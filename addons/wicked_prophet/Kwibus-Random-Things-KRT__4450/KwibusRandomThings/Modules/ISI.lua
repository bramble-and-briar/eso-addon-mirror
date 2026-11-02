-- =============================================================================
-- Kwibus Isiibus Equipped (ISI)
-- =============================================================================
-- Lightweight on-screen display of currently equipped gear sets, armor weights,
-- armor traits, and jewelry traits, with alerts for missing items or invalid skills.
-- =============================================================================

KwibusRandomThings = KwibusRandomThings or {}
local KRT = KwibusRandomThings
local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER
local ADDON_NAME = KRT.name or "KwibusRandomThings"

-- Resilient table clear fallback (used by table recycling pools)
local ZO_ClearTable = ZO_ClearTable or function(t)
    if not t then return end
    for k in pairs(t) do
        t[k] = nil
    end
end

-- =========================================================
-- SavedVariables Defaults & Accessor
-- =========================================================

local DEFAULTS = { isi = {
    enabled = true,
    offsetX = 300,
    offsetY = 300,
    uiScale = 1.0,
    enableReposition = false,
    showArmorWeights = true,
    showArmorTraits = true,
    colorCodedTraits = true,
    hasForcedTraitColoringOnce = false,
    showJewelryTraits = true,
    colorCodedJewelryTraits = true,
    hasForcedJewelryTraitColoringOnce = false,
    showAbilityWarning = true,
    showMissingGearWarning = true,
    showLocationTags = true,
    columnSpacing = 45,
    tagSpacing = 40,
    nameSpacing = 180,
    showInMenus = true,
    hideInCombat = false,
    bgOpacity = 25,
    colorMonster = { 1, 1, 1 },
    colorMythic = { 1, 1, 1 },
    colorRegular = { 1, 1, 1 },
} }

KRT.ISI = {
    id = "isi",
    defaults = DEFAULTS.isi,
    ui = nil,
    wLight = nil,
    wMedium = nil,
    wHeavy = nil,
    wTraitsShort = nil,
    wJewelryTraits = nil,
    labels = {},
    _eventsRegistered = false,
}

function KRT.ISI:SV()
    if not self.sv then
        self.sv = KRT.GetModuleSV(self.id, self.defaults)
    end
    return self.sv
end

local function SV()
    return KRT.ISI:SV()
end

-- =========================================================
-- Color & Font Constants
-- =========================================================

-- Champion Point category colors
local CP_BLUE = {0.36, 0.64, 1.00, 1}
local CP_GREEN = {0.36, 1.00, 0.36, 1}
local CP_RED = {1.00, 0.36, 0.36, 1}

-- Fonts & row metrics
local ROW_FONT = "ZoFontGame"
local HEADER_FONT = "ZoFontGame"
local ROW_H = 21
local STAT_COLOR = {0.925, 0.925, 1.000, 1}
local GREEN = {0.36, 1.00, 0.36, 1}
local RED = {1.00, 0.36, 0.36, 1}

-- =========================================================
-- Armor Trait Color Coding & Formatting
-- =========================================================

-- Armor trait hex colors (with resilient fallbacks for ESO enum variants).
-- Meta traits receive high-visibility tones, while progression traits use muted shades.
local TRAIT_HEX_COLORS = {
    -- Core Meta Traits (High Visibility)
    [ITEM_TRAIT_TYPE_ARMOR_DIVINES or ITEM_TRAIT_TYPE_DIVINES or 18]         = "FFD700", -- Radiant Gold
    [ITEM_TRAIT_TYPE_ARMOR_INFUSED or ITEM_TRAIT_TYPE_INFUSED or 16]         = "00E5FF", -- Arcane Cyan
    [ITEM_TRAIT_TYPE_ARMOR_STURDY or ITEM_TRAIT_TYPE_STURDY or 11]           = "FF9900", -- Amber Orange
    [ITEM_TRAIT_TYPE_ARMOR_REINFORCED or ITEM_TRAIT_TYPE_REINFORCED or 13]   = "80C8FF", -- Steel Ice Blue
    [ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED or ITEM_TRAIT_TYPE_WELL_FITTED or 14] = "00FF66", -- Neon Green

    -- Niche Combat
    [ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE or ITEM_TRAIT_TYPE_IMPENETRABLE or 12]     = "FF3344", -- Crimson Red
    [ITEM_TRAIT_TYPE_ARMOR_INVIGORATING or ITEM_TRAIT_TYPE_INVIGORATING or 25]     = "C678DD", -- Soft Orchid Purple
    [ITEM_TRAIT_TYPE_ARMOR_NIRNHONED or ITEM_TRAIT_TYPE_NIRNHONED or 26]           = "C85A32", -- Copper Maroon

    -- Progression / Economy (Muted)
    [ITEM_TRAIT_TYPE_ARMOR_TRAINING or ITEM_TRAIT_TYPE_TRAINING or 15]   = "98C379", -- Muted Olive
    [ITEM_TRAIT_TYPE_ARMOR_INTRICATE or ITEM_TRAIT_TYPE_INTRICATE or 20] = "828997", -- Slate Gray
    [ITEM_TRAIT_TYPE_ARMOR_ORNATE or ITEM_TRAIT_TYPE_ORNATE or 19]       = "A07A48", -- Muted Bronze
}

-- Wraps armor trait text in the corresponding hex color tag if color coding is defined.
-- Returns original text unchanged if no color mapping exists.
local function ColorizeTrait(traitType, text)
    if not traitType or not text then return text or "" end
    local hex = TRAIT_HEX_COLORS[traitType]
    if hex then
        return string.format("|c%s%s|r", hex, text)
    end
    return text
end

-- =========================================================
-- Jewelry Trait Color Coding & Formatting
-- =========================================================

-- Jewelry trait hex colors mapping ESO trait types to distinct colors:
--   * Combat / Meta traits receive vibrant, high-contrast colors:
--       - Bloodthirsty: Crimson Red ("FF3344")
--       - Infused: Arcane Cyan ("00E5FF")
--       - Harmony: Soft Orchid Purple ("C678DD")
--       - Triune: Radiant Gold ("FFD700")
--       - Swift: Neon Green ("00FF66")
--   * Resource traits match standard resource colors:
--       - Arcane: Magicka Blue ("4FC3F7")
--       - Robust: Stamina Amber ("FF9900")
--       - Healthy: Health Green ("98C379")
--   * Non-combat / Economy traits use muted tones:
--       - Protective / Intricate: Slate Gray ("828997")
--       - Ornate: Muted Bronze ("A07A48")
-- Includes numeric enum fallbacks in case constants are not yet initialized.
local JEWELRY_TRAIT_HEX_COLORS = {
    -- Core Meta / Combat (High Visibility)
    [ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY or 31] = "FF3344", -- Crimson Red
    [ITEM_TRAIT_TYPE_JEWELRY_INFUSED or 33]      = "00E5FF", -- Arcane Cyan
    [ITEM_TRAIT_TYPE_JEWELRY_HARMONY or 29]      = "C678DD", -- Soft Orchid Purple
    [ITEM_TRAIT_TYPE_JEWELRY_TRIUNE or 30]       = "FFD700", -- Radiant Gold
    [ITEM_TRAIT_TYPE_JEWELRY_SWIFT or 28]        = "00FF66", -- Neon Green

    -- Resources
    [ITEM_TRAIT_TYPE_JEWELRY_ARCANE or 22]       = "4FC3F7", -- Magicka Blue
    [ITEM_TRAIT_TYPE_JEWELRY_ROBUST or 23]       = "FF9900", -- Stamina Amber
    [ITEM_TRAIT_TYPE_JEWELRY_HEALTHY or 21]      = "98C379", -- Health Green

    -- Non-useful / Progression / Economy (Muted)
    [ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE or 32]   = "828997", -- Slate Gray (Off-meta)
    [ITEM_TRAIT_TYPE_JEWELRY_INTRICATE or 27]    = "828997", -- Slate Gray
    [ITEM_TRAIT_TYPE_JEWELRY_ORNATE or 24]       = "A07A48", -- Muted Bronze
}

