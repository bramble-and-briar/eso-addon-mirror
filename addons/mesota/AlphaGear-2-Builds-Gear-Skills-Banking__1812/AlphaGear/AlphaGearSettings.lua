
-- Constants for options

AG_OPTION_SHOW_MAIN_BUTTON = 1
AG_OPTION_SHOW_SET_BUTTONS = 2
AG_OPTION_SHOW_GEAR_ICON = 3
AG_OPTION_SHOW_REPAIR_COST = 4
AG_OPTION_SHOW_WEAPON_ICON = 5
AG_OPTION_SHOW_CHANGE_NOTIFICATION = 6
AG_OPTION_SHOW_ACITVE_SET = 7
AG_OPTION_MARK_SET_ITEMS_IN_BAG = 8
AG_OPTION_SHOW_ITEM_CONDITION = 9
AG_OPTION_SHOW_ITEM_QUALITY = 10
AG_OPTION_CLOSE_WINDOW_ON_MOVE = 11
AG_OPTION_LOCK_UI = 12
AG_OPTION_AUTO_CHARGE_WEAPONS = 13
AG_OPTION_AUTO_REPAIR_AT_STORES = 14
AG_OPTION_SHOW_ITEM_LEVEL = 15
AG_OPTION_UNUSED = 16
AG_OPTION_LOAD_LAST_BUILD_OF_PROFILE = 17

-- the addon menu library
local LAM = LibAddonMenu2

-- Panel for quick access
local addOnPanel = {}

-- Getters and setters for options
function AG.isShowMainButton()
	return AG.account.option[AG_OPTION_SHOW_MAIN_BUTTON]
end

function AG.setShowMainButton(value)
	AG.account.option[AG_OPTION_SHOW_MAIN_BUTTON] = value
	AG.setupMainButton()
end
--
function AG.isLoadLastBuildOfProfile()
	return AG.account.option[AG_OPTION_LOAD_LAST_BUILD_OF_PROFILE]
end

function AG.setLoadLastBuildOfProfile(value)
	AG.account.option[AG_OPTION_LOAD_LAST_BUILD_OF_PROFILE] = value
end
--
function AG.isShowSetButtons()
	return AG.account.option[AG_OPTION_SHOW_SET_BUTTONS]
end

function AG.setShowSetButtons(value)
	AG.account.option[AG_OPTION_SHOW_SET_BUTTONS] = value
	AG.setupSetButtons()
end
--
function AG.isShowGearIcon()
	return AG.account.option[AG_OPTION_SHOW_GEAR_ICON]
end

function AG.setShowGearIcon(value)
	AG.account.option[AG_OPTION_SHOW_GEAR_ICON] = value 
	AG.setupGearIcon()
end
--
function AG.isShowRepairCost()
	return AG.account.option[AG_OPTION_SHOW_REPAIR_COST]
end

function AG.setShowRepairCost(value)
	AG.account.option[AG_OPTION_SHOW_REPAIR_COST] = value
	AG.setupGearIcon()
end
--
function AG.isShowWeaponIcon()
	return AG.account.option[AG_OPTION_SHOW_WEAPON_ICON]
end

function AG.setShowWeaponIcon(value)
	AG.account.option[AG_OPTION_SHOW_WEAPON_ICON] = value 
	AG.setupWeaponIconsAndCharge()
end
--
function AG.isShowChangeNotification()
	return AG.account.option[AG_OPTION_SHOW_CHANGE_NOTIFICATION]
end

function AG.setShowChangeNotification(value)
	AG.account.option[AG_OPTION_SHOW_CHANGE_NOTIFICATION] = value

	if not value then
		AG.account.option[AG_OPTION_SHOW_ACITVE_SET] = false
	end

	AG.setupActiveSet()
end
--
function AG.isShowActiveSet()
	return AG.account.option[AG_OPTION_SHOW_ACITVE_SET]
end

function AG.setShowActiveSet(value)
	AG.account.option[AG_OPTION_SHOW_ACITVE_SET] = value

	if value then
		AG.account.option[AG_OPTION_SHOW_CHANGE_NOTIFICATION] = true
	end

	AG.setupActiveSet()
end
--
function AG.isMarkSetItemsInBag()
	return AG.account.option[AG_OPTION_MARK_SET_ITEMS_IN_BAG]
end

function AG.setMarkSetItemsInBag(value)
	AG.account.option[AG_OPTION_MARK_SET_ITEMS_IN_BAG] = value 
	AG.setupMarkSetItems()
end
--
function AG.isShowItemCondition()
	return AG.account.option[AG_OPTION_SHOW_ITEM_CONDITION]
