local env=dofile("tests/addon.lua")
COMBAT_UNIT_TYPE_PLAYER,COMBAT_UNIT_TYPE_PLAYER_PET,COMBAT_UNIT_TYPE_GROUP=1,2,3
ACTION_RESULT_DAMAGE,ACTION_RESULT_CRITICAL_DAMAGE,ACTION_RESULT_DOT_TICK_CRITICAL=10,11,13
EVENT_COMBAT_EVENT=90
LIBCOMBAT_LOG_EVENT_COMBATSTATE,LIBCOMBAT_LOG_EVENT_DAMAGE,LIBCOMBAT_LOG_EVENT_HEAL,LIBCOMBAT_LOG_EVENT_EFFECT=1,2,3,4
LIBCOMBAT_EVENT_FIGHTSUMMARY,LIBCOMBAT_MESSAGE_COMBATSTART=51,1
function GetGameTimeMilliseconds() return GetFrameTimeSeconds()*1000+100000 end
local callbacks={}
LibCombat2={RegisterForCombatEvent=function(_,event,callback) callbacks[event]=callback;return true end,
 GetPlayerUnitId=function() return 1 end,GetUnitById=function(id) return {GetUnitType=function() return id==1 and 1 or id==2 and 2 or 4 end} end}
LibCombat={RegisterForCombatEvent=function() error("LibCombat2 must be preferred") end}
local saved=env.saved();saved.trackers={}
ZO_SavedVars.NewAccountWide=function() return saved end
dofile("LiveBuffUptime2.lua");env.events[EVENT_ADD_ON_LOADED](nil,"LiveBuffUptime2")
local function raw(time,result,amount,source,target)
 env.setClock(time)
 env.events.LiveBuffUptime2CombatTiming(nil,result,false,"Skill",nil,nil,"player",source,"Enemy",4,amount,nil,nil,nil,source,target,101)
end
raw(100,11,2000,1,900) -- opening crit buffered before library combat start
env.setClock(100);callbacks[1](1,200000,1)
raw(102,10,1000,1,900)
raw(104,13,500,2,901)
raw(106,11,99999,3,900) -- group damage must not enter own crit stats
env.setClock(110)
callbacks[51](51,{unitIds={player=1},units={[1]={unitType=1},[2]={unitType=2},[900]={unitType=4,name="Boss"},[901]={unitType=4,name="Add"}}})
local report=assert(saved.lastUptimeReport)
local all=LiveBuffUptime2Reports.SkillRows(report)[1]
assert(all.damage==3500 and all.hits==3 and all.criticalHits==2 and all.maxHit==2000)
local boss=LiveBuffUptime2Reports.SkillRows(report,900)[1]
assert(boss.damage==3000 and boss.hits==2 and boss.criticalHits==1 and boss.maxHit==2000)
local add=LiveBuffUptime2Reports.SkillRows(report,901)[1]
assert(add.damage==500 and add.criticalHits==1 and add.maxHit==500)
print("Console skill columns: LibCombat2 preference, buffered opening crit, native pet DOTs, target stats and group exclusion passed")
