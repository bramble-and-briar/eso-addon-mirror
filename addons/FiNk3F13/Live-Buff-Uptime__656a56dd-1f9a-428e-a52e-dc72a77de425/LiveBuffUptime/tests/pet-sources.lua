dofile("Uptime.lua")
dofile("StackUptime.lua")
dofile("LiveUptime.lua")
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP = 1, 2
COMBAT_UNIT_TYPE_PLAYER_PET, COMBAT_UNIT_TYPE_GROUP_PET = 3, 4
local E = LiveBuffUptimeEngine
local function near(a, b) assert(math.abs(a - b) < 0.00001, tostring(a) .. " ~= " .. tostring(b)) end
local fight = E.New(0)
fight.starts, fight.ends = 0, 10
local tracker = { config = { unit = "group", buffSource = "own" }, state = { since = 0 } }
local unit = E.Touch(fight, 10, 0, COMBAT_UNIT_TYPE_GROUP)
local function effect(time, slot, gained, source, stacks)
    E.Remember(unit, 61771, slot, gained, source == COMBAT_UNIT_TYPE_PLAYER, stacks, source)
    E.Effect(fight, tracker, time, 10, 61771, slot, gained, source == COMBAT_UNIT_TYPE_PLAYER, stacks, source)
end
effect(0, 1, true, COMBAT_UNIT_TYPE_PLAYER_PET, 99)
effect(0, 2, true, COMBAT_UNIT_TYPE_GROUP_PET, 99)
effect(1, 3, true, COMBAT_UNIT_TYPE_GROUP, 1)
effect(3, 3, true, COMBAT_UNIT_TYPE_PLAYER_PET, 99)
effect(4, 4, true, nil, 1)
effect(6, 4, false, nil, 1)
effect(7, 5, true, COMBAT_UNIT_TYPE_PLAYER, 1)
effect(8, 5, false, COMBAT_UNIT_TYPE_GROUP_PET, 99)
E.Touch(fight, 10, 10)
near(E.Calculate(fight, tracker).covered, 5)
tracker.config.uptimeMetric = "stacks"
near(E.Calculate(fight, tracker).covered, 5)
assert(not unit.effects[1] and not unit.effects[2] and not unit.effects[3])
effect(10, 6, true, COMBAT_UNIT_TYPE_GROUP_PET, 99)
E.Seed(fight, tracker, 10, function() return true end)
fight.ends = 12
E.Touch(fight, 10, 12)
near(E.Calculate(fight, tracker).covered, 0)
local pet = E.Touch(fight, 20, 0, COMBAT_UNIT_TYPE_GROUP_PET)
E.Effect(fight, tracker, 0, 20, 61771, 1, true, true, 1, COMBAT_UNIT_TYPE_PLAYER)
E.Touch(fight, 20, 12)
tracker.config.unit = "player"
near(E.Calculate(fight, tracker, 20).covered, 0)
assert(not fight.allies[20] and E.IsPet(pet.kind))
print("Pet sources: fixed all sources, pet replacements, unknown sources, fades, stacks, seed and recipients passed")