-- Wraps jewelry trait text in the corresponding hex color tag if color coding is defined.
-- Returns original text unchanged if no color mapping exists.
local function ColorizeJewelryTrait(traitType, text)
    if not traitType or not text then return text or "" end
    local hex = JEWELRY_TRAIT_HEX_COLORS[traitType]
    if hex then
        return string.format("|c%s%s|r", hex, text)
    end
    return text
end

-- =========================================================
-- Equipment Slots & Item Classification
-- =========================================================

-- Equipment slot arrays
local ARMOR_SLOTS = {
    EQUIP_SLOT_HEAD, EQUIP_SLOT_SHOULDERS, EQUIP_SLOT_CHEST,
    EQUIP_SLOT_HAND, EQUIP_SLOT_WAIST, EQUIP_SLOT_LEGS, EQUIP_SLOT_FEET,
}
local JEWELRY_SLOTS = { EQUIP_SLOT_NECK, EQUIP_SLOT_RING1, EQUIP_SLOT_RING2 }
local MAIN_BAR_SLOTS = { EQUIP_SLOT_MAIN_HAND, EQUIP_SLOT_OFF_HAND }
local BACK_BAR_SLOTS = { EQUIP_SLOT_BACKUP_MAIN, EQUIP_SLOT_BACKUP_OFF }

local TWO_HANDED_WEAPON_TYPES = {
    [WEAPONTYPE_TWO_HANDED_AXE] = true,
    [WEAPONTYPE_TWO_HANDED_HAMMER] = true,
    [WEAPONTYPE_TWO_HANDED_SWORD] = true,
    [WEAPONTYPE_BOW] = true,
    [WEAPONTYPE_FIRE_STAFF] = true,
    [WEAPONTYPE_FROST_STAFF] = true,
    [WEAPONTYPE_LIGHTNING_STAFF] = true,
    [WEAPONTYPE_HEALING_STAFF] = true,
}

-- Sets with special viable piece thresholds where wearing fewer than the maximum pieces is a valid build choice
local SPECIAL_SET_MIN_PIECES = {
    [163] = 1, -- Armor of the Trainee (1pc Max Health bonus)
    [548] = 1, -- Druid's Braid (1pc Max Health bonus)
    [153] = 2, -- Blessing of the Potentates (2pc Ultimate Cost Reduction)
    [181] = 2, -- Willpower (2pc Max Magicka)
    [216] = 2, -- Eyes of Mara (2pc Max Magicka)
}

local function isTwoHanded(itemLink)
    if not itemLink or itemLink == "" then return false end
    local weaponType = GetItemLinkWeaponType(itemLink)
    return TWO_HANDED_WEAPON_TYPES[weaponType] or false
end

-- =========================================================
-- Localization & Formatting Helpers
-- =========================================================

-- Helper to properly format localized strings (removes ^m, ^f, ^p, and grammatic tags)
local function FormatLocalizedString(rawName)
    if not rawName or rawName == "" then return "" end
    if zo_strformat then
        return zo_strformat("<<1>>", rawName)
    end
    return rawName
end

-- Capitalize first letter safely using ESO's string formatting specifier <<C:1>>
local function CapitalizeFirstLetter(str)
    if not str or str == "" then return "" end
    if zo_strformat then
        return zo_strformat("<<C:1>>", str)
    end
    return str:sub(1, 1):upper() .. str:sub(2)
end

-- =========================================================
-- Trait Name Caching (Armor & Jewelry)
-- =========================================================

-- Fallback English names for armor traits when SI_ITEMTRAITTYPE lookup is unavailable.
local ARMOR_TRAIT_FALLBACK_NAMES = {
    [ITEM_TRAIT_TYPE_ARMOR_DIVINES or 18]         = "Divines",
    [ITEM_TRAIT_TYPE_ARMOR_INFUSED or 16]         = "Infused",
    [ITEM_TRAIT_TYPE_ARMOR_STURDY or 11]           = "Sturdy",
    [ITEM_TRAIT_TYPE_ARMOR_REINFORCED or 13]       = "Reinforced",
    [ITEM_TRAIT_TYPE_ARMOR_WELL_FITTED or 14]     = "Well-fitted",
    [ITEM_TRAIT_TYPE_ARMOR_IMPENETRABLE or 12]     = "Impenetrable",
    [ITEM_TRAIT_TYPE_ARMOR_INVIGORATING or 25]     = "Invigorating",
    [ITEM_TRAIT_TYPE_ARMOR_NIRNHONED or 26]       = "Nirnhoned",
    [ITEM_TRAIT_TYPE_ARMOR_TRAINING or 15]         = "Training",
    [ITEM_TRAIT_TYPE_ARMOR_INTRICATE or 20]        = "Intricate",
    [ITEM_TRAIT_TYPE_ARMOR_ORNATE or 19]           = "Ornate",
}

-- Fallback English names for jewelry traits when SI_ITEMTRAITTYPE lookup is unavailable.
local JEWELRY_TRAIT_FALLBACK_NAMES = {
    [ITEM_TRAIT_TYPE_JEWELRY_ARCANE or 22]        = "Arcane",
    [ITEM_TRAIT_TYPE_JEWELRY_ROBUST or 23]        = "Robust",
    [ITEM_TRAIT_TYPE_JEWELRY_HEALTHY or 21]       = "Healthy",
    [ITEM_TRAIT_TYPE_JEWELRY_BLOODTHIRSTY or 31]  = "Bloodthirsty",
    [ITEM_TRAIT_TYPE_JEWELRY_HARMONY or 29]       = "Harmony",
    [ITEM_TRAIT_TYPE_JEWELRY_INFUSED or 33]       = "Infused",
    [ITEM_TRAIT_TYPE_JEWELRY_TRIUNE or 30]        = "Triune",
    [ITEM_TRAIT_TYPE_JEWELRY_SWIFT or 28]         = "Swift",
    [ITEM_TRAIT_TYPE_JEWELRY_PROTECTIVE or 32]    = "Protective",
    [ITEM_TRAIT_TYPE_JEWELRY_INTRICATE or 27]     = "Intricate",
    [ITEM_TRAIT_TYPE_JEWELRY_ORNATE or 24]        = "Ornate",
}

-- Armor trait full name cache to eliminate repeated string formatting in sort comparators.
local _traitFullCache = {}

-- Safely retrieves and caches the localized full name of an armor trait.
-- Performs safe lookup via pcall(GetString, "SI_ITEMTRAITTYPE", traitType) with fallback
-- to ARMOR_TRAIT_FALLBACK_NAMES if missing or empty.
local function GetArmorTraitNameFull(traitType)
    local noneTrait = ITEM_TRAIT_TYPE_NONE or 0
    if not traitType or traitType == noneTrait or traitType == 0 then return "" end
    local cached = _traitFullCache[traitType]
    if cached then return cached end

    local rawName = nil
    if GetString then
        local ok, str = pcall(GetString, "SI_ITEMTRAITTYPE", traitType)
        if ok and str and str ~= "" then
            rawName = str
        end
    end
    if (not rawName or rawName == "") and ARMOR_TRAIT_FALLBACK_NAMES then
        rawName = ARMOR_TRAIT_FALLBACK_NAMES[traitType]
    end

    cached = rawName and FormatLocalizedString(rawName) or ""
    _traitFullCache[traitType] = cached
    return cached
end

-- Armor trait short abbreviation cache.
local _traitShortCache = {}

-- Safely retrieves and caches a 4-character abbreviation or single-word short name
-- for an armor trait, used when multiple distinct traits are equipped.
local function GetArmorTraitShort(traitType)
    local cached = _traitShortCache[traitType]
    if cached then return cached end
    local full = GetArmorTraitNameFull(traitType)
    if full == "" then return "" end
    
    local firstWord = full:match("^(%S+)") or full
    local len = zo_strlen and zo_strlen(firstWord) or string.len(firstWord)
    local sub = zo_strsub or string.sub
    cached = (len > 5) and sub(firstWord, 1, 4) or firstWord
    _traitShortCache[traitType] = cached
    return cached
end

-- Jewelry trait full name cache to eliminate repeated string formatting and lookups.
local _jewelryTraitFullCache = {}

