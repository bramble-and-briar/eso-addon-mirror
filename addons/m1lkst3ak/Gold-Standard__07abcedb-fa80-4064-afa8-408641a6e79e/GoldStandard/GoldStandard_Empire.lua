-- Gold Standard Empire | Account-wide valuation report and historical snapshots.
-- A valuation of current holdings, not a cumulative sum of loot ever acquired.
local GS=GoldStandard
local GOLD="|cE8BC63"
local GREEN="|c8EDBAD"
local MUTED="|cB9C4D1"
local END="|r"
local function get(fn,...)
    if type(fn)~="function" then return nil end
    local ok,v=pcall(fn,...)
    if ok then return v end
    return nil
end
local function num(n) return math.floor((tonumber(n) or 0)+.5) end
local function when(t)
    if not t or t<=0 then return "unknown" end
    return (os and os.date and os.date("%Y-%m-%d %H:%M",t)) or tostring(t)
end
function GS:BuildEmpire(force)
    local now=get(GetTimeStamp) or 0
    if not force and self.empireCache and now-(self.empireCache.timestamp or 0)<90 then return self.empireCache end
    local r={timestamp=now, categories={},assets={},unpricedSlots=0,boundSlots=0,access={},unknownBags=0}
    local categories={
        {"Backpack",BAG_BACKPACK},{"Bank",BAG_BANK},{"Bank (subscriber)",BAG_SUBSCRIBER_BANK},
        {"Craft Bag",BAG_VIRTUAL},{"Furnishing Vault",BAG_FURNITURE_VAULT},
    }
    local total=0
    for _,item in ipairs(categories) do
        local title,bag=item[1],item[2]
        local cat={name=title,value=0,items=0,unpriced=0,excluded=0,available=false}
        r.categories[#r.categories+1]=cat
        -- Account-wide bags may not be readable in every scene. Never turn unknown into zero wealth.
        cat.available=self:ForEachValuableBagSlot(bag,function(slot,link,qty)
            local eligible,reason=self:IsSlotMarketable(bag,slot,link)
            if eligible~=true then
                cat.excluded=cat.excluded+1
                r.boundSlots=r.boundSlots+1
                if eligible==nil then r.unknownBindingSlots=(r.unknownBindingSlots or 0)+1 end
            else
                local value=self:Estimate(link,qty)
                if type(value)=="number" then
                    cat.value=cat.value+value
                    cat.items=cat.items+qty
                    local name=get(GetItemLinkName,link) or link
                    r.assets[#r.assets+1]={link=link,name=name,qty=qty,value=value,category=title}
                else
                    cat.unpriced=cat.unpriced+1
                    r.unpricedSlots=r.unpricedSlots+1
                end
            end
        end)
        if cat.available then total=total+cat.value end
        if not cat.available then r.unknownBags=r.unknownBags+1 end
    end
    table.sort(r.assets,function(a,b) return a.value>b.value end)
    local wallet=self:ReadCurrencies()
    r.gold=(wallet.carried or 0)+(wallet.banked or 0)
    r.goldKnown=wallet.carried~=nil and wallet.banked~=nil
    r.itemsValue=total
    local listings=self.saved.listings or {}
    r.listingMarket=0;r.listingAsk=0;r.listingUnknown=0;r.listingCount=#listings
    for _,l in ipairs(listings) do
        r.listingAsk=r.listingAsk+(tonumber(l.asking) or 0)
        if type(l.market)=="number" then r.listingMarket=r.listingMarket+l.market
        else r.listingUnknown=r.listingUnknown+1 end
    end
    r.listingTime=self.saved.listingUpdated or 0
    r.ap=wallet.ap
    r.tel=wallet.telVar
    local ap=self:APConversion(wallet.ap)
    local tel=self:TelVarConversion(wallet.telVar)
    r.apValue=ap and ap.gross or nil
    r.telValue=tel and tel.gross or nil
    r.apCount=ap and ap.count or 0
    r.telCount=tel and tel.count or 0
    -- Listed holdings are separate from backpack/bank/craft-bag; their price cache may be stale.
    r.knownTotal=r.gold+total+r.listingMarket+(r.apValue or 0)+(r.telValue or 0)
    r.missing=(not r.goldKnown) or r.unknownBags>0 or r.unpricedSlots>0 or (r.unknownBindingSlots or 0)>0 or r.listingUnknown>0 or (r.ap~=nil and not r.apValue) or (r.tel~=nil and not r.telValue)
    r.basis="Observable assets only; incomplete" 
    if not r.missing then r.basis="All queried sources priced" end
    r.wealth=self:ScanWealth(false)
    local n,gross,net=self:SalesSummary()
    r.saleCount=n or 0;r.salesGross=gross or 0;r.salesNet=net or 0
    self.empireCache=r
    return r
end
function GS:SaveEmpireSnapshot()
    local r=self:BuildEmpire(true)
    local snapshots=self.saved.empireSnapshots or {}
    self.saved.empireSnapshots=snapshots
    local e={time=r.timestamp,value=num(r.knownTotal),gold=num(r.gold),inventory=num(r.itemsValue),
        listed=num(r.listingMarket),ap=num(r.apValue),tel=num(r.telValue),
        missing=r.missing,unknownBags=r.unknownBags,unpriced=r.unpricedSlots}
    -- Retain manual observations; never silently rewrite earlier snapshots.
    if #snapshots>0 and (e.time-(snapshots[#snapshots].time or 0))<300 then
        snapshots[#snapshots]=e
    else
        snapshots[#snapshots+1]=e
    end
    while #snapshots>120 do table.remove(snapshots,1) end
    return e
end
function GS:EmpirePageRows(page)
    local r=self:BuildEmpire(false)
    local fmt=function(v) return self:Money(v or 0).."g" end
    local rows={}
    local pages={"YOUR EMPIRE","WHERE IT LIVES","CROWN JEWELS","HOW IT WAS BUILT","WHEN IT GREW","SURPLUS ASSETS"}
    page=math.max(1,math.min(6,page or 1))
    rows[1]=GOLD..pages[page]..END.."   "..MUTED.."PAGE "..page.."/6  |  L1/R1 TO EXPLORE"..END
    if page==1 then
        rows[2]=GOLD.."KNOWN EMPIRE VALUE: "..fmt(r.knownTotal)..END
        rows[3]="Liquid gold (wallet + bank): "..GREEN..fmt(r.gold)..END
        rows[4]="Sellable inventory, all readable bags: "..fmt(r.itemsValue)
        rows[5]="Guild trader listings, known TSC value: "..fmt(r.listingMarket)
        rows[6]="Converted Gold (AP): "..(r.apValue and fmt(r.apValue) or "UNPRICED")
        rows[7]="Converted Gold (Tel Var): "..(r.telValue and fmt(r.telValue) or "UNPRICED")
        rows[8]=""
        rows[9]="Estimated excess inventory within holdings: "..fmt(r.wealth.knownTotal)
        rows[10]="Unreadable bags: "..r.unknownBags.."  |  Unpriced slots: "..r.unpricedSlots
        rows[11]="Unpriced trader listings: "..r.listingUnknown.."  |  Nontradable slots excluded: "..r.boundSlots
        rows[12]=MUTED.."Observed at "..when(r.timestamp).."  |  "..r.basis..END
    elseif page==2 then
        rows[2]=GOLD.."WHERE YOUR WEALTH LIVES"..END
        rows[3]="Liquid gold: "..fmt(r.gold)
        for i,c in ipairs(r.categories) do
            rows[i+3]=c.name..": "..(c.available and fmt(c.value) or "NOT READABLE").."  "..MUTED.."unpriced "..c.unpriced..END
        end
        rows[9]="Listed at guild traders: "..fmt(r.listingMarket).."  ("..r.listingCount.." items)"
        rows[10]="Converted Gold (AP): "..(r.apValue and fmt(r.apValue) or "Unavailable")
        rows[11]="Converted Gold (Tel Var): "..(r.telValue and fmt(r.telValue) or "Unavailable")
        rows[12]=""
    elseif page==3 then
        rows[2]=GOLD.."YOUR MOST VALUABLE HOLDINGS"..END
        for i=1,8 do
            local a=r.assets[i]
            if a then rows[i+2]=i..". "..a.name.." x"..a.qty.."  "..GREEN..fmt(a.value)..END.."  "..MUTED..a.category..END
            else rows[i+2]="" end
        end
        rows[11]="Known surplus materials and furnishings: "..fmt(r.wealth.knownTotal)
        rows[12]=MUTED.."Rankings are TSC estimates; nontradable and unpriced items excluded."..END
    elseif page==4 then
        rows[2]=GOLD.."YOUR FINANCIAL ENGINE"..END
        rows[3]="Recorded lifetime loot value: "..fmt(self.saved.lifetimeFound)
        rows[4]="Recorded lifetime wallet inflows: "..fmt(self.saved.lifetimeRawIn)
        rows[5]="Recorded lifetime wallet outflows: "..fmt(self.saved.lifetimeRawOut)
        rows[6]="Cached completed guild-trader sales: "..r.saleCount
        rows[7]="Cached guild-trader gross revenue: "..fmt(r.salesGross)
        rows[8]="Cached guild-trader net receipts: "..fmt(r.salesNet)
        rows[9]="Current session estimated gold/hour: "..fmt(self:NetPerHour()).."/h"
        rows[10]="Currently listed at trader (asking): "..fmt(r.listingAsk)
        rows[11]="Listing cache last refreshed: "..when(r.listingTime)
        rows[12]=""
    elseif page==5 then
        local snapshots=self.saved.empireSnapshots or {}
        rows[2]=GOLD.."YOUR EMPIRE THROUGH TIME"..END
        rows[3]="Current observed wealth: "..fmt(r.knownTotal)
        rows[4]="Snapshots recorded: "..#snapshots.."  |  First: "..(#snapshots>0 and when(snapshots[1].time) or "none")
        local a=snapshots[1]
        if a then
            rows[5]="First measured value: "..fmt(a.value)
            rows[6]="Observed change since first: "..fmt(r.knownTotal-a.value)
        else
            rows[5]="No historic readings yet."
            rows[6]="Select REFRESH & SAVE SNAPSHOT to begin your empire timeline."
        end
        for j=1,5 do
            local b=snapshots[#snapshots-j+1]
            if b then
                rows[j+6]=when(b.time).."  "..fmt(b.value)..(b.missing and "  *partial*" or "")
            end
        end
        rows[12]=""
    else
        local w=r.wealth
        rows[2]=GOLD.."YOUR SELLABLE SURPLUS: "..fmt(w.knownTotal)..END
        rows[3]="Craft Bag above "..self.saved.wealthMaterialKeep..": "..fmt(w.matGold).." ("..self:Money(w.matExcess).." excess)"
        rows[4]="Furnishings above "..self.saved.wealthFurnitureKeep..": "..fmt(w.furnitureGold).." ("..self:Money(w.furnitureExcess).." extra)"
        rows[5]="Unpriced surplus types: "..(w.unpriced or 0)
        rows[6]=GOLD.."MOST VALUABLE SURPLUS ITEMS"..END
        local holdings={}
        for _,a in ipairs(w.materials or {}) do if type(a.value)=="number" then holdings[#holdings+1]=a end end
        for _,a in ipairs(w.furnishings or {}) do if type(a.value)=="number" then holdings[#holdings+1]=a end end
        table.sort(holdings,function(a,b) return a.value>b.value end)
        for i=1,6 do
            local a=holdings[i]
            if a then
                local name=get(GetItemLinkName,a.link) or a.link or "Item"
                rows[i+6]=i..". "..name.." x"..a.excess.."  "..GREEN..fmt(a.value)..END
            end
        end
    end
    return rows,"L2/R2: TABS  |  L1/R1: EMPIRE CHAPTERS  |  X: REFRESH & SAVE  |  CIRCLE: BACK"
end
