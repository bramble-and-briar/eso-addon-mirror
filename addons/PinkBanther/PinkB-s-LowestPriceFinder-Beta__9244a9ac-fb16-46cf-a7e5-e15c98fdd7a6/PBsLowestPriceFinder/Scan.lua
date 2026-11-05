PBsLowestPriceFinder = PBsLowestPriceFinder or {}
local ADDON = PBsLowestPriceFinder

---------------------------------------------------------------------------------------------------
-- Searching the guild stores
--
-- Runs while a guild trader is open. For every watched item the game is asked, once, which item
-- names match (MatchTradingHouseItemNames -> a hash per name); then, store by store, a search is run
-- with that name filter, sorted by price per unit, and the cheapest acceptable row is recorded.
-- Only the game's own API is used; nothing of the client's UI is called or wrapped. The client's own
-- trading house reacts to the same events and resets its search screen when the store is switched,
-- which is why the store that was open is selected again at the end.
--
-- It is a state machine moved along by a 100 ms pump and by events:
--
--     match     name -> hashes, one item at a time
--     store     pick the next store; select it when it is not the open one
--     selecting wait until the game reports that store as selected
--     item      pick the next item that has hashes
--     fire      wait out the search cooldown, set the filters, run the search
--     searching wait for the game's answer; retry on an error, record on success
--
-- Everything the game does not answer is waited for with a time limit, so a lost event ends in a
-- skipped step, not a hang. /lpf log lists the last steps.
--
-- UNMEASURED on a console: that an add-on may call these functions at all (the documentation dump
-- marks none of them private, and that marker has been wrong before), the order in which the client's
-- and this add-on's handlers see the store change, and how long the game's search cooldown is.
---------------------------------------------------------------------------------------------------

local scan = { open = false, armed = false, forceNext = false, wantNext = false, probeNext = false, broken = nil }
ADDON.scan = scan

local PUMP_NAME = "PBsLowestPriceFinderPump"
local PUMP_MS = 100
local STATUS_WAIT_MS = 5000 -- no "status received" by then: try anyway
local SETTLE_MS = 800 -- after the trader opens or the store changes, let the client's own handlers finish
local MATCH_TIMEOUT_MS = 6000
local SELECT_TIMEOUT_MS = 6000
local SEARCH_TIMEOUT_MS = 12000
local RETRY_MS = 1500
local MAX_RETRIES = 3
local MAX_PAGES = 3 -- pages looked at for one item in one store when the first rows are all unusable
local LOG_LINES = 120
local PLACE_RETRY_MS = 10000 -- how long a trader that cannot be tied to a store is read again

local unpack = ADDON.unpack
local SafeCall = ADDON.SafeCall

-- The functions of the game this add-on calls in the guild store. /lpf probe asks the game whether
-- any is restricted.
scan.RAW_FUNCTIONS = {
	"MatchTradingHouseItemNames",
	"ClearAllTradingHouseSearchTerms",
	"SetTradingHouseFilter",
	"ExecuteTradingHouseSearch",
	"SelectTradingHouseGuildId",
}

ADDON.log = {}

