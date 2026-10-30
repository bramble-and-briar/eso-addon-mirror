HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP=0,1
COMBAT_UNIT_TYPE_PLAYER,EFFECT_RESULT_FADED=1,3
local now,active=100,0
local bindings={[0]={[3]=101,[4]=301,[5]=401,[6]=501},[1]={[3]=201}}
local native={[0]={[3]=12000,[4]=9000,[5]=99000,[6]=99000},[1]={[3]=8000}}
ObsidianHUD={timerSources={[101]=901,[201]=902,[301]=903},
    timerDisabled={[301]=true},timerPhases={[401]={id=401,phase=1,seconds=3}},
    timerOnUse={[501]=true}}
local O=ObsidianHUD
function O.OtherBar(bar) return bar==0 and 1 or bar==1 and 0 end
function O.IsSharedTimerEffect() return false end
function GetFrameTimeSeconds() return now end
function GetActiveHotbarCategory() return active end
function GetSlotBoundId(slot,bar) return bindings[bar] and bindings[bar][slot] or 0 end
function GetActionSlotEffectTimeRemaining(slot,bar) return native[bar] and native[bar][slot] or 0 end
function GetNumBuffs() return 0 end
function GetSlotCooldownInfo() error("recast cooldown must never become an effect timer") end
function ZO_FormatTimeShowUnitOverThresholdShowDecimalUnderThreshold(seconds) return string.format("%.1f",seconds) end
ZO_ONE_MINUTE_IN_SECONDS,ZO_EFFECT_EXPIRATION_IMMINENCE_THRESHOLD_S,TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT=60,2,1
dofile("SkillTimers.lua"); dofile("Native.lua")
assert(O.GetSkillTimerRemaining(3,0)==12000,"mapped front skill uses native effect time without a captured effect event")
assert(O.BackBarTimerText(3,0)=="12.0")
assert(O.GetSkillTimerRemaining(3,1)==8000 and O.BackBarTimerText(3,1)=="8.0",
    "inactive bar has its own native effect duration")
active=1
assert(O.BackBarTimerText(3,0)=="12.0" and O.BackBarTimerText(3,1)=="8.0")
native[0][3]=7000; now=105
assert(O.GetSkillTimerRemaining(3,0)==7000)
-- An observed mapped effect remains more specific than the native fallback.
O.OnTimerEffectChanged(nil,1,1,"","reticleover",105,109,0,"",0,0,0,0,"",42,901,1)
assert(O.GetSkillTimerRemaining(3,0)==4000)
native[0][3]=0; now=106
assert(O.GetSkillTimerRemaining(3,0)==3000,"native zero cannot erase a known own effect")
now=110
assert(O.GetSkillTimerRemaining(3,0)==0 and O.BackBarTimerText(3,0)=="")
native[1][3]=0
assert(O.GetSkillTimerRemaining(3,1)==0,"native expiry does not leave a guessed countdown")
assert(O.GetSkillTimerRemaining(4,0)==0,"disabled/instant skills remain excluded")
assert(O.GetSkillTimerRemaining(5,0)==0,"unobserved multi-phase skill cannot borrow a long parent timer")
assert(O.GetSkillTimerRemaining(6,0)==0,"special on-use timing cannot borrow a different parent phase")
O.OnTimerEffectChanged(nil,1,2,"","player",110,199,0,"",0,0,0,0,"",0,401,1)
assert(O.GetSkillTimerRemaining(5,0)==3000,"observed phase retains its configured duration")
print("PASS: mapped native skill timers on both bars, own effect priority, expiry, phase exclusions and no cooldown guesses")
