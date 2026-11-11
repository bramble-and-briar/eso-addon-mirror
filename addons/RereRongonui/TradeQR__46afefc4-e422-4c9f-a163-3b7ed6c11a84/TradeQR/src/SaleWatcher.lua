-- Watches the guild store ("trader") history of every guild and pushes new sales into the queue.
--
-- Guild history is not pushed to add-ons on demand: data must be requested from the server
-- (CreateGuildHistoryRequest + RequestMoreGuildHistoryEvents, subject to a server cooldown, and
-- add-on requests have low priority), and EVENT_GUILD_HISTORY_CATEGORY_UPDATED fires when new data
-- reached the local cache. Events can therefore reach the cache late and out of order.
--
-- Every scan re-reads the whole recent window (scanWindowSeconds) of the local cache and relies on
-- the seen event ids for de-duplication, so a sale that arrives late is still picked up.
local SaleWatcher = ZO_InitializingObject:Subclass()

local EVENT_NAMESPACE = "TradeQR_SaleWatcher"
local POLL_UPDATE_NAME = "TradeQR_SaleWatcher_Poll"
local QUEUE_IF_ON_COOLDOWN = true

function SaleWatcher:Initialize(savedVars, saleQueue)
    self.savedVars = savedVars
    self.saleQueue = saleQueue
    self.requestIdByGuildId = {}
    -- Runtime-only counters shown by "/tradeqr diag".
    self.statsByGuildId = {}
end

function SaleWatcher:Start()
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_GUILD_HISTORY_CATEGORY_UPDATED, function(_, guildId, eventCategory, flags)
        self:OnCategoryUpdated(guildId, eventCategory, flags)
    end)
    EVENT_MANAGER:RegisterForUpdate(POLL_UPDATE_NAME, TradeQR.pollIntervalMs, function()
        self:PollAllGuilds()
    end)
    self:PollAllGuilds()
end

function SaleWatcher:GetStats(guildId)
    local stats = self.statsByGuildId[guildId]
    if not stats then
        stats = { updatesReceived = 0 }
        self.statsByGuildId[guildId] = stats
    end
    return stats
end

function SaleWatcher:GetRequestId(guildId)
    return self.requestIdByGuildId[guildId]
end

function SaleWatcher:GetScanWindow(nowS)
    return nowS, nowS - self.savedVars.scanWindowSeconds
end

function SaleWatcher:PollAllGuilds()
    for guildIndex = 1, GetNumGuilds() do
        self:PollGuild(GetGuildId(guildIndex))
    end
end

-- A request covers a fixed time window, so a fresh one is needed to include newer sales.
-- But add-on requests wait in a low-priority queue behind the server cooldown: destroying a queued
-- request at every poll would send it back to the end of the queue and it might never be served.
-- So an unfinished request is kept until it completes or gets too old.
function SaleWatcher:PollGuild(guildId)
    local nowS = GetTimeStamp()
    local stats = self:GetStats(guildId)
    stats.lastPollS = nowS

    if self:ShouldKeepRequest(guildId, nowS) then
        self:ScanGuild(guildId)
        return
    end
    self:DestroyRequest(guildId)

    local newestS, oldestS = self:GetScanWindow(nowS)
    local requestId = CreateGuildHistoryRequest(guildId, GUILD_HISTORY_EVENT_CATEGORY_TRADER, newestS, oldestS)
    stats.lastRequestId = requestId
    stats.requestCreatedS = nowS
    if requestId == 0 then
        stats.lastReadyState = nil
        -- Still scan what is already cached (e.g. events pushed by the server).
        self:ScanGuild(guildId)
        return
    end
    self.requestIdByGuildId[guildId] = requestId

    stats.lastReadyState = RequestMoreGuildHistoryEvents(requestId, QUEUE_IF_ON_COOLDOWN)
    -- Scan right away in any case: the cache may already hold the events.
    self:ScanGuild(guildId)
end

