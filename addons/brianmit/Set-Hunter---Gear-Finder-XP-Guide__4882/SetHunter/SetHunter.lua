-- SetHunter.lua : data layer. Where each set drops (LibItemSets), boss details
-- (SetHunter_Data.lua), collection progress, wishlist, travel, slash command.
-- Open with /sethunter (or /sh when free, or a keybind).

local ADDON_NAME = "SetHunter"
SetHunter = SetHunter or {}
local S = SetHunter
local L = S.L
local D = S.DATA

local defaults = {
    view = "here",          -- see CATEGORIES in SetHunter_UI.lua
    loc = nil,              -- location id when a single location is picked
    open = {},              -- [category] = true when expanded in the tree
    wishlist = {},          -- [itemSetId] = true
    wishTraits = {},        -- [itemSetId] = { [traitType] = true }, only for wishlist sets
    wishPieces = {},        -- [itemSetId] = { [collection slot key] = true }, only for wishlist sets
    wishAuto = {},          -- [itemSetId] = true: only on the wishlist because of picked pieces / traits
    missingOnly = false,
    recent = {},            -- Recently collected: { { s = setId, k = slot key, link, t = time, z = zoneId }, ... }
    itemsScope = nil,       -- My items dropdown: nil = all, a character id, "bank" or "house"
    announce = true,
    x = nil, y = nil,
    docked = true,
    launcherX = 16, launcherY = 88,   -- just under the Command Codex button
    launcherHidden = false,
    launcherCombatHide = true,   -- hide the button while in combat
    launcherCompact = false,     -- button shows only the shield
    bagButton = true,            -- Set Hunter button in the inventory and bank
    -- Owned set items (SetHunter_Inventory.lua)
    inv = { chars = {}, bank = {}, houses = {} },
    -- Dungeon runs (SetHunter_Run.lua)
    runSummary = true,
    runs = {},
    dropAlert = true,
    dropSound = true,
    dropOnlyNew = false,
    bankOpen = true,
}

ZO_CreateStringId("SI_BINDING_NAME_SETHUNTER_TOGGLE", L("BIND_TOGGLE"))

function S.Print(text)
    d("|c8FD17F" .. L("PREFIX") .. "|r " .. text)
end

-- "The Banished Cells I" -> "banishedcellsi": for matching names from different sources.
local function Squash(text)
    text = zo_strlower(zo_strformat("<<1>>", text or ""))
    text = text:gsub("^the%s+", "")
    return (text:gsub("[^%w]", ""))
end
S.Squash = Squash

-- LibItemSets ships inside Item Set Browser; everything set-related needs it.
function S.LIS()
    return LibItemSets
end

-- ---------------------------------------------------------------------------
-- Zones by name (the hand-written data uses English names)
-- ---------------------------------------------------------------------------
local zoneByName

function S.ZoneIdByName(name)
    if not zoneByName then
        zoneByName = {}
        for zoneId = 1, 2500 do
            local zoneName = GetZoneNameById(zoneId)
            if zoneName and zoneName ~= "" then
                local key = Squash(zoneName)
                if not zoneByName[key] then zoneByName[key] = zoneId end
            end
        end
    end
    return zoneByName[Squash(name)]
end

function S.ZoneName(zoneId)
    return ZO_CachedStrFormat(SI_ZONE_NAME, GetZoneNameById(zoneId))
end

-- ---------------------------------------------------------------------------
-- Sets
-- ---------------------------------------------------------------------------
local monsterBySet     -- Squash(set name) -> D.MONSTER_SETS entry

local function MonsterForSetName(name)
    if not monsterBySet then
        monsterBySet = {}
        for _, m in ipairs(D.MONSTER_SETS) do monsterBySet[Squash(m.set)] = m end
    end
    return monsterBySet[Squash(name)]
end

-- Collected pieces for a set; total is 0 for sets that aren't in the collections.
-- Remembered until the collection changes (S.collectionGen goes up), because the
-- overview pages look at every set in the game.
S.collectionGen = 0
local progressCache, progressGen = {}, -1
local function CollectionProgress(setId)
    if progressGen ~= S.collectionGen then progressCache, progressGen = {}, S.collectionGen end
    local cached = progressCache[setId]
    if not cached then
        local total = GetNumItemSetCollectionPieces(setId)
        local have = 0
        for i = 1, total do
            local _, slot = GetItemSetCollectionPieceInfo(setId, i)
            if IsItemSetCollectionSlotUnlocked(setId, slot) then have = have + 1 end
        end
        cached = { have, total }
        progressCache[setId] = cached
    end
    return cached[1], cached[2]
end
S.SetProgress = CollectionProgress

-- Crafted sets: how many researched traits the item needs (nil for other sets)
function S.CraftTraitsNeeded(setId)
    local LIS = S.LIS()
    local info = LIS and LIS.GetItemSetInfo(setId)
    if info and LIS.CheckFlag(info.flags, LIS.SPECIAL_CRAFTABLE) then return info.craftTraits or 0 end
    return nil
end

-- This character's research: every item line (Helmet, Bow, Ring...) with how many
-- traits are known. Research is per character, so this is for the one you're on.
local CRAFT_TYPES = { CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER, CRAFTING_TYPE_WOODWORKING,
    CRAFTING_TYPE_JEWELRYCRAFTING }   -- ipairs stops at a type an old client doesn't have
