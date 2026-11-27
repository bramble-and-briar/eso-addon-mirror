local N=ESOHardcore;local s=N.safe
local E={index=1,sort=1,loot={},debug={}};N.economy=E
local function c() return N.hardcore.saved end
local function active() return c().active and not c().fallen end
local function own() c().ownership=c().ownership or {};return c().ownership end
local function shared() return E.db.materials end
local function add(t,k,n) t[k]=math.max(0,(t[k] or 0)+n);if t[k]==0 then t[k]=nil end end
-- Item links from loot and virtual slots can differ in display style/name.
local materialTypes={}
for _,n in ipairs({'BLACKSMITHING_RAW_MATERIAL','BLACKSMITHING_MATERIAL','BLACKSMITHING_BOOSTER','CLOTHIER_RAW_MATERIAL','CLOTHIER_MATERIAL','CLOTHIER_BOOSTER','WOODWORKING_RAW_MATERIAL','WOODWORKING_MATERIAL','WOODWORKING_BOOSTER','JEWELRYCRAFTING_RAW_MATERIAL','JEWELRYCRAFTING_MATERIAL','JEWELRYCRAFTING_BOOSTER','JEWELRYCRAFTING_RAW_BOOSTER','JEWELRY_RAW_TRAIT','JEWELRY_TRAIT','STYLE_MATERIAL','WEAPON_TRAIT','ARMOR_TRAIT','INGREDIENT','REAGENT','POTION_BASE','POISON_BASE','ENCHANTING_RUNE_ASPECT','ENCHANTING_RUNE_ESSENCE','ENCHANTING_RUNE_POTENCY','FURNISHING_MATERIAL','RAW_MATERIAL','LURE'}) do
 local v=_G['ITEMTYPE_'..n];if v then materialTypes[v]=true end
end
local function key(l)
 if type(l)~='string' or l=='' then return end
 if l:match('^mat:%d+$') then return l end
 local id=s(GetItemLinkItemId,l);local typ=s(GetItemLinkItemType,l)
 if type(id)=='number' and id>0 and materialTypes[typ] then return 'mat:'..id end
 return l:gsub('|H%d+:','|H0:'):gsub('|h.-|h$','|h|h')
end
local function virtualCount(l)
 if INVENTORY_COUNT_BAG_OPTION_CRAFT_BAG then
  local q=s(GetItemLinkInventoryCount,l,INVENTORY_COUNT_BAG_OPTION_CRAFT_BAG);if type(q)=='number' then return q end
 end
 if INVENTORY_COUNT_BAG_OPTION_BACKPACK_AND_CRAFT_BAG and INVENTORY_COUNT_BAG_OPTION_BACKPACK then
  local total=s(GetItemLinkInventoryCount,l,INVENTORY_COUNT_BAG_OPTION_BACKPACK_AND_CRAFT_BAG);local pack=s(GetItemLinkInventoryCount,l,INVENTORY_COUNT_BAG_OPTION_BACKPACK)
  if type(total)=='number' and type(pack)=='number' then return math.max(0,total-pack) end
 end
 local _,_,q=s(GetItemLinkStacks,l);return q
end
local function note(t) c().integrityNotes=c().integrityNotes or {};table.insert(c().integrityNotes,1,t);if #c().integrityNotes>30 then table.remove(c().integrityNotes) end end
local function trace(t) table.insert(E.debug,1,t);if #E.debug>18 then table.remove(E.debug) end end
local function scan(...) 
 local out={}
 for j=1,select('#',...) do
  local b=select(j,...)
  if b then
   local seen={}
   local function visit(i,data)
    if type(i)~='number' or seen[i] then return end
    local l=s(GetItemLink,b,i,LINK_STYLE_DEFAULT)
    if (not l or l=='') and type(data)=='table' then l=data.itemLink end
    local q=s(GetSlotStackSize,b,i)
    if (not q or q<=0) and type(data)=='table' then q=data.stackCount or data.stack or data.quantity end
    local k=key(l)
    if k and type(q)=='number' and q>0 then seen[i]=true;add(out,k,q);E.db.links[k]=l end
   end
   if b~=BAG_VIRTUAL then for i=0,(s(GetBagSize,b) or 0)-1 do visit(i) end
   else
    -- First iterator invocation must have zero arguments, not explicit nil.
    local i=s(GetNextVirtualBagSlotId);local walked={}
    while type(i)=='number' and i>0 and not walked[i] do walked[i]=true;visit(i);i=s(GetNextVirtualBagSlotId,i) end
    local cache=SHARED_INVENTORY and s(SHARED_INVENTORY.GetOrCreateBagCache,SHARED_INVENTORY,b)
    if type(cache)=='table' then for k,d in pairs(cache) do if type(d)=='table' then visit(d.slotIndex or d.itemId or k,d) end end end
    for i in pairs(E.virtualSlots or {}) do visit(i) end
    -- Direct link stack query is independent of virtual enumeration. Only for known links.
    for k,l in pairs(E.db.links) do
     local q=virtualCount(l)
     if type(q)=='number' and q>0 then out[k]=q end
    end
   end
  end
 end
 return out