function SaleWatcher:ShouldKeepRequest(guildId, nowS)
    local requestId = self.requestIdByGuildId[guildId]
    if not requestId or IsGuildHistoryRequestComplete(requestId) then
        return false
    end
    local createdS = self:GetStats(guildId).requestCreatedS or nowS
    return nowS - createdS < TradeQR.maxRequestAgeSeconds
end

function SaleWatcher:DestroyRequest(guildId)
    local requestId = self.requestIdByGuildId[guildId]
    if requestId then
        DestroyGuildHistoryRequest(requestId)
        self.requestIdByGuildId[guildId] = nil
    end
end

function SaleWatcher:OnCategoryUpdated(guildId, eventCategory, flags)
    if eventCategory ~= GUILD_HISTORY_EVENT_CATEGORY_TRADER then
        return
    end
    local stats = self:GetStats(guildId)
    stats.updatesReceived = stats.updatesReceived + 1
    stats.lastUpdateFlags = flags
    self:ScanGuild(guildId)
    self:ContinueRequestIfIncomplete(guildId)
end

-- Large windows may need several round-trips before the request is complete.
function SaleWatcher:ContinueRequestIfIncomplete(guildId)
    local requestId = self.requestIdByGuildId[guildId]
    if requestId and not IsGuildHistoryRequestComplete(requestId) then
        self:GetStats(guildId).lastReadyState = RequestMoreGuildHistoryEvents(requestId, QUEUE_IF_ON_COOLDOWN)
    end
end

function SaleWatcher:ScanGuild(guildId)
    local nowS = GetTimeStamp()
    local stats = self:GetStats(guildId)
    stats.lastScanS = nowS
    stats.lastScanEvents = 0
    stats.lastScanSold = 0
    stats.lastScanMine = 0
    stats.lastScanAdded = 0

    local newestS, oldestS = self:GetScanWindow(nowS)
    local newestIndex, oldestIndex = GetGuildHistoryEventIndicesForTimeRange(guildId, GUILD_HISTORY_EVENT_CATEGORY_TRADER, newestS, oldestS)
    if not newestIndex then
        return
    end
    -- Index 1 is the newest event, so newestIndex <= oldestIndex.
    for eventIndex = newestIndex, oldestIndex do
        self:ProcessEvent(guildId, eventIndex, stats)
    end
end

function SaleWatcher:ProcessEvent(guildId, eventIndex, stats)
    local eventId, timestampS, isRedacted, eventType, sellerDisplayName, buyerDisplayName, itemLink, quantity, price, tax = GetGuildHistoryTraderEventInfo(guildId, eventIndex)
    stats.lastScanEvents = stats.lastScanEvents + 1
    if isRedacted or eventType ~= GUILD_HISTORY_TRADER_EVENT_ITEM_SOLD then
        return
    end
    stats.lastScanSold = stats.lastScanSold + 1
    if not stats.newestSeller or timestampS > stats.newestSellerS then
        stats.newestSeller = sellerDisplayName
        stats.newestSellerS = timestampS
    end
    if self.savedVars.onlyMySales and not self:IsCurrentAccount(sellerDisplayName) then
        return
    end
    stats.lastScanMine = stats.lastScanMine + 1

    local isAdded = self.saleQueue:Add({
        eventId = string.format("%.0f", eventId),
        timestamp = timestampS,
        guildId = guildId,
        guildName = GetGuildName(guildId),
        itemLink = itemLink,
        itemName = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(itemLink)),
        quantity = quantity,
        price = price,
        tax = tax,
        buyer = buyerDisplayName,
        seller = sellerDisplayName,
    })
    if isAdded then
        stats.lastScanAdded = stats.lastScanAdded + 1
    end
end

-- On console the trader history reports seller names without the leading "@" that
-- GetDisplayName() has, so both sides are normalized before comparing.
function SaleWatcher:NormalizeDisplayName(displayName)
    return zo_strlower((string.gsub(displayName or "", "^@", "")))
end

function SaleWatcher:IsCurrentAccount(displayName)
    return self:NormalizeDisplayName(displayName) == self:NormalizeDisplayName(GetDisplayName())
end

TradeQR.SaleWatcher = SaleWatcher
