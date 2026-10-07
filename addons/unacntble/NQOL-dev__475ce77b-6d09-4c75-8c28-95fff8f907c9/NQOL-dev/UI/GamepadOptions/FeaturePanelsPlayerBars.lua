NQOL = NQOL or {}
local GamepadOptions = NQOL.GamepadOptions

function GamepadOptions.BuildShowNqolPlayerFrameOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_PANEL_ID, 2, playerBars.GetShowNqolPlayerFrameLabel(), playerBars.GetShowNqolPlayerFrameTooltip(), playerBars.GetShowNqolPlayerFrame, playerBars.SetShowNqolPlayerFrame)
end

function GamepadOptions.BuildShowNqolCompanionFrameOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.COMPANION_FRAME_PANEL_ID, 2, playerBars.GetShowNqolCompanionFrameLabel(), playerBars.GetShowNqolCompanionFrameTooltip(), playerBars.GetShowNqolCompanionFrame, playerBars.SetShowNqolCompanionFrame)
end

function GamepadOptions.BuildShowNqolGroupFrameOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 2, playerBars.GetShowNqolGroupFrameLabel(), playerBars.GetShowNqolGroupFrameTooltip(), playerBars.GetShowNqolGroupFrame, playerBars.SetShowNqolGroupFrame)
end

function GamepadOptions.BuildPlayerShowOnlyInCombatOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_PANEL_ID, 1, playerBars.GetShowOnlyInCombatLabel(), playerBars.GetShowOnlyInCombatTooltip(), playerBars.GetPlayerShowOnlyInCombat, playerBars.SetPlayerShowOnlyInCombat)
end

function GamepadOptions.BuildCompanionShowOnlyInCombatOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.COMPANION_FRAME_PANEL_ID, 1, playerBars.GetShowOnlyInCombatLabel(), playerBars.GetShowOnlyInCombatTooltip(), playerBars.GetCompanionShowOnlyInCombat, playerBars.SetCompanionShowOnlyInCombat)
end

function GamepadOptions.BuildGroupShowOnlyInCombatOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 1, playerBars.GetShowOnlyInCombatLabel(), playerBars.GetShowOnlyInCombatTooltip(), playerBars.GetGroupShowOnlyInCombat, playerBars.SetGroupShowOnlyInCombat)
end

function GamepadOptions.BuildGroupShowCustomNamesOption()
    local playerBars = NQOL.Features.PlayerBars
    local option = GamepadOptions.BuildCheckboxOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 34, playerBars.GetGroupShowCustomNamesLabel(), playerBars.GetGroupShowCustomNamesTooltip(), playerBars.GetGroupShowCustomNames, playerBars.SetGroupShowCustomNames, playerBars.Group.IsLibCustomNamesAvailable, playerBars.GetGroupShowCustomNamesDefault)
    option.gamepadIsEnabledCallback = playerBars.Group.IsLibCustomNamesAvailable
    return option
end

function GamepadOptions.BuildPlayerBarsPresetOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_PANEL_ID, 6, playerBars.GetPresetLabel(), playerBars.GetPresetTooltip(), playerBars.GetPresetChoices(), playerBars.GetPresetChoiceNames(), playerBars.GetPreset, playerBars.SetPreset)
end

local function BuildPresetBarColorOption(panelId, settingId, presetKey, colorKey, label, tooltip)
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildColorOption(panelId, settingId, label, tooltip, function()
        return playerBars.GetPresetBarColor(presetKey, colorKey)
    end, function(red, green, blue, alpha)
        playerBars.SetPresetBarColor(presetKey, colorKey, red, green, blue, alpha)
    end)
end

function GamepadOptions.BuildPresetHealthBarColorOption(panelId, settingId, presetKey)
    local playerBars = NQOL.Features.PlayerBars
    return BuildPresetBarColorOption(panelId, settingId, presetKey, "health", playerBars.GetHealthBarColorLabel(), playerBars.GetHealthBarColorTooltip())
end

function GamepadOptions.BuildPresetMagickaBarColorOption(panelId, settingId, presetKey)
    local playerBars = NQOL.Features.PlayerBars
    return BuildPresetBarColorOption(panelId, settingId, presetKey, "magicka", playerBars.GetMagickaBarColorLabel(), playerBars.GetMagickaBarColorTooltip())
end

function GamepadOptions.BuildPresetStaminaBarColorOption(panelId, settingId, presetKey)
    local playerBars = NQOL.Features.PlayerBars
    return BuildPresetBarColorOption(panelId, settingId, presetKey, "stamina", playerBars.GetStaminaBarColorLabel(), playerBars.GetStaminaBarColorTooltip())
end

function GamepadOptions.BuildPresetTraumaBarColorOption(panelId, settingId, presetKey)
    local playerBars = NQOL.Features.PlayerBars
    return BuildPresetBarColorOption(panelId, settingId, presetKey, "trauma", playerBars.GetTraumaBarColorLabel(), playerBars.GetTraumaBarColorTooltip())
end

function GamepadOptions.BuildPresetShieldBarColorOption(panelId, settingId, presetKey)
    local playerBars = NQOL.Features.PlayerBars
    return BuildPresetBarColorOption(panelId, settingId, presetKey, "shield", playerBars.GetShieldBarColorLabel(), playerBars.GetShieldBarColorTooltip())
end

local function BuildRadialSideOption(settingId, label, tooltip, getFunc, setFunc, enabled)
    local playerBars = NQOL.Features.PlayerBars
    local option = GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID, settingId, label, tooltip, playerBars.GetFlyingOrientationChoices(), playerBars.GetFlyingOrientationChoiceNames(), getFunc, setFunc)
    option.enabled = enabled
    option.gamepadIsEnabledCallback = enabled
    return option
end

function GamepadOptions.BuildRadialHealthSideOption()
    local playerBars = NQOL.Features.PlayerBars
    return BuildRadialSideOption(3, playerBars.GetRadialHealthSideLabel(), playerBars.GetRadialHealthSideTooltip(), playerBars.GetRadialHealthSide, playerBars.SetRadialHealthSide)
end

function GamepadOptions.BuildRadialMagickaSideOption()
    local playerBars = NQOL.Features.PlayerBars
    return BuildRadialSideOption(5, playerBars.GetRadialMagickaSideLabel(), playerBars.GetRadialMagickaSideTooltip(), playerBars.GetRadialMagickaSide, playerBars.SetRadialMagickaSide, playerBars.IsRadialNotStacked)
end

function GamepadOptions.BuildRadialStaminaSideOption()
    local playerBars = NQOL.Features.PlayerBars
    return BuildRadialSideOption(6, playerBars.GetRadialStaminaSideLabel(), playerBars.GetRadialStaminaSideTooltip(), playerBars.GetRadialStaminaSide, playerBars.SetRadialStaminaSide, playerBars.IsRadialNotStacked)
end

function GamepadOptions.BuildRadialStackOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID, 7, playerBars.GetRadialStackLabel(), playerBars.GetRadialStackTooltip(), playerBars.GetRadialStackChoices(), playerBars.GetRadialStackChoiceNames(), playerBars.GetRadialStack, function(value)
        playerBars.SetRadialStack(value)
        GamepadOptions.RefreshCurrentOptionsList()
    end)
end

function GamepadOptions.BuildRadialStackTypeOption()
    local playerBars = NQOL.Features.PlayerBars
    local option = GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID, 9, playerBars.GetRadialStackTypeLabel(), playerBars.GetRadialStackTypeTooltip(), playerBars.GetRadialStackTypeChoices(), playerBars.GetRadialStackTypeChoiceNames(), playerBars.GetRadialStackType, playerBars.SetRadialStackType)
    option.enabled = playerBars.IsRadialStacked
    option.gamepadIsEnabledCallback = playerBars.IsRadialStacked
    return option
end

function GamepadOptions.BuildRadialStackPositionOption()
    local playerBars = NQOL.Features.PlayerBars
    return BuildRadialSideOption(8, playerBars.GetRadialStackPositionLabel(), playerBars.GetRadialStackPositionTooltip(), playerBars.GetRadialStackPosition, playerBars.SetRadialStackPosition, playerBars.IsRadialStacked)
end

