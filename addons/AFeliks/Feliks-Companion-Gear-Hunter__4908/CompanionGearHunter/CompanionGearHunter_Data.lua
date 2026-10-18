CompanionGearHunter = CompanionGearHunter or {}
local CompanionGearHunter = CompanionGearHunter -- local reference, faster than repeated _G lookups

CompanionGearHunter.name = "CompanionGearHunter"
CompanionGearHunter.savedVariablesVersion = 1

-- Keep in sync with ## Version in CompanionGearHunter.txt on every real
-- release bump (see CompanionRoster's own versioning policy: bump only when
-- actually cutting a release, not on every commit).
CompanionGearHunter.version = "1.2.0"

CompanionGearHunter.Data = {}

local savedVars = nil

-- Slot categories. Plain numbers, not strings, so nothing depends on a word
-- (and a translation can never collide with a lookup key). Never saved; safe
-- to renumber.
CompanionGearHunter.Data.CATEGORY_ARMOR = 1
CompanionGearHunter.Data.CATEGORY_WEAPON = 2
CompanionGearHunter.Data.CATEGORY_JEWELRY = 3
local CATEGORY_ARMOR = CompanionGearHunter.Data.CATEGORY_ARMOR
local CATEGORY_WEAPON = CompanionGearHunter.Data.CATEGORY_WEAPON
local CATEGORY_JEWELRY = CompanionGearHunter.Data.CATEGORY_JEWELRY

-- Slot layout, in the same order the companion's own equipment paperdoll
-- uses (confirmed against companioncharacterwindow_keyboard.lua). "category"
-- picks which trait-type family (ITEM_TRAIT_TYPE_ARMOR_/WEAPON_/JEWELRY_*)
-- and which "wanted sub-type" dropdown (weight / weapon type / none) apply.
CompanionGearHunter.Data.SLOTS = {
    { key = "Head",      equipSlot = EQUIP_SLOT_HEAD,      label = GetString("SI_EQUIPSLOT", EQUIP_SLOT_HEAD),      category = CATEGORY_ARMOR },
    { key = "Shoulders",  equipSlot = EQUIP_SLOT_SHOULDERS, label = GetString("SI_EQUIPSLOT", EQUIP_SLOT_SHOULDERS), category = CATEGORY_ARMOR },
    { key = "Chest",      equipSlot = EQUIP_SLOT_CHEST,     label = GetString("SI_EQUIPSLOT", EQUIP_SLOT_CHEST),     category = CATEGORY_ARMOR },
    { key = "Hands",      equipSlot = EQUIP_SLOT_HAND,      label = GetString("SI_EQUIPSLOT", EQUIP_SLOT_HAND),     category = CATEGORY_ARMOR },
    { key = "Waist",      equipSlot = EQUIP_SLOT_WAIST,     label = GetString("SI_EQUIPSLOT", EQUIP_SLOT_WAIST),     category = CATEGORY_ARMOR },
    { key = "Legs",       equipSlot = EQUIP_SLOT_LEGS,      label = GetString("SI_EQUIPSLOT", EQUIP_SLOT_LEGS),      category = CATEGORY_ARMOR },
    { key = "Feet",       equipSlot = EQUIP_SLOT_FEET,      label = GetString("SI_EQUIPSLOT", EQUIP_SLOT_FEET),      category = CATEGORY_ARMOR },
    { key = "Necklace",   equipSlot = EQUIP_SLOT_NECK,      label = GetString("SI_EQUIPSLOT", EQUIP_SLOT_NECK),  category = CATEGORY_JEWELRY },
    { key = "Ring1",      equipSlot = EQUIP_SLOT_RING1,     label = GetString("SI_EQUIPSLOT", EQUIP_SLOT_RING1),      category = CATEGORY_JEWELRY },
    { key = "Ring2",      equipSlot = EQUIP_SLOT_RING2,     label = GetString("SI_EQUIPSLOT", EQUIP_SLOT_RING2),      category = CATEGORY_JEWELRY },
    { key = "MainHand",   equipSlot = EQUIP_SLOT_MAIN_HAND, label = GetString("SI_EQUIPSLOT", EQUIP_SLOT_MAIN_HAND),    category = CATEGORY_WEAPON },
    { key = "OffHand",    equipSlot = EQUIP_SLOT_OFF_HAND,  label = GetString("SI_EQUIPSLOT", EQUIP_SLOT_OFF_HAND),  category = CATEGORY_WEAPON },
}

-- Companion-only trait names. Confirmed against the real ITEM_TRAIT_TYPE_*
-- enum dump (esoui/esoui source): these 11 suffixes exist identically across
-- the ARMOR/WEAPON/JEWELRY trait families, beyond each family's normal
-- player-facing traits, and never appear on player gear. Looked up by
-- constructed name at runtime rather than hardcoded numeric ids, so a
-- renamed/removed constant just gets skipped instead of breaking.
local COMPANION_TRAIT_SUFFIXES = {
    "AGGRESSIVE", "AUGMENTED", "BOLSTERED", "FOCUSED", "INTRICATE",
    "ORNATE", "PROLIFIC", "QUICKENED", "SHATTERING", "SOOTHING", "VIGOROUS",
}

local CATEGORY_TRAIT_PREFIX = {
    [CATEGORY_ARMOR] = "ITEM_TRAIT_TYPE_ARMOR_",
    [CATEGORY_WEAPON] = "ITEM_TRAIT_TYPE_WEAPON_",
    [CATEGORY_JEWELRY] = "ITEM_TRAIT_TYPE_JEWELRY_",
}

