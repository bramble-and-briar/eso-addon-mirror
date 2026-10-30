-- Actual client slot from Screenshot_12: Front S4, ID 118763, native timer 0.
HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP=0,1
COMBAT_UNIT_TYPE_PLAYER,EFFECT_RESULT_FADED=1,3
local now,active,raw=100,0,118763
function GetSlotBoundId(slot,bar) return slot==4 and raw or 0 end
function GetActiveHotbarCategory() return active end
function GetFrameTimeSeconds() return now end
function GetAbilityDuration() return 0 end
function GetAbilityCastInfo() return true,0,0 end
function IsAbilityDurationToggled() return true end
function GetActionSlotEffectTimeRemaining() return 0 end
function GetNumBuffs() return 0 end
function GetUnitBuffInfo() end
function ZO_FormatTimeShowUnitOverThresholdShowDecimalUnderThreshold(s) return string.format("%.1f",s) end
ZO_ONE_MINUTE_IN_SECONDS,ZO_EFFECT_EXPIRATION_IMMINENCE_THRESHOLD_S,TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT=60,2,1
ObsidianHUD={}
local O=ObsidianHUD
function O.OtherBar(bar) return bar==0 and 1 or bar==1 and 0 end
dofile("SkillTracking.lua"); dofile("TimerSources.lua"); dofile("TimerRules.lua")
dofile("SkillTimers.lua"); dofile("Native.lua"); dofile("SkillText.lua")
function O.NoSkillAnimationsView() return false end
function O.FixedSkillRows() return false end
function O.UpdateSkillPreview() end
function O.UpdateFixedSkillBindings() end
function O.UpdateSkillProcHighlight() end
function O.UpdateStackText() end
local function label() return {SetText=function(self,v) self.text=v end} end
for _,row in ipairs({{115924,116445,20},{118008,118009,20},{118763,118764,20},
    {115926,116450,12},{118122,118123,12},{118070,118071,12}}) do
    raw=row[1]; active=0; now=100; O.ResetSkillTimers()
    O.OnTimerAbilityUsed(nil,4)
    assert(GetSlotBoundId(4,0)==row[1] and O.timerAliases[row[1]]==row[2] and O.GetTimerSource(row[2])==row[1],
        "live child slot ID must resolve to its configured activation rule")
    assert(O.GetSkillTimerRemaining(4,0)==row[3]*1000 and GetActionSlotEffectTimeRemaining(4,0)==0)
    now=102
    local skin={activeTextVisible=true,activeTextBar=0,activeTextSlot=4,button={},
        activeTimer=label(),activeStacks=label()}
    O.UpdateActiveSkillText(skin)
    assert(skin.activeTimer.text==string.format("%.1f",row[3]-2),"real timer-to-label path must display the child-slot timer")
    active=1
    assert(O.BackBarTimerText(4,0)==skin.activeTimer.text,"inactive bar retains the same resolved timer")
    O.OnTimerEffectChanged(nil,1,9,"","player",102,107,0,"",0,0,0,0,"",0,row[1],1)
    assert(O.GetSkillTimerRemaining(4,0)==5000)
    O.OnTimerEffectChanged(nil,3,9,"","player",102,107,0,"",0,0,0,0,"",0,row[1],1)
    assert(O.GetSkillTimerRemaining(4,0)==0)
end
print("PASS: screenshot Siphon ID 118763 and all corpse child-slot variants, cast-to-label countdown, swaps and actual fade")
