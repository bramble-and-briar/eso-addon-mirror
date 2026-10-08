--[[
    Copyright © 2025-2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

PMCore = PMCore or {}
local PM = PMCore
local dismiss_captured_error, get_bug_report_settings_fields, show_copy_text_box
local PM_defaults = PM.defaults
local PM_modules = PM._modules
local PM_state = PM.state
local PM_ui_refs = PM.ui_refs
local session_bugs = {}
local build_delay_trigger_options

local function only_built(...)
	local list = {}
	for index = 1, select("#", ...) do
		local control = select(index, ...)
		if control then list[#list + 1] = control end
	end
	return list
end

local function show_menu_scene(scene)
	return LibAPH.ShowMenuScene(scene)
end

local function after_scene_shown(scene, fn)
	return LibAPH.AfterSceneShown(scene, fn)
end

function PM.update_profile_list()
	PM_state.profile_list_names = {}
	PM_state.profile_list_values = {}
	local raw_names = {}

	if PM.acct_saved and PM.acct_saved.profiles then
		for p_name, _ in pairs(PM.acct_saved.profiles) do
			table.insert(raw_names, p_name)
		end
	end
	table.sort(raw_names)

	for _, p_name in ipairs(raw_names) do
		local display_name = p_name
		if PM.settings and PM.settings.active_profile == p_name then
			display_name = "|c00FF00" .. p_name .. "|r"
		end
		table.insert(PM_state.profile_list_names, display_name)
		table.insert(PM_state.profile_list_values, p_name)
	end

	if #PM_state.profile_list_names == 0 then
		table.insert(PM_state.profile_list_names, PM.L("LABEL_NONE"))
		table.insert(PM_state.profile_list_values, "")
	end

	local ddl = _G["PM_ProfileDropdown"]
	if ddl and ddl.UpdateChoices then
		ddl:UpdateChoices(PM_state.profile_list_names, PM_state.profile_list_values)
		ddl:UpdateValue(false, PM_state.selected_profile_name or "")
	end
end

function PM.save_profile(p_name)
	if not p_name or p_name == "" then
		PM.log_msg(PM.L("CHAT_PROFILE_NAME_EMPTY"), true, "error"); return
	end
	PM.ensure_table(PM.acct_saved, "profiles")

	local exclude = {
		learned_data = true, favorites = true, total_loops = true,
		memento_usage = true, install_date = true, version_history = true,
		last_version = true, is_migrated_088 = true,
		has_shown_lib_warning_088 = true,
		active_profile = true
	}

	local new_prof = {}
	for k, v in pairs(PM.settings) do
		if not exclude[k] then
			if type(v) == "table" then
				new_prof[k] = ZO_DeepTableCopy(v)
			else
				new_prof[k] = v
			end
		end
	end

	PM.settings.active_profile = p_name
	PM.acct_saved.profiles[p_name] = new_prof
	PM.log_msg(PM.L("CHAT_PROFILE_SAVED", p_name), true, "settings", 90)
	PM_ui_refs.profile_input_text = ""
	PM_state.selected_profile_name = p_name
	PM.update_profile_list()
	if IsConsoleUI() then
		zo_callLater(function() ReloadUI("ingame") end, 1000)
	end
end

function PM.load_profile(p_name)
	if not p_name or p_name == "" then
		PM.log_msg(PM.L("CHAT_NO_PROFILE_TO_LOAD"), true, "error"); return
	end
	if PM.acct_saved.profiles and PM.acct_saved.profiles[p_name] then
		local p_data = PM.acct_saved.profiles[p_name]
		for k, v in pairs(p_data) do
			if type(v) == "table" then
				PM.settings[k] = ZO_DeepTableCopy(v)
			else
				PM.settings[k] = v
			end
		end
		PM.settings.active_profile = p_name
		PM.log_msg(PM.L("CHAT_PROFILE_LOADED", p_name), true, "settings", 90)
		zo_callLater(function() ReloadUI("ingame") end, 1000)
	end
end

function PM.delete_profile(p_name)
	if not p_name or p_name == "" then
		PM.log_msg(PM.L("CHAT_NO_PROFILE_TO_DELETE"), true, "error"); return
	end
	if PM.acct_saved.profiles and PM.acct_saved.profiles[p_name] then
		PM.acct_saved.profiles[p_name] = nil
		if PM.settings.active_profile == p_name then
			PM.settings.active_profile = nil
		end
		PM.log_msg(PM.L("CHAT_PROFILE_DELETED", p_name), true, "settings", 90)
		if PM_state.selected_profile_name == p_name then PM_state.selected_profile_name = "" end
		PM.update_profile_list()
		if IsConsoleUI() then
			zo_callLater(function() ReloadUI("ingame") end, 1000)
		end
	end
end

function PM.delete_learned_data(del_id)
	if not del_id or del_id == 0 then return end
	if PM.acct_saved and PM.acct_saved.learned_data then
		PM.acct_saved.learned_data[del_id] = nil
		PM.log_msg(PM.L("CHAT_LEARNED_DATA_DELETED"), true, "settings", 90)
		PM.update_menu_choices()
		local lrn_ddl = _G["PM_LearnedDropdown"]
		if lrn_ddl then lrn_ddl:UpdateValue(false, 0) end
	end
end

function PM.delete_all_learned_data()
	if PM.acct_saved and PM.acct_saved.learned_data then
		PM.acct_saved.learned_data = {}
		PM.log_msg(PM.L("CHAT_ALL_LEARNED_DATA_DELETED"), true, "settings", 90)
		PM.update_menu_choices()
		local lrn_ddl = _G["PM_LearnedDropdown"]
		if lrn_ddl then lrn_ddl:UpdateValue(false, 0) end
	end
end

function PM.update_favorites_choices()
	PM.call_optional(PM.update_fav_count, "Loop module (update_fav_count)")
	PM_state.fav_all_names, PM_state.fav_all_ids = {}, {}
	PM_state.fav_current_names, PM_state.fav_current_ids = {PM.L("LABEL_NONE")}, {0}

	local arr_all = {}
	local max_cat = GetTotalCollectiblesByCategoryType(COLLECTIBLE_CATEGORY_TYPE_MEMENTO)
	for i = 1, max_cat do
		local f_id = GetCollectibleIdFromType(COLLECTIBLE_CATEGORY_TYPE_MEMENTO, i)
		if f_id and IsCollectibleUnlocked(f_id) then
			table.insert(arr_all, {name=GetCollectibleName(f_id), id=f_id})
		end
	end
	table.sort(arr_all, function(a,b) return a.name < b.name end)
	for _, t in ipairs(arr_all) do
		local f_str = t.name; local md = PM.get_data(t.id)
		if md then f_str = f_str .. string.format(" (%ds)", md.dur / 1000) end
		if PM.settings.favorites[t.id] then f_str = "|c00FF00" .. f_str .. " (" .. PM.L("LABEL_FAV") .. ")|r" end
		table.insert(PM_state.fav_all_names, f_str); table.insert(PM_state.fav_all_ids, t.id)
	end

	local arr_fav = {}
	if PM.settings and PM.settings.favorites then
		for f_id, is_fav in pairs(PM.settings.favorites) do
			if is_fav and IsCollectibleUnlocked(f_id) then
				table.insert(arr_fav, {name=GetCollectibleName(f_id), id=f_id})
			end
		end
	end
	table.sort(arr_fav, function(a,b) return a.name < b.name end)
	for _, t in ipairs(arr_fav) do
		local f_str = t.name; local md = PM.get_data(t.id)
		if md then f_str = f_str .. string.format(" (%ds)", md.dur / 1000) end
		table.insert(PM_state.fav_current_names, f_str); table.insert(PM_state.fav_current_ids, t.id)
	end

	local cand_ddl = _G["PM_FavCandidateDropdown"]
	if cand_ddl and cand_ddl.UpdateChoices then
		cand_ddl:UpdateChoices(PM_state.fav_all_names, PM_state.fav_all_ids)
		cand_ddl:UpdateValue()
	end

	local rem_ddl = _G["PM_FavRemoveDropdown"]
	if rem_ddl and rem_ddl.UpdateChoices then
		rem_ddl:UpdateChoices(PM_state.fav_current_names, PM_state.fav_current_ids)
		rem_ddl:UpdateValue()
	end
end

function PM.toggle_favorite(f_id)
	if not f_id or f_id == 0 then return end
	PM.ensure_table(PM.settings, "favorites")
	if PM.settings.favorites[f_id] then
		PM.settings.favorites[f_id] = nil
		PM.log_msg(PM.L("CHAT_REMOVED_FROM_FAVORITES", GetCollectibleName(f_id)), true, "settings", 90)
	else
		PM.settings.favorites[f_id] = true
		PM.log_msg(PM.L("CHAT_ADDED_TO_FAVORITES", GetCollectibleName(f_id)), true, "settings", 90)
	end
	PM.update_favorites_choices()
end

function PM.delete_all_favorites()
	if PM.settings then PM.settings.favorites = {} end
	PM.log_msg(PM.L("CHAT_ALL_FAVORITES_CLEARED"), true, "settings", 90)
	PM.update_favorites_choices()
end

function PM.update_menu_choices()
	PM_state.active_names, PM_state.active_ids = {PM.L("LABEL_NONE")}, {0}
	local arr_act = {}
	for f_id, md in pairs(PM.memento_data) do
		if IsCollectibleUnlocked(f_id) then
			table.insert(arr_act, {name=md.name, id=f_id, dur=md.dur, stat=md.stationary})
		end
	end
	table.sort(arr_act, function(a,b) return a.name < b.name end)
	for _, t in ipairs(arr_act) do
		local stat_str = t.stat and (" (" .. PM.L("LABEL_STATIONARY") .. ")") or ""
		local f_str = string.format("%s (%ds)%s", t.name, t.dur / 1000, stat_str)
		if PM.settings and PM.settings.active_id == t.id then
			f_str = "|c00FF00" .. f_str .. "|r"
		end
		table.insert(PM_state.active_names, f_str); table.insert(PM_state.active_ids, t.id)
	end
	local act_ddl = _G["PM_ActiveDropdown"]
	if act_ddl and act_ddl.UpdateChoices then
		act_ddl:UpdateChoices(PM_state.active_names, PM_state.active_ids)
		act_ddl:UpdateValue()
	end

	PM_state.sync_names, PM_state.sync_ids = {PM.L("LABEL_NONE")}, {0}
	local arr_sync = {}
	local max_cat = GetTotalCollectiblesByCategoryType(COLLECTIBLE_CATEGORY_TYPE_MEMENTO)
	for i = 1, max_cat do
		local f_id = GetCollectibleIdFromType(COLLECTIBLE_CATEGORY_TYPE_MEMENTO, i)
		if f_id and IsCollectibleUnlocked(f_id) then
			table.insert(arr_sync, {name=GetCollectibleName(f_id), id=f_id})
		end
	end
	table.sort(arr_sync, function(a,b) return a.name < b.name end)
	for _, t in ipairs(arr_sync) do
		local f_str = t.name; local md = PM.get_data(t.id)
		if md then f_str = f_str .. string.format(" (%ds)", md.dur / 1000) end
		table.insert(PM_state.sync_names, f_str); table.insert(PM_state.sync_ids, t.id)
	end
	local sync_ddl = _G["PM_SyncDropdown"]
	if sync_ddl and sync_ddl.UpdateChoices then
		sync_ddl:UpdateChoices(PM_state.sync_names, PM_state.sync_ids)
		sync_ddl:UpdateValue()
	end

	PM_state.learned_list_names, PM_state.learned_list_values = {PM.L("LABEL_NONE")}, {0}
	if PM.acct_saved and PM.acct_saved.learned_data then
		local arr_lrn = {}
		for _, md in pairs(PM.acct_saved.learned_data) do table.insert(arr_lrn, md) end
		table.sort(arr_lrn, function(a,b) return a.name < b.name end)
		for _, md in ipairs(arr_lrn) do
			local f_str = md.name .. string.format(" (%ds)", md.dur / 1000)
			table.insert(PM_state.learned_list_names, f_str); table.insert(PM_state.learned_list_values, md.id)
		end
	end
	local lrn_ddl = _G["PM_LearnedDropdown"]
	if lrn_ddl and lrn_ddl.UpdateChoices then
		lrn_ddl:UpdateChoices(PM_state.learned_list_names, PM_state.learned_list_values)
		lrn_ddl:UpdateValue()
	end
end

function PM.dev_simulate_error()
	zo_callLater(function()
		error(PM.name .. ": THIS IS NOT A REAL ERROR, THIS IS A TEST ERROR")
	end, 1)
end

function dismiss_captured_error()
	ZO_ClearNumericallyIndexedTable(session_bugs)
	PM.show_bug_report_box()
end

function PM.wipe_all_bugs()
	ZO_ClearNumericallyIndexedTable(session_bugs)
	if PM_ui_refs.copy_box then PM_ui_refs.copy_box:Hide() end
end

function show_copy_text_box(sections, has_errors)
	local is_dev = (GetDisplayName() == "@APHONlC")
	PM_ui_refs.copy_box = PM_ui_refs.copy_box or LibAPH.CreateCopyTextBox({
		name = "PMCopyBox",
		pastebin = true,
		sections = true,
		maxInputChars = LibAPH.BUG_REPORT_MAX_CHARS,
		closeText = PM.L("BTN_CLOSE"),
		titleText = PM.L("BUG_REPORT_COPY_TITLE"),
		devButton = is_dev and { text = "Simulate Error", onClick = PM.dev_simulate_error } or nil,
		dismissBug = { text = "Dismiss Bug", onClick = dismiss_captured_error },
		wipeAllBugs = { text = "Wipe All Bugs", onClick = PM.wipe_all_bugs },
	})
	PM_ui_refs.copy_box:ShowReport(sections, has_errors)
end

function PM.hook_error_capture()
	LibAPH.HookErrorCapture(PM.name, function(text)
		LibAPH.RecordCapturedBug(session_bugs, text)
		if PM_ui_refs.copy_box and not PM_ui_refs.copy_box.window:IsHidden() then
			PM.show_bug_report_box()
		end
	end)
end

function get_bug_report_settings_fields()
	return {
		{ key = "is_csa_enabled", label = PM.L("CHK_SCREEN_ANNOUNCEMENTS") },
		{ key = "is_random_on_login", label = PM.L("CHK_RANDOM_ON_LOGIN") },
		{ key = "is_random_on_zone", label = PM.L("CHK_RANDOM_ON_ZONE") },
		{ key = "is_loop_in_combat", label = PM.L("CHK_LOOP_IN_COMBAT") },
		{ key = "show_in_hud", label = PM.L("CHK_UI_MODE") },
		{ key = "is_ui_global", label = PM.L("CHK_RENDER_IN_MENUS") },
		{ key = "is_unrestricted", label = PM.L("BTN_UNRESTRICTED_MODE") },
		{ key = "enable_random_fav", label = PM.L("CHK_ENABLE_RANDOM_FAV") },
		{ key = "enable_learning", label = PM.L("CHK_ENABLE_LEARNING") },
		{ key = "is_log_enabled", label = PM.L("CHK_ENABLE_CHAT_LOGS") },
		{ key = "is_stop_spinning", label = PM.L("CHK_STOP_SPINNING") },
		{ key = "is_lib_warning_enabled", label = PM.L("CHK_LIB_WARNING_ENABLED") },
		{ key = "busy_check_teleport", label = PM.L("CHK_BUSY_TELEPORT") },
		{ key = "busy_check_dead", label = PM.L("CHK_BUSY_DEAD") },
		{ key = "busy_check_casting", label = PM.L("CHK_BUSY_CASTING") },
		{ key = "busy_check_attacking", label = PM.L("CHK_BUSY_ATTACKING") },
		{ key = "busy_check_crafting", label = PM.L("CHK_BUSY_CRAFTING") },
		{ key = "busy_check_interacting", label = PM.L("CHK_BUSY_INTERACTING") },
		{ key = "busy_check_menu", label = PM.L("CHK_BUSY_MENU") },
		{ key = "busy_check_resurrecting", label = PM.L("CHK_BUSY_RESURRECTING") },
		{ key = "busy_check_blocking", label = PM.L("CHK_BUSY_BLOCKING") },
		{ key = "busy_check_swimming", label = PM.L("CHK_BUSY_SWIMMING") },
		{ key = "busy_check_mounted", label = PM.L("CHK_BUSY_MOUNTED") },
		{ key = "busy_check_sneaking", label = PM.L("CHK_BUSY_SNEAKING") },
		{ key = "busy_check_moving", label = PM.L("CHK_BUSY_MOVING") },
	}
end

local function get_bug_report_delay_lines()
	local rows = {
		{ "SLIDER_DELAY_IDLE", "delay_idle" },
		{ "SLIDER_DELAY_MENU", "delay_in_menu" },
		{ "SLIDER_DELAY_CAST", "delay_cast" },
		{ "SLIDER_DELAY_ATTACK", "delay_attack" },
		{ "SLIDER_DELAY_COMBAT_END", "delay_combat_end" },
		{ "SLIDER_DELAY_DEAD", "delay_dead" },
		{ "SLIDER_DELAY_RESURRECT", "delay_resurrect" },
		{ "SLIDER_DELAY_TELEPORT", "delay_teleport" },
		{ "SLIDER_DELAY_CRAFTING", "delay_crafting" },
		{ "SLIDER_DELAY_MOVE", "delay_move" },
		{ "SLIDER_DELAY_BLOCK", "delay_block" },
		{ "SLIDER_DELAY_SWIM", "delay_swim" },
		{ "SLIDER_DELAY_SNEAK", "delay_sneak" },
		{ "SLIDER_DELAY_MOUNT", "delay_mount" },
	}
	local lines = {}
	for _, row in ipairs(rows) do
		table.insert(lines, PM.L(row[1]) .. ": " .. tostring(PM.settings[row[2]]) .. "s")
	end
	return table.concat(lines, "\n")
end

function PM.show_bug_report_box()

	local bug_lines = {}
	if #session_bugs > 0 then bug_lines[1] = LibAPH.FormatCapturedBugBlocks(PM.name, session_bugs) end
	local error_section = LibAPH.FormatCapturedBugsSection(
		bug_lines,
		PM.L("BUG_REPORT_COPY_PROMPT") .. "\n\n",
		PM.L("BUG_REPORT_NONE_CAPTURED", PM.name) .. "\n\n",
		PM.L("BUG_REPORT_DESCRIBE_INSTEAD")
	)

	local on_word, off_word = PM.L("WORD_ON"), PM.L("WORD_OFF")
	local settings_lines = LibAPH.FormatSettingsSnapshot(PM.settings, get_bug_report_settings_fields(), on_word, off_word)
	if PM.char_saved then
		local acct_line = PM.L("CHK_ACCOUNT_SETTINGS") .. ": " .. (PM.char_saved.use_account_settings and on_word or off_word)
		settings_lines = (settings_lines ~= "" and (settings_lines .. "\n") or "") .. acct_line
	end
	settings_lines = settings_lines .. "\n\n" .. PM.L("HEADER_MEMENTO_DELAYS") .. ":\n" .. get_bug_report_delay_lines()

	local sections = LibAPH.BuildBugReportSections({
		statsText = PM.get_stats_text(),
		settingsLines = settings_lines,
		fieldSettingsLabel = PM.L("FIELD_SETTINGS"),
		errorSection = error_section,
		fieldLabels = {
			platform = PM.L("FIELD_PLATFORM"),
			language = PM.L("FIELD_CURRENT_LANGUAGE"),
			installed = PM.L("FIELD_INSTALLED_SINCE"),
			version_history = PM.L("FIELD_VERSION_HISTORY"),
			library_version = PM.L("FIELD_LIBRARY_VERSION"),
			wizard = PM.L("FIELD_WIZARD"),
			files = PM.L("FIELD_MODULES"),
		},
	})

	show_copy_text_box(sections, #session_bugs > 0)
end

function PM.build_general_options(b_data, is_pad)
	local grp_gen = {
		{
			type = "checkbox", name = function() return PM.L("CHK_ACCOUNT_SETTINGS") end,
			getFunc = function() return PM.char_saved.use_account_settings end,
			setFunc = function(v)
				PM.char_saved.use_account_settings = v
				PM.call_optional(PM.update_settings_reference, "update_settings_reference")
				zo_callLater(function() ReloadUI("ingame") end, 50)
			end
		},
		{
			type = "dropdown", name = function() return PM.L("DD_SELECT_ACTIVE_MEMENTO") end, reference = "PM_ActiveDropdown",
			choices = PM_state.active_names, choicesValues = PM_state.active_ids,
			getFunc = function()
				if PM_state.pending_id == nil then return PM.settings.active_id or 0 end
				return PM_state.pending_id
			end,
			setFunc = function(v) PM_state.pending_id = v end,
			disabled = function() return PM.settings.enable_random_fav and PM.settings.is_random_on_zone end
		}
	}
	local random_button = {
		type = "button", name = function() return "|cFFFF00" .. PM.L("BTN_ACTIVATE_RANDOM") .. "|r" end, width = "half",
		func = function()
			local r_id = PM.call_optional(PM.get_random_supported, "Loop module (get_random_supported)")
			if r_id then
				PM.settings.active_id = r_id
				PM.log_msg(PM.L("CHAT_RANDOMLY_SELECTED", PM.get_data(r_id).name), true, "random", 90)
				PM.call_optional(PM.start_loop, "Loop module (start_loop)", r_id)
			else
				PM.log_msg(PM.L("CHAT_NO_RANDOM_AVAILABLE"), true, "error", 90)
			end
		end,
		disabled = function() return not PM_modules.loop or not PM.settings.enable_random_fav end
	}
	local random_on = PM.settings.enable_random_fav
	if PM_modules.loop and random_on then table.insert(grp_gen, random_button) end
	if PM_modules.loop then table.insert(grp_gen, {
		type = "button", name = function() return "|c00FF00" .. PM.L("BTN_APPLY_SELECTED") .. "|r" end, width = random_on and "half" or "full",
		func = function()
			if PM_state.pending_id and PM_state.pending_id ~= 0 then
				PM.settings.active_id = PM_state.pending_id
				local md = PM.get_data(PM_state.pending_id)
				PM.log_msg(PM.L("CHAT_SELECTED_VIA_MENU", md.name or PM.L("LABEL_UNKNOWN")), true, "activation")
				PM.call_optional(PM.start_loop, "Loop module (start_loop)", PM_state.pending_id); PM_state.pending_id = nil
			elseif PM_state.pending_id == 0 then
				PM.settings.active_id = nil; PM_state.loop_token = (PM_state.loop_token or 0) + 1
				PM.log_msg(PM.L("CHAT_AUTOLOOP_STOPPED"), true, "stop", 90)
				PM_state.pending_id = nil; PM_state.next_fire_time = 0
			end
		end,
		disabled = function() return not PM_modules.loop end
	}) end
	if random_on then table.insert(grp_gen, {
		type = "checkbox", name = function() return PM.L("CHK_RANDOM_ON_ZONE") end,
		getFunc = function() return PM.settings.is_random_on_zone end,
		setFunc = function(v) PM.settings.is_random_on_zone = v end,
		disabled = function() return not PM.settings.enable_random_fav end
	})
	table.insert(grp_gen, {
		type = "checkbox", name = function() return PM.L("CHK_RANDOM_ON_LOGIN") end,
		getFunc = function() return PM.settings.is_random_on_login end,
		setFunc = function(v) PM.settings.is_random_on_login = v end,
		disabled = function() return not PM.settings.enable_random_fav end
	}) end
	for _, ctrl in ipairs({
		{
			type = "checkbox", name = function() return PM.L("CHK_LOOP_IN_COMBAT") end,
			getFunc = function() return PM.settings.is_loop_in_combat end,
			setFunc = function(v) PM.settings.is_loop_in_combat = v end
		},
		{
			type = "checkbox", name = function() return PM.L("CHK_SCREEN_ANNOUNCEMENTS") end,
			getFunc = function() return PM.settings.is_csa_enabled end,
			setFunc = function(v) PM.settings.is_csa_enabled = v end
		},
		{
			type = "checkbox", name = function() return PM.L("CHK_ENABLE_CHAT_LOGS") end,
			getFunc = function() return PM.settings.is_log_enabled end,
			setFunc = function(v) PM.settings.is_log_enabled = v end
		}
	}) do table.insert(grp_gen, ctrl) end

	if is_pad then
		table.insert(b_data, {
			type = "submenu", name = function() return "|c00FF00" .. PM.L("HEADER_GENERAL_SETTINGS") .. "|r" end,
			controls = grp_gen
		})
	else
		table.insert(b_data, { type = "header", name = function() return "|c00FF00" .. PM.L("HEADER_GENERAL_SETTINGS") .. "|r" end })
		for _, ctrl in ipairs(grp_gen) do table.insert(b_data, ctrl) end
	end
end

function PM.build_module_manager_options(b_data, is_pad)
	local function is_genuinely_missing(mod_key)
		local was_disabled_at_start = PM_state.module_disabled_snapshot and PM_state.module_disabled_snapshot[mod_key]
		return not PM_modules[mod_key] and not was_disabled_at_start
	end
	local missing_text = " - |c888888" .. PM.L("LABEL_MISSING_FILE") .. "|r |cFF0000" .. PM.L("LABEL_DISABLED_PAREN") .. "|r"
	local function build_module_load_button(mod_key, display_name)
		return LibAPH.BuildModuleLoadButton({
			modKey = mod_key, displayName = display_name,
			moduleLabel = PM.L("LABEL_MODULE"),
			settings = PM.acct_saved,
			toggleFn = PM.toggle_module_disabled,
			isMissing = is_genuinely_missing,
			missingText = missing_text,
		})
	end

	local grp_pwr = {
		{
			type = "checkbox", name = function() return PM.L("CHK_ENABLE_RANDOM_FAV") end,
			getFunc = function() return PM.settings.enable_random_fav end,
			setFunc = function(v)
				PM.settings.enable_random_fav = v
				PM.refresh_slash_commands()
				PM.log_msg(PM.L("CHAT_RANDOM_FAV", v and PM.L("WORD_ON") or PM.L("WORD_OFF")), true, "settings")
			end
		},
		{
			type = "checkbox", name = function() return PM.L("CHK_ENABLE_LEARNING") end,
			getFunc = function() return PM.settings.enable_learning end,
			setFunc = function(v)
				PM.settings.enable_learning = v
				PM.refresh_slash_commands()
				PM.log_msg(PM.L("CHAT_LEARNING_MODE", v and PM.L("WORD_ON") or PM.L("WORD_OFF")), true, "settings")
			end
		}
	}

	if not is_pad and PM_modules.sync then
		table.insert(grp_pwr, {
			type = "checkbox",
			name = function() return PM.L("CHK_ENABLE_SYNC_LISTENER") end,
			getFunc = function() return PM.settings.sync_module.is_enabled end,
			setFunc = function(v)
				PM.settings.sync_module.is_enabled = v; PM.toggle_sync_listener()
				PM.refresh_slash_commands()
				PM.log_msg(PM.L("CHAT_SYNC_LISTENING", v and PM.L("WORD_ON") or PM.L("WORD_OFF")), true, "settings")
			end,
			disabled = function() return not PM_modules.sync end
		})
	end

	table.insert(grp_pwr, { type = "description", text = "" })
	if IsKeyboardUISupported() then
		table.insert(grp_pwr, { type = "header", name = function() return PM.L("HEADER_MODULE_FILE_STATUS") end })
	end
	if not is_pad then
		table.insert(grp_pwr, build_module_load_button("sync", "Sync"))
	end
	table.insert(grp_pwr, build_module_load_button("migration", "Migration"))
	table.insert(grp_pwr, build_module_load_button("ui", "UI"))
	table.insert(grp_pwr, build_module_load_button("menu", "Menu"))
	table.insert(grp_pwr, build_module_load_button("wizard", "Wizard"))
	table.insert(grp_pwr, {
		type = "button", name = function() return PM.L("BTN_RELOAD_UI") end, width = "half",
		func = function() ReloadUI("ingame") end
	})
	table.insert(b_data, {
		type = "submenu", name = function() return "|cFFA500" .. PM.L("HEADER_MODULE_MANAGER") .. "|r" end,
		reference = "PM_Submenu_ModuleManager",
		controls = grp_pwr
	})
end

function PM.build_ui_position_options(b_data, is_pad)
	if not PM_modules.ui then return end
	local function preview_window_reset(win_ctrl)
		local cur_scene = SCENE_MANAGER:GetCurrentScene()
		if not cur_scene then return end
		local t_frag = PM.settings.show_in_hud and PM_ui_refs.hudFragment or PM_ui_refs.menuFragment
		if win_ctrl == PM_ui_refs.ui_window and t_frag and cur_scene:HasFragment(t_frag) then
			win_ctrl:SetHidden(false)
		end
	end

	local ui_pos_controls = {
		{
			type = "checkbox",
			name = function()
				local visible = not PM.settings.ui.is_hidden
				return PM.L("CHK_UI_VISIBILITY") .. ": " .. (visible and "|c00FF00" .. PM.L("LABEL_VISIBLE") .. "|r" or "|c888888" .. PM.L("LABEL_HIDDEN") .. "|r")
			end,
			getFunc = function() return not PM.settings.ui.is_hidden end,
			setFunc = function(v)
				PM.settings.ui.is_hidden = not v
				PM.call_optional(PM.toggle_ui_update, "UI module (toggle_ui_update)")
				PM.log_msg(PM.L("CHAT_UI_VISIBILITY_CHANGED"), true, "ui", 90)
			end,
			disabled = function() return not PM_modules.ui end
		},
		{
			type = "checkbox",
			name = function()
				return PM.L("CHK_UI_MODE") .. ": " .. (PM.settings.show_in_hud and "|c00FF00" .. PM.L("LABEL_HUD") .. "|r" or "|c00FF00" .. PM.L("LABEL_MENU") .. "|r")
			end,
			getFunc = function() return PM.settings.show_in_hud end,
			setFunc = function(v)
				PM.settings.show_in_hud = v
				PM.call_optional(PM.update_ui_scenes, "UI module (update_ui_scenes)")
				PM.log_msg(PM.L("CHAT_UI_MODE", v and PM.L("LABEL_HUD_ONLY") or PM.L("LABEL_MENU_ONLY")), true, "ui")
			end,
			disabled = function() return PM.settings.ui.is_hidden or not PM_modules.ui end
		},
		{
			type = "checkbox", name = function() return PM.L("CHK_RENDER_IN_MENUS") end,
			getFunc = function() return PM.settings.is_ui_global end,
			setFunc = function(v)
				PM.settings.is_ui_global = v
				PM.call_optional(PM.update_ui_scenes, "UI module (update_ui_scenes)")
			end,
			disabled = function() return PM.settings.ui.is_hidden or not PM.settings.show_in_hud or not PM_modules.ui end
		},
		{
			type = "slider", name = function() return PM.L("SLIDER_HUD_UI_SCALE") end,
			min = 0.5, max = 2.0, step = 0.1, decimals = 1,
			getFunc = function() return PM.settings.ui.scale or (is_pad and 1.0 or 1.0) end,
			setFunc = function(v) if PM_ui_refs.ui_mover then PM_ui_refs.ui_mover:ToggleGamepadMove(false) end; PM.settings.ui.scale = v; PM.call_optional(PM.apply_ui_size, "UI module (apply_ui_size)") end,
			disabled = function() return not PM_modules.ui end
		},
		{
			type = "slider", name = function() return PM.L("SLIDER_MENU_UI_SCALE") end,
			min = 0.5, max = 2.0, step = 0.1, decimals = 1,
			getFunc = function() return PM.settings.ui_menu.scale or (is_pad and 1.2 or 1.0) end,
			setFunc = function(v) if PM_ui_refs.ui_mover then PM_ui_refs.ui_mover:ToggleGamepadMove(false) end; PM.settings.ui_menu.scale = v; PM.call_optional(PM.apply_ui_size, "UI module (apply_ui_size)") end,
			disabled = function() return not PM_modules.ui end
		},
		{
			type = "checkbox", name = function() return PM.L("CHK_LOCK_UI_POSITION") end,
			getFunc = function() return PM.settings.ui.is_locked end,
			setFunc = function(v)
				PM.settings.ui.is_locked = v
				if PM_ui_refs.ui_window then PM_ui_refs.ui_window:SetMovable(not v) end
			end,
			disabled = function() return not PM_modules.ui end
		}
	}

	if is_pad then
		table.insert(ui_pos_controls, {
			type = "button", name = function() return PM.L("BTN_MOVE_UI_STICK") end, width = "half",
			func = function()
				PM.call_optional(PM.start_gamepad_move, "UI module (start_gamepad_move)")
			end,
			disabled = function() return PM_ui_refs.ui_mover == nil or PM.settings.ui.is_locked or not PM_modules.ui end
		})
	end

	local reset_width = is_pad and "full" or "half"
	table.insert(ui_pos_controls, {
		type = "button", name = function() return "|cFF0000" .. PM.L("BTN_RESET_UI_POSITION") .. "|r" end, warning = function() return PM.L("WARN_RESET_UI_POSITION") end, isDangerous = true, width = reset_width,
		func = function()
			PM.settings.ui.left = PM_defaults.ui.left
			PM.settings.ui.top = PM_defaults.ui.top
			PM.settings.ui_menu.left = PM_defaults.ui_menu.left
			PM.settings.ui_menu.top = PM_defaults.ui_menu.top
			PM.settings.ui.point = nil
			PM.settings.ui_menu.point = nil
			PM.call_optional(PM.reset_ui_position, "UI module (reset_ui_position)"); PM.log_msg(PM.L("CHAT_UI_POSITION_RESET"), true, "ui", 90)
			preview_window_reset(PM_ui_refs.ui_window)
		end,
		disabled = function() return not PM_modules.ui end
	})

	table.insert(ui_pos_controls, {
		type = "button", name = function() return "|cFF0000" .. PM.L("BTN_RESET_UI_SIZE") .. "|r" end, warning = function() return PM.L("WARN_RESET_UI_SIZE") end, isDangerous = true, width = reset_width,
		func = function()
			if PM_ui_refs.ui_mover then PM_ui_refs.ui_mover:ToggleGamepadMove(false) end
			PM.settings.ui.scale = PM_defaults.ui.scale
			PM.settings.ui_menu.scale = PM_defaults.ui_menu.scale
			PM.settings.ui.width = nil
			PM.settings.ui.height = nil
			PM.settings.ui_menu.width = nil
			PM.settings.ui_menu.height = nil
			PM.call_optional(PM.apply_ui_size, "UI module (apply_ui_size)"); PM.log_msg(PM.L("CHAT_UI_SIZE_RESET"), true, "ui", 90)
			preview_window_reset(PM_ui_refs.ui_window)
		end,
		disabled = function() return not PM_modules.ui end
	})

	table.insert(b_data, {
		type = "submenu", name = function() return "|c00FFFF" .. PM.L("HEADER_CONFIGURE_UI_POSITIONS") .. "|r" end,
		reference = "PM_Submenu_UIPosition", controls = ui_pos_controls
	})
end

function PM.build_sync_options(b_data, is_pad)
	if not is_pad and PM_modules.sync and PM.settings.sync_module.is_enabled then
		local grp_sync = only_built(
			{
				type = "description",
				text = function()
					if not PM.settings.sync_module.is_enabled then
						return "|cFF0000" .. PM.L("DESC_SYNC_DISABLED") .. "|r"
					end
					return PM.L("DESC_SYNC_OPTIONS")
				end
			},
			{
				type = "dropdown", name = function() return PM.L("DD_SELECT_SYNC_REQUEST") end, reference = "PM_SyncDropdown",
				choices = PM_state.sync_names, choicesValues = PM_state.sync_ids,
				getFunc = function() return 0 end,
				setFunc = function(v)
					if v and v ~= 0 and PM.send_sync then PM.send_sync("play", v) end
				end,
				disabled = function() return not PM.settings.sync_module.is_enabled end
			},
			PM_modules.loop and {
				type = "button", name = function() return PM.L("BTN_SEND_RANDOM_SYNC") end,
				func = function()
					local r_id = PM.call_optional(PM.get_random_any, "Loop module (get_random_any)")
					if not r_id then
						PM.log_msg(PM.L("CHAT_NO_RANDOM_AVAILABLE"), true, "error", 90)
					elseif PM.send_sync then
						PM.send_sync("play", r_id)
					end
				end,
				disabled = function() return not PM.settings.sync_module.is_enabled or not PM_modules.loop end
			},
			{
				type = "button", name = function() return PM.L("BTN_SEND_STOP_COMMAND") end,
				func = function()
					if PM.send_sync then PM.send_sync("stop") end
				end,
				disabled = function() return not PM.settings.sync_module.is_enabled end
			},
			{
				type = "checkbox", name = function() return PM.L("CHK_RANDOMIZE_SYNC_DELAY") end,
				getFunc = function() return PM.settings.sync_module.is_random end,
				setFunc = function(v) PM.settings.sync_module.is_random = v end,
				disabled = function() return not PM.settings.sync_module.is_enabled end
			},
			{
				type = "slider", name = function() return PM.L("SLIDER_SYNC_DELAY") end,
				min = 0, max = 10, step = 1,
				getFunc = function() return PM.settings.sync_module.delay end,
				setFunc = function(v) PM.settings.sync_module.delay = v end,
				disabled = function()
					return not PM.settings.sync_module.is_enabled or PM.settings.sync_module.is_random
				end
			}
		)
		table.insert(b_data, {
			type = "submenu", name = function() return "|c800080" .. PM.L("HEADER_SYNC_SETTINGS") .. "|r" end,
			reference = "PM_Submenu_Sync",
			controls = grp_sync
		})
	end
end

function PM.build_favorites_options(b_data, is_pad)
	if not PM.settings.enable_random_fav then return end
	local grp_fav = {
		{
			type = "description",
			text = function()
				if not PM.settings.enable_random_fav then
					return "|cFF0000" .. PM.L("DESC_FAVORITES_DISABLED") .. "|r"
				end
				return PM.L("DESC_FAVORITES_HELP")
			end
		},
		{
			type = "dropdown", name = function() return PM.L("DD_SELECT_MEMENTO_FAVORITE") end,
			reference = "PM_FavCandidateDropdown",
			choices = PM_state.fav_all_names, choicesValues = PM_state.fav_all_ids,
			getFunc = function() return PM_state.selected_fav_candidate or 0 end,
			setFunc = function(v) PM_state.selected_fav_candidate = v end,
			disabled = function() return not PM.settings.enable_random_fav end
		},
		{
			type = "button", name = function() return PM.L("BTN_APPLY_TO_FAVORITES") end,
			func = function() PM.toggle_favorite(PM_state.selected_fav_candidate) end,
			disabled = function() return not PM.settings.enable_random_fav end
		}
	}
	if IsKeyboardUISupported() then
		table.insert(grp_fav, { type = "divider" })
	end
	table.insert(grp_fav, {
		type = "dropdown", name = function() return PM.L("DD_VIEW_CURRENT_FAVORITES") end,
		reference = "PM_FavRemoveDropdown",
		choices = PM_state.fav_current_names, choicesValues = PM_state.fav_current_ids,
		getFunc = function() return PM_state.selected_fav_removal or 0 end,
		setFunc = function(v) PM_state.selected_fav_removal = v end,
		disabled = function() return not PM.settings.enable_random_fav end
	})
	table.insert(grp_fav, {
		type = "button", name = function() return "|cFF0000" .. PM.L("BTN_REMOVE_SELECTED_FAVORITE") .. "|r" end, warning = function() return PM.L("WARN_REMOVE_SELECTED_FAVORITE") end, isDangerous = true,
		func = function() PM.toggle_favorite(PM_state.selected_fav_removal) end,
		disabled = function() return not PM.settings.enable_random_fav end
	})
	table.insert(grp_fav, {
		type = "button", name = function() return "|cFF0000" .. PM.L("BTN_CLEAR_ALL_FAVORITES") .. "|r" end, warning = function() return PM.L("WARN_CLEAR_ALL_FAVORITES") end, isDangerous = true,
		func = function() PM.delete_all_favorites() end,
		disabled = function() return not PM.settings.enable_random_fav end
	})
	table.insert(b_data, {
		type = "submenu", name = function() return "|c9CD04C" .. PM.L("HEADER_FAVORITES_MANAGER") .. "|r" end,
		reference = "PM_Submenu_Favorites",
		controls = grp_fav
	})
end

function PM.build_profile_options(b_data, is_pad)
	if PM.char_saved.use_account_settings then return end

	local grp_prof = {
		{
			type = "description",
			text = function()
				local cur = PM.settings.active_profile or PM.L("LABEL_NONE")
				return PM.L("CURRENT_PROFILE_LABEL") .. " |c00FF00" .. cur .. "|r"
			end
		},
		{
			type = "description",
			text = function() return PM.L("DESC_PROFILE_HELP") end
		},
		{
			type = "editbox", name = function() return PM.L("EDIT_NEW_PROFILE_NAME") end,
			isMultiline = false,
			getFunc = function() return PM_ui_refs.profile_input_text or "" end,
			setFunc = function(v) PM_ui_refs.profile_input_text = v end
		},
		{
			type = "button", name = function() return "|c00FF00" .. PM.L("BTN_SAVE_NEW_PROFILE") .. "|r" end, width = "full",
			func = function() PM.save_profile(PM_ui_refs.profile_input_text) end
		}
	}
	if IsKeyboardUISupported() then
		table.insert(grp_prof, { type = "divider" })
	end
	table.insert(grp_prof, {
		type = "dropdown", name = function() return PM.L("DD_SELECT_PROFILE") end, reference = "PM_ProfileDropdown",
		choices = PM_state.profile_list_names, choicesValues = PM_state.profile_list_values,
		getFunc = function() return PM_state.selected_profile_name or "" end,
		setFunc = function(v) PM_state.selected_profile_name = v end
	})
	table.insert(grp_prof, {
		type = "button", name = function() return "|c00FFFF" .. PM.L("BTN_LOAD_PROFILE") .. "|r" end, width = "half",
		func = function() PM.load_profile(PM_state.selected_profile_name) end
	})
	table.insert(grp_prof, {
		type = "button", name = function() return "|cFF0000" .. PM.L("BTN_DELETE_PROFILE") .. "|r" end, warning = function() return PM.L("WARN_DELETE_PROFILE") end, isDangerous = true, width = "half",
		func = function() PM.delete_profile(PM_state.selected_profile_name) end
	})
	table.insert(b_data, {
		type = "submenu", name = function() return "|cFFFF00" .. PM.L("HEADER_PROFILE_MANAGER") .. "|r" end,
		reference = "PM_Submenu_ProfileManager",
		controls = grp_prof
	})
end

function PM.build_learned_data_options(b_data, is_pad)
	if not PM.settings.enable_learning then return end
	local grp_lrn = only_built(
		{
			type = "description",
			text = function()
				if not PM.settings.enable_learning then
					return "|cFF0000" .. PM.L("DESC_LEARNED_DISABLED") .. "|r"
				end
				return PM.L("DESC_LEARNED_HELP")
			end
		},
		{
			type = "dropdown", name = function() return PM.L("DD_LEARNED_MEMENTOS") end, reference = "PM_LearnedDropdown",
			choices = PM_state.learned_list_names, choicesValues = PM_state.learned_list_values,
			getFunc = function() return PM_state.selected_learned_id or 0 end,
			setFunc = function(v) PM_state.selected_learned_id = v end,
			disabled = function() return not PM.settings.enable_learning end
		},
		PM_modules.loop and {
			type = "button", name = function() return "|c00FF00" .. PM.L("BTN_ACTIVATE_SELECTION") .. "|r" end, width = "half",
			func = function()
				if PM_state.selected_learned_id and PM_state.selected_learned_id ~= 0 then
					PM.settings.active_id = PM_state.selected_learned_id
					local md = PM.get_data(PM_state.selected_learned_id)
					PM.log_msg(PM.L("CHAT_SELECTED_LEARNED", md and md.name or "?"), true, "activation")
					PM.call_optional(PM.start_loop, "Loop module (start_loop)", PM_state.selected_learned_id)
				end
			end,
			disabled = function() return not PM.settings.enable_learning or not PM_modules.loop end
		},
		PM_modules.loop and {
			type = "button", name = function() return "|cFFFF00" .. PM.L("BTN_LEARN_AUTOSCAN") .. "|r" end, width = "half",
			func = function() PM.call_optional(PM.auto_scan_mementos, "Loop module (auto_scan_mementos)") end,
			disabled = function() return not PM.settings.enable_learning or not PM_modules.loop end
		},
		{
			type = "button", name = function() return "|cFF0000" .. PM.L("BTN_DELETE_SELECTED_MEMENTO") .. "|r" end, warning = function() return PM.L("WARN_DELETE_SELECTED_MEMENTO") end, isDangerous = true, width = "half",
			func = function() PM.delete_learned_data(PM_state.selected_learned_id) end,
			disabled = function() return not PM.settings.enable_learning end
		},
		PM_modules.loop and {
			type = "button", name = function() return PM.L("BTN_RANDOMIZED_LEARNED") end, width = "half",
			func = function()
				local r_id = PM.call_optional(PM.get_random_learned, "Loop module (get_random_learned)")
				if r_id then
					PM.settings.active_id = r_id
					PM.log_msg(PM.L("CHAT_RANDOMLY_SELECTED", PM.get_data(r_id).name), true, "random", 90)
					PM.call_optional(PM.start_loop, "Loop module (start_loop)", r_id)
				else
					PM.log_msg(PM.L("CHAT_NO_LEARNED_DATA"), true, "error")
				end
			end,
			disabled = function() return not PM.settings.enable_learning or not PM_modules.loop end
		},
		{
			type = "button", name = function() return "|cFF0000" .. PM.L("BTN_DELETE_ALL_LEARNED") .. "|r" end, warning = function() return PM.L("WARN_DELETE_ALL_LEARNED") end, isDangerous = true, width = "half",
			func = function() PM.delete_all_learned_data() end,
			disabled = function() return not PM.settings.enable_learning end
		}
	)
	table.insert(b_data, {
		type = "submenu", name = function() return "|cFFFF00" .. PM.L("HEADER_LEARNED_DATA_MGMT") .. "|r" end,
		reference = "PM_Submenu_LearnedData",
		controls = grp_lrn
	})
end

function PM.build_delay_options(b_data, is_pad)
	local grp_delay = {
		{
			type = "slider", name = function() return PM.L("SLIDER_DELAY_IDLE") end, min = 0, max = 10, step = 1,
			getFunc = function() return PM.settings.delay_idle end,
			setFunc = function(v) PM.settings.delay_idle = v end
		},
		{
			type = "slider", name = function() return PM.L("SLIDER_DELAY_MENU") end, min = 0, max = 10, step = 1,
			getFunc = function() return PM.settings.delay_in_menu end,
			setFunc = function(v) PM.settings.delay_in_menu = v end
		},
		{
			type = "slider", name = function() return PM.L("SLIDER_DELAY_CAST") end, min = 0, max = 10, step = 1,
			getFunc = function() return PM.settings.delay_cast end,
			setFunc = function(v) PM.settings.delay_cast = v end
		},
		{
			type = "slider", name = function() return PM.L("SLIDER_DELAY_ATTACK") end, min = 0, max = 10, step = 1,
			getFunc = function() return PM.settings.delay_attack end,
			setFunc = function(v) PM.settings.delay_attack = v end
		},
		{
			type = "slider", name = function() return PM.L("SLIDER_DELAY_COMBAT_END") end, min = 0, max = 10, step = 1,
			getFunc = function() return PM.settings.delay_combat_end end,
			setFunc = function(v) PM.settings.delay_combat_end = v end
		},
		{
			type = "slider", name = function() return PM.L("SLIDER_DELAY_DEAD") end, min = 0, max = 10, step = 1,
			getFunc = function() return PM.settings.delay_dead end,
			setFunc = function(v) PM.settings.delay_dead = v end
		},
		{
			type = "slider", name = function() return PM.L("SLIDER_DELAY_RESURRECT") end, min = 0, max = 10, step = 1,
			getFunc = function() return PM.settings.delay_resurrect end,
			setFunc = function(v) PM.settings.delay_resurrect = v end
		},
		{
			type = "slider", name = function() return PM.L("SLIDER_DELAY_TELEPORT") end, min = 0, max = 20, step = 1,
			getFunc = function() return PM.settings.delay_teleport end,
			setFunc = function(v) PM.settings.delay_teleport = v end
		},
		{
			type = "slider", name = function() return PM.L("SLIDER_DELAY_CRAFTING") end, min = 0, max = 10, step = 1,
			getFunc = function() return PM.settings.delay_crafting end,
			setFunc = function(v) PM.settings.delay_crafting = v end
		},
		{
			type = "slider", name = function() return PM.L("SLIDER_DELAY_MOVE") end, min = 0, max = 10, step = 1,
			getFunc = function() return PM.settings.delay_move end,
			setFunc = function(v) PM.settings.delay_move = v end
		},
		{
			type = "slider", name = function() return PM.L("SLIDER_DELAY_BLOCK") end, min = 0, max = 10, step = 1,
			getFunc = function() return PM.settings.delay_block end,
			setFunc = function(v) PM.settings.delay_block = v end
		},
		{
			type = "slider", name = function() return PM.L("SLIDER_DELAY_SWIM") end, min = 0, max = 10, step = 1,
			getFunc = function() return PM.settings.delay_swim end,
			setFunc = function(v) PM.settings.delay_swim = v end
		},
		{
			type = "slider", name = function() return PM.L("SLIDER_DELAY_SNEAK") end, min = 0, max = 10, step = 1,
			getFunc = function() return PM.settings.delay_sneak end,
			setFunc = function(v) PM.settings.delay_sneak = v end
		},
		{
			type = "slider", name = function() return PM.L("SLIDER_DELAY_MOUNT") end, min = 0, max = 10, step = 1,
			getFunc = function() return PM.settings.delay_mount end,
			setFunc = function(v) PM.settings.delay_mount = v end
		}
	}
	table.insert(b_data, {
		type = "submenu", name = function() return "|cAAAAAA" .. PM.L("HEADER_MEMENTO_DELAYS") .. "|r" end,
		reference = "PM_Submenu_Delays",
		controls = grp_delay
	})
	build_delay_trigger_options(b_data)
end

function build_delay_trigger_options(b_data)
	local function trigger_checkbox(key, setting_key)
		return {
			type = "checkbox", name = function() return PM.L(key) end,
			getFunc = function() return PM.settings[setting_key] end,
			setFunc = function(v)
				PM.settings[setting_key] = v
				PM.refresh_loop_event_registrations()
			end
		}
	end
	local grp_triggers = {
		trigger_checkbox("CHK_BUSY_TELEPORT", "busy_check_teleport"),
		trigger_checkbox("CHK_BUSY_DEAD", "busy_check_dead"),
		trigger_checkbox("CHK_BUSY_CASTING", "busy_check_casting"),
		trigger_checkbox("CHK_BUSY_ATTACKING", "busy_check_attacking"),
		trigger_checkbox("CHK_BUSY_CRAFTING", "busy_check_crafting"),
		trigger_checkbox("CHK_BUSY_INTERACTING", "busy_check_interacting"),
		trigger_checkbox("CHK_BUSY_MENU", "busy_check_menu"),
		trigger_checkbox("CHK_BUSY_RESURRECTING", "busy_check_resurrecting"),
		trigger_checkbox("CHK_BUSY_BLOCKING", "busy_check_blocking"),
		trigger_checkbox("CHK_BUSY_SWIMMING", "busy_check_swimming"),
		trigger_checkbox("CHK_BUSY_MOUNTED", "busy_check_mounted"),
		trigger_checkbox("CHK_BUSY_SNEAKING", "busy_check_sneaking"),
		trigger_checkbox("CHK_BUSY_MOVING", "busy_check_moving"),
	}
	table.insert(b_data, {
		type = "submenu", name = function() return "|cAAAAAA" .. PM.L("HEADER_DELAY_TRIGGERS") .. "|r" end,
		reference = "PM_Submenu_DelayTriggers",
		controls = grp_triggers
	})
end

function PM.build_commands_options(b_data, is_pad)

	local grp_cmd = {}
	if PM_modules.loop then table.insert(grp_cmd, {
		type = "checkbox", name = function() return PM.L("CHK_STOP_SPINNING") end,
		getFunc = function() return PM.settings.is_stop_spinning end,
		setFunc = function(v)
			PM.settings.is_stop_spinning = v; PM.call_optional(PM.apply_spin_stop, "Loop module (apply_spin_stop)")
		end,
		disabled = function() return not PM_modules.loop end
	}) end
	table.insert(grp_cmd, {
		type = "checkbox", name = function() return PM.L("CHK_LIB_WARNING_ENABLED") end,
		getFunc = function() return PM.settings.is_lib_warning_enabled end,
		setFunc = function(v) PM.settings.is_lib_warning_enabled = v end
	})
	table.insert(grp_cmd, {
		type = "button", name = function() return "|cFF0000" .. PM.L("BTN_RESET_TO_DEFAULTS") .. "|r" end, warning = function() return PM.L("WARN_RESET_TO_DEFAULTS") end, isDangerous = true, width = "half",
		func = PM.reset_to_defaults
	})

	if PM.char_saved.use_account_settings then
		table.insert(grp_cmd, {
			type = "button", name = function() return "|cFF0000" .. PM.L("BTN_DELETE_CHAR_PROFILES") .. "|r" end, warning = function() return PM.L("WARN_DELETE_CHAR_PROFILES") end, isDangerous = true, width = "half",
			func = PM.delete_all_character_profiles
		})
	end

	table.insert(grp_cmd, {
		type = "button", name = function() return "|cFF0000" .. PM.L("BTN_UNRESTRICTED_MODE") .. "|r" end, warning = function() return PM.L("WARN_UNRESTRICTED_MODE") end, isDangerous = true, width = "half",
		func = function()
			PM.settings.is_unrestricted = not PM.settings.is_unrestricted
			local s_txt = (PM.settings.is_unrestricted and PM.L("WORD_ON") or PM.L("WORD_OFF"))
			PM.log_msg(PM.L("CHAT_UNRESTRICTED_MODE", s_txt), true, "settings")
		end
	})
	if PM_modules.wizard then
		table.insert(grp_cmd, {
			type = "button",
			name = function() return "|c00FFFF" .. PM.L("BTN_SETUP_WIZARD") .. "|r" end,
			width = "half",
			func = function() PM.call_optional(PM.run_wizard, "Wizard module (run_wizard)") end
		})
	end

	table.insert(b_data, {
		type = "submenu", name = function() return "|cFF0000" .. PM.L("HEADER_ADVANCED_SETTINGS") .. "|r" end,
		reference = "PM_Submenu_Advanced",
		controls = grp_cmd
	})

	if not is_pad then
		local live_stats = {
			type = "submenu", name = function() return "|c00FFFF" .. PM.L("HEADER_CLIENT_INFORMATION") .. "|r" end,
			controls = {
				{
					type = "description",
					text = function() return PM.call_optional(PM.get_stats_text, "Loop module (get_stats_text)") or "" end,
					reference = "PM_StatsText"
				}
			}
		}
		table.insert(b_data, live_stats)
	end

	if not is_pad then
		table.insert(b_data, {
			type = "description", title = function() return PM.L("HEADER_COMMANDS_INFO") end,
			text = function() return PM.build_command_reference_text(false) end
		})
	end
end

function PM.build_menu()
	if PM_state.is_menu_built then return end

	local lam_ver, lam_en = PM.get_settings_library()
	if not lam_en or lam_ver < 30 then return end

	if lam_ver >= 30 and lam_ver < PM.REQUIRED_LAM_VERSION then
		zo_callLater(function()
			local warn_msg = "|cFFFF00" .. PM.L(
				"WARN_LAM_OUTDATED",
				lam_ver, PM.REQUIRED_LAM_VERSION
			) .. "|r"
			PM.chat:Print(warn_msg)
			local p = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(
				CSA_CATEGORY_LARGE_TEXT, SOUNDS.NONE
			)
			p:SetText(warn_msg); p:SetLifespanMS(4000)
			CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(p)
		end, 4000)
	end

	PM_state.is_menu_built = true
	PM.update_menu_choices(); PM.update_favorites_choices()

	if not PM.acct_saved.is_profiles_migrated then
		PM.call_optional(PM.migrate_legacy_profiles, "Migration module (migrate_legacy_profiles)")
	end

	PM.update_profile_list()

	local is_eu = (GetWorldName() == "EU Megaserver")
	local is_pad = IsConsoleUI() or IsInGamepadPreferredMode()
	local is_dev = (GetDisplayName() == "@APHONlC")
	local lib_lam = LibAddonMenu2 or _G["LibAddonMenu2"]
	if not lib_lam then return end

	local hdr_data = {
		type = "panel", name = "Permanent Memento",
		displayName = "|c9CD04CPermanent Memento|r",
		author = "|ca500f3A|r|cb400e6P|r|cc300daH|r|cd200cdO|r|ce100c1NlC|r",
		version = PM.version, registerForRefresh = true,
		website = "https://www.esoui.com/downloads/info4116",
		feedback = "https://www.esoui.com/downloads/info4116-PermanentMementoPCampConsole.html#comments",
		translation = "https://www.esoui.com/portal.php?id=360&a=featurereq",
		donation = "https://buymeacoffee.com/aph0nlc"
	}
	local b_data = {}

	if not is_pad and not is_eu then
		table.insert(b_data, {
			type = "button", width = "half",
			name = function() return "|c00FFFF" .. PM.L("BTN_MAIL") .. "|r @|ca500f3A|r|cb400e6P|r|cc300daH|r|cd200cdO|r|ce100c1NlC|r" end,
			func = function()
				show_menu_scene("mailSend")
				after_scene_shown("mailSend", function()
					ZO_MailSendToField:SetText("@APHONlC")
					ZO_MailSendSubjectField:SetText("PermMemento Support")
					ZO_MailSendBodyField:TakeFocus()
				end)
			end
		})
	end

	table.insert(b_data, {
		type = "button", name = function() return "|cFF0000" .. PM.L("BTN_BUG_REPORT") .. "|r" end, width = is_pad and "full" or "half",
		func = function()
			if not is_pad then
				RequestOpenUnsafeURL("https://www.esoui.com/portal.php?id=360&a=bugreport")
				PM.show_bug_report_box()
			end
		end
	})

	if is_dev then
		table.insert(b_data, { type = "description", text = " ", width = "half" })
		table.insert(b_data, {
			type = "button",
			name = function()
				local is_console_mode = (GetCVar("ForceConsoleFlow.2") == "1")
				return "|cFFA500" .. PM.L("MENU_CHANGE_MODE") .. ": " ..
					(is_console_mode and "|c00FFFF" .. PM.L("MODE_CONSOLE") .. "|r" or "|c00FF00" .. PM.L("MODE_PC") .. "|r")
			end,
			func = function()
				local is_console_mode = (GetCVar("ForceConsoleFlow.2") == "1")
				SetCVar("ForceConsoleFlow.2", is_console_mode and "0" or "1")
			end,
			width = "half"
		})
	end

	PM.call_optional(PM.build_general_options, "Menu section (build_general_options)", b_data, is_pad)
	PM.call_optional(PM.build_ui_position_options, "Menu section (build_ui_position_options)", b_data, is_pad)
	PM.call_optional(PM.build_sync_options, "Menu section (build_sync_options)", b_data, is_pad)
	PM.call_optional(PM.build_favorites_options, "Menu section (build_favorites_options)", b_data, is_pad)
	PM.call_optional(PM.build_delay_options, "Menu section (build_delay_options)", b_data, is_pad)
	PM.call_optional(PM.build_profile_options, "Menu section (build_profile_options)", b_data, is_pad)
	PM.call_optional(PM.build_learned_data_options, "Menu section (build_learned_data_options)", b_data, is_pad)
	PM.call_optional(PM.build_module_manager_options, "Menu section (build_module_manager_options)", b_data, is_pad)
	PM.call_optional(PM.build_commands_options, "Menu section (build_commands_options)", b_data, is_pad)

	if is_pad then
		table.insert(b_data, {
			type = "submenu",
			name = function() return "|c00FFFF" .. PM.L("HEADER_CLIENT_INFORMATION") .. "|r" end,
			reference = "PM_Submenu_ClientInfo",
			controls = {
				{
					type = "button", width = "full",
					name = function() return "|c00FFFF" .. PM.L("HEADER_CLIENT_INFORMATION") .. "|r" end,
					tooltip = function() return PM.call_optional(PM.get_stats_text, "Loop module (get_stats_text)") or "" end,
					func = function() end
				}
			}
		})
		table.insert(b_data, {
			type = "submenu",
			name = function() return "|c00FF00" .. PM.L("HEADER_COMMANDS_INFO") .. "|r" end,
			reference = "PM_Submenu_CommandsInfo",
			controls = {
				{
					type = "button", width = "full",
					name = function() return "|c00FF00" .. PM.L("HEADER_COMMANDS_INFO") .. "|r" end,
					tooltip = function() return PM.build_command_reference_text(false) end,
					func = function() end
				}
			}
		})
	end

	local menu_refresher = LibAPH.CreateMenuLabelRefresher("PM_MRC_", function() return PM.lam_panel end)
	menu_refresher.CollectFrom(b_data)
	PM.refresh_control_labels = menu_refresher.Refresh

	PM.lam_panel = lib_lam:RegisterAddonPanel("PermMementoOptions", hdr_data)
	lib_lam:RegisterOptionControls("PermMementoOptions", b_data)
	PM.menu_layout = PM.get_menu_layout()

	local persisted_submenus = {
		"PM_Submenu_ModuleManager", "PM_Submenu_UIPosition", "PM_Submenu_Sync",
		"PM_Submenu_Favorites", "PM_Submenu_ProfileManager", "PM_Submenu_LearnedData",
		"PM_Submenu_Delays", "PM_Submenu_DelayTriggers", "PM_Submenu_Advanced", "PM_Submenu_Language"
	}

	local function on_panel_controls_created(panel)
		if panel ~= PM.lam_panel then return end
		CALLBACK_MANAGER:UnregisterCallback("LAM-PanelControlsCreated", on_panel_controls_created)
		if not is_pad then
			PM.ensure_table(PM.acct_saved, "submenu_open_state")
			for _, ref in ipairs(persisted_submenus) do
				LibAPH.PersistSubmenuOpenState(PM.acct_saved.submenu_open_state, ref)
			end
		end
		CALLBACK_MANAGER:RegisterCallback("LAM-RefreshPanel", PM.refresh_control_labels)
	end
	CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", on_panel_controls_created)

	PM_ui_refs.ctrl_active_dropdown = _G["PM_ActiveDropdown"]
	PM_ui_refs.ctrl_sync_dropdown = _G["PM_SyncDropdown"]
	PM_ui_refs.ctrl_learned_dropdown = _G["PM_LearnedDropdown"]
	PM_ui_refs.ctrl_fav_candidate_dropdown = _G["PM_FavCandidateDropdown"]
	PM_ui_refs.ctrl_fav_remove_dropdown = _G["PM_FavRemoveDropdown"]
end

PM_modules.menu = true
