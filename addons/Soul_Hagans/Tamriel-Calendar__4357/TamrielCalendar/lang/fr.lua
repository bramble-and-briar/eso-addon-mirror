TamrielCalendar = TamrielCalendar or {}
local TC = TamrielCalendar

local fr = {
    days = {"Sandaas", "Morndaas", "Tirdaas", "Middaas", "Turdaas", "Fredaas", "Loredaas"},
    shortDays = {"Sa", "Mo", "Ti", "Mi", "Tu", "Fr", "Lo"},
    months = {"Étoile du matin", "Clair de ciel", "Premier semer", "Pluie de main", "Deuxième semer", "Mi-l'an", "Haut zénith", "Dernier semer", "Âtrefeu", "Soufflegivre", "Sommeil du soleil", "Étoile du soir"},
    realMonths = {"Janvier", "Février", "Mars", "Avril", "Mai", "Juin", "Juillet", "Août", "Septembre", "Octobre", "Novembre", "Décembre"},
    signs = {"Le Rituel", "L'Amant", "Le Seigneur", "Le Mage", "L'Ombre", "Le Destrier", "L'Apprenti", "Le Guerrier", "La Dame", "La Tour", "L'Atronach", "Le Voleur", "Le Serpent"},
    moonPhases = {"Nouvelle lune", "Premier croissant", "Premier quartier", "Lune gibbeuse", "Pleine lune", "Lune décroissante", "Dernier quartier", "Dernier croissant"},
    yearSuffix = "2ème Ère",
    monthPrefix = "Mois de",
    signPrefix = "Signe:",
    stripFormat = "%s, %d %s %d | %s | %02d:%02d",
    titleHoliday = "Jour férié:",
    btnPrev = "Précédent",
    btnNext = "Suivant",
    hNames = {
        nl = "Nouvelle vie",
        hd = "Jour du Coeur",
        aj = "Jubilé ESO",
        jd = "Jour de la Farce",
        zz = "Jour de Zenithar",
        wf = "Festival des Sorcières"
    }
}

for k, v in pairs(fr) do
    TC.L[k] = v
end

ZO_CreateStringId("SI_BINDING_NAME_TC_TOGGLE_UI", "Afficher/Masquer le bandeau")
ZO_CreateStringId("SI_BINDING_NAME_TC_TOGGLE_WINDOW", "Ouvrir le grand calendrier")

-- Settings Panel Strings (FR)
ZO_CreateStringId("SI_TC_SECTION_APPEARANCE", "Apparence du bandeau")
ZO_CreateStringId("SI_TC_AUTO_WIDTH_NAME", "Largeur automatique")
ZO_CreateStringId("SI_TC_AUTO_WIDTH_TIP", "Le bandeau ajuste automatiquement sa largeur à la longueur du texte.")
ZO_CreateStringId("SI_TC_STRIP_WIDTH_NAME", "Largeur fixe (px)")
ZO_CreateStringId("SI_TC_STRIP_WIDTH_TIP", "Fonctionne uniquement lorsque la largeur automatique est désactivée.")
ZO_CreateStringId("SI_TC_STRIP_HEIGHT_NAME", "Hauteur du bandeau (px)")
ZO_CreateStringId("SI_TC_STRIP_ALPHA_NAME", "Opacité de l'arrière-plan (%)")
ZO_CreateStringId("SI_TC_STRIP_LOCK_NAME", "Verrouiller le bandeau")
ZO_CreateStringId("SI_TC_STRIP_LOCK_TIP", "Verrouille le bandeau pour éviter tout déplacement accidentel.")

ZO_CreateStringId("SI_TC_SECTION_FONT", "Paramètres de police et de texte")
ZO_CreateStringId("SI_TC_TEXT_COLOR_NAME", "Couleur du texte")
ZO_CreateStringId("SI_TC_TEXT_COLOR_TIP", "Choisissez la couleur du texte sur le bandeau.")
ZO_CreateStringId("SI_TC_FONT_FAMILY_NAME", "Police de caractères")
ZO_CreateStringId("SI_TC_FONT_SIZE_NAME", "Taille de la police (px)")
ZO_CreateStringId("SI_TC_FONT_STYLE_NAME", "Style d'ombre / contour")

-- Font Dropdown Choices
ZO_CreateStringId("SI_TC_FONT_CHOICE_BOLD", "Système Gras (Univers Bold)")
ZO_CreateStringId("SI_TC_FONT_CHOICE_REGULAR", "Système Standard (Univers Regular)")
ZO_CreateStringId("SI_TC_FONT_CHOICE_MEDIUM", "Système Moyen (Univers Medium)")
ZO_CreateStringId("SI_TC_FONT_CHOICE_GAME", "Police d'interface du jeu")
ZO_CreateStringId("SI_TC_FONT_CHOICE_ANTIQUE", "Livre / Parchemins (Antique)")
ZO_CreateStringId("SI_TC_FONT_CHOICE_HANDWRITTEN", "Manuscrit / Notes")
ZO_CreateStringId("SI_TC_FONT_CHOICE_STONE", "Tablette de pierre / Titres")

-- Shadow Dropdown Choices
ZO_CreateStringId("SI_TC_STYLE_CHOICE_SOFT", "Ombre douce (Recommandé)")
ZO_CreateStringId("SI_TC_STYLE_CHOICE_HARD", "Ombre nette")
ZO_CreateStringId("SI_TC_STYLE_CHOICE_OUTLINE", "Contour (Outline)")
ZO_CreateStringId("SI_TC_STYLE_CHOICE_THIN", "Ombre fine")
ZO_CreateStringId("SI_TC_STYLE_CHOICE_NONE", "Sans ombre")

-- Elements Toggles
ZO_CreateStringId("SI_TC_SECTION_ELEMENTS", "Éléments affichés")
ZO_CreateStringId("SI_TC_SHOW_WDAY_NAME", "Jour de la semaine")
ZO_CreateStringId("SI_TC_SHOW_WDAY_TIP", "Afficher le jour de la semaine (Sundas, Morndas...)")
ZO_CreateStringId("SI_TC_SHOW_DATE_NAME", "Jour et mois")
ZO_CreateStringId("SI_TC_SHOW_DATE_TIP", "Afficher le jour et le mois (14 Onde d'argent...)")
ZO_CreateStringId("SI_TC_SHOW_YEAR_NAME", "Année et ère")
ZO_CreateStringId("SI_TC_SHOW_YEAR_TIP", "Afficher l'année (582 de la 2e Ère)")
ZO_CreateStringId("SI_TC_SHOW_SIGN_NAME", "Signe astrologique")
ZO_CreateStringId("SI_TC_SHOW_SIGN_TIP", "Afficher la constellation actuelle (Signe : Le Rituel...)")
ZO_CreateStringId("SI_TC_SHOW_TIME_NAME", "Heure de Tamriel")
ZO_CreateStringId("SI_TC_SHOW_TIME_TIP", "Afficher l'heure en jeu (heures et minutes)")