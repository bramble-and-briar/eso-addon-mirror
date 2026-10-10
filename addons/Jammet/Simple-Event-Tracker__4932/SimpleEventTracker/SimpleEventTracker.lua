-- Simple Event Tracker: shows the running ESO event and tracks the account's daily Trade Bars.
-- Credits: original Event Tracker by Kelinmiriel; this rewrite by Jammet / Claude AI assisted.
--   /sevti  event info + today's bars        /sevt  trade bar status, recent days, totals
--   Both take the same options; see "/sevt help".

SimpleEventTracker = SimpleEventTracker or {}   -- the addon's only global table (XML and key bindings call into it)
local SET = SimpleEventTracker

local NAME       = "SimpleEventTracker"
local HOUR, DAY  = 3600, 86400
local KEEP_DAYS  = 60          -- day records kept in the saved variables
local SATCHEL_ID = 224673      -- "Trade Bar Satchel"
local STALE_SECS = 30 * HOUR   -- an event without a known end counts as running this long after its last bars

local defaults = {
	days  = {},   -- { t = start, e = end (= next reset), bars = n, done = bool, ev = event name }
	total = 0,    -- all trade bars collected while tracked
	last  = {},   -- most recent event: name, desc, endT, seen
	wait  = {},   -- start of the day of each satchel looted but not yet opened
	ui    = { hidden = false },
	quiet = false,
}

local db, label, fragment
local running  = {}     -- events the game lists as running now, soonest end first
local apiReady = false  -- the game has sent its campaign list this session
local pendingAnnounce, delayElapsed = false, false

local updateUI, announce   -- defined further down

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------
local function say(text)
	CHAT_ROUTER:AddSystemMessage("|c00CCFF[SET]|r " .. text)
end

local function dur(s)
	s = math.max(0, math.floor(s))
	local d, h, m = math.floor(s / DAY), math.floor(s % DAY / HOUR), math.floor(s % HOUR / 60)
	if d > 0 then return string.format("%dd %dh", d, h) end
	if h > 0 then return string.format("%dh %dm", h, m) end
	return string.format("%dm", m)
end

local function dateStr(ts, short)
	local ok, s = pcall(os.date, short and "%d.%m" or "%d.%m.%Y", ts)
	return ok and s or GetDateStringFromTimestamp(ts)
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
-- event info: the game's promotional event campaigns (the Events tab)
---------------------------------------------------------------------------
local function readCampaigns()
	local ok, list = pcall(function()
		local out = {}
		for i = 1, GetNumActivePromotionalEventCampaigns() do
			local key = GetActivePromotionalEventCampaignKey(i)
			if not (IsReturningPlayerPromotionalEventsCampaign(key) or IsLowLevelPlayerPromotionalEventsCampaign(key)) then
				local id = GetPromotionalEventCampaignInfo(key)
				out[#out + 1] = {
					name   = zo_strformat("<<1>>", GetPromotionalEventCampaignDisplayName(id)),
					desc   = zo_strformat("<<1>>", GetPromotionalEventCampaignDescription(id)),
					remain = GetSecondsRemainingInPromotionalEventCampaign(key),
				}
			end
		end
		return out
	end)
	return ok and list or nil
end

-- The current or most recent event, and whether it is running right now.
local function getEvent()
	if running[1] then return running[1], true end
	local l = db.last
	if not l.name then return nil, false end
	if l.endT then return l, GetTimeStamp() < l.endT end
	return l, GetTimeStamp() - (l.seen or 0) < STALE_SECS
end

