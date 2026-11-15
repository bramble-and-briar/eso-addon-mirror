-- Translation by Floliroy

-- Functionality

SafeAddString(SI_COMBAT_METRICS2_LANG, "fr", 1)
SafeAddString(SI_COMBAT_METRICS2_ENCHANTMENT_TRIM, " Enchantement", 1) -- this will be removed from the items enchantment string to show the rest in the info panel, e.g. "Spell Damage Enchantment" is reduced to "Spell Damage".

-- Fonts

--SafeAddString(SI_COMBAT_METRICS2_STD_FONT, "EsoUI/Common/Fonts/Univers57.otf", 1)
--SafeAddString(SI_COMBAT_METRICS2_BOLD_FONT, "EsoUI/Common/Fonts/Univers67.otf", 1)

--SafeAddString(SI_COMBAT_METRICS2_FONT_SIZE_SMALL, "14", 1)
--SafeAddString(SI_COMBAT_METRICS2_FONT_SIZE, "15", 1)
--SafeAddString(SI_COMBAT_METRICS2_FONT_SIZE_TITLE, "20", 1)

-- Main UI

SafeAddString(SI_COMBAT_METRICS2_CALC, "Calcul en Cours...", 1)
SafeAddString(SI_COMBAT_METRICS2_FINALIZING, "Finalisation...", 1)
SafeAddString(SI_COMBAT_METRICS2_GROUP, "Groupe", 1)
SafeAddString(SI_COMBAT_METRICS2_SELECTION, "Sélection", 1)

SafeAddString(SI_COMBAT_METRICS2_BASE_REG, "Régénération de Base", 1)
SafeAddString(SI_COMBAT_METRICS2_DRAIN, "Drain", 1)
SafeAddString(SI_COMBAT_METRICS2_UNKNOWN, "Inconnu", 1)

SafeAddString(SI_COMBAT_METRICS2_BLOCKS, "Bloqués", 1)
SafeAddString(SI_COMBAT_METRICS2_CRITS, "Crits", 1)

SafeAddString(SI_COMBAT_METRICS2_DAMAGE, "Dégâts", 1)
SafeAddString(SI_COMBAT_METRICS2_DAMAGEC, "Dégâts: ", 1)
SafeAddString(SI_COMBAT_METRICS2_HIT, "Hit", 1)
SafeAddString(SI_COMBAT_METRICS2_DPS, "DPS", 1)
SafeAddString(SI_COMBAT_METRICS2_INCOMING_DPS, "DPS Entrant", 1)

SafeAddString(SI_COMBAT_METRICS2_HEALING, "Soins", 1)
SafeAddString(SI_COMBAT_METRICS2_HEALS, "Tics", 1)
SafeAddString(SI_COMBAT_METRICS2_HPS, "HPS", 1)
SafeAddString(SI_COMBAT_METRICS2_HPSA, "HPS + Overheal", 1)
SafeAddString(SI_COMBAT_METRICS2_INCOMING_HPS, "HPS Entrant", 1)

SafeAddString(SI_COMBAT_METRICS2_EDIT_TITLE, "Double clique pour changer le nom du Combat", 1)

SafeAddString(SI_COMBAT_METRICS2_DAMAGE_CAUSED, "Dégâts Infligés", 1)
SafeAddString(SI_COMBAT_METRICS2_DAMAGE_RECEIVED, "Dégâts Reçus", 1)
SafeAddString(SI_COMBAT_METRICS2_HEALING_DONE, "Soins Produits", 1)
SafeAddString(SI_COMBAT_METRICS2_HEALING_RECEIVED, "Soins Reçus", 1)

SafeAddString(SI_COMBAT_METRICS2_TOGGLE_FIGHTSTATS, "Stats de Combat", 1)
SafeAddString(SI_COMBAT_METRICS2_TOGGLE_COMBAT_LOG, "Journal de Combat", 1)
SafeAddString(SI_COMBAT_METRICS2_TOGGLE_GRAPH, "Graph", 1)
SafeAddString(SI_COMBAT_METRICS2_TOGGLE_INFO, "Info", 1)
SafeAddString(SI_COMBAT_METRICS2_TOGGLE_SETTINGS, "Options", 1)

-- Options Menu Strings

SafeAddString(SI_COMBAT_METRICS2_SHOWIDS, "Afficher les IDs", 1) -- (for units, buffs and abilities)
SafeAddString(SI_COMBAT_METRICS2_HIDEIDS, "Cacher les IDs", 1) -- (for units, buffs and abilities)

SafeAddString(SI_COMBAT_METRICS2_SHOWOVERHEAL, "Afficher l'overheal", 1) -- (for units, buffs and abilities)
SafeAddString(SI_COMBAT_METRICS2_HIDEOVERHEAL, "Cacher l'overheal", 1) -- (for units, buffs and abilities)

