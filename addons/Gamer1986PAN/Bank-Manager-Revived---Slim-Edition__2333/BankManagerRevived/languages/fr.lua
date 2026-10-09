--[[
File : fr.lua
Version : 4.5
Author : Ayantir
]]--

--Option Translation

SafeAddString(BMR_AUTO_TRANSFERT								, "Transfert automatique à l'ouverture", 1)
SafeAddString(BMR_AUTO_TRANSFERT_TOOLTIP					, "Transfère automatiquement objets et devises à l'ouverture de la banque", 1)

SafeAddString(BMR_STACK_DETAILLED							, "Afficher un détail de chaque mouvement", 1)
SafeAddString(BMR_STACK_DETAILLED_TOOLTIP					, "Affiche un détail de chaque mouvement dans la fenêtre de discussion", 1)

SafeAddString(BMR_DISPLAY_SUMMARY							, "Afficher un résumé", 1)
SafeAddString(BMR_DISPLAY_SUMMARY_TOOLTIP					, "Affiche un résumé des mouvements dans la fenêtre de discussion", 1)

SafeAddString(BMR_STACK_DETAILLED_NOTMOVED				, "Afficher les déplacements non effectués", 1)
SafeAddString(BMR_STACK_DETAILLED_NOTMOVED_TOOLTIP		, "Affiche un message lorsque BMR n'a pas déplacé un objet à cause d'un espace insuffisant dans le sac de destination", 1)

SafeAddString(BMR_DONT_MOVE_PROTECTED_ITEMS				, "Ne pas déplacer les objets protégés", 1)
SafeAddString(BMR_DONT_MOVE_PROTECTED_ITEMS_TOOLTIP	, "Ne pas déplacer les objets protégés par ESO, ItemSaver ou FCO ItemSaver", 1)

SafeAddString(BMR_DONT_MOVE_MOVED_ITEMS					, "Ne pas toucher aux objets déplacés par un tiers", 1)
SafeAddString(BMR_DONT_MOVE_MOVED_ITEMS_TOOLTIP			, "Ne pas toucher aux objets précédemment déplacés par vous même ou un autre addon à l'ouverture de la banque", 1)

SafeAddString(BMR_WAIT_AT_STARTUP							, "Délai à l'initialisation de la banque", 1)
SafeAddString(BMR_WAIT_AT_STARTUP_TOOLTIP					, "Réduisez le temps d'attente si vous ne voulez pas patienter. Une valeur plus faible peut néanmoins faire planter BMR si votre ordinateur est un peu lent, plus particulièrement à la banque de guilde", 1)

SafeAddString(BMR_NO_OVERFILL									, "Garder un nombre de slots disponibles", 1)
SafeAddString(BMR_NO_OVERFILL_TOOLTIP						, "Si défini, BMR essayera de garder ce nombre d'emplacement disponibles et ne déplacera pas d'objets supplémentaire si ce chiffre est atteint", 1)

SafeAddString(BMR_DELAY_BETWEEN_MOVES						, "Délai entre les déplacements ", 1)
SafeAddString(BMR_DELAY_BETWEEN_MOVES_TOOLTIP			, "Ajouer un délai entre les déplacement pour éviter de potentiels crashs et/ou kicks du jeu", 1)

SafeAddString(BMR_ONLY_IF_NOT_FULL_STACK					, "Seulement si pile incomplète", 1)
SafeAddString(BMR_ONLY_IF_NOT_FULL_STACK_TOOLTIP		, "Déplacer les objets uniquement si le conteneur de destination ne possède pas une pile pleine des objets à transférer", 1)

SafeAddString(BMR_MAX_STACK									, "Nombre de piles", 1)
SafeAddString(BMR_MAX_STACK_TOOLTIP							, "Nombre de piles maximum à déplacer dans le conteneur de destination", 1)

SafeAddString(BMR_GUILD_LIST									, "Banque de guilde associée", 1)
SafeAddString(BMR_GUILD_LIST_TOOLTIP						, "Nom de la banque de guilde associée aux règles définies ci-dessous. BMR mettra en banque les objets si les conditions correspondent à vos critères", 1)

-- Profiles
SafeAddString(BMR_PROFILES										, "Profils", 1)
SafeAddString(BMR_PROFILE_LIST								, "Profil actuellement sélectionné", 1)
SafeAddString(BMR_PROFILE_LIST_TOOLTIP						, "Pour chaque personnage, vous pouvez définir 9 différents profils avec ses règles spécifiques", 1)
SafeAddString(BMR_PROFILE_NAME								, "Nom du profil", 1)
SafeAddString(BMR_PROFILE_NAME_TOOLTIP						, "Nom du profil actuellement sélectionné", 1)
SafeAddString(BMR_PROFILE_RESET								, "Réinit. Profil", 1)
SafeAddString(BMR_PROFILE_RESET_TOOLTIP					, "Réinitialiser ce profil aux valeurs par défaut", 1)
	
