local ADDON_NAME = "NirnsteelUI"
local EVENT_NAMESPACE = ADDON_NAME .. "_GroupFrames"
local STOCK_HIDE_REASON = ADDON_NAME .. "_GroupFrames"

Nirnsteel_UI = Nirnsteel_UI or {}
local Nirnsteel_UI = Nirnsteel_UI
local GroupFrames = {}
Nirnsteel_UI.GroupFrames = GroupFrames

local BarVisuals = Nirnsteel_UI.BarVisuals
local LevelVisuals = Nirnsteel_UI.LevelVisuals
local MAX_GROUP_ROWS = MAX_GROUP_SIZE_THRESHOLD or 24
local HEALTH_POWER_TYPE = COMBAT_MECHANIC_FLAGS_HEALTH
local PLAYER_DEFAULT_POSITION = { keyboard = { x = 28, y = 100 }, gamepad = { x = 70, y = 55 } }
local COMPANION_INDENT = 22
local COMPANION_GAP = 4
local COMPANION_IDENTITY_HEIGHT = 15
local COMPANION_BAR_HEIGHT = 12
local STATUS_ICON_SIZE = 16
local ROSTER_REFRESH_DELAY_MS = 50
local RECOVERY_CADENCE_MS = 2000
local LEVEL_SHIMMER_CADENCE_MS = LevelVisuals.SHIMMER_CADENCE_MS

local DEFAULT_SETTINGS =
{
    enabled = true,
    unlocked = false,
    scale = 100,
    width = 270,
    healthHeight = 24,
    identityHeight = 20,
    rowSpacing = 6,
    columnSpacing = 14,
    trialMembersPerColumn = 0,
    compactTrials = false,
    opacity = 100,
    sortMode = "role",
    displayNameMode = "displayName",
    healthColorMode = "role",
    healthTextMode = "number",
    healthTextPosition = "left",
    showClassIcon = true,
    showRoleIcon = true,
    classIconSize = 16,
    roleIconSize = 16,
    showLeaderIcon = true,
    showShields = true,
    showDeathAnimation = true,
    showFriendIcon = false,
    showGuildIcon = false,
    showLevel = true,
    showLevelStyle = true,
    levelTextSize = 13,
    showRecoveryRhythm = false,
    glossEnabled = true,
    patternEnabled = true,
    patternKey = "ZigZag",
    patternOpacity = 8,
    patternScale = 220,
    feedbackEnabled = true,
    feedbackIntensity = 80,
    lossTrailEnabled = false,
    lowHealthGlowEnabled = true,
    borderWidth = 1,
    rpgBorder = true,
    innerShadowAlpha = 55,
    outerShadowAlpha = 75,
    textFontKey = "gameSmall",
    nameTextSize = 15,
    healthTextSize = 16,
    textOutline = "thick-outline",
    textOpacity = 100,
    textInset = 6,
    staticColor = { r = 0.78, g = 0.10, b = 0.11 },
    fullHealthColor = { r = 0.96, g = 0.96, b = 0.94 },
    lowHealthColor = { r = 0.56, g = 0.035, b = 0.055 },
    tankColor = { r = 0.23, g = 0.51, b = 0.88 },
    healerColor = { r = 0.28, g = 0.72, b = 0.42 },
    damageColor = { r = 0.84, g = 0.27, b = 0.25 },
    otherColor = { r = 0.85, g = 0.60, b = 0.24 },
    companionColor = { r = 0.24, g = 0.62, b = 0.62 },
    shieldFillOpacity = 70,
    shieldFillColor = { r = 0.95, g = 0.60, b = 0.33 },
    shieldGlowEnabled = true,
    shieldGlowOpacity = 58,
    shieldGlowColor = { r = 0.95, g = 0.66, b = 0.56 },
    classColors =
    {
        [1] = { r = 0.85, g = 0.47, b = 0.17 },
        [2] = { r = 0.54, g = 0.39, b = 0.84 },
        [3] = { r = 0.70, g = 0.23, b = 0.28 },
        [4] = { r = 0.26, g = 0.66, b = 0.54 },
        [5] = { r = 0.40, g = 0.54, b = 0.66 },
        [6] = { r = 0.88, g = 0.75, b = 0.33 },
        [117] = { r = 0.25, g = 0.72, b = 0.47 },
    },
    unknownClassColor = { r = 0.54, g = 0.59, b = 0.66 },
}

local READY_CHECK_ICONS =
{
    [GROUP_VOTE_CHOICE_ABSTAIN] = "EsoUI/Art/UnitFrames/votedIcon_notYet.dds",
    [GROUP_VOTE_CHOICE_FOR] = "EsoUI/Art/UnitFrames/votedIcon_yes.dds",
    [GROUP_VOTE_CHOICE_AGAINST] = "EsoUI/Art/UnitFrames/votedIcon_no.dds",
    [GROUP_VOTE_CHOICE_INVALID] = "EsoUI/Art/UnitFrames/votedIcon_notYet.dds",
}

local PREVIEW_NAMES =
{
    "@AetherTank", "@BrightMender", "@CinderBlade", "@DawnArrow", "@EmberKnight", "@FrostWard",
    "@GaleSinger", "@HollowStar", "@IronRoot", "@JadeSpear", "@KindleFox", "@LunarRune",
    "@MoonHammer", "@NightQuill", "@OakenShield", "@PrismWitch", "@QuietStorm", "@RuneDancer",
    "@SilverAsh", "@ThornHeart", "@UmbralRay", "@VelvetBlade", "@WildBloom", "@ZenithGuard",
}

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    return math.min(math.max(value, minimum), maximum)
end

local function CopyColor(color, fallback)
    color = color or fallback or {}
    return
    {
        r = tonumber(color.r) or tonumber(fallback and fallback.r) or 1,
        g = tonumber(color.g) or tonumber(fallback and fallback.g) or 1,
        b = tonumber(color.b) or tonumber(fallback and fallback.b) or 1,
        a = tonumber(color.a) or tonumber(fallback and fallback.a) or 1,
    }
end

local function GetSettings()
    if Nirnsteel_UI.Settings and Nirnsteel_UI.Settings.GetGroupFrames then
        return Nirnsteel_UI.Settings:GetGroupFrames()
    end
    return DEFAULT_SETTINGS
end

local function GetSetting(key)
    local settings = GetSettings()
    local value = settings and settings[key]
    if value == nil then
        return DEFAULT_SETTINGS[key]
    end
    return value
end

local function IsCompactTrial()
    return GetSetting("compactTrials") == true and #(GroupFrames.roster or {}) > 4
end

local function GetRowDimensions()
    if IsCompactTrial() then
        return math.min(Clamp(GetSetting("width"), 180, 420), 220), 18, 16
    end
    return Clamp(GetSetting("width"), 180, 420), Clamp(GetSetting("identityHeight"), 16, 32), Clamp(GetSetting("healthHeight"), 12, 42)
end

local function IsEnabled()
    return GetSetting("enabled") ~= false
end

local function IsUnlocked()
    if Nirnsteel_UI.HUDEditor and Nirnsteel_UI.HUDEditor:IsAvailable() then return false end
    return IsEnabled() and GetSetting("unlocked") == true
end

local function IsGrouped()
    return IsUnitGrouped and IsUnitGrouped("player") == true
end

local function IsHudSceneShowing()
    local hudShowing = HUD_SCENE and HUD_SCENE.IsShowing and HUD_SCENE:IsShowing()
    local hudUiShowing = HUD_UI_SCENE and HUD_UI_SCENE.IsShowing and HUD_UI_SCENE:IsShowing()
    if HUD_SCENE or HUD_UI_SCENE then
        return hudShowing or hudUiShowing
    end
    return true
end

local function GetModeKey()
    return IsInGamepadPreferredMode and IsInGamepadPreferredMode() and "gamepad" or "keyboard"
end

local function GetDefaultPosition(mode)
    mode = mode or GetModeKey()
    if ZO_UnitFrames_GetPlatformConstants then
        local ok, constants = pcall(ZO_UnitFrames_GetPlatformConstants)
        if ok and constants then
            local x = tonumber(constants.GROUP_FRAME_BASE_OFFSET_X)
            local y = tonumber(constants.GROUP_FRAME_BASE_OFFSET_Y)
            if x and y then
                return x, y
            end
        end
    end
    local fallback = PLAYER_DEFAULT_POSITION[mode] or PLAYER_DEFAULT_POSITION.keyboard
    return fallback.x, fallback.y
end

