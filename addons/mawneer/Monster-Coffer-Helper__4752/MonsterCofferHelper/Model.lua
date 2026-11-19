local MCH = MonsterCofferHelper

local Model = {}
MCH.Model = Model

local poolCache = {}

--------------------------------------------------------------------------------
-- Which sets a quartermaster stocks
--------------------------------------------------------------------------------

-- LibSets tags every monster set with the quartermaster that sells its shoulders.
local function StaticVendorSets(vendorId)
    local result = {}
    local setInfo = LibSets and LibSets.setInfo
    if not setInfo then return result end

    for setId, data in pairs(setInfo) do
        if data.undauntedChestId == vendorId then
            result[#result + 1] = setId
        end
    end
    table.sort(result)
    return result
end

-- The store scan (Store.lua) records which sets it could tie a curated coffer to.
local function LearnedVendorSets(vendorId)
    local db = MCH.db
    if not db or not db.useLearnedPools then return nil end

    local learned = MCH.learned and MCH.learned[vendorId]
    return learned and learned.setIds or nil
end

-- The scan can only add to the bundled list, never shrink it. It recognises a
-- coffer by finding a set name inside the coffer's name, so any coffer worded
-- differently goes unseen, and a scan that matched 3 of a vendor's 33 sets
-- once replaced the whole list and cut the pool to 9 shoulders. What the scan
-- is good for is a set newer than LibSets' data, so that is all it contributes.
-- Pure, so it can be tested outside the game.
function Model.MergeVendorSets(staticSetIds, learnedSetIds)
    local merged, seen = {}, {}
    for _, list in ipairs({ staticSetIds or {}, learnedSetIds or {} }) do
        for _, setId in ipairs(list) do
            if not seen[setId] then
                seen[setId] = true
                merged[#merged + 1] = setId
            end
        end
    end
    table.sort(merged)
    return merged
end

function Model.GetVendorSets(vendorId)
    return Model.MergeVendorSets(StaticVendorSets(vendorId), LearnedVendorSets(vendorId))
end

--------------------------------------------------------------------------------
-- Reading the stickerbook
--------------------------------------------------------------------------------

-- Walk a set's item set collection and keep only the shoulder pieces, because
-- the quartermasters sell shoulders and nothing else; the helm comes off the
-- veteran dungeon's last boss and must not count towards the odds.
--
-- The piece list is read rather than assumed. Monster sets currently carry one
-- shoulder per armour weight, but reading it means a set that ever breaks that
-- pattern still gets counted correctly.
local function ScanShoulders(setId)
    local pieces, owned = {}, 0

    for i = 1, GetNumItemSetCollectionPieces(setId) do
        local pieceId, slot = GetItemSetCollectionPieceInfo(setId, i)
        local itemLink = GetItemSetCollectionPieceItemLink(pieceId, LINK_STYLE_DEFAULT, ITEM_TRAIT_TYPE_NONE)

        if itemLink and itemLink ~= "" and GetItemLinkEquipType(itemLink) == EQUIP_TYPE_SHOULDERS then
            -- `slot` is an id64 bitmask, so it is handed straight back to the
            -- API rather than stored or compared with ==.
            local unlocked = IsItemSetCollectionSlotUnlocked(setId, slot)
            pieces[#pieces + 1] = {
                armorType = GetItemLinkArmorType(itemLink),
                unlocked  = unlocked,
            }
            if unlocked then owned = owned + 1 end
        end
    end

    return pieces, owned
end

--------------------------------------------------------------------------------
-- Pool assembly
--------------------------------------------------------------------------------

local function SortSets(a, b)
    if a.missing ~= b.missing then return a.missing > b.missing end
    return a.name < b.name
end

-- Everything the advisor needs about one quartermaster: how many shoulders are
-- in the pool, how many of them you already own, and the per-set breakdown.
function Model.BuildPool(vendorId)
    local pool = {
        vendorId       = vendorId,
        sets           = {},
        setCount       = 0,
        total          = 0,
        owned          = 0,
        missing        = 0,
        incompleteSets = 0,
    }

    for _, setId in ipairs(Model.GetVendorSets(vendorId)) do
        local pieces, owned = ScanShoulders(setId)
        if #pieces > 0 then
            local entry = {
                setId   = setId,
                name    = zo_strformat(SI_ITEM_SET_NAME_FORMATTER, GetItemSetName(setId)),
                pieces  = pieces,
                total   = #pieces,
                owned   = owned,
                missing = #pieces - owned,
            }

            pool.sets[#pool.sets + 1] = entry
            pool.setCount = pool.setCount + 1
            pool.total    = pool.total + entry.total
            pool.owned    = pool.owned + entry.owned
            if entry.missing > 0 then
                pool.incompleteSets = pool.incompleteSets + 1
            end
        end
    end

    pool.missing = pool.total - pool.owned
    table.sort(pool.sets, SortSets)
    return pool
end

function Model.GetPool(vendorId)
    local cached = poolCache[vendorId]
    if cached then return cached end

    local pool = Model.BuildPool(vendorId)
    poolCache[vendorId] = pool
    return pool
end

-- Called when the stickerbook changes, when a store scan rewrites the stock, or
-- when a setting moves the numbers. The advisor's cache is derived from these
-- pools, so it goes at the same time.
function Model.Invalidate(vendorId)
    if vendorId then
        poolCache[vendorId] = nil
    else
        poolCache = {}
    end

    if MCH.Advisor then MCH.Advisor.Invalidate(vendorId) end
end

--------------------------------------------------------------------------------
-- Names
--------------------------------------------------------------------------------

function Model.GetVendorName(vendorId)
    local name = LibSets and LibSets.GetUndauntedChestName(vendorId)
    if name and name ~= "" then
        return zo_strformat(SI_UNIT_NAME, name)
    end
    return string.format("Undaunted vendor %d", vendorId)
end

function Model.GetKeyCount()
    return GetCurrencyAmount(CURT_UNDAUNTED_KEYS, GetCurrencyPlayerStoredLocation(CURT_UNDAUNTED_KEYS))
end

-- Prices to reason with: what was read off the store window if we have it and
-- the player wants it, otherwise the configured fallback.
function Model.GetPrices(vendorId)
    local db = MCH.db
    local mystery, curated = db.mysteryCost, db.curatedCost
    local learned = db.useLearnedPrices and MCH.learned and MCH.learned[vendorId] or nil

    if learned then
        mystery = learned.mysteryCost or mystery
        curated = learned.curatedCost or curated
        if learned.mysteryCost and learned.curatedCost then
            return mystery, curated, true
        end
    end

    return mystery, curated, false
end
