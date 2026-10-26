-----------------------------------------------------------
-- Author: SpringPeace2575 | Version: 0.9.0
-- FurnishThemAll add-on
-----------------------------------------------------------

FurnishThemAll = FurnishThemAll or {}
local FTA = FurnishThemAll
local FTAData = FurnishThemAllData
local FTAResults = FurnishThemAllResults
local FTAGui = FurnishThemAllGui

FTA.name = "FurnishThemAll"
FTA.displayName = "Furnish Them All"
FTA.savedVarsName = "FurnishThemAllSavedVars"
FTA.settingsPanelId = "FurnishThemAllPanel"
FTA.version = "0.9.0"

FTA.savedVarsVersion = 1
FTA.commandSlashCommand = "/fta"

FTA.state = {
    menuRegistered = false,
    settingsRegistered = false,
}

FTA.defaults = {
    showUncollectedItemsOnly = false,
    rebuildOnDemandOnly = true,
    enablePageRotation = true,
    showIcons = true,
    orderedBy = 3,
    debug = false,
    enable = true,

    freshLevelTimeUnit = "Day",
    freshLevelTimeValue = 1,
    recentLevelTimeUnit = "Month",
    recentLevelTimeValue = 1,

    selectedCategory = "All",
    selectedSubcategory = "All",
    selectedSource = "All",
    selectedGroup = "All",
    selectedTag = "All",
    selectedInventory = "All",

    inventoriesLastCheck = {},

    -- collections, values by ix
    results = {},
    categories = {},
    subcategories = {},
    sources = {},
    groups = {},
    tags = {},
    types = {},

    collectedCount = 0,
    totalCount = 0,

    lastVersion = "0.0.1",
    nextVersion = nil,
}

function FTA.InitializeSavedVars()
	if type(FTA.sv.showUncollectedItemsOnly) ~= "boolean" then FTA.sv.showUncollectedItemsOnly = FTA.defaults.showUncollectedItemsOnly end
	if type(FTA.sv.rebuildOnDemandOnly) ~= "boolean" then FTA.sv.rebuildOnDemandOnly = FTA.defaults.rebuildOnDemandOnly end
    if type(FTA.sv.enablePageRotation) ~= "boolean" then FTA.sv.enablePageRotation = FTA.defaults.enablePageRotation end
    if type(FTA.sv.showIcons) ~= "boolean" then FTA.sv.showIcons = FTA.defaults.showIcons end
    if type(FTA.sv.orderedBy) ~= "number" then FTA.sv.orderedBy = FTA.defaults.orderedBy end
    if type(FTA.sv.selectedCategory) ~= "string" then FTA.sv.selectedCategory = FTA.defaults.selectedCategory end
    if type(FTA.sv.selectedSubcategory) ~= "string" then FTA.sv.selectedSubcategory = FTA.defaults.selectedSubcategory end
    if type(FTA.sv.selectedSource) ~= "string" then FTA.sv.selectedSource = FTA.defaults.selectedSource end
    if type(FTA.sv.selectedGroup) ~= "string" then FTA.sv.selectedGroup = FTA.defaults.selectedGroup end
    if type(FTA.sv.selectedTag) ~= "string" then FTA.sv.selectedTag = FTA.defaults.selectedTag end
    if type(FTA.sv.selectedInventory) ~= "string" then FTA.sv.selectedInventory = FTA.defaults.selectedInventory end
    if type(FTA.sv.inventoriesLastCheck) ~= "table" then FTA.sv.inventoriesLastCheck = FTA.defaults.inventoriesLastCheck end
    if type(FTA.sv.debug) ~= "boolean" then FTA.sv.debug = FTA.defaults.debug end
    if type(FTA.sv.enable) ~= "boolean" then FTA.sv.enable = FTA.defaults.enable end
    if type(FTA.sv.freshLevelTimeUnit) ~= "string" then FTA.sv.freshLevelTimeUnit = FTA.defaults.freshLevelTimeUnit end
    if type(FTA.sv.freshLevelTimeValue) ~= "number" then FTA.sv.freshLevelTimeValue = FTA.defaults.freshLevelTimeValue end
    if type(FTA.sv.recentLevelTimeUnit) ~= "string" then FTA.sv.recentLevelTimeUnit = FTA.defaults.recentLevelTimeUnit end
    if type(FTA.sv.recentLevelTimeValue) ~= "number" then FTA.sv.recentLevelTimeValue = FTA.defaults.recentLevelTimeValue end
    if type(FTA.sv.results) ~= "table" then FTA.sv.results = {} end
    if type(FTA.sv.categories) ~= "table" then FTA.sv.categories = {} end
    if type(FTA.sv.subcategories) ~= "table" then FTA.sv.subcategories = {} end
    if type(FTA.sv.sources) ~= "table" then FTA.sv.sources = {} end
    if type(FTA.sv.groups) ~= "table" then FTA.sv.groups = {} end
    if type(FTA.sv.tags) ~= "table" then FTA.sv.tags = {} end
    if type(FTA.sv.types) ~= "table" then FTA.sv.types = {} end

    if type(FTA.sv.collectedCount) ~= "number" then FTA.sv.collectedCount = FTA.defaults.collectedCount end
    if type(FTA.sv.totalCount) ~= "number" then FTA.sv.totalCount = FTA.defaults.totalCount end

    if type(FTA.sv.lastVersion) ~= "string" then FTA.sv.lastVersion = FTA.defaults.lastVersion end
    FTA.sv.nextVersion = FTA.version
