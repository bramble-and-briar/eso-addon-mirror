-- "/tradeqr diag": prints the watcher state to chat, so problems can be investigated on console
-- (no PC, no access to SavedVariables or Lua errors there).
local Diagnostics = ZO_InitializingObject:Subclass()

function Diagnostics:Initialize(saleWatcher, listingWatcher, saleQueue, savedVars)
    self.saleWatcher = saleWatcher
    self.listingWatcher = listingWatcher
    self.saleQueue = saleQueue
    self.savedVars = savedVars
end

function Diagnostics:Print()
    local nowS = GetTimeStamp()
    d(string.format(GetString(TRADEQR_DIAG_HEADER), GetDisplayName(), GetNumGuilds(), self.saleQueue:GetCount(), self:CountSeen(), self.savedVars.scanWindowSeconds / 3600))
    local listingStats = self.listingWatcher:GetStats()
    d(string.format(GetString(TRADEQR_DIAG_LISTINGS), listingStats.requested, listingStats.confirmed, listingStats.failed))
    local lastListing = self.listingWatcher:GetLastListing()
    if lastListing then
        local uniqueId = lastListing.itemUniqueId ~= "" and lastListing.itemUniqueId or "-"
        d(string.format(GetString(TRADEQR_DIAG_LAST_LISTING), lastListing.itemLink, uniqueId))
    end
    for guildIndex = 1, GetNumGuilds() do
        self:PrintGuild(GetGuildId(guildIndex), nowS)
    end
end

function Diagnostics:CountSeen()
    local count = 0
    for _ in pairs(self.savedVars.seenEventIds) do
        count = count + 1
    end
    return count
end

function Diagnostics:PrintGuild(guildId, nowS)
    local category = GUILD_HISTORY_EVENT_CATEGORY_TRADER
    local stats = self.saleWatcher:GetStats(guildId)
    local requestId = self.saleWatcher:GetRequestId(guildId)

    d(string.format(GetString(TRADEQR_DIAG_GUILD),
        GetGuildName(guildId),
        GetNumGuildHistoryEvents(guildId, category),
        self:YesNo(DoesGuildHistoryEventCategoryHaveUpToDateEvents(guildId, category)),
        tostring(GetOldestGuildHistoryEventIndexForUpToDateEventsWithoutGaps(guildId, category) or "-")))
    d(string.format(GetString(TRADEQR_DIAG_SCAN),
        stats.lastScanEvents or 0, stats.lastScanSold or 0, stats.lastScanMine or 0, stats.lastScanAdded or 0,
        self:Ago(stats.lastScanS, nowS)))
    d(string.format(GetString(TRADEQR_DIAG_REQUEST),
        self:ReadyStateText(stats.lastReadyState),
        requestId and tostring(GetGuildHistoryRequestFlags(requestId)) or "-",
        requestId and self:YesNo(IsGuildHistoryRequestComplete(requestId)) or "-",
        self:Ago(stats.requestCreatedS, nowS),
        stats.updatesReceived,
        tostring(stats.lastUpdateFlags or "-"),
        self:Ago(stats.lastPollS, nowS)))
    if stats.newestSeller then
        d(string.format(GetString(TRADEQR_DIAG_NEWEST_SELLER), stats.newestSeller, self:Ago(stats.newestSellerS, nowS), self:YesNo(self.saleWatcher:IsCurrentAccount(stats.newestSeller))))
    end
end

function Diagnostics:YesNo(value)
    return GetString(value and TRADEQR_DIAG_YES or TRADEQR_DIAG_NO)
end

function Diagnostics:Ago(timestampS, nowS)
    if not timestampS then
        return "-"
    end
    return string.format(GetString(TRADEQR_DIAG_MINUTES_AGO), (nowS - timestampS) / 60)
end

function Diagnostics:ReadyStateText(readyState)
    if readyState == GUILD_HISTORY_DATA_READY_STATE_READY then
        return GetString(TRADEQR_DIAG_STATE_READY)
    elseif readyState == GUILD_HISTORY_DATA_READY_STATE_RESPONSE_PENDING then
        return GetString(TRADEQR_DIAG_STATE_PENDING)
    elseif readyState == GUILD_HISTORY_DATA_READY_STATE_ON_COOLDOWN then
        return GetString(TRADEQR_DIAG_STATE_COOLDOWN)
    elseif readyState == GUILD_HISTORY_DATA_READY_STATE_INVALID_REQUEST then
        return GetString(TRADEQR_DIAG_STATE_INVALID)
    end
    return GetString(TRADEQR_DIAG_STATE_NONE)
end

TradeQR.Diagnostics = Diagnostics
