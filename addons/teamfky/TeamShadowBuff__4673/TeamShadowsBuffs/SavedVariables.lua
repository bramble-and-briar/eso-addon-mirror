TeamShadowsBuffs = TeamShadowsBuffs or {}

local TSB = TeamShadowsBuffs

TSB.name = "TeamShadowsBuffs"
TSB.displayName = "Team Shadows Buffs"
TSB.version = "1.1.10"
TSB.iconPath = "TeamShadowsBuffs/icons/team_shadows_buffs.dds"
TSB.savedVariableName = "TeamShadowsBuffsSavedVariables"
TSB.savedVariableVersion = 1

TSB.defaults = {
    enabled = true,
    debug = false,
    unlocked = true,
    layout = "combined",
    scale = 1.0,
    circleSize = 40,
    frameColor = { r = 0, g = 0, b = 0 },
    frameAlpha = 0.78,
    borderEnabled = true,
    borderColor = { r = 0.86, g = 0.72, b = 0.32 },
    borderAlpha = 0.95,
    borderThickness = 3,
    nameTextColor = { r = 1, g = 1, b = 1 },
    timerTextColor = { r = 1, g = 1, b = 1 },
    acronymTextColor = { r = 1, g = 1, b = 1 },
    cooldownColor = { r = 0.88, g = 0.24, b = 0.08, a = 1 },
    badgeAlpha = 0.95,
    barAlpha = 0.95,
    textAlpha = 1.0,
    timerTextScale = 1.0,
    compactTimerPosition = "above",
    showNames = true,
    showTimers = true,
    showAcronyms = true,
    showStacks = true,
    showBar = true,
    stackTextColor = { r = 1, g = 0.95, b = 0.55 },
    catalogLanguage = "fr",
    catalogNamesByLanguage = {},
    previewEnabled = true,
    managerWindowX = nil,
    managerWindowY = nil,
    launcherX = 36,
    launcherY = 300,
    launcherSize = 64,
    launcherVisible = true,
    combinedX = 220,
    combinedY = 160,
    buffsX = 120,
    buffsY = 260,
    debuffsX = 620,
    debuffsY = 260,
    panel1X = 220,
    panel1Y = 160,
    panel2X = 480,
    panel2Y = 160,
    panel3X = 740,
    panel3Y = 160,
    panel4X = 1000,
    panel4Y = 160,
    free1X = 920,
    free1Y = 480,
    free2X = 920,
    free2Y = 540,
    free3X = 920,
    free3Y = 600,
    free4X = 920,
    free4Y = 660,
    free5X = 920,
    free5Y = 720,
    free6X = 920,
    free6Y = 780,
    free7X = 1040,
    free7Y = 480,
    free8X = 1040,
    free8Y = 540,
    free9X = 1040,
    free9Y = 600,
    free10X = 1040,
    free10Y = 660,
    trackerPositions = {},
    groupTrackerPositions = {},
    statsTrackerX = 900,
    statsTrackerY = 420,
    targetStatsTrackerX = 900,
    targetStatsTrackerY = 530,
    playerOrder = "major_slayer,major_courage,major_force,major_berserk,major_brutality,major_savagery,major_resolve,major_heroism,major_expedition",
    bossOrder = "major_vulnerability,major_breach,major_brittle,major_cowardice,major_maim,off_balance",
    effectSettings = {},
    panelSettings = {},
    modules = {
        MajorEffects = {
            enabled = true,
            trackPlayerBuffs = true,
            trackBossDebuffs = true,
        },
        CombatStats = {
            enabled = true,
            targetEnabled = true,
            unlocked = true,
            displayMode = "bars",
            showLabels = true,
            penetrationMin = 0,
            penetrationMax = 18200,
            criticalMin = 0,
            criticalMax = 125,
            lastPenMin = 0,
            lastPenMax = 0,
            lastCritMin = 0,
            lastCritMax = 0,
            cellWidth = 116,
            cellHeight = 50,
            gap = 2,
            scale = 1.0,
            labelScale = 1.0,
            valueScale = 1.0,
            updateMs = 300,
            frameColor = { r = 0, g = 0, b = 0, a = 1 },
            cellColor = { r = 0.04, g = 0.04, b = 0.04, a = 1 },
            borderColor = { r = 0.86, g = 0.72, b = 0.32, a = 1 },
            labelColor = { r = 0.75, g = 0.75, b = 0.75, a = 1 },
            normalColor = { r = 0.35, g = 0.90, b = 0.45, a = 1 },
            lowColor = { r = 0.95, g = 0.30, b = 0.20, a = 1 },
            highColor = { r = 0.95, g = 0.72, b = 0.20, a = 1 },
            penBarColor = { r = 0.00, g = 1.00, b = 0.18, a = 1 },
            critBarColor = { r = 1, g = 0.48, b = 0.12, a = 1 },
            capMarkerColor = { r = 0, g = 0, b = 0, a = 1 },
            frameAlpha = 0.82,
            cellAlpha = 0.92,
            borderAlpha = 0.95,
            textAlpha = 1.0,
            borderEnabled = true,
            borderThickness = 2,
        },
    },
}

