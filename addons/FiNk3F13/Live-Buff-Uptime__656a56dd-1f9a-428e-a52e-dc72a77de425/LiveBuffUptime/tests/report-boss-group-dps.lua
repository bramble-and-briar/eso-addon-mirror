local env=dofile("tests/addon.lua")
local clock=0
ACTION_RESULT_DAMAGE=1
COMBAT_UNIT_TYPE_PLAYER,COMBAT_UNIT_TYPE_PLAYER_PET,COMBAT_UNIT_TYPE_GROUP=1,2,3
function GetGameTimeMilliseconds() return 100000+clock end
function GetFrameTimeSeconds() return clock/1000 end
function DoesUnitExist(tag) return tag=="player" or tag=="boss1" end
function GetRawUnitName(tag) return tag=="boss1" and "Boss" or "Player" end
function GetUnitName(tag) return GetRawUnitName(tag) end
dofile("../SimpleGroupDPS/DamageMeter.lua")
local meter,reports=SimpleGroupDPS_DamageMeter,LiveBuffUptimeReports
local list=dofile("tests/helpers/report-console-ui.lua")(env)
local saved={uptimeHistory={}}
reports.Init(saved); reports.BeginEncounter(0,true,"player")
reports.StartSkillEncounterClock(GetGameTimeMilliseconds(),true)
meter:Start(GetGameTimeMilliseconds()); meter:CorrelateBoss("boss1",900,"Boss")
local function hit(time,source,target,name,amount,skill)
 clock=time
 meter:OnDamage(1,false,source,name,4,amount,target,source==1 and 1 or 2)
 reports.RecordSkillEncounterDamage(GetGameTimeMilliseconds())
 reports.RecordDamage(source,4,target,name,amount,skill,"Skill "..skill,false,GetFrameTimeSeconds())
end
hit(1000,1,900,"Boss",600000,101)
hit(3000,1,900,"Boss",400000,102)
hit(8000,2,900,"Boss",200000,103)
hit(10000,1,901,"Add",1100000,104)
hit(10000,3,900,"Boss",900000,105)
local group=meter:GetStats()
assert(group.bossDPS==120000 and group.dps==230000)
local groupDuration=reports.FinishSkillEncounterClock()
reports.SkillDamageSummary(10,{[900]={name="Boss",bossId=1,dpsstart=101000,dpsend=108000}},nil,groupDuration)
reports.CaptureFallback({},0,10,10,false,tostring,{},function() return false end)
local report=assert(saved.lastUptimeReport)
assert(report.ownDamage==2300000 and report.groupDamageDuration==10)
assert(report.enemies[1].damage==1200000 and report.enemies[1].duration==7,
    "own boss damage stays intact and the shorter raw target interval remains available")
reports.Open(); reports.ShowZone(); reports.ShowBuffs(); reports.SetCategory("skills")
assert(env.controls.LiveBuffUptimeReportTotal.text=="Gesamtschaden  2300000" and env.controls.LiveBuffUptimeReportTimes.text=="Gesamt-DPS  230000")
local bossIndex
for i,entry in ipairs(list.entries) do if entry.skillTargetKey==900 then bossIndex=i end end
list:SetSelectedIndex(assert(bossIndex))
assert(env.controls.LiveBuffUptimeReportTotal.text=="Schaden  1200000" and env.controls.LiveBuffUptimeReportTimes.text=="Boss-DPS  120000")
local skillDPS=0
for _,label in ipairs(env.controls.LiveBuffUptimeReportDetails.labels) do
 if label.x==528 then skillDPS=skillDPS+(tonumber(label.text) or 0) end
end
assert(skillDPS==group.bossDPS,"boss skill DPS add up to the same 120k shown by GroupDPS; add/group damage stays out")
-- A PC CMX active-time clock may differ. Boss rows must still use the recorded
-- GroupDPS-compatible encounter clock, rather than silently using CMX's 8s.
report.skillDamageDuration=8
reports.Refresh()
assert(env.controls.LiveBuffUptimeReportTimes.text=="Boss-DPS  120000")
for _,label in ipairs(env.controls.LiveBuffUptimeReportDetails.labels) do
 if label.x==528 and label.y==204 then assert(label.text=="60000") end
end
assert(reports.SkillTargets(report)[3].duration==1,"ordinary add DPS retains its own target clock")
reports.Close()
print("Boss/group DPS: 120k boss vs 230k all targets, matching actual GroupDPS and boss skill rows, pets, raid clock, add exclusion and PC active-time independence")
