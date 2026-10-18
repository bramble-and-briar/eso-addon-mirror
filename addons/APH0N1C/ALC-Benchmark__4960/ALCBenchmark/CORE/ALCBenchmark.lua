--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

ALCBenchmark = {}
local AB = ALCBenchmark

local NAME = "ALCBenchmark"
AB.VERSION = "2026.10.15.14.36"
local THEME = LibAPH.THEME
local GS = {}
local TIMING = {
	before = 3000,
	travel_settle = 3000,
	auto_delay = 1000,
	auto_timeout = 20000,
	auto_retries = 3,
	auto_retry_delay = 3000,
	reload_delay = 1000,
	isolate_settle = 10000,
	force_at = 5000,
	kill_share = 0.9,
	limit_margin = 2,
	alc_reload_margin = 1,
	heading_margin = 0.5,
	alc_heading_margin = 0.25,
	limit_retries = 2,
	fill_hold_mb_pc = 50,
	fill_hold_pool_console = 65,
	fill_release_before_s = 10,
	fill_settle = 1000,
	fill_timeout = 20000,
	fill_cap_margin_mb = 1.5,
	save_share = 0.75,
	save_every = 10000,
	continue_max = 1800,
	resume_age_sec = 300,
	max_load = 600000,
}
local CHUNK_ENTRIES = 1024
local FILL_MB_PER_FRAME = 2
local ALC_BUSY_MS = 1500
AB.GAME_RUN_GAP_MS = 2000
local POOL_FULL_MARGIN_MB = 1
local DEFAULT_SECONDS = 60
local DEFAULT_CHURN_MB = 0
local MIN_SECONDS_PC, MIN_SECONDS_CONSOLE = 10, 10
local MIN_CHURN_CONSOLE_MB = 0.1
local MENU_GAP = 4
local MAX_COLUMNS = IsConsoleUI() and 18 or 24
local HISTORY_MAX = 50
local GOOD = { 0.61, 0.82, 0.3 }
local BAD = { 1, 0.25, 0.25 }
AB.SAME = { 0.35, 0.68, 1 }
AB.ALC_COLOR = { 0.78, 0.5, 1 }
AB.BENCH_COLOR = { 0.62, 0.62, 0.66 }
AB.PINK = { 1, 0.48, 0.78 }

local UI = {}

local function Say(text)
	LibAPH.SendRawChatLine("|c00FFFF[ALC Bench]|r " .. text)
end

local TRAVEL_TEXT = "Travel to another zone/house so a loading screen runs. Do not /reloadui."

local function ClampSeconds(seconds)
	return math.max(IsConsoleUI() and MIN_SECONDS_CONSOLE or MIN_SECONDS_PC, math.floor(seconds))
end

local function ClampChurn(churn)
	churn = math.max(0, churn)
	if IsConsoleUI() and churn > 0 then churn = math.max(MIN_CHURN_CONSOLE_MB, churn) end
	return churn
end

local function AnnounceTravel()
	Say(TRAVEL_TEXT)
	LibAPH.SafeCSA(true, "ALC Benchmark", TRAVEL_TEXT, 8000)
end

local function LuaMB()
	return collectgarbage("count") / 1024
end

local function PoolCapacityMB()
	local cap = GetTotalUserAddOnMemoryPoolCapacityMB and GetTotalUserAddOnMemoryPoolCapacityMB()
	if cap and cap > 0 then return cap end
	return nil
end

local function PoolLimitMB()
	local cap = PoolCapacityMB()
	return cap and cap * TIMING.kill_share
end

local function PoolMB()
	if not PoolCapacityMB() then return nil end
	return GetTotalUserAddOnMemoryPoolUsageMB()
end

local function Alc()
	return rawget(_G, "AutoLuaMemoryCleaner") or rawget(_G, "ALC")
end

local function AlcState()
	local alc = Alc()
	if not (alc and alc.settings) then return "not loaded" end
	if not alc.settings.is_enabled then return "loaded, Auto Lua Cleanup off" end
	return tostring(alc.settings.cleanup_mode)
end

local METHOD_NAMES = { vanilla = "Vanilla", automatic = "Automatic", background = "Background", aggressive = "Aggressive", deep = "Deep Clean", rescue = "Rescue" }
local CLEANERS = {
	{ key = "mgc", name = "Memory Garbage Collector", short = "MGC", letter = "F", timer = "MemoryGarbageCollector_Auto" },
	{ key = "shissu", name = "Shissu's LUA Memory", short = "Shissu", letter = "G", timer = "shissuLUAMemory_Auto" },
}
local CLEANER_BY_KEY = {}
for _, cleaner in ipairs(CLEANERS) do CLEANER_BY_KEY[cleaner.key] = cleaner end

