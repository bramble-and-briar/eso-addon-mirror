local isDevelopment = InventoryCompanion and InventoryCompanion.IsDevelopment == true
InventoryCompanion = {
    Name = isDevelopment and "InventoryCompanion_DEV" or "InventoryCompanion",
    IsDevelopment = isDevelopment,
	DisplayName = "Inventory Companion",
    Author = "@Tim-P",
    Version = "1.5.0",
    SettingsVersion = 2,
    SettingsName = "InventoryCompanion_SavedVariables",
}
local this = InventoryCompanion
this.state = {
    isLoaded = false, -- Set to true when it has finished loading so that we can check if it is safe to rely on our defined structures. Note that this is NOT breaking the guarding against our own code - if something has not loaded YET but we don't necessarily expect it to, then that is fine. We mitigated it. If it still fails after the addon is loaded, then we have something we need to fix and that is what the fail hard, fail fast mantra is for
	
    lastActiveEditTab = "InventoryCompanion_TrackedItemsScene", -- Tracks the last viewed edit panel tab
}

------------------------------------------------------------------
-- Core Initialization
------------------------------------------------------------------
function this.ValidateTrackerSettings()
    local value = this.accountWide.trackerMaxRows
    if value == nil then
        value = this.defaultsAccount.trackerMaxRows
    end
    assert(type(value) == "number" and value == value and value >= 5 and value <= 50
        and value == math.floor(value), "Saved trackerMaxRows must be an integer from 5 to 50")
    this.accountWide.trackerMaxRows = value
    local titleSize = this.accountWide.trackerTitleSize
    if titleSize == nil then titleSize = this.defaultsAccount.trackerTitleSize end
    assert(type(titleSize) == "number" and titleSize == titleSize and titleSize >= 16
        and titleSize <= 28 and titleSize == math.floor(titleSize),
        "Saved trackerTitleSize must be an integer from 16 to 28")
    this.accountWide.trackerTitleSize = titleSize
end

local function Initialize()
    this.PrepareSavedVariables()

    -- Register keybind display names in ESO controls menu
    ZO_CreateStringId("SI_BINDING_NAME_InventoryCompanion_Deposit_Crafted_Items", "Deposit Items to Bank")
    ZO_CreateStringId("SI_BINDING_NAME_InventoryCompanion_Withdraw_Crafted_Items", "Withdraw Items from Bank")
	ZO_CreateStringId("SI_BINDING_NAME_InventoryCompanion_Toggle_EditPanel", "Show/Hide Tracking Settings")
    ZO_CreateStringId("SI_BINDING_NAME_InventoryCompanion_Debug_Key", "Debug Key")
    ZO_CreateStringId("SI_BINDING_NAME_InventoryCompanion_Toggle_ItemTracker", "Show/Hide Item Tracking Panel")
	
    -- Load Saved Variables
    this.accountWide = ZO_SavedVars:NewAccountWide(this.SettingsName, this.SettingsVersion, nil, this.defaultsAccount)
    this.character   = ZO_SavedVars:NewCharacterIdSettings(this.SettingsName, this.SettingsVersion, nil, this.defaultsCharacter)
    this.ValidateTrackerSettings()
    this.ValidateSavedRuleProfiles()
    this.state.isCurrencySettingsOpen = false

    -- Initialize modules
    this.InitCutsceneTicker()
    this.InitContextMenus()
    this.InitializeCurrencyHelper()
    this.InitializeProgressBarResources()
    this.InitResourceProgressBars()
    this.InitItemTrackerPanel()
    this.InitCurrencyPanel()
    this.CreateSettingsPanel()
    this.UpdateEventRegistry()

    this.state.isLoaded = true
    if this.IsDevelopment then
        d("[InventoryCompanion] DEV version loaded.")
    end
end

local function OnAddOnLoaded(eventCode, name)
    if name == this.Name then
        EVENT_MANAGER:UnregisterForEvent(this.Name, eventCode)
        Initialize()
    end
end

EVENT_MANAGER:RegisterForEvent(this.Name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
-- Register the slash commands to clear corrupt rule overrides

------------------------------------------------------------------
-- Keybind Endpoints
------------------------------------------------------------------
function this.Deposit()
    this.ProcessBags({ BAG_BACKPACK }, BAG_BANK)
end

function this.Withdraw()
    this.ProcessBags({ BAG_BANK, BAG_SUBSCRIBER_BANK }, BAG_BACKPACK)
end

function this.ToggleEditPanel()
    this.ToggleTrackedItemsEditor()
end

------------------------------------------------------------------
-- Debug Routines
------------------------------------------------------------------
SLASH_COMMANDS["/icclearoverrides"] = function()
    local modeText = ""
    if this.character.useCharacterItemList then
        this.character.trackedRules = {}
        modeText = "Character-specific"
    else
        this.accountWide.trackedRules = {}
        modeText = "Account-wide"
    end
    this.InvalidateRuleCache()
    
    d(string.format("[InventoryCompanion] Cleared all rule overrides for current mode (%s). All rules restored to baseline defaults.", modeText))
    
    this.RefreshGroupsEditor()
    this.RefreshItemTrackerPanel()
end

------------------------------------------------------------------
-- Debug Key
------------------------------------------------------------------
function this.Debug()
    this.RunTests("verbose copy")
end
