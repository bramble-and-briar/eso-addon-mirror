NQOL = NQOL or {}
local GamepadOptions = NQOL.GamepadOptions

local PanelIds = GamepadOptions.PanelIds
local ROOT_PANEL_ID = PanelIds.ROOT
local MOUNTS_PANEL_ID = PanelIds.MOUNTS
local ANTIQUITIES_PANEL_ID = PanelIds.ANTIQUITIES
local GEAR_PANEL_ID = PanelIds.GEAR
local PROVISIONING_PANEL_ID = PanelIds.PROVISIONING
local UI_PANEL_ID = PanelIds.UI
local ACTIVE_QUEST_PANEL_ID = PanelIds.ACTIVE_QUEST
local UTILITY_PANEL_ID = PanelIds.UTILITY
local GROUPING_PANEL_ID = PanelIds.GROUPING
local AUTO_BOUND_PANEL_ID = PanelIds.AUTO_BOUND
local AUTO_CHARGE_PANEL_ID = PanelIds.AUTO_CHARGE
local AUTO_REPAIR_PANEL_ID = PanelIds.AUTO_REPAIR

function GamepadOptions.BuildRootOptionsData()
    local optionsData = {
        GamepadOptions.BuildAntiquitiesEntry(),
        GamepadOptions.BuildBuffsDebuffsEntry(),
        GamepadOptions.BuildCombatEntry(),
        GamepadOptions.BuildGearEntry(),
        GamepadOptions.BuildFishingEntry(),
        GamepadOptions.BuildGroupingEntry(),
        GamepadOptions.BuildMapEntry(),
        GamepadOptions.BuildMountsEntry(),
        GamepadOptions.BuildProgressEntry(),
        GamepadOptions.BuildProvisioningEntry(),
        GamepadOptions.BuildSocialEntry(),
        GamepadOptions.BuildTickerEntry(),
        GamepadOptions.BuildUIEntry(),
        GamepadOptions.BuildUtilityEntry(),
        GamepadOptions.WithHeader(GamepadOptions.BuildPositioningOption(), NQOL.L("ui.headers.global_options_ac5ccaa")),
        GamepadOptions.BuildLanguageOption(),
    }

    if NQOL.IsDevMode and NQOL.IsDevMode() then
        table.insert(optionsData, GamepadOptions.WithHeader(GamepadOptions.BuildDebugEntry(), "Actions"))
        table.insert(optionsData, GamepadOptions.BuildReloadUIOption())
    else
        table.insert(optionsData, GamepadOptions.WithHeader(GamepadOptions.BuildReloadUIOption(), NQOL.L("ui.headers.actions_c3cd636")))
    end

    return optionsData
end

function GamepadOptions.BuildLanguageOption()
    local lexicon = NQOL.Lexicon
    local defaultPreference = lexicon.GetLanguagePreferenceDefault()
    local option = GamepadOptions.BuildFiniteListOption(
        ROOT_PANEL_ID,
        15,
        NQOL.L("settings.language.label"),
        NQOL.L("settings.language.tooltip"),
        lexicon.GetLanguageChoices(),
        lexicon.GetLanguageChoiceNames(),
        GamepadOptions.GetPendingLanguagePreference,
        GamepadOptions.SetPendingLanguagePreference,
        defaultPreference
    )
    option.customResetToDefaultsFunction = function()
        GamepadOptions.SetPendingLanguagePreference(defaultPreference)
        GamepadOptions.RefreshCurrentOptionsList()
    end
    return option
end

function GamepadOptions.BuildReloadUIOption()
    return {
        panel = ROOT_PANEL_ID,
        system = ROOT_PANEL_ID,
        settingId = 16,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.feature_panels_data.reload_ui_1986db8"),
        gamepadTextOverride = NQOL.L("ui.feature_panels_data.reload_ui_1986db8"),
        onInitializeFunction = GamepadOptions.InitializeDecorativeEntry,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.feature_panels_data.reload_the_game_s_user_interface_e548514"))
        end,
        callback = function()
            ReloadUI("ingame")
        end,
    }
end

