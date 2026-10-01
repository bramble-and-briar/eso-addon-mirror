local Icon = WPamA.Consts.IconsW
local GetIcon = WPamA.Textures.GetTexture
local OpenWindowText = GetString(SI_ENTER_CODE_CONFIRM_BUTTON)
local DynamicEncounterText = GetString(SI_HUD_EDITOR_DYNAMIC_EVENT_TRACKER)
WPamA.i18n = {
  Lng = "JP",
-- DateTime settings
  DateTimePart = {dd = 2, mm = 1, yy = 0, },
  DateFrmt = 4, -- 1 default:m.d.yyy ; 2:yyyy-mm-dd; 3:dd.mm.yyyy; 4:yyyy/mm/dd; 5:dd.mm.yy; 6:mm/dd; 7:dd.mm
  DateFrmtList = {"ESO標準","yyyy-mm-dd","dd.mm.yyyy","yyyy/mm/dd","dd.mm.yy","mm/dd","dd.mm"},
  DayMarker = "日",
  MetricPrefix = {"千","百万","十億","一兆","千兆","百京"},
  CharsOrderList = {"ESO Default","Names","Alliance, Names","Max level, Names","Min level, Names","Alliance, Max level","Alliance, Min level"},
-- Marker (substring) in active quest step text for detect DONE stage
  DoneM = {
    [1] = "へ戻る",
    [2] = "と話す",
    [3] = "に戻る",
  },
-- Keybinding string
  KeyBindShowStr  = "アドオンウィンドウの表示/非表示",
  KeyBindChgWStr  = "Open next window",
  KeyBindChgTStr  = "Open next window tab",
  KeyBindChgAStr  = "Open next addon tab",
  KeyFavRadMenu   = "Radial menu of favorite tabs",
  KeyBindCharStr  = "Show character Pledges",
  KeyBindClndStr  = "Show calendar of Pledges",
  KeyBindPostTd   = "今日の誓いを、英語でチャットに投稿する", -- Post today pledges to chat (EN)
  KeyBindPostTdCL = "今日の誓いを、日本語でチャットに投稿する", -- Post today pledges to chat (JP)
  KeyBindWindow0  = OpenWindowText .. ": " .. "グループダンジョン",
  KeyBindWindow1  = OpenWindowText .. ": " .. "試練(トライアル)",
  KeyBindWindow2  = OpenWindowText .. ": " .. GetString(SI_ZONECOMPLETIONTYPE9),
  KeyBindWindow3  = OpenWindowText .. ": " .. "スキル",
  KeyBindWindow4  = OpenWindowText .. ": " .. GetString(SI_BINDING_NAME_TOGGLE_INVENTORY),
  KeyBindWindow5  = OpenWindowText .. ": " .. GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKCATEGORIES1),
  KeyBindWindow6  = OpenWindowText .. ": " .. GetString(SI_MAPFILTER14),
  KeyBindWindow7  = OpenWindowText .. ": " .. GetString(SI_JOURNAL_MENU_ACHIEVEMENTS) ..
                    ", " .. GetString(SI_COLLECTIONS_MENU_ROOT_TITLE),
  KeyBindWindow8  = OpenWindowText .. ": " .. GetString(SI_QUEST_JOURNAL_GENERAL_CATEGORY),
  KeyBindRGLA     = "RGLA(レイドグループリーダーアシスタント）の表示/非表示)",
  KeyBindRGLASrt  = "RGLA: 開始",
  KeyBindRGLAStp  = "RGLA: 停止",
  KeyBindRGLAPst  = "RGLA: チャットに投稿",
  KeyBindRGLAShr  = "RGLA: クエストの共有",
  KeyBindLFGP     = "GFP: Start/stop search",
  KeyBindLFGPMode = "GFP: Mode selection",
