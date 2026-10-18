local ADDON_NAME = "Leo_stats_panel"
local SAVED_VARS_NAME = "Leo_stats_panel_SavedVariables"
local UPDATE_NAME = ADDON_NAME .. "_Update"

local VERSION = "0.2.3"
local UPDATE_INTERVAL_MS = 500
local MIN_SCALE = 0.5
local MAX_SCALE = 2.0
local MIN_TEXT_SIZE = 10
local MAX_TEXT_SIZE = 32
local MIN_SIDE_PADDING = 0
local MAX_SIDE_PADDING = 32
local MIN_ALPHA = 0.1
local MAX_ALPHA = 1.0
local MIN_POSITION_X = -3000
local MAX_POSITION_X = 3000
local MIN_POSITION_Y = -2000
local MAX_POSITION_Y = 2000

local FONT_STYLES = {
    gamepadBold = {
        label = "Gamepad Bold",
        face = "$(GAMEPAD_BOLD_FONT)",
        fallback = "ZoFontGamepadBold18",
    },
    gamepad = {
        label = "Gamepad Normal",
        face = "$(GAMEPAD_FONT)",
        fallback = "ZoFontGamepad18",
    },
    standardBold = {
        label = "Standard Bold",
        face = "$(BOLD_FONT)",
        fallback = "ZoFontGameBold",
    },
    standard = {
        label = "Standard Normal",
        face = "$(MEDIUM_FONT)",
        fallback = "ZoFontGame",
    },
}
local FONT_STYLE_KEYS = { "gamepadBold", "gamepad", "standardBold", "standard" }
local fontCache = {}

local BLOCK_DEFINITIONS = {
    { id = "wpd", label = "WPD", defaultX = 300, defaultY = 120 },
    { id = "arm", label = "ARM", defaultX = 300, defaultY = 180 },
    { id = "mreg", label = "MREG", defaultX = 300, defaultY = 240 },
    { id = "sreg", label = "SREG", defaultX = 300, defaultY = 300 },
    { id = "crit", label = "CRIT", defaultX = 500, defaultY = 120 },
    { id = "pen", label = "PEN", defaultX = 500, defaultY = 180 },
}

local DEFAULTS = {
    panelAlpha = 0.88,
    fontStyle = "gamepadBold",
    showOnlyInCombat = false,
    blocks = {},
}

for _, definition in ipairs(BLOCK_DEFINITIONS) do
    DEFAULTS.blocks[definition.id] = {
        enabled = true,
        x = definition.defaultX,
        y = definition.defaultY,
        scale = 1.0,
        textSize = 18,
        sidePadding = 8,
    }
end

local panelControls = {}
local appliedStyles = {}
local lastRenderedText = {}
local lastHiddenState = {}
local savedVars
local settingsPanel
local consoleSettings
local settingsRegistered = false
local settingsCallbacksRegistered = false
local consoleSceneCallbackRegistered = false
local sceneManagerCallbackRegistered = false
local settingsMenuOpen = false
local gameMenuOpen = false
local updateRegistered = false

local state = {
    inCombat = false,
    wpd = nil,
    spellResist = nil,
    physicalResist = nil,
    magickaRecovery = nil,
    staminaRecovery = nil,
    critical = nil,
    spellPenetration = nil,
    physicalPenetration = nil,
}

local function AddChatLine(text)
    local message = "[Leo Stats Panel] " .. tostring(text)
    if type(d) == "function" then
        d(message)
    elseif CHAT_SYSTEM and type(CHAT_SYSTEM.AddMessage) == "function" then
        CHAT_SYSTEM:AddMessage(message)
    end
end

local function Clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function IsFontStyleValid(value)
    return type(value) == "string" and FONT_STYLES[value] ~= nil
end

local function GetFontName(config)
    local style = IsFontStyleValid(savedVars.fontStyle) and savedVars.fontStyle or DEFAULTS.fontStyle
    local fontStyle = FONT_STYLES[style]
    local textSize = Clamp(tonumber(config and config.textSize) or 18, MIN_TEXT_SIZE, MAX_TEXT_SIZE)
    local cacheKey = style .. ":" .. tostring(textSize)
    if fontCache[cacheKey] then
        return fontCache[cacheKey]
    end

    if type(ZO_CreateFontString) == "function" then
        local outlineStyle = FONT_STYLE_OUTLINE_THICK or FONT_STYLE_SOFT_SHADOW_THICK or FONT_STYLE_NORMAL or 0
        local created, dynamicFont = pcall(ZO_CreateFontString, fontStyle.face, textSize, outlineStyle)
        if created and type(dynamicFont) == "string" and dynamicFont ~= "" then
            fontCache[cacheKey] = dynamicFont
            return dynamicFont
        end
    end

    fontCache[cacheKey] = fontStyle.fallback
    return fontStyle.fallback
