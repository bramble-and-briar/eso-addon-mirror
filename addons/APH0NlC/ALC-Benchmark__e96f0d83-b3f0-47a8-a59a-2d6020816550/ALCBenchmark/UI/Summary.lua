--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local Ranked, SUMMARY, Conclusion, Fmt, CellText, UI = AB.Ranked, AB.SUMMARY, AB.Conclusion, AB.Fmt, AB.CellText, AB.UI
local view, NextLine, Tint, THEME = AB.view, AB.NextLine, AB.Tint, AB.THEME
local GOOD, BAD, DeltaText = AB.GOOD, AB.BAD, AB.DeltaText

local USUAL_WARNING = "Low Add-On memory: 70 MB/100 MB"

local function WarningName(text)
	if text == USUAL_WARNING then return "Low Add-On memory" end
	return tostring(text)
end
UI.WarningName = WarningName

local function JoinAnd(list)
	if #list <= 1 then return list[1] or "" end
	return table.concat(list, ", ", 1, #list - 1) .. " and " .. list[#list]
end

local function WarningPart(rows, record)
	local groups, order, row_of = {}, {}, {}
	for _, row in ipairs(rows) do row_of[tostring(row.label or "?")] = row end
	local function AddWarning(text, label, seconds)
		local group = groups[text]
		if not group then
			group = { places = {}, by_label = {} }
			groups[text], order[#order + 1] = group, text
		end
		local place = group.by_label[label]
		if not place then
			place = { label = label, times = {} }
			group.by_label[label] = place
			group.places[#group.places + 1] = place
		end
		if seconds then place.times[#place.times + 1] = string.format("%d s", seconds) end
	end
	for _, row in ipairs(rows) do
		for _, event in ipairs(row.events or {}) do
			if event.warning then AddWarning(event.warning, tostring(row.label or "?"), math.floor(event.at + 0.5)) end
		end
	end
	local warned = record and record.low_warning
	if warned and not (groups[warned.text] and groups[warned.text].by_label[tostring(warned.where)]) then AddWarning(warned.text, tostring(warned.where), warned.s) end
	if #order == 0 then return nil end
	local texts = {}
	for _, text in ipairs(order) do
		local places = {}
		for _, place in ipairs(groups[text].places) do
			local row = row_of[place.label]
			local outcome = row and (UI.FailReason(row) and Tint(" (failed)", BAD) or Tint(" (survived)", GOOD)) or ""
			places[#places + 1] = place.label .. (#place.times > 0 and (" after " .. JoinAnd(place.times)) or "") .. outcome
		end
		texts[#texts + 1] = string.format("the game warned \"%s\" in %s", WarningName(text), JoinAnd(places))
	end
	local text = table.concat(texts, "; ")
	if record and record.cut_reason == "out of memory" then text = text .. ", then the add-ons ran out of memory and were disabled" end
	if warned and not warned.protect then text = text .. "; Low memory protection was off" end
	return text
end

local function OldNotes(note, rows, AddNote)
	local marks = {}
	for _, row in ipairs(rows) do
		local label = tostring(row.label or "")
		local from = 1
		while label ~= "" do
			local first, last = note:find(label .. ": ", from, true)
			if not first then break end
			marks[#marks + 1] = { first = first, last = last, label = label }
			from = last + 1
		end
	end
	table.sort(marks, function(a, b) return a.first < b.first or (a.first == b.first and a.last > b.last) end)
	local kept, reached = {}, 0
	for _, mark in ipairs(marks) do
		if mark.first > reached then
			kept[#kept + 1] = mark
			reached = mark.last
		end
	end
	if #kept == 0 then return note end
	for index, mark in ipairs(kept) do
		local stop = kept[index + 1] and kept[index + 1].first - 1 or #note
		local text = note:sub(mark.last + 1, stop):gsub("%s+$", ""):gsub("%.$", "")
		if not text:find("^the game warned") and not text:find("^failed:") then AddNote(text, mark.label) end
	end
	return (note:sub(1, kept[1].first - 1):gsub("%s+$", ""))
end

local function NotesLines(rows, record)
	local groups, order = {}, {}
	local function AddNote(text, label, at)
		text = tostring(text):gsub("^%l", string.upper)
		local group = groups[text]
		if not group then
			group = {}
			groups[text], order[#order + 1] = group, text
		end
		group[#group + 1] = label .. ((at or 0) > 0 and string.format(" after %d s", at) or "")
	end
	for _, row in ipairs(rows) do
		for _, note in ipairs(row.notes or {}) do AddNote(note.text, tostring(row.label or "?"), note.at) end
	end
	local head = record and record.note
	if type(head) == "string" and #order == 0 then head = OldNotes(head, rows, AddNote) end
	local lines = {}
	if type(head) == "string" and head ~= "" then lines[#lines + 1] = head end
	if #order > 0 then
		local parts = {}
		for _, text in ipairs(order) do parts[#parts + 1] = string.format("%s (%s)", text, JoinAnd(groups[text])) end
		lines[#lines + 1] = Tint("Notes", THEME.ACCENT) .. ": " .. table.concat(parts, ". ") .. "."
	end
	return lines
end

local function LowMemoryLine(rows, record)
	local vanilla, alc_failed, other_failed, answered, reloaded, alc_done, other_done = {}, {}, {}, {}, {}, 0, 0
	for index, row in ipairs(rows) do
		local label = tostring(row.label or "?")
		local alc = tostring(row.alc or "")
		local other = AB.CleanerShown(row)
		local none = not other and (alc == "vanilla" or alc == "not loaded" or alc:find("off", 1, true) ~= nil)
		if row.low_memory or row.limit_s then
			local list = other and other_failed or (none and vanilla or alc_failed)
			local text = row.low_memory_late and (label .. " during its loading screen or reload") or string.format("%s after %d s", label, math.floor((row.limit_s or 0) + 0.5))
			if row.limit_pool and not row.cut_reason then text = text .. string.format(" at %s MB", Fmt(row.limit_pool, 2)) end
			list[#list + 1] = text
		elseif other and (row.frames or 0) > 0 and not row.after and index > 1 then
			other_done = other_done + 1
		elseif not none and AB.METHOD_NAMES[alc] and (row.frames or 0) > 0 and not row.after and index > 1 then
			alc_done = alc_done + 1
		end
		if row.alc_reload_s then reloaded[#reloaded + 1] = string.format("%s after %d s at %s MB", label, math.floor(row.alc_reload_s + 0.5), Fmt(row.alc_reload_pool or 0, 2)) end
		local first, freed, counts, order = nil, 0, {}, {}
		for _, event in ipairs(row.events or {}) do
			if event.lowmem then
				local method = event.method or "cleanup"
				if not counts[method] then order[#order + 1] = method end
				first, freed, counts[method] = first or event.at, freed + (event.freed or 0), (counts[method] or 0) + 1
			end
		end
		if first then
			local hows = {}
			for _, method in ipairs(order) do
				local count = counts[method]
				hows[#hows + 1] = method == "rescue" and string.format("%d rescue pass%s", count, count == 1 and "" or "es")
					or string.format("%s%s", AB.METHOD_NAMES[method] or "cleanups", count > 1 and " " .. count .. "x" or "")
			end
			answered[#answered + 1] = string.format("%s from %d s (%s, freed %s MB)", label, math.floor(first + 0.5), table.concat(hows, " and "), Fmt(freed))
		end
	end
	local warning_part = WarningPart(rows, record)
	if not warning_part and #vanilla == 0 and #alc_failed == 0 and #other_failed == 0 and #answered == 0 and #reloaded == 0 then return nil end
	local parts = {}
	if warning_part then parts[#parts + 1] = warning_part end
	if #vanilla > 0 then parts[#parts + 1] = string.format("Vanilla failed in %d phase%s (%s)", #vanilla, #vanilla == 1 and "" or "s", table.concat(vanilla, ", ")) end
	if #alc_failed > 0 then
		parts[#parts + 1] = string.format("ALC failed in %d phase%s (%s)", #alc_failed, #alc_failed == 1 and "" or "s", table.concat(alc_failed, ", "))
	elseif #vanilla > 0 and alc_done > 0 then
		parts[#parts + 1] = string.format("ALC finished its %d phase%s", alc_done, alc_done == 1 and "" or "s")
	end
	if #other_failed > 0 then
		parts[#parts + 1] = string.format("Other cleaners failed in %d phase%s (%s)", #other_failed, #other_failed == 1 and "" or "s", table.concat(other_failed, ", "))
	elseif #vanilla > 0 and other_done > 0 then
		parts[#parts + 1] = string.format("The other cleaners finished their %d phase%s", other_done, other_done == 1 and "" or "s")
	end
	if #answered > 0 then parts[#parts + 1] = "ALC cleaned for low memory in " .. table.concat(answered, ", ") end
	if #reloaded > 0 then parts[#parts + 1] = "ALC reloaded the UI for low memory itself in " .. table.concat(reloaded, ", ") .. "; those phases count and the test carried on" end
	local failed = #vanilla + #alc_failed + #other_failed > 0
	return Tint("Low add-on memory", BAD) .. ": " .. table.concat(parts, ". ") .. (failed and ". Failed phases are left out of the comparison." or ".")
end
UI.LowMemoryLine = LowMemoryLine

local function SummaryNotes(rows, pooled)
	local found = {}
	local function Best(key, pick, better)
		for index, row in ipairs(rows) do
			local value = Ranked(row, index) and pick(row)
			if value and (not found[key] or better(value, found[key].value)) then found[key] = { value = value, label = row.label } end
		end
	end
	local function Lower(a, b) return a < b end
	local function Higher(a, b) return a > b end
	Best("lua_end", function(c) return c.lua_end end, Lower)
	Best("growth", SUMMARY[1][2], Lower)
	Best("freed", function(c) return (c.freed_lua or 0) > 0 and c.freed_lua or nil end, Higher)
	Best("game", function(c) return (c.game_lua or 0) >= 0.05 and c.game_lua or nil end, Higher)
	Best("other", function(c) return AB.CleanerShown(c) and (c.other_freed_lua or 0) > 0 and c.other_freed_lua or nil end, Higher)
	local lines = {}
	local function Add(text) lines[#lines + 1] = text end
	local function Label(text) return Tint(text, THEME.ACCENT) end
	local function Group(heading, items)
		if #items == 0 then return end
		Add(Label(heading))
		for _, item in ipairs(items) do Add("  " .. item) end
	end
	local has_alc = false
	for index, row in ipairs(rows) do
		local alc = tostring(row.alc or "")
		if Ranked(row, index) and AB.METHOD_NAMES[alc] and alc ~= "vanilla" then has_alc = true end
	end
	local low_line = LowMemoryLine(rows, view.shown)
	if low_line then Add(low_line) end
	Conclusion(pooled or rows, Add)

	local best = {}
	local ranked = 0
	for index, row in ipairs(rows) do if Ranked(row, index) then ranked = ranked + 1 end end
	if ranked < 2 then
		found.lua_end, found.growth = nil, nil
		best[#best + 1] = "One phase only, so there is nothing to rank."
	end
	if found.lua_end then best[#best + 1] = string.format("%s %s (%s MB)", Label("Lowest Lua at the end:"), Tint(found.lua_end.label, GOOD), Fmt(found.lua_end.value)) end
	if found.growth then best[#best + 1] = string.format("%s %s (%s MB)", Label("Smallest Lua growth:"), Tint(found.growth.label, GOOD), CellText("mb_signed", found.growth.value)) end
	if found.freed then
		best[#best + 1] = string.format("%s %s (%s MB)", Label("Most freed by ALC:"), Tint(found.freed.label, GOOD), Fmt(found.freed.value))
	elseif has_alc then
		best[#best + 1] = "ALC freed nothing in these phases."
	end
	if found.other then best[#best + 1] = string.format("%s %s (%s MB)", Label("Most freed by another cleaner:"), Tint(found.other.label, GOOD), Fmt(found.other.value)) end
	if found.game then best[#best + 1] = string.format("%s %s (%s MB)", Label("Most freed by Vanilla:"), Tint(found.game.label, GOOD), Fmt(found.game.value)) end
	local freers = {}
	local function Freer(name, value, label)
		if not value or value < 0.05 then return end
		for _, freer in ipairs(freers) do
			if freer.name == name then
				if value > freer.value then freer.value, freer.label = value, label end
				return
			end
		end
		freers[#freers + 1] = { name = name, value = value, label = label }
	end
	for index, row in ipairs(rows) do
		if Ranked(row, index) then
			if AB.AlcShown(row) then Freer("ALC", row.freed_lua, row.label) end
			if AB.CleanerShown(row) then Freer(AB.CLEANER_BY_KEY[row.cleaner].short, row.other_freed_lua, row.label) end
			Freer("Vanilla", row.game_lua, row.label)
		end
	end
	if #freers > 1 then
		table.sort(freers, function(a, b) return a.value > b.value end)
		local parts = {}
		for index, freer in ipairs(freers) do
			local text = string.format("%s in %s (%s MB)", freer.name, freer.label, Fmt(freer.value))
			parts[#parts + 1] = index == 1 and Tint(text, GOOD) or text
		end
		best[#best + 1] = Label("Most freed of all:") .. " " .. parts[1] .. (#parts > 1 and (", then " .. table.concat(parts, ", ", 2)) or "")
	end
	Group("Best phases", best)

	local vanilla = {}
	if found.game then
		local lua_total, pool_total = 0, 0
		for index, row in ipairs(rows) do
			if Ranked(row, index) then lua_total, pool_total = lua_total + (row.game_lua or 0), pool_total + (row.game_pool or 0) end
		end
		local pool_part = pool_total >= 0.05 and string.format(" and %s MB of pool", Fmt(pool_total)) or ""
		vanilla[#vanilla + 1] = string.format("%s %s MB of Lua%s%s", Label("Freed in all:"), Fmt(lua_total), pool_part, has_alc and ", outside ALC's cleanups" or "")
	end
	local function Average(pre, post)
		local total, n = 0, 0
		for index, row in ipairs(rows) do
			if Ranked(row, index) and row[pre] and row[post] then total, n = total + row[pre] - row[post], n + 1 end
		end
		return n > 0 and total / n or nil, n
	end
	local function FreedText(lua, pool)
		local function Part(value, what)
			value = math.floor(value * 10 + 0.5) / 10
			return string.format("%s %s MB of %s", value >= 0 and "freed" or "added", Fmt(math.abs(value)), what)
		end
		return Part(lua, "Lua") .. (pool and (" and " .. Part(pool, "pool")) or "") .. " on average"
	end
	local loads = {}
	local travel, travels = Average("lua_pre_travel", "lua_post_travel")
	if travel then loads[#loads + 1] = string.format("Loading screens (%d) %s", travels, FreedText(travel, (Average("pool_pre_travel", "pool_post_travel")))) end
	local reload, reloads = Average("lua_pre_reload", "lua_post_reload")
	if reload then loads[#loads + 1] = string.format("%s (%d) %s", #loads > 0 and "reloads" or "Reloads", reloads, FreedText(reload, (Average("pool_pre_reload", "pool_post_reload")))) end
	if #loads > 0 then vanilla[#vanilla + 1] = table.concat(loads, "; ") .. " (only when you travel or reload in normal play)." end
	Group("Vanilla", vanilla)

	local test = {}
	local function Signed(value)
		local text = CellText("mb_signed", value) .. " MB"
		if value > 0.05 then return Tint(text, GOOD) end
		if value < -0.05 then return Tint(text, BAD) end
		return text
	end
	local focus
	local away_phases = {}
	for index, row in ipairs(rows) do
		if row.away_s then away_phases[#away_phases + 1] = string.format("%s (%d s)", index == 1 and "Before" or (row.label or "?"), row.away_s) end
	end
	if #away_phases > 0 then
		focus = "Game window lost focus: " .. table.concat(away_phases, ", ") .. "."
	elseif #rows > 0 and UI.Series(rows[1]) then
		focus = "Game window had focus the whole test."
	end
	local first, last = rows[1], rows[#rows]
	local versus
	if #rows > 1 and last.after and last.lua_end and first.lua_end then
		local parts = { "Lua " .. Signed(last.lua_end - first.lua_end) }
		if last.pool_end and first.pool_end then parts[#parts + 1] = "pool " .. Signed(last.pool_end - first.pool_end) end
		versus = Label("After vs Before:") .. " " .. table.concat(parts, ", ")
	end
	if focus or versus then test[#test + 1] = focus and versus and (focus .. " " .. versus) or focus or versus end
	local shown_record = view.shown
	local recovered_said = false
	local seal_status = shown_record and UI.SealStatus(shown_record)
	if seal_status == "not_sealed" and shown_record.recovered then
		test[#test + 1] = Tint("The test was recovered from the crash copy.", BAD) .. " " .. shown_record.recovered
		recovered_said = true
	elseif seal_status == "not_sealed" and shown_record.unsealed then
		test[#test + 1] = Tint("These results are not sealed: " .. shown_record.unsealed .. ".", BAD)
	elseif shown_record then
		local note, color = UI.SealNote(shown_record)
		if note and seal_status == "changed" then
			test[#test + 1] = Tint(note .. " The seal saved with it no longer matches, or its numbers no longer agree with the second-by-second data, so it can't be compared with other tests.", BAD)
		elseif note and color == BAD then
			test[#test + 1] = Tint(note .. " Its seal was removed, so edits can't be ruled out and it can't be compared with other tests.", BAD)
		elseif note then
			test[#test + 1] = Tint(note .. " The seal matches where it was recorded, so the numbers are as they were recorded there.", color)
		end
	end
	local open_parts, open_kb, open_s = {}, 0, 0
	for _, row in ipairs(rows) do
		if (row.window_s or 0) > 0 then
			open_parts[#open_parts + 1] = string.format("%s %d s", tostring(row.label), row.window_s)
			open_s, open_kb = open_s + row.window_s, open_kb + (row.window_kb or 0)
		end
	end
	if #open_parts > 0 then
		test[#test + 1] = string.format("The benchmark window was open while measuring (%s); its redraws made about %s KB/s of its own garbage, counted in those phases.", table.concat(open_parts, ", "), Fmt(open_kb / open_s))
	end
	if shown_record and shown_record.recovered and not recovered_said then test[#test + 1] = shown_record.recovered end
	if shown_record and shown_record.continued then test[#test + 1] = shown_record.continued end
	if shown_record and type(shown_record.held_cleaners) == "table" and #shown_record.held_cleaners > 0 then
		local CALLS = { mgc = "Memory Garbage Collector's own check", shissu = "Shissu's LUA Memory's /slm clean" }
		local tested, idle, calls = {}, {}, {}
		for _, key in ipairs(shown_record.held_cleaners) do
			local has_phase = false
			for _, row in ipairs(rows) do if row.cleaner == key then has_phase = true end end
			local list = has_phase and tested or idle
			list[#list + 1] = AB.CleanerName(key)
			if has_phase and CALLS[key] then calls[#calls + 1] = CALLS[key] end
		end
		if #tested > 0 and shown_record.own_cleaning then
			local its = #tested == 1 and "its" or "their"
			test[#test + 1] = string.format("%s %s held outside %s own phases. In each of %s own phases the benchmark ran %s cleanup once, at the same point ALC is made to clean (%s), and from then on %s own timer%s ran for the rest of the phase.%s",
				JoinAnd(tested), #tested == 1 and "was" or "were", its, its, its, JoinAnd(calls), its, #tested == 1 and "" or "s",
				shown_record.force_cleaners and " Force other cleaners to clean was on: where a cleaner's own cleanup did not clean, the benchmark cleaned once in its place, and that phase counts toward the conclusion and the verdict."
					or " A phase where it freed nothing is left out of the conclusion and the verdict (Force other cleaners to clean was off).")
		elseif #tested > 0 then
			test[#test + 1] = string.format("%s %s held outside %s own phases, so %s own timers never cleaned during the test; in each of %s own phases the benchmark ran %s cleanup once, at the same point ALC is made to clean (%s).%s",
				JoinAnd(tested), #tested == 1 and "was" or "were", #tested == 1 and "its" or "their", #tested == 1 and "its" or "their", #tested == 1 and "its" or "their", #tested == 1 and "its" or "their", JoinAnd(calls),
				shown_record.force_cleaners and " Force other cleaners to clean was on: where a cleaner's own cleanup did not clean, the benchmark cleaned once in its place, and that phase counts toward the conclusion and the verdict."
					or " A phase where it freed nothing is left out of the conclusion and the verdict (Force other cleaners to clean was off).")
		end
		local forced, idle_phases = {}, {}
		for _, row in ipairs(rows) do
			if AB.CleanerShown(row) and (row.other_forced or 0) > 0 then
				forced[#forced + 1] = string.format("%s (%s)", tostring(row.label), tostring(row.other_own_why or "nothing freed"))
			elseif AB.CleanerIdleWhy(row) then
				idle_phases[#idle_phases + 1] = string.format("%s (%s)", tostring(row.label), AB.CleanerIdleWhy(row))
			end
		end
		if #forced > 0 then
			test[#test + 1] = "Their own cleanup did not clean in " .. JoinAnd(forced) .. "; the benchmark cleaned there instead, and those phases are counted."
		end
		if #idle_phases > 0 then
			test[#test + 1] = "Their own cleanup did not clean in " .. JoinAnd(idle_phases) .. "; those phases are not counted."
		end
		local timers = type(shown_record.cleaner_timers) == "table" and shown_record.cleaner_timers or {}
		for _, key in ipairs(shown_record.held_cleaners) do
			local timer = timers[key]
			if timer and timer.on == false then
				test[#test + 1] = string.format("%s's own timer was off, so in normal play it never cleans by itself; only the benchmark's call cleaned in its phases.", AB.CleanerName(key))
			end
		end
		if #idle > 0 then test[#test + 1] = string.format("%s %s held the whole test, so %s never cleaned.", JoinAnd(idle), #idle == 1 and "was" or "were", #idle == 1 and "it" or "they") end
	end
	if shown_record and shown_record.own_cleaning then
		test[#test + 1] = "After that one cleanup each cleaner was left to clean on its own in its own phases only: ALC with its own threshold, cleanup delay and growth check, the other cleaners with their own timers."
	end
	if shown_record and shown_record.player then
		test[#test + 1] = "Simulated actions were on: every phase got the same plan of idling, a short combat (simulated) and the inventory, so every phase got the same workload."
		local effects = {}
		for _, row in ipairs(rows) do
			local text = AB.PlayerEffects(row)
			if text ~= "" then effects[#effects + 1] = string.format("%s (%s)", tostring(row.label), text) end
		end
		test[#test + 1] = #effects > 0 and ("What the simulated actions triggered: " .. table.concat(effects, "; ") .. ".") or "The simulated actions did not trigger or hold any cleanup."
	end
	for _, line in ipairs(NotesLines(rows, shown_record)) do test[#test + 1] = line end
	if shown_record and shown_record.kind == "alc_only" then
		test[#test + 1] = "The game's own garbage collector was paused while each phase measured, so Lua only went down when ALC cleaned."
		local released = {}
		for _, row in ipairs(rows) do
			if row.gc_released then released[#released + 1] = tostring(row.label) end
		end
		if #released > 0 then test[#test + 1] = "It was let run again near the add-on memory limit in: " .. table.concat(released, ", ") .. "." end
	end
	Group("Test", test)
	return table.concat(lines, "\n"), #lines
end

local TIME_ROWS = {
	{ "Measuring", "measure" },
	{ "Settling", "settle", nil, "settle_each" },
	{ "Loading screens", "load", "load_n" },
	{ "Reloads", "reload", "reload_n" },
	{ "Fresh-start reloads", "fresh", "fresh_n" },
	{ "Trips home", "home", "home_n" },
	{ "The rest", "rest" },
	{ "Cut off, not counted", "gap" },
}

local function TimeCell(parts, row)
	local value, count = parts[row[2]], row[3] and parts[row[3]] or 0
	if value == nil then
		if count > 0 then return string.format("not recorded (%d)", count) end
		return row[2] == "rest" and "not recorded" or ""
	end
	if value < 0.5 and count == 0 then return "" end
	local text = UI.Dur(value)
	if count > 0 then text = string.format("%s (%d)", text, count) end
	if row[4] and parts[row[4]] then text = string.format("%s (%d s each)", text, parts[row[4]]) end
	return text
end

local function TestTimeLines(record, compared)
	local parts = UI.TestTimeParts(record)
	local sums
	if #compared > 0 then
		local counted, missing = {}, 0
		local list = { record }
		for _, other in ipairs(compared) do list[#list + 1] = other end
		for _, one in ipairs(list) do
			local other = one == record and parts or UI.TestTimeParts(one)
			if other.total then counted[#counted + 1] = other else missing = missing + 1 end
		end
		if #counted >= 2 then
			sums = { n = #counted, missing = missing, total = 0 }
			for _, other in ipairs(counted) do
				sums.total = sums.total + other.total
				for _, row in ipairs(TIME_ROWS) do
					sums[row[2]] = (sums[row[2]] or 0) + (other[row[2]] or 0)
					if row[3] then sums[row[3]] = (sums[row[3]] or 0) + (other[row[3]] or 0) end
				end
			end
		end
	end
	NextLine()
	local head = NextLine()
	head.sticky = true
	head[1], head[2] = Tint("Test time", THEME.ACCENT), Tint("This test", THEME.ACCENT)
	if sums then head[3] = Tint(string.format("All %d tests", sums.n), THEME.ACCENT) end
	for _, row in ipairs(TIME_ROWS) do
		local mine, theirs = TimeCell(parts, row), sums and TimeCell(sums, { row[1], row[2], row[3] }) or ""
		if mine ~= "" or theirs ~= "" then
			local line = NextLine()
			line.sticky = true
			line[1], line[2], line[3] = row[1], mine, sums and theirs or nil
		end
	end
	local total = NextLine()
	total.sticky = true
	total[1] = "Total"
	total[2] = parts.total and Tint(UI.Dur(parts.total), AB.PINK) or "not recorded"
	if sums then total[3] = Tint(UI.Dur(sums.total), AB.PINK) end
	if sums and sums.missing > 0 then
		local line = NextLine()
		line.sticky = true
		line[1], line[3] = "Without a total", string.format("%d test%s", sums.missing, sums.missing == 1 and "" or "s")
	end
	return sums and 2 or 1
end

local summary_rows = {}

local function SummaryLines()
	AB.line_count = 0
	for index = #summary_rows, 1, -1 do summary_rows[index] = nil end
	for _, column in ipairs(view.columns) do
		if not column.ghost then summary_rows[#summary_rows + 1] = column end
	end
	local pooled = {}
	for _, row in ipairs(summary_rows) do pooled[#pooled + 1] = row end
	for _, against in ipairs(view.cross and {} or view.compared) do
		local stamp = ", " .. (against.name or against.time or against.when or "earlier")
		for _, column in ipairs(against.columns or {}) do
			local copy = {}
			for key, value in pairs(column) do copy[key] = value end
			copy.label, copy.ghost, copy.compared, copy.from = tostring(column.label) .. stamp, nil, true, against
			pooled[#pooled + 1] = copy
		end
	end
	local average = #view.compared > 0 and not view.cross and UI.AverageColumns(view.compared) or nil
	local specs = {}
	for _, spec in ipairs(SUMMARY) do
		local shown = not spec.nonzero and not spec.any
		if spec.any then
			for _, row in ipairs(summary_rows) do
				if spec[2](row) ~= nil then shown = true end
			end
		elseif spec.nonzero then
			for _, row in ipairs(summary_rows) do
				local value = spec[2](row)
				if type(value) == "number" and value >= 0.05 then shown = true end
			end
		end
		if spec.console and not AB.UI.ConsoleView() then shown = false end
		if shown then specs[#specs + 1] = spec end
	end
	local head = NextLine()
	head[1] = Tint("Phase", THEME.ACCENT)
	view.header_lines = 2
	for c, spec in ipairs(specs) do
		local parts = {}
		for part in spec[1]:gmatch("[^\n]+") do parts[#parts + 1] = Tint(part, THEME.ACCENT) end
		head[c + 1] = table.concat(parts, "\n")
	end
	for _, spec in ipairs(specs) do
		local low, high
		if spec[4] then
			for index, row in ipairs(summary_rows) do
				local value = Ranked(row, index) and spec[2](row)
				if type(value) == "number" then
					if not low or value < low then low = value end
					if not high or value > high then high = value end
				end
			end
		end
		spec.low, spec.high = low, high
	end
	local failed = UI.FailedColumns(summary_rows, not view.cross and view.shown or nil)
	for index, row in ipairs(summary_rows) do
		local line = NextLine()
		line[1] = failed[row] and Tint(tostring(row.label or "") .. " (" .. failed[row] .. ")", BAD) or (row.label or "")
		for c, spec in ipairs(specs) do
			local value = spec[2](row)
			local text = CellText(spec[3], value)
			if spec.bench_color and text ~= "" and AB.IsBenchColumn(row) then text = Tint(text, spec.bench_color) end
			if type(value) == "number" and Ranked(row, index) and spec.low and spec.high and spec.low ~= spec.high then
				local best = spec[4] == "low" and spec.low or spec.high
				local worst = spec[4] == "low" and spec.high or spec.low
				if value == best then text = Tint(text, GOOD) elseif value == worst then text = Tint(text, BAD) end
			end
			local other
			if average then
				other = not row.ghost and UI.MatchColumn(average, index, row)
			else
				local ref = view.compare and view.compare[index]
				other = type(ref) == "table" and ref or (ref and view.columns[ref])
			end
			if other then text = text .. DeltaText(spec[3], value, spec[2](other), spec[4], row.after and AB.SAME_MARGIN[spec[3]] or nil) end
			line[c + 1] = text
		end
	end
	local time_cols = view.shown and TestTimeLines(view.shown, view.compared or {}) or 0
	local text, count = SummaryNotes(summary_rows, pooled)
	view.notes, view.notes_lines = text, count
	return AB.line_pool, AB.line_count, math.max(#specs, time_cols)
end
AB.SummaryLines = SummaryLines
