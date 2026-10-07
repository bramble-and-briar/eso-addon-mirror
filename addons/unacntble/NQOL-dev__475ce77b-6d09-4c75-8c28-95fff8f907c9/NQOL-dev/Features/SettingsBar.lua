NQOL = NQOL or {}
NQOL.Features = NQOL.Features or {}

local PlayerBars = NQOL.Features.PlayerBars
local Shared = PlayerBars.Shared
local C = PlayerBars.Constants
local COMPANION = PlayerBars.Companion
local Shadow = PlayerBars.Shadow
local defaults = Shared.defaults
local Clamp = NQOL.Util.Clamp
local Round = NQOL.Util.Round
local GetSettings = Shared.GetPlayerSettings
local GetCompanionSettings = Shared.GetCompanionSettings
local GetClassicSettings = Shared.GetClassicSettings
local GetPyramidSettings = Shared.GetPyramidSettings
local GetStackSettings = Shared.GetStackSettings
local GetVerticalSettings = Shared.GetVerticalSettings
local GetRadialSettings = Shared.GetRadialSettings

local function ClearFontCache(name)
    if Shared.ClearFontCache then
        Shared.ClearFontCache(name)
    end
end


function PlayerBars.GetShowNqolPlayerFrame()
    return GetSettings().showNqolPlayerFrame
end

function PlayerBars.SetShowNqolPlayerFrame(value)
    GetSettings().showNqolPlayerFrame = value == true
    NQOL.Features.UI.RefreshOfficialPlayerFrameVisibility()
    PlayerBars.Player.RefreshRuntimeState()
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetPlayerShowOnlyInCombat()
    return GetSettings().showOnlyInCombat
end

function PlayerBars.SetPlayerShowOnlyInCombat(value)
    GetSettings().showOnlyInCombat = value == true
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetPreset()
    return GetSettings().preset
end

function PlayerBars.SetPreset(value)
    if C.VALID_PRESETS[value] then
        GetSettings().preset = value
    else
        GetSettings().preset = C.CLASSIC
    end

    PlayerBars.QueueRefresh()
end

function PlayerBars.GetPresetChoices()
    return C.PRESET_CHOICES
end

function PlayerBars.GetPresetChoiceNames()
    return C.PRESET_CHOICE_NAMES
end

function PlayerBars.GetPresetBarColor(presetKey, colorKey)
    local frameSettings = GetSettings()
    local settings = frameSettings[presetKey] or frameSettings[C.CLASSIC]
    local color = settings.barColors[colorKey]
    return color.r, color.g, color.b, color.a or 1
end

function PlayerBars.SetPresetBarColor(presetKey, colorKey, red, green, blue, alpha)
    local frameSettings = GetSettings()
    local settings = frameSettings[presetKey] or frameSettings[C.CLASSIC]
    settings.barColors[colorKey] = PlayerBars.Group.CopyColorTable({ r = red, g = green, b = blue, a = alpha or 1 })
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetCurrentValueChoices()
    return C.CURRENT_VALUE.CHOICES
end

function PlayerBars.GetCurrentValueChoiceNames()
    return C.CURRENT_VALUE.CHOICE_NAMES
end

function PlayerBars.GetClassicName()
    return C.CLASSIC_NAME
end

function PlayerBars.GetClassicTooltip()
    return NQOL.L("features.settings_bar.classic_tooltip")
end

function PlayerBars.GetPyramidName()
    return C.PYRAMID_NAME
end

function PlayerBars.GetPyramidTooltip()
    return NQOL.L("features.settings_bar.pyramid_tooltip")
end

function PlayerBars.GetStackName()
    return C.STACK_NAME
end

function PlayerBars.GetStackTooltip()
    return NQOL.L("features.settings_bar.stack_tooltip")
end

function PlayerBars.GetVerticalName()
    return C.VERTICAL_NAME
end

function PlayerBars.GetVerticalTooltip()
    return NQOL.L("features.settings_bar.vertical_tooltip")
end

function PlayerBars.GetRadialName()
    return C.RADIAL_NAME
end

function PlayerBars.GetRadialTooltip()
    return NQOL.L("features.settings_bar.radial_tooltip")
end

local function SetRadialSide(key, value)
    GetRadialSettings()[key] = value == C.FLYING_ORIENTATION_RIGHT and C.FLYING_ORIENTATION_RIGHT or C.FLYING_ORIENTATION_LEFT
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetRadialHealthSideLabel() return NQOL.L("features.settings_bar.radial_health_side_label") end
function PlayerBars.GetRadialHealthSideTooltip() return NQOL.L("features.settings_bar.radial_health_side_tooltip") end
function PlayerBars.GetRadialHealthSide() return GetRadialSettings().healthSide end
function PlayerBars.SetRadialHealthSide(value) SetRadialSide("healthSide", value) end
function PlayerBars.GetRadialMagickaSideLabel() return NQOL.L("features.settings_bar.radial_magicka_side_label") end
function PlayerBars.GetRadialMagickaSideTooltip() return NQOL.L("features.settings_bar.radial_magicka_side_tooltip") end
function PlayerBars.GetRadialMagickaSide() return GetRadialSettings().magickaSide end
function PlayerBars.SetRadialMagickaSide(value) SetRadialSide("magickaSide", value) end
function PlayerBars.GetRadialStaminaSideLabel() return NQOL.L("features.settings_bar.radial_stamina_side_label") end
function PlayerBars.GetRadialStaminaSideTooltip() return NQOL.L("features.settings_bar.radial_stamina_side_tooltip") end
function PlayerBars.GetRadialStaminaSide() return GetRadialSettings().staminaSide end
function PlayerBars.SetRadialStaminaSide(value) SetRadialSide("staminaSide", value) end
function PlayerBars.GetRadialStackLabel() return NQOL.L("features.settings_bar.radial_stack_label") end
function PlayerBars.GetRadialStackTooltip() return NQOL.L("features.settings_bar.radial_stack_tooltip") end
function PlayerBars.GetRadialStackChoices() return C.RADIAL_STACK_CHOICES end
function PlayerBars.GetRadialStackChoiceNames() return C.RADIAL_STACK_CHOICE_NAMES end
function PlayerBars.GetRadialStack() return GetRadialSettings().stack end
function PlayerBars.SetRadialStack(value)
    GetRadialSettings().stack = C.RADIAL_STACK_VALID[value] and value or C.RADIAL_STACK_NOTHING
    PlayerBars.QueueRefresh()
end
function PlayerBars.GetRadialStackTypeLabel() return NQOL.L("features.settings_bar.radial_stack_type_label") end
function PlayerBars.GetRadialStackTypeTooltip() return NQOL.L("features.settings_bar.radial_stack_type_tooltip") end
function PlayerBars.GetRadialStackTypeChoices() return C.RADIAL_STACK_TYPE_CHOICES end
function PlayerBars.GetRadialStackTypeChoiceNames() return C.RADIAL_STACK_TYPE_CHOICE_NAMES end
function PlayerBars.GetRadialStackType() return GetRadialSettings().stackType end
function PlayerBars.SetRadialStackType(value)
    GetRadialSettings().stackType = C.RADIAL_STACK_TYPE_VALID[value] and value or C.RADIAL_STACK_TYPE_EQUAL
    PlayerBars.QueueRefresh()
end
function PlayerBars.GetRadialStackPositionLabel() return NQOL.L("features.settings_bar.radial_stack_position_label") end
function PlayerBars.GetRadialStackPositionTooltip() return NQOL.L("features.settings_bar.radial_stack_position_tooltip") end
function PlayerBars.GetRadialStackPosition() return GetRadialSettings().stackPosition end
function PlayerBars.SetRadialStackPosition(value) SetRadialSide("stackPosition", value) end
function PlayerBars.IsRadialStacked() return GetRadialSettings().stack ~= C.RADIAL_STACK_NOTHING end
function PlayerBars.IsRadialNotStacked() return not PlayerBars.IsRadialStacked() end
function PlayerBars.GetRadialHorizontalPosition()
    return GetRadialSettings().horizontalPosition
end

function PlayerBars.SetRadialHorizontalPosition(value)
    GetRadialSettings().horizontalPosition = Clamp(value, 0, 100)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetRadialVerticalPosition()
    return GetRadialSettings().verticalPosition
end

function PlayerBars.SetRadialVerticalPosition(value)
    GetRadialSettings().verticalPosition = Clamp(value, 0, 100)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetRadialScale() return GetRadialSettings().scale end
function PlayerBars.SetRadialScale(value)
    GetRadialSettings().scale = Clamp(Round(value), C.RADIAL_SCALE_MIN, C.RADIAL_SCALE_MAX)
    PlayerBars.QueueRefresh()
end
function PlayerBars.GetRadialScaleMin() return C.RADIAL_SCALE_MIN end
function PlayerBars.GetRadialScaleMax() return C.RADIAL_SCALE_MAX end

function PlayerBars.GetRadialBorderSizeLabel()
    return NQOL.L("features.settings_bar.radial_border_size_label")
end

function PlayerBars.GetRadialBorderSizeTooltip()
    return NQOL.L("features.settings_bar.radial_border_size_tooltip")
end

function PlayerBars.GetRadialBorderSize()
    return GetRadialSettings().borderSize
end

function PlayerBars.SetRadialBorderSize(value)
    GetRadialSettings().borderSize = Clamp(Round(value), C.CLASSIC_BORDER_SIZE_MIN, C.CLASSIC_BORDER_SIZE_MAX)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetRadialBorderSizeMin()
    return C.CLASSIC_BORDER_SIZE_MIN