-- Caption
  Wind = {
    [0] = {
      Capt = "グループダンジョン",
      Tab = {
        [1] = {N="アンドーンテッドの誓い", W=110},
        [2] = {N="誓いのカレンダー", W=95},
        [3] = {N="ランダムな活動", W=200}, -- "ランダムダンジョン"
        [4] = {N=GetString(SI_ENDLESS_DUNGEON_LEADERBOARDS_CATEGORIES_HEADER), W=181},
      },
    },
    [1] = {
      Capt = "試練(トライアル)",
      Tab = {
        [1] = {N="AA, HRC, SO, MOL, CR, SS", W=200},
        [2] = {N="HOF, AS, KA, RG, DSR, SE", W=192},
        [3] = {N="LC, OC", W=192},
      },
    },
    [2] = {
      Capt = GetString(SI_ZONECOMPLETIONTYPE9), -- "World Bosses"
      Tab = {
        [ 1] = {N=GetIcon(18,28), NC=GetIcon(18,28,true), W=28, S=true, A="ロスガー"},
        [ 2] = {N=GetIcon(25,28), NC=GetIcon(25,28,true), W=28, S=true, A="ヴァーデンフェル"},
        [ 3] = {N=GetIcon(22,28), NC=GetIcon(22,28,true), W=28, S=true, A="ゴールドコースト"},
        [ 4] = {N=GetIcon(26,26), NC=GetIcon(26,26,true), W=28, S=true, A="サマーセット"},
        [ 5] = {N=GetIcon(28,26), NC=GetIcon(28,26,true), W=28, S=true, A="北エルスウェア"},
        [ 6] = {N=GetIcon(30,28), NC=GetIcon(30,28,true), W=28, S=true, A="西スカイリム"},
        [ 7] = {N=GetIcon(34,28), NC=GetIcon(34,28,true), W=28, S=true, A=GetString(SI_CHAPTER5)}, -- "Blackwood"
        [ 8] = {N=GetIcon(40,28), NC=GetIcon(40,28,true), W=28, S=true, A=GetString(SI_CHAPTER6)}, -- "High Isle"
        [ 9] = {N=GetIcon(42,28), NC=GetIcon(42,28,true), W=28, S=true, A=GetString(SI_CHAPTER7)}, -- "Necrom"
        [10] = {N=GetIcon(43,28), NC=GetIcon(43,28,true), W=28, S=true, A=GetString(SI_CHAPTER8)}, -- "The Gold Road"
        [11] = {N=GetIcon(66,28), NC=GetIcon(66,28,true), W=28, S=true, A=GetString(SI_CHAPTER9)}, -- "Solstice"
      },
    },
    [3] = {
      Capt = "スキル",
      Tab = {
        [1] = {N="クラス＆AvA", W=90},
        [2] = {N="クラフト", W=60},
        [3] = {N="ギルド", W=50},
        [4] = {N="World", W=50},
        [5] = {N=GetIcon(27,28), NC=GetIcon(27,28,true), W=28, S=true, A=GetString(SI_STATS_RIDING_SKILL)},
        [6] = {N=GetIcon(22,28), NC=GetIcon(22,28,true), W=28, S=true, A="影の配達人"},
        [7] = {N=zo_strformat("<<1>><<2>><<3>>", GetIcon(57,22), GetIcon(58,22), GetIcon(59,22)),
               NC=zo_strformat("<<1>><<2>><<3>>", GetIcon(57,22,true), GetIcon(58,22,true), GetIcon(59,22,true)),
               W=70, S=true, A=GetString(SI_STAT_GAMEPAD_CHAMPION_POINTS_LABEL)},
      },
    },
    [4] = {
      Capt = GetString(SI_BINDING_NAME_TOGGLE_INVENTORY),
      Tab = {
        [1] = {N="通貨", W=50},
        [2] = {N="アイテム", W=70},
        [3] = {N=GetIcon(32,24), NC=GetIcon(32,24,true), W=28, S=true, A="Experience Scrolls"},
        [4] = {N=GetIcon(60,24), NC=GetIcon(60,24,true), W=28, S=true, A="Transmutation Geodes"},
        [5] = {N=GetIcon(31,28), NC=GetIcon(31,28,true), W=28, S=true,
               A=GetString(SI_GAMEPAD_PLAYER_INVENTORY_CAPACITY_FOOTER_LABEL)},
        [6] = {N=GetIcon(61,24), NC=GetIcon(61,24,true), W=28, S=true,
               A=zo_strformat("<<1>>,\n<<2>>,\n<<3>>", GetString(SI_SPECIALIZEDITEMTYPE100),
                              GetString(SI_SPECIALIZEDITEMTYPE101), GetString(SI_SPECIALIZEDITEMTYPE2750) )},
        [7] = {N=GetIcon(65,28), NC=GetIcon(65,28,true), W=28, S=true, A=GetString(SI_ITEMTYPEDISPLAYCATEGORY26)},
      },
    },
    [5] = {
      Capt = GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKCATEGORIES1),
      Tab = {
        [1] = {N=GetString(SI_CAMPAIGNRULESETTYPE1), W=80},
        [2] = {N=GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES5), W=120},
        [3] = {N=GetString(SI_DAILY_LOGIN_REWARDS_TILE_HEADER), W=120},
        [4] = {N="Rewards & Signs", W=180},
        [5] = {N="AP Bonus", W=71},
--        [6] = {N=GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES4), W=100,},
      },
    },
    [6] = {
      Capt = GetString(SI_MAPFILTER14),
      Tab = {
        [1] = {N=GetIcon(45, 24) .. "1", NC=GetIcon(45, 24, true) .. "1", W=70, S=true, A=GetString(SI_COMPANION_OVERVIEW_RAPPORT)},
        [2] = {N=GetIcon(45, 24) .. "2", NC=GetIcon(45, 24, true) .. "1", W=70, S=true, A=GetString(SI_COMPANION_OVERVIEW_RAPPORT)},
        [3] = {N=zo_strformat("<<1>><<2>><<3>>", GetIcon(24, 24), GetIcon(35, 24), GetIcon(39, 24)),
               NC=zo_strformat("<<1>><<2>><<3>>", GetIcon(24, 24, true), GetIcon(35, 24, true), GetIcon(39, 24, true)),
               W=70, S=true, A="Skills: class, guild, armor"},
        [4] = {N=zo_strformat("<<1>><<2>><<3>>", GetIcon(48, 24), GetIcon(51, 24), GetIcon(53, 24)),
               NC=zo_strformat("<<1>><<2>><<3>>", GetIcon(48, 24, true), GetIcon(51, 24, true), GetIcon(53, 24, true)),
               W=70, S=true, A="Skills: weapon"},
        [5] = {N=zo_strformat("<<1>><<2>><<3>>", GetIcon(38, 24), GetIcon(39, 24), GetIcon(37, 24)),
               NC=zo_strformat("<<1>><<2>><<3>>", GetIcon(38, 24, true), GetIcon(39, 24, true), GetIcon(37, 24, true)),
               W=70, S=true,
               A=zo_strformat("<<1>>: <<2>>", GetString(SI_ARMORY_EQUIPMENT_LABEL), GetString(SI_EQUIPSLOTVISUALCATEGORY2))},
        [6] = {N=zo_strformat("<<1>><<2>><<3>>", GetIcon(54, 24), GetIcon(48, 24), GetIcon(55, 24)),
               NC=zo_strformat("<<1>><<2>><<3>>", GetIcon(54, 24, true), GetIcon(48, 24, true), GetIcon(55, 24, true)),
               W=70, S=true,
               A=zo_strformat("<<1>>: <<2>>, <<3>>", GetString(SI_ARMORY_EQUIPMENT_LABEL),
                              GetString(SI_EQUIPSLOTVISUALCATEGORY1), GetString(SI_EQUIPSLOTVISUALCATEGORY3))},
        [7] = {N=zo_strformat("<<1>><<2>>", GetIcon(75, 28), GetIcon(24, 24)),
               NC=zo_strformat("<<1>><<2>>", GetIcon(75, 28, true), GetIcon(24, 24, true)),
               W=70, S=true,
               A=zo_strformat("<<1>>: <<2>>", GetString(SI_COMPANION_OVERVIEW_SKILLS), GetString(SI_SKILLS_ACTIVE_ABILITIES))},
      },
    },
    [7] = {
      Capt = GetString(SI_JOURNAL_MENU_ACHIEVEMENTS) .. ", " .. GetString(SI_COLLECTIONS_MENU_ROOT_TITLE),
      Tab = {
        [1] = {N="季節のお祭り", W=100},
        [2] = {N=GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES803), W=70},
        [3] = {N=GetString(SI_RECIPECRAFTINGSYSTEM6), W=100},
        [4] = {N=GetString(SI_QUESTTYPE19), W=100}, -- Favors
      },
    },
    [8] = {
      Capt = GetString(SI_QUEST_JOURNAL_GENERAL_CATEGORY), -- "Miscellaneous"
      Tab = {
        [1] = {N=GetString(SI_TIMED_ACTIVITIES_TITLES), W=102},
        [2] = {N="Writs", W=48},
        [3] = {N=GetIcon(12,28), NC=GetIcon(12,28,true), W=28, S=true, A=GetString(SI_ZONECOMPLETIONTYPE8)}, -- World Events
        [4] = {N=GetIcon(56,28), NC=GetIcon(56,28,true),
               W=28, S=true, A=GetString(SI_CUSTOMER_SERVICE_OVERVIEW)}, -- Overview
        [5] = {N=GetIcon(69,28), NC=GetIcon(69,28,true),
               W=28, S=true, A=GetString(SI_CHARGE_WEAPON_TITLE)}, -- Charge Weapon
      },
    },
  },
  ModeSettings = {
    [25] = {
      HdT = { [1] = "合計", [2] = "中古", [3] = "自由" }
    },
--------
    [42] = {
      HdT = {
        [1] = GetString(SI_COLLECTIBLERESTRICTIONTYPE1), -- Race
        [2] = GetString(SI_COLLECTIBLERESTRICTIONTYPE3), -- Class
        [3] = "SP", [4] = "Last login", [5] = "Played time"
      },
    },
--------
    [50] = {
      HdT = {
        [1] = GetString(SI_CAMPAIGN_OVERVIEW_CATEGORY_BONUSES), -- Bonuses
        [2] = GetString(SI_STAT_GAMEPAD_TIME_REMAINING):gsub(":", "") -- time remaining
      },
    },
--------
    [51] = {
      HdT = { [1] = GetMailListName(1), [2] = GetMailListName(2), [3] = GetMailListName(3) }
    },
--------
  }, -- ModeSettings
  SelModeWin = {x = 170, y = 2, dy = 24},
-- Labels
  TotalRow = {[1] = "銀行", [2] = "合計"},
  HdrLvl = "レベル",
  HdrName = "名前",
  HdrClnd = "カレンダー",
  HdrMaj = "マジ・アルラガス",
  HdrGlirion = "赤髭グリリオン",
  HdrUrgarlag = "族長殺しのウルガルラグ",
  HdrLFGReward = "紫色報酬",
  HdrLFGRnd  = "ダンジョン",
  HdrLFGBG   = "バトルグラウンド",
  HdrLFGTrib = GetString(SI_ACTIVITY_FINDER_CATEGORY_TRIBUTE),
  HdrAvAReward = GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES705),
  SendInvTo = "<<1>> に招待を送る",
  ShareSubstr = "share",
  EndeavorTypeNames = {
    [1] = zo_strformat(SI_TIMED_ACTIVITIES_TYPE_HEADER, GetString(SI_TIMEDACTIVITYTYPE0)),
    [2] = zo_strformat(SI_TIMED_ACTIVITIES_TYPE_HEADER, GetString(SI_TIMEDACTIVITYTYPE1)),
    [3] = zo_strformat(SI_TIMED_ACTIVITIES_TYPE_HEADER, GetString(SI_TIMEDACTIVITYTYPE2))
  },
  EndeavorRepeat = "Repeat",
  PromoEventName = GetIcon(47, 20, true) ..
                   GetString(SI_ACTIVITY_FINDER_CATEGORY_PROMOTIONAL_EVENTS) .. " : <<1>>",
  NoWorldEventsHere = "There are no world events here",
  WECalculating = "Calculating",
  WEDistance = "Distance",
