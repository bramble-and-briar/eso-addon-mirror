HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP=0,1
COMBAT_UNIT_TYPE_PLAYER,COMBAT_UNIT_TYPE_PLAYER_PET=1,2
EFFECT_RESULT_FADED=3
local now,active,slotId,slotIndex,toggled,channeled=100,0,0,3,false,false
local durationAvailable=true
function GetActiveHotbarCategory() return active end
function GetFrameTimeSeconds() return now end
function GetSlotBoundId(slot,bar) return slot==slotIndex and slotId or 0 end
function GetAbilityDuration() return durationAvailable and 7000 or 0 end
function GetAbilityCastInfo() return channeled,0,0 end
function IsAbilityDurationToggled() return toggled end
function GetActionSlotEffectTimeRemaining() return 0 end
function GetActionSlotEffectStackCount() return 0 end
function GetNumBuffs() return 0 end
function GetUnitBuffInfo() end
ObsidianHUD={}
local O=ObsidianHUD
function O.OtherBar(bar) return bar==0 and 1 or bar==1 and 0 end
dofile("TimerSources.lua"); dofile("TimerRules.lua"); dofile("StackSources.lua")
dofile("SkillTimers.lua"); dofile("StackEffects.lua")
local function timerEvent(change,id,source,began,ending)
    O.OnTimerEffectChanged(nil,change,7,"","reticleover",began or now,ending or now+5,0,"",0,0,0,0,"",42,id,source or 1)
end
local timerCases,stackCases,onUseCases=0,0,0
for id,effect in pairs(O.timerSources) do
    local excluded=O.timerDisabled[id] or O.timerCounterOnly[effect]
    for bar=0,1 do
        active=bar
        for slot=3,8 do
            slotId,slotIndex,now=id,slot,100
            O.ResetSkillTimers(); O.OnTimerAbilityUsed(nil,slot)
            local before=O.GetSkillTimerRemaining(slot,bar)
            timerEvent(1,effect,9)
            assert(O.GetSkillTimerRemaining(slot,bar)==before,"foreign timer contamination for "..id)
            timerEvent(1,effect,1)
            local expected=excluded and 0 or 5000
            assert(O.GetSkillTimerRemaining(slot,bar)==expected,"mapped timer missing on slot/bar for "..id)
            active=O.OtherBar(bar); now=101
            assert(O.GetSkillTimerRemaining(slot,bar)==(excluded and 0 or 4000))
            timerEvent(3,effect,1,100,105)
            assert(O.GetSkillTimerRemaining(slot,bar)==0,"faded mapped timer remained for "..id)
            timerCases=timerCases+1
        end
    end
end
for id,source in pairs(O.stackSources) do
    for bar=0,1 do
        active=bar
        for slot=3,8 do
            slotId,slotIndex,now=id,slot,100
            O.ResetStackEffects()
            O.OnSkillStackEffectChanged(nil,1,7,"","player",100,110,3,"",0,0,0,0,"",0,source,1)
            assert(O.GetSkillStackCount(slot,bar)==3,"mapped stacks missing for "..id)
            active=O.OtherBar(bar)
            assert(O.GetSkillStackCount(slot,bar)==3)
            O.OnSkillStackEffectChanged(nil,3,7,"","player",100,110,0,"",0,0,0,0,"",0,source,1)
            assert(O.GetSkillStackCount(slot,bar)==0,"consumed mapped stacks remained for "..id)
            stackCases=stackCases+1
        end
    end
end
-- Every explicit activation rule has priority over generic channel/toggle
-- metadata. Normal unknown channels/toggles must still get no guessed timer.
for id in pairs(O.timerOnUse) do
    for _,toggle in ipairs({false,true}) do
        for _,channel in ipairs({false,true}) do
            toggled,channeled=toggle,channel
            active=0; slotId,slotIndex,now=id,3,100
            O.ResetSkillTimers(); O.OnTimerAbilityUsed(nil,3)
            assert(O.GetSkillTimerRemaining(3,0)>0,"explicit activation rule blocked by metadata for "..id)
            onUseCases=onUseCases+1
        end
    end
end
durationAvailable=false
for _,row in ipairs({{116445,115924,20},{118009,118008,20},{118764,118763,20},
    {116450,115926,12},{118123,118122,12},{118071,118070,12}}) do
    active=0; slotId,slotIndex,now=row[1],3,100
    O.ResetSkillTimers(); O.OnTimerAbilityUsed(nil,3)
    assert(O.GetSkillTimerRemaining(3,0)==row[3]*1000,"Siphon/tether fallback failed with channel/toggle metadata")
    timerEvent(1,row[2],1,100,106)
    assert(O.GetSkillTimerRemaining(3,0)==6000)
    timerEvent(3,row[2],1,100,106)
    assert(O.GetSkillTimerRemaining(3,0)==0)
end
slotId=999001; O.ResetSkillTimers(); O.OnTimerAbilityUsed(nil,3)
assert(O.GetSkillTimerRemaining(3,0)==0,"ordinary unknown channel/toggle gets no fabricated duration")
print("PASS: systematic skill matrix: "..timerCases.." timer, "..stackCases.." stack, "..onUseCases.." metadata cases plus all corpse tethers")
