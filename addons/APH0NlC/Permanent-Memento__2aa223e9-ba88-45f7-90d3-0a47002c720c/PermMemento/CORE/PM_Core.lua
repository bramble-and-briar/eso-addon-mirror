--[[
    Copyright © 2025-2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

PMCore = PMCore or {}
local PM = PMCore
PM.state = PM.state or {}
PM.ui_refs = PM.ui_refs or {}
local PM_state = PM.state
local PM_ui_refs = PM.ui_refs

PM.name = "PermMemento"
PM.version = "2026.10.07.17.24"
PM.REQUIRED_LAM_VERSION = 43
PM.REQUIRED_LHAS_VERSION = 20200

PM._modules = {
	data = false,
	migration = false,
	loop = false,
	ui = false,
	sync = false,
	menu = false,
	wizard = false
}
local PM_modules = PM._modules

function PM.call_optional(fn, label, ...)
	return LibAPH.CallOptional(PM.acct_saved.warned_labels, "|cFF9900[PermMemento]|r",
		"is unavailable (its file did not load) - skipping.", fn, label, ...)
end

function PM.log_msg(msg)
	d("|cFF9900[PermMemento]|r " .. tostring(msg))
end

function PM.L(key, ...)
	local id = _G["SI_PM_" .. key]
	local str = id and GetString(id) or key
	if select("#", ...) > 0 then
		return string.format(str, ...)
	end
	return str
end

function PM.ensure_table(container, key)
	if not container[key] then container[key] = {} end
	return container[key]
end

PM.LITE_MODE_MODULES = { "migration", "ui", "sync" }
PM.LITE_MODE_SETTINGS = {
	is_stop_spinning = false,
	enable_random_fav = false,
	enable_learning = false,
	is_loop_in_combat = false,
	is_random_on_login = false,
	is_random_on_zone = false
}

function PM.apply_lite_mode()
	for _, mod_key in ipairs(PM.LITE_MODE_MODULES) do
		local already_disabled = PM.acct_saved.module_disabled and PM.acct_saved.module_disabled[mod_key]
		if not already_disabled then PM.toggle_module_disabled(mod_key, true) end
	end
	for setting_key, value in pairs(PM.LITE_MODE_SETTINGS) do
		PM.settings[setting_key] = value
	end
	if PM.settings.sync_module then PM.settings.sync_module.is_enabled = false end
	PM.acct_saved.wizard_lite_mode = true
end

function PM.matches_lite_mode_config()
	local md = PM.acct_saved.module_disabled or {}
	for _, mod_key in ipairs(PM.LITE_MODE_MODULES) do
		if not md[mod_key] then return false end
	end
	for setting_key, value in pairs(PM.LITE_MODE_SETTINGS) do
		if PM.settings[setting_key] ~= value then return false end
	end
	if PM.settings.sync_module and PM.settings.sync_module.is_enabled then return false end
	return true
end

PM.MODULE_FILE_FUNCS = {
	migration = { "migrate_data", "migrate_legacy_profiles" },
	ui = { "update_ui_anchor", "update_ui_scenes", "toggle_ui_update", "create_gamepad_mover", "create_ui", "reset_ui_position", "start_gamepad_move", "apply_ui_size" },
	sync = { "sync_engine.initialize" },
	menu = { "update_profile_list", "save_profile", "load_profile", "delete_profile",
			 "delete_learned_data", "delete_all_learned_data", "update_favorites_choices",
			 "toggle_favorite", "delete_all_favorites", "update_menu_choices",
			 "build_general_options", "build_module_manager_options",
			 "build_ui_position_options", "build_sync_options", "build_favorites_options",
			 "build_profile_options", "build_learned_data_options",
			 "build_delay_options", "build_commands_options", "build_menu",
			 "refresh_control_labels" },
	wizard = { "run_wizard_if_needed", "run_wizard", "finish_wizard" }
}

PM.COMMAND_REFERENCE = {
	{ section_key = "HEADER_GENERAL_SETTINGS", commands = {
		{ cmd = "/pmem <name>", alias = "/permmemento", desc_key = "CMD_DESC_FORCE_LOOP", available = function() return true end },
		{ cmd = "/pmemstop", alias = "/permmementostop", desc_key = "CMD_DESC_STOP_LOOP", available = function() return true end },
		{ cmd = "/pmemrand", alias = "/pmemrandom", desc_key = "CMD_DESC_ACTIVATE_RANDOM", available = function() return PM_modules.loop and PM.settings.enable_random_fav end },
		{ cmd = "/pmemrandzone", alias = "/pmemrandomzonechange", desc_key = "CMD_DESC_TOGGLE_ZONE_RAND", available = function() return PM_modules.loop and PM.settings.enable_random_fav end },
		{ cmd = "/pmemrandlog", alias = "/pmemrandomlogin", desc_key = "CMD_DESC_TOGGLE_LOGIN_RAND", available = function() return PM_modules.loop and PM.settings.enable_random_fav end },
		{ cmd = "/pmemfree", alias = "/pmemunrestrict", desc_key = "CMD_DESC_TOGGLE_UNRESTRICTED", available = function() return true end },
		{ cmd = "/pmempause", alias = "/pmemtogglepause", desc_key = "CMD_DESC_PAUSE_RESUME", available = function() return true end },
		{ cmd = "/pmembugreport", alias = "/pmembug", desc_key = "CMD_DESC_BUG_REPORT", available = function() return not IsConsoleUI() end },
	}},
	{ section_key = "HEADER_MODULE_MANAGER", commands = {
		{ cmd = "/pmemrandfav", desc_key = "CMD_DESC_TOGGLE_RANDFAV_MODULE", available = function() return true end },
		{ cmd = "/pmemlearn", desc_key = "CMD_DESC_TOGGLE_LEARNING_MODULE", available = function() return true end },
		{ cmd = "/pmemunloadsync", desc_key = "CMD_DESC_UNLOAD_SYNC", available = function() return true end },
		{ cmd = "/pmemunloadmigration", desc_key = "CMD_DESC_UNLOAD_MIGRATION", available = function() return true end },
		{ cmd = "/pmemunloadui", desc_key = "CMD_DESC_UNLOAD_UI", available = function() return true end },
		{ cmd = "/pmemunloadmenu", desc_key = "CMD_DESC_UNLOAD_MENU", available = function() return true end },
		{ cmd = "/pmemunloadwizard", desc_key = "CMD_DESC_UNLOAD_WIZARD", available = function() return true end },
	}},
	{ section_key = "HEADER_CONFIGURE_UI_POSITIONS", commands = {
		{ cmd = "/pmemui", alias = "/pmemtoggleui", desc_key = "CMD_DESC_TOGGLE_STATUS_DISPLAY", available = function() return PM_modules.ui end },
		{ cmd = "/pmemhud", alias = "/pmemuimode", desc_key = "CMD_DESC_TOGGLE_HUD_MENU", available = function() return PM_modules.ui end },
		{ cmd = "/pmemlock", alias = "/pmemuilock", desc_key = "CMD_DESC_LOCK_UNLOCK_UI", available = function() return PM_modules.ui end },
		{ cmd = "/pmemresetui", alias = "/pmemuireset", desc_key = "CMD_DESC_RESET_UI_SCALE_POS", available = function() return PM_modules.ui end },
		{ cmd = "/pmemhudscale <val>", alias = "/pmemsethudscale", desc_key = "CMD_DESC_SET_HUD_SCALE", available = function() return PM_modules.ui end },
		{ cmd = "/pmemmenuscale <val>", alias = "/pmemsetmenuscale", desc_key = "CMD_DESC_SET_MENU_SCALE", available = function() return PM_modules.ui end },
	}},
	{ section_key = "HEADER_SYNC_SETTINGS", commands = {
		{ cmd = "/pmsync <name>", alias = "/permmementosync", desc_key = "CMD_DESC_SEND_SYNC_REQUEST", available = function() return PM_modules.sync and PM.settings.sync_module.is_enabled end },
		{ cmd = "/pmsyncrand", alias = "/permmementosyncrandom", desc_key = "CMD_DESC_SEND_RANDOM_SYNC", available = function() return PM_modules.sync and PM_modules.loop and PM.settings.sync_module.is_enabled end },
		{ cmd = "/pmsyncstop", alias = "/permmementosyncstop", desc_key = "CMD_DESC_SEND_STOP_REQUEST", available = function() return PM_modules.sync and PM.settings.sync_module.is_enabled end },
		{ cmd = "/pmsyncon", alias = "/pmemsyncenable", desc_key = "CMD_DESC_TOGGLE_SYNC_LISTENING", available = function() return PM_modules.sync and not IsConsoleUI() end },
		{ cmd = "/pmsyncdelay", alias = "/pmemsyncrandomdelay", desc_key = "CMD_DESC_TOGGLE_RANDOM_SYNC_DELAY", available = function() return PM_modules.sync and not IsConsoleUI() and PM.settings.sync_module.is_enabled end },
	}},
	{ section_key = "HEADER_FAVORITES_MANAGER", commands = {
		{ cmd = "/pmemwipefav", alias = "/pmemdeleteallfavorites", desc_key = "CMD_DESC_CLEAR_ALL_FAVORITES", available = function() return PM_modules.menu and PM.settings.enable_random_fav end },
	}},
	{ section_key = "HEADER_PROFILE_MANAGER", commands = {
		{ cmd = "/pmemacct", alias = "/pmemuseaccountsettings", desc_key = "CMD_DESC_TOGGLE_ACCOUNT_SETTINGS", available = function() return true end },
	}},
	{ section_key = "HEADER_LEARNED_DATA_MGMT", commands = {
		{ cmd = "/pmemscan", alias = "/pmemautolearn", desc_key = "CMD_DESC_START_AUTOSCAN", available = function() return PM_modules.loop and PM.settings.enable_learning end },
		{ cmd = "/pmemlist", alias = "/pmemlearned", desc_key = "CMD_DESC_LIST_LEARNED", available = function() return PM.settings.enable_learning end },
		{ cmd = "/pmemplay <name>", alias = "/pmemactivatelearned", desc_key = "CMD_DESC_FORCE_LOOP_LEARNED", available = function() return PM_modules.loop and PM.settings.enable_learning end },
		{ cmd = "/pmemrandlrn", alias = "/pmemrandomlearned", desc_key = "CMD_DESC_ACTIVATE_RANDOM_LEARNED", available = function() return PM_modules.loop and PM.settings.enable_learning end },
		{ cmd = "/pmemwipe", alias = "/pmemdeletealllearned", desc_key = "CMD_DESC_WIPE_ALL_LEARNED", available = function() return PM_modules.menu and PM.settings.enable_learning end },
	}},
	{ section_key = "SECTION_ANNOUNCE_DELAYS", commands = {
		{ cmd = "/pmemcsa", alias = "/pmemtogglecsa", desc_key = "CMD_DESC_TOGGLE_SCREEN_ANNOUNCE", available = function() return true end },
		{ cmd = "/pmemset <name> <val>", desc_key = "CMD_DESC_SET_DELAY_DURATION", available = function() return true end },
	}},
	{ section_key = "HEADER_ADVANCED_SETTINGS", commands = {
		{ cmd = "/pmemcombat", alias = "/pmemloopincombat", desc_key = "CMD_DESC_TOGGLE_LOOP_IN_COMBAT", available = function() return true end },
		{ cmd = "/pmemreset", alias = "/pmemresetdefaults", desc_key = "CMD_DESC_RESET_TO_DEFAULTS", available = function() return true end },
		{ cmd = "/pmemwizard", desc_key = "CMD_DESC_RERUN_WIZARD", available = function() return PM_modules.wizard end },
		{ cmd = "/pmemlibwarn", desc_key = "CMD_DESC_TOGGLE_LIB_WARNING", available = function() return true end },
		{ cmd = "/pmemlogs", alias = "/pmemchatlogs", desc_key = "CMD_DESC_TOGGLE_CHAT_LOGS", available = function() return not IsConsoleUI() end },
		{ cmd = "/pmemnospin", alias = "/pmemstopspinning", desc_key = "CMD_DESC_TOGGLE_STOP_SPINNING", available = function() return not IsConsoleUI() end },
		{ cmd = "/pmemclientinfo", desc_key = "CMD_DESC_PRINT_CLIENT_INFO", available = function() return true end },
	}}
}

function PM.get_menu_layout()
	local sync = PM.settings.sync_module
	return table.concat({
		tostring(PM.settings.enable_random_fav and true or false), tostring(PM.settings.enable_learning and true or false),
		tostring(sync and sync.is_enabled and true or false),
	}, ",")
end

function PM.refresh_slash_commands()
	if not PM.settings then return end
	if PM.menu_layout and PM.menu_layout ~= PM.get_menu_layout() then
		zo_callLater(function() PM.chat:Print(PM.L("CHAT_RELOAD_TO_APPLY")) end, 0)
	end
	if not LibAPH.SetSlashCommandsShown then return end
	for _, sect in ipairs(PM.COMMAND_REFERENCE) do
		for _, entry in ipairs(sect.commands) do
			local names = { entry.cmd:match("^(%S+)") }
			if entry.alias then names[#names + 1] = entry.alias end
			LibAPH.SetSlashCommandsShown(names, entry.available() and true or false)
		end
	end
end

function PM.build_command_reference_text(double_spaced)
	local sep = double_spaced and "\n\n" or "\n"
	local parts = {}
	for _, sect in ipairs(PM.COMMAND_REFERENCE) do
		local sect_lines = {}
		for _, entry in ipairs(sect.commands) do
			if entry.available() then
				table.insert(sect_lines, "|c00FFFF" .. entry.cmd .. "|r |cFFD700- " .. PM.L(entry.desc_key) .. "|r" .. sep)
			end
		end
		if #sect_lines > 0 then
			table.insert(parts, "|c9CD04C-- " .. PM.L(sect.section_key) .. " --|r" .. sep)
			for _, l in ipairs(sect_lines) do table.insert(parts, l) end
		end
	end
	return table.concat(parts)
end

function PM.reset_to_defaults()
	LibAPH.ResetToDefaults(PM.settings, PM.defaults, {
		learned_data = true, favorites = true, total_loops = true,
		memento_usage = true, install_date = true, version_history = true,
		last_version = true, is_migrated_088 = true,
		has_shown_lib_warning_088 = true
	})
	PM.refresh_loop_event_registrations()
	PM.call_optional(PM.toggle_ui_update, "UI module (toggle_ui_update)")
	PM.refresh_slash_commands()
end

function PM.delete_all_character_profiles()
	local display_name = GetDisplayName()
	if _G["PermMemento"] and _G["PermMemento"]["Default"] then
		_G["PermMemento"]["Default"][display_name] = nil
	end
	PM.log_msg(PM.L("CHAT_CHAR_PROFILES_DELETED"), true, "settings", 90)
	ReloadUI("ingame")
end

function PM.toggle_module_disabled(mod_key, silent)
	local now_disabled = LibAPH.ToggleModuleDisabled(PM.acct_saved, PM.MODULE_FILE_FUNCS, mod_key,
		function(disabled, key)
			PM.log_msg(
				(disabled and PM.L("MODULE_TOGGLE_UNLOADED", key) or PM.L("MODULE_TOGGLE_REENABLED", key)) ..
				(LibAPH.HasModuleLifecycle(key) and PM.L("MODULE_TOGGLE_LIVE") or PM.L("MODULE_TOGGLE_RELOAD")),
				true, "settings", 90
			)
		end, silent)
	LibAPH.SyncModuleLifecycle(PM_modules, mod_key, now_disabled)
	PM_state.cached_stats_suffix = nil
	PM.refresh_slash_commands()
	if not now_disabled then
		PM.acct_saved.warned_labels = {}
	end
	return now_disabled
end

function PM.apply_module_disable_overrides()
	PM.ensure_table(PM.acct_saved, "module_disabled")
	PM.ensure_table(PM.acct_saved, "warned_labels")
	if IsConsoleUI() and PM.acct_saved.module_disabled.sync == nil then
		PM.acct_saved.module_disabled.sync = true
	end
	PM_state.module_disabled_snapshot = ZO_ShallowTableCopy(PM.acct_saved.module_disabled)
	LibAPH.ApplyModuleDisableOverrides(PM.acct_saved, PM.MODULE_FILE_FUNCS, PM_modules,
		function(fname)
			if fname == "sync_engine.initialize" then
				PM.sync_engine = {}
			else
				PM[fname] = nil
			end
		end,
		function(fname)
			if fname == "sync_engine.initialize" then return PM.sync_engine and PM.sync_engine.initialize end
			return PM[fname]
		end)
end

PM.defaults = {
	active_id = nil,
	pending_sync_id = nil,
	is_paused = false,
	is_log_enabled = false,
	is_csa_enabled = true,
	is_random_on_login = false,
	is_random_on_zone = false,
	is_loop_in_combat = false,
	use_account_settings = false,
	show_in_hud = false,
	is_ui_global = false,
	is_unrestricted = false,
	enable_random_fav = false,
	enable_learning = false,
	is_stop_spinning = false,
	is_migrated_088 = false,
	has_shown_lib_warning_088 = false,
	is_lib_warning_enabled = true,
	active_profile = nil,
	last_version = "0.8.6",
	version_history = {},
	learned_data = {},
	favorites = {},
	total_loops = 0,
	memento_usage = {},
	install_date = nil,
	delay_idle = 3,
	delay_in_menu = 5,
	delay_combat_end = 5,
	delay_resurrect = 3,
	delay_teleport = 5,
	delay_dead = 3,
	delay_crafting = 5,
	delay_attack = 3,
	delay_move = 3,
	delay_block = 3,
	delay_swim = 3,
	delay_sneak = 3,
	delay_mount = 3,
	delay_cast = 3,

	busy_check_teleport = true,
	busy_check_dead = true,
	busy_check_crafting = true,
	busy_check_interacting = true,
	busy_check_menu = true,
	busy_check_resurrecting = true,
	busy_check_blocking = true,
	busy_check_attacking = true,
	busy_check_casting = true,
	busy_check_swimming = true,
	busy_check_mounted = true,
	busy_check_sneaking = true,
	busy_check_moving = true,
	csa_durations = {
		activation = 3, stop = 3, sync = 3, ui = 3,
		random = 3, error = 3, settings = 3
	},
	ui = {
		left = 1627, top = 32, is_locked = false, is_hidden = true,
		scale = (IsConsoleUI() and 1.0 or 1.0), width = nil, height = nil
	},
	ui_menu = {
		left = -1, top = -1, scale = (IsConsoleUI() and 1.2 or 1.0), width = nil, height = nil
	},
	sync_module = {
		delay = 0, is_random = false, ignore_in_combat = true, is_enabled = false
	}
}

PM_state.is_looping = false
PM_state.is_scanning = false
PM_state.loop_token = 0
PM.movement_tracker = LibAPH.CreateMovementTracker()
PM_state.is_moving = false
PM.teleport_tracker = LibAPH.CreateTeleportTracker()
PM_state.is_sync_firing = false
PM_state.sync_auto_suspended = false
PM_state.was_in_sync_protected_zone = false
PM_state.next_fire_time = 0
PM_state.learned_count = 0
PM_state.session_loops = 0
PM_state.current_fav_count = 0
PM_state.current_sv_size_kb = 0
PM_state.next_random_precalc = nil
PM_state.last_priority_save_time = 0
PM.sync_engine = PM.sync_engine or {}
PM_state.is_menu_built = false
PM_state.active_names = {}
PM_state.active_ids = {}
PM_state.sync_names = {}
PM_state.sync_ids = {}
PM_state.learned_list_names = {}
PM_state.learned_list_values = {}
PM_state.fav_all_names = {}
PM_state.fav_all_ids = {}
PM_state.fav_current_names = {}
PM_state.fav_current_ids = {}
PM_state.char_list_values = {}
PM_state.char_list_names = {}
PM_state.selected_sync_id = nil
PM_state.pending_id = nil
PM_state.selected_char_copy = nil
PM_state.selected_char_delete = nil
PM_state.selected_learned_id = nil
PM_state.selected_fav_candidate = nil
PM_state.selected_fav_removal = nil
PM_ui_refs.ctrl_active_dropdown = nil
PM_ui_refs.ctrl_sync_dropdown = nil
PM_ui_refs.ctrl_learned_dropdown = nil
PM_ui_refs.ctrl_fav_candidate_dropdown = nil
PM_ui_refs.ctrl_fav_remove_dropdown = nil
PM_ui_refs.ui_update_fn = nil

function PM.get_settings_library()
	local lam_v, lam_e = LibAPH.CheckLibraryVersion("LibAddonMenu-2.0")
	local lhas_v, lhas_e = LibAPH.CheckLibraryVersion("LibHarvensAddonSettings")
	return lam_v, lam_e, lhas_v, lhas_e
end

function PM.show_missing_library_warning()
	if not PM.settings.is_lib_warning_enabled then return end

	local lam_ver, lam_en, lhas_ver, lhas_en = PM.get_settings_library()

	local libwarn_templates = {
		missing = PM.L("LIBWARN_MISSING"),
		disabled = PM.L("LIBWARN_DISABLED"),
		old = PM.L("LIBWARN_OLD"),
	}

	local alerts = {}
	local lam_alert = LibAPH.BuildLibraryWarning(libwarn_templates, "LibAddonMenu", "LAM", lam_ver, lam_en, PM.REQUIRED_LAM_VERSION,
		PM.L("LIBWARN_CONSEQUENCE_LAM"))
	if lam_alert then table.insert(alerts, lam_alert) end

	if IsConsoleUI() then
		local lhas_alert = LibAPH.BuildLibraryWarning(libwarn_templates, "LibHarvensAddonSettings", "LHAS", lhas_ver, lhas_en, PM.REQUIRED_LHAS_VERSION,
			PM.L("LIBWARN_CONSEQUENCE_LHAS"))
		if lhas_alert then table.insert(alerts, lhas_alert) end
	end

	if #alerts == 0 then return end

	if not PM.settings.has_shown_lib_warning_088 then
		local dialog_id = "PM_MISSING_LIBRARY_WARN"
		local popup_title = "|cFF0000" .. PM.L("DIALOG_MISSING_LIBRARY_TITLE") .. "|r"
		local popup_body = PM.L("DIALOG_MISSING_LIBRARY_BODY") .. "\n\n" .. table.concat(alerts, "\n\n")

		local function on_ack()
			PM.settings.has_shown_lib_warning_088 = true
			local tick_ms = GetGameTimeMilliseconds()
			if (tick_ms - PM_state.last_priority_save_time) >= 900000 then
				GetAddOnManager():RequestAddOnSavedVariablesPrioritySave(PM.name)
				PM_state.last_priority_save_time = tick_ms
			end
		end

		LibAPH.RunWhenPlayerActivated(PM.name .. "_LibWarnDialog", function()
			LibAPH.ShowDialogHidingWindows({ function() return GetControl("PermMementoUI") end }, dialog_id, popup_title, popup_body,
				{ { text = PM.L("BTN_ACKNOWLEDGE_CLOSE"), keybind = "DIALOG_PRIMARY", callback = on_ack } }, 0)
		end)
	end

	local combined_msg = table.concat(alerts, "\n")

	LibAPH.RunWhenPlayerActivated(PM.name .. "_LibWarnChat", function()
		PM.chat_error:Print(combined_msg)

		if not PM.settings.has_shown_lib_warning_088 then
			local params = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, SOUNDS.NONE)
			params:SetText("|cFF0000" .. PM.L("CSA_TITLE_SETTINGS_UNAVAILABLE") .. "|r", combined_msg)
			params:SetLifespanMS(10000)
			CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(params)
		end
	end)
end

function PM.get_platform_str()
	local platform = LibAPH.GetPlatformString()
	if platform == "PC" then
		local service = LibAPH.GetPlatformServiceName()
		if service then return "PC (" .. service .. ")" end
		return "PC"
	elseif platform then
		return platform
	end
	return PM.L("LABEL_UNKNOWN")
end

function PM.get_today_date_str()
	local d = GetDate()
	if d and type(d) == "number" then d = tostring(d) end
	if d and string.len(d) == 8 then
		return string.sub(d, 1, 4) .. "/" .. string.sub(d, 5, 6) .. "/" .. string.sub(d, 7, 8)
	end
	return GetDateStringFromTimestamp(GetTimeStamp())
end

function PM.toggle_stats_ui_tracker()
	if not PM.settings then return end
	EVENT_MANAGER:RegisterForUpdate(PM.name .. "_StatsUpdate", 1000, function()
		local s_ctrl = _G["PM_StatsText"]
		if s_ctrl and s_ctrl.desc and not s_ctrl:IsHidden() then
			s_ctrl.desc:SetText(PM.call_optional(PM.get_stats_text, "Loop module (get_stats_text)") or "")
		end
	end)
end

function PM.toggle_sync_listener()
	if not PM.settings then return end
	PM_state.sync_listening = PM.settings.sync_module.is_enabled and PM_state.sync_running == true
end

local function is_in_sync_protected_zone()
	return IsUnitInDungeon("player")
		or IsPlayerInRaid()
		or IsActiveWorldBattleground()
		or IsInAvAZone()
end

function PM.check_sync_zone_protection()
	if not PM.settings or not PM.settings.sync_module then return end
	local is_protected = is_in_sync_protected_zone()

	if is_protected and not PM_state.was_in_sync_protected_zone then
		if PM.settings.sync_module.is_enabled then
			PM_state.sync_auto_suspended = true
			PM.log_msg(PM.L("CHAT_SYNC_AUTO_SUSPENDED"), true, "sync", 90)
		end
	elseif not is_protected and PM_state.was_in_sync_protected_zone then
		if PM_state.sync_auto_suspended then
			PM_state.sync_auto_suspended = false
			PM.toggle_sync_listener()
			PM.log_msg(PM.L("CHAT_SYNC_AUTO_RESUMED"), true, "sync", 90)
		end
	end

	PM_state.was_in_sync_protected_zone = is_protected
end

function PM.trigger_priority_save()
	local tick_ms = GetGameTimeMilliseconds()
	if (tick_ms - PM_state.last_priority_save_time) >= 900000 then
		GetAddOnManager():RequestAddOnSavedVariablesPrioritySave(PM.name)
		PM_state.last_priority_save_time = tick_ms
	end
end

function PM.get_data(target_id)
	if PM.memento_data[target_id] then return PM.memento_data[target_id] end
	if PM.acct_saved and PM.acct_saved.learned_data then
		if PM.acct_saved.learned_data[target_id] then
			return PM.acct_saved.learned_data[target_id]
		end
	end
	if PM.settings.is_unrestricted then
		return {
			id = target_id, ref_id = 0, dur = 10000,
			name = (GetCollectibleName(target_id) or "Unknown")
		}
	end
	return nil
end
