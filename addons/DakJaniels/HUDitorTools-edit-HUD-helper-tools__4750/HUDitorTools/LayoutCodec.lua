-- -----------------------------------------------------------------------------
-- HUDitorTools - compact HUDT share-string codec
-- Observed parsers: zo_tokenize / zo_strjoin in EsoUI/Libraries/Globals/globalapi.lua
-- Record layout is append-only; bump HUDT_FORMAT_VERSION only if the header/record shape changes.
-- The integer saveKey dictionary is append-only (new ZOS names go at the end).
-- -----------------------------------------------------------------------------
local HT = HUDitorTools

HT.HUDT_FORMAT_VERSION = 3
HT.HUDT_FORMAT_VERSION_V1 = 1
HT.HUDT_FORMAT_VERSION_V2 = 2
HT.HUDT_MAGIC = "HUDT"

-- Offset precision matches ZO_HUDManager:SaveAnchorOffsets (hudmanager.lua)
local OFFSET_PRECISION = 0.00001

-- Known SeparatedTrackers bits from GetHUDElementOptionKeys() in ZOS tracker files.
-- First seven match the U51 dump; Adventure is appended (adventurezonehudtracker.lua).
local SEPARATED_TRACKER_BIT_KEYS =
{
    "Dynamic",
    "Quest",
    "Generic",
    "Aspiration",
    "House",
    "Infinite",
    "Activity",
    "Adventure",
}

-- ZOS saveKey = control:GetName() (ZO_HUDManager_Element:Initialize).
-- Addon / unknown names encode as @ControlName and are not required to be listed here.
local SAVE_KEY_BY_ID =
{
    "ZO_ActionBar1",
    "ZO_ActiveCombatTipsTip",
    "ZO_ActivityTracker",
    "ZO_AdvZoneHUD_TopLevelPlayerScoreContainer",
    "ZO_AdvZoneHUDTracker",
    "ZO_AlertTextNotification",
    "ZO_AlertTextNotificationGamepad",
    "ZO_BuffDebuffTopLevelSelfContainer",
    "ZO_BuffDebuffTopLevelTargetContainer",
    "ZO_CenterScreenAnnounce",
    "ZO_ChatWindowMinBar",
    "ZO_CompassFrame",
    "ZO_DynamicEventsTracker_TL",
    "ZO_EndDunHUDTracker",
    "ZO_EndlessDungeonHUD_TopLevelScoreContainer",
    "ZO_FocusedQuestTrackerPanel",
    "ZO_GamepadTextChat",
    "ZO_GenSelectHUDTracker",
    "ZO_HUDDaedricEnergyMeterTopLevel",
    "ZO_HUDEquipmentStatus",
    "ZO_HUDInfamyMeter",
    "ZO_HUDRaidLifeReservoir",
    "ZO_HUDTelvarMeter",
    "ZO_HUDTrackers",
    "ZO_HouseInformationTrackerTopLevel",
    "ZO_HousingHUDFragmentTopLevelKeybindButton",
    "ZO_LargeGroupAnchorFrame1",
    "ZO_LargeGroupAnchorFrame2",
    "ZO_LargeGroupAnchorFrame3",
    "ZO_LargeGroupAnchorFrame4",
    "ZO_LargeGroupAnchorFrame5",
    "ZO_LargeGroupAnchorFrame6",
    "ZO_LootHistoryControl_Gamepad",
    "ZO_LootHistoryControl_Keyboard",
    "ZO_ObjectiveCaptureMeter",
    "ZO_PlayerAttribute",
    "ZO_PlayerAttributeHealth",
    "ZO_PlayerAttributeMagicka",
    "ZO_PlayerAttributeStamina",
    "ZO_PlayerToPlayerAreaPromptContainer",
    "ZO_SmallGroupAnchorFrame",
    "ZO_Subtitles",
    "ZO_SynergyTopLevelContainer",
    "ZO_TargetUnitFramereticleover",
    "ZO_TimedActivityTracker_TL",
    "ZO_TutorialHudInfoTipGamepad",
    "ZO_TutorialHudInfoTipKeyboard",
    "ZO_BattlegroundHUDFragmentTopLevel",
    "ZO_PlayerProgress",
    "ZO_RamTopLevel",
    "ZO_ReticleContainerInteract",
    "ZO_ReticleContainerReticle",
    "ZO_ReticleContainerStealthIcon",
}