end

function FTA.GetSettingsOptions()
	-- TODO: all options
    return SPFLibUtils.ConcatArrays(SPFLibUtils.GetDonationSettingsOptions("SpringPeaceDev"), { -- TODO: use FTA.name when separated
        {
            type = "checkbox",
            name = "Enable",
			tooltip = "Enable or disable furniture catalog.",
            default = FTA.defaults.enable,
            getFunc = function() return FTA.sv.enable end,
            setFunc = function(value) FTA.sv.enable = value end,
            width = "full",
        },
        {
			type = "dropdown",
			name = "Fresh Level Timing Unit",
			tooltip = "Choose timing unit to determine how long from the last scan will the data be considered as frash (green color).",
			default = FTA.defaults.freshLevelTimeUnit,
			choices = FTAResults.TimeUnit,
			choicesValues = FTAResults.TimeUnit,
			getFunc = function() return FTA.sv.freshLevelTimeUnit end,
			setFunc = function(v)
				FTA.sv.freshLevelTimeUnit = v
			end,
		},
        {
			type = "slider",
			name = "Fresh Level Timing Value",
			tooltip = "Choose timing value to determine how long from the last scan will the data be considered as frash (green color).",
			min = 1, max = 60, step = 1,
			default = FTA.defaults.freshLevelTimeValue,
			getFunc = function() return FTA.sv.freshLevelTimeValue end,
			setFunc = function(v)
				FTA.sv.freshLevelTimeValue = v
			end,
			width = "full",
		},
        {
			type = "dropdown",
			name = "Recent Level Timing Unit",
			tooltip = "Choose timing unit to determine how long from the last scan will the data be considered as recent (yellow color).",
			default = FTA.defaults.recentLevelTimeUnit,
			choices = FTAResults.TimeUnit,
			choicesValues = FTAResults.TimeUnit,
			getFunc = function() return FTA.sv.recentLevelTimeUnit end,
			setFunc = function(v)
				FTA.sv.recentLevelTimeUnit = v
			end,
		},
        {
			type = "slider",
			name = "Recent Level Timing Value",
			tooltip = "Choose timing value to determine how long from the last scan will the data be considered as recent (yellow color).",
			min = 1, max = 60, step = 1,
			default = FTA.defaults.recentLevelTimeValue,
			getFunc = function() return FTA.sv.recentLevelTimeValue end,
			setFunc = function(v)
				FTA.sv.recentLevelTimeValue = v
			end,
			width = "full",
		},
        {
            type = "checkbox",
            name = "Show uncollected items only",
            tooltip = "Main menu view defaults to uncollected items only. If enabled, the custom FTA screen opens with hidden collected items. If disabled, it opens with collected items included.",
            default = FTA.defaults.showUncollectedItemsOnly,
            getFunc = function() return FTA.sv.showUncollectedItemsOnly end,
            setFunc = function(value) FTA.sv.showUncollectedItemsOnly = value end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Rebuild on demand only",
            tooltip = "If enabled, the results will be rebuild on demand only or when it is necessery (first time, version change). Button for rebuild is below these options and bellow filters in the catalog.",
            default = FTA.defaults.rebuildOnDemandOnly,
            getFunc = function() return FTA.sv.rebuildOnDemandOnly end,
            setFunc = function(value) FTA.sv.rebuildOnDemandOnly = value end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Enable page rotation",
            tooltip = "If enabled, it is possible to go from first page to last page and vice versa.",
            default = FTA.defaults.enablePageRotation,
            getFunc = function() return FTA.sv.enablePageRotation end,
            setFunc = function(value) FTA.sv.enablePageRotation = value end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show icons",
            tooltip = "If enabled, icons will be visible. Switch off when you hit ESOUI addons limitation.",
            default = FTA.defaults.showIcons,
            getFunc = function() return FTA.sv.showIcons end,
            setFunc = function(value) FTA.sv.showIcons = value end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Debug chat output",
            default = FTA.defaults.debug,
            getFunc = function() return FTA.sv.debug end,
            setFunc = function(value) FTA.sv.debug = value end,
            width = "full",
        },
        {
            type = "button",
            name = "Rebuild saved results",
            buttonText = "Rebuild",
            func = function()
                FTAResults.Build(true)
            end,
            width = "half",
        },
    })
