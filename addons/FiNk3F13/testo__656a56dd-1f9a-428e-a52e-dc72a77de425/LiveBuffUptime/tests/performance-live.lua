local env = dofile("tests/addon.lua")
local Perf = LiveBuffUptimePerformance
local ms, reads = 0, 0
function GetGameTimeMilliseconds() reads = reads + 1; return ms end
local child = Perf.Wrap("Bibliotheks-Ereignisse", function(a, b)
    assert(a == 7 and b == nil)
    ms = ms + 5
    return nil, false, 7
end)
local outer = Perf.Wrap("Live-Update", function()
    ms = ms + 4
    local a, b, c = child(7, nil)
    ms = ms + 6
    return a, b, c
end)
local a, b, c = outer()
assert(a == nil and b == false and c == 7 and reads == 0, "Inactive wrappers must preserve returns without timing")
assert(not env.controls.LiveBuffUptimePerformanceFrames, "No frame sampler before opt-in")
ms = 0
SLASH_COMMANDS["/lbu"]("perf start")
assert(Perf.active)
local control = assert(env.controls.LiveBuffUptimePerformanceFrames)
env.setClock(40)
control.handlers.OnUpdate()
a, b, c = outer()
assert(a == nil and b == false and c == 7)
local messages = #env.messages
env.setClock(40.06)
control.handlers.OnUpdate()
assert(#env.messages == messages, "Sampling must not print")
ms = 120
SLASH_COMMANDS["/lbu"]("perf stop")
assert(not Perf.active and not control.handlers.OnUpdate and control.hidden)
local report = table.concat(env.messages, "\n", messages + 1)
assert(report:find("eigene Arbeit 15.00ms", 1, true), "Nested work must not be double counted")
assert(report:find("Max 15.00ms", 1, true))
assert(report:find("vorherigen Frame: 1", 1, true), "Previous-frame work must correlate with the long frame")
reads = 0
outer()
assert(reads == 0, "Stop must disable all callback timing")
ms = 200
SLASH_COMMANDS["/lbu"]("perf start")
env.setClock(50)
control.handlers.OnUpdate()
env.events.tick()
env.rawEvents[EVENT_RETICLE_TARGET_CHANGED]()
local failing = Perf.Wrap("ESO-Ereignisse", function() ms = ms + 7; error("test error") end)
local ok, err = pcall(failing)
assert(not ok and tostring(err):find("test error", 1, true), "Debug must propagate callback errors")
env.setClock(50.1)
control.handlers.OnUpdate()
ms = 300
messages = #env.messages
SLASH_COMMANDS["/lbu"]("perf stop")
report = table.concat(env.messages, "\n", messages + 1)
assert(report:find("eigene Arbeit 7.00ms", 1, true), "Restart must reset counters")
assert(report:find("Fehler: 1", 1, true))
assert(report:find("Live-Update: 1 Aufrufe", 1, true), "Scheduled update must be measured")
assert(report:find("ESO-Ereignisse: 2 Aufrufe", 1, true), "ESO callback must be measured")
print("Live performance: opt-in, inactive overhead, nested timing, nil returns, frame correlation, silent sampling, stop, reset, integration and errors passed")