function GamepadOptions.BuildDebugOptionsData()
    return {
        GamepadOptions.BuildExportAchievementSectionsOption(),
        GamepadOptions.BuildResetWelcomeMessageOption(),
        GamepadOptions.BuildResetWhatsNewMessageOption(),
        GamepadOptions.BuildPrintAnnotationTestItemLinksOption(),
        GamepadOptions.BuildGenerateBenignLuaErrorOption(),
    }
end

function GamepadOptions.BuildFishingOptionsData()
    return {
        GamepadOptions.BuildFishingReelNotificationOption(),
        GamepadOptions.BuildFishingReelNotificationSoundOption(),
        GamepadOptions.BuildFishingAutoSelectBaitOption(),
        GamepadOptions.BuildFishingReportBaitSwitchOption(),
        GamepadOptions.BuildFishingTrackerEntry(),
    }
end

function GamepadOptions.BuildFishingTrackerOptionsData()
    local fishing = NQOL.Features.Fishing
    return {
        GamepadOptions.BuildFiniteListOption(GamepadOptions.FISHING_TRACKER_PANEL_ID, 1, fishing.GetFishingTrackerLabel(), fishing.GetFishingTrackerTooltip(), fishing.GetFishingTrackerChoices(), fishing.GetFishingTrackerChoiceNames(), fishing.GetFishingTracker, fishing.SetFishingTracker, fishing.GetFishingTrackerDefault),
        GamepadOptions.BuildCheckboxOption(GamepadOptions.FISHING_TRACKER_PANEL_ID, 2, fishing.GetFishingTrackerShowInSettingsLabel(), fishing.GetFishingTrackerShowInSettingsTooltip(), fishing.GetFishingTrackerShowInSettings, fishing.SetFishingTrackerShowInSettings),
        GamepadOptions.BuildFiniteListOption(GamepadOptions.FISHING_TRACKER_PANEL_ID, 3, fishing.GetFishingTrackerOrientationLabel(), fishing.GetFishingTrackerOrientationTooltip(), fishing.GetFishingTrackerOrientationChoices(), fishing.GetFishingTrackerOrientationChoiceNames(), fishing.GetFishingTrackerOrientation, fishing.SetFishingTrackerOrientation, fishing.GetFishingTrackerOrientationDefault),
        GamepadOptions.WithHeader(GamepadOptions.BuildPositionSliderOption(GamepadOptions.FISHING_TRACKER_PANEL_ID, 4, fishing.GetFishingTrackerHorizontalPositionLabel(), fishing.GetFishingTrackerHorizontalPositionTooltip(), 0, 100, "%.0f", fishing.GetFishingTrackerHorizontalPosition, fishing.SetFishingTrackerHorizontalPosition), NQOL.L("ui.headers.position_and_appearance_346f660")),
        GamepadOptions.BuildPositionSliderOption(GamepadOptions.FISHING_TRACKER_PANEL_ID, 5, fishing.GetFishingTrackerVerticalPositionLabel(), fishing.GetFishingTrackerVerticalPositionTooltip(), 0, 100, "%.0f", fishing.GetFishingTrackerVerticalPosition, fishing.SetFishingTrackerVerticalPosition),
        GamepadOptions.BuildFiniteListOption(GamepadOptions.FISHING_TRACKER_PANEL_ID, 6, fishing.GetFishingTrackerFontLabel(), fishing.GetFishingTrackerFontTooltip(), fishing.GetFishingTrackerFontChoices(), fishing.GetFishingTrackerFontChoiceNames(), fishing.GetFishingTrackerFont, fishing.SetFishingTrackerFont),
        GamepadOptions.BuildValueStepSliderOption(GamepadOptions.FISHING_TRACKER_PANEL_ID, 7, fishing.GetFishingTrackerFontSizeLabel(), fishing.GetFishingTrackerFontSizeTooltip(), fishing.GetFishingTrackerFontSizeMin(), fishing.GetFishingTrackerFontSizeMax(), "%.0f", fishing.GetFishingTrackerFontSize, fishing.SetFishingTrackerFontSize, 1),
        GamepadOptions.BuildSliderOption(GamepadOptions.FISHING_TRACKER_PANEL_ID, 8, fishing.GetFishingTrackerBackgroundOpacityLabel(), fishing.GetFishingTrackerBackgroundOpacityTooltip(), fishing.GetFishingTrackerBackgroundOpacityMin(), fishing.GetFishingTrackerBackgroundOpacityMax(), "%.0f", fishing.GetFishingTrackerBackgroundOpacity, fishing.SetFishingTrackerBackgroundOpacity, 1),
    }
