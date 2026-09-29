NQOL = NQOL or {}
local GamepadOptions = NQOL.GamepadOptions

local PanelIds = GamepadOptions.PanelIds
local ROOT_PANEL_ID = PanelIds.ROOT
local MOUNTS_PANEL_ID = PanelIds.MOUNTS
local ANTIQUITIES_PANEL_ID = PanelIds.ANTIQUITIES
local GEAR_PANEL_ID = PanelIds.GEAR
local PROVISIONING_PANEL_ID = PanelIds.PROVISIONING
local MAP_OPTIONS_PANEL_ID = PanelIds.MAP_OPTIONS
local MINIMAP_PANEL_ID = PanelIds.MINIMAP
local GPS_PANEL_ID = PanelIds.GPS
local FISHING_PANEL_ID = PanelIds.FISHING
local UI_PANEL_ID = PanelIds.UI
local CAMERA_PANEL_ID = PanelIds.CAMERA
local COMBAT_RETICLE_PANEL_ID = PanelIds.COMBAT_RETICLE
local RETICLE_INFO_TOP_LEFT_PANEL_ID = PanelIds.RETICLE_INFO_TOP_LEFT
local RETICLE_INFO_TOP_RIGHT_PANEL_ID = PanelIds.RETICLE_INFO_TOP_RIGHT
local RETICLE_INFO_BOTTOM_LEFT_PANEL_ID = PanelIds.RETICLE_INFO_BOTTOM_LEFT
local RETICLE_INFO_BOTTOM_RIGHT_PANEL_ID = PanelIds.RETICLE_INFO_BOTTOM_RIGHT
local ACTIVE_QUEST_PANEL_ID = PanelIds.ACTIVE_QUEST
local ACTIVE_COMBAT_TIPS_PANEL_ID = PanelIds.ACTIVE_COMBAT_TIPS
local SYNERGY_PROMPTS_PANEL_ID = PanelIds.SYNERGY_PROMPTS
local CENTER_SCREEN_ANNOUNCE_PANEL_ID = PanelIds.CENTER_SCREEN_ANNOUNCE
local ANNOUNCEMENTS_PANEL_ID = PanelIds.ANNOUNCEMENTS
local INFINITE_ARCHIVE_FRAME_PANEL_ID = PanelIds.INFINITE_ARCHIVE_FRAME
local LOOT_LOG_PANEL_ID = PanelIds.LOOT_LOG
local PLAYER_INFO_PANEL_ID = PanelIds.PLAYER_INFO
local PLAYER_INTERACTION_PANEL_ID = PanelIds.PLAYER_INTERACTION
local SUBTITLES_PANEL_ID = PanelIds.SUBTITLES
local CHAT_PANEL_ID = PanelIds.CHAT
local TICKER_PANEL_ID = PanelIds.TICKER
local UTILITY_PANEL_ID = PanelIds.UTILITY
local GROUPING_PANEL_ID = PanelIds.GROUPING
local AUTO_INVITE_PANEL_ID = PanelIds.AUTO_INVITE
local LUA_GC_PANEL_ID = PanelIds.LUA_GC
local AUTO_BOUND_PANEL_ID = PanelIds.AUTO_BOUND
local AUTO_CHARGE_PANEL_ID = PanelIds.AUTO_CHARGE
local AUTO_REPAIR_PANEL_ID = PanelIds.AUTO_REPAIR
local BUFFS_DEBUFFS_PANEL_ID = PanelIds.BUFFS_DEBUFFS
local BUFFS_DEBUFFS_TRACKERS_PANEL_ID = PanelIds.BUFFS_DEBUFFS_TRACKERS
local PROGRESS_PANEL_ID = PanelIds.PROGRESS
local XP_TRACKER_PANEL_ID = PanelIds.XP_TRACKER
local XP_TIMERS_PANEL_ID = PanelIds.XP_TIMERS

function GamepadOptions.BuildPositioningOption()
    local positioning = NQOL.Features.Positioning
    return GamepadOptions.BuildFiniteListOption(ROOT_PANEL_ID, 14, positioning.GetModeLabel(), positioning.GetModeTooltip(), positioning.GetModeChoices(), positioning.GetModeChoiceNames(), positioning.GetMode, function(value)
        positioning.SetMode(value)
        GamepadOptions.RefreshCurrentOptionsList()
    end)
end

function GamepadOptions.BuildFishingReelNotificationOption()
    local fishing = NQOL.Features.Fishing
    return GamepadOptions.BuildCheckboxOption(FISHING_PANEL_ID, 1, fishing.GetReelNotificationLabel(), fishing.GetReelNotificationTooltip(), fishing.GetReelNotification, fishing.SetReelNotification, nil, fishing.GetReelNotificationDefault)
end

function GamepadOptions.BuildFishingReelNotificationSoundOption()
    local fishing = NQOL.Features.Fishing
    return GamepadOptions.BuildFiniteListOption(FISHING_PANEL_ID, 2, fishing.GetReelNotificationSoundLabel(), fishing.GetReelNotificationSoundTooltip(), fishing.GetReelNotificationSoundChoices(), fishing.GetReelNotificationSoundChoiceNames(), fishing.GetReelNotificationSound, fishing.SetReelNotificationSound, fishing.GetReelNotificationSoundDefault)
end

function GamepadOptions.BuildFishingAutoSelectBaitOption()
    local fishing = NQOL.Features.Fishing
    return GamepadOptions.BuildCheckboxOption(FISHING_PANEL_ID, 3, fishing.GetAutoSelectBaitLabel(), fishing.GetAutoSelectBaitTooltip(), fishing.GetAutoSelectBait, fishing.SetAutoSelectBait, nil, fishing.GetAutoSelectBaitDefault)
end

function GamepadOptions.BuildFishingReportBaitSwitchOption()
    local fishing = NQOL.Features.Fishing
    return GamepadOptions.BuildCheckboxOption(FISHING_PANEL_ID, 4, fishing.GetReportBaitSwitchLabel(), fishing.GetReportBaitSwitchTooltip(), fishing.GetReportBaitSwitch, fishing.SetReportBaitSwitch, nil, fishing.GetReportBaitSwitchDefault)
end

function GamepadOptions.BuildMapFreeportOption()
    local map = NQOL.Features.Map
    return GamepadOptions.BuildCheckboxOption(MAP_OPTIONS_PANEL_ID, 2, map.GetFreeportLabel(), map.GetFreeportTooltip(), map.GetFreeport, map.SetFreeport, nil, map.GetFreeportDefault)
end

function GamepadOptions.BuildMinimapEnabledOption()
    local minimap = NQOL.Features.Minimap
    return GamepadOptions.BuildCheckboxOption(MINIMAP_PANEL_ID, 1, minimap.GetEnabledLabel(), minimap.GetEnabledTooltip(), minimap.GetEnabled, minimap.SetEnabled, minimap.CanEnable, minimap.GetEnabledDefault)
end

function GamepadOptions.BuildGPSEnabledOption()
    local gps = NQOL.Features.GPS
    return GamepadOptions.BuildCheckboxOption(GPS_PANEL_ID, 1, gps.GetEnabledLabel(), gps.GetEnabledTooltip(), gps.GetEnabled, gps.SetEnabled, gps.IsAvailable, gps.GetEnabledDefault)
end

function GamepadOptions.BuildGPSDisplayFormatOption()
    local gps = NQOL.Features.GPS
    return GamepadOptions.BuildFiniteListOption(GPS_PANEL_ID, 2, gps.GetDisplayFormatLabel(), gps.GetDisplayFormatTooltip(), gps.GetDisplayFormatChoices(), gps.GetDisplayFormatChoiceNames(), gps.GetDisplayFormat, function(value)
        gps.SetDisplayFormat(value)
        GamepadOptions.RefreshCurrentOptionsList()
    end, gps.GetDisplayFormatDefault)
