-- DevSandbox3PinUtils.lua: Pure helpers for map pin layout/visibility (no side effects)

local PinUtils = {}

PinUtils.FILTER_LABEL = "War Torte Recipes"

-- Pinpoint dots. The stock map clamps every pin to MIN_PIN_SIZE (18) unless the layout gives its own minSize,
-- so minSize must be set explicitly for anything smaller than 18 to actually render small.
PinUtils.DOT_TEXTURE = "DevSandbox3/textures/dot_plain.dds"

---@param level integer
---@param size integer
---@param tint table ZO_ColorDef
---@return table
local function Dot(level, size, tint)
    return { level = level, texture = PinUtils.DOT_TEXTURE, size = size, minSize = math.max(2, math.floor(size * 0.6)), tint = tint }
end

---@param candidate boolean
---@param size integer|nil UI units (default 8)
---@return table pinLayoutData for LibMapPins:AddPinType
function PinUtils.CreateLayout(candidate, size)
    size = size or 8
    return Dot(candidate and 49 or 50, candidate and math.max(3, size - 2) or size,
        candidate and ZO_ColorDef:New(1.0, 0.85, 0.3, 0.9) or ZO_ColorDef:New(0.45, 1.0, 0.45, 1.0))
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
PinUtils.EMPTY_SLOT_FILTER_LABEL = "War Torte: expected nodes missing"

---Small grey dot: an expected material slot within compass range that has not been verified yet.
---@param size integer|nil
---@return table
function PinUtils.CreateExpectedSlotLayout(size)
    return Dot(44, math.max(3, (size or 8) - 2), ZO_ColorDef:New(0.7, 0.7, 0.7, 0.6))
end

---Orange marker: an expected material slot that was checked and had no harvest node (book candidate).
---@param size integer|nil
---@return table
function PinUtils.CreateEmptySlotLayout(size)
    return Dot(48, size or 8, ZO_ColorDef:New(1.0, 0.55, 0.15, 1.0))
end

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
