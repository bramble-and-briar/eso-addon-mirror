local ADDON_NAME = "AbyssUI"
local EVENT_NAMESPACE = ADDON_NAME .. "_TargetFrame"
local STOCK_HIDE_REASON = ADDON_NAME .. "_TargetFrame"
local UNIT_TAG = "reticleover"
local PLAYER_UNIT_TAG = "reticleoverplayer"
local RECONCILE_NAMESPACE = EVENT_NAMESPACE .. "_Reconcile"

NAGA_UI = NAGA_UI or {}
local NAGA_UI = NAGA_UI
local BarVisuals = NAGA_UI.BarVisuals
local LevelVisuals = NAGA_UI.LevelVisuals
local TargetFrame = {}
NAGA_UI.TargetFrame = TargetFrame

local HEALTH_POWER_TYPE = COMBAT_MECHANIC_FLAGS_HEALTH
local DEFAULT_POSITION = { x = 0, y = 88 }
local MIN_FEEDBACK_DELTA_RATIO = 0.015
local MIN_FEEDBACK_INTERVAL_MS = 140
local LOW_HEALTH_RATIO = 0.35
-- Immortal city guards / unkillable NPCs use a dedicated target-bar presentation.
local IMMORTAL_BAR_COLOR = { r = 0.62, g = 0.45, b = 0.05, a = 1 }
local IMMORTAL_TEXT = "IMORTAL"
local EXECUTE_ICON_SIZE = 18
local EXECUTE_PULSE_DURATION_MS = 900
local IDENTITY_ROW_MIN_HEIGHT = 24
local IDENTITY_ICON_SIZE = 18
local CLASS_ICON_SIZE = 18
local CHAMPION_ICON_SIZE = 14
local CLASS_NAME_GAP = 6
local NAME_LEVEL_GAP = 8
local LEVEL_RANK_GAP = 6
local IDENTITY_ICON_VERTICAL_OFFSET = -2
local LEVEL_BADGE_VERTICAL_OFFSET = 0
-- Nudge CP/level number slightly down relative to the nick midline.
local LEVEL_TEXT_VERTICAL_NUDGE = 2
local HEADER_BAR_GAP = 4
local MARKER_BAR_GAP = 2
local TITLE_BAR_GAP = 2
local TITLE_ROW_MIN_HEIGHT = 14
local DEFAULT_EXECUTE_ICON_KEY = "deathDown"
local TARGET_REFRESH_DELAYS_MS = { 40, 120, 250, 500 }
local TARGET_RECONCILE_INTERVAL_MS = 100
local TARGET_MISSING_GRACE_MS = 150
local TARGET_RECOVERY_DELAY_MS = 500
local TARGET_ERROR_LOG_INTERVAL_MS = 5000



local function GetClassTexture(classId)
    classId = tonumber(classId) or 0
    if classId <= 0 then
        return nil
    end

    local texture
    if ZO_GetPlatformClassIcon then
        texture = ZO_GetPlatformClassIcon(classId)
    end
    if (not texture or texture == "") and ZO_GetClassIcon then
        texture = ZO_GetClassIcon(classId)
    end
    if (not texture or texture == "") and GetClassIndexById and GetClassInfo then
        local classIndex = GetClassIndexById(classId)
        if classIndex then
            local _, _, _, _, _, _, keyboardIcon, gamepadIcon = GetClassInfo(classIndex)
            if IsInGamepadPreferredMode and IsInGamepadPreferredMode() then
                texture = gamepadIcon or keyboardIcon
            else
                texture = keyboardIcon or gamepadIcon
            end
        end
    end
    if (not texture or texture == "") and GetClassIcon then
        texture = GetClassIcon(classId)
    end
    return texture ~= "" and texture or nil
end

local EXECUTE_ICON_TEXTURES =
{
    whiteSkull = "/esoui/art/compass/target_white_skull.dds",
    champion = "/esoui/art/tutorial/gamepad/achievement_categoryicon_champion.dds",
    darkAnchors = "/esoui/art/tutorial/gamepad/achievement_categoryicon_darkanchors.dds",
    avaGeneral = "/esoui/art/ava/ava_rankicon64_general.dds",
    avaLegate = "/esoui/art/ava/ava_rankicon64_legate.dds",
    retrait = "/esoui/art/tutorial/gamepad/gp_inventory_trait_retrait_icon.dds",
    scoring = "/esoui/art/tutorial/gamepad/gp_overview_menuicon_scoring.dds",
    deathDown = "/esoui/art/tutorial/tutorial_idexicon_death_down.dds",
    deathOver = "/esoui/art/tutorial/tutorial_idexicon_death_over.dds",
}

