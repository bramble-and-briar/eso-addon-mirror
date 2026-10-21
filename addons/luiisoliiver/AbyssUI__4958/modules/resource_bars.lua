local ADDON_NAME = "AbyssUI"
local EVENT_NAMESPACE = ADDON_NAME .. "_ResourceBars"

NAGA_UI = NAGA_UI or {}
local NAGA_UI = NAGA_UI
local BarVisuals = NAGA_UI.BarVisuals
local LevelVisuals = NAGA_UI.LevelVisuals
local ResourceBars = {}
NAGA_UI.ResourceBars = ResourceBars

local DEFAULT_SETTINGS =
{
    enabled = true,
    unlocked = false,
    layout = "stacked",
    attachMountStamina = true,
    -- Barra alternativa estilo LuiExtended: mostra XP (ou CP) e, quando montado, a stamina da montaria.
    altBarEnabled = true,
    altBarHeight = 9,
    altBarIconSize = 18,
    altBarGap = 2,
    scale = 109,
    barHeight = 25,
    rowSpacing = 3,
    columnSpacing = 8,
    rowHealthWidth = 270,
    rowMagickaWidth = 270,
    rowStaminaWidth = 270,
    barTextureKey = "Cloud",
    healthBarTexture = "Cloud",
    magickaBarTexture = "Cloud",
    staminaBarTexture = "Cloud",
    opacity = 100,
    glossEnabled = true,
    healthTextFormat = "numberAndPercent",
    magickaTextFormat = "numberAndPercent",
    staminaTextFormat = "numberAndPercent",
    healthTextPosition = "center",
    magickaTextPosition = "center",
    staminaTextPosition = "center",
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
    feedbackIntensity = 100,
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
    textFontKey = "trajan",
    textSize = 18,
    textOutline = "thick-outline",
    textOpacity = 100,
    textInset = 6,
    textVerticalOffset = 3,
    textColor = { r = 0.96, g = 0.92, b = 0.82 },
    -- Alinhado ao Target Frame (nameTextSize / levelTextSize / classIconSize / championIconSize)
    identityClassIconSize = 20,
    identityLevelIconSize = 20,
    identityNameSize = 18,
    identityNameFontKey = "trajan",
    identityNameOutline = "thick-outline",
    identityNameOpacity = 100,
    identityNameColor = { r = 1, g = 1, b = 1 },
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
    currentMax = "currentMax",
    ["Current/Max"] = "currentMax",
    ["Atual/Máximo"] = "currentMax",
}

