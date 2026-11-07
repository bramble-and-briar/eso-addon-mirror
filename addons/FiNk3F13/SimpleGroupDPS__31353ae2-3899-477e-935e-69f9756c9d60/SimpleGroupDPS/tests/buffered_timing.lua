local clock = 100
ACTION_RESULT_DAMAGE = 1
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP, COMBAT_UNIT_TYPE_TARGET_DUMMY = 1, 4, 7
function GetGameTimeMilliseconds() return clock end
function DoesUnitExist() return false end
function IsUnitInCombat() return true end
EVENT_MANAGER = {UnregisterForUpdate=function() end}
dofile('DamageMeter.lua')
local meter = SimpleGroupDPS_DamageMeter
-- Native dummy data must have no effect, even if available.
ZO_TARGET_DUMMY_LOGS = {logObjects={[10]={GetDamageTaken=function() return 23600 end,
    GetTimeSpentTakingDamage=function() return 999 end}}}
for _, targetType in ipairs({7,8}) do
    clock = 100
    meter:OnDamage(1,false,1,'Target',targetType,100,10,99)
    clock = 1099
    meter:Start(clock)
    clock = 23700
    meter:OnDamage(1,false,1,'Target',targetType,23500,10,99)
    local live = meter:GetStats()
    assert(live.total == 23600 and live.durationMS == 22601 and math.abs(live.dps - 23600000 / 22601) < 0.000001,
        'Replay buffered damage without backdating combat start, exactly as BattleScrolls')
    clock = 30000
    meter:Finish()
    local final = meter:GetStats()
    assert(final.durationMS == live.durationMS and final.dps == live.dps,
        'Combat exit does not add a second or change final DPS')
end
clock = 40000
meter:OnDamage(1,false,1,'Old hit',8,500,10,99)
clock = 41001
meter:Start(clock)
clock = 42001
meter:OnDamage(1,false,1,'New hit',8,1000,10,99)
assert(meter:GetStats().total == 1000 and meter:GetStats().durationMS == 1000,
    'Expired precombat hits cannot backdate the next fight')
print('PASS: buffered damage and timestamps stay together for every target; native dummy log ignored; stable final clock')
