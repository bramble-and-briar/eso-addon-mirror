-- Optional historical sales supplement trading statistics only, never real cash.
local A=ALTHarvestItems
local function L(key) return A:T(key) end
function A:GoldPeriodBounds(t,period)
    local midnight=t-(GetSecondsSinceMidnight and GetSecondsSinceMidnight() or t%86400)
    if period==1 then return self:GoldState().started,t+1 end
    if period==2 then return midnight,t+1 end
    if period==3 then return midnight-86400,midnight end
    if period==7 then
        if not GetGuildKioskCycleTimes then return end
        local _,ending=GetGuildKioskCycleTimes()
        if type(ending)~='number' or ending<=0 then return end
        local week=7*86400
        local start=ending+math.floor((t-ending)/week)*week
        return start,math.min(t+1,start+week)
    end
    return t-(({[4]=7,[5]=14,[6]=30})[period] or 30)*86400,t+1
end
function A:GoldCaptureSale(guildId,info)
    local t=GetTimeStamp()
    if type(info)~='table' or info.isRedacted or info.eventType~=GUILD_HISTORY_TRADER_EVENT_ITEM_SOLD
        or not info.eventId or type(info.timestampS)~='number' or info.timestampS<t-30*86400 or info.timestampS>t
        or type(info.price)~='number' or info.price<=0 or type(info.sellerDisplayName)~='string'
        or zo_strlower(info.sellerDisplayName:gsub('^@',''))~=zo_strlower(GetDisplayName():gsub('^@','')) then return false end
    if not GetTradingHousePostPriceInfo then return false end
    local _,cut=GetTradingHousePostPriceInfo(info.price)
    if type(cut)~='number' or cut<0 or cut>info.price then return false end
    local state=self:GoldPeriodState(); local id=tostring(guildId)..':'..tostring(info.eventId)
    local old=state.sales[id]
    if not old and state.boundary and state.boundary[id] and not self.goldImport then return false end
    local tax=type(info.tax)=='number' and info.tax>=0 and info.tax<=cut and info.tax or nil
    -- Copy scalar fields: native event tables are recycled by ESO/LibHistoire.
    state.sales[id]={at=info.timestampS,amount=info.price-cut,gross=info.price,tax=tax,
        guild=tostring(guildId),name=GetGuildName(guildId)}
    self.goldPeriodCache=nil
    return old==nil
end
local tradeEvent=A.GoldTradeEvent
function A:GoldTradeEvent(guildId,info)
    tradeEvent(self,guildId,info); self:GoldCaptureSale(guildId,info)
end
function A:GoldGuildMetrics(summary)
    local first,last=self:GoldPeriodBounds(GetTimeStamp(),self.db.ui.goldPeriod or 1)
    local rows={}; if not first then return rows end
    for _,sale in pairs(self:GoldPeriodState().sales) do
        if sale.at>=first and sale.at<last then
            local row=rows[sale.guild] or {name=sale.name,gross=0,tax=0,amount=0,count=0}
            row.count=row.count+1; row.amount=row.amount+sale.amount
            if sale.gross==nil then row.grossMissing=true else row.gross=row.gross+sale.gross end
            if sale.tax==nil then row.taxMissing=true else row.tax=row.tax+sale.tax end
            rows[sale.guild]=row
        end
    end
    for id,sale in pairs(summary.guilds or {}) do
        local row=rows[id]
        if not row or row.amount~=sale.amount then
            rows[id]={name=sale.name,amount=sale.amount,grossMissing=true,taxMissing=true}
        end
    end
    return rows
end
local tradeSummary=A.GoldTradeSummary
function A:GoldTradeSummary()
    local summary=tradeSummary(self)
    if (self.db.ui.goldPeriod or 1)~=1 then return summary end
    summary=self.Copy(summary); summary.guilds=summary.guilds or {}
    local g=self:GoldState(); local seen=g.trades and g.trades.seen or {}
    for id,sale in pairs(self:GoldPeriodState().sales) do
        if sale.at>=g.started and not seen[id] then
            summary.value=summary.value+sale.amount
            local row=summary.guilds[sale.guild] or {name=sale.name,amount=0}
            row.amount=row.amount+sale.amount; summary.guilds[sale.guild]=row
        end
    end
    return summary
end
function A:GoldPersonalTotals(c)
    local income,expenses=0,0
    for key,value in pairs(c and c.categories or {}) do
        if key~='GOLD_GUILD_SALE' and key~='GOLD_GUILD_BUY' and key~='GOLD_LISTING' and key~='GOLD_REFUND' then
            income=income+value.income; expenses=expenses+value.expenses
        end
    end
    return income,expenses
