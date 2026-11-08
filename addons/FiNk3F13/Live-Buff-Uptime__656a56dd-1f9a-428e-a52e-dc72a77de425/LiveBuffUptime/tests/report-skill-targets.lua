local env=dofile("tests/addon.lua")
COMBAT_UNIT_TYPE_PLAYER,COMBAT_UNIT_TYPE_PLAYER_PET,COMBAT_UNIT_TYPE_GROUP=1,2,3
local list=dofile("tests/helpers/report-console-ui.lua")(env)
local reports=LiveBuffUptimeReports
local saved={uptimeHistory={}}
reports.Init(saved); reports.BeginEncounter(100,true,"player")
reports.RecordDamage(1,4,900,"Wespe",6000,101,"Skill A",false,100)
reports.RecordDamage(2,4,900,"Wespe",1000,101,"Skill A",false,102)
reports.RecordDamage(1,4,901,"Wespe",3000,102,"Skill B",false,101)
reports.RecordDamage(1,4,901,"Wespe",500,101,"Skill A",false,105)
reports.RecordDamage(1,4,902,"Wespe",2000,103,"Skill C",false,106)
for id=201,213 do reports.RecordDamage(1,4,901,"Wespe",10,id,"Small "..id,false,105) end
reports.RecordDamage(3,4,900,"Wespe",999999,101,"Foreign skill",false,106)
reports.CaptureFallback({},100,110,10,false,tostring,{},function() return false end)
local report=assert(saved.lastUptimeReport)
assert(report.ownDamage==12630 and report.skillTargetsRecorded and #report.enemies==3)
local targets=reports.SkillTargets(report)
assert(#targets==4 and targets[1].key=="all")
local sum,rate=0,0
for i=2,#targets do sum=sum+targets[i].damage; rate=rate+targets[i].damage/targets[i].duration end
assert(sum==report.ownDamage and targets[1].damage/targets[1].duration==1263,"damage sums and overall DPS remain unchanged")
assert(targets[2].duration==2 and targets[2].damage/targets[2].duration==3500 and targets[3].duration==4,
    "individual enemy DPS uses that enemy's own interval, rather than dividing every enemy by the fight duration")
assert(targets[2].name=="Wespe [900]" and targets[3].name=="Wespe [901]","same-name enemies stay separate by ID")
local rows=reports.SkillRows(report,900)
assert(#rows==1 and rows[1].damage==7000 and rows[1].hits==2,"own pet damage joins only the correct enemy")
reports.Open(); reports.ShowZone(); reports.ShowBuffs(); reports.SetCategory("skills")
assert(#list.entries==4 and list.entries[1].text=="Alle Ziele")
assert(env.controls.LiveBuffUptimeReportTotal.text=="Gesamtschaden  12630")
assert(env.controls.LiveBuffUptimeReportTimes.text=="Gesamt-DPS  1263")
assert(env.controls.LiveBuffUptimeReportBasis.text=="Alle Ziele" and not list.entries[1].subtitle,
    "summary numbers appear only in the bottom footer")
list:SetSelectedIndex(2)
assert(env.controls.LiveBuffUptimeReportCovered1.text=="7000" and env.controls.LiveBuffUptimeReportPercent1.text=="100,0 %")
assert(env.controls.LiveBuffUptimeReportTotal.text=="Schaden  7000" and env.controls.LiveBuffUptimeReportTimes.text=="DPS  3500",
    "selected enemy footer uses this enemy's damage and active-time DPS")
assert(env.controls.LiveBuffUptimeReportBasis.text=="Wespe [900]" and not list.entries[2].subtitle,
    "enemy numbers are not duplicated in the heading or left list")
local rowDPS
for _,label in ipairs(env.controls.LiveBuffUptimeReportDetails.labels) do
    if label.x==528 and label.y==204 then rowDPS=label.text end
end
assert(rowDPS=="700","right skill DPS retain the ten-second fight divisor, exactly as CMX")
assert(env.controls.LiveBuffUptimeReportName2.text=="" and reports.SkillRows(report)[1].damage==7500,
    "enemy filtering cannot mutate the stored all-target skill totals")
list:SetSelectedIndex(3)
assert(env.controls.LiveBuffUptimeReportCovered1.text=="3000")
assert(env.controls.LiveBuffUptimeReportTotal.text=="Schaden  3630" and env.controls.LiveBuffUptimeReportTimes.text=="DPS  908")
reports.ScrollSkills(100)
assert(list:GetSelectedIndex()==3 and env.controls.LiveBuffUptimeReportName1.text=="Small 202",
    "scrolling the selected enemy's skills never moves the left target list")
list:SetSelectedIndex(2)
assert(env.controls.LiveBuffUptimeReportCovered1.text=="7000","changing enemies resets the right scroll position")
reports.SetCategory("buffs"); reports.SetCategory("skills")
assert(list:GetSelectedIndex()==2 and env.controls.LiveBuffUptimeReportCovered1.text=="7000","category changes retain the enemy selection")
list:SetSelectedIndex(1)
assert(env.controls.LiveBuffUptimeReportCovered1.text=="7500" and env.controls.LiveBuffUptimeReportTotal.text=="Gesamtschaden  12630")
assert(env.controls.LiveBuffUptimeReportTimes.text=="Gesamt-DPS  1263","All Targets restores the overall footer")
reports.Close()
-- Old fights without per-target skill records retain their original skill list.
reports.Init({uptimeHistory={{started=0,ended=10,zone="Old",ownDamage=100,skillDamageRecorded=true,buffs={},debuffs={},
    enemies={{id=900,name="Wespe",damage=100}},skills={{id=101,name="Old skill",damage=100,hits=1}}}}})
reports.Open(); reports.ShowZone(); reports.ShowBuffs(); reports.SetCategory("skills")
assert(#list.entries==1 and list.entries[1].buffIndex==1,"legacy history never invents per-enemy skill data")
reports.Close()
print("Per-enemy skills: same-name IDs, own pets, total/rate sums, selection, independent scrolling, category retention, immutability and legacy history")
