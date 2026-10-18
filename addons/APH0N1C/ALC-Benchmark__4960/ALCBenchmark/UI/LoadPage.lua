--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local LOAD, UI, view, NextLine, Tint, THEME, Fmt, NAME = AB.LOAD, AB.UI, AB.view, AB.NextLine, AB.Tint, AB.THEME, AB.Fmt, AB.NAME
local GOOD, BAD, SAME = AB.GOOD, AB.BAD, AB.SAME

local VERDICTS = {
	same = { "about the same", SAME },
	faster = { "faster", GOOD },
	slower = { "slower", BAD },
	unsettled = { "not settled, needs more loads", THEME.MUTED },
	["no pairs"] = { "no pairs yet", THEME.MUTED },
}

local function UsingPad()
	return IsConsoleUI() or IsInGamepadPreferredMode()
end

function LOAD.ShownRecord()
	local list = LOAD.Saved()
	if LOAD.shown then
		for _, record in ipairs(list) do
			if record == LOAD.shown then return record end
		end
	end
	return list[1]
end

local function Signed(value)
	if not value then return "" end
	return (value > 0 and "+" or "") .. Fmt(value)
end

local function Count(record, key, field)
	local count, total = 0, 0
	for _, sample in ipairs(record.samples or {}) do
		if sample.side == key then
			total = total + 1
			if sample[field] then count = count + 1 end
		end
	end
	return count, total
end

