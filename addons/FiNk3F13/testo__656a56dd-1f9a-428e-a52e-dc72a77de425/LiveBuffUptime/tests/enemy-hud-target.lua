local setup = dofile("tests/group-effect-timers.lua")
local env = setup.env
local target = 99
local targetKnown = true
LibCombat2.GetUnitIdByTag = function(tag)
    if tag == "reticleover" then return targetKnown and target or nil end
    return tag == "player" and 1 or tonumber(tag:match("^group(%d+)$"))
end
DoesUnitExist = function(tag) return tag == "player" or tag == "reticleover" and target ~= nil end
GetUnitReaction = function() return 3 end
UNIT_REACTION_HOSTILE, BUFF_EFFECT_TYPE_DEBUFF = 3, 2
local saved = env.saved()
saved.trackers = {{key = 1, id = 34384, unit = "reticleover", x = 0, y = 0, scale = 1}}
env.setCombat(false); env.setClock(1000)
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
setup.begin(1000)
env.setClock(1002)
env.rawEvents[EVENT_EFFECT_CHANGED](nil, 1, 1, "", "reticleover", 1002, 1010,
    1, "icon", 0, 2, 0, 0, "Gegner", 99, 34384, 1)
setup.damage(1006)
local hud = env.controls.LiveBuffUptimeTracker1
assert(hud.labels[2].text == "66.7 %", hud.labels[2].text)
env.events[EVENT_RETICLE_TARGET_CHANGED]()
env.events.tick()
assert(hud.labels[2].text == "66.7 %", "Reacquiring the target must not zero known uptime")
target = nil
env.events[EVENT_RETICLE_TARGET_CHANGED]()
env.events.tick()
assert(hud.labels[2].text == "66.7 %", "Temporary reticle loss must retain the last confirmed enemy's result")
target = 99
env.events[EVENT_RETICLE_TARGET_CHANGED]()
env.events.tick()
assert(hud.labels[2].text == "66.7 %", "An already-debuffed target must recover without a new effect notification")
target = 100
env.events.tick()
assert(hud.labels[2].text == "0.0 %", "Polling must resolve the current target without attributing another enemy's buff")
target = 99
env.events.tick()
assert(hud.labels[2].text == "66.7 %")
targetKnown = false
env.events.tick()
assert(hud.labels[2].text == "66.7 %", "A temporarily missing library lookup must not erase the known ESO target ID")
env.setClock(1007)
setup.callbacks[51](51, {unitIds = {player = 1}, units = {}})
local final = hud.labels[2].text
assert(final == "66.7 %", final)
target = nil
env.events[EVENT_RETICLE_TARGET_CHANGED]()
env.events.tick()
assert(hud.labels[2].text == final, "Console final enemy uptime must survive target loss after the library summary")
setup.begin(1100)
env.events.tick()
assert(hud.labels[2].text == "0.0 %", "Console next combat resets the saved target")
print("Enemy HUD: Morag Tong live uptime, reticle reacquisition, target loss, polling and separate enemy identity passed")
