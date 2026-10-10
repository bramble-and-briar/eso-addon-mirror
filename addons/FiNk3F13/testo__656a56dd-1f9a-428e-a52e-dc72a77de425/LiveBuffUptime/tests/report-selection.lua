local env = dofile("tests/addon.lua")
local saved = env.saved()
local function record(unit, percent)
    return { id = 61771, unit = unit, source = "all", combatDuration = 30,
        covered = percent * 0.3, duration = 30, percent = percent, members = {} }
end
local function report(command)
    local index = #env.messages + 1
    SLASH_COMMANDS["/lbu"](command)
    return env.messages[index]
end
saved.lastFights = { record("group", 92.7), record("player", 48) }
assert(report("report"):find("48.0%", 1, true), "Default must select the latest report, not an older group")
assert(report("report group"):find("92.7%", 1, true), "Explicit group request must retain access to group reports")
saved.lastFights[#saved.lastFights + 1] = record("player", 81.9)
assert(report("report"):find("81.9%", 1, true), "A second solo fight must replace the displayed report")
saved.lastFights[#saved.lastFights + 1] = record("group", 60)
assert(report("report"):find("60.0%", 1, true))
saved.lastFights = { record("player", 50) }
assert(report("report group"):find("Noch kein", 1, true), "No silent personal fallback for an explicit group request")
saved.lastFights = {}
assert(report("report"):find("Noch kein", 1, true))
print("Report selection: latest report, consecutive solo fights, explicit group request and missing reports passed")
