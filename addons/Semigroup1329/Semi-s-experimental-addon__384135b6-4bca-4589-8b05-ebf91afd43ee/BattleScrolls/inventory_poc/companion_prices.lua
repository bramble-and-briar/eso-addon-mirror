if not SemisPlaygroundCheckAccess() then return end

---@class InventoryPocCompanionFamilyPrices
---@field price number|nil
---@field untilMs number
---@class InventoryPocCompanionPrices
---@field families table<string, InventoryPocCompanionFamilyPrices>
---@field source InventoryPocTsc|nil
---@field sourceData table<number, string|unknown>|nil
local prices = { families = {} }
BattleScrolls.inventoryPocCompanionPrices = prices
local facts = BattleScrolls.inventoryPocFacts
local policy = BattleScrolls.inventoryPocPolicy
local CACHE_MS = 15 * 60000
local REQUIRED_COMPARABLES = 3

-- Companion catalogue layout: each trait has 36 pieces per quality. Heavy
-- gloves have their own nine-trait blocks. Every generated link is checked
-- through native APIs before its quote enters a family. Research and ID
-- provenance: docs/inventory-addon/companion-market-research.md.
local TRAIT_STARTS = { 175805, 176110, 176254, 176398, 176542, 176686, 176830, 176974, 177118 }
local GAUNTLETS_START = 178415
local PIECES_PER_QUALITY = 36
local ARMOR_OFFSETS = {
    [ARMORTYPE_LIGHT] = { 0, 1, 2, 3, 4, 5, 6, 7 },
    [ARMORTYPE_MEDIUM] = { 8, 9, 10, 11, 12, 13, 14 },
    [ARMORTYPE_HEAVY] = { 15, 16, 17, 18, 19, 20 },
}
local ONE_HAND_OFFSETS = { 26, 27, 28, 30 }
local TWO_HAND_OFFSETS = { 23, 24, 25 }
local JEWELRY_OFFSETS = { 21, 22 }

---@param item InventoryPocVariant
---@return number|nil
local function traitIndex(item)
    local qualityOffset = (item.quality - 2) * PIECES_PER_QUALITY
    for index, first in ipairs(TRAIT_STARTS) do
        local offset = item.itemId - first - qualityOffset
        if offset >= 0 and offset < PIECES_PER_QUALITY then return index end
    end
    local gloves = item.itemId - GAUNTLETS_START - (item.quality - 2) * #TRAIT_STARTS
    if gloves >= 0 and gloves < #TRAIT_STARTS then return gloves + 1 end
end

---@param item InventoryPocVariant
---@return number[]|nil
local function offsets(item)
    if item.equipType == EQUIP_TYPE_RING or item.equipType == EQUIP_TYPE_NECK then return JEWELRY_OFFSETS end
    if item.weaponType == WEAPONTYPE_NONE then return ARMOR_OFFSETS[item.armorType] end
    if item.weaponType == WEAPONTYPE_AXE or item.weaponType == WEAPONTYPE_SWORD
        or item.weaponType == WEAPONTYPE_HAMMER or item.weaponType == WEAPONTYPE_DAGGER then return ONE_HAND_OFFSETS end
    if item.weaponType == WEAPONTYPE_TWO_HANDED_AXE or item.weaponType == WEAPONTYPE_TWO_HANDED_SWORD
        or item.weaponType == WEAPONTYPE_TWO_HANDED_HAMMER then return TWO_HAND_OFFSETS end
end

---@param link string
---@return number|nil median
---@return boolean|nil loading
function prices.referencePrice(link)
    local api = rawget(_G, 'TSCPriceDataAPI') ---@type InventoryPocTsc|nil
    if GetWorldName() ~= 'XB1live-eu' or not api then return nil end
    local item = facts.variant(link)
    if item.actorCategory ~= GAMEPLAY_ACTOR_CATEGORY_COMPANION or item.quality < 2 or item.quality > 4 then
        return facts.price(link)
    end
    local family = offsets(item)
    -- Each staff type, bows and shields have a single catalogue entry per
    -- quality and trait, so their group median is that entry's quote.
    if not family then return facts.price(link) end
    local index = traitIndex(item)
    if not index then return nil end
    if prices.source ~= api or prices.sourceData ~= api.priceData then
        prices.families, prices.source, prices.sourceData = {}, api, api.priceData
    end
    local key = table.concat({ index, item.quality, item.trait, item.armorType, family[1] }, ':')
    local cached = prices.families[key]
    if not cached or GetFrameTimeMilliseconds() >= cached.untilMs then
        local payload = link:match('|H%d+:item:%d+(:[^|]+)|h')
        if not payload then return nil end
        local quotes, loading = {}, false
        local function collect(id)
            local candidate = '|H0:item:' .. tostring(id) .. payload .. '|h|h'
            local variant = facts.variant(candidate)
            if variant.itemId ~= id or not policy.sameCompanionClass(item, variant) then return end
            local price, pending = facts.price(candidate)
            if pending then loading = true end
            if policy.validPrice(price) then quotes[#quotes + 1] = price end
        end
        local base = TRAIT_STARTS[index] + (item.quality - 2) * PIECES_PER_QUALITY
        for _, offset in ipairs(family) do collect(base + offset) end
        if family == ARMOR_OFFSETS[ARMORTYPE_HEAVY] then
            collect(GAUNTLETS_START + (item.quality - 2) * #TRAIT_STARTS + index - 1)
        end
        if loading then return nil, true end
        local median
        -- Larger groups need three quotes; two-handed melee needs two and
        -- jewelry needs one. Every group includes the target's usable quote.
        if #quotes >= math.min(REQUIRED_COMPARABLES, #family - 1) then
            table.sort(quotes)
            local middle = math.floor((#quotes + 1) / 2)
            median = #quotes % 2 == 1 and quotes[middle] or (quotes[middle] + quotes[middle + 1]) / 2
        end
        cached = { price = median, untilMs = GetFrameTimeMilliseconds() + CACHE_MS }
        prices.families[key] = cached
    end
    return cached.price
end
