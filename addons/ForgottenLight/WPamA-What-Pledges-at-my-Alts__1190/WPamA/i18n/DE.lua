local Icon = WPamA.Consts.IconsW
local GetIcon = WPamA.Textures.GetTexture
local OpenWindowText = GetString(SI_ENTER_CODE_CONFIRM_BUTTON)
local DynamicEncounterText = GetString(SI_HUD_EDITOR_DYNAMIC_EVENT_TRACKER)
WPamA.i18n = {
  Lng = "DE",
-- DateTime settings
  DateTimePart = {dd = 0, mm = 1, yy = 2, },
  DateFrmt = 2, -- 1 default:m.d.yyy ; 2:yyyy-mm-dd; 3:dd.mm.yyyy; 4:yyyy/mm/dd; 5:dd.mm.yy; 6:mm/dd; 7:dd.mm
  DateFrmtList = {"ESO Default","jjjj-mm-tt","tt.mm.jjjj","jjjj/mm/tt","tt.mm.jj","mm/tt","tt.mm"},
  DayMarker = "T",
  MetricPrefix = {"K","M","G","T","P","E"},
  CharsOrderList = {"ESO Default","Names","Alliance, Names","Max level, Names","Min level, Names","Alliance, Max level","Alliance, Min level"},
-- Marker (substring) in active quest step text for detect DONE stage
  DoneM = {
    [1] = "Kehrt",
    [2] = "Sprecht",
  },
-- Keybinding string
  KeyBindShowStr  = "Zeige/Verstecke AddOn Fenster",
  KeyBindChgWStr  = "Nächstes Fenster öffnen",
  KeyBindChgTStr  = "Nächsten Fenstertab öffnen",
  KeyBindChgAStr  = "Nächsten Addon-Tab öffnen",
  KeyFavRadMenu   = "Radialmenü der bevorzugten Tabs",
  KeyBindCharStr  = "Charaktergelöbnisse zeigen",
  KeyBindClndStr  = "Gelöbnissekalender anzeigen",
  KeyBindPostTd   = "Poste die heutigen Gelöbnisse im Chat (EN)",
  KeyBindPostTdCL = "Poste die heutigen Gelöbnisse im Chat (DE)",
  KeyBindWindow0  = OpenWindowText .. ": " .. "Gruppendungeons",
  KeyBindWindow1  = OpenWindowText .. ": " .. "Prüfungen",
  KeyBindWindow2  = OpenWindowText .. ": " .. GetString(SI_ZONECOMPLETIONTYPE9),
  KeyBindWindow3  = OpenWindowText .. ": " .. "Fertigkeiten",
  KeyBindWindow4  = OpenWindowText .. ": " .. GetString(SI_BINDING_NAME_TOGGLE_INVENTORY),
  KeyBindWindow5  = OpenWindowText .. ": " .. GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKCATEGORIES1),
  KeyBindWindow6  = OpenWindowText .. ": " .. GetString(SI_MAPFILTER14),
  KeyBindWindow7  = OpenWindowText .. ": " .. GetString(SI_JOURNAL_MENU_ACHIEVEMENTS) ..
                    ", " .. GetString(SI_COLLECTIONS_MENU_ROOT_TITLE),
  KeyBindWindow8  = OpenWindowText .. ": " .. GetString(SI_QUEST_JOURNAL_GENERAL_CATEGORY),
  KeyBindRGLA     = "Zeige/Verstecke RGLA (Raid Group Leader Assistant)",
  KeyBindRGLASrt  = "RGLA: Starten",
  KeyBindRGLAStp  = "RGLA: Stoppen",
  KeyBindRGLAPst  = "RGLA: In den Chat schreiben",
  KeyBindRGLAShr  = "RGLA: Teile Quest",
  KeyBindLFGP     = "GFP: Suche starten/stoppen",
  KeyBindLFGPMode = "GFP: Auswahl des Modus",
