if not SemisPlaygroundCheckAccess() then return end

---Whether a dropped piece of gear has a price worth a listing.
---
---Most sets are worth nothing, and the price list shows it only indirectly:
---four of five gear records rest on one or two sales, at whatever a seller
---once asked. A price counts when the piece's own record took three or more
---sales. Short of that, the set's pieces of one trait, quality and gear class
---vouch for each other: when their records took three or more sales between
---them and their median is worth a listing, each piece takes that median.
---Failing both, a price counts only in a set people trade: one whose
---collection pieces hold several proven records at a listing's worth. Any
---other piece has no price, and goes to deconstruction or a merchant.
---docs/inventory-addon/player-gear-market-research.md has the numbers.

---@class InventoryPocGearQuote
---@field price number|nil
---@field exact number|nil The piece's own unproven record the price was decided with
---@field untilMs number
---@class InventoryPocGearRecord A sibling's record, read by item ID
---@field itemId number
---@field price number
---@field sales number
---@class InventoryPocGearPrices
---@field cache table<string, InventoryPocGearQuote>
---@field traded table<number, boolean> By set ID, see `tradedSet`
---@field source InventoryPocTsc|nil
---@field sourceData table<number, string|unknown>|nil
---@field PROVEN_SALES number Recorded sales that make a record's price count on its own
---@field TRADED_SET_RECORDS number Such records, at a listing's worth, that make a set a traded one
local prices = { cache = {}, traded = {}, PROVEN_SALES = 3, TRADED_SET_RECORDS = 4 }
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

---A set people trade. Its collection pieces are read by item ID, without links.
---@param setId number
---@return boolean|nil traded Nil while the price list loads
local function tradedSet(setId)
    local known = prices.traded[setId]
    if known ~= nil then return known end
    local records = 0
    for index = 1, GetNumItemSetCollectionPieces(setId) do
        local pieceId = GetItemSetCollectionPieceInfo(setId, index)
        local count, loading = facts.provenRecords(pieceId, policy.GEAR_MIN_LISTING)
        if loading then return nil end
        records = records + count
    end
    known = records >= prices.TRADED_SET_RECORDS
    prices.traded[setId] = known
    return known
end

---The piece's own record when it is proven, else the median its same-trait
---pieces vouch for. In a traded set an unproven record counts too, and a
---piece without one takes the median of matching pieces whatever they show.
---The collection catalogue keeps each lookup bounded to one set.
---
---Prices are recorded per item ID, and a set drops each trait under IDs of
---its own. A collection link keeps its piece's ID whatever trait it is asked
---for, so its price is another trait's. The pieces of one trait sit as far
---from the collection's IDs as the item sits from its own piece: that
---distance finds them. Their records are read by ID, and the game's data
---confirms each piece before its record is used.
---@param link string
---@return number|nil
---@return boolean|nil loading
function prices.referencePrice(link)
    local item = facts.variant(link)
    if IsItemLinkCrafted(link) then return nil end
    if item.setId and item.setId > 0 and item.championPoints ~= 160 then return nil end
    local exact, loading, sales = facts.price(link)
    if loading then return nil, true end
    local pooled = sales or 0
    if exact and pooled >= prices.PROVEN_SALES then return exact end
    if not item.setId or item.setId == 0 then return nil end
    local api = rawget(_G, 'TSCPriceDataAPI') ---@type InventoryPocTsc|nil
    if not api or GetWorldName() ~= 'XB1live-eu' then return nil end
    if prices.source ~= api or prices.sourceData ~= api.priceData then
        prices.cache, prices.traded, prices.source, prices.sourceData = {}, {}, api, api.priceData
    end
    local traded = tradedSet(item.setId)
    if traded == nil then return nil, true end
    local key = facts.variantKey(item)
    local cached = prices.cache[key]
    if cached and cached.exact == exact and GetFrameTimeMilliseconds() < cached.untilMs then return cached.price end
    local seen, siblings = {}, {}
    local ownSlot = GetItemLinkItemSetCollectionSlot(link)
    local filter = collectionFilter(ownSlot)
    local ownPieceId
    for index = 1, GetNumItemSetCollectionPieces(item.setId) do
        local pieceId, slot = GetItemSetCollectionPieceInfo(item.setId, index)
        if AreId64sEqual(slot, ownSlot) then ownPieceId = pieceId
        elseif collectionFilter(slot) == filter then siblings[#siblings + 1] = pieceId end
    end
    local records = {} ---@type InventoryPocGearRecord[]
    local best = exact or 0
    if ownPieceId then
        local distance = item.itemId - ownPieceId
        seen[ownPieceId] = true
        for _, pieceId in ipairs(siblings) do
            if not seen[pieceId] and pieceId + distance > 0 then
                seen[pieceId] = true
                local price, pending, count = facts.recordedPrice(pieceId + distance, item.quality)
                if pending then return nil, true end
                if price then
                    records[#records + 1] = { itemId = pieceId + distance, price = price, sales = count or 0 }
                    pooled, best = pooled + (count or 0), math.max(best, price)
                end
            end
        end
    end
    local price = traded and exact or nil
    -- The client keeps native data for every distinct link it is asked about until it
    -- exits (docs/addon-memory-research.md). Links are built only for pieces with a
    -- record, and only where the records could vouch or a traded set's piece has none.
    if (pooled >= prices.PROVEN_SALES and best >= policy.GEAR_MIN_LISTING) or (traded and not exact) then
        local quotes = { exact }
        pooled = sales or 0
        for _, record in ipairs(records) do
            if policy.sameSetGearClass(item, facts.variant(facts.linkWithItemId(link, record.itemId))) then
                quotes[#quotes + 1], pooled = record.price, pooled + record.sales
            end
        end
        table.sort(quotes)
        -- Of an even count, the lower of the middle two.
        local median = quotes[math.floor((#quotes + 1) / 2)]
        local vouched = pooled >= prices.PROVEN_SALES and median and median >= policy.GEAR_MIN_LISTING
        if vouched or (traded and not exact) then price = median end
    end
    prices.cache[key] = { price = price, exact = exact, untilMs = GetFrameTimeMilliseconds() + CACHE_MS }
    return price
end