end

function GamepadOptions.BuildGPSUpdateFrequencyOption()
    local gps = NQOL.Features.GPS
    return GamepadOptions.BuildValueStepSliderOption(GPS_PANEL_ID, 12, gps.GetUpdateFrequencyLabel(), gps.GetUpdateFrequencyTooltip(), gps.GetUpdateFrequencyMin(), gps.GetUpdateFrequencyMax(), gps.GetUpdateFrequencyValueFormat(), gps.GetUpdateFrequency, gps.SetUpdateFrequency, gps.GetUpdateFrequencyStep(), nil, gps.GetUpdateFrequencyDefault)
end

function GamepadOptions.BuildGPSHorizontalPositionOption()
    local gps = NQOL.Features.GPS
    return GamepadOptions.BuildPositionSliderOption(GPS_PANEL_ID, 3, gps.GetHorizontalPositionLabel(), gps.GetHorizontalPositionTooltip(), 0, 100, "%.0f", gps.GetHorizontalPosition, gps.SetHorizontalPosition, nil, gps.GetHorizontalPositionDefault)
end

function GamepadOptions.BuildGPSVerticalPositionOption()
    local gps = NQOL.Features.GPS
    return GamepadOptions.BuildPositionSliderOption(GPS_PANEL_ID, 4, gps.GetVerticalPositionLabel(), gps.GetVerticalPositionTooltip(), 0, 100, "%.0f", gps.GetVerticalPosition, gps.SetVerticalPosition, nil, gps.GetVerticalPositionDefault)
end

function GamepadOptions.BuildGPSOpacityOption()
    local gps = NQOL.Features.GPS
    return GamepadOptions.BuildValueStepSliderOption(GPS_PANEL_ID, 5, gps.GetOpacityLabel(), gps.GetOpacityTooltip(), 0, 100, "%.0f%%", gps.GetOpacity, gps.SetOpacity, 1, nil, gps.GetOpacityDefault)
end

function GamepadOptions.BuildGPSColorOption()
    local gps = NQOL.Features.GPS
    return GamepadOptions.BuildColorOption(GPS_PANEL_ID, 6, gps.GetColorLabel(), gps.GetColorTooltip(), gps.GetColor, gps.SetColor)
end

function GamepadOptions.BuildGPSShowInSettingsOption()
    local gps = NQOL.Features.GPS
    return GamepadOptions.BuildCheckboxOption(GPS_PANEL_ID, 7, gps.GetShowInSettingsLabel(), gps.GetShowInSettingsTooltip(), gps.GetShowInSettings, gps.SetShowInSettings, nil, gps.GetShowInSettingsDefault)
end

function GamepadOptions.BuildGPSTextOrientationOption()
    local gps = NQOL.Features.GPS
    local option = GamepadOptions.BuildFiniteListOption(GPS_PANEL_ID, 8, gps.GetTextOrientationLabel(), gps.GetTextOrientationTooltip(), gps.GetTextOrientationChoices(), gps.GetTextOrientationChoiceNames(), gps.GetTextOrientation, gps.SetTextOrientation, gps.GetTextOrientationDefault)
    option.enabled = function()
        return gps.GetDisplayFormat() == "text"
    end
    return option
end

function GamepadOptions.BuildGPSFontOption()
    local gps = NQOL.Features.GPS
    local option = GamepadOptions.BuildFiniteListOption(GPS_PANEL_ID, 9, gps.GetFontLabel(), gps.GetFontTooltip(), gps.GetFontChoices(), gps.GetFontChoiceNames(), gps.GetFont, gps.SetFont)
    option.enabled = function()
        return gps.GetDisplayFormat() ~= "qr"
    end
    return option
end

function GamepadOptions.BuildGPSFontSizeOption()
    local gps = NQOL.Features.GPS
    local option = GamepadOptions.BuildValueStepSliderOption(GPS_PANEL_ID, 10, gps.GetFontSizeLabel(), gps.GetFontSizeTooltip(), gps.GetFontSizeMin(), gps.GetFontSizeMax(), "%.0f", gps.GetFontSize, gps.SetFontSize, 1, nil, gps.GetFontSizeDefault)
    option.enabled = function()
        return gps.GetDisplayFormat() ~= "qr"
    end
    return option
end

function GamepadOptions.BuildGPSQRCodeSizeOption()
    local gps = NQOL.Features.GPS
    local option = GamepadOptions.BuildValueStepSliderOption(GPS_PANEL_ID, 11, gps.GetQRCodeSizeLabel(), gps.GetQRCodeSizeTooltip(), gps.GetQRCodeSizeMin(), gps.GetQRCodeSizeMax(), "%.0f", gps.GetQRCodeSize, gps.SetQRCodeSize, 10, nil, gps.GetQRCodeSizeDefault)
    option.enabled = function()
        return gps.GetDisplayFormat() == "qr" and gps.IsQRCAvailable()
    end
    return option
end

function GamepadOptions.BuildGPSAdvancedDataOption()
    local gps = NQOL.Features.GPS
    local option = GamepadOptions.BuildCheckboxOption(GPS_PANEL_ID, 13, gps.GetAdvancedDataLabel(), gps.GetAdvancedDataTooltip(), gps.GetAdvancedData, gps.SetAdvancedData, nil, gps.GetAdvancedDataDefault)
    option.enabled = function()
        return gps.GetDisplayFormat() == "qr" and gps.IsQRCAvailable()
    end
    return option
end

function GamepadOptions.BuildMinimapZoneZoomOption()
    local minimap = NQOL.Features.Minimap
    return GamepadOptions.BuildValueStepSliderOption(MINIMAP_PANEL_ID, 6, minimap.GetZoneZoomLabel(), minimap.GetZoneZoomTooltip(), minimap.GetZoomMin(), minimap.GetZoomMax(), "%.0f%%", minimap.GetZoneZoom, minimap.SetZoneZoom, 1, nil, minimap.GetZoneZoomDefault)
end

function GamepadOptions.BuildMinimapZonePlayerPinScaleOption()
    local minimap = NQOL.Features.Minimap
    return GamepadOptions.BuildValueStepSliderOption(MINIMAP_PANEL_ID, 20, minimap.GetZonePlayerPinScaleLabel(), minimap.GetZonePlayerPinScaleTooltip(), minimap.GetPlayerPinScaleMin(), minimap.GetPlayerPinScaleMax(), "%.0f%%", minimap.GetZonePlayerPinScale, minimap.SetZonePlayerPinScale, 1, nil, minimap.GetZonePlayerPinScaleDefault)
end

function GamepadOptions.BuildMinimapSubzoneZoomOption()
    local minimap = NQOL.Features.Minimap
    return GamepadOptions.BuildValueStepSliderOption(MINIMAP_PANEL_ID, 19, minimap.GetSubzoneZoomLabel(), minimap.GetSubzoneZoomTooltip(), minimap.GetZoomMin(), minimap.GetZoomMax(), "%.0f%%", minimap.GetSubzoneZoom, minimap.SetSubzoneZoom, 1, nil, minimap.GetSubzoneZoomDefault)
end

function GamepadOptions.BuildMinimapDungeonZoomOption()
    local minimap = NQOL.Features.Minimap
    return GamepadOptions.BuildValueStepSliderOption(MINIMAP_PANEL_ID, 23, minimap.GetDungeonZoomLabel(), minimap.GetDungeonZoomTooltip(), minimap.GetZoomMin(), minimap.GetZoomMax(), "%.0f%%", minimap.GetDungeonZoom, minimap.SetDungeonZoom, 1, nil, minimap.GetDungeonZoomDefault)
end

