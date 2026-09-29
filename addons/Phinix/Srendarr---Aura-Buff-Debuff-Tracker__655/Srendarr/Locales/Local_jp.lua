--- @class Srendarr
local Srendarr = _G['Srendarr'] -- grab addon table from global
local L = {}

------------------------------------------------------------------------------------------------------------------
-- Japanese (jp) - Thanks to ESOUI.com user k0ta0uchi for the translations.
-- Indented or commented lines still require human translation and may not make sense!
------------------------------------------------------------------------------------------------------------------

L.Srendarr = "|c67b1e9S|c4779ce'rendarr|r"
L.Srendarr_Basic = "S'rendarr"
L.Usage = "|c67b1e9S|c4779ce'rendarr|r - 使用方法: /srendarr 表示されているウィンドウの移動のロック|アンロックを切り替えます。"
L.CastBar = 'キャストバー'
L.Sound_DefaultProc = 'Srendarr（デフォルトのproc）'
L.ToggleVisibility = 'Srendarrの可視性を切り替えます'
L.UpdateGearSets = '装備されたギアセットを更新します'

-- time format						
L.Time_Tenths = '%.1fs'
L.Time_TenthsNS = '%.1f'
L.Time_Seconds = '%ds'
L.Time_SecondsNS = '%d'
L.Time_Minutes = '%dm'
L.Time_Hours = '%dh'
L.Time_Days = '%dd'

-- aura grouping
L.Group_Displayed_Here = '表示されたグループ'
L.Group_Displayed_None = '無し'
L.Group_Player_Short = 'ショートバフ'
L.Group_Player_Long = 'ロングバフ'
L.Group_Player_Major = 'メジャーバフ'
L.Group_Player_Minor = 'マイナーバフ'
L.Group_Player_Toggled = 'トグルバフ'
L.Group_Player_Ground = 'グランドターゲット'
L.Group_Player_Enchant = 'エンチャント & ギア Procs'
L.Group_Player_Cooldowns = 'あなたのProc Coooldowns'
L.Group_Player_CABar = 'クールダウンアクションバー'
L.Group_Player_Passive = 'パッシブ'
L.Group_Player_Debuff = 'デバフ'
L.Group_Target_Buff = 'ターゲットバフ'
L.Group_Target_Debuff = 'ターゲットデバフ'
L.Group_ProminentType = '顕著なタイプ'
L.Group_ProminentTypeTip = '監視するオーラのタイプを選択します（バフ、デバフ）。'
L.Group_ProminentTarget = '著名なターゲット'
L.Group_ProminentTargetTip = 'Auraのターゲットを選択して（プレーヤー、ターゲット、グループAOE）を選択します。'
L.Group_GroupBuffs = 'グループバフフレーム'
L.Group_RaidBuffs = '襲撃バフフレーム'
L.Group_GroupDebuffs = 'グループデバフフレーム'
L.Group_RaidDebuffs = 'Raid Debuffフレーム'
L.Group_Cooldowns = 'クールダウントラッカー'
L.Group_CooldownBar = 'アクティブなクールダウンバー'
L.Group_Cooldown = 'クールダウン'

-- whitelist & blacklist control
L.Prominent_RemoveByRecent = 'は、誤った分類のために著名なものから削除され、タイプでなければなりません'
L.Prominent_AuraAddSuccess = 'はフレームに追加されました'
L.Prominent_AuraAddAs = 'として'
L.Prominent_AuraAddFail = 'は、見つからないため追加されませんでした。'
L.Prominent_AuraAddFailByID = 'は、有効なabilityIDではないか、時限的なオーラのIDではないため追加されませんでした。'
L.Prominent_AuraAddFailByName = 'パラメーターの欠落または誤ったパラメーター。'
L.Prominent_AuraRemoveFail = '顕著なオーラを削除するには、最初にAura Pop-Outメニューの変更から名前をクリックする必要があります。 オーラをクリックした後、または除去が失敗した後、値を変更しないでください。'
L.Prominent_AuraRemoveSuccess = 'は著名なリストから削除されました。'
L.Blacklist_AuraAddSuccess = 'は、ブラックリストに追加され、表示されることはありません。'
L.Blacklist_AuraAddFail = 'は、見つからなかったためブラックリストには追加されませんでした。'
L.Blacklist_AuraAddFailByID = 'は、有効なabilityIDではなく、ブラックリストに追加されませんでした。'
L.Blacklist_AuraRemoved = 'は、ブラックリストから外されました。'
L.Group_AuraAddSuccess = 'がグループバフホワイトリストに追加されました。'
L.Group_AuraAddSuccess2 = 'はグループデバフホワイトリストに追加されました。'
L.Group_AuraRemoved = 'はグループバフホワイトリストから削除されました。'
L.Group_AuraRemoved2 = 'は、グループデバフホワイトリストから削除されました。'

-- settings: base
L.Show_Example_Auras = 'オーラ例'
L.Show_Example_Castbar = 'キャストバー例'

L.SampleAura_PlayerTimed = '時限プレイヤー'
L.SampleAura_PlayerToggled = 'トグルプレイヤー'
L.SampleAura_PlayerPassive = 'パッシブプレイヤー'
L.SampleAura_PlayerDebuff = 'デバフプレイヤー'
L.SampleAura_PlayerGround = '地上エフェクト'
L.SampleAura_PlayerMajor = 'メジャーエフェクト'
L.SampleAura_PlayerMinor = 'マイナーエフェクト'
L.SampleAura_TargetBuff = 'ターゲットバフ'
L.SampleAura_TargetDebuff = 'ターゲットデバフ'

L.TabButton1 = '一般'
L.TabButton2 = 'フィルター'
L.TabButton3 = 'キャストバー'
L.TabButton4 = 'オーラ表示'
L.TabButton5 = 'プロファイル'

L.TabHeader1 = '一般設定'
L.TabHeader2 = 'フィルター設定'
L.TabHeader3 = 'キャストバー設定'
L.TabHeader5 = 'プロファイル設定'
L.TabHeaderDisplay = 'ウィンドウ表示設定'

