local AE = AtlasAddon

AE.Translations.fr = {
    NAME = "Atlas",
    ADDON_DESCRIPTION = "Une extension Torfason × Atlas pour The Elder Scrolls Online. Révèle la carte du monde au fil de vos explorations de Tamriel.",
    PREFIX = "|cD8B36A[Atlas]|r ",
    LOADED = "chargé. /atlas help affiche les commandes.",
    HELP = [[
|cD8B36AAtlas – Commandes|r
/atlas – ouvrir les paramètres d’Atlas
/atlas help – afficher cette aide
/atlas on – activer Atlas
/atlas off – désactiver Atlas
/atlas reveal – dévoiler entièrement la carte actuelle
/atlas forget – effacer l’exploration de la carte actuelle
/atlas import – importer les données TrueExploration du personnage
/atlas importall – fusionner tous les profils TrueExploration trouvés
/atlas status – afficher les informations de la carte actuelle
/atlas archive – ouvrir les archives d’Atlas sur la carte
/atlas settings – ouvrir les paramètres
/atlas style <1-6> – choisir l’apparence de la carte inexplorée
/atlas radius <1-8> – rayon de découverte en cases
/atlas opacity <10-100> – opacité de la carte inexplorée en pourcentage
/ae est également disponible comme raccourci.

Les commandes allemandes fonctionnent aussi, par ex. /atlas hilfe, /atlas an, /atlas aufdecken.
]],
    ENABLED = "Atlas est activé.",
    DISABLED = "Atlas est désactivé.",
    CURRENT_MAP_REVEALED = "La carte actuelle a été entièrement dévoilée.",
    CURRENT_MAP_CLEARED = "Les données d’exploration de la carte actuelle ont été effacées.",
    NO_MAP = "Aucune zone de carte utilisable n’a été détectée.",
    STATUS = "Carte : %s | découverte : %d / %d cases (%.1f%%) | style : %s",
    STYLE_SET = "Style de carte inexplorée : %s",
    RADIUS_SET = "Rayon de découverte : %d cases.",
    OPACITY_SET = "Opacité : %d%%.",
    BAD_VALUE = "Valeur invalide. Utilisez /atlas help.",
    ARCHIVE_TITLE = "ARCHIVES DES CARTES",
    ARCHIVE_SUBTITLE = "Toutes les cartes sur lesquelles Atlas a déjà dessiné.",
    ARCHIVE_COUNT = "%d cartes enregistrées",
    ARCHIVE_EMPTY = "Aucune carte explorée n’a encore été enregistrée.",
    ARCHIVE_PAGE = "Page %d / %d",
    ARCHIVE_PREV = "Précédent",
    ARCHIVE_NEXT = "Suivant",
    ARCHIVE_VARIANT_LABEL = "Carte %d · ID %s",
    ARCHIVE_GROUP_EXPAND_HINT = "Cliquez pour afficher les cartes ou étages distincts.",
    ARCHIVE_GROUP_COLLAPSE_HINT = "Cliquez pour replier ce groupe de cartes.",
    ARCHIVE_FORGET = "Oublier la carte",
    ARCHIVE_FORGET_HINT = "Effacer uniquement la progression Atlas de cette carte. Une confirmation sera demandée.",
    ARCHIVE_MAP_CLEARED = "La progression d’exploration de « %s » a été effacée.",
    ARCHIVE_OPEN_HINT = "Clic gauche : ouvrir. Clic droit : révéler ou oublier cette carte.",
    ARCHIVE_REVEAL = "Révéler la carte",
    ARCHIVE_MAP_REVEALED = "La carte « %s » a été entièrement dévoilée.",
    ARCHIVE_MENU_UNAVAILABLE = "Le menu de la carte est indisponible. Aucune donnée n’a été modifiée.",
    ARCHIVE_OPEN_FAILED = "ESO ne permet pas d’ouvrir directement cette carte ici. Atlas la conserve dans les archives.",
    ARCHIVE_UNRESOLVED = "Atlas connaît cette carte, mais ne l’a pas encore associée à un identifiant ESO. Elle sera liée lors de votre prochaine visite.",
    ARCHIVE_RESOLVING = "Atlas associe les anciennes cartes enregistrées à leurs identifiants ESO en arrière-plan…",
    ARCHIVE_PATH = "Enregistré sous : %s",
    ARCHIVE_UNKNOWN_MAP = "Carte inconnue",
    IMPORT_NO_TE = "Les données TrueExploration ne sont pas chargées. Activez TrueExploration avec Atlas, rechargez l’interface et relancez l’importation.",
    IMPORT_START = "Vérification de l’importation TrueExploration…",
    IMPORT_DONE = "Importation terminée : %d cartes trouvées, %d fusionnées, %d cases ajoutées, %d entrées non reconnues.",
    IMPORT_NONE = "Le profil TrueExploration du personnage actuel est introuvable. Activez TrueExploration avec Atlas et rechargez l’interface.",
    IMPORT_NONE_ALL = "Aucune table de cartes TrueExploration trouvée dans TE_SavedVars.",
    IMPORT_ALL_WARNING = "Tous les profils TrueExploration trouvés seront fusionnés avec ce personnage.",
    STYLE_NAMES = { "Parchemin", "Papier clair", "Parchemin sombre", "Brume grise", "Charbon", "Noir profond" },
    STYLE_VALUES = AE.LanguageStyleValues,
    STYLE_TOOLTIPS = {
        "Parchemin – ancienne carte d’explorateur avec rose des vents et tracés estompés",
        "Papier clair – feuille de cartographe avec fines lignes de relevé et repères de mesure",
        "Parchemin sombre – ancienne carte marine aux côtes et pliures estompées",
        "Brume grise – brume froide avec légères courbes de niveau et voile doux",
        "Charbon – papier rugueux avec chemins dessinés à la main et anciens repères",
        "Noir profond – carte nocturne mystérieuse avec discrètes étoiles et figures de navigation",
    },
    OPTION_LANGUAGE = "Langue",
    OPTION_LANGUAGE_TT = "Choisissez uniquement la langue d’Atlas. Le mode automatique suit ESO sans modifier la langue du jeu ni celle des autres extensions.",
    LANGUAGE_AUTO = "Automatique (comme ESO)",
    SETTINGS_VERSION = "Version %s",
    SETTINGS_TITLE = "Atlas - Paramètres",
    SETTINGS_GENERAL_HEADER = "GÉNÉRAL",
    SETTINGS_APPEARANCE_HEADER = "APPARENCE",
    SETTINGS_EXPLORATION_HEADER = "EXPLORATION",
    SETTINGS_DEFAULTS = "Par défaut",
    SETTINGS_DEFAULTS_TT = "Rétablit les paramètres par défaut d’Atlas sans supprimer votre progression d’exploration.",
    SETTINGS_CLOSE = "Fermer",
    SETTINGS_CLOSE_SHORT = "X",
    SETTINGS_GEAR_TOOLTIP = "Ouvrir les paramètres d’Atlas",
    SETTINGS_SELECTED_STYLE = "%s : %s",
    OPTION_DESCRIPTION = "La carte du monde est d’abord inexplorée et se révèle là où votre personnage s’est rendu. La progression est propre à chaque personnage ; les réglages visuels sont communs au compte.",
    OPTION_ENABLED = "Activer Atlas",
    OPTION_ENABLED_TT = "Masque les zones inexplorées de la carte et révèle les lieux visités.",
    OPTION_STYLE = "Style de carte inexplorée – aperçu",
    OPTION_STYLE_TT = "Cliquez sur un aperçu pour voir les styles de carte et en choisir un.",
    OPTION_SELECTED = "Sélectionné",
    OPTION_OPACITY = "Opacité de la carte inexplorée",
    OPTION_OPACITY_TT = "100 % masque complètement la carte. Une valeur moindre laisse apparaître le fond.",
    OPTION_RADIUS = "Rayon de découverte – grandes cartes",
    OPTION_RADIUS_TT = "Nombre de cases révélées autour du personnage sur la grille de 48 × 48.",
    OPTION_SUBZONES = "Explorer les villes, donjons et cartes locales",
    OPTION_SUBZONES_TT = "Les cartes locales commencent elles aussi inexplorées lorsque cette option est activée.",
    OPTION_SUBRADIUS = "Rayon de découverte – cartes locales",
    OPTION_SUBRADIUS_TT = "Les cartes locales sont souvent plus petites ; elles peuvent utiliser un rayon distinct, plus large.",
    OPTION_CURRENT_HEADER = "Carte actuelle",
    OPTION_REVEAL = "Dévoiler toute la carte actuelle",
    OPTION_REVEAL_TT = "Marque la carte affichée comme entièrement explorée.",
    OPTION_CLEAR = "Oublier la carte actuelle",
    OPTION_CLEAR_TT = "Efface uniquement la progression d’Atlas pour la carte affichée.",
    CONFIRM_CLEAR_TITLE = "Oublier l’exploration de la carte ?",
    CONFIRM_CLEAR_TEXT = "Voulez-vous effacer toute la progression d’exploration Atlas pour « <<1>> » ? Cette action est irréversible.",
    CONFIRM_CLEAR_ACCEPT = "Oublier la carte",
    CONFIRM_CLEAR_CANCEL = "Annuler",
    CONFIRM_CLEAR_UNAVAILABLE = "La confirmation est indisponible. Aucune donnée d’exploration n’a été effacée.",

    OPTION_IMPORT_HEADER = "Importation TrueExploration",
    OPTION_IMPORT_DESC = "L’importation lit les données TrueExploration sans les modifier. Pour importer le personnage actuel, activez TrueExploration avec Atlas puis rechargez l’interface. Atlas lit la grille de 48 × 48 au format 31 bits et fusionne les chemins ne différant que par la casse.",
    OPTION_IMPORT_CURRENT = "Importer le personnage actuel",
    OPTION_IMPORT_CURRENT_TT = "Recommandé : importe uniquement les données TrueExploration du personnage connecté.",
    OPTION_IMPORT_ALL = "Fusionner tous les anciens profils",
    OPTION_IMPORT_ALL_TT = "Fusionne toutes les cartes TrueExploration trouvées avec ce personnage sans supprimer les cases Atlas existantes.",
    OPTION_COMMANDS_HEADER = "Commandes de discussion",
    OPTION_COMMANDS = "/atlas   /atlas help   /atlas reveal   /atlas forget   /atlas import   /atlas status\n/atlas style 1-6   /atlas radius 1-8   /atlas opacity 10-100",
}