function scan:Log(format, ...)
	local line = string.format("%7.1f  " .. format, GetFrameTimeMilliseconds() / 1000, ...)
	local log = ADDON.log
	log[#log + 1] = line
	if #log > LOG_LINES then
		table.remove(log, 1)
	end
end

-- A call into the game that must not take the add-on down: false and the error when it raises.
local function Raw(name, ...)
	local fn = _G[name]
	if type(fn) ~= "function" then
		return false, name .. " is missing"
	end
	return pcall(fn, ...)
end

local function Quote(text)
	local open = SafeCall(GetString, SI_TRADING_HOUSE_EXACT_NAME_SEARCH_START_DELIMITER)
	local close = SafeCall(GetString, SI_TRADING_HOUSE_EXACT_NAME_SEARCH_END_DELIMITER)
	if type(open) ~= "string" or open == "" then
		open = '"'
	end
	if type(close) ~= "string" or close == "" then
		close = '"'
	end
	return open .. text .. close
end

---------------------------------------------------------------------------------------------------
-- Which stores
---------------------------------------------------------------------------------------------------

-- The stores to search: the open one first (no switch needed), then the rest the trader offers.
function scan:ListStores()
	local stores, seen = {}, {}
	local function Add(guildId, name)
		if type(guildId) == "number" and guildId > 0 and not seen[guildId] then
			seen[guildId] = true
			if type(name) ~= "string" or name == "" then
				name = ADDON:GuildName(guildId)
			end
			name = ADDON.CleanName(name)
			ADDON:NoteGuildName(guildId, name)
			stores[#stores + 1] = { guildId = guildId, name = name }
		end
	end

	local selected = SafeCall(GetSelectedTradingHouseGuildId)
	if selected then
		local _, name = SafeCall(GetCurrentTradingHouseGuildDetails)
		Add(selected, name)
	end
	local count = SafeCall(GetNumTradingHouseGuilds) or 0
	for index = 1, count do
		local guildId, name = SafeCall(GetTradingHouseGuildDetails, index)
		if guildId and SafeCall(CanBuyFromTradingHouse, guildId) ~= false then
			Add(guildId, name)
		end
	end

	return stores
end

---------------------------------------------------------------------------------------------------
-- Events from the game
---------------------------------------------------------------------------------------------------

function scan:OnOpen()
	local now = GetFrameTimeMilliseconds()
	self.open = true
	self.openedAt = now
	self.statusAt = nil
	self.run = nil
	self.manual = self.forceNext
	self.armed = ADDON.sv.autoScan or self.forceNext or self.wantNext
	self.wantNext = false
	if self.broken and not self.forceNext then
		if self.armed then
			ADDON.bar:Note(GetString(SI_PBSLPF_SCAN_BROKEN), 8, true)
		end
		self.armed = false
	end
	self.forceNext = false
	self:Log("trader opened (armed=%s)", tostring(self.armed))
	ADDON.lastTraderLog = nil
	self.nextPlaceTry = 0
	self.toldUnlinked = false
	self.placeLinked = ADDON:LearnPlace(GetTimeStamp()).linked
	if self.probeNext then
		self.probeNext = false
		ADDON:Probe()
	end
	EVENT_MANAGER:RegisterForUpdate(PUMP_NAME, PUMP_MS, function()
		self:SafePump()
	end)
end

function scan:OnStatus()
	if self.open and not self.statusAt then
		self.statusAt = GetFrameTimeMilliseconds()
		self:Log("status received")
	end
end

-- The trader may not be readable the moment the store opens, so until a store is tied to it (and for a few
-- seconds at most) it is read again every second. If none ever is, the player is told once per session: the
-- place is kept, but no store can be tied to it.
function scan:WatchPlace(now)
	if self.placeLinked then
		return
	end
	if now < self.openedAt + PLACE_RETRY_MS then
		if now >= (self.nextPlaceTry or 0) then
			self.nextPlaceTry = now + 1000
			self.placeLinked = ADDON:LearnPlace(GetTimeStamp()).linked
		end
	elseif not self.toldUnlinked and not ADDON.toldUnlinked then
		self.toldUnlinked = true
		ADDON.toldUnlinked = true
		ADDON.bar:Note(GetString(SI_PBSLPF_PLACE_NOT_LINKED), 12, true)
	end
end

function scan:OnClose()
	ADDON.chatterTrader = nil
	local interrupted = self.run ~= nil
	if interrupted then
		self:Log("trader closed during the search")
		self.run = nil
		ADDON.bar:Note(GetString(SI_PBSLPF_SCAN_CLOSED), 10, true)
	end
	self.open = false
	self.armed = false
	EVENT_MANAGER:UnregisterForUpdate(PUMP_NAME)
	if interrupted then
		-- what was found before the trader closed is still worth reading
		ADDON.panel:Show()
	else
		ADDON.panel:Refresh()
	end
end

function scan:OnMatchComplete(taskId, numResults)
	local run = self.run
	if not run or run.taskId ~= taskId then
		return
	end
	local item = run.items[run.matchIdx]
	local key = ADDON:WatchKey(item)
	local hashes = {}
	if numResults and numResults > 0 then
		local limit = SafeCall(GetMaxTradingHouseFilterExactTerms, TRADING_HOUSE_FILTER_TYPE_NAME_HASH) or numResults
		for index = 1, math.min(numResults, limit) do
			local _, hash = SafeCall(GetMatchTradingHouseItemNamesResult, taskId, index)
			if hash then
				hashes[#hashes + 1] = hash
			end
		end
		if numResults > limit then
			self:Log("%s: %d names match, only %d can be searched", item.text, numResults, limit)
		end
	end
	run.taskId = nil
	if #hashes > 0 then
		run.hashes[key] = hashes
		self.hashCache[key] = hashes
		self:Log("%s: %d name(s) matched", item.text, #hashes)
	else
		run.unmatched[key] = true
		self:Log("%s: no name matched", item.text)
	end
end
scan.hashCache = {}

function scan:OnResponse(responseType, result)
	local run = self.run
	if run and run.state == "searching" and responseType == TRADING_HOUSE_RESULT_SEARCH_PENDING then
		run.got = true
		run.result = result
	end
end

function scan:OnError(errorCode)
	local run = self.run
	if run and run.state == "selecting" then
		self:Log("error event %s while selecting", tostring(errorCode))
	elseif run and run.state == "searching" then
		self:Log("error event %s", tostring(errorCode))
		run.got = true
		run.result = errorCode
	end
end

function scan:OnTimeout(responseType)
	local run = self.run
	if run and run.state == "searching" then
		self:Log("response timeout (%s)", tostring(responseType))
		run.got = true
		run.result = "timeout"
	end
end

---------------------------------------------------------------------------------------------------
-- The pump
---------------------------------------------------------------------------------------------------

function scan:IsReady(now)
	if self.statusAt then
		return now >= self.statusAt + SETTLE_MS
	end
	return now >= self.openedAt + STATUS_WAIT_MS
end

-- Asks for a search now: at once when a trader is open, else at the next one.
function scan:Request()
	self.broken = nil
	if self.open then
		if self.run then
			return
		end
		self.manual = true
		self.armed = true
		ADDON.bar:Note(GetString(SI_PBSLPF_SCAN_NOW), 4)
	else
		self.forceNext = true
		ADDON.bar:Note(GetString(SI_PBSLPF_SCAN_ARMED), 6)
	end
end

-- /lpf find: search what has no answer yet at the next trader (now, if one is open and idle). Unlike
-- Request this leaves out what was searched lately, so it costs a search only for the new item.
function scan:WantNext()
	if self.open and not self.run then
		self.armed = true
	else
		self.wantNext = true
	end
end

function scan:SafePump()
	local ok, err = xpcall(function()
		self:Pump()
	end, function(message)
		-- the full trace goes to /lpf log; the chat gets the first line
		if type(debug) == "table" and type(debug.traceback) == "function" then
			return debug.traceback(tostring(message), 2)
		end
		return tostring(message)
	end)
	if not ok then
		local text = tostring(err)
		for line in text:gmatch("[^\n]+") do
			self:Log("%s", line)
		end
		self:Abort(text:match("^[^\n]*"))
	end
end

function scan:Pump()
	if not self.open then
		return
	end
	local now = GetFrameTimeMilliseconds()
	self:WatchPlace(now)
	local run = self.run
	if not run then
		if self.armed and self:IsReady(now) then
			self:Begin(now)
		end
		return
	end
	if now < (run.waitUntil or 0) then
		return
	end
	self["Step_" .. run.state](self, run, now)
end

function scan:Begin(now)
	self.armed = false
	local manual = self.manual
	self.manual = false
	local watch = ADDON.sv.watch
	if #watch == 0 then
		if manual then
			ADDON.bar:Note(GetString(SI_PBSLPF_SCAN_NO_ITEMS), 8, true)
		end
		return
	end
	local stores = self:ListStores()
	if #stores == 0 then
		ADDON.bar:Note(GetString(SI_PBSLPF_SCAN_NO_STORES), 8, true)
		return
	end
	local items = {}
	for index, entry in ipairs(watch) do
		items[index] = entry
	end

	-- A search that starts by itself leaves out what was searched lately. `fresh[guildId][key]` marks
	-- an item in a store that need not be searched; a store with nothing left to search is not visited
	-- (the open store, which costs no switch, is kept only if it has something to do as well).
	local fresh = {}
	local minutes = ADDON.sv.rescanMinutes or 0
	if not manual and minutes > 0 then
		local stamp = GetTimeStamp()
		local needed = {}
		for _, store in ipairs(stores) do
			local marks, any = {}, false
			for _, entry in ipairs(items) do
				local key = ADDON:WatchKey(entry)
				local record = ADDON.sv.prices[key] and ADDON.sv.prices[key][store.guildId]
				if record and stamp - record.seen < minutes * 60 then
					marks[key] = true
				else
					any = true
				end
			end
			fresh[store.guildId] = marks
			if any then
				needed[#needed + 1] = store
			end
		end
		if #needed == 0 then
			self:Log("everything was searched less than %d minute(s) ago", minutes)
			return
		end
		stores = needed
	end

	local run = {
		state = "match",
		items = items,
		stores = stores,
		fresh = fresh,
		hashes = {},
		unmatched = {},
		matchIdx = 0,
		storeIdx = 0,
		itemIdx = 0,
		original = SafeCall(GetSelectedTradingHouseGuildId),
		searches = 0,
		failures = 0,
		done = 0, -- (store, item) searches finished, whatever came of them
		total = 0, -- how many there will be; known once the names are matched
		started = now,
	}
	-- Names already resolved this session need no new match.
	for _, entry in ipairs(items) do
		local key = ADDON:WatchKey(entry)
		if self.hashCache[key] then
			run.hashes[key] = self.hashCache[key]
		end
	end
	self.run = run
	self:Log("begin: %d store(s), %d item(s), original store %s", #stores, #items, tostring(run.original))
	self:ShowProgress(run)
	ADDON.panel:Show()
end

-- How many items this run still has to search in a store (what has a name match and is not fresh).
function scan:StoreWork(run, store)
	local marks = run.fresh[store.guildId]
	local work = 0
	for _, item in ipairs(run.items) do
		local key = ADDON:WatchKey(item)
		if run.hashes[key] and not (marks and marks[key]) then
			work = work + 1
		end
	end
	return work
end

-- The progress bar: the names are being looked up until the total is known, then done/total with the store.
function scan:ShowProgress(run)
	if run.state == "match" then
		ADDON.bar:Progress(GetString(SI_PBSLPF_BAR_MATCHING), 0)
		return
	end
	local done = math.min(run.done, run.total)
	local store = run.store and run.store.name or ""
	local text = ADDON.Format(SI_PBSLPF_BAR_SEARCHING, done, run.total, store):gsub("%s+$", "")
	ADDON.bar:Progress(text, run.total > 0 and done / run.total or 1)
end

-- Is the item still to be searched in some store of this run?
function scan:IsNeeded(run, item)
	local key = ADDON:WatchKey(item)
	for _, store in ipairs(run.stores) do
		local marks = run.fresh[store.guildId]
		if not (marks and marks[key]) then
			return true
		end
	end
	return false
end

function scan:Step_match(run, now)
	if run.taskId ~= nil then
		if now > run.deadline then
			local item = run.items[run.matchIdx]
			self:Log("%s: name match timed out", item.text)
			run.unmatched[ADDON:WatchKey(item)] = true
			run.taskId = nil
		end
		return
	end
	-- the next item that has no hashes yet
	repeat
		run.matchIdx = run.matchIdx + 1
		local item = run.items[run.matchIdx]
		if not item then
			if next(run.hashes) == nil then
				return self:Finish("nothing to search")
			end
			run.state = "store"
			run.total = 0
			for _, store in ipairs(run.stores) do
				run.total = run.total + self:StoreWork(run, store)
			end
			self:ShowProgress(run)
			return
		end
		if not run.hashes[ADDON:WatchKey(item)] and self:IsNeeded(run, item) then
			local text = item.exact and Quote(item.text) or item.text
			local ok, taskId = Raw("MatchTradingHouseItemNames", text)
			if not ok then
				return self:Abort("MatchTradingHouseItemNames: " .. tostring(taskId))
			end
			if taskId == nil then
				self:Log("%s: the game would not match this text", item.text)
				run.unmatched[ADDON:WatchKey(item)] = true
			else
				run.taskId = taskId
				run.deadline = now + MATCH_TIMEOUT_MS
				return
			end
		end
	until false
end

function scan:Step_store(run, now)
	run.storeIdx = run.storeIdx + 1
	local store = run.stores[run.storeIdx]
	if not store then
		return self:Finish("done")
	end
	run.store = store
	ADDON.panel:Refresh()
	self:ShowProgress(run)
	if SafeCall(GetSelectedTradingHouseGuildId) == store.guildId then
		run.state = "item"
		run.itemIdx = 0
		return
	end
	local ok, success = Raw("SelectTradingHouseGuildId", store.guildId)
	if not ok then
		return self:Abort("SelectTradingHouseGuildId: " .. tostring(success))
	end
	if success == false then
		self:Log("%s: the game would not select this store", store.name)
		run.total = run.total - self:StoreWork(run, store)
		self:ShowProgress(run)
		return -- the next pump takes the next store
	end
	self:Log("selecting %s", store.name)
	run.state = "selecting"
	run.deadline = now + SELECT_TIMEOUT_MS
	run.waitUntil = now + 200
end

function scan:Step_selecting(run, now)
	if SafeCall(GetSelectedTradingHouseGuildId) == run.store.guildId then
		self:Log("%s selected", run.store.name)
		run.state = "item"
		run.itemIdx = 0
		run.waitUntil = now + SETTLE_MS
	elseif now > run.deadline then
		self:Log("%s: not selected in time, skipped", run.store.name)
		run.total = run.total - self:StoreWork(run, run.store)
		self:ShowProgress(run)
		run.state = "store"
	end
end

function scan:Step_item(run, now)
	repeat
		run.itemIdx = run.itemIdx + 1
		local item = run.items[run.itemIdx]
		if not item then
			run.state = "store"
			return
		end
		local key = ADDON:WatchKey(item)
		local marks = run.fresh[run.store.guildId]
		if run.hashes[key] and not (marks and marks[key]) then
			run.page = 0
			run.tries = 0
			run.state = "fire"
			return
		end
	until false
end

function scan:Step_fire(run, now)
	if (SafeCall(GetTradingHouseCooldownRemaining) or 0) > 0 then
		return
	end
	local item = run.items[run.itemIdx]
	local hashes = run.hashes[ADDON:WatchKey(item)]
	if run.page == 0 then
		local ok, err = Raw("ClearAllTradingHouseSearchTerms")
		if not ok then
			return self:Abort("ClearAllTradingHouseSearchTerms: " .. tostring(err))
		end
		local set, success = Raw("SetTradingHouseFilter", TRADING_HOUSE_FILTER_TYPE_NAME_HASH, unpack(hashes))
		if not set then
			return self:Abort("SetTradingHouseFilter: " .. tostring(success))
		end
		if item.quality then
			local qualitySet, qualityOk = Raw("SetTradingHouseFilter", TRADING_HOUSE_FILTER_TYPE_QUALITY, item.quality)
			if not qualitySet or qualityOk == false then
				-- The rows are checked for quality anyway when they are read.
				self:Log("%s: the quality filter was not accepted", item.text)
			end
		end
	end
	local ok, err = Raw("ExecuteTradingHouseSearch", run.page, TRADING_HOUSE_SORT_SALE_PRICE_PER_UNIT, true, run.page > 0)
	if not ok then
		return self:Abort("ExecuteTradingHouseSearch: " .. tostring(err))
	end
	self:Log("search %s in %s (page %d)", item.text, run.store.name, run.page)
	run.got = false
	run.result = nil
	run.state = "searching"
	run.deadline = now + SEARCH_TIMEOUT_MS
end

-- The cheapest usable row on the page the game has just answered with. Returns the listing, whether
-- there are more pages, and how many rows the page had.
function scan:ReadBest(item)
	local count, _, hasMore = SafeCall(GetTradingHouseSearchResultsInfo)
	count = count or 0
	local mine = zo_strlower(SafeCall(GetDisplayName) or "")
	local best
	for index = 1, count do
		local _, name, quality, stack, seller, left, price, currency, _, perUnit = SafeCall(GetTradingHouseSearchResultItemInfo, index)
		local usable = type(price) == "number" and price > 0 and type(name) == "string" and name ~= ""
		usable = usable and (currency == nil or currency == CURT_MONEY)
		usable = usable and (not item.quality or quality == item.quality)
		usable = usable and zo_strlower(seller or "") ~= mine
		if usable then
			stack = (type(stack) == "number" and stack > 0) and stack or 1
			perUnit = type(perUnit) == "number" and perUnit or (price / stack)
			if not best or perUnit < best.pricePerUnit or (perUnit == best.pricePerUnit and price < best.price) then
				best = {
					index = index,
					pricePerUnit = perUnit,
					price = price,
					stack = stack,
					seller = seller,
					name = ADDON.CleanName(name),
					left = left,
				}
			end
		end
	end
	if best then
		best.link = SafeCall(GetTradingHouseSearchResultItemLink, best.index, LINK_STYLE_DEFAULT)
	end
	return best, hasMore and true or false, count
end

function scan:Step_searching(run, now)
	if not run.got then
		if now <= run.deadline then
			return
		end
		self:Log("no answer in time")
		run.got = true
		run.result = "timeout"
	end
	run.got = false
	local item = run.items[run.itemIdx]
	if run.result ~= TRADING_HOUSE_RESULT_SUCCESS then
		run.tries = run.tries + 1
		self:Log("answer %s (try %d)", tostring(run.result), run.tries)
		if run.tries <= MAX_RETRIES then
			run.state = "fire"
			run.page = 0
			run.waitUntil = now + RETRY_MS
			return
		end
		run.failures = run.failures + 1
		run.done = run.done + 1
		self:Log("%s in %s: given up (%s)", item.text, run.store.name, tostring(run.result))
		self:ShowProgress(run)
		run.state = "item"
		return
	end
	run.searches = run.searches + 1
	local best, hasMore, count = self:ReadBest(item)
	local stamp = GetTimeStamp()
	if best then
		self:Log("%s in %s: %s each (%d row(s))", item.text, run.store.name, ADDON.FormatNumber(best.pricePerUnit), count)
		ADDON:RecordPrice(item, run.store.guildId, run.store.name, best, stamp)
		run.state = "item"
	elseif hasMore and run.page + 1 < MAX_PAGES then
		run.page = run.page + 1
		run.state = "fire"
	else
		self:Log("%s in %s: nothing usable (%d row(s))", item.text, run.store.name, count)
		ADDON:RecordPrice(item, run.store.guildId, run.store.name, nil, stamp)
		run.state = "item"
	end
	if run.state == "item" then
		run.done = run.done + 1
		self:ShowProgress(run)
	end
	ADDON.panel:Refresh()
end

---------------------------------------------------------------------------------------------------
-- Ending
---------------------------------------------------------------------------------------------------

-- Puts the store that was open back. The client keeps showing whatever store it believes is selected.
function scan:Restore(run)
	if run and run.original and self.open then
		local current = SafeCall(GetSelectedTradingHouseGuildId)
		if current ~= run.original then
			local ok, success = Raw("SelectTradingHouseGuildId", run.original)
			self:Log("store %s selected again (%s)", tostring(run.original), ok and (success == false and "refused" or "asked") or "failed")
		end
	end
end

-- What the bar says when a run ends: the searches made, the ones given up, the names the game does not know.
function scan:ShowOutcome(run)
	local parts, names = {}, {}
	for _, item in ipairs(run.items) do
		if run.unmatched[ADDON:WatchKey(item)] then
			names[#names + 1] = item.text
		end
	end
	if run.searches > 0 then
		parts[#parts + 1] = ADDON.Format(SI_PBSLPF_SCAN_DONE, run.searches, #run.stores)
	end
	if run.failures > 0 then
		parts[#parts + 1] = ADDON.Format(SI_PBSLPF_SCAN_FAILED, run.failures)
	end
	if #names > 0 then
		parts[#parts + 1] = ADDON.Format(SI_PBSLPF_SCAN_NO_MATCH, table.concat(names, ", "))
	end
	if #parts == 0 then
		ADDON.bar:Hide()
		return
	end
	ADDON.bar:Finish(table.concat(parts, "  "), run.failures > 0 or #names > 0)
end

function scan:Finish(reason)
	local run = self.run
	self.run = nil
	self:Log("finished: %s", tostring(reason))
	self:Restore(run)
	if run then
		self:ShowOutcome(run)
	end
	ADDON.panel:Show()
end

function scan:Abort(message)
	local run = self.run
	self.run = nil
	self.armed = false
	self.broken = tostring(message)
	self:Log("ABORT: %s", tostring(message))
	self:Restore(run)
	ADDON.bar:Note(ADDON.Format(SI_PBSLPF_SCAN_ERROR, tostring(message)), 12, true)
	ADDON.panel:Refresh()
end
