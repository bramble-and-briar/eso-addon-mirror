--[[------------------------------------------------------------------------------------------------
Title: Settings
Author: Static_Recharge
Description: Creates and controls the settings menu and related saved variables.
------------------------------------------------------------------------------------------------]]--

--[[------------------------------------------------------------------------------------------------
Libraries and Aliases
------------------------------------------------------------------------------------------------]]--
local LAM2 = LibAddonMenu2
local CM = CALLBACK_MANAGER
local EM = EVENT_MANAGER
local SLO = StaticsLetterOpener

--[[------------------------------------------------------------------------------------------------
Settings Initialization
------------------------------------------------------------------------------------------------]]--
local Settings = {}

--[[------------------------------------------------------------------------------------------------
Settings.Initialize()
Inputs: None
Outputs: None
Description: Initializes all of the variables and tables.
------------------------------------------------------------------------------------------------]]--
function Settings.Initialize()
	Settings.eventSpace = "SLOSettings"

	Settings.CreateSettingsPanel()

	-- Event Registrations
	EM:RegisterForEvent(Settings.eventSpace, EVENT_PLAYER_ACTIVATED, Settings.Changed)

	Settings.initialized = true
end

--[[------------------------------------------------------------------------------------------------
Settings.IsInitialized()
Inputs: None
Outputs: initialized - bool for initialized state
Description: Returns true if Settings has been successfully initialized.
------------------------------------------------------------------------------------------------]]--
function Settings.IsInitialized()
	return Settings.initialized
end

--[[------------------------------------------------------------------------------------------------
Settings.CreateSettingsPanel()
Inputs: None
Outputs: None
Description: Creates and registers the settings panel with LibAddonMenu.
------------------------------------------------------------------------------------------------]]--
function Settings.CreateSettingsPanel()
	local panelData = {
		type = "panel",
		name = "Static's Letter Opener",
		displayName = "|cFFFFFFStatic's Letter Opener|r",
		author = SLO.author,
		--website = "https://www.esoui.com/downloads/info3836-StaticsRecruiter.html",
		feedback = "https://esoui.com",
		slashCommand = "/slomenu",
		registerForRefresh = true,
		registerForDefaults = true,
		version = SLO.addonVersion,
	}

	local optionsData = {}
	local i = 1

	optionsData[i] = {
		type = "header",
		name = "Containers",
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
		name = "Open Surveys",
		getFunc = function() return SLO.SV.surveys end,
		setFunc = function(value) SLO.SV.surveys = value end,
		width = "full",
		default = SLO.Defaults.surveys,
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
		name = "Open Master Writs",
		getFunc = function() return SLO.SV.masterWrits end,
		setFunc = function(value) SLO.SV.masterWrits = value end,
		width = "full",
		default = SLO.Defaults.masterWrits,
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
		name = "Open Maps",
		getFunc = function() return SLO.SV.maps end,
		setFunc = function(value) SLO.SV.maps = value end,
		width = "full",
		default = SLO.Defaults.maps,
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
		name = "Open All",
		getFunc = function() return SLO.SV.openAll end,
		setFunc = function(value) SLO.SV.openAll = value end,
		tooltip = "If enabled, when one envelope of a particular type is opened, the add-on will attempt to open the whole stack.",
		width = "full",
		default = SLO.Defaults.openAll,
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
		getFunc = function() return SLO.SV.chatEnabled end,
		setFunc = function(value)
			SLO.SV.chatEnabled = value
			SLO.Chat:SetChatEnabled(value)
		end,
		tooltip = "Disables ALL chat messages from this add-on.",
		width = "half",
		default = SLO.Defaults.chatEnabled,
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
		name = "Debugging Mode",
		getFunc = function() return SLO.SV.debugEnabled end,
		setFunc = function(value)
			SLO.SV.debugEnabled = value
			SLO.Chat:SetDebugEnabled(value)
		end,
		tooltip = "Turns on extra messages for the purposes of debugging. Not intended for normal use. Must have chat messages enabled.",
		width = "half",
		default = SLO.Defaults.debugEnabled,
		disabled = function() return not SLO.SV.chatEnabled end,
	}

	local function LAMPanelCreated(panel)
		if panel ~= SLO.LAMSettingsPanel then return end
		SLO.LAMReady = true
		SLO.Controls = {}
		Settings.Update()
	end

	local function LAMPanelOpened(panel)
		if panel ~= SLO.LAMSettingsPanel then return end
		Settings.Update()
	end

	SLO.LAMSettingsPanel = LAM2:RegisterAddonPanel(SLO.addonName .. "_LAM", panelData)
	CM:RegisterCallback("LAM-PanelControlsCreated", LAMPanelCreated)
	CM:RegisterCallback("LAM-PanelOpened", LAMPanelOpened)
	LAM2:RegisterOptionControls(SLO.addonName .. "_LAM", optionsData)
end

--[[------------------------------------------------------------------------------------------------
Settings.Update()
Inputs: None
Outputs: None
Description: Updates the settings panel in LibAddonMenu.
------------------------------------------------------------------------------------------------]]--
function Settings.Update()
	if not SLO.LAMReady then return end
end

--[[------------------------------------------------------------------------------------------------
Settings.Changed()
Inputs: None
Outputs: None
Description: Sends a message that the settings have been reset.
------------------------------------------------------------------------------------------------]]--
function Settings.Changed()
	if not SLO.SV.settingsChanged then return end
	SLO.SV.settingsChanged = false
	SLO.Chat:Msg("Settings have been reset, please ensure they are to your preference.")
end

--[[------------------------------------------------------------------------------------------------
Global template assignment
------------------------------------------------------------------------------------------------]]--
StaticsLetterOpener.Settings = Settings
