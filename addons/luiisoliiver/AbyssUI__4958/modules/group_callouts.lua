local ADDON_NAME = "AbyssUI"
local EVENT_NAMESPACE = ADDON_NAME .. "_GroupCallouts"

NAGA_UI = NAGA_UI or {}
local NAGA_UI = NAGA_UI
local GroupCallouts = {}
NAGA_UI.GroupCallouts = GroupCallouts

local DEFAULT_SETTINGS =
{
    enabled = false,
    unlocked = false,
    soundMode = "leaderOnly",
    soundKey = "KEYBIND_BUTTON_DISABLED",
    scale = 100,
    maxVisible = 3,
    width = 460,
    height = 56,
    rowSpacing = 6,
    iconSize = 24,
    showIcon = true,
    showAccent = true,
    durationMS = 4200,
    slideDistance = 14,
    shimmerEnabled = false,
    shimmerIntensity = 50,
    shimmerTarget = "leaderOnly",
    glowEnabled = false,
    glowIntensity = 50,
    glowTarget = "leaderOnly",
    nameFontKey = "gameSmall",
    messageFontKey = "chat",
    nameFontSize = 14,
    messageFontSize = 14,
    textEffect = "soft-shadow-thin",
    textOpacity = 94,
    hideBackground = false,
    backgroundOpacity = 68,
    borderOpacity = 28,
    accentOpacity = 54,
    memberBackgroundColor = { r = 0.014, g = 0.016, b = 0.020 },
    leaderBackgroundColor = { r = 0.016, g = 0.014, b = 0.012 },
    memberNameColor = { r = 0.72, g = 0.84, b = 0.96 },
    memberTextColor = { r = 0.84, g = 0.87, b = 0.90 },
    memberAccentColor = { r = 0.40, g = 0.55, b = 0.72 },
    leaderNameColor = { r = 0.96, g = 0.78, b = 0.38 },
    leaderTextColor = { r = 0.88, g = 0.84, b = 0.74 },
    leaderAccentColor = { r = 0.92, g = 0.64, b = 0.22 },
}

local DEFAULT_POSITION = { x = 0, y = -260 }
local MEMBER_ICON = "EsoUI/Art/Compass/groupmember.dds"
local LEADER_ICON = "EsoUI/Art/Compass/groupLeader.dds"
local EFFECT_HIGHLIGHT_TEXTURE = "EsoUI/Art/HUD/lootHistory_highlight.dds"
local FADE_IN_MS = 180
local FADE_OUT_MS = 380
local SOUND_THROTTLE_MS = 250
local SHIMMER_CYCLE_MS = 1900
local SHIMMER_SWEEP_MS = 950
local GLOW_CYCLE_MS = 1400

local FONT_FACES =
{
    gameSmall = "$(BOLD_FONT)",
    gameMedium = "$(MEDIUM_FONT)",
    antique = "$(ANTIQUE_FONT)",
    trajan = "EsoUI/Common/Fonts/TrajanPro-Regular.slug",
    univers = "EsoUI/Common/Fonts/Univers57.slug",
    chat = "$(CHAT_FONT)",
}

local TEXT_EFFECT_ALIASES =
{
    None = "none",
    ["Soft Thin"] = "soft-shadow-thin",
    ["Soft Thick"] = "soft-shadow-thick",
    ["Thick Outline"] = "thick-outline",
}

local SOUND_KEYS =
{
    KEYBIND_BUTTON_DISABLED = true,
    TRIBUTE_AGENT_HEALED = true,
    STATS_RESPEC_CLEAR_ALL = true,
    RETURNING_PLAYER_OPEN_KEYBOARD = true,
}

local SOUND_MODE_ALIASES =
{
    Off = "off",
    ["Leader Only"] = "leaderOnly",
    ["Every Message"] = "all",
}

local EFFECT_TARGET_ALIASES =
{
    ["Leader Only"] = "leaderOnly",
    ["All Callouts"] = "all",
    All = "all",
}

local function ClampNumber(value, minValue, maxValue)
    value = tonumber(value) or minValue
    return math.min(math.max(value, minValue), maxValue)
end

local function EaseOutCubic(progress)
    local inverse = 1 - progress
    return 1 - inverse * inverse * inverse
end

local function EaseOutBack(progress)
    local c1 = 1.70158
    local c3 = c1 + 1
    local offset = progress - 1
    return 1 + c3 * offset * offset * offset + c1 * offset * offset
end

local function IsNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

local function NamesMatch(firstName, secondName)
    return IsNonEmptyString(firstName)
        and IsNonEmptyString(secondName)
        and firstName == secondName
end

