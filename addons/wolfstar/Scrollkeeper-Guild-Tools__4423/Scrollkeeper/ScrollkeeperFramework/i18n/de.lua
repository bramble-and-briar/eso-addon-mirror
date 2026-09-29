Scrollkeeper = Scrollkeeper or {}
Scrollkeeper.Localization = Scrollkeeper.Localization or {}

--------------------------------------------------------------------------------
-- FRAMEWORK CORE
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperFramework"] = {
  FRAMEWORK_LOADED = "Scrollkeeper Framework erfolgreich geladen",
  CRITICAL_ERROR = "KRITISCHER FEHLER: Einstellungspanel konnte nicht erstellt werden!",
  ERROR_REGISTERING = "FEHLER beim Registrieren der Einstellungen",
  LAM2_UNAVAILABLE = "LibAddonMenu2 nicht verfügbar!",
  ALREADY_INITIALIZED = "Bereits initialisiert, überspringe...",
  CHAT_BUTTONS_DISABLED = "LibChatMenuButton nicht verfügbar - Chat-Buttons deaktiviert",
  HEADER_DESC = "Kern-Framework für Scrollkeeper Gilden-Tools mit erweiterten Bibliotheksintegrationen. Einzelne Module haben eigene Einstellungen und erfordern kein Neuladen.",
  DONATE_BUTTON = "Entwicklung unterstützen",
  DONATE_TOOLTIP = "Sende eine Spende an @WolfStar07 auf PC/NA, um die weitere Entwicklung zu unterstützen",
  OPEN_ALL_WINDOWS = "Alle Scrollkeeper-Fenster öffnen",
  OPEN_SETTINGS = "Scrollkeeper-Einstellungen öffnen",
  DISPLAY_NAME = "|cF5DA81Scrollkeeper Gilden-Tools|r",
}

--------------------------------------------------------------------------------
-- COLOR THEMES
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperColorThemes"] = {
  -- Main
  SUBMENU_NAME = "Farbthemen",
  DESCRIPTION = "Wähle aus vordefinierten Farbthemen für Scrollkeepers Oberflächenelemente.",
  ACTIVE_THEME = "Aktives Thema",
  ACTIVE_THEME_TOOLTIP = "Wähle, welches Farbthema auf Scrollkeeper-Oberflächenelemente angewendet werden soll.",
  CURRENT_THEME = "Aktuelles Thema: %s",
  
  -- Preview Section
  PREVIEW_HEADER = "Farbvorschau:",
  BORDER_COLOR = "Rahmenfarbe",
  BORDER_DESC = "Fensterränder und Kanten",
  HEADER_COLOR = "Kopfzeilenfarbe",
  HEADER_DESC = "Titelleisten und Spaltenüberschriften",
  TEXT_COLOR = "Textfarbe", 
  TEXT_DESC = "Primärtext und Beschriftungen",
  ACCENT_COLOR = "Akzentfarbe",
  ACCENT_DESC = "Hervorgehobene Schaltflächen und Auswahlen",
  NOTE = "Hinweis: Themaänderungen werden sofort auf alle geöffneten Scrollkeeper-Fenster angewendet.",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperColorThemes]|r FEHLER: ScrollkeeperFramework fehlt!",
  
  -- Theme Names
  THEME_EMBER = "Glut",
  THEME_FORGE = "Schmiede",
  THEME_OCEAN = "Ozean",
  THEME_SKY = "Himmel",
  THEME_REGALIA = "Insignien",
  THEME_BRIAR = "Dornbusch",
  THEME_JUNGLE = "Dschungel",
  
  -- Status Messages
  STATUS_UNKNOWN = "Unbekannt",
}

