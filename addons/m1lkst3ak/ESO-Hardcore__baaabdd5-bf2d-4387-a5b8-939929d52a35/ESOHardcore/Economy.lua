local N=ESOHardcore;local s=N.safe
local E={index=1,sort=1,loot={},debug={}};N.economy=E
local function c() return N.hardcore.saved end
local function active() return c().active and not c().fallen end
local function own() c().ownership=c().ownership or {};return c().ownership end
local function shared() return E.db.materials end
local function add(t,k,n) t[k]=math.max(0,(t[k] or 0)+n);if t[k]==0 then t[k]=nil end end
-- Item links from loot and virtual slots can differ in display style/name.
local function key(l) if type(l)=='string' and l~='' then return l:gsub('|H%d+:','|H0:'):gsub('|h.-|h$','|h|h') end end
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
     local _,_,q=s(GetItemLinkStacks,l)
     if type(q)=='number' and q>0 then out[k]=q end
    end
   end
  end
 end
 return out
end
local function bank() return INTERACTION_BANK and s(GetInteractionType)==INTERACTION_BANK end
local function craft() local v=s(GetCraftingInteractionType);return type(v)=='number' and v>0 and v~=CRAFTING_TYPE_INVALID end
local function snap() local p=scan(BAG_BACKPACK,BAG_WORN);local v=scan(BAG_VIRTUAL);for k,n in pairs(v) do add(p,k,n) end;return {p=p,v=v,b=scan(BAG_BANK,BAG_SUBSCRIBER_BANK)} end
local function distribute(now)
 local o=own();for k,q in pairs(o) do local virtual=now.v[k] or 0;local physical=math.max(0,(now.p[k] or 0)-virtual);local n=math.min(q,math.max(0,virtual-(shared()[k] or 0)),math.max(0,q-physical));if n>0 then add(o,k,-n);add(shared(),k,n) end end
end
local function goldSnapshot() return s(GetCurrentMoney),s(GetBankedMoney) end
local function goldUpdate()
 local a=c();local p,b=goldSnapshot();if type(p)~='number' or type(b)~='number' then return end
 local op,ob=E.goldP,E.goldB;E.goldP,E.goldB=p,b;if not op or not ob then return end
 local dp,db=p-op,b-ob;local held=a.hcGold or 0;local banked=E.db.gold or 0
 if bank() or E.banking then
  if dp<0 and db>0 then local n=math.min(-dp,db,active() and held or 0);held=held-n;banked=banked+n;dp=dp+n
  elseif dp>0 and db<0 then local n=math.min(dp,-db,banked);banked=banked-n;if active() then held=held+n end;dp=dp-n end
 else if active() and dp>0 then held=held+dp end end
 if active() and dp<0 then held=math.max(0,held+dp) end
 a.hcGold=math.min(p,held);E.db.gold=math.min(b,banked)
