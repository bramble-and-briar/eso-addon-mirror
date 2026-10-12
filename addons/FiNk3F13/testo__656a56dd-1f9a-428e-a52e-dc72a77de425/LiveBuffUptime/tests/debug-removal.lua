local env = dofile("tests/libcombat.lua")
local saved = env.saved()
saved.checkUptime, saved.lastCheck, saved.lastFights = true, { last = { "old" } }, { { percent = 50 } }
ZO_SavedVars.NewAccountWide = function() return saved end
LiveBuffUptimeDiagnostics = nil
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
assert(saved.checkUptime == nil and saved.lastCheck == nil and saved.lastFights == nil)
for _, descriptor in ipairs(env.panel.descriptors) do
    assert(descriptor.label ~= "Uptime-Selbstpruefung")
end
assert(not env.controls.LiveBuffUptimePerformanceFrames)
local from = #env.messages
for _, command in ipairs({ "perf on", "perf", "perf off", "debug", "check on", "check last", "report", "report group" }) do
    SLASH_COMMANDS["/lbu"](command)
    assert(env.messages[#env.messages]:find("/lbu status", 1, true))
end
for index = 1, 20 do env.events.tick() end
assert(#env.messages == from + 8, "Removed debug commands must not enable background/chat work")
local statusFrom = #env.messages + 1
SLASH_COMMANDS["/lbu"]("status")
assert(table.concat(env.messages, "\n", statusFrom):find("Bezugszeit", 1, true))
print("Debug removal: migrated saved data, no settings/frame profiler, inactive old commands and retained status passed")