local function GetSettings()
    if NAGA_UI.Settings and NAGA_UI.Settings.GetGroupCallouts then
        return NAGA_UI.Settings:GetGroupCallouts()
    end

    return DEFAULT_SETTINGS
end

local function GetSettingValue(key)
    local settings = GetSettings()
    local value = settings and settings[key]
    if value == nil then
        return DEFAULT_SETTINGS[key]
    end

    return value
end

local function GetColorSetting(key)
    local settings = GetSettings()
    local color = settings and settings[key]
    local fallback = DEFAULT_SETTINGS[key]
    if type(color) ~= "table" then
        color = fallback
    end

    return color.r or fallback.r, color.g or fallback.g, color.b or fallback.b
end

local function IsModuleEnabled()
    if NAGA_UI.Settings and NAGA_UI.Settings.IsGroupCalloutsEnabled then
        return NAGA_UI.Settings:IsGroupCalloutsEnabled()
    end

    return DEFAULT_SETTINGS.enabled
end

local function IsModuleUnlocked()
    return IsModuleEnabled()
        and NAGA_UI.Settings
        and NAGA_UI.Settings.IsGroupCalloutsUnlocked
        and NAGA_UI.Settings:IsGroupCalloutsUnlocked()
end

local function GetPosition()
    if NAGA_UI.Settings and NAGA_UI.Settings.GetGroupCalloutsPosition then
        return NAGA_UI.Settings:GetGroupCalloutsPosition()
    end

    return DEFAULT_POSITION
end

local function GetScale()
    return ClampNumber(GetSettingValue("scale"), 60, 180) / 100
end

local function GetCalloutWidth()
    return ClampNumber(GetSettingValue("width"), 260, 760)
end

local function GetCalloutHeight()
    return ClampNumber(GetSettingValue("height"), 42, 110)
end

local function GetCalloutSpacing()
    return ClampNumber(GetSettingValue("rowSpacing"), 0, 24)
end

local function GetMaxVisibleCallouts()
    return ClampNumber(GetSettingValue("maxVisible"), 3, 6)
end

local function GetTotalHeight()
    local maxVisible = GetMaxVisibleCallouts()
    return (GetCalloutHeight() * maxVisible) + (GetCalloutSpacing() * (maxVisible - 1))
end

local function GetIconSize()
    return ClampNumber(GetSettingValue("iconSize"), 0, 48)
end

local function ShouldShowIcon()
    return GetSettingValue("showIcon") ~= false and GetIconSize() > 0
end

local function ShouldShowAccent()
    return GetSettingValue("showAccent") ~= false
end

local function ShouldHideBackground()
    return GetSettingValue("hideBackground") == true
end

local function GetVisibleDurationMS()
    return ClampNumber(GetSettingValue("durationMS"), 1200, 9000)
end

local function GetSlideDistance()
    return ClampNumber(GetSettingValue("slideDistance"), 0, 40)
end

local function GetNameFontSize()
    return ClampNumber(GetSettingValue("nameFontSize"), 9, 28)
end

local function GetMessageFontSize()
    return ClampNumber(GetSettingValue("messageFontSize"), 9, 30)
end

local function GetTextOpacity()
    return ClampNumber(GetSettingValue("textOpacity"), 10, 100) / 100
end

local function NormalizeEffectTarget(value, defaultValue)
    local normalized = EFFECT_TARGET_ALIASES[value] or value
    if normalized == "leaderOnly" or normalized == "all" then
        return normalized
    end

    return defaultValue
end

local function ShouldApplyEffect(enabledKey, targetKey, isLeader)
    if GetSettingValue(enabledKey) ~= true then
        return false
    end

    local target = NormalizeEffectTarget(GetSettingValue(targetKey), DEFAULT_SETTINGS[targetKey])
    return target == "all" or isLeader == true
end

local function BuildFont(fontKey, fontSize)
    local face = FONT_FACES[fontKey] or FONT_FACES.chat
    local effect = TEXT_EFFECT_ALIASES[GetSettingValue("textEffect")] or GetSettingValue("textEffect")
    if effect ~= "none"
        and effect ~= "soft-shadow-thin"
        and effect ~= "soft-shadow-thick"
        and effect ~= "thick-outline" then
        effect = DEFAULT_SETTINGS.textEffect
    end

    if effect == "none" then
        return string.format("%s|%d", face, fontSize)
    end

    return string.format("%s|%d|%s", face, fontSize, effect or "soft-shadow-thin")
end

local function NormalizeSoundMode(value)
    local normalized = SOUND_MODE_ALIASES[value] or value
    if normalized == "off" or normalized == "leaderOnly" or normalized == "all" then
        return normalized
    end

    return DEFAULT_SETTINGS.soundMode
end

local function NormalizeSoundKey(value)
    if not IsNonEmptyString(value) or value == "none" or value == "None" then
        return nil
    end

    return value
