PBF=PBF or {}
local C=PBF.Core
local V={};V.__index=V;PBF.View=V
local floor,ceil,min,max,abs,cos,sin,sqrt=math.floor,math.ceil,math.min,math.max,math.abs,math.cos,math.sin,math.sqrt
-- This is a Mode 7 style floor: every ground feature is a flat polygon, a horizontal line of the
-- screen hits the ground at one depth, and so each band of rows is the sum of where that line
-- crosses each polygon. The result is a short list of rectangles, which is the only thing the
-- engine's UI can draw quickly. This file is pure arithmetic (no controls), so the same code can
-- be run offline and rasterised to a picture.
--
-- Two modes share the geometry. "rich" lays one picture of the road's cross-section over each
-- crossing (the barrier, the glow, the lit edge, the chequered lanes are all in the picture) and
-- draws machines, posts and the start gantry as sprites. "flat" paints the same road out of plain
-- coloured rectangles and draws machines as eight rectangles each; it is what the game falls back
-- to if the pictures cannot be loaded.
--
-- Inside a band a layer owns a fixed run of slots, so a rectangle keeps the same control from
-- frame to frame and only its position, colour and picture window change.
V.FLAT_LAYERS={{'wallL',2},{'road',3},{'wallR',2},{'mark',5}}
V.RICH_LAYERS={{'road',3},{'mark',5},{'void',1}}
local CAP=8          -- intervals kept per layer per band before the extras are dropped
V.SPRITE_PARTS=8     -- flat mode: rectangles per machine
V.MAX_SPRITES=10
V.WORLD_SLOTS=64     -- rich mode: machines, shadows, posts, the gantry
V.GLOW_SLOTS=16      -- rich mode: additive thruster glows
-- A machine's picture is 7.1 x 4.44 m, and the underside of the craft sits 72% of the way down it.
V.CELL_M_W,V.CELL_M_H,V.FOOT=7.1,4.44,.72
V.NOZZLE_X,V.NOZZLE_Y=1.5,.64    -- thruster centres, metres from the middle / fraction down the cell
local WALL_FLAT=1.7  -- width of the barrier strip outside the road in flat mode, metres
V.Themes={
 default={road={{.17,.2,.31},{.21,.24,.37}},wall={{.95,.26,.36},{.93,.95,1}},fog={.5,.33,.58},void={.035,.04,.08},
  skyTop={.03,.03,.11},skyLow={.55,.34,.62},skyline={.07,.06,.14},neon={.35,.85,1},pylons={'pylon_cyan','pylon_pink'}},
 vivec={road={{.17,.2,.31},{.21,.24,.37}},wall={{.95,.26,.36},{.93,.95,1}},fog={.52,.33,.58},void={.04,.035,.085},
  skyTop={.04,.03,.12},skyLow={.62,.34,.6},skyline={.08,.06,.15},neon={.35,.85,1},pylons={'pylon_cyan','pylon_pink'}},
 bruma={road={{.18,.23,.32},{.23,.29,.4}},wall={{.3,.75,1},{.92,.97,1}},fog={.45,.58,.72},void={.04,.06,.1},
  skyTop={.04,.07,.16},skyLow={.62,.78,.92},skyline={.1,.14,.22},neon={.6,1,1},pylons={'pylon_cyan','pylon_cyan'}},
 solitude={road={{.17,.24,.22},{.21,.3,.27}},wall={{1,.7,.25},{.96,.96,.9}},fog={.45,.62,.55},void={.03,.07,.06},
  skyTop={.03,.08,.1},skyLow={.62,.82,.7},skyline={.06,.13,.12},neon={1,.85,.4},pylons={'pylon_amber','pylon_green'}},
}
local function mix(a,b,t) return a+(b-a)*t end
function V.New(cfg)
 cfg=cfg or {}
 local self=setmetatable({},V)
 self.W,self.H=cfg.W or 1280,cfg.H or 720
 self.hy=cfg.horizon or 250
 self.f=cfg.focal or 834
 self.camH=cfg.camHeight or 4.5
 self.camBack=cfg.camBack or 14
 self.maxZ=cfg.maxZ or 700
 self.ahead=cfg.ahead or 118
 self.theme=V.Themes.default
 self.themeName='default'
 self.wantRich=cfg.rich~=false
 self.cam={x=0,y=0,h=0,idx=1,bank=0,odo=0}
 self.o={n=0,slot={},x={},y={},w={},h={},r={},g={},b={},a={},u0={},u1={},v0={},v1={}}
 self.uv={}
 self.band=cfg.band or 6
 self:Refresh()
 return self
end
-- Rebuilds everything that depends on the mode, the theme or the band height.
function V:Refresh()
 local A=PBF.Atlas
 self.atlas=A
 self.tinfo=A and A.themes and A.themes[self.themeName] or nil
 self.rich=self.wantRich and A~=nil and self.tinfo~=nil
 self.layers=self.rich and V.RICH_LAYERS or V.FLAT_LAYERS
 self.nLayer=#self.layers
 self.layerAt,self.layerBase={}, {}
 local spb=0
 for i,l in ipairs(self.layers) do self.layerAt[l[1]]=i;self.layerBase[i]=spb;spb=spb+l[2] end
 self.spb=spb
 V.SLOTS_PER_BAND=spb
 self.wall=self.rich and A.WALL or WALL_FLAT
 self.rim=self.rich and A.RIM or 0
 self.nb=floor((self.H-self.hy)/self.band)
 self.uv={}
 self.whiteUV=nil
 self:BuildBands()