end
function A:CancelGoldImport()
    local job=self.goldImport; self.goldImport=nil
    EVENT_MANAGER:UnregisterForUpdate('ALTHIGoldImportTimeout')
    if job then for _,processor in ipairs(job.processors) do if processor.Stop then pcall(processor.Stop,processor) end end end
end
function A:FinishGoldImport(job)
    if self.goldImport~=job or job.starting or job.remaining>0 then return end
    self.goldImport=nil; EVENT_MANAGER:UnregisterForUpdate('ALTHIGoldImportTimeout')
    self:GoldPeriodState().lastImport={at=GetTimeStamp(),added=job.added,complete=job.complete,first=job.first,last=job.last}
    self:Say(string.format(L(job.complete and 'GOLD_IMPORT_DONE' or 'GOLD_IMPORT_PARTIAL'),job.added))
    self:QueueRefresh()
end
function A:StartGoldImport()
    if self.goldImport then self:Say(L('GOLD_IMPORT_RUNNING')); return end
    local lib=self.goldHistoryLib
    if not lib or not lib.CreateGuildHistoryProcessor or not lib.StopReason or not GetNumGuilds or GetNumGuilds()==0 then
        self:Say(L('GOLD_IMPORT_UNAVAILABLE')); return
    end
    if type(lib.IsGuildHistorySystemDisabled)=='function' then
        local ok,disabled=pcall(lib.IsGuildHistorySystemDisabled,lib)
        if not ok or disabled then self:Say(L('GOLD_IMPORT_UNAVAILABLE')); return end
    end
    local job={first=GetTimeStamp()-30*86400,last=GetTimeStamp()+1,remaining=GetNumGuilds(),starting=true,
        processors={},added=0,complete=true,state=self:GoldState()}
    self.goldImport=job
    self:Say(L('GOLD_IMPORT_RUNNING'))
    for i=1,GetNumGuilds() do
        local guild=GetGuildId(i); local stopped=false
        local function finish(reason)
            if self.goldImport~=job or stopped then return end
            stopped=true; job.remaining=job.remaining-1
            if reason~=lib.StopReason.ITERATION_COMPLETED then job.complete=false end
            self:FinishGoldImport(job)
        end
        local ok,processor=pcall(lib.CreateGuildHistoryProcessor,lib,guild,GUILD_HISTORY_EVENT_CATEGORY_TRADER,'ALTHI Gold Import')
        if not ok or not processor or type(processor.StartIteratingTimeRange)~='function' then finish(nil)
        else
            job.processors[#job.processors+1]=processor
            local valid,started=pcall(processor.StartIteratingTimeRange,processor,job.first,job.last,function(event)
                if self.goldImport~=job or self:GoldState()~=job.state then return end
                if not event or type(event.GetEventInfo)~='function' then job.complete=false; return end
                local success,info=pcall(event.GetEventInfo,event)
                if not success then job.complete=false; return end
                if type(info)~='table' or info.isRedacted then job.complete=false; return end
                if type(info)=='table' and type(info.timestampS)=='number' and info.timestampS>=job.first and info.timestampS<job.last then
                    if self:GoldCaptureSale(guild,info) then job.added=job.added+1 end
                end
            end,finish)
            if not valid or not started then finish(nil); if processor.Stop then pcall(processor.Stop,processor) end end
        end
    end
    job.starting=false; self:FinishGoldImport(job)
    if self.goldImport==job then
        EVENT_MANAGER:RegisterForUpdate('ALTHIGoldImportTimeout',120000,function()
            if self.goldImport~=job then return end
            job.complete=false; job.remaining=0; self:FinishGoldImport(job)
            for _,processor in ipairs(job.processors) do if processor.Stop then pcall(processor.Stop,processor) end end
        end)
    end
end
function A:ConfirmGoldImport() ZO_Dialogs_ShowDialog('ALTHI_GOLD_IMPORT_CONFIRM') end
local reset=A.GoldResetAll
function A:GoldResetAll() self:CancelGoldImport(); reset(self) end
local initialize=A.Initialize
function A:Initialize()
    initialize(self)
    ZO_Dialogs_RegisterCustomDialog('ALTHI_GOLD_IMPORT_CONFIRM',{title={text=L('GOLD_IMPORT_TITLE')},
        mainText={text=L('GOLD_IMPORT_CONFIRM')},buttons={{text=L('GOLD_IMPORT_BUTTON'),callback=function() self:StartGoldImport() end},{text=L('CANCEL')}}})
    EVENT_MANAGER:RegisterForEvent('ALTHIGoldImport',EVENT_PLAYER_DEACTIVATED,function() self:CancelGoldImport() end)
end
