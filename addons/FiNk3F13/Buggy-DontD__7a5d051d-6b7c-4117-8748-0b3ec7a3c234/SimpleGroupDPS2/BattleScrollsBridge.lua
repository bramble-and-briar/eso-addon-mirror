-- Receive-only test build: no outgoing DPS/HPS implementation.
-- Wire format: https://github.com/vladislavsheludchenkov/BattleScrolls/blob/main/BattleScrolls/network/dpsshare.lua
local bridge = {}
SimpleGroupDPS2_BattleScrolls = bridge
local members = {}
local retained = {}
local lastGrouped
local registeredShare
local receiverReady = false
local receiverAttempted = false
local damageProtocol
local healingProtocol
local connectionError
local receivedCount = 0
local lastReceivedAt
local STALE_MS = 15000

local function decodeDPS(encoded, bits, literalMax)
    local maxValue = 2 ^ bits - 1
    if type(encoded) ~= "number" or encoded < 0 or encoded > maxValue
        or encoded ~= math.floor(encoded) then return nil end
    if encoded == maxValue then return math.huge end
    if encoded <= literalMax then return encoded end
    local base = literalMax + 1
    return math.floor(base * (1048576 / base) ^ ((encoded - base) / (maxValue - base - 1)) + 0.5)
end

local function onData(unitTag, data)
    if not IsUnitGrouped("player") then return end
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
    if GetUnitClassId then
        local classId = GetUnitClassId(unitTag)
        if type(classId) == "number" and classId > 0 then member.classId = classId end
    end
    member.receivedAt = now
    member.resultAt = nil
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
        local handler = lgb:RegisterHandler("SimpleGroupDPS2_BattleScrolls")
        handler:SetDisplayName("SimpleGroupDPS2: Battle Scrolls DPS")
        handler:SetDescription("Empfaengt nur Gruppenwerte. Kein DPS/HPS-Versand in dieser Testversion.")
        -- DeclareProtocol rejects occupied IDs. Leave any existing owner intact.
        local ok, damage = pcall(handler.DeclareProtocol, handler, 430, "SimpleGroupDPS2_BattleScrollsDamage")
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
        local healingOK, healing = pcall(handler.DeclareProtocol, handler, 431, "SimpleGroupDPS2_BattleScrollsHealing")
        if healingOK and healing then
            healing:AddField(lgb.CreateNumericField("encodedRawHPS", { minValue = 0, numBits = 12 }))
            healing:AddField(lgb.CreateNumericField("encodedEffectiveHPS", { minValue = 0, numBits = 12 }))
            healing:OnData(function(unitTag, data)
                onData(unitTag, {messageType = "healing", rawHPS = decodeDPS(data.encodedRawHPS, 12, 511),
                    effectiveHPS = decodeDPS(data.encodedEffectiveHPS, 12, 511)})
            end)
            if healing:Finalize({ isRelevantInCombat = true, replaceQueuedMessages = true }) then
                healingProtocol = healing
            end
        end
        if not healingProtocol then connectionError = "HPS-Protokoll 431 konnte nicht aktiviert werden." end
        receiverReady = true
        return true
    end
    if share == registeredShare then return true end
    if registeredShare and type(registeredShare.UnregisterCallback) == "function" then
        registeredShare:UnregisterCallback("SimpleGroupDPS2")
    end
    members = {}
    retained = {}
    share:RegisterCallback("SimpleGroupDPS2", onData)
    registeredShare = share
    return true
end

function bridge:Clear()
    members = {}
    retained = {}
end

function bridge:BeginEncounter()
    retained = {}
    for _, member in pairs(members) do member.resultAt = nil end
    -- A new solo encounter must not inherit the previous group's result rows.
    if not IsUnitGrouped("player") then members = {}; lastGrouped = false end
end

function bridge:MarkResult()
    local now = GetGameTimeMilliseconds()
    for _, member in pairs(members) do member.resultAt = now end
    for _, member in pairs(retained) do member.resultAt = now end
end

function bridge:Expire(ageMS)
    local now = GetGameTimeMilliseconds()
    for tag, member in pairs(members) do
        if now - (member.resultAt or member.receivedAt) >= ageMS then members[tag] = nil end
    end
    for tag, member in pairs(retained) do
        if now - (member.resultAt or member.receivedAt) >= ageMS then retained[tag] = nil end
    end
end

function bridge:GetStatus()
    local localShare = BattleScrolls and BattleScrolls.dpsShare
    return {
        grouped = IsUnitGrouped("player"),
        connected = (localShare and registeredShare == localShare) or damageProtocol ~= nil,
        localBattleScrolls = localShare ~= nil,
        healingConnected = (localShare and registeredShare == localShare) or healingProtocol ~= nil,
        error = connectionError,
        receivedCount = receivedCount, lastReceivedAt = lastReceivedAt,
        enabled = damageProtocol and damageProtocol:IsEnabled() or false,
        healingEnabled = healingProtocol and healingProtocol:IsEnabled() or false,
    }
end

function bridge:GetRows()
    local rows = {}
    local now = GetGameTimeMilliseconds()
    local grouped = IsUnitGrouped("player")
    if not grouped and next(members) then
        -- Unit tags are already invalid when GROUP_UPDATE fires. Keep cached
        -- identities, roles and classes without consulting those tags again.
        retained, members = members, {}
    elseif grouped and lastGrouped == false then
        retained = {}
    end
    lastGrouped = grouped
    local function append(member, tag)
        if tag and GetGroupMemberSelectedRole then member.role = GetGroupMemberSelectedRole(tag) end
        if tag and GetUnitClassId then
            local classId = GetUnitClassId(tag)
            if type(classId) == "number" and classId > 0 then member.classId = classId end
        end
        -- BattleScrolls displays the received type, not a role-based guess.
        member.displayType = member.messageType
        local metricAt
        if member.displayType == "healing" then metricAt = member.healingAt else metricAt = member.damageAt end
        member.stale = not metricAt or now - metricAt > STALE_MS
        member.metricAgeMS = metricAt and math.max(0, now - metricAt) or nil
        rows[#rows + 1] = member
    end
    for tag, member in pairs(members) do
        if not DoesUnitExist(tag)
            or AreUnitsEqual(tag, "player") or GetUnitDisplayName(tag) ~= member.identity then
            members[tag] = nil
        else
            append(member, tag)
        end
    end
    if not grouped then
        for _, member in pairs(retained) do append(member) end
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
