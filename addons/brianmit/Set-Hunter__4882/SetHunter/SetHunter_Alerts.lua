-- SetHunter_Alerts.lua : on-screen alert when a wishlist piece drops.

local S = SetHunter
local L = S.L

-- unlocked slots per wishlist set, kept from before the loot so we can still tell
-- "new" when the collection updates before EVENT_LOOT_RECEIVED fires
local known = {}

local function Snapshot(setId)
    local slots = {}
    for i = 1, GetNumItemSetCollectionPieces(setId) do
        local _, slot = GetItemSetCollectionPieceInfo(setId, i)
        if IsItemSetCollectionSlotUnlocked(setId, slot) then slots[Id64ToString(slot)] = true end
    end
    known[setId] = slots
end

function S.WatchWish(setId)
    if S.sv.wishlist[setId] then Snapshot(setId) else known[setId] = nil end
end

local function Announce(main, sub)
    local sound = S.sv.dropSound and SOUNDS.ACHIEVEMENT_AWARDED or nil
    local ok = pcall(function()
        local msg = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT, sound)
        msg:SetText(main, sub)
        msg:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_DISPLAY_ANNOUNCEMENT)
        CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(msg)
    end)
    if not ok and sound then PlaySound(sound) end   -- chat line still goes out below
end

local function OnLoot(_, _, link, _, _, _, isSelf)
    if not isSelf or not S.sv.dropAlert then return end
    local hasSet, _, _, _, _, setId = GetItemLinkSetInfo(link, false)
    if not hasSet or not setId or not S.sv.wishlist[setId] then return end

    local slots = known[setId]
    if not slots then
        Snapshot(setId)
        slots = known[setId]
    end
    local slot = GetItemLinkItemSetCollectionSlot(link)
    local key = slot and Id64ToString(slot)
    local isNew = key ~= nil and not slots[key]
    if key then slots[key] = true end

    -- wanted pieces / traits picked: a drop has to match all of them; anything else
    -- only matters if it unlocks a new collection slot
    local trait = GetItemLinkTraitInfo(link)
    local hasPieces, hasTraits = S.HasWishPieces(setId), S.HasWishTraits(setId)
    local pieceMatch = hasPieces and S.IsWantedPiece(setId, key)
    local traitMatch = hasTraits and S.IsWantedTrait(setId, trait)
    local picky = hasPieces or hasTraits
    local wanted = picky and (not hasPieces or pieceMatch) and (not hasTraits or traitMatch)
    if picky and not wanted and not isNew then return end
    if S.sv.dropOnlyNew and not isNew and not wanted then return end
    -- only call out the trait when it's actually what made this drop wanted
    if not wanted then traitMatch = false end

    local total, have = GetNumItemSetCollectionPieces(setId), 0
    for _ in pairs(slots) do have = have + 1 end

    local quality = GetItemLinkDisplayQuality and GetItemLinkDisplayQuality(link) or GetItemLinkQuality(link)
    local name = GetItemQualityColor(quality):Colorize(zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(link)))
    local good = S.UIKit.COLOR.good
    local parts = { name }
    if traitMatch then parts[#parts + 1] = S.UIKit.Colorize(good, GetString("SI_ITEMTRAITTYPE", trait)) end
    if isNew then parts[#parts + 1] = S.UIKit.Colorize(good, L("DROP_NEW")) end
    if total > 0 then parts[#parts + 1] = L("DROP_PROGRESS", have, total) end

    local title = "DROP_TITLE"
    if wanted then title = pieceMatch and "DROP_TITLE_PIECE" or "DROP_TITLE_TRAIT" end
    Announce(L(title), table.concat(parts, "  ·  "))
    local chat = { link }
    if wanted then chat[#chat + 1] = L(title) end
    if isNew then chat[#chat + 1] = L("DROP_NEW") end
    if total > 0 then chat[#chat + 1] = L("DROP_PROGRESS", have, total) end
    S.Print(L("DROP_CHAT", table.concat(chat, "  ·  ")))
end

-- /sethunter testdrop: fake a drop from the first wishlist set
function S.TestDrop()
    local setId = next(S.sv.wishlist)
    local info = setId and S.LIS() and S.LIS().GetItemSetInfo(setId)
    if not info then
        S.Print(L("EMPTY_WISHLIST"))
        return
    end
    local was = S.sv.dropAlert
    S.sv.dropAlert = true
    OnLoot(nil, nil, info.sampleItemLink, 1, nil, nil, true)
    S.sv.dropAlert = was
    Snapshot(setId)   -- don't let the fake piece count as collected
end

function S.InitAlerts()
    local name = "SetHunter_Alerts"
    EVENT_MANAGER:RegisterForEvent(name, EVENT_PLAYER_ACTIVATED, function()
        -- only needed once; collection data isn't ready at add-on load
        EVENT_MANAGER:UnregisterForEvent(name, EVENT_PLAYER_ACTIVATED)
        for setId in pairs(S.sv.wishlist) do Snapshot(setId) end
    end)
    EVENT_MANAGER:RegisterForEvent(name, EVENT_LOOT_RECEIVED, OnLoot)
end
