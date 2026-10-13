AtlasMiniMap = {}
local M=AtlasMiniMap
local PIN_SIZE,PLAYER_SIZE,WAYPOINT_SIZE=26,28,32
local HEADER_HEIGHT,MAP_TOP,WINDOW_EXTRA=42,46,104
local defaults={enabled=true,size=300,zoom=3,x=0.79,y=0.08,clock=true,hour24=true,fps=true,latency=true,atlas=true}
local function read(fn,...)
 if type(fn)~='function' then return nil end
 local ok,a,b,c,d=pcall(fn,...);if ok then return a,b,c,d end
end
local function clamp(x,a,b) return math.max(a,math.min(b,x)) end
local function control(parent,kind,x,y,w,h)
 local c=WINDOW_MANAGER:CreateControl(nil,parent,kind);c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);c:SetDimensions(w,h);return c
end
local function label(parent,x,y,w,h)
 local c=control(parent,CT_LABEL,x,y,w,h);c:SetFont('ZoFontGamepad18');c:SetColor(.93,.93,.93,1);c:SetMaxLineCount(1);return c
end
local function solid(parent,x,y,w,h,r,g,b)
 local c=control(parent,CT_TEXTURE,x,y,w,h);c:SetColor(r,g,b,1);return c
end
-- Crop each intersecting tile to the viewport, rather than reparenting the world map.
function M.Crop(tx,ty,tw,th,left,top,span)
 local x1,y1=math.max(tx,left),math.max(ty,top)
 local x2,y2=math.min(tx+tw,left+span),math.min(ty+th,top+span)
 if x2<=x1 or y2<=y1 then return nil end
 return (x1-left)/span,(y1-top)/span,(x2-x1)/span,(y2-y1)/span,
  (x1-tx)/tw,(x2-tx)/tw,(y1-ty)/th,(y2-ty)/th
end
function M.Clock(text,hour24)
 local h,m=text:match('^(%d+):(%d+)');h=tonumber(h);if not h then return text end
 if hour24 then return string.format('%02d:%s',h,m) end
 return string.format('%d:%s %s',(h+11)%12+1,m,h>=12 and 'PM' or 'AM')
end
function M:Layout()
 local s=self.saved;local size=s.size
 self.window:ClearAnchors();self.window:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,
 clamp(s.x*GuiRoot:GetWidth(),0,math.max(0,GuiRoot:GetWidth()-size-8)),
 clamp(s.y*GuiRoot:GetHeight(),0,math.max(0,GuiRoot:GetHeight()-size-WINDOW_EXTRA)))
 self.window:SetDimensions(size+8,size+WINDOW_EXTRA);self.bg:SetDimensions(size+8,size+WINDOW_EXTRA)
 self.map:SetDimensions(size,size);self.header:SetDimensions(size,HEADER_HEIGHT)
 self.map:ClearAnchors();self.map:SetAnchor(TOPLEFT,self.window,TOPLEFT,4,MAP_TOP)
 self.clock:ClearAnchors();self.clock:SetAnchor(TOP,self.window,TOP,0,4);self.clock:SetDimensions(size-18,42);self.clock:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
 self.latency:ClearAnchors();self.latency:SetAnchor(TOPRIGHT,self.window,TOPRIGHT,-9,size+MAP_TOP+28)
 self.fps:ClearAnchors();self.fps:SetAnchor(TOPLEFT,self.window,TOPLEFT,9,size+MAP_TOP+28)
 self.zone:SetDimensions(size-30,24);self.zone:ClearAnchors();self.zone:SetAnchor(TOPLEFT,self.window,TOPLEFT,9,size+MAP_TOP+4)
 self.north:ClearAnchors();self.north:SetAnchor(TOPRIGHT,self.map,TOPRIGHT,-4,3)
