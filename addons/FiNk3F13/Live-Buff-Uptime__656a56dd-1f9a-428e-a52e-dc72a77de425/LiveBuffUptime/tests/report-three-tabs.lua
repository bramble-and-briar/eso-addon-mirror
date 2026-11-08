local setup = dofile("tests/group-effect-timers.lua")
local env, reports = setup.env, LiveBuffUptimeReports
local list = dofile("tests/helpers/report-console-ui.lua")(env)
local bindings, headerData, activeTab
KEYBIND_STRIP = { AddKeybindButtonGroup = function(_, value) bindings = value end,
    RemoveKeybindButtonGroup = function() end, UpdateKeybindButtonGroup = function() end }
ZO_GAMEPAD_HEADER_TABBAR_CREATE = true
local initialize = ZO_Gamepad_ParametricList_Screen.Initialize
function ZO_Gamepad_ParametricList_Screen.Initialize(self,control,hasTabs,...)
    assert(hasTabs == true, "native header provides the visible category switcher")
    initialize(self,control,...); self.header = {}
end
function ZO_GamepadGenericHeader_Refresh(_,data) headerData = data end
function ZO_GamepadGenericHeader_SetActiveTabIndex(_,index)
    assert(index >= 1 and index <= 3)
    -- Native callbacks can occur during header refresh; must not recurse.
    activeTab = index
    if headerData.tabBarEntries and headerData.tabBarEntries[index].callback then headerData.tabBarEntries[index].callback() end
end
function ZO_GamepadGenericHeader_RefreshData(_,data)
    assert(data.titleText == data.tabBarEntries[activeTab].text,"visible header title follows the selected category")
