TamrielCalendar = TamrielCalendar or {}
local TC = TamrielCalendar

TC.L = {
    days = {"Sundas", "Morndas", "Tirdas", "Middas", "Turdas", "Fredas", "Loredas"},
    shortDays = {"Su", "Mo", "Tu", "We", "Th", "Fr", "Lo"},
    months = {"Morning Star", "Sun's Dawn", "First Seed", "Rain's Hand", "Second Seed", "Midyear", "Sun's Height", "Last Seed", "Hearthfire", "Frostfall", "Sun's Dusk", "Evening Star"},
    realMonths = {"January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"},
    signs = {"Ritual", "Lover", "Lord", "Mage", "Shadow", "Steed", "Apprentice", "Warrior", "Lady", "Tower", "Atronach", "Thief", "Serpent"},
    moonPhases = {"New Moon", "Waxing Crescent", "First Quarter", "Waxing Gibbous", "Full Moon", "Waning Gibbous", "Last Quarter", "Waning Crescent"},
    yearSuffix = "year of 2nd Era",
    monthPrefix = "Month of",
    signPrefix = "Sign:",
    stripFormat = "%s, %d %s %d | %s | %02d:%02d",
    titleHoliday = "Holiday (Lore):",
    btnPrev = "Prev",
    btnNext = "Next",
    hNames = {
        nl = "New Life Festival",
        hd = "Heart's Day (Sanguine)",
        aj = "ESO Anniversary",
        jd = "Jester's Day",
        zz = "Zenithar's Day",
        my = "Midyear (Pelinal)",
        wf = "Witches Festival",
        ud = "Warrior's Day",
        ol = "Old Life"
    }
}

ZO_CreateStringId("SI_BINDING_NAME_TC_TOGGLE_UI", "Show/Hide Strip")
ZO_CreateStringId("SI_BINDING_NAME_TC_TOGGLE_WINDOW", "Open Big Calendar")

-- Settings Panel Strings
ZO_CreateStringId("SI_TC_SECTION_APPEARANCE", "Strip Appearance")
ZO_CreateStringId("SI_TC_AUTO_WIDTH_NAME", "Automatic Width")
ZO_CreateStringId("SI_TC_AUTO_WIDTH_TIP", "The strip automatically adjusts its width to fit the text length.")
ZO_CreateStringId("SI_TC_STRIP_WIDTH_NAME", "Fixed Width (px)")
ZO_CreateStringId("SI_TC_STRIP_WIDTH_TIP", "Only works when automatic width is disabled.")
ZO_CreateStringId("SI_TC_STRIP_HEIGHT_NAME", "Strip Height (px)")
ZO_CreateStringId("SI_TC_STRIP_ALPHA_NAME", "Background Opacity (%)")
ZO_CreateStringId("SI_TC_STRIP_LOCK_NAME", "Lock Strip")
ZO_CreateStringId("SI_TC_STRIP_LOCK_TIP", "Locks the strip to prevent accidental dragging.")

ZO_CreateStringId("SI_TC_SECTION_FONT", "Font & Text Settings")
ZO_CreateStringId("SI_TC_TEXT_COLOR_NAME", "Text Color")
ZO_CreateStringId("SI_TC_TEXT_COLOR_TIP", "Choose the text color on the strip.")
ZO_CreateStringId("SI_TC_FONT_FAMILY_NAME", "Font Family")
ZO_CreateStringId("SI_TC_FONT_SIZE_NAME", "Font Size (px)")
ZO_CreateStringId("SI_TC_FONT_STYLE_NAME", "Shadow / Outline Style")

-- Font Dropdown Choices
ZO_CreateStringId("SI_TC_FONT_CHOICE_BOLD", "System Bold (Univers Bold)")
ZO_CreateStringId("SI_TC_FONT_CHOICE_REGULAR", "System Regular (Univers Regular)")
ZO_CreateStringId("SI_TC_FONT_CHOICE_MEDIUM", "System Medium (Univers Medium)")
ZO_CreateStringId("SI_TC_FONT_CHOICE_GAME", "Game UI Font")
ZO_CreateStringId("SI_TC_FONT_CHOICE_ANTIQUE", "Book / Scrolls (Antique)")
ZO_CreateStringId("SI_TC_FONT_CHOICE_HANDWRITTEN", "Handwritten / Notes")
ZO_CreateStringId("SI_TC_FONT_CHOICE_STONE", "Stone Tablet / Headings")

-- Shadow Dropdown Choices
ZO_CreateStringId("SI_TC_STYLE_CHOICE_SOFT", "Soft Shadow (Recommended)")
ZO_CreateStringId("SI_TC_STYLE_CHOICE_HARD", "Hard Shadow")
ZO_CreateStringId("SI_TC_STYLE_CHOICE_OUTLINE", "Outline")
ZO_CreateStringId("SI_TC_STYLE_CHOICE_THIN", "Thin Shadow")
ZO_CreateStringId("SI_TC_STYLE_CHOICE_NONE", "No Shadow")

-- Elements Toggles
ZO_CreateStringId("SI_TC_SECTION_ELEMENTS", "Displayed Elements")
ZO_CreateStringId("SI_TC_SHOW_WDAY_NAME", "Day of the Week")
ZO_CreateStringId("SI_TC_SHOW_WDAY_TIP", "Show day of the week (Sundas, Morndas...)")
ZO_CreateStringId("SI_TC_SHOW_DATE_NAME", "Day and Month")
ZO_CreateStringId("SI_TC_SHOW_DATE_TIP", "Show day and month (14 Morning Star...)")
ZO_CreateStringId("SI_TC_SHOW_YEAR_NAME", "Year and Era")
ZO_CreateStringId("SI_TC_SHOW_YEAR_TIP", "Show year (582 year of 2nd Era)")
ZO_CreateStringId("SI_TC_SHOW_SIGN_NAME", "Constellation Sign")
ZO_CreateStringId("SI_TC_SHOW_SIGN_TIP", "Show current constellation (Sign: The Ritual...)")
ZO_CreateStringId("SI_TC_SHOW_TIME_NAME", "Tamriel Time")
ZO_CreateStringId("SI_TC_SHOW_TIME_TIP", "Show in-game time (hours and minutes)")