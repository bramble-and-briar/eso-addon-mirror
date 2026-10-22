-- Battle Scrolls DPS sharing; no local Battle Scrolls install needed.
-- Wire format: https://github.com/vladislavsheludchenkov/BattleScrolls/blob/main/BattleScrolls/network/dpsshare.lua
local bridge = {}
SimpleGroupDPS_BattleScrolls = bridge
local members = {}
local registeredShare
local receiverReady = false
local receiverAttempted = false
local damageProtocol
local lastSendAt
local lastSendResult
local connectionError
local receivedCount, queuedCount = 0, 0
local lastReceivedAt
local STALE_MS = 15000
local SEND_INTERVAL_MS = 300

local function decodeDPS(encoded, bits, literalMax)
    local maxValue = 2 ^ bits - 1
    if type(encoded) ~= "number" or encoded < 0 or encoded > maxValue
        or encoded ~= math.floor(encoded) then return nil end
    if encoded == maxValue then return math.huge end
    if encoded <= literalMax then return encoded end
    local base = literalMax + 1
    return math.floor(base * (1048576 / base) ^ ((encoded - base) / (maxValue - base - 1)) + 0.5)
end

local function encodeDPS(value, bits, literalMax)
    if value > 1048576 then return 2 ^ bits - 1 end
    if value <= literalMax then return math.floor(value) end
    local base = literalMax + 1
    return base + math.floor((2 ^ bits - base - 2) * math.log(value / base) / math.log(1048576 / base) + 0.5)
end

local function onData(unitTag, data)
    if type(unitTag) ~= "string" or not unitTag:match("^group%d+$") then return end
    if not DoesUnitExist(unitTag) or AreUnitsEqual(unitTag, "player") then return end
    if type(data) ~= "table" then return end
    if data.messageType ~= "damage" then
        local hadMember = members[unitTag] ~= nil
        members[unitTag] = nil
        if hadMember and bridge.onChanged then bridge.onChanged() end
        return
    end
    local dps = tonumber(data.allTargetsDPS)
    if not dps or dps ~= dps or dps < 0 then return end
    local identity = GetUnitDisplayName(unitTag)
    if not identity or identity == "" then return end
    local bossDPS = tonumber(data.bossDPS)
    if bossDPS and (bossDPS ~= bossDPS or bossDPS < 0) then bossDPS = nil end
    members[unitTag] = {
        identity = identity,
        name = identity,
        dps = dps,
        bossDPS = bossDPS,
        addsDPS = bossDPS and bossDPS < math.huge and dps < math.huge and math.max(0, dps - bossDPS) or nil,
        receivedAt = GetGameTimeMilliseconds(),
    }
    receivedCount = receivedCount + 1
    lastReceivedAt = GetGameTimeMilliseconds()
    if bridge.onChanged then bridge.onChanged() end
end

