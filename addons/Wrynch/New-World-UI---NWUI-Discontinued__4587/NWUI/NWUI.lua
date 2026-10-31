local ADDON_NAME = "NWUI"
local PLAYER_UNIT_TAG = "player"

NWUI = NWUI or {}
local addon = NWUI

addon.name = ADDON_NAME
addon.initialized = false

local ASSET_PATH = "NWUI/assets/"
local TEXTURES =
{
    slotFrame = ASSET_PATH .. "slot_frame.dds",
    slotFrameEmpty = ASSET_PATH .. "slot_frame_empty.dds",
    keybindBox = ASSET_PATH .. "keybind_box.dds",
    barBg = ASSET_PATH .. "bar_bg.dds",
    healthOverlay = ASSET_PATH .. "health_bar_overlay.dds",
    resourceOverlay = ASSET_PATH .. "resource_bar_overlay.dds",
    levelBadgeRegular = ASSET_PATH .. "level_badge_regular.dds",
    levelBadgeChampion = ASSET_PATH .. "level_badge_champion.dds",
    weaponDualWield = ASSET_PATH .. "weapon_dual_wield.dds",
    weaponSword = ASSET_PATH .. "weapon_sword.dds",
    weaponTwoHanded = ASSET_PATH .. "weapon_two_handed.dds",
    weaponBow = ASSET_PATH .. "weapon_bow.dds",
    weaponStaff = ASSET_PATH .. "weapon_staff.dds",
    weaponShield = ASSET_PATH .. "weapon_shield.dds",
    ultimateFrame = ASSET_PATH .. "ultimate_frame.dds",
    ultimateShimmer = ASSET_PATH .. "ultimate_shimmer.dds",
}

local MAGICKA_BAR_COLOR = { 0.14, 0.48, 0.56, 0.54 }
local STAMINA_BAR_COLOR = { 0.70, 0.52, 0.17, 0.54 }
local HEALTH_FULL_COLOR = { 0.78, 0.76, 0.68, 0.62 }
local HEALTH_DAMAGED_COLOR = { 0.58, 0.05, 0.035, 0.68 }
local POWER_LOSS_COLOR = { 0.92, 0.90, 0.82, 0.58 }
local DAMAGE_SHIELD_COLOR = { 0.42, 0.62, 0.84, 0.72 }
local DAMAGE_SHIELD_TEXT_COLOR = { 0.72, 0.84, 0.96, 1 }

local RESOURCE_BARS =
{
    {
        key = "magicka",
        powerType = COMBAT_MECHANIC_FLAGS_MAGICKA,
        label = "MP",
        color = MAGICKA_BAR_COLOR,
    },
    {
        key = "stamina",
        powerType = COMBAT_MECHANIC_FLAGS_STAMINA,
        label = "ST",
        color = STAMINA_BAR_COLOR,
    },
    {
        key = "health",
        powerType = COMBAT_MECHANIC_FLAGS_HEALTH,
        label = "HP",
        color = HEALTH_FULL_COLOR,
    },
}

local SKILL_SLOT_INDEXES =
{
    ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 1,
    ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 2,
    ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 3,
    ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 4,
    ACTION_BAR_FIRST_NORMAL_SLOT_INDEX + 5,
    ACTION_BAR_ULTIMATE_SLOT_INDEX + 1,
}

local ULTIMATE_SLOT_INDEX = ACTION_BAR_ULTIMATE_SLOT_INDEX + 1
local QUICK_SLOT_COUNT = 4
local SLOT_SIZE = 40
local SLOT_GAP = 5
local ACTIVE_ULTIMATE_SLOT_SIZE = 58
local BACKBAR_SLOT_SIZE = 28
local BACKBAR_SLOT_GAP = 4
local WEAPON_SLOT_SIZE = 28
local ACTIVE_WEAPON_SLOT_SIZE = SLOT_SIZE
local KEYBIND_LABEL_HEIGHT = 14
local KEYBIND_LABEL_GAP = 2
local SLOT_CONTROL_HEIGHT = SLOT_SIZE + KEYBIND_LABEL_GAP + KEYBIND_LABEL_HEIGHT
local ACTIVE_ULTIMATE_SLOT_CONTROL_HEIGHT = ACTIVE_ULTIMATE_SLOT_SIZE + KEYBIND_LABEL_GAP + KEYBIND_LABEL_HEIGHT
local BACKBAR_TO_ACTIVE_GAP = 5
local QUICK_SLOT_PANEL_WIDTH = (SLOT_SIZE * QUICK_SLOT_COUNT) + (SLOT_GAP * (QUICK_SLOT_COUNT - 1))
local SKILL_ROW_OFFSET_X = ACTIVE_WEAPON_SLOT_SIZE + SLOT_GAP
local SKILL_ROW_WIDTH = (SLOT_SIZE * (#SKILL_SLOT_INDEXES - 1)) + ACTIVE_ULTIMATE_SLOT_SIZE + (SLOT_GAP * (#SKILL_SLOT_INDEXES - 1))
local SKILL_PANEL_WIDTH = SKILL_ROW_OFFSET_X + SKILL_ROW_WIDTH
local BACKBAR_ROW_WIDTH = (BACKBAR_SLOT_SIZE * #SKILL_SLOT_INDEXES) + (BACKBAR_SLOT_GAP * (#SKILL_SLOT_INDEXES - 1))
local BACKBAR_ROW_OFFSET_X = SKILL_ROW_OFFSET_X + math.floor((SKILL_ROW_WIDTH - BACKBAR_ROW_WIDTH) / 2)
local BACKBAR_WEAPON_OFFSET_X = BACKBAR_ROW_OFFSET_X - BACKBAR_SLOT_GAP - WEAPON_SLOT_SIZE
local ACTIVE_ROW_OFFSET_Y = BACKBAR_SLOT_SIZE + BACKBAR_TO_ACTIVE_GAP
local SKILL_PANEL_HEIGHT = ACTIVE_ROW_OFFSET_Y + math.max(SLOT_CONTROL_HEIGHT, ACTIVE_ULTIMATE_SLOT_CONTROL_HEIGHT)
local POWER_BAR_WIDTH = 320
local HALF_POWER_BAR_WIDTH = math.floor(POWER_BAR_WIDTH / 2)
local THIN_POWER_BAR_HEIGHT = 14
local HEALTH_BAR_HEIGHT = 24
local EXPERIENCE_BAR_HEIGHT = 5
local RESOURCE_BAR_GAP = 2
local HEALTH_BAR_TOP_GAP = 4
local EXPERIENCE_BAR_TOP_GAP = 4
local EXPERIENCE_BAR_OFFSET_Y = 62
local LEVEL_BADGE_REGULAR_WIDTH = 46
local LEVEL_BADGE_REGULAR_HEIGHT = 24
local LEVEL_BADGE_CHAMPION_WIDTH = 70
local LEVEL_BADGE_CHAMPION_HEIGHT = 30
local LEVEL_BADGE_OFFSET_Y = EXPERIENCE_BAR_OFFSET_Y + EXPERIENCE_BAR_HEIGHT - 1
local LEVEL_BADGE_MAX_HEIGHT = LEVEL_BADGE_CHAMPION_HEIGHT
local LEVEL_BADGE_TEXT_OFFSET_Y = -1
local BARS_PANEL_HEIGHT = LEVEL_BADGE_OFFSET_Y + LEVEL_BADGE_MAX_HEIGHT
local SIDE_PANEL_GAP = 36
local BARS_TOP_OFFSET = ACTIVE_ROW_OFFSET_Y
local ROOT_SIDE_WIDTH = math.max(HALF_POWER_BAR_WIDTH + SIDE_PANEL_GAP + QUICK_SLOT_PANEL_WIDTH, HALF_POWER_BAR_WIDTH + SIDE_PANEL_GAP + SKILL_PANEL_WIDTH)
local ROOT_WIDTH = ROOT_SIDE_WIDTH * 2
local ROOT_HEIGHT = BARS_TOP_OFFSET + BARS_PANEL_HEIGHT + 2
local SAVED_VARIABLES_NAME = "NWUI_SavedVariables"
local SAVED_VARIABLES_VERSION = 1
local SAVED_VARIABLES_NAMESPACE = "Settings"
local SETTINGS_PANEL_ID = ADDON_NAME .. "Settings"
local DEFAULT_ROOT_POINT = BOTTOM
local DEFAULT_ROOT_RELATIVE_POINT = BOTTOM
local DEFAULT_ROOT_OFFSET_X = 0
local DEFAULT_ROOT_OFFSET_Y = -52
local SCALE_MIN = 0.50
local SCALE_MAX = 1.80
local BAR_WIDTH_MIN = 260
local BAR_WIDTH_MAX = 520
local THIN_BAR_HEIGHT_MIN = 8
local THIN_BAR_HEIGHT_MAX = 24
local HEALTH_BAR_HEIGHT_MIN = 16
local HEALTH_BAR_HEIGHT_MAX = 40
local EXPERIENCE_BAR_HEIGHT_MIN = 2
local EXPERIENCE_BAR_HEIGHT_MAX = 10
local DEFAULT_SETTINGS =
{
    unlockUI = false,
    moveComponentsIndividually = false,
    uiScale = 1,
    consumablesScale = 1,
    resourceScale = 1,
    skillsScale = 1,
    magickaScale = 1,
    staminaScale = 1,
    healthScale = 1,
    experienceScale = 1,
    levelBadgeScale = 1,
    consumablesOffsetX = 0,
    consumablesOffsetY = 0,
    magickaOffsetX = 0,
    magickaOffsetY = 0,
    staminaOffsetX = 0,
    staminaOffsetY = 0,
    healthOffsetX = 0,
    healthOffsetY = 0,
    experienceOffsetX = 0,
    experienceOffsetY = 0,
    levelBadgeOffsetX = 0,
    levelBadgeOffsetY = 0,
    skillsOffsetX = 0,
    skillsOffsetY = 0,
    barWidth = POWER_BAR_WIDTH,
    thinBarHeight = THIN_POWER_BAR_HEIGHT,
    healthBarHeight = HEALTH_BAR_HEIGHT,
    experienceBarHeight = EXPERIENCE_BAR_HEIGHT,
    showSecondaryResourceNumbers = false,
    showUltimateShimmer = true,
    skillEffectFrontNumberScale = 1,
    skillEffectBackNumberScale = 1,
    skillEffectTimeFormat = "float",
    showSkillEffectBorderAnimation = true,
    uiPoint = DEFAULT_ROOT_POINT,
    uiRelativePoint = DEFAULT_ROOT_RELATIVE_POINT,
    uiOffsetX = DEFAULT_ROOT_OFFSET_X,
    uiOffsetY = DEFAULT_ROOT_OFFSET_Y,
}
local HIDE_UNBOUND = false
local NO_LEADING_EDGE = false
local SLOT_BORDER_COLOR = { 0.44, 0.39, 0.30, 0.58 }
local DEFAULT_SLOT_ICON_INSET = 2
local ULTIMATE_SLOT_ICON_INSET_RATIO = 0.10
local INACTIVE_QUICKSLOT_ALPHA = 0.68
local INACTIVE_QUICKSLOT_DESATURATION = 0.55
local BAR_BACKGROUND_TEXTURE_ALPHA = 0.62
local BAR_OVERLAY_ALPHA = 0.42
local DAMAGE_SHIELD_READOUT_GAP = 5
local DAMAGE_SHIELD_ICON_MAX_SIZE = 18
local POWER_BAR_ANIMATION_MS = 180
local POWER_LOSS_HOLD_MS = 160
local POWER_LOSS_ANIMATION_MS = 620
local ULTIMATE_READY_PULSE_SPEED = 0.007
local ULTIMATE_READY_MIN_ALPHA = 0.62
local ULTIMATE_READY_ALPHA_RANGE = 0.38
local ULTIMATE_READY_GLOW_MIN_ALPHA = 0.18
local ULTIMATE_READY_GLOW_ALPHA_RANGE = 0.34
local ULTIMATE_READY_SHIMMER_CYCLE_MS = 1150
local ULTIMATE_READY_SHIMMER_U_WIDTH = 0.25
local ULTIMATE_READY_SHIMMER_U_TRAVEL = 1 - ULTIMATE_READY_SHIMMER_U_WIDTH
local SKILL_EFFECT_TIMER_UPDATE_INTERVAL_MS = 100
local SKILL_EFFECT_TIMER_DECIMAL_THRESHOLD_S = 10
local SKILL_EFFECT_BORDER_COLOR = { 0.94, 0.72, 0.20, 1 }
local SKILL_EFFECT_BORDER_THICKNESS = 2
local SKILL_EFFECT_ICON_OVERLAY_ALPHA = 0.28
local SKILL_EFFECT_STACK_BACKGROUND_ALPHA = 0.60
local SKILL_EFFECT_NUMBER_SCALE_MIN = 0.50
local SKILL_EFFECT_NUMBER_SCALE_MAX = 1.80

local RESOURCE_BAR_LAYOUTS =
{
    [COMBAT_MECHANIC_FLAGS_MAGICKA] =
    {
        y = 0,
        height = THIN_POWER_BAR_HEIGHT,
        showValue = false,
    },
    [COMBAT_MECHANIC_FLAGS_HEALTH] =
    {
        y = 34,
        height = HEALTH_BAR_HEIGHT,
        showValue = true,
    },
    [COMBAT_MECHANIC_FLAGS_STAMINA] =
    {
        y = 16,
        height = THIN_POWER_BAR_HEIGHT,
        showValue = false,
    },
}

local LAYOUT_COMPONENT_ORDER =
{
    "consumables",
    "magicka",
    "stamina",
    "health",
    "experience",
    "levelBadge",
    "skills",
}

local LAYOUT_COMPONENTS =
{
    consumables =
    {
        label = "Consumables",
        controlField = "quickSlotContainer",
        point = TOPRIGHT,
        relativeControlField = "bars",
        relativePoint = TOPLEFT,
        baseOffsetX = -SIDE_PANEL_GAP,
        baseOffsetY = -3,
        offsetXSetting = "consumablesOffsetX",
        offsetYSetting = "consumablesOffsetY",
    },
    magicka =
    {
        label = "Magicka",
        powerType = COMBAT_MECHANIC_FLAGS_MAGICKA,
        point = TOP,
        relativeControlField = "bars",
        relativePoint = TOP,
        barLayoutPowerType = COMBAT_MECHANIC_FLAGS_MAGICKA,
        offsetXSetting = "magickaOffsetX",
        offsetYSetting = "magickaOffsetY",
        scaleSetting = "magickaScale",
    },
    stamina =
    {
        label = "Stamina",
        powerType = COMBAT_MECHANIC_FLAGS_STAMINA,
        point = TOP,
        relativeControlField = "bars",
        relativePoint = TOP,
        barLayoutPowerType = COMBAT_MECHANIC_FLAGS_STAMINA,
        offsetXSetting = "staminaOffsetX",
        offsetYSetting = "staminaOffsetY",
        scaleSetting = "staminaScale",
    },
    health =
    {
        label = "Health",
        powerType = COMBAT_MECHANIC_FLAGS_HEALTH,
        point = TOP,
        relativeControlField = "bars",
        relativePoint = TOP,
        barLayoutPowerType = COMBAT_MECHANIC_FLAGS_HEALTH,
        offsetXSetting = "healthOffsetX",
        offsetYSetting = "healthOffsetY",
        scaleSetting = "healthScale",
    },
    experience =
    {
        label = "Experience",
        controlField = "experienceBar",
        point = TOP,
        relativeControlField = "bars",
        relativePoint = TOP,
        barLayoutOffsetY = "experienceY",
        offsetXSetting = "experienceOffsetX",
        offsetYSetting = "experienceOffsetY",
        scaleSetting = "experienceScale",
    },
    levelBadge =
    {
        label = "Level Badge",
        controlField = "levelBadge",
        point = TOP,
        relativeControlField = "bars",
        relativePoint = TOP,
        barLayoutOffsetY = "levelBadgeY",
        offsetXSetting = "levelBadgeOffsetX",
        offsetYSetting = "levelBadgeOffsetY",
        scaleSetting = "levelBadgeScale",
    },
    skills =
    {
        label = "Skills",
        controlField = "skillSlotContainer",
        point = TOPLEFT,
        relativeControlField = "bars",
        relativePoint = TOPRIGHT,
        baseOffsetX = SIDE_PANEL_GAP,
        baseOffsetY = -BARS_TOP_OFFSET,
        offsetXSetting = "skillsOffsetX",
        offsetYSetting = "skillsOffsetY",
    },
}

local ONE_HANDED_WEAPON_TYPES =
{
    [WEAPONTYPE_AXE] = true,
    [WEAPONTYPE_HAMMER] = true,
    [WEAPONTYPE_SWORD] = true,
    [WEAPONTYPE_DAGGER] = true,
}

local TWO_HANDED_WEAPON_TYPES =
{
    [WEAPONTYPE_TWO_HANDED_AXE] = true,
    [WEAPONTYPE_TWO_HANDED_HAMMER] = true,
    [WEAPONTYPE_TWO_HANDED_SWORD] = true,
}

local STAFF_WEAPON_TYPES =
{
    [WEAPONTYPE_FIRE_STAFF] = true,
    [WEAPONTYPE_FROST_STAFF] = true,
    [WEAPONTYPE_LIGHTNING_STAFF] = true,
    [WEAPONTYPE_HEALING_STAFF] = true,
}

local function FormatNumber(value)
    value = tonumber(value) or 0
    local text = tostring(math.floor(value))
    local formatted = text
    local replacements

    while true do
        formatted, replacements = formatted:gsub("^(-?%d+)(%d%d%d)", "%1 %2")
        if replacements == 0 then
            break
        end
    end

    return formatted
end

local function SetBackdropColor(control, r, g, b, a)
    control:SetCenterColor(r, g, b, a)
    control:SetEdgeColor(r, g, b, a)
end

local function CreateInsetBackdrop(name, parent, inset, centerColor, borderColor)
    local border = CreateControl(name .. "Border", parent, CT_BACKDROP)
    border:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, 0)
    border:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, 0, 0)
    SetBackdropColor(border, borderColor[1], borderColor[2], borderColor[3], borderColor[4])

    local center = CreateControl(name .. "Center", parent, CT_BACKDROP)
    center:SetAnchor(TOPLEFT, parent, TOPLEFT, inset, inset)
    center:SetAnchor(BOTTOMRIGHT, parent, BOTTOMRIGHT, -inset, -inset)
    SetBackdropColor(center, centerColor[1], centerColor[2], centerColor[3], centerColor[4])

    return border, center
end

local function CreateLabel(name, parent, font, color)
    local label = CreateControl(name, parent, CT_LABEL)
    label:SetFont(font)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    if color then
        label:SetColor(color[1], color[2], color[3], color[4])
    else
        label:SetColor(0.92, 0.90, 0.84, 1)
    end

    return label
end

local function ClampNumber(value, minimumValue, maximumValue, defaultValue)
    value = tonumber(value)
    if value == nil then
        value = defaultValue
    end

    if value < minimumValue then
        return minimumValue
    elseif value > maximumValue then
        return maximumValue
    end

    return value
end

local function ClampInteger(value, minimumValue, maximumValue, defaultValue)
    return math.floor(ClampNumber(value, minimumValue, maximumValue, defaultValue) + 0.5)
end

function addon:GetSettingValue(key)
    local settings = self.savedVars
    if settings and settings[key] ~= nil then
        return settings[key]
    end

    return DEFAULT_SETTINGS[key]
end

function addon:SetSettingValue(key, value)
    if self.savedVars then
        self.savedVars[key] = value
    end

    self:ApplySettings()
end

function addon:GetCurrentBarLayout()
    local width = ClampInteger(self:GetSettingValue("barWidth"), BAR_WIDTH_MIN, BAR_WIDTH_MAX, POWER_BAR_WIDTH)
    local thinHeight = ClampInteger(self:GetSettingValue("thinBarHeight"), THIN_BAR_HEIGHT_MIN, THIN_BAR_HEIGHT_MAX, THIN_POWER_BAR_HEIGHT)
    local healthHeight = ClampInteger(self:GetSettingValue("healthBarHeight"), HEALTH_BAR_HEIGHT_MIN, HEALTH_BAR_HEIGHT_MAX, HEALTH_BAR_HEIGHT)
    local experienceHeight = ClampInteger(self:GetSettingValue("experienceBarHeight"), EXPERIENCE_BAR_HEIGHT_MIN, EXPERIENCE_BAR_HEIGHT_MAX, EXPERIENCE_BAR_HEIGHT)
    local staminaY = thinHeight + RESOURCE_BAR_GAP
    local healthY = staminaY + thinHeight + HEALTH_BAR_TOP_GAP
    local experienceY = healthY + healthHeight + EXPERIENCE_BAR_TOP_GAP
    local levelBadgeY = experienceY + experienceHeight - 1

    return {
        width = width,
        height = levelBadgeY + LEVEL_BADGE_MAX_HEIGHT,
        experienceY = experienceY,
        experienceHeight = experienceHeight,
        levelBadgeY = levelBadgeY,
        bars = {
            [COMBAT_MECHANIC_FLAGS_MAGICKA] = {
                y = 0,
                height = thinHeight,
            },
            [COMBAT_MECHANIC_FLAGS_STAMINA] = {
                y = staminaY,
                height = thinHeight,
            },
            [COMBAT_MECHANIC_FLAGS_HEALTH] = {
                y = healthY,
                height = healthHeight,
            },
        },
    }
end

local function CreateBar(name, parent, width, height, color, overlayTexture, lossColor)
    local container = CreateControl(name, parent, CT_CONTROL)
    container:SetDimensions(width, height)

    local border, background = CreateInsetBackdrop(name .. "Background", container, 1, { 0, 0, 0, 0.48 }, { 0.42, 0.38, 0.30, 0.46 })

    local backgroundTexture = CreateControl(name .. "BackgroundTexture", container, CT_TEXTURE)
    backgroundTexture:SetAnchor(TOPLEFT, container, TOPLEFT, 0, 0)
    backgroundTexture:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, 0, 0)
    backgroundTexture:SetTexture(TEXTURES.barBg)
    backgroundTexture:SetDrawLevel(0)
    backgroundTexture:SetAlpha(BAR_BACKGROUND_TEXTURE_ALPHA)

    local lossBar
    if lossColor then
        lossBar = CreateControl(name .. "LossFill", container, CT_STATUSBAR)
        lossBar:SetAnchor(TOPLEFT, container, TOPLEFT, 1, 1)
        lossBar:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, -1, -1)
        lossBar:SetDrawLevel(1)
        lossBar:SetMinMax(0, 1)
        lossBar:SetValue(0)
        lossBar:SetColor(lossColor[1], lossColor[2], lossColor[3], lossColor[4])
        lossBar:SetHidden(true)
    end

    local bar = CreateControl(name .. "Fill", container, CT_STATUSBAR)
    bar:SetAnchor(TOPLEFT, container, TOPLEFT, 1, 1)
    bar:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, -1, -1)
    bar:SetDrawLevel(lossBar and 2 or 1)
    bar:SetMinMax(0, 1)
    bar:SetValue(0)
    bar:SetColor(color[1], color[2], color[3], color[4])

    local overlay = CreateControl(name .. "Overlay", container, CT_TEXTURE)
    overlay:SetAnchor(TOPLEFT, container, TOPLEFT, 1, 1)
    overlay:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, -1, -1)
    overlay:SetDrawLevel(lossBar and 3 or 2)
    overlay:SetAlpha(BAR_OVERLAY_ALPHA)
    overlay:SetHidden(overlayTexture == nil)
    if overlayTexture then
        overlay:SetTexture(overlayTexture)
    end

    container.border = border
    container.background = background
    container.backgroundTexture = backgroundTexture
    container.lossBar = lossBar
    container.bar = bar
    container.overlay = overlay

    return container
