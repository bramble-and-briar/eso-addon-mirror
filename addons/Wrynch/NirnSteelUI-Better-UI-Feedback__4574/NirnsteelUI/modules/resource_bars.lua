local ADDON_NAME = "NirnsteelUI"
local EVENT_NAMESPACE = ADDON_NAME .. "_ResourceBars"

Nirnsteel_UI = Nirnsteel_UI or {}
local Nirnsteel_UI = Nirnsteel_UI
local BarVisuals = Nirnsteel_UI.BarVisuals
local ResourceBars = {}
Nirnsteel_UI.ResourceBars = ResourceBars

local DEFAULT_SETTINGS =
{
    enabled = true,
    unlocked = false,
    layout = "pyramid",
    attachMountStamina = true,
    scale = 109,
    barHeight = 25,
    rowSpacing = 5,
    columnSpacing = 8,
    rowHealthWidth = 300,
    rowMagickaWidth = 270,
    rowStaminaWidth = 270,
    opacity = 100,
    glossEnabled = true,
    healthTextFormat = "numberAndPercent",
    magickaTextFormat = "numberAndPercent",
    staminaTextFormat = "numberAndPercent",
    healthTextPosition = "sides",
    magickaTextPosition = "sides",
    staminaTextPosition = "sides",
    shieldOverlayEnabled = true,
    shieldTextMode = "healthAndShield",
    shieldFillOpacity = 70,
    shieldFillColor = { r = 0.95, g = 0.60, b = 0.33 },
    shieldGlowEnabled = true,
    shieldGlowOpacity = 65,
    shieldGlowColor = { r = 0.95, g = 0.66, b = 0.56 },
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
    lowResourceGlowEnabled = true,
    borderWidth = 0,
    rpgBorder = true,
    innerShadowAlpha = 60,
    outerShadowAlpha = 100,
    textFontKey = "gameSmall",
    textSize = 18,
    textOutline = "thick-outline",
    textOpacity = 100,
    textInset = 6,
    textVerticalOffset = 3,
    textColor = { r = 0.96, g = 0.92, b = 0.82 },
}

local DEFAULT_POSITION = { x = 0, y = -120 }
local VISIBILITY_HOLD_MS = 1500
local DEFAULT_ROW_WIDTH = 420
local MIN_ROW_WIDTH = 300
local MAX_ROW_WIDTH = 620
local MIN_HEALTH_WIDTH = 220
local MIN_RESOURCE_WIDTH = 96
local MIN_BAR_HEIGHT = 10
local MAX_BAR_HEIGHT = 48
local MIN_ALPHA = 10
local MAX_ALPHA = 100
local MIN_FEEDBACK_DELTA_RATIO = 0.015
local MIN_FEEDBACK_INTERVAL_MS = 140
local LOW_RESOURCE_HEALTH_RATIO = 0.35
local LOW_RESOURCE_OTHER_RATIO = 0.25
local FONT_FACES = BarVisuals.Fonts

local RESOURCE_DATA =
{
    health = {
        powerType = COMBAT_MECHANIC_FLAGS_HEALTH,
        color = { 0.98, 0.18, 0.20, 0.98 },
        endColor = { 0.98, 0.18, 0.20, 0.98 },
        label = "Health",
    },
    magicka = {
        powerType = COMBAT_MECHANIC_FLAGS_MAGICKA,
        color = { 0.04, 0.30, 0.62, 0.94 },
        endColor = { 0.16, 0.64, 0.96, 0.96 },
        label = "Magicka",
    },
    stamina = {
        powerType = COMBAT_MECHANIC_FLAGS_STAMINA,
        color = { 0.03, 0.42, 0.25, 0.94 },
        endColor = { 0.16, 0.78, 0.42, 0.96 },
        label = "Stamina",
    },
}

local POWER_KEY_BY_TYPE =
{
    [COMBAT_MECHANIC_FLAGS_HEALTH] = "health",
    [COMBAT_MECHANIC_FLAGS_MAGICKA] = "magicka",
    [COMBAT_MECHANIC_FLAGS_STAMINA] = "stamina",
}

local TEXT_FORMAT_SETTING =
{
    number = RESOURCE_NUMBERS_SETTING_NUMBER_ONLY,
    percent = RESOURCE_NUMBERS_SETTING_PERCENT_ONLY,
    numberAndPercent = RESOURCE_NUMBERS_SETTING_NUMBER_AND_PERCENT,
}

local BAR_ORDER = { "health", "magicka", "stamina" }

local TEXT_FORMAT_ALIASES =
{
    none = "none",
    None = "none",
    number = "number",
    Number = "number",
    percent = "percent",
    Percent = "percent",
    numberAndPercent = "numberAndPercent",
    ["Number + Percent"] = "numberAndPercent",
    ["Number and Percent"] = "numberAndPercent",
}

local TEXT_POSITION_ALIASES =
{
    center = "center",
    Center = "center",
    sides = "sides",
    Sides = "sides",
}

local SHIELD_TEXT_ALIASES =
{
    off = "off",
    Off = "off",
    shieldOnly = "shieldOnly",
    ["Shield Only"] = "shieldOnly",
    healthAndShield = "healthAndShield",
    ["Health + Shield"] = "healthAndShield",
}

local function ClampNumber(value, minValue, maxValue)
    value = tonumber(value) or minValue
    return math.min(math.max(value, minValue), maxValue)
end

local function NormalizeTextFormat(value)
    return TEXT_FORMAT_ALIASES[value] or "numberAndPercent"
end

local function NormalizeTextPosition(value)
    return TEXT_POSITION_ALIASES[value] or "center"
end

local function NormalizeShieldTextMode(value)
    return SHIELD_TEXT_ALIASES[value] or "healthAndShield"
end

local function GetSettings()
    if Nirnsteel_UI.Settings then
        return Nirnsteel_UI.Settings:GetResourceBars()
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

