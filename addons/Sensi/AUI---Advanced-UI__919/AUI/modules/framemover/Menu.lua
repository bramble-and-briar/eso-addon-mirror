AUI.Settings.FrameMover = {}

local g_LAM = LibAddonMenu2
local g_isInit = false

local function GetDefaultSettings()
	local defaultSettings =
	{
		enable = true,	
	}
end

local function CreateOptions()
	local optionsTable = 
	{
		{
			type = "header",
			name = AUI_TXT_COLOR_HEADER:Colorize(AUI.L10n.GetString("general"))
		},
		{
			type = "checkbox",
			name = AUI.L10n.GetString("acount_wide"),
			tooltip = AUI.L10n.GetString("acount_wide_tooltip"),
			getFunc = function() return AUI.Settings.MainMenu.modul_frame_mover_account_wide end,
			setFunc = function(value)
				if value ~= nil then
					if value ~= AUI.Settings.MainMenu.modul_frame_mover_account_wide then
						AUI.Settings.MainMenu.modul_frame_mover_account_wide = value
						ReloadUI()
					else
						AUI.Settings.MainMenu.modul_frame_mover_account_wide = value
					end
				end	
			end,
			default = true,
			width = "full",
			warning = AUI.L10n.GetString("reloadui_warning_tooltip"),
		},	
		{
			type = "checkbox",
			name = AUI.L10n.GetString("show_windows"),
			getFunc = function() return AUI.FrameMover.IsPreviewShowing() end,
			setFunc = function(value)
				if value ~= nil then
					AUI.FrameMover.ShowPreview(value)
				end
			end,
			default = AUI.FrameMover.IsPreviewShowing(),
			width = "full",
		},		
		{
			type = "header",
		},				
		{
			type = "button",
			name = AUI.L10n.GetString("reset_to_default_position"),
			tooltip = AUI.L10n.GetString("reset_to_default_position_tooltip"),
			func = function() AUI.FrameMover.SetToDefaultPosition() end,
		},		
	}
	
	return optionsTable
end

function AUI.FrameMover.LoadSettings()
	if g_isInit then
		return
	end

	if AUI.Settings.MainMenu.modul_frame_mover_account_wide then
		AUI.Settings.FrameMover = ZO_SavedVars:NewAccountWide("AUI_Control_Mover", 10, nil, GetDefaultSettings())
	else
		AUI.Settings.FrameMover = ZO_SavedVars:New("AUI_Control_Mover", 10, nil, GetDefaultSettings())
	end	
	
	local panelData = 
	{
		type = "panel",
		name = AUI_MAIN_NAME .. " (" .. AUI.L10n.GetString("frame_mover_module_name") .. ")",
		displayName = "|cFFFFB0" .. AUI_MAIN_NAME .. " (" .. AUI.L10n.GetString("frame_mover_module_name") .. ")",
		author = AUI_TXT_COLOR_AUTHOR:Colorize(AUI_FRAMEMOVER_AUTHOR),
		version = AUI_TXT_COLOR_VERSION:Colorize(AUI_FRAMEMOVER_VERSION),
		slashCommand = "/auiframemover",
		registerForRefresh = true,
		registerForDefaults = true,
	}
	
	g_LAM:RegisterOptionControls("AUI_Menu_FrameMover", CreateOptions())	
	g_LAM:RegisterAddonPanel("AUI_Menu_FrameMover", panelData)
	
	g_isInit = true
end
