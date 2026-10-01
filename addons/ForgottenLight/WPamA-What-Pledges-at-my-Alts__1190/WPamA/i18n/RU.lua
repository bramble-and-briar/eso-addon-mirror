local Icon = WPamA.Consts.IconsW
local GetIcon = WPamA.Textures.GetTexture
local OpenWindowText = GetString(SI_ENTER_CODE_CONFIRM_BUTTON) -- "Открыть окно"
local DynamicEncounterText = GetString(SI_HUD_EDITOR_DYNAMIC_EVENT_TRACKER) -- "Случайное событие" GetAchievementSubCategoryInfo(1,1)
WPamA.i18n = {
  Lng = "RU",
-- DateTime settings
  DateTimePart = {dd = 0, mm = 1, yy = 2},
--  SwapDDMM = true,
  DateFrmt = 3, -- 1 default:m.d.yyy ; 2:yyyy-mm-dd; 3:dd.mm.yyyy; 4:yyyy/mm/dd; 5:dd.mm.yy; 6:mm/dd; 7:dd.mm
  DateFrmtList = {"ESO По умолчанию","ГГГГ-ММ-ДД","ДД.ММ.ГГГГ","ГГГГ/ММ/ДД","ДД.ММ.ГГ","ММ/ДД","ДД.ММ"},
  DayMarker = "д",
  MetricPrefix = {"К","М","Г","Т","П","Э"},
  CharsOrderList = {"ESO По умолчанию","Имена","Альянс, Имена","Макс.уров., Имена","Мин.уров., Имена","Альянс, Макс.уров.","Альянс, Мин.уров."},
-- Marker (substring) in active quest step text for detect DONE stage
  DoneM = {
    [1] = "Return to",
    [2] = "Talk to",
    [3] = "Вернут",
    [4] = "Поговор",
  },
-- Keybinding string
  KeyBindShowStr  = "Показать/скрыть окно аддона",
  KeyBindChgWStr  = "Открыть следующее окно",
  KeyBindChgTStr  = "Открыть следующий режим окна",
  KeyBindChgAStr  = "Открыть следующий режим аддона",
  KeyFavRadMenu   = "Круговое меню избранных режимов",
  KeyBindCharStr  = "Показать Обеты персонажей",
  KeyBindClndStr  = "Показать календарь Обетов",
  KeyBindPostTd   = "Отправить в чат сегодняшние Обеты (EN)",
  KeyBindPostTdCL = "Отправить в чат сегодняшние Обеты (RU)",
  KeyBindWindow0  = OpenWindowText .. ": " .. "Групповые Подземелья",
  KeyBindWindow1  = OpenWindowText .. ": " .. "Испытания (триалы)",
  KeyBindWindow2  = OpenWindowText .. ": " .. GetString(SI_ZONECOMPLETIONTYPE9), -- "Мировые боссы"
  KeyBindWindow3  = OpenWindowText .. ": " .. "Навыки",
  KeyBindWindow4  = OpenWindowText .. ": " .. GetString(SI_BINDING_NAME_TOGGLE_INVENTORY), -- "Инвентарь"
  KeyBindWindow5  = OpenWindowText .. ": " .. GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKCATEGORIES1), -- "Война альянсов и PvP"
  KeyBindWindow6  = OpenWindowText .. ": " .. GetString(SI_MAPFILTER14), -- "Спутники"
  KeyBindWindow7  = OpenWindowText .. ": " .. GetString(SI_JOURNAL_MENU_ACHIEVEMENTS) ..
                    ", " .. GetString(SI_COLLECTIONS_MENU_ROOT_TITLE), -- "Достижения, Коллекции"
  KeyBindWindow8  = OpenWindowText .. ": " .. GetString(SI_QUEST_JOURNAL_GENERAL_CATEGORY), -- "Разное"
  KeyBindRGLA     = "Показать/скрыть RGLА (Помощник лидера рейдовой группы)",
  KeyBindRGLASrt  = "RGLА: Старт",
  KeyBindRGLAStp  = "RGLА: Стоп",
  KeyBindRGLAPst  = "RGLА: Сообщение в чат",
  KeyBindRGLAShr  = "RGLА: Расшарить квест",
  KeyBindLFGP     = "GFP: Старт/стоп поиска",
  KeyBindLFGPMode = "GFP: Выбор режима",
