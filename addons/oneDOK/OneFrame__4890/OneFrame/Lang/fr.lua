local strings = {
    [SI_ONEFRAME_DEBUG] = "Debug",
    [SI_ONEFRAME_DEBUG_OFF] = "Désactivé",
    [SI_ONEFRAME_DEBUG_SMALL] = "Petit groupe",
    [SI_ONEFRAME_DEBUG_LARGE] = "Grand groupe",
    [SI_ONEFRAME_DISPLAY] = "Affichage",
    [SI_ONEFRAME_TANK_ROLE] = "Tank",
    [SI_ONEFRAME_HEALER_ROLE] = "Soigneur",
    [SI_ONEFRAME_DAMAGE_ROLE] = "DPS",
    [SI_ONEFRAME_SHOW_STATISTIC] = "Statistique à afficher",
    [SI_ONEFRAME_NOTHING] = "Aucune",
    [SI_ONEFRAME_LEVEL_CP] = "Niveau / Points de Champion",
    [SI_ONEFRAME_GROUP_DPS] = "DPS du groupe",
    [SI_ONEFRAME_HEALTH_THOUSANDS] = "%.1fk",
    [SI_ONEFRAME_GENERAL] = "Général",
    [SI_ONEFRAME_SORT] = "Trier le groupe par rôle",
    [SI_ONEFRAME_CLASS] = "Afficher l’icône de classe",
    [SI_ONEFRAME_DPS_LABEL] = "DPS",
    [SI_ONEFRAME_HPS_LABEL] = "HPS",
    [SI_ONEFRAME_UNAVAILABLE] = "—",
    [SI_ONEFRAME_KILO] = "%.1fk",
    [SI_ONEFRAME_MILLION] = "%.2fm",
    [SI_ONEFRAME_SHIELD_COLOR] = "Couleur du bouclier",
    [SI_ONEFRAME_CONTEXT_MENU] = "Menu contextuel par clic droit",
    [SI_ONEFRAME_WHISPER] = "Chuchoter",
    [SI_ONEFRAME_TRAVEL] = "Se rendre auprès du joueur",
    [SI_ONEFRAME_REMOVE] = "Exclure du groupe",
    [SI_ONEFRAME_UNSUPPORTED] = "OneFrame : cette version de l’interface ESO n’a pas été vérifiée ; les améliorations des cadres sont désactivées.",
    [SI_ONEFRAME_MISSING] = "OneFrame : les cadres par défaut ne sont pas pris en charge ; les améliorations n’ont pas été appliquées.",
}

for id, text in pairs(strings) do
    SafeAddString(id, text, 1)
end
