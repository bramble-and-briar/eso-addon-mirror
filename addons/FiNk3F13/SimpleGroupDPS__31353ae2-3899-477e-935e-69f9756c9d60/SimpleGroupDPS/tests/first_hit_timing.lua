local clock = 1000
ACTION_RESULT_DAMAGE = 1
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP, COMBAT_UNIT_TYPE_TARGET_DUMMY = 1,4,7
function GetGameTimeMilliseconds() return clock end
function DoesUnitExist() return false end
function IsUnitInCombat() return true end
EVENT_MANAGER = {UnregisterForUpdate=function() end}
dofile('DamageMeter.lua')
local meter = SimpleGroupDPS_DamageMeter
-- Reproduce the screenshot's 7.9s versus 7.3s: combat state precedes damage by 600ms.
for _, targetType in ipairs({7,8}) do
    clock = 1000
    meter:Start(clock)
    clock = 1600
    meter:OnDamage(1,false,1,'Enemy',targetType,1000,10,99)
    clock = 8900
    meter:OnDamage(1,false,1,'Enemy',targetType,7033.65,10,99)
    local stats = meter:GetStats()
    assert(stats.durationMS == 7300 and math.abs(stats.dps-1100.5) < 0.000001,
        'Start at first hit: 7.3s and 1100.5 DPS, rather than 7.9s and 1016.9 DPS')
    clock = 9500
    meter:OnDamage(1,false,8,'Player',1,500,99,10)
    assert(meter:GetStats().durationMS == 7300, 'Incoming damage does not extend outgoing DPS')
    clock = 10000
    meter:OnDamage(1,false,1,'Friend',4,500,20,99)
    assert(meter:GetStats().durationMS == 7300, 'Friendly damage does not extend outgoing DPS')
    clock = 12000
    meter:Finish()
    assert(meter:GetStats().durationMS == 7300 and math.abs(meter:GetStats().dps-1100.5) < 0.000001,
        'Same measured clock and DPS before and after combat exit')
end
print('PASS: screenshot reproduction, first outgoing hit clock, incoming/friendly exclusion and stable final DPS')
