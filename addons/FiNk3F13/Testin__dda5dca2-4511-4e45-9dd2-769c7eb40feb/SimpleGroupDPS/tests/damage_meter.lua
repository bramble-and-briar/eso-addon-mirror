local clock, inCombat = 0, false
local bosses = { boss1 = "Boss" }
local callbacks = {}
ACTION_RESULT_DAMAGE, ACTION_RESULT_CRITICAL_DAMAGE, ACTION_RESULT_DAMAGE_SHIELDED = 1, 2, 3
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_PLAYER_PET, COMBAT_UNIT_TYPE_GROUP = 1, 3, 4
COMBAT_UNIT_TYPE_GROUP_PET, COMBAT_UNIT_TYPE_PLAYER_COMPANION = 5, 6
EVENT_COMBAT_EVENT, EVENT_PLAYER_COMBAT_STATE, EVENT_BOSSES_CHANGED, EVENT_EFFECT_CHANGED = 1, 2, 3, 4
EFFECT_RESULT_FADED = 3
function GetGameTimeMilliseconds() return clock end
function IsUnitInCombat() return inCombat end
function DoesUnitExist(tag) return bosses[tag] ~= nil end
function GetRawUnitName(tag) return bosses[tag] or "" end
function zo_strformat(_, name) return (name:gsub("%^.*$", "")) end
EVENT_MANAGER = { RegisterForEvent = function(_, name, event, callback) callbacks[name] = callback end }
dofile("DamageMeter.lua")
local meter = SimpleGroupDPS_DamageMeter
meter:Initialize({ damageTotal = 100, dps = 10, durationMS = 10000 })
assert(meter:GetStats().total == 100 and meter:GetStats().bossDPS == nil, "legacy summary restores unknown boss values")

local function damage(time, source, name, target, amount, id, result, overflow)
    clock = time
    callbacks.SimpleGroupDPSDamage(nil, result or 1, false, nil, nil, nil, nil,
        source, name, target, amount, nil, nil, nil, 99, id, 123, overflow or 0)
end
clock, inCombat = 1000, true
callbacks.SimpleGroupDPSDamageState(nil, true)
damage(1000, 1, "Boss", 2, 600, 10)
damage(1500, 3, "Add", 2, 400, 20)
damage(2000, 4, "Boss", 2, 9000, 10)
local stats = meter:GetStats()
assert(stats.total == 1000 and stats.bossTotal == 600)
assert(stats.dps == 1000 and stats.bossDPS == 600 and stats.addsDPS == 400, "all categories use the same encounter clock")
clock = 9000
assert(meter:GetStats().dps == 1000 and meter:GetStats().durationMS == 1000,
    "live DPS retains the measured damage window during pauses")
assert(meter:GetStats(true).dps == meter:GetStats().dps, "live and final DPS use the same clock")
damage(10000, 6, "Boss", 2, 800, 10, 2, 10000)
stats = meter:GetStats()
assert(stats.total == 1800 and stats.dps == 200, "companion included and overkill excluded")
assert(math.abs(stats.dps - stats.bossDPS - stats.addsDPS) < 0.000001)
damage(11000, 1, "Boss", 2, 200, 10, 3)
assert(meter:GetStats().total == 2000, "shield damage counted once")
damage(11000, 1, "Friend", 4, 9000, 44)
damage(11000, 2, "Player", 1, 9000, 99)
assert(meter:GetStats().total == 2000, "friendly and incoming damage excluded from own total")
damage(11000, 1, "Boss", 2, 500, 11)
callbacks.SimpleGroupDPSDamageEffects(nil, 1, nil, nil, "boss1", nil, nil, nil, nil, nil, nil, nil, nil, "Boss", 10)
assert(meter:GetStats().bossTotal == 1600, "authoritative boss unit ID disambiguates same-name adds retroactively")
bosses.boss2 = "Second Boss"
callbacks.SimpleGroupDPSDamageBosses()
damage(12000, 1, "Second Boss", 2, 1100, 30)
assert(meter:GetStats().bossTotal == 2700, "multiple bosses combined")
stats = meter:GetStats()
clock = 18000
assert(meter:GetStats().dps == stats.dps, "damage pause cannot dilute the live value before combat exit")
clock, inCombat = 20000, false
callbacks.SimpleGroupDPSDamageState(nil, false)
assert(not meter:IsActive() and meter:GetStats().dps == stats.dps, "combat exit freezes exact damage window")
damage(21000, 1, "New Add", 2, 500, 40)
assert(meter:GetStats().total == 3600, "precombat hits do not overwrite previous result")

bosses = {}
clock, inCombat = 21500, true
callbacks.SimpleGroupDPSDamageState(nil, true)
damage(22000, 1, "New Add", 2, 500, 40)
stats = meter:GetStats()
assert(stats.total == 1000 and stats.durationMS == 500 and stats.dps == 2000,
    "one-second precombat replay uses combat-entry time and exact subsecond duration")
assert(stats.bossDPS == nil and stats.addsDPS == nil, "no boss data stays unknown")
callbacks.SimpleGroupDPSDamageState(nil, false)
clock = 25000
meter:Start(clock)
damage(25100, 1, "New Add", 2, 100, 40)
assert(meter:GetStats().total == 100 and meter:GetStats().dps == 1000, "new fight resets counters")
meter:Finish()
clock = 30000
meter:Start(clock)
damage(30000, 1, "New Add", 2, 100, 40)
clock = 35000
meter:Finish()
assert(meter:GetStats().durationMS == 0 and meter:GetStats().dps == 0,
    "zero-length encounter has no invented trailing duration or infinite DPS")
bosses = { boss1 = "Boss^Mx" }
clock = 40000
meter:Start(clock)
damage(41000, 1, "Unrelated Add", 2, 100, 55)
assert(meter:GetStats().bossDPS == nil, "nearby boss tag alone does not turn add damage into a boss encounter")
callbacks.SimpleGroupDPSDamageEffects(nil, 1, nil, nil, "boss1", nil, nil, nil, nil, nil, nil, nil, nil, "Boss", 10)
assert(meter:GetStats().bossDPS == nil, "boss effect without boss damage does not trigger boss encounter")
damage(42000, 4, "Boss", 2, 200, 10)
assert(meter:GetStats().bossDPS == 0 and meter:GetStats().dps == 50,
    "group boss damage confirms encounter while own add damage stays in overall DPS")
meter:Finish()
clock = 50000
meter:Start(clock)
damage(51000, 1, "BOSS", 2, 100, 10)
assert(meter:GetStats().bossDPS == 100, "boss names match across grammar suffixes and case")
print("PASS: unified DPS clock, boss identification, pet/companion damage, shields, overkill and encounter lifecycle")
