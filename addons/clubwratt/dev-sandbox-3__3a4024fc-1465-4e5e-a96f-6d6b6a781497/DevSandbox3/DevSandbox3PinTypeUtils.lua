-- DevSandbox3PinTypeUtils.lua: HarvestMap pin type ids + interactable name -> pin type (no side effects)
local PinTypeUtils = {}

PinTypeUtils.BLACKSMITH, PinTypeUtils.CLOTHING, PinTypeUtils.ENCHANTING, PinTypeUtils.MUSHROOM, PinTypeUtils.WOODWORKING = 1, 2, 3, 4, 5
PinTypeUtils.WATER, PinTypeUtils.FLOWER, PinTypeUtils.WATERPLANT, PinTypeUtils.CRIMSON, PinTypeUtils.HERBALIST = 7, 13, 14, 19, 20
-- the harvestable types present in the data (chests etc. are not compass HARVEST_NODE pins)
PinTypeUtils.HARVESTABLE = { [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [7] = true, [13] = true, [14] = true, [19] = true, [20] = true }

local P = PinTypeUtils
local BY_NAME = {
    ["Runestone"] = P.ENCHANTING,
    ["Blessed Thistle"] = P.FLOWER, ["Wormwood"] = P.FLOWER, ["Lady's Smock"] = P.FLOWER, ["Bugloss"] = P.FLOWER, ["Dragonthorn"] = P.FLOWER,
    ["Mountain Flower"] = P.FLOWER, ["Columbine"] = P.FLOWER, ["Corn Flower"] = P.FLOWER, ["Nightshade"] = P.FLOWER,
    ["Nirnroot"] = P.WATERPLANT, ["Water Hyacinth"] = P.WATERPLANT, ["Crimson Nirnroot"] = P.CRIMSON,
    ["Stinkhorn"] = P.MUSHROOM, ["Blue Entoloma"] = P.MUSHROOM, ["Emetic Russula"] = P.MUSHROOM, ["Violet Coprinus"] = P.MUSHROOM,
    ["Namira's Rot"] = P.MUSHROOM, ["White Cap"] = P.MUSHROOM, ["Luminous Russula"] = P.MUSHROOM, ["Imp Stool"] = P.MUSHROOM,
    ["Maple"] = P.WOODWORKING, ["Oak"] = P.WOODWORKING, ["Beech"] = P.WOODWORKING, ["Hickory"] = P.WOODWORKING, ["Yew"] = P.WOODWORKING,
    ["Birch"] = P.WOODWORKING, ["Ash"] = P.WOODWORKING, ["Mahogany"] = P.WOODWORKING, ["Nightwood"] = P.WOODWORKING, ["Ruby Ash Wood"] = P.WOODWORKING,
    ["Iron Ore"] = P.BLACKSMITH, ["High Iron Ore"] = P.BLACKSMITH, ["Orichalcum Ore"] = P.BLACKSMITH, ["Dwarven Ore"] = P.BLACKSMITH, ["Ebony Ore"] = P.BLACKSMITH,
    ["Calcinium Ore"] = P.BLACKSMITH, ["Galatite Ore"] = P.BLACKSMITH, ["Quicksilver Ore"] = P.BLACKSMITH, ["Voidstone Ore"] = P.BLACKSMITH, ["Rubedite Ore"] = P.BLACKSMITH,
    ["Pewter Seam"] = P.BLACKSMITH, ["Copper Seam"] = P.BLACKSMITH, ["Silver Seam"] = P.BLACKSMITH, ["Electrum Seam"] = P.BLACKSMITH, ["Platinum Seam"] = P.BLACKSMITH,
    ["Jute"] = P.CLOTHING, ["Flax"] = P.CLOTHING, ["Cotton"] = P.CLOTHING, ["Spidersilk"] = P.CLOTHING, ["Ebonthread"] = P.CLOTHING,
    ["Kreshweed"] = P.CLOTHING, ["Ironweed"] = P.CLOTHING, ["Silverweed"] = P.CLOTHING, ["Void Bloom"] = P.CLOTHING, ["Ancestor Silk"] = P.CLOTHING,
    ["Pure Water"] = P.WATER, ["Water Skin"] = P.WATER, ["Potable Liquids"] = P.WATER, ["Herbalist's Satchel"] = P.HERBALIST,
    ["Torn Cloth"] = P.CLOTHING, ["Scrap Wood"] = P.WOODWORKING,
}
local lower = {}
for name, id in pairs(BY_NAME) do lower[string.lower(name)] = id end
local PREFIXES = { "rich ", "lush ", "pristine ", "protean " }

-- Every node name, in the order the tracker dropdown lists them: alchemy reagents first, then the rest; each
-- group alphabetical (the console dropdown is a left/right list that does not wrap).
local REAGENT = { [P.FLOWER] = true, [P.MUSHROOM] = true, [P.WATERPLANT] = true, [P.CRIMSON] = true }
PinTypeUtils.NAMES = {}
for name in pairs(BY_NAME) do PinTypeUtils.NAMES[#PinTypeUtils.NAMES + 1] = name end
table.sort(PinTypeUtils.NAMES, function(a, b)
    local ra, rb = REAGENT[BY_NAME[a]] or false, REAGENT[BY_NAME[b]] or false
    if ra ~= rb then return ra end
    return a < b
end)

---The node a name stands for: lower case, quality prefix dropped ("Lush Columbine" and "Columbine" -> "columbine").
---@param name string|nil compass pin description, or a name from NAMES
---@return string|nil key nil for a name that is not a harvest node
function PinTypeUtils.Key(name)
    if type(name) ~= "string" then return nil end
    local s = string.lower(name)
    if lower[s] then return s end
    for _, p in ipairs(PREFIXES) do
        local rest = s:sub(#p + 1)
        if s:sub(1, #p) == p and lower[rest] then return rest end
    end
    return nil
end

---@param key string a key from PinTypeUtils.Key
---@return integer|nil
function PinTypeUtils.TypeOfKey(key)
    return lower[key]
end

---@param name string|nil compass pin description
---@return integer|nil
function PinTypeUtils.FromName(name)
    local key = PinTypeUtils.Key(name)
    return key and lower[key]
end

DevSandbox3.PinTypeUtils = PinTypeUtils
