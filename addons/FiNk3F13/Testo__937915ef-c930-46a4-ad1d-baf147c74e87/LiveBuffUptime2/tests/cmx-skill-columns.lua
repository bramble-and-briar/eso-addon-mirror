local env=dofile("tests/addon.lua")
local names={"EVENT_MESSAGES","EVENT_FIGHTSUMMARY","MESSAGE_COMBATSTART","EVENT_DAMAGE_OUT","EVENT_DAMAGE_IN","EVENT_DAMAGE_SELF",
    "EVENT_HEAL_OUT","EVENT_HEAL_IN","EVENT_HEAL_SELF","EVENT_EFFECTS_IN","EVENT_EFFECTS_OUT","EVENT_GROUPEFFECTS_IN","EVENT_GROUPEFFECTS_OUT"}
for index,name in ipairs(names) do _G["LIBCOMBAT_"..name]=100+index end
COMBAT_UNIT_TYPE_PLAYER,COMBAT_UNIT_TYPE_PLAYER_PET,COMBAT_UNIT_TYPE_GROUP=1,2,3
ACTION_RESULT_DAMAGE,ACTION_RESULT_CRITICAL_DAMAGE,ACTION_RESULT_DOT_TICK,ACTION_RESULT_DOT_TICK_CRITICAL,ACTION_RESULT_BLOCKED_DAMAGE=10,11,12,13,14
EVENT_COMBAT_EVENT=90
function GetGameTimeMilliseconds() return GetFrameTimeSeconds()*1000+100000 end
local callbacks={}
LibCombat2=nil
LibCombat={name="LibCombat",RegisterForCombatEvent=function(_,_,event,callback) callbacks[event]=callback end}
local saved=env.saved();saved.trackers={}
ZO_SavedVars.NewAccountWide=function() return saved end
dofile("LiveBuffUptime2.lua");env.events[EVENT_ADD_ON_LOADED](nil,"LiveBuffUptime2")
local function send(name,time,...)
    env.setClock(time);local code=_G["LIBCOMBAT_"..name];callbacks[code](code,GetGameTimeMilliseconds(),...)
end
send("EVENT_MESSAGES",100,LIBCOMBAT_MESSAGE_COMBATSTART)
send("EVENT_DAMAGE_OUT",100,10,1,900,101,1000,1,0)
send("EVENT_DAMAGE_OUT",101,11,1,900,101,2000,1,100)
send("EVENT_DAMAGE_OUT",102,13,1,901,101,900,1,0)
send("EVENT_DAMAGE_OUT",103,12,1,901,101,300,1,0)
send("EVENT_DAMAGE_OUT",104,14,1,900,101,700,1,0)
send("EVENT_DAMAGE_OUT",105,10,2,900,101,400,1,0)
send("EVENT_DAMAGE_OUT",106,10,1,900,202,500,1,0)
send("EVENT_DAMAGE_IN",107,11,900,1,101,99999,1,0)
send("EVENT_HEAL_OUT",108,11,1,1,101,99999,1,0)
-- A duplicate raw damage callback can only add metadata, never another crit/hit.
env.events.LiveBuffUptime2CombatTiming(nil,11,false,"Skill",nil,nil,"player",1,"Boss",4,2000,nil,nil,nil,1,900,101)
env.setClock(110)
callbacks[LIBCOMBAT_EVENT_FIGHTSUMMARY](nil,{starttime=200000,endtime=210000,dpstime=10,playerid=1,
    units={[1]={unitType=1},[2]={unitType=2},[900]={name="Boss",unitType=4},[901]={name="Add",unitType=4}}})
local report=assert(saved.lastUptimeReport)
local reports=LiveBuffUptime2Reports
local all=reports.SkillRows(report)[1]
assert(all.damage==5400 and all.hits==6 and all.criticalHits==2 and all.maxHit==2100)
assert(all.damage/all.hits==900,"average is weighted across all hits, including pets, not an average of target averages")
local boss=reports.SkillRows(report,900)[1]
assert(boss.damage==4200 and boss.hits==4 and boss.criticalHits==1 and boss.maxHit==2100)
local add=reports.SkillRows(report,901)[1]
assert(add.damage==1200 and add.hits==2 and add.criticalHits==1 and add.maxHit==900)
local list=dofile("tests/helpers/report-console-ui.lua")(env)
reports.Open();reports.ShowZone();reports.ShowBuffs();reports.SetCategory("skills")
local controls=env.controls
assert(controls.LiveBuffUptime2ReportCritHits1.text=="2/6")
assert(controls.LiveBuffUptime2ReportCritPercent1.text=="33 %")
assert(controls.LiveBuffUptime2ReportAverage1.text=="900" and controls.LiveBuffUptime2ReportMaximum1.text=="2100")
assert(controls.LiveBuffUptime2ReportCritHits2.text=="0/1" and controls.LiveBuffUptime2ReportCritPercent2.text=="0 %")
assert(controls.LiveBuffUptime2ReportAverage3.text=="" and controls.LiveBuffUptime2ReportMaximum3.text=="","empty rows must stay empty")
local selected
for index,entry in ipairs(list.entries) do if entry.skillTargetKey==901 then selected=index end end
list:SetSelectedIndex(assert(selected))
assert(controls.LiveBuffUptime2ReportCritHits1.text=="1/2" and controls.LiveBuffUptime2ReportAverage1.text=="600")
assert(controls.LiveBuffUptime2ReportMaximum1.text=="900","target max must not inherit a larger hit on another enemy")
reports.SetCategory("buffs")
assert(controls.LiveBuffUptime2ReportCritHits1.hidden and controls.LiveBuffUptime2ReportMaximum1.hidden)
assert(controls.LiveBuffUptime2ReportCovered1.x==362 and controls.LiveBuffUptime2ReportCovered1.width==150,"buff layout is restored")
reports.Close()
local old={started=0,ended=10,buffs={},debuffs={},skills={{id=101,name="Legacy",damage=1000,hits=2}},ownDamage=1000,skillDamageRecorded=true,skillDamageDuration=10}
reports.Init({uptimeHistory={old}});reports.Open();reports.ShowZone();reports.ShowBuffs();reports.SetCategory("skills")
assert(controls.LiveBuffUptime2ReportCritHits1.text=="--/2" and controls.LiveBuffUptime2ReportCritPercent1.text=="--")
assert(controls.LiveBuffUptime2ReportAverage1.text=="500" and controls.LiveBuffUptime2ReportMaximum1.text=="--","legacy crit/max data must not be fabricated")
reports.Close()
assert(report.skills[1].criticalHits==2 and report.skills[1].maxHit==2100,"saved statistics remain frozen")
print("CMX columns: crits/hits, crit percent, weighted average, maximum, DOT/pets, overflow, target filtering, layout reset and honest legacy values passed")
