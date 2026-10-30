HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP=0,1
COMBAT_UNIT_TYPE_PLAYER,COMBAT_UNIT_TYPE_PLAYER_PET=1,2
EFFECT_RESULT_GAINED,EFFECT_RESULT_UPDATED,EFFECT_RESULT_FADED=1,2,3
ACTION_RESULT_DAMAGE,ACTION_RESULT_CRITICAL_DAMAGE,ACTION_RESULT_DAMAGE_SHIELDED=10,11,12
ACTION_RESULT_EFFECT_GAINED_DURATION,ACTION_RESULT_POWER_ENERGIZE,ACTION_RESULT_EFFECT_FADED=13,14,15
local now,active=100,0
local bindings={[0]={},[1]={}}
function GetFrameTimeSeconds() return now end
function GetActiveHotbarCategory() return active end
function GetSlotBoundId(slot,bar) return bindings[bar][slot] or 0 end
function GetAbilityDuration() return 20000 end
function GetAbilityCastInfo() return false,0,0 end
function IsAbilityDurationToggled() return false end
function GetActionSlotEffectTimeRemaining() return 0 end
function GetActionSlotEffectStackCount() return 0 end
function GetNumBuffs() return 0 end
ObsidianHUD={}
local O=ObsidianHUD
function O.OtherBar(bar) return bar==0 and 1 or bar==1 and 0 end
dofile("TimerSources.lua"); dofile("TimerRules.lua"); dofile("SpecialSkillEffects.lua")
dofile("StackSources.lua"); dofile("SkillTimers.lua"); dofile("StackEffects.lua")
local function bind(id)
    bindings={[0]={[3]=id},[1]={[3]=id}}; now=100; active=0
    O.ResetSkillTimers(); O.ResetStackEffects()
end
local function effect(change,id,slot,began,ending,source,tag,unit)
    O.OnTimerEffectChanged(nil,change,slot,"",tag or "player",began,ending,0,"",0,0,0,0,"",unit or 0,id,source or 1)
end
local function combat(result,id,source,target,isError)
    O.OnTimerCombatEvent(nil,result,isError,"",0,0,"",source or 1,"",target or 9,0,0,0,false,0,42,id)