-- Returns an ordered list of { traitType = <enum>, name = <localized string> }
-- for the given slot category.
function CompanionGearHunter.Data.GetTraitOptions(category)
    local prefix = CATEGORY_TRAIT_PREFIX[category]
    if not prefix then
        return {}
    end

    local options = {}
    for _, suffix in ipairs(COMPANION_TRAIT_SUFFIXES) do
        local traitType = _G[prefix .. suffix]
        if traitType ~= nil then
            local traitName = GetString("SI_ITEMTRAITTYPE", traitType)
            if traitName ~= "" then
                table.insert(options, { traitType = traitType, name = traitName })
            end
        end
    end
    table.sort(options, function(a, b) return a.name < b.name end)
    return options
end

-- Trait choices for the "All slots" row, which has to name a trait without
-- knowing which slot category it will land on: { suffix = "VIGOROUS",
-- name = <localized> }, named from the armor family (the names read the same in
-- all three). GetTraitTypeForSuffix turns a suffix into the real enum for one
-- category.
function CompanionGearHunter.Data.GetTraitSuffixOptions()
    local options = {}
    for _, suffix in ipairs(COMPANION_TRAIT_SUFFIXES) do
        local traitType = _G[CATEGORY_TRAIT_PREFIX[CATEGORY_ARMOR] .. suffix]
        if traitType ~= nil then
            local traitName = GetString("SI_ITEMTRAITTYPE", traitType)
            if traitName ~= "" then
                table.insert(options, { suffix = suffix, name = traitName })
            end
        end
    end
    table.sort(options, function(a, b) return a.name < b.name end)
    return options
end

function CompanionGearHunter.Data.GetTraitTypeForSuffix(category, suffix)
    local prefix = CATEGORY_TRAIT_PREFIX[category]
    return prefix and _G[prefix .. suffix] or nil
end

-- Names come from the game's own SI_ARMORTYPE strings (the same lookup the
-- game's tooltips use), so they are already translated.
CompanionGearHunter.Data.WEIGHT_OPTIONS = {
    { value = ARMORTYPE_LIGHT,  name = GetString("SI_ARMORTYPE", ARMORTYPE_LIGHT) },
    { value = ARMORTYPE_MEDIUM, name = GetString("SI_ARMORTYPE", ARMORTYPE_MEDIUM) },
    { value = ARMORTYPE_HEAVY,  name = GetString("SI_ARMORTYPE", ARMORTYPE_HEAVY) },
}

-- Weapon type names shown/selected for the weapon slots' "wanted sub-type"
-- and the equipped-item display. Confirmed real WEAPONTYPE_* values against
-- esoui/esoui; WEAPONTYPE_RUNE/NONE deliberately left out, not relevant to
-- companion melee/staff/shield gear.
-- The names come from the game's SI_WEAPONTYPE strings (already translated,
-- and the current in-game wording: Inferno/Ice/Healing Staff) - except the
-- three two-handed weapons, which the game names plain "Axe"/"Hammer"/"Sword",
-- the same as the one-handed ones; those use this addon's own strings.
local function GameWeaponTypeName(weaponType)
    return GetString("SI_WEAPONTYPE", weaponType)
end

local WEAPON_TYPE_NAMES = {
    [WEAPONTYPE_AXE] = GameWeaponTypeName(WEAPONTYPE_AXE),
    [WEAPONTYPE_BOW] = GameWeaponTypeName(WEAPONTYPE_BOW),
    [WEAPONTYPE_DAGGER] = GameWeaponTypeName(WEAPONTYPE_DAGGER),
    [WEAPONTYPE_FIRE_STAFF] = GameWeaponTypeName(WEAPONTYPE_FIRE_STAFF),
    [WEAPONTYPE_FROST_STAFF] = GameWeaponTypeName(WEAPONTYPE_FROST_STAFF),
    [WEAPONTYPE_HAMMER] = GameWeaponTypeName(WEAPONTYPE_HAMMER),
    [WEAPONTYPE_HEALING_STAFF] = GameWeaponTypeName(WEAPONTYPE_HEALING_STAFF),
    [WEAPONTYPE_LIGHTNING_STAFF] = GameWeaponTypeName(WEAPONTYPE_LIGHTNING_STAFF),
    [WEAPONTYPE_SHIELD] = GameWeaponTypeName(WEAPONTYPE_SHIELD),
    [WEAPONTYPE_SWORD] = GameWeaponTypeName(WEAPONTYPE_SWORD),
    [WEAPONTYPE_TWO_HANDED_AXE] = GetString(COMPANIONGEARHUNTER_WEAPON_TWO_HANDED_AXE),
    [WEAPONTYPE_TWO_HANDED_HAMMER] = GetString(COMPANIONGEARHUNTER_WEAPON_TWO_HANDED_HAMMER),
    [WEAPONTYPE_TWO_HANDED_SWORD] = GetString(COMPANIONGEARHUNTER_WEAPON_TWO_HANDED_SWORD),
}
CompanionGearHunter.Data.WEAPON_TYPE_NAMES = WEAPON_TYPE_NAMES

CompanionGearHunter.Data.WEAPON_TYPE_OPTIONS = {}
for value, weaponTypeName in pairs(WEAPON_TYPE_NAMES) do
    table.insert(CompanionGearHunter.Data.WEAPON_TYPE_OPTIONS, { value = value, name = weaponTypeName })
end
table.sort(CompanionGearHunter.Data.WEAPON_TYPE_OPTIONS, function(a, b) return a.name < b.name end)

-- What an Off-Hand can hold: a shield or a one-handed weapon (dual wield).
-- Bows, staves and the two-handed types never go there.
local OFF_HAND_WEAPON_TYPES = {
    [WEAPONTYPE_AXE] = true,
    [WEAPONTYPE_DAGGER] = true,
    [WEAPONTYPE_HAMMER] = true,
    [WEAPONTYPE_SHIELD] = true,
    [WEAPONTYPE_SWORD] = true,
}

