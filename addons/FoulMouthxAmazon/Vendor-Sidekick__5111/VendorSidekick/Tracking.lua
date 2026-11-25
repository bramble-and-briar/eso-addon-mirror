local V=VendorSidekick
local M=V.Model
local EM=EVENT_MANAGER
local function Now()return GetFrameTimeMilliseconds()end
local function Prune(list)
 for i=#list,1,-1 do if Now()-list[i].at>10000 then table.remove(list,i)end end
end
function V.ReadItem(slot)
 local link=GetItemLink(BAG_BACKPACK,slot,LINK_STYLE_DEFAULT);if not link or link=="" then return nil end
 local _,quantity,price,_,locked,_,_,quality=GetItemInfo(BAG_BACKPACK,slot)
 if not quantity or quantity<=0 then return nil end
 local uid=GetItemUniqueId(BAG_BACKPACK,slot)
 return {slot=slot,link=link,name=M.Clean(GetItemName(BAG_BACKPACK,slot)),itemId=GetItemLinkItemId(link),uid=uid and Id64ToString(uid) or link,
  quantity=quantity,price=GetItemSellValueWithBonuses and GetItemSellValueWithBonuses(BAG_BACKPACK,slot) or price or 0,
  launderPrice=GetItemLaunderPrice(BAG_BACKPACK,slot),stolen=IsItemStolen(BAG_BACKPACK,slot),junk=IsItemJunk(BAG_BACKPACK,slot),locked=locked or IsItemPlayerLocked(BAG_BACKPACK,slot),quality=quality or 0}
end
function V.Snapshot()
 V.cache={};for slot=0,GetBagSize(BAG_BACKPACK)-1 do V.cache[slot]=V.ReadItem(slot)end
end
function V.Exclusion(item)
 if not item then return "Missing item" end
 if item.stolen then return "Stolen - manual only" end
 if item.locked then return "Locked" end
 if not item.junk then return "Not marked junk" end
 if (item.price or 0)<=0 then return "No vendor value" end
 if V.db.keep[tostring(item.itemId)] then return "Keep list" end
 if V.db.settings.protectPurple and item.quality>=ITEM_QUALITY_ARTIFACT then return "Purple/gold protection" end
 return nil
