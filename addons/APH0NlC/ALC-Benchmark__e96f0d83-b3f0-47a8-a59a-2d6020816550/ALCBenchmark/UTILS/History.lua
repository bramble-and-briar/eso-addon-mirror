--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local AlcState, LuaMB, PoolMB, PoolCapacityMB, Fmt, view = AB.AlcState, AB.LuaMB, AB.PoolMB, AB.PoolCapacityMB, AB.Fmt, AB.view
local UI, AddOnText, GS, Alc, SetAlcMode = AB.UI, AB.AddOnText, AB.GS, AB.Alc, AB.SetAlcMode

local function NowColumn()
	return { label = "Now", alc = AlcState(), lua_start = LuaMB(), pool_start = PoolMB(), pool_cap = PoolCapacityMB() }
end

local function KindName(record)
	if record.kind == "run" or record.kind == "alc_only" then return record.kind end
	return "all"
end

local KIND_LABELS = { all = "ALL TEST", run = "VANILLA ONLY TEST", alc_only = "ALC ONLY TEST" }

local function WithArticle(label)
	return (label:find("^[AEIOU]") and "an " or "a ") .. label
end

local CROSS = { alc_only = "run", run = "alc_only" }

function UI.IsCross(a, b)
	return a ~= nil and b ~= nil and CROSS[KindName(a)] == KindName(b)
end

local function FailedPhasesText(record)
	local count = 0
	for _, column in ipairs(record.columns or {}) do
		if column.low_memory and not column.cut_reason then count = count + 1 end
	end
	if count == 0 then return nil end
	return string.format("%d phase%s failed (low memory)", count, count == 1 and "" or "s")
end

local function Owner(record)
	return type(record.seal_account) == "string" and record.seal_account or GetDisplayName()
end

local function Comparable(a, b)
	if not (a and b) or a == b then return false, "pick two different tests" end
	if UI.SealInvalid and UI.SealInvalid(b) then return false, "can't be compared" end
	if UI.SealInvalid and UI.SealInvalid(a) then return false, "the test shown is Invalid Data" end
	if Owner(a) ~= Owner(b) then return false, "recorded by another account" end
	if not (a.seconds and b.seconds) then return false, "saved by an older version" end
	local cross = UI.IsCross(a, b)
	if KindName(a) ~= KindName(b) and not cross then return false, "one is " .. WithArticle(KIND_LABELS[KindName(a)]) .. ", the other " .. WithArticle(KIND_LABELS[KindName(b)]) end
	if (a.real or false) ~= (b.real or false) then return false, "one is real world, the other not" end
	if (a.isolated or false) ~= (b.isolated or false) then return false, "made with the older test procedure" end
	if not cross and (a.vanilla_garbage or false) ~= (b.vanilla_garbage or false) then return false, "Vanilla got extra garbage in one, not the other" end
	if (a.keep_fill or false) ~= (b.keep_fill or false) then return false, "the fill was held while measuring in one, not the other" end
	if (a.own_cleaning or false) ~= (b.own_cleaning or false) then return false, "made before the cleaners cleaned on their own" end
	if (a.player or false) ~= (b.player or false) then return false, "simulated actions were on in one, not the other" end
	if a.hold_s ~= b.hold_s then return false, "different fill hold time" end
	if a.seconds ~= b.seconds then return false, "different length" end
	if not a.real and math.abs((a.churn or 0) - (b.churn or 0)) > 0.001 then return false, "different extra garbage" end
	if a.metric_name ~= b.metric_name or math.abs((a.target_mb or 0) - (b.target_mb or 0)) > 0.5 then return false, "different fill target" end
	if a.platform ~= b.platform then return false, "different platform or UI" end
	if not cross then
		if #(a.columns or {}) ~= #(b.columns or {}) then return false, "different phases" end
		local run = KindName(a) == "run"
		for index, column in ipairs(a.columns) do
			local other = b.columns[index]
			if run and UI.PhaseType(column) ~= UI.PhaseType(other) then return false, "different phases" end
			if not run and column.label ~= other.label then return false, "different phases" end
		end
	end
	return true
end

local INVALID_TAG = " |cFF4040(Invalid Data)|r"

local function InvalidTag(record)
	return UI.SealInvalid and UI.SealInvalid(record) and INVALID_TAG or ""
end

