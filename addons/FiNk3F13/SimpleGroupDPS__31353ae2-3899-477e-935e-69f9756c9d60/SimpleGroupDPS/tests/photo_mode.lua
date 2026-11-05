local env = dofile('tests/standalone.lua')
LFG_ROLE_DPS, LFG_ROLE_TANK, LFG_ROLE_HEAL = 1, 2, 4
local photo = env.menu['Fotomodus']
assert(photo and not photo.getFunction())
local before = SimpleGroupDPS_DamageMeter:GetStats().total
local sent = SimpleGroupDPS_BattleScrolls:GetStatus().queuedCount
photo.setFunction(true)
assert(photo.getFunction() and not env.window.hidden and not env.personalWindow.hidden)
local rows = env.window.swtGroupDPSLabels
local visible = 0
for i = 1, 12 do
    assert(rows[i] and not rows[i].hidden)
    assert(rows[i].text ~= 'Me' and not rows[i].swtDPSValue.text:find('Keine',1,true))
    visible = visible + 1
end
assert(visible == 12 and rows[3].color[1] == 1, 'Twelve fictional names and own gold highlight')
assert(rows[11].text == 'DawnHealer' and not rows.healingHeader.hidden)
assert(rows[0].swtDPSValue.text == '1:12')
env.tick()
assert(SimpleGroupDPS_DamageMeter:GetStats().total == before)
assert(SimpleGroupDPS_BattleScrolls:GetStatus().queuedCount == sent)
assert(next(env.saved.lastSummary) == nil and env.saved.photoMode == nil, 'Never save screenshot values')
env.menu['Tanks anzeigen'].setFunction(false)
assert(rows[9].text == 'DawnHealer' and rows[11].hidden, 'Role filters apply to preview')
env.menu['Tanks anzeigen'].setFunction(true)
photo.setFunction(false)
assert(env.window.hidden and env.personalWindow.hidden, 'Disable restores actual empty encounter')
photo.setFunction(true)
env.setCombat(true)
env.events['SimpleGroupDPSDamageState:combat'](nil,true)
env.tick()
assert(not photo.getFunction(), 'Actual combat ends photo mode')
print('PASS: 12-player photo preview, roles, values, filtering and isolation from saved/sent combat data')

