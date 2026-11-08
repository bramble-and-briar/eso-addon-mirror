local env=dofile("tests/addon.lua")
COMBAT_UNIT_TYPE_PLAYER,COMBAT_UNIT_TYPE_PLAYER_PET,COMBAT_UNIT_TYPE_GROUP,COMBAT_UNIT_TYPE_OTHER=1,2,3,4
ACTION_RESULT_DAMAGE,EVENT_COMBAT_EVENT=10,90
LIBCOMBAT_LOG_EVENT_COMBATSTATE,LIBCOMBAT_LOG_EVENT_DAMAGE,LIBCOMBAT_LOG_EVENT_HEAL,LIBCOMBAT_LOG_EVENT_EFFECT=1,2,3,4
LIBCOMBAT_EVENT_FIGHTSUMMARY,LIBCOMBAT_MESSAGE_COMBATSTART=51,1
local callbacks={}
LibCombat=nil
LibCombat2={RegisterForCombatEvent=function(_,event,callback) callbacks[event]=callback; return true end,
    GetPlayerUnitId=function() return 1 end,
    GetUnitById=function(id) return {GetUnitType=function() return id==1 and 1 or id==2 and 2 or 4 end} end}
function GetGameTimeMilliseconds() return GetFrameTimeSeconds()*1000+100000 end
local saved=env.saved(); saved.trackers={}
ZO_SavedVars.NewAccountWide=function() return saved end
dofile("LiveBuffUptime.lua"); env.events[EVENT_ADD_ON_LOADED](nil,"LiveBuffUptime")
local function send(event,time,...)
    env.setClock(time); callbacks[event](event,GetGameTimeMilliseconds(),...)
end
local function raw(time,id,value,source,kind)
    env.setClock(time)
    env.events.LiveBuffUptimeCombatTiming(nil,10,false,"raw",0,0,"player",kind or 1,"Dummy",4,value,0,0,false,source or 1,900,id)
end
-- The raw opening hit arrives before the library starts its encounter.
raw(100,16145,12345)
send(1,100,1)
send(2,100,10,1,900,16145,12345,1,0)
-- Library first, raw duplicate second; use the library's full damage amount.
send(2,102,10,1,900,46743,100000,1,50); raw(102,46743,100000)
send(2,103,10,2,900,777,500,1,0); raw(103,777,500,2,2)
send(2,104,10,900,1,888,9000,1,0)
send(2,105,10,1,1,999,9000,1,0)
send(3,110,10,1,1,555,5000,1,400)
env.setClock(111)
callbacks[51](51,{info={combatStart=200000,combatEnd=211000},unitIds={player=1},
    units={[1]={unitType=1},[2]={unitType=2},[900]={unitType=4,name="Dummy"}},
    damageDone={[1]={startTime=200000,endTime=202000},[2]={startTime=203000,endTime=203000}},
    healingDone={[1]={startTime=210000,endTime=210000}}})
local report=assert(saved.lastUptimeReport)
assert(report.ownDamage==112845,"native events include the opening hit and pets exactly once, without adding library overflow")
assert(#report.skills==3,"incoming, self damage, healing and raw duplicates are excluded")
assert(report.skillDamageDuration==3,"skill DPS spans only own and own-pet damage, not later healing or incoming damage")
assert(report.skills[1].id==46743 and report.skills[1].damage==100000 and report.skills[1].hits==1)
assert(report.skills[2].damage==12345 and report.skills[2].hits==1)
-- A single-hit encounter without any later damage uses the group clock fallback.
send(1,200,1)
send(2,200,10,1,900,16145,8287,1,0); raw(200,16145,8287)
send(3,205,10,1,1,555,5000,1,0)
env.setClock(206)
callbacks[51](51,{unitIds={player=1},units={[1]={unitType=1},[900]={unitType=4,name="Dummy"}},
    damageDone={[1]={startTime=300000,endTime=300000}},healingDone={[1]={startTime=305000,endTime=305000}}})
assert(saved.lastUptimeReport.ownDamage==8287 and saved.lastUptimeReport.skillDamageDuration==6,
    "a single-hit encounter uses the same current-time fallback as the group display")
assert(report.ownDamage==112845 and report.skillDamageDuration==3,"previous report remains frozen")
print("LibCombat2 skill stream: first hit, raw dedup, full amount, pets and independent damage duration")
