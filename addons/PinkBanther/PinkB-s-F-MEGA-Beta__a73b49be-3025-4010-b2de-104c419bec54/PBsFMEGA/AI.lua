PBF=PBF or {}
local C=PBF.Core
local AI={};PBF.AI=AI
local abs,min,max,sqrt=math.abs,math.min,math.max,math.sqrt
-- The fastest a machine can take a corner of radius R: its turn rate falls with speed, so
-- v = R*turn*(1-0.5*v/top), which solves to the line below.
local function cornerSpeed(st,radius)
 local k=radius*st.turn
 return k/(1+.5*k/st.top)
end
function AI.New(skill,rng)
 return {skill=skill,lane=0,laneGoal=0,laneAt=0,boostLeft=0,wobble=rng()*6.28,hold=0}
end
-- Fills `inp` for the machine, the same table the player's pad fills. The AI gets no physics of
-- its own: it steers a point down the road and works the same stick and pedals.
function AI.Drive(m,race,inp,dt)
 local ai=m.ai;local track=race.track;local st=m.type
 local speed=m.speed
 local look=16+speed*.5
 -- Lane: a slow drift so the field does not run in a line, pushed aside by whatever is close
 -- ahead.
 ai.wobble=ai.wobble+dt*.45
 local half=track:HalfWidth(m.s)-5
 local goal=math.sin(ai.wobble+m.slot)*half*.55
 for _,o in ipairs(race.machines) do
  if o~=m and not o.wrecked then
   local ahead=race:Gap(m,o)
   if ahead>0 and ahead<34 then
    local lat=o.d-m.d
    if abs(lat)<4.2 then goal=C.clamp(m.d+(lat>0 and -7 or 7),-half,half) end
   end
  end
 end
 ai.lane=ai.lane+C.clamp(goal-ai.lane,-9*dt,9*dt)
 local tx,ty=track:Point(m.s+look,C.clamp(ai.lane,-half,half))
 local want=C.atan2(ty-m.y,tx-m.x)
 local err=C.wrapAngle(want-m.h)
 -- Steering on the nose alone lets a slide run on, so the sideways speed is cancelled too.
 local vr=m.vx*math.sin(m.h)-m.vy*math.cos(m.h)
 -- err is positive when the target is to the left, and steer is positive to the right.
 inp.steer=C.clamp(-err*2.6+vr*.02,-1,1)
 inp.lean=0
 -- Target speed: the slowest corner inside the distance needed to brake for it.
 local skill=ai.skill*(ai.scale or 1)
 local limit=st.top*skill
 local reach=speed*speed/(2*70)+30
 local i0=m.idx;local n=track.n;local stepLen=track.step
 for k=0,math.floor(reach/stepLen),3 do
  local c=abs(track.curv[(i0+k-1)%n+1])
  if c>1e-4 then
   local v=cornerSpeed(st,1/c)*skill*1.02
   local allow=v+k*stepLen*.9
   if allow<limit then limit=allow end
  end
 end
 if m.rough then limit=limit*.6 end
 inp.throttle=speed<limit and 1 or 0
 inp.brake=speed>limit*1.1 and min(1,(speed-limit*1.1)/12) or 0
 -- Boost on a straight, with energy to spare, from the second lap.
 inp.boost=false
 if ai.boostLeft>0 then
  ai.boostLeft=ai.boostLeft-dt
  if m.energy>40 and abs(err)<.12 and inp.brake==0 then inp.boost=true end
 elseif m.lap>=2 and m.energy>65 and abs(track.curv[m.idx])<.002 and race.rng()<dt*.35 then
  ai.boostLeft=1.4
 end
end