function GamepadOptions.BuildMinimapDungeonPlayerPinScaleOption()
    local minimap = NQOL.Features.Minimap
    return GamepadOptions.BuildValueStepSliderOption(MINIMAP_PANEL_ID, 24, minimap.GetDungeonPlayerPinScaleLabel(), minimap.GetDungeonPlayerPinScaleTooltip(), minimap.GetPlayerPinScaleMin(), minimap.GetPlayerPinScaleMax(), "%.0f%%", minimap.GetDungeonPlayerPinScale, minimap.SetDungeonPlayerPinScale, 1, nil, minimap.GetDungeonPlayerPinScaleDefault)
end

function GamepadOptions.BuildMinimapSubzonePlayerPinScaleOption()
    local minimap = NQOL.Features.Minimap
    return GamepadOptions.BuildValueStepSliderOption(MINIMAP_PANEL_ID, 21, minimap.GetSubzonePlayerPinScaleLabel(), minimap.GetSubzonePlayerPinScaleTooltip(), minimap.GetPlayerPinScaleMin(), minimap.GetPlayerPinScaleMax(), "%.0f%%", minimap.GetSubzonePlayerPinScale, minimap.SetSubzonePlayerPinScale, 1, nil, minimap.GetSubzonePlayerPinScaleDefault)
end

function GamepadOptions.BuildMinimapMountedZoomOption()
    local minimap = NQOL.Features.Minimap
    return GamepadOptions.BuildValueStepSliderOption(MINIMAP_PANEL_ID, 7, minimap.GetMountedZoomLabel(), minimap.GetMountedZoomTooltip(), minimap.GetZoomMin(), minimap.GetZoomMax(), "%.0f%%", minimap.GetMountedZoom, minimap.SetMountedZoom, 1, nil, minimap.GetMountedZoomDefault)
end

function GamepadOptions.BuildMinimapMountedPlayerPinScaleOption()
    local minimap = NQOL.Features.Minimap
    return GamepadOptions.BuildValueStepSliderOption(MINIMAP_PANEL_ID, 22, minimap.GetMountedPlayerPinScaleLabel(), minimap.GetMountedPlayerPinScaleTooltip(), minimap.GetPlayerPinScaleMin(), minimap.GetPlayerPinScaleMax(), "%.0f%%", minimap.GetMountedPlayerPinScale, minimap.SetMountedPlayerPinScale, 1, nil, minimap.GetMountedPlayerPinScaleDefault)
end

function GamepadOptions.BuildMinimapShowInSettingsOption()
    local minimap = NQOL.Features.Minimap
    return GamepadOptions.BuildCheckboxOption(MINIMAP_PANEL_ID, 2, minimap.GetShowInSettingsLabel(), minimap.GetShowInSettingsTooltip(), minimap.GetShowInSettings, minimap.SetShowInSettings, nil, minimap.GetShowInSettingsDefault)
end

function GamepadOptions.BuildMinimapShowInCombatOption()
    local minimap = NQOL.Features.Minimap
    return GamepadOptions.BuildCheckboxOption(MINIMAP_PANEL_ID, 16, minimap.GetShowInCombatLabel(), minimap.GetShowInCombatTooltip(), minimap.GetShowInCombat, minimap.SetShowInCombat, nil, minimap.GetShowInCombatDefault)
end

function GamepadOptions.BuildMinimapUpdateFrequencyOption()
    local minimap = NQOL.Features.Minimap
    return GamepadOptions.BuildFiniteListOption(MINIMAP_PANEL_ID, 17, minimap.GetUpdateFrequencyLabel(), minimap.GetUpdateFrequencyTooltip(), minimap.GetUpdateFrequencyChoices(), minimap.GetUpdateFrequencyChoiceNames(), minimap.GetUpdateFrequency, minimap.SetUpdateFrequency, minimap.GetUpdateFrequencyDefault)
end

function GamepadOptions.BuildMinimapHarvestMapCompatibilityOption()
    local minimap = NQOL.Features.Minimap
    return GamepadOptions.BuildCheckboxOption(MINIMAP_PANEL_ID, 18, minimap.GetHarvestMapCompatibilityLabel(), minimap.GetHarvestMapCompatibilityTooltip(), minimap.GetHarvestMapCompatibility, minimap.SetHarvestMapCompatibility, nil, minimap.GetHarvestMapCompatibilityDefault)
end

function GamepadOptions.BuildMinimapHorizontalPositionOption()
    local minimap = NQOL.Features.Minimap
    return GamepadOptions.BuildPositionSliderOption(MINIMAP_PANEL_ID, 3, minimap.GetHorizontalPositionLabel(), minimap.GetHorizontalPositionTooltip(), 0, 100, "%.0f", minimap.GetHorizontalPosition, minimap.SetHorizontalPosition, nil, minimap.GetHorizontalPositionDefault)
end

function GamepadOptions.BuildMinimapVerticalPositionOption()
    local minimap = NQOL.Features.Minimap
    return GamepadOptions.BuildPositionSliderOption(MINIMAP_PANEL_ID, 4, minimap.GetVerticalPositionLabel(), minimap.GetVerticalPositionTooltip(), 0, 100, "%.0f", minimap.GetVerticalPosition, minimap.SetVerticalPosition, nil, minimap.GetVerticalPositionDefault)
end

function GamepadOptions.BuildMinimapSizeOption()
    local minimap = NQOL.Features.Minimap
    return GamepadOptions.BuildValueStepSliderOption(MINIMAP_PANEL_ID, 5, minimap.GetSizeLabel(), minimap.GetSizeTooltip(), minimap.GetSizeMin(), minimap.GetSizeMax(), "%.0f", minimap.GetSize, minimap.SetSize, 1, true, minimap.GetSizeDefault)
end

function GamepadOptions.BuildMinimapBorderSizeOption()
    local minimap = NQOL.Features.Minimap
    return GamepadOptions.BuildValueStepSliderOption(MINIMAP_PANEL_ID, 11, minimap.GetBorderSizeLabel(), minimap.GetBorderSizeTooltip(), minimap.GetBorderSizeMin(), minimap.GetBorderSizeMax(), "%.0f", minimap.GetBorderSize, function(value)
        minimap.SetBorderSize(value)
        GamepadOptions.RefreshCurrentOptionsList()
    end, 1, nil, minimap.GetBorderSizeDefault)
end

function GamepadOptions.BuildMinimapBorderColorOption()
    local minimap = NQOL.Features.Minimap
    local option = GamepadOptions.BuildColorOption(MINIMAP_PANEL_ID, 12, minimap.GetBorderColorLabel(), minimap.GetBorderColorTooltip(), minimap.GetBorderColor, minimap.SetBorderColor)
    option.enabled = function()
        return minimap.GetBorderSize() > 0
    end
    return option
end

function GamepadOptions.BuildMinimapWayshrineWayfinderEnabledOption()
    local minimap = NQOL.Features.Minimap
    return GamepadOptions.BuildCheckboxOption(MINIMAP_PANEL_ID, 13, minimap.GetWayshrineWayfinderEnabledLabel(), minimap.GetWayshrineWayfinderEnabledTooltip(), minimap.GetWayshrineWayfinderEnabled, function(value)
        minimap.SetWayshrineWayfinderEnabled(value)
        GamepadOptions.RefreshCurrentOptionsList()
    end, nil, minimap.GetWayshrineWayfinderEnabledDefault)
end

function GamepadOptions.BuildMinimapWayshrineWayfinderThicknessOption()
    local minimap = NQOL.Features.Minimap
    local option = GamepadOptions.BuildValueStepSliderOption(MINIMAP_PANEL_ID, 14, minimap.GetWayshrineWayfinderThicknessLabel(), minimap.GetWayshrineWayfinderThicknessTooltip(), minimap.GetWayshrineWayfinderThicknessMin(), minimap.GetWayshrineWayfinderThicknessMax(), "%.0f", minimap.GetWayshrineWayfinderThickness, minimap.SetWayshrineWayfinderThickness, 1, nil, minimap.GetWayshrineWayfinderThicknessDefault)
    option.enabled = minimap.GetWayshrineWayfinderEnabled
    return option
