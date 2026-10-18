-- Quartermaster/src/Index.lua
-- Read side of the inventory store. Builds query indexes lazily over the
-- SavedVariables snapshot the Scanner produces, and merges live craft-bag
-- contents at query time (per brief §4.5).
--
-- Result row shape (consumed by ui/InventoryTab_*):
--   {
--     entry           = <Scanner entry>,
--     locationKey     = "char:<id>:backpack" | "char:<id>:worn" | "bank" | "guildbank:<id>" | "house:<houseId>:<bagId>" | "craftbag",
--     locationLabel   = string,    -- localized
--     bagId           = number,    -- live bag id usable by RequestMoveItem
--     slotIndex       = number,    -- live slot index usable by RequestMoveItem
--     characterId     = string?,
--     guildId         = number?,
--     houseId         = number?,
--   }

AccountHold = AccountHold or {}
AccountHold.Index = AccountHold.Index or {}

local Index = AccountHold.Index
local addon

-- ---------------------------------------------------------------------------
-- Cache invalidation
-- ---------------------------------------------------------------------------

local cacheValid = false
local lastResults = nil

function Index:Invalidate()
    cacheValid = false
end

function Index:Initialize(addonRef)
    addon = addonRef
end

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function locLabelCharacter(name) return ZO_CachedStrFormat(GetString(SI_ACCOUNTHOLD_LOC_CHARACTER), name) end
local function locLabelGuildBank(name) return ZO_CachedStrFormat(GetString(SI_ACCOUNTHOLD_LOC_GUILD_BANK), name) end
local function locLabelHouse(name)     return ZO_CachedStrFormat(GetString(SI_ACCOUNTHOLD_LOC_HOUSE), name or "?") end
local function locLabelWorn(name)      return ZO_CachedStrFormat(GetString(SI_ACCOUNTHOLD_LOC_WORN), name) end

-- ZO_CachedStrFormat is the recommended formatter; if the build is older (or
-- in the test harness), fall back to a small formatter that substitutes the
-- ESO <<1>>/<<2>> tokens the strings use (plain string.format would leave them
-- untouched, printing a literal "<<1>>").
if not ZO_CachedStrFormat then
    ZO_CachedStrFormat = function(fmt, ...)
        local args = { ... }
        return (tostring(fmt):gsub("<<(%d+)>>", function(n)
            return tostring(args[tonumber(n)] or "")
        end))
    end
end

-- ---------------------------------------------------------------------------
-- Walk the persisted snapshot and yield rows
-- ---------------------------------------------------------------------------

local function emitRowsForCharacter(characterId, rec, sink)
    local isMe = (characterId == GetCurrentCharacterId())
    -- Backpack rows: only the currently-played character has a usable bagId/slot.
    -- For other characters we emit rows with bagId=BAG_BACKPACK but mark them
    -- not-actionable-from-here (the holder must log in).
    for slotIndex, entry in pairs(rec.backpack or {}) do
        sink[#sink + 1] = {
            entry         = entry,
            locationKey   = "char:" .. tostring(characterId) .. ":backpack",
            locationLabel = locLabelCharacter(rec.name or "?"),
            bagId         = BAG_BACKPACK,
            slotIndex     = slotIndex,
            characterId   = characterId,
            isLocal       = isMe,
        }
    end
    for slotIndex, entry in pairs(rec.worn or {}) do
        sink[#sink + 1] = {
            entry         = entry,
            locationKey   = "char:" .. tostring(characterId) .. ":worn",
            locationLabel = locLabelWorn(rec.name or "?"),
            bagId         = BAG_WORN,
            slotIndex     = slotIndex,
            characterId   = characterId,
            isLocal       = isMe,
            isWorn        = true,
        }
    end
end

local function emitRowsForAccountBank(sink)
    local store = addon.sv.accountBank
    if not store or not store.items then return end
    for slotKey, entry in pairs(store.items) do
        local bagId, slotIndex
        if type(slotKey) == "string" and slotKey:sub(1, 2) == "S:" then
            bagId     = BAG_SUBSCRIBER_BANK
            slotIndex = tonumber(slotKey:sub(3))
        else
            bagId     = BAG_BANK
            slotIndex = slotKey
        end
        sink[#sink + 1] = {
            entry         = entry,
            locationKey   = "bank",
            locationLabel = GetString(SI_ACCOUNTHOLD_LOC_BANK),
            bagId         = bagId,
            slotIndex     = slotIndex,
            isLocal       = true,           -- bank items are usable by the active char when bank is open
        }
    end
end

local function emitRowsForGuildBanks(sink)
    for guildId, store in pairs(addon.sv.guildBanks or {}) do
        for slotIndex, entry in pairs(store.items or {}) do
            sink[#sink + 1] = {
                entry         = entry,
                locationKey   = "guildbank:" .. tostring(guildId),
                locationLabel = locLabelGuildBank(store.name or "?"),
                bagId         = BAG_GUILDBANK,
                slotIndex     = slotIndex,
                guildId       = guildId,
                isLocal       = true,       -- usable when this guild bank is open
            }
        end
    end
end

