local lmb,rmb = '|t16:16:AlphaGear/asset/lmb.dds|t','|t16:16:AlphaGear/asset/rmb.dds|t'



AGLang.msg = {
    Copy = 'コピー',
    Paste = 'ペースト',
    Clear = 'クリア',
    Insert = '現在の装備を挿入',

	-- new since 6.6.0
	ToBankAll = 'Deposit all gear sets',
	FromBankAll = 'Withdraw alle gear sets',
    FailedToMoveItem = 'Failed to move <<1>>',
	MovingSet = 'Moving set <<1>>...',
	-- end new 6.6.0

    -- new since 6.2.1
    ToBank = 'セット装備を預ける',
    FromBank = 'セット装備を引き出す',
    CurrentlyEquipped = '<<1>> は装備中です',
    NotEnoughSpaceInBackPack = 'バックパックに <<1>> を引き出すスペースがありません',
    NotEnoughSpaceInBank = '銀行に <<1>> を預けるスペースがありません',
    ItemIsStolen = '<<1>> は盗品です。預けれられません。',
    ReassignHint = 'Shift+左クリックまたはドラッグでこのスキルを再保存してください。スキルウィンドウから正しいツールチップを取得します。',
    ToolTipSkillIcon = lmb..' アイコンを選択\n'..rmb..' アイコンをリセット',
    BindLoadNextSet = '次のセットを装備',
    BindLoadPreviousSet = '前のセットを装備',
    BindToggleSet = '最後2つのセットを切り替え',
    MsgNoPreviousSet = '2つ目のセットを装備出来ません',
    ShowMainBinding = 'ウィンドウの表示/非表示',
    -- end new 6.2.1

    Icon = lmb..'アイコンを選択',
    Set = lmb..' セットを装備\n'..rmb..' セットを編集',
    NotFound = '<<1>> |cFF0000は見つかりませんでした...|r',
    NotEnoughSpace = '|cFFAA33AlphaGear|r |cFF0000バッグ容量が不足しています...|r',
    SoulgemUsed = '<<C:1>> |cFFAA33はリチャージされました.|r',
    SetPart = '\n|cFFAA33セットの一部: <<C:1>>|r',
    Lock = 'セットがロックされている場合、全ての空のスロットは装備が外されます。\nセットがロックされていない場合、全ての空のスロットは無視されます。\n\n'..lmb..' ロック/解除',
    Unequip = '防具を外す',
    UnequipAll = '全体の防具を外す',
    
    -- new since 6.1.1
    SetsHeader = 'セット',
    SettingsDesc = 'AlphaGear UI設定,  自動修理＆自動チャージ。',
    NumVisibleSetButtons = '表示するUIセットボタン数',
    GearHeader = '装備',
    WeaponsHeader = '武器',
    EquipmentHeader = '装備パネル',
    UIHeader = 'ユーザーインターフェース',
    ResetPositions = '位置を初期化',
    -- end new 6.1.1
    -- new since 6.1.3
    ShowItemLevelChoices = {'すべて', '低レベル品のみ', 'オフ'},
    -- end new 6.1.3
 
    -- new since 6.2.0
    OutfitLabel = 'スタイル',
    UneqipAllBinding = '防具を外す',
    LoadSetBinding = 'セット',
    KeepOutfitItemLabel = '今のスタイルを維持',
    SetChangeQueuedMsg = '戦闘中は装備変更できません。セット<<1>> (<<2>>) ',
    ActionBar1Text = 'アクションバー 1',
    ActionBar2Text = 'アクションバー 2',
    ActionBarNText = 'アクションバー <<1>>',
    NotEnoughMoneyForRepairMsg = '装備を修理するお金が足りません。',
	ItemsRepairedMsg = '<<1>> アイテム修理しました。 トータル修理コスト: <<2>> ゴールド。',
    ItemsNotRepairedMsg = '<<1>> アイテム分のゴールドが足りません。',
    -- end new since 6.2.0

	-- new since 6.5.0
	BindLoadProfile = 'Load profile ',
	BindLoadNextProfile = 'Load next profile',
	BindLoadPreviousProfile = 'Load previous profile',
	BindToggleProfile = 'Toggle last two profiles',
	MsgNoPreviousProfile = 'No profile to toggle.',
	-- end new since 6.5.0
	
    SetConnector = {
        lmb..' セットで装備に接続\n'..rmb..' 接続を削除',
        lmb..' セットでアクションバー1に接続\n'..rmb..' 接続を削除',
        lmb..' セットでアクションバー2に接続\n'..rmb..' 接続を削除'
    },
    Head = {
        Gear = '装備 ',
        Skill = 'スキル '
    },
    Button = {
        Gear = lmb..' アイテムを装備\n'..rmb..' アイテムを削除',
        Skill = lmb..' スキルを装備\n'..rmb..' スキルを削除'
    },
    Selector = {
        Gear = lmb..' 全体を装備\n'..rmb..' 追加オプション',
        Skill = lmb..' 全てのスキルを装備\n'..rmb..' 追加オプション'
    },
    OptionWidth = 300,
    Options = {
        'UIボタンを表示',
        'UIセットボタンを表示',
        '修理アイコンを表示',
        '修理コストを表示',
        '武器のチャージアイコンを表示',
        '武器の入れ替えメッセージを表示',
        '装備セットを表示',
        '所持品のセットアイテムをマーク',
        'アイテムの状態をパーセントで表示',
        'アイテムの品質を色で表示',
        '移動のウィンドウを閉じる',
        '全てのAlphaGearの要素をロック',
        '自動で武器をチャージ',
    -- new since 6.1.1
        '自動で防具を修理(店舗アクセス時)',
    -- end new 6.1.1
    -- new since 6.1.3
        'アイテムのレベルをマークで表示',
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
