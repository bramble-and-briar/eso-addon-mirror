--- @class Srendarr
local Srendarr = _G['Srendarr'] -- grab addon table from global
local L = {}

------------------------------------------------------------------------------------------------------------------
-- French (fr) - Thanks to ESOUI.com user Ayantir for the translations.
-- Indented or commented lines still require human translation and may not make sense!
------------------------------------------------------------------------------------------------------------------

L.Srendarr = "|c67b1e9S|c4779ce'rendarr|r"
L.Srendarr_Basic = "S'rendarr"
L.Usage = "|c67b1e9S|c4779ce'rendarr|r - Usage : /srendarr lock/unlock : Verrouille/Déverrouille les fenêtres pour définir leur positionnement."
L.CastBar = 'Barre de cast'
L.Sound_DefaultProc = 'Srendarr (Procs par défaut)'
L.ToggleVisibility = 'Toggle Srendarr Visibilité'
L.UpdateGearSets = "Mettre à jour les ensembles d'équipement équipés"

-- time format						
L.Time_Tenths = '%.1fs'
L.Time_TenthsNS = '%.1f'
L.Time_Seconds = '%ds'
L.Time_SecondsNS = '%d'
L.Time_Minutes = '%dm'
L.Time_Hours = '%dh'
L.Time_Days = '%dj'

-- aura grouping
L.Group_Displayed_Here = 'Groupes affichés'
L.Group_Displayed_None = 'Aucun'
L.Group_Player_Short = 'Vos buffs courts'
L.Group_Player_Long = 'Vos buffs longs'
L.Group_Player_Major = "Vos buffs 'Majeurs'"
L.Group_Player_Minor = "Vos buffs 'Mineurs'"
L.Group_Player_Toggled = 'Vos buffs continus'
L.Group_Player_Ground = 'Vos cibles au sol'
L.Group_Player_Enchant = 'Vos Enchant Procs'
L.Group_Player_Cooldowns = 'Vos capacités de recouvrement'
L.Group_Player_CABar = "Barre d'action de recharge"
L.Group_Player_Passive = 'Vos passifs'
L.Group_Player_Debuff = 'Vos debuffs'
L.Group_Target_Buff = 'Les buffs de la cible'
L.Group_Target_Debuff = 'Les débuffs de la cible'
L.Group_ProminentType = 'Type proéminent'
L.Group_ProminentTypeTip = "Sélectionnez le type de l'aura à surveiller (Buff, Debuff)."
L.Group_ProminentTarget = 'Cible proéminente'
L.Group_ProminentTargetTip = "Sélectionnez la cible de l'aura à surveiller (joueur, cible, AOE)."
L.Group_GroupBuffs = 'Cadres de buff de groupe'
L.Group_RaidBuffs = 'Cadres de buff de raid'
L.Group_GroupDebuffs = 'Cadres de debuff de groupe'
L.Group_RaidDebuffs = 'Cadres de debuff de raid'
L.Group_Cooldowns = 'Tracker de recharge'
L.Group_CooldownBar = 'Bar à recharge actif'
L.Group_Cooldown = 'Recharge'

-- whitelist & blacklist control
L.Prominent_RemoveByRecent = "retiré de la proéminente en raison d'une mauvaise classification, devrait être le type"
L.Prominent_AuraAddSuccess = 'ajouté au cadre'
L.Prominent_AuraAddAs = 'comme'
L.Prominent_AuraAddFail = "n'a pas été trouvé et ne peut être ajouté."
L.Prominent_AuraAddFailByID = "est pas un abilityID valide ou est pas l'ID d'une aura chronométré et ne pouvait pas être ajouté."
L.Prominent_AuraAddFailByName = 'Paramètres manquants ou incorrects.'
L.Prominent_AuraRemoveFail = "Pour supprimer une aura proéminente, vous devez d'abord cliquer sur un nom à partir d'un menu de renfreneur de modification de l'aura. Ne modifiez aucune valeur après avoir cliqué sur une aura ou la suppression échouera."
L.Prominent_AuraRemoveSuccess = 'a été supprimé de la liste proéminente.'
L.Blacklist_AuraAddSuccess = 'a été ajouté à la liste noire et ne sera plus affiché.'
L.Blacklist_AuraAddFail = "n'a pas été trouvé et ne peux être ajouté."
L.Blacklist_AuraAddFailByID = "ne constitue pas une abilityID valide et n'a pas pu être ajouté à la liste noire."
L.Blacklist_AuraRemoved = 'a été supprimé de la liste noire.'
L.Group_AuraAddSuccess = 'a été ajouté à la liste blanche du groupe de groupe.'
L.Group_AuraAddSuccess2 = 'a été ajouté à la liste blanche de Debuff du groupe.'
L.Group_AuraRemoved = 'a été supprimé de la liste blanche de la buff de groupe.'
L.Group_AuraRemoved2 = 'a été retiré de la liste blanche de Debuff du groupe.'

-- settings: base
L.Show_Example_Auras = "Ex. d'effets"
L.Show_Example_Castbar = 'Ex. de barre de cast'

L.SampleAura_PlayerTimed = 'Effets temporaires'
L.SampleAura_PlayerToggled = 'Effets continus'
L.SampleAura_PlayerPassive = 'Passifs du joueur'
L.SampleAura_PlayerDebuff = 'Débuffs du joueur'
L.SampleAura_PlayerGround = 'Effet au sol'
L.SampleAura_PlayerMajor = "Effet 'Majeur'"
L.SampleAura_PlayerMinor = "Effet 'Mineur'"
L.SampleAura_TargetBuff = 'Buff de la cible'
L.SampleAura_TargetDebuff = 'Débuff de la cible'

L.TabButton1 = 'Général'
L.TabButton2 = 'Filtres'
L.TabButton3 = 'Barre de cast'
L.TabButton4 = 'Effets'
L.TabButton5 = 'Profils'

L.TabHeader1 = 'Paramètres généraux'
L.TabHeader2 = 'Paramètres de filtres'
L.TabHeader3 = 'Paramètres de la barre de cast'
L.TabHeader5 = 'Paramètres des profils'
L.TabHeaderDisplay = 'Paramètres de la fenêtre : '