end

local function SetBarValue(barControl, current, maxValue)
    current = tonumber(current) or 0
    maxValue = tonumber(maxValue) or 0

    if maxValue <= 0 then
        barControl:SetMinMax(0, 1)
        barControl:SetValue(0)
        return
    end

    if current < 0 then
        current = 0
    elseif current > maxValue then
        current = maxValue
    end

    barControl:SetMinMax(0, maxValue)
    barControl:SetValue(current)
end

local function ApplyDamageShieldControlLayout(healthBar, height)
    if not healthBar or not healthBar.shieldInfo then
        return
    end

    local iconSize = math.min(DAMAGE_SHIELD_ICON_MAX_SIZE, math.max(12, height - 4))
    healthBar.shieldInfo:SetHeight(height)
    healthBar.shieldIcon:SetDimensions(iconSize, iconSize)
    healthBar.shieldText:SetHeight(height)
    healthBar.shieldBar:SetHeight(math.max(1, height - 2))
end

local function UpdateDamageShieldVisuals(healthBar, maxHealth, shieldValue)
    if not healthBar or not healthBar.shieldBar or not healthBar.shieldInfo then
        return
    end

    maxHealth = math.max(0, tonumber(maxHealth) or 0)
    shieldValue = math.max(0, tonumber(shieldValue) or 0)

    local showShield = shieldValue > 0 and maxHealth > 0
    healthBar.shieldBar:SetHidden(not showShield)
    healthBar.shieldInfo:SetHidden(not showShield)

    if not showShield then
        healthBar.valueText:ClearAnchors()
        healthBar.valueText:SetAnchor(CENTER, healthBar, CENTER, 0, 0)
        healthBar.valueText:SetDimensions(math.max(1, healthBar:GetWidth() - 8), healthBar:GetHeight())
        return
    end

    healthBar.shieldText:SetText("+" .. FormatNumber(shieldValue))

    local healthTextWidth = math.max(1, math.ceil(healthBar.valueText:GetTextWidth()))
    local shieldTextWidth = math.max(1, math.ceil(healthBar.shieldText:GetTextWidth()))
    local iconWidth = math.max(1, healthBar.shieldIcon:GetWidth())
    local readoutWidth = healthTextWidth + iconWidth + shieldTextWidth + (DAMAGE_SHIELD_READOUT_GAP * 2)
    local readoutHeight = healthBar:GetHeight()

    healthBar.shieldInfo:ClearAnchors()
    healthBar.shieldInfo:SetAnchor(CENTER, healthBar, CENTER, 0, 0)
    healthBar.shieldInfo:SetDimensions(readoutWidth, readoutHeight)

    healthBar.valueText:ClearAnchors()
    healthBar.valueText:SetAnchor(LEFT, healthBar.shieldInfo, LEFT, 0, 0)
    healthBar.valueText:SetDimensions(healthTextWidth, readoutHeight)

    healthBar.shieldIcon:ClearAnchors()
    healthBar.shieldIcon:SetAnchor(LEFT, healthBar.shieldInfo, LEFT, healthTextWidth + DAMAGE_SHIELD_READOUT_GAP, 0)

    healthBar.shieldText:ClearAnchors()
    healthBar.shieldText:SetAnchor(LEFT, healthBar.shieldIcon, RIGHT, DAMAGE_SHIELD_READOUT_GAP, 0)
    healthBar.shieldText:SetDimensions(shieldTextWidth, readoutHeight)

    local innerWidth = math.max(1, (tonumber(healthBar:GetWidth()) or 0) - 2)
    local visibleShield = math.min(shieldValue, maxHealth)
    local segmentWidth = math.max(1, math.floor(((visibleShield / maxHealth) * innerWidth) + 0.5))

    healthBar.shieldBar:ClearAnchors()
    -- A center anchor makes width changes expand equally to the left and right.
    healthBar.shieldBar:SetAnchor(CENTER, healthBar, CENTER, 0, 0)
    healthBar.shieldBar:SetWidth(segmentWidth)
end

local function SetStatusBarColor(barControl, color)
    barControl:SetColor(color[1], color[2], color[3], color[4])
end

local function StopPowerValueAnimation(barControl)
    if barControl.powerValueAnimating then
        barControl.powerValueAnimating = false
        barControl:SetHandler("OnUpdate", nil, "PowerValueAnimation")
    end
end

local function UpdatePowerValueFrame(barControl)
    local maxValue = barControl.powerValueMaxValue or 0
    local targetValue = barControl.powerValueTargetValue or 0

    if maxValue <= 0 then
        barControl.powerValueDisplayValue = nil
        SetBarValue(barControl.bar, 0, 1)
        StopPowerValueAnimation(barControl)
        return
    end

    local progress = (GetFrameTimeMilliseconds() - (barControl.powerValueStartTime or 0)) / POWER_BAR_ANIMATION_MS
    if progress < 0 then
        progress = 0
    elseif progress > 1 then
        progress = 1
    end

    local startValue = barControl.powerValueStartValue or targetValue
    local value = startValue + ((targetValue - startValue) * progress)
    barControl.powerValueDisplayValue = value
    SetBarValue(barControl.bar, value, maxValue)
    if progress >= 1 then
        barControl.powerValueDisplayValue = targetValue
        SetBarValue(barControl.bar, targetValue, maxValue)
        StopPowerValueAnimation(barControl)
    end
end

local function SetAnimatedBarValue(barControl, current, maxValue)
    local currentValue = tonumber(current) or 0
    local maximumValue = tonumber(maxValue) or 0

    if maximumValue <= 0 then
        barControl.powerValueDisplayValue = nil
        barControl.powerValueMaxValue = nil
        SetBarValue(barControl.bar, 0, 1)
        StopPowerValueAnimation(barControl)
        return
    end

    if currentValue < 0 then
        currentValue = 0
    elseif currentValue > maximumValue then
        currentValue = maximumValue
    end

    local displayValue = barControl.powerValueDisplayValue
    local maxChanged = barControl.powerValueMaxValue ~= nil and barControl.powerValueMaxValue ~= maximumValue
    if displayValue == nil or maxChanged then
        barControl.powerValueDisplayValue = currentValue
        barControl.powerValueMaxValue = maximumValue
        SetBarValue(barControl.bar, currentValue, maximumValue)
        StopPowerValueAnimation(barControl)
        return
    end

    if displayValue == currentValue then
        barControl.powerValueMaxValue = maximumValue
        SetBarValue(barControl.bar, currentValue, maximumValue)
        StopPowerValueAnimation(barControl)
        return
    end

    barControl.powerValueStartValue = displayValue
    barControl.powerValueTargetValue = currentValue
    barControl.powerValueMaxValue = maximumValue
    barControl.powerValueStartTime = GetFrameTimeMilliseconds()

    if not barControl.powerValueAnimating then
        barControl.powerValueAnimating = true
        barControl:SetHandler("OnUpdate", UpdatePowerValueFrame, "PowerValueAnimation")
    end
end

local function StopPowerLossAnimation(barControl)
    if barControl.powerLossAnimating then
        barControl.powerLossAnimating = false
        barControl:SetHandler("OnUpdate", nil, "PowerLossAnimation")
    end
end

local function UpdatePowerLossFrame(barControl)
    local lossBar = barControl.lossBar
    local maxValue = barControl.powerLossMaxValue or 0
    local targetValue = barControl.powerLossTargetValue or 0

    if not lossBar or maxValue <= 0 then
        StopPowerLossAnimation(barControl)
        if lossBar then
            lossBar:SetHidden(true)
        end
        return
    end

    local now = GetFrameTimeMilliseconds()
    local startTime = barControl.powerLossStartTime or now
    if now < startTime then
        return
    end

    local progress = (now - startTime) / POWER_LOSS_ANIMATION_MS
    if progress < 0 then
        progress = 0
    elseif progress > 1 then
        progress = 1
    end

    local startValue = barControl.powerLossStartValue or targetValue
    local value = startValue + ((targetValue - startValue) * progress)
    if value < targetValue then
        value = targetValue
    end

    barControl.powerLossDisplayValue = value
    SetBarValue(lossBar, value, maxValue)

    if progress >= 1 then
        barControl.powerLossDisplayValue = targetValue
        SetBarValue(lossBar, targetValue, maxValue)
        lossBar:SetHidden(true)
        StopPowerLossAnimation(barControl)
    end
end

local function StartPowerLossAnimation(barControl)
    if barControl.powerLossAnimating then
        return
    end

    barControl.powerLossAnimating = true
    barControl:SetHandler("OnUpdate", UpdatePowerLossFrame, "PowerLossAnimation")
end

