local env = dofile("tests/libcombat.lua")
local function toggles()
    local result = {}
    for _, descriptor in ipairs(env.panel.descriptors) do
        if descriptor.label == "Buff aktiv" then result[#result + 1] = descriptor end
    end
    return result
end
local player = env.controls.LiveBuffUptimeTracker1
local toggle = toggles()[1]
assert(toggle.getFunction(), "Legacy trackers must remain enabled by default")
local config = env.saved().trackers[1]
local id, x, y, scale = config.id, config.x, config.y, config.scale
toggle.setFunction(false)
assert(player.hidden and config.enabled == false)
local scans, events = 0, 0
local getBuffs, scopeEvent = GetNumBuffs, LiveBuffUptimeMeter.ScopeEvent
GetNumBuffs = function(...) scans = scans + 1; return getBuffs(...) end
LiveBuffUptimeMeter.ScopeEvent = function(...) events = events + 1; return scopeEvent(...) end
env.setClock(50)
env.callbacks[LIBCOMBAT_EVENT_EFFECTS_IN](nil, 150000, 1, 61747, EFFECT_RESULT_GAINED, 0, 1, 0, 2)
env.events.tick()
assert(scans == 0 and events == 0, "Disabled tracker must not poll buffs or record library effects")
SLASH_COMMANDS["/lbu"]("move")
assert(player.hidden and not player.mouse, "Move mode cannot reveal a disabled tracker")
assert(config.id == id and config.x == x and config.y == y and config.scale == scale)
assert(#env.saved().trackers == 1, "Disable must not delete saved configuration")

env.setClock(60)
env.setBuffs("player", { { 46522, 60, 70 } })
toggle.setFunction(true)
assert(not player.hidden and config.enabled)
env.callbacks[LIBCOMBAT_EVENT_DAMAGE_OUT](nil, 160000)
env.setClock(62)
env.callbacks[LIBCOMBAT_EVENT_DAMAGE_OUT](nil, 162000)
env.events.tick()
assert(player.labels[2].text == "100.0 %", "Enable must start a fresh measurement, excluding disabled time")
SLASH_COMMANDS["/lbu"]("move")
assert(player.mouse)
toggle.setFunction(false)
assert(player.hidden and not player.mouse and env.events.move == nil, "Disable must exit active movement")

env.setting("Effekt-ID").setFunction("123")
env.setting("Einheit").setFunction(nil, nil, { data = "group" })
env.setting("Tracker hinzufuegen").clickHandler()
local group = env.controls.LiveBuffUptimeTracker2
local switches = toggles()
assert(not switches[1].getFunction() and switches[2].getFunction())
switches[2].setFunction(false)
scans = 0
env.events.tick()
assert(scans == 0 and group.hidden and player.hidden, "All disabled trackers must skip polling")
switches[1].setFunction(true)
assert(not player.hidden and group.hidden, "Per-tracker toggles must be independent")
switches[1].setFunction(false)
local saved = env.saved()
ZO_SavedVars.NewAccountWide = function() return saved end
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
assert(#toggles() == 2 and not toggles()[1].getFunction() and not toggles()[2].getFunction())
assert(env.controls.LiveBuffUptimeTracker1.hidden and env.controls.LiveBuffUptimeTracker2.hidden,
    "Reload must retain disabled state and never show disabled windows")
print("Tracker toggles: legacy defaults, no polling/events, fresh enable, move mode, independence and saved reload passed")
