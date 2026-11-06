local env = dofile("tests/standalone.lua")
LFG_ROLE_DPS, LFG_ROLE_TANK, LFG_ROLE_HEAL = 1, 2, 4
local ownRole = LFG_ROLE_DPS
local roles = {group1 = LFG_ROLE_TANK, group2 = LFG_ROLE_TANK, group3 = LFG_ROLE_HEAL, group4 = LFG_ROLE_HEAL}
local names = {group1 = "@TankOne", group2 = "@TankTwo", group3 = "@HealerOne", group4 = "@HealerTwo"}
function DoesUnitExist(tag) return names[tag] ~= nil end
function GetUnitDisplayName(tag) return names[tag] or "@Me" end
function GetGroupMemberSelectedRole(tag) return roles[tag] end
function GetSelectedLFGRole() return ownRole end
function AreUnitsEqual(a, b) return a == b end
function IsUnitGrouped() return true end
local bridge = SimpleGroupDPS_BattleScrolls
bridge:Clear()
local function visible(name)
    for key, row in pairs(env.window.swtGroupDPSLabels) do
        if type(key) == "number" and row.text == name and not row.hidden then return true end
    end
    return false
end
env.receive("group1", {messageType = "damage", allTargetsDPS = 1000})
env.receive("group2", {messageType = "damage", allTargetsDPS = 2000})
env.receive("group3", {messageType = "healing", rawHPS = 3000, effectiveHPS = 1000})
env.receive("group4", {messageType = "healing", rawHPS = 4000, effectiveHPS = 2000})
assert(visible("TankOne") and visible("TankTwo") and visible("HealerOne") and visible("HealerTwo"))
env.menu["Tanks anzeigen"].setFunction(false)
assert(not visible("TankOne") and not visible("TankTwo") and visible("HealerOne") and visible("Me"))
assert(env.saved.showTanks == false and #bridge:GetRows() == 4, "Hiding tanks saves preference without deleting received data")
env.menu["Heiler anzeigen"].setFunction(false)
assert(not visible("HealerOne") and not visible("HealerTwo") and env.window.swtGroupDPSLabels.healingHeader.hidden)
assert(visible("Me") and env.saved.showHealers == false)
env.receive("group3", {messageType = "healing", rawHPS = 5000, effectiveHPS = 3000})
assert(not visible("HealerOne") and #bridge:GetRows() == 4, "Hidden roles keep receiving without reappearing")
env.menu["Heiler anzeigen"].setFunction(true)
assert(visible("HealerOne") and visible("HealerTwo") and not visible("TankOne"), "Role switches are independent")
env.menu["Tanks anzeigen"].setFunction(true)
assert(visible("TankOne") and visible("TankTwo"))

ownRole = LFG_ROLE_HEAL
env.menu["Heiler anzeigen"].setFunction(false)
assert(not visible("Me"), "Own healer follows the same visibility setting")
env.menu["Tanks anzeigen"].setFunction(false)
assert(env.window.hidden, "All hidden roles leave no empty HUD behind")
env.menu["Move UI"].clickHandler()
assert(not env.window.hidden and visible("Me"), "Move UI remains usable with every role hidden")
SLASH_COMMANDS["/sgdmove"]()
assert(env.window.hidden, "Leaving Move UI restores role filters")
local sends = 0
bridge.SendHPS = function() sends = sends + 1; return true end
env.setClock(800000)
env.setCombat(true)
env.events["SimpleGroupDPSDamageState:combat"](nil, true)
env.tick()
assert(sends == 1 and SimpleGroupDPS_DamageMeter:IsActive() and env.window.hidden,
    "Hidden own healer keeps measuring and sending HPS")
env.menu["Layout zurücksetzen"].clickHandler()
assert(env.saved.showTanks == false and env.saved.showHealers == false, "Layout reset preserves role preferences")
print("PASS: independent tank/healer visibility, own role, live reception/send, empty HUD and Move UI")
