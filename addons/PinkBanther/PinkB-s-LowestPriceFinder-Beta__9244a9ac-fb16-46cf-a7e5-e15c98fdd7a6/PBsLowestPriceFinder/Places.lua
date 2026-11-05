PBsLowestPriceFinder = PBsLowestPriceFinder or {}
local ADDON = PBsLowestPriceFinder

---------------------------------------------------------------------------------------------------
-- Where a guild store's trader stands
--
-- The game does not say where a guild's trader is. Two things are known, and both are learned by
-- being there:
--
--  * a trader (kiosk) NPC stands in one place for good: kiosks[name] = where. It is learned each time
--    a guild trader is opened, from the player's own position and the NPC's name.
--  * which guild holds which trader changes (a trader is bid for and held for a week), so
--    guilds[id] = the trader it was seen at, good until the traders next change
--    (GetGuildKioskCycleTimes' despawn time, taken when it was learned).
--
-- For a guild the player belongs to, GetGuildOwnedKioskInfo names its trader right now, so the place
-- is known as soon as that trader's NPC has been opened once, whoever held it then.
---------------------------------------------------------------------------------------------------

local SafeCall = ADDON.SafeCall
local CleanName = ADDON.CleanName

-- A name compared loosely: case, spaces and punctuation do not matter (the trader NPC's name and the name
-- the game gives a guild's trader may not be spelled the same way).
local function Norm(name)
	return (zo_strlower(CleanName(name)):gsub("[%s%p]", ""))
end
ADDON.NormName = Norm

-- Where the trader NPC can be found. "interact" is the unit being talked to (the client's own guild kiosk screen
-- reads its name that way); the reticle is the same unit when the player is looking at it. The interaction target
-- is believed by its name alone; any other unit only when the game says it is a guild kiosk (so another NPC in view
-- is never taken for it).
local TAGS = { "interact", "reticleover" }

-- What the game says about the trader that is open now. Returns a table; fields the game did not
-- answer are nil. Read by /lpf probe as well, so what is shown is what is stored.
function ADDON:ReadTrader()
	local info = {}
	for _, tag in ipairs(TAGS) do
		local name = SafeCall(GetUnitName, tag)
		name = (type(name) == "string" and name ~= "") and CleanName(name) or nil
		local isKiosk = SafeCall(IsUnitGuildKiosk, tag) and true or false
		local owner
		if isKiosk then
			local id = SafeCall(GetUnitGuildKioskOwner, tag)
			if type(id) == "number" and id > 0 then
				owner = id
			end
		end
		if (tag == "interact" and (name or isKiosk)) or isKiosk then
			info.tag = info.tag or tag
			info.kiosk = info.kiosk or name
			info.isKiosk = info.isKiosk or isKiosk
			info.ownerId = info.ownerId or owner
		end
	end
	local zoneId, worldX, _, worldZ = SafeCall(GetUnitWorldPosition, "player")
	info.zoneId, info.x, info.z = zoneId, worldX, worldZ
	info.zone = SafeCall(GetPlayerActiveZoneName) or ""
	info.loc = SafeCall(GetPlayerLocationName) or ""
	info.sub = SafeCall(GetPlayerActiveSubzoneName) or ""
	local despawn = SafeCall(GetGuildKioskCycleTimes)
	info.validUntil = type(despawn) == "number" and despawn or nil
	return info
end

-- Called when the player starts talking to an NPC. The trader's unit may be gone from "interact" by the time the
-- guild store opens, so what is read here, when it is a guild kiosk, is kept for a short while as a second source.
function ADDON:NoteChatter(now)
	local info = self:ReadTrader()
	if info.isKiosk and (info.kiosk or info.ownerId) then
		self.chatterTrader = { kiosk = info.kiosk, ownerId = info.ownerId, at = now }
	else
		self.chatterTrader = nil
	end
end

local CHATTER_HINT_SECONDS = 180

-- The guild the trader belongs to, found from the player's own guilds when the game does not say: a guild the
-- player is in knows the name of its own trader.
local function OwnerFromOwnGuilds(kiosk)
	if not kiosk then
		return nil
	end
	local wanted = Norm(kiosk)
	for index = 1, SafeCall(GetNumGuilds) or 0 do
		local guildId = SafeCall(GetGuildId, index)
		local owned = guildId and SafeCall(GetGuildOwnedKioskInfo, guildId)
		if type(owned) == "string" and owned ~= "" and Norm(owned) == wanted then
			return guildId
		end
	end
	return nil
end

-- Writes down the trader the game names for each guild the player is in. The game answers that only now, and not
-- always (it may say nothing while another trader is being talked to), so a name that is only ever asked for
-- live is gone the moment the game stops answering. Whatever it says is kept; an empty answer changes nothing.
function ADDON:RememberTraders(now)
	local despawn = SafeCall(GetGuildKioskCycleTimes)
	local guilds = self.sv.places.guilds
	for index = 1, SafeCall(GetNumGuilds) or 0 do
		local guildId = SafeCall(GetGuildId, index)
		local owned = guildId and SafeCall(GetGuildOwnedKioskInfo, guildId)
		if type(owned) == "string" and owned ~= "" then
			local entry = guilds[guildId] or {}
			if self.scan and entry.kiosk ~= CleanName(owned) then
				self.scan:Log("trader of guild %s remembered: %s (was %s)", tostring(guildId), CleanName(owned), tostring(entry.kiosk))
			end
			entry.kiosk = CleanName(owned)
			entry.seen = now
			entry.validUntil = type(despawn) == "number" and despawn or entry.validUntil
			if not entry.name then
				local name = SafeCall(GetGuildName, guildId)
				entry.name = (type(name) == "string" and name ~= "") and name or nil
			end
			guilds[guildId] = entry
		end
	end
end

-- Stores what ReadTrader says (and what the start of the conversation said, if the trader can no longer be read).
-- `now` is a timestamp in seconds. Reading again later is safe: nothing already known is lost to an empty answer.
function ADDON:LearnPlace(now)
	self:RememberTraders(now)
	local info = self:ReadTrader()
	local how = info.tag
	local hint = self.chatterTrader
	if hint and now - hint.at <= CHATTER_HINT_SECONDS then
		if not info.kiosk and hint.kiosk then
			info.kiosk = hint.kiosk
			how = (how or "") .. "+talk"
		end
		if not info.ownerId and hint.ownerId then
			info.ownerId = hint.ownerId
			how = (how or "") .. "+talk"
		end
	end
	if not info.ownerId then
		local owner = OwnerFromOwnGuilds(info.kiosk)
		if owner then
			info.ownerId = owner
			how = (how or "") .. "+own guild"
		end
	end

	local places = self.sv.places
	local place = {
		zone = info.zone,
		loc = info.loc,
		zoneId = info.zoneId,
		x = info.x,
		z = info.z,
		seen = now,
	}
	local kioskKey = info.kiosk
	if not kioskKey and info.zoneId and info.x and info.z then
		-- The NPC's name was not readable: file the place under where it is, to the nearest 10 m.
		kioskKey = string.format("@%d:%d:%d", info.zoneId, math.floor(info.x / 1000 + 0.5), math.floor(info.z / 1000 + 0.5))
	end
	if kioskKey then
		places.kiosks[kioskKey] = place
	end
	if info.ownerId then
		local previous = places.guilds[info.ownerId] or {}
		places.guilds[info.ownerId] = {
			name = previous.name,
			kiosk = kioskKey or previous.kiosk,
			seen = now,
			validUntil = info.validUntil,
		}
	end

	-- What the game said, for /lpf log: the one measurement needed when a trader's place does not get recorded.
	local signature = table.concat({ tostring(how), tostring(info.kiosk), tostring(info.isKiosk), tostring(info.ownerId), tostring(kioskKey) }, "|")
	if self.scan and signature ~= self.lastTraderLog then
		self.lastTraderLog = signature
		local owned = {}
		for index = 1, SafeCall(GetNumGuilds) or 0 do
			local guildId = SafeCall(GetGuildId, index)
			owned[#owned + 1] = string.format("%s=%s", tostring(guildId), tostring(guildId and SafeCall(GetGuildOwnedKioskInfo, guildId)))
		end
		self.scan:Log("trader: from=%s name=%s kiosk=%s owner=%s key=%s at '%s' / '%s'; own guilds' traders: %s",
			tostring(how), tostring(info.kiosk), tostring(info.isKiosk), tostring(info.ownerId), tostring(kioskKey),
			tostring(info.loc), tostring(info.zone), table.concat(owned, ", "))
	end
	info.linked = info.ownerId ~= nil
	info.how = how
	return info, kioskKey
end

-- Remembers a store's name (the trading house lists them; the place table is keyed by id).
function ADDON:NoteGuildName(guildId, name)
	if type(guildId) ~= "number" or type(name) ~= "string" or name == "" then
		return
	end
	local guilds = self.sv.places.guilds
	guilds[guildId] = guilds[guildId] or {}
	guilds[guildId].name = name
end

function ADDON:GuildName(guildId)
	local known = self.sv.places.guilds[guildId]
	if known and known.name then
		return known.name
	end
	local name = SafeCall(GetGuildName, guildId)
	if type(name) == "string" and name ~= "" then
		return name
	end
	return tostring(guildId)
end

-- What is known of a store's trader: { kiosk =, place =, live =, moved = }.
--  live  -- the game named the trader itself (a guild the player is in)
--  moved -- it was learned before the traders last changed, so it may not be there now
function ADDON:StoreInfo(guildId, now)
	local places = self.sv.places
	local known = places.guilds[guildId]
	local kiosk = SafeCall(GetGuildOwnedKioskInfo, guildId)
	local live = type(kiosk) == "string" and kiosk ~= ""
	if live then
		kiosk = CleanName(kiosk)
	else
		kiosk = known and known.kiosk or nil
	end
	local place = kiosk and places.kiosks[kiosk] or nil
	if kiosk and not place then
		-- the same trader spelled a little differently by the two sources
		local wanted = Norm(kiosk)
		for name, found in pairs(places.kiosks) do
			if name:sub(1, 1) ~= "@" and Norm(name) == wanted then
				place = found
				break
			end
		end
	end
	local moved = false
	if not live and known and known.validUntil and now > known.validUntil then
		moved = true
	end
	return { kiosk = kiosk, place = place, live = live, moved = moved }
end

local function Where(place)
	local loc, zone = place.loc or "", place.zone or ""
	if loc == "" then
		return zone
	end
	if zone ~= "" and zone ~= loc then
		return loc .. ", " .. zone
	end
	return loc
end

-- The trader and place of a store, for a price record, as they are known now ({ trader =, loc =, zone = }).
function ADDON:TraderSnapshot(guildId, now)
	local info = self:StoreInfo(guildId, now)
	local snapshot = {}
	if info.kiosk and info.kiosk:sub(1, 1) ~= "@" then
		snapshot.trader = info.kiosk
	end
	if info.place then
		snapshot.loc, snapshot.zone = info.place.loc, info.place.zone
	end
	return snapshot
end

-- "Vulkhel Guard, Auridon / trader Ravan" -- or what is missing of it.
-- `brief`: the short wording for a place that is not known (the panel is narrow).
-- `row`: the price record being shown. What it says about the trader and place when it was seen fills in what is
-- not known any more, so an answer does not lose its trader when the game stops naming it.
function ADDON:PlaceText(guildId, now, brief, row)
	local info = self:StoreInfo(guildId, now or GetTimeStamp())
	if row then
		if not info.kiosk and row.trader then
			info.kiosk = row.trader
		end
		if not info.place and ((row.loc and row.loc ~= "") or (row.zone and row.zone ~= "")) then
			info.place = { loc = row.loc, zone = row.zone }
		end
	end
	local text
	if info.place then
		text = Where(info.place)
		if info.kiosk and info.kiosk:sub(1, 1) ~= "@" then
			text = text .. " / " .. ADDON.Format(SI_PBSLPF_TRADER, info.kiosk)
		end
		if info.moved then
			text = text .. " " .. GetString(SI_PBSLPF_PLACE_MOVED)
		end
	elseif info.kiosk and info.kiosk:sub(1, 1) ~= "@" then
		text = ADDON.Format(SI_PBSLPF_TRADER, info.kiosk) .. " (" .. GetString(SI_PBSLPF_PLACE_UNKNOWN) .. ")"
	else
		text = GetString(brief and SI_PBSLPF_PLACE_UNKNOWN or SI_PBSLPF_PLACE_UNKNOWN_HINT)
	end
	return text
end
