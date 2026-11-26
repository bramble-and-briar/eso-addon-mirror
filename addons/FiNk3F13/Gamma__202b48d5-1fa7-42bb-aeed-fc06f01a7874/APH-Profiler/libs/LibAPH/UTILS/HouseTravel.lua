--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

local JUMP_DELAY_MS = 1000
local JUMP_TIMEOUT_MS = 20000
local jump_count = 0

function LibAPH.GetCurrentPlace()
	return { zone = GetZoneId(GetUnitZoneIndex("player")), house = GetCurrentZoneHouseId and GetCurrentZoneHouseId() or 0 }
end

function LibAPH.IsInOwnedHouse()
	local house = GetCurrentZoneHouseId and GetCurrentZoneHouseId() or 0
	return house ~= 0 and type(IsOwnerOfCurrentHouse) == "function" and IsOwnerOfCurrentHouse() == true
end

function LibAPH.GetHouseDestinations()
	local list = {}
	local category = COLLECTIBLE_CATEGORY_TYPE_HOUSE
	for index = 1, GetTotalCollectiblesByCategoryType(category) do
		local collectible = GetCollectibleIdFromType(category, index)
		local house = GetCollectibleReferenceId(collectible)
		if house and house > 0 then
			local name = zo_strformat("<<1>>", GetCollectibleName(collectible))
			if IsCollectibleUnlocked(collectible) then
				list[#list + 1] = { house = house, outside = false, owned = true, zone = GetHouseZoneId(house), text = name .. ", inside" }
				list[#list + 1] = { house = house, outside = true, owned = true, zone = GetHouseFoundInZoneId(house), text = name .. ", outside" }
			else
				list[#list + 1] = { house = house, outside = false, owned = false, zone = GetHouseZoneId(house), text = name .. ", preview" }
			end
		end
	end
	return list
end

function LibAPH.PickHouseDestination(opts)
	opts = opts or {}
	local skip = opts.skipZones or {}
	local options = {}
	for _, dest in ipairs(LibAPH.GetHouseDestinations()) do
		if dest.zone and dest.zone > 0 and not skip[dest.zone] and dest.zone ~= opts.avoidZone and dest.house ~= opts.avoidHouse then
			options[#options + 1] = dest
		end
	end
	if #options == 0 then return nil end
	return options[math.random(#options)]
end

function LibAPH.RequestHouseJump(house, outside, opts)
	opts = opts or {}
	jump_count = jump_count + 1
	local namespace = "LibAPH_HouseJump" .. jump_count
	local handle = { live = true }
	local function Stop()
		handle.live = false
		EVENT_MANAGER:UnregisterForEvent(namespace, EVENT_JUMP_FAILED)
		EVENT_MANAGER:UnregisterForEvent(namespace, EVENT_PLAYER_DEACTIVATED)
	end
	local function Live()
		if not handle.live then return false end
		if opts.isLive and not opts.isLive() then
			Stop()
			return false
		end
		return true
	end
	local function Failed()
		if not Live() then return end
		Stop()
		if opts.onFailed then opts.onFailed() end
	end
	function handle:Cancel() Stop() end
	function handle:IsLive() return Live() end
	if not CanJumpToHouseFromCurrentLocation() then
		Failed()
		return handle
	end
	EVENT_MANAGER:RegisterForEvent(namespace, EVENT_JUMP_FAILED, Failed)
	EVENT_MANAGER:RegisterForEvent(namespace, EVENT_PLAYER_DEACTIVATED, Stop)
	zo_callLater(function() if Live() then RequestJumpToHouse(house, outside and true or false) end end, opts.delayMs or JUMP_DELAY_MS)
	zo_callLater(Failed, opts.timeoutMs or JUMP_TIMEOUT_MS)
	return handle
end
