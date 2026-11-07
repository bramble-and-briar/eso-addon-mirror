local env=dofile('tests/standalone.lua')
LFG_ROLE_DPS,LFG_ROLE_TANK,LFG_ROLE_HEAL=1,2,4
function GetSelectedLFGRole() return LFG_ROLE_DPS end
function GetGroupMemberSelectedRole() return LFG_ROLE_DPS end
function DoesUnitExist(tag) return tag=='boss1' or tag=='group1' end
function GetRawUnitName(tag) return tag=='boss1' and 'Boss' or '' end
function GetUnitDisplayName(tag) return tag=='group1' and '@OtherDD' or '@Me' end
function AreUnitsEqual(a,b) return a==b end
local meter,bridge=SimpleGroupDPS_DamageMeter,SimpleGroupDPS_BattleScrolls
bridge:Clear()
env.setClock(800000);env.setCombat(true)
env.events['SimpleGroupDPSDamageState:combat'](nil,true)
env.setClock(802000)
meter:OnDamage(1,false,1,'Boss',0,10000,10,99)
env.setClock(805000)
meter:OnDamage(1,false,1,'Add',0,10000,20,99)
meter:OnDamage(1,false,4,'Boss',0,80000,10,55)
env.receive('group1',{messageType='damage',allTargetsDPS=250000,bossDPS=200000})
env.tick()
local stats=meter:GetStats()
assert(stats.total==20000 and stats.dps==4000 and stats.bossDPS==2000)
assert(bridge.SendDPS==nil and bridge.SendMetrics==nil,'Own metrics are never submitted to a sender')
local own
for key,row in pairs(env.window.swtGroupDPSLabels) do
 if type(key)=='number' and row.text=='Me' and not row.hidden then own=row end
end
assert(own and own.swtDPSValue.text=='2,0 Tsd. (4,0 Tsd.)',
 'Own HUD row shows boss DPS and total DPS from the actual own metric')
assert(env.window.swtGroupDPSLabels.summary.swtDPSValue.text=='18,0 Tsd. (20,0 Tsd.)',
 'Group summary stays separate and is not substituted into the own row')
assert(env.personalWindow.primary.text=='Boss: 2,0 Tsd. DPS | 11,1 %')
assert(env.personalWindow.secondary.text=='(Gesamt: 4,0 Tsd. DPS | 20,0 %)')
print('PASS: real raid collector -> own boss/all-target HUD -> personal share -> local-only metrics')
