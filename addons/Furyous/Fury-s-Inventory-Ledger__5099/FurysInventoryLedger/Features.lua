-- Fury's Inventory Ledger - find, split stacks, sets and the tooltip line
-- Everything here reads the saved containers through FIL.Items and never changes them.

local FIL = FurysInventoryLedger

local WALLETS = { ["Wallet"] = true, ["Bank Wallet"] = true, ["Account Wallet"] = true }

-- Short name for the place a container is: "Bank", "Vexating", "Vexating (worn)", a coffer or house name.
local function PlaceLabel(cont)
    if cont.owner == FIL.ACCOUNT_OWNER then
        if cont.location == "Placed in House" then return cont.container .. " (placed)" end
        return cont.container
    end
    if cont.container == "Backpack" or cont.container == "Wallet" then return cont.owner end
    if cont.container == "Equipped" then return cont.owner .. " (worn)" end
    return cont.owner .. ": " .. cont.container
end
FIL.PlaceLabel = PlaceLabel

-- Calls fn(cont, accountKey) for every saved container; this account only unless allAccounts.
local function EachContainer(fn, allAccounts)
    for acctKey, a in pairs(FIL.GetAllAccounts()) do
        if allAccounts or acctKey == FIL.accountKey then
            for _, ch in pairs(a.chars) do
                for _, cont in pairs(ch.containers) do fn(cont, acctKey) end
            end
            for _, cont in pairs(a.shared) do fn(cont, acctKey) end
        end
    end
end
FIL.EachContainer = EachContainer

-- "@Name: " in front of places that belong to another account on this PC.
local function AccountPrefix(acctKey)
    if acctKey == FIL.accountKey then return "" end
    return (acctKey:match("^(%S+)") or acctKey) .. ": "
end