-- settings: generic
L.GenericSetting_ClickToViewAuras = '|cffd100オーラを見るにはクリック|r'
L.GenericSetting_NameFont = '名前テキストフォント'
L.GenericSetting_NameStyle = '名前テキストフォントカラー & スタイル'
L.GenericSetting_NameSize = '名前テキストサイズ'
L.GenericSetting_TimerFont = 'タイマーテキストフォント'
L.GenericSetting_TimerStyle = 'タイマーテキストフォントカラー & スタイル'
L.GenericSetting_TimerSize = 'タイマーテキストサイズ'
L.GenericSetting_BarWidth = 'バー幅'
L.GenericSetting_BarWidthTip = 'キャストタイマーバー表示の幅を設定します。\n\nポジションによっては、幅を変更した後調整する必要がある場合があります。'


-- ----------------------------
-- SETTINGS: DROPDOWN ENTRIES
-- ----------------------------
L.DropGroup_1 = '表示ウィンドウ [|cffd1001|r]'
L.DropGroup_2 = '表示ウィンドウ [|cffd1002|r]'
L.DropGroup_3 = '表示ウィンドウ [|cffd1003|r]'
L.DropGroup_4 = '表示ウィンドウ [|cffd1004|r]'
L.DropGroup_5 = '表示ウィンドウ [|cffd1005|r]'
L.DropGroup_6 = '表示ウィンドウ [|cffd1006|r]'
L.DropGroup_7 = '表示ウィンドウ [|cffd1007|r]'
L.DropGroup_8 = '表示ウィンドウ [|cffd1008|r]'
L.DropGroup_9 = '表示ウィンドウ [|cffd1009|r]'
L.DropGroup_10 = '表示ウィンドウ [|cffd10010|r]'
L.DropGroup_11 = '表示ウィンドウ [|cffd10011|r]'
L.DropGroup_12 = '表示ウィンドウ [|cffd10012|r]'
L.DropGroup_13 = '表示ウィンドウ [|cffd10013|r]'
L.DropGroup_14 = '表示ウィンドウ [|cffd10014|r]'
L.DropGroup_None = '表示しない'

L.DropStyle_Full = 'フル表示'
L.DropStyle_Icon = 'アイコンのみ'
L.DropStyle_Mini = '最小表示'

L.DropGrowth_Up = '上'
L.DropGrowth_Down = '下'
L.DropGrowth_Left = '左'
L.DropGrowth_Right = '右'
L.DropGrowth_CenterLeft = '中央揃え (左)'
L.DropGrowth_CenterRight = '中央揃え (右)'
L.DropGrowth_CenterUp = '中央揃え （上）'
L.DropGrowth_CenterDown = '中央揃え （下）'

L.DropSort_NameAsc = 'アビリティ名 (上昇）'
L.DropSort_TimeAsc = '残り時間 (上昇）'
L.DropSort_CastAsc = 'キャスティングオーダー (上昇）'
L.DropSort_NameDesc = 'アビリティ名 (下降)'
L.DropSort_TimeDesc = '残り時間 (下降)'
L.DropSort_CastDesc = 'キャスティングオーダー (下降)'

L.DropTimer_Above = '上アイコン'
L.DropTimer_Below = '下アイコン'
L.DropTimer_Over = 'オーバーアイコン'
L.DropTimer_Hidden = '隠す'

L.DropAuraClassBuff = 'バフ'
L.DropAuraClassDebuff = 'デバフ'
L.DropAuraTargetPlayer = 'プレーヤー'
L.DropAuraTargetTarget = '目標'
L.DropAuraTargetAOE = 'AOE'
L.DropAuraClassDefault = 'オーバーライドなし'

L.DropGroupMode1 = 'デフォルト'
-- L.DropGroupMode2							= "Foundry Tactical Combat"
-- L.DropGroupMode3							= "Lui Extended"
-- L.DropGroupMode4							= "Bandits User Interface"
-- L.DropGroupMode5							= "AUI"


