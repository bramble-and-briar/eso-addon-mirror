dofile("EnemyDebug.lua")
local debug = LiveBuffUptimeEnemyDebug
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
local messages, now = {}, 100
d = function(message) messages[#messages + 1] = message end
GetFrameTimeSeconds = function() return now end
debug.Begin(100, true)
for id = 1, 6 do debug.Enemy(id, "Gegner " .. id, 100) end
debug.Effect(34384, 1, 101, 1, 2, 106, "ESO", "reticleover", true)
debug.Effect(34384, 1, 101, 1, 2, nil, "LibCombat2", "EVENT_EFFECTS_OUT", true)
debug.Effect(34384, 2, 105, 3, 2, nil, "ESO", "", true)
for index = 1, 14 do debug.Effect(34384, 3, 100 + index / 10, 2, 2, 110, "ESO", "", false) end
debug.Effect(34384, 4, 102, 1, 2, 107, "ESO", "", true)
debug.Effect(34384, 5, 102, 1, 2, 107, "ESO", "", true)
assert(#messages == 0, "Automatic recording must not print chat messages")
debug.Finish(100, 110)
-- Late callbacks must not change the finished diagnostic.
debug.Effect(34384, 6, 111, 1, 2, 116, "ESO", "", true)
debug.Report(34384)
local summary = table.concat(messages, "\n")
assert(summary:find("letzter abgeschlossener Kampf | 6 Gegner | Messfenster 10.00s", 1, true))
assert(summary:find("ESO 1/0/0; LibCombat2 1/0/0", 1, true))
assert(summary:find("WARN: Ende ohne Beginn", 1, true))
assert(summary:find("WARN: keine Meldung zugeordnet", 1, true))
assert(summary:find("[6] Gegner 6: UNBEKANNT", 1, true))
messages = {}
debug.Report(34384, 3)
local details = table.concat(messages, "\n")
assert(details:find("Letzte 12 von 14 Meldungen", 1, true))
assert(not details:find("+0.100s", 1, true) and details:find("+1.400s", 1, true))
debug.Begin(200, false)
messages = {}; debug.Report(34384)
assert(table.concat(messages, "\n"):find("6 Gegner", 1, true), "Idle initialization must retain the last completed diagnostic")
debug.Begin(200, true)
debug.Enemy(7, "Neuer Gegner", 200)
messages = {}; debug.Report(34384)
assert(table.concat(messages, "\n"):find("Kampf laeuft | 1 Gegner", 1, true))
for id = 1, 300 do debug.Effect(id, 7, 201, 1, 1, 205, "ESO", "", true) end
debug.Finish(200, 210)
messages = {}; debug.Report(1)
assert(table.concat(messages, "\n"):find("Diagnose-Limit erreicht", 1, true), "Bounds must be explicit, never silently imply completeness")
print("Enemy diagnostics: automatic six-ID recording, sources/timestamps, unknown and missing-begin warnings, bounded tails, frozen last fight and limits passed")
