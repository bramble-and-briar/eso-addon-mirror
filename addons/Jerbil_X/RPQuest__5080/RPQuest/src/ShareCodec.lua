-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0006-puntos-de-descubrimiento-ocultos.md
-- Ref: docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.ShareCodec = {}
local ShareCodec = Addon.ShareCodec

local B64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local B64_LOOKUP = {}
local B64_CHARS = {}
for i = 1, #B64_ALPHABET do
    local ch = string.sub(B64_ALPHABET, i, i)
    B64_LOOKUP[ch] = i - 1
    B64_CHARS[i - 1] = ch
end

local BYTE_TO_CHAR = {}
for b = 0, 255 do
    BYTE_TO_CHAR[b] = string.char(b)
end

local ESCAPE_MAP = {
    ["%"] = "%25",
    ["|"] = "%7C",
    [";"] = "%3B",
    ["~"] = "%7E",
    ["\r"] = "",
    ["\n"] = "%0A",
}

local UNESCAPE_MAP = {
    ["%0A"] = "\n",
    ["%7E"] = "~",
    ["%3B"] = ";",
    ["%7C"] = "|",
    ["%25"] = "%",
}

local function EscapeField(str)
    if str == nil then return "" end
    local s = tostring(str)
    if not s:find("[%%|;~\r\n]") then
        return s
    end
    return (s:gsub("[%%|;~\r\n]", ESCAPE_MAP))
end

local function UnescapeField(str)
    if str == nil then return "" end
    local s = tostring(str)
    if not s:find("%", 1, true) then
        return s
    end
    return (s:gsub("%%[0-9A-F][0-9A-F]", UNESCAPE_MAP))
end

local function SplitByChar(raw, sep)
    local parts = {}
    local count = 0
    local startIdx = 1
    while true do
        local pos = string.find(raw, sep, startIdx, true)
        count = count + 1
        if not pos then
            parts[count] = string.sub(raw, startIdx)
            break
        end
        parts[count] = string.sub(raw, startIdx, pos - 1)
        startIdx = pos + 1
    end
    return parts
end

local function EncodeTargetsList(targets)
    if type(targets) ~= "table" or #targets == 0 then
        return ""
    end
    local items = {}
    for _, t in ipairs(targets) do
        if type(t) == "table" and type(t.name) == "string" and t.name ~= "" then
            local req = math.max(1, math.floor(tonumber(t.requiredCount) or 1))
            table.insert(items, EscapeField(t.name) .. "~" .. tostring(req))
        end
    end
    return table.concat(items, ";")
end

local function DecodeTargetsList(rawTargets)
    if type(rawTargets) ~= "string" or rawTargets == "" then
        return nil
    end
    local entries = SplitByChar(rawTargets, ";")
    local targets = {}
    for _, item in ipairs(entries) do
        if item ~= "" then
            local kv = SplitByChar(item, "~")
            local name = UnescapeField(kv[1] or "")
            local req = tonumber(kv[2]) or 1
            if name ~= "" and req >= 1 then
                table.insert(targets, {
                    name = name,
                    currentCount = 0,
                    requiredCount = math.max(1, math.floor(req)),
                })
            end
        end
    end
    if #targets == 0 then
        return nil
    end
    return targets
end

local function EncodeDiscoveriesList(discoveries)
    if type(discoveries) ~= "table" or #discoveries == 0 then
        return ""
    end
    local defaultRad = (Addon.Constants and Addon.Constants.DISCOVERY_RADIUS and Addon.Constants.DISCOVERY_RADIUS.MEDIUM) or 1500
    local items = {}
    for _, d in ipairs(discoveries) do
        if type(d) == "table" and d.worldX and d.worldZ then
            local parts = {
                tostring(math.floor(tonumber(d.zoneId) or 0)),
                tostring(math.floor(tonumber(d.worldX) or 0)),
                tostring(math.floor(tonumber(d.worldY) or 0)),
                tostring(math.floor(tonumber(d.worldZ) or 0)),
                tostring(math.floor(tonumber(d.mapId) or 0)),
                string.format("%.4f", tonumber(d.x) or 0),
                string.format("%.4f", tonumber(d.y) or 0),
                tostring(math.max(100, math.floor(tonumber(d.radius) or defaultRad))),
                EscapeField(d.message or ""),
            }
            table.insert(items, table.concat(parts, "~"))
        end
    end
    return table.concat(items, ";")
