-- Ref: docs/adr/0002-modelo-de-dominio-captura-y-codec-de-comparticion.md
-- Ref: docs/adr/0004-objetivos-multiples-inferidos-por-reticula.md
-- Ref: docs/adr/0006-puntos-de-descubrimiento-ocultos.md
-- Ref: docs/adr/0007-dialogos-inyectados-en-npcs-nativos.md
-- Ref: docs/adr/0008-codec-compacto-rpq3-lzss-base85.md

RPQuest = RPQuest or {}
local Addon = RPQuest

Addon.ShareCodec = {}
local ShareCodec = Addon.ShareCodec
local BinaryCodec = Addon.BinaryCodec

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
            local isOpt = (t.optional == true)
            local msg = type(t.customMessage) == "string" and t.customMessage or ""
            if hasLoc or reqLoc or msg ~= "" or isOpt then
                local parts = {
                    EscapeField(t.name),
                    tostring(req),
                    hasLoc and tostring(math.floor(tonumber(t.zoneId) or 0)) or "",
                    hasLoc and tostring(math.floor(tonumber(t.worldX))) or "",
                    hasLoc and tostring(math.floor(tonumber(t.worldZ))) or "",
                    hasLoc and tostring(math.max(100, math.floor(tonumber(t.radius) or defaultRad))) or "",
                    reqLoc and "1" or "0",
                    EscapeField(msg),
                    isOpt and "1" or "0",
                }
                table.insert(items, table.concat(parts, "~"))
            else
                table.insert(items, EscapeField(t.name) .. "~" .. tostring(req))
            end
        end
    end
    return table.concat(items, ";")
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