local function IsModuleEnabled()
    return not Nirnsteel_UI.Settings or Nirnsteel_UI.Settings:IsResourceBarsEnabled()
end

local function ShouldHideHealthResourceBar()
    return Nirnsteel_UI.Settings and Nirnsteel_UI.Settings:ShouldHardcoreHideHealthResourceBar()
end

local function ShouldShowResourceBarKey(key)
    return key ~= "health" or not ShouldHideHealthResourceBar()
end

local function IsModuleUnlocked()
    if Nirnsteel_UI.HUDEditor and Nirnsteel_UI.HUDEditor:IsAvailable() then return false end
    return IsModuleEnabled()
        and Nirnsteel_UI.Settings
        and Nirnsteel_UI.Settings:IsResourceBarsUnlocked()
end

local function GetPosition()
    if Nirnsteel_UI.Settings then
        return Nirnsteel_UI.Settings:GetResourceBarsPosition()
    end

    return DEFAULT_POSITION
end

local function GetScale()
    return ClampNumber(GetSettingValue("scale"), 70, 160) / 100
end

local function GetConfiguredBarHeight()
    return ClampNumber(GetSettingValue("barHeight"), MIN_BAR_HEIGHT, MAX_BAR_HEIGHT)
end

local function GetConfiguredAlpha()
    return ClampNumber(GetSettingValue("opacity"), MIN_ALPHA, MAX_ALPHA) / 100
end

local function GetRowSpacing()
    return ClampNumber(GetSettingValue("rowSpacing"), 0, 32)
end

local function GetColumnSpacing()
    return ClampNumber(GetSettingValue("columnSpacing"), 0, 32)
end

local function ShouldShowGloss()
    return GetSettingValue("glossEnabled") ~= false
end

local function ShouldShowShieldOverlay()
    return GetSettingValue("shieldOverlayEnabled") ~= false
end

local function ShouldShowShieldGlow()
    return GetSettingValue("shieldGlowEnabled") ~= false
end

local function ShouldShowBarPattern()
    return GetSettingValue("barPatternEnabled") == true
end

local function ShouldShowFeedback()
    return GetSettingValue("feedbackEnabled") == true
end

local function GetFeedbackIntensity()
    return ClampNumber(GetSettingValue("feedbackIntensity"), 0, 100) / 100
end

local function ShouldShowGainPulse()
    return ShouldShowFeedback() and GetSettingValue("gainPulseEnabled") ~= false
end

local function ShouldShowSpendPulse()
    return ShouldShowFeedback() and GetSettingValue("spendPulseEnabled") ~= false
end

local function ShouldShowFullResourcePulse()
    return ShouldShowFeedback() and GetSettingValue("fullResourcePulseEnabled") ~= false
end

local function ShouldShowShieldPulse()
    return ShouldShowFeedback() and GetSettingValue("shieldPulseEnabled") ~= false
end

local function ShouldShowLowResourceGlow()
    return ShouldShowFeedback() and GetSettingValue("lowResourceGlowEnabled") ~= false
end

local function BuildTextFont()
    local face = FONT_FACES[GetSettingValue("textFontKey")] or FONT_FACES.gameSmall
    local size = ClampNumber(GetSettingValue("textSize"), 8, 32)
    local outline = GetSettingValue("textOutline")
    if outline == "none" then
        return string.format("%s|%d", face, size)
    end

    return string.format("%s|%d|%s", face, size, outline or "soft-shadow-thick")
end

local function ApplyLabelTextStyle(label, font, r, g, b, alpha)
    if not label then
        return
    end

    label:SetFont(font)
    label:SetModifyTextType(MODIFY_TEXT_TYPE_NONE)
    label:SetColor(r, g, b, alpha)
end

local function ConfigureStatusBar(bar, data, key)
    bar:SetGradientColors(data.color[1], data.color[2], data.color[3], data.color[4], data.endColor[1], data.endColor[2], data.endColor[3], data.endColor[4])
end

local function GetResourceColor(key)
    local data = RESOURCE_DATA[key] or RESOURCE_DATA.health
    local color = data.endColor or data.color
    return color[1], color[2], color[3]
end

local function HideFrameFeedback(frame)
    BarVisuals:HideFeedback(frame)
end

local function SetResourceFillDirection(frame, key)
    local alignment = BAR_ALIGNMENT_NORMAL
    if key == "health" then
        alignment = BAR_ALIGNMENT_CENTER
    elseif key == "magicka" then
        alignment = BAR_ALIGNMENT_REVERSE
    end

    frame.alignment = alignment
    BarVisuals:SetAlignment(frame, alignment)
end