local function UpdatePowerBarVisuals(barControl, current, maxValue)
    local currentValue = tonumber(current) or 0
    local maximumValue = tonumber(maxValue) or 0

    if currentValue < 0 then
        currentValue = 0
    elseif maximumValue > 0 and currentValue > maximumValue then
        currentValue = maximumValue
    end

    if barControl.damagedColor then
        local fillColor = maximumValue > 0 and currentValue < maximumValue and barControl.damagedColor or barControl.defaultColor
        SetStatusBarColor(barControl.bar, fillColor)
    end

    local lossBar = barControl.lossBar
    if not lossBar then
        return
    end

    if maximumValue <= 0 then
        barControl.lastPowerValue = nil
        barControl.lastPowerMaxValue = nil
        barControl.powerLossDisplayValue = nil
        lossBar:SetHidden(true)
        StopPowerLossAnimation(barControl)
        return
    end

    local previousValue = barControl.lastPowerValue
    local maxChanged = barControl.lastPowerMaxValue ~= nil and barControl.lastPowerMaxValue ~= maximumValue

    if previousValue == nil or maxChanged then
        barControl.powerLossDisplayValue = currentValue
        SetBarValue(lossBar, currentValue, maximumValue)
        lossBar:SetHidden(true)
        StopPowerLossAnimation(barControl)
    elseif currentValue < previousValue then
        local startValue = barControl.powerLossDisplayValue or previousValue
        if previousValue > startValue then
            startValue = previousValue
        end
        if currentValue > startValue then
            startValue = currentValue
        end

        barControl.powerLossDisplayValue = startValue
        barControl.powerLossStartValue = startValue
        barControl.powerLossTargetValue = currentValue
        barControl.powerLossMaxValue = maximumValue
        barControl.powerLossStartTime = GetFrameTimeMilliseconds() + POWER_LOSS_HOLD_MS

        SetBarValue(lossBar, startValue, maximumValue)
        lossBar:SetHidden(false)
        StartPowerLossAnimation(barControl)
    elseif currentValue > previousValue then
        barControl.powerLossDisplayValue = currentValue
        SetBarValue(lossBar, currentValue, maximumValue)
        lossBar:SetHidden(true)
        StopPowerLossAnimation(barControl)
    end

    barControl.lastPowerValue = currentValue
    barControl.lastPowerMaxValue = maximumValue
end

local function GetInactiveHotbarCategory(activeHotbarCategory)
    if activeHotbarCategory == HOTBAR_CATEGORY_PRIMARY then
        return HOTBAR_CATEGORY_BACKUP
    elseif activeHotbarCategory == HOTBAR_CATEGORY_BACKUP then
        return HOTBAR_CATEGORY_PRIMARY
    end

    return nil
end

local function GetMainHandEquipSlotForHotbar(hotbarCategory)
    if hotbarCategory == HOTBAR_CATEGORY_BACKUP then
        return EQUIP_SLOT_BACKUP_MAIN
    elseif hotbarCategory == HOTBAR_CATEGORY_PRIMARY then
        return EQUIP_SLOT_MAIN_HAND
    end

    return nil
end

local function GetOffHandEquipSlotForHotbar(hotbarCategory)
    if hotbarCategory == HOTBAR_CATEGORY_BACKUP then
        return EQUIP_SLOT_BACKUP_OFF
    elseif hotbarCategory == HOTBAR_CATEGORY_PRIMARY then
        return EQUIP_SLOT_OFF_HAND
    end

    return nil
end

local function IsOneHandedWeaponType(weaponType)
    return weaponType and ONE_HANDED_WEAPON_TYPES[weaponType] == true
end

local function IsTwoHandedWeaponType(weaponType)
    return weaponType and TWO_HANDED_WEAPON_TYPES[weaponType] == true
end

local function IsStaffWeaponType(weaponType)
    return weaponType and STAFF_WEAPON_TYPES[weaponType] == true
end

local function GetWeaponTypeForEquipSlot(equipSlot)
    if not equipSlot then
        return nil
    end

    local slotHasItem = GetWornItemInfo(BAG_WORN, equipSlot)
    if not slotHasItem then
        return nil
    end

    return GetItemWeaponType(BAG_WORN, equipSlot)
end

local function GetWeaponIconTextureForHotbar(hotbarCategory)
    local mainHandSlot = GetMainHandEquipSlotForHotbar(hotbarCategory)
    local offHandSlot = GetOffHandEquipSlotForHotbar(hotbarCategory)
    local mainHandWeaponType = GetWeaponTypeForEquipSlot(mainHandSlot)
    local offHandWeaponType = GetWeaponTypeForEquipSlot(offHandSlot)

    if IsOneHandedWeaponType(mainHandWeaponType) and IsOneHandedWeaponType(offHandWeaponType) then
        return TEXTURES.weaponDualWield
    end

    if offHandWeaponType == WEAPONTYPE_SHIELD then
        return TEXTURES.weaponShield
    end

    if mainHandWeaponType == WEAPONTYPE_BOW or offHandWeaponType == WEAPONTYPE_BOW then
        return TEXTURES.weaponBow
    end

    if IsStaffWeaponType(mainHandWeaponType) or IsStaffWeaponType(offHandWeaponType) then
        return TEXTURES.weaponStaff
    end

    if IsTwoHandedWeaponType(mainHandWeaponType) or IsTwoHandedWeaponType(offHandWeaponType) then
        return TEXTURES.weaponTwoHanded
    end

    if IsOneHandedWeaponType(mainHandWeaponType) or IsOneHandedWeaponType(offHandWeaponType) then
        return TEXTURES.weaponSword
    end

    return nil
end

function addon:CreateSlot(name, parent, size, keybindActionName, gamepadActionName, showKeybind)
    if showKeybind == nil then
        showKeybind = true
    end

    local slot = CreateControl(name, parent, CT_CONTROL)
    slot:SetDimensions(size, showKeybind and (size + KEYBIND_LABEL_GAP + KEYBIND_LABEL_HEIGHT) or size)

    local frame = CreateControl(name .. "Frame", slot, CT_CONTROL)
    frame:SetDimensions(size, size)
    frame:SetAnchor(TOP, slot, TOP, 0, 0)
    local border, background = CreateInsetBackdrop(name .. "FrameBackdrop", frame, 1, { 0.02, 0.02, 0.02, 0.68 }, SLOT_BORDER_COLOR)

    local frameTexture = CreateControl(name .. "FrameTexture", frame, CT_TEXTURE)
    frameTexture:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    frameTexture:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, 0, 0)
    frameTexture:SetTexture(TEXTURES.slotFrame)
    frameTexture:SetDrawLevel(0)

    local ultimateGlowTexture = CreateControl(name .. "UltimateGlowTexture", frame, CT_TEXTURE)
    ultimateGlowTexture:SetAnchor(TOPLEFT, frame, TOPLEFT, -4, -4)
    ultimateGlowTexture:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, 4, 4)
    ultimateGlowTexture:SetTexture(TEXTURES.ultimateFrame)
    ultimateGlowTexture:SetDrawLevel(5)
    ultimateGlowTexture:SetColor(1, 0.82, 0.34, 1)
    ultimateGlowTexture:SetAlpha(0)
    ultimateGlowTexture:SetHidden(true)

    local ultimateFrameTexture = CreateControl(name .. "UltimateFrameTexture", frame, CT_TEXTURE)
    ultimateFrameTexture:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    ultimateFrameTexture:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, 0, 0)
    ultimateFrameTexture:SetTexture(TEXTURES.ultimateFrame)
    ultimateFrameTexture:SetDrawLevel(6)
    ultimateFrameTexture:SetHidden(true)

    local iconClip = CreateControl(name .. "IconClip", frame, CT_CONTROL)
    iconClip:SetAnchor(TOPLEFT, frame, TOPLEFT, DEFAULT_SLOT_ICON_INSET, DEFAULT_SLOT_ICON_INSET)
    iconClip:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -DEFAULT_SLOT_ICON_INSET, -DEFAULT_SLOT_ICON_INSET)

    local icon = CreateControl(name .. "Icon", iconClip, CT_TEXTURE)
    icon:SetAnchor(TOPLEFT, iconClip, TOPLEFT, 0, 0)
    icon:SetAnchor(BOTTOMRIGHT, iconClip, BOTTOMRIGHT, 0, 0)
    icon:SetDrawLevel(1)
    icon:SetHidden(true)

    local unusableOverlay = CreateControl(name .. "UnusableOverlay", iconClip, CT_BACKDROP)
    unusableOverlay:SetAnchor(TOPLEFT, icon, TOPLEFT, 0, 0)
    unusableOverlay:SetAnchor(BOTTOMRIGHT, icon, BOTTOMRIGHT, 0, 0)
    unusableOverlay:SetDrawLevel(5)
    SetBackdropColor(unusableOverlay, 0, 0, 0, 0.34)
    unusableOverlay:SetHidden(true)

    local ultimateMask = CreateControl(name .. "UltimateMask", iconClip, CT_BACKDROP)
    ultimateMask:SetAnchor(TOPLEFT, icon, TOPLEFT, 0, 0)
    ultimateMask:SetAnchor(TOPRIGHT, icon, TOPRIGHT, 0, 0)
    ultimateMask:SetHeight(size - 4)
    ultimateMask:SetDrawLevel(2)
    SetBackdropColor(ultimateMask, 0, 0, 0, 0.62)
    ultimateMask:SetHidden(true)

    local ultimateReady = CreateControl(name .. "UltimateReady", iconClip, CT_BACKDROP)
    ultimateReady:SetAnchor(TOPLEFT, icon, TOPLEFT, 0, 0)
    ultimateReady:SetAnchor(BOTTOMRIGHT, icon, BOTTOMRIGHT, 0, 0)
    ultimateReady:SetDrawLevel(3)
    SetBackdropColor(ultimateReady, 0.95, 0.68, 0.18, 0.30)
    ultimateReady:SetHidden(true)

    local ultimateShimmerTexture = CreateControl(name .. "UltimateShimmerTexture", frame, CT_TEXTURE)
    ultimateShimmerTexture:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    ultimateShimmerTexture:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, 0, 0)
    ultimateShimmerTexture:SetTexture(TEXTURES.ultimateShimmer)
    ultimateShimmerTexture:SetTextureCoords(0, ULTIMATE_READY_SHIMMER_U_WIDTH, 0, 1)
    ultimateShimmerTexture:SetDrawLevel(7)
    ultimateShimmerTexture:SetAlpha(0)
    ultimateShimmerTexture:SetHidden(true)

    local active = CreateControl(name .. "Active", frame, CT_BACKDROP)
    active:SetAnchor(TOPLEFT, frame, TOPLEFT, 1, 1)
    active:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -1, -1)
    SetBackdropColor(active, 0.86, 0.58, 0.16, 0.16)
    active:SetHidden(true)

    local cooldown = CreateControl(name .. "Cooldown", iconClip, CT_COOLDOWN)
    cooldown:SetAnchor(TOPLEFT, icon, TOPLEFT, 0, 0)
    cooldown:SetAnchor(BOTTOMRIGHT, icon, BOTTOMRIGHT, 0, 0)
    cooldown:SetFillColor(0, 0, 0, 0.70)
    cooldown:SetHidden(true)

    local count = CreateLabel(name .. "Count", frame, "ZoFontGameSmall", { 1, 1, 1, 1 })
    count:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -2, -1)
    count:SetDimensions(size - 5, 14)
    count:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    count:SetHidden(true)

    local effectOverlay = CreateControl(name .. "EffectOverlay", frame, CT_BACKDROP)
    effectOverlay:SetAnchor(TOPLEFT, frame, TOPLEFT, 1, 1)
    effectOverlay:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -1, -1)
    effectOverlay:SetDrawLevel(8)
    SetBackdropColor(effectOverlay, 0, 0, 0, SKILL_EFFECT_ICON_OVERLAY_ALPHA)
    effectOverlay:SetHidden(true)

    local effectBorder = CreateControl(name .. "EffectBorder", frame, CT_CONTROL)
    effectBorder:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    effectBorder:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, 0, 0)
    effectBorder:SetDrawLevel(9)
    effectBorder:SetHidden(true)

    local function CreateEffectBorderPart(suffix)
        local part = CreateControl(name .. "EffectBorder" .. suffix, effectBorder, CT_TEXTURE)
        part:SetDrawLevel(9)
        part:SetColor(SKILL_EFFECT_BORDER_COLOR[1], SKILL_EFFECT_BORDER_COLOR[2], SKILL_EFFECT_BORDER_COLOR[3], SKILL_EFFECT_BORDER_COLOR[4])
        return part
    end

    local effectBorderTop = CreateEffectBorderPart("Top")
    effectBorderTop:SetAnchor(TOPLEFT, effectBorder, TOPLEFT, 0, 0)
    effectBorderTop:SetDimensions(size, SKILL_EFFECT_BORDER_THICKNESS)

    local effectBorderRight = CreateEffectBorderPart("Right")
    effectBorderRight:SetAnchor(TOPRIGHT, effectBorder, TOPRIGHT, 0, 0)
    effectBorderRight:SetDimensions(SKILL_EFFECT_BORDER_THICKNESS, size)

    local effectBorderBottom = CreateEffectBorderPart("Bottom")
    effectBorderBottom:SetAnchor(BOTTOMRIGHT, effectBorder, BOTTOMRIGHT, 0, 0)
    effectBorderBottom:SetDimensions(size, SKILL_EFFECT_BORDER_THICKNESS)

    local effectBorderLeft = CreateEffectBorderPart("Left")
    effectBorderLeft:SetAnchor(BOTTOMLEFT, effectBorder, BOTTOMLEFT, 0, 0)
    effectBorderLeft:SetDimensions(SKILL_EFFECT_BORDER_THICKNESS, size)

    local effectTimer = CreateLabel(name .. "EffectTimer", frame, "ZoFontGameSmall", { 0.86, 0.85, 0.13, 1 })
    effectTimer:SetDimensions(size - 4, 14)
    effectTimer:SetAnchor(CENTER, frame, CENTER, 0, 0)
    effectTimer:SetDrawLevel(10)
    effectTimer:SetHidden(true)

    local effectStackBackground = CreateControl(name .. "EffectStackBackground", frame, CT_TEXTURE)
    effectStackBackground:SetDimensions(20, 18)
    effectStackBackground:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -2, 2)
    effectStackBackground:SetDrawLevel(9)
    effectStackBackground:SetColor(0, 0, 0, SKILL_EFFECT_STACK_BACKGROUND_ALPHA)
    effectStackBackground:SetHidden(true)

    local effectStackCount = CreateLabel(name .. "EffectStackCount", frame, "ZoFontGameBold", { 0.86, 0.85, 0.13, 1 })
    effectStackCount:SetDimensions(20, 18)
    effectStackCount:SetAnchor(TOPRIGHT, frame, TOPRIGHT, -2, 2)
    effectStackCount:SetDrawLevel(11)
    effectStackCount:SetHidden(true)

    if showKeybind then
        local keybindFrame = CreateControl(name .. "KeybindFrame", slot, CT_CONTROL)
        keybindFrame:SetDimensions(size, KEYBIND_LABEL_HEIGHT)
        keybindFrame:SetAnchor(TOP, frame, BOTTOM, 0, KEYBIND_LABEL_GAP)

        local keybindBackground = CreateControl(name .. "KeybindBackground", keybindFrame, CT_TEXTURE)
        keybindBackground:SetAnchor(TOPLEFT, keybindFrame, TOPLEFT, 0, 0)
        keybindBackground:SetAnchor(BOTTOMRIGHT, keybindFrame, BOTTOMRIGHT, 0, 0)
        keybindBackground:SetTexture(TEXTURES.keybindBox)

        local keybind = CreateLabel(name .. "Keybind", keybindFrame, "ZoFontGameSmall", { 0.86, 0.84, 0.78, 1 })
        keybind:SetAnchor(TOPLEFT, keybindFrame, TOPLEFT, 0, 0)
        keybind:SetAnchor(BOTTOMRIGHT, keybindFrame, BOTTOMRIGHT, 0, 0)

        if keybindActionName then
            ZO_Keybindings_RegisterLabelForBindingUpdate(keybind, keybindActionName, HIDE_UNBOUND, gamepadActionName)
        end

        slot.keybindFrame = keybindFrame
        slot.keybindBackground = keybindBackground
        slot.keybind = keybind
    end

    slot.frame = frame
    slot.border = border
    slot.background = background
    slot.frameTexture = frameTexture
    slot.ultimateGlowTexture = ultimateGlowTexture
    slot.ultimateFrameTexture = ultimateFrameTexture
    slot.ultimateShimmerTexture = ultimateShimmerTexture
    slot.active = active
    slot.iconClip = iconClip
    slot.icon = icon
    slot.slotSize = size
    slot.iconSize = size - (DEFAULT_SLOT_ICON_INSET * 2)
    slot.unusableOverlay = unusableOverlay
    slot.ultimateMask = ultimateMask
    slot.ultimateReady = ultimateReady
    slot.cooldown = cooldown
    slot.count = count
    slot.effectBorder = effectBorder
    slot.effectBorderParts = { effectBorderTop, effectBorderRight, effectBorderBottom, effectBorderLeft }
    slot.effectOverlay = effectOverlay
    slot.effectTimer = effectTimer
    slot.effectStackBackground = effectStackBackground
    slot.effectStackCount = effectStackCount

    return slot
