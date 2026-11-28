if ZO_CreateStringId then ZO_CreateStringId('SI_ONEPACK_NATIVE_GRID_LAYER','OnePack Inventory Directions') end
-- Independent backpack grid; supported keybind callbacks only.
local N=OnePack; local s=N.safe;local G=N.gear
local I={rows={},cells={},page=1,selected=1,category=1,sort=1,dirty=true};N.inventory=I
local PAGE_SIZE=60
local categories={'All','Weapons','Armor','Consumables','Materials','Other','Equipped','Furnishings'}
local sorts={'Category','Name','Quality','Quantity','Vendor value','TSC / Guild Trader Value'}
local function matches(v,...)
 for i=1,select('#',...) do local k=select(i,...);if k and _G[k]~=nil and v==_G[k] then return true end end
 return false
end
local function category(t)
 if matches(t,'ITEMTYPE_WEAPON') then return 2 end
 if matches(t,'ITEMTYPE_ARMOR') then return 3 end
 if matches(t,'ITEMTYPE_FURNISHING') then return 8 end
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
local function readQuality(bag,slot,link)
 local q=s(GetItemLinkDisplayQuality,link) or s(GetItemDisplayQuality,bag,slot) or s(GetItemLinkQuality,link) or s(GetItemQuality,bag,slot)
 if type(q)~='number' then return 1 end
 local names={'TRASH','NORMAL','MAGIC','ARCANE','ARTIFACT','LEGENDARY'}
 for i,k in ipairs(names) do if _G['ITEM_DISPLAY_QUALITY_'..k]==q then return i-1 end end
 return math.max(0,math.min(5,q))
