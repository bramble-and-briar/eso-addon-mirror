-- DevSandbox3NodeUtils.lua: Pure helpers for war torte node records (no side effects)

local NodeUtils = {}

-- Interactable / item names that identify the Colovian War Torte recipe spawn.
-- The world object is "Lost Imperial Notes" (a glowing green book replacing a mat node).
NodeUtils.MATCH_PATTERNS = {
    "lost imperial notes",
    "war torte",
}

-- Item id of "Recipe: Colovian War Torte"
NodeUtils.RECIPE_ITEM_ID = 171324

-- Two sightings closer than this (in meters) are treated as the same node.
NodeUtils.MERGE_DISTANCE_METERS = 25

NodeUtils.CYRODIIL_ZONE_ID = 181

-- Every interactable name the engine reports as a HARVEST_NODE compass pin for ordinary materials
-- (list from HarvestMap/LibNodeDetection default localization). A harvest node whose name is NOT
-- in this set is treated as a candidate war torte spawn even if we don't recognise its name.
NodeUtils.KNOWN_MATERIALS = {}
for _, name in ipairs({
    "Ancestor Silk", "Ash", "Beech", "Birch", "Blessed Thistle", "Blue Entoloma", "Bugloss", "Calcinium Ore",
    "Columbine", "Copper Seam", "Corn Flower", "Cotton", "Crimson Nirnroot", "Dragonthorn", "Dwarven Ore",
    "Ebonthread", "Ebony Ore", "Electrum Seam", "Emetic Russula", "Flax", "Galatite Ore", "Herbalist's Satchel",
    "Hickory", "High Iron Ore", "Imp Stool", "Iron Ore", "Ironweed", "Jute", "Kreshweed", "Lady's Smock",
    "Luminous Russula", "Mahogany", "Maple", "Mountain Flower", "Namira's Rot", "Nightshade", "Nightwood",
    "Nirnroot", "Oak", "Orichalcum Ore", "Pewter Seam", "Platinum Seam", "Potable Liquids", "Pure Water",
    "Quicksilver Ore", "Rubedite Ore", "Ruby Ash Wood", "Runestone", "Scrap Wood", "Silver Seam", "Silverweed",
    "Spidersilk", "Stinkhorn", "Torn Cloth", "Violet Coprinus", "Void Bloom", "Voidstone Ore", "Water Hyacinth",
    "Water Skin", "White Cap", "Wormwood", "Yew",
    -- Cyrodiil-flavoured names seen in testing
    "Protean Runestone", "Rich Iron Ore", "Rich Platinum Seam",
}) do
    NodeUtils.KNOWN_MATERIALS[string.lower(name)] = true
end

-- Current Cyrodiil spawns survey-style bonus nodes: "Rich <ore/seam>", "Lush <plant/reagent>", "Pristine <wood>".
-- Both the plain and the prefixed names are ordinary materials.
NodeUtils.MATERIAL_PREFIXES = { "rich ", "lush ", "pristine " }

---@param lowered string already-lowercased interactable name
---@return boolean
function NodeUtils.IsKnownMaterial(lowered)
    if NodeUtils.KNOWN_MATERIALS[lowered] then
        return true
    end
    for _, prefix in ipairs(NodeUtils.MATERIAL_PREFIXES) do
        if string.sub(lowered, 1, #prefix) == prefix and NodeUtils.KNOWN_MATERIALS[string.sub(lowered, #prefix + 1)] then
            return true
        end
    end
    return false
end

NodeUtils.CLASS_MATERIAL = "material"
NodeUtils.CLASS_WAR_TORTE = "wartorte"
NodeUtils.CLASS_UNKNOWN = "unknown"

---@param name string|nil
---@return boolean
function NodeUtils.IsWarTorteName(name)
    if type(name) ~= "string" or name == "" then
        return false
    end
    local lowered = string.lower(name)
    for _, pattern in ipairs(NodeUtils.MATCH_PATTERNS) do
        if string.find(lowered, pattern, 1, true) then
            return true
        end
    end
    local state = DevSandbox3.state
    local extra = state and state.savedVars and state.savedVars.extraPatterns
    if extra then
        for _, pattern in ipairs(extra) do
            if string.find(lowered, pattern, 1, true) then
                return true
            end
        end
    end
    return false
end

---Classify a HARVEST_NODE compass description.
---@param name string|nil
---@param ignoredNames table<string, boolean>|nil lowercase names the user told us to ignore
---@return string class one of NodeUtils.CLASS_*
function NodeUtils.ClassifyHarvestNode(name, ignoredNames)
    if type(name) ~= "string" or name == "" then
        return NodeUtils.CLASS_MATERIAL
    end
    if NodeUtils.IsWarTorteName(name) then
        return NodeUtils.CLASS_WAR_TORTE
    end
    local lowered = string.lower(name)
    if NodeUtils.IsKnownMaterial(lowered) or (ignoredNames and ignoredNames[lowered]) then
        return NodeUtils.CLASS_MATERIAL
    end
    return NodeUtils.CLASS_UNKNOWN
end

---@param itemId integer|nil
---@param itemName string|nil
---@return boolean
function NodeUtils.IsWarTorteLoot(itemId, itemName)
    if itemId == NodeUtils.RECIPE_ITEM_ID then
        return true
    end
    return NodeUtils.IsWarTorteName(itemName)
end

---@param gx number
---@param gy number
---@param name string
---@param zoneId integer
---@param now integer
---@return DevSandbox3Node
function NodeUtils.CreateNode(gx, gy, name, zoneId, now)
    return {
        gx = gx,
        gy = gy,
        name = name,
        zoneId = zoneId,
        firstSeen = now,
        lastSeen = now,
        seenCount = 1,
        looted = false,
        candidate = false,
    }
end

---Find the index of an existing node within merge distance of (gx, gy).
---@param nodes DevSandbox3Node[]
---@param gx number
---@param gy number
---@param distanceFn fun(x1:number,y1:number,x2:number,y2:number):number global-distance-in-meters
---@return integer|nil index
function NodeUtils.FindNearbyNodeIndex(nodes, gx, gy, distanceFn)
    for index, node in ipairs(nodes) do
        local meters = distanceFn(node.gx, node.gy, gx, gy)
        if meters and meters <= NodeUtils.MERGE_DISTANCE_METERS then
            return index
        end
    end
    return nil
end

---Strip the " [TYPE]" suffix compass detection appends to non-harvest candidates.
---@param name string
---@return string
function NodeUtils.BaseName(name)
    return (string.gsub(name or "", "%s*%[[A-Z_]+%]$", ""))
end

---@param seconds integer
---@return string
function NodeUtils.FormatAge(seconds)
    if seconds < 60 then
        return string.format("%ds ago", seconds)
    elseif seconds < 3600 then
        return string.format("%dm ago", math.floor(seconds / 60))
    elseif seconds < 86400 then
        return string.format("%dh ago", math.floor(seconds / 3600))
    end
    return string.format("%dd ago", math.floor(seconds / 86400))
end

---@param node DevSandbox3Node
---@param now integer
---@return string
function NodeUtils.DescribeNode(node, now)
    local status = node.looted and "looted here" or (node.candidate and "UNRECOGNIZED node, candidate" or "spotted")
    return string.format("%s - %s %dx, last %s", node.name, status, node.seenCount, NodeUtils.FormatAge(now - node.lastSeen))
end

DevSandbox3.NodeUtils = NodeUtils