end

function GamepadOptions.BuildMinimapWayshrineWayfinderColorOption()
    local minimap = NQOL.Features.Minimap
    local option = GamepadOptions.BuildColorOption(MINIMAP_PANEL_ID, 15, minimap.GetWayshrineWayfinderColorLabel(), minimap.GetWayshrineWayfinderColorTooltip(), minimap.GetWayshrineWayfinderColor, minimap.SetWayshrineWayfinderColor)
    option.enabled = minimap.GetWayshrineWayfinderEnabled
    return option
end

function GamepadOptions.BuildMinimapAreaLabelPositionOption()
    local minimap = NQOL.Features.Minimap
    return GamepadOptions.BuildFiniteListOption(MINIMAP_PANEL_ID, 8, minimap.GetAreaLabelPositionLabel(), minimap.GetAreaLabelPositionTooltip(), minimap.GetAreaLabelPositionChoices(), minimap.GetAreaLabelPositionChoiceNames(), minimap.GetAreaLabelPosition, minimap.SetAreaLabelPosition, minimap.GetAreaLabelPositionDefault)
end

function GamepadOptions.BuildMinimapAreaLabelFontOption()
    local minimap = NQOL.Features.Minimap
    return GamepadOptions.BuildFiniteListOption(MINIMAP_PANEL_ID, 9, minimap.GetAreaLabelFontLabel(), minimap.GetAreaLabelFontTooltip(), minimap.GetAreaLabelFontChoices(), minimap.GetAreaLabelFontChoiceNames(), minimap.GetAreaLabelFont, minimap.SetAreaLabelFont, minimap.GetAreaLabelFontDefault)
end

function GamepadOptions.BuildMinimapAreaLabelSizeOption()
    local minimap = NQOL.Features.Minimap
    return GamepadOptions.BuildValueStepSliderOption(MINIMAP_PANEL_ID, 10, minimap.GetAreaLabelSizeLabel(), minimap.GetAreaLabelSizeTooltip(), minimap.GetAreaLabelSizeMin(), minimap.GetAreaLabelSizeMax(), "%.0f", minimap.GetAreaLabelSize, minimap.SetAreaLabelSize, 1, true, minimap.GetAreaLabelSizeDefault)
end

function GamepadOptions.BuildMapFreeportFallbackOption()
    local map = NQOL.Features.Map
    return GamepadOptions.BuildFiniteListOption(MAP_OPTIONS_PANEL_ID, 3, map.GetFreeportFallbackLabel(), map.GetFreeportFallbackTooltip(), map.GetFreeportFallbackChoices(), map.GetFreeportFallbackChoiceNames(), map.GetFreeportFallback, map.SetFreeportFallback, map.GetFreeportFallbackDefault)
end

function GamepadOptions.BuildMapBypassFastTravelConfirmationOption()
    local map = NQOL.Features.Map
    return GamepadOptions.BuildCheckboxOption(MAP_OPTIONS_PANEL_ID, 4, map.GetBypassFastTravelConfirmationLabel(), map.GetBypassFastTravelConfirmationTooltip(), map.GetBypassFastTravelConfirmation, map.SetBypassFastTravelConfirmation)
end

function GamepadOptions.BuildMapShowDungeonsOption()
    local map = NQOL.Features.Map
    return GamepadOptions.BuildCheckboxOption(MAP_OPTIONS_PANEL_ID, 1, map.GetShowDungeonsLabel(), map.GetShowDungeonsTooltip(), map.GetShowDungeons, map.SetShowDungeons, nil, map.GetShowDungeonsDefault)
end

function GamepadOptions.BuildMapShowTrialsOption()
    local map = NQOL.Features.Map
    return GamepadOptions.BuildCheckboxOption(MAP_OPTIONS_PANEL_ID, 5, map.GetShowTrialsLabel(), map.GetShowTrialsTooltip(), map.GetShowTrials, map.SetShowTrials, nil, map.GetShowTrialsDefault)
end

function GamepadOptions.BuildActiveQuestHorizontalOffsetOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildPositionSliderOption(ACTIVE_QUEST_PANEL_ID, 3, ui.GetActiveQuestHorizontalOffsetLabel(), ui.GetActiveQuestHorizontalOffsetTooltip(), ui.GetActiveQuestHorizontalOffsetMin(), ui.GetActiveQuestHorizontalOffsetMax(), "%.0f", ui.GetActiveQuestHorizontalOffset, ui.SetActiveQuestHorizontalOffset)
end

function GamepadOptions.BuildActiveQuestVerticalOffsetOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildPositionSliderOption(ACTIVE_QUEST_PANEL_ID, 4, ui.GetActiveQuestVerticalOffsetLabel(), ui.GetActiveQuestVerticalOffsetTooltip(), ui.GetActiveQuestVerticalOffsetMin(), ui.GetActiveQuestVerticalOffsetMax(), "%.0f", ui.GetActiveQuestVerticalOffset, ui.SetActiveQuestVerticalOffset, nil, ui.GetActiveQuestVerticalOffsetDefault)
end

function GamepadOptions.BuildActiveQuestEnabledOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildCheckboxOption(ACTIVE_QUEST_PANEL_ID, 1, ui.GetActiveQuestEnabledLabel(), ui.GetActiveQuestEnabledTooltip(), ui.GetActiveQuestEnabled, ui.SetActiveQuestEnabled, nil, ui.GetActiveQuestEnabledDefault)
end

function GamepadOptions.BuildActiveCombatTipsHorizontalOffsetOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildPositionSliderOption(ACTIVE_COMBAT_TIPS_PANEL_ID, 3, ui.GetActiveCombatTipsHorizontalOffsetLabel(), ui.GetActiveCombatTipsHorizontalOffsetTooltip(), ui.GetActiveCombatTipsHorizontalOffsetMin(), ui.GetActiveCombatTipsHorizontalOffsetMax(), "%.0f", ui.GetActiveCombatTipsHorizontalOffset, ui.SetActiveCombatTipsHorizontalOffset)
end

function GamepadOptions.BuildActiveCombatTipsVerticalOffsetOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildPositionSliderOption(ACTIVE_COMBAT_TIPS_PANEL_ID, 4, ui.GetActiveCombatTipsVerticalOffsetLabel(), ui.GetActiveCombatTipsVerticalOffsetTooltip(), ui.GetActiveCombatTipsVerticalOffsetMin(), ui.GetActiveCombatTipsVerticalOffsetMax(), "%.0f", ui.GetActiveCombatTipsVerticalOffset, ui.SetActiveCombatTipsVerticalOffset, nil, ui.GetActiveCombatTipsVerticalOffsetDefault)
end

function GamepadOptions.BuildActiveCombatTipsEnabledOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildCheckboxOption(ACTIVE_COMBAT_TIPS_PANEL_ID, 1, ui.GetActiveCombatTipsEnabledLabel(), ui.GetActiveCombatTipsEnabledTooltip(), ui.GetActiveCombatTipsEnabled, ui.SetActiveCombatTipsEnabled, nil, ui.GetActiveCombatTipsEnabledDefault)
end

function GamepadOptions.BuildSynergyPromptsHorizontalOffsetOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildPositionSliderOption(SYNERGY_PROMPTS_PANEL_ID, 3, ui.GetSynergyPromptsHorizontalOffsetLabel(), ui.GetSynergyPromptsHorizontalOffsetTooltip(), ui.GetSynergyPromptsHorizontalOffsetMin(), ui.GetSynergyPromptsHorizontalOffsetMax(), "%.0f", ui.GetSynergyPromptsHorizontalOffset, ui.SetSynergyPromptsHorizontalOffset)
end