local TEXT_POSITION_ALIASES =
{
    center = "center",
    Center = "center",
    sides = "sides",
    Sides = "sides",
    left = "left",
    Left = "left",
    right = "right",
    Right = "right",
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
    if NAGA_UI.Settings then
        return NAGA_UI.Settings:GetResourceBars()
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
    return not NAGA_UI.Settings or NAGA_UI.Settings:IsResourceBarsEnabled()
end

local function ShouldHideHealthResourceBar()
    return NAGA_UI.Settings and NAGA_UI.Settings:ShouldHardcoreOcultarHealthResourceBar()
end

local function ShouldShowResourceBarKey(key)
    return key ~= "health" or not ShouldHideHealthResourceBar()
end

local function IsModuleUnlocked()
    return IsModuleEnabled()
        and NAGA_UI.Settings
        and NAGA_UI.Settings:IsResourceBarsUnlocked()
end

local function GetPosition()
    if NAGA_UI.Settings then
        return NAGA_UI.Settings:GetResourceBarsPosition()
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

-- ---------------------------------------------------------------------------
-- Barra alternativa (XP / montaria) no estilo do LuiExtended
-- ---------------------------------------------------------------------------
local ALT_MOUNT_ICON = "/esoui/art/icons/servicemappins/servicepin_stable.dds"
local ALT_FALLBACK_XP_ICON = "EsoUI/Art/Champion/champion_icon.dds"
local ALT_BAR_TEXTURE = "EsoUI/Art/Miscellaneous/progressbar_genericFill_tall.dds"
local ALT_BAR_COORDS = { 0, 1, 0, 0.8125 }
local ALT_FALLBACK_XP_COLOR = { r = 0.80, g = 0.66, b = 0.16 }

local function IsAltBarEnabled()
    return IsModuleEnabled() and GetSettingValue("altBarEnabled") ~= false
end

local function GetAltBarHeight()
    return ClampNumber(GetSettingValue("altBarHeight"), 4, 24)
end

local function GetAltBarIconSize()
    return ClampNumber(GetSettingValue("altBarIconSize"), 10, 32)
end

local function GetAltBarGap()
    return ClampNumber(GetSettingValue("altBarGap"), 0, 16)
end

-- Altura total da linha (o icone e maior que a barra e fica centralizado nela).
local function GetAltBarRowHeight()
    return math.max(GetAltBarHeight(), GetAltBarIconSize())
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
    -- Vida/Magicka/Vigor acompanham a mesma FONTE escolhida para o nick.
    -- O tamanho continua sendo controlado separadamente pelo texto das barras.
    local fontKey = GetSettingValue("identityNameFontKey") or GetSettingValue("textFontKey") or "gameSmall"
    local face = FONT_FACES[fontKey] or FONT_FACES.gameSmall
    local size = ClampNumber(GetSettingValue("textSize"), 8, 32)
    -- O contorno também acompanha o nick para que a troca de fonte fique consistente.
    local outline = GetSettingValue("identityNameOutline") or GetSettingValue("textOutline")
    if outline == "none" then
        return string.format("%s|%d", face, size)
    end

    return string.format("%s|%d|%s", face, size, outline or "soft-shadow-thick")
end

-- Copia do Target Frame: nick, nível/CP, ícone de classe e ícone de CP.
local function GetTargetMatchedIdentitySizes()
    local tf
    if NAGA_UI.Settings and NAGA_UI.Settings.GetTargetFrame then
        local ok, result = pcall(function()
            return NAGA_UI.Settings:GetTargetFrame()
        end)
        if ok then
            tf = result
        end
    end
    -- Defaults iguais ao Target Frame (nameTextSize 20, levelTextSize 16, class 18, champion 18).
    local nameSize = ClampNumber(tf and tonumber(tf.nameTextSize) or GetSettingValue("identityNameSize") or 20, 10, 50)
    local levelSize = ClampNumber(tf and tonumber(tf.levelTextSize) or GetSettingValue("identityNameSize") or 16, 8, 36)
    local classSize = ClampNumber(tf and tonumber(tf.classIconSize) or GetSettingValue("identityClassIconSize") or 18, 10, 40)
    local cpIconSize = ClampNumber(tf and tonumber(tf.championIconSize) or GetSettingValue("identityLevelIconSize") or 18, 8, 40)
    -- Target limita o ícone de classe à altura do nick.
    classSize = math.min(classSize, nameSize)
    -- HUD 2: o nick e o CP devem respeitar a fonte escolhida nas opções da identidade
    -- do personagem. Não usar primeiro a fonte do Target Frame, pois ela sobrescreve
    -- a escolha do HUD 2 e faz parecer que a fonte não muda.
    local fontKey = GetSettingValue("identityNameFontKey") or (tf and tf.textFontKey) or "gameSmall"
    local outline = GetSettingValue("identityNameOutline") or (tf and tf.textOutline) or "thick-outline"
    return nameSize, levelSize, classSize, cpIconSize, fontKey, outline
end

local function BuildIdentityFont(size, fontKey, outline)
    local face = FONT_FACES[fontKey] or FONT_FACES.gameSmall
    size = ClampNumber(size, 8, 50)
    outline = outline or "thick-outline"
    if outline == "none" then
        return string.format("%s|%d", face, size)
    end
    return string.format("%s|%d|%s", face, size, outline)
end

local function BuildIdentityNameFont(sizeOverride)
    local nameSize, _, _, _, fontKey, outline = GetTargetMatchedIdentitySizes()
    return BuildIdentityFont(sizeOverride or nameSize, fontKey, outline)
end


local function GetIdentityNameColor()
    local color = GetSettingValue("identityNameColor") or { r = 0.92, g = 0.90, b = 0.84 }
    return tonumber(color.r) or 0.92,
        tonumber(color.g) or 0.90,
        tonumber(color.b) or 0.84,
        ClampNumber(GetSettingValue("identityNameOpacity"), 10, 100) / 100
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
    -- Direção solicitada para o HUD 2:
    -- Vida preenche da direita para a esquerda; Magicka da esquerda para a direita.
    local alignment = BAR_ALIGNMENT_NORMAL
    if key == "health" then
        alignment = BAR_ALIGNMENT_REVERSE
    elseif key == "magicka" then
        alignment = BAR_ALIGNMENT_NORMAL
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
        rpgBorder = true,
        innerShadowAlpha = ClampNumber(GetSettingValue("innerShadowAlpha"), 0, 100) / 100,
        outerShadowAlpha = ClampNumber(GetSettingValue("outerShadowAlpha"), 0, 100) / 100,
        textureInfo = (BarVisuals.GetBarTextureInfo and BarVisuals:GetBarTextureInfo(
            (NAGA_UI.Settings and NAGA_UI.Settings:GetResourceBars().barTextureKey)
                or (NAGA_UI.Settings and NAGA_UI.Settings:GetResourceBars().healthBarTexture)
                or "genericTall"))
            or BarVisuals.Textures.genericTall,
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
    current = tonumber(current) or 0
    maximum = tonumber(maximum) or 0
    if mode == "currentMax" then
        local cur = zo_floor(current)
        local maxv = zo_floor(maximum)
        if ZO_CommaDelimitNumber then
            return string.format("%s/%s", ZO_CommaDelimitNumber(cur), ZO_CommaDelimitNumber(maxv))
        end
        return string.format("%d/%d", cur, maxv)
    end
    local override = TEXT_FORMAT_SETTING[mode] or RESOURCE_NUMBERS_SETTING_NUMBER_AND_PERCENT
    local formatted
    if ZO_FormatResourceBarCurrentAndMax then
        formatted = ZO_FormatResourceBarCurrentAndMax(current, maximum, override)
    else
        formatted = zo_strformat(SI_ATTRIBUTE_NUMBERS_WITH_PERCENT, current, 0)
    end

    -- Mantém o formato "número + %" igual ao alvo selecionado, com dois
    -- espaços visuais entre o valor e o percentual (ex.: "1500  100%").
    if mode == "numberAndPercent" and formatted then
        formatted = string.gsub(formatted, "%s+(%d+%%)$", "  %1")
    end

    return formatted
end


local function IsEditHudShowing()
    return SCENE_MANAGER and SCENE_MANAGER.IsShowing
        and (SCENE_MANAGER:IsShowing("hud_editor_keyboard") or SCENE_MANAGER:IsShowing("hud_editor_gamepad"))
end

local function IsHudSceneShowing()
    if IsEditHudShowing() then
        return true
    end
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

    -- Prefere o controle XML (herda ZO_HUDManager_Element) para aparecer no Edit HUD nativo.
    local root = NAGA_UI_ResourceBarsRoot or WINDOW_MANAGER:CreateTopLevelWindow("NAGA_UI_ResourceBarsRoot")
    root:SetDimensions(DEFAULT_ROW_WIDTH, (GetConfiguredBarHeight() * 2) + 5)
    root:SetClampedToScreen(true)
    root:SetMouseEnabled(false)
    root:SetMovable(false)
    root:SetDrawTier(DT_HIGH)
    root:SetHidden(true)
    self.root = root

    -- Identidade igual à foto: [classe] [nick] [estrela CP] [nível/CP]
    -- A identidade fica FORA do root das barras.
    -- Se fosse filha do root, o clamping/área do elemento nativo do HUD
    -- pode cortar o nick/ícones quando a Vigor muda (ex.: segurando SHIFT).
    -- Como top-level, ela continua ancorada ao HUD, mas nunca é recortada pelo root.
    local identity = WINDOW_MANAGER:CreateTopLevelWindow("NAGA_UI_ResourceBarsIdentity")
    identity:SetDimensions(DEFAULT_ROW_WIDTH, 26)
    identity:SetAnchor(BOTTOM, root, TOP, 0, -2)
    identity:SetDrawTier(DT_HIGH)
    identity:SetDrawLayer(DL_OVERLAY)
    identity:SetDrawLevel(30)
    identity:SetMouseEnabled(false)
    identity:SetClampedToScreen(false)
    identity:SetHidden(true)
    self.identity = identity

    local classIcon = WINDOW_MANAGER:CreateControl(nil, identity, CT_TEXTURE)
    classIcon:SetDimensions(18, 18)
    classIcon:SetDrawLevel(31)
    self.identityClassIcon = classIcon

    local nameLabel = WINDOW_MANAGER:CreateControl(nil, identity, CT_LABEL)
    nameLabel:SetFont(BuildIdentityNameFont())
    local nr, ng, nb, na = GetIdentityNameColor()
    nameLabel:SetColor(nr, ng, nb, na)
    nameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    nameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    nameLabel:SetDrawLevel(31)
    self.identityName = nameLabel

    local levelIcon = WINDOW_MANAGER:CreateControl(nil, identity, CT_TEXTURE)
    levelIcon:SetDimensions(16, 16)
    levelIcon:SetTexture("EsoUI/Art/Champion/champion_icon.dds")
    levelIcon:SetDrawLevel(31)
    levelIcon:SetHidden(true)
    self.identityLevelIcon = levelIcon

    local levelLabel = WINDOW_MANAGER:CreateControl(nil, identity, CT_LABEL)
    levelLabel:SetFont("$(BOLD_FONT)|18|thick-outline")
    levelLabel:SetColor(0.92, 0.90, 0.84, 1)
    levelLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    levelLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    levelLabel:SetDrawLevel(31)
    self.identityLevelText = levelLabel

    self.bars = {}
    self:CreateResourceBar("health", RESOURCE_DATA.health)
    self:CreateResourceBar("magicka", RESOURCE_DATA.magicka)
    self:CreateResourceBar("stamina", RESOURCE_DATA.stamina)
    self:CreateAltBar(root)

    return root
end

function ResourceBars:IsAltBarEnabled()
    return IsAltBarEnabled()
end

function ResourceBars:CreateAltBar(root)
    local alt = {}

    -- borda preta + fundo escuro (a cor do fundo muda conforme o modo)
    local backdrop = WINDOW_MANAGER:CreateControl(nil, root, CT_BACKDROP)
    backdrop:SetCenterColor(0, 0, 0, 0.9)
    backdrop:SetEdgeColor(0, 0, 0, 0.9)
    backdrop:SetDrawLevel(1)
    backdrop:SetMouseEnabled(true)
    alt.backdrop = backdrop

    local center = WINDOW_MANAGER:CreateControl(nil, backdrop, CT_BACKDROP)
    center:SetAnchor(TOPLEFT, backdrop, TOPLEFT, 1, 1)
    center:SetAnchor(BOTTOMRIGHT, backdrop, BOTTOMRIGHT, -1, -1)
    center:SetCenterColor(0, 0.1, 0.1, 0.9)
    center:SetEdgeColor(0, 0, 0, 0)
    center:SetDrawLevel(2)
    alt.center = center

    -- "iluminado" (Champion): fica atras da barra principal
    local enlightenment = WINDOW_MANAGER:CreateControl(nil, backdrop, CT_STATUSBAR)
    enlightenment:SetAnchor(TOPLEFT, backdrop, TOPLEFT, 1, 1)
    enlightenment:SetAnchor(BOTTOMRIGHT, backdrop, BOTTOMRIGHT, -1, -1)
    enlightenment:SetTexture(ALT_BAR_TEXTURE)
    enlightenment:SetTextureCoords(unpack(ALT_BAR_COORDS))
    enlightenment:SetMinMax(0, 1)
    enlightenment:SetValue(0)
    enlightenment:SetDrawLevel(3)
    enlightenment:SetHidden(true)
    alt.enlightenment = enlightenment

    local bar = WINDOW_MANAGER:CreateControl(nil, backdrop, CT_STATUSBAR)
    bar:SetAnchor(TOPLEFT, backdrop, TOPLEFT, 1, 1)
    bar:SetAnchor(BOTTOMRIGHT, backdrop, BOTTOMRIGHT, -1, -1)
    bar:SetTexture(ALT_BAR_TEXTURE)
    bar:SetTextureCoords(unpack(ALT_BAR_COORDS))
    bar:SetMinMax(0, 1)
    bar:SetValue(0)
    bar:SetDrawLevel(4)
    alt.bar = bar

    local icon = WINDOW_MANAGER:CreateControl(nil, root, CT_TEXTURE)
    icon:SetDimensions(18, 18)
    icon:SetDrawLevel(5)
    alt.icon = icon

    backdrop:SetHandler("OnMouseEnter", function(control)
        self:ShowAltBarTooltip(control)
    end)
    backdrop:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)

    self.alt = alt
