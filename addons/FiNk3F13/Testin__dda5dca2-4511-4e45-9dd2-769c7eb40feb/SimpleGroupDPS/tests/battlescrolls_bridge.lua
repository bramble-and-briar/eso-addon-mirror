local clock, grouped = 0, true
local identities = { group1 = "@Alice", group2 = "@Bob", group3 = "@Me" }
function GetGameTimeMilliseconds() return clock end
function DoesUnitExist(tag) return identities[tag] ~= nil end
function AreUnitsEqual(tag) return tag == "player" or tag == "group3" end
function GetUnitDisplayName(tag) return identities[tag] end
function IsUnitGrouped() return grouped end

local protocols, handlers = {}, 0
local sent = {}
local sendEnabled, sendSucceeds = true, true
LibGroupBroadcast = {
    CreateNumericField = function(name, options) return { name = name, bits = options.numBits } end,
    CreateOptionalField = function(field) field.optional = true; return field end,
    RegisterHandler = function()
        handlers = handlers + 1
        return {
            SetDisplayName = function() end,
            SetDescription = function() end,
            DeclareProtocol = function(_, id)
                assert(not protocols[id], "duplicate protocol")
                local p = { fields = {} }
                function p:AddField(field) self.fields[#self.fields + 1] = field end
                function p:OnData(callback) self.receive = callback end
                function p:Finalize() return true end
                function p:IsEnabled() return sendEnabled end
                function p:Send(data)
                    if not sendSucceeds then return false end
                    sent[#sent + 1] = { id = id, data = data }
                    return true
                end
                protocols[id] = p
                return p
            end,
        }
    end,
}

dofile("BattleScrollsBridge.lua")
local bridge = SimpleGroupDPS_BattleScrolls
assert(bridge:Connect(), "direct LGB receiver connects without Battle Scrolls")
assert(bridge:Connect() and handlers == 1, "reconnection is idempotent")
assert(protocols[430].fields[1].bits == 11)
assert(protocols[430].fields[2].bits == 12 and protocols[430].fields[2].optional)
assert(protocols[431].fields[1].bits == 12 and protocols[431].fields[2].bits == 12)
local receive = protocols[430].receive
local changes = 0
bridge.onChanged = function() changes = changes + 1 end
receive("group1", { encodedAllDPS = 255 })
assert(changes == 1, "received DPS notifies the display immediately")
assert(bridge:GetStatus().receivedCount == 1 and bridge:GetStatus().lastReceivedAt == clock,
    "diagnostics record actual accepted group packets")
receive("group2", { encodedAllDPS = 2046 })
receive("group3", { encodedAllDPS = 2046 })
receive("player", { encodedAllDPS = 2046 })
local rows = bridge:GetRows()
assert(#rows == 2 and rows[1].name == "@Bob" and rows[1].dps == 1048576)
assert(rows[2].dps == 255, "literal DPS decoded")
receive("group1", { encodedAllDPS = 256 })
assert(bridge:GetRows()[2].dps == 256, "logarithmic boundary decoded")
receive("group1", { encodedAllDPS = 2047 })
assert(bridge:GetRows()[1].dps == math.huge, "overflow sentinel retained")
protocols[431].receive("group1", {})
assert(#bridge:GetRows() == 1, "HPS replaces old DPS without being shown as DPS")
identities.group2 = "@Replacement"
assert(#bridge:GetRows() == 0, "group slot reuse removes former member")
receive("group1", { encodedAllDPS = 500 })
clock = 15001
assert(#bridge:GetRows() == 1 and bridge:GetRows()[1].stale,
    "missing broadcasts retain the last known group row and mark it stale")
receive("group1", { encodedAllDPS = 500 })
grouped = false
assert(#bridge:GetRows() == 0, "leaving group clears data")
grouped = true
receive("group1", { encodedAllDPS = -1 })
receive("group1", { encodedAllDPS = 2048 })
receive("group1", { encodedAllDPS = 1.5 })
assert(#bridge:GetRows() == 0, "invalid encoded data rejected")

assert(#sent == 0, "receiving alone never broadcasts")
assert(bridge:SendDPS(255), "first outgoing DPS queued")
assert(sent[1].id == 430 and sent[1].data.encodedAllDPS == 255)
assert(sent[1].data.encodedBossDPS == nil, "unknown boss DPS omitted")
assert(bridge:GetStatus().queuedCount == 1, "queued counter counts successful submissions")
assert(bridge:GetStatus().connected and bridge:GetStatus().enabled
    and bridge:GetStatus().lastSendAt == clock and bridge:GetStatus().lastSendResult == "queued",
    "status reports queue acceptance, not remote delivery")
assert(not bridge:SendDPS(500), "duplicate send in the same tick is throttled")
clock = clock + 299
assert(not bridge:SendDPS(500), "send interval matches Battle Scrolls' 300ms tick")
clock = clock + 1
assert(bridge:SendDPS(256) and sent[2].data.encodedAllDPS == 256)
assert(bridge:SendDPS(1048576, true) and sent[3].data.encodedAllDPS == 2046)
assert(bridge:SendDPS(1048577, true) and sent[4].data.encodedAllDPS == 2047)
assert(bridge:SendDPS(0, true) and sent[5].data.encodedAllDPS == 0)
for _, value in ipairs({ 1000, 12345, 100000, 500000 }) do
    assert(bridge:SendDPS(value, true))
    receive("group1", sent[#sent].data)
    assert(math.abs(bridge:GetRows()[1].dps / value - 1) < 0.003, "wire roundtrip within compression precision")
end
assert(bridge:SendDPS(100000, true, 60000), "boss DPS transmitted alongside overall DPS")
receive("group1", sent[#sent].data)
rows = bridge:GetRows()
assert(math.abs(rows[1].bossDPS / 60000 - 1) < 0.002, "12-bit boss DPS roundtrip")
assert(math.abs(rows[1].addsDPS / 40000 - 1) < 0.01, "adds DPS derived from the same time basis")
assert(bridge:SendDPS(511, true, 511) and sent[#sent].data.encodedBossDPS == 511)
assert(bridge:SendDPS(512, true, 512) and sent[#sent].data.encodedBossDPS == 512)
assert(bridge:SendDPS(1048576, true, 1048576) and sent[#sent].data.encodedBossDPS == 4094)
assert(bridge:SendDPS(1048577, true, 1048577) and sent[#sent].data.encodedBossDPS == 4095)
receive("group1", sent[#sent].data)
assert(bridge:GetRows()[1].addsDPS == nil, "overflow cannot produce an inf-minus-inf adds value")
assert(bridge:SendDPS(1000, true, 0) and sent[#sent].data.encodedBossDPS == 0)
receive("group1", sent[#sent].data)
assert(bridge:GetRows()[1].bossDPS == 0 and bridge:GetRows()[1].addsDPS > 990, "zero boss DPS is valid")
receive("group1", { encodedAllDPS = 1000, encodedBossDPS = 5000 })
assert(bridge:GetRows()[1].bossDPS == nil and bridge:GetRows()[1].addsDPS == nil, "invalid boss encoding stays unknown")
grouped = false
assert(not bridge:SendDPS(500, true), "no solo broadcasts")
grouped = true
sendEnabled = false
assert(not bridge:SendDPS(500, true), "LibGroupBroadcast sharing preference respected")
assert(not bridge:GetStatus().enabled, "status exposes disabled library protocol")
sendEnabled = true
assert(not bridge:SendDPS(-1, true) and not bridge:SendDPS(0 / 0, true)
    and not bridge:SendDPS(math.huge, true), "invalid DPS never transmitted")
clock = clock + 1000
sendSucceeds = false
assert(not bridge:SendDPS(500), "queue failure reported")
assert(bridge:GetStatus().lastSendResult == "failed", "rejected queue submission is visible in status")
sendSucceeds = true
assert(bridge:SendDPS(500), "queue failure does not throttle retry")

-- When Battle Scrolls is installed, use its callback instead of claiming IDs.
local registered
BattleScrolls = { dpsShare = { RegisterCallback = function(_, name, callback)
    assert(name == "SimpleGroupDPS")
    registered = callback
end } }
assert(not bridge:SendDPS(500, true), "local Battle Scrolls prevents duplicate senders")
dofile("BattleScrollsBridge.lua")
bridge = SimpleGroupDPS_BattleScrolls
assert(bridge:Connect() and handlers == 1, "local Battle Scrolls avoids protocol conflict")
registered("group1", { messageType = "damage", allTargetsDPS = 12345, bossDPS = 10000 })
assert(bridge:GetRows()[1].dps == 12345, "local callback forwards exact DPS")
assert(bridge:GetRows()[1].bossDPS == 10000 and bridge:GetRows()[1].addsDPS == 2345, "local callback preserves boss split")
bridge:Clear()
assert(#bridge:GetRows() == 0)
BattleScrolls = nil
LibGroupBroadcast = nil
dofile("BattleScrollsBridge.lua")
assert(not SimpleGroupDPS_BattleScrolls:Connect(), "missing optional dependencies are harmless")
assert(not SimpleGroupDPS_BattleScrolls:SendDPS(100), "missing dependency cannot send")
assert(not SimpleGroupDPS_BattleScrolls:GetStatus().connected, "missing dependency status stays disconnected")
print("PASS: Battle Scrolls send/receive, wire codec, throttling, preferences, callbacks and group changes")