end

function GamepadOptions.BuildMountsOptionsData()
    return {
        GamepadOptions.BuildRemainMountedOption(),
        GamepadOptions.BuildAllowUseInteractionsOption(),
        GamepadOptions.BuildAllowOpenInteractionsOption(),
        GamepadOptions.BuildAllowTalkInteractionsOption(),
        GamepadOptions.BuildTrainingCheckOption(),
    }
end

function GamepadOptions.BuildAntiquitiesOptionsData()
    return {
        GamepadOptions.BuildShowMissingActiveLeadsButtonOption(),
        GamepadOptions.BuildAutoEyeOption(),
        GamepadOptions.BuildVendorLeadIndicatorsOption(),
    }
end

function GamepadOptions.BuildGearOptionsData()
    return {
        GamepadOptions.BuildAutoChargeEntry(),
        GamepadOptions.BuildAutoRepairEntry(),
        GamepadOptions.BuildAutoBoundEntry(),
    }
end

function GamepadOptions.BuildCombatOptionsData()
    return {
        GamepadOptions.BuildTrialTimerEntry(),
        GamepadOptions.BuildCombatInfiniteArchiveEntry(),
        GamepadOptions.BuildCombatMiscellaneousEntry(),
        GamepadOptions.BuildCombatReticleEntry(),
        GamepadOptions.BuildUltimateCountdownEntry(),
    }
end

function GamepadOptions.BuildUltimateCountdownOptionsData()
    return {
        GamepadOptions.BuildUltimateCountdownFrontEntry(),
        GamepadOptions.BuildUltimateCountdownBackEntry(),
    }
end

function GamepadOptions.BuildAutoChargeOptionsData()
    return {
        GamepadOptions.BuildAutoChargeOption(),
        GamepadOptions.BuildChargeThresholdOption(),
        GamepadOptions.BuildLogChargeOption(),
    }
end

function GamepadOptions.BuildAutoRepairOptionsData()
    return {
        GamepadOptions.BuildAutoRepairOption(),
        GamepadOptions.BuildRepairThresholdOption(),
        GamepadOptions.BuildRepairAllInMerchantsOption(),
        GamepadOptions.BuildLogRepairOption(),
    }
end

function GamepadOptions.BuildAutoBoundOptionsData()
    return {
        GamepadOptions.BuildAutoBoundOption(),
        GamepadOptions.BuildLogBindOption(),
    }
end

function GamepadOptions.BuildGroupingOptionsData()
    return {
        GamepadOptions.BuildAutoInviteEntry(),
    }
end

function GamepadOptions.BuildSocialOptionsData()
    return {
        GamepadOptions.BuildChatEntry(),
        GamepadOptions.BuildFriendsEntry(),
        GamepadOptions.BuildGroupFinderMonitorEntry(),
    }
end

function GamepadOptions.BuildFriendsOptionsData()
    return {
        GamepadOptions.BuildFriendsEnabledOption(),
        GamepadOptions.BuildFriendsShowInSettingsOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildFriendsHorizontalPositionOption(), NQOL.L("ui.headers.position_cf1c85a")),
        GamepadOptions.BuildFriendsVerticalPositionOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildFriendsWidthOption(), NQOL.L("ui.headers.size_b715234")),
        GamepadOptions.BuildFriendsMaxRowsOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildFriendsFontOption(), NQOL.L("ui.headers.appearance_41def7a")),
        GamepadOptions.BuildFriendsFontSizeOption(),
        GamepadOptions.BuildFriendsHeaderColorOption(),
        GamepadOptions.BuildFriendsTextColorOption(),
        GamepadOptions.BuildFriendsBackgroundOpacityOption(),
        GamepadOptions.BuildFriendsBorderSizeOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildFriendsShowStatusIconOption(), NQOL.L("ui.headers.rows_52d0b35")),
        GamepadOptions.BuildFriendsShowCharacterNameOption(),
        GamepadOptions.BuildFriendsShowZoneOption(),
    }
