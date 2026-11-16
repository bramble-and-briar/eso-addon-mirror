local A, S = PBS_AUTO_LOOT, PBS_AUTO_LOOT_STRINGS
local em = EVENT_MANAGER

-- ---------------------------------------------------------------------------------------
-- Output
--
-- A message printed at EVENT_ADD_ON_LOADED is thrown away because chat is not up yet, so anything user-facing is
-- either a command response or fires later. A console hides the chat window while a menu is open, and the
-- settings panel is a menu: so every message is also kept in a short log that the panel shows as a label.
-- Note() writes only to that log, Print() also goes to the chat.
-- ---------------------------------------------------------------------------------------

local PREFIX = "|cFF69B4" .. A.chatName .. "|r: "
local LOG_LINES = 6
local NOTICE_GAP_MS = 60000
local LOGIN_DELAY_MS = 8000

A.log = {}

function A:Say(text)
	if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
		CHAT_ROUTER:AddSystemMessage(text)
	elseif CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
		CHAT_SYSTEM:AddMessage(text)
	else
		d(text)
	end
end

function A:Note(text, ...)
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, text, ...)
		text = ok and formatted or text
	end
	local log = self.log
	log[#log + 1] = text
	while #log > LOG_LINES do
		table.remove(log, 1)
	end
	self:RefreshPanel()
end

function A:Print(text, ...)
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, text, ...)
		text = ok and formatted or text
	end
	self:Note(text)
	self:Say(PREFIX .. text)
end

function A:LogText()
	if #self.log == 0 then
		return S.logEmpty
	end
	return table.concat(self.log, "\n")
end

function A:RefreshPanel()
	local panel = self.panel
	if not (panel and panel.selected and panel.UpdateControls) then
		return
	end
	-- only while the library's settings screen is up: its rows are pooled and shared with other add-ons' panels
	local scene = LibHarvensAddonSettings and LibHarvensAddonSettings.scene
	if type(scene) == "table" and type(scene.IsShowing) == "function" and not scene:IsShowing() then
		return
	end
	pcall(panel.UpdateControls, panel)
end

-- A message that matters whatever the "messages" option says, at most once a minute per kind (there are only a
-- few kinds: the table below never grows).
A.noticeAt = {}

function A:Notice(key, text, ...)
	local now = GetGameTimeMilliseconds()
	local last = self.noticeAt[key]
	if last and now - last < NOTICE_GAP_MS then
		return
	end
	self.noticeAt[key] = now
	self:Print(text, ...)
end

-- ---------------------------------------------------------------------------------------
-- Batches
--
-- What the box opener and the binder did is counted here and printed as one line per kind after things have been
-- quiet for a moment, instead of one line per item: ten boxes and a dozen pieces would otherwise be twenty lines.
-- Numbers only, plus the link of the last bound piece.
-- ---------------------------------------------------------------------------------------

A.batch = { opened = 0, openFailed = 0, bound = 0, bindFailed = 0, held = 0, at = 0, first = 0, link = nil }

function A:BatchAdd(key, now)
	local b = self.batch
	b[key] = b[key] + 1
	b.at = now
	if b.first == 0 then
		b.first = now
	end
	self:Wake()
end

function A:StepFlush(now)
	local b = self.batch
	if b.first == 0 then
		return false
	end
	local working = self.boxQ:Count() > 0 or self.bindQ:Count() > 0 or self.open.slot ~= nil or self.bind.slot ~= nil
	if working and now - b.first < self.FLUSH_MAX_MS then
		return true
	end
	if now - b.at < self.FLUSH_QUIET_MS then
		return true
	end

	local show = self.sv.messages
	local function line(text, ...)
		if show then
			self:Print(text, ...)
		else
			self:Note(text, ...)
		end
	end
	if b.opened > 0 then
		line(S.summaryOpened, b.opened)
	end
	if b.openFailed > 0 then
		line(S.summaryOpenFailed, b.openFailed)
	end
	if b.bound == 1 and b.link then
		line(S.summaryBoundOne, b.link)
	elseif b.bound > 0 then
		line(S.summaryBound, b.bound, b.link or "")
	end
	if b.bindFailed > 0 then
		line(S.summaryBindFailed, b.bindFailed)
	end
	if b.held > 0 then
		line(S.summaryHeld, b.held)
	end
	b.opened, b.openFailed, b.bound, b.bindFailed, b.held = 0, 0, 0, 0, 0
	b.at, b.first, b.link = 0, 0, nil
	return false
end

-- ---------------------------------------------------------------------------------------
-- Work that is started by the player or by logging in
-- ---------------------------------------------------------------------------------------

