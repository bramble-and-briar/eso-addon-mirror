local env = dofile("tests/standalone.lua")
LFG_ROLE_DPS, LFG_ROLE_TANK, LFG_ROLE_HEAL = 1, 2, 4
function GetSelectedLFGRole() return LFG_ROLE_TANK end
function GetGroupMemberSelectedRole() return LFG_ROLE_HEAL end
env.receive("group1", {messageType = "healing", rawHPS = 20000, effectiveHPS = 8000})
local rows = env.window.swtGroupDPSLabels
assert(rows[1].swtIcon.texture:find("tank", 1, true), "Own tank role must have its role icon")
assert(rows[2].swtIcon.texture:find("healer", 1, true), "Received healer role must have its role icon")
assert(rows[2].swtDPSValue.text == "8,0 Tsd. (20,0 Tsd.)" and rows.summary.swtDPSValue.text == "0")
assert(rows.healingHeader.hidden == false and rows.healingHeader.top > rows.summary.top,
    "Healing header must follow the damage sum")
assert(rows[2].top > rows.healingHeader.top, "Healing rows must not overlap the header or damage sum")
function GetGroupMemberSelectedRole() return LFG_ROLE_TANK end
env.receive("group1", {messageType = "damage", allTargetsDPS = 1000})
assert(rows[1].text == "Replacement" and rows[1].swtIcon.texture:find("tank", 1, true))
assert(rows[1].swtDPSValue.text == "1,0 Tsd." and rows.summary.swtDPSValue.text == "1,0 Tsd.")
assert(rows.healingHeader.hidden, "Switching to a tank damage packet must remove the old healing section")
function GetGroupMemberSelectedRole() return LFG_ROLE_HEAL end
env.tick()
assert(rows[1].swtIcon.texture:find("healer", 1, true) and rows[1].swtDPSValue.text == "1,0 Tsd.",
    "Healer DPS must remain included; changing role must not discard the row")
env.receive("group1", {messageType = "healing", rawHPS = 0, effectiveHPS = 0})
assert(not rows[2].hidden and rows[2].swtDPSValue.text == "0 (0)", "A valid zero-healing packet must not remove its player")
print("PASS: tank and healer roles, DPS/HPS separation, zero values, role changes and non-overlapping section layout")
