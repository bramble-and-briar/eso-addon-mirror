NQOL = NQOL or {}
local GamepadOptions = NQOL.GamepadOptions

local PanelIds = GamepadOptions.PanelIds
local CHAT_PANEL_ID = PanelIds.CHAT
local CHAT_GUILD_COLORS_PANEL_ID = PanelIds.CHAT_GUILD_COLORS
local CHAT_REMINDERS_PANEL_ID = PanelIds.CHAT_REMINDERS
local TICKER_PANEL_ID = PanelIds.TICKER
local UTILITY_PANEL_ID = PanelIds.UTILITY
local GROUPING_PANEL_ID = PanelIds.GROUPING
local AUTO_INVITE_PANEL_ID = PanelIds.AUTO_INVITE
local LUA_GC_PANEL_ID = PanelIds.LUA_GC
local BUFFS_DEBUFFS_PANEL_ID = PanelIds.BUFFS_DEBUFFS
local BUFFS_DEBUFFS_TRACKERS_PANEL_ID = PanelIds.BUFFS_DEBUFFS_TRACKERS
local XP_TRACKER_PANEL_ID = PanelIds.XP_TRACKER
local XP_TIMERS_PANEL_ID = PanelIds.XP_TIMERS

function GamepadOptions.BuildChatTimestampModeOption()
    local chat = NQOL.Features.Chat
    return GamepadOptions.BuildFiniteListOption(
        CHAT_PANEL_ID,
        1,
        chat.GetTimestampModeLabel(),
        chat.GetTimestampModeTooltip(),
        chat.GetTimestampModeChoices(),
        chat.GetTimestampModeChoiceNames(),
        chat.GetTimestampMode,
        chat.SetTimestampMode,
        chat.GetTimestampModeDefault
    )
end

