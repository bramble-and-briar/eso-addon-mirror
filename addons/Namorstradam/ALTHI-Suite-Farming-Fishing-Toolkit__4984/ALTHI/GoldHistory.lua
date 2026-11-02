-- Optional LibHistoire v2 processing. History enriches attribution, never the cash ledger.
local A=ALTHarvestItems
local function stamp() return GetTimeStamp and GetTimeStamp() or 0 end
function A:GoldRememberPendingSale(mail,charId)
    local g=self:GoldState(); g.goldPendingSales=g.goldPendingSales or {}
    g.goldPendingSales[mail.key]={key=mail.key,amount=mail.amount,received=mail.received,itemId=mail.itemId,charId=charId,collected=stamp()}
    local count,oldest,oldestTime=0,nil,math.huge
    for id,entry in pairs(g.goldPendingSales) do count=count+1; if entry.collected<oldestTime then oldest=id; oldestTime=entry.collected end end
    if count>100 and oldest then g.goldPendingSales[oldest]=nil end
    self:GoldStartHistoryTimer()
end
function A:GoldStartHistoryTimer()
    if not self.goldHistoryLib then return end
    local pending=self:GoldState().goldPendingSales
    if not pending or not next(pending) then return end
    EVENT_MANAGER:RegisterForUpdate('ALTHIGoldHistory',10000,function() self:GoldRetryHistory() end)
    self:GoldRetryHistory()
end
function A:GoldCancelHistory()
    local job=self.goldHistoryJob
    self.goldHistoryJob=nil
    if job then
        job.cancelled=true
        for _,processor in ipairs(job.processors) do if type(processor.Stop)=='function' then pcall(processor.Stop,processor) end end
    end
end
function A:GoldRangeCovered(guildId,first,last)
    if not GetNumGuildHistoryEventRanges or not GetGuildHistoryEventRangeInfo then return false end
    for index=1,GetNumGuildHistoryEventRanges(guildId,GUILD_HISTORY_EVENT_CATEGORY_TRADER) do
        local newest,oldest=GetGuildHistoryEventRangeInfo(guildId,GUILD_HISTORY_EVENT_CATEGORY_TRADER,index)
        if newest and oldest and oldest<=first and newest>=last then return true end
    end
    return false
end
function A:GoldHistoryCandidate(mail,guildId,info)
    if type(info)~='table' or info.isRedacted or info.eventType~=GUILD_HISTORY_TRADER_EVENT_ITEM_SOLD
        or type(info.sellerDisplayName)~='string' or type(info.timestampS)~='number' or type(info.price)~='number'
        or not info.eventId or not GetTradingHousePostPriceInfo then return end
    local seller=zo_strlower(info.sellerDisplayName:gsub('^@',''))
    local me=zo_strlower(GetDisplayName():gsub('^@',''))
    if seller~=me or math.abs(info.timestampS-mail.received)>12 then return end
    local eventKey=tostring(guildId)..':'..tostring(info.eventId)
    if (self:GoldState().goldUsedSales or {})[eventKey] then return end
    local fee,_,profit=GetTradingHousePostPriceInfo(info.price)
    if not fee or not profit or fee+profit~=mail.amount then return end
    if mail.itemId and (not info.itemLink or GetItemLinkItemId(info.itemLink)~=mail.itemId) then return end
    return {id=guildId,name=GetGuildName(guildId),eventKey=eventKey}
end
function A:GoldResolvePending(mail,guild)
    local g=self:GoldState(); local pending=g.goldPendingSales or {}; local c=g.characters[mail.charId]
    if pending[mail.key]~=mail or not c or (g.goldUsedSales or {})[guild.eventKey] then return false end
    for _,target in ipairs({g,c}) do
        local unknown=(target.guildIncome or {}).unknown
        if not unknown or unknown.amount<mail.amount then return false end
    end
    for _,target in ipairs({g,c}) do
        target.guildIncome.unknown.amount=target.guildIncome.unknown.amount-mail.amount
        if target.guildIncome.unknown.amount==0 then target.guildIncome.unknown=nil end
        local row=target.guildIncome[tostring(guild.id)] or {name=guild.name,amount=0}
        row.amount=row.amount+mail.amount; target.guildIncome[tostring(guild.id)]=row
    end
    self:GoldMarkSaleUsed(guild.eventKey); pending[mail.key]=nil
    self:QueueRefresh(); return true
