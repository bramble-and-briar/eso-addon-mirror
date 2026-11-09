local env = dofile("tests/standalone.lua")
local bridge, meter = SimpleGroupDPS_BattleScrolls, SimpleGroupDPS_DamageMeter
LFG_ROLE_DPS, LFG_ROLE_TANK, LFG_ROLE_HEAL = 1, 2, 4
local names = {group1 = "@Tank", group2 = "@Healer", group3 = "@Me"}
local roles = {group1 = LFG_ROLE_TANK, group2 = LFG_ROLE_HEAL, group3 = LFG_ROLE_DPS}
function IsUnitGrouped() return true end
function GetGroupSize() return 3 end
function ZO_Group_GetUnitTagForGroupIndex(index) return "group" .. index end
function DoesUnitExist(tag) return names[tag] ~= nil end
function IsUnitOnline() return true end
function GetUnitDisplayName(tag) return names[tag] or "@Me" end
function GetGroupMemberSelectedRole(tag) return roles[tag] end
function GetSelectedLFGRole() return LFG_ROLE_DPS end
function AreUnitsEqual(a, b) return a == b or (a == "group3" and b == "player") end
local function row(name)
    for key, control in pairs(env.window.swtGroupDPSLabels) do
        if type(key) == "number" and not control.hidden and control.text == name then return control end
    end
    return nil
end
bridge:Clear()
local received = bridge:GetStatus().receivedCount
env.setClock(800000)
env.setCombat(true)
env.events["SimpleGroupDPSDamageState:combat"](nil, true)
env.tick()
assert(row("Tank") == nil and row("Healer") == nil, "No rows for players who have not sent metrics")
assert(#bridge:GetRows() == 0 and #bridge:GetRows(true) == 0 and bridge:GetStatus().receivedCount == received,
    "Silent members are never shown or counted as received data")
env.receive("group1", {messageType = "damage", allTargetsDPS = 0})
env.receive("group2", {messageType = "healing", rawHPS = 0, effectiveHPS = 0})
assert(row("Tank").swtDPSValue.text == "0" and row("Healer").swtDPSValue.text == "0 (0)",
    "Valid zero samples remain distinguishable from missing data")
assert(bridge:GetStatus().receivedCount == received + 2)
env.setClock(816001)
env.tick()
assert(row("Tank").swtDPSValue.color[1] == 0.88 and row("Tank").swtDPSValue.color[2] == 0.97)
assert(row("Healer").swtDPSValue.color[1] == 0.88 and env.window.swtGroupDPSLabels.status == nil,
    "Older DPS/HPS stay white without an age footer")
env.receive("group2", {messageType = "healing", rawHPS = 1000, effectiveHPS = 400})
assert(row("Healer").swtDPSValue.color[1] == 0.88)
env.receive("group1", {messageType = "damage", allTargetsDPS = 2000})
assert(env.window.swtGroupDPSLabels.status == nil and row("Tank").swtDPSValue.color[1] == 0.88)
roles.group1 = LFG_ROLE_HEAL
env.tick()
assert(row("Tank").swtDPSValue.text == "2,0 Tsd.", "Role changes cannot replace a received damage packet with missing HPS")
local showPersonal = env.menu["Anteil-HUD anzeigen"]
assert(showPersonal.getFunction() and not env.personalWindow.hidden)
showPersonal.setFunction(false)
assert(env.saved.showPersonal == false and env.personalWindow.hidden and not env.window.hidden)
env.tick()
assert(meter:IsActive() and type(bridge.SendDPS)=="function", "Hidden personal HUD preserves measurement and automatic sharing")
env.menu["Anteil-HUD verschieben"].clickHandler()
assert(not env.personalWindow.hidden, "Move preview remains usable for a disabled personal HUD")
SLASH_COMMANDS["/sgdsharemove"]()
assert(env.personalWindow.hidden, "Leaving Move restores personal visibility setting")
showPersonal.setFunction(true)
assert(not env.personalWindow.hidden)
print("PASS: received members only, white metrics without footer, valid zero and personal HUD visibility")
