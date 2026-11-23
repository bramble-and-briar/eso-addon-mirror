-- French localisation
-- luacheck: ignore 631
local L = function(k, v)
    ZO_CreateStringId("MARKTRIALHELPER_" .. k, v)
end

L("ADD_AVOID", "Ajouter à la liste des Indésirables")
L("ALL_BOTH", "Tous les versets et visions acquis")
L("ALL_VISIONS", "Toutes les visions acquises")
L("ALL_VERSES", "Tous les versets acquis")
L("ARC_BOSS", "Replicanum de Tho’at à venir")
L("AUDITOR", "Invoquer automatiquement l'Auditeur loyal")
L("AUDITOR_NAME", "Auditeur loyal")
L("AVOID", "Indésirables")
L("BONUS", "Niveaux bonus")
L("BUFF_SELECTED", "<<1>> a sélectionné <<2>>")
L("COUNT", "<<1>> sur <<2>>")
L("CROSSING_END", "Fin")
L("CROSSING_FAIL", "verrouillés") -- Les leviers sont verrouillés. Personne ne peut passer
L("CROSSING_INVALID", "L'aide ne peut être activée qu'à l'intérieur du Gué traître dans l'Archive Infinie")
L("CROSSING_KEY", "<<1>> Prendre à gauche - <<2>> Prendre à droite")
L("CROSSING_NO_SOLUTIONS", "Aucun chemin trouvé")
L("CROSSING_PATHS", "Chemins possibles")
L("CROSSING_SLASH", "aide")
L("CROSSING_START", "Début")
L("CROSSING_SUCCESS", "résolu") -- Vous avez résolu l'énigme du couloir
L("CROSSING_TITLE", "Aide pour le Gué traître")
L(
    "CROSSING_INSTRUCTIONS",
    "Trouvez l'interrupteur correspondant au début du chemin et sélectionnez-le dans la liste déroulante ci-dessous (1 est le plus à gauche, 6 le plus à droite)." ..
        " Puis, si nécessaire, trouvez la 2ème étape ou la fin du chemin, jusqu'à ce qu'il ne reste qu'une solution."
)
L("CYCLE_BOSS", "Phase de boss à venir")
L("DEN_TIMER", "<<1[0s restantes/1s restante/$ds restantes]>>")
L("FABLED", "fabule")
L("FABLED_MARKER", "Mettre un marqueur de cible sur les Fables")
L(
    "FABLED_TOOLTIP",
    "Cette fonctionnalité ne fonctionnera pas avec l'addon Lykeion's Fabled Marker afin d'éviter que les deux addons n'essaient de marquer les mêmes choses."
)

L("FLAMESHAPER", "Façonne-feu")
L("GW", "Gw le pillard")
L("GW_MARKER", "Ajouter un marqueur de cible sur Gw le pillard")
L("GW_PLAY", "Jouer un son quand Gw est marqué")
L("HERD", "Rassemblez les lueurs fantômes")
L("HERD_FAIL", "assez") -- Vous n'avez pas assez rassemblé de lueurs fantômes
L("HERD_SUCCESS", "ramené") -- Vous avez ramené les lueurs fantômes
L("MARAUDER_MARKER", "Mettre un marqueur de cible sur les Maraudeurs")
L("MARAUDER_INCOMING_PLAY", "Jouer un son à l'arrivée d'un Maraudeur")
L("OPTIONAL_LIBS_CHAT", "Mark Trial Helper fonctionne mieux si LibChatMessage est installé.")
L("OPTIONAL_LIBS_SHARE", "Pour que le mode Duo fonctionne correctement, veuillez installer LibDataShare.")
L("PREVENT", "Empêcher de sélectionner un bienfait par erreur")
L(
    "PREVENT_TOOLTIP",
    "Désactive la sélection du bienfait brièvement lorsque le panneau de sélection s'ouvre pour éviter un choix accidentel."
)
L("PROGRESS", "Avancement du critère <<1>>. Encore <<2>>.")
L("PROGRESS_ACHIEVEMENT", "Progression des succès")
L("PROGRESS_CHAT", "Afficher dans le log")
L("PROGRESS_SCREEN", "Annoncer à l'écran")
L("RANDOM", "<<1>> a reçu <<2>>")
L("REMINDER", "Signaler les prochaines phases de boss")
L("REMINDER_QUEST", "Rappel en cas d'objet de quête non ramassé")
L("REMINDER_QUEST_TEXT", "Pensez à ramasser l'objet de quête !")
L("REMINDER_TOOLTIP", "Lors de la sélection des versets, afficher un rappel si la phase suivante est un boss.")
L("REMOVE_AVOID", "Retirer de la liste des Indésirables")
L("REQUIRES", "Requiert LibChatMessage")
L("SECONDS", "s")
L("SHARD", "Fragment de Tho'at")
L("SHARD_IGNORE", "Ignorer les Fragments en dehors du cycle 5")
L("SHARD_MARKER", "Mettre un marqueur sur les Fragments de Tho'at")
L("SHOW_COUNT", "Décompter les tomes-carapaces de l'Aile du greffier")
L("SHOW_CROSSING_HELPER", "Afficher l'aide dans le Gué traître")