end

function GamepadOptions.BuildGroupFinderMonitorOptionsData()
    return {
        GamepadOptions.BuildGroupFinderMonitorEnabledOption(),
        GamepadOptions.BuildGroupFinderMonitorCloseOnJoinOption(),
        GamepadOptions.BuildGroupFinderMonitorShowInSettingsOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildGroupFinderMonitorRoleOption(), NQOL.L("features.group_finder_monitor.filters_header")),
        GamepadOptions.BuildGroupFinderMonitorAlarmOption(),
        GamepadOptions.BuildGroupFinderMonitorAlarmSoundOption(),
        GamepadOptions.BuildGroupFinderMonitorAlarmTextOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildGroupFinderMonitorDifficultyCategoryOption(3, "dungeon"), NQOL.L("features.group_finder_monitor.categories_header")),
        GamepadOptions.BuildGroupFinderMonitorDifficultyCategoryOption(4, "arena"),
        GamepadOptions.BuildGroupFinderMonitorDifficultyCategoryOption(5, "trial"),
        GamepadOptions.BuildGroupFinderMonitorCategoryOption(7, "infiniteArchive"),
        GamepadOptions.BuildGroupFinderMonitorCategoryOption(8, "pvp"),
        GamepadOptions.BuildGroupFinderMonitorCategoryOption(9, "zone"),
        GamepadOptions.BuildGroupFinderMonitorCategoryOption(10, "custom"),
        GamepadOptions.WithHeader(GamepadOptions.BuildGroupFinderMonitorHorizontalPositionOption(), NQOL.L("ui.headers.position_cf1c85a")),
        GamepadOptions.BuildGroupFinderMonitorVerticalPositionOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildGroupFinderMonitorWidthOption(), NQOL.L("ui.headers.size_b715234")),
        GamepadOptions.BuildGroupFinderMonitorMaxRowsOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildGroupFinderMonitorFontOption(), NQOL.L("ui.headers.appearance_41def7a")),
        GamepadOptions.BuildGroupFinderMonitorScaleOption(),
        GamepadOptions.BuildGroupFinderMonitorBackgroundOpacityOption(),
        GamepadOptions.BuildGroupFinderMonitorBorderSizeOption(),
    }
end

function GamepadOptions.BuildAutoInviteOptionsData()
    return {
        GamepadOptions.BuildAutoInviteModeOption(),
        GamepadOptions.BuildAutoInviteGroupSizeOption(),
        GamepadOptions.BuildAutoInviteTriggerTextOption(),
        GamepadOptions.BuildAutoInviteDeclinedDelayOption(),
        GamepadOptions.BuildAutoInviteReinviteDelayOption(),
        GamepadOptions.BuildAutoInviteLogInChatOption(),
    }
end

function GamepadOptions.BuildProvisioningOptionsData()
    return {
        GamepadOptions.BuildAutoFoodOption(),
        GamepadOptions.BuildAutoFoodRefreshThresholdOption(),
        GamepadOptions.BuildCheckStockOption(),
        GamepadOptions.BuildLogFoodOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildAutoFoodSavedFoodLabel(), NQOL.L("ui.headers.actions_c3cd636")),
    }
end

function GamepadOptions.BuildMapOptionsData()
    return {
        GamepadOptions.BuildGPSEntry(),
        GamepadOptions.BuildMapSettingsEntry(),
        GamepadOptions.BuildMinimapEntry(),
    }
end