--------------------------------------------------------------------------------
-- PROVISIONAL MEMBER TRACKING
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperProvisionMember"] = {
  SUBMENU_NAME = "Probemitglieder-Verfolgung",
  DESCRIPTION = "Verfolge Gildenmitglieder in Proberängen und solche, die Spendenanforderungen nicht erfüllen. Verwende |cFFD700/sgtprovision|r, um das Verwaltungsfenster zu öffnen.",
  MASTER_ENABLE = "Probemitglieder-Verfolgung aktivieren (Master)",
  MASTER_ENABLE_TIP = "Hauptschalter für alle Probemitglieder-Verfolgungsfunktionen.",
  OPEN_ADMIN = "Admin-Fenster öffnen",
  OPEN_ADMIN_TIP = "Öffne das Probemitglieder-Verwaltungsfenster",
  CLEAR_SCAN = "Fehlerhafte Daten löschen & Scannen",
  CLEAR_SCAN_TIP = "Lösche fehlerhaft verfolgte Mitglieder und scanne nach neuen",
  RESET_GOLD = "Gold-Entfernungen zurücksetzen",
  RESET_GOLD_TIP = "Lösche alle goldbasierten Entfernungsmarkierungen, damit Mitglieder für Gold-Verfolgung neu bewertet werden können",
  STATUS_TRACKING = "Derzeit verfolgt: %d aktive Probemitglieder",
  STATUS_RANK_REMOVED = "Dauerhaft entfernt (Rang): %d Mitglieder",
  STATUS_GOLD_REMOVED = "Vorübergehend entfernt (Gold): %d Mitglieder",
  WINDOW_OPENED_MESSAGE = "Fenster geöffnet. Verwenden Sie die |cFFFFFFScan|r-Schaltfläche, um Mitglieder zu überprüfen, die eine Nachverfolgung benötigen.",
  
  -- Window UI
  WINDOW_TITLE = "Probemitglieder-Verwaltung",
  SELECT_GUILD = "Gilde auswählen:",
  FILTER_LABEL = "Filter:",
  MEMBER_NAME = "Mitgliedsname",
  DAYS = "Tage",
  STATUS = "Verfolgungsstatus",
  NOTES = "Notizen",
  ACTIONS = "Aktionen",
  
  -- Guild Settings
  ENABLE_FOR_GUILD = "Für %s aktivieren",
  ENABLE_FOR_GUILD_TIP = "Aktiviere Probemitglieder-Verfolgung für diese Gilde.",
  AUTO_TAG = "Neue Mitglieder automatisch markieren",
  AUTO_TAG_TIP = "Markiere automatisch Mitglieder, die Verfolgungskriterien erfüllen.",
  NOTIFY_JOIN = "Benachrichtigen, wenn Mitglieder beitreten",
  NOTIFY_JOIN_TIP = "Zeige Benachrichtigungen für neue Mitglieder in dieser Gilde.",
  PROBATION_DAYS = "Probezeit (Tage)",
  PROBATION_DAYS_TIP = "Wie viele Tage Mitglieder im Probestatus bleiben, bevor sie befördert werden.",
  
  -- Gold Tracking
  GOLD_HEADER = "Verfolgung der Goldanforderungen",
  INACTIVITY_HEADER = "Inaktivitätsverfolgung",
  DONOR_HEADER = "Spenderanerkennung",
  GOLD_ENABLE = "Gold-Spenden-Filter aktivieren",
  GOLD_ENABLE_TIP = "Verfolge Mitglieder, die Spendenanforderungen nicht erfüllt haben.",
  GOLD_AMOUNT = "Erforderlicher Spendenbetrag",
  GOLD_AMOUNT_TIP = "Goldmenge, die Mitglieder im Zeitraum spenden müssen (z.B. 5000 für 5k Beiträge).",
  GOLD_PERIOD = "Zeitraum (Tage)",
  GOLD_PERIOD_TIP = "Anzahl der Tage, die auf Spenden geprüft werden (z.B. 30 für monatliche Beiträge, 7 für wöchentliche).",
  STATUS_PENDING_DONATION = "Spende Ausstehend",
  SOURCE_MANUAL = "Manuell",
  TIP_DAYS_MANUAL = "^ = Enthält manuelle Spendeneinträge",
  
  -- Statistics
  GUILD_STATS = "Gildenstatistiken",
  NO_MEMBERS = "Derzeit keine Probemitglieder für diese Gilde verfolgt",
  STATS_FORMAT = "Verfolge %d Mitglieder: %d aktiv, %d überfällig, %d befördert",
  RECENT_ADDITIONS = "Kürzliche Hinzufügungen (letzte 7 Tage): %d",
  
  -- Integration Status
  INTEGRATION_HEADER = "Beitrittszeitdaten-Quellen & Integration",
  AMT_AVAILABLE = "Advanced Member Tooltip - Genaueste Beitrittszeiten verfügbar",
  AMT_UNAVAILABLE = "Advanced Member Tooltip - Nicht installiert",
  AMT_INSTALL = "Installieren von: esoui.com/downloads/info2351",
  AMT_DESC = "Bietet genaueste Verfolgung der Gilden-Beitrittszeit",
  LH_READY = "LibHistoire - Bereit und verarbeitet Gildenhistorie",
  LH_MISSING = "LibHistoire - Nicht gefunden (erforderliche Abhängigkeit)",
  DATA_AVAILABLE = "Datenmodul - Gold-Spenden-Verfolgung aktiviert",
  DATA_UNAVAILABLE = "Datenmodul - Gold-Filterung nicht verfügbar",
  
  -- Symbol Legend
  SYMBOL_LEGEND = "Symbole in der Tage-Spalte:",
  SYMBOL_AMT = "* = AMT-Daten (am genauesten)",
  SYMBOL_HISTOIRE = "~ = LibHistoire Gildenhistorie",
  SYMBOL_DONATION = "? = Erste Spendenschätzung",
  SYMBOL_TAGGED = "! = Verfolgungsstartzeit",
  SYMBOL_VALIDATED = "(kein Symbol) = Validierte gespeicherte Daten",
  SYMBOL_UNKNOWN = "UNK = Unbekannte/unzuverlässige Quelle",
  SYMBOL_FOOTER = "Fahre über einen Tage-Wert für detaillierte Quelleninformationen.",
  TIP_SORT_NAME = "Klicken Sie zum Sortieren nach Namen",
  TIP_SORT_DAYS = "Klicken Sie zum Sortieren nach Tagen seit Beitritt",

  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "[ScrollkeeperProvisionMember] FEHLER: Framework fehlt!",
  ERROR_NO_GUILD_SELECTED = "Keine Gilde ausgewählt",
  ERROR_MAIL_UNAVAILABLE = "ScrollkeeperNotebookMail nicht verfügbar",
  ERROR_NO_MEMBERS_TO_MAIL = "Keine Mitglieder zum Mailen",
  ERROR_MAIL_WINDOW_FAILED = "Zugriff auf Mail-Fenster fehlgeschlagen",
  ERROR_SETTINGS_UNAVAILABLE = "Einstellungen nicht verfügbar",
  ERROR_NO_GUILDS = "Keine Gilden verfügbar. Tritt einer Gilde bei, um gildenspezifische Einstellungen zu konfigurieren.",
 
  -- Success Messages
  SUCCESS_AMT_DETECTED = "Advanced Member Tooltip erkannt - erweiterte Verfolgung aktiviert",
  SUCCESS_HISTOIRE_READY = "LibHistoire-Integration bereit - genaue Beitrittszeiten verfügbar",
  SUCCESS_REMOVED = "%s aus Verfolgung entfernt",
  SUCCESS_BULK_REMOVED = "%d Mitglieder massenweise aus Verfolgung entfernt",
  SUCCESS_CLEARED_DATA = "Verfolgungsdaten für %s gelöscht",
  SUCCESS_CLEARED_GOLD = "%d goldbasierte Entfernungsmarkierungen gelöscht",
  SUCCESS_MAIL_OPENED = "Mail-Fenster geöffnet mit %d Probemitgliedern von %s",

  -- Status Messages
  STATUS_DISABLED = "Probeverfolgung ist deaktiviert",
  STATUS_NO_DATA = "Keine Daten verfügbar",
  STATUS_NO_TRACKING = "Keine Verfolgungsdaten verfügbar",
  STATUS_SELECT_GUILD = "Wähle eine Gilde, um Statistiken anzuzeigen",
  STATUS_NO_FILTER_MATCH = "Keine Mitglieder entsprechen den aktuellen Filterkriterien.",
  STATUS_NO_SELECTED = "Keine Mitglieder zur Beförderung ausgewählt",
  STATUS_NO_SELECTED_REMOVE = "Keine Mitglieder zur Entfernung ausgewählt",
  
  -- Notes column - color coding descriptions (for tooltip if needed)
  NOTES_COLOR_DONATION = "Grün: Spendeninformationen",
  NOTES_COLOR_OFFLINE = "Orange: Offline-Informationen",
  NOTES_COLOR_NO_DONATION = "Rot: Keine Spenden gefunden",

  -- Button Labels
  BTN_REFRESH = "Aktualisieren",
  BTN_REFRESH_TIP = "Gildendaten und Mitgliederliste aktualisieren",
  BTN_EXPORT = "Exportieren",
  BTN_EXPORT_TIP = "Mitgliederdaten in kopierbares Textfenster exportieren",
  BTN_SCAN = "Scannen",
  BTN_SCAN_TIP = "Gildenlisten nach neuen Probemitgliedern scannen",
  BTN_VIEW_SELECTED = "Ausgewählte anzeigen",
  BTN_VIEW_ALL = "Alle anzeigen",
  BTN_VIEW_SELECTED_TIP = "Zwischen allen Mitgliedern und nur ausgewählten Mitgliedern wechseln",
  BTN_PROMOTE_ALL = "Alle befördern",
  BTN_PROMOTE_ALL_TIP = "Öffne Gildenliste, um hervorgehobene Mitglieder zu befördern.",
  BTN_REMOVE_ALL = "Alle entfernen",
  BTN_REMOVE_ALL_TIP = "Alle ausgewählten Mitglieder aus Verfolgung entfernen",
  BTN_MAIL_SELECTED = "Ausgewählte anmailen",
  BTN_MAIL_SELECTED_TIP_HIGHLIGHTED = "Mail-Fenster mit ausgewählten Mitgliedern öffnen (%d)",
  BTN_MAIL_SELECTED_TIP_FILTERED = "Mail-Fenster mit gefilterten Mitgliedern öffnen",
  BTN_SELECT_ALL = "Alle auswählen",
  BTN_CLOSE = "Schließen",

  -- Filter Labels
  FILTER_ALL = "ALLE",
  FILTER_PROBATION_ICON_TIP = "Nach Probemitgliedern filtern",
  FILTER_GOLD_ICON_TIP = "Nach Mitgliedern mit geringen Goldspenden filtern",
  STATUS_INACTIVE = "Inaktiv",
  STATUS_DONOR = "Aktiver Spender",

  -- Export Window
  EXPORT_TITLE = "Daten exportieren - Text auswählen und kopieren",
  EXPORT_INSTRUCTION = "Klicke 'Alle auswählen', dann verwende Strg+C zum Kopieren in die Zwischenablage",
  EXPORT_REPORT_HEADER = "Probemitglieder-Bericht für %s",
  EXPORT_GENERATED = "Erstellt: %s",
  EXPORT_FILTER = "Filter: %s",
  EXPORT_VIEW_SELECTED = "Ansicht: Nur ausgewählte Mitglieder",
  EXPORT_FILTER_ALL = "Alle Mitglieder",
  EXPORT_FILTER_RANK = "Probemitglieder",
  EXPORT_FILTER_GOLD = "Gold-Spenden-Mitglieder",
  EXPORT_FILTER_CUSTOM = "Gefilterte Mitglieder",
  EXPORT_FORMAT = "%s | Status: %s | Tage in Gilde: %s | Grund: %s | Notizen: %s",
  EXPORT_DAYS_NA = "N/V (Gold-Filter)",
  EXPORT_DAYS_FORMAT = "%d (%s)",
  EXPORT_DAYS_ACTUAL = "tatsächlich",
  EXPORT_DAYS_ESTIMATED = "geschätzt",
  EXPORT_FILTER_INACTIVE = "Inaktive Mitglieder",
  EXPORT_FILTER_DONOR = "Aktive Spender",

  -- Tooltips
  TIP_OPEN_ROSTER = "Gildenmitgliederliste für %s öffnen",
  TIP_REMOVE = "%s aus Verfolgung entfernen",
  TIP_DAYS_HEADER = "Tage seit Gildenbeitritt\n\n",
  TIP_DAYS_OFFLINE_HEADER = "Tage Offline",
  TIP_DAYS_OFFLINE_DESC = "Zeigt, wie viele Tage dieses Mitglied offline war.\nHöhere Zahlen bedeuten längere Inaktivität.",
  TIP_DAYS_AMT = "* = Advanced Member Tooltip (am genauesten)",
  TIP_DAYS_HISTOIRE = "~ = LibHistoire Gildenhistorie",
  TIP_DAYS_DONATION = "? = Erste Spendenschätzung",
  TIP_DAYS_TAGGED = "! = Verfolgungsstartzeit",
  TIP_DAYS_UNKNOWN = "(Unbekannt - keine zuverlässige Datenquelle)",
  TIP_DAYS_GOLD = "(Gold-Filter-Mitglied)",
  TIP_DAYS_VALIDATED = "(Validiert aus gespeicherten Daten)",
  TIP_INSTALL_AMT = "Installiere Advanced Member Tooltip\nfür genaueste Beitrittszeiten",
  TIP_REVIEW_KICK = "Liste öffnen, um %s zu überprüfen/kicken (inaktives Mitglied)",
  TIP_REVIEW_PROMOTE = "Liste öffnen, um %s zu überprüfen/kicken (Probezeit-Mitglied)",
  TIP_REVIEW_DONATION = "Liste öffnen, um %s zu überprüfen (ausstehende Spende)",
  TIP_PROMOTE_DONOR = "Liste öffnen, um %s zu befördern (wertvoller Beitragender)",
  FILTER_INACTIVE_TIP = "Mitglieder anzeigen, die für den konfigurierten Zeitraum offline waren",
  FILTER_DONOR_TIP = "Mitglieder anzeigen, die die Mindestspendenanforderungen erfüllen",

  -- Logging Messages
  LOG_STARTING_SCAN = "Starte manuellen Scan...",
  LOG_SCAN_COMPLETE = "Manueller Scan abgeschlossen - %d fehlerhafte Einträge gelöscht, %d neue Mitglieder gefunden",
  LOG_REFRESHED = "Anzeige aktualisiert",
  LOG_NEW_MEMBER = "Neues Mitglied ist %s beigetreten: %s",
  LOG_OPENING_ROSTER_PROMOTE = "Öffne Liste zur Beförderung: %s",
  LOG_OPENING_ROSTER_BULK = "Öffne Liste - befördere diese %d Mitglieder: %s",
  LOG_NO_GUILD_ID = "Konnte Gilden-ID nicht finden für: %s",
  LOG_NO_GUILD_ID_SIMPLE = "Konnte Gilden-ID nicht finden",
  LOG_FILTER_MODE = "%s-Modus - %d Mitglieder ausgewählt",
  LOG_INITIALIZING = "Initialisiere - %s",
  ERROR_DATA_NOT_READY = "Gildenhistoriendaten sind noch nicht bereit. Warte einen Moment und versuche es erneut.",
  LOG_SCAN_COMPLETE_SHORT = "Scan abgeschlossen!",

  -- Mail Integration
  MAIL_SUBJECT_GOLD = "Gildenbeitrags-Erinnerung - %s",
  MAIL_RECIPIENT_COUNT = "Probe-Empfänger: %d",
  MAIL_STATUS = "Status: %d Probemitglieder bereit zum Mailen",

  -- Stats Display
  STATS_FORMAT_FULL = "Gilde: %s | Gesamt: %d | Aktiv: %d | Überfällig: %d | Befördert: %d | Probe: %d | Gold: %d",
  STATS_LH_READY = "bereit",
  STATS_LH_LOADING = "lädt",

  -- Auto-tag Messages
  AUTO_TAG_SCAN = "Auto-markiert (Scan)",
  AUTO_TAG_LOGIN = "Auto-markiert (Login-Scan)",
  AUTO_TAG_ONLINE = "Auto-markiert (online beigetreten)",
  ACTIVE_DONOR = "Aktiver Spender",

  -- Dropdown Messages
  DROPDOWN_NO_GUILDS = "Keine Gilden für Verfolgung konfiguriert",

  -- Status Values
  STATUS_PROVISIONAL = "probe",
  STATUS_PROMOTED = "befördert",

  -- Reason Values
  REASON_RANK = "rang",
  REASON_GOLD = "gold",
  REASON_INACTIVE = "Inaktiv",
  REASON_DONOR = "Spender",

  -- Integration Status (detailed)
  INTEGRATION_AMT_INSTALL_URL = "esoui.com/downloads/info2351",
  INTEGRATION_STATUS = "Status der integrierten Addons und Datenquellen:",

  -- Member Count Status
  MEMBER_COUNT_STATUS = "Mitgliederzahl-Status",
  MEMBER_COUNT_FORMAT = "Derzeit verfolgt: %d aktive Probemitglieder\nDauerhaft entfernt (Rang): %d Mitglieder\nVorübergehend entfernt (Gold): %d Mitglieder",

  -- Sources
  SOURCE_AMT = "amt",
  SOURCE_HISTOIRE = "histoire",
  SOURCE_DONATION = "spende",
  SOURCE_TAGGED = "markiert",
  SOURCE_STORED = "gespeichert",
  SOURCE_UNKNOWN = "unbekannt",
  SOURCE_DATA = "daten",

  -- Days display values
  DAYS_UNKNOWN = "UNB",
  DAYS_ERROR = "FEHL",
  DAYS_NA = "-",
  
  -- Inactivity Filter Settings
  INACTIVITY_ENABLE = "Inaktive Mitglieder verfolgen",
  INACTIVITY_ENABLE_TIP = "Automatisch Mitglieder verfolgen, die für einen längeren Zeitraum offline waren",
  INACTIVITY_DAYS = "Inaktiv Nach (Tage)",
  INACTIVITY_DAYS_TIP = "Ein Mitglied als inaktiv betrachten, wenn es sich so viele Tage nicht angemeldet hat",
  
  -- Settings - Donor Filter
  DONOR_ENABLE = "Aktive Spender verfolgen",
  DONOR_ENABLE_TIP = "Mitglieder verfolgen, die die Mindestspendenanforderungen erfüllen oder übertreffen (nützlich zur Anerkennung von Beitragenden)",
  DONOR_AMOUNT = "Mindestspendenbetra",
  DONOR_AMOUNT_TIP = "Goldbetrag, der erforderlich ist, um als aktiver Spender zu gelten",
  DONOR_PERIOD = "Zeitraum (Tage)",
  DONOR_PERIOD_TIP = "Spenden innerhalb der letzten X Tage überprüfen",
  MANUAL_SCAN_NOTE = "Hinweis: Die Mitgliederverfolgung erfordert manuelles Scannen. Öffne das Fenster für provisorische Mitglieder und klicke auf die Schaltfläche Scannen, um Mitglieder zu überprüfen, die verfolgt werden müssen.",
}