function GamepadOptions.BuildSynergyPromptsVerticalOffsetOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildPositionSliderOption(SYNERGY_PROMPTS_PANEL_ID, 4, ui.GetSynergyPromptsVerticalOffsetLabel(), ui.GetSynergyPromptsVerticalOffsetTooltip(), ui.GetSynergyPromptsVerticalOffsetMin(), ui.GetSynergyPromptsVerticalOffsetMax(), "%.0f", ui.GetSynergyPromptsVerticalOffset, ui.SetSynergyPromptsVerticalOffset, nil, ui.GetSynergyPromptsVerticalOffsetDefault)
end

function GamepadOptions.BuildSynergyPromptsEnabledOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildCheckboxOption(SYNERGY_PROMPTS_PANEL_ID, 1, ui.GetSynergyPromptsEnabledLabel(), ui.GetSynergyPromptsEnabledTooltip(), ui.GetSynergyPromptsEnabled, ui.SetSynergyPromptsEnabled, nil, ui.GetSynergyPromptsEnabledDefault)
end

function GamepadOptions.BuildCenterScreenAnnounceHorizontalOffsetOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildPositionSliderOption(CENTER_SCREEN_ANNOUNCE_PANEL_ID, 3, ui.GetCenterScreenAnnounceHorizontalOffsetLabel(), ui.GetCenterScreenAnnounceHorizontalOffsetTooltip(), ui.GetCenterScreenAnnounceHorizontalOffsetMin(), ui.GetCenterScreenAnnounceHorizontalOffsetMax(), "%.0f", ui.GetCenterScreenAnnounceHorizontalOffset, ui.SetCenterScreenAnnounceHorizontalOffset)
end

function GamepadOptions.BuildCenterScreenAnnounceVerticalOffsetOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildPositionSliderOption(CENTER_SCREEN_ANNOUNCE_PANEL_ID, 4, ui.GetCenterScreenAnnounceVerticalOffsetLabel(), ui.GetCenterScreenAnnounceVerticalOffsetTooltip(), ui.GetCenterScreenAnnounceVerticalOffsetMin(), ui.GetCenterScreenAnnounceVerticalOffsetMax(), "%.0f", ui.GetCenterScreenAnnounceVerticalOffset, ui.SetCenterScreenAnnounceVerticalOffset, nil, ui.GetCenterScreenAnnounceVerticalOffsetDefault)
end

function GamepadOptions.BuildCenterScreenAnnounceEnabledOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildCheckboxOption(CENTER_SCREEN_ANNOUNCE_PANEL_ID, 1, ui.GetCenterScreenAnnounceEnabledLabel(), ui.GetCenterScreenAnnounceEnabledTooltip(), ui.GetCenterScreenAnnounceEnabled, ui.SetCenterScreenAnnounceEnabled, nil, ui.GetCenterScreenAnnounceEnabledDefault)
end

function GamepadOptions.BuildAnnouncementsHorizontalOffsetOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildPositionSliderOption(ANNOUNCEMENTS_PANEL_ID, 3, ui.GetAnnouncementsHorizontalOffsetLabel(), ui.GetAnnouncementsHorizontalOffsetTooltip(), ui.GetAnnouncementsHorizontalOffsetMin(), ui.GetAnnouncementsHorizontalOffsetMax(), "%.0f", ui.GetAnnouncementsHorizontalOffset, ui.SetAnnouncementsHorizontalOffset)
end

function GamepadOptions.BuildAnnouncementsVerticalOffsetOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildPositionSliderOption(ANNOUNCEMENTS_PANEL_ID, 4, ui.GetAnnouncementsVerticalOffsetLabel(), ui.GetAnnouncementsVerticalOffsetTooltip(), ui.GetAnnouncementsVerticalOffsetMin(), ui.GetAnnouncementsVerticalOffsetMax(), "%.0f", ui.GetAnnouncementsVerticalOffset, ui.SetAnnouncementsVerticalOffset, nil, ui.GetAnnouncementsVerticalOffsetDefault)
end

function GamepadOptions.BuildAnnouncementsEnabledOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildCheckboxOption(ANNOUNCEMENTS_PANEL_ID, 1, ui.GetAnnouncementsEnabledLabel(), ui.GetAnnouncementsEnabledTooltip(), ui.GetAnnouncementsEnabled, ui.SetAnnouncementsEnabled, nil, ui.GetAnnouncementsEnabledDefault)
end

function GamepadOptions.BuildInfiniteArchiveFrameHorizontalOffsetOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildPositionSliderOption(INFINITE_ARCHIVE_FRAME_PANEL_ID, 3, ui.GetInfiniteArchiveHorizontalOffsetLabel(), ui.GetInfiniteArchiveHorizontalOffsetTooltip(), ui.GetInfiniteArchiveHorizontalOffsetMin(), ui.GetInfiniteArchiveHorizontalOffsetMax(), "%.0f", ui.GetInfiniteArchiveHorizontalOffset, ui.SetInfiniteArchiveHorizontalOffset)
end

function GamepadOptions.BuildInfiniteArchiveFrameVerticalOffsetOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildPositionSliderOption(INFINITE_ARCHIVE_FRAME_PANEL_ID, 4, ui.GetInfiniteArchiveVerticalOffsetLabel(), ui.GetInfiniteArchiveVerticalOffsetTooltip(), ui.GetInfiniteArchiveVerticalOffsetMin(), ui.GetInfiniteArchiveVerticalOffsetMax(), "%.0f", ui.GetInfiniteArchiveVerticalOffset, ui.SetInfiniteArchiveVerticalOffset, nil, ui.GetInfiniteArchiveVerticalOffsetDefault)
end

function GamepadOptions.BuildInfiniteArchiveFrameEnabledOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildCheckboxOption(INFINITE_ARCHIVE_FRAME_PANEL_ID, 1, ui.GetInfiniteArchiveEnabledLabel(), ui.GetInfiniteArchiveEnabledTooltip(), ui.GetInfiniteArchiveEnabled, ui.SetInfiniteArchiveEnabled, nil, ui.GetInfiniteArchiveEnabledDefault)
end

function GamepadOptions.BuildPlayerInteractionHorizontalOffsetOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildPositionSliderOption(PLAYER_INTERACTION_PANEL_ID, 3, ui.GetPlayerInteractionHorizontalOffsetLabel(), ui.GetPlayerInteractionHorizontalOffsetTooltip(), ui.GetPlayerInteractionHorizontalOffsetMin(), ui.GetPlayerInteractionHorizontalOffsetMax(), "%.0f", ui.GetPlayerInteractionHorizontalOffset, ui.SetPlayerInteractionHorizontalOffset)
end

function GamepadOptions.BuildPlayerInteractionVerticalOffsetOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildPositionSliderOption(PLAYER_INTERACTION_PANEL_ID, 4, ui.GetPlayerInteractionVerticalOffsetLabel(), ui.GetPlayerInteractionVerticalOffsetTooltip(), ui.GetPlayerInteractionVerticalOffsetMin(), ui.GetPlayerInteractionVerticalOffsetMax(), "%.0f", ui.GetPlayerInteractionVerticalOffset, ui.SetPlayerInteractionVerticalOffset, nil, ui.GetPlayerInteractionVerticalOffsetDefault)
end

function GamepadOptions.BuildPlayerInteractionEnabledOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildCheckboxOption(PLAYER_INTERACTION_PANEL_ID, 1, ui.GetPlayerInteractionEnabledLabel(), ui.GetPlayerInteractionEnabledTooltip(), ui.GetPlayerInteractionEnabled, ui.SetPlayerInteractionEnabled, nil, ui.GetPlayerInteractionEnabledDefault)
end

