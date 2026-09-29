Scrollkeeper = Scrollkeeper or {}
Scrollkeeper.Localization = Scrollkeeper.Localization or {}

--------------------------------------------------------------------------------
-- FRAMEWORK CORE
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperFramework"] = {
  FRAMEWORK_LOADED = "Scrollkeeper Framework chargé avec succès",
  CRITICAL_ERROR = "ERREUR CRITIQUE : Impossible de créer le panneau de paramètres !",
  ERROR_REGISTERING = "ERREUR lors de l'enregistrement des paramètres",
  LAM2_UNAVAILABLE = "LibAddonMenu2 non disponible !",
  ALREADY_INITIALIZED = "Déjà initialisé, passage...",
  CHAT_BUTTONS_DISABLED = "LibChatMenuButton non disponible - boutons de chat désactivés",
  HEADER_DESC = "Framework central pour Scrollkeeper Guild Tools avec intégrations de bibliothèque améliorées. Les modules individuels ont leurs propres paramètres et ne nécessitent pas de rechargement.",
  DONATE_BUTTON = "Soutenir le Développement",
  DONATE_TOOLTIP = "Envoyer un don à @WolfStar07 sur PC/NA pour soutenir le développement continu",
  OPEN_ALL_WINDOWS = "Ouvrir Toutes les Fenêtres Scrollkeeper",
  OPEN_SETTINGS = "Ouvrir les Paramètres Scrollkeeper",
  DISPLAY_NAME = "|cF5DA81Scrollkeeper Guild Tools|r",
}

--------------------------------------------------------------------------------
-- COLOR THEMES
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperColorThemes"] = {
  -- Main
  SUBMENU_NAME = "Thèmes de Couleur",
  DESCRIPTION = "Choisissez parmi des thèmes de couleur prédéfinis pour les éléments d'interface de Scrollkeeper.",
  ACTIVE_THEME = "Thème Actif",
  ACTIVE_THEME_TOOLTIP = "Sélectionnez le thème de couleur à appliquer aux éléments d'interface de Scrollkeeper.",
  CURRENT_THEME = "Thème actuel : %s",
  
  -- Preview Section
  PREVIEW_HEADER = "Aperçu des Couleurs :",
  BORDER_COLOR = "Couleur de Bordure",
  BORDER_DESC = "Bordures et bords des fenêtres",
  HEADER_COLOR = "Couleur d'En-tête",
  HEADER_DESC = "Barres de titre et en-têtes de colonnes",
  TEXT_COLOR = "Couleur de Texte", 
  TEXT_DESC = "Texte principal et étiquettes",
  ACCENT_COLOR = "Couleur d'Accent",
  ACCENT_DESC = "Boutons mis en surbrillance et sélections",
  NOTE = "Note : Les modifications de thème s'appliquent immédiatement à toutes les fenêtres Scrollkeeper ouvertes.",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperColorThemes]|r ERREUR : ScrollkeeperFramework manquant !",
  
  -- Theme Names
  THEME_EMBER = "Braise",
  THEME_FORGE = "Forge",
  THEME_OCEAN = "Océan",
  THEME_SKY = "Ciel",
  THEME_REGALIA = "Regalia",
  THEME_BRIAR = "Ronce",
  THEME_JUNGLE = "Jungle",
  
  -- Status Messages
  STATUS_UNKNOWN = "Inconnu",
}

