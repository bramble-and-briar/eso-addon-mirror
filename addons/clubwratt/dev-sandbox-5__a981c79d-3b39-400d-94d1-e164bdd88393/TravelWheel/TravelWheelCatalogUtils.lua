-- TravelWheelCatalogUtils.lua: Pure helpers for the lists the game offers
-- (zones, wayshrines, houses).

local TravelWheelCatalogUtils = {}

---The game's names carry a grammar suffix ("Vivec City Wayshrine^N,at").
---@param rawName string
---@return string
function TravelWheelCatalogUtils.CleanName(rawName)
    return (string.gsub(rawName or "", "%^.*$", ""))
end

---@generic T: { name: string }
---@param list T[]
---@return T[] list The same table, sorted by name
function TravelWheelCatalogUtils.SortByName(list)
    table.sort(list, function(a, b)
        return a.name < b.name
    end)
    return list
end

---The zone the map shows for where a player stands: a city or delve reports
---its own zone id with the surrounding zone as its parent.
---@param zoneId integer
---@param parentZoneId integer
---@return integer
function TravelWheelCatalogUtils.OverlandZoneId(zoneId, parentZoneId)
    if parentZoneId and parentZoneId ~= 0 then
        return parentZoneId
    end
    return zoneId
end

TravelWheel.CatalogUtils = TravelWheelCatalogUtils
