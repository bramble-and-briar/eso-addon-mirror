-- Mail metadata only classifies an already observed gold credit; it never creates income.
local A=ALTHarvestItems
local soldSubjects={de='Gegenstand verkauft',en='Item Sold',fr='Objet vendu',es='Objeto vendido',ru='Предмет продан',zh='物品已售出',jp='アイテムが売れました'}
local function key(id) return Id64ToString and Id64ToString(id) or tostring(id) end
local function stamp() return GetTimeStamp and GetTimeStamp() or 0 end
local function remember(map,id)
    map[id]=stamp(); local count,oldest,oldestTime=0,nil,math.huge
    for entry,time in pairs(map) do count=count+1; if time<oldestTime then oldest=entry; oldestTime=time end end
    if count>500 and oldest then map[oldest]=nil end
end
function A:GoldMarkSaleUsed(eventKey)
    local g=self:GoldState(); g.goldUsedSales=g.goldUsedSales or {}; remember(g.goldUsedSales,eventKey)
end
function A:GoldGuildForMail(mail,agsOnly)
    local g=self:GoldState(); local candidates={}
    -- Use already available history only: no background guild-history downloads.
    if not agsOnly and not self.goldHistoryLib and GetGuildHistoryEventIndicesForTimeRange and GetGuildHistoryTraderEventInfo and GetTradingHousePostPriceInfo
        and GetNumGuilds and GetGuildId and GUILD_HISTORY_EVENT_CATEGORY_TRADER then
        local me=zo_strlower((GetDisplayName() or ''):gsub('^@',''))
        for guildIndex=1,GetNumGuilds() do
            local guildId=GetGuildId(guildIndex)
            local newest,oldest=GetGuildHistoryEventIndicesForTimeRange(guildId,GUILD_HISTORY_EVENT_CATEGORY_TRADER,mail.received+12,mail.received-12)
            if newest and oldest and math.abs(newest-oldest)<250 then
                for index=math.min(newest,oldest),math.max(newest,oldest) do
                    local eventId,time,redacted,eventType,seller,_,link,_,price=GetGuildHistoryTraderEventInfo(guildId,index)
                    local eventKey=tostring(guildId)..':'..tostring(eventId)
                    if eventId and not redacted and eventType==GUILD_HISTORY_TRADER_EVENT_ITEM_SOLD and type(seller)=='string'
                        and zo_strlower(seller:gsub('^@',''))==me and math.abs(time-mail.received)<=12
                        and not (g.goldUsedSales or {})[eventKey] and type(price)=='number' then
                        local fee,_,profit=GetTradingHousePostPriceInfo(price)
                        local itemId=link and GetItemLinkItemId(link)
                        if profit and fee and profit+fee==mail.amount and (not mail.itemId or itemId==mail.itemId) then
                            candidates[#candidates+1]={id=guildId,name=GetGuildName(guildId),eventKey=eventKey}
                        end
                    end
                end
            end
        end
    end
    if #candidates==1 then return candidates[1] end
    if #candidates>1 then return nil end -- Never choose a random equal-price sale.
    -- Optional existing AGS mail-ID association, verified against payout/time.
    local account=type(AwesomeGuildStore_Data)=='table' and AwesomeGuildStore_Data[GetWorldName()..GetDisplayName()]
    local event=type(account)=='table' and type(account.mailAugmentationData)=='table' and account.mailAugmentationData[mail.key]
    if type(event)=='table' and event.eventId and event.guildId and type(event.guildName)=='string' and event.guildName~=''
        and type(event.eventTime)=='number' and math.abs(event.eventTime-mail.received)<=12 and type(event.price)=='number'
        and GetTradingHousePostPriceInfo then
        local fee,_,profit=GetTradingHousePostPriceInfo(event.price)
        local eventKey=tostring(event.guildId)..':'..tostring(event.eventId)
        if fee and profit and fee+profit==mail.amount and not (g.goldUsedSales or {})[eventKey]
            and (not mail.itemId or event.itemLink and GetItemLinkItemId(event.itemLink)==mail.itemId) then
            return {id=event.guildId,name=event.guildName,eventKey=eventKey}
        end
    end
end
function A:GoldSnapshotMail(mailId)
    if not GetMailItemInfo then return end
    local _,_,subject,_,_,system,cs,returned,_,money,_,_,age=GetMailItemInfo(mailId)
    if type(money)~='number' or money<=0 then return end
    local k=key(mailId); local body=''
    if ReadMail and IsReadMailInfoReady and IsReadMailInfoReady(mailId) then body=ReadMail(mailId) or '' end
    local mail={key=k,amount=money,at=self.Now(),received=stamp()-(age or 0),
        sale=system==true and not cs and not returned and subject==soldSubjects[self:ClientLanguage()],
        itemId=tonumber(body:match('|H%d+:item:(%d+):'))}
    if mail.sale then mail.guild=self:GoldGuildForMail(mail) end
    self.goldMailSnapshots=self.goldMailSnapshots or {}
    for id,entry in pairs(self.goldMailSnapshots) do if self.Now()-entry.at>120 then self.goldMailSnapshots[id]=nil end end
    self.goldMailSnapshots[k]=mail
end
function A:GoldQueueMailCredit(amount,charId)
    self.goldMailCredits=self.goldMailCredits or {}
    self.goldMailCredits[#self.goldMailCredits+1]={amount=amount,charId=charId,at=self.Now()}
    if #self.goldMailCredits>100 then table.remove(self.goldMailCredits,1) end
    self:GoldMatchMailCredits()
end
function A:GoldConfirmMail(mailId)
    local k=key(mailId); local g=self:GoldState()
    g.goldClaimedMails=g.goldClaimedMails or {}
    if g.goldClaimedMails[k] then return end
    local mail=(self.goldMailSnapshots or {})[k]
    if not mail or self.Now()-mail.at>120 then return end
    if mail.sale and not mail.guild then mail.guild=self:GoldGuildForMail(mail) end
    remember(g.goldClaimedMails,k)
    self.goldMailClaims=self.goldMailClaims or {}; mail.confirmedAt=self.Now()
    self.goldMailClaims[#self.goldMailClaims+1]=mail
    if #self.goldMailClaims>100 then table.remove(self.goldMailClaims,1) end
    self:GoldMatchMailCredits()
end
function A:GoldMatchMailCredits()
    local now=self.Now(); local credits=self.goldMailCredits or {}; local claims=self.goldMailClaims or {}
    for i=#credits,1,-1 do if now-credits[i].at>10 then table.remove(credits,i) end end
    for i=#claims,1,-1 do if now-claims[i].confirmedAt>10 then table.remove(claims,i) end end
    for claimIndex=#claims,1,-1 do
        local mail=claims[claimIndex]
        for creditIndex,credit in ipairs(credits) do
            if credit.amount==mail.amount then
                if mail.sale then self:GoldClassifySaleCredit(credit,mail) end
                table.remove(credits,creditIndex); table.remove(claims,claimIndex); break
            end
        end
    end
end
function A:GoldClassifySaleCredit(credit,mail)
    local g=self:GoldState(); local c=g.characters[credit.charId]
    if not c then return end
    for _,target in ipairs({g,c}) do
        local original=target.categories.GOLD_MAIL
        if not original or original.income<credit.amount then return end
    end
    local guild=mail.guild; local guildKey=guild and tostring(guild.id) or 'unknown'
    for _,target in ipairs({g,c}) do
        target.categories.GOLD_MAIL.income=target.categories.GOLD_MAIL.income-credit.amount
        target.categories.GOLD_GUILD_SALE=target.categories.GOLD_GUILD_SALE or {income=0,expenses=0}
        target.categories.GOLD_GUILD_SALE.income=target.categories.GOLD_GUILD_SALE.income+credit.amount
        target.guildIncome=target.guildIncome or {}
        local row=target.guildIncome[guildKey] or {name=guild and guild.name,amount=0}
        row.amount=row.amount+credit.amount; target.guildIncome[guildKey]=row
    end
    if guild then self:GoldMarkSaleUsed(guild.eventKey)
    elseif self.GoldRememberPendingSale then self:GoldRememberPendingSale(mail,credit.charId) end
    self:QueueRefresh()
end
local reset=A.GoldResetAll
function A:GoldResetAll()
    reset(self); local g=self:GoldState(); g.guildIncome={}
    for _,c in pairs(g.characters) do c.guildIncome={} end
    self.goldMailCredits={}; self.goldMailClaims={}
end
local initialize=A.Initialize
function A:Initialize()
    initialize(self)
    for _,event in pairs({EVENT_MAIL_READABLE,EVENT_MAIL_TAKE_ATTACHED_MONEY_SUCCESS}) do
        if event then
            local readable=event==EVENT_MAIL_READABLE
            EVENT_MANAGER:RegisterForEvent('ALTHIGoldMail',event,function(_,id)
                if readable then self:GoldSnapshotMail(id) else self:GoldConfirmMail(id) end
            end)
        end
    end
    if ZO_PreHook then
        for _,name in ipairs({'TakeMailAttachedMoney','TakeMailAttachments'}) do
            if type(_G[name])=='function' then ZO_PreHook(name,function(id) self:GoldSnapshotMail(id); return false end) end
        end
        if TakeAllMailAttachmentsInCategory and GetNumMailItemsByCategory and GetMailIdByIndex then
            ZO_PreHook('TakeAllMailAttachmentsInCategory',function(category)
                for index=1,GetNumMailItemsByCategory(category) do self:GoldSnapshotMail(GetMailIdByIndex(category,index)) end
                return false
            end)
        end
    end
end
