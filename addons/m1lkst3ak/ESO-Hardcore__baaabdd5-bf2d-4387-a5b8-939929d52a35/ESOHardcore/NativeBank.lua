if ZO_CreateStringId then ZO_CreateStringId('SI_ESOHC_NATIVE_BANK_GRID_LAYER','Hardcore Bank Directions') end
-- Independent backpack grid; supported keybind callbacks only.
local N=ESOHardcore; local s=N.safe
local I={rows={},cells={},page=1,selected=1,category=1,sort=1,dirty=true};N.bank=I
local categories={'All','Weapons','Armor','Consumables','Materials','Other'}
local sorts={'Category','Name','Quality','Quantity','Market value'}
local function matches(v,...)
 for i=1,select('#',...) do local k=select(i,...);if k and _G[k]~=nil and v==_G[k] then return true end end
 return false
end
local function category(t)
 if matches(t,'ITEMTYPE_WEAPON') then return 2 end
 if matches(t,'ITEMTYPE_ARMOR') then return 3 end
 if matches(t,'ITEMTYPE_POTION','ITEMTYPE_POISON','ITEMTYPE_FOOD','ITEMTYPE_DRINK','ITEMTYPE_RECIPE','ITEMTYPE_CONTAINER','ITEMTYPE_SCROLL') then return 4 end
 if matches(t,'ITEMTYPE_BLACKSMITHING_RAW_MATERIAL','ITEMTYPE_BLACKSMITHING_MATERIAL','ITEMTYPE_CLOTHIER_RAW_MATERIAL','ITEMTYPE_CLOTHIER_MATERIAL','ITEMTYPE_WOODWORKING_RAW_MATERIAL','ITEMTYPE_WOODWORKING_MATERIAL','ITEMTYPE_JEWELRYCRAFTING_RAW_MATERIAL','ITEMTYPE_JEWELRYCRAFTING_MATERIAL','ITEMTYPE_INGREDIENT','ITEMTYPE_REAGENT','ITEMTYPE_POTION_BASE','ITEMTYPE_POISON_BASE','ITEMTYPE_ENCHANTING_RUNE_ASPECT','ITEMTYPE_ENCHANTING_RUNE_ESSENCE','ITEMTYPE_ENCHANTING_RUNE_POTENCY','ITEMTYPE_STYLE_MATERIAL','ITEMTYPE_ARMOR_TRAIT','ITEMTYPE_WEAPON_TRAIT','ITEMTYPE_JEWELRY_TRAIT','ITEMTYPE_RAW_MATERIAL','ITEMTYPE_BLACKSMITHING_BOOSTER','ITEMTYPE_CLOTHIER_BOOSTER','ITEMTYPE_WOODWORKING_BOOSTER','ITEMTYPE_JEWELRYCRAFTING_BOOSTER') then return 5 end
 return 6
end
local function fmt(n) if type(n)~='number' then return '—' end;return tostring(math.floor(n)) end
local function label(p,x,y,w,h,size)
 local a=WINDOW_MANAGER:CreateControl(nil,p,CT_LABEL);a:SetAnchor(TOPLEFT,p,TOPLEFT,x,y);a:SetDimensions(w,h);a:SetFont('$(BOLD_FONT)|'..size..'|soft-shadow-thick');a:SetColor(.94,.87,.72,1);return a
end
local function frame(p,x,y,w,h)
 local a=WINDOW_MANAGER:CreateControl(nil,p,CT_BACKDROP);a:SetAnchor(TOPLEFT,p,TOPLEFT,x,y);a:SetDimensions(w,h);a:SetCenterColor(.07,.06,.045,.96);a:SetEdgeTexture('',1,1,1);a:SetEdgeColor(.27,.45,.65,1);return a