end

local function GetBlockDefaults(definition)
    return DEFAULTS.blocks[definition.id]
end

local function GetBlockConfig(definition)
    return savedVars.blocks[definition.id]
end

local function IsBlockEnabled(blockId)
    return savedVars
        and savedVars.blocks
        and savedVars.blocks[blockId]
        and savedVars.blocks[blockId].enabled == true
end

local function IsCombat()
    return type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true
end

local function CanDisplayStats()
    if settingsMenuOpen then
        return true
    end

    if gameMenuOpen then
        return false
    end

    return not savedVars.showOnlyInCombat or IsCombat()
end

local function ReadPlayerStat(statType)
    if type(GetPlayerStat) ~= "function" or statType == nil then
        return nil
    end

    local value
    if STAT_BONUS_OPTION_APPLY_BONUS ~= nil and STAT_SOFT_CAP_OPTION_APPLY_SOFT_CAP ~= nil then
        value = GetPlayerStat(statType, STAT_BONUS_OPTION_APPLY_BONUS, STAT_SOFT_CAP_OPTION_APPLY_SOFT_CAP)
    else
        value = GetPlayerStat(statType)
    end

    value = tonumber(value)
    if not value then
        return nil
    end

    return math.max(0, math.floor(value + 0.5))
end

local function GetCombatRecoveryStat(statType)
    -- The character sheet displays combat recovery. Idle recovery is higher
    -- and is not the value the player sees in the character statistics UI.
    return ReadPlayerStat(statType)
end

local function ReadStats()
    state.inCombat = IsCombat()

    state.wpd = IsBlockEnabled("wpd") and ReadPlayerStat(STAT_POWER or STAT_WEAPON_POWER) or nil
    state.spellResist = IsBlockEnabled("arm") and ReadPlayerStat(STAT_SPELL_RESIST) or nil
    state.physicalResist = IsBlockEnabled("arm") and ReadPlayerStat(STAT_PHYSICAL_RESIST) or nil
    state.magickaRecovery = IsBlockEnabled("mreg") and GetCombatRecoveryStat(STAT_MAGICKA_REGEN_COMBAT) or nil
    state.staminaRecovery = IsBlockEnabled("sreg") and GetCombatRecoveryStat(STAT_STAMINA_REGEN_COMBAT) or nil
    state.critical = IsBlockEnabled("crit") and ReadPlayerStat(STAT_CRITICAL_STRIKE) or nil
    state.spellPenetration = IsBlockEnabled("pen") and ReadPlayerStat(STAT_SPELL_PENETRATION) or nil
    state.physicalPenetration = IsBlockEnabled("pen") and ReadPlayerStat(STAT_PHYSICAL_PENETRATION) or nil
end

local function FormatSingle(value, suffix)
    return string.format("%s %s", value and tostring(value) or "--", suffix)
end

local function FormatPair(first, second, suffix)
    return string.format(
        "%s/%s %s",
        first and tostring(first) or "--",
        second and tostring(second) or "--",
        suffix
    )
end

local function GetBlockText(blockId)
    if blockId == "wpd" then
        return FormatSingle(state.wpd, "WPD")
    elseif blockId == "arm" then
        return FormatPair(state.spellResist, state.physicalResist, "ARM")
    elseif blockId == "mreg" then
        return FormatSingle(state.magickaRecovery, "MREG")
    elseif blockId == "sreg" then
        return FormatSingle(state.staminaRecovery, "SREG")
    elseif blockId == "crit" then
        return FormatSingle(state.critical, "CRIT")
    elseif blockId == "pen" then
        return FormatPair(state.spellPenetration, state.physicalPenetration, "PEN")
    end

    return "--"
end

