local calls = 0
function GetFramerate() calls = calls + 1; return 60 end
local env = dofile("tests/addon.lua")
assert(not env.controls.LiveBuffUptimeFPS, "FPS overlay must not be created")
for _, descriptor in ipairs(env.panel.descriptors) do
    assert(descriptor.label ~= "FPS anzeigen" and descriptor.label ~= "FPS-Position")
end
local saved = env.saved()
saved.fps = { enabled = true, x = 100, y = 200 }
ZO_SavedVars.NewAccountWide = function() return saved end
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
assert(saved.fps == nil, "Legacy FPS settings must be cleared")
for index = 1, 10 do env.events.tick() end
assert(calls == 0, "Addon must no longer poll native FPS")
assert(LiveBuffUptimePerformance == nil, "Performance debug must no longer be loaded")
print("FPS removal: no overlay, settings, polling or profiler; migrated saved data passed")
