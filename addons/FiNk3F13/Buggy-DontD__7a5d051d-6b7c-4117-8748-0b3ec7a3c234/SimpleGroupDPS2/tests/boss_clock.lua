local clock, boss = 0, false
ACTION_RESULT_DAMAGE=1
COMBAT_UNIT_TYPE_PLAYER,COMBAT_UNIT_TYPE_GROUP=1,4
function IsUnitInCombat() return false end
function GetGameTimeMilliseconds() return clock end
function DoesUnitExist(tag) return boss and tag=='boss1' end
function GetRawUnitName() return 'Boss' end
EVENT_MANAGER={UnregisterForUpdate=function() end,RegisterForEvent=function() end}
dofile('DamageMeter.lua')
local meter=SimpleGroupDPS2_DamageMeter
local function hit(time,name,amount,id,source)
 clock=time;meter:OnDamage(1,false,source or 1,name,0,amount,id,99)
end
meter:Start(0)
hit(1000,'Add',1000,20)
assert(meter:GetStats().bossDPS==nil)
boss=true;meter:RefreshBosses()
hit(10000,'Boss',30000,10)
local s=meter:GetStats()
assert(s.bossDPS==0 and s.bossDurationMS==0 and s.durationMS==10000)
hit(12000,'Add',1000,20)
s=meter:GetStats()
assert(meter:GetDiagnostics().bossDurationMS==2000,"Status exposes the actual boss clock")
assert(s.bossDPS==15000 and s.dps==32000/12 and s.bossDurationMS==2000 and s.durationMS==12000)
boss=false;meter:RefreshBosses()
hit(15000,'Add',1000,20)
s=meter:GetStats()
assert(s.bossDPS==6000 and s.groupBossDPS==6000 and s.durationMS==15000)
meter:Start(16000) -- temporary reentry must not reset either clock
assert(meter:GetStats().bossDurationMS==5000)
clock=30000;meter:Finish()
assert(meter:GetStats().bossDurationMS==5000 and meter:GetStats().durationMS==15000)
assert(meter:GetDiagnostics().bossDurationMS==5000,"Final status preserves the boss clock")
meter:Start(30000);hit(31000,'Add',100,20)
assert(meter:GetStats().bossDPS==nil and meter:GetStats().bossDurationMS==nil)
-- Recognition after damage must recover the actual first boss hit.
hit(32000,'Unknown',10000,40);hit(34000,'Add',100,20)
meter:CorrelateBoss('boss1',40,'Boss')
s=meter:GetStats()
assert(s.bossDurationMS==2000 and s.bossDPS==5000 and s.durationMS==4000)
meter:Finish()
meter:Initialize({bossDPS=5000,bossDurationMS=2000,damageDurationMS=4000})
assert(meter:GetStats().bossDurationMS==2000)
print('PASS: adds -> boss clock, unchanged overall time, sticky boss mode, reentry, idle finish, delayed recognition, reset and reload')
