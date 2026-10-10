--[[------------------------------------------------------------------------------------------------
Title:          Settings
Author:         Static_Recharge
Description:    Creates and controls the settings menu and related saved variables.
------------------------------------------------------------------------------------------------]]--


--[[------------------------------------------------------------------------------------------------
Libraries and Aliases
------------------------------------------------------------------------------------------------]]--
local LAM2 = LibAddonMenu2
local CM = CALLBACK_MANAGER
local SM = SCENE_MANAGER
local EM = EVENT_MANAGER


--[[------------------------------------------------------------------------------------------------
Settings Object Initialization
Settings    													            - Parent object containing all functions, tables, variables, constants and other data managers.
├─ :IsInitialized()                               - Returns true if the object has been successfully initialized.
├─ :CreateSettingsPanel()													- Creates and registers the settings panel with LibAddonMenu.
├─ :Update()                											- Updates the settings panel in LibAddonMenu.
├─ :Changed()               							- Fired when the player first loads in after a settings reset is forced.
└─ :GetParent()                                   - Returns the parent object of this object for reference to parent variables.
------------------------------------------------------------------------------------------------]]--
local Settings = {}


--[[------------------------------------------------------------------------------------------------
Settings:Initialize(Parent)
Inputs:				Parent 															- The parent object containing other required information.  
Outputs:			None
Description:	Initializes all of the variables and tables.
------------------------------------------------------------------------------------------------]]--
function Settings:Initialize(Parent)
  self.Parent = Parent
  self.eventSpace = "SFISettings"

  self:CreateSettingsPanel()

  -- Event Registrations
	EM:RegisterForEvent(self.eventSpace, EVENT_PLAYER_ACTIVATED, function(...) self:Changed() end)

	self.initialized = true
end


--[[------------------------------------------------------------------------------------------------
Settings:IsInitialized()
Inputs:				None
Outputs:			initialized                         - bool for object initialized state
Description:	Returns true if the object has been successfully initialized.
------------------------------------------------------------------------------------------------]]--
function Settings:IsInitialized()
  return self.initialized
end


