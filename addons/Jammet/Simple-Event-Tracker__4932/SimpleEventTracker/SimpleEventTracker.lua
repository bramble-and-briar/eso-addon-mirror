-- Simple Event Tracker: tracks the account's daily Trade Bars and tells you when an event is running.
-- Credits: original Event Tracker by Kelinmiriel; this rewrite by Jammet / Claude AI assisted.
--   /sevti  event info + today's bars        /sevt  trade bar status, recent days, totals
--   Both take the same options; see "/sevt help".  /sevtsize 1-5 sets the label text size.
--
-- The game exposes no event data, so an event counts as running while trade bars keep being collected.
-- When one is detected, the player is told once and offered to enter its name and time left (/sevt event
-- opens a prompt pre-filled from an active Golden Pursuit), which enables the event name, days left and
-- the login announcement. Nothing is ever forced on the player.

SimpleEventTracker = SimpleEventTracker or {}   -- the addon's only global table (XML and key bindings call into it)
local SET = SimpleEventTracker

local NAME       = "SimpleEventTracker"
local HOUR, DAY  = 3600, 86400
local KEEP_DAYS  = 60          -- day records kept in the saved variables
local SATCHEL_ID = 224673      -- "Trade Bar Satchel"
local RECENT     = 30 * HOUR   -- trade bars collected this recently mean an event is running
local UNNAMED    = "Event"     -- name used while an event is detected but its details are unknown

local defaults = {
	days       = {},   -- { t = start, e = end (= next reset), bars = n, done = bool, ev = event name }
	total      = 0,    -- all trade bars collected while tracked
	event      = {},   -- the player's event details: name, endT (nil = until the bars stop), setAt
	lastBars   = 0,    -- when trade bars were last collected
	streakStart = 0,   -- when the current run of daily collections began
	asked      = "",   -- which situation the player was already asked about
	wait       = {},   -- start of the day of each satchel looted but not yet opened
	ui         = { hidden = false, size = 4 },   -- size: 1 (largest) .. 5 (smallest)
	paused     = false, -- the player turned event tracking off (/sevt pause)
	dismissed  = 0,     -- streakStart of a run of collections the player told us to disregard
}

local db, label, icon, startButton, fragment

local updateUI, announce   -- defined further down

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function chat(text)
	CHAT_ROUTER:AddSystemMessage(text)
end

local function say(text)
	chat("|c00CCFF[SET]|r " .. text)
end

local function dur(s)
	s = math.max(0, math.floor(s))
	local d, h, m = math.floor(s / DAY), math.floor(s % DAY / HOUR), math.floor(s % HOUR / 60)
	if d > 0 then return string.format("%dd %dh", d, h) end
	if h > 0 then return string.format("%dh %dm", h, m) end
	return string.format("%dm", m)
end

local function dateStr(ts, short)
	return os.date(short and "%d.%m" or "%d.%m.%Y", ts)
end

local function plural(n, one, many)
	return n == 1 and one or many
end

