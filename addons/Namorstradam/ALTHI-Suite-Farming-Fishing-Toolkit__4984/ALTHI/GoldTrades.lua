-- Account-level sales are independent of cash collection and character wallets.
local A=ALTHarvestItems
local function stamp() return GetTimeStamp and GetTimeStamp() or 0 end
function A:GoldTradeState()
    local g=self:GoldState()
    g.trades=g.trades or {since=g.started or stamp(),seen={},guilds={},value=0,gross=0,count=0}
    return g.trades
end
function A:GoldTradeEvent(guildId,info)
    local trades=self:GoldTradeState()
    if type(info)~='table' or info.isRedacted or info.eventType~=GUILD_HISTORY_TRADER_EVENT_ITEM_SOLD
        or not info.eventId or type(info.timestampS)~='number' or info.timestampS<trades.since
        or type(info.sellerDisplayName)~='string' or type(info.price)~='number' or info.price<=0 then return end
    if zo_strlower(info.sellerDisplayName:gsub('^@',''))~=zo_strlower(GetDisplayName():gsub('^@','')) then return end
    local id=tostring(guildId)..':'..tostring(info.eventId)
    if trades.seen[id] or not GetTradingHousePostPriceInfo then return end
    local fee,_,profit=GetTradingHousePostPriceInfo(info.price)
    if type(fee)~='number' or type(profit)~='number' then return end
    local value=profit+fee
    trades.seen[id]=info.timestampS; trades.value=trades.value+value; trades.gross=trades.gross+info.price; trades.count=trades.count+1
    local guild=trades.guilds[tostring(guildId)] or {name=GetGuildName(guildId),amount=0,count=0}
    guild.amount=guild.amount+value; guild.count=guild.count+1; trades.guilds[tostring(guildId)]=guild
    self:QueueRefresh() -- No real income or post balance is changed here.
end
function A:GoldStopTrades()
    self.goldTradeGeneration=(self.goldTradeGeneration or 0)+1
    local streams=self.goldTradeStreams or {}; self.goldTradeStreams={}
    for _,processor in pairs(streams) do if type(processor.Stop)=='function' then pcall(processor.Stop,processor) end end
end
function A:GoldStartTrades()
    local lib=self.goldHistoryLib
    if self.goldTradesResetting or not self.goldReady or not lib or not GetNumGuilds then return end
    self.goldTradeStreams=self.goldTradeStreams or {}
    local trades=self:GoldTradeState(); local generation=self.goldTradeGeneration or 0; local active={}
    for index=1,GetNumGuilds() do
        local guildId=GetGuildId(index); active[guildId]=true
        if not self.goldTradeStreams[guildId] then
            local ok,processor=pcall(lib.CreateGuildHistoryProcessor,lib,guildId,GUILD_HISTORY_EVENT_CATEGORY_TRADER,'ALTHI Gold Sales')
            if ok and processor and type(processor.SetAfterEventTime)=='function' and type(processor.SetEventCallback)=='function' and type(processor.Start)=='function' then
                local startedOk,started=pcall(function()
                    processor:SetAfterEventTime(trades.since-1)
                    processor:SetEventCallback(function(event)
                        if (self.goldTradeGeneration or 0)~=generation or self:GoldTradeState()~=trades then return end
                        if not event or type(event.GetEventInfo)~='function' then return end
                        local valid,info=pcall(event.GetEventInfo,event)
                        if valid then self:GoldTradeEvent(guildId,info) end
                    end)
                    if type(processor.SetOnStopCallback)=='function' then
                        processor:SetOnStopCallback(function()
                            if self.goldTradeStreams and self.goldTradeStreams[guildId]==processor then self.goldTradeStreams[guildId]=nil end
                        end)
                    end
                    return processor:Start()
                end)
                if startedOk and started then
                    self.goldTradeStreams[guildId]=processor; self.goldTradeSupported=true
                elseif type(processor.Stop)=='function' then pcall(processor.Stop,processor) end
            end
        end
    end
    for guildId,processor in pairs(self.goldTradeStreams) do
        if not active[guildId] then pcall(processor.Stop,processor); self.goldTradeStreams[guildId]=nil end
    end
end
function A:GoldReadInbox()
    self.goldPostHeaders=nil
    -- Only the game's actual received mail headers are authoritative. Never
    -- derive mail gold from sales, COD requests, or an old saved estimate.
    if not GetNextMailId or not GetNumMailItems or not GetMailItemInfo or not HasUnreceivedMail or HasUnreceivedMail() then return nil end
    local expected=GetNumMailItems(); local count,total,id=0,0,nil; local seen={}; local attachments,unread=false,false
    if type(expected)~='number' or expected<0 then return nil end
    repeat
        id=GetNextMailId(id)
        if id then
            local key=Id64ToString and Id64ToString(id) or tostring(id)
            if seen[key] then return nil end
            seen[key]=true; count=count+1
            if count>expected then return nil end
            local _,_,_,_,isUnread,_,_,_,items,money=GetMailItemInfo(id)
            if type(money)~='number' or money<0 then return nil end
            unread=unread or isUnread==true; attachments=attachments or (type(items)=='number' and items>0)
            total=total+money
        end
    until not id
    if count~=expected then return nil end
    self.goldPostHeaders={count=count,unread=unread,attachments=attachments,money=total}
    return total
