-- BetterEffectViewer: core namespace, constants, defaults and shared helpers.

BetterEffectViewer = {
    name = "BetterEffectViewer",
    title = "|c4FC3F7Better|rEffectViewer",
    version = "2.0",
    author = "Vixen Hunny",

    effects = {},
    effectCount = 0,
    runtime = {},
}

BetterEffectViewer.Auth = {
    "@Mastcrs",
    "@Vixen Hunny",
    "@Bexztar",
    "@blu3topaz",
    "@Kix Flipz",
    "@Xvwly",
    "@ViperMarquis",
}

local BEV = BetterEffectViewer

-- Effects lasting at least this long (seconds) are treated as permanent.
BEV.PERMANENT_DURATION_THRESHOLD = 600
-- Vertical gap between the header and groups, and between the two groups.
BEV.HEADER_GAP = 4
BEV.GROUP_GAP = 6
-- Hard ceiling on slots created per group, whatever the settings say.
BEV.MAX_SLOTS_PER_GROUP = 120

-- Seed lists for fresh installs. Kept out of `defaults` so ZO_SavedVars does not
-- re-add entries the user has deliberately removed.
BEV.DEFAULT_WHITELIST = {
    [61747] = true,
    [61745] = true,
}

BEV.DEFAULT_BLACKLIST = {
    [64228] = true,
}

BEV.defaults = {
    -- Window
    offsetX = 0,
    offsetY = -250,
    lockWindow = true,

    -- Display
    showBuffs = true,
    showDebuffs = true,
    showPermanents = true,
    showTargetName = true,
    targetNameFontSize = 16,
    groupOrder = "buffsFirst",
    alignment = "center",
    collapseEmptyRows = false,
    iconSpacing = 3,
    borderSize = 1,
    maxRows = 4,
    showDurationSweep = true,
    dimOtherEffects = true,
    reticleHoldDuration = 1.0,
    fadeOutDuration = 0.6,

    -- Per-content layouts (PvP is used in Cyrodiil, Imperial City and battlegrounds)
    pveLayout = {
        iconSize = 32,
        fontSize = 18,
        maxCols = 10,
    },
    pvpLayout = {
        iconSize = 36,
        fontSize = 20,
        maxCols = 8,
    },

    -- Sorting & filtering
    sortMode = "shortest",
    playerEffectsFirst = false,
    filterMode = "none",
    autoWhitelist = true,
    autoWhitelistDuration = 5,
    maxWhitelistSize = 500,

    -- Timers
    decimalThreshold = 10,
    flashThreshold = 5,
    flashColor = { 1.0, 1.0, 1.0, 1.0 },

    -- Colors
    playerEffectBorderColor = { 0.2, 0.8, 1.0, 1.0 },
    buffBorderColor = { 0.2, 0.8, 0.2, 1.0 },
    debuffBorderColor = { 0.9, 0.2, 0.2, 1.0 },
    permanentBorderColor = { 0.2, 0.6, 1.0, 1.0 },
    buffTimerColor = { 1.0, 1.0, 1.0, 1.0 },
    debuffTimerColor = { 1.0, 0.6, 0.3, 1.0 },
    permanentTimerColor = { 0.8, 0.8, 1.0, 1.0 },
    stackColor = { 1.0, 0.92, 0.75, 1.0 },

    -- Performance
    performanceMode = "low",
    fallbackRescanInterval = 1.5,
    autoConsoleTuning = true,
    consoleSlotRowsCap = 5,
    consoleEffectCap = 96,
    consoleMaxColsCap = 8,
}

-- Update cadences in seconds.
BEV.PERFORMANCE_PROFILES = {
    balanced = { maintenance = 0.25, visualFast = 0.1, visualNormal = 0.25, visualIdle = 0.5 },
    low = { maintenance = 0.4, visualFast = 0.15, visualNormal = 0.35, visualIdle = 0.75 },
    ultra = { maintenance = 0.6, visualFast = 0.25, visualNormal = 0.5, visualIdle = 1.0 },
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

function BEV.Clamp(value, minValue, maxValue, fallback)
    local n = tonumber(value) or fallback
    if n < minValue then
        return minValue
    elseif n > maxValue then
        return maxValue
    end
    return n
end

function BEV.ClampInt(value, minValue, maxValue, fallback)
    return math.floor(BEV.Clamp(value, minValue, maxValue, fallback))
end

function BEV:UnpackColor(t)
    return t[1], t[2], t[3], t[4]
end

function BEV:Print(message, ...)
    if select("#", ...) > 0 then
        message = string.format(message, ...)
    end
    d(string.format("%s: %s", self.title, message))
end

-- Numeric keys are cheaper than formatted strings and are what the event and
-- rescan paths both produce for the same effect.
function BEV:MakeEffectKey(abilityId, effectType)
    return (abilityId or 0) * 4 + (effectType or 0)
end

function BEV:IsPermanentEffect(startTime, endTime)
    if not endTime or endTime == 0 then
        return true
    end
    return startTime ~= nil and (endTime - startTime) >= self.PERMANENT_DURATION_THRESHOLD
end

function BEV:TimeRemaining(effect, now)
    if effect.isPermanent or not effect.endTime or effect.endTime == 0 then
        return math.huge
    end
    return effect.endTime - (now or GetFrameTimeSeconds())
end

function BEV:FormatTime(remaining)
    if remaining == math.huge or remaining <= 0 then
        return ""
    elseif remaining < (self.sv.decimalThreshold or 0) then
        return string.format("%.1f", remaining)
    elseif remaining < 60 then
        return tostring(math.floor(remaining))
    elseif remaining < 3600 then
        return string.format("%d:%02d", math.floor(remaining / 60), math.floor(remaining % 60))
    end
    return string.format("%dh", math.floor(remaining / 3600))
end

function BEV:GetPerformanceProfile()
    local mode = self.runtime.performanceMode or self.sv.performanceMode
    return self.PERFORMANCE_PROFILES[mode] or self.PERFORMANCE_PROFILES.low
end

function BEV:GetRescanInterval()
    return self.runtime.rescanInterval or self.sv.fallbackRescanInterval or self.defaults.fallbackRescanInterval
end
