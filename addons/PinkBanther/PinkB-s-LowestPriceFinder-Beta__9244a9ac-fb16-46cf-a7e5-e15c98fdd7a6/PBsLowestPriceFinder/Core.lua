PBsLowestPriceFinder = PBsLowestPriceFinder or {}
local ADDON = PBsLowestPriceFinder

---------------------------------------------------------------------------------------------------
-- PB's Lowest Price Finder
-- Author: PinkBanther
--
-- Finds the guild store that sells the items you watch at the lowest price, and where its trader
-- stands.
--
-- WHAT THE GAME ALLOWS (read from the client's own Lua, esoui/esoui; not yet measured on a console)
--
-- A guild store search runs against ONE store at a time: SelectTradingHouseGuildId picks the store,
-- ExecuteTradingHouseSearch searches it, and a result row carries the seller but not the store. The
-- stores that can be picked are the ones the trader at hand offers (GetNumTradingHouseGuilds). So no
-- add-on can ask "who sells this cheapest in all of Tamriel"; what it can do is search every store the
-- player can open right now, one after the other, and REMEMBER what it saw. This add-on does exactly
-- that, and the answer it gives is "the cheapest store among those searched, as of the time shown".
--
-- Core.lua: the watch list, the recorded prices, and ranking them. Nothing here talks to the guild
-- store; Scan.lua does.
---------------------------------------------------------------------------------------------------

ADDON.name = "PBsLowestPriceFinder"
ADDON.author = "PinkBanther"
ADDON.displayName = "PB’s Lowest Price Finder"
ADDON.title = ADDON.displayName
ADDON.version = ""

ADDON.SAVED_VARS_NAME = "PBsLowestPriceFinder_Data"
ADDON.SAVED_VARS_VERSION = 1

-- How many items can be watched. Every item costs one search per store, and a search can be asked for
-- only about once a couple of seconds, so the list is kept short.
ADDON.MAX_WATCH = 12

ADDON.DEFAULTS = {
	-- Search by itself whenever a guild trader opens. Off by default: the searches have not been run on a
	-- console yet, so they start only when /lpf scan asks for one (turn this on once they are known to work).
	autoScan = false,
	-- Prices older than this many days are not offered as the answer (0: no limit).
	maxAgeDays = 7,
	-- A search that starts by itself leaves out an item in a store that was searched less than this many
	-- minutes ago (0: leave nothing out). /lpf scan always searches everything. The guild store's own screen
	-- follows every search the add-on makes, so a trader opened only to sell should not start one each time.
	rescanMinutes = 30,
	panel = true,
	panelHoldSec = 30,
	-- 1 (smallest) to 5 (largest)
	panelSize = 3,
	panelLeft = 60,
	panelTop = 140,
	-- { { text =, name =, exact =, quality =, link = }, ... }
	watch = {},
	-- prices[itemKey][guildId] = { guild =, price =, total =, stack =, seller =, name =, link =, seen =, expires =,
	--                              trader =, loc =, zone = (the guild's trader and its place, as known when it was seen) }
	--                         or { guild =, none = true, seen = } when the store had none for sale
	prices = {},
	-- places.kiosks[trader name] = { zone =, loc =, zoneId =, x =, z =, seen = }
	-- places.guilds[guildId]     = { name =, kiosk =, seen =, validUntil = }
	places = { kiosks = {}, guilds = {} },
}

local unpackList = unpack or table.unpack
ADDON.unpack = unpackList

local function Print(text)
	d(text)
end
ADDON.Print = Print

function ADDON.Format(id, ...)
	return string.format(GetString(id), ...)
end

---------------------------------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------------------------------

local function Commas(digits)
	local out = digits
	while true do
		local replaced
		out, replaced = out:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if replaced == 0 then
			break
		end
	end
	return out
end

-- 1234567 -> "1,234,567"; 12.5 -> "12.50"; nil -> "-".
function ADDON.FormatNumber(value)
	if type(value) ~= "number" then
		return "-"
	end
	local whole = math.floor(value + 0.5)
	if math.abs(value - whole) < 0.005 then
		return Commas(string.format("%d", whole))
	end
	local text = string.format("%.2f", value)
	local int, frac = text:match("^(-?%d+)(%.%d+)$")
	return Commas(int) .. frac
end

-- "3 h ago" and the like, from a number of seconds.
function ADDON.AgeText(seconds)
	if type(seconds) ~= "number" or seconds < 60 then
		return GetString(SI_PBSLPF_AGE_NOW)
	elseif seconds < 3600 then
		return ADDON.Format(SI_PBSLPF_AGE_MIN, math.floor(seconds / 60))
	elseif seconds < 86400 then
		return ADDON.Format(SI_PBSLPF_AGE_HOUR, math.floor(seconds / 3600))
	end
	return ADDON.Format(SI_PBSLPF_AGE_DAY, math.floor(seconds / 86400))
end

-- A name as the game gives it, without its grammar markers ("Dro-m'Athra^m" -> "Dro-m'Athra").
function ADDON.CleanName(name)
	if type(name) ~= "string" then
		return ""
	end
	return (zo_strtrim((name:gsub("%^[%a:]+", ""))))
end

local function Lower(text)
	return zo_strlower(text or "")
end

-- Calls a function of the game and returns everything it returns; nil when it is missing or raises.
local function Unwrap(ok, ...)
	if ok then
		return ...
	end
	return nil
end

local function SafeCall(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	return Unwrap(pcall(fn, ...))
end
ADDON.SafeCall = SafeCall

---------------------------------------------------------------------------------------------------
-- The watch list
---------------------------------------------------------------------------------------------------

-- The key the prices of an item are filed under: its search text, whether the name is exact, and the
-- quality when one is demanded.
function ADDON:WatchKey(entry)
	return Lower(entry.text) .. (entry.exact and "!" or "") .. (entry.quality and ("#" .. entry.quality) or "")
end

local LINK_PATTERN = "(|H%d+:item:[^|]*|h[^|]*|h)"

local function TextLength(text)
	if type(ZoUTF8StringLength) == "function" then
		return ZoUTF8StringLength(text)
	end
	return #text
end

local function StripQuotes(text)
	local inner = text:match('^"(.*)"$') or text:match("^“(.*)”$") or text:match("^「(.*)」$")
	if inner then
		return zo_strtrim(inner), true
	end
	return text, false
end

local function QualityName(quality)
	local name = SafeCall(GetString, "SI_ITEMQUALITY", quality)
	if type(name) == "string" and name ~= "" then
		return name
	end
	return tostring(quality)
end

-- The qualities the guild store's Quality drop-down offers, in its order (after "any quality"):
-- Normal, Fine, Superior, Epic, Legendary. The drop-down picks exactly one, not "this or better".
function ADDON.QualityValues()
	return {
		ITEM_DISPLAY_QUALITY_NORMAL or 1,
		ITEM_DISPLAY_QUALITY_MAGIC or 2,
		ITEM_DISPLAY_QUALITY_ARCANE or 3,
		ITEM_DISPLAY_QUALITY_ARTIFACT or 4,
		ITEM_DISPLAY_QUALITY_LEGENDARY or 5,
	}
end

-- nil is "any quality".
function ADDON.QualityName(quality)
	if quality == nil then
		return GetString(SI_PBSLPF_QUALITY_ANY)
	end
	return QualityName(quality)
end

local QUALITY_WORDS = { "normal", "fine", "superior", "epic", "legendary" }
local ANY_WORDS = { any = true, none = true, all = true, ["0"] = true, ["-"] = true, ["指定なし"] = true, ["なし"] = true }

-- What a player types for a quality: a number 1-5, the English word, the game's own word in the client's
-- language, or "any". Returns found, quality (quality nil: any).
function ADDON:ParseQuality(text)
	local word = Lower(zo_strtrim(text or ""))
	if word == "" then
		return false
	end
	if ANY_WORDS[word] or word == Lower(GetString(SI_PBSLPF_QUALITY_ANY)) then
		return true, nil
	end
	local values = ADDON.QualityValues()
	local number = tonumber(word)
	if number and number == math.floor(number) and values[number] then
		return true, values[number]
	end
	for position, value in ipairs(values) do
		if word == QUALITY_WORDS[position] or word == Lower(QualityName(value)) then
			return true, value
		end
	end
	return false
end

-- The guild store saves which entry of its Quality drop-down was chosen: 1 is "any", then the qualities above.
local function QualityFromChoice(choice)
	if type(choice) ~= "number" or choice < 2 then
		return nil
	end
	return ADDON.QualityValues()[choice - 1]
end

-- What the user typed after /lpf add: an item link, "an exact name", or a name (searched the way the
-- game's own name search does, i.e. part of a name matches). Returns entry, or nil and a reason:
-- "usage", or "short" with the minimum number of letters.
function ADDON:ParseItem(argument, defaultQuality)
	argument = zo_strtrim(argument or "")
	if argument == "" then
		return nil, "usage"
	end
	-- A trailing "#epic" (or "#any") demands that quality, whatever an item link says.
	local qualityGiven, demanded = false, nil
	local rest, token = argument:match("^(.-)%s+#([^%s#]+)$")
	if rest and rest ~= "" then
		local found, value = self:ParseQuality(token)
		if not found then
			return nil, "quality", token
		end
		qualityGiven, demanded = true, value
		argument = zo_strtrim(rest)
	end
	local link = argument:match(LINK_PATTERN)
	local entry
	if link then
		local text = SafeCall(GetItemLinkTradingHouseItemSearchName, link)
		local display = SafeCall(GetItemLinkName, link)
		display = ADDON.CleanName(display or "")
		if type(text) ~= "string" or text == "" then
			text = display
		end
		if text == "" then
			return nil, "usage"
		end
		local quality = SafeCall(GetItemLinkDisplayQuality, link)
		entry = {
			text = ADDON.CleanName(text),
			name = display ~= "" and display or ADDON.CleanName(text),
			exact = true,
			quality = type(quality) == "number" and quality or nil,
			link = link,
		}
	else
		local text, exact = StripQuotes(argument)
		if text == "" then
			return nil, "usage"
		end
		entry = { text = text, name = text, exact = exact }
	end
	if qualityGiven then
		entry.quality = demanded
	elseif entry.quality == nil and defaultQuality then
		entry.quality = defaultQuality
	end
	local minimum = SafeCall(GetMinLettersInTradingHouseItemNameForCurrentLanguage) or 3
	if TextLength(entry.text) < minimum then
		return nil, "short", minimum
	end
	return entry
end

-- Puts a parsed item on the watch list, or says why not. Returns true, entry.
function ADDON:AddEntry(entry)
	local watch = self.sv.watch
	local key = self:WatchKey(entry)
	for _, existing in ipairs(watch) do
		if self:WatchKey(existing) == key then
			Print(ADDON.Format(SI_PBSLPF_ADD_DUP, self:WatchLabel(existing)))
			return false
		end
	end
	if #watch >= ADDON.MAX_WATCH then
		Print(ADDON.Format(SI_PBSLPF_ADD_FULL, ADDON.MAX_WATCH))
		return false
	end
	watch[#watch + 1] = entry
	Print(ADDON.Format(SI_PBSLPF_ADD_DONE, self:WatchLabel(entry)))
	return true, entry
end

-- `defaultQuality`: the quality a typed name gets when the text names none (the settings panel's choice).
function ADDON:AddWatch(argument, defaultQuality)
	local entry, reason, extra = self:ParseItem(argument, defaultQuality)
	if not entry then
		if reason == "short" then
			Print(ADDON.Format(SI_PBSLPF_ADD_SHORT, zo_strtrim(argument or ""), extra))
		elseif reason == "quality" then
			Print(ADDON.Format(SI_PBSLPF_QUALITY_UNKNOWN, extra))
		else
			Print(GetString(SI_PBSLPF_ADD_USAGE))
		end
		return false
	end
	return self:AddEntry(entry)
end

-- Changes the quality an item is demanded in (nil: any). The prices kept for the old quality are for a
-- different search and go. Returns true, entry; or false, "none" / "dup", the entry that already has it.
function ADDON:SetWatchQuality(index, quality)
	local watch = self.sv.watch
	local entry = watch[index]
	if not entry then
		return false, "none"
	end
	if entry.quality == quality then
		return true, entry
	end
	local oldKey = self:WatchKey(entry)
	local changed = { text = entry.text, exact = entry.exact, quality = quality }
	local newKey = self:WatchKey(changed)
	for position, other in ipairs(watch) do
		if position ~= index and self:WatchKey(other) == newKey then
			return false, "dup", other
		end
	end
	self.sv.prices[oldKey] = nil
	entry.quality = quality
	return true, entry
end

-- /lpf quality <number or part of a name> <quality>
function ADDON:SetQualityCommand(argument)
	local reference, token = zo_strtrim(argument or ""):match("^(.-)%s*(%S+)$")
	if not reference or reference == "" then
		Print(GetString(SI_PBSLPF_QUALITY_USAGE))
		return false
	end
	local found, quality = self:ParseQuality(token)
	if not found then
		Print(ADDON.Format(SI_PBSLPF_QUALITY_UNKNOWN, token))
		return false
	end
	local index = self:FindWatch(reference)
	if not index then
		Print(ADDON.Format(SI_PBSLPF_REMOVE_NONE, reference))
		return false
	end
	local ok, entry, other = self:SetWatchQuality(index, quality)
	if not ok then
		Print(ADDON.Format(SI_PBSLPF_ADD_DUP, self:WatchLabel(other)))
		return false
	end
	Print(ADDON.Format(SI_PBSLPF_QUALITY_DONE, self:WatchLabel(entry)))
	return true, entry
end

-- "Dreugh Wax (exact name)" / "Fortified Nirncrux (Epic quality only)".
function ADDON:WatchLabel(entry, withoutQuality)
	local tags = {}
	if entry.exact and not entry.link then
		tags[#tags + 1] = GetString(SI_PBSLPF_TAG_EXACT)
	end
	if entry.quality and not withoutQuality then
		tags[#tags + 1] = ADDON.Format(SI_PBSLPF_TAG_QUALITY, QualityName(entry.quality))
	end
	if #tags == 0 then
		return entry.name
	end
	return string.format("%s (%s)", entry.name, table.concat(tags, ", "))
end

-- A number (the position in the list) or part of a name; the exact name wins over a part of one.
function ADDON:FindWatch(reference)
	local watch = self.sv.watch
	local number = tonumber(reference)
	if number then
		number = math.floor(number)
		return watch[number] and number or nil
	end
	local wanted = Lower(zo_strtrim(reference or ""))
	if wanted == "" then
		return nil
	end
	local partial
	for index, entry in ipairs(watch) do
		local name = Lower(entry.name)
		if name == wanted or Lower(entry.text) == wanted then
			return index
		end
		if not partial and (name:find(wanted, 1, true) or Lower(entry.text):find(wanted, 1, true)) then
			partial = index
		end
	end
	return partial
end

function ADDON:RemoveWatch(index)
	local entry = self.sv.watch[index]
	if not entry then
		return false
	end
	self.sv.prices[self:WatchKey(entry)] = nil
	table.remove(self.sv.watch, index)
	return true, entry
end

function ADDON:ClearWatch()
	self.sv.watch = {}
	self.sv.prices = {}
end

function ADDON:ForgetData()
	self.sv.prices = {}
	self.sv.places = { kiosks = {}, guilds = {} }
end

---------------------------------------------------------------------------------------------------
-- The guild store's search history
--
-- Every search the player runs in the guild store is saved by the client (TRADING_HOUSE_SEARCH_HISTORY_MANAGER,
-- in ZO_Ingame_SavedVariables) with the name that was typed and the entry chosen in the Quality drop-down. That
-- is the "copy" of a name searched there: it is read, never changed, and no client function is called.
-- Searches this add-on makes itself never reach it (they do not go through the store's screen).
---------------------------------------------------------------------------------------------------

ADDON.HISTORY_LIMIT = 8

-- The name searches in the history, newest first, as entries ready for the watch list; then how many
-- searches the history holds and how many of those had a name. nil when the history cannot be read.
function ADDON:ReadSearchHistory()
	local manager = _G.TRADING_HOUSE_SEARCH_HISTORY_MANAGER
	local entries = type(manager) == "table" and manager.searchEntries or nil
	if type(entries) ~= "table" then
		return nil
	end
	local list, seen = {}, {}
	local total, named = 0, 0
	for index = #entries, 1, -1 do
		local saved = entries[index]
		local search = type(saved) == "table" and saved.searchTable or nil
		if type(search) == "table" then
			total = total + 1
			local text = search["NameSearch"]
			if type(text) == "string" and zo_strtrim(text) ~= "" then
				named = named + 1
				local entry = self:ParseItem(text)
				if entry then
					entry.quality = QualityFromChoice(search["Quality"])
					local key = self:WatchKey(entry)
					if not seen[key] then
						seen[key] = true
						list[#list + 1] = entry
					end
				end
			end
		end
	end
	return list, total, named
end

-- The text that, typed after /lpf add or into the settings panel's text row, makes this entry again: the name
-- (in quotes when it is exact) and the quality as a trailing #word. A name the store searched at any quality
-- says #any when the panel's default quality would otherwise be put on it.
function ADDON:EntryInputText(entry, defaultQuality)
	local text = entry.exact and ('"' .. entry.text .. '"') or entry.text
	local word
	for position, value in ipairs(ADDON.QualityValues()) do
		if entry.quality == value then
			word = QUALITY_WORDS[position]
		end
	end
	if not word and entry.quality == nil and defaultQuality then
		word = "any"
	end
	return word and (text .. " #" .. word) or text
end

-- What can be added from the history: the searches not on the watch list yet, newest first.
function ADDON:HistoryChoices()
	local list, total, named = self:ReadSearchHistory()
	if not list then
		return nil
	end
	local watched = {}
	for _, entry in ipairs(self.sv.watch) do
		watched[self:WatchKey(entry)] = true
	end
	local choices = {}
	for _, entry in ipairs(list) do
		if not watched[self:WatchKey(entry)] and #choices < ADDON.HISTORY_LIMIT then
			choices[#choices + 1] = entry
		end
	end
	return choices, total, named
end

-- /lpf history lists them; /lpf history <number> watches one.
function ADDON:History(argument)
	argument = zo_strtrim(argument or "")
	local choices, total, named = self:HistoryChoices()
	if not choices then
		Print(GetString(SI_PBSLPF_HISTORY_UNREADABLE))
		if self.scan then
			self.scan:Log("history: TRADING_HOUSE_SEARCH_HISTORY_MANAGER.searchEntries is %s", type(_G.TRADING_HOUSE_SEARCH_HISTORY_MANAGER))
		end
		return false
	end
	if argument ~= "" then
		local number = tonumber(argument)
		local entry = number and choices[math.floor(number)]
		if not entry then
			Print(ADDON.Format(SI_PBSLPF_HISTORY_BAD_NUMBER, argument))
			return false
		end
		return self:AddEntry(entry)
	end
	if #choices == 0 then
		Print(ADDON.Format(SI_PBSLPF_HISTORY_NONE, total, named))
		return false
	end
	Print(GetString(SI_PBSLPF_HISTORY_HEADER))
	for index, entry in ipairs(choices) do
		Print(string.format("%d. %s", index, self:WatchLabel(entry)))
	end
	return true
end

---------------------------------------------------------------------------------------------------
-- Recording and ranking prices
---------------------------------------------------------------------------------------------------

-- listing = { pricePerUnit =, price =, stack =, seller =, name =, link =, left = } or nil when the store
-- had nothing for sale. `now` is a timestamp in seconds; `left` is how long the listing has to run.
function ADDON:RecordPrice(entry, guildId, guildName, listing, now)
	local key = self:WatchKey(entry)
	local byStore = self.sv.prices[key]
	if not byStore then
		byStore = {}
		self.sv.prices[key] = byStore
	end
	if listing then
		-- The trader and place are written down with the price: they are what the answer says, and the game
		-- may not name the trader later.
		local snapshot = self:TraderSnapshot(guildId, now)
		-- a record that replaces an older one keeps what the older one knew when the game says nothing now
		local previous = byStore[guildId]
		if previous then
			snapshot.trader = snapshot.trader or previous.trader
			if not snapshot.loc and not snapshot.zone then
				snapshot.loc, snapshot.zone = previous.loc, previous.zone
			end
		end
		byStore[guildId] = {
			guild = guildName,
			price = listing.pricePerUnit,
			total = listing.price,
			stack = listing.stack,
			seller = listing.seller,
			name = listing.name,
			link = listing.link,
			seen = now,
			expires = (type(listing.left) == "number" and listing.left > 0) and (now + listing.left) or nil,
			trader = snapshot.trader,
			loc = snapshot.loc,
			zone = snapshot.zone,
		}
	else
		byStore[guildId] = { guild = guildName, none = true, seen = now }
	end
end

-- The stores that had the item for sale, cheapest first. A listing whose time has run out is not
-- offered (it is gone, sold or not), and neither is a record older than the age limit.
function ADDON:Ranking(entry, now)
	local byStore = self.sv.prices[self:WatchKey(entry)]
	local list = {}
	if not byStore then
		return list, 0, 0
	end
	local limit = (self.sv.maxAgeDays or 0) * 86400
	local searched, answered = 0, 0
	for guildId, record in pairs(byStore) do
		local fresh = limit <= 0 or (now - record.seen) <= limit
		if fresh then
			searched = searched + 1
			local expired = record.expires and now >= record.expires
			if record.none or not expired then
				answered = answered + 1
			end
			if not record.none and not expired then
				list[#list + 1] = {
					guildId = guildId,
					guild = record.guild or tostring(guildId),
					price = record.price,
					total = record.total,
					stack = record.stack,
					seller = record.seller,
					name = record.name,
					link = record.link,
					seen = record.seen,
					expires = record.expires,
					trader = record.trader,
					loc = record.loc,
					zone = record.zone,
				}
			end
		end
	end
	table.sort(list, function(a, b)
		if a.price ~= b.price then
			return a.price < b.price
		end
		if a.seen ~= b.seen then
			return a.seen > b.seen
		end
		return a.guildId < b.guildId
	end)
	-- `searched`: fresh records, however they turned out; `answered`: those that still hold (a store that had
	-- none, or a listing that has not run out). Nothing answered means the item has to be searched again.
	return list, searched, answered
end

---------------------------------------------------------------------------------------------------
-- Reports
---------------------------------------------------------------------------------------------------

-- One ranked store as a line of chat.
function ADDON:RankLine(rank, row, now)
	return ADDON.Format(
		SI_PBSLPF_RANK_ROW,
		rank,
		ADDON.FormatNumber(row.price),
		ADDON.FormatNumber(row.stack),
		ADDON.FormatNumber(row.total),
		row.guild,
		self:PlaceText(row.guildId, now, false, row),
		ADDON.AgeText(now - row.seen)
	)
end

-- /lpf and /lpf show: for each watched item, its cheapest stores. `limit` is how many stores per item.
-- One item's heading and its cheapest stores. Returns whether any store has it for sale.
function ADDON:PrintItemReport(entry, limit, now)
	Print(ADDON.Format(SI_PBSLPF_ITEM_HEADER, self:WatchLabel(entry)))
	local ranking, searched, answered = self:Ranking(entry, now)
	if #ranking > 0 then
		local shown = limit and math.min(limit, #ranking) or #ranking
		for rank = 1, shown do
			Print(self:RankLine(rank, ranking[rank], now))
		end
		if shown < #ranking then
			Print(ADDON.Format(SI_PBSLPF_MORE_STORES, #ranking - shown))
		end
		return true
	elseif answered > 0 then
		Print("   " .. GetString(SI_PBSLPF_NOT_FOR_SALE))
	elseif searched > 0 then
		Print("   " .. GetString(SI_PBSLPF_RAN_OUT))
	else
		Print("   " .. GetString(SI_PBSLPF_NOT_SEARCHED))
	end
	return false
end

-- /lpf and /lpf show: for each watched item, its cheapest stores. `limit` is how many stores per item.
function ADDON:PrintReport(limit)
	local watch = self.sv.watch
	if #watch == 0 then
		Print(GetString(SI_PBSLPF_LIST_EMPTY))
		return
	end
	local now = GetTimeStamp()
	local anything = false
	for _, entry in ipairs(watch) do
		if self:PrintItemReport(entry, limit, now) then
			anything = true
		end
	end
	if not anything and not next(self.sv.prices) then
		Print(GetString(SI_PBSLPF_NO_DATA))
	end
end

-- /lpf find <name or link>: works anywhere. A guild store can only be searched while a guild trader is
-- open (the game rejects a search otherwise), so this answers from what was recorded, and an item with
-- nothing recorded is put on the watch list and searched at the next guild trader that is opened -- by
-- itself, whatever the automatic search is set to, and without searching again what is fresh.
function ADDON:Find(argument)
	argument = zo_strtrim(argument or "")
	if argument == "" then
		Print(GetString(SI_PBSLPF_FIND_USAGE))
		return
	end
	-- watched already: by name (or part of one), or the same link / quoted name
	local index = self:FindWatch(argument)
	if not index then
		local parsed = self:ParseItem(argument)
		if parsed then
			local key = self:WatchKey(parsed)
			for position, watched in ipairs(self.sv.watch) do
				if self:WatchKey(watched) == key then
					index = position
				end
			end
		end
	end
	if not index then
		if not self:AddWatch(argument) then
			return
		end
		index = #self.sv.watch
	end
	local entry = self.sv.watch[index]
	local now = GetTimeStamp()
	self:PrintItemReport(entry, 3, now)
	local _, _, answered = self:Ranking(entry, now)
	if answered == 0 then
		self.scan:WantNext()
		Print(GetString(SI_PBSLPF_FIND_QUEUED))
	end
	self.panel:Show()
end

function ADDON:PrintList()
	local watch = self.sv.watch
	if #watch == 0 then
		Print(GetString(SI_PBSLPF_LIST_EMPTY))
		return
	end
	for index, entry in ipairs(watch) do
		Print(ADDON.Format(SI_PBSLPF_LIST_ROW, index, self:WatchLabel(entry)))
	end
end

-- The lines of the result panel: { text =, kind = "title" | "head" | "sub" | "dim" }.
ADDON.PANEL_MAX_ITEMS = 5

function ADDON:PanelLines(now)
	local lines = {}
	local title = GetString(SI_PBSLPF_PANEL_TITLE)
	local run = self.scan and self.scan.run
	if run and run.stores and #run.stores > 0 then
		title = title .. "   " .. ADDON.Format(SI_PBSLPF_PANEL_SCANNING, math.min(math.max(run.storeIdx or 0, 1), #run.stores), #run.stores)
	end
	lines[1] = { text = title, kind = "title" }
	local watch = self.sv.watch
	if #watch == 0 then
		lines[2] = { text = GetString(SI_PBSLPF_PANEL_EMPTY), kind = "dim" }
		return lines
	end
	for index, entry in ipairs(watch) do
		if index > ADDON.PANEL_MAX_ITEMS then
			lines[#lines + 1] = { text = ADDON.Format(SI_PBSLPF_PANEL_MORE, #watch - ADDON.PANEL_MAX_ITEMS), kind = "dim" }
			break
		end
		local ranking, searched, answered = self:Ranking(entry, now)
		local best = ranking[1]
		if best then
			lines[#lines + 1] = { text = ADDON.Format(SI_PBSLPF_PANEL_ITEM, entry.name, ADDON.FormatNumber(best.price)), kind = "head" }
			lines[#lines + 1] = { text = "   " .. best.guild .. "  -  " .. self:PlaceText(best.guildId, now, true, best), kind = "sub" }
		elseif answered > 0 then
			lines[#lines + 1] = { text = entry.name .. "   " .. GetString(SI_PBSLPF_NOT_FOR_SALE), kind = "dim" }
		elseif searched > 0 then
			lines[#lines + 1] = { text = entry.name .. "   " .. GetString(SI_PBSLPF_RAN_OUT), kind = "dim" }
		else
			lines[#lines + 1] = { text = entry.name .. "   " .. GetString(SI_PBSLPF_NOT_SEARCHED), kind = "dim" }
		end
	end
	return lines
end
