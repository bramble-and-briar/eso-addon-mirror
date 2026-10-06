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
    ["Pure Water"] = P.WATER, ["Water Skin"] = P.WATER, ["Herbalist's Satchel"] = P.HERBALIST,
}
local lower = {}
for name, id in pairs(BY_NAME) do lower[string.lower(name)] = id end
local PREFIXES = { "rich ", "lush ", "pristine ", "protean " }

---@param name string|nil compass pin description
---@return integer|nil
function PinTypeUtils.FromName(name)
    if type(name) ~= "string" then return nil end
    local s = string.lower(name)
    if lower[s] then return lower[s] end
    for _, p in ipairs(PREFIXES) do
        if s:sub(1, #p) == p and lower[s:sub(#p + 1)] then return lower[s:sub(#p + 1)] end
    end
    return nil
end

DevSandbox3.PinTypeUtils = PinTypeUtils
