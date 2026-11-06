ACTION_RESULT_HEAL = 5
local env = dofile('tests/standalone.lua')
LFG_ROLE_DPS, LFG_ROLE_TANK, LFG_ROLE_HEAL = 1,2,4
function GetSelectedLFGRole() return LFG_ROLE_HEAL end
function IsUnitGrouped() return false end
function DoesUnitExist() return false end
SimpleGroupDPS_BattleScrolls:Clear()
local meter = SimpleGroupDPS_DamageMeter
env.setClock(800000)
env.setCombat(true)
env.events['SimpleGroupDPSDamageState:combat'](nil,true)
local function heal(time)
    env.setClock(time)
    meter:OnDamage(5,false,1,'Self',1,1000,10,10,1000,123)
    env.tick()
end
heal(801000)
local rows = env.window.swtGroupDPSLabels
assert(rows[0].hidden and not rows.healingHeader.hidden)
assert(rows.healingHeader.swtDPSValue.text == '0:00', 'Solo healer timer starts at zero, without the HPS rate floor')
assert(meter:GetStats().rawHPS == 2000 and meter:GetStats().healingDurationMS == 0,
    'A first heal keeps stable HPS without inventing elapsed time')
heal(801500)
assert(rows.healingHeader.swtDPSValue.text == '0:00' and meter:GetStats().healingDurationMS == 500)
heal(802000)
assert(rows.healingHeader.swtDPSValue.text == '0:01')
heal(813900)
assert(rows.healingHeader.swtDPSValue.text == '0:12', 'Timer uses actual healing duration with whole seconds')
assert(meter:GetStats().total == 0 and meter:GetStats().healingDurationMS == 12900)
env.setCombat(false)
meter:Finish()
env.setClock(820000)
env.tick()
assert(rows.healingHeader.swtDPSValue.text == '0:12', 'Final healing timer stays frozen')
assert(env.saved.lastSummary.healingDurationMS == 12900)
-- A healer attacking the dummy must see the same fight clock as a DD,
-- even when healing continues after the last attack.
env.setClock(900000)
env.setCombat(true)
meter:Start(900000)
env.setClock(900600)
meter:OnDamage(1,false,1,'Enemy',0,1000,99,10)
heal(900700)
env.setClock(907900)
meter:OnDamage(1,false,1,'Enemy',0,1000,99,10)
heal(909400)
local healerTime = rows.healingHeader.swtDPSValue.text
assert(healerTime == '0:08' and meter:GetStats().durationMS == 8800)
assert(meter:GetStats().healingDurationMS == 8700, 'HPS retains its independent healing clock')
function GetSelectedLFGRole() return LFG_ROLE_DPS end
env.tick()
assert(rows[0].swtDPSValue.text == healerTime, 'Switching DD/healer cannot change displayed fight time')
print('PASS: solo healer timer, no damage required, precise healing clock and final retention')
