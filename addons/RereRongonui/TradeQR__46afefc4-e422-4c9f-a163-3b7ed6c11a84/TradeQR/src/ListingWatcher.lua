-- Queues a listing record every time the account posts an item on a guild store, so the phone app
-- can create the pending sale right away (the later sold event is matched to it by the API).
--
-- Both the keyboard and the gamepad UI post through the global RequestPostItemOnTradingHouse(bag, slot,
-- quantity, price): a pre-hook captures the item while it is still in the bag, and the listing is queued
-- only when EVENT_TRADING_HOUSE_RESPONSE_RECEIVED confirms the post (POST_PENDING + SUCCESS).
-- The UI never sends a second post while one is awaiting its response, so one pending slot is enough.
local ListingWatcher = ZO_InitializingObject:Subclass()

local EVENT_NAMESPACE = "TradeQR_ListingWatcher"

function ListingWatcher:Initialize(savedVars, saleQueue)
    self.savedVars = savedVars
    self.saleQueue = saleQueue
    self.pendingPost = nil
    -- Runtime-only counters shown by "/tradeqr diag".
    self.stats = { requested = 0, confirmed = 0, failed = 0 }
end

function ListingWatcher:Start()
    ZO_PreHook("RequestPostItemOnTradingHouse", function(bagId, slotIndex, quantity, price)
        -- An error raised inside a pre-hook would skip the original call and break posting: never let it escape.
        local isCaptured = pcall(self.OnPostRequested, self, bagId, slotIndex, quantity, price)
        if not isCaptured then
            self.pendingPost = nil
            self.stats.failed = self.stats.failed + 1
        end
        -- Returning nothing: a pre-hook returning true would block the post.
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_TRADING_HOUSE_RESPONSE_RECEIVED, function(_, responseType, result)
        self:OnResponseReceived(responseType, result)
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_TRADING_HOUSE_RESPONSE_TIMEOUT, function(_, responseType)
        self:OnResponseTimeout(responseType)
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_CLOSE_TRADING_HOUSE, function()
        self.pendingPost = nil
    end)
end

function ListingWatcher:GetStats()
    return self.stats
end

function ListingWatcher:OnPostRequested(bagId, slotIndex, quantity, price)
    self.pendingPost = nil
    local itemLink = GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
    if not itemLink or itemLink == "" then
        return
    end
    local guildId, guildName = GetCurrentTradingHouseGuildDetails()
    local listingFee = GetTradingHousePostPriceInfo(price)

    self.stats.requested = self.stats.requested + 1
    self.pendingPost = {
        guildId = guildId,
        guildName = guildName,
        itemLink = itemLink,
        itemName = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(itemLink)),
        quantity = quantity,
        price = price,
        fee = listingFee,
    }
end

function ListingWatcher:OnResponseReceived(responseType, result)
    if responseType ~= TRADING_HOUSE_RESULT_POST_PENDING or not self.pendingPost then
        return
    end
    local post = self.pendingPost
    self.pendingPost = nil

    if result ~= TRADING_HOUSE_RESULT_SUCCESS then
        self.stats.failed = self.stats.failed + 1
        return
    end
    self.stats.confirmed = self.stats.confirmed + 1
    self.saleQueue:Add(self:BuildListing(post, GetTimeStamp()))
end

-- A timed-out post is dropped: queuing it could create a listing that never existed.
function ListingWatcher:OnResponseTimeout(responseType)
    if responseType == TRADING_HOUSE_RESULT_POST_PENDING and self.pendingPost then
        self.pendingPost = nil
        self.stats.failed = self.stats.failed + 1
    end
end

-- Listing ids are "<timestamp>-<sequence>": unique per account even if the SavedVariables are reset
-- (the timestamp alone could repeat when two items are posted in the same second).
function ListingWatcher:NextListingId(timestampS)
    self.savedVars.listingSequence = (self.savedVars.listingSequence or 0) + 1
    return string.format("%.0f-%d", timestampS, self.savedVars.listingSequence)
end

function ListingWatcher:BuildListing(post, timestampS)
    return {
        kind = TradeQR.RECORD_KIND_LISTING,
        -- Queue key shared with sales (SaleQueue deduplicates and the screen renders by eventId).
        eventId = self:NextListingId(timestampS),
        timestamp = timestampS,
        guildId = post.guildId,
        guildName = post.guildName,
        itemLink = post.itemLink,
        itemName = post.itemName,
        quantity = post.quantity,
        price = post.price,
        fee = post.fee,
        seller = GetDisplayName(),
    }
end

TradeQR.ListingWatcher = ListingWatcher