-- ------------------------
-- SETTINGS: GENERAL
-- ------------------------
-- general (general options)
L.General_GeneralOptions = '一般的なオプション'
L.General_GeneralOptionsDesc = 'アドオンの動作を制御するさまざまな一般的なオプション。'
L.General_UnlockDesc = 'ロックを解除すると、オーラ表示ウィンドウをマウスでドラッグできるようになります。 リセットは、最後のリロード以降のすべての位置変更を元に戻し、デフォルトはすべてのウィンドウをデフォルトの場所に戻します。'
L.General_UnlockLock = 'ロック'
L.General_UnlockUnlock = 'アンロック'
L.General_UnlockReset = 'リセット'
L.General_UnlockDefaults = 'デフォルト'
L.General_UnlockDefaultsAgain = 'デフォルトを確認'
L.General_PassivesAlways = '常にパッシブを表示します'
L.General_PassivesAlwaysTip = '戦闘中にはない場合でも、パッシブ/長い期間を表示します。'
L.HideOnDeadTargets = '死んだターゲットに隠れます'
L.HideOnDeadTargetsTip = '死んだターゲットにすべてのオーラを隠すかどうかを設定します。 （悔い改めのような潜在的に有用なものを隠すことができます。デバフを使用します。）'
L.PVPJoinTimer = 'PVP結合タイマー'
L.PVPJoinTimerTip = 'ゲームはPVPを初期化しながらアドオン登録イベントをブロックします。 これはSrendarrがこれが完了するのを待つ秒数です。これは、CPUやサーバーの遅れに依存する可能性があります。 PVPを結合または去るときにオーラが消える場合は、この値を高く設定してください。'
L.ShowTenths = '10秒'
L.ShowTenthsTip = '残りの数秒でタイマーの隣に10分の1を表示します。 スライダーは、10分の1以下の残り秒が表示され始めます。 この値を0に設定すると、10分の1の表示が無効になります。'
L.ShowSSeconds = 'ショー「S」秒'
L.ShowSSecondsTip = '残りの数秒でタイマーの後に文字「s」を表示します。 数分と秒を示すタイマーは、これによって影響されません。'
L.ShowSeconds = '残りの秒を表示します'
L.ShowSecondsTip = '数分を示すタイマーの隣に残っている秒を表示します。 時間を示すタイマーは、これによって影響されません。'
L.General_ConsolidateEnabled = 'マルチアウラを統合します'
L.General_ConsolidateEnabledTip = 'テンプル騎士団の復元オーラのような特定の能力には複数のバフ効果があり、これらは通常、同じアイコンで選択したオーラウィンドウに表示され、クラッターにつながります。 このオプションは、これらを単一のオーラに統合します。 W.I.P.'
L.General_AlternateEnchantIcons = '代替エンチャントアイコン'
L.General_AlternateEnchantIconsTip = '有効：エンチャント効果のためにアイコンのカスタムセットを使用します。 無効：デフォルトのゲームエンチャントアイコンを使用します。'
L.General_PassiveEffectsAsPassive = 'パッシブメジャー&マイナーバフをパッシブとして扱う'
L.General_PassiveEffectsAsPassiveTip = 'パッシブなメジャー&マイナーバフは他のパッシブオーラ（あなたのパッシブ設定による）と一緒にグループ化され隠されます。\n\n有効化されている場合、全てのメジャー&マイナーバフは時限かかパッシブでない限りグループ化統合されます。'
L.General_AuraFadeout = 'オーラフェードアウトタイム'
L.General_AuraFadeoutTip = '完了したオーラがどれくらい時間をかけてフェードアウトするかを設定します。0に設定した場合、完了したオーラはフェードアウトしないですぐに消えます。'
L.General_ShortThreshold = 'ショートバフ閾値'
L.General_ShortThresholdTip = "'ロングバフ'グループとして扱うプレイヤーバフの最小持続時間を設定します。（秒単位）この閾値以下のバフは'ショートバフ'グループとして扱われます。"
L.General_ProcEnableAnims = 'Bar Procアニメーションを有効にします'
L.General_ProcEnableAnimsTip = "Procされ、発動できる特殊アクションを持つアビリティでアクションバーにアニメーションを表示するか設定します。以下のProcを持つアビリティを含む:\n   Crystal Fragments\n   Grim Focus & It's Morphs\n   Flame Lash\n   Deadly Cloak"
L.General_GrimProcAnims = 'Grim Focus Procアニメーション'
L.General_GrimProcAnimsTip = 'Nightblade Grim Dawnまたはそのモーフがスペックボウをキャストするのに十分なスタックを持っているときに、オーラ自体にアニメーションを表示するかどうかを設定します。'
L.General_GearProcAnims = 'クールダウンアクションバーアニメーション'
L.General_GearProcAnimsTip = 'ギアの能力がクールダウンから外れており、準備ができているときに、クールダウンアクションバーにアニメーションを表示するかどうかを設定します。 （オーラコントロールのフレームにクールダウンアクションバーを割り当てる必要があります - グループを表示します。）'
L.General_gearProcCDText = 'クールダウンアクションバーの期間'
L.General_gearProcCDTextTip = '使用する準備ができているギア能力のセットProc名の隣のクールダウンアクションバーにクールダウン期間を表示します。'
L.General_ProcEnableAnimsWarn = 'デフォルトのアクションバーを修正するか隠すかするmodを使用している場合アニメーションが表示されない場合があります。'
L.General_ProcPlaySound = 'Proc発動時サウンドを再生する'
L.General_ProcPlaySoundTip = 'アビリティのProc発動時サウンドを再生するかを設定します。「無し」に設定した場合Proc発動音声アラートが再生されません。'
L.General_ModifyVolume = '変更PROCボリューム'
L.General_ModifyVolumeTip = '以下のProc Volumeスライダの使用を有効にします。'
L.General_ProcVolume = 'PROCサウンド音量'
L.General_ProcVolumeTip = 'SrendArr Proc Soundを再生するときは、オーディオエフェクトボリュームを一時的に上書きします。'
L.General_GroupAuraMode = 'グループオーラモード'
L.General_GroupAuraModeTip = '現在使用しているグループユニットフレームのサポートモジュールを選択します。'
L.General_RaidAuraMode = 'RAIDオーラモード'
L.General_RaidAuraModeTip = '現在使用しているRAIDユニットフレームのサポートモジュールを選択します。'

-- general (display groups)
L.General_ControlHeader = 'オーラコントロール - ディスプレイグループ'
L.General_ControlBaseTip = 'このオーラグループをどのディスプレイウィンドウに表示するか、全体的に隠すかを設定します。'
L.General_ControlShortTip = "このオーラグループは、全ての自身にかかっている独自な持続時間が'ショートバフ閾値'以下のバフを含みます。"
L.General_ControlLongTip = "このオーラグループは、全ての自身にかかっている独自な持続時間が'ショートバフ閾値'より長いバフを含みます。"
L.General_ControlMajorTip = 'このオーラグループは、全ての自身にかかっている有効な便利なメジャーエフェクトが含まれ、（例：Major Brutality）有害なメジャーエフェクトはデバフグループの一部となります。'
L.General_ControlMinorTip = 'このオーラグループは、全ての自身にかかっている有効な便利なマイナーエフェクトが含まれ、（例：Minor Brutality）有害なマイナーエフェクトはデバフグループの一部となります。'
L.General_ControlToggledTip = 'このオーラグループは、全ての自身にかかっているアクティブなトグルバフを含みます。'
L.General_ControlGroundTip = 'このオーラグループは、全ての自身でかけた地上エリアのエフェクトを含みます。'
L.General_ControlEnchantTip = 'このオーラグループは全ての自身にかかっている有効なエンチャントとギアProcエフェクトが含まれます。(例：Hardening, Berserker）'
L.General_ControlGearTip = 'このオーラグループには、自分でアクティブな通常は目に見えないすべてのギアプロセスが含まれています（例：Bloodspawn）。'
L.General_ControlCooldownTip = 'このオーラグループは、ギアプロセスの内部再利用クールダウンを追跡します。'
L.Group_Player_CABarTip = '装備されたクールダウンを追跡し、準備ができたときに通知されます。'
L.General_ControlPassiveTip = 'このオーラグループは、フィルタリングされていない全ての自身にかかっているアクティブなパッシブエフェクトを含みます。'
L.General_ControlDebuffTip = 'このオーラグループは全ての他のモブ、プレイヤー、環境にかけられた自身にかかっているアクティブな敵対デバフを含みます。'
L.General_ControlTargetBuffTip = 'このオーラグループは、フィルターされていない全てのターゲットにかかっている時限的、パッシブもしくはトグルのバフが含まれます。'
L.General_ControlTargetDebuffTip = 'このオーラグループは、全てのターゲットにかかっているデバフが含まれます。ゲーム上の制限により、レアな例外以外、自分のデバフのみが表示されます。'
L.General_ControlProminentFrame = '著名なフレーム'
L.General_ControlProminentFrameTip = 'この顕著なオーラを表示するフレームを選択します。 これにより、構成されたオーラに適用される通常のフィルターカテゴリがオーバーライドされます。'

