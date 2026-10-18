--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local METHOD_NAMES, CellText, Fmt, view, Tint, THEME = AB.METHOD_NAMES, AB.CellText, AB.Fmt, AB.view, AB.Tint, AB.THEME
local UI, GOOD, BAD = AB.UI, AB.GOOD, AB.BAD

local SUMMARY = {
	{ "Lua change\n(MB)", function(c) return c.lua_end and c.lua_start and c.lua_end - c.lua_start end, "mb_signed", "low" },
	{ "Lua at end\n(MB)", function(c) return c.lua_end end, "mb_plain", "low" },
	{ "Pool at end\n(MB)", function(c) return c.pool_end end, "mb_plain", "low", any = true },
	{ "ALC\nmethods", function(c) local text = AB.AlcMethodsText(c) return text ~= "" and text or nil end, "text", any = true },
	{ "Freed by ALC\n(MB)", function(c) return AB.AlcShown(c) and (c.freed_lua or 0) or nil end, "mb_plain", "high", any = true },
	{ "Other\ncleaner", function(c) return AB.CleanerShown(c) and AB.CleanerText(c) or nil end, "text", any = true },
	{ "Freed by it\n(MB)", function(c) return AB.CleanerShown(c) and (c.other_freed_lua or 0) or nil end, "mb_plain", "high", any = true },
	{ "Vanilla\nmethods", function(c) local text = AB.GameMethodsText(c) return text ~= "" and text or nil end, "text", any = true },
	{ "Freed by\nVanilla (MB)", function(c) return c.game_lua end, "mb_plain", nonzero = true },
	{ "Pool freed by\nVanilla (MB)", function(c) return c.game_pool end, "mb_plain", nonzero = true, console = true },
	{ "Load or\nreload (s)", function(c) return c.load_s or c.reload_s end, "secs1", "low" },
	{ "Freed by load\nor reload (MB)", function(c) return AB.LoadLua(c) end, "mb_signed", bench_color = AB.BENCH_COLOR, any = true },
}

local function Ranked(column, index)
	return not column.ghost and not column.after and index > 1 and not AB.UI.FailReason(column)
end

local function AddOnText(counts)
	if not counts then return nil end
	local function On(n) return Tint(tostring(n), GOOD) end
	local function All(n) return Tint(tostring(n), THEME.MUTED) end
	return string.format("Add-ons: %s/%s, libraries: %s/%s", On(counts.on), All(counts.total), On(counts.libs_on), All(counts.libs_total))
end

local FACTORS = {
	{ "Lua growth", function(c) return c.lua_end and c.lua_start and c.lua_end - c.lua_start end, "MB", "low", 1, 0, "mb_signed" },
	{ "Lua at the end", function(c) return c.lua_end end, "MB", "low", 1, 0 },
	{ "Add-on pool at the end", function(c) return c.pool_end end, "MB", "low", 1, 0 },
	{ "Loading screen time", function(c) return c.load_s end, "s", "low", 0.5, 0.05 },
	{ "Reload time", function(c) return c.reload_s end, "s", "low", 0.5, 0.05 },
}

local function JudgeFactor(factor, with, without)
	local diff = with - without
	if math.abs(diff) <= math.max(factor[5], factor[6] * math.abs(without)) then return 0 end
	if factor[4] == "low" then return diff < 0 and 1 or -1 end
	return diff > 0 and 1 or -1
end

local function ShowFactor(factor, value)
	local text = factor[7] and CellText(factor[7], value) or Fmt(value, 1)
	return factor[3] ~= "" and (text .. " " .. factor[3]) or text
end

local function NoneName(c)
	return c.alc == "vanilla" and "ALC set to Vanilla" or (c.alc == "not loaded" and "ALC not loaded" or "ALC off")
end

local function OutOfMemoryWhy(disabled)
	return disabled and "Without a cleaner your add-ons ran out of memory, and the game force-disabled all of them."
		or "Without a cleaner your add-ons ran out of memory, and the game would have force-disabled all of them (Low memory protection reloaded first)."
