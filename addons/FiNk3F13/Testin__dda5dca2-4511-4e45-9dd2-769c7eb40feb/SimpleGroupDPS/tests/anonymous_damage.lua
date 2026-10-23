local clock = 1000
ACTION_RESULT_DAMAGE, ACTION_RESULT_HEAL, ACTION_RESULT_DAMAGE_SHIELDED = 1, 2, 3
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_PLAYER_PET, COMBAT_UNIT_TYPE_GROUP = 1, 3, 4
COMBAT_UNIT_TYPE_GROUP_PET, COMBAT_UNIT_TYPE_PLAYER_COMPANION, COMBAT_UNIT_TYPE_OTHER = 5, 6, 0
EVENT_COMBAT_EVENT, EVENT_PLAYER_COMBAT_STATE, EVENT_BOSSES_CHANGED, EVENT_EFFECT_CHANGED = 1, 2, 3, 4
local events = {}
function GetGameTimeMilliseconds() return clock end
function DoesUnitExist(tag) return tag == "boss1" end
function GetRawUnitName() return "Boss" end
EVENT_MANAGER = {UnregisterForUpdate = function() end,
    RegisterForEvent = function(_, name, _, callback) events[name] = callback end}
dofile("DamageMeter.lua")
local meter = SimpleGroupDPS_DamageMeter
meter:Initialize()
meter:Start(clock)
local function hit(time, source, target, targetId, amount, sourceId, result, name)
    clock = time
    events.SimpleGroupDPSDamage(nil, result or 1, false, nil, nil, nil, nil,
        source, name or "Boss", target, amount, nil, nil, nil, sourceId or 99, targetId)
end
hit(1100, 0, 0, 42, 9000)
assert(meter:GetStats().groupTotal == 0, "Unknown-target damage must wait for identification")
hit(1200, 1, 0, 42, 1000, 1)
local stats = meter:GetStats()
assert(stats.total == 1000 and stats.groupTotal == 10000, "Own hit identifies the enemy and includes buffered anonymous damage once")
assert(stats.groupBossTotal == 10000 and stats.groupBossDPS == 50000, "Anonymous boss damage uses the same boss filter and duration")
hit(1300, 0, 0, 80, 4000, 88, nil, "Add")
assert(meter:GetStats().groupTotal == 10000)
hit(1500, 0, 1, 1, 50, 80, nil, "Player")
assert(meter:GetStats().groupTotal == 14000 and meter:GetStats().groupBossTotal == 10000,
    "Incoming damage identifies its enemy source but is not added to outgoing group damage")
hit(1700, 0, 0, 77, 5000)
hit(1750, 1, 4, 77, 1000000, 1, ACTION_RESULT_HEAL, "Friend")
assert(meter:GetStats().groupTotal == 14000 and meter:GetStats().durationMS == 700,
    "Healing identifies friends, discards their pending incoming damage and never advances the damage clock")
hit(1800, 0, 0, 48, 1000, 88, nil, "Second Boss")
hit(1900, 0, 0, 48, 2000, 88, nil, "Second Boss")
meter:CorrelateBoss("boss2", 48, "Second Boss")
assert(meter:GetStats().groupTotal == 17000 and meter:GetStats().groupBossTotal == 13000)
meter:CorrelateBoss("boss2", 48, "Second Boss")
assert(meter:GetStats().groupTotal == 17000, "Repeated identification must not replay damage twice")
hit(2000, 3, 0, 42, 200, 3)
hit(2000, 6, 0, 42, 300, 6)
hit(2000, 4, 0, 42, 400, 4)
hit(2100, 5, 0, 42, 500, 5, ACTION_RESULT_DAMAGE_SHIELDED)
hit(2200, 0, 0, 77, 6000)
hit(2200, 0, 0, 0, 99999)
stats = meter:GetStats()
assert(stats.total == 1500 and stats.groupTotal == 18400 and stats.groupBossTotal == 14400,
    "Pets, companions, shield hits and identified group damage count once; friends and missing anonymous IDs do not")
hit(2300, 0, 0, 66, 999)
hit(9999, 1, 4, 77, 1000000, 1, ACTION_RESULT_HEAL)
assert(meter:GetStats().durationMS == 1300 and meter:GetStats().groupTotal == 18400)
meter:Finish()
assert(meter:GetStats().groupTotal == 18400, "Unknown targets must not be guessed hostile at fight end")
clock = 11000
meter:Start(clock)
hit(11100, 1, 0, 66, 1, 1)
assert(meter:GetStats().groupTotal == 1, "New encounter must not inherit unclassified damage or old identity data")
meter:Finish()
hit(11900, 0, 0, 90, 500)
clock = 12000
meter:Start(clock)
hit(12200, 1, 0, 90, 50, 1)
assert(meter:GetStats().groupTotal == 550 and meter:GetStats().total == 50,
    "Pre-combat anonymous hits use the existing bounded one-second replay window")
print("PASS: anonymous damage, delayed enemy/friend identity, boss totals, healing exclusion, native source IDs and encounter isolation")
