local ADDON_NAME = "Leo_status_panel"
local SAVED_VARS_NAME = "Leo_status_panel_SavedVariables"
local UPDATE_NAME = ADDON_NAME .. "_Update"

local VERSION = "0.1.2"
local UPDATE_INTERVAL_MS = 500
local PANEL_HEIGHT = 52
local PANEL_PADDING = 8
local ITEM_GAP = 10
local FPS_WIDTH = 76
local PING_WIDTH = 76
local INVENTORY_WIDTH = 96
local MEMORY_WIDTH = 88
local COMBAT_WIDTH = 36
local ADDON_MEMORY_LIMIT_MB = 100
local COMBAT_ICON = "EsoUI/Art/Icons/ability_weapon_001.dds"
local COMBAT_RED = { 1.0, 0.18, 0.18, 1.0 }
local COMBAT_WHITE = { 1.0, 1.0, 1.0, 1.0 }

local FONT_STYLES = {
    gamepadBold = {
        label = "Gamepad Bold",
        font = "ZoFontGamepadBold18",
    },
    gamepad = {
        label = "Gamepad Normal",
        font = "ZoFontGamepad18",
    },
    standardBold = {
        label = "Standard Bold",
        font = "ZoFontGameBold",
    },
    standard = {
        label = "Standard Normal",
        font = "ZoFontGame",
    },
}

local FONT_STYLE_KEYS = { "gamepadBold", "gamepad", "standardBold", "standard" }

local DEFAULTS = {
    x = 300,
    y = 120,
    scale = 1.0,
    panelAlpha = 0.88,
    showFps = true,
    showPing = true,
    showInventory = true,
    showMemory = true,
    showCombat = true,
    fontStyle = "gamepadBold",
}

local panel
local background
local fpsLabel
local pingLabel
local inventoryLabel
local memoryLabel
local combatIcon
local savedVars
local settingsPanel
local consoleSettings
local settingsRegistered = false
local settingsCallbacksRegistered = false
local consoleSceneCallbackRegistered = false
local updateRegistered = false

local state = {
    fps = nil,
    ping = nil,
    bagUsed = nil,
    bagSize = nil,
    addonMemoryMb = nil,
    inCombat = false,
}

local function AddChatLine(text)
    local message = "[Leo Status Panel] " .. tostring(text)
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

local function GetFontName()
    local style = IsFontStyleValid(savedVars.fontStyle) and savedVars.fontStyle or DEFAULTS.fontStyle
    return FONT_STYLES[style].font
end

local function ApplyFont()
    if not fpsLabel or not pingLabel or not inventoryLabel or not memoryLabel or not combatIcon then
        return
    end

    local font = GetFontName()
    local labels = { fpsLabel, pingLabel, inventoryLabel, memoryLabel }
    for _, label in ipairs(labels) do
        label:SetFont(font)
        label:SetColor(1, 1, 1, 1)
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        label:SetDrawLayer(DL_OVERLAY)
        label:SetDrawTier(DT_HIGH)
        label:SetDrawLevel(5)
    end
end

local function GetCurrentFps()
    local value
    if type(GetFramerate) == "function" then
        value = GetFramerate()
    elseif type(GetFrameRate) == "function" then
        value = GetFrameRate()
    end

    value = tonumber(value)
    if value and value >= 0 then
        return value
    end

    return nil
end

local function GetCurrentPing()
    if type(GetLatency) ~= "function" then
        return nil
    end

    local value = tonumber(GetLatency())
    if value and value >= 0 then
        return math.floor(value + 0.5)
    end

    return nil
end

local function GetInventoryCounts()
    if type(GetNumBagUsedSlots) ~= "function"
        or type(GetBagSize) ~= "function"
        or BAG_BACKPACK == nil then
        return nil, nil
    end

    local used = tonumber(GetNumBagUsedSlots(BAG_BACKPACK))
    local size = tonumber(GetBagSize(BAG_BACKPACK))
    if not used or not size then
        return nil, nil
    end

    return math.max(0, math.floor(used)), math.max(0, math.floor(size))