end

function FTA.RegisterSettings()
    if FTA.state.settingsRegistered then return end
    FTA.state.settingsRegistered = true

    local panelData = {
        type = "panel",
        name = FTA.name,
        displayName = FTA.displayName,
        author = "SpringPeace2575",
        version = FTA.version,
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local options = FTA.GetSettingsOptions()

    SPFLibSettings.RegisterSettingsPanel(FTA.settingsPanelId, panelData, options, FTA.defaults, FTA.sv)
end

function FTA.RegisterMenu()
    if FTA.state.menuRegistered then return end
    FTA.state.menuRegistered = true

    local menuData = {
        name = function() return FTA.displayName end,
        icon = "EsoUI/Art/Crafting/Gamepad/gp_crafting_menuIcon_furnishings.dds",
        scene = FTAGui.state.menuSceneName,
    }

    SPFLibMainMenu.AddMainMenuEntry(menuData, SPFLibMainMenu.GetActivityFinderIndex())
end

function FTA.RefreshFull()
    SPFLibSettings.RefreshSettings()
    FTAGui.RefreshAll()
end

local function OnPlayerActivated(_, ...)
    zo_callLater(function() FTAResults.RegisterFurniture() end, 3000)
end

local function OnInventorySlotUpdate(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, inventoryUpdateReason, stackCountChange)
    FTAResults.InvalidateInventory(bagId)
    FTAResults.RequestStateRefresh()
end

local function OnHousingFurnitureChange(eventId, furnitureId, collectibleId)
    FTAResults.InvalidateCurrentHouseInventory()
    FTAResults.RequestStateRefresh()
end

function FTA.RegisterEvents()
    local eventNamespace = FTA.name .. "_Results"
    EVENT_MANAGER:RegisterForEvent(eventNamespace, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    EVENT_MANAGER:RegisterForEvent(eventNamespace, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventorySlotUpdate)
    EVENT_MANAGER:RegisterForEvent(eventNamespace, EVENT_HOUSING_FURNITURE_PLACED, OnHousingFurnitureChange)
    EVENT_MANAGER:RegisterForEvent(eventNamespace, EVENT_HOUSING_FURNITURE_REMOVED, OnHousingFurnitureChange)
end

function FTA.Initialize(savedVariables, dev)
    if dev == true then
        FTA.sv = savedVariables
        if not FTA.sv then
            d("[FTA] SavedVars unavilable")
            return
        end
    else
        FTA.sv = ZO_SavedVars:NewAccountWide(FTA.savedVarsName, FTA.savedVarsVersion, nil, FTA.defaults, GetWorldName())
    end

    FTA.InitializeSavedVars()

    zo_callLater(function()
        FTAResults.Initialize(FTA.sv, FTA.RefreshFull)
        FTA.RegisterSettings()
    end, 1000)

    FTAGui.Initialize(FTA.sv, FTAResults)
    FTA.RegisterMenu()
    FTA.RegisterEvents()

    d("[FTA] Initialized")
end

function FTA.Activate()

end

function FTA.OnAddOnLoaded(eventCode, addonName)
	if addonName ~= FTA.name then return end

	EVENT_MANAGER:UnregisterForEvent(FTA.name, EVENT_ADD_ON_LOADED)

	FTA.Initialize({}, false)
    FTA.Activate()
end
