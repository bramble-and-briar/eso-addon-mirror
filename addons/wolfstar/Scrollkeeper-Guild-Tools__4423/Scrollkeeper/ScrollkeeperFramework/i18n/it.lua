Scrollkeeper = Scrollkeeper or {}
Scrollkeeper.Localization = Scrollkeeper.Localization or {}

--------------------------------------------------------------------------------
-- FRAMEWORK CORE
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperFramework"] = {
  FRAMEWORK_LOADED = "Scrollkeeper Framework caricato con successo",
  CRITICAL_ERROR = "ERRORE CRITICO: Impossibile creare il pannello delle impostazioni!",
  ERROR_REGISTERING = "ERRORE durante la registrazione delle impostazioni",
  LAM2_UNAVAILABLE = "LibAddonMenu2 non disponibile!",
  ALREADY_INITIALIZED = "Già inizializzato, saltando...",
  CHAT_BUTTONS_DISABLED = "LibChatMenuButton non disponibile - pulsanti chat disabilitati",
  HEADER_DESC = "Framework centrale per Scrollkeeper Guild Tools con integrazioni di libreria migliorate. I singoli moduli hanno le proprie impostazioni e non richiedono ricaricamento.",
  DONATE_BUTTON = "Sostieni lo Sviluppo",
  DONATE_TOOLTIP = "Invia una donazione a @WolfStar07 su PC/NA per sostenere lo sviluppo continuo",
  OPEN_ALL_WINDOWS = "Apri Tutte le Finestre Scrollkeeper",
  OPEN_SETTINGS = "Apri Impostazioni Scrollkeeper",
  DISPLAY_NAME = "|cF5DA81Scrollkeeper Guild Tools|r",
}

--------------------------------------------------------------------------------
-- COLOR THEMES
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperColorThemes"] = {
  -- Main
  SUBMENU_NAME = "Temi Colore",
  DESCRIPTION = "Scegli tra temi colore predefiniti per gli elementi dell'interfaccia di Scrollkeeper.",
  ACTIVE_THEME = "Tema Attivo",
  ACTIVE_THEME_TOOLTIP = "Seleziona quale tema colore applicare agli elementi dell'interfaccia di Scrollkeeper.",
  CURRENT_THEME = "Tema attuale: %s",
  
  -- Preview Section
  PREVIEW_HEADER = "Anteprima Colori:",
  BORDER_COLOR = "Colore Bordo",
  BORDER_DESC = "Bordi e margini delle finestre",
  HEADER_COLOR = "Colore Intestazione",
  HEADER_DESC = "Barre del titolo e intestazioni delle colonne",
  TEXT_COLOR = "Colore Testo", 
  TEXT_DESC = "Testo principale ed etichette",
  ACCENT_COLOR = "Colore Accento",
  ACCENT_DESC = "Pulsanti evidenziati e selezioni",
  NOTE = "Nota: Le modifiche al tema si applicano immediatamente a tutte le finestre Scrollkeeper aperte.",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperColorThemes]|r ERRORE: ScrollkeeperFramework mancante!",
  
  -- Theme Names
  THEME_EMBER = "Brace",
  THEME_FORGE = "Fucina",
  THEME_OCEAN = "Oceano",
  THEME_SKY = "Cielo",
  THEME_REGALIA = "Regalia",
  THEME_BRIAR = "Rovo",
  THEME_JUNGLE = "Giungla",
  
  -- Status Messages
  STATUS_UNKNOWN = "Sconosciuto",
}

