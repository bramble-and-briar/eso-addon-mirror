local env=dofile("tests/addon.lua")
COMBAT_UNIT_TYPE_PLAYER,COMBAT_UNIT_TYPE_PLAYER_PET,COMBAT_UNIT_TYPE_GROUP,COMBAT_UNIT_TYPE_OTHER,COMBAT_UNIT_TYPE_TARGET_DUMMY=1,2,3,4,7
ACTION_RESULT_DAMAGE,EVENT_COMBAT_EVENT=10,90
LIBCOMBAT_LOG_EVENT_COMBATSTATE,LIBCOMBAT_LOG_EVENT_DAMAGE,LIBCOMBAT_LOG_EVENT_HEAL,LIBCOMBAT_LOG_EVENT_EFFECT=1,2,3,4
LIBCOMBAT_EVENT_FIGHTSUMMARY,LIBCOMBAT_MESSAGE_COMBATSTART=51,1
local callbacks={}
LibCombat=nil
LibCombat2={RegisterForCombatEvent=function(_,event,callback) callbacks[event]=callback; return true end,
    GetPlayerUnitId=function() return 1 end,
    GetUnitById=function(id) return {GetUnitType=function() return id==1 and 1 or 4 end} end}
function GetGameTimeMilliseconds() return GetFrameTimeSeconds()*1000+100000 end
local saved=env.saved(); saved.trackers={}
ZO_SavedVars.NewAccountWide=function() return saved end
dofile("LiveBuffUptime.lua"); env.events[EVENT_ADD_ON_LOADED](nil,"LiveBuffUptime")
local function send(event,time,...)
    env.setClock(time); callbacks[event](event,GetGameTimeMilliseconds(),...)
end
local function raw(time,id,value,kind,isError)
    env.setClock(time)
    env.events.LiveBuffUptimeCombatTiming(nil,10,isError or false,"Skill "..id,0,0,"player",kind or 1,"Dummy",7,
        value,0,0,false,kind==2 and 2 or 1,900,id)
end
raw(98,1,999999) -- outside the one-second lookback
raw(100,16499,9715)
send(2,100,10,1,900,16499,9715,1,0) -- can reset live counters before combat start
send(1,100.1,1)
raw(101,25260,100000); send(2,101,10,1,900,25260,100000,1,0)
raw(102,133494,500,2); send(2,102,10,2,900,133494,500,1,0)
send(2,103,10,1,900,16499,2000,1,0); raw(103,16499,2000)
raw(104,123,999999,3); raw(105,123,999999,1,true); raw(106,123,0)
send(3,110,10,1,1,777,5000,1,0)
env.setClock(111)
-- Even the library summary lacks the opening hit: only native events can restore it.
callbacks[51](51,{unitIds={player=1},units={[1]={unitType=1},[900]={unitType=4,name="Dummy"}},
    damageDone={[1]={startTime=201000,endTime=203000,[900]={
        [25260]={totalAmount=100000,totalCount=1,startTime=201000,endTime=201000},
        [16499]={totalAmount=2000,totalCount=1,startTime=203000,endTime=203000}}}}})
local report=assert(saved.lastUptimeReport)
local expectedDamage=9715+100000+500+2000
local expectedTime=math.max(1,103-100) -- ESO ZO_DPSLog: last hit minus first hit, minimum one second
assert(report.ownDamage==expectedDamage and report.skillDamageDuration==expectedTime,
    "native damage and first-hit clock match ESO's dummy log even when LibCombat2 itself lacks the opening hit")
assert(#report.skills==3 and report.skills[2].id==16499 and report.skills[2].hits==2)
assert(report.skills[3].id==133494 and report.skills[3].damage==500,"source type identifies an own pet even before library unit lookup")
assert(report.ownDamage/report.skillDamageDuration==expectedDamage/expectedTime)
raw(200,16499,8287); send(1,200.3,1); send(2,200.3,10,1,900,16499,8287,1,0)
env.setClock(205); callbacks[51](51,{unitIds={player=1},units={}})
assert(saved.lastUptimeReport.ownDamage==8287 and saved.lastUptimeReport.skillDamageDuration==1)
assert(report.ownDamage==expectedDamage,"old report stays immutable")
-- ESO enters combat immediately, while LibCombat2 reports the start much later.
-- Even a correctly sized pre-combat ring cannot recover this hit if anchored
-- to the delayed library message; the native counter must already be running.
raw(300,16499,4068)
env.setClock(300.05)
env.events[EVENT_PLAYER_COMBAT_STATE](nil,true)
raw(300.5,25260,10000)
send(2,300.5,10,1,900,25260,10000,1,0)
send(1,302,1)
raw(303,25260,20000); send(2,303,10,1,900,25260,20000,1,0)
env.setClock(304)
callbacks[51](51,{unitIds={player=1},units={}})
assert(saved.lastUptimeReport.ownDamage==34068 and saved.lastUptimeReport.skillDamageDuration==3,
    "delayed library start must neither expire the opening hit nor reset native damage accumulated after ESO combat start")
assert(saved.lastUptimeReport.skills[1].damage==30000 and saved.lastUptimeReport.skills[1].hits==2)
-- The lookback queue has a fixed 200-event bound.
for i=1,201 do LiveBuffUptimeReports.RecordNativeDamage(399.9,1,7,900,"Dummy",1,123,"Skill") end
LiveBuffUptimeReports.BeginNativeDamage(400,false)
local bounded=LiveBuffUptimeReports.FinishNativeDamage()
assert(bounded.total==200 and bounded.skills[123].hits==200)
print("Native skill damage: precombat ring, library-independent first hit/pets, deduplication, real dummy clock, exclusions and stable reports")