function GamepadOptions.BuildChatGuildColorsEntry()
    local chat = NQOL.Features.Chat
    return {
        panel = CHAT_PANEL_ID,
        system = CHAT_PANEL_ID,
        settingId = 13,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = chat.GetGuildColorsEntryLabel,
        gamepadTextOverride = chat.GetGuildColorsEntryLabel,
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, chat.GetGuildColorsEntryTooltip())
        end,
        callback = function()
            chat.CleanMissingGuildColors()
            GamepadOptions.ShowPanel(CHAT_GUILD_COLORS_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildChatRemindersEntry()
    local reminders = NQOL.Features.ChatReminders
    return {
        panel = CHAT_PANEL_ID,
        system = CHAT_PANEL_ID,
        settingId = 14,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = reminders.GetEntryLabel,
        gamepadTextOverride = reminders.GetEntryLabel,
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, reminders.GetEntryTooltip())
        end,
        callback = function()
            GamepadOptions.ShowPanel(CHAT_REMINDERS_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildChatSavedMessagesOption()
    local chat = NQOL.Features.Chat
    return GamepadOptions.BuildFiniteListOption(CHAT_PANEL_ID, 2, chat.GetSavedMessagesLabel(), chat.GetSavedMessagesTooltip(), chat.GetSavedMessagesChoices(), chat.GetSavedMessagesChoiceNames(), chat.GetSavedMessages, chat.SetSavedMessages)
end

function GamepadOptions.BuildChatKeepHudOpenOption()
    local chat = NQOL.Features.Chat
    return GamepadOptions.BuildCheckboxOption(CHAT_PANEL_ID, 3, chat.GetKeepHudOpenLabel(), chat.GetKeepHudOpenTooltip(), chat.GetKeepHudOpen, chat.SetKeepHudOpen)
end

function GamepadOptions.BuildChatHudHorizontalPositionOption()
    local chat = NQOL.Features.Chat
    return GamepadOptions.BuildPositionSliderOption(CHAT_PANEL_ID, 4, chat.GetHudHorizontalPositionLabel(), chat.GetHudHorizontalPositionTooltip(), 0, 100, "%.0f", chat.GetHudHorizontalPosition, chat.SetHudHorizontalPosition)
end

function GamepadOptions.BuildChatHudVerticalPositionOption()
    local chat = NQOL.Features.Chat
    return GamepadOptions.BuildPositionSliderOption(CHAT_PANEL_ID, 5, chat.GetHudVerticalPositionLabel(), chat.GetHudVerticalPositionTooltip(), 0, 100, "%.0f", chat.GetHudVerticalPosition, chat.SetHudVerticalPosition)
end

function GamepadOptions.BuildChatHudWidthOption()
    local chat = NQOL.Features.Chat
    return GamepadOptions.BuildSliderOption(CHAT_PANEL_ID, 6, chat.GetHudWidthLabel(), chat.GetHudWidthTooltip(), chat.GetHudWidthMin(), chat.GetHudWidthMax(), "%.0f", chat.GetHudWidth, chat.SetHudWidth)
end

function GamepadOptions.BuildChatHudHeightOption()
    local chat = NQOL.Features.Chat
    return GamepadOptions.BuildSliderOption(CHAT_PANEL_ID, 7, chat.GetHudHeightLabel(), chat.GetHudHeightTooltip(), chat.GetHudHeightMin(), chat.GetHudHeightMax(), "%.0f", chat.GetHudHeight, chat.SetHudHeight)
end

function GamepadOptions.BuildChatRemoveBackgroundOption()
    local chat = NQOL.Features.Chat
    return GamepadOptions.BuildCheckboxOption(CHAT_PANEL_ID, 8, chat.GetRemoveBackgroundLabel(), chat.GetRemoveBackgroundTooltip(), chat.GetRemoveBackground, chat.SetRemoveBackground)
end

function GamepadOptions.BuildChatFilterGuildAdsOption()
    local chat = NQOL.Features.Chat
    return GamepadOptions.BuildCheckboxOption(CHAT_PANEL_ID, 9, chat.GetFilterGuildAdsLabel(), chat.GetFilterGuildAdsTooltip(), chat.GetFilterGuildAds, chat.SetFilterGuildAds)
end

function GamepadOptions.BuildChatFilterPlusMessagesOption()
    local chat = NQOL.Features.Chat
    return GamepadOptions.BuildCheckboxOption(CHAT_PANEL_ID, 10, chat.GetFilterPlusMessagesLabel(), chat.GetFilterPlusMessagesTooltip(), chat.GetFilterPlusMessages, chat.SetFilterPlusMessages)
end

function GamepadOptions.BuildChatFilterWttWtsOption()
    local chat = NQOL.Features.Chat
    return GamepadOptions.BuildCheckboxOption(CHAT_PANEL_ID, 11, chat.GetFilterWttWtsLabel(), chat.GetFilterWttWtsTooltip(), chat.GetFilterWttWts, chat.SetFilterWttWts)
end

function GamepadOptions.BuildChatFilterZoneItemsOption()
    local chat = NQOL.Features.Chat
    return GamepadOptions.BuildCheckboxOption(CHAT_PANEL_ID, 18, chat.GetFilterZoneItemsLabel(), chat.GetFilterZoneItemsTooltip(), chat.GetFilterZoneItems, chat.SetFilterZoneItems)
end

function GamepadOptions.BuildChatFilterFriendStatusOption()
    local chat = NQOL.Features.Chat
    return GamepadOptions.BuildCheckboxOption(CHAT_PANEL_ID, 15, chat.GetFilterFriendStatusLabel(), chat.GetFilterFriendStatusTooltip(), chat.GetFilterFriendStatus, chat.SetFilterFriendStatus)
end

function GamepadOptions.BuildChatSilenceInDungeonsOption()
    local chat = NQOL.Features.Chat
    return GamepadOptions.BuildCheckboxOption(CHAT_PANEL_ID, 19, chat.GetSilenceInDungeonsLabel(), chat.GetSilenceInDungeonsTooltip(), chat.GetSilenceInDungeons, chat.SetSilenceInDungeons, nil, chat.GetSilenceInDungeonsDefault)
end

function GamepadOptions.BuildChatSilenceInTrialsOption()
    local chat = NQOL.Features.Chat
    return GamepadOptions.BuildCheckboxOption(CHAT_PANEL_ID, 20, chat.GetSilenceInTrialsLabel(), chat.GetSilenceInTrialsTooltip(), chat.GetSilenceInTrials, chat.SetSilenceInTrials, nil, chat.GetSilenceInTrialsDefault)
end

function GamepadOptions.BuildChatWhisperColorOption()
    local chat = NQOL.Features.Chat
    return GamepadOptions.BuildColorOption(CHAT_PANEL_ID, 12, chat.GetWhisperColorLabel(), chat.GetWhisperColorTooltip(), chat.GetWhisperColor, chat.SetWhisperColor)
end

function GamepadOptions.BuildChatGuildColorsEnabledOption()
    local chat = NQOL.Features.Chat
    return GamepadOptions.BuildCheckboxOption(CHAT_GUILD_COLORS_PANEL_ID, 1, chat.GetGuildColorsEnabledLabel(), chat.GetGuildColorsEnabledTooltip(), chat.GetGuildColorsEnabled, chat.SetGuildColorsEnabled)
end

function GamepadOptions.BuildChatAnnotateMissingItemsEnabledOption()
    local chat = NQOL.Features.Chat
    return GamepadOptions.BuildCheckboxOption(
        CHAT_PANEL_ID,
        16,
        chat.GetAnnotateMissingItemsEnabledLabel(),
        chat.GetAnnotateMissingItemsEnabledTooltip(),
        chat.GetAnnotateMissingItemsEnabled,
        chat.SetAnnotateMissingItemsEnabled,
        nil,
        chat.GetAnnotateMissingItemsEnabledDefault
    )
end

function GamepadOptions.BuildChatAnnotateMissingItemsWhisperMessageOption()
    local chat = NQOL.Features.Chat
    return {
        panel = CHAT_PANEL_ID,
        system = CHAT_PANEL_ID,
        settingId = 17,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = chat.GetAnnotateMissingItemsWhisperMessageLabel,
        gamepadTextOverride = chat.GetAnnotateMissingItemsWhisperMessageLabel,
        tooltipText = chat.GetAnnotateMissingItemsWhisperMessageTooltip(),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, chat.GetAnnotateMissingItemsWhisperMessageTooltip())
        end,
        callback = GamepadOptions.ShowChatMissingItemWhisperMessageDialog,
    }
end

function GamepadOptions.BuildChatGuildColorOption(guildIndex)
    local chat = NQOL.Features.Chat
    local option = GamepadOptions.BuildColorOption(CHAT_GUILD_COLORS_PANEL_ID, guildIndex + 1, function()
        return chat.GetGuildColorLabel(guildIndex)
    end, chat.GetGuildColorTooltip(), function()
        return chat.GetGuildColor(guildIndex)
    end, function(red, green, blue, alpha)
        chat.SetGuildColor(guildIndex, red, green, blue, alpha)
    end)
    option.enabled = function()
        return chat.HasGuildColorSlot(guildIndex)
    end
    return option
end

function GamepadOptions.BuildChatOfficerColorOption(guildIndex)
    local chat = NQOL.Features.Chat
    local option = GamepadOptions.BuildColorOption(CHAT_GUILD_COLORS_PANEL_ID, guildIndex + 6, function()
        return chat.GetOfficerColorLabel(guildIndex)
    end, chat.GetOfficerColorTooltip(), function()
        return chat.GetOfficerColor(guildIndex)
    end, function(red, green, blue, alpha)
        chat.SetOfficerColor(guildIndex, red, green, blue, alpha)
    end)
    option.enabled = function()
        return chat.HasGuildColorSlot(guildIndex)
    end
    return option
end

function GamepadOptions.BuildChatRemindersEnabledOption()
    local reminders = NQOL.Features.ChatReminders
    return GamepadOptions.BuildCheckboxOption(CHAT_REMINDERS_PANEL_ID, 1, reminders.GetEnabledLabel(), reminders.GetEnabledTooltip(), reminders.GetEnabled, reminders.SetEnabled, nil, reminders.GetEnabledDefault)
end

function GamepadOptions.BuildChatRemindersClearAllOption()
    local reminders = NQOL.Features.ChatReminders
    return {
        panel = CHAT_REMINDERS_PANEL_ID,
        system = CHAT_REMINDERS_PANEL_ID,
        settingId = 2,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = reminders.GetClearAllLabel,
        gamepadTextOverride = reminders.GetClearAllLabel,
        enabled = reminders.GetHasReminders,
        onInitializeFunction = GamepadOptions.InitializeDecorativeEntry,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, reminders.GetClearAllTooltip())
        end,
        callback = function()
            reminders.ClearAll()
            GamepadOptions.RefreshCurrentOptionsList()
        end,
    }
