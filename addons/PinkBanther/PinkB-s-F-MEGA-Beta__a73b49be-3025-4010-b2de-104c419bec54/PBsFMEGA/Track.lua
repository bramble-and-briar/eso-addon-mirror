PBF=PBF or {}
local C=PBF.Core
local T={};T.__index=T;PBF.Track=T
-- Metres between samples. Short enough that a straight segment stays straight on screen, long
-- enough that a 6 km lap is about a thousand entries.
T.STEP=6
local floor,sqrt,abs,cos,sin=math.floor,math.sqrt,math.abs,math.cos,math.sin
local function catmull(a,b,c,d,t)
 local t2,t3=t*t,t*t*t
 return .5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t2+(-a+3*b-3*c+d)*t3)
end
-- Lateral coordinate d is measured to the RIGHT of the direction of travel, the same side as the
-- camera's right vector, so a point at (s,d) is the centreline plus right*d with no sign flips
-- anywhere between the track and the screen.
-- `def.width` is the half width of the road: a number, or {{fraction,width},...} to pinch it.
function T.New(def)
 local self=setmetatable({def=def,name=def.name},T)
 local pts=def.points;local m=#pts
 -- `scale` lets a layout be drawn at any size and shrunk to what is drivable, without
 -- retyping its points.
 local sc=def.scale or 1
 local px,py={}, {}
 local SUB=24
 for i=1,m do
  local p0,p1,p2,p3=pts[(i-2)%m+1],pts[i],pts[i%m+1],pts[(i+1)%m+1]
  for k=0,SUB-1 do
   local t=k/SUB
   px[#px+1]=sc*catmull(p0[1],p1[1],p2[1],p3[1],t);py[#py+1]=sc*catmull(p0[2],p1[2],p2[2],p3[2],t)
  end
 end
 local dense=#px
 local cum={0}
 for i=1,dense do
  local j=i%dense+1;local dx,dy=px[j]-px[i],py[j]-py[i]
  cum[i+1]=cum[i]+sqrt(dx*dx+dy*dy)
 end
 local length=cum[dense+1]
 local n=math.max(16,floor(length/T.STEP+.5))
 local step=length/n
 self.n,self.step,self.length=n,step,n*step
 local x,y={}, {}
 local k=1
 for i=1,n do
  local target=(i-1)*step
  while cum[k+1]<target do k=k+1 end
  local a=(target-cum[k])/math.max(1e-9,cum[k+1]-cum[k]);local j=k%dense+1
  x[i]=px[k]+(px[j]-px[k])*a;y[i]=py[k]+(py[j]-py[k])*a
 end
 local tx,ty,rx,ry,curv,w={}, {}, {}, {}, {}, {}
 for i=1,n do
  local a,b=(i-2)%n+1,i%n+1
  local dx,dy=x[b]-x[a],y[b]-y[a];local l=sqrt(dx*dx+dy*dy)
  tx[i],ty[i]=dx/l,dy/l;rx[i],ry[i]=dy/l,-dx/l
 end
 local minRadius=1e9
 for i=1,n do
  local a,b=(i-2)%n+1,i%n+1
  local cross=tx[a]*ty[b]-ty[a]*tx[b];local dot=tx[a]*tx[b]+ty[a]*ty[b]
  curv[i]=C.atan2(cross,dot)/(2*step)
  if abs(curv[i])>1e-6 then minRadius=math.min(minRadius,1/abs(curv[i])) end
 end
 local widths=def.width
 for i=1,n do
  if type(widths)=='table' then
   local f=(i-1)/n;local lo,hi=widths[#widths],widths[1]
   for q=1,#widths do if widths[q][1]<=f then lo=widths[q];hi=widths[q+1] or {1+widths[1][1],widths[1][2]} end end
   local span=hi[1]-lo[1];local a=span>0 and (f-lo[1])/span or 0
   w[i]=lo[2]+(hi[2]-lo[2])*C.clamp(a,0,1)
  else w[i]=widths or 12 end
 end
 self.x,self.y,self.tx,self.ty,self.rx,self.ry,self.curv,self.w=x,y,tx,ty,rx,ry,curv,w
 self.minRadius=minRadius
 self.maxW=0;for i=1,n do self.maxW=math.max(self.maxW,w[i]) end
 self.zones={}
 for _,z in ipairs(def.zones or {}) do
  local s0=z.at*self.length
  self.zones[#self.zones+1]={kind=z.kind,s0=s0,s1=s0+z.len,d0=z.d-z.width/2,d1=z.d+z.width/2}
 end
 self:BuildDecals()
 return self
end
function T:Wrap(i) return (i-1)%self.n+1 end
function T:WrapS(s) return s-floor(s/self.length)*self.length end
-- Nearest sample to the point, searched around `hint` because a machine moves a few metres
-- between frames and a full scan of a thousand samples per machine per step is the one thing in
-- the physics loop that would show up. The scan only widens when the machine has been put
-- somewhere else entirely (the grid, a respawn).
function T:Locate(px,py,hint)
 local n=self.n;local x,y=self.x,self.y
 local best,bi=1e30,hint or 1
 if hint then
  for k=-10,10 do
   local i=(hint+k-1)%n+1;local dx,dy=px-x[i],py-y[i];local d2=dx*dx+dy*dy
   if d2<best then best,bi=d2,i end
  end
 end
 local far=(self.maxW*3)^2
 if not hint or best>far then
  best=1e30
  for i=1,n do
   local dx,dy=px-x[i],py-y[i];local d2=dx*dx+dy*dy
   if d2<best then best,bi=d2,i end
  end
 end
 local dx,dy=px-x[bi],py-y[bi]
 local along=dx*self.tx[bi]+dy*self.ty[bi]
 local side=dx*self.rx[bi]+dy*self.ry[bi]
 return self:WrapS((bi-1)*self.step+along),side,bi
end
function T:HalfWidth(s)
 local f=s/self.step;local i=floor(f);local a=f-i
 local w=self.w;return w[i%self.n+1]*(1-a)+w[(i+1)%self.n+1]*a
end
-- World position and heading of (s,d).
function T:Point(s,d)
 s=self:WrapS(s)
 local f=s/self.step;local i=floor(f);local a=f-i
 local n=self.n;local i0,i1=i%n+1,(i+1)%n+1
 local cx=self.x[i0]+(self.x[i1]-self.x[i0])*a;local cy=self.y[i0]+(self.y[i1]-self.y[i0])*a
 local tx=self.tx[i0]+(self.tx[i1]-self.tx[i0])*a;local ty=self.ty[i0]+(self.ty[i1]-self.ty[i0])*a
 local l=sqrt(tx*tx+ty*ty);tx,ty=tx/l,ty/l
 return cx+ty*d,cy-tx*d,C.atan2(ty,tx)
end
function T:ZoneAt(s,d)
 for _,z in ipairs(self.zones) do
  if s>=z.s0 and s<=z.s1 and d>=z.d0 and d<=z.d1 then return z.kind end
 end
end
local ZONE_COLORS={
 pad={.12,.42,.3},heal={.1,.5,.2},rough={.34,.22,.12},slip={.3,.62,.74},
}
-- Everything painted flat on the road: the centre dashes, the grid, and the zone markings.
-- They are kept as lateral/longitudinal rectangles, not textures, because the renderer fills
-- ground rectangles row by row and has nothing to sample a picture from.
function T:BuildDecals()
 local list={}
 local function add(s0,s1,d0,d1,r,g,b,kind) list[#list+1]={s0=s0,s1=s1,d0=d0,d1=d1,r=r,g=g,b=b,kind=kind} end
 for _,z in ipairs(self.zones) do
  local c=ZONE_COLORS[z.kind]
  add(z.s0,z.s1,z.d0,z.d1,c[1],c[2],c[3],z.kind)
  if z.kind=='pad' then
   -- Chevron bars across the plate: the bright lines are what read as "dash plate" from far off.
   local k=0;local s=z.s0+1.5
   while s+1.6<z.s1 do add(s,s+1.6,z.d0+.6,z.d1-.6,.6,1,.55,'padbar');s=s+4.5;k=k+1 end
  elseif z.kind=='heal' then
   local s=z.s0+2
   while s+2<z.s1 do add(s,s+2,z.d0+.5,z.d1-.5,.7,1,.75,'healbar');s=s+6 end
  end
 end
 -- Start grid, two rows of squares across the road.
 local w=self:HalfWidth(0);local cells=8;local cw=2*w/cells
 for row=0,1 do for c=0,cells-1 do
  local white=(row+c)%2==0;local v=white and .95 or .06
  add(row*2.2,row*2.2+2.2,-w+c*cw,-w+(c+1)*cw,v,v,v,'grid')
 end end
 local s=14
 while s<self.length-16 do
  local blocked=false
  for _,z in ipairs(self.zones) do if s+9>z.s0 and s<z.s1+1 and z.d0<0.6 and z.d1>-.6 then blocked=true end end
  if not blocked and not (s<8) then add(s,s+9,-.35,.35,.78,.84,.95,'dash') end
  s=s+30
 end
 table.sort(list,function(a,b) return a.s0<b.s0 end)
 self.decals=list
 self:BuildRichDecals()
end
-- The same markings for the textured renderer: one picture per plate instead of flat bars, a
-- single chequered grid, and arrows painted down the long straights. `cell` names a cell in
-- the world atlas; a decal with no cell is a flat tinted bar (the dashes).
function T:BuildRichDecals()
 local list={}
 local function add(s0,s1,d0,d1,cell,tint) list[#list+1]={s0=s0,s1=s1,d0=d0,d1=d1,cell=cell,tint=tint,r=.78,g=.84,b=.95} end
 local zoneCell={pad='d_pad',heal='d_heal',rough='d_rough',slip='d_slip'}
 for _,z in ipairs(self.zones) do add(z.s0,z.s1,z.d0,z.d1,zoneCell[z.kind]) end
 local w=self:HalfWidth(0)
 add(0,4.4,-w,w,'d_grid')
 local function blocked(s0,s1,d0,d1)
  for _,z in ipairs(self.zones) do if s1>z.s0-2 and s0<z.s1+2 and d1>z.d0 and d0<z.d1 then return true end end
 end
 local s=14;local flip=1
 while s<self.length-16 do
  if s>=8 and not blocked(s,s+9,-.35,.35) then add(s,s+9,-.35,.35,nil) end
  s=s+30
 end
 -- Lane arrows: every 150 m, only where the road is straight and nothing else is painted.
 local s2=90;local side=-1
 while s2<self.length-40 do
  local i=floor(s2/self.step)%self.n+1
  local straight=true
  for k=0,3 do if abs(self.curv[(i+k*3-1)%self.n+1])>.0012 then straight=false end end
  local d=side*self:HalfWidth(s2)*.5
  if straight and not blocked(s2,s2+13,d-2.4,d+2.4) then add(s2,s2+13,d-2.4,d+2.4,'d_arrow','neon');side=-side end
  s2=s2+150
 end
 table.sort(list,function(a,b) return a.s0<b.s0 end)
 self.decalsRich=list
end
