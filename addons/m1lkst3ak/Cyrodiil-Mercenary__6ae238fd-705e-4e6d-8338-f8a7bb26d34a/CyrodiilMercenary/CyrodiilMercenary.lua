local N='CyrodiilMercenary'
local C={nodes={},errors={},active=false}
local function call(n,...)
 local f=_G[n]; if type(f)~='function' then return nil end
 local ok,a,b,c,d,e=pcall(f,...); if ok then return a,b,c,d,e end
 C.errors[n]=tostring(a); return nil
end
local function log(s) if d then d('[CC] '..s) end end
local function dist(a,b) if not a or not b or not a.x or not b.x then return 2 end return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2) end
local function xy(x,y) return type(x)=='number' and type(y)=='number' and x>=0 and y>=0 and x<=1 and y<=1 end
local function lower(s) return string.lower(s or '') end
local ring={'chalman','blue road','alessia','roebeck','ash','aleswell'}
local home={[ALLIANCE_EBONHEART_PACT or 3]={'arrius','kingscrest','farragut'},[ALLIANCE_ALDMERI_DOMINION or 1]={'faregyl','black boot','bloodmayne'},[ALLIANCE_DAGGERFALL_COVENANT or 2]={'glademist','rayles','warden'}}
local function contains(s,t) for _,v in ipairs(t or {}) do if string.find(s,v,1,true) then return true end end return false end
local function scan()
 local now=GetFrameTimeMilliseconds(); local old=C.mission; local oldScore; local oldReason; local incumbent; local contested=0
 local ctx=BGQUERY_LOCAL or 0; local nodes={}; local seen={}
 local function add(id,x,y,transit)
  if type(id)~='number' or id<=0 or seen[id] then return end
  local name=call('GetKeepName',id); if type(name)~='string' or name=='' then return end
  local owner=call('GetKeepAlliance',id,ctx); if type(owner)~='number' then return end
  if not xy(x,y) then local a,b,c=call('GetKeepPinInfo',id,ctx); if xy(b,c) then x,y=b,c elseif xy(a,b) then x,y=a,b else x,y=nil,nil end end
  seen[id]=true; nodes[#nodes+1]={id=id,transit=transit==true,name=name,owner=owner,x=x,y=y,attack=call('GetKeepUnderAttack',id,ctx)==true,kind=call('GetKeepType',id),accessible=call('GetKeepAccessible',id,ctx),resources=call('GetKeepHasResourcesForTravel',id,ctx)}
 end
 local count=call('GetNumKeepTravelNetworkNodes',ctx) or call('GetNumKeepTravelNetworkNodes') or 0
 for i=1,count do local id=call('GetKeepTravelNetworkNodeKeepId',i,ctx) or call('GetKeepTravelNetworkNodeKeepId',i); local x,y=call('GetKeepTravelNetworkNodePosition',i,ctx); if not xy(x,y) then x,y=call('GetKeepTravelNetworkNodePosition',i) end; add(id,x,y,true) end
 local total=call('GetNumKeeps') or call('GetNumKeepKeys') or 0
 for i=1,total do local id=call('GetKeepKeysByIndex',i); add(id) end
 -- Bounded fallback for clients lacking keep enumeration; not a distance filter.
 if total==0 then for id=1,200 do add(id) end end
 C.nodes=nodes; C.count=#nodes; C.coverage=total>0 and "Enumerated" or "Fallback / partial"
 local faction=call('GetUnitAlliance','player'); if not faction then C.mission=nil; return end
 local best,score,reason
 for _,k in ipairs(nodes) do
  if k.attack or (C.skirmishes and C.skirmishes[k.id] and now-C.skirmishes[k.id]<45000) then
   contested=contested+1
   local s=lower(k.name); local own=k.owner==faction; local resource=(KEEPTYPE_RESOURCE~=nil and k.kind==KEEPTYPE_RESOURCE) or contains(s,{'farm','mine','lumbermill'}); local p=own and 45 or 25; local r=own and 'Friendly objective under attack' or 'Contested enemy objective'
   if resource then p=p-25; r='Contested resource' elseif own and contains(s,home[faction]) then p=100; r='Homeland keep under attack' elseif contains(s,ring) then p=own and 85 or 75; r='Emperor ring objective' elseif own and contains(s,{'scroll','temple','gate'}) then p=110; r='Scroll defense' elseif own and k.resources==false then p=65; r='Transit supply threatened' end
   if not k.attack then r="Reported local skirmish | "..r end
   if old and old.id==k.id then incumbent,oldScore,oldReason=k,p,r end
   if not score or p>score or (p==score and k.id<best.id) then best,score,reason=k,p,r end
  end
 end
 C.contested=contested
 -- Keep a still-contested assignment unless the replacement is materially better.
 if incumbent and best and best.id~=incumbent.id then
  local threshold=(now-(C.assignedAt or 0)<60000) and 20 or 10
  if score-oldScore<threshold then best,score,reason=incumbent,oldScore,oldReason end
 end
 if not old or not best or old.id~=best.id then C.assignedAt=now end
 C.mission=best; C.score=score; C.reason=reason; C.travel=nil
 if best then
  local bd=2
  for _,k in ipairs(nodes) do
   if k.owner==faction and not k.attack and k.resources~=false and k.x and best.x and (k.transit or k.accessible==true) and k.accessible~=false then
    local v=dist(k,best)+(k.accessible==true and 0 or .25); if v<bd then C.travel=k; bd=v end
   end
  end
 end
end
local function place(w,key)
 local s=C.sv[key]; w:SetScale(s.scale)
 local width,height=GuiRoot:GetDimensions()
 local x=math.max(0,width-w:GetWidth()*s.scale)*(s.h or 5)/100
 local y=math.max(0,height-w:GetHeight()*s.scale)*(s.v or 20)/100
 w:ClearAnchors(); w:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,x,y)
