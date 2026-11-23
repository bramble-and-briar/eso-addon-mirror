-- WDH_Categories.lua
-- Sorting loot into categories
--
-- Every item lands in exactly one category. BOTH are always stored:
-- the item with its item ID, and the category. The mode only decides the display:
--   SET      -> grouped per setId, with slot (armor/weapon/jewelry)
--   DETAIL   -> always by name
--   DETAIL_Q -> by name from the "Show names from" quality up, otherwise as category
--   COUNT    -> always as category (category x quality)

WhatDropsHere.Categories = {}
local CAT = WhatDropsHere.Categories

local SET      = "SET"
local DETAIL   = "DETAIL"
local DETAIL_Q = "DETAIL_Q"
local COUNT    = "COUNT"

CAT.MODE_SET      = SET
CAT.MODE_DETAIL   = DETAIL
CAT.MODE_DETAIL_Q = DETAIL_Q
CAT.MODE_COUNT    = COUNT

-- -----------------------------------------------------------------------------
-- Mapping itemType -> category
-- -----------------------------------------------------------------------------

local BY_ITEMTYPE = {}

-- Display mode per category key (for displaying stored data)
local MODE_BY_KEY = {
    SET             = SET,
    GEAR_ARMOR      = COUNT,
    GEAR_WEAPON     = COUNT,
    GEAR_JEWELRY    = COUNT,
    GEAR_COMPANION  = COUNT,
    FURNISHING_PLAN = DETAIL,
    MAT_LEATHER     = DETAIL_Q,
    LEAD            = DETAIL,
    NO_ITEM         = DETAIL,
    MISC            = COUNT,
}

-- Constants that do not exist in this API version (nil) are skipped.
-- A nil key in the table constructor would raise an error otherwise.
local function add(itemType, key, mode)
    if itemType == nil then return end
    BY_ITEMTYPE[itemType] = { key = key, mode = mode }
    MODE_BY_KEY[key] = mode
end

-- Worthless
add(ITEMTYPE_TREASURE,                     "TREASURE",       COUNT)
add(ITEMTYPE_TRASH,                        "TRASH",          COUNT)

-- Trinkets: new gear slot from API 101052 (PTS 12.2). On live, ITEMTYPE_TRINKET is nil
-- and add() skips it. Trinkets with a set go through the gear branch in Classify.
add(ITEMTYPE_TRINKET,                      "TRINKET",        DETAIL)

-- Always by name
add(ITEMTYPE_FURNISHING,                   "FURNISHING",     DETAIL)
add(ITEMTYPE_RACIAL_STYLE_MOTIF,           "MOTIF",          DETAIL)
add(ITEMTYPE_COLLECTIBLE,                  "COLLECTIBLE",    DETAIL)
add(ITEMTYPE_TROPHY,                       "TROPHY",         DETAIL)

-- By name from the threshold up
add(ITEMTYPE_RECIPE,                       "RECIPE",         DETAIL_Q)
add(ITEMTYPE_CONTAINER,                    "CONTAINER",      DETAIL_Q)

-- Crafting materials (raw and refined in one category, so material tiers do not matter)
add(ITEMTYPE_BLACKSMITHING_RAW_MATERIAL,   "MAT_SMITH",      DETAIL_Q)
add(ITEMTYPE_BLACKSMITHING_MATERIAL,       "MAT_SMITH",      DETAIL_Q)
add(ITEMTYPE_CLOTHIER_RAW_MATERIAL,        "MAT_CLOTH",      DETAIL_Q)
add(ITEMTYPE_CLOTHIER_MATERIAL,            "MAT_CLOTH",      DETAIL_Q)
add(ITEMTYPE_WOODWORKING_RAW_MATERIAL,     "MAT_WOOD",       DETAIL_Q)
add(ITEMTYPE_WOODWORKING_MATERIAL,         "MAT_WOOD",       DETAIL_Q)
add(ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL, "MAT_JEWELRY",    DETAIL_Q)
add(ITEMTYPE_JEWELRYCRAFTING_MATERIAL,     "MAT_JEWELRY",    DETAIL_Q)
add(ITEMTYPE_RAW_MATERIAL,                 "MAT_STYLE",      DETAIL_Q)
add(ITEMTYPE_STYLE_MATERIAL,               "MAT_STYLE",      DETAIL_Q)
add(ITEMTYPE_ARMOR_TRAIT,                  "MAT_TRAIT",      DETAIL_Q)
add(ITEMTYPE_WEAPON_TRAIT,                 "MAT_TRAIT",      DETAIL_Q)
add(ITEMTYPE_JEWELRY_RAW_TRAIT,            "MAT_TRAIT",      DETAIL_Q)
add(ITEMTYPE_JEWELRY_TRAIT,                "MAT_TRAIT",      DETAIL_Q)
add(ITEMTYPE_FURNISHING_MATERIAL,          "MAT_FURNISHING", DETAIL_Q)