end
function M:Initialize()
 local w=WINDOW_MANAGER:CreateTopLevelWindow('TGWAtlasMiniMap');self.window=w
 self.bg=solid(w,0,0,308,360,.055,.035,.035)
 self.header=solid(w,4,4,300,26,.10,.045,.045)
 self.map=control(w,CT_CONTROL,4,30,300,300)
 self.mapBG=solid(self.map,0,0,300,300,.018,.018,.025);self.mapBG:SetAnchorFill(self.map)
 self.clock=label(w,9,4,282,44);self.clock:SetFont('ZoFontGamepad36');self.fps=label(w,9,4,70,26);self.latency=label(w,230,4,70,26)
 self.latency:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
 self.zone=label(w,9,334,270,24);self.north=label(self.map,275,3,20,24);self.north:SetText('N');self.north:SetColor(1,.7,.4,1)
 self.tiles={};self.pins={};self.points={};self.digSites={};self.digPolygons={}
 self.waypoint=control(self.map,CT_TEXTURE,0,0,WAYPOINT_SIZE,WAYPOINT_SIZE)
 self.waypoint:SetTexture('EsoUI/Art/MapPins/UI_Worldmap_pin_customDestination_white.dds')
 self.waypoint:SetColor(.3,.85,1,1);self.waypoint:SetDrawLevel(22);self.waypoint:SetHidden(true)
 self.player=control(self.map,CT_TEXTURE,0,0,PLAYER_SIZE,PLAYER_SIZE);self.player:SetTexture('EsoUI/Art/MapPins/UI-WorldMapPlayerPip.dds');self.player:SetDrawLevel(20)
 self.north:SetDrawLevel(25)
 self:Layout()
 EVENT_MANAGER:RegisterForUpdate('TGWAtlasMiniMap_Move',100,function() self:Tick() end)
 EVENT_MANAGER:RegisterForUpdate('TGWAtlasMiniMap_Header',1000,function() self:Header() end)
 CALLBACK_MANAGER:RegisterCallback('OnWorldMapChanged',function() self.dirty=true;self.digDirty=true end)
 EVENT_MANAGER:RegisterForEvent('TGWAtlasMiniMap_Zone',EVENT_PLAYER_ACTIVATED,function() self.active=true;self.dirty=true;self.digDirty=true end)
 EVENT_MANAGER:RegisterForEvent('TGWAtlasMiniMap_Off',EVENT_PLAYER_DEACTIVATED,function() self.active=false;self.window:SetHidden(true) end)
 local function digChanged() self.digDirty=true end
 for _,event in ipairs({EVENT_ANTIQUITY_DIG_SITES_UPDATED,EVENT_REVEAL_ANTIQUITY_DIG_SITES_ON_MAP,EVENT_ANTIQUITY_DIGGING_ANTIQUITY_UNEARTHED}) do
  if type(event)=='number' then EVENT_MANAGER:RegisterForEvent('TGWAtlasMiniMap_Dig'..event,event,digChanged) end
 end
 local function questsChanged() self.dirty=true end
 for _,event in pairs({EVENT_QUEST_ADDED,EVENT_QUEST_REMOVED,EVENT_QUEST_ADVANCED,EVENT_QUEST_CONDITION_COUNTER_CHANGED,EVENT_QUEST_POSITION_REQUEST_COMPLETE,EVENT_QUEST_LIST_UPDATED}) do
  if type(event)=='number' then EVENT_MANAGER:RegisterForEvent('TGWAtlasMiniMap_Quest'..event,event,questsChanged) end
 end
 self.active=true;self.dirty=true;self.digDirty=true;self:Header()
end
function M:Header()
 local s=self.saved;self.clock:SetText(s.clock and self.Clock(read(GetTimeString) or '',s.hour24) or '')
 local fps=s.fps and read(GetFramerate);local ping=s.latency and read(GetLatency)
 self.fps:SetText(type(fps)=='number' and fps>0 and string.format('%d FPS',math.floor(fps+.5)) or '')
 self.latency:SetText(type(ping)=='number' and ping>=0 and string.format('%d ms',math.floor(ping+.5)) or '')
