AUI.Settings.Questtracker = {}

local g_LAM = LibAddonMenu2
local g_isInit = false
local g_isPreviewShowing = false

AUI_QUESTTRACKER_WIDTH_MIN_SIZE = 250
AUI_QUESTTRACKER_WIDTH_MAX_SIZE = 600
AUI_QUESTTRACKER_MAX_HEIGHT_MIN_SIZE = 151
AUI_QUESTTRACKER_MAX_HEIGHT_MAX_SIZE = 800
AUI_QUESTTRACKER_MIN_FONT_SIZE = 15
AUI_QUESTTRACKER_MAX_FONT_SIZE = 36

local function GetDefaultSettings()
	local lang = GetCVar("Language.2")
	local defaultTimePrecisionTwelfeHour = true

	if lang == "de" or lang == "fr" then
		defaultTimePrecisionTwelfeHour = false
	end

	local defaultSettings =
	{
		enable = true,
		width = 278,
		height= 698, 
		anchor = 
		{
			point = 9,
			relativePoint = 0,
			offsetX = 0,
			offsetY = 324
		},
		lock_window = false,
		showBackground = false,
		showTime = true,
		useTimePrecisionTwelfeHour = defaultTimePrecisionTwelfeHour,
		isExpandedConditions = false,
		expandMode = 0,
		font_size = 18,
		font_art = "esoui/common/fonts/myingheiprc-w5.slug",
	}

	return defaultSettings
end

