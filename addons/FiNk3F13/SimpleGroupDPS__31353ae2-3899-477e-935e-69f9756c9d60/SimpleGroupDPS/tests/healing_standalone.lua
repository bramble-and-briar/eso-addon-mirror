ACTION_RESULT_HEAL = 5
local env = dofile("tests/standalone.lua")
local meter, bridge = SimpleGroupDPS_DamageMeter, SimpleGroupDPS_BattleScrolls
LFG_ROLE_DPS, LFG_ROLE_TANK, LFG_ROLE_HEAL = 1, 2, 4
local ownRole = LFG_ROLE_HEAL
function GetSelectedLFGRole() return ownRole end
function GetGroupMemberSelectedRole() return LFG_ROLE_HEAL end
env.saved.lingerSeconds = 60
bridge:Clear()
env.setClock(800000)
env.setCombat(true)
env.events["SimpleGroupDPSDamageState:combat"](nil, true)
env.setClock(801000)
env.events["SimpleGroupDPSDamage:damage"](nil, 1, false, nil, nil, nil, "Enemy", 0,
    "Me", COMBAT_UNIT_TYPE_PLAYER, 100, nil, nil, nil, 99, 10, 200, 0)
env.events["SimpleGroupDPSDamage:damage"](nil, 5, false, nil, nil, nil, "Me", COMBAT_UNIT_TYPE_PLAYER,
    "Friend", COMBAT_UNIT_TYPE_GROUP, 400, nil, nil, nil, 10, 20, 100, 600)
local sent = {}
-- Capture final uncompressed stats going into the real role-based routing.
bridge.SendHPS = function(_, raw, effective, force) sent[#sent+1] = {raw, effective, force}; return true end
env.tick()
local function ownRow()
    for key, row in pairs(env.window.swtGroupDPSLabels) do
        if type(key) == "number" and row.text == "Me" and not row.hidden then return row end
    end
    error("own row missing")
end
assert(ownRow().swtDPSValue.text == "400 (1,0 Tsd.)" and not env.window.swtGroupDPSLabels.healingHeader.hidden,
    "Own healer displays measured HPS immediately without a local BattleScrolls callback")
assert(sent[#sent][1] == 1000 and sent[#sent][2] == 400 and sent[#sent][3] == false,
    "Live UI and sender get the same snapshot")
env.receive("group1", {messageType = "healing", rawHPS = 2000, effectiveHPS = 600})
assert(ownRow().swtDPSValue.text == "400 (1,0 Tsd.)", "Receiving another healer never overwrites own HPS")
env.setCombat(false)
env.events["SimpleGroupDPSDamageState:combat"](nil, false)
env.updates.SimpleGroupDPSDamageReset()
assert(sent[#sent][3] == true and env.saved.lastSummary.rawHPS == 1000
    and env.saved.lastSummary.effectiveHPS == 400, "Final HPS is forced to queue and saved with the result")
env.setClock(803000)
env.tick()
assert(ownRow().swtDPSValue.text == "400 (1,0 Tsd.)", "Finished own healing remains frozen")
env.setClock(861000)
env.tick()
assert(meter:GetStats().rawHPS == nil and next(env.saved.lastSummary) == nil,
    "Retention expiry clears own healing result and saved data")
print("PASS: healer event -> own HUD and role-based send -> final queue/save -> retention reset")