local function MethodLabel()
	local alc = Alc()
	if not (alc and alc.settings) or not alc.settings.is_enabled then return "Vanilla" end
	return METHOD_NAMES[alc.settings.cleanup_mode] or tostring(alc.settings.cleanup_mode)
end

local GAME_ONLY = { Vanilla = true }

local function SetAlcMode(alc, mode)
	if type(alc.set_cleanup_mode) == "function" then alc.set_cleanup_mode(mode) else alc.settings.cleanup_mode = mode end
end

function AB.HoldAlcReloads(alc)
	alc.settings.auto_clear_pool_on_teleport = false
	alc.settings.afk_reload = false
	if alc.toggle_afk_watch then alc.toggle_afk_watch() end
end

local function MakeChunk()
	local chunk = {}
	for index = 1, CHUNK_ENTRIES do chunk[index] = index end
	return chunk
end

local function ChunkKB()
	if AB.measured_chunk_kb then return AB.measured_chunk_kb end
	local best = 0
	for _ = 1, 4 do
		local keep = {}
		local before = collectgarbage("count")
		for index = 1, 16 do keep[index] = MakeChunk() end
		best = math.max(best, (collectgarbage("count") - before) / #keep)
	end
	AB.measured_chunk_kb = math.max(1, best)
	return AB.measured_chunk_kb
end

local function Hold(store, mb)
	local chunks = math.max(1, math.floor(mb * 1024 / ChunkKB() + 0.5))
	for _ = 1, chunks do store[#store + 1] = MakeChunk() end
end

local CPU_MARGIN_MS = 5

local function CpuRoom()
	if not (GetTotalUserAddOnCPUTimeAvailableEachFrameMS and GetTotalUserAddOnCPUTimeUsedNowMS) then return true end
	local available = GetTotalUserAddOnCPUTimeAvailableEachFrameMS()
	if type(available) ~= "number" or available <= 0 then return true end
	return available - GetTotalUserAddOnCPUTimeUsedNowMS() > CPU_MARGIN_MS
end

local function MakeGarbage(mb)
	local chunks = math.floor(mb * 1024 / ChunkKB())
	for _ = 1, chunks do MakeChunk() end
	return chunks * ChunkKB() / 1024
end

local function Fmt(value, places)
	return string.format("%." .. (places or 1) .. "f", value or 0)
end
AB.NAME, AB.THEME, AB.GS, AB.TIMING, AB.FILL_MB_PER_FRAME = NAME, THEME, GS, TIMING, FILL_MB_PER_FRAME
AB.CpuRoom = CpuRoom
AB.ALC_BUSY_MS, AB.POOL_FULL_MARGIN_MB, AB.DEFAULT_SECONDS, AB.DEFAULT_CHURN_MB = ALC_BUSY_MS, POOL_FULL_MARGIN_MB, DEFAULT_SECONDS, DEFAULT_CHURN_MB
AB.MIN_SECONDS_PC, AB.MIN_SECONDS_CONSOLE, AB.MENU_GAP, AB.MAX_COLUMNS, AB.HISTORY_MAX = MIN_SECONDS_PC, MIN_SECONDS_CONSOLE, MENU_GAP, MAX_COLUMNS, HISTORY_MAX
AB.GOOD, AB.BAD, AB.UI, AB.Say, AB.TRAVEL_TEXT = GOOD, BAD, UI, Say, TRAVEL_TEXT
AB.ClampSeconds, AB.ClampChurn, AB.AnnounceTravel, AB.LuaMB, AB.PoolCapacityMB, AB.PoolMB, AB.PoolLimitMB = ClampSeconds, ClampChurn, AnnounceTravel, LuaMB, PoolCapacityMB, PoolMB, PoolLimitMB
AB.Alc, AB.AlcState, AB.METHOD_NAMES, AB.MethodLabel = Alc, AlcState, METHOD_NAMES, MethodLabel
AB.GAME_ONLY, AB.SetAlcMode, AB.ChunkKB, AB.Hold, AB.MakeGarbage, AB.Fmt = GAME_ONLY, SetAlcMode, ChunkKB, Hold, MakeGarbage, Fmt
AB.CLEANERS, AB.CLEANER_BY_KEY = CLEANERS, CLEANER_BY_KEY
