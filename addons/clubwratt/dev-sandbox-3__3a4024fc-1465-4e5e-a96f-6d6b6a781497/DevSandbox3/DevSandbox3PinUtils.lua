-- DevSandbox3PinUtils.lua: Pure helpers for map pin layout/visibility (no side effects)

local PinUtils = {}

PinUtils.FILTER_LABEL = "War Torte Recipes"

---@param candidate boolean
---@return table pinLayoutData for LibMapPins:AddPinType
function PinUtils.CreateLayout(candidate)
    return {
        level = candidate and 49 or 50,
        texture = "EsoUI/Art/ZoneStories/completionTypeIcon_lorebooks.dds",
        size = candidate and 26 or 32,
        tint = candidate and ZO_ColorDef:New(1.0, 0.85, 0.3, 0.9) or ZO_ColorDef:New(0.45, 1.0, 0.45, 1.0),
    }
end

---Layout for area-only pins (circle blob, no icon).
---@param level integer
---@return table
function PinUtils.CreateAreaLayout(level)
    return {
        level = level,
        texture = "EsoUI/Art/MapPins/map_areaPin.dds",
        size = 0,
    }
end

PinUtils.CANDIDATE_FILTER_LABEL = "War Torte Candidates (unrecognized nodes)"

---Pins are only meaningful on Cyrodiil maps (or the Tamriel world map).
---@param mapType integer GetMapType()
---@param zoneId integer GetZoneId(GetCurrentMapZoneIndex())
---@return boolean
function PinUtils.ShouldShowOnMap(mapType, zoneId)
    if mapType == MAPTYPE_WORLD then
        return true
    end
    return zoneId == DevSandbox3.NodeUtils.CYRODIIL_ZONE_ID
end

---@param lx number|nil
---@param ly number|nil
---@return boolean
function PinUtils.IsOnCurrentMap(lx, ly)
    if type(lx) ~= "number" or type(ly) ~= "number" then
        return false
    end
    return lx > 0 and lx < 1 and ly > 0 and ly < 1
end

---@param node DevSandbox3Node
---@param now integer
---@return string[] lines
function PinUtils.BuildTooltipLines(node, now)
    local NodeUtils = DevSandbox3.NodeUtils
    return {
        node.candidate and "Unrecognized harvest node (war torte candidate?)" or "Colovian War Torte recipe spawn",
        node.name,
        string.format("%s %dx, last %s", node.looted and "Looted" or "Spotted", node.seenCount, NodeUtils.FormatAge(now - node.lastSeen)),
    }
end

DevSandbox3.PinUtils = PinUtils