-- Caption
  Wind = {
    [0] = {
      Capt = "Gruppendungeons",
      Tab = {
        [1] = {N="Gelöbnisse", W=88},
        [2] = {N="Kalender", W=72},
        [3] = {N="Zufällige Aktivität", W=136},
        [4] = {N=GetString(SI_ENDLESS_DUNGEON_LEADERBOARDS_CATEGORIES_HEADER), W=181},
      },
    },
    [1] = {
      Capt = "Prüfungen",
      Tab = {
        [1] = {N="AA, HRC, SO, MOL, CR, SS", W=192},
        [2] = {N="HOF, AS, KA, RG, DSR, SE", W=192},
        [3] = {N="LC, OC", W=192},
      },
    },
    [2] = {
      Capt = GetString(SI_ZONECOMPLETIONTYPE9), -- "World Bosses"
      Tab = {
        [ 1] = {N=GetIcon(18,28), NC=GetIcon(18,28,true), W=28, S=true, A="Wrothgar"},
        [ 2] = {N=GetIcon(25,28), NC=GetIcon(25,28,true), W=28, S=true, A="Vvardenfell"},
        [ 3] = {N=GetIcon(22,28), NC=GetIcon(22,28,true), W=28, S=true, A="Goldküste"},
        [ 4] = {N=GetIcon(26,26), NC=GetIcon(26,26,true), W=28, S=true, A="Sommersend"},
        [ 5] = {N=GetIcon(28,26), NC=GetIcon(28,26,true), W=28, S=true, A="Nördliches Elsweyr"},
        [ 6] = {N=GetIcon(30,28), NC=GetIcon(30,28,true), W=28, S=true, A="Westliches Himmelsrand"},
        [ 7] = {N=GetIcon(34,28), NC=GetIcon(34,28,true), W=28, S=true, A=GetString(SI_CHAPTER5)}, -- "Dunkelforst"
        [ 8] = {N=GetIcon(40,28), NC=GetIcon(40,28,true), W=28, S=true, A=GetString(SI_CHAPTER6)}, -- "Hochinsel"
        [ 9] = {N=GetIcon(42,28), NC=GetIcon(42,28,true), W=28, S=true, A=GetString(SI_CHAPTER7)}, -- "Necrom"
        [10] = {N=GetIcon(43,28), NC=GetIcon(43,28,true), W=28, S=true, A=GetString(SI_CHAPTER8)}, -- "Westauen"
        [11] = {N=GetIcon(66,28), NC=GetIcon(66,28,true), W=28, S=true, A=GetString(SI_CHAPTER9)}, -- "Sonnenwende"
      },
    },
    [3] = {
      Capt = "Fertigkeiten",
      Tab = {
        [1] = {N="Klasse & AvA", W=104},
        [2] = {N="Handwerk", W=81},
        [3] = {N="Gilde", W=43},
        [4] = {N="Offene welt", W=91},
        [5] = {N=GetIcon(27,28), NC=GetIcon(27,28,true), W=28, S=true, A=GetString(SI_STATS_RIDING_SKILL)},
        [6] = {N=GetIcon(22,28), NC=GetIcon(22,28,true), W=28, S=true, A="Verhüllte Versorgerin"},
        [7] = {N=zo_strformat("<<1>><<2>><<3>>", GetIcon(57,22), GetIcon(58,22), GetIcon(59,22)),
               NC=zo_strformat("<<1>><<2>><<3>>", GetIcon(57,22,true), GetIcon(58,22,true), GetIcon(59,22,true)),
               W=70, S=true, A=GetString(SI_STAT_GAMEPAD_CHAMPION_POINTS_LABEL)},
      },
    },
    [4] = {
      Capt = GetString(SI_BINDING_NAME_TOGGLE_INVENTORY),
      Tab = {
        [1] = {N="Währung", W=75},
        [2] = {N="Artikel", W=53},
        [3] = {N=GetIcon(32,24), NC=GetIcon(32,24,true), W=28, S=true, A="Schriftrollen des Lernens"},
        [4] = {N=GetIcon(60,24), NC=GetIcon(60,24,true), W=28, S=true, A="Transmutationsgeoden"},
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
        [1] = {N=GetString(SI_CAMPAIGNRULESETTYPE1), W=61},
        [2] = {N=GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES5), W=116},
        [3] = {N=GetString(SI_DAILY_LOGIN_REWARDS_TILE_HEADER), W=175},
        [4] = {N="Belohnungen & Zeichen", W=187},
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
               W=70, S=true, A="Fertigkeiten: Klasse, Gilde, Rüstung"},
        [4] = {N=zo_strformat("<<1>><<2>><<3>>", GetIcon(48, 24), GetIcon(51, 24), GetIcon(53, 24)),
               NC=zo_strformat("<<1>><<2>><<3>>", GetIcon(48, 24, true), GetIcon(51, 24, true), GetIcon(53, 24, true)),
               W=70, S=true, A="Fertigkeiten: Waffe"},
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
        [1] = {N="Saisonale Festivals", W=150},
        [2] = {N=GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES803), W=70},
        [3] = {N=GetString(SI_RECIPECRAFTINGSYSTEM6), W=100},
        [4] = {N=GetString(SI_QUESTTYPE19), W=100}, -- Favors
      },
    },
    [8] = {
      Capt = GetString(SI_QUEST_JOURNAL_GENERAL_CATEGORY), -- "Verschiedenes"
      Tab = {
        [1] = {N=GetString(SI_TIMED_ACTIVITIES_TITLES), W=102},
        [2] = {N="Schriebe", W=82},
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
      HdT = { [1] = "Gesamt", [2] = "Benutzt", [3] = "Freie" }
    },
--------
    [42] = {
      HdT = {
        [1] = GetString(SI_COLLECTIBLERESTRICTIONTYPE1), -- Race
        [2] = GetString(SI_COLLECTIBLERESTRICTIONTYPE3), -- Class
        [3] = "SP", [4] = "Letzte Anmeldung", [5] = "Gespielte Zeit"
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
  SelModeWin = {x = 270, y = 2, dy = 24},
-- Labels
  TotalRow = {[1] = "BANK", [2] = "TOTAL"},
  HdrLvl = "Lvl",
  HdrName = "Name",
  HdrClnd = "Kalender",
  HdrMaj = "Maj",
  HdrGlirion = "Glirion",
  HdrUrgarlag = "Urgarlag",
  HdrLFGReward = "Lila Belohnung",
  HdrLFGRnd  = "Verlies",
  HdrLFGBG   = "Battlegrounds",
  HdrLFGTrib = GetString(SI_ACTIVITY_FINDER_CATEGORY_TRIBUTE),
  HdrAvAReward = GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES705),
  SendInvTo = "Schicke Einladung zu <<1>>",
  ShareSubstr = "share",
  EndeavorTypeNames = {
    [1] = zo_strformat(SI_TIMED_ACTIVITIES_TYPE_HEADER, GetString(SI_TIMEDACTIVITYTYPE0)),
    [2] = zo_strformat(SI_TIMED_ACTIVITIES_TYPE_HEADER, GetString(SI_TIMEDACTIVITYTYPE1)),
    [3] = zo_strformat(SI_TIMED_ACTIVITIES_TYPE_HEADER, GetString(SI_TIMEDACTIVITYTYPE2))
  },
  EndeavorRepeat = "Wiederholen",
  PromoEventName = GetIcon(47, 20, true) ..
                   GetString(SI_ACTIVITY_FINDER_CATEGORY_PROMOTIONAL_EVENTS) .. " : <<1>>",
  NoWorldEventsHere = "Hier gibt es keine Weltereignisse",
  WECalculating = "Berechnung",
  WEDistance = "Distanz",
-- Pledge Quest Givers NPC names
  PledgeQGivers = {
    [1] = "Maj al-Ragath",
    [2] = "Glirion der Rotbart",
    [3] = "Urgarlag Häuptlingsfluch",
  },
-- Shadowy-Supplier NPC name
  ShadowySupplier = {
    ["Schweigt-still"] = true,
  },
  ComeBackLater = "Kommen Sie später wieder",
-- Replace text for long companion equipment names
  CompanionEquipRepl = {
    CompTitle = " eines Gefährten",
   --- Trait names replacement ---
    ["Keine Eigenschaft"] = {[3] = "Keine", [4] = "Keine"},
    ["Beflügelt"]    = {[4] = "Befl"},
    ["Fruchtbar"]    = {[4] = "Fruch"},
    ["Fokussiert"]   = {[4] = "Fokus"},
    ["Erschütternd"] = {[3] = "Erschüt.", [4] = "Ersch"},
    ["Aggressiv"]    = {[4] = "Aggr"},
    ["Besänftigend"] = {[3] = "Besänf.", [4] = "Besänf"},
    ["Erweitert"]    = {[4] = "Erweit"},
    ["Gepolstert"]   = {[4] = "Gepol"},
    ["Lebhaft"]      = {[4] = "Lebh"},
   --- Item names replacement ---
    ["Schulterschutz"]  = {[1] = "Sch.schutz"},
    ["Schulterkappen"]  = {[1] = "Sch.kappen"},
    ["Schulterpolster"] = {[1] = "Sch.polster"},
    ["Panzerschuhe"]    = {[1] = "Pnz.schuhe"},
    ["Armschienen"]     = {[1] = "Armsch."},
    ["Beinschienen"]    = {[1] = "Beinsch."},
    ["Beinkleider"]     = {[1] = "Beinklei."},
    ["Handschuhe"]      = {[1] = "Handsch."},
   --- Item types replacement ---
    [SI_EQUIPTYPE5]  = {[4] = "1H"}, -- "One-Handed"
    [SI_EQUIPTYPE6]  = {[4] = "2H"}, -- "Two-Handed"
    [SI_EQUIPSLOT11] = {[2] = "Ring", [4] = "R"},
  },
-- Addon Options Menu
--> 1
  OptGeneralHdr = "Generelle Einstellungen",
  OptCharsOrder = "Characters Order",
  OptCharsOrderF = "The choice of the order in which characters are displayed in the addon window. UI reload required. Characters are sorted only at the start of the addon and in the future the order does not change.",
  OptAlwaysMaxWinX  = "Feste Breite des Hauptfensters",
  OptAlwaysMaxWinXF = "Die Fensterbreite des Hauptfensters wird immer gleich bleiben, wenn diese Einstellung aktiviert ist. Ist diese Einstellung deaktiviert, so verändert sich die Fensterbreite des Hauptfensters abhängig vom Modus.",
  OptLocation = "Ort anstelle des Deungeon Namens",
  OptENDungeon = "Zeige die Namen von Dungeons in Englischer Sprache",
  OptDontShowNone  = "Zeige blank anstelle von \"fehlt\"",
  OptDontShowReady = "Zeige blank anstelle von \"Verfügbar\"",
  OptTitleToolTip = "Aktiviere Tooltip für den Fenster Titel",
  OptHintUncomplPlg  = "Gelöbnisse in nicht abgeschlossenen Dungeons", -- Gelöbnisse in unvollendeten Dungeons
  OptHintUncomplPlgF = table.concat( {
                       "Zeigen Sie Hinweise zu den heutigen Gelöbnissen im Fenster Gelöbnisse der Unerschrockenen an, wenn diese Dungeons noch nicht abgeschlossen sind.\n",
                       "Ein Dungeon gilt als nicht abgeschlossen, wenn die Story-Quest nicht abgeschlossen wurde oder nicht alle Bosse getötet wurden.\n",
                       "(ein Dungeon muss für den Account oder Charakter verfügbar/freigeschaltet sein)",
                       } ),
  OptLargeCalend  = "Kalender der Gelöbnisse anzeigen für...",
  OptLargeCalendF = "Wählen Sie die Anzahl der Tage im Gelöbnis Kalender aus",
  OptDateFrmt  = "Das Datumsformat",
  OptDateFrmtF = "Wähle das Format für die Darstellung des Datums im Kalender",
  OptShowTime  = "Zeige Zeit hinter dem Datum",
  OptLFGRndAvl  = "Das Format der kurzen Zeiträume",
  OptLFGRndAvlF = "Wählen Sie das Format für kurze Zeiträume (weniger als 24 Stunden) aus, z. B. tägliche Belohnung für zufällige Aktivitäten, Schattenlieferanten, Reitfähigkeiten usw.",
  OptTrialAvl  = "Das Format der langer Zeiträume",
  OptTrialAvlF = "Wählen Sie das Format für lange Zeiträume (mehr als 24 Stunden), wie z. B. die wöchentliche Belohnung für Prüfungen usw.",
  OptTimerList = {"Countdown Timer","Datum & Uhrzeit (MM/TT hh:mm)","Datum & Uhrzeit (TT.MM hh:mm)"},
  OptRndDungDelay = "Wartezeit für Tagesbelohnung",
  OptRndDungDelayF = "Die Wartezeit (in Sekunden), welche der Server benötigt, bis er die Belohnungsinformation für das abgeschlossene, tägliche Zufalls-Verlies abgerufen hat.. Die Standard Einstellung (5 Sekunden) kann nur dann verändert werden, wenn das AddOn \"???\" anstelle eines Countdown nach dem Re-Login oder ReloadUI anzeigt.",
  OptShowMonsterSetTT = "Show tooltip for the Monster Sets",
  OptShowMonsterSetTTF = "Show tooltip for the Monster Sets in \"Undaunted Pledges\" and \"Calendar of Pledges\" modes",
  OptMouseModeUI = "Zeig den Mauszeiger",
  OptMouseModeUIF = "Zeig den Mauszeiger bei geöffnetem Addon-Fenster",
  OptCharNamesMenu = "Charakternamen",
  OptCharNameColor = "Zeigen Sie die Namen in Allianz Farbe",
  OptCharNameAlign = "Namen Ausrichtung",
  OptNamesAlignList = {"links", "mitte", "rechts"},
  OptCorrLongNames = "Korrigieren Sie die Anzeige langer Namen um",
  OptNamesCorrList = {"nichts tun", "Schriftgröße", "Mitte schneiden", "Textmaske"},
  OptNamesCorrRepl = {"Finden Sie diesen Text im Namen", "und ersetzen Sie ihn durch diesen Text"},
  OptCurrencyValThres = "Runden Sie Währungswerte auf...",
  OptCurrencyValThresF = table.concat(
                         { "Auf welche Zahlen Währungswerte gerundet werden sollen.\n",
                           GetString(SI_GAMEPAD_CURRENCY_SELECTOR_HUNDREDS_NARRATION),      " : 123 K\n",
                           GetString(SI_GAMEPAD_CURRENCY_SELECTOR_THOUSANDS_NARRATION),     " : 1234 K\n",
                           GetString(SI_GAMEPAD_CURRENCY_SELECTOR_TEN_THOUSANDS_NARRATION), " : 12345 K"
                         } ),
  OptDynEncounterNotify = zo_strformat("<<1>>: <<2>>", DynamicEncounterText, GetString(SI_MAIN_MENU_NOTIFICATIONS)),
  OptDynEncounterNotifyF = table.concat(
                           { "Benachrichtigungen über Start, Aktivität, Abschluss und Fortschritt ",
                             "von dynamischen Begegnungen auf dem Bildschirm und im Chat anzeigen.\n\n",
                             GetString(SI_ACTIONBARSETTINGCHOICE2), " - Benachrichtigungen ausblenden, solange der Charakter ",
                             "an einer Begegnung teilnimmt, ansonsten dynamische Begegnungsbenachrichtigungen anzeigen."
                           } ),
  OptCompanionRapport = "Gefährtenbeziehung anzeigen als...",
  OptCompanionRprtList = {"Zahl", "Text"},
  OptCompanionRprtMax = "Maximalwert anzeigen",
  OptCompanionEquip = "Gefährten-Ausrüstung anzeigen als...",
  OptCompanionEquipList = {"Artikelname", "Artikeltyp", "Artikeleigenschaft", "Typ und Eigenschaft"},
--> 2
  OptModeSetHdr = "Options- und Mode-Einstellungen",
  OptAutoActionsHdr = "Automatisierung der täglichen Aktivitäten",
  OptAutoTakeUpPledges = "Automatisch Gelöbnis annehmen",
  OptAutoTakeUpPledgesF = "Automatisch die Gelöbnis Quest annehmen, wenn mit den Unerschrockenen NPCs gesprochen wird",
  OptAutoTakeDBSupplies = "Auto-erhalte die Vorräte der Dunk.Bruderschaft",
  OptAutoTakeDBSuppliesF = "Erhalten Sie während eines Gesprächs mit dem schattenhaften Lieferanten automatisch nützliche Gegenstände (Vorräte)",
  OptAutoTakeDBList = {"Kontoweit", "abhängig vom Charakter"},
  OptChoiceDBSupplies = "Welche Art von Lieferungen zu erhalten...",
  OptDBSuppliesList = {"nichts tun", "Gifte / Tränke", "weniger auffällig", "Rüstung / Waffen"},
  OptAutoChargeWeapon = "Waffen automatisch laden",
  OptAutoChargeWeaponF = "Waffe automatisch nachladen, wenn die aktuelle Ladung unter dem Mindestschwellenwert liegt.\n" ..
                         "Das Inventar des Charakters muss mindestens 1 gefüllten Seelenstein enthalten.",
  OptAutoChargeThreshold = "Mindestladeschwelle",
  OptAutoChargeThresholdF = "Die Waffe wird aufgeladen, wenn die verbleibende Verzauberungsladung unter diesem Wert liegt",
  OptAutoCallEyeInfinite = "Auto-beschwört ein " .. zo_strformat( SI_COLLECTIBLE_NAME_FORMATTER, GetCollectibleName(WPamA.EndlessDungeons.EyeOfInfinite.C) ),
  OptAutoCallEyeInfiniteF = table.concat(
                            { "Beschwört automatisch ein |t20:20:",
                              GetCollectibleIcon(WPamA.EndlessDungeons.EyeOfInfinite.C), "|t",
                              zo_strformat( SI_COMPANION_NAME_FORMATTER, GetCollectibleName(WPamA.EndlessDungeons.EyeOfInfinite.C) ),
                              " in Infinite-Archiv-Zonen.\n\nDiese Option ist verfügbar, wenn das Werkzeug auf dem Konto verfügbar ist."
                            } ),
  ---
--  OptEndeavorRewardMode = "Belohnungen für Herausforderung anzeigen als...",
--  OptEndeavorRewardList = {"einzeln", "aktuell", "maximal"},
  OptEndeavorChatMsg  = "Zeigen Sie den Herausforderung im Chat an",
  OptEndeavorChatMsgF = "Zeigen Sie Informationen im Chat-Fenster an, wenn sich der Herausforderung ändert",
  OptEndeavorChatChnl = "Chat-Kanal für Fortschrittsmeldungen",
  OptEndeavorChatChnlF = "Chat-Kanal zur Anzeige von Informationen über der Herausforderung anzuzeigen",
  OptEndeavorChatColor = "Farbe der Fortschrittsbenachrichtigung",
  OptEndeavorChatColorF = "Passt die Farbe der Fortschrittsbenachrichtigungen an",
  OptEndeavorAutoClaim = "Auto-Einfordern der Herausforderung Belohnungen",
  OptEndeavorHideCompl = "Abgeschlossene Herausforderungen ausblenden",
  OptPursuitChatMsg  = "Zeigen Sie den Vorhaben im Chat an",
  OptPursuitChatMsgF = "Zeigen Sie Informationen im Chat-Fenster an, wenn sich der Goldene Vorhaben ändert",
  OptPursuitChatCamp  = "Bis eine Kampagnenbelohnung verdient wird",
  OptPursuitChatCampF = "Wenn aktiviert, wird der Goldene Vorhaben angezeigt, bis eine Kampagnenbelohnung verdient wird.\nWenn deaktiviert, wird der Goldene Vorhaben immer angezeigt.",
--  OptPursuitChatChnl = "Chat-Kanal für Fortschrittsmeldungen",
  OptPursuitChatChnlF = "Chat-Kanal zur Anzeige von Informationen über der Goldene Vorhaben anzuzeigen",
  OptPursuitAutoClaim = "Auto-Einfordern der Vorhaben Belohnungen",
  ---
  OptLFGPHdr = "Gruppen Finder für Gelöbnis",
  OptLFGPOnOff = "Erlaubt Nutzung des Gruppen Finder für Gelöbnis",
  OptLFGPMode = "Setze auch den Gruppen Modus auf...",
  OptLFGPModeList = {zo_strformat("immer <<1>><<1>><<1>> (<<2>>)", Icon.Norm, Icon.LfgpKeys[1]), -- NNN
                     zo_strformat("immer <<1>><<1>><<2>> (<<3>>)", Icon.Vet, Icon.Minus, Icon.LfgpKeys[2]), -- VV-
                     zo_strformat("immer <<1>><<1>><<2>> (<<3>>)", Icon.Vet, Icon.Norm, Icon.LfgpKeys[3]), -- VVN
                     zo_strformat("immer <<1>><<1>><<1>> (<<2>>)", Icon.Vet, Icon.LfgpKeys[4]), -- VVV
                     "abhängig vom Charakter"},
  OptLFGPIgnPledge = "Ignoriere \"Gelöbnis abgschlossen\" Markierung",
  OptLFGPAlert = "Benachrichtige am Bildschirm",
  OptLFGPChat = "Benachrichtige in den Chat",
  OptLFGPModeRoult = zo_strformat("Suchen als <<1>>/<<2>> für veraltete Gelöbnis", Icon.Vet, Icon.Norm),
  OptLFGPModeRoultF = table.concat(
                      { "Falls der Gruppen Finder auf den Veteranenmodus eingestellt ist ",
                        "und der Charakter eine Quest für ein veraltetes (nicht aktuelles) Gelöbnis hat, ",
                        "ermöglicht diese Einstellung die zusätzliche Suche nach einer Gruppe für den normalen Modus.\n\n",
                        "Wenn aktiviert, suchen Sie eine Gruppe für jeden Modus (", Icon.Vet, " oder ", Icon.Norm,
                        ") - ", Icon.Roult, ".\n",
                        "Wenn deaktiviert, suchen Sie nur eine Gruppe für den ", Icon.Vet, "-Modus."
                      } ),
--> 3
  OptRGLAHdr = "RGLA Einstellungen",
  OptRGLAQAutoShare = "Erlaube automatisches Quest Teilen",
  OptRGLAQAlert = "Benachrichtige am Bildschirm",
  OptRGLAQChat = "Benachrichtige in den Chat",
  OptRGLABossKilled = "RGLA Stoppe wenn der Boss getötet wurde",
--> 4
  CharsOnOffHdr = "Zeige / Verstecke Charaktere",
  CharsOnOffNote = "Notiz: Dein aktueller Charakter wird diese Einstellung immer ignorieren. Informationen über den aktuellen Charakter werden immer, in allen Modi, angezeigt.",
  OptCharOnOffTtip = "Zeige / Verstecke Charakter \"<<1>>\"",
--> 5
  ModesOnOffHdr = "Zeige / Verstecke Fenster Modus",
  ModesOnOffNote = "Notiz: Diese Einstellung betrifft nur den sequentiellen Fenster Wechsel Modus. Du kannst alle Fenster Modi verstecken, aber wenigstens ein Fenster Modus bleibt nicht-versteckt. Du kannst auch den gewünschten Fenstermodus direkt aus dem Kontextmenü auswählen.",
  OptWindOnOffTtip = "Zeige / Verstecke Fenster \n\"<<1>>\"",
  OptModeOnOffTtip = "Zeige / Verstecke Fenster Modus\n\"<<1>>\"",
--> 6
  CustomModeKbdHdr  = "Benutzerdefinierte Tastenbindungseinstellungen",
  CustomModeKbdNote = "Notiz: Diese Einstellungen gelten für das gesamte Konto.\nAnpassen der Modusanruftasten ermöglicht es Ihnen, Tasten Anrufmodi Ihrer Wahl zuzuweisen.",
  OptCustomModeKbd  = GetString(SI_COLLECTIBLECATEGORYTYPE29) .. " <<1>> ...",
--> 7
--  ResetCharNote = "",
  ResetChar = "Setze Charakterliste",
  ResetCharF = "Setze Charakterliste zurück",
  ResetCharWarn = "Alle Daten über deine Charaktere werden gelöscht. Bist du sicher?",
-- LFGP texts
  LFGPSrchCanceled = "Gruppensuche wurde abgebrochen",
  LFGPSrchStarted  = "Gruppensuche gestartet",
  LFGPAlrdyStarted = "Eine andere Aktivität wurde bereits gestartet",
  LFGPQueueFailed  = "Erstellung der Warteschlange fehlgeschlagen",
  LFGP_ErrLeader   = "Du bist kein gruppen Anführer!",
  LFGP_ErrOverland = "Du musst dich in der normalen Spielwelt (Overland) befinden!",
  LFGP_ErrGroupRole= "Du musst eine Gruppen Rolle setzen!",
-- RGLA texts
  RGLABossKilled = "Der Boss wurde getötet. RGLA wurde gestoppt.",
  RGLALeaderChanged = "Der Gruppen Anführer hat gewechselt. RGLA wurde gestoppt.",
  RGLAShare = "Teile",
  RGLAStop = "Stop",
  RGLAPost = "> Chat",
  RGLAStart = "Start",
  RGLAStarted = "Gestartet",
  RGLALangTxt = "Auf Deutsch für",
-- RGLA Errors
  RGLA_ErrLeader = "Du bist kein gruppen Anführer!",
  RGLA_ErrAI = "Addon AutoInvite wurde nicht gefunden, oder ist nicht aktiv!",
  RGLA_ErrBoss = "Der Boss wurde bereits getötet. RGLA kann nicht gestartet werden.",
  RGLA_ErrQuestBeg = "Du hast keine täglichen Quests für ",
  RGLA_ErrQuestEnd = " Welt Bosse!",
  RGLA_ErrLocBeg = "Du bist momentan nicht in ", 
  RGLA_ErrLocEnd = "!", 
  RGLA_Loc = {
    [ 0] = "Wrothgar",
    [ 1] = "Vvardenfell",
    [ 2] = "Goldküste",
    [ 3] = "Sommersend",
    [ 4] = "Nördliches Elsweyr",
    [ 5] = "Westliches Himmelsrand",
    [ 6] = "Graumoorkavernen",
    [ 7] = "Dunkelforst",
    [ 8] = "Hochinsel",
    [ 9] = "Telvanni-Halbinsel",
    [10] = "Apocrypha",
    [11] = "Sonnenwende",
  },
-- Dungeons Status
  DungStDone = "FERTIG",
  DungStNA = "N/A",
-- Wrothgar Boss Status
  WWBStNone = "fehlt",
  WWBStDone = "FERTIG",
  WWBStCur  = "AKT",
-- Trials Status
  TrialStNone = "fehlt",
  TrialStActv = "AKT",
-- LFG Random Dungeon Status
  LFGRewardReady = "Verfügbar",
  LFGRewardNA = "N/A",
-- Shadowy Supplier
  ShSuplUnkn = "?",
  ShSuplReady = "Verfügbar",
  ShSuplNA = "N/A",
-- Login Status
  LoginToday = "Heute",
  Login1DayAgo = "Gestern",
-- Dynamic Encounter Status
  DynamicEncounter = {
    Icon  = GetIcon(73, 20),
    Title = DynamicEncounterText,
    Start = "Die Veranstaltung begann",
    Stop  = "Die Veranstaltung ist abgeschlossen",
    Activ = "Die Veranstaltung ist aktiv",
    Progr = table.concat({ GetString(SI_ENDLESS_DUNGEON_SUMMARY_PROGRESS_HEADER),
            " ", GetString(SI_SPECTACLE_EVENTS_PROGRESS_PERCENT) })
  },
--
}
WPamA.i18n.ToolTip = {
  [-1] = "",
  [ 0] = Icon.LMB .. " Schließe Fenster",
  [ 1] = Icon.LMB .. " Zeige Optionen Fenster",
  [ 2] = Icon.LMB .. " Ändere Fenster\n" .. Icon.RMB .. " Wähle den Fenster",
  [ 3] = table.concat({ "Schreibe heutige 'Tägliche Dungeons' (Unerschrockene) in den Chat\n",
                        Icon.LMB, " Auf Englisch\n", Icon.RMB, " Auf Deutsch" }),
  [ 4] = "Dein aktueller Fortschritt beim Abschließen der täglichen Dungeons",
  [ 5] = "Ein Kalender der aktuellen und zukünftigen täglichen Dungeons (Unerschrockene)",
  [ 6] = "Dein aktueller Fortschritt beim Abschließen der täglichen Quests",
  [ 7] = "Schlüssel, Dietrich und Großer Seelenstein",
  [ 8] = "Deine Charaktere sind erholt",
  [ 9] = "Deine Charaktere sind NICHT erholt",
  [10] = table.concat({ "Gruppen Finder für Gelöbnis\n", Icon.LMB, " ", WPamA.i18n.KeyBindLFGP, "\n", Icon.RMB, " ", WPamA.i18n.KeyBindLFGPMode }),
  [11] = "Transmutationskristalle",
--
  [12] = "Dein aktueller Fortschritt der Offene welt Fertigkeiten.",
  [13] = GetString(SI_STABLE_STABLES_TAB),
  [14] = GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKCATEGORIES1),
  [15] = "Saisonale Festivals",
  [16] = "Dein aktueller Fortschritt der Gilden Fertigkeiten.",
  [17] = "Dein aktueller Fortschritt der Klassen & AvA Fertigkeiten.",
  [18] = "Dein aktueller Fortschritt der Handwerk Fertigkeiten.",
  [19] = "Die Verfügbarkeit von wöchentlichen Prüfungsbelohnungen",
  [20] = "Tägliche Belohnungs-Verfolgung für Zufalls Verlies und Battlegrounds",
-- WB Wrothgar
  [21] = "Unvollendeter Dolmen\n - Zandadunoz den Wiedergeborenen",
  [22] = "Die Nyzchaleft-Fälle\n - Nyzchaleft, den Dwemerzenturio",
  [23] = "Der Thron des Königshäuptlings\n - Königshäuptling Edu",
  [24] = "Der Altar des verrückten Ogers\n - Den verrückten Urkazbur",
  [25] = "Wildererlager\n - Die alte Snagara",
  [26] = "Die verfluchte Kinderkrippe\n - Corintthac die Abscheulichkeit",
--
  [27] = "Errungenschaft Countdown",
  [28] = "Ein aktiver Effekt (ein Bonus), der die Anzahl der verdienten Allianzpunkte erhöht",
  [29] = table.concat({ "Gruppen Finder für Gelöbnis\n",
         Icon.Minus, " - GFP ist in den Add-On-Einstellungen nicht aktiviert\n",
         GetIcon(62,18), " - mögliche Anzahl Schlüssel (mit HM)\n",
         Icon.Norm, "/", Icon.Vet, "/", Icon.Roult, " - Gruppenfinder-Modus (vor dem Dungeon-Namen)" }),
  [30] = "Lila Belohnung ist verfügbar",
-- 31-39 Class skills + Guild skills
  [31] = "Klassen Fertigkeiten: 1. Linie",
  [32] = "Klassen Fertigkeiten: 2. Linie",
  [33] = "Klassen Fertigkeiten: 3. Linie",
  [34] = "Kriegergilde",
  [35] = "Magiergilde",
  [36] = "Unerschrockene",
  [37] = "Diebesgilde",
  [38] = "Dunkle Bruderschaft",
  [39] = "Psijik-Orden",
-- 41-47 Craft skills
-- 48-50 AvA skills
  [51] = "Zitadelle von Hel Ra",
  [52] = "Ätherisches Archiv",
  [53] = "Sanctum Ophidia",
  [54] = "Schlund von Lorkhaj",
  [55] = "Die Hallen der Fertigung",
  [56] = "Die Anstalt Sanctorium",
  [57] = "Wolkenruh",
  [58] = "Sonnspitz",
  [59] = "Kynes Ägis",
--
  [60] = GetString(SI_LEVEL_UP_REWARDS_SKILL_POINT_TOOLTIP_HEADER),
  [61] = "Gold",
  [62] = "Schriebscheine",
  [63] = "Allianzpunkte",
  [64] = "Tel'Var-Steine",
--65-70 Item name
-- WB Vvardenfell
  [71] = "Eiermine von Missir-Dadalit\n - Gemahl der Königin",
  [72] = "Rat von Salothan\n - Salothan",
  [73] = "Nilthogs Senke\n - Nilthog den Ungebrochenen",
  [74] = "Sulipund-Gehöft\n - Wuyuvus den Hunger",
  [75] = "Turm von Dubdil-Alar\n - Mehz den Einschüchterer",
  [76] = "Schiffwrackbucht\n - Kimbrudhil den Singvogel",
-- WB Gold Coast
  [77] = "Arena von Kvatch",
  [78] = "Tribunentorheit\n - Limenauruus",
-- WB Summerset
  [81] = "Die Brutstätte der Königin\n - die Königin des Riffs",
  [82] = "Kielspalters Nest\n - Kielspalter",
  [83] = "Indriktollerei\n - Caanerin",
  [84] = "Die Wellsippenbucht\n - B'Korgen",
  [85] = "Gravelds Versteck\n - Graveld",
  [86] = "Greifenlauf\n - Haeliata und Nagravia",
-- Inventory
  [87] = "Informationen zum Füllen des Inventars",
  [88] = "Gesamtzahl der Plätze im Inventar",
  [89] = "Verwendete Plätze im Inventar",
  [90] = "Freie Plätze im Inventar",
-- WB Northern Elsweyr
  [91] = "Die Knochengrube\n - Na'ruzz der Knochenweber",
  [92] = "Der Narbenrand\n - Thannar der Grablotter",
  [93] = "Rothandlauf\n - Akumjhargo und Zav'i",
  [94] = "Der Hügel der Zerschlagenen Schwerter\n - Schwertmeisterin Vhysradue",
  [95] = "Die Klauenschlucht\n - die listige Kee'va",
  [96] = "Das Albtraumplateau\n - Zalsheem",
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
  [107] = "Verhüllte Versorgerin",
  [108] = "Abklingzeit-Timer für Verhüllte Versorgerin",
  [109] = "Beziehung zu Gefährten",
  [110] = GetString(SI_STAT_GAMEPAD_CHAMPION_POINTS_LABEL),
  [111] = GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES212),
