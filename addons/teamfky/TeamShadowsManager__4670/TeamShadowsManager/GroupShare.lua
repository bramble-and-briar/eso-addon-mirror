TeamShadowsManager = TeamShadowsManager or {}

local TSM = TeamShadowsManager
local Module = {
    protocolId = 443,
    bahseiProtocolId = 444,
    maxPayloadLength = 6000,
    packetPrefix = "TSMX3",
    chunkLength = 700,
    maxAttempts = 3,
    recentMessages = {},
    incoming = {},
    outgoing = {},
    diagnostics = {},
    transferCounter = 0,
    diagnosticCounter = 0,
}

TSM.GroupShare = Module

local function Chat(message)
    if TSM.LocalizeChatMessage then message = TSM.LocalizeChatMessage(message) end
    if d then d("|c66ccffTSM:|r " .. tostring(message)) end
end

local function NowMs()
    if GetFrameTimeMilliseconds then return GetFrameTimeMilliseconds() end
    if GetGameTimeMilliseconds then return GetGameTimeMilliseconds() end
    return (GetTimeStamp and GetTimeStamp() or 0) * 1000
end

local function IsSelf(unitTag)
    return AreUnitsEqual and AreUnitsEqual(unitTag, "player")
end

local function SenderName(unitTag)
    local name = GetUnitDisplayName and GetUnitDisplayName(unitTag)
    if name and name ~= "" then return name end
    name = GetUnitName and GetUnitName(unitTag)
    return (name and name ~= "") and name or tostring(unitTag or "joueur")
end

local function Encode(value)
    return (tostring(value or ""):gsub("([^%w%-%._ ])", function(char)
        return string.format("%%%02X", string.byte(char))
    end))
end