-- Pledge Quest Givers NPC names
  PledgeQGivers = {
    [1] = "マジ・アルラガス",
    [2] = "赤髭グリリオン",
    [3] = "族長殺しのウルガルラグ",
  },
-- Shadowy-Supplier NPC name
  ShadowySupplier = {
    ["引き続き黙る者"] = true,
  },
  ComeBackLater = "Come back later",
-- Replace text for long companion equipment names
  CompanionEquipRepl = {
   --- Trait names replacement ---
   --- Item names replacement ---
   --- Item types replacement ---
  },
-- Addon Options Menu
--> 1
  OptGeneralHdr = "一般設定",
  OptCharsOrder = "Characters Order",
  OptCharsOrderF = "The choice of the order in which characters are displayed in the addon window. UI reload required. Characters are sorted only at the start of the addon and in the future the order does not change.",
  OptAlwaysMaxWinX  = "メインウィンドウの幅を固定",
  OptAlwaysMaxWinXF = "有効にすると、アドオンのメインウィンドウの幅はすべてのモードで同じになります。無効にすると、幅はモードによって変化します。",
  OptLocation = "ダンジョン名の代わりに地名",
  OptENDungeon = "ダンジョン名を英語で表示",
  OptDontShowNone  = "\"なし\"の代わりに空白を表示",
  OptDontShowReady = "\"Ready\"の代わりに空白を表示",
  OptTitleToolTip = "ウィンドウのタイトルのツールチップを有効にする",
  OptHintUncomplPlg  = "Hint Pledges in uncompleted dungeons",
  OptHintUncomplPlgF = table.concat( {
                       "Show hints about today's pledges in the Undaunted Pledges window if those dungeons have not yet been completed.\n",
                       "A dungeon is considered incomplete if the story quest has not been completed or all bosses have not been killed.\n",
                       "(a dungeon must be available/unlocked for the account or character)",
                       } ),
  OptLargeCalend  = "Show calendar of Pledges for...",
  OptLargeCalendF = "Select the number of days in the Pledges calendar",
  OptDateFrmt  = "日付のフォーマット",
  OptDateFrmtF = "カレンダーウィンドウに表示する日付のフォーマットを選択",
  OptShowTime  = "日付の後に時間も表示",
  OptLFGRndAvl  = "The format of short time periods",
  OptLFGRndAvlF = "Select the format of short time periods (less than 24 hours), such as daily reward for random activities, Shadowy Supplier, Riding skill, etc.",
  OptTrialAvl  = "The format of long time periods",
  OptTrialAvlF = "Select the format of long time periods (more than 24 hours), such as the weekly reward for Trials, etc.",
  OptTimerList = {"カウントダウンタイマー","日時 (MM/DD hh:mi)","日時 (DD.MM hh:mi)"},
  OptRndDungDelay = "デイリー報酬の待ち時間",
  OptRndDungDelayF = "完了したランダムダンジョンのデイリー報酬の情報が、ゲームサーバーから通知されるのを待機する時間(秒)。デフォルト設定(5秒)は、再ログインやUIの再読み込み後のカウントダウンタイマーにて、アドオンが \"???\" と表示している場合にのみ変更できます。",
  OptShowMonsterSetTT = "モンスターセットのツールチップを表示",
  OptShowMonsterSetTTF = "\"アンドーンテッドの誓い\" と \"誓いのカレンダー\" にモンスターセットのツールチップを表示します",
  OptMouseModeUI = "マウスポインターを表示する",
  OptMouseModeUIF = "アドオンのウィンドウが開いている間、マウスポインターを表示します。",
  OptCharNamesMenu = "Characters names",
  OptCharNameColor = "Show the names in an Alliance color",
  OptCharNameAlign = "Names alignment",
  OptNamesAlignList = {"left", "center", "right"},
  OptCorrLongNames = "Correct the display of long names by",
  OptNamesCorrList = {"do nothing", "font size", "cutting the middle", "text mask"},
  OptNamesCorrRepl = {"Find this text in the name", "and replace with this text"},
  OptCurrencyValThres = "Round currency values to...",
  OptCurrencyValThresF = table.concat(
                         { "What numbers to round currency values to.\n",
                           GetString(SI_GAMEPAD_CURRENCY_SELECTOR_HUNDREDS_NARRATION),      " : 123 K\n",
                           GetString(SI_GAMEPAD_CURRENCY_SELECTOR_THOUSANDS_NARRATION),     " : 1234 K\n",
                           GetString(SI_GAMEPAD_CURRENCY_SELECTOR_TEN_THOUSANDS_NARRATION), " : 12345 K"
                         } ),
  OptDynEncounterNotify = zo_strformat("<<1>>: <<2>>", DynamicEncounterText, GetString(SI_MAIN_MENU_NOTIFICATIONS)),
  OptDynEncounterNotifyF = table.concat(
                           { "Show notifications at screen and in chat about the start, activity, completion, ",
                             "progress of Dynamic Encounters.\n\n",
                             GetString(SI_ACTIONBARSETTINGCHOICE2), " - hide notifications while the character is ",
                             "participating in an Encounter, otherwise show Dynamic Encounter notifications."
                           } ),
  OptCompanionRapport = "Show companions rapport as...",
  OptCompanionRprtList = {"number", "text"},
  OptCompanionRprtMax = "Also show maximum value",
  OptCompanionEquip = "Show companions equipment as...",
  OptCompanionEquipList = {"item name", "item type", "item trait", "type and trait"},
--> 2
  OptModeSetHdr = "Option and Mode settings",
  OptAutoActionsHdr = "Automation of daily activities",
  OptAutoTakeUpPledges = "誓いを自動受注",
  OptAutoTakeUpPledgesF = "アンドーンテッドNPCと会話すると誓いを自動で受注します。",
  OptAutoTakeDBSupplies = "Auto-receive the Dark Brotherhood supplies",
  OptAutoTakeDBSuppliesF = "Automatically receive beneficial items (supplies) during a conversation with the Shadowy Supplier",
  OptAutoTakeDBList = {"account-wide", "depends on Character"},
  OptChoiceDBSupplies = "What type of supplies to receive...",
  OptDBSuppliesList = {"do nothing", "poisons / potions", "less noticeable", "equipment"},
  OptAutoChargeWeapon = "Automatically charge weapons",
  OptAutoChargeWeaponF = "Automatically recharge weapon if current charge is less than minimum threshold.\n" ..
                         "The character's inventory must contain at least 1 filled Soul Gem.",
  OptAutoChargeThreshold = "Minimum charge threshold",
  OptAutoChargeThresholdF = "The weapon will be charged when the remaining enchantment charge is less than this value",
  OptAutoCallEyeInfinite = "Automatically summon " .. GetCollectibleName(WPamA.EndlessDungeons.EyeOfInfinite.C),
  OptAutoCallEyeInfiniteF = table.concat(
                            { "Automatically summon |t20:20:",
                              GetCollectibleIcon(WPamA.EndlessDungeons.EyeOfInfinite.C), "|t",
                              GetCollectibleName(WPamA.EndlessDungeons.EyeOfInfinite.C),
                              " while in Infinite Archive zones.\n\nThis option is available when that tool is available on the account."
                            } ),
  ---