end

function GamepadOptions.BuildChatRemindersShowInSettingsOption()
    local reminders = NQOL.Features.ChatReminders
    return GamepadOptions.BuildCheckboxOption(CHAT_REMINDERS_PANEL_ID, 4, reminders.GetShowInSettingsLabel(), reminders.GetShowInSettingsTooltip(), reminders.GetShowInSettings, reminders.SetShowInSettings)
end

function GamepadOptions.BuildChatRemindersShowInGameOption()
    local reminders = NQOL.Features.ChatReminders
    return GamepadOptions.BuildCheckboxOption(CHAT_REMINDERS_PANEL_ID, 3, reminders.GetShowInGameLabel(), reminders.GetShowInGameTooltip(), reminders.GetShowInGame, reminders.SetShowInGame)
end

function GamepadOptions.BuildChatRemindersHorizontalPositionOption()
    local reminders = NQOL.Features.ChatReminders
    return GamepadOptions.BuildPositionSliderOption(CHAT_REMINDERS_PANEL_ID, 5, reminders.GetHorizontalPositionLabel(), reminders.GetHorizontalPositionTooltip(), 0, 100, "%.0f", reminders.GetHorizontalPosition, reminders.SetHorizontalPosition)
end

function GamepadOptions.BuildChatRemindersVerticalPositionOption()
    local reminders = NQOL.Features.ChatReminders
    return GamepadOptions.BuildPositionSliderOption(CHAT_REMINDERS_PANEL_ID, 6, reminders.GetVerticalPositionLabel(), reminders.GetVerticalPositionTooltip(), 0, 100, "%.0f", reminders.GetVerticalPosition, reminders.SetVerticalPosition)
end

function GamepadOptions.BuildChatRemindersWidthOption()
    local reminders = NQOL.Features.ChatReminders
    return GamepadOptions.BuildSliderOption(CHAT_REMINDERS_PANEL_ID, 7, reminders.GetWidthLabel(), reminders.GetWidthTooltip(), reminders.GetWidthMin(), reminders.GetWidthMax(), "%.0f", reminders.GetWidth, reminders.SetWidth, 1)
end

function GamepadOptions.BuildChatRemindersFontOption()
    local reminders = NQOL.Features.ChatReminders
    return GamepadOptions.BuildFiniteListOption(CHAT_REMINDERS_PANEL_ID, 8, reminders.GetFontLabel(), reminders.GetFontTooltip(), reminders.GetFontChoices(), reminders.GetFontChoiceNames(), reminders.GetFont, reminders.SetFont)
end