local function Decode(value)
    if type(value) ~= "string" then return nil end
    local withoutEscapes = value:gsub("%%(%x%x)", "")
    if withoutEscapes:find("%%") then return nil end
    return (value:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

local function Hash(text)
    local hash = 5381
    for index = 1, #text do
        hash = (hash * 33 + string.byte(text, index)) % 2147483647
    end
    return hash
end

local function ParsePayload(payload)
    if type(payload) ~= "string" or #payload < 12 or #payload > Module.maxPayloadLength then return nil end
    local encodedDirectory, encodedName, code = payload:match("^TSMG1|([^|]*)|([^|]*)|(TSM1.*)$")
    if not encodedDirectory or not encodedName or not code then return nil end

    local directoryKey, packName = Decode(encodedDirectory), Decode(encodedName)
    if not directoryKey or not packName or #directoryKey > 40 or #packName > 40 then return nil end
    if directoryKey:find("[^%w_%-]") or packName:find("[%c|<>]") then return nil end
    if not TSM.ValidateMarkerShareCode or not TSM.ValidateMarkerShareCode(code) then return nil end

    return {
        directoryKey = directoryKey,
        packName = packName,
        code = code,
    }
end

local function GroupRecipients()
    local recipients = {}
    local size = GetGroupSize and GetGroupSize() or 0
    for index = 1, size do
        local unitTag = GetGroupUnitTagByIndex and GetGroupUnitTagByIndex(index) or ("group" .. index)
        local exists = not DoesUnitExist or DoesUnitExist(unitTag)
        local online = not IsUnitOnline or IsUnitOnline(unitTag)
        if exists and online and not IsSelf(unitTag) then recipients[SenderName(unitTag)] = true end
    end
    return recipients
end

local function CountKeys(values)
    local count = 0
    for _ in pairs(values or {}) do count = count + 1 end
    return count
end

local function Deliver(unitTag, payload)
    local share = ParsePayload(payload)
    if not share then return end

    local sender = SenderName(unitTag)
    local signature = sender .. ":" .. tostring(Hash(payload))
    local now = NowMs()
    if Module.recentMessages[signature] and now - Module.recentMessages[signature] < 300000 then return end
    Module.recentMessages[signature] = now

    share.sender = sender
    share.typeName = "Pack de markers"
    zo_callLater(function()
        if TSM.UI and TSM.UI.ReceiveGroupMarkerShare then TSM.UI:ReceiveGroupMarkerShare(share) end
    end, 50)
end

local function CleanupIncoming()
    local cutoff = NowMs() - 600000
    for key, transfer in pairs(Module.incoming) do
        if (transfer.updatedAt or 0) < cutoff then Module.incoming[key] = nil end
    end
end

local function MissingChunks(transfer)
    local current = GroupRecipients()
    for recipient in pairs(transfer.expected) do
        if not current[recipient] then transfer.expected[recipient] = nil end
    end

    local missing, missingRecipients = {}, {}
    for recipient in pairs(transfer.expected) do
        local acknowledged = transfer.acknowledged[recipient] or {}
        for index = 1, #transfer.chunks do
            if not acknowledged[index] then
                missing[index] = true
                missingRecipients[recipient] = true
            end
        end
    end
    return missing, missingRecipients
end

local function TransferDelayMs(packets)
    local frames = 0
    for _, packet in ipairs(packets) do frames = frames + math.ceil((#packet + 4) / 28) end
    return math.max(8000, (frames * 1400) + 5000)
end

function Module:QueuePacket(packet)
    if type(packet) ~= "string" or #packet < 12 or #packet > self.maxPayloadLength then return false end
    if not self.protocol and not self:InitializeProtocol() then return false end
    if self.protocol.IsEnabled and not self.protocol:IsEnabled() then return false end
    local ok, sent = pcall(function()
        return self.protocol:Send({ payload = packet }, {
            isRelevantInCombat = false,
            replaceQueuedMessages = false,
        })
    end)
    return ok and sent == true
end

function Module:FinishTransfer(transfer, success, missingRecipients)
    if transfer.done then return end
    transfer.done = true
    self.outgoing[transfer.id] = nil
    local expectedCount = CountKeys(transfer.expected)
    if success then
        Chat(string.format("partage confirme par %d/%d joueur(s).", expectedCount, expectedCount))
        return
    end

    local names = {}
    for name in pairs(missingRecipients or {}) do names[#names + 1] = name end
    table.sort(names)
    Chat(string.format("pas de confirmation fiable de %d joueur(s) (ancienne version ou reception bloquee) : %s. La copie compatible a aussi ete envoyee.",
        #names, #names > 0 and table.concat(names, ", ") or "aucun destinataire compatible"))
end

function Module:ScheduleCheck(transfer, packets)
    zo_callLater(function()
        if transfer.done or Module.outgoing[transfer.id] ~= transfer then return end
        if IsUnitInCombat and IsUnitInCombat("player") then
            Module:ScheduleCheck(transfer, {})
            return
        end
        local missing, missingRecipients = MissingChunks(transfer)
        if not next(missing) then
            Module:FinishTransfer(transfer, true)
            return
        end
        if transfer.attempts >= Module.maxAttempts then
            Module:FinishTransfer(transfer, false, missingRecipients)
            return
        end

        transfer.attempts = transfer.attempts + 1
        local retryPackets = {}
        for index = 1, #transfer.chunks do
            if missing[index] then
                local packet = Module:BuildDataPacket(transfer, index)
                if Module:QueuePacket(packet) then retryPackets[#retryPackets + 1] = packet end
            end
        end
        Chat(string.format("partage : tentative %d/%d pour %d morceau(x) manquant(s).",
            transfer.attempts, Module.maxAttempts, #retryPackets))
        Module:ScheduleCheck(transfer, retryPackets)
    end, TransferDelayMs(packets))
end

function Module:BuildDataPacket(transfer, index)
    return table.concat({
        self.packetPrefix, "D", transfer.id, tostring(transfer.hash), tostring(index),
        tostring(#transfer.chunks), transfer.chunks[index],
    }, "|")
end

function Module:BeginReliableTransfer(transfer)
    if transfer.done or self.outgoing[transfer.id] ~= transfer then return end
    if IsUnitInCombat and IsUnitInCombat("player") then
        zo_callLater(function() Module:BeginReliableTransfer(transfer) end, 5000)
        return
    end

    if not next(transfer.expected) then
        local recipientCount = CountKeys(transfer.recipients)
        transfer.done = true
        self.outgoing[transfer.id] = nil
        Chat(string.format("copie compatible envoyee a %d joueur(s). Confirmation automatique indisponible sur leurs versions.",
            recipientCount))
        return
    end

    transfer.started = true
    local packets = {}
    for index = 1, #transfer.chunks do
        local packet = self:BuildDataPacket(transfer, index)
        if self:QueuePacket(packet) then packets[#packets + 1] = packet end
    end
    if #packets ~= #transfer.chunks then
        self:FinishTransfer(transfer, false, transfer.expected)
        return
    end

    Chat(string.format("confirmation fiable active pour %d/%d joueur(s).",
        CountKeys(transfer.expected), CountKeys(transfer.recipients)))
    self:ScheduleCheck(transfer, packets)
end

function Module:StartReliableTransfer(payload)
    self.transferCounter = (self.transferCounter % 4095) + 1
    local stamp = GetTimeStamp and GetTimeStamp() or math.floor(NowMs() / 1000)
    local id = string.format("%x%x", stamp % 0x7FFFFFFF, self.transferCounter)
    local chunks = {}
    for offset = 1, #payload, self.chunkLength do
        chunks[#chunks + 1] = payload:sub(offset, offset + self.chunkLength - 1)
    end

    local transfer = {
        id = id,
        hash = Hash(payload),
        chunks = chunks,
        recipients = GroupRecipients(),
        expected = {},
        acknowledged = {},
        attempts = 1,
    }
    self.outgoing[id] = transfer

    local packets = {}
    if not self:QueuePacket(payload) then
        self.outgoing[id] = nil
        return false
    end
    packets[#packets + 1] = payload
    local hello = table.concat({ self.packetPrefix, "H", id }, "|")
    for _ = 1, 2 do
        if not self:QueuePacket(hello) then
            self.outgoing[id] = nil
            return false
        end
        packets[#packets + 1] = hello
    end

    Chat(string.format("copie compatible en cours vers %d destinataire(s); detection des confirmations...",
        CountKeys(transfer.recipients)))
    zo_callLater(function() Module:BeginReliableTransfer(transfer) end, TransferDelayMs(packets))
    return true
end

local function ReceiveReliable(unitTag, payload)
    local prefix = Module.packetPrefix
    local diagnosticId = payload:match("^" .. prefix .. "|Q|([%w_%-]+)$")
    if diagnosticId then
        Module:QueuePacket(table.concat({ prefix, "R", diagnosticId }, "|"))
        return true
    end

    local diagnosticResponseId = payload:match("^" .. prefix .. "|R|([%w_%-]+)$")
    if diagnosticResponseId then
        local diagnostic = Module.diagnostics[diagnosticResponseId]
        if diagnostic then diagnostic.responses[SenderName(unitTag)] = true end
        return true
    end

    local helloId = payload:match("^" .. prefix .. "|H|([%w_%-]+)$")
    if helloId then
        Module:QueuePacket(table.concat({ prefix, "P", helloId }, "|"))
        return true
    end

    local presenceId = payload:match("^" .. prefix .. "|P|([%w_%-]+)$")
    if presenceId then
        local transfer = Module.outgoing[presenceId]
        if transfer and not transfer.done and not transfer.started then
            local recipient = SenderName(unitTag)
            if transfer.recipients[recipient] then transfer.expected[recipient] = true end
        end
        return true
    end

    local transferId, hashText, indexText = payload:match("^" .. prefix .. "|A|([%w_%-]+)|(%d+)|(%d+)$")
    if transferId then
        local transfer = Module.outgoing[transferId]
        local hash, index = tonumber(hashText), tonumber(indexText)
        if not transfer or transfer.hash ~= hash or not transfer.chunks[index] then return true end
        local recipient = SenderName(unitTag)
        if not transfer.expected[recipient] then return true end
        transfer.acknowledged[recipient] = transfer.acknowledged[recipient] or {}
        transfer.acknowledged[recipient][index] = true
        local missing = MissingChunks(transfer)
        if not next(missing) then Module:FinishTransfer(transfer, true) end
        return true
    end

    local id, receivedHash, part, total, chunk = payload:match(
        "^" .. prefix .. "|D|([%w_%-]+)|(%d+)|(%d+)|(%d+)|(.*)$")
    if not id then return false end

    receivedHash, part, total = tonumber(receivedHash), tonumber(part), tonumber(total)
    local maxChunks = math.ceil(Module.maxPayloadLength / Module.chunkLength) + 1
    if not receivedHash or not part or not total or total < 1 or total > maxChunks or part < 1 or part > total then
        return true
    end

    CleanupIncoming()
    local sender = SenderName(unitTag)
    local key = sender .. ":" .. id
    local transfer = Module.incoming[key]
    if not transfer or transfer.hash ~= receivedHash or transfer.total ~= total then
        transfer = { hash = receivedHash, total = total, chunks = {}, received = 0 }
        Module.incoming[key] = transfer
    end
    transfer.updatedAt = NowMs()
    if not transfer.chunks[part] then
        transfer.chunks[part] = chunk
        transfer.received = transfer.received + 1
    end

    Module:QueuePacket(table.concat({ prefix, "A", id, tostring(receivedHash), tostring(part) }, "|"))
    if transfer.received ~= total or transfer.delivered then return true end

    local complete = table.concat(transfer.chunks)
    if #complete <= Module.maxPayloadLength and Hash(complete) == receivedHash and ParsePayload(complete) then
        transfer.delivered = true
        Deliver(unitTag, complete)
    else
        Module.incoming[key] = nil
    end
    return true
end

local function ReceivePayload(unitTag, data)
    if IsSelf(unitTag) then return end
    local payload = data and data.payload
    if type(payload) ~= "string" then return end
    if ReceiveReliable(unitTag, payload) then return end
    if ParsePayload(payload) then Deliver(unitTag, payload) end
end

local function ReceiveBahseiPayload(unitTag, data)
    if IsSelf(unitTag) then return end
    local payload = data and data.payload
    if type(payload) ~= "string"
        or not (payload:match("^TSMB1|[A-Z0-9_]+|%d+$") or payload:match("^TSMB1|[A-Z0-9_]+|%d+|%d+$"))
    then return end
    if TSM.BahseiPortal and TSM.BahseiPortal.OnGroupSignal then
        TSM.BahseiPortal:OnGroupSignal(unitTag, payload)
    end
end

function Module:InitializeProtocol()
    if self.protocol then return true end
    if not LibGroupBroadcast or not LibGroupBroadcast.RegisterHandler or not LibGroupBroadcast.CreateStringField then
        self.lastProtocolError = "LibGroupBroadcast manquante"
        return false
    end

    local ok, handler, protocol, bahseiProtocol = pcall(function()
        local h = LibGroupBroadcast:RegisterHandler("TeamShadowsManager")
        h:SetDisplayName("Team Shadows Manager")
        h:SetDescription(TSM.GetString and TSM.GetString("group_share_description") or
            "Partage fiable de packs de markers entre les membres du groupe.")
        local p = h:DeclareProtocol(self.protocolId, "TeamShadowsManagerConfig")
        p:AddField(LibGroupBroadcast.CreateStringField("payload", {
            minLength = 12,
            maxLength = self.maxPayloadLength,
        }))
        p:OnData(ReceivePayload)
        local finalized = p:Finalize({
            isRelevantInCombat = false,
            replaceQueuedMessages = false,
        })
        if finalized ~= true then return h, nil, nil end

        local bahseiOk, b = pcall(function()
            local bahsei = h:DeclareProtocol(self.bahseiProtocolId, "TeamShadowsManagerBahsei")
            bahsei:AddField(LibGroupBroadcast.CreateStringField("payload", {
                minLength = 10,
                maxLength = 32,
            }))
            bahsei:OnData(ReceiveBahseiPayload)
            local bahseiFinalized = bahsei:Finalize({
                isRelevantInCombat = true,
                -- Death packets must never replace one another; each unique
                -- Spectre is part of the shared 24 -> 0 counter.
                replaceQueuedMessages = false,
            })
            return bahseiFinalized == true and bahsei or nil
        end)
        return h, p, bahseiOk and b or nil
    end)

    if not ok or not handler or not protocol then
        self.lastProtocolError = not ok and tostring(handler) or "finalisation refusee"
        return false
    end
    self.handler, self.protocol, self.bahseiProtocol = handler, protocol, bahseiProtocol
    self.lastProtocolError = nil
    self.lastBahseiProtocolError = bahseiProtocol and nil or "protocole Bahsei indisponible"
    return true
end

function Module:SendBahseiSignal(signal, value, total)
    if not IsUnitGrouped or not IsUnitGrouped("player") then return false, "not_grouped" end
    if not self:InitializeProtocol() then return false, self.lastProtocolError or "protocol_unavailable" end
    if not self.bahseiProtocol then return false, self.lastBahseiProtocolError or "protocol_unavailable" end
    if self.bahseiProtocol.IsEnabled and not self.bahseiProtocol:IsEnabled() then
        return false, "protocol_disabled"
    end

    signal = tostring(signal or ""):upper():gsub("[^A-Z0-9_]", "")
    value = tonumber(value) or 0
    if signal == "DEAD" then
        value = math.max(0, math.floor(value))
    else
        value = zo_clamp(value, 0, 99)
    end
    if signal == "" or #signal > 12 then return false, "invalid_signal" end

    local valueText = signal == "DEAD" and string.format("%.0f", value) or tostring(math.floor(value))
    local payload
    if total ~= nil then
        total = zo_clamp(tonumber(total) or 0, 0, 99)
        payload = string.format("TSMB1|%s|%s|%d", signal, valueText, total)
    else
        payload = string.format("TSMB1|%s|%s", signal, valueText)
    end
    if #payload > 32 then return false, "payload_too_long" end

    local sent = self.bahseiProtocol:Send({
        payload = payload,
    }, {
        isRelevantInCombat = true,
        replaceQueuedMessages = false,
    })
    return sent == true, sent == true and nil or "send_failed"
end

function Module:RefreshLanguage()
    if not self.handler then return end
    pcall(function()
        self.handler:SetDisplayName("Team Shadows Manager")
        self.handler:SetDescription(TSM.GetString and TSM.GetString("group_share_description") or
            "Partage fiable de packs de markers entre les membres du groupe.")
    end)
end

function Module:SendCurrentSelection()
    if not IsUnitGrouped or not IsUnitGrouped("player") then
        Chat("partage impossible : tu n'es pas dans un groupe.")
        return false
    end
    if IsUnitInCombat and IsUnitInCombat("player") then
        Chat("partage impossible : attends la fin du combat.")
        return false
    end
    if not TSM.GetCurrentMarkerShareData then return false end

    local selection, message = TSM.GetCurrentMarkerShareData()
    if not selection then
        Chat(message or "aucun pack selectionne.")
        return false
    end

    local payload = table.concat({
        "TSMG1", Encode(selection.directoryKey), Encode(selection.packName), selection.code,
    }, "|")
    if #payload > self.maxPayloadLength then
        Chat("partage impossible : le pack depasse 6000 caracteres.")
        return false
    end
    if not self:InitializeProtocol() then
        Chat("partage impossible : " .. tostring(self.lastProtocolError or "protocole indisponible") .. ".")
        return false
    end
    if self.protocol.IsEnabled and not self.protocol:IsEnabled() then
        Chat("partage impossible : le protocole est desactive dans LibGroupBroadcast.")
        return false
    end
    if self:StartReliableTransfer(payload) then return true end
    Chat("l'envoi du pack a echoue.")
    return false
end

function Module:FinishDiagnostic(diagnostic)
    if self.diagnostics[diagnostic.id] ~= diagnostic then return end
    self.diagnostics[diagnostic.id] = nil

    local responders, missing = {}, {}
    for name in pairs(diagnostic.expected) do
        if diagnostic.responses[name] then
            responders[#responders + 1] = name
        else
            missing[#missing + 1] = name
        end
    end
    table.sort(responders)
    table.sort(missing)

    Chat(string.format("DIAG termine : %d/%d joueur(s) repondent.", #responders, CountKeys(diagnostic.expected)))
    if #responders > 0 then Chat("DIAG OK : " .. table.concat(responders, ", ")) end
    if #missing > 0 then
        Chat("DIAG SANS RETOUR : " .. table.concat(missing, ", "))
        Chat("Sur ces joueurs : mettre a jour l'addon puis verifier LibGroupBroadcast > Team Shadows Manager > Allow Sending.")
    end
end

function Module:RunDiagnostic()
    Chat("DIAG Team Shadows Manager v" .. tostring(TSM.version or "?") .. ".")
    if not IsUnitGrouped or not IsUnitGrouped("player") then
        Chat("DIAG ARRET : tu n'es pas dans un groupe.")
        return false
    end
    if IsUnitInCombat and IsUnitInCombat("player") then
        Chat("DIAG ARRET : attends la fin du combat.")
        return false
    end
    if not self:InitializeProtocol() then
        Chat("DIAG ARRET : " .. tostring(self.lastProtocolError or "protocole indisponible") .. ".")
        return false
    end
    if self.protocol.IsEnabled and not self.protocol:IsEnabled() then
        Chat("DIAG ARRET : Allow Sending est desactive dans LibGroupBroadcast > Team Shadows Manager.")
        return false
    end

    local expected = GroupRecipients()
    local expectedCount = CountKeys(expected)
    if expectedCount == 0 then
        Chat("DIAG ARRET : aucun autre joueur connecte dans le groupe.")
        return false
    end

    self.diagnosticCounter = (self.diagnosticCounter % 4095) + 1
    local stamp = GetTimeStamp and GetTimeStamp() or math.floor(NowMs() / 1000)
    local id = string.format("d%x%x", stamp % 0x7FFFFFFF, self.diagnosticCounter)
    local diagnostic = { id = id, expected = expected, responses = {} }
    self.diagnostics[id] = diagnostic
    local packet = table.concat({ self.packetPrefix, "Q", id }, "|")
    local queued = self:QueuePacket(packet)
    if queued then queued = self:QueuePacket(packet) end
    if not queued then
        self.diagnostics[id] = nil
        Chat("DIAG ARRET : le signal de test n'a pas pu etre envoye.")
        return false
    end

    Chat(string.format("DIAG en cours vers %d joueur(s), resultat dans environ 18 secondes...", expectedCount))
    zo_callLater(function() Module:FinishDiagnostic(diagnostic) end, 18000)
    return true
end

function Module:Initialize()
    self:InitializeProtocol()
end