local function refreshEvents()
	local now = GetTimeStamp()
	local list = readCampaigns()
	if list then
		running = {}
		for _, c in ipairs(list) do
			if c.remain and c.remain > 0 then
				c.endT = now + c.remain
				running[#running + 1] = c
			end
		end
		table.sort(running, function(a, b) return a.endT < b.endT end)
		if running[1] then
			local r = running[1]
			db.last = { name = r.name, desc = r.desc, endT = r.endT, seen = now }
		elseif apiReady and db.last.endT and db.last.endT > now then
			db.last.endT = now   -- the game no longer lists it: it ended early
		end
	end

	local ev, on = getEvent()
	local d = today(false)
	if d and on and not d.ev then d.ev = ev.name end
	updateUI()
	if pendingAnnounce and delayElapsed and on then
		pendingAnnounce = false
		announce(ev)
	end
end

---------------------------------------------------------------------------
-- trade bar tracking
---------------------------------------------------------------------------
local function collected(amount)
	local d = today()
	if not d then return end

	local ev, on = getEvent()
	if not on then   -- bars arrived while the game lists no event
		db.last = { name = "Unknown event", seen = GetTimeStamp() }
		ev = db.last
	elseif not ev.endT then
		ev.seen = GetTimeStamp()
	end
	d.ev = d.ev or ev.name

	local first = not d.done
	d.done = true
	if amount and amount > 0 then
		d.bars = d.bars + amount
		db.total = db.total + amount
	end
	if first or (amount and amount > 0) then
		say("|c00FF00Trade bars collected|r" .. (d.bars > 0 and string.format(" (%d today)", d.bars) or "") .. " - done for today.")
	end
	updateUI()
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
	if ev then
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

local function eventBlock(ev, on)
	say(string.format("|cFFD700%s|r  %s", ev.name, on and "|c00FF00RUNNING|r" or "|cAAAAAAnot running|r"))
	if ev.desc and ev.desc ~= "" then
		say(#ev.desc > 350 and (ev.desc:sub(1, 347) .. "...") or ev.desc)
	end
	if ev.endT then
		local now = GetTimeStamp()
		say("End " .. dateStr(ev.endT) .. "  -  " ..
			(on and ("|cFFFF00" .. dur(ev.endT - now) .. " left|r") or ("ended " .. dur(now - ev.endT) .. " ago")))
	end
end

local function showInfo()
	refreshEvents()
	if #running > 1 then
		for _, ev in ipairs(running) do eventBlock(ev, true) end
	else
		local ev, on = getEvent()
		if ev then eventBlock(ev, on) else say("No event known yet. The game may not have sent its event list; try again in a minute.") end
	end
	if select(2, getEvent()) then say(todayLine()) end
end

local function showStatus(days)
	say(todayLine())
	for _, line in ipairs(historyLines(days)) do CHAT_ROUTER:AddSystemMessage(line) end
	say(totalsLine())
end

---------------------------------------------------------------------------
-- on-screen label (only while an event is running)
---------------------------------------------------------------------------
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
	setShown(true)
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

	local title, text = ev.name .. " is active!", table.concat(parts, " - ")
	say("|cFFD700" .. title .. "|r " .. text)
	pcall(function()
		local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, SOUNDS.LEVEL_UP)
		params:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_DISPLAY_ANNOUNCEMENT)
		params:SetText(title, text)
		CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
	end)
end

---------------------------------------------------------------------------
-- slash commands
---------------------------------------------------------------------------
local HELP = {
	"|cFFD700/sevti|r  event info: name, description, time left, today's bars",
	"|cFFD700/sevt|r  trade bars: today, last 7 days, totals",
	"Both commands accept the same options:",
	"  |cFFD700info|r  event info    |cFFD700history|r [days]  longer history (max 30)",
	"  |cFFD700done|r [bars]  mark today collected    |cFFD700undo|r  clear today's record",
	"  |cFFD700ui|r  show/hide the label    |cFFD700quiet|r  toggle the login announcement",
}

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

local function handle(default, text)
	local cmd, arg = (text or ""):match("^%s*(%S*)%s*(.-)%s*$")
	cmd = cmd:lower()
	if cmd == "" then cmd = default end

	if cmd == "info" then showInfo()
	elseif cmd == "status" then showStatus(7)
	elseif cmd == "history" then showStatus(math.min(30, math.max(1, tonumber(arg) or 14)))
	elseif cmd == "done" then markDone(tonumber(arg))
	elseif cmd == "undo" then undoToday()
	elseif cmd == "ui" then SET.ToggleUI()
	elseif cmd == "quiet" then
		db.quiet = not db.quiet
		say("Login announcement " .. (db.quiet and "off." or "on."))
	else
		for _, line in ipairs(HELP) do say(line) end
	end
end

---------------------------------------------------------------------------
-- startup
---------------------------------------------------------------------------
local function onActivated()
	EVENT_MANAGER:UnregisterForEvent(NAME .. "Activated", EVENT_PLAYER_ACTIVATED)
	pendingAnnounce = not db.quiet
	today()
	refreshEvents()
	zo_callLater(function()   -- give the game a moment to send its event data
		delayElapsed = true
		refreshEvents()       -- announces now if an event is known; otherwise as soon as the data arrives
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
	local ok, icon = pcall(ZO_Currency_GetKeyboardCurrencyIcon, CURT_TRADE_BARS)   -- the game's own trade bar icon
	if ok and icon then frame:GetNamedChild("Icon"):SetTexture(icon) end
	fragment = ZO_HUDFadeSceneFragment:New(frame)

	ZO_CreateStringId("SI_BINDING_NAME_SIMPLEEVENTTRACKER_TOGGLE_UI", "Show/hide Simple Event Tracker label")
	SLASH_COMMANDS["/sevti"] = function(text) handle("info", text) end
	SLASH_COMMANDS["/sevt"]  = function(text) handle("status", text) end

	EVENT_MANAGER:RegisterForEvent(NAME .. "Loot", EVENT_LOOT_RECEIVED, onLoot)
	EVENT_MANAGER:RegisterForEvent(NAME .. "Currency", EVENT_CURRENCY_UPDATE, onCurrency)
	EVENT_MANAGER:RegisterForEvent(NAME .. "Campaigns", EVENT_PROMOTIONAL_EVENTS_CAMPAIGNS_UPDATED, function()
		apiReady = true
		refreshEvents()
	end)
	EVENT_MANAGER:RegisterForEvent(NAME .. "Activated", EVENT_PLAYER_ACTIVATED, onActivated)
	EVENT_MANAGER:RegisterForUpdate(NAME .. "UI", 30 * 1000, updateUI)
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_ADD_ON_LOADED, onAddOnLoaded)
