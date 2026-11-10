-- Watches the guild store ("trader") history of every guild and pushes new sales into the queue.
--
-- Guild history is not pushed to add-ons: data must be requested from the server
-- (CreateGuildHistoryRequest + RequestMoreGuildHistoryEvents, subject to a server cooldown),
-- and EVENT_GUILD_HISTORY_CATEGORY_UPDATED fires when new data reached the local cache.
local SaleWatcher = ZO_InitializingObject:Subclass()

local EVENT_NAMESPACE = "TradeQR_SaleWatcher"
local POLL_UPDATE_NAME = "TradeQR_SaleWatcher_Poll"
local QUEUE_IF_ON_COOLDOWN = true

function SaleWatcher:Initialize(savedVars, saleQueue)
    self.savedVars = savedVars
    self.saleQueue = saleQueue
    self.requestIdByGuildId = {}
end

function SaleWatcher:Start()
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_GUILD_HISTORY_CATEGORY_UPDATED, function(_, guildId, eventCategory)
        self:OnCategoryUpdated(guildId, eventCategory)
    end)
    EVENT_MANAGER:RegisterForUpdate(POLL_UPDATE_NAME, TradeQR.pollIntervalMs, function()
        self:PollAllGuilds()
    end)
    self:PollAllGuilds()
end

function SaleWatcher:PollAllGuilds()
    for guildIndex = 1, GetNumGuilds() do
        self:PollGuild(GetGuildId(guildIndex))
    end
end

function SaleWatcher:GetScanStartTimestamp(guildId, nowS)
    local lastScanS = self.savedVars.lastScanTimestampByGuildId[guildId]
    if lastScanS then
        return lastScanS - self.savedVars.rescanOverlapSeconds
    end
    return nowS - self.savedVars.initialLookbackSeconds
end

-- A request covers a fixed time window, so a fresh one is created at every poll
-- to include sales that happened after the previous request was made.
function SaleWatcher:PollGuild(guildId)
    local nowS = GetTimeStamp()
    self:DestroyRequest(guildId)

    local requestId = CreateGuildHistoryRequest(guildId, GUILD_HISTORY_EVENT_CATEGORY_TRADER, nowS, self:GetScanStartTimestamp(guildId, nowS))
    if requestId == 0 then
        return
    end
    self.requestIdByGuildId[guildId] = requestId

    local readyState = RequestMoreGuildHistoryEvents(requestId, QUEUE_IF_ON_COOLDOWN)
    if readyState == GUILD_HISTORY_DATA_READY_STATE_READY then
        self:ScanGuild(guildId)
    end
end

function SaleWatcher:DestroyRequest(guildId)
    local requestId = self.requestIdByGuildId[guildId]
    if requestId then
        DestroyGuildHistoryRequest(requestId)
        self.requestIdByGuildId[guildId] = nil
    end
end

function SaleWatcher:OnCategoryUpdated(guildId, eventCategory)
    if eventCategory ~= GUILD_HISTORY_EVENT_CATEGORY_TRADER then
        return
    end
    self:ScanGuild(guildId)
    self:ContinueRequestIfIncomplete(guildId)
end

-- Large windows may need several round-trips before the request is complete.
function SaleWatcher:ContinueRequestIfIncomplete(guildId)
    local requestId = self.requestIdByGuildId[guildId]
    if requestId and not IsGuildHistoryRequestComplete(requestId) then
        RequestMoreGuildHistoryEvents(requestId, QUEUE_IF_ON_COOLDOWN)
    end
end

function SaleWatcher:ScanGuild(guildId)
    local nowS = GetTimeStamp()
    local newestIndex, oldestIndex = GetGuildHistoryEventIndicesForTimeRange(guildId, GUILD_HISTORY_EVENT_CATEGORY_TRADER, nowS, self:GetScanStartTimestamp(guildId, nowS))
    if newestIndex then
        -- Index 1 is the newest event, so newestIndex <= oldestIndex.
        for eventIndex = newestIndex, oldestIndex do
            self:ProcessEvent(guildId, eventIndex)
        end
    end
    self:UpdateLastScanTimestamp(guildId, nowS)
end

-- Only move the scan window forward once the cache has up-to-date events,
-- otherwise sales still on their way from the server could be skipped.
function SaleWatcher:UpdateLastScanTimestamp(guildId, nowS)
    if DoesGuildHistoryEventCategoryHaveUpToDateEvents(guildId, GUILD_HISTORY_EVENT_CATEGORY_TRADER) then
        self.savedVars.lastScanTimestampByGuildId[guildId] = nowS
    end
end

function SaleWatcher:ProcessEvent(guildId, eventIndex)
    local eventId, timestampS, isRedacted, eventType, sellerDisplayName, buyerDisplayName, itemLink, quantity, price, tax = GetGuildHistoryTraderEventInfo(guildId, eventIndex)
    if isRedacted or eventType ~= GUILD_HISTORY_TRADER_EVENT_ITEM_SOLD then
        return
    end
    if self.savedVars.onlyMySales and not self:IsCurrentAccount(sellerDisplayName) then
        return
    end

    self.saleQueue:Add({
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
end

function SaleWatcher:IsCurrentAccount(displayName)
    return zo_strlower(displayName) == zo_strlower(GetDisplayName())
end

TradeQR.SaleWatcher = SaleWatcher
