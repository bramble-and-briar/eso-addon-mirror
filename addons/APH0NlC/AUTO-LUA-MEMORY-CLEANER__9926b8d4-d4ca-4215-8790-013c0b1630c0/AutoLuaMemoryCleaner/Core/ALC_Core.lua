--[[
    Copyright © 2025-2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local function is_gamepad_ui()
	return IsInGamepadPreferredMode()
end

local apply_module_disable_overrides, dismiss_captured_error, get_bug_report_settings_fields, get_platform_str
local get_today_date_str, hook_error_capture, init, safe_csa, show_copy_text_box, save_and_reload

AutoLuaMemoryCleaner = {
	name = "AutoLuaMemoryCleaner",
	version = "2026.10.18.01.41",
	defaults = {
		schema_version = 2,
		is_enabled = true,
		threshold_pc = 200,
		threshold_console = 60,
		pool_threshold_console = 10,
		fallback_delay_sec = 300,
		is_csa_enabled = true,
		is_log_enabled = true,
		show_ui = true,
		is_ui_locked = true,
		ui_x = nil,
		ui_y = nil,
		ui_width = nil,
		ui_height = nil,
		ui_scale = 1.0,
		is_ui_global = false,
		has_shown_lib_warning_008 = false,
		is_lib_warning_enabled = true,
		wizard_completed = false,
		install_date = nil,
		last_version = nil,
		version_history = {},
		submenu_open = {},
		warned_module_labels = {},
		auto_clear_pool_on_teleport = false,
		pool_reload_confirm_auto = true,
		cleanup_mode = "automatic",
		pool_reload_delay_sec = 3,
		reload_cooldown_min = 60,
		reload_threshold_pc = 500,
		afk_reload = false,
		afk_reload_min = 10,
		afk_reloaded = false,
		cleanup_min_growth_mb = 2,
		cleanup_min_growth_pct = 5,
		pool_reload_test_pending = false,
		pool_reload_test_before_mb = 0,
		last_pool_reload_time = 0,
		pool_reload_stuck_client_start = 0,
		lowmem_reload = false,
		lowmem_notices = false,
		garbage_check_notices = false,
		garbage_check_ignore_growth = false,
		lowmem_reload_pending = false,
		lowmem_reload_before_mb = 0
	},
	session_mb_freed = 0,
	session_pool_mb_freed = 0,
}
local ALC = AutoLuaMemoryCleaner
local ALC_defaults = ALC.defaults
local SCHEMA_VERSION = 2
local mem_state = 0
local is_mem_check_queued = false
local last_priority_save_time = 0
local is_scene_callback_registered = false
local chat_error, copy_box, last_cleanup_time, pool_reload_token, cleanup_interrupted, watch_add_on_pool, garbage_armed_at
local POOL_WATCH_MS = 100
local session_bugs = {}

local REQUIRED_LAM_VERSION = 43
local REQUIRED_LHAS_VERSION = 20200

ALC._modules = {}
local ALC_modules = ALC._modules
local MODULE_FILE_FUNCS = {
	migration = { "migrate_data" },
	wizard = { "run_wizard", "run_wizard_if_needed" },
	menu = { "build_lam2_menu" },
	ui = { "get_gamepad_mover", "toggle_ui_update", "update_ui_anchor", "update_ui", "create_ui", "update_ui_scenes", "reset_ui_position", "start_gamepad_move", "apply_ui_size" },
}

function ALC.call_optional(fn, label, ...)
	return LibAPH.CallOptional(ALC.settings.warned_module_labels, "|c00FFFF[ALC]|r",
		"is unavailable (unloaded via Module Manager) - skipping.", fn, label, ...)
end

function ALC.toggle_module_disabled(mod_key, silent)
	local now_disabled = LibAPH.ToggleModuleDisabled(ALC.settings, MODULE_FILE_FUNCS, mod_key, function(disabled, key)
		local applied_live = LibAPH.HasModuleLifecycle(key)
		d("|c00FFFF[ALC]|r " .. (disabled and ALC.L("MODULE_TOGGLE_UNLOADED", key) or ALC.L("MODULE_TOGGLE_REENABLED", key)) ..
		  (applied_live and ALC.L("MODULE_TOGGLE_LIVE") or ALC.L("MODULE_TOGGLE_RELOAD")))
	end, silent)

	if not now_disabled then
		ALC.settings.warned_module_labels = {}
	end
	LibAPH.SyncModuleLifecycle(ALC_modules, mod_key, now_disabled)
	ALC.refresh_slash_commands()
	return now_disabled
end

function apply_module_disable_overrides()
	LibAPH.ApplyModuleDisableOverrides(ALC.settings, MODULE_FILE_FUNCS, ALC_modules, function(fname)
		ALC[fname] = nil
	end)
end

function ALC.reset_to_defaults()
	LibAPH.ResetToDefaults(ALC.settings, ALC_defaults, {
		wizard_completed = true, has_shown_lib_warning_008 = true
	}, function()
		ALC.settings.ui_x = nil
		ALC.settings.ui_y = nil
		ALC.settings.ui_point = nil
		ALC.settings.ui_width = nil
		ALC.settings.ui_height = nil
	end)
	ALC.set_cleanup_mode(ALC.settings.cleanup_mode)
	ALC.call_optional(ALC.toggle_ui_update, "UI module (toggle_ui_update)")
	ALC.refresh_slash_commands()
end

function ALC.get_hybrid_memory_data()
	return collectgarbage("count") / 1024
end

function ALC.get_console_pool_mb()
	return GetTotalUserAddOnMemoryPoolUsageMB() or 0
end

ALC.PC = ALC.PC or {}
ALC.Console = ALC.Console or {}
local ALC_PC = ALC.PC
local ALC_Console = ALC.Console
local trigger_memory_check
local scene_callback_fn

local function get_platform_module()
	return is_gamepad_ui() and ALC_Console or ALC_PC
end

function ALC.get_active_memory_mb()
	local mod = get_platform_module()
	if mod.get_active_memory_mb then return mod.get_active_memory_mb() end
	return ALC.get_hybrid_memory_data()
end

local function get_active_threshold()
	local mod = get_platform_module()
	if mod.get_threshold then return mod.get_threshold() end
	return ALC.settings.threshold_pc
end

function ALC.is_console()
	return IsConsoleUI()
end

function ALC.platform_build_threshold_slider(build_data)
	local mod = get_platform_module()
	if mod.build_threshold_slider then mod.build_threshold_slider(build_data) end
end

function ALC.platform_build_pool_threshold_slider(build_data)
	local mod = get_platform_module()
	if mod.build_pool_threshold_slider then mod.build_pool_threshold_slider(build_data) end
end

function ALC.platform_build_extra_options(build_data)
	local mod = get_platform_module()
	if mod.build_extra_options then mod.build_extra_options(build_data) end
end

local ALC_PC_SERVICE_NAMES = { Steam = "Steam", Epic = "Epic Games Store", ZOS = "ZOS Launcher", DMM = "DMM" }

function get_platform_str()
	local platform = LibAPH.GetPlatformString()
	if platform == "PC" then
		local service = ALC_PC_SERVICE_NAMES[LibAPH.GetPlatformServiceName()]
		if service then
			return string.format("%s (%s)", ALC.L("MODE_PC"), service)
		end
		return ALC.L("MODE_PC")
	elseif platform then
		return platform
	end
	return ALC.L("NOT_FOUND")
end

function ALC.get_settings_library()
	local lam_v, lam_e = LibAPH.CheckLibraryVersion("LibAddonMenu-2.0")
	local lhas_v, lhas_e = 0, false
	if is_gamepad_ui() then
		lhas_v, lhas_e = LibAPH.CheckLibraryVersion("LibHarvensAddonSettings")
	end
	return lam_v, lam_e, lhas_v, lhas_e
end

local function format_memory(value_mb)
	return LibAPH.FormatMemoryMB(value_mb)
end

function get_today_date_str()
	return LibAPH.GetTodayDateString()
end

local COLOR_LUA_ACTIVE = "|c00FF00"
local COLOR_POOL_ACTIVE = "|c00FFFF"
local COLOR_CLEANED = "|c888888"

local function get_lua_status_color(mb)
	if mb >= 512 then return "|cFF0000" elseif mb >= 320 then return "|cFFA500" else return COLOR_LUA_ACTIVE end
end
local function get_pool_status_color(mb)
	local cap = GetTotalUserAddOnMemoryPoolCapacityMB() or 100
	if mb >= cap then return "|cFF0000" elseif mb >= cap * 0.6 then return "|cFFA500" else return COLOR_POOL_ACTIVE end
end

local function build_memory_fragment(label, color, current_mb, cleaned_mb)
	local base = string.format("%s: %s%s|r", label, color, format_memory(current_mb))
	if cleaned_mb and cleaned_mb > 0.001 then
		base = base .. string.format(" %s(-%s)|r", COLOR_CLEANED, format_memory(cleaned_mb))
	end
	return base
end

function ALC.build_memory_status_line(current_lua, lua_cleaned, current_pool, pool_cleaned)
	return build_memory_fragment(ALC.L("LABEL_LUA"), get_lua_status_color(current_lua), current_lua, lua_cleaned) ..
		"  " .. build_memory_fragment(ALC.L("LABEL_POOL"), get_pool_status_color(current_pool), current_pool, pool_cleaned)
end

local function build_memory_status_lines(current_lua, lua_cleaned, current_pool, pool_cleaned)
	return build_memory_fragment(ALC.L("LABEL_LUA"), get_lua_status_color(current_lua), current_lua, lua_cleaned) ..
		"\n" .. build_memory_fragment(ALC.L("LABEL_POOL"), get_pool_status_color(current_pool), current_pool, pool_cleaned)
end

local function format_lib(ver, en, name, req)
	return LibAPH.FormatLibraryVersion(ver, en, req, {
		missing = function() return "|cFF0000" .. ALC.L("NOT_FOUND") .. "|r" end,
		disabled = function(v) return string.format("|cFF0000%s (v%d) %s|r", name, v, ALC.L("STATE_DISABLED")) end,
		exact = function(v) return string.format("|c00FF00%s (v%d)|r", name, v) end,
		old = function(v, r) return string.format("|c888888%s|r |cFF0000%s|r |c00FFFF%s|r", name, ALC.L("STATE_OLD", v), ALC.L("STATE_EXPECTED", r)) end,
		newer = function(v, r) return string.format("|c00FFFF%s %s %s|r", name, ALC.L("STATE_NEWER", v), ALC.L("STATE_EXPECTED", r)) end,
	})
end

local ALC_MODULE_FILES = {
	migration = "MODULE/ALC_Migration.lua",
	wizard = "MODULE/ALC_Wizard.lua",
	menu = "MODULE/ALC_Menu.lua",
	ui = "MODULE/ALC_UI.lua",
}

local function alc_module_state(mod_key)
	return (ALC_modules[mod_key] == false) and "unloaded" or "loaded"
end

function ALC.build_client_info_text()
	local lam_ver, lam_en, lhas_ver, lhas_en = ALC.get_settings_library()
	local lam_str = format_lib(lam_ver, lam_en, "LAM2", REQUIRED_LAM_VERSION)
	local lhas_str = format_lib(lhas_ver, lhas_en, "LHAS", REQUIRED_LHAS_VERSION)

	local install_date = ALC.settings.install_date or ALC.L("INSTALL_DATE_UNKNOWN")
	local today_str = get_today_date_str()
	local install_line = LibAPH.FormatInstallDateLine(install_date, today_str)

	local v_hist = ALC.settings.version_history or {ALC.version}
	local v_hist_str = LibAPH.FormatVersionHistory(v_hist, ALC.version)

	local wizard_str = ALC.settings.wizard_completed
		and ("|c00FF00" .. ALC.L("WIZARD_SETUP_DONE") .. "|r")
		or ("|cFFA500" .. ALC.L("WIZARD_NOT_YET_RUN") .. "|r")

	local file_lines_str = LibAPH.BuildModuleFileList(
		{ "migration", "wizard", "menu", "ui" },
		ALC_MODULE_FILES,
		alc_module_state,
		{ loaded = ALC.L("FILE_LOADED"), unloaded = ALC.L("FILE_UNLOADED_BY_USER") }
	)

	local libaph_str = "|c00FF00LibAPH (v" .. LibAPH.VERSION .. ")|r"
	local library_version_str = libaph_str .. ", " .. lam_str
	if is_gamepad_ui() then
		library_version_str = library_version_str .. ", " .. lhas_str
	end

	local info_lines = {
		ALC.L("FIELD_INSTALLED_SINCE") .. " " .. install_line,
		ALC.L("FIELD_VERSION_HISTORY") .. " " .. v_hist_str,
		ALC.L("FIELD_LIBRARY_VERSION") .. " " .. library_version_str,
		ALC.L("FIELD_PLATFORM") .. " |cFFFFFF" .. get_platform_str() .. "|r",
	}
	table.insert(info_lines, ALC.L("FIELD_WIZARD") .. " " .. wizard_str)

	table.insert(info_lines, ALC.L("FIELD_FILES") .. "\n  " .. file_lines_str)

	return table.concat(info_lines, "\n")
end

function ALC.dev_simulate_error()
	zo_callLater(function()
		error(ALC.name .. ": THIS IS NOT A REAL ERROR, THIS IS A TEST ERROR")
	end, 1)
end

function dismiss_captured_error()
	ZO_ClearNumericallyIndexedTable(session_bugs)
	ALC.show_bug_report_box()
end

function ALC.wipe_all_bugs()
	ZO_ClearNumericallyIndexedTable(session_bugs)
	if copy_box then copy_box:Hide() end
end

function show_copy_text_box(sections, has_errors)
	local is_dev = (GetDisplayName() == "@APHONlC")
	copy_box = copy_box or LibAPH.CreateCopyTextBox({
		name = "ALCCopyBox",
		pastebin = true,
		sections = true,
		maxInputChars = LibAPH.BUG_REPORT_MAX_CHARS,
		closeText = ALC.L("BTN_CLOSE"),
		titleText = ALC.L("BUG_REPORT_COPY_TITLE"),
		devButton = is_dev and { text = "Simulate Error", onClick = ALC.dev_simulate_error } or nil,
		dismissBug = { text = "Dismiss Bug", onClick = dismiss_captured_error },
		wipeAllBugs = { text = "Wipe All Bugs", onClick = ALC.wipe_all_bugs },
	})
	copy_box:ShowReport(sections, has_errors)
end

function get_bug_report_settings_fields()
	local fields = {
		{ key = "is_enabled", label = ALC.L("CHK_AUTO_LUA_CLEANUP") },
		{ key = "is_csa_enabled", label = ALC.L("CHK_CSA") },
		{ key = "is_log_enabled", label = ALC.L("CHK_CHAT_LOGS") },
		{ key = "show_ui", label = ALC.L("CHK_SHOW_UI") },
		{ key = "is_ui_locked", label = ALC.L("CHK_LOCK_UI") },
		{ key = "is_ui_global", label = ALC.L("CHK_RENDER_IN_MENUS") },
		{ key = "auto_clear_pool_on_teleport", label = ALC.L("CHK_AUTO_POOL_CLEANUP") },
		{ key = "afk_reload", label = ALC.L("CHK_AFK_RELOAD") },
		{ key = "garbage_check_notices", label = ALC.L("CHK_GARBAGE_CHECK_NOTICES") },
		{ key = "garbage_check_ignore_growth", label = ALC.L("CHK_GARBAGE_CHECK_IGNORE_GROWTH") },
	}
	if IsConsoleUI() then
		fields[#fields + 1] = { key = "lowmem_reload", label = ALC.L("CHK_LOWMEM_RELOAD") }
		fields[#fields + 1] = { key = "lowmem_notices", label = ALC.L("CHK_LOWMEM_NOTICES") }
	end
	return fields
end

function ALC.show_bug_report_box()
	local bug_lines = {}
	if #session_bugs > 0 then bug_lines[1] = LibAPH.FormatCapturedBugBlocks(ALC.name, session_bugs) end
	local error_section = LibAPH.FormatCapturedBugsSection(
		bug_lines,
		ALC.L("BUG_REPORT_COPY_PROMPT"),
		ALC.L("BUG_REPORT_NONE_CAPTURED", ALC.name),
		ALC.L("BUG_REPORT_DESCRIBE_INSTEAD")
	)

	local on_word, off_word = ALC.L("WORD_ON"), ALC.L("WORD_OFF")
	local settings_lines = LibAPH.FormatSettingsSnapshot(ALC.settings, get_bug_report_settings_fields(), on_word, off_word)

	local sections = LibAPH.BuildBugReportSections({
		statsText = ALC.build_client_info_text(),
		settingsLines = settings_lines,
		fieldSettingsLabel = ALC.L("FIELD_SETTINGS"),
		errorSection = error_section,
		fieldLabels = {
			platform = ALC.L("FIELD_PLATFORM"),
			language = ALC.L("FIELD_CURRENT_LANGUAGE"),
			installed = ALC.L("FIELD_INSTALLED_SINCE"),
			version_history = ALC.L("FIELD_VERSION_HISTORY"),
			library_version = ALC.L("FIELD_LIBRARY_VERSION"),
			wizard = ALC.L("FIELD_WIZARD"),
			files = ALC.L("FIELD_FILES"),
		},
	})

	show_copy_text_box(sections, #session_bugs > 0)
end

function hook_error_capture()
	ALC.settings.captured_bugs = nil
	LibAPH.HookErrorCapture(ALC.name, function(text)
		LibAPH.RecordCapturedBug(session_bugs, text)
		if copy_box and not copy_box.window:IsHidden() then
			ALC.show_bug_report_box()
		end
	end)
end

local function command_shown(c)
	if (c.pc_only and IsConsoleUI()) or (c.console_only and not IsConsoleUI()) then return false end
	return not (c.disabled_check and c.disabled_check())
end

function ALC.get_menu_layout()
	return tostring(ALC.settings.auto_clear_pool_on_teleport and true or false) .. "," .. tostring(ALC.settings.show_ui and true or false) .. "," .. tostring(ALC.settings.afk_reload and true or false)
end

function ALC.refresh_slash_commands()
	if not ALC.settings then return end
	if ALC.menu_layout and ALC.menu_layout ~= ALC.get_menu_layout() then
		zo_callLater(function() ALC.chat:Print(ALC.L("CHAT_RELOAD_TO_APPLY")) end, 0)
	end
	if not LibAPH.SetSlashCommandsShown then return end
	for _, cat in ipairs(ALC.COMMAND_CATEGORIES) do
		for _, c in ipairs(cat.cmds) do
			local names = { c.cmd }
			if c.alias then names[#names + 1] = c.alias end
			LibAPH.SetSlashCommandsShown(names, command_shown(c))
		end
	end
end

function ALC.say_setting(label_key, on)
	d("|c00FFFF[ALC]|r " .. ALC.L("CHAT_SETTING_STATE", ALC.L(label_key), on and ALC.L("WORD_ON") or ALC.L("WORD_OFF")))
end

function ALC.build_command_list_text(double_spaced)
	local sep = double_spaced and "\n\n" or "\n"
	local lines = {}
	for _, cat in ipairs(ALC.COMMAND_CATEGORIES) do
		local cat_lines = {}
		for _, c in ipairs(cat.cmds) do
			if command_shown(c) then
				table.insert(cat_lines, string.format("|c00FFFF%s|r |cFFD700- %s|r%s", c.cmd, ALC.L(c.desc_key), sep))
			end
		end
		if #cat_lines > 0 then
			table.insert(lines, string.format("|c00FF00[%s]|r%s", ALC.L(cat.title_key), sep))
			for _, l in ipairs(cat_lines) do table.insert(lines, l) end
		end
	end
	return table.concat(lines)
end

local HUD_SCENE_NAMES = { hud = true, hudui = true }

function ALC.toggle_core_events()
	if ALC.settings.is_enabled then
		EVENT_MANAGER:RegisterForEvent(ALC.name .. "_CombatState", EVENT_PLAYER_COMBAT_STATE,
			function(event_code, in_combat)
				if not in_combat then
					trigger_memory_check("CombatEnd", 3000)
				elseif mem_state == 1 then
					local job = LibAPH.GetScheduledJob("LibAPH_StepCleanup")
					if job then
						cleanup_interrupted = true
						job:Cancel()
					end
				end
			end
		)
		garbage_armed_at = GetGameTimeMilliseconds()
		ALC.toggle_afk_watch()
		if is_gamepad_ui() then
			EVENT_MANAGER:RegisterForEvent(ALC.name .. "_LowMem", EVENT_CONSOLE_ADD_ONS_MEMORY_LIMIT_REACHED, function() ALC.start_rescue() end)
		end
		if LibAPH.RegisterLowMemoryCallback then
			LibAPH.RegisterLowMemoryCallback(ALC.name, function(used, cap) ALC.start_rescue(used, cap) end)
		end
		if LibAPH.GetAddOnMemoryLimitMB and LibAPH.GetAddOnMemoryLimitMB() then
			EVENT_MANAGER:RegisterForUpdate(ALC.name .. "_PoolWatch", POOL_WATCH_MS, watch_add_on_pool)
		end
		EVENT_MANAGER:RegisterForUpdate(ALC.name .. "_AutoSweep", 5000,
			function()
				if not IsPlayerMoving() then
					trigger_memory_check("Idle", 1000)
				else
					trigger_memory_check("AutoSweep", 0)
				end
			end
		)

		if not is_scene_callback_registered then
			scene_callback_fn = function(old_state, new_state)
				if new_state ~= SCENE_HIDDEN then return end
				local next_scene = SCENE_MANAGER:GetNextScene()
				if next_scene and not HUD_SCENE_NAMES[next_scene:GetName()] then
					trigger_memory_check("Menu", 6000)
				end
			end
			for name in pairs(HUD_SCENE_NAMES) do
				local scene = SCENE_MANAGER:GetScene(name)
				if scene then scene:RegisterCallback("StateChange", scene_callback_fn) end
			end
			is_scene_callback_registered = true
		end
	else
		EVENT_MANAGER:UnregisterForEvent(ALC.name .. "_CombatState", EVENT_PLAYER_COMBAT_STATE)
		EVENT_MANAGER:UnregisterForEvent(ALC.name .. "_LowMem", EVENT_CONSOLE_ADD_ONS_MEMORY_LIMIT_REACHED)
		if LibAPH.UnregisterLowMemoryCallback then LibAPH.UnregisterLowMemoryCallback(ALC.name) end
		EVENT_MANAGER:UnregisterForUpdate(ALC.name .. "_PoolWatch")
		EVENT_MANAGER:UnregisterForUpdate(ALC.name .. "_AutoSweep")
		ALC.toggle_afk_watch()
		if is_scene_callback_registered then
			for name in pairs(HUD_SCENE_NAMES) do
				local scene = SCENE_MANAGER:GetScene(name)
				if scene then scene:UnregisterCallback("StateChange", scene_callback_fn) end
			end
			is_scene_callback_registered = false
		end
		EVENT_MANAGER:UnregisterForUpdate(ALC.name .. "_Fallback")
		mem_state = 0
		is_mem_check_queued = false
	end
end

function safe_csa(title, body, lifespan_ms)
	LibAPH.SafeCSA(ALC.settings.is_csa_enabled, title, body, lifespan_ms or 4000)
end

local CLEANUP_MODES = { "automatic", "vanilla", "background", "aggressive", "deep" }
local AUTO_SECOND_PASS_SHARE = 0.05
local AUTO_RECHECK_EVERY = 5
local last_after_lua
local auto_second_share
local auto_menu_runs = 0
local AUTO_PICK_SHOW_MS = 3000

function ALC.get_cleanup_modes()
	return CLEANUP_MODES
end

function ALC.get_cleanup_mode()
	local mode = ALC.settings.cleanup_mode
	for _, known in ipairs(ALC.get_cleanup_modes()) do
		if known == mode then return mode end
	end
	return "automatic"
end

function ALC.get_cleanup_mode_choices()
	local names, values, current = {}, {}, ALC.get_cleanup_mode()
	local tint = GetUIPlatform() == UI_PLATFORM_PC
	for index, mode in ipairs(CLEANUP_MODES) do
		local name = ALC.L("MODE_" .. mode:upper())
		if tint and mode == current then name = "|c00FF00" .. name .. "|r" end
		names[index], values[index] = name, mode
	end
	return names, values
end

function ALC.set_cleanup_mode(mode)
	ALC.settings.cleanup_mode = mode
	local dropdown = _G["ALC_CleanupModeDropdown"]
	if dropdown and dropdown.UpdateChoices then
		dropdown:UpdateChoices(ALC.get_cleanup_mode_choices())
		if dropdown.UpdateValue then dropdown:UpdateValue() end
	end
end

local function alc_gc_pass_count(opts)
	local passes = opts.mode == "aggressive" and 1 or 2
	if opts.extraPass then passes = passes + 1 end
	return passes
end

function ALC.get_min_growth_mb()
	local share = (ALC.settings.cleanup_min_growth_pct or 0) / 100
	return math.max(ALC.settings.cleanup_min_growth_mb or 0, (last_after_lua or 0) * share)
end

function ALC.get_growth_since_cleanup()
	if not last_after_lua then return nil end
	return math.max(ALC.get_hybrid_memory_data() - last_after_lua, 0)
end

function ALC.pick_auto_mode(forced)
	local lua_mb = collectgarbage("count") / 1024
	if not forced and last_after_lua then
		if lua_mb - last_after_lua < ALC.get_min_growth_mb() then return "vanilla" end
	end
	if IsUnitInCombat("player") or not LibAPH.IsPlayerInMenu() then return "background" end
	auto_menu_runs = auto_menu_runs + 1
	if auto_second_share and auto_second_share < AUTO_SECOND_PASS_SHARE and auto_menu_runs % AUTO_RECHECK_EVERY ~= 0 then
		return "aggressive"
	end
	return "deep"
end

local function alc_run_gc_pass(opts)
	opts = opts or {}
	local settle_before = opts.settleBeforeMs or 500
	local settle_after = opts.settleAfterMs or 200
	zo_callLater(function()
		local before_lua = collectgarbage("count") / 1024
		local before_pool = opts.getPoolMB and opts.getPoolMB() or 0

		local function report()
			zo_callLater(function()
				local after_lua = collectgarbage("count") / 1024
				local after_pool = opts.getPoolMB and opts.getPoolMB() or 0
				local freed_lua = math.max(before_lua - after_lua, 0)
				local freed_pool = math.max(before_pool - after_pool, 0)
				opts.onDone(before_lua, after_lua, freed_lua, before_pool, after_pool, freed_pool)
			end, settle_after)
		end

		local passes = alc_gc_pass_count(opts)
		local mode = opts.mode
		if mode ~= "aggressive" and mode ~= "deep" then
			LibAPH.StepCleanup(passes, report)
			return
		end
		local first_freed
		for pass = 1, passes do
			local before_pass = collectgarbage("count")
			collectgarbage("collect")
			local freed_pass = before_pass - collectgarbage("count")
			if pass == 1 then
				first_freed = freed_pass
			elseif pass == 2 and opts.measure then
				auto_second_share = first_freed > 0 and math.max(freed_pass, 0) / first_freed or 0
			end
		end
		report()
	end, settle_before)
end

local function report_cleanup(after_lua, freed, after_pool, freed_pool, note, force_feedback, quiet)
	mem_state = 0
	if cleanup_interrupted then
		cleanup_interrupted = false
		last_cleanup_time = nil
	else
		last_after_lua = after_lua
	end
	local reported = false

	if freed > 0.001 or freed_pool > 0.001 then
		reported = true
		ALC.session_mb_freed = ALC.session_mb_freed + freed
		ALC.session_pool_mb_freed = ALC.session_pool_mb_freed + freed_pool

		if not quiet then
			local msg = ALC.build_memory_status_line(after_lua, freed, after_pool, freed_pool)
			if note then msg = msg .. " |c888888(" .. note .. ")|r" end

			if ALC.settings.is_log_enabled then
				ALC.chat:Print(msg)
			end
			local body = build_memory_status_lines(after_lua, freed, after_pool, freed_pool)
			if note then body = note .. "\n" .. body end
			safe_csa(ALC.L("CSA_TITLE_CLEANED"), body)
		end
	elseif force_feedback then
		reported = true
		local msg = ALC.build_memory_status_line(after_lua, 0, after_pool, 0) .. " |c888888" .. ALC.L("LABEL_ALREADY_CLEAN") .. "|r"
		if note then msg = msg .. " |c888888(" .. note .. ")|r" end
		if ALC.settings.is_log_enabled then
			ALC.chat:Print(msg)
		end
		local body = build_memory_status_lines(after_lua, 0, after_pool, 0)
		if note then body = note .. "\n" .. body end
		safe_csa(ALC.L("CSA_TITLE_ALREADY_CLEAN"), body)
	end

	if note and reported then
		local shown = { text = note, at = GetGameTimeMilliseconds() }
		ALC.last_auto_pick = shown
		zo_callLater(function()
			if ALC.last_auto_pick ~= shown then return end
			ALC.last_auto_pick = nil
			if ALC.settings.show_ui then ALC.call_optional(ALC.update_ui, "UI module (update_ui)") end
		end, AUTO_PICK_SHOW_MS)
	end

	if ALC.settings.show_ui then ALC.call_optional(ALC.update_ui, "UI module (update_ui)") end
end

local function picked_note(picked)
	return picked and ALC.L("AUTO_PICKED", ALC.L("PICK_" .. picked:upper()))
end

local function report_result(result, force_feedback, by)
	local note = by and ALC.L("CLEANED_BY", by) or picked_note(result.picked)
	report_cleanup(result.afterLua, result.freedLua, result.afterPool, result.freedPool, note, force_feedback)
end

function ALC.track_shared_cleanups()
	if not LibAPH.RegisterCleanupListener then return end
	LibAPH.RegisterCleanupListener(ALC.name, function(result)
		if result.sources[ALC.name] then return end
		last_cleanup_time = GetGameTimeMilliseconds()
		report_result(result, false, result.source)
	end)
end

function ALC.run_manual_cleanup(force_feedback, reason, growth_checked)
	if LibAPH.RunCleanup then
		local method = ALC.get_cleanup_mode()
		local started = LibAPH.RunCleanup({
			method = method,
			source = ALC.name,
			force = force_feedback or (growth_checked and method ~= "vanilla"),
			reason = reason,
			onDone = function(result) report_result(result, force_feedback) end,
		})
		if started then
			mem_state = 1
			last_cleanup_time = GetGameTimeMilliseconds()
		end
		return
	end

	local mode, picked = ALC.get_cleanup_mode(), nil
	if mode == "vanilla" then
		if not force_feedback then return end
		mode = "background"
	elseif mode == "automatic" then
		mode = ALC.pick_auto_mode(force_feedback)
		if mode == "vanilla" then return end
		picked = mode
	end
	mem_state = 1
	last_cleanup_time = GetGameTimeMilliseconds()
	alc_run_gc_pass({
		mode = mode,
		measure = picked == "deep",
		getPoolMB = ALC.get_console_pool_mb,
		onDone = function(_, after_lua, freed, _, after_pool, freed_pool)
			report_cleanup(after_lua, freed, after_pool, freed_pool, picked_note(picked), force_feedback)
		end,
	})
end

local function grew_enough()
	if not last_after_lua then return true end
	return ALC.get_hybrid_memory_data() - last_after_lua >= ALC.get_min_growth_mb()
end

local function run_garbage_check(now_ms, delay_ms)
	if now_ms - (garbage_armed_at or now_ms) < delay_ms then return end
	if ALC.get_cleanup_mode() == "vanilla" or not LibAPH.RunCleanup then return end
	if not ALC.settings.garbage_check_ignore_growth and not grew_enough() then return end
	if IsUnitInCombat("player") or IsUnitDead("player") then return end
	mem_state, last_cleanup_time = 1, now_ms
	local started = LibAPH.RunCleanup({
		method = "background",
		source = ALC.name,
		force = true,
		onDone = function(result)
			report_cleanup(result.afterLua, result.freedLua, result.afterPool, result.freedPool, ALC.L("NOTE_GARBAGE_CHECK"), false, not ALC.settings.garbage_check_notices)
		end,
	})
	if not started then mem_state = 0 end
end

function trigger_memory_check(check_type, delay)
	if not ALC.settings.is_enabled then return end
	if mem_state == 1 or is_mem_check_queued then return end
	if LibAPH.IsCleanupRunning and LibAPH.IsCleanupRunning() then return end

	local now_ms = GetGameTimeMilliseconds()
	local fallback_ms = ALC.settings.fallback_delay_sec * 1000
	if (now_ms - (last_cleanup_time or 0)) < fallback_ms then return end

	local current_metric = ALC.get_active_memory_mb()
	local limit_threshold = get_active_threshold()

	if current_metric >= limit_threshold and grew_enough() then
		local in_combat = IsUnitInCombat("player")
		if in_combat or IsUnitDead("player") then
			if ALC.settings.show_ui then ALC.call_optional(ALC.update_ui, "UI module (update_ui)") end
			return
		end

		is_mem_check_queued = true
		zo_callLater(function()
			is_mem_check_queued = false
			if mem_state == 1 or (LibAPH.IsCleanupRunning and LibAPH.IsCleanupRunning()) then return end

			local still_in_combat = IsUnitInCombat("player")
			if still_in_combat or IsUnitDead("player") then
				if ALC.settings.show_ui then ALC.call_optional(ALC.update_ui, "UI module (update_ui)") end
				return
			end

			if check_type == "Menu" then
				local is_hud = SCENE_MANAGER:IsShowing("hud")
				local is_hudui = SCENE_MANAGER:IsShowing("hudui")
				local in_menu = not (is_hud or is_hudui)
				if not in_menu then return end
			end

			local recheck_metric = ALC.get_active_memory_mb()
			if recheck_metric >= limit_threshold and grew_enough() then
				ALC.run_manual_cleanup(false, nil, true)
				EVENT_MANAGER:UnregisterForUpdate(ALC.name .. "_Fallback")
				EVENT_MANAGER:RegisterForUpdate(ALC.name .. "_Fallback",
					ALC.settings.fallback_delay_sec * 1000,
					function() trigger_memory_check("Fallback", 0) end
				)
			end
		end, delay)
	else
		if current_metric < limit_threshold then
			EVENT_MANAGER:UnregisterForUpdate(ALC.name .. "_Fallback")
		end
		mem_state = 0
		run_garbage_check(now_ms, fallback_ms)
	end
end

function ALC.L(key, ...)
	local id = _G["SI_ALC_" .. key]
	local str = id and GetString(id) or key
	if select("#", ...) > 0 then
		return string.format(str, ...)
	end
	return str
end

function ALC.show_missing_library_warning()
	if not ALC.settings.is_lib_warning_enabled then return end

	local lam_ver, lam_en, lhas_ver, lhas_en = ALC.get_settings_library()

	local libwarn_templates = {
		missing = ALC.L("LIBWARN_MISSING"),
		disabled = ALC.L("LIBWARN_DISABLED"),
		old = ALC.L("LIBWARN_OLD"),
	}

	local alerts = {}
	local lam_alert = LibAPH.BuildLibraryWarning(libwarn_templates, "LibAddonMenu", "LAM", lam_ver, lam_en, REQUIRED_LAM_VERSION,
		ALC.L("LIBWARN_CONSEQUENCE_LAM"))
	if lam_alert then table.insert(alerts, lam_alert) end

	if is_gamepad_ui() then
		local lhas_alert = LibAPH.BuildLibraryWarning(libwarn_templates, "LibHarvensAddonSettings", "LHAS", lhas_ver, lhas_en, REQUIRED_LHAS_VERSION,
			ALC.L("LIBWARN_CONSEQUENCE_LHAS"))
		if lhas_alert then table.insert(alerts, lhas_alert) end
	end

	if #alerts == 0 then return end

	if not ALC.settings.has_shown_lib_warning_008 then
		local dialog_id = "ALC_MISSING_LIBRARY_WARN"
		local popup_title = "|cFF0000" .. ALC.L("DIALOG_MISSING_LIBRARY_TITLE") .. "|r"
		local popup_body = ALC.L("DIALOG_MISSING_LIBRARY_BODY") .. "\n\n" .. table.concat(alerts, "\n\n")

		local function on_ack()
			ALC.settings.has_shown_lib_warning_008 = true
			local tick_ms = GetGameTimeMilliseconds()
			if (tick_ms - last_priority_save_time) >= 900000 then
				GetAddOnManager():RequestAddOnSavedVariablesPrioritySave(ALC.name)
				last_priority_save_time = tick_ms
			end
		end

		LibAPH.RunWhenPlayerActivated(ALC.name .. "_LibWarnDialog", function()
			LibAPH.ShowDialogHidingWindows({ function() return GetControl("AutoLuaCleanerUI") end }, dialog_id, popup_title, popup_body,
				{ { text = ALC.L("BTN_ACKNOWLEDGE_CLOSE"), keybind = "DIALOG_PRIMARY", callback = on_ack } }, 0)
		end)
	end

	local combined_msg = table.concat(alerts, "\n")

	LibAPH.RunWhenPlayerActivated(ALC.name .. "_LibWarnChat", function()
		chat_error:Print(combined_msg)

		if not ALC.settings.has_shown_lib_warning_008 then
			local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, SOUNDS.NONE)
			params:SetText("|cFF0000" .. ALC.L("CSA_TITLE_SETTINGS_UNAVAILABLE") .. "|r", combined_msg)
			params:SetLifespanMS(10000)
			CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
		end
	end)
end

local POOL_RELOAD_MIN_FREED_MB = 0.5
local POOL_RELOAD_MIN_GROWTH_MB = 2
local POOL_RELOAD_SETTLE_MS = 500
local pool_floor_mb
local CLIENT_START_TOLERANCE_SEC = 5

local function get_client_start_time()
	return LibAPH.GetClientStartTime()
end

local function is_pool_reload_stuck_this_session()
	return LibAPH.IsSameClientSession(ALC.settings.pool_reload_stuck_client_start, CLIENT_START_TOLERANCE_SEC)
end

local ASK_MS = 5000
local ASK_GIVE_UP_CHECKS = 120

local function ui_windows()
	return { function() return GetControl("AutoLuaCleanerUI") end }
end

local function announce(title, text, color)
	local tinted = "|c" .. (color or "FFD700") .. text .. "|r"
	if title then safe_csa(title, tinted) else safe_csa(tinted) end
	if ALC.settings.is_log_enabled then ALC.chat:Print(tinted) end
end

local function lowmem_notice(title, text, color, lifespan_ms)
	if not ALC.settings.lowmem_notices then return end
	color = color or "FFD700"
	if title then LibAPH.SafeCSA(true, "|c" .. color .. title .. "|r", nil, lifespan_ms or 4000) end
	ALC.chat:Print("|c" .. color .. text .. "|r")
end

function save_and_reload()
	if LibAPH.RequestPrioritySaveForRunningAddons then
		LibAPH.RequestPrioritySaveForRunningAddons()
	elseif LibAPH.RequestPrioritySave then
		LibAPH.RequestPrioritySave(ALC.name)
	end
	ReloadUI("ingame")
end

local function ask_reload(dialog_id, title, text, on_yes, on_no)
	local answered = false
	LibAPH.ShowDialogHidingWindows(ui_windows(), dialog_id, title, text .. "\n\n" .. ALC.L("DLG_ASK_TIMEOUT", ASK_MS / 1000), {
		{ text = ALC.L("BTN_RELOAD_UI"), callback = function()
			answered = true
			on_yes()
		end },
		{ text = ALC.L("BTN_SKIP"), callback = function() end },
	}, nil, function()
		if not answered and on_no then on_no() end
	end)
	local shown_at, checks = nil, 0
	local function expire()
		checks = checks + 1
		local showing = ZO_Dialogs_IsShowing(dialog_id)
		if showing and not shown_at then shown_at = GetGameTimeMilliseconds() end
		if shown_at and not showing then return end
		if (shown_at and GetGameTimeMilliseconds() - shown_at >= ASK_MS) or checks > ASK_GIVE_UP_CHECKS then
			ZO_Dialogs_ReleaseDialog(dialog_id)
			return
		end
		zo_callLater(expire, 250)
	end
	zo_callLater(expire, 250)
end

function ALC.is_in_group_activity()
	if IsPlayerInRaid() or IsActiveWorldBattleground() or IsPlayerInAvAWorld() or IsInAvAZone() or IsInstanceEndlessDungeon() then return true end
	if IsUnitInDungeon("player") and (IsUnitGrouped("player") or GetCurrentZoneDungeonDifficulty() ~= DUNGEON_DIFFICULTY_NONE) then return true end
	if GetDuelInfo() ~= DUEL_STATE_IDLE then return true end
	local finder = GetActivityFinderStatus()
	return finder ~= ACTIVITY_FINDER_STATUS_NONE and finder ~= ACTIVITY_FINDER_STATUS_COMPLETE
end

function ALC.get_reload_memory_mb()
	if IsConsoleUI() then return ALC.get_console_pool_mb() end
	return ALC.get_hybrid_memory_data()
end

local function get_reload_threshold()
	if IsConsoleUI() then return ALC.settings.pool_threshold_console end
	return ALC.settings.reload_threshold_pc
end

local function start_pool_reload(memory_mb, my_token)
	if pool_reload_token ~= my_token then return end
	local threshold = get_reload_threshold()
	if memory_mb < threshold or memory_mb - pool_floor_mb < POOL_RELOAD_MIN_GROWTH_MB then return end
	if ALC.is_in_group_activity() or IsUnitInCombat("player") or IsUnitDead("player") then return end
	ALC.settings.last_pool_reload_time = GetTimeStamp()
	ALC.settings.pool_reload_test_pending = true
	ALC.settings.pool_reload_test_before_mb = ALC.get_console_pool_mb()
	ALC.settings.pool_reload_test_before_lua_mb = ALC.get_hybrid_memory_data()

	if not ALC.settings.pool_reload_confirm_auto then
		local text = ALC.L("CHAT_POOL_RELOAD_ASK", memory_mb)
		announce(ALC.L("DLG_POOL_RELOAD_CONFIRM_TITLE"), text)
		ask_reload("ALC_POOL_RELOAD_CONFIRM", ALC.L("DLG_POOL_RELOAD_CONFIRM_TITLE"), text, function()
			if pool_reload_token ~= my_token or not ALC.settings.auto_clear_pool_on_teleport then
				ALC.settings.pool_reload_test_pending = false
				return
			end
			save_and_reload()
		end, function() ALC.settings.pool_reload_test_pending = false end)
		return
	end

	local reload_delay_sec = ALC.settings.pool_reload_delay_sec or 3
	announce(nil, ALC.L("CHAT_POOL_RELOAD_NOTICE", reload_delay_sec), "00FFFF")

	zo_callLater(function()
		if pool_reload_token ~= my_token
			or not ALC.settings.auto_clear_pool_on_teleport
			or not IsPlayerActivated()
			or IsUnitInCombat("player")
			or IsUnitDead("player") then
			ALC.settings.pool_reload_test_pending = false
			return
		end
		save_and_reload()
	end, reload_delay_sec * 1000)
end

local function on_player_teleported()
	local memory_mb = ALC.get_reload_memory_mb()
	if not pool_floor_mb or memory_mb < pool_floor_mb then pool_floor_mb = memory_mb end
	if not ALC.settings.auto_clear_pool_on_teleport then return end

	if memory_mb < get_reload_threshold() then return end
	if memory_mb - pool_floor_mb < POOL_RELOAD_MIN_GROWTH_MB then return end
	if IsConsoleUI() and is_pool_reload_stuck_this_session() then return end
	if ALC.is_in_group_activity() then return end
	if GetTimeStamp() - (ALC.settings.last_pool_reload_time or 0) < ALC.settings.reload_cooldown_min * 60 then return end

	pool_reload_token = (pool_reload_token or 0) + 1
	local my_token = pool_reload_token
	collectgarbage("collect")
	zo_callLater(function() start_pool_reload(ALC.get_reload_memory_mb(), my_token) end, POOL_RELOAD_SETTLE_MS)
end

local AFK_POLL_MS = 1000
local afk_since, afk_zone, afk_x, afk_y, afk_z

local function afk_watch()
	local now = GetGameTimeMilliseconds()
	local zone, x, y, z = GetUnitRawWorldPosition("player")
	local first = afk_zone == nil
	local moved = IsPlayerMoving() or not first and (zone ~= afk_zone or x ~= afk_x or y ~= afk_y or z ~= afk_z)
	afk_zone, afk_x, afk_y, afk_z = zone, x, y, z
	if moved then ALC.settings.afk_reloaded = false end
	if first or moved or LibAPH.IsPlayerInMenu() or not IsPlayerActivated()
		or IsUnitInCombat("player") or IsUnitDead("player") or ALC.is_in_group_activity() then
		afk_since = now
		return
	end
	if ALC.settings.afk_reloaded or now - afk_since < ALC.settings.afk_reload_min * 60000 then return end
	ALC.settings.afk_reloaded = true
	if ALC.settings.is_log_enabled then ALC.chat:Print(ALC.L("CHAT_AFK_RELOAD", ALC.settings.afk_reload_min)) end
	save_and_reload()
end

function ALC.toggle_afk_watch()
	afk_since, afk_zone = nil, nil
	if ALC.settings.is_enabled and ALC.settings.afk_reload then
		EVENT_MANAGER:RegisterForUpdate(ALC.name .. "_AfkWatch", AFK_POLL_MS, afk_watch)
	else
		EVENT_MANAGER:UnregisterForUpdate(ALC.name .. "_AfkWatch")
	end
end

local function report_pool_reload_result(before_pool, before_lua, after_pool)
	local after_lua = ALC.get_hybrid_memory_data()
	local freed_pool = math.max(before_pool - after_pool, 0)
	if IsConsoleUI() and freed_pool < POOL_RELOAD_MIN_FREED_MB then
		ALC.settings.pool_reload_stuck_client_start = get_client_start_time()
		if ALC.settings.is_log_enabled then
			ALC.chat:Print("|cFFA500" .. ALC.L("CHAT_POOL_RELOAD_STUCK", after_pool) .. "|r")
		end
		safe_csa(ALC.L("CSA_TITLE_POOL_STUCK"), "|cFFD700" .. ALC.L("CHAT_POOL_RELOAD_STUCK", after_pool) .. "|r")
		if ALC.settings.show_ui then ALC.call_optional(ALC.update_ui, "UI module (update_ui)") end
		return
	end
	local freed_lua = math.max(before_lua - after_lua, 0)

	if freed_lua > 0.01 then ALC.session_mb_freed = ALC.session_mb_freed + freed_lua end
	if freed_pool > 0.01 then ALC.session_pool_mb_freed = ALC.session_pool_mb_freed + freed_pool end

	if ALC.settings.is_log_enabled then
		ALC.chat:Print(ALC.build_memory_status_line(after_lua, freed_lua, after_pool, freed_pool))
	end
	safe_csa(ALC.L("CSA_TITLE_POOL_CLEARED"), build_memory_status_lines(after_lua, freed_lua, after_pool, freed_pool))
	if ALC.settings.show_ui then ALC.call_optional(ALC.update_ui, "UI module (update_ui)") end
end

local function check_pool_reload_test_result()
	if not ALC.settings.pool_reload_test_pending then return end
	ALC.settings.pool_reload_test_pending = false

	local before_pool = ALC.settings.pool_reload_test_before_mb or 0
	local before_lua = ALC.settings.pool_reload_test_before_lua_mb or 0
	local last_reading = nil

	local function poll(attempt)
		local cur_pool = ALC.get_console_pool_mb()
		local settled = last_reading and math.abs(cur_pool - last_reading) < 0.01
		if settled or attempt >= 6 then
			report_pool_reload_result(before_pool, before_lua, cur_pool)
			return
		end
		last_reading = cur_pool
		zo_callLater(function() poll(attempt + 1) end, 500)
	end

	zo_callLater(function() poll(1) end, 500)
end

local POOL_KILL_SHARE = 0.9
local POOL_LINE_MARGIN_MB = 5
local POOL_CEILING_MARGIN_MB = 1.5
local POOL_STALL_MS = 10000
local pool_above_since, pool_reload_asked, relaunch_advised

local function advise_relaunch(used, cap)
	if relaunch_advised then return end
	relaunch_advised = true
	local text = ALC.L("CHAT_LOWMEM_RELAUNCH", used, cap)
	lowmem_notice(ALC.L("CSA_TITLE_LOWMEM_RELAUNCH"), text)
	LibAPH.ShowDialogHidingWindows(ui_windows(), "ALC_LOWMEM_RELAUNCH", ALC.L("CSA_TITLE_LOWMEM_RELAUNCH"), text,
		{ { text = ALC.L("BTN_ACKNOWLEDGE_CLOSE"), keybind = "DIALOG_PRIMARY", callback = function() end } })
end

local POOL_HEADING_MARGIN_MB = 0.5
local POOL_LOOKAHEAD_S = 1
local POOL_RATE_EVERY_MS = 250
local POOL_RATE_SAMPLES = 5
local pool_rate
local pool_sample_ms, pool_sample_mb = {}, {}

local function track_pool_rate(used, now)
	local count = #pool_sample_ms
	if count > 0 and now < pool_sample_ms[count] then
		for index = count, 1, -1 do pool_sample_ms[index], pool_sample_mb[index] = nil, nil end
		count = 0
	end
	if count > 0 and now - pool_sample_ms[count] < POOL_RATE_EVERY_MS then return end
	count = count + 1
	pool_sample_ms[count], pool_sample_mb[count] = now, used
	if count > POOL_RATE_SAMPLES then
		table.remove(pool_sample_ms, 1)
		table.remove(pool_sample_mb, 1)
		count = POOL_RATE_SAMPLES
	end
	if count < 3 or pool_sample_mb[count] <= pool_sample_mb[count - 1] or pool_sample_mb[count - 1] <= pool_sample_mb[count - 2] then
		pool_rate = 0
		return
	end
	pool_rate = (pool_sample_mb[count] - pool_sample_mb[1]) * 1000 / (pool_sample_ms[count] - pool_sample_ms[1])
end

local RESCUE_NOTICE_GAP_MS = 60000
local rescue, rescue_noticed_at

local function rescue_engine()
	return LibAPH.StartLowMemoryRescue and LibAPH or ALC.rescue_engine
end

function ALC.get_lowmem_lines(cap)
	local kill, start, stop, deep = rescue_engine().GetLowMemoryRescueLines(cap)
	return kill, start, stop, kill - POOL_LINE_MARGIN_MB, kill - POOL_CEILING_MARGIN_MB, deep
end

function ALC.is_rescuing()
	return rescue ~= nil
end

local function rescue_pass(result)
	if ALC.rescue_listener then ALC.rescue_listener(result) end
end

local function rescue_done(reached, totals)
	local r = rescue
	if not r then return end
	rescue = nil
	ALC.session_mb_freed = ALC.session_mb_freed + totals.freedLua
	ALC.session_pool_mb_freed = ALC.session_pool_mb_freed + totals.freedPool
	if reached then
		local seconds = math.floor(totals.tookMs / 1000 + 0.5)
		lowmem_notice(r.noticed and ALC.L("CSA_TITLE_RESCUE_DONE"), ALC.L("CHAT_RESCUE_DONE", ALC.get_console_pool_mb(), totals.freedPool, seconds), "00FF00")
	end
	if ALC.settings.show_ui then ALC.call_optional(ALC.update_ui, "UI module (update_ui)") end
end

local function rescue_can_run()
	return ALC.settings.is_enabled and not ALC.lowmem_held
end

function ALC.start_rescue(used, cap)
	if rescue or not rescue_can_run() then return end
	if not (used and cap) then used, cap = LibAPH.GetAddOnMemoryLimitMB() end
	if not (used and cap) then return end
	local r = {}
	rescue = r
	local started = rescue_engine().StartLowMemoryRescue({ source = ALC.name, used = used, cap = cap,
		canRun = rescue_can_run, onPass = rescue_pass, onDone = rescue_done })
	if not started then
		rescue = nil
		return
	end
	local now = GetGameTimeMilliseconds()
	if not rescue_noticed_at or now - rescue_noticed_at >= RESCUE_NOTICE_GAP_MS then
		rescue_noticed_at, r.noticed = now, true
		local _, _, stop = ALC.get_lowmem_lines(cap)
		lowmem_notice(ALC.L("CSA_TITLE_RESCUE"), ALC.L("CHAT_RESCUE_START", used, cap, stop))
	end
end

local function lowmem_reload_now(used, cap)
	ALC.settings.lowmem_reload_pending = true
	ALC.settings.lowmem_reload_before_mb = used
	lowmem_notice(ALC.L("CSA_TITLE_LOWMEM_RELOAD"), ALC.L("CHAT_LOWMEM_RELOADING", used, cap))
	save_and_reload()
end

function watch_add_on_pool()
	local used, cap = LibAPH.GetAddOnMemoryLimitMB()
	if not (used and cap) then return end
	local now = GetGameTimeMilliseconds()
	track_pool_rate(used, now)
	local kill, start = ALC.get_lowmem_lines(cap)
	if used >= start then ALC.start_rescue(used, cap) end
	if used <= kill - POOL_LINE_MARGIN_MB then
		pool_above_since, pool_reload_asked = nil, nil
		return
	end
	pool_above_since = pool_above_since or now
	if not (ALC.settings.lowmem_reload and IsConsoleUI()) or ALC.lowmem_held then return end
	if is_pool_reload_stuck_this_session() then return advise_relaunch(used, cap) end
	local heading = (pool_rate or 0) > 0 and used + pool_rate * POOL_LOOKAHEAD_S >= kill - POOL_HEADING_MARGIN_MB
	if used >= kill - POOL_CEILING_MARGIN_MB or heading then return lowmem_reload_now(used, cap) end
	if pool_reload_asked or now - pool_above_since < POOL_STALL_MS then return end
	pool_reload_asked = true
	local text = ALC.L("CHAT_LOWMEM_ASK", used, cap)
	lowmem_notice(ALC.L("CSA_TITLE_LOWMEM_ASK"), text)
	ask_reload("ALC_LOWMEM_RELOAD", ALC.L("DLG_LOWMEM_RELOAD_TITLE"), text, function()
		lowmem_reload_now(ALC.get_console_pool_mb(), cap)
	end)
end

function ALC.check_lowmem_reload_result()
	if not ALC.settings.lowmem_reload_pending then return end
	ALC.settings.lowmem_reload_pending = false
	local before = ALC.settings.lowmem_reload_before_mb or 0
	local last_reading
	local function poll(attempt)
		local cur_pool = ALC.get_console_pool_mb()
		local settled = last_reading and math.abs(cur_pool - last_reading) < 0.01
		if not settled and attempt < 6 then
			last_reading = cur_pool
			zo_callLater(function() poll(attempt + 1) end, 500)
			return
		end
		local cap = LibAPH.GetAddOnMemoryLimitMB and select(2, LibAPH.GetAddOnMemoryLimitMB())
		if cap and cur_pool > cap * POOL_KILL_SHARE - POOL_LINE_MARGIN_MB then
			ALC.settings.pool_reload_stuck_client_start = get_client_start_time()
			advise_relaunch(cur_pool, cap)
			return
		end
		lowmem_notice(ALC.L("CSA_TITLE_LOWMEM_RELOADED"), ALC.L("CHAT_LOWMEM_RELOAD_DONE", before, cap or 100, cur_pool), "00FF00", 8000)
	end
	LibAPH.RunWhenPlayerActivated(ALC.name .. "_LowMemReloadResult", function()
		zo_callLater(function() poll(1) end, 500)
	end)
end

function init(event_code, addon_name)
	if addon_name ~= ALC.name then return end
	EVENT_MANAGER:UnregisterForEvent(ALC.name, EVENT_ADD_ON_LOADED)

	ALC.chat = LibAPH.CreateChatLogger("ALC", "00FFFF")
	chat_error = LibAPH.CreateChatLogger("ALC Error", "FF0000")

	LibAPH.RegisterAddonDependencies(ALC.name, { "LibAPH" }, { "LibAddonMenu-2.0", "LibHarvensAddonSettings" })

	local active_world = GetWorldName() or "Default"
	local sv_name = "AutoLuaCleaner"
	local account = GetDisplayName()

	if _G[sv_name] and _G[sv_name][active_world] and _G[sv_name][active_world][account] then
		_G[sv_name][active_world] = nil
	end

	local existing_ns = _G[sv_name] and _G[sv_name]["Default"] and _G[sv_name]["Default"][account]
		and _G[sv_name]["Default"][account]["$AccountWide"]
	local existing_data = existing_ns and existing_ns[active_world]
	if existing_data and existing_data.schema_version ~= SCHEMA_VERSION then
		existing_ns[active_world] = nil
		d("|c00FFFF[ALC]|r " .. ALC.L("CHAT_SETTINGS_RESET_OLDVERSION"))
	end

	ALC.settings = ZO_SavedVars:NewAccountWide(
		sv_name, 1, active_world, ALC_defaults
	)
	ALC.settings.schema_version = SCHEMA_VERSION

	ALC.settings.module_disabled = ALC.settings.module_disabled or {}
	local migration_needs_run = (ALC.settings.migrated_version ~= ALC.version)
	if migration_needs_run then
		ALC.settings.module_disabled.migration = false
	end

	apply_module_disable_overrides()

	ALC.call_optional(ALC.migrate_data, "Migration module (migrate_data)")
	if migration_needs_run then
		ALC.settings.migrated_version = ALC.version
		ALC.settings.module_disabled.migration = true
	end
	check_pool_reload_test_result()
	ALC.check_lowmem_reload_result()

	if not ALC.settings.install_date then
		ALC.settings.install_date = get_today_date_str()
	end

	LibAPH.CheckSelfVersion(ALC.settings, ALC.version)

	ALC.session_mb_freed = 0
	ALC.session_pool_mb_freed = 0

	hook_error_capture()
	ALC.toggle_core_events()
	ALC.track_shared_cleanups()

	EVENT_MANAGER:RegisterForEvent(ALC.name, EVENT_PLAYER_ACTIVATED, function()
		trigger_memory_check("ZoneLoad", 5000)
		on_player_teleported()
	end)

	EVENT_MANAGER:RegisterForEvent(ALC.name .. "_PoolReloadGuard", EVENT_PLAYER_DEACTIVATED, function()
		pool_reload_token = (pool_reload_token or 0) + 1
	end)

	ALC.register_slash_commands()

	LibAPH.InitOnFirstShow(HUD_SCENE, function()
		ALC.call_optional(ALC.toggle_ui_update, "UI module (toggle_ui_update)")
	end)
	LibAPH.RunInitStages(ALC.name, {
		function() end,
		function() ALC.call_optional(ALC.build_lam2_menu, "Menu module (build_lam2_menu)") end,
		function()
			ALC.show_missing_library_warning()
			ALC.call_optional(ALC.run_wizard_if_needed, "Wizard module (run_wizard_if_needed)")
		end,
	})
end

EVENT_MANAGER:RegisterForEvent(
	ALC.name,
	EVENT_ADD_ON_LOADED,
	function(...) init(...) end
)