end

function ResourceBars:UpdateIdentityDisplay()
    if not self.identity or not self.identityName then
        return
    end

    local name = GetUnitName("player") or ""
    -- Permite nomes longos; não corta em 30 caracteres.
    -- 50 caracteres é o limite solicitado para a exibição do nick.
    self.identityName:SetText(string.sub(name, 1, 50))
    name = string.sub(name, 1, 50)

    local classId = GetUnitClassId and GetUnitClassId("player")
    local iconTexture = nil
    if classId and GetClassIcon then
        local ok, texture = pcall(GetClassIcon, classId)
        if ok then iconTexture = texture end
    end
    if not iconTexture or iconTexture == "" then
        local classIcons = {
            [1] = "EsoUI/Art/Icons/class_dragonknight.dds",
            [2] = "EsoUI/Art/Icons/class_sorcerer.dds",
            [3] = "EsoUI/Art/Icons/class_nightblade.dds",
            [4] = "EsoUI/Art/Icons/class_warden.dds",
            [5] = "EsoUI/Art/Icons/class_necromancer.dds",
            [6] = "EsoUI/Art/Icons/class_arcanist.dds",
        }
        iconTexture = classIcons[classId]
    end
    if iconTexture and iconTexture ~= "" and self.identityClassIcon then
        self.identityClassIcon:SetTexture(iconTexture)
        self.identityClassIcon:SetHidden(false)
    elseif self.identityClassIcon then
        self.identityClassIcon:SetHidden(true)
    end

    local unitLevel = GetUnitLevel and (GetUnitLevel("player") or 1) or 1
    local isChampion = (IsUnitChampion and IsUnitChampion("player") == true) or unitLevel >= 50
    local championPoints = 0
    local levelLabel
    if isChampion then
        championPoints = tonumber(GetPlayerChampionPointsEarned and GetPlayerChampionPointsEarned() or 0) or 0
        levelLabel = tostring(championPoints)
        if self.identityLevelIcon then
            self.identityLevelIcon:SetTexture("EsoUI/Art/Champion/champion_icon.dds")
            self.identityLevelIcon:SetHidden(false)
        end
    else
        levelLabel = tostring(unitLevel)
        if self.identityLevelIcon then
            self.identityLevelIcon:SetHidden(true)
        end
    end

    -- Grupo compacto centralizado acima da vida:
    -- [classe] [nick] [estrela][CP]  (estrela colada no número)
    local classVisible = self.identityClassIcon and not self.identityClassIcon:IsHidden()
    local levelIconVisible = self.identityLevelIcon and not self.identityLevelIcon:IsHidden()
    -- Exact Target Frame sizes: name, level/CP, class icon, CP icon (all of them).
    local nameFontSize, levelFontSize, classSize, levelIconSize, fontKey, outline = GetTargetMatchedIdentitySizes()
    -- Altura da linha = mesma regra do Target (nick + nível/CP + ícones).
    local rowHeight = math.max(24, nameFontSize + 4, levelFontSize + 4, classSize, levelIconSize)
    local gapClassName = 6   -- CLASS_NAME_GAP do Target
    local gapNameLevel = 8   -- NAME_LEVEL_GAP do Target
    local gapIconNum = 2     -- championIconGap do Target

    self.identityName:SetFont(BuildIdentityFont(nameFontSize, fontKey, outline))
    local nameR, nameG, nameB, nameA = GetIdentityNameColor()
    self.identityName:SetColor(nameR, nameG, nameB, nameA)

    -- Same tier colors as the target frame CP badge (by champion point total).
    local levelColor = { r = 0.92, g = 0.90, b = 0.84 }
    local levelDisplayText = levelLabel
    if LevelVisuals and LevelVisuals.GetTier then
        local _, tier = LevelVisuals:GetTier(
        {
            champion = isChampion,
            championPoints = championPoints,
        })
        if tier and tier.textColor then
            levelColor = tier.textColor
        end
        if isChampion and LevelVisuals.BuildGradientText and tier then
            levelDisplayText = LevelVisuals:BuildGradientText(levelLabel, tier, false)
        end
    end
    if self.identityLevelText then
        self.identityLevelText:SetFont(BuildIdentityFont(levelFontSize, fontKey, outline))
        self.identityLevelText:SetText(levelDisplayText)
        self.identityLevelText:SetColor(levelColor.r or 1, levelColor.g or 1, levelColor.b or 1, 1)
        self.identityLevelText:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        self.identityLevelText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        self.identityLevelText:SetHidden(false)
    end
    self.identityName:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    self.identityName:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    -- Force icon pixel sizes every refresh (class + CP star) from Target settings.
    if self.identityClassIcon then
        self.identityClassIcon:SetDimensions(classSize, classSize)
        self.identityClassIcon:ClearAnchors()
    end
    self.identityName:ClearAnchors()
    if self.identityLevelIcon then
        self.identityLevelIcon:SetDimensions(levelIconSize, levelIconSize)
        self.identityLevelIcon:ClearAnchors()
    end
    if self.identityLevelText then
        self.identityLevelText:ClearAnchors()
    end

    local nameW = 0
    if self.identityName.GetTextWidth then
        local ok, w = pcall(function() return self.identityName:GetTextWidth() end)
        if ok and tonumber(w) then nameW = tonumber(w) end
    end
    if nameW <= 0 then
        nameW = math.max(30, #name * 8)
    end
    local levelW = 0
    if self.identityLevelText and self.identityLevelText.GetTextWidth then
        local ok, w = pcall(function() return self.identityLevelText:GetTextWidth() end)
        if ok and tonumber(w) then levelW = tonumber(w) end
    end
    if levelW <= 0 then
        levelW = math.max(18, #levelLabel * math.max(nameFontSize * 0.55, 6))
    end

    local totalWidth = 0
    if classVisible then totalWidth = totalWidth + classSize + gapClassName end
    totalWidth = totalWidth + nameW
    if levelIconVisible then
        totalWidth = totalWidth + gapNameLevel + levelIconSize + gapIconNum + levelW
    else
        totalWidth = totalWidth + gapNameLevel + levelW
    end

    -- O conjunto inteiro fica centralizado no eixo da barra: [classe] [nick] [CP] [nível].
    local identityW = math.max(120, totalWidth + 12)
    self.identity:SetDimensions(identityW, rowHeight)
    self.identity:ClearAnchors()
    self.identity:SetAnchor(BOTTOM, self.root, TOP, 0, -2)
    local startX = (identityW - totalWidth) * 0.5
    local x = startX
    -- Midline for nick/class; CP/level nudged slightly down.
    local midY = rowHeight * 0.5
    local levelNudge = 2  -- igual ao LEVEL_TEXT_VERTICAL_NUDGE do Target

    local function AnchorOnMidline(control, width, yNudge)
        control:ClearAnchors()
        control:SetAnchor(CENTER, self.identity, TOPLEFT, x + width * 0.5, midY + (yNudge or 0))
    end

    if classVisible then
        self.identityClassIcon:SetDimensions(classSize, classSize)
        AnchorOnMidline(self.identityClassIcon, classSize, 0)
        x = x + classSize + gapClassName
    end

    self.identityName:SetDimensions(math.max(1, nameW + 2), rowHeight)
    AnchorOnMidline(self.identityName, nameW, 0)
    x = x + nameW

    if levelIconVisible then
        x = x + gapNameLevel
        -- CP icon stays on the nick midline; only the number is nudged down.
        self.identityLevelIcon:SetDimensions(levelIconSize, levelIconSize)
        AnchorOnMidline(self.identityLevelIcon, levelIconSize, 0)
        x = x + levelIconSize + gapIconNum
        self.identityLevelText:SetDimensions(math.max(1, levelW + 2), rowHeight)
        AnchorOnMidline(self.identityLevelText, levelW, levelNudge)
    else
        x = x + gapNameLevel
        self.identityLevelText:SetDimensions(math.max(1, levelW + 2), rowHeight)
        AnchorOnMidline(self.identityLevelText, levelW, levelNudge)
    end
end

function ResourceBars:GetMover()
    if self.mover then
        return self.mover
    end

    local mover = WINDOW_MANAGER:CreateTopLevelWindow("NAGA_UI_ResourceBarsMover")
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
    label:SetText("NAGA Resource Bars")
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
        if NAGA_UI.Settings then
            NAGA_UI.Settings:SetResourceBarsPosition(x, y)
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
            elseif position == "left" then
                frame.centerLabel:SetHidden(true)
                frame.leftLabel:SetHidden(false)
                frame.rightLabel:SetHidden(true)
                frame.leftLabel:SetText(centerText or leftText or "")
            elseif position == "right" then
                frame.centerLabel:SetHidden(true)
                frame.leftLabel:SetHidden(true)
                frame.rightLabel:SetHidden(false)
                frame.rightLabel:SetText(centerText or rightText or "")
            else
                -- center
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

    local altExtra = 0
    if IsAltBarEnabled() then
        altExtra = GetAltBarGap() + GetAltBarRowHeight()
    end

    return {
        layout = layout,
        barHeight = barHeight,
        width = layoutWidth,
        height = layoutHeight + altExtra,
        bodyHeight = layoutHeight,
        altExtra = altExtra,
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
    -- A cor escolhida para o nick também é aplicada aos textos de Vida/Magicka/Vigor.
    local textColor = GetSettingValue("identityNameColor") or GetSettingValue("textColor") or DEFAULT_SETTINGS.textColor
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

    self:ApplyAltBarLayout(metrics)

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

    -- Com a barra alternativa ligada a montaria aparece nela (estilo LuiExtended),
    -- entao a barra nativa nao e mais anexada abaixo do Vigor.
    if IsModuleEnabled() and not IsAltBarEnabled() and GetSettingValue("attachMountStamina") ~= false then
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

    self:SetStockMountBarHidden(IsAltBarEnabled())
end

function ResourceBars:SetStockMountBarHidden(hidden)
    local mount = ZO_PlayerAttribute and ZO_PlayerAttribute:GetNamedChild("MountStamina")
    if not mount then
        return
    end

    if hidden then
        mount:SetHidden(true)
        mount:SetAlpha(0)
    else
        -- ao reexibir, deixa o proprio jogo decidir quando mostrar (so montado)
        mount:SetAlpha(1)
    end

    if not mount._abyssUIStockHooked then
        mount._abyssUIStockHooked = true
        ZO_PreHookHandler(mount, "OnShow", function()
            if IsAltBarEnabled() then
                mount:SetHidden(true)
                mount:SetAlpha(0)
                return true
            end
        end)
    end
end

function ResourceBars:ApplyAltBarLayout(metrics)
    local alt = self.alt
    if not alt then
        return
    end

    local enabled = IsAltBarEnabled()
    alt.backdrop:SetHidden(not enabled)
    alt.icon:SetHidden(not enabled)
    if not enabled then
        return
    end

    metrics = metrics or self.metrics or self:ComputeLayoutMetrics()
    local root = self:GetRoot()
    local height = GetAltBarHeight()
    local iconSize = GetAltBarIconSize()
    local rowHeight = GetAltBarRowHeight()
    local width = math.ceil(metrics.width * 2 / 3)
    local top = (metrics.bodyHeight or metrics.height) + GetAltBarGap() + ((rowHeight - height) / 2)

    alt.backdrop:ClearAnchors()
    alt.backdrop:SetDimensions(width, height)
    -- icone + barra ficam centralizados juntos (igual ao LuiExtended)
    alt.backdrop:SetAnchor(TOP, root, TOP, math.floor(iconSize / 2) + 1, top)

    alt.icon:ClearAnchors()
    alt.icon:SetDimensions(iconSize, iconSize)
    alt.icon:SetAnchor(RIGHT, alt.backdrop, LEFT, -2, 0)

    self:RefreshAltBar()
end

local function GetAltXPColors(isChampion)
    local xpColor = (ZO_XP_BAR_GRADIENT_COLORS and ZO_XP_BAR_GRADIENT_COLORS[2]) or ALT_FALLBACK_XP_COLOR
    if not isChampion then
        return xpColor, xpColor, ZO_GetKeyboardDungeonDifficultyIcon and ZO_GetKeyboardDungeonDifficultyIcon(DUNGEON_DIFFICULTY_NORMAL) or nil
    end

    local barColor, enlightenColor, icon = xpColor, xpColor, nil
    local ok, points = pcall(GetPlayerChampionPointsEarned)
    if ok and points and CHAMPION_DATA_MANAGER and GetChampionPointPoolForRank and ZO_CP_BAR_GRADIENT_COLORS then
        local rank = (points == 3600) and points or (points + 1)
        local attribute = GetChampionPointPoolForRank(rank)
        local colors = attribute and ZO_CP_BAR_GRADIENT_COLORS[attribute]
        if colors then
            barColor = colors[2] or barColor
            enlightenColor = colors[1] or enlightenColor
        end
        local disciplineData = attribute and CHAMPION_DATA_MANAGER:FindChampionDisciplineDataByType(attribute)
        icon = disciplineData and disciplineData:GetHUDIcon() or nil
    end
    return barColor, enlightenColor, icon
end

-- Prioridade igual ao LuiExtended: montaria enquanto montado; senao XP (CP se campeao).
function ResourceBars:RefreshAltBar()
    local alt = self.alt
    if not alt or not IsAltBarEnabled() then
        return
    end

    if IsMounted and IsMounted() then
        local current, maximum = GetUnitPower("player", COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA)
        current = tonumber(current) or 0
        maximum = tonumber(maximum) or 0
        local color = RESOURCE_DATA.stamina.endColor
        alt.mode = "mount"
        alt.current, alt.maximum = current, maximum
        alt.center:SetCenterColor(0.1 * color[1], 0.1 * color[2], 0.1 * color[3], 0.9)
        alt.bar:SetColor(color[1], color[2], color[3], 0.9)
        alt.icon:SetTexture(ALT_MOUNT_ICON)
        alt.enlightenment:SetHidden(true)
        alt.bar:SetMinMax(0, math.max(maximum, 1))
        alt.bar:SetValue(current)
        return
    end

    local isChampion = IsUnitChampion and IsUnitChampion("player")
    local barColor, enlightenColor, icon = GetAltXPColors(isChampion)
    local current, maximum

    if isChampion then
        local points = GetPlayerChampionPointsEarned() or 0
        current = GetPlayerChampionXP() or 0
        maximum = GetNumChampionXPInChampionPoint(points) or current
        local pool = GetEnlightenedPool and (4 * GetEnlightenedPool()) or 0
        alt.enlightened = math.min(pool + current, maximum)
        alt.enlightenment:SetColor(enlightenColor.r, enlightenColor.g, enlightenColor.b, 0.40)
        alt.enlightenment:SetMinMax(0, math.max(maximum, 1))
        alt.enlightenment:SetValue(alt.enlightened)
        alt.enlightenment:SetHidden(false)
        alt.center:SetCenterColor(0.1 * barColor.r, 0.1 * barColor.g, 0.1 * barColor.b, 0.9)
    else
        current = GetUnitXP("player") or 0
        maximum = GetUnitXPMax("player") or 0
        alt.enlightened = nil
        alt.enlightenment:SetHidden(true)
        alt.center:SetCenterColor(0, 0.1, 0.1, 0.9)
    end

    alt.mode = isChampion and "champion" or "experience"
    alt.current, alt.maximum = current, maximum
    alt.bar:SetColor(barColor.r, barColor.g, barColor.b, 0.9)
    alt.icon:SetTexture(icon or ALT_FALLBACK_XP_ICON)
    alt.bar:SetMinMax(0, math.max(maximum, 1))
    alt.bar:SetValue(current)
end

function ResourceBars:ShowAltBarTooltip(control)
    local alt = self.alt
    if not alt or not alt.mode then
        return
    end

    local current, maximum = alt.current or 0, alt.maximum or 0
    local percent = maximum > 0 and zo_floor(current / maximum * 100) or 100

    InitializeTooltip(InformationTooltip, control, BOTTOM, 0, -10)
    if alt.mode == "mount" then
        SetTooltipText(InformationTooltip, "Mount")
        InformationTooltip:AddLine(string.format("Stamina: %d / %d (%d%%)", current, maximum, percent))
    elseif alt.mode == "champion" then
        local points = GetPlayerChampionPointsEarned() or 0
        SetTooltipText(InformationTooltip, string.format("%s %d", GetString(SI_EXPERIENCE_CHAMPION_LABEL), points))
        InformationTooltip:AddLine(string.format("%s / %s (%d%%)", ZO_CommaDelimitNumber(current), ZO_CommaDelimitNumber(maximum), percent))
    else
        SetTooltipText(InformationTooltip, string.format("%s %d", GetString(SI_EXPERIENCE_LEVEL_LABEL), GetUnitLevel("player") or 0))
        InformationTooltip:AddLine(string.format("%s / %s (%d%%)", ZO_CommaDelimitNumber(current), ZO_CommaDelimitNumber(maximum), percent))
    end
end

function ResourceBars:ApplyLayout()
    local position = GetPosition()
    local scale = GetScale()
    local root = self:GetRoot()
    local mover = self:GetMover()

    self:ApplyLayoutGeometry()

    root:SetScale(scale)

    -- Registrado no Edit HUD: o jogo controla a posicao (nao sobrescrever ancoras).
    if NAGA_UI.MasterMover and NAGA_UI.MasterMover.RegisterAll then
        NAGA_UI.MasterMover:RegisterAll()
    end
    local editHudManaged = root.hudManaged == true and root.nagaNativeEditHUD == true
    if not editHudManaged then
        root:ClearAnchors()
        root:SetAnchor(CENTER, GuiRoot, CENTER, position.x, position.y)
    end

    local health = self.state and self.state.health
    if health then
        self:UpdateHealthShieldOverlay(health.current or 0, health.maximum or 0)
    end

    if self.identity then
        local metrics = self:ComputeLayoutMetrics()
        self.identity:SetDimensions(metrics.width or DEFAULT_ROW_WIDTH, 26)
        self:UpdateIdentityDisplay()
    end

    mover:SetScale(scale)
    mover:ClearAnchors()
    mover:SetAnchor(CENTER, GuiRoot, CENTER, position.x, position.y)
    mover:SetHidden(editHudManaged or not IsModuleUnlocked())
    self:ApplyMountStaminaAnchor()
end

function ResourceBars:SetStockPlayerBarsHidden(hidden)
    -- Esconde as barras padrão do jogo (Vida / Magicka / Vigor) quando o HUD 2 está ativo.
    local names = { "Health", "Magicka", "Stamina" }
    local parent = ZO_PlayerAttribute
    if not parent then
        return
    end

    for _, name in ipairs(names) do
        local bar = parent:GetNamedChild(name)
        if bar then
            local shouldHide = hidden
            if name == "Health" and not hidden then
                -- ao reexibir, respeita hardcore hide health se existir
                shouldHide = ShouldHideHealthResourceBar()
            end
            bar:SetHidden(shouldHide == true)
            if shouldHide then
                bar:SetAlpha(0)
            else
                bar:SetAlpha(1)
            end

            -- Impede o jogo de reaparecer a barra enquanto o HUD 2 estiver ligado
            if not bar._abyssUIStockHooked then
                bar._abyssUIStockHooked = true
                local barRef = bar
                local barName = name
                ZO_PreHookHandler(barRef, "OnShow", function()
                    if IsModuleEnabled() then
                        barRef:SetHidden(true)
                        barRef:SetAlpha(0)
                        return true
                    end
                end)
            end
        end
    end

    -- Também tenta esconder controles globais conhecidos (PC)
    for _, globalName in ipairs({
        "ZO_PlayerAttributeHealth",
        "ZO_PlayerAttributeMagicka",
        "ZO_PlayerAttributeStamina",
    }) do
        local ctrl = _G[globalName]
        if ctrl and ctrl.SetHidden then
            if hidden then
                ctrl:SetHidden(true)
                if ctrl.SetAlpha then ctrl:SetAlpha(0) end
            end
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
        if self.identity then
            self.identity:SetHidden(true)
        end
        self:SetStockPlayerBarsHidden(false)
        return
    end

    if self.settingsPreviewActive then
        root:SetHidden(false)
        if self.identity then
            self.identity:SetHidden(false)
            self:UpdateIdentityDisplay()
        end
        return
    end

    if not IsHudSceneShowing() then
        root:SetHidden(true)
        if self.identity then
            self.identity:SetHidden(true)
        end
        return
    end

    -- Sempre visível com o módulo ligado (não some quando as barras estão cheias).
    root:SetHidden(false)
    if self.identity then
        self.identity:SetHidden(false)
        self:UpdateIdentityDisplay()
    end
    -- Mantém barras padrão do jogo desligadas enquanto o HUD 2 estiver ativo
    self:SetStockPlayerBarsHidden(true)
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
        self:UpdateIdentityDisplay()
        self:SetStockPlayerBarsHidden(IsModuleEnabled())
        self:RefreshAltBar()
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Level", EVENT_LEVEL_UPDATE, function()
        self:UpdateIdentityDisplay()
        self:RefreshAltBar()
    end)

    -- Barra alternativa (XP / montaria)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_AltMounted", EVENT_MOUNTED_STATE_CHANGED, function()
        self:RefreshAltBar()
        self:SetStockMountBarHidden(IsAltBarEnabled())
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_AltMountPower", EVENT_POWER_UPDATE, function()
        if IsMounted and IsMounted() then
            self:RefreshAltBar()
        end
    end)
    EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE .. "_AltMountPower", EVENT_POWER_UPDATE, REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA, REGISTER_FILTER_UNIT_TAG, "player")
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_AltExperience", EVENT_EXPERIENCE_UPDATE, function(_, unitTag)
        if unitTag == "player" then
            self:RefreshAltBar()
        end
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_AltChampionGained", EVENT_CHAMPION_POINT_GAINED, function()
        self:RefreshAltBar()
    end)
    EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE .. "_Level", EVENT_LEVEL_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Champion", EVENT_CHAMPION_POINT_UPDATE, function()
        self:UpdateIdentityDisplay()
        self:RefreshAltBar()
    end)
    EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE .. "_Champion", EVENT_CHAMPION_POINT_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
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
    return NAGA_UI.Settings and NAGA_UI.Settings:IsDebugModeEnabled()
end

local function RegisterDebugCommands()
    for command, handler in pairs(DEBUG_COMMANDS) do
        SLASH_COMMANDS[command] = IsDebugModeEnabled() and handler or nil
    end
end

function ResourceBars:RefreshDebugCommands()
    RegisterDebugCommands()
end

NAGA_UI.OnAddonLoaded(function()
    ResourceBars:RefreshSettings()
    RegisterDebugCommands()
    zo_callLater(function() ResourceBars:RefreshSettings() end, 1000)
end)