function GamepadOptions.BuildRadialHorizontalPositionOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildPositionSliderOption(GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID, 1, playerBars.GetHorizontalPositionLabel(), playerBars.GetHorizontalPositionTooltip(), 0, 100, "%.0f", playerBars.GetRadialHorizontalPosition, playerBars.SetRadialHorizontalPosition)
end

function GamepadOptions.BuildRadialVerticalPositionOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildPositionSliderOption(GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID, 2, playerBars.GetVerticalPositionLabel(), playerBars.GetVerticalPositionTooltip(), 0, 100, "%.0f", playerBars.GetRadialVerticalPosition, playerBars.SetRadialVerticalPosition)
end

function GamepadOptions.BuildRadialScaleOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildValueStepSliderOption(GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID, 19, NQOL.L("ui.player_bars.radial_scale"), NQOL.L("ui.player_bars.radial_scale_tooltip"), playerBars.GetRadialScaleMin(), playerBars.GetRadialScaleMax(), "%.0f%%", playerBars.GetRadialScale, playerBars.SetRadialScale, 5)
end

function GamepadOptions.BuildRadialBorderSizeOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildValueStepSliderOption(GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID, 4, playerBars.GetRadialBorderSizeLabel(), playerBars.GetRadialBorderSizeTooltip(), playerBars.GetRadialBorderSizeMin(), playerBars.GetRadialBorderSizeMax(), "%.0f", playerBars.GetRadialBorderSize, playerBars.SetRadialBorderSize, 1)
end

function GamepadOptions.BuildRadialFontOption()
    local p = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID, 10, p.GetClassicFontLabel(), NQOL.L("ui.player_bars.radial_font_tooltip"), p.GetRadialFontChoices(), p.GetRadialFontChoiceNames(), p.GetRadialFont, p.SetRadialFont)
end

function GamepadOptions.BuildRadialFontSizeOption()
    local p = NQOL.Features.PlayerBars
    return GamepadOptions.BuildValueStepSliderOption(GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID, 11, p.GetClassicFontSizeLabel(), NQOL.L("ui.player_bars.radial_font_size_tooltip"), p.GetRadialFontSizeMin(), p.GetRadialFontSizeMax(), "%.0f", p.GetRadialFontSize, p.SetRadialFontSize, 1)
end

function GamepadOptions.BuildRadialCurrentValueOption()
    local p = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID, 12, p.GetCurrentValueLabel(), NQOL.L("ui.player_bars.radial_current_value_tooltip"), p.GetCurrentValueChoices(), p.GetCurrentValueChoiceNames(), p.GetRadialCurrentValue, p.SetRadialCurrentValue)
end

function GamepadOptions.BuildRadialSmoothTransitionsOption()
    local p = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID, 15, p.GetSmoothTransitionsLabel(), p.GetSmoothTransitionsTooltip(), p.GetRadialSmoothTransitions, p.SetRadialSmoothTransitions)
end

function GamepadOptions.BuildRadialTransitionShadowOption()
    local p = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID, 16, p.GetTransitionShadowLabel(), p.GetTransitionShadowTooltip(), p.GetRadialTransitionShadow, p.SetRadialTransitionShadow)
end

function GamepadOptions.BuildRadialShadowOption()
    local p = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID, 17, p.GetShadowLabel(), p.GetShadowTooltip(), p.GetShadowChoices(), p.GetShadowChoiceNames(), p.GetRadialShadow, p.SetRadialShadow)
end

function GamepadOptions.BuildRadialShadowIntensityOption()
    local p = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID, 18, p.GetShadowIntensityLabel(), p.GetShadowIntensityTooltip(), p.GetShadowIntensityMin(), p.GetShadowIntensityMax(), "%.0f%%", p.GetRadialShadowIntensity, p.SetRadialShadowIntensity, 1, nil, p.GetRadialShadowIntensityDefault)
end

function GamepadOptions.BuildRadialFlyingPositiveAnimationOption()
    local p = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID, 20, p.GetRadialFlyingPositiveAnimationLabel(), p.GetRadialFlyingPositiveAnimationTooltip(), p.GetRadialFlyingPositiveAnimation, p.SetRadialFlyingPositiveAnimation)
end

function GamepadOptions.BuildRadialFlyingNegativeAnimationOption()
    local p = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID, 21, p.GetRadialFlyingNegativeAnimationLabel(), p.GetRadialFlyingNegativeAnimationTooltip(), p.GetRadialFlyingNegativeAnimation, p.SetRadialFlyingNegativeAnimation)
end

function GamepadOptions.BuildRadialFlyingAnimationFontOption()
    local p = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID, 22, p.GetRadialFlyingAnimationFontLabel(), p.GetRadialFlyingAnimationFontTooltip(), p.GetRadialFlyingAnimationFontChoices(), p.GetRadialFlyingAnimationFontChoiceNames(), p.GetRadialFlyingAnimationFont, p.SetRadialFlyingAnimationFont)
end

function GamepadOptions.BuildRadialFlyingAnimationFontSizeOption()
    local p = NQOL.Features.PlayerBars
    return GamepadOptions.BuildValueStepSliderOption(GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID, 23, p.GetRadialFlyingAnimationFontSizeLabel(), p.GetRadialFlyingAnimationFontSizeTooltip(), p.GetRadialFlyingAnimationFontSizeMin(), p.GetRadialFlyingAnimationFontSizeMax(), "%.0f", p.GetRadialFlyingAnimationFontSize, p.SetRadialFlyingAnimationFontSize, 1)
end

function GamepadOptions.BuildPlayerBarsShowInSettingsOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_PANEL_ID, 3, playerBars.GetShowInSettingsLabel(), playerBars.GetShowInSettingsTooltip(), playerBars.GetShowInSettings, playerBars.SetShowInSettings)
end

function GamepadOptions.BuildPlayerBarsShowTraumaOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_PANEL_ID, 4, playerBars.GetShowTraumaLabel(), playerBars.GetShowTraumaTooltip(), playerBars.GetShowTrauma, playerBars.SetShowTrauma)
end

function GamepadOptions.BuildPlayerBarsShowShieldOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_PANEL_ID, 12, playerBars.GetShowShieldLabel(), playerBars.GetShowShieldTooltip(), playerBars.GetShowShield, playerBars.SetShowShield)
end

function GamepadOptions.BuildPlayerBarsShowNoHealingOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_PANEL_ID, 5, playerBars.GetShowNoHealingLabel(), playerBars.GetShowNoHealingTooltip(), playerBars.GetShowNoHealing, playerBars.SetShowNoHealing)
end

function GamepadOptions.BuildCompanionShowInSettingsOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.COMPANION_FRAME_PANEL_ID, 3, playerBars.GetCompanionShowInSettingsLabel(), playerBars.GetCompanionShowInSettingsTooltip(), playerBars.GetCompanionShowInSettings, playerBars.SetCompanionShowInSettings)
end

function GamepadOptions.BuildGroupShowInSettingsOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 3, playerBars.GetGroupShowInSettingsLabel(), playerBars.GetGroupShowInSettingsTooltip(), playerBars.GetGroupShowInSettings, playerBars.SetGroupShowInSettings)
end

function GamepadOptions.BuildGroupShowShieldOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 36, playerBars.GetGroupShowShieldLabel(), playerBars.GetGroupShowShieldTooltip(), playerBars.GetGroupShowShield, playerBars.SetGroupShowShield)
end

function GamepadOptions.BuildGroupShowTraumaOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 4, playerBars.GetGroupShowTraumaLabel(), playerBars.GetGroupShowTraumaTooltip(), playerBars.GetGroupShowTrauma, playerBars.SetGroupShowTrauma)
end

function GamepadOptions.BuildGroupShowNoHealingOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 5, playerBars.GetGroupShowNoHealingLabel(), playerBars.GetGroupShowNoHealingTooltip(), playerBars.GetGroupShowNoHealing, playerBars.SetGroupShowNoHealing)
end

function GamepadOptions.BuildCompanionOrientationOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.COMPANION_FRAME_PANEL_ID, 6, playerBars.GetCompanionOrientationLabel(), playerBars.GetCompanionOrientationTooltip(), playerBars.GetCompanionOrientationChoices(), playerBars.GetCompanionOrientationChoiceNames(), playerBars.GetCompanionOrientation, playerBars.SetCompanionOrientation)
end

