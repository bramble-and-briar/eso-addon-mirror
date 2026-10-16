local setup = dofile("tests/group-effect-timers.lua")
local env = setup.env
local saved = env.saved()
local config = saved.trackers[1]
local hud = env.controls.LiveBuffUptimeTracker1
local showHud = assert(env.setting("Im HUD anzeigen"))
local showReports = assert(env.setting("In Kampfstatistiken anzeigen"))
assert(showHud.getFunction() and showReports.getFunction(), "Existing trackers retain both displays by default")
showHud.setFunction(false)
assert(config.showHud == false and hud.hidden)
local function fight(time)
    setup.begin(time)
    for id = 1, 6 do setup.raw(time, id, 1, time + 20) end
    setup.damage(time + 100)
    env.setClock(time + 101)
    setup.callbacks[51](51, { unitIds = { player = 1 }, units = {} })
end
fight(1000)
local report = saved.lastUptimeReport
assert(hud.hidden and config.enabled ~= false, "Hidden HUD must not disable tracking")
assert(report.buffs[1].covered == 120 and report.buffs[1].duration == 1200 and report.buffs[1].percent == 10,
    "Hidden group tracker must retain all twelve members and identical uptime math")
local count = #saved.uptimeHistory
showReports.setFunction(false)
fight(2000)
assert(#saved.uptimeHistory == count and saved.lastUptimeReport == report,
    "Report exclusion only affects new reports, never saved history")
showHud.setFunction(true)
assert(not hud.hidden and config.showInReports == false, "HUD and report switches are independent")
showReports.setFunction(true)
fight(3000)
assert(#saved.uptimeHistory == count + 1 and saved.lastUptimeReport ~= report)

-- Exercise fallback capture and enemy filtering independently of the library.
local reports = LiveBuffUptimeReports
local store = {uptimeHistory = {}}
reports.Init(store)
local personal = {config = {id = 61771, unit = "player", showHud = false}, displayPercent = 50,
    state = {since = 100, intervals = {{100, 105}}}}
local enemy = {config = {id = 39077, unit = "reticleover", showInReports = false}}
local function capture(time)
    reports.BeginEncounter(time, true, "player")
    reports.RecordDamage(COMBAT_UNIT_TYPE_PLAYER, 999, 900, "Boss", 100)
    reports.RecordDebuff(39077, 900, "Boss", 1, time, time + 5, true)
    personal.state = {since = time, intervals = {{time, time + 5}}}
    reports.CaptureFallback({personal, enemy}, time, time + 10, 10, false,
        function() return "Buff" end, {}, function() return false end)
end
capture(100)
assert(#store.lastUptimeReport.buffs == 1 and #store.lastUptimeReport.debuffs == 0)
assert(store.lastUptimeReport.buffs[1].covered == 5 and store.lastUptimeReport.buffs[1].duration == 10)
personal.config.showInReports, enemy.config.showInReports = false, true
capture(200)
assert(#store.lastUptimeReport.buffs == 0 and #store.lastUptimeReport.debuffs == 1)
assert(store.lastUptimeReport.debuffs[1].percent == 50, "Enemy-only reports keep their original uptime calculation")
personal.config.showInReports, enemy.config.showInReports = true, false
capture(300)
assert(#store.lastUptimeReport.buffs == 1 and #store.lastUptimeReport.debuffs == 0)
print("Tracker visibility: independent HUD/report settings, hidden full-group capture, library/fallback paths, enemy filtering and frozen history passed")