--------------------------------------------------------------------------------
-- GUILD MAIL
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperNotebookMail"] = {
  SUBMENU_NAME = "Gildenpost",
  DESCRIPTION = "Massenpost-Komposition mit Vorlagenintegration. Mail-Sendungen werden automatisch auf 3,1 Sekunden zwischen Nachrichten gedrosselt. Verwende |cFFD700/sgtmail|r, um das Mail-Fenster zu öffnen.",
  ENABLE_MAIL = "Gildenpost aktivieren",
  ENABLE_MAIL_TIP = "Schalte die Gildenpost-Funktion ein oder aus.",
  OPEN_MAIL = "Mail-Fenster öffnen",
  OPEN_MAIL_TIP = "Klicke, um das Mail-Kompositionsfenster zu öffnen.",
  
  -- Window UI
  WINDOW_TITLE = "Scrollkeeper Gildenpost",
  MAIL_TEMPLATES = "Mail-Vorlagen:",
  SELECT_TEMPLATE = "-- Vorlage auswählen --",
  GUILD_LABEL = "Gilde:",
  RANK_FILTER = "Rangfilter:",
  ALL_RANKS = "Alle Ränge",
  PROVISIONAL_LABEL = "Probemitglieder:",
  ALL_PROVISIONAL = "Alle Probe",
  GOLD_ONLY = "Nur Gold-Filter",
  RANK_ONLY = "Nur Rang-Filter",
  USE_PROVISIONAL = "Probeliste verwenden",
  KICK_AFTER_MAIL = "Nach dem Versand entfernen:",
  KICK_NO = "Nicht entfernen",
  KICK_YES = "Nach dem Versand entfernen",
  KICK_NO_PERMISSION = "Sie haben keine Berechtigung, Mitglieder aus dieser Gilde zu entfernen",
  MEMBER_KICKED = "Entfernt: %s",
  MEMBER_NOT_FOUND = "Mitglied %s konnte nicht in der Gildenliste gefunden werden",
  PREVIEW_TITLE = "E-Mail-Vorschau",
  PREVIEW_MAIL = "Vorschau",
  
  -- Composition
  SUBJECT_LABEL = "Betreff:",
  BODY_LABEL = "Nachrichtentext:",
  READY_TO_SEND = "Bereit zum Senden",
  STATUS_READY = "Status: Bereit",
  RECIPIENTS = "Empfänger: %d",
  
  -- Buttons
  SAVE_TEMPLATE = "Vorlage speichern",
  PREVIEW_RECIPIENTS = "Empfänger-Vorschau",
  SEND_MAIL = "Mail senden",
  PAUSE = "Pause",
  RESUME = "Fortsetzen",
  
  -- Status Messages
  NO_GUILD = "Status: Bitte zuerst eine Gilde auswählen",
  NO_SUBJECT = "Status: Bitte einen Betreff eingeben",
  NO_BODY = "Status: Bitte einen Nachrichtentext eingeben",
  NO_RECIPIENTS = "Status: Keine Empfänger gefunden",
  STARTING = "Status: Starte Mail-Versand...",
  SENDING = "Sende %d/%d",
  SENDING_TO = "An: %s",
  SUCCESS = "Status: Mail erfolgreich gesendet",
  FAILED = "Status: Fehlgeschlagen - %s",
  PAUSED = "Status: Pausiert",
  COMPLETED = "Abgeschlossen: %d gesendet, %d fehlgeschlagen",
  TEMPLATE_SAVED = "Status: Vorlage gespeichert",
  TEMPLATE_FAILED = "Status: Vorlage speichern fehlgeschlagen",
  NEED_SUBJECT_BODY = "Status: Bitte Betreff und Text eingeben",
  RECIPIENTS_FOUND = "Status: %d Empfänger gefunden",
  NO_MATCH_FILTERS = "Status: Keine Empfänger entsprechen den Filtern",
  PROVISIONAL_SELECTED = "Status: %d Probemitglieder ausgewählt",
  NO_PROVISIONAL = "Status: Keine Probemitglieder gefunden",
  USING_PROVISIONAL = "Status: Verwende Probemitglieder-Liste...",
  
  -- Failure Reasons
  RECIPIENT_NOT_FOUND = "Empfänger nicht gefunden",
  MAILBOX_FULL = "Postfach voll",
  IGNORED = "Empfänger ignoriert Mail",
  BLANK_MAIL = "Leere Mail nicht erlaubt",
  UNKNOWN_ERROR = "Unbekannter Fehler",

  -- Character count display
  CHAR_COUNT = "%d/%d",

  -- Provisional member filter type display
  PROVISION_FILTER_ALL = "alle",
  PROVISION_FILTER_GOLD = "gold", 
  PROVISION_FILTER_RANK = "rang",

  -- Auto-generated subject for gold filter
  DUES_REMINDER_SUBJECT = "Gildenbeitrags-Erinnerung - %s",

  -- Failure log content
  FAILURE_LOG_TITLE = "Mail-Versand-Fehlerbericht",
  FAILURE_LOG_DATE = "Datum: %s",
  FAILURE_LOG_SUBJECT_LINE = "Betreff: %s",
  FAILURE_LOG_TOTAL_SENT = "Gesamt gesendet: %d",
  FAILURE_LOG_TOTAL_FAILED = "Gesamt fehlgeschlagen: %d",
  FAILURE_LOG_FAILED_LIST = "Fehlgeschlagene Empfänger:",
  FAILURE_LOG_SEPARATOR = string.rep("-", 50),
  FAILURE_LOG_BODY_HEADER = "Ursprünglicher Nachrichtentext:",
  FAILURE_LOG_SAVED = "Fehlerprotokoll im Notizbuch gespeichert: '%s'",
  FAILURE_LOG_SAVE_FAILED = "Fehlerprotokoll im Notizbuch speichern fehlgeschlagen",
  FAILURE_LOG_NO_NOTEBOOK = "Kann Fehlerprotokoll nicht speichern - Notizbuch nicht verfügbar",
  
  -- Mail tags
  TAG_MAIL = "post",
  TAG_TEMPLATE = "vorlage",
  TAG_MAIL_LOG = "post-log",
  TAG_FAILURES = "fehler",

  -- Failure log
  FAILURE_LOG_TITLE_FORMAT = "Postfehler - %s",
}

