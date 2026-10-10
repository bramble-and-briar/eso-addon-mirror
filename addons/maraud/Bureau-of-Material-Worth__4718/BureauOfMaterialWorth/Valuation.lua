local addon = BureauOfMaterialWorth
addon.Valuation = addon.Valuation or {}

local Valuation = addon.Valuation
local private = addon.private

-- Hot-path global caching
-- ---------------------------------------------------------------------------
-- Cache inventory and pricing functions used by slot scans.
local GetSlotStackSize          = GetSlotStackSize
local GetItemId                 = GetItemId
local GetItemLink               = GetItemLink
local GetItemLinkItemType       = GetItemLinkItemType
local ZO_GetNextBagSlotIndex    = ZO_GetNextBagSlotIndex
local GetNumBagFreeSlots        = GetNumBagFreeSlots
local LibPrice                  = LibPrice

-- Backpack destination used by capacity checks.
local BAG_BACKPACK              = BAG_BACKPACK

-- Cached display, time, and price-history helpers.
local GetItemLinkName             = GetItemLinkName
local GetItemLinkIcon             = GetItemLinkIcon
local GetItemLinkFunctionalQuality = GetItemLinkFunctionalQuality
local GetItemQualityColor         = GetItemQualityColor
local GetTimeStamp                = GetTimeStamp
local zo_round                    = zo_round
local mathabs                     = math.abs
local zo_strformat                = zo_strformat
local tablesort                   = table.sort
local stringformat                = string.format
local stringgmatch                = string.gmatch
local stringmatch                 = string.match
local tonumber                    = tonumber

local BAG = BAG_VIRTUAL

-- Craft Bag slots count distinct materials; classic stacks are a separate,
-- derived count using the stack size shared with the withdrawal module.
local STACK_SIZE = private.STACK_SIZE

-- Price-history bookkeeping for the detail window's "price change" column.
-- ---------------------------------------------------------------------------
-- Encoded observations support the latest comparable price change and seven-day
-- trends. Append on a new UI session or source change; otherwise update the last
-- point. Row building never writes history, and source changes break comparison.
-- Retain the latest baseline outside the trend window; drop materials unseen for
-- PRUNE_MAX_AGE_SECONDS and cap each series at PRICE_HISTORY_MAX_POINTS.
local PRUNE_MAX_AGE_SECONDS   = 30 * 24 * 60 * 60  -- 30 days
local PRICE_TREND_WINDOW_SECONDS = 7 * 24 * 60 * 60
-- Session-gated writes can land more than one point a day, so keep enough room
-- for a week of typical play (a few logins per day) inside the seven-day window.
local PRICE_HISTORY_MAX_POINTS = 30

-- Grand-total value history (the footer sparkline)
-- ---------------------------------------------------------------------------
-- One total-value sample per UI session in a fixed-size ring buffer.
-- Reopening the bag does not append; old samples are overwritten in place.
local VALUE_HISTORY_CAPACITY = 90

-- Encode persisted records as scalar strings to keep saves compact.
-- %.17g preserves number precision; item links occupy the last record field.
local SAVE_SEPARATOR = "~"
local PRICE_POINT_SEPARATOR = "|"

local function EncodeNumber(value)
    return stringformat("%.17g", value or 0)
end

local function EncodeSnapshotMaterial(entry)
    return table.concat({
        EncodeNumber(entry.count),
        EncodeNumber(entry.unitPrice),
        entry.priced and "1" or "0",
        entry.link or "",
    }, SAVE_SEPARATOR)
end

local function DecodeSnapshotMaterial(entry)
    if type(entry) ~= "string" then
        return entry or {}
    end
    local count, unitPrice, priced, link = stringmatch(entry,
        "^([^" .. SAVE_SEPARATOR .. "]*)" .. SAVE_SEPARATOR
        .. "([^" .. SAVE_SEPARATOR .. "]*)" .. SAVE_SEPARATOR
        .. "([^" .. SAVE_SEPARATOR .. "]*)" .. SAVE_SEPARATOR .. "(.*)$")
    return {
        count = tonumber(count) or 0,
        unitPrice = tonumber(unitPrice) or 0,
        priced = priced == "1",
        link = link or "",
    }
end

local function EncodeVisitMaterial(entry)
    return EncodeNumber(entry.count) .. SAVE_SEPARATOR .. EncodeNumber(entry.unitPrice)
end

local function DecodeVisitMaterial(entry)
    if type(entry) ~= "string" then
        return entry or {}
    end
    local count, unitPrice = stringmatch(entry,
        "^([^" .. SAVE_SEPARATOR .. "]*)" .. SAVE_SEPARATOR .. "(.*)$")
    return { count = tonumber(count) or 0, unitPrice = tonumber(unitPrice) or 0 }
end

local function EncodePriceHistorySeries(points)
    local encoded = {}
    for index = 1, #points do
        local point = points[index]
        encoded[index] = table.concat({
            EncodeNumber(point.p),
            EncodeNumber(point.t),
            point.s or "",
        }, SAVE_SEPARATOR)
    end
    return table.concat(encoded, PRICE_POINT_SEPARATOR)
end

-- Decode both the current multi-point format ("p~t~source|...") and the legacy
-- single baseline ("p~t"). Table-shaped entries are accepted for one-time save
-- migration in CompactSavedVariables.
local function DecodePriceHistorySeries(entry)
    if type(entry) == "table" then
        if entry.p then
            return { { p = entry.p or 0, t = entry.t or 0, s = entry.s } }
        end
        return entry
    end
    if type(entry) ~= "string" or entry == "" then
        return {}
    end

    local points = {}
    for encodedPoint in stringgmatch(entry, "([^" .. PRICE_POINT_SEPARATOR .. "]+)") do
        local price, stamp, source = stringmatch(encodedPoint,
            "^([^" .. SAVE_SEPARATOR .. "]*)" .. SAVE_SEPARATOR
            .. "([^" .. SAVE_SEPARATOR .. "]*)" .. SAVE_SEPARATOR .. "(.*)$")
        if not price then
            price, stamp = stringmatch(encodedPoint,
                "^([^" .. SAVE_SEPARATOR .. "]*)" .. SAVE_SEPARATOR .. "(.*)$")
        end
        points[#points + 1] = {
            p = tonumber(price) or 0,
            t = tonumber(stamp) or 0,
            s = source ~= "" and source or nil,
        }
    end
    return points
end

