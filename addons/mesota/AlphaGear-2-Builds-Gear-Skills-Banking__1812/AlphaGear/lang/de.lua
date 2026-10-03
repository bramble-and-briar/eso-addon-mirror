local lmb,rmb = '|t16:16:AlphaGear/asset/lmb.dds|t','|t16:16:AlphaGear/asset/rmb.dds|t'



AGLang.msg = {
	Copy = 'Kopieren',
	Paste = 'Einfügen',
	Clear = 'Leeren',
	Insert = 'Aktuell ausgerüstete einfügen',

	-- new since 6.6.0
	ToBankAll = 'Alle Sets in die Bank legen',
	FromBankAll = 'Alle Sets aus der Bank holen',
	FailedToMoveItem = '<<1>> konnte nicht verschoben werden',
	MovingSet = 'Moving set <<1>>...',
	-- end new 6.6.0

	-- new since 6.2.1
	ToBank = 'Ausrüstung in die Bank legen',
	FromBank = 'Ausrüstung aus der Bank holen',
	CurrentlyEquipped = '<<1>> ist noch ausgerüstet',
	NotEnoughSpaceInBackPack = 'Nicht genug Platz im Rucksack für <<1>>',
	NotEnoughSpaceInBank = 'Nicht genug Platz in der Bank für <<1>>',
	ItemIsStolen = '<<1>> ist gestohlen. Einlagern ist nicht erlaubt.',
	ReassignHint = 'Weise die Fertigkeit neu zu, um den richtigen Tooltip zu erhalten (aus dem Fertigkeiten-Fenster ziehen oder mit Shift+Click übernehmen).',
	ToolTipSkillIcon = lmb..' Ikone wählen\n'..rmb..' Ikone zurücksetzen',
	BindLoadNextSet = 'Lade nächstes Build',
	BindLoadPreviousSet = 'Lade vorheriges Build',
	BindToggleSet = 'Wechsle letzte zwei Builds',
	MsgNoPreviousSet = 'Es war noch kein zweites Build aktiv.',
	ShowMainBinding = 'AlphaGear Fenster öffnen/schließen',
	-- end new 6.2.1

	Icon = lmb..'Ikone manuell auswählen',
	Set = lmb..' Build anlegen\n'..rmb..' Build bearbeiten',
	NotFound = '<<1>> |cFF0000konnte nicht gefunden werden...|r',
	NotEnoughSpace = '|cFFAA33AlphaGear|r |cFF0000Nicht genügend Taschenplatz...|r',
	SoulgemUsed = '<<C:1>> |cFFAA33wurde neu aufgeladen.|r',
	SetPart = '\n|cFFAA33Teil vom Build: <<C:1>>|r',
	Lock = 'Ist das Build gesperrt, werden leere Plätze ausgezogen.\nIst das Build entsperrt, werden leere Plätze ignoriert.\n\n'..lmb..' Sperren/Entsperren',
	Unequip = 'Rüstung ausziehen',
	UnequipAll = 'Alles ausziehen',
	
	-- new since 6.1.1
	SetsHeader = 'Profile/Builds',
	SettingsDesc = 'Einstellungen für AlphaGear UI, Auto-Repair und Auto-Recharge.',
	NumVisibleSetButtons = 'Anzahl der anzuzeigenden Build-Buttons',
	GearHeader = 'Rüstung',
	WeaponsHeader = 'Waffen',
	EquipmentHeader = 'Ausrüstungs-Panel',
	UIHeader = 'Benutzeroberfläche',
	ResetPositions = 'Positionen zurücksetzen',
	-- end new 6.1.1
	-- new since 6.1.3
	ShowItemLevelChoices = {'Immer', 'Nur bei niedrigen', 'Nie'},
	-- end new 6.1.3

	-- new since 6.2.0
	OutfitLabel = 'Montur',
	UneqipAllBinding = 'Alles ausziehen',
	LoadSetBinding = 'Lade Build ',
	KeepOutfitItemLabel = 'Aktuelle Montur beibehalten',
	SetChangeQueuedMsg = 'Build <<1>> (<<2>>) wird nach Ende des Kampfs ausgerüstet.',
	ActionBar1Text = 'Aktionsleiste 1',
	ActionBar2Text = 'Aktionsleiste 2',
	ActionBarNText = 'Aktionsleiste <<1>>',
	NotEnoughMoneyForRepairMsg = 'Nicht genügend Gold, um die Ausrüstung zu reparieren.',
	ItemsRepairedMsg = '<<1>> Gegenstände für <<2>> Gold repariert.',
	ItemsNotRepairedMsg = 'Nicht genügend Gold für <<1>> Gegenstände.',
	-- end new since 6.2.0

	-- new since 6.5.0
	BindLoadProfile = 'Lade Profil ',
	BindLoadNextProfile = 'Lade nächstes Profil',
	BindLoadPreviousProfile = 'Lade vorheriges Profil',
	BindToggleProfile = 'Wechsle letzte zwei Profile',
	MsgNoPreviousProfile = 'Es war noch kein zweites Profil aktiv.',
	-- end new since 6.5.0
	
	SetConnector = {
		lmb..' Ausrüstung mit Build verbinden\n'..rmb..' Verbindung entfernen',
		lmb..' Aktionsleiste 1 mit Build verbinden\n'..rmb..' Verbindung entfernen',
		lmb..' Aktionsleiste 2 mit Build verbinden\n'..rmb..' Verbindung entfernen'
	},
	Head = {
		Gear = 'Ausrüstung ',
		Skill = 'Fertigkeiten '
	},
	Button = {
		Gear = '\n'..lmb..' Gegenstand anlegen\n'..rmb..' Gegenstand entfernen',
		Skill = '\n'..lmb..' Fertigkeit ausrüsten\n'..rmb..' Fertigkeit entfernen'
	},
	Selector = {
		Gear = lmb..' Gesamte Ausrüstung anlegen\n'..rmb..' Weitere Optionen',
		Skill = lmb..' Alle Fertigkeiten ausrüsten\n'..rmb..' Weitere Optionen'
	},
	OptionWidth = 310,
	Options = {
		'AlphaGear Button anzeigen',
		'Build-Buttons anzeigen',
		'Reparatur-Icon anzeigen',
		'Reparatur-Kosten anzeigen',
		'Waffen-Ladung-Icon(s) anzeigen',
		'Waffenwechsel-Meldung anzeigen',
		'Angelegtes Build anzeigen',
		'Build-Items im Inventar markieren',
		'Item-Zustand in Prozent anzeigen',
		'Item-Qualität als Farbe anzeigen',
		'Fenster bei Bewegung schließen',
		'Alle AlphaGear-Elemente sperren',
		'Waffen automatisch aufladen',
	-- new since 6.1.1
		'Rüstung bei Händlern automatisch reparieren',
	-- end new 6.1.1
	-- new since 6.1.3
		'Item-Level als Marker anzeigen',
	-- end new 6.1.3
	-- new since 6.4.1 
		'<Unused Message>',		
		'Letztes Build bei Wechsel des Profils laden',
	-- end new since 6.4.1
	},

	-- new since 6.8.1
	Integrations = {
		Inventory = {
			Title = 'Inventory Manager',
			UseFCOIS = 'Verwende FCO Item Saver',
			FCOIS = {
				GearMarkerIconLabel = 'Ikone',
				NoGearMarkerIconEntry = '-None-',
			}
		},

		Styling = {
			Title = 'Style Manager',
			UseAlphaStyle = 'Verwende AlphaStyle',
		},

		Champion = {
			Title = 'Champion Point Manager',
			UseCPSlots = 'Verwende Champion Point Slots',
		},

		QuickSlot = {
			Title = 'Quickslot Manager',
			UseGMQSB = 'Verwende Greymind Quick Slot Bar',
		},

	},
	-- new since 6.8.1
}