end

function AG.setShowItemCondition(value)
	AG.account.option[AG_OPTION_SHOW_ITEM_CONDITION] = value 
	AG.setupItemCondition()
end
--
function AG.isShowItemQuality()
	return AG.account.option[AG_OPTION_SHOW_ITEM_QUALITY]
end

function AG.setShowItemQuality(value)
	AG.account.option[AG_OPTION_SHOW_ITEM_QUALITY] = value 
	AG.setupItemQuality()
end
--
function AG.isCloseWindowOnMove()
	return AG.account.option[AG_OPTION_CLOSE_WINDOW_ON_MOVE]
end

function AG.setCloseWindowOnMove(value)
	AG.account.option[AG_OPTION_CLOSE_WINDOW_ON_MOVE] = value 
	AG.setupAutoClose()
end
--
function AG.isLockUI()
	return AG.account.option[AG_OPTION_LOCK_UI]
end

function AG.setLockUI(value)
	AG.account.option[AG_OPTION_LOCK_UI] = value
	AG.setupLockUI()
end
--
function AG.isAutoChargeWeapons()
	return AG.account.option[AG_OPTION_AUTO_CHARGE_WEAPONS]
end

function AG.setAutoChargeWeapons(value)
	AG.account.option[AG_OPTION_AUTO_CHARGE_WEAPONS] = value 
	AG.setupWeaponIconsAndCharge()
end
--
function AG.isAutoRepairAtStores()
	return AG.account.option[AG_OPTION_AUTO_REPAIR_AT_STORES]
end

function AG.setAutoRepairAtStores(value)
	AG.account.option[AG_OPTION_AUTO_REPAIR_AT_STORES] = value 
	AG.setupAutoRepairAtStores()
end
--
function AG.getShowItemLevel()
	if AG.account.option[AG_OPTION_SHOW_ITEM_LEVEL] == nil then
		return AG.account_defaults.option[AG_OPTION_SHOW_ITEM_LEVEL]
	end
	
	return AG.account.option[AG_OPTION_SHOW_ITEM_LEVEL]
end

function AG.setShowItemLevel(value)
	AG.account.option[AG_OPTION_SHOW_ITEM_LEVEL] = value
	AG.setupShowItemLevel()
end

function AG.getShowItemLevelName()
	local index = AG.account.option[AG_OPTION_SHOW_ITEM_LEVEL]
	
	if index == nil then
		index = AG.account_defaults.option[AG_OPTION_SHOW_ITEM_LEVEL]
	end
	
	return AGLang.msg.ShowItemLevelChoices[index]
end

function AG.setShowItemLevelName(name)
	-- set to default in case of error
	AG.account.option[AG_OPTION_SHOW_ITEM_LEVEL] = AG.account_defaults.option[AG_OPTION_SHOW_ITEM_LEVEL]
	
	for index, label in pairs(AGLang.msg.ShowItemLevelChoices) do
		if name == label then
			AG.account.option[AG_OPTION_SHOW_ITEM_LEVEL] = index
		end
	end
	
	AG.setupShowItemLevel()
end

--
function AG.getNumberOfVisibleSetButtons()
	return AG.setdata.setamount
end

function AG.setNumberOfVisibleSetButtons(value)
	AG.setdata.setamount = value 
	AG.DrawSetButtonsUI()
end
--
function AG.onClickResetPositions()
	AG.ResetPositions()
end

--- Opens the settings page
function AG.ShowSettings()
	AG.HideMain()
	LAM:OpenToPanel(addOnPanel)
end



