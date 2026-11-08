local localization_strings = {
  CHATIV_WARNING_CAPTION = "À noter:",
  CHATIV_WARNING_TEXT = "Le champ d'affichage des messages instantanés s'affiche sous la fenêtre de chat. La fenêtre de chat"
    .. " s'étend généralement jusqu'au bord inférieur de l'écran. Si la fenêtre ne se déplace pas automatiquement vers le haut"
    .. " lorsque l'add-on est affiché, le bord inférieur de la fenêtre de chat doit être déplacé manuellement vers le haut.",
  CHATIV_VISIBLE = "Visibilité",
  CHATIV_VISIBLE_TOOLTIP = "Affiche ou masque la fenêtre.",
  CHATIV_MINIMISED = "Taille de fenêtre réduite",
  CHATIV_MINIMISED_TOOLTIP = "Affiche la fenêtre réduite à une ligne.",
  CHATIV_FONTSIZE = "Taille de la police",
  CHATIV_FONTSIZE_TOOLTIP = "La taille des caractères affichés dans la fenêtre du visualiseur. Toute modification de"
    .. " cette valeur aura également un impact sur la hauteur de la fenêtre.",
  CHATIV_WINDOWMODE = "Mode fenêtré",
  CHATIV_WINDOWMODE_TOOLTIP = "Définit comment la largeur de la fenêtre est déterminée.",
  CHATIV_WINDOWMODE_VAL1 = "Largeur de la fenêtre de chat",
  CHATIV_WINDOWMODE_VAL2 = "Largeur fixe",
  CHATIV_WINDOWWIDTH = "Largeur de la fenêtre",
  CHATIV_WINDOWWIDTH_TOOLTIP = "La largeur de la fenêtre du visualiseur.",
  CHATIV_NROFLINES = "Nombre de lignes de texte",
  CHATIV_NROFLINES_TOOLTIP = "Le nombre de lignes de texte pouvant être affichées dans le visualiseur. Toute modification"
    .. " de cette valeur modifie la hauteur de la fenêtre du visualiseur.",
  CHATIV_KEYBINDING_TUGGLE = "Afficher ou masquer la fenêtre",
  CHATIV_UPDATEMESSAGE_01 = "== Chat Input Viewer - nouveautés de la version 1.3.0 ==",
  CHATIV_UPDATEMESSAGE_02 = " * Nouveau mode «réduit»",
  CHATIV_UPDATEMESSAGE_03 = " * Commandes du chat /civshow, /civhide et /civmini",
  CHATIV_UPDATEMESSAGE_04 = " * Raccourci clavier personnalisable pour changer de mode.",
  CHATIV_UPDATEMESSAGE_05 = "Vous trouverez plus de détails dans la description de l'extension sur USOUI: https://www.esoui.com/downloads/info4158-ChatInputViewer.html",
  CHATIV_UPDATEMESSAGE_06 = "(Ce message s'affichera encore %s fois après la connexion.)",
}

for stringId, stringValue in pairs(localization_strings) do
  SafeAddString(_G[stringId], stringValue, 2)
end
