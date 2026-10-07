local ADDON_NAME = "Leo_sust_beta"
local SAVED_VARS_NAME = "Leo_sust_beta_SavedVariables"
local TIMER_UPDATE_NAME = ADDON_NAME .. "_TimerUpdate"

local DEFAULT_TICK_INTERVAL_MS = 2000
local MIN_TICK_INTERVAL_MS = 1400
local MAX_TICK_INTERVAL_MS = 2600
local TICK_TOLERANCE_MS = 450
local INTERVAL_ADAPT_TOLERANCE_MS = 200
local PASSIVE_REGEN_TOLERANCE = 10
local TIMER_INTERVAL_MS = 50
local MIN_WIDTH = 160
local MAX_WIDTH = 900
local MIN_HEIGHT = 4
local MAX_HEIGHT = 40

-- ESO exposes the constants on supported clients. The fallback keeps the
-- addon from crashing if the constant is unavailable during a UI reload.
local MAGICKA_POWER_TYPE = POWERTYPE_MAGICKA or 1

local DEFAULTS = {
    x = 300,
    y = 500,
    scale = 1.0,
    width = 360,
    height = 16,
    panelAlpha = 0.85,
    fillAlpha = 1.0,
    showOnlyInCombat = false,
}

local panel
local background
local fill
local savedVars
local settingsPanel
local consoleSettings
local settingsRegistered = false
local settingsCallbacksRegistered = false
local consoleSceneCallbackRegistered = false
local sceneManagerCallbackRegistered = false
local settingsMenuOpen = false
local gameMenuOpen = false
local timerUpdateRegistered = false
local ApplyPanelSettings

local state = {
    lastPower = nil,
    lastPowerMax = nil,
    lastPowerAt = nil,
    lastDelta = nil,
    lastNaturalTickAt = nil,
    tickIntervalMs = DEFAULT_TICK_INTERVAL_MS,
    displayIntervalMs = DEFAULT_TICK_INTERVAL_MS,
    confidence = 0,
    recentGains = {},
    latencyAtLastNatural = nil,
    lastLatency = nil,
    lastExpectedRecovery = nil,
    lastClassification = "not_initialized",
}

local function AddChatLine(text)
    if CHAT_SYSTEM then
        CHAT_SYSTEM:AddMessage("[Leo Sust Beta] " .. tostring(text))
    end
end

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function Now()
    if GetGameTimeMilliseconds then
        return GetGameTimeMilliseconds()
    end

    return GetFrameTimeMilliseconds()
end

local function GetCurrentLatency()
    if not GetLatency then
        return 0
    end

    return tonumber(GetLatency()) or 0
end

local function GetExpectedMagickaRecovery()
    if not GetPlayerStat then
        return nil
    end

    local inCombat = IsUnitInCombat and IsUnitInCombat("player") or false
    local statType
    if inCombat then
        statType = STAT_MAGICKA_REGEN_COMBAT or STAT_MAGICKA_REGEN_IDLE
    else
        statType = STAT_MAGICKA_REGEN_IDLE or STAT_MAGICKA_REGEN_COMBAT
    end

    if not statType then
        return nil
    end

    local recovery = GetPlayerStat(statType)
    return tonumber(recovery)
end

local function ReadMagickaState()
    if not GetUnitPower then
        return nil, nil
    end

    -- Capture both returns before converting. Passing GetUnitPower directly
    -- to tonumber would treat the maximum value as tonumber's base argument.
    local currentPower, powerMax = GetUnitPower("player", MAGICKA_POWER_TYPE)
    return tonumber(currentPower), tonumber(powerMax)
end

local function ResetSynchronization(keepPower)
    state.lastNaturalTickAt = nil
    state.tickIntervalMs = DEFAULT_TICK_INTERVAL_MS
    state.displayIntervalMs = DEFAULT_TICK_INTERVAL_MS
    state.confidence = 0
    state.recentGains = {}
    state.latencyAtLastNatural = nil
    state.lastLatency = nil
    state.lastExpectedRecovery = nil
    state.lastClassification = "reset"

    if not keepPower then
        state.lastPower, state.lastPowerMax = ReadMagickaState()
        state.lastPowerAt = Now()
    end

    if savedVars then
        ApplyPanelSettings()
    end
end

local function IsPlausibleInterval(intervalMs)
    return intervalMs >= MIN_TICK_INTERVAL_MS and intervalMs <= MAX_TICK_INTERVAL_MS