-- World Events
  [112] = "", -- an overridden string
  [113] = "", -- an overridden string
  [114] = "", -- an overridden string
  [115] = table.concat({
          GetIcon(14, 24), "- Wie viel Zeit vergangen ist, seit das aktive Ereignis erkannt wurde.\n",
          GetIcon(13, 28), "- Wie viel Zeit ist vergangen, seit das Ereignis abgeschlossen wurde." }),
  [116] = "Wie lange das Ereignis aktiv war.\n(Wie lange haben die Spieler gebraucht, um das Ereignis abzuschließen)",
  [117] = "Geschätzte Zeit bis zur Aktivierung des Weltereignisses.\n" ..
          "Zur Berechnung der Zeit werden mindestens 2 abgeschlossene Veranstaltungen benötigt.\n" ..
          "Je mehr Veranstaltungen absolviert werden, desto genauer wird die Zeitberechnung.",
  [118] = "HP % - Der Gesundheitszustand des Event-Boss.\n" ..
          GetIcon(13, 28) .. "- Wie viel Zeit ist vergangen, seit das Ereignis abgeschlossen wurde.",
  [119] = "Die Entfernung in Metern zum Event-Boss.\nTatsächliche Informationen über den Boss können nur in einem Umkreis von 300 Metern um den Boss erlangt werden.",
  [120] = "Geschätzte Zeit bis zur Aktivierung des Weltereignisses.\nHängt von der Anzahl und Aktivität der Spieler am Ort ab.",
