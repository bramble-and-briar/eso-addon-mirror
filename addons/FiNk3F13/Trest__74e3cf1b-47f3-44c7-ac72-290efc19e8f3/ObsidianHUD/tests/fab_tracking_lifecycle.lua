HOTBAR_CATEGORY_PRIMARY,HOTBAR_CATEGORY_BACKUP=0,1
ACTION_TYPE_CRAFTED_ABILITY,ACTION_TYPE_ABILITY=10,11
COMBAT_UNIT_TYPE_PLAYER,COMBAT_UNIT_TYPE_PLAYER_PET,EFFECT_RESULT_FADED=1,2,3
local now,active,crafted=100,0,23806
local bindings={[0]={[3]=42,[4]=20816,[5]=38745,[6]=999001},[1]={[3]=42,[4]=999002}}
local state={}
local function slotState(slot,bar) return state[tostring(bar)..":"..slot] or {remain=0,count=0} end
function GetSlotBoundId(slot,bar) return bindings[bar] and bindings[bar][slot] or 0 end
function GetSlotType(slot,bar) return GetSlotBoundId(slot,bar)==42 and ACTION_TYPE_CRAFTED_ABILITY or ACTION_TYPE_ABILITY end
function GetAbilityIdForCraftedAbilityId(id) assert(id==42); return crafted end
function GetFrameTimeSeconds() return now end
function GetActiveHotbarCategory() return active end
function GetActionSlotEffectTimeRemaining(slot,bar) return slotState(slot,bar).remain end
function GetActionSlotEffectStackCount(slot,bar) return slotState(slot,bar).count end
function GetNumBuffs() return 0 end
function GetUnitBuffInfo() end
function GetAbilityDuration() return 10000 end
function GetAbilityCastInfo() return false,0,0 end
ObsidianHUD={}
local O=ObsidianHUD
function O.OtherBar(bar) return bar==0 and 1 or bar==1 and 0 end
dofile("SkillTracking.lua"); dofile("TimerSources.lua"); dofile("TimerRules.lua")
dofile("StackSources.lua"); dofile("SkillTimers.lua"); dofile("StackEffects.lua")
local function event(change,id,count,began,ending,unit,source,tag)
    O.OnSkillStackEffectChanged(nil,change,1,"",tag or "reticleover",began,ending,count,"",0,0,0,0,"",unit,id,source or 1)
end
assert(O.GetSkillAbilityId(3,0)==23806,"crafted grimoire resolves to its real ability")
O.OnTimerAbilityUsed(nil,3)
O.OnTimerEffectChanged(nil,1,1,"","player",100,112,7,"",0,0,0,0,"",0,256798,1)
event(1,256798,7,100,112,0,1,"player")
assert(O.GetSkillTimerRemaining(3,0)==12000 and O.GetSkillTimerRemaining(3,1)==12000)
assert(O.GetSkillStackCount(3,0)==7 and O.GetSkillStackCount(3,1)==7)
event(1,20824,3,100,115,0,1,"player")
assert(O.GetSkillStackCount(4,0)==3,"shield counter uses its dedicated effect ID")
event(1,999001,4,100,115,0,1,"player")
assert(O.GetSkillStackCount(6,0)==4,"unlisted slotted ability accepts its own real stack event")
event(1,38747,2,100,110,42)
event(1,38747,3,100,115,43)
assert(O.GetSkillStackCount(5,0)==3,"target stacks use the greatest real count, not the number of targets or sum")
event(3,38747,0,100,115,43)
assert(O.GetSkillStackCount(5,0)==2,"one target fading does not erase another target")
event(1,38747,9,100,115,44,9)
assert(O.GetSkillStackCount(5,0)==2,"foreign target stacks are ignored")
now=105
event(1,38747,1,105,115,42)
event(3,38747,0,100,110,42)
assert(O.GetSkillStackCount(5,0)==1,"old fade cannot erase a refreshed target")
event(3,38747,0,105,115,42)
assert(O.GetSkillStackCount(5,0)==0)
event(1,38747,3,105,115,42)
state["0:5"]={remain=10000,count=3}
assert(O.GetSkillStackCount(5,0)==3)
state["0:5"]={remain=10000,count=0}
assert(O.GetSkillStackCount(5,0)==0,"native consumption must not resurrect old target stacks")
event(1,38747,2,106,116,42)
assert(O.GetSkillStackCount(5,0)==2,"a fresh own target event restores its new counter")
active=1; now=106
state["1:4"]={remain=9000,count=5}
O.OnTimerSlotEffectUpdated(nil,1,4); O.OnSkillStackSlotUpdated(nil,1,4)
assert(O.GetSkillTimerRemaining(4,1)==9000 and O.GetSkillStackCount(4,1)==5)
active=0; now=108; state["1:4"]={remain=0,count=0}
assert(O.GetSkillTimerRemaining(4,1)==7000 and O.GetSkillStackCount(4,1)==5,
    "inactive API gaps keep only actually observed slot time and stacks")
O.OnTimerSlotEffectUpdated(nil,1,4); O.OnSkillStackSlotUpdated(nil,1,4)
assert(O.GetSkillTimerRemaining(4,1)==0 and O.GetSkillStackCount(4,1)==0,
    "explicit zero slot events clear cached timers and consumed stacks")
bindings[1][5]=999004; state["1:5"]={remain=10000,count=0}
O.OnTimerSlotEffectUpdated(nil,1,5)
state["1:5"]={remain=0,count=0}
O.OnTimerEffectChanged(nil,3,1,"","reticleover",106,116,0,"",0,0,0,0,"",42,999004,1)
assert(O.GetSkillTimerRemaining(5,1)==0,"own effect fade clears an inactive native observation too")
state["1:4"]={remain=9000,count=2}
O.OnTimerSlotEffectUpdated(nil,1,4); O.OnSkillStackSlotUpdated(nil,1,4)
state["1:4"]={remain=0,count=0}; bindings[1][4]=999003
assert(O.GetSkillTimerRemaining(4,1)==0 and O.GetSkillStackCount(4,1)==0,
    "replaced ability cannot borrow the previous slot occupant's state")
O.ResetSkillTimers(); O.ResetStackEffects()
assert(O.GetSkillTimerRemaining(3,0)==0 and O.GetSkillStackCount(3,0)==0)
crafted=0
assert(O.GetSkillAbilityId(3,0)==0)
print("PASS: FAB-style lifecycle, crafted IDs, both-bar timers/stacks, mapped counters, per-target fades and inactive slot observations")