function GamepadOptions.BuildSubtitlesHorizontalOffsetOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildPositionSliderOption(SUBTITLES_PANEL_ID, 3, ui.GetSubtitlesHorizontalOffsetLabel(), ui.GetSubtitlesHorizontalOffsetTooltip(), ui.GetSubtitlesHorizontalOffsetMin(), ui.GetSubtitlesHorizontalOffsetMax(), "%.0f", ui.GetSubtitlesHorizontalOffset, ui.SetSubtitlesHorizontalOffset)
end

function GamepadOptions.BuildSubtitlesVerticalOffsetOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildPositionSliderOption(SUBTITLES_PANEL_ID, 4, ui.GetSubtitlesVerticalOffsetLabel(), ui.GetSubtitlesVerticalOffsetTooltip(), ui.GetSubtitlesVerticalOffsetMin(), ui.GetSubtitlesVerticalOffsetMax(), "%.0f", ui.GetSubtitlesVerticalOffset, ui.SetSubtitlesVerticalOffset, nil, ui.GetSubtitlesVerticalOffsetDefault)
end

function GamepadOptions.BuildSubtitlesEnabledOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildCheckboxOption(SUBTITLES_PANEL_ID, 1, ui.GetSubtitlesEnabledLabel(), ui.GetSubtitlesEnabledTooltip(), ui.GetSubtitlesEnabled, ui.SetSubtitlesEnabled, nil, ui.GetSubtitlesEnabledDefault)
end

function GamepadOptions.BuildCombatReticleColorOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildColorOption(COMBAT_RETICLE_PANEL_ID, 1, ui.GetCombatReticleColorLabel(), ui.GetCombatReticleColorTooltip(), ui.GetCombatReticleColor, ui.SetCombatReticleColor)
end

function GamepadOptions.BuildCombatReticleFightColorOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildColorOption(COMBAT_RETICLE_PANEL_ID, 5, ui.GetCombatReticleFightColorLabel(), ui.GetCombatReticleFightColorTooltip(), ui.GetCombatReticleFightColor, ui.SetCombatReticleFightColor)
end

function GamepadOptions.BuildCombatReticleShapeOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildFiniteListOption(COMBAT_RETICLE_PANEL_ID, 2, ui.GetCombatReticleShapeLabel(), ui.GetCombatReticleShapeTooltip(), ui.GetCombatReticleShapeChoices(), ui.GetCombatReticleShapeChoiceNames(), ui.GetCombatReticleShape, ui.SetCombatReticleShape, ui.GetCombatReticleShapeDefault)
end

function GamepadOptions.BuildCombatReticleScaleOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildSliderOption(COMBAT_RETICLE_PANEL_ID, 3, ui.GetCombatReticleScaleLabel(), ui.GetCombatReticleScaleTooltip(), ui.GetCombatReticleScaleMin(), ui.GetCombatReticleScaleMax(), "%.0fx", ui.GetCombatReticleScale, ui.SetCombatReticleScale, 100 / 9, nil, ui.GetCombatReticleScaleDefault)
end

function GamepadOptions.BuildAnimatedCombatReticleOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildCheckboxOption(COMBAT_RETICLE_PANEL_ID, 4, ui.GetAnimatedCombatReticleLabel(), ui.GetAnimatedCombatReticleTooltip(), ui.GetAnimatedCombatReticle, ui.SetAnimatedCombatReticle, nil, ui.GetAnimatedCombatReticleDefault)
end

function GamepadOptions.BuildReticleInfoContentOption(panelId, positionKey)
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildFiniteListOption(panelId, 1, ui.GetReticleInfoContentLabel(), ui.GetReticleInfoContentTooltip(), ui.GetReticleInfoContentChoices(), ui.GetReticleInfoContentChoiceNames(), function()
        return ui.GetReticleInfoContent(positionKey)
    end, function(value)
        ui.SetReticleInfoContent(positionKey, value)
    end, ui.GetReticleInfoContentDefault)
end

function GamepadOptions.BuildReticleInfoIconPositionOption(panelId, positionKey)
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildFiniteListOption(panelId, 7, ui.GetReticleInfoIconPositionLabel(), ui.GetReticleInfoIconPositionTooltip(), ui.GetReticleInfoIconPositionChoices(), ui.GetReticleInfoIconPositionChoiceNames(), function()
        return ui.GetReticleInfoIconPosition(positionKey)
    end, function(value)
        ui.SetReticleInfoIconPosition(positionKey, value)
    end, ui.GetReticleInfoIconPositionDefault)
end

function GamepadOptions.BuildReticleInfoFontOption(panelId, positionKey)
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildFiniteListOption(panelId, 4, ui.GetReticleInfoFontLabel(), ui.GetReticleInfoFontTooltip(), ui.GetReticleInfoFontChoices(), ui.GetReticleInfoFontChoiceNames(), function()
        return ui.GetReticleInfoFont(positionKey)
    end, function(value)
        ui.SetReticleInfoFont(positionKey, value)
    end)
end

function GamepadOptions.BuildReticleInfoColorOption(panelId, positionKey)
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildColorOption(panelId, 6, ui.GetReticleInfoColorLabel(), ui.GetReticleInfoColorTooltip(), function()
        return ui.GetReticleInfoColor(positionKey)
    end, function(red, green, blue, alpha)
        ui.SetReticleInfoColor(positionKey, red, green, blue, alpha)
    end)
end

function GamepadOptions.BuildReticleInfoFontSizeOption(panelId, positionKey)
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildValueStepSliderOption(panelId, 5, ui.GetReticleInfoFontSizeLabel(), ui.GetReticleInfoFontSizeTooltip(), ui.GetReticleInfoFontSizeMin(), ui.GetReticleInfoFontSizeMax(), "%.0f", function()
        return ui.GetReticleInfoFontSize(positionKey)
    end, function(value)
        ui.SetReticleInfoFontSize(positionKey, value)
    end, 1, nil, ui.GetReticleInfoFontSizeDefault)
end

function GamepadOptions.BuildReticleInfoHorizontalOffsetOption(panelId, positionKey)
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildPositionSliderOption(panelId, 2, ui.GetReticleInfoHorizontalOffsetLabel(), ui.GetReticleInfoHorizontalOffsetTooltip(), ui.GetReticleInfoOffsetMin(), ui.GetReticleInfoOffsetMax(), "%.0f", function()
        return ui.GetReticleInfoHorizontalOffset(positionKey)
    end, function(value)
        ui.SetReticleInfoHorizontalOffset(positionKey, value)
    end, nil, function()
        return ui.GetReticleInfoHorizontalOffsetDefault(positionKey)
    end)
end

function GamepadOptions.BuildReticleInfoVerticalOffsetOption(panelId, positionKey)
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildPositionSliderOption(panelId, 3, ui.GetReticleInfoVerticalOffsetLabel(), ui.GetReticleInfoVerticalOffsetTooltip(), ui.GetReticleInfoOffsetMin(), ui.GetReticleInfoOffsetMax(), "%.0f", function()
        return ui.GetReticleInfoVerticalOffset(positionKey)
    end, function(value)
        ui.SetReticleInfoVerticalOffset(positionKey, value)
    end, nil, function()
        return ui.GetReticleInfoVerticalOffsetDefault(positionKey)
    end)
end

function GamepadOptions.BuildReticleInfoPositionOptions(panelId, positionKey)
    return {
        GamepadOptions.BuildReticleInfoContentOption(panelId, positionKey),
        GamepadOptions.BuildReticleInfoIconPositionOption(panelId, positionKey),
        GamepadOptions.BuildReticleInfoHorizontalOffsetOption(panelId, positionKey),
        GamepadOptions.BuildReticleInfoVerticalOffsetOption(panelId, positionKey),
        GamepadOptions.BuildReticleInfoFontOption(panelId, positionKey),
        GamepadOptions.BuildReticleInfoFontSizeOption(panelId, positionKey),
        GamepadOptions.BuildReticleInfoColorOption(panelId, positionKey),
    }