local function LatestComparablePricePoint(points, source)
    local latest = points[#points]
    if not latest then
        return nil
    end
    if latest.s ~= source then
        return nil
    end
    return latest
end

local function PrunePriceHistoryPoints(points, now)
    local cutoff = now - PRICE_TREND_WINDOW_SECONDS
    local pointCount = #points
    local retainedCount = 0

    for index = 1, pointCount do
        local point = points[index]
        if index == pointCount or (point.t and point.t >= cutoff) then
            retainedCount = retainedCount + 1
            points[retainedCount] = point
        end
    end

    for index = retainedCount + 1, pointCount do
        points[index] = nil
    end
end

local function AppendPriceHistoryPoint(points, price, stamp, source)
    points[#points + 1] = { p = zo_round(price), t = stamp, s = source }
    while #points > PRICE_HISTORY_MAX_POINTS do
        table.remove(points, 1)
    end
end

local function EncodePriceTrendAlert(direction, magnitude, stamp)
    return table.concat({ direction, EncodeNumber(magnitude), EncodeNumber(stamp) }, SAVE_SEPARATOR)
end

local function DecodePriceTrendAlert(entry)
    if type(entry) == "table" then
        return entry
    end
    if type(entry) ~= "string" then
        return nil
    end
    local direction, magnitude, stamp = stringmatch(entry,
        "^([^" .. SAVE_SEPARATOR .. "]*)" .. SAVE_SEPARATOR
        .. "([^" .. SAVE_SEPARATOR .. "]*)" .. SAVE_SEPARATOR .. "(.*)$")
    if not direction then
        return nil
    end
    return { d = direction, m = tonumber(magnitude) or 0, t = tonumber(stamp) or 0 }
end

local function EncodeVisitDiffRow(row)
    return table.concat({
        EncodeNumber(row.itemId),
        EncodeNumber(row.countDelta),
        EncodeNumber(row.goldDelta),
        row.priced and "1" or "0",
        row.status or "",
        row.link or "",
    }, SAVE_SEPARATOR)
end

local function DecodeVisitDiffRow(row)
    if type(row) ~= "string" then
        return row or {}
    end
    local itemId, countDelta, goldDelta, priced, status, link = stringmatch(row,
        "^([^" .. SAVE_SEPARATOR .. "]*)" .. SAVE_SEPARATOR
        .. "([^" .. SAVE_SEPARATOR .. "]*)" .. SAVE_SEPARATOR
        .. "([^" .. SAVE_SEPARATOR .. "]*)" .. SAVE_SEPARATOR
        .. "([^" .. SAVE_SEPARATOR .. "]*)" .. SAVE_SEPARATOR
        .. "([^" .. SAVE_SEPARATOR .. "]*)" .. SAVE_SEPARATOR .. "(.*)$")
    return {
        itemId = tonumber(itemId) or 0,
        countDelta = tonumber(countDelta) or 0,
        goldDelta = tonumber(goldDelta) or 0,
        priced = priced == "1",
        status = status or "",
        link = link or "",
    }
end

local function CompressVisitBaseline(baseline)
    local compact = { gold = baseline.gold, items = baseline.items, materials = {} }
    for itemId, entry in pairs(baseline.materials or {}) do
        compact.materials[itemId] = EncodeVisitMaterial(entry)
    end
    return compact
end

local function CompressVisitDetails(details)
    if not details then
        return nil
    end
    local compact = {
        t = details.t,
        totalGold = details.totalGold,
        quantityGold = details.quantityGold,
        priceGold = details.priceGold,
        hasQuantityChange = details.hasQuantityChange,
        rows = {},
    }
    for index, row in ipairs(details.rows or {}) do
        compact.rows[index] = EncodeVisitDiffRow(row)
    end
    return compact
end

-- Migrate once in memory. ESO writes SavedVariables on logout/reload, so this
-- safely compacts existing saves without asking the user to delete anything.
local function CompactSavedVariables()
    local sv = private.savedVars
    if not sv then
        return
    end

    for itemId, entry in pairs(sv.priceHistory or {}) do
        if type(entry) == "table" then
            sv.priceHistory[itemId] = EncodePriceHistorySeries(DecodePriceHistorySeries(entry))
        end
    end

    local snapshot = sv.snapshot
    for itemId, entry in pairs(snapshot and snapshot.materials or {}) do
        if type(entry) == "table" then
            snapshot.materials[itemId] = EncodeSnapshotMaterial(entry)
        end
    end

    local baseline = sv.lastVisitBaseline
    if baseline and baseline.materials then
        for itemId, entry in pairs(baseline.materials) do
            if type(entry) == "table" then
                baseline.materials[itemId] = EncodeVisitMaterial(entry)
            end
        end
    end

    local details = sv.lastVisitDetails
    for index, row in ipairs(details and details.rows or {}) do
        if type(row) == "table" then
            details.rows[index] = EncodeVisitDiffRow(row)
        end
    end
end


local zo_ceil = zo_ceil

-- Number of classic 200-item stacks a raw item count occupies. 0 items -> 0
-- stacks; any partial stack rounds up to a whole one.
local function ItemsToStacks(items)
    if not items or items <= 0 then
        return 0
    end
    return zo_ceil(items / STACK_SIZE)
end

local LogDebug = private.LogDebug
local LogInfo = private.LogInfo
local ChatInfo = private.ChatInfo

local function GetNotificationMode()
    return private.GetNotificationMode and private.GetNotificationMode() or "summary"
end

-- LibPrice source keys (the second return of ItemLinkToPriceGold) mapped to
-- their labels. One row per source so the full name and the compact footer label
-- can never drift apart: `display` is the human-readable name (LibPrice ships no
-- such map, so we keep our own), `short` the tight label for the footer value
-- column where the full name would not fit. An unknown key falls back to the raw
-- string (display) or its upper-cased form (short) rather than erroring.
local SOURCE_INFO = {
    mm    = { display = "Master Merchant",       short = "MM" },
    att   = { display = "Arkadius' Trade Tools",  short = "ATT" },
    ttc   = { display = "Tamriel Trade Centre",   short = "TTC" },
    furc  = { display = "Furniture Catalogue",    short = "FurC" },
    crown = { display = "Crown Store",            short = "Crown" },
    rolis = { display = "Rolis Hlaalu",           short = "Rolis" },
    npc   = { display = "NPC Vendor",             short = "NPC" },
}

local function SourceDisplayName(sourceKey)
    if not sourceKey then
        return nil
    end
    local info = SOURCE_INFO[sourceKey]
    return (info and info.display) or sourceKey
end

local function SourceShortName(sourceKey)
    if not sourceKey then
        return nil
    end
    local info = SOURCE_INFO[sourceKey]
    return (info and info.short) or string.upper(sourceKey)
end

-- Public: resolve a LibPrice source key ("mm"/"ttc"/...) to its full display name
-- ("Master Merchant"/...). Exposed so the detail-row tooltip can name the price
-- source carried on each material row. Returns nil for a nil key.
function Valuation.GetSourceDisplayName(sourceKey)
    return SourceDisplayName(sourceKey)
end

-- Compact counterpart used by tight UI surfaces such as the summary footer and
-- the per-material source badge. Unknown LibPrice keys remain visible instead
-- of disappearing, using the same uppercase fallback as the footer aggregate.
function Valuation.GetSourceShortName(sourceKey)
    return SourceShortName(sourceKey)
end

-- Category model
-- ---------------------------------------------------------------------------
-- Categories mirror the crafting professions the craft bag is organized by.
-- The id is a stable string key; the nameKey is the localized display string.
-- Order here is the display order in the window. Anything that does not map to
-- a known crafting profession (style/trait/furnishing mats, etc.) lands in
-- "other".
local CATEGORY_DEFINITIONS = {
    { id = "blacksmithing", nameKey = SI_BMW_CATEGORY_BLACKSMITHING },
    { id = "clothier",      nameKey = SI_BMW_CATEGORY_CLOTHIER },
    { id = "woodworking",   nameKey = SI_BMW_CATEGORY_WOODWORKING },
    { id = "jewelry",       nameKey = SI_BMW_CATEGORY_JEWELRY },
    { id = "alchemy",       nameKey = SI_BMW_CATEGORY_ALCHEMY },
    { id = "enchanting",    nameKey = SI_BMW_CATEGORY_ENCHANTING },
    { id = "provisioning",  nameKey = SI_BMW_CATEGORY_PROVISIONING },
    { id = "other",         nameKey = SI_BMW_CATEGORY_OTHER },
}

-- ITEMTYPE -> category id map.
-- ---------------------------------------------------------------------------
-- Built once at load from the game's ITEMTYPE_* constants grouped by
-- profession. We map item types explicitly rather than calling a crafting-type
-- API because there is no global that returns "the item types for this
-- profession" in the live client. Each constant is referenced by name and
-- nil-guarded at build time (see BuildItemTypeMap), so a client build that
-- lacks one of these constants simply leaves that type unmapped -- it falls
-- back to "other" instead of erroring. Initialized empty (not nil) so a lookup
-- before BuildItemTypeMap() runs is a safe miss -> "other".
--
-- The grouping uses raw material + refined material + booster (tempers/tannins/
-- resins/plating) per equipment profession; reagents/solvents for alchemy;
-- runestones for enchanting; ingredients for provisioning. Style materials,
-- trait stones, and furnishing mats intentionally fall through to "other".
local CATEGORY_ITEM_TYPES = {
    blacksmithing = {
        "ITEMTYPE_BLACKSMITHING_RAW_MATERIAL",
        "ITEMTYPE_BLACKSMITHING_MATERIAL",
        "ITEMTYPE_BLACKSMITHING_BOOSTER",
    },
    clothier = {
        "ITEMTYPE_CLOTHIER_RAW_MATERIAL",
        "ITEMTYPE_CLOTHIER_MATERIAL",
        "ITEMTYPE_CLOTHIER_BOOSTER",
    },
    woodworking = {
        "ITEMTYPE_WOODWORKING_RAW_MATERIAL",
        "ITEMTYPE_WOODWORKING_MATERIAL",
        "ITEMTYPE_WOODWORKING_BOOSTER",
    },
    jewelry = {
        "ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL",
        "ITEMTYPE_JEWELRYCRAFTING_MATERIAL",
        "ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER",
        "ITEMTYPE_JEWELRYCRAFTING_BOOSTER",
    },
    alchemy = {
        "ITEMTYPE_REAGENT",
        "ITEMTYPE_POTION_BASE",
        "ITEMTYPE_POISON_BASE",
    },
    enchanting = {
        "ITEMTYPE_ENCHANTING_RUNE_ASPECT",
        "ITEMTYPE_ENCHANTING_RUNE_ESSENCE",
        "ITEMTYPE_ENCHANTING_RUNE_POTENCY",
    },
    provisioning = {
        "ITEMTYPE_INGREDIENT",
    },
}

-- Initialized empty so a category lookup is always safe even before the map is
-- built; BuildItemTypeMap() fills it on load.
local itemTypeToCategory = {}

local function BuildItemTypeMap()
    ZO_ClearTable(itemTypeToCategory)
    for categoryId, itemTypeNames in pairs(CATEGORY_ITEM_TYPES) do
        for i = 1, #itemTypeNames do
            -- Resolve the ITEMTYPE_* constant by name from the global table and
            -- skip it if this client build does not define it. This keeps a
            -- missing/renamed constant from erroring at load -- the type just
            -- stays unmapped and resolves to "other".
            local itemType = _G[itemTypeNames[i]]
            if itemType ~= nil then
                itemTypeToCategory[itemType] = categoryId
            end
        end
    end
end

local function ResolveCategory(itemLink)
    local itemType = GetItemLinkItemType(itemLink)
    return itemTypeToCategory[itemType] or "other"
end

-- Module state
-- ---------------------------------------------------------------------------
-- slotInfo caches each slot's last computed contribution (value, category,
-- stack size, priced flag) so a single-slot update can be applied
-- incrementally -- subtract the slot's old contribution from the aggregates,
-- recompute just that slot, add it back -- without rescanning the whole bag.
-- priceCache memoizes LibPrice per itemId so each distinct material costs at
-- most one (potentially expensive) LibPrice call per session. categoryStats
-- holds the running per-category aggregates the window reads; the grand* values
-- are the bag-wide rollup. This is the heart of the "no 5-10s freeze" design.
--
-- categoryStats[categoryId] = { gold, slots, items, unpricedSlots }
--   gold          summed market value of the category
--   slots         number of occupied craft-bag slots (== distinct materials)
--   items         summed slot sizes (e.g. one slot of 350000 = 350000 items)
--   unpricedSlots occupied slots with no available price
-- The classic 200-item stack count is NOT stored here; it is derived from
-- `items` via ItemsToStacks() at snapshot time so the two figures can never
-- drift out of sync.
local slotInfo = {}         -- [slotIndex] = { value, unitPrice, category, stack, priced, source, itemId, link }
local priceCache = {}       -- [itemId] = per-unit gold (false = known-unpriced)
local priceSource = {}      -- [itemId] = LibPrice source key ("mm"/"ttc"/...) when priced
-- Current material aggregates keyed by itemId. Craft Bag materials are normally
-- one slot each, but aggregating here preserves correctness if the API ever
-- exposes duplicates and gives the live visit delta an O(1) current-state read.
local currentMaterials = {} -- [itemId] = { count, value, pricedSlots, link }
-- Display name per itemId, resolved lazily and memoized. A material's name is
-- stable for its itemId, but GetItemLinkName + zo_strformat is not free, and the
-- detail window resolves it repeatedly (every Populate: a sort, a search
-- keystroke, a live refresh after a withdrawal). Caching it here turns those
-- rebuilds into arithmetic. Keyed by itemId, so one entry serves every slot and
-- both the row builders and the search filter.
local nameCache = {}        -- [itemId] = resolved display name
local categoryStats = {}    -- [categoryId] = { gold, slots, items, unpricedSlots }
local sourceCounts = {}     -- [sourceKey] = number of priced slots sourced from it

local grandGold = 0
local grandSlots = 0
local grandItems = 0
local grandUnpricedSlots = 0

-- Items that are present in the Craft Bag but have no market value by design.
-- Keep them out of both valuation and the "unpriced" coverage warning.
local EXCLUDED_FROM_VALUATION = {
    [71668] = true, -- Chameleon Crown Gem: cannot be sold
}

-- Footer delta is established on bag open and then maintained live against the
-- last acknowledged state as material quantities change.
-- Opening the Craft Bag never consumes it: material changes are acknowledged
-- only when the user opens the footer breakdown.
-- Two baselines feed it depending on the user's deltaMode setting:
--   "visit"   -- baseline persists in savedVars so it survives a restart.
--   "session" -- baseline lives in memory and resets on /reloadui or logout.
-- In both modes the gold delta is gated on the item count changing, so a pure
-- price drift (restart + price reimport, same stock) reports no delta.
local deltaSinceLastVisit = nil
-- Composition changed since the acknowledged baseline. Tracked separately from
-- deltaSinceLastVisit because an even trade (200 of one material out, 200 of an
-- equally-priced one in) yields a gold delta of exactly zero while still being a
-- real, reviewable change. Gating the footer row on the gold delta alone made
-- those changes unacknowledgeable, so the baseline could never advance past them.
local visitChangePending = false
local sessionBaseGold = nil   -- session-mode acknowledged baseline gold
local sessionBaseline = nil   -- session-mode acknowledged material baseline
local acknowledgedVisitDetails = nil -- retained while the acknowledged detail view is open
local visitNotified = false   -- emitted the first-session chat line yet this session?
local visitFinalizePending = false  -- an open is waiting to finalize its delta/history once prices settle
-- Forward-declared: StartPriceRetry (defined above FinalizeVisit) calls it from
-- its timer callback once the last unpriced slot heals or the budget is spent.
local FinalizeVisit
local UpdatePriceHistoryBaselines
local NotifySignificantPriceTrends
local CompleteManualPriceRefresh

local lastInventoryUpdateMs = nil  -- GetGameTimeMilliseconds() of the last inventory valuation
local lastPriceRefreshMs = nil     -- GetGameTimeMilliseconds() of the last LibPrice lookup
local manualPriceRefreshPending = false
local manualPriceRefreshCompletedMs = nil
local priceHistoryUpdatePending = false
local priceLookupItemIds = {}      -- itemIds queried from LibPrice in the current pass
local valueHistoryRecordedThisSession = false
local priceHistoryWrittenThisSession = {} -- [itemId] = true after this session's point exists
-- Seven-day analysis does not depend on stack-size changes. Window.Update
-- reuses this summary until bag composition, prices, history, or the threshold
-- actually change; a deposit of an already-held material must not re-walk
-- every earlier/later price pair. The material list itself is rebuilt on demand
-- so an open trend view still shows live quantities.
local PRICE_TREND_SUMMARY_MAX_AGE_SECONDS = 10 * 60
local priceTrendSummaryCache = {
    threshold = nil,
    computedAt = 0,
    gains = 0,
    losses = 0,
    total = 0,
}

local function InvalidatePriceTrendCache()
    priceTrendSummaryCache.threshold = nil
    priceTrendSummaryCache.computedAt = 0
end

local function StorePriceTrendSummary(threshold, materials)
    local gains, losses = 0, 0
    for index = 1, #materials do
        if (materials[index].trendStrongestPercent or 0) >= 0 then
            gains = gains + 1
        else
            losses = losses + 1
        end
    end
    priceTrendSummaryCache.threshold = threshold
    priceTrendSummaryCache.computedAt = GetTimeStamp()
    priceTrendSummaryCache.gains = gains
    priceTrendSummaryCache.losses = losses
    priceTrendSummaryCache.total = #materials
end

local isDirty = true        -- valuation may be stale; rescan on next show
local isBagVisible = false

-- Incremental slot applies accumulate floating-point error in grandGold (each
-- one is a subtract-then-add of a price * stack product) and can only ever
-- approximate the true total. Count them and force one full rebuild every
-- INCREMENTAL_DRIFT_LIMIT applies so a long session of withdrawals cannot let
-- the displayed total wander away from the bag. The limit is high enough that
-- normal play never pays for it twice in a row.
local INCREMENTAL_DRIFT_LIMIT = 250
local incrementalApplies = 0

-- Record the settled total once per UI session; no-op before SavedVariables exist.
local function RecordValuePoint()
    if valueHistoryRecordedThisSession then
        return
    end

    local sv = private.savedVars
    if not sv then
        return
    end

    local hist = sv.valueHistory
    if not hist or type(hist) ~= "table" then
        hist = { head = 0, entries = {} }
        sv.valueHistory = hist
    end
    -- An older save (or a partially-defaulted table) may lack either field.
    hist.entries = hist.entries or {}
    hist.head = hist.head or 0
    -- A save written when the capacity was larger can carry an out-of-range
    -- head; clamping here keeps every downstream modulus walk in bounds.
    if type(hist.head) ~= "number" or hist.head < 0 or hist.head > VALUE_HISTORY_CAPACITY then
        hist.head = 0
    end

    local nextHead = (hist.head % VALUE_HISTORY_CAPACITY) + 1
    hist.entries[nextHead] = { t = GetTimeStamp(), gold = grandGold, items = grandItems }
    hist.head = nextHead
    valueHistoryRecordedThisSession = true
end

-- Capture the stock baseline used by visit/session reports, separate from the
-- comparison snapshot. It advances on acknowledgement, not every bag open.
local function CaptureVisitBaseline()
    local materials = {}
    for itemId, current in pairs(currentMaterials) do
        materials[itemId] = {
            link = current.link,
            count = current.count,
            unitPrice = current.count > 0 and (current.value / current.count) or 0,
            priced = current.pricedSlots > 0,
        }
    end

    return { gold = grandGold, items = grandItems, materials = materials }
end

-- Split a total value change into two exact, additive effects:
--   quantity: the stock change valued at the previous visit's unit price;
--   prices:   the remaining revaluation of the materials still held now.
-- The rows deliberately contain only quantity changes, so the existing diff
-- table remains useful for answering "what did I add or spend?" while the
-- price figure is shown separately in the visit-delta tooltip.
local function BuildVisitDeltaDetails(baseline)
    if not baseline then
        return nil
    end

    local current = CaptureVisitBaseline()
    local oldMaterials = baseline.materials or {}
    local rows = {}
    local quantityGold, priceGold = 0, 0
    local hasQuantityChange = false

    for itemId, cur in pairs(current.materials) do
        local storedOld = oldMaterials[itemId]
        local old = storedOld and DecodeVisitMaterial(storedOld) or nil
        if not old then
            local quantityDelta = cur.count * cur.unitPrice
            quantityGold = quantityGold + quantityDelta
            hasQuantityChange = true
            rows[#rows + 1] = {
                itemId = itemId,
                link = cur.link,
                countDelta = cur.count,
                goldDelta = quantityDelta,
                priced = cur.priced,
                status = "new",
            }
        else
            local countDelta = cur.count - old.count
            local quantityDelta = countDelta * (old.unitPrice or 0)
            local revaluation = (cur.unitPrice - (old.unitPrice or 0)) * cur.count
            quantityGold = quantityGold + quantityDelta
            priceGold = priceGold + revaluation
            if countDelta ~= 0 then
                hasQuantityChange = true
                rows[#rows + 1] = {
                    itemId = itemId,
                    link = old.link or cur.link,
                    countDelta = countDelta,
                    goldDelta = quantityDelta,
                    priced = cur.priced or old.priced,
                    status = countDelta > 0 and "added" or "reduced",
                }
            end
        end
    end

    for itemId, storedOld in pairs(oldMaterials) do
        local old = DecodeVisitMaterial(storedOld)
        if not current.materials[itemId] then
            local quantityDelta = -old.count * (old.unitPrice or 0)
            quantityGold = quantityGold + quantityDelta
            hasQuantityChange = true
            rows[#rows + 1] = {
                itemId = itemId,
                link = old.link,
                countDelta = -old.count,
                goldDelta = quantityDelta,
                priced = old.priced,
                status = "gone",
            }
        end
    end

    return {
        t = GetTimeStamp(),
        totalGold = current.gold - (baseline.gold or 0),
        quantityGold = quantityGold,
        priceGold = priceGold,
        rows = rows,
        hasQuantityChange = hasQuantityChange,
    }, current
end

-- Recompute the unacknowledged footer delta after a live inventory change.
-- FinalizeVisit establishes/migrates the baseline once per bag open; this path
-- only compares against an already-established baseline so category totals and
-- the "since last review" row move together while the Craft Bag stays open.
local function RefreshLiveVisitDelta(changedItemIds)
    local sv = private.savedVars
    if not sv then
        deltaSinceLastVisit = nil
        visitChangePending = false
        return
    end

    local mode = sv.deltaMode or "visit"
    local baseline = mode == "session" and sessionBaseline or sv.lastVisitBaseline
    local baselineGold = mode == "session" and sessionBaseGold or sv.lastVisitGold
    if baselineGold == nil or not baseline or not baseline.materials then
        return
    end

    if changedItemIds then
        local existing = sv.lastVisitDetails
        local existingRows = existing and existing.rows or {}
        local rowsByItemId = {}
        for index = 1, #existingRows do
            local row = DecodeVisitDiffRow(existingRows[index])
            rowsByItemId[row.itemId] = row
        end

        for itemId in pairs(changedItemIds) do
            local current = currentMaterials[itemId]
            local storedOld = baseline.materials[itemId]
            local old = storedOld and DecodeVisitMaterial(storedOld) or nil
            local row = nil

            if current and not old then
                row = {
                    itemId = itemId,
                    link = current.link,
                    countDelta = current.count,
                    goldDelta = current.value,
                    priced = current.pricedSlots > 0,
                    status = "new",
                }
            elseif current and old then
                local countDelta = current.count - old.count
                if countDelta ~= 0 then
                    row = {
                        itemId = itemId,
                        link = current.link,
                        countDelta = countDelta,
                        goldDelta = countDelta * (old.unitPrice or 0),
                        priced = current.pricedSlots > 0,
                        status = countDelta > 0 and "added" or "reduced",
                    }
                end
            elseif old then
                row = {
                    itemId = itemId,
                    link = rowsByItemId[itemId] and rowsByItemId[itemId].link
                        or changedItemIds[itemId] or "",
                    countDelta = -old.count,
                    goldDelta = -old.count * (old.unitPrice or 0),
                    priced = (old.unitPrice or 0) > 0,
                    status = "gone",
                }
            end

            rowsByItemId[itemId] = row
        end

        local rows = {}
        local quantityGold = 0
        for _, row in pairs(rowsByItemId) do
            rows[#rows + 1] = row
            quantityGold = quantityGold + row.goldDelta
        end

        if #rows > 0 then
            local totalGold = grandGold - baselineGold
            deltaSinceLastVisit = totalGold
            visitChangePending = true
            sv.lastVisitDetails = CompressVisitDetails({
                t = GetTimeStamp(),
                totalGold = totalGold,
                quantityGold = quantityGold,
                priceGold = totalGold - quantityGold,
                rows = rows,
                hasQuantityChange = true,
            })
        else
            deltaSinceLastVisit = nil
            visitChangePending = false
            sv.lastVisitDetails = nil
        end
        return
    end

    local details = BuildVisitDeltaDetails(baseline)
    if details and details.hasQuantityChange then
        deltaSinceLastVisit = grandGold - baselineGold
        visitChangePending = true
        sv.lastVisitDetails = CompressVisitDetails(details)
    else
        deltaSinceLastVisit = nil
        visitChangePending = false
        sv.lastVisitDetails = nil
    end
end


-- Coalesced refresh: a burst of slot updates (e.g. dumping a 200-item stack,
-- which fires per-slot events) should yield ONE window refresh, not one per
-- event. Mirrors the throttled-save pattern in BAV's QueueSave.
local REFRESH_DELAY_MS = 100
local refreshQueued = false
local REFRESH_TIMER_NAME = addon.name .. "_QueuedRefresh"
local fullUpdateRescanPending = false
local fullUpdateEventCount = 0
local fullUpdateVisibleEventCount = 0
local fullUpdateRescanCount = 0
local visitDeltaChangedItemIds = {}
local visitDeltaFullRefreshPending = false

-- Unpriced-slot self-heal
-- ---------------------------------------------------------------------------
-- A price source (Master Merchant / TTC / ATT) often finishes importing its data
-- a minute or two AFTER login, so the first scan of a freshly-opened bag can mark
-- materials unpriced that will have a price shortly. The cache stores that verdict
-- as false and never re-queries it within a session (by design -- see
-- GetUnitPrice), so without this the panel would keep showing "unpriced" until the
-- user manually hit /bmw refresh. Instead, while the bag is open and something is
-- unpriced, a slow timer re-queries just the unpriced slots and folds any
-- newly-available prices into the aggregates. It runs once after a short delay,
-- then keeps the negative cache verdict for the rest of the UI session.
local PRICE_RETRY_INTERVAL_MS  = 15000  -- one delayed re-query after startup imports settle
local PRICE_RETRY_TIMER_NAME   = addon.name .. "_PriceRetry"
local priceRetryQueued = false
local priceRetryAttempted = false

local function GetOrCreateCategoryStat(categoryId)
    local stat = categoryStats[categoryId]
    if not stat then
        stat = { gold = 0, slots = 0, items = 0, unpricedSlots = 0 }
        categoryStats[categoryId] = stat
    end
    return stat
end

-- Per-unit price for an itemId, memoized. Returns the per-unit gold (or 0 when
-- no source has data), a priced flag, and the LibPrice source key the price came
-- from ("mm"/"ttc"/"att"/...) or nil when unpriced. We cache the "unpriced"
-- verdict as false so a missing price is not re-queried on every rescan within a
-- session; the source key is memoized alongside it.
local function GetUnitPrice(itemId, itemLink)
    local cached = priceCache[itemId]
    if cached ~= nil then
        return cached or 0, cached ~= false, priceSource[itemId]
    end

    priceHistoryUpdatePending = true
    priceLookupItemIds[itemId] = true
    lastPriceRefreshMs = GetGameTimeMilliseconds()
    local gold, sourceKey = LibPrice.ItemLinkToPriceGold(itemLink)
    if gold and gold > 0 then
        priceCache[itemId] = gold
        priceSource[itemId] = sourceKey
        return gold, true, sourceKey
    end

    priceCache[itemId] = false
    priceSource[itemId] = nil
    return 0, false, nil
end

-- Resolved display name for an itemId, memoized. The name is stable per itemId,
-- so this is resolved once (GetItemLinkName + the game's title-casing via
-- zo_strformat) and reused across the detail window's many rebuilds -- a sort, a
-- search keystroke, or a live refresh no longer re-resolve every row. The link is
-- the language-independent source of truth, so a stale name never survives a
-- game-language change within a session (the cache lives only for the session).
--
-- Deliberately NOT named GetDisplayName: ESO defines a global GetDisplayName()
-- that returns the player's "@account" handle, and a local of the same name
-- shadows it for the rest of the file. Nothing here needs the account handle
-- today, but the collision made the two impossible to tell apart at a glance.
local function GetMaterialDisplayName(itemId, itemLink)
    local cached = nameCache[itemId]
    if cached ~= nil then
        return cached
    end
    -- GetItemLinkName returns the raw, often lower-case name; zo_strformat title-
    -- cases and cleans it the way the game shows it (see BuildMaterialRow).
    local name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(itemLink))
    nameCache[itemId] = name
    return name
end

-- Compute a single slot's contribution WITHOUT touching the running aggregates.
-- Returns an info record { value, category, stack, priced, source } for an
-- occupied slot, or nil for an empty/unknown slot. Empty virtual slots (the
-- craft bag keeps slots around after a material is fully removed) have stack
-- size 0 and contribute nothing -- this is the GetItemId/stack guard the user
-- called out.
local function ComputeSlot(slotIndex)
    local stack = GetSlotStackSize(BAG, slotIndex)
    if not stack or stack <= 0 then
        return nil
    end

    local itemId = GetItemId(BAG, slotIndex)
    if not itemId or itemId <= 0 then
        return nil
    end

    if EXCLUDED_FROM_VALUATION[itemId] then
        return nil
    end

    local itemLink = GetItemLink(BAG, slotIndex)
    local unitPrice, wasPriced, sourceKey = GetUnitPrice(itemId, itemLink)
    return {
        value = unitPrice * stack,
        unitPrice = unitPrice,
        category = ResolveCategory(itemLink),
        stack = stack,
        priced = wasPriced,
        source = sourceKey,
        itemId = itemId,
        link = itemLink,
    }
end

-- Remove a slot's previously-cached contribution from the aggregates. Safe to
-- call for a slot we have never seen (no-op).
local function RemoveSlotFromAggregates(slotIndex)
    local info = slotInfo[slotIndex]
    if info == nil then
        return
    end

    local stat = categoryStats[info.category]
    if stat then
        stat.gold = stat.gold - info.value
        stat.slots = stat.slots - 1
        stat.items = stat.items - info.stack
        if not info.priced then
            -- Clamp at zero: a slot whose `priced` verdict flipped between the
            -- add and this remove would otherwise drive the counter negative
            -- and make the footer report a nonsense unpriced count.
            stat.unpricedSlots = stat.unpricedSlots > 0 and (stat.unpricedSlots - 1) or 0
        end
        if stat.slots <= 0 then
            categoryStats[info.category] = nil
        end
    end

    grandGold = grandGold - info.value
    grandSlots = grandSlots > 0 and (grandSlots - 1) or 0
    grandItems = grandItems > 0 and (grandItems - info.stack) or 0
    if grandItems < 0 then
        grandItems = 0
    end
    if not info.priced then
        grandUnpricedSlots = grandUnpricedSlots > 0 and (grandUnpricedSlots - 1) or 0
    end

    -- Drop this slot from the per-source tally so the footer's "Prices: X"
    -- reflects only currently-occupied priced slots.
    if info.source then
        local count = sourceCounts[info.source]
        if count then
            count = count - 1
            sourceCounts[info.source] = count > 0 and count or nil
        end
    end

    local current = currentMaterials[info.itemId]
    if current then
        current.count = current.count - info.stack
        current.value = current.value - info.value
        if info.priced then
            current.pricedSlots = current.pricedSlots - 1
        end
        if current.count <= 0 then
            currentMaterials[info.itemId] = nil
        end
    end

    slotInfo[slotIndex] = nil
end

-- Add a freshly-computed slot contribution into the aggregates and cache it.
local function AddSlotToAggregates(slotIndex, info)
    if info == nil then
        -- Empty/unknown slot: nothing cached, nothing added.
        return
    end

    slotInfo[slotIndex] = info

    local stat = GetOrCreateCategoryStat(info.category)
    stat.gold = stat.gold + info.value
    stat.slots = stat.slots + 1
    stat.items = stat.items + info.stack
    if not info.priced then
        stat.unpricedSlots = stat.unpricedSlots + 1
    end

    grandGold = grandGold + info.value
    grandSlots = grandSlots + 1
    grandItems = grandItems + info.stack
    if not info.priced then
        grandUnpricedSlots = grandUnpricedSlots + 1
    end

    if info.source then
        sourceCounts[info.source] = (sourceCounts[info.source] or 0) + 1
    end

    local current = currentMaterials[info.itemId]
    if not current then
        current = { count = 0, value = 0, pricedSlots = 0, link = info.link }
        currentMaterials[info.itemId] = current
    end
    current.count = current.count + info.stack
    current.value = current.value + info.value
    current.pricedSlots = current.pricedSlots + (info.priced and 1 or 0)
    current.link = info.link or current.link
end

local function ResetAggregates()
    ZO_ClearTable(slotInfo)
    ZO_ClearTable(categoryStats)
    ZO_ClearTable(sourceCounts)
    ZO_ClearTable(currentMaterials)
    grandGold = 0
    grandSlots = 0
    grandItems = 0
    grandUnpricedSlots = 0
end

-- Full single-pass scan of the craft bag, rebuilding every aggregate from the
-- (memoized) price cache. This is the only O(slots) operation. It runs on a
-- dirty bag open, an explicit refresh, or once for a coalesced burst of full
-- inventory updates while the bag is visible.
local function FullRescan()
    ResetAggregates()

    local slotIndex = ZO_GetNextBagSlotIndex(BAG)
    local scanned = 0
    while slotIndex do
        AddSlotToAggregates(slotIndex, ComputeSlot(slotIndex))
        scanned = scanned + 1
        slotIndex = ZO_GetNextBagSlotIndex(BAG, slotIndex)
    end

    lastInventoryUpdateMs = GetGameTimeMilliseconds()
    isDirty = false
    -- Totals are exact again, so the incremental drift budget starts over.
    incrementalApplies = 0
    InvalidatePriceTrendCache()
    UpdatePriceHistoryBaselines()
    if NotifySignificantPriceTrends then
        NotifySignificantPriceTrends()
    end
    LogInfo(SI_BMW_LOG_RESCAN_DONE, scanned, private.FormatGold(grandGold))
end

local function RefreshWindow()
    local window = addon.Window
    if window and isBagVisible then
        window.Update()
    end

    -- A withdrawal shrinks the craft-bag stack, so the open detail table would
    -- otherwise show stale Qty/Value. Refresh it too; it is a no-op when the
    -- detail window is hidden, and rides the same coalescing as the panel.
    local detail = addon.DetailWindow
    if detail and detail.Refresh then
        detail.Refresh()
    end

    -- The queue keeps craft-bag slot references, so reconcile its visible rows
    -- after inventory changes as well. This is a no-op while it is hidden.
    local withdrawDialog = addon.WithdrawDialog
    if withdrawDialog and withdrawDialog.Refresh then
        withdrawDialog.Refresh()
    end
end

CompleteManualPriceRefresh = function()
    if not manualPriceRefreshPending then
        return false
    end

    manualPriceRefreshPending = false
    manualPriceRefreshCompletedMs = GetGameTimeMilliseconds()
    return true
end

-- Collapse a burst of slot updates into a single window refresh.
local function QueueWindowRefresh()
    if refreshQueued then
        return
    end
    refreshQueued = true
    EVENT_MANAGER:RegisterForUpdate(REFRESH_TIMER_NAME, REFRESH_DELAY_MS, function()
        EVENT_MANAGER:UnregisterForUpdate(REFRESH_TIMER_NAME)
        refreshQueued = false

        if fullUpdateRescanPending then
            fullUpdateRescanPending = false
            if isBagVisible and isDirty then
                FullRescan()
                fullUpdateRescanCount = fullUpdateRescanCount + 1
            end
        elseif isBagVisible and incrementalApplies >= INCREMENTAL_DRIFT_LIMIT then
            -- Enough incremental applies have stacked up that accumulated
            -- floating-point error could be visible; rebuild from scratch once
            -- (this resets the counter) before the refresh below renders.
            FullRescan()
        end

        if visitDeltaFullRefreshPending then
            RefreshLiveVisitDelta()
        else
            RefreshLiveVisitDelta(visitDeltaChangedItemIds)
        end
        ZO_ClearTable(visitDeltaChangedItemIds)
        visitDeltaFullRefreshPending = false
        RefreshWindow()
    end)
end

-- Re-price the currently-unpriced slots and fold any now-available prices into
-- the aggregates. Walks slotInfo (cheap: it is the occupied slots, not the whole
-- bag), and for each slot still flagged unpriced drops its cached "false" verdict
-- so GetUnitPrice re-queries LibPrice, then re-applies the slot incrementally
-- (remove old contribution, recompute, add back) exactly like a single-slot
-- update. Returns how many slots became priced this pass, so the caller can tell
-- whether the retry made progress. Touches nothing when nothing is unpriced.
local function RepriceUnpricedSlots()
    if grandUnpricedSlots <= 0 then
        return 0
    end

    -- Collect first, then mutate: RemoveSlotFromAggregates rewrites slotInfo, so
    -- iterating it while editing would be unsafe.
    local stale = {}
    for slotIndex, info in pairs(slotInfo) do
        if not info.priced then
            stale[#stale + 1] = { slotIndex = slotIndex, itemId = info.itemId }
        end
    end

    local healed = 0
    for i = 1, #stale do
        -- Drop the memoized "unpriced" verdict so ComputeSlot re-queries LibPrice.
        priceCache[stale[i].itemId] = nil
        RemoveSlotFromAggregates(stale[i].slotIndex)
        local info = ComputeSlot(stale[i].slotIndex)
        AddSlotToAggregates(stale[i].slotIndex, info)
        if info and info.priced then
            healed = healed + 1
        elseif info == nil then
            -- The slot emptied between the collect pass and now (a withdrawal
            -- landed mid-retry). Its contribution is already removed, but the
            -- bag no longer matches what we last scanned, so mark the valuation
            -- stale instead of leaving the panel on a silently-short total.
            isDirty = true
        end
    end

    if healed > 0 then
        lastInventoryUpdateMs = GetGameTimeMilliseconds()
    end
    UpdatePriceHistoryBaselines()
    return healed
end

-- Stop the one-shot unpriced-slot retry timer. Safe to call when none is armed.
local function StopPriceRetry()
    EVENT_MANAGER:UnregisterForUpdate(PRICE_RETRY_TIMER_NAME)
    priceRetryQueued = false
end

-- Arm the slow retry that heals prices which imported after the first scan (see
-- the PRICE_RETRY_* note above). No-op when everything is already priced, when a
-- retry is already armed, or when the bag is not visible (we do no work with the
-- bag closed). The callback unregisters itself before doing one re-query pass.
local function StartPriceRetry()
    if priceRetryQueued or priceRetryAttempted
        or grandUnpricedSlots <= 0 or not isBagVisible then
        return false
    end
    priceRetryQueued = true

    EVENT_MANAGER:RegisterForUpdate(PRICE_RETRY_TIMER_NAME, PRICE_RETRY_INTERVAL_MS, function()
        StopPriceRetry()
        priceRetryAttempted = true

        local healed = RepriceUnpricedSlots()
        if healed > 0 then
            RefreshLiveVisitDelta()
        end

        if grandUnpricedSlots <= 0 and healed > 0
            and GetNotificationMode() == "detailed" then
            ChatInfo(SI_BMW_MSG_PRICES_RECOVERED, healed)
        end

        -- The only retry has completed: capture the visit baseline and history
        -- point against this settled result. No-op if already finalized.
        FinalizeVisit(true)
        local manualRefreshCompleted = CompleteManualPriceRefresh()
        if healed > 0 or manualRefreshCompleted then
            RefreshWindow()
        end
    end)
    return true
end

-- EVENT_INVENTORY_SINGLE_SLOT_UPDATE handler (filtered to BAG_VIRTUAL).
-- ---------------------------------------------------------------------------
-- While the bag is closed we do NO work beyond marking the valuation dirty, so
-- background deposits never cost a scan. While the bag is open we update only
-- the one changed slot (O(1) on the aggregates) and coalesce the window
-- refresh. A genuine full inventory update falls back to a dirty flag + rescan.
local function OnSingleSlotUpdate(eventCode, bagId, slotIndex, isNewItem, soundCat, updateReason, stackCountChange)
    if bagId ~= BAG then
        return
    end

    if not isBagVisible then
        isDirty = true
        return
    end

    local oldInfo = slotInfo[slotIndex]
    local oldItemId = oldInfo and oldInfo.itemId or nil
    local newStack = GetSlotStackSize(BAG, slotIndex) or 0
    local newItemId = newStack > 0 and GetItemId(BAG, slotIndex) or nil
    local info

    if oldInfo and newItemId == oldItemId and newStack > 0 then
        local stackDelta = newStack - oldInfo.stack
        local valueDelta = stackDelta * oldInfo.unitPrice
        oldInfo.stack = newStack
        oldInfo.value = oldInfo.value + valueDelta
        info = oldInfo

        local stat = categoryStats[oldInfo.category]
        stat.items = stat.items + stackDelta
        stat.gold = stat.gold + valueDelta
        grandItems = grandItems + stackDelta
        grandGold = grandGold + valueDelta

        local current = currentMaterials[oldItemId]
        current.count = current.count + stackDelta
        current.value = current.value + valueDelta
    else
        RemoveSlotFromAggregates(slotIndex)
        info = ComputeSlot(slotIndex)
        AddSlotToAggregates(slotIndex, info)
        -- A new, removed, or swapped material can add or drop a trend signal.
        -- Quantity-only updates of an already-held material do not.
        InvalidatePriceTrendCache()
    end

    if oldItemId then
        visitDeltaChangedItemIds[oldItemId] = oldInfo.link or ""
    end
    if info then
        visitDeltaChangedItemIds[info.itemId] = info.link or ""
    end
    incrementalApplies = incrementalApplies + 1
    lastInventoryUpdateMs = GetGameTimeMilliseconds()
    UpdatePriceHistoryBaselines()
    LogDebug(SI_BMW_LOG_SLOT_UPDATED, slotIndex, private.FormatGold(info and info.value or 0))

    QueueWindowRefresh()
end

-- EVENT_INVENTORY_FULL_UPDATE carries no bagId (unlike the single-slot event),
-- so there is nothing to filter on here; a full update is not bag-scoped. Mark
-- the valuation dirty and coalesce a burst into one rescan through the existing
-- refresh timer. While the bag is closed, defer all work until the next open.
local function OnFullInventoryUpdate()
    fullUpdateEventCount = fullUpdateEventCount + 1

    if not isBagVisible then
        isDirty = true
        return
    end

    fullUpdateVisibleEventCount = fullUpdateVisibleEventCount + 1
    isDirty = true
    fullUpdateRescanPending = true
    visitDeltaFullRefreshPending = true
    QueueWindowRefresh()
end

-- Public API ----------------------------------------------------------------

function Valuation.Initialize()
    BuildItemTypeMap()

    -- Compact legacy table-shaped entries before normal reads/writes begin.
    CompactSavedVariables()

    -- Drop stale price-history baselines accumulated across past sessions.
    Valuation.PrunePriceHistory()

    -- Single-slot updates are the common case (deposit/withdraw one material);
    -- filter to the craft bag so we are never woken by backpack/bank churn.
    EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnSingleSlotUpdate)
    EVENT_MANAGER:AddFilterForEvent(addon.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_BAG_ID, BAG)

    -- A full update (e.g. first login population) can't be filtered the same
    -- way; the handler guards on bagId itself.
    EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_INVENTORY_FULL_UPDATE, OnFullInventoryUpdate)