--[[------------------------------------------------------------------------------------------------
Settings:CreateSettingsPanel()
Inputs:				None  
Outputs:			None
Description:	Creates and registers the settings panel with LibAddonMenu.
------------------------------------------------------------------------------------------------]]--
function Settings:CreateSettingsPanel()
	local Parent = self:GetParent()
	local panelData = {
		type = "panel",
		name = "Static's Furnishing Improvements",
		displayName = "|c0086B3Static's Furnishing Improvements|r",
		author = Parent.author,
		--website = "https://www.esoui.com/downloads/info3836-StaticsRecruiter.html",
		feedback = "https://www.esoui.com/portal.php?&uid=6533",
		slashCommand = "/sfimenu",
		registerForRefresh = true,
		registerForDefaults = true,
		version = Parent.addonVersion,
	}

  local optionsData = {}
	local controls = {}
	local i = 0

  i = i + 1
  optionsData[i] = {
		type = "header",
		name = "Deposit and Retrieve",
	}

  i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Deposit Same from Inventory",
    getFunc = function() return Parent.SV.depositSameFromInventory end,
    setFunc = function(value) Parent.SV.depositSameFromInventory = value end,
    tooltip = "Enables and displays the Deposit Same button on the Furnishing Vault screen.",
    width = "full",
		default = Parent.Defaults.depositSameFromInventory,
	}

  i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Deposit Same from House",
    getFunc = function() return Parent.SV.depositSameFromHouse end,
    setFunc = function(value) Parent.SV.depositSameFromHouse = value end,
    tooltip = "Enables the Deposit Same from House hotkey and slash command.",
    width = "full",
		default = Parent.Defaults.depositSameFromHouse,
	}

  i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Show Retrieve To on Editor HUD",
    getFunc = function() return Parent.SV.showRetrieveToOnHUD end,
    setFunc = function(value) Parent.SV.showRetrieveToOnHUD = value Parent:OnPlayerActivated() end,
    tooltip = "Shows the Retrieve To menu on the editor HUD screne. If disabled, the Retrieve To menu will still be available in the editor cursor mode.",
    width = "full",
		default = Parent.Defaults.showRetrieveToOnHUD,
	}

  i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Crafting Stations to Furnishing Vault",
    getFunc = function() return Parent.SV.depositCraftingStations end,
    setFunc = function(value) Parent.SV.depositCraftingStations = value end,
    tooltip = "When enabled, retrieving crafting stations from a house automatically sends them to the furnishing vault.",
    width = "full",
		default = Parent.Defaults.depositCraftingStations,
	}

  i = i + 1
  optionsData[i] = {
		type = "header",
		name = "Queue |t100%:100%:esoui/art/buttons/info_up.dds|t",
    tooltip = "Inventory: |c0086B3Right click|r on furnishing item and select \"Add to Vault Queue\" to add an item.\n\nQueue Window: |c0086B3Right click|r on an item to remove it from the Queue.\n\nItems in the Queue will be automatically deposited to the |c0086B3Furnishing Vault|r on the next visit.",
	}

  i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Enabled",
    getFunc = function() return Parent.SV.queueEnabled end,
    setFunc = function(value) Parent.SV.queueEnabled = value end,
    tooltip = "If disabled the Queue module will be unloaded.",
    width = "full",
		default = Parent.Defaults.queueEnabled,
		requiresReload = true,
	}

  i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Show Queue After Adding",
    getFunc = function() return Parent.SV.queueShowAfterAdd end,
    setFunc = function(value) Parent.SV.queueShowAfterAdd = value end,
    tooltip = "When enabled, the Queue window will be shown when an item is added.",
    width = "full",
		default = Parent.Defaults.queueShowAfterAdd,
    disabled = function() return not Parent.SV.queueEnabled end,
	}

  i = i + 1
	optionsData[i] = {
    type = "button",
    name = "Show Queue",
    func = function() SM:ShowBaseScene() Parent.Queue:ShowWindow(true) end,
    width = "half",
    disabled = function() return not Parent.SV.queueEnabled end,
  }

  i = i + 1
	optionsData[i] = {
    type = "button",
    name = "Reset Position",
    func = function() Parent.Queue:ResetPosition() end,
    tooltip = "Resets the Queue window position.",
    width = "half",
    disabled = function() return not Parent.SV.queueEnabled end,
  }

	i = i + 1
  optionsData[i] = {
		type = "header",
		name = "Vault Stats |t100%:100%:esoui/art/buttons/info_up.dds|t",
    tooltip = "Shows varioius statistics to help keep the |c0086B3Furnishing Vault|r organized and optimized.",
	}

  i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Enabled",
    getFunc = function() return Parent.SV.vaultStatsEnabled end,
    setFunc = function(value) Parent.SV.vaultStatsEnabled = value end,
    tooltip = "If disabled the Queue module will be unloaded.",
    width = "full",
		default = Parent.Defaults.vaultStatsEnabled,
		requiresReload = true,
	}

  i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Automatically Show at Furniture Vault",
    getFunc = function() return Parent.SV.vaultAutoShow end,
    setFunc = function(value) Parent.SV.vaultAutoShow = value end,
    width = "full",
		default = Parent.Defaults.vaultAutoShow,
    disabled = function() return not Parent.SV.vaultStatsEnabled end,
	}

	i = i + 1
	optionsData[i] = {
    type = "button",
    name = "Show Vault Stats",
    func = function() SM:ShowBaseScene() Parent.VaultStats:ShowWindow(true) end,
    width = "half",
    disabled = function() return not Parent.SV.vaultStatsEnabled end,
  }

	i = i + 1
	optionsData[i] = {
    type = "button",
    name = "Reset Position",
    func = function() Parent.VaultStats:ResetPosition() end,
    tooltip = "Resets the Vault Stats window position.",
    width = "half",
    disabled = function() return not Parent.SV.vaultStatsEnabled end,
  }

  i = i + 1
  optionsData[i] = {
		type = "header",
		name = "Misc.",
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Chat Messages",
    getFunc = function() return Parent.SV.chatEnabled end,
    setFunc = function(value) Parent.SV.chatEnabled = value Parent.Chat:SetChatEnabled(value) end,
    tooltip = "Disables ALL chat messages from this add-on.",
    width = "half",
		default = Parent.Defaults.chatEnabled,
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Debugging Mode",
    getFunc = function() return Parent.SV.debugEnabled end,
    setFunc = function(value) Parent.SV.debugEnabled = value Parent.Chat:SetDebugEnabled(value) end,
    tooltip = "Turns on extra messages for the purposes of debugging. Not intended for normal use. Must have chat messages enabled.",
    width = "half",
		default = Parent.Defaults.debugEnabled,
		disabled = not Parent.SV.chatEnabled,
	}

	local function LAMPanelCreated(panel)
		if panel ~= Parent.LAMSettingsPanel then return end
		Parent.LAMReady = true
		Parent.Controls = {}
		self:Update()
	end

	local function LAMPanelOpened(panel)
		if panel ~= Parent.LAMSettingsPanel then return end
		self:Update()
	end

	Parent.LAMSettingsPanel = LAM2:RegisterAddonPanel(Parent.addonName .. "_LAM", panelData)
	CM:RegisterCallback("LAM-PanelControlsCreated", LAMPanelCreated)
	CM:RegisterCallback("LAM-PanelOpened", LAMPanelOpened)
	LAM2:RegisterOptionControls(Parent.addonName .. "_LAM", optionsData)
end


--[[------------------------------------------------------------------------------------------------
Settings:Update()
Inputs:				None
Outputs:			None
Description:	Updates the settings panel in LibAddonMenu.
------------------------------------------------------------------------------------------------]]--
function Settings:Update()
	local Parent = self:GetParent()
	if not Parent.LAMReady then return end
end


--[[------------------------------------------------------------------------------------------------
Settings:Changed()
Inputs:				None
Outputs:			None
Description:	Sends a message the the settings have been reset.
------------------------------------------------------------------------------------------------]]--
function Settings:Changed()
	local Parent = self:GetParent()
	if not Parent.SV.settingsChanged then return end
	Parent.SV.settingsChanged = false
	Parent.Chat:Msg("Settings have been reset, please ensure they are to your preference.")
end


--[[------------------------------------------------------------------------------------------------
Settings:GetParent()
Inputs:				None
Outputs:			Parent          										- The parent object of this object.
Description:	Returns the parent object of this object for reference to parent variables.
------------------------------------------------------------------------------------------------]]--
function Settings:GetParent()
  return self.Parent
end


--[[------------------------------------------------------------------------------------------------
Global template assignment
------------------------------------------------------------------------------------------------]]--
StaticsFurnishingImprovements.Settings = Settings