-- Caption
  Wind = {
    [0] = {
      Capt = "Групповые Подземелья",
      Tab = {
        [1] = {N="Взятые обеты", W=114},
        [2] = {N="Календарь", W=89},
        [3] = {N="Случайная деятельность", W=201},
        [4] = {N=GetString(SI_ENDLESS_DUNGEON_LEADERBOARDS_CATEGORIES_HEADER), W=181}, -- "Бесконечный архив"
      },
    },
    [1] = {
      Capt = "Испытания (триалы)",
      Tab = {
        [1] = {N="AA, HRC, SO, MOL, CR, SS", W=192},
        [2] = {N="HOF, AS, KA, RG, DSR, SE", W=192},
        [3] = {N="LC, OC", W=192},
      },
    },
    [2] = {
      Capt = GetString(SI_ZONECOMPLETIONTYPE9), -- "Мировые боссы"
      Tab = {
        [ 1] = {N=GetIcon(18,28), NC=GetIcon(18,28,true), W=28, S=true, A="Ротгар"},
                -- SI_CHAPTER1 = "Morrowind"
        [ 2] = {N=GetIcon(25,28), NC=GetIcon(25,28,true), W=28, S=true, A="Вварденфелл"},
        [ 3] = {N=GetIcon(22,28), NC=GetIcon(22,28,true), W=28, S=true, A="Золотой Берег"},
                -- SI_CHAPTER2 = "Summerset"
        [ 4] = {N=GetIcon(26,26), NC=GetIcon(26,26,true), W=28, S=true, A="Саммерсет"},
                -- SI_CHAPTER3 = "Elsweyr"
        [ 5] = {N=GetIcon(28,26), NC=GetIcon(28,26,true), W=28, S=true, A="Северный Эльсвейр"},
                -- SI_CHAPTER4 = "Greymoor"
        [ 6] = {N=GetIcon(30,28), NC=GetIcon(30,28,true), W=28, S=true, A="Западный Скайрим"},
        [ 7] = {N=GetIcon(34,28), NC=GetIcon(34,28,true), W=28, S=true, A=GetString(SI_CHAPTER5)}, -- "Черный Лес"
        [ 8] = {N=GetIcon(40,28), NC=GetIcon(40,28,true), W=28, S=true, A=GetString(SI_CHAPTER6)}, -- "Высокий Остров"
        [ 9] = {N=GetIcon(42,28), NC=GetIcon(42,28,true), W=28, S=true, A=GetString(SI_CHAPTER7)}, -- "Некром"
        [10] = {N=GetIcon(43,28), NC=GetIcon(43,28,true), W=28, S=true, A=GetString(SI_CHAPTER8)}, -- "Золотая Дорога"
        [11] = {N=GetIcon(66,28), NC=GetIcon(66,28,true), W=28, S=true, A=GetString(SI_CHAPTER9)}, -- "Солстис"
      },
    },
    [3] = {
      Capt = "Навыки",
      Tab = {
        [1] = {N="Класс и Альянс", W=128},
        [2] = {N="Ремесло", W=74},
        [3] = {N="Гильдия", W=69},
        [4] = {N="Общие", W=58},
        [5] = {N=GetIcon(27,28), NC=GetIcon(27,28,true), W=28, S=true, A=GetString(SI_STATS_RIDING_SKILL)},
        [6] = {N=GetIcon(22,28), NC=GetIcon(22,28,true), W=28, S=true, A="Теневой поставщик"},
        [7] = {N=zo_strformat("<<1>><<2>><<3>>", GetIcon(57,22), GetIcon(58,22), GetIcon(59,22)),
               NC=zo_strformat("<<1>><<2>><<3>>", GetIcon(57,22,true), GetIcon(58,22,true), GetIcon(59,22,true)),
               W=70, S=true, A=GetString(SI_STAT_GAMEPAD_CHAMPION_POINTS_LABEL)},
      },
    },
    [4] = {
      Capt = GetString(SI_BINDING_NAME_TOGGLE_INVENTORY), -- "Инвентарь"
      Tab = {
        [1] = {N="Валюта", W=64},
        [2] = {N="Предметы", W=84},
        [3] = {N=GetIcon(32,24), NC=GetIcon(32,24,true), W=28, S=true, A="Свитки опыта"},
        [4] = {N=GetIcon(60,24), NC=GetIcon(60,24,true), W=28, S=true, A="Жеоды трансмутации"},
        [5] = {N=GetIcon(31,28), NC=GetIcon(31,28,true), W=28, S=true,
               A=GetString(SI_GAMEPAD_PLAYER_INVENTORY_CAPACITY_FOOTER_LABEL)}, -- "Вместимость инвентаря"
        [6] = {N=GetIcon(61,24), NC=GetIcon(61,24,true), W=28, S=true,
               A=zo_strformat("<<1>>,\n<<2>>,\n<<3>>", GetString(SI_SPECIALIZEDITEMTYPE100),
                              GetString(SI_SPECIALIZEDITEMTYPE101), GetString(SI_SPECIALIZEDITEMTYPE2750) )},
        [7] = {N=GetIcon(65,28), NC=GetIcon(65,28,true), W=28, S=true,
               A=GetString(SI_ITEMTYPEDISPLAYCATEGORY26)}, -- "Контейнеры"
      },
    },
    [5] = {
      Capt = GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKCATEGORIES1), -- "Война альянсов и PvP"
      Tab = {
        [1] = {N=GetString(SI_CAMPAIGNRULESETTYPE1), W=71}, -- "Сиродил"
        [2] = {N=GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES5), W=127}, -- "Поля сражений"
        [3] = {N=GetString(SI_DAILY_LOGIN_REWARDS_TILE_HEADER), W=173}, -- "Ежедневные награды"
        [4] = {N="Награды и знаки", W=135},
        [5] = {N="AP бонус", W=75},
--        [6] = {N=GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES4), W=100}, -- "Имперский город"
      },
    },
    [6] = {
      Capt = GetString(SI_MAPFILTER14), -- "Спутники"
      Tab = {
        [1] = {N=GetIcon(45, 24) .. "1", NC=GetIcon(45, 24, true) .. "1", W=70, S=true, A="Отношения"}, -- GetString(SI_COMPANION_OVERVIEW_RAPPORT)
        [2] = {N=GetIcon(45, 24) .. "2", NC=GetIcon(45, 24, true) .. "2", W=70, S=true, A="Отношения"}, -- GetString(SI_COMPANION_OVERVIEW_RAPPORT)
        [3] = {N=zo_strformat("<<1>><<2>><<3>>", GetIcon(24, 24), GetIcon(35, 24), GetIcon(39, 24)),
               NC=zo_strformat("<<1>><<2>><<3>>", GetIcon(24, 24, true), GetIcon(35, 24, true), GetIcon(39, 24, true)),
               W=70, S=true, A="Навыки: класс, гильдия, доспехи"},
        [4] = {N=zo_strformat("<<1>><<2>><<3>>", GetIcon(48, 24), GetIcon(51, 24), GetIcon(53, 24)),
               NC=zo_strformat("<<1>><<2>><<3>>", GetIcon(48, 24, true), GetIcon(51, 24, true), GetIcon(53, 24, true)),
               W=70, S=true, A="Навыки: оружие"},
        [5] = {N=zo_strformat("<<1>><<2>><<3>>", GetIcon(38, 24), GetIcon(39, 24), GetIcon(37, 24)),
               NC=zo_strformat("<<1>><<2>><<3>>", GetIcon(38, 24, true), GetIcon(39, 24, true), GetIcon(37, 24, true)),
               W=70, S=true,
               -- "Снаряжение: Доспехи"
               A=zo_strformat("<<1>>: <<2>>", GetString(SI_ARMORY_EQUIPMENT_LABEL), GetString(SI_EQUIPSLOTVISUALCATEGORY2))},
        [6] = {N=zo_strformat("<<1>><<2>><<3>>", GetIcon(54, 24), GetIcon(48, 24), GetIcon(55, 24)),
               NC=zo_strformat("<<1>><<2>><<3>>", GetIcon(54, 24, true), GetIcon(48, 24, true), GetIcon(55, 24, true)),
               W=70, S=true,
               -- "Снаряжение: Оружие, Аксессуары"
               A=zo_strformat("<<1>>: <<2>>, <<3>>", GetString(SI_ARMORY_EQUIPMENT_LABEL),
                              GetString(SI_EQUIPSLOTVISUALCATEGORY1), GetString(SI_EQUIPSLOTVISUALCATEGORY3))},
        [7] = {N=zo_strformat("<<1>><<2>>", GetIcon(75, 28), GetIcon(24, 24)),
               NC=zo_strformat("<<1>><<2>>", GetIcon(75, 28, true), GetIcon(24, 24, true)),
               W=70, S=true,
               -- "Навыки: Активные способности"
               A=zo_strformat("<<1>>: <<2>>", GetString(SI_COMPANION_OVERVIEW_SKILLS), GetString(SI_SKILLS_ACTIVE_ABILITIES))},
      },
    },
    [7] = {
      Capt = GetString(SI_JOURNAL_MENU_ACHIEVEMENTS) .. ", " .. GetString(SI_COLLECTIONS_MENU_ROOT_TITLE),
      Tab = {
        [1] = {N="Сезонные фестивали", W=172},
        [2] = {N=GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES803), W=70},
        [3] = {N=GetString(SI_RECIPECRAFTINGSYSTEM6), W=100}, -- "Чертежи"
        [4] = {N=GetString(SI_QUESTTYPE19), W=100}, -- "Просьбы"
      },
    },
    [8] = {
      Capt = GetString(SI_QUEST_JOURNAL_GENERAL_CATEGORY), -- "Разное"
      Tab = {
        [1] = {N=GetString(SI_TIMED_ACTIVITIES_TITLES), W=102}, -- "Деяния"
        [2] = {N="Заказы", W=64},
        [3] = {N=GetIcon(12,28), NC=GetIcon(12,28,true), W=28, S=true, A=GetString(SI_ZONECOMPLETIONTYPE8)}, -- "Мировые события"
        [4] = {N=GetIcon(56,28), NC=GetIcon(56,28,true),
               W=28, S=true, A=GetString(SI_CUSTOMER_SERVICE_OVERVIEW)}, -- "Общие сведения"
        [5] = {N=GetIcon(69,28), NC=GetIcon(69,28,true),
               W=28, S=true, A=GetString(SI_CHARGE_WEAPON_TITLE)}, -- "Зарядка оружия"
      },
    },
  },
  ModeSettings = {
    [25] = {
      HdT = { [1] = "Всего", [2] = "Занято", [3] = "Свободно" }
    },
--------
    [42] = {
      HdT = {
        [1] = GetString(SI_COLLECTIBLERESTRICTIONTYPE1), -- Race
        [2] = GetString(SI_COLLECTIBLERESTRICTIONTYPE3), -- Class
        [3] = "Очки", [4] = "Последний вход", [5] = "Время игры"
      },
    },
--------
    [50] = {
      HdT = {
        [1] = GetString(SI_CAMPAIGN_OVERVIEW_CATEGORY_BONUSES), -- Бонусы
        [2] = GetString(SI_STAT_GAMEPAD_TIME_REMAINING):gsub(":", "") -- time remaining
      },
    },
--------
    [51] = {
      HdT = { [1] = GetMailListName(1), [2] = GetMailListName(2), [3] = GetMailListName(3) }
    },
--------
  }, -- ModeSettings
  SelModeWin = {x = 230, y = 2, dy = 24},
-- Labels
  TotalRow = {[1] = "БАНК", [2] = "ИТОГО"},
  HdrLvl = "Лвл",
  HdrName = "Имя",
  HdrClnd = "Календарь",
  HdrMaj = "Мадж",
  HdrGlirion = "Глирион",
  HdrUrgarlag = "Ургарлаг",
  HdrLFGReward = "Фиолетовая награда",
  HdrLFGRnd  = "Подземелье",
  HdrLFGBG   = "Поля сражений",
  HdrLFGTrib = GetString(SI_ACTIVITY_FINDER_CATEGORY_TRIBUTE), -- "Легенды о наградах"
  HdrAvAReward = GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES705),
  SendInvTo = "Отправлено приглашение игроку <<1>>",
  ShareSubstr = {"share","шарь","делись"},
  EndeavorTypeNames = {
    [1] = zo_strformat(SI_TIMED_ACTIVITIES_TYPE_HEADER, "Ежедневные"),   -- "Ежедневные деяния"
    [2] = zo_strformat(SI_TIMED_ACTIVITIES_TYPE_HEADER, "Еженедельные"), -- "Еженедельные деяния"
    [3] = zo_strformat(SI_TIMED_ACTIVITIES_TYPE_HEADER, "Сезонные")      -- "Сезонные деяния"
  },
  EndeavorRepeat = "Повтор",
