--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local Fmt, GOOD, BAD = AB.Fmt, AB.GOOD, AB.BAD

local function Paint(text, color)
	return string.format("|c%02x%02x%02x%s|r", math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255), text)
end

local function Signed(value)
	value = math.floor(value * 10 + 0.5) / 10
	return (value > 0 and "+" or "") .. Fmt(value, 1)
end

function AB.AlcShown(c)
	local alc = tostring(c.alc or "")
	return (AB.METHOD_NAMES[alc] ~= nil and alc ~= "vanilla") or (c.cleanups or 0) > 0
end

function AB.CleanerShown(c)
	return c.cleaner ~= nil and AB.CLEANER_BY_KEY[c.cleaner] ~= nil
end

function AB.CleanerText(c)
	if not AB.CleanerShown(c) then return "" end
	local color = AB.TLC and AB.TLC[c.cleaner] or AB.ALC_COLOR
	return Paint(AB.CleanerName(c.cleaner), color)
end

function AB.CleanerIdleWhy(c)
	if not AB.CleanerShown(c) or (c.other_cleanups or 0) > 0 then return nil end
	if c.other_error then return "its cleanup stopped with an error" end
	if (c.other_runs or 0) == 0 then return "its cleanup could not be run" end
	if c.cleaner == "mgc" then return "under its own limit" end
	return "its cleanup freed nothing"
end

local function CleanerRuns(c)
	if not AB.CleanerShown(c) then return "" end
	local why = AB.CleanerIdleWhy(c)
	if why then return Paint("0 (" .. why .. ", not counted)", BAD) end
	local count = tostring(math.floor((c.other_cleanups or 0) + 0.5))
	if (c.own_cleanups or 0) > 0 then count = count .. string.format(" (%d on its own timer)", c.own_cleanups) end
	if (c.other_forced or 0) > 0 then
		return Paint(count .. " (forced by the benchmark: its own cleanup did not clean, " .. tostring(c.other_own_why or "nothing freed") .. "; counted)", AB.SAME)
	end
	return count
end

function AB.OwnTimerText(c)
	if not AB.CleanerShown(c) or c.own_timer_on == nil then return "" end
	if not c.own_timer_on then return "off, so it never cleans by itself" end
	local every = c.own_timer_s or 0
	local text = every % 60 == 0 and string.format("every %d min", every / 60) or string.format("every %d s", every)
	if c.own_runs == nil then return text .. ", held, so it did not clean by itself" end
	if c.own_runs == 0 then return text .. " after its first cleanup; the phase ended before it came round" end
	return text .. string.format(" after its first cleanup; ran %d time%s", c.own_runs, c.own_runs == 1 and "" or "s")
end

local function AlcRuns(c)
	if not AB.AlcShown(c) then return "" end
	local count = tostring(math.floor((c.cleanups or 0) + 0.5))
	if (c.own_cleanups or 0) > 0 then count = count .. string.format(" (%d on its own)", c.own_cleanups) end
	return count
end

local ACTION_NAMES = { { "idle", "idle" }, { "combat", "combat" }, { "menu", "inventory" } }

