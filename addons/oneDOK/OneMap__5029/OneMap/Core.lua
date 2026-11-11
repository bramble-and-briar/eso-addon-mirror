OneMap = { name = "OneMap", version = "26.11.2" }
local A = OneMap

A.defaults = {
    enlargeMap = true,
    hideCompletion = false,
    playerPulse = true,
    smoothScroll = true,
    skipPaidConfirmation = false,
    compactHouses = true,
    showDungeons = true,
    showTrials = true,
    questZone = true,
    antiquityZone = true,
    rightClickTravel = true,
    freeTravel = true,
    useGroup = true,
    useFriends = true,
    useGuilds = true,
    travelTooltips = true,
}

function A:Text(key)
    return self.strings[key] or key
end

function A:Alert(key)
    ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, "OneMap: " .. self:Text(key))
end

function A:IsKeyboardMap()
    return not IsInGamepadPreferredMode() and SCENE_MANAGER:IsShowing("worldMap")
end

function A:CanUseMap()
    return self:IsKeyboardMap() and WORLD_MAP_MANAGER:IsMapChangingAllowed()
        and not WORLD_MAP_MANAGER:IsInMode(MAP_MODE_DIG_SITES)
end

function A:ShowZone(zoneId)
    local mapIndex = zoneId and GetMapIndexByZoneId(zoneId)
    if not mapIndex or not self:CanUseMap() then return false end
    WORLD_MAP_MANAGER:SetMapByIndex(mapIndex)
    return true
end

-- No scene callbacks are fired while inspecting coordinates. Always restore the
-- exact map and floor before returning, including when an API call raises.
function A:OnZoneMap(zoneId, callback)
    local mapIndex = zoneId and GetMapIndexByZoneId(zoneId)
    if not mapIndex then return nil end
    local mapId, floor = GetCurrentMapId(), GetMapFloorInfo()
    local ok, result = pcall(function()
        if SetMapToMapListIndex(mapIndex) == SET_MAP_RESULT_FAILED then return nil end
        return callback()
    end)
    SetMapToMapId(mapId)
    if floor and floor > 0 then SetMapFloor(floor) end
    if not ok then error(result) end
    return result
end