end
function N.hcGold() return c().hcGold or 0,E.db and E.db.gold or 0 end
local function clean(v) return (tostring(v or ''):gsub('%^%a+','')) end
local function name(k) local raw=s(GetItemLinkName,E.db.links[k] or k);return clean(s(zo_strformat, SI_TOOLTIP_ITEM_NAME,raw) or raw or k) end
local function reconcile()
 local now=snap();local old=E.prev;E.prev=now;if not old then return end
 local keys={};for _,t in ipairs({old.p,now.p,old.b,now.b}) do for k in pairs(t) do keys[k]=true end end
 goldUpdate();local o=own();local sh=E.db.bank;local banking=bank() or E.banking
 -- Self-loot is the acquisition evidence; snapshots alone cannot identify it.
 if active() then for k,q in pairs(E.loot) do if q>0 then add(o,k,q);trace('HC loot credited '..name(k)..' +'..q) end end end
 for k in pairs(keys) do local dp=(now.p[k] or 0)-(old.p[k] or 0);local db=(now.b[k] or 0)-(old.b[k] or 0)
 if banking then
 if dp<0 and db>0 then local n=math.min(-dp,db,active() and (o[k] or 0) or 0);add(o,k,-n);add(sh,k,n);dp=dp+n
 elseif dp>0 and db<0 then local n=math.min(dp,-db,sh[k] or 0);add(sh,k,-n);if active() then add(o,k,n) end;dp=dp-n;db=db+n end
 if db<0 then add(sh,k,db) end
 end
 if active() then if dp<0 then local dv=math.max(0,(old.v[k] or 0)-(now.v[k] or 0));local n=math.min(-dp,dv,shared()[k] or 0);add(shared(),k,-n);dp=dp+n;if E.crafted and -dp>(o[k] or 0) then note('Review crafting input: '..name(k)) end;add(o,k,dp) elseif dp>0 then local n=math.min(dp,E.loot[k] or 0);if E.crafted and n<dp and not banking then note('Unverified crafting output: '..name(k)) end end end
 end
 if banking then for k,v in pairs(sh) do if v>(now.b[k] or 0) then add(sh,k,(now.b[k] or 0)-v) end end end
 if active() then distribute(now) end;for k,q in pairs(shared()) do if q>(now.v[k] or 0) then shared()[k]=(now.v[k] or 0)>0 and now.v[k] or nil end end
 E.loot={};E.crafted=false;E.banking=bank()
end

local function schedule() if E.pending then return end;E.pending=true;zo_callLater(function() E.pending=false;local ok,e=pcall(reconcile);if not ok then trace('Reconcile error: '..tostring(e));if d then d('HC ledger: '..tostring(e)) end end end,450) end
function N.economyInit()
 E.db=ZO_SavedVars:NewAccountWide('ESOHardcoreSaved',1,'Economy',{bank={},links={}});E.db.bank=E.db.bank or {};E.db.materials=E.db.materials or {};E.db.gold=E.db.gold or 0;E.db.links=E.db.links or {};E.virtualSlots={}
 local function migrate(tbl) local r={};for k,v in pairs(tbl) do local nk=key(k) or k;add(r,nk,v);if E.db.links[k] then E.db.links[nk]=E.db.links[k] end end;return r end
 c().ownership=migrate(own());E.db.bank=migrate(E.db.bank)
 local links={};for k,l in pairs(E.db.links) do links[key(l) or k]=l end;E.db.links=links;E.prev=snap();if active() then distribute(E.prev) end;E.goldP,E.goldB=goldSnapshot()
 local function ev(n,v,f) if v then EVENT_MANAGER:RegisterForEvent('ESOHC_Econ_'..n,v,function(...) local ok,e=pcall(f,...);if not ok and d then d('HC ledger '..n..': '..tostring(e)) end end) end end
 ev('slot',EVENT_INVENTORY_SINGLE_SLOT_UPDATE,function(_,b,i,_,_,reason,delta) 
  if b==BAG_VIRTUAL and type(i)=='number' then E.virtualSlots[i]=true;local l=s(GetItemLink,b,i,LINK_STYLE_DEFAULT);local k=key(l);if k then E.db.links[k]=l end;trace('Craft Bag slot '..i..' delta '..tostring(delta)) else trace('Slot '..tostring(b)..':'..tostring(i)) end;schedule() end)
 ev('full',EVENT_INVENTORY_FULL_UPDATE,schedule);ev('money',EVENT_MONEY_UPDATE,schedule);ev('bankmoney',EVENT_BANKED_MONEY_UPDATE,schedule)
 ev('loot',EVENT_LOOT_RECEIVED,function(_,who,l,q,_,kind,selfLoot) if active() and selfLoot==true and not bank() and not craft() and (not LOOT_TYPE_ITEM or kind==LOOT_TYPE_ITEM) then local k=key(l);trace('Loot '..clean(s(GetItemLinkName,l) or l)..' x'..tostring(q));if k then E.db.links[k]=l;add(E.loot,k,tonumber(q) or 1);schedule() end end end)
 ev('craft',EVENT_CRAFT_COMPLETED,function() trace('Craft completed');E.crafted=true;schedule() end)
 ev('bankopen',EVENT_OPEN_BANK,function() trace('Bank opened');E.banking=true;schedule() end)
 ev('bankclose',EVENT_CLOSE_BANK,schedule)
 ev('trade',EVENT_TRADE_SUCCEEDED,function() if active() then note('Player trade completed — review') end end)
 ev('mail',EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS,function() if active() then note('Mail attachment received — review source') end end)
 ev('guild',EVENT_TRADING_HOUSE_PURCHASE_ITEM_RESULT,function() if active() then note('Guild trader purchase result — review') end end)
 local root=WINDOW_MANAGER:CreateTopLevelWindow('ESOHCAdvisor');E.root=root;root:SetDimensions(450,130);root:SetAnchor(TOPRIGHT,GuiRoot,TOPRIGHT,-55,110);root:SetMouseEnabled(false);root:SetHidden(true);local bg=WINDOW_MANAGER:CreateControl(nil,root,CT_TEXTURE);bg:SetAnchorFill(root);bg:SetColor(.04,.04,.04,.9);local l=WINDOW_MANAGER:CreateControl(nil,root,CT_LABEL);l:SetAnchorFill(root);l:SetFont('$(BOLD_FONT)|20|soft-shadow-thick');l:SetColor(.9,.8,.6,1);E.text=l