--- Creates the settings page
function AG:CreateSettingsPage()
	local OptMsg = AGLang.msg.Options
	local IntMsg = AGLang.msg.Integrations
	local L = AGLang.msg
	local defaults = AG.account_defaults.option
	local intDefaults = AG.account_defaults.Integrations
	local intOptions = AG.account.Integrations
	local plugins = AG.plugins

	local agOptionsPanel = 
	{
		type = "panel",
		name = self.displayname,
		author = self.author,
		version = self.version,
		registerForRefresh = true,
		registerForDefaults = true,
		slashCommand = "/alphagearoptions"
	}

	local agOptions = 
	{
		{
			type = "description",
			text = L.SettingsDesc,
		},
		
		{
			type = "header",
			name = L.SetsHeader,
		},
		{
			type = "checkbox",
			name = OptMsg[AG_OPTION_LOAD_LAST_BUILD_OF_PROFILE],
			getFunc = AG.isLoadLastBuildOfProfile,
			setFunc = AG.setLoadLastBuildOfProfile,
			default = defaults[AG_OPTION_LOAD_LAST_BUILD_OF_PROFILE] 
		},
		{
			type = "checkbox",
			name = OptMsg[AG_OPTION_SHOW_SET_BUTTONS],
			getFunc = AG.isShowSetButtons,
			setFunc = AG.setShowSetButtons,
			default = defaults[AG_OPTION_SHOW_SET_BUTTONS] 
		},
		{
			type = "slider",
			name = L.NumVisibleSetButtons,
			min = 0, max = 16, step = 1, 
			getFunc = AG.getNumberOfVisibleSetButtons,
			setFunc = AG.setNumberOfVisibleSetButtons,
			default = AG.setdata_defaults.setamount, 
		},
		
		{
			type = "checkbox",
			name = OptMsg[AG_OPTION_SHOW_CHANGE_NOTIFICATION],
			getFunc = AG.isShowChangeNotification,
			setFunc = AG.setShowChangeNotification,
			default = defaults[AG_OPTION_SHOW_CHANGE_NOTIFICATION] 
		},
		{
			type = "checkbox",
			name = OptMsg[AG_OPTION_SHOW_ACITVE_SET],
			getFunc = AG.isShowActiveSet,
			setFunc = AG.setShowActiveSet,
			default = defaults[AG_OPTION_SHOW_ACITVE_SET] 
		},
		{
			type = "checkbox",
			name = OptMsg[AG_OPTION_MARK_SET_ITEMS_IN_BAG],
			getFunc = AG.isMarkSetItemsInBag,
			setFunc = AG.setMarkSetItemsInBag,
			default = defaults[AG_OPTION_MARK_SET_ITEMS_IN_BAG] 
		},
		{
			type = "header",
			name = L.GearHeader,
		},
		{
			type = "checkbox",
			name = OptMsg[AG_OPTION_SHOW_GEAR_ICON],
			getFunc = AG.isShowGearIcon,
			setFunc = AG.setShowGearIcon,
			default = defaults[AG_OPTION_SHOW_GEAR_ICON] 
		},
		{
			type = "checkbox",
			name = OptMsg[AG_OPTION_SHOW_REPAIR_COST],
			getFunc = AG.isShowRepairCost,
			setFunc = AG.setShowRepairCost,
			default = defaults[AG_OPTION_SHOW_REPAIR_COST] 
		},
		{
			type = "checkbox",
			name = OptMsg[AG_OPTION_AUTO_REPAIR_AT_STORES],
			getFunc = AG.isAutoRepairAtStores,
			setFunc = AG.setAutoRepairAtStores,
			default = defaults[AG_OPTION_AUTO_REPAIR_AT_STORES]  
		},
		{
			type = "header",
			name = L.WeaponsHeader,
		},
		{
			type = "checkbox",
			name = OptMsg[AG_OPTION_SHOW_WEAPON_ICON],
			getFunc = AG.isShowWeaponIcon,
			setFunc = AG.setShowWeaponIcon,
			default = defaults[AG_OPTION_SHOW_WEAPON_ICON] 
		},
		{
			type = "checkbox",
			name = OptMsg[AG_OPTION_AUTO_CHARGE_WEAPONS],
			getFunc = AG.isAutoChargeWeapons,
			setFunc = AG.setAutoChargeWeapons,
			default = defaults[AG_OPTION_AUTO_CHARGE_WEAPONS] 
		},
		{
			type = "header",
			name = L.EquipmentHeader,
		},
		{
			type = "checkbox",
			name = OptMsg[AG_OPTION_SHOW_ITEM_CONDITION],
			getFunc = AG.isShowItemCondition,
			setFunc = AG.setShowItemCondition,
			default = defaults[AG_OPTION_SHOW_ITEM_CONDITION] 
		},
		{
			type = "checkbox",
			name = OptMsg[AG_OPTION_SHOW_ITEM_QUALITY],
			getFunc = AG.isShowItemQuality,
			setFunc = AG.setShowItemQuality,
			default = defaults[AG_OPTION_SHOW_ITEM_QUALITY] 
		},
		{
			type = "dropdown", 
			name = OptMsg[AG_OPTION_SHOW_ITEM_LEVEL],
			choices = L.ShowItemLevelChoices,
			getFunc = AG.getShowItemLevelName,
			setFunc = AG.setShowItemLevelName,
			default = L.ShowItemLevelChoices[defaults[AG_OPTION_SHOW_ITEM_LEVEL]], 
		},		
		{
			type = "header",
			name = L.UIHeader,
		},
		{
			type = "checkbox",
			name = OptMsg[AG_OPTION_SHOW_MAIN_BUTTON], 
			getFunc = AG.isShowMainButton,
			setFunc = AG.setShowMainButton,
			default = defaults[AG_OPTION_SHOW_MAIN_BUTTON] 
		},
		{
			type = "checkbox",
			name = OptMsg[AG_OPTION_CLOSE_WINDOW_ON_MOVE],
			getFunc = AG.isCloseWindowOnMove,
			setFunc = AG.setCloseWindowOnMove,
			default = defaults[AG_OPTION_CLOSE_WINDOW_ON_MOVE] 
		},
		{
			type = "checkbox",
			name = OptMsg[AG_OPTION_LOCK_UI],
			getFunc = AG.isLockUI,
			setFunc = AG.setLockUI,
			default = defaults[AG_OPTION_LOCK_UI] 
		},
		{
			type = "button",
			name = L.ResetPositions,
			func = AG.onClickResetPositions,
			width = "half",
		},

	}

	local agIntegrationsPanel = 
	{
		type = "panel",
		name = self.displayname..' Integrations',
		author = self.author,
		version = self.version,
		registerForRefresh = true,
		registerForDefaults = true,
	}


	local agIntegrations = {
		{
			type = "submenu",
			name = IntMsg.Inventory.Title,
			controls = {
				{
					type = "checkbox",
					name = IntMsg.Inventory.UseFCOIS,
					getFunc = function() return intOptions.Inventory.UseFCOIS end,
					setFunc = function(value) intOptions.Inventory.UseFCOIS = value end,
					default = intDefaults.Inventory.UseFCOIS,
					disabled = function() return not plugins.FCOIS.isAddonReady() end
				},
			},
		},

		{
			type = "submenu",
			name = IntMsg.Styling.Title,
			controls = {
				{
					type = "checkbox",
					name = IntMsg.Styling.UseAlphaStyle,
					getFunc = function() return intOptions.Styling.UseAlphaStyle end,
					setFunc = function(value) intOptions.Styling.UseAlphaStyle = value end,
					default = intDefaults.Styling.UseAlphaStyle,
					disabled = function() return not plugins.AlphaStyle.isAddonReady() end
				},
			},
		},

		{
			type = "submenu",
			name = IntMsg.Champion.Title,
			controls = {
				{
					type = "checkbox",
					name = IntMsg.Champion.UseCPSlots,
					getFunc = function() return intOptions.Champion.UseCPSlots end,
					setFunc = function(value) intOptions.Champion.UseCPSlots = value end,
					default = intDefaults.Champion.UseCPSlots,
					disabled = function() return not plugins.CPSlots.isAddonReady() end
				},
				{
					type = "checkbox",
					name = "Use Dynamic CP",
					tooltip = "Allows Dynamic CP slottable sets to be equipped alongside builds, via the Advanced Options dialog. Requires Dynamic CP 3.4.0+",
					getFunc = function() return intOptions.Champion.UseDynamicCP end,
					setFunc = function(value) intOptions.Champion.UseDynamicCP = value end,
					default = intDefaults.Champion.UseDynamicCP,
					disabled = function() return not plugins.DynamicCP.isAddonReady() end
				},
				{
					type = "checkbox",
					name = "    Print slottable sets names",
					tooltip = "When equipping slottable sets, prints to chat what sets are being slotted. If the slottable set does not exist, an error message will be printed regardless.",
					getFunc = function() return intOptions.Champion.DCPPrintNames end,
					setFunc = function(value) intOptions.Champion.DCPPrintNames = value end,
					default = intDefaults.Champion.DCPPrintNames,
					disabled = function() return not plugins.DynamicCP.isAddonReady() or not intOptions.Champion.UseDynamicCP end
				},
				{
					type = "checkbox",
					name = "    Print individual star names",
					tooltip = "When equipping slottable sets, prints to chat what slottable stars are being slotted and which ones are already slotted. If there aren't enough points allocated to a star, an error message will be printed regardless.",
					getFunc = function() return intOptions.Champion.DCPPrintSlottables end,
					setFunc = function(value) intOptions.Champion.DCPPrintSlottables = value end,
					default = intDefaults.Champion.DCPPrintSlottables,
					disabled = function() return not plugins.DynamicCP.isAddonReady() or not intOptions.Champion.UseDynamicCP end
				},
			},
		},


	}


	addOnPanel = LAM:RegisterAddonPanel(self.name.."_LAM", agOptionsPanel)
	LAM:RegisterOptionControls(self.name.."_LAM", agOptions)

	LAM:RegisterAddonPanel(self.name.."Integrations_LAM", agIntegrationsPanel)
	LAM:RegisterOptionControls(self.name.."Integrations_LAM", agIntegrations)
end