function GamepadOptions.BuildGPSOptionsData()
    return {
        GamepadOptions.BuildGPSEnabledOption(),
        GamepadOptions.BuildGPSShowInSettingsOption(),
        GamepadOptions.BuildGPSDisplayFormatOption(),
        GamepadOptions.BuildGPSUpdateFrequencyOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildGPSHorizontalPositionOption(), NQOL.L("ui.headers.position_and_appearance_346f660")),
        GamepadOptions.BuildGPSVerticalPositionOption(),
        GamepadOptions.BuildGPSOpacityOption(),
        GamepadOptions.BuildGPSColorOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildGPSTextOrientationOption(), NQOL.Features.GPS.GetTextSectionLabel()),
        GamepadOptions.BuildGPSFontOption(),
        GamepadOptions.BuildGPSFontSizeOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildGPSQRCodeSizeOption(), NQOL.Features.GPS.GetQRCodeSectionLabel()),
        GamepadOptions.BuildGPSAdvancedDataOption(),
    }
end

function GamepadOptions.BuildMapSettingsOptionsData()
    return {
        GamepadOptions.BuildMapShowDungeonsOption(),
        GamepadOptions.BuildMapShowTrialsOption(),
        GamepadOptions.BuildMapBypassFastTravelConfirmationOption(),
        GamepadOptions.BuildMapFreeportOption(),
        GamepadOptions.BuildMapFreeportFallbackOption(),
    }
end

function GamepadOptions.BuildMinimapOptionsData()
    return {
        GamepadOptions.BuildMinimapEnabledOption(),
        GamepadOptions.BuildMinimapShowInCombatOption(),
        GamepadOptions.BuildMinimapShowInSettingsOption(),
        GamepadOptions.BuildMinimapUpdateFrequencyOption(),
        GamepadOptions.BuildMinimapHarvestMapCompatibilityOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildMinimapHorizontalPositionOption(), NQOL.L("ui.headers.position_and_appearance_346f660")),
        GamepadOptions.BuildMinimapVerticalPositionOption(),
        GamepadOptions.BuildMinimapSizeOption(),
        GamepadOptions.BuildMinimapBorderSizeOption(),
        GamepadOptions.BuildMinimapBorderColorOption(),
        GamepadOptions.BuildMinimapAreaLabelPositionOption(),
        GamepadOptions.BuildMinimapAreaLabelFontOption(),
        GamepadOptions.BuildMinimapAreaLabelSizeOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildMinimapZoneZoomOption(), NQOL.L("ui.headers.zoom")),
        GamepadOptions.BuildMinimapZonePlayerPinScaleOption(),
        GamepadOptions.BuildMinimapMountedZoomOption(),
        GamepadOptions.BuildMinimapMountedPlayerPinScaleOption(),
        GamepadOptions.BuildMinimapSubzoneZoomOption(),
        GamepadOptions.BuildMinimapSubzonePlayerPinScaleOption(),
        GamepadOptions.BuildMinimapDungeonZoomOption(),
        GamepadOptions.BuildMinimapDungeonPlayerPinScaleOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildMinimapWayshrineWayfinderEnabledOption(), NQOL.L("ui.headers.wayshrine_wayfinder_714bb59")),
        GamepadOptions.BuildMinimapWayshrineWayfinderThicknessOption(),
        GamepadOptions.BuildMinimapWayshrineWayfinderColorOption(),
    }
end

function GamepadOptions.BuildUIOptionsData()
    return {
        GamepadOptions.BuildCameraEntry(),
        GamepadOptions.BuildDefaultFramesEntry(),
        GamepadOptions.BuildDisableAlertTextsOption(),
        GamepadOptions.BuildFrameStylingEntry(),
        GamepadOptions.BuildLootLogEntry(),
        GamepadOptions.BuildPlayerInfoEntry(),
        GamepadOptions.BuildSortDungeonsFinderOption(),
    }
end

function GamepadOptions.BuildCameraOptionsData()
    return {
        GamepadOptions.BuildCameraEnabledOption(),
        GamepadOptions.BuildCameraOnFootZoomOption(),
        GamepadOptions.BuildCameraMountedZoomOption(),
        GamepadOptions.BuildCameraCombatZoomOption(),
    }
end

function GamepadOptions.BuildDefaultFramesOptionsData()
    return {
        GamepadOptions.BuildActiveCombatTipsEntry(),
        GamepadOptions.BuildActiveQuestEntry(),
        GamepadOptions.BuildAnnouncementsEntry(),
        GamepadOptions.BuildCenterScreenAnnounceEntry(),
        GamepadOptions.BuildInfiniteArchiveFrameEntry(),
        GamepadOptions.BuildPlayerInteractionEntry(),
        GamepadOptions.BuildSubtitlesEntry(),
        GamepadOptions.BuildSynergyPromptsEntry(),
    }