--------------------------------------------------------------------------------
-- PROVISIONAL MEMBER TRACKING
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperProvisionMember"] = {
  SUBMENU_NAME = "Tracciamento Membri Provvisori",
  DESCRIPTION = "Traccia i membri della gilda in gradi di prova e quelli che non soddisfano i requisiti di donazione. Usa |cFFD700/sgtprovision|r per aprire la finestra di gestione.",
  MASTER_ENABLE = "Attiva Tracciamento Membri Provvisori (Master)",
  MASTER_ENABLE_TIP = "Interruttore principale per tutte le funzioni di tracciamento membri provvisori.",
  OPEN_ADMIN = "Apri Finestra Admin",
  OPEN_ADMIN_TIP = "Apri la finestra di gestione membri provvisori",
  CLEAR_SCAN = "Cancella Dati Errati e Scansiona",
  CLEAR_SCAN_TIP = "Cancella i membri tracciati in modo errato e scansiona per nuovi",
  RESET_GOLD = "Ripristina Rimozioni Oro",
  RESET_GOLD_TIP = "Cancella tutti i flag di rimozione basati sull'oro, permettendo ai membri di essere rivalutati per il tracciamento oro",
  STATUS_TRACKING = "Attualmente tracciati: %d membri provvisori attivi",
  STATUS_RANK_REMOVED = "Rimossi permanentemente (grado): %d membri",
  STATUS_GOLD_REMOVED = "Rimossi temporaneamente (oro): %d membri",
  WINDOW_OPENED_MESSAGE = "Finestra aperta. Usa il pulsante |cFFFFFFScansiona|r per controllare i membri che necessitano di monitoraggio.",
    
  -- Window UI
  WINDOW_TITLE = "Gestione Membri Provvisori",
  SELECT_GUILD = "Seleziona Gilda:",
  FILTER_LABEL = "Filtro:",
  MEMBER_NAME = "Nome Membro",
  DAYS = "Giorni",
  STATUS = "Stato Tracciamento",
  NOTES = "Note",
  ACTIONS = "Azioni",
    
  -- Guild Settings
  ENABLE_FOR_GUILD = "Attiva per %s",
  ENABLE_FOR_GUILD_TIP = "Attiva il tracciamento membri provvisori per questa gilda.",
  AUTO_TAG = "Tagga Automaticamente Nuovi Membri",
  AUTO_TAG_TIP = "Tagga automaticamente i membri che soddisfano i criteri di tracciamento.",
  NOTIFY_JOIN = "Notifica Quando si Uniscono Membri",
  NOTIFY_JOIN_TIP = "Mostra notifiche per nuovi membri in questa gilda.",
  PROBATION_DAYS = "Periodo di Prova (Giorni)",
  PROBATION_DAYS_TIP = "Quanti giorni i membri rimangono in stato di prova prima della promozione.",
    
  -- Gold Tracking
  GOLD_HEADER = "Monitoraggio Requisiti Oro",
  INACTIVITY_HEADER = "Monitoraggio Inattività",
  DONOR_HEADER = "Riconoscimento Donatori",
  GOLD_ENABLE = "Attiva Filtro Donazione Oro",
  GOLD_ENABLE_TIP = "Traccia i membri che non hanno soddisfatto i requisiti di donazione.",
  GOLD_AMOUNT = "Importo Donazione Richiesto",
  GOLD_AMOUNT_TIP = "Quantità d'oro che i membri devono donare nel periodo di tempo (es. 5000 per quote di 5k).",
  GOLD_PERIOD = "Periodo di Tempo (Giorni)",
  GOLD_PERIOD_TIP = "Numero di giorni per verificare le donazioni (es. 30 per quote mensili, 7 per settimanali).",
  STATUS_PENDING_DONATION = "Donazione in Sospeso",
  SOURCE_MANUAL = "Manuale",
  TIP_DAYS_MANUAL = "^ = Include voci di donazioni manuali",
    
  -- Statistics
  GUILD_STATS = "Statistiche Gilda",
  NO_MEMBERS = "Nessun membro provvisorio attualmente tracciato per questa gilda",
  STATS_FORMAT = "Tracciamento di %d membri: %d attivi, %d in ritardo, %d promossi",
  RECENT_ADDITIONS = "Aggiunte recenti (ultimi 7 giorni): %d",
    
  -- Integration Status
  INTEGRATION_HEADER = "Fonti Dati Tempo di Adesione e Integrazione",
  AMT_AVAILABLE = "Advanced Member Tooltip - Tempi di adesione più accurati disponibili",
  AMT_UNAVAILABLE = "Advanced Member Tooltip - Non installato",
  AMT_INSTALL = "Installa da: esoui.com/downloads/info2351",
  AMT_DESC = "Fornisce il tracciamento più accurato del tempo di adesione alla gilda",
  LH_READY = "LibHistoire - Pronto e elaborazione cronologia gilda",
  LH_MISSING = "LibHistoire - Non trovato (dipendenza richiesta)",
  DATA_AVAILABLE = "Modulo Dati - Tracciamento donazioni oro attivato",
  DATA_UNAVAILABLE = "Modulo Dati - Filtraggio oro non disponibile",
    
  -- Symbol Legend
  SYMBOL_LEGEND = "Simboli Colonna Giorni:",
  SYMBOL_AMT = "* = Dati AMT (più accurato)",
  SYMBOL_HISTOIRE = "~ = Cronologia gilda LibHistoire",
  SYMBOL_DONATION = "? = Stima prima donazione",
  SYMBOL_TAGGED = "! = Tempo inizio tracciamento",
  SYMBOL_VALIDATED = "(nessun simbolo) = Dati memorizzati validati",
  SYMBOL_UNKNOWN = "SCO = Fonte sconosciuta/inaffidabile",
  SYMBOL_FOOTER = "Passa il mouse su qualsiasi valore giorni per informazioni dettagliate sulla fonte.",
  TIP_SORT_NAME = "Fare clic per ordinare per nome",
  TIP_SORT_DAYS = "Fare clic per ordinare per giorni dall'iscrizione",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "[ScrollkeeperProvisionMember] ERRORE: Framework mancante!",
  ERROR_NO_GUILD_SELECTED = "Nessuna gilda selezionata",
  ERROR_MAIL_UNAVAILABLE = "ScrollkeeperNotebookMail non disponibile",
  ERROR_NO_MEMBERS_TO_MAIL = "Nessun membro a cui inviare posta",
  ERROR_MAIL_WINDOW_FAILED = "Accesso alla finestra posta fallito",
  ERROR_SETTINGS_UNAVAILABLE = "Impostazioni non disponibili",
  ERROR_NO_GUILDS = "Nessuna gilda disponibile. Unisciti a una gilda per configurare le impostazioni per gilda.",
   
  -- Success Messages
  SUCCESS_AMT_DETECTED = "Advanced Member Tooltip rilevato - tracciamento migliorato attivato",
  SUCCESS_HISTOIRE_READY = "Integrazione LibHistoire pronta - tempi di adesione accurati disponibili",
  SUCCESS_REMOVED = "%s rimosso dal tracciamento",
  SUCCESS_BULK_REMOVED = "%d membri rimossi in massa dal tracciamento",
  SUCCESS_CLEARED_DATA = "Dati di tracciamento cancellati per %s",
  SUCCESS_CLEARED_GOLD = "%d flag di rimozione basati sull'oro cancellati",
  SUCCESS_MAIL_OPENED = "Finestra posta aperta con %d membri provvisori da %s",
  
  -- Status Messages
  STATUS_DISABLED = "Il tracciamento provvisorio è disabilitato",
  STATUS_NO_DATA = "Nessun dato disponibile",
  STATUS_NO_TRACKING = "Nessun dato di tracciamento disponibile",
  STATUS_SELECT_GUILD = "Seleziona una gilda per vedere le statistiche",
  STATUS_NO_FILTER_MATCH = "Nessun membro corrisponde ai criteri di filtro attuali.",
  STATUS_NO_SELECTED = "Nessun membro selezionato per la promozione",
  STATUS_NO_SELECTED_REMOVE = "Nessun membro selezionato per la rimozione",
  
  -- Notes column - color coding descriptions (for tooltip if needed)
  NOTES_COLOR_DONATION = "Verde: Informazioni sulle donazioni",
  NOTES_COLOR_OFFLINE = "Arancione: Informazioni offline",
  NOTES_COLOR_NO_DONATION = "Rosso: Nessuna donazione trovata",
  
  -- Button Labels
  BTN_REFRESH = "Aggiorna",
  BTN_REFRESH_TIP = "Aggiorna dati gilda e lista membri",
  BTN_EXPORT = "Esporta",
  BTN_EXPORT_TIP = "Esporta dati membri in finestra testo copiabile",
  BTN_SCAN = "Scansiona",
  BTN_SCAN_TIP = "Scansiona liste gilda per nuovi membri provvisori",
  BTN_VIEW_SELECTED = "Visualizza Selezionati",
  BTN_VIEW_ALL = "Visualizza Tutti",
  BTN_VIEW_SELECTED_TIP = "Alterna tra visualizzare tutti i membri e solo quelli selezionati",
  BTN_PROMOTE_ALL = "Promuovi Tutti",
  BTN_PROMOTE_ALL_TIP = "Apri lista gilda per promuovere i membri evidenziati.",
  BTN_REMOVE_ALL = "Rimuovi Tutti",
  BTN_REMOVE_ALL_TIP = "Rimuovi tutti i membri selezionati dal tracciamento",
  BTN_MAIL_SELECTED = "Invia Posta ai Selezionati",
  BTN_MAIL_SELECTED_TIP_HIGHLIGHTED = "Apri finestra posta con membri selezionati (%d)",
  BTN_MAIL_SELECTED_TIP_FILTERED = "Apri finestra posta con membri filtrati",
  BTN_SELECT_ALL = "Seleziona Tutti",
  BTN_CLOSE = "Chiudi",
  
  -- Filter Labels
  FILTER_ALL = "TUTTI",
  FILTER_PROBATION_ICON_TIP = "Filtra per membri in prova",
  FILTER_GOLD_ICON_TIP = "Filtra per membri con basse donazioni di oro",
  STATUS_INACTIVE = "Inattivo",
  STATUS_DONOR = "Donatore Attivo",
  
  -- Export Window
  EXPORT_TITLE = "Esporta Dati - Seleziona e Copia Testo",
  EXPORT_INSTRUCTION = "Clicca 'Seleziona Tutti' poi usa Ctrl+C per copiare negli appunti",
  EXPORT_REPORT_HEADER = "Rapporto Membri Provvisori per %s",
  EXPORT_GENERATED = "Generato: %s",
  EXPORT_FILTER = "Filtro: %s",
  EXPORT_VIEW_SELECTED = "Vista: Solo Membri Selezionati",
  EXPORT_FILTER_ALL = "Tutti i Membri",
  EXPORT_FILTER_RANK = "Membri in Prova",
  EXPORT_FILTER_GOLD = "Membri Donazione Oro",
  EXPORT_FILTER_CUSTOM = "Membri Filtrati",
  EXPORT_FORMAT = "%s | Stato: %s | Giorni nella gilda: %s | Motivo: %s | Note: %s",
  EXPORT_DAYS_NA = "N/D (filtro oro)",
  EXPORT_DAYS_FORMAT = "%d (%s)",
  EXPORT_DAYS_ACTUAL = "effettivo",
  EXPORT_DAYS_ESTIMATED = "stimato",
  EXPORT_FILTER_INACTIVE = "Membri Inattivi",
  EXPORT_FILTER_DONOR = "Donatori Attivi",
  
  -- Tooltips
  TIP_OPEN_ROSTER = "Apri lista membri per %s",
  TIP_REMOVE = "Rimuovi %s dal tracciamento",
  TIP_DAYS_HEADER = "Giorni dall'adesione alla gilda\n\n",
  TIP_DAYS_OFFLINE_HEADER = "Giorni Offline",
  TIP_DAYS_OFFLINE_DESC = "Mostra quanti giorni questo membro è stato offline.\nNumeri più alti indicano inattività più lunga.",
  TIP_DAYS_AMT = "* = Advanced Member Tooltip (più accurato)",
  TIP_DAYS_HISTOIRE = "~ = Cronologia gilda LibHistoire",
  TIP_DAYS_DONATION = "? = Stima prima donazione",
  TIP_DAYS_TAGGED = "! = Tempo inizio tracciamento",
  TIP_DAYS_UNKNOWN = "(Sconosciuto - nessuna fonte dati affidabile)",
  TIP_DAYS_GOLD = "(Membro filtro oro)",
  TIP_DAYS_VALIDATED = "(Validato dai dati memorizzati)",
  TIP_INSTALL_AMT = "Installa Advanced Member Tooltip\nper tempi di adesione più accurati",
  TIP_REVIEW_KICK = "Apri lista per revisionare/espellere %s (membro inattivo)",
  TIP_REVIEW_PROMOTE = "Apri lista per revisionare/espellere %s (membro in prova)",
  TIP_REVIEW_DONATION = "Apri lista per revisionare %s (donazione in sospeso)",
  TIP_PROMOTE_DONOR = "Apri lista per promuovere %s (contributore prezioso)",
  FILTER_INACTIVE_TIP = "Mostra membri che sono stati offline per il periodo configurato",
  FILTER_DONOR_TIP = "Mostra membri che soddisfano i requisiti minimi di donazione",
  
  -- Logging Messages
  LOG_STARTING_SCAN = "Avvio scansione manuale...",
  LOG_SCAN_COMPLETE = "Scansione manuale completata - %d voci errate cancellate, %d nuovi membri trovati",
  LOG_REFRESHED = "Visualizzazione aggiornata",
  LOG_NEW_MEMBER = "Nuovo membro si è unito a %s: %s",
  LOG_OPENING_ROSTER_PROMOTE = "Apertura lista per promuovere: %s",
  LOG_OPENING_ROSTER_BULK = "Apertura lista - promuovi questi %d membri: %s",
  LOG_NO_GUILD_ID = "Impossibile trovare ID gilda per: %s",
  LOG_NO_GUILD_ID_SIMPLE = "Impossibile trovare ID gilda",
  LOG_FILTER_MODE = "Modalità %s - %d membri selezionati",
  LOG_INITIALIZING = "Inizializzazione - %s",
  ERROR_DATA_NOT_READY = "I dati della cronologia della gilda non sono ancora pronti. Attendi un momento e riprova.",
  LOG_SCAN_COMPLETE_SHORT = "Scansione completata!",
  
  -- Mail Integration
  MAIL_SUBJECT_GOLD = "Promemoria Quote Gilda - %s",
  MAIL_RECIPIENT_COUNT = "Destinatari Provvisori: %d",
  MAIL_STATUS = "Stato: %d membri provvisori pronti per l'invio",

  -- Stats Display 
  STATS_FORMAT_FULL = "Gilda: %s | Totale: %d | Attivi: %d | In ritardo: %d | Promossi: %d | Prova: %d | Oro: %d",
  STATS_LH_READY = "pronto",
  STATS_LH_LOADING = "caricamento",
  
  -- Auto-tag Messages
  AUTO_TAG_SCAN = "Auto-taggato (scansione)",
  AUTO_TAG_LOGIN = "Auto-taggato (scansione login)",
  AUTO_TAG_ONLINE = "Auto-taggato (unito online)",
  ACTIVE_DONOR = "Donatore Attivo",
  
  -- Dropdown Messages
  DROPDOWN_NO_GUILDS = "Nessuna gilda configurata per il tracciamento",
  
  -- Status Values
  STATUS_PROVISIONAL = "provvisorio",
  STATUS_PROMOTED = "promosso",
  
  -- Reason Values
  REASON_RANK = "grado",
  REASON_GOLD = "oro",
  REASON_INACTIVE = "Inattivo",
  REASON_DONOR = "Donatore",
  
  -- Integration Status (detailed)
  INTEGRATION_AMT_INSTALL_URL = "esoui.com/downloads/info2351",
  INTEGRATION_STATUS = "Stato degli addon integrati e fonti dati:",
  
  -- Member Count Status
  MEMBER_COUNT_STATUS = "Stato Conteggio Membri",
  MEMBER_COUNT_FORMAT = "Attualmente tracciati: %d membri provvisori attivi\nRimossi permanentemente (grado): %d membri\nRimossi temporaneamente (oro): %d membri",
  
  -- Sources
  SOURCE_AMT = "amt",
  SOURCE_HISTOIRE = "histoire",
  SOURCE_DONATION = "donazione",
  SOURCE_TAGGED = "taggato",
  SOURCE_STORED = "memorizzato",
  SOURCE_UNKNOWN = "sconosciuto",
  SOURCE_DATA = "dati",
  
  -- Days display values
  DAYS_UNKNOWN = "SCO",
  DAYS_ERROR = "ERR",
  DAYS_NA = "-",
    
  -- Inactivity Filter Settings
  INACTIVITY_ENABLE = "Monitora Membri Inattivi",
  INACTIVITY_ENABLE_TIP = "Monitora automaticamente i membri che sono stati offline per un periodo prolungato",
  INACTIVITY_DAYS = "Inattivo Dopo (Giorni)",
  INACTIVITY_DAYS_TIP = "Considera un membro inattivo se non ha effettuato l'accesso per questo numero di giorni",
  
  -- Settings - Donor Filter
  DONOR_ENABLE = "Monitora Donatori Attivi",
  DONOR_ENABLE_TIP = "Monitora i membri che soddisfano o superano i requisiti minimi di donazione (utile per riconoscere i contributori)",
  DONOR_AMOUNT = "Importo Minimo Donazione",
  DONOR_AMOUNT_TIP = "Quantità di oro richiesta per essere considerato un donatore attivo",
  DONOR_PERIOD = "Periodo di Tempo (Giorni)",
  DONOR_PERIOD_TIP = "Controlla le donazioni negli ultimi X giorni",
  MANUAL_SCAN_NOTE = "Nota: Il monitoraggio dei membri richiede la scansione manuale. Apri la finestra Membri Provvisori e fai clic sul pulsante Scansiona per verificare i membri che necessitano di monitoraggio.",
}