local function ApplyFrameStyle(frame, width, height)
    local borderWidth = ClampNumber(GetSettingValue("borderWidth"), 0, 8)
    local textColor = GetSettingValue("textColor") or DEFAULT_SETTINGS.textColor
    local data = frame.data or RESOURCE_DATA.health
    BarVisuals:ApplyStyle(frame,
    {
        width = width,
        height = height,
        alpha = GetConfiguredAlpha(),
        borderWidth = borderWidth,
        rpgBorder = GetSettingValue("rpgBorder") == true,
        innerShadowAlpha = ClampNumber(GetSettingValue("innerShadowAlpha"), 0, 100) / 100,
        outerShadowAlpha = ClampNumber(GetSettingValue("outerShadowAlpha"), 0, 100) / 100,
        textureInfo = BarVisuals.Textures.genericTall,
        trackColor = { r = 0.01, g = 0.01, b = 0.01, a = 0.55 },
        fillStartColor = data.color,
        fillEndColor = data.endColor,
        glossEnabled = ShouldShowGloss(),
        glossOpacity = 0.13,
        patternEnabled = ShouldShowBarPattern(),
        patternTexture = BarVisuals.Patterns[GetSettingValue("barPatternKey")] or BarVisuals.Patterns.smoke,
        patternOpacity = ClampNumber(GetSettingValue("barPatternOpacity"), 0, 100) / 100,
        patternScale = ClampNumber(GetSettingValue("barPatternScale"), 24, 256),
        lossTrailEnabled = GetSettingValue("lossTrailEnabled") == true,
        lossTrailColor = { r = 1.00, g = 0.70, b = 0.24, a = 0.78 },
        shieldEnabled = ShouldShowShieldOverlay(),
        shieldFillColor = GetSettingValue("shieldFillColor") or DEFAULT_SETTINGS.shieldFillColor,
        shieldFillOpacity = ClampNumber(GetSettingValue("shieldFillOpacity"), 0, 100) / 100,
        shieldGlowEnabled = ShouldShowShieldGlow(),
        shieldGlowColor = GetSettingValue("shieldGlowColor") or DEFAULT_SETTINGS.shieldGlowColor,
        shieldGlowOpacity = ClampNumber(GetSettingValue("shieldGlowOpacity"), 0, 100) / 100,
        shieldUseOuterDimensions = true,
        font = BuildTextFont(),
        textColor = textColor,
        textOpacity = ClampNumber(GetSettingValue("textOpacity"), 10, 100) / 100,
        textInset = ClampNumber(GetSettingValue("textInset"), 0, 24),
        textVerticalOffset = ClampNumber(GetSettingValue("textVerticalOffset"), -8, 8),
        alignment = frame.alignment,
        lowGlowEnabled = false,
    })
end

local function FormatByMode(current, maximum, mode)
    mode = NormalizeTextFormat(mode)
    local override = TEXT_FORMAT_SETTING[mode] or RESOURCE_NUMBERS_SETTING_NUMBER_AND_PERCENT
    if ZO_FormatResourceBarCurrentAndMax then
        return ZO_FormatResourceBarCurrentAndMax(current or 0, maximum or 0, override)
    end

    return zo_strformat(SI_ATTRIBUTE_NUMBERS_WITH_PERCENT, current or 0, 0)
end

local function ShouldShowResource(current, effectiveMax, fadeUntilMS)
    local showSetting = tonumber(GetSetting(SETTING_TYPE_UI, UI_SETTING_SHOW_RESOURCE_BARS))
    if showSetting == RESOURCE_BARS_SETTING_CHOICE_ALWAYS_SHOW then
        return true
    elseif showSetting == RESOURCE_BARS_SETTING_CHOICE_DONT_SHOW then
        return false
    end

    if not current or not effectiveMax or effectiveMax == 0 then
        return false
    end

    if current < effectiveMax and current ~= 0 then
        return true
    end

    if not GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_FADE_PLAYER_BARS) then
        return true
    end

    return fadeUntilMS and fadeUntilMS > GetFrameTimeMilliseconds()
end

local function IsHudSceneShowing()
    local hudShowing = HUD_SCENE and HUD_SCENE.IsShowing and HUD_SCENE:IsShowing()
    local hudUiShowing = HUD_UI_SCENE and HUD_UI_SCENE.IsShowing and HUD_UI_SCENE:IsShowing()
    if HUD_SCENE or HUD_UI_SCENE then
        return hudShowing or hudUiShowing
    end

    return true
end

local function GetBarTextSettings(key)
    local formatKey = key .. "TextFormat"
    local positionKey = key .. "TextPosition"
    local formatValue = NormalizeTextFormat(GetSettingValue(formatKey))
    local positionValue = NormalizeTextPosition(GetSettingValue(positionKey))
    return formatValue, positionValue
end

function ResourceBars:CreateResourceBar(key, data)
    local root = self:GetRoot()
    local frame = BarVisuals:Create(root, nil, { withShield = key == "health" })
    frame.powerKey = key
    ConfigureStatusBar(frame.bar, data, key)
    SetResourceFillDirection(frame, key)
    frame.centerLabel:SetDrawLevel(3)
    frame.leftLabel:SetDrawLevel(3)
    frame.rightLabel:SetDrawLevel(3)
    frame.data = data
    self.bars[key] = frame
    return frame
end

function ResourceBars:GetRoot()
    if self.root then
        return self.root
    end

    local root = WINDOW_MANAGER:CreateTopLevelWindow("Nirnsteel_UI_ResourceBarsRoot")
    root:SetDimensions(DEFAULT_ROW_WIDTH, (GetConfiguredBarHeight() * 2) + 5)
    root:SetClampedToScreen(true)
    root:SetMouseEnabled(false)
    root:SetMovable(false)
    root:SetDrawTier(DT_HIGH)
    root:SetHidden(true)
    self.root = root

    self.bars = {}
    self:CreateResourceBar("health", RESOURCE_DATA.health)
    self:CreateResourceBar("magicka", RESOURCE_DATA.magicka)
    self:CreateResourceBar("stamina", RESOURCE_DATA.stamina)

    return root
end

function ResourceBars:GetMover()
    if self.mover then
        return self.mover
    end

    local mover = WINDOW_MANAGER:CreateTopLevelWindow("Nirnsteel_UI_ResourceBarsMover")
    mover:SetDimensions(DEFAULT_ROW_WIDTH, (GetConfiguredBarHeight() * 2) + 5)
    mover:SetClampedToScreen(true)
    mover:SetMouseEnabled(true)
    mover:SetMovable(false)
    mover:SetDrawTier(DT_HIGH)
    mover:SetHidden(true)

    local backdrop = WINDOW_MANAGER:CreateControl(nil, mover, CT_BACKDROP)
    backdrop:SetAnchorFill(mover)
    backdrop:SetCenterColor(0.02, 0.02, 0.02, 0.32)
    backdrop:SetEdgeColor(0.85, 0.72, 0.25, 0.9)
    backdrop:SetEdgeTexture("", 1, 1, 2)

    local label = WINDOW_MANAGER:CreateControl(nil, mover, CT_LABEL)
    label:SetAnchor(CENTER, mover, CENTER, 0, 0)
    label:SetFont("ZoFontGameBold")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetText("Nirnsteel Resource Bars")
    label:SetColor(0.95, 0.86, 0.35, 1)

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
        if Nirnsteel_UI.Settings then
            Nirnsteel_UI.Settings:SetResourceBarsPosition(x, y)
        end
        self:ApplyLayout()
    end)

    self.mover = mover
    return mover