--  OptEndeavorRewardMode = "Show challenge rewards as...",
--  OptEndeavorRewardList = {"single", "current", "maximum"},
  OptEndeavorChatMsg  = "Show challenge progress in chat",
  OptEndeavorChatMsgF = "Show information in the chat window when challenge progress changes",
  OptEndeavorChatChnl = "Chat channel for progress notifications",
  OptEndeavorChatChnlF = "Chat channel to show information about the challenge progress",
  OptEndeavorChatColor = "Progress notification color",
  OptEndeavorChatColorF = "Adjusts the color of progress notifications",
  OptEndeavorAutoClaim = "Auto-claim the Challenges rewards",
  OptEndeavorHideCompl = "Hide completed challenges",
  OptPursuitChatMsg  = "Show pursuit progress in chat",
  OptPursuitChatMsgF = "Show information in the chat window when the Golden Pursuits progress changes",
  OptPursuitChatCamp  = "Until a campaign reward is earned",
  OptPursuitChatCampF = "If enabled, show pursuit progress until a campaign reward is earned.\nIf disabled, always show pursuit progress.",
--  OptPursuitChatChnl = "Chat channel for progress notifications",
  OptPursuitChatChnlF = "Chat channel to show information about the Golden Pursuits progress",
  OptPursuitAutoClaim = "Auto-claim the Golden Pursuits rewards",
  ---
  OptLFGPHdr = "GFP設定(誓い向けグループ検索)",
  OptLFGPOnOff = "GFPを利用する",
  OptLFGPMode = "ダンジョンモード",
  OptLFGPModeList = {zo_strformat("always <<1>><<1>><<1>> (<<2>>)", Icon.Norm, Icon.LfgpKeys[1]), -- NNN
                     zo_strformat("always <<1>><<1>><<2>> (<<3>>)", Icon.Vet, Icon.Minus, Icon.LfgpKeys[2]), -- VV-
                     zo_strformat("always <<1>><<1>><<2>> (<<3>>)", Icon.Vet, Icon.Norm, Icon.LfgpKeys[3]), -- VVN
                     zo_strformat("always <<1>><<1>><<1>> (<<2>>)", Icon.Vet, Icon.LfgpKeys[4]), -- VVV
                     "depends on Character"},
  OptLFGPIgnPledge = "\"完了\" チェックマークを無視する",
  OptLFGPAlert = "画面に通知する",
  OptLFGPChat = "チャットに通知する",
  OptLFGPModeRoult = zo_strformat("Find as <<1>>/<<2>> for outdated Pledges", Icon.Vet, Icon.Norm),
  OptLFGPModeRoultF = table.concat(
                      { "In case, when the Group Finder is set to Veteran mode, ",
                        "and the character has a quest for an outdated (not current) Pledge, ",
                        "this setting allows you to additionally search for a group for Normal mode.\n\n",
                        "If enabled, find a group for any (", Icon.Vet, " or ", Icon.Norm,
                        ") mode - ", Icon.Roult, ".\n",
                        "If disabled, find a group for ", Icon.Vet, " mode only."
                      } ),
--> 3
  OptRGLAHdr = "RGLA設定(レイドグループリーダーアシスタント)",
  OptRGLAQAutoShare = "クエストの自動共有を有効にする",
  OptRGLAQAlert = "画面に通知する",
  OptRGLAQChat = "チャットに通知する",
  OptRGLABossKilled = "ボスが倒されるとRGLAは停止します。",
--> 4
  CharsOnOffHdr = "キャラクターの表示/非表示",
  CharsOnOffNote = "注意：あなたの現在のキャラクターはこの設定を常に無視します。現在のキャラクターに関する情報は全てのモードで常に表示されます",
  OptCharOnOffTtip = "キャラクター \"<<1>>\" の表示 / 非表示",
--> 5
  ModesOnOffHdr = "ウィンドウモードの表示 / 非表示",
  ModesOnOffNote = "注意： この設定はウィンドウモードを順番にスイッチします。ウィンドウモードを隠すことができますが、少なくとも1回以上はウィンドウモードを表示にします。また、コンテキストメニューから目的のウィンドウモードを直接指定することができます。",
  OptWindOnOffTtip = "ウィンドウ \"<<1>>\" の表示 / 非表示",
  OptModeOnOffTtip = "ウィンドウモード \"<<1>>\" の表示 / 非表示",
--> 6
  CustomModeKbdHdr  = "Custom key binding settings",
  CustomModeKbdNote = "Note: This settings are account-wide.\nCustomizing the mode call keys allows you to assign keys to call modes of your choice.",
  OptCustomModeKbd  = GetString(SI_COLLECTIBLECATEGORYTYPE29) .. " <<1>> ...",
--> 7
--  ResetCharNote = "",
  ResetChar = "キャラクターリストのリセット",
  ResetCharNote = "キャラクターを削除した場合でもデータは引き続き保存されます。存在しないキャラクターのデータを削除するには、以下のボタンをクリックする必要があります。キャラクターの一覧のリセット後、新しいキャラクターのデータを取得するには再ログインする必要があります。",
  ResetCharWarn = "全てのキャラクターに関するデータを削除します！よろしいですか？",
-- LFGP texts
  LFGPSrchCanceled = "グループ検索を中断しました",
  LFGPSrchStarted  = "グループ検索を開始しました",
  LFGPAlrdyStarted = "他のアクティビティが開始済みです",
  LFGPQueueFailed  = "キューの作成に失敗しました",
  LFGP_ErrLeader   = "グループリーダーではありません!",
  LFGP_ErrOverland = "フィールド上にいる必要があります!",
  LFGP_ErrGroupRole= "グループロールを設定してください!",
-- RGLA text
  RGLABossKilled = "ボスが倒されました。RGLAを停止しました。",
  RGLALeaderChanged = "グループリーダーが変更されました。RGLAを停止しました。",
  RGLAShare = "共有",
  RGLAStop = "停止",
  RGLAPost = "投稿",
  RGLAStart = "開始",
  RGLAStarted = "開始済み",
  RGLALangTxt = "日本語で",
-- RGLA Errors
  RGLA_ErrLeader = "グループリーダーではありません!",
  RGLA_ErrAI = "AutoInviteアドオンが見つからないか、有効でありません!",
  RGLA_ErrBoss = "ボスは既に倒されています。RGLAは起動できません。",
  RGLA_ErrQuestBeg = "デイリーボスクエストを受けていません (",
  RGLA_ErrQuestEnd = ")!",
  RGLA_ErrLocBeg = "現在、", 
  RGLA_ErrLocEnd = "にいません!", 
  RGLA_Loc = {
    [ 0] = "ロスガー",
    [ 1] = "ヴァーデンフェル",
    [ 2] = "ゴールドコースト",
    [ 3] = "サマーセット",
    [ 4] = "北エルスウェア",
    [ 5] = "西スカイリム",
    [ 6] = "グレイムーア洞窟",
    [ 7] = "ブラックウッド",
    [ 8] = "ハイ・アイル",
    [ 9] = "テルヴァンニ半島",
    [10] = "アポクリファ",
    [11] = "ソルスティス",
  },
-- Dungeons Status
  DungStDone = "完了",
  DungStNA = "無効",
-- Wrothgar Boss Status
  WWBStNone = "なし",
  WWBStDone = "完了",
  WWBStCur  = "進行中",
-- Trials Status
  TrialStNone = "なし",
  TrialStActv = "進行中",
-- LFG Random Dungeon Status
  LFGRewardReady = "Ready",
  LFGRewardNA = "無効",
-- Shadowy Supplier
  ShSuplUnkn = "?",
  ShSuplReady = "Ready",
  ShSuplNA = "無効",
-- Login Status
  LoginToday = "Today",
  Login1DayAgo = "Yesterday",
