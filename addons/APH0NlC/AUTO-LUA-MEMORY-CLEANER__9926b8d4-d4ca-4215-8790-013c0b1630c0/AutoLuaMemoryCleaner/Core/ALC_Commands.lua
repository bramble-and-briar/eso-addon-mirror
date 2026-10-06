--[[
    Copyright © 2025-2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

if not ALC then return end
local ALC = ALC

function ALC.register_slash_commands()
	SLASH_COMMANDS["/alc"] = function(raw_arg)
		local parsed_cmd = raw_arg:lower()
		if parsed_cmd == "" then
			local msg = "|c00FF00Available ALC Commands:|r\n" .. ALC.build_command_list_text(false)
			LibAPH.SendRawChatLine(msg)
			return
		end
	end
	SLASH_COMMANDS["/autoluaclean"] = SLASH_COMMANDS["/alc"]

	SLASH_COMMANDS["/alcon"] = function()
		ALC.settings.is_enabled = not ALC.settings.is_enabled
		ALC.toggle_core_events()
	end
	SLASH_COMMANDS["/alcenable"] = SLASH_COMMANDS["/alcon"]

	local ui_module_disabled = ALC.settings.module_disabled and ALC.settings.module_disabled.ui
	if not ui_module_disabled then
		SLASH_COMMANDS["/alcui"] = function()
			ALC.settings.show_ui = not ALC.settings.show_ui
			ALC.call_optional(ALC.toggle_ui_update, "UI module (toggle_ui_update)")
		end
		SLASH_COMMANDS["/alctoggleui"] = SLASH_COMMANDS["/alcui"]

		SLASH_COMMANDS["/alclock"] = function()
			if not ALC.settings.show_ui then return end
			ALC.settings.is_ui_locked = not ALC.settings.is_ui_locked
			if ALC.ui_window then ALC.ui_window:SetMovable(not ALC.settings.is_ui_locked) end
		end
		SLASH_COMMANDS["/alcuilock"] = SLASH_COMMANDS["/alclock"]

		SLASH_COMMANDS["/alcreset"] = function()
			if not ALC.settings.show_ui then return end
			ALC.settings.ui_x = nil
			ALC.settings.ui_y = nil
			ALC.settings.ui_point = nil
			ALC.call_optional(ALC.reset_ui_position, "UI module (reset_ui_position)")
		end
		SLASH_COMMANDS["/alcuireset"] = SLASH_COMMANDS["/alcreset"]
	end

	SLASH_COMMANDS["/alccsa"] = function()
		ALC.settings.is_csa_enabled = not ALC.settings.is_csa_enabled
	end
	SLASH_COMMANDS["/alctogglecsa"] = SLASH_COMMANDS["/alccsa"]

	SLASH_COMMANDS["/alclogs"] = function()
		ALC.settings.is_log_enabled = not ALC.settings.is_log_enabled
	end
	SLASH_COMMANDS["/alcchatlogs"] = SLASH_COMMANDS["/alclogs"]

	SLASH_COMMANDS["/alcclean"] = function() ALC.run_manual_cleanup(true) end
	SLASH_COMMANDS["/alccleanup"] = SLASH_COMMANDS["/alcclean"]

	SLASH_COMMANDS["/alcpoolreload"] = function()
		ALC.settings.auto_clear_pool_on_teleport = not ALC.settings.auto_clear_pool_on_teleport
		d("|c00FFFF[ALC]|r " .. ALC.L("CHAT_POOL_RELOAD_TOGGLE", ALC.settings.auto_clear_pool_on_teleport and ALC.L("WORD_ON") or ALC.L("WORD_OFF")))
	end

	SLASH_COMMANDS["/alcpoolconfirm"] = function()
		if not ALC.settings.auto_clear_pool_on_teleport then
			d("|c00FFFF[ALC]|r " .. ALC.L("CHAT_POOL_CONFIRM_UNAVAILABLE"))
			return
		end
		ALC.settings.pool_reload_confirm_auto = not ALC.settings.pool_reload_confirm_auto
		d("|c00FFFF[ALC]|r " .. ALC.L("CHAT_POOL_CONFIRM_TOGGLE", ALC.settings.pool_reload_confirm_auto and ALC.L("WORD_ON") or ALC.L("WORD_OFF")))
	end

	SLASH_COMMANDS["/alccleanupmode"] = function()
		local modes, current = ALC.get_cleanup_modes(), ALC.get_cleanup_mode()
		local next_mode = modes[1]
		for index, mode in ipairs(modes) do
			if mode == current then next_mode = modes[index % #modes + 1] end
		end
		ALC.set_cleanup_mode(next_mode)
		d("|c00FFFF[ALC]|r " .. ALC.L("CHAT_CLEANUP_MODE", ALC.L("MODE_" .. next_mode:upper())))
	end

	if not IsConsoleUI() then
		SLASH_COMMANDS["/alcbugreport"] = function() ALC.show_bug_report_box() end
		SLASH_COMMANDS["/alcbug"] = SLASH_COMMANDS["/alcbugreport"]
	end

	SLASH_COMMANDS["/alcsimulateerror"] = function()
		if GetDisplayName() ~= "@APHONlC" then return end
		ALC.dev_simulate_error()
	end

	SLASH_COMMANDS["/alclibwarn"] = function()
		ALC.settings.is_lib_warning_enabled = not ALC.settings.is_lib_warning_enabled
		d("|c00FFFF[ALC]|r " .. ALC.L("CHAT_LIBWARN_TOGGLE", ALC.settings.is_lib_warning_enabled and ALC.L("WORD_ON") or ALC.L("WORD_OFF")))
	end

	SLASH_COMMANDS["/alcdelvars"] = function()
		d("|cFF0000[ALC] " .. ALC.L("CHAT_WIPING_SETTINGS") .. "|r")
		ALC.reset_to_defaults()
	end
	SLASH_COMMANDS["/alcwipe"] = SLASH_COMMANDS["/alcdelvars"]

	if not (ALC.settings.module_disabled and ALC.settings.module_disabled.wizard) then
		SLASH_COMMANDS["/alcwizard"] = function()
			ALC.call_optional(ALC.run_wizard, "Wizard module (run_wizard)")
		end
	end

	SLASH_COMMANDS["/alcunloadwizard"] = function() ALC.toggle_module_disabled("wizard") end
	SLASH_COMMANDS["/alcunloadmenu"] = function() ALC.toggle_module_disabled("menu") end
	SLASH_COMMANDS["/alcunloadmigration"] = function() ALC.toggle_module_disabled("migration") end
	SLASH_COMMANDS["/alcunloadui"] = function() ALC.toggle_module_disabled("ui") end
end