end

local function AddRecentGain(timestamp, amount, latency)
    local gains = state.recentGains
    gains[#gains + 1] = { at = timestamp, amount = amount, latency = latency }
    while #gains > 8 do
        table.remove(gains, 1)
    end
end

local function SetNaturalTick(timestamp, measuredInterval, confidence, latency)
    if measuredInterval
        and IsPlausibleInterval(measuredInterval)
        and math.abs(measuredInterval - state.tickIntervalMs) <= INTERVAL_ADAPT_TOLERANCE_MS then
        state.tickIntervalMs = Clamp(
            state.tickIntervalMs * 0.8 + measuredInterval * 0.2,
            MIN_TICK_INTERVAL_MS,
            MAX_TICK_INTERVAL_MS
        )
    end

    state.lastNaturalTickAt = timestamp
    state.latencyAtLastNatural = latency
    -- Keep the visual duration equal to the measured passive-tick interval.
    -- Latency is used only to validate event timing; subtracting it here
    -- would make the bar finish before the resource actually recovers.
    state.displayIntervalMs = state.tickIntervalMs
    state.confidence = math.max(state.confidence, confidence or 1)
    state.lastClassification = "natural"
end

local function GetLatencyCorrectedInterval(first, second)
    local observedInterval = second.at - first.at
    local latencyDelta = ((second.latency or 0) - (first.latency or 0)) / 2
    return observedInterval - latencyDelta
end

local function TryLearnNaturalTick(timestamp, latency)
    local gains = state.recentGains

    -- Once the phase is known, require both the passive regen amount and the
    -- expected phase. This prevents sustain abilities from re-anchoring the
    -- timer when their restore happens near a natural tick.
    if state.lastNaturalTickAt then
        local previousLatency = state.latencyAtLastNatural or latency
        local latencyDelta = (latency - previousLatency) / 2
        local observedElapsed = timestamp - state.lastNaturalTickAt
        local serverElapsed = observedElapsed - latencyDelta
        local periods = math.max(1, math.floor(serverElapsed / state.tickIntervalMs + 0.5))
        local expectedServerElapsed = periods * state.tickIntervalMs

        local earlyBy = expectedServerElapsed - serverElapsed
        local allowedEarly = math.max(0, ((previousLatency - latency) / 2) + 10)

        -- A passive tick may arrive late, but it should not be accepted
        -- hundreds of milliseconds early. Only allow early arrival explained
        -- by the latency change between the two observations.
        if earlyBy < allowedEarly then
            local measuredInterval
            if math.abs(serverElapsed - expectedServerElapsed) <= INTERVAL_ADAPT_TOLERANCE_MS then
                measuredInterval = serverElapsed / periods
            end

            -- The event timestamp is the moment the client actually observes
            -- the resource change. Start the next visual cycle here instead
            -- of anchoring it at a rounded future timestamp.
            SetNaturalTick(timestamp, measuredInterval, math.min(3, state.confidence + 1), latency)
            return true
        end

        state.lastClassification = "external_or_off_phase"
        return false
    end

    -- Before locking the phase, require two consecutive plausible intervals.
    -- This prevents a one-second resource effect from becoming the timer.
    if #gains >= 3 then
        local third = gains[#gains].at
        local firstInterval = GetLatencyCorrectedInterval(gains[#gains - 2], gains[#gains - 1])
        local secondInterval = GetLatencyCorrectedInterval(gains[#gains - 1], gains[#gains])

        if IsPlausibleInterval(firstInterval)
            and IsPlausibleInterval(secondInterval)
            and math.abs(firstInterval - state.tickIntervalMs) <= INTERVAL_ADAPT_TOLERANCE_MS
            and math.abs(secondInterval - state.tickIntervalMs) <= INTERVAL_ADAPT_TOLERANCE_MS
            and math.abs(firstInterval - secondInterval) <= TICK_TOLERANCE_MS then
            SetNaturalTick(third, (firstInterval + secondInterval) / 2, 2, latency)
            return true
        end
    end

    state.lastClassification = "candidate_or_external"
    return false
end

local function GetProgress(timestamp)
    if not state.lastNaturalTickAt or state.displayIntervalMs <= 0 then
        return 0
    end

    local elapsed = math.max(0, timestamp - state.lastNaturalTickAt)
    -- Keep predicting the shared cycle between confirmed ticks. A confirmed
    -- passive event will correct the phase, while the prediction prevents the
    -- bar from freezing at 100% if the next power update is delayed or merged
    -- with another resource change.
    local remainder = elapsed % state.displayIntervalMs
    return Clamp(remainder / state.displayIntervalMs, 0, 1)
end

local function IsPanelAllowedByVisibility()
    if settingsMenuOpen then
        return true
    end

    if gameMenuOpen then
        return false
    end

    if not savedVars.showOnlyInCombat then
        return true
    end

    return IsUnitInCombat == nil or IsUnitInCombat("player")
end

local function SetBackdropColors()
    if background then
        background:SetCenterColor(0.03, 0.03, 0.03, 1)
        background:SetEdgeColor(0.25, 0.25, 0.25, 1)
        background:SetEdgeTexture("", 1, 1, 0, 0)
    end

    if fill then
        fill:SetCenterColor(0.25, 0.75, 1.0, 1)
        fill:SetEdgeColor(0.25, 0.75, 1.0, 1)
        fill:SetEdgeTexture("", 1, 1, 0, 0)
    end
end

local function Render()
    if not panel or not savedVars then
        return
    end

    local width = Clamp(tonumber(savedVars.width) or DEFAULTS.width, MIN_WIDTH, MAX_WIDTH)
    local height = Clamp(tonumber(savedVars.height) or DEFAULTS.height, MIN_HEIGHT, MAX_HEIGHT)
    local progress = GetProgress(Now())

    panel:SetDimensions(width, height)
    if background then
        background:SetDimensions(width, height)
        background:SetAlpha(savedVars.panelAlpha)
    end
    if fill then
        fill:SetDimensions(math.max(1, width * progress), height)
        fill:SetAlpha(savedVars.fillAlpha)
    end

    panel:SetHidden(not IsPanelAllowedByVisibility())
end

local function StopTimerUpdates()
    if timerUpdateRegistered then
        EVENT_MANAGER:UnregisterForUpdate(TIMER_UPDATE_NAME)
        timerUpdateRegistered = false
    end
end

local function TimerUpdate()
    Render()
end

local function StartTimerUpdates()
    if timerUpdateRegistered then
        return
    end

    EVENT_MANAGER:RegisterForUpdate(TIMER_UPDATE_NAME, TIMER_INTERVAL_MS, TimerUpdate)
    timerUpdateRegistered = true
end

ApplyPanelSettings = function()
    if not panel or not savedVars then
        return
    end

    panel:ClearAnchors()
    panel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, savedVars.x, savedVars.y)
    panel:SetScale(savedVars.scale)
    Render()
    if state.lastNaturalTickAt then
        StartTimerUpdates()
    else
        StopTimerUpdates()
    end
end

local function OnLAMPanelOpened(selectedPanel)
    if selectedPanel == settingsPanel then
        settingsMenuOpen = true
        ApplyPanelSettings()
    end
end

local function OnLAMPanelClosed(selectedPanel)
    if selectedPanel == settingsPanel then
        settingsMenuOpen = false
        ApplyPanelSettings()
    end
end

local function OnConsoleSettingsSceneStateChange(newState)
    if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
        if consoleSettings and consoleSettings.selected then
            settingsMenuOpen = true
            ApplyPanelSettings()
        end
    elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
        settingsMenuOpen = false
        ApplyPanelSettings()
    end
end

local function GetCurrentSceneName()
    if not SCENE_MANAGER or not SCENE_MANAGER.GetCurrentScene then
        return nil
    end

    local currentScene = SCENE_MANAGER:GetCurrentScene()
    if currentScene and currentScene.GetName then
        return currentScene:GetName()
    end

    return nil
end

local function IsHudSceneName(sceneName)
    return sceneName == "hud" or sceneName == "hudui"
end

local function SyncGameMenuState()
    local currentSceneName = GetCurrentSceneName()
    if currentSceneName then
        gameMenuOpen = not IsHudSceneName(currentSceneName)
    end
end

local function OnSceneStateChanged(scene, _, newState)
    local sceneName = scene and scene.GetName and scene:GetName() or nil
    if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
        -- Any non-HUD scene is a menu or modal interface. The own settings
        -- callback can override this through settingsMenuOpen.
        if sceneName and not IsHudSceneName(sceneName) then
            gameMenuOpen = true
        end
    elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
        SyncGameMenuState()
    end

    Render()
end

local function RegisterSceneManagerCallback()
    if sceneManagerCallbackRegistered or not SCENE_MANAGER or not SCENE_MANAGER.RegisterCallback then
        return
    end

    SCENE_MANAGER:RegisterCallback("SceneStateChanged", OnSceneStateChanged)
    sceneManagerCallbackRegistered = true
    SyncGameMenuState()
end

local function RegisterConsoleSettingsSceneCallback()
    if consoleSceneCallbackRegistered or not LibHarvensAddonSettings then
        return
    end

    local settingsScene = LibHarvensAddonSettings.scene
    if settingsScene and settingsScene.RegisterCallback then
        settingsScene:RegisterCallback("StateChange", OnConsoleSettingsSceneStateChange)
        consoleSceneCallbackRegistered = true
    end
end

local function OnConsoleAddonSelected(_, addonSettings)
    RegisterConsoleSettingsSceneCallback()

    local isOurSettings = addonSettings == consoleSettings
    if not isOurSettings and not consoleSettings and addonSettings then
        isOurSettings = addonSettings.name == "Leo Sust Beta"
        if isOurSettings then
            consoleSettings = addonSettings
        end
    end

    settingsMenuOpen = isOurSettings
    ApplyPanelSettings()
end

local function RegisterSettingsCallbacks()
    if settingsCallbacksRegistered or not CALLBACK_MANAGER then
        return
    end

    CALLBACK_MANAGER:RegisterCallback("LAM-PanelOpened", OnLAMPanelOpened)
    CALLBACK_MANAGER:RegisterCallback("LAM-PanelClosed", OnLAMPanelClosed)
    CALLBACK_MANAGER:RegisterCallback("LibHarvensAddonSettings_AddonSelected", OnConsoleAddonSelected)
    settingsCallbacksRegistered = true
end

local function RefreshSettingsDisplay()
    if CALLBACK_MANAGER and settingsPanel then
        CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", settingsPanel)
    end

    if LibAddonMenu2
        and IsKeyboardUISupported
        and not IsKeyboardUISupported()
        and LibAddonMenu2.LHASConversion
        and LibAddonMenu2.LHASConversion.settingTables then
        local converted = LibAddonMenu2.LHASConversion.settingTables[ADDON_NAME .. "_Settings"]
        if converted and converted.RefreshSettings then
            converted:RefreshSettings()
        end
    end
end

local function BuildSettingsOptions()
    return {
        {
            type = "description",
            text = "Visualizes the shared magicka recovery phase. It does not reset from every magicka gain; one-second sustain effects are ignored after synchronization.",
        },
        {
            type = "slider",
            name = "Position X",
            min = -3000,
            max = 3000,
            step = 1,
            decimals = 0,
            getFunc = function() return savedVars.x end,
            setFunc = function(value)
                savedVars.x = math.floor(tonumber(value) or DEFAULTS.x)
                ApplyPanelSettings()
            end,
            default = DEFAULTS.x,
        },
        {
            type = "slider",
            name = "Position Y",
            min = -2000,
            max = 2000,
            step = 1,
            decimals = 0,
            getFunc = function() return savedVars.y end,
            setFunc = function(value)
                savedVars.y = math.floor(tonumber(value) or DEFAULTS.y)
                ApplyPanelSettings()
            end,
            default = DEFAULTS.y,
        },
        {
            type = "slider",
            name = "Scale",
            min = 0.5,
            max = 2.0,
            step = 0.05,
            decimals = 2,
            getFunc = function() return savedVars.scale end,
            setFunc = function(value)
                savedVars.scale = Clamp(tonumber(value) or DEFAULTS.scale, 0.5, 2.0)
                ApplyPanelSettings()
            end,
            default = DEFAULTS.scale,
        },
        {
            type = "slider",
            name = "Line width",
            min = MIN_WIDTH,
            max = MAX_WIDTH,
            step = 10,
            decimals = 0,
            getFunc = function() return savedVars.width end,
            setFunc = function(value)
                savedVars.width = Clamp(math.floor(tonumber(value) or DEFAULTS.width), MIN_WIDTH, MAX_WIDTH)
                Render()
            end,
            default = DEFAULTS.width,
        },
        {
            type = "slider",
            name = "Line height",
            min = MIN_HEIGHT,
            max = MAX_HEIGHT,
            step = 1,
            decimals = 0,
            getFunc = function() return savedVars.height end,
            setFunc = function(value)
                savedVars.height = Clamp(math.floor(tonumber(value) or DEFAULTS.height), MIN_HEIGHT, MAX_HEIGHT)
                Render()
            end,
            default = DEFAULTS.height,
        },
        {
            type = "slider",
            name = "Panel opacity",
            min = 0.1,
            max = 1.0,
            step = 0.05,
            decimals = 2,
            getFunc = function() return savedVars.panelAlpha end,
            setFunc = function(value)
                savedVars.panelAlpha = Clamp(tonumber(value) or DEFAULTS.panelAlpha, 0.1, 1.0)
                Render()
            end,
            default = DEFAULTS.panelAlpha,
        },
        {
            type = "slider",
            name = "Fill opacity",
            min = 0.1,
            max = 1.0,
            step = 0.05,
            decimals = 2,
            getFunc = function() return savedVars.fillAlpha end,
            setFunc = function(value)
                savedVars.fillAlpha = Clamp(tonumber(value) or DEFAULTS.fillAlpha, 0.1, 1.0)
                Render()
            end,
            default = DEFAULTS.fillAlpha,
        },
        {
            type = "checkbox",
            name = "Show only in combat",
            getFunc = function() return savedVars.showOnlyInCombat end,
            setFunc = function(value)
                savedVars.showOnlyInCombat = value == true
                Render()
            end,
            default = DEFAULTS.showOnlyInCombat,
        },
        {
            type = "button",
            name = "Reset synchronization",
            func = function()
                ResetSynchronization(false)
                RefreshSettingsDisplay()
            end,
            width = "full",
        },
        {
            type = "description",
            text = "Use /leosust to inspect synchronization and detected resource changes.",
        },
    }
end

local function InitializeSettings()
    if not LibAddonMenu2 then
        return
    end

    local registered, result = pcall(function()
        return LibAddonMenu2:RegisterAddonPanel(ADDON_NAME .. "_Settings", {
            type = "panel",
            name = "Leo Sust Beta",
            displayName = "Leo Sust Beta",
            author = "Leo_Kujo",
            version = "0.1.7",
            registerForRefresh = true,
            registerForDefaults = true,
        })
    end)

    if not registered then
        AddChatLine("settings panel registration failed: " .. tostring(result))
        return
    end

    settingsPanel = result
    local options = BuildSettingsOptions()
    local optionsRegistered, optionsError = pcall(function()
        LibAddonMenu2:RegisterOptionControls(ADDON_NAME .. "_Settings", options)
    end)
    if optionsRegistered then
        settingsRegistered = true
    else
        AddChatLine("settings option registration failed: " .. tostring(optionsError))
    end

    if LibAddonMenu2.LHASConversion and LibAddonMenu2.LHASConversion.settingTables then
        consoleSettings = LibAddonMenu2.LHASConversion.settingTables[ADDON_NAME .. "_Settings"]
    end

    RegisterSettingsCallbacks()
end

local function PrintDiagnostics(command)
    local text = tostring(command or ""):lower():match("^%s*(.-)%s*$")
    if text == "reset" then
        ResetSynchronization(false)
        AddChatLine("synchronization reset")
        return
    end

    local now = Now()
    local progress = GetProgress(now)
    AddChatLine(string.format(
        "Lua=LOADED | HUD=%s | Settings=%s | magicka=%s | max=%s | delta=%s | passive=%s | latency=%dms | interval=%.0fms | display=%.0fms | confidence=%d | progress=%.2f | last=%s",
        panel and "OK" or "NOT_INITIALIZED",
        settingsRegistered and "OK" or "NOT_REGISTERED",
        tostring(state.lastPower),
        tostring(state.lastPowerMax),
        tostring(state.lastDelta),
        tostring(state.lastExpectedRecovery),
        state.lastLatency or 0,
        state.tickIntervalMs,
        state.displayIntervalMs,
        state.confidence,
        progress,
        state.lastClassification
    ))
end

SLASH_COMMANDS["/leosust"] = PrintDiagnostics

local function MatchesPassiveRecovery(amount, expectedRecovery, previousPower, currentPower, powerMax)
    if not expectedRecovery or expectedRecovery <= 0 then
        return false
    end

    local expectedGain = expectedRecovery

    -- The final natural tick can be smaller than the recovery stat when the
    -- resource reaches its maximum. Treat that capped remainder as passive
    -- instead of losing synchronization at the cap.
    if powerMax
        and previousPower
        and currentPower
        and currentPower >= powerMax
        and previousPower < powerMax then
        local remainingToCap = powerMax - previousPower
        if remainingToCap > 0 then
            expectedGain = math.min(expectedGain, remainingToCap)
        end
    end

    return expectedGain > 0 and math.abs(amount - expectedGain) <= PASSIVE_REGEN_TOLERANCE
end

local function OnPowerUpdate(_, unitTag, _, powerType, power, powerMax)
    if unitTag ~= "player" or powerType ~= MAGICKA_POWER_TYPE then
        return
    end

    local currentPower = tonumber(power)
    local currentPowerMax = tonumber(powerMax)
    if not currentPower then
        currentPower, currentPowerMax = ReadMagickaState()
    elseif not currentPowerMax then
        local _, readPowerMax = ReadMagickaState()
        currentPowerMax = readPowerMax
    end
    if not currentPower then
        return
    end

    local timestamp = Now()
    local latency = GetCurrentLatency()
    local expectedRecovery = GetExpectedMagickaRecovery()
    state.lastLatency = latency
    state.lastExpectedRecovery = expectedRecovery
    if currentPowerMax then
        state.lastPowerMax = currentPowerMax
    end
    if state.lastPower ~= nil then
        local delta = currentPower - state.lastPower
        state.lastDelta = delta
        if delta > 0 then
            if MatchesPassiveRecovery(delta, expectedRecovery, state.lastPower, currentPower, currentPowerMax or state.lastPowerMax) then
                AddRecentGain(timestamp, delta, latency)
                if TryLearnNaturalTick(timestamp, latency) then
                    StartTimerUpdates()
                end
            elseif expectedRecovery then
                state.lastClassification = "external_restore"
            else
                state.lastClassification = "regen_stat_unavailable"
            end
        elseif delta < 0 then
            state.lastClassification = "resource_spent"
        end
    end

    state.lastPower = currentPower
    state.lastPowerAt = timestamp
    Render()
end

local function OnPlayerActivated()
    state.lastPower, state.lastPowerMax = ReadMagickaState()
    state.lastPowerAt = Now()
    state.lastDelta = nil
    state.lastNaturalTickAt = nil
    state.tickIntervalMs = DEFAULT_TICK_INTERVAL_MS
    state.displayIntervalMs = DEFAULT_TICK_INTERVAL_MS
    state.confidence = 0
    state.recentGains = {}
    state.latencyAtLastNatural = nil
    state.lastLatency = GetCurrentLatency()
    state.lastExpectedRecovery = GetExpectedMagickaRecovery()
    state.lastClassification = "waiting_for_natural_ticks"
    ApplyPanelSettings()
end

local function OnCombatStateChanged()
    Render()
end

local function NormalizeSavedVars()
    savedVars.x = tonumber(savedVars.x) or DEFAULTS.x
    savedVars.y = tonumber(savedVars.y) or DEFAULTS.y
    savedVars.scale = Clamp(tonumber(savedVars.scale) or DEFAULTS.scale, 0.5, 2.0)
    savedVars.width = Clamp(math.floor(tonumber(savedVars.width) or DEFAULTS.width), MIN_WIDTH, MAX_WIDTH)
    savedVars.height = Clamp(math.floor(tonumber(savedVars.height) or DEFAULTS.height), MIN_HEIGHT, MAX_HEIGHT)
    savedVars.panelAlpha = Clamp(tonumber(savedVars.panelAlpha) or DEFAULTS.panelAlpha, 0.1, 1.0)
    savedVars.fillAlpha = Clamp(tonumber(savedVars.fillAlpha) or DEFAULTS.fillAlpha, 0.1, 1.0)
    savedVars.showOnlyInCombat = savedVars.showOnlyInCombat == true
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    panel = Leo_sust_beta
    if not panel then
        AddChatLine("HUD root control Leo_sust_beta was not created from XML")
        return
    end

    background = panel:GetNamedChild("Background")
    fill = panel:GetNamedChild("Fill")
    if not background or not fill then
        AddChatLine("HUD background or fill control was not found")
        return
    end

    savedVars = ZO_SavedVars:NewAccountWide(SAVED_VARS_NAME, 1, nil, DEFAULTS)
    NormalizeSavedVars()
    SetBackdropColors()
    ApplyPanelSettings()
    RegisterSceneManagerCallback()
    InitializeSettings()

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_POWER_UPDATE, OnPowerUpdate)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_COMBAT_STATE, OnCombatStateChanged)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