-- Safely retrieves and caches the localized full name of a jewelry trait.
-- Performs safe lookup via pcall(GetString, "SI_ITEMTRAITTYPE", traitType) with fallback
-- to JEWELRY_TRAIT_FALLBACK_NAMES if missing or empty.
local function GetJewelryTraitNameFull(traitType)
    local noneTrait = ITEM_TRAIT_TYPE_NONE or 0
    if not traitType or traitType == noneTrait or traitType == 0 then return "" end
    local cached = _jewelryTraitFullCache[traitType]
    if cached then return cached end

    local rawName = nil
    if GetString then
        local ok, str = pcall(GetString, "SI_ITEMTRAITTYPE", traitType)
        if ok and str and str ~= "" then
            rawName = str
        end
    end
    if (not rawName or rawName == "") and JEWELRY_TRAIT_FALLBACK_NAMES then
        rawName = JEWELRY_TRAIT_FALLBACK_NAMES[traitType]
    end

    cached = rawName and FormatLocalizedString(rawName) or ""
    _jewelryTraitFullCache[traitType] = cached
    return cached
end

-- Jewelry trait short abbreviation cache.
local _jewelryTraitShortCache = {}

-- Safely retrieves and caches a 4-character abbreviation or single-word short name
-- for a jewelry trait, used when more than 2 distinct traits are worn across jewelry slots.
local function GetJewelryTraitShort(traitType)
    local cached = _jewelryTraitShortCache[traitType]
    if cached then return cached end
    local full = GetJewelryTraitNameFull(traitType)
    if full == "" then return "" end
    
    local firstWord = full:match("^(%S+)") or full
    local len = zo_strlen and zo_strlen(firstWord) or string.len(firstWord)
    local sub = zo_strsub or string.sub
    cached = (len > 5) and sub(firstWord, 1, 4) or firstWord
    _jewelryTraitShortCache[traitType] = cached
    return cached
end

-- =========================================================
-- Set Name Cleaning (Multi-language Support)
-- =========================================================

-- Multi-language cleaning for "Perfected" prefix/suffix
local PERFECTED_PATTERNS = {
    -- English
    "^Perfected%s+",
    "%s+Perfected$",
    -- Russian (Совершенный, Совершенная, Совершенное, Совершенные)
    "^Совершенный%s+",
    "^Совершенная%s+",
    "^Совершенное%s+",
    "^Совершенные%s+",
    "%s+Совершенный$",
    "%s+Совершенная$",
    "%s+Совершенное$",
    "%s+Совершенные$",
    -- German
    "^Perfektioniertes%s+",
    "^Perfektionierte%s+",
    "^Perfektionierter%s+",
    -- French
    "^Parfait%s+",
    "^Parfaite%s+",
    "%s+parfait$",
    "%s+parfaite$",
}

local _cleanedSetNameCache = {}
local function CleanSetName(setName)
    if not setName or setName == "" then return "" end
    local cached = _cleanedSetNameCache[setName]
    if cached then return cached end

    local clean = FormatLocalizedString(setName)
    
    -- Strip brackets if present [Perfected] / [Совершенный]
    clean = clean:gsub("%[%s*.-%s*%]", "")
    
    -- Strip localized perfected words
    for _, pattern in ipairs(PERFECTED_PATTERNS) do
        clean = clean:gsub(pattern, "")
    end
    
    clean = zo_strtrim and zo_strtrim(clean) or clean:match("^%s*(.-)%s*$")
    
    -- Capitalize first character reliably via <<C:1>>
    cached = CapitalizeFirstLetter(clean)
    _cleanedSetNameCache[setName] = cached
    return cached
end

-- =========================================================
-- Armor Weights & Traits Aggregation (Recycled Pool)
-- =========================================================

local _cachedWeights = { light = 0, medium = 0, heavy = 0 }
local _cachedTraitsMap = {}
local _cachedTraitsList = {}
local _traitEntryPool = {}

-- Retrieves a recycled entry table from _traitEntryPool (or allocates a new one),
-- initializing it with the specified traitType and piece count.
local function GetTraitEntry(traitType, count)
    local entry = table.remove(_traitEntryPool)
    if not entry then
        entry = {}
    end
    entry.traitType = traitType
    entry.count = count
    return entry
end

-- Sort comparator for armor traits:
-- Sorts primarily by descending count (highest piece count first), secondarily by short name,
-- and falls back to traitType ID for strict deterministic ordering.
local function SortTraits(a, b)
    if a.count ~= b.count then return a.count > b.count end
    local an = GetArmorTraitShort(a.traitType)
    local bn = GetArmorTraitShort(b.traitType)
    if an ~= bn then return an < bn end
    return (a.traitType or 0) < (b.traitType or 0)
end

-- Aggregates equipped armor weights (Light, Medium, Heavy) and worn armor traits.
-- Recycles existing entries into _traitEntryPool to avoid garbage collection churn.
local function GetArmorWeightsAndTraits()
    _cachedWeights.light = 0
    _cachedWeights.medium = 0
    _cachedWeights.heavy = 0
    ZO_ClearTable(_cachedTraitsMap)

    for i = #_cachedTraitsList, 1, -1 do
        table.insert(_traitEntryPool, _cachedTraitsList[i])
        _cachedTraitsList[i] = nil
    end

    local noneTrait = ITEM_TRAIT_TYPE_NONE or 0
    for _, slot in ipairs(ARMOR_SLOTS) do
        if HasItemInSlot(BAG_WORN, slot) then
            local at = GetItemArmorType(BAG_WORN, slot)
            if at == ARMORTYPE_LIGHT then _cachedWeights.light = _cachedWeights.light + 1
            elseif at == ARMORTYPE_MEDIUM then _cachedWeights.medium = _cachedWeights.medium + 1
            elseif at == ARMORTYPE_HEAVY then _cachedWeights.heavy = _cachedWeights.heavy + 1 end
            
            local traitType = GetItemTrait(BAG_WORN, slot)
            if traitType and traitType ~= noneTrait and traitType ~= 0 then
                _cachedTraitsMap[traitType] = (_cachedTraitsMap[traitType] or 0) + 1
            end
        end
    end

    for t, c in pairs(_cachedTraitsMap) do
        table.insert(_cachedTraitsList, GetTraitEntry(t, c))
    end
    table.sort(_cachedTraitsList, SortTraits)
    return _cachedWeights, _cachedTraitsList
end

-- =========================================================
-- Jewelry Traits Aggregation (Recycled Pool)
-- =========================================================

local _cachedJewelryTraitsMap = {}
local _cachedJewelryTraitsList = {}
local _jewelryTraitEntryPool = {}

-- Retrieves a recycled entry table from _jewelryTraitEntryPool (or allocates a new one),
-- initializing it with the specified traitType and piece count.
local function GetJewelryTraitEntry(traitType, count)
    local entry = table.remove(_jewelryTraitEntryPool)
    if not entry then
        entry = {}
    end
    entry.traitType = traitType
    entry.count = count
    return entry
end

-- Sort comparator for jewelry trait entries:
-- Sorts primarily by descending count (highest piece count first), secondarily by short name,
-- and falls back to traitType ID for strict deterministic weak ordering.
local function SortJewelryTraits(a, b)
    if a.count ~= b.count then return a.count > b.count end
    local an = GetJewelryTraitShort(a.traitType)
    local bn = GetJewelryTraitShort(b.traitType)
    if an ~= bn then return an < bn end
    return (a.traitType or 0) < (b.traitType or 0)
end

-- Scans equipped jewelry slots (Neck, Ring 1, Ring 2) for active item traits.
-- Recycles existing entries into _jewelryTraitEntryPool, aggregates trait counts,
-- and returns a sorted list of active jewelry traits.
local function GetJewelryTraits()
    ZO_ClearTable(_cachedJewelryTraitsMap)

    for i = #_cachedJewelryTraitsList, 1, -1 do
        table.insert(_jewelryTraitEntryPool, _cachedJewelryTraitsList[i])
        _cachedJewelryTraitsList[i] = nil
    end

    local noneTrait = ITEM_TRAIT_TYPE_NONE or 0
    for _, slot in ipairs(JEWELRY_SLOTS) do
        if HasItemInSlot(BAG_WORN, slot) then
            local traitType = GetItemTrait(BAG_WORN, slot)
            if traitType and traitType ~= noneTrait and traitType ~= 0 then
                _cachedJewelryTraitsMap[traitType] = (_cachedJewelryTraitsMap[traitType] or 0) + 1
            end
        end
    end

    for t, c in pairs(_cachedJewelryTraitsMap) do
        table.insert(_cachedJewelryTraitsList, GetJewelryTraitEntry(t, c))
    end
    table.sort(_cachedJewelryTraitsList, SortJewelryTraits)
    return _cachedJewelryTraitsList