end

local function TestScope(rows)
	local seen, count = {}, 0
	for _, c in ipairs(rows) do
		local key = c.compared and c.from or view.shown or "shown"
		if not seen[key] then seen[key], count = true, count + 1 end
	end
	return count == 1 and "in this test" or (count == 2 and "in these two tests" or string.format("in these %d tests", count)), count
end

local function SideMean(list, pick, common, Kind)
	local total, n = 0, 0
	for _, c in ipairs(list) do
		local value = common[Kind(c)] and pick(c)
		if type(value) == "number" then total, n = total + value, n + 1 end
	end
	return n > 0 and total / n or nil
end

local function CompareSides(Add, a, b, Kind, scope, winner_why)
	local common = {}
	for kind in pairs(b.kinds) do if a.kinds[kind] then common[kind] = true end end
	if not next(common) then
		if winner_why then
			Add("  " .. Tint("Verdict: " .. a.name .. " is the clear winner " .. scope, GOOD) .. ". " .. winner_why)
			return
		end
		Add(string.format("  %s and %s ended differently (loading screen, no travel or reload), so they cannot be compared.", a.name, b.name))
		return
	end
	local score = { 0, 0, 0 }
	for _, factor in ipairs(FACTORS) do
		local with, without = SideMean(a.list, factor[2], common, Kind), SideMean(b.list, factor[2], common, Kind)
		if with and without then
			local verdict = JudgeFactor(factor, with, without)
			score[verdict + 2] = score[verdict + 2] + 1
			local word = verdict > 0 and Tint(a.short .. " better", GOOD) or (verdict < 0 and Tint(b.short .. " better", BAD) or Tint("about the same", AB.SAME))
			Add(string.format("  %s: %s (%s %s, %s %s)", factor[1], word, a.short, ShowFactor(factor, with), b.short, ShowFactor(factor, without)))
		end
	end
	local total = score[1] + score[2] + score[3]
	local tally = string.format("better on %d of %d, worse on %d, about the same on %d", score[3], total, score[1], score[2])
	if winner_why then
		Add("  " .. Tint("Verdict: " .. a.name .. " is the clear winner " .. scope, GOOD) .. ". " .. winner_why)
	elseif score[3] > score[1] then
		Add("  " .. Tint("Verdict: " .. a.name .. " did better than " .. b.name .. " " .. scope, GOOD) .. " (" .. tally .. ").")
	elseif score[1] > score[3] then
		Add("  " .. Tint("Verdict: " .. b.name .. " did better than " .. a.name .. " " .. scope, BAD) .. " (" .. a.short .. " " .. tally .. ").")
	else
		Add("  Verdict: no clear winner between " .. a.name .. " and " .. b.name .. " " .. scope .. " (" .. a.short .. " " .. tally .. ").")
	end
end