end

local function GetAddonMemoryUsageMb()
    if type(GetTotalUserAddOnMemoryPoolUsageMB) ~= "function" then
        return nil
    end

    local value = tonumber(GetTotalUserAddOnMemoryPoolUsageMB())
    if not value or value < 0 then
        return nil
    end

    return math.max(0, math.floor(value + 0.5))
end

local function GetCombatState()
    if type(IsUnitInCombat) ~= "function" then
        return false
    end

    return IsUnitInCombat("player") == true
end

local function ReadMetrics()
    if savedVars.showFps then
        state.fps = GetCurrentFps()
    else
        state.fps = nil
    end

    if savedVars.showPing then
        state.ping = GetCurrentPing()
    else
        state.ping = nil
    end

    if savedVars.showInventory then
        state.bagUsed, state.bagSize = GetInventoryCounts()
    else
        state.bagUsed, state.bagSize = nil, nil
    end

    if savedVars.showMemory then
        state.addonMemoryMb = GetAddonMemoryUsageMb()
    else
        state.addonMemoryMb = nil
    end

    if savedVars.showCombat then
        state.inCombat = GetCombatState()
    end
end

local function HasVisibleMetrics()
    return savedVars.showFps
        or savedVars.showPing
        or savedVars.showInventory
        or savedVars.showMemory
        or savedVars.showCombat
end

local function SetControlVisibility(control, visible)
    if control then
        control:SetHidden(not visible)
    end
end

local function LayoutPanel()
    if not panel then
        return
    end

    local items = {
        { control = fpsLabel, width = FPS_WIDTH, visible = savedVars.showFps },
        { control = pingLabel, width = PING_WIDTH, visible = savedVars.showPing },
        { control = inventoryLabel, width = INVENTORY_WIDTH, visible = savedVars.showInventory },
        { control = memoryLabel, width = MEMORY_WIDTH, visible = savedVars.showMemory },
        { control = combatIcon, width = COMBAT_WIDTH, visible = savedVars.showCombat },
    }

    local visibleCount = 0
    local totalWidth = PANEL_PADDING * 2
    for _, item in ipairs(items) do
        SetControlVisibility(item.control, item.visible)
        if item.visible then
            visibleCount = visibleCount + 1
            totalWidth = totalWidth + item.width
        end
    end

    if visibleCount > 1 then
        totalWidth = totalWidth + (visibleCount - 1) * ITEM_GAP
    end

    panel:SetDimensions(math.max(1, totalWidth), PANEL_HEIGHT)

    local offsetX = PANEL_PADDING
    for _, item in ipairs(items) do
        if item.visible then
            item.control:ClearAnchors()
            item.control:SetAnchor(LEFT, panel, LEFT, offsetX, 0)
            item.control:SetDimensions(item.width, PANEL_HEIGHT)
            offsetX = offsetX + item.width + ITEM_GAP
        end
    end

    panel:SetHidden(not HasVisibleMetrics())
end

local function FormatFps()
    if not state.fps then
        return "-- fps"
    end

    return string.format("%d fps", math.floor(state.fps + 0.5))
end

local function FormatPing()
    if state.ping == nil then
        return "-- ms"
    end

    return string.format("%d ms", state.ping)
end

local function FormatInventory()
    if state.bagUsed == nil or state.bagSize == nil then
        return "--/--"
    end

    return string.format("%d/%d", state.bagUsed, state.bagSize)
end

local function FormatMemory()
    if state.addonMemoryMb == nil then
        return "--/" .. tostring(ADDON_MEMORY_LIMIT_MB)
    end

    return string.format("%d/%d", state.addonMemoryMb, ADDON_MEMORY_LIMIT_MB)
end

local function Render()
    if not panel then
        return
    end

    LayoutPanel()
    fpsLabel:SetText(FormatFps())
    pingLabel:SetText(FormatPing())
    inventoryLabel:SetText(FormatInventory())
    memoryLabel:SetText(FormatMemory())
    if state.inCombat then
        combatIcon:SetColor(COMBAT_RED[1], COMBAT_RED[2], COMBAT_RED[3], COMBAT_RED[4])
    else
        combatIcon:SetColor(COMBAT_WHITE[1], COMBAT_WHITE[2], COMBAT_WHITE[3], COMBAT_WHITE[4])
    end
