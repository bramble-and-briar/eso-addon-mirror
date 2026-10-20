PBF=PBF or {}
local C=PBF.Core
local M={};PBF.Machine=M
local cos,sin,exp,sqrt,abs,max,min=math.cos,math.sin,math.exp,math.sqrt,math.abs,math.max,math.min
-- top: metres per second at full throttle. turn: radians per second at a standstill; it falls
-- to half of that at top speed. grip: how fast sideways speed is bled off per second, so a high
-- value corners on rails and a low one slides. mass only matters in a collision.
M.Types={
 {id='falcon',name='ルナ・ファルコン',note='扱いやすい標準機体',top=220,accel=70,turn=2.15,grip=7.0,mass=1.0,
  body={.22,.46,.98},wing={.08,.18,.48},top2={.9,.97,1},glow={.2,.82,1}},
 {id='drake',name='クリムゾン・ドレイク',note='最高速重視。曲がりにくい',top=235,accel=66,turn=1.8,grip=5.6,mass=1.15,
  body={.94,.13,.22},wing={.42,.045,.09},top2={1,.78,.7},glow={1,.2,.12}},
 {id='fox',name='ミント・フォクス',note='旋回重視。最高速は控えめ',top=205,accel=76,turn=2.55,grip=8.5,mass=.85,
  body={.18,.9,.62},wing={.055,.46,.28},top2={.88,1,.95},glow={.25,1,.74}},
 {id='bear',name='ゴールド・ベア',note='頑丈で体当たりに強い',top=215,accel=62,turn=2.0,grip=6.5,mass=1.5,
  body={1,.7,.13},wing={.48,.3,.045},top2={1,.94,.68},glow={.16,.78,1}},
}
M.RADIUS=1.8
M.BOOST_TOP=1.25
M.BOOST_COST=15
M.BOOST_MIN=12
M.PAD_TOP=1.15
M.JUMP_SPEED=11.5
M.GRAVITY=16
function M.New(kind,x,y,h)
 local st=M.Types[kind]
 return {type=st,kind=kind,x=x,y=y,h=h,vx=0,vy=0,speed=0,energy=100,boost=0,pad=0,
  s=0,d=0,idx=1,hit=0,scrape=false,bank=0,steer=0,wrecked=false,healing=false,rough=false,slip=false,
  height=0,vz=0,airborne=false,zone=nil}