local function emitRowsForHouseStorage(sink)
    for houseId, byBag in pairs(addon.sv.houseStorage or {}) do
        for bagId, bucket in pairs(byBag) do
            for slotIndex, entry in pairs(bucket.items or {}) do
                sink[#sink + 1] = {
                    entry         = entry,
                    locationKey   = string.format("house:%d:%d", houseId, bagId),
                    locationLabel = locLabelHouse("#" .. tostring(houseId)),
                    bagId         = bagId,
                    slotIndex     = slotIndex,
                    houseId       = houseId,
                    isLocal       = true,
                }
            end
        end
    end
end

-- Live craft-bag walk: NEVER persisted. Called every query.
local function emitRowsForCraftBag(sink)
    if not BAG_VIRTUAL then return end
    local size = GetBagSize(BAG_VIRTUAL) or 0
    if size <= 0 then return end
    for slot = 0, size - 1 do
        if not IsItemBagAndSlotEmpty or not IsItemBagAndSlotEmpty(BAG_VIRTUAL, slot) then
            -- Reuse the Scanner's entry builder if available.
            local entry
            if addon.Scanner and addon.Scanner._BuildEntry then
                entry = addon.Scanner._BuildEntry(BAG_VIRTUAL, slot)
            else
                local link = GetItemLink(BAG_VIRTUAL, slot, LINK_STYLE_DEFAULT)
                if link and link ~= "" then
                    entry = {
                        itemSignature = link,
                        itemLink      = link,
                        name          = GetItemName(BAG_VIRTUAL, slot) or "",
                        stackCount    = select(2, GetItemInfo(BAG_VIRTUAL, slot)) or 0,
                        scannedAt     = GetTimeStamp(),
                    }
                end
            end
            if entry then
                sink[#sink + 1] = {
                    entry         = entry,
                    locationKey   = "craftbag",
                    locationLabel = GetString(SI_ACCOUNTHOLD_LOC_CRAFT_BAG),
                    bagId         = BAG_VIRTUAL,
                    slotIndex     = slot,
                    isLocal       = true,
                    isCraftBag    = true,
                }
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Build / cache the row set
-- ---------------------------------------------------------------------------

local function rebuildRows()
    local rows = {}
    for characterId, rec in pairs(addon.sv.characters or {}) do
        emitRowsForCharacter(characterId, rec, rows)
    end
    emitRowsForAccountBank(rows)
    emitRowsForGuildBanks(rows)
    emitRowsForHouseStorage(rows)
    -- Craft bag is intentionally excluded from the cached rows; merged at
    -- query time so it always reflects ESO Plus state changes immediately.
    lastResults = rows
    cacheValid  = true
end

-- ---------------------------------------------------------------------------
-- Item categories (guild-bank-style top-level filter)
-- Each category resolves a set of ESO ITEMTYPE_* constants at first use.
-- Resolution is nil-safe: constants absent on a given client build are
-- skipped, so the addon never hard-errors on an unknown itemtype. "all"
-- matches everything; "misc" matches any itemType not claimed elsewhere.
-- ---------------------------------------------------------------------------
local function resolveTypeSet(names)
    local set = {}
    for _, n in ipairs(names) do
        local v = _G[n]
        if type(v) == "number" then set[v] = true end
    end
    return set
end