-- settings: generic
L.GenericSetting_ClickToViewAuras = 'Cliquer pour voir les effets'
L.GenericSetting_NameFont = 'Police du nom de la compétence'
L.GenericSetting_NameStyle = 'Couleur & Style du nom de la compétence'
L.GenericSetting_NameSize = 'Taille de la police du nom de la compétence'
L.GenericSetting_TimerFont = 'Police du timer'
L.GenericSetting_TimerStyle = 'Couleur & Style de la police du timer'
L.GenericSetting_TimerSize = 'Taille de la police du timer'
L.GenericSetting_BarWidth = 'Largeur de la barre'
L.GenericSetting_BarWidthTip = "Définissez la largeur de la barre de cast lorsqu' elle est affichée."


-- ----------------------------
-- SETTINGS: DROPDOWN ENTRIES
-- ----------------------------
L.DropGroup_1 = 'Dans la fenêtre [|cffd1001|r]'
L.DropGroup_2 = 'Dans la fenêtre [|cffd1002|r]'
L.DropGroup_3 = 'Dans la fenêtre [|cffd1003|r]'
L.DropGroup_4 = 'Dans la fenêtre [|cffd1004|r]'
L.DropGroup_5 = 'Dans la fenêtre [|cffd1005|r]'
L.DropGroup_6 = 'Dans la fenêtre [|cffd1006|r]'
L.DropGroup_7 = 'Dans la fenêtre [|cffd1007|r]'
L.DropGroup_8 = 'Dans la fenêtre [|cffd1008|r]'
L.DropGroup_9 = 'Dans la fenêtre [|cffd1009|r]'
L.DropGroup_10 = 'Dans la fenêtre [|cffd10010|r]'
L.DropGroup_11 = 'Dans la fenêtre [|cffd10011|r]'
L.DropGroup_12 = 'Dans la fenêtre [|cffd10012|r]'
L.DropGroup_13 = 'Dans la fenêtre [|cffd10013|r]'
L.DropGroup_14 = 'Dans la fenêtre [|cffd10014|r]'
L.DropGroup_None = 'Ne pas afficher'

L.DropStyle_Full = 'Affichage détaillé'
L.DropStyle_Icon = 'Icône seulement'
L.DropStyle_Mini = 'Minimal'

L.DropGrowth_Up = 'Haut'
L.DropGrowth_Down = 'Bas'
L.DropGrowth_Left = 'Gauche'
L.DropGrowth_Right = 'Droite'
L.DropGrowth_CenterLeft = 'Centré (Gauche)'
L.DropGrowth_CenterRight = 'Centré (Droite)'
L.DropGrowth_CenterUp = 'Centré (Up)'
L.DropGrowth_CenterDown = 'Centré (Bas)'

L.DropSort_NameAsc = 'Nom de la compétence (Asc)'
L.DropSort_TimeAsc = 'Temps restant (Asc)'
L.DropSort_CastAsc = 'Ordre de cast (Asc)'
L.DropSort_NameDesc = 'Nom de la compétence (Desc)'
L.DropSort_TimeDesc = 'Temps restant (Desc)'
L.DropSort_CastDesc = 'Ordre de cast (Desc)'

L.DropTimer_Above = "Au dessus de l'icône"
L.DropTimer_Below = "Sous l'icône"
L.DropTimer_Over = "Par dessus l'icone"
L.DropTimer_Hidden = 'Masqué'
L.DropAuraClassBuff = 'Buff'
L.DropAuraClassDebuff = 'Debuff'
L.DropAuraTargetPlayer = 'Joueur'
L.DropAuraTargetTarget = 'Cible'
L.DropAuraTargetAOE = 'AOE'
L.DropAuraClassDefault = 'Pas de remplacement'
L.DropGroupMode1 = 'Défaut'
-- 	L.DropGroupMode2							= "Foundry Tactical Combat"
-- 	L.DropGroupMode3							= "Lui Extended"
-- 	L.DropGroupMode4							= "Bandits User Interface"
-- 	L.DropGroupMode5							= "AUI"