end

local function DecodeDiscoveriesList(rawDiscoveries)
    if type(rawDiscoveries) ~= "string" or rawDiscoveries == "" then
        return {}
    end
    local defaultRad = (Addon.Constants and Addon.Constants.DISCOVERY_RADIUS and Addon.Constants.DISCOVERY_RADIUS.MEDIUM) or 1500
    local entries = SplitByChar(rawDiscoveries, ";")
    local discoveries = {}
    for _, item in ipairs(entries) do
        if item ~= "" then
            local kv = SplitByChar(item, "~")
            local worldX = tonumber(kv[2])
            local worldZ = tonumber(kv[4])
            if worldX and worldZ then
                table.insert(discoveries, {
                    zoneId = math.floor(tonumber(kv[1]) or 0),
                    worldX = math.floor(worldX),
                    worldY = math.floor(tonumber(kv[3]) or 0),
                    worldZ = math.floor(worldZ),
                    mapId = math.floor(tonumber(kv[5]) or 0),
                    x = tonumber(kv[6]) or 0,
                    y = tonumber(kv[7]) or 0,
                    radius = math.max(100, math.floor(tonumber(kv[8]) or defaultRad)),
                    message = UnescapeField(kv[9] or ""),
                    discovered = false,
                })
            end
        end
    end
    return discoveries
end

local function EncodeDialoguesList(dialogues)
    if type(dialogues) ~= "table" or #dialogues == 0 then
        return ""
    end
    local maxNpcs = (Addon.Constants and Addon.Constants.DIALOGUE and Addon.Constants.DIALOGUE.MAX_NPCS) or 3
    local items = {}
    for _, d in ipairs(dialogues) do
        if #items >= maxNpcs then break end
        if type(d) == "table" and type(d.npcName) == "string" and d.npcName ~= "" then
            local parts = {
                EscapeField(d.npcName),
                tostring(math.floor(tonumber(d.zoneId) or 0)),
                EscapeField(d.response or ""),
            }
            table.insert(items, table.concat(parts, "~"))
        end
    end
    return table.concat(items, ";")
end

local function DecodeDialoguesList(rawDialogues)
    if type(rawDialogues) ~= "string" or rawDialogues == "" then
        return {}
    end
    local maxNpcs = (Addon.Constants and Addon.Constants.DIALOGUE and Addon.Constants.DIALOGUE.MAX_NPCS) or 3
    local entries = SplitByChar(rawDialogues, ";")
    local dialogues = {}
    for _, item in ipairs(entries) do
        if #dialogues >= maxNpcs then break end
        if item ~= "" then
            local kv = SplitByChar(item, "~")
            local npcName = UnescapeField(kv[1] or "")
            if npcName ~= "" then
                table.insert(dialogues, {
                    npcName = npcName,
                    zoneId = math.floor(tonumber(kv[2]) or 0),
                    response = UnescapeField(kv[3] or ""),
                })
            end
        end
    end
    return dialogues
end

local function ComputeChecksum16(data)
    local sum1 = 0x5A
    local sum2 = 0xA5
    for i = 1, #data do
        local b = string.byte(data, i)
        sum1 = (sum1 + b) % 255
        sum2 = (sum2 + sum1) % 255
    end
    local combined = (sum2 * 256) + sum1
    return string.format("%04X", combined)
end

local function ComputeSignature32(data)
    local h1 = 0x811C
    local h2 = 0x9DC5
    for i = 1, #data do
        local b = string.byte(data, i)
        h1 = ((h1 * 33) + b + i) % 65521
        h2 = ((h2 * 131) + b + (i * 7)) % 65521
    end
    return string.format("%04X%04X", h1, h2)
end