end

-- Finalize once per bag open after prices settle, or on hide as a fallback.
-- Update the stock report, applicable notifications, and session value sample.
-- Only the settled-price path may create the one-time automatic snapshot.
function FinalizeVisit(pricesReadyForSnapshot)
    if not visitFinalizePending then
        return
    end
    visitFinalizePending = false

    local sv = private.savedVars
    local comparisonGold = nil
    local visitDetails, currentBaseline

    -- A snapshot captured during LibPrice's startup import can permanently save
    -- removed materials at zero value. Only create the automatic baseline after
    -- the retry completes; an early bag close leaves it pending for a later open.
    if pricesReadyForSnapshot and sv and not sv.autoSnapshotDone
        and not Valuation.HasSnapshot() and grandSlots > 0 then
        sv.autoSnapshotDone = true
        Valuation.CaptureSnapshot()
    end

    -- Compute the delta once per open so incremental updates during the visit do
    -- not move it under the user. The baseline is retained until the user clicks
    -- the footer row, so changes accumulate across bag opens. A pure price drift
    -- with unchanged stock remains hidden rather than reading as a material change.
    local mode = (sv and sv.deltaMode) or "visit"
    -- True only when this call actually compared the bag against an existing
    -- baseline. When no baseline existed there is nothing to conclude about a
    -- previously-stored breakdown, so it must be left alone rather than cleared.
    local comparedAgainstBaseline = false

    if mode == "session" then
        -- Establish the session baseline quietly on first open, then retain it
        -- until manual inspection acknowledges the accumulated changes.
        comparisonGold = sessionBaseGold
        if sessionBaseGold ~= nil and sessionBaseline then
            comparedAgainstBaseline = true
            visitDetails = BuildVisitDeltaDetails(sessionBaseline)
            if visitDetails and visitDetails.hasQuantityChange then
                deltaSinceLastVisit = grandGold - sessionBaseGold
                visitChangePending = true
            else
                deltaSinceLastVisit = nil
                visitChangePending = false
            end
        else
            deltaSinceLastVisit = nil
            visitChangePending = false
        end
        if sessionBaseGold == nil then
            sessionBaseGold = grandGold
            sessionBaseline = CaptureVisitBaseline()
        end
    elseif sv then
        -- Visit mode persists its baseline across restarts. The first open only
        -- establishes it; later opens compare against it until manual review.
        local previousGold = sv.lastVisitGold
        comparisonGold = previousGold
        local previousItems = sv.lastVisitItems
        local previousBaseline = sv.lastVisitBaseline
        if previousGold ~= nil and previousBaseline and previousBaseline.materials then
            comparedAgainstBaseline = true
            visitDetails, currentBaseline = BuildVisitDeltaDetails(previousBaseline)
            if visitDetails and visitDetails.hasQuantityChange then
                deltaSinceLastVisit = grandGold - previousGold
                visitChangePending = true
            else
                deltaSinceLastVisit = nil
                visitChangePending = false
            end
        elseif previousGold ~= nil and previousItems ~= nil and previousItems ~= grandItems then
            -- Older saves may have aggregate totals but no material baseline.
            -- Preserve their previous behavior for one visit, then replace it
            -- below with the composition-aware baseline format.
            comparedAgainstBaseline = true
            deltaSinceLastVisit = grandGold - previousGold
            visitChangePending = true
        else
            deltaSinceLastVisit = nil
            visitChangePending = false
        end
        if previousGold == nil or not previousBaseline or not previousBaseline.materials then
            sv.lastVisitGold = grandGold
            sv.lastVisitItems = grandItems
            sv.lastVisitBaseline = CompressVisitBaseline(currentBaseline or CaptureVisitBaseline())
        end
    else
        deltaSinceLastVisit = nil
        visitChangePending = false
    end

    if sv then
        -- Keep the unacknowledged breakdown across restarts so merely opening the
        -- Craft Bag never loses a change awaiting manual review. Only overwrite a
        -- stored breakdown when this visit produced one, or when a real comparison
        -- concluded nothing is pending. Writing an unconditional nil here used to
        -- wipe an unacknowledged report: switching deltaMode makes the first open
        -- in the new mode establish a fresh baseline without computing details,
        -- which silently discarded the breakdown accumulated under the old mode.
        if visitDetails then
            sv.lastVisitDetails = CompressVisitDetails(visitDetails)
        elseif comparedAgainstBaseline and not visitChangePending then
            sv.lastVisitDetails = nil
        end
    end

    -- Summary/detailed modes retain the first-open session digest. Important
    -- mode instead reports each real change that reaches one percent of the
    -- selected baseline, avoiding noise from ordinary small movements.
    local notificationMode = GetNotificationMode()
    if (notificationMode == "summary" or notificationMode == "detailed") and not visitNotified then
        visitNotified = true
        local total = private.FormatGold(grandGold)
        if deltaSinceLastVisit and deltaSinceLastVisit ~= 0 then
            local sign = deltaSinceLastVisit > 0 and "+" or "-"
            local magnitude = sign .. private.FormatGold(mathabs(deltaSinceLastVisit))
            ChatInfo(SI_BMW_MSG_VISIT_DELTA, total, magnitude)
        else
            ChatInfo(SI_BMW_MSG_VISIT_TOTAL, total)
        end
    elseif notificationMode == "important" and deltaSinceLastVisit and comparisonGold
        and comparisonGold > 0 and mathabs(deltaSinceLastVisit) >= comparisonGold * 0.01 then
        local sign = deltaSinceLastVisit > 0 and "+" or "-"
        local magnitude = sign .. private.FormatGold(mathabs(deltaSinceLastVisit))
        local percent = zo_round(mathabs(deltaSinceLastVisit) / comparisonGold * 100)
        ChatInfo(SI_BMW_MSG_SIGNIFICANT_DELTA, magnitude, percent)
    end

    RecordValuePoint()

    -- Refresh so the footer picks up the just-computed delta (the delta was nil
    -- while finalize was deferred; without this the footer would show no change
    -- until the next window refresh).
    RefreshWindow()