end

function ResourceBars:UpdateLabelLayout(frame, width, height)
    ApplyFrameStyle(frame, width, height)

    local textInset = ClampNumber(GetSettingValue("textInset"), 0, 24)
    local textVerticalOffset = ClampNumber(GetSettingValue("textVerticalOffset"), -8, 8)
    local labelWidth = frame.contentWidth or width
    local labelHeight = frame.contentHeight or height

    frame.layoutWidth = labelWidth
    frame.layoutHeight = labelHeight

    frame.centerLabel:ClearAnchors()
    frame.centerLabel:SetAnchor(CENTER, frame.track, CENTER, 0, textVerticalOffset)
    frame.centerLabel:SetDimensions(math.max(labelWidth - (textInset * 2), 10), labelHeight)

    frame.leftLabel:ClearAnchors()
    frame.leftLabel:SetAnchor(LEFT, frame.track, LEFT, textInset, textVerticalOffset)
    frame.leftLabel:SetDimensions(math.max(labelWidth * 0.5 - textInset, 10), labelHeight)

    frame.rightLabel:ClearAnchors()
    frame.rightLabel:SetAnchor(RIGHT, frame.track, RIGHT, -textInset, textVerticalOffset)
    frame.rightLabel:SetDimensions(math.max(labelWidth * 0.5 - textInset, 10), labelHeight)
end

function ResourceBars:GetResourceText(key)
    local state = self.state and self.state[key]
    local current = state and state.current or 0
    local effectiveMax = state and state.effectiveMax or state and state.maximum or 0
    local formatMode, position = GetBarTextSettings(key)
    if formatMode == "none" then
        return nil, nil, nil
    end

    local main = FormatByMode(current, effectiveMax, formatMode)
    local shieldMode
    local shieldValue = 0
    local shieldText = ""

    if key == "health" then
        shieldMode = NormalizeShieldTextMode(GetSettingValue("shieldTextMode"))
        shieldValue = self.shieldValue or 0
        if shieldValue > 0 then
            shieldText = ZO_AbbreviateAndLocalizeNumber(shieldValue, NUMBER_ABBREVIATION_PRECISION_TENTHS, USE_LOWERCASE_NUMBER_SUFFIXES)
        end
        if shieldMode == "shieldOnly" then
            main = zo_strformat("<<1>>", shieldText)
        elseif shieldMode == "healthAndShield" and shieldValue > 0 then
            main = string.format("%s [+%s]", main, shieldText)
        end
    end

    if position == "sides" then
        local numberText = FormatByMode(current, effectiveMax, "number")
        local percentText = FormatByMode(current, effectiveMax, "percent")
        local sideShieldText = ""
        if key == "health" and shieldMode == "shieldOnly" then
            numberText = shieldText
            percentText = ""
        elseif key == "health" and shieldMode == "healthAndShield" and shieldValue > 0 then
            sideShieldText = string.format(" [+%s]", shieldText)
        end

        if formatMode == "number" then
            return nil, numberText .. sideShieldText, ""
        elseif formatMode == "percent" then
            return nil, sideShieldText, percentText
        end
        return nil, numberText .. sideShieldText, percentText
    end

    return main, nil, nil
end

function ResourceBars:UpdateAllLabels()
    if not self.bars then
        return
    end

    self:ApplyTextStyle()

    for _, key in ipairs(BAR_ORDER) do
        local frame = self.bars[key]
        if frame then
            local centerText, leftText, rightText = self:GetResourceText(key)
            local formatMode, position = GetBarTextSettings(key)
            if formatMode == "none" then
                frame.centerLabel:SetHidden(true)
                frame.leftLabel:SetHidden(true)
                frame.rightLabel:SetHidden(true)
                frame.centerLabel:SetText("")
                frame.leftLabel:SetText("")
                frame.rightLabel:SetText("")
            elseif position == "sides" then
                frame.centerLabel:SetHidden(true)
                frame.leftLabel:SetHidden(false)
                frame.rightLabel:SetHidden(false)
                frame.leftLabel:SetText(leftText or "")
                frame.rightLabel:SetText(rightText or "")
            else
                frame.centerLabel:SetHidden(false)
                frame.leftLabel:SetHidden(true)
                frame.rightLabel:SetHidden(true)
                frame.centerLabel:SetText(centerText or "")
            end
        end
    end
end

function ResourceBars:ComputeLayoutMetrics()
    local barHeight = GetConfiguredBarHeight()
    local rowGap = GetRowSpacing()
    local hideHealth = ShouldHideHealthResourceBar()
    local colGap = GetColumnSpacing()
    local healthWidth = ClampNumber(GetSettingValue("rowHealthWidth"), MIN_HEALTH_WIDTH, MAX_ROW_WIDTH)
    local magickaWidth = ClampNumber(GetSettingValue("rowMagickaWidth"), MIN_RESOURCE_WIDTH, MAX_ROW_WIDTH)
    local staminaWidth = ClampNumber(GetSettingValue("rowStaminaWidth"), MIN_RESOURCE_WIDTH, MAX_ROW_WIDTH)
    local pyramidGap = colGap
    local bottomTotalWidth = magickaWidth + staminaWidth + pyramidGap
    local layoutWidth = hideHealth and bottomTotalWidth or math.max(healthWidth, bottomTotalWidth)
    local layoutHeight = hideHealth and barHeight or (barHeight * 2) + rowGap
    local layout = GetSettingValue("layout")
    if layout == "linear" then
        layoutWidth = bottomTotalWidth + (hideHealth and 0 or healthWidth + colGap)
        layoutHeight = barHeight
    elseif layout == "stacked" then
        layoutWidth = math.max(hideHealth and 0 or healthWidth, magickaWidth, staminaWidth)
        local rows = hideHealth and 2 or 3
        layoutHeight = (barHeight * rows) + (rowGap * (rows - 1))
    else
        layout = "pyramid"
    end

    return {
        layout = layout,
        barHeight = barHeight,
        width = layoutWidth,
        height = layoutHeight,
        rowGap = rowGap,
        hideHealth = hideHealth,
        pyramid = {
            healthWidth = healthWidth,
            magickaWidth = magickaWidth,
            staminaWidth = staminaWidth,
            bottomWidth = bottomTotalWidth,
            gap = pyramidGap,
        },
    }