end
function V:SetRich(on) self.wantRich=on and true or false;self:Refresh() end
function V:SetTheme(name)
 self.themeName=V.Themes[name] and name or 'default'
 self.theme=V.Themes[self.themeName]
 self:Refresh()
end
function V:SetBand(px) self.band=px;self:Refresh() end
-- Per-band constants: the depth the band's rows land at, how much haze lies over it, and the
-- colours the road and barrier take there. Stripes fade out with distance on purpose: past a
-- couple of hundred metres a stripe is narrower than a band and would only shimmer.
function V:BuildBands()
 local K=self.f*self.camH
 self.K=K
 self.bandZ,self.bandFog,self.bandScale,self.bandRoad,self.bandWall,self.bandVoid,self.bandDZ={}, {}, {}, {}, {}, {}, {}
 self.voidAlt={}
 local th=self.theme;local fog=th.fog
 for b=0,self.nb-1 do
  local yMid=self.hy+(b+.5)*self.band
  local z=K/(yMid-self.hy)
  self.bandZ[b]=z;self.bandScale[b]=self.f/z
  self.bandDZ[b]=K/max(1,b*self.band)-K/((b+1)*self.band)
  local fk=min(.92,(z/560)^1.25)
  self.bandFog[b]=fk
  local contrast=C.clamp(1-z/260,0,1)
  local function tint(c,k)
   return {mix(c[1],fog[1],k),mix(c[2],fog[2],k),mix(c[3],fog[3],k)}
  end
  local function stripe(a,bc)
   local avg={(a[1]+bc[1])/2,(a[2]+bc[2])/2,(a[3]+bc[3])/2}
   local ca={mix(avg[1],a[1],contrast),mix(avg[2],a[2],contrast),mix(avg[3],a[3],contrast)}
   local cb={mix(avg[1],bc[1],contrast),mix(avg[2],bc[2],contrast),mix(avg[3],bc[3],contrast)}
   return tint(ca,fk),tint(cb,fk)
  end
  local r0,r1=stripe(th.road[1],th.road[2]);local w0,w1=stripe(th.wall[1],th.wall[2])
  self.bandRoad[b]={r0,r1};self.bandWall[b]={w0,w1}
  self.bandVoid[b]=tint(th.void,fk)
  -- the lighter stripe of the ground outside the road, which scrolls with the machine
  local alt={th.void[1]*1.55+.012,th.void[2]*1.55+.012,th.void[3]*1.55+.016}
  self.voidAlt[b]=tint(alt,fk)
 end
end
-- The camera sits behind and above the machine and its heading chases the machine's, so a
-- slide shows as the nose pointing across the road.
function V:Follow(m,dt,snap)
 local cam=self.cam
 local want=m.h
 if m.speed>12 then
  local vh=C.atan2(m.vy,m.vx)
  want=m.h+C.wrapAngle(vh-m.h)*.35
 end
 if snap then cam.h=want else
  local k=1-math.exp(-7*dt)
  cam.h=cam.h+C.wrapAngle(want-cam.h)*k
 end
 local tx,ty=m.x-cos(cam.h)*self.camBack,m.y-sin(cam.h)*self.camBack
 if snap then cam.x,cam.y=tx,ty else
  local k=1-math.exp(-16*dt)
  cam.x=cam.x+(tx-cam.x)*k;cam.y=cam.y+(ty-cam.y)*k
  cam.odo=cam.odo+m.speed*dt
 end
 cam.idx=m.idx;cam.s=m.s
end
-- Picture window of a cell in a sheet, inset by half a texel so a neighbour never bleeds in.
function V:CellUV(sheet,name)
 local key=sheet.file..name
 local uv=self.uv[key]
 if uv then return uv end
 local c=sheet.cells[name]
 uv={u0=(c.x+.5)/sheet.w,u1=(c.x+c.w-.5)/sheet.w,v0=(c.y+.5)/sheet.h,v1=(c.y+c.h-.5)/sheet.h,w=c.w,h=c.h}
 self.uv[key]=uv
 return uv
end
-- ---------------------------------------------------------------------------------------
-- Interval pool: for every (band, layer) a few runs of one rectangle each.
local pool={cnt={},xa={},xb={},r={},g={},b={},a={},u0={},u1={},v0={},v1={},id={}}
local FIELDS={pool.xa,pool.xb,pool.r,pool.g,pool.b,pool.a,pool.u0,pool.u1,pool.v0,pool.v1,pool.id}
local S={}                  -- one crossing: x at each end, with the picture coordinates there
local qx,qz,qu,qt={}, {}, {}, {}
local function crossing(z,x1,z1,x2,z2,lo,hi)
 if (z1<=z and z2>z) or (z2<=z and z1>z) then
  local x=x1+(x2-x1)*(z-z1)/(z2-z1)
  if not lo or x<lo then lo=x end
  if not hi or x>hi then hi=x end
 end
 return lo,hi
end
local function crossUV(i,j,z)
 local z1,z2=qz[i],qz[j]
 if (z1<=z and z2>z) or (z2<=z and z1>z) then
  local k=(z-z1)/(z2-z1)
  local x=qx[i]+(qx[j]-qx[i])*k
  if not S.lo or x<S.lo then S.lo,S.ulo,S.tlo=x,qu[i]+(qu[j]-qu[i])*k,qt[i]+(qt[j]-qt[i])*k end
  if not S.hi or x>S.hi then S.hi,S.uhi,S.thi=x,qu[i]+(qu[j]-qu[i])*k,qt[i]+(qt[j]-qt[i])*k end
 end