--------------------------------------------------------------------------------
-- GUILD MAIL
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperNotebookMail"] = {
  SUBMENU_NAME = "Posta Gilda",
  DESCRIPTION = "Composizione posta in massa con integrazione modelli. Gli invii di posta sono automaticamente limitati a 3,1 secondi tra i messaggi. Usa |cFFD700/sgtmail|r per aprire la finestra posta.",
  ENABLE_MAIL = "Attiva Posta Gilda",
  ENABLE_MAIL_TIP = "Attiva o disattiva la funzione Posta Gilda.",
  OPEN_MAIL = "Apri Finestra Posta",
  OPEN_MAIL_TIP = "Clicca per aprire la finestra di composizione posta.",
    
  -- Window UI
  WINDOW_TITLE = "Posta Gilda Scrollkeeper",
  MAIL_TEMPLATES = "Modelli Posta:",
  SELECT_TEMPLATE = "-- Seleziona Modello --",
  GUILD_LABEL = "Gilda:",
  RANK_FILTER = "Filtro Grado:",
  ALL_RANKS = "Tutti i Gradi",
  PROVISIONAL_LABEL = "Membri Provvisori:",
  ALL_PROVISIONAL = "Tutti i Provvisori",
  GOLD_ONLY = "Solo Filtro Oro",
  RANK_ONLY = "Solo Filtro Grado",
  USE_PROVISIONAL = "Usa Lista Provvisori",
  KICK_AFTER_MAIL = "Rimuovi dopo l'invio:",
  KICK_NO = "Non rimuovere",
  KICK_YES = "Rimuovi dopo l'invio",
  KICK_NO_PERMISSION = "Non hai il permesso di rimuovere membri da questa gilda",
  MEMBER_KICKED = "Espulso: %s",
  MEMBER_NOT_FOUND = "Impossibile trovare il membro %s nell'elenco della gilda",
  PREVIEW_TITLE = "Anteprima della posta",
  PREVIEW_MAIL = "Anteprima",
    
  -- Composition
  SUBJECT_LABEL = "Oggetto:",
  BODY_LABEL = "Corpo del Messaggio:",
  READY_TO_SEND = "Pronto per l'invio",
  STATUS_READY = "Stato: Pronto",
  RECIPIENTS = "Destinatari: %d",
    
  -- Buttons
  SAVE_TEMPLATE = "Salva Modello",
  PREVIEW_RECIPIENTS = "Anteprima Destinatari",
  SEND_MAIL = "Invia Posta",
  PAUSE = "Pausa",
  RESUME = "Riprendi",
    
  -- Status Messages
  NO_GUILD = "Stato: Seleziona prima una gilda",
  NO_SUBJECT = "Stato: Inserisci un oggetto",
  NO_BODY = "Stato: Inserisci un corpo del messaggio",
  NO_RECIPIENTS = "Stato: Nessun destinatario trovato",
  STARTING = "Stato: Avvio invio posta...",
  SENDING = "Invio %d/%d",
  SENDING_TO = "A: %s",
  SUCCESS = "Stato: Posta inviata con successo",
  FAILED = "Stato: Fallito - %s",
  PAUSED = "Stato: In pausa",
  COMPLETED = "Completato: %d inviati, %d falliti",
  TEMPLATE_SAVED = "Stato: Modello salvato",
  TEMPLATE_FAILED = "Stato: Salvataggio modello fallito",
  NEED_SUBJECT_BODY = "Stato: Inserisci oggetto e corpo",
  RECIPIENTS_FOUND = "Stato: %d destinatari trovati",
  NO_MATCH_FILTERS = "Stato: Nessun destinatario corrisponde ai filtri",
  PROVISIONAL_SELECTED = "Stato: %d membri provvisori selezionati",
  NO_PROVISIONAL = "Stato: Nessun membro provvisorio trovato",
  USING_PROVISIONAL = "Stato: Utilizzo lista membri provvisori...",
    
  -- Failure Reasons
  RECIPIENT_NOT_FOUND = "Destinatario non trovato",
  MAILBOX_FULL = "Casella postale piena",
  IGNORED = "Destinatario ignora la posta",
  BLANK_MAIL = "Posta vuota non consentita",
  UNKNOWN_ERROR = "Errore sconosciuto",
  
  -- Character count display
  CHAR_COUNT = "%d/%d",
  
  -- Provisional member filter type display
  PROVISION_FILTER_ALL = "tutti",
  PROVISION_FILTER_GOLD = "oro", 
  PROVISION_FILTER_RANK = "grado",
  
  -- Auto-generated subject for gold filter
  DUES_REMINDER_SUBJECT = "Promemoria Quote Gilda - %s",
  
  -- Failure log content
  FAILURE_LOG_TITLE = "Rapporto Fallimento Invio Posta",
  FAILURE_LOG_DATE = "Data: %s",
  FAILURE_LOG_SUBJECT_LINE = "Oggetto: %s",
  FAILURE_LOG_TOTAL_SENT = "Totale Inviati: %d",
  FAILURE_LOG_TOTAL_FAILED = "Totale Falliti: %d",
  FAILURE_LOG_FAILED_LIST = "Destinatari Falliti:",
  FAILURE_LOG_SEPARATOR = string.rep("-", 50),
  FAILURE_LOG_BODY_HEADER = "Corpo Messaggio Originale:",
  FAILURE_LOG_SAVED = "Registro fallimenti salvato nel Taccuino: '%s'",
  FAILURE_LOG_SAVE_FAILED = "Salvataggio registro fallimenti nel Taccuino fallito",
  FAILURE_LOG_NO_NOTEBOOK = "Impossibile salvare registro fallimenti - Taccuino non disponibile",
  
  -- Mail tags
  TAG_MAIL = "posta",
  TAG_TEMPLATE = "modello",
  TAG_MAIL_LOG = "registro-posta",
  TAG_FAILURES = "fallimenti",

  -- Failure log
  FAILURE_LOG_TITLE_FORMAT = "Errori posta - %s",
}

