-- FurnishingCatalogScanUtils.lua: pure helpers for building the catalog (no game calls).
local FC = FurnishingCatalog

local ScanUtils = {}

-- The full scan (/furn scan) walks item ids upward and cannot ask the game where they end. No
-- furnishing sits below FIRST_ID (the lowest known is 87709). The walk stops once it is past
-- MIN_LAST_ID and has seen EMPTY_GAP ids in a row that hold no item at all, so a patch that adds
-- ids needs no addon update. HARD_CAP bounds a client that answers every id.
ScanUtils.FIRST_ID = 80000
ScanUtils.MIN_LAST_ID = 240000
ScanUtils.EMPTY_GAP = 30000
ScanUtils.HARD_CAP = 1000000

-- Item link: |H<style>:item:<id>:<subtype>:<level>: then 18 more fields. Furnishing links the game
-- hands out carry the quality (1-5) in subtype and level 1 (console log, Preview Anywhere 0.3.0:
-- "|H0:item:120648:2:1:0:...|h|h"). Lookups ask with subtype 0; the list builds the game's form.
local BARE_LINK_FORMAT = "|H0:item:%d:0:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
local LINK_FORMAT = "|H1:item:%d:%d:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"

local format = string.format

---Link an item id is looked up with.
---@param itemId integer
---@return string
function ScanUtils.BareLink(itemId)
    return format(BARE_LINK_FORMAT, itemId)
end

---Link in the form the game itself writes for a furnishing of that quality.
---@param itemId integer
---@param quality integer|nil ItemDisplayQuality; anything below 1 is written as 1
---@return string
function ScanUtils.Link(itemId, quality)
    if not quality or quality < 1 then
        quality = 1
    end
    return format(LINK_FORMAT, itemId, quality)
end

---Whether the full scan is done after having checked every id up to and including lastScannedId.
---@param lastScannedId integer
---@param lastValidId integer highest id so far that held any item (0 = none yet)
---@return boolean
function ScanUtils.IsPastEnd(lastScannedId, lastValidId)
    if lastScannedId >= ScanUtils.HARD_CAP then
        return true
    end
    return lastScannedId >= ScanUtils.MIN_LAST_ID and (lastScannedId - lastValidId) >= ScanUtils.EMPTY_GAP
end

---Id the full scan is expected to stop at, for a progress figure.
---@param lastValidId integer
---@return integer
function ScanUtils.EstimatedEnd(lastValidId)
    local estimate = lastValidId + ScanUtils.EMPTY_GAP
    if estimate < ScanUtils.MIN_LAST_ID then
        estimate = ScanUtils.MIN_LAST_ID
    end
    return estimate
end

---How far a full scan is, 0-1.
---@param nextId integer
---@param lastValidId integer
---@return number
function ScanUtils.FullScanFraction(nextId, lastValidId)
    local span = ScanUtils.EstimatedEnd(lastValidId) - ScanUtils.FIRST_ID
    local fraction = (nextId - ScanUtils.FIRST_ID) / span
    if fraction < 0 then
        return 0
    elseif fraction > 1 then
        return 1
    end
    return fraction
end

---Turn (first id, run length) pairs into a plain list of ids.
---@param ranges integer[]
---@return integer[]
function ScanUtils.ExpandRanges(ranges)
    local ids = {}
    local n = 0
    for index = 1, #ranges - 1, 2 do
        local first, length = ranges[index], ranges[index + 1]
        for itemId = first, first + length - 1 do
            n = n + 1
            ids[n] = itemId
        end
    end
    return ids
end

