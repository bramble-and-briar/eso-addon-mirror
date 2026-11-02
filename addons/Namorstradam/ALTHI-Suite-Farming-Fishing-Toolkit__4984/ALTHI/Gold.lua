-- Actual currency accounting is independent of material estimates and harvest resets.
local A = ALTHarvestItems
local function L(key) return A:T(key) end
local function stamp() return GetTimeStamp and GetTimeStamp() or 0 end
local function reasonIs(reason, name) return _G['CURRENCY_CHANGE_REASON_'..name]~=nil and reason==_G['CURRENCY_CHANGE_REASON_'..name] end
function A:GoldState()
    self.db.gold=self.db.gold or {schema=1,characters={},bank=0,bankKnown=false,opening=0,income=0,expenses=0,adjustment=0,categories={},purchases={},nextId=0,started=stamp()}
    return self.db.gold
end
function A:GoldCharacterId() return GetCurrentCharacterId and tostring(GetCurrentCharacterId()) or 'unknown' end
function A:GoldRoster()
    local roster={}
    if GetNumCharacters and GetCharacterInfo then
        for i=1,GetNumCharacters() do
            local name,_,_,_,_,_,id=GetCharacterInfo(i)
            if id then roster[tostring(id)]=zo_strformat('<<1>>',name) end
        end
    end
    if not next(roster) then roster[self:GoldCharacterId()]=GetUnitName and GetUnitName('player') or '?' end
    return roster
end
function A:GoldWealth()
    local g=self:GoldState(); local total=g.bankKnown and g.bank or 0; local known,all=0,0
    for id in pairs(self:GoldRoster()) do
        all=all+1
        if g.characters[id] then total=total+g.characters[id].balance; known=known+1 end
    end
    return total,known,all
end
function A:GoldSynchronize()
    if not GetCurrencyAmount or not CURT_MONEY then return end
    local g=self:GoldState(); local id=self:GoldCharacterId(); local roster=self:GoldRoster()
    if self.goldLoginCharacter~=id then
        self.goldLoginCharacter=id; self.db.ui.goldCharacter=id
    end
    local current=GetCurrencyAmount(CURT_MONEY,CURRENCY_LOCATION_CHARACTER)
    local bank=GetCurrencyAmount(CURT_MONEY,CURRENCY_LOCATION_BANK)
    if type(current)~='number' or type(bank)~='number' then return end
    local c=g.characters[id]
    if not c then
        c={name=roster[id] or '?',balance=current,opening=current,income=0,expenses=0,adjustment=0,categories={}}
        g.characters[id]=c; g.opening=g.opening+current
    else
        local difference=current-c.balance
        c.adjustment=c.adjustment+difference; g.adjustment=g.adjustment+difference
        c.balance=current; c.name=roster[id] or c.name
    end
    if g.bankKnown then g.adjustment=g.adjustment+bank-g.bank else g.opening=g.opening+bank end
    g.bank=bank; g.bankKnown=true; c.seen=stamp()
    -- Remove deleted characters from the scope without inventing expenditure.
    local removed=0
    for charId,char in pairs(g.characters) do if not roster[charId] and not char.retired then removed=removed+char.balance; char.retired=true end end
    g.adjustment=g.adjustment-removed
    self.goldReady=true; self:QueueRefresh()
end
function A:GoldCategory(reason,delta)
    local map={TRADINGHOUSE_LISTING='GOLD_LISTING',TRADINGHOUSE_REFUND='GOLD_REFUND',TRADINGHOUSE_PURCHASE='GOLD_GUILD_BUY',VENDOR_REPAIR='GOLD_REPAIR',TRAVEL_GRAVEYARD='GOLD_TRAVEL',MAIL='GOLD_MAIL',CASH_ON_DELIVERY='GOLD_COD',TRADE='GOLD_TRADE',QUESTREWARD='GOLD_QUEST',LOOT='GOLD_LOOT',LOOT_STOLEN='GOLD_LOOT',LOOT_CURRENCY_CONTAINER='GOLD_LOOT',VENDOR='GOLD_VENDOR',BUYBACK='GOLD_VENDOR'}
    for name,key in pairs(map) do if reasonIs(reason,name) then return key end end
    return 'GOLD_OTHER'