end
local backgrounds={}
local function hudVisible()
 return not SCENE_MANAGER or not SCENE_MANAGER.IsShowing or SCENE_MANAGER:IsShowing('hud') or SCENE_MANAGER:IsShowing('hudui')
end

-- TME shared blue frame; anchored strips follow resizing and scaling.
local function TMEBlueFrame(parent)
    local function edge(a,b,c,d,vertical)
        local t=WINDOW_MANAGER:CreateControl(nil,parent,CT_TEXTURE)
        t:SetAnchor(a,parent,b,0,0); t:SetAnchor(c,parent,d,0,0)
        if vertical then t:SetWidth(2) else t:SetHeight(2) end
        t:SetColor(0.20,0.65,0.90,0.95); t:SetMouseEnabled(false)
        t:SetDrawLayer(DL_BACKGROUND); t:SetDrawLevel(3)
    end
    edge(TOPLEFT,TOPLEFT,TOPRIGHT,TOPRIGHT,false)
    edge(BOTTOMLEFT,BOTTOMLEFT,BOTTOMRIGHT,BOTTOMRIGHT,false)
    edge(TOPLEFT,TOPLEFT,BOTTOMLEFT,BOTTOMLEFT,true)
    edge(TOPRIGHT,TOPRIGHT,BOTTOMRIGHT,BOTTOMRIGHT,true)
end

