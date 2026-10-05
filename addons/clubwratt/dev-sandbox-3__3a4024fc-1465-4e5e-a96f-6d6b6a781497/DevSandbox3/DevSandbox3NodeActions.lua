-- DevSandbox3NodeActions.lua: Detect war torte recipe nodes and persist them

local NodeActions = {}

local NodeUtils = DevSandbox3.NodeUtils
local LogUtils = DevSandbox3.LogUtils

---Convert a zone-normalized position to global (Tamriel) coords without disturbing the open map.
---Passing nil for nx/ny uses the player's own map position.
---@param nx number|nil
---@param ny number|nil
---@return number|nil gx
---@return number|nil gy
---@return integer zoneId
local function ToGlobalPosition(nx, ny)
    local gps = LibGPS3
    gps:PushCurrentMap()
    SetMapToPlayerLocation()
    if GetMapType() == MAPTYPE_SUBZONE then
        MapZoomOut()
    end
    local lx, ly = nx, ny
    if not lx or not ly then
        lx, ly = GetMapPlayerPosition("player")
    end
    local gx, gy = gps:LocalToGlobal(lx, ly)
    local zoneId = GetZoneId(GetCurrentMapZoneIndex())
    gps:PopCurrentMap()
    return gx, gy, zoneId
end

---@param gx1 number
---@param gy1 number
---@param gx2 number
---@param gy2 number
---@return number meters
local function GlobalDistanceMeters(gx1, gy1, gx2, gy2)
    return LibGPS3:GetGlobalDistanceInMeters(gx1, gy1, gx2, gy2)
end