-- Tempers (green to gold; blue and up are shown by name with the default threshold)
add(ITEMTYPE_BLACKSMITHING_BOOSTER,        "TEMPER",         DETAIL_Q)
add(ITEMTYPE_CLOTHIER_BOOSTER,             "TEMPER",         DETAIL_Q)
add(ITEMTYPE_WOODWORKING_BOOSTER,          "TEMPER",         DETAIL_Q)
add(ITEMTYPE_JEWELRYCRAFTING_BOOSTER,      "TEMPER",         DETAIL_Q)
add(ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER,  "TEMPER",         DETAIL_Q)

-- Alchemy, provisioning, enchanting
add(ITEMTYPE_REAGENT,                      "REAGENT",        DETAIL_Q)
add(ITEMTYPE_POTION_BASE,                  "SOLVENT",        DETAIL_Q)
add(ITEMTYPE_POISON_BASE,                  "SOLVENT",        DETAIL_Q)
add(ITEMTYPE_INGREDIENT,                   "INGREDIENT",     DETAIL_Q)
add(ITEMTYPE_ENCHANTING_RUNE_ASPECT,       "RUNE_ASPECT",    DETAIL_Q)
add(ITEMTYPE_ENCHANTING_RUNE_ESSENCE,      "RUNE_ESSENCE",   DETAIL_Q)
add(ITEMTYPE_ENCHANTING_RUNE_POTENCY,      "RUNE_POTENCY",   DETAIL_Q)

-- Count only
add(ITEMTYPE_LURE,                         "LURE",           COUNT)
add(ITEMTYPE_FOOD,                         "CONSUMABLE",     COUNT)
add(ITEMTYPE_DRINK,                        "CONSUMABLE",     COUNT)
add(ITEMTYPE_POTION,                       "CONSUMABLE",     COUNT)
add(ITEMTYPE_POISON,                       "CONSUMABLE",     COUNT)
add(ITEMTYPE_GLYPH_ARMOR,                  "GLYPH",          COUNT)
add(ITEMTYPE_GLYPH_WEAPON,                 "GLYPH",          COUNT)
add(ITEMTYPE_GLYPH_JEWELRY,                "GLYPH",          COUNT)
add(ITEMTYPE_SOUL_GEM,                     "SOUL_GEM",       COUNT)
add(ITEMTYPE_LOCKPICK,                     "TOOL",           COUNT)
add(ITEMTYPE_TOOL,                         "TOOL",           COUNT)

-- Specialized types that get their own category (checked before itemType)
local BY_SPECIALIZED = {}
local function addSpecial(specializedType, key, mode)
    if specializedType == nil then return end
    BY_SPECIALIZED[specializedType] = { key = key, mode = mode }
    MODE_BY_KEY[key] = mode
end

addSpecial(SPECIALIZED_ITEMTYPE_CONTAINER_STYLE_PAGE,   "STYLE_PAGE",   DETAIL)
addSpecial(SPECIALIZED_ITEMTYPE_TROPHY_TREASURE_MAP,    "TREASURE_MAP", DETAIL)
addSpecial(SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT,   "SURVEY",       DETAIL)

local MISC = { key = "MISC", mode = COUNT }