---------------------------------------------------------------------------
-- day records (one per daily reset period)
---------------------------------------------------------------------------
-- Timestamp of the next daily reset; extends the known 24h cycle if the game timer isn't ready yet.
local function nextReset(now)
	local s = GetTimeUntilNextDailyLoginRewardClaimS()
	if s and s > 0 and s <= DAY + 120 then return now + s end
	local last = db.days[#db.days]
	return last and last.e + (math.floor((now - last.e) / DAY) + 1) * DAY
end

-- The current day record; created on demand unless create == false.
local function today(create)
	local now = GetTimeStamp()
	local d = db.days[#db.days]
	if d and now < d.e then return d end
	local e = create ~= false and nextReset(now)
	if not e then return nil end
	d = { t = e - DAY, e = e, bars = 0, done = false }
	db.days[#db.days + 1] = d
	while #db.days > KEEP_DAYS do table.remove(db.days, 1) end
	return d
end

---------------------------------------------------------------------------
-- event detection and details
---------------------------------------------------------------------------
-- Trade bars arrived recently, and after the end of any event the player recorded.
local function inferred()
	if db.paused or db.dismissed == db.streakStart then return false end
	local t = db.lastBars
	if GetTimeStamp() - t >= RECENT then return false end
	return not (db.event.endT and t <= db.event.endT)
end

-- The current or most recent event, and whether it is running right now.
local function getEvent()
	if db.paused then return nil, false end
	local e, now = db.event, GetTimeStamp()
	if e.endT and now < e.endT then return e, true end
	-- details without an end date, given during this run of collections: running until the bars stop
	local open = e.name and not e.endT and e.setAt >= db.streakStart
	if open and now - math.max(db.lastBars, e.setAt) < RECENT then return e, true end
	if inferred() then return { name = UNNAMED }, true end
	return e.name and e or nil, false
end

-- An event is running but the player hasn't told us which one (or the recorded one is over).
local function needsDetails()
	if not inferred() then return false end
	local e = db.event
	if e.endT then return GetTimeStamp() >= e.endT end
	return not (e.setAt and e.setAt >= db.streakStart)
end

-- Best guess from the active Golden Pursuit. Pursuits don't always match an event, so it is only a suggestion.
local function suggestion()
	local name, remain
	for i = 1, GetNumActivePromotionalEventCampaigns() do
		local key = GetActivePromotionalEventCampaignKey(i)
		local left = GetSecondsRemainingInPromotionalEventCampaign(key)
		local personal = IsReturningPlayerPromotionalEventsCampaign(key) or IsLowLevelPlayerPromotionalEventsCampaign(key)
		if left > 0 and not personal and (not remain or left < remain) then
			local campaignId = GetPromotionalEventCampaignInfo(key)
			name, remain = zo_strformat("<<1>>", GetPromotionalEventCampaignDisplayName(campaignId)), left
		end
	end
	return name, remain
end

local UNITS = { d = DAY, day = DAY, days = DAY, h = HOUR, hr = HOUR, hrs = HOUR, hour = HOUR, hours = HOUR,
	m = 60, min = 60, mins = 60, minute = 60, minutes = 60 }

-- "Name 5d 4h" -> name, seconds left. The time is the number+unit groups (d/h/m, days, hours, minutes) at the
-- end of the text, the rest is the name. Either part may be missing (nil). A lone number alone means days.
local function parseDetails(text)
	local rest, secs = text:match("^%s*(.-)%s*$"), 0
	while true do
		local head, n, unit = rest:match("^(.-)%s*(%d+)%s*(%a+)$")
		local mult = unit and UNITS[unit:lower()]
		if not mult then break end
		secs, rest = secs + tonumber(n) * mult, head
	end
	if secs == 0 and rest:match("^%d+$") then secs, rest = tonumber(rest) * DAY, "" end
	return rest ~= "" and rest or nil, secs > 0 and secs or nil
end

local function saveEvent(name, secs)
	name = name or db.event.name or UNNAMED   -- no name given: keep the current one
	local now = GetTimeStamp()
	db.event = { name = name, endT = secs and now + secs or nil, setAt = now }
	for _, d in ipairs(db.days) do   -- name the days already collected during this run
		if d.ev == UNNAMED and d.e > db.streakStart then d.ev = name end
	end
	say(string.format("Event saved: |cFFD700%s|r%s", name, secs and (" - " .. dur(secs) .. " left.") or "."))
	updateUI()
end

-- The entry window (SimpleEventTrackerEdit in the XML): name plus days, hours and minutes left. It is filled in
-- from the recorded event or the Golden Pursuit suggestion, and only ever opened by the player's own action.
local editWin, editFragment

local function editBox(part)
	return editWin:GetNamedChild(part):GetNamedChild("Edit")
end

local function closePrompt()
	SCENE_MANAGER:GetScene("hudui"):RemoveFragment(editFragment)
end

local function openPrompt()
	local e, name, secs = db.event, "", 0
	if e.name and e.endT and e.endT > GetTimeStamp() then
		name, secs = e.name, e.endT - GetTimeStamp()
	else
		local sName, remain = suggestion()
		if sName then name, secs = sName, remain or 0 end
	end
	editBox("Name"):SetText(name)
	editBox("Days"):SetText(secs >= DAY and tostring(math.floor(secs / DAY)) or "")
	editBox("Hours"):SetText(secs >= HOUR and tostring(math.floor(secs % DAY / HOUR)) or "")
	editBox("Minutes"):SetText(secs > 0 and tostring(math.floor(secs % HOUR / 60)) or "")
	SCENE_MANAGER:GetScene("hudui"):AddFragment(editFragment)
	SCENE_MANAGER:SetInUIMode(true)
	editBox("Name"):TakeFocus()
end

function SET.EditSave()
	local name = editBox("Name"):GetText():match("^%s*(.-)%s*$")
	local secs = (tonumber(editBox("Days"):GetText()) or 0) * DAY + (tonumber(editBox("Hours"):GetText()) or 0) * HOUR
		+ (tonumber(editBox("Minutes"):GetText()) or 0) * 60
	closePrompt()
	saveEvent(name ~= "" and name or nil, secs > 0 and secs or nil)
end

function SET.EditCancel()
	closePrompt()
end

-- Once per detected event (a new run of collections, or the end of a recorded event): a small alert at the top
-- of the screen plus a friendly chat line offering the prompt. Returns true if it told the player.
local function offerDetails()
	if not needsDetails() then return false end
	local key = db.streakStart .. ":" .. (db.event.endT or 0)
	if db.asked == key then return false end
	db.asked = key
	ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.NONE, "<<1>>", "Simple Event Tracker: new event found!")
	say("Looks like a new event is on! Click |cFFD700Start Event Tracking|r on the widget or type |cFFD700/sevt event|r to add its name and time left.")
	return true
end

local function refresh()
	local ev, on = getEvent()
	local d = today(false)
	if d and on and not d.ev then d.ev = ev.name end
	updateUI()
end

---------------------------------------------------------------------------
-- trade bar tracking
---------------------------------------------------------------------------
local function collected(amount)
	local d = today()
	if not d then return end

	local now = GetTimeStamp()
	if now - db.lastBars >= RECENT then db.streakStart = now end
	db.lastBars = now
	local ev = getEvent()
	d.ev = d.ev or (ev and ev.name)

	local first = not d.done
	d.done = true
	if amount and amount > 0 then
		d.bars = d.bars + amount
		db.total = db.total + amount
	end
	if not db.paused and (first or (amount and amount > 0)) then
		say("|c00FF00Trade bars collected|r" .. (d.bars > 0 and string.format(" (%d today)", d.bars) or "") .. " - done for today.")
	end
	updateUI()
	offerDetails()
end

-- A looted Trade Bar Satchel is the day's collection; its bars arrive when it is opened.
local function onLoot(_, _, _, _, _, _, isSelf, _, _, itemId)
	if not (isSelf and itemId == SATCHEL_ID) then return end
	local d = today()
	if d then db.wait[#db.wait + 1] = d.t end
	collected(0)
end

local function onCurrency(_, currencyType, location, newAmount, oldAmount, reason)
	local diff = newAmount - oldAmount
	if currencyType ~= CURT_TRADE_BARS or location ~= CURRENCY_LOCATION_ACCOUNT or diff <= 0 then return end

	if reason == CURRENCY_CHANGE_REASON_LOOT_CURRENCY_CONTAINER then   -- satchel opened
		local t, target = table.remove(db.wait, 1)   -- credit the day it was looted
		for _, d in ipairs(db.days) do
			if d.t == t then target = d end
		end
		if not target then return collected(diff) end
		target.bars = target.bars + diff
		db.total = db.total + diff
		updateUI()
		say(string.format("|c00FF00+%d trade bars|r (%d on %s).", diff, target.bars, dateStr(target.t + DAY / 2, true)))
	elseif reason == CURRENCY_CHANGE_REASON_LOOT or reason == CURRENCY_CHANGE_REASON_QUESTREWARD then
		collected(diff)
	end
end

---------------------------------------------------------------------------
-- chat output
---------------------------------------------------------------------------
local function todayLine()
	local d = today()
	if not d then return "Today: waiting for the daily reset timer..." end
	local reset = "|cAAAAAA(resets in " .. dur(d.e - GetTimeStamp()) .. ")|r"
	if d.done then
		return "Today: |c00FF00collected|r" .. (d.bars > 0 and (" " .. d.bars) or "") .. "  " .. reset
	end
	return "Today: |cFF5555NOT collected yet|r  " .. reset
end

local function totalsLine()
	local ev = getEvent()
	local out = ""
	if ev and ev.name ~= UNNAMED then
		local bars, days = 0, 0
		for _, d in ipairs(db.days) do
			if d.ev == ev.name and d.done then bars, days = bars + d.bars, days + 1 end
		end
		out = string.format("%s: %d bars on %d %s.  ", ev.name, bars, days, plural(days, "day", "days"))
	end
	return out .. string.format("All tracked: %d bars.", db.total)
end

local function findDay(t)
	for _, d in ipairs(db.days) do
		if math.abs(d.t - t) < HOUR then return d end
	end
end

-- One line per day, newest first: done, missed (event day without bars), open (today) or none.
local function historyLines(n)
	local out, cur = {}, today(false)
	if not cur then return out end
	for k = 0, n - 1 do
		local t = cur.t - k * DAY
		local d = findDay(t)
		local stamp = dateStr(t + DAY / 2, true)
		local text
		if d and d.done then
			text = string.format("|c00FF00done|r %s  |cAAAAAA%s|r", d.bars > 0 and d.bars or "", d.ev or "")
		elseif k == 0 then
			text = "|cFFFF00open|r"
		elseif d and d.ev then
			text = string.format("|cFF5555missed|r  |cAAAAAA%s|r", d.ev)
		else
			text = "|cAAAAAA-|r"
		end
		out[#out + 1] = "  " .. stamp .. "  " .. text
	end
	return out
end

local function showInfo()
	if db.paused then
		say("Event tracking is paused. Type |cFFD700/sevt pause|r to resume.")
		return
	end
	local ev, on = getEvent()
	if not ev then
		say("No event detected. One is detected when you collect trade bars; you can also enter it with |cFFD700/sevt event|r.")
		return
	end
	say(string.format("|cFFD700%s|r  %s", ev.name, on and "|c00FF00RUNNING|r" or "|cAAAAAAnot running|r"))
	if ev.endT then
		local now = GetTimeStamp()
		say("End " .. dateStr(ev.endT) .. "  -  " ..
			(on and ("|cFFFF00" .. dur(ev.endT - now) .. " left|r") or ("ended " .. dur(now - ev.endT) .. " ago")))
	elseif on then
		say((ev.name == UNNAMED and "Name and time left" or "Time left") .. " unknown: enter them with |cFFD700/sevt event|r.")
	end
	if on then say(todayLine()) end
end

local function showStatus(days)
	say(todayLine())
	for _, line in ipairs(historyLines(days)) do chat(line) end
	say(totalsLine())
end

---------------------------------------------------------------------------
-- on-screen label (only while an event is running)
---------------------------------------------------------------------------
-- Label font sizes by setting. 4 is the default; 3 is the size the addon started with.
local FONT_SIZES = { 26, 22, 18, 13, 11 }   -- 1 = largest ... 5 = smallest

local function applySize()
	local size = FONT_SIZES[db.ui.size] or FONT_SIZES[4]
	local line = math.floor(size * 1.25)
	label:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thin", size))
	label:SetDimensions(size * 20, line * 3 + 4)
	icon:SetDimensions(math.min(56, line * 2), math.min(56, line * 2))
end

local shown = false
local function setShown(want)
	if want == shown then return end
	shown = want
	for _, sceneName in ipairs({ "hud", "hudui" }) do
		local scene = SCENE_MANAGER:GetScene(sceneName)
		if want then scene:AddFragment(fragment) else scene:RemoveFragment(fragment) end
	end
end

function updateUI()
	local ev, on = getEvent()
	if not (on and not db.ui.hidden) then return setShown(false) end

	local now, d = GetTimeStamp(), today()
	local bars
	if not d then
		bars = "|cAAAAAATrade bars: ?|r"
	elseif d.done then
		bars = "Trade bars: |c00FF00done|r" .. (d.bars > 0 and (" (" .. d.bars .. ")") or "")
	else
		bars = "Trade bars: |cFF5555COLLECT|r |cAAAAAA(reset " .. dur(d.e - now) .. ")|r"
	end
	label:SetText(table.concat({
		"|cFFD700" .. ev.name .. "|r",
		ev.endT and ("|cAAAAAA" .. dur(ev.endT - now) .. " left|r") or "|cAAAAAAevent running|r",
		bars,
	}, "\n"))
	startButton:SetHidden(not needsDetails())
	setShown(true)
end

function SET.StartTracking()   -- the widget's "Start Event Tracking" button
	openPrompt()
end

-- Right-click menu on the widget (the game's own context menu). Cancel just closes it.
function SET.OnMouseUp(button, upInside)
	if not (upInside and button == MOUSE_BUTTON_INDEX_RIGHT) then return end
	ClearMenu()
	AddMenuItem("Set up event...", function() SET.StartTracking() end)
	AddMenuItem("Clear event", function() SET.ClearEvent() end)
	AddMenuItem("Trade bar history", function() showStatus(14) end)
	AddMenuItem("Hide widget", function() SET.ToggleUI() end)
	AddMenuItem("Cancel", function() end)
	ShowMenu(SimpleEventTrackerFrame)
end

function SET.ToggleUI()
	db.ui.hidden = not db.ui.hidden
	updateUI()
	say("On-screen label " .. (db.ui.hidden and "hidden." or "shown (only visible while an event runs)."))
end

function SET.OnMoveStop()
	db.ui.left, db.ui.top = SimpleEventTrackerFrame:GetLeft(), SimpleEventTrackerFrame:GetTop()
end

---------------------------------------------------------------------------
-- login announcement: chat line + center-screen text with name, days left, bar status
---------------------------------------------------------------------------
function announce(ev)
	local parts = {}
	if ev.endT then
		local left = ev.endT - GetTimeStamp()
		local days = math.floor(left / DAY)
		parts[#parts + 1] = days >= 1 and string.format("%d %s left", days, plural(days, "day", "days"))
			or "last day - ends in " .. dur(left)
	end
	local d = today()
	if d then parts[#parts + 1] = d.done and "trade bars collected" or "trade bars NOT collected yet" end

	local title = ev.name == UNNAMED and "An event is active!" or (ev.name .. " is active!")
	local text = table.concat(parts, " - ")
	say("|cFFD700" .. title .. "|r " .. text)

	local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, SOUNDS.LEVEL_UP)
	params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_DISPLAY_ANNOUNCEMENT)
	params:SetText(title, text)
	CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
end

---------------------------------------------------------------------------
-- slash commands
---------------------------------------------------------------------------
local CMD, TXT, HEAD = "|cFFD700", "|cC5C29F", "|cFFFFFF"   -- typed commands gold, descriptions beige, headings white

local function cmdLine(cmd, desc)
	chat("  " .. CMD .. cmd .. "|r  " .. TXT .. desc .. "|r")
end

local function showHelp()
	say(HEAD .. "Commands|r " .. TXT .. "(/sevt and /sevti take the same options)|r")
	chat(HEAD .. "Manage the event|r")
	cmdLine("/sevt event", "enter the event's name and time left")
	cmdLine("/sevt event Name 5d 4h", "the same in one line (time is optional)")
	cmdLine("/sevt event clear", "disregard the current event")
	cmdLine("/sevt pause", "stop looking for events / start again")
	chat(HEAD .. "Look things up|r")
	cmdLine("/sevti", "the event: name, time left, today's bars")
	cmdLine("/sevt", "trade bars: today, last 7 days, totals")
	cmdLine("/sevt history 14", "longer history (up to 30 days)")
	chat(HEAD .. "Correct a day|r")
	cmdLine("/sevt done 20", "mark today collected (bars optional)")
	cmdLine("/sevt undo", "clear today's record")
	chat(HEAD .. "Options|r")
	cmdLine("/sevt ui", "show/hide the on-screen widget")
	cmdLine("/sevtsize 1-5", "widget text size (1 largest, 5 smallest)")
end

local function markDone(amount)
	local d = today()
	if not d then say("The daily reset timer isn't ready yet; try again in a moment.")
	elseif d.done and not amount then say("Today is already marked collected.")
	else collected(amount) end
end

local function undoToday()
	local d = today()
	if not d then return end
	db.total = math.max(0, db.total - d.bars)
	d.bars, d.done = 0, false
	db.wait = {}
	say("Today's record cleared.")
	updateUI()
end

function SET.ClearEvent()
	db.event = {}
	db.dismissed = db.streakStart   -- also ignore the bars still being collected for this event
	say("Event disregarded. A new one is announced when the next event begins.")
	updateUI()
end

local function setEvent(arg)
	if arg == "" then
		openPrompt()
	elseif arg:lower() == "clear" then
		SET.ClearEvent()
	else
		saveEvent(parseDetails(arg))
	end
end

local function handle(default, text)
	local cmd, arg = (text or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = cmd:lower()
	if cmd == "" then cmd = default end

	if cmd == "info" then showInfo()
	elseif cmd == "status" then showStatus(7)
	elseif cmd == "history" then showStatus(math.min(30, math.max(1, tonumber(arg) or 14)))
	elseif cmd == "done" then markDone(tonumber(arg))
	elseif cmd == "undo" then undoToday()
	elseif cmd == "event" then setEvent(arg)
	elseif cmd == "ui" then SET.ToggleUI()
	elseif cmd == "pause" then
		db.paused = not db.paused
		say(db.paused and "Event tracking paused: no event announcements or widget. Type |cFFD700/sevt pause|r to resume."
			or "Event tracking resumed.")
		refresh()
	else
		showHelp()
	end
end

local function setSize(text)
	local n = tonumber(text)
	if n and n == math.floor(n) and n >= 1 and n <= 5 then
		db.ui.size = n
		applySize()
		say(string.format("Label size %d of 5 (1 = largest, 5 = smallest).%s", n, shown and "" or " The label is only visible while an event is running."))
	else
		say(string.format("Label size is %d. Use |cFFD700/sevtsize|r 1-5  (1 = largest, 5 = smallest).", db.ui.size))
	end
end

---------------------------------------------------------------------------
-- startup
---------------------------------------------------------------------------
local function onActivated()
	EVENT_MANAGER:UnregisterForEvent(NAME .. "Activated", EVENT_PLAYER_ACTIVATED)
	today()
	refresh()
	zo_callLater(function()   -- let the game finish loading before announcing or asking
		refresh()
		local ev, on = getEvent()
		if not offerDetails() and on then announce(ev) end
	end, 5000)
end

local function onAddOnLoaded(_, addon)
	if addon ~= NAME then return end
	EVENT_MANAGER:UnregisterForEvent(NAME, EVENT_ADD_ON_LOADED)

	db = ZO_SavedVars:NewAccountWide("SimpleEventTrackerVars", 3, "Compact", defaults, GetWorldName())   -- per server

	local frame = SimpleEventTrackerFrame
	frame:ClearAnchors()
	frame:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, db.ui.left or 20, db.ui.top or 160)
	label = frame:GetNamedChild("Label")
	icon = frame:GetNamedChild("Icon")
	startButton = frame:GetNamedChild("Start")
	startButton:SetText("Start Event Tracking")
	icon:SetTexture(ZO_Currency_GetKeyboardCurrencyIcon(CURT_TRADE_BARS))   -- the game's own trade bar icon
	applySize()
	fragment = ZO_HUDFadeSceneFragment:New(frame)

	editWin = SimpleEventTrackerEdit
	editFragment = ZO_SimpleSceneFragment:New(editWin)
	editWin:GetNamedChild("Title"):SetText("Simple Event Tracker")
	editWin:GetNamedChild("NameLabel"):SetText("Event name")
	editWin:GetNamedChild("TimeLabel"):SetText("Time left (leave empty if unknown)")
	editWin:GetNamedChild("DaysLabel"):SetText("days")
	editWin:GetNamedChild("HoursLabel"):SetText("hours")
	editWin:GetNamedChild("MinutesLabel"):SetText("minutes")
	editWin:GetNamedChild("Save"):SetText("Save")
	editWin:GetNamedChild("Cancel"):SetText("Cancel")
	ZO_CreateStringId("SI_BINDING_NAME_SIMPLEEVENTTRACKER_TOGGLE_UI", "Show/hide Simple Event Tracker label")
	SLASH_COMMANDS["/sevti"] = function(text) handle("info", text) end
	SLASH_COMMANDS["/sevt"]  = function(text) handle("status", text) end
	SLASH_COMMANDS["/sevtsize"] = setSize

	EVENT_MANAGER:RegisterForEvent(NAME .. "Loot", EVENT_LOOT_RECEIVED, onLoot)
	EVENT_MANAGER:RegisterForEvent(NAME .. "Currency", EVENT_CURRENCY_UPDATE, onCurrency)
	EVENT_MANAGER:RegisterForEvent(NAME .. "Activated", EVENT_PLAYER_ACTIVATED, onActivated)
	EVENT_MANAGER:RegisterForUpdate(NAME .. "UI", 30 * 1000, refresh)
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, onAddOnLoaded)
