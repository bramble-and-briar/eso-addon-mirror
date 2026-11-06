local isDevelopment = InventoryCompanion and InventoryCompanion.IsDevelopment == true
InventoryCompanion = {
    Name = isDevelopment and "InventoryCompanion_DEV" or "InventoryCompanion",
    IsDevelopment = isDevelopment,
	DisplayName = "Inventory Companion",
    Author = "@Tim-P",
    Version = "1.6.3",
    SettingsVersion = 10,
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
    local value = this.GetSettingsProfile().trackerMaxRows
    if value == nil then
        value = this.defaultsAccount.trackerMaxRows
    end
    assert(type(value) == "number" and value == value and value >= 5 and value <= 50
        and value == math.floor(value), "Saved trackerMaxRows must be an integer from 5 to 50")
    this.GetSettingsProfile().trackerMaxRows = value
    local titleSize = this.GetSettingsProfile().trackerTitleSize
    if titleSize == nil then titleSize = this.defaultsAccount.trackerTitleSize end
    assert(type(titleSize) == "number" and titleSize == titleSize and titleSize >= 16
        and titleSize <= 28 and titleSize == math.floor(titleSize),
        "Saved trackerTitleSize must be an integer from 16 to 28")
    this.GetSettingsProfile().trackerTitleSize = titleSize
end

function this.ValidateDebugSettings()
    local threshold = this.accountWide.autoCategoryTimingThresholdMs
    if threshold == nil then threshold = this.defaultsAccount.autoCategoryTimingThresholdMs end
    assert(type(threshold) == "number" and threshold == threshold and threshold >= 50 and threshold <= 5000
        and threshold == math.floor(threshold), "Saved autoCategoryTimingThresholdMs must be an integer from 50 to 5000")
    this.accountWide.autoCategoryTimingThresholdMs = threshold
    if this.accountWide.debug == nil then this.accountWide.debug = {} end
    assert(type(this.accountWide.debug) == "table", "Saved debug data must be a table")
    for key in pairs(this.accountWide.debug) do
        assert(key == "autoCategoryRemovedLines", "Saved debug data has an unknown field: " .. tostring(key))
    end
    if this.accountWide.debug.autoCategoryRemovedLines == nil then
        this.accountWide.debug.autoCategoryRemovedLines = {}
    end
    assert(type(this.accountWide.debug.autoCategoryRemovedLines) == "table",
        "Saved AutoCategory removed-line log must be a table")
end

function this.ValidateGuildBankPartialWithdrawSetting()
    local enabled = this.accountWide.guildBankPartialWithdrawEnabled
    if enabled == nil then enabled = this.defaultsAccount.guildBankPartialWithdrawEnabled end
    assert(type(enabled) == "boolean", "Saved guildBankPartialWithdrawEnabled must be a boolean")
    this.accountWide.guildBankPartialWithdrawEnabled = enabled
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
    this.ValidateDebugSettings()
    this.ValidateGuildBankPartialWithdrawSetting()
    this.ValidateSavedRuleProfiles()
    this.AutoCategoryIntegration.Initialize()
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
    
    this.RefreshTrackedItemsEditor()
    this.RefreshGroupsEditor()
    this.RefreshAutoCategoryEditor()
    this.RefreshItemTrackerPanel()
end

SLASH_COMMANDS["/iccleanautocategory"] = function()
    assert(type(GetDisplayName) == "function", "ESO account-name API is unavailable; no cleanup was performed")
    local accountName = GetDisplayName()
    assert(type(accountName) == "string" and accountName ~= "",
        "ESO account-name API returned an invalid name; no cleanup was performed")
    if accountName:lower():gsub("^@", "") ~= "tim-p" then
        d("[InventoryCompanion] AutoCategory saved-data cleanup is restricted to the @Tim-P account; no data was changed.")
        return
    end

    local profiles, assignments = this.CleanAutoCategorySavedData(accountName)
    d(string.format("[InventoryCompanion] Cleared AutoCategory integration data from %d @Tim-P IC profile(s) and removed %d IC-owned AutoCategory assignment(s). Other accounts and unrelated settings were preserved. Run /reloadui to finish.", profiles, assignments))
end

SLASH_COMMANDS["/iclistbackup"] = function(arguments)
    local action = type(arguments) == "string" and arguments:lower():match("^%s*(.-)%s*$") or ""
    if action == "save" then
        this.SaveAccountWideListBackup()
        d("[InventoryCompanion] Saved the account-wide tracked lists and AutoCategory choices. Character-specific lists and other settings were not changed.")
    elseif action == "recover" then
        this.RestoreAccountWideListBackup()
        d("[InventoryCompanion] Restored the account-wide tracked lists and AutoCategory choices. Run /reloadui to resynchronize AutoCategory.")
    else
        d("Usage: /iclistbackup save | /iclistbackup recover")
    end
end

if this.IsDevelopment then
    SLASH_COMMANDS["/icactest"] = function(arguments)
        local action = arguments:lower():match("^%s*(.-)%s*$")
        if action == "inject" then
            this.AutoCategoryIntegration.InjectTestAssignment()
        elseif action:match("^inject[1-4]$") then
            this.AutoCategoryIntegration.InjectTestAssignment(tonumber(action:sub(-1)))
        elseif action == "remove" then
            this.AutoCategoryIntegration.RemoveTestAssignment()
        elseif action == "verify" then
            this.AutoCategoryIntegration.ShowTestVerification()
        else
            d("Usage: /icactest inject1 | inject2 | inject3 | inject4 | remove | verify"
                .. " (DEV only; inject retains the original single-row test; verify is read-only)")
        end
    end
end

------------------------------------------------------------------
-- Debug Key
------------------------------------------------------------------
function this.Debug()
    this.RunTests("verbose copy")
end
