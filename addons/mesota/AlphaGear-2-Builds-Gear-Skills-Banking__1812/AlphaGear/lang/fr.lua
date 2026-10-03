local lmb,rmb = '|t16:16:AlphaGear/asset/lmb.dds|t','|t16:16:AlphaGear/asset/rmb.dds|t'



AGLang.msg = {
	Copy = 'Copier',
	Paste = 'Coller',
	Clear = 'Effacer',
	Insert = 'Placer actuellement équipé',

	-- new since 6.6.0
	ToBankAll = 'Deposit all gear sets',
	FromBankAll = 'Withdraw alle gear sets',
	FailedToMoveItem = 'Failed to move <<1>>',
	MovingSet = 'Moving set <<1>>...',
	-- end new 6.6.0

	-- new since 6.2.1
	ToBank = 'Déposer l\'ensemble',
	FromBank = 'Retirer l\'ensemble',
	CurrentlyEquipped = '<<1>> est déjà équipé',
	NotEnoughSpaceInBackPack = 'Espace Inventaire insuffisant pour <<1>>',
	NotEnoughSpaceInBank = 'Espace Banque insuffisant pour <<1>>',
	ItemIsStolen = '<<1>> a été volé. Depôt interdit.',
	ReassignHint = 'Rechargez cet item avec Shift + Click ou ramenez-le depuis la liste de compétences.',
	ToolTipSkillIcon = lmb..' Choisir l\'icône\n'..rmb..' Réinitialiser l\'icône',
	BindLoadNextSet = 'Charger l\'équipement suivant',
	BindLoadPreviousSet = 'Charger l\'équipement précédent',
	BindToggleSet = 'Échanger les deux derniers ensembles',
	MsgNoPreviousSet = 'Vous n\'avez pas de second ensemble.',
	ShowMainBinding = 'Afficher/Cacher la fenêtre AlphaGear',
	-- end new 6.2.1

	Icon = lmb..'Sélectionner l\'icône',
	Set = lmb..' Équiper l\'ensemble\n'..rmb..' Modifier l\'ensemble',
	NotFound = '<<1>> |cFF0000n\'a pas été trouvé...|r',
	NotEnoughSpace = '|cFFAA33AlphaGear|r |cFF0000Pas assez d\'espace d\'inventaire...|r',
	SoulgemUsed = '<<C:1>> |cFFAA33a été rechargé.|r',
	SetPart = '\n|cFFAA33Élément de l\'ensemble: <<C:1>>|r',
	Lock = 'Si l\'ensemble est verrouillé, tous les slots vides seront déséquipés.\nSi l\'ensemble est déverrouillé, tous les slots vides seront ignorés.\n\n'..lmb..' Verrouiller/Déverrouiller',
	Unequip = 'Enlever l\'armure',
	UnequipAll = 'Enlever tous les équipements',
	
	-- new since 6.1.1
	SetsHeader = 'Ensembles',
	SettingsDesc = 'Configurer AlphaGear UI, auto-réparation et auto-recharge.',
	NumVisibleSetButtons = 'Nombre de boutons d\'ensembles à afficher',
	GearHeader = 'Équipement',
	WeaponsHeader = 'Armes',
	EquipmentHeader = 'Tableau d\'Équipement',
	UIHeader = 'Interface Utilisateur',
	ResetPositions = 'Réinitialiser les Positions',
	-- end new 6.1.1
	-- new since 6.1.3
	ShowItemLevelChoices = {'Toujours', 'Seulement les bas niveaux', 'Jamais'},
	-- end new 6.1.3
	
	-- new since 6.2.0
	OutfitLabel = 'Équipement',
	UneqipAllBinding = 'Deséquiper complètement ',
	LoadSetBinding = 'Charger l\'ensemble ',
	KeepOutfitItemLabel = 'Conserver l\'équipement actuel',
	SetChangeQueuedMsg = 'L\'ensemble <<1>> (<<2>>) sera chargé après le combat',
	ActionBar1Text = 'Barre d\'action 1',
	ActionBar2Text = 'Barre d\'action 2',
	ActionBarNText = 'Barre d\'action <<1>>',
	NotEnoughMoneyForRepairMsg = 'Pas assez d\'argent pour réparer.',
	ItemsRepairedMsg = '<<1>> objets réparés. Coût total: <<2>> pièces d\'or.',
	ItemsNotRepairedMsg = 'Pas assez d\'argent pour <<1>> objets.',
	-- end new since 6.2.0
	
	-- new since 6.5.0
	BindLoadProfile = 'Load profile ',
	BindLoadNextProfile = 'Load next profile',
	BindLoadPreviousProfile = 'Load previous profile',
	BindToggleProfile = 'Toggle last two profiles',
	MsgNoPreviousProfile = 'No profile to toggle.',
	-- end new since 6.5.0
	
	SetConnector = {
		lmb..' Lier l\'équipement avec l\'ensemble\n'..rmb..' Supprimer le lien',
		lmb..' Lier la barre d\'action principale avec l\'ensemble\n'..rmb..' Supprimer le lien',
		lmb..' Lier la barre d\'action secondaire avec l\'ensemble\n'..rmb..' Supprimer le lien'
	},
	Head = {
		Gear = 'Équipement ',
		Skill = 'Compétences '
	},
	Button = {
		Gear = lmb..' Équiper l\'objet\n'..rmb..' Supprimer l\'objet',
		Skill = lmb..' Placer la compétence\n'..rmb..' Supprimer la compétence'
	},
	Selector = {
		Gear = lmb..' Équiper tout l\'équipement\n'..rmb..' plus d\'options',
		Skill = lmb..' Placer toutes les compétences\n'..rmb..' plus d\'options'
	},
	OptionWidth = 400,
	Options = {
		'Afficher le bouton de l\'interface',
		'Afficher les boutons d\'ensembles',
		'Afficher l\'icône de réparation',
		'Afficher le coût de réparation',
		'Afficher les icônes de charge d\'arme',
		'Afficher le message de switch d\'arme',
		'Afficher l\'ensemble porté',
		'Marquer les objets d\'ensemble dans l\'inventaire',
		'Afficher le taux d\'usure en pourcentage',
		'Afficher la qualité de l\'objet en tant que couleur',
		'Fermer la fenêtre au déplacement du personnage',
		'Verrouiller les objets AlphaGear',
		'Rechargement automatique de l\'arme',
	-- new since 6.1.1
		'Réparation automatique chez les marchands',
	-- end new 6.1.1
	-- new since 6.1.3
		'Montrer le marqueur de niveau de l\'objet',
	-- end new 6.1.3
	-- new since 6.4.1
	'<Unused Message>',		
	'Auto load last build of profile',          -- AG_OPTION_LOAD_LAST_BUILD_OF_PROFILE = 17
-- end new since 6.4.1
},

-- new since 6.8.1
Integrations = {
	Inventory = {
		Title = 'Inventory Manager',
		UseFCOIS = 'Show FCOIS marker icons',
		FCOIS = {
			GearMarkerIconLabel = 'Marker icon',
			NoGearMarkerIconEntry = '-None-',
		}
	},

	Styling = {
		Title = 'Style Manager',
		UseAlphaStyle = 'Use AlphaStyle',
	},

	Champion = {
		Title = 'Champion Point Manager',
		UseCPSlots = 'Use Champion Point Slots',
	},

	QuickSlot = {
		Title = 'Quickslot Manager',
		UseGMQSB = 'Use Greymind Quick Slot Bar',
	},

},
-- new since 6.8.1
}
