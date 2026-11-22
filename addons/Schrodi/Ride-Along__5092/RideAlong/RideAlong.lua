-- Ride Along (formerly Mounty Python)
--
-- One keybind to hop on a group member's multi-rider mount, without targeting them and
-- without the interaction wheel.
--
-- It can't fall back to summoning your own mount when nobody has a free seat: the game's
-- mount keybind calls ToggleMount(), which is a private function, so addon code can't call
-- it (or wrap it) at all.

local ADDON_NAME = "RideAlong"
local MAX_DISTANCE_M = 5

local function Msg(text)
    CHAT_ROUTER:AddSystemMessage("|c88CCFFRide Along:|r " .. text)
end

-- Distance in meters between the player and a unit in the same zone, or nil.
local function DistanceTo(unitTag)
    local zoneA, x1, y1, z1 = GetUnitWorldPosition("player")
    local zoneB, x2, y2, z2 = GetUnitWorldPosition(unitTag)
    if zoneA ~= zoneB then return nil end
    return zo_distance3D(x1, y1, z1, x2, y2, z2) / 100
end

local function HasFreeSeat(displayName)
    local mountedState, isRidingGroupMount, hasFreePassengerSlot = GetTargetMountedStateInfo(displayName)
    return mountedState == MOUNTED_STATE_MOUNT_RIDER and isRidingGroupMount and hasFreePassengerSlot
end

-- Group member with a free seat: the one under the reticle if there is one, otherwise the
-- nearest one within MAX_DISTANCE_M.
local function FindRide()
    if IsUnitPlayer("reticleover") and IsUnitGrouped("reticleover") then
        local displayName = GetUnitDisplayName("reticleover")
        if HasFreeSeat(displayName) then
            return displayName, "reticleover"
        end
    end

    local myName = GetDisplayName()
    local best, bestTag, bestDistance
    for i = 1, GetGroupSize() do
        local unitTag = GetGroupUnitTagByIndex(i)
        local displayName = unitTag and GetUnitDisplayName(unitTag)
        if displayName and displayName ~= myName and IsUnitOnline(unitTag) and HasFreeSeat(displayName) then
            local distance = DistanceTo(unitTag)
            if distance and distance <= MAX_DISTANCE_M and (not bestDistance or distance < bestDistance) then
                best, bestTag, bestDistance = displayName, unitTag, distance
            end
        end
    end
    return best, bestTag
end

local function GetShownName(unitTag, displayName)
    if ZO_ShouldPreferUserId() then
        return displayName
    end
    return zo_strformat("<<1>>", GetUnitName(unitTag))
end

function RideAlong_Mount()
    if IsGroupMountPassenger() then
        Msg("You're already riding along.")
        return
    end
    if IsUnitDeadOrReincarnating("player") or IsUnitInCombat("player") or HasPendingCompanion() then
        Msg("Can't hop on right now.")
        return
    end
    if not IsUnitGrouped("player") then
        Msg("You need to be in a group.")
        return
    end

    local displayName, unitTag = FindRide()
    if not displayName then
        Msg(string.format("No group member with a free seat within %d m.", MAX_DISTANCE_M))
        return
    end
    Msg("Hopping on behind " .. GetShownName(unitTag, displayName) .. ".")
    UseMountAsPassenger(displayName)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, function(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- The action keeps Mounty Python's name, so an existing keybind carries over.
    ZO_CreateStringId("SI_BINDING_NAME_RIDE_ALONG_HOTKEY_MOUNT", "Ride with a group member")
    SLASH_COMMANDS["/ride"] = RideAlong_Mount
end)