end

-- The footer row is an acknowledgement control. Preserve the details in memory
-- for the just-opened table, then advance the baseline so future changes form a
-- new accumulated delta. The persisted record is cleared immediately, making the
-- footer row disappear even while DetailWindow remains open.
function Valuation.AcknowledgeVisitDelta()
    local sv = private.savedVars
    -- Accept the acknowledgement whenever a composition change is pending, even
    -- if the gold delta nets to exactly zero (an even swap). Requiring a non-zero
    -- delta here left such changes permanently stuck: the row could not be
    -- cleared, so the baseline never advanced past them.
    if not sv or not visitChangePending then
        return
    end

    acknowledgedVisitDetails = sv.lastVisitDetails
    local baseline = CaptureVisitBaseline()
    if (sv.deltaMode or "visit") == "session" then
        sessionBaseGold = baseline.gold
        sessionBaseline = baseline
    else
        sv.lastVisitGold = baseline.gold
        sv.lastVisitItems = baseline.items
        sv.lastVisitBaseline = CompressVisitBaseline(baseline)
    end

    sv.lastVisitDetails = nil
    deltaSinceLastVisit = nil
    visitChangePending = false
    RefreshWindow()
end

-- Called from the fragment StateChange callback when the craft bag is shown.
-- Lazy: only rescans when something marked the valuation dirty since last time.
function Valuation.OnCraftBagShown()
    isBagVisible = true
    if isDirty then
        FullRescan()
    end

    -- Defer the delta/baseline/history capture until prices have settled. If the
    -- first scan is fully priced, finalize now; otherwise the price source is
    -- probably still importing (common right after login) -- arm the slow
    -- self-heal (below) and let it finalize once it fills the last slot or gives
    -- up, so the persisted baseline and the sparkline record the real total rather
    -- than an understated one. OnCraftBagHidden is a backstop for the case where
    -- the bag is closed before the heal completes.
    visitFinalizePending = true

    -- If the first scan left anything unpriced, the price source is probably still
    -- importing (common right after login); arm the slow self-heal so those slots
    -- fill in on their own instead of waiting for a manual /bmw refresh. When
    -- everything is already priced, StartPriceRetry is a no-op, so finalize here.
    if grandUnpricedSlots <= 0 then
        FinalizeVisit(true)
    elseif not StartPriceRetry() then
        -- The session's one automatic retry already ran. Treat the cached
        -- unpriced verdicts as settled until an explicit refresh or /reloadui.
        FinalizeVisit(true)
    end