local function ApplyBlockStyle(definition, controls)
    local config = GetBlockConfig(definition)
    local font = GetFontName(config)
    local cachedStyle = appliedStyles[definition.id]
    if cachedStyle
        and cachedStyle.x == config.x
        and cachedStyle.y == config.y
        and cachedStyle.scale == config.scale
        and cachedStyle.textSize == config.textSize
        and cachedStyle.sidePadding == config.sidePadding
        and cachedStyle.panelAlpha == savedVars.panelAlpha
        and cachedStyle.font == font then
        return
    end

    controls.control:ClearAnchors()
    controls.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, config.x, config.y)
    controls.control:SetScale(config.scale)
    controls.background:SetAlpha(savedVars.panelAlpha)
    controls.text:ClearAnchors()
    controls.text:SetAnchor(TOPLEFT, controls.control, TOPLEFT, config.sidePadding, 0)
    controls.text:SetAnchor(BOTTOMRIGHT, controls.control, BOTTOMRIGHT, -config.sidePadding, 0)
    controls.text:SetFont(font)
    controls.text:SetColor(1, 1, 1, 1)
    controls.text:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    controls.text:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    controls.text:SetDrawLayer(DL_OVERLAY)
    controls.text:SetDrawTier(DT_HIGH)
    controls.text:SetDrawLevel(5)
    appliedStyles[definition.id] = {
        x = config.x,
        y = config.y,
        scale = config.scale,
        textSize = config.textSize,
        sidePadding = config.sidePadding,
        panelAlpha = savedVars.panelAlpha,
        font = font,
    }
end

local function IsHudSceneName(sceneName)
    return sceneName == "hud" or sceneName == "hudui"
end

local function IsBlockAllowedByVisibility(config)
    return config.enabled and CanDisplayStats()
end

local function RenderBlock(definition)
    local controls = panelControls[definition.id]
    if not controls then
        return
    end

    local config = GetBlockConfig(definition)
    if not config.enabled then
        lastRenderedText[definition.id] = nil
        if lastHiddenState[definition.id] ~= true then
            controls.control:SetHidden(true)
            lastHiddenState[definition.id] = true
        end
        return
    end

    local text = GetBlockText(definition.id)
    if lastRenderedText[definition.id] ~= text then
        controls.text:SetText(text)
        lastRenderedText[definition.id] = text
    end

    local hidden = not IsBlockAllowedByVisibility(config)
    if lastHiddenState[definition.id] ~= hidden then
        controls.control:SetHidden(hidden)
        lastHiddenState[definition.id] = hidden
    end

    ApplyBlockStyle(definition, controls)
end

local function RenderAll()
    for _, definition in ipairs(BLOCK_DEFINITIONS) do
        RenderBlock(definition)
    end
end

local function HasEnabledBlocks()
    for _, definition in ipairs(BLOCK_DEFINITIONS) do
        if savedVars.blocks[definition.id].enabled then
            return true
        end
    end

    return false
end

local function StopUpdates()
    if updateRegistered then
        EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
        updateRegistered = false
    end
end

local function StartUpdates()
    if updateRegistered or not HasEnabledBlocks() or not CanDisplayStats() then
        return
    end

    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, UPDATE_INTERVAL_MS, function()
        ReadStats()
        RenderAll()
    end)
    updateRegistered = true
end

local function SyncUpdates()
    if HasEnabledBlocks() and CanDisplayStats() then
        ReadStats()
        StartUpdates()
    else
        StopUpdates()
    end

    RenderAll()
end

local function ApplyAllBlockSettings()
    for _, definition in ipairs(BLOCK_DEFINITIONS) do
        local controls = panelControls[definition.id]
        if controls and GetBlockConfig(definition).enabled then
            ApplyBlockStyle(definition, controls)
        end
    end
    RenderAll()
end

local function OnCombatStateChanged(_, inCombat)
    if type(inCombat) == "boolean" then
        state.inCombat = inCombat
    else
        state.inCombat = IsCombat()
    end

    SyncUpdates()
end

local function OnPlayerActivated()
    ApplyAllBlockSettings()
    SyncUpdates()
end

local function RefreshSettingsDisplay()
    if CALLBACK_MANAGER and settingsPanel then
        CALLBACK_MANAGER:FireCallbacks("LAM-RefreshPanel", settingsPanel)
    end

    if LibAddonMenu2
        and type(IsKeyboardUISupported) == "function"
        and not IsKeyboardUISupported()
        and LibAddonMenu2.LHASConversion
        and LibAddonMenu2.LHASConversion.settingTables then
        local converted = LibAddonMenu2.LHASConversion.settingTables[ADDON_NAME .. "_Settings"]
        if converted and type(converted.RefreshSettings) == "function" then
            converted:RefreshSettings()
        end
    end
