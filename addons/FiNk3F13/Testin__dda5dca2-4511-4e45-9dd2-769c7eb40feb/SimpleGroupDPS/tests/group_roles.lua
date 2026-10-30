local env = dofile("tests/standalone.lua")
LFG_ROLE_DPS, LFG_ROLE_TANK, LFG_ROLE_HEAL = 1, 2, 4
local ownRole, peerRole = LFG_ROLE_TANK, LFG_ROLE_DPS
function GetSelectedLFGRole() return ownRole end
function GetGroupMemberSelectedRole() return peerRole end
local rows = env.window.swtGroupDPSLabels
local bridge = SimpleGroupDPS_BattleScrolls
local function peerRow()
    for key, row in pairs(rows) do
        if type(key) == "number" and row.text == "Replacement" and not row.hidden then return row end
    end
    error("missing peer row")
end

-- Screenshot sequence: a DD sends healing first, then damage, then healing again.
env.receive("group1", {messageType = "healing", rawHPS = 1800, effectiveHPS = 0})
assert(peerRow().swtDPSValue.text == "" and peerRow().swtIcon.texture:find("dps", 1, true),
    "A DD with only healing received remains damage with unknown DPS, never invented HPS-as-DPS")
assert(rows.healingHeader.hidden and peerRow().top < rows.summary.top)
env.receive("group1", {messageType = "damage", allTargetsDPS = 13200, bossDPS = 13200})
assert(peerRow().swtDPSValue.text == "13,2 Tsd." and rows.healingHeader.hidden)
env.receive("group1", {messageType = "healing", rawHPS = 2200, effectiveHPS = 100})
assert(peerRow().swtDPSValue.text == "13,2 Tsd." and rows.healingHeader.hidden,
    "A DD's self-healing packet cannot move their row or erase received damage")
assert(bridge:GetRows()[1].dps == 13200 and bridge:GetRows()[1].rawHPS == 2200)

-- A real role change applies without waiting for a new packet.
peerRole = LFG_ROLE_HEAL
env.tick()
assert(peerRow().swtDPSValue.text == "100 (2,2 Tsd.)" and peerRow().swtIcon.texture:find("healer", 1, true))
assert(not rows.healingHeader.hidden and peerRow().top > rows.healingHeader.top
    and rows.healingHeader.top > rows.summary.top, "Healer section stays below the damage sum")
env.receive("group1", {messageType = "damage", allTargetsDPS = 1000})
assert(peerRow().swtDPSValue.text == "100 (2,2 Tsd.)",
    "Healer dealing damage stays healing and keeps independently received HPS")
assert(rows.summary.swtDPSValue.text == "0", "Healer HPS must never enter the damage sum")
env.receive("group1", {messageType = "healing", rawHPS = 0, effectiveHPS = 0})
assert(peerRow().swtDPSValue.text == "0 (0)", "Measured zero HPS remains distinct from missing HPS")

peerRole = LFG_ROLE_TANK
env.tick()
assert(peerRow().swtDPSValue.text == "1,0 Tsd." and peerRow().swtIcon.texture:find("tank", 1, true))
assert(rows.healingHeader.hidden, "A real role change to tank uses cached DPS immediately")
assert(rows.summary.swtDPSValue.text == "1,0 Tsd.")

bridge:Clear()
peerRole = LFG_ROLE_HEAL
env.receive("group1", {messageType = "damage", allTargetsDPS = 1000})
assert(not rows.healingHeader.hidden and peerRow().swtDPSValue.text == "",
    "Damage-only healer appears in healing without substituting DPS for missing HPS")
assert(bridge:GetRows()[1].stale, "Damage packets cannot claim missing HPS is fresh")

ownRole = LFG_ROLE_HEAL
env.tick()
assert(rows[0].hidden and rows.summary.hidden and not rows.healingHeader.hidden,
    "Own and remote healer roles both belong to healing")
ownRole, peerRole = LFG_ROLE_DPS, LFG_ROLE_DPS
env.tick()
assert(rows.healingHeader.hidden, "Switching selected roles to DD removes healing section")
print("PASS: stable DD/healer sections, independent DPS/HPS, missing/zero HPS and actual role changes")