end
local function addInterval(key,xa,xb,r,g,b,a,u0,u1,v0,v1,id)
 local n=pool.cnt[key]
 if n>=CAP then return end
 n=n+1;pool.cnt[key]=n
 local at=key*CAP+n
 pool.xa[at],pool.xb[at],pool.r[at],pool.g[at],pool.b[at],pool.a[at]=xa,xb,r,g,b,a
 pool.u0[at],pool.u1[at],pool.v0[at],pool.v1[at],pool.id[at]=u0,u1,v0,v1,id
end
-- Fills bands for the quad with corners (x1,z1)..(x4,z4), in camera space (x to the right, z
-- ahead), painting it `layer` in a flat colour. Flat mode only.
local function fillQuad(self,layer,x1,z1,x2,z2,x3,z3,x4,z4,r,g,b,rowColors,par)
 local zmin=min(min(z1,z2),min(z3,z4));local zmax=max(max(z1,z2),max(z3,z4))
 local nb=self.nb
 if zmax<=0 then return end
 local K,band=self.K,self.band
 local b0=ceil(K/(min(zmax,self.maxZ)*band)-.5);local b1=floor(K/(max(zmin,.01)*band)-.5)
 if b0<0 then b0=0 end
 if b1>nb-1 then b1=nb-1 end
 local nl=self.nLayer
 for row=b0,b1 do
  local z=self.bandZ[row]
  if z>=zmin and z<=zmax then
   local lo,hi
   lo,hi=crossing(z,x1,z1,x2,z2,lo,hi);lo,hi=crossing(z,x2,z2,x3,z3,lo,hi)
   lo,hi=crossing(z,x3,z3,x4,z4,lo,hi);lo,hi=crossing(z,x4,z4,x1,z1,lo,hi)
   if lo and hi then
    local sc=self.bandScale[row];local cr,cg,cb
    if rowColors then local c=rowColors[row][par];cr,cg,cb=c[1],c[2],c[3]
    else
     local fk=self.bandFog[row];local fog=self.theme.fog
     cr,cg,cb=mix(r,fog[1],fk),mix(g,fog[2],fk),mix(b,fog[3],fk)
    end
    addInterval(row*nl+layer-1,self.W/2+lo*sc,self.W/2+hi*sc,cr,cg,cb,1,0,0,0,0,0)
   end
  end
 end
end
-- Rich mode: the quad in qx/qz (camera space) carries picture coordinates in qu/qt. `road` means
-- the picture is the road's cross-section, whose window is picked by `variant`; otherwise `cell`
-- is the uv table of a plate in the world atlas. The crossing keeps the picture coordinate at
-- each end of the run, so a road seen at an angle is stretched and flipped correctly.
local function fillUV(self,layer,road,variant,cell,tr,tg,tb,dtdz)
 local zmin=min(min(qz[1],qz[2]),min(qz[3],qz[4]));local zmax=max(max(qz[1],qz[2]),max(qz[3],qz[4]))
 local nb=self.nb
 if zmax<=0 then return end
 local K,band=self.K,self.band
 local b0=ceil(K/(min(zmax,self.maxZ)*band)-.5);local b1=floor(K/(max(zmin,.01)*band)-.5)
 if b0<0 then b0=0 end
 if b1>nb-1 then b1=nb-1 end
 local nl=self.nLayer
 local ti=self.tinfo
 local vc,vh,u0a,u1a
 if road then
  vc=(variant*ti.strip+ti.strip*.5)/ti.roadH;vh=.25/ti.roadH
  u0a,u1a=.5/ti.roadW,1-.5/ti.roadW
 end
 for row=b0,b1 do
  local z=self.bandZ[row]
  if z>=zmin and z<=zmax then
   S.lo,S.hi=nil,nil
   crossUV(1,2,z);crossUV(2,3,z);crossUV(3,4,z);crossUV(4,1,z)
   if S.lo and S.hi and S.hi>S.lo then
    local sc=self.bandScale[row]
    local alpha=1-self.bandFog[row]*.95
    local ua,ub,va,vb
    if road then
     ua,ub=u0a+S.ulo*(u1a-u0a),u0a+S.uhi*(u1a-u0a)
     va,vb=vc-vh,vc+vh
    else
     local tm=(S.tlo+S.thi)*.5
     local dt=abs(dtdz)*self.bandDZ[row]*.5
     local vtop,vbot=1-(tm+dt),1-(tm-dt)
     if vtop<0 then vtop=0 end;if vbot>1 then vbot=1 end;if vbot<vtop then vbot=vtop end
     ua,ub=cell.u0+C.clamp(S.ulo,0,1)*(cell.u1-cell.u0),cell.u0+C.clamp(S.uhi,0,1)*(cell.u1-cell.u0)
     va,vb=cell.v0+vtop*(cell.v1-cell.v0),cell.v0+vbot*(cell.v1-cell.v0)
    end
    addInterval(row*nl+layer-1,self.W/2+S.lo*sc,self.W/2+S.hi*sc,tr,tg,tb,alpha,ua,ub,va,vb,variant)
   end
  end
 end