SafeAddString(SI_COMBAT_METRICS2_POSTDPS, "Poster DPS/HPS", 1)
SafeAddString(SI_COMBAT_METRICS2_POSTSINGLEDPS, "Poster DPS Mono", 1)
SafeAddString(SI_COMBAT_METRICS2_POSTSMARTDPS, "Poster DPS du Boss", 1)
SafeAddString(SI_COMBAT_METRICS2_POSTMULTIDPS, "Poster DPS Total", 1)
SafeAddString(SI_COMBAT_METRICS2_POSTALLDPS, "Poster DPS Mono + Total", 1)
SafeAddString(SI_COMBAT_METRICS2_POSTHPS, "Poster HPS Total", 1)
SafeAddString(SI_COMBAT_METRICS2_POSTUNITDPS, "Poster le DPS sur cette unité", 1)
SafeAddString(SI_COMBAT_METRICS2_POSTUNITNAMEDPS, "Poster le DPS sur '<<1>>'", 1) -- <<1>> is unitname
SafeAddString(SI_COMBAT_METRICS2_POSTSELECTIONDPS, "Poster le DPS sur les unités sélectionnées", 1)
SafeAddString(SI_COMBAT_METRICS2_POSTSELECTIONHPS, "Poster le HPS sur les unités sélectionnées", 1)

-- Format Strings for DPS posting

SafeAddString(SI_COMBAT_METRICS2_BOSS_DPS, "Boss DPS", 1)

SafeAddString(SI_COMBAT_METRICS2_POSTDPS_FORMAT, "<<1>> - DPS: <<2>> (<<3>> sur <<4>>)", 1) -- for single target DPS (<<1>> = fightname, <<2>> = DPS, <<3>> = damage, <<4>> =  ) e.g. Z'Maja - DPS: 10000 (1000000 in 1:40.0)
SafeAddString(SI_COMBAT_METRICS2_POSTSMARTDPS_FORMAT, "<<1>><<2>> - Boss DPS: <<3>> (<<4>> sur <<5>>)", 1) -- (<<1>> = fightname, <<2>> = extraunits (can be ""), <<3>> = DPS, <<4>> = damage, <<5>> = time) e.g. Valariel (+5) - Boss DPS: 10000 (1000000 in 1:40.0)
SafeAddString(SI_COMBAT_METRICS2_POSTMULTIDPS_FORMAT, "<<1>> (+<<2>>) - DPS: <<3>> (<<4>> sur <<5>>)", 1) -- (<<1>> = fightname, <<2>> = extraunits, <<3>> = DPS, <<4>> = damage, <<5>> = time) e.g. Some random Mob (+5) - DPS: 10000 (1000000 in 1:40.0)
SafeAddString(SI_COMBAT_METRICS2_POSTALLDPS_FORMAT_A, "<<1>> - DPS Total (+<<2>>): <<3>> (<<4>> sur <<5>>)", 1) -- multi target part (<<1>> = fightname, <<2>> = extraunits, <<3>> = DPS, <<4>> = damage, <<5>> = time) e.g. Valariel - Total DPS (+5): 10000 (1000000 in 1:40.0)
SafeAddString(SI_COMBAT_METRICS2_POSTALLDPS_FORMAT_B, "<<1>>: <<2>> (<<3>> sur <<4>>)", 1) --  single target part (<<1>> = Label, <<2>> = DPS, <<3>> = damage) e.g. Boss DPS (+2): 10000 (1000000 in 1:40.0)
SafeAddString(SI_COMBAT_METRICS2_POSTSELECTIONDPS_FORMAT, "<<1>><<2>> - DPS Sélectionné: <<3>> (<<4>> sur <<5>>)", 1) -- (<<1>> = fightname, <<2>> = extraunits (can be ""), <<3>> = DPS, <<4>> = damage, <<5>> = time) e.g. Valariel (+5) - Boss DPS: 10000 (1000000 in 1:40.0)
SafeAddString(SI_COMBAT_METRICS2_POSTHPS_FORMAT, "<<1>> - HPS: <<2>> (<<3>> sur <<4>>)", 1) -- (<<1>> = fightname, <<2>> = HPS, <<3>> = damage, <<4>> = time)  e.g. Z'Maja - HPS: 10000 (1000000 in 1:40.0)
SafeAddString(
	SI_COMBAT_METRICS2_POSTSELECTIONHPS_FORMAT,
	"<<1>> - HPS Sélectionné (x<<2>>): <<3>> (<<4>> sur <<5>>)",
	1
) -- (<<1>> = fightname, <<2>> = units, <<3>> = HPS, <<4>> = damage, <<5>> = time) e.g. Z'Maja - HPS (12): 10000 (1000000 in 1:40.0)

SafeAddString(SI_COMBAT_METRICS2_POSTBUFF, "Poster l'uptime du buff", 1)
SafeAddString(SI_COMBAT_METRICS2_POSTBUFF_BOSS, "Poster l'uptime du buff sur le(s) boss", 1)
SafeAddString(SI_COMBAT_METRICS2_POSTBUFF_GROUP, "Poster l'uptime du buff sur le groupe", 1)
SafeAddString(SI_COMBAT_METRICS2_POSTBUFF_FORMAT, "<<1>> - Uptime: <<2>> (<<3>><<4[/ sur $d/ sur $d units]>>)", 1) -- (<<1>> = buff name, <<2>> = relative uptime, <<3>> = uptime, <<4>> = time) e.g. Major Intellect - Uptime: 93.2% (9:26 in 10:07)
SafeAddString(
	SI_COMBAT_METRICS2_POSTBUFF_FORMAT_GROUP,
	"<<1>> - Uptime: <<2>>/<<5>> (<<3>>/<<6>><<4[/ sur $d/ sur $d units]>>)",
	1
) -- (<<1>> = buff name, <<2>> = relative uptime, <<3>> = uptime, <<4>> = units, <<5>> = relative group uptime, <<6>> = group uptime) e.g. Minor Sorcery - Uptime: 55.4%/100.6% (5:36/10:11 in 10:07)

