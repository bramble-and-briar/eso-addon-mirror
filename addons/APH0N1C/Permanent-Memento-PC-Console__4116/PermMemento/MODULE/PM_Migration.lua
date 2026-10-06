--[[
    Copyright © 2025-2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

PMCore = PMCore or {}
local PM = PMCore

function PM.migrate_data()
	if PM.settings then
		local c_map = {
			activeId = "active_id", paused = "is_paused", logEnabled = "is_log_enabled",
			csaEnabled = "is_csa_enabled",
			randomOnLogin = "is_random_on_login", randomOnZone = "is_random_on_zone",
			loopInCombat = "is_loop_in_combat",
			useAccountSettings = "use_account_settings", showInHUD = "show_in_hud",
			unrestricted = "is_unrestricted",
			enableRandomFav = "enable_random_fav",
			enableLearning = "enable_learning", stopSpinning = "is_stop_spinning",
			migrated086 = "is_migrated_088", libWarningShown086 = "has_shown_lib_warning_088",
			lastVersion = "last_version",
			versionHistory = "version_history", learnedData = "learned_data",
			totalLoops = "total_loops", mementoUsage = "memento_usage",
			installDate = "install_date", delayIdle = "delay_idle", delayInMenu = "delay_in_menu",
			delayCombatEnd = "delay_combat_end", delayResurrect = "delay_resurrect",
			delayTeleport = "delay_teleport", delayMove = "delay_move",
			delaySprint = "delay_sprint", delayBlock = "delay_block", delaySwim = "delay_swim",
			delaySneak = "delay_sneak", delayMount = "delay_mount", delayCast = "delay_cast",
			csaDurations = "csa_durations", uiMenu = "ui_menu", sync = "sync_module"
		}
		for old_k, new_k in pairs(c_map) do
			if PM.settings[old_k] ~= nil then
				PM.settings[new_k] = PM.settings[old_k]
				PM.settings[old_k] = nil
			end
		end
		PM.settings.is_performance_mode = nil
		PM.settings.performanceMode = nil
		PM.settings.is_migrated_086 = nil
		PM.settings.has_shown_lib_warning_086 = nil
		PM.settings.enable_stats_ui = nil
		PM.settings.enableStatsUI = nil
		PM.settings.csaCleanupEnabled = nil
		PM.settings.autoCleanup = nil
		PM.settings.alcDisabledPM = nil
		PM.settings.is_auto_cleanup = nil
		PM.settings.is_csa_cleanup_enabled = nil
		PM.settings.alc_disabled_pm = nil
		if PM.settings.is_migrated_087 ~= nil then
			PM.settings.is_migrated_088 = PM.settings.is_migrated_087
			PM.settings.is_migrated_087 = nil
		end
		if PM.settings.has_shown_lib_warning_087 ~= nil then
			PM.settings.has_shown_lib_warning_088 = PM.settings.has_shown_lib_warning_087
			PM.settings.has_shown_lib_warning_087 = nil
		end
		if PM.settings.ui then
			if PM.settings.ui.locked ~= nil then
				PM.settings.ui.is_locked = PM.settings.ui.locked
				PM.settings.ui.locked = nil
			end
			if PM.settings.ui.hidden ~= nil then
				PM.settings.ui.is_hidden = PM.settings.ui.hidden
				PM.settings.ui.hidden = nil
			end
		end
		if PM.settings.sync_module then
			if PM.settings.sync_module.random ~= nil then
				PM.settings.sync_module.is_random = PM.settings.sync_module.random
				PM.settings.sync_module.random = nil
			end
			if PM.settings.sync_module.ignoreInCombat ~= nil then
				PM.settings.sync_module.ignore_in_combat = PM.settings.sync_module.ignoreInCombat
				PM.settings.sync_module.ignoreInCombat = nil
			end
			if PM.settings.sync_module.enabled ~= nil then
				PM.settings.sync_module.is_enabled = PM.settings.sync_module.enabled
				PM.settings.sync_module.enabled = nil
			end
		end

		if not PM.settings.is_migrated_088 then
			PM.settings.ui.is_hidden = true; PM.settings.show_in_hud = false
			PM.settings.is_log_enabled = false
			PM.settings.is_csa_enabled = true; PM.settings.enable_random_fav = false
			PM.settings.enable_learning = false; PM.settings.is_unrestricted = false
			PM.settings.is_loop_in_combat = false
			PM.settings.is_random_on_login = false; PM.settings.is_random_on_zone = false
			PM.settings.is_stop_spinning = false; PM.settings.sync_module.is_enabled = false
			PM.settings.is_migrated_088 = true
		end

		local delays_to_fix = {
			"delay_move", "delay_sprint", "delay_block", "delay_cast", "delay_swim",
			"delay_sneak", "delay_mount", "delay_idle", "delay_teleport", "delay_resurrect",
			"delay_in_menu", "delay_combat_end"
		}
		for _, k in ipairs(delays_to_fix) do
			if PM.settings[k] and PM.settings[k] > 20 then
				PM.settings[k] = PM.settings[k] / 1000
			end
		end
		for k, v in pairs(PM.settings.csa_durations) do
			if v > 10 then PM.settings.csa_durations[k] = v / 1000 end
		end
		if PM.settings.sync_module and PM.settings.sync_module.delay then
			if PM.settings.sync_module.delay > 20 then
				PM.settings.sync_module.delay = PM.settings.sync_module.delay / 1000
			end
		end
	end

	if PM.acct_saved and PM.acct_saved.learned_data then
		for _, data in pairs(PM.acct_saved.learned_data) do
			if data.aid and not data.ref_id then data.ref_id = data.aid; data.aid = nil end
			if data.refID and not data.ref_id then data.ref_id = data.refID; data.refID = nil end
		end
	end

	if _G["PermMemento"] then
		for _, w_data in pairs(_G["PermMemento"]) do
			if type(w_data) == "table" then
				for _, a_data in pairs(w_data) do
					if type(a_data) == "table" then
						for p_id, p_data in pairs(a_data) do
							if type(p_data) == "table" then
								if p_id == "$AccountWide" then
									p_data["autoResumeScan"] = nil
								elseif p_data["Character"] then
									p_data["Character"]["autoResumeScan"] = nil
								end
							end
						end
					end
				end
			end
		end
	end
	if PM.acct_saved then PM.acct_saved.autoResumeScan = nil end
	if PM.char_saved then PM.char_saved.autoResumeScan = nil end
end

function PM.migrate_legacy_profiles()
	PM.ensure_table(PM.acct_saved, "profiles")

	if not PM.acct_saved.is_profiles_migrated then
		local usr = GetDisplayName(); local srv = GetWorldName() or "Default"
		local raw_sv = _G["PermMemento"]
		if raw_sv and raw_sv[srv] and raw_sv[srv][usr] then
			for r_id, r_data in pairs(raw_sv[srv][usr]) do
				if r_id ~= "$AccountWide" and type(r_data) == "table" and r_data["Character"] then
					local char_nm = LibAPH.UnescapeName(r_data["$LastCharacterName"])
					if (not char_nm or char_nm == "") and type(r_id) == "string" and r_id:match("^%d+$") then
						char_nm = LibAPH.UnescapeName(zo_strformat("<<1>>", GetCharacterNameById(StringToId64(r_id))))
					end
					if char_nm and char_nm ~= "" and not PM.acct_saved.profiles[char_nm] then
						PM.acct_saved.profiles[char_nm] = ZO_DeepTableCopy(r_data["Character"])
					end
				end
			end
		end
		PM.acct_saved.is_profiles_migrated = true
		PM.log_msg(PM.L("CHAT_MIGRATED_TO_PROFILES"), true, "settings")
	end
end

PM._modules.migration = true
