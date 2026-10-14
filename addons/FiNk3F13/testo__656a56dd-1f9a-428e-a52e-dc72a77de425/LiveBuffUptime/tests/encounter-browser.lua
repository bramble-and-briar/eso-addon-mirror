local env = dofile("tests/addon.lua")
EVENT_COMBAT_EVENT = 90
ACTION_RESULT_DAMAGE = 10
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_PLAYER_PET, COMBAT_UNIT_TYPE_GROUP, COMBAT_UNIT_TYPE_OTHER = 1, 2, 3, 4
local zone = "Das Glattbachhaus"
function GetUnitZone() return zone end
function GetUnitZoneIndex() return zone == "Das Glattbachhaus" and 10 or 20 end
function GetZoneId(index) return index + 100 end
local saved = env.saved()
saved.trackers = { { key = 1, id = 123, unit = "player", x = 0, y = 0, scale = 1 } }
saved.uptimeHistory, saved.lastUptimeReport = {}, nil
ZO_SavedVars.NewAccountWide = function() return saved end
env.setClock(100); env.setCombat(false); env.setBuffs("player", { { 123, 100, 200 } })
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
local function start(time)
    env.setClock(time); env.setCombat(true)
    env.events[EVENT_PLAYER_COMBAT_STATE](nil, true)
end
local function hit(time, source, target, id, name, value)
    env.setClock(time)
    env.events.LiveBuffUptimeCombatTiming(nil, 10, false, "", "", 0, "Me", source, name, target, value, 0, 0, false, 1, id, 123)
    env.events.tick()
end
local function finish(time)
    env.setClock(time); env.setCombat(false)
    env.events[EVENT_PLAYER_COMBAT_STATE](nil, false)
end
start(100)
hit(100, 1, 4, 99, "Trainingspuppe", 10)
hit(104, 3, 4, 100, "Nur vom Gruppenmitglied getroffen", 10000)
hit(105, 4, 1, 1, "Me", 20000)
hit(110, 1, 4, 101, "Anfuehrer", 200)
-- Moving immediately at fight end must not rename the encounter's location.
zone = "Schnittermark"
finish(111)
local first = saved.lastUptimeReport
assert(first.zone == "Das Glattbachhaus" and first.enemyName == "Anfuehrer" and #first.enemies == 2)
assert(first.enemies[1].damage == 200 and first.enemies[2].name == "Trainingspuppe")
zone = "Das Glattbachhaus"
start(120); hit(120, 1, 4, 102, "Andere Puppe", 100); hit(130, 1, 4, 102, "Andere Puppe", 100); finish(131)
local second = saved.lastUptimeReport
zone = "Schnittermark"
start(140); hit(140, 1, 4, 103, "Bandit", 100); hit(150, 1, 4, 103, "Bandit", 100); finish(151)
local list = dofile("tests/helpers/report-console-ui.lua")(env)
local reports = LiveBuffUptimeReports
local bindings
KEYBIND_STRIP = { AddKeybindButtonGroup = function(_, group) bindings = group end, RemoveKeybindButtonGroup = function() end }
reports.Open()
assert(#list.entries == 2 and list.entries[1].text == "Schnittermark" and list.entries[2].text == "Das Glattbachhaus")
assert(bindings[6].visible(), "Area grouping must offer confirmed deletion of its saved encounters")
list:SetSelectedIndex(2)
bindings[5].callback()
assert(#list.entries == 2 and list.entries[1].text == "Andere Puppe" and list.entries[2].text == "Anfuehrer")
assert(bindings[6].visible(), "Individual encounters remain deletable")
list:SetSelectedIndex(2)
bindings[5].callback()
assert(list.entries[1].buffIndex and not bindings[6].visible())
assert(env.controls.LiveBuffUptimeReportSubtitle.text:find("Anfuehrer", 1, true))
reports.Back()
assert(list.index == 2 and list.entries[2].text == "Anfuehrer", "Returning from statistics must retain the chosen fight")
reports.Back()
assert(list.index == 2 and list.entries[2].zoneKey)
reports.Close()
assert(first.enemyName == "Anfuehrer" and second.enemyName == "Andere Puppe", "Later fights must not mutate recorded targets")
print("Encounter browser: areas -> named fights -> buff stats, own-damage targets, preserved location, focused back navigation and delete scope passed")