end
for _,row in ipairs({{24828,24830,24832,24833},{24842,24844,24846,24847},
    {24834,25157,25158,25159,25160,25162}}) do
    bind(row[1]); effect(1,row[1],1,100,120)
    for i=2,#row do effect(1,row[i],i,100,120) end
    assert(O.GetSkillStackCount(3,0)==#row-1,"parent is not an extra mine")
    effect(2,row[2],2,100,120)
    assert(O.GetSkillStackCount(3,0)==#row-1,"updates do not duplicate devices")
    active=1; now=102
    assert(O.GetSkillTimerRemaining(3,0)==18000 and O.GetSkillStackCount(3,1)==#row-1)
    effect(3,row[2],2,100,120)
    assert(O.GetSkillStackCount(3,0)==#row-2,"individual mine consumption")
    effect(1,row[1],1,102,122); effect(1,row[2],2,102,122)
    effect(3,row[2],2,100,120); effect(3,row[1],1,100,120)
    assert(O.GetSkillStackCount(3,0)==1 and O.GetSkillTimerRemaining(3,0)==20000,"old fades cannot clear new placement")
    effect(3,row[1],1,102,122)
    assert(O.GetSkillStackCount(3,0)==0 and O.GetSkillTimerRemaining(3,0)==0)
end
for _,id in ipairs({86175,86179,86183}) do
    bind(id)
    effect(1,id,10,100,120); effect(1,id,11,100,125); effect(1,id,12,100,130)
    effect(2,id,10,100,120)
    assert(O.GetSkillStackCount(3,0)==3 and O.GetSkillTimerRemaining(3,0)==30000)
    effect(1,id,13,100,140,9)
    assert(O.GetSkillStackCount(3,0)==3,"foreign gate ignored")
    now=110; effect(3,id,11,100,125)
    assert(O.GetSkillStackCount(3,0)==2)
    effect(1,id,10,110,135); effect(3,id,10,100,120)
    assert(O.GetSkillStackCount(3,0)==2,"reused device slot survives late fade")
    now=131
    assert(O.GetSkillStackCount(3,0)==1 and O.GetSkillTimerRemaining(3,0)==4000)
    now=136
    assert(O.GetSkillStackCount(3,0)==0 and O.GetSkillTimerRemaining(3,0)==0)
end
for _,id in ipairs(O.skillReflectIds) do
    bind(id); O.OnTimerAbilityUsed(nil,3)
    local expected=(id==86135 or id==86139 or id==86143) and 3 or 1
    assert(O.GetSkillStackCount(3,0)==expected)
    combat(12,id,9,9); assert(O.GetSkillStackCount(3,0)==expected,"other shield not consumed")
    combat(12,id,9,1,true); assert(O.GetSkillStackCount(3,0)==expected)
    combat(12,id,9,1); assert(O.GetSkillStackCount(3,0)==expected-1)
    now=102; O.OnTimerAbilityUsed(nil,3); effect(3,id,1,100,120)
    assert(O.GetSkillStackCount(3,0)==expected,"previous shield fade cannot erase recast")
    effect(3,id,1,102,122)
    assert(O.GetSkillStackCount(3,0)==0,"current shield fade clears remaining charges")
end
for id,rule in pairs(O.timerCombatRules) do
    bind(rule.id or id)
    local result=rule.result and _G[rule.result] or ACTION_RESULT_DAMAGE
    combat(result,id,9); assert(O.GetSkillTimerRemaining(3,0)==0)
    combat(999,id); assert(O.GetSkillTimerRemaining(3,0)==(rule.result and 0 or 20000))
    O.ResetSkillTimers()
    combat(result,id)
    local expected=rule.seconds and rule.seconds*1000 or 20000
    assert(O.GetSkillTimerRemaining(3,0)==expected,"combat-only duration missing for "..id)
    now=102; active=1
    assert(O.GetSkillTimerRemaining(3,0)==expected-2000)
    effect(3,id,1,100,100+expected/1000)
    assert(O.GetSkillTimerRemaining(3,0)==0,"effect fade ends a combat-sourced timer")
end
bind(999001)
for _,row in ipairs({{24330,89491,3.5,8.5},{86009,178020,3,6},
    {86019,146919,3,3},{86015,178028,3,6}}) do
    bind(row[1]); O.OnTimerAbilityUsed(nil,3)
    effect(1,row[1],1,100,120,1,"reticleover",42)
    assert(O.GetSkillStackCount(3,0)==2 and O.GetSkillTimerRemaining(3,0)==row[3]*1000)
    now=100+row[3]; effect(1,row[2],2,now,now+row[4],1,"reticleover",42)
    effect(3,row[1],1,100,120,1,"reticleover",42)
    assert(O.GetSkillStackCount(3,1)==1 and O.GetSkillTimerRemaining(3,1)==row[4]*1000)
    now=now+1; O.OnTimerAbilityUsed(nil,3)
    effect(1,row[1],1,now,now+row[3],1,"reticleover",42)
    effect(3,row[2],2,100+row[3],120,1,"reticleover",42)
    assert(O.GetSkillStackCount(3,0)==2,"old second explosion does not clear a new cast")
end
bind(999001)
effect(1,999001,1,100,110,2,"reticleover",42)
assert(O.GetSkillTimerRemaining(3,0)==10000,"own pet effects accepted")
effect(3,999001,1,100,110,2,"reticleover",42)
assert(O.GetSkillTimerRemaining(3,0)==0)
O.OnSkillStackEffectChanged(nil,1,1,"","player",100,120,2,"",0,0,0,0,"",0,999001,1)
now=102
O.OnSkillStackEffectChanged(nil,2,1,"","player",102,122,4,"",0,0,0,0,"",0,999001,1)
O.OnSkillStackEffectChanged(nil,3,1,"","player",100,120,0,"",0,0,0,0,"",0,999001,1)
assert(O.GetSkillStackCount(3,0)==4,"same-slot old fade cannot clear refreshed stacks")
O.OnSkillStackEffectChanged(nil,1,1,"","player",100,120,2,"",0,0,0,0,"",0,999001,1)
assert(O.GetSkillStackCount(3,0)==4,"late old gain cannot replace new stacks")
print("PASS: mine/gate instances, shield charges, explosion counts, combat-only durations, own pets and same-slot stack refresh ordering")
