-- collect.lua: reads game state for each wire-v2 section and builds its payload bytes.
-- Every API used here is confirmed in ESOUIDocumentation.txt (API 101051); see docs/facts-verified.md.
-- Bit orders must match docs/wire-v2.md and the app's static DB.

CompanionExport = CompanionExport or {}

local Collect = {}
CompanionExport.Collect = Collect

local P = CompanionExport.Payload
local SCOPE_ACCOUNT, SCOPE_CHARACTER = P.SCOPE_ACCOUNT, P.SCOPE_CHARACTER
local ITEM_LINK_FMT = "|H0:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"

-- T order: blacksmithing, clothier, woodworking, jewelry (docs/wire-v2.md)
local function smithingTypes()
    return { CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER, CRAFTING_TYPE_WOODWORKING, CRAFTING_TYPE_JEWELRYCRAFTING }
end

local function charHeader()
    return { apiVersion = GetAPIVersion(), scope = SCOPE_CHARACTER, characterId = GetCurrentCharacterId() }
end

local function accountHeader()
    return { apiVersion = GetAPIVersion(), scope = SCOPE_ACCOUNT }
end

function Collect.profile()
    return P.encodeProfile(charHeader(), {
        classId = GetUnitClassId("player"),
        raceId = GetUnitRaceId("player"),
        alliance = GetUnitAlliance("player"),
        level = GetUnitLevel("player"),
        championPoints = GetUnitChampionPoints("player") or 0,
        esoPlus = IsESOPlusSubscriber(),
        platform = GetUIPlatform(),
        name = GetUnitName("player"),
        world = GetWorldName(),
    }), 1
end