end

local function GetCalloutSound()
    local key = NormalizeSoundKey(GetSettingValue("soundKey"))
    if not key or not SOUND_KEYS[key] then
        key = DEFAULT_SETTINGS.soundKey
    end

    if SOUNDS and SOUNDS[key] then
        return SOUNDS[key]
    end

    return key
end

local function IsOwnMessage(fromName, fromDisplayName)
    local playerDisplayName = GetUnitDisplayName("player")
    local playerRawName = GetRawUnitName("player")
    local playerName = GetUnitName("player")

    return NamesMatch(fromDisplayName, playerDisplayName)
        or NamesMatch(fromName, playerDisplayName)
        or NamesMatch(fromName, playerRawName)
        or NamesMatch(fromName, playerName)
end

local function GetUserFacingName(fromName, fromDisplayName)
    if ZO_GetPrimaryPlayerName and IsNonEmptyString(fromDisplayName) and IsNonEmptyString(fromName) then
        local primaryName = ZO_GetPrimaryPlayerName(fromDisplayName, fromName)
        if IsNonEmptyString(primaryName) then
            return primaryName
        end
    end

    if IsNonEmptyString(fromDisplayName) then
        return fromDisplayName
    end

    if IsNonEmptyString(fromName) then
        return fromName
    end

    return "Group"
end

function GroupCallouts:IsSenderLeader(fromName, fromDisplayName)
    local leaderTag = GetGroupLeaderUnitTag()
    if not IsNonEmptyString(leaderTag) then
        return false
    end

    local leaderDisplayName = GetUnitDisplayName(leaderTag)
    local leaderRawName = GetRawUnitName(leaderTag)
    local leaderName = GetUnitName(leaderTag)

    return NamesMatch(fromDisplayName, leaderDisplayName)
        or NamesMatch(fromName, leaderDisplayName)
        or NamesMatch(fromName, leaderRawName)
        or NamesMatch(fromName, leaderName)
end

function GroupCallouts:GetRoot()
    if self.root then
        return self.root
    end

    local root = WINDOW_MANAGER:CreateTopLevelWindow("NAGA_UI_GroupCalloutsRoot")
    ApplyTemplateToControl(root, "ZO_HUDManager_Element")
    root:SetDimensions(GetCalloutWidth(), GetTotalHeight())
    root:SetClampedToScreen(true)
    root:SetMouseEnabled(false)
    root:SetDrawTier(DT_HIGH)
    root:SetHidden(true)
    root:SetAlpha(1)

    self.root = root
    return root
end

