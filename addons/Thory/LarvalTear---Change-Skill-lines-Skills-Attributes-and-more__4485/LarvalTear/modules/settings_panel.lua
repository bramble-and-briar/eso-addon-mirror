local Addon = LarvalTearMod
local SettingsPanel = Addon.Modules.SettingsPanel

local SETTINGS_PANEL_ID = "LarvalTearSettings"

local function GetLibAddonMenu()
    local lam = rawget(_G, "LibAddonMenu2")
    if type(lam) ~= "table" then
        return nil
    end

    if type(lam.RegisterAddonPanel) ~= "function" or type(lam.RegisterOptionControls) ~= "function" then
        return nil
    end

    return lam
end

local function IsHudLauncherVisible()
    local settings = Addon:GetHudLauncherSettings(false)
    return type(settings) ~= "table" or settings.hidden ~= true
end

local function IsHudLauncherLocked()
    local settings = Addon:GetHudLauncherSettings(false)
    return type(settings) == "table" and settings.locked == true
end

local function IsDebugModeEnabled()
    return type(Addon.savedVars) == "table" and Addon.savedVars.debugRunCompact == true
end

local function IsPrintMessagesEnabled()
    return Addon:IsPrintMessagesEnabled()
end

local function IsIgnoreCostumesEnabled()
    return Addon:IsIgnoreCostumesEnabled()
end

local function IsAutoRefillQuickSlotEnabled()
    return Addon:IsAutoRefillQuickSlotEnabled()
end

local function IsAutoRefillFoodHelperEnabled()
    return Addon:IsAutoRefillFoodHelperEnabled()
end

local function GetEquipmentDepositCleanupScope()
    return Addon:GetEquipmentDepositCleanupScope()
end

local function SetEquipmentDepositCleanupScope(value)
    Addon:SetEquipmentDepositCleanupScope(value)
end

local function GetEquipmentDepositItemFilter()
    return Addon:GetEquipmentDepositItemFilter()
end

local function SetEquipmentDepositItemFilter(value)
    Addon:SetEquipmentDepositItemFilter(value)
end

local function GetEquipmentDepositSafetyMode()
    return Addon:GetEquipmentDepositSafetyMode()
end

local function SetEquipmentDepositSafetyMode(value)
    Addon:SetEquipmentDepositSafetyMode(value)
end

local function GetApplyUiMode()
    return Addon:GetApplyUiMode()
end

local function SetApplyUiMode(value)
    Addon:SetApplyUiMode(value)
end