-- ------------------------
-- SETTINGS: GENERAL
-- ------------------------
-- general (general options)
L.General_GeneralOptions = 'Options générales'
L.General_GeneralOptionsDesc = "Diverses options générales qui contrôlent le comportement de l'addon."
L.General_UnlockDesc = "Déverrouillez pour permettre de faire glisser les fenêtres d'affichage de l'aura à l'aide de la souris. Réinitialiser annule tous les changements de position depuis le dernier rechargement et les valeurs par défaut ramèneront toutes les fenêtres à leur emplacement par défaut."
L.General_UnlockLock = 'Verrouiller'
L.General_UnlockUnlock = 'Déverrouiller'
L.General_UnlockReset = 'Réinitialiser'
L.General_UnlockDefaults = 'Valeurs par défaut'
L.General_UnlockDefaultsAgain = 'Confirmer les valeurs par défaut'
L.General_PassivesAlways = 'Toujours montrer des passives'
L.General_PassivesAlwaysTip = "Afficher l'auras de la durée passive / longue, même lorsqu'il n'est pas au combat et au-dessus de l'option est vérifié."
L.HideOnDeadTargets = 'Masquer les cibles mortes'
L.HideOnDeadTargetsTip = 'Définissez si vous souhaitez masquer toutes les auras sur des cibles mortes. (Cachera des choses potentiellement utiles comme Repentance use debuff.)'
L.PVPJoinTimer = 'PVP Rejoignez minuterie'
L.PVPJoinTimerTip = "Le jeu bloque les événements enregistrés par Addon lors de l'initialisation du PvP. Ceci est le nombre de secondes qui Srendarr attendra que cela complète, qui peut dépendre de votre CPU et/ou le retard du serveur. Si Auras disparaît lors de la jonction ou de la sortie de PvP, définissez cette valeur plus élevée."
L.ShowTenths = 'Dixièmes de secondes'
L.ShowTenthsTip = 'Afficher les dixièmes près des minuteurs avec seulement quelques secondes. Le curseur définit combien de secondes il reste en dessous duquel les dixièmes commenceront à apparaître. La définition de cette valeur sur 0 désactivera afficher des dixièmes.'
L.ShowSSeconds = "Afficher 's' secondes"
L.ShowSSecondsTip = "Affiche la lettre 's' après les minuteries avec seulement quelques secondes. Les minuteries indiquant les minutes et les secondes ne sont pas affectées par ceci."
L.ShowSeconds = 'Afficher les secondes restantes'
L.ShowSecondsTip = 'Affiche les secondes restantes à côté des minuteurs qui indiquent les minutes. Les minuteurs qui montrent les heures ne sont pas affectés par cela.'
L.General_ConsolidateEnabled = 'Consolider Multi-Auras'
L.General_ConsolidateEnabledTip = "Certaines capacités comme Restauration Aura des Templiers ont de multiples effets de buff, et ceux-ci seront normalement tous les afficher dans la fenêtre de votre aura sélectionné avec la même icône, conduisant à l'encombrement. Cette option regroupe celles-ci en une seule aura."
L.General_AlternateEnchantIcons = "Icônes d'enchantement alternatives"
L.General_AlternateEnchantIconsTip = "Activer: Utilisez un ensemble personnalisé d'icônes pour les effets d'enchanteur. Désactiver: utilisez les icônes d'enchanteur de jeu par défaut."
L.General_PassiveEffectsAsPassive = 'Buffs passifs majeurs et mineurs'
L.General_PassiveEffectsAsPassiveTip = "Définissez si les grands et les buffs mineurs qui sont passifs (pas de durée) sont regroupés avec d'autres auras passifs sur le joueur selon le paramètre «Vos passifs».\n\nS'il n'est pas activé, tous les buffs majeurs et mineurs seront regroupés, qu'ils soient chronométrés ou passifs."
L.General_AuraFadeout = 'Délai de disparition des effets'
L.General_AuraFadeoutTip = "Définissez le temps donné pour la disparition d'affichage d'un effet à l'écran. Un paramètre à 0 fera disparaitre l'aura sans transition."
L.General_ShortThreshold = 'Seuil des buffs courts'
L.General_ShortThresholdTip = "Définissez le seuil en secondes de différence entre les buffs dits 'Courts' et les buffs dits 'Longs'."
L.General_ProcEnableAnims = 'Activer les animations Bar Proc'
L.General_ProcEnableAnimsTip = "Choisissez de créer une animation sur la barre d'action pour les compétences qui ont proqué et possédant une action spéciale à réaliser. Les compétences possédant un proc sont :\n   Fragments de cristal (Sorc)\n   Déchaînement meurtrier & morphs (NB)\n   Langue de feu (DK)\n   Cape Mortelle (Deux armes)"
-- 	L.General_GrimProcAnims						= "Grim Focus Proc Animations"
L.General_GrimProcAnimsTip = "Définissez s'il faut montrer une animation sur l'aura elle-même lorsque Nightblade Grim Dawn ou ses morphes a suffisamment de piles pour lancer l'arc spectre."
L.General_GearProcAnims = "Animations de barre d'action de temps de recharge"
L.General_GearProcAnimsTip = "Définissez s'il faut montrer une animation sur la barre d'action du temps de recharge lorsque les capacités de vitesse sont hors du temps de recharge et prêtes à proc. (Doit attribuer la barre d'action du temps de recharge à un cadre de contrôle AURA - groupes d'affichage.)"
L.General_gearProcCDText = "Durée du bar d'action de temps de recharge"
L.General_gearProcCDTextTip = "Affichez la durée du temps de recharge sur la barre d'action de temps de recharge à côté du nom de procage des capacités de vitesse qui sont prêtes à être utilisées."
L.General_ProcEnableAnimsWarn = "Si vous utilisez un addon modifiant ou masquant la barre d'action, les animations pourront ne pas être affichées."
L.General_ProcPlaySound = "Jouer un son lors d'un proc"
L.General_ProcPlaySoundTip = "Sélectionnez le son à jouer lors d'un proc d'une compétence. Sélectionner 'None' ne jouera aucun son."
L.General_ModifyVolume = 'Volume Modifier Proc'
L.General_ModifyVolumeTip = "Permettre l'utilisation de dessous Proc de volume."
L.General_ProcVolume = 'Volume sonore Proc'
L.General_ProcVolumeTip = 'Remplace temporairement le volume des effets audio lors de la lecture de Srendarr Proc Sound.'
L.General_GroupAuraMode = 'Mode Aura Groupe'
L.General_GroupAuraModeTip = "Sélectionnez le module de support pour les trames d'unité de groupe que vous utilisez actuellement."
L.General_RaidAuraMode = 'Mode Aura Raid'
L.General_RaidAuraModeTip = "Sélectionnez le module de support pour les cadres d'unité raid que vous utilisez actuellement."

-- general (display groups)
L.General_ControlHeader = "Gestion des effets - Groupes d'affichage"
L.General_ControlBaseTip = 'Définissez dans quel groupe de fenêtre afficher vos effets ou les masquer totalement.'
L.General_ControlShortTip = 'Ce groupe contient tous les buffs lancés sur vous-même avec une durée inférieure au seuil des buffs courts.'
L.General_ControlLongTip = 'Ce groupe contient tous les buffs lancés sur vous-même avec une durée supérieure au seuil des buffs courts.'
L.General_ControlMajorTip = "Ce groupe contient tous les effets 'majeurs' (ex: Intellect majeur) qui sont actifs sur vous même. Les effets majeurs négatifs (ex: Brèche majeure) sont slistés dans les débuffs"
L.General_ControlMinorTip = "Ce groupe contient tous les effets 'mineurs' (ex: Dynamisation majeure) qui sont actifs sur vous même. Les effets mineurs négatifs (ex: Profanation mineure) sont slistés dans les débuffs"
L.General_ControlToggledTip = 'Ce groupe contient tous les buffs continus (sans durée définie) qui sont actifs sur vous même.'
L.General_ControlGroundTip = 'Ce groupe contient tous les effets au sol que vous avez lancé.'
L.General_ControlEnchantTip = 'Ce groupe Aura contient tous les effets Enchant qui sont actives sur vous-même (par exemple. Hardening, Berserker).'
L.General_ControlGearTip = "Ce groupe AURA contient tous les procs d'équipement normalement invisibles qui sont actifs sur vous-même (par exemple, le sang de sang)."
L.General_ControlCooldownTip = 'Ce groupe AURA suit le temps de recharge interne de votre Gear Procs.'
L.Group_Player_CABarTip = "Suivez vos temps de recharge équipés et soyez averti lorsqu'ils sont prêts à procurer."
L.General_ControlPassiveTip = 'Ce groupe contient tous les effets passifs qui sont actifs sur vous même.'
L.General_ControlDebuffTip = 'Ce groupe contient tous les effets négatifs qui sont actifs sur vous même.'
L.General_ControlTargetBuffTip = 'Ce groupe contient tous les effets positifs appliqués à votre cible.'
L.General_ControlTargetDebuffTip = 'Ce groupe contient tous les effets négatifs appliqués à votre cible. En raisons de limitation intrinsèques au jeu, seuls vos débuffs apparaitront ici à de très rares exceptions près'
L.General_ControlProminentFrame = 'Cadre proéminent'
L.General_ControlProminentFrameTip = "Sélectionnez le cadre dans lequel afficher cette aura proéminente. Cela remplacera les catégories de filtres normales qui s'appliqueraient autrement à l'aura configurée."