end
local function bankBags() local b={BAG_BANK};if BAG_SUBSCRIBER_BANK and s(IsESOPlusSubscriber)==true then b[#b+1]=BAG_SUBSCRIBER_BANK end;return b end
local function readQuality(bag,slot,link)
 local q=s(GetItemLinkDisplayQuality,link) or s(GetItemDisplayQuality,bag,slot) or s(GetItemLinkQuality,link) or s(GetItemQuality,bag,slot)
 if type(q)~='number' then return 1 end
 local names={'TRASH','NORMAL','MAGIC','ARCANE','ARTIFACT','LEGENDARY'}
 for i,k in ipairs(names) do if _G['ITEM_DISPLAY_QUALITY_'..k]==q then return i-1 end end
 return math.max(0,math.min(5,q))
end
local function scan()
 local rows={};local cap,used=0,0
 local remaining={}
 local bags=I.deposit and {BAG_BACKPACK} or bankBags()
 for _,bag in ipairs(bags) do local size=s(GetBagSize,bag) or 0;cap=cap+size
 for slot=0,size-1 do
  local link=s(GetItemLink,bag,slot,LINK_STYLE_DEFAULT)
  if type(link)=='string' and link~='' then
   used=used+1;local icon,qty=s(GetItemInfo,bag,slot);qty=s(GetSlotStackSize,bag,slot) or qty or 1
   local t=s(GetItemType,bag,slot) or s(GetItemLinkItemType,link);local cat=category(t)
   local name=(s(GetItemLinkName,link) or link):gsub('%^%a+','');if zo_strformat then name=s(zo_strformat,'<<1>>',name) or name end
   local quality=readQuality(bag,slot,link)
   local value;local gs=GoldStandard;if gs and s(gs.IsSlotMarketable,gs,bag,slot,link)==true then value=s(gs.Estimate,gs,link,qty) end
   local k=link:gsub('|H%d+:','|H0:'):gsub('|h.-|h$','|h|h');if remaining[k]==nil then remaining[k]=N.hcEligible(link,not I.deposit) end;local physical=qty;local eligible=math.min(qty,remaining[k]);remaining[k]=remaining[k]-eligible
   if qty>0 and (I.category==1 or cat==I.category) then rows[#rows+1]={bag=bag,slot=slot,link=link,icon=icon or s(GetItemLinkIcon,link),qty=qty,physical=physical,eligible=eligible,name=name,quality=quality,cat=cat,value=value} end
  end
 end
 end
 table.sort(rows,function(a,b)
  if I.sort==1 and a.cat~=b.cat then return a.cat<b.cat end
  if I.sort==3 and a.quality~=b.quality then return a.quality>b.quality end
  if I.sort==4 and a.qty~=b.qty then return a.qty>b.qty end
  if I.sort==5 and (a.value or -1)~=(b.value or -1) then return (a.value or -1)>(b.value or -1) end
  if a.name~=b.name then return a.name<b.name end;if a.bag~=b.bag then return a.bag<b.bag end;return a.slot<b.slot
 end)
 I.rows=rows;I.cap=cap;I.used=used;I.dirty=false
end
local colors={{.65,.65,.65},{.94,.94,.94},{.25,.8,.3},{.25,.55,1},{.65,.35,.9},{.95,.75,.22}}
local rarity={'Trash','Normal','Fine','Superior','Epic','Legendary'}
local function qualityColor(q)
 return colors[math.max(1,math.min(6,(tonumber(q) or 1)+1))]
end
local function coloredName(e)
 local c=qualityColor(e.quality)
 local name=tostring(e.name):gsub('|[cC]%x%x%x%x%x%x',''):gsub('|[rR]','')
 return string.format('|c%02x%02x%02x%s|r',math.floor(c[1]*255+.5),math.floor(c[2]*255+.5),math.floor(c[3]*255+.5),name)
end
local function detail(e)
 if not e then I.detailTitle:SetColor(.94,.87,.72,1);I.detailTitle:SetText('No items in this category');I.detail:SetText('');return end
 local c=qualityColor(e.quality);I.detailTitle:SetColor(c[1],c[2],c[3],1);I.detailTitle:SetText(coloredName(e)..'  ×'..fmt(e.qty))
 local lines={rarity[e.quality+1] or ('Quality '..fmt(e.quality)), 'HC eligible: '..fmt(e.eligible or 0)..' / '..fmt(e.qty)}
 local function add(v) if type(v)=='string' and v~='' then lines[#lines+1]=v end end
 local function stat(n,v) if type(v)=='number' and v>0 then add(n..': '..fmt(v)) end end
 local link=e.link
 local typ=s(GetItemLinkItemType,link);if typ and GetString then add(s(GetString,'SI_ITEMTYPE',typ)) end
 if typ==ITEMTYPE_WEAPON then stat('Damage',s(GetItemLinkWeaponPower,link)) elseif typ==ITEMTYPE_ARMOR then stat('Armor',s(GetItemLinkArmorRating,link,true)) end
 local cp=s(GetItemLinkRequiredChampionPoints,link);if type(cp)=='number' and cp>0 then stat('Required CP',cp) else stat('Required level',s(GetItemLinkRequiredLevel,link)) end
 if s(DoesItemLinkHaveArmorDecay,link)==true then local v=s(GetItemLinkCondition,link);if type(v)=='number' then add('Condition: '..fmt(v)..'%') end end
 local locked=s(IsItemPlayerLocked,e.bag,e.slot)
 if locked==true then add('LOCKED') end
 local _,trait=s(GetItemLinkTraitInfo,link);add(trait)
 local _,_,enchant=s(GetItemLinkEnchantInfo,link);add(enchant)
 local has,_,ability=s(GetItemLinkOnUseAbilityInfo,link);if has then add(ability) end
 local set,name=s(GetItemLinkSetInfo,link,false);if set then add('Set: '..tostring(name or 'Unknown')) end
 stat('Vendor gold / item',s(GetItemLinkValue,link,true));if e.value then add('Market estimate: '..fmt(e.value)..'g') end
 I.detail:SetText(table.concat(lines,'\n'))
end
local currencies={{name='HC Gold',id=CURT_MONEY,mode='hc'},{name='Standard Gold',id=CURT_MONEY,mode='standard'}}
local function balance(c,loc) if c.id and loc then return s(GetCurrencyAmount,c.id,loc) or 0 end end
local function moneyfmt(n) if type(n)~='number' then return '—' end;local v=tostring(math.floor(n));return (v:reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,','')) end
local function render()
 if I.dirty then scan() end
 local total=math.max(1,math.ceil(#I.rows/60));I.page=math.max(1,math.min(total,I.page));local count=math.min(60,#I.rows-(I.page-1)*60);I.selected=math.max(1,math.min(math.max(1,count),I.selected))
 I.header:SetText('HARDCORE BANK  /  '..(I.deposit and 'DEPOSIT' or 'WITHDRAW')..'     •     '..I.used..' / '..I.cap..' slots')
 I.filter:SetText('Category: '..categories[I.category]..'     |     Sort: '..sorts[I.sort]..'     |     Page '..I.page..' / '..total)
 for j,c in ipairs(I.cells) do local e=I.rows[(I.page-1)*60+j];c.icon:SetHidden(not e);c.qty:SetText(e and e.qty>1 and fmt(e.qty) or '');local col=e and qualityColor(e.quality) or {.25,.21,.15};if e and e.icon then c.icon:SetTexture(e.icon) else c.icon:SetHidden(true) end;c.bg:SetEdgeColor(col[1],col[2],col[3],1);local active=j==I.selected and e~=nil;c.sel:SetHidden(not active);c.icon:SetColor(active and 1 or .78,active and 1 or .78,active and 1 or .78,1) end
 local e=I.rows[(I.page-1)*60+I.selected];detail(e)
 local h,b=N.hcGold();I.money[1]:SetText('HC Gold   Carried: '..moneyfmt(h)..'   |   Bank: '..moneyfmt(b));if I.money[2] then I.money[2]:SetText('Total gold   Carried: '..moneyfmt(balance(currencies[1],CURRENCY_LOCATION_CHARACTER))..'   |   Bank: '..moneyfmt(balance(currencies[1],CURRENCY_LOCATION_BANK))) end
end
local function build()
 local p=WINDOW_MANAGER:CreateTopLevelWindow('HCNativeBankGrid');I.root=p
 p:SetDimensions(1150,680);p:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
 local w,h=GuiRoot:GetDimensions();p:SetScale(math.min(1.05,w*.90/1150,h*.88/680));p:SetHidden(true);p:SetDrawTier(DT_HIGH)
 frame(p,0,0,1150,680)
 local headerRule=frame(p,24,88,1102,1);headerRule:SetEdgeColor(.40,.32,.19,1)
 I.header=label(p,24,16,1100,36,30);I.filter=label(p,24,56,1100,28,20)
 local panel=frame(p,825,100,301,515);panel:SetCenterColor(.045,.043,.038,.98);panel:SetEdgeColor(.40,.32,.19,1)
 for j=1,60 do
  local x=25+((j-1)%10)*80;local y=105+math.floor((j-1)/10)*75
  local bg=frame(p,x,y,68,68);bg:SetCenterColor(.025,.025,.023,1)
  local icon=WINDOW_MANAGER:CreateControl(nil,bg,CT_TEXTURE);icon:SetAnchor(CENTER,bg,CENTER,0,0);icon:SetDimensions(56,56)
  local qty=label(bg,3,44,61,22,18);qty:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  local sel=frame(bg,-4,-4,76,76);sel:SetCenterColor(0,0,0,0);sel:SetEdgeTexture('',4,4,4);sel:SetEdgeColor(1,.88,.35,1);sel:SetDrawLayer(DL_OVERLAY);sel:SetDrawLevel(10)
  for _,pos in ipairs({{0,0},{62,0},{0,62},{62,62}}) do
   local corner=frame(sel,pos[1],pos[2],14,14);corner:SetCenterColor(1,.88,.35,1);corner:SetEdgeColor(1,.96,.75,1);corner:SetDrawLayer(DL_OVERLAY);corner:SetDrawLevel(11)
  end
  sel:SetHidden(true)
  I.cells[j]={bg=bg,icon=icon,qty=qty,sel=sel}
 end
 I.detailTitle=label(p,840,114,271,76,23);I.detail=label(p,840,198,271,407,18)
 local footerRule=frame(p,24,628,1102,1);footerRule:SetEdgeColor(.40,.32,.19,1)
 I.money={};for j=1,2 do I.money[j]=label(p,24+(j-1)*550,638,545,34,17) end
end

local function current() return I.rows[(I.page-1)*60+I.selected] end
local function move(delta)
 local n=#I.rows;if n==0 then return end
 local old=(I.page-1)*60+I.selected; if delta==-1 and (old-1)%10==0 then return end; if delta==1 and old%10==0 then return end; local index=old+delta; if index<1 or index>n then return end; I.page=math.floor((index-1)/60)+1;I.selected=(index-1)%60+1;render()
end
local function filter(delta) I.category=(I.category-1+delta)%#categories+1;I.page=1;I.selected=1;I.dirty=true;render() end
local function sort() I.sort=I.sort%#sorts+1;I.page=1;I.selected=1;I.dirty=true;render() end
local function valid()
 local e=current();if not e then return end
 if s(GetItemLink,e.bag,e.slot,LINK_STYLE_DEFAULT)~=e.link then I.dirty=true;render();return end
 return e
end
local function notice(t) if d then d('Hardcore Bank: '..t) end end
-- Dedicated scene and explicit action layer. Restricted actions stay in native UI.
local nativeName='gamepad_banking'
local sceneName='HCNativeBankScene'
local function sceneNameNow()
 local scene=SCENE_MANAGER and s(SCENE_MANAGER.GetCurrentScene,SCENE_MANAGER)
 return scene and s(scene.GetName,scene)
end
local layerName='Hardcore Bank Directions'
local directions={LEFT='left',RIGHT='right',UP='up',DOWN='down'}
local function release()
 I.split=nil;if I.splitPanel then I.splitPanel:SetHidden(true) end
 I.menu=nil;I.currency=nil;if I.currencyPanel then I.currencyPanel:SetHidden(true) end;if I.actionPanel then I.actionPanel:SetHidden(true) end
 if I.directionLayer then I.directionLayer=false; if RemoveActionLayerByName then s(RemoveActionLayerByName,layerName) end end
 if I.focus then
  I.focus=false
  if I.keys and KEYBIND_STRIP then s(KEYBIND_STRIP.RemoveKeybindButtonGroup,KEYBIND_STRIP,I.keys) end
 end
 if I.root then I.root:SetHidden(true) end
end
local function native()
 I.bypass=true;release();SCENE_MANAGER:Show(nativeName)
end
local function back() release();SCENE_MANAGER:HideCurrentScene() end
local function handoff() native() end
local function secureAction(name,...)
 -- Never read a protected native function from _G: even type() can taint it.
 -- For known protected actions use only the supported string-based dispatcher.
 if name=='RequestMoveItem' or name=='UseItem' or s(IsProtectedFunction,name)==true then
  if type(CallSecureProtected)=='function' then return pcall(CallSecureProtected,name,...) end
  return false,'Secure API unavailable; use native UI'
 end
 -- Only explicitly documented public actions may use the direct path.
 if name=='RequestEquipItem' or name=='DestroyItem' or name=='TransferCurrency' then
  return pcall(function(...) local f=_G[name];if type(f)~='function' then return false end;return f(...) end,...)
 end
 return false,'Unsupported action; use native UI'
end
local function bankOpen() return INTERACTION_BANK~=nil and s(GetInteractionType)==INTERACTION_BANK end
local function findTarget(bags)
 for _,bag in ipairs(bags) do local slot=s(FindFirstEmptySlotInBag,bag);if type(slot)=='number' and slot>=0 and s(GetItemLink,bag,slot,LINK_STYLE_DEFAULT)=='' then return bag,slot end end
end
local function primary(e,kind)
 if I.pending or not bankOpen() or s(IsUnitInCombat,'player')~=false then notice('Bank action unavailable.');return end
 local function execute()
  if I.pending or not bankOpen() or s(IsUnitInCombat,'player')~=false or s(GetItemLink,e.bag,e.slot,LINK_STYLE_DEFAULT)~=e.link or s(GetSlotStackSize,e.bag,e.slot)~=(e.physical or e.qty) then notice('Bank or item changed; cancelled.');return end
  local name,args,dest,slot
  if kind=='Destroy' then
   if s(IsItemPlayerLocked,e.bag,e.slot)~=false then notice('Locked item protected.');return end
   name='DestroyItem';args={e.bag,e.slot}
  else
   if kind=='Deposit' and e.bag~=BAG_BACKPACK or kind=='Withdraw' and e.bag~=BAG_BANK and e.bag~=BAG_SUBSCRIBER_BANK then return end
   dest,slot=findTarget(kind=='Deposit' and bankBags() or {BAG_BACKPACK})
   if not dest then notice('No empty destination slot. R2 opens native bank for stacking.');return end
   name='RequestMoveItem';args={e.bag,e.slot,dest,slot,e.qty}
  end
  local ok,result=secureAction(name,(unpack or table.unpack)(args))
  if not ok or result==false then notice(kind..' unavailable. R2 opens native bank.');return end
  I.pending=true
  zo_callLater(function()
   I.pending=false;I.dirty=true
   local now=s(GetItemLink,e.bag,e.slot,LINK_STYLE_DEFAULT);local count=s(GetSlotStackSize,e.bag,e.slot)
   local changed=type(now)=='string' and (now~=e.link or (type(count)=='number' and count<e.qty))
   if changed and (not dest or s(GetItemLink,dest,slot,LINK_STYLE_DEFAULT)==e.link) then notice(kind..' confirmed.') else notice(kind..' not confirmed (return '..tostring(result)..'). R2 opens native bank.') end
  end,1500)
 end
 if not (ZO_Dialogs_RegisterCustomDialog and ZO_Dialogs_ShowGamepadDialog and GAMEPAD_DIALOGS and GAMEPAD_DIALOGS.BASIC and zo_callLater) then notice('Confirmation unavailable.');return end
 if not I.primaryDialog then
  ZO_Dialogs_RegisterCustomDialog('ESOHC_NATIVE_BANK_CONFIRM',{gamepadInfo={dialogType=GAMEPAD_DIALOGS.BASIC},title={text='Confirm bank action'},mainText={text='<<1>>'},buttons={{keybind='DIALOG_PRIMARY',text='Confirm',callback=function(dialog) if dialog.data and dialog.data.execute then dialog.data.execute() end end},{keybind='DIALOG_NEGATIVE',text='Cancel'}}});I.primaryDialog=true
 end
 ZO_Dialogs_ShowGamepadDialog('ESOHC_NATIVE_BANK_CONFIRM',{execute=execute},{mainTextParams={kind..' '..e.name..' ×'..fmt(e.qty)..(kind=='Destroy' and (' PERMANENTLY ('..(rarity[e.quality+1] or 'Unknown quality')..')') or '')..' ?'}})
end
local function closeMenu()
 I.menu=nil;if I.actionPanel then I.actionPanel:SetHidden(true) end
end
local function paintMenu()
 local m=I.menu;if not m then return end
 local color=qualityColor(m.item.quality);I.actionTitle:SetColor(color[1],color[2],color[3],1);I.actionTitle:SetText(coloredName(m.item))
 for j,l in ipairs(I.actionLabels) do
  local v=m.options[j];l:SetHidden(not v)
  if v then l:SetText((j==m.index and '>  ' or '    ')..v.label);if j==m.index then l:SetColor(1,.85,.4,1) else l:SetColor(.94,.87,.72,1) end end
 end
 I.actionPanel:SetHidden(false)
end
local function closeSplit() I.split=nil;if I.splitPanel then I.splitPanel:SetHidden(true) end end
local function paintSplit()
 local m=I.split;if not m then return end
 m.amount=math.max(1,math.min(m.item.qty-1,m.amount))
 local color=qualityColor(m.item.quality);I.splitTitle:SetColor(color[1],color[2],color[3],1);I.splitTitle:SetText('SPLIT STACK — '..coloredName(m.item))
 I.splitText:SetText('New stack: '..m.amount..'     Remaining: '..(m.item.qty-m.amount)..'\n\nLeft / Right: -1 / +1\nUp / Down: +10 / -10\nL1: quarter    R1: half\nSquare: leave one\n\nX: split     Circle: cancel')
end
local function openSplit(e)
 if I.pending or e.qty<2 then return end
 if not I.splitPanel then
  local p=frame(I.root,265,125,620,365);p:SetDrawLayer(DL_OVERLAY);p:SetDrawLevel(40);I.splitPanel=p
  I.splitTitle=label(p,20,15,580,50,23);I.splitTitle:SetDrawLayer(DL_OVERLAY);I.splitTitle:SetDrawLevel(41)
  I.splitText=label(p,20,75,580,270,22);I.splitText:SetDrawLayer(DL_OVERLAY);I.splitText:SetDrawLevel(41)
 end
 I.split={item=e,amount=math.floor(e.qty/2)};I.splitPanel:SetHidden(false);paintSplit()
end
local function executeSplit()
 local m=I.split;local e=m.item;local amount=m.amount
 if I.pending or not I.focus or not bankOpen() or s(IsUnitInCombat,'player')~=false or s(GetItemLink,e.bag,e.slot,LINK_STYLE_DEFAULT)~=e.link or s(GetSlotStackSize,e.bag,e.slot)~=(e.physical or e.qty) then closeSplit();notice('Split cancelled: item or interaction changed.');return end
 if amount<1 or amount>=e.qty then return end
 local slot=s(FindFirstEmptySlotInBag,e.bag)
 if type(slot)~='number' or slot<0 or s(GetItemLink,e.bag,slot,LINK_STYLE_DEFAULT)~='' then notice('Split requires an empty slot in the same bag.');return end
 if not zo_callLater then notice('Split verification unavailable.');return end
 closeSplit()
 local ok,result=secureAction('RequestMoveItem',e.bag,e.slot,e.bag,slot,amount)
 if not ok or result==false then notice('Split unavailable. R2 opens native bank.');return end
 I.pending=true;zo_callLater(function()
 I.pending=false;I.dirty=true
 if s(GetSlotStackSize,e.bag,e.slot)==e.qty-amount and s(GetItemLink,e.bag,slot,LINK_STYLE_DEFAULT)==e.link and s(GetSlotStackSize,e.bag,slot)==amount then notice('Split confirmed: '..amount..' / '..(e.qty-amount)) else notice('Split not confirmed (return '..tostring(result)..').') end
 end,1500)
end
local function itemActions()
 local e=valid();if not e then return end
 local opts={};local function add(label,kind) opts[#opts+1]={label=label,kind=kind} end
 local mode=I.deposit and 'Deposit' or 'Withdraw';add(mode..' entire stack',mode)
 if s(IsItemPlayerLocked,e.bag,e.slot)==false then add('Destroy item / stack','Destroy') end
 if e.qty>1 and e.bag~=BAG_WORN then add('Split stack','Split') end
 add('Cancel','Cancel')
 if not I.actionPanel then
  local p=frame(I.root,290,155,570,365);p:SetDrawLayer(DL_OVERLAY);p:SetDrawLevel(20);I.actionPanel=p
  I.actionTitle=label(p,20,12,530,55,23);I.actionTitle:SetDrawLayer(DL_OVERLAY);I.actionTitle:SetDrawLevel(21)
  I.actionLabels={};for j=1,8 do local l=label(p,20,70+(j-1)*35,530,33,21);l:SetDrawLayer(DL_OVERLAY);l:SetDrawLevel(21);I.actionLabels[j]=l end
 end
 I.menu={item=e,options=opts,index=1};paintMenu()
end
local function selectAction()
 local m=I.menu;local v=m.options[m.index];local e=m.item;closeMenu()
 if not v or v.kind=='Cancel' then return end
 if s(GetItemLink,e.bag,e.slot,LINK_STYLE_DEFAULT)~=e.link then notice('Item changed.');return end
 if v.kind=='Split' then openSplit(e);return end
 primary(e,v.kind)
end
local function closeCurrency() I.currency=nil;if I.currencyPanel then I.currencyPanel:SetHidden(true) end end
local function currencyMax(m)
 local c=currencies[m.index];local from=m.deposit and CURRENCY_LOCATION_CHARACTER or CURRENCY_LOCATION_BANK;local to=m.deposit and CURRENCY_LOCATION_BANK or CURRENCY_LOCATION_CHARACTER
 if not c.id or not from or not to then return 0 end
 local n=balance(c,from);if type(n)~='number' then return 0 end
 local limit=s(GetMaxCurrencyTransfer,c.id,from,to);if type(limit)=='number' then n=math.min(n,limit) else return 0 end
 return math.max(0,math.floor(n))
end
local function paintCurrency()
 local m=I.currency;if not m then return end
 local c=currencies[m.index];local limit=currencyMax(m);m.amount=math.min(limit,math.max(0,m.amount))
 I.currencyTitle:SetText('CURRENCY MANAGEMENT')
 I.currencyText:SetText((m.stage==1 and '> ' or '  ')..'Currency: '..c.name..'\n'..(m.stage==2 and '> ' or '  ')..'Direction: '..(m.deposit and 'Deposit' or 'Withdraw')..'\n'..(m.stage==3 and '> ' or '  ')..'Amount: '..moneyfmt(m.amount)..' / '..moneyfmt(limit)..'\n\nHC carried: '..moneyfmt(select(1,N.hcGold()))..'    HC bank: '..moneyfmt(select(2,N.hcGold()))..'\nTotal carried: '..moneyfmt(balance(c,CURRENCY_LOCATION_CHARACTER))..'    Total bank: '..moneyfmt(balance(c,CURRENCY_LOCATION_BANK))..'\n\nLeft / Right: change selection or amount\nUp / Down: select field     L1 / R1: amount step\nStep: '..moneyfmt(m.step)..'    Square: HC balance / total maximum\nX: confirm transfer    Circle: cancel')
end
local function openCurrency()
 if I.pending or not bankOpen() then return end
 if not I.currencyPanel then
  local p=frame(I.root,265,125,620,500);p:SetDrawLayer(DL_OVERLAY);p:SetDrawLevel(30);I.currencyPanel=p
  I.currencyTitle=label(p,20,15,580,45,25);I.currencyTitle:SetDrawLayer(DL_OVERLAY);I.currencyTitle:SetDrawLevel(31)
  I.currencyText=label(p,20,65,580,420,21);I.currencyText:SetDrawLayer(DL_OVERLAY);I.currencyText:SetDrawLevel(31)
 end
 I.currency={index=1,stage=1,deposit=I.deposit==true,amount=0,step=1};I.currencyPanel:SetHidden(false);paintCurrency()
end
local function transferFunds()
 local m=I.currency;local c=currencies[m.index];local amount=m.amount;local from=m.deposit and CURRENCY_LOCATION_CHARACTER or CURRENCY_LOCATION_BANK;local to=m.deposit and CURRENCY_LOCATION_BANK or CURRENCY_LOCATION_CHARACTER
 if amount<=0 or amount>currencyMax(m) or I.pending then notice('Invalid currency amount.');return end
 local kind=m.deposit and 'Deposit' or 'Withdraw'
 local function execute()
  if I.pending or not bankOpen() or not I.focus or s(IsUnitInCombat,'player')~=false or amount>currencyMax(m) then notice('Currency transfer cancelled: balance or interaction changed.');return end
  local before=s(GetCurrencyAmount,c.id,from);local target=s(GetCurrencyAmount,c.id,to);if type(before)~='number' or type(target)~='number' then return end
  N.goldTransferIntent(m.deposit,amount,c.mode);local ok,result=secureAction('TransferCurrency',c.id,amount,from,to);if not ok then N.cancelGoldTransferIntent(); notice('Currency transfer error: '..tostring(result));return end
  I.pending=true;zo_callLater(function() I.pending=false;local after=s(GetCurrencyAmount,c.id,from);local dest=s(GetCurrencyAmount,c.id,to);if after==before-amount and dest==target+amount then if N.refreshHCGold then N.refreshHCGold() end;notice(kind..' '..moneyfmt(amount)..' '..c.name..' confirmed.') else notice('Currency transfer not confirmed (return '..tostring(result)..'). R2 opens native bank.') end end,1500)
 end
 if not (ZO_Dialogs_RegisterCustomDialog and ZO_Dialogs_ShowGamepadDialog and GAMEPAD_DIALOGS and GAMEPAD_DIALOGS.BASIC and zo_callLater) then notice('Confirmation unavailable.');return end
 if not I.currencyDialog then ZO_Dialogs_RegisterCustomDialog('ESOHC_NATIVE_CURRENCY_CONFIRM',{gamepadInfo={dialogType=GAMEPAD_DIALOGS.BASIC},title={text='Confirm currency transfer'},mainText={text='<<1>>'},buttons={{keybind='DIALOG_PRIMARY',text='Confirm',callback=function(dialog) if dialog.data and dialog.data.execute then dialog.data.execute() end end},{keybind='DIALOG_NEGATIVE',text='Cancel'}}});I.currencyDialog=true end
 closeCurrency();ZO_Dialogs_ShowGamepadDialog('ESOHC_NATIVE_CURRENCY_CONFIRM',{execute=execute},{mainTextParams={kind..' '..moneyfmt(amount)..' '..c.name..' ?'}})
end
function HCNativeBankInput(action)
 if not I.focus or (ZO_Dialogs_IsShowingDialog and s(ZO_Dialogs_IsShowingDialog)) then return end
 if I.split then
  local m=I.split
  if action=='back' then closeSplit();return elseif action=='primary' then executeSplit();return
  elseif action=='left' then m.amount=m.amount-1 elseif action=='right' then m.amount=m.amount+1
  elseif action=='up' then m.amount=m.amount+10 elseif action=='down' then m.amount=m.amount-10
  elseif action=='prev' then m.amount=math.floor(m.item.qty/4) elseif action=='next' then m.amount=math.floor(m.item.qty/2)
  elseif action=='sort' then m.amount=m.item.qty-1 end
  paintSplit();return
 end
 if I.currency then
  local m=I.currency
  if action=='back' then closeCurrency();return elseif action=='primary' then transferFunds();return
  elseif action=='up' or action=='down' then m.stage=(m.stage-1+(action=='up' and -1 or 1))%3+1
  elseif action=='left' or action=='right' then local d=action=='left' and -1 or 1;if m.stage==1 then m.index=(m.index-1+d)%#currencies+1;m.amount=0 elseif m.stage==2 then m.deposit=not m.deposit;m.amount=0 else m.amount=m.amount+d*m.step end
  elseif action=='prev' then m.step=math.max(1,m.step/10) elseif action=='next' then m.step=math.min(100000000,m.step*10) elseif action=='sort' then local h,b=N.hcGold();m.amount=m.index==1 and math.min(currencyMax(m),m.deposit and h or b) or currencyMax(m) end
  paintCurrency();return
 end
 if I.menu then
  if action=='up' or action=='down' then local m=I.menu;m.index=(m.index-1+(action=='up' and -1 or 1))%#m.options+1;paintMenu()
  elseif action=='primary' then selectAction() elseif action=='back' then closeMenu() end
  return
 end
 if action=='left' then move(-1) elseif action=='right' then move(1)
 elseif action=='up' then move(-10) elseif action=='down' then move(10)
 elseif action=='prev' then filter(-1) elseif action=='next' then filter(1)
 elseif action=='mode' then I.deposit=not I.deposit;I.page=1;I.selected=1;I.dirty=true;render() elseif action=='sort' then sort() elseif action=='back' then back()
 elseif action=='currency' then openCurrency() elseif action=='native' then handoff() elseif action=='primary' then itemActions() end
end
local function setup()
 if I.scene then return true end
 if not (ZO_InteractScene and BANKING_INTERACTION and SCENE_MANAGER and KEYBIND_STRIP and FRAGMENT_GROUP and FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW) then
  I.disabled=true;notice('Native gamepad window group unavailable; keeping original inventory.');return false
 end
 if not I.root then build() end
 I.scene=ZO_InteractScene:New(sceneName,SCENE_MANAGER,BANKING_INTERACTION)
 I.scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
 if I.scene.SetInputPreferredMode and INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD then I.scene:SetInputPreferredMode(INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD) end
 -- Keybind strip is supplied by the native window group.
 if GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT then I.scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT) end
 I.keys={alignment=KEYBIND_STRIP_ALIGN_LEFT}
 local function key(binding,name,action,hidden)
  I.keys[#I.keys+1]={keybind=binding,name=name,ethereal=hidden,callback=function() HCNativeBankInput(action) end}
 end
 -- Directional keys are registered in Inventory/Bindings.xml, independently of keybind strip.
 key('UI_SHORTCUT_LEFT_SHOULDER','Category','prev');key('UI_SHORTCUT_RIGHT_SHOULDER','Category','next')
 key('UI_SHORTCUT_PRIMARY','Item actions','primary');key('UI_SHORTCUT_SECONDARY','Sort','sort')
 key('UI_SHORTCUT_TERTIARY','Deposit / Withdraw','mode')
 key('UI_SHORTCUT_LEFT_TRIGGER','Gold transfer','currency')
 key('UI_SHORTCUT_RIGHT_TRIGGER','Native bank','native')
 key('UI_SHORTCUT_NEGATIVE','Back','back')
 I.scene:RegisterCallback('StateChange',function(_,state)
  if state==SCENE_SHOWING then
   I.dirty=true;render();I.root:SetHidden(false)
  elseif state==SCENE_SHOWN then
   local ok,err=pcall(function() KEYBIND_STRIP:AddKeybindButtonGroup(I.keys) end)
   if ok then I.focus=true
    local ready=true
    for suffix in pairs(directions) do
     local action='ESOHC_NATIVE_BANK_GRID_'..suffix;local code=_G['KEY_GAMEPAD_DPAD_'..suffix]
     if not (CreateDefaultActionBind and code and KEY_INVALID and GetActionIndicesFromName and s(GetActionIndicesFromName,action)) then ready=false
     else local success=pcall(CreateDefaultActionBind,action,code,KEY_INVALID,KEY_INVALID,KEY_INVALID,KEY_INVALID);ready=ready and success end
    end
    if ready and PushActionLayerByName and RemoveActionLayerByName then
     local pushed=pcall(PushActionLayerByName,layerName);I.directionLayer=pushed
     if pushed and IsActionLayerActiveByName then ready=s(IsActionLayerActiveByName,layerName)==true else ready=pushed end
    else ready=false end
    local bound=0
    if GetHighestPriorityActionBindingInfoFromName then for suffix in pairs(directions) do if s(GetHighestPriorityActionBindingInfoFromName,'ESOHC_NATIVE_BANK_GRID_'..suffix,true)==_G['KEY_GAMEPAD_DPAD_'..suffix] then bound=bound+1 end end end
    notice('D-pad layer '..(ready and 'active' or 'unavailable')..'; verified bindings '..bound..'/4.') else I.disabled=true;release();notice(tostring(err));I.bypass=true;SCENE_MANAGER:Show(nativeName) end
  elseif state==SCENE_HIDING or state==SCENE_HIDDEN then release() end
 end)
 return true
end
function I.close() if I.focus then back() end end
local function tick()
 local name=sceneNameNow()
 if name==sceneName and not N.hcActive() then back();return end
 if name==sceneName then if not bankOpen() then back();return end;if I.focus then render() end;return end
 if I.focus then release() end
 if name==nativeName then
  if N.hcActive() and bankOpen() and not I.disabled and not I.bypass and not (ZO_Dialogs_IsShowingDialog and s(ZO_Dialogs_IsShowingDialog)) then
   if setup() then SCENE_MANAGER:Show(sceneName) end
  end
 else I.bypass=false end
end
function I.options() return {{type='checkbox',name='HCNative personal bank (experimental)',getFunc=function() return not I.disabled end,setFunc=function(v) I.disabled=not v;if not v and I.focus then native() end end},{type='description',text='D-pad grid. Follow the native keybind strip for item actions, sorting and native inventory fallback.'}} end
function I.open() if not N.hcActive() then return end;if bankOpen() then I.bypass=false;if setup() then SCENE_MANAGER:Show(sceneName) end end end
EVENT_MANAGER:RegisterForEvent('HCNativeBankInit',EVENT_ADD_ON_LOADED,function(_,name)
 if name~='ESOHardcore' then return end
 EVENT_MANAGER:UnregisterForEvent('HCNativeBankInit',EVENT_ADD_ON_LOADED)
 if EVENT_CLOSE_BANK then EVENT_MANAGER:RegisterForEvent('HCNativeBankClosed',EVENT_CLOSE_BANK,function() if sceneNameNow()==sceneName then back() end end) end
 if EVENT_INVENTORY_SINGLE_SLOT_UPDATE then EVENT_MANAGER:RegisterForEvent('HCNativeBankDirty',EVENT_INVENTORY_SINGLE_SLOT_UPDATE,function() I.dirty=true end) end
 if EVENT_INVENTORY_FULL_UPDATE then EVENT_MANAGER:RegisterForEvent('HCNativeBankFull',EVENT_INVENTORY_FULL_UPDATE,function() I.dirty=true end) end
 EVENT_MANAGER:RegisterForUpdate('HCNativeBankRefresh',250,function() local ok,err=pcall(tick);if not ok then release();I.disabled=true;notice(tostring(err));if sceneNameNow()==sceneName then s(SCENE_MANAGER.Show,SCENE_MANAGER,nativeName) end end end)
end)