local function Describe(record, index)
	if record.name then return string.format("%s%s%s", index and (index .. ". ") or "", record.name, InvalidTag(record)) end
	local what = KIND_LABELS[KindName(record)]
	if KindName(record) == "run" then
		local labels = {}
		for column = 2, #(record.columns or {}) do labels[#labels + 1] = tostring(record.columns[column].label) end
		what = what .. ", " .. (#labels > 0 and table.concat(labels, " / ") or "?")
	end
	local fps = ""
	if record.fps == "uncapped" then fps = ", uncapped FPS" elseif type(record.fps) == "number" then fps = ", " .. record.fps .. "FPS" end
	local length = record.seconds and string.format(", %d s", record.seconds) or ""
	local garbage = (record.churn or 0) > 0 and string.format("%gMB/s garbage", record.churn) or "Add-ons only"
	local mode = record.real and "(REALWORLD)" or "(FILL)"
	return string.format("%s%s, %s%s%s, %s %s%s%s", index and (index .. ". ") or "", record.when or "?", what, fps, length, garbage, mode, record.failed and (", failed (" .. (record.cut_reason or "low memory") .. ")") or (record.stopped and (record.cut_reason and (", stopped (" .. record.cut_reason .. ")") or ", stopped") or (FailedPhasesText(record) and (", " .. FailedPhasesText(record)) or "")), InvalidTag(record))
end

local function History()
	AB.saved.history = AB.saved.history or {}
	return AB.saved.history
end

local function FirstComparable(record)
	for _, other in ipairs(History()) do
		if other ~= record and KindName(other) == KindName(record) and Comparable(record, other) then return other end
	end
	return nil
end

local function PhaseType(column)
	if column.after then return "after" end
	local label = tostring(column.label or "")
	if label == "Before" then return "before" end
	if label:find("+ no travel", 1, true) then return "stay" end
	if label:find("+ reload", 1, true) then return "reload" end
	return "travel"
end
UI.PhaseType = PhaseType

local function Relabel(column, label, ghost)
	local copy = {}
	for key, value in pairs(column or {}) do copy[key] = value end
	copy.label, copy.ghost = label, ghost or nil
	return copy
end

local function ShowCross(shown, others, text)
	local other = others[1]
	local stamp = #others > 1 and string.format(", average of %d", #others) or (", " .. (other.name or other.time or other.when or "earlier"))
	local other_columns = #others > 1 and UI.AverageColumns(others) or other.columns or {}
	local vanilla_from_shown = KindName(shown) == "run"
	local own, theirs = shown.columns or {}, other_columns
	local function Phases(list, label_stamp)
		local out = {}
		for _, column in ipairs(list) do
			local kind = PhaseType(column)
			if kind ~= "before" and kind ~= "after" then out[#out + 1] = label_stamp and Relabel(column, tostring(column.label) .. label_stamp) or column end
		end
		return out
	end
	local vanilla = vanilla_from_shown and Phases(own) or Phases(theirs, stamp)
	local alc = vanilla_from_shown and Phases(theirs, stamp) or Phases(own)
	local columns, compare, first_of = { own[1] }, {}, {}
	for _, column in ipairs(vanilla) do
		columns[#columns + 1] = column
		local kind = PhaseType(column)
		first_of[kind] = first_of[kind] or #columns
	end
	if vanilla_from_shown and #vanilla > 0 then compare[2] = 1 end
	for _, column in ipairs(alc) do
		columns[#columns + 1] = column
		compare[#columns] = first_of[PhaseType(column)]
	end
	local own_after
	for _, column in ipairs(own) do
		if column.after then own_after = column end
	end
	if own_after then
		columns[#columns + 1] = own_after
		compare[#columns] = 1
	end
	local after_index = own_after and #columns or nil
	for _, column in ipairs(theirs) do
		local kind = PhaseType(column)
		if kind == "before" then
			columns[#columns + 1] = Relabel(column, "Before" .. stamp, true)
			compare[#columns] = 1
		elseif kind == "after" and after_index then
			columns[#columns + 1] = Relabel(column, "After" .. stamp, true)
			compare[#columns] = after_index
		end
	end
	local vanilla_name = vanilla_from_shown and UI.TestName(shown) or (#others > 1 and string.format("the average of %d VANILLA ONLY TESTs", #others) or UI.TestName(other))
	local alc_name = vanilla_from_shown and (#others > 1 and string.format("the average of %d ALC ONLY TESTs", #others) or UI.TestName(other)) or UI.TestName(shown)
	text = text .. string.format(" Compared as one ALL TEST: Vanilla phases from %s, ALC phases from %s; each ALC phase's +/- is against the Vanilla phase of the same kind.", vanilla_name, alc_name)
	view.cross = true
	UI.Set(columns, compare, text)
end

local function ShowSaved()
	if view.blank and #History() > 0 then
		view.shown, view.compared = nil, {}
		UI.Set({ NowColumn() }, nil, (IsConsoleUI() or IsInGamepadPreferredMode()) and "No saved test shown. Open the options and pick one under Saved tests." or "No saved test shown. Right-click and pick one under Saved tests.")
		return
	end
	local shown = view.shown or History()[1]
	if not shown then
		UI.Set({ NowColumn() }, nil, (IsConsoleUI() or IsInGamepadPreferredMode()) and "No test yet. Open the options to start one." or "No test yet. Right-click for options, or /alcbench alc, /alcbench alconly or /alcbench vanilla.")
		return
	end
	view.shown = shown
	view.cross = nil
	for index = #view.compared, 1, -1 do
		if not Comparable(shown, view.compared[index]) then table.remove(view.compared, index) end
	end
	local lead = view.compared[1]
	for index = #view.compared, 2, -1 do
		local other = view.compared[index]
		if KindName(other) ~= KindName(lead) or not Comparable(lead, other) then table.remove(view.compared, index) end
	end
	local against = view.compared[1]
	local text = string.format("%s: %s, %s%s. Target %s.", KIND_LABELS[KindName(shown)], shown.when or "?", shown.platform or "?", shown.failed and (", failed (" .. (shown.cut_reason or "low memory") .. ")") or (shown.stopped and (shown.cut_reason and (", stopped early (" .. shown.cut_reason .. ")") or ", stopped early") or (FailedPhasesText(shown) and (", " .. FailedPhasesText(shown)) or "")), shown.target or "none")
	if shown.addons then text = text .. " " .. AddOnText(shown.addons) .. "." end
	local away = 0
	for _, column in ipairs(shown.columns or {}) do away = away + (column.away_s or 0) end
	if away > 0 then text = text .. string.format(" Game in the background for %d s.", away) end
	local held_text = GS.HeldText(shown.held)
	if held_text then text = text .. " " .. held_text end
	local seal_note, seal_color = UI.SealNote(shown)
	if seal_note then text = text .. " " .. AB.Tint(seal_note, seal_color or AB.BAD) end
	if shown.name then text = shown.name .. ". " .. text end
	if not (IsConsoleUI() or IsInGamepadPreferredMode()) then text = text .. " Right-click for options." end
	if not against then
		local columns, compare = shown.columns or {}, shown.compare
		if columns[1] and columns[2] and not columns[2].after and compare and compare[2] == nil then
			compare = setmetatable({ [2] = 1 }, { __index = compare })
		end
		UI.Set(columns, compare, text)
		return
	end
	if UI.IsCross(shown, against) then return ShowCross(shown, view.compared, text) end
	if #view.compared > 1 then
		local names = {}
		for _, record in ipairs(view.compared) do names[#names + 1] = UI.TestName(record) end
		text = text .. string.format(" +/- compares with the average of %d tests (%s).", #names, table.concat(names, ", "))
		against = { columns = UI.AverageColumns(view.compared) }
	else
		text = text .. " +/- compares with " .. (against.when or "?") .. "."
	end
	local columns, compare = {}, {}
	for index, column in ipairs(shown.columns) do
		columns[index] = column
		compare[index] = against.columns[index]
	end
	UI.Set(columns, compare, text)
end

local function Restore(restore)
	restore = restore or (AB.test and AB.test.restore)
	local alc = Alc()
	if not (restore and alc and alc.settings) then return end
	alc.settings.auto_clear_pool_on_teleport = restore.pool_travel
	if restore.afk ~= nil then alc.settings.afk_reload = restore.afk end
	if alc.toggle_afk_watch then alc.toggle_afk_watch() end
	SetAlcMode(alc, restore.mode)
end

local function PhaseChurn(_)
	if AB.test.real then return 0 end
	return AB.test.churn
end

local function PhaseExtra(phase, into)
	local extra = into or {}
	extra.alc = phase.alc_label or AlcState()
	extra.cleaner = phase.cleaner
	local timer = phase.cleaner and AB.test.cleaner_timers and AB.test.cleaner_timers[phase.cleaner]
	if timer then extra.own_timer_on, extra.own_timer_s = timer.on, timer.every_s end
	if timer and AB.test.own_cleaning then extra.own_runs = phase.stats and phase.stats.own_runs or 0 end
	extra.workload = AB.test.real and "add-ons only" or (PhaseChurn(phase) > 0 and (Fmt(PhaseChurn(phase)) .. " MB/s") or "none")
	if phase.slowed then extra.workload = extra.workload .. string.format(", slowed to %d%% near the add-on memory limit", math.floor(phase.slowed * 100 + 0.5)) end
	extra.slowed = phase.slowed
	extra.held, extra.held_until = phase.held_mb, phase.held_until
	extra.gc_held = AB.test.kind == "alc_only" or nil
	extra.gc_released = phase.gc_released
	extra.timer = "done"
	extra.notes = phase.notes
	if phase.travel_values then
		for key, value in pairs(phase.travel_values) do extra[key] = value end
	end
	return extra
end
AB.Comparable, AB.Describe, AB.History, AB.FirstComparable, AB.ShowSaved, AB.Restore = Comparable, Describe, History, FirstComparable, ShowSaved, Restore
AB.PhaseChurn, AB.PhaseExtra = PhaseChurn, PhaseExtra