-- general (debug)
L.General_DebugOptions = 'Options de débogage'
L.General_DebugOptionsDesc = 'Aide à traquer Auras manquantes ou incorrectes!'
L.General_DisplayAbilityID = "Activer l'affichage des capacités d'Aura"
L.General_DisplayAbilityIDTip = "Définissez s'il faut afficher la capacité interne de toutes les auras. Cela peut être utilisé pour trouver l'ID exact des auras que vous voudrez peut-être la liste noire de l'affichage ou ajouter au groupe d'affichage de la liste blanche Aura.\n\nCette option peut également être utilisée pour aider à fixer un affichage AURA inexact en signalant les ID errants à l'auteur addon."
L.General_ShowCombatEvents = 'Voir Combat Events'
L.General_ShowCombatEventsTip = "Lorsqu'elle est activée, l'AbilityID et nom de tous les effets (buffs et debuffs) gagnés ou causés par le joueur va montrer dans le chat, suivi par des informations sur la source et la cible, et le code de résultat événementiel (gagné, perdu, etc.).\n\nPour éviter le chat des inondations et de faciliter l'examen, chaque capacité n'affichera une fois jusqu'à ce rechargement. Cependant, vous pouvez taper /sdbclear à tout moment pour réinitialiser manuellement le cache.\n\nAVERTISSEMENT: L'activation de cette option diminue les performances du jeu en grands groupes. Activez uniquement si nécessaire pour tester."
L.General_ShowCombatEventsH1 = 'ATTENTION:'
L.General_ShowCombatEventsH2 = 'Quittant '
L.General_ShowCombatEventsH3 = ' à tout moment diminuera les performances du jeu en grands groupes. Activé uniquement lorsque vous avez besoin pour les tests.'
L.General_AllowManualDebugTip = "Lorsqu'elle est activée, vous pouvez taper /sdbadd XXXXXX ou /sdbremove XXXXXX pour ajouter/supprimer un seul ID du filtre d'inondation. De plus, la typing /sdbignore XXXXXX autorisera toujours l'entrée d'entrée au-delà du filtre d'inondation. Taper /sdbclear sera toujours réinitialiser le filtre."
L.General_DisableSpamControl = 'Désactiver le contrôle des inondations'
L.General_DisableSpamControlTip = "Lorsqu'il est activé le filtre d'événement de combat va imprimer le même événement chaque fois qu'il se produit sans avoir à taper /sdbclear ou recharger pour effacer la base de données."
L.General_VerboseDebug = 'Montrer un débogage verbeux'
L.General_VerboseDebugTip = "Affichez l'intégralité du bloc de données reçu de Event_Combat_event et le chemin d'icône de la capacité pour chaque identifiant qui passe les filtres ci-dessus dans un format lisible (principalement) humain (cela remplira rapidement votre journal de chat)."
L.General_OnlyPlayerDebug = 'Seuls les événements des joueurs'
L.General_OnlyPlayerDebugTip = 'Afficher uniquement les événements de combat de débogage résultant des actions des joueurs.'
L.General_ShowNoNames = 'Afficher les événements Nameless'
L.General_ShowNoNamesTip = "Lorsqu'il est activé le filtre d'événement de combat montre l'événement de même quand ils ont pas de nom ID de texte."
L.General_ShowSetIds = "Afficher les identifiants d'ensemble lors de l'équipement"
L.General_ShowSetIdsTip = "Lorsqu'il est activé, affiche le nom et le setID de tous les équipements équipés lors du changement de pièce."


-- ------------------------
-- SETTINGS: FILTERS
-- ------------------------
L.FilterHeader = 'Listes de filtre et bascules'
L.Filter_Desc = "Ici, vous pouvez les auras de liste noire, les buffs de liste blanche ou les débuts pour apparaître comme proéminents et les attribuer à une fenêtre personnalisée, ou basculer les filtres pour afficher ou cacher différents types d'effets."
L.Filter_RemoveSelected = 'Supprimer sélectionné'
L.Filter_ListAddWarn = "Ajouter un effet par son nom requiert de scanner toutes les compétences existantes. Cette opération peut ralentir votre jeu quelques instants le temps de l'opération."
L.FilterToggle_Desc = "Activer un filtre masquera l'affichage de l'effet à l'écran."

L.Filter_PlayerHeader = "Filtre d'effets pour vous"
L.Filter_TargetHeader = "Filtres d'effets pour la cible"
L.Filter_OnlyPlayerDebuffs = 'Les débuffes des joueurs uniquement'
L.Filter_OnlyPlayerDebuffsTip = "Empêchez l'affichage des auras debuff sur la cible qui n'ont pas été créées par le joueur."
L.Filter_OnlyTargetMajor = 'Seulement cible majeur'
L.Filter_OnlyTargetMajorTip = 'Afficher uniquement des abouts majeurs sur la cible. Tous les autres debuffs cible ne seront pas affichés.'

-- filters (blacklist auras)
L.Filter_BlacklistHeader = 'Blacklist des effets'
L.Filter_BlacklistDesc = 'Auras spécifiques peut être mis en liste noire ici pour ne jamais apparaître dans aucune fenêtre de suivi Aura.'
L.Filter_BlacklistAdd = 'Ajouter un effet à blacklister'
L.Filter_BlacklistAddTip = "L'effet que vous souhaitez blacklister doit être écrit exactement tel qu'il apparait en jeu. Validez par Entrée pour ajouter l'effet à la liste des effets blacklistés."
L.Filter_BlacklistList = 'Effets actuellement blacklistées'
L.Filter_BlacklistListTip = 'Liste de tous les effets actuellement blacklistés. Pour supprimer un effet de la blacklis, sélectionnez le et cliquez sur le bouton Supprimer de la liste.'