--[[
SI_TAMRIEL_TOMES_CHALLENGES_COMING_SOON, "Новые деяния скоро появятся"
SI_TIMED_ACTIVITIES_REWARD_HEADER, "Награда"
--]]
  PromoEventName = GetIcon(47, 20, true) ..
                   GetString(SI_ACTIVITY_FINDER_CATEGORY_PROMOTIONAL_EVENTS) .. " : <<1>>", -- "Золотые Стремления"
  NoWorldEventsHere = "Здесь нет мировых событий",
  WECalculating = "Вычисление",
  WEDistance = "Дистанция",
-- Pledge Quest Givers NPC names
  PledgeQGivers = {
    [1] = "Мадж аль-Рагат",
    [2] = "Глирион Рыжебородый",
    [3] = "Ургарлаг Бич Вождей",
  },
-- Shadowy-Supplier NPC name
  ShadowySupplier = {
    ["Хранит-Молчание"] = true,
    ["Remains-Silent"]  = true,
  },
  ComeBackLater = "Возвращайтесь позже",
-- Replace text for long companion equipment names
  CompanionEquipRepl = {
    CompTitle = " спутника",
   --- Trait names replacement ---
    ["Без особенности"]   = {[3] = "нет", [4] = "нет"},
    ["Агрессия"]          = {[4] = "Агрес"},
    ["Сосредоточенность"] = {[3] = "Сосредот.", [4] = "Соср"},
    ["Энергичность"]      = {[3] = "Энергич.", [4] = "Энерг"},
    ["Проворность"]       = {[3] = "Проворн.", [4] = "Пров"},
    ["Жизненная сила"]    = {[3] = "Жизн.сила", [4] = "Жизн"},
    ["Разрушение"]        = {[3] = "Разруш.", [4] = "Разр"},
    ["Расширение"]        = {[3] = "Расшир.", [4] = "Расш"},
    ["Укрепление"]        = {[3] = "Укреплен.", [4] = "Укреп"},
    ["Утешение"]          = {[4] = "Утеш"},
   --- Item names replacement ---
    ["Тяжелый шлем"]      = {[1] = "Тяж.шлем"},
    ["Наплечники"]        = {[1] = "Наплечник"},
    ["Латные перчатки"]   = {[1] = "Лат.перч."},
    ["Головной убор"]     = {[1] = "Гол.убор"},
    ["Огненный посох"]    = {[1] = "Огнен.посох"},
    ["Грозовой посох"]    = {[1] = "Гроз.посох"},
    ["Восстанавливающий посох"] = {[1] = "Восст.посох"},
   --- Item types replacement ---
    [SI_EQUIPTYPE5] = {[2] = "Одноручное", [4] = "1P"}, -- "Одноручное оружие"
    [SI_EQUIPTYPE6] = {[2] = "Двуручное", [4] = "2P"}, -- "Двуручное оружие"
  },
-- Addon Options Menu
--> 1
  OptGeneralHdr = "Общие настройки",
  OptCharsOrder = "Порядок персонажей",
  OptCharsOrderF = "Выбор порядка отображения персонажей в окне аддона. Требуется перезагрузка UI. Персонажи сортируются только при старте аддона и в дальнейшем порядок не изменяется.",
  OptAlwaysMaxWinX = "Фиксированная ширина основного окна",
  OptAlwaysMaxWinXF = "Если включено, то основное окно аддона всегда будет одинаковой ширины для всех режимов.\nЕсли выключено, то окно будет изменять ширину в зависимости от режима.",
  OptLocation = "Локация вместо названия подземелья",
  OptLocationF = "Показывать локацию вместо названия подземелья",
  OptENDungeon = "Названия подземелий на английском", 
  OptENDungeonF = "Показывать названия подземелий на английском", 
  OptDontShowNone  = "Не отображать статус \"нет\"",
  OptDontShowReady = "Не отображать статус \"доступна\"",
  OptTitleToolTip = "Всплывающие описания на заголовках окон",
  OptTitleToolTipF = "Показывать всплывающие описания на заголовках окон",
  OptHintUncomplPlg  = "Обеты в незавершенных подземельях",
  OptHintUncomplPlgF = table.concat( {
                       "Показывать в окне обетов Неустрашимых подсказки о сегодняшних обетах, если эти подземелья еще не завершены.\n",
                       "Подземелье считается незавершенным, если в нём не выполнен сюжетный квест или не убиты все боссы.\n",
                       "(подземелье должно быть доступно/не заблокировано для аккаунта или персонажа)",
                       } ),
  OptLargeCalend  = "Показывать календарь Обетов на...",
  OptLargeCalendF = "Выбор количества дней в календаре Обетов",
  OptDateFrmt  = "Формат отображения даты",
  OptDateFrmtF = "Выбор формата отображения даты в окне календаря",
  OptShowTime  = "Также после даты отображать время",
  OptLFGRndAvl  = "Формат краткосрочных периодов времени",
  OptLFGRndAvlF = "Выбор формата отображения краткосрочных периодов времени (менее 24 часов), таких как ежедневная награда за случайную деятельность, Теневой Поставщик, навык верховой езды и т.д.",
  OptTrialAvl  = "Формат долгосрочных периодов времени",
  OptTrialAvlF = "Выбор формата отображения долгосрочных периодов времени (более 24 часов), таких как еженедельная награда за Триалы и т.д.",
  OptTimerList = {"осталось времени","дата и время (ММ/ДД чч:ми)","дата и время (ДД.ММ чч:ми)"},
  OptRndDungDelay = "Период ожидания награды",
  OptRndDungDelayF = "Задержка (в секундах) перед определением смены награды за случайное подземелье после убийства последнего босса. Изменяйте эту настройку только, если у вас аддон не определяет прохождение случайного подземелья, и после перезахода персонажа отображается статус \"???\".",
  OptShowMonsterSetTT = "Показывать подсказку для Монстр Сетов",
  OptShowMonsterSetTTF = "Показывать подсказку о получаемом с последнего босса Монстр Сете при наведении курсора мыши на строку Обета в окнах \"Обеты Неустрашимых\" и \"Календарь Обетов\"",
  OptMouseModeUI = "Показывать указатель мыши",
  OptMouseModeUIF = "Показывать указатель мыши при открытом окне аддона",
  OptCharNamesMenu = "Имена персонажей",
  OptCharNameColor = "Имя в цвете Альянса",
  OptCharNameAlign = "Выравнивание имен",
  OptNamesAlignList = {"по левому краю", "по центру", "по правому краю"},
  OptCorrLongNames = "Исправлять отображение длинных имен",
  OptNamesCorrList = {"ничего не делать", "размером шрифта", "удален. середины", "текстовой маской"},
  OptNamesCorrRepl = {"Найти этот текст в имени", "и заменить на этот текст"},
  OptCurrencyValThres = "Округлять числа валюты до...",
  OptCurrencyValThresF = table.concat(
                         { "До каких чисел округлять значения валюты.\n",
                           GetString(SI_GAMEPAD_CURRENCY_SELECTOR_HUNDREDS_NARRATION),      " : 123 K\n",
                           GetString(SI_GAMEPAD_CURRENCY_SELECTOR_THOUSANDS_NARRATION),     " : 1234 K\n",
                           GetString(SI_GAMEPAD_CURRENCY_SELECTOR_TEN_THOUSANDS_NARRATION), " : 12345 K"
                         } ),
  OptDynEncounterNotify = zo_strformat("<<1>>: <<2>>", DynamicEncounterText, GetString(SI_MAIN_MENU_NOTIFICATIONS)), -- "Уведомления"
  OptDynEncounterNotifyF = table.concat(
                           { "Уведомлять на экране и в чате о начале, активности, завершении и прогрессе случайных событий.\n\n",
                           -- GetString(SI_ACTIONBARSETTINGCHOICE0), " - не показывать уведомления событий.\n",
                           -- GetString(SI_ACTIONBARSETTINGCHOICE1), " - всегда показывать уведомления событий.\n",
                             GetString(SI_ACTIONBARSETTINGCHOICE2), " - скрывать уведомления, пока персонаж ",
                             "принимает участие в событии, иначе показывать уведомления события."
                           } ),
  OptCompanionRapport = "Показывать отношение спутников как...",
  OptCompanionRprtList = {"число", "текст"},
  OptCompanionRprtMax = "Показывать максимальное значение",
  OptCompanionEquip = "Показывать экипировку спутников как...",
  OptCompanionEquipList = {"название", "тип предмета", "особенность", "тип и особенность"},
