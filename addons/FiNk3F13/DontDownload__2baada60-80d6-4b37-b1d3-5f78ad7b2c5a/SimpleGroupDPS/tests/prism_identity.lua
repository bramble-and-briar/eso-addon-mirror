local clock, bossName = 1000, 'Verteidigungsprisma^n'
ACTION_RESULT_DAMAGE=1;COMBAT_UNIT_TYPE_PLAYER=1;COMBAT_UNIT_TYPE_GROUP=4
function GetGameTimeMilliseconds() return clock end
function DoesUnitExist(tag) return tag=='boss1' end
function GetRawUnitName() return bossName end
EVENT_MANAGER={UnregisterForUpdate=function() end}
dofile('DamageMeter.lua')
local m=SimpleGroupDPS_DamageMeter;m:Start(clock)
local function hit(id,name,value,source)
 clock=clock+100;m:OnDamage(1,false,source or 1,name,0,value,id,source==4 and 55 or 1)
end
-- Raw names that look the same after formatting are not interchangeable bosses.
hit(47952,'Verteidigungsprisma',203065)
assert(m:GetStats().bossTotal==nil)
m:CorrelateBoss('boss1',71988,'Verteidigungsprisma^n')
hit(71988,bossName,1000)
assert(m:GetStats().total==204065 and m:GetStats().bossTotal==1000)
-- A later authoritative effect can identify the earlier raw-name target as
-- this recreated boss; its damage moves to the canonical ID without duplication.
m:CorrelateBoss('boss1',47952,bossName)
assert(m:GetComparisonSnapshot().targets[71988].total==204065)
assert(m:GetComparisonSnapshot().targets[47952]==nil)
-- Confirmed same-raw-name boss recreated on the client: merge into stable ID.
hit(80000,bossName,2000)
m:CorrelateBoss('boss1',80000,bossName)
local snap=m:GetComparisonSnapshot()
assert(snap.targets[71988].total==206065 and snap.targets[80000]==nil and snap.targets[47952]==nil)
assert(m:GetStats().total==206065 and m:GetStats().bossTotal==206065)
-- Another raw-name target reusing the boss tag is a new boss, not a redirect.
bossName='Verteidigungsprisma';m:RefreshBosses()
m:CorrelateBoss('boss1',48326,bossName)
hit(48326,bossName,191098)
assert(m:GetStats().bossTotal==397163 and m:GetComparisonSnapshot().targets[48326].total==191098)
-- An effect does not release group-only unknown-target damage.
bossName='Other Boss';m:RefreshBosses()
hit(90000,bossName,500000,4)
local groupBefore=m:GetStats().groupTotal
m:CorrelateBoss('boss1',90000,bossName)
assert(m:GetStats().groupTotal==groupBefore)
clock=clock+100;m:OnDamage(1,false,0,'Player',1,10,1,90000)
assert(m:GetStats().groupTotal==groupBefore+500000,'Only actual personal interaction confirms hostility')
assert(m:GetStats().total==397163,'Redirecting targets cannot add or drop personal damage')
print('PASS: raw prism names, stable canonical boss IDs, retroactive merges, tag reuse and unknown group gating')
