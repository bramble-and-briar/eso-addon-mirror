-- Fixed game data the API doesn't expose outside a crafting station.
-- Everything that changes with new content (sets, styles, recipes, glyphs) comes from the game API,
-- LibCharacterKnowledge or LibLazyCrafting at run time instead, so it never needs updating here.

local addon = CanCraftMasterWrit
local Data = {}
addon.Data = Data

---------------------------------------------------------------------------------------------------
-- Writ kinds
---------------------------------------------------------------------------------------------------

Data.KIND_SMITHING = "smithing"
Data.KIND_ENCHANTING = "enchanting"
Data.KIND_ALCHEMY = "alchemy"
Data.KIND_PROVISIONING = "provisioning"

-- One sample writ item per writ type. Every writ of a type shares its item name, so comparing names
-- identifies a writ in any language. Item IDs from Dolgubon's Lazy Writ Crafter.
Data.SAMPLE_WRITS = {
    { itemId = 119680, kind = Data.KIND_SMITHING, craftType = CRAFTING_TYPE_BLACKSMITHING },
    { itemId = 121532, kind = Data.KIND_SMITHING, craftType = CRAFTING_TYPE_CLOTHIER },
    { itemId = 119682, kind = Data.KIND_SMITHING, craftType = CRAFTING_TYPE_WOODWORKING },
    { itemId = 153737, kind = Data.KIND_SMITHING, craftType = CRAFTING_TYPE_JEWELRYCRAFTING },
    { itemId = 119564, kind = Data.KIND_ENCHANTING, craftType = CRAFTING_TYPE_ENCHANTING },
    { itemId = 119705, kind = Data.KIND_ALCHEMY, craftType = CRAFTING_TYPE_ALCHEMY },
    { itemId = 119693, kind = Data.KIND_PROVISIONING, craftType = CRAFTING_TYPE_PROVISIONING, event = "master" },
    -- Holiday event writs ask for a provisioning dish, in different amounts.
    { itemId = 153482, kind = Data.KIND_PROVISIONING, craftType = CRAFTING_TYPE_PROVISIONING, event = "witchesFestival" },
    { itemId = 145572, kind = Data.KIND_PROVISIONING, craftType = CRAFTING_TYPE_PROVISIONING, event = "newLife" },
    { itemId = 156735, kind = Data.KIND_PROVISIONING, craftType = CRAFTING_TYPE_PROVISIONING, event = "deepWinter" },
    { itemId = 167172, kind = Data.KIND_PROVISIONING, craftType = CRAFTING_TYPE_PROVISIONING, event = "imperial" },
}

---------------------------------------------------------------------------------------------------
-- Smithing
---------------------------------------------------------------------------------------------------

-- Master writs always ask for champion point 150 gear. This is the material index LibLazyCrafting uses for it.
Data.SMITHING_CP150_MATERIAL_INDEX = 40

-- The champion point 150 material for each craft.
Data.SMITHING_CP150_MATERIAL = {
    [CRAFTING_TYPE_BLACKSMITHING] = 64489,   -- Rubedite Ingot
    [CRAFTING_TYPE_CLOTHIER] = 64504,        -- Ancestor Silk (light armour)
    [CRAFTING_TYPE_WOODWORKING] = 64502,     -- Sanded Ruby Ash
    [CRAFTING_TYPE_JEWELRYCRAFTING] = 135146, -- Platinum Ounce
}
Data.SMITHING_CP150_LEATHER = 64506 -- Rubedo Leather (medium armour)
Data.CLOTHIER_FIRST_LEATHER_PATTERN = 9