end
-- Merges one layer's intervals in one band into at most `slots` runs, sorted by x. Touching runs
-- that continue each other (same picture, same colour, picture coordinate carries on) join; if
-- there are still too many, the closest pair is joined whatever it is, which only ever costs a
-- stripe in a hairpin.
local function move(to,from) for _,arr in ipairs(FIELDS) do arr[to]=arr[from] end end
local function settle(key,slots)
 local n=pool.cnt[key];if n==0 then return 0 end
 local base=key*CAP
 local xa=pool.xa
 for i=2,n do
  -- insertion sort on xa; slot 0 of the key is free (entries are 1..CAP) and serves as scratch
  move(base,base+i)
  local j=i-1
  while j>=1 and xa[base+j]>xa[base] do move(base+j+1,base+j);j=j-1 end
  move(base+j+1,base)
 end
 local m=1
 for i=2,n do
  local at=base+m;local nx=base+i
  local near=abs(pool.r[nx]-pool.r[at])<1e-4 and abs(pool.g[nx]-pool.g[at])<1e-4 and abs(pool.b[nx]-pool.b[at])<1e-4 and abs(pool.a[nx]-pool.a[at])<.02
  local carries=pool.id[nx]==pool.id[at] and abs(pool.u0[nx]-pool.u1[at])<.004 and abs(pool.v0[nx]-pool.v0[at])<.02
  if xa[nx]<=pool.xb[at]+1.5 and near and carries then
   if pool.xb[nx]>pool.xb[at] then pool.xb[at]=pool.xb[nx];pool.u1[at]=pool.u1[nx] end
  else m=m+1;move(base+m,nx) end
 end
 while m>slots do
  local best,bi=1e9,1
  for i=1,m-1 do
   local gap=xa[base+i+1]-pool.xb[base+i]
   if gap<best then best,bi=gap,i end
  end
  if pool.xb[base+bi+1]>pool.xb[base+bi] then pool.xb[base+bi]=pool.xb[base+bi+1];pool.u1[base+bi]=pool.u1[base+bi+1] end
  for i=bi+1,m-1 do move(base+i,base+i+1) end
  m=m-1
 end
 return m
end
local function push(o,slot,x,y,w,h,r,g,b,a,u0,u1,v0,v1)
 local n=o.n+1;o.n=n
 o.slot[n],o.x[n],o.y[n],o.w[n],o.h[n],o.r[n],o.g[n],o.b[n],o.a[n]=slot,x,y,w,h,r,g,b,a
 o.u0[n],o.u1[n],o.v0[n],o.v1[n]=u0,u1,v0,v1
end
-- Scratch space reused every frame: the renderer runs thirty times a second and the garbage a
-- fresh set of tables would leave is memory the console has to collect while the race runs.
local tcx,tcz,trcx,trcz,twd={}, {}, {}, {}, {}
local G={cx=0,cy=0,fx=0,fy=0,rx=0,ry=0}
local function cam2(x,y) local dx,dy=x-G.cx,y-G.cy;return dx*G.rx+dy*G.ry,dx*G.fx+dy*G.fy end
-- Paints the decals whose s lies in [lo,hi]. Point() wraps s, so a window that runs past the
-- start line needs no special casing here.
local function paintDecals(self,track,list,lo,hi)
 local rich=self.rich
 local ids=self.layerAt.mark
 local world=rich and self.atlas.world
 local white=rich and self:CellUV(world,'white')
 local neon=self.theme.neon
 for _,dc in ipairs(list) do
  if dc.s0>hi then break end
  if dc.s1>=lo then
   local x1,y1=track:Point(dc.s0,dc.d0);local x2,y2=track:Point(dc.s1,dc.d0)
   local x3,y3=track:Point(dc.s1,dc.d1);local x4,y4=track:Point(dc.s0,dc.d1)
   local a1,b1=cam2(x1,y1);local a2,b2=cam2(x2,y2);local a3,b3=cam2(x3,y3);local a4,b4=cam2(x4,y4)
   if not rich then
    fillQuad(self,ids,a1,b1,a2,b2,a3,b3,a4,b4,dc.r,dc.g,dc.b)
   else
    qx[1],qz[1],qx[2],qz[2],qx[3],qz[3],qx[4],qz[4]=a1,b1,a2,b2,a3,b3,a4,b4
    if dc.cell then
     -- (u,t): u across the plate, t along it; vertex order matches the quad above
     qu[1],qt[1],qu[2],qt[2],qu[3],qt[3],qu[4],qt[4]=0,0,0,1,1,1,1,0
     local cell=self:CellUV(world,dc.cell)
     local dz=abs(b2-b1);if dz<.05 then dz=abs(b3-b4) end
     local tr,tg,tb=1,1,1
     if dc.tint=='neon' then tr,tg,tb=neon[1],neon[2],neon[3] end
     fillUV(self,ids,false,0,cell,tr,tg,tb,1/max(.05,dz))
    else
     qu[1],qt[1],qu[2],qt[2],qu[3],qt[3],qu[4],qt[4]=0,0,0,0,0,0,0,0
     local cu,cv=(white.u0+white.u1)*.5,(white.v0+white.v1)*.5
     local cell={u0=cu,u1=cu,v0=cv,v1=cv}
     fillUV(self,ids,false,0,cell,dc.r,dc.g,dc.b,0)
    end
   end
  end
 end