-- Leather (raw and refined). The game does not tell cloth and leather apart by item type,
-- both are ITEMTYPE_CLOTHIER_(RAW_)MATERIAL. Any clothier material not listed here counts as cloth.
-- Item IDs as in CraftingMaterialLevelDisplay (ClothingMaterials.lua).
local LEATHER_IDS = {
    [793]   = true, [794]   = true,  -- rawhide scraps, rawhide          (1-14)
    [4448]  = true, [4447]  = true,  -- hide scraps, hide                (16-24)
    [23095] = true, [23099] = true,  -- leather scraps, leather          (26-34)
    [6020]  = true, [23100] = true,  -- thick leather scraps, thick leather (36-44)
    [23097] = true, [23101] = true,  -- fell hide scraps, fell hide      (46-50)
    [23142] = true, [46135] = true,  -- topgrain hide scraps, topgrain hide (CP10-30)
    [23143] = true, [46136] = true,  -- iron hide scraps, iron hide      (CP40-60)
    [800]   = true, [46137] = true,  -- superb hide scraps, superb hide  (CP70-80)
    [4478]  = true, [46138] = true,  -- shadowhide scraps, shadowhide    (CP90-140)
    [71239] = true, [64506] = true,  -- rubedo hide scraps, rubedo leather (CP150-160)
}

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------

local function GearSlot(itemLink, itemType)
    if itemType == ITEMTYPE_WEAPON then return "weapon" end
    if ITEMTYPE_TRINKET and itemType == ITEMTYPE_TRINKET then return "trinket" end
    local equipType = GetItemLinkEquipType(itemLink)
    if equipType == EQUIP_TYPE_NECK or equipType == EQUIP_TYPE_RING then
        return "jewelry"
    end
    return "armor"
end

local function IsCompanionGear(itemLink)
    if not GetItemLinkActorCategory or not GAMEPLAY_ACTOR_CATEGORY_COMPANION then return false end
    return GetItemLinkActorCategory(itemLink) == GAMEPLAY_ACTOR_CATEGORY_COMPANION
end

local function IsFurnishingPlan(itemLink)
    return IsItemLinkFurnitureRecipe ~= nil and IsItemLinkFurnitureRecipe(itemLink)
end

-- -----------------------------------------------------------------------------
-- Classify
-- -----------------------------------------------------------------------------

-- Classifies an item link.
-- Returns a table with
--   key     = category key (see WDH_CAT_NAMES)
--   quality = display quality
--   itemId  = item ID
--   setId, slot (set gear only)
function CAT.Classify(itemLink)
    local itemType, specializedType = GetItemLinkItemType(itemLink)
    local quality = GetItemLinkDisplayQuality(itemLink)
    local itemId  = GetItemLinkItemId(itemLink)

    -- Trinket with a set (whether these will exist is still open on the PTS)
    if ITEMTYPE_TRINKET and itemType == ITEMTYPE_TRINKET then
        local hasSet, _, _, _, _, setId = GetItemLinkSetInfo(itemLink, false)
        if hasSet and setId and setId > 0 then
            return { key = "SET", quality = quality, itemId = itemId, setId = setId, slot = "trinket" }
        end
    end

    -- Gear: set, companion or no set
    if itemType == ITEMTYPE_WEAPON or itemType == ITEMTYPE_ARMOR then
        local slot = GearSlot(itemLink, itemType)
        if IsCompanionGear(itemLink) then
            return { key = "GEAR_COMPANION", quality = quality, itemId = itemId }
        end
        local hasSet, _, _, _, _, setId = GetItemLinkSetInfo(itemLink, false)
        if hasSet and setId and setId > 0 then
            return { key = "SET", quality = quality, itemId = itemId, setId = setId, slot = slot }
        end
        return { key = "GEAR_" .. zo_strupper(slot), quality = quality, itemId = itemId }
    end

    local key = (BY_SPECIALIZED[specializedType] or BY_ITEMTYPE[itemType] or MISC).key
    if itemType == ITEMTYPE_RECIPE and IsFurnishingPlan(itemLink) then
        key = "FURNISHING_PLAN"
    elseif key == "MAT_CLOTH" and LEATHER_IDS[itemId] then
        key = "MAT_LEATHER"
    end
    return { key = key, quality = quality, itemId = itemId }
end

-- Display mode of a category (unknown keys are treated like COUNT)
function CAT.ModeOf(key)
    return MODE_BY_KEY[key] or COUNT
end