function GamepadOptions.BuildChatRemindersWrapTextOption()
    local reminders = NQOL.Features.ChatReminders
    return GamepadOptions.BuildCheckboxOption(CHAT_REMINDERS_PANEL_ID, 14, reminders.GetWrapTextLabel(), reminders.GetWrapTextTooltip(), reminders.GetWrapText, reminders.SetWrapText, nil, reminders.GetWrapTextDefault)
end

function GamepadOptions.BuildChatRemindersFontSizeOption()
    local reminders = NQOL.Features.ChatReminders
    return GamepadOptions.BuildValueStepSliderOption(CHAT_REMINDERS_PANEL_ID, 9, reminders.GetFontSizeLabel(), reminders.GetFontSizeTooltip(), reminders.GetFontSizeMin(), reminders.GetFontSizeMax(), "%.0f", reminders.GetFontSize, reminders.SetFontSize, 1)
end

function GamepadOptions.BuildChatRemindersBackgroundOpacityOption()
    local reminders = NQOL.Features.ChatReminders
    return GamepadOptions.BuildSliderOption(CHAT_REMINDERS_PANEL_ID, 10, reminders.GetBackgroundOpacityLabel(), reminders.GetBackgroundOpacityTooltip(), reminders.GetBackgroundOpacityMin(), reminders.GetBackgroundOpacityMax(), "%.0f", reminders.GetBackgroundOpacity, reminders.SetBackgroundOpacity, 1)
end

function GamepadOptions.BuildChatRemindersBorderSizeOption()
    local reminders = NQOL.Features.ChatReminders
    return GamepadOptions.BuildValueStepSliderOption(CHAT_REMINDERS_PANEL_ID, 11, reminders.GetBorderSizeLabel(), reminders.GetBorderSizeTooltip(), reminders.GetBorderSizeMin(), reminders.GetBorderSizeMax(), "%.0f", reminders.GetBorderSize, reminders.SetBorderSize, 1)
end

function GamepadOptions.BuildChatRemindersHeaderColorOption()
    local reminders = NQOL.Features.ChatReminders
    return GamepadOptions.BuildColorOption(CHAT_REMINDERS_PANEL_ID, 12, reminders.GetHeaderColorLabel(), reminders.GetHeaderColorTooltip(), reminders.GetHeaderColor, reminders.SetHeaderColor)
end

function GamepadOptions.BuildChatRemindersTextColorOption()
    local reminders = NQOL.Features.ChatReminders
    return GamepadOptions.BuildColorOption(CHAT_REMINDERS_PANEL_ID, 13, reminders.GetTextColorLabel(), reminders.GetTextColorTooltip(), reminders.GetTextColor, reminders.SetTextColor)
end

function GamepadOptions.BuildAutoInviteModeOption()
    local grouping = NQOL.Features.Grouping
    return GamepadOptions.BuildFiniteListOption(AUTO_INVITE_PANEL_ID, 1, grouping.GetAutoInviteModeLabel(), grouping.GetAutoInviteModeTooltip(), grouping.GetAutoInviteModeChoices(), grouping.GetAutoInviteModeChoiceNames(), grouping.GetAutoInviteMode, grouping.SetAutoInviteMode)
end

function GamepadOptions.BuildAutoInviteGroupSizeOption()
    local grouping = NQOL.Features.Grouping
    return GamepadOptions.BuildValueStepSliderOption(AUTO_INVITE_PANEL_ID, 2, grouping.GetAutoInviteGroupSizeLabel(), grouping.GetAutoInviteGroupSizeTooltip(), grouping.GetAutoInviteGroupSizeMin(), grouping.GetAutoInviteGroupSizeMax(), "%.0f", grouping.GetAutoInviteGroupSize, grouping.SetAutoInviteGroupSize, 1)
end

function GamepadOptions.BuildAutoInviteTriggerTextOption()
    local grouping = NQOL.Features.Grouping

    return {
        panel = AUTO_INVITE_PANEL_ID,
        system = AUTO_INVITE_PANEL_ID,
        settingId = 3,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = grouping.GetAutoInviteTriggerTextLabel,
        gamepadTextOverride = grouping.GetAutoInviteTriggerTextLabel,
        tooltipText = grouping.GetAutoInviteTriggerTextTooltip(),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, grouping.GetAutoInviteTriggerTextTooltip())
        end,
        callback = GamepadOptions.ShowAutoInviteTextDialog,
    }
end

function GamepadOptions.BuildAutoInviteDeclinedDelayOption()
    local grouping = NQOL.Features.Grouping
    return GamepadOptions.BuildSliderOption(AUTO_INVITE_PANEL_ID, 5, grouping.GetAutoInviteDeclinedDelayLabel(), grouping.GetAutoInviteDeclinedDelayTooltip(), grouping.GetAutoInviteDelayMin(), grouping.GetAutoInviteDelayMax(), NQOL.L("common.minutes_format"), grouping.GetAutoInviteDeclinedDelayMinutes, grouping.SetAutoInviteDeclinedDelayMinutes, 100 / 60, false, grouping.GetAutoInviteDeclinedDelayDefault())
end

