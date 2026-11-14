NQOL = NQOL or {}
local GamepadOptions = NQOL.GamepadOptions

local GUILDS_PANEL_ID = GamepadOptions.PanelIds.GUILDS
local FRIENDS_PANEL_ID = GamepadOptions.PanelIds.FRIENDS
local GROUP_FINDER_MONITOR_PANEL_ID = GamepadOptions.PanelIds.GROUP_FINDER_MONITOR

function GamepadOptions.BuildFriendsEnabledOption()
    local friends = NQOL.Features.Friends
    return GamepadOptions.BuildCheckboxOption(FRIENDS_PANEL_ID, 1, friends.GetEnabledLabel(), friends.GetEnabledTooltip(), friends.GetEnabled, friends.SetEnabled, nil, friends.GetEnabledDefault)
end

function GamepadOptions.BuildFriendsShowInSettingsOption()
    local friends = NQOL.Features.Friends
    return GamepadOptions.BuildCheckboxOption(FRIENDS_PANEL_ID, 2, friends.GetShowInSettingsLabel(), friends.GetShowInSettingsTooltip(), friends.GetShowInSettings, friends.SetShowInSettings, nil, friends.GetShowInSettingsDefault)
end

function GamepadOptions.BuildFriendsHorizontalPositionOption()
    local friends = NQOL.Features.Friends
    return GamepadOptions.BuildPositionSliderOption(FRIENDS_PANEL_ID, 3, friends.GetHorizontalPositionLabel(), friends.GetHorizontalPositionTooltip(), 0, 100, "%.0f", friends.GetHorizontalPosition, friends.SetHorizontalPosition)
end

function GamepadOptions.BuildFriendsVerticalPositionOption()
    local friends = NQOL.Features.Friends
    return GamepadOptions.BuildPositionSliderOption(FRIENDS_PANEL_ID, 4, friends.GetVerticalPositionLabel(), friends.GetVerticalPositionTooltip(), 0, 100, "%.0f", friends.GetVerticalPosition, friends.SetVerticalPosition)
end

function GamepadOptions.BuildFriendsWidthOption()
    local friends = NQOL.Features.Friends
    return GamepadOptions.BuildSliderOption(FRIENDS_PANEL_ID, 5, friends.GetWidthLabel(), friends.GetWidthTooltip(), friends.GetWidthMin(), friends.GetWidthMax(), "%.0f", friends.GetWidth, friends.SetWidth, 1)
end

function GamepadOptions.BuildFriendsMaxRowsOption()
    local friends = NQOL.Features.Friends
    return GamepadOptions.BuildValueStepSliderOption(FRIENDS_PANEL_ID, 6, friends.GetMaxRowsLabel(), friends.GetMaxRowsTooltip(), friends.GetMaxRowsMin(), friends.GetMaxRowsMax(), "%.0f", friends.GetMaxRows, friends.SetMaxRows, 1)
end

function GamepadOptions.BuildFriendsFontOption()
    local friends = NQOL.Features.Friends
    return GamepadOptions.BuildFiniteListOption(FRIENDS_PANEL_ID, 7, friends.GetFontLabel(), friends.GetFontTooltip(), friends.GetFontChoices(), friends.GetFontChoiceNames(), friends.GetFont, friends.SetFont)
end

function GamepadOptions.BuildFriendsFontSizeOption()
    local friends = NQOL.Features.Friends
    return GamepadOptions.BuildValueStepSliderOption(FRIENDS_PANEL_ID, 8, friends.GetFontSizeLabel(), friends.GetFontSizeTooltip(), friends.GetFontSizeMin(), friends.GetFontSizeMax(), "%.0f", friends.GetFontSize, friends.SetFontSize, 1)
end

function GamepadOptions.BuildFriendsHeaderColorOption()
    local friends = NQOL.Features.Friends
    return GamepadOptions.BuildColorOption(FRIENDS_PANEL_ID, 9, friends.GetHeaderColorLabel(), friends.GetHeaderColorTooltip(), friends.GetHeaderColor, friends.SetHeaderColor)
