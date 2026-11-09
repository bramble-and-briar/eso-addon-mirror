local env = dofile('tests/standalone.lua')
LFG_ROLE_DPS, LFG_ROLE_TANK, LFG_ROLE_HEAL = 1, 2, 4
local names = {group1='@TankOne', group2='@TankTwo', group3='@HealerOne', group4='@HealerTwo'}
local roles = {group1=2, group2=2, group3=4, group4=4}
function DoesUnitExist(tag) return names[tag] ~= nil end
function GetUnitDisplayName(tag) return names[tag] or '@Me' end
function GetGroupMemberSelectedRole(tag) return roles[tag] end
function GetSelectedLFGRole() return 1 end
function AreUnitsEqual(a,b) return a == b end
function IsUnitGrouped() return true end
local bridge = SimpleGroupDPS_BattleScrolls
bridge:Clear()
local function row(name)
    for key,value in pairs(env.window.swtGroupDPSLabels) do
        if type(key)=='number' and value.text==name and not value.hidden then return value end
    end
end
env.receive('group1',{messageType='damage',allTargetsDPS=3000})
env.receive('group1',{messageType='healing',rawHPS=2400,effectiveHPS=1100})
env.receive('group2',{messageType='healing',rawHPS=10700,effectiveHPS=1100})
env.receive('group3',{messageType='healing',rawHPS=27200,effectiveHPS=4900})
env.receive('group4',{messageType='healing',rawHPS=18000,effectiveHPS=6000})
assert(row('TankOne').swtDPSValue.text=='1,1 Tsd. (2,4 Tsd.)', 'Replace stale 3k DPS with received tank healing')
assert(row('TankTwo').swtDPSValue.text=='1,1 Tsd. (10,7 Tsd.)', 'Healing-only tank must not remain zero')
assert(row('TankOne').swtIcon.texture:find('tank',1,true) and row('TankTwo').swtIcon.texture:find('tank',1,true))
assert(row('HealerOne').swtDPSValue.text=='4,9 Tsd. (27,2 Tsd.)')
assert(row('HealerTwo').swtDPSValue.text=='6,0 Tsd. (18,0 Tsd.)')
local summary = env.window.swtGroupDPSLabels.summary.swtDPSValue.text
env.receive('group3',{messageType='healing',rawHPS=40000,effectiveHPS=12300})
assert(row('HealerOne').swtDPSValue.text=='12,3 Tsd. (40,0 Tsd.)')
assert(env.window.swtGroupDPSLabels.summary.swtDPSValue.text==summary, 'Healing never changes damage sum')
env.menu['Heiler anzeigen'].setFunction(false)
assert(not row('HealerOne') and not row('HealerTwo') and row('TankOne') and row('TankTwo'), 'Healing tanks remain controlled by tank role filter')
env.menu['Heiler anzeigen'].setFunction(true)
env.menu['Tanks anzeigen'].setFunction(false)
assert(not row('TankOne') and not row('TankTwo') and row('HealerOne') and row('HealerTwo'))
env.menu['Tanks anzeigen'].setFunction(true)
env.receive('group1',{messageType='damage',allTargetsDPS=3200})
assert(row('TankOne').swtDPSValue.text=='3,2 Tsd.', 'Actual new DPS packet switches tank back to damage')
assert(type(bridge.SendDPS)=="function" and type(bridge.SendHPS)=="function" and type(bridge.SendMetrics)=="function")
print('PASS: screenshot tank 3k/zero regression, both received healers, live HPS, role filters and no healing in damage sum')
