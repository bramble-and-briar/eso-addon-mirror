-- MasterBaiter's collection HUD and main-map pins. Progress comes from ESO achievements.
MasterBaiterCollection={}
local M=MasterBaiterCollection
local D=MasterBaiterData
local db,window,fragment,title,columns,special,pins
local current,arrivalUntil,lastZone,lastTick,manualHidden=nil,0,nil,0,false
local pinIds={}
local active=false
local waterKeys={'ocean','lake','river','foul'}
local waterNames={ocean='Ocean / Saltwater',lake='Lake',river='River',foul='Foul',other='Special catches'}
local nodeWater={[1]='foul',[2]='river',[3]='ocean',[4]='lake'}
local textures={ocean='/esoui/art/icons/crafting_fishing_merringar.dds',lake='/esoui/art/icons/crafting_fishing_perch.dds',river='/esoui/art/icons/crafting_fishing_river_betty.dds',foul='/esoui/art/icons/crafting_slaughterfish.dds'}
local function Clean(s)return zo_strformat('<<1>>',s or '')end
local function Now()return GetFrameTimeMilliseconds()end
local function ResolveZone(zone)
 local seen={}
 for _=1,8 do
  if D.zones[zone] then return zone end
  if not zone or zone==0 or seen[zone] then break end
  seen[zone]=true
  local parent=GetZoneStoryZoneIdForZoneId or GetParentZoneId
  if not parent then break end
  zone=parent(zone)
 end
 return nil
end
local function DescriptionWater(description)
 local n=description:lower()
 local suffix=n:match('%(([^()]*)%)%s*$') or ''
 if suffix:find('salt',1,true) or suffix:find('ocean',1,true) or suffix:find('mystic',1,true) then return 'ocean' end
 if suffix:find('lake',1,true) then return 'lake' end
 if suffix:find('river',1,true) or suffix:find('running',1,true) then return 'river' end
 if suffix:find('foul',1,true) or suffix:find('oily',1,true) then return 'foul' end