--------------------------------------------------------------------------------
-- PROVISIONAL MEMBER TRACKING
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperProvisionMember"] = {
  SUBMENU_NAME = "Suivi des Membres Provisoires",
  DESCRIPTION = "Suivez les membres de guilde en rangs probatoires et ceux qui ne remplissent pas les exigences de don. Utilisez |cFFD700/sgtprovision|r pour ouvrir la fenêtre de gestion.",
  MASTER_ENABLE = "Activer le Suivi des Membres Provisoires (Maître)",
  MASTER_ENABLE_TIP = "Interrupteur principal pour toutes les fonctions de suivi des membres provisoires.",
  OPEN_ADMIN = "Ouvrir la Fenêtre d'Administration",
  OPEN_ADMIN_TIP = "Ouvrir la fenêtre de gestion des membres provisoires",
  CLEAR_SCAN = "Effacer les Mauvaises Données et Scanner",
  CLEAR_SCAN_TIP = "Effacer les membres suivis de manière incorrecte et scanner pour de nouveaux",
  RESET_GOLD = "Réinitialiser les Suppressions d'Or",
  RESET_GOLD_TIP = "Effacer tous les indicateurs de suppression basés sur l'or, permettant aux membres d'être réévalués pour le suivi de l'or",
  STATUS_TRACKING = "Actuellement suivi : %d membres provisoires actifs",
  STATUS_RANK_REMOVED = "Supprimés définitivement (rang) : %d membres",
  STATUS_GOLD_REMOVED = "Supprimés temporairement (or) : %d membres",
  WINDOW_OPENED_MESSAGE = "Fenêtre ouverte. Utilisez le bouton |cFFFFFFAnalyser|r pour vérifier les membres nécessitant un suivi.",
  
  -- Window UI
  WINDOW_TITLE = "Gestion des Membres Provisoires",
  SELECT_GUILD = "Sélectionner la Guilde :",
  FILTER_LABEL = "Filtre :",
  MEMBER_NAME = "Nom du Membre",
  DAYS = "Jours",
  STATUS = "Statut de Suivi",
  NOTES = "Notes",
  ACTIONS = "Actions",
  
  -- Guild Settings
  ENABLE_FOR_GUILD = "Activer pour %s",
  ENABLE_FOR_GUILD_TIP = "Activer le suivi des membres provisoires pour cette guilde.",
  AUTO_TAG = "Marquer Automatiquement les Nouveaux Membres",
  AUTO_TAG_TIP = "Marquer automatiquement les membres répondant aux critères de suivi.",
  NOTIFY_JOIN = "Notifier Lorsque des Membres Rejoignent",
  NOTIFY_JOIN_TIP = "Afficher les notifications pour les nouveaux membres dans cette guilde.",
  PROBATION_DAYS = "Période Probatoire (Jours)",
  PROBATION_DAYS_TIP = "Combien de jours les membres restent en statut probatoire avant promotion.",
  
  -- Gold Tracking
  GOLD_HEADER = "Suivi des Exigences d'Or",
  INACTIVITY_HEADER = "Suivi d'Inactivité",
  DONOR_HEADER = "Reconnaissance des Donateurs",
  GOLD_ENABLE = "Activer le Filtre de Don d'Or",
  GOLD_ENABLE_TIP = "Suivre les membres qui n'ont pas rempli les exigences de don.",
  GOLD_AMOUNT = "Montant de Don Requis",
  GOLD_AMOUNT_TIP = "Montant d'or que les membres doivent donner pendant la période (par ex. 5000 pour cotisations de 5k).",
  GOLD_PERIOD = "Période de Temps (Jours)",
  GOLD_PERIOD_TIP = "Nombre de jours pour vérifier les dons (par ex. 30 pour cotisations mensuelles, 7 pour hebdomadaires).",
  STATUS_PENDING_DONATION = "Don en Attente",
  SOURCE_MANUAL = "Manuel",
  TIP_DAYS_MANUAL = "^ = Inclut des entrées de dons manuels",
  
  -- Statistics
  GUILD_STATS = "Statistiques de Guilde",
  NO_MEMBERS = "Aucun membre provisoire actuellement suivi pour cette guilde",
  STATS_FORMAT = "Suivi de %d membres : %d actifs, %d en retard, %d promus",
  RECENT_ADDITIONS = "Ajouts récents (7 derniers jours) : %d",
  
  -- Integration Status
  INTEGRATION_HEADER = "Sources de Données de Temps d'Adhésion et Intégration",
  AMT_AVAILABLE = "Advanced Member Tooltip - Temps d'adhésion les plus précis disponibles",
  AMT_UNAVAILABLE = "Advanced Member Tooltip - Non installé",
  AMT_INSTALL = "Installer depuis : esoui.com/downloads/info2351",
  AMT_DESC = "Fournit le suivi le plus précis du temps d'adhésion à la guilde",
  LH_READY = "LibHistoire - Prêt et traitement de l'historique de guilde",
  LH_MISSING = "LibHistoire - Non trouvé (dépendance requise)",
  DATA_AVAILABLE = "Module de Données - Suivi des dons d'or activé",
  DATA_UNAVAILABLE = "Module de Données - Filtrage d'or non disponible",
  
  -- Symbol Legend
  SYMBOL_LEGEND = "Symboles de la Colonne Jours :",
  SYMBOL_AMT = "* = Données AMT (le plus précis)",
  SYMBOL_HISTOIRE = "~ = Historique de guilde LibHistoire",
  SYMBOL_DONATION = "? = Estimation du premier don",
  SYMBOL_TAGGED = "! = Heure de début de suivi",
  SYMBOL_VALIDATED = "(pas de symbole) = Données stockées validées",
  SYMBOL_UNKNOWN = "INC = Source inconnue/peu fiable",
  SYMBOL_FOOTER = "Survolez n'importe quelle valeur de jours pour des informations détaillées sur la source.",
  TIP_SORT_NAME = "Cliquer pour trier par nom",
  TIP_SORT_DAYS = "Cliquer pour trier par jours depuis l'adhésion",

  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "[ScrollkeeperProvisionMember] ERREUR : Framework manquant !",
  ERROR_NO_GUILD_SELECTED = "Aucune guilde sélectionnée",
  ERROR_MAIL_UNAVAILABLE = "ScrollkeeperNotebookMail non disponible",
  ERROR_NO_MEMBERS_TO_MAIL = "Aucun membre à qui envoyer un courrier",
  ERROR_MAIL_WINDOW_FAILED = "Échec d'accès à la fenêtre de courrier",
  ERROR_SETTINGS_UNAVAILABLE = "Paramètres non disponibles",
  ERROR_NO_GUILDS = "Aucune guilde disponible. Rejoignez une guilde pour configurer les paramètres par guilde.",
 
  -- Success Messages
  SUCCESS_AMT_DETECTED = "Advanced Member Tooltip détecté - suivi amélioré activé",
  SUCCESS_HISTOIRE_READY = "Intégration LibHistoire prête - temps d'adhésion précis disponibles",
  SUCCESS_REMOVED = "%s supprimé du suivi",
  SUCCESS_BULK_REMOVED = "%d membres supprimés en masse du suivi",
  SUCCESS_CLEARED_DATA = "Données de suivi effacées pour %s",
  SUCCESS_CLEARED_GOLD = "%d indicateurs de suppression basés sur l'or effacés",
  SUCCESS_MAIL_OPENED = "Fenêtre de courrier ouverte avec %d membres provisoires de %s",

  -- Status Messages
  STATUS_DISABLED = "Le suivi provisoire est désactivé",
  STATUS_NO_DATA = "Aucune donnée disponible",
  STATUS_NO_TRACKING = "Aucune donnée de suivi disponible",
  STATUS_SELECT_GUILD = "Sélectionnez une guilde pour voir les statistiques",
  STATUS_NO_FILTER_MATCH = "Aucun membre ne correspond aux critères de filtre actuels.",
  STATUS_NO_SELECTED = "Aucun membre sélectionné pour promotion",
  STATUS_NO_SELECTED_REMOVE = "Aucun membre sélectionné pour suppression",

  -- Notes column - color coding descriptions (for tooltip if needed)
  NOTES_COLOR_DONATION = "Vert: Informations sur les dons",
  NOTES_COLOR_OFFLINE = "Orange: Informations hors ligne",
  NOTES_COLOR_NO_DONATION = "Rouge: Aucun don trouvé",
  
  -- Button Labels
  BTN_REFRESH = "Actualiser",
  BTN_REFRESH_TIP = "Actualiser les données de guilde et la liste des membres",
  BTN_EXPORT = "Exporter",
  BTN_EXPORT_TIP = "Exporter les données des membres vers une fenêtre de texte copiable",
  BTN_SCAN = "Scanner",
  BTN_SCAN_TIP = "Scanner les listes de guilde pour de nouveaux membres provisoires",
  BTN_VIEW_SELECTED = "Voir Sélectionnés",
  BTN_VIEW_ALL = "Voir Tous",
  BTN_VIEW_SELECTED_TIP = "Basculer entre voir tous les membres et seulement les sélectionnés",
  BTN_PROMOTE_ALL = "Promouvoir Tous",
  BTN_PROMOTE_ALL_TIP = "Ouvrir la liste de guilde pour promouvoir les membres mis en surbrillance.",
  BTN_REMOVE_ALL = "Supprimer Tous",
  BTN_REMOVE_ALL_TIP = "Supprimer tous les membres sélectionnés du suivi",
  BTN_MAIL_SELECTED = "Envoyer aux Sélectionnés",
  BTN_MAIL_SELECTED_TIP_HIGHLIGHTED = "Ouvrir la fenêtre de courrier avec les membres sélectionnés (%d)",
  BTN_MAIL_SELECTED_TIP_FILTERED = "Ouvrir la fenêtre de courrier avec les membres filtrés",
  BTN_SELECT_ALL = "Tout Sélectionner",
  BTN_CLOSE = "Fermer",

  -- Filter Labels
  FILTER_ALL = "TOUS",
  FILTER_PROBATION_ICON_TIP = "Filtrer par membres en probation",
  FILTER_GOLD_ICON_TIP = "Filtrer par membres avec faibles dons d'or",
  STATUS_INACTIVE = "Inactif",
  STATUS_DONOR = "Donateur Actif",

  -- Export Window
  EXPORT_TITLE = "Exporter les Données - Sélectionner et Copier le Texte",
  EXPORT_INSTRUCTION = "Cliquez sur 'Tout Sélectionner' puis utilisez Ctrl+C pour copier dans le presse-papiers",
  EXPORT_REPORT_HEADER = "Rapport des Membres Provisoires pour %s",
  EXPORT_GENERATED = "Généré : %s",
  EXPORT_FILTER = "Filtre : %s",
  EXPORT_VIEW_SELECTED = "Vue : Membres Sélectionnés Seulement",
  EXPORT_FILTER_ALL = "Tous les Membres",
  EXPORT_FILTER_RANK = "Membres en Probation",
  EXPORT_FILTER_GOLD = "Membres de Don d'Or",
  EXPORT_FILTER_CUSTOM = "Membres Filtrés",
  EXPORT_FORMAT = "%s | Statut : %s | Jours dans la guilde : %s | Raison : %s | Notes : %s",
  EXPORT_DAYS_NA = "N/D (filtre d'or)",
  EXPORT_DAYS_FORMAT = "%d (%s)",
  EXPORT_DAYS_ACTUAL = "réel",
  EXPORT_DAYS_ESTIMATED = "estimé",
  EXPORT_FILTER_INACTIVE = "Membres Inactifs",
  EXPORT_FILTER_DONOR = "Donateurs Actifs",

  -- Tooltips
  TIP_OPEN_ROSTER = "Ouvrir la liste des membres pour %s",
  TIP_REMOVE = "Supprimer %s du suivi",
  TIP_DAYS_HEADER = "Jours depuis l'adhésion à la guilde\n\n",
  TIP_DAYS_OFFLINE_HEADER = "Jours Hors Ligne",
  TIP_DAYS_OFFLINE_DESC = "Affiche combien de jours ce membre a été hors ligne.\nDes nombres plus élevés indiquent une inactivité plus longue.",
  TIP_DAYS_AMT = "* = Advanced Member Tooltip (le plus précis)",
  TIP_DAYS_HISTOIRE = "~ = Historique de guilde LibHistoire",
  TIP_DAYS_DONATION = "? = Estimation du premier don",
  TIP_DAYS_TAGGED = "! = Heure de début de suivi",
  TIP_DAYS_UNKNOWN = "(Inconnu - aucune source de données fiable)",
  TIP_DAYS_GOLD = "(Membre de filtre d'or)",
  TIP_DAYS_VALIDATED = "(Validé depuis les données stockées)",
  TIP_INSTALL_AMT = "Installez Advanced Member Tooltip\npour des temps d'adhésion plus précis",
  TIP_REVIEW_KICK = "Ouvrir la liste pour examiner/expulser %s (membre inactif)",
  TIP_REVIEW_PROMOTE = "Ouvrir la liste pour examiner/expulser %s (membre en probation)",
  TIP_REVIEW_DONATION = "Ouvrir la liste pour examiner %s (don en attente)",
  TIP_PROMOTE_DONOR = "Ouvrir la liste pour promouvoir %s (contributeur précieux)",
  FILTER_INACTIVE_TIP = "Afficher les membres qui ont été hors ligne pendant la période configurée",
  FILTER_DONOR_TIP = "Afficher les membres qui remplissent les exigences minimales de don",

  -- Logging Messages
  LOG_STARTING_SCAN = "Démarrage du scan manuel...",
  LOG_SCAN_COMPLETE = "Scan manuel terminé - %d entrées incorrectes effacées, %d nouveaux membres trouvés",
  LOG_REFRESHED = "Affichage actualisé",
  LOG_NEW_MEMBER = "Nouveau membre a rejoint %s : %s",
  LOG_OPENING_ROSTER_PROMOTE = "Ouverture de la liste pour promouvoir : %s",
  LOG_OPENING_ROSTER_BULK = "Ouverture de la liste - promouvoir ces %d membres : %s",
  LOG_NO_GUILD_ID = "Impossible de trouver l'ID de guilde pour : %s",
  LOG_NO_GUILD_ID_SIMPLE = "Impossible de trouver l'ID de guilde",
  LOG_FILTER_MODE = "Mode %s - %d membres sélectionnés",
  LOG_INITIALIZING = "Initialisation - %s",
  ERROR_DATA_NOT_READY = "Les données d'historique de guilde ne sont pas encore prêtes. Attendez un moment et réessayez.",
  LOG_SCAN_COMPLETE_SHORT = "Analyse terminée!",

  -- Mail Integration
  MAIL_SUBJECT_GOLD = "Rappel de Cotisations de Guilde - %s",
  MAIL_RECIPIENT_COUNT = "Destinataires Provisoires : %d",
  MAIL_STATUS = "Statut : %d membres provisoires prêts à envoyer",

  -- Stats Display
  STATS_FORMAT_FULL = "Guilde : %s | Total : %d | Actifs : %d | En retard : %d | Promus : %d | Probation : %d | Or : %d",
  STATS_LH_READY = "prêt",
  STATS_LH_LOADING = "chargement",

  -- Auto-tag Messages
  AUTO_TAG_SCAN = "Auto-marqué (scan)",
  AUTO_TAG_LOGIN = "Auto-marqué (scan de connexion)",
  AUTO_TAG_ONLINE = "Auto-marqué (rejoint en ligne)",
  ACTIVE_DONOR = "Donateur Actif",

  -- Dropdown Messages
  DROPDOWN_NO_GUILDS = "Aucune guilde configurée pour le suivi",

  -- Status Values
  STATUS_PROVISIONAL = "provisoire",
  STATUS_PROMOTED = "promu",

  -- Reason Values
  REASON_RANK = "rang",
  REASON_GOLD = "or",
  REASON_INACTIVE = "Inactif",
  REASON_DONOR = "Donateur",

  -- Integration Status (detailed)
  INTEGRATION_AMT_INSTALL_URL = "esoui.com/downloads/info2351",
  INTEGRATION_STATUS = "Statut des addons intégrés et sources de données :",

  -- Member Count Status
  MEMBER_COUNT_STATUS = "Statut du Comptage de Membres",
  MEMBER_COUNT_FORMAT = "Actuellement suivi : %d membres provisoires actifs\nSupprimés définitivement (rang) : %d membres\nSupprimés temporairement (or) : %d membres",

  -- Sources
  SOURCE_AMT = "amt",
  SOURCE_HISTOIRE = "histoire",
  SOURCE_DONATION = "don",
  SOURCE_TAGGED = "marqué",
  SOURCE_STORED = "stocké",
  SOURCE_UNKNOWN = "inconnu",
  SOURCE_DATA = "données",

  -- Days display values
  DAYS_UNKNOWN = "INC",
  DAYS_ERROR = "ERR",
  DAYS_NA = "-",
    
  -- Inactivity Filter Settings
  INACTIVITY_ENABLE = "Suivre les Membres Inactifs",
  INACTIVITY_ENABLE_TIP = "Suivre automatiquement les membres qui ont été hors ligne pendant une période prolongée",
  INACTIVITY_DAYS = "Inactif Après (Jours)",
  INACTIVITY_DAYS_TIP = "Considérer un membre comme inactif s'il ne s'est pas connecté pendant ce nombre de jours",
  
  -- Settings - Donor Filter
  DONOR_ENABLE = "Suivre les Donateurs Actifs",
  DONOR_ENABLE_TIP = "Suivre les membres qui atteignent ou dépassent les exigences minimales de don (utile pour reconnaître les contributeurs)",
  DONOR_AMOUNT = "Montant Minimum de Don",
  DONOR_AMOUNT_TIP = "Montant d'or requis pour être considéré comme un donateur actif",
  DONOR_PERIOD = "Période de Temps (Jours)",
  DONOR_PERIOD_TIP = "Vérifier les dons dans les X derniers jours",
  MANUAL_SCAN_NOTE = "Remarque: Le suivi des membres nécessite une analyse manuelle. Ouvrez la fenêtre des Membres Provisoires et cliquez sur le bouton Analyser pour vérifier les membres nécessitant un suivi.",
}