end

local function StopUpdates()
    if updateRegistered then
        EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
        updateRegistered = false
    end
end

local function StartUpdates()
    if updateRegistered or not HasVisibleMetrics() then
        return
    end

    EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, UPDATE_INTERVAL_MS, function()
        ReadMetrics()
        Render()
    end)
    updateRegistered = true
end

local function SyncUpdates()
    if HasVisibleMetrics() then
        ReadMetrics()
        StartUpdates()
    else
        StopUpdates()
    end
end

local function ApplyPanelSettings()
    if not panel or not savedVars then
        return
    end

    panel:ClearAnchors()
    panel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, savedVars.x, savedVars.y)
    panel:SetScale(savedVars.scale)
    if background then
        background:SetAlpha(savedVars.panelAlpha)
    end

    ApplyFont()
    Render()
end

local function OnCombatStateChanged(_, inCombat)
    if type(inCombat) == "boolean" then
        state.inCombat = inCombat
    else
        state.inCombat = GetCombatState()
    end
    Render()
end

local function OnPlayerActivated()
    ReadMetrics()
    ApplyPanelSettings()
    SyncUpdates()
end

local function OnLAMPanelOpened(selectedPanel)
    if selectedPanel == settingsPanel then
        ApplyPanelSettings()
    end
end

local function OnLAMPanelClosed(selectedPanel)
    if selectedPanel == settingsPanel then
        ApplyPanelSettings()
    end
end

local function OnConsoleSettingsSceneStateChange(newState)
    if newState == SCENE_SHOWING or newState == SCENE_SHOWN or newState == SCENE_HIDING or newState == SCENE_HIDDEN then
        ApplyPanelSettings()
    end
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
    if addonSettings == consoleSettings then
        ApplyPanelSettings()
    end
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