end
function A:GoldFinishHistory(job)
    if self.goldHistoryJob~=job or job.cancelled or job.starting or job.remaining>0 then return end
    self.goldHistoryJob=nil
    local mail=job.mail; local g=self:GoldState()
    if (g.goldPendingSales or {})[mail.key]~=mail then return end
    local candidates={}
    for _,guild in pairs(job.candidates) do candidates[#candidates+1]=guild end
    if job.complete and #candidates==1 then self:GoldResolvePending(mail,candidates[1]) end
end
function A:GoldRetryHistory()
    local lib=self.goldHistoryLib
    if not lib or not self.goldReady or not GetNumGuilds or not GetGuildId then return end
    if type(lib.IsGuildHistorySystemDisabled)=='function' then
        local ok,disabled=pcall(lib.IsGuildHistorySystemDisabled,lib)
        if not ok or disabled then return end
    end
    local now=self.Now(); local g=self:GoldState(); local pending=g.goldPendingSales or {}
    if not next(pending) then
        self:GoldCancelHistory(); EVENT_MANAGER:UnregisterForUpdate('ALTHIGoldHistory'); return
    end
    if self.goldHistoryJob then
        if now-self.goldHistoryJob.at>30 then self:GoldCancelHistory() else return end
    end
    local selected
    for id,entry in pairs(pending) do
        if stamp()-entry.collected>30*86400 then pending[id]=nil
        elseif now-(self.goldHistoryAttempts and self.goldHistoryAttempts[id] or -60)>=60
            and (not selected or (entry.collected or 0)<(selected.collected or 0)) then selected=entry end
    end
    if not selected then return end
    self.goldHistoryAttempts=self.goldHistoryAttempts or {}; self.goldHistoryAttempts[selected.key]=now
    -- An exact AGS post-ID association may have arrived since collection.
    local direct=self:GoldGuildForMail(selected,true)
    if direct then self:GoldResolvePending(selected,direct); return end
    local job={mail=selected,at=now,processors={},candidates={},remaining=0,complete=true,starting=true}
    self.goldHistoryJob=job
    local first,last=selected.received-12,selected.received+13
    local guilds=GetNumGuilds()
    if guilds==0 then job.complete=false end
    for index=1,guilds do
        local guildId=GetGuildId(index)
        local ok,processor=pcall(lib.CreateGuildHistoryProcessor,lib,guildId,GUILD_HISTORY_EVENT_CATEGORY_TRADER,'ALTHI')
        if not ok or not processor or type(processor.StartIteratingTimeRange)~='function' then job.complete=false
        else
            job.processors[#job.processors+1]=processor; job.remaining=job.remaining+1
            local stopped=false
            local function finished(reason)
                if stopped or job.cancelled or self.goldHistoryJob~=job then return end
                stopped=true; job.remaining=job.remaining-1
                local full=lib.StopReason and reason==lib.StopReason.ITERATION_COMPLETED
                -- LAST_CACHED alone is not proof of full coverage. Native cached
                -- interval bounds can independently confirm the entire window.
                if not full and not self:GoldRangeCovered(guildId,first,last) then job.complete=false end
                self:GoldFinishHistory(job)
            end
            local startedOk,started=pcall(processor.StartIteratingTimeRange,processor,first,last,function(event)
                if job.cancelled or self.goldHistoryJob~=job then return end
                if not event or type(event.GetEventInfo)~='function' then job.complete=false; return end
                local valid,info=pcall(event.GetEventInfo,event)
                if not valid then job.complete=false; return end
                local candidate=self:GoldHistoryCandidate(selected,guildId,info)
                -- Native event objects/tables are shared and recycled. Keep only
                -- our own scalar result, never the object or its info table.
                if candidate then job.candidates[candidate.eventKey]=candidate end
            end,finished)
            if not startedOk or not started then
                job.complete=false; finished(nil)
                if type(processor.Stop)=='function' then pcall(processor.Stop,processor) end
            end
        end
    end
    job.starting=false; self:GoldFinishHistory(job)
end
local reset=A.GoldResetAll
function A:GoldResetAll()
    self:GoldCancelHistory(); EVENT_MANAGER:UnregisterForUpdate('ALTHIGoldHistory')
    reset(self); self:GoldState().goldPendingSales={}; self.goldHistoryAttempts={}
end
function A:GoldInitializeHistory()
    local lib=LibHistoire
    if type(lib)~='table' or type(lib.OnReady)~='function' or type(lib.CreateGuildHistoryProcessor)~='function'
        or type(lib.StopReason)~='table' or not lib.StopReason.ITERATION_COMPLETED then return end
    local ok=pcall(lib.OnReady,lib,function(ready)
        ready=ready or lib
        if type(ready.CreateGuildHistoryProcessor)~='function' then return end
        self.goldHistoryLib=ready
        if self.GoldStartTrades then self:GoldStartTrades() end
        if ready.RegisterCallback and ready.callback then
            local name=ready.callback.CATEGORY_LINKED
            if name then ready:RegisterCallback(name,function()
                self.goldHistoryAttempts={}; self:GoldStartHistoryTimer()
                if self.GoldStartTrades then self:GoldStartTrades() end
            end) end
        end
        self:GoldStartHistoryTimer()
    end)
    if not ok then self.goldHistoryLib=nil end -- Optional integration cannot break startup.
end
local initialize=A.Initialize
function A:Initialize()
    initialize(self)
    EVENT_MANAGER:RegisterForEvent('ALTHIGoldHistory',EVENT_PLAYER_ACTIVATED,function() self:GoldStartHistoryTimer() end)
    EVENT_MANAGER:RegisterForEvent('ALTHIGoldHistory',EVENT_PLAYER_DEACTIVATED,function()
        self:GoldCancelHistory(); EVENT_MANAGER:UnregisterForUpdate('ALTHIGoldHistory')
    end)
    self:GoldInitializeHistory()
end
