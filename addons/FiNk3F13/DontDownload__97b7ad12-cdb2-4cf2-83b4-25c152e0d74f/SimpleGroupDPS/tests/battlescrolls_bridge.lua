local clock, grouped = 0, true
local identities = { group1 = "@Alice", group2 = "@Bob", group3 = "@Me" }
function GetGameTimeMilliseconds() return clock end
function DoesUnitExist(tag) return identities[tag] ~= nil end
function AreUnitsEqual(tag) return tag == "player" or tag == "group3" end
function GetUnitDisplayName(tag) return identities[tag] end
function IsUnitGrouped() return grouped end

local protocols, handlers = {}, 0
local sent = {}
LFG_ROLE_DPS, LFG_ROLE_TANK, LFG_ROLE_HEAL = 1, 2, 4
local roles = {group1 = LFG_ROLE_DPS, group2 = LFG_ROLE_TANK}
function GetGroupMemberSelectedRole(tag) return roles[tag] end
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
                    error("Receive-only bridge must never call protocol Send")
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
roles.group1 = LFG_ROLE_HEAL
protocols[431].receive("group1", {encodedRawHPS = 400, encodedEffectiveHPS = 200})
assert(#bridge:GetRows() == 2, "Healer must remain visible when receiving HPS")
local healer = bridge:GetRows()[2]
assert(healer.messageType == "healing" and healer.rawHPS == 400 and healer.effectiveHPS == 200 and healer.dps == math.huge,
    "HPS updates retain the independent DPS sample")
assert(healer.role == LFG_ROLE_HEAL and bridge:GetRows()[1].role == LFG_ROLE_TANK, "Role must not filter either participant")
protocols[431].receive("group1", {encodedRawHPS = -1, encodedEffectiveHPS = 200})
assert(#bridge:GetRows() == 2 and bridge:GetRows()[2].rawHPS == 400, "Invalid healing packet cannot erase valid cached values")
identities.group2 = "@Replacement"
assert(#bridge:GetRows() == 1 and bridge:GetRows()[1].messageType == "healing", "Group slot reuse removes only the former member")
receive("group1", { encodedAllDPS = 500 })
clock = 15001
assert(#bridge:GetRows() == 1 and bridge:GetRows()[1].stale,
    "missing broadcasts retain the last known group row and mark it stale")
receive("group1", { encodedAllDPS = 500 })
assert(bridge:GetRows()[1].displayType == "healing" and bridge:GetRows()[1].stale,
    "Fresh damage cannot refresh an old healer HPS sample or change their selected role")
protocols[431].receive("group1", {encodedRawHPS = 400, encodedEffectiveHPS = 200})
assert(not bridge:GetRows()[1].stale, "A fresh HPS sample refreshes the healer row")
identities.group1 = "@NewHealer"
receive("group1", {encodedAllDPS = 256})
assert(bridge:GetRows()[1].rawHPS == nil and bridge:GetRows()[1].stale,
    "An immediate packet from a replacement identity cannot inherit the previous player's HPS")
grouped = false
assert(#bridge:GetRows() == 0, "leaving group clears data")
grouped = true
receive("group1", { encodedAllDPS = -1 })
receive("group1", { encodedAllDPS = 2048 })
receive("group1", { encodedAllDPS = 1.5 })
assert(#bridge:GetRows() == 0, "invalid encoded data rejected")

assert(#sent == 0, "receiving alone never broadcasts")
assert(bridge.SendDPS == nil and bridge.SendHPS == nil and bridge.SendMetrics == nil,
    "Receiver bridge exposes no metric sending methods")
roles.group1 = LFG_ROLE_DPS
receive("group1", {encodedAllDPS=1000, encodedBossDPS=511})
assert(bridge:GetRows()[1].dps > 1000 and bridge:GetRows()[1].bossDPS == 511)
protocols[431].receive("group1", {encodedRawHPS=1000,encodedEffectiveHPS=511})
assert(bridge:GetRows()[1].rawHPS > 1000 and bridge:GetRows()[1].effectiveHPS == 511)
assert(#sent == 0, "Wire reception never submits outgoing packets")
local registered
BattleScrolls={dpsShare={RegisterCallback=function(_,_,callback) registered=callback end}}
dofile("BattleScrollsBridge.lua")
bridge=SimpleGroupDPS_BattleScrolls
assert(bridge:Connect() and handlers == 1, "Local BattleScrolls is used for reception without protocol conflict")
registered("group1",{messageType="damage",allTargetsDPS=12345,bossDPS=10000})
assert(bridge:GetRows()[1].dps==12345 and bridge:GetRows()[1].bossDPS==10000)
registered("player",{messageType="damage",allTargetsDPS=999999})
assert(#bridge:GetRows()==1 and bridge:GetRows()[1].dps==12345,
    "Local BattleScrolls player values are never substituted into the own meter")
assert(bridge.SendDPS==nil and bridge.SendHPS==nil and #sent==0)
bridge:Clear();assert(#bridge:GetRows()==0)
BattleScrolls,LibGroupBroadcast=nil,nil
dofile("BattleScrollsBridge.lua")
assert(not SimpleGroupDPS_BattleScrolls:Connect() and not SimpleGroupDPS_BattleScrolls:GetStatus().connected)
print("PASS: receive-only wire codec, independent DPS/HPS samples, identities, local callbacks and no outgoing methods")