-- WB Western Skyrim
  [121] = "Ysmgars Strand\n - Seeriese",
  [122] = "Hordreks Jagdgründe\n - Werwolfjagdparty",
  [123] = "Kreis der Champions\n - Zirkel der Champions",
  [124] = "Zuflucht der Schattenmutter\n - Schattenmutter",
-- WB Blackreach: Greymoor Caverns
  [125] = "Vampir-Nährterritorien\n - Futterstelle",
  [126] = "Koloss-Ladestation\n - Dwemerkoloss",
--131-136 World skills
-- Endless Dungeon progress
  [158] = table.concat({ "Tägliche Aufgabe\n",
          Icon.Lock, " - die Einführungsquest ist nicht abgeschlossen\n",
          Icon.Quest, " - Quest ist verfügbar\n",
          Icon.ChkM, " - Quest abgeschlossen" }),
  [159] = "Bester Fortschritt erreicht\n(für alle Dungeon-Läufe mit aktivem Addon)",
--160-190 Item name
-- Trials
  [191] = "Felshain",
  [192] = "Das Grauenssegelriff",
  [193] = "Rand des Wahnsinns",
  [194] = "Die Luminit-Zitadelle",
  [195] = "Gebeinkäfig",
-- WB Blackwood
  [201] = "Teich der Alten Todwarze\n - alte Todwarze",
  [202] = "Xeemhoks Lagune\n - Xeemhok der Trophäensammler",
  [203] = "Sul-Xan-Ritualstätte\n - Yaxhat Todmacher, Nukhujeema, Shuvh-Mok, Veesha die Sumpfmystikerin",
  [204] = "Zerschlagene Xanmeer\n - Ghemvas der Vorbote",
  [205] = "Shardius' Ausgrabung\n - Bhrum",
  [206] = "Krötenzungen-Kriegslager\n - Kriegshäuptling Zathmoz",
