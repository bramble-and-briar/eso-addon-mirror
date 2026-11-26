local N=TMENexus
local s=N.safe
local UI={slots={},resources={}}
local powerCache={}
local function power(kind)
 local modern=_G['COMBAT_MECHANIC_FLAGS_'..kind]
 local legacy=_G['POWERTYPE_'..kind]
 for _,key in ipairs({modern or legacy or false,legacy or false}) do
  if key then local a,b=s(GetUnitPower,'player',key);if type(a)=='number' and type(b)=='number' and b>0 then return a,b end end
 end
 for i=1,12 do local k,a,b=s(GetUnitPowerInfo,"player",i);if k~=nil and (k==modern or k==legacy) and type(a)=="number" and type(b)=="number" and b>0 then return a,b end end
 local cached=powerCache[kind];if cached then return cached[1],cached[2] end
end
local function onPower(_,tag,index,kind,value,max)
 if tag~='player' or type(value)~='number' or type(max)~='number' or max<=0 then return end
 for _,name in ipairs({'HEALTH','MAGICKA','STAMINA','ULTIMATE'}) do
  if kind==_G['COMBAT_MECHANIC_FLAGS_'..name] or kind==_G['POWERTYPE_'..name] then powerCache[name]={value,max} end
 end
end
local function label(parent,size)
 local l=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL);l:SetFont('$(BOLD_FONT)|'..size..'|soft-shadow-thick');l:SetHorizontalAlignment(TEXT_ALIGN_CENTER);l:SetVerticalAlignment(TEXT_ALIGN_CENTER);l:SetAnchorFill(parent);return l
end
local function frame(parent,w,h)
 local p=WINDOW_MANAGER:CreateControl(nil,parent,CT_CONTROL);p:SetDimensions(w,h)
 local bg=WINDOW_MANAGER:CreateControl(nil,p,CT_BACKDROP);bg:SetAnchorFill(p);bg:SetCenterColor(.025,.023,.020,.93);bg:SetEdgeColor(.66,.51,.29,1);bg:SetEdgeTexture('',1,1,1);return p,bg
end
local function texture(parent)
 local t=WINDOW_MANAGER:CreateControl(nil,parent,CT_TEXTURE);t:SetAnchorFill(parent);return t