-- Currencies
SafeAddString(BMR_CURRENCY_PUSH								, "Devises à conserver en inventaire", 1)
SafeAddString(BMR_CURRENCY_PUSH_TOOLTIP					, "Conserver cette quantité de devises dans votre inventaire\n\nSi vous définissez une valeur pour \"Récupérer un maximum de\", cette valeur sera prise pour minimum pour cette option.", 1)
		
SafeAddString(BMR_CURRENCY_PULL								, "Récupérer un maximum de", 1)
SafeAddString(BMR_CURRENCY_PULL_TOOLTIP					, "Récupérer un maximum de devises depuis votre banque à destination de votre inventaire", 1)

SafeAddString(BMR_CURRENCY_NOTHING							, "Ne conserver aucun <<1>>", 1)
SafeAddString(BMR_CURRENCY_NOTHING_TOOLTIP				, "Lorsque \"Devises à conserver en inventaire\" est défini à 0, vous devez confirmer ce paramètre en définissant cette option pour déposer tout votre <<1>> en banque", 1)

SafeAddString(BMR_CURRENCY_KEEP_IN_BANK					, "Garder en banque plutôt que dans le sac", 1)
SafeAddString(BMR_CURRENCY_KEEP_IN_BANK_TOOLTIP			, "Garder la quantité définie en banque plutôt que dans le sac et remplir la banque du montant indiqué si la banque n'en contient pas assez", 1)

-- Crafting Types as their ID are language dependant
SafeAddString(BMR_TRADESKILL_ALCHEMY						, "Alchimie", 1)
SafeAddString(BMR_TRADESKILL_CLOTHIER						, "Couture", 1)
SafeAddString(BMR_TRADESKILL_PROVISIONING					, "Cuisine", 1)
SafeAddString(BMR_TRADESKILL_ENCHANTING						, "Enchantement", 1)
SafeAddString(BMR_TRADESKILL_BLACKSMITHING					, "Forge", 1)
SafeAddString(BMR_TRADESKILL_WOODWORKING					, "Travail du bois", 1)
SafeAddString(BMR_TRADESKILL_JEWELRYCRAFTING				, "Joaillerie", 1)

-- Trophies are hardcoded because there is nothing to label them
SafeAddString(BMR_TROPHY_TREASURE_MAP						, "Cartes au trésor", 1)
SafeAddString(BMR_TROPHY_SURVEY_MAP							, "Repérage d'artisanat", 1)
SafeAddString(BMR_TROPHY_MOTIF_FRAGMENT					, "Fragments de motif de style", 1)
SafeAddString(BMR_TROPHY_RECIPE_FRAGMENT					, "Fragments de recette", 1)
SafeAddString(BMR_TROPHY_IMPERIALCITY_PVE					, "Trophées de la Cité Impériale", 1)
SafeAddString(BMR_TROPHY_QUEST_REWARD						, "Trophés de récompense de quête", 1)

-- Writ quests
SafeAddString(BMR_WRIT_QUESTS									, "Retirer de la banque les matériaux nécessaires", 1)
SafeAddString(BMR_WRIT_QUESTS_TOOLTIP						, "Retirer de la banque les matériaux nécessaires pour les quêtes d'artisanat quotidiennes", 1)

-- Bindings
SafeAddString(SI_BINDING_NAME_BMR_PROFILE1				, "Exécuter le profil 1", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE2				, "Exécuter le profil 2", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE3				, "Exécuter le profil 3", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE4				, "Exécuter le profil 4", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE5				, "Exécuter le profil 5", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE6				, "Exécuter le profil 6", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE7				, "Exécuter le profil 7", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE8				, "Exécuter le profil 8", 1)
SafeAddString(SI_BINDING_NAME_BMR_PROFILE9				, "Exécuter le profil 9", 1)

-- Dropwdons
SafeAddString(BMR_ACTION_PUSH									, "Mettre en banque", 1)
SafeAddString(BMR_ACTION_PULL									, "Retirer de la banque", 1)
SafeAddString(BMR_ACTION_NOTSET								, "-", 1)	
SafeAddString(BMR_ACTION_PUSH_GBANK							, "Mettre en banque de guilde", 1)
SafeAddString(BMR_ACTION_PUSH_BOTH							, "Mettre dans les deux banques", 1)

