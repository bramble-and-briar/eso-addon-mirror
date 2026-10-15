local TP = TheProfit

-- Deals that group members reported for items the player tracks. Each report is
-- checked with the player's own model, shown once on the HUD and kept in a short list
-- until the player has been to that guild's store or the report is too old.
local MAX_DEALS = 50
local UNVISITED_SECONDS = 30 * 60
local VISITED_SECONDS = 60
local CHECK_MS = 5 * 1000
local AGS_API_VERSION = 4
local EVENT_NAME = TP.name .. "GroupDeals"

-- Newest first. A deal is { key, itemKey, unitPrice, quantity, guildId, place,
-- receivedAt, visitedAt, from }.
local deals = {}
local expiring = false
local Expire

-- The expiry check runs only while there is something to expire.
local function UpdateExpiryTimer()
    local needed = #deals > 0
    if needed == expiring then return end
    expiring = needed
    if needed then
        EVENT_MANAGER:RegisterForUpdate(EVENT_NAME .. "Expire", CHECK_MS, Expire)
    else
        EVENT_MANAGER:UnregisterForUpdate(EVENT_NAME .. "Expire")
    end
end

local function Changed()
    UpdateExpiryTimer()
    TP.callbacks:FireCallbacks("GroupDealsChanged")
end

function TP.GetGroupDeals()
    return deals
end

-- Quality color of an item link as r, g, b.
function TP.GetGroupItemColor(itemLink)
    if itemLink and GetItemLinkDisplayQuality and GetItemQualityColor then
        local color = GetItemQualityColor(GetItemLinkDisplayQuality(itemLink))
        if color then
            local r, g, b = color:UnpackRGBA()
            return r, g, b
        end
    end
    return 1, 1, 1
end

local function FindTrackedItem(itemId, hash)
    for _, itemKey in ipairs(TP.SV.trackedItemOrder or {}) do
        local item = TP.SV.trackedItems[itemKey]
        if item then
            local trackedId, trackedHash = TP.GetGroupItemIdentity(itemKey)
            if trackedId == itemId and trackedHash == hash then return itemKey, item end
        end
    end
    return nil
end

local function AddDeal(itemKey, hit, from)
    local key = string.format("%d:%d:%d:%d:%d", hit.guildId, hit.itemId, hit.hash, hit.price, hit.quantity)
    for index, deal in ipairs(deals) do
        if deal.key == key then table.remove(deals, index) break end
    end

    table.insert(deals, 1, {
        key = key,
        itemKey = itemKey,
        unitPrice = hit.price,
        quantity = hit.quantity,
        guildId = hit.guildId,
        place = hit.place,
        receivedAt = GetTimeStamp(),
        from = from,
    })
    for index = #deals, MAX_DEALS + 1, -1 do deals[index] = nil end
    Changed()
end

local function OnDealReceived(peerName, hit)
    local itemKey, item = FindTrackedItem(hit.itemId, hit.hash)
    if not itemKey then return end

    -- The reporter only compared the price for one piece; the stack is judged here.
    local score = TP.EvaluatePurchase(item.link, hit.price, hit.quantity)
    if score < TP.PURCHASE_SCORE_BUY then return end

    AddDeal(itemKey, hit, peerName)
    if TP.ShowGroupHudMessage then
        local r, g, b = TP.GetGroupItemColor(item.link)
        TP.ShowGroupHudMessage({
            itemKey = itemKey,
            name = item.name,
            r = r, g = g, b = b,
            quantity = hit.quantity,
            unitPrice = hit.price,
            guildId = hit.guildId,
            place = hit.place,
        })
    end
end

local function RemoveDealsWhere(predicate)
    local removed = false
    for index = #deals, 1, -1 do
        if predicate(deals[index]) then
            table.remove(deals, index)
            removed = true
        end
    end
    if removed then Changed() end
end

local function OnTrackedItemRemoved(itemKey)
    RemoveDealsWhere(function(deal) return deal.itemKey == itemKey end)
    if TP.HideGroupHudMessageForItem then TP.HideGroupHudMessageForItem(itemKey) end
end

local function MarkGuildVisited(guildId)
    if not guildId then return end
    local now = GetTimeStamp()
    local changed = false
    for _, deal in ipairs(deals) do
        if deal.guildId == guildId and not deal.visitedAt then
            deal.visitedAt = now
            changed = true
        end
    end
    if changed then Changed() end
end

function Expire()
    local now = GetTimeStamp()
    RemoveDealsWhere(function(deal)
        if deal.visitedAt then return now - deal.visitedAt >= VISITED_SECONDS end
        return now - deal.receivedAt >= UNVISITED_SECONDS
    end)
end

function TP.SetupGroupDeals()
    TP.callbacks:RegisterCallback("GroupDealReceived", OnDealReceived)
    TP.callbacks:RegisterCallback("TrackedItemRemoved", OnTrackedItemRemoved)
    TP.callbacks:RegisterCallback("GroupSharingChanged", function(enabled)
        if not enabled then RemoveDealsWhere(function() return true end) end
    end)

    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_OPEN_TRADING_HOUSE, function()
        MarkGuildVisited((GetCurrentTradingHouseGuildDetails()))
    end)

    -- Inside AwesomeGuildStore the player can switch guilds without reopening the store.
    local AGS = AwesomeGuildStore
    if AGS and type(AGS.RegisterCallback) == "function" and type(AGS.GetAPIVersion) == "function"
        and AGS.GetAPIVersion() == AGS_API_VERSION and AGS.callback and AGS.callback.GUILD_SELECTION_CHANGED then
        AGS:RegisterCallback(AGS.callback.GUILD_SELECTION_CHANGED, function(guildData)
            MarkGuildVisited(guildData and guildData.guildId)
        end)
    end

    if TP.SetupGroupDealsWindow then TP.SetupGroupDealsWindow() end
end