end

function PlayerBars.GetRadialBorderSizeMax()
    return C.CLASSIC_BORDER_SIZE_MAX
end

function PlayerBars.GetRadialFontChoices() return NQOL.Util.GetFontChoices() end
function PlayerBars.GetRadialFontChoiceNames() return NQOL.Util.GetFontChoiceNames() end
function PlayerBars.GetRadialFont() return GetRadialSettings().font end
function PlayerBars.SetRadialFont(value)
    GetRadialSettings().font = NQOL.Util.IsFontChoice(value) and value or NQOL.Util.GetDefaultFont()
    PlayerBars.QueueRefresh()
end
function PlayerBars.GetRadialFontSize() return GetRadialSettings().fontSize end
function PlayerBars.SetRadialFontSize(value)
    GetRadialSettings().fontSize = Clamp(Round(value), C.CLASSIC_FONT_SIZE_MIN, C.CLASSIC_FONT_SIZE_MAX)
    PlayerBars.QueueRefresh()
end
function PlayerBars.GetRadialFontSizeMin() return C.CLASSIC_FONT_SIZE_MIN end
function PlayerBars.GetRadialFontSizeMax() return C.CLASSIC_FONT_SIZE_MAX end
function PlayerBars.GetRadialCurrentValue() return GetRadialSettings().currentValue end
function PlayerBars.SetRadialCurrentValue(value)
    GetRadialSettings().currentValue = value == C.CURRENT_VALUE.PERCENTAGE and value or C.CURRENT_VALUE.NUMBER
    PlayerBars.QueueRefresh()
end
function PlayerBars.GetRadialFlyingPositiveAnimation()
    return GetRadialSettings().flyingPositiveAnimation
end
function PlayerBars.SetRadialFlyingPositiveAnimation(value)
    GetRadialSettings().flyingPositiveAnimation = value == true
    if value ~= true then
        PlayerBars.Player.HidePresetChangeLabels(C.RADIAL)
    end
end
function PlayerBars.GetRadialFlyingNegativeAnimation()
    return GetRadialSettings().flyingNegativeAnimation
end
function PlayerBars.SetRadialFlyingNegativeAnimation(value)
    GetRadialSettings().flyingNegativeAnimation = value == true
    if value ~= true then
        PlayerBars.Player.HidePresetChangeLabels(C.RADIAL)
    end
end
function PlayerBars.GetRadialFlyingAnimationFontChoices() return NQOL.Util.GetFontChoices() end
function PlayerBars.GetRadialFlyingAnimationFontChoiceNames() return NQOL.Util.GetFontChoiceNames() end
function PlayerBars.GetRadialFlyingAnimationFont() return GetRadialSettings().flyingAnimationFont end
function PlayerBars.SetRadialFlyingAnimationFont(value)
    GetRadialSettings().flyingAnimationFont = NQOL.Util.IsFontChoice(value) and value or NQOL.Util.GetDefaultFont()
    ClearFontCache("radialChange")
    PlayerBars.QueueRefresh()
end
function PlayerBars.GetRadialFlyingAnimationFontSize() return GetRadialSettings().flyingAnimationFontSize end
function PlayerBars.SetRadialFlyingAnimationFontSize(value)
    GetRadialSettings().flyingAnimationFontSize = Clamp(Round(value), C.CLASSIC_FLYING_FONT_SIZE_MIN, C.CLASSIC_FLYING_FONT_SIZE_MAX)
    ClearFontCache("radialChange")
    PlayerBars.QueueRefresh()
end
function PlayerBars.GetRadialFlyingAnimationFontSizeMin() return C.CLASSIC_FLYING_FONT_SIZE_MIN end
function PlayerBars.GetRadialFlyingAnimationFontSizeMax() return C.CLASSIC_FLYING_FONT_SIZE_MAX end
function PlayerBars.GetRadialSmoothTransitions() return GetRadialSettings().smoothTransitions == true end
function PlayerBars.SetRadialSmoothTransitions(value)
    GetRadialSettings().smoothTransitions = value == true
    if value ~= true and PlayerBars.Smooth then PlayerBars.Smooth.ResetAll() end
    PlayerBars.QueueRefresh()
end
function PlayerBars.GetRadialTransitionShadow() return GetRadialSettings().transitionShadow == true end
function PlayerBars.SetRadialTransitionShadow(value)
    GetRadialSettings().transitionShadow = value == true
    PlayerBars.QueueRefresh()
end
function PlayerBars.GetRadialShadow() return GetRadialSettings().shadow end
function PlayerBars.SetRadialShadow(value)
    GetRadialSettings().shadow = Shadow.VALID[value] and value or Shadow.NONE
    PlayerBars.QueueRefresh()
end
function PlayerBars.GetRadialShadowIntensity() return GetRadialSettings().shadowIntensity end
function PlayerBars.GetRadialShadowIntensityDefault() return defaults.ui.customFrames.playerFrame.radial.shadowIntensity end
function PlayerBars.SetRadialShadowIntensity(value)
    GetRadialSettings().shadowIntensity = Clamp(Round(value), Shadow.INTENSITY_MIN, Shadow.INTENSITY_MAX)
    PlayerBars.QueueRefresh()
end

function PlayerBars.IsClassicSelected()
    return GetSettings().preset == C.CLASSIC
end

function PlayerBars.GetClassicBoxHeight()
    return GetClassicSettings().boxHeight
end

function PlayerBars.SetClassicBoxHeight(value)
    GetClassicSettings().boxHeight = Clamp(Round(value), 10, 80)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetClassicSeparation()
    return GetClassicSettings().separation
end

function PlayerBars.SetClassicSeparation(value)
    GetClassicSettings().separation = Clamp(Round(value), 0, 160)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetClassicHealthWidth()
    return GetClassicSettings().healthWidth
end

function PlayerBars.SetClassicHealthWidth(value)
    GetClassicSettings().healthWidth = Clamp(Round(value), 80, 600)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetClassicMagickaWidth()
    return GetClassicSettings().magickaWidth
end

function PlayerBars.SetClassicMagickaWidth(value)
    GetClassicSettings().magickaWidth = Clamp(Round(value), 80, 600)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetClassicStaminaWidth()
    return GetClassicSettings().staminaWidth
end

function PlayerBars.SetClassicStaminaWidth(value)
    GetClassicSettings().staminaWidth = Clamp(Round(value), 80, 600)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetClassicBorderSize()
    return GetClassicSettings().borderSize
end

function PlayerBars.SetClassicBorderSize(value)
    GetClassicSettings().borderSize = Clamp(Round(value), C.CLASSIC_BORDER_SIZE_MIN, C.CLASSIC_BORDER_SIZE_MAX)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetClassicBorderSizeMin()
    return C.CLASSIC_BORDER_SIZE_MIN
end

function PlayerBars.GetClassicBorderSizeMax()
    return C.CLASSIC_BORDER_SIZE_MAX
end

function PlayerBars.GetShadowChoices()
    return Shadow.CHOICES
end

function PlayerBars.GetShadowChoiceNames()
    return Shadow.CHOICE_NAMES
end

function PlayerBars.GetShadowIntensityMin()
    return Shadow.INTENSITY_MIN
end

function PlayerBars.GetShadowIntensityMax()
    return Shadow.INTENSITY_MAX
end

function PlayerBars.GetClassicShadow()
    return GetClassicSettings().shadow
end

function PlayerBars.SetClassicShadow(value)
    if not Shadow.VALID[value] then
        value = Shadow.NONE
    end

    GetClassicSettings().shadow = value
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetClassicShadowIntensity()
    return GetClassicSettings().shadowIntensity
end

function PlayerBars.GetClassicShadowIntensityDefault()
    return defaults.ui.customFrames.playerFrame.classic.shadowIntensity
end

function PlayerBars.SetClassicShadowIntensity(value)
    GetClassicSettings().shadowIntensity = Clamp(Round(value), Shadow.INTENSITY_MIN, Shadow.INTENSITY_MAX)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetPyramidShadow()
    return GetPyramidSettings().shadow
end

function PlayerBars.SetPyramidShadow(value)
    if not Shadow.VALID[value] then
        value = Shadow.NONE
    end

    GetPyramidSettings().shadow = value
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetPyramidShadowIntensity()
    return GetPyramidSettings().shadowIntensity
end

function PlayerBars.GetPyramidShadowIntensityDefault()
    return defaults.ui.customFrames.playerFrame.pyramid.shadowIntensity
end

function PlayerBars.SetPyramidShadowIntensity(value)
    GetPyramidSettings().shadowIntensity = Clamp(Round(value), Shadow.INTENSITY_MIN, Shadow.INTENSITY_MAX)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetStackShadow()
    return GetStackSettings().shadow
end

function PlayerBars.SetStackShadow(value)
    if not Shadow.VALID[value] then
        value = Shadow.NONE
    end

    GetStackSettings().shadow = value
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetStackShadowIntensity()
    return GetStackSettings().shadowIntensity
end

function PlayerBars.GetStackShadowIntensityDefault()
    return defaults.ui.customFrames.playerFrame.stack.shadowIntensity
end

function PlayerBars.SetStackShadowIntensity(value)
    GetStackSettings().shadowIntensity = Clamp(Round(value), Shadow.INTENSITY_MIN, Shadow.INTENSITY_MAX)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetVerticalShadow()
    return GetVerticalSettings().shadow
end

function PlayerBars.SetVerticalShadow(value)
    if not Shadow.VALID[value] then
        value = Shadow.NONE
    end

    GetVerticalSettings().shadow = value
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetVerticalShadowIntensity()
    return GetVerticalSettings().shadowIntensity