end

function addon:CreateWeaponIcon(name, parent, size)
    local slot = CreateControl(name, parent, CT_CONTROL)
    slot:SetDimensions(size, size)

    local frame = CreateControl(name .. "Frame", slot, CT_CONTROL)
    frame:SetAnchor(TOPLEFT, slot, TOPLEFT, 0, 0)
    frame:SetAnchor(BOTTOMRIGHT, slot, BOTTOMRIGHT, 0, 0)
    local border, background = CreateInsetBackdrop(name .. "FrameBackdrop", frame, 1, { 0.02, 0.02, 0.02, 0.68 }, SLOT_BORDER_COLOR)

    local frameTexture = CreateControl(name .. "FrameTexture", frame, CT_TEXTURE)
    frameTexture:SetAnchor(TOPLEFT, frame, TOPLEFT, 0, 0)
    frameTexture:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, 0, 0)
    frameTexture:SetTexture(TEXTURES.slotFrameEmpty)
    frameTexture:SetDrawLevel(0)

    local icon = CreateControl(name .. "Icon", frame, CT_TEXTURE)
    icon:SetAnchor(TOPLEFT, frame, TOPLEFT, 2, 2)
    icon:SetAnchor(BOTTOMRIGHT, frame, BOTTOMRIGHT, -2, -2)
    icon:SetDrawLevel(1)
    icon:SetHidden(true)

    slot.frame = frame
    slot.border = border
    slot.background = background
    slot.frameTexture = frameTexture
    slot.icon = icon

    return slot
end

local function SetSlotUltimateFrameEnabled(slot, enabled)
    if not slot or not slot.ultimateFrameTexture or slot.ultimateFrameEnabled == enabled then
        return
    end

    slot.ultimateFrameEnabled = enabled

    slot.border:SetHidden(enabled)
    slot.background:SetHidden(enabled)
    slot.frameTexture:SetHidden(enabled)
    slot.ultimateFrameTexture:SetHidden(not enabled)
    if not enabled then
        if slot.ultimateGlowTexture then
            slot.ultimateGlowTexture:SetHidden(true)
            slot.ultimateGlowTexture:SetAlpha(0)
        end

        if slot.ultimateShimmerTexture then
            slot.ultimateShimmerTexture:SetHidden(true)
            slot.ultimateShimmerTexture:SetAlpha(0)
        end
    end

    local iconInset = DEFAULT_SLOT_ICON_INSET
    if enabled then
        iconInset = math.max(DEFAULT_SLOT_ICON_INSET, math.floor((slot.slotSize or SLOT_SIZE) * ULTIMATE_SLOT_ICON_INSET_RATIO))
    end

    slot.iconClip:ClearAnchors()
    slot.iconClip:SetAnchor(TOPLEFT, slot.frame, TOPLEFT, iconInset, iconInset)
    slot.iconClip:SetAnchor(BOTTOMRIGHT, slot.frame, BOTTOMRIGHT, -iconInset, -iconInset)

    slot.cooldown:ClearAnchors()
    slot.cooldown:SetAnchor(TOPLEFT, slot.icon, TOPLEFT, 0, 0)
    slot.cooldown:SetAnchor(BOTTOMRIGHT, slot.icon, BOTTOMRIGHT, 0, 0)

    slot.iconSize = (slot.slotSize or SLOT_SIZE) - (iconInset * 2)
end

function addon:GetLayoutComponentControl(componentData)
    if componentData.powerType then
        return self.powerBars and self.powerBars[componentData.powerType]
    end

    return self[componentData.controlField]
end

function addon:GetLayoutComponentBaseOffsets(componentData, barLayout)
    local offsetX = componentData.baseOffsetX or 0
    local offsetY = componentData.baseOffsetY or 0

    if componentData.barLayoutPowerType then
        local layout = barLayout.bars[componentData.barLayoutPowerType]
        if layout then
            offsetY = layout.y
        end
    elseif componentData.barLayoutOffsetY then
        offsetY = barLayout[componentData.barLayoutOffsetY] or offsetY
    end

    return offsetX, offsetY
end

function addon:ApplyLayoutComponentAnchor(componentKey, barLayout)
    local componentData = LAYOUT_COMPONENTS[componentKey]
    if not componentData then
        return
    end

    local control = self:GetLayoutComponentControl(componentData)
    local relativeControl = self[componentData.relativeControlField]
    if not control or not relativeControl then
        return
    end

    barLayout = barLayout or self:GetCurrentBarLayout()
    local baseOffsetX, baseOffsetY = self:GetLayoutComponentBaseOffsets(componentData, barLayout)
    local offsetX = tonumber(self:GetSettingValue(componentData.offsetXSetting)) or 0
    local offsetY = tonumber(self:GetSettingValue(componentData.offsetYSetting)) or 0

    control:ClearAnchors()
    control:SetAnchor(componentData.point, relativeControl, componentData.relativePoint, baseOffsetX + offsetX, baseOffsetY + offsetY)
end

function addon:ApplyLayoutComponentAnchors(barLayout)
    for _, componentKey in ipairs(LAYOUT_COMPONENT_ORDER) do
        self:ApplyLayoutComponentAnchor(componentKey, barLayout)
    end
end

local function GetControlScreenScale(control)
    local left, top, right, bottom = control:GetScreenRect()
    local width, height = control:GetDimensions()
    if width <= 0 or height <= 0 then
        return nil, nil
    end

    return (right - left) / width, (bottom - top) / height
end

function addon:SaveLayoutComponentPosition(componentKey)
    if not self.savedVars then
        return
    end

    local componentData = LAYOUT_COMPONENTS[componentKey]
    if not componentData then
        return
    end

    local control = self:GetLayoutComponentControl(componentData)
    local relativeControl = self[componentData.relativeControlField]
    if not control or not relativeControl then
        return
    end

    local anchorSpace = control:GetParent()
    if not anchorSpace then
        self:ApplyLayoutComponentAnchor(componentKey)
        return
    end

    local scaleX, scaleY = GetControlScreenScale(anchorSpace)
    if not scaleX or not scaleY or scaleX == 0 or scaleY == 0 then
        self:ApplyLayoutComponentAnchor(componentKey)
        return
    end

    local controlX, controlY = control:ProjectRectToScreenAndComputeAABBPoint(componentData.point)
    local relativeX, relativeY = relativeControl:ProjectRectToScreenAndComputeAABBPoint(componentData.relativePoint)
    local offsetX = (controlX - relativeX) / scaleX
    local offsetY = (controlY - relativeY) / scaleY
    local baseOffsetX, baseOffsetY = self:GetLayoutComponentBaseOffsets(componentData, self:GetCurrentBarLayout())
    self.savedVars[componentData.offsetXSetting] = offsetX - baseOffsetX
    self.savedVars[componentData.offsetYSetting] = offsetY - baseOffsetY
    self:ApplyLayoutComponentAnchor(componentKey)
end

function addon:ResetLayoutComponentPositions()
    if not self.savedVars then
        return
    end

    for _, componentKey in ipairs(LAYOUT_COMPONENT_ORDER) do
        local componentData = LAYOUT_COMPONENTS[componentKey]
        self.savedVars[componentData.offsetXSetting] = 0
        self.savedVars[componentData.offsetYSetting] = 0
    end

    self:ApplyLayoutComponentAnchors()
end

function addon:CreateLayoutComponentOverlay(componentKey)
    local componentData = LAYOUT_COMPONENTS[componentKey]
    local target = componentData and self:GetLayoutComponentControl(componentData)
    if not target then
        return
    end

    target:SetMovable(false)
    target:SetClampedToScreen(true)
    target:SetHandler("OnMoveStop", function()
        addon:SaveLayoutComponentPosition(componentKey)
    end)

    local overlay = CreateControl(ADDON_NAME .. "LayoutOverlay" .. componentKey, target, CT_BACKDROP)
    overlay:SetAnchor(TOPLEFT, target, TOPLEFT, 0, 0)
    overlay:SetAnchor(BOTTOMRIGHT, target, BOTTOMRIGHT, 0, 0)
    overlay:SetDrawLevel(200)
    overlay:SetCenterColor(0.82, 0.60, 0.12, 0.20)
    overlay:SetEdgeColor(1, 0.82, 0.36, 0.95)
    overlay:SetMouseEnabled(false)
    overlay:SetHidden(true)
    overlay:SetHandler("OnMouseDown", function()
        if addon:GetSettingValue("unlockUI") and addon:GetSettingValue("moveComponentsIndividually") then
            target:StartMoving()
        end
    end)
    overlay:SetHandler("OnMouseUp", function()
        target:StopMovingOrResizing()
    end)

    local label = CreateLabel(ADDON_NAME .. "LayoutOverlay" .. componentKey .. "Label", overlay, "ZoFontGameSmall", { 1, 0.90, 0.58, 1 })
    label:SetAnchor(CENTER, overlay, CENTER, 0, 0)
    label:SetDrawLevel(201)
    label:SetText(componentData.label)

    self.layoutOverlays[componentKey] = overlay
end

