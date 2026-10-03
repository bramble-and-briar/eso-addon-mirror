local lmb,rmb = '|t16:16:AlphaGear/asset/lmb.dds|t','|t16:16:AlphaGear/asset/rmb.dds|t'

AGLang = {}

AGLang.msg = {
	Copy = 'Copy',
	Paste = 'Paste',
	Clear = 'Clear',
	Insert = 'Insert currently equipped',

	-- new since 6.6.0
	ToBankAll = 'Deposit all gear sets',
	FromBankAll = 'Withdraw all gear sets',
	FailedToMoveItem = 'Failed to move <<1>>',
	MovingSet = 'Moving set <<1>>...',
	-- end new 6.6.0

	-- new since 6.2.1
	ToBank = 'Deposit gear set',
	FromBank = 'Withdraw gear set',
	CurrentlyEquipped = '<<1>> is still equipped',
	NotEnoughSpaceInBackPack = 'Not enough space in backpack for <<1>>',
	NotEnoughSpaceInBank = 'Not enough space in bank for <<1>>',
	ItemIsStolen = '<<1>> is stolen. Deposit not allowed.',
	ReassignHint = 'Please resave this skill with Shift + Click or drag it from the skill window to get the correct tooltip.',
	ToolTipSkillIcon = lmb..' Choose Icon\n'..rmb..' Reset Icon',
	BindLoadNextSet = 'Load next build',
	BindLoadPreviousSet = 'Load previous build',
	BindToggleSet = 'Toggle last two builds',
	MsgNoPreviousSet = 'You did not equip a second build.',
	ShowMainBinding = 'Show/hide AlphaGear Window',
	-- end new 6.2.1

	Icon = lmb..'Choose icon',
	Set = lmb..' Equip build\n'..rmb..' Edit build',
	NotFound = '<<1>> |cFF0000was not found...|r',
	NotEnoughSpace = '|cFFAA33AlphaGear|r |cFF0000Not enough bag-space...|r',
	SoulgemUsed = '<<C:1>> |cFFAA33was recharged.|r',
	SetPart = '\n|cFFAA33Part of build: <<C:1>>|r',
	Lock = 'If the buld is locked, all empty slots will be unequipped.\nIf the build is unlocked, all empty slots will be ignored.\n\n'..lmb..' Lock/unlock',
	Unequip = 'Unequip armor',
	UnequipAll = 'Unequip entire gear',
	
	-- new since 6.1.1
	SetsHeader = 'Profiles/Builds',
	SettingsDesc = 'Configure AlphaGear UI, Auto-Repair and Auto-Recharge.',
	NumVisibleSetButtons = 'Number of Build Buttons to Show',
	GearHeader = 'Gear',
	WeaponsHeader = 'Weapons',
	EquipmentHeader = 'Equipment Panel',
	UIHeader = 'User Interface',
	ResetPositions = 'Reset Positions',
	-- end new 6.1.1
	-- new since 6.1.3
	ShowItemLevelChoices = {'Always', 'Only low items', 'Never'},
	-- end new 6.1.3
	
	-- new since 6.2.0
	OutfitLabel = 'Outfit',
	UneqipAllBinding = 'Unequip entire gear',
	LoadSetBinding = 'Load Build ',
	KeepOutfitItemLabel = 'Keep Current Outfit',
	SetChangeQueuedMsg = 'Build <<1>> (<<2>>) will be equipped when out-of-combat.',
	ActionBar1Text = 'Action-Bar 1',
	ActionBar2Text = 'Action-Bar 2',
	ActionBarNText = 'Action-Bar <<1>>',
	NotEnoughMoneyForRepairMsg = 'Not enough money to repair gear.',
	ItemsRepairedMsg = '<<1>> Items repaired. Total repair cost: <<2>> gold.',
	ItemsNotRepairedMsg = 'Not enough gold for <<1>> Items.',
	-- end new since 6.2.0
	
	-- new since 6.5.0
	BindLoadProfile = 'Load profile ',
	BindLoadNextProfile = 'Load next profile',
	BindLoadPreviousProfile = 'Load previous profile',
	BindToggleProfile = 'Toggle last two profiles',
	MsgNoPreviousProfile = 'No profile to toggle.',
	-- end new since 6.5.0
	
	SetConnector = {
		lmb..' Connect gear with build\n'..rmb..' Remove connection',
		lmb..' Connect actionbar 1 with build\n'..rmb..' Remove connection',
		lmb..' Connect actionbar 2 with build\n'..rmb..' Remove connection'
	},
	Head = {
		Gear = 'Gear ',
		Skill = 'Skills '
	},
	Button = {
		Gear = lmb..' Equip item\n'..rmb..' Remove item',
		Skill = lmb..' Equip skill\n'..rmb..' Remove skill'
	},
	Selector = {
		Gear = lmb..' Equip entire gear\n'..rmb..' More options',
		Skill = lmb..' Equip all skills\n'..rmb..' More options'
	},
	OptionWidth = 300,
	Options = {
		'Show UI button',							-- AG_OPTION_SHOW_MAIN_BUTTON = 1
		'Show build buttons',						-- AG_OPTION_SHOW_SET_BUTTONS = 2
		'Show repair icon',							-- AG_OPTION_SHOW_GEAR_ICON = 3
		'Show repair cost',							-- AG_OPTION_SHOW_REPAIR_COST = 4
		'Show weapon charge icon(s)',				-- AG_OPTION_SHOW_WEAPON_ICON = 5
		'Show weapon swap message',					-- AG_OPTION_SHOW_CHANGE_NOTIFICATION = 6
		'Show equipped build',						-- AG_OPTION_SHOW_ACITVE_SET = 7
		'Mark build items in inventory',				-- AG_OPTION_MARK_SET_ITEMS_IN_BAG = 8
		'Show item condition in percent',			-- AG_OPTION_SHOW_ITEM_CONDITION = 9
		'Show item quality as color',				-- AG_OPTION_SHOW_ITEM_QUALITY = 10
		'Close window on movement',					-- AG_OPTION_CLOSE_WINDOW_ON_MOVE = 11
		'Lock all AlphaGear elements',				-- AG_OPTION_LOCK_UI = 12
		'Automatic weapon charge',					-- AG_OPTION_AUTO_CHARGE_WEAPONS = 13
	-- new since 6.1.1
		'Auto repair armor at stores',				-- AG_OPTION_AUTO_REPAIR_AT_STORES = 14
	-- end new 6.1.1
	-- new since 6.1.3
		'Show item level marker',					-- AG_OPTION_SHOW_ITEM_LEVEL = 15
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
			UseFCOIS = 'Use FCO Item Saver',
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