--------------------------------------------------------------------------------
-- NOTEBOOK
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperNotebook"] = {
  -- Main
  SUBMENU_NAME = "Impostazioni Taccuino",
  WINDOW_TITLE = "Taccuino Scrollkeeper",
    
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperNotebook]|r ERRORE: ScrollkeeperFramework mancante!",
  ERROR_ALREADY_INIT = "|cFFD700[ScrollkeeperNotebook]|r Già inizializzato, saltando...",
  ERROR_WINDOW_EXISTS = "|cFFD700[ScrollkeeperNotebook]|r La finestra esiste già, restituzione esistente",
  ERROR_DROPDOWN_FAILED = "|cFFD700[ScrollkeeperNotebook]|r Avviso: Impossibile creare menu a discesa",
  ERROR_WINDOW_NOT_INIT = "Finestra taccuino non inizializzata.",
  ERROR_NO_NOTE_ENTRY = "Non c'è voce nota per %s.",
  ERROR_DISABLED = "|cFFD700[ScrollkeeperNotebook]|r Il taccuino è disabilitato",
  ERROR_NO_TITLE = "|cFFD700[ScrollkeeperNotebook]|r Inserisci un titolo per la nota",
  ERROR_SAVE_FAILED = "|cFFD700[ScrollkeeperNotebook]|r Salvataggio nota fallito",
  ERROR_TEMPLATE_NO_TITLE = "|cFFD700[ScrollkeeperNotebook]|r Inserisci un titolo per il modello",
    
  -- Success Messages
  SUCCESS_NOTE_SAVED = "|cFFD700[ScrollkeeperNotebook]|r Nota salvata: %s",
  SUCCESS_TEMPLATE_SAVED = "|cFFD700[ScrollkeeperNotebook]|r Modello posta salvato: %s",
    
  -- Window Labels
  LABEL_SEARCH = "Cerca:",
  LABEL_CATEGORY = "Categoria:",
  LABEL_SAVED_NOTES = "Note Salvate:",
  LABEL_NOTE_TITLE = "Titolo Nota:",
  LABEL_TAGS = "Tag (separati da virgole):",
  LABEL_NOTE_CONTENT = "Contenuto Nota:",
  LABEL_NOTES_COUNT = "Note: %d/%d",
  LABEL_NOTES_SIMPLE = "Note: %d",
    
  -- Character Counts
  CHAR_COUNT_TITLE = "%d/100",
  CHAR_COUNT_BODY = "%d/5000",
    
  -- Dropdown Options
  DROPDOWN_SELECT = "-- Seleziona Nota --",
  DROPDOWN_NO_MATCHES = "-- Nessuna corrispondenza trovata --",
    
  -- Default Text
  DEFAULT_NOTE_TITLE = "Nuova Nota",
  DEFAULT_NOTE_BODY = "Inserisci la tua nota qui...",
    
  -- Button Labels
  BTN_SAVE = "Salva",
  BTN_NEW = "Nuova",
  BTN_DELETE = "Elimina",
  BTN_SAVE_MAIL = "Salva Posta",
  BTN_OPEN_NOTEBOOK = "Apri Taccuino",
    
  -- Button Tooltips
  TIP_OPEN_NOTEBOOK = "Clicca per aprire la finestra taccuino (come il comando /sgtnote).",
    
  -- Settings
  SETTING_ENABLE = "Attiva Modulo Taccuino",
  SETTING_ENABLE_TIP = "Attiva/disattiva la funzione Taccuino.",
  SETTING_SEARCH = "Attiva Filtro Ricerca",
  SETTING_SEARCH_TIP = "Consenti filtro note per termini di ricerca.",
  SETTING_DEFAULT_CATEGORY = "Categoria Predefinita",
  SETTING_DEFAULT_CATEGORY_TIP = "Categoria predefinita per nuove note. Usa 'Posta' per modelli posta.",
    
  -- Descriptions
  DESC_MAIN = "Un blocco note in gioco completo con ricerca, categorie e tag. Usa |cFFD700/sgtnote|r per aprire la finestra taccuino.",
  DESC_MAIL_TEMPLATES = "Modelli posta: Salva note nella categoria 'Posta' per usarle come modelli sia nel client posta nativo che nel sistema posta gilda.",
    
  -- Mail Integration
  MAIL_LABEL_TEMPLATES = "Modelli Posta:",
  MAIL_DROPDOWN_SELECT = "-- Seleziona Modello --",
    
  -- Categories
  CAT_GENERAL = "Generale",
  CAT_MAIL = "Posta",
  CAT_EVENTS = "Eventi",
  CAT_ALL_CATEGORIES = "Tutte le Categorie",

  ERROR_MAX_TOTAL_NOTES = "Impossibile creare la nota: Numero massimo totale di note (%d) raggiunto. Elimina prima alcune note.",
  ERROR_MAX_CATEGORY_NOTES = "Impossibile creare la nota: Numero massimo di note (%d) per la categoria '%s' raggiunto.",
  ERROR_NOTE_TOO_LARGE = "La nota è troppo grande (%d caratteri). Il massimo è %d caratteri.",
  STATS_HEADER = "Statistiche di Archiviazione Quaderno Scrollkeeper",
  STATS_TOTAL = "Note Totali: %d / %d",
  STATS_CATEGORY = " %s: %d / %d note (~%.1f KB)",
  BTN_PREVIEW_MAIL = "Anteprima",
  PREVIEW_TITLE = "Anteprima della posta",
  ERROR_NO_BODY = "Inserisci del testo nel corpo",
  
  -- Guild Tools Integration
  GUILDMAIL_NO_TEMPLATES   = "(Usa 'Salva come posta' nel Taccuino per aggiungere modelli)",
  SETTING_GUILDMAIL_INJECT = "Mostra il selettore di modelli nella posta della gilda",
  SETTING_GUILDMAIL_INJECT_TIP = "Mostra un selettore di modelli di posta del Taccuino nella finestra di composizione della posta della gilda.",
}

