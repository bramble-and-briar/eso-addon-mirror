-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0006-puntos-de-descubrimiento-ocultos.md
-- Ref: docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md
-- Ref: docs/adr/0008-codec-compacto-rpq3-lzss-base85.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.ShareCodec = {}
local ShareCodec = Addon.ShareCodec

local function GetClientLanguage()
    local lang = GetCVar("language.2") or GetCVar("Language.2")
    if type(lang) == "string" and lang ~= "" then
        return lang:lower()
    end
    if Addon.Locale and Addon.Locale.GetLanguage then
        return (Addon.Locale:GetLanguage() or "en"):lower()
    end
    return "en"
end

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
    local defaultRad = (Addon.Constants and Addon.Constants.DISCOVERY_RADIUS and Addon.Constants.DISCOVERY_RADIUS.MEDIUM) or 1500
    local items = {}
    for _, t in ipairs(targets) do
        if type(t) == "table" and type(t.name) == "string" and t.name ~= "" then
            local req = math.max(1, math.floor(tonumber(t.requiredCount) or 1))
            local hasLoc = (t.worldX ~= nil and t.worldZ ~= nil)
            local reqLoc = (t.locationRequired == true)
            local msg = type(t.customMessage) == "string" and t.customMessage or ""
            if hasLoc or reqLoc or msg ~= "" then
                local parts = {
                    EscapeField(t.name),
                    tostring(req),
                    hasLoc and tostring(math.floor(tonumber(t.zoneId) or 0)) or "",
                    hasLoc and tostring(math.floor(tonumber(t.worldX))) or "",
                    hasLoc and tostring(math.floor(tonumber(t.worldZ))) or "",
                    hasLoc and tostring(math.max(100, math.floor(tonumber(t.radius) or defaultRad))) or "",
                    reqLoc and "1" or "0",
                    EscapeField(msg),
                }
                table.insert(items, table.concat(parts, "~"))
            else
                table.insert(items, EscapeField(t.name) .. "~" .. tostring(req))
            end
        end
    end
    return table.concat(items, ";")
end