function GroupCallouts:CreateEntry()
    self.nextEntryId = (self.nextEntryId or 0) + 1

    local entry = WINDOW_MANAGER:CreateControl("NAGA_UI_GroupCallout" .. self.nextEntryId, self:GetRoot(), CT_CONTROL)
    entry:SetDimensions(GetCalloutWidth(), GetCalloutHeight())
    entry:SetMouseEnabled(false)
    entry:SetHidden(true)
    entry:SetAlpha(0)

    local glowLeft = WINDOW_MANAGER:CreateControl(nil, entry, CT_TEXTURE)
    glowLeft:SetTexture(EFFECT_HIGHLIGHT_TEXTURE)
    glowLeft:SetTextureCoords(0, 1, 0, 0.75)
    glowLeft:SetBlendMode(TEX_BLEND_MODE_ADD)
    glowLeft:SetDrawLayer(DL_BACKGROUND)
    glowLeft:SetDrawLevel(0)
    glowLeft:SetHidden(true)
    entry.glowLeft = glowLeft

    local glowRight = WINDOW_MANAGER:CreateControl(nil, entry, CT_TEXTURE)
    glowRight:SetTexture(EFFECT_HIGHLIGHT_TEXTURE)
    glowRight:SetTextureCoords(1, 0, 0, 0.75)
    glowRight:SetBlendMode(TEX_BLEND_MODE_ADD)
    glowRight:SetDrawLayer(DL_BACKGROUND)
    glowRight:SetDrawLevel(0)
    glowRight:SetHidden(true)
    entry.glowRight = glowRight

    local backdrop = WINDOW_MANAGER:CreateControl(nil, entry, CT_BACKDROP)
    backdrop:SetAnchorFill(entry)
    backdrop:SetEdgeTexture("", 1, 1, 1)
    backdrop:SetDrawLayer(DL_BACKGROUND)
    backdrop:SetDrawLevel(1)
    entry.backdrop = backdrop

    local accent = WINDOW_MANAGER:CreateControl(nil, entry, CT_BACKDROP)
    accent:SetDimensions(3, math.max(GetCalloutHeight() - 16, 1))
    accent:SetAnchor(LEFT, entry, LEFT, 7, 0)
    accent:SetEdgeTexture("", 1, 1, 0)
    accent:SetEdgeColor(0, 0, 0, 0)
    accent:SetDrawLayer(DL_OVERLAY)
    accent:SetDrawLevel(5)
    entry.accent = accent

    local icon = WINDOW_MANAGER:CreateControl(nil, entry, CT_TEXTURE)
    icon:SetDimensions(GetIconSize(), GetIconSize())
    icon:SetAnchor(LEFT, entry, LEFT, 20, 0)
    icon:SetDrawLayer(DL_OVERLAY)
    icon:SetDrawLevel(6)
    entry.icon = icon

    local shimmer = WINDOW_MANAGER:CreateControl(nil, entry, CT_TEXTURE)
    shimmer:SetTexture(EFFECT_HIGHLIGHT_TEXTURE)
    shimmer:SetTextureCoords(0, 1, 0, 0.75)
    shimmer:SetBlendMode(TEX_BLEND_MODE_ADD)
    shimmer:SetDrawLayer(DL_OVERLAY)
    shimmer:SetDrawLevel(4)
    shimmer:SetHidden(true)
    entry.shimmer = shimmer

    local nameLabel = WINDOW_MANAGER:CreateControl(nil, entry, CT_LABEL)
    nameLabel:SetDimensions(GetCalloutWidth() - 60, 18)
    nameLabel:SetAnchor(TOPLEFT, entry, TOPLEFT, 52, 6)
    nameLabel:SetFont(BuildFont(GetSettingValue("nameFontKey"), GetNameFontSize()))
    nameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    nameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    nameLabel:SetMaxLineCount(1)
    nameLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    nameLabel:SetDrawLayer(DL_OVERLAY)
    nameLabel:SetDrawLevel(6)
    entry.nameLabel = nameLabel

    local textLabel = WINDOW_MANAGER:CreateControl(nil, entry, CT_LABEL)
    textLabel:SetDimensions(GetCalloutWidth() - 60, 28)
    textLabel:SetAnchor(TOPLEFT, entry, TOPLEFT, 52, 24)
    textLabel:SetFont(BuildFont(GetSettingValue("messageFontKey"), GetMessageFontSize()))
    textLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    textLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
    textLabel:SetMaxLineCount(2)
    textLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    textLabel:SetDrawLayer(DL_OVERLAY)
    textLabel:SetDrawLevel(6)
    entry.textLabel = textLabel

    return entry
end