end

local function OnLAMPanelOpened(selectedPanel)
    if selectedPanel == settingsPanel then
        settingsMenuOpen = true
        ApplyAllBlockSettings()
        SyncUpdates()
    end
end

local function OnLAMPanelClosed(selectedPanel)
    if selectedPanel == settingsPanel then
        settingsMenuOpen = false
        ApplyAllBlockSettings()
        SyncUpdates()
    end
end

local function OnConsoleSettingsSceneStateChange(newState)
    if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
        if consoleSettings and consoleSettings.selected then
            settingsMenuOpen = true
            ApplyAllBlockSettings()
            SyncUpdates()
        end
    elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
        settingsMenuOpen = false
        ApplyAllBlockSettings()
        SyncUpdates()
    end
end

local function GetCurrentSceneName()
    if not SCENE_MANAGER or type(SCENE_MANAGER.GetCurrentScene) ~= "function" then
        return nil
    end

    local currentScene = SCENE_MANAGER:GetCurrentScene()
    if currentScene and type(currentScene.GetName) == "function" then
        return currentScene:GetName()
    end

    return nil
end

local function SyncGameMenuState()
    local currentSceneName = GetCurrentSceneName()
    if currentSceneName then
        gameMenuOpen = not IsHudSceneName(currentSceneName)
    end
end

local function OnSceneStateChanged(scene, _, newState)
    local sceneName = scene and type(scene.GetName) == "function" and scene:GetName() or nil
    if newState == SCENE_SHOWING or newState == SCENE_SHOWN then
        if sceneName then
            gameMenuOpen = not IsHudSceneName(sceneName)
        end
    elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
        SyncGameMenuState()
    end

    SyncUpdates()
end

local function RegisterSceneManagerCallback()
    if sceneManagerCallbackRegistered
        or not SCENE_MANAGER
        or type(SCENE_MANAGER.RegisterCallback) ~= "function" then
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
    if settingsScene and type(settingsScene.RegisterCallback) == "function" then
        settingsScene:RegisterCallback("StateChange", OnConsoleSettingsSceneStateChange)
        consoleSceneCallbackRegistered = true
    end
end

local function OnConsoleAddonSelected(_, addonSettings)
    RegisterConsoleSettingsSceneCallback()

    local isOurSettings = addonSettings == consoleSettings
    if not isOurSettings and not consoleSettings and addonSettings then
        isOurSettings = addonSettings.name == "Leo Stats Panel"
        if isOurSettings then
            consoleSettings = addonSettings
        end
    end

    settingsMenuOpen = isOurSettings
    ApplyAllBlockSettings()
    SyncUpdates()
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

local function ResetBlock(definition)
    local defaults = GetBlockDefaults(definition)
    savedVars.blocks[definition.id] = {
        enabled = defaults.enabled,
        x = defaults.x,
        y = defaults.y,
        scale = defaults.scale,
        textSize = defaults.textSize,
        sidePadding = defaults.sidePadding,
    }
end

local function ResetAllBlocks()
    for _, definition in ipairs(BLOCK_DEFINITIONS) do
        ResetBlock(definition)
    end
    ApplyAllBlockSettings()
    SyncUpdates()
    RefreshSettingsDisplay()
end