--> 2
  OptModeSetHdr = "Настройки опций и режимов",
  OptAutoActionsHdr = "Автоматизация ежедневных действий",
  OptAutoTakeUpPledges = "Автоматически принимать Обеты",
  OptAutoTakeUpPledgesF = "Автоматически принимать Обеты во время разговоров с Неустрашимыми",
  OptAutoTakeDBSupplies = "Автомат. получать припасы Темн.Братства",
  OptAutoTakeDBSuppliesF = "Автоматически получать полезные предметы (припасы) во время разговора с Теневым Поставщиком",
  OptAutoTakeDBList = {"весь аккаунт", "зависит от персонажа"},
  OptChoiceDBSupplies = "Какой тип припасов получать...",
  OptDBSuppliesList = {"ничего не делать", "яды / зелья", "меньше внимания", "снаряжение"},
  OptAutoChargeWeapon = "Автоматически заряжать оружие",
  OptAutoChargeWeaponF = "Автоматически заряжать оружие, когда его заряд меньше минимального порога.\n" ..
                         "В инвентаре персонажа должен быть хотя бы 1 заполненный камень душ.",
--SI_DEFAULTSOULGEMCHOICE0 "|t16:16:EsoUI/Art/ currency/currency_gold .dds|t За золото"
--SI_DEFAULTSOULGEMCHOICE1 "|t16:16:EsoUI/Art/ currency/currency_crown .dds|t За кроны"
  OptAutoChargeThreshold = "Минимальный порог заряда",
  OptAutoChargeThresholdF = "Оружие будет заряжено, когда оставшийся заряд зачарования будет меньше этого значения",
  OptAutoCallEyeInfinite = "Автомат. призывать " .. GetCollectibleName(WPamA.EndlessDungeons.EyeOfInfinite.C),
  OptAutoCallEyeInfiniteF = table.concat(
                            { "Автоматически призывать |t20:20:",
                              GetCollectibleIcon(WPamA.EndlessDungeons.EyeOfInfinite.C), "|t",
                              GetCollectibleName(WPamA.EndlessDungeons.EyeOfInfinite.C),
                              " в зонах Бесконечного Архива.\n\nЭта опция доступна, когда этот инструмент доступен на аккаунте."
                            } ),
  ---
--  OptEndeavorRewardMode = "Показывать награду за деяния как...",
--  OptEndeavorRewardList = {"одиночную", "текущую", "максимальную"},
  OptEndeavorChatMsg  = "Показывать прогресс деяний в чате",
  OptEndeavorChatMsgF = "Показывать в окне чата информацию при изменении прогресса деяний",
  OptEndeavorChatChnl = "Канал чата для сообщений о прогрессе",
  OptEndeavorChatChnlF = "В каком канале чата показывать информацию о прогрессе деяний",
  OptEndeavorChatColor = "Цвет сообщений о прогрессе",
  OptEndeavorChatColorF = "Настройка цвета сообщений о прогрессе",
  OptEndeavorAutoClaim = "Автоматически получать награды деяний",
  OptEndeavorHideCompl = "Скрывать завершенные деяния",
  OptPursuitChatMsg  = "Показывать прогресс стремлений в чате",
  OptPursuitChatMsgF = "Показывать в окне чата информацию при изменении прогресса Золотых Стремлений",
  OptPursuitChatCamp  = "Пока не получена награда кампании",
  OptPursuitChatCampF = "Если включено, показывать прогресс стремлений, пока еще не получена награда кампании.\nЕсли выключено, всегда показывать прогресс стремлений.",
--  OptPursuitChatChnl = "Канал чата для сообщений о прогрессе",
  OptPursuitChatChnlF = "В каком канале чата показывать информацию о прогрессе Золотых Стремлений",
  OptPursuitAutoClaim = "Автоматически получать награды стремлений",
  ---
  OptLFGPHdr = "Поиск группы для Обетов (GFP)",
  OptLFGPOnOff = "Разрешить использовать GFP",
  OptLFGPMode = "Также установить режим группы...",
  OptLFGPModeList = {zo_strformat("всегда <<1>><<1>><<1>> (<<2>>)", Icon.Norm, Icon.LfgpKeys[1]), -- NNN
                     zo_strformat("всегда <<1>><<1>><<2>> (<<3>>)", Icon.Vet, Icon.Minus, Icon.LfgpKeys[2]), -- VV-
                     zo_strformat("всегда <<1>><<1>><<2>> (<<3>>)", Icon.Vet, Icon.Norm, Icon.LfgpKeys[3]), -- VVN
                     zo_strformat("всегда <<1>><<1>><<1>> (<<2>>)", Icon.Vet, Icon.LfgpKeys[4]), -- VVV
                     "зависит от персонажа"},
  OptLFGPIgnPledge = "Игнорировать галку \"Обет выполнен\"",
  OptLFGPAlert = "Выводить сообщения на экран",
  OptLFGPChat = "Выводить сообщения в чат",
  OptLFGPModeRoult = zo_strformat("Искать <<1>>/<<2>> для устаревших Обетов", Icon.Vet, Icon.Norm),
  OptLFGPModeRoultF = table.concat(
                      { "В случае, когда установлен ветеранский режим поиска группы, ",
                        "и у персонажа есть квест на устаревший (не сегодняшний) Обет, ",
                        "эта настройка позволяет дополнительно искать группу для нормального режима.\n\n",
                        "Если включено, искать группу для любого (", Icon.Vet, " или ", Icon.Norm,
                        ") режима - ", Icon.Roult, ".\n",
                        "Если выключено, искать группу только для ", Icon.Vet, " режима."
                      } ),
--> 3
  OptRGLAHdr = "Настройки RGLA",
  OptRGLAQAutoShare = "Разрешить авто-расшаривание квеста",
  OptRGLAQAlert = "Уведомлять на экране",
  OptRGLAQChat = "Уведомлять в чат",
  OptRGLABossKilled = "Остановить RGLA когда босс убит",
--> 4
  CharsOnOffHdr = "Настройка показа / сокрытия персонажей",
  CharsOnOffNote = "Внимание! Эти настройки не влияют на показ текущего персонажа. Информация о текущем персонаже всегда будет показана во всех режимах.",
  OptCharOnOffTtip = "Показать / Скрыть персонажа \"<<1>>\"",
--> 5
  ModesOnOffHdr = "Настройка показа / сокрытия режимов",
  ModesOnOffNote = "Внимание! Эти настройки влияют только на последовательное переключение режимов. Можно скрыть любые режимы, но хотя бы один (любой) режим будет оставаться не скрытым. Также можно выбрать нужный режим в контекстном меню.",
  OptWindOnOffTtip = "Показать / Скрыть окно \n\"<<1>>\"",
  OptModeOnOffTtip = "Показать / Скрыть режим \n\"<<1>>\"",
--> 6
  CustomModeKbdHdr  = "Настройка кнопок вызова режимов",
  CustomModeKbdNote = "Внимание! Эти настройки действуют на весь аккаунт.\nНастройка кнопок вызова режимов позволяет назначать кнопки для вызова режимов по выбору игрока.",
  OptCustomModeKbd  = GetString(SI_COLLECTIBLECATEGORYTYPE29) .. " <<1>> ...", -- "Настраиваемое действие"
--> 7
--  ResetCharNote = "",
  ResetChar = "Очистить персонажей",
  ResetCharF = "Очистить весь список персонажей",
  ResetCharWarn = "Вся информация о персонажах будет удалена! Вы уверены?",