end
local function bank() return INTERACTION_BANK and s(GetInteractionType)==INTERACTION_BANK end
local function craft() local v=s(GetCraftingInteractionType);return type(v)=='number' and v>0 and v~=CRAFTING_TYPE_INVALID end
local function snap() local p=scan(BAG_BACKPACK);local w=scan(BAG_WORN);for k,n in pairs(w) do add(p,k,n) end;local v=scan(BAG_VIRTUAL);for k,n in pairs(v) do add(p,k,n) end;return {p=p,v=v,w=w,b=scan(BAG_BANK,BAG_SUBSCRIBER_BANK)} end
local function distribute(now)
 local o=own();for k,q in pairs(o) do local virtual=now.v[k] or 0;local physical=math.max(0,(now.p[k] or 0)-virtual);local n=math.min(q,math.max(0,virtual-(shared()[k] or 0)),math.max(0,q-physical));if n>0 then add(o,k,-n);add(shared(),k,n) end end
end
local function goldSnapshot()
 local p,b
 if CURT_MONEY and CURRENCY_LOCATION_CHARACTER and CURRENCY_LOCATION_BANK then
  p=s(GetCurrencyAmount,CURT_MONEY,CURRENCY_LOCATION_CHARACTER)
  b=s(GetCurrencyAmount,CURT_MONEY,CURRENCY_LOCATION_BANK)
 end
 if type(p)~='number' then p=s(GetCurrentMoney) end
 if type(b)~='number' then b=s(GetBankedMoney) end
 return p,b
end
function N.goldTransferIntent(deposit,amount,mode)
 E.goldIntent={deposit=deposit,amount=amount,mode=mode};local intent=E.goldIntent
 zo_callLater(function() if E.goldIntent==intent then E.goldIntent=nil;if N.refreshHCGold then N.refreshHCGold() end end end,4000)
end
function N.cancelGoldTransferIntent() E.goldIntent=nil end
local function goldUpdate()
 local a=c();local p,b=goldSnapshot();if type(p)~='number' or type(b)~='number' then return end
 local op,ob=E.goldP,E.goldB;E.goldP,E.goldB=p,b;if not op or not ob then return end
 local dp,db=p-op,b-ob;local held=a.hcGold or 0;local banked=E.db.gold or 0
 local intent=E.goldIntent;if intent then local matched=intent.deposit and dp<=-intent.amount and db>=intent.amount or not intent.deposit and dp>=intent.amount and db<=-intent.amount;if not matched and (dp~=0 or db~=0) then E.goldP,E.goldB=op,ob;return end end
 if bank() or E.banking or E.goldBanking or E.goldIntent then
  if dp<0 and db>0 then
   local moved=math.min(-dp,db);local n=math.min(moved,active() and held or 0);local intent=E.goldIntent;if intent and intent.deposit and intent.amount==moved then if intent.mode=="standard" then n=math.min(n,math.max(0,moved-math.max(0,op-held))) end;E.goldIntent=nil end;held=held-n;banked=banked+n;dp=dp+moved
   if active() and moved>n then note('Review non-HC gold deposit: '..(moved-n)) end
  elseif dp>0 and db<0 then
   local moved=math.min(dp,-db);local n=math.min(moved,banked);local intent=E.goldIntent;if intent and not intent.deposit and intent.amount==moved then if intent.mode=="standard" then n=math.min(n,math.max(0,moved-math.max(0,ob-banked))) end;E.goldIntent=nil end;banked=banked-n;if active() then held=held+n end;dp=dp-moved
   if active() and moved>n then note('Review non-HC gold withdrawal: '..(moved-n)) end
  end
 end
 if active() and dp~=0 then a.commerceFlow=a.commerceFlow or {income=0,expense=0};local f=a.commerceFlow;if dp>0 then f.income=(f.income or 0)+dp else f.expense=(f.expense or 0)-dp end;if a.journal then if dp>0 then a.journal.goldIn=(a.journal.goldIn or 0)+dp else a.journal.goldOut=(a.journal.goldOut or 0)-dp end end end
 if active() and dp>0 then held=held+dp end
 if active() and dp<0 then if -dp>held then note('Review non-HC gold loss/spend: '..(-dp-held)) end;held=math.max(0,held+dp) end
 a.hcGold=math.min(p,held);E.db.gold=math.min(b,banked)
