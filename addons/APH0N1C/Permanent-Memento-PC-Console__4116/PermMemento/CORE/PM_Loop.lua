--[[
    Copyright © 2025-2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

PMCore = PMCore or {}
local PM = PMCore
local PM_memento_data = PM.memento_data
local PM_modules = PM._modules
local PM_state = PM.state

function PM.get_stats_text()
	local install_d_raw = (PM.acct_saved and PM.acct_saved.install_date) or PM.L("INSTALL_DATE_UNKNOWN")
	local today_str = PM.get_today_date_str()
	local install_d = LibAPH.FormatInstallDateLine(install_d_raw, today_str)
	local install_line = PM.L("FIELD_INSTALLED_SINCE") .. " " .. install_d

	if PM_state.cached_stats_suffix then
		return install_line .. PM_state.cached_stats_suffix
	end

	local v_hist = (PM.acct_saved and PM.acct_saved.version_history) or {PM.version}
	local v_hist_str = LibAPH.FormatVersionHistory(v_hist, PM.version)

	local lam_ver, lam_en, lhas_ver, lhas_en = PM.get_settings_library()

	local function get_lib_str(ver, en, name, req)
		return LibAPH.FormatLibraryVersion(ver, en, req, {
			missing = function() return string.format("|cFF0000%s (%s)|r", name, PM.L("STATE_MISSING")) end,
			disabled = function(v) return string.format("|cFF0000%s %s|r", name, PM.L("STATE_DISABLED_VER", v)) end,
			exact = function(v) return string.format("|c00FF00%s (v%d)|r", name, v) end,
			old = function(v, r) return string.format("|c888888%s|r |cFF0000%s|r |c00FFFF%s|r", name, PM.L("STATE_OLD", v), PM.L("STATE_EXPECTED", r)) end,
			newer = function(v, r) return string.format("|c00FFFF%s %s %s|r", name, PM.L("STATE_NEWER", v), PM.L("STATE_EXPECTED", r)) end,
		})
	end

	local lib_parts = { "|c00FF00LibAPH (v" .. LibAPH.VERSION .. ")|r" }
	if PM_modules.menu then
		table.insert(lib_parts, get_lib_str(lam_ver, lam_en, "LAM2", PM.REQUIRED_LAM_VERSION))
		if IsConsoleUI() then
			table.insert(lib_parts, get_lib_str(lhas_ver, lhas_en, "LHAS", PM.REQUIRED_LHAS_VERSION))
		end
	end
	local lib_str = (#lib_parts > 0) and table.concat(lib_parts, " | ") or ("|c888888" .. PM.L("LIB_NA") .. "|r")

	local module_files = {
		migration = "MODULE/PM_Migration.lua",
		menu = "MODULE/PM_Menu.lua",
		ui = "MODULE/PM_UI.lua",
		sync = "PC/PM_Sync.lua",
		wizard = "MODULE/PM_Wizard.lua"
	}
	local module_order = { "migration", "ui", "wizard", "menu", "sync" }
	local function pm_module_state(mod_key)
		if PM_modules[mod_key] then return "loaded" end
		local disabled_by_user = PM.acct_saved.module_disabled and PM.acct_saved.module_disabled[mod_key]
		return disabled_by_user and "unloaded" or "missing"
	end
	local modules_str = LibAPH.BuildModuleFileList(
		module_order, module_files, pm_module_state,
		{ loaded = PM.L("STATE_LOADED"), unloaded = PM.L("STATE_UNLOADED"), missing = PM.L("STATE_MISSING_FILE") }
	)

	local wizard_status = ""
	if PM.acct_saved.wizard_skipped then
		wizard_status = "\n" .. PM.L("FIELD_WIZARD") .. " |cFF0000" .. PM.L("STATE_SETUP_SKIPPED") .. "|r"
	elseif PM.acct_saved.wizard_completed then
		if PM.acct_saved.wizard_lite_mode and PM.matches_lite_mode_config() then
			wizard_status = "\n" .. PM.L("FIELD_WIZARD") .. " |c00FF00" .. PM.L("STATE_SETUP_DONE_LITE") .. "|r"
		else
			wizard_status = "\n" .. PM.L("FIELD_WIZARD") .. " |c00FF00" .. PM.L("STATE_SETUP_DONE") .. "|r"
		end
	end

	local platform_line = "\n" .. PM.L("FIELD_PLATFORM") .. " |cFFFFFF" .. PM.get_platform_str() .. "|r"

	local lang_line = "\n" .. PM.L("FIELD_CURRENT_LANGUAGE") .. " |cFFFFFF" .. tostring(GetCVar("Language.2")) .. "|r"

	local suffix = "\n" .. PM.L("FIELD_VERSION_HISTORY") .. " " .. v_hist_str
		.. "\n" .. PM.L("FIELD_LIBRARY_VERSION") .. " " .. lib_str
		.. platform_line .. wizard_status .. lang_line .. "\n" .. PM.L("FIELD_MODULES") .. "\n  " .. modules_str
	PM_state.cached_stats_suffix = suffix
	return install_line .. suffix
end

function PM.update_learned_count()
	local cc = 0
	if PM.acct_saved and PM.acct_saved.learned_data then
		for _ in pairs(PM.acct_saved.learned_data) do cc = cc + 1 end
	end
	PM_state.learned_count = cc
end

function PM.update_fav_count()
	local cc = 0
	if PM.settings and PM.settings.favorites then
		for _, v in pairs(PM.settings.favorites) do if v then cc = cc + 1 end end
	end
	PM_state.current_fav_count = cc
end

function PM.safe_csa(title, body, lifespan_ms)
	LibAPH.SafeCSA(PM.settings.is_csa_enabled, title, body, lifespan_ms or 6000)
end

function PM.log_msg(msg, is_csa, dur_key, limit_override)
	if not PM.settings then return end
	if PM.settings.is_csa_enabled and is_csa then
		PM_state.csa_debounce_token = (PM_state.csa_debounce_token or 0) + 1
		local my_token = PM_state.csa_debounce_token
		local csa_text = "|cFFD700" .. tostring(msg) .. "|r"
		zo_callLater(function()
			if PM_state.csa_debounce_token == my_token then
				PM.safe_csa(csa_text)
			end
		end, 1500)
	end
	if PM.settings.is_log_enabled then
		PM.chat:Print((string.gsub(tostring(msg), "\n", " ")))
		if IsConsoleUI() and not is_csa and PM.settings.is_csa_enabled then
			PM.safe_csa("|cFFD700" .. tostring(msg) .. "|r")
		end
	end
end

function PM.apply_spin_stop()
	if IsConsoleUI() then return end
	local scene_list = { "character", "stats", "interact" }
	for _, s_name in ipairs(scene_list) do
		local scene_obj = SCENE_MANAGER:GetScene(s_name)
		if scene_obj then
			local has_frag = scene_obj:HasFragment(FRAME_PLAYER_FRAGMENT)
			if PM.settings.is_stop_spinning and has_frag then
				scene_obj:RemoveFragment(FRAME_PLAYER_FRAGMENT)
			elseif not PM.settings.is_stop_spinning and not has_frag then
				scene_obj:AddFragment(FRAME_PLAYER_FRAGMENT)
			end
		end
	end
end

function PM.get_random_supported()
	local avail = {}
	if PM.settings.enable_random_fav and PM.settings.favorites then
		for f_id, is_fav in pairs(PM.settings.favorites) do
			if is_fav and IsCollectibleUnlocked(f_id) then
				local is_hardcoded = (PM_memento_data[f_id] ~= nil)
				if PM.settings.is_unrestricted or is_hardcoded then table.insert(avail, f_id) end
			end
		end
	end
	if #avail > 0 then return avail[math.random(#avail)] end

	for f_id, _ in pairs(PM_memento_data) do
		if IsCollectibleUnlocked(f_id) then table.insert(avail, f_id) end
	end

	if PM.settings.is_unrestricted and PM.acct_saved and PM.acct_saved.learned_data then
		for f_id, _ in pairs(PM.acct_saved.learned_data) do
			if IsCollectibleUnlocked(f_id) then table.insert(avail, f_id) end
		end
	end
	return #avail > 0 and avail[math.random(#avail)] or nil
end

function PM.get_random_learned()
	if not PM.acct_saved or not PM.acct_saved.learned_data then return nil end
	local avail = {}
	for f_id, _ in pairs(PM.acct_saved.learned_data) do
		if IsCollectibleUnlocked(f_id) then table.insert(avail, f_id) end
	end
	return #avail > 0 and avail[math.random(#avail)] or nil
end

function PM.get_random_any()
	local avail = {}
	for i = 1, GetTotalCollectiblesByCategoryType(COLLECTIBLE_CATEGORY_TYPE_MEMENTO) do
		local f_id = GetCollectibleIdFromType(COLLECTIBLE_CATEGORY_TYPE_MEMENTO, i)
		if f_id and IsCollectibleUnlocked(f_id) then table.insert(avail, f_id) end
	end
	return #avail > 0 and avail[math.random(#avail)] or nil
end

function PM.update_movement_state()
	if not GetUnitRawWorldPosition then return end
	PM.movement_tracker:Update()
	PM_state.is_moving = PM.movement_tracker:IsMoving()
end

local BUSY_RULES = {
	{ "busy_check_teleport", function() return PM.teleport_tracker:IsTeleporting() end, nil, "delay_teleport", 5 },
	{ "busy_check_resurrecting", function() return IsResurrectPending() end, "LABEL_RESURRECTING", "delay_resurrect", 5 },
	{ "busy_check_resurrecting", function() return IsUnitReincarnating("player") end, "LABEL_REVIVING", "delay_resurrect", 5 },
	{ "busy_check_dead", function() return IsUnitDead("player") end, "LABEL_DEAD", "delay_dead", 2 },
	{ "is_loop_in_combat", function() return IsUnitInCombat("player") end, "LABEL_COMBAT", "delay_combat_end", 5, invert = true },
	{ "busy_check_crafting", function() return LibAPH.IsPlayerCrafting() end, "LABEL_CRAFTING", "delay_crafting", 2 },
	{ "busy_check_interacting", function() return LibAPH.IsPlayerInteracting() end, "LABEL_INTERACTING", "delay_in_menu", 5 },
	{ "busy_check_menu", function() return LibAPH.IsPlayerInMenu() end, "LABEL_MENU", "delay_in_menu", 5 },
	{ "busy_check_blocking", function() return IsBlockActive() end, "LABEL_BLOCKING", "delay_block", 5 },
	{ "busy_check_swimming", function() return IsUnitSwimming("player") end, "LABEL_SWIMMING", "delay_swim", 5 },
	{ "busy_check_mounted", function() return IsMounted("player") end, "LABEL_MOUNTED", "delay_mount", 5 },
	{ "busy_check_sneaking", function() return GetUnitStealthState("player") ~= STEALTH_STATE_NONE end, "LABEL_SNEAKING", "delay_sneak", 5 },
	{ "busy_check_moving", function() return PM_state.is_moving end, "LABEL_MOVING", "delay_move", 5 },
}
local function get_busy_state()
	local settings = PM.settings
	for i = 1, #BUSY_RULES do
		local rule = BUSY_RULES[i]
		local enabled = settings[rule[1]]
		if rule.invert then enabled = not enabled end
		if enabled ~= false and rule[2]() then
			return true, rule[3] and PM.L(rule[3]) or nil, (settings[rule[4]] or rule[5]) * 1000
		end
	end
	return false, nil, 0
end

local function resolve_memento_duration_ms(c_id, r_id, begin_s, end_s)
	if begin_s and end_s and end_s > begin_s then
		return zo_floor((end_s - begin_s) * 1000 + 0.5)
	end
	if r_id and r_id > 0 and GetAbilityDuration then
		local ab_dur = GetAbilityDuration(r_id)
		if ab_dur and ab_dur > 0 then return ab_dur end
	end
	local _, cd_dur = GetCollectibleCooldownAndDuration(c_id)
	if cd_dur and cd_dur > 0 then return cd_dur end
	return 10000
end

function PM.on_effect_changed(eventCode, changeType, effectSlot, effectName, unitTag, beginTime,
							  endTime, stackCount, iconName, buffType, effectType, abilityType,
							  statusEffectType, unitName, unitId, abilityId, sourceUnitId)
	if not PM.settings then return end
	local is_gain = (changeType == EFFECT_RESULT_GAINED)

	if is_gain and not PM.settings.is_paused then
		local matched_id = nil
		for fid, fmd in pairs(PM_memento_data) do
			if fmd.ref_id and fmd.ref_id > 0 and fmd.ref_id == abilityId then
				matched_id = fid; break
			end
		end
		if not matched_id and PM.acct_saved and PM.acct_saved.learned_data then
			for fid, fmd in pairs(PM.acct_saved.learned_data) do
				if fmd.ref_id and fmd.ref_id > 0 and fmd.ref_id == abilityId then
					matched_id = fid; break
				end
			end
		end
		if not matched_id and PM.settings.is_unrestricted then
			local max_cat = GetTotalCollectiblesByCategoryType(COLLECTIBLE_CATEGORY_TYPE_MEMENTO)
			for i = 1, max_cat do
				local c_id = GetCollectibleIdFromType(COLLECTIBLE_CATEGORY_TYPE_MEMENTO, i)
				if c_id then
					local c_data = ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(c_id)
					local r_id = c_data and c_data.GetReferenceId and c_data:GetReferenceId()
					if r_id and r_id > 0 and r_id == abilityId then
						matched_id = c_id; break
					end
				end
			end
		end
		if matched_id and matched_id ~= PM.settings.active_id then
			PM.settings.active_id = matched_id
			PM_state.loop_token = (PM_state.loop_token or 0) + 1
		end
	end

	if not PM.settings.active_id then return end

	if PM.settings.enable_learning and (PM.settings.is_unrestricted or PM_state.is_scanning) and is_gain then
		 local act_id = PM.settings.active_id
		 local is_unlearned = (PM.acct_saved and PM.acct_saved.learned_data and
							   not PM.acct_saved.learned_data[act_id])

		 if not PM_memento_data[act_id] and is_unlearned then
			 local c_name = GetCollectibleName(act_id)
			 PM.ensure_table(PM.acct_saved, "learned_data")
			 local r_id = 0
			 local c_data = ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(act_id)
			 if c_data and c_data.GetReferenceId then r_id = c_data:GetReferenceId() end
			 if r_id == 0 then r_id = abilityId end
			 local s_dur = resolve_memento_duration_ms(act_id, r_id, beginTime, endTime)
			 PM.acct_saved.learned_data[act_id] = {
				 id = act_id, ref_id = r_id, dur = s_dur, name = c_name
			 }
			 PM.update_learned_count()
			 local out_msg = string.format(
				 "Saved: %s\nID: %d | RefID: %d | Dur: %dms | Total Learned: %d",
				 c_name, act_id, r_id, s_dur, PM_state.learned_count
			 )
			 PM.log_msg(out_msg, true, "settings", 70)
		 end
	end

	local md = PM.get_data(PM.settings.active_id)
	local is_match = false
	if md and md.ref_id > 0 and abilityId == md.ref_id then is_match = true end

	if is_match and changeType == EFFECT_RESULT_FADED then
		PM_state.loop_token = (PM_state.loop_token or 0) + 1
		PM.run_loop(PM_state.loop_token)
	end
end

function PM.auto_scan_mementos()
	if not PM.settings.enable_learning then
		PM.log_msg(PM.L("CHAT_LEARNING_DISABLED"), true, "error"); return
	end
	if PM_state.is_scanning then return end
	PM_state.is_scanning = true
	local c_count = 0
	local max_col = GetTotalCollectiblesByCategoryType(COLLECTIBLE_CATEGORY_TYPE_MEMENTO)
	PM.log_msg(PM.L("CHAT_AUTOSCAN_STARTING"), true, "settings", 90)
	PM.acct_saved.recentScans = {}

	for i = 1, max_col do
		local m_id = GetCollectibleIdFromType(COLLECTIBLE_CATEGORY_TYPE_MEMENTO, i)
		if m_id and IsCollectibleUnlocked(m_id) then
			local r_id = 0
			local c_data = ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(m_id)
			if c_data and c_data.GetReferenceId then r_id = c_data:GetReferenceId() end
			local s_dur = resolve_memento_duration_ms(m_id, r_id)
			local prev = PM.acct_saved.learned_data and PM.acct_saved.learned_data[m_id]
			if not prev or prev.dur ~= s_dur or prev.ref_id ~= r_id then
				local c_name = GetCollectibleName(m_id)
				PM.ensure_table(PM.acct_saved, "learned_data")
				PM.acct_saved.learned_data[m_id] = {
					id = m_id, ref_id = r_id, dur = s_dur, name = c_name
				}
				table.insert(PM.acct_saved.recentScans, m_id)
				c_count = c_count + 1
			end
		end
	end

	PM_state.is_scanning = false
	if c_count == 0 then
		PM.log_msg(PM.L("CHAT_ALL_ALREADY_LEARNED"), true, "settings", 90)
		PM.acct_saved.recentScans = nil
	else
		PM.update_learned_count()
		PM.log_msg(PM.L("CHAT_SUCCESSFULLY_LEARNED", c_count), false)
		PM_state.is_menu_built = false; zo_callLater(function() ReloadUI("ingame") end, 3000)
	end
end

function PM.run_loop(req_token)
	local state = PM_state
	if not PM.settings or PM.settings.is_paused or not PM.settings.active_id then return end
	if req_token ~= state.loop_token then return end

	local md = PM.get_data(PM.settings.active_id)
	if not md then PM.settings.active_id = nil; return end

	local is_busy, reason, w_delay = get_busy_state()
	if is_busy then
		local wait_ms = (w_delay > 0) and w_delay or ((PM.settings.delay_idle or 0) * 1000)
		if wait_ms < 100 then wait_ms = 100 end
		state.delay_reason = reason
		state.next_fire_time = GetGameTimeMilliseconds() + wait_ms
		zo_callLater(function() PM.run_loop(req_token) end, wait_ms); return
	end
	state.delay_reason = nil

	local cur_target = PM.settings.active_id
	if PM.settings.pending_sync_id then cur_target = PM.settings.pending_sync_id end

	local cd_rem, _ = GetCollectibleCooldownAndDuration(cur_target)
	if cd_rem and cd_rem > 500 then
		local wait_ms = cd_rem + ((PM.settings.delay_idle or 0) * 1000)
		if wait_ms < 1000 then wait_ms = 1000 end
		state.next_fire_time = GetGameTimeMilliseconds() + wait_ms
		zo_callLater(function() PM.run_loop(req_token) end, wait_ms); return
	end

	state.is_looping = true
	if PM.settings.pending_sync_id then
		 local sync_id = PM.settings.pending_sync_id
		 state.is_sync_firing = true; UseCollectible(sync_id)
		 PM.settings.pending_sync_id = nil
		 zo_callLater(function()
			 if req_token ~= state.loop_token then return end
			 local s_rem, s_dur = GetCollectibleCooldownAndDuration(sync_id)
			 local wait_ms = (s_rem > 0) and s_rem or s_dur
			 PM.log_msg(PM.L("CHAT_SYNC_FINISHED"), true, "sync", 80)
			 state.is_sync_firing = false; state.is_looping = false
			 state.next_fire_time = GetGameTimeMilliseconds() + wait_ms + 1000
			 zo_callLater(function() PM.run_loop(req_token) end, wait_ms + 1000)
		 end, 500); return
	end

	UseCollectible(PM.settings.active_id)
	state.session_loops = state.session_loops + 1
	if PM.acct_saved then
		PM.acct_saved.total_loops = (PM.acct_saved.total_loops or 0) + 1
		PM.ensure_table(PM.acct_saved, "memento_usage")
		local curr_use = PM.acct_saved.memento_usage[PM.settings.active_id] or 0
		PM.acct_saved.memento_usage[PM.settings.active_id] = curr_use + 1
		PM.trigger_priority_save()
	end

	local rand_zone = PM.settings.is_random_on_zone
	local rand_log = PM.settings.is_random_on_login
	if (rand_zone or rand_log) and PM.settings.enable_random_fav then
		state.next_random_precalc = PM.get_random_supported()
	end
	state.is_looping = false

	local is_unres = PM.settings.is_unrestricted
	if not PM_memento_data[PM.settings.active_id] and not is_unres then
		PM.settings.active_id = nil; return
	end

	local wait_ms = md.dur + 1000 + ((PM.settings.delay_idle or 0) * 1000)
	state.next_fire_time = GetGameTimeMilliseconds() + wait_ms
	zo_callLater(function() PM.run_loop(req_token) end, wait_ms)
end

function PM.start_loop(c_id, bypass_res)
	local md = PM.get_data(c_id)
	if not md then return end

	if not PM_memento_data[c_id] and not PM.settings.is_unrestricted and not bypass_res then
		PM.log_msg(
			"Activating " .. md.name .. " (Looping Disabled - Unrestricted Mode Required)",
			true, "activation", 70
		)
		UseCollectible(c_id); return
	end

	PM.settings.active_id = c_id; PM.settings.is_paused = false
	PM_state.loop_token = (PM_state.loop_token or 0) + 1

	local rand_zone = PM.settings.is_random_on_zone
	local rand_log = PM.settings.is_random_on_login
	if (rand_zone or rand_log) and PM.settings.enable_random_fav then
		PM_state.next_random_precalc = PM.get_random_supported()
	end

	local cur_token = PM_state.loop_token
	local is_busy, reason, w_delay = get_busy_state()
	if is_busy then
		local wait_ms = (w_delay > 0) and w_delay or ((PM.settings.delay_idle or 0) * 1000)
		if wait_ms < 100 then wait_ms = 100 end
		PM_state.delay_reason = reason
		PM_state.next_fire_time = GetGameTimeMilliseconds() + wait_ms
		zo_callLater(function() PM.run_loop(cur_token) end, wait_ms)
	else
		PM_state.delay_reason = nil
		PM_state.is_looping = true; UseCollectible(c_id); PM_state.is_looping = false
		PM_state.session_loops = PM_state.session_loops + 1
		if PM.acct_saved then
			PM.acct_saved.total_loops = (PM.acct_saved.total_loops or 0) + 1
			PM.ensure_table(PM.acct_saved, "memento_usage")
			local curr_use = PM.acct_saved.memento_usage[c_id] or 0
			PM.acct_saved.memento_usage[c_id] = curr_use + 1
			PM.trigger_priority_save()
		end
		local wait_ms = md.dur + 1000 + ((PM.settings.delay_idle or 0) * 1000)
		PM_state.next_fire_time = GetGameTimeMilliseconds() + wait_ms
		zo_callLater(function() PM.run_loop(cur_token) end, wait_ms)
	end
end

function PM.on_combat_event(eventCode, result, isError, abilityName, abilityGraphic,
							actionSlotType, sourceName, sourceType, targetName, targetType,
							hitValue, powerType, damageType, log, sourceUnitId, targetUnitId,
							abilityId, overflow)
	if not PM.settings or not PM.settings.active_id then return end
	if not PM.settings.busy_check_attacking then return end

	local is_attack = actionSlotType == ACTION_SLOT_TYPE_LIGHT_ATTACK
		or actionSlotType == ACTION_SLOT_TYPE_HEAVY_ATTACK
		or actionSlotType == ACTION_SLOT_TYPE_WEAPON_ATTACK
	if not is_attack then return end

	PM_state.loop_token = (PM_state.loop_token or 0) + 1
	local tkn = PM_state.loop_token
	local w_ms = (PM.settings.delay_attack or 2) * 1000

	PM_state.delay_reason = PM.L("LABEL_ATTACKING")
	PM_state.next_fire_time = GetGameTimeMilliseconds() + w_ms
	zo_callLater(function() PM.run_loop(tkn) end, w_ms)
end

function PM.on_ability_used(eventCode, actionSlotIndex)
	if not PM.settings or not PM.settings.active_id then return end
	if not PM.settings.busy_check_casting then return end
	if actionSlotIndex <= ACTION_BAR_FIRST_NORMAL_SLOT_INDEX then return end

	PM_state.loop_token = (PM_state.loop_token or 0) + 1
	local tkn = PM_state.loop_token
	local w_ms = (PM.settings.delay_cast or 3) * 1000

	local ability_id = GetSlotBoundId(actionSlotIndex)
	if ability_id and ability_id ~= 0 then
		local is_chan, c_time, chan_time = GetAbilityCastInfo(ability_id)
		if c_time and c_time > 0 then w_ms = c_time + 500 end
		if is_chan and chan_time and chan_time > 0 then w_ms = chan_time + 500 end
	end

	PM_state.delay_reason = PM.L("LABEL_CASTING")
	PM_state.next_fire_time = GetGameTimeMilliseconds() + w_ms
	zo_callLater(function() PM.run_loop(tkn) end, w_ms)
end

function PM.on_collectible_use_result(eventCode, result, isAttemptingActivation)
	if not PM.settings or not PM.settings.active_id then return end

	if isAttemptingActivation and result ~= 0 then
		PM_state.loop_token = (PM_state.loop_token or 0) + 1
		local tkn = PM_state.loop_token
		local w_ms = 2000

		PM_state.next_fire_time = GetGameTimeMilliseconds() + w_ms
		zo_callLater(function() PM.run_loop(tkn) end, w_ms)
	end
end

function PM.hook_collectible_activation()
	ZO_PreHook("UseCollectible", function(c_id)
		if not PM.settings then return end
		if PM_state.is_looping or PM_state.is_scanning then return end
		if GetCollectibleCategoryType(c_id) ~= COLLECTIBLE_CATEGORY_TYPE_MEMENTO then return end
		if PM_state.is_sync_firing then return end

		local is_col = SCENE_MANAGER:IsShowing("collectionsBook") or
			SCENE_MANAGER:IsShowing("gamepadCollectionsBook")

		if (c_id == 336 or c_id == 341) and PM.settings.active_id ~= c_id then
			if PM_state.is_bmu_teleport_animating then return end
			if PM.teleport_tracker:IsTeleporting() then return end
			if PM_state.delay_reason then return end

			local is_qs = SCENE_MANAGER:IsShowing("quickslot")
			if not is_col and not is_qs then return end
		end

		local md = PM.get_data(c_id)

		if not md and PM.settings.is_unrestricted and is_col and PM.settings.enable_learning then
			 local c_name = GetCollectibleName(c_id)
			 PM.ensure_table(PM.acct_saved, "learned_data")
			 local r_id = 0
			 local c_data = ZO_COLLECTIBLE_DATA_MANAGER:GetCollectibleDataById(c_id)
			 if c_data and c_data.GetReferenceId then r_id = c_data:GetReferenceId() end

			 zo_callLater(function()
				 local s_dur = resolve_memento_duration_ms(c_id, r_id)
				 PM.acct_saved.learned_data[c_id] = {
					 id = c_id, ref_id = r_id, dur = s_dur, name = c_name
				 }
				 PM.call_optional(PM.update_learned_count, "Loop module (update_learned_count)")
				 local out_msg = PM.L(
					 "CHAT_LEARNED_SAVED",
					 c_name, c_id, r_id, s_dur, PM_state.learned_count
				 )
				 PM.log_msg(out_msg, true, "settings", 70)
				 PM.call_optional(PM.update_menu_choices, "Menu module (update_menu_choices)")
			 end, 500)
		end

		if PM.settings.active_id == c_id then
			 PM.settings.active_id = nil; PM.settings.is_paused = false
			 PM_state.loop_token = (PM_state.loop_token or 0) + 1
			 PM.log_msg(PM.L("CHAT_AUTOLOOP_STOPPED"), true, "stop", 90)
			 PM_state.pending_id = 0; PM_state.next_fire_time = 0; return
		end

		if md then
			if not PM_memento_data[c_id] and not PM.settings.is_unrestricted then
				 PM.log_msg(
					 PM.L("CHAT_ACTIVATING_UNRESTRICTED_REQUIRED", md.name),
					 true, "activation", 70
				 ); return
			end
			local is_sw = (PM.settings.active_id ~= nil)
			PM.settings.active_id = c_id; PM.settings.is_paused = false
			PM_state.loop_token = (PM_state.loop_token or 0) + 1; PM_state.pending_id = c_id

			if is_sw then
				PM.log_msg(PM.L("CHAT_MEMENTO_SWITCHED", md.name), true, "activation", 90)
			else
				PM.log_msg(PM.L("CHAT_AUTOLOOP_STARTED", md.name), true, "activation", 90)
			end

			local tkn = PM_state.loop_token
			zo_callLater(function() PM.call_optional(PM.run_loop, "Loop module (run_loop)", tkn) end, 100)
		else
			if PM.settings.active_id then
				PM.settings.active_id = nil; PM_state.loop_token = (PM_state.loop_token or 0) + 1
				PM_state.pending_id = 0; PM_state.next_fire_time = 0
				PM.log_msg(PM.L("CHAT_AUTOLOOP_STOPPED"), true, "stop", 90)
			end
		end
	end)
end

function PM.hook_beam_me_up_animation()
	if type(BMU) ~= "table" or type(BMU.showTeleportAnimation) ~= "function" then return end
	ZO_PreHook(BMU, "showTeleportAnimation", function()
		PM_state.is_bmu_teleport_animating = true
		zo_callLater(function() PM_state.is_bmu_teleport_animating = false end, 100)
	end)
end

function PM.integrate_with_beam_me_up()
	if type(BMU) ~= "table" or type(BMU.savedVarsAcc) ~= "table" then return end
	BMU.savedVarsAcc.showTeleportAnimation = false
end

PM_modules.loop = true
