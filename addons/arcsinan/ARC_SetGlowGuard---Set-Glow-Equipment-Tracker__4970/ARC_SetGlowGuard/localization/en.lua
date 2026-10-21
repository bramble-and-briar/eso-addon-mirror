-- localization/en.lua
-- English Default Strings for ARC_SetGlowGuard
-- Author: @arcsinan

local strings = {
    SI_ARC_SGG_PANEL_TITLE          = "ARC_SetGlowGuard - Set Glow & Equipment Tracker",
    SI_ARC_SGG_HDR_GENERAL          = "General Settings",

    SI_ARC_SGG_OPT_LANGUAGE         = "Language / Dil",
    SI_ARC_SGG_OPT_LANGUAGE_TT      = "Select addon display and notification language. Default is English.",

    SI_ARC_SGG_OPT_ENABLE           = "Enable ARC_SetGlowGuard",
    SI_ARC_SGG_OPT_ENABLE_TT        = "Toggles glowing set highlights on equipment and inventory.",

    SI_ARC_SGG_OPT_AUTO_CHAR        = "Show Character Sheet with Inventory ('I')",
    SI_ARC_SGG_OPT_AUTO_CHAR_TT     = "When pressing 'I' to open your bag, automatically attaches the Character equipment panel to the left side of your screen. All worn sets and matching backpack items glow in matching colors simultaneously!",

    SI_ARC_SGG_OPT_HIGHLIGHT_EQUIP  = "Highlight Equipment Slots",
    SI_ARC_SGG_OPT_HIGHLIGHT_EQUIP_TT = "Equipped items belonging to the same set will glow with identical colors on your Character sheet.",

    SI_ARC_SGG_OPT_HIGHLIGHT_BAG    = "Highlight Backpack Items",
    SI_ARC_SGG_OPT_HIGHLIGHT_BAG_TT = "Items in your bag that match your currently equipped sets glow with the exact same set color, making accidentally unequipped items instantly noticeable.",

    SI_ARC_SGG_OPT_ROW_BAR          = "Show Left Accent Bar in Inventory Rows",
    SI_ARC_SGG_OPT_ROW_BAR_TT       = "Draws a sleek colored vertical accent stripe on the left border of inventory rows matching equipped sets.",

    SI_ARC_SGG_OPT_INCOMPLETE       = "Show Incomplete Set Alert (e.g. 4/5)",
    SI_ARC_SGG_OPT_INCOMPLETE_TT    = "Displays a clear piece count indicator on slots when an equipped set is missing pieces (e.g. 4/5 or 1/2) so you never miss an unequipped item.",

    SI_ARC_SGG_OPT_GLOW_INTENSITY   = "Glow Intensity",
    SI_ARC_SGG_OPT_GLOW_INTENSITY_TT = "Adjust how bright and vivid the glow highlights appear.",

    SI_ARC_SGG_OPT_GLOW_STYLE       = "Glow Style",
    SI_ARC_SGG_OPT_GLOW_STYLE_TT    = "Select the visual texture style used for glowing borders.",

    SI_ARC_SGG_HDR_COLORS           = "Custom Set Colors",
    SI_ARC_SGG_DESC_COLORS          = "Customize the distinct glow color assigned to each equipped set, mythic items, and incomplete alerts:",

    SI_ARC_SGG_COLOR_SET_1          = "Set 1 Color (Primary)",
    SI_ARC_SGG_COLOR_SET_2          = "Set 2 Color (Secondary)",
    SI_ARC_SGG_COLOR_SET_3          = "Set 3 Color (Tertiary)",
    SI_ARC_SGG_COLOR_SET_4          = "Set 4 Color (Quaternary)",
    SI_ARC_SGG_COLOR_SET_5          = "Set 5 Color (Quinary)",
    SI_ARC_SGG_COLOR_SET_6          = "Set 6 Color (Senary)",
    SI_ARC_SGG_COLOR_MYTHIC         = "Mythic Item Glow Color",
    SI_ARC_SGG_COLOR_WARNING        = "Incomplete Set Alert Color",

    SI_ARC_SGG_BTN_RESET_COLORS     = "Reset Colors to Default",
    SI_ARC_SGG_BTN_RESET_COLORS_TT  = "Restores all set and indicator colors back to their default palette.",

    SI_ARC_SGG_HDR_DONATE           = "Support Developer (@arcsinan)",
    SI_ARC_SGG_DESC_DONATE          = "Enjoying ARC_SetGlowGuard? No more accidentally lost set pieces or broken 5-piece bonuses!\nIf you would like to support ongoing development, you can send an in-game gold donation directly to @arcsinan (PC/EU Megaserver only).",

    SI_ARC_SGG_BTN_DONATE_5K        = "Send 5,000 Gold to @arcsinan",
    SI_ARC_SGG_BTN_DONATE_5K_TT     = "Opens in-game mail addressed to @arcsinan with 5,000 gold pre-attached.",

    SI_ARC_SGG_BTN_DONATE_25K       = "Send 25,000 Gold to @arcsinan",
    SI_ARC_SGG_BTN_DONATE_25K_TT    = "Opens in-game mail addressed to @arcsinan with 25,000 gold pre-attached.",

    SI_ARC_SGG_BTN_DONATE_100K      = "Send 100,000 Gold to @arcsinan",
    SI_ARC_SGG_BTN_DONATE_100K_TT   = "Opens in-game mail addressed to @arcsinan with 100,000 gold pre-attached.",

    SI_ARC_SGG_BTN_DONATE_CUSTOM    = "Open Mail to @arcsinan (Custom Amount)",
    SI_ARC_SGG_BTN_DONATE_CUSTOM_TT = "Opens in-game mail addressed to @arcsinan so you can enter any gold amount you wish.",

    SI_ARC_SGG_CHAT_REFRESHED       = "[ARC_SetGlowGuard] Refreshed! Detected active sets: %d",
    SI_ARC_SGG_CHAT_COMPLETE        = "(Complete: %d/%d)",
    SI_ARC_SGG_CHAT_INCOMPLETE      = "(Incomplete: %d/%d)",
    SI_ARC_SGG_CHAT_SERVER_WARN     = "[ARC_SetGlowGuard] Notice: @arcsinan is exclusively on PC/EU Megaserver! (Current server: %s). Mails sent from other servers cannot be received.",
    SI_ARC_SGG_MAIL_BODY            = "Thank you @arcsinan for creating ARC_SetGlowGuard! Here is some gold to support your ESO addon development.",
}

for stringId, stringValue in pairs(strings) do
    ZO_CreateStringId(stringId, stringValue)
    SafeAddString(_G[stringId], stringValue, 1)
end