-- Crafting Writs
  [207] = GetQuestName(WPamA.DailyWrits.QuestIDs[1][1]),
  [208] = GetQuestName(WPamA.DailyWrits.QuestIDs[2][1]),
  [209] = GetQuestName(WPamA.DailyWrits.QuestIDs[3][1]),
  [210] = GetQuestName(WPamA.DailyWrits.QuestIDs[4][1]),
  [211] = GetQuestName(WPamA.DailyWrits.QuestIDs[5][1]),
  [212] = GetQuestName(WPamA.DailyWrits.QuestIDs[6][1]),
  [213] = GetQuestName(WPamA.DailyWrits.QuestIDs[7][1]),
--214-229 Companion Skills
  [214] = "Klassen Fertigkeiten",
  [215] = "", -- an overridden string
  [216] = "", -- an overridden string
  [217] = "", -- an overridden string
  [218] = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_EQUIPMENTFILTERTYPE1) ),
  [219] = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_EQUIPMENTFILTERTYPE2) ),
  [220] = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_EQUIPMENTFILTERTYPE3) ),
  [221] = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_WEAPONCONFIGTYPE3) ),
  [222] = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_WEAPONCONFIGTYPE1) ),
  [223] = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_WEAPONCONFIGTYPE2) ),
  [224] = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_WEAPONCONFIGTYPE4) ),
  [225] = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_WEAPONCONFIGTYPE5) ),
  [226] = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_WEAPONCONFIGTYPE6) ),
