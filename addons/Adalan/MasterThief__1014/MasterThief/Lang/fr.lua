---------------------------------------------
-- French localization for MasterThief
---------------------------------------------
-- translated by Adalan@Aruntas
-- updated by WolfStar07

local localization_strings = {
	-- settings panel name
	MASTER_THIEF_NAME = "Master Thief",
	
	-- options checkboxes
	MT_SNEAK_MODE_NAME = "Mode furtif et vol",
	MT_SNEAK_MODE_TEXT = "Cela fonctionne comme un filet de sécurité. Vous pouvez inspecter tous les conteneurs (sauf les coffres-forts) sans être furtif et sans tout piller automatiquement. Cela aide si des gardes ou des PNJ sont à proximité et que vous voulez juste voir s'il y a quelque chose qui vaut la peine d'être volé.",
	MT_SHOW_MESSAGEBOX_NAME = "Afficher le cadre de message",
	MT_SHOW_MESSAGEBOX_TEXT = "Forcer l'affichage du cadre de message à l'écran pour permettre le déplacement et le positionnement.",
	MT_EXCLUDE_COMPARE_NAME = "Pillage de connaissances partagées",
	MT_EXCLUDE_COMPARE_TEXT = "Cette option vérifie vos recettes et plans connus sur l'ensemble de votre compte (nécessite LibCharacterKnowledge). Si désactivé, seules les connaissances de votre personnage actuel seront vérifiées.",
	MT_LOOT_UNKNOWN_RECIPES_NAME = "Forcer le pillage des inconnus",
	MT_LOOT_UNKNOWN_RECIPES_TEXT = "Piller toutes les recettes et plans inconnus quel que soit le niveau de qualité défini. Si désactivé, seules les recettes et plans du niveau de qualité défini ou supérieur seront automatiquement pillés.",
	MT_AUTOLOOT_FROM_LOOTLIST_NAME = "Pillage automatique de la liste de butin",	
	MT_AUTOLOOT_FROM_LOOTLIST_TEXT = "Si activé, vous volez automatiquement les objets ajoutés à la liste de butin. Accédez à la fenêtre de butin en tapant |cedbe3e/mtloot|r.",
	MT_PICKPOCKET_COUNTER_NAME = "Compteur de pickpocket",
	MT_PICKPOCKET_COUNTER_TEXT = "Compteur de pickpocket à l'écran, car les PNJ ont tendance à se déplacer. Tuez pour réinitialiser le compteur. S'applique à tous les PNJ portant le même nom générique, comme garde du Lion, alors pensez à réinitialiser en tuant ou en vous téléportant.",
	
	-- options slider
	MT_MESSAGE_DELAY_NAME = "Délai des messages",
	MT_MESSAGE_DELAY_TEXT = "Définissez le délai de vos messages à l'écran en millisecondes, c'est-à-dire 1000 unités = 1 seconde.",
	MT_FREE_SLOTS_LEFT_LIMIT_NAME = "Seuil d'avertissement d'emplacements de sac libres",
	MT_FREE_SLOTS_LEFT_LIMIT_TEXT = "Définissez le nombre minimum d'emplacements restants dans votre sac avant d'afficher un message d'avertissement sur les emplacements libres.",
	MT_MIN_SELL_PRICE_AUTOLOOT_NAME = "Prix de vente minimum pour le pillage automatique",
	MT_MIN_SELL_PRICE_AUTOLOOT_TEXT = "Définissez le prix de vente minimum pour activer le pillage automatique des objets volés. Notez que cela exclut les recettes, les plans et les motifs, qui sont contrôlés par les paramètres de pillage automatique.",

	-- options dropdown
	MT_RECIPE_QUALITY_NAME = "Qualité minimale des recettes",
	MT_RECIPE_QUALITY_TEXT = "Choisissez le niveau de qualité minimum d'une recette ou d'un plan à piller automatiquement. Les inconnus en dessous du niveau donné ne seront pillés automatiquement que si vous l'autorisez explicitement.",
	MT_RECIPE_COLOR_GREEN = "vert",
	MT_RECIPE_COLOR_BLUE = "bleu",
	MT_RECIPE_COLOR_PURPLE = "violet",
	MT_RECIPE_COLOR_GOLD = "or",

	-- options submenu - announcements
	MT_SUB_ANNOUNCE_NAME = "Annonces",
	MT_SUB_ANNOUNCE_TEXT = "Toutes les annonces",
	MT_SUB_ANNOUNCE_ONSCREENMSG_NAME = "Annoncer avec message à l'écran",
	MT_SUB_ANNOUNCE_ONSCREENMSG_TEXT = "Annoncer les recettes, plans et motifs comme message à l'écran.",
	MT_SUB_ANNOUNCE_SPECIALS_NAME = "Annoncer les objets spéciaux dans le chat",
	MT_SUB_ANNOUNCE_SPECIALS_TEXT = "Annoncer les recettes, plans et motifs dans le chat. Seul vous verrez ces annonces.",
	MT_SUB_ANNOUNCE_REGULAR_NAME = "Annoncer les informations dans le chat",
	MT_SUB_ANNOUNCE_REGULAR_TEXT = "Annoncer les informations comme les paiements aux gardes/receleurs, les objets vendus, la prime, etc. dans le chat.",	
	MT_SUB_ANNOUNCE_USELESS_NAME = "Annoncer les objets de rebut",
	MT_SUB_ANNOUNCE_USELESS_TEXT = "Annoncer les objets de rebut tels que définis par le prix de vente minimum pour le pillage automatique. Vous pouvez lister ces objets avec la commande /mt_junk. Exclut les recettes, plans ou motifs.",
	MT_SUB_ANNOUNCE_BECAREFUL_NAME = "Annoncer \"Soyez prudent\" en mode furtif",
	MT_SUB_ANNOUNCE_BECAREFUL_TEXT = "Afficher le message \"Soyez prudent\", car la distance aux PNJ n'est pas suffisante pour être totalement furtif. Cela devrait vous aider à vous faufiler et à voler en étant totalement furtif.",	
	MT_SUB_ANNOUNCE_KNOWN_RECIPES_NAME = "Annoncer les recettes connues",
	MT_SUB_ANNOUNCE_KNOWN_RECIPES_TEXT = "Afficher un message concernant le pillage de recettes déjà connues dans le chat.",	
	MT_SUB_ANNOUNCE_SELLS_TRANSFERS_NAME = "Annoncer recel/blanchiment dans le chat",
	MT_SUB_ANNOUNCE_SELLS_TRANSFERS_TEXT = "Afficher un message concernant les transactions de recel et de blanchiment dans le chat.",	
	MT_SUB_ANNOUNCE_MAX_FENCER_LIMITS_NAME = "Annoncer les limites du receleur",
	MT_SUB_ANNOUNCE_MAX_FENCER_LIMITS_TEXT = "Afficher un message dans le chat si vous transportez trop d'objets pour le recel ou le blanchiment.",
	
	-- options submenu - companion
	MT_COMP_MENU_SUBMENU_NAME = "Protection de la complicité du compagnon",
	MT_COMP_MENU_SUBMENU_TOOLTIP = "Paramètres pour protéger la complicité du compagnon lors d'activités de vol.",
	MT_COMP_MENU_WARN_NAME = "Avertir lors d'actions désapprouvées",
	MT_COMP_MENU_WARN_TOOLTIP = "Affiche un avertissement lorsque ton compagnon perdrait de la complicité.",
	MT_COMP_MENU_BLOCK_NAME = "Bloquer les actions désapprouvées",
	MT_COMP_MENU_BLOCK_TOOLTIP = "Empêche les actions désapprouvées par ton compagnon, plutôt que de simplement t'avertir.",
	MT_COMP_MENU_AUTODISMISS_NAME = "Renvoi automatique dans les zones de la Confrérie Noire",
	MT_COMP_MENU_AUTODISMISS_TOOLTIP = "Renvoie automatiquement les compagnons qui n'aiment pas la Confrérie Noire lorsque vous approchez de leur sanctuaire.",

	-- Misc Text
	MT_MISC_TRASH_TEXT = "Rebut: ",
	MT_MISC_SOLD_FOR = " vendu pour ",
	MT_MISC_BOUNTY_IS = "La prime est ",
	MT_MISC_BOUNTY_REMOVED_FROM_BODY = "La prime totale a été retirée de votre cadavre!",
	MT_MISC_ALL_STOLEN_ITEMS_REMOVED = "Tous les objets volés ont été retirés par un garde!",
	MT_MISC_YOU_PAID_BOUNTY = "Vous avez payé la prime: ",
	MT_MISC_YOU_SOLD_AN_ITEM_FOR = "Vous avez recelé un objet pour ",
	MT_MISC_SNEAKMODE_ACTIVE = "Mode furtif et vol actif",
	MT_MISC_SNEAKMODE_SLEEPING = "Mode furtif et vol inactif",
	MT_MISC_BE_CAREFUL = "Soyez prudent!",
	MT_MISC_IS_KNOWN = "Déjà connu: ",
	MT_MISC_FREE_SLOTS_LEFT = "Emplacements libres restants: ",
	MT_MISC_SELL_MAXIMUM_REACHED = "Attention: Vous transportez plus d'objets que d'emplacements de recel restants!",
	MT_MISC_TRANSFER_MAXIMUM_REACHED = "Attention: Vous transportez plus d'objets que d'emplacements de blanchiment restants!",
	MT_MISC_ITEM_DESTROYED = "...détruit!",
	MT_MISC_LIST_USELESS_ITEMS = "Liste des objets de rebut: ",
	MT_MISC_USELESS_ITEMS_FOUND = "Objets de rebut trouvés: ",
	MT_MISC_TYPE_COMMAND_DESTROY_ITEM = "Tapez /mt_junk delete pour les détruire",
	MT_MISC_NO_ITEMS_FOUND = "Aucun objet à détruire trouvé",
	MT_MISC_ITEMS_BELOW_VALUE_USELESS = "Les objets en dessous de ce prix de vente sont des rebuts: ",
	MT_MISC_FOUND_ALOT_GOLD_TEXT = "Vous avez pillé de l'or. Volé: ",
	MT_MISC_ITS_KNOWN_BUT_WANTED_TEXT = "Connu, mais pillé: ",
	MT_MISC_LOOTLIST_TEXT = "Afficher la liste de butin",

	--Text for command list on chat
	MT_MISC_MASTERTHIEF_COMMANDS = "Commandes MasterThief:",
	MT_MISC_MASTERTHIEF_LISTCOMMANDS = "Lister toutes les commandes de chat",
	MT_MISC_CMD_LIST_ALL_USELESS_ITEMS = "Liste de tous les objets de rebut",
	MT_MISC_CMD_DESTROY_ALL_USELESS_ITEMS = "Détruire tous les objets de rebut",
	
	--Text for recipe tooltip
	MT_MISC_TOOLTIP_RECIPE_CHARS = "Cette recette est connue par:",

	--Text for Lootlist
	MT_MISC_LOOTLIST_DELETE = " retiré de la liste de butin",
	MT_MISC_ITEM_ADDED = " ajouté à la liste de butin",
	MT_MISC_ITEM_ALREADY_ON_LOOTLIST = "L'objet est déjà sur la liste de butin",
	MT_MISC_WORTHFUL_ITEMS = "Liste de butin d'objets intéressants",
	MT_MISC_ITEM_TOOLTIP = "L'objet est déjà sur la liste de butin",
	
	-- Text for Context-Menu
	MT_CONTEXTMENU_LOOT_MARK = "Marquer pour pillage automatique",	
	
	-- Statistics window headers
	MT_STATS_SESSION_HEADER = "Statistiques de session",
	MT_STATS_LIFETIME_HEADER = "Statistiques totales",
	
	-- Session stats - Looting
	MT_STATS_ITEMS_LOOTED = "Objets pillés automatiquement:",
	MT_STATS_ITEMS_SKIPPED = "Objets ignorés:",
	MT_STATS_MOTIFS_LOOTED = "Motifs pillés:",
	MT_STATS_RECIPES_LOOTED = "Recettes pillées:",
	MT_STATS_FURNISHING_PLANS = "Plans d'ameublement:",
	MT_STATS_FURNISHINGS = "Meubles pillés:",
	MT_STATS_HIDDEN_WALLETS = "Portefeuilles cachés:",
	MT_STATS_RESEARCH_PORTFOLIOS = "Portfolios de recherche:",
	MT_STATS_EDICTS = "Édits pillés:",
	
	-- Session stats - Justice
	MT_STATS_PICKPOCKETS = "Pickpockets:",
	MT_STATS_SAFEBOXES = "Coffres crochetés:",
	MT_STATS_DOORS = "Portes crochetées:",
	MT_STATS_LOCKPICK_BREAKS_PREVENTED = "Guidance de Tanlorin:",
	MT_STATS_BOW_KILLS = "Kills avec Lame du Malheur:",
	MT_STATS_GUARD_DEATHS = "Morts par gardes:",
	MT_STATS_GOLD_FENCED = "Or recelé:",
	MT_STATS_HIGHEST_BOUNTY = "Prime la plus élevée:",
	MT_STATS_TROVES = "Trésors de voleurs:",
	MT_STATS_HIGHEST_VALUE = "Objet de plus grande valeur:",
	
	-- Lifetime stats
	MT_STATS_LIFETIME_BOUNTY_PAID = "Prime totale payée:",
	MT_STATS_GOLD_LAUNDERED = "L'or dépensé sert à blanchir :"
	MT_DIALOG_RESET_LIFETIME_TITLE = "Réinitialiser les statistiques à vie",
	MT_DIALOG_RESET_LIFETIME_TEXT = "Es-tu sûr de vouloir réinitialiser toutes les statistiques à vie ? Cette action est irréversible.",
	MT_DIALOG_RESET_LIFETIME_CONFIRM = "Réinitialiser",
	MT_DIALOG_RESET_LIFETIME_CANCEL = "Annuler",
	
	-- Buttons
	MT_STATS_RESET_SESSION = "Réinitialiser stats de session",
	MT_STATS_RESET_LIFETIME = "Réinitialiser stats totales",
	MT_STATS_CLOSE = "Fermer",
	
	-- Bastian
	MT_COMP_STEALTH_BASTIAN = "n'aime pas le vol ni les pickpockets. Envisage de le renvoyer.",
	MT_COMP_ARRESTED_BASTIAN = "n'aime pas fuir ! Demande la clémence ou accepte l'amende pour minimiser la perte de complicité.",
	
	-- Isobel
	MT_COMP_STEALTH_ISOBEL = "n'aime pas voler dans les conteneurs, les cadavres et les Trésors des voleurs.",
	
	-- Sharp
	MT_COMP_STEALTH_SHARP = "n'aime pas faire les poches des mendiants, ouvriers ou pêcheurs.",
	
	-- Tanlorin
	MT_COMP_STEALTH_TANLORIN = "perdra de la complicité si tu voles des jouets d'enfants, des poupées ou pilles des cadavres.",
	
	-- Zerith
	MT_COMP_STEALTH_ZERITH =  "perdra de la complicité si tu voles des objets médicinaux, religieux ou sentimentaux, pilles des cadavres ou utilises des édits.",
	
	-- Arrest advice 
	MT_COMP_ARRESTED_PAYBOUNTY = "n'aime pas payer les gardes ! Fuis ou demande la clémence pour éviter la perte de complicité.",
	MT_COMP_ARRESTED_GENERIC = "n'aime pas cette situation ! Réfléchis bien à tes options.",
	
	-- Other warnings
	MT_COMP_TROVE_WARN = "n'aime pas piller les Trésors des voleurs ! La complicité va diminuer.",
	MT_COMP_PICKPOCKET_WARN = "n'aime pas les pickpockets ! La complicité va diminuer.",
	MT_COMP_CONTAINER_WARN = "n'aime pas voler dans les conteneurs ! La complicité va diminuer.",
	MT_COMP_CORPSE_WARN = "n'aime pas piller les cadavres ! La complicité va diminuer.",
	MT_COMP_BOUNTY_WARN = "n'aime pas que tu te fasses attraper ! Envisage d'utiliser un édit ou de le renvoyer avant qu'un garde ne t'arrête.",
	MT_COMP_BOW_AVAILABLE_WARN = "n'aime pas l'assassinat — la Lame du Malheur est disponible ! Éloigne-toi pour éviter la perte de complicité.",
	MT_COMP_BOW_USED_WARN = "n'aime pas la Lame du Malheur ! La complicité a diminué.",
	MT_COMP_REFUGE_WARN = "n'aime pas les Refuges des hors-la-loi ! La complicité va diminuer.",
	MT_COMP_DB_WARN = "n'aime pas la Confrérie Noire !",
	MT_COMP_PAYBOUNTY_WARN = "n'aime pas payer une prime à un garde ! La complicité va diminuer.",
	MT_COMP_FENCE_WARN = "n'aime pas recel de marchandises volées ! La complicité va diminuer.",
	MT_COMP_EDICT_WARN = "n'aime pas l'utilisation des édits ! La complicité va diminuer.",
	
	-- Blocked actions
	MT_COMP_TROVE_BLOCK = "n'aime pas les Trésors des voleurs ! Action bloquée.",
	MT_COMP_PICKPOCKET_BLOCK = "n'aime pas les pickpockets ! Action bloquée.",
	MT_COMP_CONTAINER_BLOCK = "n'aime pas voler dans les conteneurs ! Action bloquée.",
	MT_COMP_BOW_BLOCK = "n'aime pas l'assassinat ! Lame du Malheur bloquée.",
	MT_COMP_REFUGE_BLOCK = "n'aime pas les Refuges des hors-la-loi ! Entrée bloquée.",
	MT_COMP_DB_DISMISSED = "a été renvoyée — elle n'aime pas la Confrérie Noire.",
	MT_COMP_FENCE_BLOCK = "n'aime pas recel de marchandises volées ! Receleur fermé.",
	MT_COMP_EDICT_BLOCK = "n'aime pas l'utilisation des édits ! Action bloquée.",
	
}

for stringId, stringValue in pairs(localization_strings) do
   ZO_CreateStringId(stringId, stringValue)
   SafeAddVersion(stringId, 1)
end