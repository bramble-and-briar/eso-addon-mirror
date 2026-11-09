local clock=1000
local bossName='Boss'
ACTION_RESULT_DAMAGE=1
COMBAT_UNIT_TYPE_PLAYER,COMBAT_UNIT_TYPE_GROUP=1,4
function GetGameTimeMilliseconds() return clock end
function DoesUnitExist(tag) return tag=='boss1' end
function GetRawUnitName() return bossName end
EVENT_MANAGER={UnregisterForUpdate=function() end}
dofile('DamageMeter.lua')
local meter=SimpleGroupDPS_DamageMeter
meter:Start(clock)
local function hit(time,id,amount,source,name)
 clock=time
 meter:OnDamage(1,false,source or 1,name or bossName,0,amount,id,source==4 and 55 or 99)
end
hit(2000,10,1000)
hit(2500,11,400)
assert(meter:GetStats().total==1400 and meter:GetStats().bossTotal==1000,
 'Name fallback assigns only one target ID, as in BattleScrolls')
meter:CorrelateBoss('boss1',11,'Boss')
assert(meter:GetStats().total==1400 and meter:GetStats().bossTotal==400,
 'Authoritative boss ID corrects an earlier name guess retroactively')
hit(3000,11,600)
assert(meter:GetStats().dps==1000 and meter:GetStats().bossDPS==500)
meter:CorrelateBoss('boss1',20,'Boss')
hit(4000,20,700)
assert(meter:GetStats().bossTotal==1700,'Recreated confirmed boss retains prior boss damage')
hit(4500,30,300)
assert(meter:GetStats().total==3000 and meter:GetStats().bossTotal==1700,
 'Same-name adds do not inflate boss DPS after recreation')
bossName='Next Boss';meter:RefreshBosses()
hit(5000,40,9000,4)
assert(meter:GetStats().groupBossTotal==1700,'Group-only damage does not invent boss ID assignment')
meter:CorrelateBoss('boss1',40,'Next Boss')
assert(meter:GetStats().groupBossTotal==1700,'Boss effect does not release unknown group damage')
meter:OnDamage(1,false,0,'Player',1,10,99,40)
assert(meter:GetStats().groupBossTotal==10700 and meter:GetStats().bossTotal==1700,
 'Boss tag reuse includes confirmed group boss damage while keeping own damage separate')
print('PASS: one-target boss fallback, correction, same-name adds, recreated IDs and group boss confirmation')