--------------------------------------------------------------------------------
-- GUILD MAIL
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperNotebookMail"] = {
  SUBMENU_NAME = "Courrier de Guilde",
  DESCRIPTION = "Composition de courrier en masse avec intégration de modèles. Les envois de courrier sont automatiquement limités à 3,1 secondes entre les messages. Utilisez |cFFD700/sgtmail|r pour ouvrir la fenêtre de courrier.",
  ENABLE_MAIL = "Activer le Courrier de Guilde",
  ENABLE_MAIL_TIP = "Activer ou désactiver la fonction de Courrier de Guilde.",
  OPEN_MAIL = "Ouvrir la Fenêtre de Courrier",
  OPEN_MAIL_TIP = "Cliquez pour ouvrir la fenêtre de composition de courrier.",
  
  -- Window UI
  WINDOW_TITLE = "Courrier de Guilde Scrollkeeper",
  MAIL_TEMPLATES = "Modèles de Courrier :",
  SELECT_TEMPLATE = "-- Sélectionner un Modèle --",
  GUILD_LABEL = "Guilde :",
  RANK_FILTER = "Filtre de Rang :",
  ALL_RANKS = "Tous les Rangs",
  PROVISIONAL_LABEL = "Membres Provisoires :",
  ALL_PROVISIONAL = "Tous les Provisoires",
  GOLD_ONLY = "Filtre d'Or Seulement",
  RANK_ONLY = "Filtre de Rang Seulement",
  USE_PROVISIONAL = "Utiliser la Liste Provisoire",
  KICK_AFTER_MAIL = "Retirer après l'envoi :",
  KICK_NO = "Ne pas retirer",
  KICK_YES = "Retirer après l'envoi",
  KICK_NO_PERMISSION = "Vous n'avez pas la permission de retirer des membres de cette guilde",
  MEMBER_KICKED = "Exclu : %s",
  MEMBER_NOT_FOUND = "Impossible de trouver le membre %s dans la liste de la guilde",
  PREVIEW_TITLE = "Aperçu du courrier",
  PREVIEW_MAIL = "Aperçu",
  
  -- Composition
  SUBJECT_LABEL = "Objet :",
  BODY_LABEL = "Corps du Message :",
  READY_TO_SEND = "Prêt à envoyer",
  STATUS_READY = "Statut : Prêt",
  RECIPIENTS = "Destinataires : %d",
  
  -- Buttons
  SAVE_TEMPLATE = "Enregistrer le Modèle",
  PREVIEW_RECIPIENTS = "Aperçu des Destinataires",
  SEND_MAIL = "Envoyer le Courrier",
  PAUSE = "Pause",
  RESUME = "Reprendre",
  
  -- Status Messages
  NO_GUILD = "Statut : Veuillez sélectionner une guilde d'abord",
  NO_SUBJECT = "Statut : Veuillez entrer un objet",
  NO_BODY = "Statut : Veuillez entrer un corps de message",
  NO_RECIPIENTS = "Statut : Aucun destinataire trouvé",
  STARTING = "Statut : Démarrage de l'envoi de courrier...",
  SENDING = "Envoi %d/%d",
  SENDING_TO = "À : %s",
  SUCCESS = "Statut : Courrier envoyé avec succès",
  FAILED = "Statut : Échec - %s",
  PAUSED = "Statut : En pause",
  COMPLETED = "Terminé : %d envoyés, %d échoués",
  TEMPLATE_SAVED = "Statut : Modèle enregistré",
  TEMPLATE_FAILED = "Statut : Échec de l'enregistrement du modèle",
  NEED_SUBJECT_BODY = "Statut : Veuillez entrer l'objet et le corps",
  RECIPIENTS_FOUND = "Statut : %d destinataires trouvés",
  NO_MATCH_FILTERS = "Statut : Aucun destinataire ne correspond aux filtres",
  PROVISIONAL_SELECTED = "Statut : %d membres provisoires sélectionnés",
  NO_PROVISIONAL = "Statut : Aucun membre provisoire trouvé",
  USING_PROVISIONAL = "Statut : Utilisation de la liste des membres provisoires...",
  
  -- Failure Reasons
  RECIPIENT_NOT_FOUND = "Destinataire non trouvé",
  MAILBOX_FULL = "Boîte aux lettres pleine",
  IGNORED = "Destinataire ignore le courrier",
  BLANK_MAIL = "Courrier vide non autorisé",
  UNKNOWN_ERROR = "Erreur inconnue",

  -- Character count display
  CHAR_COUNT = "%d/%d",

  -- Provisional member filter type display
  PROVISION_FILTER_ALL = "tous",
  PROVISION_FILTER_GOLD = "or", 
  PROVISION_FILTER_RANK = "rang",

  -- Auto-generated subject for gold filter
  DUES_REMINDER_SUBJECT = "Rappel de Cotisations de Guilde - %s",

  -- Failure log content
  FAILURE_LOG_TITLE = "Rapport d'Échec d'Envoi de Courrier",
  FAILURE_LOG_DATE = "Date : %s",
  FAILURE_LOG_SUBJECT_LINE = "Objet : %s",
  FAILURE_LOG_TOTAL_SENT = "Total Envoyés : %d",
  FAILURE_LOG_TOTAL_FAILED = "Total Échoués : %d",
  FAILURE_LOG_FAILED_LIST = "Destinataires Échoués :",
  FAILURE_LOG_SEPARATOR = string.rep("-", 50),
  FAILURE_LOG_BODY_HEADER = "Corps du Message Original :",
  FAILURE_LOG_SAVED = "Journal d'échecs enregistré dans le Carnet : '%s'",
  FAILURE_LOG_SAVE_FAILED = "Échec de l'enregistrement du journal d'échecs dans le Carnet",
  FAILURE_LOG_NO_NOTEBOOK = "Impossible d'enregistrer le journal d'échecs - Carnet non disponible",
  
  -- Mail tags
  TAG_MAIL = "courrier",
  TAG_TEMPLATE = "modèle",
  TAG_MAIL_LOG = "journal-courrier",
  TAG_FAILURES = "échecs",

  -- Failure log
  FAILURE_LOG_TITLE_FORMAT = "Échecs d'envoi - %s",
}