local function BuildSettingsOptions()
    local fontDefaults = {}
    for _, key in ipairs(FONT_STYLE_KEYS) do
        fontDefaults[#fontDefaults + 1] = FONT_STYLES[key].label
    end

    return {
        {
            type = "description",
            text = "Horizontal status panel with FPS, latency, inventory and combat state.",
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
            name = "Panel opacity",
            min = 0.1,
            max = 1.0,
            step = 0.05,
            decimals = 2,
            getFunc = function() return savedVars.panelAlpha end,
            setFunc = function(value)
                savedVars.panelAlpha = Clamp(tonumber(value) or DEFAULTS.panelAlpha, 0.1, 1.0)
                ApplyPanelSettings()
            end,
            default = DEFAULTS.panelAlpha,
        },
        {
            type = "dropdown",
            name = "Font style",
            choices = fontDefaults,
            choicesValues = FONT_STYLE_KEYS,
            getFunc = function() return savedVars.fontStyle end,
            setFunc = function(value)
                if IsFontStyleValid(value) then
                    savedVars.fontStyle = value
                    ApplyPanelSettings()
                end
            end,
            default = DEFAULTS.fontStyle,
        },
        {
            type = "header",
            name = "Displayed values",
        },
        {
            type = "checkbox",
            name = "Show FPS",
            getFunc = function() return savedVars.showFps end,
            setFunc = function(value)
                savedVars.showFps = value == true
                SyncUpdates()
                Render()
            end,
            default = DEFAULTS.showFps,
        },
        {
            type = "checkbox",
            name = "Show Ping",
            getFunc = function() return savedVars.showPing end,
            setFunc = function(value)
                savedVars.showPing = value == true
                SyncUpdates()
                Render()
            end,
            default = DEFAULTS.showPing,
        },
        {
            type = "checkbox",
            name = "Show Inventory",
            getFunc = function() return savedVars.showInventory end,
            setFunc = function(value)
                savedVars.showInventory = value == true
                SyncUpdates()
                Render()
            end,
            default = DEFAULTS.showInventory,
        },
        {
            type = "checkbox",
            name = "Show Add-on Memory",
            tooltip = "Shows total memory used by all enabled add-ons on console, in MB.",
            getFunc = function() return savedVars.showMemory end,
            setFunc = function(value)
                savedVars.showMemory = value == true
                SyncUpdates()
                Render()
            end,
            default = DEFAULTS.showMemory,
        },
        {
            type = "checkbox",
            name = "Show Combat",
            getFunc = function() return savedVars.showCombat end,
            setFunc = function(value)
                savedVars.showCombat = value == true
                SyncUpdates()
                Render()
            end,
            default = DEFAULTS.showCombat,
        },
    }
end

local function InitializeSettings()
    if not LibAddonMenu2 or type(LibAddonMenu2.RegisterAddonPanel) ~= "function" then
        AddChatLine("LibAddonMenu-2.0 is unavailable; settings were not registered")
        return
    end

    local registered, result = pcall(function()
        return LibAddonMenu2:RegisterAddonPanel(ADDON_NAME .. "_Settings", {
            type = "panel",
            name = "Leo Status Panel",
            displayName = "Leo Status Panel",
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
        ReadMetrics()
        Render()
    end

    AddChatLine(string.format(
        "Lua=LOADED | HUD=%s | Settings=%s | FPS=%s | Ping=%s | Bag=%s/%s | Memory=%s/%d | Combat=%s",
        panel and "OK" or "NOT_INITIALIZED",
        settingsRegistered and "OK" or "NOT_REGISTERED",
        tostring(state.fps),
        tostring(state.ping),
        tostring(state.bagUsed),
        tostring(state.bagSize),
        tostring(state.addonMemoryMb),
        ADDON_MEMORY_LIMIT_MB,
        tostring(state.inCombat)
    ))
end

SLASH_COMMANDS["/leostatus"] = PrintDiagnostics
SLASH_COMMANDS["/lsp"] = PrintDiagnostics

local function NormalizeSavedVars()
    savedVars.x = math.floor(tonumber(savedVars.x) or DEFAULTS.x)
    savedVars.y = math.floor(tonumber(savedVars.y) or DEFAULTS.y)
    savedVars.scale = Clamp(tonumber(savedVars.scale) or DEFAULTS.scale, 0.5, 2.0)
    savedVars.panelAlpha = Clamp(tonumber(savedVars.panelAlpha) or DEFAULTS.panelAlpha, 0.1, 1.0)
    savedVars.showFps = savedVars.showFps ~= false
    savedVars.showPing = savedVars.showPing ~= false
    savedVars.showInventory = savedVars.showInventory ~= false
    savedVars.showMemory = savedVars.showMemory ~= false
    savedVars.showCombat = savedVars.showCombat ~= false
    if not IsFontStyleValid(savedVars.fontStyle) then
        savedVars.fontStyle = DEFAULTS.fontStyle
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    panel = Leo_status_panel
    if not panel then
        AddChatLine("HUD root control Leo_status_panel was not created from XML")
        return
    end

    background = panel:GetNamedChild("Background")
    fpsLabel = panel:GetNamedChild("Fps")
    pingLabel = panel:GetNamedChild("Ping")
    inventoryLabel = panel:GetNamedChild("Inventory")
    memoryLabel = panel:GetNamedChild("Memory")
    combatIcon = panel:GetNamedChild("Combat")
    if not background or not fpsLabel or not pingLabel or not inventoryLabel or not memoryLabel or not combatIcon then
        AddChatLine("one or more HUD child controls were not found")
        return
    end

    combatIcon:SetTexture(COMBAT_ICON)

    savedVars = ZO_SavedVars:NewAccountWide(SAVED_VARS_NAME, 1, nil, DEFAULTS)
    NormalizeSavedVars()
    ReadMetrics()
    ApplyPanelSettings()
    InitializeSettings()

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Activated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "_Combat", EVENT_PLAYER_COMBAT_STATE, OnCombatStateChanged)
    StartUpdates()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