-- Dynamic Encounter Status
  DynamicEncounter = {
    Icon  = GetIcon(73, 20),
    Title = DynamicEncounterText,
    Start = "The event started",
    Stop  = "The event completed",
    Activ = "The event is active",
    Progr = table.concat({ GetString(SI_ENDLESS_DUNGEON_SUMMARY_PROGRESS_HEADER),
            " ", GetString(SI_SPECTACLE_EVENTS_PROGRESS_PERCENT) })
  },
--
}
WPamA.i18n.ToolTip = {
  [-1] = "",
  [ 0] = Icon.LMB .. " ウィンドウを閉じる",
  [ 1] = Icon.LMB .. " オプションウィンドウの表示/非表示",
  [ 2] = Icon.LMB .. " ウィンドウを変更\n" .. Icon.RMB .. " ウィンドウ選択",
  [ 3] = "チャットに今日の誓いを投稿する\n" .. Icon.LMB .. " 英語で\n".. Icon.RMB .. " 日本語で",
  [ 4] = "誓いの進捗状況です。",
  [ 5] = "現在及び未来の誓いのカレンダー",
  [ 6] = "デイリークエストの進捗状況です。",
  [ 7] = "アンドーンテッドの鍵、ロックピック、極大魂石、その他",
  [ 8] = "あなたのキャラクターは悟りを開きました。",
  [ 9] = "あなたのキャラクターは悟りを開いていません。",
  [10] = table.concat({ "Group Finder for Pledges\n", Icon.LMB, " ", WPamA.i18n.KeyBindLFGP, "\n", Icon.RMB, " ", WPamA.i18n.KeyBindLFGPMode }),
  [11] = "変性クリスタル",
--
  [12] = "Your current progress in World skills.",
  [13] = GetString(SI_STABLE_STABLES_TAB),
  [14] = GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKCATEGORIES1),
  [15] = "季節毎にあるお祭りイベントの進捗です",
  [16] = "ギルドスキルの進捗状況です。",
  [17] = "クラス＆同盟戦争スキルの進捗状況です。",
  [18] = "クラフトスキルの進捗状況です。",
  [19] = "試練の週報酬が入手可能になるまでの時間",
  [20] = "ランダムダンジョンの紫色報酬(高級アンドーンテッド探検物資)が入手可能になるまでの時間",
-- WB Wrothgar
  [21] = "未完成のドルメン\n - 蘇ったザンダデュノズ",
  [22] = "ニジャレフト・フォールズ\n - ニジャレフト ドワーフ センチュリオン",
  [23] = "族長王の玉座\n - 族長王エドゥ",
  [24] = "マッド・オーガの祭壇\n -  マッド・ウルカズブル",
  [25] = "密猟者の野営地\n - オールド・スナガラ",
  [26] = "呪われた託児所\n - 悪鬼コリンサック",
--
  [27] = "アチーブメントのカウントダウン",
  [28] = "An active effect (a bonus) that increases the amount of Alliance Points earned",
  [29] = table.concat({ "Group Finder for Pledges\n",
         Icon.Minus, " - GFP is not enabled in addon settings\n",
         GetIcon(62,18), " - possible number of keys (with HM)\n",
         Icon.Norm, "/", Icon.Vet, "/", Icon.Roult, " - Group Finder mode (in front of the dungeon name)" }),
  [30] = "紫色報酬が入手可能",
-- 31-39 Class skills + Guild skills
  [31] = "クラススキル： ファーストライン",
  [32] = "クラススキル： セカンドライン",
  [33] = "クラススキル： サードライン",
  [34] = "戦士ギルド",
  [35] = "魔導師ギルド",
  [36] = "アンドーンテッド",
  [37] = "盗賊ギルド",
  [38] = "闇の一党",
  [39] = "サイジック",
-- 41-47 Craft skills
-- 48-50 AvA skills
  [51] = "ヘル・ラ要塞",
  [52] = "エセリアルの保管庫",
  [53] = "聖域オフィディア",
  [54] = "モー・オブ・ローカジュ",
  [55] = "ホール・オブ・ファブリケーション",
  [56] = "聖者の隔離場",
  [57] = "クラウドレスト",
  [58] = "サンスパイア",
  [59] = "カイネズ・アイギス",
--
  [60] = GetString(SI_LEVEL_UP_REWARDS_SKILL_POINT_TOOLTIP_HEADER),
  [61] = "ゴールド",
  [62] = "依頼達成証",
  [63] = "同名ポイント",
  [64] = "テルバー・ストーン",
--65-70 Item name
-- WB Vvardenfell
  [71] = "ミシール・ダダリット卵鉱山\n - クィーンの配偶者",
  [72] = "サロサンの評議会\n - サロサン",
  [73] = "ニルソグ洞穴\n - 不壊なる者ニルソグ",
  [74] = "スリパンド繁殖場\n - ウユヴス",
  [75] = "ダブディル・アラーの塔\n -騙す者メーズ",
  [76] = "難破船の入江\n - ソングバードのキンブルディル",
-- WB Gold Coast
  [77] = "クヴァッチ・アリーナ",
  [78] = "トリビュナルズ・フォリー\n - ライムナウルス",
-- WB Summerset
  [81] = "女王の孵化場\n - サンゴ礁の女王",
  [82] = "キールスプリッターの巣\n - キールスプリッター",
  [83] = "インドリクの遊び場\n - ケイネリン",
  [84] = "ウェレンキンの入江\n - ブコルゲン",
  [85] = "グラヴェルドの巣\n - グラヴェルド",
  [86] = "グリフォン・ラン\n - ヘリアータとナグラヴィア",
-- Inventory
  [87] = "Information about filling the inventory",
  [88] = "Total places in the inventory",
  [89] = "Used places in inventory",
  [90] = "Free places in the inventory",
-- WB Northern Elsweyr
  [91] = "ボーンピット\n - 骨を紡ぐ者ナルズ",
  [92] = "スカーズエッジ\n - 墓をうろつく者サナール",
  [93] = "レッドハンズ・ラン\n - アクムジャーゴ + ザビ",
  [94] = "砕けた剣の丘\n - ソードマスター・ヴィスラデュー",
  [95] = "鉤爪の渓谷\n - 悪賢いキーヴァ",
  [96] = "悪夢の高原\n - ザルシーム",
-- Inventory Upgrades
  [97] = GetString(SI_INTERACT_OPTION_BUY_BAG_SPACE),
  [98] = GetString(SI_GAMEPAD_STABLE_TRAIN) .. " - " .. GetString(SI_RIDINGTRAINTYPE2),
  [99] = GetString(SI_COLLECTIBLECATEGORYTYPE3) .. " - " .. GetString(SI_BINDING_NAME_TOGGLE_INVENTORY),
-- AvA Activity
  [100] = GetString(SI_CAMPAIGN_BROWSER_TOOLTIP_HOME_CAMPAIGN),
  [101] = GetString(SI_CAMPAIGN_SCORING_END_OF_CAMPAIGN_REWARD_TIER),
  [102] = GetString(SI_GAMEPAD_CAMPAIGN_SCORING_DURATION_REMAINING),
  [103] = GetString(SI_STATS_ALLIANCE_RANK),
  [104] = GetString(SI_LOOT_HISTORY_LEADERBOARD_SCORE) .. ".\n" .. GetString(SI_LEADERBOARDS_RANK_HELP_TOOLTIP),
  [105] = GetString(SI_DAILY_LOGIN_REWARDS_TILE_HEADER) .. " (AvA)",
--
  [106] = GetString(SI_TIMED_ACTIVITIES_TITLES),
  [107] = "影の配達人",
  [108] = "影の配達人のクールダウンタイマー",
  [109] = "Rapport with Companions",
  [110] = GetString(SI_STAT_GAMEPAD_CHAMPION_POINTS_LABEL),
  [111] = GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES212),
