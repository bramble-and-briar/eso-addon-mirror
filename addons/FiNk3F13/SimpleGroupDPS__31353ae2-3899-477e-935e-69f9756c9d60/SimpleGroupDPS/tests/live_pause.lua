local env = dofile('tests/standalone.lua')
local meter, bridge = SimpleGroupDPS_DamageMeter, SimpleGroupDPS_BattleScrolls
function DoesUnitExist() return false end
bridge:Clear()
local sent
bridge.SendDPS = function(_,dps) sent = dps; return true end
env.setClock(800000)
env.setCombat(true)
env.events['SimpleGroupDPSDamageState:combat'](nil,true)
meter:OnDamage(1,false,1,'Enemy',0,10000,10,99)
env.setClock(802000)
meter:OnDamage(1,false,1,'Enemy',0,2000,10,99)
env.tick()
assert(meter:GetStats().dps == 6000 and sent == 6000)
env.setClock(803000)
env.tick()
assert(meter:GetStats().total == 12000 and meter:GetStats().dps == 4000 and sent == 4000,
    'No new damage: collector and sender update using live elapsed time')
assert(env.window.swtGroupDPSLabels[0].swtDPSValue.text == '0:03')
assert(env.window.swtGroupDPSLabels[1].swtDPSValue.text == '4,0 Tsd.')
env.setClock(805000)
env.tick()
assert(meter:GetStats().dps == 2400 and sent == 2400)
env.setCombat(false)
env.events['SimpleGroupDPSDamageState:combat'](nil,false)
env.setClock(806000)
env.updates.SimpleGroupDPSDamageReset()
assert(not meter:IsActive() and meter:GetStats().dps == 2400 and meter:GetStats().durationMS == 5000,
    'Combat exit freezes the same elapsed-time formula without jumping to last-hit DPS')
assert(env.saved.lastSummary.dps == 2400 and env.saved.lastSummary.damageDurationMS == 5000)
env.setClock(810000)
env.tick()
assert(meter:GetStats().dps == 2400 and env.window.swtGroupDPSLabels[0].swtDPSValue.text == '0:05',
    'Final result stays frozen')
print('PASS: live DPS without attacks/DoTs, shared HUD/send snapshots, combat-exit boundary and frozen final result')