local function DecodeTargetsList(rawTargets)
    if type(rawTargets) ~= "string" or rawTargets == "" then
        return nil
    end
    local defaultRad = (Addon.Constants and Addon.Constants.DISCOVERY_RADIUS and Addon.Constants.DISCOVERY_RADIUS.MEDIUM) or 1500
    local entries = SplitByChar(rawTargets, ";")
    local targets = {}
    for _, item in ipairs(entries) do
        if item ~= "" then
            local kv = SplitByChar(item, "~")
            local name = UnescapeField(kv[1] or "")
            local req = tonumber(kv[2]) or 1
            if name ~= "" and req >= 1 then
                local wx = (kv[4] ~= nil and kv[4] ~= "") and tonumber(kv[4]) or nil
                local wz = (kv[5] ~= nil and kv[5] ~= "") and tonumber(kv[5]) or nil
                local hasLoc = (wx ~= nil and wz ~= nil)
                table.insert(targets, {
                    name = name,
                    currentCount = 0,
                    requiredCount = math.max(1, math.floor(req)),
                    zoneId = hasLoc and math.floor(tonumber(kv[3]) or 0) or nil,
                    worldX = hasLoc and wx or nil,
                    worldZ = hasLoc and wz or nil,
                    radius = hasLoc and math.max(100, math.floor(tonumber(kv[6]) or defaultRad)) or nil,
                    locationRequired = (kv[7] == "1"),
                    customMessage = UnescapeField(kv[8] or ""),
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
                EscapeField(d.clue or ""),
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
                    clue = kv[4] ~= nil and UnescapeField(kv[4]) or nil,
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
        EscapeField((type(quest.language) == "string" and quest.language ~= "" and quest.language:lower()) or GetClientLanguage()),
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

local B85_ALPHABET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!$%&+,-./;=?@^{}()[]#'\""
local B85_LOOKUP = {}
local B85_CHARS = {}
for i = 1, #B85_ALPHABET do
    local ch = string.sub(B85_ALPHABET, i, i)
    B85_LOOKUP[ch] = i - 1
    B85_CHARS[i - 1] = ch
end

local function Base85Encode(input)
    local out = {}
    local outLen = 0
    local len = #input
    local i = 1
    local strByte = string.byte
    local floor = math.floor
    while i <= len do
        local rem = len - i + 1
        local chunkLen = rem >= 4 and 4 or rem
        local b1 = strByte(input, i) or 0
        local b2 = (chunkLen >= 2) and strByte(input, i + 1) or 0
        local b3 = (chunkLen >= 3) and strByte(input, i + 2) or 0
        local b4 = (chunkLen >= 4) and strByte(input, i + 3) or 0

        local n = ((b1 * 256 + b2) * 256 + b3) * 256 + b4
        local d5 = n % 85; n = floor(n / 85)
        local d4 = n % 85; n = floor(n / 85)
        local d3 = n % 85; n = floor(n / 85)
        local d2 = n % 85; n = floor(n / 85)
        local d1 = n % 85

        local digits = { d1, d2, d3, d4, d5 }
        local emitCount = chunkLen + 1
        for k = 1, emitCount do
            outLen = outLen + 1
            out[outLen] = B85_CHARS[digits[k]]
        end
        i = i + 4
    end
    return table.concat(out)
end

local function Base85Decode(encoded)
    if type(encoded) ~= "string" then return nil end
    local len = #encoded
    if len == 0 then return "" end
    local out = {}
    local outLen = 0
    local i = 1
    local strSub = string.sub
    local floor = math.floor
    while i <= len do
        local rem = len - i + 1
        if rem == 1 then
            return nil
        end
        local chunkChars = rem >= 5 and 5 or rem
        local n = 0
        for k = 0, chunkChars - 1 do
            local ch = strSub(encoded, i + k, i + k)
            local v = B85_LOOKUP[ch]
            if v == nil then return nil end
            n = n * 85 + v
        end
        for _ = chunkChars + 1, 5 do
            n = n * 85 + 84
        end
        if n > 4294967295 then
            return nil
        end
        local b4 = n % 256; n = floor(n / 256)
        local b3 = n % 256; n = floor(n / 256)
        local b2 = n % 256; n = floor(n / 256)
        local b1 = n % 256

        local emitBytes = chunkChars - 1
        local bytes = { b1, b2, b3, b4 }
        for k = 1, emitBytes do
            outLen = outLen + 1
            out[outLen] = BYTE_TO_CHAR[bytes[k]]
        end
        i = i + 5
    end
    return table.concat(out)
end

local function WriteUVarint(buf, n)
    n = math.max(0, math.floor(tonumber(n) or 0))
    while n >= 128 do
        buf[#buf + 1] = BYTE_TO_CHAR[(n % 128) + 128]
        n = math.floor(n / 128)
    end
    buf[#buf + 1] = BYTE_TO_CHAR[n]
end

local function ReadUVarint(data, pos, len)
    local result = 0
    local mult = 1
    while pos <= len do
        local b = string.byte(data, pos)
        pos = pos + 1
        result = result + (b % 128) * mult
        if b < 128 then
            return result, pos
        end
        mult = mult * 128
        if mult > 2 ^ 49 then return nil, pos end
    end
    return nil, pos
end

local function WriteSVarint(buf, n)
    n = math.floor(tonumber(n) or 0)
    local zz = (n >= 0) and (n * 2) or (-n * 2 - 1)
    WriteUVarint(buf, zz)
end

local function ReadSVarint(data, pos, len)
    local zz, nextPos = ReadUVarint(data, pos, len)
    if not zz then return nil, nextPos end
    local n = (zz % 2 == 0) and (zz / 2) or -((zz + 1) / 2)
    return n, nextPos
end

local function WriteUInt16(buf, val)
    local snapped = tonumber(string.format("%.4f", tonumber(val) or 0)) or 0
    local q = math.floor(math.max(0, math.min(1, snapped)) * 65535 + 0.5)
    buf[#buf + 1] = BYTE_TO_CHAR[math.floor(q / 256)]
    buf[#buf + 1] = BYTE_TO_CHAR[q % 256]
end

local function ReadUInt16(data, pos, len)
    if pos + 1 > len then return nil, pos end
    local b1, b2 = string.byte(data, pos, pos + 1)
    return ((b1 * 256) + b2) / 65535, pos + 2
end

local function WriteStr(buf, str)
    local s = (str ~= nil) and tostring(str) or ""
    WriteUVarint(buf, #s)
    if #s > 0 then
        buf[#buf + 1] = s
    end
end

local function ReadStr(data, pos, len)
    local sLen, nextPos = ReadUVarint(data, pos, len)
    if not sLen or nextPos + sLen - 1 > len then return nil, nextPos end
    if sLen == 0 then return "", nextPos end
    return string.sub(data, nextPos, nextPos + sLen - 1), nextPos + sLen
end

local function CompressLZSS(data)
    local n = #data
    if n < 8 then
        return "\0" .. data
    end

    local strByte = string.byte
    local head = {}
    local out = {}
    local outLen = 0
    local i = 1

    while i <= n do
        local flagPos = outLen + 1
        outLen = flagPos
        out[flagPos] = "\0"
        local flags = 0
        local bit = 1

        for _ = 1, 8 do
            if i > n then break end
            local bestLen = 0
            local bestOff = 0
            if i + 2 <= n then
                local b1, b2, b3 = strByte(data, i, i + 2)
                local h = (b1 * 65536) + (b2 * 256) + b3
                local prev = head[h]
                head[h] = i
                if prev and (i - prev) <= 4096 then
                    local maxLen = math.min(18, n - i + 1)
                    local m = 0
                    while m < maxLen and strByte(data, prev + m) == strByte(data, i + m) do
                        m = m + 1
                    end
                    if m >= 3 then
                        bestLen = m
                        bestOff = i - prev
                    end
                end
            end

            if bestLen >= 3 then
                flags = flags + bit
                local offM1 = bestOff - 1
                local lenM3 = bestLen - 3
                outLen = outLen + 1
                out[outLen] = BYTE_TO_CHAR[math.floor(offM1 / 16)]
                outLen = outLen + 1
                out[outLen] = BYTE_TO_CHAR[((offM1 % 16) * 16) + lenM3]
                i = i + bestLen
            else
                outLen = outLen + 1
                out[outLen] = string.sub(data, i, i)
                i = i + 1
            end
            bit = bit * 2
        end
        out[flagPos] = BYTE_TO_CHAR[flags]
    end

    local compressed = table.concat(out)
    if #compressed + 1 >= n then
        return "\0" .. data
    end
    return "\1" .. compressed
end

local function DecompressLZSS(data)
    if type(data) ~= "string" or #data < 1 then return nil end
    local mode = string.byte(data, 1)
    if mode == 0 then
        return string.sub(data, 2)
    elseif mode ~= 1 then
        return nil
    end

    local len = #data
    local pos = 2
    local out = {}
    local outLen = 0
    local strByte = string.byte
    local floor = math.floor

    while pos <= len do
        local flags = strByte(data, pos)
        pos = pos + 1
        for k = 0, 7 do
            if pos > len then break end
            local isRef = (floor(flags / (2 ^ k)) % 2) == 1
            if isRef then
                if pos + 1 > len then return nil end
                local b1, b2 = strByte(data, pos, pos + 1)
                pos = pos + 2
                local offset = (b1 * 16) + floor(b2 / 16) + 1
                local matchLen = (b2 % 16) + 3
                if offset < 1 or offset > outLen then return nil end
                local startIdx = outLen - offset + 1
                for m = 0, matchLen - 1 do
                    outLen = outLen + 1
                    out[outLen] = out[startIdx + m]
                end
            else
                outLen = outLen + 1
                out[outLen] = BYTE_TO_CHAR[strByte(data, pos)]
                pos = pos + 1
            end
        end
    end

    return table.concat(out)
end

local function PackQuestBinary(quest)
    if type(quest) ~= "table" then return nil, "Invalid quest table" end
    local targets = quest.targets or {}
    local discoveries = quest.discoveries or {}
    if #targets == 0 and #discoveries == 0 then
        return nil, "Invalid quest table"
    end

    local dialogues = quest.dialogues or {}
    local compMsg = type(quest.completionMessage) == "string" and quest.completionMessage or ""
    local clue = type(quest.clue) == "string" and quest.clue or ""
    local lang = (type(quest.language) == "string" and quest.language ~= "" and quest.language:lower()) or GetClientLanguage()

    local flags = 0
    if quest.requireUndetected then flags = flags + 1 end
    if quest.hideMapArea then flags = flags + 2 end
    if #targets > 0 then flags = flags + 4 end
    if #discoveries > 0 then flags = flags + 8 end
    if #dialogues > 0 then flags = flags + 16 end
    if compMsg ~= "" then flags = flags + 32 end
    if clue ~= "" then flags = flags + 64 end
    if lang ~= "" then flags = flags + 128 end

    local buf = { BYTE_TO_CHAR[flags] }
    WriteStr(buf, quest.title or "")
    WriteStr(buf, quest.description or "")
    WriteUVarint(buf, quest.mapId or 0)
    WriteUVarint(buf, quest.zoneId or 0)
    WriteStr(buf, quest.mapName or "")

    local defaultRad = (Addon.Constants and Addon.Constants.DISCOVERY_RADIUS and Addon.Constants.DISCOVERY_RADIUS.MEDIUM) or 1500
    if #targets > 0 then
        WriteUInt16(buf, quest.targetX or 0.5)
        WriteUInt16(buf, quest.targetY or 0.5)
        WriteUInt16(buf, quest.areaCenterX or 0.5)
        WriteUInt16(buf, quest.areaCenterY or 0.5)
        WriteUInt16(buf, quest.areaRadius or 0.075)
        WriteUVarint(buf, #targets)
        for _, t in ipairs(targets) do
            local hasLoc = (t.worldX ~= nil and t.worldZ ~= nil)
            local reqLoc = (t.locationRequired == true)
            local tMsg = type(t.customMessage) == "string" and t.customMessage or ""
            local tFlags = (hasLoc and 1 or 0) + (reqLoc and 2 or 0) + (tMsg ~= "" and 4 or 0)
            buf[#buf + 1] = BYTE_TO_CHAR[tFlags]
            WriteStr(buf, t.name or "")
            WriteUVarint(buf, math.max(1, math.floor(tonumber(t.requiredCount) or 1)))
            if hasLoc then
                WriteUVarint(buf, t.zoneId or 0)
                WriteSVarint(buf, t.worldX)
                WriteSVarint(buf, t.worldZ)
                WriteUVarint(buf, math.max(100, math.floor(tonumber(t.radius) or defaultRad)))
            end
            if tMsg ~= "" then
                WriteStr(buf, tMsg)
            end
        end
    end

    if #discoveries > 0 then
        WriteUVarint(buf, #discoveries)
        for _, d in ipairs(discoveries) do
            WriteUVarint(buf, d.zoneId or 0)
            WriteSVarint(buf, d.worldX or 0)
            WriteSVarint(buf, d.worldY or 0)
            WriteSVarint(buf, d.worldZ or 0)
            WriteUVarint(buf, d.mapId or 0)
            WriteUInt16(buf, d.x or 0)
            WriteUInt16(buf, d.y or 0)
            WriteUVarint(buf, math.max(100, math.floor(tonumber(d.radius) or defaultRad)))
            WriteStr(buf, d.message or "")
        end
    end

    if #dialogues > 0 then
        local maxNpcs = (Addon.Constants and Addon.Constants.DIALOGUE and Addon.Constants.DIALOGUE.MAX_NPCS) or 3
        local count = math.min(#dialogues, maxNpcs)
        WriteUVarint(buf, count)
        for idx = 1, count do
            local dlg = dialogues[idx]
            WriteStr(buf, dlg.npcName or "")
            WriteUVarint(buf, dlg.zoneId or 0)
            WriteStr(buf, dlg.response or "")
        end
    end

    if compMsg ~= "" then WriteStr(buf, compMsg) end
    if clue ~= "" then WriteStr(buf, clue) end
    if lang ~= "" then WriteStr(buf, lang) end

    if #dialogues > 0 then
        local maxNpcs = (Addon.Constants and Addon.Constants.DIALOGUE and Addon.Constants.DIALOGUE.MAX_NPCS) or 3
        local count = math.min(#dialogues, maxNpcs)
        local hasPerNpcClue = false
        for idx = 1, count do
            if type(dialogues[idx].clue) == "string" and dialogues[idx].clue ~= "" then
                hasPerNpcClue = true
                break
            end
        end
        if hasPerNpcClue then
            for idx = 1, count do
                WriteStr(buf, dialogues[idx].clue or "")
            end
        end
    end

    return table.concat(buf)
end

local function UnpackQuestBinary(data)
    if type(data) ~= "string" or #data < 1 then return nil, "ERR_IMPORT_INCOMPLETE_DATA" end
    local len = #data
    local pos = 1
    local flags = string.byte(data, pos); pos = pos + 1
    local floor = math.floor
    local requireUndetected = (flags % 2) == 1
    local hideMapArea = (floor(flags / 2) % 2) == 1
    local hasTargets = (floor(flags / 4) % 2) == 1
    local hasDiscoveries = (floor(flags / 8) % 2) == 1
    local hasDialogues = (floor(flags / 16) % 2) == 1
    local hasCompMsg = (floor(flags / 32) % 2) == 1
    local hasClue = (floor(flags / 64) % 2) == 1
    local hasLang = (floor(flags / 128) % 2) == 1

    local title; title, pos = ReadStr(data, pos, len)
    local description; description, pos = ReadStr(data, pos, len)
    local mapId; mapId, pos = ReadUVarint(data, pos, len)
    local zoneId; zoneId, pos = ReadUVarint(data, pos, len)
    local mapName; mapName, pos = ReadStr(data, pos, len)
    if not title or not description or not mapId or not zoneId or not mapName then
        return nil, "ERR_IMPORT_INCOMPLETE_DATA"
    end

    local defaultRad = (Addon.Constants and Addon.Constants.DISCOVERY_RADIUS and Addon.Constants.DISCOVERY_RADIUS.MEDIUM) or 1500
    local targetX, targetY, areaCenterX, areaCenterY, areaRadius
    local decodedTargets = {}
    if hasTargets then
        targetX, pos = ReadUInt16(data, pos, len)
        targetY, pos = ReadUInt16(data, pos, len)
        areaCenterX, pos = ReadUInt16(data, pos, len)
        areaCenterY, pos = ReadUInt16(data, pos, len)
        areaRadius, pos = ReadUInt16(data, pos, len)
        local tCount; tCount, pos = ReadUVarint(data, pos, len)
        if not targetX or not areaRadius or not tCount then
            return nil, "ERR_IMPORT_INCOMPLETE_DATA"
        end
        for _ = 1, tCount do
            if pos > len then return nil, "ERR_IMPORT_INCOMPLETE_DATA" end
            local tFlags = string.byte(data, pos); pos = pos + 1
            local tHasLoc = (tFlags % 2) == 1
            local tReqLoc = (floor(tFlags / 2) % 2) == 1
            local tHasMsg = (floor(tFlags / 4) % 2) == 1
            local tName; tName, pos = ReadStr(data, pos, len)
            local tReq; tReq, pos = ReadUVarint(data, pos, len)
            if not tName or not tReq or tName == "" or tReq < 1 then
                return nil, "ERR_IMPORT_INCOMPLETE_DATA"
            end
            local tZone, tWX, tWZ, tRad
            if tHasLoc then
                tZone, pos = ReadUVarint(data, pos, len)
                tWX, pos = ReadSVarint(data, pos, len)
                tWZ, pos = ReadSVarint(data, pos, len)
                tRad, pos = ReadUVarint(data, pos, len)
                if not tZone or not tWX or not tWZ or not tRad then
                    return nil, "ERR_IMPORT_INCOMPLETE_DATA"
                end
            end
            local tMsg = ""
            if tHasMsg then
                tMsg, pos = ReadStr(data, pos, len)
                if not tMsg then return nil, "ERR_IMPORT_INCOMPLETE_DATA" end
            end
            table.insert(decodedTargets, {
                name = tName,
                currentCount = 0,
                requiredCount = math.max(1, math.floor(tReq)),
                zoneId = tHasLoc and math.floor(tZone) or nil,
                worldX = tHasLoc and tWX or nil,
                worldZ = tHasLoc and tWZ or nil,
                radius = tHasLoc and math.max(100, math.floor(tRad)) or nil,
                locationRequired = tReqLoc,
                customMessage = tMsg,
            })
        end
    end

    local decodedDiscoveries = {}
    if hasDiscoveries then
        local dCount; dCount, pos = ReadUVarint(data, pos, len)
        if not dCount then return nil, "ERR_IMPORT_INCOMPLETE_DATA" end
        for _ = 1, dCount do
            local dz; dz, pos = ReadUVarint(data, pos, len)
            local dwx; dwx, pos = ReadSVarint(data, pos, len)
            local dwy; dwy, pos = ReadSVarint(data, pos, len)
            local dwz; dwz, pos = ReadSVarint(data, pos, len)
            local dmap; dmap, pos = ReadUVarint(data, pos, len)
            local dx; dx, pos = ReadUInt16(data, pos, len)
            local dy; dy, pos = ReadUInt16(data, pos, len)
            local drad; drad, pos = ReadUVarint(data, pos, len)
            local dmsg; dmsg, pos = ReadStr(data, pos, len)
            if not dz or not dwx or not dwy or not dwz or not dmap or not dx or not dy or not drad or not dmsg then
                return nil, "ERR_IMPORT_INCOMPLETE_DATA"
            end
            table.insert(decodedDiscoveries, {
                zoneId = math.floor(dz),
                worldX = math.floor(dwx),
                worldY = math.floor(dwy),
                worldZ = math.floor(dwz),
                mapId = math.floor(dmap),
                x = dx,
                y = dy,
                radius = math.max(100, math.floor(drad or defaultRad)),
                message = dmsg,
                discovered = false,
            })
        end
    end

    local decodedDialogues = {}
    if hasDialogues then
        local dlgCount; dlgCount, pos = ReadUVarint(data, pos, len)
        if not dlgCount then return nil, "ERR_IMPORT_INCOMPLETE_DATA" end
        for _ = 1, dlgCount do
            local npc; npc, pos = ReadStr(data, pos, len)
            local dz; dz, pos = ReadUVarint(data, pos, len)
            local resp; resp, pos = ReadStr(data, pos, len)
            if not npc or not dz or not resp then
                return nil, "ERR_IMPORT_INCOMPLETE_DATA"
            end
            if npc ~= "" then
                table.insert(decodedDialogues, {
                    npcName = npc,
                    zoneId = math.floor(dz),
                    response = resp,
                })
            end
        end
    end

    local completionMessage = ""
    if hasCompMsg then
        completionMessage, pos = ReadStr(data, pos, len)
        if not completionMessage then return nil, "ERR_IMPORT_INCOMPLETE_DATA" end
    end
    local clue = ""
    if hasClue then
        clue, pos = ReadStr(data, pos, len)
        if not clue then return nil, "ERR_IMPORT_INCOMPLETE_DATA" end
    end
    local sourceLanguage = ""
    if hasLang then
        sourceLanguage, pos = ReadStr(data, pos, len)
        if not sourceLanguage then return nil, "ERR_IMPORT_INCOMPLETE_DATA" end
        sourceLanguage = sourceLanguage:lower()
    end

    if hasDialogues and pos <= len then
        for idx = 1, #decodedDialogues do
            local dClue
            dClue, pos = ReadStr(data, pos, len)
            if not dClue then return nil, "ERR_IMPORT_INCOMPLETE_DATA" end
            decodedDialogues[idx].clue = dClue
        end
    end

    if sourceLanguage ~= "" and sourceLanguage ~= GetClientLanguage() then
        return nil, "ERR_IMPORT_LANGUAGE_MISMATCH"
    end
    if #decodedTargets == 0 and #decodedDiscoveries == 0 then
        return nil, "ERR_IMPORT_INCOMPLETE_DATA"
    end
    if #decodedTargets > 0 and (not areaCenterX or not areaCenterY or not areaRadius or areaRadius <= 0) then
        return nil, "ERR_IMPORT_INCOMPLETE_DATA"
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
        language = (sourceLanguage ~= "" and sourceLanguage) or nil,
    }
end

function ShareCodec:EncodeQuest(quest)
    local rawBinary, err = PackQuestBinary(quest)
    if not rawBinary then
        return nil, err
    end

    local compressed = CompressLZSS(rawBinary)
    local prefix = Addon.Constants.SHARE_CODEC.PREFIX
    local checksum = ComputeChecksum16(compressed)
    local encodedPayload = Base85Encode(compressed)

    return string.format("%s:%s:%s", prefix, checksum, encodedPayload)
end

local function DecodeAndVerifyEnvelope(codeString, invalidFormatErr, badB64Err, badChecksumErr, allowedPrefixes, unknownPrefixErr)
    local trimmed = codeString:gsub("^%s+", ""):gsub("%s+$", "")
    local pfx, checksum, encodedPayload = string.match(trimmed, "^([A-Z0-9]+):([0-9A-Fa-f]+):([^%s]+)$")
    if not pfx or not checksum or #checksum ~= 4 or not encodedPayload then
        return nil, nil, invalidFormatErr
    end
    if allowedPrefixes then
        local errOrAllowed = allowedPrefixes[pfx]
        if errOrAllowed == nil then
            return nil, nil, unknownPrefixErr or invalidFormatErr
        elseif type(errOrAllowed) == "string" then
            return nil, nil, errOrAllowed
        end
    end
    if not string.match(encodedPayload, "^[A-Za-z0-9%-_]+$") then
        return nil, nil, badB64Err
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
        return nil, "ERR_IMPORT_EMPTY"
    end

    local trimmed = codeString:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed == "" then
        return nil, "ERR_IMPORT_EMPTY"
    end

    local prefix = Addon.Constants.SHARE_CODEC.PREFIX
    local legacyPrefixV2 = Addon.Constants.SHARE_CODEC.LEGACY_PREFIX_V2 or "RPQ2"
    local legacyPrefix = Addon.Constants.SHARE_CODEC.LEGACY_PREFIX or "RPQ1"
    local compPrefix = Addon.Constants.SHARE_CODEC.COMPLETION_PREFIX

    local rpqPrefix = string.match(trimmed, "^(RPQ%d+):")
    if rpqPrefix and rpqPrefix ~= prefix and rpqPrefix ~= legacyPrefixV2 and rpqPrefix ~= legacyPrefix then
        return nil, "ERR_IMPORT_UNSUPPORTED_VERSION"
    end

    if string.sub(trimmed, 1, #prefix + 1) == (prefix .. ":") then
        local pfx, checksum, encodedPayload = string.match(trimmed, "^([A-Z0-9]+):([0-9A-Fa-f]+):(.+)$")
        if not pfx or not checksum or #checksum ~= 4 or not encodedPayload or encodedPayload:find("%s") then
            return nil, "ERR_IMPORT_INVALID_FORMAT"
        end
        local compressed = Base85Decode(encodedPayload)
        if not compressed then
            return nil, "ERR_IMPORT_TRUNCATED_OR_CORRUPT"
        end
        local expectedChecksum = ComputeChecksum16(compressed)
        if checksum:upper() ~= expectedChecksum:upper() then
            return nil, "ERR_IMPORT_TRUNCATED_OR_CORRUPT"
        end
        local rawBinary = DecompressLZSS(compressed)
        if not rawBinary then
            return nil, "ERR_IMPORT_TRUNCATED_OR_CORRUPT"
        end
        return UnpackQuestBinary(rawBinary)
    end

    local _, rawPayload, envErr = DecodeAndVerifyEnvelope(
        trimmed,
        "ERR_IMPORT_INVALID_FORMAT",
        "ERR_IMPORT_TRUNCATED_OR_CORRUPT",
        "ERR_IMPORT_TRUNCATED_OR_CORRUPT",
        {
            [legacyPrefixV2] = true,
            [legacyPrefix] = true,
            [compPrefix] = "ERR_IMPORT_NOT_QUEST_CODE",
        },
        "ERR_IMPORT_UNSUPPORTED_VERSION"
    )
    if not rawPayload then
        return nil, envErr
    end

    local fields = SplitByChar(rawPayload, "|")
    if #fields < 11 then
        return nil, "ERR_IMPORT_INCOMPLETE_DATA"
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
    local sourceLanguage = fields[18] and UnescapeField(fields[18]):lower() or ""

    if sourceLanguage ~= "" and sourceLanguage ~= GetClientLanguage() then
        return nil, "ERR_IMPORT_LANGUAGE_MISMATCH"
    end

    if #decodedTargets == 0 and #decodedDiscoveries == 0 then
        return nil, "ERR_IMPORT_INCOMPLETE_DATA"
    end

    if #decodedTargets > 0 and (not areaCenterX or not areaCenterY or not areaRadius or areaRadius <= 0) then
        return nil, "ERR_IMPORT_INCOMPLETE_DATA"
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
        language = (sourceLanguage ~= "" and sourceLanguage) or nil,
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
    local legacyPrefixV2 = Addon.Constants.SHARE_CODEC.LEGACY_PREFIX_V2 or "RPQ2"
    local legacyPrefix = Addon.Constants.SHARE_CODEC.LEGACY_PREFIX or "RPQ1"
    local compPrefix = Addon.Constants.SHARE_CODEC.COMPLETION_PREFIX

    if string.sub(codeString:gsub("^%s+", ""), 1, #questPrefix + 1) == (questPrefix .. ":") then
        return nil, "VALIDATE_ERR_NOT_COMPLETION_CODE"
    end

    local _, rawPayload, envErr = DecodeAndVerifyEnvelope(
        codeString,
        "VALIDATE_ERR_INVALID_CODE",
        "VALIDATE_ERR_INVALID_CODE",
        "VALIDATE_ERR_INVALID_CODE",
        {
            [compPrefix] = true,
            [legacyPrefixV2] = "VALIDATE_ERR_NOT_COMPLETION_CODE",
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
