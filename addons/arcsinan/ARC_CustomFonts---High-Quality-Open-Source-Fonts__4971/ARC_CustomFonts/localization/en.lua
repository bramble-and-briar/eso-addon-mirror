-- ARC_CustomFonts English Localization
-- Formatted according to ESOUI Best Practices

local strings = {
    -- Settings Panel
    SI_ARC_CF_TITLE                 = "ARC Custom Fonts",
    SI_ARC_CF_DESC                  = "High-quality, royalty-free open-source fonts for ESO. Automatically registered with LibMediaProvider (LMP) and customizable for in-game UI.",
    SI_ARC_CF_OPT_LANGUAGE          = "Language / Dil",
    SI_ARC_CF_OPT_LANGUAGE_TIP      = "Select the addon interface language (Default: English). Requires /reloadui.",
    SI_ARC_CF_HEADER_LMP            = "LibMediaProvider (LMP) Status",
    SI_ARC_CF_LMP_REGISTERED        = "All 11 custom fonts are successfully registered with LibMediaProvider and available in any supported addon (Bandit UI, pChat, AUI, etc.).",
    SI_ARC_CF_LMP_NOT_FOUND         = "LibMediaProvider-1.0 was not found. Install it via Minion if you wish to use these fonts in other addons.",

    -- Global Font Overrides
    SI_ARC_CF_HEADER_OVERRIDES      = "Global In-Game Font Overrides",
    SI_ARC_CF_OVERRIDES_DESC        = "Optionally replace default ESO interface fonts with your chosen custom fonts. Requires /reloadui to take full effect.",

    SI_ARC_CF_ENABLE_OVERRIDES      = "Enable Global Overrides",
    SI_ARC_CF_ENABLE_OVERRIDES_TIP  = "When enabled, the selected fonts below will override the default game fonts.",

    SI_ARC_CF_CHAT_FONT             = "Chat Font",
    SI_ARC_CF_CHAT_FONT_TIP         = "Select the font used in chat channels and text input.",

    SI_ARC_CF_UI_FONT               = "General UI Font",
    SI_ARC_CF_UI_FONT_TIP           = "Select the font used for general menus, buttons, labels, and inventory list.",

    SI_ARC_CF_HEADER_FONT           = "Headers & Titles Font",
    SI_ARC_CF_HEADER_FONT_TIP       = "Select the font used for window titles, section headers, and character names.",

    SI_ARC_CF_BOOK_FONT             = "Books & Lore Font",
    SI_ARC_CF_BOOK_FONT_TIP         = "Select the font used when reading books, notes, and scrolls in Tamriel.",

    SI_ARC_CF_COMBAT_FONT           = "Combat Numbers Font",
    SI_ARC_CF_COMBAT_FONT_TIP       = "Select the font used for floating damage, healing numbers, and alerts.",

    SI_ARC_CF_RELOAD_BTN            = "Apply & Reload UI",
    SI_ARC_CF_RELOAD_BTN_TIP        = "Reloads the user interface to apply all font changes.",

    -- Font Options
    SI_ARC_CF_FONT_DEFAULT          = "Default (Game Default)",

    -- Support & Donation
    SI_ARC_CF_HEADER_DONATE         = "Support the Author (@arcsinan)",
    SI_ARC_CF_DONATE_DESC           = "ARC Custom Fonts is completely free and open-source. If you enjoy having these fonts in ESO, you can support the developer by sending in-game gold or a quick thank-you note directly to @arcsinan (PC/EU)!",
    SI_ARC_CF_BTN_DONATE_5K         = "Send 5,000 Gold",
    SI_ARC_CF_BTN_DONATE_5K_TT      = "Opens in-game mail to @arcsinan with 5,000 Gold pre-attached.",
    SI_ARC_CF_BTN_DONATE_25K        = "Send 25,000 Gold",
    SI_ARC_CF_BTN_DONATE_25K_TT     = "Opens in-game mail to @arcsinan with 25,000 Gold pre-attached.",
    SI_ARC_CF_BTN_DONATE_100K       = "Send 100,000 Gold",
    SI_ARC_CF_BTN_DONATE_100K_TT    = "Opens in-game mail to @arcsinan with 100,000 Gold pre-attached. Thank you so much!",
    SI_ARC_CF_BTN_DONATE_CUSTOM     = "Custom Amount / Feedback Note",
    SI_ARC_CF_BTN_DONATE_CUSTOM_TT  = "Opens in-game mail to @arcsinan where you can attach any gold or type feedback.",
    SI_ARC_CF_MAIL_BODY             = "Thank you for creating ARC Custom Fonts!",
    SI_ARC_CF_CHAT_SERVER_WARN      = "|cFFD700[ARC Custom Fonts]|r Note: @arcsinan plays primarily on the PC/EU server (current server: %s).",
}

for stringId, stringValue in pairs(strings) do
    ZO_CreateStringId(stringId, stringValue)
    SafeAddString(_G[stringId], stringValue, 1)
end