end

function Valuation.OnCraftBagHidden()
    isBagVisible = false
    -- No scanning work happens with the bag closed, so drop the retry timer too.
    StopPriceRetry()
    -- Closing the bag cancels the delayed LibPrice retry. Clear the busy state
    -- without recording a successful completion that the player never observed.
    manualPriceRefreshPending = false
    -- Backstop: if the bag is closed before the self-heal finished (or was never
    -- fully priced), finalize now so the visit baseline still advances and the
    -- session's history point is recorded exactly once.
    FinalizeVisit(false)
end

-- Explicit user-driven refresh (/bmw refresh): drop the price cache so prices
-- re-query (e.g. after MM/TTC finished importing) and rebuild from scratch.
function Valuation.ForceRefresh()
    if manualPriceRefreshPending then
        return false
    end

    ZO_ClearTable(priceCache)
    ZO_ClearTable(priceSource)
    priceRetryAttempted = false
    -- A manual refresh supersedes any in-flight self-heal; stop it (and reset its
    -- attempt budget) so a fresh retry can arm below if slots are still unpriced.
    StopPriceRetry()
    isDirty = true
    if isBagVisible then
        manualPriceRefreshPending = true
        FullRescan()
        RefreshLiveVisitDelta()
        local retryStarted = StartPriceRetry()
        if not retryStarted then
            CompleteManualPriceRefresh()
        end
        RefreshWindow()
    end
    return true