end

-- =========================================================
-- Equipped Sets Scanner & Categorization
-- =========================================================

local _globalSetInfoCache = {}
local _scratchSetsById = {}
local _scratchBaseById = {}
local _scratchWeaponCountBySet = {}
local _scratchSetsList = {}
local _setEntryPool = {}

local function GetSetEntry(id, name, max)
    local e = table.remove(_setEntryPool)
    if not e then
        e = {}
    end
    e.id = id
    e.name = name
    e.max = max
    e.num = 0
    e.hasHead = false
    e.hasShoulder = false
    e.bodyNum = 0
    e.frontBarNum = 0
    e.backBarNum = 0
    e.sortCategory = 99
    e.sortSub = 9
    return e
end

local function SortSets(a, b)
    local catA = a.sortCategory or 99
    local catB = b.sortCategory or 99

    if catA ~= catB then 
        return catA < catB 
    end

    if catA == 1 then
        local subA = a.sortSub or 9
        local subB = b.sortSub or 9
        if subA ~= subB then
            return subA < subB
        end
    end

    local nameA = a.name or ""
    local nameB = b.name or ""
    if nameA ~= nameB then
        return nameA < nameB
    end
    return (a.id or 0) < (b.id or 0)
end

function KRT.ISI:GetEquippedSets()
    for i = #_scratchSetsList, 1, -1 do
        table.insert(_setEntryPool, _scratchSetsList[i])
        _scratchSetsList[i] = nil
    end
    ZO_ClearTable(_scratchSetsById)
    ZO_ClearTable(_scratchBaseById)
    ZO_ClearTable(_scratchWeaponCountBySet)

    local function addSetFromLink(link)
        if not link or link == "" then return nil end
        local hasSet, _, _, _, _, setId = GetItemLinkSetInfo(link, false)
        if not hasSet or not setId or setId == 0 then return nil end
        
        if not _globalSetInfoCache[setId] then
            local _, setName, _, _, max = GetItemLinkSetInfo(link, false)
            _globalSetInfoCache[setId] = { name = CleanSetName(setName), max = max or 0 }
        end
        
        if not _scratchSetsById[setId] then
            _scratchSetsById[setId] = GetSetEntry(setId, _globalSetInfoCache[setId].name, _globalSetInfoCache[setId].max)
        end
        return setId, _globalSetInfoCache[setId].name, _globalSetInfoCache[setId].max
    end

    for _, slot in ipairs(ARMOR_SLOTS) do
        local link = GetItemLink(BAG_WORN, slot)
        local id = addSetFromLink(link)
        if id then 
            _scratchSetsById[id].num = (_scratchSetsById[id].num or 0) + 1 
            if slot == EQUIP_SLOT_HEAD then _scratchSetsById[id].hasHead = true end
            if slot == EQUIP_SLOT_SHOULDERS then _scratchSetsById[id].hasShoulder = true end
        end
    end
    for _, slot in ipairs(JEWELRY_SLOTS) do
        local link = GetItemLink(BAG_WORN, slot)
        local id = addSetFromLink(link)
        if id then _scratchSetsById[id].num = (_scratchSetsById[id].num or 0) + 1 end
    end
    
    for id, e in pairs(_scratchSetsById) do _scratchBaseById[id] = e.num or 0 end

    local function addWeaponCount(link, barKey)
        if not link or link == "" then return end
        local has, _, _, _, _, id = GetItemLinkSetInfo(link, false)
        if not has or not id or id == 0 then return end
        
        if not _globalSetInfoCache[id] then
            local _, setName, _, _, max = GetItemLinkSetInfo(link, false)
            _globalSetInfoCache[id] = { name = CleanSetName(setName), max = max or 0 }
        end

        if not _scratchWeaponCountBySet[id] then
            _scratchWeaponCountBySet[id] = { main=0, backup=0, name=_globalSetInfoCache[id].name, max=_globalSetInfoCache[id].max, id=id }
        end
        _scratchWeaponCountBySet[id][barKey] = (_scratchWeaponCountBySet[id][barKey] or 0) + (isTwoHanded(link) and 2 or 1)
    end
    
    for _, slot in ipairs(MAIN_BAR_SLOTS) do addWeaponCount(GetItemLink(BAG_WORN, slot), "main") end
    for _, slot in ipairs(BACK_BAR_SLOTS) do addWeaponCount(GetItemLink(BAG_WORN, slot), "backup") end

    for id, wc in pairs(_scratchWeaponCountBySet) do
        if not _scratchSetsById[id] then
            _scratchSetsById[id] = GetSetEntry(id, wc.name, wc.max or 0)
            _scratchBaseById[id] = 0
        end
        local base = _scratchBaseById[id] or 0
        _scratchSetsById[id].frontBarNum = base + (wc.main or 0)
        _scratchSetsById[id].backBarNum = base + (wc.backup or 0)
        _scratchSetsById[id].num = math.max(_scratchSetsById[id].frontBarNum, _scratchSetsById[id].backBarNum)
    end
    
    for id, e in pairs(_scratchSetsById) do
        e.bodyNum = _scratchBaseById[id] or 0
        e.frontBarNum = e.frontBarNum or e.num
        e.backBarNum = e.backBarNum or e.num

        -- Categorize the set for sorting & coloring
        if (e.max or 0) == 1 then
            e.sortCategory = 2 -- Mythic
        elseif (e.max or 0) == 2 and (e.hasHead or e.hasShoulder) then
            e.sortCategory = 1 -- Monster Set
            e.sortSub = e.hasHead and 1 or 2 -- Head first, then shoulder
        elseif (e.frontBarNum or 0) > (e.bodyNum or 0) and (e.backBarNum or 0) > (e.bodyNum or 0) then
            e.sortCategory = 6 -- Both Bars Weapon Set (wp)
        elseif (e.frontBarNum or 0) > (e.backBarNum or 0) then
            e.sortCategory = 4 -- Front Bar Set
        elseif (e.backBarNum or 0) > (e.frontBarNum or 0) then
            e.sortCategory = 5 -- Back Bar Set
        else
            e.sortCategory = 3 -- Body Set
        end
    end

    for _, e in pairs(_scratchSetsById) do table.insert(_scratchSetsList, e) end
    table.sort(_scratchSetsList, SortSets)

    return _scratchSetsList
end

-- =========================================================
-- UI Creation, Layout & Dragging
-- =========================================================

function KRT.ISI:ApplyAnchor()
    if not self.ui then return end
    local sv = SV()
    self.ui:ClearAnchors()
    self.ui:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.offsetX or 300, sv.offsetY or 300)
    self.ui:SetScale(sv.uiScale or 1.0)
end

function KRT.ISI:EnableDragging(enable)
    local ui = self.ui
    if not ui then return end
    ui:SetMouseEnabled(enable)
    ui:SetMovable(enable)
    if enable then
        ui:SetHandler("OnMoveStop", function(control)
            local sv = SV()
            sv.offsetX = control:GetLeft()
            sv.offsetY = control:GetTop()
        end)
    else
        ui:SetHandler("OnMoveStop", nil)
    end
end