-- Ces données constituent le profil de trackers propre à chaque personnage.
-- Les réglages généraux (langue, icône, apparence globale, modules) restent
-- conservés au niveau du compte.
TSB.characterDefaults = {
    profileInitialized = false,
    effectSettings = {},
    panelSettings = {},
    playerOrder = TSB.defaults.playerOrder,
    bossOrder = TSB.defaults.bossOrder,
    trackerPositions = {},
    groupTrackerPositions = {},
    panels = {},
}

local TRACKER_DESTINATIONS = {
    "panel1", "panel2", "panel3", "panel4",
    "free1", "free2", "free3", "free4", "free5",
    "free6", "free7", "free8", "free9", "free10", "head", "group",
}

local function DestinationSettings(key)
    if type(key) == "table" then return key end
    if TSB.GetEffectSettings then return TSB.GetEffectSettings(key) end
    return nil
end

local function EnsureDestinations(key)
    local settings = DestinationSettings(key)
    if not settings then return nil end
    settings.destinations = settings.destinations or {}
    if settings.destination and settings.destinations[settings.destination] == nil then
        settings.destinations[settings.destination] = settings.enabled ~= false
    end
    return settings
end

function TSB.GetTrackerDestinations(key, includeDisabled)
    local settings = EnsureDestinations(key)
    local result = {}
    if not settings then return result end
    for _, destination in ipairs(TRACKER_DESTINATIONS) do
        local state = settings.destinations[destination]
        if state ~= nil and (includeDisabled or state == true) then result[#result + 1] = destination end
    end
    return result
end

function TSB.IsTrackerDestinationConfigured(key, destination)
    local settings = EnsureDestinations(key)
    return settings and settings.destinations[destination] ~= nil or false
end

function TSB.IsTrackerDestinationEnabled(key, destination)
    local settings = EnsureDestinations(key)
    if not settings or settings.destinations[destination] ~= true then return false end
    local panel = destination and destination:match("^panel[1-4]$")
    local panelSettings = panel and TSB.savedVars and TSB.savedVars.panelSettings and TSB.savedVars.panelSettings[panel]
    return not panelSettings or panelSettings.enabled ~= false
end

function TSB.AnyTrackerDestinationConfigured(key)
    return #TSB.GetTrackerDestinations(key, true) > 0
end

function TSB.AnyTrackerDestinationEnabled(key)
    for _, destination in ipairs(TSB.GetTrackerDestinations(key, false)) do
        if TSB.IsTrackerDestinationEnabled(key, destination) then return true end
    end
    return false
end

function TSB.AddTrackerDestination(key, destination)
    local settings = EnsureDestinations(key)
    if not settings or not destination then return false end
    settings.destinations[destination] = true
    settings.destination = destination
    settings.enabled = true
    return true
end

function TSB.SetTrackerDestinationEnabled(key, destination, enabled)
    local settings = EnsureDestinations(key)
    if not settings or settings.destinations[destination] == nil then return false end
    settings.destinations[destination] = enabled == true
    settings.enabled = true
    return true
end

function TSB.MoveTrackerDestination(key, fromDestination, toDestination)
    local settings = EnsureDestinations(key)
    if not settings or not fromDestination or not toDestination then return false end
    local wasEnabled = settings.destinations[fromDestination] ~= false
    settings.destinations[fromDestination] = nil
    settings.destinations[toDestination] = wasEnabled
    settings.destination = toDestination
    settings.enabled = true
    return true
end

function TSB.RemoveTrackerDestination(key, destination)
    local settings = EnsureDestinations(key)
    if not settings or not destination then return false end
    settings.destinations[destination] = nil
    if settings.destination == destination then
        settings.destination = nil
        settings.destination = TSB.GetTrackerDestinations(settings, true)[1]
    end
    if not TSB.AnyTrackerDestinationConfigured(settings) then settings.enabled = false end
    return true
end