end

-- The price source covering the most priced slots, as a display name, plus a
-- flag for whether more than one source contributed. Lets the footer read
-- "Prices: Master Merchant" (or "... (+others)") so the user knows where the
-- figures came from. Returns nil when nothing is priced.
local function GetDominantSource()
    local bestKey, bestCount = nil, 0
    local distinct = 0
    for sourceKey, count in pairs(sourceCounts) do
        distinct = distinct + 1
        if count > bestCount then
            bestKey, bestCount = sourceKey, count
        end
    end
    if not bestKey then
        return nil, nil, false
    end
    return SourceDisplayName(bestKey), SourceShortName(bestKey), distinct > 1
end

-- Snapshot consumed by the window. Returns a single table so the window does one
-- call and reads a stable view:
--   {
--     gold, slots, stacks, items, unpricedSlots,  -- bag-wide rollup
--     delta,                                       -- gold change since last review (or nil)
--     sourceName, sourceHasOthers,                 -- dominant price source for the footer
--     lastInventoryUpdateMs, lastPriceRefreshMs,    -- valuation and price freshness
--     categories = { { id, name, gold, slots, stacks, items, unpricedSlots }, ... }
--   }
-- `slots` is occupied craft-bag slots (distinct materials); `stacks` is the
-- derived count of classic 200-item stacks (ceil(items / 200)). Category rows
-- are emitted in canonical display order, or sorted by descending value when the
-- caller passes sortByValue.
-- Category comparator for the "sort by value" view: descending gold, stable
-- alphabetical tie-break. Captures nothing, so it is defined once here rather
-- than re-created on every GetSnapshot call.
local function CompareCategoriesByValue(a, b)
    if a.gold ~= b.gold then
        return a.gold > b.gold
    end
    return a.name < b.name
end

function Valuation.GetSnapshot(sortByValue)
    local categories = {}
    for index = 1, #CATEGORY_DEFINITIONS do
        local def = CATEGORY_DEFINITIONS[index]
        local stat = categoryStats[def.id]
        if stat and stat.slots > 0 then
            categories[#categories + 1] = {
                id = def.id,
                name = GetString(def.nameKey),
                gold = stat.gold,
                slots = stat.slots,
                stacks = ItemsToStacks(stat.items),
                items = stat.items,
                unpricedSlots = stat.unpricedSlots,
            }
        end
    end

    -- Optional: order categories by descending value so the biggest holdings
    -- float to the top. Stable tie-break on name keeps the order deterministic.
    if sortByValue then
        table.sort(categories, CompareCategoriesByValue)
    end

    local sourceName, sourceShort, sourceHasOthers = GetDominantSource()

    return {
        gold = grandGold,
        slots = grandSlots,
        stacks = ItemsToStacks(grandItems),
        items = grandItems,
        unpricedSlots = grandUnpricedSlots,
        delta = deltaSinceLastVisit,
        -- Lets the footer show (and accept a click on) an even swap whose gold
        -- delta is zero but whose composition still changed.
        deltaPending = visitChangePending,
        deltaMode = (private.savedVars and private.savedVars.deltaMode) or "visit",
        sourceName = sourceName,
        sourceShort = sourceShort,
        sourceHasOthers = sourceHasOthers,
        lastInventoryUpdateMs = lastInventoryUpdateMs,
        lastPriceRefreshMs = lastPriceRefreshMs,
        priceRefreshPending = manualPriceRefreshPending,
        priceRefreshCompletedMs = manualPriceRefreshCompletedMs,
        categories = categories,
    }
end

function Valuation.GetStatus()
    return grandGold, grandSlots - grandUnpricedSlots, grandUnpricedSlots
end

function Valuation.GetInventoryUpdateStats()
    return fullUpdateEventCount, fullUpdateVisibleEventCount, fullUpdateRescanCount
end

