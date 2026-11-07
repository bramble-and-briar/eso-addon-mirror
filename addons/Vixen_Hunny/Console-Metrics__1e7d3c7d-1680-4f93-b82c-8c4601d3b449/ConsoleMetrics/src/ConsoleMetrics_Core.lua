-- ConsoleMetrics_Core.lua
-- Addon namespace, saved-variable defaults, tuning constants and generic helpers.
--
-- Module layout (load order follows ConsoleMetrics.addon):
--   Core        namespace, defaults, constants, number/text/stat helpers   -> ConsoleMetrics.Util
--   Build       action bars, gear, sets, boons, role profiles              -> ConsoleMetrics.Build
--   Champion    champion point scanning                                    -> ConsoleMetrics.Champion
--   Sets        set catalog, proc classification, custom rules, PCT import -> ConsoleMetrics.Sets
--   FightData   fight model, summaries, history, saved fights, ML model    -> ConsoleMetrics.Fight
--   Combat      combat event processing and trace output
--   Chat        chat sharing (links + text)
--   Dialog      gamepad/console dialog (LibConsoleDialogs)
--   PCDialog    keyboard/mouse window
--   LibFights   optional LibFights bridge (logging control, panel rows)
--   Integration journal menu hooks
--   Debug       diagnostic dumps
--   Settings    saved-variable schema, settings menu, presets
--   Commands    /cm slash commands
--   Init        initialization, events, update loop
--
-- Helpers are shared through namespaced tables and imported as file locals;
-- nothing except the ConsoleMetrics table itself is written to _G.

local ADDON_NAME = "ConsoleMetrics"

ConsoleMetrics = {
    name = ADDON_NAME,
    version = "1.1.0",
    defaults = {
        autoClearOnNextFight = true,
        maxFightHistory = 25,
        performanceMode = false,
        lowMemoryMode = true,
        dialogAutoHide = true,
        dialogAutoHideSeconds = 12,
        closeOnMove = false,
        debugEnabled = false,
        drSampleAlpha = 0.35,
        ioTraceEnabled = false,
        ioTraceMode = "summary",
        ioTraceTargetMode = "off",
        ioTraceTargetName = "",
        ioTraceTargetOnlyProcessing = false,
        ioTraceSkipResourceSampling = false,
        ioTraceTargetGraceMs = 1500,
        ioTraceMaxLinesPerSecond = 40,
        ioTraceMinValue = 0,
        ioTraceSummarySeconds = 1,
        behaviorModelEnabled = false,
        behaviorModelRefreshMs = 1500,
        customSetRules = {},
        saveFightDraftName = "",
        loadFightDraftName = "",
        savedFights = {},
        maxSavedFights = 10,
        libFightsAutoStart = true,
    },

    -- Runtime state (not persisted).
    ui = {},
    saved = nil,
    inCombat = false,
    fight = nil,
    fightHistory = {},
    viewFightIndex = 0,
    dialogPanel = "main",
    dialogAutoHideAtMs = nil,
    dialogRefreshAtMs = nil,
    lastDialogRefreshKey = nil,
    wasFightViewDialogShowing = false,
    isClosingFightViewDialog = false,
    lastMetricsUpdateMs = 0,
    lastProtectionUpdateMs = 0,
    lastEffectStateEventMs = 0,
    lastTraceTargetMatchMs = nil,
    trackedSetMatchById = {},
    trackedSetMatchByName = {},
    ioTraceState = nil,
    behaviorModelCache = nil,
    fightSnapshotCache = nil,
    observedAbilityLog = {},
    observedAbilityCount = 0,
    fpsRuntime = nil,
    playerName = nil,
}

