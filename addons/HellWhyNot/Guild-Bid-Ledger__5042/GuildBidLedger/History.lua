local A = GuildBidLedger
local CATEGORY = GUILD_HISTORY_EVENT_CATEGORY_BANKED_CURRENCY
A.processors, A.requests, A.scanGeneration, A.lastRequest = {}, {}, {}, {}
A.scanning, A.rescan, A.historyDiagnostics = {}, {}, {}

function A:Scan(guildId)
    if not GetNumGuildHistoryEvents or not GetGuildHistoryBankedCurrencyEventInfo then return end
    if self.scanning[guildId] then self.rescan[guildId]=true;return end
    self.scanning[guildId]=true
    self.scanGeneration[guildId] = (self.scanGeneration[guildId] or 0) + 1
    local generation = self.scanGeneration[guildId]
    local ids = {}
    -- Indices can shift between frames: capture stable ids, resolve on each chunk.
    for index = 1, GetNumGuildHistoryEvents(guildId, CATEGORY) do
        ids[#ids + 1] = GetGuildHistoryEventId(guildId, CATEGORY, index)
    end
    self.historyDiagnostics[guildId]={cached=#ids,read=0,kiosk=0,redacted=0}
    local position = 1
    local function chunk()
        if self.scanGeneration[guildId] ~= generation then return end
        local last = math.min(position + 199, #ids)
        for n = position, last do
            local index = GetGuildHistoryEventIndex(guildId, CATEGORY, ids[n])
            if index then
                local info=self:ReadCurrencyEvent(guildId,index)
                local diagnostic=self.historyDiagnostics[guildId]
                diagnostic.read=diagnostic.read+1
                if info.isRedacted then diagnostic.redacted=diagnostic.redacted+1 end
                if self:Kind(info.eventType) then diagnostic.kiosk=diagnostic.kiosk+1 end
                self:Store(guildId,info)
            end
        end
        position = last + 1
        if position <= #ids then zo_callLater(chunk, 10) else
            self.scanning[guildId]=nil;self.dirty=true
            if self.rescan[guildId] then self.rescan[guildId]=nil;zo_callLater(function()self:Scan(guildId)end,100) end
        end
    end
    chunk()
end

function A:StartProcessor(guildId)
    if not self.libReady or self.processors[guildId] then return end
    local ok,err=pcall(function()
        local processor=LibHistoire:CreateGuildHistoryProcessor(guildId,CATEGORY,self.name)
        if not processor then return end
        self.processors[guildId]=processor
        processor:SetEventCallback(function(event)self:Store(guildId,event:GetEventInfo())end)
        processor:SetReceiveMissedEventsOutsideIterationRange(true)
        processor:SetOnStopCallback(function()self.processors[guildId]=nil;self.dirty=true end)
        local started=processor:StartStreaming(nil)
        if not started then self.processors[guildId]=nil;self.historyError="Library processor could not start; native cache remains active." end
    end)
    if not ok then self.processors[guildId]=nil;self.historyError="History library: "..tostring(err);self.dirty=true end
end

function A:RequestHistory(guildId, force)
    self:Scan(guildId)
    if self.libReady then self:StartProcessor(guildId) end
    -- A processor streams the managed range but does not request a historical date range.
    -- Make a bounded native request even with LibHistoire, using the shared cooldown/queue.
    if not CreateGuildHistoryRequest then self.message = "Guild history API unavailable."; return end
    if self.requests[guildId] then return end
    local newest = GetTimeStamp()
    if not force and self.lastRequest[guildId] and newest - self.lastRequest[guildId] < 300 then return end
    local days = GetGuildHistoryCacheDefaultMaxNumDays(CATEGORY)
    if not days or days<=0 then days=30 end
    days=math.min(30,days)
    local requestId = CreateGuildHistoryRequest(guildId, CATEGORY, newest, newest - days * 86400)
    if requestId == 0 then self.message = "History request unavailable or restricted."; return end
    self.lastRequest[guildId] = newest
    self.requests[guildId] = { id = requestId, expires = newest + 7200, next = 0 }
    self.message = "Loading available past kiosk history; server limits still apply."
end

function A:PumpRequests()
    local now = GetTimeStamp()
    for guildId, request in pairs(self.requests) do
        if IsGuildHistoryRequestComplete(request.id) or now >= request.expires then
            self:Scan(guildId)
            DestroyGuildHistoryRequest(request.id)
            self.requests[guildId] = nil
            self.message = "History request ended; displayed records may still be partial."
            self.dirty = true
        elseif now >= request.next then
            -- No tight retry loop; never bypass ESO's request cooldown or queue manager.
            -- Join ESO's own request queue even when another addon has a request.
            -- Waiting for the entire global queue to empty can starve us indefinitely.
            local flags=GetGuildHistoryRequestFlags and GetGuildHistoryRequestFlags(request.id)
            local busy=false
            if flags and ZO_FlagHelpers then
                busy=ZO_FlagHelpers.MaskHasFlag(flags,GUILD_HISTORY_REQUEST_FLAG_QUEUED)
                    or ZO_FlagHelpers.MaskHasFlag(flags,GUILD_HISTORY_REQUEST_FLAG_RESPONSE_PENDING)
            end
            local ready
            if not busy then ready=RequestMoreGuildHistoryEvents(request.id,true) end
            request.lastState=ready
            request.next = now + math.max(5, math.ceil(GetGuildHistoryRequestMinCooldownMs() / 1000))
        end
    end
end

function A:InitializeHistory()
    if LibHistoire and LibHistoire.OnReady and LibHistoire.CreateGuildHistoryProcessor then
        LibHistoire:OnReady(function()
            self.libReady = true
            local guildId=self.context and self.context.guildId or self.sv.defaultGuildId
            if guildId then self:StartProcessor(guildId) end
        end)
    end
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GUILD_HISTORY_CATEGORY_UPDATED, function(_, guildId, category)
        if category == CATEGORY then self:Scan(guildId) end
    end)
    for i = 1, GetNumGuilds() do self:Scan(GetGuildId(i)) end
end

function A:GetHistoryStatus(guildId)
    if self.historyError then return self.historyError end
    if self.requests[guildId] then return "loading past bank / kiosk events (ESO cooldown applies)" end
    if LibHistoire and not self.libReady then return "waiting for library" end
    local processor = self.processors[guildId]
    if processor and processor.GetPendingEventMetrics then
        local count = processor:GetPendingEventMetrics()
        if count and count > 0 then return tostring(count) .. " events processing" end
    end
    if not DoesGuildHistoryEventCategoryHaveUpToDateEvents(guildId, CATEGORY) then
        return "history not yet up to date"
    end
    return "cached records"
end

function A:DebugHistory()
    if not self.context then d("Guild Bid Ledger: open a trader's Bid dialog first."); return end
    local ctx = self.context
    if not DoesPlayerHaveGuildPermission(ctx.guildId, GUILD_PERMISSION_GUILD_KIOSK_BID) then return end
    local total = GetNumGuildHistoryEvents(ctx.guildId, CATEGORY)
    local records = self:GetRecords(ctx.guildId)
    local matched = self:GetRecords(ctx.guildId, ctx.kiosk)
    d(string.format("GBL API %s | guild %s | trader [%s] | bank history cached: %d | retained kiosk records: %d | matched: %d",
        tostring(GetAPIVersion()), tostring(ctx.guildId), self:KioskKey(ctx.kiosk), total, #records, #matched))
    d("GBL: " .. self:GetHistoryStatus(ctx.guildId))
    local seen = {}
    local shown = 0
    for _, r in ipairs(records) do
        local key = self:KioskKey(r.kiosk)
        if not seen[key] and shown < 5 then
            seen[key] = true; shown = shown + 1
            d("GBL cached kiosk name: [" .. key .. "]")
        end
    end
end

-- The redaction flag was inserted into the native return list. Decode both layouts
-- rather than shifting event type / money fields on clients with the older layout.
function A:ReadCurrencyEvent(guildId,index)
    local id,time,a,b,c,d,e,f=GetGuildHistoryBankedCurrencyEventInfo(guildId,index)
    if type(a)=="boolean" then
        return {eventId=id,timestampS=time,isRedacted=a,eventType=b,displayName=c,currencyType=d,amount=e,kioskName=f}
    end
    return {eventId=id,timestampS=time,isRedacted=false,eventType=a,displayName=b,currencyType=c,amount=d,kioskName=e}
end
