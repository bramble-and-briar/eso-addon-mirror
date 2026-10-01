local Icon = WPamA.Consts.IconsW
local GetIcon = WPamA.Textures.GetTexture
local OpenWindowText = GetString(SI_ENTER_CODE_CONFIRM_BUTTON)
local DynamicEncounterText = GetString(SI_HUD_EDITOR_DYNAMIC_EVENT_TRACKER)
WPamA.i18n = {
  Lng = "FR",
-- DateTime settings
  DateTimePart = {dd = 0, mm = 1, yy = 2, },
  DateFrmt = 2, -- 1 default:m.d.yyy ; 2:yyyy-mm-dd; 3:dd.mm.yyyy; 4:yyyy/mm/dd; 5:dd.mm.yy; 6:mm/dd; 7:dd.mm
  DateFrmtList = {"ESO par défaut","aaaa-mm-jj","jj.mm.aaaa","aaaa/mm/jj","jj.mm.aa","mm/jj","jj.mm"},
  DayMarker = "j",
  MetricPrefix = {"K","M","G","T","P","E"},
  CharsOrderList = {"ESO par défaut","Noms","Alliance, Noms","Niveau max, Noms","Niveau min, Noms","Alliance, Niveau max","Alliance, Niveau min"},
-- Marker (substring) in active quest step text for detect DONE stage
  DoneM = {
    [1] = "Retournez",
    [2] = "Parlez",
  },
-- Keybinding string
  KeyBindShowStr  = "Afficher/Masquer la fenêtre",
  KeyBindChgWStr  = "Ouvrir la fenêtre suivante",
  KeyBindChgTStr  = "Ouvrir l'onglet suivant de la fenêtre",
  KeyBindChgAStr  = "Ouvrir l'onglet suivant de l'addon",
  KeyFavRadMenu   = "Menu radial des onglets favoris",
  KeyBindCharStr  = "Afficher les serments des personnages",
  KeyBindClndStr  = "Afficher le calendrier des serments",
  KeyBindPostTd   = "Publiez les serments d'aujourd'hui sur le chat (EN)",
  KeyBindPostTdCL = "Publiez les serments d'aujourd'hui sur le chat (FR)",
  KeyBindWindow0  = OpenWindowText .. ": " .. "Donjons de groupe",
  KeyBindWindow1  = OpenWindowText .. ": " .. "Épreuves",
  KeyBindWindow2  = OpenWindowText .. ": " .. GetString(SI_ZONECOMPLETIONTYPE9),
  KeyBindWindow3  = OpenWindowText .. ": " .. "Compétences",
  KeyBindWindow4  = OpenWindowText .. ": " .. GetString(SI_BINDING_NAME_TOGGLE_INVENTORY),
  KeyBindWindow5  = OpenWindowText .. ": " .. GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKCATEGORIES1),
  KeyBindWindow6  = OpenWindowText .. ": " .. GetString(SI_MAPFILTER14),
  KeyBindWindow7  = OpenWindowText .. ": " .. GetString(SI_JOURNAL_MENU_ACHIEVEMENTS) ..
                    ", " .. GetString(SI_COLLECTIONS_MENU_ROOT_TITLE),
  KeyBindWindow8  = OpenWindowText .. ": " .. GetString(SI_QUEST_JOURNAL_GENERAL_CATEGORY),
  KeyBindRGLA     = "Afficher/Cacher RGLA (Assistant pour Chef de Groupe Raid)",
  KeyBindRGLASrt  = "RGLA: Démarrer",
  KeyBindRGLAStp  = "RGLA: Arrêter",
  KeyBindRGLAPst  = "RGLA: Publier dans le chat",
  KeyBindRGLAShr  = "RGLA: Partager la quête",
  KeyBindLFGP     = "GFP: Démarrer/arrêter la recherche",
  KeyBindLFGPMode = "GFP: Sélection du mode",