function bridge:Connect()
    local share = BattleScrolls and BattleScrolls.dpsShare
    if not share or type(share.RegisterCallback) ~= "function" then
        if receiverReady then return true end
        local lgb = LibGroupBroadcast
        if not lgb then return false end
        if receiverAttempted then return false end
        receiverAttempted = true
        local handler = lgb:RegisterHandler("SimpleGroupDPS_BattleScrolls")
        handler:SetDisplayName("SimpleGroupDPS: Battle Scrolls DPS")
        handler:SetDescription("Teilt eigene DPS und empfaengt Gruppen-DPS im Battle-Scrolls-Format.")
        -- DeclareProtocol rejects occupied IDs. Leave any existing owner intact.
        local ok, damage = pcall(handler.DeclareProtocol, handler, 430, "SimpleGroupDPS_BattleScrollsDamage")
        if not ok or not damage then
            connectionError = "DPS-Protokoll 430 konnte nicht registriert werden (moeglicherweise bereits belegt)."
            return false
        end
        damage:AddField(lgb.CreateNumericField("encodedAllDPS", { minValue = 0, numBits = 11 }))
        damage:AddField(lgb.CreateOptionalField(lgb.CreateNumericField("encodedBossDPS", { minValue = 0, numBits = 12 })))
        damage:OnData(function(unitTag, data)
            onData(unitTag, { messageType = "damage", allTargetsDPS = decodeDPS(data.encodedAllDPS, 11, 255),
                bossDPS = decodeDPS(data.encodedBossDPS, 12, 511) })
        end)
        if not damage:Finalize({ isRelevantInCombat = true, replaceQueuedMessages = true }) then
            connectionError = "DPS-Protokoll 430 konnte nicht aktiviert werden."
            return false
        end
        damageProtocol = damage
        -- A healing update replaces the sender's previous damage metric.
        local healingOK, healing = pcall(handler.DeclareProtocol, handler, 431, "SimpleGroupDPS_BattleScrollsHealing")
        if healingOK and healing then
            healing:AddField(lgb.CreateNumericField("encodedRawHPS", { minValue = 0, numBits = 12 }))
            healing:AddField(lgb.CreateNumericField("encodedEffectiveHPS", { minValue = 0, numBits = 12 }))
            healing:OnData(function(unitTag) onData(unitTag, { messageType = "healing" }) end)
            healing:Finalize({ isRelevantInCombat = true })
        end
        receiverReady = true
        return true
    end
    if share == registeredShare then return true end
    if registeredShare and type(registeredShare.UnregisterCallback) == "function" then
        registeredShare:UnregisterCallback("SimpleGroupDPS")
    end
    members = {}
    share:RegisterCallback("SimpleGroupDPS", onData)
    registeredShare = share
    return true
end

function bridge:Clear()
    members = {}
    lastSendAt = nil
end

function bridge:ResetSendClock()
    lastSendAt = nil
end

function bridge:Expire(ageMS)
    local now = GetGameTimeMilliseconds()
    for tag, member in pairs(members) do
        if now - member.receivedAt >= ageMS then members[tag] = nil end
    end
end

function bridge:SendDPS(dps, force, bossDPS)
    -- A local Battle Scrolls installation already owns and sends this metric.
    if BattleScrolls and BattleScrolls.dpsShare then return false end
    if not damageProtocol then self:Connect() end
    if not damageProtocol or not IsUnitGrouped("player") or not damageProtocol:IsEnabled() then return false end
    dps = tonumber(dps)
    if not dps or dps ~= dps or dps < 0 or dps == math.huge then return false end
    local now = GetGameTimeMilliseconds()
    if not force and lastSendAt and now - lastSendAt < SEND_INTERVAL_MS then return false end
    local encodedBoss
    bossDPS = tonumber(bossDPS)
    if bossDPS and bossDPS >= 0 and bossDPS < math.huge then
        encodedBoss = encodeDPS(math.min(dps, bossDPS), 12, 511)
    end
    local queued = damageProtocol:Send({ encodedAllDPS = encodeDPS(dps, 11, 255), encodedBossDPS = encodedBoss })
    lastSendResult = queued and "queued" or "failed"
    if queued then lastSendAt = now; queuedCount = queuedCount + 1 end
    return queued
end

-- Queue acceptance is observable here; delivery to another client is not.
function bridge:GetStatus()
    local localShare = BattleScrolls and BattleScrolls.dpsShare
    return {
        grouped = IsUnitGrouped("player"),
        connected = (localShare and registeredShare == localShare) or damageProtocol ~= nil,
        localBattleScrolls = localShare ~= nil,
        enabled = damageProtocol and damageProtocol:IsEnabled() or false,
        lastSendAt = lastSendAt,
        lastSendResult = lastSendResult,
        error = connectionError,
        receivedCount = receivedCount, queuedCount = queuedCount, lastReceivedAt = lastReceivedAt,
    }
end

function bridge:GetRows()
    local rows = {}
    local now = GetGameTimeMilliseconds()
    for tag, member in pairs(members) do
        if not IsUnitGrouped("player") or not DoesUnitExist(tag)
            or AreUnitsEqual(tag, "player") or GetUnitDisplayName(tag) ~= member.identity then
            members[tag] = nil
        else
            member.stale = now - member.receivedAt > STALE_MS
            rows[#rows + 1] = member
        end
    end
    table.sort(rows, function(a, b)
        if a.dps == b.dps then return a.name < b.name end
        return a.dps > b.dps
    end)
    return rows
end
