local lmb,rmb = '|t16:16:AlphaGear/asset/lmb.dds|t','|t16:16:AlphaGear/asset/rmb.dds|t'



AGLang.msg = {
    Copy = '拷贝',
    Paste = '粘贴',
    Clear = '清除',
    Insert = '插入当前装备的',

	-- new since 6.6.0
	ToBankAll = 'Deposit all gear sets',
	FromBankAll = 'Withdraw alle gear sets',
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
	ReassignHint = 'Please resave this skill with Shift + Click or Drag it from the Skill Window to get the correct tooltip.',
	ToolTipSkillIcon = lmb..' Choose Icon\n'..rmb..' Reset Icon',
	BindLoadNextSet = 'Load next set',
	BindLoadPreviousSet = 'Load previous set',
	BindToggleSet = 'Toggle last two sets',
    MsgNoPreviousSet = 'You did not equip a second set.',
	ShowMainBinding = 'Show/hide AlphaGear Window',
	-- end new 6.2.1

    Icon = lmb..'选择图标',
    Set = lmb..' 装备套装\n'..rmb..' 编辑套装',
    NotFound = '<<1>> |cFF0000没有找到...|r',
    NotEnoughSpace = '|cFFAA33AlphaGear|r |cFF0000没有足够的空间...|r',
    SoulgemUsed = '<<C:1>> |cFFAA33已充能.|r',
    SetPart = '\n|cFFAA33套装: <<C:1>>|r',
    Lock = '如果套装锁定, 所有空的槽位将会卸下装备.\n如果套装解锁, 所有空的槽位将会忽略.\n\n'..lmb..' 锁定/解锁',
    Unequip = '卸下装备',
    UnequipAll = '卸下所有装备',
	
	-- new since 6.1.1
	SetsHeader = 'Sets',
	SettingsDesc = 'Configure AlphaGear UI, Auto-Repair and Auto-Recharge.',
	NumVisibleSetButtons = 'Number of Set Buttons to Show',
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
	LoadSetBinding = 'Load Set ',
	KeepOutfitItemLabel = 'Keep Current Outfit',
	SetChangeQueuedMsg = 'Set <<1>> (<<2>>) will be equiped when out-of-combat.',
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
        lmb..' 连接装备到套装\n'..rmb..' 移除连接',
        lmb..' 连接动作条 1 到套装\n'..rmb..' 移除连接',
        lmb..' 连接动作条 2 到套装\n'..rmb..' 移除连接'
    },
    Head = {
        Gear = '装备 ',
        Skill = '技能 '
    },
    Button = {
        Gear = lmb..' 装备物品\n'..rmb..' 移除物品',
        Skill = lmb..' 装备技能\n'..rmb..' 移除技能'
    },
    Selector = {
        Gear = lmb..' 装备所有装备\n'..rmb..' 更多选项',
        Skill = lmb..' 装备所有技能\n'..rmb..' 更多选项'
    },
    OptionWidth = 300,
    Options = {
        '显示界面按钮',
        '显示界面套装按钮',
        '显示修理按钮',
        '显示修理花费',
        '显示武器充能图标',
        '显示武器切换信息',
        '显示正在装备的套装',
        '在物品栏中标记套装',
        '显示物品耐久度百分比',
        '显示物品质量为颜色',
        '移动时关闭窗口',
        '锁定所有AlphaGear的元素',
        '自动武器充能',
	-- new since 6.1.1
		'Auto repair armor at stores',
	-- end new 6.1.1
	-- new since 6.1.3
		'Show item level marker',
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
