-- Create the global namespace for the addon
MuffinsUtilityTree = {}

-- Create a local shortcut for global
local MUT = MuffinsUtilityTree

-- local MUTInitializeColor = "EFFBBE" -- Chat color

-- AddOn information
MUT.name = "MuffinsUtilityTree"
MUT.prefix = "MUT"
MUT.version = "1.2"
MUT.author = "|c7851a9Muffins714|r"
MUT.website = ""

-- Default values for SavedVariable
local defaults = {
    -- Multi Stack Splitter
    splitterEnabled = false,

    -- Quality Sorter
    qualitySortEnabled = false,

    -- Reload UI
    reloadUIEnabled = false,

    -- Bank Stack All
    bankStackAllEnabled = false,
}

----------------------------------------------------------------------------
-- CHAT SYSTEM
----------------------------------------------------------------------------
--[[
-- Helper function to print branded messages to the chat
function MUT.MUTPrint(message)
    CHAT_SYSTEM:AddMessage(message)
end
]]

---------------------------------------------------------------------------------------------
-- RELOAD UI
---------------------------------------------------------------------------------------------
-- Scenes the keybind can attach to
local UIkeybindScene = {
    Menu   = "mainMenuGamepad",
    Map    = "gamepad_worldMap",
    Char   = "gamepad_stats_root",
    Social = "gamepad_groupList",
}

local UIkeybindButton = {
    -- Tertiary = "UI_SHORTCUT_TERTIARY", -- disabled
    Quinary    = "UI_SHORTCUT_QUINARY",
    Quaternary = "UI_SHORTCUT_QUATERNARY",
}
MUT.UIkeybindScene = UIkeybindScene
MUT.UIkeybindButton = UIkeybindButton

local reloadKeybindEntry = {
    name = GetString(SI_UI_ERROR_RELOAD_UI),
    keybind = "UI_SHORTCUT_QUINARY",
    callback = function() ReloadUI() end,
}
local reloadKeybindDescriptor = {
    alignment = KEYBIND_STRIP_ALIGN_LEFT,
    reloadKeybindEntry,
}

local currentReloadScene = nil
local isReloadKeybindShown = false

local function OnReloadSceneStateChange(oldState, newState)
    local settings = MUT.GetSettings()
    if not settings.reloadUIEnabled then
        if isReloadKeybindShown then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(reloadKeybindDescriptor)
            isReloadKeybindShown = false
        end
        return
    end
    if newState == SCENE_SHOWN then
        if not isReloadKeybindShown then
            KEYBIND_STRIP:AddKeybindButtonGroup(reloadKeybindDescriptor)
            isReloadKeybindShown = true
        end
    elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
        if isReloadKeybindShown then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(reloadKeybindDescriptor)
            isReloadKeybindShown = false
        end
    end
end

-- Call whenever the scene/button/enabled setting changes
function MUT.AddReloadUIKeyBind()
    local settings = MUT.GetSettings()

    if currentReloadScene then
        currentReloadScene:UnregisterCallback("StateChange", OnReloadSceneStateChange)
        if isReloadKeybindShown then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(reloadKeybindDescriptor)
            isReloadKeybindShown = false
        end
        currentReloadScene = nil
    end

    if not settings.reloadUIEnabled then return end

    reloadKeybindEntry.keybind = settings.chosenKeybind or UIkeybindButton.Quinary

    local sceneName = settings.visibleScene or UIkeybindScene.Menu
    local targetScene = SCENE_MANAGER:GetScene(sceneName)
    if not targetScene then return end

    currentReloadScene = targetScene
    currentReloadScene:RegisterCallback("StateChange", OnReloadSceneStateChange)
end

----------------------------------------------------------------------------
-- THE LOADING SCREEN
----------------------------------------------------------------------------
--[[
function MUT.OnPlayerActivated(event, initial)
    -- Print the message in chat box
   -- MUT.MUTPrint(zo_strformat("|c<<1>><<2>>|r", MUTInitializeColor, "Muffins Utility Tree Initialized!"))

    EVENT_MANAGER:UnregisterForEvent(MUT.name, EVENT_PLAYER_ACTIVATED)
end
]]

function MUT.OnAddOnLoaded(event, addonName)
    if addonName ~= MUT.name then return end
    EVENT_MANAGER:UnregisterForEvent(MUT.name, EVENT_ADD_ON_LOADED)

    MUT.GlobalSavedVars = ZO_SavedVars:NewAccountWide("MUTGlobalSavedVars", 1, nil, defaults, GetWorldName()) --account wide

    -- Reload UI
    MUT.AddReloadUIKeyBind()

    -- Make our options menu
    MUT.CreateSettingsMenu(defaults)

    -- Register the login message event
    -- EVENT_MANAGER:RegisterForEvent(MUT.name, EVENT_PLAYER_ACTIVATED, MUT.OnPlayerActivated)

    zo_callLater(function()
        MUT.Initialize_QualitySorter() -- Quality Sorter
        MUT.Initialize_MultiSplitter() -- Stack Splitter
        MUT.Initialize_BankStackAll()  -- Bank Stack All
    end, 100)
end

EVENT_MANAGER:RegisterForEvent(MUT.name, EVENT_ADD_ON_LOADED, MUT.OnAddOnLoaded)