SafeAddString(SI_COMBAT_METRICS2_SETTINGS, "Réglages de l'Extension", 1)
SafeAddString(SI_COMBAT_METRICS2_FEEDBACK, "Envoyer un retour / Dons", 1)

-- Graph

SafeAddString(SI_COMBAT_METRICS2_TOGGLE_CURSOR, "Montrer le curseur et la valeur", 1)
SafeAddString(SI_COMBAT_METRICS2_GRAPH_BUFF_GROUP_SELECTOR, "Montrer l'uptime du groupe", 1)

SafeAddString(SI_COMBAT_METRICS2_RECALCULATE, "Recalculer le combat", 1)
SafeAddString(SI_COMBAT_METRICS2_SMOOTHED, "Lissé", 1)
SafeAddString(SI_COMBAT_METRICS2_TOTAL, "Total", 1)
SafeAddString(SI_COMBAT_METRICS2_ABSOLUTE, "Absolue %", 1)
SafeAddString(SI_COMBAT_METRICS2_SMOOTH_LABEL, "Lissé: %d s", 1)
SafeAddString(SI_COMBAT_METRICS2_NONE, "Aucun", 1)
SafeAddString(SI_COMBAT_METRICS2_BOSS_HP, "Boss HP", 1)
SafeAddString(SI_COMBAT_METRICS2_ENLARGE, "Agrandir", 1)
SafeAddString(SI_COMBAT_METRICS2_SHRINK, "Rétrécir", 1)

-- Feedback

SafeAddString(SI_COMBAT_METRICS2_FEEDBACK_MAIL, "Envoyer un Mail", 1)
SafeAddString(SI_COMBAT_METRICS2_FEEDBACK_GOLD, "Donner 5000g", 1)
SafeAddString(SI_COMBAT_METRICS2_FEEDBACK_GOLD2, "Donner 25000g", 1)
SafeAddString(SI_COMBAT_METRICS2_FEEDBACK_ESOUI, "Site (ESOUI)", 1)
SafeAddString(SI_COMBAT_METRICS2_FEEDBACK_GITHUB, "GitHub", 1)
SafeAddString(
	SI_COMBAT_METRICS2_FEEDBACK_TEXT,
	"\nSi vous trouvez un bug, avez une requête ou une suggestion, envoyez moi un mail en jeu, créez une issue sur GitHub, ou postez dans les commentaires sur EsoUI. \n\nLes dons sont appréciés mais pas nécessaires ni obligatoires. \nSi vous voulez donner de l'argent réel merci de regarder sur EsoUI",
	1
)

SafeAddString(
	SI_COMBAT_METRICS2_STORAGE_FULL,
	"Le fichier de stockage est plein. Supprimer un combat pour libérer de l'espace !",
	1
)

-- Fight Control Button Tooltips

SafeAddString(SI_COMBAT_METRICS2_PREVIOUS_FIGHT, "Combat Précédent", 1)
SafeAddString(SI_COMBAT_METRICS2_NEXT_FIGHT, "Combat Suivant", 1)
SafeAddString(SI_COMBAT_METRICS2_MOST_RECENT_FIGHT, "Combat le Plus Récent", 1)
SafeAddString(SI_COMBAT_METRICS2_LOAD_FIGHT, "Chargement du Combat", 1)
SafeAddString(SI_COMBAT_METRICS2_SAVE_FIGHT, "Clique: Enregistre le Combat", 1)
SafeAddString(SI_COMBAT_METRICS2_SAVE_FIGHT2, "Shift+Clique: Enregistre le Combat ainsi que le Journal de Combat", 1)
SafeAddString(SI_COMBAT_METRICS2_DELETE_COMBAT_LOG, "Supprime le Journal de Combat", 1)
SafeAddString(SI_COMBAT_METRICS2_DELETE_FIGHT, "Supprime le Combat", 1)

-- Fight List

SafeAddString(SI_COMBAT_METRICS2_RECENT_FIGHT, "Combats Récents", 1)
SafeAddString(SI_COMBAT_METRICS2_DURATION, "Durée", 1)
SafeAddString(SI_COMBAT_METRICS2_CHARACTER, "Personnage", 1)
SafeAddString(SI_COMBAT_METRICS2_ZONE, "Zone", 1)
SafeAddString(SI_COMBAT_METRICS2_TIME, "Temps", 1)
SafeAddString(SI_COMBAT_METRICS2_TIME2, "Date", 1)
SafeAddString(SI_COMBAT_METRICS2_TIMEC, "Temps: ", 1)

SafeAddString(SI_COMBAT_METRICS2_SHOW, "Montrer", 1)
SafeAddString(SI_COMBAT_METRICS2_DELETE, "Supprimer", 1)

SafeAddString(SI_COMBAT_METRICS2_SAVED_FIGHTS, "Combats Sauvegardés", 1)

-- More UI Strings

SafeAddString(SI_COMBAT_METRICS2_ACTIVE_TIME, "Temps Actif:", 1)
SafeAddString(SI_COMBAT_METRICS2_ZERO_SEC, "0 s", 1)
SafeAddString(SI_COMBAT_METRICS2_IN_COMBAT, "En Combat:", 1)

SafeAddString(SI_COMBAT_METRICS2_PLAYER, "Joueur", 1)

