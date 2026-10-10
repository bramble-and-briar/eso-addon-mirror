dofile("Uptime.lua")
dofile("StackUptime.lua")
dofile("LiveUptime.lua")
dofile("Diagnostics.lua")
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP, COMBAT_UNIT_TYPE_PLAYER_PET = 1, 2, 3
COMBAT_UNIT_TYPE_PLAYER_COMPANION, COMBAT_UNIT_TYPE_GROUP_COMPANION = 5, 6
local E, A = LiveBuffUptimeEngine, LiveBuffUptimeDiagnostics
local f = E.New(0)
f.starts, f.ends, f.diagnostics = 1, 10, {}
local t = { config = { id = 61771, unit = "group" }, state = { since = 0 } }
E.Kind(f, 1, COMBAT_UNIT_TYPE_GROUP)
E.Effect(f, t, 1, 1, 61771, 1, true, false, 1)
E.Effect(f, t, 5, 1, 61771, 1, false, false, 1)
E.Touch(f, 1, 10)
for id = 2, 4 do
    local kind = id == 2 and COMBAT_UNIT_TYPE_PLAYER_PET or id == 3 and COMBAT_UNIT_TYPE_PLAYER_COMPANION or COMBAT_UNIT_TYPE_GROUP_COMPANION
    E.Kind(f, id, kind)
    E.Effect(f, t, 1, id, 61771, 1, true, false, 1)
    E.Touch(f, id, 10)
end
E.Kind(f, 5, COMBAT_UNIT_TYPE_GROUP)
E.Effect(f, t, 1, 5, 61771, 1, true, false, 1)
E.Touch(f, 5, 10)
E.Finish(f, { units = { [1] = { unitType = 2, name = "Player" }, [2] = { unitType = 3 },
    [3] = { unitType = 5 }, [4] = { unitType = 6 }, [5] = { unitType = 2, name = "Offline" } } }, function(v) return v end)
local r = E.Calculate(f, t, nil, nil, true)
assert(#r.members == 1 and #r.excluded == 4)
assert(r.members[1].kind == 2 and r.members[1].observedStarts == 1 and r.members[1].ends == 10)
assert(r.covered == 4 and r.duration == 9)
for _, member in ipairs(r.excluded) do
    assert(member.reason == "Begleiter ausgeschlossen" or member.reason == "Offline/fehlt in Zusammenfassung")
end
E.Action(f, "EVENT_DAMAGE_OUT", 30, 1, 20, 100)
E.Effect(f, t, 30, 1, 61771, 1, true, false, 1)
E.Kind(f, 1, COMBAT_UNIT_TYPE_PLAYER_PET)
assert(f.ends == 10 and f.units[1].kind == 2 and f.diagnostics.blockedMutations == 3)
assert(E.Calculate(f, t).covered == 4)
local lines = {}
local audit = A.New(function(line) lines[#lines + 1] = line end)
A.SetEnabled(audit, true)
local function check(member, weighted)
    A.Queue(audit, { label = "Raid", starts = 1, ends = 10, duration = 9, percent = 4 / 9 * 100,
        selection = "group", group = true, weighted = weighted, members = { member } })
    for index = 1, 100 do A.Tick(audit) end
    return audit.last[#audit.last]
end
assert(check(r.members[1]):find("OK intern", 1, true))
r.members[1].kind = COMBAT_UNIT_TYPE_PLAYER_PET
assert(check(r.members[1]):find("Begleiter mitgezaehlt", 1, true))
r.members[1].kind = nil
assert(check(r.members[1]):find("Nicht-Spieler", 1, true))
r.members[1].kind, r.members[1].starts = 2, 0
assert(check(r.members[1]):find("ausserhalb Kampf", 1, true))
r.members[1].starts, r.members[1].normalCovered = 1, 99
assert(check(r.members[1], true):find("Normale Buffzeit", 1, true))
local record = { id = 61771, covered = r.covered, duration = r.duration, percent = r.percent }
A.Freeze(t, f, record, 10)
A.CheckFrozen(audit, t, f, r, 10.5)
assert(record.freeze.checks == 0)
A.CheckFrozen(audit, t, f, r, 11)
assert(record.freeze.status == "OK unveraendert")
local altered = { covered = 8, duration = 9, percent = 8 / 9 * 100 }
A.CheckFrozen(audit, t, f, altered, 12)
assert(record.freeze.violations == 1 and record.freeze.status:find("WARN", 1, true))
local count = #lines
A.CheckFrozen(audit, t, f, altered, 13)
assert(record.freeze.violations == 2 and #lines == count, "Freeze warning must not spam chat")
A.Freeze(t, f, record, 14)
t.config.view = "healingIn"
A.CheckFrozen(audit, t, f, altered, 15)
assert(record.freeze.violations == 0 and record.freeze.status:find("Auswahl geaendert", 1, true))
for id = 100, 500 do f.units[id] = { starts = 1, ends = 10 } end
local bounded = E.Calculate(f, t, nil, nil, true)
assert(bounded.scanned <= 256 and #bounded.excluded <= 48 and bounded.exclusionsTruncated)
print("Raid diagnostics: unit types, companions, exclusions, bounds, post-summary guards, freeze checks, warnings and bounded inspection passed")