end
-- Builds the rectangle list for the ground, from the camera in `self.cam`.
function V:Ground(track)
 local cam=self.cam;local nb=self.nb;local nl=self.nLayer
 for k=0,nb*nl-1 do pool.cnt[k]=0 end
 local fx,fy=cos(cam.h),sin(cam.h);local rx,ry=fy,-fx
 local n=track.n
 local NS=self.ahead
 local i0=cam.idx-6
 -- Camera-space centre and right vector of every sample in view.
 local cx,cz,rcx,rcz,wd=tcx,tcz,trcx,trcz,twd
 for j=0,NS do
  local i=(i0+j-1)%n+1
  local dx,dy=track.x[i]-cam.x,track.y[i]-cam.y
  cx[j]=dx*rx+dy*ry;cz[j]=dx*fx+dy*fy
  rcx[j]=track.rx[i]*rx+track.ry[i]*ry;rcz[j]=track.rx[i]*fx+track.ry[i]*fy
  wd[j]=track.w[i]
 end
 local WALL,RIM=self.wall,self.rim
 if self.rich then
  local roadL=self.layerAt.road
  local chase=self.chase or 0
  for j=0,NS-1 do
   local i=(i0+j-1)%n+1
   local a,b=j,j+1
   if cz[a]>-60 or cz[b]>-60 then
    local da,db=wd[a]+WALL+RIM,wd[b]+WALL+RIM
    qx[1],qz[1]=cx[a]-rcx[a]*da,cz[a]-rcz[a]*da
    qx[2],qz[2]=cx[b]-rcx[b]*db,cz[b]-rcz[b]*db
    qx[3],qz[3]=cx[b]+rcx[b]*db,cz[b]+rcz[b]*db
    qx[4],qz[4]=cx[a]+rcx[a]*da,cz[a]+rcz[a]*da
    qu[1],qt[1],qu[2],qt[2],qu[3],qt[3],qu[4],qt[4]=0,0,0,0,1,0,1,0
    -- stripe along the lap, barrier stripe, and a running light that creeps with the clock
    local variant=(floor((i-1)/2)%2)+((i-1)%2)*2+((i+chase)%4)*4
    fillUV(self,roadL,true,variant,nil,1,1,1,0)
   end
  end
 else
  local WL,RD,WR=self.layerAt.wallL,self.layerAt.road,self.layerAt.wallR
  local roadCols,wallCols=self.bandRoad,self.bandWall
  for j=0,NS-1 do
   local i=(i0+j-1)%n+1
   local a,b=j,j+1
   if cz[a]>-60 or cz[b]>-60 then
    local wa,wb=wd[a],wd[b]
    local rp=floor((i-1)/2)%2+1;local wp=(i-1)%2+1
    fillQuad(self,RD,cx[a]-rcx[a]*wa,cz[a]-rcz[a]*wa,cx[b]-rcx[b]*wb,cz[b]-rcz[b]*wb,cx[b]+rcx[b]*wb,cz[b]+rcz[b]*wb,cx[a]+rcx[a]*wa,cz[a]+rcz[a]*wa,0,0,0,roadCols,rp)
    fillQuad(self,WL,cx[a]-rcx[a]*(wa+WALL),cz[a]-rcz[a]*(wa+WALL),cx[b]-rcx[b]*(wb+WALL),cz[b]-rcz[b]*(wb+WALL),cx[b]-rcx[b]*wb,cz[b]-rcz[b]*wb,cx[a]-rcx[a]*wa,cz[a]-rcz[a]*wa,0,0,0,wallCols,wp)
    fillQuad(self,WR,cx[a]+rcx[a]*wa,cz[a]+rcz[a]*wa,cx[b]+rcx[b]*wb,cz[b]+rcz[b]*wb,cx[b]+rcx[b]*(wb+WALL),cz[b]+rcz[b]*(wb+WALL),cx[a]+rcx[a]*(wa+WALL),cz[a]+rcz[a]*(wa+WALL),0,0,0,wallCols,wp)
   end
  end
 end
 -- Decals: the dashes, the grid, the arrows and the zone plates.
 G.cx,G.cy,G.fx,G.fy,G.rx,G.ry=cam.x,cam.y,fx,fy,rx,ry
 local L=track.length
 local sA=cam.s-18;local sB=cam.s+self.maxZ*1.02
 local list=self.rich and track.decalsRich or track.decals
 if sA<0 then paintDecals(self,track,list,sA+L,L) end
 paintDecals(self,track,list,max(sA,0),min(sB,L))
 if sB>L then paintDecals(self,track,list,0,sB-L) end
 -- Emit.
 local o=self.o;o.n=0
 local W=self.W
 local rich=self.rich
 for row=0,nb-1 do
  local y=self.hy+row*self.band
  for layer=1,nl do
   local layerDef=self.layers[layer]
   if layerDef[1]~='void' then
    local key=row*nl+layer-1
    local m=settle(key,layerDef[2])
    local base=key*CAP
    for q=1,m do
     local xa,xb=pool.xa[base+q],pool.xb[base+q]
     local u0,u1=pool.u0[base+q],pool.u1[base+q]
     if rich then
      local span=xb-xa
      if span>0 then
       local du=pool.u1[base+q]-pool.u0[base+q]
       if xa<0 then u0=pool.u0[base+q]+(0-xa)/span*du end
       if xb>W then u1=pool.u0[base+q]+(W-xa)/span*du end
      end
     end
     if xa<0 then xa=0 end
     if xb>W then xb=W end
     if xb-xa>=.5 then push(o,row*self.spb+self.layerBase[layer]+q-1,xa,y,xb-xa,self.band+.5,pool.r[base+q],pool.g[base+q],pool.b[base+q],pool.a[base+q],u0,u1,pool.v0[base+q],pool.v1[base+q]) end
    end
   end
  end
  if rich then
   -- The ground outside the road: two tones that slide towards the camera as the machine moves.
   local z=self.bandZ[row]
   local par=floor((z+cam.odo)/26)%2
   local c=par==0 and self.bandVoid[row] or self.voidAlt[row]
   local white=self.whiteUV
   if not white then white=self:CellUV(self.atlas.world,'white');self.whiteUV=white end
   local cu,cv=(white.u0+white.u1)*.5,(white.v0+white.v1)*.5
   push(o,row*self.spb+self.layerBase[self.layerAt.void],0,y,W,self.band+1,c[1],c[2],c[3],1,cu,cu,cv,cv)
  end
 end
 return o.n