function addon:CreateControls()
    local root = CreateTopLevelWindow(ADDON_NAME .. "Root")
    root:SetDimensions(ROOT_WIDTH, ROOT_HEIGHT)
    root:SetAnchor(DEFAULT_ROOT_POINT, GuiRoot, DEFAULT_ROOT_RELATIVE_POINT, DEFAULT_ROOT_OFFSET_X, DEFAULT_ROOT_OFFSET_Y)
    root:SetMouseEnabled(false)
    root:SetMovable(false)
    root:SetClampedToScreen(true)
    root:SetDrawTier(DT_HIGH)
    root:SetDrawLayer(DL_OVERLAY)
    root:SetDrawLevel(1)
    root:SetHandler("OnMouseDown", function(control)
        if addon:GetSettingValue("unlockUI") then
            control:StartMoving()
        end
    end)
    root:SetHandler("OnMouseUp", function(control)
        control:StopMovingOrResizing()
    end)
    root:SetHandler("OnMoveStop", function()
        addon:SaveRootPosition()
    end)

    local dragOverlay = CreateControl(ADDON_NAME .. "DragOverlay", root, CT_BACKDROP)
    dragOverlay:SetAnchor(TOPLEFT, root, TOPLEFT, 0, 0)
    dragOverlay:SetAnchor(BOTTOMRIGHT, root, BOTTOMRIGHT, 0, 0)
    dragOverlay:SetDrawLevel(100)
    dragOverlay:SetCenterColor(0.82, 0.60, 0.12, 0.12)
    dragOverlay:SetEdgeColor(1, 0.82, 0.36, 0.95)
    dragOverlay:SetMouseEnabled(false)
    dragOverlay:SetHidden(true)
    dragOverlay:SetHandler("OnMouseDown", function()
        if addon:GetSettingValue("unlockUI") then
            root:StartMoving()
        end
    end)
    dragOverlay:SetHandler("OnMouseUp", function()
        root:StopMovingOrResizing()
    end)

    local dragOverlayLabel = CreateLabel(ADDON_NAME .. "DragOverlayLabel", dragOverlay, "ZoFontWinH5", { 1, 0.90, 0.58, 1 })
    dragOverlayLabel:SetAnchor(CENTER, dragOverlay, CENTER, 0, 0)
    dragOverlayLabel:SetDrawLevel(101)
    dragOverlayLabel:SetText("Whole UI")

    self.root = root
    self.dragOverlay = dragOverlay
    self.powerBars = {}
    self.skillSlots = {}
    self.backbarSlots = {}
    self.weaponIcons = {}
    self.quickSlots = {}
    self.layoutOverlays = {}

    local bars = CreateControl(ADDON_NAME .. "Bars", root, CT_CONTROL)
    bars:SetDimensions(POWER_BAR_WIDTH, BARS_PANEL_HEIGHT)
    bars:SetAnchor(TOP, root, TOP, 0, BARS_TOP_OFFSET)
    self.bars = bars

    for index, data in ipairs(RESOURCE_BARS) do
        local layout = RESOURCE_BAR_LAYOUTS[data.powerType]
        local overlayTexture = data.powerType == COMBAT_MECHANIC_FLAGS_HEALTH and TEXTURES.healthOverlay or TEXTURES.resourceOverlay
        local bar = CreateBar(ADDON_NAME .. "Power" .. index, bars, POWER_BAR_WIDTH, layout.height, data.color, overlayTexture, POWER_LOSS_COLOR)
        bar:SetAnchor(TOP, bars, TOP, 0, layout.y)
        bar.defaultColor = data.color

        local isHealthBar = data.powerType == COMBAT_MECHANIC_FLAGS_HEALTH
        if isHealthBar then
            bar.damagedColor = HEALTH_DAMAGED_COLOR

            local shieldBar = CreateControl(ADDON_NAME .. "DamageShieldFill", bar, CT_STATUSBAR)
            shieldBar:SetAnchor(TOPLEFT, bar, TOPLEFT, 1, 1)
            shieldBar:SetDimensions(1, math.max(1, layout.height - 2))
            shieldBar:SetDrawLevel(3)
            shieldBar:SetMinMax(0, 1)
            shieldBar:SetValue(1)
            shieldBar:SetColor(DAMAGE_SHIELD_COLOR[1], DAMAGE_SHIELD_COLOR[2], DAMAGE_SHIELD_COLOR[3], DAMAGE_SHIELD_COLOR[4])
            shieldBar:SetHidden(true)
            bar.shieldBar = shieldBar

            bar.overlay:SetDrawLevel(4)
        end

        local textFont = isHealthBar and "ZoFontWinH5" or "ZoFontGameSmall"
        local textColor = isHealthBar and { 0.88, 0.86, 0.78, 0.92 } or { 0.86, 0.84, 0.78, 0.90 }
        local text = CreateLabel(ADDON_NAME .. "Power" .. index .. "Text", bar, textFont, textColor)
        text:SetAnchor(CENTER, bar, CENTER, 0, 0)
        text:SetDimensions(POWER_BAR_WIDTH - 8, layout.height)
        text:SetDrawLevel(isHealthBar and 5 or 4)
        text:SetText(data.label)
        text:SetHidden(not isHealthBar and not self:GetSettingValue("showSecondaryResourceNumbers"))

        bar.valueText = text

        if isHealthBar then
            local shieldInfo = CreateControl(ADDON_NAME .. "DamageShieldInfo", bar, CT_CONTROL)
            shieldInfo:SetDimensions(1, layout.height)
            shieldInfo:SetAnchor(CENTER, bar, CENTER, 0, 0)
            shieldInfo:SetDrawLevel(6)
            shieldInfo:SetHidden(true)

            local shieldIcon = CreateControl(ADDON_NAME .. "DamageShieldIcon", shieldInfo, CT_TEXTURE)
            shieldIcon:SetAnchor(LEFT, shieldInfo, LEFT, 0, 0)
            shieldIcon:SetTexture(TEXTURES.weaponShield)
            shieldIcon:SetDrawLevel(6)

            local shieldText = CreateLabel(ADDON_NAME .. "DamageShieldText", shieldInfo, "ZoFontGameSmall", DAMAGE_SHIELD_TEXT_COLOR)
            shieldText:SetAnchor(LEFT, shieldIcon, RIGHT, DAMAGE_SHIELD_READOUT_GAP, 0)
            shieldText:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            shieldText:SetDrawLevel(6)

            bar.shieldInfo = shieldInfo
            bar.shieldIcon = shieldIcon
            bar.shieldText = shieldText
            ApplyDamageShieldControlLayout(bar, layout.height)
        end

        self.powerBars[data.powerType] = bar
    end

    local xp = CreateBar(ADDON_NAME .. "Experience", bars, POWER_BAR_WIDTH, EXPERIENCE_BAR_HEIGHT, { 0.74, 0.56, 0.17, 0.50 }, TEXTURES.resourceOverlay)
    xp:SetAnchor(TOP, bars, TOP, 0, EXPERIENCE_BAR_OFFSET_Y)
    xp:SetDrawLevel(3)
    self.experienceBar = xp

    local xpText = CreateLabel(ADDON_NAME .. "ExperienceText", xp, "ZoFontGameSmall", { 0.93, 0.82, 0.48, 1 })
    xpText:SetAnchor(CENTER, xp, CENTER, 0, 0)
    xpText:SetDimensions(POWER_BAR_WIDTH - 8, KEYBIND_LABEL_HEIGHT)
    xpText:SetHidden(true)
    self.experienceText = xpText

    local levelBadge = CreateControl(ADDON_NAME .. "LevelBadge", bars, CT_CONTROL)
    levelBadge:SetDimensions(LEVEL_BADGE_REGULAR_WIDTH, LEVEL_BADGE_REGULAR_HEIGHT)
    levelBadge:SetAnchor(TOP, bars, TOP, 0, LEVEL_BADGE_OFFSET_Y)
    levelBadge:SetDrawLevel(1)

    local levelBadgeTexture = CreateControl(ADDON_NAME .. "LevelBadgeTexture", levelBadge, CT_TEXTURE)
    levelBadgeTexture:SetAnchor(TOPLEFT, levelBadge, TOPLEFT, 0, 0)
    levelBadgeTexture:SetAnchor(BOTTOMRIGHT, levelBadge, BOTTOMRIGHT, 0, 0)
    levelBadgeTexture:SetTexture(TEXTURES.levelBadgeRegular)
    levelBadgeTexture:SetDrawLevel(0)
    self.levelBadge = levelBadge
    self.levelBadgeTexture = levelBadgeTexture

    local levelText = CreateLabel(ADDON_NAME .. "LevelText", levelBadge, "ZoFontGameSmall", { 0.92, 0.90, 0.84, 1 })
    levelText:SetAnchor(TOPLEFT, levelBadge, TOPLEFT, 0, LEVEL_BADGE_TEXT_OFFSET_Y)
    levelText:SetAnchor(BOTTOMRIGHT, levelBadge, BOTTOMRIGHT, 0, LEVEL_BADGE_TEXT_OFFSET_Y)
    levelText:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    levelText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    levelText:SetDrawLevel(1)
    self.levelText = levelText

    local quickSlots = CreateControl(ADDON_NAME .. "QuickSlots", root, CT_CONTROL)
    quickSlots:SetDimensions(QUICK_SLOT_PANEL_WIDTH, SLOT_CONTROL_HEIGHT)
    quickSlots:SetAnchor(TOPRIGHT, bars, TOPLEFT, -SIDE_PANEL_GAP, -3)
    self.quickSlotContainer = quickSlots

    for index = 1, QUICK_SLOT_COUNT do
        local slot = self:CreateSlot(ADDON_NAME .. "QuickSlot" .. index, quickSlots, SLOT_SIZE, "ACTION_BUTTON_9", "GAMEPAD_ACTION_BUTTON_9")
        slot.slotIndex = index
        slot.hotbarCategory = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
        slot:SetAnchor(TOPLEFT, quickSlots, TOPLEFT, (index - 1) * (SLOT_SIZE + SLOT_GAP), 0)
        self.quickSlots[index] = slot
    end

    local skillSlots = CreateControl(ADDON_NAME .. "SkillSlots", root, CT_CONTROL)
    skillSlots:SetDimensions(SKILL_PANEL_WIDTH, SKILL_PANEL_HEIGHT)
    skillSlots:SetAnchor(TOPLEFT, bars, TOPRIGHT, SIDE_PANEL_GAP, -BARS_TOP_OFFSET)
    self.skillSlotContainer = skillSlots

    local backbar = CreateControl(ADDON_NAME .. "BackbarSlots", skillSlots, CT_CONTROL)
    backbar:SetDimensions(SKILL_PANEL_WIDTH, BACKBAR_SLOT_SIZE)
    backbar:SetAnchor(TOPLEFT, skillSlots, TOPLEFT, 0, 0)
    self.backbarContainer = backbar

    local weaponIcon = self:CreateWeaponIcon(ADDON_NAME .. "BackbarWeaponIcon", backbar, WEAPON_SLOT_SIZE)
    weaponIcon:SetAnchor(LEFT, backbar, LEFT, BACKBAR_WEAPON_OFFSET_X, 0)
    self.backbarWeaponIcon = weaponIcon
    self.weaponIcons.backbar = weaponIcon

    for index, slotIndex in ipairs(SKILL_SLOT_INDEXES) do
        local slot = self:CreateSlot(ADDON_NAME .. "BackbarSlot" .. index, backbar, BACKBAR_SLOT_SIZE, nil, nil, false)
        slot.slotIndex = slotIndex
        slot.hotbarCategory = nil
        slot.requiresHotbarCategory = true
        slot.tracksSkillEffect = true
        slot:SetAnchor(LEFT, backbar, LEFT, BACKBAR_ROW_OFFSET_X + ((index - 1) * (BACKBAR_SLOT_SIZE + BACKBAR_SLOT_GAP)), 0)
        self.backbarSlots[index] = slot
    end

    local activeWeaponIcon = self:CreateWeaponIcon(ADDON_NAME .. "ActiveWeaponIcon", skillSlots, ACTIVE_WEAPON_SLOT_SIZE)
    activeWeaponIcon:SetAnchor(TOPLEFT, skillSlots, TOPLEFT, 0, ACTIVE_ROW_OFFSET_Y)
    self.activeWeaponIcon = activeWeaponIcon
    self.weaponIcons.active = activeWeaponIcon

    for index, slotIndex in ipairs(SKILL_SLOT_INDEXES) do
        local actionName = "ACTION_BUTTON_" .. slotIndex
        local gamepadActionName = "GAMEPAD_ACTION_BUTTON_" .. slotIndex
        local slotSize = slotIndex == ULTIMATE_SLOT_INDEX and ACTIVE_ULTIMATE_SLOT_SIZE or SLOT_SIZE
        local slot = self:CreateSlot(ADDON_NAME .. "SkillSlot" .. index, skillSlots, slotSize, actionName, gamepadActionName)
        slot.slotIndex = slotIndex
        slot.hotbarCategory = nil
        slot.tracksSkillEffect = true
        slot:SetAnchor(TOPLEFT, skillSlots, TOPLEFT, SKILL_ROW_OFFSET_X + ((index - 1) * (SLOT_SIZE + SLOT_GAP)), ACTIVE_ROW_OFFSET_Y)
        self.skillSlots[index] = slot
    end

    for _, componentKey in ipairs(LAYOUT_COMPONENT_ORDER) do
        self:CreateLayoutComponentOverlay(componentKey)
    end
end

function addon:InitializeSavedVars()
    self.savedVars = ZO_SavedVars:NewAccountWide(SAVED_VARIABLES_NAME, SAVED_VARIABLES_VERSION, SAVED_VARIABLES_NAMESPACE, DEFAULT_SETTINGS)
end

function addon:ApplyRootDimensions(barLayout)
    if not self.root then
        return
    end

    barLayout = barLayout or self:GetCurrentBarLayout()

    local halfPowerBarWidth = math.floor(barLayout.width / 2)
    local rootSideWidth = math.max(halfPowerBarWidth + SIDE_PANEL_GAP + QUICK_SLOT_PANEL_WIDTH, halfPowerBarWidth + SIDE_PANEL_GAP + SKILL_PANEL_WIDTH)
    local rootHeight = math.max(BARS_TOP_OFFSET + barLayout.height + 2, SKILL_PANEL_HEIGHT + 2)

    self.root:SetDimensions(rootSideWidth * 2, rootHeight)
end

function addon:ApplyRootAnchor()
    if not self.root then
        return
    end

    local point = self:GetSettingValue("uiPoint") or DEFAULT_ROOT_POINT
    local relativePoint = self:GetSettingValue("uiRelativePoint") or DEFAULT_ROOT_RELATIVE_POINT
    local offsetX = tonumber(self:GetSettingValue("uiOffsetX")) or DEFAULT_ROOT_OFFSET_X
    local offsetY = tonumber(self:GetSettingValue("uiOffsetY")) or DEFAULT_ROOT_OFFSET_Y

    self.root:ClearAnchors()
    self.root:SetAnchor(point, GuiRoot, relativePoint, offsetX, offsetY)
end

function addon:SaveRootPosition()
    if not self.root or not self.savedVars then
        return
    end

    local _
    _, self.savedVars.uiPoint, _, self.savedVars.uiRelativePoint, self.savedVars.uiOffsetX, self.savedVars.uiOffsetY = self.root:GetAnchor(0)
end

function addon:ResetRootPosition()
    if not self.savedVars then
        return
    end

    self.savedVars.uiPoint = DEFAULT_ROOT_POINT
    self.savedVars.uiRelativePoint = DEFAULT_ROOT_RELATIVE_POINT
    self.savedVars.uiOffsetX = DEFAULT_ROOT_OFFSET_X
    self.savedVars.uiOffsetY = DEFAULT_ROOT_OFFSET_Y
    self:ApplyRootAnchor()
end

function addon:ApplyBarLayout()
    if not self.bars then
        return
    end

    local barLayout = self:GetCurrentBarLayout()
    self.bars:SetDimensions(barLayout.width, barLayout.height)

    for _, data in ipairs(RESOURCE_BARS) do
        local bar = self.powerBars[data.powerType]
        local layout = barLayout.bars[data.powerType]
        if bar and layout then
            bar:SetDimensions(barLayout.width, layout.height)

            if bar.valueText then
                bar.valueText:SetDimensions(barLayout.width - 8, layout.height)
            end

            if data.powerType == COMBAT_MECHANIC_FLAGS_HEALTH then
                ApplyDamageShieldControlLayout(bar, layout.height)
                UpdateDamageShieldVisuals(bar, bar.currentPowerMaxValue, self.damageShieldValue)
            end
        end
    end

    if self.experienceBar then
        self.experienceBar:SetDimensions(barLayout.width, barLayout.experienceHeight)
    end

    if self.experienceText then
        self.experienceText:SetDimensions(barLayout.width - 8, KEYBIND_LABEL_HEIGHT)
    end

    self:ApplyLayoutComponentAnchors(barLayout)
    self:ApplyRootDimensions(barLayout)
end

function addon:ApplyResourceNumberVisibility()
    if not self.powerBars then
        return
    end

    local showSecondaryResourceNumbers = self:GetSettingValue("showSecondaryResourceNumbers") == true

    for _, data in ipairs(RESOURCE_BARS) do
        local bar = self.powerBars[data.powerType]
        if bar and bar.valueText then
            local isHealthBar = data.powerType == COMBAT_MECHANIC_FLAGS_HEALTH
            bar.valueText:SetHidden(not isHealthBar and not showSecondaryResourceNumbers)
        end
    end
end

function addon:ApplyUltimateShimmerSetting()
    if self:GetSettingValue("showUltimateShimmer") then
        return
    end

    if self.skillSlots then
        for _, slot in ipairs(self.skillSlots) do
            if slot.ultimateShimmerTexture then
                slot.ultimateShimmerTexture:SetHidden(true)
                slot.ultimateShimmerTexture:SetAlpha(0)
            end
        end
    end

    if self.backbarSlots then
        for _, slot in ipairs(self.backbarSlots) do
            if slot.ultimateShimmerTexture then
                slot.ultimateShimmerTexture:SetHidden(true)
                slot.ultimateShimmerTexture:SetAlpha(0)
            end
        end
    end
end

function addon:ApplySkillEffectSettings()
    local frontNumberScale = ClampNumber(
        self:GetSettingValue("skillEffectFrontNumberScale"),
        SKILL_EFFECT_NUMBER_SCALE_MIN,
        SKILL_EFFECT_NUMBER_SCALE_MAX,
        DEFAULT_SETTINGS.skillEffectFrontNumberScale
    )
    local backNumberScale = ClampNumber(
        self:GetSettingValue("skillEffectBackNumberScale"),
        SKILL_EFFECT_NUMBER_SCALE_MIN,
        SKILL_EFFECT_NUMBER_SCALE_MAX,
        DEFAULT_SETTINGS.skillEffectBackNumberScale
    )

    local function ApplyNumberScale(slots, scale)
        for _, slot in ipairs(slots) do
            if slot.effectTimer then
                slot.effectTimer:SetScale(scale)
            end
            if slot.effectStackBackground then
                slot.effectStackBackground:SetScale(scale)
            end
            if slot.effectStackCount then
                slot.effectStackCount:SetScale(scale)
            end
        end
    end

    ApplyNumberScale(self.skillSlots, frontNumberScale)
    ApplyNumberScale(self.backbarSlots, backNumberScale)
    self:UpdateSkillEffectTimerTexts()
end

function addon:ApplyUnlockState()
    if not self.root then
        return
    end

    local unlocked = self:GetSettingValue("unlockUI") == true
    local moveComponentsIndividually = self:GetSettingValue("moveComponentsIndividually") == true
    local moveWholeUI = unlocked and not moveComponentsIndividually
    local moveComponents = unlocked and moveComponentsIndividually

    self.root:SetMouseEnabled(moveWholeUI)
    self.root:SetMovable(moveWholeUI)
    self.root:SetClampedToScreen(true)

    if self.dragOverlay then
        self.dragOverlay:SetMouseEnabled(moveWholeUI)
        self.dragOverlay:SetHidden(not moveWholeUI)
    end

    for _, componentKey in ipairs(LAYOUT_COMPONENT_ORDER) do
        local componentData = LAYOUT_COMPONENTS[componentKey]
        local control = self:GetLayoutComponentControl(componentData)
        local overlay = self.layoutOverlays and self.layoutOverlays[componentKey]

        if control then
            control:SetMouseEnabled(moveComponents)
            control:SetMovable(moveComponents)
        end

        if overlay then
            overlay:SetMouseEnabled(moveComponents)
            overlay:SetHidden(not moveComponents)
        end
    end
end

function addon:ApplySettings()
    if not self.root then
        return
    end

    self.root:SetScale(ClampNumber(self:GetSettingValue("uiScale"), SCALE_MIN, SCALE_MAX, DEFAULT_SETTINGS.uiScale))

    if self.quickSlotContainer then
        self.quickSlotContainer:SetScale(ClampNumber(self:GetSettingValue("consumablesScale"), SCALE_MIN, SCALE_MAX, DEFAULT_SETTINGS.consumablesScale))
    end

    if self.bars then
        self.bars:SetScale(ClampNumber(self:GetSettingValue("resourceScale"), SCALE_MIN, SCALE_MAX, DEFAULT_SETTINGS.resourceScale))
    end

    if self.skillSlotContainer then
        self.skillSlotContainer:SetScale(ClampNumber(self:GetSettingValue("skillsScale"), SCALE_MIN, SCALE_MAX, DEFAULT_SETTINGS.skillsScale))
    end

    for _, componentKey in ipairs(LAYOUT_COMPONENT_ORDER) do
        local componentData = LAYOUT_COMPONENTS[componentKey]
        if componentData.scaleSetting then
            local control = self:GetLayoutComponentControl(componentData)
            if control then
                control:SetScale(ClampNumber(self:GetSettingValue(componentData.scaleSetting), SCALE_MIN, SCALE_MAX, DEFAULT_SETTINGS[componentData.scaleSetting]))
            end
        end
    end

    self:ApplyBarLayout()
    self:ApplyRootAnchor()
    self:ApplyUnlockState()
    self:ApplyResourceNumberVisibility()
    self:ApplyUltimateShimmerSetting()
    self:ApplySkillEffectSettings()
    self:UpdateVisibility()
end

function addon:UpdatePower(powerType, current, maxValue)
    local bar = self.powerBars and self.powerBars[powerType]
    if not bar then
        return
    end

    if current == nil or maxValue == nil then
        current, maxValue = GetUnitPower(PLAYER_UNIT_TAG, powerType)
    end

    bar.currentPowerValue = tonumber(current) or 0
    bar.currentPowerMaxValue = tonumber(maxValue) or 0

    SetAnimatedBarValue(bar, current, maxValue)
    UpdatePowerBarVisuals(bar, current, maxValue)

    if bar.valueText then
        bar.valueText:SetText(FormatNumber(current))
    end

    if powerType == COMBAT_MECHANIC_FLAGS_HEALTH then
        UpdateDamageShieldVisuals(bar, maxValue, self.damageShieldValue)
    end
