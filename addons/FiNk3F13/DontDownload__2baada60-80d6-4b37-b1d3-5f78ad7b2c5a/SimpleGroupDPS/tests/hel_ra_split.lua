local clock, zone, inCombat, groupCombat, bossVisible = 1000,636,true,true,true
local callbacks, updates, completed = {},{},{}
ACTION_RESULT_DAMAGE = 1
COMBAT_UNIT_TYPE_PLAYER, COMBAT_UNIT_TYPE_GROUP = 1,4
EVENT_COMBAT_EVENT, EVENT_PLAYER_COMBAT_STATE, EVENT_BOSSES_CHANGED, EVENT_EFFECT_CHANGED = 1,2,3,4
EFFECT_RESULT_GAINED, EFFECT_RESULT_FADED = 1,3
function GetGameTimeMilliseconds() return clock end
function GetCurrentMapZoneIndex() return zone end
function GetZoneId(index) return index end
function IsUnitInCombat(tag) return tag=='player' and inCombat or tag=='group1' and groupCombat end
function GetGroupSize() return 1 end
function ZO_Group_GetUnitTagForGroupIndex() return 'group1' end
function IsUnitOnline() return true end
function AreUnitsEqual(a,b) return a==b end
function DoesUnitExist(tag) return bossVisible and tag=='boss1' end
function GetRawUnitName(tag) return bossVisible and tag=='boss1' and 'Split Boss' or '' end
function IsUnitDead() return false end
function GetUnitPower() return 50,100 end
EVENT_MANAGER = {RegisterForEvent=function(_,name,_,fn) callbacks[name]=fn end,
    RegisterForUpdate=function(_,name,_,fn) updates[name]=fn end,
    UnregisterForUpdate=function(_,name) updates[name]=nil end}
dofile('DamageMeter.lua')
local meter = SimpleGroupDPS_DamageMeter
meter:Initialize()
meter.onFinished=function(stats) completed[#completed+1]=stats end
meter:Start(clock)
meter:OnDamage(1,false,1,'Split Boss',0,1000,30,99)
clock=3000
meter:OnDamage(1,false,0,'Player',1,100,99,30)
assert(meter:GetStats().durationMS==2000 and meter:GetStats().total==1000,
    'Incoming raid damage advances the clock without adding to own damage')
callbacks.SimpleGroupDPSDamageEffects(nil,1,nil,nil,'boss1',nil,nil,nil,nil,nil,nil,nil,nil,'Split Boss',30,50184)
assert(meter:IsActive() and meter:GetStats().total==1000 and #completed==0,
    'Generic Mage appearance effect cannot reset Hel Ra')
clock,inCombat,groupCombat,bossVisible=4000,false,true,false
callbacks.SimpleGroupDPSDamageState(nil,false)
clock=4150
updates.SimpleGroupDPSDamageReset()
assert(meter:IsActive(), 'Original BattleScrolls group-combat rule holds the split despite missing local boss tags')
clock,groupCombat=6000,true
updates.SimpleGroupDPSDamageReset()
assert(meter:IsActive() and #completed==0, 'Other route keeps encounter alive')
clock,inCombat=7000,true
callbacks.SimpleGroupDPSDamageState(nil,true)
assert(meter:GetStats().total==1000, 'Combat reentry retains earlier split damage')
clock=8000
meter:OnDamage(1,false,1,'Other Split Boss',0,1000,40,99)
assert(meter:GetStats().total==2000 and meter:GetStats().durationMS==7000)
clock,inCombat,groupCombat=9000,false,false
callbacks.SimpleGroupDPSDamageState(nil,false)
clock=9150
updates.SimpleGroupDPSDamageReset()
assert(not meter:IsActive() and #completed==1 and completed[1].total==2000 and completed[1].durationMS==7000,
    'Original BattleScrolls finishes after 150ms once player/group/boss/portal/death holds are clear')
-- Every zone now uses the same observed-damage clock; no Hel Ra timing special case.
zone,clock,inCombat=1,20000,true
meter:Start(clock)
meter:OnDamage(1,false,1,'Dummy',7,1000,50,99)
clock=25000
meter:OnDamage(1,false,0,'Player',1,100,99,50)
assert(meter:GetStats().durationMS==5000 and meter:GetStats().total==1000,
    'Incoming damage advances the clock in every zone without increasing own damage')
print('PASS: Hel Ra split, incoming raid clock, AA-only reset, group combat reentry, original reset delay and uniform timing across zones')