--------------------------------------------------------------------------------
-- NOTEBOOK
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperNotebook"] = {
  -- Main
  SUBMENU_NAME = "Paramètres du Carnet",
  WINDOW_TITLE = "Carnet Scrollkeeper",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperNotebook]|r ERREUR : ScrollkeeperFramework manquant !",
  ERROR_ALREADY_INIT = "|cFFD700[ScrollkeeperNotebook]|r Déjà initialisé, passage...",
  ERROR_WINDOW_EXISTS = "|cFFD700[ScrollkeeperNotebook]|r La fenêtre existe déjà, retour de l'existante",
  ERROR_DROPDOWN_FAILED = "|cFFD700[ScrollkeeperNotebook]|r Avertissement : Impossible de créer le menu déroulant",
  ERROR_WINDOW_NOT_INIT = "Fenêtre de carnet non initialisée.",
  ERROR_NO_NOTE_ENTRY = "Il n'y a pas d'entrée de note pour %s.",
  ERROR_DISABLED = "|cFFD700[ScrollkeeperNotebook]|r Le carnet est désactivé",
  ERROR_NO_TITLE = "|cFFD700[ScrollkeeperNotebook]|r Veuillez entrer un titre pour la note",
  ERROR_SAVE_FAILED = "|cFFD700[ScrollkeeperNotebook]|r Échec de l'enregistrement de la note",
  ERROR_TEMPLATE_NO_TITLE = "|cFFD700[ScrollkeeperNotebook]|r Veuillez entrer un titre pour le modèle",
  
  -- Success Messages
  SUCCESS_NOTE_SAVED = "|cFFD700[ScrollkeeperNotebook]|r Note enregistrée : %s",
  SUCCESS_TEMPLATE_SAVED = "|cFFD700[ScrollkeeperNotebook]|r Modèle de courrier enregistré : %s",
  
  -- Window Labels
  LABEL_SEARCH = "Rechercher :",
  LABEL_CATEGORY = "Catégorie :",
  LABEL_SAVED_NOTES = "Notes Enregistrées :",
  LABEL_NOTE_TITLE = "Titre de la Note :",
  LABEL_TAGS = "Étiquettes (séparées par des virgules) :",
  LABEL_NOTE_CONTENT = "Contenu de la Note :",
  LABEL_NOTES_COUNT = "Notes : %d/%d",
  LABEL_NOTES_SIMPLE = "Notes : %d",
  
  -- Character Counts
  CHAR_COUNT_TITLE = "%d/100",
  CHAR_COUNT_BODY = "%d/5000",
  
  -- Dropdown Options
  DROPDOWN_SELECT = "-- Sélectionner une Note --",
  DROPDOWN_NO_MATCHES = "-- Aucune correspondance trouvée --",
  
  -- Default Text
  DEFAULT_NOTE_TITLE = "Nouvelle Note",
  DEFAULT_NOTE_BODY = "Entrez votre note ici...",
  
  -- Button Labels
  BTN_SAVE = "Enregistrer",
  BTN_NEW = "Nouvelle",
  BTN_DELETE = "Supprimer",
  BTN_SAVE_MAIL = "Enregistrer Courrier",
  BTN_OPEN_NOTEBOOK = "Ouvrir le Carnet",
  
  -- Button Tooltips
  TIP_OPEN_NOTEBOOK = "Cliquez pour ouvrir la fenêtre du carnet (comme la commande /sgtnote).",
  
  -- Settings
  SETTING_ENABLE = "Activer le Module Carnet",
  SETTING_ENABLE_TIP = "Activer/désactiver la fonction Carnet.",
  SETTING_SEARCH = "Activer le Filtre de Recherche",
  SETTING_SEARCH_TIP = "Permettre le filtrage des notes par termes de recherche.",
  SETTING_DEFAULT_CATEGORY = "Catégorie par Défaut",
  SETTING_DEFAULT_CATEGORY_TIP = "Catégorie par défaut pour les nouvelles notes. Utilisez 'Courrier' pour les modèles de courrier.",
  
  -- Descriptions
  DESC_MAIN = "Un bloc-notes en jeu complet avec recherche, catégories et étiquetage. Utilisez |cFFD700/sgtnote|r pour ouvrir la fenêtre du carnet.",
  DESC_MAIL_TEMPLATES = "Modèles de courrier : Enregistrez les notes dans la catégorie 'Courrier' pour les utiliser comme modèles dans le client de courrier natif et le système de courrier de guilde.",
  
  -- Mail Integration
  MAIL_LABEL_TEMPLATES = "Modèles de Courrier :",
  MAIL_DROPDOWN_SELECT = "-- Sélectionner un Modèle --",
  
  -- Categories
  CAT_GENERAL = "Général",
  CAT_MAIL = "Courrier",
  CAT_EVENTS = "Événements",
  CAT_ALL_CATEGORIES = "Toutes les Catégories",

  ERROR_MAX_TOTAL_NOTES = "Impossible de créer la note: Nombre maximum total de notes (%d) atteint. Supprimez d'abord quelques notes.",
  ERROR_MAX_CATEGORY_NOTES = "Impossible de créer la note: Nombre maximum de notes (%d) pour la catégorie '%s' atteint.",
  ERROR_NOTE_TOO_LARGE = "La note est trop grande (%d caractères). Le maximum est de %d caractères.",
  STATS_HEADER = "Statistiques de Stockage du Carnet Scrollkeeper",
  STATS_TOTAL = "Notes Totales: %d / %d",
  STATS_CATEGORY = " %s: %d / %d notes (~%.1f Ko)",
  BTN_PREVIEW_MAIL = "Aperçu",
  PREVIEW_TITLE = "Aperçu du courrier",
  ERROR_NO_BODY = "Veuillez saisir du texte dans le corps",
  
  -- Guild Tools Integration
  GUILDMAIL_NO_TEMPLATES   = "(Utilisez 'Enregistrer comme courrier' dans le Carnet pour ajouter des modèles)",
  SETTING_GUILDMAIL_INJECT = "Afficher le sélecteur de modèles dans le courrier de guilde",
  SETTING_GUILDMAIL_INJECT_TIP = "Affiche un sélecteur de modèles de courrier du Carnet dans la fenêtre de rédaction du courrier de guilde.",
}

