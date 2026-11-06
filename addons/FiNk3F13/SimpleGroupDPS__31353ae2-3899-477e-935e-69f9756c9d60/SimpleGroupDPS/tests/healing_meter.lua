local clock, active = 1000, true
ACTION_RESULT_DAMAGE, ACTION_RESULT_HEAL, ACTION_RESULT_CRITICAL_HEAL = 1, 2, 3
ACTION_RESULT_HOT_TICK, ACTION_RESULT_HOT_TICK_CRITICAL, ACTION_RESULT_HEAL_ABSORBED = 4, 5, 6
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_PLAYER_PET, COMBAT_UNIT_TYPE_PLAYER_COMPANION = 1, 3, 6
COMBAT_UNIT_TYPE_GROUP, COMBAT_UNIT_TYPE_OTHER = 4, 0
EVENT_COMBAT_EVENT, EVENT_PLAYER_COMBAT_STATE, EVENT_BOSSES_CHANGED, EVENT_EFFECT_CHANGED = 1,2,3,4
local events = {}
function GetGameTimeMilliseconds() return clock end
function IsUnitInCombat() return active end
function DoesUnitExist() return false end
EVENT_MANAGER = {UnregisterForUpdate = function() end,
    RegisterForEvent = function(_, name, _, callback) events[name] = callback end}
dofile("DamageMeter.lua")
local meter = SimpleGroupDPS_DamageMeter
meter:Initialize()
local function heal(result, source, target, effective, overheal, ability, isError)
    events.SimpleGroupDPSDamage(nil, result, isError or false, nil, nil, nil, "Source", source,
        "Target", target, effective, nil, nil, nil, 10, 20, ability or 100, overheal)
end
heal(2, 1, 4, 1000, 1000)
assert(not meter:IsActive(), "Healing out of combat cannot start or contaminate a fight")
meter:Start(clock)
clock = 2000
meter:OnDamage(1, false, 1, "Enemy", 0, 1000, 99, 10)
clock = 2250
heal(2, 1, 4, 400, 600)
heal(3, 1, 1, 100, 0)
heal(4, 3, 4, 200, 300)
heal(5, 6, 4, 50, 50)
local stats = meter:GetStats()
assert(stats.rawHealingTotal == 1700 and stats.effectiveHealingTotal == 750,
    "Outgoing group/self/pet/companion healing counts once; raw includes overheal")
assert(stats.rawHPS == 1700 and stats.effectiveHPS == 750 and stats.total == 1000 and stats.dps == 1000)
heal(2, 4, 1, 100000, 100000) -- someone else heals us
heal(2, 1, 0, 100000, 100000) -- hostile target
heal(2, 3, 3, 100000, 0, 126366) -- pet health initialization
heal(2, 1, 4, 100000, 0, 100, true)
heal(2, 1, 4, 100000, -1)
heal(2, 1, 4, 100000, math.huge)
heal(2, 1, 4, 100000, 0/0)
assert(meter:GetStats().rawHealingTotal == 1700, "Unrelated or invalid healing must not inflate output")
heal(6, 1, 4, 100, 999) -- absorbed event ignores unreliable overflow, matching the native event handling
heal(2, 1, 4, 0, 200) -- pure overheal still contributes to raw HPS
clock = 9000
stats = meter:GetStats()
assert(stats.rawHealingTotal == 2000 and stats.effectiveHealingTotal == 850)
assert(stats.durationMS == 7000 and math.abs(stats.dps - 1000000 / 7000) < 0.000001 and stats.groupTotal == 1000,
    "Elapsed combat time advances DPS while healing remains separate from damage totals")
meter:Finish()
clock = 15000
assert(meter:GetStats().rawHPS == 2000 and meter:GetStats().effectiveHPS == 850,
    "Finished HPS freezes with the same result as the last display/send snapshot")
assert(meter:ClearResult() and meter:GetStats().rawHPS == nil, "Reset clears old healing too")

clock = 20000
meter:Start(clock)
heal(2, 1, 4, 500, 500)
clock = 21000
stats = meter:GetStats()
assert(stats.total == 0 and stats.rawHPS == 1000 and stats.effectiveHPS == 500,
    "A healer needs no own damage to get outgoing HPS")
meter:Finish()
local saved = {damageTotal = stats.total, dps = stats.dps, damageDurationMS = stats.durationMS,
    rawHealingTotal = stats.rawHealingTotal, effectiveHealingTotal = stats.effectiveHealingTotal,
    rawHPS = stats.rawHPS, effectiveHPS = stats.effectiveHPS}
meter:Initialize(saved)
assert(meter:GetStats().rawHPS == 1000 and meter:GetStats().effectiveHPS == 500, "Reload restores own HPS")
meter:ClearResult()
clock = 22000
meter:Start(clock)
clock = 23000
assert(meter:GetStats().rawHPS == 0 and meter:GetStats().effectiveHPS == 0,
    "New fight resets totals and measured zero differs from missing old data")
print("PASS: outgoing healing, overheal, self/pets/companions, incoming exclusion, validation, clock isolation, finish/reset/reload")
