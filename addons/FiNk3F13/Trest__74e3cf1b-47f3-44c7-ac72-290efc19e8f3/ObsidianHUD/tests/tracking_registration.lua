ObsidianHUD={name="ObsidianHUD",defaults={},textRevision=0}
local O=ObsidianHUD
for i,name in ipairs({"EVENT_ADD_ON_LOADED","EVENT_PLAYER_ACTIVATED","EVENT_PLAYER_DEACTIVATED",
    "EVENT_POWER_UPDATE","EVENT_GAMEPAD_PREFERRED_MODE_CHANGED","EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED",
    "EVENT_EFFECT_CHANGED","EVENT_ACTION_SLOT_ABILITY_USED","EVENT_ACTION_SLOT_EFFECT_UPDATE","EVENT_COMBAT_EVENT"}) do _G[name]=i end
COMBAT_UNIT_TYPE_PLAYER,COMBAT_UNIT_TYPE_PLAYER_PET=1,2
SETTING_TYPE_UI,UI_SETTING_SHOW_ACTION_BAR_TIMERS=1,2
REGISTER_FILTER_UNIT_TAG,REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE,REGISTER_FILTER_ABILITY_ID=1,2,3
local timerSetting,writes="0",0
function GetSetting(group,key) assert(group==1 and key==2); return timerSetting end
function SetSetting() writes=writes+1; error("protected SetSetting must not be called by the HUD") end
function GetSlotBoundId() return 0 end
local handlers,filters={},{}
EVENT_MANAGER={}
function EVENT_MANAGER:RegisterForEvent(name,event,handler) handlers[name..":"..event]=handler end
function EVENT_MANAGER:UnregisterForEvent() end
function EVENT_MANAGER:RegisterForUpdate() end
function EVENT_MANAGER:AddFilterForEvent(name,event,kind,value) filters[name]={kind,value} end
ZO_SavedVars={NewAccountWide=function() return {enabled=true,fantasyLayout=true} end}
SLASH_COMMANDS=setmetatable({},{__newindex=function() error("release addon must not register slash commands") end})
for _,name in ipairs({"ApplyFixedFeatures","CreateUI","CreateMoveUI","CreateNativeMoveUI","CreateSettings","Layout"}) do O[name]=function() end end
dofile("SkillTracking.lua"); dofile("TimerSources.lua"); dofile("TimerRules.lua"); dofile("SpecialSkillEffects.lua")
dofile("SkillTimers.lua"); dofile("ObsidianHUD.lua")
handlers[O.name..":"..EVENT_ADD_ON_LOADED](nil,O.name)
assert(writes==0,"loading alone does not change settings before HUD activation")
O.Refresh(); assert(writes==0,"refresh with game timers off must not call protected settings")
timerSetting="1"; O.Refresh(); assert(writes==0,"enabled game timers are not rewritten")
timerSetting="0"; O.vars.enabled=false; O.Refresh(); assert(writes==0)
local petKey=O.name.."TimerPetEffects"
assert(handlers[petKey..":"..EVENT_EFFECT_CHANGED]==O.OnTimerEffectChanged)
assert(filters[petKey][1]==REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE and filters[petKey][2]==COMBAT_UNIT_TYPE_PLAYER_PET)
local function registered(id)
    local key=O.name.."TimerImpact"..id
    assert(handlers[key..":"..EVENT_COMBAT_EVENT]==O.OnTimerCombatEvent,"missing actual combat callback "..id)
    assert(filters[key][1]==REGISTER_FILTER_ABILITY_ID and filters[key][2]==id)
end
for id in pairs(O.timerExplosions) do registered(id) end
for id in pairs(O.timerCombatRules) do registered(id) end
for _,id in ipairs(O.skillReflectIds) do registered(id) end
O.vars.enabled=true; SetSetting=nil; O.Refresh(); assert(writes==0)
print("PASS: initialization and refresh never call protected settings; combat/own-pet timer tracking remains registered")
