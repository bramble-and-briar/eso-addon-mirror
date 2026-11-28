-- OnePack by Trash Man Enterprises. No required libraries.
OnePack={autoInventory=true,autoBank=true}
local N=OnePack
function N.safe(f,...) if type(f)~='function' then return end;local ok,a,b,c,d,e=pcall(f,...);if ok then return a,b,c,d,e end end
local s=N.safe
-- Optional Tamriel Savings Co. integration, using the same API conventions as Gold Standard.
-- No vendor fallback: absent market data is not a market price.
function N.hasMarketData()
 local api,lite=_G.TSCPriceDataAPI,_G.TSCPriceDataLite
 return (type(api)=='table' and type(api.GetPrice)=='function') or (type(lite)=='table' and type(lite.GetPrice)=='function')
end
local function validPrice(p)
 if type(p)=='table' then p=p.price or p.avgPrice or p.averagePrice or p.avg or p[1] end
 if type(p)=='number' and p>0 and p<math.huge then return p end
end
local function readPrice(api,key)
 if type(api)~='table' or type(api.GetPrice)~='function' or key==nil then return nil end
 return validPrice(s(api.GetPrice,api,key)) or validPrice(s(api.GetPrice,key))
end
function N.marketUnit(link,cache)
 if type(link)~='string' or link=='' then return nil end
 if cache and cache[link]~=nil then local c=cache[link];if c then return c[1],c[2] end;return nil end
 local price,source=readPrice(_G.TSCPriceDataAPI,link),'TSC API'
 if not price then price,source=readPrice(_G.TSCPriceDataLite,s(GetItemLinkItemId,link)),'TSC Lite' end
 if cache then cache[link]=price and {price,source} or false end
 if price then return price,source end
end
function N.marketValue(e,cache)
 if s(IsItemBound,e.bag,e.slot)==true or s(IsItemLinkBound,e.link)==true then return nil,nil,'Bound' end
 if s(IsItemStolen,e.bag,e.slot)==true then return nil,nil,'Stolen' end
 if not N.hasMarketData() then return nil,nil,'TSC data unavailable' end
 local price,source=N.marketUnit(e.link,cache)
 if not price then return nil,nil,'No TSC price' end
 return price*(e.qty or 1),price,source
end
function N.prepareMarketSort(rows)
 local cache={}
 for _,e in ipairs(rows) do e.marketTotal,e.marketUnit,e.marketSource=N.marketValue(e,cache) end
end
function N.marketSortLabel()
 return N.hasMarketData() and 'TSC / Guild Trader Value' or 'TSC value (no data)'