local function AppendBlockSettings(options, definition)
    options[#options + 1] = {
        type = "header",
        name = definition.label .. " block",
    }
    options[#options + 1] = {
        type = "checkbox",
        name = "Show " .. definition.label,
        getFunc = function() return GetBlockConfig(definition).enabled end,
        setFunc = function(value)
            GetBlockConfig(definition).enabled = value == true
            SyncUpdates()
        end,
        default = GetBlockDefaults(definition).enabled,
    }
    options[#options + 1] = {
        type = "slider",
        name = definition.label .. " Position X",
        min = MIN_POSITION_X,
        max = MAX_POSITION_X,
        step = 1,
        decimals = 0,
        getFunc = function() return GetBlockConfig(definition).x end,
        setFunc = function(value)
            GetBlockConfig(definition).x = math.floor(tonumber(value) or GetBlockDefaults(definition).x)
            ApplyAllBlockSettings()
        end,
        default = GetBlockDefaults(definition).x,
    }
    options[#options + 1] = {
        type = "slider",
        name = definition.label .. " Position Y",
        min = MIN_POSITION_Y,
        max = MAX_POSITION_Y,
        step = 1,
        decimals = 0,
        getFunc = function() return GetBlockConfig(definition).y end,
        setFunc = function(value)
            GetBlockConfig(definition).y = math.floor(tonumber(value) or GetBlockDefaults(definition).y)
            ApplyAllBlockSettings()
        end,
        default = GetBlockDefaults(definition).y,
    }
    options[#options + 1] = {
        type = "slider",
        name = definition.label .. " Scale",
        min = MIN_SCALE,
        max = MAX_SCALE,
        step = 0.05,
        decimals = 2,
        getFunc = function() return GetBlockConfig(definition).scale end,
        setFunc = function(value)
            GetBlockConfig(definition).scale = Clamp(tonumber(value) or GetBlockDefaults(definition).scale, MIN_SCALE, MAX_SCALE)
            ApplyAllBlockSettings()
        end,
        default = GetBlockDefaults(definition).scale,
    }
    options[#options + 1] = {
        type = "slider",
        name = definition.label .. " Text size",
        tooltip = "Changes the text size inside this block.",
        min = MIN_TEXT_SIZE,
        max = MAX_TEXT_SIZE,
        step = 1,
        decimals = 0,
        getFunc = function() return GetBlockConfig(definition).textSize end,
        setFunc = function(value)
            GetBlockConfig(definition).textSize = Clamp(math.floor(tonumber(value) or 18), MIN_TEXT_SIZE, MAX_TEXT_SIZE)
            ApplyAllBlockSettings()
        end,
        default = GetBlockDefaults(definition).textSize,
    }
    options[#options + 1] = {
        type = "slider",
        name = definition.label .. " Side padding",
        tooltip = "Changes the left and right text padding for this block.",
        min = MIN_SIDE_PADDING,
        max = MAX_SIDE_PADDING,
        step = 1,
        decimals = 0,
        getFunc = function() return GetBlockConfig(definition).sidePadding end,
        setFunc = function(value)
            GetBlockConfig(definition).sidePadding = Clamp(math.floor(tonumber(value) or 8), MIN_SIDE_PADDING, MAX_SIDE_PADDING)
            ApplyAllBlockSettings()
        end,
        default = GetBlockDefaults(definition).sidePadding,
    }
end

local function BuildSettingsOptions()
    local options = {
        {
            type = "description",
            text = "Each stat is an independent HUD block. Values refresh every 0.5 seconds. The panel is hidden by other menus.",
        },
        {
            type = "checkbox",
            name = "Show panels only in combat",
            getFunc = function() return savedVars.showOnlyInCombat end,
            setFunc = function(value)
                savedVars.showOnlyInCombat = value == true
                SyncUpdates()
            end,
            default = DEFAULTS.showOnlyInCombat,
        },
        {
            type = "slider",
            name = "Panel opacity",
            min = MIN_ALPHA,
            max = MAX_ALPHA,
            step = 0.05,
            decimals = 2,
            getFunc = function() return savedVars.panelAlpha end,
            setFunc = function(value)
                savedVars.panelAlpha = Clamp(tonumber(value) or DEFAULTS.panelAlpha, MIN_ALPHA, MAX_ALPHA)
                ApplyAllBlockSettings()
            end,
            default = DEFAULTS.panelAlpha,
        },
        {
            type = "dropdown",
            name = "Font style",
            choices = {
                FONT_STYLES.gamepadBold.label,
                FONT_STYLES.gamepad.label,
                FONT_STYLES.standardBold.label,
                FONT_STYLES.standard.label,
            },
            choicesValues = FONT_STYLE_KEYS,
            getFunc = function() return savedVars.fontStyle end,
            setFunc = function(value)
                if IsFontStyleValid(value) then
                    savedVars.fontStyle = value
                    ApplyAllBlockSettings()
                end
            end,
            default = DEFAULTS.fontStyle,
        },
        {
            type = "button",
            name = "Reset all block positions",
            func = ResetAllBlocks,
            width = "full",
        },
    }

    for _, definition in ipairs(BLOCK_DEFINITIONS) do
        AppendBlockSettings(options, definition)
    end

    return options
end