function SettingsPanel:Register()
    if self.registered == true then
        return true
    end

    local lam = GetLibAddonMenu()
    if lam == nil then
        return false
    end

    local displayName = Addon.displayName or Addon.name or "LarvalTear"
    local panelData = {
        name = displayName,
        displayName = displayName,
        author = "Thory'JP",
    }
    local optionsTable = {
        {
            type = "header",
            name = Addon.GetStringText("SI_LTM_SETTINGS_HEADER"),
        },
        {
            type = "checkbox",
            name = Addon.GetStringText("SI_LTM_SETTINGS_SHOW_ICON"),
            tooltip = Addon.GetStringText("SI_LTM_SETTINGS_SHOW_ICON_TOOLTIP"),
            getFunc = IsHudLauncherVisible,
            setFunc = function(value)
                Addon:SetHudLauncherHidden(value ~= true)
            end,
            default = true,
        },
        {
            type = "checkbox",
            name = Addon.GetStringText("SI_LTM_SETTINGS_LOCK_ICON"),
            tooltip = Addon.GetStringText("SI_LTM_SETTINGS_LOCK_ICON_TOOLTIP"),
            getFunc = IsHudLauncherLocked,
            setFunc = function(value)
                Addon:SetHudLauncherLocked(value == true)
            end,
            default = false,
        },
        {
            type = "checkbox",
            name = Addon.GetStringText("SI_LTM_SETTINGS_PRINT_MESSAGES"),
            tooltip = Addon.GetStringText("SI_LTM_SETTINGS_PRINT_MESSAGES_TOOLTIP"),
            getFunc = IsPrintMessagesEnabled,
            setFunc = function(value)
                Addon:SetPrintMessagesEnabled(value == true)
            end,
            default = true,
        },
        {
            type = "header",
            name = Addon.GetStringText("SI_LTM_SETTINGS_IGNORE_HEADER"),
        },
        {
            type = "checkbox",
            name = Addon.GetStringText("SI_LTM_SETTINGS_IGNORE_COSTUMES"),
            tooltip = Addon.GetStringText("SI_LTM_SETTINGS_IGNORE_COSTUMES_TOOLTIP"),
            getFunc = IsIgnoreCostumesEnabled,
            setFunc = function(value)
                if Addon:SetIgnoreCostumesEnabled(value == true) then
                    CALLBACK_MANAGER:FireCallbacks("LTM_IgnoreCostumesChanged")
                end
            end,
            default = false,
        },
        {
            type = "header",
            name = Addon.GetStringText("SI_LTM_SETTINGS_AUTO_REFILL_HEADER"),
        },
        {
            type = "description",
            text = Addon.GetStringText("SI_LTM_SETTINGS_AUTO_REFILL_DESCRIPTION"),
        },
        {
            type = "checkbox",
            name = Addon.GetStringText("SI_LTM_SETTINGS_AUTO_REFILL_QUICK_SLOT"),
            tooltip = Addon.GetStringText("SI_LTM_SETTINGS_AUTO_REFILL_QUICK_SLOT_TOOLTIP"),
            getFunc = IsAutoRefillQuickSlotEnabled,
            setFunc = function(value)
                Addon:SetAutoRefillQuickSlotEnabled(value == true)
            end,
            default = false,
        },
        {
            type = "checkbox",
            name = Addon.GetStringText("SI_LTM_SETTINGS_AUTO_REFILL_FOOD_HELPER"),
            tooltip = Addon.GetStringText("SI_LTM_SETTINGS_AUTO_REFILL_FOOD_HELPER_TOOLTIP"),
            getFunc = IsAutoRefillFoodHelperEnabled,
            setFunc = function(value)
                Addon:SetAutoRefillFoodHelperEnabled(value == true)
            end,
            default = false,
        },
        {
            type = "header",
            name = Addon.GetStringText("SI_LTM_SETTINGS_DEPOSIT_HEADER"),
        },
        {
            type = "dropdown",
            name = Addon.GetStringText("SI_LTM_SETTINGS_DEPOSIT_CLEANUP_SCOPE"),
            tooltip = Addon.GetStringText("SI_LTM_SETTINGS_DEPOSIT_CLEANUP_SCOPE_TOOLTIP"),
            choices = {
                Addon.GetStringText("SI_LTM_SETTINGS_DEPOSIT_SCOPE_CURRENT_BUILD"),
                Addon.GetStringText("SI_LTM_SETTINGS_DEPOSIT_SCOPE_ALL_BUILD_CARDS"),
            },
            choicesValues = {
                "current_build",
                "all_build_cards",
            },
            choicesTooltips = {
                Addon.GetStringText("SI_LTM_SETTINGS_DEPOSIT_SCOPE_CURRENT_BUILD_TOOLTIP"),
                Addon.GetStringText("SI_LTM_SETTINGS_DEPOSIT_SCOPE_ALL_BUILD_CARDS_TOOLTIP"),
            },
            getFunc = GetEquipmentDepositCleanupScope,
            setFunc = SetEquipmentDepositCleanupScope,
            default = "all_build_cards",
        },
        {
            type = "description",
            text = Addon.GetStringText("SI_LTM_SETTINGS_DEPOSIT_CLEANUP_SCOPE_DESCRIPTION"),
        },
        {
            type = "dropdown",
            name = Addon.GetStringText("SI_LTM_SETTINGS_EQUIPMENT_DEPOSIT_ITEM_FILTER"),
            tooltip = Addon.GetStringText("SI_LTM_SETTINGS_EQUIPMENT_DEPOSIT_ITEM_FILTER_TOOLTIP"),
            choices = {
                Addon.GetStringText("SI_LTM_SETTINGS_EQUIPMENT_DEPOSIT_ITEM_FILTER_ALL"),
                Addon.GetStringText("SI_LTM_SETTINGS_EQUIPMENT_DEPOSIT_ITEM_FILTER_SAVED_BUILD_ONLY"),
            },
            choicesValues = {
                "all_equipment",
                "saved_build_gear_only",
            },
            getFunc = GetEquipmentDepositItemFilter,
            setFunc = SetEquipmentDepositItemFilter,
            default = "saved_build_gear_only",
        },
        {
            type = "description",
            text = Addon.GetStringText("SI_LTM_SETTINGS_EQUIPMENT_DEPOSIT_ITEM_FILTER_DESCRIPTION"),
        },
        {
            type = "dropdown",
            name = Addon.GetStringText("SI_LTM_SETTINGS_DEPOSIT_SAFETY_MODE"),
            tooltip = Addon.GetStringText("SI_LTM_SETTINGS_DEPOSIT_SAFETY_MODE_TOOLTIP"),
            choices = {
                Addon.GetStringText("SI_LTM_SETTINGS_DEPOSIT_SAFETY_STRICT"),
                Addon.GetStringText("SI_LTM_SETTINGS_DEPOSIT_SAFETY_NORMAL"),
                Addon.GetStringText("SI_LTM_SETTINGS_DEPOSIT_SAFETY_AGGRESSIVE"),
            },
            choicesValues = {
                "strict",
                "normal",
                "aggressive",
            },
            choicesTooltips = {
                Addon.GetStringText("SI_LTM_SETTINGS_DEPOSIT_SAFETY_STRICT_TOOLTIP"),
                Addon.GetStringText("SI_LTM_SETTINGS_DEPOSIT_SAFETY_NORMAL_TOOLTIP"),
                Addon.GetStringText("SI_LTM_SETTINGS_DEPOSIT_SAFETY_AGGRESSIVE_TOOLTIP"),
            },
            getFunc = GetEquipmentDepositSafetyMode,
            setFunc = SetEquipmentDepositSafetyMode,
            default = "normal",
        },
        {
            type = "description",
            text = Addon.GetStringText("SI_LTM_SETTINGS_DEPOSIT_SAFETY_MODE_DESCRIPTION"),
        },
        {
            type = "header",
            name = Addon.GetStringText("SI_LTM_SETTINGS_APPLY_UI_HEADER"),
        },
        {
            type = "dropdown",
            name = Addon.GetStringText("SI_LTM_SETTINGS_APPLY_UI_MODE"),
            tooltip = Addon.GetStringText("SI_LTM_SETTINGS_APPLY_UI_MODE_TOOLTIP"),
            choices = {
                Addon.GetStringText("SI_LTM_SETTINGS_APPLY_UI_MODE_DEFAULT"),
                Addon.GetStringText("SI_LTM_SETTINGS_APPLY_UI_MODE_SMALL_PROGRESS"),
            },
            choicesValues = {
                "default",
                "small_progress",
            },
            choicesTooltips = {
                Addon.GetStringText("SI_LTM_SETTINGS_APPLY_UI_MODE_DEFAULT_TOOLTIP"),
                Addon.GetStringText("SI_LTM_SETTINGS_APPLY_UI_MODE_SMALL_PROGRESS_TOOLTIP"),
            },
            getFunc = GetApplyUiMode,
            setFunc = SetApplyUiMode,
            default = "default",
        },
        {
            type = "header",
            name = Addon.GetStringText("SI_LTM_SETTINGS_SKILL_SETTINGS_HEADER"),
        },
        {
            type = "description",
            text = Addon.GetStringText("SI_LTM_SETTINGS_SKILL_SETTINGS_DESCRIPTION"),
        },
        {
            type = "header",
            name = Addon.GetStringText("SI_LTM_SETTINGS_DEVELOPER_HEADER"),
        },
        {
            type = "checkbox",
            name = Addon.GetStringText("SI_LTM_SETTINGS_DEBUG_MODE"),
            tooltip = Addon.GetStringText("SI_LTM_SETTINGS_DEBUG_MODE_TOOLTIP"),
            getFunc = IsDebugModeEnabled,
            setFunc = function(value)
                Addon:SetCompactDebugRunEnabled(value == true)
            end,
            default = false,
        },
    }

    self.panel = lam:RegisterAddonPanel(SETTINGS_PANEL_ID, panelData)
    lam:RegisterOptionControls(SETTINGS_PANEL_ID, optionsTable)
    self.registered = true
    return true
end

function SettingsPanel:Open()
    local lam = GetLibAddonMenu()
    if self.registered ~= true or self.panel == nil or lam == nil
        or type(lam.OpenToPanel) ~= "function" then
        return false, "settings_panel_unavailable"
    end
    lam:OpenToPanel(self.panel)
    return true
end