function A:SweepBoxesNow()
	self.manualBoxes = true
	local added = self:SweepBoxes()
	if added > 0 then
		self:Print(S.sweepBoxes, added)
	else
		self:Print(S.sweepBoxesNone)
	end
end

function A:SweepBindsNow()
	self.manualBinds = true
	local added = self:SweepBinds()
	if added > 0 then
		self:Print(S.sweepBind, added)
	else
		self:Print(S.sweepBindNone)
	end
end

-- The sweep that the options ask for a few seconds after the first login of the session.
function A:StepLogin(now)
	local at = self.loginAt
	if not at then
		return false
	end
	if now < at then
		return true
	end
	self.loginAt = nil
	local sv = self.sv
	if sv.boxOnLogin and sv.boxes then
		self:SweepBoxes()
	end
	if sv.collectOnLogin and sv.collect then
		self:SweepBinds()
	end
	return false
end

-- ---------------------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------------------

-- A new item in the backpack: a box to open, or a set piece to bind.
function A:OnSlotUpdate(bagId, slot, stackChange)
	if bagId ~= BAG_BACKPACK or not stackChange or stackChange <= 0 then
		return
	end
	local sv = self.sv
	if not sv then
		return
	end
	local wantBoxes, wantBinds = sv.boxes, sv.collect
	if not (wantBoxes or wantBinds) then
		return
	end
	if self:AtStorage() then
		return
	end
	if wantBoxes and self:IsBoxSlot(slot) then
		self:QueueBox(slot)
	elseif wantBinds and IsItemLockedSetPiece(BAG_BACKPACK, slot) then
		self:QueueBind(slot)
	end
end

-- Loading screens: slot numbers and whatever was in flight are not worth carrying across.
function A:OnDeactivated()
	self.boxQ:Clear()
	self.bindQ:Clear()
	self.open.slot = nil
	self.bind.slot = nil
	self.lootState.attempts = 0
	self.lootState.busy = false
end

-- ---------------------------------------------------------------------------------------
-- /pbal status: what the add-on knows
-- ---------------------------------------------------------------------------------------

local function YesNo(value)
	return value and "on" or "off"
end

