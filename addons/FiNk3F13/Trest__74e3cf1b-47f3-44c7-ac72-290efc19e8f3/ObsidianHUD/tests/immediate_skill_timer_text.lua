HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP=0,1
COMBAT_UNIT_TYPE_PLAYER,EFFECT_RESULT_FADED=1,3
CT_CONTROL,DT_HIGH,DL_TEXT,CENTER,TOPRIGHT=1,2,3,4,5
local now,raw=100,118763
local function control(w,h)
    local c={w=w or 64,h=h or 64,handlers={}}
    function c:SetAnchorFill(target) self.fill=target end
    function c:GetWidth() return self.fill and self.fill:GetWidth() or self.w end
    function c:GetHeight() return self.fill and self.fill:GetHeight() or self.h end
    function c:SetAnchor(...) self.anchor={...} end
    function c:SetText(text) self.text=text end
    function c:SetHidden(v) self.hidden=v end
    function c:SetHandler(name,callback) self.handlers[name]=callback end
    for _,name in ipairs({"SetMouseEnabled","SetDrawTier","SetDrawLayer","SetDrawLevel"}) do c[name]=function() end end
    return c
end
WINDOW_MANAGER={CreateControl=function() return control() end}
function GetActiveHotbarCategory() return 0 end
function GetSlotBoundId(slot) return slot==4 and raw or 0 end
function GetFrameTimeSeconds() return now end
function GetAbilityDuration(id) return (id==114317 or id==118680 or id==118726) and 20000 or 0 end
function GetAbilityCastInfo() return false,0,0 end
function GetActionSlotEffectTimeRemaining() return 0 end
function GetNumBuffs() return 0 end
function GetUnitBuffInfo() end
function ZO_FormatTimeShowUnitOverThresholdShowDecimalUnderThreshold(s) return string.format("%.1f",s) end
ZO_ONE_MINUTE_IN_SECONDS,ZO_EFFECT_EXPIRATION_IMMINENCE_THRESHOLD_S,TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT=60,2,1
ObsidianHUD={}
local O=ObsidianHUD
function O.OtherBar(bar) return bar==0 and 1 or bar==1 and 0 end
dofile("TimerSources.lua"); dofile("TimerRules.lua"); dofile("SkillTimers.lua")
dofile("Native.lua"); dofile("SkillText.lua")
function O.Label() return control() end
function O.NoSkillAnimationsView() return false end
function O.UpdateSkillPreview() end
function O.UpdateFixedSkillBindings() end
function O.UpdateSkillProcHighlight() end
function O.GetSkillStackCount() return 3 end
local finishes=0
function O.FinishNativeSkillAnimations() finishes=finishes+1 end
local nativeIcon=control(0,0)
nativeIcon.hidden=true
local slot=control(64,64)
local skin={button={slot=slot,icon=nativeIcon},back=control(),backIcon=control(),
    activeTextVisible=true,activeTextBar=0,activeTextSlot=4}
O.CreateSkillText(skin)
skin.textRoot:SetHidden(false)
assert(skin.textRoot.fill==slot and skin.activeTimer.anchor[2]==slot and skin.activeStacks.anchor[2]==slot)
O.OnTimerAbilityUsed(nil,4)
assert(skin.activeTimer.text=="20.0" and skin.activeStacks.text=="3",
    "use event populates timer and stacks immediately, without waiting for tick/OnUpdate or icon animation")
assert(skin.textRoot:GetWidth()==64 and skin.textRoot:GetHeight()==64,
    "text aperture does not collapse with zero-sized animated icon")
now=105; skin.textRoot.handlers.OnUpdate()
assert(skin.activeTimer.text=="15.0")
O.OnTimerAbilityUsed(nil,4)
assert(skin.activeTimer.text=="20.0","recast text refresh is immediate too")
assert(nativeIcon.w==0 and nativeIcon.h==0 and finishes==0,"native animation is not stopped or resized")
skin.activeTextVisible=false; skin.activeTimer.text="hidden"
O.OnTimerAbilityUsed(nil,4)
assert(skin.activeTimer.text=="hidden","cast cannot force hidden HUD text to appear")
skin.activeTextVisible=true
for _,id in ipairs({114317,118680,118726}) do
    raw=id; now=200; O.ResetSkillTimers(); skin.activeTimer.text=""
    O.OnTimerAbilityUsed(nil,4)
    assert(skin.activeTimer.text=="20.0","skeletal summon timer appears on use before its delayed effect event and animation completion")
    now=200.5
    O.OnTimerEffectChanged(nil,1,5,"","player",200,220,0,"",0,0,0,0,"",0,id,1)
    skin.textRoot.handlers.OnUpdate()
    assert(skin.activeTimer.text=="19.5")
    now=203; O.OnTimerAbilityUsed(nil,4)
    assert(skin.activeTimer.text=="20.0","skeletal summon recast updates immediately")
    assert(nativeIcon.w==0 and finishes==0)
end
print("PASS: immediate cast/recast timer and stacks on stable slot while icon is collapsed; animation and HUD visibility preserved")