function GamepadOptions.BuildAutoInviteReinviteDelayOption()
    local grouping = NQOL.Features.Grouping
    return GamepadOptions.BuildSliderOption(AUTO_INVITE_PANEL_ID, 6, grouping.GetAutoInviteReinviteDelayLabel(), grouping.GetAutoInviteReinviteDelayTooltip(), grouping.GetAutoInviteDelayMin(), grouping.GetAutoInviteDelayMax(), NQOL.L("common.minutes_format"), grouping.GetAutoInviteReinviteDelayMinutes, grouping.SetAutoInviteReinviteDelayMinutes, 100 / 60, false, grouping.GetAutoInviteReinviteDelayDefault())
end

function GamepadOptions.BuildAutoInviteLogInChatOption()
    local grouping = NQOL.Features.Grouping
    return GamepadOptions.BuildCheckboxOption(AUTO_INVITE_PANEL_ID, 7, grouping.GetAutoInviteLogInChatLabel(), grouping.GetAutoInviteLogInChatTooltip(), grouping.GetAutoInviteLogInChat, grouping.SetAutoInviteLogInChat, nil, grouping.GetAutoInviteLogInChatDefault)
end

function GamepadOptions.BuildTickerHorizontalPositionOption()
    local ticker = NQOL.Features.Ticker
    return GamepadOptions.BuildPositionSliderOption(TICKER_PANEL_ID, 2, ticker.GetHorizontalPositionLabel(), ticker.GetHorizontalPositionTooltip(), 0, 100, "%.0f", ticker.GetHorizontalPosition, ticker.SetHorizontalPosition)
end

function GamepadOptions.BuildTickerVerticalPositionOption()
    local ticker = NQOL.Features.Ticker
    return GamepadOptions.BuildPositionSliderOption(TICKER_PANEL_ID, 3, ticker.GetVerticalPositionLabel(), ticker.GetVerticalPositionTooltip(), 0, 100, "%.0f", ticker.GetVerticalPosition, ticker.SetVerticalPosition)
end

function GamepadOptions.BuildTickerAlignmentOption()
    local ticker = NQOL.Features.Ticker
    return GamepadOptions.BuildFiniteListOption(TICKER_PANEL_ID, 9, ticker.GetAlignmentLabel(), ticker.GetAlignmentTooltip(), ticker.GetAlignmentChoices(), ticker.GetAlignmentChoiceNames(), ticker.GetAlignment, ticker.SetAlignment)
end

function GamepadOptions.BuildTickerFontOption()
    local ticker = NQOL.Features.Ticker
    return GamepadOptions.BuildFiniteListOption(TICKER_PANEL_ID, 4, ticker.GetFontLabel(), ticker.GetFontTooltip(), ticker.GetFontChoices(), ticker.GetFontChoiceNames(), ticker.GetFont, ticker.SetFont)
end

function GamepadOptions.BuildTickerFontSizeOption()
    local ticker = NQOL.Features.Ticker
    return GamepadOptions.BuildValueStepSliderOption(TICKER_PANEL_ID, 5, ticker.GetFontSizeLabel(), ticker.GetFontSizeTooltip(), ticker.GetFontSizeMin(), ticker.GetFontSizeMax(), "%.0f", ticker.GetFontSize, ticker.SetFontSize, 1)
end

function GamepadOptions.BuildTickerShowInSettingsOption()
    local ticker = NQOL.Features.Ticker
    return GamepadOptions.BuildCheckboxOption(TICKER_PANEL_ID, 6, ticker.GetShowInSettingsLabel(), ticker.GetShowInSettingsTooltip(), ticker.GetShowInSettings, ticker.SetShowInSettings, nil, ticker.GetShowInSettingsDefault)
end

function GamepadOptions.BuildTickerColoredIconsOption()
    local ticker = NQOL.Features.Ticker
    return GamepadOptions.BuildCheckboxOption(TICKER_PANEL_ID, 7, ticker.GetColoredIconsLabel(), ticker.GetColoredIconsTooltip(), ticker.GetColoredIcons, ticker.SetColoredIcons, nil, ticker.GetColoredIconsDefault)
end

function GamepadOptions.BuildTickerBackgroundOpacityOption()
    local ticker = NQOL.Features.Ticker
    return GamepadOptions.BuildSliderOption(TICKER_PANEL_ID, 8, ticker.GetBackgroundOpacityLabel(), ticker.GetBackgroundOpacityTooltip(), ticker.GetBackgroundOpacityMin(), ticker.GetBackgroundOpacityMax(), "%.0f", ticker.GetBackgroundOpacity, ticker.SetBackgroundOpacity, 1)
end

function GamepadOptions.BuildTickerEnabledOption()
    local ticker = NQOL.Features.Ticker
    return GamepadOptions.BuildCheckboxOption(TICKER_PANEL_ID, 1, ticker.GetEnabledLabel(), ticker.GetEnabledTooltip(), ticker.GetEnabled, ticker.SetEnabled, nil, ticker.GetEnabledDefault)
end

function GamepadOptions.BuildXpTrackerEnabledOption()
    local progress = NQOL.Features.Progress
    return GamepadOptions.BuildCheckboxOption(XP_TRACKER_PANEL_ID, 1, progress.GetXpEnabledLabel(), progress.GetXpEnabledTooltip(), progress.GetXpEnabled, progress.SetXpEnabled)
