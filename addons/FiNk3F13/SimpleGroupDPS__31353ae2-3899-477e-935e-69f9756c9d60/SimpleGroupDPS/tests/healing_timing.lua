local clock = 1000
ACTION_RESULT_DAMAGE, ACTION_RESULT_HEAL = 1,2
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP = 1,4
function GetGameTimeMilliseconds() return clock end
function DoesUnitExist() return false end
function IsUnitInCombat() return true end
EVENT_MANAGER = {UnregisterForUpdate=function() end}
dofile('DamageMeter.lua')
local meter = SimpleGroupDPS_DamageMeter
meter:Start(clock)
meter:OnDamage(1,false,1,'Enemy',0,1000,99,10)
clock = 1001
meter:OnDamage(1,false,1,'Enemy',0,1000,99,10)
assert(meter:GetStats().dps == 2000000 and meter:GetStats().durationMS == 1,
    'Exact BattleScrolls subsecond timing has no custom DPS denominator floor')
local function heal(time)
    clock = time
    meter:OnDamage(2,false,1,'Ally',4,5000,20,10,5000,123)
end
heal(2000)
heal(12000)
local stats = meter:GetStats()
assert(stats.rawHealingTotal == 20000 and stats.rawHPS == 20000000 and stats.effectiveHPS == 10000000)
assert(stats.healingDurationMS == 10000 and stats.durationMS == 1 and stats.dps == 2000000,
    'Only healing continues: healing clock advances without changing damage time')
clock = 12100
meter:OnDamage(1,false,1,'Enemy',0,1000,99,10)
assert(math.abs(meter:GetStats().rawHPS-20000/11.1)<0.000001,
    'Resuming attacks changes the common encounter denominator exactly as BattleScrolls')
heal(22000)
assert(math.abs(meter:GetStats().rawHPS-30000/11.1)<0.000001 and math.abs(meter:GetStats().effectiveHPS-15000/11.1)<0.000001,
    'Continued healing uses the same last-damage encounter duration')
clock = 30000
meter:Finish()
assert(math.abs(meter:GetStats().rawHPS-30000/11.1)<0.000001 and meter:GetStats().healingDurationMS == 20000,
    'Final healing result freezes with the encounter duration')
print('PASS: heal-only continuation, attack resumption, BattleScrolls encounter HPS clock and subsecond DPS safety')