local function Methods(record)
	local counts, order = {}, {}
	for _, sample in ipairs(record.samples or {}) do
		if sample.side == "alc" and sample.method then
			if not counts[sample.method] then order[#order + 1] = sample.method end
			counts[sample.method] = (counts[sample.method] or 0) + 1
		end
	end
	local parts = {}
	for _, method in ipairs(order) do parts[#parts + 1] = string.format("%s %d", AB.METHOD_NAMES[method] or method, counts[method]) end
	return parts
end

local function Notes(record, ref)
	local lines = {}
	local fps = record.fps and (", FPS " .. tostring(record.fps)) or ""
	lines[#lines + 1] = string.format("%s, %s%s. %s to %s and back. %s MB of garbage before each load, %d warm-up loads not counted.",
		tostring(record.when), tostring(record.platform), fps, tostring(record.home), tostring(record.dest), Fmt(record.garbage_mb or 0, 0), record.warmup or 0)
	local status = LOAD.SealStatus(record)
	if status == "running" then
		lines[#lines + 1] = Tint("Running. " .. (LOAD.StatusText() or ""), AB.PINK)
	elseif record.stopped then
		lines[#lines + 1] = Tint(string.format("Stopped early: %s. %d of %d rounds done.", tostring(record.note), record.rounds_done or 0, record.per_side or 0), BAD)
	else
		lines[#lines + 1] = string.format("%d rounds done.", record.rounds_done or 0)
	end
	if status == "not_sealed" and record.unsealed then
		lines[#lines + 1] = Tint("Not sealed: " .. record.unsealed .. ".", BAD)
	else
		local markers, invalid = UI.SealMarkers(record, status)
		if #markers > 0 then lines[#lines + 1] = Tint(table.concat(markers, " "), invalid and BAD or SAME) end
	end
	lines[#lines + 1] = "Each round runs every side once, and the order turns every round, so cache warm-up, server load and the machine heating up hit every side alike."
	if ref and #(record.sides or {}) > 1 then
		lines[#lines + 1] = string.format("Against %s: the average difference per round, plus or minus twice its standard error. About the same: inside %s s (or 5%%). Not settled: the range still crosses that, so run more loads per side.",
			LOAD.SideName(ref), Fmt(LOAD.Margin(LOAD.SideStats(record, ref).median)))
	end
	local methods = Methods(record)
	if #methods > 0 then lines[#lines + 1] = "ALC cleaned with: " .. table.concat(methods, ", ") .. "." end
	for _, key in ipairs({ "mgc", "shissu" }) do
		local forced, total = Count(record, key, "forced")
		if forced > 0 then
			lines[#lines + 1] = string.format("%s did not clean on its own in %d of %d loads, so the benchmark cleaned in its place (Force other cleaners to clean is on).", LOAD.SideName(key), forced, total)
		end
	end
	lines[#lines + 1] = "Trip home: the loading screen back home, after the first loading screen already cleaned up, as a check of how much load times vary on their own."
	return lines
end

function LOAD.Lines()
	AB.line_count = 0
	view.header_lines = 1
	local head = NextLine()
	head[1] = Tint("Loading screens", THEME.ACCENT)
	local record = LOAD.ShownRecord()
	if not record then
		NextLine()[1] = "No loading screen test yet."
		view.notes = UsingPad() and "Open the options, then Run Test, LOADING SCREEN TEST." or "Right-click, then Run Test, LOADING SCREEN TEST."
		view.notes_lines = 1
		return AB.line_pool, AB.line_count, 1
	end
	local sides = record.sides or {}
	local ref = LOAD.Reference(record)
	local ref_stats = ref and LOAD.SideStats(record, ref)
	local stats, pairs_by = {}, {}
	local low, high
	for c, key in ipairs(sides) do
		head[c + 1] = Tint(LOAD.SideName(key, true), THEME.ACCENT)
		stats[c] = LOAD.SideStats(record, key)
		if key ~= ref then pairs_by[c] = LOAD.Pairs(record, key, ref) end
		local median = stats[c].median
		if median then
			if not low or median < low then low = median end
			if not high or median > high then high = median end
		end
	end
	local function Row(label, cell)
		local line = NextLine()
		line[1] = label
		for c, key in ipairs(sides) do line[c + 1] = cell(c, key, stats[c]) or "" end
	end
	local function Number(value, places)
		return value and Fmt(value, places) or ""
	end
	Row("Loads measured", function(_, _, st) return tostring(st.n) end)
	Row("Median (s)", function(_, _, st)
		if not st.median then return "" end
		local text = Fmt(st.median)
		if #sides > 1 and low ~= high then
			if st.median == low then text = Tint(text, GOOD) elseif st.median == high then text = Tint(text, BAD) end
		end
		return text
	end)
	Row("Middle half (s)", function(_, _, st) return st.low and (Fmt(st.low) .. " to " .. Fmt(st.high)) or "" end)
	Row("Fastest / slowest (s)", function(_, _, st) return st.fastest and (Fmt(st.fastest) .. " / " .. Fmt(st.slowest)) or "" end)
	Row("Lua when it began (MB)", function(_, _, st) return Number(st.lua) end)
	local any_pool = false
	for c = 1, #sides do if stats[c].pool then any_pool = true end end
	if any_pool then Row("Pool when it began (MB)", function(_, _, st) return Number(st.pool) end) end
	Row("Cleaned before it (MB)", function(_, key, st) return key == "vanilla" and "" or Number(st.freed) end)
	Row("Lua after it (MB)", function(_, _, st) return Number(st.after) end)
	if ref and #sides > 1 then
		local ref_name = LOAD.SideName(ref, true)
		Row("Against " .. ref_name .. " (s)", function(c, key)
			if key == ref then return "reference" end
			local p = pairs_by[c]
			if not p or not p.mean then return "" end
			return Signed(p.mean) .. (p.err and (" +/- " .. Fmt(2 * p.err)) or "")
		end)
		Row("Faster than " .. ref_name, function(c, key)
			if key == ref then return "" end
			local p = pairs_by[c]
			return p and p.n > 0 and string.format("%d of %d", p.faster, p.n) or ""
		end)
		Row("Verdict", function(c, key)
			if key == ref then return "" end
			local verdict = VERDICTS[LOAD.Verdict(pairs_by[c], ref_stats and ref_stats.median)]
			return verdict[2] and Tint(verdict[1], verdict[2]) or verdict[1]
		end)
	end
	Row("Trip home (s)", function(_, _, st) return Number(st.back) end)
	local lines = Notes(record, ref)
	view.notes, view.notes_lines = table.concat(lines, "\n"), #lines
	return AB.line_pool, AB.line_count, math.max(#sides, 1)
end

local function Reopen()
	zo_callLater(function() if UI.OpenMenu then UI.OpenMenu() end end, 200)
end

local function Show(record)
	LOAD.shown = record
	UI.Show()
	UI.SetPage("loading")
end

local function Confirm(heading, yes, action)
	zo_callLater(function()
		AB.ShowChoices(heading, {
			{ text = yes, danger = true, callback = function()
				action()
				if UI.IsShown() then UI.Draw() end
			end },
			{ text = "Cancel", callback = function() end },
		})
	end, 100)
end

function LOAD.MenuChoices()
	local list = {}
	for _, side in ipairs(LOAD.SIDES) do
		local blocked = LOAD.Blocked(side.key)
		local entry = { text = side.name, checkbox = true, checked = LOAD.Picked(side.key) and not blocked, toggle = function(on) LOAD.SetPicked(side.key, on) end }
		if blocked then entry.disabled = blocked end
		list[#list + 1] = entry
	end
	local per_side, warmup, garbage = LOAD.Setting("per_side"), LOAD.Setting("warmup"), LOAD.Setting("garbage")
	list[#list + 1] = { text = string.format("Loads per side: %d", per_side), callback = function()
		AB.AskNumber(NAME .. "_LoadCount", "Loads per side", string.format("Loading screens measured for each side (%d to %d). More loads tell smaller differences apart.", LOAD.LIMITS.per_side[1], LOAD.LIMITS.per_side[2]), "Loads", per_side,
			function(number) LOAD.SetSetting("per_side", number) Reopen() end)
	end }
	list[#list + 1] = { text = string.format("Warm-up loads: %d", warmup), callback = function()
		AB.AskNumber(NAME .. "_LoadWarm", "Warm-up loads", string.format("Round trips made first and not counted, while the game caches the houses (%d to %d).", LOAD.LIMITS.warmup[1], LOAD.LIMITS.warmup[2]), "Loads", warmup,
			function(number) LOAD.SetSetting("warmup", number) Reopen() end)
	end }
	list[#list + 1] = { text = string.format("Garbage before each load: %d MB", garbage), callback = function()
		AB.AskNumber(NAME .. "_LoadGarbage", "Garbage before each load", string.format("MB of garbage made before every measured load (%d to %d). Vanilla travels with it; every other side cleans it first.%s", LOAD.LIMITS.garbage[1], LOAD.LIMITS.garbage[2],
			AB.PoolCapacityMB() and " On console it stops early at 65% of the add-on memory limit." or ""), "MB", garbage,
			function(number) LOAD.SetSetting("garbage", number) Reopen() end)
	end }
	local chosen = LOAD.Chosen()
	local blocked = LOAD.StartBlocked()
	local start = string.format("Start (%d side%s, about %d min)", #chosen, #chosen == 1 and "" or "s", LOAD.EstimateMinutes(chosen, per_side, warmup))
	list[#list + 1] = { text = start, disabled = blocked, callback = LOAD.Start }
	return list
end

function LOAD.SavedChoices()
	local list = {}
	local shown = LOAD.ShownRecord()
	for _, record in ipairs(LOAD.Saved()) do
		local names = {}
		for _, key in ipairs(record.sides or {}) do names[#names + 1] = LOAD.SideName(key, true) end
		local text = string.format("%s (%s)", tostring(record.when), table.concat(names, ", "))
		if record.running then text = text .. ", running" elseif record.stopped then text = text .. ", stopped early" end
		if LOAD.Invalid(record) then text = text .. " |cFF4040(Invalid Data)|r" end
		if record == shown then text = text .. " (showing)" end
		list[#list + 1] = { text = text, active = record == shown or nil, submenu = function()
			return {
				{ text = "Show", callback = function() Show(record) end },
				{ text = "Delete", danger = true, disabled = record.running and "running" or nil, callback = function()
					Confirm("Delete this loading screen test?", "Yes, delete this test", function() LOAD.Delete(record) end)
				end },
			}
		end }
	end
	list[#list + 1] = { text = "Clear all loading screen tests", danger = true, disabled = LOAD.run and "a test is running" or nil, callback = function()
		Confirm("Clear all loading screen tests?", "Yes, clear them", LOAD.Clear)
	end }
	return list
end
