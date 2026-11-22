Teleport.Zones = {}

local info  = Teleport.info
local dbg   = Teleport.dbg
local color = Teleport.color
local C     = Teleport.COLORS

--------------------------------------------------------------------------------

local zones
local zoneNames
local zoneNamesById
local searchList = {}

function Teleport.Zones:initialize() 
	zones = {}
	zoneNames = {}
	zoneNamesById = {}
	for i = 1, GetNumMaps() do
		if GetCyrodiilMapIndex() ~= i and GetImperialCityMapIndex() ~= i then
			local _, mapType, mapContentType, zoneIndex = GetMapInfoByIndex(i)
			if mapContentType == MAP_CONTENT_NONE and (mapType == MAPTYPE_ZONE or mapType == MAPTYPE_SUBZONE) then
				local zoneName = GetZoneNameByIndex(zoneIndex)
				zones[zoneName] = GetZoneId(zoneIndex)
				zoneNamesById[zones[zoneName]] = zoneName
				table.insert(zoneNames, zoneName)
			end
		end
	end
	
	Teleport.Aliases:generateZoneAliases(zoneNames)

	-- Zone names and their short names in one alphabetical list, so a prefix
	-- always finds the alphabetically first match: "gr" is Grahtwood, not
	-- Blackreach: Greymoor Caverns; "re" is The Reach (alias "Reach"), then
	-- Reaper's March.
	searchList = {}
	for _, zoneName in ipairs(zoneNames) do
		table.insert(searchList, { key = string.lower(zoneName), zoneName = zoneName })
	end
	for shortName, zoneName in pairs(Teleport.Aliases:getZoneAliases()) do
		if zones[zoneName] then
			table.insert(searchList, { key = string.lower(shortName), zoneName = zoneName })
		end
	end
	table.sort(searchList, function(a, b)
		if a.key ~= b.key then return a.key < b.key end
		return a.zoneName < b.zoneName
	end)
end

function Teleport.Zones:findZoneByNamePrefix(prefix)
    prefix = string.lower(prefix)
    for _, entry in ipairs(searchList) do
        if Teleport.Helpers:startsWith(entry.key, prefix) then
            return entry.zoneName, zones[entry.zoneName]
        end
    end

    return nil
end

function Teleport.Zones:findZoneById(zoneId)
    local zoneName = zoneId and zoneNamesById[zoneId]
    if zoneName then
        return zoneName, zoneId
    end

    return nil
end

-- zoneId followed by its parents (delve -> zone, etc.)
function Teleport.Zones:getZoneChain(zoneId)
    local chain, seen = {}, {}
    while zoneId and zoneId ~= 0 and not seen[zoneId] do
        seen[zoneId] = true
        table.insert(chain, zoneId)
        zoneId = GetParentZoneId(zoneId)
    end
    return chain
end

-- first zone in the chain that you can /tp to, nil for Cyrodiil, IC, etc.
function Teleport.Zones:normalizeZoneId(zoneId)
    for _, id in ipairs(self:getZoneChain(zoneId)) do
        if zoneNamesById[id] then
            return id
        end
    end
    return nil
end

function Teleport.Zones:getPlayerZoneChain()
    local zoneIndex = GetUnitZoneIndex("player")
    if not zoneIndex then return {} end
    return self:getZoneChain(GetZoneId(zoneIndex))
end

function Teleport.Zones:getPlayerZoneId()
    local zoneIndex = GetUnitZoneIndex("player")
    return zoneIndex and self:normalizeZoneId(GetZoneId(zoneIndex))
end

function Teleport.Zones:teleportToZone(prefix)
    local zoneName, zoneId = Teleport.Zones:findZoneByNamePrefix(prefix)
    if not zoneName then
        dbg("Failed to teleport to " .. color(prefix, C.NOT_FOUND) .. ": No such zone found.")
        return false
    end
        
    local player = Teleport.Players:findPlayerByZoneId(zoneId)
    if not player then
        info("Failed to teleport to " .. color(zoneName, C.ZONE) .. ": No party members/friends/guildies in that zone.")
        return true
    end
    
    return Teleport.Players:teleportToPlayer(player)
end

