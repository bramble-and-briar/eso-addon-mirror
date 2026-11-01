-- Reproduce two tanks plus two healers, including missing and interrupted metrics.
local env = dofile("tests/standalone.lua")
LFG_ROLE_DPS, LFG_ROLE_TANK, LFG_ROLE_HEAL = 1, 2, 4
local now = 1000
local names = {group1 = "@TankOne", group2 = "@TankTwo", group3 = "@HealerOne", group4 = "@HealerTwo"}
local roles = {group1 = LFG_ROLE_TANK, group2 = LFG_ROLE_TANK, group3 = LFG_ROLE_HEAL, group4 = LFG_ROLE_HEAL}
function GetGameTimeMilliseconds() return now end
function DoesUnitExist(tag) return names[tag] ~= nil end
function GetUnitDisplayName(tag) return names[tag] or "@Me" end
function GetGroupMemberSelectedRole(tag) return roles[tag] end
function GetSelectedLFGRole() return LFG_ROLE_DPS end
function AreUnitsEqual(a, b) return a == b end
function IsUnitGrouped() return true end
local bridge = SimpleGroupDPS_BattleScrolls
bridge:Clear()
local function member(name)
    for _, data in ipairs(bridge:GetRows()) do if data.name == name then return data end end
    error("Missing cached member " .. name)
end
local function row(name)
    for key, value in pairs(env.window.swtGroupDPSLabels) do
        if type(key) == "number" and value.text == name and not value.hidden then return value end
    end
    error("Missing visible row " .. name)
end
env.receive("group1", {messageType = "damage", allTargetsDPS = 5200})
env.receive("group2", {messageType = "damage", allTargetsDPS = 3000})
env.receive("group3", {messageType = "healing", rawHPS = 27200, effectiveHPS = 4900})
env.receive("group4", {messageType = "healing", rawHPS = 18000, effectiveHPS = 6000})
assert(#bridge:GetRows() == 4, "Both tanks and both healers retain distinct cached records")
assert(row("TankOne").swtDPSValue.text == "5,2 Tsd." and row("TankTwo").swtDPSValue.text == "3,0 Tsd.")
assert(row("HealerOne").swtDPSValue.text == "4,9 Tsd. (27,2 Tsd.)")
assert(row("HealerTwo").swtDPSValue.text == "6,0 Tsd. (18,0 Tsd.)",
    "The second healer's received HPS is displayed independently from the first")
assert(not member("@TankOne").stale and not member("@TankTwo").stale)

-- BattleScrolls may send only HPS when that exceeds DPS: refreshing HPS cannot invent fresh DPS.
now = 17001
env.receive("group1", {messageType = "healing", rawHPS = 9000, effectiveHPS = 2000})
env.receive("group2", {messageType = "damage", allTargetsDPS = 3200})
assert(member("@TankOne").stale and not member("@TankTwo").stale,
    "One tank's old DPS may fade while the second tank keeps receiving DPS updates")
assert(row("TankOne").swtDPSValue.text == "5,2 Tsd.", "Cached value is retained, not silently replaced by HPS")
now = 17301
env.receive("group1", {messageType = "damage", allTargetsDPS = 5400})
assert(not member("@TankOne").stale and row("TankOne").swtDPSValue.text == "5,4 Tsd.",
    "The next DPS packet refreshes the first tank independently")

-- SimpleGroupDPS 1.5.1 sends damage only: a healer row exists but has no HPS to display.
bridge:Clear()
env.receive("group3", {messageType = "healing", rawHPS = 27200, effectiveHPS = 4900})
env.receive("group4", {messageType = "damage", allTargetsDPS = 500})
assert(row("HealerOne").swtDPSValue.text == "4,9 Tsd. (27,2 Tsd.)"
    and row("HealerTwo").swtDPSValue.text == "", "Missing second-healer HPS is not a one-healer limit")
assert(member("@HealerTwo").rawHPS == nil and member("@HealerTwo").displayType == "healing")
env.receive("group4", {messageType = "healing", rawHPS = 18000, effectiveHPS = 6000})
assert(row("HealerTwo").swtDPSValue.text == "6,0 Tsd. (18,0 Tsd.)",
    "Receiving HPS makes the second healer's values appear immediately")
print("PASS: two tanks and two healers, independent freshness, interrupted DPS, and missing versus received HPS")