end
-- ---------------------------------------------------------------------------------------
-- Flat mode machines. Each is a handful of rectangles seen from behind: shadow, two pods, body,
-- canopy, fin and the glow of the thrusters. Parts are listed in the order they must be painted.
local PARTS={
 -- u0,u1,v0,v1,colour key
 {-1.55,1.55,-.12,.18,'shadow'},
 {-1.85,-.95,.12,.78,'wing'},{.95,1.85,.12,.78,'wing'},
 {-1.15,1.15,.2,1.0,'body'},
 {-.55,.55,.95,1.4,'top2'},
 {-.14,.14,1.0,1.85,'wing'},
 {-.95,-.35,.3,.72,'glow'},{.35,.95,.3,.72,'glow'},
}
local SHADOW={0,0,0}
local function sortFar(a,b) return a.z>b.z end
local entries={}
local sprites={}
-- Projects every machine and appends its rectangles. Farthest first, so a nearer one is
-- always later in slot order and therefore on top.
function V:Sprites(race)
 local cam=self.cam;local fx,fy=cos(cam.h),sin(cam.h);local rx,ry=fy,-fx
 local o=self.o;local list=sprites
 local count0=#list
 local n=0
 for _,m in ipairs(race.machines) do
  local dx,dy=m.x-cam.x,m.y-cam.y
  local z=dx*fx+dy*fy
  if z>1.5 and z<self.maxZ*.9 then
   n=n+1;local e=entries[n];if not e then e={};entries[n]=e end
   e.m,e.z,e.x=m,z,dx*rx+dy*ry;list[n]=e
  end
 end
 for i=n+1,count0 do list[i]=nil end
 table.sort(list,sortFar)
 local W=self.W;local count=0
 local base0=self.nb*self.spb
 for q,e in ipairs(list) do
  if q>V.MAX_SPRITES then break end
  local m=e.m;local k=self.f/e.z
  local sx=W/2+e.x*k;local sy=self.hy+self.camH*k
  local st=m.type
  local fogK=min(.7,(e.z/700)^1.4);local fog=self.theme.fog
  local flick=1
  if m.boosting then flick=1.6 elseif m.pad and m.pad>0 then flick=1.3 end
  local gscale=(m.speed>5 and 1 or .5)*flick
  local base=base0+(q-1)*V.SPRITE_PARTS
  for p,part in ipairs(PARTS) do
   local key=part[5];local col
   if key=='shadow' then col=SHADOW
   elseif key=='glow' then col=st.glow else col=st[key] or st.body end
   local r,g,b=col[1],col[2],col[3]
   if m.wrecked then r,g,b=r*.3,g*.3,b*.3 end
   r,g,b=mix(r,fog[1],fogK),mix(g,fog[2],fogK),mix(b,fog[3],fogK)
   local u0,u1,v0,v1=part[1],part[2],part[3],part[4]
   if key=='glow' then u0,u1=u0*gscale,u1*gscale;v1=v1+(gscale-1)*.15 end
   local lean=m.bank*.35
   local x0=sx+(u0+lean*(v0))*k;local x1=sx+(u1+lean*(v1))*k
   local y0=sy-v1*k;local y1=sy-v0*k
   local a=key=='shadow' and .4*(1-fogK) or 1
   if m.exploded or (m.wrecked and p>1) then a=.65 end
   push(o,base+p-1,x0,y0,max(1,x1-x0),max(1,y1-y0),r,g,b,a,0,0,0,0)
  end
  count=count+1
 end
 return count
end
-- ---------------------------------------------------------------------------------------
-- Rich mode: machines, shadows, posts and the start gantry, all sprites of the world atlas,
-- sorted far to near so that slot order is paint order.
local world={}
local worldN=0
local function addWorld(z,x,yTop,w,h,r,g,b,a,u0,u1,v0,v1,part)
 worldN=worldN+1
 local e=world[worldN];if not e then e={};world[worldN]=e end
 e.z,e.x,e.y,e.w,e.h,e.r,e.g,e.b,e.a,e.u0,e.u1,e.v0,e.v1,e.part=z,x,yTop,w,h,r,g,b,a,u0,u1,v0,v1,part
end
local function sortWorld(a,b)
 if a.z~=b.z then return a.z>b.z end
 return a.part<b.part
end
local glows={}
local glowN=0
local function addGlow(z,x,y,size,r,g,b,a)
 glowN=glowN+1
 local e=glows[glowN];if not e then e={};glows[glowN]=e end
 e.z,e.x,e.y,e.size,e.r,e.g,e.b,e.a=z,x,y,size,r,g,b,a