function GamepadOptions.BuildCompanionHorizontalPositionOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildPositionSliderOption(GamepadOptions.COMPANION_FRAME_PANEL_ID, 4, playerBars.GetHorizontalPositionLabel(), playerBars.GetHorizontalPositionTooltip(), 0, 100, "%.0f", playerBars.GetCompanionHorizontalPosition, playerBars.SetCompanionHorizontalPosition)
end

function GamepadOptions.BuildGroupHorizontalPositionOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildPositionSliderOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 6, playerBars.GetHorizontalPositionLabel(), playerBars.GetHorizontalPositionTooltip(), 0, 100, "%.0f", playerBars.GetGroupHorizontalPosition, playerBars.SetGroupHorizontalPosition)
end

function GamepadOptions.BuildCompanionVerticalPositionOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildPositionSliderOption(GamepadOptions.COMPANION_FRAME_PANEL_ID, 5, playerBars.GetVerticalPositionLabel(), playerBars.GetVerticalPositionTooltip(), 0, 100, "%.0f", playerBars.GetCompanionVerticalPosition, playerBars.SetCompanionVerticalPosition)
end

function GamepadOptions.BuildGroupVerticalPositionOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildPositionSliderOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 7, playerBars.GetVerticalPositionLabel(), playerBars.GetVerticalPositionTooltip(), 0, 100, "%.0f", playerBars.GetGroupVerticalPosition, playerBars.SetGroupVerticalPosition)
end

function GamepadOptions.BuildCompanionWidthOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.COMPANION_FRAME_PANEL_ID, 7, playerBars.GetCompanionWidthLabel(), playerBars.GetCompanionWidthTooltip(), playerBars.GetCompanionWidthMin(), playerBars.GetCompanionWidthMax(), "%.0f", playerBars.GetCompanionWidth, playerBars.SetCompanionWidth, 1)
end

function GamepadOptions.BuildGroupWidthOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 8, playerBars.GetGroupWidthLabel(), playerBars.GetGroupWidthTooltip(), playerBars.GetGroupWidthMin(), playerBars.GetGroupWidthMax(), "%.0f", playerBars.GetGroupWidth, playerBars.SetGroupWidth, 1)
end

function GamepadOptions.BuildCompanionHeightOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.COMPANION_FRAME_PANEL_ID, 8, playerBars.GetCompanionHeightLabel(), playerBars.GetCompanionHeightTooltip(), playerBars.GetCompanionHeightMin(), playerBars.GetCompanionHeightMax(), "%.0f", playerBars.GetCompanionHeight, playerBars.SetCompanionHeight, 2)
end

function GamepadOptions.BuildGroupHeightOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 9, playerBars.GetGroupHeightLabel(), playerBars.GetGroupHeightTooltip(), playerBars.GetGroupHeightMin(), playerBars.GetGroupHeightMax(), "%.0f", playerBars.GetGroupHeight, playerBars.SetGroupHeight, 2)
end

function GamepadOptions.BuildGroupColumnsOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildValueStepSliderOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 38, playerBars.GetGroupColumnsLabel(), playerBars.GetGroupColumnsTooltip(), playerBars.GetGroupColumnsMin(), playerBars.GetGroupColumnsMax(), "%.0f", playerBars.GetGroupColumns, playerBars.SetGroupColumns, 1, nil, playerBars.GetGroupColumnsDefault)
end

function GamepadOptions.BuildGroupRowGapOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 10, playerBars.GetGroupRowGapLabel(), playerBars.GetGroupRowGapTooltip(), playerBars.GetGroupRowGapMin(), playerBars.GetGroupRowGapMax(), "%.0f", playerBars.GetGroupRowGap, playerBars.SetGroupRowGap, 5)
end

function GamepadOptions.BuildGroupColumnGapOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 39, playerBars.GetGroupColumnGapLabel(), playerBars.GetGroupColumnGapTooltip(), playerBars.GetGroupColumnGapMin(), playerBars.GetGroupColumnGapMax(), "%.0f", playerBars.GetGroupColumnGap, playerBars.SetGroupColumnGap, 5)
end

function GamepadOptions.BuildCompanionBorderSizeOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.COMPANION_FRAME_PANEL_ID, 11, playerBars.GetCompanionBorderSizeLabel(), playerBars.GetCompanionBorderSizeTooltip(), playerBars.GetCompanionBorderSizeMin(), playerBars.GetCompanionBorderSizeMax(), "%.0f", playerBars.GetCompanionBorderSize, playerBars.SetCompanionBorderSize, 1)
end

function GamepadOptions.BuildGroupBorderSizeOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 13, playerBars.GetGroupBorderSizeLabel(), playerBars.GetGroupBorderSizeTooltip(), playerBars.GetGroupBorderSizeMin(), playerBars.GetGroupBorderSizeMax(), "%.0f", playerBars.GetGroupBorderSize, playerBars.SetGroupBorderSize, 1)
end

function GamepadOptions.BuildCompanionFontOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.COMPANION_FRAME_PANEL_ID, 9, playerBars.GetCompanionFontLabel(), playerBars.GetCompanionFontTooltip(), playerBars.GetCompanionFontChoices(), playerBars.GetCompanionFontChoiceNames(), playerBars.GetCompanionFont, playerBars.SetCompanionFont)
end

function GamepadOptions.BuildGroupFontOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 11, playerBars.GetGroupFontLabel(), playerBars.GetGroupFontTooltip(), playerBars.GetGroupFontChoices(), playerBars.GetGroupFontChoiceNames(), playerBars.GetGroupFont, playerBars.SetGroupFont)
end

function GamepadOptions.BuildCompanionFontSizeOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildValueStepSliderOption(GamepadOptions.COMPANION_FRAME_PANEL_ID, 10, playerBars.GetCompanionFontSizeLabel(), playerBars.GetCompanionFontSizeTooltip(), playerBars.GetCompanionFontSizeMin(), playerBars.GetCompanionFontSizeMax(), "%.0f", playerBars.GetCompanionFontSize, playerBars.SetCompanionFontSize, 1)
end

function GamepadOptions.BuildGroupFontSizeOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildValueStepSliderOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 12, playerBars.GetGroupFontSizeLabel(), playerBars.GetGroupFontSizeTooltip(), playerBars.GetGroupFontSizeMin(), playerBars.GetGroupFontSizeMax(), "%.0f", playerBars.GetGroupFontSize, playerBars.SetGroupFontSize, 1)
end

function GamepadOptions.BuildCompanionShowNameOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.COMPANION_FRAME_PANEL_ID, 13, playerBars.GetCompanionShowNameLabel(), playerBars.GetCompanionShowNameTooltip(), playerBars.GetCompanionShowName, playerBars.SetCompanionShowName)
end

function GamepadOptions.BuildCompanionShowRapportOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.COMPANION_FRAME_PANEL_ID, 15, playerBars.GetCompanionShowRapportLabel(), playerBars.GetCompanionShowRapportTooltip(), playerBars.GetCompanionShowRapport, playerBars.SetCompanionShowRapport)
end

function GamepadOptions.BuildCompanionShowXpProgressOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.COMPANION_FRAME_PANEL_ID, 16, playerBars.GetCompanionShowXpProgressLabel(), playerBars.GetCompanionShowXpProgressTooltip(), playerBars.GetCompanionShowXpProgress, playerBars.SetCompanionShowXpProgress)
end

function GamepadOptions.BuildGroupNameDisplayOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 15, playerBars.GetGroupNameDisplayLabel(), playerBars.GetGroupNameDisplayTooltip(), playerBars.GetGroupNameDisplayChoices(), playerBars.GetGroupNameDisplayChoiceNames(), playerBars.GetGroupNameDisplay, playerBars.SetGroupNameDisplay)
end

function GamepadOptions.BuildGroupShowClassOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 16, playerBars.GetGroupShowClassLabel(), playerBars.GetGroupShowClassTooltip(), playerBars.GetGroupShowClass, playerBars.SetGroupShowClass, nil, playerBars.GetGroupShowClassDefault)
end