---------------------------------------------------------------------------
-- Tuning constants
---------------------------------------------------------------------------
local DIALOG_LIVE_REFRESH_MS = 500
local METRICS_UPDATE_THROTTLE_MS = 250
local PROTECTION_UPDATE_THROTTLE_MS = 500
local EFFECT_STATE_EVENT_THROTTLE_MS = 25
local RESISTANCE_CAP = 33000
local RESISTANCE_SCALE = 66000
local TOP_MOMENTS_LIMIT = 30
local MAJOR_PROTECTION_DR_PCT = 10
local MINOR_PROTECTION_DR_PCT = 5
local EFFECTS_PANEL_LIMIT = 30
local THROUGHPUT_WINDOW_INTERVAL_MS = 1000
local RESOURCE_SAMPLE_INTERVAL_MS = 1000
local RESOURCE_SAMPLE_MAX_POINTS = 1200
local OBSERVED_ABILITY_LOG_MAX = 2048
local MAX_FIGHT_HISTORY_HARD_CAP = 40
local LOW_MEMORY_LIST_LIMIT = 20
local LOW_MEMORY_MOMENTS_LIMIT = 12
local LOW_MEMORY_EFFECT_LIMIT = 20
local PING_DIP_DELTA_MS = 25
local PING_SPIKE_DELTA_MS = 40
local PING_HIGH_DELAY_MS = 140

-- Bounded cache for zo_strformat'd unit names (combat events are very chatty).
local UNIT_NAME_CACHE = {}
local UNIT_NAME_CACHE_SIZE = 0
local UNIT_NAME_CACHE_MAX = 512

---------------------------------------------------------------------------
-- Resource power types
---------------------------------------------------------------------------
-- Resolved lazily so every game constant is bound by the time we look it up.
-- Each entry is a list: the modern COMBAT_MECHANIC_FLAGS_* value first, then
-- the legacy POWERTYPE_* value as a fallback for GetUnitPower.
local RESOURCE_POWER_TYPES_CACHE = nil