function GroupCallouts:AcquireEntry()
    self.pool = self.pool or {}
    self.active = self.active or {}

    if #self.active >= GetMaxVisibleCallouts() then
        self:ReleaseEntry(#self.active)
    end

    local entry = table.remove(self.pool)
    if not entry then
        entry = self:CreateEntry()
    end

    return entry
end

function GroupCallouts:ReleaseEntry(index)
    local entry = table.remove(self.active, index)
    if not entry then
        return
    end

    entry:SetHidden(true)
    entry:SetAlpha(0)
    entry:SetScale(1)
    entry.glowLeft:SetHidden(true)
    entry.glowLeft:SetAlpha(0)
    entry.glowRight:SetHidden(true)
    entry.glowRight:SetAlpha(0)
    entry.shimmer:SetHidden(true)
    entry.shimmer:SetAlpha(0)
    entry.shimmerEnabled = nil
    entry.glowEnabled = nil
    entry.activeCallout = nil
    table.insert(self.pool, entry)
end

function GroupCallouts:ApplyEntryLayout(entry)
    local width = GetCalloutWidth()
    local height = GetCalloutHeight()
    local iconSize = GetIconSize()
    local showIcon = ShouldShowIcon()
    local nameFontSize = GetNameFontSize()
    local messageFontSize = GetMessageFontSize()
    local nameTop = math.max(4, math.floor(height * 0.10))
    local nameHeight = math.min(math.max(nameFontSize + 4, 16), math.max(height - nameTop - 10, 12))
    local textTop = nameTop + nameHeight
    local textHeight = math.max(height - textTop - 5, 1)
    local contentLeft = showIcon and (20 + iconSize + 8) or 18
    local contentWidth = math.max(width - contentLeft - 12, 60)

    entry:SetDimensions(width, height)

    local glowWidth = ClampNumber(width * 0.46, 140, 320)
    entry.glowLeft:ClearAnchors()
    entry.glowLeft:SetDimensions(glowWidth, height + 14)
    entry.glowLeft:SetAnchor(LEFT, entry, LEFT, -12, 0)

    entry.glowRight:ClearAnchors()
    entry.glowRight:SetDimensions(glowWidth, height + 14)
    entry.glowRight:SetAnchor(RIGHT, entry, RIGHT, 12, 0)

    entry.backdrop:ClearAnchors()
    entry.backdrop:SetAnchorFill(entry)

    entry.shimmer:ClearAnchors()
    entry.shimmer:SetDimensions(ClampNumber(width * 0.28, 90, 160), height)
    entry.shimmer:SetAnchor(LEFT, entry, LEFT, 0, 0)

    entry.accent:ClearAnchors()
    entry.accent:SetDimensions(3, math.max(height - 16, 1))
    entry.accent:SetAnchor(LEFT, entry, LEFT, 7, 0)
    entry.accent:SetHidden(not ShouldShowAccent())

    entry.icon:ClearAnchors()
    entry.icon:SetDimensions(iconSize, iconSize)
    entry.icon:SetAnchor(LEFT, entry, LEFT, 20, 0)
    entry.icon:SetHidden(not showIcon)

    entry.nameLabel:ClearAnchors()
    entry.nameLabel:SetAnchor(TOPLEFT, entry, TOPLEFT, contentLeft, nameTop)
    entry.nameLabel:SetDimensions(contentWidth, nameHeight)
    entry.nameLabel:SetFont(BuildFont(GetSettingValue("nameFontKey"), nameFontSize))

    entry.textLabel:ClearAnchors()
    entry.textLabel:SetAnchor(TOPLEFT, entry, TOPLEFT, contentLeft, textTop)
    entry.textLabel:SetDimensions(contentWidth, textHeight)
    entry.textLabel:SetFont(BuildFont(GetSettingValue("messageFontKey"), messageFontSize))
end

function GroupCallouts:ApplyEntryStyle(entry, isLeader)
    local backgroundColorKey = isLeader and "leaderBackgroundColor" or "memberBackgroundColor"
    local nameColorKey = isLeader and "leaderNameColor" or "memberNameColor"
    local textColorKey = isLeader and "leaderTextColor" or "memberTextColor"
    local accentColorKey = isLeader and "leaderAccentColor" or "memberAccentColor"
    local backgroundR, backgroundG, backgroundB = GetColorSetting(backgroundColorKey)
    local nameR, nameG, nameB = GetColorSetting(nameColorKey)
    local textR, textG, textB = GetColorSetting(textColorKey)
    local accentR, accentG, accentB = GetColorSetting(accentColorKey)
    local backgroundAlpha = ShouldHideBackground() and 0 or ClampNumber(GetSettingValue("backgroundOpacity"), 0, 100) / 100
    local borderAlpha = ShouldHideBackground() and 0 or ClampNumber(GetSettingValue("borderOpacity"), 0, 100) / 100
    local accentAlpha = ClampNumber(GetSettingValue("accentOpacity"), 0, 100) / 100
    local textAlpha = GetTextOpacity()
    local shimmerIntensity = ClampNumber(GetSettingValue("shimmerIntensity"), 0, 100) / 100
    local glowIntensity = ClampNumber(GetSettingValue("glowIntensity"), 0, 100) / 100

    entry.backdrop:SetCenterColor(backgroundR, backgroundG, backgroundB, backgroundAlpha)
    entry.backdrop:SetEdgeColor(accentR, accentG, accentB, borderAlpha)
    entry.accent:SetCenterColor(accentR, accentG, accentB, accentAlpha)
    entry.icon:SetColor(accentR, accentG, accentB, math.max(textAlpha, accentAlpha))
    entry.nameLabel:SetColor(nameR, nameG, nameB, textAlpha)
    entry.textLabel:SetColor(textR, textG, textB, textAlpha)
    entry.shimmerIntensity = shimmerIntensity
    entry.glowIntensity = glowIntensity
    entry.shimmerEnabled = shimmerIntensity > 0 and ShouldApplyEffect("shimmerEnabled", "shimmerTarget", isLeader)
    entry.glowEnabled = glowIntensity > 0 and ShouldApplyEffect("glowEnabled", "glowTarget", isLeader)
    entry.shimmer:SetColor(
        0.70 + (accentR * 0.30),
        0.70 + (accentG * 0.30),
        0.70 + (accentB * 0.30),
        1)
    entry.shimmer:SetHidden(not entry.shimmerEnabled)
    if not entry.shimmerEnabled then
        entry.shimmer:SetAlpha(0)
    end
    entry.glowLeft:SetColor(accentR, accentG, accentB, 1)
    entry.glowRight:SetColor(accentR, accentG, accentB, 1)
    entry.glowLeft:SetHidden(not entry.glowEnabled)
    entry.glowRight:SetHidden(not entry.glowEnabled)
    if not entry.glowEnabled then
        entry.glowLeft:SetAlpha(0)
        entry.glowRight:SetAlpha(0)
    end
end

function GroupCallouts:UpdateEntryEffects(entry, data, nowMS)
    local elapsedMS = math.max(nowMS - (data.startMS or nowMS), 0)

    if entry.shimmerEnabled then
        local cyclePositionMS = elapsedMS % SHIMMER_CYCLE_MS
        if cyclePositionMS <= SHIMMER_SWEEP_MS then
            local progress = cyclePositionMS / SHIMMER_SWEEP_MS
            local shimmerWidth = entry.shimmer:GetWidth()
            local travelDistance = math.max(entry:GetWidth() - shimmerWidth, 0)
            local x = (shimmerWidth * 0.5) + (travelDistance * progress)
            local fadeIn = ClampNumber(progress / 0.10, 0, 1)
            local fadeOut = ClampNumber((1 - progress) / 0.20, 0, 1)
            local alpha = math.min(fadeIn, fadeOut) * entry.shimmerIntensity * 0.55
            entry.shimmer:ClearAnchors()
            entry.shimmer:SetAnchor(CENTER, entry, LEFT, x, 0)
            entry.shimmer:SetAlpha(alpha)
            entry.shimmer:SetHidden(false)
        else
            entry.shimmer:SetAlpha(0)
            entry.shimmer:SetHidden(true)
        end
    else
        entry.shimmer:SetAlpha(0)
        entry.shimmer:SetHidden(true)
    end

    if entry.glowEnabled then
        local progress = (elapsedMS % GLOW_CYCLE_MS) / GLOW_CYCLE_MS
        local pulse = 0.5 - (0.5 * math.cos(progress * math.pi * 2))
        local alpha = entry.glowIntensity * (0.10 + (0.28 * pulse))
        entry.glowLeft:SetAlpha(alpha)
        entry.glowRight:SetAlpha(alpha)
        entry.glowLeft:SetHidden(false)
        entry.glowRight:SetHidden(false)
    else
        entry.glowLeft:SetAlpha(0)
        entry.glowRight:SetAlpha(0)
        entry.glowLeft:SetHidden(true)
        entry.glowRight:SetHidden(true)
    end
end

function GroupCallouts:ConfigureEntry(entry, speakerName, text, isLeader)
    self:ApplyEntryLayout(entry)
    self:ApplyEntryStyle(entry, isLeader)

    if isLeader then
        entry.icon:SetTexture(LEADER_ICON)
    else
        entry.icon:SetTexture(MEMBER_ICON)
    end

    entry.nameLabel:SetText(speakerName or "Group")
    entry.textLabel:SetText(text or "")
end

function GroupCallouts:ApplyLayout()
    local position = GetPosition()
    local x = tonumber(position and position.x) or DEFAULT_POSITION.x
    local y = tonumber(position and position.y) or DEFAULT_POSITION.y
    local root = self:GetRoot()
    local mover = self:GetMover()
    local width = GetCalloutWidth()
    local totalHeight = GetTotalHeight()
    local scale = GetScale()

    root:SetDimensions(width, totalHeight)
    root:SetScale(scale)
    root:ClearAnchors()
    root:SetAnchor(CENTER, GuiRoot, CENTER, x, y)

    mover:SetDimensions(width, totalHeight)
    mover:SetScale(scale)
    mover:ClearAnchors()
    mover:SetAnchor(CENTER, GuiRoot, CENTER, x, y)
    if mover.label then
        mover.label:SetDimensions(width - 24, 32)
    end
    mover:SetHidden(not IsModuleUnlocked())

    for _, entry in ipairs(self.active or {}) do
        local data = entry.activeCallout
        self:ApplyEntryLayout(entry)
        self:ApplyEntryStyle(entry, data and data.isLeader)
    end
end

function GroupCallouts:GetMover()
    if self.mover then
        return self.mover
    end

    local mover = WINDOW_MANAGER:CreateTopLevelWindow("NAGA_UI_GroupCalloutsMover")
    mover:SetDimensions(GetCalloutWidth(), GetTotalHeight())
    mover:SetClampedToScreen(true)
    mover:SetMouseEnabled(true)
    mover:SetMovable(false)
    mover:SetDrawTier(DT_HIGH)
    mover:SetHidden(true)

    local backdrop = WINDOW_MANAGER:CreateControl(nil, mover, CT_BACKDROP)
    backdrop:SetAnchorFill(mover)
    backdrop:SetCenterColor(0.02, 0.02, 0.02, 0.46)
    backdrop:SetEdgeColor(0.94, 0.78, 0.30, 0.92)
    backdrop:SetEdgeTexture("", 1, 1, 2)

    local label = WINDOW_MANAGER:CreateControl(nil, mover, CT_LABEL)
    label:SetAnchor(CENTER, mover, CENTER, 0, 0)
    label:SetDimensions(GetCalloutWidth() - 24, 32)
    label:SetFont("ZoFontGameBold")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetText("NAGA Group Callouts")
    label:SetColor(0.95, 0.86, 0.38, 1)
    mover.label = label

    mover:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            control:SetMovable(true)
            control:StartMoving()
        else
            control:SetMovable(false)
        end
    end)

    mover:SetHandler("OnMouseUp", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            control:StopMovingOrResizing()
        end
        control:SetMovable(false)
    end)

    mover:SetHandler("OnMoveStop", function(control)
        control:SetMovable(false)
        local x = control:GetLeft() + (control:GetWidth() * 0.5) - (GuiRoot:GetWidth() * 0.5)
        local y = control:GetTop() + (control:GetHeight() * 0.5) - (GuiRoot:GetHeight() * 0.5)
        if NAGA_UI.Settings and NAGA_UI.Settings.SetGroupCalloutsPosition then
            NAGA_UI.Settings:SetGroupCalloutsPosition(x, y)
        end
        self:ApplyLayout()
    end)

    self.mover = mover
    return mover