local function BuildQuestPayloadString(quest)
    if type(quest) ~= "table" then
        return nil, "Invalid quest table"
    end

    local targets = quest.targets or {}
    local discoveries = quest.discoveries or {}
    local encodedTargets = EncodeTargetsList(targets)
    local encodedDiscoveries = EncodeDiscoveriesList(discoveries)

    if encodedTargets == "" and encodedDiscoveries == "" then
        return nil, "Invalid quest table"
    end

    local fields = {
        EscapeField(quest.title or ""),
        EscapeField(quest.description or ""),
        tostring(math.floor(tonumber(quest.mapId) or 0)),
        tostring(math.floor(tonumber(quest.zoneId) or 0)),
        EscapeField(quest.mapName or ""),
        string.format("%.4f", tonumber(quest.targetX) or 0.5),
        string.format("%.4f", tonumber(quest.targetY) or 0.5),
        string.format("%.4f", tonumber(quest.areaCenterX) or 0.5),
        string.format("%.4f", tonumber(quest.areaCenterY) or 0.5),
        string.format("%.4f", tonumber(quest.areaRadius) or 0.075),
        encodedTargets,
        EscapeField(quest.completionMessage or ""),
        quest.requireUndetected and "1" or "0",
        encodedDiscoveries,
        EscapeField(quest.clue or ""),
        quest.hideMapArea and "1" or "0",
        EncodeDialoguesList(quest.dialogues),
    }

    return table.concat(fields, "|")
end

local function Base64UrlEncode(input)
    local out = {}
    local outLen = 0
    local len = #input
    local i = 1
    local strByte = string.byte
    local floor = math.floor
    while i <= len do
        local b1 = strByte(input, i) or 0
        local b2 = strByte(input, i + 1)
        local b3 = strByte(input, i + 2)

        local n = (b1 * 65536) + ((b2 or 0) * 256) + (b3 or 0)
        local c1 = floor(n / 262144) % 64
        local c2 = floor(n / 4096) % 64
        local c3 = floor(n / 64) % 64
        local c4 = n % 64

        outLen = outLen + 1
        out[outLen] = B64_CHARS[c1]
        outLen = outLen + 1
        out[outLen] = B64_CHARS[c2]
        if b2 then
            outLen = outLen + 1
            out[outLen] = B64_CHARS[c3]
        end
        if b3 then
            outLen = outLen + 1
            out[outLen] = B64_CHARS[c4]
        end

        i = i + 3
    end
    return table.concat(out)
end

local function Base64UrlDecode(encoded)
    if type(encoded) ~= "string" or encoded == "" then
        return nil
    end

    local out = {}
    local outLen = 0
    local len = #encoded
    local i = 1
    local strSub = string.sub
    local floor = math.floor
    while i <= len do
        local ch1 = strSub(encoded, i, i)
        local ch2 = strSub(encoded, i + 1, i + 1)
        local ch3 = (i + 2 <= len) and strSub(encoded, i + 2, i + 2) or nil
        local ch4 = (i + 3 <= len) and strSub(encoded, i + 3, i + 3) or nil

        local v1 = B64_LOOKUP[ch1]
        local v2 = B64_LOOKUP[ch2]
        local v3 = ch3 and B64_LOOKUP[ch3] or 0
        local v4 = ch4 and B64_LOOKUP[ch4] or 0

        if v1 == nil or v2 == nil or (ch3 and B64_LOOKUP[ch3] == nil) or (ch4 and B64_LOOKUP[ch4] == nil) then
            return nil
        end

        local n = (v1 * 262144) + (v2 * 4096) + (v3 * 64) + v4
        local b1 = floor(n / 65536) % 256
        local b2 = floor(n / 256) % 256
        local b3 = n % 256

        outLen = outLen + 1
        out[outLen] = BYTE_TO_CHAR[b1]
        if ch3 then
            outLen = outLen + 1
            out[outLen] = BYTE_TO_CHAR[b2]
        end
        if ch4 then
            outLen = outLen + 1
            out[outLen] = BYTE_TO_CHAR[b3]
        end

        i = i + 4
    end

    return table.concat(out)
end

function ShareCodec:EncodeQuest(quest)
    local rawPayload, err = BuildQuestPayloadString(quest)
    if not rawPayload then
        return nil, err
    end

    local prefix = Addon.Constants.SHARE_CODEC.PREFIX
    local checksum = ComputeChecksum16(rawPayload)
    local encodedPayload = Base64UrlEncode(rawPayload)

    return string.format("%s:%s:%s", prefix, checksum, encodedPayload)