local function CreateOptions()
	local optionsTable = {
		{
			type = "header",
			name = AUI_TXT_COLOR_HEADER:Colorize(AUI.L10n.GetString("general"))
		},
		{
			type = "checkbox",
			name = AUI.L10n.GetString("acount_wide"),
			tooltip = AUI.L10n.GetString("acount_wide_tooltip"),
			getFunc = function() return AUI.Settings.MainMenu.modul_quest_tacker_account_wide end,
			setFunc = function(value)
				if value ~= nil then
					if value ~= AUI.Settings.MainMenu.modul_quest_tacker_account_wide then
						AUI.Settings.MainMenu.modul_quest_tacker_account_wide = value
						ReloadUI()
					else
						AUI.Settings.MainMenu.modul_quest_tacker_account_wide = value
					end
				end					
			end,
			default = true,
			width = "full",
			warning = AUI.L10n.GetString("reloadui_warning_tooltip"),
		},
		{
			type = "checkbox",
			name = AUI.L10n.GetString("lock_window"),
			tooltip = AUI.L10n.GetString("lock_window_tooltip"),
			getFunc = function() return AUI.Settings.Questtracker.lock_window end,
			setFunc = function(value)
				if value ~= nil then
					AUI.Settings.Questtracker.lock_window = value
				end
			end,
			default = GetDefaultSettings().lock_window,
			width = "full",
		},				
		{
			type = "checkbox",
			name = AUI.L10n.GetString("preview"),
			tooltip = AUI.L10n.GetString("preview_tooltip"),
			getFunc = function() return g_isPreviewShowing end,
			setFunc = function(value)
				if value ~= nil then
					if value == true then
						AUI.Questtracker.Show()
					else
						AUI.Questtracker.Hide()
					end
					
					g_isPreviewShowing = value
				end
			end,
			default = g_isPreviewShowing,
			width = "full",
		},	
		{
			type = "header",
			name = AUI_TXT_COLOR_HEADER:Colorize(AUI.L10n.GetString("quest_tracker_module_name"))
		},
		{
			type = "slider",
			name = AUI.L10n.GetString("width"),
			tooltip = AUI.L10n.GetString("width_tooltip"),
			min = AUI_QUESTTRACKER_WIDTH_MIN_SIZE,
			max = AUI_QUESTTRACKER_WIDTH_MAX_SIZE,
			step = 1,
			getFunc = function() return AUI.Settings.Questtracker.width end,
			setFunc = function(value) 
				if value ~= nil then
					AUI.Settings.Questtracker.width = value						
					AUI.Questtracker.UpdateUI()
				end
			end,
			default = GetDefaultSettings().width,
			width = "half",			
		},	
		{
			type = "slider",
			name = AUI.L10n.GetString("height"),
			tooltip = AUI.L10n.GetString("height_tooltip"),
			min = AUI_QUESTTRACKER_MAX_HEIGHT_MIN_SIZE,
			max = AUI_QUESTTRACKER_MAX_HEIGHT_MAX_SIZE,
			step = 1,
			getFunc = function() return AUI.Settings.Questtracker.height end,
			setFunc = function(value) 
				if value ~= nil then
					AUI.Settings.Questtracker.height = value
					AUI.Questtracker.UpdateUI()
				end
			end,
			default = GetDefaultSettings().height,
			width = "half",			
		},	
		{
			type = "dropdown",
			name = AUI.L10n.GetString("font_art"),
			tooltip = AUI.L10n.GetString("font_art_tooltip"),
			choices = AUI.Table.GetChoiceList(AUI.Menu.GetFontTypeList(), "value"),
			getFunc = function() return AUI.Table.GetValue(AUI.Menu.GetFontTypeList(), AUI.Settings.Questtracker.font_art) end,
			setFunc = function(value)
				if value ~= nil then
					AUI.Settings.Questtracker.font_art = AUI.Table.GetKey(AUI.Menu.GetFontTypeList(), value)
					AUI.Questtracker.UpdateUI()
				end
			end,
			default = AUI.Table.GetValue(AUI.Menu.GetFontTypeList(), GetDefaultSettings().font_art),
		},		
		{
			type = "slider",
			name = AUI.L10n.GetString("font_size"),
			name = AUI.L10n.GetString("font_size_tooltip"),
			min = AUI_QUESTTRACKER_MIN_FONT_SIZE,
			max = AUI_QUESTTRACKER_MAX_FONT_SIZE,
			step = 1,
			getFunc = function() return AUI.Settings.Questtracker.font_size end,
			setFunc = function(value) 
				if value ~= nil then
					AUI.Settings.Questtracker.font_size = value
					AUI.Questtracker.UpdateUI()
				end
			end,
			default = GetDefaultSettings().font_size,
			width = "full",
		},				
		{
			type = "checkbox",
			name = AUI.L10n.GetString("show_background"),
			getFunc = function() return AUI.Settings.Questtracker.showBackground end,
			setFunc = function(value)
				if value ~= nil then
					AUI.Settings.Questtracker.showBackground = value
					AUI.Questtracker.UpdateUI()
				end
			end,
			default = GetDefaultSettings().showBackground,
			width = "full",
		},	
		{
			type = "checkbox",
			name = AUI.L10n.GetString("show_time"),
			getFunc = function() return AUI.Settings.Questtracker.showTime end,
			setFunc = function(value)
				if value ~= nil then
					AUI.Settings.Questtracker.showTime = value
					AUI.Questtracker.UpdateUI()
				end
			end,
			default = GetDefaultSettings().showTime,
			width = "full",
		},	
		{
			type = "checkbox",
			name = AUI.L10n.GetString("time_precision_twelfe_hour"),
			getFunc = function() return AUI.Settings.Questtracker.useTimePrecisionTwelfeHour end,
			setFunc = function(value)
				if value ~= nil then
					AUI.Settings.Questtracker.useTimePrecisionTwelfeHour = value
					AUI.Questtracker.UpdateUI()
				end
			end,
			default = GetDefaultSettings().useTimePrecisionTwelfeHour,
			width = "full",
		},		
		{
			type = "button",
			name = AUI.L10n.GetString("reset_to_default_position"),
			tooltip = AUI.L10n.GetString("reset_to_default_position_tooltip"),
			func = function() AUI.Questtracker.SetToDefaultPosition(GetDefaultSettings()) end,
		},				
	}

	return optionsTable
end

function AUI.Questtracker.LoadSettings()
	if g_isInit then
		return
	end
		
	g_isInit = true	
		
	if AUI.Settings.MainMenu.modul_quest_tacker_account_wide then
		AUI.Settings.Questtracker = ZO_SavedVars:NewAccountWide("AUI_Quests", 10, nil, GetDefaultSettings())
	else
		AUI.Settings.Questtracker = ZO_SavedVars:New("AUI_Quests", 10, nil, GetDefaultSettings())
	end	
	
	local panelData =
	{
		type = "panel",
		name = AUI_MAIN_NAME .. " (" .. AUI.L10n.GetString("quest_tracker_module_name") .. ")",
		displayName = "|cFFFFB0" .. AUI_MAIN_NAME .. " (" .. AUI.L10n.GetString("quest_tracker_module_name") .. ")",
		author = AUI_TXT_COLOR_AUTHOR:Colorize(AUI_QUESTTRACKER_AUTHOR),
		version = AUI_TXT_COLOR_VERSION:Colorize(AUI_QUESTTRACKER_VERSION),
		slashCommand = "/auiquesttracker",
		registerForRefresh = true,
		registerForDefaults = true,
	}	
	
	g_LAM:RegisterOptionControls("AUI_Menu_Quests", CreateOptions())
	g_LAM:RegisterAddonPanel("AUI_Menu_Quests", panelData)
end