-- filters (prominent auras)
L.Filter_ProminentHead = "Affectations de l'aura proéminentes"
L.Filter_ProminentHeadTip = 'Auras peut être affecté à apparaître dans des trames spécifiques pour des types spécifiques (buff, debuff, etc.) sur des cibles spécifiques (joueur, cible, groupe, etc.).'
L.Filter_ProminentOnlyPlayer = 'Seul Player Cast'
L.Filter_ProminentOnlyPlayerTip = 'Surveillez uniquement Aura si le joueur.'
L.Filter_ProminentAddRecent = 'Ajouter une aura récemment vue:'
L.Filter_ProminentAddRecentTip = "Cliquez pour montrer les auras récemment détectés dans diverses catégories. Cliquer sur une aura affichée remplira le panneau de configuration proéminent avec ces données afin que vous puissiez facilement les ajouter à un cadre d'affichage personnalisé."
L.Filter_ProminentResetRecent = 'Réinitialiser récent'
L.Filter_ProminentResetRecentTip = 'Effacer la base de données de liste des auras récemment détectées.'
L.Filter_ProminentModify = 'Modifier les auras de premier plan existants:'
L.Filter_ProminentModifyTip = 'Cliquez pour afficher une liste des auras de premier plan qui ont été définies pour chaque catégorie. En cliquant sur une aura affichée, un panneau de configuration proéminent avec ces données afin que vous puissiez les modifier ou les supprimer.'
L.Filter_ProminentTypePB = 'Buffs de joueur'
L.Filter_ProminentTypePD = 'Debuffs de joueur'
L.Filter_ProminentTypeTB = 'Buffs cibles'
L.Filter_ProminentTypeTD = 'Cible les demandes'
L.Filter_ProminentTypeAOE = 'Effets de la zone'
L.Filter_ProminentResetAll = 'Menus clairs'
L.Filter_ProminentResetAllTip = "Effacez et réinitialisez tous les champs de menu du panneau de l'AURA proéminent."
L.Filter_ProminentTypeGB = 'Buffs de groupe'
L.Filter_ProminentTypeGD = 'Debuffs de groupe'
L.Filter_ProminentAdd = 'Ajouter/Mettre à jour'
L.Filter_ProminentRemove = 'Enlever'
L.Filter_ProminentEdit = 'Aura sélectionné:'
L.Filter_ProminentEditTip1 = 'Sélectionnez une aura dans une liste récemment vue à ajouter, ou sélectionnez-en une dans la liste existante à modifier.'
L.Filter_ProminentEditTip2 = "Lors de l'ajout d'une aura, il nécessite la numérisation de toutes les auras du jeu pour trouver le (s) numéro (s) d'identification interne de la capacité. Cela peut entraîner un instant le jeu pendant un instant pendant la recherche."
L.Filter_ProminentShowIDs = 'Afficher les IDs Aura'
L.Filter_ProminentExpert = 'Expert'
L.Filter_ProminentExpertTip = "Autorisez l'entrée manuelle des auras par nom ou ID et activez la fonction de suppression.\n\n|cffffffALERTE:|r N'ajoutez pas les auras qui apparaissent déjà dans SRENDARR (lorsque leur catégorie est affectée à un cadre) de cette façon. Cela peut coûter des performances et casser les choses. Ajoutez-les à un cadre personnalisé à l'aide d'un menu récemment vu. Les Auras qui sont entrées en tant que mauvais type seront automatiquement supprimées lorsque SRendarr voit le jeu les envoyer avec différents paramètres.\n\n|cffffffEXPÉRIMENTALE:|r Vous pouvez entrer ici AURA ID que le jeu et le SRENDARR ne suivent pas, mais il n'y a aucune garantie qu'ils fonctionneront car le jeu envoie parfois une durée et de mauvaises informations pour ces derniers. Il est préférable de demander un support SRENDARR à ajouter puis pour essayer de forcer les choses manuellement."
L.Filter_ProminentRemoveAll = 'Enlever tout'
L.Filter_ProminentRemoveAllTip = 'Supprime tous les auras proéminents pour le profil actif actuel. AVERTISSEMENT: Si vous utilisez des paramètres larges du compte, cela supprimera toutes les auras de premier plan de la largeur compte.'
L.Filter_ProminentRemoveConfirm = 'Supprimer tous les auras proéminents pour le profil actif actuel?'
L.Filter_ProminentWaitForSearch = 'Rechercher en cours, veuillez patienter.'

-- filters (group frame buffs)
L.Filter_GroupBuffHeader = 'Affectations de buff de groupe'
L.Filter_GroupBuffDesc = 'Cette liste détermine ce que les buffs afficheront à côté du groupe ou du cadre raid de chaque joueur.'
L.Filter_GroupBuffAdd = 'Ajouter un buff de groupe de liste blanche'
L.Filter_GroupBuffAddTip = "Pour ajouter une aura buff pour suivre les trames de groupe, vous devez saisir son nom exactement tel qu'il apparaît dans le jeu. Appuyez sur Entrée pour ajouter l'aura d'entrée à la liste.\n\nAVERTISSEMENT: N'entrez pas ID Aura ici à moins qu'il ne soit normalement suivi par le jeu (entrez au nom de l'aura à la place). Auras entré par ID ici utilise le faux système Aura de Srendarr et coûtera les performances plus les entrées."
L.Filter_GroupBuffList = 'Liste blanche de buff de groupe actuel'
L.Filter_GroupBuffListTip = 'Liste de tous les buffs définis pour apparaître sur les trames de groupe. Pour supprimer les auras existants, sélectionnez-le dans la liste et utilisez le bouton Supprimer ci-dessous.'
L.Filter_GroupBuffsByDuration = 'Exclure les buffs par durée'
L.Filter_GroupBuffsByDurationTip = 'Afficher uniquement les buffs de groupe avec une durée plus courte que sélectionnée ci-dessous (en secondes).'
L.Filter_GroupBuffThreshold = 'Seuil de durée de buff'
L.Filter_GroupBuffWhitelistOff = 'Utiliser comme liste noire de buff'
L.Filter_GroupBuffWhitelistOffTip = "Transformez la liste blanche de Buff en une liste noire et affichez toutes les auras avec une durée, sauf celle de l'entrée ici."
L.Filter_GroupBuffOnlyPlayer = 'Uniquement les buffs de groupes de joueurs'
L.Filter_GroupBuffOnlyPlayerTip = "Afficher uniquement les buffs de groupe lancés par le joueur ou l'un de ses familiers."
L.Filter_GroupBuffsEnabled = 'Activer les buffs de groupe'
L.Filter_GroupBuffsEnabledTip = "Si désactivé, les buffs de groupe ne s'affichent pas du tout."