--------------------------------------------------------------------------------
-- NOTEBOOK
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperNotebook"] = {
  -- Main
  SUBMENU_NAME = "Notizbuch-Einstellungen",
  WINDOW_TITLE = "Scrollkeeper Notizbuch",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperNotebook]|r FEHLER: ScrollkeeperFramework fehlt!",
  ERROR_ALREADY_INIT = "|cFFD700[ScrollkeeperNotebook]|r Bereits initialisiert, überspringe...",
  ERROR_WINDOW_EXISTS = "|cFFD700[ScrollkeeperNotebook]|r Fenster existiert bereits, gebe bestehendes zurück",
  ERROR_DROPDOWN_FAILED = "|cFFD700[ScrollkeeperNotebook]|r Warnung: Dropdown konnte nicht erstellt werden",
  ERROR_WINDOW_NOT_INIT = "Notizbuch-Fenster nicht initialisiert.",
  ERROR_NO_NOTE_ENTRY = "Es gibt keinen Notizeintrag für %s.",
  ERROR_DISABLED = "|cFFD700[ScrollkeeperNotebook]|r Notizbuch ist deaktiviert",
  ERROR_NO_TITLE = "|cFFD700[ScrollkeeperNotebook]|r Bitte einen Titel für die Notiz eingeben",
  ERROR_SAVE_FAILED = "|cFFD700[ScrollkeeperNotebook]|r Notiz speichern fehlgeschlagen",
  ERROR_TEMPLATE_NO_TITLE = "|cFFD700[ScrollkeeperNotebook]|r Bitte einen Titel für die Vorlage eingeben",
  
  -- Success Messages
  SUCCESS_NOTE_SAVED = "|cFFD700[ScrollkeeperNotebook]|r Notiz gespeichert: %s",
  SUCCESS_TEMPLATE_SAVED = "|cFFD700[ScrollkeeperNotebook]|r Mail-Vorlage gespeichert: %s",
  
  -- Window Labels
  LABEL_SEARCH = "Suche:",
  LABEL_CATEGORY = "Kategorie:",
  LABEL_SAVED_NOTES = "Gespeicherte Notizen:",
  LABEL_NOTE_TITLE = "Notiz-Titel:",
  LABEL_TAGS = "Tags (kommagetrennt):",
  LABEL_NOTE_CONTENT = "Notizinhalt:",
  LABEL_NOTES_COUNT = "Notizen: %d/%d",
  LABEL_NOTES_SIMPLE = "Notizen: %d",
  
  -- Character Counts
  CHAR_COUNT_TITLE = "%d/100",
  CHAR_COUNT_BODY = "%d/5000",
  
  -- Dropdown Options
  DROPDOWN_SELECT = "-- Notiz auswählen --",
  DROPDOWN_NO_MATCHES = "-- Keine Treffer gefunden --",
  
  -- Default Text
  DEFAULT_NOTE_TITLE = "Neue Notiz",
  DEFAULT_NOTE_BODY = "Gib deine Notiz hier ein...",
  
  -- Button Labels
  BTN_SAVE = "Speichern",
  BTN_NEW = "Neu",
  BTN_DELETE = "Löschen",
  BTN_SAVE_MAIL = "Mail speichern",
  BTN_OPEN_NOTEBOOK = "Notizbuch öffnen",
  
  -- Button Tooltips
  TIP_OPEN_NOTEBOOK = "Klicke, um das Notizbuch-Fenster zu öffnen (wie /sgtnote Befehl).",
  
  -- Settings
  SETTING_ENABLE = "Notizbuch-Modul aktivieren",
  SETTING_ENABLE_TIP = "Schalte die Notizbuch-Funktion ein/aus.",
  SETTING_SEARCH = "Suchfilter aktivieren",
  SETTING_SEARCH_TIP = "Erlaube Filterung von Notizen nach Suchbegriffen.",
  SETTING_DEFAULT_CATEGORY = "Standard-Kategorie",
  SETTING_DEFAULT_CATEGORY_TIP = "Standard-Kategorie für neue Notizen. Verwende 'Mail' für Mail-Vorlagen.",
  
  -- Descriptions
  DESC_MAIN = "Ein voll ausgestattetes In-Game-Notizbuch mit Suche, Kategorien und Tagging. Verwende |cFFD700/sgtnote|r, um das Notizbuch-Fenster zu öffnen.",
  DESC_MAIL_TEMPLATES = "Mail-Vorlagen: Speichere Notizen in der 'Mail'-Kategorie, um sie als Vorlagen im nativen Mail-Client und im Gildenpost-System zu verwenden.",
  
  -- Mail Integration
  MAIL_LABEL_TEMPLATES = "Mail-Vorlagen:",
  MAIL_DROPDOWN_SELECT = "-- Vorlage auswählen --",
  
  -- Categories
  CAT_GENERAL = "Allgemein",
  CAT_MAIL = "Mail",
  CAT_EVENTS = "Ereignisse",
  CAT_ALL_CATEGORIES = "Alle Kategorien",

  ERROR_MAX_TOTAL_NOTES = "Notiz kann nicht erstellt werden: Maximale Gesamtzahl der Notizen (%d) erreicht. Lösche zuerst einige Notizen.",
  ERROR_MAX_CATEGORY_NOTES = "Notiz kann nicht erstellt werden: Maximale Notizen (%d) für Kategorie '%s' erreicht.",
  ERROR_NOTE_TOO_LARGE = "Notiz ist zu groß (%d Zeichen). Maximum ist %d Zeichen.",
  STATS_HEADER = "Scrollkeeper Notizbuch Speicherstatistiken",
  STATS_TOTAL = "Gesamtnotizen: %d / %d",
  STATS_CATEGORY = " %s: %d / %d Notizen (~%.1f KB)",
  BTN_PREVIEW_MAIL = "Vorschau",
  PREVIEW_TITLE = "E-Mail-Vorschau",
  ERROR_NO_BODY = "Bitte geben Sie Text in den Nachrichtentext ein",
  
  -- Guild Tools Integration
  GUILDMAIL_NO_TEMPLATES   = "(Verwende 'Als Post speichern' im Notizbuch, um Vorlagen hinzuzufügen)",
  SETTING_GUILDMAIL_INJECT = "Vorlagen-Dropdown in der Gildenpost anzeigen",
  SETTING_GUILDMAIL_INJECT_TIP = "Zeigt eine Auswahlliste für Notizbuch-Postvorlagen im Verfassungsfenster der Gildenpost an.",
}

