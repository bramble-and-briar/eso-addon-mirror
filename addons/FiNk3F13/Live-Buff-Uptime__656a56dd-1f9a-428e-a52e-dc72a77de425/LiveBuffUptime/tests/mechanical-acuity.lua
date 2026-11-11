local env = dofile("tests/addon.lua")
EVENT_COMBAT_EVENT = 20
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP = 1, 3
ACTION_RESULT_EFFECT_GAINED, ACTION_RESULT_DAMAGE, ACTION_RESULT_EFFECT_FADED = 100, 101, 102
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
dofile("LiveBuffUptime.lua")
env.events[EVENT_ADD_ON_LOADED](nil, "LiveBuffUptime")
env.setClock(100)
env.setting("Effekt-ID").setFunction("99204")
env.setting("Einheit").setFunction(nil, nil, {data="player"})
env.setting("Tracker hinzufuegen").clickHandler()
env.setting("Cooldown-Quelle").setFunction(nil, nil, {data="mechanicalAcuity"})
local window = env.controls.LiveBuffUptimeTracker1
local profile = LiveBuffUptimeCooldowns.Profile({id=99204,unit="player",cooldownProfile="mechanicalAcuity"},99204)
assert(profile and profile.seconds==25 and profile.id==164087)
assert(not LiveBuffUptimeCooldowns.Profile({id=99204,unit="reticleover",cooldownProfile="mechanicalAcuity"},99204))
local function proc(id, source, result, error)
    env.events.LiveBuffUptimeCooldown164087(nil,result or ACTION_RESULT_EFFECT_GAINED,error or false,nil,nil,nil,
        "Caster",source or COMBAT_UNIT_TYPE_PLAYER,"Player",COMBAT_UNIT_TYPE_PLAYER,nil,nil,nil,nil,nil,nil,id)
    env.events.tick()
end
for count=1,5 do
    proc(99204)
    assert(not LiveBuffUptimeCooldowns.Get(profile,"player",100),"Building stacks must not start lockout")
end
proc(164087,COMBAT_UNIT_TYPE_GROUP)
proc(164087,COMBAT_UNIT_TYPE_PLAYER,ACTION_RESULT_EFFECT_GAINED,true)
proc(164087,COMBAT_UNIT_TYPE_PLAYER,ACTION_RESULT_EFFECT_FADED)
proc(164087,COMBAT_UNIT_TYPE_PLAYER,ACTION_RESULT_DAMAGE)
assert(not LiveBuffUptimeCooldowns.Get(profile,"player",100),"Foreign, error, damage and fade events must not start lockout")
env.setClock(104)
proc(164087)
assert(window.labels[1].text=="25.0","Separate lockout gain starts 25 seconds")
env.setClock(106)
proc(164087)
assert(window.labels[1].text=="23.0","Duplicate notification must not restart lockout")
env.setBuffs("player",{{99204,104,108}})
env.events.tick()
assert(window.labels[1].text=="2.0","Remaining active buff takes priority over cooldown")
env.setClock(108)
env.setBuffs("player",{})
env.events.tick()
assert(window.labels[1].text=="21.0","Cooldown continues after active buff ends")
env.setClock(129)
env.events.tick()
assert(window.labels[1].text=="--","Expired cooldown clears normally")
proc(164087)
assert(window.labels[1].text=="25.0","Next cycle can start normally")
print("Mechanical Acuity: separate buff/lockout IDs, own-only 25s cooldown, no stack-triggered restart, active buff priority and repeat cycles passed")