function KRT.ISI:EnsureOverlay()
    if self.ui then return end
    local win = WM:CreateTopLevelWindow("KwibusIsiibusUI")
    win:SetDimensions(300, 200)
    win:SetHidden(true)
    win:SetClampedToScreen(true)
    win:SetDrawLayer(DL_OVERLAY)
    win:SetDrawTier(DT_HIGH)
    win:SetDrawLevel(1)

    local bg = WM:CreateControl(nil, win, CT_BACKDROP)
    bg:SetAnchorFill()
    bg:SetCenterColor(0, 0, 0, 0.25)
    bg:SetEdgeColor(0, 0, 0, 0)
    bg:SetEdgeTexture("", 1, 1, 1)
    self.bg = bg

    local wLight = WM:CreateControl(nil, win, CT_LABEL)
    local wMedium = WM:CreateControl(nil, win, CT_LABEL)
    local wHeavy = WM:CreateControl(nil, win, CT_LABEL)
    local wTraitsShort = WM:CreateControl(nil, win, CT_LABEL)

    local wWarning = WM:CreateControl(nil, win, CT_LABEL)
    wWarning:SetFont("ZoFontGame")
    wWarning:SetColor(1, 0, 0, 1)
    wWarning:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    wWarning:SetAnchor(TOPLEFT, win, TOPLEFT, 0, 0)
    wWarning:SetHidden(true)
    self.wWarning = wWarning

    for _, lbl in ipairs({wLight, wMedium, wHeavy, wTraitsShort}) do
        lbl:SetFont(HEADER_FONT)
        lbl:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    end

    wLight:SetAnchor(TOPLEFT, win, TOPLEFT, 0, 0)
    wMedium:SetAnchor(LEFT, wLight, RIGHT, 10, 0)
    wHeavy:SetAnchor(LEFT, wMedium, RIGHT, 10, 0)
    wTraitsShort:SetAnchor(LEFT, wHeavy, RIGHT, 20, 0)

    self.wLight = wLight
    self.wMedium = wMedium
    self.wHeavy = wHeavy
    self.wTraitsShort = wTraitsShort

    local wJewelryTraits = WM:CreateControl(nil, win, CT_LABEL)
    wJewelryTraits:SetFont(ROW_FONT)
    wJewelryTraits:SetHeight(ROW_H)
    wJewelryTraits:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    wJewelryTraits:SetHidden(true)
    self.wJewelryTraits = wJewelryTraits

    self.ui = win

    for i = 1, 7 do
        local countLabel = WM:CreateControl(nil, win, CT_LABEL)
        local tagLabel = WM:CreateControl(nil, win, CT_LABEL)
        local nameLabel = WM:CreateControl(nil, win, CT_LABEL)

        countLabel:SetFont(ROW_FONT)
        countLabel:SetHeight(ROW_H)
        countLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        countLabel:SetAnchor(TOPLEFT, win, TOPLEFT, 0, 0)

        tagLabel:SetFont(ROW_FONT)
        tagLabel:SetHeight(ROW_H)
        tagLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        tagLabel:SetAnchor(LEFT, countLabel, RIGHT, 0, 0)

        nameLabel:SetFont(ROW_FONT)
        nameLabel:SetHeight(ROW_H)
        nameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        nameLabel:SetAnchor(LEFT, tagLabel, RIGHT, 0, 0)

        nameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

        self.labels[i] = {
            count = countLabel,
            tag = tagLabel,
            name = nameLabel,
        }
    end

    self:ApplyAnchor()
    self:EnableDragging(SV().enableReposition)

    self.fragment = ZO_HUDFadeSceneFragment:New(self.ui)
    self:UpdateSceneFragments()
end

-- =========================================================
-- Scene Manager Fragments & Visibility
-- =========================================================

function KRT.ISI:UpdateSceneFragments()
    if not self.fragment then return end
    local sv = SV()
    local menuScenes = { "inventory", "bank", "guildBank", "houseBank", "store", "tradinghouse", "craftingResults" }

    if not sv.enabled then
        if HUD_SCENE and HUD_SCENE:HasFragment(self.fragment) then HUD_SCENE:RemoveFragment(self.fragment) end
        if HUD_UI_SCENE and HUD_UI_SCENE:HasFragment(self.fragment) then HUD_UI_SCENE:RemoveFragment(self.fragment) end
        if SCENE_MANAGER then
            for _, sceneName in ipairs(menuScenes) do
                local scene = SCENE_MANAGER:GetScene(sceneName)
                if scene and scene:HasFragment(self.fragment) then
                    scene:RemoveFragment(self.fragment)
                end
            end
        end
        return
    end

    if HUD_SCENE and not HUD_SCENE:HasFragment(self.fragment) then
        HUD_SCENE:AddFragment(self.fragment)
    end
    if HUD_UI_SCENE and not HUD_UI_SCENE:HasFragment(self.fragment) then
        HUD_UI_SCENE:AddFragment(self.fragment)
    end
    
    if SCENE_MANAGER then
        for _, sceneName in ipairs(menuScenes) do
            local scene = SCENE_MANAGER:GetScene(sceneName)
            if scene then
                if sv.showInMenus then
                    if not scene:HasFragment(self.fragment) then scene:AddFragment(self.fragment) end
                else
                    if scene:HasFragment(self.fragment) then scene:RemoveFragment(self.fragment) end
                end
            end
        end
    end
end

-- =========================================================
-- Overlay Render & Layout Pipeline
-- =========================================================