end
local function build()
 UI.root=WINDOW_MANAGER:CreateTopLevelWindow('TMENexusInterface');UI.root:SetDimensions(480,200);UI.root:SetMouseEnabled(false);UI.root:SetDrawTier(DT_HIGH)
 UI.barRoot=WINDOW_MANAGER:CreateControl(nil,UI.root,CT_CONTROL);UI.barRoot:SetDimensions(480,150)
 UI.resourceRoot=WINDOW_MANAGER:CreateControl(nil,UI.root,CT_CONTROL);UI.resourceRoot:SetDimensions(660,52)
 for r=1,2 do UI.slots[r]={};for i=1,6 do
  local p,bg=frame(UI.barRoot,64,64);p:SetAnchor(TOPLEFT,UI.barRoot,TOPLEFT,36+(i-1)*68,(r-1)*68)
  local icon=texture(p);icon:ClearAnchors();icon:SetAnchor(TOPLEFT,p,TOPLEFT,2,2);icon:SetAnchor(BOTTOMRIGHT,p,BOTTOMRIGHT,-2,-2);local timer=label(p,i==6 and 22 or 29);if i~=6 then timer:SetFont("$(BOLD_FONT)|29|outline");timer:ClearAnchors();timer:SetAnchor(BOTTOM,p,BOTTOM,0,-4);timer:SetDimensions(62,34) end;timer:SetDrawLayer(DL_TEXT or DL_OVERLAY);s(timer.SetDrawLevel,timer,5);local cd=WINDOW_MANAGER:CreateControl(nil,p,CT_TEXTURE);cd:SetColor(0,0,0,.48);cd:SetAnchor(TOPLEFT,p,TOPLEFT,2,2);cd:SetWidth(60);cd:SetDrawLayer(DL_OVERLAY);s(cd.SetDrawLevel,cd,2);cd:SetHidden(true);timer:SetDrawLayer(DL_OVERLAY);s(timer.SetDrawLevel,timer,5)
  local glow={};if i==6 then for j=1,4 do local g=WINDOW_MANAGER:CreateControl(nil,p,CT_TEXTURE);g:SetColor(1,.75,.12,1);g:SetDrawLayer(DL_OVERLAY);g:SetHidden(true);if j<=2 then g:SetDimensions(70,3);g:SetAnchor(j==1 and TOP or BOTTOM,p,j==1 and TOP or BOTTOM,0,0) else g:SetDimensions(3,70);g:SetAnchor(j==3 and LEFT or RIGHT,p,j==3 and LEFT or RIGHT,0,0) end;glow[j]=g end end
  local stackLabel;if i~=6 then stackLabel=label(p,15);stackLabel:ClearAnchors();stackLabel:SetAnchor(TOPRIGHT,p,TOPRIGHT,-3,2);stackLabel:SetDimensions(24,19);stackLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT);stackLabel:SetDrawLayer(DL_OVERLAY);s(stackLabel.SetDrawLevel,stackLabel,6) end
  UI.slots[r][i]={p=p,bg=bg,icon=icon,timer=timer,cd=cd,glow=glow,stacks=stackLabel}
 end end
 UI.keys={};for i,k in ipairs({'',' ','','L1','R1','L1+R1'}) do local l=label(UI.barRoot,15);l:ClearAnchors();l:SetAnchor(TOPLEFT,UI.barRoot,TOPLEFT,36+(i-1)*68,133);l:SetDimensions(64,18);l:SetText(k);UI.keys[i]=l
 if i<=3 then
  local function line(x,y,w,h) local q=WINDOW_MANAGER:CreateControl(nil,l,CT_TEXTURE);q:SetColor(.9,.93,1,1);q:SetDimensions(w,h);q:SetAnchor(CENTER,l,CENTER,x,y);return q end
  if i==1 then line(0,-6,12,2);line(0,6,12,2);line(-6,0,2,12);line(6,0,2,12)
  elseif i==2 then line(0,6,14,2);for j=0,6 do line(-j,-6+j*2,2,3);line(j,-6+j*2,2,3) end
  else for j=0,15 do local angle=j*math.pi/8;line(math.cos(angle)*6,math.sin(angle)*6,3,3) end end
 end end
 for i,v in ipairs({{"MAGICKA",.16,.45,.92},{"HEALTH",.85,.16,.22},{"STAMINA",.15,.7,.35}}) do
  local p=frame(UI.resourceRoot,214,44);p:SetAnchor(TOPLEFT,UI.resourceRoot,TOPLEFT,(i-1)*223,0)
  local fill=WINDOW_MANAGER:CreateControl(nil,p,CT_BACKDROP);fill:SetAnchor(TOPLEFT,p,TOPLEFT,2,2);fill:SetCenterColor(v[2],v[3],v[4],1);fill:SetEdgeColor(0,0,0,0);fill:SetHeight(40);fill:SetWidth(1)
  local txt=label(p,22);txt:SetDrawLayer(DL_TEXT or DL_OVERLAY);s(txt.SetDrawLevel,txt,5)
  local o={p=p,fill=fill,text=txt,power=v[1],color=v};UI.resources[i]=o
  if i~=2 then
   local arc=WINDOW_MANAGER:CreateControl(nil,UI.resourceRoot,CT_CONTROL);arc:SetDimensions(128,300);o.arc=arc
   o.parts={};local side=i==1 and -1 or 1
   for j=1,40 do
    local f=(j-.5)/40;local x=64+side*35*math.sin(math.pi*f);local y=270-250*f
    local bg=WINDOW_MANAGER:CreateControl(nil,arc,CT_TEXTURE);bg:SetDimensions(20,8);bg:SetAnchor(CENTER,arc,TOPLEFT,x,y);bg:SetColor(.06,.09,.12,.9)
    local q=WINDOW_MANAGER:CreateControl(nil,arc,CT_TEXTURE);q:SetDimensions(14,7);q:SetAnchor(CENTER,arc,TOPLEFT,x,y);q:SetColor(v[2],v[3],v[4],1);o.parts[j]=q
   end
   local t=label(arc,18);t:ClearAnchors();t:SetDimensions(180,30);t:SetAnchor(TOP,arc,BOTTOM,0,-20);o.arcText=t
  end
 end
 local mode=label(UI.root,15);mode:ClearAnchors();mode:SetAnchor(TOP,UI.root,TOP,0,0);mode:SetDimensions(420,22);mode:SetColor(.88,.76,.52,1);UI.mode=mode