-- The weapon-type choices for one weapon slot's "Type" dropdown: Off-Hand gets
-- only the types above; Main Hand gets everything except Shield, which can't
-- be held in the main hand.
function CompanionGearHunter.Data.GetWeaponTypeOptions(slotKey)
    local options = {}
    for _, option in ipairs(CompanionGearHunter.Data.WEAPON_TYPE_OPTIONS) do
        local allowed
        if slotKey == "OffHand" then
            allowed = OFF_HAND_WEAPON_TYPES[option.value] == true
        else
            allowed = option.value ~= WEAPONTYPE_SHIELD
        end
        if allowed then
            table.insert(options, option)
        end
    end
    return options
end

-- Quality floor options - deliberately skips ITEM_FUNCTIONAL_QUALITY_TRASH
-- (never relevant to gear worth hunting for). Confirmed via real source
-- (retraitstation_reconstruct_keyboard.lua) that these are a contiguous,
-- ascending numeric range, so a plain >= comparison is a valid "floor" check.
-- Names come from the game's own SI_ITEMQUALITY string table (Normal/Fine/
-- Superior/Epic/Legendary) rather than color nicknames, colorized to match
-- the item quality colors shown everywhere else in the game (the "or
-- better" meaning is explained via the column header's tooltip instead of
-- being spelled out in every option's text).
CompanionGearHunter.Data.QUALITY_OPTIONS = {}
for _, value in ipairs({
    ITEM_FUNCTIONAL_QUALITY_NORMAL,
    ITEM_FUNCTIONAL_QUALITY_MAGIC,
    ITEM_FUNCTIONAL_QUALITY_ARCANE,
    ITEM_FUNCTIONAL_QUALITY_ARTIFACT,
    ITEM_FUNCTIONAL_QUALITY_LEGENDARY,
}) do
    local displayName = GetItemQualityColor(value):Colorize(GetString("SI_ITEMQUALITY", value))
    table.insert(CompanionGearHunter.Data.QUALITY_OPTIONS, { value = value, name = displayName })
end

-- Companion enumeration - same discovery method as CompanionRoster
-- (companionId is a small integer, valid to query directly for any
-- companion regardless of summon state - see that project's own notes on
-- why this replaced an earlier hardcoded name list).
local MAX_COMPANION_DEF_ID = 30

function CompanionGearHunter.Data.GetAllCompanions()
    local companions = {}
    for companionId = 1, MAX_COMPANION_DEF_ID do
        local collectibleId = GetCompanionCollectibleId(companionId)
        if collectibleId ~= nil and collectibleId > 0 then
            table.insert(companions, {
                id = companionId,
                name = zo_strformat("<<1>>", GetCompanionName(companionId)),
            })
        end
    end
    table.sort(companions, function(a, b) return a.name < b.name end)
    return companions
end

-- Wishlist read/write ------------------------------------------------------
-- Each entry: { enabled = <bool|nil>, subType = <ARMORTYPE_*|WEAPONTYPE_*|nil>,
-- trait = <ItemTraitType|nil>, qualityFloor = <ItemFunctionalQuality|nil> }.
-- `enabled` is the master "hunting this slot" toggle (false/nil by default -
-- see SetWishlistEnabled); nil in subType/trait/qualityFloor means "Any".

local function GetOrCreateWishlistSlot(companionId, slotKey)
    savedVars.wishlist[companionId] = savedVars.wishlist[companionId] or {}
    savedVars.wishlist[companionId][slotKey] = savedVars.wishlist[companionId][slotKey] or {}
    return savedVars.wishlist[companionId][slotKey]
end

function CompanionGearHunter.Data.GetWishlistEntry(companionId, slotKey)
    local companionWishlist = savedVars.wishlist[companionId]
    return (companionWishlist and companionWishlist[slotKey]) or {}
end

-- Master toggle for the row - false/nil (the default) means "not hunting
-- this slot", which is what makes the 3 dropdowns disabled/blank rather
-- than just sitting on "Any" (see CompanionGearHunter_UI.lua's RefreshGrid).
function CompanionGearHunter.Data.SetWishlistEnabled(companionId, slotKey, value)
    GetOrCreateWishlistSlot(companionId, slotKey).enabled = value
end

function CompanionGearHunter.Data.SetWishlistSubType(companionId, slotKey, value)
    GetOrCreateWishlistSlot(companionId, slotKey).subType = value
end

function CompanionGearHunter.Data.SetWishlistTrait(companionId, slotKey, value)
    GetOrCreateWishlistSlot(companionId, slotKey).trait = value
end

function CompanionGearHunter.Data.SetWishlistQualityFloor(companionId, slotKey, value)
    GetOrCreateWishlistSlot(companionId, slotKey).qualityFloor = value
end

-- Bulk edit ("All slots" row) ----------------------------------------------

-- Sets one wanted field on every slot of a companion. `field` is "subType",
-- "trait" or "qualityFloor"; for "trait" the value is a trait suffix (see
-- GetTraitSuffixOptions), translated per slot to that category's own enum.
-- Weight only exists on armor, so "subType" skips weapons and jewelry. A real
-- value also ticks Find on the slots it touches (otherwise it would be stored
-- where no one can see it); "Any" (nil) just resets the field and leaves Find
-- alone, so it works as an undo. Off-Hand is skipped while it is closed (see
-- IsOffHandAvailable), so a bulk pick never quietly starts hunting an off-hand
-- the companion can't use.
function CompanionGearHunter.Data.ApplyToAllSlots(companionId, field, value)
    local skipOffHand = not CompanionGearHunter.Data.IsOffHandAvailable(companionId)

    for _, slotDef in ipairs(CompanionGearHunter.Data.SLOTS) do
        local applies = not (slotDef.key == "OffHand" and skipOffHand)
        if field == "subType" and slotDef.category ~= CATEGORY_ARMOR then
            applies = false
        end

        if applies then
            local slotEntry = GetOrCreateWishlistSlot(companionId, slotDef.key)
            if field == "trait" then
                slotEntry.trait = value ~= nil and CompanionGearHunter.Data.GetTraitTypeForSuffix(slotDef.category, value) or nil
            else
                slotEntry[field] = value
            end
            if value ~= nil then
                slotEntry.enabled = true
            end
        end
    end
end

-- Wipes the whole page for one companion (every slot, Off-Hand included);
-- other companions are untouched.
function CompanionGearHunter.Data.ClearCompanionWishlist(companionId)
    savedVars.wishlist[companionId] = nil
end

-- Item link decoding + wishlist matching ----------------------------------

-- EquipType -> candidate wishlist slot keys. A ring or one-handed weapon
-- sitting in a bag isn't yet assigned to a specific equip slot (Ring1 vs
-- Ring2, Main Hand vs Off-Hand), so matching checks every real candidate
-- rather than assuming one.
local EQUIP_TYPE_TO_SLOT_KEYS = {
    [EQUIP_TYPE_HEAD] = { "Head" },
    [EQUIP_TYPE_SHOULDERS] = { "Shoulders" },
    [EQUIP_TYPE_CHEST] = { "Chest" },
    [EQUIP_TYPE_HAND] = { "Hands" },
    [EQUIP_TYPE_WAIST] = { "Waist" },
    [EQUIP_TYPE_LEGS] = { "Legs" },
    [EQUIP_TYPE_FEET] = { "Feet" },
    [EQUIP_TYPE_NECK] = { "Necklace" },
    [EQUIP_TYPE_RING] = { "Ring1", "Ring2" },
    [EQUIP_TYPE_ONE_HAND] = { "MainHand", "OffHand" },
    [EQUIP_TYPE_TWO_HAND] = { "MainHand" },
    [EQUIP_TYPE_OFF_HAND] = { "OffHand" },
}

-- Weapon types that occupy both hands - a companion wielding one of these
-- has no Off-Hand item right now (the game's own paperdoll hides that slot).
-- Shared here (not just in the UI file) because upgrade-checking, the bulk
-- "All slots" edit and the equipped-gear lookup need the same fact: never
-- suggest an Off-Hand item for a companion who physically can't equip one
-- right now. The grid still shows the Off-Hand row, so it can be hunted for.
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

-- Whether this companion's cached Main Hand weapon currently occupies both
-- hands - if so, their Off-Hand is empty right now (see
-- GetCachedEquippedLink), upgrade suggestions skip it, and "All slots" leaves
-- it alone. The Off-Hand row itself is still shown and can still be hunted
-- for (a one-handed weapon plus Off-Hand is a build the companion could switch
-- to).
function CompanionGearHunter.Data.IsCompanionUsingTwoHandedWeapon(companionId)
    local mainHandLink = CompanionGearHunter.Data.GetCachedEquippedLink(companionId, "MainHand")
    if mainHandLink == nil then
        return false
    end
    return TWO_HANDED_WEAPON_TYPES[GetItemLinkWeaponType(mainHandLink)] == true
end

-- Whether the Off-Hand row can be used for a companion: only when their
-- effective Main Hand is one-handed. If the Main Hand row is ticked with a
-- specific weapon type, that wanted type decides (a one-handed type opens it, a
-- two-handed type closes it - this is how a sword-and-shield build is planned
-- for a companion who wields a staff today); otherwise whatever is equipped
-- decides. While it is closed the stored Off-Hand picks are kept but ignored by
-- matching, the dropdown star and the "All slots" bulk edit, and the grid
-- greys the row out.
function CompanionGearHunter.Data.IsOffHandAvailable(companionId)
    local mainHandWish = CompanionGearHunter.Data.GetWishlistEntry(companionId, "MainHand")
    if mainHandWish.enabled == true and mainHandWish.subType ~= nil then
        return TWO_HANDED_WEAPON_TYPES[mainHandWish.subType] ~= true
    end
    return not CompanionGearHunter.Data.IsCompanionUsingTwoHandedWeapon(companionId)
end

-- Candidate slots for an UPGRADE suggestion - same as
-- EQUIP_TYPE_TO_SLOT_KEYS[equipType], except Off-Hand is dropped when EITHER
-- the companion currently wields a two-handed weapon (see above) OR the
-- Off-Hand row is closed (IsOffHandAvailable: the Main Hand row is hunting a
-- two-hander, or a two-hander is equipped). Both are needed: with a two-hander
-- worn there is no equipped off-hand to compare against, and an empty slot
-- counts as an upgrade for anything, which would flag every shield - even when
-- the player has planned a one-handed build (Off-Hand open but still empty);
-- and a closed Off-Hand must never produce a suggestion at all (a companion
-- with nothing recorded in hand, hunting a staff, was flagged for every mace).
-- Wishlist matching does NOT use this - an Off-Hand row the player ticked
-- Find on is honored whenever it is open.
local function GetCandidateSlotKeysForCompanion(equipType, companionId)
    local slotKeys = EQUIP_TYPE_TO_SLOT_KEYS[equipType]
    if slotKeys == nil then
        return nil
    end
    if not CompanionGearHunter.Data.IsCompanionUsingTwoHandedWeapon(companionId)
        and CompanionGearHunter.Data.IsOffHandAvailable(companionId) then
        return slotKeys
    end

    local filtered = {}
    for _, slotKey in ipairs(slotKeys) do
        if slotKey ~= "OffHand" then
            table.insert(filtered, slotKey)
        end
    end
    return filtered
end

-- Derives weight/weapon type/trait/quality/equip-slot-type from an item
-- link, or nil for an empty/invalid link. Shared by the grid (decoding
-- equipped gear) and the inventory/bank matcher (decoding browsed items) -
-- keep this the single source of truth for "what does this item link mean"
-- rather than duplicating the GetItemLink* calls in more than one file.
function CompanionGearHunter.Data.DecodeItemLink(itemLink)
    if itemLink == nil or itemLink == "" then
        return nil
    end

    local traitType = GetItemLinkTraitInfo(itemLink)
    local armorType = GetItemLinkArmorType(itemLink)
    local weaponType = GetItemLinkWeaponType(itemLink)

    return {
        armorType = (armorType ~= ARMORTYPE_NONE) and armorType or nil,
        weaponType = (weaponType ~= WEAPONTYPE_NONE) and weaponType or nil,
        trait = (traitType ~= ITEM_TRAIT_TYPE_NONE) and traitType or nil,
        quality = GetItemLinkFunctionalQuality(itemLink),
        equipType = GetItemLinkEquipType(itemLink),
    }
end

-- Core per-field comparison (weight/type, trait, quality floor), shared by
-- every matching context below. Deliberately does NOT decide what an
-- all-"Any" entry means, since that differs by caller: FindWishlistMatches
-- treats it as "match anything" (browsing), while DoesInfoSatisfyWishlist
-- treats it as "never satisfied" (grid highlight/auto-uncheck) - see
-- CompanionGearHunter_UI.lua and the auto-uncheck note below for why.
local function MatchesWishlistFields(info, wishlistEntry)
    local itemSubType = info and (info.armorType or info.weaponType)
    return (wishlistEntry.subType == nil or wishlistEntry.subType == itemSubType)
        and (wishlistEntry.trait == nil or (info ~= nil and wishlistEntry.trait == info.trait))
        and (wishlistEntry.qualityFloor == nil or (info ~= nil and info.quality ~= nil and info.quality >= wishlistEntry.qualityFloor))
end

-- Returns a list of { companionId = .., slotKey = .. } for every active,
-- enabled wishlist entry (any companion) this item link satisfies - empty
-- if it isn't companion gear, or doesn't match anything currently wanted.
-- `GetItemLinkActorCategory` is the real, universal "is this companion
-- gear" check (confirmed against inventoryutils_gamepad.lua's own filter
-- logic) - it works on any item link regardless of where it came from
-- (bag, bank, guild store, trade, a chat link), which is what lets this
-- same function serve every later stage (guild bank/store/trade/chat) with
-- no changes once those hook their own sources in.
function CompanionGearHunter.Data.FindWishlistMatches(itemLink)
    local matches = {}

    if itemLink == nil or itemLink == "" then
        return matches
    end
    if GetItemLinkActorCategory(itemLink) ~= GAMEPLAY_ACTOR_CATEGORY_COMPANION then
        return matches
    end

    local info = CompanionGearHunter.Data.DecodeItemLink(itemLink)
    if EQUIP_TYPE_TO_SLOT_KEYS[info.equipType] == nil then
        return matches
    end

    for _, companion in ipairs(CompanionGearHunter.Data.GetAllCompanions()) do
        -- Every slot this equip type could go in. Only slots the player ticked
        -- Find on can match, and Off-Hand only counts while it is open for this
        -- companion (see IsOffHandAvailable) - a planned one-handed build counts
        -- even while a two-hander is worn. Upgrade suggestions are separate and
        -- skip Off-Hand for a two-hander wearer (GetCandidateSlotKeysForCompanion).
        local offHandOpen = CompanionGearHunter.Data.IsOffHandAvailable(companion.id)
        local slotKeys = EQUIP_TYPE_TO_SLOT_KEYS[info.equipType]
        for _, slotKey in ipairs(slotKeys) do
            local wishlistEntry = CompanionGearHunter.Data.GetWishlistEntry(companion.id, slotKey)
            if wishlistEntry.enabled == true and (slotKey ~= "OffHand" or offHandOpen) and MatchesWishlistFields(info, wishlistEntry) then
                table.insert(matches, { companionId = companion.id, slotKey = slotKey })
            end
        end
    end

    return matches
end

-- Returns a list of { companionId = .., slotKey = .. } for every companion
-- whose *currently equipped* gear in a matching slot this item link would
-- be a same-weight/type, same-trait, strictly-higher-quality upgrade over -
-- regardless of whether anyone's actively hunting for it (that's
-- FindWishlistMatches' job; this is a separate, softer "hey, this might be
-- worth a look" signal, deliberately skipping any slot that already has
-- its own "Find" enabled so the two don't produce redundant/conflicting
-- tooltip lines for the same row). Weight/type and trait must match
-- exactly - only quality is allowed to differ, and only upward (see the
-- comment inline below for an example of why this isn't just "any
-- higher quality item"). An empty slot is the one exception: anything
-- counts as an upgrade over nothing, since there's no existing build to
-- compare against. Only considers a companion once something has actually
-- been cached for them (see RecordActiveCompanionEquipment) - if a
-- companion's gear has never been observed, there's no real basis to call
-- anything an upgrade for them, so they're skipped rather than guessed at.
-- Master on/off setting for FindUpgradeOpportunities below - defaults to
-- enabled, toggled by "Find Gear Quality Upgrades" in the settings panel's
-- Gear Quality Upgrades section. While it is off, upgrades are ignored for
-- every companion, whatever their own setting below says.
function CompanionGearHunter.Data.GetUpgradeSuggestionsEnabled()
    return savedVars.upgradeSuggestionsEnabled ~= false
end

function CompanionGearHunter.Data.SetUpgradeSuggestionsEnabled(value)
    savedVars.upgradeSuggestionsEnabled = value
end

-- Per-companion upgrade switch, only consulted while the master setting above
-- is on. Everyone is ON by default, including companions added to the game
-- later, so only the companions turned OFF are stored.
function CompanionGearHunter.Data.GetUpgradeEnabledForCompanion(companionId)
    local disabled = savedVars.upgradeDisabledCompanions
    return not (disabled and disabled[companionId])
end

function CompanionGearHunter.Data.SetUpgradeEnabledForCompanion(companionId, value)
    savedVars.upgradeDisabledCompanions = savedVars.upgradeDisabledCompanions or {}
    savedVars.upgradeDisabledCompanions[companionId] = (value == false) and true or nil
end

function CompanionGearHunter.Data.FindUpgradeOpportunities(itemLink)
    local upgrades = {}

    if not CompanionGearHunter.Data.GetUpgradeSuggestionsEnabled() then
        return upgrades
    end
    if itemLink == nil or itemLink == "" then
        return upgrades
    end
    if GetItemLinkActorCategory(itemLink) ~= GAMEPLAY_ACTOR_CATEGORY_COMPANION then
        return upgrades
    end

    local info = CompanionGearHunter.Data.DecodeItemLink(itemLink)
    if info.quality == nil then
        return upgrades
    end
    if EQUIP_TYPE_TO_SLOT_KEYS[info.equipType] == nil then
        return upgrades
    end

    for _, companion in ipairs(CompanionGearHunter.Data.GetAllCompanions()) do
        if savedVars.equipped[companion.id] ~= nil and CompanionGearHunter.Data.GetUpgradeEnabledForCompanion(companion.id) then
            -- Per-companion, not computed once above the loop - see the
            -- matching note in FindWishlistMatches above.
            local slotKeys = GetCandidateSlotKeysForCompanion(info.equipType, companion.id)
            for _, slotKey in ipairs(slotKeys) do
                local wishlistEntry = CompanionGearHunter.Data.GetWishlistEntry(companion.id, slotKey)
                if wishlistEntry.enabled ~= true then
                    local equippedLink = CompanionGearHunter.Data.GetCachedEquippedLink(companion.id, slotKey)
                    local equippedInfo = CompanionGearHunter.Data.DecodeItemLink(equippedLink)

                    -- An empty slot counts as an upgrade for anything (see
                    -- comment above the function); otherwise weight/type
                    -- AND trait must match what's equipped exactly - only
                    -- quality is allowed to differ (and only upward). For
                    -- example: a Medium Quickened item currently
                    -- Fine should only flag a Medium Quickened Superior-or-
                    -- better, never a different weight or trait even at a
                    -- much higher quality - this is a same-build quality
                    -- bump suggestion, not a second wishlist match.
                    local isUpgrade
                    if equippedInfo == nil then
                        isUpgrade = true
                    else
                        local itemSubType = info.armorType or info.weaponType
                        local equippedSubType = equippedInfo.armorType or equippedInfo.weaponType
                        isUpgrade = itemSubType == equippedSubType
                            and info.trait == equippedInfo.trait
                            and equippedInfo.quality ~= nil
                            and info.quality > equippedInfo.quality
                    end

                    if isUpgrade then
                        table.insert(upgrades, { companionId = companion.id, slotKey = slotKey })
                    end
                end
            end
        end
    end

    return upgrades
end

-- Whether a decoded equipped-item `info` (see DecodeItemLink; nil for an
-- empty slot) counts as "satisfied" for a wishlist entry - used by the
-- grid's highlight and by the auto-uncheck logic below. An entry still
-- sitting on all-"Any" is never satisfied (unlike FindWishlistMatches
-- above) - "I want anything here" has no specific criteria that could ever
-- be considered met on its own, so it always keeps hunting/highlighting
-- until the player picks real criteria or unchecks it themselves.
function CompanionGearHunter.Data.DoesInfoSatisfyWishlist(info, wishlistEntry)
    if wishlistEntry.enabled ~= true then
        return false
    end
    if wishlistEntry.subType == nil and wishlistEntry.trait == nil and wishlistEntry.qualityFloor == nil then
        return false
    end
    return MatchesWishlistFields(info, wishlistEntry)
end

-- On/off setting for tagging companion gear item links in chat (see
-- CompanionGearHunter_Chat.lua) - defaults to enabled, toggled from the
-- grid window.
function CompanionGearHunter.Data.GetChatTaggingEnabled()
    return savedVars.chatTaggingEnabled ~= false
end

function CompanionGearHunter.Data.SetChatTaggingEnabled(value)
    savedVars.chatTaggingEnabled = value
end

-- The chat command that toggles the window, editable in the settings panel
-- and applied live (see CompanionGearHunter_Settings.lua).
function CompanionGearHunter.Data.GetSlashCommand()
    return savedVars.slashCommand
end

function CompanionGearHunter.Data.SetSlashCommand(command)
    savedVars.slashCommand = command
end

-- Text shown at the start of each tooltip line this addon adds ("FCGH: Wanted
-- for ..."), editable in the settings panel. Empty means no prefix.
CompanionGearHunter.Data.DEFAULT_TOOLTIP_PREFIX = "FCGH:"
local MAX_TOOLTIP_PREFIX_LENGTH = 20

function CompanionGearHunter.Data.GetTooltipPrefix()
    local prefix = savedVars.tooltipPrefix
    if prefix == nil then
        return CompanionGearHunter.Data.DEFAULT_TOOLTIP_PREFIX
    end
    return prefix
end

function CompanionGearHunter.Data.SetTooltipPrefix(value)
    value = (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
    savedVars.tooltipPrefix = string.sub(value, 1, MAX_TOOLTIP_PREFIX_LENGTH)
end

-- The one rule every marker uses (list badges, chat tags): "wanted" if the
-- item satisfies an enabled wishlist entry, otherwise "upgrade" if it's a
-- same-build quality upgrade, otherwise nil. Wanted wins when both apply.
function CompanionGearHunter.Data.GetMatchKind(itemLink)
    if itemLink == nil or itemLink == "" then
        return nil
    end
    if #CompanionGearHunter.Data.FindWishlistMatches(itemLink) > 0 then
        return "wanted"
    end
    if #CompanionGearHunter.Data.FindUpgradeOpportunities(itemLink) > 0 then
        return "upgrade"
    end
    return nil
end

-- The one marker every surface uses (list badges, chat tags, the companion
-- dropdown) so they read as a single signal: the game's own companion
-- inventory-tab icon, tinted green for a wishlist match and yellow for a
-- quality upgrade. Referenced by path; nothing is shipped.
CompanionGearHunter.Data.MARKER_ICON = "EsoUI/Art/Inventory/inventory_tabIcon_companion_up.dds"
CompanionGearHunter.Data.DEFAULT_MARKER_COLORS = {
    wanted = { 0.4, 1, 0.4 },
    upgrade = { 1, 0.88, 0.30 },
}

-- The player's chosen color for a marker kind ("wanted" / "upgrade"), set in
-- the settings panel, falling back to the default. Returns r, g, b (0-1).
-- Used by every surface that shows a marker - list badges, chat tags, the
-- companion dropdown, and the tooltip lines - so one setting recolors all.
function CompanionGearHunter.Data.GetMarkerColor(kind)
    local saved = savedVars and savedVars.markerColors and savedVars.markerColors[kind]
    local color = saved or CompanionGearHunter.Data.DEFAULT_MARKER_COLORS[kind]
    return color[1], color[2], color[3]
end

function CompanionGearHunter.Data.SetMarkerColor(kind, r, g, b)
    savedVars.markerColors = savedVars.markerColors or {}
    savedVars.markerColors[kind] = { r, g, b }
end

-- Same color as a "RRGGBB" string, for |c escape codes in chat and labels.
function CompanionGearHunter.Data.GetMarkerColorHex(kind)
    local r, g, b = CompanionGearHunter.Data.GetMarkerColor(kind)
    return string.format("%02X%02X%02X", zo_round(r * 255), zo_round(g * 255), zo_round(b * 255))
end

-- Whether a companion has at least one "Find" row still being hunted - i.e.
-- enabled and not already satisfied by what's cached as equipped. A ticked
-- Off-Hand row counts only while Off-Hand is open for this companion (see
-- IsOffHandAvailable); stored picks on a closed Off-Hand are ignored.
function CompanionGearHunter.Data.HasActiveHunt(companionId)
    local offHandOpen = CompanionGearHunter.Data.IsOffHandAvailable(companionId)
    for _, slotDef in ipairs(CompanionGearHunter.Data.SLOTS) do
        local wishlistEntry = CompanionGearHunter.Data.GetWishlistEntry(companionId, slotDef.key)
        if wishlistEntry.enabled == true and (slotDef.key ~= "OffHand" or offHandOpen) then
            local info = CompanionGearHunter.Data.DecodeItemLink(CompanionGearHunter.Data.GetCachedEquippedLink(companionId, slotDef.key))
            if not CompanionGearHunter.Data.DoesInfoSatisfyWishlist(info, wishlistEntry) then
                return true
            end
        end
    end
    return false
end

-- Auto-unchecks a slot's "Find" box once its cached equipped item already
-- satisfies what was being hunted for, so there's nothing to remember to
-- turn off by hand. Also resets subType/trait/qualityFloor back to
-- "Any" - not just the enabled flag - so the leftover matched criteria
-- can't immediately re-satisfy themselves (and re-clear the box right back
-- off) the next time "Find" is checked again for that slot, e.g. to hunt
-- for something else, or the same trait at a higher quality. Safe/
-- idempotent to call whenever - a no-op if the entry isn't enabled or
-- isn't satisfied yet.
function CompanionGearHunter.Data.AutoClearIfSatisfiedWishlist(companionId, slotKey)
    local wishlistEntry = CompanionGearHunter.Data.GetWishlistEntry(companionId, slotKey)
    if wishlistEntry.enabled ~= true then
        return
    end

    local itemLink = CompanionGearHunter.Data.GetCachedEquippedLink(companionId, slotKey)
    local info = CompanionGearHunter.Data.DecodeItemLink(itemLink)
    if CompanionGearHunter.Data.DoesInfoSatisfyWishlist(info, wishlistEntry) then
        CompanionGearHunter.Data.SetWishlistEnabled(companionId, slotKey, false)
        CompanionGearHunter.Data.SetWishlistSubType(companionId, slotKey, nil)
        CompanionGearHunter.Data.SetWishlistTrait(companionId, slotKey, nil)
        CompanionGearHunter.Data.SetWishlistQualityFloor(companionId, slotKey, nil)
    end
end

-- Equipped-gear cache ("last known", by design) ---------------------------
-- The game only ever exposes a companion's worn gear (BAG_COMPANION_WORN)
-- while that companion is actually summoned - same limitation CompanionRoster
-- documented for rapport/skills. So this records whatever was last seen
-- whenever a companion is active, and simply keeps showing that after they're
-- dismissed. Stored as the raw item link (or `false` for a confirmed-empty
-- slot) so weight/trait/quality/name can all be derived from it on demand,
-- and so the tooltip can link the exact item later if wanted.

function CompanionGearHunter.Data.GetCachedEquippedLink(companionId, slotKey)
    -- A two-handed weapon fills both hands, so the Off-Hand reads as empty
    -- whatever an older recording left in the cache. Checked on Main Hand only
    -- (slotKey ~= "OffHand"), so this can't recurse.
    if slotKey == "OffHand" and CompanionGearHunter.Data.IsCompanionUsingTwoHandedWeapon(companionId) then
        return nil
    end

    local companionCache = savedVars.equipped[companionId]
    local link = companionCache and companionCache[slotKey]
    if link == false or link == nil then
        return nil
    end
    return link
end

local function RecordActiveCompanionEquipment()
    if not HasActiveCompanion() then
        return
    end
    local companionId = GetActiveCompanionDefId()
    if companionId == nil or companionId == 0 then
        return
    end

    savedVars.equipped[companionId] = savedVars.equipped[companionId] or {}
    local cache = savedVars.equipped[companionId]

    for _, slotDef in ipairs(CompanionGearHunter.Data.SLOTS) do
        local link = GetItemLink(BAG_COMPANION_WORN, slotDef.equipSlot)
        cache[slotDef.key] = (link ~= "" and link) or false
        CompanionGearHunter.Data.AutoClearIfSatisfiedWishlist(companionId, slotDef.key)
    end
end

function CompanionGearHunter.Data.GetActiveCompanionId()
    if not HasActiveCompanion() then
        return nil
    end
    local companionId = GetActiveCompanionDefId()
    if companionId == nil or companionId == 0 then
        return nil
    end
    return companionId
end

-- Window position (account-wide UI preference, not game data) ------------

function CompanionGearHunter.Data.GetWindowPosition()
    return savedVars.windowPosition
end

function CompanionGearHunter.Data.SaveWindowPosition(point, relativePoint, offsetX, offsetY)
    savedVars.windowPosition = { point = point, relativePoint = relativePoint, offsetX = offsetX, offsetY = offsetY }
end

-- Events -------------------------------------------------------------------

local function RefreshGridIfOpen()
    if CompanionGearHunter.RefreshGrid then
        CompanionGearHunter.RefreshGrid()
    end
end

-- Only ever called for BAG_COMPANION_WORN: the AddFilterForEvent in
-- SetEquipmentEventsRegistered below filters the event by bag before any Lua
-- runs.
local function OnCompanionEquipmentSlotUpdate()
    RecordActiveCompanionEquipment()
    RefreshGridIfOpen()
end

-- The equipment-change event is only registered while a companion is out: with
-- none summoned there is no worn gear that can change, so nothing needs to
-- listen. Idempotent; `equipmentEventsRegistered` is the one source of truth.
local EVENT_NAMESPACE = "CompanionGearHunter_Data"
local equipmentEventsRegistered = false

local function SetEquipmentEventsRegistered(enabled)
    if enabled == equipmentEventsRegistered then
        return
    end
    equipmentEventsRegistered = enabled
    if enabled then
        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnCompanionEquipmentSlotUpdate)
        EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_COMPANION_WORN)
    else
        EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    end
