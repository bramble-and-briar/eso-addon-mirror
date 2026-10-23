local env = dofile("tests/addon.lua")
local sceneName = "hud"
local sceneCallback
function SCENE_MANAGER:GetCurrentScene()
    return { GetName = function() return sceneName end }
end
function SCENE_MANAGER:RegisterCallback(event, callback)
    assert(event == "SceneStateChanged")
    sceneCallback = callback
end
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
env.setting("Effekt-ID").setFunction("123")
env.setting("Tracker hinzufuegen").clickHandler()
local window = env.controls.LiveBuffUptimeTracker1
env.setClock(30)
env.setBuffs("player", { { 123, 30, 50 } })
env.setCombat(false)
env.events[EVENT_PLAYER_COMBAT_STATE](nil, false)
env.setCombat(true)
env.events[EVENT_PLAYER_COMBAT_STATE](nil, true)
assert(not window.hidden)
local function show(name)
    sceneName = name
    sceneCallback(SCENE_MANAGER:GetCurrentScene(), "showing")
end
for _, name in ipairs({ "worldMap", "gamepad_worldMap", "gameMenuInGame", "inventory", "LibHarvensAddonSettingsScene" }) do
    show(name)
    assert(window.hidden, "Tracker must hide in " .. name)
    env.setClock(35)
    env.events.tick()
    assert(window.hidden and window.labels[1].text == "15.0", "Hidden timer must keep updating")
    assert(window.labels[2].text == "100.0 %", "Menu visibility must not reset uptime")
end
SLASH_COMMANDS["/lbu"]("move")
assert(not window.hidden, "Move UI must remain usable in addon settings")
SLASH_COMMANDS["/lbu"]("move")
assert(window.hidden)
for _, name in ipairs({ "hud", "hudui" }) do
    show(name)
    assert(not window.hidden)
end
env.setting("Nur im Kampf anzeigen").setFunction(true)
env.setCombat(false)
env.events[EVENT_PLAYER_COMBAT_STATE](nil, false)
assert(window.hidden)
env.setting("Nur im Kampf anzeigen").setFunction(false)
assert(not window.hidden)
print("Visibility: desktop/gamepad maps, menus, immediate scene changes, background measurement and Move UI passed")