function A:StatusLines()
	local lines = {}
	local function add(text, ...)
		lines[#lines + 1] = select("#", ...) > 0 and string.format(text, ...) or text
	end
	local sv = self.sv
	local st = self.stats
	add("%s", self.title)
	add("loot=%s stolen=%s | boxes=%s reserve=%d gap=%d ms onLogin=%s | collect=%s tradeable=%s onLogin=%s | skipLocked=%s messages=%s",
		YesNo(sv.loot), tostring(sv.stolenMode), YesNo(sv.boxes), sv.boxReserve, sv.boxGapMs, YesNo(sv.boxOnLogin), YesNo(sv.collect),
		YesNo(sv.collectTradeable), YesNo(sv.collectOnLogin), YesNo(sv.skipLocked), YesNo(sv.messages))
	for _, group in ipairs({ "loot", "settings", "open", "bind" }) do
		local route, why = self:Route(group)
		local state = self.routes[group] or {}
		local kinds = {}
		for name, kind in pairs(state.kinds or {}) do
			kinds[#kinds + 1] = name .. "=" .. kind
		end
		table.sort(kinds)
		add("%s: %s%s; asked: %s (%s); learned: %s; strikes: %s", group, route or "NOT USED", route and "" or (" - " .. tostring(why)),
			tostring(state.asked), table.concat(kinds, ", "), tostring(sv.probe[group] or "-"), tostring(sv.strikes[group] or 0))
	end
	add("loot windows %d, LootAll calls %d (refused %d, left alone %d) | boxes opened %d, did not open %d, passed over %d | pieces bound %d, failed %d, passed over %d, collected per game %d",
		st.lootWindows, st.lootCalls, st.lootFailed, st.lootGaveUp, st.opened, st.openFailed, st.openSkipped, st.bound, st.bindFailed, st.bindSkipped, st.collected)
	if not self.game.read then
		self:ReadGameSettings()
	end
	local function Reading(value)
		return value == nil and "cannot read" or YesNo(value)
	end
	add("game loot settings: Auto Loot Stolen Items %s, Prevent Stealing Placed Items %s -> stolen items taken now: %s (%s)", Reading(self.game.stolen),
		Reading(self.game.prevent), YesNo(self:TakeStolen()),
		sv.stolenMode == "game" and "following the game" or ("this add-on's own choice: " .. tostring(sv.stolenMode)))
	local ready, reason = self:Ready()
	add("now: box queue %d, bind queue %d, waiting for a box %s, for a bind %s; safe moment: %s%s; queued in total %d boxes / %d pieces, not queued (full) %d",
		self.boxQ:Count(), self.bindQ:Count(), tostring(self.open.slot ~= nil), tostring(self.bind.slot ~= nil), tostring(ready), ready and "" or (" (" .. tostring(reason) .. ")"),
		st.queuedBoxes, st.queuedBinds, st.dropped)
	local okHeap, heap = pcall(collectgarbage, "count")
	add("memory: heap %s KB; ticks %d, timer running %s, errors caught %d, longest queue %d", okHeap and string.format("%.0f", heap) or "?", st.ticks,
		tostring(self.ticking == true), st.errors, st.peakQueue)
	add("last: passed over because \"%s\"; box call \"%s\"; bind call \"%s\"; error \"%s\"", tostring(self.lastSkip or "-"), tostring(self.lastOpenWhy or "-"),
		tostring(self.lastBindWhy or "-"), tostring(self.lastError or "-"))
	local startup = self.startup or {}
	add("left over from the last session: %s; started by: %s; box setting reset to the new default (file from 0.1.0/0.1.1): %s", tostring(startup.stale or "-"),
		tostring(self.boot.init or "?"), tostring(startup.migrated == true))
	return lines
end

function A:PrintStatus()
	for _, line in ipairs(self:StatusLines()) do
		self:Print("%s", line)
	end
end

-- ---------------------------------------------------------------------------------------
-- Commands
-- ---------------------------------------------------------------------------------------

-- ASCII only, byte by byte: a command is typed text, and a character class would ask the C library about bytes.
local function Words(text)
	local words = {}
	for word in tostring(text or ""):gmatch("[^ ]+") do
		words[#words + 1] = word
	end
	return words
end

local function LowerAscii(text)
	return (tostring(text or ""):gsub("[A-Z]", string.lower))
end

function A:PrintHelp()
	for line in S.help:gmatch("[^\n]+") do
		self:Print("%s", line)
	end
end

local SWITCHES = {
	loot = { key = "loot", label = "loot" },
	boxes = { key = "boxes", label = "boxes" },
	collect = { key = "collect", label = "collect" },
}

function A:Command(input)
	local words = Words(input)
	local verb = LowerAscii(words[1])

	if verb == "" or verb == "help" then
		self:PrintHelp()
	elseif SWITCHES[verb] then
		local value = LowerAscii(words[2])
		if value == "on" or value == "off" then
			local def = SWITCHES[verb]
			self:Set(def.key, value == "on")
			self:Print(value == "on" and S.optionOn or S.optionOff, def.label)
		else
			self:PrintHelp()
		end
	elseif verb == "stolen" then
		local mode = LowerAscii(words[2])
		if mode == "game" or mode == "take" or mode == "leave" then
			self:Set("stolenMode", mode)
			self:Print(S.stolenSet, S["stolen_" .. mode])
		else
			self:PrintHelp()
		end
	elseif verb == "reserve" then
		local n = tonumber(words[2])
		if n then
			self:Set("boxReserve", n)
			self:Print(S.reserveSet, self.sv.boxReserve)
		else
			self:PrintHelp()
		end
	elseif verb == "open" then
		self:SweepBoxesNow()
	elseif verb == "bind" then
		self:SweepBindsNow()
	elseif verb == "status" then
		self:PrintStatus()
	elseif verb == "retry" then
		self:Retry()
		self:Print(S.retried)
	elseif verb == "boot" then
		if PBS_AL_BOOT then
			PBS_AL_BOOT.Print()
		end
	else
		self:PrintHelp()
	end
end

-- ---------------------------------------------------------------------------------------
-- Start-up
--
-- Start-up proper happens once, at whichever comes first: the game announcing this add-on, or the player becoming
-- active. The second is a fallback for an announcement that never comes under the name the add-on expects (a folder
-- that was renamed on its way to the console); Boot.lua's trace says which it was.
-- ---------------------------------------------------------------------------------------

A.boot = PBS_AL_BOOT or { files = {}, like = {}, announced = 0, activated = 0 }
local boot = A.boot

-- A handler that cannot raise: an error in here would reach the game as an error screen.
local function Guard(fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then
			A.stats.errors = A.stats.errors + 1
			A.lastError = tostring(err)
		end
	end
end

local function OnLootUpdated()
	A:OnLootUpdated()
end
local function OnLootClosed()
	A:OnLootClosed()
end
local function OnLootItemFailed()
	A:OnLootItemFailed()
end
local function OnSlotUpdate(_, bagId, slotIndex, _, _, _, stackChange)
	A:OnSlotUpdate(bagId, slotIndex, stackChange)
end
local function OnCollectionUpdated()
	A.stats.collected = A.stats.collected + 1
end
local function OnDeactivated()
	A:OnDeactivated()
end
local function OnSettingChanged(_, systemType)
	A:OnSettingChanged(systemType)
end

local function Step(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		A.stats.errors = A.stats.errors + 1
		A.lastError = name .. ": " .. tostring(err)
	end
	return ok
end

function A:Init(how)
	if self.initialised then
		return
	end
	self.initialised = true
	boot.init = how

	Step("saved variables", function()
		self.sv = ZO_SavedVars:NewAccountWide(self.savedVar, 1, nil, self.defaults)
	end)
	-- Without them the add-on still runs, on defaults it cannot save.
	if not self.sv then
		self.sv = {}
		for key, value in pairs(self.defaults) do
			self.sv[key] = value
		end
	end
	Step("checking the saved data", self.Sanitize, self)
	Step("box types", self.ResolveBoxTypes, self)
	Step("settings panel", self.InitSettings, self)

	Step("commands", function()
		local function command(input)
			local ok, err = pcall(self.Command, self, input)
			if not ok then
				self.stats.errors = self.stats.errors + 1
				self.lastError = tostring(err)
				self:Print("error: " .. tostring(err))
			end
		end
		SLASH_COMMANDS[self.slash] = command
		SLASH_COMMANDS[self.shortSlash] = command
	end)

	-- The client's own loot handler was registered when its files ran, before this add-on's: ours runs second.
	Step("loot events", function()
		em:RegisterForEvent(self.name .. "Loot", EVENT_LOOT_UPDATED, Guard(OnLootUpdated))
		em:RegisterForEvent(self.name .. "LootClosed", EVENT_LOOT_CLOSED, Guard(OnLootClosed))
		em:RegisterForEvent(self.name .. "LootFailed", EVENT_LOOT_ITEM_FAILED, Guard(OnLootItemFailed))
	end)
	Step("inventory events", function()
		local name = self.name .. "Slot"
		em:RegisterForEvent(name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, Guard(OnSlotUpdate))
		-- the game filters before it calls Lua: only the backpack, and only an item arriving or leaving
		pcall(em.AddFilterForEvent, em, name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK,
			REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
	end)
	Step("setting event", function()
		local name = self.name .. "Setting"
		em:RegisterForEvent(name, EVENT_INTERFACE_SETTING_CHANGED, Guard(OnSettingChanged))
		-- only the loot settings (the handler compares again, in case the filter is not accepted)
		pcall(em.AddFilterForEvent, em, name, EVENT_INTERFACE_SETTING_CHANGED, REGISTER_FILTER_SETTING_SYSTEM_TYPE, SETTING_TYPE_LOOT)
	end)
	Step("collection event", function()
		em:RegisterForEvent(self.name .. "Collection", EVENT_ITEM_SET_COLLECTION_UPDATED, Guard(OnCollectionUpdated))
	end)
	Step("screen events", function()
		em:RegisterForEvent(self.name .. "Off", EVENT_PLAYER_DEACTIVATED, Guard(OnDeactivated))
	end)
end

function A:OnActivated()
	if not self.sv then
		return
	end
	-- the settings are read again after every loading screen (the first loot window asks, not this)
	self.game.read = false
	if not self.loginScheduled then
		self.loginScheduled = true
		if (self.sv.boxOnLogin and self.sv.boxes) or (self.sv.collectOnLogin and self.sv.collect) then
			self.loginAt = GetGameTimeMilliseconds() + LOGIN_DELAY_MS
			self:Wake()
		end
	end
	if not self.bannerShown then
		self.bannerShown = true
		self:Print(S.bannerLine, self.title)
		if boot.init ~= "EVENT_ADD_ON_LOADED" then
			self:Print("started late, by " .. tostring(boot.init) .. ": the game did not announce this add-on as \"" .. self.name
				.. "\" (/pbal boot says what it did announce)")
		end
		if self.lastError then
			self:Print("error - " .. self.lastError)
		end
	end
end

-- Registered here, at file load, so that start-up can be started (and traced) from either.
em:RegisterForEvent(A.name, EVENT_ADD_ON_LOADED, Guard(function(_, name)
	boot.announced = boot.announced + 1
	if name == A.name then
		boot.ours = true
		A:Init("EVENT_ADD_ON_LOADED")
	elseif boot.Looks and boot.Looks(name) and #boot.like < 8 then
		boot.like[#boot.like + 1] = tostring(name)
	end
end))
em:RegisterForEvent(A.name, EVENT_PLAYER_ACTIVATED, Guard(function()
	boot.activated = boot.activated + 1
	if not A.initialised then
		A:Init("EVENT_PLAYER_ACTIVATED (fallback)")
	end
	A:OnActivated()
end))

PBS_AL_MARK("Main")