-- Motif chapter for each crafting pattern, by craft. Pattern order is the game's crafting station order.
local C = {
    AXES = ITEM_STYLE_CHAPTER_AXES, BELTS = ITEM_STYLE_CHAPTER_BELTS, BOOTS = ITEM_STYLE_CHAPTER_BOOTS,
    BOWS = ITEM_STYLE_CHAPTER_BOWS, CHESTS = ITEM_STYLE_CHAPTER_CHESTS, DAGGERS = ITEM_STYLE_CHAPTER_DAGGERS,
    GLOVES = ITEM_STYLE_CHAPTER_GLOVES, HELMETS = ITEM_STYLE_CHAPTER_HELMETS, LEGS = ITEM_STYLE_CHAPTER_LEGS,
    MACES = ITEM_STYLE_CHAPTER_MACES, SHIELDS = ITEM_STYLE_CHAPTER_SHIELDS,
    SHOULDERS = ITEM_STYLE_CHAPTER_SHOULDERS, STAVES = ITEM_STYLE_CHAPTER_STAVES,
    SWORDS = ITEM_STYLE_CHAPTER_SWORDS,
}
Data.MOTIF_CHAPTER_BY_PATTERN = {
    -- Axe, Mace, Sword, Battle Axe, Maul, Greatsword, Dagger, Cuirass, Sabatons, Gauntlets, Helm, Greaves,
    -- Pauldron, Girdle.
    [CRAFTING_TYPE_BLACKSMITHING] = {
        C.AXES, C.MACES, C.SWORDS, C.AXES, C.MACES, C.SWORDS, C.DAGGERS,
        C.CHESTS, C.BOOTS, C.GLOVES, C.HELMETS, C.LEGS, C.SHOULDERS, C.BELTS,
    },
    -- Robe, Jerkin, Shoes, Gloves, Hat, Breeches, Epaulets, Sash, then Jack, Boots, Bracers, Helmet, Guards,
    -- Arm Cops, Belt.
    [CRAFTING_TYPE_CLOTHIER] = {
        C.CHESTS, C.CHESTS, C.BOOTS, C.GLOVES, C.HELMETS, C.LEGS, C.SHOULDERS, C.BELTS,
        C.CHESTS, C.BOOTS, C.GLOVES, C.HELMETS, C.LEGS, C.SHOULDERS, C.BELTS,
    },
    -- Bow, Shield, Inferno Staff, Ice Staff, Lightning Staff, Restoration Staff.
    [CRAFTING_TYPE_WOODWORKING] = { C.BOWS, C.SHIELDS, C.STAVES, C.STAVES, C.STAVES, C.STAVES },
}