end
function M:RefreshPoints()
 self.points={};local seen={}
 local function add(x,y,texture,color)
  if #self.points>=512 then return end
  if type(x)=='number' and type(y)=='number' and x>=0 and x<=1 and y>=0 and y<=1 and type(texture)=='string' and texture~='' then
   local key=texture..':'..math.floor(x*100000+.5)..':'..math.floor(y*100000+.5)
   if not seen[key] then
    seen[key]=true;self.points[#self.points+1]={x=x,y=y,texture=texture,color=color}
   end
  end
 end
 -- Services (including traders) are map locations, not zone POIs.
 -- Always include native sources, even when optional Atlas layers are enabled.
 for i=1,read(GetNumMapLocations) or 0 do
  if read(IsMapLocationVisible,i) then
   local icon,x,y=read(GetMapLocationIcon,i);add(x,y,icon)
  end
 end
 local breadcrumbs=WORLD_MAP_QUEST_BREADCRUMBS
 if breadcrumbs and ZO_MapPin then
  for quest=1,MAX_JOURNAL_QUESTS or 25 do
   if read(IsValidQuestIndex,quest) then
    local steps=read(breadcrumbs.GetSteps,breadcrumbs,quest)
    for _,conditions in pairs(steps or {}) do
     for _,p in pairs(conditions) do
      if p.insideCurrentMapWorld then
       -- Reuse ESO's quest/breadcrumb icon selection without creating or
       -- modifying native pins or requesting protected quest assistance.
       local proxy={m_PinTag={isBreadcrumb=p.isBreadcrumb},GetPinType=function() return p.pinType end}
       local icon=read(ZO_MapPin.GetQuestIcon,proxy)
       add(p.xLoc,p.yLoc,icon)
       if QUEST_PIN_STATE_HAS_ADDITIONAL_SYMBOLIC_POSITION and p.symbolicState==QUEST_PIN_STATE_HAS_ADDITIONAL_SYMBOLIC_POSITION then
        add(p.additionalSymbolicLocX,p.additionalSymbolicLocY,icon)
       end
      end
     end
    end
   end
  end
 end
 local zone=read(GetCurrentMapZoneIndex)
 if type(zone)=='number' and zone>0 then
  for i=1,read(GetNumPOIs,zone) or 0 do
   local ok,x,y,_,icon,onMap=pcall(GetPOIMapInfo,zone,i)
   if ok and onMap then add(x,y,icon) end
  end
 end
 local A=Atlas
 if self.saved.atlas and A and A.saved and A.options and A.Locations then
  for i=1,A.layerCount or 13 do local o=A.options[i]
   if o and A.saved[o.key] then
    local points=read(A.Locations,o.key)
    for _,p in ipairs(points or {}) do add(p.x,p.y,p.texture or o.texture,o.color) end
   end
  end
 end
 self.lastPoints=GetFrameTimeMilliseconds()
end
-- Clip dig-site polygons to the current minimap crop. No full-map controls
-- are moved, reparented or asked to reveal hidden excavation locations.
function M.ClipPolygon(points,left,top,span)
 local poly={}
 for _,p in ipairs(points) do poly[#poly+1]={x=(p.x-left)/span,y=(p.y-top)/span} end
 local function clip(input,axis,boundary,keepAbove)
  local output={};if #input==0 then return output end
  local previous=input[#input]
  local function inside(p) return keepAbove and p[axis]>=boundary or not keepAbove and p[axis]<=boundary end
  for _,current in ipairs(input) do
   local a,b=inside(previous),inside(current)
   if a~=b then
    local t=(boundary-previous[axis])/(current[axis]-previous[axis])
    output[#output+1]={x=previous.x+t*(current.x-previous.x),y=previous.y+t*(current.y-previous.y)}
   end
   if b then output[#output+1]=current end
   previous=current
  end
  return output
 end
 poly=clip(poly,'x',0,true);poly=clip(poly,'x',1,false)
 poly=clip(poly,'y',0,true);poly=clip(poly,'y',1,false)
 return poly
end
function M:RefreshDigSites()
 local sites,seen={},{}
 for i=1,math.min(read(GetNumInProgressAntiquities) or 0,32) do
  for j=1,math.min(read(GetNumDigSitesForInProgressAntiquity,i) or 0,32) do
   local id=read(GetInProgressAntiquityDigSiteId,i,j)
   if id and not seen[id] and #sites<32 then
    seen[id]=true
    local x,y,shown=read(GetDigSiteNormalizedCenterPosition,id)
    if shown and type(x)=='number' and type(y)=='number' then
     local ok,border=pcall(function() return {GetDigSiteNormalizedBorderPoints(id)} end)
     local points={}
     if ok then
      for n=1,math.min(#border,128),2 do
       if type(border[n])=='number' and type(border[n+1])=='number' then points[#points+1]={x=border[n],y=border[n+1]} end
      end
     end
     if #points>=3 then sites[#sites+1]={id=id,points=points,tracked=read(IsDigSiteAssociatedWithTrackedAntiquity,id)==true} end
    end
   end
  end
 end
 self.digSites=sites;self.lastDigSites=GetFrameTimeMilliseconds();self.digDirty=false
end
function M:DrawDigSites(left,top,span,size)
 local used=0
 for _,site in ipairs(self.digSites) do
  local points=self.ClipPolygon(site.points,left,top,span)
  if #points>=3 then
   used=used+1;local polygon=self.digPolygons[used]
   if not polygon then
    polygon=WINDOW_MANAGER:CreateControlFromVirtual('TGWAtlasMiniMapDigArea'..used,self.map,'ZO_PinPolygonBlob')
    polygon:SetMouseEnabled(false);polygon:SetDrawTier(DT_MEDIUM);polygon:SetDrawLayer(DL_CONTROLS);polygon:SetDrawLevel(3)
    self.digPolygons[used]=polygon
   end
   polygon:ClearAnchors();polygon:SetAnchor(TOPLEFT,self.map,TOPLEFT,0,0);polygon:SetDimensions(size,size)
   polygon:ClearPoints()
   for _,p in ipairs(points) do polygon:AddPoint(clamp(p.x,0,1),clamp(p.y,0,1)) end
   -- Clipping preserves the native border order used by ZO_PinPolygonBlob.
   polygon:SetPointLayout(POLYGON_POINT_LAYOUT_COUNTER_CLOCKWISE)
   -- Match the main map's dig-site colours, opacity and textured 3px border.
   local center=site.tracked and ZO_MAP_PIN_TRACKED_DIG_SITE_COLOR or ZO_MAP_PIN_DIG_SITE_COLOR
   local r,g,b=read(center and center.UnpackRGB,center)
   if not r then r,g,b=1,.85,.45 end
   local border=ZO_MAP_PIN_DIG_SITE_BORDER_COLOR
   local br,bg,bb,ba=read(border and border.UnpackRGBA,border)
   if not br then br,bg,bb,ba=1,1,1,1 end
   polygon:SetCenterColor(r,g,b,.39);polygon:SetBorderColor(br,bg,bb,ba);polygon:SetBorderThickness(3,3,1)
   polygon:SetHidden(false)
  end
 end
 for i=used+1,#self.digPolygons do self.digPolygons[i]:SetHidden(true) end
end
function M:DrawWaypoint(left,top,span,size)
 local x,y=read(GetMapPlayerWaypoint)
 if type(x)~='number' or type(y)~='number' or x<0 or x>1 or y<0 or y>1 or (x==0 and y==0) then self.waypoint:SetHidden(true);return end
 local px,py=(x-left)/span,(y-top)/span
 local margin=(WAYPOINT_SIZE/2+2)/size
 if px<margin or px>1-margin or py<margin or py>1-margin then
  local dx,dy=px-.5,py-.5
  local scale=(.5-margin)/math.max(math.abs(dx),math.abs(dy))
  px,py=.5+dx*scale,.5+dy*scale
  self.waypoint:SetTexture('EsoUI/Art/MapPins/UI-WorldMapPlayerPip.dds')
  local angle=math.atan2 and math.atan2(dx,-dy) or math.atan(dx,-dy)
  self.waypoint:SetTextureRotation(angle)
 else
  self.waypoint:SetTexture('EsoUI/Art/MapPins/UI_Worldmap_pin_customDestination_white.dds')
  self.waypoint:SetTextureRotation(0)
 end
 self.waypoint:ClearAnchors();self.waypoint:SetAnchor(CENTER,self.map,TOPLEFT,px*size,py*size);self.waypoint:SetHidden(false)
end
function M:Draw(x,y,heading)
 local size=self.saved.size;local span=1/self.saved.zoom
 local left,top=x-span/2,y-span/2
 local nx,ny=GetMapNumTiles();nx=tonumber(nx) or 0;ny=tonumber(ny) or 0
 local used=0
 -- Large zone maps can exceed 64 total tiles. Visit only tiles intersecting
 -- the viewport, preserving the native row-major texture index.
 if nx>0 and ny>0 and nx<=64 and ny<=64 then
  local firstCol=math.max(0,math.floor(left*nx))
  local lastCol=math.min(nx-1,math.ceil((left+span)*nx)-1)
  local firstRow=math.max(0,math.floor(top*ny))
  local lastRow=math.min(ny-1,math.ceil((top+span)*ny)-1)
  for row=firstRow,lastRow do for col=firstCol,lastCol do
   local px,py,pw,ph,u1,u2,v1,v2=self.Crop(col/nx,row/ny,1/nx,1/ny,left,top,span)
   if px then
    used=used+1;local tile=self.tiles[used]
    if not tile then tile=control(self.map,CT_TEXTURE,0,0,1,1);tile:SetDrawLevel(1);self.tiles[used]=tile end
    tile:ClearAnchors();tile:SetAnchor(TOPLEFT,self.map,TOPLEFT,px*size,py*size);tile:SetDimensions(pw*size,ph*size)
    local texture=GetMapTileTexture(row*nx+col+1)
    if tile.path~=texture then tile:SetTexture(texture or '');tile.path=texture end
    tile:SetTextureCoords(u1,u2,v1,v2);tile:SetHidden(false)
   end
  end end
 end
 for i=used+1,#self.tiles do self.tiles[i]:SetHidden(true) end
 self:DrawDigSites(left,top,span,size)
 used=0
 for _,p in ipairs(self.points) do
  local px,py=(p.x-left)/span,(p.y-top)/span
  local margin=(PIN_SIZE/2+1)/size
  if px>=margin and px<=1-margin and py>=margin and py<=1-margin then
   used=used+1;local pin=self.pins[used]
   if not pin then pin=control(self.map,CT_TEXTURE,0,0,PIN_SIZE,PIN_SIZE);pin:SetDrawLevel(10);self.pins[used]=pin end
   pin:ClearAnchors();pin:SetAnchor(CENTER,self.map,TOPLEFT,px*size,py*size);pin:SetTexture(p.texture)
   local c=p.color or {1,1,1};pin:SetColor(c[1],c[2],c[3],1);pin:SetHidden(false)
  end
 end
 for i=used+1,#self.pins do self.pins[i]:SetHidden(true) end
 self:DrawWaypoint(left,top,span,size)
 self.player:ClearAnchors();self.player:SetAnchor(CENTER,self.map,CENTER,0,0);self.player:SetTextureRotation(heading or 0)
 self.zone:SetText(GetMapName() or '')
end
function M:Tick()
 local settings=SCENE_MANAGER:IsShowing('tgwMiniMapSettings')
 local hud=SCENE_MANAGER:IsShowing('hud') or SCENE_MANAGER:IsShowing('hudui')
 local full=read(ZO_WorldMap_IsWorldMapShowing)
 local visible=self.active and self.saved.enabled and (hud or settings) and not full
 self.window:SetHidden(not visible);if not visible then return end
 local now=GetFrameTimeMilliseconds()
 if not self.lastMapCheck or now-self.lastMapCheck>=1000 then
  self.lastMapCheck=now
  local result=read(SetMapToPlayerLocation)
  if result==SET_MAP_RESULT_MAP_CHANGED then CALLBACK_MANAGER:FireCallbacks('OnWorldMapChanged');self.dirty=true;self.digDirty=true end
 end
 if self.dirty or not self.lastPoints or now-self.lastPoints>=5000 then self:RefreshPoints();self.dirty=false end
 if self.digDirty or not self.lastDigSites or now-self.lastDigSites>=2000 then self:RefreshDigSites() end
 local x,y,heading=GetMapPlayerPosition('player')
 if type(x)~='number' or type(y)~='number' or x<0 or x>1 or y<0 or y>1 or (x==0 and y==0) then self.window:SetHidden(true);return end
 self:Draw(x,y,heading)
end
local options={{'enabled','Minimap',kind='toggle'},{'size','Map size',min=220,max=440,step=20},{'zoom','Zoom',min=1,max=8,step=.5},{'x','Horizontal position',min=0,max=1,step=.02},{'y','Vertical position',min=0,max=1,step=.02},{'clock','Digital clock',kind='toggle'},{'hour24','24-hour clock',kind='toggle'},{'fps','FPS',kind='toggle'},{'latency','Latency',kind='toggle'},{'atlas','Atlas layers',kind='toggle'}}
function M:Settings()
 if IsUnitInCombat('player') then d('Atlas Mini Map: open settings after combat.');return end
 if not self.settingsWindow then
  local w=WINDOW_MANAGER:CreateTopLevelWindow('TGWAtlasMiniMapSettings');self.settingsWindow=w;w:SetDimensions(620,640);w:SetAnchor(CENTER,GuiRoot,CENTER,-180,0);w:SetHidden(true)
  solid(w,0,0,620,640,.025,.027,.035)
  label(w,26,20,568,32):SetText('ATLAS MINI MAP | 1.0.3')
  label(w,26,58,568,45):SetText('Stick / D-pad: select   X: decrease   Y: increase')
  self.settingLabels={};for i=1,#options do self.settingLabels[i]=label(w,26,115+(i-1)*40,568,35) end
  label(w,26,545,568,65):SetText('RB: reset defaults\nClock uses the time supplied by ESO.')
  self.selected=1
  local function change(direction)
   local o=options[self.selected];local k=o[1]
   if o.kind=='toggle' then self.saved[k]=not self.saved[k] else self.saved[k]=clamp(self.saved[k]+o.step*direction,o.min,o.max) end
   self.dirty=true;self:Layout();self:Header();self:SettingsText()
  end
  local function move(direction)
   self.selected=clamp(self.selected+direction,1,#options);self:SettingsText()
  end
  local function stop()
   EVENT_MANAGER:UnregisterForUpdate('TGWAtlasMiniMap_SettingsRepeat');self.held=nil
  end
  self.stopInput=stop
  local function held(direction,up)
   if up then if self.held==direction then stop() end;return end
   stop();self.held=direction;move(direction);local ticks=0
   EVENT_MANAGER:RegisterForUpdate('TGWAtlasMiniMap_SettingsRepeat',120,function()
    ticks=ticks+1;if ticks>=3 then move(direction) end
   end)
  end
  self.keys={alignment=KEYBIND_STRIP_ALIGN_LEFT,
   {keybind='UI_SHORTCUT_INPUT_UP',handlesKeyUp=true,callback=function(up) held(-1,up) end},
   {keybind='UI_SHORTCUT_INPUT_DOWN',handlesKeyUp=true,callback=function(up) held(1,up) end},
   {name='Decrease / toggle',keybind='UI_SHORTCUT_SECONDARY',callback=function() change(-1) end},
   {name='Increase / toggle',keybind='UI_SHORTCUT_TERTIARY',callback=function() change(1) end},
   {name='Reset defaults',keybind='UI_SHORTCUT_RIGHT_SHOULDER',callback=function() for k,v in pairs(defaults) do self.saved[k]=v end;self.dirty=true;self:Layout();self:Header();self:SettingsText() end},
   {name='Back',keybind='UI_SHORTCUT_NEGATIVE',callback=function() SCENE_MANAGER:Hide('tgwMiniMapSettings') end}}
  local scene=ZO_Scene:New('tgwMiniMapSettings',SCENE_MANAGER);scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW);scene:AddFragment(ZO_SimpleSceneFragment:New(w))
  scene:RegisterCallback('StateChange',function(_,state) if state==SCENE_SHOWING then self:SettingsText();KEYBIND_STRIP:AddKeybindButtonGroup(self.keys) elseif state==SCENE_HIDING then self.stopInput();KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keys) end end)
 end
 self:SettingsText();SCENE_MANAGER:Show('tgwMiniMapSettings')
end
function M:SettingsText()
 for i,o in ipairs(options) do
  local v=self.saved[o[1]];local text
  if type(v)=='boolean' then text=v and 'On' or 'Off' elseif o[1]=='x' or o[1]=='y' then text=string.format('%.0f%%',v*100) else text=tostring(v) end
  self.settingLabels[i]:SetText((i==self.selected and '> ' or '   ')..o[2]..'   '..text)
  self.settingLabels[i]:SetColor(i==self.selected and 1 or .85,i==self.selected and .55 or .85,i==self.selected and .4 or .85,1)
 end
end
EVENT_MANAGER:RegisterForEvent('TGWAtlasMiniMap_Load',EVENT_ADD_ON_LOADED,function(_,name)
 if name~='AtlasMiniMap' then return end
 EVENT_MANAGER:UnregisterForEvent('TGWAtlasMiniMap_Load',EVENT_ADD_ON_LOADED)
 M.saved=ZO_SavedVars:NewAccountWide('TGWAtlasMiniMapSaved',1,nil,defaults,GetWorldName())
 for k,v in pairs(defaults) do if M.saved[k]==nil then M.saved[k]=v end end
 M.saved.size=clamp(tonumber(M.saved.size) or 300,220,440);M.saved.zoom=clamp(tonumber(M.saved.zoom) or 3,1,8)
 M.saved.x=clamp(tonumber(M.saved.x) or .79,0,1);M.saved.y=clamp(tonumber(M.saved.y) or .08,0,1)
 M:Initialize()
 SLASH_COMMANDS['/minimap']=function(arg)
  arg=(arg or ''):lower()
  if arg=='toggle' then M.saved.enabled=not M.saved.enabled
  elseif arg=='reset' then for k,v in pairs(defaults) do M.saved[k]=v end;M.dirty=true;M:Layout();M:Header()
  else M:Settings() end
 end
 d('Atlas Mini Map 1.0.3 loaded. /minimap for settings.')
end)