--------------------------------------------------------------------------------
-- HISTORY
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperHistory"] = {
  -- Main
  SUBMENU_NAME = "Gildenhistorie-Suche",
  WINDOW_TITLE = "Gildenhistorie-Suche",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperHistory]|r FEHLER: ScrollkeeperFramework fehlt!",
  ERROR_WINDOW_FAILED = "|cFFD700[ScrollkeeperHistory]|r Fenster erstellen fehlgeschlagen",
  ERROR_NO_EXPORT = "|cFFD700[ScrollkeeperHistory]|r Keine Ereignisse zum Exportieren",
  
  -- Success Messages
  SUCCESS_READY = "|cFFD700[ScrollkeeperHistory]|r Bereit - verwende /sgthistory",
  
  -- Log Messages
  LOG_LOADING = "|cFFD700[ScrollkeeperHistory]|r Lädt... SF.Data existiert: %s",
  LOG_DATA_GETEVENTS = "|cFFD700[ScrollkeeperHistory]|r SF.Data.getEvents beim Laden: %s",
  LOG_DATA_UNAVAILABLE = "|cFFD700[ScrollkeeperHistory]|r SF.Data.getEvents nicht verfügbar",
  LOG_FALLBACK_INIT = "|cFFD700[ScrollkeeperHistory]|r Fallback-Initialisierung ausgelöst",
  
  -- Window Labels
  LABEL_GUILD = "Gilde:",
  LABEL_CATEGORY = "Kategorie:",
  LABEL_SEARCH = "Suche:",
  LABEL_EVENTS_COUNT = "Ereignisse: %d",
  LABEL_REFRESH = "Aktualisieren",
  LABEL_EXPORT = "Exportieren",
  
  -- Status Messages
  STATUS_READY = "Bereit",
  STATUS_READY_LOADED = "Bereit - %d Ereignisse geladen",
  STATUS_NO_GUILD = "Keine Gilde ausgewählt",
  STATUS_DATA_NOT_READY = "Datenmodul nicht bereit",
  STATUS_NO_EVENTS_CACHE = "Keine Ereignisse gefunden - Cache wird möglicherweise noch aufgebaut. Stelle sicher, dass die Kategorie in LibHistoire aktiv ist.",
  STATUS_WAITING_LH = "Warte auf LibHistoire-Initialisierung...",
  STATUS_ENABLE_GUILDS = "Aktiviere Gilden in Historie-Einstellungen",
  
  -- Column Headers
  HEADER_TIME = "Zeit",
  HEADER_CATEGORY = "Kategorie",
  HEADER_EVENT = "Ereignis",
  HEADER_MEMBER = "Mitglied",
  HEADER_DETAILS = "Details",
  
  -- Category Names
  CAT_ALL = "Alle Ereignisse",
  CAT_ROSTER = "Liste",
  CAT_BANK_GOLD = "Bank Gold",
  CAT_BANK_ITEMS = "Bank Gegenstände",
  CAT_SALES = "Verkäufe",
  
  -- Event Type Names - Roster
  EVENT_INVITED = "Eingeladen",
  EVENT_JOINED = "Beigetreten",
  EVENT_PROMOTED = "Befördert",
  EVENT_DEMOTED = "Degradiert",
  EVENT_LEFT = "Verlassen",
  EVENT_KICKED = "Gekickt",
  EVENT_APP_ACCEPTED = "Bewerbung akzeptiert",
  
  -- Event Type Names - Bank Gold
  EVENT_GOLD_DEPOSITED = "Gold eingezahlt",
  EVENT_GOLD_WITHDRAWN = "Gold abgehoben",
  EVENT_TRADER_BID = "Händler-Gebot",
  EVENT_BID_RETURNED = "Gebot zurückerstattet",
  
  -- Event Type Names - Bank Items
  EVENT_ITEM_DEPOSITED = "Gegenstand eingezahlt",
  EVENT_ITEM_WITHDRAWN = "Gegenstand abgehoben",
  
  -- Event Type Names - Sales
  EVENT_ITEM_SOLD = "Gegenstand verkauft",
  
  -- Unknown Event
  EVENT_UNKNOWN = "Unbekannt (%s)",
  
  -- Time Formatting
  TIME_JUST_NOW = "Gerade eben",
  TIME_MINUTES_AGO = "vor %dm",
  TIME_HOURS_AGO = "vor %dh",
  TIME_DAYS_AGO = "vor %dd",
  TIME_MONTHS_AGO = "vor %dMo",
  
  -- Export Window
  EXPORT_TITLE = "Daten exportieren - Text auswählen und kopieren",
  EXPORT_INSTRUCTION = "Klicke 'Alle auswählen', dann verwende Strg+C zum Kopieren in die Zwischenablage",
  EXPORT_SELECT_ALL = "Alle auswählen",
  EXPORT_HEADER = "Gildenhistorie-Export für %s",
  EXPORT_GENERATED = "Erstellt: %s",
  EXPORT_CATEGORY = "Kategorie: %s",
  EXPORT_TOTAL = "Gesamtereignisse: %d",
  EXPORT_FORMAT = "%s | %s | %s | %s | %s",
  
  -- Tooltips
  TIP_REFRESH = "Gildenliste und Ereignisdaten aktualisieren",
  TIP_EXPORT = "Sichtbare Ereignisse in Text exportieren",
  TIP_FULL_TIMESTAMP = "Vollständiger Zeitstempel",
  TIP_FULL_DETAILS = "Vollständige Details",
  
  -- Settings - Main
  SETTINGS_DESC = "Durchsuche zwischengespeicherte Gildenhistorie-Ereignisse. Verwende |cFFD700/sgthistory|r, um das Suchfenster zu öffnen.\n\nDaten werden automatisch für alle Gilden von ScrollkeeperData zwischengespeichert. Hier steuerst du, welche Gilden und Kategorien im Suchfenster angezeigt werden.",
  SETTINGS_DISPLAY = "Anzeigeeinstellungen",
  SETTINGS_MAX_EVENTS = "Max. Ereignisse",
  SETTINGS_MAX_EVENTS_TIP = "Maximale Anzahl von Ereignissen, die auf einmal geladen werden",
  SETTINGS_SEARCH_DELAY = "Suchverzögerung (ms)",
  SETTINGS_SEARCH_DELAY_TIP = "Verzögerung vor Suchausführung beim Tippen",
  SETTINGS_COLOR_CODING = "Farbkodierung aktivieren",
  SETTINGS_COLOR_CODING_TIP = "Ereignisse nach Typ farblich kodieren",
  
  -- Settings - Per Guild
  SETTINGS_SHOW_GUILD = "In Historie-Fenster anzeigen",
  SETTINGS_SHOW_GUILD_TIP = "Diese Gilde im Historie-Suchfenster anzeigen",
  SETTINGS_CATEGORIES = "Anzuzeigende Ereigniskategorien",
  SETTINGS_ROSTER_EVENTS = "Listen-Ereignisse",
  SETTINGS_ROSTER_EVENTS_TIP = "Zeige Mitglieds-Beitritte, Austritte, Beförderungen, Kicks",
  SETTINGS_BANK_GOLD_EVENTS = "Bank-Gold-Ereignisse",
  SETTINGS_BANK_GOLD_EVENTS_TIP = "Zeige Gold-Einzahlungen, -Abhebungen, Händler-Gebote",
  SETTINGS_BANK_ITEMS_EVENTS = "Bank-Gegenstands-Ereignisse",
  SETTINGS_BANK_ITEMS_EVENTS_TIP = "Zeige Gegenstands-Einzahlungen und -Abhebungen",
  SETTINGS_SALES_EVENTS = "Verkaufs-Ereignisse",
  SETTINGS_SALES_EVENTS_TIP = "Zeige Gildenladen-Verkäufe",
  
  -- Dropdown
  DROPDOWN_NO_GUILDS = "Keine Gilden aktiviert - siehe Einstellungen",
  
  -- Formatting
  FORMAT_GOLD = "%s Gold",
  FORMAT_QUANTITY_ITEM = "%dx %s",
  FORMAT_SOLD_TO = "an %s",
  FORMAT_RANK_ARROW = "→",
  MANUAL_ENTRY_TOOLTIP = "Dies ist eine manuell protokollierte Spende",
  NOTES_LABEL = "Notizen",
  DELETE_MANUAL_ENTRY = "Diesen manuellen Eintrag löschen",
  SUCCESS_DELETED_ENTRY = "Manueller Eintrag erfolgreich gelöscht",
  ERROR_DELETE_FAILED = "Eintrag konnte nicht gelöscht werden",
  
  -- Member Names
  MEMBER_UNKNOWN = "Unbekannt",
    
  LOG_LIBSCROLL_NOT_FOUND = "|cFFD700[ScrollkeeperHistory]|r LibScroll nicht gefunden - verwende einfaches Scrollen",
}

--------------------------------------------------------------------------------
-- ROSTER
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperRoster"] = {
  -- Main
  SUBMENU_NAME = "Listen-Erweiterung",
  
  -- Settings
  SETTING_TRADER_TIMER = "Händler-Wechsel-Timer anzeigen",
  SETTING_TRADER_TIMER_TIP = "Zeige Countdown-Timer, der die Zeit bis zum nächsten Gildenhändler-Wechsel anzeigt.\n\n" ..
                              "Timer-Farbe zeigt Dringlichkeit:\n" ..
                              "• |c00FF0024+ Std.|r - Sicher\n" ..
                              "• |cFFFF006-24 Std.|r - Vorausplanen\n" ..
                              "• |cFF88002-6 Std.|r - Bald handeln\n" ..
                              "• |cFF0000< 2 Std.|r - Dringend!",
  
  -- Timer Display
  TIMER_LABEL = "Händler-Wechsel: %s",
  TIMER_FLIPPING = "Wechselt jetzt",
  TIMER_FORMAT = "%dh %dm",
  
  -- Full tooltip
  TOOLTIP_FULL = "Zeit bis Gildenhändler-Wechsel\n\n" ..
                 "Farbe zeigt Dringlichkeit:\n" ..
                 "|c00FF0024+ Stunden|r - Sicher\n" ..
                 "|cFFFF006-24 Stunden|r - Vorausplanen\n" ..
                 "|cFF88002-6 Stunden|r - Bald handeln\n" ..
                 "|cFF0000< 2 Stunden|r - Dringend!",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperRoster]|r FEHLER: ScrollkeeperFramework fehlt!",
  
  -- Tasks
  TASKS_HEADER = "Aufgabenerinnerungen",
  TASKS_DESCRIPTION = "Aufgabenerinnerungen werden unten pro Gilde konfiguriert. Aktiviere 'Aufgaben im Roster anzeigen' für jede Gilde, bei der du Erinnerungen möchtest.",
  CUSTOM_TASKS = "Benutzerdefinierte Aufgaben",
  CUSTOM_TASKS_DESC = "Füge benutzerdefinierte Aufgaben hinzu und konfiguriere sie. Das Einstellungsfenster wird erst nach einem Neuladen aktualisiert, aber die Aufgabe wird in Echtzeit hinzugefügt oder entfernt.",
  ADD_CUSTOM_TASK = "Benutzerdefinierte Aufgabe hinzufügen",
  REMOVE = "Entfernen",

  -- Per-guild task toggle
  GUILD_TASKS_ENABLE = "Aufgaben im Roster anzeigen",
  GUILD_TASKS_ENABLE_TIP = "Aufgabenerinnerungen für die Roster-Seite dieser Gilde aktivieren",

  -- Guild configuration header
  GUILD_CONFIG_DESC = "Aufgabenerinnerungen für %s konfigurieren",

  -- Preset tasks section
  PRESET_TASKS_HEADER = "Vordefinierte Aufgaben",

  -- Frequency settings
  FREQUENCY_NUMBER = "Häufigkeit (Zahl)",
  FREQUENCY_NUMBER_TIP = "Anzahl der Zeiteinheiten eingeben",
  FREQUENCY_UNIT = "Einheit",

  -- Task window
  TASK_WINDOW_TITLE = "Benutzerdefinierte Aufgabe hinzufügen",
  TASK_WINDOW_NAME_LABEL = "Aufgabenname:",
  TASK_WINDOW_FREQ_LABEL = "Häufigkeit:",
  TASK_WINDOW_GUILD_LABEL = "Gilden (mehrere auswählen oder 'Alle'):",
  TASK_WINDOW_ADD = "Aufgabe hinzufügen",
  TASK_WINDOW_CANCEL = "Abbrechen",

  -- Task window validation messages
  ERROR_NO_TASK_NAME = "Bitte gib einen Aufgabennamen ein",
  ERROR_INVALID_FREQ_NUMBER = "Bitte gib eine gültige Zahl für die Häufigkeit ein",
  ERROR_NO_FREQ_UNIT = "Bitte wähle eine Häufigkeitseinheit aus",

  -- Task completion messages
  TASK_COMPLETED = "Aufgabe abgeschlossen: %s",
  TASK_ADDED = "Aufgabe hinzugefügt: %s (Gilde: %s, aktiviert: wahr, istBenutzerdefiniert: wahr)",
  TASK_REMOVED = "Aufgabe entfernt: %s",
  ERROR_PRESET_REMOVE = "Vordefinierte Aufgaben können nicht entfernt werden. Deaktiviere sie stattdessen in den Einstellungen.",

  -- Task list display
  TASK_STATUS_OVERDUE = "ÜBERFÄLLIG",

  -- Tooltip for task labels
  TASK_TOOLTIP_LEFT = "Linksklick: Aufgabe abschließen",
  TASK_TOOLTIP_RIGHT = "Rechtsklick: Aufgabe entfernen",

  PRESET_REVIEW_APPLICATIONS = "Bewerbungen prüfen",
  PRESET_CHECK_BANK_DEPOSITS = "Bankeinlagen überprüfen",
  PRESET_UPDATE_MOTD = "Nachricht des Tages aktualisieren",
  PRESET_PROMOTE_PROBATIONARY = "Probemitglieder befördern",
  PRESET_REVIEW_INACTIVES = "Inaktive überprüfen",

  TASK_COLOR_LEGEND = "Farblegende - Verbleibende Zeit:\n|c00FF00>25%|r - Sicher\n|cFFFF0010-25%|r - Vorausplanen\n|cFF88005-10%|r - Bald handeln\n|cFF0000<5% oder überfällig|r - Dringend!",
    
  -- Remove Button
  REMOVE_CUSTOM_TASK = "Benutzerdefinierte Aufgabe Entfernen",
  REMOVE_CUSTOM_TASK_TIP = "Wähle eine benutzerdefinierte Aufgabe zum dauerhaften Entfernen aus",
  REMOVE_WARNING = "WARNUNG: Das Entfernen ist dauerhaft! Um eine Aufgabe wiederherzustellen, musst du sie manuell erneut hinzufügen.",
  REMOVE_INSTRUCTION = "Klicke unten auf eine Aufgabe, um sie zu entfernen:",
  REMOVE_WINDOW_CANCEL = "Abbrechen",
}