end

function GamepadOptions.BuildXpTrackerShowInSettingsOption()
    local progress = NQOL.Features.Progress
    return GamepadOptions.BuildCheckboxOption(XP_TRACKER_PANEL_ID, 2, progress.GetXpShowInSettingsLabel(), progress.GetXpShowInSettingsTooltip(), progress.GetXpShowInSettings, progress.SetXpShowInSettings)
end

function GamepadOptions.BuildXpTrackerHorizontalPositionOption()
    local progress = NQOL.Features.Progress
    return GamepadOptions.BuildPositionSliderOption(XP_TRACKER_PANEL_ID, 4, progress.GetXpHorizontalPositionLabel(), progress.GetXpHorizontalPositionTooltip(), 0, 100, "%.0f", progress.GetXpHorizontalPosition, progress.SetXpHorizontalPosition)
end

function GamepadOptions.BuildXpTrackerVerticalPositionOption()
    local progress = NQOL.Features.Progress
    return GamepadOptions.BuildPositionSliderOption(XP_TRACKER_PANEL_ID, 5, progress.GetXpVerticalPositionLabel(), progress.GetXpVerticalPositionTooltip(), 0, 100, "%.0f", progress.GetXpVerticalPosition, progress.SetXpVerticalPosition)
end

function GamepadOptions.BuildXpTrackerFontOption()
    local progress = NQOL.Features.Progress
    return GamepadOptions.BuildFiniteListOption(XP_TRACKER_PANEL_ID, 6, progress.GetXpFontLabel(), progress.GetXpFontTooltip(), progress.GetXpFontChoices(), progress.GetXpFontChoiceNames(), progress.GetXpFont, progress.SetXpFont)
end

function GamepadOptions.BuildXpTrackerFontSizeOption()
    local progress = NQOL.Features.Progress
    return GamepadOptions.BuildValueStepSliderOption(XP_TRACKER_PANEL_ID, 7, progress.GetXpFontSizeLabel(), progress.GetXpFontSizeTooltip(), progress.GetXpFontSizeMin(), progress.GetXpFontSizeMax(), "%.0f", progress.GetXpFontSize, progress.SetXpFontSize, 1)
end

function GamepadOptions.BuildXpTrackerBackgroundOpacityOption()
    local progress = NQOL.Features.Progress
    return GamepadOptions.BuildSliderOption(XP_TRACKER_PANEL_ID, 8, progress.GetXpBackgroundOpacityLabel(), progress.GetXpBackgroundOpacityTooltip(), progress.GetXpBackgroundOpacityMin(), progress.GetXpBackgroundOpacityMax(), "%.0f", progress.GetXpBackgroundOpacity, progress.SetXpBackgroundOpacity, 1)
end

function GamepadOptions.BuildXpTimerOption(settingId, timer)
    local progress = NQOL.Features.Progress
    return GamepadOptions.BuildCheckboxOption(XP_TIMERS_PANEL_ID, settingId, timer.label, progress.GetXpTimerTooltip(timer.label), function()
        return progress.GetXpTimerEnabled(timer.key)
    end, function(value)
        progress.SetXpTimerEnabled(timer.key, value)
    end)
end

function GamepadOptions.BuildAutoClaimTomePointsOption()
    local tomePoints = NQOL.Features.TomePoints
    return GamepadOptions.BuildCheckboxOption(UTILITY_PANEL_ID, 1, tomePoints.GetAutoClaimTomePointsLabel(), tomePoints.GetAutoClaimTomePointsTooltip(), tomePoints.GetAutoClaimTomePoints, tomePoints.SetAutoClaimTomePoints)
end

function GamepadOptions.BuildAutoClaimGoldenPursuitsOption()
    local tomePoints = NQOL.Features.TomePoints
    return GamepadOptions.BuildCheckboxOption(UTILITY_PANEL_ID, 2, tomePoints.GetAutoClaimGoldenPursuitsLabel(), tomePoints.GetAutoClaimGoldenPursuitsTooltip(), tomePoints.GetAutoClaimGoldenPursuits, tomePoints.SetAutoClaimGoldenPursuits)
end

function GamepadOptions.BuildAutoClaimVeterancyRewardsOption()
    local veterancyRewards = NQOL.Features.VeterancyRewards
    return GamepadOptions.BuildCheckboxOption(UTILITY_PANEL_ID, 3, veterancyRewards.GetEnabledLabel(), veterancyRewards.GetEnabledTooltip(), veterancyRewards.GetEnabled, veterancyRewards.SetEnabled)
end

function GamepadOptions.BuildTransmuteWatchOption()
    local transmuteWatch = NQOL.Features.TransmuteWatch
    return GamepadOptions.BuildCheckboxOption(UTILITY_PANEL_ID, 4, transmuteWatch.GetEnabledLabel(), transmuteWatch.GetEnabledTooltip(), transmuteWatch.GetEnabled, transmuteWatch.SetEnabled, nil, transmuteWatch.GetEnabledDefault)
end