-- LFGP texts
  LFGPSrchCanceled = "Поиск группы отменен",
  LFGPSrchStarted  = "Начат поиск группы",
  LFGPAlrdyStarted = "Уже начата другая активность",
  LFGPQueueFailed  = "Не удалось встать в очередь поиска",
  LFGP_ErrLeader   = "Нужно быть лидером группы!",
  LFGP_ErrOverland = "Нужно быть вне подземелья!",
  LFGP_ErrGroupRole= "Установите свою роль в группе!",
-- RGLA texts
  RGLABossKilled = "Босс убит. RGLA остановлен.",
  RGLALeaderChanged = "Изменился лидер группы. RGLA остановлен.",
  RGLAShare = "Расшар.",
  RGLAStop = "Стоп",
  RGLAPost = "В чат",
  RGLAStart = "Пуск",
  RGLAStarted = "Запущен",
  RGLALangTxt = "На русском в",
-- RGLA Errors
  RGLA_ErrLeader = "Вы сейчас не лидер группы!",
  RGLA_ErrAI = "Аддон AutoInvite не установлен или не включен!",
  RGLA_ErrBoss = "Босс уже был убит. Запуск RGLA невозможен.",
  RGLA_ErrQuestBeg = "Не взят ежедневный квест на боссов локации ",
  RGLA_ErrQuestEnd = "!",
  RGLA_ErrLocBeg = "Вы сейчас не в локации ", 
  RGLA_ErrLocEnd = "!", 
  RGLA_Loc = {
    [ 0] = "Ротгар",
    [ 1] = "Варденфелл",
    [ 2] = "Золотой берег",
    [ 3] = "Саммерсет",
    [ 4] = "Северный Эльсвейр",
    [ 5] = "Западный Скайрим",
    [ 6] = "Пещеры Греймура",
    [ 7] = "Черный Лес",
    [ 8] = "Высокий Остров",
    [ 9] = "Полуостров Тельвани",
    [10] = "Апокриф",
    [11] = "Солстис",
  },
-- Dungeons Status
  DungStDone = "ВЫП.",
  DungStNA = "Н/Д",
-- Wrothgar Boss Status
  WWBStNone = "нет",
  WWBStDone = "ВЫП.",
  WWBStCur  = "ТЕК.",
-- Trials Status
  TrialStNone = "нет",
  TrialStActv = "АКТ.",
-- LFG Random Dungeon Status
  LFGRewardReady = "Доступна",
  LFGRewardNA = "Н/Д",
-- Shadowy Supplier
  ShSuplUnkn = "?",
  ShSuplReady = "Доступен",
  ShSuplNA = "Н/Д",
-- Login Status
  LoginToday = "Сегодня",
  Login1DayAgo = "Вчера",
-- Dynamic Encounter Status
  DynamicEncounter = {
    Icon  = GetIcon(73, 20),
    Title = DynamicEncounterText,
    Start = "началось событие",
    Stop  = "событие завершено",
    Activ = "событие активно",
    Progr = table.concat({ GetString(SI_ENDLESS_DUNGEON_SUMMARY_PROGRESS_HEADER), -- "Прогресс"
            " ", GetString(SI_SPECTACLE_EVENTS_PROGRESS_PERCENT) }) -- "<<1>>%"
  },
--
}
WPamA.i18n.ToolTip = {
  [-1] = "",
  [ 0] = Icon.LMB .. " Закрыть окно",
  [ 1] = Icon.LMB .. " Настройки",
  [ 2] = Icon.LMB .. " Смена окна\n" .. Icon.RMB .. " Выбор окна",
  [ 3] = table.concat({ "Сегодняшний Обет в чат\n", Icon.LMB, " На английском\n", Icon.RMB, " На русском" }),
  [ 4] = "Выполнение Обетов по каждому персонажу",
  [ 5] = "Календарь Обетов на ближайшие 7 дней",
  [ 6] = "Выполнение ежедневных квестов по каждому персонажу",
  [ 7] = "Ключи Неустрашимых, отмычки, камни душ и прочее...",
  [ 8] = "Ваши персонажи просвещены",
  [ 9] = "Ваши персонажи не просвещены",
  [10] = table.concat({ "Поиск группы для Обетов\n", Icon.LMB, " ", WPamA.i18n.KeyBindLFGP, "\n", Icon.RMB, " ", WPamA.i18n.KeyBindLFGPMode }),
  [11] = "Кристаллы трансмутации",
--
  [12] = "Прогресс в общих навыках",
  [13] = GetString(SI_STABLE_STABLES_TAB),
  [14] = GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKCATEGORIES1),
  [15] = "Сезонные фестивали",
  [16] = "Прогресс в гильдейских навыках",
  [17] = "Прогресс в классовых и альянсовых навыках",
  [18] = "Прогресс в ремесленных навыках",
  [19] = "Доступность еженедельной награды за прохождение триалов",
  [20] = "Доступность расширенной (фиолетовой) награды раз в день за Случайное Подземелье и Поля сражений",
-- WB Wrothgar
  [21] = "Незаконченный дольмен\n - Зандадуноз Перерожденная",
  [22] = "Водопад Низчалефт\n - Двемерский центурион Низчалефт",
  [23] = "Трон короля-вождя\n - Король-вождь Эду",
  [24] = "Алтарь Безумного огра\n - Безумный Урказбур",
  [25] = "Лагерная стоянка браконьеров\n - Старая Снагара",
  [26] = "Проклятый питомник\n - Коринттак Омерзительный",
--
  [27] = "Осталось до получения Достижения",
  [28] = "Активный эффект (бонус), увеличивающий количество получаемых Очков Альянса",
  [29] = table.concat({ "Поиск группы для Обетов\n",
         Icon.Minus, " - GFP не включен в настройках аддона\n",
         GetIcon(62,18), " - возможное количество ключей (с ХМ)\n",
         Icon.Norm, "/", Icon.Vet, "/", Icon.Roult, " - режим поиска группы (перед названием подземелья)" }),
  [30] = "Доступна ли ежедневная награда",
-- 31-39 Class skills + Guild skills
  [31] = "Классовые навыки: 1-я линейка",
  [32] = "Классовые навыки: 2-я линейка",
  [33] = "Классовые навыки: 3-я линейка",
  [34] = "Гильдия бойцов",
  [35] = "Гильдия магов",
  [36] = "Неустрашимые",
  [37] = "Гильдия воров",
  [38] = "Темное Братство",
  [39] = "Орден Псиджиков",
-- 40 ???
-- 41-47 Craft skills
-- 48-50 AvA skills
  [51] = "Цитадель Хель Ра",
  [52] = "Этерианский архив",
  [53] = "Святилище Офидии",
  [54] = "Святилище Пасти Лорхаджа",
  [55] = "Залы Фабрикации",
  [56] = "Изоляционный санктуарий",
  [57] = "Клаудрест",
  [58] = "Солнечный шпиль",
  [59] = "Эгида Кин",
--
  [60] = GetString(SI_LEVEL_UP_REWARDS_SKILL_POINT_TOOLTIP_HEADER),
  [61] = "Золото",
  [62] = "Ваучеры заказов",
  [63] = "Очки альянса",
  [64] = "Камни Тель-Вар",
--65-70 Item name
-- WB Vvardenfell
  [71] = "Яичная шахта Миссир-Дадалит\n - Супруг королевы",
  [72] = "Совет Салотана\n - Салотан",
  [73] = "Лощина Нилтога\n - Нилтог Несокрушимый",
  [74] = "Ферма Сулипунд\n - Вуйувус",
  [75] = "Башня Дабдил Алара\n - Меца Обманщик",
  [76] = "Бухта Кораблекрушений\n - Кимбрудил Певунья",
-- WB Gold Coast
  [77] = "Арена Кватча",
  [78] = "Каприз Трибуна\n - Лименаурус",
-- 79-80 ??? резерв для двух боссов Причала Абы / Хьюбана
-- WB Summerset
  [81] = "Питомник королевы\n - Королева Рифа",
  [82] = "Гнездо Килелома\n - Килелом",
  [83] = "Индриково раздолье\n - Канерин",
  [84] = "Бухта Веленкина\n - Б'Корген",
  [85] = "Укрытие Гравельда\n - Гравельд",
  [86] = "Ручей грифона\n - Хейлиата и Награвия",