end

function GamepadOptions.BuildCombatReticleOptionsData()
    return {
        GamepadOptions.BuildCombatReticleColorOption(),
        GamepadOptions.BuildCombatReticleFightColorOption(),
        GamepadOptions.BuildCombatReticleShapeOption(),
        GamepadOptions.BuildCombatReticleScaleOption(),
        GamepadOptions.BuildAnimatedCombatReticleOption(),
        GamepadOptions.BuildReticleInfoEntry(),
    }
end

function GamepadOptions.BuildReticleInfoOptionsData()
    return {
        GamepadOptions.BuildReticleInfoTopLeftEntry(),
        GamepadOptions.BuildReticleInfoTopRightEntry(),
        GamepadOptions.BuildReticleInfoBottomLeftEntry(),
        GamepadOptions.BuildReticleInfoBottomRightEntry(),
    }
end

function GamepadOptions.BuildReticleInfoTopLeftOptionsData()
    return GamepadOptions.BuildReticleInfoTopLeftPositionOptions()
end

function GamepadOptions.BuildReticleInfoTopRightOptionsData()
    return GamepadOptions.BuildReticleInfoTopRightPositionOptions()
end

function GamepadOptions.BuildReticleInfoBottomLeftOptionsData()
    return GamepadOptions.BuildReticleInfoBottomLeftPositionOptions()
end

function GamepadOptions.BuildReticleInfoBottomRightOptionsData()
    return GamepadOptions.BuildReticleInfoBottomRightPositionOptions()
end

function GamepadOptions.BuildLootLogOptionsData()
    return {
        GamepadOptions.BuildLootLogShowTotalsOption(),
        GamepadOptions.BuildLootLogShowPriceOption(),
        GamepadOptions.BuildLootLogBufferSizeOption(),
        GamepadOptions.BuildLootLogTimerSecondsOption(),
    }
end

function GamepadOptions.BuildPlayerInfoOptionsData()
    return {
        GamepadOptions.BuildPlayerInfoEnabledOption(),
        GamepadOptions.BuildPlayerInfoShowInSettingsOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildPlayerInfoHorizontalPositionOption(), NQOL.L("ui.headers.position_cf1c85a")),
        GamepadOptions.BuildPlayerInfoVerticalPositionOption(),
        GamepadOptions.BuildPlayerInfoSeparationOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildPlayerInfoFontOption(), NQOL.L("ui.headers.appearance_41def7a")),
        GamepadOptions.BuildPlayerInfoFontSizeOption(),
        GamepadOptions.BuildPlayerInfoTextColorOption(),
        GamepadOptions.BuildPlayerInfoChampionPointsColorOption(),
        GamepadOptions.BuildPlayerInfoCpIconColorOption(),
        GamepadOptions.BuildPlayerInfoIconColorOption(),
        GamepadOptions.BuildPlayerInfoBackgroundOpacityOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildPlayerInfoXpBarOption(), NQOL.L("features.ui_player_info.xp_bar_section")),
        GamepadOptions.BuildPlayerInfoXpBarColorOption(),
        GamepadOptions.BuildPlayerInfoXpBarHeightOption(),
        GamepadOptions.BuildPlayerInfoXpBarProgressOption(),
        GamepadOptions.BuildPlayerInfoXpBarBackgroundOpacityOption(),
        GamepadOptions.BuildPlayerInfoXpBarFontOption(),
        GamepadOptions.BuildPlayerInfoXpBarFontSizeOption(),
        GamepadOptions.BuildPlayerInfoXpBarTextColorOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildPlayerInfoEnlightenmentBarOption(), NQOL.L("features.ui_player_info.enlightenment_bar_section")),
        GamepadOptions.BuildPlayerInfoEnlightenmentBarColorOption(),
        GamepadOptions.BuildPlayerInfoEnlightenmentBarHeightOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildPlayerInfoFieldOption(21, "playerId"), NQOL.L("ui.headers.fields_e8b6852")),
        GamepadOptions.BuildPlayerInfoFieldOption(22, "characterName"),
        GamepadOptions.BuildPlayerInfoFieldOption(23, "championPoints"),
        GamepadOptions.BuildPlayerInfoFieldOption(24, "className"),
        GamepadOptions.BuildPlayerInfoFieldOption(25, "classIcon"),
    }
