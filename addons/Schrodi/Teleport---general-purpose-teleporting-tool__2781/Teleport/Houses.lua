Teleport.Houses = {}

local info  = Teleport.info
local dbg   = Teleport.dbg
local color = Teleport.color
local C     = Teleport.COLORS

function Teleport.Houses:teleportToHouse(houseNamePrefix)
    local outside = Teleport.Helpers:startsWithCaseInsensitive(houseNamePrefix, "outside ")
    if outside then
        houseNamePrefix = string.sub(houseNamePrefix, 9)
    end
    local nodeName, nodeIndex = Teleport.Nodes:findHouseNode(houseNamePrefix)
    if not nodeName then
        dbg("Failed to teleport to " .. houseNamePrefix .. ": No such house.")
        return false
    end

    local houseId = GetFastTravelNodeHouseId(nodeIndex)
    local collectibleId = GetCollectibleIdForHouse(houseId)
    local _, _, _, _, unlocked, _, _, _, _, _ = GetCollectibleInfo(collectibleId)

    if not unlocked then
        if outside then
            info("Cannot teleport outside house you don't own")
            return true
        end
        
        info("Previewing house: " .. color(nodeName, C.HOUSE))
        RequestJumpToHouse(houseId, false)
        return true
    end
    
    if not outside then
        info("Teleporting to " .. color(nodeName, C.HOUSE))
        RequestJumpToHouse(houseId, false)
    else
        info("Teleporting outside of " .. color(nodeName, C.HOUSE)) -- 'remove "outside " prefix from house's name'
        RequestJumpToHouse(houseId, true)
    end
    return true
end

function Teleport.Houses:teleportToPlayersHouse(playerNamePrefix, houseNamePrefix)
    local player
    local exact = false
    if Teleport.Helpers:startsWith(playerNamePrefix, '@@') then
        -- assume a correct exact name if @@ was used
        player = { }
        player.displayName = string.sub(playerNamePrefix, 2)
        exact = true
    else
        player = Teleport.Players:findPlayerByNamePrefix(playerNamePrefix)
        if not player then
            info("Failed to teleport to " .. color(playerNamePrefix, C.NOT_FOUND) .. "'s " .. color(houseNamePrefix, C.HOUSE) .. ": Player not found.")
            return true
        end
    end

    if Teleport.Helpers:startsWithCaseInsensitive(houseNamePrefix, "outside ") then
        info("You cannot teleport outside of other people's houses")
        return true
    end

    if houseNamePrefix == 'primary' or houseNamePrefix == 'main' then
        info("Teleporting to " .. color(ZO_LinkHandler_CreateDisplayNameLink(player.displayName), C.PLAYER) .. "'s primary residence")
        JumpToHouse(player.displayName)
        return true
    end

    local nodeName, nodeIndex = Teleport.Nodes:findHouseNode(houseNamePrefix)
    if not nodeName then
        info("Failed to teleport to " .. color(ZO_LinkHandler_CreateDisplayNameLink(player.displayName), C.PLAYER) .. "'s " .. color(houseNamePrefix, C.NOT_FOUND) .. ": No such house.")
        return false
    end

    info("Teleporting to " ..  color(ZO_LinkHandler_CreateDisplayNameLink(player.displayName), C.PLAYER) .. "'s " .. color(nodeName, C.HOUSE))
    JumpToSpecificHouse(player.displayName, GetFastTravelNodeHouseId(nodeIndex))
    return true
end
