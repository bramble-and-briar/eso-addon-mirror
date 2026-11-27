-------------------------------------------------------------------------------
-- Wayfinder
-- Open delve and public dungeon maps from world map pins, and find/
-- teleport to nearby group, friends, and guildmates.
-------------------------------------------------------------------------------

Wayfinder = Wayfinder or {}

local ADDON_VERSION = "1.2.0"
local wfDebug = false

-- POI display name -> list of candidate mapIds. The click handler's show() check can run often,
-- and matching a name walks the whole map name index, so each POI is only matched once.
local mapCandidateCache = {}

-- ZO_Menu is a single control shared by the game and every addon, so "a menu is open" says
-- nothing about whose it is. This records which of OUR map menus currently occupies it
-- ("zonelist" or "pin"). Anyone calling ClearMenu or ShowMenu - us included - drops the claim,
-- so we set it right after our own ShowMenu.
local ownedMenu = nil
local function ReleaseMenu() ownedMenu = nil end
ZO_PreHook("ClearMenu", ReleaseMenu)
ZO_PreHook("ShowMenu", ReleaseMenu)

local function TColor(hex, text)
	return "|c"..hex..text.."|r"
end

local function DebugPrint(msg)
	d(TColor("D9A441", "Wayfinder:") .. " " .. msg)
end

-- Icons via ESO text format |t size:size:path|t
local ICON_GROUP  = "|t16:16:esoui/art/mapicons/group_player.dds|t"
local ICON_FRIEND = "|t16:16:esoui/art/friends/friends_tabicon_friendslist_up.dds|t"
local ICON_GUILD  = "|t16:16:esoui/art/guild/guildicon_default.dds|t"

local ICON_EYE_OPEN   = "Wayfinder/icons/eye_open.dds"
local ICON_EYE_HIDDEN = "Wayfinder/icons/eye_hidden.dds"
local ICON_MOVE       = "Wayfinder/icons/move_icon.dds"

-- zoneId -> displayName -> GetTimeStamp() epoch seconds of the last time we teleported to them
-- from the "Players in Zone" list, for that specific zone. Keyed by zone so that a player who
-- teleports away to a different zone doesn't keep showing a stale dot there. Session-only by
-- design (not saved) - it's just a quick visual cue that stops mattering once it's stale anyway.
local recentTeleports = {}

local function ColorToHex(color)
	return string.format("%02X%02X%02X", zo_floor(color.r * 255 + 0.5), zo_floor(color.g * 255 + 0.5), zo_floor(color.b * 255 + 0.5))
end

-- Colored dot shown before a name in the "Players in Zone" list, indicating how long ago we last
-- teleported to them in this zone (helps avoid re-jumping to someone who's just cycling zone
-- instances via their own teleport). Three stages, each with its own "ends after" cutoff (Stage 3
-- is open-ended) and color, all configurable in Settings.
local function GetRecentTeleportIndicator(displayName, zoneId)
	if not Wayfinder.SV or not Wayfinder.SV.enableRecentTeleportIndicator then return "" end
	local ts = zoneId and recentTeleports[zoneId] and recentTeleports[zoneId][displayName]
	local stage1Min = Wayfinder.SV.recentTeleportGreenMin or 5
	local stage2Min = Wayfinder.SV.recentTeleportGrayMin or 15
	if ts then
		local elapsedMin = (GetTimeStamp() - ts) / 60
		if elapsedMin <= stage1Min then
			return TColor(ColorToHex(Wayfinder.SV.recentTeleportGreenColor), "•") .. " "
		elseif elapsedMin <= stage2Min then
			return TColor(ColorToHex(Wayfinder.SV.recentTeleportYellowColor), "•") .. " "
		end
	end
	return TColor(ColorToHex(Wayfinder.SV.recentTeleportGrayColor), "•") .. " "
end

-- If enabled in Settings, drops a player's recorded teleport time for this zone as soon as they
-- disappear from its "Players in Zone" list. The addon has no way to see instance/shard IDs, so
-- "left the zone's player list" is the only signal available that they may have hopped to a
-- different instance (e.g. via their own teleport-to-reset-instance) and back.
local function PruneStaleZoneTeleports(zoneId, players)
	if not Wayfinder.SV or not Wayfinder.SV.recentTeleportClearOnLeave then return end
	local bucket = zoneId and recentTeleports[zoneId]
	if not bucket then return end
	local present = {}
	for _, p in ipairs(players) do present[p.displayName] = true end
	for name in pairs(bucket) do
		if not present[name] then bucket[name] = nil end
	end
end

-- Sort players: group first, then friends, then guild, alphabetical within each
local function SortPlayers(players)
	local order = { group = 1, friend = 2, guild = 3 }
	table.sort(players, function(a, b)
		local oa, ob = order[a.rel] or 9, order[b.rel] or 9
		if oa ~= ob then return oa < ob end
		return zo_strlower(a.displayName) < zo_strlower(b.displayName)
	end)
	return players
end

-- Build teleport menu from sorted player list. zoneId scopes the "recently teleported" dot to
-- the zone this list is actually for (see GetRecentTeleportIndicator). refCount is passed on
-- to ShowMenu: how many mouse-ups outside the menu it takes to close it (nil = game default).
local function BuildTeleportMenu(players, owner, zoneId, refCount)
	ClearMenu()
	local sorted = SortPlayers(players)
	local lastRel = nil
	for _, p in ipairs(sorted) do
		if p.rel ~= lastRel then
			if lastRel ~= nil then
				AddCustomMenuItem("———————————", function() end)
			end
			lastRel = p.rel
		end
		local icon = p.rel == "group" and ICON_GROUP or p.rel == "friend" and ICON_FRIEND or ICON_GUILD
		local displayName = p.displayName
		AddCustomMenuItem(GetRecentTeleportIndicator(displayName, zoneId) .. icon .. " " .. displayName, function()
			Wayfinder.TeleportTo(displayName, zoneId)
		end)
	end
	ShowMenu(owner, refCount)
	ownedMenu = "zonelist"
end