end
local function scheduleGold()
 if bank() or E.banking then E.goldBanking=true end
 if E.goldPending then return end
 E.goldPending=true;zo_callLater(function()
  E.goldPending=false;local ok,err=pcall(goldUpdate);E.goldBanking=false
  if not ok then trace('Gold update error: '..tostring(err)) end
 end,450)
end
N.refreshHCGold=scheduleGold
function N.hcGold() return c().hcGold or 0,E.db and E.db.gold or 0 end
local function clean(v) return (tostring(v or ''):gsub('%^%a+','')) end
local function name(k) local raw=s(GetItemLinkName,E.db.links[k] or k);return clean(s(zo_strformat, SI_TOOLTIP_ITEM_NAME,raw) or raw or k) end
-- Craft completion and actual material gains provide acquisition evidence.
-- Input ownership is advisory only; keep the pre-craft snapshot until inventory settles.
local function resultName(v)
 return clean(s(zo_strformat, SI_TOOLTIP_ITEM_NAME,v) or v):lower()
end
-- Console APIs can throw during global lookup as well as during invocation.
local function craftApi(name,...)
 local args={...};local argc=select('#',...)
 local ok,a,b,c,d,e,f,g=pcall(function()
  local fn=_G[name];if type(fn)=='function' then return fn((unpack or table.unpack)(args,1,argc)) end
 end)
 if ok then return a,b,c,d,e,f,g end
 trace('Craft API unavailable: '..name)
end
local function captureCraftResults()
 local results={byKey={},byName={}};local count=craftApi('GetNumLastCraftingResultItemsAndPenalty')
 if type(count)~='number' then count=craftApi('GetNumLastCraftingResultItems') end
 if type(count)~='number' or count~=count or count<0 or count>1000 then trace('Craft result count unavailable');return results end
 for i=1,math.floor(count) do
  local n,icon,q,sell,usable,equip,typ=craftApi('GetLastCraftingResultItemInfo',i)
  if type(q)=='number' and q>0 and q==q then
   local l=craftApi('GetLastCraftingResultItemLink',i,LINK_STYLE_DEFAULT)
   if type(l)~='string' or l=='' then l=craftApi('GetLastCraftingResultItemLink',i) end
   local k=type(l)=='string' and l:find('|H',1,true) and key(l)
   if k then
    -- Seed the known-link and virtual-slot indices, not ownership. The actual
    -- inventory gain and completed craft still control every credit.
    E.db.links[k]=l
    local itemId=tonumber(k:match('^mat:(%d+)$'));if itemId then E.virtualSlots[itemId]=true end
    add(results.byKey,k,q)
   elseif type(n)=='string' and n~='' then
    -- Match only actual material gains, using item type when available.
    add(results.byName,resultName(n)..':'..tostring(typ or ''),q)
   end
  end
 end
 trace('Native crafting results: '..count)
 return results
end
local function craftCredits(old,now,transaction)
 local out={}
 if not transaction or not transaction.completed or not active() then return out end
 -- Honor-based: input provenance is advisory, never a veto on output credit.
 local consumed=0
 for k,q in pairs(old.p) do consumed=consumed+math.max(0,q-(now.p[k] or 0)) end
 for k,q in pairs(old.b) do
  local loss=math.max(0,q-(now.b[k] or 0))
  if loss>0 then consumed=consumed+loss;note('Review crafting input from bank: '..name(k)..' x'..loss) end
 end
 if consumed==0 then trace('Craft completed without a confirmed input delta; output tracking continues') end
 local results=transaction.results or {byKey={},byName={}}
 local remainingNames={};for k,v in pairs(results.byName or {}) do remainingNames[k]=v end
 for k,q in pairs(now.p) do
  local gain=math.max(0,q-(old.p[k] or 0)-(E.loot[k] or 0))
  local l=E.db.links[k];local typ=l and s(GetItemLinkItemType,l)
  if gain>0 and materialTypes[typ] then
   local id=resultName(name(k))..':'..tostring(typ)
   local exact=math.min(gain,(results.byKey or {})[k] or 0)
   local fallback=math.min(gain-exact,remainingNames[id] or 0)
   local untyped=resultName(name(k))..':'
   local other=math.min(gain-exact-fallback,remainingNames[untyped] or 0)
   add(remainingNames,id,-fallback);add(remainingNames,untyped,-other)
   -- A successful native craft event plus an observed material gain is
   -- sufficient on the honor system. Unmatched results are review-only.
   out[k]=gain
   if exact+fallback+other<gain then note('Review crafting-window material gain: '..name(k)..' x'..(gain-exact-fallback-other)..' (result not individually verified)') end
  end
 end
 return out