-- Adds qty at a place to an entry that keeps its places in first-seen order.
local function AddPlace(entry, label, qty)
    entry.qty = entry.qty + qty
    local p = entry.byLabel[label]
    if not p then
        p = { label = label, qty = 0 }
        entry.byLabel[label] = p
        entry.places[#entry.places + 1] = p
    end
    p.qty = p.qty + qty
end

local function NewEntry(name, kind)
    return { name = name, kind = kind or "", qty = 0, places = {}, byLabel = {} }
end

-- "Bank 200, Craft Bag 212", biggest first, cut after maxPlaces.
local function PlacesText(entry, maxPlaces)
    table.sort(entry.places, function(a, b)
        if a.qty ~= b.qty then return a.qty > b.qty end
        return a.label < b.label
    end)
    local parts = {}
    for i, p in ipairs(entry.places) do
        if maxPlaces and i > maxPlaces then
            parts[#parts + 1] = zo_strformat("+<<1>> more", #entry.places - maxPlaces)
            break
        end
        parts[#parts + 1] = p.label .. " " .. ZO_CommaDelimitNumber(p.qty)
    end
    return table.concat(parts, ", ")
end
FIL.PlacesText = PlacesText

local function ByQtyThenName(a, b)
    if a.qty ~= b.qty then return a.qty > b.qty end
    return a.name < b.name
end

------------------------------------------------------------------------------
-- Find: every item or currency whose name, or set name, holds the words. All accounts.
------------------------------------------------------------------------------
function FIL.Find(text)
    local needle = zo_strlower(zo_strtrim(text or ""))
    local found, list = {}, {}
    if needle == "" then return list end
    EachContainer(function(cont, acctKey)
        local label
        for _, it in ipairs(FIL.Items(cont)) do
            local name, kind
            if it.l then
                local info = FIL.LinkInfo(it.l)
                name = info.name
                kind = (info.set and info.set ~= "") and info.set or info.itype
            else
                name, kind = it.n, it.cur and "Currency" or "Furniture"
            end
            name, kind = name or "", kind or ""
            if zo_strlower(name):find(needle, 1, true) or zo_strlower(kind):find(needle, 1, true) then
                local key = name .. "\1" .. kind
                local entry = found[key]
                if not entry then
                    entry = NewEntry(name, kind)
                    found[key] = entry
                    list[#list + 1] = entry
                end
                label = label or (AccountPrefix(acctKey) .. PlaceLabel(cont))
                AddPlace(entry, label, it.q)
            end
        end
    end, true)
    table.sort(list, ByQtyThenName)
    return list
end

local CHAT_ROWS = 12

function FIL.FindToChat(text)
    text = zo_strtrim(text or "")
    if text == "" then
        FIL.Msg("Usage: /ledger find <part of an item or set name>")
        return
    end
    local list = FIL.Find(text)
    if #list == 0 then
        FIL.Msg("Nothing you own matches <<1>>. Places not read yet are listed under Still to read on the summary.", text)
        return
    end
    local total = 0
    for _, entry in ipairs(list) do total = total + entry.qty end
    FIL.Msg("<<1>> matches, <<2>> items for <<3>>:", #list, ZO_CommaDelimitNumber(total), text)
    for i, entry in ipairs(list) do
        if i > CHAT_ROWS then
            FIL.Msg("  and <<1>> more. The Find box on the summary (/ledger) shows them all.", #list - CHAT_ROWS)
            break
        end
        FIL.Msg("  <<1>> x<<2>>: <<3>>", entry.name, ZO_CommaDelimitNumber(entry.qty), PlacesText(entry, 5))
    end
end

------------------------------------------------------------------------------
-- Split stacks: the same stackable item sitting in two or more places on this account.
------------------------------------------------------------------------------
function FIL.SplitStacks()
    local found, list = {}, {}
    EachContainer(function(cont)
        if cont.container == "Equipped" or cont.location == "Companion" or cont.location == "Placed in House"
            or WALLETS[cont.container] then return end
        local label = PlaceLabel(cont)
        for _, it in ipairs(FIL.Items(cont)) do
            if it.l and IsItemLinkStackable(it.l) then
                local key = it.l .. (it.b and "#b" or "") .. (it.s and "#s" or "")
                local entry = found[key]
                if not entry then
                    entry = NewEntry(FIL.LinkInfo(it.l).name or "", "")
                    found[key] = entry
                end
                AddPlace(entry, label, it.q)
            end
        end
    end, false)
    for _, entry in pairs(found) do
        if #entry.places > 1 then list[#list + 1] = entry end
    end
    table.sort(list, function(a, b)
        if #a.places ~= #b.places then return #a.places > #b.places end
        return ByQtyThenName(a, b)
    end)
    return list
end

------------------------------------------------------------------------------
-- Sets: how many pieces of each set this account owns, and who holds them.
------------------------------------------------------------------------------
function FIL.Sets()
    local found, list = {}, {}
    EachContainer(function(cont)
        local label = PlaceLabel(cont)
        for _, it in ipairs(FIL.Items(cont)) do
            local info = it.l and FIL.LinkInfo(it.l)
            if info and info.set and info.set ~= "" then
                local entry = found[info.set]
                if not entry then
                    entry = NewEntry(info.set, "")
                    found[info.set] = entry
                    list[#list + 1] = entry
                end
                AddPlace(entry, label, it.q)
            end
        end
    end, false)
    table.sort(list, ByQtyThenName)
    return list
end

------------------------------------------------------------------------------
-- Tooltip line (a setting, starts turned off): "You own 412: Bank 200, Craft Bag 212".
-- The index is keyed by item ID, built on first use and again only after something was read.
------------------------------------------------------------------------------
local owned, ownedRev

local function ItemIdOf(link)
    return link and link:match("^|H%d:item:(%d+)")
end

local function OwnedIndex()
    if owned and ownedRev == FIL.dataRev then return owned end
    owned, ownedRev = {}, FIL.dataRev
    EachContainer(function(cont, acctKey)
        local label
        for _, it in ipairs(FIL.Items(cont)) do
            local id = ItemIdOf(it.l)
            if id then
                local entry = owned[id]
                if not entry then
                    entry = NewEntry("", "")
                    owned[id] = entry
                end
                label = label or (AccountPrefix(acctKey) .. PlaceLabel(cont))
                AddPlace(entry, label, it.q)
            end
        end
    end, true)
    return owned
end

local function AddOwnedLine(tooltip, link)
    if not FIL.TooltipWanted() then return end
    local id = ItemIdOf(link)
    local entry = id and OwnedIndex()[id]
    if not entry then return end
    local r, g, b = FIL.Theme.VIOLET:UnpackRGB()
    tooltip:AddLine(zo_strformat("You own <<1>>: <<2>>", ZO_CommaDelimitNumber(entry.qty), PlacesText(entry, 6)),
        "ZoFontGameSmall", r, g, b)
end

function FIL.HookTooltips()
    ZO_PostHook(ItemTooltip, "SetBagItem", function(tooltip, bagId, slot) AddOwnedLine(tooltip, GetItemLink(bagId, slot)) end)
    ZO_PostHook(ItemTooltip, "SetWornItem", function(tooltip, slot, bagId) AddOwnedLine(tooltip, GetItemLink(bagId or BAG_WORN, slot)) end)
    ZO_PostHook(ItemTooltip, "SetLootItem", function(tooltip, lootId) AddOwnedLine(tooltip, GetLootItemLink(lootId)) end)
    ZO_PostHook(ItemTooltip, "SetStoreItem", function(tooltip, index) AddOwnedLine(tooltip, GetStoreItemLink(index)) end)
    ZO_PostHook(ItemTooltip, "SetTradingHouseItem", function(tooltip, index) AddOwnedLine(tooltip, GetTradingHouseSearchResultItemLink(index)) end)
    ZO_PostHook(ItemTooltip, "SetLink", function(tooltip, link) AddOwnedLine(tooltip, link) end)
    ZO_PostHook(PopupTooltip, "SetLink", function(tooltip, link) AddOwnedLine(tooltip, link) end)
end