--------------------------------------------------------------------------------
-- CONTEXT MENU
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperContextMenu"] = {
  SUBMENU_NAME = "Kontextmenü-Optionen",
  DESCRIPTION = "Fügt Neue-Mail-, Gilden-Einladungs- und Chat-Einladungs-Einträge zu allen Rechtsklick-Kontextmenüs hinzu.",
  MASTER_ENABLE = "Kontextmenü-Funktionen aktivieren",
  MASTER_ENABLE_TIP = "Hauptschalter für alle Kontextmenü-Erweiterungen.",
  SF_UNAVAILABLE = "FEHLER: ScrollkeeperFramework fehlt!",
  
  -- Headers
  SCROLLKEEPER_TOOLS = "Scrollkeeper-Tools",
  CHAT_HEADER = "Chat-Optionen",
  ROSTER_HEADER = "Gildenlisten-Optionen",
  
  -- Options
  NEW_MAIL = "Neue Mail",
  NEW_MAIL_TIP = "Füge 'Neue Mail'-Option zu Chat-Kontextmenüs hinzu.",
  GUILD_INVITE = "Gilden-Einladung",
  GUILD_INVITE_TIP = "Füge Gilden-Einladungs-Optionen zu Chat-Kontextmenüs hinzu.",
  ROSTER_DESC = "Fügt Notizbuch-Integration zum Gildenlisten-Rechtsklickmenü hinzu.",
  NOTEBOOK_CONTEXT = "Notizbuch-Kontextmenü aktivieren",
  NOTEBOOK_CONTEXT_TIP = "Rechtsklicke Gildenmitglieder, um Notizbuch-Einträge zu öffnen oder zu erstellen.",
  ROSTER_INVITE = "Gilden-Einladung von Liste",
  ROSTER_INVITE_TIP = "Füge Gilden-Einladungs-Optionen zu Gildenlisten-Kontextmenüs hinzu.",
  
  -- Context Menu Items
  INVITE_TO = "Einladen zu %s",
  GO_TO_NOTEBOOK = "Zu Notizbuch-Eintrag gehen",
  MAKE_NOTE = "Notizbuch-Notiz erstellen",
  
  -- Messages
  NOTEBOOK_NOT_FOUND = "Notizbuch-Modul nicht gefunden.",
  NOTE_EXISTS = "Notiz existiert bereits für %s.",
  NOTE_CREATED = "Notiz für %s im Notizbuch erstellt.",
  OPEN_NOTE = "Notizbuch-Eintrag öffnen",
  CREATE_NOTE = "Notizbuch-Notiz erstellen",
  LOG_CONVERSATION = "Neueste Chat-Protokolle",
  CONVERSATION_LOGGED = "%d aktuelle Nachrichten mit %s im Notizbuch unter der Kategorie 'Chat' protokolliert",
  NO_CONVERSATION = "Keine neuesten Chats mit %s in den letzten 100 Nachrichten gefunden.",
  LOG_CONVERSATIONS = "Gesprächsprotokollierung aktivieren",
  LOG_CONVERSATIONS_TIP = "Protokolliere Chat-Gespräche ins Notizbuch (erfordert pChat-Addon).",
  PCHAT_WARNING = "pChat-Addon nicht erkannt - diese Funktion wird nicht funktionieren",
  
  -- Mail Logging
  LOG_DONATION = "Spende Protokollieren",
  LOG_DONATION_TIP = "Eine Spende für diesen Spieler manuell aufzeichnen",
  DONATION_WINDOW_TITLE = "Manuelle Spende Protokollieren",
  DONATION_PLAYER = "Spieler",
  DONATION_GUILD = "Gilde",
  DONATION_VALUE_LABEL = "Goldwert",
  DONATION_VALUE_TIP = "Geben Sie den Goldwert dieser Spende ein (für Gegenstände, geben Sie ihren geschätzten Wert ein)",
  DONATION_NOTES_LABEL = "Notizen (Optional)",
  DONATION_NOTES_TIP = "Zusätzliche Details wie '50 Dreugh-Wachs per Post gesendet' oder 'Gold gesendet am 25.12.'",
  DONATION_TYPE_LABEL = "Spendenart",
  DONATION_TYPE_GOLD = "Gold (Post)",
  DONATION_TYPE_ITEMS = "Gegenstände (Bewertet)",
  BTN_RECORD_DONATION = "Spende Aufzeichnen",
  BTN_CANCEL = "Abbrechen",
  SUCCESS_DONATION_LOGGED = "Spende von %d Gold für %s protokolliert",
  ERROR_INVALID_AMOUNT = "Bitte geben Sie einen gültigen Goldbetrag ein",
}

--------------------------------------------------------------------------------
-- DATA MODULE
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperData"] = {
  -- Module Info
  DESCRIPTION = "Hintergrund-Caching-Dienst für Gildenhistorie-Daten mit LibHistoire.",
  
  -- Status Messages
  HISTOIRE_READY = "LibHistoire bereit - cacht gesamte Gildenhistorie",
  CACHE_STATUS = "=== Ereignis-Cache-Status ===",
  NO_CACHED_DATA = "Keine zwischengespeicherten Daten gefunden",
  CACHE_EMPTY = "Cache ist leer - dies kann beim ersten Laden einige Minuten dauern",
  WAITING_FOR_HISTOIRE = "Warte auf LibHistoire-Initialisierung...",
  
  -- Log Messages
  EVENTS_CACHED = "%s/%s: %d Ereignisse zwischengespeichert",
  STARTED_CACHING = "Caching von %d Gilden gestartet",
  MODULE_LOADED = "|cFFD700[ScrollkeeperData]|r Geladen - Hintergrund-Caching-Dienst",
  LOG_MANUAL_DONATION = "%s - %d Gold manuell protokolliert",
  MANUAL_DONATION_SOURCE = "Manueller Eintrag",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperData]|r FEHLER: ScrollkeeperFramework fehlt!",
  ERROR_DATA_NOT_TABLE = "|cFFD700[ScrollkeeperData]|r KRITISCH: SF.Data ist keine Tabelle!",
  ERROR_HISTOIRE_NOT_FOUND = "|cFFD700[ScrollkeeperData]|r FEHLER: LibHistoire nicht gefunden!",
  
  -- Cache Display
  GUILD_HEADER = "%s:",
  CATEGORY_LINE = "  %s: %d Ereignisse",
  HISTOIRE_STATUS = "LibHistoire bereit: %s",
  
  -- Category Names (for display)
  CAT_ROSTER = "liste",
  CAT_BANKED_GOLD = "bankGold",
  CAT_BANKED_ITEMS = "bankGegenstände",
  CAT_SALES = "verkäufe",
  
  -- Manual donation logging
  LOG_MANUAL_DONATION = "|cFFD700[ScrollkeeperData]|r Protokolliert: %d Gold von %s an %s",
  
  -- Delete entry messages
  ERROR_DELETE_MISSING_PARAMS = "|cFFD700[ScrollkeeperData]|r deleteManualEntry: Erforderliche Parameter fehlen",
  SUCCESS_DELETE_ENTRY = "|cFFD700[ScrollkeeperData]|r Manueller Eintrag erfolgreich aus Cache und Speicher gelöscht",
  ERROR_DELETE_NOT_FOUND = "|cFFD700[ScrollkeeperData]|r deleteManualEntry: Eintrag nicht gefunden",
  
  -- Debug cache messages
  DEBUG_NO_GUILD = "[Daten-Debug] Keine Gilde angegeben",
  DEBUG_NO_CACHE_FOR_GUILD = "[Daten-Debug] Kein Cache für Gilde: %s",
  DEBUG_AVAILABLE_GUILDS = "[Daten-Debug] Verfügbare Gilden:",
  DEBUG_GUILD_LIST_ITEM = "  - %s",
  DEBUG_CACHE_FOR_GUILD = "[Daten-Debug] Cache für %s:",
  DEBUG_BANKED_GOLD_COUNT = "  bankedGold: %d Ereignisse",
  DEBUG_RECENT_DEPOSITS = "  Letzte Einzahlungen:",
  DEBUG_NO_DEPOSITS = "  Keine Einzahlungen gefunden",
  DEBUG_BANKED_GOLD_MISSING = "  bankedGold: NICHT VORHANDEN",
  DEBUG_ROSTER_COUNT = "  roster: %d Ereignisse",
  DEBUG_ROSTER_MISSING = "  roster: NICHT VORHANDEN",
  
  -- Slash command messages
  ERROR_DATA_MODULE_UNAVAILABLE = "Datenmodul oder Prüffunktion nicht verfügbar",
  CMD_CHECKGOLD_USAGE = "Verwendung: /sgtcheckgold Gildenname|@Anzeigename|Tage",
  CMD_CHECKGOLD_EXAMPLE = "Beispiel: /sgtcheckgold Dragon's Nest Thievery Co|@DeinName|14",
  CMD_CHECKGOLD_RESULT = "%s hat %d Gold in den letzten %d Tagen gespendet (%s)",
  
  -- Initialization
  ERROR_LIBHISTOIRE_MISSING = "|cFFD700[ScrollkeeperData]|r FEHLER: LibHistoire nicht gefunden",
}