--------------------------------------------------------------------------------
-- HISTORY
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperHistory"] = {
  -- Main
  SUBMENU_NAME = "Recherche d'Historique de Guilde",
  WINDOW_TITLE = "Recherche d'Historique de Guilde",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperHistory]|r ERREUR : ScrollkeeperFramework manquant !",
  ERROR_WINDOW_FAILED = "|cFFD700[ScrollkeeperHistory]|r Échec de la création de la fenêtre",
  ERROR_NO_EXPORT = "|cFFD700[ScrollkeeperHistory]|r Aucun événement à exporter",
  
  -- Success Messages
  SUCCESS_READY = "|cFFD700[ScrollkeeperHistory]|r Prêt - utilisez /sgthistory",
  
  -- Log Messages
  LOG_LOADING = "|cFFD700[ScrollkeeperHistory]|r Chargement... SF.Data existe : %s",
  LOG_DATA_GETEVENTS = "|cFFD700[ScrollkeeperHistory]|r SF.Data.getEvents au chargement : %s",
  LOG_DATA_UNAVAILABLE = "|cFFD700[ScrollkeeperHistory]|r SF.Data.getEvents non disponible",
  LOG_FALLBACK_INIT = "|cFFD700[ScrollkeeperHistory]|r Initialisation de secours déclenchée",
  
  -- Window Labels
  LABEL_GUILD = "Guilde :",
  LABEL_CATEGORY = "Catégorie :",
  LABEL_SEARCH = "Rechercher :",
  LABEL_EVENTS_COUNT = "Événements : %d",
  LABEL_REFRESH = "Actualiser",
  LABEL_EXPORT = "Exporter",
  
  -- Status Messages
  STATUS_READY = "Prêt",
  STATUS_READY_LOADED = "Prêt - %d événements chargés",
  STATUS_NO_GUILD = "Aucune guilde sélectionnée",
  STATUS_DATA_NOT_READY = "Module de données non prêt",
  STATUS_NO_EVENTS_CACHE = "Aucun événement trouvé - le cache peut encore être en construction. Assurez-vous que la catégorie est active dans LibHistoire.",
  STATUS_WAITING_LH = "En attente de l'initialisation de LibHistoire...",
  STATUS_ENABLE_GUILDS = "Activez les guildes dans les paramètres d'Historique",
  
  -- Column Headers
  HEADER_TIME = "Temps",
  HEADER_CATEGORY = "Catégorie",
  HEADER_EVENT = "Événement",
  HEADER_MEMBER = "Membre",
  HEADER_DETAILS = "Détails",
  
  -- Category Names
  CAT_ALL = "Tous les Événements",
  CAT_ROSTER = "Liste",
  CAT_BANK_GOLD = "Or de Banque",
  CAT_BANK_ITEMS = "Objets de Banque",
  CAT_SALES = "Ventes",
  
  -- Event Type Names - Roster
  EVENT_INVITED = "Invité",
  EVENT_JOINED = "Rejoint",
  EVENT_PROMOTED = "Promu",
  EVENT_DEMOTED = "Rétrogradé",
  EVENT_LEFT = "Quitté",
  EVENT_KICKED = "Expulsé",
  EVENT_APP_ACCEPTED = "Candidature Acceptée",
  
  -- Event Type Names - Bank Gold
  EVENT_GOLD_DEPOSITED = "Or Déposé",
  EVENT_GOLD_WITHDRAWN = "Or Retiré",
  EVENT_TRADER_BID = "Offre de Marchand",
  EVENT_BID_RETURNED = "Offre Retournée",
  
  -- Event Type Names - Bank Items
  EVENT_ITEM_DEPOSITED = "Objet Déposé",
  EVENT_ITEM_WITHDRAWN = "Objet Retiré",
  
  -- Event Type Names - Sales
  EVENT_ITEM_SOLD = "Objet Vendu",
  
  -- Unknown Event
  EVENT_UNKNOWN = "Inconnu (%s)",
  
  -- Time Formatting
  TIME_JUST_NOW = "À l'instant",
  TIME_MINUTES_AGO = "il y a %dm",
  TIME_HOURS_AGO = "il y a %dh",
  TIME_DAYS_AGO = "il y a %dj",
  TIME_MONTHS_AGO = "il y a %dmo",
  
  -- Export Window
  EXPORT_TITLE = "Exporter les Données - Sélectionner et Copier le Texte",
  EXPORT_INSTRUCTION = "Cliquez sur 'Tout Sélectionner' puis utilisez Ctrl+C pour copier dans le presse-papiers",
  EXPORT_SELECT_ALL = "Tout Sélectionner",
  EXPORT_HEADER = "Export d'Historique de Guilde pour %s",
  EXPORT_GENERATED = "Généré : %s",
  EXPORT_CATEGORY = "Catégorie : %s",
  EXPORT_TOTAL = "Total d'Événements : %d",
  EXPORT_FORMAT = "%s | %s | %s | %s | %s",
  
  -- Tooltips
  TIP_REFRESH = "Actualiser la liste des guildes et les données d'événements",
  TIP_EXPORT = "Exporter les événements visibles vers le texte",
  TIP_FULL_TIMESTAMP = "Horodatage complet",
  TIP_FULL_DETAILS = "Détails complets",
  
  -- Settings - Main
  SETTINGS_DESC = "Rechercher les événements d'historique de guilde en cache. Utilisez |cFFD700/sgthistory|r pour ouvrir la fenêtre de recherche.\n\nLes données sont automatiquement mises en cache pour toutes les guildes par ScrollkeeperData. Ici, vous contrôlez quelles guildes et catégories afficher dans la fenêtre de recherche.",
  SETTINGS_DISPLAY = "Paramètres d'Affichage",
  SETTINGS_MAX_EVENTS = "Événements Maximum",
  SETTINGS_MAX_EVENTS_TIP = "Nombre maximum d'événements à charger à la fois",
  SETTINGS_SEARCH_DELAY = "Délai de Recherche (ms)",
  SETTINGS_SEARCH_DELAY_TIP = "Délai avant l'exécution de la recherche pendant la saisie",
  SETTINGS_COLOR_CODING = "Activer le Codage par Couleur",
  SETTINGS_COLOR_CODING_TIP = "Coder les événements par couleur selon le type",
  
  -- Settings - Per Guild
  SETTINGS_SHOW_GUILD = "Afficher dans la Fenêtre d'Historique",
  SETTINGS_SHOW_GUILD_TIP = "Afficher cette guilde dans la fenêtre de recherche d'historique",
  SETTINGS_CATEGORIES = "Catégories d'Événements à Afficher",
  SETTINGS_ROSTER_EVENTS = "Événements de Liste",
  SETTINGS_ROSTER_EVENTS_TIP = "Afficher les adhésions de membres, départs, promotions, expulsions",
  SETTINGS_BANK_GOLD_EVENTS = "Événements d'Or de Banque",
  SETTINGS_BANK_GOLD_EVENTS_TIP = "Afficher les dépôts d'or, retraits, offres de marchand",
  SETTINGS_BANK_ITEMS_EVENTS = "Événements d'Objets de Banque",
  SETTINGS_BANK_ITEMS_EVENTS_TIP = "Afficher les dépôts et retraits d'objets",
  SETTINGS_SALES_EVENTS = "Événements de Ventes",
  SETTINGS_SALES_EVENTS_TIP = "Afficher les ventes de la boutique de guilde",
  
  -- Dropdown
  DROPDOWN_NO_GUILDS = "Aucune guilde activée - voir les paramètres",
  
  -- Formatting
  FORMAT_GOLD = "%s or",
  FORMAT_QUANTITY_ITEM = "%dx %s",
  FORMAT_SOLD_TO = "à %s",
  FORMAT_RANK_ARROW = "→",
  MANUAL_ENTRY_TOOLTIP = "Ceci est un don enregistré manuellement",
  NOTES_LABEL = "Notes",
  DELETE_MANUAL_ENTRY = "Supprimer cette entrée manuelle",
  SUCCESS_DELETED_ENTRY = "Entrée manuelle supprimée avec succès",
  ERROR_DELETE_FAILED = "Échec de la suppression de l'entrée",
  
  -- Member Names
  MEMBER_UNKNOWN = "Inconnu",
    
  LOG_LIBSCROLL_NOT_FOUND = "|cFFD700[ScrollkeeperHistory]|r LibScroll introuvable - utilisation du défilement de base",
}

--------------------------------------------------------------------------------
-- ROSTER
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperRoster"] = {
  -- Main
  SUBMENU_NAME = "Amélioration de la Liste",
  
  -- Settings
  SETTING_TRADER_TIMER = "Afficher le Minuteur de Rotation de Marchand",
  SETTING_TRADER_TIMER_TIP = "Afficher le minuteur de compte à rebours montrant le temps jusqu'à la prochaine rotation du marchand de guilde.\n\n" ..
                              "La couleur du minuteur indique l'urgence :\n" ..
                              "• |c00FF0024+ hrs|r - Sûr\n" ..
                              "• |cFFFF006-24 hrs|r - Planifier à l'avance\n" ..
                              "• |cFF88002-6 hrs|r - Agir bientôt\n" ..
                              "• |cFF0000< 2 hrs|r - Urgent!",
  
  -- Timer Display
  TIMER_LABEL = "Rotation de Marchand : %s",
  TIMER_FLIPPING = "En rotation maintenant",
  TIMER_FORMAT = "%dh %dm",
  
  -- Full tooltip
  TOOLTIP_FULL = "Temps jusqu'à la rotation du marchand de guilde\n\n" ..
                 "La couleur indique l'urgence :\n" ..
                 "|c00FF0024+ heures|r - Sûr\n" ..
                 "|cFFFF006-24 heures|r - Planifier à l'avance\n" ..
                 "|cFF88002-6 heures|r - Agir bientôt\n" ..
                 "|cFF0000< 2 heures|r - Urgent!",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperRoster]|r ERREUR : ScrollkeeperFramework manquant !",
  
  -- Tasks
  TASKS_HEADER = "Rappels de Tâches",
  TASKS_DESCRIPTION = "Les rappels de tâches sont configurés par guilde ci-dessous. Activez 'Afficher les tâches sur le registre' pour chaque guilde où vous souhaitez des rappels.",
  CUSTOM_TASKS = "Tâches Personnalisées",
  CUSTOM_TASKS_DESC = "Ajoutez et configurez des tâches personnalisées. Le panneau des paramètres ne sera mis à jour qu'après un rechargement, mais la tâche sera ajoutée ou supprimée en temps réel.",
  ADD_CUSTOM_TASK = "Ajouter une Tâche Personnalisée",
  REMOVE = "Supprimer",

  -- Per-guild task toggle
  GUILD_TASKS_ENABLE = "Afficher les tâches sur le registre",
  GUILD_TASKS_ENABLE_TIP = "Activer les rappels de tâches pour la page de registre de cette guilde",

  -- Guild configuration header
  GUILD_CONFIG_DESC = "Configurer les rappels de tâches pour %s",

  -- Preset tasks section
  PRESET_TASKS_HEADER = "Tâches prédéfinies",

  -- Frequency settings
  FREQUENCY_NUMBER = "Fréquence (nombre)",
  FREQUENCY_NUMBER_TIP = "Entrez le nombre d'unités de temps",
  FREQUENCY_UNIT = "Unité",

  -- Task window
  TASK_WINDOW_TITLE = "Ajouter une tâche personnalisée",
  TASK_WINDOW_NAME_LABEL = "Nom de la tâch:",
  TASK_WINDOW_FREQ_LABEL = "Fréquence:",
  TASK_WINDOW_GUILD_LABEL = "Guildes (sélectionnez plusieurs ou 'Toutes'):",
  TASK_WINDOW_ADD = "Ajouter une tâche",
  TASK_WINDOW_CANCEL = "Annuler",

  -- Task window validation messages
  ERROR_NO_TASK_NAME = "Veuillez entrer un nom de tâche",
  ERROR_INVALID_FREQ_NUMBER = "Veuillez entrer un nombre valide pour la fréquence",
  ERROR_NO_FREQ_UNIT = "Veuillez sélectionner une unité de fréquence",

  -- Task completion messages
  TASK_COMPLETED = "Tâche terminée: %s",
  TASK_ADDED = "Tâche ajoutée : %s (guilde : %s, activée : vrai, estPersonnalisée : vrai)",
  TASK_REMOVED = "Tâche supprimée: %s",
  ERROR_PRESET_REMOVE = "Les tâches prédéfinies ne peuvent pas être supprimées. Désactivez-les dans les paramètres à la place.",

  -- Task list display
  TASK_STATUS_OVERDUE = "EN RETARD",

  -- Tooltip for task labels
  TASK_TOOLTIP_LEFT = "Clic gauche : Terminer la tâche",
  TASK_TOOLTIP_RIGHT = "Clic droit : Supprimer la tâche",

  PRESET_REVIEW_APPLICATIONS = "Examiner les candidatures",
  PRESET_CHECK_BANK_DEPOSITS = "Vérifier les dépôts bancaires",
  PRESET_UPDATE_MOTD = "Mettre à jour le message du jour",
  PRESET_PROMOTE_PROBATIONARY = "Promouvoir les probatoires",
  PRESET_REVIEW_INACTIVES = "Examiner les inactifs",

  TASK_COLOR_LEGEND = "Légende des couleurs - Temps restant :\n|c00FF00>25%|r - Sûr\n|cFFFF0010-25%|r - Planifier à l'avance\n|cFF88005-10%|r - Agir bientôt\n|cFF0000<5% ou en retard|r - Urgent!",
    
  -- Remove Button
  REMOVE_CUSTOM_TASK = "Supprimer une Tâche Personnalisée",
  REMOVE_CUSTOM_TASK_TIP = "Sélectionner une tâche personnalisée à supprimer définitivement",
  REMOVE_WARNING = "ATTENTION : La suppression est définitive ! Pour restaurer une tâche, vous devez l'ajouter à nouveau manuellement.",
  REMOVE_INSTRUCTION = "Cliquez sur une tâche ci-dessous pour la supprimer :",
  REMOVE_WINDOW_CANCEL = "Annuler",
}