local SAVE_KEY_ID_BY_NAME = {}
for saveKeyId, saveKey in ipairs(SAVE_KEY_BY_ID) do
    SAVE_KEY_ID_BY_NAME[saveKey] = saveKeyId
end

local SEPARATED_TRACKER_BIT_BY_KEY = {}
for bitIndex, trackerKey in ipairs(SEPARATED_TRACKER_BIT_KEYS) do
    SEPARATED_TRACKER_BIT_BY_KEY[trackerKey] = bitIndex
end

local function FormatOffsetToken(value)
    local numberValue = tonumber(value) or 0
    numberValue = zo_roundToNearest(numberValue, OFFSET_PRECISION)
    local text = string.format("%.5f", numberValue)
    text = zo_strgsub(text, "0+$", "")
    text = zo_strgsub(text, "%.$", "")
    if text == "-0" then
        text = "0"
    end
    if text == "" then
        text = "0"
    end
    return text
end

local function FormatNumberToken(value)
    if type(value) == "boolean" then
        if value then
            return "1"
        end
        return "0"
    end
    local numberValue = tonumber(value)
    if numberValue == nil then
        return nil
    end
    if numberValue == zo_floor(numberValue) and math.abs(numberValue) < 1000000000 then
        return tostring(zo_floor(numberValue))
    end
    return FormatOffsetToken(numberValue)
end

local function EscapeTextToken(text)
    text = tostring(text or "")
    text = string.gsub(text, "\\", "\\\\")
    text = string.gsub(text, " ", "\\s")
    if text == "" then
        return "-"
    end
    return text
end

local function UnescapeTextToken(token)
    if token == nil or token == "-" then
        return ""
    end
    local placeholder = "\1"
    token = string.gsub(token, "\\\\", placeholder)
    token = string.gsub(token, "\\s", " ")
    token = string.gsub(token, placeholder, "\\")
    return token
end

local function EncodeSaveKeyToken(saveKey)
    local saveKeyId = SAVE_KEY_ID_BY_NAME[saveKey]
    if saveKeyId then
        return tostring(saveKeyId)
    end
    return "@" .. tostring(saveKey)
end

local function DecodeSaveKeyToken(token)
    if token == nil or token == "" then
        return nil, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_SAVEKEY)
    end
    local prefix = zo_strsub(token, 1, 1)
    if prefix == "@" then
        local saveKey = zo_strsub(token, 2)
        if saveKey == nil or saveKey == "" then
            return nil, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_SAVEKEY)
        end
        return saveKey, nil
    end
    local saveKeyId = tonumber(token)
    if saveKeyId == nil or saveKeyId ~= zo_floor(saveKeyId) then
        return nil, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_SAVEKEY)
    end
    local saveKey = SAVE_KEY_BY_ID[saveKeyId]
    if saveKey == nil then
        return nil, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_SAVEKEY)
    end
    return saveKey, nil
end

