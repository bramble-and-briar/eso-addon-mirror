-- ARC_ZoneExplorer English Localization
-- Formatted according to ESOUI Best Practices

local strings = {
    -- Settings & Panel
    SI_ARC_ZE_TITLE                 = "ARC Zone Explorer",
    SI_ARC_ZE_DESC                  = "Displays an elegant zone exploration HUD and arrival summary upon entering a new zone or city. Shows Zone Guide completion, stickerbook sets, and daily reminders.",
    SI_ARC_ZE_OPT_LANGUAGE          = "Language / Dil",
    SI_ARC_ZE_OPT_LANGUAGE_TIP      = "Select the addon interface language (Default: English). Requires /reloadui.",

    -- General Settings
    SI_ARC_ZE_HDR_GENERAL           = "General & Display Settings",
    SI_ARC_ZE_OPT_ENABLE            = "Enable ARC Zone Explorer",
    SI_ARC_ZE_OPT_ENABLE_TIP        = "Enables or disables the zone arrival HUD overlay.",
    SI_ARC_ZE_OPT_AUTO_SHOW         = "Auto-Show on Zone Arrival",
    SI_ARC_ZE_OPT_AUTO_SHOW_TIP     = "Automatically displays the dashboard when exiting a loading screen into a new zone.",
    SI_ARC_ZE_OPT_DURATION          = "Display Duration (Seconds)",
    SI_ARC_ZE_OPT_DURATION_TIP      = "How many seconds the HUD remains visible before fading out (0 = stay open until closed).",
    SI_ARC_ZE_OPT_OPACITY           = "Window Background Opacity",
    SI_ARC_ZE_OPT_OPACITY_TIP       = "Adjust the transparency of the dashboard background.",
    SI_ARC_ZE_OPT_SCALE             = "UI Scale",
    SI_ARC_ZE_OPT_SCALE_TIP         = "Adjust the overall scale and size of the Zone Explorer HUD (50% - 130%).",
    SI_ARC_ZE_OPT_COMPACT           = "Compact Mini Mode",
    SI_ARC_ZE_OPT_COMPACT_TIP       = "Use a narrower, streamlined single-column layout that takes less screen space.",
    SI_ARC_ZE_OPT_SHOW_SETS         = "Show Item Sets (Stickerbook)",
    SI_ARC_ZE_OPT_SHOW_SETS_TIP     = "Display collection progress for overland item sets found in this zone.",
    SI_ARC_ZE_OPT_HIDE_COMPLETED_SETS = "Hide 100% Completed Sets",
    SI_ARC_ZE_OPT_HIDE_COMPLETED_SETS_TIP = "Do not display item sets that have all pieces already unlocked in your stickerbook.",
    SI_ARC_ZE_OPT_SHOW_DAILIES      = "Show Daily Statuses",
    SI_ARC_ZE_OPT_SHOW_DAILIES_TIP  = "Display Riding Training and Daily Writ status.",
    SI_ARC_ZE_OPT_TRACK_RIDING      = "Show Riding Training",
    SI_ARC_ZE_OPT_TRACK_RIDING_TIP  = "Display Riding Training timer / ready alert.",
    SI_ARC_ZE_OPT_TRACK_WRITS       = "Show Daily Crafting Writs",
    SI_ARC_ZE_OPT_TRACK_WRITS_TIP   = "Display Daily Crafting Writ quest progress.",

    -- Granular Activity Filters
    SI_ARC_ZE_OPT_HIDE_COMPLETED    = "Hide Completed Activities",
    SI_ARC_ZE_OPT_HIDE_COMPLETED_TIP = "Only display activities and objectives that are NOT yet 100% completed in the current zone.",
    SI_ARC_ZE_SUBMENU_ACTIVITIES    = "Activity Filters (Zone Guide)",
    SI_ARC_ZE_SUBMENU_ACTIVITIES_DESC = "Choose which specific exploration objectives to display on the HUD.",
    SI_ARC_ZE_OPT_TRACK_SKYSHARDS   = "Track Skyshards",
    SI_ARC_ZE_OPT_TRACK_WAYSHRINES  = "Track Wayshrines",
    SI_ARC_ZE_OPT_TRACK_DELVES      = "Track Delves",
    SI_ARC_ZE_OPT_TRACK_DUNGEONS    = "Track Public Dungeons",
    SI_ARC_ZE_OPT_TRACK_BOSSES      = "Track World Bosses",
    SI_ARC_ZE_OPT_TRACK_EVENTS      = "Track World Events (Dolmens)",
    SI_ARC_ZE_OPT_TRACK_LOCALES     = "Track Striking Locales",
    SI_ARC_ZE_OPT_TRACK_STORY       = "Track Zone Story Quests",

    -- HUD UI Labels
    SI_ARC_ZE_HUD_WELCOME           = "WELCOME TO",
    SI_ARC_ZE_HUD_EXPLORATION       = "Zone Exploration",
    SI_ARC_ZE_HUD_SETS              = "Zone Item Sets",
    SI_ARC_ZE_HUD_DAILIES           = "Daily Statuses",

    -- Activities
    SI_ARC_ZE_ACT_SKYSHARDS         = "Skyshards",
    SI_ARC_ZE_ACT_WAYSHRINES        = "Wayshrines",
    SI_ARC_ZE_ACT_DELVES            = "Delves",
    SI_ARC_ZE_ACT_DUNGEONS          = "Public Dungeons",
    SI_ARC_ZE_ACT_BOSSES            = "World Bosses",
    SI_ARC_ZE_ACT_EVENTS            = "World Events",
    SI_ARC_ZE_ACT_LOCALES           = "Striking Locales",
    SI_ARC_ZE_ACT_STORY             = "Zone Story",

    -- Dailies
    SI_ARC_ZE_RIDING_READY          = "Riding Training: Ready!",
    SI_ARC_ZE_RIDING_COOLDOWN       = "Riding Training: In %s",
    SI_ARC_ZE_RIDING_MAX            = "Riding Training: Maxed Out (60/60/60)",
    SI_ARC_ZE_WRITS_DONE            = "Daily Crafting Writs: All Done",
    SI_ARC_ZE_WRITS_PENDING         = "Daily Crafting Writs: Pending (%d active)",

    -- Support & Donation
    SI_ARC_ZE_HEADER_DONATE         = "Support the Author (@arcsinan)",
    SI_ARC_ZE_DONATE_DESC           = "ARC Zone Explorer is free and open-source. If you enjoy exploring Tamriel with this addon, you can support the developer by sending in-game gold or a quick thank-you note directly to @arcsinan (PC/EU)!",
    SI_ARC_ZE_BTN_DONATE_5K         = "Send 5,000 Gold",
    SI_ARC_ZE_BTN_DONATE_5K_TT      = "Opens in-game mail to @arcsinan with 5,000 Gold pre-attached.",
    SI_ARC_ZE_BTN_DONATE_25K        = "Send 25,000 Gold",
    SI_ARC_ZE_BTN_DONATE_25K_TT     = "Opens in-game mail to @arcsinan with 25,000 Gold pre-attached.",
    SI_ARC_ZE_BTN_DONATE_100K       = "Send 100,000 Gold",
    SI_ARC_ZE_BTN_DONATE_100K_TT    = "Opens in-game mail to @arcsinan with 100,000 Gold pre-attached. Thank you so much!",
    SI_ARC_ZE_BTN_DONATE_CUSTOM     = "Custom Amount / Feedback Note",
    SI_ARC_ZE_BTN_DONATE_CUSTOM_TT  = "Opens in-game mail to @arcsinan where you can attach any gold or type feedback.",
    SI_ARC_ZE_MAIL_BODY             = "Thank you for creating ARC Zone Explorer!",
    SI_ARC_ZE_CHAT_SERVER_WARN      = "|cFFD700[ARC Zone Explorer]|r Note: @arcsinan plays primarily on the PC/EU server (current server: %s).",
}

for stringId, stringValue in pairs(strings) do
    ZO_CreateStringId(stringId, stringValue)
    SafeAddString(_G[stringId], stringValue, 1)
end
