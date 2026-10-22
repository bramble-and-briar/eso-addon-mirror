PBF=PBF or {}
local C=PBF.Core
local U={};U.__index=U;PBF.UI=U
local floor,min,max=math.floor,math.min,math.max
local TEX='PBsFMEGA/assets/white.dds'
local VW,VH=1280,720
local FADE_IN,FADE_OUT,HOLD_MIN,HOLD_MAX=.28,.34,.1,1.2
local SPARKS,LINES=16,14
-- Colours are rounded to 1/64 before they are compared with what a control already shows: a
-- rectangle whose colour drifts by a thousandth would otherwise cost an API call every frame.
local function q(v) return floor(v*63+.5)/63 end
local function qa(v) return floor(v*32+.5)/32 end   -- alpha: a fade is smooth at 1/32 and costs a call only when it steps
local function label(parent,x,y,w,h,size,value,align)
 local c=WINDOW_MANAGER:CreateControl(nil,parent,CT_LABEL);c:SetAnchor(TOPLEFT,parent,TOPLEFT,x,y);c:SetDimensions(w,h)
 c:SetFont('ZoFontGamepad'..size);c:SetHorizontalAlignment(align or TEXT_ALIGN_CENTER);c:SetColor(.95,.95,1,1)
 c:SetDrawLayer(DL_TEXT);c:SetDrawLevel(20);c:SetText(value or '');return c
end
-- The window and the scene exist from the start (the menu needs a scene to push); every control
-- inside is built the first time the game is opened, behind the curtain, so a player who never
-- launches it pays for none of them.
function U.New(app)
 local self=setmetatable({app=app,slots={},active={},nextActive={},activeN=0,frame=0,sky={},text={},plates={},panos={},win={{},{},{}},
  sparks={},lines={}},U)
 local root=WINDOW_MANAGER:CreateTopLevelWindow('PBsFMEGAWindow');self.root=root
 root:SetAnchorFill(GuiRoot);root:SetHidden(true)
 local curtain=WINDOW_MANAGER:CreateTopLevelWindow('PBsFMEGACurtain')
 curtain:SetAnchorFill(GuiRoot);curtain:SetHidden(true);curtain:SetDrawTier(DT_HIGH);curtain:SetDrawLayer(DL_OVERLAY);curtain:SetDrawLevel(9)
 local black=WINDOW_MANAGER:CreateControl(nil,curtain,CT_BACKDROP)
 black:SetAnchorFill(curtain);black:SetCenterColor(0,0,0,1);black:SetEdgeColor(0,0,0,0);black:SetEdgeTexture('',1,1,1)
 self.curtain=curtain
 self.keybinds={alignment=KEYBIND_STRIP_ALIGN_CENTER,
  {keybind='UI_SHORTCUT_TERTIARY',name=function() return app:BackLabel() end,callback=function() app:Back() end}}
 self.scene=ZO_Scene:New('pbfGame',SCENE_MANAGER)
 self.scene:AddFragment(ZO_SimpleSceneFragment:New(self.root))
 -- The client's own window group draws a dark band along the bottom of the screen behind the keybind strip; this one is the same without it
 self.scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_NO_KEYBIND_BACKGROUND_WINDOW or FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
 self.scene:AddFragment(ZO_ActionLayerFragment:New('PBsFMEGAInput'))
 self.scene:RegisterCallback('StateChange',function(_,state)
  if state==SCENE_SHOWING then
   self:Fit();KEYBIND_STRIP:AddKeybindButtonGroup(self.keybinds)
  elseif state==SCENE_SHOWN then self.sceneShown=true
  elseif state==SCENE_HIDING then self.sceneShown=false;KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybinds);app:Hidden() end
 end)
 return self
end
function U:Fit()
 if self.content then self.content:SetScale(min(GuiRoot:GetWidth()/VW,GuiRoot:GetHeight()/VH)) end