end

function GamepadOptions.BuildReticleInfoTopLeftPositionOptions()
    return GamepadOptions.BuildReticleInfoPositionOptions(RETICLE_INFO_TOP_LEFT_PANEL_ID, "topLeft")
end

function GamepadOptions.BuildReticleInfoTopRightPositionOptions()
    return GamepadOptions.BuildReticleInfoPositionOptions(RETICLE_INFO_TOP_RIGHT_PANEL_ID, "topRight")
end

function GamepadOptions.BuildReticleInfoBottomLeftPositionOptions()
    return GamepadOptions.BuildReticleInfoPositionOptions(RETICLE_INFO_BOTTOM_LEFT_PANEL_ID, "bottomLeft")
end

function GamepadOptions.BuildReticleInfoBottomRightPositionOptions()
    return GamepadOptions.BuildReticleInfoPositionOptions(RETICLE_INFO_BOTTOM_RIGHT_PANEL_ID, "bottomRight")
end

function GamepadOptions.BuildDisableAlertTextsOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildCheckboxOption(UI_PANEL_ID, 2, ui.GetDisableAlertTextsLabel(), ui.GetDisableAlertTextsTooltip(), ui.GetDisableAlertTexts, ui.SetDisableAlertTexts)
end

function GamepadOptions.BuildCameraEnabledOption()
    local camera = NQOL.Features.Camera
    return GamepadOptions.BuildCheckboxOption(CAMERA_PANEL_ID, 1, camera.GetEnabledLabel(), camera.GetEnabledTooltip(), camera.GetEnabled, camera.SetEnabled, nil, camera.GetEnabledDefault)
end

function GamepadOptions.BuildCameraOnFootZoomOption()
    local camera = NQOL.Features.Camera
    return GamepadOptions.BuildValueStepSliderOption(CAMERA_PANEL_ID, 2, camera.GetOnFootZoomLabel(), camera.GetOnFootZoomTooltip(), camera.GetZoomMin(), camera.GetZoomMax(), "%.1f", camera.GetOnFootZoom, camera.SetOnFootZoom, camera.GetZoomStep(), nil, camera.GetOnFootZoomDefault)
end

function GamepadOptions.BuildCameraMountedZoomOption()
    local camera = NQOL.Features.Camera
    return GamepadOptions.BuildValueStepSliderOption(CAMERA_PANEL_ID, 3, camera.GetMountedZoomLabel(), camera.GetMountedZoomTooltip(), camera.GetZoomMin(), camera.GetZoomMax(), "%.1f", camera.GetMountedZoom, camera.SetMountedZoom, camera.GetZoomStep(), nil, camera.GetMountedZoomDefault)
end

function GamepadOptions.BuildCameraCombatZoomOption()
    local camera = NQOL.Features.Camera
    return GamepadOptions.BuildValueStepSliderOption(CAMERA_PANEL_ID, 4, camera.GetCombatZoomLabel(), camera.GetCombatZoomTooltip(), camera.GetZoomMin(), camera.GetZoomMax(), "%.1f", camera.GetCombatZoom, camera.SetCombatZoom, camera.GetZoomStep(), nil, camera.GetCombatZoomDefault)
end

function GamepadOptions.BuildLootLogShowTotalsOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildCheckboxOption(LOOT_LOG_PANEL_ID, 1, ui.GetLootLogShowTotalsLabel(), ui.GetLootLogShowTotalsTooltip(), ui.GetLootLogShowTotals, ui.SetLootLogShowTotals, nil, ui.GetLootLogShowTotalsDefault)
end

function GamepadOptions.BuildLootLogShowPriceOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildFiniteListOption(LOOT_LOG_PANEL_ID, 2, ui.GetLootLogShowPriceLabel(), ui.GetLootLogShowPriceTooltip(), ui.GetLootLogShowPriceChoices(), ui.GetLootLogShowPriceChoiceNames(), ui.GetLootLogShowPrice, ui.SetLootLogShowPrice, ui.GetLootLogShowPriceDefault)
end

function GamepadOptions.BuildLootLogBufferSizeOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildFiniteListOption(LOOT_LOG_PANEL_ID, 3, ui.GetLootLogBufferSizeLabel(), ui.GetLootLogBufferSizeTooltip(), ui.GetLootLogBufferSizeChoices(), ui.GetLootLogBufferSizeChoiceNames(), ui.GetLootLogBufferSize, ui.SetLootLogBufferSize, ui.GetLootLogBufferSizeDefault)
end

function GamepadOptions.BuildLootLogTimerSecondsOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildSliderOption(LOOT_LOG_PANEL_ID, 4, ui.GetLootLogTimerSecondsLabel(), ui.GetLootLogTimerSecondsTooltip(), ui.GetLootLogTimerSecondsMin(), ui.GetLootLogTimerSecondsMax(), "%.0f", ui.GetLootLogTimerSeconds, ui.SetLootLogTimerSeconds, 11.111111111111, nil, ui.GetLootLogTimerSecondsDefault)
end

function GamepadOptions.BuildPlayerInfoEnabledOption()
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildCheckboxOption(PLAYER_INFO_PANEL_ID, 1, playerInfo.GetEnabledLabel(), playerInfo.GetEnabledTooltip(), playerInfo.GetEnabled, playerInfo.SetEnabled, nil, playerInfo.GetEnabledDefault)
end

function GamepadOptions.BuildPlayerInfoShowInSettingsOption()
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildCheckboxOption(PLAYER_INFO_PANEL_ID, 2, playerInfo.GetShowInSettingsLabel(), playerInfo.GetShowInSettingsTooltip(), playerInfo.GetShowInSettings, playerInfo.SetShowInSettings)
end

function GamepadOptions.BuildPlayerInfoHorizontalPositionOption()
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildPositionSliderOption(PLAYER_INFO_PANEL_ID, 3, playerInfo.GetHorizontalPositionLabel(), playerInfo.GetHorizontalPositionTooltip(), 0, 100, "%.0f", playerInfo.GetHorizontalPosition, playerInfo.SetHorizontalPosition)
end

function GamepadOptions.BuildPlayerInfoVerticalPositionOption()
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildPositionSliderOption(PLAYER_INFO_PANEL_ID, 4, playerInfo.GetVerticalPositionLabel(), playerInfo.GetVerticalPositionTooltip(), 0, 100, "%.0f", playerInfo.GetVerticalPosition, playerInfo.SetVerticalPosition)
end

function GamepadOptions.BuildPlayerInfoSeparationOption()
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildSliderOption(PLAYER_INFO_PANEL_ID, 5, playerInfo.GetSeparationLabel(), playerInfo.GetSeparationTooltip(), playerInfo.GetSeparationMin(), playerInfo.GetSeparationMax(), "%.0f", playerInfo.GetSeparation, playerInfo.SetSeparation, 1)
end

function GamepadOptions.BuildPlayerInfoFontOption()
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildFiniteListOption(PLAYER_INFO_PANEL_ID, 6, playerInfo.GetFontLabel(), playerInfo.GetFontTooltip(), playerInfo.GetFontChoices(), playerInfo.GetFontChoiceNames(), playerInfo.GetFont, playerInfo.SetFont)
end

function GamepadOptions.BuildPlayerInfoFontSizeOption()
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildValueStepSliderOption(PLAYER_INFO_PANEL_ID, 7, playerInfo.GetFontSizeLabel(), playerInfo.GetFontSizeTooltip(), playerInfo.GetFontSizeMin(), playerInfo.GetFontSizeMax(), "%.0f", playerInfo.GetFontSize, playerInfo.SetFontSize, 1)
end