end

function GroupCallouts:UpdateEntries()
    local active = self.active
    if not active or #active == 0 then
        self:GetRoot():SetHandler("OnUpdate", nil)
        self:GetRoot():SetHidden(true)
        return
    end

    local nowMS = GetFrameTimeMilliseconds()
    for index = #active, 1, -1 do
        local entry = active[index]
        local data = entry and entry.activeCallout
        if not data or (not data.persistent and nowMS - data.startMS >= data.durationMS) then
            self:ReleaseEntry(index)
        end
    end

    active = self.active
    if not active or #active == 0 then
        self:GetRoot():SetHandler("OnUpdate", nil)
        self:GetRoot():SetHidden(true)
        return
    end

    for index, entry in ipairs(active) do
        local data = entry.activeCallout
        local height = GetCalloutHeight()
        local spacing = GetCalloutSpacing()
        local slideDistance = GetSlideDistance()
        local alpha = 1
        local scale = 1
        local y = (index - 1) * (height + spacing)

        if not data.persistent then
            local elapsedMS = nowMS - data.startMS
            local fadeInProgress = ClampNumber(elapsedMS / FADE_IN_MS, 0, 1)
            local fadeOutStartMS = data.durationMS - FADE_OUT_MS
            local fadeOutProgress = 0
            if elapsedMS > fadeOutStartMS then
                fadeOutProgress = ClampNumber((elapsedMS - fadeOutStartMS) / FADE_OUT_MS, 0, 1)
            end

            local inEase = EaseOutCubic(fadeInProgress)
            local outEase = EaseOutCubic(fadeOutProgress)
            alpha = inEase * (1 - outEase)
            scale = 0.96 + (0.04 * EaseOutBack(fadeInProgress))
            y = y - ((1 - inEase) * slideDistance) - (outEase * math.max(4, slideDistance * 0.55))
        end

        entry:ClearAnchors()
        entry:SetAnchor(TOP, self:GetRoot(), TOP, 0, y)
        entry:SetAlpha(alpha)
        entry:SetScale(scale)
        self:UpdateEntryEffects(entry, data, nowMS)
    end
