--[[
    Copyright © 2025-2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

PMCore = PMCore or {}
local PM = PMCore
local PM_state = PM.state

local SYNC_PROTOCOL_ID = 480
local SYNC_KINDS = { "play", "stop" }
local sync_protocol
local lgb_registered = false
local on_sync_data

local function lgb_available()
	local lgb = LibGroupBroadcast
	return type(lgb) == "table" and type(lgb.RegisterHandler) == "function"
end

local function register_lgb()
	if lgb_registered then return sync_protocol ~= nil end
	lgb_registered = true
	if not lgb_available() then return false end
	local lgb = LibGroupBroadcast
	local handler = lgb:RegisterHandler(PM.name, "PermMementoSync")
	if not handler then return false end
	handler:SetDisplayName("Permanent Memento")
	handler:SetDescription(PM.L("SYNC_LGB_DESCRIPTION"))
	local protocol = handler:DeclareProtocol(SYNC_PROTOCOL_ID, "PermMementoSync")
	protocol:AddField(lgb.CreateEnumField("kind", SYNC_KINDS))
	protocol:AddField(lgb.CreateNumericField("collectibleId", { minValue = 0, maxValue = 65535 }))
	protocol:OnData(function(unitTag, data)
		if on_sync_data then on_sync_data(unitTag, data) end
	end)
	protocol:Finalize({ replaceQueuedMessages = true })
	sync_protocol = protocol
	return true
end
PM.register_sync_broadcast = register_lgb

local function sync_blocker()
	if not sync_protocol then return "CHAT_SYNC_NEEDS_LGB" end
	if not sync_protocol:IsEnabled() then return "CHAT_SYNC_LGB_OFF" end
	if not IsUnitGrouped("player") then return "CHAT_SYNC_NOT_GROUPED" end
	return nil
end
PM.sync_blocker = sync_blocker

local function send_sync(kind, c_id)
	local blocked = sync_blocker()
	if blocked then
		PM.log_msg(PM.L(blocked), true, "error", 90)
		return false
	end
	if not sync_protocol:Send({ kind = kind, collectibleId = c_id or 0 }) then
		PM.log_msg(PM.L("CHAT_SYNC_SEND_FAILED"), true, "error", 90)
		return false
	end
	PM.log_msg(PM.L(kind == "stop" and "CHAT_SENT_GROUP_STOP" or "CHAT_SENT_GROUP_SYNC"), true, "sync", 90)
	return true
end
PM.send_sync = send_sync

local function sync_listening()
	return PM.settings and PM.settings.sync_module.is_enabled and not PM_state.sync_auto_suspended
		and PM_state.sync_running == true
end

function PM.sync_engine.initialize()
	register_lgb()
	SLASH_COMMANDS["/pmsync"] = function(arg_str)
		if not PM.settings.sync_module.is_enabled then
			PM.log_msg(PM.L("CHAT_GROUP_SYNC_DISABLED"), true, "error"); return
		end
		if not arg_str or string.len(arg_str) < 1 then
			PM.log_msg(PM.L("CHAT_SYNC_USAGE"), true, "error", 70)
			return
		end
		local c_arg = string.lower(arg_str)

		if c_arg == "stop" then
			send_sync("stop")
			if PM.settings then
				PM.settings.active_id = nil; PM_state.loop_token = (PM_state.loop_token or 0) + 1
			end
			PM_state.next_fire_time = 0; return
		elseif c_arg == "random" then
			local r_id = PM.call_optional(PM.get_random_any, "Loop module (get_random_any)")
			if r_id then
				send_sync("play", r_id)
				PM.log_msg(PM.L("CHAT_SENT_RANDOM_SYNC"), true, "sync", 90); return
			end
			if PM._modules.loop then PM.log_msg(PM.L("CHAT_NO_RANDOM_AVAILABLE"), true, "error", 90) end
			return
		end

		local max_cat = GetTotalCollectiblesByCategoryType(COLLECTIBLE_CATEGORY_TYPE_MEMENTO)
		for i = 1, max_cat do
			local f_id = GetCollectibleIdFromType(COLLECTIBLE_CATEGORY_TYPE_MEMENTO, i)
			if f_id and IsCollectibleUnlocked(f_id) then
				if string.find(string.lower(GetCollectibleName(f_id)), c_arg, 1, true) then
					send_sync("play", f_id)
					return
				end
			end
		end
		PM.log_msg(PM.L("CHAT_MEMENTO_NOT_FOUND"), true, "error", 90)
	end
	SLASH_COMMANDS["/permmementosync"] = SLASH_COMMANDS["/pmsync"]

	local function attempt_col(c_id, own)
		if not IsCollectibleUsable(c_id) then return end
		if not PM.settings or not PM.settings.sync_module.is_enabled then return end
		if IsUnitInCombat("player") and PM.settings.sync_module.ignore_in_combat then
			return
		end

		if PM.settings.active_id and not own then
			PM.log_msg(PM.L("CHAT_SYNC_SKIPPED_ACTIVE"), true, "sync", 70)
		elseif PM.settings.active_id then
			PM.log_msg(PM.L("CHAT_SYNC_RECEIVED_QUEUING"), true, "sync", 70); PM.settings.pending_sync_id = c_id
		else
			local c_rem, _ = GetCollectibleCooldownAndDuration(c_id)
			if c_rem and c_rem > 0 then
				PM.log_msg(PM.L("CHAT_SYNC_RECEIVED_COOLDOWN"), true, "sync", 70)
				zo_callLater(function() attempt_col(c_id, own) end, c_rem + 1000)
			else
				PM.log_msg(PM.L("CHAT_SYNC_RECEIVED_PLAYING"), true, "sync", 80)
				PM_state.is_sync_firing = true; UseCollectible(c_id)
				zo_callLater(function() PM_state.is_sync_firing = false end, 1000)
			end
		end
	end

	local function receive_stop(cl_name)
		if not PM.settings then return end
		PM.settings.active_id = nil; PM_state.loop_token = (PM_state.loop_token or 0) + 1
		PM.settings.pending_sync_id = nil; PM_state.next_fire_time = 0
		PM.log_msg(PM.L("CHAT_GROUP_STOP_RECEIVED", cl_name), true, "stop", 90)
	end

	local function receive_play(f_id)
		if not f_id or f_id == 0 or not IsCollectibleUnlocked(f_id) or not PM.settings then return end
		local s_delay = PM.settings.sync_module.delay or 0
		if PM.settings.sync_module.is_random then s_delay = math.random(0, s_delay) end
		if s_delay == 0 then
			attempt_col(f_id)
		else
			zo_callLater(function() attempt_col(f_id) end, s_delay * 1000)
		end
	end

	on_sync_data = function(unitTag, data)
		if type(data) ~= "table" then return end
		if AreUnitsEqual(unitTag, "player") then
			local own_id = tonumber(data.collectibleId)
			if data.kind == "play" and PM_state.sync_running and own_id and own_id ~= 0 and IsCollectibleUnlocked(own_id) then
				attempt_col(own_id, true)
			end
			return
		end
		if not sync_listening() then return end
		if data.kind == "stop" then
			receive_stop(zo_strformat("<<1>>", GetUnitName(unitTag)))
		elseif data.kind == "play" then
			receive_play(tonumber(data.collectibleId))
		end
	end

	PM_state.sync_running = true
end

LibAPH.RegisterModuleLifecycle("sync", {
	onUnload = function()
		PM_state.sync_running = false
		on_sync_data = nil
		SLASH_COMMANDS["/pmsync"] = nil
		SLASH_COMMANDS["/permmementosync"] = nil
	end,
	onLoad = function()
		local init_fn = (PM.sync_engine and PM.sync_engine.initialize) or LibAPH.GetStashedFunc("sync", "sync_engine.initialize")
		if init_fn then
			PM.sync_engine = PM.sync_engine or {}
			PM.sync_engine.initialize = init_fn
			init_fn()
		end
	end,
})

PM._modules.sync = true
