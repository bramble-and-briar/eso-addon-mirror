-- ZoneSweep 0.4.0: controller checklist release candidate.
local NAME="ZoneSweep"
local ui, snapshot, db
local traceEnabled=false
local trace={}
local function Trace(message)
 if not traceEnabled then return end
 trace[#trace+1]=message
 if #trace>60 then table.remove(trace,1)end
end
local function Context()
 local zoneIndex,poiIndex=GetCurrentSubZonePOIIndices()
 local name=zoneIndex and poiIndex and GetPOIInfo(zoneIndex,poiIndex) or "no subzone POI"
 return tostring(GetUnitZone("player")).." | "..tostring(name).." ("..tostring(zoneIndex)..":"..tostring(poiIndex)..")"
end
local sharedTypes={
 [ZONE_COMPLETION_TYPE_DELVES]=true,
 [ZONE_COMPLETION_TYPE_GROUP_BOSSES]=true,
 [ZONE_COMPLETION_TYPE_WORLD_EVENTS]=true,
 [ZONE_COMPLETION_TYPE_GROUP_DELVES]=true,
}
local function CharacterRecords(zone)
 local id=tostring(GetCurrentCharacterId())
 db.characters[id]=db.characters[id] or {zones={}}
 local zones=db.characters[id].zones
 zones[zone]=zones[zone] or {}
 return zones[zone]
end
local function ActivityKey(kind,id)return tostring(kind)..":"..tostring(id)end
local categories={
 {ZONE_COMPLETION_TYPE_PRIORITY_QUESTS,"Main story"},
 {ZONE_COMPLETION_TYPE_WAYSHRINES,"Wayshrines"},
 {ZONE_COMPLETION_TYPE_DELVES,"Delves"},
 {ZONE_COMPLETION_TYPE_GROUP_BOSSES,"World bosses"},
 {ZONE_COMPLETION_TYPE_PUBLIC_DUNGEONS,"Public dungeons"},
 {ZONE_COMPLETION_TYPE_SKYSHARDS,"Skyshards"},
 {ZONE_COMPLETION_TYPE_MAGES_GUILD_BOOKS,"Lorebooks"},
 {ZONE_COMPLETION_TYPE_POINTS_OF_INTEREST,"Quest sites"},
 {ZONE_COMPLETION_TYPE_STRIKING_LOCALES,"Striking locales"},
 {ZONE_COMPLETION_TYPE_WORLD_EVENTS,"World events"},
 {ZONE_COMPLETION_TYPE_GROUP_DELVES,"Group delves"},
 {ZONE_COMPLETION_TYPE_SET_STATIONS,"Set stations"},
 {ZONE_COMPLETION_TYPE_MUNDUS_STONES,"Mundus stones"},
}
local function Clean(s)return zo_strformat("<<1>>",s or "")end
local function ReadZone()
 local zone=GetZoneStoryZoneIdForZoneId(GetZoneId(GetUnitZoneIndex("player")))
 local data={zone=zone,name=zone and zone>0 and Clean(GetZoneNameById(zone)) or "No zone guide here",character=Clean(GetUnitName("player")),categories={}}
 if not zone or zone<=0 then return data end
 for _,definition in ipairs(categories)do
  local kind,name=definition[1],definition[2]
  local total=GetNumZoneActivitiesForZoneCompletionTypeAndIndex(zone,kind,nil)
  if total>0 then
   local reported=GetNumCompletedZoneActivitiesForZoneCompletionTypeAndIndex(zone,kind,nil)
   local shared=sharedTypes[kind]
   local records=CharacterRecords(zone)
   local entry={kind=kind,name=name,total=total,done=shared and 0 or reported,accountDone=shared and reported or nil,activities={}}
   if not DoesZoneStoryActivityCompletionTypeUseIndex(kind) then
    local count=GetNumUnblockedZoneStoryActivitiesForZoneCompletionTypeAndIndex(zone,kind,nil)
    for index=1,count do
     local activityId=GetZoneActivityIdForZoneCompletionType(zone,kind,index)
     local key=ActivityKey(kind,activityId)
     local record=shared and records[key]
     local done=shared and record~=nil or (not shared and IsZoneStoryActivityComplete(zone,kind,index,nil))
     entry.activities[#entry.activities+1]={id=activityId,key=key,name=Clean(GetZoneStoryActivityNameByActivityIndex(zone,kind,index,nil)),done=done,unknown=shared and not done,record=record}
     if shared and done then entry.done=entry.done+1 end
    end
    table.sort(entry.activities,function(a,b)if a.done~=b.done then return not a.done end;return a.name<b.name end)
   end
   data.categories[#data.categories+1]=entry
  end
 end
 return data
end
local function CreateWindow()
 if ui then return end
 local wm=WINDOW_MANAGER
 local window=wm:CreateTopLevelWindow("ZoneSweepWindow")
 window:SetDimensions(1120,820);window:SetAnchor(CENTER,GuiRoot,CENTER,0,0);window:SetHidden(true);window:SetMouseEnabled(true)
 local w,h=GuiRoot:GetDimensions();window:SetScale(math.min(1,w/1180,h/900))
 local bg=wm:CreateControl(nil,window,CT_BACKDROP);bg:SetAnchorFill();bg:SetCenterColor(.012,.012,.018,1);bg:SetEdgeColor(.38,.07,.065,1)
 local function Label(x,y,width,height,font)
  local label=wm:CreateControl(nil,window,CT_LABEL);label:SetAnchor(TOPLEFT,window,TOPLEFT,x,y);label:SetDimensions(width,height);label:SetFont(font);label:SetColor(.85,.85,.88,1);return label
 end
 local title=Label(35,20,1050,45,"ZoFontGamepad34")
 local summary=Label(35,75,1050,70,"ZoFontGamepad22")
 local heading=Label(35,157,1050,38,"ZoFontGamepad27");heading:SetColor(.85,.3,.28,1)
 local lines={}
 for i=1,16 do lines[i]=Label(35,207+(i-1)*28,1050,28,"ZoFontGamepad22");lines[i]:SetMaxLineCount(1)end
 local footer=Label(35,701,1050,45,"ZoFontGamepad22")
 local credit=Label(35,760,1050,30,"ZoFontGamepad22");credit:SetText("by @TheGreyWolf98  |  ZoneSweep 0.4.0");credit:SetColor(.57,.24,.23,1)
 ui={window=window,category=0,page=1,onlyMissing=true,selected=1}
 local keys
 local function Render()
  title:SetText("ZoneSweep  |  "..snapshot.name)
  summary:SetText(snapshot.character.."  |  Character checklist + separate account totals\nRecorded = saved for this toon. Unknown = no personal record; account ticks are not imported.")
  local rows={};ui.visibleActivities={}
  local entry=snapshot.categories[ui.category]
  if ui.help then
   heading:SetText("How to use ZoneSweep")
   rows={"Type /zs or /zonesweep to open the current-zone checklist.",
    "Overview: D-pad selects a category; A opens it. LB/RB cycles categories.",
    "X switches between all activities and activities still to do.",
    "LT/RT changes pages. Y reads the latest zone progress. B closes.",
    "Delves, world bosses and world events record progress for this character.",
    "On their lists: D-pad selects a site; A ticks or clears your personal record.",
    "Use manual ticks for earlier completions you know this character has done.",
    "Recorded = saved for this character. Unknown = no personal record yet.",
    "Account totals are shown separately and never copied into personal records.",
    "Complete activities while ZoneSweep is installed to build personal history.",
    "Quest sites come from the zone guide; they are not every side quest.",
    "Some categories provide totals only; named lists depend on ESO's data.",
    "Type /zs help to reopen these instructions.",
    "For troubleshooting: /zs debug, fight the boss, then /zs debug again."}
  elseif ui.debug then
   heading:SetText("Encounter log | /zs debug")
   rows[#rows+1]=Context()
   rows[#rows+1]="Capture enabled. Fight a boss or world event, then reopen /zs debug."
   for _,line in ipairs(trace)do rows[#rows+1]=line end
  elseif entry then
   heading:SetText(entry.name.."  "..entry.done.." / "..entry.total..(entry.accountDone and " recorded  |  Account "..entry.accountDone.." / "..entry.total or ""))
   for _,activity in ipairs(entry.activities)do
    if not ui.onlyMissing or not activity.done then
     local status=activity.unknown and "[Unknown]  " or activity.record and "[Recorded]  " or activity.done and "[Done]  " or "[To do]  "
     rows[#rows+1]=status..activity.name
     ui.visibleActivities[#rows]=activity
    end
   end
   if #rows==0 then rows[1]=#entry.activities==0 and "ESO provides a total only for this category; see the count above." or "No unfinished activities reported." end
  else
   heading:SetText("Current-zone checklist")
   for _,c in ipairs(snapshot.categories)do rows[#rows+1]=c.name.."    "..c.done.." / "..c.total..(c.accountDone and " recorded; history unknown  |  Account "..c.accountDone.." / "..c.total or "") end
   if #rows==0 then rows[1]="No zone-guide activities available in this location. Try an overland zone."end
  end
  ui.rowCount=#rows
  local selectable=not ui.help and not ui.debug and ((not entry and #snapshot.categories>0) or (entry and entry.accountDone and #ui.visibleActivities>0))
  local pages=math.max(1,math.ceil(#rows/16));ui.page=math.max(1,math.min(ui.page,pages));ui.pages=pages
  ui.selected=math.max(1,math.min(ui.selected,#rows))
  for i,label in ipairs(lines)do
   local index=(ui.page-1)*16+i
   label:SetText(rows[index] and ((selectable and index==ui.selected and "> " or "")..rows[index]) or "")
   label:SetColor(selectable and index==ui.selected and .95 or .85,selectable and index==ui.selected and .4 or .85,selectable and index==ui.selected and .35 or .88,1)
  end
  footer:SetText("Page "..ui.page.." / "..pages.."  |  LT/RT: pages  |  LB/RB: categories  |  /zs help: instructions\n"..(selectable and (entry and "D-pad: select  |  A: tick/clear  |  " or "D-pad: select  |  A: open category  |  ") or "")..(entry and "X: "..(ui.onlyMissing and "show all" or "unfinished only").."  |  " or "").."Y: refresh  |  B: close")
  if keys and KEYBIND_STRIP.UpdateKeybindButtonGroup and SCENE_MANAGER:IsShowing("zonesweep")then KEYBIND_STRIP:UpdateKeybindButtonGroup(keys)end
 end
 ui.refresh=function()snapshot=ReadZone();ui.category=math.min(ui.category,#snapshot.categories);Render()end
 local function Cycle(delta)ui.debug=false;ui.help=false;ui.category=(ui.category+delta)%(#snapshot.categories+1);ui.page=1;ui.selected=1;Render()end
 local function Move(delta)
  if ui.help or ui.debug then return end
  local entry=snapshot.categories[ui.category]
  if entry and not entry.accountDone then return end
  local count=entry and #ui.visibleActivities or #snapshot.categories
  ui.selected=math.max(1,math.min(ui.selected+delta,count))
  ui.page=math.max(1,math.ceil(ui.selected/16));Render()
 end
 local function Mark()
  if ui.debug or ui.help then return end
  if ui.category==0 then ui.category=ui.selected;ui.page=1;ui.selected=1;Render();return end
  local entry=snapshot.categories[ui.category]
  local activity=ui.visibleActivities[ui.selected]
  if not entry or not entry.accountDone or not activity then return end
  local records=CharacterRecords(snapshot.zone)
  if records[activity.key] then records[activity.key]=nil else records[activity.key]={source="manual",at=GetTimeStamp()}end
  ui.refresh()
 end
 local function CanSelect()
  if ui.help or ui.debug then return false end
  local entry=snapshot.categories[ui.category]
  return (ui.category==0 and #snapshot.categories>0) or (entry~=nil and entry.accountDone~=nil and #ui.visibleActivities>0)
 end
 keys={alignment=KEYBIND_STRIP_ALIGN_CENTER,
  {name="Previous category",keybind="UI_SHORTCUT_LEFT_SHOULDER",callback=function()Cycle(-1)end},
  {name="Next category",keybind="UI_SHORTCUT_RIGHT_SHOULDER",callback=function()Cycle(1)end},
  {name=function()return ui.onlyMissing and "Show all" or "Unfinished only"end,visible=function()return not ui.help and not ui.debug and ui.category>0 end,keybind="UI_SHORTCUT_SECONDARY",callback=function()if ui.debug or ui.help or ui.category==0 then return end;ui.onlyMissing=not ui.onlyMissing;ui.page=1;ui.selected=1;Render()end},
  {name="Refresh",keybind="UI_SHORTCUT_TERTIARY",callback=function()ui.page=1;ui.refresh()end},
  {name="Previous page",enabled=function()return ui.page>1 end,keybind="UI_SHORTCUT_LEFT_TRIGGER",callback=function()ui.page=ui.page-1;Render();ui.selected=(ui.page-1)*16+1;Render()end},
  {name="Next page",enabled=function()return ui.page<ui.pages end,keybind="UI_SHORTCUT_RIGHT_TRIGGER",callback=function()ui.page=ui.page+1;Render();ui.selected=(ui.page-1)*16+1;Render()end},
  {name="Close",keybind="UI_SHORTCUT_NEGATIVE",callback=function()SCENE_MANAGER:Hide("zonesweep")end},
  {name=function()return ui.category==0 and "Open category" or "Tick / Clear"end,visible=CanSelect,keybind="UI_SHORTCUT_PRIMARY",callback=Mark},
  {visible=CanSelect,keybind="UI_SHORTCUT_INPUT_UP",callback=function()Move(-1)end},
  {visible=CanSelect,keybind="UI_SHORTCUT_INPUT_DOWN",callback=function()Move(1)end},
 }
 local scene=ZO_Scene:New("zonesweep",SCENE_MANAGER)
 scene:AddFragmentGroup(IsInGamepadPreferredMode()and FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW or FRAGMENT_GROUP.MOUSE_DRIVEN_UI_WINDOW)
 scene:AddFragment(ZO_FadeSceneFragment:New(window))
 scene:RegisterCallback("StateChange",function(_,state)
  if state==SCENE_SHOWN then KEYBIND_STRIP:AddKeybindButtonGroup(keys)
  elseif state==SCENE_HIDING then KEYBIND_STRIP:RemoveKeybindButtonGroup(keys)end
 end)
end
local function ObjectiveCompleted(_,zoneIndex,poiIndex)
 Trace("OBJECTIVE "..tostring(zoneIndex)..":"..tostring(poiIndex).." | "..Context())
 local zone=GetZoneStoryZoneIdForZoneId(GetZoneId(zoneIndex))
 if not zone or zone<=0 then return end
 local kind=GetPOIZoneCompletionType(zoneIndex,poiIndex)
 if not sharedTypes[kind] then return end
 local count=GetNumUnblockedZoneStoryActivitiesForZoneCompletionTypeAndIndex(zone,kind,nil)
 for index=1,count do
  local id=GetZoneActivityIdForZoneCompletionType(zone,kind,index)
  local activityZone,activityPOI=GetPOIIndices(id)
  if activityZone==zoneIndex and activityPOI==poiIndex then
   CharacterRecords(zone)[ActivityKey(kind,id)]={source="objective",at=GetTimeStamp()}
   if ui and SCENE_MANAGER:IsShowing("zonesweep")then ui.refresh()end
   return
  end
 end
end
-- Confirmed completion bosses only. Difficulty alone also matches quest bosses.
-- Each entry lists every required boss; partial kills remain partial.
local delveBosses={
 ["the chill hollow"]={"nomeg chal"},
}
local function NormalName(name)return string.lower(Clean(name)):gsub("^%s+", ""):gsub("%s+$", "")end
local function RecordDelveKill(target)
 local location=NormalName(GetUnitZone("player"))
 local required=delveBosses[location]
 if not required then return end
 local boss=NormalName(target)
 local matches=false
 for _,name in ipairs(required)do if name==boss then matches=true;break end end
 if not matches then return end
 local zone=GetZoneStoryZoneIdForZoneId(GetZoneId(GetUnitZoneIndex("player")))
 if not zone or zone<=0 then return end
 local kind=ZONE_COMPLETION_TYPE_DELVES
 local count=GetNumUnblockedZoneStoryActivitiesForZoneCompletionTypeAndIndex(zone,kind,nil)
 for index=1,count do
  if NormalName(GetZoneStoryActivityNameByActivityIndex(zone,kind,index,nil))==location then
   local id=GetZoneActivityIdForZoneCompletionType(zone,kind,index)
   local records=CharacterRecords(zone)
   local partialKey="bosses:"..ActivityKey(kind,id)
   records[partialKey]=records[partialKey] or {}
   records[partialKey][boss]=true
   for _,name in ipairs(required)do if not records[partialKey][name]then return end end
   records[ActivityKey(kind,id)]={source="boss",at=GetTimeStamp()}
   records[partialKey]=nil
   Trace("RECORDED "..location.." | "..boss)
   if ui and SCENE_MANAGER:IsShowing("zonesweep")then ui.refresh()end
   return
  end
 end
end
-- A world boss's name differs from its checklist site name.
local worldBossSites={ ["rageclaw"]="rageclaw's den" }
local function RecordWorldBossKill(target)
 local site=worldBossSites[NormalName(target)]
 if not site then return end
 local zone=GetZoneStoryZoneIdForZoneId(GetZoneId(GetUnitZoneIndex("player")))
 if not zone or zone<=0 then return end
 local kind=ZONE_COMPLETION_TYPE_GROUP_BOSSES
 local count=GetNumUnblockedZoneStoryActivitiesForZoneCompletionTypeAndIndex(zone,kind,nil)
 for index=1,count do
  if NormalName(GetZoneStoryActivityNameByActivityIndex(zone,kind,index,nil))==site then
   local id=GetZoneActivityIdForZoneCompletionType(zone,kind,index)
   CharacterRecords(zone)[ActivityKey(kind,id)]={source="boss",at=GetTimeStamp()}
   Trace("RECORDED "..site.." | "..NormalName(target))
   if ui and SCENE_MANAGER:IsShowing("zonesweep")then ui.refresh()end
   return
  end
 end
end
-- Broad encounter tracking: all boss-bar units must die at one unambiguous site.
-- Legacy delve identification and data inspired by silvereyes' MIT-licensed CZT.
local excluded={}
for _,name in ipairs(ZoneSweepExcludedMonsters or {})do excluded[NormalName(name)]=true end
local multi=ZoneSweepMultiBossDelves or {}
ZoneSweepExcludedMonsters=nil;ZoneSweepMultiBossDelves=nil
local targets,bossFight,activeEvents,damageNames={},{},{},{}
local function ZoneContext()
 local index=GetUnitZoneIndex("player")
 if not index then return end
 local id=GetZoneId(index)
 local zone=GetZoneStoryZoneIdForZoneId(id)
 if not zone or zone<=0 then return end
 return zone,id
end
local function Activities(zone,kind)
 local out={}
 for i=1,GetNumUnblockedZoneStoryActivitiesForZoneCompletionTypeAndIndex(zone,kind,nil)do
  local id=GetZoneActivityIdForZoneCompletionType(zone,kind,i)
  out[#out+1]={id=id,key=ActivityKey(kind,id),kind=kind,name=NormalName(GetZoneStoryActivityNameByActivityIndex(zone,kind,i,nil))}
 end
 return out
end
local function DelveSite(zone)
 local name=NormalName(GetUnitZone("player"))
 local match
 for _,kind in ipairs({ZONE_COMPLETION_TYPE_DELVES,ZONE_COMPLETION_TYPE_GROUP_DELVES})do
  for _,site in ipairs(Activities(zone,kind))do
   if site.name==name then if match then return end;match=site end
  end
 end
 return match
end
local function NearbySite(zone,kind)
 local match
 for _,site in ipairs(Activities(zone,kind))do
  local zi,pi=GetPOIIndices(site.id)
  if zi and pi and select(8,GetPOIMapInfo(zi,pi))then
   if match then return end -- Never guess between overlapping sites.
   site.zi=zi;site.pi=pi;match=site
  end
 end
 return match
end
local function SaveSite(zone,site,source)
 if not zone or not site then return end
 CharacterRecords(zone)[site.key]={source=source,at=GetTimeStamp()}
 Trace("RECORDED "..site.name.." | "..source)
 if ui and SCENE_MANAGER:IsShowing("zonesweep")then ui.refresh()end
end
local function TargetChanged()
 local name=NormalName(GetUnitName("reticleover"))
 if name=="" or GetUnitReaction("reticleover")~=UNIT_REACTION_HOSTILE then return end
 local difficulty=GetUnitDifficulty("reticleover")
 if difficulty<MONSTER_DIFFICULTY_NORMAL then return end
 local now=GetTimeStamp()
 for old,info in pairs(targets)do if now-info.at>300 then targets[old]=nil end end
 targets[name]={difficulty=difficulty,at=now}
 Trace("TARGET "..name.." difficulty "..difficulty.." | "..Context())
end
local function LegacyKill(name)
 local zone,id=ZoneContext();if not zone then return end
 local site=DelveSite(zone);if not site then return end
 local boss=NormalName(name)
 local required=multi[id]
 if required then
  local found=false
  for _,n in ipairs(required)do if NormalName(n)==boss then found=true;break end end
  if not found then return end
  local records=CharacterRecords(zone)
  local key="bosses:"..site.key
  records[key]=records[key] or {};records[key][boss]=true
  for _,n in ipairs(required)do if not records[key][NormalName(n)]then return end end
  records[key]=nil;SaveSite(zone,site,"boss-list");return
 end
 -- Newer zones use encounter tags; rank alone can include optional quest bosses.
 if zone>=980 or next(bossFight)then return end
 local seen=targets[boss]
 if not seen or GetTimeStamp()-seen.at>300 or excluded[boss]then return end
 SaveSite(zone,site,"legacy-boss")
end
local function BossesChanged(forceReset)
 local zone=ZoneContext();if not zone then bossFight={};return end
 local site=DelveSite(zone) or (not IsUnitInDungeon("player") and NearbySite(zone,ZONE_COMPLETION_TYPE_GROUP_BOSSES))
 if not site then bossFight={};return end
 local nextFight={}
 for i=1,MAX_BOSSES or 6 do
  local tag="boss"..i
  local name=NormalName(GetUnitName(tag))
  if name~="" and GetUnitType(tag)~=COMBAT_UNIT_TYPE_NONE then
   local old=not forceReset and bossFight[tag]
   nextFight[tag]={name=name,dead=IsUnitDead(tag),zone=zone,site=site,engaged=IsUnitInCombat("player"),tag=tag}
   if old and old.name==name and old.zone==zone and old.site.key==site.key then
    nextFight[tag].engaged=old.engaged or nextFight[tag].engaged
    nextFight[tag].dead=old.dead or nextFight[tag].dead
   end
  elseif not forceReset and bossFight[tag] and bossFight[tag].dead then nextFight[tag]=bossFight[tag] end
 end
 bossFight=nextFight
end
local function BossDeath(tag,dead)
 if not dead or not bossFight[tag]then return end
 local zone=ZoneContext();local killed=bossFight[tag]
 if zone~=killed.zone then bossFight={};return end
 local here=killed.site.kind==ZONE_COMPLETION_TYPE_GROUP_BOSSES and NearbySite(zone,ZONE_COMPLETION_TYPE_GROUP_BOSSES) or DelveSite(zone)
 if not here or here.key~=killed.site.key then bossFight={};return end
 killed.dead=true;killed.engaged=killed.engaged or IsUnitInCombat("player")
 local engaged=false
 for _,boss in pairs(bossFight)do
  if not boss.dead or boss.site.key~=killed.site.key then return end
  engaged=engaged or boss.engaged
 end
 if not engaged then return end
 SaveSite(zone,killed.site,"boss-encounter");bossFight={}
end
local function WatchEvent(id)
 local zi,pi=GetWorldEventPOIInfo(id)
 if not zi or not pi or zi==0 or pi==0 then activeEvents[id]=nil;return end
 local zone=GetZoneStoryZoneIdForZoneId(GetZoneId(zi))
 local old=activeEvents[id]
 activeEvents[id]={zone=zone,zi=zi,pi=pi,participated=old and old.zi==zi and old.pi==pi and old.participated or false}
end
local function EventKill()
 local zone=ZoneContext();if not zone then return end
 local nearby=NearbySite(zone,ZONE_COMPLETION_TYPE_WORLD_EVENTS)
 if not nearby then return end
 for _,event in pairs(activeEvents)do
  if event.zone==zone and event.zi==nearby.zi and event.pi==nearby.pi then event.participated=true end
 end
end
local function EndEvent(id)
 local event=activeEvents[id];activeEvents[id]=nil
 if not event or not event.participated then return end
 local zone=ZoneContext();if zone~=event.zone then return end
 local site=NearbySite(zone,ZONE_COMPLETION_TYPE_WORLD_EVENTS)
 if site and site.zi==event.zi and site.pi==event.pi then SaveSite(zone,site,"world-event")end
end
local function ResetTracking()
 targets={};bossFight={};activeEvents={};damageNames={}
end

local function Open(text)
 CreateWindow()
 ui.help=type(text)=="string" and string.lower(text):match("^%s*help%s*$")~=nil
 ui.selected=1
 ui.debug=type(text)=="string" and string.lower(text):match("^%s*debug%s*$")~=nil
 if ui.debug and not traceEnabled then traceEnabled=true;Trace("Started on "..Clean(GetUnitName("player")))end
 ui.category=0;ui.page=1;ui.refresh();SCENE_MANAGER:Show("zonesweep")end
EVENT_MANAGER:RegisterForEvent(NAME,EVENT_ADD_ON_LOADED,function(_,addon)
 if addon~=NAME then return end
 EVENT_MANAGER:UnregisterForEvent(NAME,EVENT_ADD_ON_LOADED)
 db=ZO_SavedVars:NewAccountWide("ZoneSweepSavedVariables",1,GetWorldName(),{characters={}})
 EVENT_MANAGER:RegisterForEvent(NAME,EVENT_OBJECTIVE_COMPLETED,ObjectiveCompleted)
 EVENT_MANAGER:RegisterForEvent(NAME,EVENT_QUEST_COMPLETE,function(_,quest)
  Trace("QUEST "..Clean(quest).." | "..Context())
 end)
 EVENT_MANAGER:RegisterForEvent(NAME,EVENT_RETICLE_TARGET_CHANGED,TargetChanged)
 EVENT_MANAGER:RegisterForEvent(NAME,EVENT_BOSSES_CHANGED,function(_,reset)BossesChanged(reset)end)
 EVENT_MANAGER:RegisterForEvent(NAME,EVENT_UNIT_DEATH_STATE_CHANGED,function(_,tag,dead)BossDeath(tag,dead)end)
 EVENT_MANAGER:RegisterForEvent(NAME,EVENT_PLAYER_COMBAT_STATE,function(_,inCombat)
  if inCombat then for _,boss in pairs(bossFight)do boss.engaged=true end end
 end)
 EVENT_MANAGER:RegisterForEvent(NAME,EVENT_WORLD_EVENT_ACTIVATED,function(_,id)WatchEvent(id)end)
 EVENT_MANAGER:RegisterForEvent(NAME,EVENT_WORLD_EVENT_ACTIVE_LOCATION_CHANGED,function(_,id)WatchEvent(id)end)
 EVENT_MANAGER:RegisterForEvent(NAME,EVENT_WORLD_EVENT_DEACTIVATED,function(_,id)EndEvent(id)end)
 EVENT_MANAGER:RegisterForEvent(NAME,EVENT_PLAYER_ACTIVATED,function()
  ResetTracking()
  local id=GetNextWorldEventInstanceId()
  while id do WatchEvent(id);id=GetNextWorldEventInstanceId(id)end
  BossesChanged(true)
 end)
 local function Damage(_,result,isError,ability,graphic,slot,source,sourceType,target,targetType,hit,power,damage,log,sourceId,targetId)
  if isError or not target or target=="" then return end
  local name=NormalName(target)
  local now=GetTimeStamp()
  if targetId and targetId~=0 then
   local count=0
   for id,info in pairs(damageNames)do if now-info.at>45 then damageNames[id]=nil else count=count+1 end end
   if count<256 or damageNames[targetId]then damageNames[targetId]={name=target,at=now}end
  end
  for _,boss in pairs(bossFight)do if boss.name==name then boss.engaged=true end end
 end
 for _,result in ipairs({ACTION_RESULT_DAMAGE,ACTION_RESULT_CRITICAL_DAMAGE,ACTION_RESULT_DOT_TICK,ACTION_RESULT_DOT_TICK_CRITICAL})do
  local key=NAME.."Damage"..result
  EVENT_MANAGER:RegisterForEvent(key,EVENT_COMBAT_EVENT,Damage)
  EVENT_MANAGER:AddFilterForEvent(key,EVENT_COMBAT_EVENT,REGISTER_FILTER_COMBAT_RESULT,result)
  EVENT_MANAGER:AddFilterForEvent(key,EVENT_COMBAT_EVENT,REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,COMBAT_UNIT_TYPE_PLAYER)
 end
 local function Kill(_,result,isError,ability,graphic,slot,source,sourceType,target,targetType,hit,power,damage,log,sourceId,targetId)
  if (not target or target=="" )and targetId and damageNames[targetId]then
   local cached=damageNames[targetId]
   if GetTimeStamp()-cached.at<=45 then target=cached.name end
  end
  Trace("KILL "..tostring(result).." "..Clean(target).." | "..Context())
  if not isError then RecordDelveKill(target);RecordWorldBossKill(target);LegacyKill(target);if result==ACTION_RESULT_DIED_XP or result==ACTION_RESULT_KILLING_BLOW then EventKill()end end
 end
 for _,result in ipairs({ACTION_RESULT_KILLING_BLOW,ACTION_RESULT_DIED_XP,ACTION_RESULT_DIED})do
  local key=NAME.."Trace"..result
  EVENT_MANAGER:RegisterForEvent(key,EVENT_COMBAT_EVENT,Kill)
  EVENT_MANAGER:AddFilterForEvent(key,EVENT_COMBAT_EVENT,REGISTER_FILTER_COMBAT_RESULT,result)
 end
 SLASH_COMMANDS["/zs"]=Open;SLASH_COMMANDS["/zonesweep"]=Open
 EVENT_MANAGER:RegisterForEvent(NAME,EVENT_PLAYER_DEACTIVATED,function()ResetTracking();if SCENE_MANAGER:IsShowing("zonesweep")then SCENE_MANAGER:Hide("zonesweep")end end)
end)