local function InitializeSettings()
    if not LibAddonMenu2 or type(LibAddonMenu2.RegisterAddonPanel) ~= "function" then
        AddChatLine("LibAddonMenu-2.0 is unavailable; settings were not registered")
        return
    end

    local registered, result = pcall(function()
        return LibAddonMenu2:RegisterAddonPanel(ADDON_NAME .. "_Settings", {
            type = "panel",
            name = "Leo Stats Panel",
            displayName = "Leo Stats Panel",
            author = "Leo_Kujo",
            version = VERSION,
            registerForRefresh = true,
            registerForDefaults = true,
        })
    end)

    if not registered then
        AddChatLine("settings panel registration failed: " .. tostring(result))
        return
    end

    settingsPanel = result
    local optionsRegistered, optionsError = pcall(function()
        LibAddonMenu2:RegisterOptionControls(ADDON_NAME .. "_Settings", BuildSettingsOptions())
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
    local normalized = tostring(command or ""):lower():match("^%s*(.-)%s*$")
    if normalized == "refresh" then
        ReadStats()
        RenderAll()
    end

    AddChatLine(string.format(
        "Lua=LOADED | HUD=%s | Settings=%s | WPD=%s | ARM=%s/%s | MREG=%s | SREG=%s | CRIT=%s | PEN=%s/%s | combat=%s",
        panelControls.wpd and "OK" or "NOT_INITIALIZED",
        settingsRegistered and "OK" or "NOT_REGISTERED",
        tostring(state.wpd),
        tostring(state.spellResist),
        tostring(state.physicalResist),
        tostring(state.magickaRecovery),
        tostring(state.staminaRecovery),
        tostring(state.critical),
        tostring(state.spellPenetration),
        tostring(state.physicalPenetration),
        tostring(state.inCombat)
    ))
end

SLASH_COMMANDS["/leostats"] = PrintDiagnostics
SLASH_COMMANDS["/lstats"] = PrintDiagnostics

local function NormalizeSavedVars()
    savedVars.panelAlpha = Clamp(tonumber(savedVars.panelAlpha) or DEFAULTS.panelAlpha, MIN_ALPHA, MAX_ALPHA)
    savedVars.showOnlyInCombat = savedVars.showOnlyInCombat == true
    if not IsFontStyleValid(savedVars.fontStyle) then
        savedVars.fontStyle = DEFAULTS.fontStyle
    end

    if type(savedVars.blocks) ~= "table" then
        savedVars.blocks = {}
    end

    for _, definition in ipairs(BLOCK_DEFINITIONS) do
        local defaults = GetBlockDefaults(definition)
        local config = savedVars.blocks[definition.id]
        if type(config) ~= "table" then
            config = {}
            savedVars.blocks[definition.id] = config
        end

        config.enabled = config.enabled ~= false
        config.x = Clamp(math.floor(tonumber(config.x) or defaults.x), MIN_POSITION_X, MAX_POSITION_X)
        config.y = Clamp(math.floor(tonumber(config.y) or defaults.y), MIN_POSITION_Y, MAX_POSITION_Y)
        config.scale = Clamp(tonumber(config.scale) or defaults.scale, MIN_SCALE, MAX_SCALE)
        config.textSize = Clamp(math.floor(tonumber(config.textSize) or defaults.textSize), MIN_TEXT_SIZE, MAX_TEXT_SIZE)
        config.sidePadding = Clamp(math.floor(tonumber(config.sidePadding) or defaults.sidePadding), MIN_SIDE_PADDING, MAX_SIDE_PADDING)
    end
end

local function CreateBlockControls()
    for _, definition in ipairs(BLOCK_DEFINITIONS) do
        local rootName = "Leo_stats_panel_" .. definition.id:upper()
        local control = _G[rootName]
        local background = control and control:GetNamedChild("Background")
        local text = control and control:GetNamedChild("Text")
        if not control or not background or not text then
            AddChatLine("HUD controls missing for block " .. definition.label)
            return false
        end

        panelControls[definition.id] = {
            control = control,
            background = background,
            text = text,
        }
    end

    return true
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    savedVars = ZO_SavedVars:NewAccountWide(SAVED_VARS_NAME, 1, nil, DEFAULTS)
    NormalizeSavedVars()

    if not CreateBlockControls() then
        return
    end

    InitializeSettings()
    RegisterSceneManagerCallback()
    ApplyAllBlockSettings()

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Activated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Combat", EVENT_PLAYER_COMBAT_STATE, OnCombatStateChanged)
    SyncUpdates()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
