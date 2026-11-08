local env=dofile("tests/addon.lua")
local names={"EVENT_MESSAGES","EVENT_FIGHTSUMMARY","MESSAGE_COMBATSTART","EVENT_DAMAGE_OUT","EVENT_DAMAGE_IN","EVENT_DAMAGE_SELF",
    "EVENT_HEAL_OUT","EVENT_HEAL_IN","EVENT_HEAL_SELF","EVENT_EFFECTS_IN","EVENT_EFFECTS_OUT","EVENT_GROUPEFFECTS_IN","EVENT_GROUPEFFECTS_OUT"}
for index,name in ipairs(names) do _G["LIBCOMBAT_"..name]=100+index end
COMBAT_UNIT_TYPE_PLAYER,COMBAT_UNIT_TYPE_PLAYER_PET,COMBAT_UNIT_TYPE_GROUP,COMBAT_UNIT_TYPE_OTHER=1,2,3,4
ACTION_RESULT_DAMAGE,EVENT_COMBAT_EVENT=10,90
function IsConsoleUI() return true end
function GetGameTimeMilliseconds() return GetFrameTimeSeconds()*1000+100000 end
local callbacks={}
LibCombat={name="LibCombat", RegisterForCombatEvent=function(_,_,event,callback) callbacks[event]=callback end,
    GetCurrentFight=function() error("never copy a whole fight on each hit") end}
LibCombat2=nil -- Exercise the optional PC testing fallback.
function GetAbilityName(id) return (id==117624 or id==123699) and "Giftschaedel" or "Light Attack" end
local saved=env.saved()
saved.trackers={{key=1,id=61771,unit="player",scale=1,x=0,y=0}}
ZO_SavedVars.NewAccountWide=function() return saved end
dofile("LiveBuffUptime.lua"); env.events[EVENT_ADD_ON_LOADED](nil,"LiveBuffUptime")
local function send(name,time,...)
    env.setClock(time); local code=_G["LIBCOMBAT_"..name]
    callbacks[code](code,GetGameTimeMilliseconds(),...)
end
local function raw(time,id,value)
    env.setClock(time)
    env.events.LiveBuffUptimeCombatTiming(nil,10,false,"raw",0,0,"player",1,"Boss",4,value,0,0,false,1,900,id)
end
-- Raw-before-library on the first hit used to miss it in our independent meter.
raw(100,16145,1959)
send("EVENT_DAMAGE_OUT",100,10,1,900,16145,1959,1,0)
send("EVENT_MESSAGES",100,LIBCOMBAT_MESSAGE_COMBATSTART)
raw(101,16145,1000)
send("EVENT_DAMAGE_OUT",101,10,1,900,16145,1000,1,50)
-- Library-before-raw must also count exactly once, including own pets.
send("EVENT_DAMAGE_OUT",102,10,2,900,117624,1000,1,0); raw(102,117624,1000)
send("EVENT_DAMAGE_OUT",103,10,1,900,123699,2000,1,0); raw(103,123699,2000)
send("EVENT_DAMAGE_IN",103,10,900,1,99,9000,1,0)
send("EVENT_HEAL_OUT",103,10,1,1,98,7000,1,500)
env.setClock(104)
callbacks[LIBCOMBAT_EVENT_FIGHTSUMMARY](nil,{starttime=200000,endtime=204000,activetime=4,dpstime=3,playerid=1,
    units={[1]={unitType=1},[2]={unitType=2},[900]={unitType=4,name="Boss",dpsstart=201000,dpsend=203500}}})
local report=assert(saved.lastUptimeReport)
assert(report.ownDamage==6009,"CMX hitValue+shield overflow; no healing/incoming/raw double counting or lost first hit")
assert(report.skillDamageDuration==3,"DPS uses the same library dpstime as CMX")
assert(report.enemies[1].duration==2.5,"target DPS uses the same v1 unit.dpsstart/dpsend interval as the CMX target list")
local rows=LiveBuffUptimeReports.SkillRows(report)
assert(#rows==3 and rows[1].id==16145 and rows[1].damage==3009 and rows[1].hits==2)
assert(rows[2].id==123699 and rows[3].id==117624,"same-name damage IDs stay separate")
local list=dofile("tests/helpers/report-console-ui.lua")(env)
LiveBuffUptimeReports.Open(); LiveBuffUptimeReports.ShowZone(); LiveBuffUptimeReports.ShowBuffs(); LiveBuffUptimeReports.SetCategory("skills")
assert(env.controls.LiveBuffUptimeReportTotal.text=="Gesamtschaden  6009")
assert(#list.entries==2 and list.entries[1].skillTargetKey=="all")
assert(env.controls.LiveBuffUptimeReportDeaths1.text=="2 Treffer | ID 16145")
assert(report.skills[1].damage==3009)
LiveBuffUptimeReports.Close()
-- The next fight can open with an enchantment proc before COMBATSTART.
-- Previously the closed-fight guard dropped this first hit permanently.
send("EVENT_HEAL_OUT",110,10,1,1,98,7000,1,0)
assert(saved.lastUptimeReport==report,"post-fight healing must not replace the report")
raw(120,46743,1486)
send("EVENT_DAMAGE_OUT",120,10,1,900,46743,1486,1,0)
send("EVENT_MESSAGES",120,LIBCOMBAT_MESSAGE_COMBATSTART)
send("EVENT_DAMAGE_OUT",121,10,1,900,46743,16170,1,0)
env.setClock(122)
callbacks[LIBCOMBAT_EVENT_FIGHTSUMMARY](nil,{starttime=220000,endtime=222000,activetime=2,dpstime=1,playerid=1,
    units={[1]={unitType=1},[900]={unitType=4,name="Boss"}}})
local nextReport=assert(saved.lastUptimeReport)
assert(nextReport~=report and nextReport.ownDamage==17656,"next fight retains the opening 1486-damage proc")
assert(#nextReport.skills==1 and nextReport.skills[1].hits==2,"only the new fight's two hits are counted")
assert(report.ownDamage==6009,"previous fight stays unchanged")
print("CMX stream: real v1 API shape, first-hit order, raw dedup, shield overflow, own pets, separate IDs and DPS duration")