function GamepadOptions.BuildSkipLogoutConfirmationOption()
    local skipLogoutConfirmation = NQOL.Features.SkipLogoutConfirmation
    return GamepadOptions.BuildCheckboxOption(UTILITY_PANEL_ID, 5, skipLogoutConfirmation.GetEnabledLabel(), skipLogoutConfirmation.GetEnabledTooltip(), skipLogoutConfirmation.GetEnabled, skipLogoutConfirmation.SetEnabled)
end

function GamepadOptions.BuildErrorsDismissalOption()
    local errorsDismissal = NQOL.Features.ErrorsDismissal
    return GamepadOptions.BuildFiniteListOption(UTILITY_PANEL_ID, 7, errorsDismissal.GetModeLabel(), errorsDismissal.GetModeTooltip(), errorsDismissal.GetModeChoices(), errorsDismissal.GetModeChoiceNames(), errorsDismissal.GetMode, errorsDismissal.SetMode, errorsDismissal.GetModeDefault())
end

function GamepadOptions.BuildLuaGcOption()
    local luaGc = NQOL.Features.LuaGc
    return GamepadOptions.BuildCheckboxOption(LUA_GC_PANEL_ID, 1, luaGc.GetEnabledLabel(), luaGc.GetEnabledTooltip(), luaGc.GetEnabled, luaGc.SetEnabled)
end

function GamepadOptions.BuildLuaGcDebugOutputOption()
    local luaGc = NQOL.Features.LuaGc
    return GamepadOptions.BuildCheckboxOption(LUA_GC_PANEL_ID, 2, luaGc.GetDebugOutputLabel(), luaGc.GetDebugOutputTooltip(), luaGc.GetDebugOutput, luaGc.SetDebugOutput)
end

function GamepadOptions.BuildBuffsDebuffsMajorMonitorOption()
    local buffsDebuffs = NQOL.Features.BuffsDebuffs
    return GamepadOptions.BuildCheckboxOption(BUFFS_DEBUFFS_PANEL_ID, 4, buffsDebuffs.GetMonitorMajorLabel(), buffsDebuffs.GetMonitorMajorTooltip(), buffsDebuffs.GetMonitorMajor, buffsDebuffs.SetMonitorMajor, nil, buffsDebuffs.GetMonitorMajorDefault)
end

function GamepadOptions.BuildBuffsDebuffsMinorMonitorOption()
    local buffsDebuffs = NQOL.Features.BuffsDebuffs
    return GamepadOptions.BuildCheckboxOption(BUFFS_DEBUFFS_PANEL_ID, 5, buffsDebuffs.GetMonitorMinorLabel(), buffsDebuffs.GetMonitorMinorTooltip(), buffsDebuffs.GetMonitorMinor, buffsDebuffs.SetMonitorMinor, nil, buffsDebuffs.GetMonitorMinorDefault)
end

function GamepadOptions.BuildBuffsDebuffsHorizontalPositionOption()
    local buffsDebuffs = NQOL.Features.BuffsDebuffs
    return GamepadOptions.BuildPositionSliderOption(BUFFS_DEBUFFS_PANEL_ID, 7, buffsDebuffs.GetHorizontalPositionLabel(), buffsDebuffs.GetHorizontalPositionTooltip(), 0, 100, "%.0f", buffsDebuffs.GetHorizontalPosition, buffsDebuffs.SetHorizontalPosition, nil, buffsDebuffs.GetHorizontalPositionDefault)
end

function GamepadOptions.BuildBuffsDebuffsVerticalPositionOption()
    local buffsDebuffs = NQOL.Features.BuffsDebuffs
    return GamepadOptions.BuildPositionSliderOption(BUFFS_DEBUFFS_PANEL_ID, 8, buffsDebuffs.GetVerticalPositionLabel(), buffsDebuffs.GetVerticalPositionTooltip(), 0, 100, "%.0f", buffsDebuffs.GetVerticalPosition, buffsDebuffs.SetVerticalPosition, nil, buffsDebuffs.GetVerticalPositionDefault)
end

function GamepadOptions.BuildBuffsDebuffsShowInSettingsOption()
    local buffsDebuffs = NQOL.Features.BuffsDebuffs
    return GamepadOptions.BuildCheckboxOption(BUFFS_DEBUFFS_PANEL_ID, 2, buffsDebuffs.GetShowInSettingsLabel(), buffsDebuffs.GetShowInSettingsTooltip(), buffsDebuffs.GetShowInSettings, buffsDebuffs.SetShowInSettings)
end

function GamepadOptions.BuildBuffsDebuffsUseGameIconsOption()
    local buffsDebuffs = NQOL.Features.BuffsDebuffs
    return GamepadOptions.BuildCheckboxOption(BUFFS_DEBUFFS_PANEL_ID, 9, buffsDebuffs.GetUseGameIconsLabel(), buffsDebuffs.GetUseGameIconsTooltip(), buffsDebuffs.GetUseGameIcons, buffsDebuffs.SetUseGameIcons, nil, buffsDebuffs.GetUseGameIconsDefault)
end