end

function addon:UpdateAllPowers()
    for _, data in ipairs(RESOURCE_BARS) do
        self:UpdatePower(data.powerType)
    end
end

function addon:UpdateDamageShield(shieldValue)
    if shieldValue == nil then
        local queriedShieldValue, _, sequenceId = GetUnitAttributeVisualizerEffectInfo(
            PLAYER_UNIT_TAG,
            ATTRIBUTE_VISUAL_POWER_SHIELDING,
            STAT_MITIGATION,
            ATTRIBUTE_HEALTH,
            COMBAT_MECHANIC_FLAGS_HEALTH
        )
        shieldValue = queriedShieldValue
        self.damageShieldSequenceId = sequenceId
    end

    self.damageShieldValue = math.max(0, tonumber(shieldValue) or 0)

    local healthBar = self.powerBars and self.powerBars[COMBAT_MECHANIC_FLAGS_HEALTH]
    if healthBar then
        UpdateDamageShieldVisuals(healthBar, healthBar.currentPowerMaxValue, self.damageShieldValue)
    end
end

function addon:UpdateExperience()
    local current
    local maxValue
    local levelLabel
    local isChampion = IsUnitChampion(PLAYER_UNIT_TAG)

    if isChampion then
        current = GetPlayerChampionXP() or 0
        local championPoints = GetPlayerChampionPointsEarned() or 0
        maxValue = GetNumChampionXPInChampionPoint(championPoints)
        levelLabel = FormatNumber(championPoints)
    else
        current = GetUnitXP(PLAYER_UNIT_TAG) or 0
        maxValue = GetUnitXPMax(PLAYER_UNIT_TAG)
        levelLabel = tostring(GetUnitLevel(PLAYER_UNIT_TAG))
    end

    if maxValue and maxValue > 0 then
        SetBarValue(self.experienceBar.bar, current, maxValue)
    else
        self.experienceBar.bar:SetMinMax(0, 1)
        self.experienceBar.bar:SetValue(1)
    end

    if self.levelBadgeIsChampion ~= isChampion then
        self.levelBadgeIsChampion = isChampion

        if isChampion then
            self.levelBadge:SetDimensions(LEVEL_BADGE_CHAMPION_WIDTH, LEVEL_BADGE_CHAMPION_HEIGHT)
            self.levelBadgeTexture:SetTexture(TEXTURES.levelBadgeChampion)
        else
            self.levelBadge:SetDimensions(LEVEL_BADGE_REGULAR_WIDTH, LEVEL_BADGE_REGULAR_HEIGHT)
            self.levelBadgeTexture:SetTexture(TEXTURES.levelBadgeRegular)
        end
    end

    self.levelText:SetText(levelLabel)
end

function addon:UpdateHotbarCategories()
    local activeHotbarCategory = GetActiveHotbarCategory()
    local backbarHotbarCategory = GetInactiveHotbarCategory(activeHotbarCategory)

    self.activeHotbarCategory = activeHotbarCategory
    self.backbarHotbarCategory = backbarHotbarCategory

    for _, slot in ipairs(self.skillSlots) do
        slot.hotbarCategory = activeHotbarCategory
        slot:SetHidden(false)
    end

    local showBackbar = backbarHotbarCategory ~= nil
    if self.backbarContainer then
        self.backbarContainer:SetHidden(not showBackbar)
    end

    for _, slot in ipairs(self.backbarSlots) do
        slot.hotbarCategory = backbarHotbarCategory
        slot:SetHidden(not showBackbar)
    end
end

function addon:UpdateWeaponIcon(weaponIcon, hotbarCategory)
    if not weaponIcon then
        return
    end

    local texture = GetWeaponIconTextureForHotbar(hotbarCategory)

    weaponIcon:SetHidden(hotbarCategory == nil)
    weaponIcon.icon:SetHidden(true)

    if texture then
        if weaponIcon.frameTexture then
            weaponIcon.frameTexture:SetTexture(TEXTURES.slotFrame)
        end
        weaponIcon.icon:SetTexture(texture)
        weaponIcon.icon:SetHidden(false)
    elseif weaponIcon.frameTexture then
        weaponIcon.frameTexture:SetTexture(TEXTURES.slotFrameEmpty)
    end
end

function addon:UpdateWeaponIcons()
    self:UpdateWeaponIcon(self.activeWeaponIcon, self.activeHotbarCategory)
    self:UpdateWeaponIcon(self.backbarWeaponIcon, self.backbarHotbarCategory)
end

function addon:UpdateSlotUsableState(slot, slotType, hasSlot)
    if not slot or not slot.icon then
        return
    end

    if slot.hotbarCategory == nil then
        slot.icon:SetDesaturation(0)
        slot.icon:SetColor(1, 1, 1, 1)
        if slot.unusableOverlay then
            slot.unusableOverlay:SetHidden(true)
        end
        return
    end

    slotType = slotType or GetSlotType(slot.slotIndex, slot.hotbarCategory)
    if hasSlot == nil then
        hasSlot = slotType ~= ACTION_TYPE_NOTHING
    end

    local isUnusable = hasSlot and
        slot.hotbarCategory ~= HOTBAR_CATEGORY_QUICKSLOT_WHEEL and
        ActionSlotHasNonCostStateFailure(slot.slotIndex, slot.hotbarCategory)

    if slot.isUltimateSlot and hasSlot then
        if slot.unusableOverlay then
            slot.unusableOverlay:SetHidden(not isUnusable)
        end
        return
    end

    if isUnusable then
        slot.icon:SetDesaturation(1)
        slot.icon:SetColor(0.58, 0.58, 0.58, 0.78)
    else
        slot.icon:SetDesaturation(0)
        slot.icon:SetColor(1, 1, 1, 1)
    end

    if slot.unusableOverlay then
        slot.unusableOverlay:SetHidden(not isUnusable)
    end
end

function addon:StartUltimateReadyPulse(slot)
    if slot.ultimateReadyPulsing then
        return
    end

    slot.ultimateReadyPulsing = true
    slot.frame:SetHandler("OnUpdate", function()
        local frameTime = GetFrameTimeMilliseconds()
        local pulse = (math.sin(frameTime * ULTIMATE_READY_PULSE_SPEED) + 1) * 0.5
        local alpha = ULTIMATE_READY_MIN_ALPHA + (ULTIMATE_READY_ALPHA_RANGE * pulse)
        slot.ultimateReady:SetAlpha(alpha)

        if slot.ultimateGlowTexture then
            slot.ultimateGlowTexture:SetHidden(false)
            slot.ultimateGlowTexture:SetAlpha(ULTIMATE_READY_GLOW_MIN_ALPHA + (ULTIMATE_READY_GLOW_ALPHA_RANGE * pulse))
        end

        if slot.ultimateFrameTexture then
            slot.ultimateFrameTexture:SetAlpha(0.92 + (0.08 * pulse))
            slot.ultimateFrameTexture:SetColor(1, 0.90 + (0.10 * pulse), 0.62 + (0.18 * pulse), 1)
        end

        if slot.ultimateShimmerTexture and addon:GetSettingValue("showUltimateShimmer") then
            local shimmerProgress = (frameTime % ULTIMATE_READY_SHIMMER_CYCLE_MS) / ULTIMATE_READY_SHIMMER_CYCLE_MS
            local shimmerLeft = ULTIMATE_READY_SHIMMER_U_TRAVEL * shimmerProgress
            slot.ultimateShimmerTexture:SetTextureCoords(shimmerLeft, shimmerLeft + ULTIMATE_READY_SHIMMER_U_WIDTH, 0, 1)
            slot.ultimateShimmerTexture:SetHidden(false)
            slot.ultimateShimmerTexture:SetAlpha(0.42 + (0.28 * pulse))
        elseif slot.ultimateShimmerTexture then
            slot.ultimateShimmerTexture:SetHidden(true)
            slot.ultimateShimmerTexture:SetAlpha(0)
        end

        if slot.border then
            SetBackdropColor(slot.border, 0.62, 0.46, 0.18, 0.50 + (0.34 * pulse))
        end
    end, "UltimateReadyPulse")
end

function addon:StopUltimateReadyPulse(slot)
    if slot.ultimateReadyPulsing then
        slot.ultimateReadyPulsing = false
        slot.frame:SetHandler("OnUpdate", nil, "UltimateReadyPulse")
    end

    if slot.ultimateReady then
        slot.ultimateReady:SetAlpha(1)
    end

    if slot.ultimateGlowTexture then
        slot.ultimateGlowTexture:SetHidden(true)
        slot.ultimateGlowTexture:SetAlpha(0)
    end

    if slot.ultimateFrameTexture then
        slot.ultimateFrameTexture:SetAlpha(1)
        slot.ultimateFrameTexture:SetColor(1, 1, 1, 1)
    end

    if slot.ultimateShimmerTexture then
        slot.ultimateShimmerTexture:SetHidden(true)
        slot.ultimateShimmerTexture:SetAlpha(0)
        slot.ultimateShimmerTexture:SetTextureCoords(0, ULTIMATE_READY_SHIMMER_U_WIDTH, 0, 1)
    end

    if slot.border then
        SetBackdropColor(slot.border, SLOT_BORDER_COLOR[1], SLOT_BORDER_COLOR[2], SLOT_BORDER_COLOR[3], SLOT_BORDER_COLOR[4])
    end
end

function addon:UpdateUltimateProgress(slot, hasSlot)
    if not slot or not slot.ultimateMask or not slot.ultimateReady then
        return
    end

    local hotbarCategory = slot.hotbarCategory
    local isUltimateSlot = slot.slotIndex == ULTIMATE_SLOT_INDEX and
        hotbarCategory ~= nil and
        IsActiveAbilityHotBarCategory(hotbarCategory)

    if hasSlot == nil and isUltimateSlot then
        hasSlot = GetSlotType(slot.slotIndex, hotbarCategory) ~= ACTION_TYPE_NOTHING
    end

    slot.isUltimateSlot = isUltimateSlot

    if not isUltimateSlot or not hasSlot then
        slot.ultimateMask:SetHidden(true)
        slot.ultimateReady:SetHidden(true)
        self:StopUltimateReadyPulse(slot)
        if isUltimateSlot then
            slot.icon:SetDesaturation(0)
            slot.icon:SetColor(1, 1, 1, 1)
        end
        return
    end

    local ultimateCost = GetSlotAbilityCost(ULTIMATE_SLOT_INDEX, COMBAT_MECHANIC_FLAGS_ULTIMATE, hotbarCategory)
    if not ultimateCost or ultimateCost <= 0 then
        slot.ultimateMask:SetHidden(true)
        slot.ultimateReady:SetHidden(true)
        self:StopUltimateReadyPulse(slot)
        slot.icon:SetDesaturation(0)
        slot.icon:SetColor(1, 1, 1, 1)
        return
    end

    local ultimatePower = GetUnitPower(PLAYER_UNIT_TAG, COMBAT_MECHANIC_FLAGS_ULTIMATE) or 0
    local progress = ultimatePower / ultimateCost
    if progress < 0 then
        progress = 0
    elseif progress > 1 then
        progress = 1
    end

    if progress >= 1 then
        slot.icon:SetDesaturation(0)
        slot.icon:SetColor(1, 1, 1, 1)
    else
        slot.icon:SetDesaturation(1)
        slot.icon:SetColor(0.42 + (0.46 * progress), 0.42 + (0.46 * progress), 0.42 + (0.46 * progress), 0.58 + (0.34 * progress))
    end

    local unfilledHeight = math.floor(slot.iconSize * (1 - progress))
    if unfilledHeight > 0 then
        slot.ultimateMask:SetHeight(unfilledHeight)
        slot.ultimateMask:SetHidden(false)
    else
        slot.ultimateMask:SetHidden(true)
    end

    if progress >= 1 then
        slot.ultimateReady:SetHidden(false)
        self:StartUltimateReadyPulse(slot)
    else
        slot.ultimateReady:SetHidden(true)
        self:StopUltimateReadyPulse(slot)
    end
end

function addon:UpdateUltimateMeters()
    for _, slot in ipairs(self.skillSlots) do
        self:UpdateUltimateProgress(slot)
    end

    for _, slot in ipairs(self.backbarSlots) do
        self:UpdateUltimateProgress(slot)
    end
end

function addon:UpdateActionSlotStates()
    for _, slot in ipairs(self.skillSlots) do
        self:UpdateSlotUsableState(slot)
    end

    for _, slot in ipairs(self.backbarSlots) do
        self:UpdateSlotUsableState(slot)
    end
end

local function FormatSkillEffectTime(remainingMS)
    local remainingS = remainingMS / 1000
    local decimalThresholdS = addon:GetSettingValue("skillEffectTimeFormat") == "integer" and 0 or SKILL_EFFECT_TIMER_DECIMAL_THRESHOLD_S
    return ZO_FormatTimeShowUnitOverThresholdShowDecimalUnderThreshold(
        remainingS,
        ZO_ONE_MINUTE_IN_SECONDS,
        decimalThresholdS,
        TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT
    )
end

local function GetSkillEffectBorderSegmentProgress(progress, segmentIndex)
    local segmentProgress = (progress * 4) - (segmentIndex - 1)
    if segmentProgress < 0 then
        return 0
    elseif segmentProgress > 1 then
        return 1
    end

    return segmentProgress
end

function addon:UpdateSlotEffectBorder(slot, remainingMS)
    if not slot or not slot.effectBorderParts then
        return
    end

    if not self:GetSettingValue("showSkillEffectBorderAnimation") then
        slot.effectBorder:SetHidden(true)
        return
    end

    local durationMS = tonumber(slot.effectDurationMS) or 0
    local progress = 1
    if durationMS > 0 then
        progress = remainingMS / durationMS
        if progress < 0 then
            progress = 0
        elseif progress > 1 then
            progress = 1
        end
    end

    local size = slot.slotSize or SLOT_SIZE
    for segmentIndex, borderPart in ipairs(slot.effectBorderParts) do
        local segmentProgress = GetSkillEffectBorderSegmentProgress(progress, segmentIndex)
        if segmentProgress > 0 then
            local segmentLength = math.max(1, math.floor((size * segmentProgress) + 0.5))
            if segmentIndex == 1 or segmentIndex == 3 then
                borderPart:SetDimensions(segmentLength, SKILL_EFFECT_BORDER_THICKNESS)
            else
                borderPart:SetDimensions(SKILL_EFFECT_BORDER_THICKNESS, segmentLength)
            end
            borderPart:SetHidden(false)
        else
            borderPart:SetHidden(true)
        end
    end
    slot.effectBorder:SetHidden(false)
end

function addon:ClearSlotEffectTimer(slot)
    if not slot then
        return
    end

    slot.effectEndTimeMS = nil
    slot.effectDurationMS = nil
    if slot.effectTimer then
        slot.effectTimer:SetHidden(true)
    end
    if slot.effectBorder then
        slot.effectBorder:SetHidden(true)
    end
    if slot.effectOverlay then
        slot.effectOverlay:SetHidden(true)
    end
end

function addon:ClearSlotEffectStack(slot)
    if not slot then
        return
    end

    if slot.effectStackCount then
        slot.effectStackCount:SetHidden(true)
    end
    if slot.effectStackBackground then
        slot.effectStackBackground:SetHidden(true)
    end
end

function addon:UpdateAllSkillEffectStacks()
    local function UpdateSlots(slots)
        for _, slot in ipairs(slots) do
            local hotbarCategory = slot.hotbarCategory
            local hasSlot = hotbarCategory ~= nil and GetSlotType(slot.slotIndex, hotbarCategory) ~= ACTION_TYPE_NOTHING
            self:UpdateSlotEffectStack(slot, hasSlot)
        end
    end

    UpdateSlots(self.skillSlots)
    UpdateSlots(self.backbarSlots)
end