-- filters (group frame debuffs)
L.Filter_GroupDebuffHeader = 'Affectations de debuff de groupe'
L.Filter_GroupDebuffDesc = 'Cette liste détermine ce que les debuffs afficheront à côté du groupe ou du cadre RAID de chaque joueur.'
L.Filter_GroupDebuffAdd = 'Ajouter le groupe de groupe blanc'
L.Filter_GroupDebuffAddTip = "Pour ajouter une aura debuff pour suivre les trames de groupe, vous devez saisir son nom exactement tel qu'il apparaît dans le jeu. Appuyez sur Entrée pour ajouter l'aura d'entrée à la liste.\n\nAVERTISSEMENT: N'entrez pas ID Aura ici à moins qu'il ne soit normalement suivi par le jeu (entrez au nom de l'aura à la place). Auras entré par ID ici utilise le faux système Aura de Srendarr et coûtera les performances plus les entrées."
L.Filter_GroupDebuffList = 'Liste blanche debuff de groupe actuel'
L.Filter_GroupDebuffListTip = 'Liste de toutes les debuffs pour apparaître sur les trames de groupe. Pour supprimer les auras existants, sélectionnez-le dans la liste et utilisez le bouton Supprimer ci-dessous.'
L.Filter_GroupDebuffsByDuration = 'Exclure les débuts par durée'
L.Filter_GroupDebuffsByDurationTip = 'Afficher uniquement les debuffs de groupe avec une durée plus courte que sélectionnée ci-dessous (en secondes).'
L.Filter_GroupDebuffThreshold = 'Seuil de durée de la debuff'
L.Filter_GroupDebuffWhitelistOff = 'Utiliser comme Debuff Blacklist'
L.Filter_GroupDebuffWhitelistOffTip = 'Transformez la liste blanche de Debuff en groupe en une liste noire et affichez toutes les auras avec une durée, sauf ces entrées ici. '
L.Filter_GroupDebuffsEnabled = 'Activer les débuts de groupe'
L.Filter_GroupDebuffsEnabledTip = "Si désactivé, les débuffes de groupe ne s'affichent pas du tout."

-- filters (unit options)
L.Filter_ESOPlus = 'Filtre ESO Plus'
L.Filter_ESOPlusPlayerTip = "Définissez s'il faut empêcher l'affichage de l'état ESO Plus sur vous-même."
L.Filter_ESOPlusTargetTip = "Définissez s'il faut empêcher l'affichage de l'état ESO Plus sur votre cible."
L.Filter_BlockPlayerTip = "Choisissez de masquer l'affichage du buff de blocage lorsque vous bloquez."
L.Filter_BlockTargetTip = "Choisissez de masquer l'affichage du buff de blocage lorsque votre cible bloque."
L.Filter_MundusBoon = 'Filtrer les pierres de Mundus'
L.Filter_MundusBoonPlayerTip = "Choisissez de masquer l'affichage du bonus de la pierre de Mundus appliqué à vous-même."
L.Filter_MundusBoonTargetTip = "Choisissez de masquer l'affichagedu bonus de la pierre de Mundus appliqué à votre cible."
L.Filter_Cyrodiil = 'Filtrer les bonus de Cyrodiil'
L.Filter_CyrodiilPlayerTip = "Choisissez de masquer l'affichage des buffs AvA de Cyrodiil appliqués à vous-même."
L.Filter_CyrodiilTargetTip = "Choisissez de masquer l'affichage des buffs AvA de Cyrodiil appliqués à votre cible."
L.Filter_Disguise = 'Filtrer les déguisements'
L.Filter_DisguisePlayerTip = "Choisissez de masquer l'affichage du buff de déguisement appliqué à vous-même."
L.Filter_DisguiseTargeTtip = "Choisissez de masquer l'affichage du buff de déguisement appliqué à votre cible."
L.Filter_MajorEffects = 'Filtrer les effets majeurs'
L.Filter_MajorEffectsTargetTip = "Choisissez de masquer les effets 'Majeurs' (ex. Mutilation majeure, Brutalité Majeure) appliqué à votre cible."
L.Filter_MinorEffects = 'Filtrer les effets mineurs'
L.Filter_MinorEffectsTargetTip = "Choisissez de masquer les effets 'Mineurs' (ex. Mutilation mineure, Brutalité mineure) appliqué à votre cible."
L.Filter_SoulSummons = 'Filtrer le timer du rez gratuit'
L.Filter_SoulSummonsPlayerTip = "Choisissez de masquer l'affichage du timer de rez gratuit de la ligne Magie des Ames appliqué à vous-même."
L.Filter_SoulSummonsTargetTip = "Choisissez de masquer l'affichage du timer de rez gratuit de la ligne Magie des Ames appliqué à votre cible."
L.Filter_VampLycan = 'Filtrer les buffs Vampire & Loup-Garou'
L.Filter_VampLycanPlayerTip = "Choisissez de masquer l'affichage des buffs de vampirisme et de lycanthropie appliqué à vous-même."
L.Filter_VampLycanTargetTip = "Choisissez de masquer l'affichage des buffs de vampirisme et de lycanthropie appliqué à votre cible."
L.Filter_VampLycanBite = 'Filtrer le timer de morsure Vampire & Loup-Garou'
L.Filter_VampLycanBitePlayerTip = "Choisissez de masquer l'affichage des buffs de morsure vampire et lycanthropique appliqué à vous-même."
L.Filter_VampLycanBiteTargetTip = "Choisissez de masquer l'affichage des buffs de morsure vampire et lycanthropique appliqué à votre cible."
L.Filter_GroupDurationThreshold = 'Les auras de groupe plus longues que cette durée (en secondes) ne seront pas affichés.'


-- ------------------------
-- SETTINGS: CAST BAR
-- ------------------------
L.CastBar_Enable = 'Activer la barre de cast & de canalisation'
L.CastBar_EnableTip = "Sélectionnez si vous voulez activer une barre de cast déplaçable pour afficher les temps d'incantation ou de canalisation de vos compétences."
L.CastBar_AlphaTip = "Définissez le degré d'opacité de la barre d'incantation hors combat. Un réglage de 0 rend la barre totalement invisible."
L.CastBar_CAlphaTip = "Définissez le degré d'opacité de la barre d'incantation en combat. Un réglage de 0 rend la barre totalement invisible."
L.CastBar_Scale = 'Echelle'
L.CastBar_ScaleTip = 'Définissez la taille de la barre de cast en pourcentage'