local function panel(name,key,width,height)
 local w=WINDOW_MANAGER:CreateTopLevelWindow(N..name); w:SetDimensions(width,height); w:SetMouseEnabled(true); w:SetMovable(false); w:SetClampedToScreen(true); w:SetDrawTier(DT_HIGH); w:SetHidden(true)
 place(w,key)
 local bg=WINDOW_MANAGER:CreateControl(nil,w,CT_BACKDROP); bg:SetAnchorFill(w); bg:SetCenterColor(.015,.028,.048,C.sv.opacity or .82); backgrounds[#backgrounds+1]=bg; bg:SetEdgeColor(0.20,0.65,0.90,0.95); TMEBlueFrame(w)
 return w
end
local function label(w,x,y,width,height,size)
 local l=WINDOW_MANAGER:CreateControl(nil,w,CT_LABEL); l:SetAnchor(TOPLEFT,w,TOPLEFT,x,y); l:SetDimensions(width,height); l:SetFont('$(MEDIUM_FONT)|'..size..'|soft-shadow-thin'); l:SetColor(.92,.92,.92,1); return l
end
local function button(w,text,x,y,fn)
 local b=WINDOW_MANAGER:CreateControl(nil,w,CT_BUTTON); b:SetAnchor(TOPLEFT,w,TOPLEFT,x,y); b:SetDimensions(150,30); b:SetFont('$(BOLD_FONT)|18|soft-shadow-thin'); b:SetNormalFontColor(.91,.77,.45,1); b:SetText(text); b:SetHandler('OnClicked',fn); return b
end
local function render()
 if not C.hud then return end
 local m=C.mission; local t=C.travel
 local compact=C.sv.compact
 C.hud:SetDimensions(420,compact and not C.preview and 124 or 220); place(C.hud,'hud')
 C.body:SetText(C.preview and '|cE4C478DEFEND: Castle Alessia|r\nPriority: HIGH\nEmperor ring objective (preview)\nTransit: Example friendly keep\nObjectives tracked: Preview' or m and ('|cE4C478'..(m.owner==call('GetUnitAlliance','player') and 'DEFEND ' or 'ATTACK ')..m.name..'|r\nPriority: '..(C.score>=85 and 'CRITICAL' or C.score>=65 and 'HIGH' or 'STANDARD')..'\n'..C.reason..'\nTravel: '..(t and (t.name..(t.accessible==true and '' or ' (unverified)')) or 'No eligible shrine found')..'\nActive conflicts: '..(C.contested or 0)..' / '..C.count) or ('Awaiting battlefield intelligence\nObjectives tracked: '..(C.count or 0)))
 if compact and not C.preview then C.body:SetText(m and ('|cFFFFFF'..(m.owner==call('GetUnitAlliance','player') and 'DEFEND ' or 'ATTACK ')..m.name..'|r\n'..C.reason..'\nTransit: '..(t and t.name or 'No eligible shrine found')) or 'Awaiting battlefield intelligence') end
 if C.nextCapture and not C.preview then C.body:SetText(C.body:GetText().."\n|c99D5A7NEXT CAPTURE: "..C.nextCapture.name.."|r"); C.hud:SetDimensions(420,compact and 165 or 245); place(C.hud,"hud") end
 C.hud:SetHidden(not C.preview and ((C.sv.autoVisibility and not C.active) or not C.sv.show or not hudVisible()))
end
local function waypoint(k)
 if not k or not k.x then log('No valid map coordinates'); return end
 if call('IsInAvAZone')~=true then return end
 call('SetMapToPlayerLocation'); if MAP_PIN_TYPE_PLAYER_WAYPOINT and MAP_TYPE_LOCATION_CENTERED then call('PingMap',MAP_PIN_TYPE_PLAYER_WAYPOINT,MAP_TYPE_LOCATION_CENTERED,k.x,k.y) end
end
local function mapUpdate()
 if not C.mapLabel then return end
 local visible=C.sv.mapBriefing and C.active and C.mission and ((WORLD_MAP_SCENE and WORLD_MAP_SCENE:IsShowing()) or (GAMEPAD_WORLD_MAP_SCENE and GAMEPAD_WORLD_MAP_SCENE:IsShowing()))
 C.mapLabel:SetHidden(not visible)
 if visible then C.mapText:SetText('|cE4C478TRANSIT: '..(C.travel and (C.travel.name..(C.travel.accessible==true and '' or ' (unverified)')) or 'No eligible shrine found')..'|r\n|cFF6666BATTLE: '..C.mission.name..'|r') end
end
local function installPins()
 if not ZO_WorldMap_AddCustomPin or not ZO_MapPin or not ZO_WorldMap_RefreshCustomPins then C.errors.mapPins='Custom map API unavailable'; return end
 local function register(name,field,color)
  ZO_WorldMap_AddCustomPin(name,function(manager)
   local k=C[field]; local zone=call('GetMapZoneIndex'); if zone and C.active and k and xy(k.x,k.y) and call('GetMapType')==MAPTYPE_ZONE and zone==call('GetUnitZoneIndex','player') then
    manager:CreatePin(_G[name],k.name,k.x,k.y)
   end
  end,nil,{level=100,size=48,texture='EsoUI/Art/MapPins/MapPin_waypoint.dds',tint=color})
  if ZO_WorldMap_SetCustomPinEnabled then ZO_WorldMap_SetCustomPinEnabled(name,true) end
 end
 local ok,e=pcall(function() register(N..'TransitPin','travel',ZO_ColorDef:New(1,.78,.18,1)); register(N..'BattlePin','mission',ZO_ColorDef:New(1,.2,.2,1)) end)
 C.pins=ok; if not ok then C.errors.mapPins=tostring(e) end
end
local function refresh()
 C.active=call('IsInAvAZone')==true and call('IsInImperialCity')~=true
 if C.active then scan() else C.mission=nil; C.travel=nil end
 render(); mapUpdate()
 if C.pins then call('ZO_WorldMap_RefreshCustomPins',N..'TransitPin'); call('ZO_WorldMap_RefreshCustomPins',N..'BattlePin') end
end
local function fresh()
 return {seconds=0,damage=0,healing=0,siege=0,captures=0,defenses=0,objective=0,battles=0,active=0,missions=0,kills=0,deaths=0}
end
local function points(r)
 local objective=math.min(70,r.objective*7)
 local combat=math.min(50,math.max(r.damage/200000,r.healing/160000)*5+r.kills*.4)
 local siege=math.min(30,r.siege/100000*3)
 local participation=math.min(30,r.battles*3)
 local efficiency=math.min(20,r.active/3600*10)
 return objective+combat+siege+participation+efficiency+r.missions*2
end
local function summary(r)
 local p=points(r); local rate=r.seconds>0 and p*3600/r.seconds or 0
 return string.format('Mercenary Score: %.1f | %.1f/hr\nCaptures: %d | Defenses: %d | Battles: %d\nDamage: %d | Healing: %d\nSiege damage: %d | Kills: %d | Deaths: %d | Missions: %d\nObjectives/hr: %.1f | Session: %d min',p,rate,r.captures,r.defenses,r.battles,r.damage,r.healing,r.siege,r.kills,r.deaths or 0,r.missions,(r.captures+r.defenses)*3600/math.max(1,r.seconds),math.floor(r.seconds/60))
end
local function nearestBattle()
 local x,y=call('GetMapPlayerPosition','player'); if not xy(x,y) or call('GetMapZoneIndex')~=call('GetUnitZoneIndex','player') then return nil end
 local best,bd=nil,.035
 for _,k in ipairs(C.nodes) do if k.x then local d=dist(k,{x=x,y=y}); if d<bd then best,bd=k,d end end end
 return best
end
local function equal(v,n) return _G[n]~=nil and v==_G[n] end
local function combat(_,result,isError,abilityName,abilityGraphic,abilityActionSlotType,sourceName,sourceType,targetName,targetType,hitValue,powerType,damageType,log,sourceUnitId,targetUnitId,abilityId)
 if not C.active or not C.run or isError or not equal(sourceType,'COMBAT_UNIT_TYPE_PLAYER') then return end
 C.events=(C.events or 0)+1; hitValue=tonumber(hitValue) or 0
 local r=C.run; local now=GetFrameTimeMilliseconds(); local k=nearestBattle()
 local healing=equal(result,'ACTION_RESULT_HEAL') or equal(result,'ACTION_RESULT_CRITICAL_HEAL') or equal(result,'ACTION_RESULT_HOT_TICK') or equal(result,'ACTION_RESULT_HOT_TICK_CRITICAL')
 local siege=equal(result,'ACTION_RESULT_SIEGE_DAMAGE')
 local damage=equal(result,'ACTION_RESULT_DAMAGE') or equal(result,'ACTION_RESULT_CRITICAL_DAMAGE') or equal(result,'ACTION_RESULT_DOT_TICK') or equal(result,'ACTION_RESULT_DOT_TICK_CRITICAL')
 if healing then r.healing=r.healing+math.max(0,hitValue) elseif siege then r.siege=r.siege+math.max(0,hitValue) elseif damage then r.damage=r.damage+math.max(0,hitValue) elseif equal(result,'ACTION_RESULT_KILLING_BLOW') then r.kills=r.kills+1 else return end
 if damage or siege or equal(result,'ACTION_RESULT_KILLING_BLOW') then
  if k then C.skirmishes=C.skirmishes or {}; C.skirmishes[k.id]=now; C.dirty=true end
 end
 C.lastAction=now; if not k then return end; local e=C.engaged[k.id]; if not e then e={owner=k.owner,first=now,wasAttack=k.attack}; C.engaged[k.id]=e end
 e.wasAttack=e.wasAttack or k.attack; e.last=now; e.hits=(e.hits or 0)+1; if e.hits==3 then r.battles=r.battles+1 end
end
local function tickScore()
 local now=GetFrameTimeMilliseconds(); local elapsed=math.min(5,math.max(0,(now-(C.scoreTick or now))/1000)); C.scoreTick=now
 if C.active then
  if not C.run then C.run=fresh(); C.engaged={}; C.skirmishes={}; C.nextCapture=nil; C.lastAction=nil end
  local r=C.run; r.seconds=r.seconds+elapsed
  if C.lastAction and now-C.lastAction<15000 then r.active=r.active+elapsed end
  local faction=call('GetUnitAlliance','player')
  for _,k in ipairs(C.nodes) do local e=C.engaged[k.id]; if e then
   local captured=e.owner~=faction and k.owner==faction
   local defended=e.owner==faction and k.owner==faction and e.wasAttack and not k.attack
   if (captured or defended) and now-e.last<180000 then
    if captured then
     r.captures=r.captures+1
     local best,bestValue
     if not contains(lower(k.name),{'farm','mine','lumbermill'}) then
      for _,v in ipairs(C.nodes) do
       if v.owner~=faction and v.transit and v.x and k.x then
        local name=lower(v.name); local value=(contains(name,home[faction]) and 100 or contains(name,ring) and 85 or 45)-dist(k,v)*100
        if not bestValue or value>bestValue then best,bestValue=v,value end
       end
      end
      C.nextCapture=best; C.nextCaptureUntil=now+180000
     end
    else r.defenses=r.defenses+1 end
    local name=lower(k.name); r.objective=r.objective+(contains(name,home[faction]) and 1.5 or contains(name,ring) and 1.25 or contains(name,{'farm','mine','lumbermill'}) and .4 or 1)
    if C.previousMission==k.id then r.missions=r.missions+1 end
    C.engaged[k.id]=nil
   elseif now-e.last>=180000 then C.engaged[k.id]=nil end
  end end
  if C.nextCapture then
   if now>(C.nextCaptureUntil or 0) then C.nextCapture=nil else for _,k in ipairs(C.nodes) do if k.id==C.nextCapture.id and k.owner==faction then C.nextCapture=nil; break end end end
  end
  C.previousMission=C.mission and C.mission.id
 elseif C.run then
  local r=C.run; C.run=nil; if r.seconds>=1 then local career=C.sv.career; career.sessions=career.sessions+1; career.points=career.points+points(r); career.best=math.max(career.best,points(r)); career.last=r; table.insert(career.history,1,r); if #career.history>30 then table.remove(career.history) end; C.tmeManualReport=false; C.reportBody:SetText(summary(r)); C.report:SetHidden(false) end
 end
 if C.scoreBody then C.scoreHUD:SetDimensions(470,C.sv.compact and 130 or 200); place(C.scoreHUD,'score'); C.scoreBody:SetText(C.scorePreview and summary({seconds=3600,damage=400000,healing=600000,siege=200000,captures=3,defenses=2,objective=4,battles=5,active=2100,missions=2,kills=3}) or summary(C.run or fresh())); if C.sv.compact then local r=C.run or fresh(); if C.scorePreview then r=fresh(); r.seconds=3600; r.damage=400000; r.healing=600000; r.captures=3 end; C.scoreBody:SetText(string.format('|cFFFFFF%.1f FP|r  |c99D5A7%.1f FP/h|r\nCAP %d  DEF %d  K/D %d/%d\nDMG %s  HEAL %s',points(r),points(r)*3600/math.max(r.seconds,1),r.captures,r.defenses,r.kills,r.deaths or 0,tostring(r.damage),tostring(r.healing))) end; C.scoreHUD:SetHidden(not C.scorePreview and ((C.sv.autoVisibility and not C.active) or not C.sv.showScore or not hudVisible())) end
end

local function setup()
 C.sv=ZO_SavedVars:NewAccountWide('CyrodiilCommandSaved',1,nil,{show=true,showScore=true,compact=true,autoVisibility=true,opacity=.82,score={h=95,v=20,scale=1},report={h=50,v=50,scale=1},career={sessions=0,points=0,best=0,history={}},mapBriefing=true,debug=false,hud={h=5,v=20,scale=1},menu={h=50,v=50,scale=1}})
 C.hud=panel('HUD','hud',420,220); label(C.hud,12,8,330,30,22):SetText('|cE4C478CYRODIIL MERCENARY|r'); C.body=label(C.hud,12,45,395,195,19)
 local missionClose=button(C.hud,'Close HUD',265,0,function() C.sv.show=false; C.preview=false; render() end)
 local transitButton=button(C.hud,'Mark transit',10,183,function() waypoint(C.travel) end); local objectiveButton=button(C.hud,'Mark objective',180,183,function() waypoint(C.mission) end)
 C.mapLabel=WINDOW_MANAGER:CreateTopLevelWindow(N..'MapBriefing'); C.mapLabel:SetDimensions(550,65); C.mapLabel:SetAnchor(TOP,GuiRoot,TOP,0,85); C.mapLabel:SetDrawTier(DT_HIGH); C.mapLabel:SetMouseEnabled(false); C.mapText=label(C.mapLabel,0,0,550,65,22); C.mapLabel:SetHidden(true)
 installPins()
 C.scoreHUD=panel('Score','score',470,200); label(C.scoreHUD,12,8,310,30,22):SetText('|cE4C478MERCENARY SCORE|r'); C.scoreBody=label(C.scoreHUD,12,45,450,145,18)
 local scoreClose=button(C.scoreHUD,'Close HUD',310,0,function() C.sv.showScore=false; C.scorePreview=false; C.scoreHUD:SetHidden(true) end)
 missionClose:SetHidden(true); transitButton:SetHidden(true); objectiveButton:SetHidden(true); scoreClose:SetHidden(true)
 C.report=panel('Report','report',490,270); C.report:SetDrawLayer(DL_OVERLAY); C.report:SetDrawLevel(1000); label(C.report,12,8,325,30,22):SetText('|cE4C478MERCENARY REPORT|r'); C.reportBody=label(C.report,12,45,460,190,19)
 button(C.report,'Close Report',325,0,function() C.tmeManualReport=false; C.report:SetHidden(true) end)
 if EVENT_COMBAT_EVENT then EVENT_MANAGER:RegisterForEvent(N..'Combat',EVENT_COMBAT_EVENT,combat) end
 if EVENT_PLAYER_DEAD then EVENT_MANAGER:RegisterForEvent(N..'Death',EVENT_PLAYER_DEAD,function() if C.active and C.run then C.run.deaths=(C.run.deaths or 0)+1 end end) end
 C.menu=panel('Settings','menu',440,320); label(C.menu,12,8,400,30,22):SetText('MERCENARY SETTINGS')
 local function close() C.menu:SetHidden(true); C.preview=false; C.scorePreview=false; render() end
 button(C.menu,'Close Menu',275,0,close)
 local function slider(title,key,field,y,min,max,step)
  local l=label(C.menu,12,y,410,25,17)
  local w=WINDOW_MANAGER:CreateControl(nil,C.menu,CT_SLIDER)
  w:SetAnchor(TOPLEFT,C.menu,TOPLEFT,15,y+25); w:SetDimensions(405,20)
  w:SetMinMax(min,max); w:SetValueStep(step)
  w:SetThumbTexture('EsoUI/Art/Miscellaneous/scrollbox_elevator.dds','EsoUI/Art/Miscellaneous/scrollbox_elevator.dds','EsoUI/Art/Miscellaneous/scrollbox_elevator.dds',20,20)
  w:SetValue(C.sv[key][field])
  l:SetText(title..': '..C.sv[key][field])
  w:SetHandler('OnValueChanged',function(_,v) C.sv[key][field]=v; l:SetText(title..': '..v); place(C.hud,key); render() end)
 end
 slider('Horizontal position (%)','hud','h',45,0,100,1)
 slider('Vertical position (%)','hud','v',100,0,100,1)
 slider('HUD scale','hud','scale',155,.5,2,.05)
 button(C.menu,'Preview HUD',10,215,function() C.preview=not C.preview; render() end)
 button(C.menu,'Show HUD',180,215,function() C.sv.show=true; render() end)
 button(C.menu,'Diagnostics',10,260,function() log('Tracked: '..(C.count or 0)); for n,e in pairs(C.errors) do log(n..': '..e) end end)
 SLASH_COMMANDS['/cc']=function() if C.menu:IsHidden() then C.menu:SetHidden(false) else close() end end
 local L=LibAddonMenu2 or (LibStub and LibStub('LibAddonMenu-2.0',true))
 if L then
  local ok,e=pcall(function()
   local id=N..'Panel'
   L:RegisterAddonPanel(id,{type='panel',name='Cyrodiil Mercenary',displayName='Cyrodiil Mercenary',author='Trash Man Enterprises',version='0.2.5',registerForRefresh=true})
   local opts={{type='checkbox',name='Show map briefing',getFunc=function() return C.sv.mapBriefing end,setFunc=function(v) C.sv.mapBriefing=v; mapUpdate() end},{type='checkbox',name='Show mission HUD',getFunc=function() return C.sv.show end,setFunc=function(v) C.sv.show=v; render() end},{type='checkbox',name='Live HUD preview',getFunc=function() return C.preview==true end,setFunc=function(v) C.preview=v; render() end}}
   local function option(key,field,title,min,max,step)
    opts[#opts+1]={type='slider',name=title,min=min,max=max,step=step,decimals=field=='scale' and 2 or 0,getFunc=function() return C.sv[key][field] end,setFunc=function(v) C.sv[key][field]=v; place(({hud=C.hud,menu=C.menu,score=C.scoreHUD,report=C.report})[key],key); render() end}
   end
   option('hud','h','HUD horizontal position (%)',0,100,1)
   option('hud','v','HUD vertical position (%)',0,100,1)
   option('hud','scale','HUD scale',.5,2,.05)
   option('menu','h','Fallback menu horizontal (%)',0,100,1)
   option('menu','v','Fallback menu vertical (%)',0,100,1)
   option('menu','scale','Fallback menu scale',.5,2,.05)
   opts[#opts+1]={type='checkbox',name='Show live score HUD',getFunc=function() return C.sv.showScore end,setFunc=function(v) C.sv.showScore=v end}
   opts[#opts+1]={type='checkbox',name='Preview score HUD',getFunc=function() return C.scorePreview==true end,setFunc=function(v) C.scorePreview=v end}
   for _,key in ipairs({'score','report'}) do option(key,'h',key..' horizontal (%)',0,100,1); option(key,'v',key..' vertical (%)',0,100,1); option(key,'scale',key..' scale',.5,2,.05) end
   opts[#opts+1]={type='button',name='Career Profile',func=function() C.tmeManualReport=true; local c=C.sv.career; C.reportBody:SetText(string.format('Sessions: %d | Career points: %.1f | Best: %.1f\n',c.sessions,c.points,c.best)..(c.last and summary(c.last) or 'No completed session')); C.report:SetDrawLayer(DL_OVERLAY); C.report:SetDrawLevel(1000); C.report:SetHidden(false) end}
   opts[#opts+1]={type='button',name='Preview report',func=function() C.tmeManualReport=true; C.reportBody:SetText(summary(C.run or fresh())); C.report:SetDrawLayer(DL_OVERLAY); C.report:SetDrawLevel(1000); C.report:SetHidden(false) end}
   opts[#opts+1]={type='button',name='Close report / career profile',func=function() C.tmeManualReport=false; C.report:SetHidden(true) end}
   opts[#opts+1]={type='button',name='Close mission HUD',func=function() C.sv.show=false; C.preview=false; render() end}
   opts[#opts+1]={type='button',name='Close live score HUD',func=function() C.sv.showScore=false; C.scorePreview=false; C.scoreHUD:SetHidden(true) end}
   opts[#opts+1]={type='button',name='Close map briefing',func=function() C.sv.mapBriefing=false; mapUpdate() end}
   opts[#opts+1]={type='button',name='Diagnostics',func=function() C.tmeManualReport=true; C.reportBody:SetText('Personal combat events: '..(C.events or 0)..'\nObjectives: '..(C.count or 0)..'\nTransit: '..(C.travel and C.travel.name or 'none')); C.report:SetDrawLayer(DL_OVERLAY); C.report:SetDrawTier(DT_HIGH); C.report:SetDrawLevel(1000); C.report:SetDrawLayer(DL_OVERLAY); C.report:SetDrawLevel(1000); C.report:SetHidden(false) end}
   opts[#opts+1]={type='button',name='Open fallback settings',func=function() C.menu:SetHidden(false) end}
   opts[#opts+1]={type='button',name='Mark mission objective',func=function() waypoint(C.mission) end}
   opts[#opts+1]={type='button',name='Mark transit destination',func=function() waypoint(C.travel) end}
   opts[#opts+1]={type='button',name='Close Menu',func=function() close(); if SCENE_MANAGER then SCENE_MANAGER:ShowBaseScene() end end}
   opts[#opts+1]={type='checkbox',name='Compact HUDs',getFunc=function() return C.sv.compact end,setFunc=function(v) C.sv.compact=v; render(); tickScore() end}
   opts[#opts+1]={type='checkbox',name='Automatic activity visibility',getFunc=function() return C.sv.autoVisibility end,setFunc=function(v) C.sv.autoVisibility=v; render(); tickScore() end}
   opts[#opts+1]={type='slider',name='Background opacity (%)',min=0,max=100,step=5,getFunc=function() return C.sv.opacity*100 end,setFunc=function(v) C.sv.opacity=v/100; for _,bg in ipairs(backgrounds) do bg:SetCenterColor(.015,.028,.048,C.sv.opacity) end end}
   L:RegisterOptionControls(id,opts)
   if CALLBACK_MANAGER then CALLBACK_MANAGER:RegisterCallback('LAM-PanelClosed',function() C.preview=false; C.scorePreview=false; render() end) end
  end)
  if not ok then C.errors.LAM=e end
 else C.errors.LAM='Optional LibAddonMenu unavailable; /cc fallback' end
 local function radial()
  if C.radialRegistered then return end
  local R=LibRadialMenu
  if not R then return end
  local ok,e=pcall(function()
   R:RegisterAddon(N,'Cyrodiil Mercenary')
   local function entry(name,id,fn,desc) R:RegisterEntry(N,name,id,'/esoui/art/icons/icon_dualwield.dds',fn,desc) end
   entry('Mark mission objective','mission',function() waypoint(C.mission) end,'Place a waypoint at the assigned battle.')
   entry('Mark transit destination','transit',function() waypoint(C.travel) end,'Place a waypoint at the recommended shrine, if available.')
   entry('Refresh mission','refresh',refresh,'Reassess contested objectives.')
   entry('Toggle mission HUD','togglemission',function() C.sv.show=not C.sv.show; C.preview=false; render() end,'Show or hide mission briefing.')
   entry('Toggle score HUD','togglescore',function() C.sv.showScore=not C.sv.showScore; C.scorePreview=false; tickScore() end,'Show or hide live score.')
   entry('Toggle session report','report',function() if C.report:IsHidden() then C.reportBody:SetText(summary(C.run or C.sv.career.last or fresh())); C.report:SetHidden(false) else C.tmeManualReport=false; C.report:SetHidden(true) end end,'Open or close session report.')
  end)
  C.radialRegistered=ok; if not ok then C.errors.radial=tostring(e) end
 end
 radial()
 EVENT_MANAGER:RegisterForEvent(N..'RadialInit',EVENT_PLAYER_ACTIVATED,radial)
 for _,n in ipairs({'EVENT_PLAYER_ACTIVATED','EVENT_KEEP_ALLIANCE_OWNER_CHANGED','EVENT_KEEP_UNDER_ATTACK_CHANGED','EVENT_KEEP_IS_PASSABLE_CHANGED','EVENT_KEEP_INITIALIZED'}) do if _G[n] then EVENT_MANAGER:RegisterForEvent(N..n,_G[n],function() C.dirty=true end) end end
 EVENT_MANAGER:RegisterForUpdate(N,1000,function() mapUpdate(); render(); local now=GetFrameTimeMilliseconds(); if C.dirty or not C.last or now-C.last>=15000 then C.dirty=false; C.last=now; local ok,e=pcall(refresh); if not ok then C.errors.refresh=e end end; local ok,e=pcall(tickScore); if not ok then C.errors.scoring=e end end)
 EVENT_MANAGER:RegisterForEvent(N.."Deactivate",EVENT_PLAYER_DEACTIVATED,function() if C.run then C.sv.interrupted=C.run end end)
 refresh()
end
EVENT_MANAGER:RegisterForEvent(N,EVENT_ADD_ON_LOADED,function(_,name) if name~=N then return end EVENT_MANAGER:UnregisterForEvent(N,EVENT_ADD_ON_LOADED); local ok,e=pcall(setup); if not ok then log(tostring(e)) end end)


-- TME Menu Visibility: independent of saved visibility and ongoing statistics.
-- Suppress presentation, not SetHidden state: existing timers/close actions remain authoritative.
local tmeMenuAlpha = setmetatable({}, {__mode="k"})
local function tmeMenuContext()
    if not SCENE_MANAGER then return false, false, false end
    local scene=SCENE_MANAGER.GetCurrentScene and SCENE_MANAGER:GetCurrentScene()
    local name=scene and scene.GetName and scene:GetName()
    local main=SCENE_MANAGER.IsShowing and SCENE_MANAGER:IsShowing("mainMenuGamepad")
    if main then return true,false,false end
    if not name then return false,false,false end
    local lower=string.lower(name)
    local gameplay=(lower=="hud" or lower=="hudui" or lower=="hudgamepad" or lower=="huduigamepad")
    local addon=lower:find("addon",1,true)~=nil or lower:find("libaddonmenu",1,true)~=nil or lower=="gamepadoptions" or lower=="gamepadoptionsroot"
    local map=lower:find("worldmap",1,true)~=nil or lower=="gamepadworldmap"
    return not gameplay,addon,map
end
local function tmeMenuSuppress(control, suppress)
    if not control then return end
    if suppress then
        if tmeMenuAlpha[control]==nil then tmeMenuAlpha[control]=control:GetAlpha() end
        if control:GetAlpha()~=0 then control:SetAlpha(0) end
    elseif tmeMenuAlpha[control]~=nil then
        control:SetAlpha(tmeMenuAlpha[control]);tmeMenuAlpha[control]=nil
    end
end

EVENT_MANAGER:RegisterForUpdate("CyrodiilMercenaryTME_MenuVisibility", 100, function()
    if not C.sv then return end
    local blocked,addon,map=tmeMenuContext()
    tmeMenuSuppress(C.hud,blocked and not C.preview)
    tmeMenuSuppress(C.scoreHUD,blocked and not C.scorePreview)
    tmeMenuSuppress(C.mapLabel,blocked and not map)
    tmeMenuSuppress(C.report,blocked and not (addon and C.tmeManualReport))
    tmeMenuSuppress(C.menu,blocked and not addon)
end)
