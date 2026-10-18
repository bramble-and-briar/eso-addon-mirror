local TP = TheProfit

-- The Buy List holds items the player wants to buy at a price and in a quantity they
-- set themselves; the market model is not involved, and the list does not affect
-- Portfolio, Ledger or Stock. An item can be in the portfolio as well. While the list
-- still has some of it left to buy, the list's price is the one that counts.
-- Events: BuyListChanged(itemKey) after an item is added, removed or edited, and after
-- a purchase of a listed item is recorded or resolved.
local MAX_BUY_LIST_ITEMS = 20
local MAX_VALUE = 999999999

TP.MAX_BUY_LIST_ITEMS = MAX_BUY_LIST_ITEMS

local function GetEntry(itemKey)
    return itemKey and TP.SV and TP.SV.buyList and TP.SV.buyList[itemKey] or nil
end

local function Changed(itemKey)
    if ADDON_MANAGER and ADDON_MANAGER.RequestAddOnSavedVariablesPrioritySave then
        ADDON_MANAGER:RequestAddOnSavedVariablesPrioritySave(TP.name)
    end
    TP.callbacks:FireCallbacks("BuyListChanged", itemKey)
    TP.RefreshUI()
end

local function ClampValue(value)
    return zo_clamp(math.floor(tonumber(value) or 0), 0, MAX_VALUE)
end

function TP.GetBuyListEntry(itemKey)
    return GetEntry(itemKey)
end

function TP.GetBuyListKeys()
    return TP.SV and TP.SV.buyListOrder or {}
end

-- Like trackedSince in the portfolio, only purchases made after the item was added
-- count, so an item removed and added again starts from zero.
function TP.GetBuyListBought(itemKey)
    local entry = GetEntry(itemKey)
    if not entry then return 0 end
    local addedAt = tonumber(entry.addedAt) or 0
    local bought = 0
    for _, purchase in pairs(TP.runtime and TP.runtime.purchasesByItem[itemKey] or {}) do
        if purchase.status ~= "failed" and (tonumber(purchase.timestamp) or 0) >= addedAt then
            bought = bought + math.max(0, tonumber(purchase.quantity) or 0)
        end
    end
    return bought
end

function TP.GetBuyListRemaining(itemKey)
    local entry = GetEntry(itemKey)
    if not entry then return 0 end
    return math.max(0, (tonumber(entry.quantity) or 0) - TP.GetBuyListBought(itemKey))
end

-- A listed item is searched for only while some of it is left to buy.
local function IsActive(itemKey)
    return GetEntry(itemKey) ~= nil and TP.GetBuyListRemaining(itemKey) > 0
end
TP.IsBuyListActive = IsActive

-- A price of 0 means the player set none: the TTC suggested price is used, and
-- without it the Portfolio buy price. Nil when neither exists.
function TP.GetBuyListUnitPrice(itemKey)
    local entry = GetEntry(itemKey)
    if not entry then return nil end
    local price = tonumber(entry.maxPrice) or 0
    if price > 0 then return price end

    local info = TP.SimpleMargin and TP.SimpleMargin.GetPriceInfo and TP.SimpleMargin.GetPriceInfo(entry.link)
    local suggested = info and tonumber(info.SuggestedPrice)
    if suggested and suggested > 0 then return suggested end
    return TP.GetMaxPurchasePrice(itemKey)
end

-- Nil when the Buy List does not need the item, so the caller falls back to the
-- portfolio model. Otherwise true when the unit price is within the list's price and
-- the stack is no larger than what is left to buy, followed by a short reason.
function TP.EvaluateBuyListPurchase(itemKey, unitPrice, quantity)
    local remaining = TP.GetBuyListRemaining(itemKey)
    if remaining <= 0 then return nil end

    local price = TP.GetBuyListUnitPrice(itemKey)
    if not price then return false, "no Buy List price" end
    if quantity > remaining then
        return false, string.format("stack %d > %d left on Buy List", quantity, remaining)
    end
    if unitPrice > price then return false, "above Buy List price" end
    return true, "Buy List"
end