end
COMBAT_UNIT_TYPE_PLAYER_PET = 2
local saved = { uptimeHistory = {} }
reports.Init(saved)
reports.BeginEncounter(100,true,"player")
reports.RecordDamage(1,4,900,"Boss",9000,101,"Skill A")
reports.RecordDamage(2,4,900,"Boss",3000,101,"Skill A")
reports.RecordDamage(1,4,900,"Boss",6000,102,"Skill B")
reports.RecordDamage(3,4,900,"Boss",999999,103,"Foreign Skill")
reports.RecordDamage(1,1,1,"Self",999999,104,"Self hit")
reports.RecordDamage(1,4,900,"Boss",-1,105,"Invalid")
for id=201,213 do reports.RecordDamage(1,4,900,"Boss",1,id,"Small "..id) end
reports.CaptureFallback({},100,110,10,false,function(id) return tostring(id) end,{},function() return false end)
local report = saved.lastUptimeReport
-- Legacy reports retain the historical skill-selection layout.
report.skillTargetsRecorded=false
assert(report and #report.skills==15 and report.ownDamage==18013,"only player/own pet damage is captured, even without uptime trackers")
assert(report.skills[1].id==101 and report.skills[1].damage==12000 and report.skills[1].hits==2)
assert(report.skills[2].id==102 and report.skills[2].damage==6000)
report.buffs={{id=61771,name="Buff A",unit="player",covered=5,duration=10,percent=50,members={{name="Player",covered=5,duration=10}}}}
report.debuffs={{id=34384,name="Debuff A",unit="reticleover",covered=7,duration=10,percent=70,members={{id=900,name="Boss",covered=7,duration=10}}}}
reports.Open()
assert(env.controls.LiveBuffUptimeReportDetails.hidden,"no uptime preview in the area browser")
assert(headerData.titleText=="Kampfstatistiken" and not headerData.tabBarEntries)
assert(not bindings[2].visible() and not bindings[3].visible())
bindings[2].callback()
assert(headerData.titleText=="Kampfstatistiken","hidden shoulder shortcuts must not switch categories in areas")
reports.ShowZone()
assert(env.controls.LiveBuffUptimeReportDetails.hidden,"no uptime preview in the fight browser")
assert(not bindings[2].visible() and not bindings[3].visible())
assert(env.controls.LiveBuffUptimeReportPage.text=="","fight browser has no category page indicator")
assert(env.controls.LiveBuffUptimeReportName1.text=="Buff A")
assert(env.controls.LiveBuffUptimeReportPercent1.text=="50,0 %")
assert(env.controls.LiveBuffUptimeReportReceiptHeading.hidden,"overview has effect rows, not receipt counters")
bindings[3].callback()
assert(env.controls.LiveBuffUptimeReportName1.text=="Buff A","fight selection does not switch pages")
reports.ShowBuffs()
assert(not env.controls.LiveBuffUptimeReportDetails.hidden,"buff details show uptime")
assert(headerData.titleText=="Buffs" and #headerData.tabBarEntries==3 and activeTab==1)
assert(headerData.tabBarEntries[2].text=="Debuffs" and headerData.tabBarEntries[3].text=="Skills")
for _, entry in ipairs(headerData.tabBarEntries) do
    assert(not entry.callback,"visual header must not register a second category-change callback")
end
assert(bindings[2].visible() and bindings[3].visible())
assert(env.controls.LiveBuffUptimeReportName1.text=="Player")
bindings[2].callback()
assert(headerData.titleText=="Debuffs" and list.entries[1].buffIndex,"category changes stay inside fight details")
assert(activeTab==2,"R1 advances the header indicator exactly once")
assert(env.controls.LiveBuffUptimeReportName1.text=="Boss" and env.controls.LiveBuffUptimeReportPercent1.text=="70,0 %")
bindings[2].callback()
assert(headerData.titleText=="Skills" and list.entries[1].buffIndex,"skills use the same detail navigation level")
assert(activeTab==3,"skill page highlights the third header indicator")
assert(not env.controls.LiveBuffUptimeReportDetails.hidden,"skill page stays visible within details")
assert(env.controls.LiveBuffUptimeReportName1.text=="Skill A")
assert(env.controls.LiveBuffUptimeReportCovered1.text=="12000")
assert(env.controls.LiveBuffUptimeReportPercent1.text=="66,6 %")
assert(env.controls.LiveBuffUptimeReportTotal.text=="Gesamtschaden  18013")
assert(not bindings[5].visible(),"skills do not open an irrelevant buff or enemy list")
assert(not bindings[4].visible(),"skill rows scroll instead of offering extra pages")
bindings[4].callback()
assert(env.controls.LiveBuffUptimeReportName1.text=="Skill A","obsolete page callback cannot page skills")
env.controls.LiveBuffUptimeReportDetails.handlers.OnMouseWheel(nil,-100)
assert(list:GetSelectedIndex()==1 and env.controls.LiveBuffUptimeReportName1.text=="Small 202",
    "right-side scrolling leaves the left skill selection and list position untouched")
reports.Refresh()
assert(list:GetSelectedIndex()==1 and env.controls.LiveBuffUptimeReportName1.text=="Small 202",
    "refresh must not snap the independently scrolled table back to the left selection")
reports.ScrollSkills(-100)
list:SetSelectedIndex(13)
assert(env.controls.LiveBuffUptimeReportName1.text=="Skill B","selection scrolls by one row beyond the viewport")
reports.ScrollSkills(1)
assert(env.controls.LiveBuffUptimeReportName1.text=="Small 201")
env.controls.LiveBuffUptimeReportDetails.handlers.OnMouseWheel(nil,-1)
assert(env.controls.LiveBuffUptimeReportName1.text=="Small 202","mouse wheel reaches the last scroll position")
reports.ScrollSkills(100)
assert(env.controls.LiveBuffUptimeReportName12.text=="Small 213","last skill remains reachable without another page")
assert(env.controls.LiveBuffUptimeReportPage.text=="Seite 3 / 3","only category indicator remains")
local details=env.controls.LiveBuffUptimeReportDetails
local leftIndex=list:GetSelectedIndex()
local stickY=GetGamepadRightStickY
GetGamepadRightStickY=function() return 1 end
env.setClock(300)
details.handlers.OnUpdate()
assert(env.controls.LiveBuffUptimeReportName1.text=="Small 201","right stick scrolls upward by one row")
details.handlers.OnUpdate()
assert(env.controls.LiveBuffUptimeReportName1.text=="Small 201","held stick waits before repeating")
env.setClock(300.31); details.handlers.OnUpdate()
assert(env.controls.LiveBuffUptimeReportName1.text=="Skill B","held stick repeats without changing a page")
assert(list:GetSelectedIndex()==leftIndex,"right-stick scrolling also leaves the left list stationary")
GetGamepadRightStickY=stickY
reports.ScrollSkills(100)
bindings[3].callback(); assert(headerData.titleText=="Debuffs")
assert(not details.handlers.OnUpdate and not details.mouse,"skill scrolling is disabled on the debuff page")
bindings[3].callback(); assert(headerData.titleText=="Buffs")
bindings[3].callback()
assert(headerData.titleText=="Skills" and env.controls.LiveBuffUptimeReportName1.text=="Small 202",
    "detail shoulders retain the skill scroll position")
bindings[2].callback(); assert(headerData.titleText=="Buffs","R1 wraps back to Buffs")
bindings[3].callback(); assert(headerData.titleText=="Skills","L1 wraps back to Skills")
local snapshot=report.skills[1].damage
reports.BeginEncounter(200,true,"player"); reports.RecordDamage(1,4,900,"Boss",500,101,"Skill A")
assert(report.skills[1].damage==snapshot,"new fight cannot mutate saved skill data")
reports.CaptureFallback({},200,210,10,false,tostring,{},function() return false end)
assert(saved.uptimeHistory[1].ownDamage==500 and report.ownDamage==18013)
assert(env.controls.LiveBuffUptimeReportTotal.text=="Gesamtschaden  18013","incoming fights retain the fight being inspected")
reports.Back()
assert(env.controls.LiveBuffUptimeReportDetails.hidden,"back to fights hides all statistics")
assert(not bindings[2].visible() and not bindings[3].visible() and list.entries[1].fightIndex)
assert(env.controls.LiveBuffUptimeReportPage.text=="" and not headerData.tabBarEntries)
reports.SelectFight(1); reports.ShowBuffs(); reports.SetCategory("skills")
assert(env.controls.LiveBuffUptimeReportTotal.text=="Gesamtschaden  500")
reports.Close()
local old={zone="Legacy",started=0,ended=10,buffs={},debuffs={}}
reports.Init({uptimeHistory={old}}); reports.Open(); reports.ShowZone(); reports.ShowBuffs(); reports.SetCategory("skills")
assert(env.controls.LiveBuffUptimeReportWarning.text=="Keine Skill-Daten","legacy reports explicitly lack skill damage rather than inventing zeroes")
reports.Close()
-- Exercise the actual ESO damage callback, including the skill ID/name.
reports.Init(env.saved())
setup.begin(300)
local original=reports.RecordDamage
local observed
reports.RecordDamage=function(...) observed={...}; return original(...) end
env.events.LiveBuffUptimeCombatTiming(nil,ACTION_RESULT_DAMAGE,false,"Native Skill",0,0,"player",1,"Boss",4,1234,0,0,false,1,900,4567)
reports.RecordDamage=original
assert(observed and observed[6]==4567 and observed[7]=="Native Skill","native damage events forward skill identity to reports")
print("Three report tabs: native header/shoulders, fight overview, own skill totals/pets, stable selection, paging, snapshots, legacy data and native damage identity passed")