end

function GamepadOptions.BuildFriendsTextColorOption()
    local friends = NQOL.Features.Friends
    return GamepadOptions.BuildColorOption(FRIENDS_PANEL_ID, 10, friends.GetTextColorLabel(), friends.GetTextColorTooltip(), friends.GetTextColor, friends.SetTextColor)
end

function GamepadOptions.BuildFriendsBackgroundOpacityOption()
    local friends = NQOL.Features.Friends
    return GamepadOptions.BuildSliderOption(FRIENDS_PANEL_ID, 11, friends.GetBackgroundOpacityLabel(), friends.GetBackgroundOpacityTooltip(), friends.GetBackgroundOpacityMin(), friends.GetBackgroundOpacityMax(), "%.0f", friends.GetBackgroundOpacity, friends.SetBackgroundOpacity, 1)
end

function GamepadOptions.BuildFriendsBorderSizeOption()
    local friends = NQOL.Features.Friends
    return GamepadOptions.BuildValueStepSliderOption(FRIENDS_PANEL_ID, 12, friends.GetBorderSizeLabel(), friends.GetBorderSizeTooltip(), friends.GetBorderSizeMin(), friends.GetBorderSizeMax(), "%.0f", friends.GetBorderSize, friends.SetBorderSize, 1)
end

function GamepadOptions.BuildFriendsShowStatusIconOption()
    local friends = NQOL.Features.Friends
    return GamepadOptions.BuildCheckboxOption(FRIENDS_PANEL_ID, 13, friends.GetShowStatusIconLabel(), friends.GetShowStatusIconTooltip(), friends.GetShowStatusIcon, friends.SetShowStatusIcon)
end

function GamepadOptions.BuildFriendsShowCharacterNameOption()
    local friends = NQOL.Features.Friends
    return GamepadOptions.BuildCheckboxOption(FRIENDS_PANEL_ID, 14, friends.GetShowCharacterNameLabel(), friends.GetShowCharacterNameTooltip(), friends.GetShowCharacterName, friends.SetShowCharacterName)
end

function GamepadOptions.BuildFriendsShowZoneOption()
    local friends = NQOL.Features.Friends
    return GamepadOptions.BuildCheckboxOption(FRIENDS_PANEL_ID, 15, friends.GetShowZoneLabel(), friends.GetShowZoneTooltip(), friends.GetShowZone, friends.SetShowZone)
end

function GamepadOptions.BuildGroupFinderMonitorEnabledOption()
    local monitor = NQOL.Features.GroupFinderMonitor
    return GamepadOptions.BuildCheckboxOption(GROUP_FINDER_MONITOR_PANEL_ID, 1, monitor.GetEnabledLabel(), monitor.GetEnabledTooltip(), monitor.GetEnabled, monitor.SetEnabled, nil, monitor.GetEnabledDefault)
end

function GamepadOptions.BuildGroupFinderMonitorCloseOnJoinOption()
    local monitor = NQOL.Features.GroupFinderMonitor
    return GamepadOptions.BuildCheckboxOption(GROUP_FINDER_MONITOR_PANEL_ID, 17, monitor.GetCloseOnJoinLabel(), monitor.GetCloseOnJoinTooltip(), monitor.GetCloseOnJoin, monitor.SetCloseOnJoin, nil, monitor.GetCloseOnJoinDefault)
end

function GamepadOptions.BuildGroupFinderMonitorShowInSettingsOption()
    local monitor = NQOL.Features.GroupFinderMonitor
    return GamepadOptions.BuildCheckboxOption(GROUP_FINDER_MONITOR_PANEL_ID, 2, monitor.GetShowInSettingsLabel(), monitor.GetShowInSettingsTooltip(), monitor.GetShowInSettings, monitor.SetShowInSettings, nil, monitor.GetShowInSettingsDefault)
end

