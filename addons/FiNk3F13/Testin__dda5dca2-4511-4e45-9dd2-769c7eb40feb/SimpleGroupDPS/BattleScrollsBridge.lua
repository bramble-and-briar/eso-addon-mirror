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
    local healing = data.messageType == "healing"
    if not healing and data.messageType ~= "damage" then return end
    local dps = not healing and tonumber(data.allTargetsDPS) or nil
    local rawHPS = healing and tonumber(data.rawHPS) or nil
    local effectiveHPS = healing and tonumber(data.effectiveHPS) or nil
    if healing then
        if not rawHPS or rawHPS ~= rawHPS or rawHPS < 0
            or not effectiveHPS or effectiveHPS ~= effectiveHPS or effectiveHPS < 0 then return end
    elseif not dps or dps ~= dps or dps < 0 then return end
    local identity = GetUnitDisplayName(unitTag)
    if not identity or identity == "" then return end
    local bossDPS = not healing and tonumber(data.bossDPS) or nil
    if bossDPS and (bossDPS ~= bossDPS or bossDPS < 0) then bossDPS = nil end
    -- DPS and HPS are independent samples, not changes to the sender's role.
    local member = members[unitTag]
    if not member or member.identity ~= identity then member = {identity = identity, name = identity} end
    local now = GetGameTimeMilliseconds()
    member.messageType = data.messageType
    member.role = GetGroupMemberSelectedRole and GetGroupMemberSelectedRole(unitTag) or data.role
    member.receivedAt = now
    if healing then
        member.rawHPS, member.effectiveHPS, member.healingAt = rawHPS, effectiveHPS, now
    else
        member.dps, member.bossDPS, member.damageAt = dps, bossDPS, now
        member.addsDPS = bossDPS and bossDPS < math.huge and dps < math.huge and math.max(0, dps - bossDPS) or nil
    end
    members[unitTag] = member
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
        -- Receive healing independently from the sender's damage sample.
        local healingOK, healing = pcall(handler.DeclareProtocol, handler, 431, "SimpleGroupDPS_BattleScrollsHealing")
        if healingOK and healing then
            healing:AddField(lgb.CreateNumericField("encodedRawHPS", { minValue = 0, numBits = 12 }))
            healing:AddField(lgb.CreateNumericField("encodedEffectiveHPS", { minValue = 0, numBits = 12 }))
            healing:OnData(function(unitTag, data)
                onData(unitTag, {messageType = "healing", rawHPS = decodeDPS(data.encodedRawHPS, 12, 511),
                    effectiveHPS = decodeDPS(data.encodedEffectiveHPS, 12, 511)})
            end)
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
            if GetGroupMemberSelectedRole then member.role = GetGroupMemberSelectedRole(tag) end
            local healing = LFG_ROLE_HEAL ~= nil and member.role == LFG_ROLE_HEAL
            local damage = (LFG_ROLE_DPS ~= nil and member.role == LFG_ROLE_DPS)
                or (LFG_ROLE_TANK ~= nil and member.role == LFG_ROLE_TANK)
            member.displayType = (healing or (not damage and member.messageType == "healing")) and "healing" or "damage"
            local metricAt
            if member.displayType == "healing" then metricAt = member.healingAt else metricAt = member.damageAt end
            member.stale = not metricAt or now - metricAt > STALE_MS
            rows[#rows + 1] = member
        end
    end
    table.sort(rows, function(a, b)
        local aHealing, bHealing = a.displayType == "healing", b.displayType == "healing"
        if aHealing ~= bHealing then return not aHealing end
        local aValue, bValue = (aHealing and a.rawHPS or (not aHealing and a.dps)) or -1,
            (bHealing and b.rawHPS or (not bHealing and b.dps)) or -1
        if aValue == bValue then return a.name < b.name end
        return aValue > bValue
    end)
    return rows
end
