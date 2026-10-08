--[[
    Copyright © 2025-2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

PMCore = PMCore or {}
local PM = PMCore
local init
local PM_defaults = PM.defaults
local PM_memento_data = PM.memento_data
local PM_modules = PM._modules
local PM_state = PM.state
local PM_ui_refs = PM.ui_refs
local on_player_activated

local function SetLoopEventRegistered(suffix, event, enabled, handler, filterType, filterValue)
	local namespace = PM.name .. suffix
	EVENT_MANAGER:UnregisterForEvent(namespace, event)
	if not enabled or not handler then return end
	EVENT_MANAGER:RegisterForEvent(namespace, event, handler)
	if filterType then
		EVENT_MANAGER:AddFilterForEvent(namespace, event, filterType, filterValue)
	end
end

function PM.refresh_loop_event_registrations()
	local loop = PM_modules.loop and PM.settings ~= nil
	SetLoopEventRegistered("_Combat", EVENT_COMBAT_EVENT, loop and PM.settings.busy_check_attacking, PM.on_combat_event,
		REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
	SetLoopEventRegistered("_Effect", EVENT_EFFECT_CHANGED, loop, PM.on_effect_changed,
		REGISTER_FILTER_UNIT_TAG, "player")
	SetLoopEventRegistered("_UseResult", EVENT_COLLECTIBLE_USE_RESULT, loop, PM.on_collectible_use_result)
	SetLoopEventRegistered("_AbilityUsed", EVENT_ACTION_SLOT_ABILITY_USED, loop and PM.settings.busy_check_casting, PM.on_ability_used)
end

function init(eventCode, addOnName)
	if addOnName ~= PM.name then return end
	EVENT_MANAGER:UnregisterForEvent(PM.name, EVENT_ADD_ON_LOADED)

	PM.chat = LibAPH.CreateChatLogger("PM", "FF9900")
	PM.chat_error = LibAPH.CreateChatLogger("PM Error", "FF0000")

	LibAPH.RegisterAddonDependencies(PM.name, { "LibAPH" }, { "LibAddonMenu-2.0", "LibHarvensAddonSettings", "LibGroupBroadcast" })

	local srv = GetWorldName() or "Default"
	local sv_name = "PermMemento"
	local account = GetDisplayName()
	local charId = GetCurrentCharacterId()

	if _G["PermMementoSaved"] and not _G[sv_name] then
		_G[sv_name] = _G["PermMementoSaved"]
		_G["PermMementoSaved"] = nil
	end

	if _G[sv_name] and _G[sv_name][srv] and _G[sv_name][srv][account] then
		local root_acct = _G[sv_name][srv][account]["$AccountWide"]
		if root_acct then
			_G[sv_name]["Default"] = _G[sv_name]["Default"] or {}
			_G[sv_name]["Default"][account] = _G[sv_name]["Default"][account] or {}
			_G[sv_name]["Default"][account]["$AccountWide"] = _G[sv_name]["Default"][account]["$AccountWide"] or {}
			_G[sv_name]["Default"][account]["$AccountWide"][srv] = _G[sv_name]["Default"][account]["$AccountWide"][srv] or {}

			if root_acct["AccountWide"] then
				for k, v in pairs(root_acct["AccountWide"]) do
					_G[sv_name]["Default"][account]["$AccountWide"][srv][k] = v
				end
			end

			for k, v in pairs(root_acct) do
				if k ~= "AccountWide" and type(k) == "string" and not string.match(k, "^%$") then
					_G[sv_name]["Default"][account]["$AccountWide"][srv][k] = v
				end
			end
		end

		if charId and _G[sv_name][srv][account][charId] then
			local root_char = _G[sv_name][srv][account][charId]
			if root_char then
				_G[sv_name]["Default"] = _G[sv_name]["Default"] or {}
				_G[sv_name]["Default"][account] = _G[sv_name]["Default"][account] or {}
				_G[sv_name]["Default"][account][charId] = _G[sv_name]["Default"][account][charId] or {}
				_G[sv_name]["Default"][account][charId][srv] = _G[sv_name]["Default"][account][charId][srv] or {}

				if root_char["Character"] then
					for k, v in pairs(root_char["Character"]) do
						_G[sv_name]["Default"][account][charId][srv][k] = v
					end
				end

				for k, v in pairs(root_char) do
					if k ~= "Character" and type(k) == "string" and not string.match(k, "^%$") then
						_G[sv_name]["Default"][account][charId][srv][k] = v
					end
				end
			end
		end

		_G[sv_name][srv] = nil
	end

	PM.acct_saved = ZO_SavedVars:NewAccountWide(
		sv_name, 1, srv, PM_defaults
	)
	PM.char_saved = ZO_SavedVars:NewCharacterIdSettings(
		sv_name, 1, srv, PM_defaults
	)

	local pm_deprecated = {"recentScans", "target_wipe_string"}
	for _, key in ipairs(pm_deprecated) do
		PM.acct_saved[key] = nil
		PM.char_saved[key] = nil
	end

	if PM.char_saved.use_account_settings == nil then
		PM.char_saved.use_account_settings = PM_defaults.use_account_settings
	end

	PM.ensure_table(PM.acct_saved, "module_disabled")
	local migration_needs_run = (PM.acct_saved.migrated_version ~= PM.version)
	if migration_needs_run then
		PM.acct_saved.module_disabled.migration = false
	end

	PM.apply_module_disable_overrides()

	local sv_tables = {PM.acct_saved, PM.char_saved}
	for _, sv in ipairs(sv_tables) do
		if sv.showInHUD ~= nil then
			sv.show_in_hud = sv.showInHUD
			sv.showInHUD = nil
		end
		if sv.ui and sv.ui.hidden ~= nil then
			sv.ui.is_hidden = sv.ui.hidden
			sv.ui.hidden = nil
		end
	end

	PM.settings = PM.char_saved.use_account_settings and PM.acct_saved or PM.char_saved


	EVENT_MANAGER:RegisterForEvent(PM.name .. "_UIRefresh", EVENT_PLAYER_ACTIVATED, function()
		EVENT_MANAGER:UnregisterForEvent(PM.name .. "_UIRefresh", EVENT_PLAYER_ACTIVATED)
		PM.call_optional(PM.toggle_ui_update, "UI module (toggle_ui_update)")
	end)

	PM.call_optional(PM.update_settings_reference, "update_settings_reference")
	PM.call_optional(PM.migrate_data, "Migration module (migrate_data)")
	if migration_needs_run then
		PM.acct_saved.migrated_version = PM.version
		PM.acct_saved.module_disabled.migration = true
	end

	if not PM_state.loop_token then PM_state.loop_token = 0 end

	if not PM.acct_saved.install_date then
		PM.acct_saved.install_date = PM.get_today_date_str()
	end

	LibAPH.CheckSelfVersion(PM.acct_saved, PM.version)

	PM.call_optional(PM.hook_collectible_activation, "Loop module (hook_collectible_activation)")
	PM.call_optional(PM.hook_beam_me_up_animation, "Loop module (hook_beam_me_up_animation)")
	PM.call_optional(PM.integrate_with_beam_me_up, "Loop module (integrate_with_beam_me_up)")
	PM.call_optional(PM.sync_engine.initialize, "Sync module (initialize)")

	PM.refresh_loop_event_registrations()

	PM.call_optional(PM.hook_error_capture, "Menu module (hook_error_capture)")
	EVENT_MANAGER:RegisterForEvent(PM.name, EVENT_PLAYER_ACTIVATED, function()
		on_player_activated(); PM.call_optional(PM.build_menu, "Menu module (build_menu)"); PM_state.pending_id = PM.settings.active_id
		LibAPH.StepCleanup(1)
	end)

	LibAPH.InitOnFirstShow(HUD_SCENE, function()
		PM.call_optional(PM.toggle_ui_update, "UI module (toggle_ui_update)")
	end)
	LibAPH.RunInitStages(PM.name, {
		function() end,
		function()
			if not IsConsoleUI() then PM.toggle_stats_ui_tracker() end
			local lam_ver, lam_en = PM.get_settings_library()
			if not (lam_en and lam_ver >= 30) and PM_modules.menu then PM.show_missing_library_warning() end
			PM.call_optional(PM.run_wizard_if_needed, "Wizard module (run_wizard_if_needed)")
		end,
	})

	local module_disabled = PM.acct_saved.module_disabled or {}

	SLASH_COMMANDS["/pmem"] = function(raw_arg)
		if not PM.settings then return end
		local parsed_cmd = raw_arg:lower()
		if parsed_cmd == "" then
			local send = LibAPH.SendRawChatLine
			if IsConsoleUI() or CHAT_SYSTEM then
				send("|cFF9900[PM]|r |c00FF00" .. PM.L("CHAT_AVAILABLE_COMMANDS") .. "|r")
				for _, sect in ipairs(PM.COMMAND_REFERENCE) do
					local lines = {}
					for _, entry in ipairs(sect.commands) do
						if entry.available() then
							local alias_part = entry.alias and (" (" .. PM.L("LABEL_OR") .. " |cFF0000" .. entry.alias .. "|r)") or ""
							table.insert(lines, "|c00FFFF" .. entry.cmd .. "|r" .. alias_part .. " |cFFD700- " .. PM.L(entry.desc_key) .. "|r")
						end
					end
					if #lines > 0 then
						send("|c9CD04C-- " .. PM.L(sect.section_key) .. " --|r\n" .. table.concat(lines, "\n"))
					end
				end

				local c_list = {"|c00FF00" .. PM.L("CHAT_SUPPORTED_MEMENTOS") .. "|r "}
				local arr_act = {}
				for f_id, md in pairs(PM_memento_data) do
					if IsCollectibleUnlocked(f_id) then table.insert(arr_act, md) end
				end
				table.sort(arr_act, function(a,b) return a.name < b.name end)
				for _, md in ipairs(arr_act) do
					table.insert(c_list, "- |cFFFFFF" .. md.name .. "|r |cFFD700(" .. (md.dur/1000) .. "s)|r ")
				end
				send("|cFF9900[PM]|r\n" .. table.concat(c_list))
			end
			return
		end

		local is_found = false
		for f_id, md in pairs(PM_memento_data) do
			if string.lower(md.name) == parsed_cmd then
				if IsCollectibleUnlocked(f_id) then
					PM.log_msg(PM.L("CHAT_AUTOLOOP_STARTED", md.name), true, "activation", 90)
					PM.call_optional(PM.start_loop, "Loop module (start_loop)", f_id); is_found = true; break
				else
					PM.log_msg(PM.L("CHAT_MEMENTO_NOT_UNLOCKED", md.name), true, "error", 80)
					is_found = true; break
				end
			end
		end
		if not is_found then
			for f_id, md in pairs(PM_memento_data) do
				if string.find(string.lower(md.name), parsed_cmd, 1, true) then
					if IsCollectibleUnlocked(f_id) then
						PM.log_msg(PM.L("CHAT_AUTOLOOP_STARTED", md.name), true, "activation", 90)
						PM.call_optional(PM.start_loop, "Loop module (start_loop)", f_id); is_found = true; break
					else
						PM.log_msg(PM.L("CHAT_MEMENTO_NOT_UNLOCKED", md.name), true, "error", 80)
						is_found = true; break
					end
				end
			end
		end
		if not is_found then
			PM.log_msg(PM.L("CHAT_MEMENTO_NOT_SUPPORTED"), true, "error", 90)
		end
	end
	SLASH_COMMANDS["/permmemento"] = SLASH_COMMANDS["/pmem"]

	SLASH_COMMANDS["/pmemrandfav"] = function()
		PM.settings.enable_random_fav = not PM.settings.enable_random_fav
		PM.refresh_slash_commands()
		local t_txt = PM.settings.enable_random_fav and PM.L("WORD_ON") or PM.L("WORD_OFF")
		PM.log_msg(PM.L("CHAT_RANDOM_FAV", t_txt), true, "settings")
	end

	SLASH_COMMANDS["/pmemlearn"] = function()
		PM.settings.enable_learning = not PM.settings.enable_learning
		PM.refresh_slash_commands()
		local t_txt = PM.settings.enable_learning and PM.L("WORD_ON") or PM.L("WORD_OFF")
		PM.log_msg(PM.L("CHAT_LEARNING_MODE", t_txt), true, "settings")
	end

	SLASH_COMMANDS["/pmemstop"] = function()
		PM.settings.active_id = nil; PM_state.loop_token = (PM_state.loop_token or 0) + 1
		PM.log_msg(PM.L("CHAT_AUTOLOOP_STOPPED"), true, "stop", 90)
		PM_state.pending_id = 0; PM_state.next_fire_time = 0
	end
	SLASH_COMMANDS["/permmementostop"] = SLASH_COMMANDS["/pmemstop"]

	if not IsConsoleUI() then
		SLASH_COMMANDS["/pmembugreport"] = function() PM.show_bug_report_box() end
		SLASH_COMMANDS["/pmembug"] = SLASH_COMMANDS["/pmembugreport"]
	end

	if GetDisplayName() == "@APHONlC" then
		SLASH_COMMANDS["/pmemsimulateerror"] = function() PM.dev_simulate_error() end
	end

	if PM_modules.ui and not module_disabled.ui then
		SLASH_COMMANDS["/pmemui"] = function()
			PM.settings.ui.is_hidden = not PM.settings.ui.is_hidden; PM.call_optional(PM.toggle_ui_update, "UI module (toggle_ui_update)")
			local t_txt = PM.settings.ui.is_hidden and PM.L("LABEL_HIDDEN_CAPS") or PM.L("LABEL_VISIBLE_CAPS")
			PM.log_msg(PM.L("CHAT_UI_VISIBILITY_SET", t_txt), true, "ui")
		end
		SLASH_COMMANDS["/pmemtoggleui"] = SLASH_COMMANDS["/pmemui"]

		SLASH_COMMANDS["/pmemhud"] = function()
			PM.settings.show_in_hud = not PM.settings.show_in_hud; PM.call_optional(PM.update_ui_scenes, "UI module (update_ui_scenes)")
			local t_txt = PM.settings.show_in_hud and PM.L("LABEL_HUD") or PM.L("LABEL_MENU")
			PM.log_msg(PM.L("CHAT_UI_MODE", t_txt), true, "settings")
		end
		SLASH_COMMANDS["/pmemuimode"] = SLASH_COMMANDS["/pmemhud"]
	end

	SLASH_COMMANDS["/pmemrandzone"] = function()
		PM.settings.is_random_on_zone = not PM.settings.is_random_on_zone
		local t_txt = PM.settings.is_random_on_zone and PM.L("WORD_ON") or PM.L("WORD_OFF")
		PM.log_msg(PM.L("CHAT_RANDOM_ON_ZONE", t_txt), true, "settings")
	end
	SLASH_COMMANDS["/pmemrandomzonechange"] = SLASH_COMMANDS["/pmemrandzone"]

	SLASH_COMMANDS["/pmemrandlog"] = function()
		PM.settings.is_random_on_login = not PM.settings.is_random_on_login
		local t_txt = PM.settings.is_random_on_login and PM.L("WORD_ON") or PM.L("WORD_OFF")
		PM.log_msg(PM.L("CHAT_RANDOM_ON_LOGIN", t_txt), true, "settings")
	end
	SLASH_COMMANDS["/pmemrandomlogin"] = SLASH_COMMANDS["/pmemrandlog"]

	SLASH_COMMANDS["/pmemrand"] = function()
		local r_id = PM.call_optional(PM.get_random_supported, "Loop module (get_random_supported)")
		if r_id then
			PM.settings.active_id = r_id
			PM.log_msg(PM.L("CHAT_RANDOMLY_SELECTED", PM.get_data(r_id).name), true, "random")
			PM.call_optional(PM.start_loop, "Loop module (start_loop)", r_id)
		elseif PM_modules.loop then
			PM.log_msg(PM.L("CHAT_NO_RANDOM_AVAILABLE"), true, "error", 90)
		end
	end
	SLASH_COMMANDS["/pmemrandom"] = SLASH_COMMANDS["/pmemrand"]

	SLASH_COMMANDS["/pmemrandlrn"] = function()
		local r_id = PM.call_optional(PM.get_random_learned, "Loop module (get_random_learned)")
		if r_id then
			PM.settings.active_id = r_id
			PM.log_msg(PM.L("CHAT_RANDOMLY_SELECTED_LEARNED", PM.get_data(r_id).name), true, "random")
			PM.call_optional(PM.start_loop, "Loop module (start_loop)", r_id)
		else PM.log_msg(PM.L("CHAT_NO_LEARNED_DATA"), true, "error") end
	end
	SLASH_COMMANDS["/pmemrandomlearned"] = SLASH_COMMANDS["/pmemrandlrn"]

	SLASH_COMMANDS["/pmemcsa"] = function()
		PM.settings.is_csa_enabled = not PM.settings.is_csa_enabled
		local t_txt = PM.settings.is_csa_enabled and PM.L("WORD_ON") or PM.L("WORD_OFF")
		PM.log_msg(PM.L("CHAT_SCREEN_ANNOUNCEMENTS", t_txt), true, "settings")
	end
	SLASH_COMMANDS["/pmemtogglecsa"] = SLASH_COMMANDS["/pmemcsa"]

	SLASH_COMMANDS["/pmemfree"] = function()
		PM.settings.is_unrestricted = not PM.settings.is_unrestricted
		local t_txt = PM.settings.is_unrestricted and PM.L("WORD_ON") or PM.L("WORD_OFF")
		PM.log_msg(PM.L("CHAT_UNRESTRICTED_MODE", t_txt), true, "settings")
	end
	SLASH_COMMANDS["/pmemunrestrict"] = SLASH_COMMANDS["/pmemfree"]

	if PM_modules.ui and not module_disabled.ui then
		SLASH_COMMANDS["/pmemlock"] = function()
			PM.settings.ui.is_locked = not PM.settings.ui.is_locked
			if PM_ui_refs.ui_window then
				PM_ui_refs.ui_window:SetMovable(not PM.settings.ui.is_locked)
			end
			local t_txt = PM.settings.ui.is_locked and PM.L("LABEL_LOCKED") or PM.L("LABEL_UNLOCKED")
			PM.log_msg(PM.L("CHAT_UI_LOCK_STATE", t_txt), true, "ui")
		end
		SLASH_COMMANDS["/pmemuilock"] = SLASH_COMMANDS["/pmemlock"]

		SLASH_COMMANDS["/pmemresetui"] = function()
			PM.settings.ui.left = PM_defaults.ui.left
			PM.settings.ui.top = PM_defaults.ui.top
			PM.settings.ui_menu.left = PM_defaults.ui_menu.left
			PM.settings.ui_menu.top = PM_defaults.ui_menu.top
			PM.settings.ui.point = nil
			PM.settings.ui_menu.point = nil
			PM.call_optional(PM.reset_ui_position, "UI module (reset_ui_position)"); PM.log_msg(PM.L("CHAT_UI_POSITION_RESET"), true, "ui")
		end
		SLASH_COMMANDS["/pmemuireset"] = SLASH_COMMANDS["/pmemresetui"]
	end

	if PM_modules.menu and not module_disabled.menu then
		SLASH_COMMANDS["/pmemwipe"] = function() PM.call_optional(PM.delete_all_learned_data, "Menu module (delete_all_learned_data)") end
		SLASH_COMMANDS["/pmemdeletealllearned"] = SLASH_COMMANDS["/pmemwipe"]
	end

	SLASH_COMMANDS["/pmemscan"] = function() PM.call_optional(PM.auto_scan_mementos, "Loop module (auto_scan_mementos)") end
	SLASH_COMMANDS["/pmemautolearn"] = SLASH_COMMANDS["/pmemscan"]

	SLASH_COMMANDS["/pmemlist"] = function()
		if PM.acct_saved and PM.acct_saved.learned_data then
			local out_msg = PM.L("CHAT_LEARNED_DATA_HEADER") .. "\n"; local cc = 0
			for _, md in pairs(PM.acct_saved.learned_data) do
				out_msg = out_msg .. "- " .. md.name .. " (" .. (md.dur/1000) .. "s)\n"
				cc = cc + 1
			end
			if cc == 0 then PM.log_msg(PM.L("CHAT_LEARNED_DATA_EMPTY"), false)
			else PM.log_msg(out_msg, false) end
		else PM.log_msg(PM.L("CHAT_LEARNED_DATA_EMPTY"), false) end
	end
	SLASH_COMMANDS["/pmemlearned"] = SLASH_COMMANDS["/pmemlist"]

	SLASH_COMMANDS["/pmemplay"] = function(raw_arg)
		local c_arg = raw_arg:lower()
		if c_arg and c_arg ~= "" then
			if PM.acct_saved and PM.acct_saved.learned_data then
				for f_id, md in pairs(PM.acct_saved.learned_data) do
					if string.lower(md.name) == c_arg then
						PM.settings.active_id = f_id
						PM.log_msg(PM.L("CHAT_ACTIVATED_LEARNED", md.name), true, "activation")
						PM.call_optional(PM.start_loop, "Loop module (start_loop)", f_id); return
					end
				end
				for f_id, md in pairs(PM.acct_saved.learned_data) do
					if string.find(string.lower(md.name), c_arg, 1, true) then
						PM.settings.active_id = f_id
						PM.log_msg(PM.L("CHAT_ACTIVATED_LEARNED", md.name), true, "activation")
						PM.call_optional(PM.start_loop, "Loop module (start_loop)", f_id); return
					end
				end
			end
			PM.log_msg(PM.L("CHAT_LEARNED_MEMENTO_NOT_FOUND", c_arg), true, "error")
		end
	end
	SLASH_COMMANDS["/pmemactivatelearned"] = SLASH_COMMANDS["/pmemplay"]

	SLASH_COMMANDS["/pmemclientinfo"] = function()
		local text = PM.call_optional(PM.get_stats_text, "Loop module (get_stats_text)")
		if not text then return end
		local is_console = IsConsoleUI()
		if is_console or CHAT_SYSTEM then
			local prefix = "|cFF9900[PermMemento]|r "
			local blank_prefix = string.rep(" ", 14)
			local is_first = true
			for line in string.gmatch(text, "[^\n]+") do
				local tagged = (is_first and prefix or blank_prefix) .. line
				LibAPH.SendRawChatLine(tagged)
				is_first = false
			end
		end
		if is_console and PM.settings.is_csa_enabled then
			PM.safe_csa("|cFFD700" .. PM.L("CSA_CLIENT_INFO_SENT") .. "|r")
		end
	end

	SLASH_COMMANDS["/pmemunloadsync"] = function() PM.toggle_module_disabled("sync") end
	SLASH_COMMANDS["/pmemunloadmigration"] = function() PM.toggle_module_disabled("migration") end
	SLASH_COMMANDS["/pmemunloadui"] = function() PM.toggle_module_disabled("ui") end
	SLASH_COMMANDS["/pmemunloadmenu"] = function() PM.toggle_module_disabled("menu") end
	SLASH_COMMANDS["/pmemunloadwizard"] = function() PM.toggle_module_disabled("wizard") end
	if PM_modules.wizard and not module_disabled.wizard then
		SLASH_COMMANDS["/pmemwizard"] = function()
			PM.call_optional(PM.run_wizard, "Wizard module (run_wizard)")
		end
	end

	SLASH_COMMANDS["/pmemlibwarn"] = function()
		PM.settings.is_lib_warning_enabled = not PM.settings.is_lib_warning_enabled
		local t_txt = PM.settings.is_lib_warning_enabled and PM.L("WORD_ON") or PM.L("WORD_OFF")
		PM.log_msg(PM.L("CHAT_LIBWARN_TOGGLE", t_txt), true, "settings")
	end

	SLASH_COMMANDS["/pmempause"] = function()
		PM.settings.is_paused = not PM.settings.is_paused
		if PM.settings.is_paused then
			PM.log_msg(PM.L("CHAT_AUTOLOOP_PAUSED"), true, "stop", 90)
		else
			PM.log_msg(PM.L("CHAT_AUTOLOOP_RESUMED"), true, "activation", 90)
			if PM.settings.active_id then PM.call_optional(PM.run_loop, "Loop module (run_loop)", PM_state.loop_token) end
		end
	end
	SLASH_COMMANDS["/pmemtogglepause"] = SLASH_COMMANDS["/pmempause"]

	SLASH_COMMANDS["/pmemcombat"] = function()
		PM.settings.is_loop_in_combat = not PM.settings.is_loop_in_combat
		local t_txt = PM.settings.is_loop_in_combat and PM.L("WORD_ON") or PM.L("WORD_OFF")
		PM.log_msg(PM.L("CHAT_LOOP_IN_COMBAT", t_txt), true, "settings")
	end
	SLASH_COMMANDS["/pmemloopincombat"] = SLASH_COMMANDS["/pmemcombat"]

	SLASH_COMMANDS["/pmemacct"] = function()
		PM.char_saved.use_account_settings = not PM.char_saved.use_account_settings
		PM.call_optional(PM.update_settings_reference, "update_settings_reference")
		PM.log_msg(PM.L("CHAT_ACCOUNT_WIDE_SETTINGS"), true, "settings", 80)
		zo_callLater(function() ReloadUI("ingame") end, 2000)
	end
	SLASH_COMMANDS["/pmemuseaccountsettings"] = SLASH_COMMANDS["/pmemacct"]

	if PM_modules.menu and not module_disabled.menu then
		SLASH_COMMANDS["/pmemwipefav"] = function() PM.call_optional(PM.delete_all_favorites, "Menu module (delete_all_favorites)") end
		SLASH_COMMANDS["/pmemdeleteallfavorites"] = SLASH_COMMANDS["/pmemwipefav"]
	end

	SLASH_COMMANDS["/pmemreset"] = function() PM.reset_to_defaults() end
	SLASH_COMMANDS["/pmemresetdefaults"] = SLASH_COMMANDS["/pmemreset"]

	if PM_modules.ui and not module_disabled.ui then
		SLASH_COMMANDS["/pmemhudscale"] = function(raw_arg)
			local n_val = tonumber(raw_arg)
			if n_val and n_val >= 0.5 and n_val <= 2.0 then
				PM.settings.ui.scale = n_val; PM.call_optional(PM.apply_ui_size, "UI module (apply_ui_size)")
				PM.log_msg(PM.L("CHAT_HUD_SCALE_SET", n_val), true, "ui")
			else PM.log_msg(PM.L("CHAT_USAGE_HUDSCALE"), true, "error", 90) end
		end
		SLASH_COMMANDS["/pmemsethudscale"] = SLASH_COMMANDS["/pmemhudscale"]

		SLASH_COMMANDS["/pmemmenuscale"] = function(raw_arg)
			local n_val = tonumber(raw_arg)
			if n_val and n_val >= 0.5 and n_val <= 2.0 then
				PM.settings.ui_menu.scale = n_val; PM.call_optional(PM.apply_ui_size, "UI module (apply_ui_size)")
				PM.log_msg(PM.L("CHAT_MENU_SCALE_SET", n_val), true, "ui")
			else PM.log_msg(PM.L("CHAT_USAGE_MENUSCALE"), true, "error", 90) end
		end
		SLASH_COMMANDS["/pmemsetmenuscale"] = SLASH_COMMANDS["/pmemmenuscale"]
	end

	local PM_DELAY_KEYS = {
		idle = "delay_idle", inmenu = "delay_in_menu", combatend = "delay_combat_end",
		resurrect = "delay_resurrect", teleport = "delay_teleport", move = "delay_move",
		block = "delay_block", swim = "delay_swim",
		sneak = "delay_sneak", mount = "delay_mount", cast = "delay_cast"
	}
	SLASH_COMMANDS["/pmemset"] = function(raw_arg)
		if not PM.settings then return end
		local key, val_str = string.match(raw_arg or "", "^(%S+)%s+(%S+)$")
		if raw_arg == "list" then
			local names = {}
			for k in pairs(PM_DELAY_KEYS) do table.insert(names, k) end
			table.insert(names, "syncdelay")
			table.sort(names)
			PM.log_msg(PM.L("CHAT_VALID_PMEMSET_NAMES", table.concat(names, ", ")), true, "settings", 90)
			return
		end
		if not key then
			PM.log_msg(PM.L("CHAT_USAGE_PMEMSET"), true, "error", 90)
			return
		end
		local val = tonumber(val_str)
		if not val or val < 0 then
			PM.log_msg(PM.L("CHAT_VALUE_MUST_BE_NONNEGATIVE"), true, "error", 90)
			return
		end
		if PM_DELAY_KEYS[key] then
			PM.settings[PM_DELAY_KEYS[key]] = val
			PM.log_msg(PM.L("CHAT_DELAY_SET", key, val), true, "settings", 80)
		elseif key == "syncdelay" then
			PM.settings.sync_module.delay = val
			PM.log_msg(PM.L("CHAT_SYNC_DELAY_SET", val), true, "settings", 80)
		else
			PM.log_msg(PM.L("CHAT_UNKNOWN_SETTING_NAME", key), true, "error", 90)
		end
	end

	if not IsConsoleUI() then
		SLASH_COMMANDS["/pmemlogs"] = function()
			PM.settings.is_log_enabled = not PM.settings.is_log_enabled
			local t_txt = PM.settings.is_log_enabled and PM.L("WORD_ON") or PM.L("WORD_OFF")
			PM.log_msg(PM.L("CHAT_CHAT_LOGS", t_txt), true, "settings")
		end
		SLASH_COMMANDS["/pmemchatlogs"] = SLASH_COMMANDS["/pmemlogs"]

		SLASH_COMMANDS["/pmemnospin"] = function()
			PM.settings.is_stop_spinning = not PM.settings.is_stop_spinning
			PM.call_optional(PM.apply_spin_stop, "Loop module (apply_spin_stop)")
			local t_txt = PM.settings.is_stop_spinning and PM.L("WORD_ON") or PM.L("WORD_OFF")
			PM.log_msg(PM.L("CHAT_STOP_SPINNING", t_txt), true, "settings")
		end
		SLASH_COMMANDS["/pmemstopspinning"] = SLASH_COMMANDS["/pmemnospin"]

		if PM_modules.sync and not module_disabled.sync then
			SLASH_COMMANDS["/pmsyncon"] = function()
				PM.settings.sync_module.is_enabled = not PM.settings.sync_module.is_enabled
				PM.toggle_sync_listener()
				PM.refresh_slash_commands()
				local t_txt = PM.settings.sync_module.is_enabled and PM.L("WORD_ON") or PM.L("WORD_OFF")
				PM.log_msg(PM.L("CHAT_SYNC_LISTENING", t_txt), true, "settings")
			end
			SLASH_COMMANDS["/pmemsyncenable"] = SLASH_COMMANDS["/pmsyncon"]

			SLASH_COMMANDS["/pmsyncdelay"] = function()
				PM.settings.sync_module.is_random = not PM.settings.sync_module.is_random
				local t_txt = PM.settings.sync_module.is_random and PM.L("WORD_ON") or PM.L("WORD_OFF")
				PM.log_msg(PM.L("CHAT_RANDOM_SYNC_DELAY", t_txt), true, "settings")
			end
			SLASH_COMMANDS["/pmemsyncrandomdelay"] = SLASH_COMMANDS["/pmsyncdelay"]
		end
	end

	if PM_modules.sync and not module_disabled.sync then
		SLASH_COMMANDS["/pmsyncstop"] = function()
			if PM.send_sync then PM.send_sync("stop") end
			if PM.settings then
				PM.settings.active_id = nil; PM_state.loop_token = (PM_state.loop_token or 0) + 1
			end
			PM_state.next_fire_time = 0
		end
		SLASH_COMMANDS["/permmementosyncstop"] = SLASH_COMMANDS["/pmsyncstop"]

		SLASH_COMMANDS["/pmsyncrand"] = function()
			local r_id = PM.call_optional(PM.get_random_any, "Loop module (get_random_any)")
			if not r_id then
				if PM_modules.loop then PM.log_msg(PM.L("CHAT_NO_RANDOM_AVAILABLE"), true, "error", 90) end
			elseif PM.send_sync and PM.send_sync("play", r_id) then
				PM.log_msg(PM.L("CHAT_SENT_RANDOM_SYNC"), true, "sync", 90)
			end
		end
		SLASH_COMMANDS["/permmementosyncrandom"] = SLASH_COMMANDS["/pmsyncrand"]
	end

	PM.refresh_slash_commands()
end

function on_player_activated()
	PM.check_sync_zone_protection()

	if PM.acct_saved and PM.acct_saved.recentScans and #PM.acct_saved.recentScans > 0 then
		zo_callLater(function()
			PM.log_msg(PM.L("CHAT_NEWLY_LEARNED_HEADER"), false)
			for _, f_id in ipairs(PM.acct_saved.recentScans) do
				local md = PM.acct_saved.learned_data[f_id]
				if md then
					local out_msg = PM.L(
						"CHAT_NEWLY_LEARNED_ENTRY",
						md.name, md.id, md.ref_id, md.dur
					)
					PM.log_msg(out_msg, false)
				end
			end
			PM.acct_saved.recentScans = nil
		end, 2000)
	end

	local w_ms = (PM.settings.delay_teleport or 5) * 1000
	local r_zone = PM.settings.is_random_on_zone
	local r_log = PM.settings.is_random_on_login
	local r_fav = PM.settings.enable_random_fav

	if r_zone and r_fav then
		local r_id = PM.call_optional(PM.get_random_supported, "Loop module (get_random_supported)")
		if r_id then
			PM.settings.active_id = r_id
			PM.log_msg(PM.L("CHAT_ZONE_RANDOM", PM.get_data(r_id).name), true, "random")
		end
	elseif r_log and not PM.settings.active_id and r_fav then
		local r_id = PM.call_optional(PM.get_random_supported, "Loop module (get_random_supported)")
		if r_id then
			PM.settings.active_id = r_id
			PM.log_msg(PM.L("CHAT_LOGIN_RANDOM", PM.get_data(r_id).name), true, "random")
		end
	end

	if PM.settings and PM.settings.active_id and not PM.settings.is_paused then
		local tkn = PM_state.loop_token
		zo_callLater(function()
			if PM.settings.active_id then PM.call_optional(PM.run_loop, "Loop module (run_loop)", tkn) end
		end, w_ms)
	end
end

EVENT_MANAGER:RegisterForEvent(PM.name, EVENT_ADD_ON_LOADED, function(...) init(...) end)
