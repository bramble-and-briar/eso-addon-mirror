local env = dofile("tests/addon.lua")
env.setCombat(false)
env.setClock(30)
local saved = env.saved()
saved.trackers = {{key = 1, id = 263461, unit = "player", x = 0, y = 0, scale = 1}}
ZO_SavedVars.NewAccountWide = function() return saved end
local count, expires = 10, 0
function GetNumBuffs(tag) return tag == "player" and 1 or 0 end
function GetUnitBuffInfo()
    return "Stacks", 30, expires, 1, count, "stacks.dds", nil, nil, nil, nil, 263461
end
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
env.events.tick()
local timer = env.controls.LiveBuffUptimeTracker1.labels[1]
assert(timer.text == "10", "permanent stack effect displays count instead of asterisk")
count = 7
env.setClock(31)
env.events.tick()
assert(timer.text == "7", "decreasing stacks refresh in the HUD")
count = 1
env.events.tick()
assert(timer.text == "1", "last remaining permanent stack stays visible")
count, expires = 0, 40
env.events.tick()
assert(timer.text == "9.0", "ordinary timed effects keep their countdown")
function GetNumBuffs() return 0 end
env.events.tick()
assert(timer.text == "--", "removed effects do not retain a stale stack count")
print("PASS: native stack count polling, decreasing counts, last stack, countdown and removal")