-- general (debug)
L.General_DebugOptions = 'デバッグオプション'
L.General_DebugOptionsDesc = '表示されない、誤ったオーラをトラッキングするのを助けてください！'
L.General_DisplayAbilityID = 'オーラAbilityIDの表示を有効にする'
L.General_DisplayAbilityIDTip = '全ての内部的なオーラabilityIDを表示するかを設定します。これはブラックリストに追加する際や重要表示グループに追加する際に正確なオーラIDを探すのに使います。\n\nこのオプションは不正確なオーラ表示を直すため、誤ったIDをaddon作者に報告する助けになります。'
L.General_ShowCombatEvents = '戦闘イベントを表示'
L.General_ShowCombatEventsTip = '有効にすると、プレーヤーによって発生して受信されたすべてのエフェクト（BUFFSとDEBUFFS）の能力がチャットに表示され、その後にソースとターゲットに関する情報、およびイベント結果コード（Gained、Lostなど）が続きます。\n\nTOから チャットフラッディングとレビューを容易にするために、各機能はリロードされるまで一度だけ表示されます。 ただし、キャッシュを手動でリセットするにはいつでも/sdbclearを入力することができます。」\n\n警告：このオプションを有効にすると、大規模なグループのゲームパフォーマンスが低下します。 テストに必要な場合にのみ有効にしてください。'
L.General_ShowCombatEventsH1 = '警告:'
L.General_ShowCombatEventsH2 = '去る '
L.General_ShowCombatEventsH3 = ' は常に、大規模なグループでゲームのパフォーマンスを低下させます。 テストに必要な場合にのみ有効になります。'
L.General_AllowManualDebug = '手動のデバッグ編集を許可します'
L.General_AllowManualDebugTip = '有効になった場合、入力できます /sdbadd XXXXXX または /sdbremove XXXXXX フラッドフィルターから単一のIDを追加/削除するには。 さらに、タイピング /sdbignore XXXXXX は、常に洪水フィルターを過ぎて入力IDを許可します。 タイピング /sdbclear は引き続きフィルターを完全にリセットします。'
L.General_DisableSpamControl = '洪水制御を無効にします'
L.General_DisableSpamControlTip = '有効になった場合、戦闘イベントフィルターは、データベースをクリアするために /sdbclearまたはリロードすることなく発生するたびに同じイベントを印刷します。'
L.General_VerboseDebug = '詳細なデバッグを表示します'
L.General_VerboseDebugTip = 'event_combat_eventから受信したデータブロック全体と、上記のフィルターを（ほとんど）人間の読み取り可能な形式で渡すすべてのIDの能力アイコンパスを表示します（これにより、チャットログがすばやく記入されます）。'
L.General_OnlyPlayerDebug = 'プレイヤーイベントだけです'
L.General_OnlyPlayerDebugTip = 'プレイヤーのアクションの結果であるデバッグコンバットイベントのみを表示します。'
L.General_ShowNoNames = '無名のイベントを表示します'
L.General_ShowNoNamesTip = '有効になった場合、戦闘イベントフィルターには、名前のテキストがない場合でもイベントIDが表示されます（通常は必要ありません）。'
L.General_ShowSetIds = '装備時にセットIDを表示'
L.General_ShowSetIdsTip = '有効にすると、ピースを変更するときに装備されているすべてのセットギアの名前とsetIDが表示されます。'


-- ------------------------
-- SETTINGS: FILTERS
-- ------------------------
L.FilterHeader = 'フィルターリストとトグル'
L.Filter_Desc = 'ここでは、ブラックリストオーラ、ホワイトリストバフ、またはデバフを顕著に表示してカスタムウィンドウに割り当てるか、さまざまな種類の効果を表示または隠すためにフィルターを切り替えることができます。'
L.Filter_RemoveSelected = '選択した削除します'
L.Filter_ListAddWarn = 'オーラを名前で追加する場合、全てのオーラをスキャンし、アビリティの内部的なIDを取得する必要があります。これは検索中ゲームをハングアップする可能性があります。'
L.FilterToggle_Desc = '特定のオーラをブラックリスト（名前による）か、特定のオーラカテゴリーのフィルターを通してコントロールします。フィルターは一つ有効にするとそのカテゴリーを表示しません。'

L.Filter_PlayerHeader = 'プレイヤー用オーラフィルター'
L.Filter_TargetHeader = 'ターゲット用オーラフィルター'
L.Filter_OnlyPlayerDebuffs = 'プレーヤーのデバフだけがデバフします'
L.Filter_OnlyPlayerDebuffsTip = 'プレーヤーによって作成されなかったターゲットにデバフオーラの表示を防ぎます。'
L.Filter_OnlyTargetMajor = '主要なターゲットデバフのみ'
L.Filter_OnlyTargetMajorTip = 'ターゲットに大きな影響を与えるデバフのみを表示します。 他のすべてのターゲットデバフは表示されません。'

-- filters (blacklist auras)
L.Filter_BlacklistHeader = 'オーラブラックリスト'
L.Filter_BlacklistDesc = 'ここで特定のオーラをブラックリストに登録して、オーラトラッキングウィンドウに表示されないようにします。'
L.Filter_BlacklistAdd = 'オーラをブラックリストに追加する'
L.Filter_BlacklistAddTip = 'ブラックリストに追加したいオーラはゲーム内に表示されている名前を正確に入力するか、内部的なAbilityID（わかれば）を入力することにより、特定のオーラをブロックすることができます。\n\nエンターキーを押すことにより、ブラックリストに追加することができます。'
L.Filter_BlacklistList = '現在ブラックリストに登録されているオーラ'
L.Filter_BlacklistListTip = 'ブラックリストに設定されている全てのオーラのリストです。設定されているオーラを外したい場合はリストから選択し、「ブラックリストから外す」ボタンを押してください。'