--------------------------------------------------------------------------------
-- CONTEXT MENU
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperContextMenu"] = {
  SUBMENU_NAME = "Options de Menu Contextuel",
  DESCRIPTION = "Ajoute des entrées de nouveau courrier, invitation de guilde et invitation de chat à tous les menus contextuels de clic droit.",
  MASTER_ENABLE = "Activer les Fonctions de Menu Contextuel",
  MASTER_ENABLE_TIP = "Interrupteur principal pour toutes les améliorations du menu contextuel.",
  SF_UNAVAILABLE = "ERREUR : ScrollkeeperFramework manquant !",
  
  -- Headers
  SCROLLKEEPER_TOOLS = "Outils Scrollkeeper",
  CHAT_HEADER = "Options de Chat",
  ROSTER_HEADER = "Options de Liste de Guilde",
  
  -- Options
  NEW_MAIL = "Nouveau Courrier",
  NEW_MAIL_TIP = "Ajouter l'option 'Nouveau Courrier' aux menus contextuels de chat.",
  GUILD_INVITE = "Invitation de Guilde",
  GUILD_INVITE_TIP = "Ajouter des options d'invitation de guilde aux menus contextuels de chat.",
  ROSTER_DESC = "Ajoute l'intégration du carnet au menu contextuel de clic droit de la liste de guilde.",
  NOTEBOOK_CONTEXT = "Activer le Menu Contextuel du Carnet",
  NOTEBOOK_CONTEXT_TIP = "Clic droit sur les membres de guilde pour ouvrir ou créer des entrées de carnet.",
  ROSTER_INVITE = "Invitation de Guilde depuis la Liste",
  ROSTER_INVITE_TIP = "Ajouter des options d'invitation de guilde aux menus contextuels de la liste de guilde.",
  
  -- Context Menu Items
  INVITE_TO = "Inviter à %s",
  GO_TO_NOTEBOOK = "Aller à l'Entrée du Carnet",
  MAKE_NOTE = "Créer une Note dans le Carnet",
  
  -- Messages
  NOTEBOOK_NOT_FOUND = "Module carnet non trouvé.",
  NOTE_EXISTS = "La note existe déjà pour %s.",
  NOTE_CREATED = "Note créée pour %s dans le Carnet.",
  OPEN_NOTE = "Ouvrir l'Entrée du Carnet",
  CREATE_NOTE = "Créer une Note dans le Carnet",
  LOG_CONVERSATION = "Enregistrer le Chat Récent",
  CONVERSATION_LOGGED = "Enregistré %d messages récents impliquant %s dans le Carnet sous la catégorie 'Chat'",
  NO_CONVERSATION = "Aucun chat récent trouvé impliquant %s dans les 100 derniers messages.",
  LOG_CONVERSATIONS = "Activer l'Enregistrement des Conversations",
  LOG_CONVERSATIONS_TIP = "Enregistrer les conversations de chat dans le Carnet (nécessite l'addon pChat).",
  PCHAT_WARNING = "Addon pChat non détecté - cette fonction ne fonctionnera pas",
  
  -- Mail Items
  LOG_DONATION = "Enregistrer un Don",
  LOG_DONATION_TIP = "Enregistrer manuellement un don pour ce joueur",
  DONATION_WINDOW_TITLE = "Enregistrer un Don Manuel",
  DONATION_PLAYER = "Joueur",
  DONATION_GUILD = "Guilde",
  DONATION_VALUE_LABEL = "Valeur en Or",
  DONATION_VALUE_TIP = "Entrez la valeur en or de ce don (pour les objets, entrez leur valeur estimée)",
  DONATION_NOTES_LABEL = "Notes (Optionnel)",
  DONATION_NOTES_TIP = "Détails supplémentaires comme 'Envoyé 50 Cire de Dreugh par courrier' ou 'Or envoyé le 25/12'",
  DONATION_TYPE_LABEL = "Type de Don",
  DONATION_TYPE_GOLD = "Or (Courrier)",
  DONATION_TYPE_ITEMS = "Objets (Évalués)",
  BTN_RECORD_DONATION = "Enregistrer le Don",
  BTN_CANCEL = "Annuler",
  SUCCESS_DONATION_LOGGED = "Don de %d or enregistré pour %s",
  ERROR_INVALID_AMOUNT = "Veuillez entrer un montant d'or valide",
}

--------------------------------------------------------------------------------
-- DATA MODULE
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperData"] = {
  -- Module Info
  DESCRIPTION = "Service de mise en cache en arrière-plan pour les données d'historique de guilde utilisant LibHistoire.",
  
  -- Status Messages
  HISTOIRE_READY = "LibHistoire prêt - mise en cache de tout l'historique de guilde",
  CACHE_STATUS = "=== Statut du Cache d'Événements ===",
  NO_CACHED_DATA = "Aucune donnée en cache trouvée",
  CACHE_EMPTY = "Le cache est vide - cela peut prendre quelques minutes au premier chargement",
  WAITING_FOR_HISTOIRE = "En attente de l'initialisation de LibHistoire...",
  
  -- Log Messages
  EVENTS_CACHED = "%s/%s : %d événements en cache",
  STARTED_CACHING = "Démarrage de la mise en cache de %d guildes",
  MODULE_LOADED = "|cFFD700[ScrollkeeperData]|r Chargé - service de mise en cache en arrière-plan",
  LOG_MANUAL_DONATION = "%s - %d or enregistré manuellement",
  MANUAL_DONATION_SOURCE = "Entrée Manuelle",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperData]|r ERREUR : ScrollkeeperFramework manquant !",
  ERROR_DATA_NOT_TABLE = "|cFFD700[ScrollkeeperData]|r CRITIQUE : SF.Data n'est pas une table !",
  ERROR_HISTOIRE_NOT_FOUND = "|cFFD700[ScrollkeeperData]|r ERREUR : LibHistoire non trouvé !",
  
  -- Cache Display
  GUILD_HEADER = "%s :",
  CATEGORY_LINE = "  %s : %d événements",
  HISTOIRE_STATUS = "LibHistoire prêt : %s",
  
  -- Category Names (for display)
  CAT_ROSTER = "liste",
  CAT_BANKED_GOLD = "orBanque",
  CAT_BANKED_ITEMS = "objetsBanque",
  CAT_SALES = "ventes",
  
  -- Manual donation logging
  LOG_MANUAL_DONATION = "|cFFD700[ScrollkeeperData]|r Enregistré : %d or de %s vers %s",
  
  -- Delete entry messages
  ERROR_DELETE_MISSING_PARAMS = "|cFFD700[ScrollkeeperData]|r deleteManualEntry : Paramètres requis manquants",
  SUCCESS_DELETE_ENTRY = "|cFFD700[ScrollkeeperData]|r Entrée manuelle supprimée avec succès du cache et du stockage",
  ERROR_DELETE_NOT_FOUND = "|cFFD700[ScrollkeeperData]|r deleteManualEntry : Entrée introuvable",
  
  -- Debug cache messages
  DEBUG_NO_GUILD = "[Débogage Données] Aucune guilde spécifiée",
  DEBUG_NO_CACHE_FOR_GUILD = "[Débogage Données] Pas de cache pour la guilde : %s",
  DEBUG_AVAILABLE_GUILDS = "[Débogage Données] Guildes disponibles :",
  DEBUG_GUILD_LIST_ITEM = "  - %s",
  DEBUG_CACHE_FOR_GUILD = "[Débogage Données] Cache pour %s :",
  DEBUG_BANKED_GOLD_COUNT = "  bankedGold : %d événements",
  DEBUG_RECENT_DEPOSITS = "  Dépôts récents :",
  DEBUG_NO_DEPOSITS = "  Aucun dépôt trouvé",
  DEBUG_BANKED_GOLD_MISSING = "  bankedGold : NON PRÉSENT",
  DEBUG_ROSTER_COUNT = "  roster : %d événements",
  DEBUG_ROSTER_MISSING = "  roster : NON PRÉSENT",
  
  -- Slash command messages
  ERROR_DATA_MODULE_UNAVAILABLE = "Module de données ou fonction de vérification non disponible",
  CMD_CHECKGOLD_USAGE = "Utilisation : /sgtcheckgold NomGuilde|@NomAffichage|Jours",
  CMD_CHECKGOLD_EXAMPLE = "Exemple : /sgtcheckgold Dragon's Nest Thievery Co|@VotreNom|14",
  CMD_CHECKGOLD_RESULT = "%s a donné %d or au cours des %d derniers jours (%s)",
  
  -- Initialization
  ERROR_LIBHISTOIRE_MISSING = "|cFFD700[ScrollkeeperData]|r ERREUR : LibHistoire introuvable",
}