end
local locations={'All carried','Backpack','Craft bag'}
I.location=1;I.query='';I.qualityFilter=0
local function scan()
 local rows={};local cap=s(GetBagSize,BAG_BACKPACK) or 0;local used=s(GetNumBagUsedSlots,BAG_BACKPACK) or 0
 local function visit(bag,slot)
  local link=s(GetItemLink,bag,slot,LINK_STYLE_DEFAULT)
  if type(link)~='string' or link=='' then return end
  local icon,qty=s(GetItemInfo,bag,slot);qty=s(GetSlotStackSize,bag,slot) or qty or 0
  if qty<=0 then return end
  local typ=s(GetItemType,bag,slot) or s(GetItemLinkItemType,link)
  local cat=bag==BAG_WORN and 7 or (bag==BAG_VIRTUAL and 5 or category(typ))
  local name=N.cleanName(s(GetItemLinkName,link) or link)
  local quality=readQuality(bag,slot,link)
  if (I.category==1 or cat==I.category) and (I.qualityFilter==0 or quality==I.qualityFilter-1) and N.matchesName(name,I.query) then
   rows[#rows+1]={bag=bag,slot=slot,link=link,icon=icon or s(GetItemLinkIcon,link),qty=qty,name=name,quality=quality,cat=cat,value=(s(GetItemLinkValue,link,true) or 0)*qty,uid=N.uid(bag,slot)}
  end
 end
 if I.category~=7 and I.location~=3 then for slot=0,cap-1 do visit(BAG_BACKPACK,slot) end end
 if BAG_VIRTUAL and I.category~=7 and I.location~=2 then
  local i=s(GetNextVirtualBagSlotId);local seen={}
  while type(i)=='number' and i>0 and not seen[i] do seen[i]=true;visit(BAG_VIRTUAL,i);i=s(GetNextVirtualBagSlotId,i) end
  if SHARED_INVENTORY then local cache=s(SHARED_INVENTORY.GetOrCreateBagCache,SHARED_INVENTORY,BAG_VIRTUAL);if type(cache)=='table' then for k,v in pairs(cache) do local slot=type(v)=='table' and (v.slotIndex or v.itemId) or k;if type(slot)=='number' and slot>0 and not seen[slot] then seen[slot]=true;visit(BAG_VIRTUAL,slot) end end end end
 end
 if BAG_WORN and (I.category==7 or (I.category==1 and I.location==1 and I.query~='')) then for slot=0,(s(GetBagSize,BAG_WORN) or 0)-1 do visit(BAG_WORN,slot) end end
 if I.sort==6 then N.prepareMarketSort(rows) end
 table.sort(rows,function(a,b)
  if I.sort==1 and a.cat~=b.cat then return a.cat<b.cat end
  if I.sort==3 and a.quality~=b.quality then return a.quality>b.quality end
  if I.sort==4 and a.qty~=b.qty then return a.qty>b.qty end
  if I.sort==5 and a.value~=b.value then return a.value>b.value end
  if I.sort==6 and (a.marketTotal or -1)~=(b.marketTotal or -1) then return (a.marketTotal or -1)>(b.marketTotal or -1) end
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
 if not e then I.detailTitle:SetColor(.94,.87,.72,1);I.detailTitle:SetText('No items in this category');N.showDetails(I,nil,{});return end
 local c=qualityColor(e.quality);I.detailTitle:SetColor(c[1],c[2],c[3],1);I.detailTitle:SetText(coloredName(e)..'  ×'..fmt(e.qty))
 local lines={rarity[e.quality+1] or ('Quality '..fmt(e.quality))}
 local function add(v) if type(v)=='string' and v~='' then lines[#lines+1]=v end end
 add(N.bagName(e.bag))
 local function stat(n,v) if type(v)=='number' and v>0 then add(n..': '..fmt(v)) end end
 local link=e.link
 local typ=s(GetItemLinkItemType,link);if typ and GetString then add(s(GetString,'SI_ITEMTYPE',typ)) end
 add(N.equipmentType(link))
 if typ==ITEMTYPE_WEAPON then stat('Damage',s(GetItemLinkWeaponPower,link)) elseif typ==ITEMTYPE_ARMOR then stat('Armor',s(GetItemLinkArmorRating,link,true)) end
 local cp=s(GetItemLinkRequiredChampionPoints,link);if type(cp)=='number' and cp>0 then stat('Required CP',cp) else stat('Required level',s(GetItemLinkRequiredLevel,link)) end
 if s(DoesItemLinkHaveArmorDecay,link)==true then local v=s(GetItemLinkCondition,link);if type(v)=='number' then add('Condition: '..fmt(v)..'%') end end
 local locked=s(IsItemPlayerLocked,e.bag,e.slot)
 if locked==true then add('LOCKED') end
 local _,trait=s(GetItemLinkTraitInfo,link);add(trait)
 local _,_,enchant=s(GetItemLinkEnchantInfo,link);add(enchant)
 local has,_,ability=s(GetItemLinkOnUseAbilityInfo,link);if has then add(ability) end
 stat('Vendor gold / item',s(GetItemLinkValue,link,true))
 for _,line in ipairs(N.marketLines(e)) do add(line) end
 for _,line in ipairs(N.setLines(link)) do add(line) end
 N.showDetails(I,e,lines)
end
local dollSlots=G.slots
local function wornEntry(index)
 local v=dollSlots[index];local slot=v and _G['EQUIP_SLOT_'..v[1]]
 if type(slot)~='number' or not BAG_WORN then return end
 local link=s(GetItemLink,BAG_WORN,slot,LINK_STYLE_DEFAULT)
 if type(link)~='string' or link=='' then return end
 return {bag=BAG_WORN,slot=slot,link=link,icon=s(GetItemInfo,BAG_WORN,slot) or s(GetItemLinkIcon,link),qty=1,name=N.cleanName(s(GetItemLinkName,link) or link),quality=readQuality(BAG_WORN,slot,link),cat=7,uid=N.uid(BAG_WORN,slot)}
end
local function renderDoll()
 I.dollTitle:SetText(I.dollFocus and 'EQUIPPED  •  SELECT' or 'EQUIPPED')
 I.gearHint:SetText((I.dollFocus and 'Square: Gear presets  v' or 'Triangle: Equipped gear')..'\n'..(G.job and G.status or G.selected and ('Last preset: '..G.selected) or 'Save / load equipment'))
 for j,c in ipairs(I.dollCells) do
  local e=wornEntry(j);local col=e and qualityColor(e.quality) or {.30,.25,.18}
  c.bg:SetEdgeColor(col[1],col[2],col[3],1);c.icon:SetHidden(not (e and e.icon));if e and e.icon then c.icon:SetTexture(e.icon) end
  c.sel:SetHidden(not (I.dollFocus and I.dollSelected==j))
 end
end
local function render()
 if I.dirty then scan() end
 local total=math.max(1,math.ceil(#I.rows/PAGE_SIZE));I.page=math.max(1,math.min(total,I.page));local count=math.min(PAGE_SIZE,#I.rows-(I.page-1)*PAGE_SIZE);I.selected=math.max(1,math.min(math.max(1,count),I.selected))
 I.header:SetText('ONEPACK INVENTORY     •     '..I.used..' / '..I.cap..' backpack slots')
 I.filter:SetText(locations[I.location]..'  |  '..categories[I.category]..'  |  '..(I.sort==6 and N.marketSortLabel() or sorts[I.sort])..'  |  '..N.qualityName(I.qualityFilter)..'  |  '..#I.rows..' items  |  Page '..I.page..' / '..total)
 I.searchLabel:SetText('Search: '..(I.query~='' and I.query or 'All names')..'\nL2: Search / clear   L3: Location   R3: Quality')
 for j,c in ipairs(I.cells) do local e=I.rows[(I.page-1)*PAGE_SIZE+j];c.icon:SetHidden(not e);c.qty:SetText(e and e.qty>1 and fmt(e.qty) or '');local col=e and qualityColor(e.quality) or {.25,.21,.15};if e and e.icon then c.icon:SetTexture(e.icon) else c.icon:SetHidden(true) end;c.bg:SetEdgeColor(col[1],col[2],col[3],1);local active=not I.dollFocus and j==I.selected and e~=nil;c.sel:SetHidden(not active);c.icon:SetColor(active and 1 or .78,active and 1 or .78,active and 1 or .78,1) end
 renderDoll()
 local e=I.rows[(I.page-1)*PAGE_SIZE+I.selected]
 if I.dollFocus then
  e=wornEntry(I.dollSelected);detail(e)
  if not e then I.detailTitle:SetColor(.94,.87,.72,1);I.detailTitle:SetText(dollSlots[I.dollSelected][2]);I.detail:SetText('Empty equipment slot') end
 else detail(e) end
 I.money:SetText('Gold: '..fmt(N.gold())..'    •    Backpack: '..I.used..' / '..I.cap..'    •    Craft bag included in All carried')
end
local function build()
 local p=WINDOW_MANAGER:CreateTopLevelWindow('OnePackNativeInventoryGrid');I.root=p
 p:SetDimensions(1520,680);p:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
 local w,h=GuiRoot:GetDimensions();p:SetScale(math.min(1.05,w*.94/1520,h*.88/680));p:SetHidden(true);p:SetDrawTier(DT_HIGH)
 frame(p,0,0,1520,680)
 local doll=frame(p,12,100,254,515);doll:SetCenterColor(.045,.043,.038,.98)
 I.dollTitle=label(doll,8,6,238,26,20);I.dollTitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
 I.gearHint=label(p,15,620,248,52,16)
 I.dollCells={};I.dollSelected=1
 -- Native control artwork: no external texture dependency.
 for j,v in ipairs(dollSlots) do
  local x=(j%2==1) and 17 or 181;local y=36+math.floor((j-1)/2)*67
  local bg=frame(doll,x,y,56,48);bg:SetCenterColor(.025,.025,.023,1)
  local icon=WINDOW_MANAGER:CreateControl(nil,bg,CT_TEXTURE);icon:SetAnchor(CENTER,bg,CENTER,0,0);icon:SetDimensions(44,44)
  local txt=label(doll,x-12,y+48,80,18,12);txt:SetHorizontalAlignment(TEXT_ALIGN_CENTER);txt:SetText(v[2])
  local sel=frame(bg,-3,-3,62,54);sel:SetCenterColor(0,0,0,0);sel:SetEdgeTexture('',4,4,4);sel:SetEdgeColor(1,.88,.35,1);sel:SetDrawLayer(DL_OVERLAY);sel:SetDrawLevel(10);sel:SetHidden(true)
  I.dollCells[j]={bg=bg,icon=icon,sel=sel}
 end
 local content=WINDOW_MANAGER:CreateControl(nil,p,CT_CONTROL);content:SetAnchor(TOPLEFT,p,TOPLEFT,270,0);content:SetDimensions(1250,680);p=content
 local headerRule=frame(p,24,88,1202,1);headerRule:SetEdgeColor(.40,.32,.19,1)
 I.header=label(p,24,16,1200,36,30);I.filter=label(p,24,56,1200,28,20)
 I.searchLabel=label(p,25,565,780,54,18)
 local panel=frame(p,825,100,401,515);panel:SetCenterColor(.045,.043,.038,.98);panel:SetEdgeColor(.40,.32,.19,1)
 for j=1,PAGE_SIZE do
  local x=25+((j-1)%10)*80;local y=105+math.floor((j-1)/10)*75
  local bg=frame(p,x,y,68,68);bg:SetCenterColor(.025,.025,.023,1)
  local icon=WINDOW_MANAGER:CreateControl(nil,bg,CT_TEXTURE);icon:SetAnchor(CENTER,bg,CENTER,0,0);icon:SetDimensions(56,56)
  local qty=label(bg,3,44,61,22,18);qty:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  local sel=frame(bg,-4,-4,76,76);sel:SetCenterColor(0,0,0,0);sel:SetEdgeTexture('',4,4,4);sel:SetEdgeColor(1,.88,.35,1);sel:SetDrawLayer(DL_OVERLAY);sel:SetDrawLevel(10)
  sel:SetHidden(true)
  I.cells[j]={bg=bg,icon=icon,qty=qty,sel=sel}
 end
 I.detailTitle=label(p,840,114,371,76,23);I.detail=label(p,840,198,371,397,17);I.detail:SetVerticalAlignment(TEXT_ALIGN_TOP);I.detailHint=label(p,840,595,371,19,13)
 local footerRule=frame(p,24,628,1202,1);footerRule:SetEdgeColor(.40,.32,.19,1)
 I.money=label(p,24,641,1202,30,22)
end

local function current() if I.dollFocus then return wornEntry(I.dollSelected) end;return I.rows[(I.page-1)*PAGE_SIZE+I.selected] end
local function move(delta)
 local n=#I.rows;if n==0 then return end
 local old=(I.page-1)*PAGE_SIZE+I.selected; if delta==-1 and (old-1)%10==0 then return end; if delta==1 and old%10==0 then return end; local index=old+delta; if index<1 or index>n then return end; I.page=math.floor((index-1)/PAGE_SIZE)+1;I.selected=(index-1)%PAGE_SIZE+1;render()
end
local function filter(delta) I.category=(I.category-1+delta)%#categories+1;I.page=1;I.selected=1;I.dirty=true;render() end
local function sort() I.sort=I.sort%#sorts+1;I.page=1;I.selected=1;I.dirty=true;render() end
local function valid()
 local e=current();if not e then return end;
 if not N.same(e) then I.dirty=true;render();return end
 return e
end
local function notice(t) if d then d('OnePack Inventory: '..t) end end
-- Dedicated scene and explicit action layer. Restricted actions stay in native UI.
local nativeName='gamepad_inventory_root'
local sceneName='OnePackNativeInventoryScene'
local function sceneNameNow()
 local scene=SCENE_MANAGER and s(SCENE_MANAGER.GetCurrentScene,SCENE_MANAGER)
 return scene and s(scene.GetName,scene)
end
local layerName='OnePack Inventory Directions'
local directions={LEFT='left',RIGHT='right',UP='up',DOWN='down'}
local function release()
 if G.job then G.job.cancelled=true end
 I.gearMenu=nil;if I.gearPanel then I.gearPanel:SetHidden(true) end
 I.dollFocus=false;I.searching=false;I.suspendedLayer=false
 I.split=nil;if I.splitPanel then I.splitPanel:SetHidden(true) end
 I.menu=nil;if I.actionPanel then I.actionPanel:SetHidden(true) end
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
-- Radial gear changes use the same verified move engine without opening the grid.
function I.gameplayReady()
 local scene=sceneNameNow()
 return (scene=='hud' or scene=='hudui') and not I.focus and N.enabled() and not (N.bank and N.bank.focus) and s(IsBankOpen)~=true and s(IsUnitInCombat,'player')==false
end
function I.loadFromRadial(name)
 if not I.gameplayReady() then return false,'Use the gear wheel from gameplay outside combat and away from the bank.' end
 if s(ZO_Dialogs_IsShowingDialog)==true then return false,'Close the active dialog before changing gear.' end
 if not G.init() then return false,G.status end
 return G.load(I,name,secureAction,true)
end
-- Gear preset dropdown, scoped to the Equipped panel.
local function closeGear() I.gearMenu=nil;if I.gearPanel then I.gearPanel:SetHidden(true) end end
local function paintGear()
 local m=I.gearMenu;if not m then return end
 I.gearTitle:SetText(m.name and ('GEAR PRESET: '..m.name) or 'GEAR PRESETS')
 I.gearInfo:SetText(m.name and 'Load, replace with current equipment, or delete.' or 'Select a saved set or save your current gear.')
 for j,l in ipairs(I.gearLabels) do
  local idx=math.floor((m.index-1)/8)*8+j;local v=m.options[idx];l:SetHidden(not v)
  if v then l:SetText((idx==m.index and '>  ' or '    ')..v.label);if idx==m.index then l:SetColor(1,.85,.4,1) else l:SetColor(.94,.87,.72,1) end end
 end
 I.gearFooter:SetText((G.status or 'X: Select   Circle: Back')..'\nPage '..math.ceil(m.index/8)..' / '..math.ceil(#m.options/8))
 I.gearPanel:SetHidden(false)
end
local function openGear(name)
 if I.pending then return end
 if not G.init() then notice(G.status or 'Gear storage unavailable.');return end
 if not I.gearPanel then
  local p=frame(I.root,280,105,760,485);p:SetDrawLayer(DL_OVERLAY);p:SetDrawLevel(30);I.gearPanel=p
  I.gearTitle=label(p,20,12,720,38,24);I.gearTitle:SetDrawLayer(DL_OVERLAY);I.gearTitle:SetDrawLevel(31)
  I.gearInfo=label(p,20,50,720,42,18);I.gearInfo:SetDrawLayer(DL_OVERLAY);I.gearInfo:SetDrawLevel(31)
  I.gearLabels={};for j=1,8 do local l=label(p,20,94+(j-1)*36,720,35,21);l:SetDrawLayer(DL_OVERLAY);l:SetDrawLevel(31);I.gearLabels[j]=l end
  I.gearFooter=label(p,20,385,720,90,17);I.gearFooter:SetDrawLayer(DL_OVERLAY);I.gearFooter:SetDrawLevel(31)
 end
 local options={};local function add(label,kind,value) options[#options+1]={label=label,kind=kind,value=value} end
 if name and G.sets[name] then
  add('Load this preset','load',name);add('Overwrite with currently equipped gear','overwrite',name);add('Delete this preset','delete',name);add('Back to presets','list')
 else
  name=nil;add('+ Save currently equipped as new preset','save')
  for _,v in ipairs(G.names()) do add(v,'select',v) end
  add('Close','close')
 end
 local index=1;if not name and G.selected then for j,v in ipairs(options) do if v.value==G.selected then index=j;break end end end
 I.gearMenu={name=name,options=options,index=index};paintGear()
end
local function gearResult(ok,err)
 if not ok then G.status=err or 'Gear preset action unavailable.';notice(G.status) end
 I.dirty=true;if I.gearMenu then paintGear() end
end
local function selectGear()
 local m=I.gearMenu;local v=m and m.options[m.index];if not v then return end
 if v.kind=='select' then openGear(v.value);return elseif v.kind=='list' then openGear();return elseif v.kind=='close' then closeGear();return end
 if v.kind=='save' then
  if not G.promptName(I,layerName,function(name) if not I.focus then return end;local ok,err=G.save(name,false);gearResult(ok,err);if ok then openGear() end end) then gearResult(false,'Keyboard unavailable.') end;return
 end
 local name=v.value
 if v.kind=='load' then
  if s(IsUnitInCombat,'player')~=false or s(IsBankOpen)==true then gearResult(false,'Gear changes require being outside combat and the bank.');return end
  local plan,err=G.plan(G.sets[name]);if not plan then gearResult(false,err);return end
  if #plan==0 then G.selected=name;gearResult(true);G.status=name..' is already equipped.';paintGear();return end
  if not G.confirm('Equip '..name..'? '..#plan..' item moves. Empty saved slots will be cleared. An interrupted swap may leave gear partially changed.',function()
   if not I.focus then return end;closeGear();local ok,why=G.load(I,name,secureAction);gearResult(ok,why);if not ok then openGear(name) end
  end) then gearResult(false,'Confirmation unavailable.') end
 elseif v.kind=='overwrite' or v.kind=='delete' then
  local text=v.kind=='overwrite' and ('Replace '..name..' with currently equipped gear?') or ('Delete saved preset '..name..'? Items are not deleted.')
  if not G.confirm(text,function() if not I.focus then return end;local ok,err;if v.kind=='overwrite' then ok,err=G.save(name,true) else ok,err=G.delete(name) end;gearResult(ok,err);if ok then openGear() end end) then gearResult(false,'Confirmation unavailable.') end
 end
end
local function destination(e)
 local typ=s(GetItemEquipType,e.bag,e.slot)
 if type(typ)~='number' then typ=s(GetItemLinkEquipType,e.link) end
 local map={HEAD={'HEAD'},CHEST={'CHEST'},SHOULDERS={'SHOULDERS'},WAIST={'WAIST'},LEGS={'LEGS'},FEET={'FEET'},HAND={'HAND'},NECK={'NECK'},RING={'RING1','RING2'},MAIN_HAND={'MAIN_HAND'},ONE_HAND={'MAIN_HAND'},TWO_HAND={'MAIN_HAND'},OFF_HAND={'OFF_HAND'},COSTUME={'COSTUME'}}
 for k,slots in pairs(map) do
  if _G['EQUIP_TYPE_'..k]~=nil and typ==_G['EQUIP_TYPE_'..k] then
   for _,v in ipairs(slots) do local slot=_G['EQUIP_SLOT_'..v];if type(slot)=='number' and s(GetItemLink,BAG_WORN,slot,LINK_STYLE_DEFAULT)=='' then return slot,v end end
   local v=slots[1];return _G['EQUIP_SLOT_'..v],v
  end
 end
end
local function isContainer(e)
 return matches(s(GetItemLinkItemType,e.link),'ITEMTYPE_CONTAINER','ITEMTYPE_CONTAINER_CURRENCY','ITEMTYPE_CONTAINER_EVENT','ITEMTYPE_CONTAINER_STYLE_PAGE')
end
local function primary(e,chosen,destChoice)
 if not e or not N.enabled() then return end
 if s(IsUnitInCombat,'player')~=false then notice('Direct actions require being out of combat.');return end
 if I.pending then notice('Waiting for previous action.');return end
 local name,args,kind
 if chosen=='Destroy' then
  if e.bag~=BAG_BACKPACK or s(IsItemPlayerLocked,e.bag,e.slot)~=false then notice('Item is protected.');return end
  name='DestroyItem';args={e.bag,e.slot};kind='Destroy'
 elseif chosen=='Unequip' then
  local free=s(FindFirstEmptySlotInBag,BAG_BACKPACK)
  if type(free)~='number' or free<0 or s(GetItemLink,BAG_BACKPACK,free,LINK_STYLE_DEFAULT)~='' then notice('No confirmed free backpack slot.');return end
  name='RequestMoveItem';args={e.bag,e.slot,BAG_BACKPACK,free,1};kind='Unequip'
 elseif chosen=='Equip' then
  local dest,slotName=destination(e)
  if destChoice then dest=destChoice.slot;slotName=destChoice.label end
  if type(dest)~='number' then notice('No supported equipment destination. Use R2.');return end
  name='RequestMoveItem';args={e.bag,e.slot,BAG_WORN,dest,1};kind='Equip'
  e.actionDestination=slotName
 else
  local usable,quick=s(IsItemUsable,e.bag,e.slot)
  if usable~=true or quick==true then notice('Item cannot be used directly. R2 opens native inventory.');return end
  -- Equipment uses the dedicated native equip action.
  local typ=s(GetItemLinkItemType,e.link)
  if s(CanInteractWithItem,e.bag,e.slot)==false then notice('Item unavailable.');return end
  if typ==ITEMTYPE_ARMOR or typ==ITEMTYPE_WEAPON then notice('Use Equip or the native inventory for equipment.');return end
  name='UseItem';args={e.bag,e.slot};kind=isContainer(e) and 'Open container' or 'Use'
 end
 local function execute()
  if not N.same(e) or s(IsUnitInCombat,'player')~=false or s(GetSlotStackSize,e.bag,e.slot)~=e.qty then notice('Item or combat state changed.');return end
  local before=s(GetSlotStackSize,e.bag,e.slot)
  if kind=='Destroy' and (s(IsItemPlayerLocked,e.bag,e.slot)~=false or before~=e.qty or N.canDestroy(e)~=true) then notice('Lock or stack changed; destruction cancelled.');return end
  if kind=='Unequip' and s(GetItemLink,BAG_BACKPACK,args[4],LINK_STYLE_DEFAULT)~='' then notice('Backpack destination changed; retry.');return end
  if kind=='Equip' or kind=='Unequip' then
   if kind=='Equip' and (s(FindFirstEmptySlotInBag,BAG_BACKPACK) or -1)<0 then notice('Keep one backpack slot free before swapping equipment.');return end
  end
  local oldDestination=(kind=='Equip' or kind=='Unequip') and s(GetItemLink,args[3],args[4],LINK_STYLE_DEFAULT) or nil
  -- Yield the custom scene before opening a container so native loot can own focus.
  local function perform()
  if kind=='Open container' and (not N.same(e) or s(IsUnitInCombat,'player')~=false) then I.pending=false;notice('Container or combat state changed.');return end
  local ok,result=secureAction(name,(unpack or table.unpack)(args))
  if not ok then I.pending=false;notice(kind..' API error: '..tostring(result)..'. R2 opens native inventory.');return end
  if result==false then I.pending=false;notice(kind..' rejected. R2 opens native inventory.');return end
  I.pending=true;notice(kind..' requested via '..name..' (return '..tostring(result)..'); checking inventory.')
  zo_callLater(function()
   I.pending=false;I.dirty=true
   local now=s(GetItemLink,e.bag,e.slot,LINK_STYLE_DEFAULT);local count=s(GetSlotStackSize,e.bag,e.slot)
   local equipment=kind=='Equip' or kind=='Unequip'
   local moved=equipment and s(GetItemLink,args[3],args[4],LINK_STYLE_DEFAULT)==e.link and (now~=e.link or oldDestination~=e.link)
   if moved or (not equipment and type(now)=='string' and (now~=e.link or (type(before)=='number' and type(count)=='number' and count<before))) then notice(kind..': inventory change confirmed.') else notice(kind..' not confirmed via '..name..'. R2 opens native inventory.') end
  end,kind=='Open container' and 6000 or 1500)
  end
  if kind=='Open container' then
   I.pending=true
   zo_callLater(function()
    if sceneNameNow()~=sceneName then I.pending=false;notice('Container opening cancelled: inventory closed.');return end
    back()
    zo_callLater(function()
     if sceneNameNow()==sceneName or (ZO_Dialogs_IsShowingDialog and s(ZO_Dialogs_IsShowingDialog)) then I.pending=false;notice('Container opening cancelled: UI still busy.');return end
     perform()
    end,500)
   end,250)
  else perform() end
 end
 if not (ZO_Dialogs_RegisterCustomDialog and ZO_Dialogs_ShowGamepadDialog and GAMEPAD_DIALOGS and GAMEPAD_DIALOGS.BASIC and zo_callLater) then notice('Confirmation unavailable. Use R2.');return end
 if not I.primaryDialog then
  ZO_Dialogs_RegisterCustomDialog('ONEPACK_NATIVE_PRIMARY_CONFIRM',{gamepadInfo={dialogType=GAMEPAD_DIALOGS.BASIC},title={text='Confirm item action'},mainText={text='<<1>>'},buttons={{keybind='DIALOG_PRIMARY',text='Confirm',callback=function(dialog) if dialog.data and dialog.data.execute then dialog.data.execute() end end},{keybind='DIALOG_NEGATIVE',text='Cancel'}}})
  I.primaryDialog=true
 end
 ZO_Dialogs_ShowGamepadDialog('ONEPACK_NATIVE_PRIMARY_CONFIRM',{execute=execute},{mainTextParams={kind..' '..e.name..(kind=='Destroy' and (' — ENTIRE STACK ×'..fmt(e.qty)..' ('..(rarity[e.quality+1] or 'Unknown quality')..') permanently') or '')..(kind=='Equip' and (' -> '..tostring(e.actionDestination)..(s(ZO_InventorySlot_WillItemBecomeBoundOnEquip,e.bag,e.slot)==true and ' (will bind this item)' or '')) or '')..' ?'}})
end
local function closeMenu()
 I.menu=nil;if I.actionPanel then I.actionPanel:SetHidden(true) end
end
local function paintMenu()
 local m=I.menu;if not m then return end
 local color=qualityColor(m.item.quality);I.actionTitle:SetColor(color[1],color[2],color[3],1);I.actionTitle:SetText(coloredName(m.item))
 for j,l in ipairs(I.actionLabels) do
  local idx=math.floor((m.index-1)/10)*10+j;local v=m.options[idx];l:SetHidden(not v)
  if v then l:SetText((idx==m.index and '>  ' or '    ')..v.label);if idx==m.index then l:SetColor(1,.85,.4,1) else l:SetColor(.94,.87,.72,1) end end
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
  local p=frame(I.root,400,125,620,365);p:SetDrawLayer(DL_OVERLAY);p:SetDrawLevel(40);I.splitPanel=p
  I.splitTitle=label(p,20,15,580,50,23);I.splitTitle:SetDrawLayer(DL_OVERLAY);I.splitTitle:SetDrawLevel(41)
  I.splitText=label(p,20,75,580,270,22);I.splitText:SetDrawLayer(DL_OVERLAY);I.splitText:SetDrawLevel(41)
 end
 I.split={item=e,amount=math.floor(e.qty/2)};I.splitPanel:SetHidden(false);paintSplit()
end
local function executeSplit()
 local m=I.split;local e=m.item;local amount=m.amount
 if I.pending or not I.focus or s(IsUnitInCombat,'player')~=false or not N.same(e) or s(GetSlotStackSize,e.bag,e.slot)~=e.qty then closeSplit();notice('Split cancelled: item or interaction changed.');return end
 if amount<1 or amount>=e.qty then return end
 local slot=s(FindFirstEmptySlotInBag,e.bag)
 if type(slot)~='number' or slot<0 or s(GetItemLink,e.bag,slot,LINK_STYLE_DEFAULT)~='' then notice('Split requires an empty slot in the same bag.');return end
 if not zo_callLater then notice('Split verification unavailable.');return end
 closeSplit()
 local ok,result=secureAction('RequestMoveItem',e.bag,e.slot,e.bag,slot,amount)
 if not ok or result==false then notice('Split unavailable. R2 opens native inventory.');return end
 I.pending=true;zo_callLater(function()
 I.pending=false;I.dirty=true
 if s(GetSlotStackSize,e.bag,e.slot)==e.qty-amount and s(GetItemLink,e.bag,slot,LINK_STYLE_DEFAULT)==e.link and s(GetSlotStackSize,e.bag,slot)==amount then notice('Split confirmed: '..amount..' / '..(e.qty-amount)) else notice('Split not confirmed (return '..tostring(result)..').') end
 end,1500)
end
local function itemActions()
 local e=valid();if not e then return end
 if I.pending then return end
 local opts={};local function add(label,kind,slot) opts[#opts+1]={label=label,kind=kind,slot=slot} end
 local function equip(label,k) local slot=_G['EQUIP_SLOT_'..k];if type(slot)=='number' then add(label,'Equip',slot) end end
 if e.bag==BAG_VIRTUAL then add('Retrieve from craft bag','Retrieve')
 elseif e.bag==BAG_WORN then add('Unequip','Unequip')
 elseif s(IsEquipable,e.bag,e.slot)==true then
  local t=s(GetItemEquipType,e.bag,e.slot) or s(GetItemLinkEquipType,e.link)
  if matches(t,'EQUIP_TYPE_ONE_HAND','EQUIP_TYPE_MAIN_HAND','EQUIP_TYPE_TWO_HAND') then
   equip('Equip — primary main hand','MAIN_HAND');equip('Equip — backup main hand','BACKUP_MAIN')
   if matches(t,'EQUIP_TYPE_ONE_HAND') then equip('Equip — primary off hand','OFF_HAND');equip('Equip — backup off hand','BACKUP_OFF') end
  elseif matches(t,'EQUIP_TYPE_OFF_HAND') then equip('Equip — primary off hand','OFF_HAND');equip('Equip — backup off hand','BACKUP_OFF')
  elseif matches(t,'EQUIP_TYPE_RING') then equip('Equip — Ring 1','RING1');equip('Equip — Ring 2','RING2')
  else local dest=destination(e);if type(dest)=='number' then add('Equip','Equip',dest) end end
 elseif e.bag==BAG_BACKPACK then local usable,quick=s(IsItemUsable,e.bag,e.slot);if usable==true and quick~=true then if isContainer(e) then add('Open container','Open container') else add('Use','Use') end end end
 local locked=s(IsItemPlayerLocked,e.bag,e.slot)
 if e.bag~=BAG_VIRTUAL and s(CanItemBePlayerLocked,e.bag,e.slot)==true and type(locked)=='boolean' then add(locked and 'Unlock' or 'Lock','Lock') end
 if e.bag==BAG_BACKPACK and locked==false and N.canDestroy(e) then add('Destroy item / stack','Destroy') end
 if e.qty>1 and e.bag==BAG_BACKPACK then add('Split stack','Split') end
 if e.bag~=BAG_VIRTUAL and s(IsBankOpen)~=true then
  if s(IsItemEnchantable,e.bag,e.slot)==true then add('Enchant','enchant') end
  local charge,max=s(GetChargeInfoForItem,e.bag,e.slot)
  if s(IsItemChargeable,e.bag,e.slot)==true and type(charge)=='number' and type(max)=='number' and charge<max then add('Recharge weapon','soulgem') end
  local condition=s(GetItemCondition,e.bag,e.slot)
  if s(DoesItemHaveDurability,e.bag,e.slot)==true and type(condition)=='number' and condition<100 then add('Repair','repair') end
  if e.bag==BAG_BACKPACK and N.canQuickslot(e) then add('Assign quickslot','Quickslot') end
  if e.bag==BAG_BACKPACK and s(ZO_InventorySlot_WillItemBecomeBoundOnEquip,e.bag,e.slot)==true then add('Bind item','Bind') end
  if e.bag==BAG_BACKPACK and N.canStow(e) then add('Stow in craft bag','Stow') end
  if e.bag==BAG_BACKPACK and s(CanItemBeMarkedAsJunk,e.bag,e.slot)==true and type(s(IsItemJunk,e.bag,e.slot))=='boolean' and locked==false then add(s(IsItemJunk,e.bag,e.slot) and 'Unmark junk' or 'Mark junk','Junk') end
 end
 if I.detailPages and #I.detailPages>1 then add('Next item info page','DetailPage') end
 if s(IsChatSystemAvailableForCurrentPlatform)==true then add('Link in chat','Link') end
 add('Cancel','Cancel')
 if not I.actionPanel then
  local p=frame(I.root,425,90,570,480);p:SetDrawLayer(DL_OVERLAY);p:SetDrawLevel(20);I.actionPanel=p
  I.actionTitle=label(p,20,12,530,55,23);I.actionTitle:SetDrawLayer(DL_OVERLAY);I.actionTitle:SetDrawLevel(21)
  I.actionLabels={};for j=1,10 do local l=label(p,20,70+(j-1)*37,530,35,21);l:SetDrawLayer(DL_OVERLAY);l:SetDrawLevel(21);I.actionLabels[j]=l end
 end
 I.menu={item=e,options=opts,index=1};paintMenu()
end
local function selectAction()
 local m=I.menu;local v=m.options[m.index];local e=m.item;closeMenu()
 if not v or v.kind=='Cancel' then return end
 if not N.same(e) then notice('Item changed.');return end
 if v.kind=='DetailPage' then N.nextDetails(I);return end
 if v.kind=='Split' then openSplit(e);return end
 if v.kind=='Destroy' then N.destroy(e,notice);return end
 if N.extraAction(I,e,v.kind,notice) then return end
 if v.kind=='Lock' then
  local old=s(IsItemPlayerLocked,e.bag,e.slot)
  if s(IsUnitInCombat,'player')~=false then return end
  if type(old)=='boolean' and s(CanItemBePlayerLocked,e.bag,e.slot)==true then s(SetItemIsPlayerLocked,e.bag,e.slot,not old);notice(s(IsItemPlayerLocked,e.bag,e.slot)==not old and 'Lock status updated.' or 'Lock change not confirmed.');I.dirty=true end
 else primary(e,v.kind,v.slot and v or nil) end
end
function OnePackNativeInventoryInput(action)
 if not I.focus or I.searching or (ZO_Dialogs_IsShowingDialog and s(ZO_Dialogs_IsShowingDialog)) then return end
 if G.job then
  if action=='back' then G.job.cancelled=true;G.status='Cancelling gear load...';I.dirty=true end;return
 end
 if I.gearMenu then
  local m=I.gearMenu
  if action=='up' or action=='down' then m.index=(m.index-1+(action=='up' and -1 or 1))%#m.options+1;paintGear()
  elseif action=='primary' then selectGear() elseif action=='back' then if m.name then openGear() else closeGear() end end
  return
 end
 if I.split then
  local m=I.split
  if action=='back' then closeSplit();return elseif action=='primary' then executeSplit();return
  elseif action=='left' then m.amount=m.amount-1 elseif action=='right' then m.amount=m.amount+1
  elseif action=='up' then m.amount=m.amount+10 elseif action=='down' then m.amount=m.amount-10
  elseif action=='prev' then m.amount=math.floor(m.item.qty/4) elseif action=='next' then m.amount=math.floor(m.item.qty/2)
  elseif action=='sort' then m.amount=m.item.qty-1 end
  paintSplit();return
 end
 if I.menu then
  if action=='up' or action=='down' then local m=I.menu;m.index=(m.index-1+(action=='up' and -1 or 1))%#m.options+1;paintMenu()
  elseif action=='primary' then selectAction() elseif action=='back' then closeMenu() end
  return
 end
 if action=='search' then N.search(I,render,layerName);return end
 if action=='location' then I.location=I.location%#locations+1;I.category=1;I.dollFocus=false;I.page=1;I.selected=1;I.dirty=true;render();return end
 if action=='quality' then I.qualityFilter=(I.qualityFilter+1)%7;I.page=1;I.selected=1;I.dollFocus=false;I.dirty=true;render();return end
 if action=='equipment' then I.dollFocus=not I.dollFocus;render();return end
 if action=='sort' and I.dollFocus then openGear();return end
 if I.dollFocus then
  local j=I.dollSelected
  if action=='left' and j%2==0 then j=j-1 elseif action=='right' and j%2==1 then j=j+1
  elseif action=='up' then j=j-2 elseif action=='down' then j=j+2
  elseif action=='primary' then itemActions();return
  elseif action=='back' then I.dollFocus=false
  elseif action=='native' then handoff();return
  elseif action=='prev' or action=='next' or action=='sort' then I.dollFocus=false;if action=='sort' then sort() else filter(action=='prev' and -1 or 1) end;return end
  I.dollSelected=math.max(1,math.min(#dollSlots,j));render();return
 end
 if action=='left' then move(-1) elseif action=='right' then move(1)
 elseif action=='up' then move(-10) elseif action=='down' then move(10)
 elseif action=='prev' then filter(-1) elseif action=='next' then filter(1)
 elseif action=='sort' then sort() elseif action=='back' then back()
 elseif action=='native' then handoff() elseif action=='primary' then itemActions() end
end
local function setup()
 if I.scene then return true end
 if not (ZO_Scene and SCENE_MANAGER and KEYBIND_STRIP and FRAGMENT_GROUP and FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW) then
  I.disabled=true;notice('Native gamepad window group unavailable; keeping original inventory.');return false
 end
 if not I.root then build() end
 I.scene=ZO_Scene:New(sceneName,SCENE_MANAGER)
 I.scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
 if I.scene.SetInputPreferredMode and INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD then I.scene:SetInputPreferredMode(INPUT_PREFERRED_MODE_ALWAYS_GAMEPAD) end
 -- Keybind strip is supplied by the native window group.
 if GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT then I.scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT) end
 I.keys={alignment=KEYBIND_STRIP_ALIGN_LEFT}
 local function key(binding,name,action,hidden)
  I.keys[#I.keys+1]={keybind=binding,name=name,ethereal=hidden,callback=function() OnePackNativeInventoryInput(action) end}
 end
 -- Directional keys are registered in Inventory/Bindings.xml, independently of keybind strip.
 key('UI_SHORTCUT_LEFT_SHOULDER','Category','prev');key('UI_SHORTCUT_RIGHT_SHOULDER','Category','next')
 key('UI_SHORTCUT_PRIMARY','Item actions','primary');key('UI_SHORTCUT_SECONDARY','Sort / gear presets','sort')
 key('UI_SHORTCUT_TERTIARY','Equipped gear','equipment')
 key('UI_SHORTCUT_LEFT_TRIGGER','Search','search');key('UI_SHORTCUT_LEFT_STICK','Location','location');key('UI_SHORTCUT_RIGHT_STICK','Quality','quality')
 key('UI_SHORTCUT_RIGHT_TRIGGER','Native inventory','native')
 key('UI_SHORTCUT_NEGATIVE','Back','back')
 I.scene:RegisterCallback('StateChange',function(_,state)
  if state==SCENE_SHOWING then
   I.dirty=true;local ok,err=pcall(render);if not ok then I.dirty=true;I.renderFailed=true;notice("Opening render: "..tostring(err));I.root:SetHidden(true);zo_callLater(function() if sceneNameNow()==sceneName then native() end end,100);return end;I.renderFailed=false;I.root:SetHidden(false)
  elseif state==SCENE_SHOWN then
   if I.disabled or I.renderFailed then return end
   local ok,err=pcall(function() KEYBIND_STRIP:AddKeybindButtonGroup(I.keys) end)
   if ok then I.focus=true
    local ready=true
    for suffix in pairs(directions) do
     local action='ONEPACK_NATIVE_GRID_'..suffix;local code=_G['KEY_GAMEPAD_DPAD_'..suffix]
     if not (CreateDefaultActionBind and code and KEY_INVALID and GetActionIndicesFromName and s(GetActionIndicesFromName,action)) then ready=false
     else local success=pcall(CreateDefaultActionBind,action,code,KEY_INVALID,KEY_INVALID,KEY_INVALID,KEY_INVALID);ready=ready and success end
    end
    if ready and PushActionLayerByName and RemoveActionLayerByName then
     local pushed=pcall(PushActionLayerByName,layerName);I.directionLayer=pushed
     if pushed and IsActionLayerActiveByName then ready=s(IsActionLayerActiveByName,layerName)==true else ready=pushed end
    else ready=false end
    local bound=0
    if GetHighestPriorityActionBindingInfoFromName then for suffix in pairs(directions) do if s(GetHighestPriorityActionBindingInfoFromName,'ONEPACK_NATIVE_GRID_'..suffix,true)==_G['KEY_GAMEPAD_DPAD_'..suffix] then bound=bound+1 end end end
    notice('D-pad layer '..(ready and 'active' or 'unavailable')..'; verified bindings '..bound..'/4.') else I.disabled=true;release();notice(tostring(err));I.bypass=true;SCENE_MANAGER:Show(nativeName) end
  elseif state==SCENE_HIDING or state==SCENE_HIDDEN then release() end
 end)
 return true
end
function I.toggle() if sceneNameNow()==sceneName then back() else I.open() end end
function I.close() if I.focus then back() end end
local function tick()
 local name=sceneNameNow()
 if name==sceneName and not N.enabled() then back();return end
 if name==sceneName then if I.focus then N.dialogFocus(I,layerName);if I.dirty and not I.menu and not I.split and not I.searching then render() end end;return end
 if I.focus then release() end
 if name==nativeName then
  if N.enabled() and N.canAutoReplace() and N.autoInventory and not I.disabled and not I.bypass and not I.autoAttempt and not (ZO_Dialogs_IsShowingDialog and s(ZO_Dialogs_IsShowingDialog)) then
   local current=SCENE_MANAGER:GetCurrentScene()
   if not current or not current.GetState or current:GetState()~=SCENE_SHOWN then return end
   I.autoAttempt=true
   if setup() then SCENE_MANAGER:Show(sceneName) end
  end
 else I.bypass=false;I.autoAttempt=false end
end
function I.options() local opts={{type='checkbox',name='OnePackNative unified inventory (experimental)',getFunc=function() return not I.disabled end,setFunc=function(v) I.disabled=not v;if not v and I.focus then native() end end},{type='description',text='D-pad grid. Follow the native keybind strip for item actions, sorting and native inventory fallback.'}};if N.bank then for _,v in ipairs(N.bank.options()) do opts[#opts+1]=v end end;return opts end
function I.open() if not N.enabled() then return end;I.bypass=false;I.disabled=false;if setup() then SCENE_MANAGER:Show(sceneName) end end
EVENT_MANAGER:RegisterForEvent('OnePackNativeInventoryInit',EVENT_ADD_ON_LOADED,function(_,name)
 if name~='OnePack' then return end
 EVENT_MANAGER:UnregisterForEvent('OnePackNativeInventoryInit',EVENT_ADD_ON_LOADED)
 G.init()
 if EVENT_INVENTORY_SINGLE_SLOT_UPDATE then EVENT_MANAGER:RegisterForEvent('OnePackNativeInventoryDirty',EVENT_INVENTORY_SINGLE_SLOT_UPDATE,function() I.dirty=true end) end
 if EVENT_INVENTORY_FULL_UPDATE then EVENT_MANAGER:RegisterForEvent('OnePackNativeInventoryFull',EVENT_INVENTORY_FULL_UPDATE,function() I.dirty=true end) end
 EVENT_MANAGER:RegisterForUpdate('OnePackNativeInventoryRefresh',250,function() local ok,err=pcall(tick);if not ok then release();I.dirty=true;I.disabled=true;I.bypass=true;I.autoAttempt=true;notice(tostring(err));if sceneNameNow()==sceneName then s(SCENE_MANAGER.Show,SCENE_MANAGER,nativeName) end end end)
end)