end
local function Read(ids,zone)
 local data={zone=zone,name=zone and Clean(GetZoneNameById(zone)) or '',caught=0,total=0,fish={},missing={ocean=0,lake=0,river=0,foul=0,other=0},counts={ocean=0,lake=0,river=0,foul=0,other=0}}
 for _,id in ipairs(ids or {})do
  local count=GetAchievementNumCriteria(id) or 0
  for index=1,count do
   local desc,done,required=GetAchievementCriterion(id,index)
   local order=D.water[id]
   local water=waterKeys[order and order[index] or 0]
   if not water and id~=1339 then water=DescriptionWater(Clean(desc))end
   water=water or 'other'
   local name=Clean(desc)
   local item=D.items[id] and D.items[id][index]
   local quality
   if item then
    local link=string.format('|H1:item:%d:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h',item)
    local itemName=Clean(GetItemLinkName(link))
    if itemName~='' then name=itemName end
    if GetItemLinkDisplayQuality then quality=GetItemLinkDisplayQuality(link) end
   end
   local caught=(required or 1)>0 and (done or 0)>=(required or 1)
   data.fish[#data.fish+1]={name=name,water=water,caught=caught,quality=quality,achievement=id,index=index}
   data.total=data.total+1;data.counts[water]=data.counts[water]+1
   if caught then data.caught=data.caught+1 else data.missing[water]=data.missing[water]+1 end
  end
 end
 return data
end
local function Refresh()
 local zone=ResolveZone(GetZoneId(GetUnitZoneIndex('player')))
 current=zone and Read(D.zones[zone],zone) or nil
end
local function FishText(fish)
 local colour=fish.caught and '849184' or fish.quality==3 and '78a9ff' or fish.quality==4 and 'ca8cff' or '91e8a1'
 return '|c'..colour..(fish.caught and '[Caught] ' or '')..fish.name..'|r'
end
local function BuildHUD()
 if window then return end
 window=WINDOW_MANAGER:CreateTopLevelWindow('MasterBaiterCollectionHUD')
 window:SetDimensions(1080,340);window:SetAnchor(TOP,GuiRoot,TOP,0,115);window:SetHidden(true);window:SetMouseEnabled(false)
 local sw=GuiRoot:GetDimensions();window:SetScale(math.min(1,sw/1140))
 window:SetDrawTier(DT_HIGH);window:SetDrawLayer(DL_OVERLAY)
 local bg=WINDOW_MANAGER:CreateControl(nil,window,CT_BACKDROP)
 bg:SetAnchorFill();bg:SetCenterColor(.012,.012,.018,.84);bg:SetEdgeColor(.65,.12,.1,.8)
 local function Label(x,y,width,height,font)
  local c=WINDOW_MANAGER:CreateControl(nil,window,CT_LABEL)
  c:SetAnchor(TOPLEFT,window,TOPLEFT,x,y);c:SetDimensions(width,height);c:SetFont(font);c:SetColor(.95,.95,.93,1);return c
 end
 title=Label(16,8,1048,35,'ZoFontGamepad27')
 columns={}
 for i,water in ipairs(waterKeys)do
  local head=Label(16+(i-1)*265,48,250,28,'ZoFontGamepad22');head:SetColor(.95,.4,.3,1)
  local rows={}
  for j=1,12 do rows[j]=Label(16+(i-1)*265,80+(j-1)*25,250,25,'ZoFontGamepad20');rows[j]:SetMaxLineCount(1)end
  columns[water]={head=head,rows=rows}
 end
 special=Label(16,0,1048,28,'ZoFontGamepad20')
 if ZO_HUDFadeSceneFragment and SCENE_MANAGER.GetScene then
  fragment=ZO_HUDFadeSceneFragment:New(window,250,500)
  fragment:SetConditional(function()return M.WantsHUD()end)
  for _,name in ipairs({'hud','hudui'})do
   local scene=SCENE_MANAGER:GetScene(name);if scene then scene:AddFragment(fragment)end
  end
 end
end
function M.WantsHUD()
 if not active or not db or manualHidden or db.fishHUD==1 or not current or current.total==0 then return false end
 if IsUnitInCombat('player') then return false end
 if db.fishHUD==3 then return true end
 if db.zoneReminder and current.caught<current.total and Now()<arrivalUntil then return true end
 local _,_,_,_,info=GetGameCameraInteractableActionInfo()
 return info==ADDITIONAL_INTERACT_INFO_FISHING_NODE or GetInteractionType()==INTERACTION_FISH
end
local function RenderHUD()
 BuildHUD()
 if current then
  title:SetText('MasterBaiter  |  '..current.name..'  |  Rare fish '..current.caught..' / '..current.total)
  local largest=1
  for _,water in ipairs(waterKeys)do
   local col=columns[water];local visible={}
   col.head:SetText(waterNames[water]..'  '..(current.counts[water]-current.missing[water])..' / '..current.counts[water])
   for _,fish in ipairs(current.fish)do
    if fish.water==water and (db.showCaught or not fish.caught)then visible[#visible+1]=FishText(fish)end
   end
   if #visible==0 then visible[1]=current.counts[water]>0 and '|c849184Complete|r' or '|c849184No rare fish|r' end
   largest=math.max(largest,math.min(12,#visible))
   for j,label in ipairs(col.rows)do label:SetText(visible[j] or '');label:SetHidden(not visible[j])end
  end
  local extras={}
  for _,fish in ipairs(current.fish)do if fish.water=='other' and (db.showCaught or not fish.caught)then extras[#extras+1]=FishText(fish)end end
  special:ClearAnchors();special:SetAnchor(TOPLEFT,window,TOPLEFT,16,84+largest*25)
  special:SetText(table.concat(extras,'  |  '));special:SetHidden(#extras==0)
  window:SetDimensions(1080,90+largest*25+(#extras>0 and 32 or 0))
 end
 if fragment then fragment:Refresh() else window:SetHidden(not M.WantsHUD())end
end
function M.Rows()
 Refresh()
 if not current or current.total==0 then return {'No fishing collection is registered for this zone.'}end
 local rows={current.name..'  |  Rare fish '..current.caught..' / '..current.total,'Progress: account achievements (shared between characters).'}
 for _,water in ipairs({'ocean','lake','river','foul','other'})do
  if current.counts[water]>0 then
   rows[#rows+1]='';rows[#rows+1]=waterNames[water]..'  |  '..current.missing[water]..' still needed'
   for _,fish in ipairs(current.fish)do if fish.water==water then rows[#rows+1]=FishText(fish)end end
  end
 end
 return rows
end
local function MapKey()
 local texture=GetMapTileTexture() or ''
 return (texture:match('[^/\\]+$') or ''):lower():gsub('%.dds$',''):gsub('_%d+$','')
end
local function MapCollection(key)
 local ach=D.mapAchievements[key]
 if ach then return Read({ach})end
 local zone=ResolveZone(GetZoneId(GetCurrentMapZoneIndex()))
 if zone then return Read(D.zones[zone],zone)end
end
-- One shared worker limits all four water types together, rather than four bursts.
local pinJobs={}
local pinWorker='MasterBaiterPinWorker'
local function CancelPinJobs()
 pinJobs={};EVENT_MANAGER:UnregisterForUpdate(pinWorker)
end
local function PumpPins()
 if not db.mapPins then CancelPinJobs();return end
 local key=MapKey()
 local made=0
 local started=(GetGameTimeMilliseconds or Now)()
 for _,water in ipairs(waterKeys)do
  local job=pinJobs[water]
  if job and job.key~=key then pinJobs[water]=nil;job=nil end
  while job and made<4 do
   local item=job.items[job.next]
   if not item then pinJobs[water]=nil;break end
   if Now()<job.readyAt then break end
   pins:CreatePin(pinIds[water],{water=water,map=item.map,index=item.index},item.node[1],item.node[2])
   job.next=job.next+1;made=made+1
   if (GetGameTimeMilliseconds or Now)()-started>=2 then return end
  end
  if made>=4 then return end
 end
 if not next(pinJobs) then EVENT_MANAGER:UnregisterForUpdate(pinWorker)end
end
local function CreatePins(water)
 -- RefreshCustomPins has already removed this type's old pins. Replace its job.
 pinJobs[water]=nil
 if not db.mapPins then return end
 local key=MapKey()
 local keys=key=='u48_overland_base' and {'u48_overland_base_west','u48_overland_base_east'} or {key}
 local items={}
 for _,map in ipairs(keys)do
  local data=MapCollection(map)
  if db.allSpots or not data or data.total==0 or data.missing[water]>0 or data.missing.other>0 then
   for index,node in ipairs(D.nodes[map] or {})do
    if nodeWater[node[3]]==water then items[#items+1]={map=map,index=index,node=node}end
   end
  end
 end
 if #items>0 then
  pinJobs[water]={key=key,items=items,next=1,readyAt=Now()+500}
  EVENT_MANAGER:RegisterForUpdate(pinWorker,32,PumpPins)
 end
end
local function SetupPins()
 if pins or not ZO_WorldMap_GetPinManager then return end
 pins=ZO_WorldMap_GetPinManager()
 if not pins then return end
 for _,water in ipairs(waterKeys)do
  local kind='MasterBaiterPin_'..water
  pins:AddCustomPin(kind,function()CreatePins(water)end,nil,{level=110,size=db.pinSize,texture=textures[water]},nil)
  pinIds[water]=_G[kind]
  pins:SetCustomPinEnabled(pinIds[water],db.mapPins)
 end
end
local hookedPanels={}
local function SetupMapFilters()
 if not GAMEPAD_WORLD_MAP_FILTERS or not ZO_PostHook or not ZO_GamepadEntryData then return end
 for _,name in ipairs({'pvePanel','pvpPanel','imperialPvPPanel'})do
  local panel=GAMEPAD_WORLD_MAP_FILTERS[name]
  if panel and panel.list and not hookedPanels[panel] then
   hookedPanels[panel]=true
   ZO_PostHook(panel,'PostBuildControls',function()
    local entry=ZO_GamepadEntryData:New('MasterBaiter fishing spots')
    entry:SetDataSource({showSelectButton=true,onSelect=function()
     db.mapPins=not db.mapPins;M.RefreshPins();panel:BuildControls()
    end,narrationText=function(data)
     if ZO_FormatToggleNarrationText then return ZO_FormatToggleNarrationText(data.text,data.currentValue)end
     return 'MasterBaiter fishing spots: '..(db.mapPins and 'On' or 'Off')
    end})
    entry.currentValue=db.mapPins
    panel.list:AddEntry('ZO_GamepadWorldMapFilterCheckboxOptionTemplate',entry)
    panel.list:Commit()
   end)
   panel:BuildControls()
  end
 end
end
function M.RefreshPins()
 CancelPinJobs()
 SetupPins()
 if pins then
  for _,water in ipairs(waterKeys)do
   local id=pinIds[water]
   if id then
    if ZO_MapPin and ZO_MapPin.PIN_DATA[id] then ZO_MapPin.PIN_DATA[id].size=db.pinSize end
    pins:SetCustomPinEnabled(id,db.mapPins);pins:RefreshCustomPins(id)
   end
  end
 end
end
function M.SettingsChanged()manualHidden=false;Refresh();RenderHUD();M.RefreshPins()end
function M.Activated()
 active=true;Refresh()
 local zone=current and current.zone
 if zone~=lastZone then lastZone=zone;arrivalUntil=Now()+10000 end
 M.RefreshPins();SetupMapFilters();RenderHUD()
end
function M.Tick()
 if not db then return end
 local now=Now()
 if now-lastTick<500 then return end
 lastTick=now;SetupMapFilters()
 local zone=ResolveZone(GetZoneId(GetUnitZoneIndex('player')))
 if zone~=lastZone then M.Activated() else RenderHUD()end
end
function M.Deactivate()
 CancelPinJobs()
 active=false
 if fragment then fragment:Refresh() elseif window then window:SetHidden(true)end
end
function M.Init(settings)
 db=settings
 db.fishHUD=math.max(1,math.min(3,tonumber(db.fishHUD)or 2))
 db.pinSize=16+4*math.floor((math.max(16,math.min(40,tonumber(db.pinSize)or 24))-16)/4)
 if db.zoneReminder==nil then db.zoneReminder=true end
 if db.showCaught==nil then db.showCaught=false end
 if db.mapPins==nil then db.mapPins=true end
 if db.allSpots==nil then db.allSpots=false end
 SLASH_COMMANDS['/mbhud']=function()manualHidden=not manualHidden;RenderHUD()end
 if EVENT_ACHIEVEMENT_UPDATED then
  EVENT_MANAGER:RegisterForEvent('MasterBaiterCollection',EVENT_ACHIEVEMENT_UPDATED,function()
   Refresh();RenderHUD();M.RefreshPins()
  end)
 end
end
