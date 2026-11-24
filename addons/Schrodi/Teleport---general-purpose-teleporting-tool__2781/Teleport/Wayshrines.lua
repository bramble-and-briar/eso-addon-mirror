local Teleport = Teleport
Teleport.Wayshrines = {}

local info  = Teleport.info
local dbg   = Teleport.dbg
local color = Teleport.color
local C     = Teleport.COLORS

--------------------------------------------------------------------------------    

function Teleport.Wayshrines:teleportToWayshrine(namePrefix)
    local nodeName, nodeIndex = Teleport.Nodes:findWayshrineNode(namePrefix)
    if not nodeName then
        dbg("Failed to teleport to " .. namePrefix .. ": No such wayshrine found.")
        return false
    end
    
    if not Teleport.Nodes:isKnown(nodeIndex) then
        info("Failed to teleport to " .. color(nodeName, C.NOT_UNLOCKED) .. ": Not unlocked.")
        return true
    end

    info("Teleporting to " .. color(nodeName, C.WAYSHRINE) .. Teleport.Nodes:getRecallCostString(nodeIndex))
    FastTravelToNode(nodeIndex)
    return true
end