end

function PlayerBars.SetVerticalShadowIntensity(value)
    GetVerticalSettings().shadowIntensity = Clamp(Round(value), Shadow.INTENSITY_MIN, Shadow.INTENSITY_MAX)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetClassicFontChoices()
    return NQOL.Util.GetFontChoices()
end

function PlayerBars.GetClassicFontChoiceNames()
    return NQOL.Util.GetFontChoiceNames()
end

function PlayerBars.GetClassicFont()
    return GetClassicSettings().font
end

function PlayerBars.SetClassicFont(value)
    if not NQOL.Util.IsFontChoice(value) then
        value = NQOL.Util.GetDefaultFont()
    end

    GetClassicSettings().font = value
    ClearFontCache("classic")
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetClassicFontSize()
    return GetClassicSettings().fontSize
end

function PlayerBars.SetClassicFontSize(value)
    GetClassicSettings().fontSize = Clamp(Round(value), C.CLASSIC_FONT_SIZE_MIN, C.CLASSIC_FONT_SIZE_MAX)
    ClearFontCache("classic")
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetClassicFontSizeMin()
    return C.CLASSIC_FONT_SIZE_MIN
end

function PlayerBars.GetClassicFontSizeMax()
    return C.CLASSIC_FONT_SIZE_MAX
end

local function SetCurrentValueMode(settings, value)
    if value ~= C.CURRENT_VALUE.PERCENTAGE then
        value = C.CURRENT_VALUE.NUMBER
    end

    settings.currentValue = value
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetClassicCurrentValue()
    return GetClassicSettings().currentValue
end

function PlayerBars.SetClassicCurrentValue(value)
    SetCurrentValueMode(GetClassicSettings(), value)
end

function PlayerBars.GetClassicFlyingPositiveAnimation()
    return GetClassicSettings().flyingPositiveAnimation
end

function PlayerBars.SetClassicFlyingPositiveAnimation(value)
    GetClassicSettings().flyingPositiveAnimation = value == true
    if value ~= true then
        PlayerBars.Player.HidePresetChangeLabels(C.CLASSIC)
    end
end

function PlayerBars.GetClassicFlyingNegativeAnimation()
    return GetClassicSettings().flyingNegativeAnimation
end

function PlayerBars.SetClassicFlyingNegativeAnimation(value)
    GetClassicSettings().flyingNegativeAnimation = value == true
    if value ~= true then
        PlayerBars.Player.HidePresetChangeLabels(C.CLASSIC)
    end
end

function PlayerBars.GetClassicFlyingAnimationFontChoices()
    return NQOL.Util.GetFontChoices()
end

function PlayerBars.GetClassicFlyingAnimationFontChoiceNames()
    return NQOL.Util.GetFontChoiceNames()
end

function PlayerBars.GetClassicFlyingAnimationFont()
    return GetClassicSettings().flyingAnimationFont
end

function PlayerBars.SetClassicFlyingAnimationFont(value)
    if not NQOL.Util.IsFontChoice(value) then
        value = NQOL.Util.GetDefaultFont()
    end

    GetClassicSettings().flyingAnimationFont = value
    ClearFontCache("classicChange")
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetClassicFlyingAnimationFontSize()
    return GetClassicSettings().flyingAnimationFontSize
end

function PlayerBars.SetClassicFlyingAnimationFontSize(value)
    GetClassicSettings().flyingAnimationFontSize = Clamp(Round(value), C.CLASSIC_FLYING_FONT_SIZE_MIN, C.CLASSIC_FLYING_FONT_SIZE_MAX)
    ClearFontCache("classicChange")
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetClassicFlyingAnimationFontSizeMin()
    return C.CLASSIC_FLYING_FONT_SIZE_MIN
end

function PlayerBars.GetClassicFlyingAnimationFontSizeMax()
    return C.CLASSIC_FLYING_FONT_SIZE_MAX
end

function PlayerBars.GetPyramidFlyingPositiveAnimation()
    return GetPyramidSettings().flyingPositiveAnimation
end

function PlayerBars.SetPyramidFlyingPositiveAnimation(value)
    GetPyramidSettings().flyingPositiveAnimation = value == true
    if value ~= true then
        PlayerBars.Player.HidePresetChangeLabels(C.PYRAMID)
    end
end

function PlayerBars.GetPyramidFlyingNegativeAnimation()
    return GetPyramidSettings().flyingNegativeAnimation
end

function PlayerBars.SetPyramidFlyingNegativeAnimation(value)
    GetPyramidSettings().flyingNegativeAnimation = value == true
    if value ~= true then
        PlayerBars.Player.HidePresetChangeLabels(C.PYRAMID)
    end
end

function PlayerBars.GetPyramidFlyingAnimationFontChoices()
    return NQOL.Util.GetFontChoices()
end

function PlayerBars.GetPyramidFlyingAnimationFontChoiceNames()
    return NQOL.Util.GetFontChoiceNames()
end

function PlayerBars.GetPyramidFlyingAnimationFont()
    return GetPyramidSettings().flyingAnimationFont
end

function PlayerBars.SetPyramidFlyingAnimationFont(value)
    if not NQOL.Util.IsFontChoice(value) then
        value = NQOL.Util.GetDefaultFont()
    end

    GetPyramidSettings().flyingAnimationFont = value
    ClearFontCache("pyramidChange")
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetPyramidFlyingAnimationFontSize()
    return GetPyramidSettings().flyingAnimationFontSize
end

function PlayerBars.SetPyramidFlyingAnimationFontSize(value)
    GetPyramidSettings().flyingAnimationFontSize = Clamp(Round(value), C.CLASSIC_FLYING_FONT_SIZE_MIN, C.CLASSIC_FLYING_FONT_SIZE_MAX)
    ClearFontCache("pyramidChange")
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetPyramidFlyingAnimationFontSizeMin()
    return C.CLASSIC_FLYING_FONT_SIZE_MIN
end

function PlayerBars.GetPyramidFlyingAnimationFontSizeMax()
    return C.CLASSIC_FLYING_FONT_SIZE_MAX
end

function PlayerBars.IsPyramidSelected()
    return GetSettings().preset == C.PYRAMID
end

function PlayerBars.GetStackFlyingPositiveAnimation()
    return GetStackSettings().flyingPositiveAnimation
end

function PlayerBars.SetStackFlyingPositiveAnimation(value)
    GetStackSettings().flyingPositiveAnimation = value == true
    if value ~= true then
        PlayerBars.Player.HidePresetChangeLabels(C.STACK)
    end
end

function PlayerBars.GetStackFlyingNegativeAnimation()
    return GetStackSettings().flyingNegativeAnimation
end

function PlayerBars.SetStackFlyingNegativeAnimation(value)
    GetStackSettings().flyingNegativeAnimation = value == true
    if value ~= true then
        PlayerBars.Player.HidePresetChangeLabels(C.STACK)
    end
end

function PlayerBars.GetStackFlyingOrientation()
    local value = GetStackSettings().flyingOrientation
    if value == C.FLYING_ORIENTATION_RIGHT then
        return C.FLYING_ORIENTATION_RIGHT
    end

    return C.FLYING_ORIENTATION_LEFT
end

function PlayerBars.SetStackFlyingOrientation(value)
    if value ~= C.FLYING_ORIENTATION_RIGHT then
        value = C.FLYING_ORIENTATION_LEFT
    end

    GetStackSettings().flyingOrientation = value
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetStackFlyingAnimationFontChoices()
    return NQOL.Util.GetFontChoices()
end

function PlayerBars.GetStackFlyingAnimationFontChoiceNames()
    return NQOL.Util.GetFontChoiceNames()
end

function PlayerBars.GetStackFlyingAnimationFont()
    return GetStackSettings().flyingAnimationFont
end

function PlayerBars.SetStackFlyingAnimationFont(value)
    if not NQOL.Util.IsFontChoice(value) then
        value = NQOL.Util.GetDefaultFont()
    end

    GetStackSettings().flyingAnimationFont = value
    ClearFontCache("stackChange")
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetStackFlyingAnimationFontSize()
    return GetStackSettings().flyingAnimationFontSize
end

function PlayerBars.SetStackFlyingAnimationFontSize(value)
    GetStackSettings().flyingAnimationFontSize = Clamp(Round(value), C.CLASSIC_FLYING_FONT_SIZE_MIN, C.CLASSIC_FLYING_FONT_SIZE_MAX)
    ClearFontCache("stackChange")
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetStackFlyingAnimationFontSizeMin()
    return C.CLASSIC_FLYING_FONT_SIZE_MIN
end

function PlayerBars.GetStackFlyingAnimationFontSizeMax()
    return C.CLASSIC_FLYING_FONT_SIZE_MAX
end

function PlayerBars.IsStackSelected()
    return GetSettings().preset == C.STACK
end

function PlayerBars.GetVerticalFlyingPositiveAnimation()
    return GetVerticalSettings().flyingPositiveAnimation
end

function PlayerBars.SetVerticalFlyingPositiveAnimation(value)
    GetVerticalSettings().flyingPositiveAnimation = value == true
    if value ~= true then
        PlayerBars.Player.HidePresetChangeLabels(C.VERTICAL)
    end
end

function PlayerBars.GetVerticalFlyingNegativeAnimation()
    return GetVerticalSettings().flyingNegativeAnimation
end

function PlayerBars.SetVerticalFlyingNegativeAnimation(value)
    GetVerticalSettings().flyingNegativeAnimation = value == true
    if value ~= true then
        PlayerBars.Player.HidePresetChangeLabels(C.VERTICAL)
    end