local function PackTargetsBlock(buf, quest, targets, defaultRad)
    BinaryCodec:WriteUInt16(buf, quest.targetX or 0.5)
    BinaryCodec:WriteUInt16(buf, quest.targetY or 0.5)
    BinaryCodec:WriteUInt16(buf, quest.areaCenterX or 0.5)
    BinaryCodec:WriteUInt16(buf, quest.areaCenterY or 0.5)
    BinaryCodec:WriteUInt16(buf, quest.areaRadius or 0.075)
    BinaryCodec:WriteUVarint(buf, #targets)
    for _, t in ipairs(targets) do
        local hasLoc = (t.worldX ~= nil and t.worldZ ~= nil)
        local reqLoc = (t.locationRequired == true)
        local isOpt = (t.optional == true)
        local tMsg = type(t.customMessage) == "string" and t.customMessage or ""
        local tFlags = (hasLoc and 1 or 0) + (reqLoc and 2 or 0) + (tMsg ~= "" and 4 or 0) + (isOpt and 8 or 0)
        BinaryCodec:WriteByte(buf, tFlags)
        BinaryCodec:WriteStr(buf, t.name or "")
        BinaryCodec:WriteUVarint(buf, math.max(1, math.floor(tonumber(t.requiredCount) or 1)))
        if hasLoc then
            BinaryCodec:WriteUVarint(buf, t.zoneId or 0)
            BinaryCodec:WriteSVarint(buf, t.worldX)
            BinaryCodec:WriteSVarint(buf, t.worldZ)
            BinaryCodec:WriteUVarint(buf, math.max(100, math.floor(tonumber(t.radius) or defaultRad)))
        end
        if tMsg ~= "" then
            BinaryCodec:WriteStr(buf, tMsg)
        end
    end
end

local function PackDiscoveriesBlock(buf, discoveries, defaultRad)
    BinaryCodec:WriteUVarint(buf, #discoveries)
    for _, d in ipairs(discoveries) do
        BinaryCodec:WriteUVarint(buf, d.zoneId or 0)
        BinaryCodec:WriteSVarint(buf, d.worldX or 0)
        BinaryCodec:WriteSVarint(buf, d.worldY or 0)
        BinaryCodec:WriteSVarint(buf, d.worldZ or 0)
        BinaryCodec:WriteUVarint(buf, d.mapId or 0)
        BinaryCodec:WriteUInt16(buf, d.x or 0)
        BinaryCodec:WriteUInt16(buf, d.y or 0)
        BinaryCodec:WriteUVarint(buf, math.max(100, math.floor(tonumber(d.radius) or defaultRad)))
        BinaryCodec:WriteStr(buf, d.message or "")
    end
end

local function PackDialoguesBlock(buf, dialogues)
    local maxNpcs = (Addon.Constants and Addon.Constants.DIALOGUE and Addon.Constants.DIALOGUE.MAX_NPCS) or 3
    local count = math.min(#dialogues, maxNpcs)
    BinaryCodec:WriteUVarint(buf, count)
    for idx = 1, count do
        local dlg = dialogues[idx]
        BinaryCodec:WriteStr(buf, dlg.npcName or "")
        BinaryCodec:WriteUVarint(buf, dlg.zoneId or 0)
        BinaryCodec:WriteStr(buf, dlg.response or "")
    end
end

local function PackDialogueCluesBlock(buf, dialogues, forceWrite)
    local maxNpcs = (Addon.Constants and Addon.Constants.DIALOGUE and Addon.Constants.DIALOGUE.MAX_NPCS) or 3
    local count = math.min(#dialogues, maxNpcs)
    local hasPerNpcClue = forceWrite and true or false
    if not hasPerNpcClue then
        for idx = 1, count do
            if type(dialogues[idx].clue) == "string" and dialogues[idx].clue ~= "" then
                hasPerNpcClue = true
                break
            end
        end
    end
    if hasPerNpcClue then
        for idx = 1, count do
            BinaryCodec:WriteStr(buf, dialogues[idx].clue or "")
        end
    end
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

    local buf = {}
    BinaryCodec:WriteByte(buf, flags)
    BinaryCodec:WriteStr(buf, quest.title or "")
    BinaryCodec:WriteStr(buf, quest.description or "")
    BinaryCodec:WriteUVarint(buf, quest.mapId or 0)
    BinaryCodec:WriteUVarint(buf, quest.zoneId or 0)
    BinaryCodec:WriteStr(buf, quest.mapName or "")

    local defaultRad = (Addon.Constants and Addon.Constants.DISCOVERY_RADIUS and Addon.Constants.DISCOVERY_RADIUS.MEDIUM) or 1500
    if #targets > 0 then
        PackTargetsBlock(buf, quest, targets, defaultRad)
    end
    if #discoveries > 0 then
        PackDiscoveriesBlock(buf, discoveries, defaultRad)
    end
    if #dialogues > 0 then
        PackDialoguesBlock(buf, dialogues)
    end

    if compMsg ~= "" then BinaryCodec:WriteStr(buf, compMsg) end
    if clue ~= "" then BinaryCodec:WriteStr(buf, clue) end
    if lang ~= "" then BinaryCodec:WriteStr(buf, lang) end

    local senderChar = (type(quest.senderCharacterName) == "string") and quest.senderCharacterName or ""
    local recipientChar = (type(quest.recipientCharacterName) == "string") and quest.recipientCharacterName or ""
    local hasCharNames = (senderChar ~= "" or recipientChar ~= "")

    if #dialogues > 0 then
        PackDialogueCluesBlock(buf, dialogues, hasCharNames)
    end

    if hasCharNames then
        BinaryCodec:WriteStr(buf, senderChar)
        BinaryCodec:WriteStr(buf, recipientChar)
    end

    return table.concat(buf)
end

local function UnpackTargetsBlock(data, pos, len)
    local targetX; targetX, pos = BinaryCodec:ReadUInt16(data, pos, len)
    local targetY; targetY, pos = BinaryCodec:ReadUInt16(data, pos, len)
    local areaCenterX; areaCenterX, pos = BinaryCodec:ReadUInt16(data, pos, len)
    local areaCenterY; areaCenterY, pos = BinaryCodec:ReadUInt16(data, pos, len)
    local areaRadius; areaRadius, pos = BinaryCodec:ReadUInt16(data, pos, len)
    local tCount; tCount, pos = BinaryCodec:ReadUVarint(data, pos, len)
    if not targetX or not areaRadius or not tCount then
        return nil, "ERR_IMPORT_INCOMPLETE_DATA"
    end

    local floor = math.floor
    local decodedTargets = {}
    for _ = 1, tCount do
        local tFlags; tFlags, pos = BinaryCodec:ReadByte(data, pos, len)
        if not tFlags then return nil, "ERR_IMPORT_INCOMPLETE_DATA" end
        local tHasLoc = (tFlags % 2) == 1
        local tReqLoc = (floor(tFlags / 2) % 2) == 1
        local tHasMsg = (floor(tFlags / 4) % 2) == 1
        local tOptional = (floor(tFlags / 8) % 2) == 1
        local tName; tName, pos = BinaryCodec:ReadStr(data, pos, len)
        local tReq; tReq, pos = BinaryCodec:ReadUVarint(data, pos, len)
        if not tName or not tReq or tName == "" or tReq < 1 then
            return nil, "ERR_IMPORT_INCOMPLETE_DATA"
        end
        local tZone, tWX, tWZ, tRad
        if tHasLoc then
            tZone, pos = BinaryCodec:ReadUVarint(data, pos, len)
            tWX, pos = BinaryCodec:ReadSVarint(data, pos, len)
            tWZ, pos = BinaryCodec:ReadSVarint(data, pos, len)
            tRad, pos = BinaryCodec:ReadUVarint(data, pos, len)
            if not tZone or not tWX or not tWZ or not tRad then
                return nil, "ERR_IMPORT_INCOMPLETE_DATA"
            end
        end
        local tMsg = ""
        if tHasMsg then
            tMsg, pos = BinaryCodec:ReadStr(data, pos, len)
            if not tMsg then return nil, "ERR_IMPORT_INCOMPLETE_DATA" end
        end
        table.insert(decodedTargets, {
            name = tName,
            currentCount = 0,
            requiredCount = math.max(1, floor(tReq)),
            zoneId = tHasLoc and floor(tZone) or nil,
            worldX = tHasLoc and tWX or nil,
            worldZ = tHasLoc and tWZ or nil,
            radius = tHasLoc and math.max(100, floor(tRad)) or nil,
            locationRequired = tReqLoc,
            optional = tOptional,
            customMessage = tMsg,
        })
    end

    return {
        targets = decodedTargets,
        targetX = targetX,
        targetY = targetY,
        areaCenterX = areaCenterX,
        areaCenterY = areaCenterY,
        areaRadius = areaRadius,
    }, pos
end

local function UnpackDiscoveriesBlock(data, pos, len, defaultRad)
    local dCount; dCount, pos = BinaryCodec:ReadUVarint(data, pos, len)
    if not dCount then return nil, "ERR_IMPORT_INCOMPLETE_DATA" end
    local decodedDiscoveries = {}
    for _ = 1, dCount do
        local dz; dz, pos = BinaryCodec:ReadUVarint(data, pos, len)
        local dwx; dwx, pos = BinaryCodec:ReadSVarint(data, pos, len)
        local dwy; dwy, pos = BinaryCodec:ReadSVarint(data, pos, len)
        local dwz; dwz, pos = BinaryCodec:ReadSVarint(data, pos, len)
        local dmap; dmap, pos = BinaryCodec:ReadUVarint(data, pos, len)
        local dx; dx, pos = BinaryCodec:ReadUInt16(data, pos, len)
        local dy; dy, pos = BinaryCodec:ReadUInt16(data, pos, len)
        local drad; drad, pos = BinaryCodec:ReadUVarint(data, pos, len)
        local dmsg; dmsg, pos = BinaryCodec:ReadStr(data, pos, len)
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
    return decodedDiscoveries, pos
end

local function UnpackDialoguesBlock(data, pos, len)
    local dlgCount; dlgCount, pos = BinaryCodec:ReadUVarint(data, pos, len)
    if not dlgCount then return nil, "ERR_IMPORT_INCOMPLETE_DATA" end
    local decodedDialogues = {}
    for _ = 1, dlgCount do
        local npc; npc, pos = BinaryCodec:ReadStr(data, pos, len)
        local dz; dz, pos = BinaryCodec:ReadUVarint(data, pos, len)
        local resp; resp, pos = BinaryCodec:ReadStr(data, pos, len)
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
    return decodedDialogues, pos
end

local function UnpackDialogueCluesBlock(data, pos, len, decodedDialogues)
    for idx = 1, #decodedDialogues do
        local dClue
        dClue, pos = BinaryCodec:ReadStr(data, pos, len)
        if not dClue then return nil, "ERR_IMPORT_INCOMPLETE_DATA" end
        if dClue ~= "" then
            decodedDialogues[idx].clue = dClue
        end
    end
    return true, pos
end

local function UnpackQuestBinary(data)
    if type(data) ~= "string" or #data < 1 then return nil, "ERR_IMPORT_INCOMPLETE_DATA" end
    local len = #data
    local flags, pos = BinaryCodec:ReadByte(data, 1, len)
    local floor = math.floor
    local requireUndetected = (flags % 2) == 1
    local hideMapArea = (floor(flags / 2) % 2) == 1
    local hasTargets = (floor(flags / 4) % 2) == 1
    local hasDiscoveries = (floor(flags / 8) % 2) == 1
    local hasDialogues = (floor(flags / 16) % 2) == 1
    local hasCompMsg = (floor(flags / 32) % 2) == 1
    local hasClue = (floor(flags / 64) % 2) == 1
    local hasLang = (floor(flags / 128) % 2) == 1

    local title; title, pos = BinaryCodec:ReadStr(data, pos, len)
    local description; description, pos = BinaryCodec:ReadStr(data, pos, len)
    local mapId; mapId, pos = BinaryCodec:ReadUVarint(data, pos, len)
    local zoneId; zoneId, pos = BinaryCodec:ReadUVarint(data, pos, len)
    local mapName; mapName, pos = BinaryCodec:ReadStr(data, pos, len)
    if not title or not description or not mapId or not zoneId or not mapName then
        return nil, "ERR_IMPORT_INCOMPLETE_DATA"
    end

    local defaultRad = (Addon.Constants and Addon.Constants.DISCOVERY_RADIUS and Addon.Constants.DISCOVERY_RADIUS.MEDIUM) or 1500
    local targetsResult
    local decodedTargets = {}
    if hasTargets then
        targetsResult, pos = UnpackTargetsBlock(data, pos, len)
        if not targetsResult then return nil, pos end
        decodedTargets = targetsResult.targets
    end

    local decodedDiscoveries = {}
    if hasDiscoveries then
        decodedDiscoveries, pos = UnpackDiscoveriesBlock(data, pos, len, defaultRad)
        if not decodedDiscoveries then return nil, pos end
    end

    local decodedDialogues = {}
    if hasDialogues then
        decodedDialogues, pos = UnpackDialoguesBlock(data, pos, len)
        if not decodedDialogues then return nil, pos end
    end

    local completionMessage = ""
    if hasCompMsg then
        completionMessage, pos = BinaryCodec:ReadStr(data, pos, len)
        if not completionMessage then return nil, "ERR_IMPORT_INCOMPLETE_DATA" end
    end
    local clue = ""
    if hasClue then
        clue, pos = BinaryCodec:ReadStr(data, pos, len)
        if not clue then return nil, "ERR_IMPORT_INCOMPLETE_DATA" end
    end
    local sourceLanguage = ""
    if hasLang then
        sourceLanguage, pos = BinaryCodec:ReadStr(data, pos, len)
        if not sourceLanguage then return nil, "ERR_IMPORT_INCOMPLETE_DATA" end
        sourceLanguage = sourceLanguage:lower()
    end

    if hasDialogues and pos <= len then
        local okClues
        okClues, pos = UnpackDialogueCluesBlock(data, pos, len, decodedDialogues)
        if not okClues then return nil, pos end
    end

    local senderCharacterName = ""
    local recipientCharacterName = ""
    if pos <= len then
        local sc, nextPos = BinaryCodec:ReadStr(data, pos, len)
        if sc then
            senderCharacterName = sc
            pos = nextPos
        end
    end
    if pos <= len then
        local rc = BinaryCodec:ReadStr(data, pos, len)
        if rc then
            recipientCharacterName = rc
        end
    end

    if sourceLanguage ~= "" and sourceLanguage ~= GetClientLanguage() then
        return nil, "ERR_IMPORT_LANGUAGE_MISMATCH"
    end
    if #decodedTargets == 0 and #decodedDiscoveries == 0 then
        return nil, "ERR_IMPORT_INCOMPLETE_DATA"
    end
    local areaCenterX = targetsResult and targetsResult.areaCenterX or nil
    local areaCenterY = targetsResult and targetsResult.areaCenterY or nil
    local areaRadius = targetsResult and targetsResult.areaRadius or nil
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
        mapId = floor(mapId or 0),
        zoneId = floor(zoneId or 0),
        mapName = mapName,
        targetX = (#decodedTargets > 0) and (targetsResult.targetX or areaCenterX) or nil,
        targetY = (#decodedTargets > 0) and (targetsResult.targetY or areaCenterY) or nil,
        areaCenterX = (#decodedTargets > 0) and areaCenterX or nil,
        areaCenterY = (#decodedTargets > 0) and areaCenterY or nil,
        areaRadius = areaRadius or 0.075,
        hideMapArea = hideMapArea,
        requireUndetected = requireUndetected,
        language = (sourceLanguage ~= "" and sourceLanguage) or nil,
        senderCharacterName = (senderCharacterName ~= "" and senderCharacterName) or nil,
        recipientCharacterName = (recipientCharacterName ~= "" and recipientCharacterName) or nil,
    }
end

function ShareCodec:EncodeQuest(quest)
    local rawBinary, err = PackQuestBinary(quest)
    if not rawBinary then
        return nil, err
    end

    local compressed = BinaryCodec:CompressLZSS(rawBinary)
    local prefix = Addon.Constants.SHARE_CODEC.PREFIX
    local checksum = ComputeChecksum16(compressed)
    local encodedPayload = BinaryCodec:Base85Encode(compressed)

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

    local rawPayload = BinaryCodec:Base64UrlDecode(encodedPayload)
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
    local compPrefix = Addon.Constants.SHARE_CODEC.COMPLETION_PREFIX

    if string.sub(trimmed, 1, #compPrefix + 1) == (compPrefix .. ":") then
        return nil, "ERR_IMPORT_NOT_QUEST_CODE"
    end

    local rpqPrefix = string.match(trimmed, "^(RPQ%d+):")
    if rpqPrefix and rpqPrefix ~= prefix then
        return nil, "ERR_IMPORT_UNSUPPORTED_VERSION"
    end

    if string.sub(trimmed, 1, #prefix + 1) ~= (prefix .. ":") then
        return nil, "ERR_IMPORT_INVALID_FORMAT"
    end

    local pfx, checksum, encodedPayload = string.match(trimmed, "^([A-Z0-9]+):([0-9A-Fa-f]+):(.+)$")
    if not pfx or not checksum or #checksum ~= 4 or not encodedPayload or encodedPayload:find("%s") then
        return nil, "ERR_IMPORT_INVALID_FORMAT"
    end
    local compressed = BinaryCodec:Base85Decode(encodedPayload)
    if not compressed then
        return nil, "ERR_IMPORT_TRUNCATED_OR_CORRUPT"
    end
    local expectedChecksum = ComputeChecksum16(compressed)
    if checksum:upper() ~= expectedChecksum:upper() then
        return nil, "ERR_IMPORT_TRUNCATED_OR_CORRUPT"
    end
    local rawBinary = BinaryCodec:DecompressLZSS(compressed)
    if not rawBinary then
        return nil, "ERR_IMPORT_TRUNCATED_OR_CORRUPT"
    end
    local quest, err = UnpackQuestBinary(rawBinary)
    if quest and Addon.QuestMigration then
        Addon.QuestMigration:MigrateQuestRecord(quest)
    end
    return quest, err
end

function ShareCodec:ComputeQuestSignature(quest)
    local rawPayload, err = BuildQuestPayloadString(quest)
    if not rawPayload then
        return nil, err
    end
    return ComputeSignature32(rawPayload)
end

local function EncodeResultCode(quest, characterName, timestamp, resultType)
    if type(quest) ~= "table" then
        return nil, "Invalid quest"
    end
    local kind = resultType
    if type(resultType) == "boolean" then
        kind = resultType and "completed" or "rejected"
    end
    if kind == "completed" and not quest.completed then
        return nil, "Quest is not completed"
    end

    if type(characterName) ~= "string" then
        return nil, "Invalid character name"
    end
    local cleanName = characterName:gsub("^%s+", ""):gsub("%s+$", "")
    if cleanName == "" then
        return nil, "Invalid character name"
    end

    local signature, err = ShareCodec:ComputeQuestSignature(quest)
    if not signature then
        return nil, err
    end

    local ts = math.max(0, math.floor(tonumber(timestamp) or 0))
    local stealthFlag = ""
    if kind == "completed" and quest.requireUndetected then
        stealthFlag = quest.wasDetected and "1" or "0"
    end
    local optionalFlag = ""
    if kind == "completed" and type(quest.targets) == "table" then
        local optBits = {}
        for _, t in ipairs(quest.targets) do
            if t.optional == true then
                local done = (t.currentCount or 0) >= (t.requiredCount or 1)
                table.insert(optBits, done and "1" or "0")
            end
        end
        if #optBits > 0 then
            optionalFlag = table.concat(optBits)
        end
    end
    local resultFlag = "0"
    if kind == "completed" then
        resultFlag = "1"
    elseif kind == "accepted" then
        resultFlag = "2"
    end
    local rawPayload = table.concat({
        signature,
        EscapeField(cleanName),
        resultFlag,
        tostring(ts),
        stealthFlag,
        optionalFlag,
    }, "|")

    local prefix = Addon.Constants.SHARE_CODEC.COMPLETION_PREFIX
    local checksum = ComputeChecksum16(rawPayload)
    local encodedPayload = BinaryCodec:Base64UrlEncode(rawPayload)

    return string.format("%s:%s:%s", prefix, checksum, encodedPayload)
end

function ShareCodec:EncodeCompletion(quest, characterName, completedAt)
    return EncodeResultCode(quest, characterName, completedAt, "completed")
end

function ShareCodec:EncodeRejection(quest, characterName, rejectedAt)
    return EncodeResultCode(quest, characterName, rejectedAt, "rejected")
end

function ShareCodec:EncodeAcceptance(quest, characterName, acceptedAt)
    return EncodeResultCode(quest, characterName, acceptedAt, "accepted")
end

function ShareCodec:DecodeCompletion(codeString)
    if type(codeString) ~= "string" then
        return nil, "VALIDATE_ERR_INVALID_CODE"
    end

    local questPrefix = Addon.Constants.SHARE_CODEC.PREFIX
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
    local flag = fields[3]
    local resultType
    if flag == "1" then
        resultType = "completed"
    elseif flag == "0" then
        resultType = "rejected"
    elseif flag == "2" then
        resultType = "accepted"
    else
        return nil, "VALIDATE_ERR_INVALID_CODE"
    end
    local completed = (resultType == "completed")
    local completedAt = tonumber(fields[4]) or 0
    local wasDetected = nil
    if fields[5] == "1" then
        wasDetected = true
    elseif fields[5] == "0" then
        wasDetected = false
    end
    local optionalTargets = nil
    local rawOpt = fields[6]
    if type(rawOpt) == "string" and rawOpt ~= "" then
        optionalTargets = {}
        for i = 1, #rawOpt do
            optionalTargets[i] = (string.sub(rawOpt, i, i) == "1")
        end
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
        rejected = (resultType == "rejected"),
        accepted = (resultType == "accepted"),
        resultType = resultType,
        completedAt = math.max(0, math.floor(completedAt)),
        wasDetected = wasDetected,
        optionalTargets = optionalTargets,
    }
end

function ShareCodec:ValidateResultForQuest(quest, codeString)
    local expectedSignature, sigErr = self:ComputeQuestSignature(quest)
    if not expectedSignature then
        return false, "VALIDATE_ERR_INVALID_CODE", sigErr
    end

    local decoded, errKey = self:DecodeCompletion(codeString)
    if not decoded then
        return false, errKey
    end

    if decoded.questSignature ~= expectedSignature then
        return false, "VALIDATE_ERR_WRONG_QUEST"
    end

    return true, decoded
end

function ShareCodec:ValidateCompletionForQuest(quest, codeString)
    local ok, resOrErr, extra = self:ValidateResultForQuest(quest, codeString)
    if not ok then
        return false, resOrErr, extra
    end

    if not resOrErr.completed then
        return false, "VALIDATE_ERR_NOT_COMPLETED"
    end

    return true, resOrErr
end