-- cast bar (name)
L.CastBar_NameHeader = 'Nom de la compétence castée'
L.CastBar_NameShow = 'Afficher le nom de la compétence castée'

-- cast bar (timer)
L.CastBar_TimerHeader = 'Timer de la barre de cast'
L.CastBar_TimerShow = 'Afficher le timer de la compétence castée'

-- cast bar (bar)
L.CastBar_BarHeader = 'Barre de timer'
L.CastBar_BarReverse = 'Inverser les directions du timer'
L.CastBar_BarReverseTip = 'Définissez si vous souhaitez inverser le timer de la barre de cast.'
L.CastBar_BarGloss = 'Activer la brillance'
L.CastBar_BarGlossTip = 'Définissez si vous souhaitez que la barre du timer possède une brillance améliorée'
L.CastBar_BarColor = 'Couleur de la barre'
L.CastBar_BarColorTip = 'Définissez les couleurs de la barre de cast. La première couleur est la couleur primaire en début de cast, la seconde sera celle affichée à la fin du timer.'


-- ------------------------
-- SETTINGS: DISPLAY FRAMES
-- ------------------------
L.DisplayFrame_Alpha = 'Transparence hors combat'
L.DisplayFrame_AlphaTip = "Définissez le degré d'opacité de cette fenêtre d'aura hors combat. Un réglage de 0 rend la fenêtre totalement invisible."
L.DisplayFrame_CAlpha = 'Transparence au combat'
L.DisplayFrame_CAlphaTip = "Définissez le degré d'opacité de cette fenêtre d'aura en combat. Un réglage de 0 rend la fenêtre totalement invisible."
L.DisplayFrame_Scale = 'Echelle de la fenêtre'
L.DisplayFrame_ScaleTip = 'Définissez la taille de la fenêtre des effets en pourcentage.'

-- display frames (aura)
L.DisplayFrame_AuraHeader = 'Affichage'
L.DisplayFrame_Style = 'Style'
L.DisplayFrame_StyleTip = "Définissez le style qui sera appliqué à cette fenêtre d'effets.\n\n|cffd100Affichage détaillé|r - Affiche le nom de la compétence, son icône, la barre de timer et le texte associé.\n\n|cffd100Icône seulement|r - Affiche l'icône de la compétence et le texte du timer seulement, ce style permet plus d'options pour le sens de l'empilage du temps des effets.\n\n|cffd100Minimal|r - Affiche le nom de la compétence et une barre de timer plus petite."
L.DisplayFrame_AuraCooldown = "Montrer l'animation de la minuterie"
L.DisplayFrame_AuraCooldownTip = "Affichez une animation de minuterie autour des icônes Aura. Cela rend également Auras plus facile à voir que l'ancien mode d'affichage. Personnalisez en utilisant les paramètres de couleur ci-dessous."
L.DisplayFrame_AuraBackground = "Utiliser l'arrière-plan de l'icône"
L.DisplayFrame_AuraBackgroundTip = "Affichez un fond noir derrière l’affichage de l’icône d’aura. Ne peut être désactivé que si vous n'utilisez pas d'animations de minuterie, car cette fonction en dépend pour s'afficher correctement."
L.DisplayFrame_AuraBorder = "Utiliser la bordure de l'icône"
L.DisplayFrame_AuraBorderTip = "Affichez la bordure de style par défaut du jeu autour de l'icône lorsque vous n'utilisez pas l'arrière-plan de l'icône noire de Srendarr."
L.DisplayFrame_CooldownTimed = 'Couleur: buffs chronométrés et débuff'
L.DisplayFrame_CooldownTimedB = 'Couleur: Buffs chronométrés'
L.DisplayFrame_CooldownTimedD = 'Couleur: Debuffs chronométrés'
L.DisplayFrame_CooldownTimedTip = "Définissez la couleur d'animation de la minuterie d'icône pour les auras avec une durée définie.\n\nGAUCHE = BUFFS\nDROITE = DEBUFFS."
L.DisplayFrame_CooldownTimedBTip = "Définissez la couleur d'animation de la minuterie d'icône pour les buffs avec une durée définie."
L.DisplayFrame_CooldownTimedDTip = "Définissez la couleur d'animation de la minuterie d'icône pour les débuts avec une durée définie."
L.DisplayFrame_Growth = "Sens de l'empilage du temps des effets"
L.DisplayFrame_GrowthTip = "Définissez dans quel sens les nouveaux effets doivent s'empiler depuis le point d'origine. Pour les paramètres centrés, les auras augmenteront dans l'une ou l'autre direction de l'ancre avec l'ordre déterminé par option de tri et direction sélectionnée (gauche, droite, haut, en bas).\n\nLes effets ne peuvent s'empiler que lorsqu'ils sont affichés en mode |cffd100Détaillé|r or |cffd100Minimal|r styles."
L.DisplayFrame_Padding = "Espacement entre les piles d'effets"
L.DisplayFrame_PaddingTip = "Définissez l'espacement entre chaque effet."
L.DisplayFrame_Sort = 'Ordre de tri des effets'
L.DisplayFrame_SortTip = "Définissez comment les effets sont triés. Soit par ordre alphabétique, soit par durée restante ou dans l'ordre où ils ont atés castés.\n\nLorsque vous triez par durée, tous les passifs et effets continus seront triés par nom et seront affichés en début ou en fin de pile selon l'ordre de tri, avec les compétences temporaires listées ensuite ou avant."
L.DisplayFrame_Highlight = "Mise en surbrillance des icones d'effet continu"
L.DisplayFrame_HighlightTip = 'Définir si les effets continus doivent être mis en surbrillance pour mieux les distinguer des effets passifs.\n\nNon disponible dans le mode |cffd100Minimal|r.'
L.DisplayFrame_Tooltips = 'Activer les infractions de noms de nom AURA'
L.DisplayFrame_TooltipsTip = "Définissez l'opportunité d'autoriser l'écran Info-bulle de Mouseover pour le nom d'une aura lors du style Icône uniquement. "
L.DisplayFrame_TooltipsWarn = "Les info-bulleurs doivent être temporairement désactivées pour le mouvement de la fenêtre d'affichage, ou ils bloqueront le mouvement."
L.DisplayFrame_AuraClassOverride = 'Aura Class Override'
L.DisplayFrame_AuraClassOverrideTip = "Vous permet de rendre Srendarr traiter toutes les auras chronométrées (bascules et passifs ignorés) dans cette barre comme des buffs ou des débuts, quelle que soit leur classe réelle.\n\nUtile lors de l'ajout de debuffs et AOE à une fenêtre pour faire utiliser les deux couleurs d'animation de bar et d'icône. "