end

function PlayerBars.GetVerticalFlyingAnimationFontChoices()
    return NQOL.Util.GetFontChoices()
end

function PlayerBars.GetVerticalFlyingAnimationFontChoiceNames()
    return NQOL.Util.GetFontChoiceNames()
end

function PlayerBars.GetVerticalFlyingAnimationFont()
    return GetVerticalSettings().flyingAnimationFont
end

function PlayerBars.SetVerticalFlyingAnimationFont(value)
    if not NQOL.Util.IsFontChoice(value) then
        value = NQOL.Util.GetDefaultFont()
    end

    GetVerticalSettings().flyingAnimationFont = value
    ClearFontCache("verticalChange")
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetVerticalFlyingAnimationFontSize()
    return GetVerticalSettings().flyingAnimationFontSize
end

function PlayerBars.SetVerticalFlyingAnimationFontSize(value)
    GetVerticalSettings().flyingAnimationFontSize = Clamp(Round(value), C.CLASSIC_FLYING_FONT_SIZE_MIN, C.CLASSIC_FLYING_FONT_SIZE_MAX)
    ClearFontCache("verticalChange")
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetVerticalFlyingAnimationFontSizeMin()
    return C.CLASSIC_FLYING_FONT_SIZE_MIN
end

function PlayerBars.GetVerticalFlyingAnimationFontSizeMax()
    return C.CLASSIC_FLYING_FONT_SIZE_MAX
end

function PlayerBars.IsVerticalSelected()
    return GetSettings().preset == C.VERTICAL
end

function PlayerBars.GetPyramidHealthHeight()
    return GetPyramidSettings().healthHeight
end

function PlayerBars.SetPyramidHealthHeight(value)
    GetPyramidSettings().healthHeight = Clamp(Round(value), 10, 80)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetPyramidResourceHeight()
    return GetPyramidSettings().resourceHeight
end

function PlayerBars.SetPyramidResourceHeight(value)
    GetPyramidSettings().resourceHeight = Clamp(Round(value), 10, 80)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetPyramidHealthWidth()
    return GetPyramidSettings().healthWidth
end

function PlayerBars.SetPyramidHealthWidth(value)
    GetPyramidSettings().healthWidth = Clamp(Round(value), 80, 600)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetPyramidMagickaWidth()
    return GetPyramidSettings().magickaWidth
end

function PlayerBars.SetPyramidMagickaWidth(value)
    GetPyramidSettings().magickaWidth = Clamp(Round(value), 80, 600)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetPyramidStaminaWidth()
    return GetPyramidSettings().staminaWidth
end

function PlayerBars.SetPyramidStaminaWidth(value)
    GetPyramidSettings().staminaWidth = Clamp(Round(value), 80, 600)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetPyramidBorderSize()
    return GetPyramidSettings().borderSize
end

function PlayerBars.SetPyramidBorderSize(value)
    GetPyramidSettings().borderSize = Clamp(Round(value), C.CLASSIC_BORDER_SIZE_MIN, C.CLASSIC_BORDER_SIZE_MAX)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetPyramidBorderSizeMin()
    return C.CLASSIC_BORDER_SIZE_MIN
end

function PlayerBars.GetPyramidBorderSizeMax()
    return C.CLASSIC_BORDER_SIZE_MAX
end

function PlayerBars.GetPyramidFontChoices()
    return NQOL.Util.GetFontChoices()
end

function PlayerBars.GetPyramidFontChoiceNames()
    return NQOL.Util.GetFontChoiceNames()
end

function PlayerBars.GetPyramidFont()
    return GetPyramidSettings().font
end

function PlayerBars.SetPyramidFont(value)
    if not NQOL.Util.IsFontChoice(value) then
        value = NQOL.Util.GetDefaultFont()
    end

    GetPyramidSettings().font = value
    ClearFontCache("pyramid")
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetPyramidFontSize()
    return GetPyramidSettings().fontSize
end

function PlayerBars.SetPyramidFontSize(value)
    GetPyramidSettings().fontSize = Clamp(Round(value), C.CLASSIC_FONT_SIZE_MIN, C.CLASSIC_FONT_SIZE_MAX)
    ClearFontCache("pyramid")
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetPyramidFontSizeMin()
    return C.CLASSIC_FONT_SIZE_MIN
end

function PlayerBars.GetPyramidFontSizeMax()
    return C.CLASSIC_FONT_SIZE_MAX
end

function PlayerBars.GetPyramidCurrentValue()
    return GetPyramidSettings().currentValue
end

function PlayerBars.SetPyramidCurrentValue(value)
    SetCurrentValueMode(GetPyramidSettings(), value)
end

function PlayerBars.GetStackHealthHeight()
    return GetStackSettings().healthHeight
end

function PlayerBars.SetStackHealthHeight(value)
    GetStackSettings().healthHeight = Clamp(Round(value), 10, 80)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetStackMagickaHeight()
    return GetStackSettings().magickaHeight
end

function PlayerBars.SetStackMagickaHeight(value)
    GetStackSettings().magickaHeight = Clamp(Round(value), 10, 80)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetStackStaminaHeight()
    return GetStackSettings().staminaHeight
end

function PlayerBars.SetStackStaminaHeight(value)
    GetStackSettings().staminaHeight = Clamp(Round(value), 10, 80)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetStackWidth()
    return GetStackSettings().width
end

function PlayerBars.SetStackWidth(value)
    GetStackSettings().width = Clamp(Round(value), 80, 600)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetStackBorderSize()
    return GetStackSettings().borderSize
end

function PlayerBars.SetStackBorderSize(value)
    GetStackSettings().borderSize = Clamp(Round(value), C.CLASSIC_BORDER_SIZE_MIN, C.CLASSIC_BORDER_SIZE_MAX)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetStackBorderSizeMin()
    return C.CLASSIC_BORDER_SIZE_MIN
end

function PlayerBars.GetStackBorderSizeMax()
    return C.CLASSIC_BORDER_SIZE_MAX
end

function PlayerBars.GetStackFontChoices()
    return NQOL.Util.GetFontChoices()
end

function PlayerBars.GetStackFontChoiceNames()
    return NQOL.Util.GetFontChoiceNames()
end

function PlayerBars.GetStackFont()
    return GetStackSettings().font
end

function PlayerBars.SetStackFont(value)
    if not NQOL.Util.IsFontChoice(value) then
        value = NQOL.Util.GetDefaultFont()
    end

    GetStackSettings().font = value
    ClearFontCache("stack")
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetStackFontSize()
    return GetStackSettings().fontSize
end

function PlayerBars.SetStackFontSize(value)
    GetStackSettings().fontSize = Clamp(Round(value), C.CLASSIC_FONT_SIZE_MIN, C.CLASSIC_FONT_SIZE_MAX)
    ClearFontCache("stack")
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetStackFontSizeMin()
    return C.CLASSIC_FONT_SIZE_MIN
end

function PlayerBars.GetStackFontSizeMax()
    return C.CLASSIC_FONT_SIZE_MAX
end

function PlayerBars.GetStackCurrentValue()
    return GetStackSettings().currentValue
end

function PlayerBars.SetStackCurrentValue(value)
    SetCurrentValueMode(GetStackSettings(), value)
end

function PlayerBars.GetStackReverse()
    return GetStackSettings().reverse
end

function PlayerBars.SetStackReverse(value)
    GetStackSettings().reverse = value == true
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetVerticalNumber(settingName)
    return GetVerticalSettings()[settingName]
end

function PlayerBars.SetVerticalNumber(settingName, value, minValue, maxValue)
    GetVerticalSettings()[settingName] = Clamp(Round(value), minValue, maxValue)
    PlayerBars.QueueRefresh()
end

function PlayerBars.SetVerticalPositionNumber(settingName, value, minValue, maxValue)
    GetVerticalSettings()[settingName] = Clamp(value, minValue, maxValue)
    PlayerBars.QueueRefresh()
end

function PlayerBars.SetVerticalFlyingOrientation(settingName, value)
    if value ~= C.FLYING_ORIENTATION_RIGHT then
        value = C.FLYING_ORIENTATION_LEFT
    end

    GetVerticalSettings()[settingName] = value
    PlayerBars.QueueRefresh()
end

function PlayerBars.SetVerticalCurrentValue(settingName, value)
    if value ~= C.CURRENT_VALUE.PERCENTAGE then
        value = C.CURRENT_VALUE.NUMBER
    end

    GetVerticalSettings()[settingName] = value
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetFlyingOrientationChoices()
    return C.FLYING_ORIENTATION_CHOICES
end

function PlayerBars.GetFlyingOrientationChoiceNames()
    return C.FLYING_ORIENTATION_CHOICE_NAMES
end

function PlayerBars.GetVerticalHealthWidth()
    return PlayerBars.GetVerticalNumber("healthWidth")
end

function PlayerBars.SetVerticalHealthWidth(value)
    PlayerBars.SetVerticalNumber("healthWidth", value, 10, 160)
end

function PlayerBars.GetVerticalHealthHeight()
    return PlayerBars.GetVerticalNumber("healthHeight")
end

function PlayerBars.SetVerticalHealthHeight(value)
    PlayerBars.SetVerticalNumber("healthHeight", value, 40, 400)
end

function PlayerBars.GetVerticalHealthX()
    return PlayerBars.GetVerticalNumber("healthHorizontalPosition")
end

function PlayerBars.SetVerticalHealthX(value)
    PlayerBars.SetVerticalPositionNumber("healthHorizontalPosition", value, 0, 100)