end
local function reconcile()
 local now=snap();local old=E.prev;if not old then E.prev=now;return end
 local keys={};for _,t in ipairs({old.p,now.p,old.b,now.b}) do for k in pairs(t) do keys[k]=true end end
 local o=own();local sh=E.db.bank;local banking=bank() or E.banking
 local credits=not banking and craftCredits(old,now,E.craftTxn) or {}
 -- Self-loot is the acquisition evidence; snapshots alone cannot identify it.
 if active() then for k,q in pairs(E.loot) do
  if q>0 then
   local gainedVirtual=math.max(0,(now.v[k] or 0)-(old.v[k] or 0));local n=math.min(q,gainedVirtual)
   add(shared(),k,n);add(o,k,q-n);trace('HC loot credited '..name(k)..' +'..q)
  end
 end end
 for k in pairs(keys) do local dp=(now.p[k] or 0)-(old.p[k] or 0);local db=(now.b[k] or 0)-(old.b[k] or 0)
 if banking then
  if dp<0 and db>0 then
   local moved=math.min(-dp,db);local n=math.min(moved,active() and (o[k] or 0) or 0)
   add(o,k,-n);add(sh,k,n);dp=dp+moved
   if active() and moved>n then note('Review non-HC bank deposit: '..name(k)..' x'..(moved-n)) end
  elseif dp>0 and db<0 then
   local moved=math.min(dp,-db);local n=math.min(moved,sh[k] or 0)
   add(sh,k,-n);if active() then add(o,k,n) end;dp=dp-moved;db=db+moved
   if active() and moved>n then note('Review non-HC bank withdrawal: '..name(k)..' x'..(moved-n)) end
  end
  if db<0 then
   if active() and -db>(sh[k] or 0) then note('Review non-HC bank item loss: '..name(k)..' x'..(-db-(sh[k] or 0))) end
   add(sh,k,db)
  end
 end
 if active() then
  if dp<0 then
   local dv=math.min(-dp,math.max(0,(old.v[k] or 0)-(now.v[k] or 0)));local n=math.min(dv,shared()[k] or 0)
   add(shared(),k,-n);dp=dp+dv
   local excess=(dv-n)+math.max(0,-dp-(o[k] or 0))
   if excess>0 then note((E.crafted and 'Review non-HC crafting input: ' or 'Review non-HC item loss/use: ')..name(k)..' x'..excess) end
   add(o,k,dp)
  elseif dp>0 then
   local looted=math.min(dp,E.loot[k] or 0);local credit=math.min(dp-looted,credits[k] or 0)
   if credit>0 then
    local gainedVirtual=math.max(0,(now.v[k] or 0)-(old.v[k] or 0)-looted)
    local n=math.min(credit,gainedVirtual);add(shared(),k,n);add(o,k,credit-n)
    trace('HC craft credited '..name(k)..' +'..credit)
   end
   if E.crafted and looted+credit<dp and not banking then note('Unverified crafting output: '..name(k)..' x'..(dp-looted-credit)) end
  end
  local worn=(now.w[k] or 0);local oldWorn=(old.w[k] or 0)
  local excess=math.max(0,worn-(o[k] or 0));local newlyWorn=math.max(0,worn-oldWorn)
  if excess>0 and newlyWorn>0 then note('Review non-HC equipment: '..name(k)..' x'..math.min(excess,newlyWorn)) end
 end
 end
 if banking then for k,v in pairs(sh) do if v>(now.b[k] or 0) then add(sh,k,(now.b[k] or 0)-v) end end end
 if active() then distribute(now) end;for k,q in pairs(shared()) do if q>(now.v[k] or 0) then local confirmed=virtualCount(E.db.links[k] or k);if type(confirmed)=="number" and confirmed<q then shared()[k]=confirmed>0 and confirmed or nil end end end
 E.prev=now;E.loot={};E.crafted=false;E.craftTxn=nil;E.materialStamp=nil;E.banking=bank();if N.inventory then N.inventory.dirty=true end;if N.bank then N.bank.dirty=true end
end

local function copy(tbl) local r={};for k,v in pairs(tbl or {}) do r[k]=v end;return r end
local function flush()
 -- Roll back ownership changes if a reconciliation fails halfway through.
 local prev=E.prev;local a=c();local o,mat,bnk,notes=copy(own()),copy(shared()),copy(E.db.bank),copy(a.integrityNotes)
 local ok,e=pcall(reconcile)
 if not ok then
  E.prev=prev;a.ownership=o;E.db.materials=mat;E.db.bank=bnk;a.integrityNotes=notes
  trace('Reconcile error: '..tostring(e))
  return false
 end
 return true