-- Inventory
  [87] = "Информация о заполнении инвентаря",
  [88] = "Всего мест в инвентаре",
  [89] = "Занято мест в инвентаре",
  [90] = "Свободно мест в инвентаре",
-- WB Northern Elsweyr
  [91] = "Костяная яма\n - На'руз Заклинатель Костей",
  [92] = "Край Шрама\n - Таннар Грабитель Могил",
  [93] = "Ручей Красных Рук\n - Зав'и и Акумджарго",
  [94] = "Холм Сломанных Мечей\n - Мастера меча Визрада",
  [95] = "Ущелье Когтя\n - Ки'ва Коварная",
  [96] = "Плато Кошмаров\n - Залшим",
-- Inventory Upgrades
  [97] = GetString(SI_INTERACT_OPTION_BUY_BAG_SPACE), -- Купить улучшение рюкзака
       -- 98 = Повышение навыка верховой езды - Переносимый вес
  [98] = GetString(SI_GAMEPAD_STABLE_TRAIN) .. " - " .. GetString(SI_RIDINGTRAINTYPE2),
       -- 99 = Небоевой питомец - Инвентарь
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
  [107] = "Теневой поставщик",
  [108] = "Таймер Теневого Поставщика",
  [109] = "Отношения со спутниками",
  [110] = GetString(SI_STAT_GAMEPAD_CHAMPION_POINTS_LABEL),
  [111] = GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES212), -- "Ремесленные заказы"
-- World Events
  [112] = "", -- строка переписывается в процессе
  [113] = "", -- строка переписывается в процессе
  [114] = "", -- строка переписывается в процессе
  [115] = table.concat({
          GetIcon(14, 24), "- Сколько времени прошло с момента обнаружения активного события.\n",
          GetIcon(13, 28), "- Сколько времени прошло с момента завершения события." }),
  [116] = "Сколько времени событие было активно.\n(как долго игроки закрывали событие)",
  [117] = "Предполагаемое время до активации мирового события.\n" ..
          "Необходимо как минимум 2 завершенных события для вычисления времени.\n" ..
          "Чем больше событий будет завершено, тем точнее будет вычисление времени.",
  [118] = "HP % - Уровень здоровья босса события.\n" ..
          GetIcon(13, 28) .. "- Сколько времени прошло с момента завершения события.",
  [119] = "Дистанция в метрах до босса события.\nАктуальная информация о боссе может быть получена только ближе 300 метров от босса.",
  [120] = "Предполагаемое время до активации мирового события.\nЗависит от количества и активности игроков в локации.",
-- WB Western Skyrim
  [121] = "Побережье Исмгара\n - Морской великан",
  [122] = "Охотничьи угодья Хордрека\n - Охотничий отряд вервольфов",
  [123] = "Круг героев",
  [124] = "Убежище Матери Тьмы\n - Мать Тьмы",
-- WB Blackreach: Greymoor Caverns
  [125] = "Места пиршеств вампиров\n - Места кормления",
  [126] = "Зарядная станция колосса\n - Двемерский колосс",
-- 127-130 ???
--131-136 World skills
-- 137-157 ???
-- Endless Dungeon progress
  [158] = table.concat({ "Ежедневное задание\n",
          Icon.Lock, " - не завершено ознакомительное задание\n",
          Icon.Quest, " - задание доступно\n",
          Icon.ChkM, " - задание завершено" }),
  [159] = "Лучший достигнутый прогресс\n(за все прохождения подземелья при активном аддоне)",
--160-190 Item name
-- Trials
  [191] = "Каменная Роща",
  [192] = "Риф Зловещих Парусов",
  [193] = "Грань Безумия",
  [194] = "Цитадель Люцентов",
  [195] = "Костяная Клетка",
-- 196-200 ??? резерв для новых Триалов
-- WB Blackwood
  [201] = "Пруд Старого Смертожаба\n - Старый Смертожаб",
  [202] = "Лагуна Зимхока\n - Зимхок Собиратель Трофеев",
  [203] = "Ритуальный круг сул-зан\n - Яксат Смертоносный, Нукуджима, Шув-Мок, Болотный мистик Виша",
  [204] = "Разрушенный занмир\n - Гемвас Предвестник",
  [205] = "Раскопки Шардия\n - Брум",
  [206] = "Военный лагерь племени Жабьего Языка\n - Вождь Затмоз",
-- Crafting Writs
  [207] = GetQuestName(WPamA.DailyWrits.QuestIDs[1][1]),
  [208] = GetQuestName(WPamA.DailyWrits.QuestIDs[2][1]),
  [209] = GetQuestName(WPamA.DailyWrits.QuestIDs[3][1]),
  [210] = GetQuestName(WPamA.DailyWrits.QuestIDs[4][1]),
  [211] = GetQuestName(WPamA.DailyWrits.QuestIDs[5][1]),
  [212] = GetQuestName(WPamA.DailyWrits.QuestIDs[6][1]),
  [213] = GetQuestName(WPamA.DailyWrits.QuestIDs[7][1]),
--214-226 Companion Skills
  [214] = "Классовые навыки",
  [215] = "", -- строка переписывается в процессе
  [216] = "", -- строка переписывается в процессе
  [217] = "", -- строка переписывается в процессе
  [218] = GetString(SI_EQUIPMENTFILTERTYPE1), -- "Легкие доспехи"
  [219] = GetString(SI_EQUIPMENTFILTERTYPE2), -- "Средние доспехи"
  [220] = GetString(SI_EQUIPMENTFILTERTYPE3), -- "Тяжелые доспехи"
  [221] = GetString(SI_WEAPONCONFIGTYPE3),    -- "Двуручное оружие"
  [222] = GetString(SI_WEAPONCONFIGTYPE1),    -- "Одноручное оружие и щит"
  [223] = GetString(SI_WEAPONCONFIGTYPE2),    -- "Парное оружие"
  [224] = GetString(SI_WEAPONCONFIGTYPE4),    -- "Лук"
  [225] = GetString(SI_WEAPONCONFIGTYPE5),    -- "Посох разрушения"
  [226] = GetString(SI_WEAPONCONFIGTYPE6),    -- "Посох восстановления"
--227-240 Companion & Character Equips
  [227] = GetString(SI_EQUIPSLOT0),  -- "Головной убор"
  [228] = GetString(SI_EQUIPSLOT3),  -- "Наплечники"
  [229] = GetString(SI_EQUIPSLOT2),  -- "Нагрудник"
  [230] = GetString(SI_EQUIPSLOT16), -- "Перчатки"
  [231] = GetString(SI_EQUIPSLOT6),  -- "Пояс"
  [232] = GetString(SI_EQUIPSLOT8),  -- "Поножи"
  [233] = GetString(SI_EQUIPSLOT9),  -- "Обувь"
  [234] = GetString(SI_EQUIPSLOT4),  -- "Правая рука"
  [235] = GetString(SI_EQUIPSLOT5),  -- "Левая рука"
  [236] = GetString(SI_EQUIPSLOT1),  -- "Шея"
  [237] = GetString(SI_EQUIPSLOT11), -- "Кольцо 1"
  [238] = GetString(SI_EQUIPSLOT12), -- "Кольцо 2"
  [239] = GetString(SI_EQUIPSLOT20), -- "Правая рука (доп.)"
  [240] = GetString(SI_EQUIPSLOT21), -- "Левая рука (доп.)"
----SI_EQUIPSLOT7, "Запястье"
-- WB High Isle
  [241] = "Змеиное болото\n - Призывательница змей Винша",
  [242] = "Котел И'ффре\n - Мрачный Рыцарь",
  [243] = "Расщелина Темного Камня\n - Палач Расцвета, Мучительница Расцвета",
  [244] = "Водопад фавнов\n - Глемиос Дикий Рог",
  [245] = "Озеро Аменоса\n - Теург Скерард, Теург Розара",
  [246] = "Водопад Морнар\n - Хадолид-матрона, Хадолид-самец",
--247-249 Books Category (Init by WPamA:InitLoreBookMode)
-- Hireling mail and crafting profession certification
  [250] = table.concat({ "\n", Icon.Mail, " - Доступна почта от наемника (нужно войти в игру или сменить локацию)",
                         "\n", Icon.NoCert, " - Не получен ремесленный сертификат" }),
