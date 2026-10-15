local env = dofile("tests/addon.lua")
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_OTHER = 1, 4
local reports = LiveBuffUptimeReports
local saved = {uptimeHistory = {}}
reports.Init(saved)
local bosses = {}
DoesUnitExist = function(tag) return bosses[tag] ~= nil end
GetUnitName = function(tag) return bosses[tag] or "Spieler" end
IsUnitDead = function() return false end
local tracker = { config = {id = 123, unit = "player"}, displayPercent = 50,
    state = { since = 100, intervals = {{100, 105}} } }
local function begin()
    env.setClock(100)
    reports.BeginEncounter(100, true, "player")
end
local function hit(id, name, damage)
    reports.RecordDamage(1, 4, id, name, damage)
end
local function finish()
    reports.CaptureFallback({tracker}, 100, 110, 10, false, function() return "Buff" end, {}, function() return false end)
    return saved.lastUptimeReport
end
begin()
hit(1, "Wamasu", 100); hit(1, "Wamasu", 100); hit(2, "Wamasu", 100)
hit(3, "Schuetze", 200); hit(4, "Kleiner Gegner", 1)
local group = finish()
assert(group.encounterLabel == "Gegnergruppe: 2 x Wamasu, Schuetze")
assert(#group.enemies == 4 and group.buffs[1].percent == 50)
bosses.boss1 = "Exarchanikerin Yaseyla"
begin()
hit(1, "Wamasu", 10000)
hit(2, "Exarchanikerin Yaseyla", 5)
local boss = finish()
assert(boss.encounterLabel == "Exarchanikerin Yaseyla", "An engaged boss must outrank high-damage adds")
assert(group.encounterLabel == "Gegnergruppe: 2 x Wamasu, Schuetze", "Later fights must not mutate old labels")
-- A boss merely visible in boss tags must not rename an unrelated add fight.
begin(); hit(1, "Wamasu", 100)
assert(finish().encounterLabel == "Gegnergruppe: Wamasu")
-- Bosses appearing after combat starts can be identified through their effect tag.
bosses = {}
begin()
reports.ObserveBoss("boss1", 42, "Lylanar")
reports.ObserveBoss("boss2", 43, "Turlassil")
reports.ObserveBoss("group1", 44, "Kein Boss")
assert(finish().encounterLabel == "Lylanar, Turlassil")
assert(boss.buffs[1].percent == 50)
print("Encounter labels: short counted enemy groups, actual boss priority, unrelated bosses, multi-boss effects and unchanged uptime passed")