end

function ResourceBars:ApplyTextStyle()
    if not self.bars then
        return
    end

    local font = BuildTextFont()
    local textAlpha = ClampNumber(GetSettingValue("textOpacity"), 10, 100) / 100
    local textColor = GetSettingValue("textColor") or DEFAULT_SETTINGS.textColor
    local textR = tonumber(textColor.r) or DEFAULT_SETTINGS.textColor.r
    local textG = tonumber(textColor.g) or DEFAULT_SETTINGS.textColor.g
    local textB = tonumber(textColor.b) or DEFAULT_SETTINGS.textColor.b

    for _, key in ipairs(BAR_ORDER) do
        local frame = self.bars[key]
        if frame then
            ApplyLabelTextStyle(frame.centerLabel, font, textR, textG, textB, textAlpha)
            ApplyLabelTextStyle(frame.leftLabel, font, textR, textG, textB, textAlpha)
            ApplyLabelTextStyle(frame.rightLabel, font, textR, textG, textB, textAlpha)
        end
    end
end

function ResourceBars:ApplyLayoutGeometry()
    if not self.bars then
        return
    end

    self.metrics = self:ComputeLayoutMetrics()
    local metrics = self.metrics

    local root = self:GetRoot()
    local mover = self:GetMover()

    root:SetDimensions(metrics.width, metrics.height)
    mover:SetDimensions(metrics.width, metrics.height)

    for _, key in ipairs(BAR_ORDER) do
        local frame = self.bars[key]
        SetResourceFillDirection(frame, key)
    end

    local p = metrics.pyramid
    local health = self.bars.health
    local magicka = self.bars.magicka
    local stamina = self.bars.stamina
    local healthCenterX = 0
    local resourceRowY = metrics.hideHealth and 0 or metrics.barHeight + metrics.rowGap
    local magickaX = -((p.staminaWidth + p.gap) * 0.5)
    local staminaX = (p.magickaWidth + p.gap) * 0.5
    local staminaY = resourceRowY
    if metrics.layout == "linear" then
        resourceRowY = 0
        staminaY = 0
        magickaX = (p.magickaWidth - metrics.width) * 0.5
        staminaX = (metrics.width - p.staminaWidth) * 0.5
        healthCenterX = (p.magickaWidth - p.staminaWidth) * 0.5
    elseif metrics.layout == "stacked" then
        magickaX = 0
        staminaX = 0
        staminaY = resourceRowY + metrics.barHeight + metrics.rowGap
    end

    health:SetHidden(metrics.hideHealth)
    health:SetDimensions(p.healthWidth, metrics.barHeight)
    self:UpdateLabelLayout(health, p.healthWidth, metrics.barHeight)
    health:ClearAnchors()
    health:SetAnchor(TOP, root, TOP, healthCenterX, 0)

    magicka:SetHidden(false)
    magicka:SetDimensions(p.magickaWidth, metrics.barHeight)
    self:UpdateLabelLayout(magicka, p.magickaWidth, metrics.barHeight)
    magicka:ClearAnchors()
    magicka:SetAnchor(TOP, root, TOP, magickaX, resourceRowY)

    stamina:SetHidden(false)
    stamina:SetDimensions(p.staminaWidth, metrics.barHeight)
    self:UpdateLabelLayout(stamina, p.staminaWidth, metrics.barHeight)
    stamina:ClearAnchors()
    stamina:SetAnchor(TOP, root, TOP, staminaX, staminaY)

    for _, key in ipairs(BAR_ORDER) do
        local state = self.state and self.state[key]
        if state then
            if ShouldShowResourceBarKey(key) then
                self:UpdatePatternOverlay(self.bars[key], state.current or 0, state.maximum or 0)
            end
            if ShouldShowResourceBarKey(key) and ShouldShowFeedback() then
                self:UpdateLowResourceFeedback(self.bars[key], key, state.current or 0, state.maximum or 0)
            else
                HideFrameFeedback(self.bars[key])
            end
        end
    end
end

function ResourceBars:ApplyMountStaminaAnchor()
    local mount = ZO_PlayerAttribute and ZO_PlayerAttribute:GetNamedChild("MountStamina")
    if not mount then
        return
    end

    if IsModuleEnabled() and GetSettingValue("attachMountStamina") ~= false then
        if not self.mountStaminaAnchors then
            self.mountStaminaAnchors = {}
            for index = 0, mount:GetNumAnchors() - 1 do
                local valid, point, relativeTo, relativePoint, offsetX, offsetY, constraints = mount:GetAnchor(index)
                if valid then
                    table.insert(self.mountStaminaAnchors, { point, relativeTo, relativePoint, offsetX, offsetY, constraints })
                end
            end
        end
        mount:ClearAnchors()
        mount:SetAnchor(TOPLEFT, self.bars.stamina, BOTTOMLEFT, 0, GetRowSpacing())
    elseif self.mountStaminaAnchors then
        mount:ClearAnchors()
        for _, anchor in ipairs(self.mountStaminaAnchors) do
            mount:SetAnchor(unpack(anchor, 1, 6))
        end
        self.mountStaminaAnchors = nil
    end
