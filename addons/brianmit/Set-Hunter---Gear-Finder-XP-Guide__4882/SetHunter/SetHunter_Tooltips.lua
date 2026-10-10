-- SetHunter_Tooltips.lua : a few Set Hunter lines in the game's own item tooltips
-- (bag, bank, worn gear, crafting stations, loot): is the piece on your wishlist or a
-- trait you hunt, is it missing from your Set Collection, and do you own it more often
-- (and where). Only set items; nothing is added when there's nothing to say.
-- Our own window uses ItemTooltip:SetLink, which isn't hooked, so its tooltips stay as
-- they are. Hook pattern (ZO_PostHook on ItemTooltip) as Item Set Browser does it.

local S = SetHunter
local L = S.L

local MAX_PLACES = 3

local SCANNED = {}   -- bags Set Hunter reads: the hovered piece is one of the counted ones
SCANNED[BAG_BACKPACK], SCANNED[BAG_WORN], SCANNED[BAG_BANK] = "char", "worn", "bank"
if BAG_SUBSCRIBER_BANK then SCANNED[BAG_SUBSCRIBER_BANK] = "bank" end
for _, n in ipairs({ "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE", "TEN" }) do
    local bag = _G["BAG_HOUSE_BANK_" .. n]
    if bag then SCANNED[bag] = "house" end
end

local function Hex(hex)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end
local THEME, GOOD, ACCENT, DIM = "C08A4E", "8FD17F", "7FB2E5", "8F8B7A"

local function PlaceName(entry)
    if entry.whereKind == "bank" then return L("SCOPE_BANK") end
    if entry.whereKind == "house" then return L("SCOPE_HOUSE") end
    return entry.owner or ""
end

-- the other copies you own of this piece (same set, slot and trait, as on the
-- Duplicates page); kind/bagKind: where the hovered one is, so it isn't counted
local function OtherCopies(link, setId, bagKind)
    local slotKey = S.SlotKey(link)
    local trait = GetItemLinkTraitInfo(link)
    if not slotKey then return 0, {} end
    local me = GetCurrentCharacterId()
    local skippedSelf = bagKind == nil
    local n, places, seen = 0, {}, {}
    for _, entry in ipairs(S.GetOwned(setId)) do
        if S.SlotKey(entry.link) == slotKey and GetItemLinkTraitInfo(entry.link) == trait then
            local isHere = not skippedSelf and entry.whereKind == bagKind
                and (bagKind == "bank" or bagKind == "house" or entry.ownerId == me)
            if isHere then
                skippedSelf = true
                if (entry.count or 1) > 1 then n = n + entry.count - 1 end
            else
                n = n + (entry.count or 1)
                local place = PlaceName(entry)
                if place ~= "" and not seen[place] then
                    seen[place] = true
                    places[#places + 1] = place
                end
            end
        end
    end
    return n, places
end

local function AddLines(tooltip, link, bagId)
    if not S.sv or S.sv.tooltipLines == false or not link or link == "" then return end
    local hasSet, _, _, _, _, setId = GetItemLinkSetInfo(link, false)
    if not hasSet or not setId or setId == 0 then return end

    local lines = {}
    local function Add(text, hex) lines[#lines + 1] = { text, hex } end

    local slotKey = S.SlotKey(link)
    local trait = GetItemLinkTraitInfo(link)
    if S.IsWantedPiece and slotKey and S.IsWantedPiece(setId, slotKey) then
        Add(L("TTL_WISH_PIECE"), GOOD)
    elseif S.sv.wishlist[setId] then
        Add(L("TTL_WISH"), GOOD)
    end
    if S.IsWantedTrait and S.IsWantedTrait(setId, trait) then Add(L("TTL_HUNT_TRAIT"), GOOD) end

    if GetItemLinkItemSetCollectionSlot and GetNumItemSetCollectionPieces(setId) > 0 then
        local collected = IsItemSetCollectionSlotUnlocked(setId, GetItemLinkItemSetCollectionSlot(link))
        if not collected then Add(L("TTL_NOT_COLLECTED"), ACCENT) end
    end

    local n, places = OtherCopies(link, setId, bagId and SCANNED[bagId])
    if n > 0 then
        local shown = {}
        for i = 1, zo_min(#places, MAX_PLACES) do shown[i] = places[i] end
        local where = table.concat(shown, ", ")
        if #places > MAX_PLACES then where = where .. " " .. L("TTL_MORE", #places - MAX_PLACES) end
        if n == 1 then
            Add(L("TTL_DUPE_ONE", where), THEME)
        else
            Add(L("TTL_DUPES", n, where), THEME)
        end
    end

    if #lines == 0 then return end
    ZO_Tooltip_AddDivider(tooltip)
    tooltip:AddLine(zo_strupper(L("TITLE")), "ZoFontGameSmall", Hex(DIM))
    for _, line in ipairs(lines) do
        tooltip:AddLine(line[1], "ZoFontGameSmall", Hex(line[2]))
    end
end

function S.InitTooltips()
    if not ItemTooltip or not ZO_PostHook then return end
    ZO_PostHook(ItemTooltip, "SetBagItem", function(self, bagId, slotIndex)
        pcall(AddLines, self, GetItemLink(bagId, slotIndex), bagId)
    end)
    ZO_PostHook(ItemTooltip, "SetWornItem", function(self, slotIndex, bagId)
        bagId = bagId or BAG_WORN
        pcall(AddLines, self, GetItemLink(bagId, slotIndex), bagId)
    end)
    if GetLootItemLink then
        ZO_PostHook(ItemTooltip, "SetLootItem", function(self, lootId)
            pcall(AddLines, self, GetLootItemLink(lootId), nil)
        end)
    end
end
