PBF=PBF or {}
local C=PBF.Core
local R={};R.__index=R;PBF.Race=R
local abs,floor,max,min=math.abs,math.floor,math.max,math.min
R.STEP=1/60
R.COUNTDOWN=3
R.BOOST_FROM_LAP=2
-- Starts a race on `track`. opts = {kind=player machine, rivals=7, laps=3, seed, level=1..3}.
-- The player is machines[1]. `onEvent(kind, machine)` is how sound and the HUD hear about it.
function R.New(track,opts)
 local self=setmetatable({track=track,machines={},state='grid',time=0,countdown=R.COUNTDOWN,acc=0,steps=0},R)
 self.laps=opts.laps or track.def.laps or 3
 self.level=opts.level or 2
 self.rng=C.Rng(opts.seed or 1)
 local rivals=opts.rivals or 7
 local kinds=#PBF.Machine.Types
 -- Grid: two columns, staggered, the pole at the front. The player starts mid-field so there is
 -- something to chase and someone to lose to.
 local total=rivals+1
 local order={}
 for i=1,total do order[i]=i end
 for i=total,2,-1 do local j=floor(self.rng()*i)+1;order[i],order[j]=order[j],order[i] end
 local slotOf={}
 local playerSlot=min(total,floor(total/2)+1)
 local k=0
 for i=1,total do
  if i==1 then slotOf[i]=playerSlot
  else k=k+1;if k==playerSlot then k=k+1 end;slotOf[i]=k end
 end
 local w=track:HalfWidth(0)
 for i=1,total do
  local slot=slotOf[i]
  local row=floor((slot-1)/2);local col=(slot-1)%2
  local s=-8-row*11-col*5
  local d=(col==0 and -1 or 1)*w*.42
  local x,y,h=track:Point(s,d)
  local kind=i==1 and opts.kind or ((i+order[i])%kinds)+1
  local m=PBF.Machine.New(kind,x,y,h)
  m.slot=slot;m.id=i;m.player=i==1
  m.s,m.d,m.idx=track:Locate(x,y,nil)
  m.roadZ=track:Elevation(m.s);m.grade=track:Slope(m.s)
  m.dist=s;m.prevS=m.s;m.lap=1;m.lapStart=0;m.lapTimes={};m.finished=false;m.finishTime=nil
  if i>1 then
   local spread=(i-2)/max(1,rivals-1)
   m.ai=PBF.AI.New(.80+.05*self.level+.1*(1-spread)*.6-.06*spread,self.rng);m.ai.wobble=self.rng()*6.28
  end
  self.machines[i]=m
 end
 self.player=self.machines[1]
 self.input={steer=0,throttle=0,brake=0,boost=false,lean=0}
 self.aiInput={steer=0,throttle=0,brake=0,boost=false,lean=0}
 self.bestLap=nil
 self:Rank()
 return self
end
function R:Emit(kind,m,a) if self.onEvent then self.onEvent(kind,m,a) end end
-- Distance of `o` ahead of `m` along the road (negative when behind), wrapped to half a lap.
function R:Gap(m,o)
 local L=self.track.length;local g=o.s-m.s
 if g>L/2 then g=g-L elseif g<-L/2 then g=g+L end
 return g
end
function R:Rank()
 local list={}
 for i,m in ipairs(self.machines) do list[i]=m end
 table.sort(list,function(a,b)
  if a.finished~=b.finished then return a.finished end
  if a.finished then return a.finishTime<b.finishTime end
  if a.wrecked~=b.wrecked then return not a.wrecked end
  return a.dist>b.dist
 end)
 for i,m in ipairs(list) do m.rank=i end
 self.order=list
end
local function progress(self,m)
 local L=self.track.length
 local ds=m.s-m.prevS
 if ds<-L/2 then ds=ds+L elseif ds>L/2 then ds=ds-L end
 m.prevS=m.s;m.dist=m.dist+ds
 local lap=max(1,floor(m.dist/L)+1)
 if lap>m.lap and not m.finished then
  local lapTime=self.time-m.lapStart
  m.lapTimes[#m.lapTimes+1]=lapTime;m.lapStart=self.time
  if lap>self.laps then
   m.finished=true;m.finishTime=self.time;m.lap=self.laps
   self:Emit('finish',m)
  else
   m.lap=lap
   if m.player then
    local best=not self.bestLap or lapTime<self.bestLap
    if best then self.bestLap=lapTime end
    self:Emit(lap==self.laps and 'finalLap' or 'lap',m,lapTime)
   end
  end
 end
end
function R:Step(dt)
 local track=self.track
 for _,m in ipairs(self.machines) do
  local inp=self.input
  if m.player then
   if m.finished then inp=self.coast end
  else
   inp=self.aiInput
   if m.finished then inp.steer,inp.throttle,inp.brake,inp.boost,inp.lean=0,0,.3,false,0
   else
    -- Light rubber band: a rival far in front of the player eases off and one far behind pushes,
    -- so a player who is well ahead or well behind still has a race. Hard level has none.
    local g=self:Gap(self.player,m)
    m.ai.scale=self.level>=3 and 1 or C.clamp(1-g*.0004,.93,self.level==1 and 1 or 1.05)
    PBF.AI.Drive(m,self,inp,dt)
   end
  end
  PBF.Machine.Step(m,track,inp,dt,m.lap>=R.BOOST_FROM_LAP)
 end
 local list=self.machines
 for i=1,#list-1 do for j=i+1,#list do
  local rel=PBF.Machine.Collide(list[i],list[j])
  if rel>6 then
   if list[i].player or list[j].player then self:Emit('bump',list[i].player and list[i] or list[j],rel) end
  end
 end end
 for _,m in ipairs(list) do
  progress(self,m)
  if m.padded then m.padded=false;if m.player then self:Emit('pad',m) end end
  if m.jumped then m.jumped=false;if m.player then self:Emit('jump',m) end end
  if m.looped then m.looped=false;if m.player then self:Emit('loop',m) end end
  if m.landed then m.landed=false;if m.player then self:Emit('land',m) end end
  if m.hit>0 then
   if m.player and m.hit>5 then self:Emit('wall',m,m.hit) end
   m.hit=0
  end
  if m.exploded then m.exploded=false;m.wreckTime=self.time;self:Emit('explode',m) end
 end
 self.coast=self.coast or {steer=0,throttle=0,brake=.25,boost=false,lean=0}
 self:Rank()
end
function R:Tick(dt)
 if self.state=='grid' then
  self.countdown=self.countdown-dt
  -- The number on screen is the whole seconds still to go, so "3" shows for the first second
  -- and the light goes green the instant it reaches zero.
  local shown=math.ceil(self.countdown)
  if shown~=self.shown then
   self.shown=shown
   if shown>0 then self:Emit('count',self.player,shown) end
  end
  if self.countdown<=0 then self.state='racing';self.countdown=0;self:Emit('go',self.player) end
  return
 end
 if self.state=='finished' then return end
 self.acc=self.acc+min(.1,dt)
 while self.acc>=R.STEP do
  self.acc=self.acc-R.STEP
  self.time=self.time+R.STEP;self.steps=self.steps+1
  self:Step(R.STEP)
  if self.player.finished or self.player.wrecked then
   self.endAt=self.endAt or (self.time+(self.player.finished and 3 or 2.5))
   if self.time>=self.endAt then self:Finish();break end
  end
 end
end
function R:Finish()
 self.state='finished'
 self:Rank()
 self:Emit('over',self.player)
end