local CATEGORY_TYPE_SETS
local function categoryTypeSets()
    if CATEGORY_TYPE_SETS then return CATEGORY_TYPE_SETS end
    CATEGORY_TYPE_SETS = {
        weapon = resolveTypeSet({ "ITEMTYPE_WEAPON" }),
        armor  = resolveTypeSet({ "ITEMTYPE_ARMOR" }),
        jewelry = resolveTypeSet({ "ITEMTYPE_ARMOR", "ITEMTYPE_JEWELRY" }),
        consumable = resolveTypeSet({
            "ITEMTYPE_FOOD", "ITEMTYPE_DRINK", "ITEMTYPE_POTION", "ITEMTYPE_POISON",
            "ITEMTYPE_RECIPE", "ITEMTYPE_RACIAL_STYLE_MOTIF",
            -- Must stay a SUPERSET of the Consumables sub-filter options in
            -- InventoryTab_Gamepad's SIMPLE_CATEGORY_FILTERS.consumable, or the
            -- top-level category match rejects a sub-type the player just picked
            -- and the list comes back empty. These four were missing.
            "ITEMTYPE_MASTER_WRIT", "ITEMTYPE_CONTAINER", "ITEMTYPE_CONTAINER_CURRENCY",
            "ITEMTYPE_AVA_REPAIR",
        }),
        material = resolveTypeSet({
            "ITEMTYPE_RAW_MATERIAL",
            "ITEMTYPE_BLACKSMITHING_RAW_MATERIAL", "ITEMTYPE_BLACKSMITHING_MATERIAL", "ITEMTYPE_BLACKSMITHING_BOOSTER",
            "ITEMTYPE_CLOTHIER_RAW_MATERIAL", "ITEMTYPE_CLOTHIER_MATERIAL", "ITEMTYPE_CLOTHIER_BOOSTER",
            "ITEMTYPE_WOODWORKING_RAW_MATERIAL", "ITEMTYPE_WOODWORKING_MATERIAL", "ITEMTYPE_WOODWORKING_BOOSTER",
            "ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL", "ITEMTYPE_JEWELRYCRAFTING_MATERIAL",
            "ITEMTYPE_JEWELRYCRAFTING_RAW_BOOSTER", "ITEMTYPE_JEWELRYCRAFTING_BOOSTER",
            "ITEMTYPE_ENCHANTING_RUNE_ASPECT", "ITEMTYPE_ENCHANTING_RUNE_ESSENCE", "ITEMTYPE_ENCHANTING_RUNE_POTENCY",
            "ITEMTYPE_ALCHEMY_BASE", "ITEMTYPE_REAGENT", "ITEMTYPE_INGREDIENT",
            -- Alchemy sub-filter also lists solvent bases; keep the parent set a
            -- superset so selecting "Alchemy" doesn't drop them.
            "ITEMTYPE_POTION_BASE", "ITEMTYPE_POISON_BASE",
            "ITEMTYPE_STYLE_MATERIAL", "ITEMTYPE_RAW_TRAIT_MATERIAL",
            "ITEMTYPE_ARMOR_TRAIT", "ITEMTYPE_WEAPON_TRAIT",
            "ITEMTYPE_JEWELRY_RAW_TRAIT", "ITEMTYPE_JEWELRY_TRAIT",
            "ITEMTYPE_FURNISHING_MATERIAL",
        }),
        glyph = resolveTypeSet({
            "ITEMTYPE_GLYPH_ARMOR", "ITEMTYPE_GLYPH_WEAPON", "ITEMTYPE_GLYPH_JEWELRY",
        }),
        furnishing = resolveTypeSet({ "ITEMTYPE_FURNISHING" }),
        companion = nil,   -- see CATEGORY_PREDICATES: identified by actorCategory,
                           -- never by itemType (companion gear shares the
                           -- player's ITEMTYPE_* values exactly).
    }
    return CATEGORY_TYPE_SETS
end

-- ESO never publishes the numeric value of a constant and it can change between
-- API versions, so always resolve by name at call time.
local function numericConst(name)
    local v = type(_G) == "table" and _G[name] or nil
    if type(v) == "number" then return v end
    return nil
end

-- Is the companion-equipment API present on this client at all? When it is not,
-- the Companion category cannot be distinguished from ordinary gear, so it is
-- hidden entirely rather than silently showing the player's own equipment.
local function companionApiAvailable()
    if numericConst("GAMEPLAY_ACTOR_CATEGORY_COMPANION") == nil then return false end
    return type(_G["GetItemLinkActorCategory"]) == "function"
        or type(_G["GetItemActorCategory"]) == "function"
end
Index.CompanionApiAvailable = companionApiAvailable

local CATEGORY_ORDER = {
    { key = "all",        stringId = "SI_ACCOUNTHOLD_CAT_ALL" },
    -- Owner views come first: they cut across every item type and pair with
    -- the Character filter rather than narrowing by itemType.
    { key = "equipped",   stringId = "SI_ACCOUNTHOLD_CAT_EQUIPPED" },
    { key = "sets",       stringId = "SI_ACCOUNTHOLD_CAT_SETS" },
    { key = "weapon",     stringId = "SI_ACCOUNTHOLD_CAT_WEAPONS" },
    { key = "armor",      stringId = "SI_ACCOUNTHOLD_CAT_ARMOR" },
    { key = "jewelry",    stringId = "SI_ACCOUNTHOLD_CAT_JEWELRY" },
    { key = "consumable", stringId = "SI_ACCOUNTHOLD_CAT_CONSUMABLES" },
    { key = "material",   stringId = "SI_ACCOUNTHOLD_CAT_MATERIALS" },
    { key = "glyph",      stringId = "SI_ACCOUNTHOLD_CAT_GLYPHS" },
    { key = "furnishing", stringId = "SI_ACCOUNTHOLD_CAT_FURNISHINGS" },
    { key = "companion",  stringId = "SI_ACCOUNTHOLD_CAT_COMPANION" },
    { key = "misc",       stringId = "SI_ACCOUNTHOLD_CAT_MISC" },
}

-- Ordered {key,label} list for the category filter dropdown / cycle.
function Index:GetCategories()
    local out = {}
    for _, c in ipairs(CATEGORY_ORDER) do
        -- Hide Companion outright when the client has no actor-category API:
        -- without it the category cannot be told apart from the player's own
        -- gear, and showing everything would be worse than not offering it.
        local skip = (c.key == "companion") and not companionApiAvailable()
        if not skip then
            local sid = _G[c.stringId]
            out[#out + 1] = { key = c.key, label = (sid and GetString(sid)) or c.key }
        end
    end
    return out
end

-- equipType for an entry. Scanner caches it (src/Scanner.lua buildEntry), but
-- fall back to the item link so entries written by an older build still
-- classify. Deliberately self-contained: safeItemLinkNumber is declared further
-- down and would resolve to a nil global here.
local function entryEquipType(entry)
    if not entry then return nil end
    if type(entry.equipType) == "number" then return entry.equipType end
    local fn = _G["GetItemLinkEquipType"]
    local link = entry.itemLink or entry.link or entry.itemSignature
    if type(fn) ~= "function" or type(link) ~= "string" or link == "" then return nil end
    local ok, value = pcall(fn, link)
    if ok and type(value) == "number" then return value end
    return nil
end

-- ESO has NO jewelry itemType. Rings and necklaces are ITEMTYPE_ARMOR and are
-- told apart by equipType. Proof: esoui/ingame/tradinghouse/
-- tradinghousecategories_shared.lua ApplyJewelryToSearch filters on
-- ITEMTYPE_ARMOR + TRADING_HOUSE_FILTER_TYPE_EQUIP (EQUIP_TYPE_NECK/RING), and
-- its SetContainsItemCallback tests ONLY GetItemLinkEquipType.
--
-- Beware the tempting counter-example: that file also contains the literal
-- `{ ITEMTYPE_WEAPON, ITEMTYPE_ARMOR, ITEMTYPE_JEWELRY }`. A trailing nil in a
-- Lua table constructor is silently dropped, so that expression evaluates to
-- {ITEMTYPE_WEAPON, ITEMTYPE_ARMOR} — it is vestigial ZOS code, NOT evidence
-- the constant exists. The name is still probed below purely so this keeps
-- working if a future build ever introduces it.
local function entryIsJewelry(entry)
    if not entry then return false end
    local jewelryItemType = _G["ITEMTYPE_JEWELRY"]
    if type(jewelryItemType) == "number" and entry.itemType == jewelryItemType then
        return true
    end
    local et = entryEquipType(entry)
    if et == nil then return false end
    local ring = _G["EQUIP_TYPE_RING"]
    local neck = _G["EQUIP_TYPE_NECK"]
    return (type(ring) == "number" and et == ring)
        or (type(neck) == "number" and et == neck)
end

-- Companion gear is identified ONLY by GameplayActorCategory: companion
-- weapons/armor/jewelry carry byte-identical ITEMTYPE_* values to the player's
-- own gear, so no itemType set can ever separate them. See
-- esoui/ingame/inventory/itemfilterutils.lua:
--   IsSlotFilterDataInItemTypeDisplayCategory ->
--     slot.actorCategory == GAMEPLAY_ACTOR_CATEGORY_COMPANION
-- and esoui/ingame/inventory/sharedinventory.lua:
--   slot.actorCategory = GetItemActorCategory(bagId, slotIndex)
local function entryActorCategory(entry)
    if entry == nil then return nil end
    if type(entry.actorCategory) == "number" then return entry.actorCategory end
    local fn = _G["GetItemLinkActorCategory"]
    local link = entry.itemLink or entry.link or entry.itemSignature
    if type(fn) ~= "function" or type(link) ~= "string" or link == "" then return nil end
    local ok, value = pcall(fn, link)
    if ok and type(value) == "number" then return value end
    return nil
end

local function entryIsCompanionGear(entry)
    local companion = numericConst("GAMEPLAY_ACTOR_CATEGORY_COMPANION")
    if companion == nil then return false end
    return entryActorCategory(entry) == companion
end

-- Companion sub-types reuse the same weapon/armor/jewelry split as player gear.
-- Shields are ITEMTYPE_ARMOR and therefore land under Armor, matching ESO.
local COMPANION_SUBTYPE_MATCHERS = {
    weapon = function(entry)
        local t = numericConst("ITEMTYPE_WEAPON")
        return t ~= nil and entry.itemType == t
    end,
    armor = function(entry)
        local t = numericConst("ITEMTYPE_ARMOR")
        return t ~= nil and entry.itemType == t and not entryIsJewelry(entry)
    end,
    jewelry = function(entry)
        return entryIsJewelry(entry)
    end,
}

-- An unknown/nil sub-type means "All Companion Equipment": no extra narrowing.
local function entryMatchesCompanionType(entry, companionType)
    local matcher = COMPANION_SUBTYPE_MATCHERS[companionType]
    if not matcher then return true end
    return entry ~= nil and matcher(entry) == true
end

-- Categories that cannot be expressed as a plain ITEMTYPE_* set. The predicate
-- runs IN ADDITION to the type set when the category has one (jewelry: armor
-- itemType AND a ring/neck equipType); when the category has NO type set it is
-- defined PURELY by the predicate (companion, whose itemTypes are identical to
-- the player's). Add a key here rather than special-casing entryMatchesCategory,
-- so independent category fixes compose.
local CATEGORY_PREDICATES = {
    jewelry   = entryIsJewelry,
    companion = entryIsCompanionGear,
}

local function entryMatchesCategory(entry, categoryKey)
    if not categoryKey or categoryKey == "all" then return true end
    -- "character" is an owner view, not an item-type filter: it shows every
    -- item type. The actual character selection is applied via filter.characterId.
    if categoryKey == "character" then return true end
    -- "equipped" is likewise an owner view and cannot be decided from the entry
    -- alone: "is this worn?" is a property of the ROW (which bag/slot the item
    -- occupies), not of the item. Query applies the row-level test; accept
    -- every entry here so the two checks compose instead of fighting.
    if categoryKey == "equipped" then return true end
    -- "sets" shows only items that belong to an item set (any gear type), so
    -- the player can pick a set from the Set dropdown and see its pieces.
    if categoryKey == "sets" then
        return (entry.setId ~= nil and entry.setId ~= 0)
               or (entry.setName ~= nil and entry.setName ~= "")
    end
    local sets = categoryTypeSets()
    local it = entry.itemType
    if categoryKey == "misc" then
        for _, set in pairs(sets) do
            if it and set[it] then return false end
        end
        return true
    end
    local set = sets[categoryKey]
    local predicate = CATEGORY_PREDICATES[categoryKey]
    -- No type set => the category is defined purely by its predicate. This is
    -- how Companion works: its items share the player's itemTypes exactly, so
    -- there is nothing to intersect and only actorCategory can decide.
    if not set then
        if predicate then return predicate(entry) == true end
        return true
    end
    if it == nil or set[it] ~= true then return false end
    if predicate and not predicate(entry) then return false end
    return true
end

local function tableContainsValue(values, value)
    if type(values) ~= "table" then return false end
    for _, v in ipairs(values) do
        if v == value then return true end
    end
    return false
end

local function setContainsValue(values, value)
    if type(values) ~= "table" then return false end
    return values[value] == true or tableContainsValue(values, value)
end

local function safeItemLinkNumber(entry, fnName)
    if type(_G) ~= "table" or type(_G[fnName]) ~= "function" then return nil end
    local link = entry and (entry.itemLink or entry.link or entry.itemSignature)
    if not link or link == "" then return nil end
    local ok, value = pcall(_G[fnName], link)
    if ok and type(value) == "number" then return value end
    return nil
end

-- Specialized item type, used by the Furnishings sub-filter.
--
-- There is NO GetItemLinkSpecializedItemType function in the ESO API — calling
-- it silently yielded nil and killed every furnishing sub-type. The canonical
-- accessor is GetItemLinkItemType(link), which returns TWO values:
-- (itemType, specializedItemType). The link fallback matters: entries scanned
-- by an older build have no cached specializedItemType, and resolving it from
-- the stored itemLink avoids forcing a full rescan or an SV migration.
local function entrySpecializedItemType(entry)
    if entry and entry.specializedItemType ~= nil then return entry.specializedItemType end
    local link = entry and (entry.itemLink or entry.link or entry.itemSignature)
    if type(_G.GetItemLinkItemType) == "function"
       and type(link) == "string" and link ~= "" then
        local ok, _, spec = pcall(_G.GetItemLinkItemType, link)
        if ok and type(spec) == "number" then return spec end
    end
    return nil
end

local function entryRequiredLevel(entry)
    local level = entry and entry.requiredLevel or safeItemLinkNumber(entry, "GetItemLinkRequiredLevel")
    if type(level) == "number" then return level end
    return nil
end

local function entryRequiredChampionPoints(entry)
    local cp = entry and entry.requiredChampionPoints or safeItemLinkNumber(entry, "GetItemLinkRequiredChampionPoints")
    if type(cp) == "number" then return cp end
    return nil
end

local function entryQuality(entry)
    if entry and entry.quality ~= nil then return entry.quality end
    return safeItemLinkNumber(entry, "GetItemLinkDisplayQuality")
        or safeItemLinkNumber(entry, "GetItemLinkFunctionalQuality")
        or safeItemLinkNumber(entry, "GetItemLinkQuality")
end

-- Public wrapper so the UI sorts resolve quality exactly the way Query's
-- quality FILTER does. Reading entry.quality directly (as the gamepad sort
-- used to) collapses every entry whose cached quality is missing to 0, so
-- those rows clumped at one end instead of sorting by their real quality.
function Index:GetEntryQuality(entry)
    return entryQuality(entry) or 0
end

-- Case-insensitive comparator for the user-visible option lists below.
-- A raw `a < b` in Lua is a byte compare, so every capitalized name sorts
-- ahead of every lowercase one ("Zephyr" before "aegis") and accented names
-- land after "Z". The second term keeps the order deterministic when two
-- labels differ only by case, so table.sort can't shuffle them per rebuild.
local function labelLess(a, b)
    a, b = a or "", b or ""
    local la, lb = string.lower(a), string.lower(b)
    if la ~= lb then return la < lb end
    return a < b
end

-- ---------------------------------------------------------------------------
-- Public query API
-- ---------------------------------------------------------------------------

-- Filter shape (all optional):
--   {
--     itemType   = number,
--     subtypeId  = number,
--     setId      = number,
--     traitType  = number,
--     quality    = number,
--     equipType  = number,
--     bound      = "any" | "boundOnly" | "unboundOnly",
--     characterId= string,
--     locationKey= string,
--     categoryKey= string?,   -- "all"|"weapon"|"armor"|"consumable"|"material"|"glyph"|"furnishing"|"misc"
--     text       = string?,    -- PC-only free-text; ignored on console
--   }
function Index:Query(filter)
    filter = filter or {}
    if not cacheValid then rebuildRows() end

    local out = {}
    for _, row in ipairs(lastResults) do
        local entry = row.entry
        local keep = true

        if filter.itemType   and entry.itemType   ~= filter.itemType   then keep = false end
        if keep and not entryMatchesCategory(entry, filter.categoryKey) then keep = false end
        -- Row-level "Equipped" view: only pieces the character is actually
        -- wearing. isWorn is set by emitRowsForCharacter for BAG_WORN rows, so
        -- this cannot be decided inside entryMatchesCategory (which only sees
        -- the item). Combine with filter.characterId to scope it to a single
        -- character; without one, every character's worn kit is shown.
        if keep and filter.categoryKey == "equipped" and not row.isWorn then keep = false end
        if keep and filter.companionType
           and not entryMatchesCompanionType(entry, filter.companionType) then keep = false end
        if keep and filter.setId      and entry.setId      ~= filter.setId      then keep = false end
        -- P2 #16: filter parity for setName (the keyboard tab sets this even
        -- when the resolver couldn't map it to a setId). String match is
        -- case-insensitive.
        if keep and filter.setName and filter.setName ~= "" then
            local ename = entry.setName or ""
            if string.lower(ename) ~= string.lower(filter.setName) then keep = false end
        end
        if keep and filter.traitType  and entry.traitType  ~= filter.traitType  then keep = false end
        if keep and filter.traitTypes and not setContainsValue(filter.traitTypes, entry.traitType) then keep = false end
        if keep and filter.armorType  and entry.armorType  ~= filter.armorType  then keep = false end
        if keep and filter.weaponType and entry.weaponType ~= filter.weaponType then keep = false end
        if keep and filter.weaponTypes and not setContainsValue(filter.weaponTypes, entry.weaponType) then keep = false end
        if keep and filter.itemTypes and not setContainsValue(filter.itemTypes, entry.itemType) then keep = false end
        if keep and filter.specializedTypes and not setContainsValue(filter.specializedTypes, entrySpecializedItemType(entry)) then keep = false end
        if keep and filter.traitName and filter.traitName ~= "" then
            local tname = entry.traitName or ""
            if string.lower(tname) ~= string.lower(filter.traitName) then keep = false end
        end
        if keep and filter.quality    and entryQuality(entry) ~= filter.quality    then keep = false end
        if keep and filter.equipType  and entry.equipType  ~= filter.equipType  then keep = false end
        if keep and filter.requiredLevelType == "level" then
            local level = entryRequiredLevel(entry)
            if level then
                if filter.minLevel and level < filter.minLevel then keep = false end
                if filter.maxLevel and level > filter.maxLevel then keep = false end
            end
        end
        if keep and filter.requiredLevelType == "cp" then
            local cp = entryRequiredChampionPoints(entry)
            if cp then
                if filter.minLevel and cp < filter.minLevel then keep = false end
                if filter.maxLevel and cp > filter.maxLevel then keep = false end
            end
        end
        if keep and filter.characterId and row.characterId ~= filter.characterId then keep = false end
        if keep and filter.locationKey and row.locationKey ~= filter.locationKey then keep = false end

        if keep and filter.bound == "boundOnly"   and not entry.isCharacterBound then keep = false end
        if keep and filter.bound == "unboundOnly" and entry.isCharacterBound     then keep = false end

        if keep and filter.text and filter.text ~= "" then
            local needle = string.lower(filter.text)
            local hay    = string.lower(entry.name or "")
            if not hay:find(needle, 1, true) then keep = false end
        end

        if keep then out[#out + 1] = row end
    end

    -- Live craft-bag merge (never cached, so it always reflects the real bag).
    -- Honours the `scanCraftBag` setting: this used to be unconditional and the
    -- setting had no reader at all, so the checkbox silently did nothing. A
    -- dataVersion 5 migration forces the setting ON once, so switching it off is
    -- now a deliberate player choice rather than an upgrade surprise.
    local craftRows = {}
    local includeCraftBag = not (addon.sv and addon.sv.settings)
        or addon.sv.settings.scanCraftBag ~= false
    if includeCraftBag then
        emitRowsForCraftBag(craftRows)
    end
    for _, row in ipairs(craftRows) do
        local entry = row.entry
        local keep = true
        if filter.itemType   and entry.itemType   ~= filter.itemType   then keep = false end
        if keep and not entryMatchesCategory(entry, filter.categoryKey) then keep = false end
        -- Craft-bag rows are account-wide storage and are never worn, so the
        -- Equipped view must exclude them outright.
        if keep and filter.categoryKey == "equipped" then keep = false end
        if keep and filter.companionType
           and not entryMatchesCompanionType(entry, filter.companionType) then keep = false end
        -- The same item-level filters the persisted rows honour. Without these
        -- a narrowed view (one set, one trait, bound-only, a level band) still
        -- listed every unrelated craft material.
        if keep and filter.setId and entry.setId ~= filter.setId then keep = false end
        if keep and filter.setName and filter.setName ~= "" then
            if string.lower(entry.setName or "") ~= string.lower(filter.setName) then keep = false end
        end
        if keep and filter.traitType and entry.traitType ~= filter.traitType then keep = false end
        if keep and filter.traitName and filter.traitName ~= "" then
            if string.lower(entry.traitName or "") ~= string.lower(filter.traitName) then keep = false end
        end
        if keep and filter.bound == "boundOnly"   and not entry.isCharacterBound then keep = false end
        if keep and filter.bound == "unboundOnly" and entry.isCharacterBound     then keep = false end
        if keep and filter.requiredLevelType == "level" then
            local level = entryRequiredLevel(entry)
            if level then
                if filter.minLevel and level < filter.minLevel then keep = false end
                if filter.maxLevel and level > filter.maxLevel then keep = false end
            end
        end
        if keep and filter.requiredLevelType == "cp" then
            local cp = entryRequiredChampionPoints(entry)
            if cp then
                if filter.minLevel and cp < filter.minLevel then keep = false end
                if filter.maxLevel and cp > filter.maxLevel then keep = false end
            end
        end
        if keep and filter.traitTypes and not setContainsValue(filter.traitTypes, entry.traitType) then keep = false end
        if keep and filter.armorType  and entry.armorType  ~= filter.armorType  then keep = false end
        if keep and filter.weaponType and entry.weaponType ~= filter.weaponType then keep = false end
        if keep and filter.weaponTypes and not setContainsValue(filter.weaponTypes, entry.weaponType) then keep = false end
        if keep and filter.itemTypes and not setContainsValue(filter.itemTypes, entry.itemType) then keep = false end
        if keep and filter.specializedTypes and not setContainsValue(filter.specializedTypes, entrySpecializedItemType(entry)) then keep = false end
        if keep and filter.quality and entryQuality(entry) ~= filter.quality then keep = false end
        if keep and filter.equipType and entry.equipType ~= filter.equipType then keep = false end
        if keep and filter.characterId then keep = false end
        if keep and filter.text and filter.text ~= "" then
            local needle = string.lower(filter.text)
            local hay    = string.lower(entry.name or "")
            if not hay:find(needle, 1, true) then keep = false end
        end
        if filter.locationKey and filter.locationKey ~= "craftbag" then keep = false end
        if keep then out[#out + 1] = row end
    end

    return out
end

-- Lookup matching rows for a hold (used by the Mover). Item-holds match by
-- itemSignature equality; set-holds match any piece carrying the setId.
function Index:RowsForHold(hold)
    if not cacheValid then rebuildRows() end
    local out = {}
    for _, row in ipairs(lastResults) do
        local match = false
        if hold.holdType == "item" and row.entry.itemSignature == hold.itemSignature then
            match = true
        elseif hold.holdType == "set" and row.entry.setId == hold.setId then
            match = true
        end
        if match then out[#out + 1] = row end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Gear-only query, set/trait enumeration, and change-callback hook used by
-- the in-Inventory "Account Gear" tab (ui/InventoryTab_*.lua). All rows
-- returned satisfy isGear (armor + weapons + jewelry per the user spec).
-- ---------------------------------------------------------------------------

local function isGearEntry(entry)
    if not entry or not entry.itemType then return false end
    if ITEMTYPE_ARMOR  and entry.itemType == ITEMTYPE_ARMOR  then return true end
    if ITEMTYPE_WEAPON and entry.itemType == ITEMTYPE_WEAPON then return true end
    if ITEMTYPE_JEWELRY and entry.itemType == ITEMTYPE_JEWELRY then return true end
    return false
end

-- Same filter shape as :Query, plus all rows are restricted to gear.
function Index:QueryGear(filter)
    local rows = self:Query(filter or {})
    local out = {}
    for _, row in ipairs(rows) do
        if isGearEntry(row.entry) then
            out[#out + 1] = row
        end
    end
    return out
end

-- Enumerate distinct (setId, setName) pairs across the snapshot, each with:
--   * count           = UNIQUE pieces of that set owned account-wide (distinct
--                        items by name; duplicate copies counted once), and
--   * reconstructable  = pieces the player can RECONSTRUCT, read from the Item
--                        Set Collection ("sticker book"): the number of unlocked
--                        collection slots for the set
--                        (GetNumItemSetCollectionSlotsUnlocked). This is exactly
--                        what the in-game Collections menu shows.
-- The gamepad tab renders "<name> (<count> / <reconstructable>)" in the Sets
-- category. Sorted by name.
function Index:GetKnownSets()
    if not cacheValid then rebuildRows() end
    local byId, out = {}, {}
    for _, row in ipairs(lastResults) do
        local e = row.entry
        if isGearEntry(e) and e.setId and e.setId ~= 0 and e.setName then
            local item = byId[e.setId]
            if not item then
                item = { setId = e.setId, name = e.setName, count = 0, _pieces = {} }
                byId[e.setId] = item
                out[#out + 1] = item
            end
            local pieceKey = e.name or tostring(e.itemId or e.uniqueId or "?")
            if not item._pieces[pieceKey] then
                item._pieces[pieceKey] = true
                item.count = item.count + 1
            end
        end
    end
    for _, item in ipairs(out) do
        item._pieces = nil
        -- Reconstructable pieces from the player's Item Set Collection. Guarded:
        -- this API is unavailable in the test harness and could be absent on
        -- older clients, in which case R degrades to 0.
        item.reconstructable = 0
        if type(_G) == "table" and type(_G.GetNumItemSetCollectionSlotsUnlocked) == "function" then
            local ok, n = pcall(_G.GetNumItemSetCollectionSlotsUnlocked, item.setId)
            if ok and type(n) == "number" then item.reconstructable = n end
        end
    end
    table.sort(out, function(a, b) return labelLess(a.name, b.name) end)
    return out
end

-- Enumerate distinct (traitType, traitName) pairs. Trait names that are
-- empty strings (untraited) are skipped.
function Index:GetKnownTraits()
    if not cacheValid then rebuildRows() end
    local seen, out = {}, {}
    for _, row in ipairs(lastResults) do
        local e = row.entry
        if isGearEntry(e) and e.traitType and e.traitName
           and e.traitName ~= "" and not seen[e.traitType] then
            seen[e.traitType] = true
            out[#out + 1] = { traitType = e.traitType, name = e.traitName }
        end
    end
    table.sort(out, function(a, b) return labelLess(a.name, b.name) end)
    return out
end

-- Enumerate distinct weapon types present in the snapshot, labelled via the
-- game's SI_WEAPONTYPE string enum. Used by the gamepad Weapon Type sub-filter
-- (shown only when the Weapons category is active). Skips WEAPONTYPE_NONE.
function Index:GetKnownWeaponTypes()
    if not cacheValid then rebuildRows() end
    local none = _G["WEAPONTYPE_NONE"]
    local seen, out = {}, {}
    for _, row in ipairs(lastResults) do
        local wt = row.entry and row.entry.weaponType
        if wt and wt ~= 0 and wt ~= none and not seen[wt] then
            seen[wt] = true
            local label = (GetString and GetString("SI_WEAPONTYPE", wt)) or ""
            if label == "" then label = tostring(wt) end
            out[#out + 1] = { value = wt, label = label }
        end
    end
    table.sort(out, function(a, b) return labelLess(a.label, b.label) end)
    return out
end

-- Enumerate distinct armor weights (Light/Medium/Heavy) present in the
-- snapshot, labelled via SI_ARMORTYPE. Used by the gamepad Armor Weight
-- sub-filter (shown only when the Armor category is active). Skips
-- ARMORTYPE_NONE (shields, off-hand foci, etc.).
function Index:GetKnownArmorTypes()
    if not cacheValid then rebuildRows() end
    local none = _G["ARMORTYPE_NONE"]
    local seen, out = {}, {}
    for _, row in ipairs(lastResults) do
        local at = row.entry and row.entry.armorType
        if at and at ~= 0 and at ~= none and not seen[at] then
            seen[at] = true
            local label = (GetString and GetString("SI_ARMORTYPE", at)) or ""
            if label == "" then label = tostring(at) end
            out[#out + 1] = { value = at, label = label }
        end
    end
    table.sort(out, function(a, b) return labelLess(a.label, b.label) end)
    return out
end

-- Enumerate distinct item qualities present across the whole snapshot
-- (all items, not just gear), sorted highest-quality first. Used to populate
-- the Quality-filter dropdown on the gamepad tab.
function Index:GetKnownQualities()
    if not cacheValid then rebuildRows() end
    local seen, out = {}, {}
    for _, row in ipairs(lastResults) do
        local q = row.entry and entryQuality(row.entry)
        if q and not seen[q] then
            seen[q] = true
            out[#out + 1] = q
        end
    end
    table.sort(out, function(a, b) return a > b end)
    return out
end

-- ---------------------------------------------------------------------------
-- Change callback: lets UI modules subscribe to "the snapshot is dirty"
-- notifications without polling. Scanner calls Index:Invalidate after each
-- write; we surface that here so the inventory tab can re-render.
-- ---------------------------------------------------------------------------
local changeCallbacks = {}

function Index:RegisterChangeCallback(fn)
    if type(fn) == "function" then
        changeCallbacks[#changeCallbacks + 1] = fn
    end
end

local function fireChangeCallbacks()
    for _, fn in ipairs(changeCallbacks) do
        local ok, err = pcall(fn)
        if not ok and addon and addon.Debug then
            addon:Debug("Index change callback failed: %s", tostring(err))
        end
    end
end

-- Coalesce change notifications. Invalidate is called once per inventory slot
-- update, so a burst (e.g. deconstructing a full bag, looting, a bulk deposit)
-- would otherwise fire the UI-rebuild callbacks hundreds of times in a frame.
-- We mark the cache dirty immediately (so the very next :Query is correct) but
-- debounce the expensive callback fan-out to a single deferred run. This is the
-- primary defence against the per-slot lag/memory churn that leaked into
-- unrelated activities like crafting/deconstruction.
local _notifyScheduled = false
local function scheduleNotify()
    if _notifyScheduled then return end
    if not (EVENT_MANAGER and EVENT_MANAGER.RegisterForUpdate
            and EVENT_MANAGER.UnregisterForUpdate and addon and addon.name) then
        -- No scheduler available (e.g. the test harness): fire synchronously.
        fireChangeCallbacks()
        return
    end
    _notifyScheduled = true
    local key = addon.name .. "_IndexNotify"
    EVENT_MANAGER:UnregisterForUpdate(key)
    EVENT_MANAGER:RegisterForUpdate(key, 100, function()
        EVENT_MANAGER:UnregisterForUpdate(key)
        _notifyScheduled = false
        fireChangeCallbacks()
    end)
end

-- Re-wrap :Invalidate so callbacks fire (debounced) on every dirty.
local _origInvalidate = Index.Invalidate
function Index:Invalidate()
    if _origInvalidate then _origInvalidate(self) end
    cacheValid = false
    scheduleNotify()
end