-- Items the group is told about: Buy List items still needed first, then the
-- portfolio. An item in both is sent once.
function TP.GetGroupWantKeys()
    local keys, seen = {}, {}
    for _, itemKey in ipairs(TP.GetBuyListKeys()) do
        if IsActive(itemKey) then
            keys[#keys + 1] = itemKey
            seen[itemKey] = true
        end
    end
    for _, itemKey in ipairs(TP.SV and TP.SV.trackedItemOrder or {}) do
        if TP.SV.trackedItems[itemKey] and not seen[itemKey] then keys[#keys + 1] = itemKey end
    end
    return keys
end

function TP.IsGroupWanted(itemKey)
    if IsActive(itemKey) then return true end
    return itemKey ~= nil and TP.SV ~= nil and TP.SV.trackedItems ~= nil and TP.SV.trackedItems[itemKey] ~= nil
end

-- The highest unit price the player pays for a wanted item, or nil without one.
function TP.GetGroupWantPrice(itemKey)
    if IsActive(itemKey) then return TP.GetBuyListUnitPrice(itemKey) end
    return TP.GetMaxPurchasePrice(itemKey)
end

-- Display data ({ key, link, name, icon }) of a portfolio or Buy List item.
function TP.GetWantedItem(itemKey)
    return TP.SV and TP.SV.trackedItems and TP.SV.trackedItems[itemKey] or GetEntry(itemKey)
end

function TP.AddToBuyList(itemLink)
    local itemKey = TP.GetItemKey(itemLink)
    if not itemKey then return false end
    if GetEntry(itemKey) then return true end
    if #TP.SV.buyListOrder >= MAX_BUY_LIST_ITEMS then
        d("|cE7C56AThe Profit:|r " .. TP.T("buyListFull"))
        return false
    end

    TP.SV.buyList[itemKey] = {
        key = itemKey,
        link = itemLink,
        name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(itemLink)),
        icon = GetItemLinkIcon(itemLink),
        maxPrice = 0,
        quantity = 0,
        addedAt = GetTimeStamp(),
    }
    TP.SV.buyListOrder[#TP.SV.buyListOrder + 1] = itemKey
    Changed(itemKey)
    return true
end

function TP.RemoveFromBuyList(itemKey)
    if not GetEntry(itemKey) then return end
    TP.SV.buyList[itemKey] = nil
    for index, key in ipairs(TP.SV.buyListOrder) do
        if key == itemKey then
            table.remove(TP.SV.buyListOrder, index)
            break
        end
    end
    Changed(itemKey)
end

-- field is "maxPrice" or "quantity".
function TP.SetBuyListValue(itemKey, field, value)
    local entry = GetEntry(itemKey)
    if not entry or (field ~= "maxPrice" and field ~= "quantity") then return end
    value = ClampValue(value)
    if entry[field] == value then return end
    entry[field] = value
    Changed(itemKey)
end

-- Called by the purchase recorder, so the remaining quantity and the group are updated.
function TP.OnBuyListPurchaseChanged(itemKey)
    if GetEntry(itemKey) then TP.callbacks:FireCallbacks("BuyListChanged", itemKey) end
end

-- Keys are rebuilt with the current item key, duplicates and entries past the limit
-- are dropped, and numbers are made whole and non-negative.
function TP.SanitizeBuyList()
    local saved = type(TP.SV.buyList) == "table" and TP.SV.buyList or {}
    local list, order = {}, {}
    for _, oldKey in ipairs(type(TP.SV.buyListOrder) == "table" and TP.SV.buyListOrder or {}) do
        local entry = saved[oldKey]
        local itemKey = type(entry) == "table" and TP.GetItemKey(entry.link) or nil
        if itemKey and not list[itemKey] and #order < MAX_BUY_LIST_ITEMS then
            entry.key = itemKey
            entry.maxPrice = ClampValue(entry.maxPrice)
            entry.quantity = ClampValue(entry.quantity)
            entry.addedAt = tonumber(entry.addedAt) or GetTimeStamp()
            list[itemKey] = entry
            order[#order + 1] = itemKey
        end
    end
    TP.SV.buyList = list
    TP.SV.buyListOrder = order
end