end

-- Registers or unregisters the equipment event to match whether a companion is
-- out right now. Run at load and on every player activation (a /reloadui or
-- zone change with a companion already summoned fires no companion event).
function CompanionGearHunter.Data.CheckEnableEvents()
    SetEquipmentEventsRegistered(HasActiveCompanion())
end

-- The companion events themselves say which way to go, so they set the state
-- directly rather than asking HasActiveCompanion() (whose value this early in
-- the event is not something we have verified).
local function OnCompanionActivated()
    SetEquipmentEventsRegistered(true)
    RecordActiveCompanionEquipment()
    RefreshGridIfOpen()
end

local function OnCompanionDeactivated()
    SetEquipmentEventsRegistered(false)
end

-- Called once from the addon's single EVENT_ADD_ON_LOADED handler
-- (CompanionGearHunter.lua), before anything else uses the saved data.
function CompanionGearHunter.Data.Initialize()
    -- GetWorldName() namespaces by server, same reasoning as CompanionRoster:
    -- avoids mixing data from two different servers under one @account.
    local defaults = { wishlist = {}, equipped = {}, upgradeSuggestionsEnabled = true, upgradeDisabledCompanions = {}, chatTaggingEnabled = true, markerColors = {}, tooltipPrefix = "FCGH:", slashCommand = "/fcgh" }
    savedVars = ZO_SavedVars:NewAccountWide("CompanionGearHunter_SavedVariables", CompanionGearHunter.savedVariablesVersion, GetWorldName(), defaults)

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_COMPANION_ACTIVATED, OnCompanionActivated)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_COMPANION_DEACTIVATED, OnCompanionDeactivated)

    CompanionGearHunter.Data.CheckEnableEvents()
    if HasActiveCompanion() then
        RecordActiveCompanionEquipment()
    end
end

-- Called from the single EVENT_PLAYER_ACTIVATED handler on every activation
-- (login, /reloadui, zone change): re-syncs the event registration and the
-- equipment cache with a companion that may already be out.
function CompanionGearHunter.Data.OnPlayerActivated()
    CompanionGearHunter.Data.CheckEnableEvents()
    RecordActiveCompanionEquipment()
    RefreshGridIfOpen()
end