-- World Events
  [112] = "", -- an overridden string
  [113] = "", -- an overridden string
  [114] = "", -- an overridden string
  [115] = table.concat({
          GetIcon(14, 24), "- How much time has passed since the active event was detected.\n",
          GetIcon(13, 28), "- How much time has passed since the event was completed." }),
  [116] = "How much time the event has been active.\n(how long did it take for players to complete the event)",
  [117] = "Estimated time until the world event is activated.\n" ..
          "At least 2 completed events are needed to calculate the time.\n" ..
          "The more events that are completed, the more accurate the time calculation will be.",
  [118] = "HP % - The health level of the event boss.\n" ..
          GetIcon(13, 28) .. "- How much time has passed since the event was completed.",
  [119] = "The distance in meters to the event boss.\nActual information about the boss can only be obtained within 300 meters of the boss.",
  [120] = "Estimated time until the world event is activated.\nDepends on the number and activity of players in the location.",
-- WB Western Skyrim
  [121] = "イスムガルの浜\n - 海の巨人",
  [122] = "ホードレックの狩場\n - ウェアウルフの狩猟パーティー",
  [123] = "サークル・オブ・チャンピオンズ\n - サークル・オブ・チャンピオンズ",
  [124] = "シェイドマザーの隠れ家\n - シェイドマザー",
-- WB Blackreach: Greymoor Caverns
  [125] = "吸血鬼の餌場\n - 餌場",
  [126] = "巨像の充填台\n - ドワーフの巨像",
--131-136 World skills
-- Endless Dungeon progress
  [158] = table.concat({ "Daily quest\n",
          Icon.Lock, " - introductory quest is not completed\n",
          Icon.Quest, " - quest is available\n",
          Icon.ChkM, " - quest completed" }),
  [159] = "Best progression reached\n(for all dungeon runs with the addon active)",
--160-190 Item name
-- Trials
  [191] = "ロックグローブ",
  [192] = "ドレッドセイル・リーフ",
  [193] = "正気の境界",
  [194] = "ルーセント要塞",
  [195] = "オセインの檻",
-- WB Blackwood
  [201] = "古きデスウォートの池\n - 古きデスウォート",
  [202] = "ゼームホックのラグーン\n - 戦利品を奪う者ゼームホック",
  [203] = "スル・ザンの儀式の地\n - 死の作り手ヤザト, ヌクジーマ, シュヴー・モク, 沼秘術師ヴィーシャ",
  [204] = "壊れたザンミーア\n - 先触れのゲムバス",
  [205] = "シャルドラスの発掘地点\n - ブールム",
  [206] = "蛙の舌の戦時キャンプ\n - ザスモズ族長",
-- Crafting Writs
  [207] = GetQuestName(WPamA.DailyWrits.QuestIDs[1][1]),
  [208] = GetQuestName(WPamA.DailyWrits.QuestIDs[2][1]),
  [209] = GetQuestName(WPamA.DailyWrits.QuestIDs[3][1]),
  [210] = GetQuestName(WPamA.DailyWrits.QuestIDs[4][1]),
  [211] = GetQuestName(WPamA.DailyWrits.QuestIDs[5][1]),
  [212] = GetQuestName(WPamA.DailyWrits.QuestIDs[6][1]),
  [213] = GetQuestName(WPamA.DailyWrits.QuestIDs[7][1]),
--214-229 Companion Skills
  [214] = "Class skills",
  [215] = "", -- an overridden string
  [216] = "", -- an overridden string
  [217] = "", -- an overridden string
  [218] = GetString(SI_EQUIPMENTFILTERTYPE1),
  [219] = GetString(SI_EQUIPMENTFILTERTYPE2),
  [220] = GetString(SI_EQUIPMENTFILTERTYPE3),
  [221] = GetString(SI_WEAPONCONFIGTYPE3),
  [222] = GetString(SI_WEAPONCONFIGTYPE1),
  [223] = GetString(SI_WEAPONCONFIGTYPE2),
  [224] = GetString(SI_WEAPONCONFIGTYPE4),
  [225] = GetString(SI_WEAPONCONFIGTYPE5),
  [226] = GetString(SI_WEAPONCONFIGTYPE6),
--227-240 Companion & Character Equips
  [227] = GetString(SI_EQUIPSLOT0),
  [228] = GetString(SI_EQUIPSLOT3),
  [229] = GetString(SI_EQUIPSLOT2),
  [230] = GetString(SI_EQUIPSLOT16),
  [231] = GetString(SI_EQUIPSLOT6),
  [232] = GetString(SI_EQUIPSLOT8),
  [233] = GetString(SI_EQUIPSLOT9),
  [234] = GetString(SI_EQUIPSLOT4),
  [235] = GetString(SI_EQUIPSLOT5),
  [236] = GetString(SI_EQUIPSLOT1),
  [237] = GetString(SI_EQUIPSLOT11),
  [238] = GetString(SI_EQUIPSLOT12),
  [239] = GetString(SI_EQUIPSLOT20),
  [240] = GetString(SI_EQUIPSLOT21),
-- WB High Isle
  [241] = "大蛇の沼\n - 大蛇の召喚者ヴィンシャ",
  [242] = "イフレの大鍋\n - サーベルナイト",
  [243] = "ダークストーン洞穴\n - 超越の執行者, 超越の拷問者",
  [244] = "ファウン・フォールズ\n - グレミョス・ワイルドホーン",
  [245] = "アメノス盆地\n - 術師スケラード, 術師ロサラ",
  [246] = "モーナード・フォールズ\n - ハドリッド・マトロン, ハドリッドの配偶者",
--247-249 Books Category (Init by WPamA:InitLoreBookMode)
-- Hireling mail and crafting profession certification
  [250] = table.concat({ "\n", Icon.Mail, " - Hirelings mail is available (need to log in the game or change location)",
                         "\n", Icon.NoCert, " - Crafting profession certification is not completed" }),
-- WB Necrom
  [251] = "悪夢の巣窟\n - さまよう悪夢",
  [252] = "クレイマークラップの器\n - 鎖作りのコーリス",
  [253] = "ディープリーヴ湿地\n - ヴロクールシャ",
  [254] = "クトン広場\n - ヴァルキナズ・デク",
  [255] = "リブラムの大聖堂\n - プライムカタロガー",
  [256] = "ルーンマスターのアクロポリス\n - ルーンマスター・ジオマラ",
--257-260
-- WB Gold Road
  [261] = "フォールズ・グレード\n - 紡ぎ手ウーセンディル",
  [262] = "ブロークンパス洞窟\n - 運命を喰らう者ストリ",
  [263] = "百人隊長の丘\n - 牙, 鉤爪",
  [264] = "幸運の断崖\n - 不吉なヘセダズ",
  [265] = "辺境のゆりかご\n - 回想者の指導者",
  [266] = "オロ湖\n - オーケンクロウ",
-- WB Solstice
  [267] = "タイドウォッシュ浜\n - タイドスパイト",
  [268] = "トゥニリア遺跡\n - ガウルム",
  [269] = "ヴァッカンの祠\n - ヴォスクロナのガーディアン",
  [270] = "ソウルコーラーのうろつく場所\n - ソウルコーラー",
  [271] = "ウォ・ジースの巣\n - ウォ・ジース",
  [272] = "ジブ・エレークの儀式の地\n - ギシュゾル",
