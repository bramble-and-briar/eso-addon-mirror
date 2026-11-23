TamrielCalendar = TamrielCalendar or {}
local TC = TamrielCalendar

local de = {
    days = {"Sandas", "Morndas", "Tirdas", "Middas", "Turdas", "Fredas", "Loredas"},
    shortDays = {"Sa", "Mo", "Ti", "Mi", "Tu", "Fr", "Lo"},
    months = {"Morgenstern", "Sonnendämmerung", "Erstsaat", "Regenhand", "Zweitsaat", "Mittjahr", "Sonnenerhöhung", "Letzte Saat", "Herzfeuer", "Eisfall", "Sonnenuntergang", "Abendstern"},
    realMonths = {"Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"},
    signs = {"Das Ritual", "Die Liebenden", "Der Fürst", "Der Magier", "Der Schatten", "Das Ross", "Der Lehrling", "Der Krieger", "Die Fürstin", "Der Turm", "Der Atronach", "Die Diebin", "Die Schlange"},
    moonPhases = {"Neumond", "Zunehmende Sichel", "Erstes Viertel", "Zunehmender Mond", "Vollmond", "Abnehmender Mond", "Letztes Viertel", "Abnehmende Sichel"},
    yearSuffix = "Jahr der 2. Ära",
    monthPrefix = "Monat",
    signPrefix = "Sternzeichen:",
    stripFormat = "%s, %d. %s %d | %s | %02d:%02d",
    titleHoliday = "Feiertag:",
    btnPrev = "Zurück",
    btnNext = "Weiter",
    hNames = {
        nl = "Neujahrsfest",
        hd = "Herztag",
        aj = "ESO-Jubiläum",
        jd = "Tag der Narren",
        zz = "Tag von Zenithar",
        my = "Mittjahr-Feier",
        wf = "Hexenfest",
        ud = "Kriegerfest"
    }
}

for k, v in pairs(de) do
    TC.L[k] = v
end

ZO_CreateStringId("SI_BINDING_NAME_TC_TOGGLE_UI", "Leiste ein-/ausblenden")
ZO_CreateStringId("SI_BINDING_NAME_TC_TOGGLE_WINDOW", "Großen Kalender öffnen")

-- Settings Panel Strings (DE)
ZO_CreateStringId("SI_TC_SECTION_APPEARANCE", "Aussehen der Leiste")
ZO_CreateStringId("SI_TC_AUTO_WIDTH_NAME", "Automatische Breite")
ZO_CreateStringId("SI_TC_AUTO_WIDTH_TIP", "Passt die Breite der Leiste automatisch an die Textlänge an.")
ZO_CreateStringId("SI_TC_STRIP_WIDTH_NAME", "Feste Breite (px)")
ZO_CreateStringId("SI_TC_STRIP_WIDTH_TIP", "Funktioniert nur, wenn die automatische Breite deaktiviert ist.")
ZO_CreateStringId("SI_TC_STRIP_HEIGHT_NAME", "Leistenhöhe (px)")
ZO_CreateStringId("SI_TC_STRIP_ALPHA_NAME", "Hintergrund-Deckkraft (%)")
ZO_CreateStringId("SI_TC_STRIP_LOCK_NAME", "Leiste sperren")
ZO_CreateStringId("SI_TC_STRIP_LOCK_TIP", "Sperrt die Leiste, um versehentliches Verschieben zu verhindern.")

ZO_CreateStringId("SI_TC_SECTION_FONT", "Schrift- & Texteinstellungen")
ZO_CreateStringId("SI_TC_TEXT_COLOR_NAME", "Textfarbe")
ZO_CreateStringId("SI_TC_TEXT_COLOR_TIP", "Wählt die Textfarbe auf der Leiste.")
ZO_CreateStringId("SI_TC_FONT_FAMILY_NAME", "Schriftart")
ZO_CreateStringId("SI_TC_FONT_SIZE_NAME", "Schriftgröße (px)")
ZO_CreateStringId("SI_TC_FONT_STYLE_NAME", "Schatten- / Umrandungsstil")

-- Font Dropdown Choices
ZO_CreateStringId("SI_TC_FONT_CHOICE_BOLD", "System Fett (Univers Bold)")
ZO_CreateStringId("SI_TC_FONT_CHOICE_REGULAR", "System Standard (Univers Regular)")
ZO_CreateStringId("SI_TC_FONT_CHOICE_MEDIUM", "System Mittel (Univers Medium)")
ZO_CreateStringId("SI_TC_FONT_CHOICE_GAME", "Spiel-UI-Schriftart")
ZO_CreateStringId("SI_TC_FONT_CHOICE_ANTIQUE", "Buch / Schriftrollen (Antik)")
ZO_CreateStringId("SI_TC_FONT_CHOICE_HANDWRITTEN", "Handschrift / Notizen")
ZO_CreateStringId("SI_TC_FONT_CHOICE_STONE", "Steintafel / Überschriften")

-- Shadow Dropdown Choices
ZO_CreateStringId("SI_TC_STYLE_CHOICE_SOFT", "Weicher Schatten (Empfohlen)")
ZO_CreateStringId("SI_TC_STYLE_CHOICE_HARD", "Harter Schatten")
ZO_CreateStringId("SI_TC_STYLE_CHOICE_OUTLINE", "Umrandung (Outline)")
ZO_CreateStringId("SI_TC_STYLE_CHOICE_THIN", "Dünner Schatten")
ZO_CreateStringId("SI_TC_STYLE_CHOICE_NONE", "Kein Schatten")

-- Elements Toggles
ZO_CreateStringId("SI_TC_SECTION_ELEMENTS", "Angezeigte Elemente")
ZO_CreateStringId("SI_TC_SHOW_WDAY_NAME", "Wochentag")
ZO_CreateStringId("SI_TC_SHOW_WDAY_TIP", "Zeigt den Wochentag an (Sundas, Morndas...)")
ZO_CreateStringId("SI_TC_SHOW_DATE_NAME", "Tag und Monat")
ZO_CreateStringId("SI_TC_SHOW_DATE_TIP", "Zeigt Tag und Monat an (14. Eisherbst...)")
ZO_CreateStringId("SI_TC_SHOW_YEAR_NAME", "Jahr und Ära")
ZO_CreateStringId("SI_TC_SHOW_YEAR_TIP", "Zeigt das Jahr an (582 der 2. Ära)")
ZO_CreateStringId("SI_TC_SHOW_SIGN_NAME", "Sternzeichen")
ZO_CreateStringId("SI_TC_SHOW_SIGN_TIP", "Zeigt das aktuelle Sternbild an (Zeichen: Das Ritual...)")
ZO_CreateStringId("SI_TC_SHOW_TIME_NAME", "Tamriel-Zeit")
ZO_CreateStringId("SI_TC_SHOW_TIME_TIP", "Zeigt die Spielzeit an (Stunden und Minuten)")