end
function A:GoldInboxAmount()
    if not self.goldPostAt or self.Now()-self.goldPostAt>5 then
        self.goldPostMoney=self:GoldReadInbox(); self.goldPostAt=self.Now()
    end
    return self.goldPostMoney
end
function A:GoldHasMailNotice()
    -- Notification state exists before the inbox headers are downloaded.
    -- This indicates mail, never a promised gold attachment or a sale estimate.
    self:GoldInboxAmount()
    local headers=self.goldPostHeaders
    local hint=self.goldPostAttachments==true and self.goldPostAttachmentsAt and self.Now()-self.goldPostAttachmentsAt<10
    return (HasUnreadMail and HasUnreadMail())
        or (HasUnreceivedMail and HasUnreceivedMail())
        or (headers and (headers.unread or headers.attachments or headers.money>0))
        or hint==true
        or false
end
function A:GoldInvalidateInbox(authoritative)
    self.goldPostAt=nil; self.goldPostMoney=nil; self.goldPostHeaders=nil
    self.goldPostReconcile=self.goldPostReconcile or authoritative==true
    EVENT_MANAGER:RegisterForUpdate('ALTHIGoldPostRefresh',150,function()
        EVENT_MANAGER:UnregisterForUpdate('ALTHIGoldPostRefresh')
        self.goldPostAt=nil -- Rescan settled headers even if an intervening UI refresh cached them.
        local amount=self:GoldInboxAmount()
        if self.goldPostReconcile and amount~=nil then self.goldPostAttachments=nil; self.goldPostAttachmentsAt=nil end
        self.goldPostReconcile=nil; self:QueueRefresh()
    end)
end
local reset=A.GoldResetAll
function A:GoldResetAll()
    local boundary={}; local old=self:GoldState().trades
    for id,time in pairs(old and old.seen or {}) do if time==true or time>=stamp() then boundary[id]=time end end
    self.goldTradesResetting=true; self:GoldStopTrades(); reset(self)
    self:GoldState().trades=nil; self.goldTradeSupported=false; self.goldTradesResetting=nil
    self:GoldTradeState().seen=boundary -- Native timestamps have one-second precision.
    self:GoldStartTrades()
end
local synchronize=A.GoldSynchronize
function A:GoldSynchronize() synchronize(self); self:GoldStartTrades() end
local initialize=A.Initialize
function A:Initialize()
    initialize(self)
    for _,event in pairs({EVENT_MAIL_INBOX_UPDATE,EVENT_MAIL_REMOVED,EVENT_MAIL_TAKE_ATTACHED_MONEY_SUCCESS,
        EVENT_MAIL_OPEN_MAILBOX,EVENT_MAIL_TAKE_ALL_ATTACHMENTS_IN_CATEGORY_RESPONSE,EVENT_PLAYER_ACTIVATED,
        EVENT_MAIL_NUM_UNREAD_CHANGED,EVENT_MAIL_LISTS_INITIALIZED,EVENT_MAIL_LISTS_UPDATED,
        EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS,EVENT_MAIL_READABLE,EVENT_MAIL_ATTACHED_MONEY_CHANGED}) do
        local authoritative=event~=EVENT_PLAYER_ACTIVATED
        EVENT_MANAGER:RegisterForEvent('ALTHIGoldPost',event,function() self:GoldInvalidateInbox(authoritative) end)
    end
    if EVENT_MAIL_WITH_ATTACHMENTS_AVAILABLE then
        EVENT_MANAGER:RegisterForEvent('ALTHIGoldPost',EVENT_MAIL_WITH_ATTACHMENTS_AVAILABLE,function(_,hasAttachments)
            self.goldPostAttachments=hasAttachments==true; self.goldPostAttachmentsAt=hasAttachments and self.Now() or nil
            self:GoldInvalidateInbox()
            EVENT_MANAGER:UnregisterForUpdate('ALTHIGoldPostHintExpiry')
            if hasAttachments then EVENT_MANAGER:RegisterForUpdate('ALTHIGoldPostHintExpiry',10000,function()
                EVENT_MANAGER:UnregisterForUpdate('ALTHIGoldPostHintExpiry')
                self.goldPostAttachments=nil; self.goldPostAttachmentsAt=nil; self:GoldInvalidateInbox()
            end) end
        end)
    end
    EVENT_MANAGER:RegisterForEvent('ALTHIGoldTrades',EVENT_PLAYER_DEACTIVATED,function()
        self:GoldStopTrades(); self.goldPostAt=nil; self.goldPostMoney=nil; self.goldPostHeaders=nil
        self.goldPostAttachments=nil; self.goldPostAttachmentsAt=nil; self.goldPostReconcile=nil
        EVENT_MANAGER:UnregisterForUpdate('ALTHIGoldPostHintExpiry')
        EVENT_MANAGER:UnregisterForUpdate('ALTHIGoldPostRefresh')
    end)
end