--273-280 Item name
}
--
WPamA.i18n.ToolTip[215] = WPamA.i18n.ToolTip[34]
WPamA.i18n.ToolTip[216] = WPamA.i18n.ToolTip[35]
WPamA.i18n.ToolTip[217] = WPamA.i18n.ToolTip[36]
--
WPamA.i18n.RGLAMsg = {
  [1] = "ギルド: メンバーを探す ...",
  [2] = "ギルド: メンバーを探す（短縮）",
  [3] = "ギルド: 1分後に開始",
  [4] = "グループ: 1分後に開始",
  [5] = "グループ: 開始",
  [6] = "ギルド: ボスが倒された",
  [7] = "グループ: 既に行っている",
  [8] = "アドオンについて",
}
-- In Dungeons structure:
-- Q - Quest name which indicates the dungeon
-- N - Short name of the dungeon displayed by the addon
WPamA.i18n.Dungeons = {
-- Virtual dungeon
  [1] = { -- None
    N = "なし",
  },
  [2] = { -- Unknown
    N = "不明",
  },
-- First location dungeons
  [3] = { -- AD, Auridon, Banished Cells I
    N = "追放者の監房1",
  },
  [4] = { -- EP, Stonefalls, Fungal Grotto I
    N = "フンガル洞窟1",
  },
  [5] = { -- DC, Glenumbra, Spindleclutch I
    N = "スピンドルクラッチ1",
  },
  [6] = { -- AD, Auridon, Banished Cells II
    N = "追放者の監房2",
  },
  [7] = { -- EP, Stonefalls, Fungal Grotto II
    N = "フンガル洞窟2",
  },
  [8] = { -- DC, Glenumbra, Spindleclutch II
    N = "スピンドルクラッチ2",
  },
-- Second location dungeons
  [9] = { -- AD, Grahtwood, Elden Hollow I
    N = "エルデン洞穴1",
  },
  [10] = { -- EP, Deshaan, Darkshade Caverns I
    N = "ダークシェイド洞窟1",
  },
  [11] = { -- DC, Stormhaven, Wayrest Sewers I
    N = "ウェイレスト下水道1",
  },
  [12] = { -- AD, Grahtwood, Elden Hollow II
    N = "エルデン洞穴2",
  },
  [13] = { -- EP, Deshaan, Darkshade Caverns II
    N = "ダークシェイド洞窟2",
  },
  [14] = { -- DC, Stormhaven, Wayrest Sewers II
    N = "ウェイレスト下水道2",
  },
-- 3 location dungeons
  [15] = { -- AD, Greenshade, City of Ash I
    N = "灰の街1",
  },
  [16] = { -- EP, Shadowfen, Arx Corinium
    N = "アークス・コリニウム",
  },
  [17] = { -- DC, Rivenspire, Crypt of Hearts I
    N = "ハーツ墓地1",
  },
  [18] = { -- AD, Greenshade, City of Ash II
    N = "灰の街2",
  },
  [19] = { -- DC, Rivenspire, Crypt of Hearts II
    N = "ハーツ墓地2",
  },
-- 4 location dungeons
  [20] = { -- AD, Malabal Tor, Tempest Island
    N = "テンペスト島",
  },
  [21] = { -- EP, Eastmarch, Direfrost Keep
    N = "ダイアフロスト砦",
  },
  [22] = { -- DC, Alik`r Desert, Volenfell
    N = "ヴォレンフェル",
  },
-- 5 location dungeons
  [23] = { -- AD, Reaper`s March, Selene`s Web
    N = "セレーンの巣",
  },
  [24] = { -- EP, The Rift, Blessed Crucible
    N = "聖なるるつぼ",
  },
  [25] = { -- DC, Bangkorai, Blackheart Haven
    N = "ブラックハート・ヘヴン",
  },
-- 6 location dungeons
  [26] = { -- Any, Coldharbour, Vaults of Madness
    N = "狂気の地下室",
  },
-- 7 location dungeons
  [27] = { -- Any, Imperial City, IC Prison
    N = "帝都監獄",
  },
  [28] = { -- Any, Imperial City, WG Tower
    N = "白金の塔",
  },
-- Shadows of the Hist DLC dungeons
  [29] = { -- Any, Shadowfen, Ruins of Mazzatun
    N = "マザッタン遺跡",
  },
  [30] = { -- Any, Shadowfen, Cradle of Shadows
    N = "影のゆりかご",
  },
-- Horns of the Reach DLC dungeons
  [31] = { -- Any, Craglorn, Bloodroot Forge
    N = "ブラッドルート・フォージ",
  },
  [32] = { -- Any, Craglorn, Falkreath Hold
    N = "ファルクリース要塞",
  },
-- Dragon Bones DLC dungeons
  [33] = { -- DC, Bangkorai, Fang Lair
    N = "牙の巣",
  },
  [34] = { -- DC, Stormhaven, Scalecaller Peak
    N = "スケイルコーラー・ピーク",
  },
-- Wolfhunter DLC dungeons
  [35] = { -- AD, Reaper`s March, Moon Hunter Keep
    N = "月狩人の砦",
  },
  [36] = { -- AD, Greenshade, March of Sacrifices
    Q = "誓い: マーチ・オブ・サクリファイス",
    N = "マーチ・オブ・サクリファイス",
  },
-- Wrathstone DLC dungeons
  [37] = { -- EP, Eastmarch, Frostvault
    N = "フロストヴォルト",
  },
  [38] = { -- Any, Gold Coast, Depths of Malatar
    N = "マラタールの深淵",
  },
-- Scalebreaker DLC dungeons
  [39] = { -- Any, Elsweyr, Moongrave Fane
    N = "ムーングレイブ神殿",
  },
  [40] = { -- AD, Grahtwood, Lair of Maarselok
    N = "マーセロクの巣",
  },
-- Harrowstorm DLC dungeons
  [41] = { -- Any, Wrothgar, Icereach
    N = "アイスリーチ",
  },
  [42] = { -- DC, Bangkorai, Unhallowed Grave
    N = "不浄の墓",
  },
-- Stonethorn DLC dungeons
  [43] = { -- Any, Blackreach, Stone Garden
    N = "ストーンガーデン",
  },
  [44] = { -- Any, Western Skyrim, Castle Thorn
    N = "ソーン城",
  },
-- Flames of Ambition DLC dungeons
  [45] = { -- Any, Gold Coast, Black Drake Villa
    N = "ブラック・ドレイクの邸宅",
  },
  [46] = { -- EP, Deshaan, The Cauldron
    N = "〈大鍋〉",
  },
-- Waking Flame DLC dungeons
  [47] = { -- DC, Glenumbra, Red Petal Bastion
    N = "赤い花弁の砦",
  },
  [48] = { -- Any, Blackwood, The Dread Cellar
    N = "ドレッドセラー",
  },
-- Ascending Tide DLC dungeons
  [49] = { -- Any, Summerset, Coral Aerie
    N = "サンゴの高所",
  },
  [50] = { -- DC, Rivenspire, Shipwright's Regret
    N = "船大工の後悔",
  },
-- Lost Depths DLC dungeons
  [51] = { -- Any, High Isle, Earthen Root Enclave
    N = "アーセンルート居留地",
  },
  [52] = { -- Any, High Isle, Graven Deep
    N = "グレイブン・ディープ",
  },
-- Scribes of Fate DLC dungeons
  [53] = { -- EP -> Stonefalls - Bal Sunnar
    N = "バル・サナー",
  },
  [54] = { -- EP -> The Rift - Scrivener's Hall
    N = "書記の館",
  },
-- Scions of Ithelia DLC dungeons
  [55] = { -- Any -> The Reach - Oathsworn Pit
    N = "オーススウォーンの訓練場",
  },
  [56] = { -- Any -> Wrothgar - Bedlam Veil
    N = "ベドラムのベール",
  },
-- Fallen Banners DLC dungeons
  [57] = { -- Any -> The Gold Road - Exiled Redoubt
    N = "追放者の砦",
  },
  [58] = { -- Any -> Hew's Bane - Lep Seclusa
    N = "レプ・セクルーサ",
  },
-- Feast of Shadows DLC dungeons
  [59] = { -- Any -> Solstice - Naj-Caldeesh
    N = "ナジ・カルディーシュ",
  },
  [60] = { -- Any -> Solstice - Black Gem Foundry
    N = "黒き石の工場",
  },
} -- Dungeons end
WPamA.i18n.DailyBoss = {
-- Wrothgar
  [1]  = {C = "蘇ったザンダデュノズを倒す",}, -- zanda,
  [2]  = {C = "ニジャレフトを倒す",}, -- nyz,
  [3]  = {C = "族長王エドゥを倒す",}, -- edu,
  [4]  = {C = "オーガのマッド・ウルカズブルを倒す",}, -- ogre,
  [5]  = {C = "オールド・スナガラを倒す",}, -- poa,
  [6]  = {C = "悪鬼コリンサックを倒す",}, -- cori,
-- Vvardenfell
  [7]  = {C = "クイーンの配偶者を倒す",}, -- QUEEN
  [8]  = {C = "",}, -- SAL
  [9]  = {C = "不壊なる者ニルソグを倒す",}, -- NIL
  [10] = {C = "ウユヴスを倒す",}, -- WUY
  [11] = {C = "",}, -- DUB 
  [12] = {C = "ソングバードのキンブルディルを倒す",}, -- SIREN
-- Gold Coast
  [13] = {C = "クヴァッチ・アリーナを制覇する",}, -- arena
  [14] = {C = "発掘現場を掃討する",}, -- mino
-- Summerset
  [15] = {C = "サンゴ礁の女王を倒す",}, -- QUEEN
  [16] = {C = "キールスプリッターを倒す",}, -- KEEL
  [17] = {C = "ケイネリンを倒す",}, -- CAAN
  [18] = {C = "ブコルゲンを倒す",}, -- KORG 
  [19] = {C = "グラヴェルドを倒す",}, -- GRAV
  [20] = {C = "ヘリアータとナグラヴィアを倒す",}, -- GRYPH 
-- Northern Elsweyr
  [21] = {C = "骨を紡ぐ者ナルズを倒す",}, -- NARUZ
  [22] = {C = "墓をうろつく者サナールを倒す",}, -- THAN
  [23] = {C = "ザビとアクムジャーゴを倒す",}, -- ZAVI
  [24] = {C = "ソードマスター・ヴィスラデューを倒す",}, -- VHYS
  [25] = {C = "悪賢いキーヴァを倒す",}, -- KEEVA
  [26] = {C = "ザルシームを倒す",}, -- ZAL
-- Western Skyrim
  [27] = {C = "海の巨人イスムガルを倒す",}, -- YSM
  [28] = {C = "ウェアウルフを倒す",}, -- WWOLF
  [29] = {C = "無敵のスクレグを倒す",}, -- SKREG
  [30] = {C = "シェイドマザーを倒す",}, -- SHADE
-- Blackreach: Greymoor Caverns
  [31] = {C = "吸血鬼の餌場を浄化する",}, -- VAMP
  [32] = {C = "ドワーフの巨像ディスマントラーを倒す",}, -- DISM
-- Blackwood
  [33] = {C = "古きデスウォートを倒す",}, -- FROG
  [34] = {C = "戦利品を奪う者ゼームホックを倒す",}, -- XEEM
  [35] = {C = "スル・ザンの祭司を倒す",}, -- SUL
  [36] = {C = "先触れのゲムバスを倒す",}, -- RUIN
  [37] = {C = "ブールム・コスカを倒す",}, -- BULL
  [38] = {C = "ザスモズ族長を倒す",}, -- ZATH
-- High Isle
  [39] = {C = "大蛇の召喚者ヴィンシャを倒す",}, -- VIN
  [40] = {C = "サーベルナイトを破壊する",}, -- SAB
  [41] = {C = "超越騎士団の狂信者を倒す",}, -- SHAD
  [42] = {C = "グレミョス・ワイルドホーンを倒す",}, -- WILD
  [43] = {C = "エルダータイドの術師を倒す",}, -- ELD
  [44] = {C = "ハドリッド・マトロンを倒す",}, -- HAD
-- Necrom
  [45] = {C = "さまよう悪夢を倒す",}, -- WNM
  [46] = {C = "鎖作りのコーリスを倒す",}, -- CORL
  [47] = {C = "ヴロクールシャを倒す",}, -- VRO
  [48] = {C = "ヴァルキナズ・デクを倒す",}, -- DEK
  [49] = {C = "プライムカタロガーを倒す",}, -- CATL
  [50] = {C = "ルーンマスター・ジオマラを倒す",}, -- XIOM
-- Gold Road
  [51] = {C = "紡ぎ手ウーセンディルを倒す",}, -- URTH
  [52] = {C = "運命を喰らう者ストリを倒す",}, -- STRI
  [53] = {C = "牙と爪を倒す",}, -- FANG
  [54] = {C = "不吉なヘセダズを倒す",}, -- HESS
  [55] = {C = "回想者の指導者を倒す",}, -- RECO
  [56] = {C = "オーケンクロウを倒す",}, -- OAK
-- Solstice
  [57] = {C = "タイドスパイトを倒す"}, -- TIDE
  [58] = {C = "ガウルムを倒す"}, -- GAULM
  [59] = {C = "ヴォスクロナのガーディアンを倒す"}, -- VOSK
  [60] = {C = "ソウルコーラーを倒す"}, -- SCALL
  [61] = {C = "ウォ・ジースを倒す"}, -- WOXET
  [62] = {C = "ギシュゾルを倒す"}, -- GHISH
}
WPamA.i18n.DayOfWeek = {
  [0] = "日",
  [1] = "月",
  [2] = "火",
  [3] = "水",
  [4] = "木",
  [5] = "金",
  [6] = "土",
}
WPamA.i18n.Chat = {
  Today = "今日の誓い[<<1>>(<<2>>)より]: ",
  Anyday = "誓い[<<1>>(<<2>>)より]: ",
  Loot  = "(<<1>>が取得可能)",
  Addon = " (<<1>> v<<X:2>>を利用)",
  Dlmtr = ", ",
}
WPamA.i18n.RGLA = {
  CZ = "/z",
  CL = "/g1",
  CP = "/p",
  F1 = "<<1>> <<2>> のクエストがシェアできます。",
  F2 = "AutoInvite及びAutoShareで参加するにはいずれかの文字列をチャットから入力してください。<<1>>",
  F3 = "AutoInviteで参加するにはいずれかの文字列をチャットから入力してください。<<1>>",
--F4 = "",
  F5 = " ( <<1>> ).",
  F6 = "<<1>> AutoInvite及びAutoShareで \"<<2>>\" の参加を募集しています。",
  F7 = "<<1>> AutoInviteで \"<<2>>\" の参加を募集しています。",
  F8 = "<<1>> あと1分で <<2>> を開始します。",
  F9 = "/p <<1>> を開始します。",
  F10= "<<1>> <<2>> は倒されました。",
  F11= "/p クエストは自動的にシェアされます。おそらく、あなたは既に他のボスのクエストを受けているか、今日の分を既に完了しています。",
  F12= "アドオン<<1>> v<<2>> from ESOUI.COM: 自動招待及び自動共有機能を有する「誓い」と「ロスガーボスデイリークエスト」の追跡ツールです。",
}
--== This part should be only in Japanese localization ==--
do
  local Bosses = WPamA.WorldBosses.Bosses
  -- Rename Bosses.H
  Bosses[1].H = "ザンダ"
  Bosses[2].H = "ニジャ"
  Bosses[3].H = "エドゥ"
  Bosses[4].H = "マッド"
  Bosses[5].H = "スナガラ"
  Bosses[6].H = "コリン"
--[[
  -- Copy Bosses.H to modes headers array
  for j = 1, 6 do
    WPamA.ModeSettings[2].HdT[j] = Bosses[j].H
  end
--]]
end