L(
    "SHOW_COUNT_TOOLTIP",
    "Pour que le mode Duo fonctionne correctement, l'autre joueur doit avoir installé cet addon. Les deux joueurs doivent également avoir installé LibDataShare."
)
L("SHOW_ECHO", "Afficher un minuteur dans l'Antre aux échos")
L("SHOW_SELECTION", "Afficher vos choix de bienfaits en discussion")
L("SHOW_TERRAIN_WARNING", "Afficher les avertissements")
L("SHOW_TERRAIN_WARNING_TOOLTIP", "Afficher les avertissements concernant les dommages causés au terrain")
L("SHOW_THEATRE_WARNING", "Show warnings in the Theatre of War")
L("SHOW_SELECTION_DISPLAY_NAME", "Utiliser le nom d'affichage")
L("SHOW_SELECTION_DISPLAY_NAME_TOOLTIP", "Utiliser le nom d'affichage au lieu du nom du personnage")
L("SLASH_MISSING", "manquant")
L("STACKS", "Nombre de bienfaits cumulés")
L("TOMESHELL", "Tome-carapace")
L("TOMESHELL_COUNT", "<<1[0 restants/1 restant/$d restants]>>")
L("USE_AUTO_AVOID", "Marquer automatiquement les Indésirables")
L(
    "USE_AUTO_AVOID_TOOLTIP",
    "Marquer automatiquement les versets ou les visions qui ne vous sont d'aucune utilité en raison de compétences non équipées."
)
L("WARNING", "Avertissement : les listes déroulantes ne seront actualisées qu'après un rechargement de l'IU")
L("WEREWOLF_BEHEMOTH", "Béhémoth loup-garou")

-- keybinds
L("SI_BINDING_NAME_MARKTRIALHELPER_MARK_CURRENT_TARGET", "Marquer la cible actuelle")
L("SI_BINDING_NAME_MARKTRIALHELPER_TOGGLE_CROSSING_HELPER", "Ouvrir/fermer l'aide du Gué traître")
L("SI_BINDING_NAME_MARKTRIALHELPER_UNMARK_CURRENT_TARGET", "Retirer la marque sur la cible actuelle")

-- Marauders
L("MARAUDER_GOTHMAU", "gothmau")
L("MARAUDER_HILKARAX", "hilkarax")
L("MARAUDER_ULMOR", "ulmor")
L("MARAUDER_BITTOG", "bittog")
L("MARAUDER_ZULFIMBUL", "zulfimbul")

-- Zones
L("MAP_TREACHEROUS_CROSSING", "Treacherous Crossing")
L("MAP_HAEFELS_BUTCHERY", "Haefel's Butchery")
L("MAP_FILERS_WING", "Filer's Wing")
L("MAP_ECHOING_DEN", "Echoing Den")
L("MAP_THEATRE_OF_WAR", "Theatre of War")
L("MAP_DESTOZUNOS_LIBRARY", "Destozuno's Library")
