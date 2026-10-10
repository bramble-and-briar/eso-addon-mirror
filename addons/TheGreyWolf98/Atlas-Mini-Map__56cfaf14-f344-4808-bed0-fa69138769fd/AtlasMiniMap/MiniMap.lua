AtlasMiniMap = {}
local M=AtlasMiniMap
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
 clamp(s.y*GuiRoot:GetHeight(),0,math.max(0,GuiRoot:GetHeight()-size-60)))
 self.window:SetDimensions(size+8,size+60);self.bg:SetDimensions(size+8,size+60)
 self.map:SetDimensions(size,size);self.header:SetDimensions(size,26)
 self.clock:ClearAnchors();self.clock:SetAnchor(TOP,self.window,TOP,0,4);self.clock:SetDimensions(size-140,26);self.clock:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
 self.latency:ClearAnchors();self.latency:SetAnchor(TOPRIGHT,self.window,TOPRIGHT,-9,4)
 self.zone:SetDimensions(size-30,24);self.zone:ClearAnchors();self.zone:SetAnchor(TOPLEFT,self.window,TOPLEFT,9,size+34)
 self.north:ClearAnchors();self.north:SetAnchor(TOPRIGHT,self.map,TOPRIGHT,-4,3)
end
function M:Initialize()
 local w=WINDOW_MANAGER:CreateTopLevelWindow('TGWAtlasMiniMap');self.window=w
 self.bg=solid(w,0,0,308,360,.055,.035,.035)
 self.header=solid(w,4,4,300,26,.10,.045,.045)
 self.map=control(w,CT_CONTROL,4,30,300,300)
 self.mapBG=solid(self.map,0,0,300,300,.018,.018,.025);self.mapBG:SetAnchorFill(self.map)
 self.clock=label(w,75,4,150,26);self.fps=label(w,9,4,70,26);self.latency=label(w,230,4,70,26)
 self.latency:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
 self.zone=label(w,9,334,270,24);self.north=label(self.map,275,3,20,24);self.north:SetText('N');self.north:SetColor(1,.7,.4,1)
 self.tiles={};self.pins={};self.points={}
 self.player=control(self.map,CT_TEXTURE,0,0,22,22);self.player:SetTexture('EsoUI/Art/MapPins/UI-WorldMapPlayerPip.dds');self.player:SetDrawLevel(20)
 self.north:SetDrawLevel(25)
 self:Layout()
 EVENT_MANAGER:RegisterForUpdate('TGWAtlasMiniMap_Move',100,function() self:Tick() end)
 EVENT_MANAGER:RegisterForUpdate('TGWAtlasMiniMap_Header',1000,function() self:Header() end)
 CALLBACK_MANAGER:RegisterCallback('OnWorldMapChanged',function() self.dirty=true end)
 EVENT_MANAGER:RegisterForEvent('TGWAtlasMiniMap_Zone',EVENT_PLAYER_ACTIVATED,function() self.active=true;self.dirty=true end)
 EVENT_MANAGER:RegisterForEvent('TGWAtlasMiniMap_Off',EVENT_PLAYER_DEACTIVATED,function() self.active=false;self.window:SetHidden(true) end)
 self.active=true;self.dirty=true;self:Header()
end
function M:Header()
 local s=self.saved;self.clock:SetText(s.clock and self.Clock(read(GetTimeString) or '',s.hour24) or '')
 local fps=s.fps and read(GetFramerate);local ping=s.latency and read(GetLatency)
 self.fps:SetText(type(fps)=='number' and fps>0 and string.format('%d FPS',math.floor(fps+.5)) or '')
 self.latency:SetText(type(ping)=='number' and ping>=0 and string.format('%d ms',math.floor(ping+.5)) or '')
end
function M:RefreshPoints()
 self.points={}
 local function add(x,y,texture,color)
  if #self.points>=512 then return end
  if type(x)=='number' and type(y)=='number' and x>=0 and x<=1 and y>=0 and y<=1 and texture and texture~='' then
   self.points[#self.points+1]={x=x,y=y,texture=texture,color=color}
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
 else
  local zone=read(GetCurrentMapZoneIndex)
  if type(zone)=='number' and zone>0 then
   for i=1,read(GetNumPOIs,zone) or 0 do
    -- POI map info: x, y, pin type, icon, shown on map.
    local ok,x,y,_,icon,onMap=pcall(GetPOIMapInfo,zone,i)
    if ok and onMap then add(x,y,icon) end
   end
  end
 end
 self.lastPoints=GetFrameTimeMilliseconds()
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
 used=0
 for _,p in ipairs(self.points) do
  local px,py=(p.x-left)/span,(p.y-top)/span
  if px>=.03 and px<=.97 and py>=.03 and py<=.97 then
   used=used+1;local pin=self.pins[used]
   if not pin then pin=control(self.map,CT_TEXTURE,0,0,18,18);pin:SetDrawLevel(10);self.pins[used]=pin end
   pin:ClearAnchors();pin:SetAnchor(CENTER,self.map,TOPLEFT,px*size,py*size);pin:SetTexture(p.texture)
   local c=p.color or {1,1,1};pin:SetColor(c[1],c[2],c[3],1);pin:SetHidden(false)
  end
 end
 for i=used+1,#self.pins do self.pins[i]:SetHidden(true) end
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
  if result==SET_MAP_RESULT_MAP_CHANGED then CALLBACK_MANAGER:FireCallbacks('OnWorldMapChanged');self.dirty=true end
 end
 if self.dirty or not self.lastPoints or now-self.lastPoints>=5000 then self:RefreshPoints();self.dirty=false end
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
  label(w,26,20,568,32):SetText('ATLAS MINI MAP | 1.0.1')
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
 d('Atlas Mini Map 1.0.1 loaded. /minimap for settings.')
end)