-- display frames (group)
L.DisplayFrame_GRX = 'Décalage horizontal'
L.DisplayFrame_GRXTip = 'Ajustez la position des icônes de buff de groupe/raid à gauche et à droite.'
L.DisplayFrame_GRY = 'Décalage vertical'
L.DisplayFrame_GRYTip = 'Ajustez la position des icônes de buff de groupe/raid de haut en bas.'

-- display frames (name)
L.DisplayFrame_NameHeader = 'Nom de la compétence'

-- display frames (timer)
L.DisplayFrame_TimerHeader = 'Texte du Timer'
L.DisplayFrame_TimerLocation = 'Emplacement du texte du timer'
L.DisplayFrame_TimerLocationTip = 'Définir la position des timers pour chaque effet par rapport à son icone.'
L.DisplayFrame_TimerHMS = 'Afficher Minutes pour les minuteries > 1 heure'
L.DisplayFrame_TimerHMSTip = 'Définissez si vous souhaitez afficher également minutes lorsque une minuterie est supérieure à 1 heure.'

-- display frames (bar)
L.DisplayFrame_BarHeader = 'Barre du timer'
L.DisplayFrame_HideFullBar = 'Barre de minuterie'
L.DisplayFrame_HideFullBarTip = "Cachez complètement la barre et affichez uniquement le texte du nom de l'aura à côté de l'icône en mode affichage complet."
L.DisplayFrame_BarReverse = 'Inverser les directions du timer'
L.DisplayFrame_BarReverseTip = "Définissez si vous souhaitez inverser le timer de l'effet. Dans le mdoe |cffd100Détaillé|r cela inversera également la position de l'icône."
L.DisplayFrame_BarGloss = 'Activer la brillance'
L.DisplayFrame_BarGlossTip = 'Définissez si vous souhaitez que la barre du timer possède une brillance améliorée.'
L.DisplayFrame_BarBuffTimed = 'Couleur: Effets temporaires'
L.DisplayFrame_BarBuffTimedTip = "Définir les couleurs des effets temporaires. La première couleur est la couleur primaire en début d'effet, la seconde sera celle affichée à la fin du timer."
L.DisplayFrame_BarBuffPassive = 'Couleur: Effets passives'
L.DisplayFrame_BarBuffPassiveTip = 'Définir les couleurs des effets temporaires. La première couleur est la couleur primaire en début de barre, la seconde sera celle affichée à la fin de la barre.'
L.DisplayFrame_BarDebuffTimed = 'Couleur: Debuffs chronométrés'
L.DisplayFrame_BarDebuffTimedTip = 'Réglez les couleurs de la barre de minuterie pour les auras de Debuff avec une durée de jeu. Le choix de couleur gauche détermine le début de la barre (quand il commence à compter) et le second la finition de la barre (quand il a presque expiré).'
L.DisplayFrame_BarDebuffPassive = 'Couleur: Debuffs passifs'
L.DisplayFrame_BarDebuffPassiveTip = "Réglez les couleurs de la barre de minuterie pour les auras de débuffes passives sans durée de définition. Le choix de couleur gauche détermine le début de la barre (le côté le plus éloigné de l'icône) et le second la finition de la barre (la plus proche de l'icône)."
L.DisplayFrame_BarToggled = 'Couleur: Effets continus'
L.DisplayFrame_BarToggledTip = 'Définir les couleurs des effets temporaires. La première couleur est la couleur primaire en début de barre, la seconde sera celle affichée à la fin de la barre.'


-- ------------------------
-- SETTINGS: PROFILES
-- ------------------------
L.Profile_Desc = "Les profils de préférences peuvent être gérés ici vous permettant de sélectionner entre une configuration par compte ou par personnage. Vous devez d'abord activer la gestion des profils pour modifier les valeurs ci-dessous."
L.Profile_UseGlobal = 'Utiliser une configuration par compte'
L.Profile_AccountWide = "À l'échelle du compte"
L.Profile_UseGlobalWarn = 'Switcher entre la configuration par personnage et par compte rechargera votre UI.'
L.Profile_Copy = 'Sélectionnez un profil à copier'
L.Profile_CopyTip = "Sélectionnez un profil pour copier ses paramètres dans le profil actuellement actrif. Le profil actif sera soit pour le caractère connecté ou le profil large du compte s'il est activé. Les paramètres de profil existants seront écrasés en permanence.\n\nÇa ne peut pas être annulé!"
L.Profile_CopyButton1 = 'Copier le profil entier'
L.Profile_CopyButton1Tip = "Copiez l'intégralité du profil sélectionné, y compris toutes les configurations de l'aura proéminentes. Voir l'option ci-dessous pour alternative."
L.Profile_CopyButton2 = 'Copier le profil de base'
L.Profile_CopyButton2Tip = "Copiez tout à partir du profil sélectionné sauf des configurations AURA proéminentes. Utile pour la configuration d'une configuration d'affichage de base sans copier la configuration de l'aura spécifique à la classe."
L.Profile_CopyButtonWarn = 'Copier un profil rechargera votre UI.'
L.Profile_CopyCannotCopy = 'Impossible de copier le profil sélectionné. Veuillez réessayer ou sélectionner un autre profil.'
L.Profile_Delete = 'Sélectionnez un profil à supprimer'
L.Profile_DeleteTip = "Sélectionnez un profil à supprimer de la base des paramètres. Si le personnage concerné est reconnecté par la suite, et que vous n'utilisez pas une configuration par compte, celui-ci héritera de la configuration par défaut"
L.Profile_DeleteButton = 'Supprimer le profil'
L.Profile_Guard = 'Activer la gestion des profils'


-- ------------------------
-- Gear Cooldown Alt Names
-- ------------------------
L.YoungWasp = 'Jeune guêpe'
L.MolagKenaHit1 = ' 1er coup'
L.VolatileAOE = 'Familier Explosif Aptitude'


if (GetCVar('language.2') == 'fr') then -- overwrite GetLocale for new language
    for k, v in pairs(Srendarr:GetLocale()) do
        if (not L[k]) then              -- no translation for this string, use default
            L[k] = v
        end
    end

    function Srendarr:GetLocale() -- set new locale return
        return L
    end
end