-- Shared on-demand advisors and bounded combat awareness. No protected actions.
local N=ESOHardcore;local R=N.rewards;local s=N.safe
local function c() return N.hardcore and N.hardcore.saved end
local function active() local a=c();return a and a.active and not a.fallen end
local function rank(k,l) return active() and N.rank(k)>=l end
local function install(k,i,label,fn) R.defs[k][i][1]=label;R.install(k,i,fn) end
local function clean(x) return tostring(x or 'Unknown'):gsub('%^%a+','') end
local function fmt(x) return tostring(math.floor(tonumber(x) or 0)) end
local function state() local a=c();a.advanced21=a.advanced21 or {};return a.advanced21 end
local function clock() return s(GetFrameTimeSeconds) or 0 end
local function value(l) local v=s(GetItemLinkValue,l);return type(v)=='number' and v or nil end
local function rows() return N.economyRows(8) or {} end
local function top(list,limit,render) local t={};for i=1,math.min(limit,#list) do t[#t+1]=render(list[i]) end;return table.concat(t,'\n') end
local function event(key,id,fn) if id then EVENT_MANAGER:RegisterForEvent('ESOHC21'..key,id,function(...) if active() then pcall(fn,...) end end) end end
-- Harvesting efficiency: observed acquisition events and NPC value, not market trading.
local originalNode=N.recordNode
function N.recordNode(link,qty) originalNode(link,qty);if not rank('Harvesting',15) then return end;local m=state();m.gather=m.gather or {};local z=clean(s(GetUnitZone,'player'));local r=m.gather[z];if not r then local count=0;for _ in pairs(m.gather) do count=count+1 end;if count>=64 then return end;r={visits=0,units=0,gold=0};m.gather[z]=r end;r.visits=r.visits+1;local q=tonumber(qty) or 0;r.units=r.units+q;local v=link and value(link);if v then r.gold=r.gold+v*q end end
install('Harvesting',6,'Master Harvester: community resource visibility',function()return N.harvestMasteryStatus()end)
local function supplies() local t={food=0,drink=0,potions=0};for _,r in ipairs(rows()) do local typ=s(GetItemLinkItemType,r.link);local q=N.hcAvailable(r.link);if typ==ITEMTYPE_FOOD then t.food=t.food+q elseif typ==ITEMTYPE_DRINK then t.drink=t.drink+q elseif typ==ITEMTYPE_POTION then t.potions=t.potions+q end end;return t end
-- One reusable HUD, lazy allocation; all events only use observed player combat.
-- A single transient cue, rendered through the existing immersive overlay.
local untilTime=0;local priority=0;local lastAlert={};local owner;local failed=false
local function hide() N.skillEffect=nil end
local function show(key,title,message,fraction,p,colour)
 local now=clock();if failed or not active() or not N.gameplay() or c().overlays==false then return end
 if now-(lastAlert[key] or -100)<8 or now<untilTime and p<priority then return end
 lastAlert[key]=now;priority=p;untilTime=now+3
 local style=(key=='fatigue' or key=='lowst' or key=='drain' or key=='exhaust') and 'haze' or key=='lastRear' and 'rear' or key=='lastSide' and 'side' or (key=='harvest' or key=='endfight' or key=='potions') and 'corner' or 'vignette'
 N.skillEffect={key=key,style=style,color=colour,start=now,ends=untilTime,priority=p,strength=math.max(.25,math.min(.85,1-(fraction or 1)+.35))}
end
local red={.95,.16,.20};local blue={.35,.66,1};local green={.65,.83,.39};local amber={.95,.72,.35};local harvestGold={.93,.77,.38}
local combat={};local previousCombat=false;local prevH,prevS;local tickAt=0;local potionAt=0;local threat={};local attack={};local totals={};local lastFight
local function reset() combat={start=clock(),damage=0,blocks=0,dodges=0,interrupts=0,hits=0};threat={};attack={};totals={} end
reset()
local function power(flag) if not flag then return end;local v,m=s(GetUnitPower,'player',flag);if type(v)=='number' and type(m)=='number' and m>0 then return v/m end end
local function threatList()local t={};local now=clock();for k,v in pairs(threat) do if now-v.at<=10 then t[#t+1]=v else threat[k]=nil end end;table.sort(t,function(a,b)return a.damage>b.damage end);return t end
local function damageResult(r) return r==ACTION_RESULT_DAMAGE or r==ACTION_RESULT_CRITICAL_DAMAGE or r==ACTION_RESULT_DOT_TICK or r==ACTION_RESULT_DOT_TICK_CRITICAL or r==ACTION_RESULT_BLOCKED_DAMAGE end
event('combat',EVENT_COMBAT_EVENT,function(_,result,err,ability,_,_,source,sourceType,target,targetType,hit,_,_,_,sourceId)
 if err then return end
 if rank('Combat Mastery',30) and sourceType==COMBAT_UNIT_TYPE_PLAYER and result==ACTION_RESULT_INTERRUPT then combat.interrupts=combat.interrupts+1;local m=state();m.interrupts=(m.interrupts or 0)+1 end
 if targetType~=COMBAT_UNIT_TYPE_PLAYER or sourceType==COMBAT_UNIT_TYPE_PLAYER then return end
 if rank('Combat Mastery',15) then if result==ACTION_RESULT_BLOCKED_DAMAGE then combat.blocks=combat.blocks+1 elseif result==ACTION_RESULT_DODGED then combat.dodges=combat.dodges+1 end end
 if not damageResult(result) or type(hit)~='number' or hit<=0 then return end
 combat.damage=combat.damage+hit;combat.hits=combat.hits+1
 if rank('Perception',30) then local id=tostring((sourceId and sourceId~=0 and sourceId) or source or '?');local n=0;for _ in pairs(threat) do n=n+1 end;if threat[id] or n<24 then local r=threat[id] or {name=clean(source),damage=0};r.damage=r.damage+hit;r.at=clock();threat[id]=r end end
 if rank('Combat Mastery',50) then local key=clean(source)..' / '..clean(ability);local m=state();m.attacks=m.attacks or {};local a=m.attacks[key];if not a then local n=0;for _ in pairs(m.attacks) do n=n+1 end;if n>=80 then return end;a={count=0,max=0};m.attacks[key]=a end;a.count=a.count+1;a.max=math.max(a.max,hit) end
end)
local oldTick=N.skillsTick
local function awarenessTick(dt,visible,inCombat)
 if owner~=c() then hide();owner=c();reset();lastFight=nil;previousCombat=false;prevH=nil;prevS=nil;lastAlert={};untilTime=0 end
 if not active() or not visible then hide();untilTime=0;return end
 local now=clock();if now>=untilTime then hide() end
 if inCombat and not previousCombat then reset();if rank('Perception',15) then show('engage','PERCEPTION | ENGAGED','Combat has begun',1,1,blue) end elseif not inCombat and previousCombat then local elapsed=math.max(1,now-combat.start);if rank('Combat Mastery',75) then lastFight={damage=combat.damage,blocks=combat.blocks,dodges=combat.dodges,interrupts=combat.interrupts,seconds=elapsed};if rank('Combat Mastery',99) then state().lastFight=lastFight end;show('endfight','COMBAT MASTERY | REVIEW','Blocks '..combat.blocks..' / dodges '..combat.dodges..' / interrupts '..combat.interrupts,1,1,amber) end end;previousCombat=inCombat
 if now-tickAt<1 then return end;tickAt=now
 local h=power(COMBAT_MECHANIC_FLAGS_HEALTH or POWERTYPE_HEALTH);local st=power(COMBAT_MECHANIC_FLAGS_STAMINA or POWERTYPE_STAMINA)
 if rank('Survivalist',99) and h and h<.12 then show('emergency','SURVIVALIST | EMERGENCY','Health below 12% - seek safety',h,5,red) elseif rank('Survivalist',30) and h and h<.25 then show('critical','SURVIVALIST | CRITICAL','Health below 25%',h,4,red) elseif rank('Survivalist',50) and h and prevH and prevH-h>=.25 then show('loss','SURVIVALIST | DANGER','Rapid health loss observed',h,4,red) end
 if rank('Endurance',99) and st and st<.1 then show('exhaust','ENDURANCE | EXHAUSTION','Stamina below 10%; conserve resources',st,3,green) elseif rank('Endurance',30) and st and st<.2 then show('lowst','ENDURANCE | LOW STAMINA','Stamina below 20%',st,2,green) elseif rank('Endurance',50) and st and prevS and prevS-st>=.2 then show('drain','ENDURANCE | RAPID DEPLETION','Stamina fell rapidly',st,2,green) elseif rank('Endurance',15) and inCombat and st and st<.45 then show('fatigue','ENDURANCE | FATIGUE','Stamina below 45%',st,1,green) end
 prevH=h;prevS=st
 if rank('Harvesting',50) and not inCombat and now-(lastAlert.harvest or -100)>=20 then
 local z,x,_,y=s(GetUnitWorldPosition,'player');if type(z)=='number' and type(x)=='number' and type(y)=='number' then
 local best;for _,r in pairs(c().journal and c().journal.nodes or {}) do if r.zone==z and type(r.x)=='number' and type(r.z)=='number' then local dd=(r.x-x)^2+(r.z-y)^2;if not best or dd<best then best=dd end end end
 if best and best<=1500^2 then show('harvest','HARVESTING | KNOWN RESOURCE','Previously recorded site nearby',1,1,harvestGold) end end end
 if inCombat and rank('Perception',30) then local t=threatList();if #t>0 then local r=t[1];if rank('Perception',99) then show('priority','PERCEPTION | PRIORITY THREAT',r.name..' | '..#t..' recent damage sources',1,2,blue) elseif rank('Perception',75) and r.damage>0 then show('heavy','PERCEPTION | THREAT FOCUS',r.name..' | '..fmt(r.damage)..' observed damage',1,2,blue) elseif rank('Perception',50) and #t>=2 then show('multi','PERCEPTION | MULTIPLE THREATS',#t..' recent hostile damage sources',1,2,blue) else show('danger','PERCEPTION | INCOMING DAMAGE',r.name,1,1,blue) end end end
 if now-potionAt>=15 and not inCombat and rank('Survivalist',75) then potionAt=now;if supplies().potions==0 then show('potions','SURVIVALIST | SUPPLIES','No eligible HC potions recorded',1,1,amber) end end
end
install('Perception',3,'Observed incoming threat warning',function()return 'Screen effects indicate recent incoming damage sources. No unengaged enemy detection.'end)
install('Perception',4,'Multiple hostile source warning',function()return 'Screen effects indicate when two or more recent incoming sources are observed. Direction unavailable.'end)
install('Perception',6,'Multiple threat prioritization',function()local t=threatList();return #t>0 and top(t,5,function(r)return r.name..' | observed damage '..fmt(r.damage)end) or 'No recent observed damage sources' end)
install('Endurance',2,'Fatigue awareness',function()return 'Full-screen fatigue veil below 45% stamina. '..(N.hardcore and N.hardcore.fatigueInfo and N.hardcore.fatigueInfo() or '')end)
install('Endurance',3,'Low stamina blur',function()return 'Native uniform blur below 30% stamina. '..(N.hardcore and N.hardcore.fatigueInfo and N.hardcore.fatigueInfo() or '') end)
install('Endurance',6,'Emergency resource management',function()return 'Maximum fatigue veil below 10% stamina. '..(N.hardcore and N.hardcore.fatigueInfo and N.hardcore.fatigueInfo() or '')end)
install('Combat Mastery',3,'Interrupt performance analysis',function()return 'Current encounter interrupts: '..combat.interrupts..' | lifetime observed since update: '..fmt(state().interrupts)end)
install('Combat Mastery',4,'Recognized enemy attack reference',function()local t={};for k,v in pairs(state().attacks or {}) do t[#t+1]={name=k,max=v.max,count=v.count}end;table.sort(t,function(a,b)return a.max>b.max end);return #t>0 and top(t,5,function(r)return r.name..' | max hit '..fmt(r.max)..' ('..r.count..' observed)' end) or 'Receive attacks to build a personal reference.'end)
local function fightReport(r)if not r then return 'Finish an encounter to generate a report' end;return fmt(r.seconds)..'s | incoming DPS '..fmt(r.damage/math.max(1,r.seconds))..'\nBlocks '..r.blocks..' | dodges '..r.dodges..' | interrupts '..r.interrupts end
install('Combat Mastery',5,'Defensive performance feedback',function()return fightReport(lastFight)end)
install('Combat Mastery',6,'Post-combat analysis',function()return fightReport(state().lastFight or lastFight)end)
local failedTick={}
local function safeTick(key,fn,...)
 if failedTick[key] then return end
 local ok,err=pcall(fn,...);if not ok then failedTick[key]=true;if key=='awareness' then pcall(hide) elseif key=='lastSeen' then local q=_G.ESOHCThreatExclamation;if q then pcall(function()q:SetHidden(true)end)end end;if d then d('ESO Hardcore '..key..' disabled: '..tostring(err)) end end
end
-- Perception: only the last position of a manually targeted hostile, never a hidden unit lookup.
local sight,sightOwner;local alert,measure
local function hideDirection() if alert then alert:SetHidden(true) end end
local function lastSeenTick(dt,visible,inCombat)
 if sightOwner~=c() then sight=nil;sightOwner=c() end
 if not visible or not rank('Perception',30) or c().overlays==false then sight=nil;hideDirection();return end
 local now=clock();local zone,px,ph,pz=s(GetUnitRawWorldPosition,'player')
 local name=s(GetUnitName,'reticleover')
 local current=s(IsUnitAttackable,'reticleover')==true and type(name)=='string' and name~='' and s(IsUnitDead,'reticleover')~=true
 if current then
  local ez,ex,eh,ey=s(GetUnitRawWorldPosition,'reticleover')
  if ez==zone and type(ex)=='number' and type(eh)=='number' and type(ey)=='number' and type(px)=='number' and (ex-px)^2+(ey-pz)^2>0 then sight={zone=ez,x=ex,h=eh,z=ey,at=now,name=clean(name)} end
 end
 if not sight or sight.zone~=zone or now-sight.at>4 or (not current and not rank('Perception',50)) then hideDirection();return end
 if not measure then measure=WINDOW_MANAGER:CreateControl('ESOHCThreatCamera',GuiRoot,CT_CONTROL);measure:Create3DRenderSpace() end
 if type(Set3DRenderSpaceToCurrentCamera)~='function' then hideDirection();return end
 Set3DRenderSpaceToCurrentCamera(measure:GetName())
 local cx,ch,cz=measure:Get3DRenderSpaceOrigin();local fx,fh,fz=measure:Get3DRenderSpaceForward();local rx,rh,rz=measure:Get3DRenderSpaceRight()
 local tx,th,tz=s(WorldPositionToGuiRender3DPosition,sight.x,sight.h+100,sight.z)
 if type(tx)~='number' or type(th)~='number' or type(tz)~='number' then hideDirection();return end
 local dx,dy,dz=tx-cx,th-ch,tz-cz;local forward=dx*fx+dy*fh+dz*fz;local right=dx*rx+dy*rh+dz*rz
 local ux,uy,uz
 ux=rz*fh-rh*fz;uy=rx*fz-rz*fx;uz=rh*fx-rx*fh
 local up=dx*ux+dy*uy+dz*uz
 if forward<=0 and not rank('Perception',75) then hideDirection();return end
 local sx,sy
 if forward<=0 then sx=right>=0 and .42 or -.42;sy=.40;if math.abs(right)<math.abs(forward)*.25 then sx=0 end
 else sx=math.max(-.43,math.min(.43,right/math.max(.01,forward)*.55));sy=math.max(-.40,math.min(.40,-up/math.max(.01,forward)*.7)) end
 if not alert then alert=WINDOW_MANAGER:CreateControl('ESOHCThreatExclamation',GuiRoot,CT_TEXTURE);alert:SetTexture('ESOHardcore/ThreatAlert.dds');alert:SetDimensions(58,78);alert:SetMouseEnabled(false) end
 local w,h=GuiRoot:GetDimensions();alert:ClearAnchors();alert:SetAnchor(CENTER,GuiRoot,CENTER,sx*w,sy*h-24);alert:SetColor(1,.76,.36,(current and .96 or .72)*(c().intensity or 100)/100);alert:SetHidden(false)
end
install('Perception',4,'Last-seen threat awareness',function()return 'Directional exclamation for recent verified hostile sightings. Not live hidden enemy tracking.' end)
install('Perception',5,'Last-seen rear threat awareness',function()return 'Rear exclamation projects the last verified location, expiring after four seconds.' end)

function N.skillsTick(dt,visible,inCombat) oldTick(dt,visible,inCombat);safeTick('awareness',awarenessTick,dt,visible,inCombat);safeTick('lastSeen',lastSeenTick,dt,visible,inCombat) end