function AB.PlayerText(c)
	local parts = {}
	for _, action in ipairs(ACTION_NAMES) do
		local count = c["player_" .. action[1] .. "s"] or 0
		if count > 0 then parts[#parts + 1] = string.format("%s %dx (%d s)", action[2], count, math.floor((c["player_" .. action[1] .. "_s"] or 0) + 0.5)) end
	end
	if (c.player_skipped or 0) > 0 then parts[#parts + 1] = string.format("inventory skipped %dx near the limit", c.player_skipped) end
	return table.concat(parts, ", ")
end

local EFFECTS = {
	{ "acted_idle", "ALC cleaned on its idle check %dx" },
	{ "acted_menu", "ALC cleaned in the inventory %dx" },
	{ "acted_after_combat", "ALC cleaned after combat %dx" },
	{ "held_alc", "ALC held off in combat %dx" },
	{ "held_mgc", "MGC skipped its check in combat %dx" },
}

function AB.PlayerEffects(c)
	local parts = {}
	for _, effect in ipairs(EFFECTS) do
		if (c[effect[1]] or 0) > 0 then parts[#parts + 1] = string.format(effect[2], c[effect[1]]) end
	end
	return table.concat(parts, ", ")
end

function AB.IsBenchColumn(c)
	return c.after == true or c.label == "Before"
end

local function GameShown(c)
	return (c.game_cleanups or 0) > 0 or (c.game_lua or 0) >= 0.05 or (not AB.IsBenchColumn(c) and (c.load_s or c.reload_s or c.lua_post_travel or c.lua_post_reload) ~= nil)
end

local function Freed(c, kind)
	local total, any = 0, false
	for _, step in ipairs({ "travel", "reload" }) do
		local before, after = c[kind .. "_pre_" .. step], c[kind .. "_post_" .. step]
		if before and after then total, any = total + before - after, true end
	end
	return any and total or nil
end

function AB.LoadLua(c) return Freed(c, "lua") end
function AB.LoadPool(c) return Freed(c, "pool") end

function AB.AlcMethodsText(c)
	local parts = {}
	if c.methods then parts[#parts + 1] = c.methods end
	if c.lowmem_methods then parts[#parts + 1] = c.lowmem_methods end
	return #parts > 0 and Paint(table.concat(parts, ", "), AB.ALC_COLOR) or ""
end

local function LoadText(c)
	local parts = {}
	if c.load_s then parts[#parts + 1] = "Loading screen" end
	if c.reload_s then parts[#parts + 1] = "Reload" end
	return table.concat(parts, ", ")
end

function AB.GameMethodsText(c)
	local parts = {}
	if (c.game_cleanups or 0) > 0 then parts[#parts + 1] = string.format("GC %dx", c.game_cleanups) end
	if not AB.IsBenchColumn(c) and LoadText(c) ~= "" then parts[#parts + 1] = LoadText(c) end
	return table.concat(parts, ", ")
end

function AB.BenchMethodsText(c)
	if not AB.IsBenchColumn(c) or LoadText(c) == "" then return "" end
	return Paint(LoadText(c), AB.BENCH_COLOR)
end

local function PhaseLoad(c, kind)
	if AB.IsBenchColumn(c) then return nil end
	return Freed(c, kind)
end

local function BenchLoad(c, kind)
	if not AB.IsBenchColumn(c) then return nil end
	return Freed(c, kind)
end

function AB.WarningText(c)
	if (c.low_warnings or 0) <= 0 then return "" end
	if AB.UI.FailReason(c) then return Paint(c.low_warnings .. " (failed)", BAD) end
	return Paint(c.low_warnings .. " (survived)", GOOD)
end

function AB.AlcReloadText(c)
	if not c.alc_reload_s then return "" end
	return string.format("after %d s at %s MB", math.floor(c.alc_reload_s + 0.5), Fmt(c.alc_reload_pool or 0, 2))
end

local function Show(value) return value and value ~= "" end

local ROWS = {
	{ section = "Run" },
	{ "Length", "seconds", "time" },
	{ "Frames", "frames", "count" },
	{ "ALC", "alc", "text" },
	{ "New garbage", "workload", "text" },
	{ "New memory per second (MB/s)", "made_rate", "rate" },
	{ "Garbage released at start", "released", "size", hide_zero = true },
	{ "Fill held while measuring", "held", "size", hide_zero = true, text = function(c)
		if not c.held or c.held <= 0 then return "" end
		local size = AB.CellText("size", c.held)
		return c.held_until and string.format("%s, let go at %d s", size, c.held_until) or size
	end },
	{ "Simulated actions", "player_menus", "text", when = function(c) return AB.PlayerText(c) ~= "" end, text = AB.PlayerText },
	{ "Simulated actions triggered", "held_alc", "text", when = function(c) return AB.PlayerEffects(c) ~= "" end, text = AB.PlayerEffects },
	{ "Loading screen (s)", "load_s", "secs1", optional = true },
	{ "Reload (s)", "reload_s", "secs1", optional = true },
	{ "Game in the background (s)", "away_s", "count", optional = true },
	{ "Low memory warnings", "low_warnings", "count", hide_zero = true, console = true, text = AB.WarningText },
	{ section = "Lua memory" },
	{ "Start (MB)", "lua_start", "mb" },
	{ "End (MB)", "lua_end", "mb" },
	{ "Average (MB)", "lua_avg", "mb" },
	{ "Peak (MB)", "lua_peak", "mb" },
	{ "Before loading screen (MB)", "lua_pre_travel", "mb" },
	{ "After loading screen (MB)", "lua_post_travel", "mb" },
	{ "Before reload (MB)", "lua_pre_reload", "mb", optional = true },
	{ "After reload (MB)", "lua_post_reload", "mb", optional = true },
	{ section = "Add-on pool", key = "pool_cap" },
	{ "Start (MB)", "pool_start", "mb", optional = true },
	{ "End (MB)", "pool_end", "mb", optional = true },
	{ "Average (MB)", "pool_avg", "mb", optional = true },
	{ "Peak (MB)", "pool_peak", "mb", optional = true },
	{ "Before loading screen (MB)", "pool_pre_travel", "mb", optional = true },
	{ "After loading screen (MB)", "pool_post_travel", "mb", optional = true },
	{ "Before reload (MB)", "pool_pre_reload", "mb", optional = true },
	{ "After reload (MB)", "pool_post_reload", "mb", optional = true },
	{ "Capacity (MB)", "pool_cap", "mb_plain", optional = true },
	{ "Full after", "pool_full_at", "secs", optional = true },
	{ "Lua when pool filled (MB)", "lua_at_full", "mb_plain", optional = true },
	{ "Lua growth past full pool (MB)", "lua_past_full", "mb", optional = true },
	{ section = "ALC", when = AB.AlcShown },
	{ "Cleanups", "cleanups", "count", when = AB.AlcShown, text = AlcRuns },
	{ "Methods used", "methods", "text", when = function(c) return Show(AB.AlcMethodsText(c)) end, text = AB.AlcMethodsText },
	{ "Freed Lua (MB)", "freed_lua", "mb_plain", when = AB.AlcShown, text = function(c) return AB.AlcShown(c) and Fmt(c.freed_lua or 0) or "" end },
	{ "Freed pool (MB)", "freed_pool", "mb_plain", console = true, when = AB.AlcShown, text = function(c) return AB.AlcShown(c) and Fmt(c.freed_pool or 0) or "" end },
	{ "Reloaded for low memory", "alc_reload_s", "text", console = true, when = function(c) return c.alc_reload_s ~= nil end, text = AB.AlcReloadText },
	{ section = "Other Lua cleaner", when = AB.CleanerShown },
	{ "Cleaner", "cleaner", "text", when = AB.CleanerShown, text = AB.CleanerText },
	{ "Own timer", "own_timer_on", "text", when = function(c) return AB.OwnTimerText(c) ~= "" end, text = AB.OwnTimerText },
	{ "Cleanups", "other_cleanups", "count", when = AB.CleanerShown, text = CleanerRuns },
	{ "Freed Lua (MB)", "other_freed_lua", "mb_plain", when = AB.CleanerShown, text = function(c) return AB.CleanerShown(c) and Fmt(c.other_freed_lua or 0) or "" end },
	{ "Freed pool (MB)", "other_freed_pool", "mb_plain", console = true, when = AB.CleanerShown, text = function(c) return AB.CleanerShown(c) and Fmt(c.other_freed_pool or 0) or "" end },
	{ section = "Vanilla", when = GameShown },
	{ "Methods used", "game_cleanups", "text", when = function(c) return Show(AB.GameMethodsText(c)) end, text = AB.GameMethodsText },
	{ "Freed Lua (MB)", "game_lua", "mb_plain", when = function(c) return (c.game_cleanups or 0) > 0 or (c.game_lua or 0) >= 0.05 end, text = function(c) return c.game_lua and Fmt(c.game_lua) or "" end },
	{ "Freed pool (MB)", "game_pool", "mb_plain", console = true, when = function(c) return (c.game_pool or 0) >= 0.05 end, text = function(c) return c.game_pool and Fmt(c.game_pool) or "" end },
	{ "Load or reload freed Lua (MB)", "lua_post_travel", "mb_signed", when = function(c) return PhaseLoad(c, "lua") ~= nil end, text = function(c) local v = PhaseLoad(c, "lua") return v and Signed(v) or "" end },
	{ "Load or reload freed pool (MB)", "pool_post_travel", "mb_signed", console = true, when = function(c) return PhaseLoad(c, "pool") ~= nil end, text = function(c) local v = PhaseLoad(c, "pool") return v and Signed(v) or "" end },
	{ section = "Benchmark (not counted)", when = function(c) return Show(AB.BenchMethodsText(c)) or BenchLoad(c, "lua") ~= nil end },
	{ "Methods used", "load_s", "text", when = function(c) return Show(AB.BenchMethodsText(c)) end, text = AB.BenchMethodsText },
	{ "Freed Lua (MB)", "lua_pre_travel", "mb_signed", when = function(c) return BenchLoad(c, "lua") ~= nil end, text = function(c) local v = BenchLoad(c, "lua") return v and Signed(v) or "" end },
	{ "Freed pool (MB)", "pool_pre_travel", "mb_signed", console = true, when = function(c) return BenchLoad(c, "pool") ~= nil end, text = function(c) local v = BenchLoad(c, "pool") return v and Signed(v) or "" end },
}
local LOWER_IS_BETTER = { mb = true, secs1 = true }
local HIGHER_IS_BETTER = {}

local function Tint(text, color)
	return string.format("|c%02x%02x%02x%s|r", math.floor(color[1] * 255), math.floor(color[2] * 255), math.floor(color[3] * 255), text)
end

local function CellText(kind, value)
	if value == nil then return "" end
	if kind == "text" then return tostring(value) end
	if kind == "time" then return string.format("%d:%02d", math.floor(value / 60), math.floor(value % 60)) end
	if kind == "rate" then return Fmt(value, 2) end
	if kind == "mb_signed" then return Signed(value) end
	if kind == "secs1" then return Fmt(value, 1) end
	if kind == "secs" then return string.format("%d s", math.floor(value + 0.5)) end
	if kind == "count" then return tostring(math.floor(value + 0.5)) end
	if kind == "size" then
		if value >= 1 then return Fmt(value, 1) .. " MB" end
		return math.floor(value * 1024 + 0.5) .. " KB"
	end
	return Fmt(value, 1)
end

AB.SAME_MARGIN = { mb = { 1, 0 }, mb_signed = { 1, 0 }, mb_plain = { 1, 0 }, secs1 = { 0.5, 0.05 } }

local function DeltaText(kind, value, other, direction, same)
	if value == nil or other == nil or type(value) ~= "number" or type(other) ~= "number" then return "" end
	local lower = direction == "low" or (direction == nil and LOWER_IS_BETTER[kind])
	local higher = direction == "high" or (direction == nil and HIGHER_IS_BETTER[kind])
	if not (lower or higher) then return "" end
	local diff = value - other
	if math.abs(diff) < 0.05 then return "" end
	local signed = (diff > 0 and "+" or "") .. Fmt(diff, 1)
	if same and math.abs(diff) <= math.max(same[1], same[2] * math.abs(other)) then return " " .. Tint(signed, AB.SAME) end
	local better = lower and diff < 0 or higher and diff > 0
	return " " .. Tint(signed, better and GOOD or BAD)
end
AB.ROWS, AB.Tint, AB.CellText, AB.DeltaText = ROWS, Tint, CellText, DeltaText