function KRT.ISI:UpdateOverlay()
    if not SV().enabled then
        self:UpdateSceneFragments()
        if self.ui then self.ui:SetHidden(true) end
        return
    end

    self:EnsureOverlay()

    local inCombat = (IsUnitInCombat and IsUnitInCombat("player")) or false
    if SV().hideInCombat and inCombat and not SV().enableReposition then
        if self.fragment then
            self.fragment:SetHiddenForReason("combat", true)
        elseif self.ui then
            self.ui:SetHidden(true)
        end
        return
    else
        if self.fragment then
            self.fragment:SetHiddenForReason("combat", false)
        end
        if SV().enableReposition and self.ui then
            self.ui:SetHidden(false)
        end
    end

    -- Apply background opacity (0 = transparent, 100 = full black)
    local opacity = (SV().bgOpacity ~= nil) and SV().bgOpacity or 25
    local alpha = math.max(0, math.min(1, opacity / 100))
    if self.bg then
        self.bg:SetCenterColor(0, 0, 0, alpha)

        -- Show green border when repositioning is active as a visual hitbox
        if SV().enableReposition then
            self.bg:SetEdgeColor(0, 1, 0, 0.8)
        else
            self.bg:SetEdgeColor(0, 0, 0, 0)
        end
    end

    local y = 0
    local invalidFront, invalidBack = false, false
    
    if SV().showAbilityWarning ~= false and ACTION_BAR_ASSIGNMENT_MANAGER then
        local frontHbManager = ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(HOTBAR_CATEGORY_PRIMARY)
        if frontHbManager then
            for i = 1, 6 do
                local slotData = frontHbManager:GetSlotData(ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + i)
                local skillData = slotData and slotData:GetPlayerSkillData()
                if skillData then
                    local progData = skillData:GetPointAllocatorProgressionData()
                    if progData then
                        local abilityId = progData:GetAbilityId()
                        if not CanAbilityBeUsedFromHotbar(abilityId, HOTBAR_CATEGORY_PRIMARY) then
                            invalidFront = true; break
                        end
                    end
                end
            end
        end
        local backHbManager = ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(HOTBAR_CATEGORY_BACKUP)
        if backHbManager then
            for i = 1, 6 do
                local slotData = backHbManager:GetSlotData(ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + i)
                local skillData = slotData and slotData:GetPlayerSkillData()
                if skillData then
                    local progData = skillData:GetPointAllocatorProgressionData()
                    if progData then
                        local abilityId = progData:GetAbilityId()
                        if not CanAbilityBeUsedFromHotbar(abilityId, HOTBAR_CATEGORY_BACKUP) then
                            invalidBack = true; break
                        end
                    end
                end
            end
        end
    end

    local missingSlots = {}
    if SV().showMissingGearWarning ~= false then
        local lang = (GetCVar and GetCVar("language.2")) or "en"
        if not self.slotNames or self._slotNamesLang ~= lang then
            local isRussian = (lang == "ru")
            self._slotNamesLang = lang
            self.slotNames = {
                [EQUIP_SLOT_HEAD] = (SI_EQUIPSLOT0 and FormatLocalizedString(GetString(SI_EQUIPSLOT0))) or (isRussian and "Голова" or "Head"),
                [EQUIP_SLOT_CHEST] = (SI_EQUIPSLOT2 and FormatLocalizedString(GetString(SI_EQUIPSLOT2))) or (isRussian and "Нагрудник" or "Chest"),
                [EQUIP_SLOT_SHOULDERS] = (SI_EQUIPSLOT3 and FormatLocalizedString(GetString(SI_EQUIPSLOT3))) or (isRussian and "Плечи" or "Shoulders"),
                [EQUIP_SLOT_HAND] = isRussian and "Кисти" or "Hands",
                [EQUIP_SLOT_WAIST] = isRussian and "Пояс" or "Belt",
                [EQUIP_SLOT_LEGS] = (SI_EQUIPSLOT8 and FormatLocalizedString(GetString(SI_EQUIPSLOT8))) or (isRussian and "Поножи" or "Legs"),
                [EQUIP_SLOT_FEET] = (SI_EQUIPSLOT9 and FormatLocalizedString(GetString(SI_EQUIPSLOT9))) or (isRussian and "Обувь" or "Feet"),
                [EQUIP_SLOT_NECK] = (SI_EQUIPSLOT1 and FormatLocalizedString(GetString(SI_EQUIPSLOT1))) or (isRussian and "Шея" or "Neck"),
                [EQUIP_SLOT_RING1] = (SI_EQUIPSLOT11 and FormatLocalizedString(GetString(SI_EQUIPSLOT11))) or (isRussian and "Кольцо 1" or "Ring 1"),
                [EQUIP_SLOT_RING2] = (SI_EQUIPSLOT12 and FormatLocalizedString(GetString(SI_EQUIPSLOT12))) or (isRussian and "Кольцо 2" or "Ring 2"),
            }
        end
        local slotNames = self.slotNames
        for _, slot in ipairs(ARMOR_SLOTS) do
            if not HasItemInSlot(BAG_WORN, slot) then table.insert(missingSlots, slotNames[slot] or "Armor") end
        end
        for _, slot in ipairs(JEWELRY_SLOTS) do
            if not HasItemInSlot(BAG_WORN, slot) then table.insert(missingSlots, slotNames[slot] or "Jewelry") end
        end

        local fbMain = GetItemLink(BAG_WORN, EQUIP_SLOT_MAIN_HAND)
        local fbOff = GetItemLink(BAG_WORN, EQUIP_SLOT_OFF_HAND)
        if fbMain == "" or (not isTwoHanded(fbMain) and fbOff == "") then
            table.insert(missingSlots, "FB weapon")
        end

        local bbMain = GetItemLink(BAG_WORN, EQUIP_SLOT_BACKUP_MAIN)
        local bbOff = GetItemLink(BAG_WORN, EQUIP_SLOT_BACKUP_OFF)
        if bbMain == "" or (not isTwoHanded(bbMain) and bbOff == "") then
            table.insert(missingSlots, "BB weapon")
        end
    end

    local warnings = {}
    if invalidFront or invalidBack then
        local msg = {}
        if invalidFront then table.insert(msg, "FB") end
        if invalidBack then table.insert(msg, "BB") end
        table.insert(warnings, "Invalid ability! (" .. table.concat(msg, ", ") .. ")")
    end
    if #missingSlots > 0 then
        if #missingSlots > 3 then
            local displaySlots = {}
            for i = 1, 3 do table.insert(displaySlots, missingSlots[i]) end
            table.insert(warnings, "Missing: " .. table.concat(displaySlots, ", ") .. " (+" .. (#missingSlots - 3) .. ")")
        else
            table.insert(warnings, "Missing: " .. table.concat(missingSlots, ", "))
        end
    end

    if #warnings > 0 then
        if self.wWarning then
            self.wWarning:SetText(table.concat(warnings, "\n"))
            self.wWarning:SetHidden(false)
        end
        y = 20 * #warnings + 5
    else
        if self.wWarning then
            self.wWarning:SetHidden(true)
        end
    end

    if SV().showArmorWeights then
        if self.wLight then
            self.wLight:ClearAnchors()
            self.wLight:SetAnchor(TOPLEFT, self.ui, TOPLEFT, 0, y)
            self.wLight:SetHidden(false)
        end
        if self.wMedium then self.wMedium:SetHidden(false) end
        if self.wHeavy then self.wHeavy:SetHidden(false) end

        local weights, traitsList = GetArmorWeightsAndTraits()
        if self.wLight then
            self.wLight:SetText(tostring(weights.light))
            self.wLight:SetColor(unpack(CP_BLUE))
        end
        if self.wMedium then
            self.wMedium:SetText(tostring(weights.medium))
            self.wMedium:SetColor(unpack(CP_GREEN))
        end
        if self.wHeavy then
            self.wHeavy:SetText(tostring(weights.heavy))
            self.wHeavy:SetColor(unpack(CP_RED))
        end

        if SV().showArmorTraits ~= false then
            local traitTxt = ""
            local distinct = 0
            for _, t in ipairs(traitsList) do
                if t.count and t.count > 0 then distinct = distinct + 1 end
            end
            local parts, shown = {}, 0
            for _, t in ipairs(traitsList) do
                if t.count and t.count > 0 then
                    local label = (distinct <= 2) and GetArmorTraitNameFull(t.traitType) or GetArmorTraitShort(t.traitType)
                    if SV().colorCodedTraits ~= false then
                        label = ColorizeTrait(t.traitType, label)
                    end
                    parts[#parts + 1] = string.format("%dx %s", t.count, label)
                    shown = shown + 1
                    if distinct > 2 and shown >= 4 then break end
                end
            end
            traitTxt = table.concat(parts, ", ")
            if self.wTraitsShort then
                self.wTraitsShort:SetText(traitTxt)
                self.wTraitsShort:SetColor(unpack(STAT_COLOR))
                self.wTraitsShort:SetHidden(traitTxt == "")
            end
        else
            if self.wTraitsShort then
                self.wTraitsShort:SetHidden(true)
            end
        end
        y = y + 25
    else
        if self.wLight then self.wLight:SetHidden(true) end
        if self.wMedium then self.wMedium:SetHidden(true) end
        if self.wHeavy then self.wHeavy:SetHidden(true) end
        if self.wTraitsShort then self.wTraitsShort:SetHidden(true) end
    end

    local sets = self:GetEquippedSets()
    for i = 1, 7 do
        local entry = sets[i]
        
        local countLabel = self.labels[i] and self.labels[i].count
        local tagLabel   = self.labels[i] and self.labels[i].tag
        local nameLabel  = self.labels[i] and self.labels[i].name

        if entry and countLabel and tagLabel and nameLabel then
            countLabel:SetAnchor(TOPLEFT, self.ui, TOPLEFT, 0, y)

            local minPieces = SPECIAL_SET_MIN_PIECES[entry.id]
            local isSpecialGreen = minPieces and (entry.num or 0) >= minPieces

            local isComplete = (entry.num or 0) >= (entry.max or 0)
            local isMonsterOneOfTwo = not isComplete and (entry.max or 0) == 2 and (entry.num or 0) == 1 and (entry.hasHead or entry.hasShoulder)
            local countColor = (isSpecialGreen or isComplete or isMonsterOneOfTwo) and GREEN or RED

            local tagStr = ""
            if SV().showLocationTags ~= false then
                local locs = {}
                local hasWeapons = false
                
                local hasFrontWeapon = (entry.frontBarNum or 0) > (entry.bodyNum or 0)
                local hasBackWeapon = (entry.backBarNum or 0) > (entry.bodyNum or 0)

                if hasFrontWeapon and hasBackWeapon then
                    table.insert(locs, "(wp)")
                    hasWeapons = true
                else
                    if hasFrontWeapon then
                        table.insert(locs, "(fb)")
                        hasWeapons = true
                    end
                    if hasBackWeapon then
                        table.insert(locs, "(bb)")
                        hasWeapons = true
                    end
                end

                if not hasWeapons and (entry.bodyNum or 0) > 0 then
                    table.insert(locs, "(b)")
                end
                
                if #locs > 0 then
                    tagStr = "|c00FFFF" .. table.concat(locs, " ") .. "|r"
                end
            end

            countLabel:SetText(zo_strformat("<<1>>/<<2>>", entry.num or 0, entry.max or 0))
            countLabel:SetColor(unpack(countColor))
            countLabel:SetHidden(false)

            tagLabel:SetText(tagStr)
            tagLabel:SetHidden(false)

            -- Determine set name color based on sortCategory (1 = Monster, 2 = Mythic, 3+ = Regular)
            local nameColor = SV().colorRegular or { 1, 1, 1 }
            if entry.sortCategory == 1 then
                nameColor = SV().colorMonster or { 1, 1, 1 }
            elseif entry.sortCategory == 2 then
                nameColor = SV().colorMythic or { 1, 1, 1 }
            end

            nameLabel:SetText(entry.name or "")
            nameLabel:SetColor(unpack(nameColor))
            nameLabel:SetHidden(false)
            
            local colWidth = SV().columnSpacing or 45
            local tagWidth = (SV().showLocationTags ~= false) and (SV().tagSpacing or 40) or 0
            local nameWidth = SV().nameSpacing or 180

            countLabel:SetWidth(colWidth)
            tagLabel:SetWidth(tagWidth)
            nameLabel:SetWidth(nameWidth)

            y = y + ROW_H
        else
            if countLabel then countLabel:SetHidden(true) end
            if tagLabel then tagLabel:SetHidden(true) end
            if nameLabel then nameLabel:SetHidden(true) end
        end
    end

    if SV().showJewelryTraits ~= false then
        local jewelryTraitsList = GetJewelryTraits()
        local traitTxt = ""
        local distinct = 0
        for _, t in ipairs(jewelryTraitsList) do
            if t.count and t.count > 0 then distinct = distinct + 1 end
        end
        if distinct > 0 then
            local parts = {}
            for _, t in ipairs(jewelryTraitsList) do
                if t.count and t.count > 0 then
                    local label = (distinct <= 2) and GetJewelryTraitNameFull(t.traitType) or GetJewelryTraitShort(t.traitType)
                    if SV().colorCodedJewelryTraits ~= false then
                        label = ColorizeJewelryTrait(t.traitType, label)
                    end
                    parts[#parts + 1] = string.format("%dx %s", t.count, label)
                end
            end
            traitTxt = table.concat(parts, ", ")
        end

        if traitTxt ~= "" then
            if self.wJewelryTraits then
                self.wJewelryTraits:ClearAnchors()
                self.wJewelryTraits:SetAnchor(TOPLEFT, self.ui, TOPLEFT, 0, y)
                self.wJewelryTraits:SetText(traitTxt)
                self.wJewelryTraits:SetColor(unpack(STAT_COLOR))
                self.wJewelryTraits:SetHidden(false)
            end
            y = y + ROW_H
        else
            if self.wJewelryTraits then
                self.wJewelryTraits:SetHidden(true)
            end
        end
    else
        if self.wJewelryTraits then
            self.wJewelryTraits:SetHidden(true)
        end
    end

    -- Calculate overlay dimensions with padding and minimum reposition height
    local totalWidth = (SV().columnSpacing or 45) + ((SV().showLocationTags ~= false) and (SV().tagSpacing or 40) or 0) + (SV().nameSpacing or 180) + 10
    local totalHeight = math.max(y, SV().enableReposition and 40 or 0)
    if self.ui then self.ui:SetDimensions(totalWidth, totalHeight) end
    if self.bg then self.bg:SetDimensions(totalWidth, totalHeight) end
end

-- =========================================================
-- Initialization & Event Handling
-- =========================================================

function KRT.ISI:Initialize()
    if not SV().hasForcedTraitColoringOnce then
        SV().colorCodedTraits = true
        SV().hasForcedTraitColoringOnce = true
    end
    if not SV().hasForcedJewelryTraitColoringOnce then
        SV().colorCodedJewelryTraits = true
        SV().hasForcedJewelryTraitColoringOnce = true
    end

    self:UpdateOverlay()

    local function TriggerDebouncedUpdate()
        if not SV().enabled then return end
        self:UpdateOverlay()
    end
    local function OnInventoryUpdate()
        if not SV().enabled then return end
        if KRT.DebounceNextFrame then
            KRT.DebounceNextFrame("IsiibusUpdate", TriggerDebouncedUpdate)
        else
            TriggerDebouncedUpdate()
        end
    end
    local function OnCombatStateChanged(eventCode, inCombat)
        if not SV().enabled then return end
        if SV().hideInCombat and not SV().enableReposition then
            if inCombat then
                if self.fragment then
                    self.fragment:SetHiddenForReason("combat", true)
                elseif self.ui then
                    self.ui:SetHidden(true)
                end
            else
                if self.fragment then
                    self.fragment:SetHiddenForReason("combat", false)
                end
                self:UpdateOverlay()
            end
        end
    end

    function self:ToggleEvents(enable)
        if enable and not self._eventsRegistered then
            EM:RegisterForEvent(ADDON_NAME .. "_ISI", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventoryUpdate)
            EM:AddFilterForEvent(ADDON_NAME .. "_ISI", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
            EM:AddFilterForEvent(ADDON_NAME .. "_ISI", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
            EM:RegisterForEvent(ADDON_NAME .. "_ISI2", EVENT_INVENTORY_FULL_UPDATE, OnInventoryUpdate)
            EM:RegisterForEvent(ADDON_NAME .. "_ISI3", EVENT_ACTION_SLOTS_FULL_UPDATE, OnInventoryUpdate)
            EM:RegisterForEvent(ADDON_NAME .. "_ISICombat", EVENT_PLAYER_COMBAT_STATE, OnCombatStateChanged)
            self._eventsRegistered = true
        elseif not enable and self._eventsRegistered then
            EM:UnregisterForEvent(ADDON_NAME .. "_ISI", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
            EM:UnregisterForEvent(ADDON_NAME .. "_ISI2", EVENT_INVENTORY_FULL_UPDATE)
            EM:UnregisterForEvent(ADDON_NAME .. "_ISI3", EVENT_ACTION_SLOTS_FULL_UPDATE)
            EM:UnregisterForEvent(ADDON_NAME .. "_ISICombat", EVENT_PLAYER_COMBAT_STATE)
            self._eventsRegistered = false
        end
    end

    self:ToggleEvents(SV().enabled)
end

-- =========================================================
-- Settings Menu (LibAddonMenu)
-- =========================================================

function KRT.ISI:GetLAMSubmenu()
    return {
        type = "submenu",
        name = "Isiibus Equipped",
        controls = {
            {
                type = "checkbox",
                name = "Enable Module",
                tooltip = "Shows equipped sets and armor weights on the screen.",
                getFunc = function() return SV().enabled end,
                setFunc = function(value)
                    SV().enabled = value
                    self:ToggleEvents(value)
                    self:UpdateSceneFragments()
                    if not value then
                        self:EnableDragging(false)
                        if self.ui then self.ui:SetHidden(true) end
                    else
                        self:UpdateOverlay()
                    end
                end,
                default = DEFAULTS.isi.enabled,
            },
            {
                type = "checkbox",
                name = "Enable Repositioning (Drag)",
                tooltip = "Shows a background box allowing you to move the overlay.",
                getFunc = function() return SV().enableReposition end,
                setFunc = function(value)
                    SV().enableReposition = value
                    self:EnableDragging(value)
                    self:UpdateOverlay()
                end,
                default = DEFAULTS.isi.enableReposition,
                disabled = function() return not SV().enabled end,
            },
            {
                type = "button",
                name = "Reset Horizontal Position",
                func = function()
                    if not KRT.ISI.ui then return end
                    local rootW = GuiRoot:GetWidth()
                    local w = KRT.ISI.ui:GetWidth() * (SV().uiScale or 1.0)
                    SV().offsetX = (rootW - w) / 2
                    KRT.ISI:ApplyAnchor()
                end,
                width = "half",
                disabled = function() return not SV().enabled or not SV().enableReposition end,
            },
            {
                type = "button",
                name = "Reset Vertical Position",
                func = function()
                    if not KRT.ISI.ui then return end
                    local rootH = GuiRoot:GetHeight()
                    local h = KRT.ISI.ui:GetHeight() * (SV().uiScale or 1.0)
                    SV().offsetY = (rootH - h) / 2
                    KRT.ISI:ApplyAnchor()
                end,
                width = "half",
                disabled = function() return not SV().enabled or not SV().enableReposition end,
            },
            {
                type = "slider",
                name = "UI Scale (%)",
                min = 10,
                max = 200,
                step = 1,
                decimals = 0,
                getFunc = function() return math.floor((SV().uiScale or 1.0) * 100) end,
                setFunc = function(value) 
                    SV().uiScale = value / 100.0
                    self:ApplyAnchor()
                end,
                default = math.floor((DEFAULTS.isi.uiScale or 1.0) * 100),
                disabled = function() return not SV().enabled end,
            },
            {
                type = "slider",
                name = "Background Opacity (%)",
                tooltip = "Adjusts background opacity from 0 (fully transparent) to 100 (solid black).",
                min = 0,
                max = 100,
                step = 1,
                getFunc = function() return (SV().bgOpacity ~= nil) and SV().bgOpacity or 25 end,
                setFunc = function(value) 
                    SV().bgOpacity = value 
                    self:UpdateOverlay() 
                end,
                default = DEFAULTS.isi.bgOpacity,
                disabled = function() return not SV().enabled end,
            },
            {
                type = "slider",
                name = "Count Column Width",
                tooltip = "Adjusts the gap between the piece counts and the tags.",
                min = 20,
                max = 100,
                step = 1,
                getFunc = function() return SV().columnSpacing or 45 end,
                setFunc = function(value) SV().columnSpacing = value; self:UpdateOverlay() end,
                default = DEFAULTS.isi.columnSpacing,
                disabled = function() return not SV().enabled end,
            },
            {
                type = "slider",
                name = "Tag Column Width",
                tooltip = "Adjusts the width of the location tags column.",
                min = 10,
                max = 50,
                step = 1,
                getFunc = function() return SV().tagSpacing or 40 end,
                setFunc = function(value) SV().tagSpacing = value; self:UpdateOverlay() end,
                default = DEFAULTS.isi.tagSpacing,
                disabled = function() return not SV().enabled end,
            },
            {
                type = "slider",
                name = "Set Name Column Width",
                tooltip = "Adjusts the max width allowed for set names before truncation.",
                min = 100,
                max = 200,
                step = 1,
                getFunc = function() return SV().nameSpacing or 180 end,
                setFunc = function(value) SV().nameSpacing = value; self:UpdateOverlay() end,
                default = DEFAULTS.isi.nameSpacing,
                disabled = function() return not SV().enabled end,
            },
            {
                type = "checkbox",
                name = "Show in Inventory/Bank",
                tooltip = "Displays the overlay while interacting with your inventory, bank, or storage chests.",
                getFunc = function() return SV().showInMenus end,
                setFunc = function(value) SV().showInMenus = value; self:UpdateSceneFragments() end,
                default = DEFAULTS.isi.showInMenus,
                disabled = function() return not SV().enabled end,
            },
            {
                type = "checkbox",
                name = "Hide in Combat",
                tooltip = "Automatically hides the overlay when you enter combat.",
                getFunc = function() return SV().hideInCombat end,
                setFunc = function(value) SV().hideInCombat = value; self:UpdateOverlay() end,
                default = DEFAULTS.isi.hideInCombat,
                disabled = function() return not SV().enabled end,
            },
            {
                type = "checkbox",
                name = "Show Armor Weights",
                getFunc = function() return SV().showArmorWeights end,
                setFunc = function(value) SV().showArmorWeights = value; self:UpdateOverlay() end,
                default = DEFAULTS.isi.showArmorWeights,
                disabled = function() return not SV().enabled end,
            },
            {
                type = "checkbox",
                name = "Show Armor Traits",
                tooltip = "Displays armor traits alongside your armor weights.",
                getFunc = function() return SV().showArmorTraits end,
                setFunc = function(value) SV().showArmorTraits = value; self:UpdateOverlay() end,
                default = DEFAULTS.isi.showArmorTraits,
                disabled = function() return not SV().enabled end,
            },
            {
                type = "checkbox",
                name = "Show Jewelry Traits",
                tooltip = "Displays jewelry traits at the bottom of the overlay.",
                getFunc = function() return SV().showJewelryTraits end,
                setFunc = function(value) SV().showJewelryTraits = value; self:UpdateOverlay() end,
                default = DEFAULTS.isi.showJewelryTraits,
                disabled = function() return not SV().enabled end,
            },
            {
                type = "checkbox",
                name = "Show Missing Gear Warning",
                tooltip = "Displays a red warning if you are missing armor, jewelry, or weapons.",
                getFunc = function() return SV().showMissingGearWarning end,
                setFunc = function(value) SV().showMissingGearWarning = value; self:UpdateOverlay() end,
                default = DEFAULTS.isi.showMissingGearWarning,
                disabled = function() return not SV().enabled end,
            },
            {
                type = "checkbox",
                name = "Show Invalid Ability Warning",
                tooltip = "Displays a red warning if you have a weapon ability slotted but are holding the wrong weapon.",
                getFunc = function() return SV().showAbilityWarning end,
                setFunc = function(value) SV().showAbilityWarning = value; self:UpdateOverlay() end,
                default = DEFAULTS.isi.showAbilityWarning,
                disabled = function() return not SV().enabled end,
            },
            {
                type = "checkbox",
                name = "Show Set Location Tags",
                tooltip = "Shows (b), (fb), or (bb) to indicate where a set is equipped.",
                getFunc = function() return SV().showLocationTags end,
                setFunc = function(value) SV().showLocationTags = value; self:UpdateOverlay() end,
                default = DEFAULTS.isi.showLocationTags,
                disabled = function() return not SV().enabled end,
            },
            {
                type = "submenu",
                name = "Color Options",
                controls = {
                    {
                        type = "checkbox",
                        name = "Color-Coded Armor Traits",
                        tooltip = "Applies distinct thematic colors to equipped armor trait labels.",
                        getFunc = function() return SV().colorCodedTraits end,
                        setFunc = function(value) 
                            SV().colorCodedTraits = value 
                            self:UpdateOverlay() 
                        end,
                        default = DEFAULTS.isi.colorCodedTraits,
                        disabled = function() return not SV().enabled or not SV().showArmorTraits end,
                    },
                    {
                        type = "checkbox",
                        name = "Color-Coded Jewelry Traits",
                        tooltip = "Applies distinct thematic colors to equipped jewelry trait labels.",
                        getFunc = function() return SV().colorCodedJewelryTraits end,
                        setFunc = function(value)
                            SV().colorCodedJewelryTraits = value
                            self:UpdateOverlay()
                        end,
                        default = DEFAULTS.isi.colorCodedJewelryTraits,
                        disabled = function() return not SV().enabled or not SV().showJewelryTraits end,
                    },
                    {
                        type = "colorpicker",
                        name = "Monster Set Color",
                        tooltip = "Color for Monster set names (Head / Shoulders).",
                        getFunc = function() return unpack(SV().colorMonster or { 1, 1, 1 }) end,
                        setFunc = function(r, g, b) 
                            SV().colorMonster = { r, g, b } 
                            self:UpdateOverlay() 
                        end,
                        default = DEFAULTS.isi.colorMonster,
                        disabled = function() return not SV().enabled end,
                    },
                    {
                        type = "colorpicker",
                        name = "Mythic Item Color",
                        tooltip = "Color for Mythic item names.",
                        getFunc = function() return unpack(SV().colorMythic or { 1, 1, 1 }) end,
                        setFunc = function(r, g, b) 
                            SV().colorMythic = { r, g, b } 
                            self:UpdateOverlay() 
                        end,
                        default = DEFAULTS.isi.colorMythic,
                        disabled = function() return not SV().enabled end,
                    },
                    {
                        type = "colorpicker",
                        name = "Regular Set Color",
                        tooltip = "Color for standard 3-piece and 5-piece set names.",
                        getFunc = function() return unpack(SV().colorRegular or { 1, 1, 1 }) end,
                        setFunc = function(r, g, b) 
                            SV().colorRegular = { r, g, b } 
                            self:UpdateOverlay() 
                        end,
                        default = DEFAULTS.isi.colorRegular,
                        disabled = function() return not SV().enabled end,
                    },
                },
            },
        }
    }
end

-- =========================================================
-- Module Registration
-- =========================================================

KRT:RegisterModule(KRT.ISI)