end

function ResourceBars:ApplyLayout()
    local position = GetPosition()
    local scale = GetScale()
    local root = self:GetRoot()
    local mover = self:GetMover()

    self:ApplyLayoutGeometry()

    root:SetScale(scale)
    root:ClearAnchors()
    root:SetAnchor(CENTER, GuiRoot, CENTER, position.x, position.y)
    if Nirnsteel_UI.HUDEditor then
        Nirnsteel_UI.HUDEditor:Apply("resourceBars",root,{
            name="Nirnsteel Resource Bars", position=position, enabled=IsModuleEnabled,
            defaultAnchor=function() return ZO_Anchor:New(CENTER,GuiRoot,CENTER,DEFAULT_POSITION.x,DEFAULT_POSITION.y) end,
            replaces=function(control) return control:GetName():find("^ZO_PlayerAttribute") ~= nil end,
            preview=function(active) self:SetSettingsPreviewActive(active) end,
            isPreviewActive=function() return self.settingsPreviewActive end,
        })
    end

    local health = self.state and self.state.health
    if health then
        self:UpdateHealthShieldOverlay(health.current or 0, health.maximum or 0)
    end

    mover:SetScale(scale)
    mover:ClearAnchors()
    mover:SetAnchor(CENTER, GuiRoot, CENTER, position.x, position.y)
    mover:SetHidden(not IsModuleUnlocked())
    self:ApplyMountStaminaAnchor()
end

function ResourceBars:SetStockPlayerBarsHidden(hidden)
    if ZO_PlayerAttribute then
        local health = ZO_PlayerAttribute:GetNamedChild("Health")
        local magicka = ZO_PlayerAttribute:GetNamedChild("Magicka")
        local stamina = ZO_PlayerAttribute:GetNamedChild("Stamina")
        local hideHealth = hidden or ShouldHideHealthResourceBar()

        if health then
            health:SetHidden(hideHealth)
        end
        if magicka then
            magicka:SetHidden(hidden)
        end
        if stamina then
            stamina:SetHidden(hidden)
        end
    end
end

function ResourceBars:SetSettingsPreviewActive(active)
    self.settingsPreviewActive = active or nil
    if self.settingsPreviewActive then
        self:RefreshPowerValues(true)
        self:ApplyLayout()
    end
    self:UpdateVisibility()
end

function ResourceBars:UpdateVisibility()
    local root = self:GetRoot()
    if not IsModuleEnabled() then
        root:SetHidden(true)
        return
    end

    if self.settingsPreviewActive then
        root:SetHidden(false)
        return
    end

    if not IsHudSceneShowing() then
        root:SetHidden(true)
        return
    end

    local shouldShow = false
    for _, key in ipairs(BAR_ORDER) do
        local state = self.state and self.state[key]
        if ShouldShowResourceBarKey(key) and state and ShouldShowResource(state.current, state.effectiveMax, state.fadeUntilMS) then
            shouldShow = true
            break
        end
    end

    root:SetHidden(not shouldShow)
end

function ResourceBars:UpdateBarValue(frame, current, maximum, instant, animateLoss)
    BarVisuals:SetValue(frame, current, maximum, not instant, animateLoss)
end

function ResourceBars:PlayResourcePulse(frame, key, pulseType, deltaRatio)
    if not frame or not frame.feedbackFlash then
        return
    end

    local now = GetFrameTimeMilliseconds()
    frame.lastFeedbackMS = frame.lastFeedbackMS or {}
    local lastMS = frame.lastFeedbackMS[pulseType] or 0
    if now - lastMS < MIN_FEEDBACK_INTERVAL_MS then
        return
    end
    frame.lastFeedbackMS[pulseType] = now

    local intensity = GetFeedbackIntensity()
    if intensity <= 0 then
        return
    end

    local r, g, b = GetResourceColor(key)
    local alpha = zo_clamp((0.42 + (deltaRatio * 1.8)) * intensity, 0, 0.85)

    if pulseType == "spend" then
        r = zo_clamp(r + 0.18, 0, 1)
        g = zo_clamp(g + 0.18, 0, 1)
        b = zo_clamp(b + 0.18, 0, 1)
    end

    BarVisuals:PlayFeedback(frame, pulseType, { r = r, g = g, b = b }, alpha)
end

function ResourceBars:PlayFullResourcePulse(frame, key)
    if not frame or not frame.readyFlash then
        return
    end

    local intensity = GetFeedbackIntensity()
    if intensity <= 0 then
        return
    end

    local r, g, b = GetResourceColor(key)
    local alpha = 0.72 * intensity
    BarVisuals:PlayFeedback(frame, "full",
        { r = zo_clamp(r + 0.22, 0, 1), g = zo_clamp(g + 0.22, 0, 1), b = zo_clamp(b + 0.22, 0, 1) }, alpha)
end

function ResourceBars:PlayShieldPulse(frame)
    if not frame or not frame.shieldPulse then
        return
    end

    local intensity = GetFeedbackIntensity()
    if intensity <= 0 then
        return
    end

    local shieldGlowColor = GetSettingValue("shieldGlowColor") or DEFAULT_SETTINGS.shieldGlowColor
    local r = tonumber(shieldGlowColor.r) or DEFAULT_SETTINGS.shieldGlowColor.r
    local g = tonumber(shieldGlowColor.g) or DEFAULT_SETTINGS.shieldGlowColor.g
    local b = tonumber(shieldGlowColor.b) or DEFAULT_SETTINGS.shieldGlowColor.b
    local alpha = 0.75 * intensity
    BarVisuals:PlayFeedback(frame, "shield", { r = r, g = g, b = b }, alpha)
end

