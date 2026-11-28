-- OnePack gear presets. No skills, CP, consumables, or Armory changes.
local N=OnePack;local s=N.safe
local G={};N.gear=G
G.slots={{'HEAD','Head'},{'NECK','Neck'},{'SHOULDERS','Shoulders'},{'RING1','Ring 1'},{'CHEST','Chest'},{'RING2','Ring 2'},{'HAND','Hands'},{'WAIST','Waist'},{'LEGS','Legs'},{'FEET','Feet'},{'MAIN_HAND','Main 1'},{'OFF_HAND','Off 1'},{'BACKUP_MAIN','Main 2'},{'BACKUP_OFF','Off 2'}}
local function key(name) return _G['EQUIP_SLOT_'..name] end
local function read(bag,slot)
 local link=s(GetItemLink,bag,slot,LINK_STYLE_DEFAULT)
 if type(link)~='string' then return nil,'Cannot read equipment or backpack.' end
 if link=='' then return false end
 local id=N.uid(bag,slot)
 if type(id)~='string' or id=='' or id=='0' then return nil,'Item identity unavailable.' end
 return {id=id,link=link,name=N.cleanName(s(GetItemLinkName,link) or link),bag=bag,slot=slot}
end
local function message(t) G.status=t;if d then d('OnePack Gear: '..t) end end
function G.init()
 if G.sets then return true end
 if not ZO_SavedVars then message('Saved variables unavailable.');return false end
 local vars=s(ZO_SavedVars.NewCharacterIdSettings,ZO_SavedVars,'OnePackSaved',1,nil,{gearSets={},radialSerial=0})
 if type(vars)~='table' or type(vars.gearSets)~='table' then message('Gear preset storage unavailable.');return false end
 G.vars=vars;G.sets=vars.gearSets;return true