SafeAddString(SI_COMBAT_METRICS2_TOTALC, "Total:", 1)
SafeAddString(SI_COMBAT_METRICS2_NORMAL, "Normal:", 1)
SafeAddString(SI_COMBAT_METRICS2_CRITICAL, "Critique:", 1)
SafeAddString(SI_COMBAT_METRICS2_BLOCKED, "Bloqué:", 1)
SafeAddString(SI_COMBAT_METRICS2_SHIELDED, "Shieldé:", 1)
SafeAddString(SI_COMBAT_METRICS2_ABSOLUTEC, "Absolue:", 1)
SafeAddString(SI_COMBAT_METRICS2_OVERHEAL, "Overheal:", 1)

SafeAddString(SI_COMBAT_METRICS2_HITS, "Hits", 1)
SafeAddString(SI_COMBAT_METRICS2_NORM, "Norm", 1) -- Normal, short
SafeAddString(SI_COMBAT_METRICS2_OH, "OH", 1) -- Overheal, short

SafeAddString(SI_COMBAT_METRICS2_RESOURCES, "Ressources", 1)

SafeAddString(SI_COMBAT_METRICS2_STATS, "Stats", 1)
SafeAddString(SI_COMBAT_METRICS2_AVE, "Moy", 1) -- Average, short
SafeAddString(SI_COMBAT_METRICS2_AVE_N, "Moy N", 1) -- Average Normal, short
SafeAddString(SI_COMBAT_METRICS2_AVE_C, "Moy C", 1) -- Average Crit, short
SafeAddString(SI_COMBAT_METRICS2_AVERAGE, "Moyen", 1)
SafeAddString(SI_COMBAT_METRICS2_NORMAL_HITS, "Hits Normaux", 1)
SafeAddString(SI_COMBAT_METRICS2_MAX, "Max", 1) -- Maximum
SafeAddString(SI_COMBAT_METRICS2_MIN, "Min", 1) -- Minimum

SafeAddString(SI_COMBAT_METRICS2_STATS_MAGICKA1, "Magie Max:", 1)
SafeAddString(SI_COMBAT_METRICS2_STATS_MAGICKA2, "Dégâts des Sorts:", 1)
SafeAddString(SI_COMBAT_METRICS2_STATS_MAGICKA3, "Critique Mag:", 1)
SafeAddString(SI_COMBAT_METRICS2_STATS_MAGICKA_FORMAT3, "%.1f %%", 1) -- e.g. 12.3%
SafeAddString(SI_COMBAT_METRICS2_STATS_MAGICKA4, "Dégâts Critiques:", 1)
SafeAddString(SI_COMBAT_METRICS2_STATS_MAGICKA5, "Pénétration Mag:", 1)
SafeAddString(SI_COMBAT_METRICS2_STATS_MAGICKA6, "Sur-Pénétration:", 1)
SafeAddString(SI_COMBAT_METRICS2_STATS_MAGICKA_FORMAT6, "%.1f %%", 1) -- e.g. 12.3%

SafeAddString(SI_COMBAT_METRICS2_STATS_STAMINA1, "Vigueur Max:", 1)
SafeAddString(SI_COMBAT_METRICS2_STATS_STAMINA2, "Dégâts des Armes:", 1)
SafeAddString(SI_COMBAT_METRICS2_STATS_STAMINA3, "Critique Phys:", 1)
SafeAddString(SI_COMBAT_METRICS2_STATS_STAMINA_FORMAT3, "%.1f %%", 1) -- e.g. 12.3%
SafeAddString(SI_COMBAT_METRICS2_STATS_STAMINA4, "Dégâts Critiques:", 1)
SafeAddString(SI_COMBAT_METRICS2_STATS_STAMINA5, "Pénétration Phys:", 1)
SafeAddString(SI_COMBAT_METRICS2_STATS_STAMINA6, "Sur-Pénétration:", 1)
SafeAddString(SI_COMBAT_METRICS2_STATS_STAMINA_FORMAT6, "%.1f %%", 1) -- e.g. 12.3%

SafeAddString(SI_COMBAT_METRICS2_STATS_HEALTH1, "Santé Max:", 1)
SafeAddString(SI_COMBAT_METRICS2_STATS_HEALTH2, "Résistance Phys:", 1)
SafeAddString(SI_COMBAT_METRICS2_STATS_HEALTH3, "Résistance Mag:", 1)
SafeAddString(SI_COMBAT_METRICS2_STATS_HEALTH4, "Crit Résistance:", 1)
SafeAddString(SI_COMBAT_METRICS2_STATS_HEALTH_FORMAT4, "%.1f %%", 1) -- e.g. 12.3%

SafeAddString(SI_COMBAT_METRICS2_PENETRATION_TT, "Pénétration: Dégâts", 1)

SafeAddString(SI_COMBAT_METRICS2_COMBAT_LOG, "Journal de Combat", 1)

SafeAddString(SI_COMBAT_METRICS2_GOTO_PREVIOUS, "Aller aux pages précédentes", 1)
SafeAddString(SI_COMBAT_METRICS2_PAGE, "Page <<1>>", 1) -- <<1>> = page number
SafeAddString(SI_COMBAT_METRICS2_GOTO_NEXT, "Aller aux pages suivantes", 1)

SafeAddString(SI_COMBAT_METRICS2_TOGGLE_HEAL, "Affiche les Soins Reçus", 1)
SafeAddString(SI_COMBAT_METRICS2_TOGGLE_DAMAGE, "Affiche les Dégâts Reçus", 1)