end
function V.Preview()
 local list={};for slot=0,GetBagSize(BAG_BACKPACK)-1 do local item=V.ReadItem(slot);if item and item.junk then item.exclusion=V.Exclusion(item);list[#list+1]=item end end
 return list
end
function V.Session(fence)
 if not V.current then
  V.visitId=(V.visitId or 0)+1
  local name=M.Clean(GetUnitName("interact"));if name=="" then name="Unknown vendor"end
  V.current={id=GetTimeStamp()..":"..V.visitId,vendorName=name,count=0,items=0,vendor=0,fence=0,launder=0,buyback=0}
 end
 if fence then V.fence=true end
 return V.current
end
local function Context(session)
 return session and {id=session.id,vendor=session.vendorName,totals=session} or {vendor="Unknown vendor"}
end
local function Record(kind,item,quantity,gold,context,auto)
 local row=M.Add(kind,item,quantity,gold,context,auto)
 if context and context.totals then local t=context.totals;t.count=t.count+1;t.items=t.items+(quantity or 0);t[kind]=t[kind]+(gold or 0);if gold==nil then t.unconfirmed=(t.unconfirmed or 0)+1 end end
 return row
end
function V.Capture(kind,bag,slot,quantity,automatic)
 if bag~=BAG_BACKPACK then return end
 local item=V.cache[slot] or V.ReadItem(slot)
 if not item then return end
 local q=math.min(tonumber(quantity) or item.quantity,item.quantity);if q<=0 then return end
 local p={kind=kind,item=item,quantity=q,at=Now(),context=Context(V.current),automatic=automatic==true}
 if kind=="launder" then p.context=Context(V.Session(true));V.requestsLaunder[#V.requestsLaunder+1]=p
 else V.requestsSale[#V.requestsSale+1]=p end
 return p
end
function V.OnSell(name,quantity,money)
 -- Defer slightly: native post-hooks and inventory callbacks may arrive in
 -- different orders. Only this receipt creates a sale record.
 local context=Context(V.current or V.lastSession);local cleaned=M.Clean(name)
 zo_callLater(function()
  Prune(V.requestsSale);local request,index
  for i,p in ipairs(V.requestsSale)do if not p.failed and M.Clean(p.item.name):lower()==cleaned:lower() and p.quantity>=quantity then request=p;index=i;break end end
  local item,automatic=request and request.item,nil
  if request then
   context=request.context;automatic=request.automatic
   if request.quantity==quantity then table.remove(V.requestsSale,index)else request.quantity=request.quantity-quantity end
  else
   local candidate
   for _,entry in pairs(V.cache)do if entry.name:lower()==cleaned:lower() then if candidate and candidate.link~=entry.link then candidate=false;break end;candidate=entry end end
   item=candidate or {name=cleaned,link=""}
  end
  local kind=(request and request.item.stolen) and "fence" or (context.totals and context.totals.isFence) and "fence" or "vendor"
  Record(kind,item,quantity,math.max(0,money),context,automatic)
  if request then request.receiptConfirmed=true end
  V.ScheduleRender()
 end,100)
end
function V.OnBuyback(link,quantity,money)
 local item={name=GetItemLinkName(link),link=link,itemId=GetItemLinkItemId(link)}
 Record("buyback",item,quantity,math.max(0,money),Context(V.current or V.lastSession),false)
end
function V.OnLaunderResult(result)
 Prune(V.requestsLaunder)
 local request=table.remove(V.requestsLaunder,1)
 if result~=ITEM_LAUNDER_RESULT_SUCCESS then return end
 local p=request or {item={name="Laundered item (details unavailable)",link=""},context=Context(V.current or V.lastSession),at=Now()}
 p.successAt=Now();V.launderSuccess[#V.launderSuccess+1]=p
 V.MatchLaunder()
end
function V.MatchLaunder()
 Prune(V.launderCharges)
 for _,p in ipairs(V.launderSuccess)do
  if not p.finalized then
   local chargeIndex
   for i,c in ipairs(V.launderCharges)do if math.abs(c.at-p.successAt)<=5000 then chargeIndex=i;break end end
   local charge=chargeIndex and table.remove(V.launderCharges,chargeIndex)
   if charge then
    if p.row then p.row.gold=charge.gold;if p.context.totals then p.context.totals.launder=p.context.totals.launder+charge.gold;p.context.totals.unconfirmed=math.max(0,(p.context.totals.unconfirmed or 0)-1) end
    else p.row=Record("launder",p.item,p.quantity,charge.gold,p.context,false)end
    p.finalized=true;V.ScheduleRender()
   elseif not p.row and Now()-p.successAt>=1000 then
    -- Free laundering is known only if the successful request had zero cost.
    local free=p.item.launderPrice==0
    p.row=Record("launder",p.item,p.quantity,free and 0 or nil,p.context,false);p.finalized=free
   end
  end
 end
 for i=#V.launderSuccess,1,-1 do if V.launderSuccess[i].finalized or Now()-V.launderSuccess[i].successAt>10000 then table.remove(V.launderSuccess,i)end end
end
function V.OnMoney(newMoney,oldMoney,reason)
 if reason~=CURRENCY_CHANGE_REASON_VENDOR_LAUNDER or newMoney>oldMoney then return end
 V.launderCharges[#V.launderCharges+1]={at=Now(),gold=oldMoney-newMoney};V.MatchLaunder()
end
function V.UpdateFence()
 local total,used,reset=GetFenceSellTransactionInfo();local lt,lu,lr=GetFenceLaunderTransactionInfo()
 V.db.characters[V.characterId].fence={total=total,used=used,launderTotal=lt,launderUsed=lu,reset=GetTimeStamp()+math.max(reset or 0,lr or 0),seen=GetTimeStamp()}
 V.ScheduleRender()
end
function V.OpenStore(fence)
 V.open=true;local session=V.Session(fence)
 if fence then V.fence=true;session.isFence=true;V.UpdateFence();V.inFlight=nil end
 V.manualBatch=false;V.openAt=Now();V.nextSale=Now()+1000;V.paused=false;V.notice=nil;V.Snapshot();V.ScheduleRender()
end
function V.CloseStore()
 V.open=false;V.fence=false;V.inFlight=nil;V.paused=false;V.manualBatch=false
 local session=V.current;V.lastSession=session;V.current=nil
 if session then zo_callLater(function()
  if V.db.settings.receipts and session.count>0 then
   local net=session.vendor+session.fence-session.launder-session.buyback
   V.Say(string.format("%s: %d transactions | vendor %dg | fence %dg | laundering -%dg | buyback -%dg | net %dg%s",session.vendorName,session.count,session.vendor,session.fence,session.launder,session.buyback,net,(session.unconfirmed or 0)>0 and " | "..session.unconfirmed.." unconfirmed costs excluded" or ""))
  end
 end,1400)end
 V.ScheduleRender()
end
function V.Pause(message)
 V.paused=true;V.manualBatch=false;V.notice=message or "Automatic sales paused for this visit.";V.ScheduleRender()
end
function V.StartBatch()
 if not V.open then return false,"Open an ordinary merchant, then click Sell all ready junk." end
 if V.fence then return false,"Fences are tracking only. Stolen goods must be sold manually." end
 V.manualBatch=true;V.paused=false;V.nextSale=Now();V.notice="Selling all eligible ordinary junk...";V.ScheduleRender();return true
end
function V.AutoTick()
 V.MatchLaunder()
 if not V.open or V.fence or V.paused or (not V.db.settings.autoSell and not V.manualBatch)then return end
 if V.inFlight then
  local pending=V.inFlight;local live=V.ReadItem(pending.item.slot)
  -- Queue progress follows the live stack, independently of receipt spelling,
  -- receipt delay or receipt availability. Only native receipts create income.
  if not live or live.uid~=pending.item.uid or live.quantity<pending.item.quantity then
   pending.inventoryConfirmed=true;V.inFlight=nil;V.nextSale=Now()+75
  elseif Now()-pending.at>3500 then
   pending.failed=true;V.Pause("Sale inventory update not confirmed. Batch paused; use Sell all ready junk to retry.");V.inFlight=nil
  end
  if V.inFlight or V.paused then return end
 end
 if Now()<(V.nextSale or 0) then return end
 -- Re-read live state immediately before every sale: never trust a stale slot.
 for slot=0,GetBagSize(BAG_BACKPACK)-1 do
  local item=V.ReadItem(slot)
  if item and not V.Exclusion(item) then
   V.cache[slot]=item
   local p=V.Capture("sale",BAG_BACKPACK,slot,item.quantity,true);V.inFlight=p;V.autoCalling=true
   local ok,err=pcall(SellInventoryItem,BAG_BACKPACK,slot,item.quantity)
   V.autoCalling=false;V.nextSale=Now()+150
   if not ok then p.failed=true;V.inFlight=nil;V.Pause("Automatic sale unavailable: "..tostring(err))end
   return
  end
 end
 if V.manualBatch then V.manualBatch=false;V.notice="All eligible ordinary junk sold. Excluded items were kept.";V.ScheduleRender()end
 V.nextSale=Now()+500
end
function V.InitTracking()
 V.cache={};V.requestsSale={};V.requestsLaunder={};V.launderSuccess={};V.launderCharges={};V.Snapshot()
 SecurePostHook(_G,"SellInventoryItem",function(bag,slot,qty)if not V.autoCalling then V.Capture("sale",bag,slot,qty,false)end end)
 SecurePostHook(_G,"LaunderItem",function(bag,slot,qty)V.Capture("launder",bag,slot,qty,false)end)
 SecurePostHook(_G,"SellAllJunk",function()
  for slot,item in pairs(V.cache)do if item.junk then
   local exists=false;for _,p in ipairs(V.requestsSale)do if p.item.uid==item.uid and Now()-p.at<300 then exists=true end end
   if not exists then V.Capture("sale",BAG_BACKPACK,slot,item.quantity,false)end
  end end
 end)
 EM:RegisterForEvent(V.name.."Open",EVENT_OPEN_STORE,function()V.OpenStore(false)end)
 EM:RegisterForEvent(V.name.."Fence",EVENT_OPEN_FENCE,function()V.OpenStore(true)end)
 EM:RegisterForEvent(V.name.."Close",EVENT_CLOSE_STORE,V.CloseStore)
 EM:RegisterForEvent(V.name.."Deactivate",EVENT_PLAYER_DEACTIVATED,function()if V.open then V.CloseStore()end end)
 EM:RegisterForEvent(V.name.."Sell",EVENT_SELL_RECEIPT,function(_,name,qty,gold)V.OnSell(name,qty,gold)end)
 EM:RegisterForEvent(V.name.."Buyback",EVENT_BUYBACK_RECEIPT,function(_,link,qty,gold)V.OnBuyback(link,qty,gold)end)
 EM:RegisterForEvent(V.name.."Launder",EVENT_ITEM_LAUNDER_RESULT,function(_,result)V.OnLaunderResult(result)end)
 EM:RegisterForEvent(V.name.."Money",EVENT_MONEY_UPDATE,function(_,new,old,reason)V.OnMoney(new,old,reason)end)
 EM:RegisterForEvent(V.name.."FenceUpdate",EVENT_JUSTICE_FENCE_UPDATE,V.UpdateFence)
 EM:RegisterForEvent(V.name.."Inventory",EVENT_INVENTORY_SINGLE_SLOT_UPDATE,function(_,bag,slot)
  if bag==BAG_BACKPACK then V.cache[slot]=V.ReadItem(slot);if V.open then V.ScheduleRender()end end
 end)
 EM:AddFilterForEvent(V.name.."Inventory",EVENT_INVENTORY_SINGLE_SLOT_UPDATE,REGISTER_FILTER_BAG_ID,BAG_BACKPACK)
 EM:RegisterForEvent(V.name.."Failure",EVENT_STORE_FAILURE,function()if V.inFlight then V.inFlight.failed=true;V.inFlight=nil;V.Pause("Merchant rejected a sale. Queue paused for this visit.")end end)
 EM:RegisterForUpdate(V.name.."Auto",100,V.AutoTick)
end