---Record (or refresh) a node at a zone-normalized position (nil = player's position).
---@param zoneIdHint integer|nil
---@param nx number|nil
---@param ny number|nil
---@param name string
---@param looted boolean
---@param candidate boolean|nil true when the name was unrecognized (not a confirmed war torte)
---@return DevSandbox3Node|nil node
---@return boolean isNew
function NodeActions.RecordAtNormalized(zoneIdHint, nx, ny, name, looted, candidate)
    local state = DevSandbox3.state
    local gx, gy, zoneId = ToGlobalPosition(nx, ny)
    zoneId = zoneIdHint or zoneId
    if not gx or not gy then
        LogUtils.Debug("LibGPS has no measurement for this map yet; node not recorded")
        return nil, false
    end

    local now = GetTimeStamp()
    local nodes = state.savedVars.nodes
    local index = NodeUtils.FindNearbyNodeIndex(nodes, gx, gy, GlobalDistanceMeters)
    local node
    local isNew = false
    if index then
        node = nodes[index]
        node.lastSeen = now
        node.seenCount = node.seenCount + 1
        node.looted = node.looted or looted
        if node.name == "" then node.name = name end
        if not candidate then node.candidate = false end
    else
        node = NodeUtils.CreateNode(gx, gy, name, zoneId, now)
        node.looted = looted
        node.candidate = candidate == true
        table.insert(nodes, node)
        isNew = true
    end
    -- World metres for the 3D / compass markers (only when recorded at the player's own position).
    if not nx and not node.wx then
        local worldZone, wx, wy, wz = GetUnitWorldPosition("player")
        if worldZone == zoneId and wx then
            node.wx, node.wy, node.wz = wx / 100, wy / 100, wz / 100
        end
    end
    state.lastRecordTime = now

    DevSandbox3.PinActions.RefreshPins()
    return node, isNew
end

---Record (or refresh) a node at the player's current position.
---@param name string
---@param looted boolean
---@return DevSandbox3Node|nil node
---@return boolean isNew
function NodeActions.RecordAtPlayer(name, looted)
    return NodeActions.RecordAtNormalized(nil, nil, nil, name, looted)
end

---Reticle handler: fires when the player looks at a new interactable.
function NodeActions.OnReticleTargetChanged()
    local state = DevSandbox3.state
    local action, interactableName = GetGameCameraInteractableActionInfo()
    if not interactableName or interactableName == "" then
        return
    end
    if interactableName == state.lastReticleName then
        return
    end
    state.lastReticleName = interactableName
    LogUtils.Debug("reticle: [%s] %s", tostring(action), interactableName)

    if not NodeUtils.IsWarTorteName(interactableName) then
        return
    end

    local node, isNew = NodeActions.RecordAtPlayer(interactableName, false)
    if node then
        LogUtils.Log("%s war torte recipe spawn: %s (%d total)", isNew and "New" or "Known", interactableName, #state.savedVars.nodes)
        DevSandbox3.AlertActions.Show(interactableName, nil, false)
    end
end

---Loot handler: fires when the recipe actually lands in the bag.
function NodeActions.OnLootReceived(_eventId, _receivedBy, itemName, _quantity, _soundCategory, lootType, isSelf, _isPickpocket, _questItemIcon, itemId)
    if not isSelf or lootType ~= LOOT_TYPE_ITEM then
        return
    end
    if not NodeUtils.IsWarTorteLoot(itemId, itemName) then
        return
    end
    local plainName = zo_strformat("<<1>>", itemName)
    local node, isNew = NodeActions.RecordAtPlayer(plainName, true)
    if node then
        LogUtils.Log("Looted %s - %s spawn saved (%d total)", plainName, isNew and "new" or "known", #DevSandbox3.state.savedVars.nodes)
    end
    -- Which expected material slot was the book sitting on? This is how we learn what node types it replaces.
    local SlotActions = DevSandbox3.SlotActions
    if SlotActions and SlotActions.grid then
        local index, dist, typeName = SlotActions.NearestSlotToPlayer(DevSandbox3.SlotUtils.LOOT_ATTRIBUTION_METERS)
        local looted = DevSandbox3.state.savedVars.lootedSlots
        if index then
            looted[#looted + 1] = { index = index, typeName = typeName, dist = math.floor(dist + 0.5), at = GetTimeStamp() }
            LogUtils.Log("Book was on an expected %s slot (%dm away). /ds3 looted shows all attributions", typeName, math.floor(dist + 0.5))
            if DevSandbox3.state.savedVars.emptySlots[index] then
                DevSandbox3.state.savedVars.emptySlots[index] = nil
            end
        else
            looted[#looted + 1] = { index = nil, typeName = "none", dist = -1, at = GetTimeStamp() }
            LogUtils.Log("Book was NOT near any expected material slot (none within %dm) - the data may be missing this spawn", DevSandbox3.SlotUtils.LOOT_ATTRIBUTION_METERS)
        end
    end
end

function NodeActions.RegisterEvents()
    EVENT_MANAGER:RegisterForEvent(DevSandbox3.name .. "_Reticle", EVENT_RETICLE_TARGET_CHANGED, NodeActions.OnReticleTargetChanged)
    EVENT_MANAGER:RegisterForEvent(DevSandbox3.name .. "_Loot", EVENT_LOOT_RECEIVED, NodeActions.OnLootReceived)
end

---Promote candidate nodes whose name now matches a war torte pattern.
---@return integer promoted
function NodeActions.PromoteMatchingCandidates()
    local promoted = 0
    for _, node in ipairs(DevSandbox3.state.savedVars.nodes) do
        if node.candidate and NodeUtils.IsWarTorteName(node.name) then
            node.candidate = false
            promoted = promoted + 1
        end
    end
    if promoted > 0 then DevSandbox3.PinActions.RefreshPins() end
    return promoted
end

---Drop candidate nodes whose name is now ignored.
---@param loweredName string
---@return integer removed
function NodeActions.RemoveCandidatesNamed(loweredName)
    local nodes = DevSandbox3.state.savedVars.nodes
    local removed = 0
    for i = #nodes, 1, -1 do
        if nodes[i].candidate and string.lower(NodeUtils.BaseName(nodes[i].name)) == loweredName then
            table.remove(nodes, i)
            removed = removed + 1
        end
    end
    if removed > 0 then DevSandbox3.PinActions.RefreshPins() end
    return removed
end

---Remove every saved node.
function NodeActions.ClearAll()
    local nodes = DevSandbox3.state.savedVars.nodes
    for i = #nodes, 1, -1 do
        nodes[i] = nil
    end
    DevSandbox3.PinActions.RefreshPins()
end

DevSandbox3.NodeActions = NodeActions
