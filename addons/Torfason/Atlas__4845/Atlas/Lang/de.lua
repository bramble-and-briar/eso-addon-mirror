local AE = AtlasAddon

AE.Translations.de = {
    NAME = "Atlas",
    ADDON_DESCRIPTION = "Ein Torfason × Atlas Addon für The Elder Scrolls Online. Deckt die Weltkarte auf, während dein Charakter Tamriel erkundet.",
    PREFIX = "|cD8B36A[Atlas]|r ",

    LOADED = "geladen. /atlas hilfe zeigt die Befehle.",

    HELP = [[
|cD8B36AAtlas – Befehle|r
/atlas – Atlas-Einstellungen oeffnen
/atlas hilfe – diese Hilfe
/atlas an – Addon einschalten
/atlas aus – Addon ausschalten
/atlas aufdecken – aktuelle Karte vollstaendig aufdecken
/atlas vergessen – Erkundung der aktuellen Karte loeschen
/atlas import – TrueExploration des aktuellen Charakters importieren
/atlas importalle – alle gefundenen TrueExploration-Profile zusammenfuehren
/atlas status – Informationen zur aktuellen Karte
/atlas archiv – Atlas-Archiv auf der Weltkarte oeffnen
/atlas einstellungen – Atlas-Einstellungen oeffnen
/atlas stil <1-6> – leere Kartenart waehlen
/atlas radius <1-8> – Aufdeckradius in Kartenfeldern
/atlas deckkraft <10-100> – Deckkraft der unerforschten Karte in Prozent
/ae funktioniert weiterhin als kurze Alternative.

Englische Befehle funktionieren ebenfalls, z. B. /atlas help, /atlas on, /atlas reveal.
]],

    ENABLED = "Atlas ist eingeschaltet.",
    DISABLED = "Atlas ist ausgeschaltet.",
    CURRENT_MAP_REVEALED = "Die aktuelle Karte wurde vollstaendig aufgedeckt.",
    CURRENT_MAP_CLEARED = "Die Erkundung der aktuellen Karte wurde geloescht.",
    NO_MAP = "Aktuell konnte keine Kartenflaeche erkannt werden.",
    STATUS = "Karte: %s | entdeckt: %d / %d Felder (%.1f%%) | Stil: %s",
    STYLE_SET = "Leere Kartenart: %s",
    RADIUS_SET = "Aufdeckradius: %d Kartenfelder.",
    OPACITY_SET = "Deckkraft: %d%%.",
    BAD_VALUE = "Der Wert passt nicht. Nutze /atlas hilfe.",

    ARCHIVE_TITLE = "KARTENARCHIV",
    ARCHIVE_SUBTITLE = "Alle Karten, auf denen Atlas bereits etwas gezeichnet hat.",
    ARCHIVE_COUNT = "%d gespeicherte Karten",
    ARCHIVE_EMPTY = "Noch keine erkundeten Karten gespeichert.",
    ARCHIVE_PAGE = "Seite %d / %d",
    ARCHIVE_PREV = "Zurueck",
    ARCHIVE_NEXT = "Weiter",
    ARCHIVE_OPEN_HINT = "Klicken, um diese Karte zu oeffnen.",
    ARCHIVE_OPEN_FAILED = "ESO laesst diese Karte von hier aus nicht direkt oeffnen. Atlas behaelt sie trotzdem im Archiv.",
    ARCHIVE_UNRESOLVED = "Atlas kennt diese Zeichnung, konnte die ESO-Karten-ID aber noch nicht zuordnen. Sobald du die Karte wieder besuchst, wird sie automatisch ergaenzt.",
    ARCHIVE_RESOLVING = "Atlas ordnet aeltere gespeicherte Karten im Hintergrund ihren ESO-Karten-IDs zu …",
    ARCHIVE_PATH = "Gespeichert als: %s",
    ARCHIVE_UNKNOWN_MAP = "Unbekannte Karte",

    IMPORT_NO_TE = "TrueExploration-Daten sind nicht geladen. Aktiviere TrueExploration einmal zusammen mit Atlas, lade die UI neu und starte den Import erneut.",
    IMPORT_START = "TrueExploration-Import wird geprueft …",
    IMPORT_DONE = "Import fertig: %d Karten gefunden, %d Karten uebernommen, %d Felder ergaenzt, %d Eintraege konnten nicht erkannt werden.",
    IMPORT_NONE = "Das aktuelle TrueExploration-Charakterprofil wurde nicht gefunden. Aktiviere TrueExploration zusammen mit Atlas und lade die UI neu.",
    IMPORT_NONE_ALL = "In TE_SavedVars wurden keine TrueExploration-Kartentabellen gefunden.",
    IMPORT_ALL_WARNING = "Alle gefundenen TrueExploration-Profile werden in diesen Charakter zusammengefuehrt.",

    STYLE_NAMES = {
        "Pergament",
        "Helles Papier",
        "Dunkles Pergament",
        "Nebelgrau",
        "Kohle",
        "Tiefschwarz",
    },
    STYLE_VALUES = AE.LanguageStyleValues,
    STYLE_TOOLTIPS = {
        "Pergament – alte Entdeckerkarte mit verblasster Kompass- und Navigationszeichnung",
        "Helles Papier – Kartographenblatt mit feinen Vermessungslinien und Massmarken",
        "Dunkles Pergament – gealterte Seekarte mit verblassten Kuestenkonturen und Faltspuren",
        "Nebelgrau – kuehler Nebel mit kaum sichtbaren Hoehenlinien und weichen Schwaden",
        "Kohle – raues Kohlepapier mit handgezeichneten Wegen und alten Wegmarken",
        "Tiefschwarz – geheimnisvolle Nachtkarte mit sehr dezentem Stern- und Navigationsmuster",
    },

    SETTINGS_VERSION = "Version %s",
    SETTINGS_TITLE = "Atlas - Einstellungen",
    SETTINGS_GENERAL_HEADER = "ALLGEMEIN",
    SETTINGS_APPEARANCE_HEADER = "DARSTELLUNG",
    SETTINGS_EXPLORATION_HEADER = "ERKUNDUNG",
    SETTINGS_DEFAULTS = "Standardwerte",
    SETTINGS_DEFAULTS_TT = "Alle Atlas-Einstellungen auf die Standardwerte zurücksetzen. Dein gespeicherter Erkundungsfortschritt bleibt erhalten.",
    SETTINGS_CLOSE = "Schließen",
    SETTINGS_CLOSE_SHORT = "X",
    SETTINGS_GEAR_TOOLTIP = "Atlas-Einstellungen oeffnen",
    SETTINGS_SELECTED_STYLE = "%s: %s",

    OPTION_DESCRIPTION = "Die Weltkarte beginnt leer und wird dort sichtbar, wo dein Charakter tatsaechlich unterwegs war. Fortschritt wird pro Charakter gespeichert; die Darstellung gilt fuer den ganzen Account.",
    OPTION_ENABLED = "Atlas einschalten",
    OPTION_ENABLED_TT = "Blendet die unerforschten Bereiche der Karte aus und zeichnet beim Erkunden neue Flaechen frei.",
    OPTION_STYLE = "Leere Kartenart – Vorschau",
    OPTION_STYLE_TT = "Klicke auf das Vorschaubild. Du siehst alle Kartenstile als kleine Bilder und kannst sie direkt auswaehlen.",
    OPTION_SELECTED = "Ausgewaehlt",
    OPTION_OPACITY = "Deckkraft der unerforschten Karte",
    OPTION_OPACITY_TT = "100 % verdeckt die eigentliche Karte vollstaendig. Weniger laesst sie schwach durchscheinen.",
    OPTION_RADIUS = "Aufdeckradius – grosse Karten",
    OPTION_RADIUS_TT = "Wie viele der 48×48 Kartenfelder um deinen Charakter herum sichtbar werden.",
    OPTION_SUBZONES = "Staedte, Verliese und Unterkarten erkunden",
    OPTION_SUBZONES_TT = "Wenn aktiv, starten auch Unterkarten zunaechst unerforscht.",
    OPTION_SUBRADIUS = "Aufdeckradius – Unterkarten",
    OPTION_SUBRADIUS_TT = "Unterkarten sind oft kleiner. Darum kann hier ein eigener, groesserer Radius eingestellt werden.",
    OPTION_CURRENT_HEADER = "Aktuelle Karte",
    OPTION_REVEAL = "Aktuelle Karte vollstaendig aufdecken",
    OPTION_REVEAL_TT = "Markiert die momentan angezeigte Karte als vollstaendig entdeckt.",
    OPTION_CLEAR = "Aktuelle Karte wieder vergessen",
    OPTION_CLEAR_TT = "Loescht nur den Atlas-Fortschritt der momentan angezeigten Karte.",
    OPTION_IMPORT_HEADER = "TrueExploration-Import",
    OPTION_IMPORT_DESC = "Der Import liest TrueExploration nur aus und veraendert dessen Daten nicht. Fuer den Import des aktuellen Charakters muss TrueExploration einmal zusammen mit Atlas aktiviert sein. Atlas versteht das echte 31-Bit-Speicherformat des 48×48-Rasters; Gross-/Kleinschreibung in Kartenpfaden wird automatisch zusammengefuehrt.",
    OPTION_IMPORT_CURRENT = "Aktuellen Charakter importieren",
    OPTION_IMPORT_CURRENT_TT = "Empfohlen: uebernimmt nur die TrueExploration-Daten des aktuell eingeloggten Charakters.",
    OPTION_IMPORT_ALL = "Alle alten Profile zusammenfuehren",
    OPTION_IMPORT_ALL_TT = "Fuehrt alle gefundenen TrueExploration-Karten in den aktuellen Charakter zusammen. Bestehende Atlas-Felder werden nie geloescht.",
    OPTION_COMMANDS_HEADER = "Chatbefehle",
    OPTION_COMMANDS = "/atlas   /atlas hilfe   /atlas aufdecken   /atlas vergessen   /atlas import   /atlas status\n/atlas stil 1-6   /atlas radius 1-8   /atlas deckkraft 10-100",
}