end

function PlayerBars.GetVerticalHealthY()
    return PlayerBars.GetVerticalNumber("healthVerticalPosition")
end

function PlayerBars.SetVerticalHealthY(value)
    PlayerBars.SetVerticalPositionNumber("healthVerticalPosition", value, 0, 100)
end

function PlayerBars.GetVerticalHealthFlyingOrientation()
    return GetVerticalSettings().healthFlyingOrientation
end

function PlayerBars.SetVerticalHealthFlyingOrientation(value)
    PlayerBars.SetVerticalFlyingOrientation("healthFlyingOrientation", value)
end

function PlayerBars.GetVerticalHealthReverse()
    return GetVerticalSettings().healthReverse
end

function PlayerBars.SetVerticalHealthReverse(value)
    GetVerticalSettings().healthReverse = value == true
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetVerticalHealthCurrentValue()
    return GetVerticalSettings().healthCurrentValue
end

function PlayerBars.SetVerticalHealthCurrentValue(value)
    PlayerBars.SetVerticalCurrentValue("healthCurrentValue", value)
end

function PlayerBars.GetVerticalMagickaWidth()
    return PlayerBars.GetVerticalNumber("magickaWidth")
end

function PlayerBars.SetVerticalMagickaWidth(value)
    PlayerBars.SetVerticalNumber("magickaWidth", value, 10, 160)
end

function PlayerBars.GetVerticalMagickaHeight()
    return PlayerBars.GetVerticalNumber("magickaHeight")
end

function PlayerBars.SetVerticalMagickaHeight(value)
    PlayerBars.SetVerticalNumber("magickaHeight", value, 40, 400)
end

function PlayerBars.GetVerticalMagickaX()
    return PlayerBars.GetVerticalNumber("magickaHorizontalPosition")
end

function PlayerBars.SetVerticalMagickaX(value)
    PlayerBars.SetVerticalPositionNumber("magickaHorizontalPosition", value, 0, 100)
end

function PlayerBars.GetVerticalMagickaY()
    return PlayerBars.GetVerticalNumber("magickaVerticalPosition")
end

function PlayerBars.SetVerticalMagickaY(value)
    PlayerBars.SetVerticalPositionNumber("magickaVerticalPosition", value, 0, 100)
end

function PlayerBars.GetVerticalMagickaFlyingOrientation()
    return GetVerticalSettings().magickaFlyingOrientation
end

function PlayerBars.SetVerticalMagickaFlyingOrientation(value)
    PlayerBars.SetVerticalFlyingOrientation("magickaFlyingOrientation", value)
end

function PlayerBars.GetVerticalMagickaReverse()
    return GetVerticalSettings().magickaReverse
end

function PlayerBars.SetVerticalMagickaReverse(value)
    GetVerticalSettings().magickaReverse = value == true
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetVerticalMagickaCurrentValue()
    return GetVerticalSettings().magickaCurrentValue
end

function PlayerBars.SetVerticalMagickaCurrentValue(value)
    PlayerBars.SetVerticalCurrentValue("magickaCurrentValue", value)
end

function PlayerBars.GetVerticalStaminaWidth()
    return PlayerBars.GetVerticalNumber("staminaWidth")
end

function PlayerBars.SetVerticalStaminaWidth(value)
    PlayerBars.SetVerticalNumber("staminaWidth", value, 10, 160)
end

function PlayerBars.GetVerticalStaminaHeight()
    return PlayerBars.GetVerticalNumber("staminaHeight")
end

function PlayerBars.SetVerticalStaminaHeight(value)
    PlayerBars.SetVerticalNumber("staminaHeight", value, 40, 400)
end

function PlayerBars.GetVerticalStaminaX()
    return PlayerBars.GetVerticalNumber("staminaHorizontalPosition")
end

function PlayerBars.SetVerticalStaminaX(value)
    PlayerBars.SetVerticalPositionNumber("staminaHorizontalPosition", value, 0, 100)
end

function PlayerBars.GetVerticalStaminaY()
    return PlayerBars.GetVerticalNumber("staminaVerticalPosition")
end

function PlayerBars.SetVerticalStaminaY(value)
    PlayerBars.SetVerticalPositionNumber("staminaVerticalPosition", value, 0, 100)
end

function PlayerBars.GetVerticalStaminaFlyingOrientation()
    return GetVerticalSettings().staminaFlyingOrientation
end

function PlayerBars.SetVerticalStaminaFlyingOrientation(value)
    PlayerBars.SetVerticalFlyingOrientation("staminaFlyingOrientation", value)
end

function PlayerBars.GetVerticalStaminaReverse()
    return GetVerticalSettings().staminaReverse
end

function PlayerBars.SetVerticalStaminaReverse(value)
    GetVerticalSettings().staminaReverse = value == true
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetVerticalStaminaCurrentValue()
    return GetVerticalSettings().staminaCurrentValue
end

function PlayerBars.SetVerticalStaminaCurrentValue(value)
    PlayerBars.SetVerticalCurrentValue("staminaCurrentValue", value)
end

function PlayerBars.GetVerticalBorderSize()
    return GetVerticalSettings().borderSize
end

function PlayerBars.SetVerticalBorderSize(value)
    GetVerticalSettings().borderSize = Clamp(Round(value), C.CLASSIC_BORDER_SIZE_MIN, C.CLASSIC_BORDER_SIZE_MAX)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetVerticalBorderSizeMin()
    return C.CLASSIC_BORDER_SIZE_MIN
end

function PlayerBars.GetVerticalBorderSizeMax()
    return C.CLASSIC_BORDER_SIZE_MAX
end

function PlayerBars.GetPresetSmoothTransitions(settings)
    return settings.smoothTransitions == true
end

function PlayerBars.SetPresetSmoothTransitions(settings, value)
    settings.smoothTransitions = value == true
    if not settings.smoothTransitions and PlayerBars.Smooth then
        PlayerBars.Smooth.ResetAll()
    end
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetPresetTransitionShadow(settings)
    return settings.transitionShadow == true
end

function PlayerBars.SetPresetTransitionShadow(settings, value)
    settings.transitionShadow = value == true
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetClassicSmoothTransitions()
    return PlayerBars.GetPresetSmoothTransitions(GetClassicSettings())
end

function PlayerBars.SetClassicSmoothTransitions(value)
    PlayerBars.SetPresetSmoothTransitions(GetClassicSettings(), value)
end

function PlayerBars.GetClassicTransitionShadow()
    return PlayerBars.GetPresetTransitionShadow(GetClassicSettings())
end

function PlayerBars.SetClassicTransitionShadow(value)
    PlayerBars.SetPresetTransitionShadow(GetClassicSettings(), value)
end

function PlayerBars.GetPyramidSmoothTransitions()
    return PlayerBars.GetPresetSmoothTransitions(GetPyramidSettings())
end

function PlayerBars.SetPyramidSmoothTransitions(value)
    PlayerBars.SetPresetSmoothTransitions(GetPyramidSettings(), value)
end

function PlayerBars.GetPyramidTransitionShadow()
    return PlayerBars.GetPresetTransitionShadow(GetPyramidSettings())
end

function PlayerBars.SetPyramidTransitionShadow(value)
    PlayerBars.SetPresetTransitionShadow(GetPyramidSettings(), value)
end

function PlayerBars.GetStackSmoothTransitions()
    return PlayerBars.GetPresetSmoothTransitions(GetStackSettings())
end

function PlayerBars.SetStackSmoothTransitions(value)
    PlayerBars.SetPresetSmoothTransitions(GetStackSettings(), value)
end

function PlayerBars.GetStackTransitionShadow()
    return PlayerBars.GetPresetTransitionShadow(GetStackSettings())
end

function PlayerBars.SetStackTransitionShadow(value)
    PlayerBars.SetPresetTransitionShadow(GetStackSettings(), value)
end

function PlayerBars.GetVerticalSmoothTransitions()
    return PlayerBars.GetPresetSmoothTransitions(GetVerticalSettings())
end

function PlayerBars.SetVerticalSmoothTransitions(value)
    PlayerBars.SetPresetSmoothTransitions(GetVerticalSettings(), value)
end

function PlayerBars.GetVerticalTransitionShadow()
    return PlayerBars.GetPresetTransitionShadow(GetVerticalSettings())
end

function PlayerBars.SetVerticalTransitionShadow(value)
    PlayerBars.SetPresetTransitionShadow(GetVerticalSettings(), value)
end

function PlayerBars.GetVerticalFontChoices()
    return NQOL.Util.GetFontChoices()
end

function PlayerBars.GetVerticalFontChoiceNames()
    return NQOL.Util.GetFontChoiceNames()
end

function PlayerBars.GetVerticalFont()
    return GetVerticalSettings().font
end

function PlayerBars.SetVerticalFont(value)
    if not NQOL.Util.IsFontChoice(value) then
        value = NQOL.Util.GetDefaultFont()
    end

    GetVerticalSettings().font = value
    ClearFontCache("vertical")
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetVerticalFontSize()
    return GetVerticalSettings().fontSize
end

function PlayerBars.SetVerticalFontSize(value)
    GetVerticalSettings().fontSize = Clamp(Round(value), C.CLASSIC_FONT_SIZE_MIN, C.CLASSIC_FONT_SIZE_MAX)
    ClearFontCache("vertical")
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetVerticalFontSizeMin()
    return C.CLASSIC_FONT_SIZE_MIN
end

function PlayerBars.GetVerticalFontSizeMax()
    return C.CLASSIC_FONT_SIZE_MAX
end