end

local function DecodeAndVerifyEnvelope(codeString, invalidFormatErr, badB64Err, badChecksumErr, allowedPrefixes)
    local trimmed = codeString:gsub("^%s+", ""):gsub("%s+$", "")
    local pfx, checksum, encodedPayload = string.match(trimmed, "^([A-Z0-9]+):([0-9A-Fa-f]+):([A-Za-z0-9%-_]+)$")
    if not pfx or not checksum or #checksum ~= 4 or not encodedPayload then
        return nil, nil, invalidFormatErr
    end
    if allowedPrefixes then
        local errOrAllowed = allowedPrefixes[pfx]
        if errOrAllowed == nil then
            return nil, nil, invalidFormatErr
        elseif type(errOrAllowed) == "string" then
            return nil, nil, errOrAllowed
        end
    end

    local rawPayload = Base64UrlDecode(encodedPayload)
    if not rawPayload then
        return nil, nil, badB64Err
    end

    local expectedChecksum = ComputeChecksum16(rawPayload)
    if checksum:upper() ~= expectedChecksum:upper() then
        return nil, nil, badChecksumErr
    end

    return pfx, rawPayload, nil
end

function ShareCodec:DecodeQuest(codeString)
    if type(codeString) ~= "string" then
        return nil, "Code must be a string"
    end

    local prefix = Addon.Constants.SHARE_CODEC.PREFIX
    local legacyPrefix = Addon.Constants.SHARE_CODEC.LEGACY_PREFIX or "RPQ1"
    local _, rawPayload, envErr = DecodeAndVerifyEnvelope(
        codeString,
        "Invalid code format",
        "Corrupted base64 payload",
        "Checksum mismatch",
        { [prefix] = true, [legacyPrefix] = true }
    )
    if not rawPayload then
        return nil, envErr
    end

    local fields = SplitByChar(rawPayload, "|")
    if #fields < 11 then
        return nil, "Incomplete quest payload"
    end

    local title = UnescapeField(fields[1])
    local description = UnescapeField(fields[2])
    local mapId = tonumber(fields[3])
    local zoneId = tonumber(fields[4])
    local mapName = UnescapeField(fields[5])
    local targetX = tonumber(fields[6])
    local targetY = tonumber(fields[7])
    local areaCenterX = tonumber(fields[8])
    local areaCenterY = tonumber(fields[9])
    local areaRadius = tonumber(fields[10])
    local decodedTargets = DecodeTargetsList(fields[11]) or {}
    local completionMessage = fields[12] and UnescapeField(fields[12]) or ""
    local requireUndetected = (fields[13] == "1")
    local decodedDiscoveries = fields[14] and DecodeDiscoveriesList(fields[14]) or {}
    local clue = fields[15] and UnescapeField(fields[15]) or ""
    local hideMapArea = (fields[16] == "1")
    local decodedDialogues = fields[17] and DecodeDialoguesList(fields[17]) or {}

    if #decodedTargets == 0 and #decodedDiscoveries == 0 then
        return nil, "Invalid target data in code"
    end

    if #decodedTargets > 0 and (not areaCenterX or not areaCenterY or not areaRadius or areaRadius <= 0) then
        return nil, "Invalid area coordinates in code"
    end

    return {
        title = title,
        description = description,
        clue = clue,
        completionMessage = completionMessage,
        targets = decodedTargets,
        discoveries = decodedDiscoveries,
        dialogues = decodedDialogues,
        mapId = math.floor(mapId or 0),
        zoneId = math.floor(zoneId or 0),
        mapName = mapName,
        targetX = (#decodedTargets > 0) and (targetX or areaCenterX) or nil,
        targetY = (#decodedTargets > 0) and (targetY or areaCenterY) or nil,
        areaCenterX = (#decodedTargets > 0) and areaCenterX or nil,
        areaCenterY = (#decodedTargets > 0) and areaCenterY or nil,
        areaRadius = areaRadius or 0.075,
        hideMapArea = hideMapArea,
        requireUndetected = requireUndetected,
    }
end

function ShareCodec:ComputeQuestSignature(quest)
    local rawPayload, err = BuildQuestPayloadString(quest)
    if not rawPayload then
        return nil, err
    end
    return ComputeSignature32(rawPayload)
end

function ShareCodec:EncodeCompletion(quest, characterName, completedAt)
    if type(quest) ~= "table" or not quest.completed then
        return nil, "Quest is not completed"
    end

    if type(characterName) ~= "string" then
        return nil, "Invalid character name"
    end
    local cleanName = characterName:gsub("^%s+", ""):gsub("%s+$", "")
    if cleanName == "" then
        return nil, "Invalid character name"
    end

    local signature, err = self:ComputeQuestSignature(quest)
    if not signature then
        return nil, err
    end

    local ts = math.max(0, math.floor(tonumber(completedAt) or 0))
    local stealthFlag = ""
    if quest.requireUndetected then
        stealthFlag = quest.wasDetected and "1" or "0"
    end
    local rawPayload = table.concat({
        signature,
        EscapeField(cleanName),
        "1",
        tostring(ts),
        stealthFlag,
    }, "|")

    local prefix = Addon.Constants.SHARE_CODEC.COMPLETION_PREFIX
    local checksum = ComputeChecksum16(rawPayload)
    local encodedPayload = Base64UrlEncode(rawPayload)

    return string.format("%s:%s:%s", prefix, checksum, encodedPayload)
end

function ShareCodec:DecodeCompletion(codeString)
    if type(codeString) ~= "string" then
        return nil, "VALIDATE_ERR_INVALID_CODE"
    end

    local questPrefix = Addon.Constants.SHARE_CODEC.PREFIX
    local legacyPrefix = Addon.Constants.SHARE_CODEC.LEGACY_PREFIX or "RPQ1"
    local compPrefix = Addon.Constants.SHARE_CODEC.COMPLETION_PREFIX

    local _, rawPayload, envErr = DecodeAndVerifyEnvelope(
        codeString,
        "VALIDATE_ERR_INVALID_CODE",
        "VALIDATE_ERR_INVALID_CODE",
        "VALIDATE_ERR_INVALID_CODE",
        {
            [compPrefix] = true,
            [questPrefix] = "VALIDATE_ERR_NOT_COMPLETION_CODE",
            [legacyPrefix] = "VALIDATE_ERR_NOT_COMPLETION_CODE",
        }
    )
    if not rawPayload then
        return nil, envErr
    end

    local fields = SplitByChar(rawPayload, "|")
    if #fields < 3 then
        return nil, "VALIDATE_ERR_INVALID_CODE"
    end

    local questSignature = fields[1]
    local characterName = UnescapeField(fields[2])
    local completed = (fields[3] == "1")
    local completedAt = tonumber(fields[4]) or 0
    local wasDetected = nil
    if fields[5] == "1" then
        wasDetected = true
    elseif fields[5] == "0" then
        wasDetected = false
    end

    if not questSignature or not string.match(questSignature, "^[0-9A-Fa-f]+$") or #questSignature ~= 8 then
        return nil, "VALIDATE_ERR_INVALID_CODE"
    end
    if not characterName or characterName == "" then
        return nil, "VALIDATE_ERR_INVALID_CODE"
    end

    return {
        questSignature = questSignature:upper(),
        characterName = characterName,
        completed = completed,
        completedAt = math.max(0, math.floor(completedAt)),
        wasDetected = wasDetected,
    }
end

function ShareCodec:ValidateCompletionForQuest(quest, codeString)
    local expectedSignature, sigErr = self:ComputeQuestSignature(quest)
    if not expectedSignature then
        return false, "VALIDATE_ERR_INVALID_CODE", sigErr
    end

    local decoded, errKey = self:DecodeCompletion(codeString)
    if not decoded then
        return false, errKey
    end

    if not decoded.completed then
        return false, "VALIDATE_ERR_NOT_COMPLETED"
    end

    if decoded.questSignature ~= expectedSignature then
        return false, "VALIDATE_ERR_WRONG_QUEST"
    end

    return true, decoded
end