local function CleanersConclusion(rows, phases, kinds, low, disabled, idle, Kind, Add)
	local entries, by_key = {}, {}
	local function Entry(key, name, short)
		local entry = { key = key, name = name, short = short, list = phases[key] or {}, kinds = kinds[key] or {}, idle = idle[key] or {} }
		entries[#entries + 1], by_key[key] = entry, entry
	end
	if #phases.alc > 0 then Entry("alc", "ALC cleaning", "ALC") end
	for _, cleaner in ipairs(AB.CLEANERS) do
		if (phases[cleaner.key] and #phases[cleaner.key] > 0) or (idle[cleaner.key] and #idle[cleaner.key] > 0) then Entry(cleaner.key, cleaner.name, cleaner.short) end
	end
	local none = { name = "Vanilla", short = "Vanilla", list = phases.none, kinds = kinds.none }
	local scope, tests = TestScope(rows)
	local why = OutOfMemoryWhy(disabled)
	local function ForcedNote(entry)
		local forced = {}
		for _, c in ipairs(entry.list) do
			if (c.other_forced or 0) > 0 then forced[#forced + 1] = string.format("%s, %s", tostring(c.label), tostring(c.other_own_why or "nothing freed")) end
		end
		if #forced == 0 then return end
		Add(string.format("  Its own cleanup did not clean in %d of these phases (%s), so the benchmark cleaned once in its place (Force other cleaners to clean is on); they count toward the conclusion and the verdict.",
			#forced, table.concat(forced, "; ")))
	end
	local function IdleNote(entry)
		local labels = entry.idle
		if #labels == 0 then return end
		local which = #labels <= 4 and (" (" .. table.concat(labels, ", ") .. ")") or ""
		Add(string.format("  %s did not clean in %d of its %d phases%s, so those phases are left out of the conclusion and the verdict.", entry.short, #labels, #labels + #entry.list, which))
	end
	local function AlcIdleNote(entry)
		local idle_alc = {}
		for _, c in ipairs(entry.list) do
			if (c.cleanups or 0) == 0 then idle_alc[#idle_alc + 1] = tostring(c.label) end
		end
		if #idle_alc > 0 then
			local which = #idle_alc <= 4 and (" (" .. table.concat(idle_alc, ", ") .. ")") or ""
			Add(string.format("  ALC did not clean in %d of its %d phases%s, so those phases ran like Vanilla.", #idle_alc, #entry.list, which))
		end
	end
	local function AgainstAlc()
		local alc = by_key.alc
		if not alc then return end
		for _, entry in ipairs(entries) do
			if entry.key ~= "alc" and #entry.list > 0 then
				Add(Tint(entry.name .. " against ALC cleaning", THEME.ACCENT) .. string.format(" (%d and %d phases)", #entry.list, #alc.list))
				CompareSides(Add, entry, alc, Kind, scope)
			end
		end
	end
	if #none.list == 0 then
		if #low.none > 0 then
			Add(Tint("Conclusion", THEME.ACCENT) .. ": every Vanilla phase ran out of add-on memory, so there is no Vanilla side left to set the cleaners against.")
			for _, entry in ipairs(entries) do
				if #entry.list == 0 then
					Add(string.format("  %s did not clean in any of its phases.", entry.name))
				elseif #(low[entry.key] or {}) == 0 then
					Add("  " .. Tint("Verdict: " .. entry.name .. " is the clear winner", GOOD) .. ". " .. why)
				else
					Add(string.format("  %s ran out of add-on memory too.", entry.name))
				end
			end
		else
			Add(Tint("Conclusion", THEME.ACCENT) .. ": only phases with a cleaner, so there is no Vanilla side to set them against. Run ALL TEST (/alcbench alc) for that.")
		end
		AgainstAlc()
		return
	end
	local none_names, seen = {}, {}
	for _, c in ipairs(none.list) do
		local name = NoneName(c)
		if not seen[name] then seen[name], none_names[#none_names + 1] = true, name end
	end
	Add(Tint("Conclusion", THEME.ACCENT) .. string.format(": each cleaner against Vanilla (%s, %d phases)", table.concat(none_names, ", "), #none.list))
	for _, entry in ipairs(entries) do
		Add(Tint(entry.name, THEME.ACCENT) .. string.format(" (%d phase%s)", #entry.list, #entry.list == 1 and "" or "s"))
		if #entry.list == 0 then
			Add(string.format("  %s did not clean in any of its phases, so it is left out of the conclusion and the verdict.", entry.name))
		else
			local wins = #low.none > 0 and #(low[entry.key] or {}) == 0
			CompareSides(Add, entry, none, Kind, scope, wins and why or nil)
			if entry.key == "alc" then
				local methods, order = {}, {}
				for _, c in ipairs(entry.list) do
					if not methods[c.alc] then methods[c.alc], order[#order + 1] = {}, c.alc end
					local list = methods[c.alc]
					list[#list + 1] = c
				end
				local common = {}
				for kind in pairs(none.kinds) do if entry.kinds[kind] then common[kind] = true end end
				local best, best_score = nil, -math.huge
				for _, method in ipairs(order) do
					local better, worse = 0, 0
					for _, factor in ipairs(FACTORS) do
						local with, without = SideMean(methods[method], factor[2], common, Kind), SideMean(none.list, factor[2], common, Kind)
						if with and without then
							local verdict = JudgeFactor(factor, with, without)
							if verdict > 0 then better = better + 1 elseif verdict < 0 then worse = worse + 1 end
						end
					end
					if better - worse > best_score then best, best_score = method, better - worse end
				end
				if #order > 1 and best then Add(string.format("  %s %s.", Tint("Best ALC method here:", THEME.ACCENT), Tint(METHOD_NAMES[best], GOOD))) end
				AlcIdleNote(entry)
			end
		end
		ForcedNote(entry)
		IdleNote(entry)
	end
	AgainstAlc()
	local workload, length = {}, {}
	for _, list in pairs(phases) do
		for _, c in ipairs(list) do
			workload[tostring(c.workload)] = true
			length[math.floor((c.seconds or 0) + 0.5)] = true
		end
	end
	local workloads, lengths = 0, 0
	for _ in pairs(workload) do workloads = workloads + 1 end
	for _ in pairs(length) do lengths = lengths + 1 end
	if workloads > 1 then Add("  Not like for like: the phases did not all get the same test garbage, so treat the memory numbers with care.") end
	if lengths > 1 then Add("  Not like for like: the phases ran for different lengths.") end
	Add("  Only phases of the same kind (loading screen, no travel, reload) are compared, and small differences count as about the same.")
	if tests == 1 then Add("  One test only: run it again before relying on small differences.") end
end

local function Conclusion(rows, Add, quiet)
	local function Kind(c)
		if c.reload_s or c.lua_pre_reload then return "reload" end
		if c.load_s or c.lua_pre_travel then return "travel" end
		return "stay"
	end
	local function Group(c)
		local label = tostring(c.label or "")
		if c.ghost or c.after or c.limit_s or c.cut_reason or label:find("^Before") or label:find("^After") or not c.frames or c.frames == 0 then return nil end
		if AB.CleanerShown(c) then return (c.other_cleanups or 0) > 0 and c.cleaner or nil end
		local alc = tostring(c.alc or "")
		if alc == "vanilla" or alc == "not loaded" or alc:find("off", 1, true) then return "none" end
		if METHOD_NAMES[alc] then return "alc" end
		return nil
	end
	local phases, kinds = { none = {}, alc = {} }, { none = {}, alc = {} }
	for _, c in ipairs(rows) do
		local group = Group(c)
		if group then
			phases[group], kinds[group] = phases[group] or {}, kinds[group] or {}
			phases[group][#phases[group] + 1] = c
			kinds[group][Kind(c)] = true
		end
	end
	local low, disabled = { none = {}, alc = {} }, false
	for _, c in ipairs(rows) do
		if c.low_memory and not c.ghost then
			local alc = tostring(c.alc or "")
			local side = AB.CleanerShown(c) and c.cleaner or ((alc == "vanilla" or alc == "not loaded" or alc:find("off", 1, true)) and "none" or "alc")
			low[side] = low[side] or {}
			low[side][#low[side] + 1] = c.low_memory_late and (tostring(c.label) .. " during its loading screen or reload") or string.format("%s after %d s", tostring(c.label), math.floor((c.limit_s or 0) + 0.5))
			if side == "none" and c.cut_reason == "out of memory" then disabled = true end
		end
	end
	local other_idle, any_other = {}, false
	for _, c in ipairs(rows) do
		if AB.CleanerShown(c) and not c.ghost and not c.after and (c.frames or 0) > 0 and not c.limit_s and not c.cut_reason then
			any_other = true
			if (c.other_cleanups or 0) == 0 then
				other_idle[c.cleaner] = other_idle[c.cleaner] or {}
				other_idle[c.cleaner][#other_idle[c.cleaner] + 1] = tostring(c.label)
			end
		end
	end
	if any_other then
		if quiet then return nil end
		return CleanersConclusion(rows, phases, kinds, low, disabled, other_idle, Kind, Add)
	end
	local alc_wins = #low.none > 0 and #low.alc == 0 and #phases.alc > 0
	local function WinVerdict(scope)
		local why = disabled and "Without ALC your add-ons ran out of memory, and the game force-disabled all of them."
			or "Without ALC your add-ons ran out of memory, and the game would have force-disabled all of them (Low memory protection reloaded first)."
		Add("  " .. Tint("Verdict: ALC is the clear winner" .. (scope and (" " .. scope) or ""), GOOD) .. ". " .. why)
	end
	if #low.none > 0 and #phases.alc == 0 and #phases.none == 0 then
		if quiet then return nil end
		if view.shown and view.shown.kind == "run" and not view.cross then
			Add(Tint("Conclusion", THEME.ACCENT) .. ": every phase ran out of add-on memory, so there is nothing left to compare.")
		else
			Add(Tint("Conclusion", THEME.ACCENT) .. ": Vanilla ran out of add-on memory before any ALC phase was measured, so there is no ALC side to set it against yet.")
		end
		return
	end
	local no_alc_only = #phases.alc == 0 and #phases.none > 0
	if no_alc_only and quiet then return nil end
	if #phases.none == 0 and #phases.alc > 0 then
		if quiet then return nil end
		if #low.none > 0 then
			Add(Tint("Conclusion", THEME.ACCENT) .. string.format(": every Vanilla phase ran out of add-on memory, so there is no Vanilla side left to set ALC against. ALC finished %d phase%s on the same console.", #phases.alc, #phases.alc == 1 and "" or "s"))
			if alc_wins then WinVerdict() end
		else
			Add(Tint("Conclusion", THEME.ACCENT) .. string.format(": only phases with ALC cleaning (%d), so there is no Vanilla side to set ALC against. Run ALL TEST (/alcbench alc) for that.", #phases.alc))
		end
		local order, by_method = {}, {}
		for _, c in ipairs(phases.alc) do
			if not by_method[c.alc] then
				by_method[c.alc] = {}
				order[#order + 1] = c.alc
			end
			local list = by_method[c.alc]
			list[#list + 1] = c
		end
		local parts = {}
		for _, method in ipairs(order) do
			local growth, freed, n_growth, n_freed = 0, 0, 0, 0
			for _, c in ipairs(by_method[method]) do
				if c.lua_end and c.lua_start then growth, n_growth = growth + c.lua_end - c.lua_start, n_growth + 1 end
				if c.freed_lua then freed, n_freed = freed + c.freed_lua, n_freed + 1 end
			end
			local text = METHOD_NAMES[method] or tostring(method)
			if n_growth > 0 then text = text .. " Lua growth " .. CellText("mb_signed", growth / n_growth) .. " MB" end
			if n_freed > 0 then text = text .. ", freed by ALC " .. Fmt(freed / n_freed) .. " MB" end
			parts[#parts + 1] = text
		end
		Add("  Each method on average: " .. table.concat(parts, "; ") .. ".")
		return
	end
	if not no_alc_only and (#phases.none == 0 or #phases.alc == 0) then
		Add("Conclusion: needs phases with ALC cleaning and phases without it. Run /alcbench alc, or compare a test without ALC against one with ALC cleaning.")
		return
	end
	local common = {}
	for kind in pairs(kinds.none) do if kinds.alc[kind] then common[kind] = true end end
	if not no_alc_only and not next(common) then
		if alc_wins then
			if quiet then return { score = { 0, 0, 0 }, results = {}, alc_wins = true } end
			WinVerdict()
			return
		end
		Add("Conclusion: the phases with and without ALC ended differently (loading screen, no travel or reload), so they cannot be compared.")
		return
	end
	local factors = FACTORS
	local function Mean(list, pick)
		local total, n = 0, 0
		for _, c in ipairs(list) do
			local value = common[Kind(c)] and pick(c)
			if type(value) == "number" then total, n = total + value, n + 1 end
		end
		return n > 0 and total / n or nil
	end
	local Judge, Show = JudgeFactor, ShowFactor
	if no_alc_only then
		local tests, test_of = {}, {}
		for _, c in ipairs(phases.none) do
			local key = c.compared and c.from or "shown"
			if not test_of[key] then
				test_of[key] = { record = c.compared and c.from or view.shown, rows = {}, kinds = {} }
				tests[#tests + 1] = test_of[key]
			end
			local entry = test_of[key]
			entry.rows[#entry.rows + 1] = c
			entry.kinds[Kind(c)] = true
		end
		local shared = {}
		for kind in pairs(tests[1].kinds) do
			local everywhere = true
			for k = 2, #tests do if not tests[k].kinds[kind] then everywhere = false end end
			if everywhere then shared[kind] = true end
		end
		local function SharedMean(list, pick)
			local total, n = 0, 0
			for _, c in ipairs(list) do
				local value = shared[Kind(c)] and pick(c)
				if type(value) == "number" then total, n = total + value, n + 1 end
			end
			return n > 0 and total / n or nil
		end
		local this = tests[1]
		if #tests == 1 then
			Add(Tint("Conclusion", THEME.ACCENT) .. string.format(": only Vanilla in this test (%d phases), so there is no ALC side to set it against. Tick another Vanilla test under Compare Test to compare the two.", #this.rows))
			local parts = {}
			for _, factor in ipairs(factors) do
				local value = SharedMean(this.rows, factor[2])
				if value then parts[#parts + 1] = factor[1] .. " " .. Show(factor, value) end
			end
			if #parts > 0 then Add("  This test on average: " .. table.concat(parts, ", ") .. ".") end
			return
		end
		if not next(shared) then
			Add("Conclusion: the tests' phases ended differently (loading screen, no travel or reload), so they cannot be compared.")
			return
		end
		local others = {}
		for k = 2, #tests do
			for _, c in ipairs(tests[k].rows) do others[#others + 1] = c end
		end
		local this_name = UI.TestName(this.record)
		local other_name = #tests == 2 and UI.TestName(tests[2].record) or string.format("the other %d tests", #tests - 1)
		Add(Tint("Conclusion", THEME.ACCENT) .. string.format(": %s against %s, both Vanilla only", this_name, other_name))
		local tally = { 0, 0, 0 }
		for _, factor in ipairs(factors) do
			local mine, theirs = SharedMean(this.rows, factor[2]), SharedMean(others, factor[2])
			if mine and theirs then
				local verdict = Judge(factor, mine, theirs)
				tally[verdict + 2] = tally[verdict + 2] + 1
				local word = verdict > 0 and Tint(this_name .. " better", GOOD) or (verdict < 0 and Tint(other_name .. " better", BAD) or Tint("about the same", AB.SAME))
				Add(string.format("  %s: %s (%s %s, %s %s)", factor[1], word, this_name, Show(factor, mine), other_name, Show(factor, theirs)))
			end
		end
		local total = tally[1] + tally[2] + tally[3]
		local counts = string.format("better on %d of %d, worse on %d, about the same on %d", tally[3], total, tally[1], tally[2])
		if tally[3] > tally[1] then
			Add("  " .. Tint("Verdict: " .. this_name .. " ran better", GOOD) .. " (" .. counts .. ").")
		elseif tally[1] > tally[3] then
			Add("  " .. Tint("Verdict: " .. other_name .. " ran better", BAD) .. " (" .. this_name .. " " .. counts .. ").")
		else
			Add("  Verdict: no clear winner (" .. this_name .. " " .. counts .. ").")
		end
		if #tests > 2 then
			local each = {}
			for _, entry in ipairs(tests) do
				local growth, lua_end = SharedMean(entry.rows, factors[1][2]), SharedMean(entry.rows, factors[2][2])
				each[#each + 1] = string.format("%s Lua growth %s, Lua at the end %s", UI.TestName(entry.record), growth and Show(factors[1], growth) or "?", lua_end and Show(factors[2], lua_end) or "?")
			end
			Add("  Each test: " .. table.concat(each, "; ") .. ".")
		end
		Add("  Only phases of the same kind (loading screen, no travel, reload) are compared, and small differences count as about the same.")
		return
	end
	local methods, order = {}, {}
	for _, c in ipairs(phases.alc) do
		if not methods[c.alc] then
			methods[c.alc] = {}
			order[#order + 1] = c.alc
		end
		local list = methods[c.alc]
		list[#list + 1] = c
	end
	local names, none_names, seen = {}, {}, {}
	for _, method in ipairs(order) do names[#names + 1] = METHOD_NAMES[method] end
	for _, c in ipairs(phases.none) do
		local name = NoneName(c)
		if not seen[name] then seen[name], none_names[#none_names + 1] = true, name end
	end
	Add(Tint("Conclusion", THEME.ACCENT) .. string.format(": ALC cleaning (%s, %d phases) against Vanilla (%s, %d phases)",
		table.concat(names, ", "), #phases.alc, table.concat(none_names, ", "), #phases.none))
	local score, results = { 0, 0, 0 }, {}
	for _, factor in ipairs(factors) do
		local with, without = Mean(phases.alc, factor[2]), Mean(phases.none, factor[2])
		if with and without then
			local verdict = Judge(factor, with, without)
			score[verdict + 2] = score[verdict + 2] + 1
			results[factor[1]] = verdict
			local word = verdict > 0 and Tint("ALC better", GOOD) or (verdict < 0 and Tint("Vanilla better", BAD) or Tint("about the same", AB.SAME))
			Add(string.format("  %s: %s (ALC %s, Vanilla %s)", factor[1], word, Show(factor, with), Show(factor, without)))
		end
	end
	local best, best_score, parts = nil, -math.huge, {}
	for _, method in ipairs(order) do
		local better, worse = 0, 0
		for _, factor in ipairs(factors) do
			local with, without = Mean(methods[method], factor[2]), Mean(phases.none, factor[2])
			if with and without then
				local verdict = Judge(factor, with, without)
				if verdict > 0 then better = better + 1 elseif verdict < 0 then worse = worse + 1 end
			end
		end
		parts[#parts + 1] = string.format("%s better on %d, worse on %d", METHOD_NAMES[method], better, worse)
		if better - worse > best_score then best, best_score = method, better - worse end
	end
	if #order > 1 then Add("  Each method against Vanilla: " .. table.concat(parts, "; ") .. ".") end
	local idle = {}
	for _, c in ipairs(phases.alc) do
		if (c.cleanups or 0) == 0 then idle[#idle + 1] = tostring(c.label) end
	end
	if #idle > 0 then
		local which = #idle <= 4 and (" (" .. table.concat(idle, ", ") .. ")") or ""
		Add(string.format("  ALC did not clean in %d of its %d phases%s, so those phases ran like Vanilla.", #idle, #phases.alc, which))
	end
	if quiet then return { score = score, results = results, alc_wins = alc_wins } end
	local groups, group_of = {}, {}
	for _, c in ipairs(rows) do
		local key = c.compared and c.from or view.shown or "shown"
		if not group_of[key] then
			group_of[key] = { record = c.compared and c.from or view.shown, rows = {} }
			groups[#groups + 1] = group_of[key]
		end
		local list = group_of[key].rows
		list[#list + 1] = c
	end
	local scope = #groups == 1 and "in this test" or (#groups == 2 and "in these two tests" or string.format("in these %d tests", #groups))
	local total = score[1] + score[2] + score[3]
	local tally = string.format("better on %d of %d, worse on %d, about the same on %d", score[3], total, score[1], score[2])
	if alc_wins then
		WinVerdict(scope)
	elseif score[3] > score[1] then
		Add("  " .. Tint("Verdict: ALC cleaning did better " .. scope, GOOD) .. " (" .. tally .. ").")
	elseif score[1] > score[3] then
		Add("  " .. Tint("Verdict: Vanilla did better " .. scope, BAD) .. " (ALC " .. tally .. ").")
	else
		Add("  Verdict: no clear winner " .. scope .. " (ALC " .. tally .. ").")
	end
	if #order > 1 and best then Add(string.format("  %s %s.", Tint("Best ALC method here:", THEME.ACCENT), Tint(METHOD_NAMES[best], GOOD))) end
	local workload, length = {}, {}
	for _, list in pairs(phases) do
		for _, c in ipairs(list) do
			if common[Kind(c)] then
				workload[tostring(c.workload)] = true
				length[math.floor((c.seconds or 0) + 0.5)] = true
			end
		end
	end
	local workloads, lengths = 0, 0
	for _ in pairs(workload) do workloads = workloads + 1 end
	for _ in pairs(length) do lengths = lengths + 1 end
	if workloads > 1 then Add("  Not like for like: the phases did not all get the same test garbage, so treat the memory numbers with care.") end
	if lengths > 1 then Add("  Not like for like: the phases ran for different lengths.") end
	if #groups == 1 then
		Add("  One test only: run it again before relying on small differences.")
		return
	end
	local function Quiet() end
	local function Side(result)
		if result.alc_wins then return 1 end
		return result.score[3] > result.score[1] and 1 or (result.score[1] > result.score[3] and -1 or 0)
	end
	local says, judged = {}, {}
	for _, group in ipairs(groups) do
		local result = Conclusion(group.rows, Quiet, true)
		local text = "cannot be judged on its own"
		if result then
			local word = result.alc_wins and "ALC is the clear winner, Vanilla ran out of memory" or (Side(result) > 0 and "ALC cleaning did better" or (Side(result) < 0 and "Vanilla did better" or "no clear winner"))
			text = string.format("%s (better on %d, worse on %d)", word, result.score[3], result.score[1])
			judged[#judged + 1] = result
		end
		says[#says + 1] = string.format("%s says %s", UI.TestName(group.record), text)
	end
	Add("  Each test on its own: " .. table.concat(says, "; ") .. ".")
	if #judged < 2 then return end
	local same, both = 0, 0
	for name, verdict in pairs(judged[1].results) do
		local present, agree = true, true
		for k = 2, #judged do
			local other = judged[k].results[name]
			if other == nil then present = false elseif other ~= verdict then agree = false end
		end
		if present then
			both = both + 1
			if agree then same = same + 1 end
		end
	end
	local sides = { 0, 0, 0 }
	for _, result in ipairs(judged) do sides[Side(result) + 2] = sides[Side(result) + 2] + 1 end
	local all_same = sides[1] == #judged or sides[2] == #judged or sides[3] == #judged
	if #judged == 2 then
		if all_same then
			Add(string.format("  The two tests agree on the verdict and on %d of %d factors.", same, both))
		else
			Add(string.format("  The two tests disagree on the verdict (they agree on %d of %d factors), so the result is not settled; run a third test.", same, both))
		end
	elseif all_same then
		Add(string.format("  All %d tests agree on the verdict and on %d of %d factors.", #judged, same, both))
	else
		Add(string.format("  The %d tests disagree on the verdict (ALC cleaning %d, Vanilla %d, no clear winner %d; they agree on %d of %d factors), so the result is not settled; run another test.",
			#judged, sides[3], sides[1], sides[2], same, both))
	end
end
AB.SUMMARY, AB.Ranked, AB.AddOnText, AB.Conclusion = SUMMARY, Ranked, AddOnText, Conclusion
