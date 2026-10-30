HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP=0,1
COMBAT_UNIT_TYPE_PLAYER,EFFECT_RESULT_FADED=1,3
local now,active,raw=100,0,118763
local buffs={}
function GetActiveHotbarCategory() return active end
function GetFrameTimeSeconds() return now end
function GetSlotBoundId(slot) return slot==4 and raw or 0 end
function GetAbilityDuration() return 0 end
function GetAbilityCastInfo() return false,0,0 end
function IsAbilityDurationToggled() return false end
function GetActionSlotEffectTimeRemaining() return 0 end
function GetNumBuffs() return #buffs end
function GetUnitBuffInfo(_,i) return unpack(buffs[i],1,13) end
ObsidianHUD={}
local O=ObsidianHUD
function O.OtherBar(bar) return bar==0 and 1 or bar==1 and 0 end
dofile("TimerSources.lua"); dofile("TimerRules.lua"); dofile("SkillTimers.lua")
local function event(change,id,began,ending,slot,unit)
    O.OnTimerEffectChanged(nil,change,slot or 9,"","player",began,ending,0,"",0,0,0,0,"",unit or 0,id,1)
end
for _,row in ipairs({{115924,20},{118008,20},{118763,20},{115926,12},{118122,12},{118070,12}}) do
    raw=row[1]; now=100; active=0; O.ResetSkillTimers()
    O.OnTimerAbilityUsed(nil,4)
    assert(O.GetSkillTimerRemaining(4,0)==row[2]*1000)
    -- Only a cast timer was available: the old effect's empty-timestamp fade
    -- arrives after the next use but before its first observed gain.
    now=103; O.OnTimerAbilityUsed(nil,4)
    event(3,raw,0,0)
    assert(O.GetSkillTimerRemaining(4,0)==row[2]*1000,"replacement fade must not cancel the second Siphon activation")
    event(1,raw,103,103+row[2])
    for i=1,3 do
        local previousBegin=now
        now=now+2
        O.OnTimerAbilityUsed(nil,4)
        -- New gain first, old fade second, same reused effect slot.
        event(1,raw,now,now+row[2])
        event(3,raw,0,0)
        assert(O.GetSkillTimerRemaining(4,0)==row[2]*1000,"late timestamp-free old fade must preserve the refreshed effect")
        active=1
        assert(O.GetSkillTimerRemaining(4,0)==row[2]*1000)
        active=0
    end
    -- Having consumed the retired fade, a genuine current fade still ends it.
    event(3,raw,0,0)
    assert(O.GetSkillTimerRemaining(4,0)==0,"the current effect must still be able to end")
end
-- Same ordering for an ordinary event-driven skill, without any Siphon rule.
raw=999001; now=200; O.ResetSkillTimers()
O.OnTimerAbilityUsed(nil,4); event(1,raw,200,210)
now=202; O.OnTimerAbilityUsed(nil,4)
event(1,raw,202,214); event(3,raw,0,0)
assert(O.GetSkillTimerRemaining(4,0)==12000,"generic refresh survives old un-timestamped fade")
event(3,raw,202,214)
assert(O.GetSkillTimerRemaining(4,0)==0)
O.ResetSkillTimers()
assert(O.GetSkillTimerRemaining(4,0)==0)
for _,withEvent in ipairs({false,true}) do
    raw=118763; now=300; O.ResetSkillTimers(); buffs={}
    O.OnTimerAbilityUsed(nil,4)
    if withEvent then event(1,raw,300,320) end
    buffs={{"Siphon",300,320,50,0,"",0,0,0,0,raw,false,true}}
    assert(O.GetSkillTimerRemaining(4,0)==20000)
    now=302; O.OnTimerAbilityUsed(nil,4)
    event(1,raw,302,322)
    buffs={{"Siphon",302,322,50,0,"",0,0,0,0,raw,false,true}}
    event(3,raw,0,0)
    assert(O.GetSkillTimerRemaining(4,0)==20000,"old buff snapshot and native event identify one retired activation")
    event(3,raw,0,0)
    assert(O.GetSkillTimerRemaining(4,0)==0,"snapshot tombstone cannot swallow the genuine current fade")
end
print("PASS: repeated Siphon and generic skill recasts, old fades before/after new gain, missing timestamps, bar swaps and genuine expiry")