end
local schedule
local function millis() return s(GetFrameTimeMilliseconds) or 0 end
local function safeCapture()
 local ok,r=pcall(captureCraftResults)
 if ok then return r end
 trace('Craft result read failed: '..tostring(r));return {byKey={},byName={}}
end
local function arm()
 if E.pending then return end
 E.pending=true
 zo_callLater(function()
  E.pending=false
  local ok,err=pcall(function()
   local tx=E.craftTxn;local now=millis()
   if tx then
    if not tx.completed and not tx.aborted and now-tx.started<60000 then arm();return end
    if tx.completed and now-(tx.changed or tx.started)<650 and now-(tx.finished or now)<5000 then arm();return end
   end
   if not flush() then
    E.retry=(E.retry or 0)+1
    if E.retry<3 then arm() else E.craftTxn=nil;E.crafted=false;E.retry=0;trace('Ledger retry limit reached; next inventory event will reconcile') end
   else E.retry=0 end
  end)
  if not ok then E.pending=false;E.craftTxn=nil;E.crafted=false;trace('Ledger timer recovered: '..tostring(err)) end
 end,E.craftTxn and 650 or 450)
end
schedule=function()
 if E.craftTxn then E.craftTxn.changed=millis() end
 arm()
end
local function craftStarted()
 if not active() then return end
 if E.craftTxn and (E.craftTxn.completed or E.craftTxn.aborted) then flush() end
 if E.craftTxn then return end
 if next(E.loot) then flush() end
 E.craftTxn={started=millis()};E.crafted=true;trace('Craft transaction started');schedule()
end
local function craftCompleted()
 if not active() then schedule();return end
 local tx=E.craftTxn or {started=millis()}
 tx.completed=true;tx.aborted=false;tx.finished=millis();E.craftTxn=tx;E.crafted=true
 tx.results=safeCapture()
 if not next(tx.results.byKey) and not next(tx.results.byName) then
  zo_callLater(function()
   local ok,e=pcall(function()
    if E.craftTxn==tx and tx.completed and not next(tx.results.byKey) and not next(tx.results.byName) then tx.results=safeCapture() end
   end)
   if not ok then trace('Delayed craft result read failed: '..tostring(e)) end
  end,150)
 end
 trace('Craft completed; counting material gains; input provenance is advisory');schedule()
end
local function craftAborted()
 if E.craftTxn and not E.craftTxn.completed then E.craftTxn.aborted=true end
 schedule()