function PlayerBars.GetClassicHorizontalPosition()
    return GetClassicSettings().horizontalPosition
end

function PlayerBars.SetClassicHorizontalPosition(value)
    GetClassicSettings().horizontalPosition = Clamp(value, 0, 100)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetClassicVerticalPosition()
    return GetClassicSettings().verticalPosition
end

function PlayerBars.SetClassicVerticalPosition(value)
    GetClassicSettings().verticalPosition = Clamp(value, 0, 100)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetPyramidHorizontalPosition()
    return GetPyramidSettings().horizontalPosition
end

function PlayerBars.SetPyramidHorizontalPosition(value)
    GetPyramidSettings().horizontalPosition = Clamp(value, 0, 100)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetPyramidVerticalPosition()
    return GetPyramidSettings().verticalPosition
end

function PlayerBars.SetPyramidVerticalPosition(value)
    GetPyramidSettings().verticalPosition = Clamp(value, 0, 100)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetStackHorizontalPosition()
    return GetStackSettings().horizontalPosition
end

function PlayerBars.SetStackHorizontalPosition(value)
    GetStackSettings().horizontalPosition = Clamp(value, 0, 100)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetStackVerticalPosition()
    return GetStackSettings().verticalPosition
end

function PlayerBars.SetStackVerticalPosition(value)
    GetStackSettings().verticalPosition = Clamp(value, 0, 100)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetShowInSettings()
    return GetSettings().showInSettings
end

function PlayerBars.SetShowInSettings(value)
    GetSettings().showInSettings = value == true
    PlayerBars.Player.RefreshRuntimeState()
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetShowTrauma()
    return GetSettings().showTrauma
end

function PlayerBars.GetShowShield()
    return GetSettings().showShield
end

function PlayerBars.SetShowShield(value)
    GetSettings().showShield = value == true
    PlayerBars.UpdateHealthVisualValues(true)
    PlayerBars.QueueRefresh()
end

function PlayerBars.SetShowTrauma(value)
    GetSettings().showTrauma = value == true
    PlayerBars.UpdateHealthVisualValues(true)
    PlayerBars.QueueRefresh()
end

function PlayerBars.GetShowNoHealing()
    return GetSettings().showNoHealing
end

function PlayerBars.SetShowNoHealing(value)
    GetSettings().showNoHealing = value == true
    PlayerBars.UpdateHealthVisualValues(true)
    PlayerBars.QueueRefresh()
end

function PlayerBars.SetSettingsPanelVisible(value)
    if PlayerBars.Player and PlayerBars.Player.ApplySettingsPanelVisibility then
        PlayerBars.Player.ApplySettingsPanelVisibility(value)
    else
        PlayerBars.QueueRefresh()
    end
end

function PlayerBars.SetCompanionSettingsPanelVisible(value)
    COMPANION.settingsPanelVisible = value == true
    COMPANION.RefreshRuntimeState()
    COMPANION.QueueRefresh()
end
function PlayerBars.GetShowNqolCompanionFrame()
    return GetCompanionSettings().showNqolCompanionFrame
end

function PlayerBars.SetShowNqolCompanionFrame(value)
    GetCompanionSettings().showNqolCompanionFrame = value == true
    NQOL.Features.UI.RefreshOfficialCompanionFrameVisibility()
    COMPANION.RefreshRuntimeState()
    COMPANION.QueueRefresh()
end

function PlayerBars.GetCompanionShowOnlyInCombat()
    return GetCompanionSettings().showOnlyInCombat
end

function PlayerBars.SetCompanionShowOnlyInCombat(value)
    GetCompanionSettings().showOnlyInCombat = value == true
    COMPANION.QueueRefresh()
end

function PlayerBars.GetCompanionShowInSettings()
    return GetCompanionSettings().showInSettings
end

function PlayerBars.SetCompanionShowInSettings(value)
    GetCompanionSettings().showInSettings = value == true
    COMPANION.RefreshRuntimeState()
    COMPANION.QueueRefresh()
end

function PlayerBars.GetCompanionOrientation()
    return GetCompanionSettings().orientation
end

function PlayerBars.SetCompanionOrientation(value)
    if not COMPANION.VALID_ORIENTATIONS[value] then
        value = COMPANION.HORIZONTAL
    end

    GetCompanionSettings().orientation = value
    COMPANION.QueueRefresh()
end

function PlayerBars.GetCompanionOrientationChoices()
    return COMPANION.ORIENTATION_CHOICES
end

function PlayerBars.GetCompanionOrientationChoiceNames()
    return COMPANION.ORIENTATION_CHOICE_NAMES
end

function PlayerBars.GetCompanionHorizontalPosition()
    return GetCompanionSettings().horizontalPosition
end

function PlayerBars.SetCompanionHorizontalPosition(value)
    GetCompanionSettings().horizontalPosition = Clamp(value, 0, 100)
    COMPANION.QueueRefresh()
end

function PlayerBars.GetCompanionVerticalPosition()
    return GetCompanionSettings().verticalPosition
end

function PlayerBars.SetCompanionVerticalPosition(value)
    GetCompanionSettings().verticalPosition = Clamp(value, 0, 100)
    COMPANION.QueueRefresh()
end

function PlayerBars.GetCompanionWidth()
    return GetCompanionSettings().width
end

function PlayerBars.SetCompanionWidth(value)
    GetCompanionSettings().width = Clamp(Round(value), COMPANION.WIDTH_MIN, COMPANION.WIDTH_MAX)
    COMPANION.QueueRefresh()
end

function PlayerBars.GetCompanionWidthMin()
    return COMPANION.WIDTH_MIN
end

function PlayerBars.GetCompanionWidthMax()
    return COMPANION.WIDTH_MAX
end

function PlayerBars.GetCompanionHeight()
    return GetCompanionSettings().height
end

function PlayerBars.SetCompanionHeight(value)
    GetCompanionSettings().height = Clamp(Round(value), COMPANION.HEIGHT_MIN, COMPANION.HEIGHT_MAX)
    COMPANION.QueueRefresh()
end

function PlayerBars.GetCompanionHeightMin()
    return COMPANION.HEIGHT_MIN
end

function PlayerBars.GetCompanionHeightMax()
    return COMPANION.HEIGHT_MAX
end

function PlayerBars.GetCompanionBorderSize()
    return GetCompanionSettings().borderSize
end

function PlayerBars.SetCompanionBorderSize(value)
    GetCompanionSettings().borderSize = Clamp(Round(value), C.CLASSIC_BORDER_SIZE_MIN, C.CLASSIC_BORDER_SIZE_MAX)
    COMPANION.QueueRefresh()
end

function PlayerBars.GetCompanionBorderSizeMin()
    return C.CLASSIC_BORDER_SIZE_MIN
end

function PlayerBars.GetCompanionBorderSizeMax()
    return C.CLASSIC_BORDER_SIZE_MAX
end

function PlayerBars.GetCompanionFontChoices()
    return NQOL.Util.GetFontChoices()
end

function PlayerBars.GetCompanionFontChoiceNames()
    return NQOL.Util.GetFontChoiceNames()
end

function PlayerBars.GetCompanionFont()
    return GetCompanionSettings().font
end

function PlayerBars.SetCompanionFont(value)
    if not NQOL.Util.IsFontChoice(value) then
        value = NQOL.Util.GetDefaultFont()
    end

    GetCompanionSettings().font = value
    ClearFontCache("companion")
    COMPANION.QueueRefresh()
end

function PlayerBars.GetCompanionFontSize()
    return GetCompanionSettings().fontSize
end

function PlayerBars.SetCompanionFontSize(value)
    GetCompanionSettings().fontSize = Clamp(Round(value), C.CLASSIC_FONT_SIZE_MIN, C.CLASSIC_FONT_SIZE_MAX)
    ClearFontCache("companion")
    COMPANION.QueueRefresh()
end

function PlayerBars.GetCompanionFontSizeMin()
    return C.CLASSIC_FONT_SIZE_MIN
end

function PlayerBars.GetCompanionFontSizeMax()
    return C.CLASSIC_FONT_SIZE_MAX
end

function PlayerBars.GetCompanionShowName()
    return GetCompanionSettings().showName
end

function PlayerBars.SetCompanionShowName(value)
    GetCompanionSettings().showName = value == true
    COMPANION.QueueRefresh()
end

function PlayerBars.GetCompanionShowRapport()
    return GetCompanionSettings().showRapport == true
end

function PlayerBars.SetCompanionShowRapport(value)
    GetCompanionSettings().showRapport = value == true
    COMPANION.QueueRefresh()
end

function PlayerBars.GetCompanionShowXpProgress()
    return GetCompanionSettings().showXpProgress == true
end

function PlayerBars.SetCompanionShowXpProgress(value)
    GetCompanionSettings().showXpProgress = value == true
    COMPANION.QueueRefresh()
end

function PlayerBars.GetCompanionCurrentValue()
    return GetCompanionSettings().currentValue
end

function PlayerBars.SetCompanionCurrentValue(value)
    if value ~= C.CURRENT_VALUE.PERCENTAGE then
        value = C.CURRENT_VALUE.NUMBER
    end

    GetCompanionSettings().currentValue = value
    COMPANION.QueueRefresh()
end

function PlayerBars.GetCompanionHealthBarColor()
    local color = GetCompanionSettings().healthColor
    return color.r, color.g, color.b, color.a or 1
end

function PlayerBars.SetCompanionHealthBarColor(red, green, blue, alpha)
    GetCompanionSettings().healthColor = PlayerBars.Group.CopyColorTable({ r = red, g = green, b = blue, a = alpha or 1 })
    COMPANION.QueueRefresh()