local function SetNestedValue(rootTable, dottedPath, value)
    local keys = {}
    for keyPart in zo_strgmatch(dottedPath, "[^.]+") do
        keys[#keys + 1] = keyPart
    end
    if #keys == 0 then
        return false
    end
    local currentTable = rootTable
    for keyIndex = 1, #keys - 1 do
        local keyPart = keys[keyIndex]
        if type(currentTable[keyPart]) ~= "table" then
            currentTable[keyPart] = {}
        end
        currentTable = currentTable[keyPart]
    end
    local leafKey = keys[#keys]
    if #keys > 1 then
        if value == 1 then
            currentTable[leafKey] = true
        elseif value == 0 then
            currentTable[leafKey] = false
        else
            currentTable[leafKey] = value
        end
    else
        currentTable[leafKey] = value
    end
    return true
end

local function AppendSeparatedTrackersExtras(extraTokens, separatedTrackers)
    local bitMask = 0
    local leftoverKeys = {}
    for trackerKey, trackerValue in pairs(separatedTrackers) do
        local bitIndex = SEPARATED_TRACKER_BIT_BY_KEY[trackerKey]
        if bitIndex then
            if trackerValue then
                bitMask = bitMask + (2 ^ (bitIndex - 1))
            end
        else
            leftoverKeys[#leftoverKeys + 1] = trackerKey
        end
    end
    if bitMask > 0 then
        extraTokens[#extraTokens + 1] = "ST"
        extraTokens[#extraTokens + 1] = tostring(zo_floor(bitMask))
    end
    table.sort(leftoverKeys)
    for _, trackerKey in ipairs(leftoverKeys) do
        local valueToken = FormatNumberToken(separatedTrackers[trackerKey])
        if valueToken then
            extraTokens[#extraTokens + 1] = "@SeparatedTrackers." .. trackerKey
            extraTokens[#extraTokens + 1] = valueToken
        end
    end
end

local function AppendTableExtras(extraTokens, optionTable, pathPrefix)
    local optionKeys = {}
    for optionKey in pairs(optionTable) do
        optionKeys[#optionKeys + 1] = optionKey
    end
    table.sort(optionKeys)
    for _, optionKey in ipairs(optionKeys) do
        local optionValue = optionTable[optionKey]
        local optionPath = pathPrefix .. optionKey
        local valueType = type(optionValue)
        if valueType == "table" then
            AppendTableExtras(extraTokens, optionValue, optionPath .. ".")
        else
            local valueToken = FormatNumberToken(optionValue)
            if valueToken then
                extraTokens[#extraTokens + 1] = "@" .. optionPath
                extraTokens[#extraTokens + 1] = valueToken
            end
        end
    end
end

local function EncodeElementExtras(elementRow)
    local extraTokens = {}
    local optionKeys = {}
    for optionKey in pairs(elementRow) do
        if optionKey ~= "offsetX" and optionKey ~= "offsetY" then
            optionKeys[#optionKeys + 1] = optionKey
        end
    end
    table.sort(optionKeys)
    for _, optionKey in ipairs(optionKeys) do
        local optionValue = elementRow[optionKey]
        if optionKey == "SeparatedTrackers" and type(optionValue) == "table" then
            AppendSeparatedTrackersExtras(extraTokens, optionValue)
        elseif type(optionValue) == "table" then
            AppendTableExtras(extraTokens, optionValue, optionKey .. ".")
        else
            local valueToken = FormatNumberToken(optionValue)
            if valueToken then
                extraTokens[#extraTokens + 1] = "@" .. optionKey
                extraTokens[#extraTokens + 1] = valueToken
            end
        end
    end
    return extraTokens
end

local function EncodeElementMap(elementMap, tokens)
    local saveKeys = {}
    for saveKey in pairs(elementMap) do
        saveKeys[#saveKeys + 1] = saveKey
    end
    table.sort(saveKeys)
    for _, saveKey in ipairs(saveKeys) do
        local elementRow = elementMap[saveKey]
        tokens[#tokens + 1] = EncodeSaveKeyToken(saveKey)
        tokens[#tokens + 1] = FormatOffsetToken(elementRow.offsetX)
        tokens[#tokens + 1] = FormatOffsetToken(elementRow.offsetY)
        local extraTokens = EncodeElementExtras(elementRow)
        local extraPairCount = #extraTokens / 2
        tokens[#tokens + 1] = tostring(extraPairCount)
        for extraIndex = 1, #extraTokens do
            tokens[#tokens + 1] = extraTokens[extraIndex]
        end
    end
    return #saveKeys
end

local function ApplySeparatedTrackersBitmask(elementRow, bitMask)
    local separatedTrackers = elementRow.SeparatedTrackers
    if type(separatedTrackers) ~= "table" then
        separatedTrackers = {}
        elementRow.SeparatedTrackers = separatedTrackers
    end
    for bitIndex, trackerKey in ipairs(SEPARATED_TRACKER_BIT_KEYS) do
        local bitValue = 2 ^ (bitIndex - 1)
        if ZO_FlagHelpers.MaskHasFlag(bitMask, bitValue) then
            separatedTrackers[trackerKey] = true
        end
    end
end

local function DecodeElementRecord(tokens, tokenIndex)
    local saveKeyToken = tokens[tokenIndex]
    local offsetXToken = tokens[tokenIndex + 1]
    local offsetYToken = tokens[tokenIndex + 2]
    local extraCountToken = tokens[tokenIndex + 3]
    if saveKeyToken == nil or offsetXToken == nil or offsetYToken == nil or extraCountToken == nil then
        return nil, tokenIndex, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_TRUNCATED)
    end

    local saveKey, saveKeyError = DecodeSaveKeyToken(saveKeyToken)
    if saveKeyError then
        return nil, tokenIndex, saveKeyError
    end

    local offsetX = tonumber(offsetXToken)
    local offsetY = tonumber(offsetYToken)
    local extraCount = tonumber(extraCountToken)
    if offsetX == nil or offsetY == nil or extraCount == nil or extraCount < 0 or extraCount ~= zo_floor(extraCount) then
        return nil, tokenIndex, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_NUMBER)
    end

    local elementRow =
    {
        offsetX = offsetX,
        offsetY = offsetY,
    }

    tokenIndex = tokenIndex + 4
    for _ = 1, extraCount do
        local extraKeyToken = tokens[tokenIndex]
        local extraValueToken = tokens[tokenIndex + 1]
        if extraKeyToken == nil or extraValueToken == nil then
            return nil, tokenIndex, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_TRUNCATED)
        end
        tokenIndex = tokenIndex + 2

        local extraValue = tonumber(extraValueToken)
        if extraValue == nil then
            return nil, tokenIndex, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_NUMBER)
        end

        if extraKeyToken == "ST" then
            ApplySeparatedTrackersBitmask(elementRow, zo_floor(extraValue))
        else
            local extraPrefix = zo_strsub(extraKeyToken, 1, 1)
            if extraPrefix ~= "@" then
                return nil, tokenIndex, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_EXTRA)
            end
            local extraPath = zo_strsub(extraKeyToken, 2)
            if extraPath == nil or extraPath == "" then
                return nil, tokenIndex, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_EXTRA)
            end
            if not SetNestedValue(elementRow, extraPath, extraValue) then
                return nil, tokenIndex, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_EXTRA)
            end
        end
    end

    return saveKey, tokenIndex, nil, elementRow
end

local function DecodeElementMap(tokens, tokenIndex, elementCount)
    local elementMap = {}
    for _ = 1, elementCount do
        local saveKey, nextIndex, decodeError, elementRow = DecodeElementRecord(tokens, tokenIndex)
        if decodeError then
            return nil, tokenIndex, decodeError
        end
        elementMap[saveKey] = elementRow
        tokenIndex = nextIndex
    end
    return elementMap, tokenIndex, nil
end

local function EncodeAppearanceMap(modeMap, tokens)
    local saveKeys = {}
    if type(modeMap) == "table" then
        for saveKey, row in pairs(modeMap) do
            if not HT.IsAppearanceRowDefault(row) then
                saveKeys[#saveKeys + 1] = saveKey
            end
        end
    end
    table.sort(saveKeys)
    tokens[#tokens + 1] = tostring(#saveKeys)
    for _, saveKey in ipairs(saveKeys) do
        local row = modeMap[saveKey]
        tokens[#tokens + 1] = EncodeSaveKeyToken(saveKey)
        tokens[#tokens + 1] = FormatOffsetToken(row.scale or 1)
        tokens[#tokens + 1] = EscapeTextToken(row.fontFace or "")
        tokens[#tokens + 1] = tostring(zo_floor(tonumber(row.fontSize) or HT.APPEARANCE_FONT_SIZE_DEFAULT))
        tokens[#tokens + 1] = EscapeTextToken(row.fontOutline or "")
    end
end

local function DecodeAppearanceMap(tokens, tokenIndex)
    local countToken = tokens[tokenIndex]
    if countToken == nil then
        return nil, tokenIndex, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_TRUNCATED)
    end
    local rowCount = tonumber(countToken)
    if rowCount == nil or rowCount < 0 or rowCount ~= zo_floor(rowCount) then
        return nil, tokenIndex, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_NUMBER)
    end
    tokenIndex = tokenIndex + 1
    local modeMap = {}
    for _ = 1, rowCount do
        local saveKeyToken = tokens[tokenIndex]
        local scaleToken = tokens[tokenIndex + 1]
        local fontFaceToken = tokens[tokenIndex + 2]
        local fontSizeToken = tokens[tokenIndex + 3]
        local fontOutlineToken = tokens[tokenIndex + 4]
        if saveKeyToken == nil or scaleToken == nil or fontFaceToken == nil or fontSizeToken == nil or fontOutlineToken == nil then
            return nil, tokenIndex, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_TRUNCATED)
        end
        local saveKey, saveKeyError = DecodeSaveKeyToken(saveKeyToken)
        if saveKeyError then
            return nil, tokenIndex, saveKeyError
        end
        local scale = tonumber(scaleToken)
        local fontSize = tonumber(fontSizeToken)
        if scale == nil or fontSize == nil then
            return nil, tokenIndex, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_NUMBER)
        end
        modeMap[saveKey] =
        {
            scale = scale,
            fontFace = UnescapeTextToken(fontFaceToken),
            fontSize = fontSize,
            fontOutline = UnescapeTextToken(fontOutlineToken),
        }
        tokenIndex = tokenIndex + 5
    end
    return modeMap, tokenIndex, nil
end

function HT.EncodeHudLayoutPayload(payload)
    local tokens =
    {
        HT.HUDT_MAGIC,
        tostring(HT.HUDT_FORMAT_VERSION),
        "0",
        "0",
    }
    local keyboardCount = EncodeElementMap(payload.keyboardElements or {}, tokens)
    local gamepadCount = EncodeElementMap(payload.gamepadElements or {}, tokens)
    tokens[3] = tostring(keyboardCount)
    tokens[4] = tostring(gamepadCount)

    local appearance = payload.elementAppearance or {}
    tokens[#tokens + 1] = "A"
    EncodeAppearanceMap(appearance.keyboard, tokens)
    EncodeAppearanceMap(appearance.gamepad, tokens)

    local resourceBarGroup = payload.resourceBarGroup or {}
    local resourceEnabled = "0"
    if resourceBarGroup.enabled then
        resourceEnabled = "1"
    end
    local preventExpandToken = "0"
    if resourceBarGroup.preventExpand then
        preventExpandToken = "1"
    end
    tokens[#tokens + 1] = "R"
    tokens[#tokens + 1] = resourceEnabled
    tokens[#tokens + 1] = tostring(zo_floor(tonumber(resourceBarGroup.healthWidth) or HT.RESOURCE_BAR_GROUP_DEFAULT_WIDTH or 474))
    tokens[#tokens + 1] = preventExpandToken

    -- table.concat matches zo_strjoin(" ", ...) without Lua 5.1 vararg limits
    return table.concat(tokens, " ")
end

function HT.DecodeHudLayoutString(sourceString)
    if type(sourceString) ~= "string" then
        return nil, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_MAGIC)
    end
    local tokens = zo_tokenize(sourceString)
    if #tokens < 4 then
        return nil, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_TRUNCATED)
    end
    if tokens[1] ~= HT.HUDT_MAGIC then
        return nil, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_MAGIC)
    end
    local formatVersion = tonumber(tokens[2])
    if formatVersion ~= HT.HUDT_FORMAT_VERSION
        and formatVersion ~= HT.HUDT_FORMAT_VERSION_V1
        and formatVersion ~= HT.HUDT_FORMAT_VERSION_V2 then
        return nil, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_VERSION)
    end
    local keyboardCount = tonumber(tokens[3])
    local gamepadCount = tonumber(tokens[4])
    if keyboardCount == nil or gamepadCount == nil or keyboardCount < 0 or gamepadCount < 0
        or keyboardCount ~= zo_floor(keyboardCount) or gamepadCount ~= zo_floor(gamepadCount) then
        return nil, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_NUMBER)
    end

    local tokenIndex = 5
    local keyboardElements, nextIndex, decodeError = DecodeElementMap(tokens, tokenIndex, keyboardCount)
    if decodeError then
        return nil, decodeError
    end
    tokenIndex = nextIndex
    local gamepadElements, endIndex, gamepadError = DecodeElementMap(tokens, tokenIndex, gamepadCount)
    if gamepadError then
        return nil, gamepadError
    end

    local elementAppearance =
    {
        keyboard = {},
        gamepad = {},
    }
    local resourceBarGroup =
    {
        enabled = false,
        healthWidth = HT.RESOURCE_BAR_GROUP_DEFAULT_WIDTH or 474,
        preventExpand = false,
    }

    if formatVersion == HT.HUDT_FORMAT_VERSION_V1 then
        if endIndex <= #tokens then
            return nil, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_TRAILING)
        end
        return {
            keyboardElements = keyboardElements,
            gamepadElements = gamepadElements,
            elementAppearance = elementAppearance,
            resourceBarGroup = resourceBarGroup,
        }, nil
    end

    if tokens[endIndex] ~= "A" then
        return nil, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_EXTRA)
    end
    local keyboardAppearance, appearanceIndex, keyboardAppearanceError = DecodeAppearanceMap(tokens, endIndex + 1)
    if keyboardAppearanceError then
        return nil, keyboardAppearanceError
    end
    local gamepadAppearance, resourceIndex, gamepadAppearanceError = DecodeAppearanceMap(tokens, appearanceIndex)
    if gamepadAppearanceError then
        return nil, gamepadAppearanceError
    end
    if tokens[resourceIndex] ~= "R" then
        return nil, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_EXTRA)
    end
    local enabledToken = tokens[resourceIndex + 1]
    local widthToken = tokens[resourceIndex + 2]
    if enabledToken == nil or widthToken == nil then
        return nil, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_TRUNCATED)
    end
    local healthWidth = tonumber(widthToken)
    if healthWidth == nil or (enabledToken ~= "0" and enabledToken ~= "1") then
        return nil, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_NUMBER)
    end
    local preventExpand = false
    local trailingIndex = resourceIndex + 3
    if formatVersion == HT.HUDT_FORMAT_VERSION then
        local preventExpandToken = tokens[resourceIndex + 3]
        if preventExpandToken == nil then
            return nil, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_TRUNCATED)
        end
        if preventExpandToken ~= "0" and preventExpandToken ~= "1" then
            return nil, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_NUMBER)
        end
        preventExpand = preventExpandToken == "1"
        trailingIndex = resourceIndex + 4
    end
    if trailingIndex <= #tokens then
        return nil, GetString(SI_HUDITORTOOLS_LAYOUT_CODEC_ERROR_TRAILING)
    end

    return {
        keyboardElements = keyboardElements,
        gamepadElements = gamepadElements,
        elementAppearance =
        {
            keyboard = keyboardAppearance,
            gamepad = gamepadAppearance,
        },
        resourceBarGroup =
        {
            enabled = enabledToken == "1",
            healthWidth = healthWidth,
            preventExpand = preventExpand,
        },
    }, nil
end