SafeAddString(SI_COMBAT_METRICS2_TOGGLE_YOUR_HEAL, "Affiche les Soins Produits", 1)
SafeAddString(SI_COMBAT_METRICS2_TOGGLE_YOUR_DAMAGE, "Affiche les Dégâts Infligés", 1)

SafeAddString(SI_COMBAT_METRICS2_TOGGLE_BUFFIN_EVENTS, "Affiche les Buffs Entrants", 1)
SafeAddString(SI_COMBAT_METRICS2_TOGGLE_BUFFOUT_EVENTS, "Affiche les Buffs Sortants", 1)
SafeAddString(SI_COMBAT_METRICS2_TOGGLE_GROUPBUFFIN_EVENTS, "Affiche les Buffs de Groupe Entrants", 1)
SafeAddString(SI_COMBAT_METRICS2_TOGGLE_GROUPBUFFOUT_EVENTS, "Affiche les Buffs de Groupe Sortants", 1)
SafeAddString(SI_COMBAT_METRICS2_TOGGLE_RESOURCE_EVENTS, "Affiche les Événements sur les Ressources", 1)
SafeAddString(SI_COMBAT_METRICS2_TOGGLE_STATS_CHANGE_EVENTS, "Affiche les Changements sur les Stats", 1)
SafeAddString(
	SI_COMBAT_METRICS2_TOGGLE_MESSAGE_CHANGE_EVENTS,
	"Affiche les Informations, comme le Changement d'Armes",
	1
)
SafeAddString(SI_COMBAT_METRICS2_TOGGLE_SKILL_USE_EVENTS, "Activer les Événements sur les Sorts Utilisés", 1)

-- \n = new line

SafeAddString(SI_COMBAT_METRICS2_DEBUFF_IN, "(De-)Buffs\nEntrants", 1)
SafeAddString(SI_COMBAT_METRICS2_DEBUFF_OUT, "(De-)Buffs\nSortants", 1)
SafeAddString(SI_COMBAT_METRICS2_MAGICKA_PM, "Magie\n +/-", 1)
SafeAddString(SI_COMBAT_METRICS2_STAMINA_PM, "Ressources\n +/-", 1)
SafeAddString(SI_COMBAT_METRICS2_RESOURCES_PM, "Ressources\n +/-", 1)

SafeAddString(SI_COMBAT_METRICS2_BUFF, "Buff", 1)
SafeAddString(SI_COMBAT_METRICS2_BUFFS, "Buffs", 1)
SafeAddString(SI_COMBAT_METRICS2_DEBUFFS, "Debuffs", 1)
SafeAddString(SI_COMBAT_METRICS2_SHARP, "#", 1)
SafeAddString(SI_COMBAT_METRICS2_BUFFCOUNT_TT, "Joueur / Global", 1)
SafeAddString(SI_COMBAT_METRICS2_UPTIME, "Uptime %", 1)
SafeAddString(SI_COMBAT_METRICS2_UPTIME_TT, "Joueur % / Global %", 1)

SafeAddString(SI_COMBAT_METRICS2_REGENERATION, "Régénération", 1)
SafeAddString(SI_COMBAT_METRICS2_CONSUMPTION, "Consommation", 1)
SafeAddString(SI_COMBAT_METRICS2_PM_SEC, "±/s", 1)
SafeAddString(SI_COMBAT_METRICS2_TARGET, "Cible", 1)
SafeAddString(SI_COMBAT_METRICS2_PERCENT, "%", 1)
SafeAddString(
	SI_COMBAT_METRICS2_UNITDPS_TT,
	"DPS réel, par exemple votre DPS entre le premier et le dernier coup infligé à cette cible.",
	1
)

SafeAddString(SI_COMBAT_METRICS2_ABILITY, "Compétence", 1)
SafeAddString(SI_COMBAT_METRICS2_PER_HITS, "/Hits", 1)
SafeAddString(SI_COMBAT_METRICS2_CRITS_PER, "Crit %", 1)

SafeAddString(SI_COMBAT_METRICS2_FAVOURITE_ADD, "Ajouter aux Favoris", 1)
SafeAddString(SI_COMBAT_METRICS2_FAVOURITE_REMOVE, "Enlever des Favoris", 1)

SafeAddString(SI_COMBAT_METRICS2_SKILL, "Sort", 1)

SafeAddString(SI_COMBAT_METRICS2_BAR, "Barre ", 1)
SafeAddString(SI_COMBAT_METRICS2_AVERAGEC, "Moyen: ", 1)

SafeAddString(SI_COMBAT_METRICS2_SKILLTIME_LABEL2, "< A / S", 1) -- as in "Weapon / Skill"
SafeAddString(SI_COMBAT_METRICS2_SKILLTIME_LABEL3, "A / S >", 1)

SafeAddString(SI_COMBAT_METRICS2_SKILLTIME_TT1, "Nombre d'utilisations de ce sort", 1)
SafeAddString(
	SI_COMBAT_METRICS2_SKILLTIME_TT2,
	"Temps depuis la dernière attaque (arme/sort) et l'actication de ce sort",
	1
)
SafeAddString(
	SI_COMBAT_METRICS2_SKILLTIME_TT3,
	"Temps ente l'activation de ce sort et la prochaine attaque (arme/sort)",
	1
)
SafeAddString(SI_COMBAT_METRICS2_SKILLTIME_TT4, "Temps moyen entre deux activations de ce sort", 1)