end
-- A HUD plate: flat-coloured until the pictures are in use, then a cell of the HUD sheet.
-- `cell` is nil for plates that stay flat (the map dots).
function U:Plate(x,y,w,h,r,g,b,a,level,cell,tint)
 local c=WINDOW_MANAGER:CreateControl(nil,self.content,CT_TEXTURE);c:SetTexture(TEX)
 c:SetAnchor(TOPLEFT,self.content,TOPLEFT,x,y);c:SetDimensions(w,h);c:SetColor(r,g,b,a)
 c:SetDrawLayer(DL_OVERLAY);c:SetDrawLevel(level or 5)
 if cell then self.plates[#self.plates+1]={c=c,cell=cell,flat={r,g,b,a},tint=tint} end
 return c
end
-- ------------------------------------------------------------------------------------------
-- Building
function U:EnsureBuilt(view,track)
 if not self.content then
  local content=WINDOW_MANAGER:CreateControl(nil,self.root,CT_CONTROL)
  content:SetDimensions(VW,VH);content:SetAnchor(CENTER,self.root,CENTER,0,0);self.content=content
  local black=WINDOW_MANAGER:CreateControl(nil,self.root,CT_TEXTURE);black:SetTexture(TEX);black:SetColor(0,0,0,1)
  black:SetAnchorFill(self.root);black:SetDrawLayer(DL_BACKGROUND);black:SetDrawLevel(0)
  self.view=view
  self:BuildHud()
  self:Fit()
 end
 self:Configure(view,track)
end
-- Which texture and blend a pooled control has depends on what its slot is: a road slot shows the
-- course's road picture, a sprite slot the world sheet, a glow slot the same sheet added to what
-- is behind it. In flat mode every slot is a plain white rectangle.
function U:BindSlot(c,view,slot)
 local kind=view:SlotKind(slot)
 c.slotKind=kind
 if view.rich then
  c:SetTexture(kind=='road' and view.tinfo.road or view.atlas.world.file)
  c:SetBlendMode(kind=='glow' and TEX_BLEND_MODE_ADD or TEX_BLEND_MODE_ALPHA)
 else
  c:SetTexture(TEX);c:SetBlendMode(TEX_BLEND_MODE_ALPHA);c:SetTextureCoords(0,1,0,1)
 end
 c:SetDrawLevel(view:SlotLevel(slot))
 c.cx,c.cy,c.cw,c.ch,c.cr,c.cg,c.cb,c.ca=nil,nil,nil,nil,nil,nil,nil,nil
 c.cu0,c.cu1,c.cv0,c.cv1=nil,nil,nil,nil
end
-- Called whenever the view, its mode, its theme or its band height changes.
function U:Configure(view,track)
 self.view=view
 local rich=view.rich
 self.rich=rich
 local sig=(rich and 'r' or 'f')..view.themeName..view.band
 if self.configFor==sig then self:BuildMap(track);self:ApplyHud();return end
 self.configFor=sig
 -- Slot numbers mean different things once the band count or the mode changes (a ground slot
 -- becomes a machine slot), so every pooled control forgets what it was showing and is bound
 -- again to the slot it now stands for.
 for slot,c in pairs(self.slots) do
  c:SetHidden(true);c.shown=false
  self:BindSlot(c,view,slot)
 end
 self.active,self.nextActive,self.activeN={}, {},0
 self.staticControls=self.staticControls or {}
 for _,c in ipairs(self.staticControls) do c:SetHidden(true) end
 for _,e in ipairs(self.sky) do e.control:SetHidden(true);e.on=false end
 for _,list in pairs(self.panos) do for _,e in ipairs(list) do e.control:SetHidden(true);e.on=false end end
 if rich then
  self:BuildPanos(view)
  self:BuildEffects(view)
 else
  local list=view:StaticRects()
  for i,r in ipairs(list) do
   local c=self.staticControls[i]
   if not c then
    c=WINDOW_MANAGER:CreateControl(nil,self.content,CT_TEXTURE);c:SetTexture(TEX);c:SetDrawLayer(DL_BACKGROUND);c:SetDrawLevel(1)
    self.staticControls[i]=c
   end
   c:SetAnchor(TOPLEFT,self.content,TOPLEFT,r.x,r.y);c:SetDimensions(r.w,r.h);c:SetColor(r.r,r.g,r.b,r.a);c:SetHidden(false)
  end
  for i=#list+1,#self.staticControls do self.staticControls[i]:SetHidden(true) end
  for i=1,view.SKYLINE_RECTS do
   local e=self.sky[i]
   if not e then
    local c=WINDOW_MANAGER:CreateControl(nil,self.content,CT_TEXTURE);c:SetTexture(TEX);c:SetDrawLayer(DL_BACKGROUND);c:SetDrawLevel(2)
    c:SetHidden(true);e={control=c};self.sky[i]=e
   end
  end
  self.skyRects={}
  view:BuildSkyline(track and (#track.def.points*7) or 11)
  self:HideEffects()
 end
 self:BuildMap(track)
 self:ApplyHud()
end
-- Three scrolling pictures in rich mode: the sky, a far layer and a near layer. Each is drawn as
-- up to two controls because the 360 degree picture wraps round and there is no tiling to lean on.
local PANO={{key='sky',level=1,parallax=1.0},{key='far',level=2,parallax=.96},{key='near',level=3,parallax=1.0}}
function U:BuildPanos(view)
 local ti=view.tinfo
 for li,p in ipairs(PANO) do
  local list=self.panos[p.key]
  if not list then
   list={}
   for i=1,2 do
    local c=WINDOW_MANAGER:CreateControl(nil,self.content,CT_TEXTURE)
    c:SetDrawLayer(DL_BACKGROUND);c:SetDrawLevel(p.level);c:SetHidden(true)
    list[i]={control=c}
   end
   self.panos[p.key]=list
  end
  for _,e in ipairs(list) do e.control:SetTexture(ti[p.key]);e.x,e.y,e.w,e.h,e.u0,e.u1=nil,nil,nil,nil,nil,nil end
 end
 -- the silhouettes keep the proportions of the 4096 wide picture, so both layers share a height
 local du=view.W/(view.f*2*math.pi)
 self.layerH=floor(ti.nearH*view.W/(du*ti.nearW)+.5)
 -- Probes for the loader check: a texture that failed to load reports a 1 x 1 placeholder.
 self.probes=self.probes or {}
 local files={view.atlas.world.file,ti.road,ti.sky}
 for i,file in ipairs(files) do
  local c=self.probes[i]
  if not c then c=WINDOW_MANAGER:CreateControl(nil,self.content,CT_TEXTURE);c:SetHidden(true);c:SetDimensions(1,1);self.probes[i]=c end
  c:SetTexture(file)
 end
 self.atlasChecked=false;self.richSince=nil
end
-- Sparks, speed lines and the screen-edge vignette. Built once; shown only while racing.
function U:BuildEffects(view)
 local world=view.atlas.world
 local spark=view:CellUV(world,'spark')
 for i=1,SPARKS do
  local e=self.sparks[i]
  if not e then
   local c=WINDOW_MANAGER:CreateControl(nil,self.content,CT_TEXTURE)
   c:SetDrawLayer(DL_OVERLAY);c:SetDrawLevel(6);c:SetBlendMode(TEX_BLEND_MODE_ADD);c:SetHidden(true)
   e={control=c,life=0};self.sparks[i]=e
  end
  e.control:SetTexture(world.file);e.control:SetTextureCoords(spark.u0,spark.u1,spark.v0,spark.v1);e.control:SetDimensions(22,22)
 end
 for i=1,LINES do
  local e=self.lines[i]
  if not e then
   local c=WINDOW_MANAGER:CreateControl(nil,self.content,CT_TEXTURE);c:SetTexture(TEX)
   c:SetDrawLayer(DL_OVERLAY);c:SetDrawLevel(4);c:SetHidden(true)
   e={control=c,y=math.random()*VH,x=0,len=0};self.lines[i]=e
  end
 end
 if not self.vignette then
  local c=WINDOW_MANAGER:CreateControl(nil,self.content,CT_TEXTURE)
  c:SetAnchor(TOPLEFT,self.content,TOPLEFT,0,0);c:SetDimensions(VW,VH);c:SetDrawLayer(DL_OVERLAY);c:SetDrawLevel(3);c:SetHidden(true)
  self.vignette=c
 end
 local v=view:CellUV(view.atlas.hud,'vignette')
 self.vignette:SetTexture(view.atlas.hud.file);self.vignette:SetTextureCoords(v.u0,v.u1,v.v0,v.v1)
 self.vigBoost,self.vigHit,self.vigShown=0,0,false
end
function U:HideEffects()
 for _,e in ipairs(self.sparks) do e.control:SetHidden(true);e.life=0 end
 for _,e in ipairs(self.lines) do e.control:SetHidden(true) end
 if self.vignette then self.vignette:SetHidden(true) end
end
-- A ground or machine rectangle: made the first time a slot is used, then kept.
function U:Slot(view,slot)
 local c=self.slots[slot]
 if c then return c end
 c=WINDOW_MANAGER:CreateControl(nil,self.content,CT_TEXTURE)
 c:SetDrawLayer(DL_CONTROLS);c:SetHidden(true)
 c.shown=false
 self:BindSlot(c,view,slot)
 self.slots[slot]=c;return c
end
function U:BuildHud()
 local p=self.content
 local t=self.text
 t.rank=label(p,28,6,260,52,42,'',TEXT_ALIGN_LEFT)
 t.lap=label(p,30,58,300,30,22,'',TEXT_ALIGN_LEFT)
 t.time=label(p,420,6,440,52,42,'')
 t.best=label(p,420,58,440,30,22,'')
 self.speedPlate=self:Plate(868,610,380,92,0,0,0,0,3,'plate_speed')
 t.speed=label(p,860,630,380,60,42,'',TEXT_ALIGN_RIGHT)
 t.speedUnit=label(p,860,676,380,30,18,'SPEED',TEXT_ALIGN_RIGHT)
 t.energyName=label(p,40,606,300,26,18,'エネルギー',TEXT_ALIGN_LEFT)
 t.boost=label(p,200,604,300,28,22,'',TEXT_ALIGN_LEFT)
 self.boostIcon=self:Plate(156,598,36,36,1,1,1,0,7,'lamp_off')
 self.energyFrame=self:Plate(38,636,424,30,.05,.06,.1,.75,6,'bar_frame')
 self.energyFill=self:Plate(42,640,416,22,.3,.9,.4,1,7,'bar_fill')
 t.banner=label(p,240,230,800,100,42,'')
 t.banner:SetDrawLayer(DL_OVERLAY);t.banner:SetDrawLevel(30);t.banner:SetHidden(true)
 t.fps=label(p,500,690,280,24,18,'')
 t.fps:SetHidden(true)
 -- Overlays (garage, pause, results) share one panel; each kind switches on its own labels.
 local function over(c) c:SetDrawLayer(DL_OVERLAY);c:SetDrawLevel(14);return c end
 self.panel=self:Plate(250,120,780,490,.02,.025,.05,.92,12,'panel')
 self.panelEdge=self:Plate(250,120,780,4,.5,.7,1,1,13)
 t.ovTitle=over(label(p,250,134,780,52,42,''))
 t.ovSub=over(label(p,270,190,740,60,22,''))
 t.ovHint=over(label(p,262,566,756,36,18,''))
 -- garage
 t.ovMachine=over(label(p,250,238,780,46,34,''))
 t.ovNote=over(label(p,250,452,780,30,22,''))
 t.ovLevel=over(label(p,250,492,780,30,22,''))
 t.ovMusic=over(label(p,250,524,780,30,18,''))
 self.statNames={}
 self.bars={}
 for i=1,4 do
  self.statNames[i]=over(label(p,290,292+(i-1)*36-4,130,30,22,'',TEXT_ALIGN_LEFT))
  self.bars[i]={back=self:Plate(430,292+(i-1)*36,360,18,.12,.14,.2,1,14,'bar_fill',{.16,.19,.28,1}),fill=self:Plate(430,292+(i-1)*36,360,18,.4,.7,1,1,15,'bar_fill',{.4,.72,1,1})}
 end
 -- results: three columns that share a line height, so the rows line up
 t.ovA=over(label(p,290,254,120,300,25,'',TEXT_ALIGN_LEFT))
 t.ovB=over(label(p,400,254,430,300,25,'',TEXT_ALIGN_LEFT))
 t.ovC=over(label(p,820,254,190,300,25,'',TEXT_ALIGN_RIGHT))
 self.groups={
  common={self.panel,self.panelEdge,t.ovTitle,t.ovSub,t.ovHint},
  garage={t.ovMachine,t.ovNote,t.ovLevel,t.ovMusic},
  result={t.ovA,t.ovB,t.ovC},
 }
 for _,n in ipairs(self.statNames) do table.insert(self.groups.garage,n) end
 for _,b in ipairs(self.bars) do table.insert(self.groups.garage,b.back);table.insert(self.groups.garage,b.fill) end
 self.mapDots={}
 self.footer=label(p,30,700,1220,20,18,'');self.footer:SetHidden(true)
 self:ShowPanel(nil)
end
-- Puts the pictures on the HUD plates (or takes them off again, in flat mode). Safe to call any
-- number of times.
function U:ApplyHud()
 local view=self.view
 local rich=view and view.rich
 local sheet=rich and view.atlas.hud
 for _,pl in ipairs(self.plates) do
  if rich then
   local uv=view:CellUV(sheet,pl.cell)
   local t=pl.tint or {1,1,1,1}
   pl.c:SetTexture(sheet.file);pl.c:SetTextureCoords(uv.u0,uv.u1,uv.v0,uv.v1);pl.c:SetColor(t[1],t[2],t[3],t[4])
  else
   pl.c:SetTexture(TEX);pl.c:SetTextureCoords(0,1,0,1);pl.c:SetColor(pl.flat[1],pl.flat[2],pl.flat[3],pl.flat[4])
  end
 end
 self.hudRich=rich
 self.energyW=nil;self.boostLit=nil
 if self.mapBack and self.mapPlate then self:ApplyMapPlate() end
 self:ShowPanel(self.panelKind)
end
-- Course map in the top-right corner: the outline is dots along the centreline, laid out once
-- per course; eight more dots are the machines.
function U:BuildMap(track)
 if not track or self.mapFor==track then return end
 self.mapFor=track
 for _,d in ipairs(self.mapDots) do d:SetHidden(true) end
 local minx,maxx,miny,maxy=1e9,-1e9,1e9,-1e9
 for i=1,track.n do
  minx=min(minx,track.x[i]);maxx=max(maxx,track.x[i]);miny=min(miny,track.y[i]);maxy=max(maxy,track.y[i])
 end
 local box=170;local scale=box/max(maxx-minx,maxy-miny)
 local mw,mh=(maxx-minx)*scale,(maxy-miny)*scale
 local ox=1250-mw;local oy=108
 self.mapScale,self.mapMinX,self.mapMaxY,self.mapOX,self.mapOY=scale,minx,maxy,ox,oy
 local count=64;local stride=track.n/count
 for k=1,count do
  local i=floor((k-1)*stride)+1
  local d=self.mapDots[k]
  if not d then d=self:Plate(0,0,3,3,.7,.8,1,.8,8);self.mapDots[k]=d end
  d:SetAnchor(TOPLEFT,self.content,TOPLEFT,ox+(track.x[i]-minx)*scale-1,oy+(maxy-track.y[i])*scale-1);d:SetHidden(false)
 end
 for k=count+1,#self.mapDots do self.mapDots[k]:SetHidden(true) end
 self.mapMachines=self.mapMachines or {}
 -- The frame is sized to this course, so a long thin one does not float in a square.
 if not self.mapBack then
  self.mapBack=self:Plate(0,0,10,10,.02,.03,.06,.55,3)
  self.mapPlate={cell='mapplate',flat={.02,.03,.06,.55}}
 end
 self.mapBack:SetAnchor(TOPLEFT,self.content,TOPLEFT,ox-9,oy-9);self.mapBack:SetDimensions(mw+18,mh+18)
 self:ApplyMapPlate()
 self.mapBack:SetHidden(false)
end
function U:ApplyMapPlate()
 local view=self.view
 if view and view.rich then
  local uv=view:CellUV(view.atlas.hud,'mapplate')
  self.mapBack:SetTexture(view.atlas.hud.file);self.mapBack:SetTextureCoords(uv.u0,uv.u1,uv.v0,uv.v1);self.mapBack:SetColor(1,1,1,1)
 else
  local f=self.mapPlate.flat
  self.mapBack:SetTexture(TEX);self.mapBack:SetTextureCoords(0,1,0,1);self.mapBack:SetColor(f[1],f[2],f[3],f[4])
 end
end
-- ------------------------------------------------------------------------------------------
-- Per frame
function U:Rect(view,slot,x,y,w,h,r,g,b,a,u0,u1,v0,v1)
 local c=self.slots[slot] or self:Slot(view,slot)
 if c.cx~=x or c.cy~=y then c:SetAnchor(TOPLEFT,self.content,TOPLEFT,x,y);c.cx,c.cy=x,y end
 if c.cw~=w or c.ch~=h then c:SetDimensions(w,h);c.cw,c.ch=w,h end
 r,g,b,a=q(r),q(g),q(b),qa(a)
 if c.cr~=r or c.cg~=g or c.cb~=b or c.ca~=a then c:SetColor(r,g,b,a);c.cr,c.cg,c.cb,c.ca=r,g,b,a end
 if u0 and (c.cu0~=u0 or c.cu1~=u1 or c.cv0~=v0 or c.cv1~=v1) then
  -- a left coordinate above the right one mirrors the picture, which is how a road seen from
  -- the other side of a curve is drawn the right way round
  c:SetTextureCoords(u0,u1,v0,v1);c.cu0,c.cu1,c.cv0,c.cv1=u0,u1,v0,v1
 end
 if not c.shown then c:SetHidden(false);c.shown=true end
 c.seen=self.frame
end
-- Moves one scrolling picture to the window the camera is looking at.
function U:Pano(view,key,parallax,windows,y,h)
 local list=self.panos[key]
 local n=view:PanoWindows(view.cam.h,parallax,windows)
 for i=1,2 do
  local e=list[i];local c=e.control
  if i<=n then
   local win=windows[i]
   local x,w=floor(win.x+.5),max(1,floor(win.w+.5))
   if e.x~=x or e.y~=y then c:SetAnchor(TOPLEFT,self.content,TOPLEFT,x,y);e.x,e.y=x,y end
   if e.w~=w or e.h~=h then c:SetDimensions(w,h);e.w,e.h=w,h end
   if e.u0~=win.u0 or e.u1~=win.u1 then c:SetTextureCoords(win.u0,win.u1,0,1);e.u0,e.u1=win.u0,win.u1 end
   if not e.on then c:SetHidden(false);e.on=true end
  elseif e.on then c:SetHidden(true);e.on=false end
 end
end
function U:Draw(track,race,dt)
 local view=self.view
 self.frame=self.frame+1
 view:Follow(race.player,dt,false)
 local o=view.o
 view:Frame(track,race)
 local x,y,w,h,r,g,b,a,slot=o.x,o.y,o.w,o.h,o.r,o.g,o.b,o.a,o.slot
 local u0,u1,v0,v1=o.u0,o.u1,o.v0,o.v1
 -- Whole pixels: a fractional position makes the engine filter the edge of a flat rectangle,
 -- which shows as a seam between two bands.
 for i=1,o.n do self:Rect(view,slot[i],floor(x[i]+.5),floor(y[i]+.5),max(1,floor(w[i]+.5)),max(1,floor(h[i]+.5)),r[i],g[i],b[i],a[i],u0[i],u1[i],v0[i],v1[i]) end
 -- Whatever was drawn last frame and not this one goes.
 local nextActive=self.nextActive
 for i=1,o.n do nextActive[i]=slot[i] end
 for i=1,self.activeN do
  local c=self.slots[self.active[i]]
  if c.seen~=self.frame and c.shown then c:SetHidden(true);c.shown=false end
 end
 self.active,self.nextActive,self.activeN=nextActive,self.active,o.n
 if view.rich then
  self:Pano(view,'sky',1.0,self.win[1],0,view.hy)
  self:Pano(view,'far',.96,self.win[2],view.hy-self.layerH,self.layerH)
  self:Pano(view,'near',1.0,self.win[3],view.hy-self.layerH,self.layerH)
  return
 end
 local n=view:Skyline(view.cam.h,self.skyRects)
 for i=1,view.SKYLINE_RECTS do
  local e=self.sky[i];local c=e.control
  if i<=n then
   local s=self.skyRects[i]
   local sx,sy,sw,sh=floor(s.x+.5),floor(s.y+.5),floor(s.w+.5),floor(s.h+.5)
   if e.x~=sx or e.y~=sy then c:SetAnchor(TOPLEFT,self.content,TOPLEFT,sx,sy);e.x,e.y=sx,sy end
   if e.w~=sw or e.h~=sh then c:SetDimensions(sw,sh);e.w,e.h=sw,sh end
   if e.r~=s.r then c:SetColor(s.r,s.g,s.b,1);e.r=s.r end
   if not e.on then c:SetHidden(false);e.on=true end
  elseif e.on then c:SetHidden(true);e.on=false end
 end
end
-- Screen-space effects, rich mode only: the glow at the edges while boosting (blue) or just hit
-- (red), speed streaks at the sides, and sparks flung off a wall the player is scraping.
function U:Effects(race,dt,racing)
 if not self.rich then return end
 local p=race.player
 local boost=(racing and p.boosting) and .5 or 0
 self.vigBoost=self.vigBoost+(boost-self.vigBoost)*min(1,dt*7)
 self.vigHit=max(0,self.vigHit-dt*1.8)
 local v=self.vignette
 local a=max(self.vigBoost,self.vigHit*.8)
 if a>.02 then
  local hit=self.vigHit*.8>self.vigBoost
  local r,g,b=.35,.65,1
  if hit then r,g,b=1,.18,.12 end
  if self.vigA~=a or self.vigHitCol~=hit then v:SetColor(r,g,b,a);self.vigA,self.vigHitCol=a,hit end
  if not self.vigShown then v:SetHidden(false);self.vigShown=true end
 elseif self.vigShown then v:SetHidden(true);self.vigShown=false end
 -- speed streaks
 -- only while boosting or on a dash plate: a streak on every frame at top speed is just noise
 local fast=racing and (p.boosting or (p.pad and p.pad>0))
 for i,e in ipairs(self.lines) do
  local c=e.control
  if fast then
   e.y=e.y+(900+i*40)*dt
   if e.y>VH or e.len==0 then
    e.y=-60-math.random()*200;e.len=60+math.random()*120
    local side=math.random()<.5 and -1 or 1
    e.x=side<0 and (10+math.random()*190) or (VW-200+math.random()*190)
    c:SetDimensions(3,e.len)
   end
   c:SetAnchor(TOPLEFT,self.content,TOPLEFT,e.x,e.y)
   if not e.on then c:SetColor(.8,.92,1,.32);c:SetHidden(false);e.on=true end
  elseif e.on then c:SetHidden(true);e.on=false;e.len=0 end
 end
 -- sparks
 if racing and p.scrape then
  local side=p.d>0 and 1 or -1
  for _=1,2 do
   for _,e in ipairs(self.sparks) do
    if e.life<=0 then
     e.life=.35+math.random()*.35
     e.x=VW/2+side*(300+math.random()*40);e.y=500+math.random()*60
     e.vx=-side*(40+math.random()*260);e.vy=-160-math.random()*300
     e.control:SetHidden(false);break
    end
   end
  end
 end
 for _,e in ipairs(self.sparks) do
  if e.life>0 then
   e.life=e.life-dt
   if e.life<=0 then e.control:SetHidden(true)
   else
    e.vy=e.vy+900*dt;e.x=e.x+e.vx*dt;e.y=e.y+e.vy*dt
    e.control:SetAnchor(TOPLEFT,self.content,TOPLEFT,e.x-11,e.y-11)
    e.control:SetAlpha(min(1,e.life*4))
   end
  end
 end
end
-- Called by the game when the player's machine is hit.
function U:Hit(strength) if self.rich then self.vigHit=max(self.vigHit or 0,min(1,strength/30)) end end
-- Reads the loader's verdict once the scene has been up a moment: a picture that is missing or
-- unreadable reports a 1 x 1 placeholder. Returns the name of the first failure, or nil.
function U:CheckPictures(now)
 if not self.rich or self.atlasChecked then return nil end
 self.richSince=self.richSince or now
 if now-self.richSince<.6 then return nil end
 self.atlasChecked=true
 for i,c in ipairs(self.probes or {}) do
  local w,h=c:GetTextureFileDimensions()
  if w==1 and h==1 then return ({'world','road','sky'})[i] end
 end
 return nil
end
function U:Text(key,value)
 local c=self.text[key]
 if self.shownText==nil then self.shownText={} end
 if self.shownText[key]~=value then self.shownText[key]=value;c:SetText(value) end
end
function U:Hud(race,saved)
 local p=race.player;local t=self.text
 self:Text('rank',string.format('%d位 / %d台',p.rank,#race.machines))
 self:Text('lap',string.format('ラップ %d / %d',min(p.lap,race.laps),race.laps))
 self:Text('time',C.FormatTime(race.time))
 self:Text('best',race.bestLap and ('ベストラップ '..C.FormatTime(race.bestLap)) or '')
 self:Text('speed',string.format('%d km/h',floor(p.speed*5)))
 local e=C.clamp(p.energy/100,0,1)
 local w=max(1,floor(416*e))
 if self.energyW~=w then
  self.energyW=w;self.energyFill:SetDimensions(w,22)
  local r,g,b=1-e*.7,.25+e*.7,.3
  if e<.3 then r,g,b=1,.2,.2 end
  self.energyFill:SetColor(r,g,b,1)
  if self.hudRich then
   -- show the first part of the picture rather than squeezing all of it, so the cells keep their size
   local uv=self.view:CellUV(self.view.atlas.hud,'bar_fill')
   self.energyFill:SetTextureCoords(uv.u0,uv.u0+(uv.u1-uv.u0)*e,uv.v0,uv.v1)
  end
 end
 local can=p.lap>=PBF.Race.BOOST_FROM_LAP and p.energy>PBF.Machine.BOOST_MIN
 local text=''
 if p.lap>=PBF.Race.BOOST_FROM_LAP then text=p.energy>PBF.Machine.BOOST_MIN and (p.boosting and 'ブースト中！' or 'ブースト可：○') or 'ブースト不可' else text='ブーストは2周目から' end
 self:Text('boost',text)
 if self.hudRich and self.boostLit~=can then
  self.boostLit=can
  local uv=self.view:CellUV(self.view.atlas.hud,can and 'lamp_on' or 'lamp_off')
  self.boostIcon:SetTextureCoords(uv.u0,uv.u1,uv.v0,uv.v1)
 end
 -- Machines on the map.
 for i,m in ipairs(race.machines) do
  local d=self.mapMachines[i]
  if not d then d=self:Plate(0,0,i==1 and 7 or 5,i==1 and 7 or 5,1,1,1,1,9);self.mapMachines[i]=d end
  local size=i==1 and 7 or 5
  d:SetAnchor(TOPLEFT,self.content,TOPLEFT,self.mapOX+(m.x-self.mapMinX)*self.mapScale-size/2,self.mapOY+(self.mapMaxY-m.y)*self.mapScale-size/2)
  if d.mapKind~=m.type.id or d.mapWrecked~=m.wrecked then
   d.mapKind,d.mapWrecked=m.type.id,m.wrecked
   local col=m.type.body
   if i==1 then d:SetColor(1,.95,.3,1) elseif m.wrecked then d:SetColor(.4,.4,.4,1) else d:SetColor(col[1],col[2],col[3],1) end
  end
  d:SetHidden(false)
 end
end
function U:HideHud(hidden)
 local t=self.text
 for k,c in pairs(t) do if k:sub(1,2)~='ov' and k~='banner' then c:SetHidden(hidden) end end
 self.energyFrame:SetHidden(hidden);self.energyFill:SetHidden(hidden)
 -- the speed plate and the boost icon only exist as pictures
 local rich=self.hudRich
 self.speedPlate:SetHidden(hidden or not rich);self.boostIcon:SetHidden(hidden or not rich)
 for _,d in ipairs(self.mapDots) do d:SetHidden(hidden) end
 for _,d in ipairs(self.mapMachines or {}) do d:SetHidden(hidden) end
 if self.mapBack then self.mapBack:SetHidden(hidden) end
 if not hidden then t.fps:SetHidden(not (self.app.saved and self.app.saved.showFps)) else t.fps:SetHidden(true);self:HideEffects() end
end
function U:ShowPanel(kind)
 for name,list in pairs(self.groups) do
  local on=kind~=nil and (name=='common' or name==kind)
  for _,c in ipairs(list) do c:SetHidden(not on) end
 end
 -- the picture of the panel carries its own edge
 if self.hudRich then self.panelEdge:SetHidden(true) end
 self.panelKind=kind
end
function U:SetBars(values)
 for i,bar in ipairs(self.bars) do bar.fill:SetDimensions(max(1,floor(360*C.clamp(values[i],0,1))),18) end
end
-- Big centred text that rises and fades: the countdown, "GO!", lap calls.
-- The size is a font, not a scale: a scaled label grows from its top-left corner, which would
-- push centred text off the right of the picture.
function U:Banner(text,seconds,size)
 self.bannerText,self.bannerAt,self.bannerFor=text,GetFrameTimeSeconds(),seconds or 1.2
 local b=self.text.banner
 b:SetFont('ZoFontGamepad'..((size or 2)>=2.5 and 61 or ((size or 2)>=2 and 54 or 42)))
 b:SetText(text);b:SetAlpha(0);b:SetHidden(false)
end
function U:TickBanner(now)
 if not self.bannerAt then return end
 local at=(now-self.bannerAt)/self.bannerFor
 local b=self.text.banner
 if at>=1 then self.bannerAt=nil;b:SetHidden(true);return end
 b:SetAlpha(min(1,at*10)*min(1,(1-at)*3))
end
-- A knock: the whole picture is jolted and settles.
function U:Shake(amount) self.shake=max(self.shake or 0,amount) end
function U:TickShake(dt)
 if not self.content then return end
 local s=self.shake or 0
 if s<=.3 then if self.shaking then self.content:SetAnchor(CENTER,self.root,CENTER,0,0);self.shaking=false end;self.shake=0;return end
 self.shaking=true
 self.content:SetAnchor(CENTER,self.root,CENTER,(math.random()-.5)*s,(math.random()-.5)*s)
 self.shake=s*math.exp(-9*dt)
end
-- Darkens the screen, runs `after` at full black, then lifts. Nothing of the game runs in
-- between: Playable needs the scene, and the scene is only shown by `after`.
function U:Fade(after)
 self.fade={phase='in',elapsed=0,after=after}
 self.curtain:SetAlpha(0);self.curtain:SetHidden(false)
end
function U:CancelFade() if self.fade then self.fade.after=nil end end
function U:Tick(dt)
 local fade=self.fade
 if not fade then return end
 fade.elapsed=fade.elapsed+min(.1,max(0,dt))
 if fade.phase=='in' then
  local alpha=min(1,fade.elapsed/FADE_IN);self.curtain:SetAlpha(alpha)
  if alpha>=1 then
   local after=fade.after
   fade.phase,fade.elapsed,fade.after=after and 'hold' or 'out',0,nil
   if after then self.sceneShown=false;after() end
  end
 elseif fade.phase=='hold' then
  if (self.sceneShown and fade.elapsed>=HOLD_MIN) or fade.elapsed>=HOLD_MAX then fade.phase,fade.elapsed='out',0 end
 else
  local alpha=1-fade.elapsed/FADE_OUT
  if alpha<=0 then self.curtain:SetAlpha(0);self.curtain:SetHidden(true);self.fade=nil
  else self.curtain:SetAlpha(alpha) end
 end
end
function U:UpdateKeybinds()
 if self.scene:IsShowing() then KEYBIND_STRIP:UpdateKeybindButtonGroup(self.keybinds) end
end