function addon:RefreshPlayerEffectStackCache(updateSlots)
    local knownAbilityIds = self.knownStackingEffectAbilityIds or {}
    local knownNames = self.knownStackingEffectNames or {}
    local effectsBySlot = {}

    for buffIndex = 1, GetNumBuffs(PLAYER_UNIT_TAG) do
        local effectName, _, _, effectSlot, stackCount, _, _, _, _, _, abilityId, _, castByPlayer = GetUnitBuffInfo(PLAYER_UNIT_TAG, buffIndex)
        stackCount = tonumber(stackCount) or 0
        abilityId = tonumber(abilityId) or 0

        if castByPlayer and stackCount > 0 then
            if stackCount > 1 then
                if abilityId > 0 then
                    knownAbilityIds[abilityId] = true
                end
                if effectName and effectName ~= "" then
                    knownNames[effectName] = true
                end
            end

            if stackCount > 1 or knownAbilityIds[abilityId] or knownNames[effectName] then
                effectsBySlot[effectSlot] =
                {
                    abilityId = abilityId,
                    name = effectName,
                    stackCount = stackCount,
                }
            end
        end
    end

    self.knownStackingEffectAbilityIds = knownAbilityIds
    self.knownStackingEffectNames = knownNames
    self.playerEffectStacksBySlot = effectsBySlot

    if updateSlots ~= false then
        self:UpdateAllSkillEffectStacks()
    end
end

function addon:HandlePlayerEffectStackChanged(changeType, effectSlot, effectName, stackCount, abilityId, sourceType)
    local effectsBySlot = self.playerEffectStacksBySlot or {}
    local knownAbilityIds = self.knownStackingEffectAbilityIds or {}
    local knownNames = self.knownStackingEffectNames or {}
    stackCount = tonumber(stackCount) or 0
    abilityId = tonumber(abilityId) or 0

    if stackCount > 1 then
        if abilityId > 0 then
            knownAbilityIds[abilityId] = true
        end
        if effectName and effectName ~= "" then
            knownNames[effectName] = true
        end
    end

    local isKnownStackingEffect = stackCount > 1 or knownAbilityIds[abilityId] or knownNames[effectName]
    if changeType ~= EFFECT_RESULT_FADED and stackCount > 0 and isKnownStackingEffect then
        if sourceType == COMBAT_UNIT_TYPE_PLAYER then
            effectsBySlot[effectSlot] =
            {
                abilityId = abilityId,
                name = effectName,
                stackCount = stackCount,
            }
        else
            self.knownStackingEffectAbilityIds = knownAbilityIds
            self.knownStackingEffectNames = knownNames
            self:RefreshPlayerEffectStackCache()
            return
        end
    else
        effectsBySlot[effectSlot] = nil
    end

    self.knownStackingEffectAbilityIds = knownAbilityIds
    self.knownStackingEffectNames = knownNames
    self.playerEffectStacksBySlot = effectsBySlot
    self:UpdateAllSkillEffectStacks()
end

function addon:GetPlayerEffectStackCountForSlot(slot)
    local effectsBySlot = self.playerEffectStacksBySlot
    if not effectsBySlot then
        return 0
    end

    local hotbarCategory = slot.hotbarCategory
    local boundAbilityId = tonumber(GetSlotBoundId(slot.slotIndex, hotbarCategory)) or 0
    local effectiveAbilityId = 0
    if boundAbilityId > 0 then
        effectiveAbilityId = tonumber(GetEffectiveAbilityIdForAbilityOnHotbar(boundAbilityId, hotbarCategory)) or 0
    end

    local slotName = GetSlotName(slot.slotIndex, hotbarCategory)
    local boundAbilityName = boundAbilityId > 0 and GetAbilityName(boundAbilityId, PLAYER_UNIT_TAG) or ""
    local effectiveAbilityName = effectiveAbilityId > 0 and GetAbilityName(effectiveAbilityId, PLAYER_UNIT_TAG) or ""
    local stackCount = 0

    for _, effectData in pairs(effectsBySlot) do
        local abilityIdMatches = effectData.abilityId > 0 and
            (effectData.abilityId == boundAbilityId or effectData.abilityId == effectiveAbilityId)
        local nameMatches = effectData.name and effectData.name ~= "" and
            (effectData.name == slotName or effectData.name == boundAbilityName or effectData.name == effectiveAbilityName)

        if abilityIdMatches or nameMatches then
            stackCount = math.max(stackCount, effectData.stackCount)
        end
    end

    return stackCount
end

function addon:UpdateSlotEffectStack(slot, hasSlot)
    if not slot or not slot.tracksSkillEffect or not slot.effectStackCount or not slot.effectStackBackground then
        return
    end

    local hotbarCategory = slot.hotbarCategory
    if hotbarCategory == nil or not hasSlot then
        self:ClearSlotEffectStack(slot)
        return
    end

    local stackCount = tonumber(GetActionSlotEffectStackCount(slot.slotIndex, hotbarCategory)) or 0
    if stackCount <= 0 then
        stackCount = self:GetPlayerEffectStackCountForSlot(slot)
    end
    if stackCount > 0 then
        slot.effectStackCount:SetText(FormatNumber(stackCount))
        slot.effectStackCount:SetHidden(false)
        slot.effectStackBackground:SetHidden(false)
    else
        self:ClearSlotEffectStack(slot)
    end
end

function addon:SetSkillEffectTimerUpdatesEnabled(enabled)
    if not self.skillSlotContainer or self.skillEffectTimerUpdatesEnabled == enabled then
        return
    end

    self.skillEffectTimerUpdatesEnabled = enabled
    self.nextSkillEffectTimerUpdateMS = nil

    if enabled then
        self.skillSlotContainer:SetHandler("OnUpdate", function()
            local currentTimeMS = GetFrameTimeMilliseconds()
            if addon.nextSkillEffectTimerUpdateMS and currentTimeMS < addon.nextSkillEffectTimerUpdateMS then
                return
            end

            addon.nextSkillEffectTimerUpdateMS = currentTimeMS + SKILL_EFFECT_TIMER_UPDATE_INTERVAL_MS
            addon:UpdateSkillEffectTimerTexts(currentTimeMS)
        end, "SkillEffectTimers")
    else
        self.skillSlotContainer:SetHandler("OnUpdate", nil, "SkillEffectTimers")
    end
end

function addon:UpdateSkillEffectTimerTexts(currentTimeMS)
    currentTimeMS = currentTimeMS or GetFrameTimeMilliseconds()
    local hasActiveTimer = false

    local function UpdateSlots(slots)
        for _, slot in ipairs(slots) do
            if slot.effectEndTimeMS then
                local remainingMS = slot.effectEndTimeMS - currentTimeMS
                if remainingMS > 0 then
                    slot.effectTimer:SetText(FormatSkillEffectTime(remainingMS))
                    self:UpdateSlotEffectBorder(slot, remainingMS)
                    slot.effectTimer:SetHidden(false)
                    slot.effectOverlay:SetHidden(false)
                    hasActiveTimer = true
                else
                    self:ClearSlotEffectTimer(slot)
                end
            end
        end
    end

    UpdateSlots(self.skillSlots)
    UpdateSlots(self.backbarSlots)
    self:SetSkillEffectTimerUpdatesEnabled(hasActiveTimer)
end

function addon:UpdateSlotEffectTimer(slot, slotType, hasSlot)
    if not slot or not slot.tracksSkillEffect or not slot.effectTimer then
        return
    end

    local hotbarCategory = slot.hotbarCategory
    local isAbility = slotType == ACTION_TYPE_ABILITY or slotType == ACTION_TYPE_CRAFTED_ABILITY
    if hotbarCategory == nil or not hasSlot or not isAbility then
        self:ClearSlotEffectTimer(slot)
        return
    end

    local remainingMS = GetActionSlotEffectTimeRemaining(slot.slotIndex, hotbarCategory)
    if remainingMS and remainingMS > 0 then
        slot.effectDurationMS = GetActionSlotEffectDuration(slot.slotIndex, hotbarCategory)
        local currentTimeMS = GetFrameTimeMilliseconds()
        slot.effectEndTimeMS = currentTimeMS + remainingMS
        slot.effectTimer:SetText(FormatSkillEffectTime(remainingMS))
        self:UpdateSlotEffectBorder(slot, remainingMS)
        slot.effectTimer:SetHidden(false)
        slot.effectOverlay:SetHidden(false)
        self:SetSkillEffectTimerUpdatesEnabled(true)
    else
        self:ClearSlotEffectTimer(slot)
    end
end

function addon:UpdateSkillEffectForActionSlot(hotbarCategory, actionSlotIndex)
    local function UpdateSlots(slots)
        for _, slot in ipairs(slots) do
            if slot.hotbarCategory == hotbarCategory and slot.slotIndex == actionSlotIndex then
                local slotType = GetSlotType(slot.slotIndex, slot.hotbarCategory)
                local hasSlot = slotType ~= ACTION_TYPE_NOTHING
                self:UpdateSlotEffectTimer(slot, slotType, hasSlot)
                self:UpdateSlotEffectStack(slot, hasSlot)
            end
        end
    end

    UpdateSlots(self.skillSlots)
    UpdateSlots(self.backbarSlots)
end

function addon:ClearSkillEffectTimers()
    for _, slot in ipairs(self.skillSlots) do
        self:ClearSlotEffectTimer(slot)
        self:ClearSlotEffectStack(slot)
    end

    for _, slot in ipairs(self.backbarSlots) do
        self:ClearSlotEffectTimer(slot)
        self:ClearSlotEffectStack(slot)
    end

    self:SetSkillEffectTimerUpdatesEnabled(false)
end

function addon:UpdateSlot(slot)
    local hotbarCategory = slot.hotbarCategory
    local slotIndex = slot.slotIndex
    local useUltimateFrame = slotIndex == ULTIMATE_SLOT_INDEX and
        hotbarCategory ~= nil and
        IsActiveAbilityHotBarCategory(hotbarCategory)

    SetSlotUltimateFrameEnabled(slot, useUltimateFrame)

    if slot.requiresHotbarCategory and hotbarCategory == nil then
        slot.icon:SetHidden(true)
        slot.count:SetHidden(true)
        slot.active:SetHidden(true)
        slot.cooldown:SetHidden(true)
        self:ClearSlotEffectTimer(slot)
        self:ClearSlotEffectStack(slot)
        if slot.frameTexture then
            slot.frameTexture:SetTexture(TEXTURES.slotFrameEmpty)
        end
        self:UpdateSlotUsableState(slot, ACTION_TYPE_NOTHING, false)
        self:UpdateUltimateProgress(slot, false)
        return
    end

    local slotType = GetSlotType(slotIndex, hotbarCategory)
    local hasSlot = slotType ~= ACTION_TYPE_NOTHING

    slot.icon:SetHidden(true)
    slot.count:SetHidden(true)
    if slot.frameTexture then
        slot.frameTexture:SetTexture(hasSlot and TEXTURES.slotFrame or TEXTURES.slotFrameEmpty)
    end

    if hasSlot then
        local texture = GetSlotTexture(slotIndex, hotbarCategory)
        if texture and texture ~= "" then
            slot.icon:SetTexture(texture)
            slot.icon:SetHidden(false)
        end

        if hotbarCategory == HOTBAR_CATEGORY_QUICKSLOT_WHEEL then
            local count = GetSlotItemCount(slotIndex, hotbarCategory)
            if count and count > 1 then
                slot.count:SetText(FormatNumber(count))
                slot.count:SetHidden(false)
            end
        end
    end

    self:UpdateSlotUsableState(slot, slotType, hasSlot)
    self:UpdateUltimateProgress(slot, hasSlot)

    if hotbarCategory == HOTBAR_CATEGORY_QUICKSLOT_WHEEL then
        local isCurrentQuickslot = slotIndex == GetCurrentQuickslot()
        slot.active:SetHidden(not isCurrentQuickslot)
        slot.frame:SetAlpha(isCurrentQuickslot and 1 or INACTIVE_QUICKSLOT_ALPHA)
        slot.icon:SetDesaturation(isCurrentQuickslot and 0 or INACTIVE_QUICKSLOT_DESATURATION)

        if slot.keybindFrame then
            slot.keybindFrame:SetHidden(not isCurrentQuickslot)
        end
    else
        slot.active:SetHidden(true)
    end

    self:UpdateSlotCooldown(slot)
    self:UpdateSlotEffectTimer(slot, slotType, hasSlot)
    self:UpdateSlotEffectStack(slot, hasSlot)
end

function addon:UpdateSlotCooldown(slot)
    if slot.requiresHotbarCategory and slot.hotbarCategory == nil then
        slot.cooldown:SetHidden(true)
        return
    end

    local remain, duration = GetSlotCooldownInfo(slot.slotIndex, slot.hotbarCategory)

    if duration and duration > 0 and remain and remain > 0 then
        slot.cooldown:SetHidden(false)
        slot.cooldown:StartCooldown(remain, duration, CD_TYPE_RADIAL, nil, NO_LEADING_EDGE)
    else
        slot.cooldown:SetHidden(true)
    end
end

function addon:UpdateActionSlots()
    self:UpdateHotbarCategories()

    for _, slot in ipairs(self.skillSlots) do
        self:UpdateSlot(slot)
    end

    for _, slot in ipairs(self.backbarSlots) do
        self:UpdateSlot(slot)
    end

    self:UpdateWeaponIcons()

    for _, slot in ipairs(self.quickSlots) do
        self:UpdateSlot(slot)
    end
end

function addon:UpdateQuickSlots()
    for _, slot in ipairs(self.quickSlots) do
        self:UpdateSlot(slot)
    end
end

function addon:UpdateCooldowns()
    for _, slot in ipairs(self.skillSlots) do
        self:UpdateSlotCooldown(slot)
    end

    for _, slot in ipairs(self.backbarSlots) do
        self:UpdateSlotCooldown(slot)
    end

    for _, slot in ipairs(self.quickSlots) do
        self:UpdateSlotCooldown(slot)
    end
end

function addon:UpdateEquipmentDisplay()
    self:UpdateHotbarCategories()
    self:UpdateWeaponIcons()
end

function addon:UpdateVisibility()
    if self.root then
        self.root:SetHidden(IsGameCameraUIModeActive() and not self:GetSettingValue("unlockUI"))
    end
end

function addon:RefreshAll()
    self:UpdateAllPowers()
    self:UpdateDamageShield()
    self:UpdateExperience()
    self:RefreshPlayerEffectStackCache(false)
    self:UpdateActionSlots()
    self:UpdateVisibility()
end

