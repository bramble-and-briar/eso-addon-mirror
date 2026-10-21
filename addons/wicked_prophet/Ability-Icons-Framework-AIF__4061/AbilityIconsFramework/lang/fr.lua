local strings = {
    -- Potion Names (Legacy & Standard)
    HP_POTION_NAME_3              = "Gorgée d'héroïsme",
    HP_POTION_NAME_10             = "Teinture d'héroïsme",
    HP_POTION_NAME_20             = "Goutte d'héroïsme",
    HP_POTION_NAME_30             = "Potion d'héroïsme",
    HP_POTION_NAME_40             = "Solution d'héroïsme",
    HP_POTION_NAME_CP10           = "Élixir d'héroïsme",
    HP_POTION_NAME_CP50           = "Panacée d'héroïsme",
    HP_POTION_NAME_CP100          = "Distillat d'héroïsme",
    HP_POTION_NAME_CP150          = "Essence d'héroïsme",


    -- Settings Menu
    SI_AIF_PANEL_NAME             = "Ability Icons Framework",
    SI_AIF_PANEL_DESC             = "Framework pour personnaliser les icônes de compétences et l'interface de combat.",
    SI_AIF_SETTINGS_HEADER        = "Paramètres",
    SI_AIF_GLOBAL_SETTINGS        = "Utiliser les mêmes paramètres pour tous les personnages",
    SI_AIF_SCRIBING_ICONS         = "Utiliser les icônes d'écriture personnalisées",
    SI_AIF_BASE_GAME_ICONS        = "Remplacer les icônes du jeu de base",
    SI_AIF_HEROISM_POTIONS        = "Activer les icônes des potions d'héroïsme",
    SI_AIF_RESOLUTION             = "Résolution des icônes du jeu de base",
    SI_AIF_RESOLUTION_TIP         = "Résolution de texture à utiliser pour les icônes par défaut",
    SI_AIF_RESOLUTION_WARN        = "Nécessite /reloadui pour appliquer les modifications",
    SI_AIF_RELOAD_UI              = "Recharger l'interface",
    SI_AIF_PACK_ORDER_SUBMENU     = "Ordre de chargement des packs d'icônes",
    SI_AIF_PACK_PRIORITY          = "Priorité des packs d'icônes",

    -- Slash Commands & Chat
    SI_AIF_COMMANDS_HEADER        = "Commandes disponibles :",
    SI_AIF_COMMAND_DETAILS        = "  /aif details <emplacement 3-8> [1 pour la barre secondaire]",
    SI_AIF_COMMAND_ICONS          = "  /aif icons <emplacement 3-8> [1 pour la barre secondaire]",
    SI_AIF_COMMAND_VARS           = "  /aif vars (inspecter les variables sauvegardées)",
    SI_AIF_COMMAND_SETTINGS       = "  /aifgb (ouvrir le menu des paramètres)",
    SI_AIF_SLOT_EMPTY             = "L'emplacement <<1>> (barre <<2>>) est vide.",
    SI_AIF_SLOT_REDIRECT_NONE     = "  Redirigé vers : (aucun)",
}

for stringId, stringValue in pairs(strings) do
    SafeAddString(_G[stringId], stringValue, 1)
end