end

function PlayerBars.GetCompanionXpColor()
    local color = GetCompanionSettings().xpColor
    return color.r, color.g, color.b, color.a or 1
end

function PlayerBars.SetCompanionXpColor(red, green, blue, alpha)
    GetCompanionSettings().xpColor = PlayerBars.Group.CopyColorTable({ r = red, g = green, b = blue, a = alpha or 1 })
    COMPANION.QueueRefresh()
end

function PlayerBars.GetCompanionSmoothTransitions()
    return GetCompanionSettings().smoothTransitions == true
end

function PlayerBars.SetCompanionSmoothTransitions(value)
    local settings = GetCompanionSettings()
    settings.smoothTransitions = value == true
    if not settings.smoothTransitions and PlayerBars.Smooth then
        PlayerBars.Smooth.ResetAll()
    end
    COMPANION.QueueRefresh()
end

function PlayerBars.GetCompanionTransitionShadow()
    return GetCompanionSettings().transitionShadow == true
end

function PlayerBars.SetCompanionTransitionShadow(value)
    GetCompanionSettings().transitionShadow = value == true
    COMPANION.QueueRefresh()
end

function PlayerBars.GetCompanionReverse()
    return GetCompanionSettings().reverse
end

function PlayerBars.SetCompanionReverse(value)
    GetCompanionSettings().reverse = value == true
    COMPANION.QueueRefresh()
end

function PlayerBars.GetCompanionShadow()
    return GetCompanionSettings().shadow
end

function PlayerBars.SetCompanionShadow(value)
    if not Shadow.VALID[value] then
        value = Shadow.NONE
    end

    GetCompanionSettings().shadow = value
    COMPANION.QueueRefresh()
end

function PlayerBars.GetCompanionShadowChoices()
    return Shadow.CHOICES
end

function PlayerBars.GetCompanionShadowChoiceNames()
    return Shadow.CHOICE_NAMES
end

function PlayerBars.GetCompanionShadowIntensity()
    return GetCompanionSettings().shadowIntensity
end

function PlayerBars.GetCompanionShadowIntensityDefault()
    return defaults.ui.customFrames.companionFrame.shadowIntensity
end

function PlayerBars.SetCompanionShadowIntensity(value)
    GetCompanionSettings().shadowIntensity = Clamp(Round(value), Shadow.INTENSITY_MIN, Shadow.INTENSITY_MAX)
    COMPANION.QueueRefresh()
end

function PlayerBars.GetCompanionShadowIntensityMin()
    return Shadow.INTENSITY_MIN
end

function PlayerBars.GetCompanionShadowIntensityMax()
    return Shadow.INTENSITY_MAX
end

function PlayerBars.ValidateGroupCustomNamesSetting()
    if PlayerBars.Group.IsLibCustomNamesAvailable() then
        return true
    end

    local settings = PlayerBars.Group.GetSettings()
    if settings.showCustomNames == true then
        settings.showCustomNames = false
        PlayerBars.Group.QueueRefresh()
    end

    return false
end

function PlayerBars.SetGroupSettingsPanelVisible(value)
    if value == true then
        PlayerBars.ValidateGroupCustomNamesSetting()
    end

    PlayerBars.Group.settingsPanelVisible = value == true
    PlayerBars.Group.RefreshRuntimeState()
    PlayerBars.Group.QueueRefresh()
end
function PlayerBars.GetShowNqolGroupFrame()
    return PlayerBars.Group.GetSettings().showNqolGroupFrame
end

function PlayerBars.SetShowNqolGroupFrame(value)
    PlayerBars.Group.GetSettings().showNqolGroupFrame = value == true
    NQOL.Features.UI.RefreshOfficialGroupFrameVisibility()
    PlayerBars.Group.RefreshRuntimeState()
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupShowOnlyInCombat()
    return PlayerBars.Group.GetSettings().showOnlyInCombat
end

function PlayerBars.SetGroupShowOnlyInCombat(value)
    PlayerBars.Group.GetSettings().showOnlyInCombat = value == true
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupShowCustomNames()
    return PlayerBars.Group.GetSettings().showCustomNames
end

function PlayerBars.SetGroupShowCustomNames(value)
    PlayerBars.Group.GetSettings().showCustomNames = value == true
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupShowCustomNamesDefault()
    return defaults.ui.customFrames.groupFrame.showCustomNames
end

function PlayerBars.GetGroupShowInSettings()
    return PlayerBars.Group.GetSettings().showInSettings
end

function PlayerBars.SetGroupShowInSettings(value)
    PlayerBars.Group.GetSettings().showInSettings = value == true
    PlayerBars.Group.RefreshRuntimeState()
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupShowShield()
    return PlayerBars.Group.GetSettings().showShield
end

function PlayerBars.SetGroupShowShield(value)
    PlayerBars.Group.GetSettings().showShield = value == true
    PlayerBars.Group.ResetSmoothAnimations()
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupShowTrauma()
    return PlayerBars.Group.GetSettings().showTrauma
end

function PlayerBars.SetGroupShowTrauma(value)
    PlayerBars.Group.GetSettings().showTrauma = value == true
    PlayerBars.Group.ResetSmoothAnimations()
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupShowNoHealing()
    return PlayerBars.Group.GetSettings().showNoHealing
end

function PlayerBars.SetGroupShowNoHealing(value)
    PlayerBars.Group.GetSettings().showNoHealing = value == true
    PlayerBars.Group.ResetSmoothAnimations()
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupHorizontalPosition()
    return PlayerBars.Group.GetSettings().horizontalPosition
end

function PlayerBars.SetGroupHorizontalPosition(value)
    PlayerBars.Group.GetSettings().horizontalPosition = Clamp(value, 0, 100)
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupVerticalPosition()
    return PlayerBars.Group.GetSettings().verticalPosition
end

function PlayerBars.SetGroupVerticalPosition(value)
    PlayerBars.Group.GetSettings().verticalPosition = Clamp(value, 0, 100)
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupWidth()
    return PlayerBars.Group.GetSettings().width
end

function PlayerBars.SetGroupWidth(value)
    PlayerBars.Group.GetSettings().width = Clamp(Round(value), PlayerBars.Group.WIDTH_MIN, PlayerBars.Group.WIDTH_MAX)
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupWidthMin()
    return PlayerBars.Group.WIDTH_MIN
end

function PlayerBars.GetGroupWidthMax()
    return PlayerBars.Group.WIDTH_MAX
end

function PlayerBars.GetGroupHeight()
    return PlayerBars.Group.GetSettings().height
end

function PlayerBars.SetGroupHeight(value)
    PlayerBars.Group.GetSettings().height = Clamp(Round(value), PlayerBars.Group.HEIGHT_MIN, PlayerBars.Group.HEIGHT_MAX)
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupHeightMin()
    return PlayerBars.Group.HEIGHT_MIN
end

function PlayerBars.GetGroupHeightMax()
    return PlayerBars.Group.HEIGHT_MAX
end

function PlayerBars.GetGroupColumns()
    return PlayerBars.Group.GetSettings().columns
end

function PlayerBars.SetGroupColumns(value)
    PlayerBars.Group.GetSettings().columns = Clamp(Round(value), PlayerBars.Group.COLUMNS_MIN, PlayerBars.Group.COLUMNS_MAX)
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupColumnsMin()
    return PlayerBars.Group.COLUMNS_MIN
end

function PlayerBars.GetGroupColumnsMax()
    return PlayerBars.Group.COLUMNS_MAX
end

function PlayerBars.GetGroupColumnsDefault()
    return defaults.ui.customFrames.groupFrame.columns
end

function PlayerBars.GetGroupRowGap()
    return PlayerBars.Group.GetSettings().rowGap
end

function PlayerBars.SetGroupRowGap(value)
    PlayerBars.Group.GetSettings().rowGap = Clamp(Round(value), PlayerBars.Group.ROW_GAP_MIN, PlayerBars.Group.ROW_GAP_MAX)
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupRowGapMin()
    return PlayerBars.Group.ROW_GAP_MIN
end

function PlayerBars.GetGroupRowGapMax()
    return PlayerBars.Group.ROW_GAP_MAX
end

function PlayerBars.GetGroupColumnGap()
    return PlayerBars.Group.GetSettings().columnGap
end

function PlayerBars.SetGroupColumnGap(value)
    PlayerBars.Group.GetSettings().columnGap = Clamp(Round(value), PlayerBars.Group.COLUMN_GAP_MIN, PlayerBars.Group.COLUMN_GAP_MAX)
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupColumnGapMin()
    return PlayerBars.Group.COLUMN_GAP_MIN
end

function PlayerBars.GetGroupColumnGapMax()
    return PlayerBars.Group.COLUMN_GAP_MAX
end

function PlayerBars.GetGroupBorderSize()
    return PlayerBars.Group.GetSettings().borderSize
end

function PlayerBars.SetGroupBorderSize(value)
    PlayerBars.Group.GetSettings().borderSize = Clamp(Round(value), C.CLASSIC_BORDER_SIZE_MIN, C.CLASSIC_BORDER_SIZE_MAX)
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupBorderSizeMin()
    return C.CLASSIC_BORDER_SIZE_MIN
end

function PlayerBars.GetGroupBorderSizeMax()
    return C.CLASSIC_BORDER_SIZE_MAX
end

function PlayerBars.GetGroupFontChoices()
    return NQOL.Util.GetFontChoices()
end

function PlayerBars.GetGroupFontChoiceNames()
    return NQOL.Util.GetFontChoiceNames()