-- Chat notifications
SafeAddString(BMR_ACTION_ITEMS_MOVED						, "BMR a déplacé <<3>>x |t16:16:<<2>>|t<<1>> <<4>>", 1)
SafeAddString(BMR_ACTION_ITEMS_NOT_MOVED					, "BMR n'a pas déplacé <<3>>x |t16:16:<<2>>|t<<1>> <<4>>", 1)
SafeAddString(BMR_ACTION_CURRENCY_SUMMARY					, "BMR a déplacé <<1>> <<2>>", 1)

SafeAddString(BMR_ACTION_HAS_MOVED							, "BMR a déplacé ", 1)
SafeAddString(BMR_ACTION_CURRENCY_MOVED_TO2				, "en banque", 1)
SafeAddString(BMR_ACTION_CURRENCY_MOVED_TO3				, "vers l'inventaire", 1)

SafeAddString(BMR_ACTION_ITEMS_MOVED_TO1					, "vers l'inventaire", 1)
SafeAddString(BMR_ACTION_ITEMS_MOVED_TO2					, "en banque", 1)
SafeAddString(BMR_ACTION_ITEMS_MOVED_TO6					, "en banque", 1)
SafeAddString(BMR_ACTION_ITEMS_MOVED_TO3					, "dans la banque de guilde <<5>>", 1)

SafeAddString(BMR_ACTION_ITEMS_SUMMARY						, "BMR a déplacé <<1>>x objets différents (<<2>> objets) ", 1)
SafeAddString(BMR_RARE_INGREDIENTS							, "<<1>>, <<2>> & <<3>>", 1)

-- Import
SafeAddString(BMR_IMPORT										, "Importer les paramètres de BMR de", 1)
SafeAddString(BMR_IMPORT_DESC									, "Choisissez à partir de quel personnage les paramètres de BMR doivent être importés. Veuillez noter que ces paramètres restent basés sur le personnage et ne sont pas synchronisés entre eux", 1)
SafeAddString(BMR_IMPORTED										, "Les paramètres de BMR ont été importés à partir du personnage <<1>>", 1)

SafeAddString(BMR_ZOS_LIMITATIONS							, "En raison d'une restriction du jeu, BMR n'a traité que 98 objets de votre inventaire. Veuillez patienter 10 secondes et interagir à nouveau avec le PNJ.", 1)
-- Nouvelles options / ScriptTracker
SafeAddString(BMR_GLOBAL_ADDON_PROFILE			, "Profil global de l'addon (rechargement automatique)", 1)
SafeAddString(BMR_GLOBAL_ADDON_PROFILE_TOOLTIP	, "Sélectionne le profil global de BMR. L'interface sera rechargée après modification. Par défaut : <<1>>", 1)
SafeAddString(BMR_PROFILE_COUNT					, "Nombre de profils", 1)
SafeAddString(BMR_PROFILE_COUNT_TOOLTIP			, "Détermine le nombre de profils BMR disponibles. Les profils au-delà de cette valeur sont conservés mais masqués jusqu'à ce que la valeur soit augmentée.", 1)

SafeAddString(BMR_SCRIPTTRACKER						, "ScriptTracker / Parchemins", 1)
SafeAddString(BMR_SCRIPTTRACKER_DESC					, "Dépose automatiquement en banque les parchemins déjà connus par le personnage actuel et retire de la banque ceux qu'il ne connaît pas encore. BMR effectue les transferts.", 1)
SafeAddString(BMR_SCRIPTTRACKER_ENABLE				, "Activer la gestion automatique des parchemins", 1)
SafeAddString(BMR_SCRIPTTRACKER_ENABLE_TOOLTIP	, "Utilise les connaissances du personnage actuel indiquées par ScriptTracker lors de l'ouverture de la banque.", 1)
SafeAddString(BMR_SCRIPTTRACKER_DEPOSIT_KNOWN	, "Déposer les parchemins connus", 1)
SafeAddString(BMR_SCRIPTTRACKER_WITHDRAW_UNKNOWN, "Retirer les parchemins inconnus", 1)
SafeAddString(BMR_SCRIPTTRACKER_ONE_ONLY			, "Ne retirer qu'un exemplaire par parchemin inconnu", 1)
SafeAddString(BMR_SCRIPTTRACKER_ONE_ONLY_TOOLTIP, "Si activé, BMR retire au maximum un exemplaire de chaque parchemin inconnu. Si le parchemin est déjà dans l'inventaire, aucun autre exemplaire n'est retiré.", 1)
SafeAddString(BMR_SCRIPTTRACKER_DEBUG				, "Activer les messages de débogage ScriptTracker", 1)
SafeAddString(BMR_SCRIPTTRACKER_DEBUG_TOOLTIP	, "Affiche des informations détaillées de diagnostic ScriptTracker/BMR dans le chat. Désactivé par défaut.", 1)

