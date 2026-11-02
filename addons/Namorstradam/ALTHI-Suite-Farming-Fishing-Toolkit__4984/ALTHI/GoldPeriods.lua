-- Bounded dated trade data supplements old totals; it never replaces cash books.
local A=ALTHarvestItems
local function now() return GetTimeStamp() end
local keys={'GOLD_PERIOD_ALL','GOLD_PERIOD_TODAY','GOLD_PERIOD_YESTERDAY','GOLD_PERIOD_7','GOLD_PERIOD_14','GOLD_PERIOD_30','GOLD_PERIOD_WEEK'}
function A:GoldPeriodState()
    local g=self:GoldState()
    g.tradePeriods=g.tradePeriods or {since=now(),sales={},costs={}}
    if not self.goldPeriodPruneAt or now()-self.goldPeriodPruneAt>=3600 then
        local cutoff=now()-31*86400
        for id,sale in pairs(g.tradePeriods.sales) do if sale.at<cutoff then g.tradePeriods.sales[id]=nil end end
        for i=#g.tradePeriods.costs,1,-1 do if g.tradePeriods.costs[i].at<cutoff then table.remove(g.tradePeriods.costs,i) end end
        self.goldPeriodPruneAt=now(); self.goldPeriodCache=nil
    end
    return g.tradePeriods
end
function A:GoldPeriodKey() return keys[self.db.ui.goldPeriod or 1] or keys[1] end
function A:GoldChoosePeriod(control)
    ClearMenu()
    for i,key in ipairs(keys) do
        local index=i
        AddMenuItem(self:T(key),function() self.db.ui.goldPeriod=index; self.goldOffset=0; self:QueueRefresh() end)
    end
    ShowMenu(control)
end
function A:GoldTradeSummary()
    local g=self:GoldState(); local period=self.db.ui.goldPeriod or 1
    if period==1 then
        local trades=g.trades
        local sales=trades and (self.goldTradeSupported or trades.count>0) and trades or nil
        return {value=sales and sales.value or (g.categories.GOLD_GUILD_SALE or {}).income or 0,
            guilds=sales and sales.guilds or g.guildIncome,
            costs=(g.categories.GOLD_GUILD_BUY or {}).expenses or 0,
            fees=(g.categories.GOLD_LISTING or {}).expenses or 0,
            refunds=(g.categories.GOLD_REFUND or {}).income or 0}
    end
    local t=now(); local state=self:GoldPeriodState()
    local start,finish=self:GoldPeriodBounds(t,period)
    if not start then return {value=0,costs=0,fees=0,refunds=0,guilds={},partial=true,unavailable=true} end
    local cached=self.goldPeriodCache
    if cached and cached.state==state and cached.period==period and cached.start==start and cached.finish==finish then return cached.result end
    local result={value=0,costs=0,fees=0,refunds=0,guilds={},partial=true}
    for id,sale in pairs(state.sales) do
        if sale.at<t-31*86400 then state.sales[id]=nil
        elseif sale.at>=start and sale.at<finish then
            result.value=result.value+sale.amount
            local row=result.guilds[sale.guild] or {name=sale.name,amount=0}
            row.amount=row.amount+sale.amount; result.guilds[sale.guild]=row
        end
    end
    for i=#state.costs,1,-1 do
        local cost=state.costs[i]
        if cost.at<t-31*86400 then table.remove(state.costs,i)
        elseif cost.at>=start and cost.at<finish then result[cost.kind]=result[cost.kind]+cost.amount end
    end
    self.goldPeriodCache={state=state,period=period,start=start,finish=finish,result=result}
    return result
end
local event=A.GoldTradeEvent
function A:GoldTradeEvent(guildId,info)
    event(self,guildId,info)
    if type(info)~='table' or info.isRedacted or info.eventType~=GUILD_HISTORY_TRADER_EVENT_ITEM_SOLD
        or not info.eventId or type(info.timestampS)~='number' or info.timestampS<now()-31*86400
        or info.timestampS>now() or type(info.price)~='number' or info.price<=0
        or type(info.sellerDisplayName)~='string'
        or zo_strlower(info.sellerDisplayName:gsub('^@',''))~=zo_strlower(GetDisplayName():gsub('^@','')) then return end
    local state=self:GoldPeriodState(); local id=tostring(guildId)..':'..tostring(info.eventId)
    if state.sales[id] or (state.boundary and state.boundary[id]) or not GetTradingHousePostPriceInfo then return end
    local fee,_,profit=GetTradingHousePostPriceInfo(info.price)
    if type(fee)~='number' or type(profit)~='number' then return end
    state.sales[id]={at=info.timestampS,amount=fee+profit,guild=tostring(guildId),name=GetGuildName(guildId)}
    self.goldPeriodCache=nil; self:QueueRefresh()
end
local currency=A.GoldCurrency
function A:GoldCurrency(...)
    local g=self:GoldState(); local before={}
    for key,kind in pairs({GOLD_GUILD_BUY='costs',GOLD_LISTING='fees',GOLD_REFUND='refunds'}) do
        before[key]=(g.categories[key] or {})[kind=='refunds' and 'income' or 'expenses'] or 0
    end
    currency(self,...)
    for key,kind in pairs({GOLD_GUILD_BUY='costs',GOLD_LISTING='fees',GOLD_REFUND='refunds'}) do
        local amount=((g.categories[key] or {})[kind=='refunds' and 'income' or 'expenses'] or 0)-before[key]
        if amount>0 then
            local state=self:GoldPeriodState()
            state.costs[#state.costs+1]={at=now(),kind=kind,amount=amount}; self.goldPeriodCache=nil
        end
    end
end
local reset=A.GoldResetAll
function A:GoldResetAll()
    reset(self)
    local boundary={}; for id,at in pairs(self:GoldTradeState().seen) do boundary[id]=at end
    self:GoldState().tradePeriods={since=now(),sales={},costs={},boundary=boundary}; self.goldPeriodCache=nil
end