-- WB Necrom
  [251] = "Кошмарное логово\n - Ходячий Кошмар",
  [252] = "Громозвучная котловина\n - Корлис Поработитель",
  [253] = "Бездонное болото\n - Вро-Кул-Ша",
  [254] = "Хтоническая площадь\n - Валкиназ Дек",
  [255] = "Собор Либрам\n - Главный Библиотекарь",
  [256] = "Акрополь повелителя рун\n - Повелитель рун Зиомар",
--257-260 ???
-- WB Gold Road
  [261] = "Осенняя поляна\n - Сказитель Уртрендир",
  [262] = "Пещера Разбитый Путь\n - Стри Пожиратель Судеб",
  [263] = "Холм Центуриона\n - Клык, Коготь",
  [264] = "Утес Фортуны\n - Хесседаз Зловещий",
  [265] = "Исток Границы\n - Предводители Стражей Памяти",
  [266] = "Озеро Оло\n - Дубовый Коготь",
-- WB Solstice
  [267] = "Омытый пляж\n - Злоба Прилива",
  [268] = "Руины Тунирии\n - Голм",
  [269] = "Святилище Ваккан\n - Воскроны-стражи",
  [270] = "Обиталище Призывательницы Душ\n - Призывательница Душ",
  [271] = "Логово Во-Зита\n - Во-Зит",
  [272] = "Место для ритуала в Зив-Элеке\n - Гишзор",