function GamepadOptions.BuildGroupShowTargetMarkerOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 19, playerBars.GetGroupShowTargetMarkerLabel(), playerBars.GetGroupShowTargetMarkerTooltip(), playerBars.GetGroupShowTargetMarker, playerBars.SetGroupShowTargetMarker, nil, playerBars.GetGroupShowTargetMarkerDefault)
end

function GamepadOptions.BuildGroupShowChampionPointsOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 27, playerBars.GetGroupShowChampionPointsLabel(), playerBars.GetGroupShowChampionPointsTooltip(), playerBars.GetGroupShowChampionPoints, playerBars.SetGroupShowChampionPoints, nil, playerBars.GetGroupShowChampionPointsDefault)
end

function GamepadOptions.BuildGroupShowCompanionsOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 29, playerBars.GetGroupShowCompanionsLabel(), playerBars.GetGroupShowCompanionsTooltip(), playerBars.GetGroupShowCompanions, playerBars.SetGroupShowCompanions, nil, playerBars.GetGroupShowCompanionsDefault)
end

function GamepadOptions.BuildGroupChampionPointsPlacementOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 28, playerBars.GetGroupChampionPointsPlacementLabel(), playerBars.GetGroupChampionPointsPlacementTooltip(), playerBars.GetGroupChampionPointsPlacementChoices(), playerBars.GetGroupChampionPointsPlacementChoiceNames(), playerBars.GetGroupChampionPointsPlacement, playerBars.SetGroupChampionPointsPlacement)
end

function GamepadOptions.BuildGroupShowLeaderOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 17, playerBars.GetGroupShowLeaderLabel(), playerBars.GetGroupShowLeaderTooltip(), playerBars.GetGroupShowLeader, playerBars.SetGroupShowLeader)
end

function GamepadOptions.BuildGroupShowDeathCounterOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 26, playerBars.GetGroupShowDeathCounterLabel(), playerBars.GetGroupShowDeathCounterTooltip(), playerBars.GetGroupShowDeathCounter, playerBars.SetGroupShowDeathCounter)
end

function GamepadOptions.BuildGroupShowResurrectingColorOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 32, playerBars.GetGroupShowResurrectingColorLabel(), playerBars.GetGroupShowResurrectingColorTooltip(), playerBars.GetGroupShowResurrectingColor, playerBars.SetGroupShowResurrectingColor)
end

function GamepadOptions.BuildGroupDimAwayOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 25, playerBars.GetGroupDimAwayLabel(), playerBars.GetGroupDimAwayTooltip(), 0, 100, "%.0f%%", playerBars.GetGroupDimAwayOpacity, playerBars.SetGroupDimAwayOpacity, 1, nil, playerBars.GetGroupDimAwayOpacityDefault)
end

function GamepadOptions.BuildCompanionCurrentValueOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.COMPANION_FRAME_PANEL_ID, 14, playerBars.GetCurrentValueLabel(), playerBars.GetCompanionCurrentValueTooltip(), playerBars.GetCurrentValueChoices(), playerBars.GetCurrentValueChoiceNames(), playerBars.GetCompanionCurrentValue, playerBars.SetCompanionCurrentValue)
end

function GamepadOptions.BuildGroupCurrentValueOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 18, playerBars.GetCurrentValueLabel(), playerBars.GetGroupCurrentValueTooltip(), playerBars.GetCurrentValueChoices(), playerBars.GetCurrentValueChoiceNames(), playerBars.GetGroupCurrentValue, playerBars.SetGroupCurrentValue)
end

function GamepadOptions.BuildCompanionSmoothTransitionsOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.COMPANION_FRAME_PANEL_ID, 19, playerBars.GetSmoothTransitionsLabel(), playerBars.GetSmoothTransitionsTooltip(), playerBars.GetCompanionSmoothTransitions, playerBars.SetCompanionSmoothTransitions)
end

function GamepadOptions.BuildCompanionTransitionShadowOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.COMPANION_FRAME_PANEL_ID, 20, playerBars.GetTransitionShadowLabel(), playerBars.GetTransitionShadowTooltip(), playerBars.GetCompanionTransitionShadow, playerBars.SetCompanionTransitionShadow)
end

function GamepadOptions.BuildCompanionHealthBarColorOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildColorOption(GamepadOptions.COMPANION_FRAME_PANEL_ID, 21, playerBars.GetCompanionHealthBarColorLabel(), playerBars.GetCompanionHealthBarColorTooltip(), playerBars.GetCompanionHealthBarColor, playerBars.SetCompanionHealthBarColor)
end

function GamepadOptions.BuildCompanionXpColorOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildColorOption(GamepadOptions.COMPANION_FRAME_PANEL_ID, 22, playerBars.GetCompanionXpColorLabel(), playerBars.GetCompanionXpColorTooltip(), playerBars.GetCompanionXpColor, playerBars.SetCompanionXpColor)
end

function GamepadOptions.BuildGroupSmoothTransitionsOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 30, playerBars.GetSmoothTransitionsLabel(), playerBars.GetSmoothTransitionsTooltip(), playerBars.GetGroupSmoothTransitions, playerBars.SetGroupSmoothTransitions)
end

function GamepadOptions.BuildGroupTransitionShadowOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 31, playerBars.GetTransitionShadowLabel(), playerBars.GetTransitionShadowTooltip(), playerBars.GetGroupTransitionShadow, playerBars.SetGroupTransitionShadow)
end

function GamepadOptions.BuildCompanionReverseOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.COMPANION_FRAME_PANEL_ID, 12, playerBars.GetCompanionReverseLabel(), playerBars.GetCompanionReverseTooltip(), playerBars.GetCompanionReverse, playerBars.SetCompanionReverse)
end

function GamepadOptions.BuildCompanionShadowOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.COMPANION_FRAME_PANEL_ID, 17, playerBars.GetCompanionShadowLabel(), playerBars.GetCompanionShadowTooltip(), playerBars.GetCompanionShadowChoices(), playerBars.GetCompanionShadowChoiceNames(), playerBars.GetCompanionShadow, playerBars.SetCompanionShadow)
end

function GamepadOptions.BuildCompanionShadowIntensityOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.COMPANION_FRAME_PANEL_ID, 18, playerBars.GetCompanionShadowIntensityLabel(), playerBars.GetCompanionShadowIntensityTooltip(), playerBars.GetCompanionShadowIntensityMin(), playerBars.GetCompanionShadowIntensityMax(), "%.0f%%", playerBars.GetCompanionShadowIntensity, playerBars.SetCompanionShadowIntensity, 1, nil, playerBars.GetCompanionShadowIntensityDefault)
end

function GamepadOptions.BuildGroupReverseOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 14, playerBars.GetGroupReverseLabel(), playerBars.GetGroupReverseTooltip(), playerBars.GetGroupReverse, playerBars.SetGroupReverse)
end

function GamepadOptions.BuildGroupShadowOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 23, playerBars.GetShadowLabel(), playerBars.GetGroupShadowTooltip(), playerBars.GetShadowChoices(), playerBars.GetShadowChoiceNames(), playerBars.GetGroupShadow, playerBars.SetGroupShadow)
end

function GamepadOptions.BuildGroupShadowIntensityOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 24, playerBars.GetShadowIntensityLabel(), playerBars.GetShadowIntensityTooltip(), playerBars.GetShadowIntensityMin(), playerBars.GetShadowIntensityMax(), "%.0f%%", playerBars.GetGroupShadowIntensity, playerBars.SetGroupShadowIntensity, 1, nil, playerBars.GetGroupShadowIntensityDefault)
end

function GamepadOptions.BuildGroupDamageColorOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildColorOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 20, playerBars.GetGroupDamageColorLabel(), playerBars.GetGroupDamageColorTooltip(), playerBars.GetGroupDamageColor, playerBars.SetGroupDamageColor)
end

function GamepadOptions.BuildGroupTankColorOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildColorOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 21, playerBars.GetGroupTankColorLabel(), playerBars.GetGroupTankColorTooltip(), playerBars.GetGroupTankColor, playerBars.SetGroupTankColor)
end

