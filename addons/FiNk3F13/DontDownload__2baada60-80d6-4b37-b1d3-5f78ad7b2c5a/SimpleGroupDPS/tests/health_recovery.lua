local clock, regen, dead, health, cap = 1000, 300, false, 1000, 1000
STAT_HEALTH_REGEN_COMBAT, STAT_BONUS_OPTION_APPLY_BONUS, COMBAT_MECHANIC_FLAGS_HEALTH = 1, 2, 3
ACTION_RESULT_DAMAGE, ACTION_RESULT_HEAL = 1, 2
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP = 1, 4
EVENT_POWER_UPDATE, EVENT_STATS_UPDATED, EVENT_PLAYER_DEAD, EVENT_PLAYER_ALIVE = 10, 11, 12, 13
EVENT_COMBAT_EVENT, EVENT_PLAYER_COMBAT_STATE, EVENT_BOSSES_CHANGED, EVENT_EFFECT_CHANGED = 20, 21, 22, 23
local events = {}
function GetGameTimeMilliseconds() return clock end
function GetPlayerStat() return regen end
function IsUnitDead() return dead end
function GetUnitPower() return health, cap end
function DoesUnitExist() return false end
EVENT_MANAGER = {UnregisterForUpdate=function() end,
 RegisterForEvent=function(_,name,_,fn) events[name]=fn end}
dofile('HealthRecovery.lua')
dofile('DamageMeter.lua')
local meter, tracker = SimpleGroupDPS_DamageMeter, SimpleGroupDPS_HealthRecovery
meter:Initialize(); meter:Start(clock)
clock = 11000
meter:OnDamage(1,false,1,'Enemy',0,1000,42,1)
local stats = meter:GetStats()
assert(stats.rawHealingTotal==1500 and stats.effectiveHealingTotal==0 and stats.rawHPS==150,
 'Natural recovery contributes raw self-healing even at full health')
tracker:OnHealth(700,1000)
tracker:OnHealth(950,1000)
meter:OnDamage(2,false,4,'Player',1,100,1,77,0,123)
stats=meter:GetStats()
assert(stats.effectiveHealingTotal==150 and stats.effectiveHPS==15,
 'Effective recovery subtracts healing from other players; incoming heal is not our output')
clock=21000;regen=600;tracker:OnStats()
clock=31000;dead=true;tracker:OnDeath(true)
clock=41000
assert(meter:GetStats().rawHealingTotal==6000,'Recovery integrates stat changes and excludes dead time')
dead=false;tracker:OnDeath(false)
clock=51000
assert(meter:GetStats().rawHealingTotal==9000)
tracker:OnHealth(1800,2000)
assert(meter:GetStats().effectiveHealingTotal==150,'Increased maximum health does not count as regeneration')
meter:OnDamage(2,false,1,'Player',1,400,1,1,600,123)
tracker:OnHealth(2000,2000)
stats=meter:GetStats()
assert(stats.rawHealingTotal==10000 and stats.effectiveHealingTotal==400,
 'Explicit self-healing is counted once and removed from inferred effective recovery')
assert(stats.total==1000 and stats.durationMS==10000 and stats.dps==100,'Recovery never changes damage or timer')
meter:Finish(); clock=91000
assert(meter:GetStats().rawHealingTotal==10000 and meter:GetStats().effectiveHealingTotal==400)
meter:Start(clock)
assert(meter:GetStats().rawHealingTotal==0 and meter:GetStats().effectiveHealingTotal==0,'Recovery resets per encounter')
assert(events.SimpleGroupDPSRecoveryPower and events.SimpleGroupDPSRecoveryStats)
print('PASS: independent natural regen, full health, incoming heals, stats, death/revive, max-health changes and final/reset isolation')