end

function GroupCallouts:ClearSettingsPreview()
    local active = self.active
    if active then
        for index = #active, 1, -1 do
            local entry = active[index]
            local data = entry and entry.activeCallout
            if data and data.isSettingsPreview then
                self:ReleaseEntry(index)
            end
        end
    end

    if self.root and (not self.active or #self.active == 0) then
        self.root:SetHandler("OnUpdate", nil)
        self.root:SetHidden(true)
    end
end

function GroupCallouts:AddSettingsPreviewEntry(speakerName, text, isLeader)
    local entry = self:AcquireEntry()
    self:ConfigureEntry(entry, speakerName, text, isLeader)
    entry.activeCallout =
    {
        startMS = GetFrameTimeMilliseconds(),
        durationMS = GetVisibleDurationMS(),
        isLeader = isLeader == true,
        isSettingsPreview = true,
        persistent = true,
    }
    entry:SetHidden(false)
    entry:SetAlpha(1)
    entry:SetScale(1)
    table.insert(self.active, entry)
end

function GroupCallouts:ShowSettingsPreview()
    self:ClearCallouts()
    self:ApplyLayout()
    self:AddSettingsPreviewEntry("Group Member", "Preview group message shown by NAGA.", false)
    self:AddSettingsPreviewEntry("Group Leader", "Preview leader callout shown by NAGA.", true)
    self:StartUpdating()
    self:UpdateEntries()
end

function GroupCallouts:SetSettingsPreviewActive(active)
    self.settingsPreviewActive = active or nil
    if self.settingsPreviewActive then
        self:ShowSettingsPreview()
    else
        self:ClearSettingsPreview()
    end
end

function GroupCallouts:StartUpdating()
    local root = self:GetRoot()
    root:SetHidden(false)
    root:SetHandler("OnUpdate", function()
        self:UpdateEntries()
    end)
end

function GroupCallouts:ClearCallouts()
    if self.active then
        for index = #self.active, 1, -1 do
            self:ReleaseEntry(index)
        end
    end

    if self.root then
        self.root:SetHandler("OnUpdate", nil)
        self.root:SetHidden(true)
    end
end

function GroupCallouts:PlayConfiguredSound(isLeader)
    local mode = NormalizeSoundMode(GetSettingValue("soundMode"))
    if mode == "off" or (mode == "leaderOnly" and not isLeader) then
        return
    end

    local nowMS = GetFrameTimeMilliseconds()
    if self.lastSoundMS and nowMS - self.lastSoundMS < SOUND_THROTTLE_MS then
        return
    end

    local sound = GetCalloutSound()
    if sound then
        PlaySound(sound)
        self.lastSoundMS = nowMS
    end
end

function GroupCallouts:ShowCallout(speakerName, text, isLeader, forceShow)
    if not forceShow and not IsModuleEnabled() then
        return
    end

    if not IsNonEmptyString(text) then
        return
    end

    self:ApplyLayout()

    local entry = self:AcquireEntry()
    self:ConfigureEntry(entry, speakerName, text, isLeader == true)
    entry.activeCallout =
    {
        startMS = GetFrameTimeMilliseconds(),
        durationMS = GetVisibleDurationMS(),
        isLeader = isLeader == true,
    }
    entry:SetHidden(false)
    entry:SetAlpha(0)
    entry:SetScale(0.96)
    table.insert(self.active, 1, entry)
    self:StartUpdating()

    self:PlayConfiguredSound(isLeader == true)
end

function GroupCallouts:OnChatMessage(channelType, fromName, text, _isCustomerService, fromDisplayName)
    if channelType ~= CHAT_CHANNEL_PARTY or not IsModuleEnabled() then
        return
    end

    if self.settingsPreviewActive then
        return
    end

    if IsOwnMessage(fromName, fromDisplayName) then
        return
    end

    local isLeader = self:IsSenderLeader(fromName, fromDisplayName)
    self:ShowCallout(GetUserFacingName(fromName, fromDisplayName), text, isLeader)
end

function GroupCallouts:RegisterEvents()
    if self.eventsRegistered then
        return
    end

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_CHAT_MESSAGE_CHANNEL, function(_, ...)
        self:OnChatMessage(...)
    end)
    self.eventsRegistered = true