function GamepadOptions.BuildGroupHealerColorOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildColorOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 22, playerBars.GetGroupHealerColorLabel(), playerBars.GetGroupHealerColorTooltip(), playerBars.GetGroupHealerColor, playerBars.SetGroupHealerColor)
end

function GamepadOptions.BuildGroupShieldColorOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildColorOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 37, playerBars.GetGroupShieldColorLabel(), playerBars.GetGroupShieldColorTooltip(), playerBars.GetGroupShieldColor, playerBars.SetGroupShieldColor)
end

function GamepadOptions.BuildGroupTraumaColorOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildColorOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 35, playerBars.GetGroupTraumaColorLabel(), playerBars.GetGroupTraumaColorTooltip(), playerBars.GetGroupTraumaColor, playerBars.SetGroupTraumaColor)
end

function GamepadOptions.BuildGroupResurrectingColorOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildColorOption(GamepadOptions.GROUP_FRAME_PANEL_ID, 33, playerBars.GetGroupResurrectingColorLabel(), playerBars.GetGroupResurrectingColorTooltip(), playerBars.GetGroupResurrectingColor, playerBars.SetGroupResurrectingColor)
end

function GamepadOptions.BuildClassicHorizontalPositionOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildPositionSliderOption(GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID, 1, playerBars.GetHorizontalPositionLabel(), playerBars.GetHorizontalPositionTooltip(), 0, 100, "%.0f", playerBars.GetClassicHorizontalPosition, playerBars.SetClassicHorizontalPosition)
end

function GamepadOptions.BuildClassicVerticalPositionOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildPositionSliderOption(GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID, 2, playerBars.GetVerticalPositionLabel(), playerBars.GetVerticalPositionTooltip(), 0, 100, "%.0f", playerBars.GetClassicVerticalPosition, playerBars.SetClassicVerticalPosition)
end

function GamepadOptions.BuildClassicBoxHeightOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID, 5, playerBars.GetClassicBoxHeightLabel(), playerBars.GetClassicBoxHeightTooltip(), 10, 80, "%.0f", playerBars.GetClassicBoxHeight, playerBars.SetClassicBoxHeight, 2)
end

function GamepadOptions.BuildClassicSeparationOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID, 6, playerBars.GetClassicSeparationLabel(), playerBars.GetClassicSeparationTooltip(), 0, 160, "%.0f", playerBars.GetClassicSeparation, playerBars.SetClassicSeparation, 1)
end

function GamepadOptions.BuildClassicHealthWidthOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID, 7, playerBars.GetClassicHealthWidthLabel(), playerBars.GetClassicHealthWidthTooltip(), 80, 600, "%.0f", playerBars.GetClassicHealthWidth, playerBars.SetClassicHealthWidth, 1)
end

function GamepadOptions.BuildClassicMagickaWidthOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID, 8, playerBars.GetClassicMagickaWidthLabel(), playerBars.GetClassicMagickaWidthTooltip(), 80, 600, "%.0f", playerBars.GetClassicMagickaWidth, playerBars.SetClassicMagickaWidth, 1)
end

function GamepadOptions.BuildClassicStaminaWidthOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID, 9, playerBars.GetClassicStaminaWidthLabel(), playerBars.GetClassicStaminaWidthTooltip(), 80, 600, "%.0f", playerBars.GetClassicStaminaWidth, playerBars.SetClassicStaminaWidth, 1)
end

function GamepadOptions.BuildClassicFontOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID, 3, playerBars.GetClassicFontLabel(), playerBars.GetClassicFontTooltip(), playerBars.GetClassicFontChoices(), playerBars.GetClassicFontChoiceNames(), playerBars.GetClassicFont, playerBars.SetClassicFont)
end

function GamepadOptions.BuildClassicFontSizeOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildValueStepSliderOption(GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID, 4, playerBars.GetClassicFontSizeLabel(), playerBars.GetClassicFontSizeTooltip(), playerBars.GetClassicFontSizeMin(), playerBars.GetClassicFontSizeMax(), "%.0f", playerBars.GetClassicFontSize, playerBars.SetClassicFontSize, 1)
end

function GamepadOptions.BuildClassicCurrentValueOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID, 17, playerBars.GetCurrentValueLabel(), playerBars.GetClassicCurrentValueTooltip(), playerBars.GetCurrentValueChoices(), playerBars.GetCurrentValueChoiceNames(), playerBars.GetClassicCurrentValue, playerBars.SetClassicCurrentValue)
end

function GamepadOptions.BuildClassicBorderSizeOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID, 10, playerBars.GetClassicBorderSizeLabel(), playerBars.GetClassicBorderSizeTooltip(), playerBars.GetClassicBorderSizeMin(), playerBars.GetClassicBorderSizeMax(), "%.0f", playerBars.GetClassicBorderSize, playerBars.SetClassicBorderSize, 1)
end

function GamepadOptions.BuildClassicSmoothTransitionsOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID, 20, playerBars.GetSmoothTransitionsLabel(), playerBars.GetSmoothTransitionsTooltip(), playerBars.GetClassicSmoothTransitions, playerBars.SetClassicSmoothTransitions)
end

function GamepadOptions.BuildClassicTransitionShadowOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID, 21, playerBars.GetTransitionShadowLabel(), playerBars.GetTransitionShadowTooltip(), playerBars.GetClassicTransitionShadow, playerBars.SetClassicTransitionShadow)
end

function GamepadOptions.BuildClassicFlyingPositiveAnimationOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID, 11, playerBars.GetClassicFlyingPositiveAnimationLabel(), playerBars.GetClassicFlyingPositiveAnimationTooltip(), playerBars.GetClassicFlyingPositiveAnimation, playerBars.SetClassicFlyingPositiveAnimation)
end

function GamepadOptions.BuildClassicFlyingNegativeAnimationOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID, 12, playerBars.GetClassicFlyingNegativeAnimationLabel(), playerBars.GetClassicFlyingNegativeAnimationTooltip(), playerBars.GetClassicFlyingNegativeAnimation, playerBars.SetClassicFlyingNegativeAnimation)
end

function GamepadOptions.BuildClassicFlyingAnimationFontOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID, 13, playerBars.GetClassicFlyingAnimationFontLabel(), playerBars.GetClassicFlyingAnimationFontTooltip(), playerBars.GetClassicFlyingAnimationFontChoices(), playerBars.GetClassicFlyingAnimationFontChoiceNames(), playerBars.GetClassicFlyingAnimationFont, playerBars.SetClassicFlyingAnimationFont)
end

function GamepadOptions.BuildClassicFlyingAnimationFontSizeOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildValueStepSliderOption(GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID, 14, playerBars.GetClassicFlyingAnimationFontSizeLabel(), playerBars.GetClassicFlyingAnimationFontSizeTooltip(), playerBars.GetClassicFlyingAnimationFontSizeMin(), playerBars.GetClassicFlyingAnimationFontSizeMax(), "%.0f", playerBars.GetClassicFlyingAnimationFontSize, playerBars.SetClassicFlyingAnimationFontSize, 1)
end

function GamepadOptions.BuildPyramidHorizontalPositionOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildPositionSliderOption(GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID, 1, playerBars.GetHorizontalPositionLabel(), playerBars.GetHorizontalPositionTooltip(), 0, 100, "%.0f", playerBars.GetPyramidHorizontalPosition, playerBars.SetPyramidHorizontalPosition)
end

function GamepadOptions.BuildPyramidVerticalPositionOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildPositionSliderOption(GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID, 2, playerBars.GetVerticalPositionLabel(), playerBars.GetVerticalPositionTooltip(), 0, 100, "%.0f", playerBars.GetPyramidVerticalPosition, playerBars.SetPyramidVerticalPosition)
end

function GamepadOptions.BuildPyramidHealthHeightOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID, 5, playerBars.GetPyramidHealthHeightLabel(), playerBars.GetPyramidHealthHeightTooltip(), 10, 80, "%.0f", playerBars.GetPyramidHealthHeight, playerBars.SetPyramidHealthHeight, 2)
end

function GamepadOptions.BuildPyramidResourceHeightOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID, 19, playerBars.GetPyramidResourceHeightLabel(), playerBars.GetPyramidResourceHeightTooltip(), 10, 80, "%.0f", playerBars.GetPyramidResourceHeight, playerBars.SetPyramidResourceHeight, 2)
end

