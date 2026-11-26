--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

function LibAPH.IsPlayerCrafting()
	return GetCraftingInteractionType() ~= 0 or ZO_CraftingUtils_IsPerformingCraftProcess()
end

function LibAPH.IsPlayerInteracting()
	if SCENE_MANAGER:IsShowing("interact") then return true end
	return IsInteracting() or GetInteractionType() ~= INTERACTION_NONE or IsPlayerInteractingWithObject()
end

function LibAPH.IsPlayerInMenu()
	return not (SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui"))
end

function LibAPH.CheckBusyReason(checks)
	for _, c in ipairs(checks) do
		if c.enabled ~= false and c.check() then
			return true, c.reasonKey, c.delayMs
		end
	end
	return false, nil, 0
end

function LibAPH.CreateMovementTracker(opts)
	opts = opts or {}
	local throttleMs = opts.throttleMs or 100
	local thresholdSq = (opts.threshold or 0.5) ^ 2
	local last = { x = 0, z = 0, t = 0 }
	local is_moving = false

	local tracker = {}
	function tracker:Update()
		local tick_ms = GetGameTimeMilliseconds()
		if last.t ~= 0 and (tick_ms - last.t) <= throttleMs then return end

		local _, p_x, _, p_z = GetUnitRawWorldPosition("player")
		if last.t == 0 then
			last.x = p_x; last.z = p_z; last.t = tick_ms
			is_moving = false
			return
		end

		local dx = p_x - last.x
		local dz = p_z - last.z
		is_moving = (dx * dx + dz * dz) > thresholdSq
		last.x = p_x; last.z = p_z; last.t = tick_ms
	end
	function tracker:IsMoving()
		return is_moving
	end
	return tracker
end

local TELEPORT_FUNCS = {
	"FastTravelToNode",
	"TravelToKeep",
	"RequestJumpToHouse",
	"JumpToHouse",
	"JumpToFriend",
	"AcceptLFGReadyCheckNotification",
}
local last_travel_ms = 0
local teleport_hooks_installed = false
local function install_teleport_hooks()
	if teleport_hooks_installed then return end
	teleport_hooks_installed = true
	for _, fname in ipairs(TELEPORT_FUNCS) do
		ZO_PreHook(fname, function() last_travel_ms = GetGameTimeMilliseconds() end)
	end
end

function LibAPH.CreateTeleportTracker(opts)
	opts = opts or {}
	local staleMs = opts.staleMs or 3000
	install_teleport_hooks()

	local tracker = {}
	function tracker:IsTeleporting()
		return (GetGameTimeMilliseconds() - last_travel_ms) < staleMs
	end
	return tracker
end

function LibAPH.RunWhenPlayerActivated(namespace, fn)
	if IsPlayerActivated() then
		fn()
		return
	end
	EVENT_MANAGER:RegisterForEvent(namespace, EVENT_PLAYER_ACTIVATED, function()
		EVENT_MANAGER:UnregisterForEvent(namespace, EVENT_PLAYER_ACTIVATED)
		fn()
	end)
end

function LibAPH.GetClientStartTime()
	return GetTimeStamp() - math.floor(GetGameTimeMilliseconds() / 1000)
end

function LibAPH.IsSameClientSession(recordedStart, toleranceSec)
	if type(recordedStart) ~= "number" or recordedStart <= 0 then return false end
	return math.abs(LibAPH.GetClientStartTime() - recordedStart) <= (toleranceSec or 30)
end