--273-280 Item name
}
--
WPamA.i18n.ToolTip[215] = WPamA.i18n.ToolTip[34]
WPamA.i18n.ToolTip[216] = WPamA.i18n.ToolTip[35]
WPamA.i18n.ToolTip[217] = WPamA.i18n.ToolTip[36]
--
WPamA.i18n.RGLAMsg = {
  [1] = "Z: LFM ...",
  [2] = "Z: LFM короткая",
  [3] = "Z: Старт через 1 мин",
  [4] = "G: Старт через 1 мин",
  [5] = "G: СТАРТ",
  [6] = "Z: Босс убит",
  [7] = "G: Квест уже делался",
  [8] = "Об аддоне",
}
-- In Dungeons structure:
-- Q - Quest name which indicates the dungeon
-- N - Short name of the dungeon displayed by the addon
WPamA.i18n.Dungeons = {
-- Virtual dungeon
  [1] = { -- None
    N = "нет",
  },
  [2] = { -- Unknown
    N = "Неизвестно",
  },
-- First location dungeons
  [3] = { -- AD, Auridon, Banished Cells I
    N = "Темницы изгнан. I",
  },
  [4] = { -- EP, Stonefalls, Fungal Grotto I
    N = "Грибной грот I",
  },
  [5] = { -- DC, Glenumbra, Spindleclutch I
    N = "Логово мертв.хват I",
  },
  [6] = { -- AD, Auridon, Banished Cells II
    N = "Темницы изгнан. II",
  },
  [7] = { -- EP, Stonefalls, Fungal Grotto II
    N = "Грибной грот II",
  },
  [8] = { -- DC, Glenumbra, Spindleclutch II
    N = "Логово мертв.хват II",
  },
-- Second location dungeons
  [9] = { -- AD, Grahtwood, Elden Hollow I
    N = "Элден. расщел. I",
  },
  [10] = { -- EP, Deshaan, Darkshade Caverns I
    N = "Глубокая тень I",
  },
  [11] = { -- DC, Stormhaven, Wayrest Sewers I
    N = "Канализ. Вэйреста I",
  },
  [12] = { -- AD, Grahtwood, Elden Hollow II
    N = "Элден. расщел. II",
  },
  [13] = { -- EP, Deshaan, Darkshade Caverns II
    N = "Глубокая тень II",
  },
  [14] = { -- DC, Stormhaven, Wayrest Sewers II
    N = "Канализ. Вэйреста II",
  },
-- 3 location dungeons
  [15] = { -- AD, Greenshade, City of Ash I
    N = "Город Пепла I",
  },
  [16] = { -- EP, Shadowfen, Arx Corinium
    N = "Аркс-Кориниум",
  },
  [17] = { -- DC, Rivenspire, Crypt of Hearts I
    N = "Крипта Сердец I",
  },
  [18] = { -- AD, Greenshade, City of Ash II
    N = "Город Пепла II",
  },
  [19] = { -- DC, Rivenspire, Crypt of Hearts II
    N = "Крипта Сердец II",
  },
-- 4 location dungeons
  [20] = { -- AD, Malabal Tor, Tempest Island
    N = "Остров Бурь",
  },
  [21] = { -- EP, Eastmarch, Direfrost Keep
    N = "Кр.Лютых Морозов",
  },
  [22] = { -- DC, Alik`r Desert, Volenfell
    N = "Воленфелл",
  },
-- 5 location dungeons
  [23] = { -- AD, Reaper`s March, Selene`s Web
    N = "Паутина Селены",
  },
  [24] = { -- EP, The Rift, Blessed Crucible
    N = "Священ. горнило",
  },
  [25] = { -- DC, Bangkorai, Blackheart Haven 
    N = "Черное Сердце",
  },
-- 6 location dungeons
  [26] = { -- Any, Coldharbour, Vaults of Madness
    N = "Своды Безумия",
  },
-- 7 location dungeons
  [27] = { -- Any, Imperial City, IC Prison
    N = "Тюрьма Имп.Города",
  },
  [28] = { -- Any, Imperial City, WG Tower
    N = "Башня Бел.Золота",
  },
-- Shadows of the Hist DLC dungeons
  [29] = { -- Any, Shadowfen, Ruins of Mazzatun
    N = "Руины Маззатуна",
  },
  [30] = { -- Any, Shadowfen, Cradle of Shadows
    N = "Колыбель Теней",
  },
-- Horns of the Reach DLC dungeons
  [31] = { -- Any, Craglorn, Bloodroot Forge
    N = "Кузница Кров.корня",
  },
  [32] = { -- Any, Craglorn, Falkreath Hold
    N = "Владение Фолкрит",
  },
-- Dragon Bones DLC dungeons
  [33] = { -- DC, Bangkorai, Fang Lair
    N = "Логово Клыка",
  },
  [34] = { -- DC, Stormhaven, Scalecaller Peak
    N = "Пик Воспев.Дракона",
  },
-- Wolfhunter DLC dungeons
  [35] = { -- AD, Reaper`s March, Moon Hunter Keep
    N = "Крепость Лун.Охотн.",
  },
  [36] = { -- AD, Greenshade, March of Sacrifices
    N = "Путь Жертвопринош.",
  },
-- Wrathstone DLC dungeons
  [37] = { -- EP, Eastmarch, Frostvault
    N = "Морозное хранилище",
  },
  [38] = { -- Any, Gold Coast, Depths of Malatar
    N = "Глубины Малатара",
  },
-- Scalebreaker DLC dungeons
  [39] = { -- Any, Elsweyr, Moongrave Fane
    N = "Храм Погребен.Лун",
  },
  [40] = { -- AD, Grahtwood, Lair of Maarselok
    N = "Логово Марселока",
  },
-- Harrowstorm DLC dungeons
  [41] = { -- Any, Wrothgar, Icereach
    N = "Ледяной Предел",
  },
  [42] = { -- DC, Bangkorai, Unhallowed Grave
    N = "Нечестивая Могила",
  },
-- Stonethorn DLC dungeons
  [43] = { -- Any, Blackreach, Stone Garden
    N = "Каменный Сад",
  },
  [44] = { -- Any, Western Skyrim, Castle Thorn
    N = "Замок Шипов",
  },
-- Flames of Ambition DLC dungeons
  [45] = { -- Any, Gold Coast, Black Drake Villa
    N = "Вилла Черн.Змея",
  },
  [46] = { -- EP, Deshaan, The Cauldron
    N = "Котел",
  },
-- Waking Flame DLC dungeons
  [47] = { -- DC, Glenumbra, Red Petal Bastion
    N = "Оплот Алый Лепесток",
  },
  [48] = { -- Any, Blackwood, The Dread Cellar
    N = "Ужасный Подвал",
  },
-- Ascending Tide DLC dungeons
  [49] = { -- Any, Summerset, Coral Aerie
    N = "Коралловое Гнездо",
  },
  [50] = { -- DC, Rivenspire, Shipwright's Regret
    N = "Горе Корабела",
  },
-- Lost Depths DLC dungeons
  [51] = { -- Any, High Isle, Earthen Root Enclave
    N = "Анклав Землян.Корня",
  },
  [52] = { -- Any, High Isle, Graven Deep
    N = "Могильная Пучина",
  },
-- Scribes of Fate DLC dungeons
  [53] = { -- EP -> Stonefalls - Bal Sunnar
    N = "Бал-Суннар",
  },
  [54] = { -- EP -> The Rift - Scrivener's Hall
    N = "Зал Книжников",
  },
-- Scions of Ithelia DLC dungeons
  [55] = { -- Any -> The Reach - Oathsworn Pit
    N = "Храм Верных Клятве",
  },
  [56] = { -- Any -> Wrothgar - Bedlam Veil
    N = "Завеса Хаоса",
  },
-- Fallen Banners DLC dungeons
  [57] = { -- Any -> The Gold Road - Exiled Redoubt
    N = "Оплот Изгнания",
  },
  [58] = { -- Any -> Hew's Bane - Lep Seclusa
    N = "Леп-Секлуза",
  },
-- Feast of Shadows DLC dungeons
  [59] = { -- Any -> Solstice - Naj-Caldeesh
    N = "Надж-Калдиш",
  },
  [60] = { -- Any -> Solstice - Black Gem Foundry
    N = "Литейная Черн.Камня",
  },
} -- Dungeons end
WPamA.i18n.DailyBoss = {
-- Wrothgar
  [1]  = {C = "Победить Зандадуноза Возрожденного"}, -- ZANDA
  [2]  = {C = "Победить Низчалефта"}, -- NYZ
  [3]  = {C = "Победить короля-вождя Эду"}, -- EDU
  [4]  = {C = "Победить Безумного Урказбура"}, -- OGRE
  [5]  = {C = "Остановить браконьеров"}, -- POA
  [6]  = {C = "Победить Коринтака Омерзительного"}, -- CORI
-- Vvardenfell
  [7]  = {C = "Победить супруга матки"}, -- QUEEN
  [8]  = {C = "Одолеть оратора Салотан"}, -- SAL
  [9]  = {C = "Победить Нилтога Несокрушимого"}, -- NIL
  [10] = {C = "Одолеть Вуйювуса"}, -- WUY
  [11] = {C = "Остановить эксперимент, который начал Дабдил Алар"}, -- DUB
  [12] = {C = "Победить Кимбрудил Певунью"}, -- SIREN
-- Gold Coast
  [13] = {C = "Победите на арене Кватча"}, -- ARENA
  [14] = {C = "Очистить место раскопок"}, -- MINO
-- Summerset
  [15] = {C = "Убить Королеву Рифа"}, -- QUEEN
  [16] = {C = "Убить Килелома"}, -- KEEL
  [17] = {C = "Убить Канерин"}, -- CAAN
  [18] = {C = "Убить Б'Коргена"}, -- KORG
  [19] = {C = "Убить Гравельда"}, -- GRAV
  [20] = {C = "Убить Хейлиату и Награвию"}, -- GRYPH
-- Northern Elsweyr
  [21] = {C = "Убить На'руза Заклинателя Костей"}, -- NARUZ
  [22] = {C = "Убить Таннара Грабителя Могил"}, -- THAN
  [23] = {C = "Убить Акумджарго и Зав'и"}, -- ZAVI
  [24] = {C = "Убить мастера меча Визраду"}, -- VHYS
  [25] = {C = "Убить Ки'ву Коварную"}, -- KEEVA
  [26] = {C = "Убить Залшим"}, -- ZAL
-- Western Skyrim
  [27] = {C = "Убить Исмгара"}, -- YSM
  [28] = {C = "Убить вервольфов"}, -- WWOLF
  [29] = {C = "Убить Скрега Непобедимого"}, -- SKREG
  [30] = {C = "Убить Мать Тьмы"}, -- SHADE
-- Blackreach: Greymoor Caverns
  [31] = {C = "Очистить места пиршеств вампиров"}, -- VAMP
  [32] = {C = "Убить двемерского колосса-разборщика"}, -- DISM
-- Blackwood
  [33] = {C = "Победить Старого Смертожаба"}, -- FROG
  [34] = {C = "Победить Зимхока Собирателя Трофеев"}, -- XEEM
  [35] = {C = "Победить ритуалистов сул-зан"}, -- SUL
  [36] = {C = "Победить Гемваса Предвестника"}, -- RUIN
  [37] = {C = "Победить Брум-Коску"}, -- BULL
  [38] = {C = "Победить вождя Затмоза"}, -- ZATH
-- High Isle
  [39] = {C = "Убить призывательницу змей Виншу"}, -- VIN
  [40] = {C = "Уничтожить Мрачного Рыцаря"}, -- SAB
  [41] = {C = "Убить фанатиков из ордена Расцвета"}, -- SHAD
  [42] = {C = "Убить Глемиоса Дикий Рог"}, -- WILD
  [43] = {C = "Убить теургов Старшего Течения"}, -- ELD
  [44] = {C = "Убить хадолида-матрону"}, -- HAD
-- Necrom
  [45] = {C = "Победить Ходячий Кошмар"}, -- WNM
  [46] = {C = "Победить Корлиса Поработителя"}, -- CORL
  [47] = {C = "Победить Вро-Кул-Ша"}, -- VRO
  [48] = {C = "Победить валкиназа Дека"}, -- DEK
  [49] = {C = "Победить Главного Библиотекаря"}, -- CATL
  [50] = {C = "Победить повелителя рун Зиомара"}, -- XIOM
-- Gold Road
  [51] = {C = "Победить сказителя Уртрендира"}, -- URTH
  [52] = {C = "Победить Стри Пожирателя Судеб"}, -- STRI
  [53] = {C = "Победить Клыка и Когтя"}, -- FANG
  [54] = {C = "Победить Хесседаза Зловещего"}, -- HESS
  [55] = {C = "Победить предводителей Стражей Памяти"}, -- RECO
  [56] = {C = "Победить Дубовый Коготь"}, -- OAK
-- Solstice
  [57] = {C = "Победить Злобу Прилива"}, -- TIDE
  [58] = {C = "Победить Голма"}, -- GAULM
  [59] = {C = "Победить воскрон-стражей"}, -- VOSK
  [60] = {C = "Победить Призывательницу Душ"}, -- SCALL
  [61] = {C = "Победить Во-Зита"}, -- WOXET
  [62] = {C = "Победить Гишзора"}, -- GHISH
}
WPamA.i18n.DayOfWeek = {
  [0] = "Вос",
  [1] = "Пон",
  [2] = "Втр",
  [3] = "Срд",
  [4] = "Чтв",
  [5] = "Птн",
  [6] = "Суб",
}
WPamA.i18n.Chat = {
  Today = "Обеты сегодня: (<<2>> <<1>>): ",
  Anyday = "Обеты: (<<2>> <<1>>): ",
  Loot  = " (<<1>>)",
  Addon = " (<<1>> v<<X:2>>)",
  Dlmtr = "; ",
}
WPamA.i18n.RGLA = {
  CZ = "/z",
  CL = "/g1",
  CP = "/p",
  F1 = "<<1>> Сбор группы на <<2>>, поделюсь квестом.",
  F2 = " Для приема в группу и получения квеста пишите <<1>>",
  F3 = " Для приема в группу пишите <<1>>",
--F4 = "",
  F5 = " ( <<1>> ).",
  F6 = "<<1>> LFM \"<<2>>\", авто-прием, авто-раздача",
  F7 = "<<1>> LFM \"<<2>>\", авто-прием",
  F8 = "<<1>> <<2>> старт через 1 мин.",
  F9 = "/p СТАРТ <<1>>",
  F10 = "<<1>> <<2>> убит.",
  F11 = "/p Квест раздается автоматически. Возможно у Вас сейчас есть квест на другого босса или Вы уже делали сегодня этот квест.",
  F12 = "Аддон <<1>> вер.<<2>> с ESOUI.COM: Отслеживание квестов Обетов, Испытаний и Мировых Боссов, авто-прием и авто-раздача.",
}