function GamepadOptions.BuildPyramidHealthWidthOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID, 6, playerBars.GetPyramidHealthWidthLabel(), playerBars.GetPyramidHealthWidthTooltip(), 80, 600, "%.0f", playerBars.GetPyramidHealthWidth, playerBars.SetPyramidHealthWidth, 1)
end

function GamepadOptions.BuildPyramidMagickaWidthOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID, 7, playerBars.GetPyramidMagickaWidthLabel(), playerBars.GetPyramidMagickaWidthTooltip(), 80, 600, "%.0f", playerBars.GetPyramidMagickaWidth, playerBars.SetPyramidMagickaWidth, 1)
end

function GamepadOptions.BuildPyramidStaminaWidthOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID, 8, playerBars.GetPyramidStaminaWidthLabel(), playerBars.GetPyramidStaminaWidthTooltip(), 80, 600, "%.0f", playerBars.GetPyramidStaminaWidth, playerBars.SetPyramidStaminaWidth, 1)
end

function GamepadOptions.BuildPyramidBorderSizeOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID, 9, playerBars.GetPyramidBorderSizeLabel(), playerBars.GetPyramidBorderSizeTooltip(), playerBars.GetPyramidBorderSizeMin(), playerBars.GetPyramidBorderSizeMax(), "%.0f", playerBars.GetPyramidBorderSize, playerBars.SetPyramidBorderSize, 1)
end

function GamepadOptions.BuildPyramidSmoothTransitionsOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID, 20, playerBars.GetSmoothTransitionsLabel(), playerBars.GetSmoothTransitionsTooltip(), playerBars.GetPyramidSmoothTransitions, playerBars.SetPyramidSmoothTransitions)
end

function GamepadOptions.BuildPyramidTransitionShadowOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID, 21, playerBars.GetTransitionShadowLabel(), playerBars.GetTransitionShadowTooltip(), playerBars.GetPyramidTransitionShadow, playerBars.SetPyramidTransitionShadow)
end

function GamepadOptions.BuildPyramidFontOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID, 3, playerBars.GetPyramidFontLabel(), playerBars.GetPyramidFontTooltip(), playerBars.GetPyramidFontChoices(), playerBars.GetPyramidFontChoiceNames(), playerBars.GetPyramidFont, playerBars.SetPyramidFont)
end

function GamepadOptions.BuildPyramidFontSizeOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildValueStepSliderOption(GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID, 4, playerBars.GetPyramidFontSizeLabel(), playerBars.GetPyramidFontSizeTooltip(), playerBars.GetPyramidFontSizeMin(), playerBars.GetPyramidFontSizeMax(), "%.0f", playerBars.GetPyramidFontSize, playerBars.SetPyramidFontSize, 1)
end

function GamepadOptions.BuildPyramidCurrentValueOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID, 16, playerBars.GetCurrentValueLabel(), playerBars.GetPyramidCurrentValueTooltip(), playerBars.GetCurrentValueChoices(), playerBars.GetCurrentValueChoiceNames(), playerBars.GetPyramidCurrentValue, playerBars.SetPyramidCurrentValue)
end

function GamepadOptions.BuildPyramidFlyingPositiveAnimationOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID, 10, playerBars.GetPyramidFlyingPositiveAnimationLabel(), playerBars.GetPyramidFlyingPositiveAnimationTooltip(), playerBars.GetPyramidFlyingPositiveAnimation, playerBars.SetPyramidFlyingPositiveAnimation)
end

function GamepadOptions.BuildPyramidFlyingNegativeAnimationOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID, 11, playerBars.GetPyramidFlyingNegativeAnimationLabel(), playerBars.GetPyramidFlyingNegativeAnimationTooltip(), playerBars.GetPyramidFlyingNegativeAnimation, playerBars.SetPyramidFlyingNegativeAnimation)
end

function GamepadOptions.BuildPyramidFlyingAnimationFontOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID, 12, playerBars.GetPyramidFlyingAnimationFontLabel(), playerBars.GetPyramidFlyingAnimationFontTooltip(), playerBars.GetPyramidFlyingAnimationFontChoices(), playerBars.GetPyramidFlyingAnimationFontChoiceNames(), playerBars.GetPyramidFlyingAnimationFont, playerBars.SetPyramidFlyingAnimationFont)
end

function GamepadOptions.BuildPyramidFlyingAnimationFontSizeOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildValueStepSliderOption(GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID, 13, playerBars.GetPyramidFlyingAnimationFontSizeLabel(), playerBars.GetPyramidFlyingAnimationFontSizeTooltip(), playerBars.GetPyramidFlyingAnimationFontSizeMin(), playerBars.GetPyramidFlyingAnimationFontSizeMax(), "%.0f", playerBars.GetPyramidFlyingAnimationFontSize, playerBars.SetPyramidFlyingAnimationFontSize, 1)
end

function GamepadOptions.BuildStackHorizontalPositionOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildPositionSliderOption(GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID, 1, playerBars.GetHorizontalPositionLabel(), playerBars.GetHorizontalPositionTooltip(), 0, 100, "%.0f", playerBars.GetStackHorizontalPosition, playerBars.SetStackHorizontalPosition)
end

function GamepadOptions.BuildStackVerticalPositionOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildPositionSliderOption(GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID, 2, playerBars.GetVerticalPositionLabel(), playerBars.GetVerticalPositionTooltip(), 0, 100, "%.0f", playerBars.GetStackVerticalPosition, playerBars.SetStackVerticalPosition)
end

function GamepadOptions.BuildStackHealthHeightOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID, 5, playerBars.GetStackHealthHeightLabel(), playerBars.GetStackHealthHeightTooltip(), 10, 80, "%.0f", playerBars.GetStackHealthHeight, playerBars.SetStackHealthHeight, 2)
end

function GamepadOptions.BuildStackMagickaHeightOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID, 7, playerBars.GetStackMagickaHeightLabel(), playerBars.GetStackMagickaHeightTooltip(), 10, 80, "%.0f", playerBars.GetStackMagickaHeight, playerBars.SetStackMagickaHeight, 2)
end

function GamepadOptions.BuildStackStaminaHeightOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID, 8, playerBars.GetStackStaminaHeightLabel(), playerBars.GetStackStaminaHeightTooltip(), 10, 80, "%.0f", playerBars.GetStackStaminaHeight, playerBars.SetStackStaminaHeight, 2)
end

function GamepadOptions.BuildStackWidthOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID, 6, playerBars.GetStackWidthLabel(), playerBars.GetStackWidthTooltip(), 80, 600, "%.0f", playerBars.GetStackWidth, playerBars.SetStackWidth, 1)
end

function GamepadOptions.BuildStackBorderSizeOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID, 9, playerBars.GetStackBorderSizeLabel(), playerBars.GetStackBorderSizeTooltip(), playerBars.GetStackBorderSizeMin(), playerBars.GetStackBorderSizeMax(), "%.0f", playerBars.GetStackBorderSize, playerBars.SetStackBorderSize, 1)
end

function GamepadOptions.BuildStackSmoothTransitionsOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID, 21, playerBars.GetSmoothTransitionsLabel(), playerBars.GetSmoothTransitionsTooltip(), playerBars.GetStackSmoothTransitions, playerBars.SetStackSmoothTransitions)
end

function GamepadOptions.BuildStackTransitionShadowOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID, 22, playerBars.GetTransitionShadowLabel(), playerBars.GetTransitionShadowTooltip(), playerBars.GetStackTransitionShadow, playerBars.SetStackTransitionShadow)
end

function GamepadOptions.BuildStackFontOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID, 3, playerBars.GetStackFontLabel(), playerBars.GetStackFontTooltip(), playerBars.GetStackFontChoices(), playerBars.GetStackFontChoiceNames(), playerBars.GetStackFont, playerBars.SetStackFont)
end

function GamepadOptions.BuildStackFontSizeOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildValueStepSliderOption(GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID, 4, playerBars.GetStackFontSizeLabel(), playerBars.GetStackFontSizeTooltip(), playerBars.GetStackFontSizeMin(), playerBars.GetStackFontSizeMax(), "%.0f", playerBars.GetStackFontSize, playerBars.SetStackFontSize, 1)
end

