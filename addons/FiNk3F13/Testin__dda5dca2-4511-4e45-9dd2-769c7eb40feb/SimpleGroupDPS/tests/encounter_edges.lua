local clock, zone, inCombat = 1000, 1, true
local callbacks, updates, finished = {}, {}, {}
local bosses = {}
ACTION_RESULT_DAMAGE = 1
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP = 1, 4
EFFECT_RESULT_GAINED, EFFECT_RESULT_FADED = 1, 3
EVENT_COMBAT_EVENT, EVENT_PLAYER_COMBAT_STATE, EVENT_BOSSES_CHANGED = 1, 2, 3
EVENT_EFFECT_CHANGED, EVENT_PLAYER_ACTIVATED, EVENT_UNIT_CREATED = 4, 5, 6
function GetGameTimeMilliseconds() return clock end
function GetCurrentMapZoneIndex() return zone end
function GetZoneId(index) return index end
function IsUnitInCombat() return inCombat end
function DoesUnitExist(tag) return bosses[tag] ~= nil end
function GetRawUnitName(tag) return bosses[tag] or "" end
EVENT_MANAGER = {
    RegisterForEvent = function(_, name, _, callback) callbacks[name] = callback end,
    RegisterForUpdate = function(_, name, _, callback) updates[name] = callback end,
    UnregisterForUpdate = function(_, name) updates[name] = nil end,
}
dofile("DamageMeter.lua")
local meter = SimpleGroupDPS_DamageMeter
meter:Initialize()
meter.onFinished = function(stats) finished[#finished + 1] = stats end
local function hit(time, name, value, id)
    clock = time
    meter:OnDamage(1, false, 1, name, 2, value, id)
end
local function effect(ability, tag, name, id)
    callbacks.SimpleGroupDPSDamageEffects(nil, 1, nil, nil, tag, nil, nil, nil, nil, nil, nil, nil, nil, name, id, ability)
end
meter:Start(clock)
hit(2000, "Add Wave", 1000, 99)
assert(meter:GetStats().bossDPS == nil)
bosses.boss1 = "The Mage"
callbacks.SimpleGroupDPSDamageCreated(nil, "boss1")
assert(meter:GetStats().bossDPS == nil, "new boss tag alone does not misclassify add wave")
clock = 2500
effect(50184, "boss1", "The Mage", 10)
assert(#finished == 1 and finished[1].total == 1000 and meter:IsActive() and meter:GetStats().total == 0,
    "Mage arrival finalizes add wave and starts a fresh encounter")
effect(50184, "boss1", "The Mage", 10)
assert(#finished == 1, "repeated arrival event before any damage cannot create duplicate summaries")
hit(3500, "The Mage", 600, 10)
hit(4000, "The Mage", 400, 99)
assert(meter:GetStats().bossTotal == 600, "same-name add is excluded after authoritative boss identity")
effect(108045, "player", "Player", 1)
effect(0, "boss1", "The Mage", 20)
hit(4500, "The Mage", 200, 20)
assert(meter:GetStats().bossTotal == 800, "recreated boss unit ID keeps earlier boss damage after portal")
bosses.boss1 = "Next Boss"
callbacks.SimpleGroupDPSDamageCreated(nil, "boss1")
hit(5000, "Next Boss", 300, 30)
assert(meter:GetStats().bossTotal == 1100, "reused boss tag discovers next boss while preserving previous damage")
effect(0, "boss1", "Next Boss", 30)
hit(5500, "Next Boss", 100, 31)
assert(meter:GetStats().bossTotal == 1100, "same-name add next to new boss is not promoted to boss")
effect(123, "player", "Player", 1)
assert(#finished == 1, "unrelated effects never split encounter")
zone, inCombat = 2, false
callbacks.SimpleGroupDPSDamageActivated()
assert(not meter:IsActive() and #finished == 2 and finished[2].total == 1600,
    "travel finalizes old encounter even if portal flag was set")
zone, clock, inCombat = 3, 6000, true
callbacks.SimpleGroupDPSDamageActivated()
assert(meter:IsActive() and meter:GetStats().total == 0, "activation in combat starts fresh measurement")
print("PASS: add-to-Mage transition, boss appearance/recreation/tag reuse and zone boundaries")