local function GetPosition(mode)
    mode = mode or GetModeKey()
    if Nirnsteel_UI.Settings and Nirnsteel_UI.Settings.GetGroupFramesPosition then
        return Nirnsteel_UI.Settings:GetGroupFramesPosition(mode)
    end
    local x, y = GetDefaultPosition(mode)
    return { custom = false, x = x, y = y }
end

local function BuildFont(fontKey, size, outline)
    local faces = BarVisuals and BarVisuals.Fonts or {}
    local face = faces[fontKey] or "$(BOLD_FONT)"
    size = Clamp(size, 8, 32)
    if outline == "none" then
        return string.format("%s|%d", face, size)
    end
    return string.format("%s|%d|%s", face, size, outline or "soft-shadow-thick")
end

local function NormalizeName(text)
    text = text or ""
    if LocaleAwareToLower then
        return LocaleAwareToLower(text)
    end
    return string.lower(text)
end

local function GetDisplayText(data)
    if GetSetting("displayNameMode") == "characterName" then
        return data.characterName ~= "" and data.characterName or data.displayName
    end
    return data.displayName ~= "" and data.displayName or data.characterName
end

local function GetClassIcon(classId)
    if not classId or classId == 0 or not GetClassIndexById or not GetClassInfo then
        return nil
    end
    local index = GetClassIndexById(classId)
    if not index then
        return nil
    end
    local _, _, _, _, _, _, keyboardIcon, gamepadIcon = GetClassInfo(index)
    return GetModeKey() == "gamepad" and (gamepadIcon or keyboardIcon) or keyboardIcon
end

local function GetRoleRank(role)
    if role == LFG_ROLE_TANK then
        return 1
    elseif role == LFG_ROLE_HEAL then
        return 2
    elseif role == LFG_ROLE_DPS then
        return 3
    end
    return 4
end

local function GetRoleLabel(role)
    if role == LFG_ROLE_TANK then
        return "Tank"
    elseif role == LFG_ROLE_HEAL then
        return "Healer"
    elseif role == LFG_ROLE_DPS then
        return "Damage"
    end
    return "Other"
end