---The value listed for a key in the built-in list's flat (key, value) pairs.
---@param pairs integer[]|nil flat (key, value) pairs, sorted by key
---@param key integer|nil
---@return integer|nil value nil when the key is not listed
function ScanUtils.PairValue(pairs, key)
    if type(pairs) ~= "table" or type(key) ~= "number" then
        return nil
    end
    local low, high = 1, math.floor(#pairs / 2)
    while low <= high do
        local middle = math.floor((low + high) / 2)
        local candidate = pairs[middle * 2 - 1]
        if candidate == key then
            return pairs[middle * 2]
        elseif candidate < key then
            low = middle + 1
        else
            high = middle - 1
        end
    end
    return nil
end

---Flat (key, value) pairs in any order -> sorted by key, one value per key (the lowest).
---@param flat integer[]
---@return integer[] sorted a new table, usable with ScanUtils.PairValue
function ScanUtils.SortedPairs(flat)
    local valueOf, keys = {}, {}
    for index = 1, #flat - 1, 2 do
        local key, value = flat[index], flat[index + 1]
        if valueOf[key] == nil then
            keys[#keys + 1] = key
            valueOf[key] = value
        elseif value < valueOf[key] then
            valueOf[key] = value
        end
    end
    table.sort(keys)
    local sorted = {}
    for _, key in ipairs(keys) do
        sorted[#sorted + 1] = key
        sorted[#sorted + 1] = valueOf[key]
    end
    return sorted
end

---How two sorted flat pair lists stand to each other.
---@param ours integer[]
---@param theirs integer[]
---@return { same: integer, different: integer, onlyOurs: integer, onlyTheirs: integer, examples: string[] } result examples: up to 5 keys of each kind of mismatch
function ScanUtils.ComparePairs(ours, theirs)
    local result = { same = 0, different = 0, onlyOurs = 0, onlyTheirs = 0, examples = {} }
    local shown = { different = 0, onlyOurs = 0, onlyTheirs = 0 }
    local function Note(kind, key)
        result[kind] = result[kind] + 1
        if shown[kind] < 5 then
            shown[kind] = shown[kind] + 1
            result.examples[#result.examples + 1] = kind .. " " .. tostring(key)
        end
    end
    local i, j = 1, 1
    while i <= #ours or j <= #theirs do
        local a, b = ours[i], theirs[j]
        if b == nil or (a ~= nil and a < b) then
            Note("onlyOurs", a)
            i = i + 2
        elseif a == nil or b < a then
            Note("onlyTheirs", b)
            j = j + 2
        else
            if ours[i + 1] == theirs[j + 1] then
                result.same = result.same + 1
            else
                Note("different", a)
            end
            i, j = i + 2, j + 2
        end
    end
    return result
end

---File an item id under its category and subcategory (0 stands for "the game named none").
---@param tree table<integer, table<integer, integer[]>>
---@param categoryId integer|nil
---@param subcategoryId integer|nil
---@param itemId integer
function ScanUtils.AddToTree(tree, categoryId, subcategoryId, itemId)
    categoryId = categoryId or 0
    subcategoryId = subcategoryId or 0
    local subcategories = tree[categoryId]
    if not subcategories then
        subcategories = {}
        tree[categoryId] = subcategories
    end
    local ids = subcategories[subcategoryId]
    if not ids then
        ids = {}
        subcategories[subcategoryId] = ids
    end
    ids[#ids + 1] = itemId
end

---@param tree table<integer, table<integer, integer[]>>
---@return integer total
---@return integer numCategories
---@return integer numSubcategories
function ScanUtils.CountTree(tree)
    local total, numCategories, numSubcategories = 0, 0, 0
    for _, subcategories in pairs(tree) do
        numCategories = numCategories + 1
        for _, ids in pairs(subcategories) do
            numSubcategories = numSubcategories + 1
            total = total + #ids
        end
    end
    return total, numCategories, numSubcategories
end

---A saved catalog is usable when it was built on this client version, holds furnishings, and
---either came from a full scan or from the built-in list this addon version ships.
---@param catalog any
---@param stamp string
---@param seedVersion string
---@return boolean
function ScanUtils.IsCatalogUsable(catalog, stamp, seedVersion)
    if type(catalog) ~= "table" or catalog.stamp ~= stamp or type(catalog.tree) ~= "table" then
        return false
    end
    if type(catalog.total) ~= "number" or catalog.total <= 0 then
        return false
    end
    return catalog.source == "full" or catalog.seedVersion == seedVersion
end

---Saved progress of a full scan can be continued when it is from this client version.
---@param progress any
---@param stamp string
---@return boolean
function ScanUtils.IsProgressUsable(progress, stamp)
    return type(progress) == "table"
        and progress.kind == "full"
        and progress.stamp == stamp
        and type(progress.tree) == "table"
        and type(progress.nextId) == "number"
        and type(progress.lastValidId) == "number"
end

FC.ScanUtils = ScanUtils
