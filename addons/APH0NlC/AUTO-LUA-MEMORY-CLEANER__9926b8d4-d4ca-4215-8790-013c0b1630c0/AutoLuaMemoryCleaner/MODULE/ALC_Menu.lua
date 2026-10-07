--[[
    Copyright © 2025-2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

if not ALC then return end
local ALC = ALC
local ALC_modules = ALC._modules
local lam_panel

local function IsConsoleUI()
	return IsInGamepadPreferredMode()
end

local function show_menu_scene(scene)
	return LibAPH.ShowMenuScene(scene)
end

local function after_scene_shown(scene, fn)
	return LibAPH.AfterSceneShown(scene, fn)
end

function ALC.build_lam2_menu()
	local lam_ver, lam_en = ALC.get_settings_library()
	if not lam_en or lam_ver < 30 then return end

	local is_eu_server = (GetWorldName() == "EU Megaserver")
	local is_pad = IsConsoleUI() or IsInGamepadPreferredMode()
	local is_dev = (GetDisplayName() == "@APHONlC")

	local lib_lam = LibAddonMenu2 or _G["LibAddonMenu2"]
	if not lib_lam then return end

	local menu_header = {
		type = "panel",
		name = "|c9CD04CAuto Lua Memory Cleaner|r",
		displayName = "|c00FFFFAuto Lua Memory Cleaner|r",
		author = "|ca500f3A|r|cb400e6P|r|cc300daH|r|cd200cdO|r|ce100c1NlC|r",
		version = ALC.version,
		registerForRefresh = true,
		website = "https://www.esoui.com/downloads/info4388",
		feedback = "https://www.esoui.com/downloads/info4388-AutoLuaMemoryCleanerPCampConsole.html#comments",
		translation = "https://www.esoui.com/portal.php?id=360&a=featurereq",
		donation = "https://buymeacoffee.com/aph0nlc"
	}

	local build_data = {}

	if not is_pad and not is_eu_server then
		table.insert(build_data, {
			type = "button",
			name = function()
				return "|c00FFFF" .. ALC.L("MENU_MAIL") .. "|r @|ca500f3A|r|cb400e6P|r|cc300daH|r|cd200cdO|r|ce100c1NlC|r"
			end,
			func = function()
				show_menu_scene("mailSend")
				after_scene_shown("mailSend", function()
					ZO_MailSendToField:SetText("@APHONlC")
					ZO_MailSendSubjectField:SetText("Auto Lua Memory Cleaner Support")
					ZO_MailSendBodyField:TakeFocus()
				end)
			end,
			width = "half"
		})
	end

	table.insert(build_data, {
		type = "button",
		name = function() return "|cFF0000" .. ALC.L("MENU_BUG_REPORT") .. "|r" end,
		func = function()
			if not is_pad then
				RequestOpenUnsafeURL("https://www.esoui.com/portal.php?id=360&a=bugreport")
				ALC.show_bug_report_box()
			end
		end,
		width = is_pad and "full" or "half"
	})

	if is_dev then
		table.insert(build_data, { type = "description", text = " ", width = "half" })
		table.insert(build_data, {
			type = "button",
			name = function()
				local is_console_mode = (GetCVar("ForceConsoleFlow.2") == "1")
				return "|cFFA500" .. ALC.L("MENU_CHANGE_MODE") .. ": " ..
					(is_console_mode and "|c00FFFF" .. ALC.L("MODE_CONSOLE") .. "|r" or "|c00FF00" .. ALC.L("MODE_PC") .. "|r")
			end,
			func = function()
				local is_console_mode = (GetCVar("ForceConsoleFlow.2") == "1")
				SetCVar("ForceConsoleFlow.2", is_console_mode and "0" or "1")
			end,
			width = "half"
		})
	end

	local cleanup_controls = {}

	table.insert(cleanup_controls, {
		type = "checkbox",
		name = function() return ALC.L("CHK_AUTO_LUA_CLEANUP") end,
		getFunc = function() return ALC.settings.is_enabled end,
		setFunc = function(v)
			ALC.settings.is_enabled = v
			ALC.toggle_core_events()
		end
	})

	local mode_names, mode_values = ALC.get_cleanup_mode_choices()
	table.insert(cleanup_controls, {
		type = "dropdown",
		name = function() return ALC.L("DD_CLEANUP_MODE") end,
		reference = "ALC_CleanupModeDropdown",
		choices = mode_names,
		choicesValues = mode_values,
		getFunc = ALC.get_cleanup_mode,
		setFunc = ALC.set_cleanup_mode
	})
	table.insert(cleanup_controls, {
		type = "description",
		text = function() return ALC.L("DESC_MODE_" .. ALC.get_cleanup_mode():upper()) end
	})

	ALC.platform_build_threshold_slider(cleanup_controls)

	table.insert(cleanup_controls, {
		type = "slider",
		name = function() return ALC.L("SLIDER_LUA_DELAY") end,
		min = 30, max = 1200, step = 10,
		getFunc = function() return ALC.settings.fallback_delay_sec end,
		setFunc = function(v) ALC.settings.fallback_delay_sec = v end,
		disabled = function() return not ALC.settings.is_enabled end
	})

	ALC.platform_build_extra_options(cleanup_controls)

	table.insert(cleanup_controls, {
		type = "checkbox",
		name = function() return ALC.L("CHK_AUTO_POOL_CLEANUP") end,
		getFunc = function() return ALC.settings.auto_clear_pool_on_teleport end,
		setFunc = function(v)
			ALC.settings.auto_clear_pool_on_teleport = v
			ALC.refresh_slash_commands()
		end
	})

	if ALC.settings.auto_clear_pool_on_teleport then table.insert(cleanup_controls, {
		type = "checkbox",
		name = function() return ALC.L("CHK_AUTO_POOL_CLEANUP_CONFIRM") end,
		getFunc = function() return ALC.settings.pool_reload_confirm_auto end,
		setFunc = function(v) ALC.settings.pool_reload_confirm_auto = v end,
		disabled = function() return not ALC.settings.auto_clear_pool_on_teleport end
	}) end

	ALC.platform_build_pool_threshold_slider(cleanup_controls)

	table.insert(cleanup_controls, {
		type = "slider",
		name = function() return ALC.L("SLIDER_POOL_DELAY") end,
		min = 1.5, max = 5, step = 0.1, decimals = 1,
		getFunc = function() return ALC.settings.pool_reload_delay_sec end,
		setFunc = function(v) ALC.settings.pool_reload_delay_sec = v end,
		disabled = function() return not ALC.settings.auto_clear_pool_on_teleport end
	})

	table.insert(cleanup_controls, {
		type = "checkbox",
		name = function() return ALC.L("CHK_CSA") end,
		getFunc = function() return ALC.settings.is_csa_enabled end,
		setFunc = function(v) ALC.settings.is_csa_enabled = v end
	})

	if is_pad then
		table.insert(build_data, {
			type = "submenu",
			name = function() return "|c00FF00" .. ALC.L("HEADER_CLEANUP_SETTINGS") .. "|r" end,
			reference = "ALC_Submenu_Cleanup",
			controls = cleanup_controls
		})
	else
		table.insert(build_data, { type = "header", name = function() return "|c00FF00" .. ALC.L("HEADER_CLEANUP_SETTINGS") .. "|r" end })
		for _, ctrl in ipairs(cleanup_controls) do
			table.insert(build_data, ctrl)
		end
	end

	if not is_pad then
		table.insert(build_data, { type = "divider" })
	end

	local function preview_window(win_ctrl)
		local cur_scene = SCENE_MANAGER:GetCurrentScene()
		if not cur_scene then return end
		if win_ctrl == ALC.ui_window and ALC.hud_fragment and cur_scene:HasFragment(ALC.hud_fragment) then
			win_ctrl:SetHidden(false)
		end
	end

	local ui_config_controls = {
		{
			type = "checkbox",
			name = function() return ALC.L("CHK_SHOW_UI") end,
			getFunc = function() return ALC.settings.show_ui end,
			setFunc = function(v)
				ALC.settings.show_ui = v
				ALC.call_optional(ALC.toggle_ui_update, "UI module (toggle_ui_update)")
				ALC.refresh_slash_commands()
			end
		},
		{
			type = "checkbox",
			name = function() return ALC.L("CHK_RENDER_IN_MENUS") end,
			getFunc = function() return ALC.settings.is_ui_global end,
			setFunc = function(v)
				ALC.settings.is_ui_global = v
				ALC.call_optional(ALC.update_ui_scenes, "UI module (update_ui_scenes)")
			end,
			disabled = function() return not ALC.settings.show_ui end
		},
		{
			type = "checkbox",
			name = function() return ALC.L("CHK_LOCK_UI") end,
			getFunc = function() return ALC.settings.is_ui_locked end,
			setFunc = function(v)
				ALC.settings.is_ui_locked = v
				if ALC.ui_window then ALC.ui_window:SetMovable(not v) end
			end,
			disabled = function() return not ALC.settings.show_ui end
		},
		{
			type = "slider",
			name = function() return ALC.L("SLIDER_UI_SCALE") end,
			min = 0.5, max = 2.0, step = 0.1, decimals = 1,
			getFunc = function() return ALC.settings.ui_scale or 1.0 end,
			setFunc = function(v)
				if ALC.ui_mover then ALC.ui_mover:ToggleGamepadMove(false) end
				ALC.settings.ui_scale = v
				ALC.call_optional(ALC.apply_ui_size, "UI module (apply_ui_size)")
			end,
			disabled = function() return not ALC.settings.show_ui end
		}
	}

	if is_pad then
		table.insert(ui_config_controls, {
			type = "button", name = function() return ALC.L("MENU_MOVE_UI") end, width = "half",
			func = function()
				ALC.call_optional(ALC.start_gamepad_move, "UI module (start_gamepad_move)")
			end,
			disabled = function() return ALC.ui_mover == nil or ALC.settings.is_ui_locked end
		})
	end
	table.insert(ui_config_controls, {
		type = "button",
		name = function() return "|cFF0000" .. ALC.L("MENU_RESET_UI_POSITION") .. "|r" end,
		warning = function() return ALC.L("WARN_RESET_UI_POSITION") end,
		isDangerous = true,
		width = is_pad and "full" or "half",
		func = function()
			ALC.settings.ui_x = nil
			ALC.settings.ui_y = nil
			ALC.settings.ui_point = nil
			ALC.call_optional(ALC.reset_ui_position, "UI module (reset_ui_position)")
			preview_window(ALC.ui_window)
			if ALC.settings.is_log_enabled then
				ALC.chat:Print(ALC.L("CHAT_UI_POSITION_RESET"))
			end
		end,
		disabled = function() return not ALC.settings.show_ui end
	})
	table.insert(ui_config_controls, {
		type = "button",
		name = function() return "|cFF0000" .. ALC.L("MENU_RESET_UI_SIZE") .. "|r" end,
		warning = function() return ALC.L("WARN_RESET_UI_SIZE") end,
		isDangerous = true,
		width = is_pad and "full" or "half",
		func = function()
			if ALC.ui_mover then ALC.ui_mover:ToggleGamepadMove(false) end
			ALC.settings.ui_scale = ALC.defaults.ui_scale
			ALC.settings.ui_width = nil
			ALC.settings.ui_height = nil
			ALC.call_optional(ALC.apply_ui_size, "UI module (apply_ui_size)")
			preview_window(ALC.ui_window)
			if ALC.settings.is_log_enabled then
				ALC.chat:Print(ALC.L("CHAT_UI_SIZE_RESET"))
			end
		end,
		disabled = function() return not ALC.settings.show_ui end
	})

	if not ALC.settings.show_ui then
		for index = #ui_config_controls, 2, -1 do table.remove(ui_config_controls, index) end
	end
	table.insert(build_data, {
		type = "submenu",
		name = function() return "|c00FFFF" .. ALC.L("HEADER_UI_CONFIG") .. "|r" end,
		reference = "ALC_Submenu_UIConfig",
		controls = ui_config_controls
	})

	do

		local function build_module_load_button(mod_key, display_name)
			return LibAPH.BuildModuleLoadButton({
				modKey = mod_key, displayName = display_name,
				moduleLabel = ALC.L("LABEL_MODULE"),
				settings = ALC.settings,
				toggleFn = ALC.toggle_module_disabled,
			})
		end

		local module_manager_controls = {}
		if IsKeyboardUISupported() then
			table.insert(module_manager_controls, { type = "header", name = function() return ALC.L("HEADER_MODULE_FILE_STATUS") end })
		end
		table.insert(module_manager_controls, build_module_load_button("migration", "Migration"))
		table.insert(module_manager_controls, build_module_load_button("wizard", "Wizard"))
		table.insert(module_manager_controls, build_module_load_button("menu", "Menu"))
		table.insert(module_manager_controls, build_module_load_button("ui", "UI"))
		table.insert(module_manager_controls, {
			type = "button", name = function() return ALC.L("BTN_RELOAD_UI") end, width = "half",
			func = function() ReloadUI("ingame") end
		})

		table.insert(build_data, {
			type = "submenu",
			name = function() return "|cFFA500" .. ALC.L("HEADER_MODULE_MANAGER") .. "|r" end,
			reference = "ALC_Submenu_ModuleManager",
			controls = module_manager_controls
		})
	end

	local adv_controls = {
		{
			type = "button",
			name = function() return "|c00FFFF" .. ALC.L("MENU_MANUAL_CLEANUP") .. "|r" end,
			func = function() ALC.run_manual_cleanup(true) end,
			width = "full"
		}
	}
	if ALC_modules.wizard then
		table.insert(adv_controls, {
			type = "button",
			name = function() return "|c00FFFF" .. ALC.L("MENU_RUN_WIZARD") .. "|r" end,
			func = function() ALC.call_optional(ALC.run_wizard, "Wizard module (run_wizard)") end,
			width = "full"
		})
	end
	table.insert(adv_controls, {
		type = "button",
		name = function() return "|cFF0000" .. ALC.L("MENU_RESET_DEFAULTS") .. "|r" end,
		warning = function() return ALC.L("WARN_RESET_DEFAULTS") end,
		isDangerous = true,
		func = ALC.reset_to_defaults,
		width = "full"
	})
	table.insert(adv_controls, {
		type = "checkbox",
		name = function() return ALC.L("CHK_LIB_WARNING_ENABLED") end,
		getFunc = function() return ALC.settings.is_lib_warning_enabled end,
		setFunc = function(v) ALC.settings.is_lib_warning_enabled = v end
	})

	table.insert(build_data, {
		type = "submenu",
		name = function() return "|cFF0000" .. ALC.L("HEADER_ADVANCED_SETTINGS") .. "|r" end,
		reference = "ALC_Submenu_Advanced",
		controls = adv_controls
	})

	if is_pad then
		table.insert(build_data, {
			type = "submenu",
			name = function() return "|c00FFFF" .. ALC.L("HEADER_CLIENT_INFO") .. "|r" end,
			reference = "ALC_Submenu_ClientInfo",
			controls = {
				{
					type = "button", width = "full",
					name = function() return "|c00FFFF" .. ALC.L("HEADER_CLIENT_INFO") .. "|r" end,
					tooltip = function() return ALC.build_client_info_text() end,
					func = function() end
				}
			}
		})
	else
		table.insert(build_data, {
			type = "submenu",
			name = function() return "|c00FFFF" .. ALC.L("HEADER_CLIENT_INFO") .. "|r" end,
			reference = "ALC_Submenu_ClientInfo",
			controls = {
				{
					type = "description",
					text = function() return ALC.build_client_info_text() end
				}
			}
		})
	end

	if is_pad then
		table.insert(build_data, {
			type = "submenu",
			name = function() return "|c00FF00" .. ALC.L("MENU_COMMANDS_INFO") .. "|r" end,
			reference = "ALC_Submenu_CommandsInfo",
			controls = {
				{
					type = "button", width = "full",
					name = function() return "|c00FF00" .. ALC.L("MENU_COMMANDS_INFO") .. "|r" end,
					tooltip = function() return ALC.build_command_list_text(false) end,
					func = function() end
				}
			}
		})
	else
		table.insert(build_data, {
			type = "description",
			title = function() return ALC.L("COMMANDS_INFO_TITLE") end,
			text = function() return ALC.build_command_list_text(false) end
		})
	end

	local menu_refresher = LibAPH.CreateMenuLabelRefresher("ALC_MRC_", function() return lam_panel end)
	menu_refresher.CollectFrom(build_data)
	ALC.refresh_control_labels = menu_refresher.Refresh

	lam_panel = lib_lam:RegisterAddonPanel("AutoLuaCleanerOptions", menu_header)
	lib_lam:RegisterOptionControls("AutoLuaCleanerOptions", build_data)
	ALC.menu_layout = ALC.get_menu_layout()

	local persisted_submenus = {
		"ALC_Submenu_UIConfig", "ALC_Submenu_Language",
		"ALC_Submenu_Advanced", "ALC_Submenu_ModuleManager"
	}

	local function on_panel_controls_created(panel)
		if panel ~= lam_panel then return end
		CALLBACK_MANAGER:UnregisterCallback("LAM-PanelControlsCreated", on_panel_controls_created)
		if not is_pad then
			for _, ref in ipairs(persisted_submenus) do
				LibAPH.PersistSubmenuOpenState(ALC.settings.submenu_open, ref)
			end
		end
		CALLBACK_MANAGER:RegisterCallback("LAM-RefreshPanel", ALC.refresh_control_labels)
	end
	CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", on_panel_controls_created)
end

ALC_modules.menu = true