function ResourceBars:UpdateLowResourceFeedback(frame, key, current, maximum)
    local threshold = key == "health" and LOW_RESOURCE_HEALTH_RATIO or LOW_RESOURCE_OTHER_RATIO
    local intensity = GetFeedbackIntensity()
    local r, g, b = GetResourceColor(key)
    BarVisuals:SetLowState(frame, current, maximum, { r = r, g = g, b = b }, threshold, intensity, ShouldShowLowResourceGlow())
end

function ResourceBars:UpdatePatternOverlay(frame, current, maximum)
    frame.patternBar:SetMinMax(0, maximum)
    frame.patternBar:SetValue(current)
    BarVisuals:ApplyPattern(frame)
end

function ResourceBars:UpdateHealthShieldOverlay(_healthCurrent, healthMax)
    local frame = self.bars and self.bars.health
    if not frame or not frame.shieldBar then
        return
    end

    local shield = self.shieldValue or 0
    BarVisuals:SetShield(frame, ShouldShowShieldOverlay() and shield or 0, healthMax, false)
end

function ResourceBars:UpdateResource(key, current, maximum, effectiveMax, instant)
    self.state = self.state or {}
    self.state[key] = self.state[key] or {}
    local previousCurrent = self.state[key].current
    local previousMaximum = self.state[key].maximum
    self.state[key].current = current
    self.state[key].maximum = maximum
    self.state[key].effectiveMax = effectiveMax or maximum
    self.state[key].fadeUntilMS = GetFrameTimeMilliseconds() + VISIBILITY_HOLD_MS

    local frame = self.bars and self.bars[key]
    if not frame then
        return
    end

    self:UpdateBarValue(frame, current, maximum, instant or key == "health", not instant)

    local currentValue = tonumber(current) or 0
    local maximumValue = tonumber(maximum) or 0
    local previousCurrentValue = tonumber(previousCurrent)
    local previousMaximumValue = tonumber(previousMaximum)
    if not instant and previousCurrentValue and previousMaximumValue and previousMaximumValue > 0 and maximumValue > 0 then
        local delta = currentValue - previousCurrentValue
        local deltaRatio = math.abs(delta) / maximumValue
        if deltaRatio >= MIN_FEEDBACK_DELTA_RATIO then
            if delta > 0 and ShouldShowGainPulse() then
                self:PlayResourcePulse(frame, key, "gain", deltaRatio)
            elseif delta < 0 and ShouldShowSpendPulse() then
                self:PlayResourcePulse(frame, key, "spend", deltaRatio)
            end
        end

        if currentValue >= maximumValue and previousCurrentValue < previousMaximumValue and ShouldShowFullResourcePulse() then
            self:PlayFullResourcePulse(frame, key)
        end
    end

    if key == "health" then
        self:UpdateHealthShieldOverlay(current, maximum)
    end

    if ShouldShowFeedback() then
        self:UpdateLowResourceFeedback(frame, key, current, maximum)
    else
        HideFrameFeedback(frame)
    end

    self:UpdateAllLabels()
    self:UpdateVisibility()
end

function ResourceBars:RefreshPowerValues(instant)
    self:GetRoot()
    for key, data in pairs(RESOURCE_DATA) do
        local current, maximum, effectiveMax = GetUnitPower("player", data.powerType)
        self:UpdateResource(key, current, maximum, effectiveMax, instant)
    end
    self:RefreshShieldState(true)
    self:UpdateAllLabels()
end

function ResourceBars:OnPowerUpdate(unitTag, powerIndex, powerType, current, maximum, effectiveMax)
    if unitTag ~= "player" then
        return
    end

    local key = POWER_KEY_BY_TYPE[powerType]
    if not key then
        return
    end

    self:UpdateResource(key, current, maximum, effectiveMax, false)
end

function ResourceBars:RefreshShieldState(force)
    local value, maxValue, sequenceId = GetUnitAttributeVisualizerEffectInfo("player", ATTRIBUTE_VISUAL_POWER_SHIELDING, STAT_MITIGATION, ATTRIBUTE_HEALTH, COMBAT_MECHANIC_FLAGS_HEALTH)
    local previousShield = self.shieldValue or 0
    self.shieldValue = math.max(tonumber(value) or 0, 0)
    self.shieldMax = math.max(tonumber(maxValue) or 0, 0)
    self.shieldSequenceId = sequenceId or self.shieldSequenceId

    local health = self.state and self.state.health
    if health then
        self:UpdateHealthShieldOverlay(health.current or 0, health.maximum or 0)
    end

    if not force and self.shieldValue > previousShield and ShouldShowShieldPulse() then
        local frame = self.bars and self.bars.health
        self:PlayShieldPulse(frame)
    end

    if force then
        self:UpdateAllLabels()
    end
end

function ResourceBars:PreviewFeedback()
    self:RefreshPowerValues(true)
    self:ApplyLayout()
    self:GetRoot():SetHidden(false)

    for index, key in ipairs(BAR_ORDER) do
        local frame = self.bars and self.bars[key]
        if frame and ShouldShowResourceBarKey(key) then
            zo_callLater(function()
                self:PlayResourcePulse(frame, key, "gain", 0.18)
            end, (index - 1) * 180)
            zo_callLater(function()
                self:PlayResourcePulse(frame, key, "spend", 0.18)
            end, 650 + ((index - 1) * 180))
            zo_callLater(function()
                self:PlayFullResourcePulse(frame, key)
            end, 1300 + ((index - 1) * 180))
        end
    end

    zo_callLater(function()
        local health = self.bars and self.bars.health
        self:PlayShieldPulse(health)
    end, 1950)
end

function ResourceBars:OnShieldVisualAdded(unitTag, visualType, statType, attributeType, powerType, value, maxValue, sequenceId)
    if unitTag ~= "player" or visualType ~= ATTRIBUTE_VISUAL_POWER_SHIELDING or attributeType ~= ATTRIBUTE_HEALTH then
        return
    end

    self.shieldValue = math.max((self.shieldValue or 0) + (tonumber(value) or 0), 0)
    self.shieldMax = math.max((self.shieldMax or 0) + (tonumber(maxValue) or 0), 0)
    self.shieldSequenceId = sequenceId or self.shieldSequenceId
    self:RefreshShieldState(true)
    if (tonumber(value) or 0) > 0 and ShouldShowShieldPulse() then
        local frame = self.bars and self.bars.health
        self:PlayShieldPulse(frame)
    end