-- filters (prominent auras)
L.Filter_ProminentHead = '著名なオーラ割り当て'
L.Filter_ProminentHeadTip = 'オーラは、特定のターゲット（プレーヤー、ターゲット、グループなど）で特定のタイプ（バフ、デバフなど）の特定のフレームに表示されるように割り当てることができます。'
L.Filter_ProminentOnlyPlayer = 'プレイヤーキャストのみ'
L.Filter_ProminentOnlyPlayerTip = 'プレイヤーがキャストした場合にのみ、選択したオーラを監視してください。'
L.Filter_ProminentAddRecent = '最近見たオーラを追加してください：'
L.Filter_ProminentAddRecentTip = 'クリックして、さまざまなカテゴリで最近検出されたオーラを表示します。 表示されたオーラをクリックすると、顕著な構成パネルがこのデータに入力されるため、カスタムディスプレイフレームに簡単に追加できます。'
L.Filter_ProminentResetRecent = '最近リセット'
L.Filter_ProminentResetRecentTip = '最近検出されたオーラのリストデータベースをクリアします。'
L.Filter_ProminentModify = '既存の著名なオーラを変更します：'
L.Filter_ProminentModifyTip = 'クリックして、各カテゴリで定義されている顕著なオーラのリストを表示します。 表示されたオーラをクリックすると、顕著な構成パネルがこのデータに入力されるため、変更または削除できます。'
L.Filter_ProminentTypePB = 'プレーヤーバフ'
L.Filter_ProminentTypePD = 'プレーヤーのデバフ'
L.Filter_ProminentTypeTB = 'ターゲットバフ'
L.Filter_ProminentTypeTD = 'ターゲットデバフ'
L.Filter_ProminentTypeAOE = '面積効果'
L.Filter_ProminentResetAll = 'クリアメニュー'
L.Filter_ProminentResetAllTip = '著名なオーラパネルのすべてのメニューフィールドをクリアしてリセットします。'
L.Filter_ProminentTypeGB = 'グループバフ'
L.Filter_ProminentTypeGD = 'グループデバフ'
L.Filter_ProminentAdd = '追加/更新します'
L.Filter_ProminentRemove = '取り外します'
L.Filter_ProminentEdit = '選択されたオーラ：'
L.Filter_ProminentEditTip1 = '最近見られたリストからオーラを選択して追加するか、既存のリストから1つを選択して変更します。'
L.Filter_ProminentEditTip2 = 'オーラを追加するときは、ゲーム内のすべてのオーラをスキャンして、機能の内部ID番号を見つける必要があります。 これにより、検索中にゲームがしばらくハングアップする可能性があります。'
L.Filter_ProminentShowIDs = 'オーラIDを表示します'
L.Filter_ProminentExpert = '専門家'
L.Filter_ProminentExpertTip = '名前またはIDでオーラの手動入力を許可し、すべての機能を削除できるようにします。\n\n|cffffff警告：|r この方法で、Srendarr（そのカテゴリがフレームに割り当てられている場合）に既に表示されているAurasを追加しないでください。 そうすることで、パフォーマンスがかかり、物事を破ることができます。 代わりに最近見られたメニューを使用して、これらをカスタムフレームに追加します。 Srendarrがゲームが異なるパラメーターで送信されるのを見たときに、間違ったタイプとして入力されるオーラは自動的に削除されます。\n\n|cffffff実験的：|r ゲームとSrendarrが追跡しないというAura IDをここに入力できますが、ゲームがゼロの期間と間違った情報を送信するため、それらが時々間違った情報を送信するため、それらが機能する保証はありません。 スレンダーサポートを追加して、物事を手動で強制しようとすることをお勧めします。'
L.Filter_ProminentRemoveAll = 'すべて削除する'
L.Filter_ProminentRemoveAllTip = '現在のアクティブプロファイルのために、すべての顕著なオーラを削除します。 警告：アカウント全体の設定を使用している場合、これにより、アカウント全体からすべての顕著なオーラが削除されます。'
L.Filter_ProminentRemoveConfirm = '現在のアクティブプロファイルのために、すべての顕著なオーラを削除しますか？'
L.Filter_ProminentWaitForSearch = '進行中の検索、お待ちください。'

-- filters (group frame buffs)
L.Filter_GroupBuffHeader = 'グループバフの割り当て'
L.Filter_GroupBuffDesc = 'このリストは、各プレーヤーのグループまたはRAIDフレームの隣にバフが表示されるかを決定します。'
L.Filter_GroupBuffAdd = 'ホワイトリストグループバフを追加します'
L.Filter_GroupBuffAddTip = 'グループフレームで追跡するためにバフオーラを追加するには、ゲームに表示されているように正確にその名前を入力する必要があります。 Enterを押して、入力オーラをリストに追加します。\n\n警告：通常、ゲームによって追跡されない限り、ここにオーラIDを入力しないでください（代わりにオーラ名を入力してください）。 ここにIDが入力したオーラは、Srendarrの偽のオーラシステムを使用し、入力されるほどパフォーマンスがかかります。'
L.Filter_GroupBuffList = '現在のグループバフホワイトリスト'
L.Filter_GroupBuffListTip = 'グループフレームに表示されるように設定されたすべてのバフのリスト。 既存のオーラを削除するには、リストからそれを選択し、下の削除ボタンを使用します。'
L.Filter_GroupBuffsByDuration = '期間ごとにバフを除外します'
L.Filter_GroupBuffsByDurationTip = '以下（秒単位）よりも短い期間があるグループバフのみを表示します。'
L.Filter_GroupBuffThreshold = 'バフの持続時間のしきい値'
L.Filter_GroupBuffWhitelistOff = 'バフブラックリストとして使用します'
L.Filter_GroupBuffWhitelistOffTip = 'グループバフホワイトリストをブラックリストに変え、ここでの入力を除いて、すべてのオーラを持続時間で表示します。'
L.Filter_GroupBuffOnlyPlayer = 'プレイヤーグループバフのみ'
L.Filter_GroupBuffOnlyPlayerTip = 'プレーヤーまたはペットの1人によってキャストされたグループバフのみを表示します。'
L.Filter_GroupBuffsEnabled = 'グループバフを有効にします'
L.Filter_GroupBuffsEnabledTip = '無効になった場合、グループバフはまったく表示されません。'