function GamepadOptions.BuildPlayerInfoTextColorOption()
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildColorOption(PLAYER_INFO_PANEL_ID, 8, playerInfo.GetTextColorLabel(), playerInfo.GetTextColorTooltip(), playerInfo.GetTextColor, playerInfo.SetTextColor)
end

function GamepadOptions.BuildPlayerInfoChampionPointsColorOption()
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildColorOption(PLAYER_INFO_PANEL_ID, 9, playerInfo.GetChampionPointsColorLabel(), playerInfo.GetChampionPointsColorTooltip(), playerInfo.GetChampionPointsColor, playerInfo.SetChampionPointsColor)
end

function GamepadOptions.BuildPlayerInfoCpIconColorOption()
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildColorOption(PLAYER_INFO_PANEL_ID, 10, playerInfo.GetCpIconColorLabel(), playerInfo.GetCpIconColorTooltip(), playerInfo.GetCpIconColor, playerInfo.SetCpIconColor)
end

function GamepadOptions.BuildPlayerInfoIconColorOption()
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildColorOption(PLAYER_INFO_PANEL_ID, 11, playerInfo.GetIconColorLabel(), playerInfo.GetIconColorTooltip(), playerInfo.GetIconColor, playerInfo.SetIconColor)
end

function GamepadOptions.BuildPlayerInfoBackgroundOpacityOption()
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildSliderOption(PLAYER_INFO_PANEL_ID, 12, playerInfo.GetBackgroundOpacityLabel(), playerInfo.GetBackgroundOpacityTooltip(), playerInfo.GetBackgroundOpacityMin(), playerInfo.GetBackgroundOpacityMax(), "%.0f", playerInfo.GetBackgroundOpacity, playerInfo.SetBackgroundOpacity, 1)
end

function GamepadOptions.BuildPlayerInfoXpBarOption()
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildCheckboxOption(PLAYER_INFO_PANEL_ID, 13, playerInfo.GetXpBarLabel(), playerInfo.GetXpBarTooltip(), playerInfo.GetXpBar, playerInfo.SetXpBar, nil, playerInfo.GetXpBarDefault)
end

function GamepadOptions.BuildPlayerInfoXpBarColorOption()
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildColorOption(PLAYER_INFO_PANEL_ID, 26, playerInfo.GetXpBarColorLabel(), playerInfo.GetXpBarColorTooltip(), playerInfo.GetXpBarColor, playerInfo.SetXpBarColor)
end

function GamepadOptions.BuildPlayerInfoXpBarHeightOption()
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildValueStepSliderOption(PLAYER_INFO_PANEL_ID, 27, playerInfo.GetXpBarHeightLabel(), playerInfo.GetXpBarHeightTooltip(), playerInfo.GetThinBarHeightPixelsMin(), playerInfo.GetThinBarHeightPixelsMax(), "%.0f", playerInfo.GetXpBarHeightPixels, playerInfo.SetXpBarHeightPixels, 1)
end

function GamepadOptions.BuildPlayerInfoXpBarProgressOption()
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildCheckboxOption(PLAYER_INFO_PANEL_ID, 14, playerInfo.GetXpBarProgressLabel(), playerInfo.GetXpBarProgressTooltip(), playerInfo.GetXpBarProgress, playerInfo.SetXpBarProgress, nil, playerInfo.GetXpBarProgressDefault)
end

function GamepadOptions.BuildPlayerInfoXpBarBackgroundOpacityOption()
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildSliderOption(PLAYER_INFO_PANEL_ID, 15, playerInfo.GetXpBarBackgroundOpacityLabel(), playerInfo.GetXpBarBackgroundOpacityTooltip(), playerInfo.GetBarBackgroundOpacityMin(), playerInfo.GetBarBackgroundOpacityMax(), "%.0f", playerInfo.GetXpBarBackgroundOpacity, playerInfo.SetXpBarBackgroundOpacity, 1)
end

function GamepadOptions.BuildPlayerInfoXpBarFontOption()
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildFiniteListOption(PLAYER_INFO_PANEL_ID, 16, playerInfo.GetXpBarFontLabel(), playerInfo.GetXpBarFontTooltip(), playerInfo.GetFontChoices(), playerInfo.GetFontChoiceNames(), playerInfo.GetXpBarFont, playerInfo.SetXpBarFont)
end

function GamepadOptions.BuildPlayerInfoXpBarFontSizeOption()
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildValueStepSliderOption(PLAYER_INFO_PANEL_ID, 17, playerInfo.GetXpBarFontSizeLabel(), playerInfo.GetXpBarFontSizeTooltip(), playerInfo.GetXpBarFontSizeMin(), playerInfo.GetXpBarFontSizeMax(), "%.0f", playerInfo.GetXpBarFontSize, playerInfo.SetXpBarFontSize, 1)
end

function GamepadOptions.BuildPlayerInfoXpBarTextColorOption()
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildColorOption(PLAYER_INFO_PANEL_ID, 18, playerInfo.GetXpBarTextColorLabel(), playerInfo.GetXpBarTextColorTooltip(), playerInfo.GetXpBarTextColor, playerInfo.SetXpBarTextColor)
end

function GamepadOptions.BuildPlayerInfoEnlightenmentBarOption()
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildCheckboxOption(PLAYER_INFO_PANEL_ID, 19, playerInfo.GetEnlightenmentBarLabel(), playerInfo.GetEnlightenmentBarTooltip(), playerInfo.GetEnlightenmentBar, playerInfo.SetEnlightenmentBar, nil, playerInfo.GetEnlightenmentBarDefault)
end

function GamepadOptions.BuildPlayerInfoEnlightenmentBarColorOption()
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildColorOption(PLAYER_INFO_PANEL_ID, 20, playerInfo.GetEnlightenmentBarColorLabel(), playerInfo.GetEnlightenmentBarColorTooltip(), playerInfo.GetEnlightenmentBarColor, playerInfo.SetEnlightenmentBarColor)
end

function GamepadOptions.BuildPlayerInfoEnlightenmentBarHeightOption()
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildValueStepSliderOption(PLAYER_INFO_PANEL_ID, 28, playerInfo.GetEnlightenmentBarHeightLabel(), playerInfo.GetEnlightenmentBarHeightTooltip(), playerInfo.GetThinBarHeightPixelsMin(), playerInfo.GetThinBarHeightPixelsMax(), "%.0f", playerInfo.GetEnlightenmentBarHeightPixels, playerInfo.SetEnlightenmentBarHeightPixels, 1)
end

function GamepadOptions.BuildPlayerInfoFieldOption(settingId, fieldKey)
    local playerInfo = NQOL.Features.UIPlayerInfo
    return GamepadOptions.BuildFiniteListOption(PLAYER_INFO_PANEL_ID, settingId, function()
        return playerInfo.GetFieldLabel(fieldKey)
    end, playerInfo.GetFieldTooltip(), playerInfo.GetPlacementChoices(), playerInfo.GetPlacementChoiceNames(), function()
        return playerInfo.GetFieldPlacement(fieldKey)
    end, function(value)
        playerInfo.SetFieldPlacement(fieldKey, value)
    end)
end

function GamepadOptions.BuildSortDungeonsFinderOption()
    local ui = NQOL.Features.UI
    return GamepadOptions.BuildCheckboxOption(UI_PANEL_ID, 4, ui.GetSortDungeonsFinderLabel(), ui.GetSortDungeonsFinderTooltip(), ui.GetSortDungeonsFinder, ui.SetSortDungeonsFinder, nil, ui.GetSortDungeonsFinderDefault)
end
