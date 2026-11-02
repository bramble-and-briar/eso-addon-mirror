InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- The Minimal layout: one level and nothing else. Every set you are carrying is a category under
-- its own name, and everything else falls into one of six buckets. Sets come first, alphabetically;
-- the buckets follow in a fixed order.
--
-- Nothing here decides how any of it looks: the Minimal theme switches every surface, outline and
-- set extra off. This file only decides what goes where.

local SET_ORDER = 0 -- sets sort above every bucket

local BUCKETS = {
    { key = "MIN_GEAR",        label = "Gear" },
    { key = "MIN_CONSUMABLES", label = "Consumables" },
    { key = "MIN_CRAFTING",    label = "Crafting" },
    { key = "MIN_FURNISHINGS", label = "Furnishings" },
    { key = "MIN_TREASURE",    label = "Treasure" },
    { key = "MIN_MISC",        label = "Misc" },
}

-- Which bucket each group of the full layout collapses into. Anything not named here, and anything
-- the full layout couldn't place either, ends up in Misc.
local FROM_GROUP = {
    COMPANION   = "MIN_GEAR",
    GARBAGE     = "MIN_GEAR",   -- gear with no set at all: the full layout files it under GARBAGE
    CONSUMABLES = "MIN_CONSUMABLES",
    CRAFT       = "MIN_CRAFTING",
    FURNISHING  = "MIN_FURNISHINGS",
    MAPS        = "MIN_TREASURE",
}

local bucketPaths = {}    -- [bucket key] = the one path every item in it shares
local setPaths = {}       -- [setId] = the same, for a set category
local pathByInstance = {} -- [itemInstanceId] = the answer already worked out for this kind of item
local bucketOrder = {}

for order, bucket in ipairs(BUCKETS) do
    bucketOrder[bucket.key] = order
    bucketPaths[bucket.key] = { {
        id = bucket.key,
        label = bucket.label,
        color = IG.DEFAULT_ICON_COLOR,
        order = order,
    } }
end

function IG.ClearMinimalCache()
    ZO_ClearTable(setPaths)
    ZO_ClearTable(pathByInstance)
end

-- Treasure and trash are the one thing the full layout keeps under GARBAGE together with setless
-- gear, so they are told apart here rather than by their group.
local TREASURE_TYPES = {}
for _, name in ipairs({ "ITEMTYPE_TREASURE", "ITEMTYPE_TRASH" }) do
    if _G[name] ~= nil then TREASURE_TYPES[_G[name]] = true end
end

local function SetPath(setId, setName)
    local path = setPaths[setId]
    if not path then
        path = { {
            id = "set" .. setId,
            label = zo_strformat("<<1>>", setName),
            color = IG.DEFAULT_ICON_COLOR,
            order = SET_ORDER,
        } }
        setPaths[setId] = path
    end
    return path
end

local function Categorize(slotData)
    local itemLink = GetItemLink(slotData.bagId, slotData.slotIndex)
    local typePath = IG.ClassifyByType(slotData, itemLink)
    local groupKey = typePath and typePath[1] and typePath[1].id or "MISC"

    -- Companion gear stays gear even when it belongs to a set: its sets are its own and would
    -- bury the ones you actually wear.
    if groupKey ~= "COMPANION" then
        local hasSet, setName, _, _, _, setId = GetItemLinkSetInfo(itemLink, false)
        if hasSet and setId and setId ~= 0 then return SetPath(setId, setName) end
    end

    if TREASURE_TYPES[slotData.itemType] then return bucketPaths.MIN_TREASURE end
    return bucketPaths[FROM_GROUP[groupKey] or "MIN_MISC"]
end

function IG.GetMinimalPath(slotData)
    -- Junk is the player's own call and can change on any item, so it is asked every time; the
    -- rest of the answer only depends on what the item is and is kept per item id.
    if slotData.isJunk then return bucketPaths.MIN_TREASURE end
    local instanceId = slotData.itemInstanceId
    local remembered = instanceId and pathByInstance[instanceId]
    if remembered then return remembered end
    local path = Categorize(slotData)
    if instanceId then pathByInstance[instanceId] = path end
    return path
end

-- Sets first and alphabetical, then the buckets in their fixed order; inside a category the list
-- is sorted the way every other list is.
function IG.CompareMinimalEntries(a, b)
    local na, nb = a.igPath[1], b.igPath[1]
    if na ~= nb then
        if na.order ~= nb.order then return na.order < nb.order end
        return na.label < nb.label
    end
    return IG.CompareItems(a, b)
end
