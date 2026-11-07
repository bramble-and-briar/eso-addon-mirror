-- Mirrors BattleScrolls state:ApplyGroupDamage/UpdateUnitFriendliness at
-- ef6d762d48998fa91e302d99fafce334568a3845: group hits do not identify targets.
local clock = 1000
ACTION_RESULT_DAMAGE, ACTION_RESULT_HEAL = 1, 2
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP = 1, 4
COMBAT_UNIT_TYPE_PLAYER_PET, COMBAT_UNIT_TYPE_PLAYER_COMPANION = 3, 6
COMBAT_UNIT_TYPE_GROUP_PET = 5
function GetGameTimeMilliseconds() return clock end
function DoesUnitExist() return false end
EVENT_MANAGER = {UnregisterForUpdate = function() end}
dofile('DamageMeter.lua')
local meter = SimpleGroupDPS_DamageMeter
meter:Start(clock)
local function hit(source, target, id, value, sourceId, result, ability)
    clock = clock + 100
    meter:OnDamage(result or 1, false, source, 'Target', target, value, id, sourceId or 99, 0, ability)
end
hit(4, 0, 42, 5000)
assert(meter:GetStats().groupTotal == 0, 'Group hits alone must not guess a hostile target')
hit(0, 4, 77, 7000, 42)
assert(meter:GetStats().groupTotal == 0, 'Damage to another group member cannot establish enemy identity')
hit(4, 4, 77, 100, 99, 2)
assert(meter:GetStats().groupTotal == 0, 'Third-party healing cannot establish identity either')
hit(1, 0, 42, 1000, 1)
assert(meter:GetStats().total == 1000 and meter:GetStats().groupTotal == 6000,
    'Own hit resolves pending group damage exactly once')
hit(4, 0, 42, 2000)
assert(meter:GetStats().groupTotal == 8000, 'Later group hits on a known enemy count immediately')
hit(4, 0, 88, 3000)
hit(4, 1, 1, 100, 88, 2)
assert(meter:GetStats().groupTotal == 8000, 'Incoming healing identifies a friend and discards damage to them')
hit(5, 0, 90, 4000)
assert(meter:GetStats().groupTotal == 8000, 'Group pets also wait for target identity')
hit(0, 1, 1, 50, 90)
assert(meter:GetStats().groupTotal == 12000, 'Incoming enemy damage resolves pending damage without adding incoming damage')
hit(4, 0, 91, 9000)
hit(1, 4, 91, 100, 1, 2, 126366)
assert(meter:GetStats().groupTotal == 12000, 'Ignored pet-initialization heal cannot classify a target')
hit(1, 0, 91, 1000, 1)
assert(meter:GetStats().total == 2000 and meter:GetStats().groupTotal == 22000)
print('PASS: group-only unknown targets, delayed hostility, incoming/friendly healing, group pets and ignored heals')