function S.ResearchLines()
    local list = {}
    for _, craft in ipairs(CRAFT_TYPES) do
        for line = 1, GetNumSmithingResearchLines(craft) do
            local name, icon, numTraits = GetSmithingResearchLineInfo(craft, line)
            local known = 0
            for t = 1, numTraits or 0 do
                local _, _, isKnown = GetSmithingResearchLineTraitInfo(craft, line, t)
                if isKnown then known = known + 1 end
            end
            list[#list + 1] = { name = zo_strformat("<<1>>", name), icon = icon, known = known }
        end
    end
    return list
end

-- Recently collected: every piece that unlocks in your Set Collection is written down
-- (newest first, the last 100), with when and in which zone.
local MAX_RECENT = 100
local function RecordUnlocks(setId, mask)
    if not setId or not mask or not GetItemSetCollectionSlotsInMask then return end
    local slots = { GetItemSetCollectionSlotsInMask(mask) }
    if #slots == 0 then return end
    local pieces = S.SetPieces(setId)
    for _, slot in ipairs(slots) do
        local key = Id64ToString(slot)
        local link
        for _, piece in ipairs(pieces) do
            if piece.key == key then link = piece.link break end
        end
        table.insert(S.sv.recent, 1, {
            s = setId, k = key, link = link, t = GetTimeStamp(),
            z = GetZoneId(GetUnitZoneIndex("player")),
        })
    end
    while #S.sv.recent > MAX_RECENT do table.remove(S.sv.recent) end
end

local function PieceName(pieceId)
    local link = GetItemSetCollectionPieceItemLink(pieceId, LINK_STYLE_DEFAULT, ITEM_TRAIT_TYPE_NONE)
    local wType = GetItemLinkWeaponType(link)
    if wType ~= WEAPONTYPE_NONE then return GetString("SI_WEAPONTYPE", wType) end
    return GetString("SI_EQUIPTYPE", GetItemLinkEquipType(link))
end

-- locked pieces as { "Head", "Ring x2", "Dagger" }
function S.MissingPieces(setId)
    local order, n = {}, {}
    for i = 1, GetNumItemSetCollectionPieces(setId) do
        local pieceId, slot = GetItemSetCollectionPieceInfo(setId, i)
        if not IsItemSetCollectionSlotUnlocked(setId, slot) then
            local name = PieceName(pieceId)
            if not n[name] then order[#order + 1] = name end
            n[name] = (n[name] or 0) + 1
        end
    end
    for i, name in ipairs(order) do
        if n[name] > 1 then order[i] = name .. " x" .. n[name] end
    end
    return order
end

local function TypeText(info)
    local LIS = S.LIS()
    local f = info.flags
    if LIS.CheckFlag(f, LIS.SPECIAL_CRAFTABLE) then return L("TYPE_CRAFTED", info.craftTraits or 0) end
    if LIS.CheckFlag(f, LIS.SPECIAL_MONSTER_SET) then return L("TYPE_MONSTER") end
    if LIS.CheckFlag(f, LIS.SPECIAL_MYTHIC) then return L("TYPE_MYTHIC") end
    if LIS.CheckFlag(f, LIS.SPECIAL_ABILITY_WEAPON) then return L("TYPE_WEAPON") end
    if LIS.CheckArmorWeight(f, LIS.ARMOR_WEIGHT_L) then return L("TYPE_LIGHT") end
    if LIS.CheckArmorWeight(f, LIS.ARMOR_WEIGHT_M) then return L("TYPE_MEDIUM") end
    if LIS.CheckArmorWeight(f, LIS.ARMOR_WEIGHT_H) then return L("TYPE_HEAVY") end
    if LIS.CheckArmorWeight(f, LIS.ARMOR_WEIGHT_ALL) then return L("TYPE_MIXED") end
    return L("TYPE_JEWELRY")
end

function S.SourceNames(info)
    local names = {}
    for _, sourceId in ipairs(info.sourceIds) do
        local name = S.LIS().GetSourceName(sourceId)
        if name ~= "" then names[#names + 1] = name end
    end
    if info.extraSourceInfo then names[#names + 1] = info.extraSourceInfo end
    return table.concat(names, ", ")
end

-- Everything the UI shows for one set (nil if LibItemSets doesn't know it).
function S.GetSetData(setId)
    local LIS = S.LIS()
    local info = LIS and LIS.GetItemSetInfo(setId)
    if not info then return nil end
    local have, total = CollectionProgress(setId)
    -- picked pieces (Wanted pieces...): the set shows the first of them instead of
    -- the set's sample item
    local link = info.sampleItemLink
    if S.HasWishPieces(setId) then
        for _, piece in ipairs(S.SetPieces(setId)) do
            if S.IsWantedPiece(setId, piece.key) then
                link = piece.link
                break
            end
        end
    end
    return {
        kind = "set",
        setId = setId,
        name = info.setName,
        typeText = TypeText(info),
        link = link,
        icon = GetItemLinkIcon(link),
        have = have,
        total = total,
        complete = total > 0 and have == total,
        owned = S.OwnedCount(setId),
        wish = S.sv.wishlist[setId] == true,
        monster = MonsterForSetName(info.setName),
        sourceIds = info.sourceIds,
        sources = S.SourceNames(info),
    }
end

-- Sets for a list of ids, A-Z, with the "missing pieces only" filter applied
-- (unless showAll).
function S.GetSets(setIds, showAll)
    local hideComplete = S.sv.missingOnly and not showAll
    local list = {}
    for _, setId in ipairs(setIds) do
        local data = S.GetSetData(setId)
        if data and not (hideComplete and data.complete) then list[#list + 1] = data end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- showAll: ignore "Missing only" (for counting progress, which needs the complete sets too)
-- What kind of set it is, for My items > By set type: "mythic", "monster", "crafted",
-- or where it drops ("dungeon", "trial", "arena", "overland", "pvp"), else "other".
local setKinds = {}
function S.SetKind(setId)
    if setKinds[setId] then return setKinds[setId] end
    local kind = "other"
    local LIS = S.LIS()
    local info = LIS and setId and LIS.GetItemSetInfo(setId)
    if info then
        if LIS.CheckFlag(info.flags, LIS.SPECIAL_MYTHIC) then
            kind = "mythic"
        elseif LIS.CheckFlag(info.flags, LIS.SPECIAL_MONSTER_SET) then
            kind = "monster"
        elseif LIS.CheckFlag(info.flags, LIS.SPECIAL_CRAFTABLE) then
            kind = "crafted"
        else
            for _, id in ipairs(info.sourceIds) do
                local loc = id > 0 and S.GetLocation(id)
                if loc then
                    kind = loc.kind
                    break
                end
            end
        end
    end
    setKinds[setId] = kind
    return kind
end

function S.GetSetsForLocation(locId, showAll)
    local LIS = S.LIS()
    if not LIS then return {} end
    return S.GetSets(LIS.GetAllItemSetIdsForSource(locId), showAll)
end

function S.SearchSets(text)
    local LIS = S.LIS()
    if not LIS then return {} end
    text = zo_strlower(text)
    local ids = {}
    for _, setId in ipairs(LIS.GetAllItemSetIds()) do
        local info = LIS.GetItemSetInfo(setId)
        if info and zo_strlower(info.setName):find(text, 1, true) then ids[#ids + 1] = setId end
    end
    return S.GetSets(ids)
end

function S.GetWishlistSets()
    local ids = {}
    for setId in pairs(S.sv.wishlist) do ids[#ids + 1] = setId end
    -- The wishlist always shows everything on it, even complete sets.
    return S.GetSets(ids, true)
end

-- Set id by (English or client) set name, for the monster helm list.
local setIdByName
function S.SetIdByName(name)
    local LIS = S.LIS()
    if not LIS then return nil end
    if not setIdByName then
        setIdByName = {}
        for _, setId in ipairs(LIS.GetAllItemSetIds()) do
            local info = LIS.GetItemSetInfo(setId)
            if info then setIdByName[Squash(info.setName)] = setId end
        end
    end
    return setIdByName[Squash(name)]
end

function S.ToggleWish(setId)
    S.sv.wishlist[setId] = not S.sv.wishlist[setId] or nil
    S.sv.wishAuto[setId] = nil   -- added or removed by hand: it's your call now
    if not S.sv.wishlist[setId] then
        S.sv.wishTraits[setId] = nil
        S.sv.wishPieces[setId] = nil
    end
    S.WatchWish(setId)
end

-- ---------------------------------------------------------------------------
-- Wanted traits on wishlist sets
-- ---------------------------------------------------------------------------
function S.IsWantedTrait(setId, trait)
    local wanted = setId and S.sv.wishTraits[setId]
    return wanted ~= nil and trait ~= nil and wanted[trait] == true
end

function S.HasWishTraits(setId)
    return next(S.sv.wishTraits[setId] or {}) ~= nil
end

-- auto: added only because a piece / trait was picked (taken off again with the last pick);
-- otherwise you want the whole set and it stays
function S.WishSet(setId, auto)
    if not S.sv.wishlist[setId] then
        S.sv.wishlist[setId] = true
        S.sv.wishAuto[setId] = auto or nil
        S.WatchWish(setId)
        local data = S.GetSetData(setId)
        if data then S.Print(L("WISH_ADDED", data.name)) end
    elseif not auto then
        S.sv.wishAuto[setId] = nil
    end
end

-- after un-picking: a set that only came with its picks leaves with the last one
local function DropIfNoPicks(setId)
    if S.sv.wishAuto[setId] and not S.HasWishPieces(setId) and not S.HasWishTraits(setId) then
        S.sv.wishlist[setId] = nil
        S.sv.wishAuto[setId] = nil
        S.WatchWish(setId)
    end
end

-- wanting a trait puts its set on the wishlist too
function S.ToggleWishTrait(setId, trait)
    S.WishSet(setId, true)
    local wanted = S.sv.wishTraits[setId] or {}
    wanted[trait] = not wanted[trait] or nil
    S.sv.wishTraits[setId] = next(wanted) and wanted or nil
    DropIfNoPicks(setId)
end

function S.ClearWishTraits(setId)
    S.sv.wishTraits[setId] = nil
end

-- "Divines, Bloodthirsty"
function S.WishTraitNames(setId)
    local names = {}
    for trait in pairs(S.sv.wishTraits[setId] or {}) do
        names[#names + 1] = GetString("SI_ITEMTRAITTYPE", trait)
    end
    table.sort(names)
    return table.concat(names, ", ")
end

-- ---------------------------------------------------------------------------
-- Wanted pieces on wishlist sets (a piece = a Set Collection slot, e.g. "Bow")
-- ---------------------------------------------------------------------------
function S.SlotKey(link)
    local slot = GetItemLinkItemSetCollectionSlot and GetItemLinkItemSetCollectionSlot(link)
    return slot and Id64ToString(slot) or nil
end

-- every piece of a set: { { key, name, unlocked }, ... } in collection order;
-- a name that comes twice (two rings) gets a number
function S.SetPieces(setId)
    local list, seen = {}, {}
    for i = 1, GetNumItemSetCollectionPieces(setId) do
        local pieceId, slot = GetItemSetCollectionPieceInfo(setId, i)
        local name = PieceName(pieceId)
        seen[name] = (seen[name] or 0) + 1
        if seen[name] > 1 then name = name .. " " .. seen[name] end
        -- gear type, for the picker's columns
        local link = GetItemSetCollectionPieceItemLink(pieceId, LINK_STYLE_DEFAULT, ITEM_TRAIT_TYPE_NONE)
        local equip = GetItemLinkEquipType(link)
        local group = "armor"
        if GetItemLinkWeaponType(link) ~= WEAPONTYPE_NONE then
            group = "weapon"
        elseif equip == EQUIP_TYPE_NECK or equip == EQUIP_TYPE_RING then
            group = "jewelry"
        end
        list[#list + 1] = { key = Id64ToString(slot), name = name, group = group,
            link = link, icon = GetItemLinkIcon(link),
            unlocked = IsItemSetCollectionSlotUnlocked(setId, slot) }
    end
    return list
end

function S.IsWantedPiece(setId, key)
    local wanted = setId and S.sv.wishPieces[setId]
    return wanted ~= nil and key ~= nil and wanted[key] == true
end

function S.HasWishPieces(setId)
    return next(S.sv.wishPieces[setId] or {}) ~= nil
end

-- wanting a piece puts its set on the wishlist too
function S.ToggleWishPiece(setId, key)
    S.WishSet(setId, true)
    local wanted = S.sv.wishPieces[setId] or {}
    wanted[key] = not wanted[key] or nil
    S.sv.wishPieces[setId] = next(wanted) and wanted or nil
    DropIfNoPicks(setId)
end

function S.ClearWishPieces(setId)
    S.sv.wishPieces[setId] = nil
end

-- "Bow, Chest"
function S.WishPieceNames(setId)
    local names = {}
    for _, piece in ipairs(S.SetPieces(setId)) do
        if S.IsWantedPiece(setId, piece.key) then names[#names + 1] = piece.name end
    end
    return table.concat(names, ", ")
end

-- the traits set gear can have, by gear type, A-Z. Listed by hand: the game also
-- has companion traits (Aggressive, Bolstered...) and ornate / intricate, nobody wants those
local PLAYER_TRAITS = {
    { key = "TRAITS_ARMOR", prefix = "ARMOR_", names = { "STURDY", "IMPENETRABLE", "REINFORCED", "WELL_FITTED",
        "TRAINING", "INFUSED", "PROSPEROUS", "DIVINES", "NIRNHONED" } },
    { key = "TRAITS_WEAPON", prefix = "WEAPON_", names = { "POWERED", "CHARGED", "PRECISE", "INFUSED",
        "DEFENDING", "TRAINING", "SHARPENED", "DECISIVE", "NIRNHONED" } },
    { key = "TRAITS_JEWELRY", prefix = "JEWELRY_", names = { "ARCANE", "HEALTHY", "ROBUST", "TRIUNE",
        "INFUSED", "PROTECTIVE", "SWIFT", "HARMONY", "BLOODTHIRSTY" } },
}

-- The game's own icon for a trait: its trait stone (Ruby = Divines, ...), straight from
-- the smithing data, matched by trait type so nothing is guessed.
local traitIcons
function S.TraitIcon(trait)
    if not traitIcons then
        traitIcons = {}
        if GetNumSmithingTraitItems and GetSmithingTraitItemInfo then
            for i = 1, GetNumSmithingTraitItems() do
                local ok, traitType, _, icon = pcall(GetSmithingTraitItemInfo, i)
                if ok and traitType and icon and icon ~= "" then traitIcons[traitType] = icon end
            end
        end
    end
    return traitIcons[trait]
end

local traitGroups

-- "Infused" exists for armor, weapons and jewelry (so do Training and Nirnhoned):
-- those get their gear type added, e.g. "Infused (Armor)"
local traitLabels
function S.TraitLabel(trait)
    if not traitLabels then
        traitLabels = {}
        local uses = {}
        for _, group in ipairs(S.TraitGroups()) do
            for _, t in ipairs(group.list) do uses[t.name] = (uses[t.name] or 0) + 1 end
        end
        for _, group in ipairs(S.TraitGroups()) do
            for _, t in ipairs(group.list) do
                traitLabels[t.trait] = uses[t.name] > 1 and string.format("%s (%s)", t.name, L(group.key)) or t.name
            end
        end
    end
    return traitLabels[trait] or GetString("SI_ITEMTRAITTYPE", trait)
end

function S.TraitGroups()
    if traitGroups then return traitGroups end
    traitGroups = {}
    for _, def in ipairs(PLAYER_TRAITS) do
        local group = { key = def.key, list = {} }
        for _, name in ipairs(def.names) do
            local trait = _G["ITEM_TRAIT_TYPE_" .. def.prefix .. name]
            if trait then
                group.list[#group.list + 1] = { trait = trait, name = GetString("SI_ITEMTRAITTYPE", trait), icon = S.TraitIcon(trait) }
            end
        end
        table.sort(group.list, function(a, b) return a.name < b.name end)
        traitGroups[#traitGroups + 1] = group
    end
    return traitGroups
end

-- ---------------------------------------------------------------------------
-- Mythic items (Antiquities): the fragments you dig up for one, where each lead is,
-- and how far you are. Matched by the antiquity's reward item (like Item Set Browser).
-- ---------------------------------------------------------------------------
local antiquityByItem   -- [itemId] = antiquity set id

local function AntiquitySetFor(setId)
    if not GetNextAntiquityId or not GetAntiquitySetRewardId or not GetItemRewardItemId then return nil end
    if not antiquityByItem then
        antiquityByItem = {}
        pcall(function()
            local id = GetNextAntiquityId()
            while id do
                local antSet = GetAntiquitySetId(id)
                if antSet and antSet ~= 0 then
                    local itemId = GetItemRewardItemId(GetAntiquitySetRewardId(antSet))
                    if itemId and itemId ~= 0 then antiquityByItem[itemId] = antSet end
                end
                id = GetNextAntiquityId(id)
            end
        end)
    end
    for _, piece in ipairs(S.SetPieces(setId)) do
        local antSet = antiquityByItem[GetItemLinkItemId(piece.link)]
        if antSet then return antSet end
    end
    local info = S.LIS() and S.LIS().GetItemSetInfo(setId)
    return info and antiquityByItem[GetItemLinkItemId(info.sampleItemLink)] or nil
end

-- { { name, zoneId, lead, found }, ... } or nil when the set isn't dug up
function S.MythicFragments(setId)
    local antSet = AntiquitySetFor(setId)
    if not antSet then return nil end
    local list = {}
    for i = 1, GetNumAntiquitySetAntiquities(antSet) do
        local id = GetAntiquitySetAntiquityId(antSet, i)
        local found = (DoesAntiquityNeedCombination and DoesAntiquityNeedCombination(id))
            or (GetNumAntiquitiesRecovered(id) or 0) > 0
        list[#list + 1] = {
            name = zo_strformat("<<1>>", GetAntiquityName(id)),
            zoneId = GetAntiquityZoneId(id),
            lead = DoesAntiquityHaveLead(id),
            found = found,
        }
    end
    return list
end

-- ---------------------------------------------------------------------------
-- Locations: every place a set drops, grouped by kind
-- kind: "dungeon", "trial", "arena", "overland", "pvp" or "other"
-- ---------------------------------------------------------------------------
local locations      -- [id] = { id, kind, name, monster, note, arena }
local locationLists  -- [kind] = { location, ... } A-Z

local function KindFromFlags(flags)
    local LIS = S.LIS()
    local found, count = nil, 0
    for kind, flag in pairs({
        trial = LIS.SOURCE_TYPE_TRIAL, arena = LIS.SOURCE_TYPE_ARENA, dungeon = LIS.SOURCE_TYPE_DUNGEON,
        pvp = LIS.SOURCE_TYPE_PVP, overland = LIS.SOURCE_TYPE_OVERLAND,
    }) do
        if LIS.CheckFlag(flags, flag) then found, count = kind, count + 1 end
    end
    return count == 1 and found or nil
end

local function BuildLocations()
    locations, locationLists = {}, {}
    local LIS = S.LIS()

    if LIS then
        -- A zone's kind: what its single-source sets say (a dungeon's sets drop only there).
        local votes = {}
        for _, setId in ipairs(LIS.GetAllItemSetIds()) do
            local info = LIS.GetItemSetInfo(setId)
            local kind = info and KindFromFlags(info.flags)
            for _, sourceId in ipairs(info and info.sourceIds or {}) do
                if sourceId < 0 then
                    locations[sourceId] = locations[sourceId]
                        or { id = sourceId, kind = "other", name = LIS.GetSourceName(sourceId) }
                else
                    votes[sourceId] = votes[sourceId] or {}
                    if kind then votes[sourceId][kind] = (votes[sourceId][kind] or 0) + 1 end
                end
            end
        end
        for zoneId, counts in pairs(votes) do
            local best, most = "overland", -1
            for kind, n in pairs(counts) do
                if n > most then best, most = kind, n end
            end
            locations[zoneId] = { id = zoneId, kind = best, name = LIS.GetSourceName(zoneId) }
        end
    end

    -- Our hand-written data names places; some names belong to two zones (e.g. a dungeon
    -- and its Update 51 solo version), so a place LibItemSets already lists wins, else
    -- the first zone with that name. (Picking the other one listed dungeons twice.)
    local byName = {}
    for id, loc in pairs(locations) do
        if id > 0 then byName[Squash(loc.name)] = id end
    end
    local function ZoneFor(name)
        return byName[Squash(name)] or S.ZoneIdByName(name)
    end

    -- Monster helms: known even without LibItemSets.
    for _, m in ipairs(D.MONSTER_SETS) do
        local zoneId = ZoneFor(m.loc)
        m.zoneId = zoneId
        if zoneId then
            locations[zoneId] = locations[zoneId] or { id = zoneId, kind = "dungeon", name = S.ZoneName(zoneId) }
            locations[zoneId].monster = m
        end
    end
    for name, note in pairs(D.LOCATION_NOTES) do
        local zoneId = ZoneFor(name)
        if zoneId and locations[zoneId] then locations[zoneId].note = note end
    end
    for name, size in pairs(D.ARENAS) do
        local zoneId = ZoneFor(name)
        if zoneId and locations[zoneId] then
            locations[zoneId].kind = "arena"
            locations[zoneId].arena = size
        end
    end

    for _, loc in pairs(locations) do
        locationLists[loc.kind] = locationLists[loc.kind] or {}
        table.insert(locationLists[loc.kind], loc)
    end
    for _, list in pairs(locationLists) do
        table.sort(list, function(a, b) return a.name < b.name end)
    end
end

function S.GetLocation(id)
    if not locations then BuildLocations() end
    return id and locations[id]
end

function S.GetLocations(kind)
    if not locations then BuildLocations() end
    return locationLists[kind] or {}
end

-- ---------------------------------------------------------------------------
-- Where the player is
-- ---------------------------------------------------------------------------
function S.GetPlayerZoneIds()
    local zoneId = GetZoneId(GetUnitZoneIndex("player"))
    local parent = GetParentZoneId(zoneId)
    if parent and parent ~= 0 and parent ~= zoneId then return zoneId, parent end
    return zoneId, nil
end

-- Sets for the player's zone, or its parent zone (a delve counts as its zone).
function S.GetHereLocation()
    local zoneId, parent = S.GetPlayerZoneIds()
    if S.GetLocation(zoneId) then return S.GetLocation(zoneId) end
    if parent and S.GetLocation(parent) then return S.GetLocation(parent) end
    return { id = zoneId, kind = "overland", name = S.ZoneName(zoneId), unknown = true }
end

-- Chat alert for wishlist sets that drop where the player just arrived.
local lastAnnounced
local function AnnounceWishlist()
    if not S.sv.announce or not S.LIS() then return end
    local loc = S.GetHereLocation()
    if loc.unknown or loc.id == lastAnnounced then return end
    lastAnnounced = loc.id
    local names = {}
    for _, data in ipairs(S.GetSetsForLocation(loc.id)) do
        if data.wish and not data.complete then
            local missing = data.total > 0 and string.format(" (%d/%d)", data.have, data.total) or ""
            names[#names + 1] = data.name .. missing
        end
    end
    if #names > 0 then S.Print(L("ANNOUNCE_MSG", table.concat(names, ", "))) end
end

-- ---------------------------------------------------------------------------
-- Travel: the location's own node (dungeon / trial entrance), else any known
-- wayshrine in that zone.
-- ---------------------------------------------------------------------------
function S.FindTravelNode(zoneId)
    if not zoneId or zoneId <= 0 then return nil end
    local wanted = Squash(GetZoneNameById(zoneId))
    local zoneIndex = GetZoneIndex(zoneId)
    local inZone
    for node = 1, GetNumFastTravelNodes() do
        local known, nodeName, _, _, _, _, poiType = GetFastTravelNodeInfo(node)
        if known then
            -- entrances can be named "Dungeon: Fungal Grotto I" / "Trial: ...": also try the part after ":"
            local afterColon = nodeName and nodeName:match(":%s*(.+)$")
            if Squash(nodeName) == wanted or (afterColon and Squash(afterColon) == wanted) then return node end
            if not inZone and poiType == POI_TYPE_WAYSHRINE then
                local nodeZoneIndex = GetFastTravelNodePOIIndicies(node)
                if nodeZoneIndex == zoneIndex then inZone = node end
            end
        end
    end
    if inZone then return inZone end
    -- Dungeon not discovered yet: a wayshrine in the zone it sits in.
    local parent = GetParentZoneId(zoneId)
    if parent and parent ~= 0 and parent ~= zoneId then return S.FindTravelNode(parent) end
    return nil
end

-- trials and group arenas can't be done alone: a warning for tooltips and the travel dialog
function S.GroupNote(zoneId)
    local loc = S.GetLocation(zoneId)
    if not loc then return nil end
    if loc.kind == "trial" then return L("NOTE_TRIAL") end
    if loc.kind == "arena" and loc.arena == "group" then return L("NOTE_GROUP_ARENA") end
    return nil
end

function S.TravelTo(zoneId)
    if IsUnitInCombat("player") then
        S.Print(L("TRAVEL_COMBAT"))
        return
    end
    local node = S.FindTravelNode(zoneId)
    if not node then
        S.Print(L("TRAVEL_NONE", S.ZoneName(zoneId)))
        return
    end
    local _, nodeName = GetFastTravelNodeInfo(node)
    local note = S.GroupNote(zoneId)
    ZO_Dialogs_ShowDialog("SETHUNTER_TRAVEL", { node = node },
        { mainTextParams = { nodeName, note and ("\n\n" .. note) or "" } })
end

-- ---------------------------------------------------------------------------
-- Dungeon queue: the Activity Finder's "specific dungeon" search, Normal or Veteran.
-- ---------------------------------------------------------------------------
local function ActivityName(activityId)
    if GetActivityName then return GetActivityName(activityId) end
    return (GetActivityInfo(activityId))
end

-- Activity id of a dungeon zone for the chosen difficulty (nil if it has none).
function S.FindDungeonActivity(zoneId, veteran)
    local activityType = veteran and LFG_ACTIVITY_MASTER_DUNGEON or LFG_ACTIVITY_DUNGEON
    if not activityType or not zoneId then return nil end
    local wanted = Squash(GetZoneNameById(zoneId))
    for i = 1, GetNumActivitiesByType(activityType) do
        local activityId = GetActivityIdByTypeAndIndex(activityType, i)
        if GetActivityZoneId and GetActivityZoneId(activityId) == zoneId then return activityId end
        local name = Squash(ActivityName(activityId)):gsub("^veteran", "")
        if name == wanted then return activityId end
    end
    return nil
end

-- Random Normal / Random Veteran Dungeon: in the Activity Finder that's an "activity set";
-- the one with the most dungeons in it is the random one (works in every game language).
function S.FindRandomDungeonSet(veteran)
    local activityType = veteran and LFG_ACTIVITY_MASTER_DUNGEON or LFG_ACTIVITY_DUNGEON
    if not activityType or not GetNumActivitySetsByType or not GetActivitySetIdByTypeAndIndex then return nil end
    local best, most = nil, 0
    for i = 1, GetNumActivitySetsByType(activityType) do
        local setId = GetActivitySetIdByTypeAndIndex(activityType, i)
        local n = setId and GetNumActivitySetActivities(setId) or 0
        if n > most then best, most = setId, n end
    end
    return best
end

function S.GetActivitySetBanner(setId)
    if not setId or not GetActivitySetKeyboardDescriptionTextures then return nil end
    local ok, texture = pcall(GetActivitySetKeyboardDescriptionTextures, setId)
    if ok and texture and texture ~= "" then return texture end
    return nil
end

function S.CanQueue(zoneId)
    local loc = S.GetLocation(zoneId)
    return loc ~= nil and loc.kind == "dungeon" and S.FindDungeonActivity(zoneId, false) ~= nil
end

-- Level / CP needed for an activity, and whether this character has it.
function S.GetActivityRequirement(activityId)
    local _, levelMin, _, cpMin = GetActivityInfo(activityId)
    levelMin, cpMin = levelMin or 0, cpMin or 0
    local meets = GetUnitLevel("player") >= levelMin
        and (cpMin == 0 or GetUnitChampionPoints("player") >= cpMin)
    return levelMin, cpMin, meets
end

-- The DLC an activity needs and whether this account has it (ESO Plus counts, the
-- game says unlocked then): collectibleId or nil, owned, DLC name.
function S.GetActivityDLC(activityId)
    if not activityId or not GetRequiredActivityCollectibleId then return nil, true end
    local id = GetRequiredActivityCollectibleId(activityId)
    if not id or id == 0 then return nil, true end
    return id, IsCollectibleUnlocked(id), zo_strformat("<<1>>", GetCollectibleName(id))
end

-- Dungeon art from the Activity Finder (nil when the game has none).
function S.GetActivityBanner(activityId)
    if not GetActivityKeyboardDescriptionTextures then return nil end
    local ok, texture = pcall(GetActivityKeyboardDescriptionTextures, activityId)
    if ok and texture and texture ~= "" then return texture end
    return nil
end

S.ROLES = {
    { role = LFG_ROLE_DPS,  key = "ROLE_DPS",  icon = "EsoUI/Art/LFG/LFG_icon_dps.dds" },
    { role = LFG_ROLE_HEAL, key = "ROLE_HEAL", icon = "EsoUI/Art/LFG/LFG_icon_healer.dds" },
    { role = LFG_ROLE_TANK, key = "ROLE_TANK", icon = "EsoUI/Art/LFG/LFG_icon_tank.dds" },
}

function S.RoleIcon(entry)
    if ZO_GetRoleIcon then
        local ok, icon = pcall(ZO_GetRoleIcon, entry.role)
        if ok and icon and icon ~= "" then return icon end
    end
    return entry.icon
end

-- The role the game will queue you as.
function S.GetRole()
    if GetSelectedLFGRole then return GetSelectedLFGRole() end
    return S.sv.role or LFG_ROLE_DPS
end

local function SetRole(role)
    S.sv.role = role
    for _, fnName in ipairs({ "UpdateSelectedLFGRole", "SetSelectedLFGRole" }) do
        local fn = _G[fnName]
        if fn and pcall(fn, role) then return true end
    end
    return false
end

function S.IsQueued()
    return IsCurrentlySearchingForGroup and IsCurrentlySearchingForGroup() or false
end

-- Only the leader queues a group.
function S.CanStartQueue()
    return not IsUnitGrouped("player") or IsUnitGroupLeader("player")
end

function S.LeaveQueue()
    if CancelGroupSearches then pcall(CancelGroupSearches) end
end

function S.QueueDungeon(zoneId, veteran, role)
    local difficulty = veteran and L("VETERAN") or L("NORMAL")
    local activityId = S.FindDungeonActivity(zoneId, veteran)
    if not activityId then
        S.Print(L("QUEUE_NONE", S.ZoneName(zoneId), difficulty))
        return false
    end
    if S.IsQueued() then
        S.Print(L("QUEUE_ALREADY"))
        return false
    end
    if role then SetRole(role) end
    local ok = pcall(function()
        ClearActivityFinderSearch()
        AddActivityFinderSpecificSearchEntry(activityId)
        StartActivityFinderSearch()
    end)
    if ok then
        S.Print(L("QUEUED", S.ZoneName(zoneId), difficulty, S.RoleName()))
    else
        S.Print(L("QUEUE_FAIL"))
    end
    return ok
end

function S.RoleName()
    for _, entry in ipairs(S.ROLES) do
        if entry.role == S.GetRole() then return L(entry.key) end
    end
    return ""
end

-- Queue for a Random Normal / Random Veteran Dungeon.
function S.QueueRandomDungeon(veteran, role)
    local difficulty = veteran and L("VETERAN") or L("NORMAL")
    local setId = S.FindRandomDungeonSet(veteran)
    if not setId or not AddActivityFinderSetSearchEntry then
        S.Print(L("QUEUE_FAIL"))
        return false
    end
    if S.IsQueued() then
        S.Print(L("QUEUE_ALREADY"))
        return false
    end
    if role then SetRole(role) end
    local ok = pcall(function()
        ClearActivityFinderSearch()
        AddActivityFinderSetSearchEntry(setId)
        StartActivityFinderSearch()
    end)
    if ok then
        S.Print(L("QUEUED", L("RANDOM_DUNGEON"), difficulty, S.RoleName()))
    else
        S.Print(L("QUEUE_FAIL"))
    end
    return ok
end

-- ---------------------------------------------------------------------------
-- Bank assistants (Tythis Andromo, Ezabi, Baron Jangleplume, ...): the ones this
-- account owns, found among the assistant collectibles. The game has no "banker"
-- flag, so they're recognized by name: their proper names are the same in every
-- game language, plus the word for banker in each language for new ones.
-- ---------------------------------------------------------------------------
local BANKER_NAME_PARTS = {
    "tythis", "ezabi", "jangleplume", "celia tyde", "pyroclast", "property steward",
    "banker", "bankier", "banquier", "banquero", "bursar",
}

function S.GetBankerAssistants()
    local list = {}
    local category = COLLECTIBLE_CATEGORY_TYPE_ASSISTANT
    if not category or not GetTotalCollectiblesByCategoryType then return list end
    for i = 1, GetTotalCollectiblesByCategoryType(category) do
        local id = GetCollectibleIdFromType(category, i)
        if id and IsCollectibleUnlocked(id) then
            local name = zo_strformat("<<1>>", GetCollectibleName(id))
            local lower = zo_strlower(name)
            for _, part in ipairs(BANKER_NAME_PARTS) do
                if lower:find(part, 1, true) then
                    local nick = GetCollectibleNickname(id)
                    list[#list + 1] = {
                        id = id,
                        -- "Tythis Andromo, the Banker" -> "Tythis Andromo" (your nickname if you gave one)
                        name = (nick and nick ~= "") and zo_strformat("<<1>>", nick) or (name:match("^([^,]+)") or name),
                        fullName = name,
                        icon = GetCollectibleIcon(id),
                    }
                    break
                end
            end
        end
    end
    table.sort(list, function(a, b) return a.name < b.name end)
    return list
end

-- For players without a bank assistant: which way the nearest bank is, from the bank
-- icons on the map of the zone you're in. Returns a direction key ("N", "NE", ...)
-- or nil (no bank on this map, e.g. in a dungeon).
local DIRECTIONS = { "E", "SE", "S", "SW", "W", "NW", "N", "NE" }

function S.NearestBankDirection()
    -- Don't move the world map around while the player is looking at it.
    if ZO_WorldMap_IsWorldMapShowing and ZO_WorldMap_IsWorldMapShowing() then return nil end
    if SetMapToPlayerLocation() == SET_MAP_RESULT_MAP_CHANGED then
        CALLBACK_MANAGER:FireCallbacks("OnWorldMapChanged")
    end
    local px, py = GetMapPlayerPosition("player")
    local bestDist, bx, by
    for i = 1, GetNumMapLocations() do
        local icon, x, y = GetMapLocationIcon(i)
        if icon and zo_strlower(icon):find("servicepin_bank", 1, true) then
            local dist = (x - px) ^ 2 + (y - py) ^ 2
            if not bestDist or dist < bestDist then bestDist, bx, by = dist, x, y end
        end
    end
    if not bestDist then return nil end
    if bestDist < 0.0004 then return "HERE" end   -- practically next to it
    -- Map y grows downward (south); turn the angle into one of 8 compass directions.
    local angle = math.atan2(by - py, bx - px)
    local index = zo_floor((angle / (2 * math.pi)) * 8 + 0.5) % 8 + 1
    return DIRECTIONS[index]
end

function S.SummonBanker(banker)
    local remaining = GetCollectibleCooldownAndDuration and GetCollectibleCooldownAndDuration(banker.id) or 0
    if remaining and remaining > 0 then
        S.Print(L("BANKER_COOLDOWN", banker.name, zo_ceil(remaining / 1000)))
        return
    end
    -- Newer game versions ask who uses it (the player); older ones take just the id.
    if not pcall(UseCollectible, banker.id, GAMEPLAY_ACTOR_CATEGORY_PLAYER) then
        pcall(UseCollectible, banker.id)
    end
    -- get the window out of the way so you can walk up to them
    S.Toggle(false)
end

local function RegisterDialogs()
    ZO_Dialogs_RegisterCustomDialog("SETHUNTER_TRAVEL", {
        title = { text = L("TITLE") },
        mainText = { text = L("TRAVEL_CONFIRM") },
        buttons = {
            { text = SI_DIALOG_ACCEPT, callback = function(dialog) FastTravelToNode(dialog.data.node) end },
            { text = SI_DIALOG_CANCEL },
        },
    })
end

-- ---------------------------------------------------------------------------
-- Slash command + init
-- ---------------------------------------------------------------------------
local function OnSlash(args)
    args = zo_strtrim(args or "")
    local sub = zo_strlower(args)
    if sub == "" then
        S.ToggleWindow()
    elseif sub == "help" then
        for _, line in ipairs(L("HELP")) do S.Print(line) end
    elseif sub == "settings" or sub == "options" then
        S.OpenSettings()
    elseif sub == "testdrop" then
        S.TestDrop()
    elseif sub == "testrun" then
        S.TestRunSummary()
    elseif sub == "here" or sub == "wishlist" or sub == "xp" or sub == "items" then
        S.OpenView(sub == "xp" and "xp_spots" or sub)
    else
        S.OpenWithSearch(args)
    end
end

local function OnPlayerActivated()
    -- the collection is only fully known once you're in the world
    S.collectionGen = S.collectionGen + 1
    if S.RefreshAll then S.RefreshAll() end
    zo_callLater(AnnounceWishlist, 1500)
end

local function OnAddOnLoaded(_, name)
    if name ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- data used to live under "Default"; hand it to the first server we log into
    -- so nobody loses their wishlist/scans when updating
    local world = GetWorldName()
    if SetHunter_SV and SetHunter_SV.Default and not SetHunter_SV[world] then
        SetHunter_SV[world] = SetHunter_SV.Default
        SetHunter_SV.Default = nil
    end
    S.sv = ZO_SavedVars:NewAccountWide("SetHunter_SV", 1, nil, defaults, world)
    RegisterDialogs()
    S.InitInventory()

    SLASH_COMMANDS["/sethunter"] = OnSlash
    if not SLASH_COMMANDS["/sh"] then SLASH_COMMANDS["/sh"] = OnSlash end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
    if EVENT_ITEM_SET_COLLECTION_UPDATED then
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ITEM_SET_COLLECTION_UPDATED, function(_, itemSetId, unlockedMask)
            RecordUnlocks(itemSetId, unlockedMask)
            S.collectionGen = S.collectionGen + 1
            -- owned pieces remember "in your collection or not": work that out again
            S.MarkOwnedDirty()
            if S.RefreshAll then S.RefreshAll() end
        end)
    end
    S.InitUI()
    S.InitRuns()
    S.InitXP()
    S.InitAlerts()
    S.InitSettings()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