function Collect.research()
    local now = GetTimeStamp()
    local records = {}
    for _, ct in ipairs(smithingTypes()) do
        for line = 1, GetNumSmithingResearchLines(ct) do
            local _, _, numTraits = GetSmithingResearchLineInfo(ct, line)
            for trait = 1, numTraits do
                local duration, remaining = GetSmithingResearchLineTraitTimes(ct, line, trait)
                if duration ~= nil and remaining ~= nil then
                    records[#records + 1] = { ct, line, trait, now + remaining }
                end
            end
        end
    end
    return P.encodeResearch(charHeader(), records), #records
end

function Collect.traits()
    local bits, known = {}, 0
    for _, ct in ipairs(smithingTypes()) do
        for line = 1, GetNumSmithingResearchLines(ct) do
            local _, _, numTraits = GetSmithingResearchLineInfo(ct, line)
            for trait = 1, numTraits do
                local _, _, isKnown = GetSmithingResearchLineTraitInfo(ct, line, trait)
                bits[#bits + 1] = isKnown and true or false
                if isKnown then known = known + 1 end
            end
        end
    end
    return P.encodeBitsetSection(charHeader(), bits), known
end

function Collect.recipes()
    local bits, known = {}, 0
    for list = 1, GetNumRecipeLists() do
        local _, numRecipes = GetRecipeListInfo(list)
        for index = 1, numRecipes do
            local isKnown = GetRecipeInfo(list, index)
            bits[#bits + 1] = isKnown and true or false
            if isKnown then known = known + 1 end
        end
    end
    return P.encodeBitsetSection(charHeader(), bits), known
end

--- M: bit i = is MOTIF_BOOK_IDS[i] known. The header carries the API version the id list was
--- generated for, because that list (not the live client) defines the bit order.
function Collect.motifs()
    local ids = CompanionExport.MOTIF_BOOK_IDS or {}
    local bits, known = {}, 0
    for i, id in ipairs(ids) do
        local isKnown = IsItemLinkBookKnown(string.format(ITEM_LINK_FMT, id))
        bits[i] = isKnown and true or false
        if isKnown then known = known + 1 end
    end
    local h = charHeader()
    h.apiVersion = CompanionExport.MOTIF_API_VERSION or h.apiVersion
    return P.encodeBitsetSection(h, bits), known
end

local function addSlot(counts, bagId, slotIndex)
    local itemId = GetItemId(bagId, slotIndex)
    if itemId and itemId > 0 then
        local stack = GetSlotStackSize(bagId, slotIndex)
        if stack and stack > 0 then
            counts[itemId] = (counts[itemId] or 0) + stack
        end
    end
end

local function collectBags(bagIds)
    local counts, n = {}, 0
    for _, bagId in ipairs(bagIds) do
        for slotIndex in ZO_IterateBagSlots(bagId) do -- handles the sparse Craft Bag too
            addSlot(counts, bagId, slotIndex)
        end
    end
    for _ in pairs(counts) do n = n + 1 end
    return counts, n
end

function Collect.backpack()
    local counts, n = collectBags({ BAG_BACKPACK })
    return P.encodeItems(charHeader(), counts), n
end

function Collect.bank()
    local bags = { BAG_BANK }
    if IsESOPlusSubscriber() then bags[2] = BAG_SUBSCRIBER_BANK end
    local counts, n = collectBags(bags)
    return P.encodeItems(accountHeader(), counts), n
end

function Collect.craftbag()
    if not HasCraftBagAccess() then
        return P.encodeItems(accountHeader(), {}), 0, "no Craft Bag access (ESO Plus inactive)"
    end
    local counts, n = collectBags({ BAG_VIRTUAL })
    return P.encodeItems(accountHeader(), counts), n
end

-- House storage chests: their contents are only readable while the chest is open, so the
-- add-on saves a snapshot each time you open (and close) one in your OWN house
-- (ui.lua wires EVENT_OPEN_BANK / EVENT_CLOSE_BANK). Snapshots live in SavedVariables.
local function houseBags()
    return {
        BAG_HOUSE_BANK_ONE, BAG_HOUSE_BANK_TWO, BAG_HOUSE_BANK_THREE, BAG_HOUSE_BANK_FOUR,
        BAG_HOUSE_BANK_FIVE, BAG_HOUSE_BANK_SIX, BAG_HOUSE_BANK_SEVEN, BAG_HOUSE_BANK_EIGHT,
        BAG_HOUSE_BANK_NINE, BAG_HOUSE_BANK_TEN,
    }
end

--- Chest index 1-10 for a house bank bag id, or nil.
function Collect.chestIndex(bagId)
    for i, b in ipairs(houseBags()) do
        if b == bagId then return i end
    end
    return nil
end

--- Save the open chest's contents. Returns the chest index or nil if not saved.
function Collect.snapshotChest(bagId, sv)
    if not (IsHouseBankBag(bagId) and IsOwnerOfCurrentHouse()) then return nil end
    local index = Collect.chestIndex(bagId)
    if not index then return nil end
    local counts = collectBags({ bagId })
    sv.chests = sv.chests or {}
    sv.chests[index] = { savedAt = GetTimeStamp(), items = counts }
    return index
end

function Collect.house()
    local sv = CompanionExport_SV or {}
    local chests = {}
    for index, c in pairs(sv.chests or {}) do
        chests[#chests + 1] = { index, c.savedAt or 0, c.items or {} }
    end
    return P.encodeHouse(accountHeader(), chests), #chests,
        #chests == 0 and "no chests saved yet: open your storage chests in your house once" or nil
end

-- Section code -> { name, collector }. ALL_ORDER is the /export all order.
Collect.SECTIONS = {
    P = { "profile", Collect.profile },
    R = { "research", Collect.research },
    T = { "traits", Collect.traits },
    E = { "recipes", Collect.recipes },
    M = { "motifs", Collect.motifs },
    B = { "backpack", Collect.backpack },
    K = { "bank", Collect.bank },
    C = { "craftbag", Collect.craftbag },
    S = { "house", Collect.house },
}
Collect.ALL_ORDER = { "P", "R", "T", "E", "M", "B", "K", "C", "S" }
Collect.ACCOUNT_SECTIONS = { K = true, C = true, S = true }