-- filters (group frame debuffs)
L.Filter_GroupDebuffHeader = 'グループデバフの割り当て'
L.Filter_GroupDebuffDesc = 'このリストは、各プレーヤーのグループまたはRAIDフレームの横に表示されるデバフが表示されるものを決定します。'
L.Filter_GroupDebuffAdd = 'ホワイトリストグループのデバフを追加します'
L.Filter_GroupDebuffAddTip = 'グループフレームで追跡するためにデバフオーラを追加するには、ゲームに表示されるように正確にその名前を入力する必要があります。 Enterを押して、入力オーラをリストに追加します。\n\n警告：通常、ゲームによって追跡されない限り、ここにオーラIDを入力しないでください（代わりにオーラ名を入力してください）。 ここにIDが入力したオーラは、Srendarrの偽のオーラシステムを使用し、入力されるほどパフォーマンスがかかります。'
L.Filter_GroupDebuffList = '現在のグループデバフホワイトリスト'
L.Filter_GroupDebuffListTip = 'グループフレームに表示されるように設定されたすべてのデバフのリスト。 既存のオーラを削除するには、リストからそれを選択し、下の削除ボタンを使用します。'
L.Filter_GroupDebuffsByDuration = '期間ごとにデバフを除外します'
L.Filter_GroupDebuffsByDurationTip = '以下（秒単位）よりも短い期間でグループデバフを表示するだけです。'
L.Filter_GroupDebuffThreshold = 'デバフ期間しきい値'
L.Filter_GroupDebuffWhitelistOff = 'デバフブラックリストとして使用します'
L.Filter_GroupDebuffWhitelistOffTip = 'グループのデバフホワイトリストをブラックリストに変え、ここでの入力を除いて、すべてのオーラを期間で表示します。'
L.Filter_GroupDebuffsEnabled = 'グループデバフを有効にします'
L.Filter_GroupDebuffsEnabledTip = '無効になった場合、グループデバフはまったく表示されません。'

-- filters (unit options)
L.Filter_ESOPlus = 'ESO Plusをフィルター'
L.Filter_ESOPlusPlayerTip = '自分のESOプラスステータスの表示を防ぐかどうかを設定します。'
L.Filter_ESOPlusTargetTip = 'ターゲットにESO Plusステータスの表示を防ぐかどうかを設定します。'
L.Filter_BlockPlayerTip = "ブロックしている状態で'Brace'トグルを表示するかを設定します。"
L.Filter_BlockTargetTip = "ブロックされている状態で'Brace'トグルを表示するかを設定します。"
L.Filter_MundusBoon = 'ムンダスブーンフィルター'
L.Filter_MundusBoonPlayerTip = '自身にかかっているムンダスストーンによる恩恵を表示するかを設定します。'
L.Filter_MundusBoonTargetTip = 'ターゲットにかかっているムンダスストーンによる恩恵を表示するかを設定します。'
L.Filter_Cyrodiil = 'シロディールボーナスフィルター'
L.Filter_CyrodiilPlayerTip = 'シロディールAvA時、自身にかかっているバフを表示するかを設定します。'
L.Filter_CyrodiilTargetTip = 'シロディールAvA時、ターゲットにかかっているバフを表示するかを設定します。'
L.Filter_Disguise = 'ディスガイズフィルター'
L.Filter_DisguisePlayerTip = '自身にかかっている有効なディスガイズを表示するかを設定します。'
L.Filter_DisguiseTargeTtip = 'ターゲットにかかっている有効なディスガイズを表示するかを設定します。'
L.Filter_MajorEffects = 'メジャーエフェクトフィルター'
L.Filter_MajorEffectsTargetTip = 'ターゲットにかかっているメジャーエフェクトを表示するかを設定します。（例：Major Maim, Major Brutality）'
L.Filter_MinorEffects = 'マイナーエフェクトフィルター'
L.Filter_MinorEffectsTargetTip = 'ターゲットにかかっているマイナーエフェクトを表示するかを設定します。（例：Minor Maim, Minor Brutality）'
L.Filter_SoulSummons = 'ソウル召喚クールダウンフィルター'
L.Filter_SoulSummonsPlayerTip = "自身にかかっているクールダウン'オーラ'を表示するかを設定します。"
L.Filter_SoulSummonsTargetTip = "ターゲットにかかっているソウル召喚クールダウン'オーラ'を表示するかを設定します。"
L.Filter_VampLycan = 'ヴァンパイア&ウェアウルフエフェクトフィルター'
L.Filter_VampLycanPlayerTip = '自身にかかっているヴァンパイア化とウェアウルフ化バフを表示するかを設定します。'
L.Filter_VampLycanTargetTip = 'ターゲットにかかっているヴァンパイア化とウェアウルフ化バフを表示するかを設定します。'
L.Filter_VampLycanBite = 'ヴァンパイア & ウェアウルフ噛みつきタイマーフィルター'
L.Filter_VampLycanBitePlayerTip = '自身にかかっているヴァンパイア & ウェアウルフ噛みつきクールダウンタイマーを表示するかを設定します。'
L.Filter_VampLycanBiteTargetTip = 'ターゲットにかかっているヴァンパイア & ウェアウルフ噛みつきクールダウンタイマーを表示するかを設定します。'
L.Filter_GroupDurationThreshold = 'グループオーラは、この期間（秒単位）よりも長く表示されません。'


-- ------------------------
-- SETTINGS: CAST BAR
-- ------------------------
L.CastBar_Enable = 'キャストとチャネルバーを有効にする'
L.CastBar_EnableTip = 'キャストがあるもしくは有効前にチャネルタイムがあるアビリティに、進捗状況を表示する移動可能なキャスティングバーを表示するかを設定します。'
L.CastBar_AlphaTip = '戦闘中でないときのキャスト バーの不透明度を設定します。0 に設定すると、バーは完全に見えなくなります。'
L.CastBar_CAlphaTip = '戦闘中のキャスト バーの不透明度を設定します。0 に設定すると、バーは完全に見えなくなります。'
L.CastBar_Scale = 'スケール'
L.CastBar_ScaleTip = 'キャストバーのサイズをパーセンテージで設定します。100がデフォルトサイズです。'

-- cast bar (name)
L.CastBar_NameHeader = '発動アビリティ名テキスト'
L.CastBar_NameShow = 'アビリティ名テキストを表示'

-- cast bar (timer)
L.CastBar_TimerHeader = 'キャストタイマーテキスト'
L.CastBar_TimerShow = 'キャスタータイマーテキストを表示'

