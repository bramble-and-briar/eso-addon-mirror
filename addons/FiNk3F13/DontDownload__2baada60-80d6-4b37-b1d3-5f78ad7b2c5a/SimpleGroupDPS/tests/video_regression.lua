-- Video VID_20261107_221256: a late passive heal inflated HPS; own total DPS
-- omitted personal friendly damage that BattleScrolls ApplyPersonalDamage keeps.
local clock=1000
ACTION_RESULT_DAMAGE,ACTION_RESULT_HEAL=1,2
COMBAT_UNIT_TYPE_PLAYER,COMBAT_UNIT_TYPE_GROUP=1,4
function GetGameTimeMilliseconds() return clock end
function DoesUnitExist(tag) return tag=='boss1' end
function GetRawUnitName() return 'Boss' end
EVENT_MANAGER={UnregisterForUpdate=function() end}
dofile('DamageMeter.lua')
local m=SimpleGroupDPS_DamageMeter
m:Start(clock)
clock=2000
m:OnDamage(1,false,1,'Boss',0,600000,42,1)
clock=28000
m:OnDamage(1,false,0,'Player',1,100,1,42)
m:OnDamage(2,false,1,'Player',1,5700,1,1,86100,123)
local stats=m:GetStats()
assert(stats.durationMS==27000 and stats.bossTotal==600000)
assert(stats.rawHPS==3400 and math.abs(stats.effectiveHPS-5700/27)<0.000001,
    'A late passive heal uses all 27 seconds, not a 1-second healing window')
clock=29000
m:OnDamage(1,false,1,'Player',1,16800,1,1)
stats=m:GetStats()
assert(stats.total==616800 and stats.groupTotal==616800 and stats.bossTotal==600000,
    'Personal self-damage changes total damage only; boss total is unchanged')
assert(math.abs(stats.dps-616800/28)<0.000001 and stats.rawHPS==91800/28)
clock=30000
m:OnDamage(1,false,1,'Friendly',4,1000,77,1)
stats=m:GetStats()
assert(stats.total==617800 and stats.groupTotal==617800 and stats.bossTotal==600000)
local before=stats.total
clock=31000
m:OnDamage(1,false,0,'Friendly',4,99999,77,42)
assert(m:GetStats().total==before and m:GetStats().groupTotal==before,
    'Incoming third-party damage to friends must still stay excluded')
local final=m:GetStats()
m:Finish()
clock=90000
assert(m:GetStats().dps==final.dps and m:GetStats().rawHPS==final.rawHPS)
print('PASS: late passive-heal video regression; personal self/friendly damage matches BattleScrolls scope; stable boss/timer/final result')