end
-- Read-only creation selection adapters. No crafting actions or hooks.
local function method(o,m,...) if o then return s(o[m],o,...) end end
local function visible(o) return o and o.control and method(o.control,'IsHidden')==false end
local function showing(scene) return method(scene,'IsShowing')==true end
local function quantity(o)
 local q=method(o,'GetMultiCraftNumIterations') or method(o and o.multiCraftSpinner,'GetValue')
 if type(q)=='number' and q>=1 then return math.floor(q),true end
 return 1,false
end
local function recipe()
 local r=method(GAMEPAD_PROVISIONER,'GetRecipeData');if type(r)~='table' then return end
 local a,b=r.recipeListIndex,r.recipeIndex;if not a or not b then return end
 local _,title,count=s(GetRecipeInfo,a,b);count=r.numIngredients or count
 if type(count)~='number' or count<1 then return end
 local rows={}
 for i=1,count do local l=s(GetRecipeIngredientItemLink,a,b,i,LINK_STYLE_DEFAULT);local _,_,q=s(GetRecipeIngredientItemInfo,a,b,i);rows[#rows+1]={link=l,qty=q} end
 return rows,title,quantity(GAMEPAD_PROVISIONER)
end
local function smith(o,t)
 local p=method(o,'GetSelectedPatternIndex');local m=method(o,'GetSelectedMaterialIndex');local q=method(o,'GetSelectedMaterialQuantity') or method(o,'GetSelectedMaterialCount') or method(o.materialQuantitySpinner,'GetValue')
 local style=method(o,'GetSelectedStyleIndex');local trait=method(o,'GetSelectedTraitIndex')
 if not p or not m or type(q)~='number' or q<1 then return end
 local rows={{link=s(GetSmithingPatternMaterialItemLink,p,m,LINK_STYLE_DEFAULT),qty=q}}
 if t~=CRAFTING_TYPE_JEWELRYCRAFTING then
  if type(style)~='number' or style<1 then return end
  if method(o,'IsUsingUniversalStyleItem') or method(o,'ShouldUseUniversalStyleItem') then style=s(GetUniversalStyleId);if not style then return end end
  rows[#rows+1]={link=s(GetSmithingStyleItemLink,style,LINK_STYLE_DEFAULT),qty=1}
 end
 if type(trait)~='number' then return end
 if trait>1 then rows[#rows+1]={link=s(GetSmithingTraitItemLink,trait,LINK_STYLE_DEFAULT),qty=1} end
 local l=s(GetSmithingPatternResultLink,p,m,q,style or 0,trait,LINK_STYLE_DEFAULT)
 return rows,s(GetItemLinkName,l) or 'Selected equipment',quantity(o)
end
local function slotLink(slot)
 local b,i=method(slot,'GetBagAndSlot');if type(b)~='number' or type(i)~='number' then return end
 return s(GetItemLink,b,i,LINK_STYLE_DEFAULT)
end
local function slotted(o,alchemy)
 if not o then return end
 local rows={};local function append(slot) local l=slotLink(slot);if not key(l) then return false end;rows[#rows+1]={link=l,qty=1};return true end
 if alchemy then
  if not append(o.solventSlot) then return end
  local n=0;for _,slot in ipairs(o.reagentSlots or {}) do if append(slot) then n=n+1 end end
  if n<2 then return end
 else
  if not append(o.potencySlot or o.potencyRuneSlot) or not append(o.essenceSlot or o.essenceRuneSlot) or not append(o.aspectSlot or o.aspectRuneSlot) then return end
 end
 return rows,alchemy and 'Selected potion / poison' or 'Selected glyph',quantity(o)
end
local function selected()
 local t=s(GetCraftingInteractionType)
 if t==CRAFTING_TYPE_PROVISIONING then if showing(GAMEPAD_PROVISIONER_CREATION_SCENE) then return recipe() end
 elseif t==CRAFTING_TYPE_ALCHEMY then if showing(GAMEPAD_ALCHEMY_CREATION_SCENE) then return slotted(GAMEPAD_ALCHEMY,true) end
 elseif t==CRAFTING_TYPE_ENCHANTING then if showing(GAMEPAD_ENCHANTING_CREATION_SCENE) or (GAMEPAD_ENCHANTING and ZO_ENCHANTING_MODE_CREATION and method(GAMEPAD_ENCHANTING,'GetMode')==ZO_ENCHANTING_MODE_CREATION) then return slotted(GAMEPAD_ENCHANTING,false) end
 else
  local o=GAMEPAD_SMITHING and GAMEPAD_SMITHING.creationPanel or GAMEPAD_SMITHING_CREATION
  if visible(o) and (t==CRAFTING_TYPE_BLACKSMITHING or t==CRAFTING_TYPE_CLOTHIER or t==CRAFTING_TYPE_WOODWORKING or t==CRAFTING_TYPE_JEWELRYCRAFTING) then return smith(o,t) end
 end
end
local function recipeCheck()
 local rows,title,mult,known=selected();if not rows then return nil,'Select a complete creation recipe.' end
 if E.pending or not E.prev then return nil,'Updating HC ownership...' end
 local needs,order={},{}
 for _,r in ipairs(rows) do local k=key(r.link);if not k or type(r.qty)~='number' or r.qty<1 then return nil,'Selected material data unavailable.' end
  if not needs[k] then needs[k]={link=r.link,qty=0};order[#order+1]=k end;needs[k].qty=needs[k].qty+r.qty*mult
 end
 local lines={clean(title or 'Selected item')..' | '..mult..(known and ' craft(s)' or ' craft (quantity unverified)')};local eligible=true
 for _,k in ipairs(order) do local r=needs[k];local virtual=E.prev.v[k] or 0;local physical=math.max(0,(E.prev.p[k] or 0)-virtual)
  local available=math.min(own()[k] or 0,physical)+math.min(shared()[k] or 0,virtual)
  if available<r.qty then eligible=false end
  lines[#lines+1]=clean(s(GetItemLinkName,r.link) or name(k))..': '..available..'/'..r.qty
 end
 lines[#lines+1]=eligible and (known and 'HC CRAFTABLE' or 'HC CRAFTABLE (1 craft only)') or 'NOT HC CRAFTABLE'
 return eligible,table.concat(lines,'\n'),#lines
end
function N.economyTick()
 if not E.root then return end
 local show=active() and craft();E.root:SetHidden(not show);if not show then return end
 local ok,eligible,msg,lines=pcall(recipeCheck)
 if not ok then trace('Advisor: '..tostring(eligible));eligible=nil;msg='Selected crafting data unavailable.' end
 if eligible==nil then E.text:SetColor(.75,.75,.75,1) elseif eligible then E.text:SetColor(.45,.9,.45,1) else E.text:SetColor(1,.45,.45,1) end
 E.root:SetDimensions(510,math.max(100,30*((lines or 2)+1)));E.text:SetText('HARDCORE CRAFTING ADVISOR\n'..(msg or 'Select a creation recipe.'))
end
function N.economyDeath() c().ownership={};c().hcGold=0;E.loot={} end
function N.economyText(page)
 if not E.db then return 'Ledger unavailable' end
 if page==10 then local t={'INTEGRITY REVIEW — not automatic violations','First person: honor-based; difficulty selectable','Crafting: observed changes only',''};for i,v in ipairs(c().integrityNotes or {}) do if i>10 then break end;t[#t+1]=clean(v) end;return table.concat(t,'\n') end
 local rows={};for k,v in pairs(page==8 and own() or E.db.bank) do rows[#rows+1]={n=name(k),v=v} end;table.sort(rows,function(a,b) if E.sort==2 and a.v~=b.v then return a.v>b.v end;return a.n<b.n end);E.index=math.max(1,math.min(E.index,math.max(1,#rows)));local start=math.floor((E.index-1)/10)*10+1;local t={page==8 and 'PERSONAL OWNERSHIP LEDGER' or 'SHARED HARDCORE BANK','Experimental | native bank performs transfers','Entries: '..#rows..' | Sort: '..(E.sort==1 and 'Name' or 'Quantity'),' '};for i=start,math.min(#rows,start+9) do local r=rows[i];t[#t+1]=(i==E.index and '> ' or '   ')..r.n..' x'..r.v end;if #rows==0 then t[#t+1]='No eligible items recorded.' end;return table.concat(t,'\n')
end
function N.economyMove(dx,dy) if dx~=0 then E.sort=3-E.sort;E.index=1 else E.index=math.max(1,E.index+dy) end end

function N.economyRows(page) local rows={};if not E.db then return rows end;for k,v in pairs(page==8 and own() or E.db.bank) do local l=E.db.links[k] or k;rows[#rows+1]={name=name(k),qty=v,link=l,icon=s(GetItemLinkIcon,l),quality=s(GetItemLinkQuality,l) or 1} end;table.sort(rows,function(a,b) return a.name<b.name end);return rows end
function N.economyDebug() return clean(table.concat(E.debug,'\n')) end

-- Read-only intersection of physical Craft Bag and personal HC ownership.
function N.hcMaterialRows()
 local rows={};if not E.db or not BAG_VIRTUAL then return rows end
 local physical=scan(BAG_VIRTUAL);local owned=shared()
 for k in pairs(owned) do local l=E.db.links[k];if l then local _,_,q=s(GetItemLinkStacks,l);if type(q)=='number' and q>0 then physical[k]=math.max(physical[k] or 0,q) end end end
 for k,n in pairs(physical) do local v=math.min(n,owned[k] or 0);if v>0 then local l=E.db.links[k] or k;rows[#rows+1]={name=name(k),qty=v,physical=n,link=l,icon=s(GetItemLinkIcon,l),quality=s(GetItemLinkQuality,l) or 1} end end
 table.sort(rows,function(a,b) return a.name<b.name end);return rows
end

function N.hcActive() return E.db~=nil and N.hardcore.saved~=nil and active() end
function N.hcEligible(link,banked) if not N.hcActive() then return 0 end;local k=key(link);return k and ((banked and E.db.bank or own())[k] or 0) or 0 end