--------------------------------------------------------------------------------
-- HISTORY
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperHistory"] = {
  -- Main
  SUBMENU_NAME = "Ricerca Cronologia Gilda",
  WINDOW_TITLE = "Ricerca Cronologia Gilda",
    
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperHistory]|r ERRORE: ScrollkeeperFramework mancante!",
  ERROR_WINDOW_FAILED = "|cFFD700[ScrollkeeperHistory]|r Creazione finestra fallita",
  ERROR_NO_EXPORT = "|cFFD700[ScrollkeeperHistory]|r Nessun evento da esportare",
    
  -- Success Messages
  SUCCESS_READY = "|cFFD700[ScrollkeeperHistory]|r Pronto - usa /sgthistory",
    
  -- Log Messages
  LOG_LOADING = "|cFFD700[ScrollkeeperHistory]|r Caricamento... SF.Data esiste: %s",
  LOG_DATA_GETEVENTS = "|cFFD700[ScrollkeeperHistory]|r SF.Data.getEvents al caricamento: %s",
  LOG_DATA_UNAVAILABLE = "|cFFD700[ScrollkeeperHistory]|r SF.Data.getEvents non disponibile",
  LOG_FALLBACK_INIT = "|cFFD700[ScrollkeeperHistory]|r Inizializzazione di fallback attivata",
    
  -- Window Labels
  LABEL_GUILD = "Gilda:",
  LABEL_CATEGORY = "Categoria:",
  LABEL_SEARCH = "Cerca:",
  LABEL_EVENTS_COUNT = "Eventi: %d",
  LABEL_REFRESH = "Aggiorna",
  LABEL_EXPORT = "Esporta",
    
  -- Status Messages
  STATUS_READY = "Pronto",
  STATUS_READY_LOADED = "Pronto - %d eventi caricati",
  STATUS_NO_GUILD = "Nessuna gilda selezionata",
  STATUS_DATA_NOT_READY = "Modulo dati non pronto",
  STATUS_NO_EVENTS_CACHE = "Nessun evento trovato - la cache potrebbe essere ancora in costruzione. Assicurati che la categoria sia attiva in LibHistoire.",
  STATUS_WAITING_LH = "In attesa dell'inizializzazione di LibHistoire...",
  STATUS_ENABLE_GUILDS = "Attiva le gilde nelle impostazioni Cronologia",
    
  -- Column Headers
  HEADER_TIME = "Tempo",
  HEADER_CATEGORY = "Categoria",
  HEADER_EVENT = "Evento",
  HEADER_MEMBER = "Membro",
  HEADER_DETAILS = "Dettagli",
    
  -- Category Names
  CAT_ALL = "Tutti gli Eventi",
  CAT_ROSTER = "Lista",
  CAT_BANK_GOLD = "Oro Banca",
  CAT_BANK_ITEMS = "Oggetti Banca",
  CAT_SALES = "Vendite",
    
  -- Event Type Names - Roster
  EVENT_INVITED = "Invitato",
  EVENT_JOINED = "Unito",
  EVENT_PROMOTED = "Promosso",
  EVENT_DEMOTED = "Retrocesso",
  EVENT_LEFT = "Abbandonato",
  EVENT_KICKED = "Espulso",
  EVENT_APP_ACCEPTED = "Candidatura Accettata",
    
  -- Event Type Names - Bank Gold
  EVENT_GOLD_DEPOSITED = "Oro Depositato",
  EVENT_GOLD_WITHDRAWN = "Oro Prelevato",
  EVENT_TRADER_BID = "Offerta Mercante",
  EVENT_BID_RETURNED = "Offerta Restituita",
    
  -- Event Type Names - Bank Items
  EVENT_ITEM_DEPOSITED = "Oggetto Depositato",
  EVENT_ITEM_WITHDRAWN = "Oggetto Prelevato",
    
  -- Event Type Names - Sales
  EVENT_ITEM_SOLD = "Oggetto Venduto",
    
  -- Unknown Event
  EVENT_UNKNOWN = "Sconosciuto (%s)",
    
  -- Time Formatting
  TIME_JUST_NOW = "Proprio ora",
  TIME_MINUTES_AGO = "%dm fa",
  TIME_HOURS_AGO = "%dh fa",
  TIME_DAYS_AGO = "%dg fa",
  TIME_MONTHS_AGO = "%dme fa",
    
  -- Export Window
  EXPORT_TITLE = "Esporta Dati - Seleziona e Copia Testo",
  EXPORT_INSTRUCTION = "Clicca 'Seleziona Tutti' poi usa Ctrl+C per copiare negli appunti",
  EXPORT_SELECT_ALL = "Seleziona Tutti",
  EXPORT_HEADER = "Esportazione Cronologia Gilda per %s",
  EXPORT_GENERATED = "Generato: %s",
  EXPORT_CATEGORY = "Categoria: %s",
  EXPORT_TOTAL = "Totale Eventi: %d",
  EXPORT_FORMAT = "%s | %s | %s | %s | %s",
    
  -- Tooltips
  TIP_REFRESH = "Aggiorna lista gilde e dati eventi",
  TIP_EXPORT = "Esporta eventi visibili in testo",
  TIP_FULL_TIMESTAMP = "Timestamp completo",
  TIP_FULL_DETAILS = "Dettagli completi",
    
  -- Settings - Main
  SETTINGS_DESC = "Cerca eventi cronologia gilda in cache. Usa |cFFD700/sgthistory|r per aprire la finestra di ricerca.\n\nI dati vengono automaticamente messi in cache per tutte le gilde da ScrollkeeperData. Qui controlli quali gilde e categorie mostrare nella finestra di ricerca.",
  SETTINGS_DISPLAY = "Impostazioni Visualizzazione",
  SETTINGS_MAX_EVENTS = "Eventi Massimi",
  SETTINGS_MAX_EVENTS_TIP = "Numero massimo di eventi da caricare contemporaneamente",
  SETTINGS_SEARCH_DELAY = "Ritardo Ricerca (ms)",
  SETTINGS_SEARCH_DELAY_TIP = "Ritardo prima dell'esecuzione della ricerca durante la digitazione",
  SETTINGS_COLOR_CODING = "Attiva Codifica Colore",
  SETTINGS_COLOR_CODING_TIP = "Codifica eventi per colore in base al tipo",
    
  -- Settings - Per Guild
  SETTINGS_SHOW_GUILD = "Mostra in Finestra Cronologia",
  SETTINGS_SHOW_GUILD_TIP = "Mostra questa gilda nella finestra ricerca cronologia",
  SETTINGS_CATEGORIES = "Categorie Eventi da Mostrare",
  SETTINGS_ROSTER_EVENTS = "Eventi Lista",
  SETTINGS_ROSTER_EVENTS_TIP = "Mostra adesioni membri, abbandoni, promozioni, espulsioni",
  SETTINGS_BANK_GOLD_EVENTS = "Eventi Oro Banca",
  SETTINGS_BANK_GOLD_EVENTS_TIP = "Mostra depositi oro, prelievi, offerte mercante",
  SETTINGS_BANK_ITEMS_EVENTS = "Eventi Oggetti Banca",
  SETTINGS_BANK_ITEMS_EVENTS_TIP = "Mostra depositi e prelievi oggetti",
  SETTINGS_SALES_EVENTS = "Eventi Vendite",
  SETTINGS_SALES_EVENTS_TIP = "Mostra vendite negozio gilda",
    
  -- Dropdown
  DROPDOWN_NO_GUILDS = "Nessuna gilda attivata - vedi impostazioni",
    
  -- Formatting
  FORMAT_GOLD = "%s oro",
  FORMAT_QUANTITY_ITEM = "%dx %s",
  FORMAT_SOLD_TO = "a %s",
  FORMAT_RANK_ARROW = "→",
  MANUAL_ENTRY_TOOLTIP = "Questa è una donazione registrata manualmente",
  NOTES_LABEL = "Note",
  DELETE_MANUAL_ENTRY = "Elimina questa voce manuale",
  SUCCESS_DELETED_ENTRY = "Voce manuale eliminata con successo",
  ERROR_DELETE_FAILED = "Impossibile eliminare la voce",
    
  -- Member Names
  MEMBER_UNKNOWN = "Sconosciuto",
    
  LOG_LIBSCROLL_NOT_FOUND = "|cFFD700[ScrollkeeperHistory]|r LibScroll non trovato - utilizzo dello scorrimento di base",
}

--------------------------------------------------------------------------------
-- ROSTER
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperRoster"] = {
  -- Main
  SUBMENU_NAME = "Miglioramento Lista",
    
  -- Settings
  SETTING_TRADER_TIMER = "Mostra Timer Rotazione Mercante",
  SETTING_TRADER_TIMER_TIP = "Mostra timer conto alla rovescia che indica il tempo fino alla prossima rotazione del mercante gilda.\n\n" ..
                              "Il colore del timer indica urgenza:\n" ..
                              "• |c00FF0024+ ore|r - Sicuro\n" ..
                              "• |cFFFF006-24 ore|r - Pianificare in anticipo\n" ..
                              "• |cFF88002-6 ore|r - Agire presto\n" ..
                              "• |cFF0000< 2 ore|r - Urgente!",
  
  -- Timer Display
  TIMER_LABEL = "Rotazione Mercante: %s",
  TIMER_FLIPPING = "In rotazione ora",
  TIMER_FORMAT = "%dh %dm",
    
  -- Full tooltip
  TOOLTIP_FULL = "Tempo fino alla rotazione del mercante gilda\n\n" ..
                 "Il colore indica urgenza:\n" ..
                 "|c00FF0024+ ore|r - Sicuro\n" ..
                 "|cFFFF006-24 ore|r - Pianificare in anticipo\n" ..
                 "|cFF88002-6 ore|r - Agire presto\n" ..
                 "|cFF0000< 2 ore|r - Urgente!",
    
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperRoster]|r ERRORE: ScrollkeeperFramework mancante!",
  
  -- Tasks
  TASKS_HEADER = "Promemoria Attività",
  TASKS_DESCRIPTION = "I promemoria delle attività sono configurati per gilda qui sotto. Abilita 'Mostra attività sul registro' per ogni gilda in cui desideri promemoria.",
  CUSTOM_TASKS = "Attività Personalizzate",
  CUSTOM_TASKS_DESC = "Aggiungi e configura attività personalizzate. Il pannello delle impostazioni non si aggiornerà fino al ricaricamento, ma l'attività verrà aggiunta o rimossa in tempo reale.",
  ADD_CUSTOM_TASK = "Aggiungi Attività Personalizzata",
  REMOVE = "Rimuovi",

  -- Per-guild task toggle
  GUILD_TASKS_ENABLE = "Mostra attività sul registro",
  GUILD_TASKS_ENABLE_TIP = "Abilita i promemoria delle attività per la pagina del registro di questa gilda",

  -- Guild configuration header
  GUILD_CONFIG_DESC = "Configura i promemoria delle attività per %s",

  -- Preset tasks section
  PRESET_TASKS_HEADER = "Attività predefinite",

  -- Frequency settings
  FREQUENCY_NUMBER = "Frequenza (numero)",
  FREQUENCY_NUMBER_TIP = "Inserisci il numero di unità di tempo",
  FREQUENCY_UNIT = "Unità",

  -- Task window
  TASK_WINDOW_TITLE = "Aggiungi attività personalizzata",
  TASK_WINDOW_NAME_LABEL = "Nome dell'attività:",
  TASK_WINDOW_FREQ_LABEL = "Frequenza:",
  TASK_WINDOW_GUILD_LABEL = "Gilde (seleziona multiple o 'Tutte'):",
  TASK_WINDOW_ADD = "Aggiungi attività",
  TASK_WINDOW_CANCEL = "Annulla",

  -- Task window validation messages
  ERROR_NO_TASK_NAME = "Inserisci un nome per l'attività",
  ERROR_INVALID_FREQ_NUMBER = "Inserisci un numero valido per la frequenza",
  ERROR_NO_FREQ_UNIT = "Seleziona un'unità di frequenza",

  -- Task completion messages
  TASK_COMPLETED = "Attività completata: %s",
  TASK_ADDED = "Attività aggiunta: %s (gilda: %s, abilitata: vero, èPersonalizzata: vero)",
  TASK_REMOVED = "Attività rimossa: %s",
  ERROR_PRESET_REMOVE = "Le attività predefinite non possono essere rimosse. Disabilitale nelle impostazioni invece.",

  -- Task list display
  TASK_STATUS_OVERDUE = "SCADUTA",

  -- Tooltip for task labels
  TASK_TOOLTIP_LEFT = "Clic sinistro: Completa attività",
  TASK_TOOLTIP_RIGHT = "Clic destro: Rimuovi attività",

  PRESET_REVIEW_APPLICATIONS = "Esamina candidature",
  PRESET_CHECK_BANK_DEPOSITS = "Verifica depositi bancari",
  PRESET_UPDATE_MOTD = "Aggiorna messaggio del giorno",
  PRESET_PROMOTE_PROBATIONARY = "Promuovi membri in prova",
  PRESET_REVIEW_INACTIVES = "Esamina inattivi",

  TASK_COLOR_LEGEND = "Legenda colori - Tempo rimanente:\n|c00FF00>25%|r - Sicuro\n|cFFFF0010-25%|r - Pianificare in anticipo\n|cFF88005-10%|r - Agire presto\n|cFF0000<5% o scaduta|r Urgente!",
    
  -- Remove Button
  REMOVE_CUSTOM_TASK = "Rimuovi Attività Personalizzata",
  REMOVE_CUSTOM_TASK_TIP = "Seleziona un'attività personalizzata da rimuovere definitivamente",
  REMOVE_WARNING = "ATTENZIONE: La rimozione è permanente! Per ripristinare un'attività, devi aggiungerla nuovamente manualmente.",
  REMOVE_INSTRUCTION = "Fai clic su un'attività qui sotto per rimuoverla:",
  REMOVE_WINDOW_CANCEL = "Annulla",
}