-- cast bar (bar)
L.CastBar_BarHeader = 'キャストタイマーバー'
L.CastBar_BarReverse = 'カウントダウン方向を逆にする'
L.CastBar_BarReverseTip = 'キャストバーがタイマーが減少すると右に移動するようカウントダウン方向を逆にするかを設定します。どちらのケースでもチャネルアビリティは反対方向に増加します。'
L.CastBar_BarGloss = 'グロスバー'
L.CastBar_BarGlossTip = 'キャストタイマーバー表示をグロス表示にするかを設定します。'
L.CastBar_BarColor = 'バーカラー'
L.CastBar_BarColorTip = 'キャストタイマーバーの色を設定します。左側はバーの最初を最初から（カウントダウンする場合）2番目のバーの終わりを意味します。（もうすぐ終わる場合）'


-- ------------------------
-- SETTINGS: DISPLAY FRAMES
-- ------------------------
L.DisplayFrame_Alpha = '非戦闘の透明性'
L.DisplayFrame_AlphaTip = '戦闘中でないときにこのオーラ ウィンドウがどの程度不透明になるかを設定します。 0 に設定すると、ウィンドウは完全に見えなくなります。'
L.DisplayFrame_CAlpha = '戦闘中の透明性'
L.DisplayFrame_CAlphaTip = '戦闘中にこのオーラ ウィンドウがどの程度不透明になるかを設定します。0 に設定すると、ウィンドウは完全に見えなくなります。'
L.DisplayFrame_Scale = 'ウィンドウスケール'
L.DisplayFrame_ScaleTip = 'このオーラウィンドウのサイズをパーセンテージで設定します。デフォルトサイズは100です。'

-- display frames (aura)
L.DisplayFrame_AuraHeader = 'オーラディスプレイ'
L.DisplayFrame_Style = 'オーラスタイル'
L.DisplayFrame_StyleTip = 'このオーラウィンドウのスタイルを設定します。\n\n|cffd100フル表示|r - アビリティ名とアイコン、タイマーバーとテキストを表示します。\n\n|cffd100アイコンのみ|r - アビリティアイコンとタイマーテキストのみ表示します。このスタイルは他のスタイルよりもオーラ拡張方向オプションをより多く提供します。\n\n|cffd100最小表示|r - アビリティ名と小さめのタイマーバーのみを表示します。'
L.DisplayFrame_AuraCooldown = 'タイマーアニメーションを表示します'
L.DisplayFrame_AuraCooldownTip = 'オーラアイコンの周りにタイマーアニメーションを表示します。 これにより、オーラは古いディスプレイモードよりも見やすくなります。 以下の色設定を使用してカスタマイズします。'
L.DisplayFrame_AuraBackground = 'アイコンの背景を使用する'
L.DisplayFrame_AuraBackgroundTip = 'オーラアイコン表示の後ろに黒い背景を表示します。 タイマー アニメーションを使用しない場合にのみ無効にできます。タイマー アニメーションが適切に表示されるかどうかはこの機能に依存します。'
L.DisplayFrame_AuraBorder = 'アイコンの枠線を使用する'
L.DisplayFrame_AuraBorderTip = 'Srendarr の黒いアイコンの背景を使用していない場合、アイコンの周囲にゲームのデフォルト スタイルの境界線を表示します。'
L.DisplayFrame_CooldownTimed = '色：タイミング付きバフとデバフ'
L.DisplayFrame_CooldownTimedB = '色：タイミングバフ'
L.DisplayFrame_CooldownTimedD = '色：タイミング付きデバフ'
L.DisplayFrame_CooldownTimedTip = '設定された期間でオーラのアイコンタイマーアニメーションの色を設定します。\n\n左 = バフ\n右 = デバフ.'
L.DisplayFrame_CooldownTimedBTip = '設定された期間のバフのアイコンタイマーアニメーションの色を設定します。'
L.DisplayFrame_CooldownTimedDTip = '設定された期間でデバフにアイコンタイマーアニメーションの色を設定します。'
L.DisplayFrame_Growth = 'オーラ拡張方向'
L.DisplayFrame_GrowthTip = '新しいオーラがアンカーポイントよりどちらの方向に拡張するかを設定します。中央の設定の場合、オーラはアンカーからの方向のいずれかを成長させ、並べ替えオプションと選択された方向（左、右、上、下）によって決定されます。\n\nオーラは|cffd100フル表示|rもしくは|cffd100最小表示|rの場合、上か下かにしか拡張しません。'
L.DisplayFrame_Padding = 'オーラ拡張パディング'
L.DisplayFrame_PaddingTip = 'それぞれの表示されたオーラの間のスペースを設定します。'
L.DisplayFrame_Sort = 'オーラソーティング順序'
L.DisplayFrame_SortTip = 'オーラがソーティングされる順序を設定します。名前アルファベット順、残り持続時間か、キャストした順に設定できます。 また、昇順か降順かも設定することができます。\n\n持続時間でソートする場合は、パッシブかトグルアビリティは名前と一番近いアンカー（昇順）、もしくは一番遠いアンカー（降順）でソートされ、時限アビリティはその前もしくは後ろに行きます。'
L.DisplayFrame_Highlight = 'トグルオーラアイコンハイライト'
L.DisplayFrame_HighlightTip = 'トグルオーラをハイライトしてパッシブオーラとの区別をするよう設定します。\n\n|cffd100最小表示|r では表示されずアイコンも表示されません。'
L.DisplayFrame_Tooltips = 'オーラ名のツールチップを表示'
L.DisplayFrame_TooltipsTip = '|cffd100アイコンのみ|r の場合オーラ名をマウスオーバーツールチップで表示するかを設定します。'
L.DisplayFrame_TooltipsWarn = 'ディスプレイウィンドウを移動する際はツールチップは一時的に無効にする必要があります。有効な場合、ツールチップが移動を妨害する場合があります。'
L.DisplayFrame_AuraClassOverride = 'オーラクラスオーバーライド'
L.DisplayFrame_AuraClassOverrideTip = '実際のクラスに関係なく、このバーでは、このバーのすべてのタイミングのあるオーラ（トグルとパッシブを無視した）をSrendarr扱うことができます。\n\nデバフとAOEの両方をウィンドウに追加して、同じバーとアイコンのアニメーションの色を使用するときに役立ちます。'

-- display frames (group)
L.DisplayFrame_GRX = '水平オフセット'
L.DisplayFrame_GRXTip = 'グループ/RAIDフレームバフアイコンの位置を左右に調整します。'
L.DisplayFrame_GRY = '垂直オフセット'
L.DisplayFrame_GRYTip = 'グループ/RAIDフレームバフのアイコンの位置を上下に調整します。'

