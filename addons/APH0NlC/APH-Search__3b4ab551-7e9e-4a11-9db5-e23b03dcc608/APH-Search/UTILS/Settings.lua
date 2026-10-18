--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local SS = APHSearchCore

local PANEL_ID = "APHSearchOptions"
local REQUIRED_LAM = 30
local REQUIRED_LHAS = 1
local panel

local WARN_TEMPLATES = {
	missing = SS.L("IS_NOT_INSTALLED_INSTALL_OR"),
	disabled = SS.L("IS_INSTALLED_BUT_SWITCHED_OFF_TURN"),
	old = SS.L("IS_THIS_NEEDS_UPDATE_IT_OR"),
}

function SS.CheckSettingsLibraries()
	local lam_version, lam_enabled = LibAPH.CheckLibraryVersion("LibAddonMenu-2.0")
	local alerts = {}

	local lam_alert = LibAPH.BuildLibraryWarning(WARN_TEMPLATES, "LibAddonMenu", "LAM",
		lam_version, lam_enabled, REQUIRED_LAM, SS.L("THE_SETTINGS_PANEL_WILL_NOT_OPEN"))
	if lam_alert then alerts[#alerts + 1] = lam_alert end

	if IsConsoleUI() then
		local lhas_version, lhas_enabled = LibAPH.CheckLibraryVersion("LibHarvensAddonSettings")
		local lhas_alert = LibAPH.BuildLibraryWarning(WARN_TEMPLATES, "LibHarvensAddonSettings", "LHAS",
			lhas_version, lhas_enabled, REQUIRED_LHAS, SS.L("THE_SETTINGS_PANEL_WILL_NOT_OPEN_2"))
		if lhas_alert then alerts[#alerts + 1] = lhas_alert end
	end

	return alerts
end

function SS.WarnAboutSettingsLibraries()
	local alerts = SS.CheckSettingsLibraries()
	if #alerts == 0 then return false end
	if SS.saved.warned_about_libraries then return false end

	SS.saved.warned_about_libraries = true
	for _, alert in ipairs(alerts) do SS.Print(alert, true) end
	return true
end

local function ScopeControls(data)
	for _, scope in ipairs(SS.GetAllScopes()) do
		data[#data + 1] = {
			type = "checkbox",
			name = SS.ScopeName(scope),
			getFunc = function() return SS.IsScopeEnabled(scope) end,
			setFunc = function(value)
				SS.SetScopeEnabled(scope, value)
				SS.RefreshScope()
			end,
			default = SS.DefaultScopeOn(scope),
			width = "half",
		}
	end
end

function SS.HowItWorks()
	if IsInGamepadPreferredMode() then
		return SS.L("HOW_IT_WORKS_CONTROLLER")
	end
	local key = ZO_Keybindings_GetHighestPriorityBindingStringFromAction("APHSEARCH_TOGGLE",
		KEYBIND_TEXT_OPTIONS_ABBREVIATED_NAME, KEYBIND_TEXTURE_OPTIONS_EMBED_MARKUP)
	local opener = key and string.format(SS.L("HOW_IT_WORKS_OPEN_KEY"), key) or SS.L("HOW_IT_WORKS_OPEN_NO_KEY")
	return opener .. SS.L("HOW_IT_WORKS_KEYBOARD_REST")
end

local KEYBOARD_ONLY = {
	[SS.L("BAR_OPACITY")] = true, [SS.L("RESET_BAR_POSITION")] = true,
}
local CONSOLE_ONLY = { [SS.L("HOLD_LEFT_TRIGGER")] = true }
local HOW_IT_WORKS = "APHSearchHowItWorks"

function SS.DropOtherPlatformSettings(data)
	local other = IsConsoleUI() and KEYBOARD_ONLY or CONSOLE_ONLY
	for index = #data, 1, -1 do
		local name = data[index].name
		if type(name) == "string" and other[LibAPH.StripColors(name)] then table.remove(data, index) end
	end
	return data
end

function SS.ShowKeyFrames(created)
	if IsConsoleUI() or created ~= panel then return false end
	local control = _G[HOW_IT_WORKS]
	local desc = control and control.desc
	if not desc or desc.aphsearch_key_frames then return false end
	desc.aphsearch_key_frames = true
	desc:SetHandler("OnTextChanged", ZO_SmallKeyMarkupLabel_OnTextChanged)
	desc:SetHandler("OnUserAreaCreated", ZO_SmallKeyMarkupLabel_OnNewUserAreaCreated)
	desc:SetText(SS.HowItWorks())
	return true
end

function SS.BuildSettingsPanel()
	local lam = LibAddonMenu2
	if not lam or type(lam.RegisterAddonPanel) ~= "function" then return false end
	if panel then return true end

	local header = {
		type = "panel",
		name = "|c9CD04CAPH-Search|r",
		displayName = "|c00FFFFAPH-Search|r",
		author = "|ca500f3A|r|cb400e6P|r|cc300daH|r|cd200cdO|r|ce100c1NlC|r",
		version = SS.VERSION,
		registerForRefresh = true,
		translation = "https://www.esoui.com/portal.php?id=360&a=featurereq",
		donation = "https://buymeacoffee.com/aph0nlc",
	}

	local data = {
		{
			type = "description",
			title = SS.L("HOW_IT_WORKS"),
			text = function() return SS.HowItWorks() end,
			reference = HOW_IT_WORKS,
		},
		{
			type = "checkbox",
			name = SS.L("MATCH_TOOLTIPS_AND_DESCRIPTIONS"),
			getFunc = function() return SS.saved.match_tooltips end,
			setFunc = function(value) SS.saved.match_tooltips = value end,
			default = SS.DEFAULTS.match_tooltips,
		},
		{
			type = "checkbox",
			name = SS.L("OFFER_TO_TRAVEL_FROM_THE_MAP"),
			getFunc = function() return SS.saved.wayshrine_travel_prompt end,
			setFunc = function(value) SS.saved.wayshrine_travel_prompt = value end,
			default = SS.DEFAULTS.wayshrine_travel_prompt,
		},
		{
			type = "checkbox",
			name = SS.L("CHAT_MESSAGES"),
			getFunc = function() return SS.saved.chat_messages end,
			setFunc = function(value) SS.saved.chat_messages = value end,
			default = SS.DEFAULTS.chat_messages,
		},
		{
			type = "checkbox",
			name = SS.L("HOLD_LEFT_TRIGGER"),
			getFunc = function() return SS.saved.hold_trigger_search end,
			setFunc = function(value) SS.saved.hold_trigger_search = value end,
			default = SS.DEFAULTS.hold_trigger_search,
		},
		{
			type = "checkbox",
			name = SS.L("PREFER_INSTANT_RESULTS"),
			getFunc = function() return SS.saved.instant_results end,
			setFunc = function(value) SS.saved.instant_results = value end,
			default = SS.DEFAULTS.instant_results,
		},
		{
			type = "slider",
			name = SS.L("BAR_OPACITY"),
			min = 0,
			max = 100,
			step = 5,
			getFunc = function() return math.floor((SS.saved.bar_opacity or 1) * 100 + 0.5) end,
			setFunc = function(value) SS.SetBarOpacity(value / 100) end,
			default = math.floor(SS.DEFAULTS.bar_opacity * 100 + 0.5),
		},
		{
			type = "button",
			name = "|cFF0000" .. SS.L("RESET_BAR_POSITION") .. "|r",
			warning = SS.L("WARN_RESET_BAR_POSITION"),
			isDangerous = true,
			func = function()
				SS.ResetBarPosition()
				SS.Print(SS.L("THE_SEARCH_BAR_IS_BACK_WHERE"), true)
			end,
			width = "half",
		},
		{
			type = "button",
			name = "|cFF0000" .. SS.L("RESET_TO_DEFAULTS") .. "|r",
			warning = SS.L("WARN_RESET_TO_DEFAULTS"),
			isDangerous = true,
			func = function()
				SS.ResetToDefaults()
				SS.RefreshScope()
				SS.Print(SS.L("SETTINGS_ARE_BACK_TO_THEIR_DEFAULTS"), true)
			end,
			width = "half",
		},
		{
			type = "submenu",
			name = SS.L("WHAT_GETS_SEARCHED"),
			controls = (function()
				local controls = {}
				ScopeControls(controls)
				return controls
			end)(),
		},
	}

	SS.DropOtherPlatformSettings(data)

	panel = lam:RegisterAddonPanel(PANEL_ID, header)
	lam:RegisterOptionControls(PANEL_ID, data)
	if not IsConsoleUI() then CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", SS.ShowKeyFrames) end
	SS.WarnAboutSettingsLibraries()
	return true
end