end
local function marketGold(n)
 return (tostring(math.floor(n+.5)):reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,',''))..'g'
end
function N.marketLines(e)
 local total,unit,source=e.marketTotal,e.marketUnit,e.marketSource
 if not source then total,unit,source=N.marketValue(e) end
 if not unit then return {'Guild trader: '..(source or 'No TSC price')} end
 return {'Guild trader / item: ~'..marketGold(unit),'Guild trader / stack: ~'..marketGold(total)..' ('..source..')'}
end
function N.enabled() return not N.paused end
function N.canAutoReplace()
 local hc=_G.ESOHardcore
 return not (type(hc)=='table' and s(hc.hcActive)==true)
end
function N.cleanName(name)
 name=tostring(name or ''):gsub('%^%a+',''):gsub('|[cC]%x%x%x%x%x%x',''):gsub('|[rR]','')
 return s(zo_strformat,'<<1>>',name) or name
end
function N.matchesName(name,query)
 query=tostring(query or ''):gsub('^%s+',''):gsub('%s+$',''):lower()
 return query=='' or tostring(name or ''):lower():find(query,1,true)~=nil
end
local quality={'All qualities','Trash','Normal','Fine','Superior','Epic','Legendary'}
function N.qualityName(i) return quality[(i or 0)+1] or quality[1] end
function N.bagName(bag)
 if bag==BAG_BACKPACK then return 'Backpack' elseif bag==BAG_WORN then return 'Equipped' elseif bag==BAG_VIRTUAL then return 'Craft bag' elseif bag==BAG_BANK then return 'Personal bank' elseif bag==BAG_SUBSCRIBER_BANK then return 'ESO Plus bank' end;return 'Item storage'
end
function N.gold() return s(GetCurrencyAmount,CURT_MONEY,CURRENCY_LOCATION_CHARACTER) or 0 end
function N.bankGold() return s(GetCurrencyAmount,CURT_MONEY,CURRENCY_LOCATION_BANK) or 0 end
function N.uid(bag,slot)
 if bag==BAG_VIRTUAL then return nil end
 local id=s(GetItemUniqueId,bag,slot)
 if id~=nil then return s(Id64ToString,id) or tostring(id) end
end
function N.same(e)
 if not e or s(GetItemLink,e.bag,e.slot,LINK_STYLE_DEFAULT)~=e.link then return false end
 if e.uid and N.uid(e.bag,e.slot)~=e.uid then return false end
 return true
end
local function slotData(e)
 local t=e.bag==BAG_WORN and SLOT_TYPE_EQUIPMENT or e.bag==BAG_VIRTUAL and SLOT_TYPE_CRAFT_BAG_ITEM or (e.bag==BAG_BANK or e.bag==BAG_SUBSCRIBER_BANK) and SLOT_TYPE_BANK_ITEM or SLOT_TYPE_GAMEPAD_INVENTORY_ITEM
 return {bagId=e.bag,slotIndex=e.slot,slotType=t,stackCount=e.qty}
end
function N.canDestroy(e) return s(ZO_InventorySlot_CanDestroyItem,slotData(e))==true end
function N.destroy(e,notice)
 if not N.same(e) or not N.canDestroy(e) or s(IsItemPlayerLocked,e.bag,e.slot)~=false or s(IsUnitInCombat,'player')~=false or s(GetSlotStackSize,e.bag,e.slot)~=e.qty then notice('Item changed or is protected.');return end
 -- The native destroy request handles quality, Armory and confirmation rules.
 local ok,result=pcall(function() return ZO_InventorySlot_InitiateDestroyItem(slotData(e)) end)
 if not ok or result==false then notice('Native destroy request unavailable. Use R2.') end
end
function N.canQuickslot(e)
 if e.bag~=BAG_BACKPACK or not SHARED_INVENTORY then return false end
 local data=s(SHARED_INVENTORY.GenerateSingleSlotData,SHARED_INVENTORY,e.bag,e.slot)
 return data and s(ZO_InventorySlot_CanQuickslotItem,data)==true or false
end
function N.canStow(e) return e.bag==BAG_BACKPACK and s(HasCraftBagAccess)==true and s(CanItemBeVirtual,e.bag,e.slot)==true and s(IsItemStolen,e.bag,e.slot)==false end
local function getSystem(name) return SYSTEMS and s(SYSTEMS.GetObject,SYSTEMS,name) end
local function transfer(e,dest)
 local obj=getSystem('ItemTransferDialog')
 if not obj or type(obj.StartTransfer)~='function' then error('Native transfer dialog unavailable') end
 obj:StartTransfer(e.bag,e.slot,dest)
end
-- Console-safe chat prefill: never auto-submit. The fourth StartTextEntry
-- argument avoids changing private console HUD settings (LibSlashCommander technique).
function N.linkChat(e)
 if s(IsChatSystemAvailableForCurrentPlatform)~=true then error('Chat unavailable') end
 if s(IsCommunicationRestricted)==true then error('Chat is restricted') end
 local link=s(ZO_LinkHandler_CreateChatLink,GetItemLink,e.bag,e.slot)
 if type(link)~='string' or link=='' then link=s(GetItemLink,e.bag,e.slot,LINK_STYLE_BRACKETS or LINK_STYLE_DEFAULT) end
 if type(link)~='string' or link=='' then error('No item link available') end
 local chat=s(ZO_GetChatSystem)
 if not chat or type(chat.StartTextEntry)~='function' then error('Chat text entry unavailable') end
 local text=s(zo_strformat,SI_TOOLTIP_ITEM_NAME,link) or link
 local result=chat:StartTextEntry(text,nil,nil,true)
 if result==false then error('Chat text entry declined') end
end
-- Use the actual item's type, not a guessed name or item category.
local function enumMatch(value, names)
 for _,name in ipairs(names) do if _G[name]~=nil and value==_G[name] then return true end end
 return false
end
local function localizedEnum(prefix,value)
 if type(value)~='number' then return nil end
 local name=s(GetString,prefix,value)
 if type(name)=='string' and name~='' then return name end
end
function N.equipmentType(link)
 local armor=s(GetItemLinkArmorType,link)
 if enumMatch(armor,{'ARMORTYPE_LIGHT','ARMORTYPE_MEDIUM','ARMORTYPE_HEAVY'}) then
  local name=localizedEnum('SI_ARMORTYPE',armor)
  if not name then
   name=enumMatch(armor,{'ARMORTYPE_LIGHT'}) and 'Light' or enumMatch(armor,{'ARMORTYPE_MEDIUM'}) and 'Medium' or 'Heavy'
  end
  return 'Armor weight: '..name
 end
 local weapon=s(GetItemLinkWeaponType,link)
 local equip=s(GetItemLinkEquipType,link)
 if type(weapon)~='number' or enumMatch(weapon,{'WEAPONTYPE_NONE'}) or weapon==0 then return nil end
 local name=localizedEnum('SI_WEAPONTYPE',weapon)
 local hands
 if enumMatch(equip,{'EQUIP_TYPE_TWO_HAND'}) or enumMatch(weapon,{'WEAPONTYPE_TWO_HANDED_AXE','WEAPONTYPE_TWO_HANDED_HAMMER','WEAPONTYPE_TWO_HANDED_SWORD','WEAPONTYPE_BOW','WEAPONTYPE_FIRE_STAFF','WEAPONTYPE_FROST_STAFF','WEAPONTYPE_LIGHTNING_STAFF','WEAPONTYPE_HEALING_STAFF'}) then hands='2H'
 elseif enumMatch(weapon,{'WEAPONTYPE_SHIELD'}) then hands='Off hand'
 elseif enumMatch(equip,{'EQUIP_TYPE_ONE_HAND','EQUIP_TYPE_MAIN_HAND'}) or enumMatch(weapon,{'WEAPONTYPE_AXE','WEAPONTYPE_HAMMER','WEAPONTYPE_SWORD','WEAPONTYPE_DAGGER'}) then hands='1H'
 elseif enumMatch(equip,{'EQUIP_TYPE_OFF_HAND'}) then hands='Off hand' end
 if name and hands then return 'Weapon: '..name..' ('..hands..')' end
 if name or hands then return 'Weapon: '..(name or hands) end
end
function N.setLines(link)
 local lines={}
 local has,name,count=s(GetItemLinkSetInfo,link,false)
 if has~=true then return lines end
 lines[1]='|cE9C77ASet: '..N.cleanName(name)..'|r'
 if type(count)~='number' then return lines end
 for index=1,math.min(20,math.max(0,math.floor(count))) do
  local required,description=s(GetItemLinkSetBonusInfo,link,false,index)
  if type(required)=='number' and type(description)=='string' and description~='' then
   -- The API generally returns its own (N items) prefix. Avoid duplicating it.
   local plain=description:gsub('|[cC]%x%x%x%x%x%x',''):gsub('|[rR]','')
   if not plain:match('^%s*%(%s*%d+') then description='('..required..') '..description end
   lines[#lines+1]=description
  end
 end
 return lines
end
-- Fit details into the wider panel; if needed, expose additional pages through X.
-- Long individual descriptions are split on word boundaries, not silently clipped.
function N.showDetails(I,e,lines)
 if not e then I.detailKey=nil;I.detailPage=1;I.detailPages={};I.detailHint:SetText('');I.detail:SetText('');return end
 local key=tostring(e.bag)..':'..tostring(e.slot)..':'..e.link
 if key~=I.detailKey then I.detailKey=key;I.detailPage=1 end
 local label=I.detail
 -- Measure unclipped text before returning the control to its normal viewport.
 if label.SetHeight then label:SetHeight(2000) end
 local function setFont(size) label:SetFont('$(BOLD_FONT)|'..size..'|soft-shadow-thick') end
 local function fits(text)
  label:SetText(text)
  local height=s(label.GetTextHeight,label)
  if type(height)=='number' and height>0 then return height<=396 end
  local n=0;for line in (text..'\n'):gmatch('(.-)\n') do n=n+math.max(1,math.ceil(#line/40)) end
  return n<=20
 end
 setFont(17)
 local full=table.concat(lines,'\n')
 if fits(full) then I.detailPages={full}
 else
  setFont(16)
  if fits(full) then I.detailPages={full}
  else
   local pages,buffer={},''
   local function append(line)
    local nextText=buffer=='' and line or buffer..'\n'..line
    if fits(nextText) then buffer=nextText;return end
    if buffer~='' then pages[#pages+1]=buffer;buffer='' end
    if fits(line) then buffer=line;return end
    -- Extremely long descriptions: break between words, preserving their order.
    for word in line:gmatch('%S+') do
     local candidate=buffer=='' and word or buffer..' '..word
     if buffer~='' and not fits(candidate) then pages[#pages+1]=buffer;buffer=word else buffer=candidate end
    end
   end
   for _,line in ipairs(lines) do append(line) end
   if buffer~='' then pages[#pages+1]=buffer end
   I.detailPages=#pages>0 and pages or {full}
  end
 end
 I.detailPage=math.max(1,math.min(I.detailPage or 1,#I.detailPages))
 if label.SetHeight then label:SetHeight(397) end
 label:SetText(I.detailPages[I.detailPage])
 I.detailHint:SetText(#I.detailPages>1 and ('Page '..I.detailPage..'/'..#I.detailPages..'  |  X > Next item info page') or '')
end
function N.nextDetails(I)
 if not I.detailPages or #I.detailPages<2 then return end
 I.detailPage=(I.detailPage or 1)%#I.detailPages+1
 I.detail:SetText(I.detailPages[I.detailPage])
 I.detailHint:SetText('Page '..I.detailPage..'/'..#I.detailPages..'  |  X > Next item info page')
end
function N.extraAction(I,e,kind,notice)
 local known={enchant=true,soulgem=true,repair=true,Quickslot=true,Retrieve=true,Stow=true,Junk=true,Link=true,Bind=true}
 if not known[kind] then return false end
 if not N.same(e) then notice('Item changed; cancelled.');return true end
 if kind~='Link' and (s(IsUnitInCombat,'player')~=false or s(IsUnitDead,'player')==true) then notice('Action unavailable during combat or while dead.');return true end
 local ok,err=pcall(function()
  if kind=='Link' then
   N.linkChat(e)
  elseif kind=='Junk' then
   if s(CanItemBeMarkedAsJunk,e.bag,e.slot)~=true or s(IsItemPlayerLocked,e.bag,e.slot)~=false then error('Junk action unavailable') end
   local old=s(IsItemJunk,e.bag,e.slot);if type(old)~='boolean' then error('Junk status unavailable') end
   if s(IsProtectedFunction,'SetItemIsJunk')==true then CallSecureProtected('SetItemIsJunk',e.bag,e.slot,not old) else SetItemIsJunk(e.bag,e.slot,not old) end
   I.dirty=true
  elseif kind=='Quickslot' then
   if not N.canQuickslot(e) then error('Item is not quickslottable') end
   local accessible=s(GetSetting_Bool,SETTING_TYPE_ACCESSIBILITY,ACCESSIBILITY_SETTING_ACCESSIBLE_QUICKWHEELS)
   if accessible and ACCESSIBLE_ASSIGNABLE_UTILITY_WHEEL_GAMEPAD then
    ACCESSIBLE_ASSIGNABLE_UTILITY_WHEEL_GAMEPAD:SetPendingItem(e.bag,e.slot)
    ACCESSIBLE_ASSIGNABLE_UTILITY_WHEEL_GAMEPAD:Show({HOTBAR_CATEGORY_QUICKSLOT_WHEEL})
   else GAMEPAD_QUICKSLOT:SetItemToQuickslot(e.bag,e.slot);SCENE_MANAGER:Push('gamepad_quickslot') end
  elseif kind=='Retrieve' then
   if e.bag~=BAG_VIRTUAL then error('Not a craft bag item') end
   ZO_TryMoveToInventoryFromBagAndSlot(e.bag,e.slot)
  elseif kind=='Stow' then
   if not N.canStow(e) then error('Cannot stow this item') end
   local data=SHARED_INVENTORY:GenerateSingleSlotData(e.bag,e.slot)
   if not data then error('Item data unavailable') end
   if data.isGemmable then ZO_Dialogs_ShowPlatformDialog('CONFIRM_STOW_GEMIFIABLE',{sourceBagId=e.bag,sourceSlotIndex=e.slot}) else transfer(e,BAG_VIRTUAL) end
  elseif kind=='Bind' then
   if s(ZO_InventorySlot_WillItemBecomeBoundOnEquip,e.bag,e.slot)~=true then error('Binding unavailable') end
   ZO_Dialogs_ShowPlatformDialog('CONFIRM_BIND_ITEM',{onAcceptCallback=function()
    if N.same(e) and s(IsUnitInCombat,'player')==false then if s(IsProtectedFunction,'BindItem')==true then CallSecureProtected('BindItem',e.bag,e.slot) else BindItem(e.bag,e.slot) end end
   end},{mainTextParams={e.name}})
  else
   local predicate=kind=='enchant' and IsItemEnchantable or kind=='soulgem' and IsItemChargeable or DoesItemHaveDurability
   if s(predicate,e.bag,e.slot)~=true then error('Item improvement unavailable') end
   local obj=getSystem(kind)
   if not obj or type(obj.BeginItemImprovement)~='function' then error('Native improvement screen unavailable') end
   local function open()
    if N.same(e) and s(IsUnitInCombat,'player')==false then local success,message=pcall(obj.BeginItemImprovement,obj,e.bag,e.slot);if not success then notice(tostring(message)..'. Use R2.') end end
   end
   if kind=='enchant' and s(IsItemBoPAndTradeable,e.bag,e.slot)==true then
    ZO_Dialogs_ShowPlatformDialog('CONFIRM_MODIFY_TRADE_BOP',{onAcceptCallback=open},{mainTextParams={e.name}})
   else open() end
  end
 end)
 if not ok then notice('Action unavailable: '..tostring(err)..'. R2 opens native UI.') end
 return true
end
-- Do not let the grid's D-pad layer consume native dialog input.
function N.dialogFocus(I,layer)
 local active=s(ZO_Dialogs_IsShowingDialog)==true
 local showing=active or I.searching
 if showing and I.directionLayer then
  s(RemoveActionLayerByName,layer);I.directionLayer=false;I.suspendedLayer=true
 elseif not showing and I.suspendedLayer and I.focus then
  I.suspendedLayer=false;I.directionLayer=pcall(PushActionLayerByName,layer)
 end
end
local SEARCH='ONEPACK_SEARCH_DIALOG'
local registered=false
function N.search(I,render,layer)
 if I.searching or not I.focus or not GAMEPAD_DIALOGS or not GAMEPAD_DIALOGS.PARAMETRIC or not ZO_Dialogs_RegisterCustomDialog or not ZO_Dialogs_ShowGamepadDialog then return end
 local function finish(dialog)
  local data=dialog and dialog.data or N.searchDialog and N.searchDialog.data;if not data or not data.owner then return end
  data.owner.searching=false;data.owner.searchSeen=false;data.owner.dirty=true
 end
 local function apply(dialog,clear)
  local data=dialog.data;if not data or not data.owner then return end
  local owner=data.owner;owner.query=clear and '' or tostring(data.entered or ''):gsub('^%s+',''):gsub('%s+$',''):sub(1,80)
  owner.page=1;owner.selected=1;owner.dollFocus=false;owner.dirty=true
  finish(dialog)
  ZO_Dialogs_ReleaseDialogOnButtonPress(SEARCH)
 end
 if not registered then
  ZO_Dialogs_RegisterCustomDialog(SEARCH,{
   gamepadInfo={dialogType=GAMEPAD_DIALOGS.PARAMETRIC},
   blockDialogReleaseOnPress=true,
   title={text='Search item names'},mainText={text='Select the text field to open the console keyboard. Then select Apply search. Empty text shows all items.'},
   setup=function(dialog) N.searchDialog=dialog;dialog:setupFunc() end,
   finishedCallback=finish,noChoiceCallback=finish,
   parametricList={
    {template='ZO_Gamepad_GenericDialog_Parametric_TextFieldItem',templateData={
      setup=function(control,data,selected)
       control.highlight:SetHidden(not selected)
       local edit=control.editBoxControl;edit:SetDefaultText('Enter item name');edit:SetMaxInputChars(80)
       local ownerData=N.searchDialog and N.searchDialog.data
       edit.textChangedCallback=function(c) if ownerData then ownerData.entered=c:GetText() end end
       edit:SetText(ownerData and ownerData.entered or '')
      end,
      callback=function(dialog) local c=dialog.entryList:GetTargetControl();if c and c.editBoxControl then c.editBoxControl:TakeFocus() end end,
      narrationText=ZO_GetDefaultParametricListEditBoxNarrationText}},
    {template='ZO_GamepadTextFieldSubmitItem',templateData={text='Apply search',setup=ZO_SharedGamepadEntry_OnSetup,callback=function(dialog) apply(dialog,false) end}},
    {template='ZO_GamepadMenuEntryTemplate',templateData={text='Clear search',setup=ZO_SharedGamepadEntry_OnSetup,callback=function(dialog) apply(dialog,true) end}},
   },
   buttons={{keybind='DIALOG_PRIMARY',text=SI_GAMEPAD_SELECT_OPTION,callback=function(dialog) local target=dialog.entryList:GetTargetData();if target and target.callback then target.callback(dialog) end end},{keybind='DIALOG_NEGATIVE',text=SI_DIALOG_CANCEL,callback=function(dialog) finish(dialog);ZO_Dialogs_ReleaseDialogOnButtonPress(SEARCH) end}},
  })
  registered=true
 end
 I.searching=true;I.searchSeen=false;N.dialogFocus(I,layer)
 local ok,err=pcall(ZO_Dialogs_ShowGamepadDialog,SEARCH,{owner=I,entered=I.query or ''})
 if not ok then I.searching=false;N.dialogFocus(I,layer);if d then d('OnePack search: '..tostring(err)) end end
end
function OnePackToggle() if N.inventory and N.enabled() then N.inventory.toggle() end end
if ZO_CreateStringId then ZO_CreateStringId('SI_BINDING_NAME_ONEPACK_OPEN','Open OnePack') end
local function cmd(arg)
 arg=tostring(arg or ''):lower():gsub('^%s+',''):gsub('%s+$','')
 if arg=='off' then N.paused=true;if N.inventory then N.inventory.close() end;if N.bank then N.bank.close() end;if d then d('OnePack paused. /onepack on to resume.') end
 elseif arg=='on' then N.paused=false;if N.inventory then N.inventory.disabled=false end;if N.bank then N.bank.disabled=false end;if d then d('OnePack enabled.') end
 elseif arg=='bank' then if N.bank then N.bank.open() end
 elseif arg=='manual' then N.autoInventory=false;N.autoBank=false;if d then d('OnePack manual mode. /onepack auto restores replacement.') end
 elseif arg=='auto' then N.autoInventory=true;N.autoBank=true;if d then d('OnePack automatic mode.') end
 else OnePackToggle() end
end
SLASH_COMMANDS['/onepack']=cmd;SLASH_COMMANDS['/op']=cmd
-- Optional radial access; documented registration API only.
local radialLib,radialAddonRegistered,radialEntryRegistered=nil,false,false
local radialEvent,radialRetry='OnePackRadialInit','OnePackRadialRetry'
local function openFromRadial()
 if N.enabled() and N.inventory then N.inventory.open() end
end
local function registerRadial()
 local lib=_G.LibRadialMenu
 if type(lib)~='table' or type(lib.RegisterAddon)~='function' or type(lib.RegisterEntry)~='function' then return false end
 if radialLib~=lib then radialLib=lib;radialAddonRegistered=false;radialEntryRegistered=false end
 local ok,result=pcall(function()
  if not radialAddonRegistered then
   if lib:RegisterAddon('OnePack','OnePack')==false then return false end
   radialAddonRegistered=true
  end
  if not radialEntryRegistered then
   if lib:RegisterEntry('OnePack','Open OnePack','onepack_inventory','/esoui/art/icons/icon_dualwield.dds',openFromRadial,'Open the unified inventory.')==false then return false end
   radialEntryRegistered=true
  end
  return not N.gear or N.gear.registerRadial(lib)
 end)
 return ok and result==true
end
function N.refreshRadial()
 if registerRadial() then
  if EVENT_MANAGER.UnregisterForUpdate then EVENT_MANAGER:UnregisterForUpdate(radialRetry) end
  return true
 end
 if not EVENT_MANAGER.RegisterForUpdate then return false end
 local attempts=0
 EVENT_MANAGER:RegisterForUpdate(radialRetry,2500,function()
  attempts=attempts+1
  if registerRadial() or attempts>=10 then EVENT_MANAGER:UnregisterForUpdate(radialRetry) end
 end)
 return false
end
EVENT_MANAGER:RegisterForEvent(radialEvent,EVENT_PLAYER_ACTIVATED,function() N.refreshRadial() end)
