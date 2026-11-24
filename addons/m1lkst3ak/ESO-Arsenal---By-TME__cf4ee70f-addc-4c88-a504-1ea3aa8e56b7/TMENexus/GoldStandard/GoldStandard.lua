-- Gold Standard | Know What It's Worth. | Trash Man Enterprises
-- ESO gamepad / keyboard: tracker, inventory advisor, visited-trader flip finder.
GoldStandard = GoldStandard or {}
local GS = GoldStandard
GS.name, GS.version = "GoldStandard", "1.0.28"
GS.defaults = {
    tracking=true, showHUD=true, showLootToast=true, minToast=0,
    hudShowGold=true, hudShowAP=true, hudShowTelVar=true, showWealthHUD=false,
    wealthMaterialKeep=100, wealthFurnitureKeep=1,
    minProfit=1000, minROI=25, resaleFee=7, marketMultiplier=100,
    toastSeconds=3, maxHistory=250, topResults=100,
    showUnpriced=true, hudX=230, hudY=140, panelX=0, panelY=0,
    hudMode=2, usePersonalPricing=true, autoFlipScan=true, flipPopup=true, autoScanPages=12,
    popupX=nil, popupY=nil, toastX=nil, toastY=nil,
    hudPosX=2,hudPosY=84,hudScale=75,panelScale=100,popupScale=100,toastScale=100,wealthScale=100,
}
GS.session = {}
GS.market = {}
GS.lastLoot = "No loot recorded"
GS.lastValue = nil
GS.priceCache = {}
GS.craftWindow = {expires=0, source=nil}
GS.openTrader = false
GS.initialized = false
local function timestamp() return (GetTimeStamp and GetTimeStamp()) or 0 end
local function clockms() return (GetFrameTimeMilliseconds and GetFrameTimeMilliseconds()) or 0 end
local function call(fn,...)
    if type(fn)~="function" then return nil end
    local ok,a,b,c,d,e,f,g,h = pcall(fn,...)
    if ok then return a,b,c,d,e,f,g,h end
    return nil
end
function GS:CleanName(name)
    if type(name)~="string" then return name end
    local formatted=call(zo_strformat,"<<1>>",name) or name
    return (formatted:gsub("%^%a+", ""))
end
local function money(n)
    n=math.floor((tonumber(n) or 0)+0.5)
    if ZO_CommaDelimitNumber then return ZO_CommaDelimitNumber(n) end
    return tostring(n)
end
function GS:Money(n) return money(n) end
-- Check the *actual inventory slot* first; a link alone may not preserve
-- the binding state of the specific copy in that slot.
-- Returns true for non-tradable items, false for verified eligible items,
-- and nil if the client provides no authoritative check.
function GS:IsSlotMarketable(bag,slot,link)
    local slotBound=call(IsItemBound,bag,slot)
    if slotBound==true then return false,"bound" end
    local linkBound=call(IsItemLinkBound,link)
    if linkBound==true then return false,"bound" end
    local stolen=call(IsItemStolen,bag,slot)
    if stolen==true then return false,"stolen" end
    if slotBound==false or linkBound==false then return true,"verified" end
    return nil,"unknown binding" -- fail closed; do not inflate sale value
end
function GS:Print(msg) if d then d("|cE3B85FGold Standard|r: "..tostring(msg)) end end
function GS:VersionCheck() return type(TSCPriceDataAPI)=="table" and "TSC API" or (type(TSCPriceDataLite)=="table" and "TSC Lite" or "NO TSC DATA") end
function GS:GetPrice(link)
    if type(link)~="string" or link=="" then return nil,"invalid link" end
    -- Never substitute vendor price for a TSC sale average.
    local api=TSCPriceDataAPI
    if type(api)=="table" and type(api.GetPrice)=="function" then
        local p=call(api.GetPrice,api,link)
        if type(p)~="number" and type(p)~="table" then p=call(api.GetPrice,link) end
        if type(p)=="table" then p=p.price or p.avgPrice or p.averagePrice or p.avg or p[1] end
        if type(p)=="number" and p>0 then return p,"TSC API" end
    end
    local lite=TSCPriceDataLite
    if type(lite)=="table" and type(lite.GetPrice)=="function" and GetItemLinkItemId then
        local id=call(GetItemLinkItemId,link)
        if id then
            local p=call(lite.GetPrice,lite,id)
            if type(p)~="number" then p=call(lite.GetPrice,id) end
            if type(p)=="number" and p>0 then return p,"TSC Lite" end
        end
    end
    return nil,"TSC price not available"
end
function GS:Estimate(link,qty)
    local p,source=self:GetPrice(link)
    if not p then return nil,nil,source end
    local multiplier=(self.saved and self.saved.marketMultiplier or 100)/100
    return p*(qty or 1)*multiplier,p,source
end
-- Currency balances belong to wealth. Only *changes* in total AP / Tel Var
-- belong to income. Use the combined carried+bank balance to ignore transfers.
function GS:ReadCurrencies()
    local function amount(currency,location)
        if not GetCurrencyAmount or not currency or not location then return nil end
        local n=call(GetCurrencyAmount,currency,location)
        return type(n)=="number" and math.max(0,math.floor(n)) or nil
    end
    local carried=amount(CURT_MONEY,CURRENCY_LOCATION_CHARACTER)
    if carried==nil then carried=self:ReadWallet() end
    local banked=amount(CURT_MONEY,CURRENCY_LOCATION_BANK)
    local apHeld=amount(CURT_ALLIANCE_POINTS,CURRENCY_LOCATION_CHARACTER)
    local apBanked=amount(CURT_ALLIANCE_POINTS,CURRENCY_LOCATION_BANK)
    local totalAP=nil
    if apHeld~=nil then totalAP=apHeld+(apBanked or 0) end
    local telHeld=amount(CURT_TELVAR_STONES,CURRENCY_LOCATION_CHARACTER)
    local telBanked=amount(CURT_TELVAR_STONES,CURRENCY_LOCATION_BANK)
    local totalTel=nil
    if telHeld~=nil then totalTel=telHeld+(telBanked or 0) end
    return {carried=carried,banked=banked,ap=totalAP,apHeld=apHeld,apBanked=apBanked,
        telVar=totalTel,telHeld=telHeld,telBanked=telBanked}