function addon:RegisterSettingsPanel()
    if self.settingsPanelRegistered then
        return
    end

    local LAM = LibAddonMenu2
    if not LAM then
        return
    end

    local function GetSetting(key)
        return function()
            return addon:GetSettingValue(key)
        end
    end

    local function SetSetting(key)
        return function(value)
            addon:SetSettingValue(key, value)
        end
    end

    local panelData =
    {
        type = "panel",
        name = "New World UI",
        displayName = "New World UI",
        author = "Wrynch",
        version = "1",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsTable =
    {
        {
            type = "header",
            name = "Layout",
            width = "full",
        },
        {
            type = "checkbox",
            name = "Unlock Layout to Move",
            tooltip = "Enables layout dragging. Use the movement mode below to drag either the whole HUD or each highlighted component.",
            getFunc = GetSetting("unlockUI"),
            setFunc = SetSetting("unlockUI"),
            default = DEFAULT_SETTINGS.unlockUI,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Move Components Individually",
            tooltip = "OFF: drag the whole NWUI HUD as one group. ON: drag the highlighted consumables, individual resource bars, experience line, level badge, and skills separately.",
            getFunc = GetSetting("moveComponentsIndividually"),
            setFunc = SetSetting("moveComponentsIndividually"),
            default = DEFAULT_SETTINGS.moveComponentsIndividually,
            width = "full",
        },
        {
            type = "button",
            name = "Reset Whole UI Position",
            tooltip = "Moves the NWUI HUD group back to the default bottom-center position without changing individual component offsets.",
            func = function()
                addon:ResetRootPosition()
            end,
            width = "full",
        },
        {
            type = "button",
            name = "Reset Component Positions",
            tooltip = "Returns every individually movable component to its default position inside the NWUI HUD group.",
            func = function()
                addon:ResetLayoutComponentPositions()
            end,
            width = "full",
        },
        {
            type = "header",
            name = "Group Scale",
            width = "full",
        },
        {
            type = "slider",
            name = "Overall Scale",
            tooltip = "Scales the whole NWUI HUD.",
            min = SCALE_MIN,
            max = SCALE_MAX,
            step = 0.01,
            decimals = 2,
            getFunc = GetSetting("uiScale"),
            setFunc = SetSetting("uiScale"),
            default = DEFAULT_SETTINGS.uiScale,
            width = "full",
        },
        {
            type = "slider",
            name = "Consumables Scale",
            tooltip = "Scales the quickslot consumables group.",
            min = SCALE_MIN,
            max = SCALE_MAX,
            step = 0.01,
            decimals = 2,
            getFunc = GetSetting("consumablesScale"),
            setFunc = SetSetting("consumablesScale"),
            default = DEFAULT_SETTINGS.consumablesScale,
            width = "full",
        },
        {
            type = "slider",
            name = "Resource Bars Scale",
            tooltip = "Scales the center resource and level group.",
            min = SCALE_MIN,
            max = SCALE_MAX,
            step = 0.01,
            decimals = 2,
            getFunc = GetSetting("resourceScale"),
            setFunc = SetSetting("resourceScale"),
            default = DEFAULT_SETTINGS.resourceScale,
            width = "full",
        },
        {
            type = "slider",
            name = "Skills UI Scale",
            tooltip = "Scales the weapon, skill, backbar, and ultimate group.",
            min = SCALE_MIN,
            max = SCALE_MAX,
            step = 0.01,
            decimals = 2,
            getFunc = GetSetting("skillsScale"),
            setFunc = SetSetting("skillsScale"),
            default = DEFAULT_SETTINGS.skillsScale,
            width = "full",
        },
        {
            type = "header",
            name = "Individual Resource Scale",
            width = "full",
        },
        {
            type = "slider",
            name = "Magicka Bar Scale",
            tooltip = "Scales only the magicka bar. This combines with the Resource Bars Scale and Overall Scale.",
            min = SCALE_MIN,
            max = SCALE_MAX,
            step = 0.01,
            decimals = 2,
            getFunc = GetSetting("magickaScale"),
            setFunc = SetSetting("magickaScale"),
            default = DEFAULT_SETTINGS.magickaScale,
            width = "full",
        },
        {
            type = "slider",
            name = "Stamina Bar Scale",
            tooltip = "Scales only the stamina bar. This combines with the Resource Bars Scale and Overall Scale.",
            min = SCALE_MIN,
            max = SCALE_MAX,
            step = 0.01,
            decimals = 2,
            getFunc = GetSetting("staminaScale"),
            setFunc = SetSetting("staminaScale"),
            default = DEFAULT_SETTINGS.staminaScale,
            width = "full",
        },
        {
            type = "slider",
            name = "Health Bar Scale",
            tooltip = "Scales only the health bar. This combines with the Resource Bars Scale and Overall Scale.",
            min = SCALE_MIN,
            max = SCALE_MAX,
            step = 0.01,
            decimals = 2,
            getFunc = GetSetting("healthScale"),
            setFunc = SetSetting("healthScale"),
            default = DEFAULT_SETTINGS.healthScale,
            width = "full",
        },
        {
            type = "slider",
            name = "Experience Line Scale",
            tooltip = "Scales only the experience line. This combines with the Resource Bars Scale and Overall Scale.",
            min = SCALE_MIN,
            max = SCALE_MAX,
            step = 0.01,
            decimals = 2,
            getFunc = GetSetting("experienceScale"),
            setFunc = SetSetting("experienceScale"),
            default = DEFAULT_SETTINGS.experienceScale,
            width = "full",
        },
        {
            type = "slider",
            name = "Level Badge Scale",
            tooltip = "Scales only the level or Champion Point badge. This combines with the Resource Bars Scale and Overall Scale.",
            min = SCALE_MIN,
            max = SCALE_MAX,
            step = 0.01,
            decimals = 2,
            getFunc = GetSetting("levelBadgeScale"),
            setFunc = SetSetting("levelBadgeScale"),
            default = DEFAULT_SETTINGS.levelBadgeScale,
            width = "full",
        },
        {
            type = "header",
            name = "Resource Bars",
            width = "full",
        },
        {
            type = "slider",
            name = "Bar Width",
            tooltip = "Sets the center resource bar width.",
            min = BAR_WIDTH_MIN,
            max = BAR_WIDTH_MAX,
            step = 1,
            getFunc = GetSetting("barWidth"),
            setFunc = SetSetting("barWidth"),
            default = DEFAULT_SETTINGS.barWidth,
            width = "full",
        },
        {
            type = "slider",
            name = "Magicka/Stamina Height",
            tooltip = "Sets the height of the top resource bars.",
            min = THIN_BAR_HEIGHT_MIN,
            max = THIN_BAR_HEIGHT_MAX,
            step = 1,
            getFunc = GetSetting("thinBarHeight"),
            setFunc = SetSetting("thinBarHeight"),
            default = DEFAULT_SETTINGS.thinBarHeight,
            width = "full",
        },
        {
            type = "slider",
            name = "Health Height",
            tooltip = "Sets the height of the main health bar.",
            min = HEALTH_BAR_HEIGHT_MIN,
            max = HEALTH_BAR_HEIGHT_MAX,
            step = 1,
            getFunc = GetSetting("healthBarHeight"),
            setFunc = SetSetting("healthBarHeight"),
            default = DEFAULT_SETTINGS.healthBarHeight,
            width = "full",
        },
        {
            type = "slider",
            name = "XP Line Height",
            tooltip = "Sets the height of the thin XP progress line.",
            min = EXPERIENCE_BAR_HEIGHT_MIN,
            max = EXPERIENCE_BAR_HEIGHT_MAX,
            step = 1,
            getFunc = GetSetting("experienceBarHeight"),
            setFunc = SetSetting("experienceBarHeight"),
            default = DEFAULT_SETTINGS.experienceBarHeight,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show Magicka/Stamina Numbers",
            tooltip = "Shows numeric values inside the magicka and stamina bars.",
            getFunc = GetSetting("showSecondaryResourceNumbers"),
            setFunc = function(value)
                addon:SetSettingValue("showSecondaryResourceNumbers", value)
                addon:UpdateAllPowers()
            end,
            default = DEFAULT_SETTINGS.showSecondaryResourceNumbers,
            width = "full",
        },
        {
            type = "header",
            name = "Skill Reminders",
            width = "full",
        },
        {
            type = "slider",
            name = "Front Bar Number Scale",
            tooltip = "Scales duration and stack numbers on the active skill bar.",
            min = SKILL_EFFECT_NUMBER_SCALE_MIN,
            max = SKILL_EFFECT_NUMBER_SCALE_MAX,
            step = 0.05,
            decimals = 2,
            getFunc = GetSetting("skillEffectFrontNumberScale"),
            setFunc = SetSetting("skillEffectFrontNumberScale"),
            default = DEFAULT_SETTINGS.skillEffectFrontNumberScale,
            width = "full",
        },
        {
            type = "slider",
            name = "Backbar Number Scale",
            tooltip = "Scales duration and stack numbers on the inactive skill bar.",
            min = SKILL_EFFECT_NUMBER_SCALE_MIN,
            max = SKILL_EFFECT_NUMBER_SCALE_MAX,
            step = 0.05,
            decimals = 2,
            getFunc = GetSetting("skillEffectBackNumberScale"),
            setFunc = SetSetting("skillEffectBackNumberScale"),
            default = DEFAULT_SETTINGS.skillEffectBackNumberScale,
            width = "full",
        },
        {
            type = "dropdown",
            name = "Duration Number Format",
            tooltip = "Float shows tenths below 10 seconds. Integer always shows whole seconds.",
            choices = { "Float", "Integer" },
            choicesValues = { "float", "integer" },
            getFunc = GetSetting("skillEffectTimeFormat"),
            setFunc = SetSetting("skillEffectTimeFormat"),
            default = DEFAULT_SETTINGS.skillEffectTimeFormat,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show Border Animation",
            tooltip = "Shows the border contracting around a skill icon as its effect expires.",
            getFunc = GetSetting("showSkillEffectBorderAnimation"),
            setFunc = SetSetting("showSkillEffectBorderAnimation"),
            default = DEFAULT_SETTINGS.showSkillEffectBorderAnimation,
            width = "full",
        },
        {
            type = "header",
            name = "Combat Effects",
            width = "full",
        },
        {
            type = "checkbox",
            name = "Show Ultimate Shimmer",
            tooltip = "Shows the moving shimmer effect when the active ultimate is ready.",
            getFunc = GetSetting("showUltimateShimmer"),
            setFunc = SetSetting("showUltimateShimmer"),
            default = DEFAULT_SETTINGS.showUltimateShimmer,
            width = "full",
        },
    }

    LAM:RegisterAddonPanel(SETTINGS_PANEL_ID, panelData)
    LAM:RegisterOptionControls(SETTINGS_PANEL_ID, optionsTable)

    self.settingsPanelRegistered = true
end

local function OnPowerUpdate(_, unitTag, _, powerType, current, maxValue)
    if unitTag == PLAYER_UNIT_TAG then
        addon:UpdatePower(powerType, current, maxValue)
    end
end

local function RegisterPowerEvent(eventName, powerType)
    EVENT_MANAGER:RegisterForEvent(eventName, EVENT_POWER_UPDATE, OnPowerUpdate)
    EVENT_MANAGER:AddFilterForEvent(eventName, EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, PLAYER_UNIT_TAG, REGISTER_FILTER_POWER_TYPE, powerType)
end

local function IsPlayerDamageShieldVisual(unitTag, visualType, statType, attributeType, powerType)
    return unitTag == PLAYER_UNIT_TAG and
        visualType == ATTRIBUTE_VISUAL_POWER_SHIELDING and
        statType == STAT_MITIGATION and
        attributeType == ATTRIBUTE_HEALTH and
        powerType == COMBAT_MECHANIC_FLAGS_HEALTH
end

local function OnDamageShieldAdded(_, unitTag, visualType, statType, attributeType, powerType, value, _, sequenceId)
    if IsPlayerDamageShieldVisual(unitTag, visualType, statType, attributeType, powerType) and addon.damageShieldSequenceId == nil then
        addon.damageShieldSequenceId = sequenceId
        addon:UpdateDamageShield(value)
    end
end

local function OnDamageShieldUpdated(_, unitTag, visualType, statType, attributeType, powerType, _, newValue, _, _, sequenceId)
    local mostRecentSequenceId = addon.damageShieldSequenceId
    if IsPlayerDamageShieldVisual(unitTag, visualType, statType, attributeType, powerType) and
        mostRecentSequenceId ~= nil and sequenceId > mostRecentSequenceId then
        addon.damageShieldSequenceId = sequenceId
        addon:UpdateDamageShield(newValue)
    end
end

local function OnDamageShieldRemoved(_, unitTag, visualType, statType, attributeType, powerType, _, _, sequenceId)
    local mostRecentSequenceId = addon.damageShieldSequenceId
    if IsPlayerDamageShieldVisual(unitTag, visualType, statType, attributeType, powerType) and
        mostRecentSequenceId ~= nil and sequenceId > mostRecentSequenceId then
        addon.damageShieldSequenceId = nil
        addon:UpdateDamageShield(0)
    end
end

local function OnPlayerEffectChanged(_, changeType, effectSlot, effectName, unitTag, _, _, stackCount, _, _, _, _, _, _, _, abilityId, sourceType)
    if unitTag == PLAYER_UNIT_TAG then
        addon:HandlePlayerEffectStackChanged(changeType, effectSlot, effectName, stackCount, abilityId, sourceType)
    end
end

function addon:RegisterEvents()
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, function()
        addon:RefreshAll()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Experience", EVENT_EXPERIENCE_UPDATE, function()
        addon:UpdateExperience()
    end)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "Experience", EVENT_EXPERIENCE_UPDATE, REGISTER_FILTER_UNIT_TAG, PLAYER_UNIT_TAG)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Level", EVENT_LEVEL_UPDATE, function()
        addon:UpdateExperience()
    end)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "Level", EVENT_LEVEL_UPDATE, REGISTER_FILTER_UNIT_TAG, PLAYER_UNIT_TAG)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Champion", EVENT_CHAMPION_POINT_UPDATE, function()
        addon:UpdateExperience()
    end)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "Champion", EVENT_CHAMPION_POINT_UPDATE, REGISTER_FILTER_UNIT_TAG, PLAYER_UNIT_TAG)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "HotbarSlot", EVENT_HOTBAR_SLOT_UPDATED, function()
        addon:UpdateActionSlots()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "HotbarSlotState", EVENT_HOTBAR_SLOT_STATE_UPDATED, function()
        addon:UpdateActionSlots()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "ActiveHotbar", EVENT_ACTION_SLOTS_ACTIVE_HOTBAR_UPDATED, function()
        addon:UpdateActionSlots()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "AllHotbars", EVENT_ACTION_SLOTS_ALL_HOTBARS_UPDATED, function()
        addon:UpdateActionSlots()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "WeaponPair", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, function()
        addon:UpdateActionSlots()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Cooldowns", EVENT_ACTION_UPDATE_COOLDOWNS, function()
        addon:UpdateCooldowns()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "SkillEffect", EVENT_ACTION_SLOT_EFFECT_UPDATE, function(_, hotbarCategory, actionSlotIndex)
        addon:UpdateSkillEffectForActionSlot(hotbarCategory, actionSlotIndex)
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "SkillEffectsCleared", EVENT_ACTION_SLOT_EFFECTS_CLEARED, function()
        addon:ClearSkillEffectTimers()
        addon:RefreshPlayerEffectStackCache()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "PlayerEffectStacks", EVENT_EFFECT_CHANGED, OnPlayerEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "PlayerEffectStacks", EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, PLAYER_UNIT_TAG)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "PlayerEffectStacksFull", EVENT_EFFECTS_FULL_UPDATE, function()
        addon:RefreshPlayerEffectStackCache()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "UltimatePower", EVENT_POWER_UPDATE, function()
        addon:UpdateUltimateMeters()
    end)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "UltimatePower", EVENT_POWER_UPDATE, REGISTER_FILTER_UNIT_TAG, PLAYER_UNIT_TAG, REGISTER_FILTER_POWER_TYPE, COMBAT_MECHANIC_FLAGS_ULTIMATE)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "UltimateCost", EVENT_ULTIMATE_ABILITY_COST_CHANGED, function()
        addon:UpdateUltimateMeters()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "ReticleTarget", EVENT_RETICLE_TARGET_CHANGED, function()
        addon:UpdateActionSlotStates()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Quickslot", EVENT_ACTIVE_QUICKSLOT_CHANGED, function()
        addon:UpdateQuickSlots()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "InventoryFull", EVENT_INVENTORY_FULL_UPDATE, function()
        addon:UpdateQuickSlots()
        addon:UpdateEquipmentDisplay()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "InventorySingle", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(_, bagId)
        addon:UpdateQuickSlots()
        if bagId == BAG_WORN then
            addon:UpdateEquipmentDisplay()
        end
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "CameraMode", EVENT_GAME_CAMERA_UI_MODE_CHANGED, function()
        addon:UpdateVisibility()
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "DamageShieldAdded", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, OnDamageShieldAdded)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "DamageShieldAdded", EVENT_UNIT_ATTRIBUTE_VISUAL_ADDED, REGISTER_FILTER_UNIT_TAG, PLAYER_UNIT_TAG)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "DamageShieldUpdated", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, OnDamageShieldUpdated)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "DamageShieldUpdated", EVENT_UNIT_ATTRIBUTE_VISUAL_UPDATED, REGISTER_FILTER_UNIT_TAG, PLAYER_UNIT_TAG)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "DamageShieldRemoved", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, OnDamageShieldRemoved)
    EVENT_MANAGER:AddFilterForEvent(ADDON_NAME .. "DamageShieldRemoved", EVENT_UNIT_ATTRIBUTE_VISUAL_REMOVED, REGISTER_FILTER_UNIT_TAG, PLAYER_UNIT_TAG)

    for _, data in ipairs(RESOURCE_BARS) do
        RegisterPowerEvent(ADDON_NAME .. data.key .. "Power", data.powerType)
    end
end

function addon:Initialize()
    if self.initialized then
        return
    end

    self.initialized = true
    self:InitializeSavedVars()
    self:CreateControls()
    self:ApplySettings()
    self:RegisterSettingsPanel()
    self:RegisterEvents()
    self:RefreshAll()
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    addon:Initialize()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
