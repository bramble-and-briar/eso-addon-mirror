--[[
    Copyright © 2025-2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

if not ALC then return end
local ALC = ALC

local function IsConsoleUI()
	return IsInGamepadPreferredMode()
end

local function wizard_show_dialog(dialog_id, title, body, buttons)
	LibAPH.ShowDialogHidingWindows({ function() return GetControl("AutoLuaCleanerUI") end }, dialog_id, title, body, buttons)
end

local function wizard_finish()
	ALC.settings.wizard_completed = true
	ALC.settings.wizard_skipped = false
	d("|c00FFFF[ALC]|r " .. ALC.L("WIZARD_FINISH_MSG"))
	LibAPH.AutoUnloadWizardModule(ALC.settings, ALC.toggle_module_disabled)
end

local function wizard_step_pool_delay_custom()
	wizard_show_dialog("ALC_WIZARD_POOL_DELAY_CUSTOM", "|c9CD04CAuto Lua Memory Cleaner|r",
		ALC.L("POOL_DELAY_CUSTOM_BODY"),
		{
			{ text = ALC.L("SHORT", "1.5 sec"), keybind = "DIALOG_PRIMARY",
				callback = function() ALC.settings.pool_reload_delay_sec = 1.5; wizard_finish() end },
			{ text = ALC.L("LONG", "4 sec"), keybind = "DIALOG_NEGATIVE",
				callback = function() ALC.settings.pool_reload_delay_sec = 4; wizard_finish() end }
		}
	)
end

local function wizard_step_pool_delay()
	if not ALC.settings.auto_clear_pool_on_teleport then wizard_finish(); return end
	wizard_show_dialog("ALC_WIZARD_POOL_DELAY", "|c9CD04CAuto Lua Memory Cleaner|r",
		ALC.L("POOL_DELAY_BODY"),
		{
			{ text = ALC.L("USE_DEFAULT"), keybind = "DIALOG_PRIMARY",
				callback = function() ALC.settings.pool_reload_delay_sec = 2; wizard_finish() end },
			{ text = ALC.L("CUSTOMIZE"), keybind = "DIALOG_NEGATIVE",
				callback = function() wizard_step_pool_delay_custom() end }
		}
	)
end

local function wizard_step_pool_threshold_custom(is_console, low, high)
	wizard_show_dialog("ALC_WIZARD_POOL_THRESHOLD_CUSTOM", "|c9CD04CAuto Lua Memory Cleaner|r",
		ALC.L("POOL_THRESHOLD_CUSTOM_BODY"),
		{
			{ text = ALC.L("LOW", string.format("%g MB", low)), keybind = "DIALOG_PRIMARY",
				callback = function()
					if is_console then ALC.settings.pool_threshold_console = low else ALC.settings.pool_threshold_pc = low end
					wizard_step_pool_delay()
				end },
			{ text = ALC.L("HIGH", string.format("%g MB", high)), keybind = "DIALOG_NEGATIVE",
				callback = function()
					if is_console then ALC.settings.pool_threshold_console = high else ALC.settings.pool_threshold_pc = high end
					wizard_step_pool_delay()
				end }
		}
	)
end

local function wizard_step_pool_threshold()
	local is_console = IsConsoleUI()
	local low, def, high = 5, 10, 50
	if is_console then low, def, high = 5, 10, 20 end
	wizard_show_dialog("ALC_WIZARD_POOL_THRESHOLD", "|c9CD04CAuto Lua Memory Cleaner|r",
		ALC.L("POOL_THRESHOLD_BODY", def),
		{
			{ text = ALC.L("USE_DEFAULT"), keybind = "DIALOG_PRIMARY",
				callback = function()
					if is_console then ALC.settings.pool_threshold_console = def else ALC.settings.pool_threshold_pc = def end
					wizard_step_pool_delay()
				end },
			{ text = ALC.L("CUSTOMIZE"), keybind = "DIALOG_NEGATIVE",
				callback = function() wizard_step_pool_threshold_custom(is_console, low, high) end }
		}
	)
end

local function wizard_step_lua_delay_custom()
	wizard_show_dialog("ALC_WIZARD_LUA_DELAY_CUSTOM", "|c9CD04CAuto Lua Memory Cleaner|r",
		ALC.L("LUA_DELAY_CUSTOM_BODY"),
		{
			{ text = ALC.L("SHORT", "120 sec"), keybind = "DIALOG_PRIMARY",
				callback = function() ALC.settings.fallback_delay_sec = 120; wizard_step_pool_threshold() end },
			{ text = ALC.L("LONG", "600 sec"), keybind = "DIALOG_NEGATIVE",
				callback = function() ALC.settings.fallback_delay_sec = 600; wizard_step_pool_threshold() end }
		}
	)
end

local function wizard_step_lua_delay()
	wizard_show_dialog("ALC_WIZARD_LUA_DELAY", "|c9CD04CAuto Lua Memory Cleaner|r",
		ALC.L("LUA_DELAY_BODY"),
		{
			{ text = ALC.L("USE_DEFAULT"), keybind = "DIALOG_PRIMARY",
				callback = function() ALC.settings.fallback_delay_sec = 300; wizard_step_pool_threshold() end },
			{ text = ALC.L("CUSTOMIZE"), keybind = "DIALOG_NEGATIVE",
				callback = function() wizard_step_lua_delay_custom() end }
		}
	)
end

local function wizard_step_lua_threshold_custom(low, high, is_console)
	wizard_show_dialog("ALC_WIZARD_LUA_THRESHOLD_CUSTOM", "|c9CD04CAuto Lua Memory Cleaner|r",
		ALC.L("LUA_THRESHOLD_CUSTOM_BODY"),
		{
			{ text = ALC.L("LOW", string.format("%d MB", low)), keybind = "DIALOG_PRIMARY",
				callback = function()
					if is_console then ALC.settings.threshold_console = low else ALC.settings.threshold_pc = low end
					wizard_step_lua_delay()
				end },
			{ text = ALC.L("HIGH", string.format("%d MB", high)), keybind = "DIALOG_NEGATIVE",
				callback = function()
					if is_console then ALC.settings.threshold_console = high else ALC.settings.threshold_pc = high end
					wizard_step_lua_delay()
				end }
		}
	)
end

local function wizard_step_lua_threshold()
	local is_console = IsConsoleUI()
	local low, def, high = 200, 350, 500
	if is_console then low, def, high = 40, 60, 80 end
	wizard_show_dialog("ALC_WIZARD_LUA_THRESHOLD", "|c9CD04CAuto Lua Memory Cleaner|r",
		ALC.L("LUA_THRESHOLD_BODY", def),
		{
			{ text = ALC.L("USE_DEFAULT"), keybind = "DIALOG_PRIMARY",
				callback = function()
					if is_console then ALC.settings.threshold_console = def else ALC.settings.threshold_pc = def end
					wizard_step_lua_delay()
				end },
			{ text = ALC.L("CUSTOMIZE"), keybind = "DIALOG_NEGATIVE",
				callback = function() wizard_step_lua_threshold_custom(low, high, is_console) end }
		}
	)
end

local function wizard_step_cleanup_mode_pick(mode)
	ALC.set_cleanup_mode(mode)
	wizard_step_lua_threshold()
end

local function wizard_step_cleanup_mode_forced()
	wizard_show_dialog("ALC_WIZARD_CLEANUP_MODE_FORCED", "|c9CD04CAuto Lua Memory Cleaner|r",
		ALC.L("CLEANUP_MODE_FORCED_BODY"),
		{
			{ text = ALC.L("MODE_AGGRESSIVE"), keybind = "DIALOG_PRIMARY",
				callback = function() wizard_step_cleanup_mode_pick("aggressive") end },
			{ text = ALC.L("MODE_DEEP"), keybind = "DIALOG_NEGATIVE",
				callback = function() wizard_step_cleanup_mode_pick("deep") end }
		}
	)
end

local function wizard_step_cleanup_mode_custom()
	wizard_show_dialog("ALC_WIZARD_CLEANUP_MODE_CUSTOM", "|c9CD04CAuto Lua Memory Cleaner|r",
		ALC.L("CLEANUP_MODE_CUSTOM_BODY"),
		{
			{ text = ALC.L("MODE_AUTOMATIC"), keybind = "DIALOG_PRIMARY",
				callback = function() wizard_step_cleanup_mode_pick("automatic") end },
			{ text = ALC.L("MODE_FORCED"), keybind = "DIALOG_NEGATIVE",
				callback = wizard_step_cleanup_mode_forced }
		}
	)
end

local function wizard_step_cleanup_mode()
	wizard_show_dialog("ALC_WIZARD_CLEANUP_MODE", "|c9CD04CAuto Lua Memory Cleaner|r",
		ALC.L("CLEANUP_MODE_BODY"),
		{
			{ text = ALC.L("USE_DEFAULT"), keybind = "DIALOG_PRIMARY",
				callback = function() wizard_step_cleanup_mode_pick("background") end },
			{ text = ALC.L("CUSTOMIZE"), keybind = "DIALOG_NEGATIVE",
				callback = wizard_step_cleanup_mode_custom }
		}
	)
end

local function wizard_step_pool_cleanup()
	wizard_show_dialog("ALC_WIZARD_POOL_CLEANUP", "|c9CD04CAuto Lua Memory Cleaner|r",
		ALC.L("POOL_CLEANUP_BODY"),
		{
			{ text = ALC.L("YES"), keybind = "DIALOG_PRIMARY",
				callback = function() ALC.settings.auto_clear_pool_on_teleport = true; wizard_step_cleanup_mode() end },
			{ text = ALC.L("NO"), keybind = "DIALOG_NEGATIVE",
				callback = function() ALC.settings.auto_clear_pool_on_teleport = false; wizard_step_cleanup_mode() end }
		}
	)
end

local function wizard_step_render_in_menus()
	wizard_show_dialog("ALC_WIZARD_RENDER_MENUS", "|c9CD04CAuto Lua Memory Cleaner|r",
		ALC.L("RENDER_MENUS_BODY"),
		{
			{ text = ALC.L("YES"), keybind = "DIALOG_PRIMARY",
				callback = function() ALC.settings.is_ui_global = true; wizard_step_pool_cleanup() end },
			{ text = ALC.L("NO"), keybind = "DIALOG_NEGATIVE",
				callback = function() ALC.settings.is_ui_global = false; wizard_step_pool_cleanup() end }
		}
	)
end

local function wizard_step_memory_ui()
	wizard_show_dialog("ALC_WIZARD_MEMORY_UI", "|c9CD04CAuto Lua Memory Cleaner|r",
		ALC.L("MEMORY_UI_BODY"),
		{
			{ text = ALC.L("YES"), keybind = "DIALOG_PRIMARY",
				callback = function()
					ALC.settings.show_ui = true
					ALC.call_optional(ALC.toggle_ui_update, "UI module (toggle_ui_update)")
					wizard_step_render_in_menus()
				end },
			{ text = ALC.L("NO"), keybind = "DIALOG_NEGATIVE",
				callback = function()
					ALC.settings.show_ui = false
					ALC.call_optional(ALC.toggle_ui_update, "UI module (toggle_ui_update)")
					wizard_step_pool_cleanup()
				end }
		}
	)
end

local function wizard_step_csa()
	wizard_show_dialog("ALC_WIZARD_CSA", "|c9CD04CAuto Lua Memory Cleaner|r",
		ALC.L("CSA_BODY"),
		{
			{ text = ALC.L("YES"), keybind = "DIALOG_PRIMARY",
				callback = function() ALC.settings.is_csa_enabled = true; wizard_step_memory_ui() end },
			{ text = ALC.L("NO"), keybind = "DIALOG_NEGATIVE",
				callback = function() ALC.settings.is_csa_enabled = false; wizard_step_memory_ui() end }
		}
	)
end

local function wizard_step_chatlogs()
	if IsConsoleUI() then wizard_step_csa(); return end
	wizard_show_dialog("ALC_WIZARD_CHATLOGS", "|c9CD04CAuto Lua Memory Cleaner|r",
		ALC.L("CHATLOGS_BODY"),
		{
			{ text = ALC.L("YES"), keybind = "DIALOG_PRIMARY",
				callback = function() ALC.settings.is_log_enabled = true; wizard_step_csa() end },
			{ text = ALC.L("NO"), keybind = "DIALOG_NEGATIVE",
				callback = function() ALC.settings.is_log_enabled = false; wizard_step_csa() end }
		}
	)
end

local function wizard_step_welcome()
	wizard_show_dialog("ALC_WIZARD_WELCOME", "|c9CD04C" .. ALC.L("WELCOME_TITLE") .. "|r",
		ALC.L("WELCOME_BODY"),
		{
			{ text = ALC.L("QUICK_SETUP"), keybind = "DIALOG_PRIMARY", callback = wizard_step_chatlogs },
			{ text = ALC.L("SKIP"), keybind = "DIALOG_NEGATIVE",
				callback = function()
					ALC.settings.wizard_completed = true
					ALC.settings.wizard_skipped = true
				end }
		}
	)
end

function ALC.run_wizard()
	wizard_step_welcome()
end

function ALC.run_wizard_if_needed()
	LibAPH.ScheduleWizardIfNeeded(ALC.settings.wizard_completed, ALC.run_wizard)
end

ALC._modules.wizard = true