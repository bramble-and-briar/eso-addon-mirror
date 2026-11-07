local env = dofile("tests/addon.lua")
local list = dofile("tests/helpers/report-console-ui.lua")(env)
local reports = LiveBuffUptimeReports
local rightBackground = {kind="right-background"}
GAMEPAD_NAV_QUADRANT_2_3_BACKGROUND_FRAGMENT = rightBackground
local unexpectedShows = 0
local create = WINDOW_MANAGER.CreateTopLevelWindow
function WINDOW_MANAGER:CreateTopLevelWindow(name)
    local control = create(self,name)
    if name=="LiveBuffUptimeReportDetails" then
        local setHidden=control.SetHidden
        function control:SetHidden(value)
            if not value and not list.scene.fragments[rightBackground] then unexpectedShows=unexpectedShows+1 end
            setHidden(self,value)
        end
    end
    return control
end
function SCENE_MANAGER:Push()
    -- Reproduce scene fragments revealing controls before the final Refresh.
    for fragment in pairs(list.scene.fragments) do if fragment.SetHidden then fragment:SetHidden(false) end end
end
local report={zone="Raid",started=0,ended=10,ownDamage=1000,skillDamageRecorded=true,
    buffs={{id=1,name="Buff",unit="player",covered=5,duration=10,percent=50,members={}}},debuffs={},
    skills={{id=100,name="Giftschaedel",damage=200,hits=2},
        {id=101,name="Giftschaedel",damage=300,hits=3},
        {id=102,name="Giftschaedel",damage=100,hits=1},
        {id=200,name="Anderer Skill",damage=400,hits=4}}}
local original=report.skills
reports.Init({uptimeHistory={report}})
reports.Open()
local detail=env.controls.LiveBuffUptimeReportDetails
assert(unexpectedShows==0 and detail.hidden,"scene opening must never flash the previous statistics")
assert(not list.scene.fragments[rightBackground] and not list.scene.fragments[detail],"outer browser has no right background or automatic statistics fade")
reports.ShowZone()
assert(detail.hidden and not list.scene.fragments[rightBackground])
reports.ShowBuffs()
assert(not detail.hidden and list.scene.fragments[rightBackground],"right panel exists only inside detail pages")
reports.SetCategory("skills")
assert(#list.entries==4 and list.entries[1].text=="Anderer Skill","damage variants remain separate by ability ID, as in CMX")
assert(env.controls.LiveBuffUptimeReportName1.text=="Anderer Skill")
assert(env.controls.LiveBuffUptimeReportCovered1.text=="400")
assert(env.controls.LiveBuffUptimeReportDeaths1.text=="4 Treffer | ID 200")
assert(env.controls.LiveBuffUptimeReportPercent1.text=="40,0 %")
assert(env.controls.LiveBuffUptimeReportTotal.text=="Gesamtschaden  1000")
assert(report.skills==original and #original==4 and original[1].damage==200,"display grouping preserves historical source data")
local merged=reports.SkillRows(report)
assert(#merged==4 and merged[2].id==101 and merged[2].damage==300 and merged[2].hits==3)
reports.Back()
assert(detail.hidden and not list.scene.fragments[rightBackground])
reports.ShowBuffs(); reports.Close(); reports.Open()
assert(detail.hidden and unexpectedShows==0 and not list.scene.fragments[rightBackground],"reopening never flashes cached skills")
reports.Close()
COMBAT_UNIT_TYPE_PLAYER,COMBAT_UNIT_TYPE_OTHER=1,4
reports.BeginEncounter(100,true,"player")
reports.RecordDamage(1,4,900,"Boss",200,100,"Giftschaedel")
reports.RecordDamage(1,4,900,"Boss",300,101,"Giftschaedel")
reports.CaptureFallback({},100,110,10,false,tostring,{},function() return false end)
-- New snapshots preserve distinct damage IDs too.
reports.Open(); reports.ShowZone(); reports.SelectFight(1); reports.ShowBuffs(); reports.SetCategory("skills")
assert(#list.entries==2 and env.controls.LiveBuffUptimeReportCovered1.text=="300")
reports.Close()
print("CMX-style skill IDs: separate variants, totals, hits, sort/icon and immutable snapshots; no opening flash or outer right panel")