end
local function sortGlow(a,b) return a.z>b.z end
local BOOM_FRAME=.11
function V:WorldSprites(race,track)
 local cam=self.cam;local fx,fy=cos(cam.h),sin(cam.h);local rx,ry=fy,-fx
 local W=self.W;local f=self.f
 local o=self.o
 local A=self.atlas
 local world_=A.world
 worldN=0;glowN=0
 local time=race.time
 local shadowUV=self:CellUV(world_,'shadow')
 for _,m in ipairs(race.machines) do
  local dx,dy=m.x-cam.x,m.y-cam.y
  local z=dx*fx+dy*fy
  if z>1.5 and z<self.maxZ*.9 then
   local k=f/z
   local sx=W/2+(dx*rx+dy*ry)*k;local sy=self.hy+self.camH*k
   local fade=1-min(.75,(z/700)^1.4)
   local boom=m.wreckTime and (time-m.wreckTime) or nil
   if not boom or boom<.2 then
    local hover=.38+.12*sin(time*5+m.id*1.7)
    -- the shadow stays on the road; the craft floats above it
    local sh=shadowUV
    addWorld(z,sx-2.5*k,sy-.55*k,5.0*k,1.1*k,1,1,1,.62*fade,sh.u0,sh.u1,sh.v0,sh.v1,0)
    local idx=C.clamp(floor(m.bank*3+(m.bank>=0 and .5 or -.5))+4,1,7)
    local c=self:CellUV(world_,'m_'..m.type.id..'_'..idx)
    local w,h=V.CELL_M_W*k,V.CELL_M_H*k
    local shade=m.wrecked and .45 or 1
    addWorld(z,sx-w/2,sy-hover*k-V.FOOT*h,w,h,shade,shade,shade,fade,c.u0,c.u1,c.v0,c.v1,1)
    if not m.wrecked then
     local bank=m.bank*math.rad(24)
     local gs=1.7*(m.boosting and 2.1 or ((m.pad and m.pad>0) and 1.5 or (m.speed>5 and 1 or .45)))
     local gc=m.type.glow
     for s=-1,1,2 do
      local gx=sx+s*V.NOZZLE_X*cos(bank)*k
      -- the nozzles are NOZZLE_Y of the way down the picture; a banked craft has one lower
      local gy=sy-hover*k-(V.FOOT-V.NOZZLE_Y)*h+s*V.NOZZLE_X*sin(bank)*k
      addGlow(z,gx,gy,gs*k,gc[1],gc[2],gc[3],.85*fade)
     end
    end
   end
   if boom and boom>=0 and boom<BOOM_FRAME*8+.6 then
    local bc=self:CellUV(world_,'boom_'..min(7,floor(boom/BOOM_FRAME)))
    local bs=9*k
    addWorld(z-.01,sx-bs/2,sy-1.3*k-bs/2,bs,bs,1,1,1,1,bc.u0,bc.u1,bc.v0,bc.v1,2)
   end
  end
 end
 -- Posts along both edges every 36 m, and the start gantry.
 if track then
  local pylons=self.theme.pylons
  local n=track.n
  local i0=cam.idx-6
  local cx,cz,rcx,rcz,wd=tcx,tcz,trcx,trcz,twd
  for j=0,self.ahead do
   local i=(i0+j-1)%n+1
   local z=cz[j]
   if z>10 and z<self.maxZ*.78 then
    local side=wd[j]+self.wall+.9
    if (i-1)%6==0 then
     local cell=self:CellUV(world_,pylons[((i-1)/6)%2+1])
     for s=-1,1,2 do
      local px=cx[j]+s*rcx[j]*side
      local pz=cz[j]+s*rcz[j]*side
      if pz>6 then
       local kk=f/pz
       local w,h=1.9*kk,6.2*kk
       addWorld(pz,W/2+px*kk-w/2,self.hy+self.camH*kk-h,w,h,1,1,1,1-min(.85,(pz/560)^1.3),cell.u0,cell.u1,cell.v0,cell.v1,3)
      end
     end
    end
    if i==1 then
     local side2=wd[j]+self.wall+1.4
     local kk=f/z
     local post=self:CellUV(world_,'gantry_post');local beam=self:CellUV(world_,'gantry_beam')
     for s=-1,1,2 do
      local px=cx[j]+s*rcx[j]*side2
      local pz=cz[j]+s*rcz[j]*side2
      if pz>6 then
       local kp=f/pz
       local w,h=3.5*kp,9.2*kp
       addWorld(pz,W/2+px*kp-w/2,self.hy+self.camH*kp-h,w,h,1,1,1,1,post.u0,post.u1,post.v0,post.v1,3)
      end
     end
     local lx=cx[j]-rcx[j]*side2;local rxx=cx[j]+rcx[j]*side2
     addWorld(z,W/2+lx*kk,self.hy+(self.camH-9.4)*kk,(rxx-lx)*kk,3.4*kk,1,1,1,1,beam.u0,beam.u1,beam.v0,beam.v1,4)
    end
   end
  end
 end
 table.sort(world,sortWorld)
 for i=worldN+1,#world do world[i]=nil end
 table.sort(glows,sortGlow)
 for i=glowN+1,#glows do glows[i]=nil end
 local first=max(1,worldN-V.WORLD_SLOTS+1)
 local slot=self.nb*self.spb
 local gl=self:CellUV(world_,'glow')
 for q=first,worldN do
  local e=world[q]
  push(o,slot+(q-first),e.x,e.y,e.w,e.h,e.r,e.g,e.b,e.a,e.u0,e.u1,e.v0,e.v1)
 end
 local gslot=slot+V.WORLD_SLOTS
 local gfirst=max(1,glowN-V.GLOW_SLOTS+1)
 for q=gfirst,glowN do
  local e=glows[q]
  push(o,gslot+(q-gfirst),e.x-e.size/2,e.y-e.size/2,e.size,e.size,e.r,e.g,e.b,e.a,gl.u0,gl.u1,gl.v0,gl.v1)
 end
 return worldN