--------------------------------------------------------------------------------
-- CONTEXT MENU
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperContextMenu"] = {
  SUBMENU_NAME = "Opzioni Menu Contestuale",
  DESCRIPTION = "Aggiunge voci di nuova posta, invito gilda e invito chat a tutti i menu contestuali clic destro.",
  MASTER_ENABLE = "Attiva Funzioni Menu Contestuale",
  MASTER_ENABLE_TIP = "Interruttore principale per tutti i miglioramenti menu contestuale.",
  SF_UNAVAILABLE = "ERRORE: ScrollkeeperFramework mancante!",
    
  -- Headers
  SCROLLKEEPER_TOOLS = "Strumenti Scrollkeeper",
  CHAT_HEADER = "Opzioni Chat",
  ROSTER_HEADER = "Opzioni Lista Gilda",
    
  -- Options
  NEW_MAIL = "Nuova Posta",
  NEW_MAIL_TIP = "Aggiungi opzione 'Nuova Posta' ai menu contestuali chat.",
  GUILD_INVITE = "Invito Gilda",
  GUILD_INVITE_TIP = "Aggiungi opzioni invito gilda ai menu contestuali chat.",
  ROSTER_DESC = "Aggiunge integrazione taccuino al menu contestuale clic destro lista gilda.",
  NOTEBOOK_CONTEXT = "Attiva Menu Contestuale Taccuino",
  NOTEBOOK_CONTEXT_TIP = "Clic destro sui membri gilda per aprire o creare voci taccuino.",
  ROSTER_INVITE = "Invito Gilda da Lista",
  ROSTER_INVITE_TIP = "Aggiungi opzioni invito gilda ai menu contestuali lista gilda.",
    
  -- Context Menu Items
  INVITE_TO = "Invita a %s",
  GO_TO_NOTEBOOK = "Vai a Voce Taccuino",
  MAKE_NOTE = "Crea Nota Taccuino",
    
  -- Messages
  NOTEBOOK_NOT_FOUND = "Modulo taccuino non trovato.",
  NOTE_EXISTS = "La nota esiste già per %s.",
  NOTE_CREATED = "Nota creata per %s nel Taccuino.",
  OPEN_NOTE = "Apri Voce Taccuino",
  CREATE_NOTE = "Crea Nota Taccuino",
  LOG_CONVERSATION = "Registra Chat Recente",
  CONVERSATION_LOGGED = "Registrati %d messaggi recenti con %s nel Taccuino nella categoria 'Chat'",
  NO_CONVERSATION = "Nessuna chat recente trovata riguardante %s negli ultimi 100 messaggi.",
  LOG_CONVERSATIONS = "Attiva Registrazione Conversazioni",
  LOG_CONVERSATIONS_TIP = "Registra conversazioni chat nel Taccuino (richiede addon pChat).",
  PCHAT_WARNING = "Addon pChat non rilevato - questa funzione non funzionerà",
    
  -- Mail Items
  LOG_DONATION = "Registra Donazione",
  LOG_DONATION_TIP = "Registrare manualmente una donazione per questo giocatore",
  DONATION_WINDOW_TITLE = "Registra Donazione Manuale",
  DONATION_PLAYER = "Giocatore",
  DONATION_GUILD = "Gilda",
  DONATION_VALUE_LABEL = "Valore in Oro",
  DONATION_VALUE_TIP = "Inserisci il valore in oro di questa donazione (per gli oggetti, inserisci il loro valore stimato)",
  DONATION_NOTES_LABEL = "Note (Opzionale)",
  DONATION_NOTES_TIP = "Dettagli aggiuntivi come 'Inviato 50 Cera di Dreugh per posta' o 'Oro inviato il 25/12'",
  DONATION_TYPE_LABEL = "Tipo di Donazione",
  DONATION_TYPE_GOLD = "Oro (Posta)",
  DONATION_TYPE_ITEMS = "Oggetti (Valutati)",
  BTN_RECORD_DONATION = "Registra Donazione",
  BTN_CANCEL = "Annulla",
  SUCCESS_DONATION_LOGGED = "Donazione di %d oro registrata per %s",
  ERROR_INVALID_AMOUNT = "Inserisci un importo di oro valido",
}

--------------------------------------------------------------------------------
-- DATA MODULE
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperData"] = {
  -- Module Info
  DESCRIPTION = "Servizio caching in background per dati cronologia gilda usando LibHistoire.",
    
  -- Status Messages
  HISTOIRE_READY = "LibHistoire pronto - caching di tutta la cronologia gilda",
  CACHE_STATUS = "=== Stato Cache Eventi ===",
  NO_CACHED_DATA = "Nessun dato in cache trovato",
  CACHE_EMPTY = "La cache è vuota - questo potrebbe richiedere alcuni minuti al primo caricamento",
  WAITING_FOR_HISTOIRE = "In attesa dell'inizializzazione di LibHistoire...",
    
  -- Log Messages
  EVENTS_CACHED = "%s/%s: %d eventi in cache",
  STARTED_CACHING = "Avviato caching di %d gilde",
  LOG_MANUAL_DONATION = "%s - %d oro registrato manualmente",
  MANUAL_DONATION_SOURCE = "Inserimento Manuale",
  MODULE_LOADED = "|cFFD700[ScrollkeeperData]|r Caricato - servizio caching in background",
    
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperData]|r ERRORE: ScrollkeeperFramework mancante!",
  ERROR_DATA_NOT_TABLE = "|cFFD700[ScrollkeeperData]|r CRITICO: SF.Data non è una tabella!",
  ERROR_HISTOIRE_NOT_FOUND = "|cFFD700[ScrollkeeperData]|r ERRORE: LibHistoire non trovato!",
    
  -- Cache Display
  GUILD_HEADER = "%s:",
  CATEGORY_LINE = "  %s: %d eventi",
  HISTOIRE_STATUS = "LibHistoire pronto: %s",
    
  -- Category Names (for display)
  CAT_ROSTER = "lista",
  CAT_BANKED_GOLD = "oroBanca",
  CAT_BANKED_ITEMS = "oggettiBanca",
  CAT_SALES = "vendite",
  
  -- Manual donation logging
  LOG_MANUAL_DONATION = "|cFFD700[ScrollkeeperData]|r Registrato: %d oro da %s a %s",
  
  -- Delete entry messages
  ERROR_DELETE_MISSING_PARAMS = "|cFFD700[ScrollkeeperData]|r deleteManualEntry: Parametri richiesti mancanti",
  SUCCESS_DELETE_ENTRY = "|cFFD700[ScrollkeeperData]|r Voce manuale eliminata con successo dalla cache e dallo storage",
  ERROR_DELETE_NOT_FOUND = "|cFFD700[ScrollkeeperData]|r deleteManualEntry: Voce non trovata",
  
  -- Debug cache messages
  DEBUG_NO_GUILD = "[Debug Dati] Gilda non specificata",
  DEBUG_NO_CACHE_FOR_GUILD = "[Debug Dati] Nessuna cache per la gilda: %s",
  DEBUG_AVAILABLE_GUILDS = "[Debug Dati] Gilde disponibili:",
  DEBUG_GUILD_LIST_ITEM = "  - %s",
  DEBUG_CACHE_FOR_GUILD = "[Debug Dati] Cache per %s:",
  DEBUG_BANKED_GOLD_COUNT = "  bankedGold: %d eventi",
  DEBUG_RECENT_DEPOSITS = "  Depositi recenti:",
  DEBUG_NO_DEPOSITS = "  Nessun deposito trovato",
  DEBUG_BANKED_GOLD_MISSING = "  bankedGold: NON PRESENTE",
  DEBUG_ROSTER_COUNT = "  roster: %d eventi",
  DEBUG_ROSTER_MISSING = "  roster: NON PRESENTE",
  
  -- Slash command messages
  ERROR_DATA_MODULE_UNAVAILABLE = "Modulo dati o funzione di controllo non disponibile",
  CMD_CHECKGOLD_USAGE = "Uso: /sgtcheckgold NomeGilda|@NomeVisualizzazione|Giorni",
  CMD_CHECKGOLD_EXAMPLE = "Esempio: /sgtcheckgold Dragon's Nest Thievery Co|@TuoNome|14",
  CMD_CHECKGOLD_RESULT = "%s ha donato %d oro negli ultimi %d giorni (%s)",
  
  -- Initialization
  ERROR_LIBHISTOIRE_MISSING = "|cFFD700[ScrollkeeperData]|r ERRORE: LibHistoire non trovato",
}