local function GetSharedGuilds(displayName)
    if not displayName or displayName == "" or not GetNumGuilds or not GetGuildId or not GetGuildMemberIndexFromDisplayName then
        return {}
    end

    GroupFrames.guildCache = GroupFrames.guildCache or {}
    local cached = GroupFrames.guildCache[displayName]
    if cached then
        return cached
    end

    local guilds = {}
    for guildIndex = 1, GetNumGuilds() do
        local guildId = GetGuildId(guildIndex)
        local memberIndex = guildId and GetGuildMemberIndexFromDisplayName(guildId, displayName)
        if memberIndex and memberIndex > 0 then
            guilds[#guilds + 1] = GetGuildName and GetGuildName(guildId) or "Guild"
        end
    end
    GroupFrames.guildCache[displayName] = guilds
    return guilds
end

local function GetShieldValue(unitTag)
    if not unitTag or not GetUnitAttributeVisualizerEffectInfo then
        return 0
    end
    local value = GetUnitAttributeVisualizerEffectInfo(unitTag, ATTRIBUTE_VISUAL_POWER_SHIELDING, STAT_MITIGATION, ATTRIBUTE_HEALTH, HEALTH_POWER_TYPE)
    return math.max(tonumber(value) or 0, 0)
end

local function GetReadyCheck(unitTag)
    if not unitTag or not GetGroupElectionInfo or not GetGroupElectionVoteByUnitTag then
        return nil
    end
    local electionType, timeRemainingSeconds, descriptor = GetGroupElectionInfo()
    if not timeRemainingSeconds or timeRemainingSeconds <= 0 then
        return nil
    end
    if ZO_IsGroupElectionTypeCustom and not ZO_IsGroupElectionTypeCustom(electionType) then
        return nil
    end
    if ZO_GROUP_ELECTION_DESCRIPTORS and descriptor ~= ZO_GROUP_ELECTION_DESCRIPTORS.READY_CHECK then
        return nil
    end
    return GetGroupElectionVoteByUnitTag(unitTag)
end

local function BuildUnitData(unitTag, isCompanion)
    local rawName = GetRawUnitName and GetRawUnitName(unitTag) or ""
    local characterName = rawName ~= "" and zo_strformat(SI_UNIT_NAME, rawName) or ""
    local displayName = not isCompanion and GetUnitDisplayName and GetUnitDisplayName(unitTag) or ""
    local current, maximum = GetUnitPower(unitTag, HEALTH_POWER_TYPE)
    local online = not IsUnitOnline or IsUnitOnline(unitTag)
    local classId = not isCompanion and GetUnitClassId and GetUnitClassId(unitTag) or 0
    local champion = not isCompanion and IsUnitChampion and IsUnitChampion(unitTag) or false
    local championPoints = champion and GetUnitChampionPoints and GetUnitChampionPoints(unitTag) or 0
    local level = not isCompanion and GetUnitLevel and GetUnitLevel(unitTag) or 0
    local inRange = not IsUnitInGroupSupportRange or IsUnitInGroupSupportRange(unitTag)
    local sameWorld = isCompanion or not IsGroupMemberInSameWorldAsPlayer or IsGroupMemberInSameWorldAsPlayer(unitTag)
    local sameInstance = isCompanion or not IsGroupMemberInSameInstanceAsPlayer or IsGroupMemberInSameInstanceAsPlayer(unitTag)
    local sameLayer = isCompanion or not IsGroupMemberInSameLayerAsPlayer or IsGroupMemberInSameLayerAsPlayer(unitTag)
    local marker = GetUnitTargetMarkerType and GetUnitTargetMarkerType(unitTag) or TARGET_MARKER_TYPE_NONE

    return
    {
        unitTag = unitTag,
        displayName = displayName or "",
        characterName = characterName or "",
        role = not isCompanion and GetGroupMemberSelectedRole and GetGroupMemberSelectedRole(unitTag) or LFG_ROLE_INVALID,
        classId = classId or 0,
        className = not isCompanion and GetUnitClass and GetUnitClass(unitTag) or "",
        classIcon = not isCompanion and GetClassIcon(classId) or nil,
        champion = champion == true,
        championPoints = tonumber(championPoints) or 0,
        level = tonumber(level) or 0,
        currentHealth = tonumber(current) or 0,
        maximumHealth = tonumber(maximum) or 0,
        healthAvailable = tonumber(maximum) and tonumber(maximum) > 0,
        shield = GetShieldValue(unitTag),
        dead = IsUnitDead and IsUnitDead(unitTag) or false,
        online = online ~= false,
        inRange = inRange ~= false and sameWorld ~= false and sameInstance ~= false and sameLayer ~= false,
        leader = not isCompanion and IsUnitGroupLeader and IsUnitGroupLeader(unitTag) or false,
        friend = not isCompanion and IsUnitFriend and IsUnitFriend(unitTag) or false,
        sharedGuilds = not isCompanion and GetSharedGuilds(displayName) or {},
        marker = marker or TARGET_MARKER_TYPE_NONE,
        readyVote = not isCompanion and GetReadyCheck(unitTag) or nil,
        isCompanion = isCompanion == true,
    }
end

local function BuildPreviewMember(index, size)
    local roles = { LFG_ROLE_TANK, LFG_ROLE_HEAL, LFG_ROLE_DPS, LFG_ROLE_DPS }
    local classIds = { 1, 6, 2, 3, 4, 5, 117 }
    local cpValues = { 3600, 1676, 1302, 1083, 2046, 420, 880, 1240, 1820, 2460, 3020, 3599 }
    local healthPercent = ({ 1, 0.78, 0.42, 0.18, 0.94, 0.63 })[((index - 1) % 6) + 1]
    local maximum = 30000 + ((index % 5) * 4200)
    local classId = classIds[((index - 1) % #classIds) + 1]
    local data =
    {
        unitTag = nil,
        displayName = PREVIEW_NAMES[index] or string.format("@Preview%02d", index),
        characterName = string.format("Preview Hero %02d", index),
        role = roles[((index - 1) % #roles) + 1],
        classId = classId,
        className = ({ [1] = "Dragonknight", [2] = "Sorcerer", [3] = "Nightblade", [4] = "Warden", [5] = "Necromancer", [6] = "Templar", [117] = "Arcanist" })[classId],
        classIcon = GetClassIcon(classId),
        champion = index ~= size,
        championPoints = cpValues[((index - 1) % #cpValues) + 1],
        level = index == size and 37 or 50,
        currentHealth = math.floor(maximum * healthPercent),
        maximumHealth = maximum,
        healthAvailable = index ~= math.min(size, 11),
        shield = index % 3 == 0 and math.floor(maximum * 0.28) or 0,
        dead = index == math.min(size, 9),
        online = index ~= math.min(size, 10),
        inRange = index ~= math.min(size, 8),
        leader = index == 1,
        friend = index == 3,
        sharedGuilds = index == 4 and { "Nirnsteel Preview Guild" } or {},
        marker = index == 2 and (TARGET_MARKER_TYPE_ONE or 1) or TARGET_MARKER_TYPE_NONE,
        readyVote = index <= 4 and ({ GROUP_VOTE_CHOICE_FOR, GROUP_VOTE_CHOICE_FOR, GROUP_VOTE_CHOICE_ABSTAIN, GROUP_VOTE_CHOICE_AGAINST })[index] or nil,
        isCompanion = false,
    }
    if index == 2 and size <= 4 then
        data.companion =
        {
            unitTag = nil,
            displayName = "",
            characterName = "Bastian",
            currentHealth = 19800,
            maximumHealth = 24000,
            healthAvailable = true,
            shield = 3600,
            dead = false,
            online = true,
            inRange = true,
            isCompanion = true,
        }
    end
    return data
end

local function SortRoster(roster)
    local sortMode = GetSetting("sortMode")
    table.sort(roster, function(first, second)
        local firstName = NormalizeName(GetDisplayText(first))
        local secondName = NormalizeName(GetDisplayText(second))
        if sortMode == "role" then
            local firstRank = GetRoleRank(first.role)
            local secondRank = GetRoleRank(second.role)
            if firstRank ~= secondRank then
                return firstRank < secondRank
            end
        elseif sortMode == "level" then
            if first.champion ~= second.champion then
                return first.champion
            end
            local firstLevel = first.champion and first.championPoints or first.level
            local secondLevel = second.champion and second.championPoints or second.level
            if firstLevel ~= secondLevel then
                return firstLevel > secondLevel
            end
        elseif sortMode == "class" then
            local firstClass = NormalizeName(first.className)
            local secondClass = NormalizeName(second.className)
            if firstClass ~= secondClass then
                return firstClass < secondClass
            end
        end
        if firstName ~= secondName then
            return firstName < secondName
        end
        return NormalizeName(first.displayName) < NormalizeName(second.displayName)
    end)
end

local function GetRoleColor(role)
    if role == LFG_ROLE_TANK then
        return CopyColor(GetSetting("tankColor"), DEFAULT_SETTINGS.tankColor)
    elseif role == LFG_ROLE_HEAL then
        return CopyColor(GetSetting("healerColor"), DEFAULT_SETTINGS.healerColor)
    elseif role == LFG_ROLE_DPS then
        return CopyColor(GetSetting("damageColor"), DEFAULT_SETTINGS.damageColor)
    end
    return CopyColor(GetSetting("otherColor"), DEFAULT_SETTINGS.otherColor)
end

local function InterpolateColor(startColor, endColor, progress)
    progress = Clamp(progress, 0, 1)
    return
    {
        r = startColor.r + ((endColor.r - startColor.r) * progress),
        g = startColor.g + ((endColor.g - startColor.g) * progress),
        b = startColor.b + ((endColor.b - startColor.b) * progress),
        a = 1,
    }
end

local function GetHealthColor(data)
    if data.isCompanion then
        return CopyColor(GetSetting("companionColor"), DEFAULT_SETTINGS.companionColor)
    end
    local mode = GetSetting("healthColorMode")
    if mode == "static" then
        return CopyColor(GetSetting("staticColor"), DEFAULT_SETTINGS.staticColor)
    elseif mode == "percentage" then
        local low = CopyColor(GetSetting("lowHealthColor"), DEFAULT_SETTINGS.lowHealthColor)
        local full = CopyColor(GetSetting("fullHealthColor"), DEFAULT_SETTINGS.fullHealthColor)
        local ratio = data.maximumHealth > 0 and data.currentHealth / data.maximumHealth or 0
        return InterpolateColor(low, full, ratio)
    elseif mode == "class" then
        local settings = GetSettings()
        local classColors = settings.classColors or DEFAULT_SETTINGS.classColors
        return CopyColor(classColors[data.classId], GetSetting("unknownClassColor"))
    end
    return GetRoleColor(data.role)
end

local function BuildBarStyle(data, width, height, companion)
    local color = GetHealthColor(data)
    local startColor = { r = color.r * 0.72, g = color.g * 0.72, b = color.b * 0.72, a = 1 }
    local endColor = { r = math.min(color.r * 1.12, 1), g = math.min(color.g * 1.12, 1), b = math.min(color.b * 1.12, 1), a = 1 }
    if data.dead then
        startColor = { r = 0.16, g = 0.16, b = 0.17, a = 1 }
        endColor = { r = 0.34, g = 0.08, b = 0.09, a = 1 }
    end

    local patternKey = GetSetting("patternKey")
    local textureInfo = BarVisuals and BarVisuals.Textures.genericTall
    local patternTexture = BarVisuals and BarVisuals.Patterns[patternKey]
    local outline = GetSetting("textOutline")
    return
    {
        width = width,
        height = height,
        alpha = Clamp(GetSetting("opacity"), 10, 100) / 100,
        borderWidth = IsCompactTrial() and 1 or Clamp(GetSetting("borderWidth"), 0, 8),
        rpgBorder = not IsCompactTrial() and GetSetting("rpgBorder") == true,
        innerShadowAlpha = Clamp(GetSetting("innerShadowAlpha"), 0, 100) / 100,
        outerShadowAlpha = Clamp(GetSetting("outerShadowAlpha"), 0, 100) / 100,
        textureInfo = textureInfo,
        trackColor = { r = 0.008, g = 0.009, b = 0.012, a = IsCompactTrial() and 0.86 or companion and 0.58 or 0.68 },
        fillStartColor = startColor,
        fillEndColor = endColor,
        glossEnabled = not IsCompactTrial() and GetSetting("glossEnabled") ~= false,
        glossOpacity = companion and 0.08 or 0.13,
        patternEnabled = not IsCompactTrial() and GetSetting("patternEnabled") == true,
        patternTexture = patternTexture,
        patternOpacity = Clamp(GetSetting("patternOpacity"), 0, 100) / 100 * (companion and 0.65 or 1),
        patternScale = Clamp(GetSetting("patternScale"), 24, 256),
        lossTrailEnabled = GetSetting("lossTrailEnabled") == true,
        lossTrailColor = { r = 1.00, g = 0.70, b = 0.24, a = companion and 0.66 or 0.78 },
        shieldEnabled = GetSetting("showShields") ~= false,
        shieldFillColor = CopyColor(GetSetting("shieldFillColor"), DEFAULT_SETTINGS.shieldFillColor),
        shieldFillOpacity = Clamp(GetSetting("shieldFillOpacity"), 0, 100) / 100,
        shieldGlowEnabled = GetSetting("shieldGlowEnabled") ~= false,
        shieldGlowColor = CopyColor(GetSetting("shieldGlowColor"), DEFAULT_SETTINGS.shieldGlowColor),
        shieldGlowOpacity = Clamp(GetSetting("shieldGlowOpacity"), 0, 100) / 100,
        font = BuildFont(GetSetting("textFontKey"), (companion or IsCompactTrial()) and 12 or GetSetting("healthTextSize"), outline),
        textColor = { r = 0.96, g = 0.94, b = 0.88 },
        textOpacity = Clamp(GetSetting("textOpacity"), 10, 100) / 100,
        textInset = (companion or IsCompactTrial()) and 4 or Clamp(GetSetting("textInset"), 0, 24),
        -- Optically center the compact font's digits within the thin health bar.
        textVerticalOffset = IsCompactTrial() and 2 or companion and 0 or 1,
        lowGlowEnabled = not companion and GetSetting("feedbackEnabled") == true and GetSetting("lowHealthGlowEnabled") ~= false,
        lowGlowThreshold = 0.35,
        lowGlowColor = color,
        feedbackIntensity = Clamp(GetSetting("feedbackIntensity"), 0, 140) / 100,
        alignment = BAR_ALIGNMENT_NORMAL,
    }
end

local function FormatHealth(data)
    if not data.online then
        return "OFFLINE"
    elseif data.dead then
        return "DEAD"
    elseif not data.healthAvailable or data.maximumHealth <= 0 then
        return "--"
    end
    local mode = IsCompactTrial() and "percent" or GetSetting("healthTextMode")
    local number = ZO_AbbreviateAndLocalizeNumber and ZO_AbbreviateAndLocalizeNumber(data.currentHealth, NUMBER_ABBREVIATION_PRECISION_TENTHS, USE_LOWERCASE_NUMBER_SUFFIXES) or tostring(data.currentHealth)
    local percent = string.format("%d%%", zo_round((data.currentHealth / data.maximumHealth) * 100))
    if mode == "percent" then
        return percent
    elseif mode == "both" then
        return string.format("%s · %s", number, percent)
    end
    return number
end

local function SetBarText(frame, text)
    frame.leftLabel:SetHidden(true)
    frame.centerLabel:SetHidden(true)
    frame.rightLabel:SetHidden(true)
    local position = IsCompactTrial() and "right" or GetSetting("healthTextPosition")
    local label = position == "center" and frame.centerLabel or position == "right" and frame.rightLabel or frame.leftLabel
    label:SetText(text)
    label:SetHidden(false)
end

local function CreateBadge(parent, text, color)
    local badge = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    badge:SetDimensions(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
    badge:SetFont("$(BOLD_FONT)|12|outline")
    badge:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    badge:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    badge:SetModifyTextType(MODIFY_TEXT_TYPE_NONE)
    badge:SetText(text)
    badge:SetColor(color[1], color[2], color[3], 1)
    badge:SetDrawLayer(DL_OVERLAY)
    badge:SetDrawLevel(8)
    return badge
end

local function CreateMemberRow(parent, index)
    local row = {}
    row.control = WINDOW_MANAGER:CreateControl("Nirnsteel_UI_GroupFrameRow" .. index, parent, CT_CONTROL)
    row.control:SetHidden(true)

    row.player = WINDOW_MANAGER:CreateControl(nil, row.control, CT_CONTROL)
    row.player:SetAnchor(TOPLEFT, row.control, TOPLEFT, 0, 0)
    row.player:SetMouseEnabled(true)
    row.player:SetHandler("OnMouseUp", function(control, button, upInside)
        if control.unitTag and UnitFrame_HandleMouseUp then
            UnitFrame_HandleMouseUp(control, button, upInside)
        end
    end)
    row.player:SetHandler("OnMouseEnter", function(control)
        if control.unitTag and UnitFrame_HandleMouseEnter then
            UnitFrame_HandleMouseEnter(control)
        end
    end)
    row.player:SetHandler("OnMouseExit", function(control)
        if control.unitTag and UnitFrame_HandleMouseExit then
            UnitFrame_HandleMouseExit(control)
        end
    end)
    row.player:SetHandler("OnReceiveDrag", function(control)
        if control.unitTag and UnitFrame_HandleMouseReceiveDrag then
            UnitFrame_HandleMouseReceiveDrag(control)
        end
    end)

    row.roleIcon = WINDOW_MANAGER:CreateControl(nil, row.player, CT_TEXTURE)
    row.roleIcon:SetDimensions(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
    row.classIcon = WINDOW_MANAGER:CreateControl(nil, row.player, CT_TEXTURE)
    row.classIcon:SetDimensions(STATUS_ICON_SIZE, STATUS_ICON_SIZE)

    row.levelBadge = LevelVisuals:Create(row.player)
    row.levelControl = row.levelBadge.control
    row.levelLabel = row.levelBadge.label
    row.levelShimmerClip = row.levelBadge.clip
    row.levelShimmerContent = row.levelBadge.content
    row.levelGlow = row.levelBadge.glow
    row.levelShimmer = row.levelBadge.shimmer

    row.nameLabel = WINDOW_MANAGER:CreateControl(nil, row.player, CT_LABEL)
    row.nameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    row.nameLabel:SetMaxLineCount(1)
    row.nameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    row.nameLabel:SetModifyTextType(MODIFY_TEXT_TYPE_NONE)
    row.nameLabel:SetColor(0.92, 0.93, 0.96, 1)

    row.targetMarker = CreateBadge(row.player, "", { 1.00, 0.84, 0.18 })
    row.readyIcon = WINDOW_MANAGER:CreateControl(nil, row.player, CT_TEXTURE)
    row.readyIcon:SetDimensions(STATUS_ICON_SIZE, STATUS_ICON_SIZE)
    row.friendBadge = CreateBadge(row.player, "F", { 0.45, 0.78, 1.00 })
    row.guildBadge = CreateBadge(row.player, "G", { 0.54, 0.90, 0.58 })
    row.leaderIcon = WINDOW_MANAGER:CreateControl(nil, row.player, CT_TEXTURE)
    row.leaderIcon:SetDimensions(STATUS_ICON_SIZE, STATUS_ICON_SIZE)

    row.health = BarVisuals:Create(row.player, nil, { withShield = true })

    row.deadBackdrop = WINDOW_MANAGER:CreateControl(nil, row.player, CT_BACKDROP)
    row.deadBackdrop:SetDimensions(20, 20)
    row.deadBackdrop:SetCenterColor(0.35, 0.02, 0.03, 0.90)
    row.deadBackdrop:SetEdgeColor(0.95, 0.20, 0.20, 0.85)
    row.deadBackdrop:SetEdgeTexture("EsoUI/Art/Miscellaneous/Gamepad/edgeframeGamepadBorder_thin.dds", 128, 16, 2, 0)
    row.deadBackdrop:SetDrawLayer(DL_OVERLAY)
    row.deadBackdrop:SetDrawLevel(7)
    row.deadLabel = CreateBadge(row.deadBackdrop, "X", { 1.00, 0.74, 0.70 })
    row.deadLabel:SetAnchorFill(row.deadBackdrop)

    row.companion = WINDOW_MANAGER:CreateControl(nil, row.control, CT_CONTROL)
    row.companion:SetHidden(true)
    row.companionName = WINDOW_MANAGER:CreateControl(nil, row.companion, CT_LABEL)
    row.companionName:SetFont("$(BOLD_FONT)|12|soft-shadow-thick")
    row.companionName:SetColor(0.62, 0.88, 0.86, 1)
    row.companionName:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    row.companionName:SetMaxLineCount(1)
    row.companionName:SetModifyTextType(MODIFY_TEXT_TYPE_NONE)
    row.companionHealth = BarVisuals:Create(row.companion, nil, { withShield = true })
    row.companionDead = CreateBadge(row.companion, "X", { 1.00, 0.48, 0.44 })

    return row
end

function GroupFrames:GetRoot()
    if self.root then
        return self.root
    end
    local root = WINDOW_MANAGER:CreateTopLevelWindow("Nirnsteel_UI_GroupFramesRoot")
    root:SetDimensions(DEFAULT_SETTINGS.width, 1)
    root:SetClampedToScreen(true)
    root:SetMouseEnabled(false)
    root:SetDrawTier(DT_HIGH)
    root:SetHidden(true)
    self.root = root
    self.rows = {}
    self.rowsByUnitTag = {}
    for index = 1, MAX_GROUP_ROWS do
        self.rows[index] = CreateMemberRow(root, index)
    end
    self.initialized = true
    return root
end

function GroupFrames:GetMover()
    if self.mover then
        return self.mover
    end
    local mover = WINDOW_MANAGER:CreateTopLevelWindow("Nirnsteel_UI_GroupFramesMover")
    mover:SetDimensions(DEFAULT_SETTINGS.width, 50)
    mover:SetClampedToScreen(true)
    mover:SetMouseEnabled(true)
    mover:SetMovable(false)
    mover:SetDrawTier(DT_HIGH)
    mover:SetDrawLayer(DL_OVERLAY)
    mover:SetHidden(true)

    local backdrop = WINDOW_MANAGER:CreateControl(nil, mover, CT_BACKDROP)
    backdrop:SetAnchorFill(mover)
    backdrop:SetCenterColor(0.02, 0.02, 0.025, 0.32)
    backdrop:SetEdgeColor(0.88, 0.72, 0.24, 0.90)
    backdrop:SetEdgeTexture("EsoUI/Art/Miscellaneous/Gamepad/edgeframeGamepadBorder_thin.dds", 128, 16, 2, 0)
    local label = WINDOW_MANAGER:CreateControl(nil, mover, CT_LABEL)
    label:SetAnchor(TOP, mover, TOP, 0, 4)
    label:SetFont("ZoFontGameBold")
    label:SetText("Nirnsteel Group Frames")
    label:SetColor(0.95, 0.86, 0.35, 1)

    mover:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            control:SetMovable(true)
            control:StartMoving()
        end
    end)
    mover:SetHandler("OnMouseUp", function(control, button)
        if button ~= MOUSE_BUTTON_INDEX_LEFT then
            return
        end
        control:StopMovingOrResizing()
        control:SetMovable(false)
        local x = zo_round(control:GetLeft())
        local y = zo_round(control:GetTop())
        if Nirnsteel_UI.Settings and Nirnsteel_UI.Settings.SetGroupFramesPosition then
            Nirnsteel_UI.Settings:SetGroupFramesPosition(GetModeKey(), x, y, true)
        end
        self:ApplyPosition()
    end)
    self.mover = mover
    return mover
end

local function PlayLevelShimmer(row)
    if row and row.levelBadge then
        LevelVisuals:Play(row.levelBadge)
    end
end

local function ApplyLevelBadge(row, data)
    local width, tierIndex = LevelVisuals:Apply(row.levelBadge, data,
    {
        shown = not IsCompactTrial() and GetSetting("showLevel") ~= false,
        styled = GetSetting("showLevelStyle") ~= false,
        fontSize = Clamp(GetSetting("levelTextSize"), 10, 17),
        playOnTierUpgrade = row.sameIdentity == true,
        previousTier = row.levelTier,
    })
    row.levelShimmerIntensity = row.levelBadge.shimmerIntensity or 0
    row.levelGlowIntensity = row.levelBadge.glowIntensity or 0
    row.levelShimmerTimeline = row.levelBadge.timeline
    if tierIndex then
        row.levelTier = tierIndex
    end
    return width
end

local function AnchorIdentity(row, data, width, identityHeight)
    local leftOffset = IsCompactTrial() and 3 or 0
    local centerY = identityHeight * 0.5
    local iconCenterY = IsCompactTrial() and centerY or centerY - 2
    local roleIconSize = IsCompactTrial() and 14 or Clamp(GetSetting("roleIconSize"), 10, 28)
    local classIconSize = Clamp(GetSetting("classIconSize"), 10, 28)
    local levelCenterY = centerY + 1
    local function AnchorLeft(control, visible, controlWidth, verticalPosition)
        control:SetHidden(not visible)
        if visible then
            control:ClearAnchors()
            control:SetAnchor(LEFT, row.player, TOPLEFT, leftOffset, verticalPosition or centerY)
            leftOffset = leftOffset + controlWidth + 3
        end
    end

    local roleVisible = GetSetting("showRoleIcon") ~= false and data.role ~= LFG_ROLE_INVALID
    if roleVisible and ZO_GetRoleIcon then
        row.roleIcon:SetTexture(ZO_GetRoleIcon(data.role))
    end
    row.roleIcon:SetDimensions(roleIconSize, roleIconSize)
    AnchorLeft(row.roleIcon, roleVisible, roleIconSize, iconCenterY)
    local classVisible = not IsCompactTrial() and GetSetting("showClassIcon") ~= false and data.classIcon ~= nil
    if classVisible then
        row.classIcon:SetTexture(data.classIcon)
    end
    row.classIcon:SetDimensions(classIconSize, classIconSize)
    AnchorLeft(row.classIcon, classVisible, classIconSize, iconCenterY)

    local levelWidth = ApplyLevelBadge(row, data)
    AnchorLeft(row.levelControl, levelWidth > 0, levelWidth, levelCenterY)

    local rightOffset = IsCompactTrial() and 3 or 0
    local function AnchorRight(control, visible)
        local iconSize = IsCompactTrial() and 14 or STATUS_ICON_SIZE
        control:SetDimensions(iconSize, iconSize)
        control:SetHidden(not visible)
        if visible then
            control:ClearAnchors()
            control:SetAnchor(RIGHT, row.player, TOPRIGHT, -rightOffset, centerY)
            rightOffset = rightOffset + iconSize + 3
        end
    end

    local leaderVisible = GetSetting("showLeaderIcon") ~= false and data.leader
    if leaderVisible then
        row.leaderIcon:SetTexture(GetModeKey() == "gamepad" and "EsoUI/Art/UnitFrames/Gamepad/gp_Group_Leader.dds" or "EsoUI/Art/UnitFrames/groupIcon_leader.dds")
    end
    AnchorRight(row.leaderIcon, leaderVisible)
    AnchorRight(row.guildBadge, not IsCompactTrial() and GetSetting("showGuildIcon") == true and #data.sharedGuilds > 0)
    AnchorRight(row.friendBadge, not IsCompactTrial() and GetSetting("showFriendIcon") == true and data.friend)

    local readyTexture = data.readyVote and READY_CHECK_ICONS[data.readyVote]
    if readyTexture then
        row.readyIcon:SetTexture(readyTexture)
    end
    AnchorRight(row.readyIcon, readyTexture ~= nil)

    local markerVisible = data.marker and data.marker ~= TARGET_MARKER_TYPE_NONE
    if markerVisible then
        row.targetMarker:SetText(tostring(data.marker))
    end
    AnchorRight(row.targetMarker, markerVisible)

    row.nameLabel:ClearAnchors()
    row.nameLabel:SetAnchor(TOPLEFT, row.player, TOPLEFT, leftOffset, 0)
    row.nameLabel:SetAnchor(BOTTOMRIGHT, row.player, TOPRIGHT, -rightOffset, identityHeight)
end

local function ApplyRowLayout(row, data, width, identityHeight, healthHeight)
    if IsCompactTrial() then width, identityHeight, healthHeight = GetRowDimensions() end
    local mainHeight = identityHeight + healthHeight
    row.player:SetDimensions(width, mainHeight)
    row.health:ClearAnchors()
    row.health:SetAnchor(TOPLEFT, row.player, TOPLEFT, 0, identityHeight)
    BarVisuals:ApplyStyle(row.health, BuildBarStyle(data, width, healthHeight, false))

    row.deadBackdrop:ClearAnchors()
    row.deadBackdrop:SetAnchor(RIGHT, row.health, RIGHT, -2, 0)
    row.deadBackdrop:SetHidden(IsCompactTrial() or not data.dead)
    AnchorIdentity(row, data, width, identityHeight)

    local totalHeight = mainHeight
    if data.companion then
        totalHeight = totalHeight + COMPANION_GAP + COMPANION_IDENTITY_HEIGHT + COMPANION_BAR_HEIGHT
        row.companion:SetHidden(false)
        row.companion:ClearAnchors()
        row.companion:SetAnchor(TOPLEFT, row.control, TOPLEFT, COMPANION_INDENT, mainHeight + COMPANION_GAP)
        row.companion:SetDimensions(width - COMPANION_INDENT, COMPANION_IDENTITY_HEIGHT + COMPANION_BAR_HEIGHT)
        row.companionName:ClearAnchors()
        row.companionName:SetAnchor(TOPLEFT, row.companion, TOPLEFT, 0, 0)
        row.companionName:SetAnchor(TOPRIGHT, row.companion, TOPRIGHT, -20, 0)
        row.companionName:SetHeight(COMPANION_IDENTITY_HEIGHT)
        row.companionHealth:ClearAnchors()
        row.companionHealth:SetAnchor(TOPLEFT, row.companion, TOPLEFT, 0, COMPANION_IDENTITY_HEIGHT)
        BarVisuals:ApplyStyle(row.companionHealth, BuildBarStyle(data.companion, width - COMPANION_INDENT, COMPANION_BAR_HEIGHT, true))
        row.companionDead:ClearAnchors()
        row.companionDead:SetAnchor(RIGHT, row.companion, TOPRIGHT, 0, COMPANION_IDENTITY_HEIGHT * 0.5)
        row.companionDead:SetHidden(not data.companion.dead)
    else
        row.companion:SetHidden(true)
    end
    row.control:SetDimensions(width, totalHeight)
    row.totalHeight = totalHeight
end

local function UpdateUnitAlpha(row, data)
    local alpha = 1
    if not data.online then
        alpha = IsCompactTrial() and 0.65 or 0.35
    elseif not data.inRange then
        alpha = IsCompactTrial() and 0.60 or 0.40
    end
    row.player:SetAlpha(alpha)
    if data.companion then
        local companionAlpha = not data.companion.online and 0.35 or not data.companion.inRange and 0.40 or 0.90
        row.companion:SetAlpha(companionAlpha)
    end
end

local function UpdateRowValues(row, data, smooth)
    local inactive = IsCompactTrial() and (data.dead or not data.online)
    local animateHealth = smooth and data.healthAvailable and not inactive
    BarVisuals:SetValue(row.health, inactive and 0 or data.currentHealth, data.maximumHealth, animateHealth, animateHealth)
    BarVisuals:SetShield(row.health, not inactive and GetSetting("showShields") ~= false and data.shield or 0, data.maximumHealth, smooth and not inactive)
    SetBarText(row.health, FormatHealth(data))
    if data.companion then
        local animateCompanionHealth = smooth and data.companion.healthAvailable
        BarVisuals:SetValue(row.companionHealth, data.companion.currentHealth, data.companion.maximumHealth,
            animateCompanionHealth, animateCompanionHealth)
        BarVisuals:SetShield(row.companionHealth, GetSetting("showShields") ~= false and data.companion.shield or 0, data.companion.maximumHealth, smooth)
        SetBarText(row.companionHealth, FormatHealth(data.companion))
    end
    UpdateUnitAlpha(row, data)
end

local function PlayDeathTransition(row, dead)
    if GetSetting("showDeathAnimation") == false then
        return
    end
    BarVisuals:PlayFeedback(row.health, dead and "death" or "revive", dead and { r = 1, g = 0.08, b = 0.10 } or { r = 0.62, g = 1, b = 0.72 }, dead and 0.82 or 0.48)
    if dead then
        if not row.deathTimeline then
            local timeline = ANIMATION_MANAGER:CreateTimeline()
            local shrink = timeline:InsertAnimation(ANIMATION_SCALE, row.player, 0)
            shrink:SetDuration(130)
            shrink:SetScaleValues(1, 0.97)
            shrink:SetEasingFunction(ZO_EaseInQuadratic)
            local restore = timeline:InsertAnimation(ANIMATION_SCALE, row.player, 130)
            restore:SetDuration(160)
            restore:SetScaleValues(0.97, 1)
            restore:SetEasingFunction(ZO_EaseOutQuadratic)
            row.deathTimeline = timeline
        end
        row.deathTimeline:PlayFromStart()
    end
end

local function ConfigureRow(row, data, width, identityHeight, healthHeight)
    local previousIdentity = row.identity
    local previousDead = row.dead
    data.identity = data.displayName ~= "" and data.displayName or data.characterName
    row.identity = data.identity
    row.sameIdentity = previousIdentity == data.identity
    row.data = data
    row.player.unitTag = data.unitTag
    row.nameLabel:SetText(GetDisplayText(data))
    row.nameLabel:SetFont(BuildFont(GetSetting("textFontKey"), IsCompactTrial() and 14 or GetSetting("nameTextSize"), GetSetting("textOutline")))
    row.nameLabel:SetColor(0.92, 0.93, 0.96, Clamp(GetSetting("textOpacity"), 10, 100) / 100)
    if data.companion then
        local companionFallback = SI_UNIT_FRAME_NAME_COMPANION and GetString(SI_UNIT_FRAME_NAME_COMPANION) or "Companion"
        row.companionName:SetText(data.companion.characterName ~= "" and data.companion.characterName or companionFallback)
    end

    ApplyRowLayout(row, data, width, identityHeight, healthHeight)
    UpdateRowValues(row, data, false)
    row.control:SetHidden(false)

    if previousIdentity == data.identity and previousDead ~= nil and previousDead ~= data.dead then
        PlayDeathTransition(row, data.dead)
    end
    row.dead = data.dead
end

function GroupFrames:BuildRoster()
    local roster = {}
    local previewSize = self.settingsPreviewActive and (GetSetting("compactTrials") == true and 12 or 4) or self.debugPreviewSize
    if previewSize then
        for index = 1, previewSize do
            roster[index] = BuildPreviewMember(index, previewSize)
        end
        SortRoster(roster)
        return roster
    end

    for index = 1, MAX_GROUP_ROWS do
        local unitTag = GetGroupUnitTagByIndex and GetGroupUnitTagByIndex(index)
        if unitTag and unitTag ~= "" and DoesUnitExist(unitTag) then
            local data = BuildUnitData(unitTag, false)
            local companionTag = GetCompanionUnitTagByGroupUnitTag and GetCompanionUnitTagByGroupUnitTag(unitTag)
            if companionTag and companionTag ~= "" and DoesUnitExist(companionTag) then
                data.companion = BuildUnitData(companionTag, true)
            end
            roster[#roster + 1] = data
        end
    end
    SortRoster(roster)
    return roster
end

function GroupFrames:ApplyPosition()
    local root = self:GetRoot()
    local mover = self:GetMover()
    local mode = GetModeKey()
    local position = GetPosition(mode)
    local x, y
    if position and position.custom then
        x, y = tonumber(position.x), tonumber(position.y)
    end
    if not x or not y then
        x, y = GetDefaultPosition(mode)
    end
    local scale = Clamp(GetSetting("scale"), 70, 160) / 100
    root:SetScale(scale)
    root:ClearAnchors()
    root:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    if Nirnsteel_UI.HUDEditor then
        Nirnsteel_UI.HUDEditor:Apply("groupFrames",root,{
            name="Nirnsteel Group Frames", position=position, enabled=IsEnabled,
            defaultAnchor=function(platform)
                local defaults = PLAYER_DEFAULT_POSITION[platform]
                return ZO_Anchor:New(TOPLEFT,GuiRoot,TOPLEFT,defaults.x,defaults.y)
            end,
            replaces=function(control)
                local name=control:GetName()
                return name == "ZO_SmallGroupAnchorFrame" or name:find("^ZO_LargeGroupAnchorFrame") ~= nil
            end,
            preview=function(active) self:SetSettingsPreviewActive(active) end,
            isPreviewActive=function() return self.settingsPreviewActive end,
        })
    end
    mover:SetScale(scale)
    mover:ClearAnchors()
    mover:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

function GroupFrames:ApplyLayout()
    local root = self:GetRoot()
    local roster = self.roster or {}
    local memberCount = #roster
    local columns = memberCount <= 4 and 1 or memberCount <= 12 and 2 or 3
    local rowsPerColumn = math.max(math.ceil(memberCount / columns), 1)
    local trialMembersPerColumn = math.floor(Clamp(GetSetting("trialMembersPerColumn"), 0, MAX_GROUP_ROWS))
    if memberCount > 4 and trialMembersPerColumn > 0 then
        rowsPerColumn = trialMembersPerColumn
        columns = math.ceil(memberCount / rowsPerColumn)
    end
    local width, identityHeight, healthHeight = GetRowDimensions()
    local rowSpacing = IsCompactTrial() and 4 or Clamp(GetSetting("rowSpacing"), 0, 24)
    local columnSpacing = IsCompactTrial() and 10 or Clamp(GetSetting("columnSpacing"), 0, 40)
    local columnHeights = {}
    local maximumHeight = 1

    self.rowsByUnitTag = {}
    for index, data in ipairs(roster) do
        local row = self.rows[index]
        ConfigureRow(row, data, width, identityHeight, healthHeight)
        local column = math.floor((index - 1) / rowsPerColumn) + 1
        local x = (column - 1) * (width + columnSpacing)
        local y = columnHeights[column] or 0
        row.control:ClearAnchors()
        row.control:SetAnchor(TOPLEFT, root, TOPLEFT, x, y)
        columnHeights[column] = y + row.totalHeight + rowSpacing
        maximumHeight = math.max(maximumHeight, columnHeights[column] - rowSpacing)
        if data.unitTag then
            self.rowsByUnitTag[data.unitTag] = { row = row, data = data, companion = false, rosterIndex = index }
        end
        if data.companion and data.companion.unitTag then
            self.rowsByUnitTag[data.companion.unitTag] = { row = row, data = data.companion, companion = true, owner = data, rosterIndex = index }
        end
    end
    for index = memberCount + 1, #self.rows do
        self.rows[index].control:SetHidden(true)
        self.rows[index].data = nil
    end
    local totalWidth = math.max((columns * width) + ((columns - 1) * columnSpacing), width)
    root:SetDimensions(totalWidth, maximumHeight)
    local mover = self:GetMover()
    mover:SetDimensions(totalWidth, math.max(maximumHeight, 40))
    mover:SetHidden(not IsUnlocked() or (not self.settingsPreviewActive and not self.debugPreviewSize and not IsGrouped()))
    self:ApplyPosition()
end

function GroupFrames:RefreshRoster()
    if not IsEnabled() then
        return
    end
    self:GetRoot()
    self.roster = self:BuildRoster()
    self:ApplyLayout()
    self:UpdateVisibility()
end

function GroupFrames:ScheduleRosterRefresh()
    if self.rosterRefreshPending then
        return
    end
    self.rosterRefreshPending = true
    zo_callLater(function()
        self.rosterRefreshPending = nil
        self:RefreshRoster()
    end, ROSTER_REFRESH_DELAY_MS)
end

local function PlayHealthDeltaFeedback(frame, previousData, updated)
    if GetSetting("feedbackEnabled") ~= true or not previousData or updated.dead then
        return
    end
    local maximum = tonumber(updated.maximumHealth) or 0
    local previous = tonumber(previousData.currentHealth)
    local current = tonumber(updated.currentHealth) or 0
    if not previous or maximum <= 0 then
        return
    end
    local delta = current - previous
    local ratio = math.abs(delta) / maximum
    if ratio < 0.015 then
        return
    end
    local strength = Clamp(GetSetting("feedbackIntensity"), 0, 140) / 100
    local color = GetHealthColor(updated)
    local alpha = Clamp((0.30 + ratio) * strength, 0, 0.72)
    BarVisuals:PlayFeedback(frame, delta > 0 and "gain" or "spend", color, alpha)
    if current >= maximum and previous < maximum then
        BarVisuals:PlayFeedback(frame, "full", color, Clamp(0.55 * strength, 0, 0.82))
    end
end

function GroupFrames:RefreshUnit(unitTag, smooth, pulseShield)
    local lookup = self.rowsByUnitTag and self.rowsByUnitTag[unitTag]
    if not lookup or not DoesUnitExist(unitTag) then
        return
    end
    local updated = BuildUnitData(unitTag, lookup.companion)
    local row = lookup.row
    if lookup.companion then
        local previousData = lookup.data
        local previousShield = lookup.data.shield or 0
        lookup.owner.companion = updated
        lookup.data = updated
        self.roster[lookup.rosterIndex] = lookup.owner
        ApplyRowLayout(row, lookup.owner, Clamp(GetSetting("width"), 180, 420), Clamp(GetSetting("identityHeight"), 16, 32), Clamp(GetSetting("healthHeight"), 12, 42))
        UpdateRowValues(row, lookup.owner, smooth)
        if smooth then
            PlayHealthDeltaFeedback(row.companionHealth, previousData, updated)
        end
        if pulseShield and updated.shield > previousShield and GetSetting("feedbackEnabled") == true then
            local intensity = 0.55 * Clamp(GetSetting("feedbackIntensity"), 0, 140) / 100
            BarVisuals:PlayFeedback(row.companionHealth, "shield", GetSetting("shieldGlowColor"), intensity)
        end
    else
        local previousData = lookup.data
        local previousShield = lookup.data.shield or 0
        updated.companion = lookup.data.companion
        updated.identity = lookup.data.identity
        local previousDead = lookup.data.dead
        lookup.data = updated
        self.roster[lookup.rosterIndex] = updated
        row.data = updated
        row.nameLabel:SetText(GetDisplayText(updated))
        if updated.companion and updated.companion.unitTag then
            local companionLookup = self.rowsByUnitTag[updated.companion.unitTag]
            if companionLookup then
                companionLookup.owner = updated
            end
        end
        ApplyRowLayout(row, updated, Clamp(GetSetting("width"), 180, 420), Clamp(GetSetting("identityHeight"), 16, 32), Clamp(GetSetting("healthHeight"), 12, 42))
        UpdateRowValues(row, updated, smooth)
        if smooth then
            PlayHealthDeltaFeedback(row.health, previousData, updated)
        end
        if previousDead ~= updated.dead then
            PlayDeathTransition(row, updated.dead)
        end
        row.dead = updated.dead
        if pulseShield and updated.shield > previousShield and GetSetting("feedbackEnabled") == true then
            local intensity = 0.65 * Clamp(GetSetting("feedbackIntensity"), 0, 140) / 100
            BarVisuals:PlayFeedback(row.health, "shield", GetSetting("shieldGlowColor"), intensity)
        end
    end
end

function GroupFrames:RefreshAllUnitStates()
    if self.settingsPreviewActive or self.debugPreviewSize then
        return
    end
    local tags = {}
    for unitTag in pairs(self.rowsByUnitTag or {}) do
        tags[#tags + 1] = unitTag
    end
    for _, unitTag in ipairs(tags) do
        self:RefreshUnit(unitTag, false, false)
    end
end

local STOCK_FRAME_TABLES = { "groupFrames", "raidFrames", "companionRaidFrames" }

function GroupFrames:ApplyStockFrameHideReason(manager, hidden)
    for _, key in ipairs(STOCK_FRAME_TABLES) do
        for _, frame in pairs(manager[key] or {}) do
            frame:SetHiddenForReason(STOCK_HIDE_REASON, hidden)
        end
    end
end

function GroupFrames:SetStockFramesHidden(hidden)
    hidden = hidden == true
    if UNIT_FRAMES and UNIT_FRAMES.SetGroupAndRaidFramesHiddenForReason then
        -- The fragment's visibility can change independently of individual frames.
        -- Keep a reason on every cached variant, including inactive raid frames.
        if self.stockHookManager ~= UNIT_FRAMES and ZO_PostHook and UNIT_FRAMES.CreateFrame then
            local manager = UNIT_FRAMES
            ZO_PostHook(manager, "CreateFrame", function()
                if self.stockFramesHidden and IsEnabled() then
                    self:ApplyStockFrameHideReason(manager, true)
                end
            end)
            self.stockHookManager = manager
        end
        UNIT_FRAMES:SetGroupAndRaidFramesHiddenForReason(STOCK_HIDE_REASON, hidden)
        self.stockFramesHidden = hidden
        self:ApplyStockFrameHideReason(UNIT_FRAMES, hidden)
    elseif not hidden then
        self.stockFramesHidden = false
    end
end

function GroupFrames:UpdateScheduler()
    local root = self:GetRoot()
    local recoveryActive = GetSetting("showRecoveryRhythm") == true
    local levelShimmerActive = false
    if GetSetting("showLevelStyle") ~= false then
        for _, row in ipairs(self.rows or {}) do
            if not row.control:IsHidden() and (row.levelShimmerIntensity or 0) > 0 then
                levelShimmerActive = true
                break
            end
        end
    end
    local active = not root:IsHidden() and (recoveryActive or levelShimmerActive)
    if not active then
        root:SetHandler("OnUpdate", nil)
        return
    end
    local startedAtMS = GetFrameTimeMilliseconds()
    self.lastRecoveryMS = self.lastRecoveryMS or startedAtMS
    self.lastLevelShimmerMS = self.lastLevelShimmerMS or (startedAtMS - LEVEL_SHIMMER_CADENCE_MS + 700)
    root:SetHandler("OnUpdate", function()
        local now = GetFrameTimeMilliseconds()
        if recoveryActive and now - (self.lastRecoveryMS or 0) >= RECOVERY_CADENCE_MS then
            self.lastRecoveryMS = now
            for _, row in ipairs(self.rows or {}) do
                if not row.control:IsHidden() then
                    BarVisuals:PlayRecovery(row.health, 0.18)
                    if not row.companion:IsHidden() then
                        BarVisuals:PlayRecovery(row.companionHealth, 0.13)
                    end
                end
            end
        end
        if levelShimmerActive and now - (self.lastLevelShimmerMS or 0) >= LEVEL_SHIMMER_CADENCE_MS then
            self.lastLevelShimmerMS = now
            for _, row in ipairs(self.rows or {}) do
                if not row.control:IsHidden() and (row.levelShimmerIntensity or 0) > 0 then
                    PlayLevelShimmer(row)
                end
            end
        end
    end)
end

function GroupFrames:UpdateVisibility()
    local root = self:GetRoot()
    local preview = self.settingsPreviewActive or self.debugPreviewSize
    local grouped = IsGrouped()
    local show = IsEnabled() and (preview or grouped) and (preview or IsHudSceneShowing()) and #(self.roster or {}) > 0
    root:SetHidden(not show)
    self:GetMover():SetHidden(not show or not IsUnlocked())
    self:SetStockFramesHidden(IsEnabled() and grouped and self.initialized == true and #(self.roster or {}) > 0)
    self:UpdateScheduler()
end

function GroupFrames:SetSettingsPreviewActive(active)
    self.settingsPreviewActive = active == true or nil
    if self.settingsPreviewActive then
        self.debugPreviewSize = nil
    end
    self:RefreshRoster()
end

function GroupFrames:SetDebugPreviewSize(size)
    if size == nil then
        self.debugPreviewSize = nil
    else
        self.debugPreviewSize = Clamp(size, 1, MAX_GROUP_ROWS)
    end
    self:RefreshRoster()
end

function GroupFrames:ReplayPreviewEffects()
    local visible = {}
    for _, row in ipairs(self.rows or {}) do
        if not row.control:IsHidden() then
            visible[#visible + 1] = row
        end
    end
    if visible[1] then
        BarVisuals:PlayFeedback(visible[1].health, "gain", { r = 0.72, g = 1, b = 0.72 }, 0.62)
    end
    if visible[2] then
        BarVisuals:PlayFeedback(visible[2].health, "shield", GetSetting("shieldGlowColor"), 0.72)
    end
    if visible[3] then
        PlayDeathTransition(visible[3], true)
    end
    if GetSetting("showRecoveryRhythm") == true then
        for _, row in ipairs(visible) do
            BarVisuals:PlayRecovery(row.health, 0.22)
        end
    end
    for _, row in ipairs(visible) do
        PlayLevelShimmer(row)
    end
end

function GroupFrames:ResetPosition()
    if Nirnsteel_UI.Settings and Nirnsteel_UI.Settings.ResetGroupFramesPosition then
        Nirnsteel_UI.Settings:ResetGroupFramesPosition(GetModeKey())
    end
    self:ApplyPosition()
end

local function RegisterOptionalEvent(namespace, eventCode, handler)
    if eventCode then
        EVENT_MANAGER:RegisterForEvent(namespace, eventCode, handler)
    end
end

function GroupFrames:RegisterEvents()
    if self.eventsRegistered then
        return
    end
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_GroupUpdate", EVENT_GROUP_UPDATE, function() self:ScheduleRosterRefresh() end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Joined", EVENT_GROUP_MEMBER_JOINED, function() self:ScheduleRosterRefresh() end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Left", EVENT_GROUP_MEMBER_LEFT, function() self:ScheduleRosterRefresh() end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Role", EVENT_GROUP_MEMBER_ROLE_CHANGED, function() self:ScheduleRosterRefresh() end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Leader", EVENT_LEADER_UPDATE, function() self:ScheduleRosterRefresh() end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Connected", EVENT_GROUP_MEMBER_CONNECTED_STATUS, function(_, unitTag) self:RefreshUnit(unitTag, false, false) end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Remote", EVENT_GROUP_MEMBER_IN_REMOTE_REGION, function(_, unitTag) self:RefreshUnit(unitTag, false, false) end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Range", EVENT_GROUP_SUPPORT_RANGE_UPDATE, function(_, unitTag) self:RefreshUnit(unitTag, false, false) end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_GroupType", EVENT_GROUP_TYPE_CHANGED, function() self:ScheduleRosterRefresh() end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_AccountName", EVENT_GROUP_MEMBER_ACCOUNT_NAME_UPDATED, function() self:ScheduleRosterRefresh() end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Created", EVENT_UNIT_CREATED, function() self:ScheduleRosterRefresh() end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Destroyed", EVENT_UNIT_DESTROYED, function() self:ScheduleRosterRefresh() end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Name", EVENT_UNIT_CHARACTER_NAME_CHANGED, function() self:ScheduleRosterRefresh() end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Level", EVENT_LEVEL_UPDATE, function() self:ScheduleRosterRefresh() end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Champion", EVENT_CHAMPION_POINT_UPDATE, function() self:ScheduleRosterRefresh() end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Death", EVENT_UNIT_DEATH_STATE_CHANGED, function(_, unitTag) self:RefreshUnit(unitTag, true, false) end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Power", EVENT_POWER_UPDATE, function(_, unitTag, _, powerType)
        if powerType == HEALTH_POWER_TYPE then
            self:RefreshUnit(unitTag, true, false)
        end
    end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_ShieldAdded", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, function(_, unitTag, visualType)
        if visualType == ATTRIBUTE_VISUAL_POWER_SHIELDING then self:RefreshUnit(unitTag, true, true) end
    end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_ShieldUpdated", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, function(_, unitTag, visualType)
        if visualType == ATTRIBUTE_VISUAL_POWER_SHIELDING then self:RefreshUnit(unitTag, true, true) end
    end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_ShieldRemoved", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, function(_, unitTag, visualType)
        if visualType == ATTRIBUTE_VISUAL_POWER_SHIELDING then self:RefreshUnit(unitTag, true, false) end
    end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Companion", EVENT_ACTIVE_COMPANION_STATE_CHANGED, function() self:ScheduleRosterRefresh() end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_ElectionRequested", EVENT_GROUP_ELECTION_REQUESTED, function() self:ScheduleRosterRefresh() end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_ElectionAdded", EVENT_GROUP_ELECTION_NOTIFICATION_ADDED, function() self:ScheduleRosterRefresh() end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_ElectionProgress", EVENT_GROUP_ELECTION_PROGRESS_UPDATED, function() self:ScheduleRosterRefresh() end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_ElectionResult", EVENT_GROUP_ELECTION_RESULT, function() self:ScheduleRosterRefresh() end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Marker", EVENT_TARGET_MARKER_UPDATE, function() self:ScheduleRosterRefresh() end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Activated", EVENT_PLAYER_ACTIVATED, function() self:RefreshRoster() end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Screen", EVENT_SCREEN_RESIZED, function() self:ApplyPosition() end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Gamepad", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function() self:RefreshRoster() end)

    local function InvalidateSocialCache()
        self.guildCache = {}
        self:ScheduleRosterRefresh()
    end
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_FriendAdded", EVENT_FRIEND_ADDED, InvalidateSocialCache)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_FriendRemoved", EVENT_FRIEND_REMOVED, InvalidateSocialCache)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_FriendStatus", EVENT_FRIEND_PLAYER_STATUS_CHANGED, InvalidateSocialCache)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_GuildAdded", EVENT_GUILD_MEMBER_ADDED, InvalidateSocialCache)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_GuildRemoved", EVENT_GUILD_MEMBER_REMOVED, InvalidateSocialCache)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_GuildStatus", EVENT_GUILD_MEMBER_PLAYER_STATUS_CHANGED, InvalidateSocialCache)

    if CALLBACK_MANAGER then
        CALLBACK_MANAGER:RegisterCallback("UnitFramesCreated", function()
            self:UpdateVisibility()
        end)
    end
    if HUD_SCENE then
        HUD_SCENE:RegisterCallback("StateChange", function() self:UpdateVisibility() end)
    end
    if HUD_UI_SCENE then
        HUD_UI_SCENE:RegisterCallback("StateChange", function() self:UpdateVisibility() end)
    end
    self.eventsRegistered = true
end

function GroupFrames:RefreshSettings()
    self:RegisterEvents()
    if not IsEnabled() then
        if self.root then
            self.root:SetHidden(true)
            self.root:SetHandler("OnUpdate", nil)
        end
        if self.mover then
            self.mover:SetHidden(true)
        end
        self:SetStockFramesHidden(false)
        return
    end

    local ok, errorMessage = pcall(function()
        self:GetRoot()
        self:RefreshRoster()
    end)
    if ok then
        self.initialized = true
        self:UpdateVisibility()
    else
        self.initialized = false
        self:SetStockFramesHidden(false)
        if self.root then
            self.root:SetHidden(true)
        end
        d(string.format("Nirnsteel UI Group Frames: %s", tostring(errorMessage)))
    end
end

local DEBUG_COMMANDS =
{
    ["/nsgroupframes"] = function(argument)
        argument = NormalizeName(argument)
        if argument == "4" or argument == "12" or argument == "24" then
            GroupFrames:SetDebugPreviewSize(tonumber(argument))
        else
            GroupFrames:SetDebugPreviewSize(nil)
        end
    end,
    ["/nsgroupframesfx"] = function()
        GroupFrames:ReplayPreviewEffects()
    end,
}

local function RegisterDebugCommands()
    local enabled = Nirnsteel_UI.Settings and Nirnsteel_UI.Settings:IsDebugModeEnabled()
    for command, handler in pairs(DEBUG_COMMANDS) do
        SLASH_COMMANDS[command] = enabled and handler or nil
    end
end

function GroupFrames:RefreshDebugCommands()
    RegisterDebugCommands()
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE .. "_Loaded", EVENT_ADD_ON_LOADED)
    GroupFrames:RefreshSettings()
    RegisterDebugCommands()
    zo_callLater(function() GroupFrames:RefreshSettings() end, 1000)
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Loaded", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