-- Caption
  Wind = {
    [0] = {
      Capt = "Donjons de groupe",
      Tab = {
        [1] = {N="Serments", W=76},
        [2] = {N="Calendrier", W=83},
        [3] = {N="Activité aléatoire", W=134},
        [4] = {N=GetString(SI_ENDLESS_DUNGEON_LEADERBOARDS_CATEGORIES_HEADER), W=181},
      },
    },
    [1] = {
      Capt = "Épreuves",
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
        [ 3] = {N=GetIcon(22,28), NC=GetIcon(22,28,true), W=28, S=true, A="La Côte d'or"},
        [ 4] = {N=GetIcon(26,26), NC=GetIcon(26,26,true), W=28, S=true, A="Le Couchant"},
        [ 5] = {N=GetIcon(28,26), NC=GetIcon(28,26,true), W=28, S=true, A="Le Nord d'Elsweyr"},
        [ 6] = {N=GetIcon(30,28), NC=GetIcon(30,28,true), W=28, S=true, A="Le Bordeciel occidental"},
        [ 7] = {N=GetIcon(34,28), NC=GetIcon(34,28,true), W=28, S=true, A=GetString(SI_CHAPTER5)}, -- "Le Bois noir"
        [ 8] = {N=GetIcon(40,28), NC=GetIcon(40,28,true), W=28, S=true, A=GetString(SI_CHAPTER6)}, -- "Île-Haute"
        [ 9] = {N=GetIcon(42,28), NC=GetIcon(42,28,true), W=28, S=true, A=GetString(SI_CHAPTER7)}, -- "Necrom"
        [10] = {N=GetIcon(43,28), NC=GetIcon(43,28,true), W=28, S=true, A=GetString(SI_CHAPTER8)}, -- "Le Weald Occidental"
        [11] = {N=GetIcon(66,28), NC=GetIcon(66,28,true), W=28, S=true, A=GetString(SI_CHAPTER9)}, -- "Solstice"
      },
    },
    [3] = {
      Capt = "Compétences",
      Tab = {
        [1] = {N="Classe & AcA", W=105},
        [2] = {N="Artisanat", W=74},
        [3] = {N="Guilde", W=52},
        [4] = {N="Monde", W=58},
        [5] = {N=GetIcon(27,28), NC=GetIcon(27,28,true), W=28, S=true, A=GetString(SI_STATS_RIDING_SKILL)},
        [6] = {N=GetIcon(22,28), NC=GetIcon(22,28,true), W=28, S=true, A="Fournisseur des ombres"},
        [7] = {N=zo_strformat("<<1>><<2>><<3>>", GetIcon(57,22), GetIcon(58,22), GetIcon(59,22)),
               NC=zo_strformat("<<1>><<2>><<3>>", GetIcon(57,22,true), GetIcon(58,22,true), GetIcon(59,22,true)),
               W=70, S=true, A=GetString(SI_STAT_GAMEPAD_CHAMPION_POINTS_LABEL)},
      },
    },
    [4] = {
      Capt = GetString(SI_BINDING_NAME_TOGGLE_INVENTORY),
      Tab = {
        [1] = {N="Monnaie", W=71},
        [2] = {N="Articles", W=63},
        [3] = {N=GetIcon(32,24), NC=GetIcon(32,24,true), W=28, S=true, A="Parchemins d'Expérience"},
        [4] = {N=GetIcon(60,24), NC=GetIcon(60,24,true), W=28, S=true, A="Géodes de transmutation"},
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
        [2] = {N=GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES5), W=148},
        [3] = {N=GetString(SI_DAILY_LOGIN_REWARDS_TILE_HEADER), W=214},
        [4] = {N="Récompenses & Signes", W=182},
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
               W=70, S=true, A="Compétences: classe, guilde, armure"},
        [4] = {N=zo_strformat("<<1>><<2>><<3>>", GetIcon(48, 24), GetIcon(51, 24), GetIcon(53, 24)),
               NC=zo_strformat("<<1>><<2>><<3>>", GetIcon(48, 24, true), GetIcon(51, 24, true), GetIcon(53, 24, true)),
               W=70, S=true, A="Compétences: arme"},
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
        [1] = {N="Festivals saisonniers", W=164},
        [2] = {N=GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES803), W=70},
        [3] = {N=GetString(SI_RECIPECRAFTINGSYSTEM6), W=100},
        [4] = {N=GetString(SI_QUESTTYPE19), W=100}, -- Favors
      },
    },
    [8] = {
      Capt = GetString(SI_QUEST_JOURNAL_GENERAL_CATEGORY), -- "Miscellaneous"
      Tab = {
        [1] = {N=GetString(SI_TIMED_ACTIVITIES_TITLES), W=102},
        [2] = {N="Commande", W=78},
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
      HdT = { [1] = "Le total", [2] = "Utilisé", [3] = "Libérer" }
    },
--------
    [42] = {
      HdT = {
        [1] = GetString(SI_COLLECTIBLERESTRICTIONTYPE1), -- Race
        [2] = GetString(SI_COLLECTIBLERESTRICTIONTYPE3), -- Class
        [3] = "PdC", [4] = "Dernière connexion", [5] = "Temps joué"
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
  SelModeWin = {x = 210, y = 2, dy = 24},
-- Labels
  TotalRow = {[1] = "BANQUE", [2] = "TOTAL"},
  HdrLvl = "Niv.",
  HdrName = "Nom",
  HdrClnd = "Calendrier",
  HdrMaj = "Maj",
  HdrGlirion = "Glirion",
  HdrUrgarlag = "Urgarlag",
  HdrLFGReward = "Récompense violette",
  HdrLFGRnd  = "Donjon",
  HdrLFGBG   = "Battlegrounds",
  HdrLFGTrib = GetString(SI_ACTIVITY_FINDER_CATEGORY_TRIBUTE),
  HdrAvAReward = GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES705),
  SendInvTo = "Invitation envoyée à <<1>>",
  ShareSubstr = "share",
  EndeavorTypeNames = {
    [1] = zo_strformat(SI_TIMED_ACTIVITIES_TYPE_HEADER, GetString(SI_TIMEDACTIVITYTYPE0)),
    [2] = zo_strformat(SI_TIMED_ACTIVITIES_TYPE_HEADER, GetString(SI_TIMEDACTIVITYTYPE1)),
    [3] = zo_strformat(SI_TIMED_ACTIVITIES_TYPE_HEADER, GetString(SI_TIMEDACTIVITYTYPE2))
  },
  EndeavorRepeat = "Répéter",
  PromoEventName = GetIcon(47, 20, true) ..
                   GetString(SI_ACTIVITY_FINDER_CATEGORY_PROMOTIONAL_EVENTS) .. " : <<1>>",
  NoWorldEventsHere = "Il n'y a pas d'événements mondiaux ici",
  WECalculating = "Calculateur",
  WEDistance = "Distance",
-- Pledge Quest Givers NPC names
  PledgeQGivers = {
    [1] = "Maj al-Ragath",
    [2] = "Glirion Barbe-Rousse",
    [3] = "Urgarlag l'Émasculatrice",
  },
-- Shadowy-Supplier NPC name
  ShadowySupplier = {
    ["Garde-le-Silence"] = true,
  },
  ComeBackLater = "Revenez plus tard",
-- Replace text for long companion equipment names
  CompanionEquipRepl = {
    CompTitle = " de compagnon",
   --- Trait names replacement ---
    ["Aucun trait"] = {[3] = "non", [4] = "non"},
    ["Aggressif"]   = {[4] = "Aggr"},
    ["Augmenté"]    = {[4] = "Augm"},
    ["Renforcé"]    = {[4] = "Renf"},
    ["Focalisé"]    = {[4] = "Focal"},
    ["Accéléré"]    = {[4] = "Accél"},
    ["Accéléré "]   = {[4] = "Accél"},
    ["Prolifique"]  = {[4] = "Prol"},
    ["Apaisant"]    = {[4] = "Apais"},
    ["Écrasant"]    = {[4] = "Écras"},
    ["Vigoureux"]   = {[4] = "Vigo"},
   --- Item names replacement ---
    ["Chaussures"]       = {[1] = "Chauss."},
    ["Coques d'épaules"] = {[1] = "Coq.épaul."},
    ["Bâton de rétablissement"] = {[1] = "Bâton de rétab."},
   --- Item types replacement ---
    [SI_EQUIPTYPE5] = {[4] = "1M"}, -- "One-Handed"
    [SI_EQUIPTYPE6] = {[4] = "2M"}, -- "Two-Handed"
  },
-- Addon Options Menu
--> 1
  OptGeneralHdr = "Réglages généraux",
  OptCharsOrder = "Ordre des personnages",
  OptCharsOrderF = "Choix de l'ordre dans lequel les personnages sont affichés dans la fenêtre de l'extension. Rechargement de l'IU nécessaire. Les personnages sont triés uniquement au lancement de l'extension et, plus tard, l'ordre ne change pas.",
  OptAlwaysMaxWinX  = "Largeur fixe de la fenêtre principale",
  OptAlwaysMaxWinXF = "Si l'option est activée, la fenêtre principale de l'extension aura toujours la même largeur dans tous les modes. Si elle est désactivée, la largeur de la fenêtre principale variera en fonction du mode.",
  OptLocation = "Afficher la zone plutôt que le nom du donjon",
  OptENDungeon = "Afficher les noms des donjons en Anglais", 
  OptDontShowNone  = "Afficher un blanc à la place de \"aucun\"",
  OptDontShowReady = "Afficher un blanc à la place de \"Prêt\"",
  OptTitleToolTip = "Activer les astuces pour la fenêtre de titre",
  OptHintUncomplPlg  = "Serments dans les donjons inachevés",
  OptHintUncomplPlgF = table.concat( {
                       "Afficher des indices sur des serments d'aujourd'hui dans la fenêtre Serments des Indomptables si ces donjons ne sont pas encore terminés.\n",
                       "Un donjon est considéré comme incomplet si la quête d'histoire n'est pas terminée ou si tous les boss n'ont pas été tués.\n",
                       "(un donjon doit être disponible/débloqué pour le compte ou le personnage)",
                       } ),
  OptLargeCalend  = "Afficher le calendrier des Serments pour...",
  OptLargeCalendF = "Sélectionnez le nombre de jours dans le calendrier des Serments",
  OptDateFrmt  = "Format de la date",
  OptDateFrmtF = "Sélectionnez le format d'affichage des dates dans le calendrier",
  OptShowTime  = "Affiche aussi l'heure après la date",
  OptLFGRndAvl  = "Le format des courtes périodes de temps",
  OptLFGRndAvlF = "Sélectionnez le format des périodes courtes (moins de 24 heures), telles que la récompense quotidienne pour les activités aléatoires, le fournisseur ténébreux, la compétence d'équitation, etc.",
  OptTrialAvl  = "Le format des longues périodes de temps",
  OptTrialAvlF = "Sélectionnez le format des longues périodes (plus de 24 heures), comme la récompense hebdomadaire pour les essais, etc.",
  OptTimerList = {"Compte à rebours","date et heure (MM/JJ hh:mi)","date et heure (JJ.MM hh:mi)"},
  OptRndDungDelay = "Temps d'attente de la récompense quotidienne",
  OptRndDungDelayF = "Le temps (en secondes) à attendre les informations du serveur du jeu sur les récompenses quotidiennes pour les activités de Donjon Aléatoire terminées. La valeur par défaut (5 secondes) peut être modifiée seulement quand l'extension affiche \"???\" au lieu d'un compte à rebours après une reconnexion ou un rechargement de l'IU.",  
  OptShowMonsterSetTT = "Astuce pour les Ensembles de Monstres",
  OptShowMonsterSetTTF = "Afficher une bulle d'aide pour les Ensembles de Monstres dans les modes  \"Serments des Indomptables\" et \"Calendrier des serments\".",
  OptMouseModeUI = "Affiche le pointeur de la souris",
  OptMouseModeUIF = "Affiche le pointeur de la souris pendant que la fenêtre de l’addon est ouverte",
  OptCharNamesMenu = "Noms des personnages",
  OptCharNameColor = "Afficher les noms dans la couleur d'Alliance",
  OptCharNameAlign = "Alignement des noms",
  OptNamesAlignList = {"gauche", "centré", "droite"},
  OptCorrLongNames = "Correction de l'affichage des noms longs",
  OptNamesCorrList = {"ne rien faire", "taille de la police", "couper au milieu", "masquer le texte"},
  OptNamesCorrRepl = {"Trouver ce texte dans le nom", "et le remplacer par ce texte"},
  OptCurrencyValThres = "Arrondir les valeurs des devises à...",
  OptCurrencyValThresF = table.concat(
                         { "À quels chiffres arrondir les valeurs des devises.\n",
                           GetString(SI_GAMEPAD_CURRENCY_SELECTOR_HUNDREDS_NARRATION),      " : 123 K\n",
                           GetString(SI_GAMEPAD_CURRENCY_SELECTOR_THOUSANDS_NARRATION),     " : 1234 K\n",
                           GetString(SI_GAMEPAD_CURRENCY_SELECTOR_TEN_THOUSANDS_NARRATION), " : 12345 K"
                         } ),
  OptDynEncounterNotify = zo_strformat("<<1>>: <<2>>", DynamicEncounterText, GetString(SI_MAIN_MENU_NOTIFICATIONS)),
  OptDynEncounterNotifyF = table.concat(
                           { "Afficher des notifications à l'écran et dans le chat concernant le début, ",
                             "l'activité, la fin et la progression des Rencontres Dynamiques.\n\n",
                             GetString(SI_ACTIONBARSETTINGCHOICE2), " - masquer les notifications pendant qu'un personnage ",
                             "participe à une Rencontre, sinon afficher les notifications de Rencontre Dynamique."
                           } ),
  OptCompanionRapport = "Afficher la relation de compagnons comme...",
  OptCompanionRprtList = {"de nombre", "de texte"},
  OptCompanionRprtMax = "Afficher la valeur maximale",
  OptCompanionEquip = "Afficher l'équipement de compagnons comme...",
  OptCompanionEquipList = {"nom d'article", "type d'article", "trait d'article", "type et trait"},
--> 2
  OptModeSetHdr = "Réglages d'option et de mode",
  OptAutoActionsHdr = "Automatisation des activités quotidiennes",
  OptAutoTakeUpPledges = "Accepter automatiquement les serments",
  OptAutoTakeUpPledgesF = "Accepter automatiquement les quêtes de serment des Indomptables lorsque vous intéragissez avec les PNJ",
  OptAutoTakeDBSupplies = "Auto-recevez les fournitures de la Confrérie noire",
  OptAutoTakeDBSuppliesF = "Recevez automatiquement des articles bénéfiques (fournitures) lors d'une conversation avec le fournisseur ténébreux",
  OptAutoTakeDBList = {"pour tout le compte", "dépend du personnage"},
  OptChoiceDBSupplies = "Quel type de fournitures recevoir...",
  OptDBSuppliesList = {"ne rien faire", "du poison/des potions", "passer inaperçu(e)", "de l'équipement"},
  OptAutoChargeWeapon = "Charger automatiquement les armes",
  OptAutoChargeWeaponF = "Rechargez automatiquement l'arme si la charge actuelle est inférieure au seuil minimum.\n" ..
                         "L'inventaire du personnage doit contenir au moins 1 pierre d'âme remplie.",
  OptAutoChargeThreshold = "Seuil de charge minimum",
  OptAutoChargeThresholdF = "L'arme sera chargée lorsque la charge d'enchantement restante sera inférieure à cette valeur",
  OptAutoCallEyeInfinite = "Invoquez automatiquement un " .. GetCollectibleName(WPamA.EndlessDungeons.EyeOfInfinite.C),
  OptAutoCallEyeInfiniteF = table.concat(
                            { "Invoquez automatiquement un |t20:20:",
                              GetCollectibleIcon(WPamA.EndlessDungeons.EyeOfInfinite.C), "|t",
                              GetCollectibleName(WPamA.EndlessDungeons.EyeOfInfinite.C),
                              " dans les zones d'archives infinies.\n\nCette option est disponible lorsque l'outil est disponible sur le compte."
                            } ),
  ---
--  OptEndeavorRewardMode = "Afficher les récompenses du défi comme...",
--  OptEndeavorRewardList = {"unique", "actuel", "maximum"},
  OptEndeavorChatMsg  = "Afficher la progression du défi dans le chat",
  OptEndeavorChatMsgF = "Afficher des informations dans la fenêtre de discussion lorsque la progression du défi change",
  OptEndeavorChatChnl = "Canal le chat pour les notifications du défi",
  OptEndeavorChatChnlF = "Canal le chat pour afficher des informations sur la progression du défi",
  OptEndeavorChatColor = "Couleur de notification de progression",
  OptEndeavorChatColorF = "Ajuste la couleur des notifications de progression",
  OptEndeavorAutoClaim = "Auto-réclamez les récompenses des défis",
  OptEndeavorHideCompl = "Masquer les défis terminés",
  OptPursuitChatMsg  = "Afficher la progression des poursuite dans le chat",
  OptPursuitChatMsgF = "Afficher les changements de progression des Poursuites dorées dans le chat",
  OptPursuitChatCamp  = "Jusqu'à ce qu'une récompense de campagne soit gagnée",
  OptPursuitChatCampF = "Si activé, la progression de la poursuite est affichée jusqu'à l'obtention d'une récompense de campagne.\n" ..
                        "Si désactivé, la progression de la poursuite est toujours affichée.",
--  OptPursuitChatChnl = "Canal le chat pour les notifications de poursuite",
  OptPursuitChatChnlF = "Canal le chat pour afficher des informations sur la progression des Poursuites dorées",
  OptPursuitAutoClaim = "Auto-réclamez les récompenses des poursuites",
  ---
  OptLFGPHdr = "Recherche de Groupe pour les Serments",
  OptLFGPOnOff = "Utiliser la Recherche de Groupe pour les Serments",
  OptLFGPMode = "Défini aussi le mode du groupe en...",
  OptLFGPModeList = {zo_strformat("toujours <<1>><<1>><<1>> (<<2>>)", Icon.Norm, Icon.LfgpKeys[1]), -- NNN
                     zo_strformat("toujours <<1>><<1>><<2>> (<<3>>)", Icon.Vet, Icon.Minus, Icon.LfgpKeys[2]), -- VV-
                     zo_strformat("toujours <<1>><<1>><<2>> (<<3>>)", Icon.Vet, Icon.Norm, Icon.LfgpKeys[3]), -- VVN
                     zo_strformat("toujours <<1>><<1>><<1>> (<<2>>)", Icon.Vet, Icon.LfgpKeys[4]), -- VVV
                     "dépend du personnage"},
  OptLFGPIgnPledge = "Ignorer case à cocher \"Serment terminé\"",
  OptLFGPAlert = "Notifier à l'écran",
  OptLFGPChat = "Notifier dans le chat",
  OptLFGPModeRoult = zo_strformat("Rechercher <<1>>/<<2>> pour les Serments obsolètes", Icon.Vet, Icon.Norm),
  OptLFGPModeRoultF = table.concat(
                      { "Dans le cas où de Recherche de Groupe est défini sur le mode Vétéran ",
                        "et que le personnage a une quête pour un Serment obsolète (et non actuel), ",
                        "ce paramètre vous permet également de rechercher un groupe pour le mode Normal.\n\n",
                        "Si activé, recherchez un groupe pour n'importe quel mode (",
                        Icon.Vet, " ou ", Icon.Norm, ") - ", Icon.Roult, ".\n",
                        "Si désactivé, recherchez un groupe pour le mode ", Icon.Vet, " uniquement."
                      } ),
--> 3
  OptRGLAHdr = "Réglages du RGLA",
  OptRGLAQAutoShare = "Permet le partage automatique de la quête",
  OptRGLAQAlert = "Notifier à l'écran",
  OptRGLAQChat = "Notifier dans le chat",
  OptRGLABossKilled = "RGLA s'arrête lorsque le boss est tué",
--> 4
  CharsOnOffHdr = "Afficher / Masquer les personnages",
  CharsOnOffNote = "Nota: Votre personnage actif ignorera toujours ces réglages. L'information concernant le personnage actif sera toujours affichée dans tous les modes.",
  OptCharOnOffTtip = "Afficher / masquer personnage \"<<1>>\"",
--> 5
  ModesOnOffHdr = "Afficher / masquer les modes de fenêtre",
  ModesOnOffNote = "Nota: Ces réglages affectent uniquement les changements séquentiels de modes de fenêtre . Vous pouvez masquer les modes de fenêtre , mais au moins un mode de fenêtre devra être visible. Vous pouvez également sélectionner directement le mode de fenêtre souhaité dans le menu contextuel.",
  OptWindOnOffTtip = "Afficher / masquer la fenêtre \n\"<<1>>\"",
  OptModeOnOffTtip = "Afficher / masquer le mode de fenêtre\n\"<<1>>\"",
--> 6
  CustomModeKbdHdr  = "Réglages de liaison de clé personnalisés",
  CustomModeKbdNote = "Nota: Ces paramètres sont applicables à l'ensemble du compte.\nLa personnalisation des touches d'appel de mode vous permet d'attribuer des touches aux modes d'appel de votre choix.",
  OptCustomModeKbd  = GetString(SI_COLLECTIBLECATEGORYTYPE29) .. " <<1>> ...",
--> 7
--  ResetCharNote = "",
  ResetChar = "RAZ personnages",
  ResetCharF = "Réinitialiser la liste des personnages",
  ResetCharWarn = "Toutes les données liées aux personnages seront effacées ! En êtes-vous sûr(e) ?",
-- LFGP texts
  LFGPSrchCanceled = "Recherche de groupe annulée",
  LFGPSrchStarted  = "Recherche de groupe commencée",
  LFGPAlrdyStarted = "Une autre activité est déjà commencée",
  LFGPQueueFailed  = "La création de la file d'attente a échoué",
  LFGP_ErrLeader   = "Vous n'êtes pas Chef de Groupe !",
  LFGP_ErrOverland = "Vous devez être dans une zone principale !",
  LFGP_ErrGroupRole= "Vous devez avoir un rôle dans le groupe !",
-- RGLA texts
  RGLABossKilled = "Le boss a été tué. L'Assistance au Chef du Groupe est arrêté.",
  RGLALeaderChanged = "Le chef du groupe a été changé. RGLA est arrêté.",
  RGLAShare = "Partager",
  RGLAStop = "Arrêter",
  RGLAPost = "Publier",
  RGLAStart = "Démarrer",
  RGLAStarted = "En cours",
  RGLALangTxt = "En Français pour la",
-- RGLA Errors
  RGLA_ErrLeader = "Vous n'êtes pas Chef de Groupe!",
  RGLA_ErrAI = "L'extension AutoInvite n'a pas été trouvée ou n'est pas activée !",
  RGLA_ErrBoss = "Le boss a déjà été tué. RGLA ne peut pas être démarré.",
  RGLA_ErrQuestBeg = "Vous n'avez pas de quête de Groupe de Boss de ",
  RGLA_ErrQuestEnd = "!",
  RGLA_ErrLocBeg = "Vous n'êtes pas ", 
  RGLA_ErrLocEnd = " actuellement!", 
  RGLA_Loc = {
    [ 0] = "à Wrothgar",
    [ 1] = "à Vvardenfell",
    [ 2] = "à la Côte d'Or",
    [ 3] = "au Couchant",
    [ 4] = "au Nord d'Elsweyr",
    [ 5] = "au Bordeciel occidental",
    [ 6] = "à Cavernes de Griselande",
    [ 7] = "au Bois noir",
    [ 8] = "à Île-Haute",
    [ 9] = "à Péninsule Telvanni",
    [10] = "à Apocrypha",
    [11] = "Solstice",
  },
-- Dungeons Status
  DungStDone = "TERMINÉ",
  DungStNA = "N/A",
-- Wrothgar Boss Status
  WWBStNone = "aucun",
  WWBStDone = "TERMINÉ",
  WWBStCur  = "EN COURS",
-- Trials Status
  TrialStNone = "aucun",
  TrialStActv = "ACT",
-- LFG Random Dungeon Status
  LFGRewardReady = "Prêt",
  LFGRewardNA = "N/A",
-- Shadowy Supplier
  ShSuplUnkn = "?",
  ShSuplReady = "Prêt",
  ShSuplNA = "N/A",
-- Login Status
  LoginToday = "Aujourd'hui",
  Login1DayAgo = "Hier",
-- Dynamic Encounter Status
  DynamicEncounter = {
    Icon  = GetIcon(73, 20),
    Title = DynamicEncounterText,
    Start = "L'événement a commencé",
    Stop  = "L'événement est terminé",
    Activ = "L'événement est actif",
    Progr = table.concat({ GetString(SI_ENDLESS_DUNGEON_SUMMARY_PROGRESS_HEADER),
            " ", GetString(SI_SPECTACLE_EVENTS_PROGRESS_PERCENT) })
  },
--
}
WPamA.i18n.ToolTip = {
  [-1] = "",
  [ 0] = Icon.LMB .. " Fermer la fenêtre",
  [ 1] = Icon.LMB .. " Afficher la fenêtre Options",
  [ 2] = Icon.LMB .. " Changer de fenêtre\n" .. Icon.RMB .. " Sélectionner une fenêtre",
  [ 3] = table.concat({ "Poster les serments du jour dans le tchat\n",
                        Icon.LMB, " En anglais\n", Icon.RMB, " En français" }),
  [ 4] = "Votre progression dans l’achèvement des serments",
  [ 5] = "Un calendrier pour les serments actuels et futurs",
  [ 6] = "Votre progression dans l'achèvement des quêtes journalières",
  [ 7] = "Clés des Indomptables, crochets, pierres d'âme et autres...",
  [ 8] = "Vos personnages sont éclairés",
  [ 9] = "Vos personnags ne sont pas éclairés",
  [10] = table.concat({ "Recherche de Groupe pour Serments\n", Icon.LMB, " ", WPamA.i18n.KeyBindLFGP, "\n", Icon.RMB, " ", WPamA.i18n.KeyBindLFGPMode }),
  [11] = "Cristaux de transmutation",
--
  [12] = "Votre progression actuelle dans les compétences de monde.",
  [13] = GetString(SI_STABLE_STABLES_TAB),
  [14] = GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKCATEGORIES1),
  [15] = "Festivals saisonniers",
  [16] = "Votre progression actuelle dans les compétences de guilde.",
  [17] = "Votre progression actuelle dans les compétences de classe et AcA.",
  [18] = "Votre progression actuelle dans les compétences d'artisanat.",
  [19] = "La disponibilité des récompenses d'épreuves hebdomadaires",
  [20] = "Suivi des quêtes quotidiennes pour Donjon Aléatoire et Champs de Bataille",
-- WB Wrothgar
  [21] = "Le Dolmen Inachevé\n - Zanadunoz la Renaissante",
  [22] = "Les Chutes de Nuzchaleft\n - Nuzchaleft le centurion dwemer",
  [23] = "Le Trône du Roi-Chef\n - Roi-Chef Edu",
  [24] = "L'Autel de l'Ogre Fou\n - Urkazbur le Fou",
  [25] = "Le Campement des Braconniers\n - Vieille Snagara",
  [26] = "La Pouponnière Maudite\n - Corintthac l'Abomination",
--
  [27] = "Décompte des succès",
  [28] = "Un effet actif (un bonus) qui augmente le nombre de points d'alliance gagnés",
  [29] = table.concat({ "Recherche de Groupe pour Serments\n",
         Icon.Minus, " - GFP n'est pas activé dans les paramètres du module complémentaire\n",
         GetIcon(62,18), " - nombre possible de clés (avec HM)\n",
         Icon.Norm, "/", Icon.Vet, "/", Icon.Roult, " - Mode Recherche de groupe (devant le nom du donjon)" }),
  [30] = "La récompense violette est disponible",
-- 31-39 Class skills + Guild skills
  [31] = "Compétences de classe : 1ère ligne",
  [32] = "Compétences de classe : 2ème ligne",
  [33] = "Compétences de classe : 3ème ligne",
  [34] = "Guilde des guerriers",
  [35] = "Guilde des mages",
  [36] = "Indomptable",
  [37] = "Guilde des voleurs",
  [38] = "Confrérie noire",
  [39] = "Ordre psijique",
-- 41-47 Craft skills
-- 48-50 AvA skills
  [51] = "La Citadelle D'Hel Ra",
  [52] = "l'Archive Æthérienne",
  [53] = "Sanctum Ophidia",
  [54] = "La Gueule de Lorkhaj",
  [55] = "Les Salles de la Fabrication",
  [56] = "L'Asile Sanctuaire",
  [57] = "Le Pas-des-Nueées",
  [58] = "Sollance",
  [59] = "Égide de Kyne",
--
  [60] = GetString(SI_LEVEL_UP_REWARDS_SKILL_POINT_TOOLTIP_HEADER),
  [61] = "Or",
  [62] = "Assignats",
  [63] = "Points d'alliance",
  [64] = "Pierres de Tel Var",
--65-70 Item name
-- WB Vvardenfell
  [71] = "Mine À Œufs Missir-Dadalit\n - Kwarax, consort de la reine",
  [72] = "Conseil de Salothan\n - Salothan",
  [73] = "Le Creux de Nilthog\n - Nilthog le Sauvage",
  [74] = "La Grange de Sulipund\n - Wuyuvus le Dévoreur",
  [75] = "Tour Dubdil Alar\n - Mehv l'Embobineur",
  [76] = "La Crique des Épaves\n - Kimbrudhil le Canari",
-- WB Gold Coast
  [77] = "L'arène de Kvatch",
  [78] = "La Folie du Tribun\n - Limenauruus",
-- WB Summerset
  [81] = "Le Couvoir de la Reine\n - la Reine du Récif",
  [82] = "Nid de Brise-Quille\n - Brise-Quille",
  [83] = "Cabrioles D'Indrik\n - Caanerin",
  [84] = "Crique de Welenkin\n - B'Korgen",
  [85] = "Refuge de Graveld\n - Graveld",
  [86] = "Cours du Griffon\n - Haeliata et Nagravia",
-- Inventory
  [87] = "Informations sur le remplissage de l'inventaire",
  [88] = "Nombre total de places dans l'inventaire",
  [89] = "Lieux utilisés dans l'inventaire",
  [90] = "Places gratuites dans l'inventaire",
-- WB Northern Elsweyr
  [91] = "La Fosse aux ossements\n - Na'ruzz le Tisseur",
  [92] = "Bord de la Balafre\n - Thannar le Rôdeur sépulcral",
  [93] = "Le Cours des Mains rouges\n - Akumjhargo et Zav'i",
  [94] = "La Colline des Épées brisées\n - la maîtresse d'arme Vhysradue",
  [95] = "La Ravine de la Serre\n - Kee'va la retorse",
  [96] = "Le Plateau du cauchemar\n - Zalsheem",
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
  [107] = "Fournisseur des ombres",
  [108] = "Temps de recharge du Fournisseur des ombres",
  [109] = "Relation avec les compagnons",
  [110] = GetString(SI_STAT_GAMEPAD_CHAMPION_POINTS_LABEL),
  [111] = GetString(SI_CUSTOMERSERVICESUBMITFEEDBACKSUBCATEGORIES212),
-- World Events
  [112] = "", -- an overridden string
  [113] = "", -- an overridden string
  [114] = "", -- an overridden string
  [115] = table.concat({
          GetIcon(14, 24), "- Combien de temps s'est écoulé depuis que l'événement actif a été détecté.\n",
          GetIcon(13, 28), "- Combien de temps s'est écoulé depuis la fin de l'événement." }),
  [116] = "Combien de temps l'événement a été actif.\n(combien de temps a-t-il fallu aux joueurs pour terminer l'événement)",
  [117] = "Temps estimé jusqu'à ce que l'événement mondial soit activé.\n" ..
          "Au moins 2 événements terminés sont nécessaires pour calculer le temps.\n" ..
          "Plus le nombre d'événements terminés est élevé, plus le calcul du temps sera précis.",
  [118] = "HP % - Le niveau de santé du boss de l'événement.\n" ..
          GetIcon(13, 28) .. "- Combien de temps s'est écoulé depuis la fin de l'événement.",
  [119] = "La distance en mètres au boss de l'événement.\nLes informations réelles sur le boss ne peuvent être obtenues qu'à moins de 300 mètres du boss.",
  [120] = "Temps estimé jusqu'à ce que l'événement mondial soit activé.\nDépend du nombre et de l'activité des joueurs dans le lieu.",
-- WB Western Skyrim
  [121] = "Plage d'Ysmgar\n - Géant de mer",
  [122] = "Terrain de chasse de Hordrek\n - Meute de chasse",
  [123] = "Cercle des Champions",
  [124] = "Refuge de la Mère des ombres\n - Mère des ombres",
-- WB Blackreach: Greymoor Caverns
  [125] = "Terrain de chasse de vampire\n - Terrain de chasse",
  [126] = "Station de charge de colosse\n - Colosse dwemer",
--131-136 World skills
-- Endless Dungeon progress
  [158] = table.concat({ "Quête quotidienne\n",
          Icon.Lock, " - la quête d'introduction n'est pas terminée\n",
          Icon.Quest, " - la quête est disponible\n",
          Icon.ChkM, " - la quête terminée" }),
  [159] = "Meilleure progression réalisée\n(pour toutes les exécutions de donjon avec l'addon actif)",
--160-190 Item name
-- Trials
  [191] = "Rochebosque",
  [192] = "Récif des Voiles funestes",
  [193] = "Le Bord de la Folie",
  [194] = "La citadelle lumineuse",
  [195] = "Cage d'Ossein",
-- WB Blackwood
  [201] = "Mare du Vieux Bubemort\n - Vieux Bubemort",
  [202] = "Lagune de Weemhok\n - Xeemhok le collectionneur de trophées",
  [203] = "Site rituel sul-xan\n - Yaxhat Marquemort, Nukhujeema, Shuvh-Mok, Veesha la Mystique",
  [204] = "Le xanmeer écrasé\n - Ghemvas le héraut",
  [205] = "Excavation de Shardius\n - Bhrum",
  [206] = "Camp de guerre des Langue-de-Crapaud\n - chef de guerre Zathmoz",
-- Crafting Writs
  [207] = GetQuestName(WPamA.DailyWrits.QuestIDs[1][1]),
  [208] = GetQuestName(WPamA.DailyWrits.QuestIDs[2][1]),
  [209] = GetQuestName(WPamA.DailyWrits.QuestIDs[3][1]),
  [210] = GetQuestName(WPamA.DailyWrits.QuestIDs[4][1]),
  [211] = GetQuestName(WPamA.DailyWrits.QuestIDs[5][1]),
  [212] = GetQuestName(WPamA.DailyWrits.QuestIDs[6][1]),
  [213] = GetQuestName(WPamA.DailyWrits.QuestIDs[7][1]),
--214-229 Companion Skills
  [214] = "Compétences de classe",
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
  [241] = "Marais des serpents\n - Mande-serpents Vinsha",
  [242] = "Chaudron d'Y'ffre\n - Le Chevalier de Sable",
  [243] = "Creux de Pierre sombre\n - Exécuteur Ascendant, Harceleuse Ascendante",
  [244] = "Chutes du faune\n - Glemyos Cornesauvage",
  [245] = "Bassin d'Amenos\n - Skerard le théurge, Rosara la théurge",
  [246] = "Chutes de Mornard\n - Matriarche Hadolid, Consort Hadolid",
--247-249 Books Category (Init by WPamA:InitLoreBookMode)
-- Hireling mail and crafting profession certification
  [250] = table.concat({ "\n", Icon.Mail, " - Le courrier des mercenaires est disponible (nécessité de se connecter au jeu ou de changer de lieu)",
                         "\n", Icon.NoCert, " - La certification de la profession d'artisan n'est pas terminée" }),
-- WB Necrom
  [251] = "Antre du Cauchemar\n - Cauchemar ambulant",
  [252] = "Cuvette de Tonneclame\n - Corlys l'Enchaîneur",
  [253] = "Marais du Profondicide\n - Vro-Kuul-Sha",
  [254] = "Place Chtonienne\n - valkynaz Dek",
  [255] = "Cathédrale du Libram\n - Indexeur en chef",
  [256] = "Acropole du maître des runes\n - maître des runes Xiomara",
--257-260
-- WB Gold Road
  [261] = "clairière de l'automne\n - trameur Urthrendir",
  [262] = "grotte du Sentier brisé\n - Stri le Mange-destin",
  [263] = "Ascension du Centurion\n - Croc, Serre",
  [264] = "falaises de la Fortune\n - Hessedaz le Funeste",
  [265] = "Berceau de la Frontière\n - les chefs de la Remémorance",
  [266] = "lac Olo\n - Griffe-de-chêne",
-- WB Solstice
  [267] = "Détroit de l'Échouage\n - Marée de haine",
  [268] = "Ruines de Tuniria\n - Gaulm",
  [269] = "Autel de Vakkan\n - les gardiens voskrona",
  [270] = "Hantise de la mande-âmes\n - la mande-âmes",
  [271] = "Antre de Wo-Xeeth\n - Wo-xeeth",
  [272] = "Site rituel de Zyv-Elehk\n - Ghishzor",
--273-280 Item name
}
--
WPamA.i18n.ToolTip[215] = WPamA.i18n.ToolTip[34]
WPamA.i18n.ToolTip[216] = WPamA.i18n.ToolTip[35]
WPamA.i18n.ToolTip[217] = WPamA.i18n.ToolTip[36]
--
WPamA.i18n.RGLAMsg = {
  [1] = "Z: LFM ...",
  [2] = "Z: LFM court",
  [3] = "Z: Démarrer après 1 min",
  [4] = "G: Démarrer après 1 min",
  [5] = "G: Démarrer",
  [6] = "Z: Boss est mort",
  [7] = "G: Vous l'avez déjà fait",
  [8] = "A propos",
}
-- In Dungeons structure:
-- Q - Quest name which indicates the dungeon
-- N - Short name of the dungeon displayed by the addon
WPamA.i18n.Dungeons = {
-- Virtual dungeon
  [1] = { -- None
    N = "Aucun",
  },
  [2] = { -- Unknown
    N = "Inconnu",
  },
-- First location dungeons
  [3] = { -- AD, Auridon, Banished Cells I
    N = "Cachot interdit I",
  },
  [4] = { -- EP, Stonefalls, Fungal Grotto I
    N = "Champignonnière I",
  },
  [5] = { -- DC, Glenumbra, Spindleclutch I
    N = "Tressefuseau I",
  },
  [6] = { -- AD, Auridon, Banished Cells II
    N = "Cachot interdit II",
  },
  [7] = { -- EP, Stonefalls, Fungal Grotto II
    N = "Champignonnière II",
  },
  [8] = { -- DC, Glenumbra, Spindleclutch II
    N = "Tressefuseau II",
  },
-- Second location dungeons
  [9] = { -- AD, Grahtwood, Elden Hollow I
    N = "Creuset des aînés I",
  },
  [10] = { -- EP, Deshaan, Darkshade Caverns I
    N = "Cav. d'Ombre-noire I",
  },
  [11] = { -- DC, Stormhaven, Wayrest Sewers I
    N = "Égouts d'Haltevoie I",
  },
  [12] = { -- AD, Grahtwood, Elden Hollow II
    N = "Creuset des aînés II",
  },
  [13] = { -- EP, Deshaan, Darkshade Caverns II
    N = "Cav. d'Ombre-noire II",
  },
  [14] = { -- DC, Stormhaven, Wayrest Sewers II
    N = "Égouts d'Haltevoie II",
  },
-- 3 location dungeons
  [15] = { -- AD, Greenshade, City of Ash I
    N = "Cité des cendres I",
  },
  [16] = { -- EP, Shadowfen, Arx Corinium
    N = "Arx Corinium",
  },
  [17] = { -- DC, Rivenspire, Crypt of Hearts I
    N = "Crypte des cœurs I",
  },
  [18] = { -- AD, Greenshade, City of Ash II
    N = "Cité des cendres II",
  },
  [19] = { -- DC, Rivenspire, Crypt of Hearts II
    N = "Crypte des cœurs II",
  },
-- 4 location dungeons
  [20] = { -- AD, Malabal Tor, Tempest Island
    N = "Île des Tempêtes",
  },
  [21] = { -- EP, Eastmarch, Direfrost Keep
    N = "Donjon d'Affregivre",
  },
  [22] = { -- DC, Alik`r Desert, Volenfell
    N = "Volenfell",
  },
-- 5 location dungeons
  [23] = { -- AD, Reaper`s March, Selene`s Web
    N = "Toile de Sélène",
  },
  [24] = { -- EP, The Rift, Blessed Crucible
    N = "Creuset béni",
  },
  [25] = { -- DC, Bangkorai, Blackheart Haven 
    N = "Havre de Cœurnoir",
  },
-- 6 location dungeons
  [26] = { -- Any, Coldharbour, Vaults of Madness
    N = "Chambres de la folie",
  },
-- 7 location dungeons
  [27] = { -- Any, Imperial City, IC Prison
    N = "Prison de la CI",
  },
  [28] = { -- Any, Imperial City, WG Tower
    N = "Tour d'Or Blanc",
  },
-- Shadows of the Hist DLC dungeons
  [29] = { -- Any, Shadowfen, Ruins of Mazzatun
    N = "Ruines de Mazzatun",
  },
  [30] = { -- Any, Shadowfen, Cradle of Shadows
    N = "Berceau des ombres",
  },
-- Horns of the Reach DLC dungeons
  [31] = { -- Any, Craglorn, Bloodroot Forge
    N = "Forge de Sangracine",
  },
  [32] = { -- Any, Craglorn, Falkreath Hold
    N = "Forteresse d'Épervine",
  },
-- Dragon Bones DLC dungeons
  [33] = { -- DC, Bangkorai, Fang Lair
    N = "Repaire du croc",
  },
  [34] = { -- DC, Stormhaven, Scalecaller Peak
    N = "Pic de la Mandécailles",
  },
-- Wolfhunter DLC dungeons
  [35] = { -- AD, Reaper`s March, Moon Hunter Keep
    N = "Fort du Chasseur lunaire",
  },
  [36] = { -- AD, Greenshade, March of Sacrifices
    N = "Procession des Sacrifiés",
  },
-- Wrathstone DLC dungeons
  [37] = { -- EP, Eastmarch, Frostvault
    N = "Arquegivre",
  },
  [38] = { -- Any, Gold Coast, Depths of Malatar
    N = "Profondeurs de Malatar",
  },
-- Scalebreaker DLC dungeons
  [39] = { -- Any, Elsweyr, Moongrave Fane
    N = "Lunes funèbres",
  },
  [40] = { -- AD, Grahtwood, Lair of Maarselok
    N = "Repaire de Maarselok",
  },
-- Harrowstorm DLC dungeons
  [41] = { -- Any, Wrothgar, Icereach
    N = "Crève-Nève",
  },
  [42] = { -- DC, Bangkorai, Unhallowed Grave
    N = "Sépulcre profane",
  },
-- Stonethorn DLC dungeons
  [43] = { -- Any, Blackreach, Stone Garden
    N = "Jardin de pierre",
  },
  [44] = { -- Any, Western Skyrim, Castle Thorn
    N = "Bastion-les-Ronce",
  },
-- Flames of Ambition DLC dungeons
  [45] = { -- Any, Gold Coast, Black Drake Villa
    N = "Villa du Dragon noir",
  },
  [46] = { -- EP, Deshaan, The Cauldron
    N = "Le Chaudron",
  },
-- Waking Flame DLC dungeons
  [47] = { -- DC, Glenumbra, Red Petal Bastion
    N = "Bastion du Pétale rouge",
  },
  [48] = { -- Any, Blackwood, The Dread Cellar
    N = "La Cave d'effroi",
  },
-- Ascending Tide DLC dungeons
  [49] = { -- Any, Summerset, Coral Aerie
    N = "Aire de corail",
  },
  [50] = { -- DC, Rivenspire, Shipwright's Regret
    N = "Regret du charpentier",
  },
-- Lost Depths DLC dungeons
  [51] = { -- Any, High Isle, Earthen Root Enclave
    N = "Enclave des Racines de la terre",
  },
  [52] = { -- Any, High Isle, Graven Deep
    N = "Profondeurs mortuaires",
  },
-- Scribes of Fate DLC dungeons
  [53] = { -- EP -> Stonefalls - Bal Sunnar
    N = "Bal Sunnar",
  },
  [54] = { -- EP -> The Rift - Scrivener's Hall
    N = "Salles du",
  },
-- Scions of Ithelia DLC dungeons
  [55] = { -- Any -> The Reach - Oathsworn Pit
    N = "Fosse aux fidèles",
  },
  [56] = { -- Any -> Wrothgar - Bedlam Veil
    N = "Voile des fous",
  },
-- Fallen Banners DLC dungeons
  [57] = { -- Any -> The Gold Road - Exiled Redoubt
    N = "Redoute de l'Exil",
  },
  [58] = { -- Any -> Hew's Bane - Lep Seclusa
    N = "Lep Seclusa",
  },
-- Feast of Shadows DLC dungeons
  [59] = { -- Any -> Solstice - Naj-Caldeesh
    N = "Naj-Caldeesh",
  },
  [60] = { -- Any -> Solstice - Black Gem Foundry
    N = "Fonderie des Pierres noires",
  },
} -- Dungeons end
WPamA.i18n.DailyBoss = {
-- Wrothgar
  [1]  = {C = "Vainquez Zanadunoz la Renaissante",}, -- ZANDA
  [2]  = {C = "Vainquez Nuzchaleft",}, -- NYZ
  [3]  = {C = "Vainquez le Roi-Chef Edu",}, -- EDU
  [4]  = {C = "Vainquez Urkazbur le Fou",}, -- OGRE
  [5]  = {C = "Arrêtez les Braconniers",}, -- POA
  [6]  = {C = "Vainquez Corintthac l'Abomination",}, -- CORI
-- Vvardenfell
  [7]  = {C = "Vainquez Kwarax, Consort de la Reine",}, -- QUEEN
  [8]  = {C = "Vainquez l’Oratrice Salothan",}, -- SAL
  [9]  = {C = "Vainquez Nilthog le Sauvage",}, -- NIL
  [10] = {C = "Vainquez Wuyuvus",}, -- WUY
  [11] = {C = "Arrêtez l'expérience de Dubdil Alar",}, -- DUB
  [12] = {C = "Vainquez Kimbrudhil le Canari",}, -- SIREN
-- Gold Coast
  [13] = {C = "Conquérez l'arène de Kvatch",}, -- ARENA
  [14] = {C = "Nettoyez le Site de Fouille",}, -- MINO
-- Summerset
  [15] = {C = "Tuez la Reine du Récif",}, -- QUEEN
  [16] = {C = "Tuez Brise-Quille",}, -- KEEL
  [17] = {C = "Tuez Caanerin",}, -- CAAN
  [18] = {C = "Tuez B'Korgen",}, -- KORG
  [19] = {C = "Tuez Graveld",}, -- GRAV
  [20] = {C = "Éliminez Haeliata Et Nagravia",}, -- GRYPH
-- Northern Elsweyr
  [21] = {C = "Tuez Na'ruzz le Tisse-os",}, -- NARUZ
  [22] = {C = "Tuez Thannar le Rôdeur sépulcral",}, -- THAN
  [23] = {C = "Tuer Akumjhargo et Zav'i",}, -- ZAVI
  [24] = {C = "Tuez la maîtresse d'arme Vhysradue",}, -- VHYS
  [25] = {C = "Tuez Kee'va la retorse",}, -- KEEVA
  [26] = {C = "Tuez Zalsheem",}, -- ZAL
-- Western Skyrim
  [27] = {C = "Tuez Ysmgar",}, -- YSM
  [28] = {C = "Tuez les loups-garous",}, -- WWOLF
  [29] = {C = "Tuez Skreg l'Invincible",}, -- SKREG
  [30] = {C = "Tuez la Mère d'Ombre",}, -- SHADE
-- Blackreach: Greymoor Caverns
  [31] = {C = "Purger le terrain de chasse des vampires.",}, -- VAMP
  [32] = {C = "Tuez Démanteleur le colosse dwemer",}, -- DISM
-- Blackwood
  [33] = {C = "Vainquez le Vieux Bubemort",}, -- FROG
  [34] = {C = "Vainquez Xeemhok le collectionneur de trophées",}, -- XEEM
  [35] = {C = "Vainquez les adeptes Sul-Xan",}, -- SUL
  [36] = {C = "Vainquez Ghemvas le héraut",}, -- RUIN
  [37] = {C = "Vainquez Bhrum-Koska",}, -- BULL
  [38] = {C = "Vainquez le chef de guerre Zathmoz",}, -- ZATH
-- High Isle
  [39] = {C = "Tuez la mande-serpents Vinsha",}, -- VIN
  [40] = {C = "Détruisez le Chevalier de Sable",}, -- SAB
  [41] = {C = "Vainquez les fanatiques de l'Ordre Ascendant",}, -- SHAD
  [42] = {C = "Tuez Glemyos Cornesauvage",}, -- WILD
  [43] = {C = "Tuez les théurges de la Marée aînée",}, -- ELD
  [44] = {C = "Tuez la matriarche hadolid",}, -- HAD
-- Necrom
  [45] = {C = "Venez à bout du Cauchemard ambulant",}, -- WNM
  [46] = {C = "Vainquez Corlys l'Enchaîneur",}, -- CORL
  [47] = {C = "Vainquez Vro-Kuul-Sha",}, -- VRO
  [48] = {C = "Terrassez le valkynaz Dek",}, -- DEK
  [49] = {C = "Vainquez le Catalogueur Prime",}, -- CATL
  [50] = {C = "Vainquez le maître des runes Xiomara",}, -- XIOM
-- Gold Road
  [51] = {C = "Vainquez le trameur Urthrendir",}, -- URTH
  [52] = {C = "Vainquez Stri la Gobe-destin",}, -- STRI
  [53] = {C = "Vainquez Serre et Croc",}, -- FANG
  [54] = {C = "Vainquez Hessedaz le Funeste",}, -- HESS
  [55] = {C = "Vainquez les chefs de la Remémorance",}, -- RECO
  [56] = {C = "Vainquez Griffe-de-chêne",}, -- OAK
-- Solstice
  [57] = {C = "Tuez Marée de haine"}, -- TIDE
  [58] = {C = "Vainquez Gaulm"}, -- GAULM
  [59] = {C = "Vainquez les gardiens voskrona"}, -- VOSK
  [60] = {C = "Vaincre la mande-âmes"}, -- SCALL
  [61] = {C = "Vainquez Wo-xeeth"}, -- WOXET
  [62] = {C = "Vaincre Ghishzor"}, -- GHISH
}
WPamA.i18n.DayOfWeek = {
  [0] = "Dim",
  [1] = "Lun",
  [2] = "Mar",
  [3] = "Mer",
  [4] = "Jeu",
  [5] = "Ven",
  [6] = "Sam",
}
WPamA.i18n.Chat = {
  Today = "Serments du jour: (du <<2>> <<1>>): ",
  Anyday = "Serments: (du <<2>> <<1>>): ",
  Loot  = " (<<1>>)",
  Addon = " (Extension <<1>> v<<X:2>>)",
  Dlmtr = "; ",
}
WPamA.i18n.RGLA = {
  CZ = "/z",
  CL = "/g1",
  CP = "/p",
  F1 = "<<1>> LFM <<2>>  je partage la quête.",
  F2 = " Pour une invitation et un partage automatiques, tapez <<1>>",
  F3 = " Pour une invitation automatique, tapez <<1>>",
--F4 = "",
  F5 = " ( <<1>> ).",
  F6 = "<<1>> LFM \"<<2>>\", invitation automatique, partage automatique",
  F7 = "<<1>> LFM \"<<2>>\", invitation automatique",
  F8 = "<<1>> <<2>> débute dans 1 minute",
  F9 = "/p <<1>> commence",
  F10 = "<<1>> <<2>> est mort",
  F11 = "/p La quête est partagée automatiquement. Peut-être avez-vous une quête pour un autre boss, ou vous l'avez déjà faite.",
  F12 = "Extension <<1>> v<<2>> de ESOUI.COM: Le suivi pour les quêtes quotidiennes de serments, épreuves et boss de zone, avec invitation et partage automatiques.",
}
