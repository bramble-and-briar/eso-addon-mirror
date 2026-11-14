NQOL = NQOL or {}
local GamepadOptions = NQOL.GamepadOptions

local PanelIds = GamepadOptions.PanelIds
local ROOT_PANEL_ID = PanelIds.ROOT
local MOUNTS_PANEL_ID = PanelIds.MOUNTS
local ANTIQUITIES_PANEL_ID = PanelIds.ANTIQUITIES
local GEAR_PANEL_ID = PanelIds.GEAR
local PROVISIONING_PANEL_ID = PanelIds.PROVISIONING
local MAP_PANEL_ID = PanelIds.MAP
local MAP_OPTIONS_PANEL_ID = PanelIds.MAP_OPTIONS
local MINIMAP_PANEL_ID = PanelIds.MINIMAP
local GPS_PANEL_ID = PanelIds.GPS
local FISHING_PANEL_ID = PanelIds.FISHING
local FISHING_TRACKER_PANEL_ID = PanelIds.FISHING_TRACKER
local UI_PANEL_ID = PanelIds.UI
local CAMERA_PANEL_ID = PanelIds.CAMERA
local DEFAULT_FRAMES_PANEL_ID = PanelIds.DEFAULT_FRAMES
local COMBAT_RETICLE_PANEL_ID = PanelIds.COMBAT_RETICLE
local RETICLE_INFO_PANEL_ID = PanelIds.RETICLE_INFO
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
local GOLDEN_PURSUIT_PANEL_ID = PanelIds.GOLDEN_PURSUIT
local HOUSE_TRACKER_PANEL_ID = PanelIds.HOUSE_TRACKER
local LOOT_LOG_PANEL_ID = PanelIds.LOOT_LOG
local PLAYER_INFO_PANEL_ID = PanelIds.PLAYER_INFO
local PLAYER_INTERACTION_PANEL_ID = PanelIds.PLAYER_INTERACTION
local SUBTITLES_PANEL_ID = PanelIds.SUBTITLES
local CHAT_PANEL_ID = PanelIds.CHAT
local SOCIAL_PANEL_ID = PanelIds.SOCIAL
local GUILDS_PANEL_ID = PanelIds.GUILDS
local FRIENDS_PANEL_ID = PanelIds.FRIENDS
local GROUP_FINDER_MONITOR_PANEL_ID = PanelIds.GROUP_FINDER_MONITOR
local TICKER_PANEL_ID = PanelIds.TICKER
local UTILITY_PANEL_ID = PanelIds.UTILITY
local GROUPING_PANEL_ID = PanelIds.GROUPING
local AUTO_INVITE_PANEL_ID = PanelIds.AUTO_INVITE
local LUA_GC_PANEL_ID = PanelIds.LUA_GC
local AUTO_BOUND_PANEL_ID = PanelIds.AUTO_BOUND
local AUTO_CHARGE_PANEL_ID = PanelIds.AUTO_CHARGE
local AUTO_REPAIR_PANEL_ID = PanelIds.AUTO_REPAIR
local COMBAT_PANEL_ID = PanelIds.COMBAT
local COMBAT_INFINITE_ARCHIVE_PANEL_ID = PanelIds.COMBAT_INFINITE_ARCHIVE
local COMBAT_MISCELLANEOUS_PANEL_ID = PanelIds.COMBAT_MISCELLANEOUS
local TRIAL_TIMER_PANEL_ID = PanelIds.TRIAL_TIMER
local ULTIMATE_COUNTDOWN_PANEL_ID = PanelIds.ULTIMATE_COUNTDOWN
local ULTIMATE_COUNTDOWN_FRONT_PANEL_ID = PanelIds.ULTIMATE_COUNTDOWN_FRONT
local ULTIMATE_COUNTDOWN_BACK_PANEL_ID = PanelIds.ULTIMATE_COUNTDOWN_BACK
local DEBUG_PANEL_ID = PanelIds.DEBUG
local BUFFS_DEBUFFS_PANEL_ID = PanelIds.BUFFS_DEBUFFS
local BUFFS_DEBUFFS_TRACKERS_PANEL_ID = PanelIds.BUFFS_DEBUFFS_TRACKERS
local PROGRESS_PANEL_ID = PanelIds.PROGRESS
local XP_TRACKER_PANEL_ID = PanelIds.XP_TRACKER
local XP_TIMERS_PANEL_ID = PanelIds.XP_TIMERS
function GamepadOptions.BuildMountsEntry()
    return {
        panel = ROOT_PANEL_ID,
        system = ROOT_PANEL_ID,
        settingId = 6,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.mounts_9516ba1"),
        gamepadTextOverride = NQOL.L("ui.navigation.mounts_9516ba1"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.control_mounted_interactions_and_riding_training_8f78f59"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(MOUNTS_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildAntiquitiesEntry()
    return {
        panel = ROOT_PANEL_ID,
        system = ROOT_PANEL_ID,
        settingId = 2,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.antiquities_20f1518"),
        gamepadTextOverride = NQOL.L("ui.navigation.antiquities_20f1518"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.filter_active_leads_to_focus_on_antiquities_still_mi_c2f5bee"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(ANTIQUITIES_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildGearEntry()
    return {
        panel = ROOT_PANEL_ID,
        system = ROOT_PANEL_ID,
        settingId = 4,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.gear_def2b5f"),
        gamepadTextOverride = NQOL.L("ui.navigation.gear_def2b5f"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.recharge_weapons_repair_worn_gear_and_bind_new_gear__61be378"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(GEAR_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildCombatEntry()
    return {
        panel = ROOT_PANEL_ID,
        system = ROOT_PANEL_ID,
        settingId = 18,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.combat_af169bb"),
        gamepadTextOverride = NQOL.L("ui.navigation.combat_af169bb"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.configure_combat_focused_countdowns_add2b90"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(COMBAT_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildUltimateCountdownEntry()
    return {
        panel = COMBAT_PANEL_ID,
        system = COMBAT_PANEL_ID,
        settingId = 1,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.ultimate_countdown_12344ec"),
        gamepadTextOverride = NQOL.L("ui.navigation.ultimate_countdown_12344ec"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.configure_user_defined_ultimate_countdowns_for_each__08a77c3"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(ULTIMATE_COUNTDOWN_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildTrialTimerEntry()
    return {
        panel = COMBAT_PANEL_ID,
        system = COMBAT_PANEL_ID,
        settingId = 3,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.trial_timer"),
        gamepadTextOverride = NQOL.L("ui.navigation.trial_timer"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.trial_timer_tooltip"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(TRIAL_TIMER_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildCombatInfiniteArchiveEntry()
    return {
        panel = COMBAT_PANEL_ID,
        system = COMBAT_PANEL_ID,
        settingId = 4,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.infinite_archive_52c9059"),
        gamepadTextOverride = NQOL.L("ui.navigation.infinite_archive_52c9059"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.track_infinite_archive_solo_and_duo_personal_bests_a_db5419b"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(COMBAT_INFINITE_ARCHIVE_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildCombatMiscellaneousEntry()
    return {
        panel = COMBAT_PANEL_ID,
        system = COMBAT_PANEL_ID,
        settingId = 2,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.miscellaneous"),
        gamepadTextOverride = NQOL.L("ui.navigation.miscellaneous"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.configure_optional_combat_integrations"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(COMBAT_MISCELLANEOUS_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildUltimateCountdownFrontEntry()
    local ultimateCountdown = NQOL.Features.UltimateCountdown
    local countdownKey = ultimateCountdown.GetFrontBarKey()

    return {
        panel = ULTIMATE_COUNTDOWN_PANEL_ID,
        system = ULTIMATE_COUNTDOWN_PANEL_ID,
        settingId = 1,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = ultimateCountdown.GetEntryLabel(countdownKey),
        gamepadTextOverride = ultimateCountdown.GetEntryLabel(countdownKey),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, ultimateCountdown.GetEntryTooltip(countdownKey))
        end,
        callback = function()
            GamepadOptions.ShowPanel(ULTIMATE_COUNTDOWN_FRONT_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildUltimateCountdownBackEntry()
    local ultimateCountdown = NQOL.Features.UltimateCountdown
    local countdownKey = ultimateCountdown.GetBackBarKey()

    return {
        panel = ULTIMATE_COUNTDOWN_PANEL_ID,
        system = ULTIMATE_COUNTDOWN_PANEL_ID,
        settingId = 2,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = ultimateCountdown.GetEntryLabel(countdownKey),
        gamepadTextOverride = ultimateCountdown.GetEntryLabel(countdownKey),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, ultimateCountdown.GetEntryTooltip(countdownKey))
        end,
        callback = function()
            GamepadOptions.ShowPanel(ULTIMATE_COUNTDOWN_BACK_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildDebugEntry()
    return {
        panel = ROOT_PANEL_ID,
        system = ROOT_PANEL_ID,
        settingId = 19,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = "Debug",
        gamepadTextOverride = "Debug",
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, "Open development-only debugging tools.")
        end,
        callback = function()
            GamepadOptions.ShowPanel(DEBUG_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildExportAchievementSectionsOption()
    local debugFeature = NQOL.Features.Debug

    return {
        panel = DEBUG_PANEL_ID,
        system = DEBUG_PANEL_ID,
        settingId = 1,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = debugFeature.GetExportAchievementSectionsLabel(),
        gamepadTextOverride = debugFeature.GetExportAchievementSectionsLabel(),
        onInitializeFunction = GamepadOptions.InitializeDecorativeEntry,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, debugFeature.GetExportAchievementSectionsTooltip())
        end,
        callback = function()
            debugFeature.ExportAchievementSections()
        end,
    }
end

function GamepadOptions.BuildResetWelcomeMessageOption()
    return {
        panel = DEBUG_PANEL_ID,
        system = DEBUG_PANEL_ID,
        settingId = 2,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = "Reset Welcome Msg",
        gamepadTextOverride = "Reset Welcome Msg",
        onInitializeFunction = GamepadOptions.InitializeDecorativeEntry,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, "Shows the Welcome to NQOL message again after the next UI reload.")
        end,
        callback = function()
            NQOL.FirstRun.ResetMessage()
        end,
    }
end

function GamepadOptions.BuildResetWhatsNewMessageOption()
    return {
        panel = DEBUG_PANEL_ID,
        system = DEBUG_PANEL_ID,
        settingId = 3,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = "Reset What's new msg",
        gamepadTextOverride = "Reset What's new msg",
        onInitializeFunction = GamepadOptions.InitializeDecorativeEntry,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, "Shows the current What's New message again after the next UI reload.")
        end,
        callback = function()
            NQOL.WhatsNew.ResetMessage()
        end,
    }
end

function GamepadOptions.BuildPrintAnnotationTestItemLinksOption()
    local debugFeature = NQOL.Features.Debug

    return {
        panel = DEBUG_PANEL_ID,
        system = DEBUG_PANEL_ID,
        settingId = 4,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = debugFeature.GetPrintAnnotationTestItemLinksLabel(),
        gamepadTextOverride = debugFeature.GetPrintAnnotationTestItemLinksLabel(),
        onInitializeFunction = GamepadOptions.InitializeDecorativeEntry,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, debugFeature.GetPrintAnnotationTestItemLinksTooltip())
        end,
        callback = function()
            debugFeature.PrintAnnotationTestItemLinks()
        end,
    }
end

function GamepadOptions.BuildGenerateBenignLuaErrorOption()
    local debugFeature = NQOL.Features.Debug

    return {
        panel = DEBUG_PANEL_ID,
        system = DEBUG_PANEL_ID,
        settingId = 5,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = debugFeature.GetGenerateBenignLuaErrorLabel(),
        gamepadTextOverride = debugFeature.GetGenerateBenignLuaErrorLabel(),
        onInitializeFunction = GamepadOptions.InitializeDecorativeEntry,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, debugFeature.GetGenerateBenignLuaErrorTooltip())
        end,
        callback = function()
            debugFeature.GenerateBenignLuaError()
        end,
    }
end

function GamepadOptions.BuildAutoBoundEntry()
    return {
        panel = GEAR_PANEL_ID,
        system = GEAR_PANEL_ID,
        settingId = 3,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.auto_bind_2381c3f"),
        gamepadTextOverride = NQOL.L("ui.navigation.auto_bind_2381c3f"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            local gear = NQOL.Features.Gear
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, gear.GetAutoBoundTooltip())
        end,
        callback = function()
            GamepadOptions.ShowPanel(AUTO_BOUND_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildAutoChargeEntry()
    local gear = NQOL.Features.Gear

    return {
        panel = GEAR_PANEL_ID,
        system = GEAR_PANEL_ID,
        settingId = 1,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = gear.GetAutoChargeLabel(),
        gamepadTextOverride = gear.GetAutoChargeLabel(),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, gear.GetAutoChargeTooltip())
        end,
        callback = function()
            GamepadOptions.ShowPanel(AUTO_CHARGE_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildAutoRepairEntry()
    local gear = NQOL.Features.Gear

    return {
        panel = GEAR_PANEL_ID,
        system = GEAR_PANEL_ID,
        settingId = 2,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = gear.GetAutoRepairLabel(),
        gamepadTextOverride = gear.GetAutoRepairLabel(),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, gear.GetAutoRepairTooltip())
        end,
        callback = function()
            GamepadOptions.ShowPanel(AUTO_REPAIR_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildGroupingEntry()
    return {
        panel = ROOT_PANEL_ID,
        system = ROOT_PANEL_ID,
        settingId = 11,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.grouping_2ae6967"),
        gamepadTextOverride = NQOL.L("ui.navigation.grouping_2ae6967"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.configure_group_related_automation_10da55f"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(GROUPING_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildProvisioningEntry()
    return {
        panel = ROOT_PANEL_ID,
        system = ROOT_PANEL_ID,
        settingId = 7,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.provisioning_c9d0ab3"),
        gamepadTextOverride = NQOL.L("ui.navigation.provisioning_c9d0ab3"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.refresh_your_preferred_food_or_drink_buff_for_each_c_e50f304"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(PROVISIONING_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildMapEntry()
    return {
        panel = ROOT_PANEL_ID,
        system = ROOT_PANEL_ID,
        settingId = 5,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.map_ab478f3"),
        gamepadTextOverride = NQOL.L("ui.navigation.map_ab478f3"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.configure_map_and_minimap_features"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(MAP_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildMinimapEntry()
    return {
        panel = MAP_PANEL_ID,
        system = MAP_PANEL_ID,
        settingId = 1,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.minimap_03000e5"),
        gamepadTextOverride = NQOL.L("ui.navigation.minimap_03000e5"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.display_the_native_world_map_as_a_minimap_during_gam_3e46e24"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(MINIMAP_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildMapSettingsEntry()
    return {
        panel = MAP_PANEL_ID,
        system = MAP_PANEL_ID,
        settingId = 2,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.map_ab478f3"),
        gamepadTextOverride = NQOL.L("ui.navigation.map_ab478f3"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.configure_freeport_and_wayshrine_confirmations_36829aa"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(MAP_OPTIONS_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildGPSEntry()
    local gps = NQOL.Features.GPS
    return {
        panel = MAP_PANEL_ID,
        system = MAP_PANEL_ID,
        settingId = 3,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = gps.GetName(),
        gamepadTextOverride = gps.GetName(),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, gps.GetEntryTooltip())
        end,
        callback = function()
            GamepadOptions.ShowPanel(GPS_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildFishingEntry()
    return {
        panel = ROOT_PANEL_ID,
        system = ROOT_PANEL_ID,
        settingId = 17,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.fishing_cadfb5b"),
        gamepadTextOverride = NQOL.L("ui.navigation.fishing_cadfb5b"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.configure_fishing_alerts_and_quality_of_life_helpers_ae11614"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(FISHING_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildFishingTrackerEntry()
    return {
        panel = FISHING_PANEL_ID,
        system = FISHING_PANEL_ID,
        settingId = 5,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.fishing_tracker_d082c00"),
        gamepadTextOverride = NQOL.L("ui.navigation.fishing_tracker_d082c00"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.configure_the_rare_fish_water_type_tracker_74049f9"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(FISHING_TRACKER_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildUIEntry()
    return {
        panel = ROOT_PANEL_ID,
        system = ROOT_PANEL_ID,
        settingId = 8,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.ui_9d57875"),
        gamepadTextOverride = NQOL.L("ui.navigation.ui_9d57875"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.tune_frame_reticle_alert_text_and_active_quest_track_b88bda7"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(UI_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildCameraEntry()
    local camera = NQOL.Features.Camera
    return {
        panel = UI_PANEL_ID,
        system = UI_PANEL_ID,
        settingId = 3,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = camera.GetName(),
        gamepadTextOverride = camera.GetName(),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, camera.GetEntryTooltip())
        end,
        callback = function()
            GamepadOptions.ShowPanel(CAMERA_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildCombatReticleEntry()
    return {
        panel = COMBAT_PANEL_ID,
        system = COMBAT_PANEL_ID,
        settingId = 5,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.combat_reticle_7a159a7"),
        gamepadTextOverride = NQOL.L("ui.navigation.combat_reticle_7a159a7"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.customize_the_center_combat_reticle_color_and_shape_6caf384"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(COMBAT_RETICLE_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildReticleInfoEntry()
    return {
        panel = COMBAT_RETICLE_PANEL_ID,
        system = COMBAT_RETICLE_PANEL_ID,
        settingId = 6,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.Features.UI.GetReticleInfoLabel(),
        gamepadTextOverride = NQOL.Features.UI.GetReticleInfoLabel(),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.Features.UI.GetReticleInfoTooltip())
        end,
        callback = function()
            GamepadOptions.ShowPanel(RETICLE_INFO_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildReticleInfoPositionEntry(settingId, positionKey, targetPanelId)
    local ui = NQOL.Features.UI
    return {
        panel = RETICLE_INFO_PANEL_ID,
        system = RETICLE_INFO_PANEL_ID,
        settingId = settingId,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = ui.GetReticleInfoPositionLabel(positionKey),
        gamepadTextOverride = ui.GetReticleInfoPositionLabel(positionKey),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, ui.GetReticleInfoPositionTooltip())
        end,
        callback = function()
            GamepadOptions.ShowPanel(targetPanelId)
        end,
    }
end

function GamepadOptions.BuildReticleInfoTopLeftEntry()
    return GamepadOptions.BuildReticleInfoPositionEntry(1, "topLeft", RETICLE_INFO_TOP_LEFT_PANEL_ID)
end

function GamepadOptions.BuildReticleInfoTopRightEntry()
    return GamepadOptions.BuildReticleInfoPositionEntry(2, "topRight", RETICLE_INFO_TOP_RIGHT_PANEL_ID)
end

function GamepadOptions.BuildReticleInfoBottomLeftEntry()
    return GamepadOptions.BuildReticleInfoPositionEntry(3, "bottomLeft", RETICLE_INFO_BOTTOM_LEFT_PANEL_ID)
end

function GamepadOptions.BuildReticleInfoBottomRightEntry()
    return GamepadOptions.BuildReticleInfoPositionEntry(4, "bottomRight", RETICLE_INFO_BOTTOM_RIGHT_PANEL_ID)
end

function GamepadOptions.BuildDefaultFramesEntry()
    return {
        panel = UI_PANEL_ID,
        system = UI_PANEL_ID,
        settingId = 1,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.default_frames_acdfa98"),
        gamepadTextOverride = NQOL.L("ui.navigation.default_frames_acdfa98"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.move_the_game_s_default_ui_frames_and_preview_their__65f71e6"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(DEFAULT_FRAMES_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildChatEntry()
    return {
        panel = SOCIAL_PANEL_ID,
        system = SOCIAL_PANEL_ID,
        settingId = 1,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.chat_2ced57f"),
        gamepadTextOverride = NQOL.L("ui.navigation.chat_2ced57f"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.customize_chat_timestamps_history_window_placement_a_fb0cb2b"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(CHAT_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildSocialEntry()
    return {
        panel = ROOT_PANEL_ID,
        system = ROOT_PANEL_ID,
        settingId = 3,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.social_41a5750"),
        gamepadTextOverride = NQOL.L("ui.navigation.social_41a5750"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.configure_chat_and_online_friends_displays_2196c21"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(SOCIAL_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildFriendsEntry()
    local friends = NQOL.Features.Friends

    return {
        panel = SOCIAL_PANEL_ID,
        system = SOCIAL_PANEL_ID,
        settingId = 2,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = friends.GetEntryLabel,
        gamepadTextOverride = friends.GetEntryLabel,
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, friends.GetEntryTooltip())
        end,
        callback = function()
            GamepadOptions.ShowPanel(FRIENDS_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildGuildsEntry()
    return {
        panel = SOCIAL_PANEL_ID,
        system = SOCIAL_PANEL_ID,
        settingId = 4,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = GetString(SI_MAIN_MENU_GUILDS),
        gamepadTextOverride = GetString(SI_MAIN_MENU_GUILDS),
        onInitializeFunction = GamepadOptions.InitializeNavigationEntry,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("features.guilds.entry_tooltip"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(GUILDS_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildGroupFinderMonitorEntry()
    local monitor = NQOL.Features.GroupFinderMonitor

    return {
        panel = SOCIAL_PANEL_ID,
        system = SOCIAL_PANEL_ID,
        settingId = 3,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = monitor.GetEntryLabel,
        gamepadTextOverride = monitor.GetEntryLabel,
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, monitor.GetEntryTooltip())
        end,
        callback = function()
            GamepadOptions.ShowPanel(GROUP_FINDER_MONITOR_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildBuffsDebuffsEntry()
    return {
        panel = ROOT_PANEL_ID,
        system = ROOT_PANEL_ID,
        settingId = 12,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.buffs_debuffs_774d3a3"),
        gamepadTextOverride = NQOL.L("ui.navigation.buffs_debuffs_774d3a3"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.track_active_major_and_minor_buffs_and_debuffs_on_yo_61ace99"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(BUFFS_DEBUFFS_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildBuffsDebuffsTrackersEntry()
    return {
        panel = BUFFS_DEBUFFS_PANEL_ID,
        system = BUFFS_DEBUFFS_PANEL_ID,
        settingId = 13,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.trackers_4be3b88"),
        gamepadTextOverride = NQOL.L("ui.navigation.trackers_4be3b88"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.choose_which_buff_and_debuff_names_the_tracker_is_al_9b40cc3"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(BUFFS_DEBUFFS_TRACKERS_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildProgressEntry()
    return {
        panel = ROOT_PANEL_ID,
        system = ROOT_PANEL_ID,
        settingId = 13,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.progress_1b90271"),
        gamepadTextOverride = NQOL.L("ui.navigation.progress_1b90271"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.configure_dedicated_progression_displays_b8fd5b5"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(PROGRESS_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildXpTrackerEntry()
    return {
        panel = PROGRESS_PANEL_ID,
        system = PROGRESS_PANEL_ID,
        settingId = 1,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.xp_53af638"),
        gamepadTextOverride = NQOL.L("ui.navigation.xp_53af638"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.track_current_xp_progress_recent_xp_gains_and_xp_per_71c1dd1"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(XP_TRACKER_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildXpTimersEntry()
    local progress = NQOL.Features.Progress

    return {
        panel = XP_TRACKER_PANEL_ID,
        system = XP_TRACKER_PANEL_ID,
        settingId = 9,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = progress.GetXpTimersLabel(),
        gamepadTextOverride = progress.GetXpTimersLabel(),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, progress.GetXpTimersTooltip())
        end,
        callback = function()
            GamepadOptions.ShowPanel(XP_TIMERS_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildBaseDungeonsEntry()
    return {
        panel = PROGRESS_PANEL_ID,
        system = PROGRESS_PANEL_ID,
        settingId = 3,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.base_dungeons_98c539e"),
        gamepadTextOverride = NQOL.L("ui.navigation.base_dungeons_98c539e"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.list_base_game_dungeon_progress_in_a_dedicated_progr_0061935"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(GamepadOptions.DUNGEONS_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildDlcDungeonsEntry()
    return {
        panel = PROGRESS_PANEL_ID,
        system = PROGRESS_PANEL_ID,
        settingId = 4,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.dlc_dungeons_d2c30fd"),
        gamepadTextOverride = NQOL.L("ui.navigation.dlc_dungeons_d2c30fd"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.list_dlc_dungeon_progress_in_a_dedicated_progress_di_19c2102"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(GamepadOptions.DLC_DUNGEONS_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildTrialsEntry()
    return {
        panel = PROGRESS_PANEL_ID,
        system = PROGRESS_PANEL_ID,
        settingId = 5,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.trials_3dcdcaf"),
        gamepadTextOverride = NQOL.L("ui.navigation.trials_3dcdcaf"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.list_trial_progress_in_a_dedicated_progress_display_f9f979a"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(GamepadOptions.TRIALS_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildArenasEntry()
    return {
        panel = PROGRESS_PANEL_ID,
        system = PROGRESS_PANEL_ID,
        settingId = 6,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.arenas_05bb528"),
        gamepadTextOverride = NQOL.L("ui.navigation.arenas_05bb528"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.list_arena_progress_in_a_dedicated_progress_display_7d19d8c"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(GamepadOptions.ARENAS_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildSoloDungeonsEntry()
    return {
        panel = PROGRESS_PANEL_ID,
        system = PROGRESS_PANEL_ID,
        settingId = 8,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.solo_dungeons"),
        gamepadTextOverride = NQOL.L("ui.navigation.solo_dungeons"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.solo_dungeons_tooltip"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(GamepadOptions.SOLO_DUNGEONS_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildInfiniteArchiveEntry()
    return {
        panel = PROGRESS_PANEL_ID,
        system = PROGRESS_PANEL_ID,
        settingId = 7,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.infinite_archive_52c9059"),
        gamepadTextOverride = NQOL.L("ui.navigation.infinite_archive_52c9059"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.list_infinite_archive_achievement_progress_and_the_h_fe80591"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(GamepadOptions.INFINITE_ARCHIVE_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildTickerEntry()
    return {
        panel = ROOT_PANEL_ID,
        system = ROOT_PANEL_ID,
        settingId = 9,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.ticker_5586cf3"),
        gamepadTextOverride = NQOL.L("ui.navigation.ticker_5586cf3"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.choose_which_account_character_and_performance_value_8873cc8"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(TICKER_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildUtilityEntry()
    return {
        panel = ROOT_PANEL_ID,
        system = ROOT_PANEL_ID,
        settingId = 10,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.utility_8918950"),
        gamepadTextOverride = NQOL.L("ui.navigation.utility_8918950"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.manage_small_account_wide_automation_and_convenience_7f26a7e"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(UTILITY_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildAutoInviteEntry()
    return {
        panel = GROUPING_PANEL_ID,
        system = GROUPING_PANEL_ID,
        settingId = 1,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.auto_invite_da2185d"),
        gamepadTextOverride = NQOL.L("ui.navigation.auto_invite_da2185d"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.invite_players_automatically_when_they_send_the_conf_3cbeaae"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(AUTO_INVITE_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildLuaGcEntry()
    return {
        panel = UTILITY_PANEL_ID,
        system = UTILITY_PANEL_ID,
        settingId = 6,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.lua_gc_be3883a"),
        gamepadTextOverride = NQOL.L("ui.navigation.lua_gc_be3883a"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            local luaGc = NQOL.Features.LuaGc
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, luaGc.GetEnabledTooltip())
        end,
        callback = function()
            GamepadOptions.ShowPanel(LUA_GC_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildActiveQuestEntry()
    return {
        panel = DEFAULT_FRAMES_PANEL_ID,
        system = DEFAULT_FRAMES_PANEL_ID,
        settingId = 3,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.active_quest_8036d24"),
        gamepadTextOverride = NQOL.L("ui.navigation.active_quest_8036d24"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.move_the_focused_quest_tracker_and_preview_its_posit_8b97f8f"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(ACTIVE_QUEST_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildAnnouncementsEntry()
    return {
        panel = DEFAULT_FRAMES_PANEL_ID,
        system = DEFAULT_FRAMES_PANEL_ID,
        settingId = 4,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("features.ui.announcements"),
        gamepadTextOverride = NQOL.L("features.ui.announcements"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("features.ui.announcements_navigation_tooltip"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(ANNOUNCEMENTS_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildActiveCombatTipsEntry()
    return {
        panel = DEFAULT_FRAMES_PANEL_ID,
        system = DEFAULT_FRAMES_PANEL_ID,
        settingId = 5,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.active_combat_tips_6e90fb1"),
        gamepadTextOverride = NQOL.L("ui.navigation.active_combat_tips_6e90fb1"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.move_active_combat_tips_and_preview_their_position_w_e0bf6d4"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(ACTIVE_COMBAT_TIPS_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildSynergyPromptsEntry()
    return {
        panel = DEFAULT_FRAMES_PANEL_ID,
        system = DEFAULT_FRAMES_PANEL_ID,
        settingId = 6,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.synergy_prompts_384f9c9"),
        gamepadTextOverride = NQOL.L("ui.navigation.synergy_prompts_384f9c9"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.move_synergy_prompts_and_preview_their_position_whil_3860a10"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(SYNERGY_PROMPTS_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildCenterScreenAnnounceEntry()
    return {
        panel = DEFAULT_FRAMES_PANEL_ID,
        system = DEFAULT_FRAMES_PANEL_ID,
        settingId = 7,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.center_screen_announce_9b7d2b5"),
        gamepadTextOverride = NQOL.L("ui.navigation.center_screen_announce_9b7d2b5"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.move_center_screen_announcements_and_preview_their_p_8e15494"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(CENTER_SCREEN_ANNOUNCE_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildGoldenPursuitEntry()
    return {
        panel = DEFAULT_FRAMES_PANEL_ID,
        system = DEFAULT_FRAMES_PANEL_ID,
        settingId = 11,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("features.ui.golden_pursuit"),
        gamepadTextOverride = NQOL.L("features.ui.golden_pursuit"),
        onInitializeFunction = GamepadOptions.InitializeNavigationEntry,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.Features.UI.GetGoldenPursuitEnabledTooltip())
        end,
        callback = function()
            GamepadOptions.ShowPanel(GOLDEN_PURSUIT_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildHouseTrackerEntry()
    return {
        panel = DEFAULT_FRAMES_PANEL_ID,
        system = DEFAULT_FRAMES_PANEL_ID,
        settingId = 12,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("features.ui.house_tracker"),
        gamepadTextOverride = NQOL.L("features.ui.house_tracker"),
        onInitializeFunction = GamepadOptions.InitializeNavigationEntry,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.Features.UI.GetHouseTrackerEnabledTooltip())
        end,
        callback = function()
            GamepadOptions.ShowPanel(HOUSE_TRACKER_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildInfiniteArchiveFrameEntry()
    return {
        panel = DEFAULT_FRAMES_PANEL_ID,
        system = DEFAULT_FRAMES_PANEL_ID,
        settingId = 8,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.infinite_archive_52c9059"),
        gamepadTextOverride = NQOL.L("ui.navigation.infinite_archive_52c9059"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.move_the_infinite_archive_frame_and_preview_its_posi_7076717"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(INFINITE_ARCHIVE_FRAME_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildLootLogEntry()
    return {
        panel = UI_PANEL_ID,
        system = UI_PANEL_ID,
        settingId = 8,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.loot_log_f30da82"),
        gamepadTextOverride = NQOL.L("ui.navigation.loot_log_f30da82"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.configure_additions_to_the_game_s_loot_log_a60f1b6"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(LOOT_LOG_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildPlayerInfoEntry()
    return {
        panel = UI_PANEL_ID,
        system = UI_PANEL_ID,
        settingId = 13,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.player_info_f6475d5"),
        gamepadTextOverride = NQOL.L("ui.navigation.player_info_f6475d5"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.configure_a_custom_player_info_bar_with_player_id_ch_79e9a78"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(PLAYER_INFO_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildPlayerInteractionEntry()
    return {
        panel = DEFAULT_FRAMES_PANEL_ID,
        system = DEFAULT_FRAMES_PANEL_ID,
        settingId = 9,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.player_interaction_c4371b1"),
        gamepadTextOverride = NQOL.L("ui.navigation.player_interaction_c4371b1"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.move_player_interaction_prompts_and_preview_their_po_7463900"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(PLAYER_INTERACTION_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildSubtitlesEntry()
    return {
        panel = DEFAULT_FRAMES_PANEL_ID,
        system = DEFAULT_FRAMES_PANEL_ID,
        settingId = 10,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.subtitles_1777047"),
        gamepadTextOverride = NQOL.L("ui.navigation.subtitles_1777047"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.move_subtitles_and_preview_their_position_while_edit_245e063"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(SUBTITLES_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildFrameStylingEntry()
    return {
        panel = UI_PANEL_ID,
        system = UI_PANEL_ID,
        settingId = 12,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.custom_frames_80b9e03"),
        gamepadTextOverride = NQOL.L("ui.navigation.custom_frames_80b9e03"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.configure_nqol_frame_replacements_and_vanilla_frame__be33895"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(GamepadOptions.FRAME_STYLING_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildPlayerFrameEntry()
    return {
        panel = GamepadOptions.FRAME_STYLING_PANEL_ID,
        system = GamepadOptions.FRAME_STYLING_PANEL_ID,
        settingId = 1,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.player_frame_2197e12"),
        gamepadTextOverride = NQOL.L("ui.navigation.player_frame_2197e12"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.configure_the_player_health_magicka_stamina_and_moun_101d985"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(GamepadOptions.PLAYER_FRAME_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildCompanionFrameEntry()
    return {
        panel = GamepadOptions.FRAME_STYLING_PANEL_ID,
        system = GamepadOptions.FRAME_STYLING_PANEL_ID,
        settingId = 2,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.companion_frame_5c3e63f"),
        gamepadTextOverride = NQOL.L("ui.navigation.companion_frame_5c3e63f"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.configure_the_companion_health_frame_49b6067"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(GamepadOptions.COMPANION_FRAME_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildGroupFrameEntry()
    return {
        panel = GamepadOptions.FRAME_STYLING_PANEL_ID,
        system = GamepadOptions.FRAME_STYLING_PANEL_ID,
        settingId = 3,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.group_frame_b9dc0c6"),
        gamepadTextOverride = NQOL.L("ui.navigation.group_frame_b9dc0c6"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.L("ui.navigation.configure_the_group_and_raid_health_frame_fe9256f"))
        end,
        callback = function()
            GamepadOptions.ShowPanel(GamepadOptions.GROUP_FRAME_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildClassicEntry()
    return {
        panel = GamepadOptions.PLAYER_FRAME_PANEL_ID,
        system = GamepadOptions.PLAYER_FRAME_PANEL_ID,
        settingId = 7,
        controlType = OPTIONS_INVOKE_CALLBACK,
        header = GamepadOptions.MakeHeader(NQOL.L("ui.headers.preset_settings_f38c00a")),
        text = NQOL.L("ui.navigation.classic_130cd7f"),
        gamepadTextOverride = NQOL.L("ui.navigation.classic_130cd7f"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.Features.PlayerBars.GetClassicTooltip())
        end,
        callback = function()
            GamepadOptions.ShowPanel(GamepadOptions.PLAYER_FRAME_CLASSIC_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildPyramidEntry()
    return {
        panel = GamepadOptions.PLAYER_FRAME_PANEL_ID,
        system = GamepadOptions.PLAYER_FRAME_PANEL_ID,
        settingId = 8,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.pyramid_38d1f19"),
        gamepadTextOverride = NQOL.L("ui.navigation.pyramid_38d1f19"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.Features.PlayerBars.GetPyramidTooltip())
        end,
        callback = function()
            GamepadOptions.ShowPanel(GamepadOptions.PLAYER_FRAME_PYRAMID_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildStackEntry()
    return {
        panel = GamepadOptions.PLAYER_FRAME_PANEL_ID,
        system = GamepadOptions.PLAYER_FRAME_PANEL_ID,
        settingId = 9,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.stack_83e5a0d"),
        gamepadTextOverride = NQOL.L("ui.navigation.stack_83e5a0d"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.Features.PlayerBars.GetStackTooltip())
        end,
        callback = function()
            GamepadOptions.ShowPanel(GamepadOptions.PLAYER_FRAME_STACK_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildVerticalEntry()
    return {
        panel = GamepadOptions.PLAYER_FRAME_PANEL_ID,
        system = GamepadOptions.PLAYER_FRAME_PANEL_ID,
        settingId = 10,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.vertical_4b937cc"),
        gamepadTextOverride = NQOL.L("ui.navigation.vertical_4b937cc"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.Features.PlayerBars.GetVerticalTooltip())
        end,
        callback = function()
            GamepadOptions.ShowPanel(GamepadOptions.PLAYER_FRAME_VERTICAL_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildRadialEntry()
    return {
        panel = GamepadOptions.PLAYER_FRAME_PANEL_ID,
        system = GamepadOptions.PLAYER_FRAME_PANEL_ID,
        settingId = 11,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = NQOL.L("ui.navigation.radial_e2a166d"),
        gamepadTextOverride = NQOL.L("ui.navigation.radial_e2a166d"),
        onInitializeFunction = function(control)
            GamepadOptions.InitializeNavigationEntry(control)
        end,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, NQOL.Features.PlayerBars.GetRadialTooltip())
        end,
        callback = function()
            GamepadOptions.ShowPanel(GamepadOptions.PLAYER_FRAME_RADIAL_PANEL_ID)
        end,
    }
end

function GamepadOptions.BuildRemainMountedOption()
    local mounts = NQOL.Features.Mounts

    return {
        panel = MOUNTS_PANEL_ID,
        system = MOUNTS_PANEL_ID,
        settingId = 1,
        controlType = OPTIONS_CHECKBOX,
        text = mounts.GetRemainMountedLabel(),
        gamepadTextOverride = mounts.GetRemainMountedLabel(),
        tooltipText = mounts.GetRemainMountedTooltip(),
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, mounts.GetRemainMountedTooltip())
        end,
        onInitializeFunction = GamepadOptions.RunOptionInitialize,
        GetSettingOverride = function()
            return mounts.GetRemainMounted()
        end,
        SetSettingOverride = function(_, value)
            mounts.SetRemainMounted(value)
        end,
    }
end

function GamepadOptions.BuildAllowUseInteractionsOption()
    local mounts = NQOL.Features.Mounts
    return GamepadOptions.BuildCheckboxOption(
        MOUNTS_PANEL_ID,
        4,
        mounts.GetAllowUseInteractionsLabel(),
        mounts.GetAllowUseInteractionsTooltip(),
        mounts.GetAllowUseInteractions,
        mounts.SetAllowUseInteractions
    )
end

function GamepadOptions.BuildAllowOpenInteractionsOption()
    local mounts = NQOL.Features.Mounts
    return GamepadOptions.BuildCheckboxOption(
        MOUNTS_PANEL_ID,
        5,
        mounts.GetAllowOpenInteractionsLabel(),
        mounts.GetAllowOpenInteractionsTooltip(),
        mounts.GetAllowOpenInteractions,
        mounts.SetAllowOpenInteractions
    )
end

function GamepadOptions.BuildAllowTalkInteractionsOption()
    local mounts = NQOL.Features.Mounts
    return GamepadOptions.BuildCheckboxOption(
        MOUNTS_PANEL_ID,
        6,
        mounts.GetAllowTalkInteractionsLabel(),
        mounts.GetAllowTalkInteractionsTooltip(),
        mounts.GetAllowTalkInteractions,
        mounts.SetAllowTalkInteractions
    )
end

function GamepadOptions.BuildAllowActivateInteractionsOption()
    local mounts = NQOL.Features.Mounts
    return GamepadOptions.BuildCheckboxOption(
        MOUNTS_PANEL_ID,
        7,
        mounts.GetAllowActivateInteractionsLabel(),
        mounts.GetAllowActivateInteractionsTooltip(),
        mounts.GetAllowActivateInteractions,
        mounts.SetAllowActivateInteractions
    )
end

function GamepadOptions.BuildTrainingCheckOption()
    local mounts = NQOL.Features.Mounts

    return {
        panel = MOUNTS_PANEL_ID,
        system = MOUNTS_PANEL_ID,
        settingId = 3,
        controlType = OPTIONS_CHECKBOX,
        text = mounts.GetTrainingCheckLabel(),
        gamepadTextOverride = mounts.GetTrainingCheckLabel(),
        tooltipText = mounts.GetTrainingCheckTooltip(),
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, mounts.GetTrainingCheckTooltip())
        end,
        onInitializeFunction = GamepadOptions.RunOptionInitialize,
        GetSettingOverride = function()
            return mounts.GetTrainingCheck()
        end,
        SetSettingOverride = function(_, value)
            mounts.SetTrainingCheck(value)
        end,
    }
end

function GamepadOptions.BuildShowMissingActiveLeadsButtonOption()
    local antiquities = NQOL.Features.Antiquities
    return GamepadOptions.BuildCheckboxOption(ANTIQUITIES_PANEL_ID, 1, antiquities.GetShowMissingActiveLeadsButtonLabel(), antiquities.GetShowMissingActiveLeadsButtonTooltip(), antiquities.GetShowMissingActiveLeadsButton, antiquities.SetShowMissingActiveLeadsButton, nil, antiquities.GetShowMissingActiveLeadsButtonDefault)
end

function GamepadOptions.BuildAutoEyeOption()
    local antiquities = NQOL.Features.Antiquities

    return {
        panel = ANTIQUITIES_PANEL_ID,
        system = ANTIQUITIES_PANEL_ID,
        settingId = 2,
        controlType = OPTIONS_CHECKBOX,
        text = antiquities.GetAutoEyeLabel(),
        gamepadTextOverride = antiquities.GetAutoEyeLabel(),
        tooltipText = antiquities.GetAutoEyeTooltip(),
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, antiquities.GetAutoEyeTooltip())
        end,
        onInitializeFunction = GamepadOptions.RunOptionInitialize,
        GetSettingOverride = function()
            return antiquities.GetAutoEye()
        end,
        SetSettingOverride = function(_, value)
            antiquities.SetAutoEye(value)
        end,
    }
end

function GamepadOptions.BuildVendorLeadIndicatorsOption()
    local antiquities = NQOL.Features.Antiquities
    return GamepadOptions.BuildCheckboxOption(ANTIQUITIES_PANEL_ID, 3, antiquities.GetVendorLeadIndicatorsLabel(), antiquities.GetVendorLeadIndicatorsTooltip(), antiquities.GetVendorLeadIndicators, antiquities.SetVendorLeadIndicators, nil, antiquities.GetVendorLeadIndicatorsDefault)
end

function GamepadOptions.BuildAutoChargeOption()
    local gear = NQOL.Features.Gear

    return {
        panel = AUTO_CHARGE_PANEL_ID,
        system = AUTO_CHARGE_PANEL_ID,
        settingId = 1,
        controlType = OPTIONS_CHECKBOX,
        text = gear.GetAutoChargeLabel(),
        gamepadTextOverride = gear.GetAutoChargeLabel(),
        tooltipText = gear.GetAutoChargeTooltip(),
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, gear.GetAutoChargeTooltip())
        end,
        onInitializeFunction = GamepadOptions.RunOptionInitialize,
        GetSettingOverride = function()
            return gear.GetAutoCharge()
        end,
        SetSettingOverride = function(_, value)
            gear.SetAutoCharge(value)
        end,
    }
end

function GamepadOptions.BuildChargeThresholdOption()
    local gear = NQOL.Features.Gear

    return GamepadOptions.BuildValueStepSliderOption(
        AUTO_CHARGE_PANEL_ID,
        3,
        gear.GetChargeThresholdLabel(),
        gear.GetChargeThresholdTooltip(),
        gear.GetChargeThresholdMin(),
        gear.GetChargeThresholdMax(),
        "%.0f%%",
        gear.GetChargeThreshold,
        gear.SetChargeThreshold,
        1,
        nil,
        gear.GetChargeThresholdDefault
    )
end

function GamepadOptions.BuildLogChargeOption()
    local gear = NQOL.Features.Gear

    return {
        panel = AUTO_CHARGE_PANEL_ID,
        system = AUTO_CHARGE_PANEL_ID,
        settingId = 2,
        controlType = OPTIONS_CHECKBOX,
        text = gear.GetLogChargeLabel(),
        gamepadTextOverride = gear.GetLogChargeLabel(),
        tooltipText = gear.GetLogChargeTooltip(),
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, gear.GetLogChargeTooltip())
        end,
        onInitializeFunction = GamepadOptions.RunOptionInitialize,
        GetSettingOverride = function()
            return gear.GetLogCharge()
        end,
        SetSettingOverride = function(_, value)
            gear.SetLogCharge(value)
        end,
    }
end

function GamepadOptions.BuildAutoRepairOption()
    local gear = NQOL.Features.Gear

    return {
        panel = AUTO_REPAIR_PANEL_ID,
        system = AUTO_REPAIR_PANEL_ID,
        settingId = 1,
        controlType = OPTIONS_CHECKBOX,
        text = gear.GetAutoRepairLabel(),
        gamepadTextOverride = gear.GetAutoRepairLabel(),
        tooltipText = gear.GetAutoRepairTooltip(),
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, gear.GetAutoRepairTooltip())
        end,
        onInitializeFunction = GamepadOptions.RunOptionInitialize,
        GetSettingOverride = function()
            return gear.GetAutoRepair()
        end,
        SetSettingOverride = function(_, value)
            gear.SetAutoRepair(value)
        end,
    }
end

function GamepadOptions.BuildRepairThresholdOption()
    local gear = NQOL.Features.Gear

    return GamepadOptions.BuildValueStepSliderOption(
        AUTO_REPAIR_PANEL_ID,
        3,
        gear.GetRepairThresholdLabel(),
        gear.GetRepairThresholdTooltip(),
        gear.GetRepairThresholdMin(),
        gear.GetRepairThresholdMax(),
        "%.0f%%",
        gear.GetRepairThreshold,
        gear.SetRepairThreshold,
        1,
        nil,
        gear.GetRepairThresholdDefault
    )
end

function GamepadOptions.BuildRepairAllInMerchantsOption()
    local gear = NQOL.Features.Gear

    return GamepadOptions.BuildCheckboxOption(
        AUTO_REPAIR_PANEL_ID,
        4,
        gear.GetRepairAllInMerchantsLabel(),
        gear.GetRepairAllInMerchantsTooltip(),
        gear.GetRepairAllInMerchants,
        gear.SetRepairAllInMerchants,
        nil,
        false
    )
end

function GamepadOptions.BuildLogRepairOption()
    local gear = NQOL.Features.Gear

    return {
        panel = AUTO_REPAIR_PANEL_ID,
        system = AUTO_REPAIR_PANEL_ID,
        settingId = 2,
        controlType = OPTIONS_CHECKBOX,
        text = gear.GetLogRepairLabel(),
        gamepadTextOverride = gear.GetLogRepairLabel(),
        tooltipText = gear.GetLogRepairTooltip(),
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, gear.GetLogRepairTooltip())
        end,
        onInitializeFunction = GamepadOptions.RunOptionInitialize,
        GetSettingOverride = function()
            return gear.GetLogRepair()
        end,
        SetSettingOverride = function(_, value)
            gear.SetLogRepair(value)
        end,
    }
end

function GamepadOptions.BuildAutoBoundOption()
    local gear = NQOL.Features.Gear

    return {
        panel = AUTO_BOUND_PANEL_ID,
        system = AUTO_BOUND_PANEL_ID,
        settingId = 1,
        controlType = OPTIONS_CHECKBOX,
        text = gear.GetAutoBoundLabel(),
        gamepadTextOverride = gear.GetAutoBoundLabel(),
        tooltipText = gear.GetAutoBoundTooltip(),
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, gear.GetAutoBoundTooltip())
        end,
        onInitializeFunction = GamepadOptions.RunOptionInitialize,
        GetSettingOverride = function()
            return gear.GetAutoBound()
        end,
        SetSettingOverride = function(_, value)
            gear.SetAutoBound(value)
        end,
    }
end

function GamepadOptions.BuildLogBindOption()
    local gear = NQOL.Features.Gear

    return {
        panel = AUTO_BOUND_PANEL_ID,
        system = AUTO_BOUND_PANEL_ID,
        settingId = 2,
        controlType = OPTIONS_CHECKBOX,
        text = gear.GetLogBindLabel(),
        gamepadTextOverride = gear.GetLogBindLabel(),
        tooltipText = gear.GetLogBindTooltip(),
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, gear.GetLogBindTooltip())
        end,
        onInitializeFunction = GamepadOptions.RunOptionInitialize,
        GetSettingOverride = function()
            return gear.GetLogBind()
        end,
        SetSettingOverride = function(_, value)
            gear.SetLogBind(value)
        end,
    }
end

function GamepadOptions.BuildAutoFoodOption()
    local provisioning = NQOL.Features.Provisioning

    return {
        panel = PROVISIONING_PANEL_ID,
        system = PROVISIONING_PANEL_ID,
        settingId = 1,
        controlType = OPTIONS_CHECKBOX,
        text = provisioning.GetAutoFoodLabel(),
        gamepadTextOverride = provisioning.GetAutoFoodLabel(),
        tooltipText = provisioning.GetAutoFoodTooltip(),
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, provisioning.GetAutoFoodTooltip())
        end,
        onInitializeFunction = GamepadOptions.RunOptionInitialize,
        GetSettingOverride = function()
            return provisioning.GetAutoFood()
        end,
        SetSettingOverride = function(_, value)
            provisioning.SetAutoFood(value)
        end,
    }
end

function GamepadOptions.BuildAutoFoodRefreshThresholdOption()
    local provisioning = NQOL.Features.Provisioning

    return GamepadOptions.BuildValueStepSliderOption(
        PROVISIONING_PANEL_ID,
        5,
        provisioning.GetAutoFoodRefreshThresholdLabel(),
        provisioning.GetAutoFoodRefreshThresholdTooltip(),
        provisioning.GetAutoFoodRefreshThresholdMinutesMin(),
        provisioning.GetAutoFoodRefreshThresholdMinutesMax(),
        NQOL.L("common.minutes_format"),
        provisioning.GetAutoFoodRefreshThresholdMinutes,
        provisioning.SetAutoFoodRefreshThresholdMinutes,
        5,
        nil,
        provisioning.GetAutoFoodRefreshThresholdMinutesDefault
    )
end

function GamepadOptions.BuildCheckStockOption()
    local provisioning = NQOL.Features.Provisioning

    return {
        panel = PROVISIONING_PANEL_ID,
        system = PROVISIONING_PANEL_ID,
        settingId = 2,
        controlType = OPTIONS_CHECKBOX,
        text = provisioning.GetCheckStockLabel(),
        gamepadTextOverride = provisioning.GetCheckStockLabel(),
        tooltipText = provisioning.GetCheckStockTooltip(),
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, provisioning.GetCheckStockTooltip())
        end,
        onInitializeFunction = GamepadOptions.RunOptionInitialize,
        GetSettingOverride = function()
            return provisioning.GetCheckStock()
        end,
        SetSettingOverride = function(_, value)
            provisioning.SetCheckStock(value)
        end,
    }
end

function GamepadOptions.BuildLogFoodOption()
    local provisioning = NQOL.Features.Provisioning

    return {
        panel = PROVISIONING_PANEL_ID,
        system = PROVISIONING_PANEL_ID,
        settingId = 3,
        controlType = OPTIONS_CHECKBOX,
        text = provisioning.GetLogFoodLabel(),
        gamepadTextOverride = provisioning.GetLogFoodLabel(),
        tooltipText = provisioning.GetLogFoodTooltip(),
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, provisioning.GetLogFoodTooltip())
        end,
        onInitializeFunction = GamepadOptions.RunOptionInitialize,
        GetSettingOverride = function()
            return provisioning.GetLogFood()
        end,
        SetSettingOverride = function(_, value)
            provisioning.SetLogFood(value)
        end,
    }
end

function GamepadOptions.BuildAutoFoodSavedFoodLabel()
    local provisioning = NQOL.Features.Provisioning

    return {
        panel = PROVISIONING_PANEL_ID,
        system = PROVISIONING_PANEL_ID,
        settingId = 4,
        controlType = OPTIONS_INVOKE_CALLBACK,
        text = provisioning.GetAutoFoodSavedFoodLabel,
        gamepadTextOverride = provisioning.GetAutoFoodSavedFoodLabel,
        tooltipText = provisioning.GetAutoFoodSavedFoodTooltip(),
        onInitializeFunction = GamepadOptions.InitializeDecorativeEntry,
        gamepadCustomTooltipFunction = function(tooltipControl)
            GAMEPAD_TOOLTIPS:LayoutTextBlockTooltip(tooltipControl, provisioning.GetAutoFoodSavedFoodTooltip())
        end,
        callback = GamepadOptions.ShowClearSavedFoodDialog,
    }
end