--------------------------------------------------------------------------------
-- WELCOME MESSAGES
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperWelcome"] = {
  SUBMENU_NAME = "Willkommensnachrichten",
  DESCRIPTION = "Konfiguriere Willkommensnachrichten für Gildenmitglieder. Verwende %1 für Spielername und %2 für Gildenname. Nachrichten werden in die Warteschlange gestellt, wenn mehrere Bewerbungen akzeptiert werden oder das Textfeld aktiv ist.",
  MASTER_ENABLE = "Willkommensnachrichten aktivieren",
  MASTER_ENABLE_TIP = "Schalte alle Willkommensnachrichten ein oder aus.",
  LOG_MEMBER_JOINED = "|cFFD700[ScrollkeeperWelcome]|r %s ist %s als %s beigetreten",
  
  -- Template
  TEMPLATE_HEADER = "Vorlagen-Variablen",
  VAR_PLAYER = "%1 - Spielername",
  VAR_GUILD = "%2 - Gildenname",
  
  -- Guild Settings
  ENABLE_FOR_GUILD = "Für diese Gilde aktivieren",
  MESSAGE_TEMPLATE = "Nachrichtenvorlage",
  PREVIEW = "Vorschau: %s",
  DEFAULT_MESSAGE = "Willkommen %1 bei %2",
}

--------------------------------------------------------------------------------
-- STANDARD COMMANDS
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperStandardCommands"] = {
  -- Main
  SUBMENU_NAME = "Chat-Befehle & Dienstprogramme",
  DESCRIPTION = "Zusätzliche Dienstprogramm-Befehle und Tastenbelegungsunterstützung für Scrollkeeper.",
  
  -- Headers
  COMMANDS_HEADER = "Verfügbare Befehle",
  UTILITY_HEADER = "Dienstprogramm-Befehle",
  STATUS_HEADER = "Status-Befehle",
  MODULE_HEADER = "Modul-Befehle",
  DEBUG_HEADER = "Debug-Befehle",
  
  -- Command Documentation
  CMD_SKDEBUG = "|cf3ebd1/skdebug|r - Zeige System-Debug-Informationen",
  CMD_SKTEST = "|cf3ebd1/sktest <option>|r - Führe Modul-Tests aus (Optionen: context, settings, notebook, mail, data)",
  CMD_SGTNOTE = "|cf3ebd1/sgtnote|r - Notizbuch-Fenster umschalten",
  CMD_SGTMAIL = "|cf3ebd1/sgtmail|r - Mail-Fenster öffnen",
  CMD_SGTHISTORY = "|cf3ebd1/sgthistory|r - Historie-Suchfenster öffnen",
  CMD_SGTPROVISION = "|cf3ebd1/sgtprovision|r - Probemitglieder-Fenster öffnen",
  CMD_SGTCACHE = "|cf3ebd1/sgtcache|r - Ereignis-Cache-Status anzeigen",
  CMD_ROLL = "|cf3ebd1/roll <zahl>|r - Würfel werfen (Beispiel: /roll 20)",
  CMD_DICE = "|cf3ebd1/dice <zahl>|r - Wie /roll",
  CMD_RL = "|cf3ebd1/rl|r - UI neu laden",
  CMD_ON = "|cf3ebd1/on|r - Status auf Online setzen",
  CMD_OFF = "|cf3ebd1/off|r - Status auf Offline setzen",
  CMD_AFK = "|cf3ebd1/afk|r - Status auf Abwesend setzen",
  CMD_DND = "|cf3ebd1/dnd|r - Status auf Nicht stören setzen",
  CMD_OFFL = "|cf3ebd1/offl|r - Online/Offline umschalten",
  
  -- Full command list
  COMMAND_LIST = "|cf3ebd1/sgtnote|r - Notizbuch-Fenster umschalten\n" ..
                "|cf3ebd1/sgtmail|r - Mail-Fenster öffnen\n" ..
                "|cf3ebd1/sgthistory|r - Historie-Suche öffnen\n" ..
                "|cf3ebd1/sgtprovision|r - Probemitglieder-Fenster öffnen\n" ..
                "|cf3ebd1/roll <zahl>|r - Würfel werfen\n" ..
                "|cf3ebd1/rl|r - UI neu laden\n" ..
                "|cf3ebd1/on /off /afk /dnd|r - Spielerstatus setzen\n" ..
                "|cf3ebd1/offl|r - Offline umschalten\n" ..
                "|cf3ebd1/skdebug|r - Debug-Info anzeigen\n" ..
                "|cf3ebd1/sgtcache|r - Cache-Status anzeigen",
				"|cf3ebd1/sgtcheckpm Gildenname|@Anzeigename|r - Debug-Goldspendenprüfung für bestimmtes Mitglied\n" ..
				"|cf3ebd1/sgtattendance start [Eventname]|r - Tracking starten\n" ..
				"|cf3ebd1/sgtattendance stop|r - Stoppen und Bericht speichern\n" ..
				"|cf3ebd1/sgtattendance status|r - Aktuelle Sitzungsinformationen anzeigen" ..
				"|cf3ebd1/sgttask add <name>|<häufigkeit>|<gilde>|r um eine benutzerdefinierte Aufgabe hinzuzufügen" ..
				"|cf3ebd1/sgttask list|r - Alle Aufgaben mit Status anzeigen" ..
				"|cf3ebd1/sgttask complete <nummer>|r - Aufgabe als abgeschlossen markieren",
  
  -- Buttons
  TEST_BUTTON = "Alle Systeme testen",
  TEST_BUTTON_TIP = "Führe einen umfassenden Test aller Scrollkeeper-Module durch",
  
  -- Status Messages
  STATUS_ONLINE = "Status auf Online gesetzt",
  STATUS_OFFLINE = "Status auf Offline gesetzt",
  STATUS_DND = "Status auf Nicht stören gesetzt",
  STATUS_AWAY = "Status auf Abwesend gesetzt",
  STATUS_CHANGED = "Scrollkeeper: Status auf %s gesetzt",
  STATUS_TOGGLED = "Notizbuch-Fenster umgeschaltet",
  
  -- Roll Messages
  ROLL_USAGE = "Verwendung: /roll <max>",
  ROLL_EXAMPLE = "Beispiel: /roll 20",
  ROLL_INVALID = "Ungültige Zahl: %s",
  ROLL_OUTPUT = "würfelte %d (1-%d)",
  
  -- Debug Messages
  DEBUG_HEADER = "=== Scrollkeeper Debug-Info ===",
  DEBUG_FRAMEWORK = "Framework geladen: %s",
  DEBUG_SETTINGS = "Einstellungen-Tabelle: %s",
  DEBUG_LAM = "LAM2 verfügbar: %s",
  DEBUG_FUNC = "SF.func verfügbar: %s",
  DEBUG_GET_SETTINGS = "SF.getModuleSettings: %s",
  DEBUG_PANEL = "Panel registriert: %s",
  DEBUG_MODULE = "Modul: %s - Steuerelemente: %d - Icon: %s",
  DEBUG_TOTAL_MODULES = "Gesamt registrierte Module: %d",
  DEBUG_NO_MODULES = "Keine Modul-Einstellungen gefunden",
  DEBUG_CONTEXT = "Kontextmenü aktiviert: %s",
  DEBUG_NOTEBOOK = "Notizbuch-Modul: %s",
  DEBUG_DATA = "Daten-Modul: %s",
  DEBUG_HISTOIRE = "LibHistoire: %s",
  DEBUG_DATETIME = "LibDateTime: %s",
  
  -- Test Messages
  TEST_HEADER = "=== Scrollkeeper Test-Befehle ===",
  TEST_USAGE = "Verwendung: /sktest <option>",
  TEST_OPTIONS = "Optionen: context, settings, notebook, mail, data, attendance",
  TEST_RUNNING = "Führe umfassenden Systemtest aus...",
  TEST_UNKNOWN = "Unbekannte Test-Option: %s",
  TEST_AVAILABLE = "Verfügbare Optionen: context, settings, notebook, mail, data, attendance",
  
  -- Test: Context
  TEST_CONTEXT_HEADER = "=== Kontextmenü-Test ===",
  TEST_CONTEXT_ACTIVE = "Kontextmenü-Hook ist aktiv",
  TEST_CONTEXT_ENABLED = "Kontextmenü in Einstellungen aktiviert: %s",
  TEST_CONTEXT_MAIL = "Chat-Neue-Mail-Option: %s",
  TEST_CONTEXT_INVITE = "Chat-Einladungs-Option: %s",
  TEST_CONTEXT_NOT_LOADED = "ScrollkeeperContextMenu-Modul nicht geladen",
  TEST_CONTEXT_FAILED = "Kontextmenü-Hook FEHLGESCHLAGEN - CHAT_SYSTEM nicht verfügbar",
  
  -- Test: Settings
  TEST_SETTINGS_HEADER = "=== Einstellungen-Test ===",
  TEST_SETTINGS_ACCESSIBLE = "%s Einstellungen erreichbar: %s",
  TEST_SETTINGS_PANEL = "Einstellungs-Panel ist registriert",
  TEST_SETTINGS_NO_PANEL = "Einstellungs-Panel nicht registriert",
  TEST_SETTINGS_NO_ACCESS = "Kann nicht auf Modul-Einstellungen zugreifen - Framework-Problem",
  
  -- Test: Notebook
  TEST_NOTEBOOK_HEADER = "=== Notizbuch-Test ===",
  TEST_NOTEBOOK_LOADED = "Notizbuch-Modul geladen",
  TEST_NOTEBOOK_ENABLED = "Aktiviert: %s",
  TEST_NOTEBOOK_WINDOW = "Notizbuch-Fenster existiert: %s",
  TEST_NOTEBOOK_SAVE = "Test-Notiz-Speicherung: %s",
  TEST_NOTEBOOK_NOT_LOADED = "Notizbuch-Modul nicht geladen",
  
  -- Test: Mail
  TEST_MAIL_HEADER = "=== Mail-Modul-Test ===",
  TEST_MAIL_LOADED = "Mail-Modul geladen",
  TEST_MAIL_ENABLED = "Aktiviert: %s",
  TEST_MAIL_WINDOW = "Mail-Fenster existiert: %s",
  TEST_MAIL_COMMAND = "/sgtmail Befehl registriert",
  TEST_MAIL_NO_COMMAND = "/sgtmail Befehl nicht registriert",
  TEST_MAIL_NOT_LOADED = "Mail-Modul nicht geladen",
  
  -- Test: Data
  TEST_DATA_HEADER = "=== Daten-Modul-Test ===",
  TEST_DATA_LOADED = "Daten-Modul geladen",
  TEST_DATA_LH_AVAILABLE = "LibHistoire verfügbar",
  TEST_DATA_CACHE_ACCESSIBLE = "Ereignis-Cache erreichbar: %s",
  TEST_DATA_RECORDS = "Gesamt zwischengespeicherte Ereignis-Datensätze: %d",
  TEST_DATA_NO_FUNCTIONS = "Daten-Funktionen nicht verfügbar",
  TEST_DATA_NO_LH = "LibHistoire nicht verfügbar",
  TEST_DATA_NOT_LOADED = "Daten-Modul nicht geladen",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperStandardCommands]|r FEHLER: ScrollkeeperFramework fehlt!",
  ERROR_NOTEBOOK_DISABLED = "Notizbuch ist in Einstellungen deaktiviert",
  ERROR_NOTEBOOK_NO_WINDOW = "Notizbuch-Fenster nicht verfügbar",
  ERROR_NOTEBOOK_NOT_LOADED = "Notizbuch-Modul nicht geladen",
  
  -- Log Messages
  LOG_REGISTERING = "|cFFD700[ScrollkeeperStandardCommands]|r Registriere Slash-Befehle...",
  LOG_REGISTERED = "|cFFD700[ScrollkeeperStandardCommands]|r Slash-Befehle registriert",
  LOG_INITIALIZING = "|cFFD700[ScrollkeeperStandardCommands]|r Initialisiere...",
  LOG_COMPLETE = "|cFFD700[ScrollkeeperStandardCommands]|r Initialisierung abgeschlossen",
}