--------------------------------------------------------------------------------
-- WELCOME MESSAGES
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperWelcome"] = {
  SUBMENU_NAME = "Messages de Bienvenue",
  DESCRIPTION = "Configurez les messages de bienvenue pour les membres de la guilde. Utilisez %1 pour le nom du joueur et %2 pour le nom de la guilde. Les messages seront mis en file d'attente lors de l'acceptation de plusieurs candidatures ou si le champ de texte est actif.",
  MASTER_ENABLE = "Activer les Messages de Bienvenue",
  MASTER_ENABLE_TIP = "Activer ou désactiver tous les messages de bienvenue.",
  LOG_MEMBER_JOINED = "|cFFD700[ScrollkeeperWelcome]|r %s a rejoint %s en tant que %s",
  
  -- Template
  TEMPLATE_HEADER = "Variables de Modèle",
  VAR_PLAYER = "%1 - Nom du Joueur",
  VAR_GUILD = "%2 - Nom de la Guilde",
  
  -- Guild Settings
  ENABLE_FOR_GUILD = "Activer pour cette Guilde",
  MESSAGE_TEMPLATE = "Modèle de Message",
  PREVIEW = "Aperçu : %s",
  DEFAULT_MESSAGE = "Bienvenue %1 à %2",
}

--------------------------------------------------------------------------------
-- STANDARD COMMANDS
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperStandardCommands"] = {
  -- Main
  SUBMENU_NAME = "Commandes de Chat et Utilitaires",
  DESCRIPTION = "Commandes utilitaires supplémentaires et support d'affectation de touches pour Scrollkeeper.",
  
  -- Headers
  COMMANDS_HEADER = "Commandes Disponibles",
  UTILITY_HEADER = "Commandes Utilitaires",
  STATUS_HEADER = "Commandes de Statut",
  MODULE_HEADER = "Commandes de Module",
  DEBUG_HEADER = "Commandes de Débogage",
  
  -- Command Documentation
  CMD_SKDEBUG = "|cf3ebd1/skdebug|r - Afficher les informations de débogage du système",
  CMD_SKTEST = "|cf3ebd1/sktest <option>|r - Exécuter les tests de module (options : context, settings, notebook, mail, data)",
  CMD_SGTNOTE = "|cf3ebd1/sgtnote|r - Basculer la fenêtre du carnet",
  CMD_SGTMAIL = "|cf3ebd1/sgtmail|r - Ouvrir la fenêtre de courrier",
  CMD_SGTHISTORY = "|cf3ebd1/sgthistory|r - Ouvrir la fenêtre de recherche d'historique",
  CMD_SGTPROVISION = "|cf3ebd1/sgtprovision|r - Ouvrir la fenêtre des membres provisoires",
  CMD_SGTCACHE = "|cf3ebd1/sgtcache|r - Afficher le statut du cache d'événements",
  CMD_ROLL = "|cf3ebd1/roll <nombre>|r - Lancer les dés (exemple : /roll 20)",
  CMD_DICE = "|cf3ebd1/dice <nombre>|r - Identique à /roll",
  CMD_RL = "|cf3ebd1/rl|r - Recharger l'interface",
  CMD_ON = "|cf3ebd1/on|r - Définir le statut sur En ligne",
  CMD_OFF = "|cf3ebd1/off|r - Définir le statut sur Hors ligne",
  CMD_AFK = "|cf3ebd1/afk|r - Définir le statut sur Absent",
  CMD_DND = "|cf3ebd1/dnd|r - Définir le statut sur Ne Pas Déranger",
  CMD_OFFL = "|cf3ebd1/offl|r - Basculer En ligne/Hors ligne",
  
  -- Full command list
  COMMAND_LIST = "|cf3ebd1/sgtnote|r - Basculer la fenêtre du carnet\n" ..
                "|cf3ebd1/sgtmail|r - Ouvrir la fenêtre de courrier\n" ..
                "|cf3ebd1/sgthistory|r - Ouvrir la recherche d'historique\n" ..
                "|cf3ebd1/sgtprovision|r - Ouvrir la fenêtre des membres provisoires\n" ..
                "|cf3ebd1/roll <nombre>|r - Lancer les dés\n" ..
                "|cf3ebd1/rl|r - Recharger l'interface\n" ..
                "|cf3ebd1/on /off /afk /dnd|r - Définir le statut du joueur\n" ..
                "|cf3ebd1/offl|r - Basculer hors ligne\n" ..
                "|cf3ebd1/skdebug|r - Afficher les infos de débogage\n" ..
                "|cf3ebd1/sgtcache|r - Afficher le statut du cache",
				"|cf3ebd1/sgtcheckpm NomGuilde|@NomAffichage|r - Déboguer la vérification de don d'or pour un membre spécifique\n" ..
				"|cf3ebd1/sgtattendance start [nom événement]|r - Commencer le suivi\n" ..
				"|cf3ebd1/sgtattendance stop|r - Arrêter et enregistrer le rapport\n" ..
				"|cf3ebd1/sgtattendance status|r - Afficher les informations de session actuelle" ..
				"|cf3ebd1/sgttask add <nom>|<fréquence>|<guilde>|r pour ajouter une tâche personnalisée" ..
				"|cf3ebd1/sgttask list|r - Afficher toutes les tâches avec état" ..
				"|cf3ebd1/sgttask complete <numéro>|r - Marquer la tâche comme terminée",
  
  -- Buttons
  TEST_BUTTON = "Tester Tous les Systèmes",
  TEST_BUTTON_TIP = "Exécuter un test complet de tous les modules Scrollkeeper",
  
  -- Status Messages
  STATUS_ONLINE = "Statut défini sur En ligne",
  STATUS_OFFLINE = "Statut défini sur Hors ligne",
  STATUS_DND = "Statut défini sur Ne Pas Déranger",
  STATUS_AWAY = "Statut défini sur Absent",
  STATUS_CHANGED = "Scrollkeeper : Statut défini sur %s",
  STATUS_TOGGLED = "Fenêtre du carnet basculée",
  
  -- Roll Messages
  ROLL_USAGE = "Utilisation : /roll <max>",
  ROLL_EXAMPLE = "Exemple : /roll 20",
  ROLL_INVALID = "Nombre invalide : %s",
  ROLL_OUTPUT = "a lancé %d (1-%d)",
  
  -- Debug Messages
  DEBUG_HEADER = "=== Infos de Débogage Scrollkeeper ===",
  DEBUG_FRAMEWORK = "Framework chargé : %s",
  DEBUG_SETTINGS = "Table de paramètres : %s",
  DEBUG_LAM = "LAM2 disponible : %s",
  DEBUG_FUNC = "SF.func disponible : %s",
  DEBUG_GET_SETTINGS = "SF.getModuleSettings : %s",
  DEBUG_PANEL = "Panneau enregistré : %s",
  DEBUG_MODULE = "Module : %s - Contrôles : %d - Icône : %s",
  DEBUG_TOTAL_MODULES = "Total de modules enregistrés : %d",
  DEBUG_NO_MODULES = "Aucun paramètre de module trouvé",
  DEBUG_CONTEXT = "Menu contextuel activé : %s",
  DEBUG_NOTEBOOK = "Module carnet : %s",
  DEBUG_DATA = "Module de données : %s",
  DEBUG_HISTOIRE = "LibHistoire : %s",
  DEBUG_DATETIME = "LibDateTime : %s",
  
  -- Test Messages
  TEST_HEADER = "=== Commandes de Test Scrollkeeper ===",
  TEST_USAGE = "Utilisation : /sktest <option>",
  TEST_OPTIONS = "Options : context, settings, notebook, mail, data, attendance",
  TEST_RUNNING = "Exécution du test système complet...",
  TEST_UNKNOWN = "Option de test inconnue : %s",
  TEST_AVAILABLE = "Options disponibles : context, settings, notebook, mail, data, attendance",
  
  -- Test: Context
  TEST_CONTEXT_HEADER = "=== Test de Menu Contextuel ===",
  TEST_CONTEXT_ACTIVE = "Le crochet du menu contextuel est actif",
  TEST_CONTEXT_ENABLED = "Menu contextuel activé dans les paramètres : %s",
  TEST_CONTEXT_MAIL = "Option de nouveau courrier de chat : %s",
  TEST_CONTEXT_INVITE = "Option d'invitation de chat : %s",
  TEST_CONTEXT_NOT_LOADED = "Module ScrollkeeperContextMenu non chargé",
  TEST_CONTEXT_FAILED = "Crochet du menu contextuel ÉCHOUÉ - CHAT_SYSTEM non disponible",
  
  -- Test: Settings
  TEST_SETTINGS_HEADER = "=== Test de Paramètres ===",
  TEST_SETTINGS_ACCESSIBLE = "Paramètres %s accessibles : %s",
  TEST_SETTINGS_PANEL = "Le panneau de paramètres est enregistré",
  TEST_SETTINGS_NO_PANEL = "Panneau de paramètres non enregistré",
  TEST_SETTINGS_NO_ACCESS = "Impossible d'accéder aux paramètres du module - problème de framework",
  
  -- Test: Notebook
  TEST_NOTEBOOK_HEADER = "=== Test de Carnet ===",
  TEST_NOTEBOOK_LOADED = "Module carnet chargé",
  TEST_NOTEBOOK_ENABLED = "Activé : %s",
  TEST_NOTEBOOK_WINDOW = "Fenêtre du carnet existe : %s",
  TEST_NOTEBOOK_SAVE = "Test d'enregistrement de note : %s",
  TEST_NOTEBOOK_NOT_LOADED = "Module carnet non chargé",
  
  -- Test: Mail
  TEST_MAIL_HEADER = "=== Test de Module de Courrier ===",
  TEST_MAIL_LOADED = "Module de courrier chargé",
  TEST_MAIL_ENABLED = "Activé : %s",
  TEST_MAIL_WINDOW = "Fenêtre de courrier existe : %s",
  TEST_MAIL_COMMAND = "Commande /sgtmail enregistrée",
  TEST_MAIL_NO_COMMAND = "Commande /sgtmail non enregistrée",
  TEST_MAIL_NOT_LOADED = "Module de courrier non chargé",
  
  -- Test: Data
  TEST_DATA_HEADER = "=== Test de Module de Données ===",
  TEST_DATA_LOADED = "Module de données chargé",
  TEST_DATA_LH_AVAILABLE = "LibHistoire disponible",
  TEST_DATA_CACHE_ACCESSIBLE = "Cache d'événements accessible : %s",
  TEST_DATA_RECORDS = "Total d'enregistrements d'événements en cache : %d",
  TEST_DATA_NO_FUNCTIONS = "Fonctions de données non disponibles",
  TEST_DATA_NO_LH = "LibHistoire non disponible",
  TEST_DATA_NOT_LOADED = "Module de données non chargé",
  
  -- Error Messages
  ERROR_FRAMEWORK_MISSING = "|cFFD700[ScrollkeeperStandardCommands]|r ERREUR : ScrollkeeperFramework manquant !",
  ERROR_NOTEBOOK_DISABLED = "Le carnet est désactivé dans les paramètres",
  ERROR_NOTEBOOK_NO_WINDOW = "Fenêtre du carnet non disponible",
  ERROR_NOTEBOOK_NOT_LOADED = "Module carnet non chargé",
  
  -- Log Messages
  LOG_REGISTERING = "|cFFD700[ScrollkeeperStandardCommands]|r Enregistrement des commandes slash...",
  LOG_REGISTERED = "|cFFD700[ScrollkeeperStandardCommands]|r Commandes slash enregistrées",
  LOG_INITIALIZING = "|cFFD700[ScrollkeeperStandardCommands]|r Initialisation...",
  LOG_COMPLETE = "|cFFD700[ScrollkeeperStandardCommands]|r Initialisation terminée",
}