function GamepadOptions.BuildBuffsDebuffsFontOption()
    local buffsDebuffs = NQOL.Features.BuffsDebuffs
    return GamepadOptions.BuildFiniteListOption(BUFFS_DEBUFFS_PANEL_ID, 10, buffsDebuffs.GetFontLabel(), buffsDebuffs.GetFontTooltip(), buffsDebuffs.GetFontChoices(), buffsDebuffs.GetFontChoiceNames(), buffsDebuffs.GetFont, buffsDebuffs.SetFont)
end

function GamepadOptions.BuildBuffsDebuffsFontSizeOption()
    local buffsDebuffs = NQOL.Features.BuffsDebuffs
    return GamepadOptions.BuildValueStepSliderOption(BUFFS_DEBUFFS_PANEL_ID, 11, buffsDebuffs.GetFontSizeLabel(), buffsDebuffs.GetFontSizeTooltip(), buffsDebuffs.GetFontSizeMin(), buffsDebuffs.GetFontSizeMax(), "%.0f", buffsDebuffs.GetFontSize, buffsDebuffs.SetFontSize, 1)
end

function GamepadOptions.BuildBuffsDebuffsBackgroundOpacityOption()
    local buffsDebuffs = NQOL.Features.BuffsDebuffs
    return GamepadOptions.BuildSliderOption(BUFFS_DEBUFFS_PANEL_ID, 12, buffsDebuffs.GetBackgroundOpacityLabel(), buffsDebuffs.GetBackgroundOpacityTooltip(), buffsDebuffs.GetBackgroundOpacityMin(), buffsDebuffs.GetBackgroundOpacityMax(), "%.0f", buffsDebuffs.GetBackgroundOpacity, buffsDebuffs.SetBackgroundOpacity, 1)
end

function GamepadOptions.BuildBuffsDebuffsStackOption()
    local buffsDebuffs = NQOL.Features.BuffsDebuffs
    return GamepadOptions.BuildFiniteListOption(BUFFS_DEBUFFS_PANEL_ID, 6, buffsDebuffs.GetStackLabel(), buffsDebuffs.GetStackTooltip(), buffsDebuffs.GetStackChoices(), buffsDebuffs.GetStackChoiceNames(), buffsDebuffs.GetStack, buffsDebuffs.SetStack)
end

function GamepadOptions.BuildBuffsDebuffsEnabledOption()
    local buffsDebuffs = NQOL.Features.BuffsDebuffs
    return GamepadOptions.BuildCheckboxOption(BUFFS_DEBUFFS_PANEL_ID, 1, buffsDebuffs.GetEnabledLabel(), buffsDebuffs.GetEnabledTooltip(), buffsDebuffs.GetEnabled, buffsDebuffs.SetEnabled, nil, buffsDebuffs.GetEnabledDefault)
end

function GamepadOptions.BuildBuffsDebuffsTrackerModeOption()
    local buffsDebuffs = NQOL.Features.BuffsDebuffs
    return GamepadOptions.BuildFiniteListOption(BUFFS_DEBUFFS_TRACKERS_PANEL_ID, 1, buffsDebuffs.GetTrackerModeLabel(), buffsDebuffs.GetTrackerModeTooltip(), buffsDebuffs.GetTrackerModeChoices(), buffsDebuffs.GetTrackerModeChoiceNames(), buffsDebuffs.GetTrackerMode, function(value)
        buffsDebuffs.SetTrackerMode(value)
        GamepadOptions.RefreshCurrentOptionsList()
    end)
end

function GamepadOptions.BuildBuffsDebuffsSelectedBuffOption(baseName)
    local buffsDebuffs = NQOL.Features.BuffsDebuffs
    return GamepadOptions.BuildCheckboxOption(BUFFS_DEBUFFS_TRACKERS_PANEL_ID, 0, buffsDebuffs.GetEffectDisplayName(baseName), buffsDebuffs.GetSelectedBuffTooltip(baseName), function()
        return buffsDebuffs.GetSelectedBuff(baseName)
    end, function(value)
        buffsDebuffs.SetSelectedBuff(baseName, value)
    end, buffsDebuffs.IsTrackSelectedMode)
end

function GamepadOptions.BuildBuffsDebuffsSelectedDebuffOption(baseName)
    local buffsDebuffs = NQOL.Features.BuffsDebuffs
    return GamepadOptions.BuildCheckboxOption(BUFFS_DEBUFFS_TRACKERS_PANEL_ID, 0, buffsDebuffs.GetEffectDisplayName(baseName), buffsDebuffs.GetSelectedDebuffTooltip(baseName), function()
        return buffsDebuffs.GetSelectedDebuff(baseName)
    end, function(value)
        buffsDebuffs.SetSelectedDebuff(baseName, value)
    end, buffsDebuffs.IsTrackSelectedMode)
end

function GamepadOptions.BuildTickerEntryOption(settingId, entryDefinition)
    local ticker = NQOL.Features.Ticker
    return GamepadOptions.BuildFiniteListOption(TICKER_PANEL_ID, settingId, entryDefinition.label, entryDefinition.tooltip, ticker.GetRowChoices(), ticker.GetRowChoiceNames(), function()
        return ticker.GetEntryRow(entryDefinition.key)
    end, function(value)
        ticker.SetEntryRow(entryDefinition.key, value)
    end)
end