-------------------------------------------------------------------------------
-- Friends/group/guild lookup, by zone or by POI
--
-- One cached group/friends/guild scan is shared by the "Players in Zone" button and the POI hover
-- tooltip/click. A scan walks every guild - up to ~2500 members across 5 guilds - so doing it per
-- caller would repeat it many times a second just from moving the mouse across a cluster of pins.
-------------------------------------------------------------------------------

local onlinePlayersCache = nil
local onlinePlayersCacheTime = 0

local function ScanOnlinePlayers()
	local players = {}
	local me = GetDisplayName()

	local function add(displayName, rel, zoneId)
		if not displayName or displayName == me then return end
		if not zoneId or zoneId == 0 then return end
		for _, p in ipairs(players) do
			if p.displayName == displayName then return end
		end
		players[#players + 1] = { displayName = displayName, rel = rel, zoneId = zoneId }
	end

	for i = 1, GetGroupSize() do
		local unitTag = GetGroupUnitTagByIndex(i)
		if unitTag and unitTag ~= "player" and IsUnitOnline(unitTag) then
			add(GetUnitDisplayName(unitTag), "group", GetZoneId(GetUnitZoneIndex(unitTag)))
		end
	end
	for i = 1, GetNumFriends() do
		local name, _, status = GetFriendInfo(i)
		if status ~= PLAYER_STATUS_OFFLINE then
			local _, _, _, _, _, _, _, zoneId = GetFriendCharacterInfo(i)
			add(name, "friend", zoneId)
		end
	end
	for guildIndex = 1, GetNumGuilds() do
		local guildId = GetGuildId(guildIndex)
		for memberIndex = 1, GetNumGuildMembers(guildId) do
			local name, _, _, status = GetGuildMemberInfo(guildId, memberIndex)
			if status ~= PLAYER_STATUS_OFFLINE then
				local _, _, _, _, _, _, _, zoneId = GetGuildMemberCharacterInfo(guildId, memberIndex)
				add(name, "guild", zoneId)
			end
		end
	end

	return players
end

-- The cache lifetime is the "Update interval" setting, so it limits how often a scan happens
-- from ANY caller (the button's poll loop or hovering pins), not just the poll loop.
-- ">=" so a poll firing exactly one interval after the last scan gets fresh data.
local function GetOnlinePlayers()
	local now = GetGameTimeMilliseconds()
	local maxAgeMs = (Wayfinder.SV and Wayfinder.SV.mapButtonPollIntervalSec or 5) * 1000
	if not onlinePlayersCache or (now - onlinePlayersCacheTime) >= maxAgeMs then
		onlinePlayersCache = ScanOnlinePlayers()
		onlinePlayersCacheTime = now
	end
	return onlinePlayersCache
end

local function GetPlayersInZoneId(targetZoneId)
	local result = {}
	for _, p in ipairs(GetOnlinePlayers()) do
		if p.zoneId == targetZoneId then
			result[#result + 1] = { displayName = p.displayName, rel = p.rel }
		end
	end
	return result
end

-- Expose for the map button
Wayfinder.GetPlayersInZoneId = GetPlayersInZoneId

local function GetPlayersInPOI(poiName)
	local result = {}
	for _, p in ipairs(GetOnlinePlayers()) do
		local zoneName = zo_strformat("<<t:1>>", GetZoneNameById(p.zoneId))
		if zoneName == poiName then
			result[#result + 1] = { displayName = p.displayName, rel = p.rel }
		end
	end
	return result
end

local MAX_TOOLTIP_NAMES = 3
local _lastPOITooltipKey = nil

local function TryAddPlayersInPOITooltip(poiName)
	if Wayfinder.SV and not Wayfinder.SV.enableNearbyPlayers then return end
	if not poiName or poiName == "" then return end

	if poiName == _lastPOITooltipKey then return end
	_lastPOITooltipKey = poiName
	zo_callLater(function() _lastPOITooltipKey = nil end, 100)

	local players = GetPlayersInPOI(poiName)

	ZO_Tooltip_AddDivider(InformationTooltip)

	if #players == 0 then
		InformationTooltip:AddLine(TColor("aaaaaa", "No one inside"), "ZoFontGameOutline")
		return
	end

	local shown = math.min(#players, MAX_TOOLTIP_NAMES)
	local extra = #players - shown

	if #players == 1 then
		InformationTooltip:AddLine(TColor("ffcc44", "1 player inside"), "ZoFontGameOutline")
	else
		InformationTooltip:AddLine(TColor("ffcc44", #players .. " players inside"), "ZoFontGameOutline")
	end
	InformationTooltip:AddLine(TColor("888888", "Click to travel"), "ZoFontGameOutline")

	for i = 1, shown do
		local p = players[i]
		local relColor = p.rel == "group" and "44ff44" or p.rel == "friend" and "44ccff" or "aaaaaa"
		InformationTooltip:AddLine(TColor(relColor, p.displayName), "ZoFontGameOutline")
	end

	if extra > 0 then
		InformationTooltip:AddLine(TColor("888888", "...and " .. extra .. " more"), "ZoFontGameOutline")
	end
end

-------------------------------------------------------------------------------
-- Map pin hooks: nearby-players tooltip, and the Open Map feature
-------------------------------------------------------------------------------

local function HookMapPins()
	local seen     = ZO_MapPin.TOOLTIP_CREATORS[MAP_PIN_TYPE_POI_SEEN]
	local complete = ZO_MapPin.TOOLTIP_CREATORS[MAP_PIN_TYPE_POI_COMPLETE]

	local origSeen = seen.creator
	seen.creator = function(pin)
		origSeen(pin)
		local zoneIndex, poiIndex = pin:GetPOIZoneIndex(), pin:GetPOIIndex()
		local poiName = zo_strformat("<<t:1>>", GetPOIInfo(zoneIndex, poiIndex))
		TryAddPlayersInPOITooltip(poiName)
	end

	local origComplete = complete.creator
	complete.creator = function(pin)
		origComplete(pin)
		local zoneIndex, poiIndex = pin:GetPOIZoneIndex(), pin:GetPOIIndex()
		local poiName = zo_strformat("<<t:1>>", GetPOIInfo(zoneIndex, poiIndex))
		TryAddPlayersInPOITooltip(poiName)
	end

	-- Map opening works by scanning mapId space directly and asking each one its name via
	-- GetMapNameById(mapId), rather than going through zoneId. The zoneId bridge
	-- (GetMapIdByZoneId) is unreliable - it can return a stale/old mapId for a zoneId that's
	-- otherwise correctly identified. GetMapNameById sidesteps that: scan every mapId, group by
	-- name, done. A name can legitimately have several mapIds (multi-level delves/public dungeons
	-- split their floors/areas into separate maps, e.g. "<core name> Approach"/"<core name> Depths"; old/
	-- reworked layouts are sometimes kept around too) - all of them are offered as a switcher.
	local MAP_ID_SCAN_MAX = 8000
	local mapNameIndex = nil

	local function BuildMapNameIndex()
		if mapNameIndex then return mapNameIndex end
		mapNameIndex = {}
		for mapId = 1, MAP_ID_SCAN_MAX do
			local ok, rawName = pcall(GetMapNameById, mapId)
			if ok and rawName and rawName ~= "" then
				local name = zo_strformat("<<t:1>>", rawName)
				if name ~= "" then
					local list = mapNameIndex[name]
					if not list then
						list = {}
						mapNameIndex[name] = list
					end
					list[#list + 1] = mapId
				end
			end
		end
		if wfDebug then
			local count = 0
			for _ in pairs(mapNameIndex) do count = count + 1 end
			DebugPrint("map name index built: " .. count .. " unique names up to mapId " .. MAP_ID_SCAN_MAX)
		end
		return mapNameIndex
	end

	-- Strips a leading "The " and lowercases, for matching only (never for display). Sub-area
	-- map names sometimes drop the zone's leading article entirely (e.g. zone "The Underweave"
	-- vs a sub-map named "Underweave Courtyard"), which a plain prefix match on the raw name misses.
	local function NormalizeMapName(name)
		local lower = zo_strlower(name)
		return (lower:gsub("^the%s+", ""))
	end

	-- Hardcoded extra map names for POIs whose sub-area map(s) don't share any prefix with the
	-- POI's display name at all, so the automatic matching below can never find them no matter
	-- how it's normalized (e.g. a dungeon whose floors are named after unrelated in-lore places).
	-- These are always ADDED to whatever automatic matching finds, not a fallback replacement -
	-- some POIs (like this one) have both a directly-matching map AND extra unrelated ones.
	-- Key = POI display name exactly as shown on the world map, value = the actual map name(s) to
	-- look up directly (exact spelling, as returned by GetMapNameById - not normalized). Add
	-- entries here as they get reported.
	local NAME_OVERRIDES = {
		["Forgotten Wastes"] = { "Kora Dur", "Caverns of Kogoruhn", "Drinith Ancestral Tomb", "Forgotten Depths" },
	}

	-- Every mapId whose (normalized) name either exactly matches this POI's display name, or
	-- starts with it followed by a space - plus any NAME_OVERRIDES entries for this POI.
	local function FindCandidateMaps(poiName)
		if not poiName or poiName == "" then return {} end
		if mapCandidateCache[poiName] then return mapCandidateCache[poiName] end
		local index = BuildMapNameIndex()
		local core = NormalizeMapName(poiName)
		local prefix = core .. " "
		local prefixLen = #prefix

		local seen = {}
		local mapIds = {}
		local function addId(mapId)
			if not seen[mapId] then
				seen[mapId] = true
				mapIds[#mapIds + 1] = mapId
			end
		end

		for name, ids in pairs(index) do
			local nameCore = NormalizeMapName(name)
			if nameCore == core or nameCore:sub(1, prefixLen) == prefix then
				for _, mapId in ipairs(ids) do
					addId(mapId)
				end
			end
		end

		if NAME_OVERRIDES[poiName] then
			for _, overrideName in ipairs(NAME_OVERRIDES[poiName]) do
				local ids = index[overrideName]
				if ids then
					for _, mapId in ipairs(ids) do
						addId(mapId)
					end
				end
			end
		end

		if wfDebug then
			DebugPrint("'" .. poiName .. "' -> " .. #mapIds .. " map candidate(s)")
			for _, mapId in ipairs(mapIds) do
				DebugPrint("  mapId=" .. mapId .. " (" .. tostring(GetMapNameById(mapId)) .. ")")
			end
		end

		mapCandidateCache[poiName] = mapIds
		return mapIds
	end

	-- Adds an "Open Map" item to the currently-building menu: a single plain item if there's
	-- exactly one matching map, or "Open Maps (N)" if there's more than one, which opens the
	-- map switcher panel instead. Nothing added if no candidate map was found.
	local function AddOpenMapMenuItem(poiName)
		local mapIds = FindCandidateMaps(poiName)
		if #mapIds == 0 then return false end

		table.sort(mapIds)

		if #mapIds == 1 then
			local mapId = mapIds[1]
			AddCustomMenuItem("Open Map", function()
				-- Close any switcher panel left open from a previously viewed multi-map dungeon -
				-- otherwise its floor list (and clicking it) would still point at that old dungeon.
				if Wayfinder.HideMapSwitcher then Wayfinder.HideMapSwitcher() end
				WORLD_MAP_MANAGER:SetMapById(mapId)
			end)
			return true
		end

		AddCustomMenuItem("Open Maps (" .. #mapIds .. ")", function()
			Wayfinder.ShowMapSwitcher(poiName, mapIds)
		end)
		return true
	end

	-- Public dungeons and delves (incl. Craglorn-style group delves) via the same POI
	-- classification the base game itself uses (GetPOIType / GetPOIZoneCompletionType).
	local function IsGroupPOI(zoneIndex, poiIndex)
		local ok1, poiType = pcall(GetPOIType, zoneIndex, poiIndex)
		local ok2, completionType = pcall(GetPOIZoneCompletionType, zoneIndex, poiIndex)
		if ok1 and poiType == POI_TYPE_PUBLIC_DUNGEON then return true end
		if ok2 and (completionType == ZONE_COMPLETION_TYPE_DELVES or completionType == ZONE_COMPLETION_TYPE_GROUP_DELVES) then return true end
		return false
	end

	local function GetPinPOIName(pin)
		local rawName = GetPOIInfo(pin:GetPOIZoneIndex(), pin:GetPOIIndex())
		return zo_strformat("<<t:1>>", rawName)
	end

	-- What we could offer for this pin: whether to try an Open Map item, and who's inside.
	-- Shared by the show() check and the menu itself so the two can't disagree.
	local function GetPOIOffer(zoneIndex, poiIndex, poiName)
		local openMapEnabled = not (Wayfinder.SV and not Wayfinder.SV.enableOpenMap)
		local teleportEnabled = not (Wayfinder.SV and not Wayfinder.SV.enableNearbyPlayers)

		local hasMaps = openMapEnabled and IsGroupPOI(zoneIndex, poiIndex)
			and #FindCandidateMaps(poiName) > 0
		local players = {}
		if teleportEnabled then
			players = GetPlayersInPOI(poiName)
		end
		return hasMaps, players
	end

	-- Without this the game treats every POI pin (mundus stones, dolmens, ...) as clickable by
	-- us, and lists us in its "which pin?" menu even when we have nothing to show.
	local function HasPOIOffer(pin)
		local poiName = GetPinPOIName(pin)
		if poiName == "" then return false end
		local hasMaps, players = GetPOIOffer(pin:GetPOIZoneIndex(), pin:GetPOIIndex(), poiName)
		return hasMaps or #players > 0
	end

	local function ShowPOIMenu(zoneIndex, poiIndex, poiName)
		local hasMaps, players = GetPOIOffer(zoneIndex, poiIndex, poiName)

		if wfDebug then
			DebugPrint("clicked '" .. poiName .. "' hasMaps=" .. tostring(hasMaps))
		end

		if not hasMaps and #players == 0 then return end

		ClearMenu()
		local hasItems = false

		if hasMaps then
			hasItems = AddOpenMapMenuItem(poiName) or hasItems
		end

		if #players > 0 then
			if hasItems then AddCustomMenuItem("——————", function() end) end
			local sorted = SortPlayers(players)
			for _, p in ipairs(sorted) do
				local displayName = p.displayName
				local relIcon = p.rel == "group" and ICON_GROUP or p.rel == "friend" and ICON_FRIEND or ICON_GUILD
				AddCustomMenuItem(relIcon .. displayName, function()
					Wayfinder.TeleportTo(displayName, GetZoneId(zoneIndex))
				end)
			end
			hasItems = true
		end

		-- Opened after the click has finished (see OnPOIPinClicked), so one click outside closes it.
		if hasItems then
			ShowMenu(nil, 1)
			ownedMenu = "pin"
		end
	end

	local function OnPOIPinClicked(pin)
		-- Read from the pin now: pin objects can be recycled before the deferred call runs.
		local zoneIndex, poiIndex = pin:GetPOIZoneIndex(), pin:GetPOIIndex()
		local poiName = GetPinPOIName(pin)
		if poiName == "" then return end

		-- When pins overlap, this runs from an item in the game's own "which pin?" menu, which
		-- calls ClearMenu() right after we return - a menu opened immediately would be wiped.
		zo_callLater(function() ShowPOIMenu(zoneIndex, poiIndex, poiName) end, 10)
	end

	if ZO_MapPin.PIN_CLICK_HANDLERS then
		local left = ZO_MapPin.PIN_CLICK_HANDLERS[MOUSE_BUTTON_INDEX_LEFT]
		if not left[MAP_PIN_TYPE_POI_SEEN] then left[MAP_PIN_TYPE_POI_SEEN] = {} end
		if not left[MAP_PIN_TYPE_POI_COMPLETE] then left[MAP_PIN_TYPE_POI_COMPLETE] = {} end
		-- name labels our entry in the overlapping-pins menu; without it the entry is blank.
		local handler = { name = GetPinPOIName, show = HasPOIOffer, callback = OnPOIPinClicked }
		table.insert(left[MAP_PIN_TYPE_POI_SEEN],     handler)
		table.insert(left[MAP_PIN_TYPE_POI_COMPLETE], handler)
	end
end

-------------------------------------------------------------------------------
-- /wfdebug — toggle diagnostic chat output for map pin clicks/scans
-------------------------------------------------------------------------------

SLASH_COMMANDS["/wfdebug"] = function()
	wfDebug = not wfDebug
	mapCandidateCache = {} -- so map matching is redone, and printed, on the next hover/click
	DebugPrint("Debug report: " .. (wfDebug and TColor("33cc33", "ON") or TColor("cc3333", "OFF")))
end

-------------------------------------------------------------------------------
-- Teleport context menu (right-click player link in chat)
-------------------------------------------------------------------------------

local function WFGetRelationship(displayName)
	for i = 1, GetGroupSize() do
		local unitTag = GetGroupUnitTagByIndex(i)
		if unitTag and GetUnitDisplayName(unitTag) == displayName then
			return "group"
		end
	end
	for i = 1, GetNumFriends() do
		local name = GetFriendInfo(i)
		if name == displayName then
			return "friend"
		end
	end
	for guildIndex = 1, GetNumGuilds() do
		local guildId = GetGuildId(guildIndex)
		for memberIndex = 1, GetNumGuildMembers(guildId) do
			local name = GetGuildMemberInfo(guildId, memberIndex)
			if name == displayName then
				return "guild"
			end
		end
	end
	return nil
end

local function NormalizeCharName(name)
	if type(name) ~= "string" or name == "" then return "" end
	return zo_strtrim(zo_strformat("<<C:1>>", name))
end

-- Chat links for a character speaking in Say/Zone/Group/Guild chat only carry the character
-- name (type "character:", confirmed in-game), not the account name teleporting needs. Resolve
-- it by matching against the character names of currently online group/friends/guild members -
-- the same data already used elsewhere for "who's nearby" - and return their @DisplayName.
local function WFResolveCharacterName(charName)
	local target = NormalizeCharName(charName)
	if target == "" then return nil end

	for i = 1, GetGroupSize() do
		local unitTag = GetGroupUnitTagByIndex(i)
		if unitTag and unitTag ~= "player" and IsUnitOnline(unitTag) then
			if NormalizeCharName(GetUnitName(unitTag)) == target then
				return GetUnitDisplayName(unitTag)
			end
		end
	end

	for i = 1, GetNumFriends() do
		local displayName, _, status = GetFriendInfo(i)
		if status ~= PLAYER_STATUS_OFFLINE then
			local _, characterName = GetFriendCharacterInfo(i)
			if NormalizeCharName(characterName) == target then
				return displayName
			end
		end
	end

	for guildIndex = 1, GetNumGuilds() do
		local guildId = GetGuildId(guildIndex)
		for memberIndex = 1, GetNumGuildMembers(guildId) do
			local displayName, _, _, status = GetGuildMemberInfo(guildId, memberIndex)
			if status ~= PLAYER_STATUS_OFFLINE then
				local _, characterName = GetGuildMemberCharacterInfo(guildId, memberIndex)
				if NormalizeCharName(characterName) == target then
					return displayName
				end
			end
		end
	end

	return nil
end

local function WFTeleportTo(displayName, zoneId)
	local rel = WFGetRelationship(displayName)

	local isOnline = false
	if rel == "group" then
		for i = 1, GetGroupSize() do
			local unitTag = GetGroupUnitTagByIndex(i)
			if unitTag and GetUnitDisplayName(unitTag) == displayName then
				isOnline = IsUnitOnline(unitTag)
				break
			end
		end
	elseif rel == "friend" then
		for i = 1, GetNumFriends() do
			local name, _, status = GetFriendInfo(i)
			if name == displayName then
				isOnline = (status ~= PLAYER_STATUS_OFFLINE)
				break
			end
		end
	elseif rel == "guild" then
		for guildIndex = 1, GetNumGuilds() do
			local guildId = GetGuildId(guildIndex)
			for memberIndex = 1, GetNumGuildMembers(guildId) do
				local name, _, _, status = GetGuildMemberInfo(guildId, memberIndex)
				if name == displayName then
					isOnline = (status ~= PLAYER_STATUS_OFFLINE)
					break
				end
			end
		end
	end

	if not isOnline then
		DebugPrint(TColor("cc3333", displayName .. " is offline"))
		return
	end

	if wfDebug then DebugPrint("teleporting to |H0:display:" .. displayName .. "|h" .. displayName .. "|h") end

	if rel == "group" then
		JumpToGroupMember(displayName)
	elseif rel == "friend" then
		JumpToFriend(displayName)
	elseif rel == "guild" then
		JumpToGuildMember(displayName)
	end

	if zoneId then
		recentTeleports[zoneId] = recentTeleports[zoneId] or {}
		recentTeleports[zoneId][displayName] = GetTimeStamp()
	end
end

-- Expose via Wayfinder table so it can be called before declaration (e.g. from map pin callbacks)
Wayfinder.TeleportTo = function(displayName, zoneId) WFTeleportTo(displayName, zoneId) end

local function WFHookLinkHandler()
	local base = ZO_LinkHandler_OnLinkMouseUp
	ZO_LinkHandler_OnLinkMouseUp = function(link, button, control)
		base(link, button, control)
		if wfDebug then DebugPrint("link click: button=" .. tostring(button) .. " link=" .. tostring(link):gsub("|", "!")) end
		if button ~= MOUSE_BUTTON_INDEX_RIGHT then return end

		-- Whispers use a "display" link: |H1:display:Name|h[@Name]|h - no leading "@" in the data
		-- portion (unlike most other link types), so it has to be added back to match the
		-- "@Name" format GetDisplayName()/GetFriendInfo()/etc. all use.
		local rawName = link:match("|H%d:display:([^|]+)|h")
		local name = rawName and ("@" .. rawName:gsub("^@", ""))

		-- Say/Zone/Group/Guild chat instead links the speaker's CHARACTER name: confirmed in-game
		-- as |H0:character:Name^Fx|hName|h (data portion even has a stray grammar-gender suffix
		-- on it - the display portion right after it is the clean name to use). Resolve that back
		-- to an account name via the group/friends/guild character names we already track.
		if not name then
			local charName = link:match("|H%d:character:[^|]+|h([^|]+)|h")
			if charName then
				name = WFResolveCharacterName(charName)
			end
		end

		if wfDebug then DebugPrint("parsed name=" .. tostring(name)) end
		if not name then return end
		if name == GetDisplayName() then return end
		if Wayfinder.SV and not Wayfinder.SV.enableTravelMenu then return end

		local rel = WFGetRelationship(name)
		if wfDebug then DebugPrint("relationship for " .. name .. " = " .. tostring(rel)) end
		if not rel then return end

		-- Vanilla chat doesn't build/show a context menu for plain @name links at all - only
		-- chat replacement addons like pChat do that themselves. So this can't just add an item
		-- and assume something else calls ShowMenu() - it has to show it, same as PriceTooltip's
		-- own link-menu extension does (confirmed by reading its code: no ClearMenu(), just adds
		-- items and calls ShowMenu() itself so it works with or without other chat addons present).
		-- If one of our map menus is still up (nothing replaced it), don't append to it.
		if ownedMenu then ClearMenu() end
		AddCustomMenuItem("Travel to Player", function()
			WFTeleportTo(name)
		end)
		ShowMenu()
	end
end

-------------------------------------------------------------------------------
-- Map teleport button ("Players in Zone")
-------------------------------------------------------------------------------

local function InitMapTeleportButton()
	-- Everything lives on one top-level window (anchor) so the whole cluster - drag handle,
	-- button, eye toggle - moves together, using the same built-in top-level-window drag
	-- behavior as the map switcher panel (no custom StartMoving code, just movable+mouseEnabled
	-- plus OnMoveStop to persist the position).
	local anchor = WINDOW_MANAGER:CreateTopLevelWindow("WFMapButtonAnchor")
	anchor:SetDimensions(284, 32)
	-- Keep this above the world map scene's own draw tier so it stays visible/on top even
	-- when the map (or another window) has focus - same fix used for the map switcher panel.
	anchor:SetDrawTier(DT_HIGH)
	if Wayfinder.SV.mapButtonX and Wayfinder.SV.mapButtonY then
		anchor:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, Wayfinder.SV.mapButtonX, Wayfinder.SV.mapButtonY)
	else
		anchor:SetAnchor(TOPRIGHT, ZO_WorldMap, TOPRIGHT, -8, 8)
	end
	anchor:SetMouseEnabled(true)
	anchor:SetClampedToScreen(true)
	anchor:SetHidden(true)
	anchor:SetHandler("OnMoveStop", function()
		Wayfinder.SV.mapButtonX = anchor:GetLeft()
		Wayfinder.SV.mapButtonY = anchor:GetTop()
	end)

	local btn = WINDOW_MANAGER:CreateControlFromVirtual("WFMapTeleportButton", anchor, "ZO_DefaultButton")
	btn:SetDimensions(205, 28)
	btn:SetAnchor(TOPLEFT, anchor, TOPLEFT, 4, 2)
	btn:SetFont("ZoFontGameBold")
	btn:SetText("Players in Zone")
	btn:SetClickSound("Click")

	-- Eye toggle: quick show/hide for the button itself, independent of the Settings on/off
	-- switch, and independent of the lock state so it's always reachable. No button chrome -
	-- a bare icon, same pattern BeamMeUp uses for its clickable map-window icons: a plain
	-- mouse-enabled CT_TEXTURE with an explicit SetDrawLayer (that's what makes it take mouse-hit
	-- priority over the parent movable window's own drag-start; without it the click gets
	-- swallowed into a drag instead of reaching this control's own handler). Hover highlight is a
	-- simple color tint for now since we don't have separate hover-state icon art yet.
	local eyeIcon = WINDOW_MANAGER:CreateControl("WFMapButtonEyeIcon", anchor, CT_TEXTURE)
	eyeIcon:SetDimensions(28, 28)
	eyeIcon:SetAnchor(TOPLEFT, btn, TOPRIGHT, 6, 0)
	eyeIcon:SetMouseEnabled(true)
	eyeIcon:SetDrawLayer(DL_TEXT)

	-- Drag handle: purely decorative and mouse-disabled, so clicks on it fall through to the
	-- anchor's own drag behavior instead of being consumed by a child control. Only shown while
	-- unlocked in Settings. Sits to the right of the eye icon.
	local dragHandle = WINDOW_MANAGER:CreateControl("WFMapButtonDragHandle", anchor, CT_TEXTURE)
	dragHandle:SetDimensions(28, 28)
	dragHandle:SetAnchor(TOPLEFT, eyeIcon, TOPRIGHT, 6, 0)
	dragHandle:SetTexture(ICON_MOVE)
	dragHandle:SetMouseEnabled(false)

	eyeIcon:SetHandler("OnMouseEnter", function(self)
		self:SetColor(1, 0.85, 0.4, 1)
	end)
	eyeIcon:SetHandler("OnMouseExit", function(self)
		self:SetColor(1, 1, 1, 1)
	end)

	local menuX, menuY -- where the zone list was opened; live rebuilds stay there
	local lastPlayerKey = nil

	local function SetAnchorVisible(visible)
		anchor:SetHidden(not visible)
	end

	local function RefreshEyeButton()
		eyeIcon:SetTexture(Wayfinder.SV.mapButtonHidden and ICON_EYE_HIDDEN or ICON_EYE_OPEN)
	end

	-- Hidden whenever the UI is locked, or whenever the button itself is hidden via the eye
	-- toggle (no point offering a drag handle for a button you can't currently see).
	local function RefreshDragHandle()
		dragHandle:SetHidden(Wayfinder.SV.lockMapButton or Wayfinder.SV.mapButtonHidden)
	end

	local function RefreshLockState()
		anchor:SetMovable(not Wayfinder.SV.lockMapButton)
		RefreshDragHandle()
	end

	-- GetZoneIdByMapId doesn't exist in the current API (confirmed in-game), so this always
	-- goes through GetCurrentMapZoneIndex/GetZoneId instead.
	local function GetCurrentMapZoneId()
		local mapId = GetCurrentMapId()
		if not mapId or mapId == 0 then return nil end
		local zoneIndex = GetCurrentMapZoneIndex()
		if not zoneIndex or zoneIndex == 0 or zoneIndex > 10000 then return nil end
		return GetZoneId(zoneIndex)
	end

	local function UpdateButton()
		if Wayfinder.SV.enableMapButton == false then
			SetAnchorVisible(false)
			return
		end

		if not WORLD_MAP_SCENE:IsShowing() then
			SetAnchorVisible(false)
			return
		end

		local mapId = GetCurrentMapId()
		local zoneIndex = GetCurrentMapZoneIndex()
		local zoneId = GetCurrentMapZoneId()

		if not mapId or mapId == 0 then
			SetAnchorVisible(false)
			return
		end

		-- zoneIndex=4294967296 is uint32 overflow of -1 meaning no zone
		if not zoneIndex or zoneIndex == 0 or zoneIndex > 100000 then
			SetAnchorVisible(false)
			return
		end

		if not zoneId or zoneId == 0 then
			SetAnchorVisible(false)
			return
		end

		SetAnchorVisible(true)
		btn:SetHidden(Wayfinder.SV.mapButtonHidden)
		RefreshDragHandle()
		if Wayfinder.SV.mapButtonHidden then
			btn:SetEnabled(false)
			return
		end

		local players = Wayfinder.GetPlayersInZoneId(zoneId)
		local count = #players

		if count == 0 then
			btn:SetText("Players in Zone")
			btn:SetEnabled(false)
		elseif count == 1 then
			btn:SetText("Players in Zone (1)")
			btn:SetEnabled(true)
		else
			btn:SetText("Players in Zone (" .. count .. ")")
			btn:SetEnabled(true)
		end
	end

	eyeIcon:SetHandler("OnMouseUp", function(self, button, upInside)
		if button ~= MOUSE_BUTTON_INDEX_LEFT or not upInside then return end
		Wayfinder.SV.mapButtonHidden = not Wayfinder.SV.mapButtonHidden
		RefreshEyeButton()
		UpdateButton()
	end)

	-- Called by Settings when enableMapButton/lockMapButton change, so they take effect
	-- immediately without a reload.
	Wayfinder.RefreshMapButton = function()
		RefreshLockState()
		RefreshEyeButton()
		UpdateButton()
	end

	RefreshEyeButton()
	RefreshLockState()

	local function IsZoneListOpen()
		return ownedMenu == "zonelist" and not ZO_Menu:IsHidden()
	end

	-- ShowMenu always puts the menu at the mouse cursor, so move it back after every build.
	local function PlaceZoneList()
		ZO_Menu:ClearAnchors()
		ZO_Menu:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, menuX, menuY)
	end

	btn:SetHandler("OnClicked", function()
		local zoneId = GetCurrentMapZoneId()
		if not zoneId or zoneId == 0 then return end
		local players = Wayfinder.GetPlayersInZoneId(zoneId)
		if #players == 0 then return end
		BuildTeleportMenu(players, btn, zoneId)
		-- Pin menu to bottom-left of button
		local btnLeft, _, _, btnBottom = btn:GetScreenRect()
		menuX, menuY = btnLeft, btnBottom
		PlaceZoneList()
	end)

	CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", function()
		if WORLD_MAP_SCENE:IsShowing() then
			lastPlayerKey = nil  -- force refresh on map change
			UpdateButton()
		end
	end)

	-- Polling while map is open; interval is configurable in Settings (seconds, converted to ms).
	-- Each time the map is shown starts a new generation. A call still pending from an earlier one
	-- would otherwise find the map open again and keep polling alongside the new chain.
	local pollGeneration = 0
	local function SchedulePoll(generation)
		zo_callLater(function()
			if generation ~= pollGeneration or not WORLD_MAP_SCENE:IsShowing() then return end

			local zoneId = GetCurrentMapZoneId()
			local players = zoneId and Wayfinder.GetPlayersInZoneId(zoneId) or {}

			if zoneId then PruneStaleZoneTeleports(zoneId, players) end

			-- Build a key from sorted names to detect changes
			local names = {}
			for _, p in ipairs(players) do names[#names + 1] = p.displayName end
			table.sort(names)
			local newKey = table.concat(names, "|")

			if newKey ~= lastPlayerKey then
				lastPlayerKey = newKey
				UpdateButton()
				if IsZoneListOpen() and #players > 0 then
					-- No click is in progress here, so one click outside should close it.
					BuildTeleportMenu(players, btn, zoneId, 1)
					PlaceZoneList()
				end
			end

			SchedulePoll(generation)
		end, (Wayfinder.SV.mapButtonPollIntervalSec or 5) * 1000)
	end

	WORLD_MAP_SCENE:RegisterCallback("StateChange", function(oldState, newState)
		if newState == SCENE_SHOWN then
			UpdateButton()
			pollGeneration = pollGeneration + 1
			SchedulePoll(pollGeneration)
		else
			SetAnchorVisible(false)
		end
	end)
end

-------------------------------------------------------------------------------
-- Map switcher panel - shown when a POI has more than one candidate map
-- (multi-level delves/public dungeons split into several maps, e.g. "Approach"/"Depths").
-- Title bar, "< label >" navigator, a dropdown for jumping straight to one,
-- version tucked in the corner.
-------------------------------------------------------------------------------

local function InitMapSwitcherPanel()
	local panel = WINDOW_MANAGER:CreateTopLevelWindow("WFMapSwitcherPanel")
	panel:SetDimensions(450, 158)
	-- Movable top-level windows need to be anchored to GuiRoot with absolute coordinates for the
	-- engine's drag tracking to actually reposition them (confirmed by how 3DMarkers/BeamMeUp
	-- anchor their movable frames) - anchoring relative to another UI element like ZO_WorldMap
	-- looked fine visually but silently didn't drag. Compute a one-time starting position next
	-- to the map from its current screen rect, then anchor to GuiRoot from there - unless a saved
	-- position already exists, same pattern as the map teleport button.
	if Wayfinder.SV.mapSwitcherX and Wayfinder.SV.mapSwitcherY then
		panel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, Wayfinder.SV.mapSwitcherX, Wayfinder.SV.mapSwitcherY)
	else
		local mapRight, mapTop = ZO_WorldMap:GetRight(), ZO_WorldMap:GetTop()
		panel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, mapRight + 10, mapTop + 40)
	end
	panel:SetMouseEnabled(true)
	panel:SetMovable(true)
	panel:SetClampedToScreen(true)
	-- Keep it above the world map scene's own tier permanently, so it doesn't end up rendering
	-- behind the map if the player parks it over the map area and reopens a multi-map dungeon later.
	panel:SetDrawTier(DT_HIGH)
	panel:SetHidden(true)
	-- Top-level windows with movable+mouseEnabled drag automatically via the engine's own
	-- default mouse handling - no StartMoving/StopMovingOrResizing needed (confirmed: 3DMarkers'
	-- movable frames have zero drag-related Lua code, just these two flags in the XML).
	panel:SetHandler("OnMoveStop", function()
		Wayfinder.SV.mapSwitcherX = panel:GetLeft()
		Wayfinder.SV.mapSwitcherY = panel:GetTop()
	end)

	local bg = WINDOW_MANAGER:CreateControl("WFMapSwitcherPanelBG", panel, CT_BACKDROP)
	bg:SetAnchorFill(panel)
	bg:SetCenterColor(0.04, 0.04, 0.04, 0.9)
	bg:SetEdgeColor(0, 0, 0, 1)

	local title = WINDOW_MANAGER:CreateControl("WFMapSwitcherPanelTitle", panel, CT_LABEL)
	title:SetAnchor(TOP, panel, TOP, 0, 8)
	title:SetFont("ZoFontHeader")
	title:SetText(TColor("D9A441", "Wayfinder"))

	local closeBtn = WINDOW_MANAGER:CreateControlFromVirtual("WFMapSwitcherPanelClose", panel, "ZO_CloseButton")
	closeBtn:SetAnchor(TOPRIGHT, panel, TOPRIGHT, -4, 4)
	closeBtn:SetHandler("OnClicked", function() panel:SetHidden(true) end)

	local divider = WINDOW_MANAGER:CreateControl("WFMapSwitcherPanelDivider", panel, CT_BACKDROP)
	divider:SetDimensions(414, 1)
	divider:SetAnchor(TOP, title, BOTTOM, 0, 6)
	divider:SetCenterColor(1, 1, 1, 0.6)
	divider:SetEdgeColor(0, 0, 0, 0)

	local subtitle = WINDOW_MANAGER:CreateControl("WFMapSwitcherPanelSubtitle", panel, CT_LABEL)
	subtitle:SetAnchor(TOP, divider, BOTTOM, 0, 6)
	subtitle:SetDimensions(414, 16)
	subtitle:SetFont("ZoFontGameSmall")
	subtitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	subtitle:SetColor(0.7, 0.7, 0.7, 1)

	local prevBtn = WINDOW_MANAGER:CreateControlFromVirtual("WFMapSwitcherPanelPrev", panel, "ZO_DefaultButton")
	prevBtn:SetDimensions(30, 26)
	prevBtn:SetText("<")
	prevBtn:SetAnchor(TOPLEFT, subtitle, BOTTOMLEFT, -2, 8)

	local nextBtn = WINDOW_MANAGER:CreateControlFromVirtual("WFMapSwitcherPanelNext", panel, "ZO_DefaultButton")
	nextBtn:SetDimensions(30, 26)
	nextBtn:SetText(">")
	nextBtn:SetAnchor(TOPRIGHT, subtitle, BOTTOMRIGHT, 2, 8)

	local navLabel = WINDOW_MANAGER:CreateControl("WFMapSwitcherPanelNavLabel", panel, CT_LABEL)
	navLabel:SetDimensions(300, 26)
	navLabel:SetFont("ZoFontGameBold")
	navLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	navLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	navLabel:SetAnchor(TOP, subtitle, BOTTOM, 0, 8)

	local dropdownContainer = WINDOW_MANAGER:CreateControlFromVirtual("WFMapSwitcherPanelDropdown", panel, "ZO_ScrollableComboBox")
	dropdownContainer:SetDimensions(390, 30)
	dropdownContainer:SetAnchor(TOP, navLabel, BOTTOM, 0, 10)
	local dropdown = ZO_ComboBox_ObjectFromContainer(dropdownContainer)
	dropdown:SetSortsItems(false)

	local version = WINDOW_MANAGER:CreateControl("WFMapSwitcherPanelVersion", panel, CT_LABEL)
	version:SetFont("ZoFontGameSmall")
	version:SetColor(0.5, 0.5, 0.5, 1)
	version:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
	version:SetText("v" .. ADDON_VERSION)
	version:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, -6, -4)

	local state = { mapIds = {}, index = 1 }

	local function MapLabel(mapId)
		local ok, mapName = pcall(GetMapNameById, mapId)
		return (ok and mapName and mapName ~= "") and zo_strformat("<<t:1>>", mapName) or ("Map " .. mapId)
	end

	-- Dropdown entries get the mapId appended so same-named floors/duplicates stay distinguishable.
	local function MapListLabel(mapId)
		return MapLabel(mapId) .. " " .. TColor("888888", "(" .. mapId .. ")")
	end

	local function UpdateNav()
		local count = #state.mapIds
		if count == 0 then return end
		local mapId = state.mapIds[state.index]
		navLabel:SetText(MapLabel(mapId) .. "  (" .. state.index .. " / " .. count .. ")")
		dropdown:SetSelectedItemText(MapListLabel(mapId))
	end

	local function SelectIndex(newIndex)
		local count = #state.mapIds
		if count == 0 then return end
		newIndex = ((newIndex - 1) % count) + 1
		state.index = newIndex
		WORLD_MAP_MANAGER:SetMapById(state.mapIds[newIndex])
		UpdateNav()
	end

	prevBtn:SetHandler("OnClicked", function() SelectIndex(state.index - 1) end)
	nextBtn:SetHandler("OnClicked", function() SelectIndex(state.index + 1) end)

	-- mapIds must already be sorted ascending by the caller.
	function Wayfinder.ShowMapSwitcher(poiName, mapIds)
		state.mapIds = mapIds
		state.index = 1
		subtitle:SetText(poiName)

		dropdown:ClearItems()
		for i, mapId in ipairs(mapIds) do
			local entry = dropdown:CreateItemEntry(MapListLabel(mapId), function()
				SelectIndex(i)
			end)
			dropdown:AddItem(entry)
		end

		WORLD_MAP_MANAGER:SetMapById(mapIds[1])
		UpdateNav()
		panel:SetHidden(false)
	end

	function Wayfinder.HideMapSwitcher()
		panel:SetHidden(true)
	end

	WORLD_MAP_SCENE:RegisterCallback("StateChange", function(oldState, newState)
		if newState ~= SCENE_SHOWN then
			panel:SetHidden(true)
		end
	end)
end

EVENT_MANAGER:RegisterForEvent("Wayfinder", EVENT_ADD_ON_LOADED, function(_, addonName)
	if addonName ~= "Wayfinder" then return end
	EVENT_MANAGER:UnregisterForEvent("Wayfinder", EVENT_ADD_ON_LOADED)
	Wayfinder.InitSettings()
	HookMapPins()
	WFHookLinkHandler()
	EVENT_MANAGER:RegisterForEvent("Wayfinder_Init", EVENT_PLAYER_ACTIVATED, function()
		EVENT_MANAGER:UnregisterForEvent("Wayfinder_Init", EVENT_PLAYER_ACTIVATED)
		-- Always created now - UpdateButton() checks enableMapButton live so the Settings
		-- toggle takes effect immediately without needing a reload.
		InitMapTeleportButton()
		InitMapSwitcherPanel()
	end)
end)
