local A, S = PBS_CRAFT_ASSIST, PBS_CRAFT_ASSIST_STRINGS
local B = PBS_CA_BOOT
local em = EVENT_MANAGER

-- ---------------------------------------------------------------------------------------
-- Output
--
-- A message printed at EVENT_ADD_ON_LOADED is thrown away (chat is not up yet), and a console hides the chat window
-- while a menu is open; so every message is also kept in a short log that the settings panel shows.
-- ---------------------------------------------------------------------------------------

local PREFIX = "|cFF69B4" .. A.chatName .. "|r: "
local LOG_LINES = 6
local NOTICE_GAP_MS = 60000

A.log = {}

function A:Say(text)
	B.Say(text)
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
	return text
end

-- A line for the log, and for the chat only when the "messages" option is on (off by default since 0.1.2: PB asked
-- for no chat output; the panel and the settings log say what happened).
function A:Print(text, ...)
	text = self:Note(text, ...)
	if self.sv == nil or self.sv.messages then
		self:Say(PREFIX .. text)
	end
end

-- A line that is always printed (a command's answer).
function A:Answer(text, ...)
	text = self:Note(text, ...)
	self:Say(PREFIX .. text)
end

-- A problem: the log always; the chat only when "messages" is on, and then at most once a minute per kind.
A.noticeAt = {}
function A:Notice(key, text, ...)
	local now = GetGameTimeMilliseconds()
	local last = self.noticeAt[key]
	if not (self.sv and self.sv.messages) or (last and now - last < NOTICE_GAP_MS) then
		self:Note(text, ...)
		return
	end
	self.noticeAt[key] = now
	self:Answer(text, ...)
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
	local scene = LibHarvensAddonSettings and LibHarvensAddonSettings.scene
	if type(scene) == "table" and type(scene.IsShowing) == "function" and not scene:IsShowing() then
		return
	end
	pcall(panel.UpdateControls, panel)
end

-- ---------------------------------------------------------------------------------------
-- Commands
-- ---------------------------------------------------------------------------------------

function A:OpenNow()
	local n = self:SweepBoxes()
	if n > 0 then
		self:Answer(S.sweepSome, n)
	else
		self:Answer(S.sweepNone)
	end
end

local function RouteText(group)
	local route, why = A:Route(group)
	local state = A.routes[group]
	return string.format("%s (%s; asked: %s)", route or "OFF", why or "ok", state and state.asked or "?")
end

function A:StatusLines()
	local lines = {}
	local st, sv = self.stats, self.sv
	local total, ready = self:CountWrits()
	local open = self:Scan()
	local words = self:Words()
	lines[#lines + 1] = string.format("%s, language %s (%s)", self.title, tostring(self.lang),
		words and "conversation words known" or "NO conversation words: talk is not automated")
	lines[#lines + 1] = string.format("writs in the journal %d (ready to hand in %d), open lines %d", total, ready, open)
	for i = 1, math.min(open, 8) do
		local r = self.lines[i]
		lines[#lines + 1] = string.format("  q%d c%d %s item %d mat %d craft %s q%d %d/%d station %s", r.quest, r.cond, r.kind,
			r.itemId, r.materialItemId, tostring(r.craftType), r.quality, r.cur, r.max, tostring(self:StationFor(r)))
	end
	local c, info = self.craft, self.scanInfo
	lines[#lines + 1] = string.format("journal: crafting writs %d, conditions %d (craft %d, gather %d, other %d first type %s, no item %d)",
		info.quests, info.conditions, info.craft, info.gather, info.other, tostring(info.otherType), info.noItem)
	lines[#lines + 1] = string.format("last station event: craft %s mode %s %s; lines here %d, other stations %d, switched off %d; state %s",
		tostring(c.eventSkill), tostring(c.eventMode), c.eventAt and string.format("%.0f s ago", (GetGameTimeMilliseconds() - c.eventAt) / 1000) or "never",
		c.diagHere, c.diagOther, c.diagOff, tostring(c.state))
	lines[#lines + 1] = string.format("talk: accepted %d, delivered %d, completed %d (all time %d)", st.accepted, st.delivered,
		st.completed, sv.totals.writs)
	lines[#lines + 1] = string.format("craft: items %d in %d calls, failed %d (all time %d)", st.crafted, st.craftCalls,
		st.craftFailed, sv.totals.crafted)
	lines[#lines + 1] = string.format("bank: moved %d, refused %d; move route %s", st.moved, st.moveFailed, RouteText("move"))
	local ids = 0
	for _ in pairs(sv.boxIds) do
		ids = ids + 1
	end
	lines[#lines + 1] = string.format("boxes: opened %d, not opened %d, looted %d, learned box ids %d; open route %s", st.opened,
		st.openFailed, st.looted, ids, RouteText("open"))
	self:BoxTraceLines(lines)
	if self.startup and self.startup.stale then
		lines[#lines + 1] = "at login a call was still marked pending: " .. tostring(self.startup.stale)
	end
	lines[#lines + 1] = string.format("errors %d%s; Lua memory %.0f KB", st.errors,
		self.lastError and (" (last: " .. self.lastError .. ")") or "", collectgarbage("count"))
	return lines
end

function A:PrintStatus()
	for _, line in ipairs(self:StatusLines()) do
		self:Say(line)
	end
end

-- The options of the last conversation (to check the conversation words of a language).
function A:PrintTalk()
	self:Say(string.format("last conversation: %d option(s)", self.talk.lastOptions or 0))
	for i = 1, self.seenCount do
		self:Say(string.format("  %d type %s: %s", i, tostring(self.seenType[i]), tostring(self.seenText[i])))
	end
end

function A:Command(text)
	local word = tostring(text or ""):match("^[ \t]*([^ \t]*)") or ""
	if word == "open" then
		self:OpenNow()
	elseif word == "talk" then
		self:PrintTalk()
	elseif word == "craft" then
		if self.craft.station then
			self:Answer(S.craftAgain)
			self.craft.round = 0
			self:Later("craft", self.START_DELAY_MS, "CraftRound")
		else
			self:Answer(S.notAtStation)
		end
	elseif word == "retry" then
		self:Retry()
		self:Answer(S.retried)
	elseif word == "trace" then
		B.Print()
	else
		self:PrintStatus()
		self:Say("/pbwrit open | talk | craft | retry | trace")
	end
end

-- ---------------------------------------------------------------------------------------
-- Events: one handler per event, created once, each under pcall
-- ---------------------------------------------------------------------------------------

local function Guard(ok, err)
	if not ok then
		A:NoteError(err)
	end
end

-- (a missing event constant must not stop the file: the table is filled entry by entry)
local handlers = {}
local function On(event, fn)
	if event then
		handlers[event] = fn
	end
end
On(EVENT_CHATTER_BEGIN, function(_, optionCount)
	Guard(pcall(A.OnChatterBegin, A, optionCount))
end)
On(EVENT_CHATTER_END, function()
	Guard(pcall(A.OnChatterEnd, A))
end)
On(EVENT_QUEST_OFFERED, function()
	Guard(pcall(A.OnQuestOffered, A))
end)
On(EVENT_QUEST_COMPLETE_DIALOG, function(_, journalIndex)
	Guard(pcall(A.OnQuestCompleteDialog, A, journalIndex))
end)
On(EVENT_QUEST_COMPLETE, function(_, _, _, _, _, _, questType)
	Guard(pcall(A.OnQuestComplete, A, questType))
end)
On(EVENT_CRAFTING_STATION_INTERACT, function(_, craftSkill, sameStation, craftMode)
	Guard(pcall(A.OnStationInteract, A, craftSkill, sameStation, craftMode))
end)
On(EVENT_END_CRAFTING_STATION_INTERACT, function()
	Guard(pcall(A.OnStationEnd, A))
end)
On(EVENT_CRAFT_COMPLETED, function()
	Guard(pcall(A.OnCraftCompleted, A))
end)
On(EVENT_CRAFT_FAILED, function(_, result)
	Guard(pcall(A.OnCraftFailed, A, result))
end)
On(EVENT_OPEN_BANK, function(_, bankBag)
	Guard(pcall(A.OnOpenBank, A, bankBag))
end)
On(EVENT_CLOSE_BANK, function()
	Guard(pcall(A.OnCloseBank, A))
end)
On(EVENT_QUEST_CONDITION_COUNTER_CHANGED, function()
	Guard(pcall(A.PanelRefresh, A))
end)
On(EVENT_LOOT_CLOSED, function()
	Guard(pcall(A.OnLootClosed, A))
end)

local function OnSlotUpdate(_, bag, slot, isNew, _, _, stackChange)
	Guard(pcall(A.OnSlotUpdate, A, bag, slot, isNew, stackChange))
end

-- ---------------------------------------------------------------------------------------
-- Start-up
-- ---------------------------------------------------------------------------------------

local function Step(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		A.startErrors = A.startErrors or {}
		A.startErrors[#A.startErrors + 1] = name .. ": " .. tostring(err)
		A:NoteError(err)
	end
end

function A:Start(how)
	if self.started then
		return
	end
	self.started = true
	B.init = how
	Step("saved variables", function()
		self.sv = ZO_SavedVars:NewAccountWide(self.savedVar, 1, nil, self.defaults)
		self:Sanitize()
	end)
	if not self.sv then
		-- without saved variables nothing can be guarded: stay off
		return
	end
	Step("craft keys", function()
		self:BuildCraftKeys()
	end)
	Step("reward flavour texts", function()
		self:RewardFlavors()
	end)
	Step("reward loot window", function()
		self:InitRewardLoot()
	end)
	Step("events", function()
		for event, fn in pairs(handlers) do
			if event then
				em:RegisterForEvent(self.name, event, fn)
			end
		end
		em:RegisterForEvent(self.name .. "Slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnSlotUpdate)
		em:AddFilterForEvent(self.name .. "Slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
	end)
	Step("settings", function()
		self:InitSettings()
	end)
	Step("commands", function()
		local function command(text)
			local ok, err = pcall(A.Command, A, text)
			if not ok then
				A:NoteError(err)
				A:Say(PREFIX .. tostring(err))
			end
		end
		SLASH_COMMANDS[self.shortSlash] = command
		SLASH_COMMANDS[self.slash] = command
	end)
end

local function OnAddOnLoaded(_, name)
	B.announced = B.announced + 1
	if name ~= A.name then
		return
	end
	B.ours = true
	em:UnregisterForEvent(A.name .. "Load", EVENT_ADD_ON_LOADED)
	A:Start("EVENT_ADD_ON_LOADED")
end

local function OnPlayerActivated()
	B.activated = B.activated + 1
	if not A.started then
		A:Start("EVENT_PLAYER_ACTIVATED (fallback)")
	end
	if not A.sv then
		return
	end
	if not A.greeted then
		A.greeted = true
		A:Print(S.banner, A.title)
		if A.startErrors then
			-- kept for /pbwrit trace and the settings log, not said in the chat
			for _, line in ipairs(A.startErrors) do
				A:Note("start-up step failed - " .. line)
			end
		end
		if A.sv.boxes and A.sv.boxOnLogin then
			A:SweepBoxes()
		end
	end
	-- a loading screen ends any station, bank or conversation
	A.craft.station, A.craft.awaiting = nil, nil
	A.talk.offerAt, A.talk.deliverAt, A.talk.tookHere = nil, nil, 0
end

em:RegisterForEvent(A.name .. "Load", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
em:RegisterForEvent(A.name .. "Activated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

PBS_CA_MARK("Main")
