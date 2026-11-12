if not SemisPlaygroundCheckAccess() then return end

---@class InventoryPocGearQuote
---@field price number|nil
---@field untilMs number
---@class InventoryPocGearPrices
---@field cache table<string, InventoryPocGearQuote>
---@field source InventoryPocTsc|nil
---@field sourceData table<number, string|unknown>|nil
local prices = { cache = {} }
BattleScrolls.inventoryPocGearPrices = prices
local facts = BattleScrolls.inventoryPocFacts
local policy = BattleScrolls.inventoryPocPolicy
local CACHE_MS = 60 * 60000

---Collection filter of a set piece, with rings and necklaces as one class
---to match `policy.sameSetGearClass`.
---@param slot ItemSetCollectionSlot_id64
---@return EquipmentFilterType
local function collectionFilter(slot)
    local filter = GetEquipmentFilterTypeForItemSetCollectionSlot(slot)
    return filter == EQUIPMENT_FILTER_TYPE_NECK and EQUIPMENT_FILTER_TYPE_RING or filter
end

---Read the piece first, then the median of matching pieces in its set.
---The collection catalogue keeps each lookup bounded to one set.
---@param link string
---@return number|nil
---@return boolean|nil loading
function prices.referencePrice(link)
    local item = facts.variant(link)
    if IsItemLinkCrafted(link) then return nil end
    if item.setId and item.setId > 0 and item.championPoints ~= 160 then return nil end
    local exact, loading = facts.price(link)
    if exact or loading then return exact, loading end
    if not item.setId or item.setId == 0 then return nil end
    local api = rawget(_G, 'TSCPriceDataAPI') ---@type InventoryPocTsc|nil
    if not api or GetWorldName() ~= 'XB1live-eu' then return nil end
    if prices.source ~= api or prices.sourceData ~= api.priceData then
        prices.cache, prices.source, prices.sourceData = {}, api, api.priceData
    end
    local key = facts.variantKey(item)
    local cached = prices.cache[key]
    if cached and GetFrameTimeMilliseconds() < cached.untilMs then return cached.price end
    local quotes, seen = {}, {}
    local quality = item.quality
    ---@cast quality ItemQuality
    local filter = collectionFilter(GetItemLinkItemSetCollectionSlot(link))
    for index = 1, GetNumItemSetCollectionPieces(item.setId) do
        local pieceId, slot = GetItemSetCollectionPieceInfo(item.setId, index)
        -- The client keeps native data for every distinct link it is asked about until
        -- it exits (docs/addon-memory-research.md), so links are built only for pieces
        -- that can share the item's gear class.
        local candidate = (filter == EQUIPMENT_FILTER_TYPE_NONE or collectionFilter(slot) == filter)
            and GetItemSetCollectionPieceItemLink(pieceId, LINK_STYLE_DEFAULT, item.trait, quality) or ''
        if candidate ~= '' then
            local variant = facts.variant(candidate)
            if not seen[variant.itemId] and policy.sameSetGearClass(item, variant) then
                seen[variant.itemId] = true
                local price, pending = facts.price(candidate)
                if pending then return nil, true end
                if policy.validPrice(price) then quotes[#quotes + 1] = price end
            end
        end
    end
    local median
    if #quotes > 0 then
        table.sort(quotes)
        local middle = math.floor((#quotes + 1) / 2)
        median = #quotes % 2 == 1 and quotes[middle] or (quotes[middle] + quotes[middle + 1]) / 2
    end
    prices.cache[key] = { price = median, untilMs = GetFrameTimeMilliseconds() + CACHE_MS }
    return median
end