-- The value-history samples in chronological order (oldest -> newest), each
-- { t = unix, gold, items }. The ring stores them out of array order (writes
-- wrap around head), so this walks from the oldest slot forward to linearize
-- them for the sparkline. O(stored points), called once per window render --
-- never on the scan path. Returns an empty array when nothing is recorded yet.
function Valuation.GetValueHistory()
    local sv = private.savedVars
    local hist = sv and sv.valueHistory
    if not hist or not hist.entries or (hist.head or 0) == 0 then
        return {}
    end

    local entries = hist.entries
    local head = hist.head
    -- Count occupied slots explicitly against the fixed capacity instead of
    -- trusting `#entries`: a save written by an older build (or one carrying a
    -- hole from a partially-defaulted table) makes the array length operator
    -- undefined in Lua 5.1, and using it as the ring modulus silently
    -- reorders the samples. Capacity is the only stable modulus.
    local stored = 0
    for i = 1, VALUE_HISTORY_CAPACITY do
        if entries[i] then
            stored = stored + 1
        end
    end
    if stored == 0 then
        return {}
    end

    local out = {}
    if stored < VALUE_HISTORY_CAPACITY then
        -- Ring not full yet: writes have only ever gone 1, 2, 3, ... head, so
        -- the slots are already chronological. Skip any hole rather than
        -- emitting nil into the sparkline input.
        for i = 1, VALUE_HISTORY_CAPACITY do
            local entry = entries[i]
            if entry then
                out[#out + 1] = entry
            end
        end
    else
        -- Full ring: head is the newest sample, so the oldest sits at head+1
        -- (wrapping) and a capacity-long walk from there is chronological.
        for offset = 1, VALUE_HISTORY_CAPACITY do
            local idx = (head + offset - 1) % VALUE_HISTORY_CAPACITY + 1
            local entry = entries[idx]
            if entry then
                out[#out + 1] = entry
            end
        end
    end
    return out
end

-- How many items of `itemId` the backpack can currently absorb, used by the
-- withdraw dialog to show the max-withdrawable figure and to clamp the requested
-- quantity. It is the sum of two things:
--   1. the room left in the first partial stack of the same item already in the
--      backpack, since the withdrawal engine targets that stack before using
--      empty slots, and
--   2. STACK_SIZE for every free backpack slot (each can hold a fresh 200).
-- Read-only: it scans BAG_BACKPACK but touches none of the craft-bag aggregates.
-- The caller clamps this against the craft-bag source stack, so the returned
-- figure is purely the destination-side cap.
function Valuation.GetBackpackCapacityFor(itemId)
    if not itemId or itemId <= 0 then
        return 0
    end

    local partialCapacity = 0
    local slotIndex = ZO_GetNextBagSlotIndex(BAG_BACKPACK)
    while slotIndex do
        if GetItemId(BAG_BACKPACK, slotIndex) == itemId then
            local size = GetSlotStackSize(BAG_BACKPACK, slotIndex)
            -- Strict `<`: a slot already at STACK_SIZE is a full stack with zero
            -- room to top up, so it contributes nothing here (it's not "free
            -- capacity", unlike the free-slot count added below).
            if size and size > 0 and size < STACK_SIZE then
                partialCapacity = STACK_SIZE - size
                break
            end
        end
        slotIndex = ZO_GetNextBagSlotIndex(BAG_BACKPACK, slotIndex)
    end

    return partialCapacity + GetNumBagFreeSlots(BAG_BACKPACK) * STACK_SIZE
end

-- Current price metadata for a live craft-bag slot. The withdrawal queue keeps
-- its own display rows, so it uses this narrow lookup during refresh instead of
-- retaining a stale price copied when the item was queued.
function Valuation.GetMaterialPrice(itemId, slotIndex)
    local info = slotInfo[slotIndex]
    if not info or info.itemId ~= itemId then
        return nil, false, nil
    end
    local unitPrice = info.stack and info.stack > 0 and (info.value / info.stack) or 0
    return unitPrice, info.priced == true, info.source
end

-- Detail-window data + price history
-- ---------------------------------------------------------------------------
-- Display rows resolve item metadata lazily. Price-history writes instead run
-- after actual price lookups through UpdatePriceHistoryBaselines.

-- Price changes captured when a price lookup refreshed a material. Keeping this
-- transient result lets the UI show the just-observed change even though the
-- persisted baseline has already advanced for the next comparison interval.
local priceGrowthCache = {}  -- [itemId] = { unitPrice, source, growthPercent, growthDir, isNew }

-- Read a persisted baseline without changing it. Row building must be pure: a
-- search, sort, or category open should never alter the user's price history.
local function ResolvePriceGrowth(itemId, curUnit, source)
    local sv = private.savedVars
    if not sv or not curUnit or curUnit <= 0 then
        return nil, nil, false
    end

    local cached = priceGrowthCache[itemId]
    if cached and cached.unitPrice == curUnit and cached.source == source then
        return cached.growthPercent, cached.growthDir, cached.isNew
    end

    local storedSeries = sv.priceHistory and sv.priceHistory[itemId]
    local points = DecodePriceHistorySeries(storedSeries)
    local old = LatestComparablePricePoint(points, source)

    local growthPercent, growthDir, isNew
    if old and old.p and old.p > 0 then
        growthPercent = (curUnit - old.p) / old.p * 100
        growthDir = curUnit >= old.p
        isNew = false
    else
        isNew = true
    end

    return growthPercent, growthDir, isNew
end

-- Advance stale price baselines only after LibPrice was actually queried. This
-- decouples price-history writes from opening/sorting the detail window while
-- preserving the observed change for the current UI refresh in priceGrowthCache.
UpdatePriceHistoryBaselines = function()
    if not priceHistoryUpdatePending then
        return
    end
    priceHistoryUpdatePending = false
    InvalidatePriceTrendCache()
    local lookupItemIds = priceLookupItemIds
    priceLookupItemIds = {}

    local sv = private.savedVars
    if not sv then
        return
    end
    local history = sv.priceHistory
    if not history then
        history = {}
        sv.priceHistory = history
    end

    local now = GetTimeStamp()
    for _, info in pairs(slotInfo) do
        if lookupItemIds[info.itemId] and info.priced and info.stack and info.stack > 0 then
            local unitPrice = info.value / info.stack
            local points = DecodePriceHistorySeries(history[info.itemId])
            local old = LatestComparablePricePoint(points, info.source)
            local growthPercent, growthDir, isNew
            if old and old.p and old.p > 0 then
                growthPercent = (unitPrice - old.p) / old.p * 100
                growthDir = unitPrice >= old.p
                isNew = false
            else
                isNew = true
            end
            priceGrowthCache[info.itemId] = {
                unitPrice = unitPrice,
                source = info.source,
                growthPercent = growthPercent,
                growthDir = growthDir,
                isNew = isNew,
            }

            local latest = points[#points]
            local sourceChanged = latest and latest.s and info.source and latest.s ~= info.source
            local needsSourceAnchor = latest and not latest.s and info.source ~= nil
            local alreadyWritten = priceHistoryWrittenThisSession[info.itemId]
            -- A new UI session always appends, even if the previous login was only
            -- minutes ago. Later lookups in the same session (bag reopen or a
            -- manual refresh) keep a single point and update it in place.
            if not latest or not latest.t or sourceChanged or needsSourceAnchor
                or not alreadyWritten then
                AppendPriceHistoryPoint(points, unitPrice, now, info.source)
                priceHistoryWrittenThisSession[info.itemId] = true
            else
                latest.p = zo_round(unitPrice)
                latest.t = now
                latest.s = info.source
            end

            PrunePriceHistoryPoints(points, now)
            history[info.itemId] = EncodePriceHistorySeries(points)
        end
    end
end

-- Build one display row from a slot's cached info. Resolves the heavier display
-- fields (name/icon/quality) and the price-growth figure lazily from the item
-- link; shared by GetCategoryMaterials and GetAllMaterials so the row shape
-- stays identical. See GetCategoryMaterials for the returned field list.
local function BuildMaterialRow(slotIndex, info)
    local itemLink = GetItemLink(BAG, slotIndex)
    local quality = GetItemLinkFunctionalQuality(itemLink)
    local unitPrice
    if info.stack and info.stack > 0 then
        unitPrice = info.value / info.stack
    else
        unitPrice = 0
    end

    local growthPercent, growthDir, isNew = ResolvePriceGrowth(
        info.itemId, info.priced and unitPrice or nil, info.source)

    return {
        itemId = info.itemId,
        -- The craft-bag slot this material occupies. Exposed so the withdraw
        -- dialog can issue RequestMoveItem against the right source slot. A
        -- material is held in exactly one craft-bag slot, so this
        -- itemId -> slotIndex mapping is 1:1 for the run.
        slotIndex = slotIndex,
        -- Resolved (and memoized) display name; see GetMaterialDisplayName.
        -- Stable per itemId, so the detail window's rebuilds reuse it.
        name = GetMaterialDisplayName(info.itemId, itemLink),
        icon = GetItemLinkIcon(itemLink),
        quality = quality,
        count = info.stack,
        gold = info.value,
        unitPrice = unitPrice,
        priced = info.priced,
        -- The LibPrice source key ("mm"/"ttc"/...) this slot's price came from, so
        -- the detail-row tooltip can name where the figure originates. nil when
        -- unpriced. Resolve to a display name via Valuation.GetSourceDisplayName.
        source = info.source,
        -- Live item link for the game tooltip and Shift-click chat linking.
        link = itemLink,
        growthPercent = growthPercent,
        growthDir = growthDir,
        isNew = isNew,
    }
end

-- Sort material rows alphabetically by name, breaking ties by itemId so the
-- order is stable across rebuilds.
local function SortMaterialsByName(materials)
    tablesort(materials, function(a, b)
        if a.name ~= b.name then
            return a.name < b.name
        end
        return a.itemId < b.itemId
    end)
end

-- Per-material rows for one category, built lazily on detail-window open. O(slots)
-- to filter slotInfo plus a GetItemLink* resolve per matching slot; runs once per
-- click, not on the scan path. Returns an array sorted alphabetically by name:
--   { itemId, slotIndex, name, icon, quality, count, gold, unitPrice, priced,
--     growthPercent, growthDir, isNew }
-- slotIndex is the craft-bag source slot, carried through so the withdraw dialog
-- can move the material out. Relies on craft-bag slots being valid, which holds
-- because the detail window is only reachable from the panel, shown only while
-- the craft bag is open.
function Valuation.GetCategoryMaterials(categoryId)
    local materials = {}

    for slotIndex, info in pairs(slotInfo) do
        if info.category == categoryId then
            materials[#materials + 1] = BuildMaterialRow(slotIndex, info)
        end
    end

    SortMaterialsByName(materials)
    return materials
end

-- Per-material rows across the entire Craft Bag. Used by the detail window's
-- whole-bag coverage view, where there is no category or search query yet the
-- player still needs the active price filter to operate over every material.
function Valuation.GetAllMaterials()
    local materials = {}

    for slotIndex, info in pairs(slotInfo) do
        materials[#materials + 1] = BuildMaterialRow(slotIndex, info)
    end

    SortMaterialsByName(materials)
    return materials
end

-- Significant price movements observed anywhere inside the trailing seven-day
-- window. Every earlier/later pair in the current source run is compared, so a
-- one- or two-day surge remains visible even if the price later returns near its
-- starting level. The live price is included as an unsaved endpoint, allowing a
-- fresh refresh to surface immediately without shortening the recording cadence.
function Valuation.GetPriceTrendMaterials(thresholdPercent)
    local threshold = tonumber(thresholdPercent) or 20
    local now = GetTimeStamp()
    local cutoff = now - PRICE_TREND_WINDOW_SECONDS
    local materials = {}
    local history = private.savedVars and private.savedVars.priceHistory or {}

    for slotIndex, info in pairs(slotInfo) do
        if info.priced and info.stack and info.stack > 0 then
            local currentPrice = info.value / info.stack
            local storedPoints = DecodePriceHistorySeries(history[info.itemId])
            local points = {}
            local hasTaggedCurrentRun = false

            -- Walk backward through only the newest uninterrupted source run.
            -- Once a source-tagged point is found, an older untagged legacy point
            -- is a boundary too: its provider is unknowable, so comparing across
            -- it could manufacture a false MM/TTC/ATT movement after migration.
            for index = #storedPoints, 1, -1 do
                local point = storedPoints[index]
                if point.s and point.s ~= info.source then
                    break
                end
                if point.s then
                    hasTaggedCurrentRun = true
                elseif hasTaggedCurrentRun then
                    break
                end
                if point.t and point.t >= cutoff and point.p and point.p > 0 then
                    table.insert(points, 1, point)
                end
            end

            if not hasTaggedCurrentRun then
                points = {}
            end
            local latest = points[#points]
            if not latest or latest.p ~= currentPrice or latest.t ~= now then
                points[#points + 1] = { p = currentPrice, t = now, s = info.source }
            end

            if #points >= 2 then
                local maxGain, maxLoss = nil, nil
                for earlierIndex = 1, #points - 1 do
                    local earlier = points[earlierIndex]
                    for laterIndex = earlierIndex + 1, #points do
                        local later = points[laterIndex]
                        local percent = (later.p - earlier.p) / earlier.p * 100
                        if percent > 0 and (not maxGain or percent > maxGain) then
                            maxGain = percent
                        elseif percent < 0 and (not maxLoss or percent < maxLoss) then
                            maxLoss = percent
                        end
                    end
                end

                local overall = (points[#points].p - points[1].p) / points[1].p * 100
                local strongest = overall
                if maxGain and mathabs(maxGain) > mathabs(strongest) then
                    strongest = maxGain
                end
                if maxLoss and mathabs(maxLoss) > mathabs(strongest) then
                    strongest = maxLoss
                end

                if mathabs(strongest) >= threshold then
                    local row = BuildMaterialRow(slotIndex, info)
                    row.trend = true
                    row.trendOverallPercent = overall
                    row.trendMaxGainPercent = maxGain
                    row.trendMaxLossPercent = maxLoss
                    row.trendStrongestPercent = strongest
                    row.trendValueImpact = (points[#points].p - points[1].p) * info.stack
                    row.trendPointCount = #points
                    row.growthPercent = strongest
                    row.growthDir = strongest >= 0
                    row.isNew = false
                    materials[#materials + 1] = row
                end
            end
        end
    end

    tablesort(materials, function(a, b)
        local aMagnitude = mathabs(a.trendStrongestPercent or 0)
        local bMagnitude = mathabs(b.trendStrongestPercent or 0)
        if aMagnitude ~= bMagnitude then
            return aMagnitude > bMagnitude
        end
        if a.name ~= b.name then
            return a.name < b.name
        end
        return a.itemId < b.itemId
    end)
    StorePriceTrendSummary(threshold, materials)
    return materials
end

function Valuation.GetPriceTrendSummary(thresholdPercent)
    local threshold = tonumber(thresholdPercent) or 20
    local now = GetTimeStamp()
    if priceTrendSummaryCache.threshold == threshold
        and (now - (priceTrendSummaryCache.computedAt or 0)) < PRICE_TREND_SUMMARY_MAX_AGE_SECONDS then
        return priceTrendSummaryCache.gains, priceTrendSummaryCache.losses,
            priceTrendSummaryCache.total
    end
    local materials = Valuation.GetPriceTrendMaterials(threshold)
    return priceTrendSummaryCache.gains, priceTrendSummaryCache.losses, #materials
end

-- True once any held, priced material has two comparable observations in the
-- current source run. Distinguishes "history is still collecting" from "nothing
-- crossed the threshold yet".
function Valuation.HasPriceTrendHistory()
    local history = private.savedVars and private.savedVars.priceHistory or {}
    for _, info in pairs(slotInfo) do
        if info.priced and info.stack and info.stack > 0 then
            local points = DecodePriceHistorySeries(history[info.itemId])
            local comparable = 0
            for index = #points, 1, -1 do
                local point = points[index]
                if point.s and point.s ~= info.source then
                    break
                end
                if point.s and point.p and point.p > 0 then
                    -- One stored observation plus the live price already makes a pair.
                    return true
                end
            end
        end
    end
    return false
end

-- Report only newly significant, reversed, or materially stronger signals.
-- Notification state persists across reloads so the same crossing is not
-- repeated; dropping below the threshold clears the state so a later
-- crossing can announce immediately.
NotifySignificantPriceTrends = function()
    local mode = GetNotificationMode()
    local sv = private.savedVars
    if not sv then
        return
    end
    if mode ~= "important" and mode ~= "detailed" then
        if sv.priceTrendAlerts then
            ZO_ClearTable(sv.priceTrendAlerts)
        end
        return
    end
    local threshold = private.GetPriceTrendThreshold and private.GetPriceTrendThreshold() or 20
    local materials = Valuation.GetPriceTrendMaterials(threshold)
    local alerts = sv.priceTrendAlerts or {}
    sv.priceTrendAlerts = alerts
    local active = {}
    local changed = {}
    local now = GetTimeStamp()
    local strongerBy = 10

    for index = 1, #materials do
        local row = materials[index]
        active[row.itemId] = true
        local magnitude = mathabs(row.trendStrongestPercent or 0)
        local direction = (row.trendStrongestPercent or 0) >= 0 and "up" or "down"
        local previous = DecodePriceTrendAlert(alerts[row.itemId])
        local shouldNotify = previous == nil
        if previous then
            if previous.d ~= direction then
                shouldNotify = true
            elseif magnitude >= (previous.m or 0) + strongerBy then
                shouldNotify = true
            end
        end
        if shouldNotify then
            changed[#changed + 1] = row
            alerts[row.itemId] = EncodePriceTrendAlert(direction, magnitude, now)
        end
    end

    for itemId in pairs(alerts) do
        if not active[itemId] then
            alerts[itemId] = nil
        end
    end

    if #changed == 0 then
        return
    end

    local parts = {}
    local shown = math.min(3, #changed)
    for index = 1, shown do
        local row = changed[index]
        local stringId = (row.trendStrongestPercent or 0) >= 0
            and SI_BMW_MSG_PRICE_TREND_GAIN or SI_BMW_MSG_PRICE_TREND_LOSS
        parts[#parts + 1] = stringformat(GetString(stringId), row.name,
            stringformat("%.1f", mathabs(row.trendStrongestPercent or 0)))
    end
    if #changed > shown then
        parts[#parts + 1] = stringformat(GetString(SI_BMW_MSG_PRICE_TREND_MORE), #changed - shown)
    end
    ChatInfo(SI_BMW_MSG_PRICE_TRENDS, threshold, table.concat(parts, "; "))
end

-- Snapshot + diff
-- ---------------------------------------------------------------------------
-- A single snapshot of the craft bag's composition, captured once automatically
-- on the first non-empty bag open or explicitly by the detail window's "Remember"
-- button, then diffed against the live bag ("Changes"). Stored in savedVars so
-- it survives restarts. Shape:
--   snapshot = {
--     t, gold, items, slots,                 -- header captured at Remember time
--     materials = { [itemId] = { link, count, unitPrice, priced } },
--   }
-- The link keeps a removed material's name localized to the active game language
-- and lets the diff rebuild its icon and quality. Gold is derived from count and
-- unitPrice, so it is not persisted. Older snapshots may still contain name,
-- icon, and quality; they remain readable without a migration.

-- Resolve a snapshot material's display name in the current game language. Item
-- links are language-independent, so re-resolving from the stored link each
-- render keeps removed/changed rows in the active language rather than the one
-- the snapshot was captured in. Falls back to the stored name for older
-- snapshots that predate the persisted link.
local function SnapshotMaterialName(entry)
    if entry.link and entry.link ~= "" then
        return zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(entry.link))
    end
    return entry.name
end

local function SnapshotMaterialVisuals(entry)
    if entry.link and entry.link ~= "" then
        return GetItemLinkIcon(entry.link), GetItemLinkFunctionalQuality(entry.link)
    end
    return entry.icon, entry.quality
end

-- Aggregate the current slotInfo by itemId. In practice the craft bag holds each
-- material in exactly one slot, but aggregating is robust and keeps the diff keyed
-- the same way as the stored snapshot. Returns { [itemId] = { count, gold,
-- unitPrice, priced, slotIndex } }; slotIndex is any one source slot, kept only so
-- a display name can be resolved lazily for added materials.
local function AggregateCurrentByItemId()
    local byId = {}
    for slotIndex, info in pairs(slotInfo) do
        local entry = byId[info.itemId]
        if not entry then
            entry = { count = 0, gold = 0, priced = info.priced, slotIndex = slotIndex }
            byId[info.itemId] = entry
        end
        entry.count = entry.count + info.stack
        entry.gold = entry.gold + info.value
    end
    -- Derive a representative unit price from the aggregate so a removed/added
    -- material can be valued by its own per-unit figure.
    for _, entry in pairs(byId) do
        entry.unitPrice = entry.count > 0 and (entry.gold / entry.count) or 0
    end
    return byId
end

-- Freeze the current bag composition into savedVars, overwriting any prior
-- snapshot (single-snapshot model). O(slots); runs only for the one-time
-- automatic baseline or a Remember click.
function Valuation.CaptureSnapshot()
    local sv = private.savedVars
    if not sv then
        return
    end

    local materials = {}
    for slotIndex, info in pairs(slotInfo) do
        local existing = materials[info.itemId]
        if existing then
            -- Same material in a second slot: fold its quantity/value in.
            existing.count = existing.count + info.stack
            existing.gold = existing.gold + info.value
            existing.unitPrice = existing.count > 0 and (existing.gold / existing.count) or 0
        else
            local itemLink = GetItemLink(BAG, slotIndex)
            local unitPrice = info.stack > 0 and (info.value / info.stack) or 0
            materials[info.itemId] = {
                -- The link lets the diff rebuild the localized name, icon, and
                -- quality for materials no longer in the Craft Bag.
                link = itemLink,
                count = info.stack,
                gold = info.value,
                unitPrice = unitPrice,
                priced = info.priced,
            }
        end
    end

    -- `gold` is needed only while combining duplicate slots. The persisted diff
    -- reconstructs it from count and unitPrice.
    for itemId, entry in pairs(materials) do
        entry.gold = nil
        materials[itemId] = EncodeSnapshotMaterial(entry)
    end

    sv.snapshot = {
        t = GetTimeStamp(),
        gold = grandGold,
        items = grandItems,
        slots = grandSlots,
        materials = materials,
    }

    -- Returned so the caller (the manual "Remember" button) can report what was
    -- captured in chat; the silent auto-snapshot path ignores the return value.
    return sv.snapshot
end

-- Whether a snapshot exists to diff against. Used by the window to pick between
-- the diff list and the "no snapshot yet" empty state.
function Valuation.HasSnapshot()
    local sv = private.savedVars
    return sv ~= nil and sv.snapshot ~= nil
end

-- Forget the saved snapshot (the detail window's "Clear" button). The single-
-- snapshot model means there is nothing else to fall back to, so the diff view
-- reverts to its "press Remember" empty state until a new snapshot is taken.
function Valuation.ClearSnapshot()
    local sv = private.savedVars
    if sv then
        sv.snapshot = nil
    end
end

-- Header info for the diff title (the relative-time label is built by the
-- window). Returns nil when no snapshot exists.
function Valuation.GetSnapshotInfo()
    local sv = private.savedVars
    local snap = sv and sv.snapshot
    if not snap then
        return nil
    end
    return { t = snap.t, gold = snap.gold, items = snap.items, slots = snap.slots }
end

-- Per-material diff rows comparing the live bag against the snapshot. Walks the
-- union of snapshot materials and current materials (both keyed by itemId) and
-- classifies each:
--   added    (current only)         countDelta = +count,  status "new"
--   removed  (snapshot only)        countDelta = -count,  status "gone"
--   increased (both, count went up)  countDelta > 0,       status "added"
--   decreased (both, count went down) countDelta < 0,      status "reduced"
--   count unchanged                 skipped
-- The gold delta is the QUANTITY change valued at one unit price (the current
-- unit price when available, else the snapshot's). Pure price drift (same count,
-- reimported prices) is intentionally excluded by the count-unchanged skip, so
-- the diff never shows a movement the player did not make - the same gating the
-- footer delta uses. Returns an array of row records; empty when nothing changed
-- or no snapshot exists. Sorting is left to the caller.
--   { itemId, name, icon, quality, diff = true, countDelta, goldDelta, priced,
--     status }  -- status is one of "new" / "gone" / "changed"
function Valuation.GetDiffMaterials()
    local sv = private.savedVars
    local snap = sv and sv.snapshot
    if not snap then
        return {}
    end

    local snapMats = snap.materials or {}
    local current = AggregateCurrentByItemId()
    local rows = {}

    -- Materials present now: added or changed (or unchanged, which we skip).
    for itemId, cur in pairs(current) do
        local storedOld = snapMats[itemId]
        local old = storedOld and DecodeSnapshotMaterial(storedOld) or nil
        if not old then
            -- Added since the snapshot.
            local itemLink = GetItemLink(BAG, cur.slotIndex)
            rows[#rows + 1] = {
                itemId = itemId,
                name = GetMaterialDisplayName(itemId, itemLink),
                icon = GetItemLinkIcon(itemLink),
                quality = GetItemLinkFunctionalQuality(itemLink),
                link = itemLink,
                diff = true,
                countDelta = cur.count,
                goldDelta = cur.unitPrice * cur.count,
                priced = cur.priced,
                status = "new",
            }
        elseif cur.count ~= old.count then
            -- Quantity changed; value the delta at the current unit price. Split
            -- the status by direction so the column reads "added"/"reduced", not a
            -- single ambiguous "changed" (the sign is otherwise only in the Qty
            -- column).
            local countDelta = cur.count - old.count
            local icon, quality = SnapshotMaterialVisuals(old)
            rows[#rows + 1] = {
                itemId = itemId,
                name = SnapshotMaterialName(old),
                icon = icon,
                quality = quality,
                link = GetItemLink(BAG, cur.slotIndex) or old.link,
                diff = true,
                countDelta = countDelta,
                goldDelta = cur.unitPrice * countDelta,
                priced = cur.priced,
                status = countDelta > 0 and "added" or "reduced",
            }
        end
        -- cur.count == old.count: unchanged, skipped (excludes price drift).
    end

    -- Materials in the snapshot but no longer present: removed.
    for itemId, storedOld in pairs(snapMats) do
        local old = DecodeSnapshotMaterial(storedOld)
        if not current[itemId] then
            local icon, quality = SnapshotMaterialVisuals(old)
            rows[#rows + 1] = {
                itemId = itemId,
                name = SnapshotMaterialName(old),
                icon = icon,
                link = old.link,
                quality = quality,
                diff = true,
                countDelta = -old.count,
                goldDelta = -(old.unitPrice * old.count),
                priced = old.priced,
                status = "gone",
            }
        end
    end

    return rows
end

-- The current unacknowledged delta is persisted. After the footer row is clicked,
-- retain that same record in memory for the open detail view while a new delta
-- starts accumulating from the acknowledged baseline.
function Valuation.GetLastVisitDeltaDetails()
    local sv = private.savedVars
    return (sv and sv.lastVisitDetails) or acknowledgedVisitDetails
end

-- Quantity-only rows for the latest visit delta. The total delta's separate
-- price component belongs in the detail view's context line/tooltip; the rows
-- answer the complementary question of which materials actually moved.
function Valuation.GetLastVisitDiffMaterials()
    local details = Valuation.GetLastVisitDeltaDetails()
    if not details or not details.rows then
        return {}
    end

    local rows = {}
    for index = 1, #details.rows do
        local entry = DecodeVisitDiffRow(details.rows[index])
        local material = { link = entry.link }
        local icon, quality = SnapshotMaterialVisuals(material)
        rows[#rows + 1] = {
            itemId = entry.itemId,
            name = SnapshotMaterialName(material) or tostring(entry.itemId),
            icon = icon,
            link = entry.link,
            quality = quality,
            diff = true,
            countDelta = entry.countDelta,
            goldDelta = entry.goldDelta,
            priced = entry.priced,
            status = entry.status,
        }
    end
    return rows
end


-- Wrap a material name in the game's own quality color, so a row reads with the
-- same tint the inventory tooltip uses (white/green/blue/purple/gold). Returns
-- the name untouched when the quality is unknown or the client has no color for
-- it, so a caller never has to special-case unquality-tagged rows. This is the
-- single place the addon applies quality coloring to material names. Kept here
-- (next to the data) so the window can render a plain string.
function Valuation.ColorizeMaterialName(name, quality)
    if not quality then
        return name
    end
    local color = GetItemQualityColor(quality)
    if not color then
        return name
    end
    return color:Colorize(name)
end

-- Drop price-history baselines for materials not seen in PRUNE_MAX_AGE_SECONDS so
-- the table cannot grow without bound, and trim retained series to the analysis
-- window while preserving the newest price baseline. Called once on load.
function Valuation.PrunePriceHistory()
    local result = {
        materialsChecked = 0,
        materialsRemoved = 0,
        pointsRemoved = 0,
        pointsRemaining = 0,
        bytesBefore = 0,
        bytesAfter = 0,
        bytesRemoved = 0,
    }
    local sv = private.savedVars
    if not sv or type(sv.priceHistory) ~= "table" then
        return result
    end

    local now = GetTimeStamp()
    for itemId, storedEntry in pairs(sv.priceHistory) do
        local points = DecodePriceHistorySeries(storedEntry)
        local pointCount = #points
        local encodedBefore = type(storedEntry) == "string" and storedEntry
            or EncodePriceHistorySeries(points)
        result.materialsChecked = result.materialsChecked + 1
        result.bytesBefore = result.bytesBefore + #encodedBefore

        local newest = points[#points]
        if not newest or not newest.t or (now - newest.t) >= PRUNE_MAX_AGE_SECONDS then
            sv.priceHistory[itemId] = nil
            result.materialsRemoved = result.materialsRemoved + 1
            result.pointsRemoved = result.pointsRemoved + pointCount
        else
            PrunePriceHistoryPoints(points, now)
            local encodedAfter = EncodePriceHistorySeries(points)
            sv.priceHistory[itemId] = encodedAfter
            result.pointsRemoved = result.pointsRemoved + pointCount - #points
            result.pointsRemaining = result.pointsRemaining + #points
            result.bytesAfter = result.bytesAfter + #encodedAfter
        end
    end

    result.bytesRemoved = math.max(0, result.bytesBefore - result.bytesAfter)
    if result.pointsRemoved > 0 or result.materialsRemoved > 0 then
        InvalidatePriceTrendCache()
    end
    return result
end

private.GetValuationSnapshot = Valuation.GetSnapshot