local DEFAULT_SETTINGS =
{
    enabled = true,
    bossDecoration = true,
    unlocked = false,
    scale = 100,
    width = 300,
    barHeight = 25,
    opacity = 100,
    glossEnabled = true,
    barPatternEnabled = true,
    barPatternKey = "Molten",
    barPatternOpacity = 6,
    barPatternScale = 228,
    feedbackEnabled = true,
    feedbackIntensity = 95,
    lossTrailEnabled = false,
    gainPulseEnabled = true,
    spendPulseEnabled = true,
    fullResourcePulseEnabled = true,
    shieldPulseEnabled = true,
    lowResourceGlowEnabled = false,
    borderWidth = 0,
    rpgBorder = true,
    innerShadowAlpha = 60,
    outerShadowAlpha = 100,
    textFontKey = "gameSmall",
    nameTextSize = 20,
    healthTextSize = 18,
    levelTextSize = 16,
    titleTextSize = 14,
    classIconSize = 18,
    championIconSize = 18,
    textOutline = "thick-outline",
    textOpacity = 100,
    textInset = 6,
    textVerticalOffset = 3,
    textColor = { r = 0.96, g = 0.92, b = 0.82 },
    healthTextFormat = "numberAndPercent",
    healthTextPosition = "sides",
    shieldOverlayEnabled = true,
    shieldTextMode = "healthAndShield",
    shieldFillOpacity = 70,
    shieldFillColor = { r = 0.95, g = 0.60, b = 0.33 },
    shieldGlowEnabled = true,
    shieldGlowOpacity = 65,
    shieldGlowColor = { r = 0.95, g = 0.66, b = 0.56 },
    npcColorMode = "static",
    playerColorMode = "static",
    staticColor = { r = 0.78, g = 0.06, b = 0.08 },
    fullHealthColor = { r = 1.00, g = 1.00, b = 1.00 },
    lowHealthColor = { r = 0.58, g = 0.015, b = 0.025 },
    showClass = true,
    showLevel = true,
    showLevelStyle = true,
    showVeterancyIcon = false,
    showTitle = true,
    showExecuteIcon = true,
    executeIconStyle = DEFAULT_EXECUTE_ICON_KEY,
    executeIconScale = 100,
    executeBlinkEnabled = false,
    executeThreshold = 18,
    executePosition = "center",
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

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or minimum
    return math.min(math.max(value, minimum), maximum)
end

local function CopyColor(color, fallback)
    color = color or fallback or {}
    return
    {
        r = tonumber(color.r or color[1]) or tonumber(fallback and fallback.r) or 1,
        g = tonumber(color.g or color[2]) or tonumber(fallback and fallback.g) or 1,
        b = tonumber(color.b or color[3]) or tonumber(fallback and fallback.b) or 1,
        a = tonumber(color.a or color[4]) or tonumber(fallback and fallback.a) or 1,
    }
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

local function GetSettings()
    if NAGA_UI.Settings and NAGA_UI.Settings.GetTargetFrame then
        return NAGA_UI.Settings:GetTargetFrame()
    end
    return DEFAULT_SETTINGS
end

local function GetSetting(key)
    local settings = GetSettings()
    if settings and settings[key] ~= nil then
        return settings[key]
    end
    return DEFAULT_SETTINGS[key]
end

local function GetUnifiedBarTextureKey()
    if NewWorldUI and NewWorldUI.GetSettingValue then
        local key = NewWorldUI:GetSettingValue("barTextureKey")
        if key and key ~= "" then return key end
    end
    if NAGA_UI and NAGA_UI.Settings and NAGA_UI.Settings.GetResourceBars then
        local rb = NAGA_UI.Settings:GetResourceBars()
        if rb and (rb.barTextureKey or rb.healthBarTexture) then
            return rb.barTextureKey or rb.healthBarTexture
        end
    end
    return GetSetting("barTextureKey") or "genericTall"
end

local function GetExecuteIconTexture()
    local texture = EXECUTE_ICON_TEXTURES[GetSetting("executeIconStyle") or DEFAULT_EXECUTE_ICON_KEY]
    if type(texture) == "function" then
        texture = texture()
    end
    if not texture or texture == "" then
        texture = EXECUTE_ICON_TEXTURES[DEFAULT_EXECUTE_ICON_KEY]
    end
    return texture
end

local function IsEnabled()
    return GetSetting("enabled") ~= false
end

local function IsUnlocked()
    return IsEnabled() and GetSetting("unlocked") == true
end

local function IsHudSceneShowing()
    local hudShowing = HUD_SCENE and HUD_SCENE.IsShowing and HUD_SCENE:IsShowing()
    local hudUiShowing = HUD_UI_SCENE and HUD_UI_SCENE.IsShowing and HUD_UI_SCENE:IsShowing()
    if HUD_SCENE or HUD_UI_SCENE then
        if hudShowing or hudUiShowing then
            return true
        end
        return IsGameCameraActive and IsGameCameraActive()
            and (not IsGameCameraUIModeActive or not IsGameCameraUIModeActive())
    end
    return not IsGameCameraActive or IsGameCameraActive()
end

local function GetModeKey()
    return IsInGamepadPreferredMode and IsInGamepadPreferredMode() and "gamepad" or "keyboard"
end

local function GetPosition()
    if NAGA_UI.Settings and NAGA_UI.Settings.GetTargetFramePosition then
        return NAGA_UI.Settings:GetTargetFramePosition(GetModeKey())
    end
    return DEFAULT_POSITION
end

local function BuildFont(sizeKey)
    local face = BarVisuals.Fonts[GetSetting("textFontKey")] or BarVisuals.Fonts.gameSmall
    local size = Clamp(GetSetting(sizeKey), 8, 36)
    local outline = GetSetting("textOutline")
    return outline == "none" and string.format("%s|%d", face, size)
        or string.format("%s|%d|%s", face, size, outline or "thick-outline")
end

local function SafeUnitCall(callback, unitTag, ...)
    if not callback or not unitTag then
        return nil
    end
    local ok, first, second, third = pcall(callback, unitTag, ...)
    if not ok then
        return nil
    end
    return first, second, third
end

local function FormatPlayerName(unitTag)
    local name = SafeUnitCall(ZO_GetPrimaryPlayerNameFromUnitTag, unitTag) or ""
    if name == "" then
        name = SafeUnitCall(GetUnitDisplayName, unitTag) or ""
    end
    if name == "" then
        name = SafeUnitCall(GetUnitName, unitTag) or SafeUnitCall(GetRawUnitName, unitTag)
    end
    return name or ""
end

local function EstimateNameWidth(text)
    text = tostring(text or "")
    text = string.gsub(text, "|c%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    text = string.gsub(text, "|t.-|t", "")
    local characterCount = zo_strlen and zo_strlen(text) or string.len(text)
    local fontSize = Clamp(GetSetting("nameTextSize"), 10, 36)
    return math.max(math.ceil(characterCount * fontSize * 0.66) + 10, 72)
end


-- Fit name into maxWidth. If it does not fit, drop at least 3 characters (when
-- possible) and append "..." so the label never overflows the bar.
local function FitNameWithEllipsis(label, text, maxWidth)
    text = tostring(text or "")
    maxWidth = math.max(tonumber(maxWidth) or 0, 24)
    if label.SetWrapMode then
        label:SetWrapMode(TEXT_WRAP_MODE_NONE)
    end
    if label.SetMaxLineCount then
        label:SetMaxLineCount(1)
    end
    label:SetText(text)
    if label.SetWidth then
        label:SetWidth(0)
    end
    local fullWidth = label.GetTextWidth and tonumber(label:GetTextWidth()) or 0
    if fullWidth <= 0 then
        fullWidth = EstimateNameWidth(text)
    end
    if fullWidth <= maxWidth then
        return text, math.ceil(fullWidth)
    end

    local ellipsis = "..."
    label:SetText(ellipsis)
    local ellipsisWidth = label.GetTextWidth and tonumber(label:GetTextWidth()) or 18
    if ellipsisWidth <= 0 then
        ellipsisWidth = 18
    end
    if maxWidth <= ellipsisWidth + 4 then
        label:SetText(ellipsis)
        return ellipsis, math.ceil(ellipsisWidth)
    end

    local strLen = (zo_strlen and zo_strlen(text)) or string.len(text)
    local strSub = zo_strsub or string.sub
    -- Prefer dropping at least 3 characters when the name is long enough.
    local maxKeep = strLen
    if strLen > 3 then
        maxKeep = strLen - 3
    end
    local lo, hi = 0, maxKeep
    local best = ellipsis
    local bestWidth = ellipsisWidth
    while lo <= hi do
        local mid = math.floor((lo + hi) / 2)
        local candidate = mid > 0 and (strSub(text, 1, mid) .. ellipsis) or ellipsis
        label:SetText(candidate)
        local w = label.GetTextWidth and tonumber(label:GetTextWidth()) or 0
        if w <= 0 then
            w = EstimateNameWidth(candidate)
        end
        if w <= maxWidth then
            best = candidate
            bestWidth = w
            lo = mid + 1
        else
            hi = mid - 1
        end
    end
    label:SetText(best)
    return best, math.ceil(bestWidth)
end

local function FormatNumber(value)
    value = math.max(tonumber(value) or 0, 0)
    if ZO_AbbreviateAndLocalizeNumber then
        return ZO_AbbreviateAndLocalizeNumber(value, NUMBER_ABBREVIATION_PRECISION_TENTHS, USE_LOWERCASE_NUMBER_SUFFIXES)
    end
    return tostring(zo_round(value))
end

local function FormatPercent(current, maximum)
    local percent = maximum > 0 and zo_round((current / maximum) * 100) or 0
    return string.format("%d%%", Clamp(percent, 0, 100))
end

local function DoesTargetUnitExist(unitTag)
    return SafeUnitCall(DoesUnitExist, unitTag) == true
end

local function NormalizeUnitName(name)
    name = tostring(name or "")
    if zo_strformat then
        name = zo_strformat("<<1>>", name)
    end
    if LocaleAwareToLower then
        return LocaleAwareToLower(name)
    end
    return string.lower(name)
end

local function CompareUnitTags(firstTag, secondTag)
    if AreUnitsEqual then
        local ok, equal = pcall(AreUnitsEqual, firstTag, secondTag)
        if ok and equal then
            return true, false
        end
    end
    local function CollectNames(unitTag)
        local names = {}
        local function AddName(name)
            if name and name ~= "" then
                names[#names + 1] = name
            end
        end
        AddName(SafeUnitCall(GetRawUnitName, unitTag))
        AddName(SafeUnitCall(GetUnitName, unitTag))
        AddName(SafeUnitCall(GetUnitDisplayName, unitTag))
        return names
    end
    local firstNames = CollectNames(firstTag)
    local secondNames = CollectNames(secondTag)
    for firstIndex = 1, #firstNames do
        local firstName = firstNames[firstIndex]
        if firstName and firstName ~= "" then
            for secondIndex = 1, #secondNames do
                local secondName = secondNames[secondIndex]
                if secondName and secondName ~= ""
                    and NormalizeUnitName(firstName) == NormalizeUnitName(secondName) then
                    return true, false
                end
            end
        end
    end
    local identityKnown = #firstNames > 0 and #secondNames > 0
    return false, identityKnown
end

local function GetStringUnitValue(getter, preferredTag, fallbackTag)
    local value = SafeUnitCall(getter, preferredTag)
    if (value == nil or value == "") and fallbackTag then
        value = SafeUnitCall(getter, fallbackTag)
    end
    return value or ""
end

local function GetPositiveUnitValue(getter, preferredTag, fallbackTag)
    local value = tonumber((SafeUnitCall(getter, preferredTag))) or 0
    if value <= 0 and fallbackTag then
        value = tonumber((SafeUnitCall(getter, fallbackTag))) or 0
    end
    return math.max(value, 0)
end

local function GetBooleanUnitValue(getter, preferredTag, fallbackTag)
    local value = SafeUnitCall(getter, preferredTag) == true
    if not value and fallbackTag then
        value = SafeUnitCall(getter, fallbackTag) == true
    end
    return value
end

local function GetPlayerName(preferredTag, fallbackTag)
    local name = FormatPlayerName(preferredTag)
    if (not name or name == "") and fallbackTag then
        name = FormatPlayerName(fallbackTag)
    end
    return name or ""
end

local function GetTargetPower(preferredTag, fallbackTag)
    local current, maximum = SafeUnitCall(GetUnitPower, preferredTag, HEALTH_POWER_TYPE)
    if (tonumber(maximum) or 0) <= 0 and fallbackTag then
        current, maximum = SafeUnitCall(GetUnitPower, fallbackTag, HEALTH_POWER_TYPE)
    end
    return math.max(tonumber(current) or 0, 0), math.max(tonumber(maximum) or 0, 0)
end

local function GetTargetMarker(preferredTag, fallbackTag)
    local marker = SafeUnitCall(GetUnitTargetMarkerType, preferredTag) or TARGET_MARKER_TYPE_NONE
    if marker == TARGET_MARKER_TYPE_NONE and fallbackTag then
        marker = SafeUnitCall(GetUnitTargetMarkerType, fallbackTag) or TARGET_MARKER_TYPE_NONE
    end
    return marker
end

local function GetUnitAllianceValue(preferredTag, fallbackTag)
    local alliance = SafeUnitCall(GetUnitAlliance, preferredTag) or ALLIANCE_NONE
    if alliance == ALLIANCE_NONE and fallbackTag then
        alliance = SafeUnitCall(GetUnitAlliance, fallbackTag) or ALLIANCE_NONE
    end
    return alliance
end

local function GetTargetShield(unitTag, fallbackTag)
    if not GetUnitAttributeVisualizerEffectInfo then
        return 0
    end
    local value = SafeUnitCall(
        GetUnitAttributeVisualizerEffectInfo, unitTag, ATTRIBUTE_VISUAL_POWER_SHIELDING,
        STAT_MITIGATION, ATTRIBUTE_HEALTH, HEALTH_POWER_TYPE)
    if (tonumber(value) or 0) <= 0 and fallbackTag then
        value = SafeUnitCall(
            GetUnitAttributeVisualizerEffectInfo, fallbackTag, ATTRIBUTE_VISUAL_POWER_SHIELDING,
            STAT_MITIGATION, ATTRIBUTE_HEALTH, HEALTH_POWER_TYPE)
    end
    return math.max(tonumber(value) or 0, 0)
end

local function ResolvePlayerMetadataTags(primaryExists, playerExists)
    local primaryIsPlayer = primaryExists and SafeUnitCall(IsUnitPlayer, UNIT_TAG) == true
    if primaryExists and playerExists then
        local tagsMatch, identityKnown = CompareUnitTags(UNIT_TAG, PLAYER_UNIT_TAG)
        if tagsMatch then
            return PLAYER_UNIT_TAG, UNIT_TAG, true
        elseif primaryIsPlayer and not identityKnown then
            return UNIT_TAG, PLAYER_UNIT_TAG, true
        end
    end
    if primaryExists then
        return UNIT_TAG, nil, primaryIsPlayer
    end
    return PLAYER_UNIT_TAG, nil, true
end

local function GetChampionData(preferredTag, fallbackTag)
    local champion = GetBooleanUnitValue(IsUnitChampion, preferredTag, fallbackTag)
    if not champion then
        return false, 0
    end
    local points = GetPositiveUnitValue(GetUnitEffectiveChampionPoints, preferredTag, fallbackTag)
    if points <= 0 then
        points = GetPositiveUnitValue(GetUnitChampionPoints, preferredTag, fallbackTag)
    end
    return true, points
end

local function GetPlayerClassData(preferredTag, fallbackTag)
    local classId = GetPositiveUnitValue(GetUnitClassId, preferredTag, fallbackTag)
    local className = GetStringUnitValue(GetUnitClass, preferredTag, fallbackTag)
    return classId, className
end

local function GetUnitLevelValue(preferredTag, fallbackTag)
    local level = GetPositiveUnitValue(GetUnitLevel, preferredTag, fallbackTag)
    if level <= 0 then
        level = GetPositiveUnitValue(GetUnitEffectiveLevel, preferredTag, fallbackTag)
    end
    return level
end

local function IsPlayerTargetTagAvailable()
    return DoesTargetUnitExist(PLAYER_UNIT_TAG)
end

local function IsBossTarget(unitTag, isPlayer)
    if isPlayer or not AreUnitsEqual then return false end
    for index = 1, tonumber(MAX_BOSSES) or 0 do
        local bossTag = "boss" .. index
        if DoesTargetUnitExist(bossTag) and SafeUnitCall(AreUnitsEqual, unitTag, bossTag) == true then
            return true
        end
    end
    return false
end

-- Below-bar caption: AVA rank name + icon for players only (LuiExtended rank mode).
local function StripGenderMarkers(text)
    if not text or text == "" then
        return ""
    end
    return (string.gsub(tostring(text), "%^%a+", ""))
end

local function GetAllianceColorRGB(alliance)
    if GetAllianceColor and alliance and alliance ~= ALLIANCE_NONE then
        local allianceColor = GetAllianceColor(alliance)
        if allianceColor and allianceColor.UnpackRGB then
            local r, g, b = allianceColor:UnpackRGB()
            return { r = r or 1, g = g or 1, b = b or 1 }
        end
    end
    return { r = 1, g = 1, b = 1 }
end

-- Returns rankName, rankValue, rankIconPath, iconColor for player targets.
-- Fully pcall-guarded so a bad rank API never blanks the whole target bar.
local function GetTargetAvaRankInfo(unitTag, alliance)
    local function TryTag(tag)
        if not tag or not GetUnitAvARank then
            return nil
        end
        local okRank, rankValue = pcall(GetUnitAvARank, tag)
        if not okRank then
            return nil
        end
        rankValue = tonumber(rankValue) or 0
        -- Alliance War ranks are 1..50. 0 means no rank / not applicable.
        if rankValue < 1 then
            return nil
        end

        local gender = 0
        if GetUnitGender then
            local okG, g = pcall(GetUnitGender, tag)
            if okG and g ~= nil then
                gender = g
            end
        end

        local rankName = ""
        if GetAvARankName then
            local okN, name = pcall(GetAvARankName, gender, rankValue)
            if okN and name and name ~= "" then
                rankName = StripGenderMarkers(name)
            end
        end

        local iconPath = nil
        if GetAvARankIcon then
            local okI, path = pcall(GetAvARankIcon, rankValue)
            if okI and path and path ~= "" then
                iconPath = path
            end
        end

        if rankName == "" and not iconPath then
            return nil
        end
        return rankName, rankValue, iconPath, GetAllianceColorRGB(alliance)
    end

    local name, rank, icon, color = TryTag(unitTag)
    if name or icon then
        return name or "", rank or 0, icon, color
    end
    if unitTag ~= PLAYER_UNIT_TAG then
        name, rank, icon, color = TryTag(PLAYER_UNIT_TAG)
        if name or icon then
            return name or "", rank or 0, icon, color
        end
    end
    if unitTag ~= UNIT_TAG then
        name, rank, icon, color = TryTag(UNIT_TAG)
        if name or icon then
            return name or "", rank or 0, icon, color
        end
    end
    return "", 0, nil, nil
end

local function IsImmortalTarget(unitTag, isPlayer, isBoss, attackable, name)
    if isPlayer or isBoss or not unitTag then
        return false
    end

    -- ESO exposes invulnerability for many NPCs that cannot be killed.
    if IsUnitInvulnerable then
        local ok, invulnerable = pcall(IsUnitInvulnerable, unitTag)
        if ok and invulnerable == true then
            return true
        end
    end

    -- City guards can be flagged inconsistently by the game depending on zone/state.
    -- Keep a narrow name fallback only for guard NPCs, without changing ordinary NPCs.
    local normalized = NormalizeUnitName(name)
    if normalized ~= "" then
        if string.find(normalized, "guard", 1, true)
            or string.find(normalized, "guarda", 1, true)
            or string.find(normalized, "watchman", 1, true)
            or string.find(normalized, "watcher", 1, true) then
            return true
        end
    end

    return false
end

local function ReadTargetData()
    local primaryExists = DoesTargetUnitExist(UNIT_TAG)
    local playerExists = IsPlayerTargetTagAvailable()
    if not primaryExists and not playerExists then
        return nil
    end

    local unitTag = primaryExists and UNIT_TAG or PLAYER_UNIT_TAG
    local metadataUnitTag, fallbackMetadataUnitTag, isPlayer = ResolvePlayerMetadataTags(primaryExists, playerExists)
    if not primaryExists then
        isPlayer = true
    end
    local resourceFallbackTag = metadataUnitTag ~= unitTag and metadataUnitTag or fallbackMetadataUnitTag
    local current, maximum = GetTargetPower(unitTag, resourceFallbackTag)
    local champion, championPoints = GetChampionData(metadataUnitTag, fallbackMetadataUnitTag)
    local classId, className = 0, ""
    if isPlayer then
        classId, className = GetPlayerClassData(metadataUnitTag, fallbackMetadataUnitTag)
    end
    local level = GetUnitLevelValue(metadataUnitTag, fallbackMetadataUnitTag)
    local marker = GetTargetMarker(unitTag, resourceFallbackTag)
    local name = isPlayer and GetPlayerName(metadataUnitTag, fallbackMetadataUnitTag)
        or GetStringUnitValue(GetUnitName, metadataUnitTag, fallbackMetadataUnitTag)
    if name == "" then
        name = GetStringUnitValue(GetRawUnitName, metadataUnitTag, fallbackMetadataUnitTag)
    end
    local attackable = GetBooleanUnitValue(IsUnitAttackable, unitTag, resourceFallbackTag)
    local isBoss = IsBossTarget(unitTag, isPlayer)
    local immortal = IsImmortalTarget(unitTag, isPlayer, isBoss, attackable, name)
    local alliance = GetUnitAllianceValue(metadataUnitTag, fallbackMetadataUnitTag)
    local title, avaRank, avaRankIcon, avaRankIconColor = "", 0, nil, nil
    if isPlayer and GetSetting("showTitle") ~= false then
        local okRank, t, r, i, c = pcall(GetTargetAvaRankInfo, metadataUnitTag or unitTag, alliance)
        if okRank then
            title, avaRank, avaRankIcon, avaRankIconColor = t or "", r or 0, i, c
        end
        if (title == "" or not avaRankIcon) and fallbackMetadataUnitTag then
            local ok2, t2, r2, i2, c2 = pcall(GetTargetAvaRankInfo, fallbackMetadataUnitTag, alliance)
            if ok2 then
                if title == "" then title = t2 or "" end
                if (avaRank or 0) < 1 then avaRank = r2 or 0 end
                if not avaRankIcon then avaRankIcon, avaRankIconColor = i2, c2 end
            end
        end
        -- Last resort: always try reticleoverplayer for AVA data.
        if title == "" and not avaRankIcon and playerExists then
            local ok3, t3, r3, i3, c3 = pcall(GetTargetAvaRankInfo, PLAYER_UNIT_TAG, alliance)
            if ok3 then
                title, avaRank, avaRankIcon, avaRankIconColor = t3 or "", r3 or 0, i3, c3
            end
        end
    end
    return
    {
        unitTag = unitTag,
        metadataUnitTag = metadataUnitTag,
        fallbackMetadataUnitTag = fallbackMetadataUnitTag,
        name = name,
        title = title,
        avaRank = avaRank,
        avaRankIcon = avaRankIcon,
        avaRankIconColor = avaRankIconColor,
        isPlayer = isPlayer,
        isBoss = isBoss,
        isImmortal = immortal,
        classId = classId,
        className = className or "",
        classIcon = isPlayer and GetClassTexture(classId) or nil,
        level = math.max(tonumber(level) or 0, 0),
        champion = champion,
        championPoints = championPoints,
        current = math.max(tonumber(current) or 0, 0),
        maximum = math.max(tonumber(maximum) or 0, 0),
        shield = GetTargetShield(unitTag, resourceFallbackTag),
        dead = GetBooleanUnitValue(IsUnitDead, unitTag, resourceFallbackTag),
        attackable = attackable,
        alliance = alliance,
        marker = marker,
    }
end

local function GetTargetFingerprint(data)
    if not data then
        return nil
    end
    return table.concat(
    {
        tostring(data.unitTag), tostring(data.metadataUnitTag), tostring(data.name), tostring(data.title),
        tostring(data.avaRank), tostring(data.avaRankIcon), tostring(data.isPlayer),
        tostring(data.classId), tostring(data.classIcon), tostring(data.level),
        tostring(data.champion), tostring(data.championPoints), tostring(data.current), tostring(data.maximum),
        tostring(data.shield), tostring(data.dead), tostring(data.attackable), tostring(data.alliance),
        tostring(data.marker), tostring(data.isBoss), tostring(data.isImmortal),
    }, "\31")
end

local function GetPreviewData(player)
    if player == false then
        return
        {
            name = "The Precursor", title = "", avaRank = 0, avaRankIcon = nil, isPlayer = false, classId = 0, className = "",
            level = 50, champion = false, championPoints = 0, current = 321800, maximum = 400000,
            shield = 0, dead = false, attackable = true, alliance = ALLIANCE_NONE,
            marker = TARGET_MARKER_TYPE_NONE, isImmortal = false, previewReaction = { r = 0.92, g = 0.17, b = 0.14 },
        }
    end
    local previewRank = 20
    local previewIcon = GetAvARankIcon and GetAvARankIcon(previewRank) or "EsoUI/Art/AvA/ava_rankicon64_general.dds"
    local previewName = ""
    if GetAvARankName then
        previewName = StripGenderMarkers(GetAvARankName(0, previewRank) or "") or ""
    end
    if previewName == "" then
        previewName = "General"
    end
    return
    {
        name = "@NagaPreview", title = previewName, avaRank = previewRank,
        avaRankIcon = previewIcon, avaRankIconColor = { r = 0.91, g = 0.80, b = 0.28 },
        isPlayer = true, classId = 2, className = "Sorcerer",
        level = 50, champion = true, championPoints = 2850,
        current = 64000, maximum = 420000, shield = 72000, dead = false, attackable = true,
        alliance = ALLIANCE_ALDMERI_DOMINION, marker = 3, isImmortal = false, previewVeterancy = true,
    }
end

local function GetTargetColor(data)
    if not data.isPlayer then
        if GetSetting("npcColorMode") == "reaction" then
            if data.previewReaction then
                return CopyColor(data.previewReaction)
            end
            if GetUnitReactionColor then
                local r, g, b = GetUnitReactionColor(data.unitTag or UNIT_TAG)
                if r then
                    return { r = r, g = g, b = b, a = 1 }
                end
            end
        end
        return CopyColor(GetSetting("staticColor"), DEFAULT_SETTINGS.staticColor)
    end

    local mode = GetSetting("playerColorMode")
    if mode == "class" then
        local classColors = GetSetting("classColors") or DEFAULT_SETTINGS.classColors
        return CopyColor(classColors[data.classId], GetSetting("unknownClassColor"))
    elseif mode == "health" then
        local ratio = data.maximum > 0 and data.current / data.maximum or 1
        return InterpolateColor(
            CopyColor(GetSetting("lowHealthColor"), DEFAULT_SETTINGS.lowHealthColor),
            CopyColor(GetSetting("fullHealthColor"), DEFAULT_SETTINGS.fullHealthColor),
            ratio)
    end
    return CopyColor(GetSetting("staticColor"), DEFAULT_SETTINGS.staticColor)
end

local function GetAllianceIcon(data)
    if not data.isPlayer then
        return nil, nil
    end
    local unitTag = data.metadataUnitTag or data.unitTag or UNIT_TAG
    if data.previewVeterancy then
        local icon = GetAvARankIcon and GetAvARankIcon(20)
        return icon or "EsoUI/Art/AvA/ava_allianceIcon_aldmeri.dds", { r = 0.91, g = 0.80, b = 0.28 }
    end
    if IsVeterancySeasonActive and IsInVeterancyProgressionZone and GetUnitVeterancyRank
        and IsVeterancySeasonActive() and IsInVeterancyProgressionZone() then
        local rank = tonumber((GetUnitVeterancyRank(unitTag))) or 0
        if rank > 0 and ZO_VeterancyRankData and ZO_VeterancyRankData.New then
            if ZO_VETERANCY_MANAGER and ZO_VETERANCY_MANAGER.GetNumRanks then
                rank = math.min(rank, ZO_VETERANCY_MANAGER:GetNumRanks())
            end
            local ok, rankData = pcall(function() return ZO_VeterancyRankData:New(rank) end)
            if ok and rankData and rankData.GetIcon then
                return rankData:GetIcon(), { r = 1, g = 1, b = 1 }
            end
        end
    end
    if GetUnitAvARank and GetAvARankIcon then
        local rank = tonumber((GetUnitAvARank(unitTag))) or 0
        local color = { r = 1, g = 1, b = 1 }
        if GetAllianceColor and data.alliance and data.alliance ~= ALLIANCE_NONE then
            local allianceColor = GetAllianceColor(data.alliance)
            if allianceColor and allianceColor.UnpackRGB then
                color.r, color.g, color.b = allianceColor:UnpackRGB()
            end
        end
        return GetAvARankIcon(rank), color
    end
    return nil, nil
end

local function CreateCenteredLabel(parent, wrapMode)
    local label = WINDOW_MANAGER:CreateControl(nil, parent, CT_LABEL)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetModifyTextType(MODIFY_TEXT_TYPE_NONE)
    label:SetWrapMode(wrapMode or TEXT_WRAP_MODE_ELLIPSIS)
    label:SetMaxLineCount(1)
    return label
end

local function GetBossCrestGap(data, barHeight)
    local ratio = data.maximum and data.maximum > 0 and data.current / data.maximum or 1
    if GetSetting("showExecuteIcon") ~= false and not data.dead and (data.current or 0) > 0
        and data.attackable and ratio <= Clamp(GetSetting("executeThreshold"), 18, 33) / 100 then
        local iconSize = EXECUTE_ICON_SIZE * Clamp(GetSetting("executeIconScale"), 50, 200) / 100
        return math.max(0, (iconSize - barHeight) * 0.5 + 2)
    end
    return 0
end

local function GetBossBracketWidth(barHeight)
    return Clamp(barHeight * 0.42, 10, 18)
end

local function CreateBossPolygon(parent, points, color)
    local control = WINDOW_MANAGER:CreateControl(nil, parent, CT_POLYGON)
    control:SetMouseEnabled(false)
    control:SetPointLayout(POLYGON_POINT_LAYOUT_CLOCKWISE)
    control:SetSmoothingEnabled(false)
    for _, point in ipairs(points) do control:AddPoint(point[1], point[2]) end
    control:SetBorderDirection(POLYGON_BORDER_DIRECTION_IN)
    control:SetBorderThickness(0, 0, 1)
    control:SetCenterColor(unpack(color))
    control:SetBorderColor(0.00, 0.00, 0.00, 1)
    control:SetDrawLayer(DL_OVERLAY)
    control:SetDrawLevel(7)
    return control
end

function TargetFrame:UpdateBossDecoration(data, barHeight)
    local visible = data and data.isBoss == true and not data.isPlayer and GetSetting("bossDecoration") ~= false
    -- Boss brackets replace the ordinary iron caps; the shared rails remain.
    local ironBorder = GetSetting("rpgBorder") == true
    if self.health and self.health.rpgBorder then
        self.health.rpgBorder.left:SetHidden(not ironBorder or visible)
        self.health.rpgBorder.right:SetHidden(not ironBorder or visible)
    end
    if not visible then
        if self.bossDecoration then self.bossDecoration:SetHidden(true) end
        return
    end
    if not self.bossDecoration then
        local ornaments = WINDOW_MANAGER:CreateControl(nil, self.root, CT_CONTROL)
        ornaments:SetAnchorFill(self.health)
        ornaments:SetMouseEnabled(false)
        -- Boss decoration: dark forged frame. The boss health bar itself is untouched.
        -- Exterior caps use a thin dark-gray edge around the RGB 82,84,87 interior.
        -- Boss decoration color: exact RGB 82,84,87.
        -- The boss health bar itself is not changed.
        local steel = { 82 / 255, 84 / 255, 87 / 255, 1 }
        -- Subtle dark-gray outer edge; keeps the same dimensions and does not enlarge the frame.
        local silver = { 48 / 255, 50 / 255, 53 / 255, 1 }
        local recessedSteel = { 82 / 255, 84 / 255, 87 / 255, 1 }
        -- Convex forged plates avoid the pinched silhouette of the old caps.
        local cap = { {0.35,0}, {1,0.08}, {1,0.92}, {0.35,1}, {0,0.78}, {0,0.22} }
        local rightCap = { {0,0.08}, {0.65,0}, {1,0.22}, {1,0.78}, {0.65,1}, {0,0.92} }
        ornaments.left = CreateBossPolygon(ornaments,
            cap, silver)
        ornaments.right = CreateBossPolygon(ornaments,
            rightCap, silver)
        ornaments.leftInset = CreateBossPolygon(ornaments.left, cap, steel)
        ornaments.rightInset = CreateBossPolygon(ornaments.right, rightCap, steel)
        ornaments.leftInset:SetAnchor(CENTER, ornaments.left, CENTER, 0, 0)
        ornaments.rightInset:SetAnchor(CENTER, ornaments.right, CENTER, 0, 0)
        ornaments.leftInset:SetDrawLevel(8)
        ornaments.rightInset:SetDrawLevel(8)
        local facet = { {0.5,0}, {1,0.5}, {0.5,1}, {0,0.5} }
        local facetColor = { 66 / 255, 68 / 255, 71 / 255, 1 }
        ornaments.leftFacet = CreateBossPolygon(ornaments.left, facet, facetColor)
        ornaments.rightFacet = CreateBossPolygon(ornaments.right, facet, facetColor)
        ornaments.leftFacet:SetAnchor(CENTER, ornaments.left, CENTER, 0, 0)
        ornaments.rightFacet:SetAnchor(CENTER, ornaments.right, CENTER, 0, 0)
        ornaments.leftFacet:SetDrawLevel(9)
        ornaments.rightFacet:SetDrawLevel(9)
        ornaments.rail = CreateBossPolygon(ornaments,
            { {0,0}, {1,0}, {1,1}, {0,1} }, silver)
        ornaments.rail:SetAnchor(TOP, self.health, BOTTOM, 0, 0)
        local crest = { {0,0}, {1,0}, {0.90,0.45}, {0.64,0.70},
            {0.5,1}, {0.36,0.70}, {0.10,0.45} }
        ornaments.crest = CreateBossPolygon(ornaments,
            crest, silver)
        ornaments.crest:SetDimensions(72, 24)
        ornaments.crestInset = CreateBossPolygon(ornaments.crest, crest, recessedSteel)
        ornaments.crestInset:SetDimensions(64, 19)
        ornaments.crestInset:SetAnchor(TOP, ornaments.crest, TOP, 0, 1)
        ornaments.crestInset:SetDrawLevel(8)
        ornaments.skull = WINDOW_MANAGER:CreateControl(nil, ornaments.crest, CT_TEXTURE)
        ornaments.skull:SetDimensions(18, 18)
        ornaments.skull:SetAnchor(TOP, ornaments.crest, TOP, 0, 1)
        ornaments.skull:SetTexture(EXECUTE_ICON_TEXTURES.whiteSkull)
        ornaments.skull:SetColor(0.83, 0.82, 0.75, 1)
        ornaments.skull:SetDrawLayer(DL_OVERLAY)
        ornaments.skull:SetDrawLevel(9)
        ornaments.skull:SetMouseEnabled(false)
        self.bossDecoration = ornaments
    end
    local ornaments = self.bossDecoration
    ornaments.crest:ClearAnchors()
    ornaments.crest:SetAnchor(TOP, self.health, BOTTOM, 0, GetBossCrestGap(data, barHeight))
    local bracketWidth = GetBossBracketWidth(barHeight)
    ornaments.rail:SetHidden(ironBorder)
    ornaments.rail:SetDimensions(Clamp(GetSetting("width"), 180, 700), 1)
    ornaments.leftInset:SetDimensions(bracketWidth - 4, barHeight + 2)
    ornaments.rightInset:SetDimensions(bracketWidth - 4, barHeight + 2)
    ornaments.left:SetDimensions(bracketWidth, barHeight + 8)
    ornaments.right:SetDimensions(bracketWidth, barHeight + 8)
    ornaments.leftFacet:SetDimensions(3, 4)
    ornaments.rightFacet:SetDimensions(3, 4)
    ornaments.left:ClearAnchors()
    ornaments.right:ClearAnchors()
    ornaments.left:SetAnchor(RIGHT, self.health, LEFT, 0, 0)
    ornaments.right:SetAnchor(LEFT, self.health, RIGHT, 0, 0)
    ornaments:SetAlpha(Clamp(GetSetting("opacity"), 10, 100) / 100)
    ornaments:SetHidden(false)
end

function TargetFrame:GetRoot()
    if self.rootReady and self.root then
        return self.root
    end
    -- Prefer XML TLC (inherits ZO_HUDManager_Element) for native Edit HUD
    local root = NAGA_UI_TargetFrameRoot or self.root
    if not root then
        root = WINDOW_MANAGER:CreateTopLevelWindow("NAGA_UI_TargetFrameRoot")
    end
    self.root = root

    root:SetDimensions(DEFAULT_SETTINGS.width, 55)
    root:SetClampedToScreen(true)
    root:SetMouseEnabled(true)
    root:SetDrawTier(DT_MEDIUM)
    root:SetHidden(true)

    if not self.hudRegistered and HUD_MANAGER then
        local ok = pcall(function()
            local opts = { defaultAnchor = ZO_Anchor:New(TOP, nil, TOP, 0, 88) }
            HUD_MANAGER:RegisterKeyboardElement(root, "NAGA Target Frame", opts, COMPASS_OPTIONS)
            HUD_MANAGER:RegisterGamepadElement(root, "NAGA Target Frame", opts, COMPASS_OPTIONS)
        end)
        self.hudRegistered = ok and true or false
        self.hudManaged = ok and true or false
    end

    self.identity = self.identity or WINDOW_MANAGER:CreateControl(nil, root, CT_CONTROL)
    self.identityContent = self.identityContent or WINDOW_MANAGER:CreateControl(nil, self.identity, CT_CONTROL)
    self.nameLabel = self.nameLabel or CreateCenteredLabel(self.identityContent, TEXT_WRAP_MODE_NONE)
    if not self.levelBadge then
        -- CP/level font is independent from the target nick (levelTextSize vs nameTextSize).
        local levelSize = Clamp(GetSetting("levelTextSize"), 8, 36)
        local cpSize = Clamp(GetSetting("championIconSize") or CHAMPION_ICON_SIZE, 8, 32)
        self.levelBadge = LevelVisuals:Create(self.identityContent,
        {
            height = math.max(levelSize, cpSize),
            minimumWidth = 28,
            maximumWidth = 86,
            horizontalPadding = 4,
            font = string.format("$(BOLD_FONT)|%d|thick-outline", levelSize),
            glowFont = string.format("$(BOLD_FONT)|%d|soft-shadow-thick", levelSize),
            fontSize = levelSize,
            showChampionIcon = true,
            championIconSize = cpSize,
            championIconGap = 2,
        })
    end
    self.targetMarker = self.targetMarker or WINDOW_MANAGER:CreateControl(nil, root, CT_TEXTURE)
    self.targetMarker:SetDimensions(IDENTITY_ICON_SIZE, IDENTITY_ICON_SIZE)
    self.targetMarker:SetDrawLayer(DL_OVERLAY)
    self.targetMarker:SetDrawLevel(8)
    self.targetMarker:SetHidden(true)
    self.classIcon = self.classIcon or WINDOW_MANAGER:CreateControl(nil, self.identityContent, CT_TEXTURE)
    self.classIcon:SetDimensions(CLASS_ICON_SIZE, CLASS_ICON_SIZE)
    self.classIcon:SetHidden(true)
    self.rankIcon = self.rankIcon or WINDOW_MANAGER:CreateControl(nil, self.identityContent, CT_TEXTURE)
    self.rankIcon:SetDimensions(IDENTITY_ICON_SIZE, IDENTITY_ICON_SIZE)

    self.health = self.health or BarVisuals:Create(root, nil, { withShield = true })
    BarVisuals:SetAlignment(self.health, BAR_ALIGNMENT_NORMAL)

    -- AVA rank name + icon under the health bar (LuiExtended rank mode).
    -- Expanding the root height by this row keeps target buffs from overlapping it.
    self.titleRankIcon = self.titleRankIcon or WINDOW_MANAGER:CreateControl(nil, root, CT_TEXTURE)
    self.titleRankIcon:SetDimensions(IDENTITY_ICON_SIZE, IDENTITY_ICON_SIZE)
    self.titleRankIcon:SetDrawLayer(DL_OVERLAY)
    self.titleRankIcon:SetDrawLevel(6)
    self.titleRankIcon:SetHidden(true)
    self.titleLabel = self.titleLabel or CreateCenteredLabel(root, TEXT_WRAP_MODE_ELLIPSIS)
    self.titleLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    self.titleLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.titleLabel:SetHidden(true)

    self.executeIcon = self.executeIcon or WINDOW_MANAGER:CreateControl(nil, self.health, CT_TEXTURE)
    self.executeIcon:SetDimensions(EXECUTE_ICON_SIZE, EXECUTE_ICON_SIZE)
    self.executeIcon:SetTexture(GetExecuteIconTexture())
    self.executeIcon:SetColor(1, 0.34, 0.18, 0.96)
    self.executeIcon:SetDrawLayer(DL_OVERLAY)
    self.executeIcon:SetDrawLevel(9)
    self.executeIcon:SetHidden(true)

    self.rootReady = true
    return root
end

function TargetFrame:GetMover()
    if self.moverReady and self.mover then
        return self.mover
    end
    local mover = self.mover or WINDOW_MANAGER:CreateTopLevelWindow("NAGA_UI_TargetFrameMover")
    self.mover = mover
    mover:SetDimensions(DEFAULT_SETTINGS.width, 55)
    mover:SetClampedToScreen(true)
    mover:SetMouseEnabled(true)
    mover:SetMovable(false)
    mover:SetDrawTier(DT_HIGH)
    mover:SetDrawLayer(DL_OVERLAY)
    mover:SetHidden(true)
    local backdrop = self.moverBackdrop or WINDOW_MANAGER:CreateControl(nil, mover, CT_BACKDROP)
    self.moverBackdrop = backdrop
    backdrop:SetAnchorFill(mover)
    backdrop:SetCenterColor(0.02, 0.02, 0.025, 0.30)
    backdrop:SetEdgeColor(0.88, 0.72, 0.24, 0.90)
    backdrop:SetEdgeTexture("EsoUI/Art/Miscellaneous/Gamepad/edgeframeGamepadBorder_thin.dds", 128, 16, 2, 0)
    local label = self.moverLabel or CreateCenteredLabel(mover)
    self.moverLabel = label
    label:ClearAnchors()
    label:SetAnchor(TOP, mover, TOP, 0, 2)
    label:SetFont("ZoFontGameBold")
    label:SetText("NAGA Target Frame")
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
        local x = zo_round(control:GetLeft() + (control:GetWidth() * 0.5) - (GuiRoot:GetWidth() * 0.5))
        local y = zo_round(control:GetTop())
        if NAGA_UI.Settings and NAGA_UI.Settings.SetTargetFramePosition then
            NAGA_UI.Settings:SetTargetFramePosition(x, y, true)
        end
        self:ApplyPosition()
    end)
    self.moverReady = true
    return mover
end

function TargetFrame:ApplyPosition()
    local root = self:GetRoot()
    -- When registered with Edit HUD, game owns position — do not overwrite anchors.
    if self.hudManaged then
        if self.mover then self.mover:SetHidden(true) end
        return
    end
    local position = GetPosition() or DEFAULT_POSITION
    root:ClearAnchors()
    root:SetAnchor(TOP, GuiRoot, TOP, tonumber(position.x) or 0, tonumber(position.y) or DEFAULT_POSITION.y)
    local mover = self:GetMover()
    mover:ClearAnchors()
    mover:SetAnchor(TOP, GuiRoot, TOP, tonumber(position.x) or 0, tonumber(position.y) or DEFAULT_POSITION.y)
end

function TargetFrame:ApplyLayout(data)
    local root = self:GetRoot()
    local width = Clamp(GetSetting("width"), 180, 700)
    local barHeight = Clamp(GetSetting("barHeight"), 10, 48)
    local scale = Clamp(GetSetting("scale"), 70, 160) / 100
    local identityHeight = math.max(
        IDENTITY_ROW_MIN_HEIGHT,
        Clamp(GetSetting("nameTextSize"), 10, 36) + 4,
        Clamp(GetSetting("levelTextSize"), 8, 36) + 4,
        self.levelBadge and self.levelBadge.height or 22)
    local totalHeight = identityHeight + HEADER_BAR_GAP + barHeight
    local decorated = data and data.isBoss == true and not data.isPlayer and GetSetting("bossDecoration") ~= false
    local sidePadding = decorated and GetBossBracketWidth(barHeight)
        or (GetSetting("rpgBorder") == true and 4 or 0)
    local crestExtra = decorated and (24 + GetBossCrestGap(data, barHeight))
        or (GetSetting("rpgBorder") == true and 4 or 0)
    totalHeight = totalHeight + crestExtra

    -- Rank row only reserves space for player AVA rank (name and/or icon).
    local titleText = data and tostring(data.title or "") or ""
    local hasRankIcon = data and data.avaRankIcon and data.avaRankIcon ~= ""
    local hasRankValue = data and (tonumber(data.avaRank) or 0) >= 1
    local showTitle = GetSetting("showTitle") ~= false
        and data
        and data.isPlayer == true
        and (titleText ~= "" or hasRankIcon == true or hasRankValue == true)
    local titleHeight = 0
    if showTitle then
        titleHeight = math.max(
            TITLE_ROW_MIN_HEIGHT,
            IDENTITY_ICON_SIZE,
            Clamp(GetSetting("titleTextSize"), 8, 28) + 2)
        totalHeight = totalHeight + TITLE_BAR_GAP + titleHeight
    end
    self._titleVisible = showTitle
    self._titleHeight = titleHeight

    root:SetScale(scale)
    root:SetDimensions(width + sidePadding * 2, totalHeight)
    self.identity:ClearAnchors()
    self.identity:SetAnchor(TOPLEFT, root, TOPLEFT, sidePadding, 0)
    self.identity:SetDimensions(width, identityHeight)
    self.health:ClearAnchors()
    self.health:SetAnchor(TOPLEFT, root, TOPLEFT, sidePadding, identityHeight + HEADER_BAR_GAP)

    if self.titleLabel then
        self.titleLabel:ClearAnchors()
        if self.titleRankIcon then
            self.titleRankIcon:ClearAnchors()
        end
        if showTitle then
            -- Center icon + rank name as a group under the bar (Lui-style caption).
            local titleTop = identityHeight + HEADER_BAR_GAP + barHeight + crestExtra + TITLE_BAR_GAP
            local iconSize = IDENTITY_ICON_SIZE
            local iconGap = 4
            local textW = 0
            if titleText ~= "" then
                self.titleLabel:SetText(titleText)
                self.titleLabel:SetFont(BuildFont("titleTextSize"))
                textW = self.titleLabel.GetStringWidth and tonumber(self.titleLabel:GetStringWidth(titleText)) or 0
                if textW <= 0 and self.titleLabel.GetTextWidth then
                    textW = tonumber(self.titleLabel:GetTextWidth()) or 0
                end
                if textW <= 0 then
                    textW = math.max(math.ceil(#titleText * Clamp(GetSetting("titleTextSize"), 8, 28) * 0.55), 24)
                end
            end
            local blockW = textW
            if hasRankIcon then
                blockW = blockW + iconSize + (titleText ~= "" and iconGap or 0)
            end
            blockW = math.min(math.max(blockW, 1), width)
            local startX = sidePadding + math.max(0, (width - blockW) * 0.5)
            if hasRankIcon and self.titleRankIcon then
                self.titleRankIcon:SetAnchor(TOPLEFT, root, TOPLEFT, startX,
                    titleTop + math.max(0, (titleHeight - iconSize) * 0.5))
                self.titleRankIcon:SetDimensions(iconSize, iconSize)
                self.titleRankIcon:SetHidden(false)
                self.titleLabel:SetAnchor(LEFT, self.titleRankIcon, RIGHT, iconGap, 0)
                self.titleLabel:SetDimensions(math.max(blockW - iconSize - iconGap, 1), titleHeight)
            else
                if self.titleRankIcon then
                    self.titleRankIcon:SetHidden(true)
                end
                self.titleLabel:SetAnchor(TOPLEFT, root, TOPLEFT, startX, titleTop)
                self.titleLabel:SetDimensions(math.max(blockW, 1), titleHeight)
            end
            self.titleLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            self.titleLabel:SetHidden(titleText == "")
        else
            self.titleLabel:SetHidden(true)
            if self.titleRankIcon then
                self.titleRankIcon:SetHidden(true)
            end
        end
    end

    local mover = self:GetMover()
    mover:SetScale(scale)
    mover:SetDimensions(width + sidePadding * 2, totalHeight)
    self:ApplyPosition()
    return width, barHeight
end

function TargetFrame:ApplyStyle(width, barHeight, color)
    local immortal = self.currentData and self.currentData.isImmortal == true
    local barColor = immortal and CopyColor(IMMORTAL_BAR_COLOR) or color
    local textColor = CopyColor(GetSetting("textColor"), DEFAULT_SETTINGS.textColor)
    local intensity = Clamp(GetSetting("feedbackIntensity"), 0, 140) / 100
    BarVisuals:ApplyStyle(self.health,
    {
        width = width,
        height = barHeight,
        alpha = Clamp(GetSetting("opacity"), 10, 100) / 100,
        borderWidth = Clamp(GetSetting("borderWidth"), 0, 8),
        rpgBorder = GetSetting("rpgBorder") == true,
        innerShadowAlpha = Clamp(GetSetting("innerShadowAlpha"), 0, 100) / 100,
        outerShadowAlpha = Clamp(GetSetting("outerShadowAlpha"), 0, 100) / 100,
        textureInfo = (BarVisuals.GetBarTextureInfo and BarVisuals:GetBarTextureInfo(GetUnifiedBarTextureKey())) or BarVisuals.Textures.genericTall,
        trackColor = { r = 0.01, g = 0.01, b = 0.01, a = 0.62 },
        fillStartColor = barColor,
        fillEndColor = barColor,
        glossEnabled = GetSetting("glossEnabled") ~= false,
        glossOpacity = 0.13,
        patternEnabled = GetSetting("barPatternEnabled") == true,
        patternTexture = BarVisuals.Patterns[GetSetting("barPatternKey")] or BarVisuals.Patterns.smoke,
        patternOpacity = Clamp(GetSetting("barPatternOpacity"), 0, 100) / 100,
        patternScale = Clamp(GetSetting("barPatternScale"), 24, 512),
        lossTrailEnabled = GetSetting("lossTrailEnabled") == true,
        lossTrailColor = { r = 1.00, g = 0.70, b = 0.24, a = 0.78 },
        shieldEnabled = GetSetting("shieldOverlayEnabled") ~= false,
        shieldFillColor = GetSetting("shieldFillColor"),
        shieldFillOpacity = Clamp(GetSetting("shieldFillOpacity"), 0, 100) / 100,
        shieldGlowEnabled = GetSetting("shieldGlowEnabled") ~= false,
        shieldGlowColor = GetSetting("shieldGlowColor"),
        shieldGlowOpacity = Clamp(GetSetting("shieldGlowOpacity"), 0, 100) / 100,
        shieldUseOuterDimensions = true,
        font = BuildFont("healthTextSize"),
        textColor = textColor,
        textOpacity = Clamp(GetSetting("textOpacity"), 10, 100) / 100,
        textInset = Clamp(GetSetting("textInset"), 0, 28),
        textVerticalOffset = Clamp(GetSetting("textVerticalOffset"), -8, 8),
        alignment = BAR_ALIGNMENT_NORMAL,
        lowGlowEnabled = GetSetting("feedbackEnabled") == true and GetSetting("lowResourceGlowEnabled") ~= false,
        lowGlowThreshold = LOW_HEALTH_RATIO,
        lowGlowColor = GetSetting("lowHealthColor"),
        feedbackIntensity = intensity,
    })
    local textAlpha = Clamp(GetSetting("textOpacity"), 10, 100) / 100
    self.nameLabel:SetFont(BuildFont("nameTextSize"))
    self.nameLabel:SetColor(textColor.r, textColor.g, textColor.b, textAlpha)
    if self.titleLabel then
        self.titleLabel:SetFont(BuildFont("titleTextSize"))
        -- Slightly softer than the name so the rank caption reads as secondary info.
        self.titleLabel:SetColor(textColor.r, textColor.g, textColor.b, textAlpha * 0.88)
    end
    self:UpdateBossDecoration(self.currentData, barHeight)
end

function TargetFrame:UpdateIdentity(data)
    self.nameLabel:SetText(data.name or "")
    self.nameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    if self.titleLabel then
        local show = GetSetting("showTitle") ~= false and data.isPlayer == true
        local title = show and tostring(data.title or "") or ""
        local iconPath = show and data.avaRankIcon or nil
        -- Fallback: if API gave rank number but empty localized name, show the number.
        if show and title == "" and data.avaRank and tonumber(data.avaRank) and tonumber(data.avaRank) >= 1 then
            title = tostring(data.avaRank)
        end
        self.titleLabel:SetText(title)
        self.titleLabel:SetHidden(title == "")
        if self.titleRankIcon then
            if iconPath and iconPath ~= "" then
                local okTex = pcall(function() self.titleRankIcon:SetTexture(iconPath) end)
                if okTex then
                    local c = data.avaRankIconColor or { r = 1, g = 1, b = 1 }
                    self.titleRankIcon:SetColor(c.r or 1, c.g or 1, c.b or 1, 1)
                    self.titleRankIcon:SetHidden(false)
                else
                    self.titleRankIcon:SetHidden(true)
                end
            else
                self.titleRankIcon:SetHidden(true)
            end
        end
    end
    local hasLevel
    if data.champion then
        hasLevel = (tonumber(data.championPoints) or 0) > 0
    else
        hasLevel = (tonumber(data.level) or 0) > 0
    end

    -- Icon sizes from settings (class + champion CP icon).
    local classSize = Clamp(GetSetting("classIconSize") or CLASS_ICON_SIZE, 12, 36)
    local cpIconSize = Clamp(GetSetting("championIconSize") or CHAMPION_ICON_SIZE, 8, 32)

    local barWidth = self.identity and self.identity.GetWidth and self.identity:GetWidth() or Clamp(GetSetting("width"), 180, 700)

    -- CP/level size is independent from nick (levelTextSize ≠ nameTextSize).
    -- CP icon uses championIconSize directly so the CP Icon Size slider works.
    local levelSize = Clamp(GetSetting("levelTextSize"), 8, 36)
    local levelWidth, tierIndex = LevelVisuals:Apply(self.levelBadge, data,
    {
        shown = GetSetting("showLevel") ~= false and hasLevel,
        styled = GetSetting("showLevelStyle") ~= false,
        playOnTierUpgrade = self.sameIdentity == true,
        previousTier = self.levelTier,
        fontSize = levelSize,
        height = math.max(levelSize, cpIconSize),
        championIconSize = cpIconSize,
        maximumWidth = math.max(40, math.floor(barWidth * 0.35)),
    })

    local markerVisible = data.marker and data.marker ~= TARGET_MARKER_TYPE_NONE
    self.targetMarker:SetHidden(not markerVisible)
    if markerVisible and ZO_GetPlatformTargetMarkerIcon then
        self.targetMarker:SetTexture(ZO_GetPlatformTargetMarkerIcon(data.marker))
    end
    self.targetMarker:ClearAnchors()
    self.targetMarker:SetAnchor(BOTTOMRIGHT, self.health, TOPLEFT, -MARKER_BAR_GAP, -MARKER_BAR_GAP)
    local classTexture = data.classIcon
    if (not classTexture or classTexture == "") and data.isPlayer then
        classTexture = GetClassTexture(data.classId)
        data.classIcon = classTexture
    end
    local classVisible = data.isPlayer and GetSetting("showClass") ~= false and classTexture ~= nil
        and classTexture ~= ""
    self.classIcon:SetHidden(not classVisible)
    if classVisible then
        self.classIcon:SetTexture(classTexture)
        self.classIcon:SetDimensions(classSize, classSize)
        self.classIcon:SetColor(1, 1, 1, Clamp(GetSetting("textOpacity"), 10, 100) / 100)
    end
    local icon, iconColor
    if GetSetting("showVeterancyIcon") == true then
        icon, iconColor = GetAllianceIcon(data)
    end
    self.rankIcon:SetHidden(not icon)
    if icon then
        self.rankIcon:SetTexture(icon)
        self.rankIcon:SetDimensions(IDENTITY_ICON_SIZE, IDENTITY_ICON_SIZE)
        self.rankIcon:SetColor(iconColor.r, iconColor.g, iconColor.b, 1)
    end

    -- Centered group above the bar: [class] [nick...] [level/CP] [(rank)].
    -- Name is manually ellipsized ("...") so it never pushes level/CP outside the bar.
    local levelVisible = levelWidth > 0
    local rankW = icon and IDENTITY_ICON_SIZE or 0
    local nameSize = Clamp(GetSetting("nameTextSize"), 10, 36)
    -- Cap class icon to the name line so it does not sit taller than the nick.
    classSize = math.min(classSize, nameSize)
    local classW = classVisible and classSize or 0
    local gapClass = classVisible and CLASS_NAME_GAP or 0
    local gapLevel = levelVisible and NAME_LEVEL_GAP or 0
    local gapRank = icon and (levelVisible and LEVEL_RANK_GAP or NAME_LEVEL_GAP) or 0
    local reserved = classW + gapClass + levelWidth + gapLevel + rankW + gapRank
    local nameMax = math.max(barWidth - reserved, 32)

    local displayName, nameWidth = FitNameWithEllipsis(self.nameLabel, data.name or "", nameMax)
    self.nameLabel:SetText(displayName)
    self.nameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    self.nameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local contentWidth = classW + gapClass + nameWidth + gapLevel + levelWidth + gapRank + rankW
    contentWidth = math.min(math.max(contentWidth, 1), barWidth)

    -- Shared midline height (nick + L25/CP) so sub-50 levels align with the name.
    local identityH = math.max(self.identity:GetHeight() or 0, nameSize, levelSize, classSize)

    self.identityContent:ClearAnchors()
    self.identityContent:SetAnchor(CENTER, self.identity, CENTER, 0, 0)
    self.identityContent:SetDimensions(contentWidth, identityH)
    self.classIcon:ClearAnchors()
    self.nameLabel:ClearAnchors()
    self.levelBadge.control:ClearAnchors()
    self.rankIcon:ClearAnchors()

    local x = 0
    local midY = identityH * 0.5
    local function AnchorOnMidline(control, width, yNudge)
        control:ClearAnchors()
        control:SetAnchor(CENTER, self.identityContent, TOPLEFT, x + width * 0.5, midY + (yNudge or 0))
    end

    if classVisible then
        self.classIcon:SetDimensions(classSize, classSize)
        AnchorOnMidline(self.classIcon, classSize, 0)
        x = x + classSize + CLASS_NAME_GAP
    end

    self.nameLabel:SetDimensions(nameWidth, identityH)
    AnchorOnMidline(self.nameLabel, nameWidth, 0)
    x = x + nameWidth

    if levelVisible then
        x = x + NAME_LEVEL_GAP
        -- Drop CP/level slightly so the digits sit lower than the nick optical center.
        AnchorOnMidline(self.levelBadge.control, levelWidth, 0)
        x = x + levelWidth
    end

    if icon then
        x = x + (levelVisible and LEVEL_RANK_GAP or NAME_LEVEL_GAP)
        self.rankIcon:SetDimensions(IDENTITY_ICON_SIZE, IDENTITY_ICON_SIZE)
        AnchorOnMidline(self.rankIcon, IDENTITY_ICON_SIZE, 0)
    end
    self.levelTier = tierIndex
end

function TargetFrame:UpdateText(data)
    if data and data.isImmortal == true then
        self.health.leftLabel:SetHidden(true)
        self.health.rightLabel:SetHidden(true)
        self.health.centerLabel:SetText(IMMORTAL_TEXT)
        self.health.centerLabel:SetHidden(false)
        return
    end
    local format = GetSetting("healthTextFormat") or "numberAndPercent"
    local position = GetSetting("healthTextPosition") or "sides"
    local shieldMode = GetSetting("shieldTextMode") or "healthAndShield"
    local numberText = FormatNumber(data.current)
    if data.shield > 0 and shieldMode == "healthAndShield" then
        numberText = string.format("%s + %s", numberText, FormatNumber(data.shield))
    elseif shieldMode == "shieldOnly" then
        numberText = data.shield > 0 and FormatNumber(data.shield) or ""
    end
    local percentText = FormatPercent(data.current, data.maximum)
    self.health.leftLabel:SetHidden(true)
    self.health.centerLabel:SetHidden(true)
    self.health.rightLabel:SetHidden(true)
    if format == "none" then
        return
    end

    if format == "numberAndPercent" and position == "sides" then
        self.health.leftLabel:SetText(numberText)
        self.health.rightLabel:SetText(percentText)
        self.health.leftLabel:SetHidden(numberText == "")
        self.health.rightLabel:SetHidden(false)
        return
    end

    local text
    if format == "number" then
        text = numberText
        if position == "sides" then
            position = "left"
        end
    elseif format == "percent" then
        text = percentText
        if position == "sides" then
            position = "right"
        end
    else
        text = numberText ~= "" and string.format("%s  %s", numberText, percentText) or percentText
    end

    local label
    if position == "left" then
        label = self.health.leftLabel
    elseif position == "right" then
        label = self.health.rightLabel
    else
        label = self.health.centerLabel
    end
    label:SetText(text)
    label:SetHidden(text == "")
end

function TargetFrame:ResetExecuteIconPulse()
    self.executePulseStartMS = nil
    if self.executeIcon then
        self.executeIcon:SetAlpha(1)
        self.executeIcon:SetScale(1)
    end
end

function TargetFrame:UpdateExecuteIconPulse(nowMS)
    if not self.executeIcon then
        return
    end

    self.executePulseStartMS = self.executePulseStartMS or nowMS
    local progress = ((nowMS - self.executePulseStartMS) % EXECUTE_PULSE_DURATION_MS) / EXECUTE_PULSE_DURATION_MS
    local pulse = 0.5 + (0.5 * math.cos(progress * math.pi * 2))
    self.executeIcon:SetAlpha(0.35 + (pulse * 0.65))
    self.executeIcon:SetScale(0.92 + (pulse * 0.16))
end

function TargetFrame:UpdateExecute(data)
    local ratio = data.maximum > 0 and data.current / data.maximum or 1
    local show = not data.isImmortal and GetSetting("showExecuteIcon") ~= false and not data.dead and data.current > 0
        and data.attackable and ratio <= (Clamp(GetSetting("executeThreshold"), 18, 33) / 100)
    local executeIconSize = EXECUTE_ICON_SIZE * (Clamp(GetSetting("executeIconScale"), 50, 200) / 100)
    self.executeIcon:SetDimensions(executeIconSize, executeIconSize)
    self.executeIcon:SetTexture(GetExecuteIconTexture())
    self.executeIcon:SetHidden(not show)
    if not show then
        self:ResetExecuteIconPulse()
        return
    end
    if GetSetting("executeBlinkEnabled") ~= true then
        self:ResetExecuteIconPulse()
    end
    local position = GetSetting("executePosition") or "center"
    self.executeIcon:ClearAnchors()
    if position == "left" then
        self.executeIcon:SetAnchor(LEFT, self.health, LEFT, Clamp(GetSetting("textInset"), 0, 28), 0)
        if not self.health.leftLabel:IsHidden() then
            self.health.leftLabel:ClearAnchors()
            self.health.leftLabel:SetAnchor(LEFT, self.health, LEFT, Clamp(GetSetting("textInset"), 0, 28) + executeIconSize + 3,
                Clamp(GetSetting("textVerticalOffset"), -8, 8))
        end
    elseif position == "right" then
        self.executeIcon:SetAnchor(RIGHT, self.health, RIGHT, -Clamp(GetSetting("textInset"), 0, 28), 0)
        if not self.health.rightLabel:IsHidden() then
            self.health.rightLabel:ClearAnchors()
            self.health.rightLabel:SetAnchor(RIGHT, self.health, RIGHT, -(Clamp(GetSetting("textInset"), 0, 28) + executeIconSize + 3),
                Clamp(GetSetting("textVerticalOffset"), -8, 8))
        end
    else
        if not self.health.centerLabel:IsHidden() then
            local centerText = self.health.centerLabel.GetText and self.health.centerLabel:GetText() or ""
            local textWidth = self.health.centerLabel.GetStringWidth
                and self.health.centerLabel:GetStringWidth(centerText)
                or self.health.centerLabel:GetTextWidth()
            textWidth = math.max(tonumber(textWidth) or 0, 1)
            local gap = 4
            local groupWidth = executeIconSize + gap + textWidth
            local iconOffset = (-groupWidth * 0.5) + (executeIconSize * 0.5)
            local textOffset = (-groupWidth * 0.5) + executeIconSize + gap + (textWidth * 0.5)
            self.executeIcon:SetAnchor(CENTER, self.health, CENTER, iconOffset, 0)
            self.health.centerLabel:ClearAnchors()
            self.health.centerLabel:SetAnchor(CENTER, self.health, CENTER, textOffset,
                Clamp(GetSetting("textVerticalOffset"), -8, 8))
        else
            self.executeIcon:SetAnchor(CENTER, self.health, CENTER, 0, 0)
        end
    end
end

function TargetFrame:ResetTargetState()
    self.previousHealth = nil
    self.previousMaximum = nil
    self.previousShield = nil
    self.previousDead = nil
    self.levelTier = nil
    self.sameIdentity = false
    self.targetIdentity = nil
    self.currentFingerprint = nil
    if self.health then
        BarVisuals:HideFeedback(self.health)
        BarVisuals:StopLossTrail(self.health, 0, 0)
        BarVisuals:SetShield(self.health, 0, 0, false)
    end
    if self.executeIcon then
        self:ResetExecuteIconPulse()
        self.executeIcon:SetHidden(true)
    end
    if self.levelBadge then
        LevelVisuals:Stop(self.levelBadge)
    end
end

function TargetFrame:UpdateFeedback(data, instant)
    local previous = self.previousHealth
    local previousMaximum = self.previousMaximum
    local previousShield = self.previousShield or 0
    local previousDead = self.previousDead
    local now = GetFrameTimeMilliseconds()
    local intensity = Clamp(GetSetting("feedbackIntensity"), 0, 140) / 100
    local enabled = not instant and GetSetting("feedbackEnabled") == true and intensity > 0
    local meaningful = data.maximum > 0 and previous ~= nil
        and math.abs(data.current - previous) / data.maximum >= MIN_FEEDBACK_DELTA_RATIO
        and now - (self.lastFeedbackMS or 0) >= MIN_FEEDBACK_INTERVAL_MS
    if enabled and meaningful and data.current > previous and GetSetting("gainPulseEnabled") ~= false then
        BarVisuals:PlayFeedback(self.health, "gain", { r = 0.56, g = 1.00, b = 0.60 }, intensity)
        self.lastFeedbackMS = now
    elseif enabled and meaningful and data.current < previous and GetSetting("spendPulseEnabled") ~= false then
        BarVisuals:PlayFeedback(self.health, "spend", { r = 1.00, g = 0.22, b = 0.18 }, intensity)
        self.lastFeedbackMS = now
    end
    if enabled and previousMaximum and previous < previousMaximum and data.current >= data.maximum
        and GetSetting("fullResourcePulseEnabled") ~= false then
        BarVisuals:PlayFeedback(self.health, "full", { r = 1.00, g = 0.92, b = 0.42 }, intensity)
    end
    if enabled and data.shield > previousShield and GetSetting("shieldPulseEnabled") ~= false then
        BarVisuals:PlayFeedback(self.health, "shield", GetSetting("shieldGlowColor"), intensity)
    end
    if enabled and previousDead ~= nil and previousDead ~= data.dead then
        BarVisuals:PlayFeedback(self.health, data.dead and "death" or "revive",
            data.dead and { r = 0.95, g = 0.10, b = 0.10 } or { r = 0.42, g = 1.00, b = 0.58 }, intensity)
    end
end

function TargetFrame:ApplyTargetData(data, instant)
    self.currentData = data
    if not data then
        self:UpdateBossDecoration(nil)
        self:ResetTargetState()
        self.lastLiveData = nil
        self.currentFingerprint = nil
        self.missingTargetSinceMS = nil
        self:GetRoot():SetHidden(true)
        self:GetMover():SetHidden(true)
        self:UpdateScheduler()
        return false
    end

    self.missingTargetSinceMS = nil
    local identity = string.format("%s:%s", tostring(data.name), tostring(data.isPlayer))
    if identity ~= self.targetIdentity then
        self:ResetTargetState()
        self.targetIdentity = identity
        -- Target swaps must never inherit or start a health transition. Some
        -- lifecycle paths arrive through power updates before the dedicated
        -- reticle event, so enforce the snap here at the identity boundary.
        instant = true
    else
        self.sameIdentity = true
    end
    local width, barHeight = self:ApplyLayout(data)
    local color = GetTargetColor(data)
    self:ApplyStyle(width, barHeight, color)
    self:UpdateIdentity(data)
    self:UpdateFeedback(data, instant)
    BarVisuals:SetValue(self.health, data.current, data.maximum, not instant,
        not instant and GetSetting("lossTrailEnabled") == true)
    BarVisuals:SetShield(self.health, data.shield, data.maximum, not instant)
    self:UpdateText(data)
    self:UpdateExecute(data)
    self.previousHealth = data.current
    self.previousMaximum = data.maximum
    self.previousShield = data.shield
    self.previousDead = data.dead
    self.currentFingerprint = GetTargetFingerprint(data)
    self:UpdateVisibility()
    return true
end

function TargetFrame:RefreshTarget(instant, retainOnMissing)
    local data
    if self.settingsPreviewActive or self.debugPreviewMode then
        data = GetPreviewData(self.debugPreviewMode ~= "npc")
        if self.settingsPreviewActive and self.previewBoss then
            data = GetPreviewData(false)
            data.name = "The Walking Nightmare"
            data.isBoss = true
        end
    elseif IsUnlocked() then
        local liveData = ReadTargetData()
        if liveData then
            self.lastLiveData = liveData
        end
        data = liveData or self.lastLiveData or GetPreviewData(true)
    else
        data = ReadTargetData()
        if data then
            self.lastLiveData = data
        end
    end
    if not data and retainOnMissing and self.currentData then
        self.missingTargetSinceMS = self.missingTargetSinceMS or GetFrameTimeMilliseconds()
        return false
    end
    return self:ApplyTargetData(data, instant)
end

function TargetFrame:ReconcileTarget()
    if not IsEnabled() or self.initialized ~= true or self.settingsPreviewActive or self.debugPreviewMode
        or IsUnlocked() then
        self.missingTargetSinceMS = nil
        return
    end

    local data = ReadTargetData()
    if data then
        self.missingTargetSinceMS = nil
        local fingerprint = GetTargetFingerprint(data)
        if not self.currentData or fingerprint ~= self.currentFingerprint then
            local identity = string.format("%s:%s", tostring(data.name), tostring(data.isPlayer))
            self:ApplyTargetData(data, not self.currentData or identity ~= self.targetIdentity)
        elseif self.root and self.root:IsHidden() and IsHudSceneShowing() then
            self:UpdateVisibility()
        end
        return
    end

    if not self.currentData then
        self.missingTargetSinceMS = nil
        return
    end
    local now = GetFrameTimeMilliseconds()
    self.missingTargetSinceMS = self.missingTargetSinceMS or now
    if now - self.missingTargetSinceMS >= TARGET_MISSING_GRACE_MS then
        self:ApplyTargetData(nil, true)
    end
end

function TargetFrame:HandleRuntimeFailure(context, errorMessage)
    local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
    self.runtimeRecoveryActive = true
    self.runtimeRecoveryAfterMS = now + TARGET_RECOVERY_DELAY_MS
    self.currentData = nil
    self.lastLiveData = nil
    self.currentFingerprint = nil
    self.missingTargetSinceMS = nil
    pcall(function() self:ResetTargetState() end)
    if self.root then
        self.root:SetHidden(true)
        self.root:SetHandler("OnUpdate", nil)
    end
    if self.mover then self.mover:SetHidden(true) end
    self:SetStockFrameHidden(false)
    if d and (not self.lastRuntimeErrorLogMS or now - self.lastRuntimeErrorLogMS >= TARGET_ERROR_LOG_INTERVAL_MS) then
        self.lastRuntimeErrorLogMS = now
        d(string.format("NAGA Target Frame %s: %s", tostring(context or "update"), tostring(errorMessage)))
    end
end

function TargetFrame:RunGuarded(context, callback)
    local ok, errorMessage = pcall(callback)
    if not ok then
        self:HandleRuntimeFailure(context, errorMessage)
    end
    return ok
end

function TargetFrame:SetReconciliationEnabled(enabled)
    if EVENT_MANAGER.UnregisterForUpdate then
        EVENT_MANAGER:UnregisterForUpdate(RECONCILE_NAMESPACE)
    end
    self.reconciliationEnabled = nil
    self.runtimeRecoveryActive = nil
    self.runtimeRecoveryAfterMS = nil
    if not enabled or not EVENT_MANAGER.RegisterForUpdate then
        return
    end
    self.reconciliationEnabled = true
    EVENT_MANAGER:RegisterForUpdate(RECONCILE_NAMESPACE, TARGET_RECONCILE_INTERVAL_MS, function()
        local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
        if self.runtimeRecoveryActive and now < (self.runtimeRecoveryAfterMS or 0) then
            return
        end
        local recovering = self.runtimeRecoveryActive == true
        self:RunGuarded("reconciliation", function()
            self:ReconcileTarget()
            if recovering and self.currentData then
                self.runtimeRecoveryActive = nil
                self.runtimeRecoveryAfterMS = nil
                self:SetStockFrameHidden(true)
                self:UpdateVisibility()
            end
        end)
    end)
end

function TargetFrame:SetStockFrameHidden(hidden)
    hidden = hidden == true and self.runtimeRecoveryActive ~= true
    if UNIT_FRAMES and UNIT_FRAMES.SetFrameHiddenForReason then
        if hidden and UNIT_FRAMES.GetFrame and not UNIT_FRAMES:GetFrame(UNIT_TAG) then
            self.stockFrameHidden = false
            self.stockHideRetryCount = (self.stockHideRetryCount or 0) + 1
            if self.stockHideRetryCount <= 20 and not self.stockHideRetryPending then
                self.stockHideRetryPending = true
                local retryToken = (self.stockHideRetryToken or 0) + 1
                self.stockHideRetryToken = retryToken
                zo_callLater(function()
                    if self.stockHideRetryToken ~= retryToken then
                        return
                    end
                    self.stockHideRetryPending = false
                    if IsEnabled() and self.initialized == true then
                        self:SetStockFrameHidden(true)
                    end
                end, 250)
            end
            return
        end
        local ok = pcall(function()
            UNIT_FRAMES:SetFrameHiddenForReason(UNIT_TAG, STOCK_HIDE_REASON, hidden)
        end)
        self.stockFrameHidden = ok and hidden or false
        if ok and hidden then
            self.stockHideRetryCount = 0
            self.stockHideRetryPending = false
        elseif not hidden then
            self.stockHideRetryToken = (self.stockHideRetryToken or 0) + 1
            self.stockHideRetryCount = 0
            self.stockHideRetryPending = false
        end
    elseif not hidden then
        self.stockFrameHidden = false
    end
end

function TargetFrame:UpdateScheduler()
    local root = self:GetRoot()
    local levelShimmerActive = not root:IsHidden() and self.levelBadge and (self.levelBadge.shimmerIntensity or 0) > 0
        and GetSetting("showLevelStyle") ~= false
    local executePulseActive = not root:IsHidden() and self.executeIcon and not self.executeIcon:IsHidden()
        and GetSetting("executeBlinkEnabled") == true
    if not executePulseActive then
        self:ResetExecuteIconPulse()
    end
    if not levelShimmerActive and not executePulseActive then
        root:SetHandler("OnUpdate", nil)
        return
    end
    local nowMS = GetFrameTimeMilliseconds()
    if levelShimmerActive then
        self.lastLevelShimmerMS = self.lastLevelShimmerMS
            or (nowMS - LevelVisuals.SHIMMER_CADENCE_MS + 700)
    end
    if executePulseActive then
        self:UpdateExecuteIconPulse(nowMS)
    end
    root:SetHandler("OnUpdate", function()
        local now = GetFrameTimeMilliseconds()
        if levelShimmerActive and now - (self.lastLevelShimmerMS or 0) >= LevelVisuals.SHIMMER_CADENCE_MS then
            self.lastLevelShimmerMS = now
            LevelVisuals:Play(self.levelBadge)
        end
        if executePulseActive then
            self:UpdateExecuteIconPulse(now)
        end
    end)
end

function TargetFrame:UpdateVisibility()
    local preview = self.settingsPreviewActive or self.debugPreviewMode
    local hasData = self.currentData ~= nil
    local show = IsEnabled() and hasData and (preview or IsUnlocked() or IsHudSceneShowing())
    self:GetRoot():SetHidden(not show)
    self:GetMover():SetHidden(not show or not IsUnlocked())
    self:SetStockFrameHidden(IsEnabled() and self.initialized == true and self.runtimeRecoveryActive ~= true)
    self:UpdateScheduler()
end

function TargetFrame:SetUnlocked(unlocked)
    unlocked = unlocked == true
    if self.mover then
        self.mover:StopMovingOrResizing()
        self.mover:SetMovable(false)
        if not unlocked then
            self.mover:SetHidden(true)
        end
    end
    if not unlocked then
        self.lastLiveData = nil
    end
    self:ResetTargetState()
    self:RefreshTarget(true)
end

function TargetFrame:SetSettingsPreviewActive(active)
    self.settingsPreviewActive = active == true or nil
    if not active then self.previewBoss = nil end
    if active then
        self.debugPreviewMode = nil
    end
    self:ResetTargetState()
    self:RefreshTarget(true)
end

function TargetFrame:SetBossPreview(active)
    self.previewBoss = active == true or nil
    self:RefreshTarget(true)
end

function TargetFrame:SetDebugPreviewMode(mode)
    self.settingsPreviewActive = nil
    self.debugPreviewMode = mode == "player" and "player" or mode == "npc" and "npc" or nil
    self:ResetTargetState()
    self:RefreshTarget(true)
end

function TargetFrame:ReplayPreviewEffects()
    if not self.currentData then
        self:SetDebugPreviewMode("player")
    end
    BarVisuals:PlayFeedback(self.health, "spend", { r = 1.00, g = 0.20, b = 0.14 }, 0.85)
    zo_callLater(function()
        if self.health then
            BarVisuals:PlayFeedback(self.health, "shield", GetSetting("shieldGlowColor"), 0.85)
            LevelVisuals:Play(self.levelBadge)
        end
    end, 450)
end

function TargetFrame:ResetPosition()
    if NAGA_UI.Settings and NAGA_UI.Settings.ResetTargetFramePosition then
        NAGA_UI.Settings:ResetTargetFramePosition()
    end
    self:ApplyPosition()
end

local function RegisterOptionalEvent(namespace, eventCode, handler)
    if eventCode then
        EVENT_MANAGER:RegisterForEvent(namespace, eventCode, function(...)
            local arguments = { ... }
            local argumentCount = select("#", ...)
            TargetFrame:RunGuarded(namespace, function()
                handler(unpack(arguments, 1, argumentCount))
            end)
        end)
    end
end

function TargetFrame:RefreshChangedTarget(resetState)
    self.targetRefreshToken = (self.targetRefreshToken or 0) + 1
    local refreshToken = self.targetRefreshToken
    if resetState ~= false then
        self:ResetTargetState()
    end
    self:RefreshTarget(true, true)
    for index = 1, #TARGET_REFRESH_DELAYS_MS do
        local delayMS = TARGET_REFRESH_DELAYS_MS[index]
        zo_callLater(function()
            if self.targetRefreshToken == refreshToken and IsEnabled() then
                self:RunGuarded("delayed target refresh", function() self:RefreshTarget(true, true) end)
            end
        end, delayMS)
    end
end

function TargetFrame:QueueTargetReadinessRefresh()
    if self.readinessRefreshPending then
        return
    end
    self.readinessRefreshPending = true
    zo_callLater(function()
        self.readinessRefreshPending = nil
        if IsEnabled() then
            self:RunGuarded("player target readiness", function() self:RefreshTarget(true, true) end)
        end
    end, 25)
end

local function IsObservedTargetTag(unitTag)
    return unitTag == UNIT_TAG or unitTag == PLAYER_UNIT_TAG
end

function TargetFrame:RegisterEvents()
    if self.eventsRegistered then
        return
    end
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Reticle", EVENT_RETICLE_TARGET_CHANGED, function()
        self:RefreshChangedTarget()
    end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_ReticlePlayer", EVENT_RETICLE_TARGET_PLAYER_CHANGED, function()
        self:QueueTargetReadinessRefresh()
    end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_ReticleCompanion", EVENT_RETICLE_TARGET_COMPANION_CHANGED, function()
        self:QueueTargetReadinessRefresh()
    end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_UnitCreated", EVENT_UNIT_CREATED, function(_, unitTag)
        if IsObservedTargetTag(unitTag) then
            self:QueueTargetReadinessRefresh()
        end
    end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_UnitDestroyed", EVENT_UNIT_DESTROYED, function(_, unitTag)
        if IsObservedTargetTag(unitTag) then
            self:QueueTargetReadinessRefresh()
        end
    end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_CharacterName", EVENT_UNIT_CHARACTER_NAME_CHANGED, function(_, unitTag)
        if IsObservedTargetTag(unitTag) then
            self:QueueTargetReadinessRefresh()
        end
    end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Power", EVENT_POWER_UPDATE, function(_, unitTag, _, powerType)
        if IsObservedTargetTag(unitTag) and powerType == HEALTH_POWER_TYPE then self:RefreshTarget(false, true) end
    end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Disposition", EVENT_DISPOSITION_UPDATE, function(_, unitTag)
        if IsObservedTargetTag(unitTag) then self:RefreshTarget(true, true) end
    end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Level", EVENT_LEVEL_UPDATE, function(_, unitTag)
        if IsObservedTargetTag(unitTag) then self:RefreshTarget(true, true) end
    end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Champion", EVENT_CHAMPION_POINT_UPDATE, function(_, unitTag)
        if IsObservedTargetTag(unitTag) then self:RefreshTarget(true, true) end
    end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Death", EVENT_UNIT_DEATH_STATE_CHANGED, function(_, unitTag)
        if IsObservedTargetTag(unitTag) then self:RefreshTarget(false, true) end
    end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_ShieldAdded", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, function(_, unitTag, visualType)
        if IsObservedTargetTag(unitTag) and visualType == ATTRIBUTE_VISUAL_POWER_SHIELDING then self:RefreshTarget(false, true) end
    end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_ShieldUpdated", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, function(_, unitTag, visualType)
        if IsObservedTargetTag(unitTag) and visualType == ATTRIBUTE_VISUAL_POWER_SHIELDING then self:RefreshTarget(false, true) end
    end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_ShieldRemoved", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, function(_, unitTag, visualType)
        if IsObservedTargetTag(unitTag) and visualType == ATTRIBUTE_VISUAL_POWER_SHIELDING then self:RefreshTarget(false, true) end
    end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Marker", EVENT_TARGET_MARKER_UPDATE, function() self:RefreshTarget(true, true) end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Rank", EVENT_RANK_POINT_UPDATE, function(_, unitTag)
        if IsObservedTargetTag(unitTag) then self:RefreshTarget(true, true) end
    end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Activated", EVENT_PLAYER_ACTIVATED, function() self:RefreshChangedTarget() end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Interface", EVENT_INTERFACE_SETTING_CHANGED, function()
        self:QueueTargetReadinessRefresh()
    end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_CameraUI", EVENT_GAME_CAMERA_UI_MODE_CHANGED, function()
        self:QueueTargetReadinessRefresh()
    end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_ReticleHidden", EVENT_RETICLE_HIDDEN_UPDATE, function()
        self:QueueTargetReadinessRefresh()
    end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Screen", EVENT_SCREEN_RESIZED, function() self:ApplyPosition() end)
    RegisterOptionalEvent(EVENT_NAMESPACE .. "_Gamepad", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
        self:QueueTargetReadinessRefresh()
    end)
    if CALLBACK_MANAGER then
        CALLBACK_MANAGER:RegisterCallback("TargetFrameCreated", function()
            self:SetStockFrameHidden(IsEnabled() and self.initialized == true)
        end)
        CALLBACK_MANAGER:RegisterCallback("UnitFramesCreated", function()
            self:SetStockFrameHidden(IsEnabled() and self.initialized == true)
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

function TargetFrame:RefreshSettings()
    self:RegisterEvents()
    if not IsEnabled() then
        self.targetRefreshToken = (self.targetRefreshToken or 0) + 1
        self:SetReconciliationEnabled(false)
        self:ResetExecuteIconPulse()
        if self.root then
            self.root:SetHidden(true)
            self.root:SetHandler("OnUpdate", nil)
        end
        if self.mover then self.mover:SetHidden(true) end
        self:SetStockFrameHidden(false)
        return
    end
    local ok, errorMessage = pcall(function()
        self:GetRoot()
        self:RefreshTarget(true)
    end)
    if ok then
        self.initialized = true
        self:SetReconciliationEnabled(true)
        self:SetStockFrameHidden(true)
        self:UpdateVisibility()
    else
        self.initialized = false
        self:SetReconciliationEnabled(false)
        self:ResetExecuteIconPulse()
        self:SetStockFrameHidden(false)
        if self.root then self.root:SetHidden(true) end
        d(string.format("NAGA Target Frame: %s", tostring(errorMessage)))
    end
end

local DEBUG_COMMANDS =
{
    ["/nstarget"] = function(argument)
        argument = string.lower(tostring(argument or ""))
        if argument == "player" or argument == "npc" then
            TargetFrame:SetDebugPreviewMode(argument)
        else
            TargetFrame:SetDebugPreviewMode(nil)
        end
    end,
    ["/nstargetfx"] = function() TargetFrame:ReplayPreviewEffects() end,
}

local function RegisterDebugCommands()
    local enabled = NAGA_UI.Settings and NAGA_UI.Settings:IsDebugModeEnabled()
    for command, handler in pairs(DEBUG_COMMANDS) do
        SLASH_COMMANDS[command] = enabled and handler or nil
    end
end

function TargetFrame:RefreshDebugCommands()
    RegisterDebugCommands()
end

NAGA_UI.OnAddonLoaded(function()
    TargetFrame:RefreshSettings()
    RegisterDebugCommands()
    zo_callLater(function() TargetFrame:RefreshSettings() end, 1000)
end)