local function GetResourcePowerTypes()
    if RESOURCE_POWER_TYPES_CACHE then
        return RESOURCE_POWER_TYPES_CACHE
    end

    local function Resolve(flagsName, legacyName, flagsDefault)
        local list = { tonumber(_G[flagsName]) or flagsDefault }
        local legacy = tonumber(_G[legacyName])
        if legacy ~= nil and legacy ~= list[1] then
            list[#list + 1] = legacy
        end
        return list
    end

    RESOURCE_POWER_TYPES_CACHE = {
        health   = Resolve("COMBAT_MECHANIC_FLAGS_HEALTH",   "POWERTYPE_HEALTH",   32),
        magicka  = Resolve("COMBAT_MECHANIC_FLAGS_MAGICKA",  "POWERTYPE_MAGICKA",  1),
        stamina  = Resolve("COMBAT_MECHANIC_FLAGS_STAMINA",  "POWERTYPE_STAMINA",  4),
        ultimate = Resolve("COMBAT_MECHANIC_FLAGS_ULTIMATE", "POWERTYPE_ULTIMATE", 8),
    }

    return RESOURCE_POWER_TYPES_CACHE
end

---------------------------------------------------------------------------
-- Colors
---------------------------------------------------------------------------
local function ColorFromHex(hex)
    local clean = (hex or "FFFFFF"):gsub("#", "")
    local r = tonumber(clean:sub(1, 2), 16) or 255
    local g = tonumber(clean:sub(3, 4), 16) or 255
    local b = tonumber(clean:sub(5, 6), 16) or 255
    return { r / 255, g / 255, b / 255 }
end

local function SafeAbilityId(abilityId)
    return math.floor(tonumber(abilityId) or 0)
end

local function FormatAbilityIdentity(abilityName, abilityId)
    return string.format("%s [id:%d]", abilityName or "Unknown", SafeAbilityId(abilityId))
end

local COMBAT_TEXT_COLORS = {
    start = ColorFromHex("#FF7314"),
    summary = ColorFromHex("#FFB04D"),
    damage = ColorFromHex("#FF7D29"),
    damageCrit = ColorFromHex("#FFCC61"),
    heal = ColorFromHex("#3DE378"),
    healCrit = ColorFromHex("#73FF8C"),
    taken = ColorFromHex("#FF4242"),
}

-- Hex strings (no# prefix) for |cHHHHHH...|r ESO color markup in panel labels.
local COMBAT_COLOR_HEX = {
    start      = "FF7314",  -- amber: combat start
    summary    = "FFB04D",  -- gold: summaries
    damage     = "FF7D29",  -- orange: direct damage
    damageCrit = "FFCC61",  -- yellow: critical damage
    dot        = "FF982A",  -- deep orange: damage-over-time ticks
    heal       = "3DE378",  -- green: direct healing
    healCrit   = "73FF8C",  -- bright green: critical healing
    hot        = "52EAA8",  -- teal: heal-over-time ticks
    taken      = "FF4242",  -- red: incoming damage
    shield     = "7BB2FF",  -- blue: absorb/shield
    overflow   = "FF6060",  -- light red: overflow damage/heal
    mitigation = "A0C8FF",  -- sky blue: blocked/shielded mitigation
}

---------------------------------------------------------------------------
-- Number / text formatting
---------------------------------------------------------------------------
local function NumberText(value)
    return ZO_CommaDelimitNumber(math.floor((tonumber(value) or 0) + 0.5))
end

local function ShortNumber(value)
    value = tonumber(value) or 0
    if value >= 1000000 then
        return string.format("%.2fm", value / 1000000)
    end
    if value >= 1000 then
        return string.format("%.1fk", value / 1000)
    end
    return tostring(math.floor(value + 0.5))
end

-- Wrap text in ESO color markup: |cHHHHHH<text>|r
local function ColorText(text, colorHex)
    return string.format("|c%s%s|r", colorHex or "FFFFFF", tostring(text or ""))
end

local function ColorShort(value, colorHex)
    return ColorText(ShortNumber(value), colorHex)
end

local function TrimText(text)
    local value = tostring(text or "")
    value = string.gsub(value, "^%s+", "")
    value = string.gsub(value, "%s+$", "")
    return value
end

local function BuildDefaultFightSaveName(snapshot, slotIndex)
    local topTarget = snapshot and snapshot.targetList and snapshot.targetList[1] or nil
    local targetTag = topTarget and topTarget.name and topTarget.name ~= "" and (" vs " .. topTarget.name) or ""
    return string.format("Slot %d: %.1fs / %s DPS%s", slotIndex or 1, (snapshot and snapshot.duration) or 0, ShortNumber((snapshot and snapshot.dps) or 0), targetTag)
end

-- Recursive table copy (handles shared references and cycles).
local function DeepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end
    seen = seen or {}
    if seen[value] then
        return seen[value]
    end
    local copy = {}
    seen[value] = copy
    for k, v in pairs(value) do
        copy[DeepCopy(k, seen)] = DeepCopy(v, seen)
    end
    return copy
end

---------------------------------------------------------------------------
-- Unit names, action results, clamp
---------------------------------------------------------------------------
local function UnitName(rawName)
    if not rawName or rawName == "" then
        return "Unknown"
    end

    local cached = UNIT_NAME_CACHE[rawName]
    if cached then
        return cached
    end

    local formatted = rawName
    if type(zo_strformat) == "function" then
        formatted = zo_strformat(SI_UNIT_NAME, rawName)
    end

    UNIT_NAME_CACHE[rawName] = formatted
    UNIT_NAME_CACHE_SIZE = UNIT_NAME_CACHE_SIZE + 1
    if UNIT_NAME_CACHE_SIZE > UNIT_NAME_CACHE_MAX then
        UNIT_NAME_CACHE = {}
        UNIT_NAME_CACHE_SIZE = 0
    end

    return formatted
end

local function IsDamageResult(result)
    return result == ACTION_RESULT_DAMAGE
        or result == ACTION_RESULT_DOT_TICK
        or result == ACTION_RESULT_DOT_TICK_CRITICAL
        or result == ACTION_RESULT_CRITICAL_DAMAGE
        or result == ACTION_RESULT_DAMAGE_SHIELDED
        or result == ACTION_RESULT_BLOCKED_DAMAGE
end

local function IsHealResult(result)
    return result == ACTION_RESULT_HEAL
        or result == ACTION_RESULT_HOT_TICK
        or result == ACTION_RESULT_HOT_TICK_CRITICAL
        or result == ACTION_RESULT_CRITICAL_HEAL
end

local function IsCriticalResult(result)
    return result == ACTION_RESULT_CRITICAL_DAMAGE
        or result == ACTION_RESULT_CRITICAL_HEAL
end

local function IsEffectGainedResult(result)
    return result == ACTION_RESULT_EFFECT_GAINED
        or result == ACTION_RESULT_EFFECT_GAINED_DURATION
        or result == ACTION_RESULT_EFFECT_REFRESH
        or result == ACTION_RESULT_EFFECT_REAPPLIED
end

local function IsEffectFadedResult(result)
    return result == ACTION_RESULT_EFFECT_FADED
        or result == ACTION_RESULT_EFFECT_FADED_DURATION
end

local function Clamp(value, minValue, maxValue)
    if value == nil then
        return minValue
    end
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

---------------------------------------------------------------------------
-- Statistics and resource reads
---------------------------------------------------------------------------
local function Mean(values)
    if #values == 0 then
        return 0
    end

    local sum = 0
    for i = 1, #values do
        sum = sum + values[i]
    end

    return sum / #values
end

local function Median(values)
    local count = #values
    if count == 0 then
        return 0
    end

    local sorted = {}
    for i = 1, count do
        sorted[i] = values[i]
    end
    table.sort(sorted)

    local midpoint = math.floor(count / 2)
    if (count % 2) == 1 then
        return sorted[midpoint + 1]
    end

    return (sorted[midpoint] + sorted[midpoint + 1]) / 2
end

local function SafeGetCurrentPowerFromList(powerTypeList)
    if type(GetUnitPower) ~= "function" or type(powerTypeList) ~= "table" then
        return nil
    end

    for i = 1, #powerTypeList do
        local powerType = powerTypeList[i]
        if type(powerType) == "number" then
            local current = GetUnitPower("player", powerType)
            if current and current >= 0 then
                return current
            end
        end
    end

    return nil
end

local function SafeGetMaxPowerFromList(powerTypeList)
    if type(GetUnitPower) ~= "function" or type(powerTypeList) ~= "table" then
        return nil
    end

    for i = 1, #powerTypeList do
        local powerType = powerTypeList[i]
        if type(powerType) == "number" then
            local _, maximum = GetUnitPower("player", powerType)
            if maximum and maximum > 0 then
                return maximum
            end
        end
    end

    return nil
end

local function SafeGetPowerPctFromList(powerTypeList)
    local current = SafeGetCurrentPowerFromList(powerTypeList)
    local maximum = SafeGetMaxPowerFromList(powerTypeList)
    if not current or not maximum or maximum <= 0 then
        return nil
    end

    return Clamp((current / maximum) * 100, 0, 100)
end

local function BuildResourceSampleSummary(values)
    local startIndex = tonumber(values and values._cmStart) or 1
    local count = values and ((#values - startIndex) + 1) or 0
    if count <= 0 then
        return {
            samples = 0,
            averagePct = 0,
            medianPct = 0,
            hasData = false,
        }
    end

    local normalized = {}
    for i = startIndex, #values do
        normalized[#normalized + 1] = tonumber(values[i]) or 0
    end

    return {
        samples = #normalized,
        averagePct = Mean(normalized),
        medianPct = Median(normalized),
        hasData = true,
    }
end

local function BuildNumericSampleSummary(values)
    local startIndex = tonumber(values and values._cmStart) or 1
    local count = values and ((#values - startIndex) + 1) or 0
    if count <= 0 then
        return {
            samples = 0,
            average = 0,
            median = 0,
            min = 0,
            max = 0,
            hasData = false,
        }
    end

    local normalized = {}
    local sum = 0
    local minValue = nil
    local maxValue = nil

    for i = startIndex, #values do
        local value = tonumber(values[i]) or 0
        normalized[#normalized + 1] = value
        sum = sum + value
        if minValue == nil or value < minValue then
            minValue = value
        end
        if maxValue == nil or value > maxValue then
            maxValue = value
        end
    end

    return {
        samples = #normalized,
        average = sum / #normalized,
        median = Median(normalized),
        min = minValue or 0,
        max = maxValue or 0,
        hasData = true,
    }
end

local function SafeGetLatencyMs()
    if type(GetLatency) ~= "function" then
        return nil
    end

    local latency = nil
    local ok = pcall(function()
        latency = GetLatency()
    end)
    if not ok then
        return nil
    end

    latency = tonumber(latency)
    if latency == nil or latency < 0 then
        return nil
    end

    return math.floor(latency + 0.5)
end

local function BuildSustainPerformanceSummary(magickaStats, staminaStats)
    local avgInputs = {}
    local medianInputs = {}

    if magickaStats and magickaStats.hasData then
        avgInputs[#avgInputs + 1] = magickaStats.averagePct or 0
        medianInputs[#medianInputs + 1] = magickaStats.medianPct or 0
    end
    if staminaStats and staminaStats.hasData then
        avgInputs[#avgInputs + 1] = staminaStats.averagePct or 0
        medianInputs[#medianInputs + 1] = staminaStats.medianPct or 0
    end

    if #avgInputs == 0 then
        return {
            hasData = false,
            averagePct = 0,
            medianPct = 0,
            label = "No sustain data",
            sourceCount = 0,
        }
    end

    local averagePct = Mean(avgInputs)
    local medianPct = Mean(medianInputs)
    local label = "Stable"
    if averagePct >= 75 then
        label = "Strong"
    elseif averagePct >= 50 then
        label = "Stable"
    elseif averagePct >= 30 then
        label = "Pressured"
    else
        label = "Critical"
    end

    return {
        hasData = true,
        averagePct = averagePct,
        medianPct = medianPct,
        label = label,
        sourceCount = #avgInputs,
    }
end

local function StdDev(values, mean)
    if #values <= 1 then
        return 0
    end

    local variance = 0
    for i = 1, #values do
        local diff = values[i] - mean
        variance = variance + (diff * diff)
    end

    variance = variance / (#values - 1)
    return math.sqrt(variance)
end

local function LinearSlope(values)
    local n = #values
    if n <= 1 then
        return 0
    end

    local sumX = 0
    local sumY = 0
    local sumXY = 0
    local sumXX = 0

    for i = 1, n do
        local x = i
        local y = values[i]
        sumX = sumX + x
        sumY = sumY + y
        sumXY = sumXY + (x * y)
        sumXX = sumXX + (x * x)
    end

    local denom = (n * sumXX) - (sumX * sumX)
    if denom == 0 then
        return 0
    end

    return ((n * sumXY) - (sumX * sumY)) / denom
end

local function ExponentialAverage(values, alpha)
    if #values == 0 then
        return 0
    end

    local ema = values[1]
    for i = 2, #values do
        ema = alpha * values[i] + (1 - alpha) * ema
    end
    return ema
end

---------------------------------------------------------------------------
-- Output and platform helpers
---------------------------------------------------------------------------
function ConsoleMetrics:Print(message)
    d(string.format("|cFF6A00[%s]|r %s", tostring(self.name or ADDON_NAME), tostring(message)))
end

-- Chat output that only appears when the debugEnabled option is on.
function ConsoleMetrics:DebugPrint(message)
    if self.saved and self.saved.debugEnabled then
        self:Print(message)
    end
end

-- True on console, or on PC while the gamepad UI mode is active.
function ConsoleMetrics.IsGamepadUI()
    if type(IsConsoleUI) == "function" and IsConsoleUI() then
        return true
    end
    return type(IsInGamepadPreferredMode) == "function" and IsInGamepadPreferredMode() == true
end

---------------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------------

ConsoleMetrics.Util = {
    ADDON_NAME = ADDON_NAME,
    BuildDefaultFightSaveName = BuildDefaultFightSaveName,
    BuildNumericSampleSummary = BuildNumericSampleSummary,
    BuildResourceSampleSummary = BuildResourceSampleSummary,
    BuildSustainPerformanceSummary = BuildSustainPerformanceSummary,
    COMBAT_COLOR_HEX = COMBAT_COLOR_HEX,
    COMBAT_TEXT_COLORS = COMBAT_TEXT_COLORS,
    Clamp = Clamp,
    ColorFromHex = ColorFromHex,
    ColorShort = ColorShort,
    ColorText = ColorText,
    DIALOG_LIVE_REFRESH_MS = DIALOG_LIVE_REFRESH_MS,
    DeepCopy = DeepCopy,
    EFFECTS_PANEL_LIMIT = EFFECTS_PANEL_LIMIT,
    EFFECT_STATE_EVENT_THROTTLE_MS = EFFECT_STATE_EVENT_THROTTLE_MS,
    ExponentialAverage = ExponentialAverage,
    FormatAbilityIdentity = FormatAbilityIdentity,
    GetResourcePowerTypes = GetResourcePowerTypes,
    IsCriticalResult = IsCriticalResult,
    IsDamageResult = IsDamageResult,
    IsEffectFadedResult = IsEffectFadedResult,
    IsEffectGainedResult = IsEffectGainedResult,
    IsHealResult = IsHealResult,
    LOW_MEMORY_EFFECT_LIMIT = LOW_MEMORY_EFFECT_LIMIT,
    LOW_MEMORY_LIST_LIMIT = LOW_MEMORY_LIST_LIMIT,
    LOW_MEMORY_MOMENTS_LIMIT = LOW_MEMORY_MOMENTS_LIMIT,
    LinearSlope = LinearSlope,
    MAJOR_PROTECTION_DR_PCT = MAJOR_PROTECTION_DR_PCT,
    MAX_FIGHT_HISTORY_HARD_CAP = MAX_FIGHT_HISTORY_HARD_CAP,
    METRICS_UPDATE_THROTTLE_MS = METRICS_UPDATE_THROTTLE_MS,
    MINOR_PROTECTION_DR_PCT = MINOR_PROTECTION_DR_PCT,
    Mean = Mean,
    Median = Median,
    NumberText = NumberText,
    OBSERVED_ABILITY_LOG_MAX = OBSERVED_ABILITY_LOG_MAX,
    PING_DIP_DELTA_MS = PING_DIP_DELTA_MS,
    PING_HIGH_DELAY_MS = PING_HIGH_DELAY_MS,
    PING_SPIKE_DELTA_MS = PING_SPIKE_DELTA_MS,
    PROTECTION_UPDATE_THROTTLE_MS = PROTECTION_UPDATE_THROTTLE_MS,
    RESISTANCE_CAP = RESISTANCE_CAP,
    RESISTANCE_SCALE = RESISTANCE_SCALE,
    RESOURCE_SAMPLE_INTERVAL_MS = RESOURCE_SAMPLE_INTERVAL_MS,
    RESOURCE_SAMPLE_MAX_POINTS = RESOURCE_SAMPLE_MAX_POINTS,
    SafeAbilityId = SafeAbilityId,
    SafeGetCurrentPowerFromList = SafeGetCurrentPowerFromList,
    SafeGetLatencyMs = SafeGetLatencyMs,
    SafeGetMaxPowerFromList = SafeGetMaxPowerFromList,
    SafeGetPowerPctFromList = SafeGetPowerPctFromList,
    ShortNumber = ShortNumber,
    StdDev = StdDev,
    THROUGHPUT_WINDOW_INTERVAL_MS = THROUGHPUT_WINDOW_INTERVAL_MS,
    TOP_MOMENTS_LIMIT = TOP_MOMENTS_LIMIT,
    TrimText = TrimText,
    UnitName = UnitName,
}
ConsoleMetrics._shared = ConsoleMetrics.Util  -- backwards-compatible alias