function GamepadOptions.BuildGroupFinderMonitorRoleOption()
    local monitor = NQOL.Features.GroupFinderMonitor
    return GamepadOptions.BuildFiniteListOption(GROUP_FINDER_MONITOR_PANEL_ID, 6, monitor.GetRoleLabel(), monitor.GetRoleTooltip(), monitor.GetRoleChoices(), monitor.GetRoleChoiceNames(), monitor.GetRole, monitor.SetRole, monitor.GetRoleDefault)
end

function GamepadOptions.BuildGroupFinderMonitorAlarmOption()
    local monitor = NQOL.Features.GroupFinderMonitor
    return GamepadOptions.BuildCheckboxOption(GROUP_FINDER_MONITOR_PANEL_ID, 21, monitor.GetAlarmEnabledLabel(), monitor.GetAlarmEnabledTooltip(), monitor.GetAlarmEnabled, monitor.SetAlarmEnabled, nil, monitor.GetAlarmEnabledDefault)
end

function GamepadOptions.BuildGroupFinderMonitorAlarmSoundOption()
    local monitor = NQOL.Features.GroupFinderMonitor
    return GamepadOptions.BuildFiniteListOption(GROUP_FINDER_MONITOR_PANEL_ID, 23, monitor.GetAlarmSoundLabel(), monitor.GetAlarmSoundTooltip(), monitor.GetAlarmSoundChoices(), monitor.GetAlarmSoundChoiceNames(), monitor.GetAlarmSound, monitor.SetAlarmSound, monitor.GetAlarmSoundDefault)
end

function GamepadOptions.BuildGroupFinderMonitorAlarmTextOption()
    local monitor = NQOL.Features.GroupFinderMonitor
    return {
        panel = GROUP_FINDER_MONITOR_PANEL_ID,
        system = GROUP_FINDER_MONITOR_PANEL_ID,
        settingId = 22,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = monitor.GetAlarmTextLabel,
        gamepadTextOverride = monitor.GetAlarmTextLabel,
        tooltipText = monitor.GetAlarmTextTooltip(),
        onInitializeFunction = GamepadOptions.InitializeNavigationEntry,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, monitor.GetAlarmTextTooltip())
        end,
        callback = GamepadOptions.ShowGroupFinderMonitorAlarmTextDialog,
    }
end

function GamepadOptions.BuildGroupFinderMonitorCategoryOption(settingId, categoryKey)
    local monitor = NQOL.Features.GroupFinderMonitor
    return GamepadOptions.BuildCheckboxOption(
        GROUP_FINDER_MONITOR_PANEL_ID,
        settingId,
        monitor.GetCategoryLabel(categoryKey),
        monitor.GetCategoryTooltip(categoryKey),
        function() return monitor.GetCategoryEnabled(categoryKey) end,
        function(value) monitor.SetCategoryEnabled(categoryKey, value) end,
        nil,
        function() return monitor.GetCategoryDefault(categoryKey) end
    )
end

function GamepadOptions.BuildGroupFinderMonitorDifficultyCategoryOption(settingId, categoryKey)
    local monitor = NQOL.Features.GroupFinderMonitor
    return GamepadOptions.BuildFiniteListOption(
        GROUP_FINDER_MONITOR_PANEL_ID,
        settingId,
        monitor.GetCategoryLabel(categoryKey),
        monitor.GetCategoryTooltip(categoryKey),
        monitor.GetCategoryModeChoices(),
        monitor.GetCategoryModeChoiceNames(),
        function() return monitor.GetCategoryMode(categoryKey) end,
        function(value) monitor.SetCategoryMode(categoryKey, value) end,
        function() return monitor.GetCategoryModeDefault(categoryKey) end
    )
end

function GamepadOptions.BuildGroupFinderMonitorHorizontalPositionOption()
    local monitor = NQOL.Features.GroupFinderMonitor
    return GamepadOptions.BuildPositionSliderOption(GROUP_FINDER_MONITOR_PANEL_ID, 11, monitor.GetHorizontalPositionLabel(), monitor.GetHorizontalPositionTooltip(), 0, 100, "%.0f", monitor.GetHorizontalPosition, monitor.SetHorizontalPosition)
end