end
function N.economyInit()
 E.db=ZO_SavedVars:NewAccountWide('ESOHardcoreSaved',1,'Economy',{bank={},links={}});E.db.bank=E.db.bank or {};E.db.materials=E.db.materials or {};E.db.gold=E.db.gold or 0;E.db.links=E.db.links or {};E.virtualSlots={}
 local function migrate(tbl) local r={};for k,v in pairs(tbl) do local nk=key(E.db.links[k] or k) or k;add(r,nk,v);if E.db.links[k] then E.db.links[nk]=E.db.links[k] end end;return r end
 c().ownership=migrate(own());E.db.bank=migrate(E.db.bank);E.db.materials=migrate(E.db.materials)
 local links={};for k,l in pairs(E.db.links) do links[key(l) or k]=l end;E.db.links=links;E.prev=snap();if active() then distribute(E.prev) end;E.goldP,E.goldB=goldSnapshot()
 local function ev(n,v,f) if v then EVENT_MANAGER:RegisterForEvent('ESOHC_Econ_'..n,v,function(...) local ok,e=pcall(f,...);if not ok and d then d('HC ledger '..n..': '..tostring(e)) end end) end end
 ev('slot',EVENT_INVENTORY_SINGLE_SLOT_UPDATE,function(_,b,i,_,_,reason,delta) 
  if b==BAG_VIRTUAL and type(i)=='number' then E.virtualSlots[i]=true;local l=s(GetItemLink,b,i,LINK_STYLE_DEFAULT);local k=key(l);if k then E.db.links[k]=l end;trace('Craft Bag slot '..i..' delta '..tostring(delta)) else trace('Slot '..tostring(b)..':'..tostring(i)) end;schedule() end)
 ev('full',EVENT_INVENTORY_FULL_UPDATE,schedule);ev('money',EVENT_MONEY_UPDATE,scheduleGold);ev('bankmoney',EVENT_BANKED_MONEY_UPDATE,scheduleGold);ev('currency',EVENT_CURRENCY_UPDATE,function(_,currencyType) if currencyType==CURT_MONEY then scheduleGold() end end)
 ev('loot',EVENT_LOOT_RECEIVED,function(_,who,l,q,_,kind,selfLoot) if active() and selfLoot==true and not bank() and not craft() and (not LOOT_TYPE_ITEM or kind==LOOT_TYPE_ITEM) then local k=key(l);trace('Loot '..clean(s(GetItemLinkName,l) or l)..' x'..tostring(q));if k then E.db.links[k]=l;add(E.loot,k,tonumber(q) or 1);schedule() end end end)
 ev('stationopen',EVENT_CRAFTING_STATION_INTERACT,function() E.stationOpen=true;E.materialStamp=nil end)
 ev('stationclose',EVENT_END_CRAFTING_STATION_INTERACT,function() E.stationOpen=false;E.materialStamp=nil;if E.root then E.root:SetHidden(true) end end)
 ev('craftstart',EVENT_CRAFT_STARTED,craftStarted)
 ev('craft',EVENT_CRAFT_COMPLETED,craftCompleted)
 ev('craftfailed',EVENT_CRAFT_FAILED,craftAborted);ev('craftaborted',EVENT_CRAFT_ABORTED,craftAborted)
 ev('bankopen',EVENT_OPEN_BANK,function() trace('Bank opened');E.banking=true;schedule() end)
 ev('bankclose',EVENT_CLOSE_BANK,function() schedule();scheduleGold() end)
 ev('trade',EVENT_TRADE_SUCCEEDED,function() if active() then note('Player trade completed — review') end end)
 ev('mail',EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS,function() if active() then note('Mail attachment received — review source') end end)
 ev('guild',EVENT_TRADING_HOUSE_PURCHASE_ITEM_RESULT,function() if active() then note('Guild trader purchase result — review') end end)
 local root=WINDOW_MANAGER:CreateTopLevelWindow('ESOHCAdvisor');E.root=root;root:SetDimensions(450,130);root:SetAnchor(TOPRIGHT,GuiRoot,TOPRIGHT,-55,110);root:SetMouseEnabled(false);root:SetHidden(true);local bg=WINDOW_MANAGER:CreateControl(nil,root,CT_TEXTURE);bg:SetAnchorFill(root);bg:SetColor(.04,.04,.04,.9);local l=WINDOW_MANAGER:CreateControl(nil,root,CT_LABEL);l:SetAnchorFill(root);l:SetFont('$(BOLD_FONT)|20|soft-shadow-thick');l:SetColor(.9,.8,.6,1);E.text=l
 -- Run independently of the survival HUD and its combat/blur effects.
 EVENT_MANAGER:RegisterForUpdate('ESOHC_MaterialOverlay',350,function() N.economyTick() end)
end
-- Read-only station material overlay. No native selection or crafting hooks.
local stationTypes={
 BLACKSMITHING={'BLACKSMITHING_RAW_MATERIAL','BLACKSMITHING_MATERIAL','BLACKSMITHING_BOOSTER','STYLE_MATERIAL','WEAPON_TRAIT','ARMOR_TRAIT'},
 CLOTHIER={'CLOTHIER_RAW_MATERIAL','CLOTHIER_MATERIAL','CLOTHIER_BOOSTER','STYLE_MATERIAL','ARMOR_TRAIT'},
 WOODWORKING={'WOODWORKING_RAW_MATERIAL','WOODWORKING_MATERIAL','WOODWORKING_BOOSTER','STYLE_MATERIAL','WEAPON_TRAIT','ARMOR_TRAIT'},
 JEWELRYCRAFTING={'JEWELRYCRAFTING_RAW_MATERIAL','JEWELRYCRAFTING_MATERIAL','JEWELRYCRAFTING_BOOSTER','JEWELRYCRAFTING_RAW_BOOSTER','JEWELRY_RAW_TRAIT','JEWELRY_TRAIT'},
 PROVISIONING={'INGREDIENT'},
 ALCHEMY={'REAGENT','POTION_BASE','POISON_BASE'},
 ENCHANTING={'ENCHANTING_RUNE_ASPECT','ENCHANTING_RUNE_ESSENCE','ENCHANTING_RUNE_POTENCY'},
}
local function stationFilter(t)
 for station,types in pairs(stationTypes) do
  local id=_G['CRAFTING_TYPE_'..station]
  if id and t==id then
   local allowed={};for _,v in ipairs(types) do local kind=_G['ITEMTYPE_'..v];if kind then allowed[kind]=true end end
   return allowed
  end
 end