end
-- Rectangles that do not depend on the road: the sky in bands, and the haze and void below the
-- horizon. Flat mode only; rich mode has a sky picture and a void slot in every band.
function V:StaticRects()
 local th=self.theme;local list={}
 local bands=14
 for i=0,bands-1 do
  local t=i/(bands-1)
  local y0=floor(self.hy*i/bands);local y1=floor(self.hy*(i+1)/bands)
  local k=t^1.6
  list[#list+1]={x=0,y=y0,w=self.W,h=y1-y0+1,r=mix(th.skyTop[1],th.skyLow[1],k),g=mix(th.skyTop[2],th.skyLow[2],k),b=mix(th.skyTop[3],th.skyLow[3],k),a=1}
 end
 for row=0,self.nb-1 do
  local c=self.bandVoid[row]
  list[#list+1]={x=0,y=self.hy+row*self.band,w=self.W,h=self.band+1,r=c[1],g=c[2],b=c[3],a=1}
 end
 return list
end
-- Distant towers, in two layers, laid round a full turn so that steering visibly slides them.
-- Flat mode only (rich mode scrolls a picture instead).
function V:BuildSkyline(seed)
 local rng=C.Rng(seed or 11)
 local circ=2*math.pi*self.f
 self.skyline={}
 for layer=1,2 do
  local list={};local x=0
  while x<circ do
   local w=(layer==1 and 38 or 56)+rng()*(layer==1 and 60 or 90)
   local h=(layer==1 and 14 or 26)+rng()*(layer==1 and 46 or 84)
   list[#list+1]={x=x,w=w,h=h};x=x+w+rng()*(layer==1 and 14 or 30)
  end
  self.skyline[layer]=list
 end
 self.circ=circ
end
V.SKYLINE_RECTS=36
function V:Skyline(heading,out)
 if not self.skyline then self:BuildSkyline() end
 local th=self.theme;local n=0
 for layer=1,2 do
  local shift=heading*self.f*(layer==1 and 1 or .92)
  local c=th.skyline;local dark=layer==1 and 1.25 or 1
  local base=self.hy+1
  for _,b in ipairs(self.skyline[layer]) do
   local x=(b.x-shift)%self.circ
   if x>self.circ-b.w then x=x-self.circ end
   if x<self.W and x+b.w>0 then
    n=n+1;if n>V.SKYLINE_RECTS then return n-1 end
    local e=out[n];if not e then e={};out[n]=e end
    e.x,e.y,e.w,e.h=x,base-b.h,b.w,b.h
    e.r,e.g,e.b,e.a=c[1]*dark,c[2]*dark,c[3]*dark,1
   end
  end
 end
 return n
end
-- Scrolling sky for rich mode: the window of a 360 degree picture that the camera is looking at.
-- Fills up to two windows (the picture wraps) as {x,w,u0,u1} and returns how many.
function V:PanoWindows(heading,parallax,out)
 local du=self.W/(self.f*2*math.pi)
 local uL=(-(heading*parallax)/(2*math.pi)-du/2)%1
 local W=self.W
 if uL+du<=1 then
  local e=out[1] or {};out[1]=e
  e.x,e.w,e.u0,e.u1=0,W,uL,uL+du
  out[2]=nil;return 1
 end
 local first=(1-uL)/du*W
 local a=out[1] or {};out[1]=a
 a.x,a.w,a.u0,a.u1=0,first,uL,1
 local b=out[2] or {};out[2]=b
 b.x,b.w,b.u0,b.u1=first,W-first,0,uL+du-1
 return 2
end
function V:Frame(track,race)
 self.chase=floor(race.time*11)
 self:Ground(track)
 if self.rich then self:WorldSprites(race,track) else self:Sprites(race) end
 return self.o.n
end
-- Slot bookkeeping, shared by the renderer and the UI.
-- Ground slots come first (spb per band), then the sprites: in flat mode eight rectangles per
-- machine, in rich mode the sorted world sprites and then the additive glows.
function V:SlotCount()
 if self.rich then return self.nb*self.spb+V.WORLD_SLOTS+V.GLOW_SLOTS end
 return self.nb*self.spb+V.MAX_SPRITES*V.SPRITE_PARTS
end
-- What a slot is: 'road','mark','void','wall' (ground), 'world','glow' (rich sprites), 'sprite'.
function V:SlotKind(slot)
 local ground=self.nb*self.spb
 if slot<ground then
  local at=slot%self.spb
  for i=#self.layers,1,-1 do
   if at>=self.layerBase[i] then
    local name=self.layers[i][1]
    return (name=='wallL' or name=='wallR') and 'wall' or name
   end
  end
 end
 if not self.rich then return 'sprite' end
 return slot-ground<V.WORLD_SLOTS and 'world' or 'glow'
end
-- Where it sits in the draw order. Ground layers are low, in layer order, the void under all;
-- sprites above all of them, in the order they were sorted.
function V:SlotLevel(slot)
 local ground=self.nb*self.spb
 if slot<ground then
  local at=slot%self.spb
  if self.rich and at==self.layerBase[self.layerAt.void] then return 1 end
  return 2+at
 end
 if not self.rich then
  local q=floor((slot-ground)/V.SPRITE_PARTS);local p=(slot-ground)%V.SPRITE_PARTS
  return 20+q*10+p
 end
 local i=slot-ground
 if i<V.WORLD_SLOTS then return 20+i end
 return 100+(i-V.WORLD_SLOTS)
end
