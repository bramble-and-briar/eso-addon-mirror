local env=dofile("tests/addon.lua")
local reports=LiveBuffUptimeReports
assert(reports.SkillRows==nil and reports.SkillTargets==nil and reports.RecordDamage==nil and reports.RecordNativeDamage==nil,
    "LiveBuffUptime must not retain the extracted skill damage accumulator or report API")
local list=dofile("tests/helpers/report-console-ui.lua")(env)
local initialize=ZO_Gamepad_ParametricList_Screen.Initialize
function ZO_Gamepad_ParametricList_Screen.Initialize(self,...) initialize(self,...);self.header={} end
local saved={uptimeHistory={}}
reports.Init(saved)
COMBAT_UNIT_TYPE_PLAYER=1
reports.BeginEncounter(100,true,"player")
reports.RecordEnemy(1,4,900,"Boss")
reports.RecordDebuff(39077,900,"Boss",1,102,108,true)
local tracker={config={id=123,unit="player"},displayPercent=50,state={since=100,intervals={{100,105}}}}
reports.CaptureFallback({tracker,{config={id=39077,unit="reticleover"}}},100,110,10,false,tostring,{},function() return false end)
local report=assert(saved.lastUptimeReport)
assert(report.skills==nil and report.ownDamage==nil and report.skillDamageDuration==nil and report.enemies[1].damage==nil)
assert(report.buffs[1].covered==5 and report.buffs[1].duration==10 and report.buffs[1].percent==50)
assert(report.debuffs[1].covered==6 and report.debuffs[1].duration==10 and report.debuffs[1].percent==60)
local header
function ZO_GamepadGenericHeader_Refresh(_,data) header=data end
reports.Open();reports.ShowZone();reports.ShowBuffs()
assert(#header.tabBarEntries==2 and header.tabBarEntries[1].text=="Buffs" and header.tabBarEntries[2].text=="Debuffs")
reports.SetCategory("skills");assert(header.titleText=="Buffs","Skills cannot be selected in LiveBuffUptime")
reports.ChangeCategory(1);assert(header.titleText=="Debuffs")
reports.ChangeCategory(1);assert(header.titleText=="Buffs","shoulder navigation wraps across exactly two categories")
reports.Close()
print("Extraction: buff/debuff math unchanged, no new damage storage, exactly two categories and no skill API passed")