-- display frames (name)
L.DisplayFrame_NameHeader = 'アビリティ名テキスト'

-- display frames (timer)
L.DisplayFrame_TimerHeader = 'タイマーテキスト'
L.DisplayFrame_TimerLocation = 'タイマーテキストポジション'
L.DisplayFrame_TimerLocationTip = 'オーラアイコンに対応した各オーラタイマーのポジションを設定します。「隠す」設定は全てのオーラでタイマーラベルを表示しないようにします。\n\n現在のスタイルによって特定の設置オプションのみ利用できます。'
L.DisplayFrame_TimerHMS = '1時間以上のタイマーの数分を表示します'
L.DisplayFrame_TimerHMSTip = 'タイマーが1時間を超える場合に残りの議事録を表示するかどうかを設定します。'

-- display frames (bar)
L.DisplayFrame_BarHeader = 'タイマーバー'
L.DisplayFrame_HideFullBar = 'タイマーバーを非表示にします'
L.DisplayFrame_HideFullBarTip = 'バーを完全に非表示にし、フルディスプレイモードの場合、アイコンの横にオーラ名のテキストのみを表示します。'
L.DisplayFrame_BarReverse = 'リバースカウントダウン方向'
L.DisplayFrame_BarReverseTip = 'タイマーバーのカウントダウン方向を逆にしタイマーが減少すると右に拡張するか設定します。|cffd100フル表示|r ではオーラアイコンをバーの右に表示することもできます。'
L.DisplayFrame_BarGloss = 'グロスバー'
L.DisplayFrame_BarGlossTip = 'タイマーバーをグロス表示するかどうかを設定します。'
L.DisplayFrame_BarBuffTimed = 'カラー: 時限オーラ'
L.DisplayFrame_BarBuffTimedTip = '持続時間がセットされたオーラタイマーバーカラーを設定します。左側はバーの最初を最初から（カウントダウンする場合）2番目のバーの終わりを意味します。（もうすぐ終わる場合）'
L.DisplayFrame_BarBuffPassive = 'カラー: パッシブオーラ'
L.DisplayFrame_BarBuffPassiveTip = '持続時間がセットされていないパッシブオーラタイマーバーカラーを設定します。左側はバーの最初を最初から（アイコンから一番遠い側）2番目のバーの終わりを意味します。（アイコンに近い側）.'
L.DisplayFrame_BarDebuffTimed = '色：タイミング付きデバフ'
L.DisplayFrame_BarDebuffTimedTip = '設定された期間でデバフオーラのタイマーバーの色を設定します。 左の色の選択により、バーの開始（カウントダウンを開始したとき）と2番目の色がバーの仕上げ（ほぼ有効期限が切れたとき）を決定します。'
L.DisplayFrame_BarDebuffPassive = '色：パッシブデバフ'
L.DisplayFrame_BarDebuffPassiveTip = '設定された期間なしでパッシブデバフオーラのタイマーバーの色を設定します。 左の色の選択により、バーのスタート（アイコンから最も遠い側）と2番目はバーの仕上げ（アイコンに最も近い）を決定します。'
L.DisplayFrame_BarToggled = 'カラー: トグルオーラ'
L.DisplayFrame_BarToggledTip = '持続時間がセットされていないトグルオーラタイマーバーカラーを設定します。左側はバーの最初を最初から（アイコンから一番遠い側）2番目のバーの終わりを意味します。（アイコンに近い側）'


-- ------------------------
-- SETTINGS: PROFILES
-- ------------------------
L.Profile_Desc = 'プロファイルを設定することができます。このアカウントの「全て」のキャラクターに同じ設定が適用されるアカウントプロファイルもここで有効することができます。これらのオプションはその永続性により、マネージャは最初にこのパネルの一番下にあるチェックボックスに有効にする必要があります。'
L.Profile_UseGlobal = 'アカウントプロファイルを使用する'
L.Profile_AccountWide = 'アカウント全体'
L.Profile_UseGlobalWarn = 'キャラ毎のプロファイルとアカウントプロファイルを切り替える場合、UIがリロードされます。'
L.Profile_Copy = 'コピーするプロファイルを選択'
L.Profile_CopyTip = '現在有効なプロファイルにコピーしたいプロファイルを選択します。有効なプロファイルはログインしているキャラクターのものか、設定が有効になっていればアカウントプロファイルになります。現在のプロファイルは永久に上書きされます。\n\nこの操作は元に戻すことはできません！'
L.Profile_CopyButton1 = 'プロファイル全体をコピーします'
L.Profile_CopyButton1Tip = '顕著なオーラ構成を含む選択したプロファイル全体をコピーします。 代替については以下のオプションを参照してください。'
L.Profile_CopyButton2 = 'ベースプロファイルをコピーします'
L.Profile_CopyButton2Tip = '顕著なオーラ構成を除く選択したプロファイルからすべてをコピーします。 クラス固有のオーラセットアップをコピーせずに、ベースディスプレイ構成を設定するのに役立ちます。'
L.Profile_CopyButtonWarn = 'プロファイルをコピーするとUIがリロードされます。'
L.Profile_CopyCannotCopy = '選択されたプロファイルをコピーできませんでした。もう一度試すかほかのプロファイルを選択してください。'
L.Profile_Delete = 'プロファイルを選択して削除'
L.Profile_DeleteTip = 'プロファイルを選択するとそのプロファイルの設定をデータベースから削除されます。もしそのキャラクターが後にログインし、アカウントプロファイルを使用していない場合は、新しくデフォルトの設定が生成されます。\n\nプロファイルは永久に削除されます！'
L.Profile_DeleteButton = 'プロファイルを削除'
L.Profile_Guard = 'プロファイルマネージャを有効にする'


-- ------------------------
-- Gear Cooldown Alt Names
-- ------------------------
L.YoungWasp = '若いハチ'
L.MolagKenaHit1 = ' 初ヒット'
L.VolatileAOE = '揮発性の使い魔能力'


if (GetCVar('language.2') == 'jp') then -- overwrite GetLocale for new language
    for k, v in pairs(Srendarr:GetLocale()) do
        if (not L[k]) then              -- no translation for this string, use default
            L[k] = v
        end
    end

    function Srendarr:GetLocale() -- set new locale return
        return L
    end
end