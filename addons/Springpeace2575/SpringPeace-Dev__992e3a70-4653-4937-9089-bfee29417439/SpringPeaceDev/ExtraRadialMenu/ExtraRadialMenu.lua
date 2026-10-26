-----------------------------------------------------------
-- Author: SpringPeace2575 | Version: 0.9.0
-- ExtraRadialMenu add-on
-----------------------------------------------------------

ExtraRadialMenu = ExtraRadialMenu or {}
local ERM = ExtraRadialMenu
local ERMData = ExtraRadialMenuData
local ERMWheels = ExtraRadialMenuWheels

ERM.name = "ExtraRadialMenu"
ERM.displayName = "Extra Radial Menu"
ERM.savedVarsName = "ExtraRadialMenuSavedVars"
ERM.settingsPanelId = "ExtraRadialMenuPanel"
ERM.version = "0.9.0"

ERM.savedVarsVersion = 1
ERM.commandSlashCommand = "/erm"

ERM.state = {
    settingsRegistered = false,
}

ERM.defaults = {
    enable = true,
    keepOriginalAlliesWheel = false,

	wheelsEnabled = {
		[ERMWheels.ERM_WHEEL1] = false,
		[ERMWheels.ERM_WHEEL2] = false,
		[ERMWheels.ERM_WHEEL3] = true,
		-- [ERMWheels.ERM_WHEEL4] = false,
		-- [ERMWheels.ERM_WHEEL5] = false,
		-- [ERMWheels.ERM_WHEEL6] = false,
		-- [ERMWheels.ERM_WHEEL7] = false,
	},
	wheelsEntries = {
		[ERMWheels.ERM_WHEEL1] = {},
		[ERMWheels.ERM_WHEEL2] = {},
		[ERMWheels.ERM_WHEEL3] = {},
		-- [ERMWheels.ERM_WHEEL4] = {},
		-- [ERMWheels.ERM_WHEEL5] = {},
		-- [ERMWheels.ERM_WHEEL6] = {},
		-- [ERMWheels.ERM_WHEEL7] = {},
	},
}

function ERM.InitializeSavedVars()
	if type(ERM.sv.enable) ~= "boolean" then ERM.sv.enable = ERM.defaults.enable end
	if type(ERM.sv.keepOriginalAlliesWheel) ~= "boolean" then ERM.sv.keepOriginalAlliesWheel = ERM.defaults.keepOriginalAlliesWheel end
	if type(ERM.sv.wheelsEnabled) ~= "table" then ERM.sv.wheelsEnabled = {} end
    if type(ERM.sv.wheelsEntries) ~= "table" then ERM.sv.wheelsEntries = {} end
end

-- 1 -> Bottom-Right
-- 2 -> Right
-- 3 -> Top-Right
-- 4 -> Top
-- 5 -> Top-Left
-- 6 -> Left
-- 7 -> Bottom-Left
-- 8 -> Bottom

function ERM.GetSettingsOptions()
	-- TODO: all options
    return SPFLibUtils.ConcatArrays(SPFLibUtils.GetDonationSettingsOptions("SpringPeaceDev"), { -- TODO: use ERM.name when separated
        {
            type = "checkbox",
            name = "Enable",
			tooltip = "Enable or disable extra radial menu.",
            default = ERM.defaults.enable,
            getFunc = function() return ERM.sv.enable end,
            setFunc = function(value)
				ERM.sv.enable = value
				ERMWheels.RefreshWheels(ERM.sv.wheelsEnabled, ERM.sv.keepOriginalAlliesWheel, ERM.sv.enable)
			end,
            width = "full",
        },
		{
            type = "checkbox",
            name = "Keep Original Allies Wheel",
			tooltip = "Show the original Allies wheel.",
            default = ERM.defaults.keepOriginalAlliesWheel,
            getFunc = function() return ERM.sv.keepOriginalAlliesWheel end,
            setFunc = function(value)
				ERM.sv.keepOriginalAlliesWheel = value
				ERMWheels.RefreshWheels(ERM.sv.wheelsEnabled, ERM.sv.keepOriginalAlliesWheel, ERM.sv.enable)
			end,
            width = "full",
        },
    })
end

function ERM.RegisterSettings()
    if ERM.state.settingsRegistered then return end
    ERM.state.settingsRegistered = true

    local panelData = {
        type = "panel",
        name = ERM.name,
        displayName = ERM.displayName,
        author = "SpringPeace2575",
        version = ERM.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local options = ERM.GetSettingsOptions()

    SPFLibSettings.RegisterSettingsPanel(ERM.settingsPanelId, panelData, options, ERM.defaults, ERM.sv)
end

function ERM.RefreshFull()
    SPFLibSettings.RefreshSettings()
end

--[[ local function GetNextDirtyUnlockStateCollectibleIdIter(_, lastCollectibleId)
    return GetNextDirtyUnlockStateCollectibleId(lastCollectibleId)
end

function ERM.OnCollectiblesUnlockStateChanged(...)
    for collectibleId in GetNextDirtyUnlockStateCollectibleIdIter do
        -- TODO: add new collectible if relevant, refresh settings (this could be problematic)
    end
end

function ERM.RegisterEvents()
    local eventNamespace = ERM.name .. "_Entries"
    EVENT_MANAGER:RegisterForEvent(eventNamespace, EVENT_COLLECTIBLES_UNLOCK_STATE_CHANGED, function(_, ...) ERM.OnCollectiblesUnlockStateChanged(...) end)
end ]]

function ERM.Initialize(savedVariables, dev)
    if dev == true then
        ERM.sv = savedVariables
        if not ERM.sv then
            d("[ERM] SavedVars unavilable")
            return
        end
    else
        ERM.sv = ZO_SavedVars:NewAccountWide(ERM.savedVarsName, ERM.savedVarsVersion, nil, ERM.defaults, GetWorldName())
    end

    ERM.InitializeSavedVars()
    ERM.RegisterSettings()
    -- ERM.RegisterEvents()

	ERMWheels.RefreshWheels(ERM.sv.wheelsEnabled, ERM.sv.keepOriginalAlliesWheel, ERM.sv.enable)

    d("[ERM] Initialized")
end

function ERM.Activate()

end

function ERM.OnAddOnLoaded(eventCode, addonName)
	if addonName ~= ERM.name then return end

	EVENT_MANAGER:UnregisterForEvent(ERM.name, EVENT_ADD_ON_LOADED)

	ERM.Initialize({}, false)
    ERM.Activate()
end
