dofile("Uptime.lua")
dofile("StackUptime.lua")
dofile("LiveUptime.lua")
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_PLAYER_PET, COMBAT_UNIT_TYPE_GROUP, COMBAT_UNIT_TYPE_OTHER = 1, 2, 3, 4
EFFECT_RESULT_GAINED, EFFECT_RESULT_UPDATED, EFFECT_RESULT_FADED = 1, 2, 3
local LiveUptime = LiveBuffUptimeEngine
local function near(actual, expected)
    assert(math.abs(actual - expected) < 0.00001, tostring(actual) .. " ~= " .. tostring(expected))
end

-- Exercise the actual installed CMX effect processor as an independent oracle.
local file = assert(io.open("../CombatMetrics/CombatMetrics.lua", "r"))
local source = file:read("*a"); file:close()
local first = assert(source:find("local function CountSlots", 1, true))
local last = assert(source:find("ProcessLog[LIBCOMBAT_EVENT_EFFECTS_IN]", first, true))
local processor = assert(loadstring("local unpackLogline = unpack; local zo_max, zo_min = math.max, math.min; "
    .. source:sub(first, last - 1) .. " return ProcessLogEffects"))()
local function oracle()
    local fight = { combatstart = 0, starttime = 0, endtime = 30000, units = { [10] = {} }, calculated = { units = {} } }
    function fight:AcquireUnitData(id, time)
        local unit = self.calculated.units[id]
        if not unit then
            unit = { starts = time, buffs = {} }; self.calculated.units[id] = unit
            function unit:UpdateStats() end
            function unit:AcquireEffectData(ability, effectType)
                local data = self.buffs[ability]
                if not data then
                    data = { slots = {}, instances = { [ability] = { [1] = { uptime = 0, count = 0, groupUptime = 0, groupCount = 0 } } },
                        uptime = 0, count = 0, groupUptime = 0, groupCount = 0 }
                    function data:CheckInstance(id, stacks)
                        local instance = self.instances[id]
                        if not instance[stacks] then instance[stacks] = { uptime = 0, count = 0, groupUptime = 0, groupCount = 0 } end
                    end
                    function data:UpdateStats() end
                    self.buffs[ability] = data
                end
                return data
            end
        end
        unit.ends = time
        return unit
    end
    return fight
end
math.randomseed(41)
for iteration = 1, 100 do
    local expected, fight = oracle(), LiveUptime.New(0)
    local tracker = { config = { unit = "group" }, state = { since = 0 } }
    fight.starts, fight.ends, fight.kinds[10] = 0, 30, COMBAT_UNIT_TYPE_GROUP
    local slots, time = {}, 0
    for index = 1, 80 do
        time = time + math.random() * 0.25
        local slot = math.random(1, 5)
        local gained = not slots[slot]
        local own = gained and math.random(1, 2) == 1 or slots[slot] == COMBAT_UNIT_TYPE_PLAYER
        local kind = own and COMBAT_UNIT_TYPE_PLAYER or COMBAT_UNIT_TYPE_GROUP
        local change = gained and EFFECT_RESULT_GAINED or EFFECT_RESULT_FADED
        processor(expected, { 1, time * 1000, 10, 61771, change, 1, 1, kind, slot })
        LiveUptime.Effect(fight, tracker, time, 10, 61771, slot, gained, own)
        slots[slot] = gained and kind or nil
    end
    for slot, kind in pairs(slots) do
        processor(expected, { 1, 25000, 10, 61771, EFFECT_RESULT_FADED, 1, 1, kind, slot })
        LiveUptime.Effect(fight, tracker, 25, 10, 61771, slot, false, kind == COMBAT_UNIT_TYPE_PLAYER)
    end
    LiveUptime.Touch(fight, 10, 30)
    local data = expected.calculated.units[10].buffs[61771]
    near(LiveUptime.Calculate(fight, tracker).covered, data.groupUptime / 1000)
    tracker.config.buffSource = "own"
    near(LiveUptime.Calculate(fight, tracker).covered, data.groupUptime / 1000)
end

local fight, tracker = LiveUptime.New(0), { config = { unit = "group" }, state = { since = 0 } }
LiveUptime.Action(fight, "EVENT_DAMAGE_OUT", 2, 1, 99)
LiveUptime.Touch(fight, 10, 1, COMBAT_UNIT_TYPE_GROUP)
LiveUptime.Effect(fight, tracker, 1, 10, 61771, 1, true, true)
LiveUptime.Effect(fight, tracker, 5, 10, 61771, 1, false, true)
LiveUptime.Touch(fight, 10, 10)
LiveUptime.Touch(fight, 11, 6, COMBAT_UNIT_TYPE_GROUP)
LiveUptime.Effect(fight, tracker, 6, 11, 61771, 1, true, false)
LiveUptime.Touch(fight, 11, 12)
LiveUptime.Action(fight, "EVENT_DAMAGE_IN", 20, 99, 1)
near(fight.ends, 2)
LiveUptime.Action(fight, "EVENT_HEAL_OUT", 12, 1, 11)
near(fight.ends, 12)
local result = LiveUptime.Calculate(fight, tracker)
near(result.covered, 9); near(result.duration, 14); near(result.percent, 900 / 14)
tracker.config.buffSource = "own"
near(LiveUptime.Calculate(fight, tracker).covered, 9)
LiveUptime.Finish(fight, { starttime = 3000, endtime = 11000, units = {
    [10] = { unitType = COMBAT_UNIT_TYPE_GROUP }, [11] = { unitType = COMBAT_UNIT_TYPE_GROUP },
} }, function(ms) return ms / 1000 end)
result = LiveUptime.Calculate(fight, tracker, nil, nil, true)
near(result.covered, 7); near(result.duration, 12)
assert(not fight.running and #result.members == 2)
print("Live-Uptime compatibility: 100 randomized comparisons against installed CMX, source union, member windows, heals and summary bounds passed")
return { processor = processor, oracle = oracle }
