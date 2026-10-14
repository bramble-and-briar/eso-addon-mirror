local AE = AtlasAddon

AE.Translations.de = {
    NAME = "Atlas",
    ADDON_DESCRIPTION = "Ein Torfason × Atlas Addon für The Elder Scrolls Online. Deckt die Weltkarte auf, während dein Charakter Tamriel erkundet.",
    PREFIX = "|cD8B36A[Atlas]|r ",

    LOADED = "geladen. /atlas hilfe zeigt die Befehle.",

    HELP = [[
|cD8B36AAtlas – Befehle|r
/atlas – Atlas-Einstellungen öffnen
/atlas hilfe – diese Hilfe
/atlas an – Addon einschalten
/atlas aus – Addon ausschalten
/atlas aufdecken – aktuelle Karte vollständig aufdecken
/atlas vergessen – Erkundung der aktuellen Karte löschen
/atlas import – TrueExploration des aktuellen Charakters importieren
/atlas importalle – alle gefundenen TrueExploration-Profile zusammenführen
/atlas status – Informationen zur aktuellen Karte
/atlas archiv – Atlas-Archiv auf der Weltkarte öffnen
/atlas einstellungen – Atlas-Einstellungen öffnen
/atlas stil <1-6> – leere Kartenart wählen
/atlas radius <1-8> – Aufdeckradius in Kartenfeldern
/atlas deckkraft <10-100> – Deckkraft der unerforschten Karte in Prozent
/ae funktioniert weiterhin als kurze Alternative.

Englische Befehle funktionieren ebenfalls, z. B. /atlas help, /atlas on, /atlas reveal.
]],

    ENABLED = "Atlas ist eingeschaltet.",
    DISABLED = "Atlas ist ausgeschaltet.",
    CURRENT_MAP_REVEALED = "Die aktuelle Karte wurde vollständig aufgedeckt.",
    CURRENT_MAP_CLEARED = "Die Erkundung der aktuellen Karte wurde gelöscht.",
    NO_MAP = "Aktuell konnte keine Kartenfläche erkannt werden.",
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
    ARCHIVE_PREV = "Zurück",
    ARCHIVE_NEXT = "Weiter",
    ARCHIVE_VARIANT_LABEL = "Karte %d · ID %s",
    ARCHIVE_GROUP_EXPAND_HINT = "Klicken, um die einzelnen Karten oder Etagen anzuzeigen.",
    ARCHIVE_GROUP_COLLAPSE_HINT = "Klicken, um die Kartengruppe wieder einzuklappen.",
    ARCHIVE_FORGET = "Karte vergessen",
    ARCHIVE_FORGET_HINT = "Nur den Atlas-Erkundungsfortschritt dieser Karte löschen. Es folgt eine Sicherheitsabfrage.",
    ARCHIVE_MAP_CLEARED = "Der Erkundungsfortschritt für „%s“ wurde gelöscht.",
    ARCHIVE_OPEN_HINT = "Linksklick: Karte öffnen. Rechtsklick: Aufdecken oder Vergessen.",
    ARCHIVE_REVEAL = "Karte aufdecken",
    ARCHIVE_MAP_REVEALED = "Die Karte „%s“ wurde vollständig aufgedeckt.",
    ARCHIVE_MENU_UNAVAILABLE = "Das Kartenmenü ist nicht verfügbar. Es wurden keine Daten verändert.",
    ARCHIVE_OPEN_FAILED = "ESO lässt diese Karte von hier aus nicht direkt öffnen. Atlas behält sie trotzdem im Archiv.",
    ARCHIVE_UNRESOLVED = "Atlas kennt diese Zeichnung, konnte die ESO-Karten-ID aber noch nicht zuordnen. Sobald du die Karte wieder besuchst, wird sie automatisch ergänzt.",
    ARCHIVE_RESOLVING = "Atlas ordnet ältere gespeicherte Karten im Hintergrund ihren ESO-Karten-IDs zu …",
    ARCHIVE_PATH = "Gespeichert als: %s",
    ARCHIVE_UNKNOWN_MAP = "Unbekannte Karte",

    IMPORT_NO_TE = "TrueExploration-Daten sind nicht geladen. Aktiviere TrueExploration einmal zusammen mit Atlas, lade die UI neu und starte den Import erneut.",
    IMPORT_START = "TrueExploration-Import wird geprüft …",
    IMPORT_DONE = "Import fertig: %d Karten gefunden, %d Karten übernommen, %d Felder ergänzt, %d Einträge konnten nicht erkannt werden.",
    IMPORT_NONE = "Das aktuelle TrueExploration-Charakterprofil wurde nicht gefunden. Aktiviere TrueExploration zusammen mit Atlas und lade die UI neu.",
    IMPORT_NONE_ALL = "In TE_SavedVars wurden keine TrueExploration-Kartentabellen gefunden.",
    IMPORT_ALL_WARNING = "Alle gefundenen TrueExploration-Profile werden in diesen Charakter zusammengeführt.",

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
        "Helles Papier – Kartographenblatt mit feinen Vermessungslinien und Maßmarken",
        "Dunkles Pergament – gealterte Seekarte mit verblassten Küstenkonturen und Faltspuren",
        "Nebelgrau – kühler Nebel mit kaum sichtbaren Höhenlinien und weichen Schwaden",
        "Kohle – raues Kohlepapier mit handgezeichneten Wegen und alten Wegmarken",
        "Tiefschwarz – geheimnisvolle Nachtkarte mit sehr dezentem Stern- und Navigationsmuster",
    },

    OPTION_LANGUAGE = "Sprache",
    OPTION_LANGUAGE_TT = "Wähle die Sprache nur für Atlas. Automatisch folgt ESO; die Sprache von ESO und anderen Addons bleibt unverändert.",
    LANGUAGE_AUTO = "Automatisch (wie ESO)",

    SETTINGS_VERSION = "Version %s",
    SETTINGS_TITLE = "Atlas - Einstellungen",
    SETTINGS_GENERAL_HEADER = "ALLGEMEIN",
    SETTINGS_APPEARANCE_HEADER = "DARSTELLUNG",
    SETTINGS_EXPLORATION_HEADER = "ERKUNDUNG",
    SETTINGS_DEFAULTS = "Standardwerte",
    SETTINGS_DEFAULTS_TT = "Alle Atlas-Einstellungen auf die Standardwerte zurücksetzen. Dein gespeicherter Erkundungsfortschritt bleibt erhalten.",
    SETTINGS_CLOSE = "Schließen",
    SETTINGS_CLOSE_SHORT = "X",
    SETTINGS_GEAR_TOOLTIP = "Atlas-Einstellungen öffnen",
    SETTINGS_SELECTED_STYLE = "%s: %s",

    OPTION_DESCRIPTION = "Die Weltkarte beginnt leer und wird dort sichtbar, wo dein Charakter tatsächlich unterwegs war. Fortschritt wird pro Charakter gespeichert; die Darstellung gilt für den ganzen Account.",
    OPTION_ENABLED = "Atlas einschalten",
    OPTION_ENABLED_TT = "Blendet die unerforschten Bereiche der Karte aus und zeichnet beim Erkunden neue Flächen frei.",
    OPTION_STYLE = "Leere Kartenart – Vorschau",
    OPTION_STYLE_TT = "Klicke auf das Vorschaubild. Du siehst alle Kartenstile als kleine Bilder und kannst sie direkt auswählen.",
    OPTION_SELECTED = "Ausgewählt",
    OPTION_OPACITY = "Deckkraft der unerforschten Karte",
    OPTION_OPACITY_TT = "100 % verdeckt die eigentliche Karte vollständig. Weniger lässt sie schwach durchscheinen.",
    OPTION_RADIUS = "Aufdeckradius – große Karten",
    OPTION_RADIUS_TT = "Wie viele der 48×48 Kartenfelder um deinen Charakter herum sichtbar werden.",
    OPTION_SUBZONES = "Städte, Verliese und Unterkarten erkunden",
    OPTION_SUBZONES_TT = "Wenn aktiv, starten auch Unterkarten zunächst unerforscht.",
    OPTION_SUBRADIUS = "Aufdeckradius – Unterkarten",
    OPTION_SUBRADIUS_TT = "Unterkarten sind oft kleiner. Darum kann hier ein eigener, größerer Radius eingestellt werden.",
    OPTION_CURRENT_HEADER = "Aktuelle Karte",
    OPTION_REVEAL = "Aktuelle Karte vollständig aufdecken",
    OPTION_REVEAL_TT = "Markiert die momentan angezeigte Karte als vollständig entdeckt.",
    OPTION_CLEAR = "Aktuelle Karte vergessen",
    OPTION_CLEAR_TT = "Löscht nur den Atlas-Fortschritt der momentan angezeigten Karte.",
    CONFIRM_CLEAR_TITLE = "Erkundung der Karte vergessen?",
    CONFIRM_CLEAR_TEXT = "Möchtest du den gesamten Atlas-Erkundungsfortschritt für „<<1>>“ löschen? Dies kann nicht rückgängig gemacht werden.",
    CONFIRM_CLEAR_ACCEPT = "Karte vergessen",
    CONFIRM_CLEAR_CANCEL = "Abbrechen",
    CONFIRM_CLEAR_UNAVAILABLE = "Die Sicherheitsabfrage ist nicht verfügbar. Es wurden keine Erkundungsdaten gelöscht.",

    OPTION_IMPORT_HEADER = "TrueExploration-Import",
    OPTION_IMPORT_DESC = "Der Import liest TrueExploration nur aus und verändert dessen Daten nicht. Für den Import des aktuellen Charakters muss TrueExploration einmal zusammen mit Atlas aktiviert sein. Atlas versteht das echte 31-Bit-Speicherformat des 48×48-Rasters; Groß-/Kleinschreibung in Kartenpfaden wird automatisch zusammengeführt.",
    OPTION_IMPORT_CURRENT = "Aktuellen Charakter importieren",
    OPTION_IMPORT_CURRENT_TT = "Empfohlen: übernimmt nur die TrueExploration-Daten des aktuell eingeloggten Charakters.",
    OPTION_IMPORT_ALL = "Alle alten Profile zusammenführen",
    OPTION_IMPORT_ALL_TT = "Führt alle gefundenen TrueExploration-Karten in den aktuellen Charakter zusammen. Bestehende Atlas-Felder werden nie gelöscht.",
    OPTION_COMMANDS_HEADER = "Chatbefehle",
    OPTION_COMMANDS = "/atlas   /atlas hilfe   /atlas aufdecken   /atlas vergessen   /atlas import   /atlas status\n/atlas stil 1-6   /atlas radius 1-8   /atlas deckkraft 10-100",
}