SafeAddString(SI_COMBAT_METRICS2_SKILLAVG_TT, "Temps moyen perdu entre deux utlisations de sorts", 1)
SafeAddString(SI_COMBAT_METRICS2_SKILLTOTAL_TT, "Temps total perdu entre deux utlisations de sorts", 1)

SafeAddString(SI_COMBAT_METRICS2_TOTALWA, "Attaques de l'arme: ", 1)
SafeAddString(SI_COMBAT_METRICS2_TOTALWA_TT, "Nombre total d'attaques de l'arme", 1)
SafeAddString(SI_COMBAT_METRICS2_TOTALSKILLS, "Sorts : ", 1)
SafeAddString(SI_COMBAT_METRICS2_TOTALSKILLS_TT, "Nombre total de sorts envoyés", 1)

SafeAddString(SI_COMBAT_METRICS2_SAVED_DATA, "Données Enregistrées", 1)

-- Live Report Window

SafeAddString(SI_COMBAT_METRICS2_SHOW_XPS, "<<1>> / <<2>> (<<3>>%)", 1) -- Format to show DPS/HPS. <<1>> = own value, <<2>> = group value, <<3>> = percentage

-- Settings Menu

SafeAddString(SI_COMBAT_METRICS2_MENU_PROFILES, "Profils", 1)

SafeAddString(SI_COMBAT_METRICS2_MENU_AC_NAME, "Utiliser les paramètres du compte", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_AC_TOOLTIP,
	"Si activé, tous les personnages du compte partageront les mêmes paramètres.",
	1
)

SafeAddString(SI_COMBAT_METRICS2_MENU_GS_NAME, "Réglages Généraux", 1)

SafeAddString(SI_COMBAT_METRICS2_MENU_FH_NAME, "Historique de Combat", 1)
SafeAddString(SI_COMBAT_METRICS2_MENU_FH_TOOLTIP, "Nombres de combats récents à sauvegarder.", 1)

SafeAddString(SI_COMBAT_METRICS2_MENU_SVSIZE_NAME, "Mémoire des Combats Sauvegardés", 1)
SafeAddString(SI_COMBAT_METRICS2_MENU_SVSIZE_TOOLTIP, "Taille maximum de la mémoire des combats sauvegardés en MB.", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_SVSIZE_WARNING,
	"A utiliser avec précaution ! Beaucoup de données sauvegardées augmentent les temps de chargement. Si le fichier devient trop volumineux, le client peut se bloquer lors d'une tentative de chargement.",
	1
)

SafeAddString(SI_COMBAT_METRICS2_MENU_BOSSFIGHTS_NAME, "Garder les Combats de Boss", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_BOSSFIGHTS_TOOLTIP,
	"Supprime les combats des trahs en priorité avant de supprimer les combats de boss quand la limite de combats est atteinte.",
	1
)

SafeAddString(SI_COMBAT_METRICS2_MENU_MG_NAME, "Enregistre les Dégâts du Groupe", 1)
SafeAddString(SI_COMBAT_METRICS2_MENU_MG_TOOLTIP, "Enregistre les événements du groupe entier.", 1)

SafeAddString(SI_COMBAT_METRICS2_MENU_STACKS_NAME, "Affiche les stacks de buffs", 1)
SafeAddString(SI_COMBAT_METRICS2_MENU_STACKS_TOOLTIP, "Affiche les stacks individuels dans le panneau de buff.", 1)

SafeAddString(SI_COMBAT_METRICS2_MENU_GL_NAME, "Enregistre les Dégâts dans les Grand Groupes", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_GL_TOOLTIP,
	"Enregistre les événements du groupe entier, pour les grands groupes (plus de 4 membres).",
	1
)

SafeAddString(SI_COMBAT_METRICS2_MENU_LM_NAME, "Mode Réduit", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_LM_TOOLTIP,
	"En mode réduit, l'extension ne calculera que le DPS / HPS dans la fenêtre de rapport en direct. Aucune statistique ne sera calculée et la grand fenêtre de rapport sera désactivée.",
	1
)

SafeAddString(SI_COMBAT_METRICS2_MENU_NOPVP_NAME, "Désactiver en Cyrodiil", 1)
SafeAddString(SI_COMBAT_METRICS2_MENU_NOPVP_TOOLTIP, "Désactive l'extension pour tous les combats en Cyrodiil.", 1)

SafeAddString(SI_COMBAT_METRICS2_MENU_LMPVP_NAME, "Mode Réduit en Cyrodiil", 1)
SafeAddString(SI_COMBAT_METRICS2_MENU_LMPVP_TOOLTIP, "L'extension passera en mode réduit dans Cyrodiil.", 1)

SafeAddString(SI_COMBAT_METRICS2_MENU_ASCC_NAME, "Sélection Automatique du Canal", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_ASCC_TOOLTIP,
	"Sélectionne automatiquement le canal où publier le DPS / HPS. Quand en groupe / g est utilisé, sinon / s.",
	1
)
SafeAddString(SI_COMBAT_METRICS2_MENU_AS_NAME, "Screenshot Automatique", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_AS_TOOLTIP,
	"Prend automatiquement un screenshot lors de l'ouverture de la fenêtre de rapport.",
	1
)
SafeAddString(SI_COMBAT_METRICS2_MENU_ML_NAME, "Longueur de Combat Minimale pour le Screeshot", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_ML_TOOLTIP,
	"Longeur minimale de combat en secondes pour le screenshot automatique.",
	1
)
SafeAddString(SI_COMBAT_METRICS2_MENU_SF_NAME, "Échelle de la Fenêtre de Rapport de Combat", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_SF_TOOLTIP,
	"Ajuste la taille de tous les éléments de la fenêtre de rapport de combat.",
	1
)