end

GS.DAWN_PRISM_AP_COST=25000
-- User-supplied average resale prices. Used only if TSC cannot resolve the item link.
GS.DAWN_PRISM_FALLBACK_GOLD=3438
GS.HAKEIJO_FALLBACK_GOLD=7175
-- Dawn-Prism item id: 139409. TSC APIs take item links, not human names.
-- Try both canonical item-link formats to accommodate price datasets.
GS.DAWN_PRISM_LINKS={
    "|H1:item:139409:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
    "|H1:item:139409:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
}
function GS:GetDawnPrismPrice()
    local now=clockms()
    local cache=self.dawnPrismCache
    if cache and now>=cache.at and now-cache.at<60000 then
        return cache.price,cache.source
    end
    local price,source
    for _,link in ipairs(self.DAWN_PRISM_LINKS) do
        price,source=self:GetPrice(link)
        if type(price)=="number" and price>0 then break end
    end
    if type(price)~="number" or price<=0 then
        price=self.DAWN_PRISM_FALLBACK_GOLD
        source="Manual fallback (user-provided average)"
    end
    self.dawnPrismCache={at=now,price=price,source=source}
    return price,source
end
function GS:APConversion(ap)
    if type(ap)~="number" then return nil end
    local quantity=math.floor(math.max(0,ap)/self.DAWN_PRISM_AP_COST)
    local remaining=math.max(0,ap)-quantity*self.DAWN_PRISM_AP_COST
    local price,source=self:GetDawnPrismPrice()
    return {count=quantity,remaining=remaining,unitPrice=price,
            gross=price and (quantity*price*(self.saved.marketMultiplier or 100)/100) or nil,
            source=source}
end

-- Tel Var -> Hakeijo essence rune (Prismatic enchantments), 5,000 Tel Var.
-- Price obtained from the exact installed TSC dataset, never fabricated.
GS.HAKEIJO_TEL_COST=5000
GS.HAKEIJO_LINKS={
    "|H1:item:68342:20:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
    "|H1:item:68342:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h",
}
function GS:GetHakeijoPrice()
    local now=clockms()
    local cached=self.hakeijoCache
    if cached and now>=cached.at and now-cached.at<60000 then return cached.price,cached.source end
    local price,source=nil,"TSC Hakeijo price unavailable"
    for _,link in ipairs(self.HAKEIJO_LINKS) do
        local p,s=self:GetPrice(link)
        if type(p)=="number" and p>0 then price,source=p,s;break end
    end
    if type(price)~="number" or price<=0 then
        price=self.HAKEIJO_FALLBACK_GOLD
        source="Manual fallback (user-provided average)"
    end
    self.hakeijoCache={at=now,price=price,source=source}
    return price,source
end
function GS:TelVarConversion(value)
    if type(value)~="number" then return nil end
    local count=math.floor(math.max(0,value)/self.HAKEIJO_TEL_COST)
    local remaining=math.max(0,value)-count*self.HAKEIJO_TEL_COST
    local unit,source=self:GetHakeijoPrice()
    return {count=count,remaining=remaining,unitPrice=unit,
        gross=unit and count*unit*((self.saved and self.saved.marketMultiplier or 100)/100) or nil,
        source=source}
end

-- BAG_VIRTUAL is not a sequential bag: ESO uses item IDs as virtual slot IDs.
-- Use the official iterator, not GetBagSize(BAG_VIRTUAL) and 0..size-1.
-- Shared by Wealth, Empire, and inventory Advisor to prevent conflicting totals.
function GS:ForEachValuableBagSlot(bag,visit)
    if bag==nil or type(visit)~="function" or type(GetItemLink)~="function" then return false end
    local function visitSlot(slot,cached)
        local link=call(GetItemLink,bag,slot,LINK_STYLE_DEFAULT)
        if (type(link)~="string" or link=="") and type(cached)=="table" then link=cached.itemLink end
        if type(link)~="string" or link=="" then return end
        local qty=call(GetSlotStackSize,bag,slot)
        if (type(qty)~="number" or qty<=0) and type(cached)=="table" then
            qty=cached.stackCount or cached.stack or cached.quantity
        end
        if type(qty)=="number" and qty>0 then visit(slot,link,qty) end
    end
    if BAG_VIRTUAL~=nil and bag==BAG_VIRTUAL then
        if type(GetNextVirtualBagSlotId)=="function" then
            local last=nil
            local seen={}
            -- First call has no parameter (per ESO API); subsequent calls pass previous ID.
            for _=1,30000 do
                local slot=call(GetNextVirtualBagSlotId,last)
                if type(slot)~="number" or seen[slot] then break end
                seen[slot]=true
                visitSlot(slot)
                last=slot
            end
            return true
        end
        -- Fallback for clients exposing shared inventory data but not the iterator.
        local shared=SHARED_INVENTORY
        if shared and type(shared.GetOrCreateBagCache)=="function" then
            local cache=call(shared.GetOrCreateBagCache,shared,BAG_VIRTUAL)
            if type(cache)=="table" then
                for key,data in pairs(cache) do
                    if type(data)=="table" then
                        local slot=data.itemId or data.slotIndex or key
                        if type(slot)=="number" then visitSlot(slot,data) end
                    end
                end
                return true
            end
        end
        return false
    end
    if type(GetBagSize)~="function" then return false end
    local size=call(GetBagSize,bag)
    if type(size)~="number" or size<0 then return false end
    for slot=0,size-1 do visitSlot(slot) end
    return true
end