--------------------------------------------------------------------------------
-- WELCOME MESSAGES
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperWelcome"] = {
  SUBMENU_NAME = "Messaggi di Benvenuto",
  DESCRIPTION = "Configura i messaggi di benvenuto per i membri della gilda. Usa %1 per il nome del giocatore e %2 per il nome della gilda. I messaggi verranno accodati quando si accettano più candidature o se il campo di testo è attivo.",
  MASTER_ENABLE = "Attiva Messaggi di Benvenuto",
  MASTER_ENABLE_TIP = "Attiva o disattiva tutti i messaggi di benvenuto.",
  LOG_MEMBER_JOINED = "|cFFD700[ScrollkeeperWelcome]|r %s si è unito a %s come %s",
    
  -- Template
  TEMPLATE_HEADER = "Variabili Modello",
  VAR_PLAYER = "%1 - Nome Giocatore",
  VAR_GUILD = "%2 - Nome Gilda",
    
  -- Guild Settings
  ENABLE_FOR_GUILD = "Attiva per questa Gilda",
  MESSAGE_TEMPLATE = "Modello Messaggio",
  PREVIEW = "Anteprima: %s",
  DEFAULT_MESSAGE = "Benvenuto %1 a %2",
}

--------------------------------------------------------------------------------
-- STANDARD COMMANDS
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperStandardCommands"] = {
  -- Main
  SUBMENU_NAME = "Comandi Chat e Utilità",
  DESCRIPTION = "Comandi utilità aggiuntivi e supporto associazione tasti per Scrollkeeper.",
    
  -- Headers
  COMMANDS_HEADER = "Comandi Disponibili",
  UTILITY_HEADER = "Comandi Utilità",
  STATUS_HEADER = "Comandi Stato",
  MODULE_HEADER = "Comandi Modulo",
  DEBUG_HEADER = "Comandi Debug",
    
  -- Command Documentation
  CMD_SKDEBUG = "|cf3ebd1/skdebug|r - Mostra informazioni debug sistema",
  CMD_SKTEST = "|cf3ebd1/sktest <opzione>|r - Esegui test moduli (opzioni: context, settings, notebook, mail, data)",
  CMD_SGTNOTE = "|cf3ebd1/sgtnote|r - Alterna finestra taccuino",
  CMD_SGTMAIL = "|cf3ebd1/sgtmail|r - Apri finestra posta",
  CMD_SGTHISTORY = "|cf3ebd1/sgthistory|r - Apri finestra ricerca cronologia",
  CMD_SGTPROVISION = "|cf3ebd1/sgtprovision|r - Apri finestra membri provvisori",
  CMD_SGTCACHE = "|cf3ebd1/sgtcache|r - Mostra stato cache eventi",
  CMD_ROLL = "|cf3ebd1/roll <numero>|r - Lancia dadi (esempio: /roll 20)",
  CMD_DICE = "|cf3ebd1/dice <numero>|r - Uguale a /roll",
  CMD_RL = "|cf3ebd1/rl|r - Ricarica interfaccia",
  CMD_ON = "|cf3ebd1/on|r - Imposta stato su Online",
  CMD_OFF = "|cf3ebd1/off|r - Imposta stato su Offline",
  CMD_AFK = "|cf3ebd1/afk|r - Imposta stato su Assente",
  CMD_DND = "|cf3ebd1/dnd|r - Imposta stato su Non Disturbare",
  CMD_OFFL = "|cf3ebd1/offl|r - Alterna Online/Offline",
    
  -- Full command list
  COMMAND_LIST = "|cf3ebd1/sgtnote|r - Alterna finestra taccuino\n" ..
                "|cf3ebd1/sgtmail|r - Apri finestra posta\n" ..
                "|cf3ebd1/sgthistory|r - Apri ricerca cronologia\n" ..
                "|cf3ebd1/sgtprovision|r - Apri finestra membri provvisori\n" ..
                "|cf3ebd1/roll <numero>|r - Lancia dadi\n" ..
                "|cf3ebd1/rl|r - Ricarica interfaccia\n" ..
                "|cf3ebd1/on /off /afk /dnd|r - Imposta stato giocatore\n" ..
                "|cf3ebd1/offl|r - Alterna offline\n" ..
                "|cf3ebd1/skdebug|r - Mostra info debug\n" ..
                "|cf3ebd1/sgtcache|r - Mostra stato cache",
				"|cf3ebd1/sgtcheckpm NomeGilda|@NomeVisualizzato|r - Debug controllo donazione oro per membro specifico\n" ..
				"|cf3ebd1/sgtattendance start [nome evento]|r - Inizia monitoraggio\n" ..
				"|cf3ebd1/sgtattendance stop|r - Ferma e salva rapporto\n" ..
				"|cf3ebd1/sgtattendance status|r - Mostra informazioni sessione corrente" ..
				"|cf3ebd1/sgttask add <nome>|<frequenza>|<gilda>|r per aggiungere un'attività personalizzata" ..
				"|cf3ebd1/sgttask list|r - Mostra tutte le attività con stato" ..
				"|cf3ebd1/sgttask complete <numero>|r - Contrassegna attività come completata",
  
  -- Buttons
  TEST_BUTTON = "Testa Tutti i Sistemi",
  TEST_BUTTON_TIP = "Esegui un test completo di tutti i moduli Scrollkeeper",
    
  -- Status Messages
  STATUS_ONLINE = "Stato impostato su Online",
  STATUS_OFFLINE = "Stato impostato su Offline",
  STATUS_DND = "Stato impostato su Non Disturbare",
  STATUS_AWAY = "Stato impostato su Assente",
  STATUS_CHANGED = "Scrollkeeper: Stato impostato su %s",
  STATUS_TOGGLED = "Finestra taccuino alternata",
    
  -- Roll Messages
  ROLL_USAGE = "Uso: /roll <max>",
  ROLL_EXAMPLE = "Esempio: /roll 20",
  ROLL_INVALID = "Numero non valido: %s",
  ROLL_OUTPUT = "ha lanciato %d (1-%d)",
    
  -- Debug Messages
  DEBUG_HEADER = "=== Info Debug Scrollkeeper ===",
  DEBUG_FRAMEWORK = "Framework caricato: %s",
  DEBUG_SETTINGS = "Tabella impostazioni: %s",
  DEBUG_LAM = "LAM2 disponibile: %s",
  DEBUG_FUNC = "SF.func disponibile: %s",
  DEBUG_GET_SETTINGS = "SF.getModuleSettings: %s",
  DEBUG_PANEL = "Pannello registrato: %s",
  DEBUG_MODULE = "Modulo: %s - Controlli: %d - Icona: %s",
  DEBUG_TOTAL_MODULES = "Totale moduli registrati: %d",
  DEBUG_NO_MODULES = "Nessuna impostazione modulo trovata",
  DEBUG_CONTEXT = "Menu contestuale attivato: %s",
  DEBUG_NOTEBOOK = "Modulo taccuino: %s",
  DEBUG_DATA = "Modulo dati: %s",
  DEBUG_HISTOIRE = "LibHistoire: %s",
  DEBUG_DATETIME = "LibDateTime: %s",
    
  -- Test Messages
  TEST_HEADER = "=== Comandi Test Scrollkeeper ===",
  TEST_USAGE = "Uso: /sktest <opzione>",
  TEST_OPTIONS = "Opzioni: context, settings, notebook, mail, data, attendance",
  TEST_RUNNING = "Esecuzione test sistema completo...",
  TEST_UNKNOWN = "Opzione test sconosciuta: %s",
  TEST_AVAILABLE = "Opzioni disponibili: context, settings, notebook, mail, data, attendance",
    
  -- Test: Context
  TEST_CONTEXT_HEADER = "=== Test Menu Contestuale ===",
  TEST_CONTEXT_ACTIVE = "Il gancio menu contestuale è attivo",
  TEST_CONTEXT_ENABLED = "Menu contestuale attivato nelle impostazioni: %s",
  TEST_CONTEXT_MAIL = "Opzione nuova posta chat: %s",
  TEST_CONTEXT_INVITE = "Opzione invito chat: %s",
  TEST_CONTEXT_NOT_LOADED = "Modulo ScrollkeeperContextMenu non caricato",
  TEST_CONTEXT_FAILED = "Gancio menu contestuale FALLITO - CHAT_SYSTEM non disponibile",
    
  -- Test: Settings
  TEST_SETTINGS_HEADER = "=== Test Impostazioni ===",
  TEST_SETTINGS_ACCESSIBLE = "Impostazioni %s accessibili: %s",
  TEST_SETTINGS_PANEL = "Il pannello impostazioni è registrato",
  TEST_SETTINGS_NO_PANEL = "Pannello impostazioni non registrato",
  TEST_SETTINGS_NO_ACCESS = "Impossibile accedere alle impostazioni modulo - problema framework",
    
  -- Test: Notebook
  TEST_NOTEBOOK_HEADER = "=== Test Taccuino ===",
  TEST_NOTEBOOK_LOADED = "Modulo taccuino caricato",
  TEST_NOTEBOOK_ENABLED = "Attivato: %s",
  TEST_NOTEBOOK_WINDOW = "Finestra taccuino esiste: %s",
  TEST_NOTEBOOK_SAVE = "Test salvataggio nota: %s",
  TEST_NOTEBOOK_NOT_LOADED = "Modulo taccuino non caricato",
    
  -- Test: Mail
  TEST_MAIL_HEADER = "=== Test Modulo Posta ===",
  TEST_MAIL_LOADED = "Modulo posta caricato",
  TEST_MAIL_ENABLED = "Attivato: %s",
  TEST_MAIL_WINDOW = "Finestra posta esiste: %s",
  TEST_MAIL_COMMAND = "Comando /sgtmail registrato",
  TEST_MAIL_NO_COMMAND = "Comando /sgtmail non registrato",
  TEST_MAIL_NOT_LOADED = "Modulo posta non caricato",
    
  -- Test: Data
  TEST_DATA_HEADER = "=== Test Modulo Dati ===",
  TEST_DATA_LOADED = "Modulo dati caricato",
  TEST_DATA_LH_AVAILABLE = "LibHistoire disponibile",
  TEST_DATA_CACHE_ACCESSIBLE = "Cache eventi accessibile: %s",
  TEST_DATA_RECORDS = "Totale record eventi in cache: %d",
  TEST_DATA_NO_FUNCTIONS = "Funzioni dati non disponibili",
  TEST_DATA_NO_LH = "LibHistoire non disponibile",
  TEST_DATA_NOT_LOADED = "Modulo dati non caricato",
    
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperStandardCommands]|r ERRORE: ScrollkeeperFramework mancante!",
  ERROR_NOTEBOOK_DISABLED = "Il taccuino è disattivato nelle impostazioni",
  ERROR_NOTEBOOK_NO_WINDOW = "Finestra taccuino non disponibile",
  ERROR_NOTEBOOK_NOT_LOADED = "Modulo taccuino non caricato",
    
  -- Log Messages
  LOG_REGISTERING = "|cFFD700[ScrollkeeperStandardCommands]|r Registrazione comandi slash...",
  LOG_REGISTERED = "|cFFD700[ScrollkeeperStandardCommands]|r Comandi slash registrati",
  LOG_INITIALIZING = "|cFFD700[ScrollkeeperStandardCommands]|r Inizializzazione...",
  LOG_COMPLETE = "|cFFD700[ScrollkeeperStandardCommands]|r Inizializzazione completata",
}

