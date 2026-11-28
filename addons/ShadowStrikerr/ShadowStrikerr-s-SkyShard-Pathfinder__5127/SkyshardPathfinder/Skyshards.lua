local addon = SkyshardPathfinder

function addon.VisitZoneShards(zone, visit)
    if not zone or zone <= 0 then return end
    local parent = GetParentZoneId(zone)
    if parent and parent > 0 then zone = parent end

    for index = 1, GetNumSkyshardsInZone(zone) do
        local id = GetZoneSkyshardId(zone, index)
        if id and id > 0 then
            local status = GetSkyshardDiscoveryStatus(id)
            if status == SKYSHARD_DISCOVERY_STATUS_ACQUIRED then
                visit(id, true, index, zone)
            elseif status == SKYSHARD_DISCOVERY_STATUS_UNDISCOVERED
                or status == SKYSHARD_DISCOVERY_STATUS_DISCOVERED then
                visit(id, false, index, zone)
            end
        end
    end
end

function addon.GetShardMapPosition(id)
    local x, y, onMap = GetNormalizedPositionForSkyshardId(id)
    if onMap and x and y and x > 0 and x < 1 and y > 0 and y < 1 then
        return x, y
    end
end

-- ESO links interior SkyShards to their entrance POIs on the parent map.
function addon.GetShardEntrances(zoneIndex)
    local entrances = {}
    if not GetPOIMapInfo or (GetMapContentType and GetMapContentType() == MAP_CONTENT_DUNGEON) then
        return entrances
    end
    for poi = 1, GetNumPOIs(zoneIndex) do
        local id = GetPOISkyshardId(zoneIndex, poi)
        if id and id > 0 then
            local x, y, _, _, shown = GetPOIMapInfo(zoneIndex, poi)
            if shown and x and y and x > 0 and x < 1 and y > 0 and y < 1 then
                entrances[id] = { x = x, y = y, name = GetPOIInfo and GetPOIInfo(zoneIndex, poi) }
            end
        end
    end
    return entrances
end

local function getMapProjection(player)
    if not GetRawNormalizedWorldPosition then return end
    local project = GetRawNormalizedWorldPosition
    local zone, x, y, z = player.zone, player.x, player.y, player.z
    local u, v = project(zone, x, y, z)
    local eastU, eastV = project(zone, x + 1000, y, z)
    local southU, southV = project(zone, x, y, z + 1000)
    if not (u and v and eastU and eastV and southU and southV and u > 0 and u < 1 and v > 0 and v < 1) then return end
    if GetMapPlayerPosition then
        local mapU, mapV = GetMapPlayerPosition("player")
        if not mapU or not mapV or math.abs(mapU - u) > .005 or math.abs(mapV - v) > .005 then return end
    end
    local a, b, c, d = eastU - u, southU - u, eastV - v, southV - v
    local determinant = a * d - b * c
    if math.abs(determinant) < 1e-12 then return end
    return function(mapX, mapY)
        local du, dv = mapX - u, mapY - v
        return x + (d * du - b * dv) * 1000 / determinant,
            z + (a * dv - c * du) * 1000 / determinant
    end
end

function addon.GetNavigationShards(zone, player, includeCollected, selectedId)
    local shards = {}
    local worldZone, worldX, worldY, worldZ = GetUnitWorldPosition("player")
    local project = getMapProjection(player)
    local entrances = addon.GetShardEntrances(GetCurrentMapZoneIndex())
    local mapName = GetMapName and GetMapName()
    addon.VisitZoneShards(zone, function(id, collected)
        if collected and not includeCollected and id ~= selectedId then return end
        local entrance = entrances[id]
        local mapX, mapY
        if entrance then
            mapX, mapY = entrance.x, entrance.y
        else
            mapX, mapY = addon.GetShardMapPosition(id)
        end
        if not mapX then return end
        local x, z
        local shardZone, shardX, shardY, shardZ = GetWorldPositionForSkyshardId(id)
        local hasWorldPosition = shardZone == worldZone and worldZone and worldZone > 0
            and shardX and shardZ and (shardX ~= 0 or shardZ ~= 0)
        if project then
            x, z = project(mapX, mapY)
        elseif not entrance and hasWorldPosition and worldX and worldZ then
            x = player.x + shardX - worldX
            z = player.z + shardZ - worldZ
        end
        if x then
            local hint = GetSkyshardHint(id)
            hint = hint and hint ~= "" and hint:gsub("[\r\n]+", " ") or ("SkyShard " .. id)
            local y = not entrance and hasWorldPosition and worldY and shardY and player.y + shardY - worldY or nil
            shards[#shards + 1] = { id = id, x = x, y = y, z = z, mapX = mapX, mapY = mapY, alreadyCollected = collected,
                hint = entrance and ("Entrance to " .. (entrance.name or "delve or public dungeon"))
                    or hint,
                detail = entrance and hint or mapName }

        end
    end)
    return shards
end