-- Converts a crafting pattern to its trait research line. They differ for clothing (robe and jerkin share
-- a line) and woodworking (the shield's line comes last). Same mapping as LibLazyCrafting.
function Data.GetResearchLineForPattern(craftType, pattern)
    if craftType == CRAFTING_TYPE_CLOTHIER then
        return pattern > 1 and pattern - 1 or pattern
    elseif craftType == CRAFTING_TYPE_WOODWORKING then
        return ({ 1, 6, 2, 3, 4, 5 })[pattern]
    end
    return pattern
end

-- Improvement materials needed per quality step, by rank in the craft's improvement passive (0 to 3).
-- Steps: Normal to Fine, Fine to Superior, Superior to Epic, Epic to Legendary.
Data.IMPROVEMENT_MATERIAL_COUNTS = {
    [0] = { 5, 7, 10, 20 },
    [1] = { 4, 5, 7, 14 },
    [2] = { 3, 4, 5, 10 },
    [3] = { 2, 3, 4, 8 },
}

-- Traits needed to craft a set, by set ID, where LibLazyCrafting 4.042 has the wrong number. Every other set comes
-- from LibLazyCrafting. Checked against UESP and LibSets (Baertram), October 2026.
Data.SET_TRAITS_REQUIRED_FIXES = {
    [490] = 5, -- Stuhn's Favor
    [491] = 7, -- Dragon's Appetite
    [678] = 3, -- Old Growth Brewer
    [679] = 5, -- Claw of the Forest Wraith
    [695] = 5, -- Shattered Fate
    [696] = 3, -- Telvanni Efficiency
}

-- Ability IDs of the improvement passives (Temper, Tannin, Resin and Platings Expertise).
Data.IMPROVEMENT_PASSIVE = {
    [CRAFTING_TYPE_BLACKSMITHING] = 48168,
    [CRAFTING_TYPE_CLOTHIER] = 48198,
    [CRAFTING_TYPE_WOODWORKING] = 48177,
    [CRAFTING_TYPE_JEWELRYCRAFTING] = 103648,
}

-- The same passives as NonCombatBonus types, used if the ability lookup fails.
Data.IMPROVEMENT_BONUS = {
    [CRAFTING_TYPE_BLACKSMITHING] = NON_COMBAT_BONUS_BLACKSMITHING_BOOSTER_BONUS,
    [CRAFTING_TYPE_CLOTHIER] = NON_COMBAT_BONUS_CLOTHIER_BOOSTER_BONUS,
    [CRAFTING_TYPE_WOODWORKING] = NON_COMBAT_BONUS_WOODWORKING_BOOSTER_BONUS,
    [CRAFTING_TYPE_JEWELRYCRAFTING] = NON_COMBAT_BONUS_JEWELRYCRAFTING_BOOSTER_BONUS,
}

---------------------------------------------------------------------------------------------------
-- Enchanting
---------------------------------------------------------------------------------------------------

-- The writ's level field, as champion points.
Data.GLYPH_LEVEL_TO_CHAMPION_POINTS = {
    [207] = 150,
    [225] = 160,
}

-- Aspect runes by glyph quality: Ta, Jejota, Denata, Rekuta, Kuta.
Data.ASPECT_RUNES = { 45850, 45851, 45852, 45853, 45854 }

Data.ASPECT_IMPROVEMENT_PASSIVE = 46763

---------------------------------------------------------------------------------------------------
-- Alchemy
---------------------------------------------------------------------------------------------------

-- The writ's base field: 199 asks for a potion, 239 for a poison.
Data.ALCHEMY_POTION_BASE = 199
Data.ALCHEMY_POISON_BASE = 239
Data.ALCHEMY_POTION_SOLVENT = 64501 -- Lorkhan's Tears
Data.ALCHEMY_POISON_SOLVENT = 75365 -- Alkahest
Data.ALCHEMY_ITEMS_REQUIRED = 16    -- Master writs ask for 16 potions or poisons.

-- The effects of every reagent. Odd numbers are positive effects and the even number after each is its
-- opposite (1 Restore Health, 2 Ravage Health, and so on); master writs use the same numbers.
-- Reagent effects from Dolgubon's Lazy Writ Crafter (Update 51).
Data.REAGENT_EFFECTS = {
    [30148] = { 1, 4, 22, 34 },
    [30149] = { 2, 6, 10, 35 },
    [30151] = { 2, 4, 6, 20 },
    [30152] = { 2, 4, 8, 11 },
    [30153] = { 19, 22, 23, 36 },
    [30154] = { 4, 7, 21, 36 },
    [30155] = { 1, 6, 12, 24 },
    [30156] = { 6, 9, 12, 36 },
    [30157] = { 5, 11, 23, 34 },
    [30158] = { 3, 8, 15, 35 },
    [30159] = { 15, 19, 21, 24 },
    [30160] = { 1, 3, 7, 37 },
    [30161] = { 2, 3, 11, 21 },
    [30162] = { 5, 10, 11, 15 },
    [30163] = { 1, 5, 9, 12 },
    [30164] = { 1, 3, 5, 19 },
    [30165] = { 2, 16, 22, 34 },
    [30166] = { 1, 15, 20, 33 },
    [77581] = { 10, 16, 21, 37 },
    [77583] = { 8, 9, 25, 29 },
    [77584] = { 22, 24, 30, 33 },
    [77585] = { 1, 27, 29, 33 },
    [77587] = { 6, 26, 28, 29 },
    [77589] = { 23, 26, 27, 38 },
    [77590] = { 2, 25, 28, 30 },
    [77591] = { 7, 9, 25, 30 },
    [139019] = { 23, 25, 29, 37 },
    [139020] = { 7, 24, 26, 30 },
    [150669] = { 4, 21, 32, 38 },
    [150670] = { 2, 3, 25, 32 },
    [150671] = { 3, 16, 23, 31 },
    [150672] = { 1, 28, 32, 35 },
    [150731] = { 5, 27, 30, 31 },
    [150789] = { 22, 26, 29, 31 },
    [224357] = { 11, 31, 33, 37 },
    [224358] = { 12, 20, 30, 34 },
    [224359] = { 5, 21, 31, 35 },
    [224360] = { 8, 30, 34, 38 },
}

---------------------------------------------------------------------------------------------------
-- Provisioning
---------------------------------------------------------------------------------------------------

Data.RECIPE_QUALITY_PASSIVE = 69953

-- How many items (food, drink or furnishings) each writ type asks for. Event amounts depend on the item's quality;
-- amounts from Dolgubon's Lazy Writ Crafter. Returns nil when the amount isn't known.
function Data.GetProvisioningItemsRequired(event, resultItemId, displayQuality, isFurnishing)
    if event == "master" then
        return 8
    elseif event == "witchesFestival" then
        return 4
    elseif event == "newLife" then
        if displayQuality == ITEM_DISPLAY_QUALITY_MAGIC then
            return 1
        elseif displayQuality == ITEM_DISPLAY_QUALITY_NORMAL then
            return 12
        end
    elseif event == "deepWinter" then
        if displayQuality == ITEM_DISPLAY_QUALITY_MAGIC then
            return 1
        elseif displayQuality == ITEM_DISPLAY_QUALITY_NORMAL then
            return (resultItemId == 120410 or resultItemId == 117943) and 3 or 12
        end
    elseif event == "imperial" then
        if displayQuality == ITEM_DISPLAY_QUALITY_NORMAL then
            return 3
        elseif displayQuality == ITEM_DISPLAY_QUALITY_MAGIC then
            -- Lazy Writ Crafter's rule: twelve of a green dish or drink, one green furnishing.
            return isFurnishing and 1 or 12
        end
    end
    return nil
end