end

function PlayerBars.GetGroupFont()
    return PlayerBars.Group.GetSettings().font
end

function PlayerBars.SetGroupFont(value)
    if not NQOL.Util.IsFontChoice(value) then
        value = NQOL.Util.GetDefaultFont()
    end

    PlayerBars.Group.GetSettings().font = value
    PlayerBars.Group.fontString = nil
    PlayerBars.Group.fontKey = nil
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupFontSize()
    return PlayerBars.Group.GetSettings().fontSize
end

function PlayerBars.SetGroupFontSize(value)
    PlayerBars.Group.GetSettings().fontSize = Clamp(Round(value), C.CLASSIC_FONT_SIZE_MIN, C.CLASSIC_FONT_SIZE_MAX)
    PlayerBars.Group.fontString = nil
    PlayerBars.Group.fontKey = nil
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupFontSizeMin()
    return C.CLASSIC_FONT_SIZE_MIN
end

function PlayerBars.GetGroupFontSizeMax()
    return C.CLASSIC_FONT_SIZE_MAX
end

function PlayerBars.GetGroupNameDisplay()
    return PlayerBars.Group.GetSettings().nameDisplay
end

function PlayerBars.SetGroupNameDisplay(value)
    if not PlayerBars.Group.NAME_DISPLAY_VALID_CHOICES[value] then
        value = PlayerBars.Group.NAME_DISPLAY_CHARACTER
    end

    PlayerBars.Group.GetSettings().nameDisplay = value
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupNameDisplayChoices()
    return PlayerBars.Group.NAME_DISPLAY_CHOICES
end

function PlayerBars.GetGroupNameDisplayChoiceNames()
    return PlayerBars.Group.NAME_DISPLAY_CHOICE_NAMES
end

function PlayerBars.GetGroupShowClass()
    return PlayerBars.Group.GetSettings().showClass
end

function PlayerBars.GetGroupShowClassDefault()
    return defaults.ui.customFrames.groupFrame.showClass
end

function PlayerBars.SetGroupShowClass(value)
    PlayerBars.Group.GetSettings().showClass = value == true
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupShowTargetMarker()
    return PlayerBars.Group.GetSettings().showTargetMarker
end

function PlayerBars.GetGroupShowTargetMarkerDefault()
    return defaults.ui.customFrames.groupFrame.showTargetMarker
end

function PlayerBars.SetGroupShowTargetMarker(value)
    PlayerBars.Group.GetSettings().showTargetMarker = value == true
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupShowChampionPoints()
    return PlayerBars.Group.GetSettings().showChampionPoints
end

function PlayerBars.GetGroupShowChampionPointsDefault()
    return defaults.ui.customFrames.groupFrame.showChampionPoints
end

function PlayerBars.SetGroupShowChampionPoints(value)
    PlayerBars.Group.GetSettings().showChampionPoints = value == true
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupShowCompanions()
    return PlayerBars.Group.GetSettings().showCompanions
end

function PlayerBars.GetGroupShowCompanionsDefault()
    return defaults.ui.customFrames.groupFrame.showCompanions
end

function PlayerBars.SetGroupShowCompanions(value)
    PlayerBars.Group.GetSettings().showCompanions = value == true
    PlayerBars.Group.ClearCompanionNameCache()
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupChampionPointsPlacement()
    return PlayerBars.Group.GetSettings().championPointsPlacement
end

function PlayerBars.SetGroupChampionPointsPlacement(value)
    if not PlayerBars.Group.CHAMPION_POINTS_PLACEMENT_VALID_CHOICES[value] then
        value = PlayerBars.Group.CHAMPION_POINTS_BEFORE
    end

    PlayerBars.Group.GetSettings().championPointsPlacement = value
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupChampionPointsPlacementChoices()
    return PlayerBars.Group.CHAMPION_POINTS_PLACEMENT_CHOICES
end

function PlayerBars.GetGroupChampionPointsPlacementChoiceNames()
    return PlayerBars.Group.CHAMPION_POINTS_PLACEMENT_CHOICE_NAMES
end

function PlayerBars.GetGroupShowLeader()
    return PlayerBars.Group.GetSettings().showLeader
end

function PlayerBars.SetGroupShowLeader(value)
    PlayerBars.Group.GetSettings().showLeader = value == true
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupShowDeathCounter()
    return PlayerBars.Group.GetSettings().showDeathCounter
end

function PlayerBars.SetGroupShowDeathCounter(value)
    PlayerBars.Group.GetSettings().showDeathCounter = value == true
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupShowResurrectingColor()
    return PlayerBars.Group.GetSettings().showResurrectingColor
end

function PlayerBars.SetGroupShowResurrectingColor(value)
    PlayerBars.Group.GetSettings().showResurrectingColor = value == true
    PlayerBars.Group.RefreshResurrectingMonitors()
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupDimAwayOpacity()
    return PlayerBars.Group.GetSettings().dimAwayOpacity
end

function PlayerBars.GetGroupDimAwayOpacityDefault()
    return defaults.ui.customFrames.groupFrame.dimAwayOpacity
end

function PlayerBars.SetGroupDimAwayOpacity(value)
    PlayerBars.Group.GetSettings().dimAwayOpacity = Clamp(Round(value), 0, 100)
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupCurrentValue()
    return PlayerBars.Group.GetSettings().currentValue
end

function PlayerBars.SetGroupCurrentValue(value)
    if value ~= C.CURRENT_VALUE.PERCENTAGE then
        value = C.CURRENT_VALUE.NUMBER
    end

    PlayerBars.Group.GetSettings().currentValue = value
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupSmoothTransitions()
    return PlayerBars.Group.GetSettings().smoothTransitions == true
end

function PlayerBars.SetGroupSmoothTransitions(value)
    local settings = PlayerBars.Group.GetSettings()
    settings.smoothTransitions = value == true
    if not settings.smoothTransitions and PlayerBars.Smooth then
        PlayerBars.Smooth.ResetAll()
    end
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupTransitionShadow()
    return PlayerBars.Group.GetSettings().transitionShadow == true
end

function PlayerBars.SetGroupTransitionShadow(value)
    PlayerBars.Group.GetSettings().transitionShadow = value == true
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupReverse()
    return PlayerBars.Group.GetSettings().reverse
end

function PlayerBars.SetGroupReverse(value)
    PlayerBars.Group.GetSettings().reverse = value == true
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupShadow()
    return PlayerBars.Group.GetSettings().shadow
end

function PlayerBars.SetGroupShadow(value)
    if not Shadow.VALID[value] then
        value = Shadow.NONE
    end

    PlayerBars.Group.GetSettings().shadow = value
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupShadowIntensity()
    return PlayerBars.Group.GetSettings().shadowIntensity
end

function PlayerBars.GetGroupShadowIntensityDefault()
    return defaults.ui.customFrames.groupFrame.shadowIntensity
end

function PlayerBars.SetGroupShadowIntensity(value)
    PlayerBars.Group.GetSettings().shadowIntensity = Clamp(Round(value), Shadow.INTENSITY_MIN, Shadow.INTENSITY_MAX)
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupDamageColor()
    local color = PlayerBars.Group.GetSettings().roleColors.dps
    return color.r, color.g, color.b, color.a or 1
end

function PlayerBars.SetGroupDamageColor(red, green, blue, alpha)
    PlayerBars.Group.GetSettings().roleColors.dps = PlayerBars.Group.CopyColorTable({ r = red, g = green, b = blue, a = alpha or 1 })
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupTankColor()
    local color = PlayerBars.Group.GetSettings().roleColors.tank
    return color.r, color.g, color.b, color.a or 1
end

function PlayerBars.SetGroupTankColor(red, green, blue, alpha)
    PlayerBars.Group.GetSettings().roleColors.tank = PlayerBars.Group.CopyColorTable({ r = red, g = green, b = blue, a = alpha or 1 })
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupHealerColor()
    local color = PlayerBars.Group.GetSettings().roleColors.heal
    return color.r, color.g, color.b, color.a or 1
end

function PlayerBars.SetGroupHealerColor(red, green, blue, alpha)
    PlayerBars.Group.GetSettings().roleColors.heal = PlayerBars.Group.CopyColorTable({ r = red, g = green, b = blue, a = alpha or 1 })
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupShieldColor()
    local color = PlayerBars.Group.GetSettings().shieldColor
    return color.r, color.g, color.b, color.a or 1
end

function PlayerBars.SetGroupShieldColor(red, green, blue, alpha)
    PlayerBars.Group.GetSettings().shieldColor = PlayerBars.Group.CopyColorTable({ r = red, g = green, b = blue, a = alpha or 1 })
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupTraumaColor()
    local color = PlayerBars.Group.GetSettings().traumaColor
    return color.r, color.g, color.b, color.a or 1
end

function PlayerBars.SetGroupTraumaColor(red, green, blue, alpha)
    PlayerBars.Group.GetSettings().traumaColor = PlayerBars.Group.CopyColorTable({ r = red, g = green, b = blue, a = alpha or 1 })
    PlayerBars.Group.QueueRefresh()
end

function PlayerBars.GetGroupResurrectingColor()
    local color = PlayerBars.Group.GetSettings().resurrectingColor
    return color.r, color.g, color.b, color.a or 1
end

function PlayerBars.SetGroupResurrectingColor(red, green, blue, alpha)
    PlayerBars.Group.GetSettings().resurrectingColor = PlayerBars.Group.CopyColorTable({ r = red, g = green, b = blue, a = alpha or 1 })
    PlayerBars.Group.QueueRefresh()
end
