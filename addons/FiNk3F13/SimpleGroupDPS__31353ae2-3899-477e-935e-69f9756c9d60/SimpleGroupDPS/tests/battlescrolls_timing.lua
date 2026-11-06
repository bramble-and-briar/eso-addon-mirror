-- Acceptance cases for the clock in BattleScrolls combat/arithmancer.lua
-- Combat entry -> last damage, with a stable estimate for a hit at combat entry.
local clock, inCombat = 900, true
local events = {}
ACTION_RESULT_DAMAGE, ACTION_RESULT_DOT_TICK = 1, 2
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP, COMBAT_UNIT_TYPE_TARGET_DUMMY = 1,4,7
EVENT_COMBAT_EVENT, EVENT_PLAYER_COMBAT_STATE, EVENT_BOSSES_CHANGED, EVENT_EFFECT_CHANGED = 1,2,3,4
function GetGameTimeMilliseconds() return clock end
function IsUnitInCombat() return inCombat end
function DoesUnitExist() return false end
EVENT_MANAGER = {
    RegisterForEvent = function(_, name, _, callback) events[name] = callback end,
    UnregisterForUpdate = function() end,
}
dofile("DamageMeter.lua")
local meter = SimpleGroupDPS_DamageMeter
meter:Initialize()
meter:OnDamage(1, false, 1, "Dummy", 7, 500, 10)
assert(not meter:IsActive(), "damage before combat-state event is buffered even if API already says in combat")
clock = 1000
events.SimpleGroupDPSDamageState(nil, true)
assert(meter:GetStats().total == 500 and meter:GetStats().durationMS == 1000,
    "precombat hit contributes damage with a fixed estimate while preserving the actual buffered hit timestamp")
clock = 1300
assert(meter:GetStats().durationMS == 1000 and meter:GetStats().dps == 500,
    "first-hit-only sample does not decay while idle")
clock = 12000
assert(meter:GetStats().durationMS == 11100 and math.abs(meter:GetStats().dps - 500000 / 11100) < 0.000001,
    "Live DPS declines without new damage")
clock = 1300
meter:OnDamage(1, false, 1, "Dummy", 7, 1000, 10)
clock = 7000
assert(meter:GetStats().durationMS == 6100 and math.abs(meter:GetStats().dps - 1500000 / 6100) < 0.000001,
    "Active combat clock advances between damage events")
local idle = meter:GetDiagnostics()
assert(idle.active and idle.inCombat and idle.damageAgeMS == 5700 and idle.personalEvents == 1,
    "diagnostics distinguish an active encounter with no new damage from a stopped measurement")
meter:OnDamage(1, false, 4, "Dummy", 7, 9999, 10)
assert(meter:GetStats().total == 1500 and meter:GetStats().durationMS == 6100 and math.abs(meter:GetStats().dps - 1500000 / 6100) < 0.000001,
    "observed group damage updates shared encounter clock without becoming personal damage")
assert(meter:GetDiagnostics().otherEvents == 1 and meter:GetDiagnostics().damageAgeMS == 0,
    "diagnostics show external damage continuing the clock without own DoTs")
clock = 7300
meter:OnDamage(1, false, 1, "Dummy", 7, 0, 10)
assert(meter:GetStats().total == 1500 and meter:GetStats().durationMS == 6400,
    "zero-value damage event advances clock like Battle Scrolls without adding damage")
clock = 7600
meter:OnDamage(2, false, 1, "Dummy", 7, 500, 10)
assert(meter:GetStats().total == 2000 and meter:GetStats().durationMS == 6700, "DoT hit uses same clock as direct hit")
local live = meter:GetStats()
clock = 10000
meter:Finish()
assert(meter:GetStats().durationMS == 9100 and math.abs(meter:GetStats().dps - 2000000 / 9100) < 0.000001,
    "final display/sending sample keeps the same clock once later damage exists")
clock = 11000
local finished = meter:GetDiagnostics()
assert(not finished.active and finished.finishedAgeMS == 1000 and finished.damageAgeMS == 3400
    and finished.personalEvents == 3 and finished.otherEvents == 1,
    "diagnostics preserve the finished fight so opening chat after a pause does not erase evidence")

-- A short burst uses the same minimum duration for all targets.
clock = 20000
meter:Start(clock)
meter:OnDamage(1, false, 1, "Dummy", 7, 2000, 10)
clock = 20677
meter:OnDamage(1, false, 1, "Dummy", 7, 2319, 10)
assert(meter:GetStats().durationMS == 1000 and math.floor(meter:GetStats().dps + 0.5) == 4319,
    "subsecond bursts use a stable one-second minimum without reading dummy chat")
meter:Finish()
assert(meter.OnDummyResult == nil, "dummy chat cannot override Battle Scrolls calculation")
print("PASS: combat entry, buffer, stable first-hit estimate, shared damage clock and multi-hit dummy parity")