--------------------------------------------------------------------------------
-- ATTENDANCE
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperAttendance"] = {
  -- Module info
  SUBMENU_NAME = "Présence aux Événements",
  
  -- Description
  DESCRIPTION = "Suivre la présence aux événements avec détection automatique des retards/départs anticipés.",
  
  -- Settings
  MASTER_ENABLE = "Activer le Suivi de Présence aux Événements",
  MASTER_ENABLE_TIP = "Activer les fonctionnalités et commandes de suivi de présence",
  
  -- Headers
  HEADER_COMMANDS = "Commandes & Utilisation",
  HEADER_HISTORY = "Historique des Sessions",
  
  -- Command help
  COMMANDS_DESC = "/sgtattendance start [nom] - Commencer le suivi\n/sgtattendance stop - Terminer et enregistrer\n/sgtattendance status - Vérifier la session actuelle",
  
  -- Help text (for /attendance help)
  HELP_HEADER = "=== Commandes de Suivi de Présence ===",
  HELP_START = "/sgtattendance start [nom événement] - Commencer le suivi",
  HELP_STOP = "/sgtattendance stop - Arrêter et enregistrer le rapport",
  HELP_STATUS = "/sgtattendance status - Afficher les informations de session actuelle",
  
  -- Success messages
  SUCCESS_TRACKING_STARTED = "Suivi commencé: %s (%d membres présents)",
  SUCCESS_TRACKING_STOPPED = "Suivi arrêté: %s",
  SUCCESS_SAVED_TO_NOTEBOOK = "Rapport de présence enregistré dans la catégorie 'Événements' du Carnet sous '%s'",
  SUCCESS_HISTORY_CLEARED = "Historique de présence effacé",
  
  -- Error messages
  ERROR_ALREADY_TRACKING = "Un événement est déjà suivi! Utilisez d'abord /sgtattendance stop.",
  ERROR_NO_ACTIVE_SESSION = "Aucune session de suivi active",
  ERROR_UNKNOWN_COMMAND = "Commande inconnue. Utilisez /sgtattendance help",
  ERROR_NOT_SAVED = "Attention: Impossible d'enregistrer dans le Carnet",
  ERROR_NOTEBOOK_DISABLED = "Carnet non disponible - rapport enregistré uniquement dans l'historique de présence",
  
  -- Status messages
  STATUS_NO_SESSION = "Aucune session de suivi active",
  STATUS_ACTIVE = "Suivi: %s | Durée: %d min | Participants: %d",
  
  -- Real-time log messages
  LOG_MEMBER_JOINED = "%s a rejoint l'événement (%d minutes de retard)",
  LOG_MEMBER_LEFT = "%s a quitté l'événement (présent pendant %d minutes)",
  
  -- Report sections
  REPORT_HEADER = "Rapport de Présence: %s",
  REPORT_TIME = "Heure: %s à %s",
  REPORT_SUMMARY = "Total Participants: %d | Présence Complète: %d | Arrivées en Retard: %d | Départs Anticipés: %d",
  
  SECTION_FULL_ATTENDANCE = "Présence Complète",
  SECTION_ON_TIME = "À l'Heure",
  SECTION_LATE = "Arrivées en Retard",
  SECTION_LEFT_EARLY = "Départs Anticipés",
  
  -- History display
  NO_SESSIONS = "Aucune session suivie pour le moment",
  SESSIONS_COUNT = "Sessions Suivies: %d",
  
  -- Settings buttons
  BTN_CLEAR_HISTORY = "Effacer l'Historique",
  BTN_CLEAR_HISTORY_TIP = "Supprimer toutes les sessions de présence enregistrées",
  WARNING_CLEAR_HISTORY = "Cela supprimera définitivement tous les enregistrements de présence!",
}

--------------------------------------------------------------------------------
-- APPLICATIONS
--------------------------------------------------------------------------------
Scrollkeeper.Localization["ScrollkeeperApplications"] = {
  -- Module info
  SUBMENU_NAME = "Candidatures de Guilde",
  DESCRIPTION = "Enregistre automatiquement les candidatures de guilde dans votre Carnet pour la tenue de registres. Les candidatures sont enregistrées avec tous les détails, y compris le message du candidat.",
  
  -- Settings
  MASTER_ENABLE = "Activer l'Enregistrement des Candidatures",
  MASTER_ENABLE_TIP = "Interrupteur principal pour la fonctionnalité d'enregistrement des candidatures",
  AUTO_LOG = "Enregistrer Automatiquement les Nouvelles Candidatures",
  AUTO_LOG_TIP = "Lorsqu'activé, les nouvelles candidatures de guilde sont automatiquement enregistrées dans le Carnet",
  SHOW_NOTIFICATIONS = "Afficher les Notifications de Chat",
  SHOW_NOTIFICATIONS_TIP = "Afficher un message dans le chat lorsque les candidatures sont enregistrées",
  
  -- Guild settings
  HEADER_GUILDS = "Paramètres par Guilde",
  GUILDS_DESC = "Choisissez pour quelles guildes enregistrer les candidatures :",
  GUILD_TOGGLE_TIP = "Enregistrer les candidatures pour %s",

  -- Errors
  ERROR_NOTEBOOK_UNAVAILABLE = "|cFFD700[ScrollkeeperApplications]|r Le module Carnet n'est pas disponible. Les candidatures ne peuvent pas être enregistrées.",
  WARNING_NOTEBOOK_MISSING = "|cFFD700[ScrollkeeperApplications]|r ATTENTION : Module Carnet non chargé. L'enregistrement des candidatures ne fonctionnera pas.",
  
  SUCCESS_LOGGED_SINGLE = "|cFFD700[ScrollkeeperApplications]|r Candidature de |cFFD700%s|r pour |cFFD700%s|r enregistrée",
  ERROR_SAVE_FAILED = "|cFF5555[ScrollkeeperApplications]|r Échec de l'enregistrement de la candidature de %s",
  SUCCESS_LOGGED_MULTIPLE = "|cFFD700[ScrollkeeperApplications]|r %d candidatures pour |cFFD700%s|r enregistrées",
}
-- Backward compatibility (DEPRECATED)
_G.Scrollkeeper.Localization = Scrollkeeper.Localization