-- Wealth Management is a stock valuation, not income; never put it in session totals.
-- Scan only directly readable Craft Bag and Furnishing Vault bags. No guessed inventory.
function GS:ScanWealth(force)
    local now=clockms()
    if not force and self.wealthSnapshot and now-(self.wealthSnapshot.at or 0)<45000 then
        return self.wealthSnapshot
    end
    local result={at=now,materials={},furnishings={},matGold=0,furnitureGold=0,
        matExcess=0,furnitureExcess=0,matUnknown=0,furnitureUnknown=0,
        matSlots=0,furnitureSlots=0,matAccessible=false,furnitureAccessible=false}
    local function scan(bag,keep,target,isFurniture)
        if bag==nil then return end
        local totals={}
        local accessible=self:ForEachValuableBagSlot(bag,function(slot,link,qty)
            local eligible=self:IsSlotMarketable(bag,slot,link)
            if eligible==true then
                local r=totals[link]
                if not r then r={link=link,qty=0};totals[link]=r end
                r.qty=r.qty+qty
            end
        end)
        result[isFurniture and "furnitureAccessible" or "matAccessible"]=accessible
        if not accessible then return end
        for _,r in pairs(totals) do
            local excess=math.max(0,r.qty-keep)
            if excess>0 then
                -- Untradeable/bound furnishings have no resellable market value.
                do
                    local val,unit=self:Estimate(r.link,excess)
                    local entry={link=r.link,qty=r.qty,excess=excess,value=val,unit=unit}
                    target[#target+1]=entry
                    if isFurniture then
                        result.furnitureExcess=result.furnitureExcess+excess
                        if val then result.furnitureGold=result.furnitureGold+val else result.furnitureUnknown=result.furnitureUnknown+1 end
                    else
                        result.matExcess=result.matExcess+excess
                        if val then result.matGold=result.matGold+val else result.matUnknown=result.matUnknown+1 end
                    end
                end
            end
        end
        result[isFurniture and "furnitureSlots" or "matSlots"]=#target
        table.sort(target,function(a,b) return (a.value or -1)>(b.value or -1) end)
    end
    scan(BAG_VIRTUAL,math.max(0,tonumber(self.saved.wealthMaterialKeep) or 100),result.materials,false)
    scan(BAG_FURNITURE_VAULT,math.max(0,tonumber(self.saved.wealthFurnitureKeep) or 1),result.furnishings,true)
    result.knownTotal=result.matGold+result.furnitureGold
    result.unpriced=result.matUnknown+result.furnitureUnknown
    self.wealthSnapshot=result
    return result
end
function GS:InvalidateWealth(bag)
    if bag==BAG_VIRTUAL or bag==BAG_FURNITURE_VAULT then
        self.wealthSnapshot=nil
    end
    -- Empire is also an inventory valuation, so invalidate its cached snapshot.
    if bag==BAG_VIRTUAL or bag==BAG_FURNITURE_VAULT or bag==BAG_BACKPACK
        or bag==BAG_BANK or bag==BAG_SUBSCRIBER_BANK then
        self.empireCache=nil
    end
end

-- Price AP and Tel Var *incrementally*. Unlike wealth conversion (which uses
-- whole purchasable prisms), fractional-equivalent gold is meaningful for a BG
-- award smaller than 25,000 AP or 5,000 Tel Var.
function GS:CurrencyDeltaGold(kind,amount)
    local unit, cost
    if kind=="ap" then unit=self:GetDawnPrismPrice();cost=self.DAWN_PRISM_AP_COST
    else unit=self:GetHakeijoPrice();cost=self.HAKEIJO_TEL_COST end
    if type(unit)~="number" or unit<=0 or type(cost)~="number" or cost<=0 then return 0 end
    return (tonumber(amount) or 0)*unit/cost*((self.saved and self.saved.marketMultiplier or 100)/100)
end
function GS:CurrencyNetGold()
    local s=self.session or {}
    return self:CurrencyDeltaGold("ap",(s.apGained or 0)-(s.apSpent or 0))
        +self:CurrencyDeltaGold("tel",(s.telGained or 0)-(s.telSpent or 0))
end
function GS:CurrencyEarnedGold()
    local s=self.session or {}
    return self:CurrencyDeltaGold("ap",s.apGained or 0)+self:CurrencyDeltaGold("tel",s.telGained or 0)
end
-- Read both locations after currency-event bursts settle. Bank transfers
-- change location, not total currency, and must never create 'income'.
function GS:ReconcileEarnedCurrencies()
    if not self.saved or not self.saved.tracking then
        self.currencyBaseline=self:ReadCurrencies()
        return
    end
    local current=self:ReadCurrencies()
    local previous=self.currencyBaseline or {}
    self.currencyBaseline=current
    local function apply(kind,field,gainField,spendField,label)
        local new,old=current[field],previous[field]
        if type(new)~="number" or type(old)~="number" or new==old then return end
        local change=new-old
        local s=self.session
        if change>0 then s[gainField]=(s[gainField] or 0)+change
        else s[spendField]=(s[spendField] or 0)-change end
        local equivalent=self:CurrencyDeltaGold(kind,change)
        s.transactions=(s.transactions or 0)+1
        self:AddHistory({time=timestamp(),source=label..(change>0 and " earned" or " spent"),
            qty=change,value=equivalent,currency=kind})
        if change>0 then
            self.lastLoot=label.." +"..self:Money(change).." (~"..self:Money(equivalent).."g)"
            self.lastValue=equivalent
            if self.saved.showLootToast then
                self:Toast("+"..self:Money(change).." "..label.."  ~+"..self:Money(equivalent).."g")
            end
        end
    end
    apply("ap","ap","apGained","apSpent","AP")
    apply("tel","telVar","telGained","telSpent","Tel Var")
    self:Refresh()
end
function GS:ScheduleCurrencyReconcile()
    -- Coalesce character/bank notifications from a single transfer.
    self.currencyReconcileToken=(self.currencyReconcileToken or 0)+1
    local token=self.currencyReconcileToken
    self.currencyScanPending=true
    if zo_callLater then
        zo_callLater(function()
            if self.currencyReconcileToken==token then
                self.currencyScanPending=false
                self:ReconcileEarnedCurrencies()
            end
        end,500)
    else
        self.currencyScanPending=false
        self:ReconcileEarnedCurrencies()
    end
end
function GS:ResetSession(quiet)
    self.session={started=timestamp(),found=0,consumed=0,rawIn=0,rawOut=0,
        output=0, items=0, unpriced=0, drops=0, decon=0, refine=0,
        apGained=0,apSpent=0,telGained=0,telSpent=0,
        transactions=0, transfers=0, vendorSales=0, vendorPurchases=0, otherSpent=0, otherIncome=0}
    self.currencyBaseline=self:ReadCurrencies()
    self.wallet=self:ReadOwnedGold()
    self.lastWalletRecord=nil
    self.pendingVendorReceipt=nil
    if not quiet then self:Print("New session started.") end
    self:Refresh()
end
function GS:Elapsed() return math.max(1,timestamp()-(self.session.started or timestamp())) end
function GS:GrossPerHour() return (self.session.found+self.session.rawIn+self:CurrencyEarnedGold())/self:Elapsed()*3600 end
function GS:NetEstimated() return self.session.found-self.session.consumed+self.session.rawIn-self.session.rawOut+self:CurrencyNetGold() end
function GS:NetPerHour() return self:NetEstimated()/self:Elapsed()*3600 end
function GS:AddHistory(record)
    local h=self.saved.history
    table.insert(h,1,record)
    while #h>(self.saved.maxHistory or 250) do table.remove(h) end
end
function GS:TrackItem(link,quantity,reason,bag,source)
    if not self.saved or not self.saved.tracking or not quantity or quantity==0 then return end
    if type(link)~="string" or link=="" then return end
    local v,unit=self:Estimate(link,math.abs(quantity))
    local processing=clockms()<(self.craftWindow.expires or 0)
    if processing then source=self.craftWindow.source or "craft output" end
    if quantity>0 then
        if v then
            self.session.found=self.session.found+v
            self.saved.lifetimeFound=(self.saved.lifetimeFound or 0)+v
        else self.session.unpriced=self.session.unpriced+quantity end
        self.session.items=self.session.items+quantity
        self.session.drops=self.session.drops+1
        if processing and v then
            self.session.output=self.session.output+v
            self.session.decon=self.session.decon+v -- output type may be craft/refine; labelled processing in UI
        end
        self.lastLoot=link.." x"..quantity
        self.lastValue=v
        if self.lootBatch then
            self.lootBatch[#self.lootBatch+1]={link=link,qty=quantity,value=v}
        elseif v and v>0 and v>=self.saved.minToast and self.saved.showLootToast then
            self:Toast("+"..money(v).."g  "..(self:CleanName(call(GetItemLinkName,link)) or "Loot"))
        elseif not v and self.saved.showUnpriced then
            self.lastValue=nil
        end
    else
        -- Do not blindly subtract items moved between bank/backpack; only mark
        -- crafting-window consumed ingredients. This avoids fictitious losses.
        if processing and v then self.session.consumed=self.session.consumed+v end
    end
    self.session.transactions=self.session.transactions+1
    self:AddHistory({time=timestamp(),link=link,qty=quantity,value=v,source=source or "inventory",bag=bag})
    self:Refresh()
end
-- Coalesce matching positive and negative stack movements across owned bags.
function GS:FlushInventoryDeltas()
    local pending=self.pendingInventory or {}; self.pendingInventory={}
    self.lootBatch={}
    for _,e in pairs(pending) do
        local net=e.delta
        if net>0 and e.eligible then self:TrackItem(e.link,net,e.reason,e.bag,"inventory")
        elseif net<0 and e.processing then self:TrackItem(e.link,net,e.reason,e.bag,"inventory") end
    end
    local batch=self.lootBatch;self.lootBatch=nil
    local total=0;for _,e in ipairs(batch) do total=total+(e.value or 0) end
    if #batch>0 and self.saved.showLootToast and total>0 and total>=(self.saved.minToast or 0) then
        table.sort(batch,function(a,b) return (a.value or -1)>(b.value or -1) end)
        local lines={"LOOT  +"..money(total).."g estimated"};local remainder,unknown=0,0
        for i,e in ipairs(batch) do
            if i<=5 then lines[#lines+1]=(self:CleanName(call(GetItemLinkName,e.link)) or "Item").." x"..e.qty.." | "..(e.value and money(e.value).."g" or "Unpriced")
            else remainder=remainder+(e.value or 0);if not e.value then unknown=unknown+1 end end
        end
        if #batch>5 then lines[#lines+1]="... +"..money(remainder).."g for items not shown"..(unknown>0 and (" ("..unknown.." unpriced)") or "") end
        self:Toast(table.concat(lines,"\n"))
    end
end
function GS:OnInventory(_,bag,slot,isNew,_,updateReason,stackCountChange)
    if not self.saved or not self.saved.tracking then return end
    local owned=bag==BAG_BACKPACK or bag==BAG_VIRTUAL or bag==BAG_BANK or bag==BAG_SUBSCRIBER_BANK
    if not owned then return end
    self.slotLinks=self.slotLinks or {}; self.pendingInventory=self.pendingInventory or {}
    local key=tostring(bag)..":"..tostring(slot)
    local link=call(GetItemLink,bag,slot,LINK_STYLE_DEFAULT)
    local delta=tonumber(stackCountChange) or 0
    if not link or link=="" then link=self.slotLinks[key]; self.slotLinks[key]=nil else self.slotLinks[key]=link end
    if not link or delta==0 then return end
    local id=link
    local e=self.pendingInventory[id] or {link=link,delta=0}
    e.delta=e.delta+delta
    if delta>0 and (bag==BAG_BACKPACK or bag==BAG_VIRTUAL) then e.eligible=true; e.bag=bag; e.reason=updateReason end
    e.processing=e.processing or clockms()<(self.craftWindow.expires or 0)
    self.pendingInventory[id]=e
    EVENT_MANAGER:UnregisterForUpdate(self.name.."_stack_batch")
    EVENT_MANAGER:RegisterForUpdate(self.name.."_stack_batch",250,function() EVENT_MANAGER:UnregisterForUpdate(self.name.."_stack_batch"); self:FlushInventoryDeltas() end)
end
-- Use the same wallet source as ESO's merchant interface, with a safe fallback.
function GS:ReadWallet()
    local n=call(GetCurrentMoney)
    if type(n)=="number" then return n end
    if GetCurrencyAmount and CURT_MONEY and CURRENCY_LOCATION_CHARACTER then
        n=call(GetCurrencyAmount,CURT_MONEY,CURRENCY_LOCATION_CHARACTER)
    end
    return type(n)=="number" and n or nil
end
function GS:CategorizeWalletRecord(record,kind)
    if not record or record.vendorCategorized then return end
    local amount=tonumber(record.qty) or 0
    if kind=="vendor sale" and amount>0 then
        self.session.vendorSales=(self.session.vendorSales or 0)+amount
        self.session.otherIncome=math.max(0,(self.session.otherIncome or 0)-amount)
    elseif kind=="vendor purchase" and amount<0 then
        self.session.vendorPurchases=(self.session.vendorPurchases or 0)-amount
        self.session.otherSpent=math.max(0,(self.session.otherSpent or 0)+amount)
    else return end
    record.source=kind
    record.vendorCategorized=true
end
-- A bank transfer changes location, not owned gold. Never substitute zero
-- for an unavailable bank balance, which would fabricate a cash transaction.
function GS:ReadOwnedGold()
    local c=self:ReadCurrencies()
    if type(c.carried)~="number" or type(c.banked)~="number" then return nil end
    return c.carried+c.banked
end
function GS:ScheduleMoneyUpdate()
    self.moneyToken=(self.moneyToken or 0)+1
    local token=self.moneyToken
    self.moneyPending=true
    if zo_callLater then
        zo_callLater(function()
            if self.moneyToken==token then
                self.moneyPending=false
                self:OnMoneyUpdate()
            end
        end,500)
    else
        self.moneyPending=false
        self:OnMoneyUpdate()
    end
end
function GS:OnMoneyUpdate()
    if self.moneyPending then return end
    local current=self:ReadOwnedGold()
    if current==nil then self.wallet=nil; return end
    if self.wallet~=nil and self.saved and self.saved.tracking then
        local change=current-self.wallet
        if change~=0 then
            local source=change>0 and "other income" or "other spending"
            local receipt=self.pendingVendorReceipt
            if receipt and clockms()-(receipt.at or 0)<=2500 and
                ((receipt.kind=="vendor sale" and change>0) or
                 (receipt.kind=="vendor purchase" and change<0)) then
                source=receipt.kind
                self.pendingVendorReceipt=nil
            end
            if change>0 then
                self.session.rawIn=self.session.rawIn+change
                self.saved.lifetimeRawIn=(self.saved.lifetimeRawIn or 0)+change
                if source=="other income" then self.session.otherIncome=self.session.otherIncome+change end
            else
                self.session.rawOut=self.session.rawOut-change
                self.saved.lifetimeRawOut=(self.saved.lifetimeRawOut or 0)-change
                if source=="other spending" then self.session.otherSpent=self.session.otherSpent-change end
            end
            local record={time=timestamp(),at=clockms(),source=source,qty=change,value=math.abs(change),wallet=true}
            self:AddHistory(record)
            if source=="vendor sale" or source=="vendor purchase" then
                self:CategorizeWalletRecord(record,source)
            end
            self.lastWalletRecord=record
        end
    end
    self.wallet=current
    self:Refresh()
end
function GS:OnVendorReceipt(kind)
    -- Receipt callbacks give us a reliable transaction type, while wallet
    -- deltas remain the authoritative source for gold amounts. Do not add the
    -- receipt amount separately, which would count the same gold twice.
    self:OnMoneyUpdate()
    local recent=self.lastWalletRecord
    if not self.moneyPending and recent and clockms()-(recent.at or 0)<=2500 and not recent.vendorCategorized and
        ((kind=="vendor sale" and (recent.qty or 0)>0) or
         (kind=="vendor purchase" and (recent.qty or 0)<0)) then
        self:CategorizeWalletRecord(recent,kind)
        self:Refresh()
        return
    end
    self.pendingVendorReceipt={kind=kind,at=clockms()}
    -- A delayed read catches currencies that settle after the receipt event.
    if zo_callLater then
        zo_callLater(function() if self.initialized then self:OnMoneyUpdate() end end,250)
    end
end
function GS:OnCraftComplete()
    -- A craft event precedes or accompanies inventory deltas; attribute outputs
    -- only for a short window. Never claim a guaranteed material result.
    self.craftWindow={expires=clockms()+1800,source="craft / deconstruct / refine"}
end
function GS:ListInventory()
    local result,total,unknown={ },0,0
    local bags={BAG_BACKPACK}
    if BAG_VIRTUAL then bags[#bags+1]=BAG_VIRTUAL end
    for _,bag in ipairs(bags) do
        self:ForEachValuableBagSlot(bag,function(slot,link,qty)
            if self:IsSlotMarketable(bag,slot,link)==true then
                local value,unit=self:Estimate(link,qty)
                if value then
                    result[#result+1]={link=link,quantity=qty,value=value,unit=unit}
                    total=total+value
                else unknown=unknown+1 end
            end
        end)
    end
    table.sort(result,function(a,b) return a.value>b.value end)
    return result,total,unknown
end
function GS:OwnListings()
    if not GetNumTradingHouseListings then return nil,"Listing API unavailable" end
    local n=call(GetNumTradingHouseListings)
    if type(n)~="number" then return nil,"Open the trading-house listings tab first" end
    local list={}
    for i=1,n do
        local icon,name,quality,qty,seller,remaining,asking=call(GetTradingHouseListingItemInfo,i)
        local link=call(GetTradingHouseListingItemLink,i,LINK_STYLE_DEFAULT)
        if link and type(asking)=="number" then
            local market=self:Estimate(link,qty or 1)
            list[#list+1]={link=link,name=name,qty=qty or 1,asking=asking,market=market,remaining=remaining}
        end
    end
    self.saved.listings=list
    self.saved.listingUpdated=timestamp()
    self:Refresh()
    return #list
end
function GS:ScanPersonalSales()
    -- Reads already cached Guild History pages; does not request server history.
    -- This does not imply complete coverage of past sales.
    if type(GetGuildHistoryEventIndicesForTimeRange)~="function" or
       type(GetGuildHistoryTraderEventInfo)~="function" or
       not GUILD_HISTORY_EVENT_CATEGORY_TRADER then
        return nil,"Guild sales history API unavailable"
    end
    local display=call(GetUnitDisplayName,"player")
    if not display then return nil,"Player display name unavailable" end
    local scanned,added=0,0
    local guildCount=call(GetNumGuilds) or 0
    self.saved.sales=self.saved.sales or {}
    self.saved.salesSeen=self.saved.salesSeen or {}
    for guildIndex=1,guildCount do
        local guildId=call(GetGuildId,guildIndex)
        if guildId then
            local newest,oldest=call(GetGuildHistoryEventIndicesForTimeRange,guildId,
                GUILD_HISTORY_EVENT_CATEGORY_TRADER,timestamp(),timestamp()-30*86400)
            if type(newest)=="number" and type(oldest)=="number" then
                local lo,hi=math.min(newest,oldest),math.max(newest,oldest)
                for index=hi,math.max(lo,hi-399),-1 do
                    local id,ts,redacted,typ,seller,buyer,link,qty,price,tax=
                        call(GetGuildHistoryTraderEventInfo,guildId,index)
                    scanned=scanned+1
                    if id and not redacted and typ==GUILD_HISTORY_TRADER_EVENT_ITEM_SOLD
                        and seller==display and type(price)=="number" and not self.saved.salesSeen[tostring(id)] then
                        self.saved.salesSeen[tostring(id)]=true
                        table.insert(self.saved.sales,1,{id=id,ts=ts,guildId=guildId,link=link,
                            qty=qty or 1,price=price,tax=tax or 0})
                        added=added+1
                    end
                end
            end
        end
    end
    table.sort(self.saved.sales,function(a,b)return (a.ts or 0)>(b.ts or 0) end)
    while #self.saved.sales>500 do table.remove(self.saved.sales) end
    self.saved.salesScanTime=timestamp()
    self:Refresh()
    return added,"Read "..scanned.." cached guild-history events; "..added.." new personal sales."
end
function GS:SalesSummary()
    local count,gross,net=0,0,0
    for _,s in ipairs(self.saved.sales or {}) do
        count=count+1;gross=gross+(s.price or 0);net=net+(s.price or 0)-(s.tax or 0)
    end
    return count,gross,net
end
function GS:ResetTrader(reason)
    self.scan={active=false, pending=false, token=(self.scan and (self.scan.token or 0)+1 or 1),
        nextPage=0, attempts=0, finished=false, lastPage=-1}
    self.market={trader="Unidentified trader",guildId=0,items={},byKey={},pages={},pageCount=0,
        hasMore=nil,updated=0,session=timestamp(),message=reason or "Open a guild trader and search."}
    self:Refresh()
end
function GS:TraderInfo()
    local id,name=call(GetCurrentTradingHouseGuildDetails)
    if type(name)=="string" and name~="" then return name,id end
    if type(id)=="string" and id~="" then return id,0 end
    return "Visited guild trader",id or 0
end
function GS:AnalyzeFlip(row)
    if not row.unit or row.unit<=0 or not row.asking or row.asking<=0 then return end
    row.market=row.unit*row.qty*(self.saved.marketMultiplier/100)
    row.profit=row.market*(1-self.saved.resaleFee/100)-row.asking
    row.roi=100*row.profit/row.asking
    row.discount=100*(1-row.asking/row.market)
    row.qualifies=(row.profit>=self.saved.minProfit and row.roi>=self.saved.minROI)
end
function GS:AnalyzeAllFlips()
    for _,row in ipairs(self.market.items) do self:AnalyzeFlip(row) end
    self:Refresh()
end
function GS:CaptureTraderResults()
    if not self.saved then return 0 end
    local count,page,more=call(GetTradingHouseSearchResultsInfo)
    if type(count)~="number" or count<0 then
        self.market.message="No results returned by trader yet."
        self:UpdateFlipPopup()
        return 0
    end
    local trader,id=self:TraderInfo()
    if id and id~=0 and self.market.guildId~=0 and id~=self.market.guildId then
        self:ResetTrader("New trader detected.")
    end
    self.market.guildId=id or 0
    self.market.trader=trader
    local p=tonumber(page) or 0
    self.market.pages[p]=true
    self.market.hasMore=more
    self.market.updated=timestamp()
    local added,skipped,priced=0,0,0
    for i=1,count do
        local icon,name,quality,qty,seller,remaining,asking=call(GetTradingHouseSearchResultItemInfo,i)
        local link=call(GetTradingHouseSearchResultItemLink,i,LINK_STYLE_DEFAULT)
        if link and link~="" and type(asking)=="number" and asking>0 then
            qty=math.max(1,tonumber(qty) or 1)
            local unit=self:GetPrice(link)
            if unit then priced=priced+1 end
            local key=tostring(p).."/"..tostring(i).."/"..link.."/"..tostring(asking)
            if not self.market.byKey[key] then
                local row={link=link,name=name,qty=qty,asking=asking,unit=unit,
                    seller=seller,page=p,remaining=remaining}
                self:AnalyzeFlip(row)
                self.market.items[#self.market.items+1]=row
                self.market.byKey[key]=true
                added=added+1
            end
        else skipped=skipped+1 end
    end
    self.market.message="PAGE "..(p+1)..": "..count.." results, "..added.." new, "..priced.." priced, "..skipped.." unavailable."
    self:Refresh()
    self:UpdateFlipPopup()
    return added,p,more,count
end

-- Physical-trader automatic scan. No remote scan or unsupported merchant enumeration.
-- Each page request is rate-limited, and a token cancels stale responses when leaving.
function GS:QueueTraderSearch(page, token)
    if not self.openTrader or not self.scan or token~=self.scan.token or not self.scan.active then return end
    if self.scan.pending then return end
    if type(ExecuteTradingHouseSearch)~="function" then
        self:FinishTraderScan("ESO search API not available; captured pages only.")
        return
    end
    local remain=call(GetTradingHouseCooldownRemaining)
    if type(remain)=="number" and remain>0 then
        -- ESO explicitly returns milliseconds, never guess seconds.
        local wait=math.max(250,math.min(30000,remain+350))
        self.market.message="Trader cooldown: "..string.format("%.1f",remain/1000).."s; next page queued."
        self:UpdateFlipPopup()
        if zo_callLater then zo_callLater(function() self:QueueTraderSearch(page,token) end,wait) end
        return
    end
    local sort=TRADING_HOUSE_SORT_SALE_PRICE
    if type(sort)~="number" then
        self:FinishTraderScan("Missing trader sort constant; browse pages manually.")
        return
    end
    if self.scan.requestPage~=page then self.scan.attempt=0 end
    self.scan.pending=true
    self.scan.requestPage=page
    self.scan.requestStarted=clockms()
    self.scan.attempt=(self.scan.attempt or 0)+1
    self.market.message="Scanning guild trader: requesting page "..(page+1).."..."
    self:UpdateFlipPopup()
    local ok,err=pcall(ExecuteTradingHouseSearch,page,sort,true,false)
    if not ok then
        self.scan.pending=false
        self:FinishTraderScan("Trader search rejected: "..tostring(err))
        return
    end
    -- Console trade searches can deliver results late, without a matching
    -- event callback. Poll the official results info before retrying.
    if zo_callLater then zo_callLater(function()
        if not (self.openTrader and self.scan and self.scan.token==token and self.scan.pending and self.scan.requestPage==page) then return end
        local count,actualPage=call(GetTradingHouseSearchResultsInfo)
        if type(count)=="number" and count>0 and tonumber(actualPage)==page then
            self.scan.pending=false
            self.scan.attempt=0
            self:AdvanceTraderResults(token,page)
            return
        end
        self.scan.pending=false
        local attempt=self.scan.attempt or 1
        if attempt<3 then
            self.market.message="No page "..(page+1).." response; retry "..attempt.."/2..."
            self:UpdateFlipPopup()
            zo_callLater(function() self:QueueTraderSearch(page,token) end,1250)
        else
            self:FinishTraderScan("PARTIAL: page "..(page+1).." did not respond (3 attempts). "..self:PageCount().." pages retained. Try a normal trader search to capture more.")
        end
    end,9000) end

end
function GS:FinishTraderScan(message)
    if not self.scan then return end
    self.scan.active=false;self.scan.pending=false;self.scan.finished=true
    self.market.message=message or ("Scan complete: "..#self.market.items.." listings on "..self:PageCount().." pages.")
    self:UpdateFlipPopup()
    self:Refresh()
end
function GS:BeginTraderScan()
    self.openTrader=true
    self:ResetTrader("Trader opened; preparing automatic scan...")
    self.scan.active=self.saved.autoFlipScan~=false
    self:ShowFlipPopup()
    self:UpdateFlipPopup()
    if not self.scan.active then
        self.market.message="Automatic scan disabled in settings."
        self:UpdateFlipPopup()
        return
    end
    local token=self.scan.token
    if zo_callLater then
        zo_callLater(function() self:QueueTraderSearch(0,token) end,850)
    else self:QueueTraderSearch(0,token) end
end
function GS:AdvanceTraderResults(token,requestedPage)
    if not self.openTrader or not self.scan or self.scan.token~=token then return end
    local count,p,hasMore=self:CaptureTraderResults()
    if not self.scan.active then return end
    if requestedPage~=nil and p~=requestedPage then
        self:FinishTraderScan("PARTIAL: another search changed the trader results; captured "..self:PageCount().." pages.")
        return
    end
    if hasMore and (p+1)<math.min(self.saved.autoScanPages or 12,40) then
        local nextPage=p+1
        if zo_callLater then zo_callLater(function() self:QueueTraderSearch(nextPage,token) end,850) end
    else
        local clipped=hasMore and "PARTIAL: page limit reached; increase max pages in Settings." or nil
        self:FinishTraderScan(clipped)
    end
end
function GS:OnTraderSearchResults()
    -- ESO delivers asynchronous results. Only advance the scan when the
    -- observed page corresponds to the page we requested.
    local token=self.scan and self.scan.token
    local function read(attempt)
        if not self.openTrader or not self.scan or self.scan.token~=token then return end
        local count,page=call(GetTradingHouseSearchResultsInfo)
        if (type(count)~="number" or (count>0 and not call(GetTradingHouseSearchResultItemLink,1,LINK_STYLE_DEFAULT))) and attempt<5 then
            if zo_callLater then zo_callLater(function() read(attempt+1) end,200) end
            return
        end
        if type(count)~="number" then
            self.market.message="Trader results not accessible yet; awaiting response."
            self:UpdateFlipPopup()
            return
        end
        local pending=self.scan.pending
        local requested=self.scan.requestPage
        if pending and tonumber(page)==requested then
            self.scan.pending=false
            self.scan.attempt=0
            self:AdvanceTraderResults(token,requested)
        elseif not pending then
            -- Native browsing can still provide extra searchable pages.
            self:CaptureTraderResults()
        else
            self.market.message="Waiting for requested page "..(requested+1).."; trader currently shows page "..((tonumber(page) or -1)+1).."."
            self:UpdateFlipPopup()
        end
    end
    if zo_callLater then zo_callLater(function() read(1) end,180) else read(1) end
end

function GS:BestFlips()
    local ranked={}
    for _,r in ipairs(self.market.items) do if r.qualifies then ranked[#ranked+1]=r end end
    table.sort(ranked,function(a,b)
        if a.profit==b.profit then return a.roi>b.roi end
        return a.profit>b.profit
    end)
    return ranked
end
function GS:PageCount()
    local n=0; for _ in pairs(self.market.pages) do n=n+1 end
    return n
end
function GS:Refresh() if self.RefreshUI then self:RefreshUI() end end
function GS:Toast(msg) if self.ShowToast then self:ShowToast(msg) end end
function GS:Initialize()
    if self.initialized then return end
    self.initialized=true
    self.saved=ZO_SavedVars:NewAccountWide("NexusGoldSaved",1,nil,self.defaults)
    self.saved.history=self.saved.history or {}
    self.saved.sales=self.saved.sales or {}
    self.saved.salesSeen=self.saved.salesSeen or {}
    self.saved.listings=self.saved.listings or {}
    self.saved.empireSnapshots=self.saved.empireSnapshots or {}
    self.saved.lifetimeFound=self.saved.lifetimeFound or 0
    self.saved.lifetimeRawIn=self.saved.lifetimeRawIn or 0
    self.saved.lifetimeRawOut=self.saved.lifetimeRawOut or 0
    self:ResetSession(true)
    self:ResetTrader()
    self.wealthSnapshot=nil
    self.wallet=self:ReadOwnedGold()
    self:InitializeUI()
    self:RegisterStartMenuVisibility()
    self:InitializeSettings()
    EVENT_MANAGER:RegisterForEvent(self.name.."_items",EVENT_INVENTORY_SINGLE_SLOT_UPDATE,function(...) self:OnInventory(...); self:InvalidateWealth(select(2,...)) end)
    if EVENT_MONEY_UPDATE then EVENT_MANAGER:RegisterForEvent(self.name.."_cash",EVENT_MONEY_UPDATE,function() self:ScheduleMoneyUpdate() end) end
    if EVENT_CURRENCY_UPDATE then
        EVENT_MANAGER:RegisterForEvent(self.name.."_currency",EVENT_CURRENCY_UPDATE,
            function(_,currencyType)
                if currencyType==CURT_MONEY then
                    self:ScheduleMoneyUpdate()
                elseif currencyType==CURT_ALLIANCE_POINTS or currencyType==CURT_TELVAR_STONES then
                    self:ScheduleCurrencyReconcile()
                end
            end)
    end
    if EVENT_SELL_RECEIPT then
        EVENT_MANAGER:RegisterForEvent(self.name.."_vendor_sell",EVENT_SELL_RECEIPT,function() self:OnVendorReceipt("vendor sale") end)
    end
    if EVENT_BUY_RECEIPT then
        EVENT_MANAGER:RegisterForEvent(self.name.."_vendor_buy",EVENT_BUY_RECEIPT,function() self:OnVendorReceipt("vendor purchase") end)
    end
    -- Some cash changes may be missed by a UI event, especially across screens;
    -- polling only the wallet balance is inexpensive and does not double-count.
    if EVENT_MANAGER.RegisterForUpdate then
        EVENT_MANAGER:RegisterForUpdate(self.name.."_wallet_reconcile",1000,function() self:OnMoneyUpdate() end)
        EVENT_MANAGER:RegisterForUpdate(self.name.."_currency_reconcile",1000,function()
            -- If a transfer event is pending, let its debounce finish first.
            if not self.currencyReconcileToken or not self.currencyScanPending then
                self:ReconcileEarnedCurrencies()
            end
        end)
        EVENT_MANAGER:RegisterForUpdate(self.name.."_wealth_refresh",60000,function()
            if self.saved.showWealthHUD then self:ScanWealth(false);self:Refresh() end
        end)
    end
    if EVENT_CRAFT_COMPLETED then EVENT_MANAGER:RegisterForEvent(self.name.."_craft",EVENT_CRAFT_COMPLETED,function() self:OnCraftComplete() end) end
    if EVENT_TRADING_HOUSE_SEARCH_RESULTS_RECEIVED then
        EVENT_MANAGER:RegisterForEvent(self.name.."_search",EVENT_TRADING_HOUSE_SEARCH_RESULTS_RECEIVED,
            function(...) self:OnTraderSearchResults() end)
    end
    if EVENT_OPEN_TRADING_HOUSE then
        EVENT_MANAGER:RegisterForEvent(self.name.."_open",EVENT_OPEN_TRADING_HOUSE,function() self:BeginTraderScan() end)
    end
    if EVENT_CLOSE_TRADING_HOUSE then
        EVENT_MANAGER:RegisterForEvent(self.name.."_close",EVENT_CLOSE_TRADING_HOUSE,function()
            self.openTrader=false
            if self.scan then
                self.scan.active=false
                self.scan.pending=false
                self.scan.token=self.scan.token+1 -- invalidate delayed requests
            end
            self:HideFlipPopup()
        end)
    end
    SLASH_COMMANDS["/goldstandard"]=function(arg)
        arg=(arg or ""):lower()
        if arg=="reset" then self:ResetSession()
        elseif arg=="tracker" then self:ShowPanel("tracker")
        elseif arg=="advisor" then self:ShowPanel("advisor")
        elseif arg=="flip" or arg=="trader" then self:ShowPanel("flip")
        elseif arg=="settings" then self:ShowPanel("settings")
        elseif arg=="sales" then self:ShowPanel("sales")
        elseif arg=="empire" then self:ShowPanel("empire")
        elseif arg=="scan" then self:CaptureTraderResults()
        elseif arg=="move" or arg=="layout" then self:StartLayoutPreview()
        elseif arg=="prices" then self:Print("Pricing: "..self:VersionCheck())
        else self:TogglePanel() end
    end
    SLASH_COMMANDS["/gs"]=SLASH_COMMANDS["/goldstandard"]
    self:Print("v"..self.version.." loaded. "..self:VersionCheck()..". Open via Add-Ons or /gs")
    self:Refresh()
end
EVENT_MANAGER:RegisterForEvent("GoldStandard_Load",EVENT_ADD_ON_LOADED,function(_,name)
    if name~="TMENexus" then return end
    EVENT_MANAGER:UnregisterForEvent("GoldStandard_Load",EVENT_ADD_ON_LOADED)
    GS:Initialize()
end)