SafeAddString(SI_COMBAT_METRICS2_MENU_RESPEN_NAME, "Résistance et Pénétration", 1)
SafeAddString(SI_COMBAT_METRICS2_MENU_CRUSHER, "Écraseur", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_CRUSHER_TOOLTIP,
	"Réduction de la résistance grâce à la glyphe Écraseur. Pour une glyphe légendaire :\n-Standard: 1622\n-Infusé/Torug: 2108\n-Infusé+Torug: 2740",
	1
)
SafeAddString(SI_COMBAT_METRICS2_MENU_MOBRESISTANCE, "Résistance de la Cible", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_MOBRESISTANCE_TOOLTIP,
	"Résistance supposée de la cible pour le calcul de la sur-pénétration.",
	1
)

SafeAddString(SI_COMBAT_METRICS2_MENU_LR_NAME, "Fenêtre de Rapport en Direct", 1)
SafeAddString(SI_COMBAT_METRICS2_MENU_ENABLE_NAME, "Activé", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_ENABLE_TOOLTIP,
	"Active la fenêtre de rapport en direct qui affiche le DPS / HPS pendant le combat.",
	1
)

SafeAddString(SI_COMBAT_METRICS2_MENU_LR_LOCK, "Verouiller", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_LR_LOCK_TOOLTIP,
	"Verouille la fenêtre de rapport en direct afin qu'elle ne puisse pas être déplacée.",
	1
)

SafeAddString(SI_COMBAT_METRICS2_MENU_LR_ALIGNMENT, "Utiliser des Nombres Alignés à Gauche", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_LR_ALIGNMENT_TOOLTIP,
	"Dans la fenêtre de rapport en direct, les chiffres de Dégâts / Soins / etc. sont alignés à gauche.",
	1
)

SafeAddString(SI_COMBAT_METRICS2_MENU_LAYOUT_NAME, "Disposition", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_LAYOUT_TOOLTIP,
	"Sélectionnez la disposition de la fenêtre de rapport en direct.",
	1
)
SafeAddString(SI_COMBAT_METRICS2_MENU_SCALE_NAME, "Taille", 1)
SafeAddString(SI_COMBAT_METRICS2_MENU_SCALE_TOOLTIP, "Taille de la fenêtre de rapport en direct.", 1)

SafeAddString(SI_COMBAT_METRICS2_MENU_BGALPHA_NAME, "Opacité du Fond", 1)
SafeAddString(SI_COMBAT_METRICS2_MENU_BGALPHA_TOOLTIP, "Permet de choisir l'Opacité du Fond.", 1)

SafeAddString(SI_COMBAT_METRICS2_MENU_SHOW_DPS_NAME, "Affiche le DPS", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_SHOW_DPS_TOOLTIP,
	"Affiche le DPS sortant dans la fenêtre de rapport en direct.",
	1
)
SafeAddString(SI_COMBAT_METRICS2_MENU_SHOW_SDPS_NAME, "Affiche le DPS mono", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_SHOW_SDPS_TOOLTIP,
	"Affiche le DPS mono que vous faites dans la fenêtre de rapport en direct.",
	1
)
SafeAddString(SI_COMBAT_METRICS2_MENU_SHOW_HPS_NAME, "Affiche le HPS", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_SHOW_HPS_TOOLTIP,
	"Affiche le HPS sortant dans la fenêtre de rapport en direct.",
	1
)
SafeAddString(SI_COMBAT_METRICS2_MENU_SHOW_HPSA_NAME, "Affiche les soins et l'overheal", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_SHOW_HPSA_TOOLTIP,
	"Affiche les soins incluant l'overheal dans la fenêtre de rapport en direct",
	1
)
SafeAddString(SI_COMBAT_METRICS2_MENU_SHOW_INC_DPS_NAME, "Affiche le DPS entrant", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_SHOW_INC_DPS_TOOLTIP,
	"Affiche le DPS entrant dans la fenêtre de rapport en direct.",
	1
)
SafeAddString(SI_COMBAT_METRICS2_MENU_SHOW_INC_HPS_NAME, "Affiche le HPS entrant", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_SHOW_INC_HPS_TOOLTIP,
	"Affiche le HPS entrant dans la fenêtre de rapport en direct.",
	1
)
SafeAddString(SI_COMBAT_METRICS2_MENU_SHOW_TIME_NAME, "Affiche la Durée", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_SHOW_TIME_TOOLTIP,
	"Affiche le temps à partir du moment ou vous avez fait des dégâts.",
	1
)

