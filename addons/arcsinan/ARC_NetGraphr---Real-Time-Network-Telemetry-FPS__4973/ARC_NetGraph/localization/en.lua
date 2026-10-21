-- ARC_NetGraph English Localization
-- Formatted according to ESOUI Best Practices

local strings = {
    -- Settings & Panel
    SI_ARC_NG_TITLE                 = "ARC NetGraph",
    SI_ARC_NG_DESC                  = "Real-time network telemetry HUD displaying Ping, Jitter, Min/Max latency variance, and FPS with custom layouts and color coding.",
    SI_ARC_NG_OPT_LANGUAGE          = "Language / Dil",
    SI_ARC_NG_OPT_LANGUAGE_TIP      = "Select the addon interface language (Default: English). Requires /reloadui.",

    -- General Settings
    SI_ARC_NG_HDR_GENERAL           = "General & Performance Settings",
    SI_ARC_NG_OPT_ENABLE            = "Enable ARC NetGraph",
    SI_ARC_NG_OPT_ENABLE_TIP        = "Show or hide the real-time network telemetry overlay.",
    SI_ARC_NG_OPT_UPDATE_INTERVAL   = "Update Rate (ms)",
    SI_ARC_NG_OPT_UPDATE_INTERVAL_TIP = "How frequently the telemetry samples latency and refreshes the display (Default: 500ms).",
    SI_ARC_NG_OPT_LAYOUT_MODE       = "Display Layout Style",
    SI_ARC_NG_OPT_LAYOUT_MODE_TIP   = "Choose between a sleek single-line telemetry bar, a detailed multi-line card, or a minimal badge.",
    SI_ARC_NG_LAYOUT_COMPACT        = "Compact Bar (Single Line)",
    SI_ARC_NG_LAYOUT_DETAILED       = "Detailed Card (Grid)",
    SI_ARC_NG_LAYOUT_MINIMAL        = "Minimalist (Badge)",

    -- Metrics Toggles
    SI_ARC_NG_HDR_METRICS           = "Telemetry Metrics",
    SI_ARC_NG_OPT_SHOW_PING         = "Show Ping (Latency)",
    SI_ARC_NG_OPT_SHOW_PING_TIP     = "Displays current round-trip latency to the megaserver in milliseconds.",
    SI_ARC_NG_OPT_SHOW_JITTER       = "Show Jitter (Variance)",
    SI_ARC_NG_OPT_SHOW_JITTER_TIP   = "Measures packet arrival jitter and latency instability (RFC 3550 variance standard).",
    SI_ARC_NG_OPT_SHOW_FPS          = "Show Framerate (FPS)",
    SI_ARC_NG_OPT_SHOW_FPS_TIP      = "Displays current rendering frames per second.",
    SI_ARC_NG_OPT_SHOW_MINMAX       = "Show Min / Max Ping Spikes",
    SI_ARC_NG_OPT_SHOW_MINMAX_TIP   = "Displays the lowest and highest ping recorded over the recent sampling window.",
    SI_ARC_NG_OPT_SHOW_SERVER       = "Show Server Name",
    SI_ARC_NG_OPT_SHOW_SERVER_TIP   = "Displays current connected megaserver (EU / NA / PTS).",

    -- Visual Styling
    SI_ARC_NG_HDR_VISUAL            = "Visual Appearance & Positioning",
    SI_ARC_NG_OPT_LOCK              = "Lock Window Position",
    SI_ARC_NG_OPT_LOCK_TIP          = "Locks the overlay in place and makes it click-through, preventing accidental mouse dragging.",
    SI_ARC_NG_OPT_SCALE             = "UI Scale",
    SI_ARC_NG_OPT_SCALE_TIP         = "Adjust the size of the NetGraph overlay (50% - 150%).",
    SI_ARC_NG_OPT_OPACITY           = "Background Opacity",
    SI_ARC_NG_OPT_OPACITY_TIP       = "Adjust the transparency of the background (0% = completely borderless/transparent).",
    SI_ARC_NG_OPT_COLOR_CODING      = "Dynamic Health Color Coding",
    SI_ARC_NG_OPT_COLOR_CODING_TIP  = "Dynamically colorizes Ping and Jitter based on network quality (Green = Great, Yellow = Moderate, Red = High/Spike).",

    -- In-Game Labels
    SI_ARC_NG_LBL_FPS               = "FPS",
    SI_ARC_NG_LBL_PING              = "PING",
    SI_ARC_NG_LBL_JITTER            = "JITTER",
    SI_ARC_NG_LBL_SPIKES            = "SPIKE",
    SI_ARC_NG_LBL_SERVER            = "SERVER",

    -- Donation Section
    SI_ARC_NG_HEADER_DONATE         = "Support the Developer (@arcsinan)",
    SI_ARC_NG_DONATE_DESC           = "If you enjoy ARC NetGraph, in-game gold donations are warmly appreciated! Clicking a button opens the in-game mail compose window addressed to @arcsinan.",
    SI_ARC_NG_BTN_DONATE_5K         = "Send 5,000 Gold",
    SI_ARC_NG_BTN_DONATE_5K_TT      = "Sends 5,000 Gold to @arcsinan.",
    SI_ARC_NG_BTN_DONATE_25K        = "Send 25,000 Gold",
    SI_ARC_NG_BTN_DONATE_25K_TT     = "Sends 25,000 Gold to @arcsinan.",
    SI_ARC_NG_BTN_DONATE_100K       = "Send 100,000 Gold",
    SI_ARC_NG_BTN_DONATE_100K_TT    = "Sends 100,000 Gold to @arcsinan.",
    SI_ARC_NG_BTN_DONATE_CUSTOM     = "Send Custom Gold / Feedback",
    SI_ARC_NG_BTN_DONATE_CUSTOM_TT  = "Opens an in-game mail to @arcsinan for custom donations or feedback.",
    SI_ARC_NG_CHAT_SERVER_WARN      = "|cFF9900[ARC NetGraph]|r Notice: You are on server '%s'. In-game mail will only be delivered if you play on the EU Megaserver.",
    SI_ARC_NG_MAIL_BODY             = "Thank you for creating ARC NetGraph! Here is a small donation to support your work.",
}

for stringId, stringValue in pairs(strings) do
    ZO_CreateStringId(stringId, stringValue)
    SafeAddString(_G[stringId], stringValue, 1)
end