function GamepadOptions.BuildStackCurrentValueOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID, 16, playerBars.GetCurrentValueLabel(), playerBars.GetStackCurrentValueTooltip(), playerBars.GetCurrentValueChoices(), playerBars.GetCurrentValueChoiceNames(), playerBars.GetStackCurrentValue, playerBars.SetStackCurrentValue)
end

function GamepadOptions.BuildStackReverseOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID, 17, playerBars.GetReverseLabel(), playerBars.GetStackReverseTooltip(), playerBars.GetStackReverse, playerBars.SetStackReverse)
end

function GamepadOptions.BuildStackFlyingPositiveAnimationOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID, 10, playerBars.GetStackFlyingPositiveAnimationLabel(), playerBars.GetStackFlyingPositiveAnimationTooltip(), playerBars.GetStackFlyingPositiveAnimation, playerBars.SetStackFlyingPositiveAnimation)
end

function GamepadOptions.BuildStackFlyingNegativeAnimationOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID, 11, playerBars.GetStackFlyingNegativeAnimationLabel(), playerBars.GetStackFlyingNegativeAnimationTooltip(), playerBars.GetStackFlyingNegativeAnimation, playerBars.SetStackFlyingNegativeAnimation)
end

function GamepadOptions.BuildStackFlyingOrientationOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID, 18, playerBars.GetStackFlyingOrientationLabel(), playerBars.GetStackFlyingOrientationTooltip(), playerBars.GetFlyingOrientationChoices(), playerBars.GetFlyingOrientationChoiceNames(), playerBars.GetStackFlyingOrientation, playerBars.SetStackFlyingOrientation)
end

function GamepadOptions.BuildStackFlyingAnimationFontOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID, 12, playerBars.GetStackFlyingAnimationFontLabel(), playerBars.GetStackFlyingAnimationFontTooltip(), playerBars.GetStackFlyingAnimationFontChoices(), playerBars.GetStackFlyingAnimationFontChoiceNames(), playerBars.GetStackFlyingAnimationFont, playerBars.SetStackFlyingAnimationFont)
end

function GamepadOptions.BuildStackFlyingAnimationFontSizeOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildValueStepSliderOption(GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID, 13, playerBars.GetStackFlyingAnimationFontSizeLabel(), playerBars.GetStackFlyingAnimationFontSizeTooltip(), playerBars.GetStackFlyingAnimationFontSizeMin(), playerBars.GetStackFlyingAnimationFontSizeMax(), "%.0f", playerBars.GetStackFlyingAnimationFontSize, playerBars.SetStackFlyingAnimationFontSize, 1)
end

function GamepadOptions.BuildVerticalFontOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 3, playerBars.GetVerticalFontLabel(), playerBars.GetVerticalFontTooltip(), playerBars.GetVerticalFontChoices(), playerBars.GetVerticalFontChoiceNames(), playerBars.GetVerticalFont, playerBars.SetVerticalFont)
end

function GamepadOptions.BuildVerticalFontSizeOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildValueStepSliderOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 4, playerBars.GetVerticalFontSizeLabel(), playerBars.GetVerticalFontSizeTooltip(), playerBars.GetVerticalFontSizeMin(), playerBars.GetVerticalFontSizeMax(), "%.0f", playerBars.GetVerticalFontSize, playerBars.SetVerticalFontSize, 1)
end

function GamepadOptions.BuildVerticalHealthWidthOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 5, playerBars.GetVerticalHealthWidthLabel(), playerBars.GetVerticalHealthWidthTooltip(), 10, 160, "%.0f", playerBars.GetVerticalHealthWidth, playerBars.SetVerticalHealthWidth, 1)
end

function GamepadOptions.BuildVerticalHealthHeightOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 6, playerBars.GetVerticalHealthHeightLabel(), playerBars.GetVerticalHealthHeightTooltip(), 40, 400, "%.0f", playerBars.GetVerticalHealthHeight, playerBars.SetVerticalHealthHeight, 2)
end

function GamepadOptions.BuildVerticalHealthXOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildPositionSliderOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 7, playerBars.GetVerticalHealthXLabel(), playerBars.GetVerticalHealthXTooltip(), 0, 100, "%.0f", playerBars.GetVerticalHealthX, playerBars.SetVerticalHealthX)
end

function GamepadOptions.BuildVerticalHealthYOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildPositionSliderOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 8, playerBars.GetVerticalHealthYLabel(), playerBars.GetVerticalHealthYTooltip(), 0, 100, "%.0f", playerBars.GetVerticalHealthY, playerBars.SetVerticalHealthY)
end

function GamepadOptions.BuildVerticalHealthFlyingOrientationOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 24, playerBars.GetVerticalFlyingOrientationLabel(), playerBars.GetVerticalHealthFlyingOrientationTooltip(), playerBars.GetFlyingOrientationChoices(), playerBars.GetFlyingOrientationChoiceNames(), playerBars.GetVerticalHealthFlyingOrientation, playerBars.SetVerticalHealthFlyingOrientation)
end

function GamepadOptions.BuildVerticalHealthReverseOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 27, playerBars.GetReverseLabel(), playerBars.GetVerticalHealthReverseTooltip(), playerBars.GetVerticalHealthReverse, playerBars.SetVerticalHealthReverse)
end

function GamepadOptions.BuildVerticalHealthCurrentValueOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 30, playerBars.GetCurrentValueLabel(), playerBars.GetVerticalHealthCurrentValueTooltip(), playerBars.GetCurrentValueChoices(), playerBars.GetCurrentValueChoiceNames(), playerBars.GetVerticalHealthCurrentValue, playerBars.SetVerticalHealthCurrentValue)
end

function GamepadOptions.BuildVerticalMagickaWidthOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 9, playerBars.GetVerticalMagickaWidthLabel(), playerBars.GetVerticalMagickaWidthTooltip(), 10, 160, "%.0f", playerBars.GetVerticalMagickaWidth, playerBars.SetVerticalMagickaWidth, 1)
end

function GamepadOptions.BuildVerticalMagickaHeightOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 10, playerBars.GetVerticalMagickaHeightLabel(), playerBars.GetVerticalMagickaHeightTooltip(), 40, 400, "%.0f", playerBars.GetVerticalMagickaHeight, playerBars.SetVerticalMagickaHeight, 2)
end

function GamepadOptions.BuildVerticalMagickaXOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildPositionSliderOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 11, playerBars.GetVerticalMagickaXLabel(), playerBars.GetVerticalMagickaXTooltip(), 0, 100, "%.0f", playerBars.GetVerticalMagickaX, playerBars.SetVerticalMagickaX)
end

function GamepadOptions.BuildVerticalMagickaYOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildPositionSliderOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 12, playerBars.GetVerticalMagickaYLabel(), playerBars.GetVerticalMagickaYTooltip(), 0, 100, "%.0f", playerBars.GetVerticalMagickaY, playerBars.SetVerticalMagickaY)
end

function GamepadOptions.BuildVerticalMagickaFlyingOrientationOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 25, playerBars.GetVerticalFlyingOrientationLabel(), playerBars.GetVerticalMagickaFlyingOrientationTooltip(), playerBars.GetFlyingOrientationChoices(), playerBars.GetFlyingOrientationChoiceNames(), playerBars.GetVerticalMagickaFlyingOrientation, playerBars.SetVerticalMagickaFlyingOrientation)
end

function GamepadOptions.BuildVerticalMagickaReverseOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 28, playerBars.GetReverseLabel(), playerBars.GetVerticalMagickaReverseTooltip(), playerBars.GetVerticalMagickaReverse, playerBars.SetVerticalMagickaReverse)
end

function GamepadOptions.BuildVerticalMagickaCurrentValueOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 31, playerBars.GetCurrentValueLabel(), playerBars.GetVerticalMagickaCurrentValueTooltip(), playerBars.GetCurrentValueChoices(), playerBars.GetCurrentValueChoiceNames(), playerBars.GetVerticalMagickaCurrentValue, playerBars.SetVerticalMagickaCurrentValue)
end

