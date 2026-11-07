local env=dofile("tests/addon.lua")
COMBAT_UNIT_TYPE_PLAYER,COMBAT_UNIT_TYPE_PLAYER_PET,COMBAT_UNIT_TYPE_GROUP,COMBAT_UNIT_TYPE_OTHER=1,2,3,4
LIBCOMBAT_LOG_EVENT_COMBATSTATE,LIBCOMBAT_LOG_EVENT_DAMAGE,LIBCOMBAT_LOG_EVENT_HEAL,LIBCOMBAT_LOG_EVENT_EFFECT=1,2,3,4
LIBCOMBAT_EVENT_FIGHTSUMMARY,LIBCOMBAT_MESSAGE_COMBATSTART=51,1
local callbacks={}
LibCombat=nil
LibCombat2={RegisterForCombatEvent=function(_,event,callback) callbacks[event]=callback; return true end,
    GetPlayerUnitId=function() return 1 end,
    GetUnitById=function(id) return {GetUnitType=function() return id==1 and 1 or id==3 and 3 or 4 end} end}
function GetGameTimeMilliseconds() return GetFrameTimeSeconds()*1000+100000 end
local saved=env.saved(); saved.trackers={}
ZO_SavedVars.NewAccountWide=function() return saved end
dofile("LiveBuffUptime.lua"); env.events[EVENT_ADD_ON_LOADED](nil,"LiveBuffUptime")
local function send(event,time,...)
    env.setClock(time); callbacks[event](event,GetGameTimeMilliseconds(),...)
end
local function leaf(amount,count,first,last)
    return {totalAmount=amount,totalCount=count,startTime=first,endTime=last}
end
-- The opening hit precedes COMBATSTART, which resets the live aggregates.
send(2,100,10,1,900,16499,9715,1,0)
send(1,100,1)
send(2,101,10,1,900,25260,100000,1,0)
-- This source is not yet known to be an own pet in the callback-time API.
send(2,102,10,2,900,133494,500,1,0)
send(2,106,10,1,1,999,10000,1,0)
env.setClock(107)
local fight={unitIds={player=1},units={[1]={unitType=1},[2]={unitType=2},[3]={unitType=3},
    [900]={unitType=4,name="Dummy"},[901]={unitType=4,name="Other dummy"}},
    damageDone={
        [1]={totalAmount=121715,startTime=200000,endTime=206000,
            [900]={totalAmount=109715,startTime=200000,endTime=201000,
                [16499]=leaf(9715,1,200000,200000),[25260]=leaf(100000,6,201000,201000)},
            [901]={[16499]=leaf(2000,2,201000,201000)},
            [1]={[999]=leaf(10000,1,206000,206000)},
            [3]={[999]=leaf(10000,1,206000,206000)}},
        [2]={startTime=202000,endTime=202000,[900]={[133494]=leaf(500,1,202000,202000)}},
        [3]={[900]={[123]=leaf(999999,1,201000,201000)}},
        [900]={[1]={[888]=leaf(999999,1,206000,206000)}}}}
callbacks[51](51,fight)
local report=assert(saved.lastUptimeReport)
assert(report.ownDamage==112215,"complete v2 leaf sums replace partial callbacks; source/target totals are not counted twice")
assert(#report.skills==3 and report.skills[1].damage==100000 and report.skills[1].hits==6)
assert(report.skills[2].id==16499 and report.skills[2].damage==11715 and report.skills[2].hits==3,
    "opening hit and same ability on another target are restored")
assert(report.skills[3].id==133494 and report.skills[3].damage==500,"final unit identity restores initially unclassified own-pet damage")
assert(report.skillDamageDuration==2,"friendly/self damage cannot extend the authoritative DPS window")
local enemyTotal=0
for _,target in ipairs(report.enemies) do enemyTotal=enemyTotal+target.damage end
assert(enemyTotal==report.ownDamage and report.enemies[1].name=="Dummy","enemy totals and names match the restored skills")
fight.damageDone[1][900][16499].totalAmount=999999
assert(report.skills[2].damage==11715,"report owns copies, not references into mutable library data")
-- A fresh encounter cannot inherit any previous damage or hits.
send(1,200,1); send(2,200,10,1,900,16499,100,1,0)
env.setClock(201)
callbacks[51](51,{unitIds={player=1},units=fight.units,
    damageDone={[1]={startTime=300000,endTime=300000,[900]={[16499]=leaf(100,1,300000,300000)}}}})
assert(saved.lastUptimeReport.ownDamage==100 and saved.lastUptimeReport.skills[1].hits==1)
assert(report.ownDamage==112215)
print("LibCombat2 final snapshot: early hits, late pet identity, multi-target IDs, full counts, damage window, ownership filters and frozen copies")