function GamepadOptions.BuildGroupFinderMonitorVerticalPositionOption()
    local monitor = NQOL.Features.GroupFinderMonitor
    return GamepadOptions.BuildPositionSliderOption(GROUP_FINDER_MONITOR_PANEL_ID, 12, monitor.GetVerticalPositionLabel(), monitor.GetVerticalPositionTooltip(), 0, 100, "%.0f", monitor.GetVerticalPosition, monitor.SetVerticalPosition)
end

function GamepadOptions.BuildGroupFinderMonitorWidthOption()
    local monitor = NQOL.Features.GroupFinderMonitor
    return GamepadOptions.BuildSliderOption(GROUP_FINDER_MONITOR_PANEL_ID, 13, monitor.GetWidthLabel(), monitor.GetWidthTooltip(), monitor.GetWidthMin(), monitor.GetWidthMax(), "%.0f", monitor.GetWidth, monitor.SetWidth, 1)
end

function GamepadOptions.BuildGroupFinderMonitorMaxRowsOption()
    local monitor = NQOL.Features.GroupFinderMonitor
    return GamepadOptions.BuildValueStepSliderOption(GROUP_FINDER_MONITOR_PANEL_ID, 14, monitor.GetMaxRowsLabel(), monitor.GetMaxRowsTooltip(), monitor.GetMaxRowsMin(), monitor.GetMaxRowsMax(), "%.0f", monitor.GetMaxRows, monitor.SetMaxRows, 1)
end

function GamepadOptions.BuildGroupFinderMonitorFontOption()
    local monitor = NQOL.Features.GroupFinderMonitor
    return GamepadOptions.BuildFiniteListOption(GROUP_FINDER_MONITOR_PANEL_ID, 15, monitor.GetFontLabel(), monitor.GetFontTooltip(), monitor.GetFontChoices(), monitor.GetFontChoiceNames(), monitor.GetFont, monitor.SetFont)
end

function GamepadOptions.BuildGroupFinderMonitorScaleOption()
    local monitor = NQOL.Features.GroupFinderMonitor
    return GamepadOptions.BuildValueStepSliderOption(GROUP_FINDER_MONITOR_PANEL_ID, 16, monitor.GetScaleLabel(), monitor.GetScaleTooltip(), monitor.GetScaleMin(), monitor.GetScaleMax(), "%.0f%%", monitor.GetScale, monitor.SetScale, 5)
end

function GamepadOptions.BuildGroupFinderMonitorBackgroundOpacityOption()
    local monitor = NQOL.Features.GroupFinderMonitor
    return GamepadOptions.BuildSliderOption(GROUP_FINDER_MONITOR_PANEL_ID, 19, monitor.GetBackgroundOpacityLabel(), monitor.GetBackgroundOpacityTooltip(), monitor.GetBackgroundOpacityMin(), monitor.GetBackgroundOpacityMax(), "%.0f", monitor.GetBackgroundOpacity, monitor.SetBackgroundOpacity, 1)
end

function GamepadOptions.BuildGroupFinderMonitorBorderSizeOption()
    local monitor = NQOL.Features.GroupFinderMonitor
    return GamepadOptions.BuildValueStepSliderOption(GROUP_FINDER_MONITOR_PANEL_ID, 20, monitor.GetBorderSizeLabel(), monitor.GetBorderSizeTooltip(), monitor.GetBorderSizeMin(), monitor.GetBorderSizeMax(), "%.0f", monitor.GetBorderSize, monitor.SetBorderSize, 1)
end

function GamepadOptions.BuildGuildsTrackGoldDepositsOption()
    local guilds = NQOL.Features.Guilds
    return GamepadOptions.BuildCheckboxOption(
        GUILDS_PANEL_ID,
        1,
        NQOL.L("features.guilds.track_gold_deposits.label"),
        NQOL.L("features.guilds.track_gold_deposits.tooltip"),
        guilds.GetTrackGoldDeposits,
        guilds.SetTrackGoldDeposits,
        nil,
        guilds.GetTrackGoldDepositsDefault
    )
end