function GamepadOptions.BuildVerticalStaminaWidthOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 13, playerBars.GetVerticalStaminaWidthLabel(), playerBars.GetVerticalStaminaWidthTooltip(), 10, 160, "%.0f", playerBars.GetVerticalStaminaWidth, playerBars.SetVerticalStaminaWidth, 1)
end

function GamepadOptions.BuildVerticalStaminaHeightOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 14, playerBars.GetVerticalStaminaHeightLabel(), playerBars.GetVerticalStaminaHeightTooltip(), 40, 400, "%.0f", playerBars.GetVerticalStaminaHeight, playerBars.SetVerticalStaminaHeight, 2)
end

function GamepadOptions.BuildVerticalStaminaXOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildPositionSliderOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 15, playerBars.GetVerticalStaminaXLabel(), playerBars.GetVerticalStaminaXTooltip(), 0, 100, "%.0f", playerBars.GetVerticalStaminaX, playerBars.SetVerticalStaminaX)
end

function GamepadOptions.BuildVerticalStaminaYOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildPositionSliderOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 16, playerBars.GetVerticalStaminaYLabel(), playerBars.GetVerticalStaminaYTooltip(), 0, 100, "%.0f", playerBars.GetVerticalStaminaY, playerBars.SetVerticalStaminaY)
end

function GamepadOptions.BuildVerticalStaminaFlyingOrientationOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 26, playerBars.GetVerticalFlyingOrientationLabel(), playerBars.GetVerticalStaminaFlyingOrientationTooltip(), playerBars.GetFlyingOrientationChoices(), playerBars.GetFlyingOrientationChoiceNames(), playerBars.GetVerticalStaminaFlyingOrientation, playerBars.SetVerticalStaminaFlyingOrientation)
end

function GamepadOptions.BuildVerticalStaminaReverseOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 29, playerBars.GetReverseLabel(), playerBars.GetVerticalStaminaReverseTooltip(), playerBars.GetVerticalStaminaReverse, playerBars.SetVerticalStaminaReverse)
end

function GamepadOptions.BuildVerticalStaminaCurrentValueOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 32, playerBars.GetCurrentValueLabel(), playerBars.GetVerticalStaminaCurrentValueTooltip(), playerBars.GetCurrentValueChoices(), playerBars.GetCurrentValueChoiceNames(), playerBars.GetVerticalStaminaCurrentValue, playerBars.SetVerticalStaminaCurrentValue)
end

function GamepadOptions.BuildVerticalBorderSizeOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 17, playerBars.GetVerticalBorderSizeLabel(), playerBars.GetVerticalBorderSizeTooltip(), playerBars.GetVerticalBorderSizeMin(), playerBars.GetVerticalBorderSizeMax(), "%.0f", playerBars.GetVerticalBorderSize, playerBars.SetVerticalBorderSize, 1)
end

function GamepadOptions.BuildVerticalSmoothTransitionsOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 35, playerBars.GetSmoothTransitionsLabel(), playerBars.GetSmoothTransitionsTooltip(), playerBars.GetVerticalSmoothTransitions, playerBars.SetVerticalSmoothTransitions)
end

function GamepadOptions.BuildVerticalTransitionShadowOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 36, playerBars.GetTransitionShadowLabel(), playerBars.GetTransitionShadowTooltip(), playerBars.GetVerticalTransitionShadow, playerBars.SetVerticalTransitionShadow)
end

function GamepadOptions.BuildVerticalFlyingPositiveAnimationOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 20, playerBars.GetVerticalFlyingPositiveAnimationLabel(), playerBars.GetVerticalFlyingPositiveAnimationTooltip(), playerBars.GetVerticalFlyingPositiveAnimation, playerBars.SetVerticalFlyingPositiveAnimation)
end

function GamepadOptions.BuildVerticalFlyingNegativeAnimationOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildCheckboxOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 21, playerBars.GetVerticalFlyingNegativeAnimationLabel(), playerBars.GetVerticalFlyingNegativeAnimationTooltip(), playerBars.GetVerticalFlyingNegativeAnimation, playerBars.SetVerticalFlyingNegativeAnimation)
end

function GamepadOptions.BuildVerticalFlyingAnimationFontOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 22, playerBars.GetVerticalFlyingAnimationFontLabel(), playerBars.GetVerticalFlyingAnimationFontTooltip(), playerBars.GetVerticalFlyingAnimationFontChoices(), playerBars.GetVerticalFlyingAnimationFontChoiceNames(), playerBars.GetVerticalFlyingAnimationFont, playerBars.SetVerticalFlyingAnimationFont)
end

function GamepadOptions.BuildVerticalFlyingAnimationFontSizeOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildValueStepSliderOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 23, playerBars.GetVerticalFlyingAnimationFontSizeLabel(), playerBars.GetVerticalFlyingAnimationFontSizeTooltip(), playerBars.GetVerticalFlyingAnimationFontSizeMin(), playerBars.GetVerticalFlyingAnimationFontSizeMax(), "%.0f", playerBars.GetVerticalFlyingAnimationFontSize, playerBars.SetVerticalFlyingAnimationFontSize, 1)
end

function GamepadOptions.BuildClassicShadowOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID, 18, playerBars.GetShadowLabel(), playerBars.GetShadowTooltip(), playerBars.GetShadowChoices(), playerBars.GetShadowChoiceNames(), playerBars.GetClassicShadow, playerBars.SetClassicShadow)
end

function GamepadOptions.BuildClassicShadowIntensityOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID, 19, playerBars.GetShadowIntensityLabel(), playerBars.GetShadowIntensityTooltip(), playerBars.GetShadowIntensityMin(), playerBars.GetShadowIntensityMax(), "%.0f%%", playerBars.GetClassicShadowIntensity, playerBars.SetClassicShadowIntensity, 1, nil, playerBars.GetClassicShadowIntensityDefault)
end

function GamepadOptions.BuildPyramidShadowOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID, 17, playerBars.GetShadowLabel(), playerBars.GetShadowTooltip(), playerBars.GetShadowChoices(), playerBars.GetShadowChoiceNames(), playerBars.GetPyramidShadow, playerBars.SetPyramidShadow)
end

function GamepadOptions.BuildPyramidShadowIntensityOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID, 18, playerBars.GetShadowIntensityLabel(), playerBars.GetShadowIntensityTooltip(), playerBars.GetShadowIntensityMin(), playerBars.GetShadowIntensityMax(), "%.0f%%", playerBars.GetPyramidShadowIntensity, playerBars.SetPyramidShadowIntensity, 1, nil, playerBars.GetPyramidShadowIntensityDefault)
end

function GamepadOptions.BuildStackShadowOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID, 19, playerBars.GetShadowLabel(), playerBars.GetShadowTooltip(), playerBars.GetShadowChoices(), playerBars.GetShadowChoiceNames(), playerBars.GetStackShadow, playerBars.SetStackShadow)
end

function GamepadOptions.BuildStackShadowIntensityOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID, 20, playerBars.GetShadowIntensityLabel(), playerBars.GetShadowIntensityTooltip(), playerBars.GetShadowIntensityMin(), playerBars.GetShadowIntensityMax(), "%.0f%%", playerBars.GetStackShadowIntensity, playerBars.SetStackShadowIntensity, 1, nil, playerBars.GetStackShadowIntensityDefault)
end

function GamepadOptions.BuildVerticalShadowOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildFiniteListOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 33, playerBars.GetShadowLabel(), playerBars.GetShadowTooltip(), playerBars.GetShadowChoices(), playerBars.GetShadowChoiceNames(), playerBars.GetVerticalShadow, playerBars.SetVerticalShadow)
end

function GamepadOptions.BuildVerticalShadowIntensityOption()
    local playerBars = NQOL.Features.PlayerBars
    return GamepadOptions.BuildSliderOption(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID, 34, playerBars.GetShadowIntensityLabel(), playerBars.GetShadowIntensityTooltip(), playerBars.GetShadowIntensityMin(), playerBars.GetShadowIntensityMax(), "%.0f%%", playerBars.GetVerticalShadowIntensity, playerBars.SetVerticalShadowIntensity, 1)
end