SafeAddString(SI_COMBAT_METRICS2_MENU_CHAT_TITLE, "Journal de Combat dans le Chat", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_CHAT_DH_TOOLTIP,
	"Affiche les Dégâts et Soins dans la fenêtre de discussion.",
	1
)
SafeAddString(SI_COMBAT_METRICS2_MENU_CHAT_TITLE_NAME, "Nom de la Fenêtre de Chat", 1)
SafeAddString(SI_COMBAT_METRICS2_MENU_CHAT_TITLE_TOOLTIP, "Permet de choisir le nom de la fenêtre de chat.", 1)
SafeAddString(SI_COMBAT_METRICS2_MENU_CHAT_SD_NAME, "Affiche les Dégâts", 1)
SafeAddString(SI_COMBAT_METRICS2_MENU_CHAT_SD_TOOLTIP, "Affiche les dégâts infligés dans la fenêtre de chat.", 1)
SafeAddString(SI_COMBAT_METRICS2_MENU_CHAT_SH_NAME, "Affiche les Soins", 1)
SafeAddString(SI_COMBAT_METRICS2_MENU_CHAT_SH_TOOLTIP, "Affiche les heals produits dans la fenêtre de chat.", 1)
SafeAddString(SI_COMBAT_METRICS2_MENU_CHAT_SID_NAME, "Affiche les Dégâts Entrants", 1)
SafeAddString(SI_COMBAT_METRICS2_MENU_CHAT_SID_TOOLTIP, "Affiche les dégâts reçus dans la fenêtre de chat.", 1)
SafeAddString(SI_COMBAT_METRICS2_MENU_CHAT_SIH_NAME, "Affiche les Soins Entrants", 1)
SafeAddString(SI_COMBAT_METRICS2_MENU_CHAT_SIH_TOOLTIP, "Affiche les soins reçus dans la fenêtre de chat.", 1)

SafeAddString(SI_COMBAT_METRICS2_MENU_DEBUG_TITLE, "Options de Débogage", 1)
SafeAddString(SI_COMBAT_METRICS2_MENU_DEBUG_SF_NAME, "Affiche le Récapitulatif de Combat", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_DEBUG_SF_TOOLTIP,
	"Affiche le récapitulatif de combat dans la fenêtre de discussion système.",
	1
)
SafeAddString(SI_COMBAT_METRICS2_MENU_DEBUG_SA_NAME, "Affiche les IDs des Sorts", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_DEBUG_SA_TOOLTIP,
	"Affiche les IDs des sorts dans la fenêtre de rapport de combat.",
	1
)
SafeAddString(SI_COMBAT_METRICS2_MENU_DEBUG_SFC_NAME, "Affiche les Infos de Calcul de Combat", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_DEBUG_SFC_TOOLTIP,
	"Affiche les informations sur les temps de calcul de combat dans la fenêtre de discussion système.",
	1
)
SafeAddString(SI_COMBAT_METRICS2_MENU_DEBUG_BI_NAME, "Affiche les Infos des Buffs", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_DEBUG_BI_TOOLTIP,
	"Affiche les événements de buffs dans la fenêtre de discussion système (Attention Spam).",
	1
)
SafeAddString(SI_COMBAT_METRICS2_MENU_DEBUG_US_NAME, "Affiche les Infos des Sorts Utilisés", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_DEBUG_US_TOOLTIP,
	"Affiche les événements de sorts utilisés dans la fenêtre de discussion système.",
	1
)
SafeAddString(SI_COMBAT_METRICS2_MENU_DEBUG_SG_NAME, "Affiche les Infos du Groupe", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_DEBUG_SG_TOOLTIP,
	"Affiche les entrées et sorties du groupe dans la fenêtre de discussion sytème.",
	1
)
SafeAddString(SI_COMBAT_METRICS2_MENU_DEBUG_MD_NAME, "Affiche Diverses Infos de Débogage", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_DEBUG_MD_TOOLTIP,
	"Affiche quelques autres événements dans la fenêtre de discussion système.",
	1
)
SafeAddString(SI_COMBAT_METRICS2_MENU_DEBUG_SPECIAL_NAME, "Informations de Débogage Spéciales", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_DEBUG_SPECIAL_TOOLTIP,
	"Affiche certains événements spéciaux dans la fenêtre de discussion sytème.",
	1
)
SafeAddString(SI_COMBAT_METRICS2_MENU_DEBUG_SAVE_NAME, "Affiche les Infos de Sauvegarde", 1)
SafeAddString(
	SI_COMBAT_METRICS2_MENU_DEBUG_SAVE_TOOLTIP,
	"Affiche les informations de débogage sur les combats enregistrés et chargés dans la fenêtre de discussion système.",
	1
)

-- make a label for keybinding

SafeAddString(SI_BINDING_NAME_CMX_REPORT_TOGGLE, "Ouvrir Fenêtre de Rapport", 1)
SafeAddString(SI_BINDING_NAME_CMX_LIVEREPORT_TOGGLE, "Afficher Rapport en Direct", 1)
SafeAddString(SI_BINDING_NAME_CMX_POST_DPS_SMART, "Poster DPS du Boss ou Total", 1)
SafeAddString(SI_BINDING_NAME_CMX_POST_DPS_SINGLE, "Poster DPS Mono", 1)
SafeAddString(SI_BINDING_NAME_CMX_POST_DPS_MULTI, "Poster DPS Multi", 1)
SafeAddString(SI_BINDING_NAME_CMX_POST_DPS, "Poster DPS Mono + Multi", 1)
SafeAddString(SI_BINDING_NAME_CMX_POST_HPS, "Poster Soins dans le Chat", 1)
SafeAddString(SI_BINDING_NAME_CMX_RESET_FIGHT, "Reset Manuel du Combat", 1)