end

function ResourceBars:OnShieldVisualUpdated(unitTag, visualType, statType, attributeType, powerType, oldValue, newValue, oldMaxValue, newMaxValue, sequenceId)
    if unitTag ~= "player" or visualType ~= ATTRIBUTE_VISUAL_POWER_SHIELDING or attributeType ~= ATTRIBUTE_HEALTH then
        return
    end

    self.shieldValue = math.max((self.shieldValue or 0) + ((tonumber(newValue) or 0) - (tonumber(oldValue) or 0)), 0)
    self.shieldMax = math.max((self.shieldMax or 0) + ((tonumber(newMaxValue) or 0) - (tonumber(oldMaxValue) or 0)), 0)
    self.shieldSequenceId = sequenceId or self.shieldSequenceId
    self:RefreshShieldState(true)
    if (tonumber(newValue) or 0) > (tonumber(oldValue) or 0) and ShouldShowShieldPulse() then
        local frame = self.bars and self.bars.health
        self:PlayShieldPulse(frame)
    end
end

function ResourceBars:OnShieldVisualRemoved(unitTag, visualType, statType, attributeType, powerType, value, maxValue, sequenceId)
    if unitTag ~= "player" or visualType ~= ATTRIBUTE_VISUAL_POWER_SHIELDING or attributeType ~= ATTRIBUTE_HEALTH then
        return
    end

    self.shieldValue = math.max((self.shieldValue or 0) - (tonumber(value) or 0), 0)
    self.shieldMax = math.max((self.shieldMax or 0) - (tonumber(maxValue) or 0), 0)
    self.shieldSequenceId = sequenceId or self.shieldSequenceId
    self:RefreshShieldState(true)
end

function ResourceBars:RegisterEvents()
    if self.eventsRegistered then
        return
    end

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_POWER_UPDATE, function(_, ...)
        self:OnPowerUpdate(...)
    end)
    EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE, EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_ShieldAdded", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, function(_, ...)
        self:OnShieldVisualAdded(...)
    end)
    EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE .. "_ShieldAdded", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, REGISTER_FILTER_UNIT_TAG, "player")
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_ShieldUpdated", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, function(_, ...)
        self:OnShieldVisualUpdated(...)
    end)
    EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE .. "_ShieldUpdated", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, REGISTER_FILTER_UNIT_TAG, "player")
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_ShieldRemoved", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, function(_, ...)
        self:OnShieldVisualRemoved(...)
    end)
    EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE .. "_ShieldRemoved", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, REGISTER_FILTER_UNIT_TAG, "player")

    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Activated", EVENT_PLAYER_ACTIVATED, function()
        self:RefreshPowerValues(true)
        self:ApplyLayout()
        self:SetStockPlayerBarsHidden(IsModuleEnabled())
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_SettingsChanged", EVENT_INTERFACE_SETTING_CHANGED, function(_, settingType, settingId)
        if settingType == SETTING_TYPE_UI
            and (settingId == UI_SETTING_SHOW_RESOURCE_BARS
                or settingId == UI_SETTING_FADE_PLAYER_BARS
                or settingId == UI_SETTING_RESOURCE_NUMBERS) then
            self:RefreshPowerValues(true)
            self:UpdateVisibility()
        end
    end)
    EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE .. "_SettingsChanged", EVENT_INTERFACE_SETTING_CHANGED, REGISTER_FILTER_SETTING_SYSTEM_TYPE, SETTING_TYPE_UI)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_ScreenResized", EVENT_SCREEN_RESIZED, function()
        self:ApplyLayout()
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Gamepad", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
        self:ApplyLayout()
    end)

    if HUD_SCENE then
        HUD_SCENE:RegisterCallback("StateChange", function()
            self:UpdateVisibility()
            self:SetStockPlayerBarsHidden(IsModuleEnabled())
        end)
    end

    if HUD_UI_SCENE then
        HUD_UI_SCENE:RegisterCallback("StateChange", function()
            self:UpdateVisibility()
            self:SetStockPlayerBarsHidden(IsModuleEnabled())
        end)
    end

    self.eventsRegistered = true
end

function ResourceBars:RefreshSettings()
    self:RegisterEvents()
    self:ApplyTextStyle()
    self:ApplyLayout()

    if IsModuleEnabled() then
        self:SetStockPlayerBarsHidden(true)
        self:RefreshPowerValues(true)
    else
        self:SetStockPlayerBarsHidden(false)
        self:GetRoot():SetHidden(true)
        self:GetMover():SetHidden(true)
    end
end

local DEBUG_COMMANDS =
{
    ["/nsbars"] = function()
        ResourceBars:RefreshPowerValues(true)
        ResourceBars:ApplyLayout()
    end,
    ["/nsbarsfeedback"] = function()
        ResourceBars:PreviewFeedback()
    end,
}

local function IsDebugModeEnabled()
    return Nirnsteel_UI.Settings and Nirnsteel_UI.Settings:IsDebugModeEnabled()
end

local function RegisterDebugCommands()
    for command, handler in pairs(DEBUG_COMMANDS) do
        SLASH_COMMANDS[command] = IsDebugModeEnabled() and handler or nil
    end
end

function ResourceBars:RefreshDebugCommands()
    RegisterDebugCommands()
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE .. "_Loaded", EVENT_ADD_ON_LOADED)
    ResourceBars:RefreshSettings()
    RegisterDebugCommands()
    zo_callLater(function() ResourceBars:RefreshSettings() end, 1000)
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Loaded", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