--227-240 Companion & Character Equips
  [227] = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_EQUIPSLOT0) ),
  [228] = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_EQUIPSLOT3) ),
  [229] = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_EQUIPSLOT2) ),
  [230] = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_EQUIPSLOT16) ),
  [231] = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_EQUIPSLOT6) ),
  [232] = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_EQUIPSLOT8) ),
  [233] = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_EQUIPSLOT9) ),
  [234] = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_EQUIPSLOT4) ),
  [235] = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_EQUIPSLOT5) ),
  [236] = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_EQUIPSLOT1) ),
  [237] = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_EQUIPSLOT11) ),
  [238] = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_EQUIPSLOT12) ),
  [239] = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_EQUIPSLOT20) ),
  [240] = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_EQUIPSLOT21) ),
-- WB High Isle
  [241] = "Schlangenmoor\n - Schlangenruferin Vinsha",
  [242] = "Y'ffres Kessel\n - Der Zobelritter",
  [243] = "Dunkelsteinmulde\n - Emporstrebender Henker, Emporstrebende Peinigerin",
  [244] = "Faunfälle\n - Glemyos Wildhorn",
  [245] = "Amenos-Becken\n - Skerard der Theurg, Rosara die Theurgin",
  [246] = "Mornard-Fälle\n - Hadoliden-Matrone, Hadoliden-Gemahl",
--247-249 Books Category (Init by WPamA:InitLoreBookMode)
-- Hireling mail and crafting profession certification
  [250] = table.concat({ "\n", Icon.Mail, " - Hirelings-Mail ist verfügbar (Sie müssen sich im Spiel anmelden oder den Standort ändern)",
                         "\n", Icon.NoCert, " - Die Zertifizierung des Handwerksberufs ist nicht abgeschlossen" }),
-- WB Necrom
  [251] = "Albtraumversteck\n - wandelnder Albtraum",
  [252] = "Zeterklatsch-Senke\n - Corlys der Kettenschmied",
  [253] = "Tiefenplünderer-Sumpf\n - Vor-Kuul-Sha",
  [254] = "chthonischer Platz\n - Valkynaz Dek",
  [255] = "Libram-Kathedrale\n - oberster Katalogisierer",
  [256] = "Akropolis des Runenmeisters\n - Runenmeister Xiomara",
--257-260
-- WB Gold Road
  [261] = "Herbstlichtung\n - Weber Urthrendir",
  [262] = "Kluftpfad-Höhle\n - Stri der Schicksalsfresser",
  [263] = "Aufstieg des Zenturios\n - Reißzahn, Kralle",
  [264] = "Schicksalsklippe\n - Hessedaz der Unheilvolle",
  [265] = "Grenzwiege\n - Anführer der Rückbesinnung",
  [266] = "Olosee\n - Eichenkralle",
-- WB Solstice
  [267] = "Gezeitenschwemme-Strand\n - Gezeitentücke",
  [268] = "Die Ruine von Tuniria\n - Gaulm",
  [269] = "Der Schrein von Vakkan\n - die Voskrona-Wächter",
  [270] = "Seelenrufer-Schlupfwinkel\n - die Seelenruferin",
  [271] = "Hort von Wo-Xeeth\n - Wo-xeeth",
  [272] = "Zyv-Elehk-Ritualstätte\n - Ghishzor",
