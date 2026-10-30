HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP=0,1
COMBAT_UNIT_TYPE_PLAYER,EFFECT_RESULT_FADED=1,3
local now,active=10,0
local bound,buffs=61503,{}
local durations={[61504]=5000,[61506]=10000,[61509]=5000,[61693]=20000}
function GetSlotBoundId(slot,bar) return ((bar==0 and slot==3) or (bar==1 and slot==4)) and bound or 0 end
function GetActiveHotbarCategory() return active end
function GetFrameTimeSeconds() return now end
function GetAbilityDuration(id) return durations[id] or 20000 end
function GetAbilityCastInfo() return false,0,0 end
function GetActionSlotEffectTimeRemaining() return 20000 end
function GetNumBuffs() return #buffs end
function GetUnitBuffInfo(_,i) return unpack(buffs[i],1,13) end
ObsidianHUD={}
local O=ObsidianHUD
function O.OtherBar(bar) return bar==0 and 1 or bar==1 and 0 end
dofile("TimerSources.lua"); dofile("TimerRules.lua"); dofile("SkillTimers.lua")
local function event(change,id,began,ending,source)
    O.OnTimerEffectChanged(nil,change,7,"","player",began,ending,0,"",0,0,0,0,"",0,id,source or 1)
end
for _,row in ipairs({{61503,61504},{63236,61504},{63238,61504},{63240,61504},
    {61505,61506},{63243,61506},{63245,61506},{63247,61506},
    {61507,61693},{63249,61693},{63252,61693},{63255,61693}}) do
    bound=row[1]; now=10; active=0; buffs={}; O.ResetSkillTimers()
    assert(O.GetSkillTimerRemaining(3,0)==0,"long secondary native timer must not start a Vigor heal")
    O.OnTimerAbilityUsed(nil,3)
    local duration=durations[row[2]]
    assert(O.GetSkillTimerRemaining(3,0)==duration,"all Vigor variants/ranks start from the healing API duration")
    active=1; now=12
    assert(O.GetSkillTimerRemaining(3,0)==duration-2000 and O.GetSkillTimerRemaining(4,1)==duration-2000)
    event(1,row[2]==61693 and 61509 or 61693,12,32)
    assert(O.GetSkillTimerRemaining(4,1)==duration-2000,"the other Vigor effect must not replace the chosen timer")
    O.OnTimerAbilityUsed(nil,4)
    assert(O.GetSkillTimerRemaining(4,1)==duration)
    event(3,row[2],10,10+duration/1000)
    assert(O.GetSkillTimerRemaining(4,1)==duration,"old fade cannot cancel the new cast")
    event(1,row[2],12,15)
    assert(O.GetSkillTimerRemaining(4,1)==3000,"actual healing effect overrides the cast duration")
    event(3,row[2],12,15)
    assert(O.GetSkillTimerRemaining(4,1)==0,"heal fade cannot fall back to the longer native buff")
    O.ResetSkillTimers(); now=20
    buffs={{"chosen",19,23,7,0,"",0,0,0,0,row[2],false,true},
        {"secondary",19,39,8,0,"",0,0,0,0,row[2]==61693 and 61509 or 61693,false,true}}
    if row[2]==61693 then
        assert(O.GetSkillTimerRemaining(4,1)==0,"shared armour buff alone cannot be attributed to an unused Vigor slot")
    else assert(O.GetSkillTimerRemaining(4,1)==3000,"own healing snapshot recovers after reload") end
    O.ResetSkillTimers(); buffs={}
    event(1,row[2],20,25,9)
    assert(O.GetSkillTimerRemaining(4,1)==0,"another player's Vigor does not start ours")
end
bound=61507; active=0; now=100; buffs={}; O.ResetSkillTimers()
durations[61693]=0
O.OnTimerAbilityUsed(nil,3)
assert(O.GetSkillTimerRemaining(3,0)==20000,"Resolving Vigor keeps its requested 20s buff timer if child duration API is unavailable")
print("PASS: Vigor healing variants and Resolving 20s buff, all ranks, recast, both bars, own attribution and API fallback")