end

function GroupCallouts:UnregisterEvents()
    if not self.eventsRegistered then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_CHAT_MESSAGE_CHANNEL)
    self.eventsRegistered = nil
end

function GroupCallouts:RefreshSettings()
    self:GetRoot()
    self:GetMover()

    if IsModuleEnabled() then
        self:RegisterEvents()
    else
        self:UnregisterEvents()
        if not self.settingsPreviewActive then
            self:ClearCallouts()
        end
    end

    self:ApplyLayout()
    if self.settingsPreviewActive then
        self:ShowSettingsPreview()
    end
end

function GroupCallouts:PreviewSound()
    self.lastSoundMS = nil
    local sound = GetCalloutSound()
    if sound then
        PlaySound(sound)
    end
end

function GroupCallouts:PreviewRegular()
    self:ShowCallout("Group Member", "Preview group message shown by NAGA.", false, true)
end

function GroupCallouts:PreviewLeader()
    self:ShowCallout("Group Leader", "Preview leader callout shown by NAGA.", true, true)
end

local DEBUG_COMMANDS =
{
    ["/nsgroupcallout"] = function()
        GroupCallouts:PreviewRegular()
    end,
    ["/nsgroupcalloutleader"] = function()
        GroupCallouts:PreviewLeader()
    end,
}

local function IsDebugModeEnabled()
    return NAGA_UI.Settings and NAGA_UI.Settings:IsDebugModeEnabled()
end

local function RegisterDebugCommands()
    for command, handler in pairs(DEBUG_COMMANDS) do
        SLASH_COMMANDS[command] = IsDebugModeEnabled() and handler or nil
    end
end

function GroupCallouts:RefreshDebugCommands()
    RegisterDebugCommands()
end

NAGA_UI.OnAddonLoaded(function()
    GroupCallouts:RefreshSettings()
    RegisterDebugCommands()
end)