--273-280 Item name
}
--
WPamA.i18n.ToolTip[215] = WPamA.i18n.ToolTip[34]
WPamA.i18n.ToolTip[216] = WPamA.i18n.ToolTip[35]
WPamA.i18n.ToolTip[217] = WPamA.i18n.ToolTip[36]
--
WPamA.i18n.RGLAMsg = {
  [1] = "Z: LFM ...",
  [2] = "Z: LFM kurz",
  [3] = "Z: Start nach 1 Min",
  [4] = "G: Start nach 1 Min",
  [5] = "G: Start",
  [6] = "Z: Boss ist tot",
  [7] = "G: Hast du bereits erledigt",
  [8] = "Über das AddOn",
}
-- In Dungeons structure:
-- Q - Quest name which indicates the dungeon
-- N - Short name of the dungeon displayed by the addon
WPamA.i18n.Dungeons = {
-- Virtual dungeon
  [1] = { -- None
    N = "kein",
  },
  [2] = { -- Unknown
    N = "Unbekannt",
  },
-- First location dungeons
  [3] = { -- AD, Auridon, Banished Cells I
    N = "Verbannungszellen I",
  },
  [4] = { -- EP, Stonefalls, Fungal Grotto I
    N = "Pilzgrotte I",
  },
  [5] = { -- DC, Glenumbra, Spindleclutch I
    N = "Spindeltiefen I",
  },
  [6] = { -- AD, Auridon, Banished Cells II
    N = "Verbannungszellen II",
  },
  [7] = { -- EP, Stonefalls, Fungal Grotto II
    N = "Pilzgrotte II",
  },
  [8] = { -- DC, Glenumbra, Spindleclutch II
    N = "Spindeltiefen II",
  },
-- Second location dungeons
  [9] = { -- AD, Grahtwood, Elden Hollow I
    N = "Eldengrund I",
  },
  [10] = { -- EP, Deshaan, Darkshade Caverns I
    N = "Kavernen I",
  },
  [11] = { -- DC, Stormhaven, Wayrest Sewers I
    N = "Kanalisation I",
  },
  [12] = { -- AD, Grahtwood, Elden Hollow II
    N = "Eldengrund II",
  },
  [13] = { -- EP, Deshaan, Darkshade Caverns II
    N = "Kavernen II",
  },
  [14] = { -- DC, Stormhaven, Wayrest Sewers II
    N = "Kanalisation II",
  },
-- 3 location dungeons
  [15] = { -- AD, Greenshade, City of Ash I
    N = "Stadt der Asche I",
  },
  [16] = { -- EP, Shadowfen, Arx Corinium
    N = "Arx Corinium",
  },
  [17] = { -- DC, Rivenspire, Crypt of Hearts I
    N = "Krypta der Herzen I",
  },
  [18] = { -- AD, Greenshade, City of Ash II
    N = "Stadt der Asche II",
  },
  [19] = { -- DC, Rivenspire, Crypt of Hearts II
    N = "Krypta der Herzen II",
  },
-- 4 location dungeons
  [20] = { -- AD, Malabal Tor, Tempest Island
    N = "Orkaninsel",
  },
  [21] = { -- EP, Eastmarch, Direfrost Keep
    N = "Burg Grauenfrost",
  },
  [22] = { -- DC, Alik`r Desert, Volenfell
    N = "Volenfell",
  },
-- 5 location dungeons
  [23] = { -- AD, Reaper`s March, Selene`s Web
    N = "Selenes Netz",
  },
  [24] = { -- EP, The Rift, Blessed Crucible
    N = "Gesegnete Feuerprobe",
  },
  [25] = { -- DC, Bangkorai, Blackheart Haven 
    N = "Schwarzherz-Unterschlupf",
  },
-- 6 location dungeons
  [26] = { -- Any, Coldharbour, Vaults of Madness
    N = "Kammern des Wahnsinns",
  },
-- 7 location dungeons
  [27] = { -- Any, Imperial City, IC Prison
    N = "Gefängnis",
  },
  [28] = { -- Any, Imperial City, WG Tower
    N = "Weißgoldturm",
  },
-- Shadows of the Hist DLC dungeons
  [29] = { -- Any, Shadowfen, Ruins of Mazzatun
    N = "Mazzatun",
  },
  [30] = { -- Any, Shadowfen, Cradle of Shadows
    N = "Wiege der Schatten",
  },
-- Horns of the Reach DLC dungeons
  [31] = { -- Any, Craglorn, Bloodroot Forge
    N = "Blutquellschmiede",
  },
  [32] = { -- Any, Craglorn, Falkreath Hold
    N = "Falkenring",
  },
-- Dragon Bones DLC dungeons
  [33] = { -- DC, Bangkorai, Fang Lair
    N = "Krallenhort",
  },
  [34] = { -- DC, Stormhaven, Scalecaller Peak
    N = "Gipfel der Schuppenruferin",
  },
-- Wolfhunter DLC dungeons
  [35] = { -- AD, Reaper`s March, Moon Hunter Keep
    N = "Mondjägerfeste",
  },
  [36] = { -- AD, Greenshade, March of Sacrifices
    N = "Marsch der Aufopferung",
  },
-- Wrathstone DLC dungeons
  [37] = { -- EP, Eastmarch, Frostvault
    N = "Frostgewölbe",
  },
  [38] = { -- Any, Gold Coast, Depths of Malatar
    N = "Tiefen von Malatar",
  },
-- Scalebreaker DLC dungeons
  [39] = { -- Any, Elsweyr, Moongrave Fane
    N = "Mondgrab-Tempelstadt",
  },
  [40] = { -- AD, Grahtwood, Lair of Maarselok
    N = "Der Hort von Maarselok",
  },
-- Harrowstorm DLC dungeons
  [41] = { -- Any, Wrothgar, Icereach
    N = "Eiskap",
  },
  [42] = { -- DC, Bangkorai, Unhallowed Grave
    N = "Unheiliges Grab",
  },
-- Stonethorn DLC dungeons
  [43] = { -- Any, Blackreach, Stone Garden
    N = "Steingarten",
  },
  [44] = { -- Any, Western Skyrim, Castle Thorn
    N = "Kastell Dorn",
  },
-- Flames of Ambition DLC dungeons
  [45] = { -- Any, Gold Coast, Black Drake Villa
    N = "Schwarzdrachenvilla",
  },
  [46] = { -- EP, Deshaan, The Cauldron
    N = "Der Kessel",
  },
-- Waking Flame DLC dungeons
  [47] = { -- DC, Glenumbra, Red Petal Bastion
    N = "Rotblütenbastion",
  },
  [48] = { -- Any, Blackwood, The Dread Cellar
    N = "Der Schreckenskeller",
  },
-- Ascending Tide DLC dungeons
  [49] = { -- Any, Summerset, Coral Aerie
    N = "Der Korallenhorst",
  },
  [50] = { -- DC, Rivenspire, Shipwright's Regret
    N = "Gram des Schiffbauers",
  },
-- Lost Depths DLC dungeons
  [51] = { -- Any, High Isle, Earthen Root Enclave
    N = "Erdwurz-Enklave",
  },
  [52] = { -- Any, High Isle, Graven Deep
    N = "Kentertiefen",
  },
-- Scribes of Fate DLC dungeons
  [53] = { -- EP -> Stonefalls - Bal Sunnar
    N = "Bal Sunnar",
  },
  [54] = { -- EP -> The Rift - Scrivener's Hall
    N = "Halle der Schriftmeister",
  },
-- Scions of Ithelia DLC dungeons
  [55] = { -- Any -> The Reach - Oathsworn Pit
    N = "Grube der Eidgeschworenen",
  },
  [56] = { -- Any -> Wrothgar - Bedlam Veil
    N = "Schleier des Aufruhrs",
  },
-- Fallen Banners DLC dungeons
  [57] = { -- Any -> The Gold Road - Exiled Redoubt
    N = "Schanze der Abgeschiedenen",
  },
  [58] = { -- Any -> Hew's Bane - Lep Seclusa
    N = "Lep Seclusa",
  },
-- Feast of Shadows DLC dungeons
  [59] = { -- Any -> Solstice - Naj-Caldeesh
    N = "Naj-Caldeesh",
  },
  [60] = { -- Any -> Solstice - Black Gem Foundry
    N = "Schwarzstein-Gießerei",
  },
} -- Dungeons end
WPamA.i18n.DailyBoss = {
-- Wrothgar
  [1]  = {C = "Besiegt Zandadunoz die Wiedergeborene",}, -- ZANDA
  [2]  = {C = "Besiegt Nyzchaleft",}, -- NYZ
  [3]  = {C = "Besiegt Königshäuptling Edu",}, -- EDU
  [4]  = {C = "Besiegt den verrückten Urkazbur",}, -- OGRE
  [5]  = {C = "Haltet die Wilderer auf",}, -- POA
  [6]  = {C = "Besiegt Corintthac die Abscheulichkeit",}, -- CORI
-- Vvardenfell
  [7]  = {C = "Besiegt den Gemahl der Königin",}, -- QUEEN
  [8]  = {C = "Besiegt Orator Salothan",}, -- SAL
  [9]  = {C = "Besiegt Nilthog den Ungebrochenen",}, -- NIL
  [10] = {C = "Besiegt Wuyuvus",}, -- WUY
  [11] = {C = "Haltet das Experiment von Dubdil Alar auf",}, -- DUB 
  [12] = {C = "Besiegt Kimbrudhil den Singvogel",}, -- SIREN
-- Gold Coast
  [13] = {C = "Erobert die Arena von Kvatch",}, -- ARENA
  [14] = {C = "Sichert die Ausgrabungsstätte",}, -- MINO
-- Summerset
  [15] = {C = "Tötet die Königin des Riffs",}, -- QUEEN
  [16] = {C = "Tötet Kielspalter",}, -- KEEL
  [17] = {C = "Tötet Caanerin",}, -- CAAN
  [18] = {C = "Tötet B'Korgen",}, -- KORG
  [19] = {C = "Tötet Graveld",}, -- GRAV
  [20] = {C = "Tötet Haeliata und Nagravia",}, -- GRYPH
-- Northern Elsweyr
  [21] = {C = "Tötet Na'ruzz den Knochenweber",}, -- NARUZ
  [22] = {C = "Tötet Thannar den Grablotter",}, -- THAN
  [23] = {C = "Tötet Akumjhargo und Zav'i",}, -- ZAVI
  [24] = {C = "Tötet Schwertmeisterin Vhysradue",}, -- VHYS
  [25] = {C = "Tötet die listige Kee'va",}, -- KEEVA
  [26] = {C = "Tötet Zalsheem",}, -- ZAL
-- Western Skyrim
  [27] = {C = "Tötet Ysmgar",}, -- YSM
  [28] = {C = "Tötet die Werwölfe",}, -- WWOLF
  [29] = {C = "Tötet Skreg den Unbezwingbaren",}, -- SKREG
  [30] = {C = "Tötet Schattenmutter",}, -- SHADE
-- Blackreach: Greymoor Caverns
  [31] = {C = "Säubert die Jagdgründe der Vampire",}, -- VAMP
  [32] = {C = "Tötet Demontierer den Dwemerkoloss",}, -- DISM
-- Blackwood
  [33] = {C = "Besiegt die Alte Todeswarze",}, -- FROG
  [34] = {C = "Besiegt Xeemhok den Trophäennehmer",}, -- XEEM
  [35] = {C = "Besiegt die Sul-Xan-Ritualisten",}, -- SUL
  [36] = {C = "Besiegt Ghemvas den Vorboten",}, -- RUIN
  [37] = {C = "Besiegt Bhrum-Koska",}, -- BULL
  [38] = {C = "Besiegt Kriegshäuptling Zathmoz",}, -- ZATH
-- High Isle
  [39] = {C = "Tötet Schlangenruferin Vinsha",}, -- VIN
  [40] = {C = "Zerstört den Zobelritter",}, -- SAB
  [41] = {C = "Tötet die Fanatiker des Ordens der Emporstrebenden",}, -- SHAD
  [42] = {C = "Tötet Glemyos Wildhorn",}, -- WILD
  [43] = {C = "Tötet die Ahngezeiten-Theurgen",}, -- ELD
  [44] = {C = "Tötet die Hadoliden-Matrone",}, -- HAD
-- Necrom
  [45] = {C = "Besiegt den Wandelnden Albtraum",}, -- WNM
  [46] = {C = "Besiegt Corlys den Kettenschmied",}, -- CORL
  [47] = {C = "Besiegt Vor-Kuul-Sha",}, -- VRO
  [48] = {C = "Besiegt Valkynaz Dek",}, -- DEK
  [49] = {C = "Besiegt den Obersten Katalogisierer",}, -- CATL
  [50] = {C = "Besiegt Runenmeister Xiomara",}, -- XIOM
-- Gold Road
  [51] = {C = "Besiegt Weber Urthrendir",}, -- URTH
  [52] = {C = "Besiegt Stri den Schicksalsfresser",}, -- STRI
  [53] = {C = "Besiegt Reißzahn und Kralle",}, -- FANG
  [54] = {C = "Besiegt Hessedaz den Unheilvollen",}, -- HESS
  [55] = {C = "Besiegt Anführer der Rückbesinnung",}, -- RECO
  [56] = {C = "Besiegt Eichenkralle",}, -- OAK
-- Solstice
  [57] = {C = "Besiegt Gezeitentücke"}, -- TIDE
  [58] = {C = "Besiegt Gaulm"}, -- GAULM
  [59] = {C = "Besiegt die Voskrona-Wächter"}, -- VOSK
  [60] = {C = "Besiegt die Seelenruferin"}, -- SCALL
  [61] = {C = "Besiegt Wo-xeeth"}, -- WOXET
  [62] = {C = "Besiegt Ghishzor"}, -- GHISH
}
WPamA.i18n.DayOfWeek = {
  [0] = "So",
  [1] = "Mo",
  [2] = "Di",
  [3] = "Mi",
  [4] = "Do",
  [5] = "Fr",
  [6] = "Sa",
}
WPamA.i18n.Chat = {
  Today = "Heutige Gelöbnisse: (von <<2>> <<1>>): ",
  Anyday = "Gelöbnisse: (von <<2>> <<1>>): ",
  Loot  = " (<<1>>)",
  Addon = " (AddOn <<1>> v<<X:2>>)",
  Dlmtr = "; ",
}
WPamA.i18n.RGLA = {
  CZ = "/z",
  CL = "/g1",
  CP = "/p",
  F1 = "<<1>> LFM <<2>> kann quest teilen.",
  F2 = " Für automatisches Einladen und Quest teilen schreibe <<1>>",
  F3 = " Für automatisches Einladen <<1>>",
--F4 = "",
  F5 = " ( <<1>> ).",
  F6 = "<<1>> LFM \"<<2>>\", auto-Einladen / Quest teilen",
  F7 = "<<1>> LFM \"<<2>>\", auto-einladen",
  F8 = "<<1>> <<2>> startet in 1 Min.",
  F9 = "/p START <<1>>",
  F10 = "<<1>> <<2>> ist gefallen",
  F11 = "/p Quest wurde automatisch geteilt. Vielleicht hast du noch eine andere Tages Boss-Quest aktiv, oder diese Quest heute bereits .",
  F12 = "AddOn <<1>> v<<2>> von ESOUI.COM: Der Tracker für Gelöbnisse, Trials und tägliche Welt-Bosse, Auto-Einladen und Quest-teilen.",
}
