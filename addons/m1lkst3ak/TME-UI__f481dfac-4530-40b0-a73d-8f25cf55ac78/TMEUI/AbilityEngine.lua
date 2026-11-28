-- Universal ability timers: for the dual action bar display only.
local N=TMEUI
local s=N.safe
local E={slots={},casts={},effects={},kinds={},dead={}}
N.abilityEngine=E
local function now() return s(GetFrameTimeSeconds) or 0 end
local function valid(id) return type(id)=='number' and id>0 end
local function name(id) return tostring(s(GetAbilityName,id) or ''):lower() end
local function norm(v) return tostring(v or ''):lower() end
local function ms(v) return type(v)=='number' and v>0 and v<=600000 and v/1000 or nil end
function E.bound(slot,bar,active)
 E.slots[bar]=E.slots[bar] or {}
 local id=s(GetSlotBoundId,slot,bar)
 if bar==active then
  local cur=s(GetSlotBoundId,slot);if type(cur)=='number' then id=cur end
  if type(id)=='number' then E.slots[bar][slot]=id end
 elseif type(id)=='number' then E.slots[bar][slot]=id
 elseif E.slots[bar][slot]~=nil then id=E.slots[bar][slot] end
 return id
end
local function classify(id)
 local n=name(id)
 -- Explicit exceptions only where known metadata is insufficient.
 if n=='elemental susceptibility' or n=='elemental drain' or n=='weakness to elements' then return 'target' end
 local desc=norm(s(GetAbilityTargetDescription,id))
 if desc=='ground' or desc=='area' or desc=='self' then return desc end
 if desc=='enemy' or desc=='target' then return 'target' end
 return 'unknown'
end
function E.cast(_,slot)
 if type(slot)~='number' or slot<3 or slot>8 then return end
 local bar=s(GetActiveHotbarCategory)
 local id=bar~=nil and E.bound(slot,bar,bar) or s(GetSlotBoundId,slot)
 if not valid(id) then return end
 local t=now();local ch,cast,channel=s(GetAbilityCastInfo,id)
 local duration=ms(s(GetAbilityDuration,id));local channelTime=ch==true and (ms(channel) or ms(cast)) or nil
 local kind=E.kinds[id] or classify(id)
 E.casts[id]={at=t,ending=t+(duration or channelTime or 0),channelEnd=channelTime and t+channelTime or nil,kind=kind}
end
local function match(id,effectName,t)
 if valid(id) then
  if E.casts[id] then return id end
  for _,slots in pairs(E.slots) do for _,v in pairs(slots) do if v==id then return id end end end
 end
 local n=norm(effectName);if n=='' then return end
 local found
 for aid,c in pairs(E.casts) do
  if name(aid)==n and (t-c.at<=2 or c.ending>t) then if found and found~=aid then return end;found=aid end
 end
 return found
end
function E.effect(_,change,slot,effectName,tag,beg,ending,stack,icon,buffType,effectType,abilityType,statusEffectType,unitName,unitId,abilityId,sourceType)
 local t=now();local self=tag=='player';local uid=self and 'player' or (unitId and unitId~=0 and tostring(unitId) or nil)
 if not uid then return end
 local key=uid..':'..tostring(abilityId)..':'..tostring(slot)
 if change==EFFECT_RESULT_FADED then
  local old=E.effects[key];if old then E.effects[key]=nil;local c=E.casts[old.id];if c and old.beg>=c.at-.5 and c.kind~='ground' and c.kind~='area' then c.observed=true end end
  return
 end
 if change~=EFFECT_RESULT_GAINED and change~=EFFECT_RESULT_UPDATED then return end
 if not COMBAT_UNIT_TYPE_PLAYER or sourceType~=COMBAT_UNIT_TYPE_PLAYER then return end
 if type(ending)~='number' or ending<=t or ending-t>600 then return end
 local id=match(abilityId,effectName,t);if not id then return end
 if not self and E.dead[uid] then if change==EFFECT_RESULT_GAINED then E.dead[uid]=nil else return end end
 local c=E.casts[id];local kind=c and c.kind or E.kinds[id] or classify(id)
 if kind=='unknown' then kind=self and 'self' or 'target';E.kinds[id]=kind end
 if c then c.kind=kind;c.observed=true end
 E.effects[key]={id=id,uid=uid,beg=type(beg)=='number' and beg or t,ending=ending,stack=type(stack)=='number' and stack or 0}
end
function E.combat(_,result,isError,abilityName,graphic,actionType,sourceName,sourceType,targetName,targetType,hitValue,powerType,damageType,log,sourceId,targetId)
 if not targetId or targetId==0 or result==nil then return end
 if result==ACTION_RESULT_TARGET_DEAD or result==ACTION_RESULT_DIED or result==ACTION_RESULT_DIED_XP or result==ACTION_RESULT_KILLING_BLOW then
  local uid=tostring(targetId);E.dead[uid]=now()
  for k,e in pairs(E.effects) do if e.uid==uid then E.effects[k]=nil;local c=E.casts[e.id];if c then c.observed=true end end end
 end
end
function E.tick(t)
 for k,e in pairs(E.effects) do if e.ending<=t then E.effects[k]=nil end end
 for id,c in pairs(E.casts) do if math.max(c.ending,c.channelEnd or 0)+2<t then E.casts[id]=nil end end
 for uid,at in pairs(E.dead) do if t-at>60 then E.dead[uid]=nil end end
end
function E.duration(id,t)
 if not valid(id) then return end
 local c=E.casts[id];local best,stacks=0,0
 for _,e in pairs(E.effects) do if e.id==id and e.ending>t then best=math.max(best,e.ending);stacks=math.max(stacks,e.stack or 0) end end
 if c and c.channelEnd and c.channelEnd>t then return c.channelEnd-t,true,0 end
 if best>t then return best-t,false,stacks end
 if c and c.ending>t and (c.kind=='ground' or c.kind=='area' or (not c.observed and c.kind~='target')) then return c.ending-t,true,0 end
end
function E.clear() E.slots={};E.casts={};E.effects={};E.kinds={};E.dead={} end
function E.register()
 local function reg(n,event,fn) if event then EVENT_MANAGER:RegisterForEvent(n,event,fn) end end
 reg('TMEUIAbilityEffects',EVENT_EFFECT_CHANGED,E.effect)
 reg('TMEUIAbilityDeaths',EVENT_COMBAT_EVENT,E.combat)
 reg('TMEUIAbilityCasts',EVENT_ACTION_SLOT_ABILITY_USED,E.cast)
 reg('TMEUIAbilityZone',EVENT_PLAYER_DEACTIVATED,E.clear)
 reg('TMEUIAbilitySlots',EVENT_ACTION_SLOTS_FULL_UPDATE,function() local active=s(GetActiveHotbarCategory);if active~=nil then for slot=3,8 do E.bound(slot,active,active) end end end)
end