end

function GamepadOptions.BuildActiveQuestOptionsData()
    return {
        GamepadOptions.BuildActiveQuestEnabledOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildActiveQuestHorizontalOffsetOption(), NQOL.L("ui.headers.position_cf1c85a")),
        GamepadOptions.BuildActiveQuestVerticalOffsetOption(),
    }
end

function GamepadOptions.BuildActiveCombatTipsOptionsData()
    return {
        GamepadOptions.BuildActiveCombatTipsEnabledOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildActiveCombatTipsHorizontalOffsetOption(), NQOL.L("ui.headers.position_cf1c85a")),
        GamepadOptions.BuildActiveCombatTipsVerticalOffsetOption(),
    }
end

function GamepadOptions.BuildSynergyPromptsOptionsData()
    return {
        GamepadOptions.BuildSynergyPromptsEnabledOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildSynergyPromptsHorizontalOffsetOption(), NQOL.L("ui.headers.position_cf1c85a")),
        GamepadOptions.BuildSynergyPromptsVerticalOffsetOption(),
    }
end

function GamepadOptions.BuildCenterScreenAnnounceOptionsData()
    return {
        GamepadOptions.BuildCenterScreenAnnounceEnabledOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildCenterScreenAnnounceHorizontalOffsetOption(), NQOL.L("ui.headers.position_cf1c85a")),
        GamepadOptions.BuildCenterScreenAnnounceVerticalOffsetOption(),
    }
end

function GamepadOptions.BuildAnnouncementsOptionsData()
    return {
        GamepadOptions.BuildAnnouncementsEnabledOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildAnnouncementsHorizontalOffsetOption(), NQOL.L("ui.headers.position_cf1c85a")),
        GamepadOptions.BuildAnnouncementsVerticalOffsetOption(),
    }
end

function GamepadOptions.BuildInfiniteArchiveFrameOptionsData()
    return {
        GamepadOptions.BuildInfiniteArchiveFrameEnabledOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildInfiniteArchiveFrameHorizontalOffsetOption(), NQOL.L("ui.headers.position_cf1c85a")),
        GamepadOptions.BuildInfiniteArchiveFrameVerticalOffsetOption(),
    }
end

function GamepadOptions.BuildPlayerInteractionOptionsData()
    return {
        GamepadOptions.BuildPlayerInteractionEnabledOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildPlayerInteractionHorizontalOffsetOption(), NQOL.L("ui.headers.position_cf1c85a")),
        GamepadOptions.BuildPlayerInteractionVerticalOffsetOption(),
    }
end

function GamepadOptions.BuildSubtitlesOptionsData()
    return {
        GamepadOptions.BuildSubtitlesEnabledOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildSubtitlesHorizontalOffsetOption(), NQOL.L("ui.headers.position_cf1c85a")),
        GamepadOptions.BuildSubtitlesVerticalOffsetOption(),
    }
end

function GamepadOptions.BuildFrameStylingOptionsData()
    return {
        GamepadOptions.BuildPlayerFrameEntry(),
        GamepadOptions.BuildCompanionFrameEntry(),
        GamepadOptions.BuildGroupFrameEntry(),
    }
end