--------------------------------------------------------------------------------
-- ATTENDANCE
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperAttendance"] = {
  -- Module info
  SUBMENU_NAME = "Presenza Eventi",
  
  -- Description
  DESCRIPTION = "Monitora la presenza agli eventi con rilevamento automatico di ritardi/uscite anticipate.",
  
  -- Settings
  MASTER_ENABLE = "Abilita Monitoraggio Presenza Eventi",
  MASTER_ENABLE_TIP = "Abilita funzionalità e comandi di monitoraggio presenza",
  
  -- Headers
  HEADER_COMMANDS = "Comandi & Utilizzo",
  HEADER_HISTORY = "Cronologia Sessioni",
  
  -- Command help
  COMMANDS_DESC = "/sgtattendance start [nome] - Inizia monitoraggio\n/sgtattendance stop - Termina e salva\n/sgtattendance status - Controlla sessione corrente",
  
  -- Help text (for /attendance help)
  HELP_HEADER = "=== Comandi Monitoraggio Presenza ===",
  HELP_START = "/sgtattendance start [nome evento] - Inizia monitoraggio",
  HELP_STOP = "/sgtattendance stop - Ferma e salva rapporto",
  HELP_STATUS = "/sgtattendance status - Mostra informazioni sessione corrente",
  
  -- Success messages
  SUCCESS_TRACKING_STARTED = "Monitoraggio iniziato: %s (%d membri presenti)",
  SUCCESS_TRACKING_STOPPED = "Monitoraggio fermato: %s",
  SUCCESS_SAVED_TO_NOTEBOOK = "Rapporto presenza salvato nella categoria 'Eventi' del Quaderno come '%s'",
  SUCCESS_HISTORY_CLEARED = "Cronologia presenza cancellata",
  
  -- Error messages
  ERROR_ALREADY_TRACKING = "Un evento è già in monitoraggio! Usa prima /sgtattendance stop.",
  ERROR_NO_ACTIVE_SESSION = "Nessuna sessione di monitoraggio attiva",
  ERROR_UNKNOWN_COMMAND = "Comando sconosciuto. Usa /sgtattendance help",
  ERROR_NOT_SAVED = "Attenzione: Impossibile salvare nel Quaderno",
  ERROR_NOTEBOOK_DISABLED = "Quaderno non disponibile - rapporto salvato solo nella cronologia presenza",
  
  -- Status messages
  STATUS_NO_SESSION = "Nessuna sessione di monitoraggio attiva",
  STATUS_ACTIVE = "Monitoraggio: %s | Durata: %d min | Partecipanti: %d",
  
  -- Real-time log messages
  LOG_MEMBER_JOINED = "%s si è unito all'evento (%d minuti in ritardo)",
  LOG_MEMBER_LEFT = "%s ha lasciato l'evento (presente per %d minuti)",
  
  -- Report sections
  REPORT_HEADER = "Rapporto Presenza: %s",
  REPORT_TIME = "Ora: da %s a %s",
  REPORT_SUMMARY = "Totale Partecipanti: %d | Presenza Completa: %d | Arrivi in Ritardo: %d | Uscite Anticipate: %d",
  
  SECTION_FULL_ATTENDANCE = "Presenza Completa",
  SECTION_ON_TIME = "In Orario",
  SECTION_LATE = "Arrivi in Ritardo",
  SECTION_LEFT_EARLY = "Uscite Anticipate",
  
  -- History display
  NO_SESSIONS = "Nessuna sessione monitorata ancora",
  SESSIONS_COUNT = "Sessioni Monitorate: %d",
  
  -- Settings buttons
  BTN_CLEAR_HISTORY = "Cancella Cronologia",
  BTN_CLEAR_HISTORY_TIP = "Rimuovi tutte le sessioni di presenza salvate",
  WARNING_CLEAR_HISTORY = "Questo eliminerà permanentemente tutti i record di presenza!",
}

--------------------------------------------------------------------------------
-- APPLICATIONS
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperApplications"] = {
  -- Module info
  SUBMENU_NAME = "Candidature di Gilda",
  DESCRIPTION = "Registra automaticamente le candidature di gilda nel tuo Taccuino per la tenuta dei registri. Le candidature vengono salvate con tutti i dettagli, incluso il messaggio del candidato.",
  
  -- Settings
  MASTER_ENABLE = "Abilita Registrazione Candidature",
  MASTER_ENABLE_TIP = "Interruttore principale per la funzionalità di registrazione delle candidature",
  AUTO_LOG = "Registra Automaticamente Nuove Candidature",
  AUTO_LOG_TIP = "Quando abilitato, le nuove candidature di gilda vengono salvate automaticamente nel Taccuino",
  SHOW_NOTIFICATIONS = "Mostra Notifiche in Chat",
  SHOW_NOTIFICATIONS_TIP = "Visualizza un messaggio in chat quando le candidature vengono registrate",
  
  -- Guild settings
  HEADER_GUILDS = "Impostazioni per Gilda",
  GUILDS_DESC = "Scegli per quali gilde registrare le candidature:",
  GUILD_TOGGLE_TIP = "Registra candidature per %s",
 
  -- Errors
  ERROR_NOTEBOOK_UNAVAILABLE = "|cFFD700[ScrollkeeperApplications]|r Il modulo Taccuino non è disponibile. Le candidature non possono essere registrate.",
  WARNING_NOTEBOOK_MISSING = "|cFFD700[ScrollkeeperApplications]|r ATTENZIONE: Modulo Taccuino non caricato. La registrazione delle candidature non funzionerà.",
  
  SUCCESS_LOGGED_SINGLE = "|cFFD700[ScrollkeeperApplications]|r Candidatura di |cFFD700%s|r per |cFFD700%s|r registrata",
  ERROR_SAVE_FAILED = "|cFF5555[ScrollkeeperApplications]|r Impossibile salvare la candidatura di %s",
  SUCCESS_LOGGED_MULTIPLE = "|cFFD700[ScrollkeeperApplications]|r %d candidature per |cFFD700%s|r registrate",
}
-- Backward compatibility (DEPRECATED)
_G.Scrollkeeper.Localization = Scrollkeeper.Localization