end
local hidden={}
local function restore()
 for c,a in pairs(hidden) do s(c.SetAlpha,c,a);hidden[c]=nil end
end
local function suppress(c)
 if c and c.GetAlpha and c.SetAlpha then if hidden[c]==nil then hidden[c]=s(c.GetAlpha,c) end;s(c.SetAlpha,c,0) end
end
-- Native placement is optional and must never disable the combat HUD.
local buffOriginal,synergyOriginal={},{}
local function method(c,k,...)
 local ok,f=pcall(function() return c[k] end)
 if not ok or type(f)~='function' then return false end
 return pcall(f,c,...)
end
local function restoreOne(c,anchors)
 if not method(c,'ClearAnchors') then return false end
 for _,v in ipairs(anchors) do if not method(c,'SetAnchor',v[1],v[2],v[3],v[4],v[5]) then return false end end
 return true
end
local function restoreNative(store)
 for c,anchors in pairs(store) do if restoreOne(c,anchors) then store[c]=nil end end
end
local function relocate(c,store,anchor,x,y)
 if not c or not anchor then return false end
 if not store[c] then
  local ok,n=method(c,'GetNumAnchors');if not ok or type(n)~='number' or n<1 then return false end
  local anchors={}
  for j=0,n-1 do
   local success,valid,p,rel,rp,ax,ay=method(c,'GetAnchor',j)
   if not success or not valid or p==nil or rp==nil then return false end
   anchors[#anchors+1]={p,rel,rp,ax,ay}
  end
  store[c]=anchors
 end
 if method(c,'ClearAnchors') and method(c,'SetAnchor',BOTTOM,anchor,TOP,x,y) then return true end
 if restoreOne(c,store[c]) then store[c]=nil end
 return false
end
local function moveBuffs(cfg,visible)
 if not (cfg.moveNativeBuffs and cfg.resources and visible) then restoreNative(buffOriginal);return end
 for _,name in ipairs({'ZO_BuffDebuffTopLevelSelfContainer','ZO_BuffDebuffTopLevelSelf','ZO_BuffDebuffTopLevelGamepadSelfContainer','ZO_BuffDebuffTopLevelGamepadSelf','ZO_BuffDebuffTopLevel'}) do
  if relocate(_G[name],buffOriginal,UI.resourceRoot,cfg.buffX or 0,-40+(cfg.buffY or 0)) then return end
 end
end
local function restoreSynergy() restoreNative(synergyOriginal) end
local function moveSynergy(cfg,visible)
 if not cfg.moveSynergy or not visible or not (cfg.resources or cfg.bars) then restoreSynergy();return end
 local anchor=cfg.resources and UI.resourceRoot or UI.barRoot
 local gap=cfg.moveNativeBuffs and cfg.resources and math.max(135,135-(cfg.buffY or 0)) or 35
 local function try(c) return relocate(c,synergyOriginal,anchor,cfg.synergyX or 0,-gap+(cfg.synergyY or 0)) end
 for _,name in ipairs({'SYNERGY','SYNERGY_GAMEPAD','GAMEPAD_SYNERGY'}) do local obj=_G[name];if type(obj)=='table' then if try(obj.control) then return end;local ok,c=method(obj,'GetControl');if ok and try(c) then return end end end
 for _,name in ipairs({'ZO_SynergyTopLevel','ZO_SynergyTopLevelGamepad','ZO_GamepadSynergyTopLevel','ZO_SynergyGamepad','ZO_Synergy'}) do if try(_G[name]) then return end end
end
local queueOriginal={}
local function queuePending()
 local f=_G.IsLFGReadyCheckInProgress
 if type(f)=='function' then local ok,v=pcall(f);if ok and type(v)=='boolean' then return v end end
 local f=_G.GetLFGReadyCheckState
 if type(f)=='function' then local ok,v=pcall(f);if ok and _G.LFG_READY_CHECK_STATE_PENDING~=nil then return v==LFG_READY_CHECK_STATE_PENDING end end
 return nil
end
local function moveQueue(cfg,visible)
 if not visible or not (cfg.bars or cfg.resources) then restoreNative(queueOriginal);return false end
 local pending=queuePending()
 local anchor=cfg.resources and UI.resourceRoot or UI.barRoot
 local found=false
 for _,name in ipairs({'ZO_LFGReadyCheckGamepad','ZO_LFGReadyCheck','ZO_ActivityFinderReadyCheckGamepad','ZO_ActivityFinderReadyCheck','ZO_GamepadLFGReadyCheck','ZO_ReadyCheckGamepad'}) do
  local c=_G[name]
  if c then local ok,h=method(c,'IsHidden');if ok and not h then
   found=true
   if relocate(c,queueOriginal,anchor,0,-180) then return false end
  end end
 end
 restoreNative(queueOriginal)
 -- If native prompt cannot be relocated, yield the overlapping HUD during a detected ready check.
 return pending==true or found
end
local E=N.abilityEngine
local boundId=E.bound
local function update()
 if not N.saved or not UI.root then return end
 local cfg=N.saved;local visible=N.gameplay() or cfg.preview
 UI.root:SetHidden(not visible or (not cfg.bars and not cfg.resources));UI.root:ClearAnchors();UI.root:SetAnchor(BOTTOM,GuiRoot,BOTTOM,cfg.x,cfg.y);UI.root:SetScale(cfg.scale/100)
 UI.mode:SetHidden(true)
 UI.barRoot:ClearAnchors();UI.barRoot:SetAnchor(BOTTOM,UI.root,BOTTOM,cfg.barX or 0,cfg.barY or 0);UI.barRoot:SetScale((cfg.barScale or 100)/100);UI.barRoot:SetHidden(not cfg.bars)
 UI.resourceRoot:ClearAnchors();UI.resourceRoot:SetAnchor(BOTTOM,UI.root,BOTTOM,cfg.resourceX or 0,cfg.resourceY or -160);UI.resourceRoot:SetScale((cfg.resourceScale or 100)/100);UI.resourceRoot:SetHidden(not cfg.resources)
 pcall(moveBuffs,cfg,visible)
 pcall(moveSynergy,cfg,visible)
 local queueOK,queueYield=pcall(moveQueue,cfg,visible)
 queueYield=queueOK and queueYield
 if queueYield then UI.root:SetHidden(true);visible=false end
 local bars={HOTBAR_CATEGORY_PRIMARY or 0,HOTBAR_CATEGORY_BACKUP or 1};local active=s(GetActiveHotbarCategory)
 local t=s(GetFrameTimeSeconds) or 0;E.tick(t)
 local values={};local maxima={};for _,kind in ipairs({"MAGICKA","HEALTH","STAMINA","ULTIMATE"}) do values[kind],maxima[kind]=power(kind) end
 local valid=false;local activeSlots=0
 local activeValid=active==bars[1] or active==bars[2]
 for r,row in ipairs(UI.slots) do for i,o in ipairs(row) do
  local slot=i+2;local id=boundId(slot,bars[r],active);local icon=s(GetSlotTexture,slot,bars[r])
  if id and id~=0 and icon and icon~='' then valid=true;if active==bars[r] then activeSlots=activeSlots+1 end;o.icon:SetTexture(icon);o.icon:SetHidden(false) else o.icon:SetHidden(true) end
  o.p:SetHidden(not cfg.bars);local rem,estimated,stacks=E.duration(id,t);local durationText=rem and (rem>3 and tostring(math.ceil(rem)) or string.format('%.1f',rem));local warn=rem;local ready=warn and warn<=5 and warn>0
  o.bg:SetEdgeColor(ready and 1 or (active==bars[r] and .78 or .42),ready and (warn<=3 and .2 or .8) or (active==bars[r] and .62 or .34),ready and .1 or (active==bars[r] and .34 or .21),1)
  local poor=false
  if cfg.dimUnaffordable and type(id)=='number' and id>0 then
   if active==bars[r] then
    poor=s(ActionSlotHasCostFailure,slot,bars[r])
   end
   if type(poor)~='boolean' or active~=bars[r] then
    poor=false
    for _,kind in ipairs({"MAGICKA","STAMINA","HEALTH","ULTIMATE"}) do
     local flag=_G['COMBAT_MECHANIC_FLAGS_'..kind];local value=values[kind]
     if flag and type(value)=='number' then local cost=s(GetAbilityCost,id,flag,nil,'player');if type(cost)=='number' and cost>0 and value<cost then poor=true;break end end
    end
   end
  end
  if o.poor~=poor then s(o.icon.SetDesaturation,o.icon,poor and 1 or 0);o.poor=poor end
  o.icon:SetAlpha(poor and .28 or (active==bars[r] and 1 or .65))
  -- Slot cooldown lookups are only trusted for the active hotbar.
  local cd,cdDuration,global
  if active==bars[r] then cd,cdDuration,global=s(GetSlotCooldownInfo,slot,bars[r]);if type(cd)~='number' then cd,cdDuration,global=s(GetSlotCooldownInfo,slot) end end
  local cooling=type(cd)=='number' and cd>0 and type(cdDuration)=='number' and cdDuration>0
  o.cd:SetHidden(not cooling)
  if cooling then o.cd:SetHeight(math.max(1,60*math.min(1,cd/cdDuration))) end
  if slot==8 then
   local ult=values.ULTIMATE
   -- Only the active hotbar may glow: slot cost can resolve to the active slot even with a category argument.
   local cost
   if active==bars[r] and type(id)=='number' and id>0 then
    cost=s(GetSlotAbilityCost,slot,bars[r]);if type(cost)~='number' or cost<=0 then cost=s(GetAbilityCost,id,COMBAT_MECHANIC_FLAGS_ULTIMATE or POWERTYPE_ULTIMATE) end
   end
   local charged=not poor and active==bars[r] and type(ult)=='number' and type(cost)=='number' and cost>0 and ult>=cost
   for _,g in ipairs(o.glow) do g:SetHidden(not charged);if charged then g:SetAlpha(.65+.35*math.sin(t*7)) end end
   o.timer:SetText(tostring(ult or ''))
  else o.timer:SetText(durationText or '') end
  if slot==8 then o.timer:SetColor(1,1,1,1) elseif rem and rem<=3 then o.timer:SetColor(1,.40,.32,1) elseif ready then o.timer:SetColor(1,.80,.40,1) else o.timer:SetColor(1,.96,.86,1) end
  if o.stacks then o.stacks:SetText(stacks and stacks>1 and tostring(stacks) or "") end
 end end
 local resourceValid=true
 for _,o in ipairs(UI.resources) do
  local value,max=values[o.power],maxima[o.power];local curved=cfg.curvedResources and o.arc~=nil
  o.p:SetHidden(not cfg.resources or curved)
  if o.arc then
   o.arc:SetHidden(not cfg.resources or not curved)
   if curved then
    o.arc:ClearAnchors();o.arc:SetAnchor(CENTER,GuiRoot,CENTER,(o.power=='MAGICKA' and -1 or 1)*(cfg.arcDistance or 330)+(cfg.resourceX or 0),cfg.arcY or 0)
   end
  end
  local fraction=0;local str='—'
  if type(max)=='number' and max>0 and type(value)=='number' then fraction=math.max(0,math.min(1,value/max));str=string.format('%d / %d  (%d%%)',value,max,math.floor(100*fraction)) else resourceValid=false end
  if curved then
   for j,q in ipairs(o.parts) do local alpha=math.max(0,math.min(1,fraction*#o.parts-j+1));if q.lastAlpha~=alpha then q:SetAlpha(alpha);q.lastAlpha=alpha end end
   local low=fraction<.2 and cfg.resourcePulse; o.arc:SetAlpha(low and (.75+.25*math.sin(t*6)) or 1)
   o.arcText:SetText(cfg.resourceNumbers and str or (str=='—' and str or string.format('%d%%',math.floor(fraction*100))))
  else
   o.fill:SetWidth(math.max(1,210*fraction));o.text:SetText(cfg.resourceNumbers and str or (str=='—' and str or string.format('%d%%',math.floor(fraction*100))))
  end
 end
 restore();N.customBarsActive=cfg.bars and cfg.replaceAction and valid and activeSlots>0 and activeValid and visible and not cfg.preview
 if N.customBarsActive then
  for slot=3,8 do local b=s(ZO_ActionBar_GetButton,slot) or (ACTION_BAR and s(ACTION_BAR.GetButton,ACTION_BAR,slot));local c=b and (s(b.GetControl,b) or b.slot or b.control) or _G['ActionButton'..slot];suppress(c);suppress(_G['ActionButton'..slot]);suppress(_G['ZO_ActionBar1Button'..slot]) end
 end
 if cfg.resources and cfg.replaceResources and resourceValid and visible and not cfg.preview then for _,key in ipairs({'ZO_PlayerAttributeHealth','ZO_PlayerAttributeMagicka','ZO_PlayerAttributeStamina','ZO_PlayerAttributeGamepadHealth','ZO_PlayerAttributeGamepadMagicka','ZO_PlayerAttributeGamepadStamina','ZO_PlayerAttributeHealthGamepad','ZO_PlayerAttributeMagickaGamepad','ZO_PlayerAttributeStaminaGamepad'}) do suppress(_G[key]) end;for _,rootName in ipairs({"ZO_PlayerAttribute","ZO_PlayerAttributeBars","ZO_PlayerAttributeGamepad","ZO_PlayerAttributeBarsGamepad"}) do local root=_G[rootName];if root then for _,key in ipairs({"Health","Magicka","Stamina"}) do suppress(s(GetControl,root,key)) end end end end
end
local function preset(minimal)
 local cfg=N.saved;cfg.bars=true;cfg.resources=true;cfg.replaceAction=true;cfg.replaceResources=true;cfg.x=0;cfg.y=-100;cfg.scale=100;cfg.setupDone=true
 if N.applyDungeonLayout then N.applyDungeonLayout(minimal) end
 local gs=GoldStandard
 if gs and gs.saved then gs.saved.showWealthHUD=false;gs.saved.showHUD=not minimal;gs.saved.hudPosX=2;gs.saved.hudPosY=84;gs.saved.hudScale=75;if gs.ApplyLayout then gs:ApplyLayout('hud') end;if gs.RefreshUI then gs:RefreshUI() end end
end
local function prompt()
 if N.saved.setupDone or not N.gameplay() then return end
 if not ZO_Dialogs_RegisterCustomDialog or not ZO_Dialogs_ShowGamepadDialog or not GAMEPAD_DIALOGS then return end
 if not N.setupRegistered then
  ZO_Dialogs_RegisterCustomDialog('ARSENAL_FIRST_SETUP',{gamepadInfo={dialogType=GAMEPAD_DIALOGS.BASIC},title={text='ESO Arsenal | First-time setup'},mainText={text='Recommended: contextual combat and economy HUDs. Minimal: action bars, resources and essential combat alerts. All engines continue tracking. Change layouts anytime in Arsenal settings.'},buttons={{text='Recommended',callback=function() preset(false) end},{text='Minimal',callback=function() preset(true) end}},noChoiceCallback=function() N.saved.setupDone=true end});N.setupRegistered=true
 end
 ZO_Dialogs_ShowGamepadDialog('ARSENAL_FIRST_SETUP');N.setupShown=true
end
local function settings()
 local lam=LibAddonMenu2;if not lam then return end
 local id='TMENexusSettings';lam:RegisterAddonPanel(id,{type='panel',name='ESO Arsenal',displayName='ESO Arsenal',author='Trash Man Enterprises',version='0.6.0',registerForRefresh=true})
 local opts={{type='button',name='Apply recommended layout',func=function() preset(false) end},{type='button',name='Apply minimal layout',func=function() preset(true) end}};local function toggle(k,n) return {type='checkbox',name=n,getFunc=function()return N.saved[k]end,setFunc=function(v)N.saved[k]=v;update()end} end
 local function slider(k,n,a,b) return {type='slider',name=n,min=a,max=b,step=5,getFunc=function()return N.saved[k]end,setFunc=function(v)N.saved[k]=v;update()end} end
 opts[#opts+1]={type='submenu',name='Core interface & placement',controls={toggle('bars','Dual action bars'),toggle('resources','Resource meters'),toggle('curvedResources','Curved Magicka / Stamina'),toggle('dimUnaffordable','Dim unaffordable abilities'),toggle('resourceNumbers','Show resource numbers'),toggle('resourcePulse','Pulse low side resources'),slider('arcDistance','Side meter distance',150,900),slider('arcY','Side meter vertical offset',-600,600),toggle('replaceAction','Hide native ability slots (experimental)'),toggle('replaceResources','Hide native resource meters (experimental)'),toggle('preview','Preview layout'),toggle('moveSynergy','Move native synergy prompt'),slider('synergyX','Synergy prompt X',-1500,1500),slider('synergyY','Synergy prompt Y',-1000,1000),{type='button',name='Reset synergy placement',func=function() N.saved.synergyX=0;N.saved.synergyY=0;update() end},toggle('moveNativeBuffs','Move native buff icons'),slider('buffX','Native buffs X',-1500,1500),slider('buffY','Native buffs Y',-1000,1000),{type='button',name='Reset native buff placement',func=function() N.saved.buffX=0;N.saved.buffY=0;update() end},slider('x','Horizontal offset',-1500,1500),slider('y','Vertical offset',-1000,0),slider('scale','Overall scale (%)',50,200),slider('barX','Action bars X',-1500,1500),slider('barY','Action bars Y',-1000,1000),slider('barScale','Action bars scale (%)',50,200),slider('resourceX','Resource meters X',-1500,1500),slider('resourceY','Resource meters Y',-1000,1000),slider('resourceScale','Resource meters scale (%)',50,200)}}
 -- Flatten original nested submenus to avoid unsupported nested LAM controls.
 local keys={};for k in pairs(N.settingsGroups) do keys[#keys+1]=k end;table.sort(keys)
 for _,k in ipairs(keys) do local g=N.settingsGroups[k];local flat={};for _,o in ipairs(g.controls or {}) do if o.type=='submenu' then flat[#flat+1]={type='header',name=o.name};for _,c in ipairs(o.controls or {}) do flat[#flat+1]=c end else flat[#flat+1]=o end end;opts[#opts+1]={type='submenu',name=g.name or k,controls=flat} end
 if N.expansion and N.expansion.options then opts[#opts+1]={type='submenu',name='Arsenal Expansion',controls=N.expansion.options()} end
 if N.inventory and N.inventory.options then opts[#opts+1]={type="submenu",name="Arsenal Inventory",controls=N.inventory.options()} end
 if N.hardcore and N.hardcore.options then opts[#opts+1]={type="submenu",name="Hardcore Survival (Preview)",controls=N.hardcore.options()} end
 lam:RegisterOptionControls(id,opts)
 if CALLBACK_MANAGER then CALLBACK_MANAGER:RegisterCallback('LAM-PanelClosed',function() N.saved.preview=false end) end
end
EVENT_MANAGER:RegisterForEvent('NexusInit',EVENT_ADD_ON_LOADED,function(_,name)
 if name~='TMENexus' then return end;EVENT_MANAGER:UnregisterForEvent('NexusInit',EVENT_ADD_ON_LOADED)
 N.saved=ZO_SavedVars:NewAccountWide('NexusCoreSaved',1,nil,{bars=true,resources=true,replaceAction=true,replaceResources=true,x=0,y=-100,scale=100,barX=0,barY=0,barScale=100,resourceX=0,resourceY=-160,resourceScale=100,moveSynergy=true,synergyX=0,synergyY=0,moveNativeBuffs=true,buffX=0,buffY=0,preview=false,curvedResources=true,dimUnaffordable=true,resourceNumbers=true,resourcePulse=true,arcDistance=330,arcY=0});N.saved.preview=false
 if not N.saved.layoutV31 then N.saved.moveNativeBuffs=true;N.saved.buffX=0;N.saved.buffY=0;N.saved.layoutV31=true end
 if not N.saved.layoutV3 then N.saved.replaceAction=true;N.saved.replaceResources=true;N.saved.layoutV3=true end
 E.register()
 if EVENT_POWER_UPDATE then EVENT_MANAGER:RegisterForEvent('ArsenalPower',EVENT_POWER_UPDATE,onPower) end
 if not N.saved.layoutV2 then preset(false);N.saved.setupDone=false;N.saved.layoutV2=true end
 EVENT_MANAGER:RegisterForUpdate('ArsenalSetup',1500,function() if N.saved.setupDone or N.setupShown then EVENT_MANAGER:UnregisterForUpdate('ArsenalSetup');return end;pcall(prompt) end)
 local ok,e=pcall(build);if not ok then if UI.root then UI.root:SetHidden(true) end;if d then d('ESO Arsenal UI: '..tostring(e)) end else
 EVENT_MANAGER:RegisterForUpdate('NexusInterface',100,function() local success,err=pcall(update);if not success then pcall(restoreNative,buffOriginal);pcall(restoreSynergy);pcall(restoreNative,queueOriginal);restore();N.customBarsActive=false;UI.root:SetHidden(true);EVENT_MANAGER:UnregisterForUpdate('NexusInterface');if d then d('ESO Arsenal UI disabled: '..tostring(err)) end end end)
 end
 zo_callLater(function() local ok,err=pcall(settings);if not ok and d then d('ESO Arsenal settings: '..tostring(err)) end end,1000)
end)