end
-- Read-only display counts. Do not use a pre-craft snapshot as the sole
-- source while a transaction is pending; never mutate the ownership ledger here.
local function liveMaterialCounts(k,l)
 local snapshot=E.prev or {v={},p={}}
 local sv=snapshot.v[k] or 0
 local sp=math.max(0,(snapshot.p[k] or 0)-sv)
 local v,p
 if type(l)=='string' and l:find('|H',1,true) then
  v=virtualCount(l)
  if INVENTORY_COUNT_BAG_OPTION_BACKPACK then
   p=s(GetItemLinkInventoryCount,l,INVENTORY_COUNT_BAG_OPTION_BACKPACK)
  end
  if type(p)~='number' or type(v)~='number' then
   local pack,_,virt=s(GetItemLinkStacks,l)
   if type(p)~='number' then p=pack end
   if type(v)~='number' then v=virt end
  end
 end
 if type(v)~='number' or v~=v or v<0 then v=sv end
 if type(p)~='number' or p~=p or p<0 then p=sp end
 return v,p
end
local function materialRows(allowed)
 local rows={};local keys={};local personal=own();local virtualOwned=shared()
 for k in pairs(personal) do keys[k]=true end;for k in pairs(virtualOwned) do keys[k]=true end
 for k in pairs(keys) do
  -- A single stale/malformed link must not hide every other material.
  local ok,row=pcall(function()
   local l=E.db.links[k] or k;local kind=s(GetItemLinkItemType,l)
   if not kind or not allowed[kind] then return end
   local v,p=liveMaterialCounts(k,l)
   local qty=math.min(personal[k] or 0,p)+math.min(virtualOwned[k] or 0,v)
   if qty>0 then return {name=name(k),qty=qty,link=l} end
  end)
  if ok and row then rows[#rows+1]=row end
 end
 table.sort(rows,function(a,b) if a.name==b.name then return a.qty>b.qty end;return a.name<b.name end)
 return rows
end
local function renderMaterials(rows)
 local screenW,screenH=GuiRoot:GetDimensions();local maxRows=math.max(1,math.floor((screenH-180)/24));local columns=math.max(1,math.ceil(#rows/maxRows));local perCol=math.max(1,math.ceil(#rows/columns));local width=math.min(410,math.floor((screenW-110)/columns))
 E.root:SetDimensions(width*columns+20,44+perCol*24)
 E.text:SetText('HC MATERIALS');E.text:ClearAnchors();E.text:SetAnchor(TOPLEFT,E.root,TOPLEFT,10,6);E.text:SetDimensions(width*columns,30);E.text:SetColor(.66,.80,1,1)
 E.materialLabels=E.materialLabels or {}
 for i=1,columns do
  local pair=E.materialLabels[i]
  if not pair then
   local n=WINDOW_MANAGER:CreateControl(nil,E.root,CT_LABEL);n:SetFont('$(BOLD_FONT)|18|soft-shadow-thick');n:SetColor(.95,.95,.95,1);n:SetMouseEnabled(false)
   local q=WINDOW_MANAGER:CreateControl(nil,E.root,CT_LABEL);q:SetFont('$(BOLD_FONT)|18|soft-shadow-thick');q:SetColor(.45,.9,.55,1);q:SetHorizontalAlignment(TEXT_ALIGN_RIGHT);q:SetMouseEnabled(false)
   pair={n=n,q=q};E.materialLabels[i]=pair
  end
  local names,counts={},{};for j=(i-1)*perCol+1,math.min(i*perCol,#rows) do names[#names+1]=rows[j].name;counts[#counts+1]=tostring(rows[j].qty) end
  local x=10+(i-1)*width;pair.n:ClearAnchors();pair.n:SetAnchor(TOPLEFT,E.root,TOPLEFT,x,36);pair.n:SetDimensions(width-65,perCol*24);pair.n:SetText(table.concat(names,'\n'));pair.n:SetHidden(false)
  pair.q:ClearAnchors();pair.q:SetAnchor(TOPLEFT,E.root,TOPLEFT,x+width-65,36);pair.q:SetDimensions(55,perCol*24);pair.q:SetText(table.concat(counts,'\n'));pair.q:SetHidden(false)
 end
 for i=columns+1,#E.materialLabels do E.materialLabels[i].n:SetHidden(true);E.materialLabels[i].q:SetHidden(true) end
end
local function overlayTick()
 if not E.root then return end
 local t=s(GetCraftingInteractionType)
 local nativeCraft=INTERACTION_CRAFT and s(GetInteractionType)==INTERACTION_CRAFT
 local allowed=(E.stationOpen or nativeCraft) and active() and type(t)=='number' and t>0 and t~=CRAFTING_TYPE_INVALID and stationFilter(t)
 if not allowed or not E.prev then E.root:SetHidden(true);E.materialStamp=nil;return end
 local rows=materialRows(allowed)
 if #rows==0 then E.root:SetHidden(true);E.materialStamp=nil;return end
 local signature={tostring(t)};for _,r in ipairs(rows) do signature[#signature+1]=r.link..':'..r.qty end;local stamp=table.concat(signature,'|')
 if E.materialStamp~=stamp then renderMaterials(rows);E.materialStamp=stamp end
 E.root:SetHidden(false)
end
function N.economyTick()
 local ok,err=pcall(overlayTick)
 if not ok then
  E.materialStamp=nil
  if E.overlayError~=tostring(err) then trace('HC overlay: '..tostring(err));E.overlayError=tostring(err) end
  -- Retry on the next refresh; the last good draw is left intact.
 else E.overlayError=nil end
end
function N.economyDeath() c().ownership={};c().hcGold=0;E.loot={} end
function N.economyText(page)
 if not E.db then return 'Ledger unavailable' end
 if page==10 then local t={'INTEGRITY LOG | informational only','First person: honor-based; difficulty selectable','Flags: observed changes; no automatic penalties',''};for i,v in ipairs(c().integrityNotes or {}) do if i>10 then break end;t[#t+1]=clean(v) end;return table.concat(t,'\n') end
 local rows={};for k,v in pairs(page==8 and own() or E.db.bank) do rows[#rows+1]={n=name(k),v=v} end;table.sort(rows,function(a,b) if E.sort==2 and a.v~=b.v then return a.v>b.v end;return a.n<b.n end);E.index=math.max(1,math.min(E.index,math.max(1,#rows)));local start=math.floor((E.index-1)/10)*10+1;local t={page==8 and 'PERSONAL OWNERSHIP LEDGER' or 'SHARED HARDCORE BANK','Experimental | native bank performs transfers','Entries: '..#rows..' | Sort: '..(E.sort==1 and 'Name' or 'Quantity'),' '};for i=start,math.min(#rows,start+9) do local r=rows[i];t[#t+1]=(i==E.index and '> ' or '   ')..r.n..' x'..r.v end;if #rows==0 then t[#t+1]='No eligible items recorded.' end;return table.concat(t,'\n')
end
function N.economyMove(dx,dy) if dx~=0 then E.sort=3-E.sort;E.index=1 else E.index=math.max(1,E.index+dy) end end

function N.economyRows(page) local rows={};if not E.db then return rows end;for k,v in pairs(page==8 and own() or E.db.bank) do local l=E.db.links[k] or k;rows[#rows+1]={name=name(k),qty=v,link=l,icon=s(GetItemLinkIcon,l),quality=math.max(0,math.min(5,math.floor(tonumber((s(GetItemLinkQuality,l))) or 1)))} end;table.sort(rows,function(a,b) return a.name<b.name end);return rows end
function N.economyDebug() return clean(table.concat(E.debug,'\n')) end

-- Read-only intersection of physical Craft Bag and personal HC ownership.
function N.hcMaterialRows(sharedOnly)
 local rows={};if not E.db or not E.prev or not active() then return rows end
 local keys={};for k in pairs(shared()) do keys[k]=true end;for k in pairs(own()) do keys[k]=true end
 for k in pairs(keys) do
  local l=E.db.links[k] or k;local typ=s(GetItemLinkItemType,l)
  if materialTypes[typ] then
   local v,p=liveMaterialCounts(k,l)
   local qty=math.min(v,shared()[k] or 0)+(sharedOnly and 0 or math.min(p,own()[k] or 0))
   if qty>0 then rows[#rows+1]={name=name(k),qty=qty,physical=sharedOnly and v or v+p,link=l,icon=s(GetItemLinkIcon,l),quality=math.max(0,math.min(5,math.floor(tonumber((s(GetItemLinkQuality,l))) or 1)))} end
  end
 end
 table.sort(rows,function(a,b) return a.name<b.name end);return rows
end

function N.hcActive() return E.db~=nil and N.hardcore.saved~=nil and active() end
function N.hcAvailable(link)
 if not N.hcActive() or not E.prev then return 0 end;local k=key(link);if not k then return 0 end
 local v=E.prev.v[k] or 0;return math.min(v,shared()[k] or 0)+math.min(math.max(0,(E.prev.p[k] or 0)-v),own()[k] or 0)
end
function N.hcEligible(link,banked) if not N.hcActive() then return 0 end;local k=key(link);return k and ((banked and E.db.bank or own())[k] or 0) or 0 end

-- Read-only reward summaries reuse the existing reconciled ledger.
function N.rewardMaterialRows(station)
 if not E.db or not E.prev or not station then return end
 local id=_G['CRAFTING_TYPE_'..station];if not id then return end
 local filter=stationFilter(id);if filter then return materialRows(filter) end
end