end
-- One physics step. `inp` = {steer=-1..1 (right positive), throttle=0..1, brake=0..1,
-- boost=bool, lean=-1|0|1}; `canBoost` is the race's rule (no boost on the first lap).
-- Events are left on the machine as fields (hit, scrape, padded, boosting) and cleared by the
-- race, so the physics allocates nothing per step.
function M.Step(m,track,inp,dt,canBoost)
 local st=m.type
 if m.wrecked then
  local k=exp(-2.5*dt);m.vx,m.vy=m.vx*k,m.vy*k
  m.x=m.x+m.vx*dt;m.y=m.y+m.vy*dt;m.speed=sqrt(m.vx*m.vx+m.vy*m.vy);return
 end
 local fx,fy=cos(m.h),sin(m.h)
 local vf=m.vx*fx+m.vy*fy
 local zoneInfo=track:Zone(m.s,m.d)
 local zone=zoneInfo and zoneInfo.kind
 m.rough,m.slip,m.healing=zone=='rough',zone=='slip',zone=='heal'
 if zone=='loop' and m.zone~='loop' and not m.airborne then
  m.looping=true;m.loopT=0;m.loopDistance=zoneInfo.distance or 150;m.loopHeight=zoneInfo.height or 24
  m.airborne=true;m.looped=true
 elseif zone=='jump' and m.zone~='jump' and not m.airborne then
  m.vz=M.JUMP_SPEED;m.airborne=true;m.jumped=true
 end
 m.zone=zone
 if m.looping then
  m.loopT=m.loopT+max(vf,45)*dt/m.loopDistance
  local a=min(1,m.loopT)*math.pi*2
  m.height=m.loopHeight*(1-cos(a));m.loopAngle=a
  if m.loopT>=1 then m.height,m.vz,m.airborne,m.looping,m.loopAngle=0,0,false,false,nil;m.landed=true end
 elseif m.airborne then
  m.height=m.height+m.vz*dt
  m.vz=m.vz-M.GRAVITY*dt
  if m.height<=0 and m.vz<0 then m.height,m.vz,m.airborne=0,0,false;m.landed=true end
 end
 -- Boost is a held button that burns energy, the way the SNES original treats it: you pay for
 -- speed with the same bar that keeps you alive, and below a floor it simply stops.
 local boosting=inp.boost and canBoost and m.energy>M.BOOST_MIN
 if boosting then m.energy=m.energy-M.BOOST_COST*dt end
 m.boosting=boosting
 if zone=='pad' then m.pad=1.2;m.padded=true end
 if m.pad>0 then m.pad=m.pad-dt end
 local top=st.top
 if boosting then top=top*M.BOOST_TOP elseif m.pad>0 then top=top*M.PAD_TOP end
 if m.rough then top=top*.55 end
 -- Steering: faster means a wider circle, and leaning trades grip for a tighter one.
 local speedFrac=C.clamp(vf/st.top,0,1.4)
 local rate=st.turn*(1-.5*min(1,speedFrac))
 local lean=inp.lean or 0
 local yaw=C.clamp(inp.steer+lean*.55,-1.35,1.35)*rate
 if vf<2 then yaw=yaw*(vf/2>0 and vf/2 or 0) end
 -- Heading is counter-clockwise, and steer is positive to the right, so a right turn lowers it.
 m.h=m.h-yaw*dt
 m.steer=inp.steer
 m.bank=m.bank+(C.clamp(yaw/rate,-1,1)-m.bank)*min(1,dt*7)
 fx,fy=cos(m.h),sin(m.h)
 local rx,ry=fy,-fx
 -- The velocity vector does not turn with the nose, so the part of it that is now sideways is
 -- the slide.
 vf=m.vx*fx+m.vy*fy
 local vr=m.vx*rx+m.vy*ry
 local grip=st.grip*(lean~=0 and .4 or 1)
 if m.airborne then grip=grip*.14 end
 if m.slip then grip=grip*.18 end
 if m.rough then grip=grip*1.4 end
 vr=vr*exp(-grip*dt)
 if inp.throttle>0 then
  local push=st.accel*inp.throttle*(1-C.clamp(vf/top,0,1)^2)
  if boosting then push=push+st.accel*1.3 end
  vf=vf+push*dt
 else vf=vf*exp(-.22*dt) end
 if inp.brake>0 then vf=max(0,vf-95*inp.brake*dt) end
 if vf>top then vf=vf-(vf-top)*min(1,1.6*dt) end
 if m.rough then vf=vf*exp(-.5*dt) end
 m.vx,m.vy=fx*vf+rx*vr,fy*vf+ry*vr
 m.x=m.x+m.vx*dt;m.y=m.y+m.vy*dt
 -- Walls. Locate gives the lateral position; past the edge the machine is put back, its outward
 -- speed is bounced, and what it loses is taken from the energy bar.
 local s,d,idx=track:Locate(m.x,m.y,m.idx)
 local limit=track:HalfWidth(s)-M.RADIUS
 m.scrape=false
 if abs(d)>limit then
  local sg=d>0 and 1 or -1
  local nx,ny=track.rx[idx]*sg,track.ry[idx]*sg
  local over=abs(d)-limit
  m.x=m.x-nx*over;m.y=m.y-ny*over;d=sg*limit
  local vn=m.vx*nx+m.vy*ny
  if vn>0 then
   m.vx=m.vx-(1+.3)*vn*nx;m.vy=m.vy-(1+.3)*vn*ny
   m.hit=max(m.hit,vn)
   -- Jet-car impact protection: the old damage scale was tuned for 500 km/h and made a single
   -- high-speed correction fatal after the 1000 km/h retune.
   m.energy=m.energy-max(0,vn-8)*.035
  end
  local k=exp(-.9*dt);m.vx,m.vy=m.vx*k,m.vy*k
  m.energy=m.energy-.6*dt*(sqrt(m.vx*m.vx+m.vy*m.vy)/180)
  m.scrape=true
 end
 m.s,m.d,m.idx=s,d,idx
 m.roadZ=track:Elevation(s);m.grade=track:Slope(s)
 if m.healing then m.energy=min(100,m.energy+24*dt) end
 if m.energy<=0 then m.energy=0;m.wrecked=true;m.exploded=true end
 m.speed=sqrt(m.vx*m.vx+m.vy*m.vy)
end
-- Two machines overlap: pull them apart in proportion to mass and trade the speed along the line
-- between them. Returns the closing speed so the race can score a bump.
function M.Collide(a,b)
 if abs((a.height or 0)-(b.height or 0))>2 then return 0 end
 local dx,dy=b.x-a.x,b.y-a.y;local d2=dx*dx+dy*dy;local r=2*M.RADIUS
 if d2>=r*r or d2<1e-6 then return 0 end
 local d=sqrt(d2);local nx,ny=dx/d,dy/d
 local ma,mb=a.type.mass,b.type.mass;local total=ma+mb
 local push=r-d
 a.x=a.x-nx*push*mb/total;a.y=a.y-ny*push*mb/total
 b.x=b.x+nx*push*ma/total;b.y=b.y+ny*push*ma/total
 local rel=(a.vx-b.vx)*nx+(a.vy-b.vy)*ny
 if rel<=0 then return 0 end
 local j=(1+.45)*rel/(1/ma+1/mb)
 a.vx=a.vx-j*nx/ma;a.vy=a.vy-j*ny/ma
 b.vx=b.vx+j*nx/mb;b.vy=b.vy+j*ny/mb
 local dmg=max(0,rel-6)*.03
 a.energy=a.energy-dmg*mb/total*1.6;b.energy=b.energy-dmg*ma/total*1.6
 a.hit=max(a.hit,rel);b.hit=max(b.hit,rel)
 return rel
end
