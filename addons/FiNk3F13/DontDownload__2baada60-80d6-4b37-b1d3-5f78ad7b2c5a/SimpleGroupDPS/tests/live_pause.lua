local env = dofile('tests/standalone.lua')
local meter, bridge = SimpleGroupDPS_DamageMeter, SimpleGroupDPS_BattleScrolls
function DoesUnitExist() return false end
bridge:Clear()
local connects=0
local connect=bridge.Connect
bridge.Connect=function(self) connects=connects+1;return connect(self) end
env.setClock(800000)
env.setCombat(true)
env.events['SimpleGroupDPSDamageState:combat'](nil,true)
meter:OnDamage(1,false,1,'Enemy',0,10000,10,99)
env.setClock(817000)
meter:OnDamage(1,false,1,'Enemy',0,13308.7,10,99)
env.tick()
local damage = meter:GetStats()
assert(damage.durationMS == 17000 and math.abs(damage.dps-1371.1) < 0.000001)
local priorConnects = connects
env.setClock(827000)
env.tick()
assert(meter:GetStats().durationMS == 17000 and meter:GetStats().dps == damage.dps,
    '17s damage followed by 10s idle must never become a 27s damage result')
assert(env.window.swtGroupDPSLabels[0].swtDPSValue.text == '0:17')
assert(connects > priorConnects and type(bridge.SendDPS)=="function", '300ms update/share loop stays active without inventing elapsed damage time')
env.setCombat(false)
env.events['SimpleGroupDPSDamageState:combat'](nil,false)
env.setClock(828000)
env.updates.SimpleGroupDPSDamageReset()
assert(not meter:IsActive() and meter:GetStats().durationMS == 17000 and meter:GetStats().dps == damage.dps)
assert(env.saved.lastSummary.damageDurationMS == 17000 and env.saved.lastSummary.dps == damage.dps,
    'Delayed combat exit cannot dilute the stored result')
env.setClock(832000)
env.tick()
assert(meter:GetStats().durationMS == 17000 and env.window.swtGroupDPSLabels[0].swtDPSValue.text == '0:17')
print('PASS: 17s damage plus 10s idle remains 17s; update loop active; same live/saved/final DPS, automatic sharing')