end
function G.names()
 local out={};for name,v in pairs(G.sets or {}) do if type(name)=='string' and type(v)=='table' and type(v.items)=='table' then out[#out+1]=name end end
 table.sort(out,function(a,b) return a:lower()==b:lower() and a<b or a:lower()<b:lower() end);return out
end
function G.cleanName(name)
 return tostring(name or ''):gsub('|',''):gsub('%c',' '):gsub('^%s+',''):gsub('%s+$','')
end
function G.existing(name)
 for _,v in ipairs(G.names()) do if v:lower()==name:lower() then return v end end
end
function G.capture()
 local items={}
 for _,v in ipairs(G.slots) do
  local slot=key(v[1]);if type(slot)~='number' then return nil,'Equipment slot unavailable: '..v[2] end
  local e,err=read(BAG_WORN,slot);if e==nil then return nil,err end
  items[v[1]]=e and {id=e.id,link=e.link,name=e.name} or false
 end
 return {items=items}
end
function G.save(name,replace)
 if not G.init() then return false,G.status end
 name=G.cleanName(name);if name=='' or #name>160 then return false,'Enter a valid preset name (up to 40 characters).' end
 local existing=G.existing(name)
 if existing and not replace then return false,'That name already exists. Select it and use Overwrite.' end
 if replace and not existing then return false,'Preset no longer exists.' end
 if not existing and #G.names()>=50 then return false,'50 preset limit reached. Delete a preset first.' end
 local preset,err=G.capture();if not preset then return false,err end
 -- Overwrite keeps the wheel binding, while a deleted and recreated preset gets a new ID.
 if existing then preset.radialId=G.sets[existing].radialId end
 G.sets[existing or name]=preset;G.selected=existing or name;message('Saved '..G.selected..'.')
 if N.refreshRadial then N.refreshRadial() end
 return true
end
function G.delete(name)
 if not G.sets or not G.sets[name] then return false,'Preset no longer exists.' end
 G.sets[name]=nil;if G.selected==name then G.selected=nil end;message('Deleted '..name..'.');if N.refreshRadial then N.refreshRadial() end;return true
end
-- Public LibRadialMenu API has no documented unregister. Retired callbacks
-- must be inert until the wheel is rebuilt on reload; never recycle an ID.
local radialRegistered={}
function G.registerRadial(lib)
 if not G.init() then return false end
 local char=s(GetCurrentCharacterId)
 if char==nil then return false end
 char=s(Id64ToString,char) or tostring(char)
 if type(char)~='string' or not char:match('^%d+$') or char=='0' then return false end
 local serial=math.max(0,math.floor(tonumber(G.vars.radialSerial) or 0))
 local used={}
 for _,name in ipairs(G.names()) do
  local id=G.sets[name].radialId
  if type(id)=='number' and id>0 and id==math.floor(id) and not used[id] then used[id]=true;serial=math.max(serial,id)
  else G.sets[name].radialId=nil end
 end
 for _,name in ipairs(G.names()) do
  local preset=G.sets[name]
  if not preset.radialId then serial=serial+1;preset.radialId=serial end
  G.vars.radialSerial=serial
  local id=preset.radialId
  local entryId='onepack_gear_'..char..'_'..tostring(id)
  if radialRegistered[entryId]~=lib then
   local capturedName=name;local capturedId=id
   local ok,result=pcall(lib.RegisterEntry,lib,'OnePack','Equip: '..name,entryId,'/esoui/art/icons/icon_dualwield.dds',function()
    local current=G.sets and G.sets[capturedName]
    if not current or current.radialId~=capturedId then message('This preset was deleted. Unassign this wheel slot.');return end
    if not N.enabled() then message('OnePack is paused.');return end
    if not N.inventory or not N.inventory.loadFromRadial then message('Inventory gear loader unavailable.');return end
    local success,why=N.inventory.loadFromRadial(capturedName)
    if not success then message(why or 'Unable to load preset.') end
   end,'Equip the saved gear preset '..name..' directly from gameplay, outside combat.')
   if not ok or result==false then return false end
   radialRegistered[entryId]=lib
  end
 end
 G.vars.radialSerial=serial
 return true
end
-- Preflight and simulate a sequence of explicit moves, never relying on an implicit equipment swap.
-- Clear intended empty slots first, then main hands before off hands, including both weapon bars.
function G.plan(preset)
 if type(preset)~='table' or type(preset.items)~='table' then return nil,'Invalid preset.' end
 local cap=s(GetBagSize,BAG_BACKPACK);if type(cap)~='number' then return nil,'Backpack unavailable.' end
 local worn,pack,where,free,desired,seen={}, {}, {},0,{},{}
 for _,v in ipairs(G.slots) do
  local k=v[1];local slot=key(k);if type(slot)~='number' then return nil,'Equipment slot unavailable.' end
  local e,err=read(BAG_WORN,slot);if e==nil then return nil,err end
  worn[k]=e and e.id or false;if e then where[e.id]=k end
  local target=preset.items[k]
  if target==false then desired[k]=false
  elseif type(target)=='table' and type(target.id)=='string' and not seen[target.id] then desired[k]=target.id;seen[target.id]=true
  else return nil,'Preset is incomplete or has duplicate items. Overwrite it first.' end
 end
 for slot=0,cap-1 do
  local link=s(GetItemLink,BAG_BACKPACK,slot,LINK_STYLE_DEFAULT)
  if type(link)~='string' then return nil,'Backpack read failed.' end
  if link=='' then free=free+1 else
   local id=N.uid(BAG_BACKPACK,slot)
   if id and seen[id] then
    if where[id] then return nil,'Duplicate item identity; retry.' end
    where[id]='pack';pack[id]=true
    if s(IsEquipable,BAG_BACKPACK,slot)~=true then return nil,'Saved item is not currently equipable.' end
    if s(ZO_InventorySlot_WillItemBecomeBoundOnEquip,BAG_BACKPACK,slot)==true then return nil,'A saved item would bind on equip. Equip it manually first.' end
   end
  end
 end
 local missing={}
 for _,v in ipairs(G.slots) do local id=desired[v[1]];if id and not where[id] then local t=preset.items[v[1]];missing[#missing+1]=v[2]..': '..tostring(t.name or 'saved item') end end
 if #missing>0 then return nil,'Missing gear (retrieve from bank if stored): '..table.concat(missing,'; ') end
 local moves={}
 local function out(k)
  local id=worn[k];if not id then return true end
  if free<1 then return false end
  moves[#moves+1]={from=k,to='pack',id=id};worn[k]=false;where[id]='pack';pack[id]=true;free=free-1;return true
 end
 local function put(k,id)
  local from=where[id]
  if from~='pack' and not out(from) then return false end
  if worn[k] and not out(k) then return false end
  moves[#moves+1]={from='pack',to=k,id=id};worn[k]=id;where[id]=k;pack[id]=nil;free=free+1;return true
 end
 for _,v in ipairs(G.slots) do local k=v[1];if not desired[k] and not out(k) then return nil,'Not enough empty backpack slots to load this preset safely.' end end
 for _,v in ipairs(G.slots) do local k=v[1];local id=desired[k];if id and worn[k]~=id and not put(k,id) then return nil,'Not enough empty backpack slots to load this preset safely.' end end
 return moves
end
local function active(I,gameplay)
 local context=gameplay and I.gameplayReady and I.gameplayReady() or (not gameplay and I.focus)
 return context and N.enabled() and s(IsUnitInCombat,'player')==false and s(IsBankOpen)~=true
end
function G.load(I,name,dispatch,gameplay)
 if G.job or I.pending then return false,'Another item action is pending.' end
 if not active(I,gameplay) or type(zo_callLater)~='function' then return false,'Gear changes require gameplay or an open inventory outside combat.' end
 local preset=G.sets and G.sets[name];local moves,err=G.plan(preset)
 if not moves then return false,err end
 if #moves==0 then G.selected=name;message(name..' is already equipped.');return true end
 local job={index=1,moves=moves,name=name,owner=I,dialogWait=0};G.job=job;I.pending=true;G.status='Loading '..name..' (0/'..#moves..')';if gameplay then message(G.status) end
 local function finish(ok,reason)
  if G.job~=job then return end
  G.job=nil;I.pending=false;I.dirty=true
  if ok then G.selected=name;message('Equipped '..name..'.') else message('Stopped: '..reason..' Gear may be partially changed; retry when safe.') end
 end
 local function step()
  if G.job~=job then return end
  if job.cancelled or not active(I,gameplay) then finish(false,'cancelled, inventory closed or combat started.');return end
  if s(ZO_Dialogs_IsShowingDialog)==true then
   if job.index==1 and job.dialogWait<20 then job.dialogWait=job.dialogWait+1;zo_callLater(step,100) else finish(false,'a dialog interrupted gear loading.') end;return
  end
  local m=moves[job.index]
  if not m then
   local remaining,why=G.plan(preset)
   if remaining and #remaining==0 then finish(true) else finish(false,why or 'final gear verification failed.') end;return
  end
  local sb,ss,db,ds
  if m.from=='pack' then
   sb=BAG_BACKPACK
   for slot=0,(s(GetBagSize,BAG_BACKPACK) or 0)-1 do if N.uid(sb,slot)==m.id and s(GetItemLink,sb,slot,LINK_STYLE_DEFAULT)~='' then ss=slot;break end end
   db=BAG_WORN;ds=key(m.to)
  else sb=BAG_WORN;ss=key(m.from);db=BAG_BACKPACK;ds=s(FindFirstEmptySlotInBag,db) end
  if type(ss)~='number' or type(ds)~='number' or ds<0 or N.uid(sb,ss)~=m.id or s(GetItemLink,db,ds,LINK_STYLE_DEFAULT)~='' then finish(false,'source or destination changed.');return end
  if db==BAG_WORN and (s(IsEquipable,sb,ss)~=true or s(ZO_InventorySlot_WillItemBecomeBoundOnEquip,sb,ss)==true) then finish(false,'item cannot be equipped safely.');return end
  local ok,result=dispatch('RequestMoveItem',sb,ss,db,ds,1)
  if not ok or result==false then finish(false,'equipment move rejected.');return end
  local attempts=0
  local function verify()
   if G.job~=job then return end
   if job.cancelled or not active(I,gameplay) then finish(false,'cancelled, inventory closed or combat started.');return end
   if N.uid(db,ds)==m.id and N.uid(sb,ss)~=m.id then
    I.dirty=true;G.status='Loading '..name..' ('..job.index..'/'..#moves..')';job.index=job.index+1;zo_callLater(step,100)
   else attempts=attempts+1;if attempts>=20 then finish(false,'equipment move not confirmed.') else zo_callLater(verify,100) end end
  end
  zo_callLater(verify,100)
 end
 zo_callLater(step,100);return true
end
-- Native gamepad keyboard, same dialog pattern as OnePack item search.
local NAME_DIALOG='ONEPACK_GEAR_NAME';local registered=false
function G.promptName(I,layer,callback)
 if not (GAMEPAD_DIALOGS and GAMEPAD_DIALOGS.PARAMETRIC and ZO_Dialogs_RegisterCustomDialog and ZO_Dialogs_ShowGamepadDialog) then return false end
 local function finish(dialog) local data=dialog and dialog.data;if data and data.owner then data.owner.searching=false;data.owner.dirty=true end end
 if not registered then
  ZO_Dialogs_RegisterCustomDialog(NAME_DIALOG,{gamepadInfo={dialogType=GAMEPAD_DIALOGS.PARAMETRIC},blockDialogReleaseOnPress=true,
   title={text='Name gear preset'},mainText={text='Select the text field to open the keyboard. Then select Save preset.'},
   setup=function(dialog) G.nameDialog=dialog;dialog:setupFunc() end,finishedCallback=finish,noChoiceCallback=finish,
   parametricList={{template='ZO_Gamepad_GenericDialog_Parametric_TextFieldItem',templateData={
    setup=function(control,data,selected) control.highlight:SetHidden(not selected);local edit=control.editBoxControl;local owner=G.nameDialog and G.nameDialog.data
     edit:SetDefaultText('Enter preset name');edit:SetMaxInputChars(40);edit.textChangedCallback=function(c) if owner then owner.entered=c:GetText() end end;edit:SetText(owner and owner.entered or '') end,
    callback=function(dialog) local c=dialog.entryList:GetTargetControl();if c and c.editBoxControl then c.editBoxControl:TakeFocus() end end,narrationText=ZO_GetDefaultParametricListEditBoxNarrationText}},
    {template='ZO_GamepadTextFieldSubmitItem',templateData={text='Save preset',setup=ZO_SharedGamepadEntry_OnSetup,callback=function(dialog) local data=dialog.data;finish(dialog);ZO_Dialogs_ReleaseDialogOnButtonPress(NAME_DIALOG);if data and data.callback then data.callback(data.entered) end end}}},
   buttons={{keybind='DIALOG_PRIMARY',text=SI_GAMEPAD_SELECT_OPTION,callback=function(dialog) local target=dialog.entryList:GetTargetData();if target and target.callback then target.callback(dialog) end end},
    {keybind='DIALOG_NEGATIVE',text=SI_DIALOG_CANCEL,callback=function(dialog) finish(dialog);ZO_Dialogs_ReleaseDialogOnButtonPress(NAME_DIALOG) end}}})
  registered=true
 end
 I.searching=true;N.dialogFocus(I,layer)
 local ok=pcall(ZO_Dialogs_ShowGamepadDialog,NAME_DIALOG,{owner=I,entered='',callback=callback})
 if not ok then I.searching=false;N.dialogFocus(I,layer) end;return ok
end
local CONFIRM='ONEPACK_GEAR_CONFIRM';local confirmRegistered=false
function G.confirm(text,callback)
 if not (GAMEPAD_DIALOGS and GAMEPAD_DIALOGS.BASIC and ZO_Dialogs_RegisterCustomDialog and ZO_Dialogs_ShowGamepadDialog) then return false end
 if not confirmRegistered then ZO_Dialogs_RegisterCustomDialog(CONFIRM,{gamepadInfo={dialogType=GAMEPAD_DIALOGS.BASIC},title={text='Gear presets'},mainText={text='<<1>>'},buttons={{keybind='DIALOG_PRIMARY',text='Confirm',callback=function(dialog) if dialog.data and dialog.data.callback then dialog.data.callback() end end},{keybind='DIALOG_NEGATIVE',text='Cancel'}}});confirmRegistered=true end
 return pcall(ZO_Dialogs_ShowGamepadDialog,CONFIRM,{callback=callback},{mainTextParams={text}})
end
