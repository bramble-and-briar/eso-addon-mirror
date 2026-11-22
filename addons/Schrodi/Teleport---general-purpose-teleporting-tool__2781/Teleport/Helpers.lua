Teleport.Helpers = {}

function Teleport.Helpers:startsWith(str, start)
    if not str or not start then return false end
    return string.sub(str, 1, #start) == start
end

function Teleport.Helpers:startsWithCaseInsensitive(str, start)
    if not str or not start then return false end
    return Teleport.Helpers:startsWith(string.lower(str), string.lower(start))
end

function Teleport.Helpers:endsWith(str, ending)
    if not str or not ending then return false end
    return string.sub(str, -#ending) == ending
end

function Teleport.Helpers:splitOnSpace(input)
    local position = string.find(input, ' ', 1, true)
    if not position then return nil end
    return string.sub(input, 1, position - 1), string.sub(input, position + 1)
end

function Teleport.Helpers:initialsFromSpaceAndDash(input)
    if not input then return "" end

    local result = {}

    for word in string.gmatch(input, "[^%s%-]+") do
        table.insert(result, string.sub(word, 1, 1))
    end

    return string.lower(table.concat(result))
end

function Teleport.Helpers:removeFirstChar(str)
    if not str or #str == 0 then return str end
    return string.sub(str, 2)
end

function Teleport.Helpers:removeLastChar(str)
    if not str or #str == 0 then return str end
    return string.sub(str, 1, -2)
end

function Teleport.Helpers:removeFirstWord(str)
    if not str then return str end

    local pos = string.find(str, " ", 1, true)
    if not pos then return "" end

    return string.sub(str, pos + 1)
end

function Teleport.Helpers:startsWithLabel(str)
    if not str then return false end
    return string.match(string.lower(str), "^[a-z]+: ") ~= nil
end

function Teleport.Helpers:isAtWayshrine()
    return GetInteractionType() == INTERACTION_FAST_TRAVEL
end

--------------------------------------------------------------------------------
-- World map state helpers
--
-- Everything that needs map coordinates (wayshrines, survey spots, quest
-- objectives) has to switch the *current map* via SetMapTo*() calls. That
-- doesn't open the map UI, but it does change the shared map state that the
-- world map / minimap addons read, so it always has to be put back afterwards.

local mapStack = {}

function Teleport.Helpers:pushMap()
    if LibGPS3 then
        LibGPS3:PushCurrentMap()
    else
        table.insert(mapStack, GetCurrentMapId())
    end
end

function Teleport.Helpers:popMap()
    if LibGPS3 then
        return LibGPS3:PopCurrentMap()
    end

    local mapId = table.remove(mapStack)
    if mapId then
        return SetMapToMapId(mapId)
    end
end

-- rough size of a zone map, only used when LibGPS is not available
local FALLBACK_MAP_SIZE_METERS = 4000

-- distance between two points on the *current* map, in meters
function Teleport.Helpers:mapDistance(x1, y1, x2, y2)
    if LibGPS3 then
        local ok, distance = pcall(LibGPS3.GetLocalDistanceInMeters, LibGPS3, x1, y1, x2, y2)
        if ok and distance then return distance end
    end

    local dx, dy = x2 - x1, y2 - y1
    return math.sqrt(dx * dx + dy * dy) * FALLBACK_MAP_SIZE_METERS
end

function Teleport.Helpers:isOnMap(x, y)
    return x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1
end

function Teleport.Helpers:formatMeters(meters)
    if meters >= 1000 then
        return string.format("%.1fkm", meters / 1000)
    end
    return string.format("%dm", zo_round(meters / 10) * 10)
end