end
function A:GoldCurrency(_,currency,location,newAmount,oldAmount,reason)
    if currency~=CURT_MONEY or not self.goldReady then return end
    local g=self:GoldState(); local c=g.characters[self:GoldCharacterId()]
    if not c or type(newAmount)~='number' or type(oldAmount)~='number' then return end
    if location==CURRENCY_LOCATION_BANK then
        -- Bank movement is represented by the character-side event; never count twice.
        g.bank=newAmount; g.bankKnown=true; self:QueueRefresh(); return
    end
    if location~=CURRENCY_LOCATION_CHARACTER then return end
    local transfer=reasonIs(reason,'BANK_DEPOSIT') or reasonIs(reason,'BANK_WITHDRAWAL')
    if reasonIs(reason,'PLAYER_INIT') then self:GoldSynchronize(); return end
    if c.balance==newAmount then return end -- Repeated snapshot/event, already observed.
    -- Event old/new carry the actual movement; snapshot gaps remain explicit adjustments.
    local gap=oldAmount-c.balance
    c.adjustment=c.adjustment+gap; g.adjustment=g.adjustment+gap
    c.balance=newAmount; c.seen=stamp()
    local delta=newAmount-oldAmount
    if delta==0 then return end
    if transfer then self:QueueRefresh(); return end
    local key=self:GoldCategory(reason,delta); local amount=math.abs(delta)
    local side=delta>0 and 'income' or 'expenses'
    for _,target in ipairs({g,c}) do
        target[side]=target[side]+amount
        target.categories[key]=target.categories[key] or {income=0,expenses=0}
        target.categories[key][side]=target.categories[key][side]+amount
    end
    if delta>0 and key=='GOLD_MAIL' and self.GoldQueueMailCredit then self:GoldQueueMailCredit(amount,self:GoldCharacterId()) end
    self:QueueRefresh()
end
function A:GoldResetAll()
    self:GoldSynchronize(); local g=self:GoldState()
    g.opening=self:GoldWealth(); g.income=0; g.expenses=0; g.adjustment=0; g.categories={}; g.started=stamp(); g.purchases={}
    for _,c in pairs(g.characters) do c.opening=c.balance; c.income=0; c.expenses=0; c.adjustment=0; c.categories={} end
    self:QueueRefresh()
end
local oldSelect=A.SelectActivity
function A:SelectActivity(tab)
    -- Gathering still updates both sessions while the player reads the gold panel.
    if self.db.ui.activity=='gold' and tab~='gold' and not self.goldManualSelection then return end
    oldSelect(self,tab)
end
local oldInitialize=A.Initialize
function A:Initialize()
    oldInitialize(self)
    if self.db.ui.goldTab~='overview' and self.db.ui.goldTab~='characters' then self.db.ui.goldTab='overview' end
    ZO_Dialogs_RegisterCustomDialog('ALTHI_GOLD_RESET',{title={text=L('GOLD_MODULE')},mainText={text=L('GOLD_RESET_ALL_CONFIRM')},buttons={{text=L('RESET'),callback=function() self:GoldResetAll() end},{text=L('CANCEL')}}})
    if not GetCurrencyAmount or not GetCurrentCharacterId then return end
    EVENT_MANAGER:RegisterForEvent('ALTHIGold',EVENT_PLAYER_ACTIVATED,function()
        self:GoldSynchronize()
    end)
    EVENT_MANAGER:RegisterForEvent('ALTHIGold',EVENT_PLAYER_DEACTIVATED,function() self.goldReady=false end)
    EVENT_MANAGER:RegisterForEvent('ALTHIGold',EVENT_CURRENCY_UPDATE,function(...) self:GoldCurrency(...) end)
    -- This event has no documented native currency-type filter. Reject other
    -- currencies/locations immediately; do not invent a filter constant.
end