--------------------------------------------------------------------------------
-- ATTENDANCE
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperAttendance"] = {
  -- Module info
  SUBMENU_NAME = "Event-Anwesenheit",
  
  -- Description
  DESCRIPTION = "Event-Anwesenheit mit automatischer Verspätungs-/Früherkennungserkennung verfolgen.",
  
  -- Settings
  MASTER_ENABLE = "Event-Anwesenheitsverfolgung Aktivieren",
  MASTER_ENABLE_TIP = "Anwesenheitsverfolgungsfunktionen und -befehle aktivieren",
  
  -- Headers
  HEADER_COMMANDS = "Befehle & Verwendung",
  HEADER_HISTORY = "Sitzungsverlauf",
  
  -- Command help
  COMMANDS_DESC = "/sgtattendance start [Name] - Tracking beginnen\n/sgtattendance stop - Beenden und speichern\n/sgtattendance status - Aktuelle Sitzung überprüfen",
  
  -- Help text (for /attendance help)
  HELP_HEADER = "=== Anwesenheitsverfolgungsbefehle ===",
  HELP_START = "/sgtattendance start [Eventname] - Tracking starten",
  HELP_STOP = "/sgtattendance stop - Stoppen und Bericht speichern",
  HELP_STATUS = "/sgtattendance status - Aktuelle Sitzungsinformationen anzeigen",
  
  -- Success messages
  SUCCESS_TRACKING_STARTED = "Tracking gestartet: %s (%d Mitglieder anwesend)",
  SUCCESS_TRACKING_STOPPED = "Tracking gestoppt: %s",
  SUCCESS_SAVED_TO_NOTEBOOK = "Anwesenheitsbericht im Notizbuch unter Kategorie 'Ereignisse' als '%s' gespeichert",
  SUCCESS_HISTORY_CLEARED = "Anwesenheitsverlauf gelöscht",
  
  -- Error messages
  ERROR_ALREADY_TRACKING = "Es wird bereits ein Event verfolgt! Verwenden Sie zuerst /sgtattendance stop.",
  ERROR_NO_ACTIVE_SESSION = "Keine aktive Tracking-Sitzung",
  ERROR_UNKNOWN_COMMAND = "Unbekannter Befehl. Verwenden Sie /sgtattendance help",
  ERROR_NOT_SAVED = "Warnung: Konnte nicht im Notizbuch gespeichert werden",
  ERROR_NOTEBOOK_DISABLED = "Notizbuch nicht verfügbar - Bericht nur im Anwesenheitsverlauf gespeichert",
  
  -- Status messages
  STATUS_NO_SESSION = "Keine aktive Tracking-Sitzung",
  STATUS_ACTIVE = "Tracking: %s | Dauer: %d Min. | Teilnehmer: %d",
  
  -- Real-time log messages
  LOG_MEMBER_JOINED = "%s ist dem Event beigetreten (%d Minuten zu spät)",
  LOG_MEMBER_LEFT = "%s hat das Event verlassen (anwesend für %d Minuten)",
  
  -- Report sections
  REPORT_HEADER = "Anwesenheitsbericht: %s",
  REPORT_TIME = "Zeit: %s bis %s",
  REPORT_SUMMARY = "Gesamtteilnehmer: %d | Vollständige Anwesenheit: %d | Verspätete Ankünfte: %d | Früh Gegangen: %d",
  
  SECTION_FULL_ATTENDANCE = "Vollständige Anwesenheit",
  SECTION_ON_TIME = "Pünktlich",
  SECTION_LATE = "Verspätete Ankünfte",
  SECTION_LEFT_EARLY = "Früh Gegangen",
  
  -- History display
  NO_SESSIONS = "Noch keine verfolgten Sitzungen",
  SESSIONS_COUNT = "Verfolgte Sitzungen: %d",
  
  -- Settings buttons
  BTN_CLEAR_HISTORY = "Verlauf Löschen",
  BTN_CLEAR_HISTORY_TIP = "Alle gespeicherten Anwesenheitssitzungen entfernen",
  WARNING_CLEAR_HISTORY = "Dies wird alle Anwesenheitsaufzeichnungen dauerhaft löschen!",
}

--------------------------------------------------------------------------------
-- APPLICATIONS
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperApplications"] = {
  -- Module info
  SUBMENU_NAME = "Gildenbewerbungen",
  DESCRIPTION = "Protokolliert automatisch Gildenbewerbungen in Ihrem Notizbuch zur Aufzeichnung. Bewerbungen werden mit vollständigen Details einschließlich der Nachricht des Bewerbers gespeichert.",
  
  -- Settings
  MASTER_ENABLE = "Bewerbungsprotokollierung Aktivieren",
  MASTER_ENABLE_TIP = "Hauptschalter für die Bewerbungsprotokollierungsfunktion",
  AUTO_LOG = "Neue Bewerbungen Automatisch Protokollieren",
  AUTO_LOG_TIP = "Wenn aktiviert, werden neue Gildenbewerbungen automatisch im Notizbuch gespeichert",
  SHOW_NOTIFICATIONS = "Chat-Benachrichtigungen Anzeigen",
  SHOW_NOTIFICATIONS_TIP = "Eine Nachricht im Chat anzeigen, wenn Bewerbungen protokolliert werden",
  
  -- Guild settings
  HEADER_GUILDS = "Einstellungen pro Gilde",
  GUILDS_DESC = "Wählen Sie aus, für welche gilden bewerbungen protokolliert werden sollen:",
  GUILD_TOGGLE_TIP = "Bewerbungen für %s protokollieren",
  
  -- Errors
  ERROR_NOTEBOOK_UNAVAILABLE = "|cFFD700[ScrollkeeperApplications]|r Notizbuch-Modul ist nicht verfügbar. Bewerbungen können nicht protokolliert werden.",
  WARNING_NOTEBOOK_MISSING = "|cFFD700[ScrollkeeperApplications]|r WARNUNG: Notizbuch-Modul nicht geladen. Bewerbungsprotokollierung funktioniert nicht.",
  
  SUCCESS_LOGGED_SINGLE = "|cFFD700[ScrollkeeperApplications]|r Bewerbung von |cFFD700%s|r für |cFFD700%s|r protokolliert",
  ERROR_SAVE_FAILED = "|cFF5555[ScrollkeeperApplications]|r Speichern der Bewerbung von %s fehlgeschlagen",
  SUCCESS_LOGGED_MULTIPLE = "|cFFD700[ScrollkeeperApplications]|r %d bewerbungen für |cFFD700%s|r protokolliert",
}
-- Backward compatibility (DEPRECATED)
_G.Scrollkeeper.Localization = Scrollkeeper.Localization