function GamepadOptions.BuildCompanionFrameOptionsData()
    return {
        GamepadOptions.WithHeader(GamepadOptions.BuildShowNqolCompanionFrameOption(), NQOL.L("ui.headers.frame_91b0658")),
        GamepadOptions.BuildCompanionShowOnlyInCombatOption(),
        GamepadOptions.BuildCompanionShowInSettingsOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildCompanionHorizontalPositionOption(), NQOL.L("ui.headers.position_cf1c85a")),
        GamepadOptions.BuildCompanionVerticalPositionOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildCompanionOrientationOption(), NQOL.L("ui.headers.layout_972ad8d")),
        GamepadOptions.BuildCompanionWidthOption(),
        GamepadOptions.BuildCompanionHeightOption(),
        GamepadOptions.BuildCompanionFontOption(),
        GamepadOptions.BuildCompanionFontSizeOption(),
        GamepadOptions.BuildCompanionBorderSizeOption(),
        GamepadOptions.BuildCompanionReverseOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildCompanionShowNameOption(), NQOL.L("ui.headers.values_b1564f6")),
        GamepadOptions.BuildCompanionShowRapportOption(),
        GamepadOptions.BuildCompanionShowXpProgressOption(),
        GamepadOptions.BuildCompanionCurrentValueOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildCompanionHealthBarColorOption(), NQOL.L("ui.headers.appearance_41def7a")),
        GamepadOptions.BuildCompanionXpColorOption(),
        GamepadOptions.BuildCompanionSmoothTransitionsOption(),
        GamepadOptions.BuildCompanionTransitionShadowOption(),
        GamepadOptions.BuildCompanionShadowOption(),
        GamepadOptions.BuildCompanionShadowIntensityOption(),
    }
end

function GamepadOptions.BuildGroupFrameOptionsData()
    return {
        GamepadOptions.WithHeader(GamepadOptions.BuildShowNqolGroupFrameOption(), NQOL.L("ui.headers.frame_91b0658")),
        GamepadOptions.BuildGroupShowOnlyInCombatOption(),
        GamepadOptions.BuildGroupShowCustomNamesOption(),
        GamepadOptions.BuildGroupShowInSettingsOption(),
        GamepadOptions.BuildGroupShowShieldOption(),
        GamepadOptions.BuildGroupShowTraumaOption(),
        GamepadOptions.BuildGroupShowNoHealingOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildGroupHorizontalPositionOption(), NQOL.L("ui.headers.position_cf1c85a")),
        GamepadOptions.BuildGroupVerticalPositionOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildGroupWidthOption(), NQOL.L("ui.headers.layout_972ad8d")),
        GamepadOptions.BuildGroupHeightOption(),
        GamepadOptions.BuildGroupColumnsOption(),
        GamepadOptions.BuildGroupRowGapOption(),
        GamepadOptions.BuildGroupColumnGapOption(),
        GamepadOptions.BuildGroupFontOption(),
        GamepadOptions.BuildGroupFontSizeOption(),
        GamepadOptions.BuildGroupBorderSizeOption(),
        GamepadOptions.BuildGroupReverseOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildGroupNameDisplayOption(), NQOL.L("ui.headers.values_b1564f6")),
        GamepadOptions.BuildGroupShowClassOption(),
        GamepadOptions.BuildGroupShowTargetMarkerOption(),
        GamepadOptions.BuildGroupShowChampionPointsOption(),
        GamepadOptions.BuildGroupChampionPointsPlacementOption(),
        GamepadOptions.BuildGroupShowCompanionsOption(),
        GamepadOptions.BuildGroupShowLeaderOption(),
        GamepadOptions.BuildGroupShowDeathCounterOption(),
        GamepadOptions.BuildGroupShowResurrectingColorOption(),
        GamepadOptions.BuildGroupDimAwayOption(),
        GamepadOptions.BuildGroupCurrentValueOption(),
        GamepadOptions.WithHeader(GamepadOptions.BuildGroupSmoothTransitionsOption(), NQOL.L("ui.headers.appearance_41def7a")),
        GamepadOptions.BuildGroupTransitionShadowOption(),
        GamepadOptions.BuildGroupShadowOption(),
        GamepadOptions.BuildGroupShadowIntensityOption(),
        GamepadOptions.BuildGroupDamageColorOption(),
        GamepadOptions.BuildGroupTankColorOption(),
        GamepadOptions.BuildGroupHealerColorOption(),
        GamepadOptions.BuildGroupShieldColorOption(),
        GamepadOptions.BuildGroupTraumaColorOption(),
        GamepadOptions.BuildGroupResurrectingColorOption(),
    }
end
