WPamA = {
  Name = "WPamA",
  Version = "2.6.8",
  RGLA_Mode = 0,
  RGLA_Started = false,
  RGLA_QuestJI = 0,
  AICfg = {}, -- For save AutoInvite config
  LastWinUpdTS = 0, -- The timestamp of the last update events of the main window
  Mode67PeriodUpd = 299, -- Default 300 sec
  MaxRidingStat = 60, -- max value for Riding Skills
  PledgeGivers = {},
  ShowMsg = false,
  TbColors = {},
  Today = {},
  EnlitState = false,
  isPlayerActive = false,
  PlayerInZone = { AvA = false, Veng = false, Raid = false, EndDung = false, Dungeon = false },
  ScreenShotMode = false,
}
---
WPamA.Colors = {
  Mdl = {
    [ 1] = "F1FF77", -- AD
    [ 2] = "FF7D77", -- EP
    [ 3] = "779CFF", -- DC
    [ 4] = "CFDCBD", -- Any
    [ 5] = "999999", -- NA
    [ 6] = "77FF77", -- Green for Sun & Sat
    [ 7] = "004000AA", -- centerColor for current char
    [ 8] = "7F8C6D99", -- edgeColor for current char 335544 7F8C6D99
    [ 9] = "D0D0FF", -- Blue 1
    [10] = "3A92FF", -- Blue 2
    [11] = "A02EF7", -- Purple
    [12] = "ADE6FF", -- Light blue (daily blue)
    [13] = "55AA55", -- Dark green (for skill max)
    [14] = "EFEFB0", -- Dark gold (yellow sand)
  },
  DungStDone = 6,
  DungStNA   = 5,
  DailyQuest = 12,
  WWBStNone  = 5,
  WWBStDone  = 6,
  WWBStCur   = 2,
  TrialNone  = 5,
  TrialDone  = 4,
  TrialActv  = 6,
  TrialDnAc  = 2,
  LFG_Blue   = 11,
  LFG_Green  = 4,
  LFG_NA     = 5,
  LabelLvl   = 4,
  Weekend    = 6,
  Workday    = 4,
  BGCenter   = 7,
  BGEdge     = 8,
  BGTabCenter= 7,
  BGTabEdge  = 8,
  WWBAchiev  = 4,
  MenuDisabled = 5,
  MenuEnabled  = 4,
  MenuActive   = 6,
  MenuHighlighted = 2,
  TabDisabled = 5,
  TabEnabled  = 4,
  TabActive   = 6,
  TabHighlighted = 2,
  FestDone   = 14,
  dlm_slash  = "|c999999\\|r",
  MaxSkill = 13,
  ShSupl_Ready = 6,
  ShSupl_Timer = 4,
  ShSupl_Unkn = 5,
  ShSupl_NA   = 5,
  Book_All  = 6,
  Book_Some = 4,
  Book_None = 5,
} -- Colors end
---
WPamA.Textures = {
  --- use WPamA.Textures.GetTexture(index, size, inherit) ---
  --- [esoui/art/] lfg/lfg_veterandungeon_up [.dds] ---
  [  1] = "buttons/accept_up", -- check mark / accept
  [  2] = "tooltips/icon_lock", -- lock
  [  3] = "tutorial/help_tabicon_tutorial_up", -- help
  [  4] = "journal/journal_tabicon_quest_up", -- quest
  [  5] = "treeicons/tutorial_idexicon_death_up", -- boss
  [  6] = "mounts/ridingskill_ready", -- time until ready
  [  7] = "mainmenu/menubar_mail_up", -- mail
  [  8] = "icons/emotes/keyboard/emotecategoryicon_physical_up", -- run to
  [  9] = "lfg/lfg_normaldungeon_up", -- normal dungeon
  [ 10] = "lfg/lfg_veterandungeon_up", -- veteran dungeon
  [ 11] = "tutorial/achievements_indexicon_exploration_up", -- exploration star
  [ 12] = "tutorial/achievements_indexicon_darkanchors_up", -- dark anchor / dolmen
  [ 13] = "progression/progression_crafting_delevel_up", -- arrow down
  [ 14] = "progression/progression_tabicon_weapons_active", -- crossed swords
  [ 15] = "tutorial/timer_icon", -- sand-glass timer
  [ 16] = "treeicons/tutorial_idexicon_adventuring_up",
  [ 17] = "tutorial/menubar_journal_up",
  [ 18] = "treeicons/tutorial_idexicon_wrothgar_up", -- Wrothgar
  [ 19] = "journal/journal_tabicon_achievements_up",
  [ 20] = "icons/icon_experience", -- valuable/expensive item
  [ 21] = "icons/u41_pvp_reward_container", -- Rewards for the Worthy coffer
  [ 22] = "treeicons/tutorial_idexicon_darkbrotherhood_up", -- Dark Brotherhood / black hand
  [ 23] = "lfg/lfg_indexicon_trial_up",
  [ 24] = "progression/progression_indexicon_class_up",
  [ 25] = "treeicons/tutorial_idexicon_morrowind_up", -- Morrowind (Vvardenfell)
  [ 26] = "treeicons/tutorial_idexicon_summerset_up", -- Summerset
  [ 27] = "treeicons/tutorial_idexicon_mounts_up", -- riding skill
  [ 28] = "treeicons/tutorial_idexicon_elsweyr_up", -- Northern Elsweyr
  [ 29] = "treeicons/tutorial_idexicon_ava_up", -- AvA skill
  [ 30] = "treeicons/tutorial_indexicon_greymoor_up", -- Greymoor / Western Skyrim
  [ 31] = "treeicons/tutorial_idexicon_items_up",
  [ 32] = "icons/store_experiencescroll_001",
  [ 33] = "treeicons/collection_indexicon_upgrade_up",
  [ 34] = "treeicons/tutorial_idexicon_blackwood_up", -- Blackwood
  [ 35] = "icons/progression_tabicon_fightersguild_up", -- Fighters guild
  [ 36] = "icons/progression_tabicon_magesguild_up", -- Mages guild
  [ 37] = "tutorial/progression_tabicon_armorlight_up", -- armor light
  [ 38] = "tutorial/progression_tabicon_armormedium_up", -- armor medium
  [ 39] = "tutorial/progression_tabicon_armorheavy_up", -- armor heavy
  [ 40] = "treeicons/tutorial_idexicon_highisle_up", -- High Isle
  [ 41] = "tutorial/pointsminus_up", -- Minus sign
  [ 42] = "treeicons/tutorial_idexicon_necrom_up", -- Necrom
  [ 43] = "treeicons/tutorial_idexicon_goldroad_up", -- Gold Road
  [ 44] = "icons/item_grimoire_ink", -- Luminous Ink
  [ 45] = "treeicons/collection_indexicon_rapport_up", -- Companions rapport
  [ 46] = "treeicons/lfg_indexicon_promotionalevents_normal", -- Golden Pursuits
  [ 47] = "treeicons/gamepad/lfg_menuicon_promotionalevents_white", -- Promo-Event / Golden Pursuit (big white)
  [ 48] = "progression/icon_2handed", -- 2-handed weapon
  [ 49] = "progression/icon_1handed", -- 1-handed weapon
  [ 50] = "progression/icon_dualwield", -- dual-wield weapon
  [ 51] = "progression/icon_bows", -- bow weapon
  [ 52] = "progression/icon_firestaff", -- fire staff weapon
  [ 53] = "progression/icon_healstaff", -- heal staff weapon
  [ 54] = "tradinghouse/tradinghouse_apparel_accessories_necklace_up", -- necklace
  [ 55] = "tradinghouse/tradinghouse_apparel_accessories_ring_up", -- ring
  [ 56] = "help/help_tabicon_overview_up",
  [ 57] = "champion/champion_points_stamina_icon",
  [ 58] = "champion/champion_points_magicka_icon",
  [ 59] = "champion/champion_points_health_icon",
  [ 60] = "icons/crafting_runecrafter_potion_sp_001",
  [ 61] = "icons/quest_scroll_001",
  [ 62] = "icons/quest_key_003", -- undaunted key
  [ 63] = "lfg/lfg_indexicon_dungeon_up", -- group dungeon
  [ 64] = "icons/fragment_gladiator_proof", -- gladiator proof / medal
  [ 65] = "inventory/inventory_tabicon_container_up", -- container / coffer
  [ 66] = "treeicons/u46_helpcategory_update46_up", -- Solstice
  [ 67] = "tutorial/collection_indexicon_customaction_up", -- for Pledge norm/vet roulette mode
  [ 68] = "treeicons/tutorial_idexicon_timedactivities_up", -- Timed Activity / Endeavor
  [ 69] = "tutorial/inventory_tabicon_quickslot_up", -- quickslot / charge icon
  [ 70] = "tutorial/inventory_tabicon_repair_up", -- armor repair / broken shield
  [ 71] = "icons/servicemappins/u49_poi_adventurezone_calamitousboss_1", -- Calamitous boss in Adventure Zone
  [ 72] = "icons/poi/u49_poi_adventurezone_skirmish", -- Skirmish area in Adventure Zone
  [ 73] = "icons/mapkey/mapkey_dynamic_world_event", -- Dynamic Encounter
  [ 74] = "inventory/inventory_icon_hiddenby", -- hidden icon
  [ 75] = "companion/keyboard/companion_skills_up", -- companion skill icon
  --- [esoui/art/] lfg/lfg_veterandungeon_up [.dds] ---
  Named = {
    ["accept"] = 1,
    ["lock"] = 2,
    ["help"] = 3,
    ["quest"] = 4,
    ["boss"] = 5,
    ["mail"] = 7,
  },
  --- the texture string constructor ---
  GetTexture = function(textureIndex, textureSize, isInheritColor)
     if type(textureIndex) == "string" then
       textureIndex = WPamA.Textures.Named[textureIndex] or 0
     end
     local textureStr = ""
     if type(textureIndex) == "number" then
       if WPamA.Textures[textureIndex] then
         textureStr = zo_strformat("esoui/art/<<1>>.dds", WPamA.Textures[textureIndex])
       end
     end
     if (type(textureSize) == "number") and (textureStr ~= "") then
       if textureSize < 8 then textureSize = 8 end
       if isInheritColor then
         textureStr = zo_strformat("|t<<1>>:<<1>>:<<2>>:inheritcolor|t", textureSize, textureStr)
       else
         textureStr = zo_strformat("|t<<1>>:<<1>>:<<2>>|t", textureSize, textureStr)
       end
     end
     return textureStr
  end,
} -- Textures end
local GetIcon = WPamA.Textures.GetTexture
---
WPamA.tWinAlignSettings = setmetatable(
  {
   [1]={x=1,  y=1,  a=TOPLEFT,     f=LEFT,  t=RIGHT},
   [2]={x=-1, y=1,  a=TOPRIGHT,    f=RIGHT, t=LEFT},
   [3]={x=-1, y=-1, a=BOTTOMRIGHT, f=RIGHT, t=LEFT},
   [4]={x=1,  y=-1, a=BOTTOMLEFT,  f=LEFT,  t=RIGHT},
  },
  {__index = function() return {x=1, y=1, a=TOPLEFT, f=RIGHT, t=LEFT} end }
)
---
WPamA.Consts = {
  WinSizeMinX = 610,
  WinSizeMaxX = 940,
  WinSizeMinY = 95,
  WinSizeStepY= 24,
  WinMsgSizeMinY = 24,
  WinMsgSizeMaxY = 50,
  MsgSizeMinX = 184,
  MsgSizeMaxX = 580,
  MsgSizeMinY = 24,
  ModeColHeight = 24,
  CharColSize = 145,
  TabsHeight = 24,
  RowCnt = 32, -- < For ScreenShots change 32 to 8 :)
  CalendRowCnt = {8, 15, 30}, -- show calendar for 8 / 15 / 30 days
  RealmIndex = 0, -- 0 = Unknown/Default, 1 = PTS, 2 = NA, 3 = EU
  Realms = {[0]="Unk", [1]="PTS", [2]="NA", [3]="EU",},
  RealmsDailyReset = {[0] = 0, [1] = 10, [2] = 10, [3] = 3,},
  BaseTimeStamp = 1615680000, -- 2021-03-14 00:00 UTC - This value will be overridden later, after the initialization of the variable RealmIndex
--  BaseTimeStamp = GetTimestampForStartOfDate(2021, 03, 14, false), -- 2021-03-14 00:00 UTC = 1615680000
-- /script d(WPamA:TimestampToStr(1615680000, 2, 1)) /script d(WPamA:TimestampToStr(GetTimeStamp(), 2, 1))
  SecInMin  = 60,     -- 60s
  SecInHour = 3600,   -- SecInMin  * 60m
  SecInDay  = 86400,  -- SecInHour * 24h
  SecInWeek = 604800, -- SecInDay  * 7d
  SecIn20h  = 72000,  -- SecInHour * 20h
  RndDungDelayDef = 5, -- in seconds
  RndDungDelayMin = 5,
  RndDungDelayMax = 10,
  MinCharLvlForPledge = 45,
  RGLAMaxGrMember = MAX_GROUP_SIZE_THRESHOLD or 12,
  RGLAMsgCnt = 8,
  WWBAchiev = 1335, -- "Monster Hunter of the Month"
  TTEnlOn  = 8,
  TTEnlOff = 9,
  QuestStatus = { Removed = 0, Updated = 1, Started = 2, Completed = 3 }, -- 0 = none/not started or removed/reseted
  WritUpdated = 0, -- questStatus = 0 start/update, 1 completed, 2 removed/reseted
  WritCompleted = 1,
  WritRemoved = 2,
  FavRadPlaceholder = GetIcon("help"),
  ScaledTextFormatter = "$(CHAT_FONT)|<<1>>|soft-shadow-thin",
  MonsterSetLinkFormatter = "|H1:item:<<1>>:363:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h",
  CustomKeybindsMax = 5,
  ModeChoicesArray = { Choices = {}, ChoicesValues = {}, ChoicesTooltips = {} },
--[[
  CraftCertAchievs = {
    [1145] = true, -- "Certified Jack-of-All-Trades"
    [2225] = true, -- "Certified Jewelry Crafter"
  },
--]]
  LFGCooldownType = {
    [LFG_ACTIVITY_DUNGEON] = LFG_COOLDOWN_DUNGEON_REWARD_GRANTED,
    [LFG_ACTIVITY_BATTLE_GROUND_NON_CHAMPION] = LFG_COOLDOWN_BATTLEGROUND_REWARD_GRANTED,
    [LFG_ACTIVITY_TRIBUTE_CASUAL] = LFG_COOLDOWN_TRIBUTE_REWARD_GRANTED,
  },
  IconsW = {
    A      = GetIcon(19, 24),
    ChmEnl = "|t20:20:EsoUI/Art/Champion/champion_icon.dds|t",
    Chm    = "|t24:24:esoui/art/mainmenu/menubar_champion_up.dds|t",
    LMB    = "|t16:16:WPamA/images/Mouse_WB_LG.dds|t",
    RMB    = "|t16:16:WPamA/images/Mouse_WB_RG.dds|t",
    LMB1   = "|t16:16:esoui/art/icons/icon_lmb.dds|t",
    RMB1   = "|t16:16:esoui/art/icons/icon_lmb.dds|t",
    ChkM   = "|t24:24:WPamA/images/CheckMark.dds|t", --GetIcon("accept", 24),
    Lock   = GetIcon("lock", 16),
    Quest  = GetIcon("quest", 18),
    Boss   = GetIcon("boss", 18),
    Value  = GetIcon(20, 18), -- valuable/expensive item
    Norm   = GetIcon(9, 16),
    Vet    = GetIcon(10, 18),
    Minus  = GetIcon(41, 14),
    Roult  = GetIcon(67, 18), -- Pledge norm/vet roulette
    Hidden = GetIcon(74, 16, true),
    LfgpKeys = {
      [1] = "4" .. GetIcon(62, 18),
      [2] = "4" .. GetIcon(62, 18),
      [3] = "6" .. GetIcon(62, 18),
      [4] = "8" .. GetIcon(62, 18),
    },
    Races = {
      [ 1] = "esoui/art/charactercreate/charactercreate_bretonicon_up.dds", -- Breton
      [ 2] = "esoui/art/charactercreate/charactercreate_redguardicon_up.dds", -- Redguard
      [ 3] = "esoui/art/charactercreate/charactercreate_orcicon_up.dds", -- Orc
      [ 4] = "esoui/art/charactercreate/charactercreate_dunmericon_up.dds", -- Dunmer
      [ 5] = "esoui/art/charactercreate/charactercreate_nordicon_up.dds", -- Nord
      [ 6] = "esoui/art/charactercreate/charactercreate_argonianicon_up.dds", -- Argonian
      [ 7] = "esoui/art/charactercreate/charactercreate_altmericon_up.dds", -- Altmer
      [ 8] = "esoui/art/charactercreate/charactercreate_bosmericon_up.dds", -- Bosmer
      [ 9] = "esoui/art/charactercreate/charactercreate_khajiiticon_up.dds", -- Khajiit
      [10] = "esoui/art/charactercreate/charactercreate_imperialicon_up.dds", -- Imperial
    },
    Classes = {
      [  1] = "esoui/art/charactercreate/charactercreate_dragonguardicon_up.dds", -- Dragon Knight
      [  2] = "esoui/art/charactercreate/charactercreate_sorceroricon_up.dds", -- Sorcerer
      [  3] = "esoui/art/charactercreate/charactercreate_nightbladeicon_up.dds", -- Night Blade
      [  4] = "esoui/art/charactercreate/charactercreate_wardenicon_up.dds", -- Warden
      [  5] = "esoui/art/charactercreate/charactercreate_necromancericon_up.dds", -- Necromancer
      [  6] = "esoui/art/charactercreate/charactercreate_templaricon_up.dds", -- Templar
      [117] = "esoui/art/charactercreate/charactercreate_arcanisticon_up.dds", -- Arcanist
    },
    NoCert = "|t14:14:WPamA/images/CertScroll.dds|t",
    Mail   = GetIcon("mail", 18),
    RunTo  = GetIcon(8, 24),
  }, -- IconsW end
---
} -- Constants end
--- Current Realm index
do
  local c = WPamA.Consts
  local wn = GetWorldName()
  if wn == "NA Megaserver" then c.RealmIndex = 2
  elseif wn == "EU Megaserver" then c.RealmIndex = 3
  elseif wn == "PTS" then c.RealmIndex = 1
  end
  local function GetTimeZoneSeconds()
    local timeStamp = GetTimeStamp()
    local tblDateUTC, tblDateLoc = os.date("!*t", timeStamp), os.date("*t", timeStamp)
    tblDateLoc.isdst = false
    local timeUTC, timeLoc = os.time(tblDateUTC), os.time(tblDateLoc)
    return timeLoc - timeUTC
  end
  c.TimeZone = GetTimeZoneSeconds()
  if c.TimeZone <= 0 then c.BaseTimeStamp = c.BaseTimeStamp + c.SecInDay end
  c.BaseTimeStamp = c.BaseTimeStamp + c.RealmsDailyReset[c.RealmIndex] * c.SecInHour -- UTC time
  c.BaseTimeStamp = c.BaseTimeStamp + c.TimeZone -- Local time
end
---
WPamA.ChatChannelChoices = {
  Choices = {}, ChoicesValues = {},
  Channels = {
    [1] = { Name = SI_CHATCHANNELCATEGORIES9, Categ = CHAT_CATEGORY_SYSTEM }, -- "System"
    [2] = { Name = SI_CHATCHANNELCATEGORIES1, Categ = CHAT_CATEGORY_SAY    }, -- "Say"
    [3] = { Name = SI_CHATCHANNELCATEGORIES6, Categ = CHAT_CATEGORY_ZONE   }, -- "Zone"
    [4] = { Name = SI_CHATCHANNELCATEGORIES7, Categ = CHAT_CATEGORY_PARTY  }, -- "Group"
    [5] = { Name = SI_CHATCHANNELCATEGORIES8, Categ = CHAT_CATEGORY_EMOTE  }, -- "Emote"
    [6] = { Name = SI_CHATCHANNELCATEGORIES2, Categ = CHAT_CATEGORY_YELL   }, -- "Yell"
    -- [7] = { Name = SI_CHAT_CHANNEL_NAME_WHISPER, Categ = CHAT_CATEGORY_WHISPER_INCOMING }, -- "Tell"
    -- [8] = { Name = SI_MAIL_READ_REPLY, Categ = CHAT_CATEGORY_WHISPER_OUTGOING }, -- "Reply"
  },
  CreateChannelChoices = function()
     local Choices, ChoicesValues = WPamA.ChatChannelChoices.Choices, WPamA.ChatChannelChoices.ChoicesValues
     local Channels = WPamA.ChatChannelChoices.Channels
     local tinsert = table.insert
     for i = 1, #Channels do
       tinsert( Choices, GetString(Channels[i].Name) )
       tinsert( ChoicesValues, Channels[i].Categ )
     end
  end,
}
WPamA.ChatChannelChoices.CreateChannelChoices()
---
WPamA.Inventory = { -- Character Inventory
  InvtMaxUpgrade = GetMaxBackpackUpgrade(),
  InvtPetUpgrade = 0, -- will be calculated
  InvtPetCIDs = {4732, 4740, 5852}, -- Mournhold Packrat, Bristleneck War Boar, Explorer's Pack Donkey
  InvtItemByID = {},
  InvtItemModes = {[3]=0,[19]=0,[20]=0,[21]=0,[23]=0,[35]=0,[37]=0,[50]=0},
  InvtItem = {
    -- 4=ITEMTYPE_FOOD, 5=ITEMTYPE_TROPHY, 7=ITEMTYPE_POTION, 9=ITEMTYPE_TOOL, 18=ITEMTYPE_CONTAINER
    -- 19=ITEMTYPE_SOUL_GEM, 60=ITEMTYPE_MASTER_WRIT, 70=ITEMTYPE_CONTAINER_CURRENCY, 74=ITEMTYPE_SCRIBING_INK
    -- 75=ITEMTYPE_CONTAINER_STACKABLE
    [ 1] = {t = 57, TT = 65, ids = {64537,135110,138811}, link = "64537:124:1", HdT=GetIcon(32,24) .. "(50%)"}, -- Crown Experience Scroll (50%)
    [ 2] = {t =  0, TT = 61, c = CURT_MONEY, HdT="|t24:24:esoui/art/currency/currency_gold.dds|t"}, -- Gold
    [ 3] = {t =  0, TT = 62, c = CURT_WRIT_VOUCHERS, HdT="|t24:24:esoui/art/currency/currency_writvoucher.dds|t"},
    [ 4] = {t =  9, TT = 66, ids = 30357, link = "30357:175:1", HdT="|t24:24:esoui/art/icons/lockpick.dds|t", i = "/esoui/art/icons/lockpick.dds",}, -- Lockpick
    [ 5] = {t = 19, TT = 67, ids = 33271, link = "33271:31:50", HdT="|t24:24:esoui/art/icons/soulgem_006_filled.dds|t", i = "/esoui/art/icons/soulgem_006_filled.dds",}, -- Soul Gem
    [ 6] = {t = 19, TT = 68, ids = 33265, link = "33265:30:50", HdT="|t24:24:esoui/art/icons/soulgem_006_empty.dds|t", i = "/esoui/art/icons/soulgem_006_empty.dds",}, -- Soul Gem (Empty)
    [ 7] = {t =  0, TT = 63, c = CURT_ALLIANCE_POINTS, HdT="|t24:24:esoui/art/currency/alliancepoints.dds|t"},
    [ 8] = {t =  0, TT = 64, c = CURT_TELVAR_STONES, HdT="|t24:24:esoui/art/currency/currency_telvar.dds|t"},
    [ 9] = {t =  0, TT = 69, c = CURT_IMPERIAL_FRAGMENTS, HdT="|t24:24:esoui/art/icons/quest_daedricembers.dds|t"},
    [10] = {t = 19, TT =160, ids = 61080, link = "61080:32:1",  HdT="|t24:24:esoui/art/icons/store_soulgem_001.dds|t",}, -- Crown Soul Gem
    [11] = {t =  7, TT =161, ids = 64710, link = "64710:123:1", HdT="|t24:24:esoui/art/icons/crownpotion_trires.dds|t",}, -- Crown Tri-Restoration Potion
    [12] = {t =  4, TT =162, ids = 64711, link = "64711:123:1", HdT="|t24:24:esoui/art/icons/store_crownfood_01.dds|t",}, -- Crown Fortifying Meal
    [13] = {t = 18, TT =163, ids = {134619,145577,181436,184171,190009,194353,204404,210866,214239,219651,224367},
            link = "145577:122:1", HdT=GetIcon(21,24)}, -- Rewards for the Worthy
           -- { 225247, 225248, 225249 } = "Veterancy Rewards for the Worthy"
    [14] = {t = 70, TT =168, ids = {211304,134618}, link = "211304:122:1", HdT=GetIcon(60,24) .. "(25)", TTf="%(.+", nL=25, nH=25}, -- Transmutation Geode (25) + Uncracked (4-25)
    [15] = {t = 57, TT =165, ids = 94439, link = "94439:124:1", HdT="|t24:24:esoui/art/icons/crowncrate_experiencescroll_001.dds|t(50%)",}, -- Gold Coast Experience Scroll (50%)
    [16] = {t = 57, TT =166, ids = 94440, link = "94440:124:1", HdT="|t24:24:esoui/art/icons/crowncrate_experiencescroll_002.dds|t(100%)",}, -- Major Gold Coast Experience Scroll (100%)
                                                                --|H1:item:187936:124:1:0:0:0:0:0:0:0:0:0:0:0:1:36:0:1:0:0:0|h|h -- "Pre-Purchase Crown Experience Scroll" (100%)
    [17] = {t = 57, TT =167, ids = 94441, link = "94441:124:1", HdT="|t24:24:esoui/art/icons/crowncrate_experiencescroll_003.dds|t(150%)",}, -- Grand Gold Coast Experience Scroll (150%)
    [18] = {t = 70, TT =168, ids =134583, link ="134583:121:1", HdT=GetIcon(60,24) .. "(1)", nL=1, nH=1}, -- Transmutation Geode (1)
    [19] = {t = 18, TT = 70, ids =203614, link ="203614:122:1", HdT="|t24:24:esoui/art/icons/delivery_box_001.dds|t"}, -- Archival Fortunes Container
    [20] = {t = 70, TT =168, ids =134588, link ="134588:121:1", HdT=GetIcon(60,24) .. "(5)", nL=5, nH=5}, -- Transmutation Geode (5)
    [21] = {t = 70, TT =168, ids =211305, link ="211305:124:1", HdT=GetIcon(60,24) .. "(100)", nL=100, nH=100}, -- Transmutation Geode (100)
    [22] = {t = 70, TT =168, ids = {134590,134623}, link ="134590:364:1", HdT=GetIcon(60,24) .. "(10)", nL=10, nH=10}, -- Transmutation Geode (10) + (2-10)
    [23] = {t = 70, TT =168, ids =134591, link ="134591:364:1", HdT=GetIcon(60,24) .. "(50)", nL=50, nH=50}, -- Transmutation Geode (50)
    [24] = {t = 70, TT =168, ids = {171531,134622}, link ="171531:121:1", HdT=GetIcon(60,24) .. "(3)", TTf="%(.+", nL=3, nH=3}, -- Transmutation Geode (3) + (1-3)
    [25] = {t = 18, TT =169, ids =138812, link ="138812:1:1", HdT="|t24:24:esoui/art/icons/quest_container_001.dds|t",}, -- Gladiator's Rucksack
    [26] = {t = 70, TT =170, ids =138783, link ="138783:1:1", HdT=GetIcon(64,24)}, -- Arena Gladiator's Proof
    [27] = {t = 18, TT =171, ids =151941, link ="151941:1:1", HdT="|t24:24:esoui/art/icons/justice_stolen_trinket.dds|t",}, -- Siegemaster's Coffer
    [28] = {t = 70, TT =172, ids =151939, link ="151939:1:1", HdT=GetIcon(64,24)}, -- Siege of Cyrodiil Merit
    [29] = {t = 12, TT =173, ids = 64221, link = "64221:364:1", HdT="|t24:24:esoui/art/icons/quest_potion_001.dds|t(50%)",}, -- Psijic Ambrosia
    [30] = {t = 12, TT =174, ids =120076, link ="120076:364:1", HdT="|t24:24:esoui/art/icons/consumeable_experience_002.dds|t(100%)",}, -- Aetherial Ambrosia
    [31] = {t = 12, TT =175, ids =115027, link ="115027:364:1", HdT="|t24:24:esoui/art/icons/consumeable_experience_003.dds|t(150%)",}, -- Mythic Aetherial Ambrosia
    [32] = {t =  5, TT =176, st = 100, TTs = GetString(SI_SPECIALIZEDITEMTYPE100), HdT=GetIcon(61,24) .. GetIcon(65,24)}, -- Treasure map
    [33] = {t =  5, TT =177, st = 101, TTs = GetString(SI_SPECIALIZEDITEMTYPE101), HdT=GetIcon(61,24) .. "|t24:24:esoui/art/treeicons/tutorial_idexicon_tradeskills_up.dds|t"}, -- Survey report
    ---
    [34] = {t =  5, TT =178, ids =203611, link ="203611:122:1", HdT="|t24:24:esoui/art/icons/u40_verse_item_offense.dds|t", i = "/esoui/art/icons/u40_verse_item_offense.dds",}, -- Mystery Offensive Verse
    [35] = {t =  5, TT =179, ids =203612, link ="203612:122:1", HdT="|t24:24:esoui/art/icons/u40_verse_item_defense.dds|t", i = "/esoui/art/icons/u40_verse_item_defense.dds",}, -- Mystery Defensive Verse
    [36] = {t =  5, TT =180, ids =203613, link ="203613:122:1", HdT="|t24:24:esoui/art/icons/u40_verse_item_utility.dds|t", i = "/esoui/art/icons/u40_verse_item_utility.dds",}, -- Mystery Utility Verse
    [37] = {t =  5, TT =181, ids =208359, link ="208359:123:1", HdT="|t24:24:/esoui/art/icons/u40_verse_item_offense.dds|t", i = "/esoui/art/icons/u40_verse_item_offense.dds",}, -- Mystery Transformation Verse
    ---
    [38] = {t =  4, TT =182, ids =171323, link ="171323:124:10", HdT="|t24:24:esoui/art/icons/crownstore_consumable_entremet_cake.dds|t"}, -- Colovian War Torte
    [39] = {t =  4, TT =183, ids =171329, link ="171329:124:10", HdT="|t24:24:esoui/art/icons/ava_skill_boost_food_001.dds|t"}, -- Molten War Torte
    [40] = {t =  4, TT =184, ids =171432, link ="171432:124:10", HdT="|t24:24:esoui/art/icons/ava_skill_boost_food_002.dds|t"}, -- White-Gold War Torte
    ---
    [41] = {t = 70, TT =185, ids = 69413, link = "69413:122:1", HdT="|t24:24:esoui/art/icons/quest_container_001.dds|t"}, -- Light Tel Var Satchel
    [42] = {t = 18, TT =186, ids =192612, link ="192612:124:1", HdT="|t24:24:esoui/art/icons/event_midyear_giftbox.dds|t", i = "/esoui/art/icons/event_midyear_giftbox.dds"}, -- Pelinal's Boon Box
    [43] = {t = 18, TT =187, ids =187700, link ="187700:124:1", HdT="|t24:24:esoui/art/icons/justice_stolen_pouch_001.dds|t", i = "/esoui/art/icons/justice_stolen_pouch_001.dds"}, -- Zenithar's Bounty
    [44] = {t = 74, TT =188, ids =204881, link ="204881:30:1",  HdT=GetIcon(44,24)}, -- Luminous Ink
    [45] = {t = 70, TT =164, ids =212235, link ="212235:370:50", HdT=GetIcon(64,24)}, -- Battlemaster Token
    ---
    [46] = {t = 75, TT =273, ids =224681, link ="224681:122:1", HdT="|t24:24:esoui/art/icons/item_u47_sealed_scroll.dds|t" .. GetIcon(65,24)}, -- Unopened Treasure Map
    [47] = {t = 75, TT =274, ids ={219849,219850,219851,219852,219853,219854}, link ="219849:122:1",
            TTs = zo_strformat("<<1>>\n(<<2>>)", GetString(SI_SPECIALIZEDITEMTYPE101), GetString(SI_ITEMTYPE75)),
            HdT="|t24:24:esoui/art/icons/item_u47_envelope_string_brown.dds|t" .. "|t24:24:esoui/art/treeicons/tutorial_idexicon_tradeskills_up.dds|t"}, -- Unidentified Survey Report
    [48] = {t = 60, TT =275, st =2750, TTs = GetString(SI_SPECIALIZEDITEMTYPE2750), HdT="|t24:24:esoui/art/icons/master_writ_woodworking.dds|t"}, -- Master Writ
    [49] = {t = 75, TT =276, ids ={217917,217918,217919,217920,217921,217922,217923}, link = "217917:123:1",
            TTs = zo_strformat("<<1>>\n(<<2>>)", GetString(SI_SPECIALIZEDITEMTYPE2750), GetString(SI_ITEMTYPE75)),
            HdT="|t24:24:esoui/art/icons/item_u47_latched_box_tan.dds|t"}, -- Unknown Writ
    ---
    [50] = {t = 57, TT =277, ids =171262, link = "171262:124:10", HdT="|t24:24:esoui/art/icons/store_alliancewarscroll_basic.dds|t"}, -- Alliance War Skill Line Scroll (Basic)
    [51] = {t = 57, TT =278, ids =170148, link = "170148:124:10", HdT="|t24:24:esoui/art/icons/store_alliancewarscroll_major.dds|t"}, -- Alliance War Skill Line Scroll (Major)
    [52] = {t = 57, TT =279, ids =171263, link = "171263:124:10", HdT="|t24:24:esoui/art/icons/store_alliancewarscroll_grand.dds|t"}, -- Alliance War Skill Line Scroll (Grand)
    ---
    [53] = {t =  5, TT =280, ids =224302, link ="224302:1:1", HdT="|t24:24:esoui/art/icons/housing_uni_inc_nowherekey001.dds|t",
            i = "/esoui/art/icons/housing_uni_inc_nowherekey001.dds"}, -- Unformed Planar Key / Wondrous Nowhere Key
    -- GetItemLinkInfo("|H1:item:217922:123:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
    -- GetItemLinkItemType("|H1:item:217922:123:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
    -- TT reserved for Item name : 61...70, 160...190, 273...280
  }, -- InvtItem
  ItemTypeForCheckST = {
    [ITEMTYPE_TROPHY] = true, [ITEMTYPE_TOOL] = true, [ITEMTYPE_SOUL_GEM] = true, [ITEMTYPE_MASTER_WRIT] = true
  },
  CreateModesHeaders = function()
     local Inv = WPamA.Inventory
     local byID = Inv.InvtItemByID
     for i, v in pairs(Inv.InvtItem) do
       if type(v.ids) == "number" then
         byID[v.ids] = i
       elseif type(v.ids) == "table" then
         for _, q in pairs(v.ids) do
           if type(q) == "number" then byID[q] = i end
         end
       end
     end
     ---
     local z = Inv.InvtItem
     for i, _ in pairs(Inv.InvtItemModes) do
       local m = WPamA.ModeSettings[i]
       if type(m) == "table" then
         for j, v in pairs(m.Map) do
           if type(z[v]) == "table" then
             m.BTT[j] = z[v].TT
             m.HdT[j] = z[v].HdT
           end
         end
       end
     end
     ---
     local pets, sum = Inv.InvtPetCIDs, 0
     for i = 1, #pets do
       if IsCollectibleUnlocked( pets[i] ) then sum = sum + 1 end
     end
     Inv.InvtPetUpgrade = sum
  end,
}
---
WPamA.Equipment = {
  EquipSlots = {
    [ 1] = EQUIP_SLOT_HEAD,        [ 2] = EQUIP_SLOT_SHOULDERS,  [ 3] = EQUIP_SLOT_CHEST,
    [ 4] = EQUIP_SLOT_HAND,        [ 5] = EQUIP_SLOT_WAIST,      [ 6] = EQUIP_SLOT_LEGS,
    [ 7] = EQUIP_SLOT_FEET,        [ 8] = EQUIP_SLOT_RING1,      [ 9] = EQUIP_SLOT_RING2,
    [10] = EQUIP_SLOT_NECK,        [11] = EQUIP_SLOT_MAIN_HAND,  [12] = EQUIP_SLOT_OFF_HAND,
    [13] = EQUIP_SLOT_BACKUP_MAIN, [14] = EQUIP_SLOT_BACKUP_OFF
  },
  -- ES = { [EqSlot] = equip slot's index }
  Iterators = { ES = {} },
  CreateIterators = function()
     local EI = WPamA.Equipment.Iterators
     local ES = WPamA.Equipment.EquipSlots
     for j = 1, #ES do
       local slot = ES[j]
       EI.ES[slot] = j
     end
     ---
  end,
}
---
WPamA.GroupDungeons = {
  Dungeons = {
-- Virtual dungeon
    [ 1] = {Alli = 0, Loc =  1, LfgN =  0, LfgV =  0,}, -- None
    [ 2] = {Alli = 9, Loc =  1, LfgN =  0, LfgV =  0,}, -- Unknown / For color N9
-- First location dungeons
         -- AD -> Auridon I - The Banished Cells I
    [ 3] = {Alli = 1, Loc = 15, LfgN =  3, LfgV =  2, QAch =  325, QID = 4107, PID = 5244, MSID = 94732},
         -- EP -> Stonefalls I - Fungal Grotto I
    [ 4] = {Alli = 2, Loc = 11, LfgN =  1, LfgV = 11, QAch =  294, QID = 3993, PID = 5247, MSID = 95012},
         -- DC -> Glenumbra I - Spindleclutch I
    [ 5] = {Alli = 3, Loc =  2, LfgN =  2, LfgV = 24, QAch =  301, QID = 4054, PID = 5260, MSID = 94476},
         -- AD -> Auridon II - The Banished Cells II
    [ 6] = {Alli = 1, Loc = 15, LfgN = 23, LfgV = 12, QAch = 1555, QID = 4597, PID = 5246, MSID = 59673},
         -- EP -> Stonefalls II - Fungal Grotto II
    [ 7] = {Alli = 2, Loc = 11, LfgN = 17, LfgV = 21, QAch = 1562, QID = 4303, PID = 5248, MSID = 59393},
         -- DC -> Glenumbra II - Spindleclutch II
    [ 8] = {Alli = 3, Loc =  2, LfgN = 26, LfgV =  1, QAch = 1571, QID = 4555, PID = 5273, MSID = 59427},
-- Second location dungeons
         -- AD -> Grahtwood I - Elden Hollow I
    [ 9] = {Alli = 1, Loc =  7, LfgN =  6, LfgV =  4, QAch =   11, QID = 4336, PID = 5276, MSID = 94764},
         -- EP -> Deshaan I - Darkshade Caverns I
    [10] = {Alli = 2, Loc = 10, LfgN =  4, LfgV = 18, QAch =   78, QID = 4145, PID = 5274, MSID = 94756},
         -- DC -> Stormhaven I - Wayrest Sewers I
    [11] = {Alli = 3, Loc =  4, LfgN =  5, LfgV = 16, QAch =   79, QID = 4246, PID = 5278, MSID = 94500},
         -- AD -> Grahtwood II - Elden Hollow II
    [12] = {Alli = 1, Loc =  7, LfgN = 24, LfgV = 13, QAch = 1579, QID = 4675, PID = 5277, MSID = 59565},
         -- EP -> Deshaan II - Darkshade Caverns II
    [13] = {Alli = 2, Loc = 10, LfgN = 25, LfgV =  3, QAch = 1587, QID = 4641, PID = 5275, MSID = 59529},
         -- DC -> Stormhaven II - Wayrest Sewers II
    [14] = {Alli = 3, Loc =  4, LfgN = 18, LfgV = 17, QAch = 1595, QID = 4813, PID = 5282, MSID = 59505},
-- 3 location dungeons
         -- AD -> Greenshade I - City of Ash I
    [15] = {Alli = 1, Loc = 16, LfgN =  9, LfgV = 19, QAch =  551, QID = 4778, PID = 5290, MSID = 94788},
         -- EP -> Shadowfen - Arx Corinium
    [16] = {Alli = 2, Loc =  9, LfgN =  7, LfgV = 15, QAch =  272, QID = 4202, PID = 5288, MSID = 95052},
         -- DC -> Rivenspire I - Crypt of Hearts I
    [17] = {Alli = 3, Loc =  3, LfgN =  8, LfgV =  5, QAch =   80, QID = 4379, PID = 5283, MSID = 94796},
         -- AD -> Greenshade II - City of Ash II
    [18] = {Alli = 1, Loc = 16, LfgN = 28, LfgV =  6, QAch = 1603, QID = 5120, PID = 5381, MSID = 59637},
         -- DC -> Rivenspire II - Crypt of Hearts II
    [19] = {Alli = 3, Loc =  3, LfgN = 27, LfgV = 25, QAch = 1616, QID = 5113, PID = 5284, MSID = 59601},
-- 4 location dungeons
         -- AD -> Malabal Tor - Tempest Island
    [20] = {Alli = 1, Loc =  8, LfgN = 12, LfgV = 20, QAch =   81, QID = 4538, PID = 5301, MSID = 95084},
         -- EP -> Eastmarch - Direfrost Keep
    [21] = {Alli = 2, Loc = 13, LfgN = 10, LfgV = 26, QAch =  357, QID = 4346, PID = 5291, MSID = 94804},
         -- DC -> Alik`r Desert - Volenfell
    [22] = {Alli = 3, Loc =  5, LfgN = 11, LfgV = 14, QAch =  391, QID = 4432, PID = 5303, MSID = 94548},
-- 5 location dungeons
         -- AD -> Reaper`s March - Selene's Web
    [23] = {Alli = 1, Loc = 17, LfgN = 15, LfgV = 22, QAch =  417, QID = 4733, PID = 5307, MSID = 95116},
         -- EP -> The Rift - Blessed Crucible
    [24] = {Alli = 2, Loc = 12, LfgN = 13, LfgV = 27, QAch =  393, QID = 4469, PID = 5306, MSID = 94836},
         -- DC -> Bangkorai - Blackheart Haven
    [25] = {Alli = 3, Loc =  6, LfgN = 14, LfgV = 28, QAch =  410, QID = 4589, PID = 5305, MSID = 94556},
-- 6 location dungeons
         -- Any -> Coldharbour - Vaults of Madness
    [26] = {Alli = 4, Loc = 23, LfgN = 16, LfgV = 23, QAch =  570, QID = 4822, PID = 5309, MSID = 94852},
-- 7 Imperial City DLC dungeons
         -- Any -> Imperial City - Imperial City Prison
    [27] = {Alli = 4, Loc = 26, LfgN = 20, LfgV =  7, QAch = 1345, QID = 5136, PID = 5382, MSID = 59459, DLC = 154},
         -- Any -> Imperial City - White-Gold Tower
    [28] = {Alli = 4, Loc = 26, LfgN = 19, LfgV =  8, QAch = 1346, QID = 5342, PID = 5431, MSID = 68112, DLC = 154},
-- 8 Shadows of the Hist DLC dungeons
         -- EP -> Shadowfen - Ruins of Mazzatun
    [29] = {Alli = 2, Loc =  9, LfgN = 21, LfgV =  9, QAch = 1504, QID = 5403, PID = 5636, MSID = 82200, DLC = 375},
         -- EP -> Shadowfen - Cradle of Shadows
    [30] = {Alli = 2, Loc =  9, LfgN = 22, LfgV = 10, QAch = 1522, QID = 5702, PID = 5780, MSID = 82130, DLC = 491},
-- 9 Horns of the Reach DLC dungeons
         -- Any -> Craglorn - Bloodroot Forge
    [31] = {Alli = 4, Loc = 25, LfgN = 29, LfgV = 29, QAch = 1690, QID = 5889, PID = 6053, MSID = 127722, DLC = 1165},
         -- Any -> Craglorn - Falkreath Hold
    [32] = {Alli = 4, Loc = 25, LfgN = 30, LfgV = 30, QAch = 1698, QID = 5891, PID = 6054, MSID = 128309, DLC = 1355},
-- 10 Dragon Bones DLC dungeons
         -- DC -> Bangkorai - Fang Lair
    [33] = {Alli = 3, Loc =  6, LfgN = 32, LfgV = 32, QAch = 1959, QID = 6064, PID = 6155, MSID = 129483, DLC = 1331},
         -- DC -> Stormhaven - Scalecaller Peak
    [34] = {Alli = 3, Loc =  4, LfgN = 31, LfgV = 31, QAch = 1975, QID = 6065, PID = 6154, MSID = 129531, DLC = 4703},
-- 11 Wolfhunter DLC dungeons
         -- AD -> Reaper`s March - Moon Hunter Keep
    [35] = {Alli = 1, Loc = 17, LfgN = 33, LfgV = 33, QAch = 2152, QID = 6186, PID = 6187, MSID = 141676, DLC = 5008},
         -- AD -> Greenshade - March of Sacrifices
    [36] = {Alli = 1, Loc = 16, LfgN = 34, LfgV = 34, QAch = 2162, QID = 6188, PID = 6189, MSID = 141628, DLC = 5009},
-- 12 Wrathstone DLC dungeons
         -- EP -> Eastmarch - Frostvault
    [37] = {Alli = 2, Loc = 13, LfgN = 35, LfgV = 35, QAch = 2260, QID = 6249, PID = 6250, MSID = 146638, DLC = 5473},
         -- Any -> Gold Coast - Depths of Malatar
    [38] = {Alli = 4, Loc = 29, LfgN = 36, LfgV = 36, QAch = 2270, QID = 6251, PID = 6252, MSID = 147243, DLC = 5474},
-- 13 Scalebreaker DLC dungeons
         -- Any -> Elsweyr - Moongrave Fane
    [39] = {Alli = 4, Loc = 36, LfgN = 37, LfgV = 37, QAch = 2415, QID = 6349, PID = 6350, MSID = 152266, DLC = 6040},
         -- AD -> Grahtwood - Lair of Maarselok
    [40] = {Alli = 1, Loc =  7, LfgN = 38, LfgV = 38, QAch = 2425, QID = 6351, PID = 6352, MSID = 152318, DLC = 6041},
-- 14 Harrowstorm DLC dungeons
         -- Any -> Wrothgar - Icereach
    [41] = {Alli = 4, Loc = 27, LfgN = 39, LfgV = 39, QAch = 2539, QID = 6414, PID = 6415, MSID = 158177, DLC = 6646},
         -- DC -> Bangkorai - Unhallowed Grave
    [42] = {Alli = 3, Loc =  6, LfgN = 40, LfgV = 40, QAch = 2549, QID = 6416, PID = 6417, MSID = 158239, DLC = 6647},
-- 15 Stonethorn DLC dungeons
         -- Any -> Blackreach - Stone Garden
    [43] = {Alli = 4, Loc = 39, LfgN = 41, LfgV = 41, QAch = 2694, QID = 6505, PID = 6506, MSID = 167046, DLC = 7430},
         -- Any -> Western Skyrim - Castle Thorn
    [44] = {Alli = 4, Loc = 38, LfgN = 42, LfgV = 42, QAch = 2704, QID = 6507, PID = 6508, MSID = 167116, DLC = 7431},
-- 16 Flames of Ambition DLC dungeons
         -- Any -> Gold Coast - Black Drake Villa
    [45] = {Alli = 4, Loc = 29, LfgN = 43, LfgV = 43, QAch = 2831, QID = 6576, PID = 6577, MSID = 171619, DLC = 8216},
         -- EP -> Deshaan - The Cauldron
    [46] = {Alli = 2, Loc = 10, LfgN = 44, LfgV = 44, QAch = 2841, QID = 6578, PID = 6579, MSID = 171663, DLC = 8217},
-- 17 Waking Flame DLC dungeons
         -- DC -> Glenumbra - Red Petal Bastion
    [47] = {Alli = 3, Loc =  2, LfgN = 45, LfgV = 45, QAch = 3016, QID = 6683, PID = 6684, MSID = 178582, DLC = 9374},
         -- Any -> Blackwood - The Dread Cellar
    [48] = {Alli = 4, Loc = 43, LfgN = 46, LfgV = 46, QAch = 3026, QID = 6685, PID = 6686, MSID = 178644, DLC = 9375},
-- 18 Ascending Tide DLC dungeons
         -- Any -> Summerset - Coral Aerie
    [49] = {Alli = 4, Loc = 32, LfgN = 47, LfgV = 47, QAch = 3104, QID = 6740, PID = 6741, MSID = 183744, DLC = 9651},
         -- DC -> Rivenspire - Shipwright's Regret
    [50] = {Alli = 3, Loc =  3, LfgN = 48, LfgV = 48, QAch = 3114, QID = 6742, PID = 6743, MSID = 183800, DLC = 9652},
-- 19 Lost Depths DLC dungeons
         -- Any -> High Isle - Earthen Root Enclave
    [51] = {Alli = 4, Loc = 46, LfgN = 49, LfgV = 49, QAch = 3375, QID = 6835, PID = 6836, MSID = 189368, DLC = 10400},
         -- Any -> High Isle - Graven Deep
    [52] = {Alli = 4, Loc = 46, LfgN = 50, LfgV = 50, QAch = 3394, QID = 6837, PID = 6838, MSID = 189418, DLC = 10401},
-- 20 Scribes of Fate DLC dungeons
         -- EP -> Stonefalls - Bal Sunnar
    [53] = {Alli = 2, Loc = 11, LfgN = 51, LfgV = 51, QAch = 3468, QID = 6896, PID = 6897, MSID = 193124, DLC = 10838},
         -- EP -> The Rift - Scrivener's Hall
    [54] = {Alli = 2, Loc = 12, LfgN = 52, LfgV = 52, QAch = 3529, QID = 7027, PID = 7028, MSID = 193695, DLC = 10839},
-- 21 Scions of Ithelia DLC dungeons
         -- Any -> The Reach - Oathsworn Pit
    [55] = {Alli = 4, Loc = 42, LfgN = 53, LfgV = 53, QAch = 3810, QID = 7105, PID = 7106, MSID = 202486, DLC = 11650},
         -- Any -> Wrothgar - Bedlam Veil
    [56] = {Alli = 4, Loc = 27, LfgN = 54, LfgV = 54, QAch = 3851, QID = 7155, PID = 7156, MSID = 203051, DLC = 11651},
-- 22 Fallen Banners DLC dungeons
         -- Any -> The Gold Road - Exiled Redoubt
    [57] = {Alli = 4, Loc = 51, LfgN = 55, LfgV = 55, QAch = 4109, QID = 7235, PID = 7236, MSID = 213126, DLC = 12699},
         -- Any -> Hew's Bane - Lep Seclusa
    [58] = {Alli = 4, Loc = 28, LfgN = 56, LfgV = 56, QAch = 4128, QID = 7237, PID = 7238, MSID = 213691, DLC = 12700},
-- 23 Feast of Shadows DLC dungeons
         -- Any -> Solstice - Naj-Caldeesh
    [59] = {Alli = 4, Loc = 53, LfgN = 57, LfgV = 57, QAch = 4311, QID = 7320, PID = 7321, MSID = 219092, DLC = 13556},
         -- Any -> Solstice - Black Gem Foundry
    [60] = {Alli = 4, Loc = 53, LfgN = 58, LfgV = 58, QAch = 4334, QID = 7323, PID = 7324, MSID = 219048, DLC = 13557},
-- 13822 - Fall of the Writhing Wall
  }, -- Dungeons end
-- "|H1:item:??????:363:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:10000:0|h|h"
-- "/wpad dlc" for DLC IDs, "/wpad loc" for Loc IDs
-- Based on 2021-03-14 06:00 UTC
  OrdPledges = {
-- Maj NPC
    [1] = {
      [ 1] =  4, -- Fungal Grotto I
      [ 2] =  6, -- Banished Cells II
      [ 3] = 10, -- Darkshade Caverns I
      [ 4] = 12, -- Elden Hollow II
      [ 5] = 11, -- Wayrest Sewers I
      [ 6] =  8, -- Spindleclutch II
      [ 7] =  3, -- Banished Cells I
      [ 8] =  7, -- Fungal Grotto II
      [ 9] =  5, -- Spindleclutch I
      [10] = 13, -- Darkshade Caverns II
      [11] =  9, -- Elden Hollow I
      [12] = 14, -- Wayrest Sewers II
    },
-- Glirion NPC
    [2] = {
      [ 1] = 23, -- Selene's Web
      [ 2] = 18, -- City of Ash II
      [ 3] = 17, -- Crypt of Hearts I
      [ 4] = 22, -- Volenfell
      [ 5] = 24, -- Blessed Crucible
      [ 6] = 21, -- Direfrost Keep
      [ 7] = 26, -- Vaults of Madness
      [ 8] = 19, -- Crypt of Hearts II
      [ 9] = 15, -- City of Ash I
      [10] = 20, -- Tempest Island
      [11] = 25, -- Blackheart Haven
      [12] = 16, -- Arx Corinium
    },
-- Urgarlag NPC
    [3] = {
      [ 1] = 27, -- Imperial City Prison
      [ 2] = 29, -- Ruins of Mazzatun
      [ 3] = 28, -- White-Gold Tower
      [ 4] = 30, -- Cradle of Shadows
      [ 5] = 31, -- Bloodroot Forge
      [ 6] = 32, -- Falkreath Hold
      [ 7] = 33, -- Fang Lair
      [ 8] = 34, -- Scalecaller Peak
      [ 9] = 35, -- Moon Hunter Keep
      [10] = 36, -- March of Sacrifices
      [11] = 38, -- Depths of Malatar
      [12] = 37, -- Frostvault
      [13] = 39, -- Moongrave Fane
      [14] = 40, -- Lair of Maarselok
      [15] = 41, -- Icereach
      [16] = 42, -- Unhallowed Grave
      [17] = 43, -- Stone Garden
      [18] = 44, -- Castle Thorn
      [19] = 45, -- Black Drake Villa
      [20] = 46, -- The Cauldron
      [21] = 47, -- Red Petal Bastion
      [22] = 48, -- The Dread Cellar
      [23] = 49, -- Coral Aerie
      [24] = 50, -- Shipwright's Regret
      [25] = 51, -- Earthen Root Enclave
      [26] = 52, -- Graven Deep
      [27] = 53, -- Bal Sunnar
      [28] = 54, -- Scrivener's Hall
      [29] = 55, -- Oathsworn Pit
      [30] = 56, -- Bedlam Veil
      [31] = 57, -- Exiled Redoubt
      [32] = 58, -- Lep Seclusa
      [33] = 59, -- Naj-Caldeesh
      [34] = 60, -- Black Gem Foundry
    },
  }, -- OrdPledges end
  -- { A = { [QAch] = Dungeon's index }, Q = { [QID] = Dungeon's index }, QN = { [QName] = Dungeon's index },
  -- N = { [PName] = Dungeon's index }, PG = { [PledgeIndex] = Pledge-Giver NPC's index } }
  Iterators = { A = {}, Q = {}, QN = {}, N = {}, PG = {} },
  CreateIterators = function()
     local di = WPamA.GroupDungeons.Iterators
     -- Create dungeon's iterator for Pledge-Giver NPC IDs
     local ord = WPamA.GroupDungeons.OrdPledges
     for j = 1, #ord do
       local op = ord[j]
       for i = 1, #op do
         di.PG[ op[i] ] = j
       end
     end
     -- Create dungeon's iterators for Quest IDs and Achiev IDs
     local dung = WPamA.GroupDungeons.Dungeons
     for j = 3, #dung do
       local d = dung[j]
       di.A[d.QAch] = j
       di.Q[d.QID] = j
       local q = GetQuestName(d.QID)
       di.QN[q] = j
       -- di.P[d.PID] = j
       local n = GetQuestName(d.PID)
       di.N[n] = j
     end
  end,
}
---
WPamA.ChampionDisciplines = {
  [1] = {Icon = "", Name = "", Total = 1200},
  [2] = {Icon = "", Name = "", Total = 1200},
  [3] = {Icon = "", Name = "", Total = 1200},
}
---
WPamA.Festivals = {
  AchievementsIDs = {
   [1] = 1677, -- Winter: "Glory of Magnus"
   [2] = 1723, -- Spring: "Royal Jester"
   [3] = 1892, -- Summer: "Star-Made Knight"
   [4] = 1546, -- Autumn: "An Unsparing Harvest"
  },
  FestIDs = {
   [1546] = true,
   [1677] = true,
   [1723] = true,
   [1892] = true,
  },
  Titles = {},
}
---
WPamA.AvA = {
  -- "|H1:item:214316:32:50:0:0:0:0:0:0:0:0:0:0:0:65:36:0:1:0:0:0|h|h" = (Vengeance) Soul Gem
  AssignedCampaign = {},
  ImperialCity = {},
  BattleGrounds = {
    DailyQuestIDs = {
      5952, -- To the Victor
      5953, -- Let the Games Begin
      5954  -- Test of Mettle
    } -- DailyQuestIDs
  } -- BattleGrounds
} -- AvA
---
WPamA.DailyWrits = {
  QuestIDs = {
   [1] = {5368, 5377, 5392}, -- Blacksmith Writ
   [2] = {5374, 5388, 5389}, -- Clothier Writ
   [3] = {5394, 5395, 5396}, -- Woodworker Writ
   [4] = {5415, 5416, 5417, 5418, 6098, 6099, 6100, 6101, 6102, 6103, 6104, 6105}, -- Alchemist Writ
   [5] = {5400, 5406, 5407}, -- Enchanter Writ
   [6] = {5409, 5412, 5413, 5414}, -- Provisioner Writ
   [7] = {6218, 6227, 6228}, -- Jewelry Crafting Writ
  },
  Iterators = { N = {}, Q = {} }, -- { N = { [QName] = Writ's index }, Q = { [QID] = Writ's index } }
  CreateIterators = function()
     local DWI, DWQ = WPamA.DailyWrits.Iterators, WPamA.DailyWrits.QuestIDs
     for j = 1, #DWQ do
       local writ = DWQ[j]
       for i = 1, #writ do
         local qid = writ[i]
         local qn = GetQuestName(qid)
         DWI.Q[qid] = j
         DWI.N[qn] = j
       end
     end
  end,
} -- DailyWrits
---
WPamA.Favors = {
  QuestIDs = {
   [1] = 7469, -- Favor for Holgunn One-Eye
   [2] = 7477, -- Favor for Battlereeve Urcelmo
   [3] = 7513, -- Favor for Lady Arabelle
  },
  Iterators = { N = {}, Q = {} }, -- { N = { [QName] = Favor's index }, Q = { [QID] = Favor's index } }
  CreateIterators = function()
     local FI, FQ = WPamA.Favors.Iterators, WPamA.Favors.QuestIDs
     for j = 1, #FQ do
       local qid = FQ[j]
       local qn = GetQuestName(qid)
       FI.Q[qid] = j
       FI.N[qn] = j
     end
  end,
} -- Favors
---
WPamA.CraftCerts = {
  QuestIDs = {
   [1] = 5249, -- CRAFTING_BLACKSMITHING
   [2] = 5310, -- CRAFTING_CLOTHIER
   [3] = 5302, -- CRAFTING_WOODWORKING
   [4] = 5315, -- CRAFTING_ALCHEMY
   [5] = 5314, -- CRAFTING_ENCHANTING
   [6] = 5289, -- CRAFTING_PROVISIONING
   [7] = 6171, -- CRAFTING_JEWELRYCRAFTING
  },
  Iterators = { N = {}, Q = {} }, -- { N = { [QName] = Cert's index }, Q = { [QID] = Cert's index } }
  CreateIterators = function()
     local CCI, CCQ = WPamA.CraftCerts.Iterators, WPamA.CraftCerts.QuestIDs
     for j = 1, #CCQ do
       local cert = CCQ[j]
       local qn = GetQuestName(cert)
       CCI.Q[cert] = j
       CCI.N[qn] = j
     end
  end,
}
---
WPamA.Companions = {
  MaxRapport = GetMaximumRapport(),
  MinRapport = GetMinimumRapport(),
  RapportColors = {
    [RAPPORT_LEVEL_MAXIMUM_AFFINITY] = "|c20DF20<<1>>|r", [RAPPORT_LEVEL_VERY_HIGH_AFFINITY] = "|c50DF50<<1>>|r",
    [RAPPORT_LEVEL_HIGH_AFFINITY]    = "|c70DC00<<1>>|r", [RAPPORT_LEVEL_MODERATE_AFFINITY]  = "|c95C525<<1>>|r",
    [RAPPORT_LEVEL_SLIGHT_AFFINITY]  = "|cCFDCBD<<1>>|r", [RAPPORT_LEVEL_SLIGHT_DISLIKE]     = "|cCFCF90<<1>>|r",
    [RAPPORT_LEVEL_HIGH_DISLIKE]     = "|cCF9500<<1>>|r", [RAPPORT_LEVEL_MAXIMUM_DISLIKE]    = "|cCF4D47<<1>>|r",
  },
  MaxSkillBarSlot = 0,
  MinSkillBarSlot = 0,
  ActiveCompanionId = 0, -- CCID of current active companion or 0
  -- Structure: { IID = IngameCompanionId, DLC = CollectibleId, Name = "CompanionName", QID = IntroQuestId,
  --              SQ = {StoryQuestIds}, isLocked = lockedStatus }
  Persons = {
    [1] = { IID =  1, DLC =  8659, Name = "", QID = 6626, SQ = {6662, 6664      }, isLocked = true }, -- Bastian
    [2] = { IID =  2, DLC =  8659, Name = "", QID = 6648, SQ = {6666, 6667      }, isLocked = true }, -- Mirri
    [3] = { IID =  5, DLC = 10053, Name = "", QID = 6771, SQ = {6785, 6786, 6787}, isLocked = true }, -- Ember
    [4] = { IID =  6, DLC = 10053, Name = "", QID = 6760, SQ = {6789, 6790, 6791}, isLocked = true }, -- Isobel
    [5] = { IID =  8, DLC = 10475, Name = "", QID = 7017, SQ = {7018, 7019, 7020}, isLocked = true }, -- Sharp-As-Night
    [6] = { IID =  9, DLC = 10475, Name = "", QID = 7021, SQ = {7022, 7023, 7024}, isLocked = true }, -- Azandar
    [7] = { IID = 12, DLC = 12172, Name = "", QID = 7186, SQ = {7187, 7188, 7189}, isLocked = true }, -- Tanlorin
    [8] = { IID = 13, DLC = 12173, Name = "", QID = 7194, SQ = {7207, 7216, 7221}, isLocked = true }, -- Zerith-var
  },
  SkillLines = {
    --- Class Skill Lines -- Bastian, Mirri, Ember, Isobel, Sharp, Azandar ---
    --- Class Skill Lines -- Tanlorin, Zerith ---
    [ 1] = { CID = {175, 178, 198, 202, 242, 248, 265, 260}, Name = "", Max = 20 }, -- Class Skill Line 1
    [ 2] = { CID = {174, 177, 197, 200, 241, 246, 264, 261}, Name = "", Max = 20 }, -- Class Skill Line 2
    [ 3] = { CID = {176, 179, 196, 201, 243, 247, 266, 262}, Name = "", Max = 20 }, -- Class Skill Line 3
    --- Skill Lines for Guilds ---
    [ 4] = { ID = 189, Name = "", Max = 10 }, -- Fighters guild Skill Line
    [ 5] = { ID = 190, Name = "", Max = 10 }, -- Mages guild Skill Line
    [ 6] = { ID = 191, Name = "", Max = 10 }, -- Undaunted guild Skill Line
    --- Skill Lines for Armor ---
    [ 7] = { ID = 186, Name = "", Max = 20 }, -- Light armor Skill Line
    [ 8] = { ID = 187, Name = "", Max = 20 }, -- Middle armor Skill Line
    [ 9] = { ID = 188, Name = "", Max = 20 }, -- Heavy armor Skill Line
    --- Skill Lines for Weapon ---
    [10] = { ID = 180, Name = "", Max = 20 }, -- 2H-weapon Skill Line
    [11] = { ID = 181, Name = "", Max = 20 }, -- 1H-weapon Skill Line
    [12] = { ID = 182, Name = "", Max = 20 }, -- Dual weapon Skill Line
    [13] = { ID = 183, Name = "", Max = 20 }, -- Bow Skill Line
    [14] = { ID = 184, Name = "", Max = 20 }, -- Destro-staff Skill Line
    [15] = { ID = 185, Name = "", Max = 20 }, -- Resto-staff Skill Line
  },
  EquipSlots = {
    [ 1] = EQUIP_SLOT_HEAD,  [ 2] = EQUIP_SLOT_SHOULDERS,  [ 3] = EQUIP_SLOT_CHEST,
    [ 4] = EQUIP_SLOT_HAND,  [ 5] = EQUIP_SLOT_WAIST,      [ 6] = EQUIP_SLOT_LEGS,
    [ 7] = EQUIP_SLOT_FEET,  [ 8] = EQUIP_SLOT_MAIN_HAND,  [ 9] = EQUIP_SLOT_OFF_HAND,
    [10] = EQUIP_SLOT_NECK,  [11] = EQUIP_SLOT_RING1,      [12] = EQUIP_SLOT_RING2,
  },
  EquipNameSubs = { ["EN"] = 1, ["DE"] = 1, ["FR"] = 1, ["RU"] = 2 },
  -- I = { [IID] = person's index }, N = { [QName] = person's index }, Q = { [QID] = person's index }
  -- SL = { [ID] = skill line's index }, ES = { [EqSlot] = equip slot's index }, SQ = { [QName] = person's index }
  Iterators = { I = {}, N = {}, Q = {}, SL = {}, ES = {}, SQ = {} },
  CreateIterators = function()
     local CI, CP = WPamA.Companions.Iterators, WPamA.Companions.Persons
     for j = 1, #CP do
       local iid = CP[j].IID
       local qid = CP[j].QID
       local qn = GetQuestName(qid)
       CI.I[iid] = j
       CI.Q[qid] = j
       CI.N[qn] = j
       ---
       local sq = CP[j].SQ
       for i = 1, #sq do
         qn = GetQuestName(sq[i])
         CI.SQ[qn] = j
       end
     end
     ---
     local ES = WPamA.Companions.EquipSlots
     for j = 1, #ES do
       local slot = ES[j]
       CI.ES[slot] = j
     end
     ---
     local CS = WPamA.Companions.SkillLines
     for j = 1, #CS do
       local id = 0
       if CS[j].CID then
         local cid = CS[j].CID
         for i = 1, #cid do
           id = cid[i]
           CI.SL[id] = j
         end
       else
         id = CS[j].ID
         CI.SL[id] = j
       end
     end
  end,
}
---
WPamA.EndlessDungeons = { -- IID = IngameDungeonId, IQI = IntroQuestId, QID = DailyQuestId
  Dungeons = {
    [1] = { IID = DEFAULT_ENDLESS_DUNGEON_ID, IQI = 7061, QID = 7065 }, -- Infinite Archive
  },
  EyeOfInfinite = { C = 12269, S = 229014 }, -- Eye of the Infinite / Loyal Auditor
  DefStat = { BestArc = 0, BestCycle = 0, BestStage = 0, Rank = 0 },
  InheritColorIcons = {
    ChkM  = GetIcon("accept", 24, true),
    Lock  = GetIcon("lock", 18, true),
    Quest = GetIcon("quest", 24, true),
  },
  -- I = { [IID] = dungeon's index }, N = { [QName] = dungeon's index }, Q = { [QID] = dungeon's index }
  -- IQ = { [IQI] = dungeon's index }
  Iterators = { I = {}, N = {}, Q = {}, IQ = {} },
  CreateIterators = function()
     local EDI, EDD = WPamA.EndlessDungeons.Iterators, WPamA.EndlessDungeons.Dungeons
     for j = 1, #EDD do
       local iid = EDD[j].IID
       local qid = EDD[j].QID
       local qn  = GetQuestName(qid)
       EDI.I[iid] = j
       EDI.Q[qid] = j
       EDI.N[qn]  = j
       local iqi = EDD[j].IQI
       EDI.IQ[iqi] = j
     end
  end,
}
---
WPamA.WorldBosses = {
  Locations = { -- aka DailyBossLoc
    [ 0] = {MZI = 380, m = 2,  b = 1,  e = 6,  s = 1}, -- Wrothgar
    [ 1] = {MZI = 468, m = 8,  b = 7,  e = 12, s = 1}, -- Vvardenfell
    [ 2] = {MZI = 449, m = 9,  b = 13, e = 14, s = 1}, -- Gold Coast
    [ 3] = {MZI = 617, m = 11, b = 15, e = 20, s = 1}, -- Summerset
    [ 4] = {MZI = 682, m = 14, b = 21, e = 26, s = 1}, -- Northern Elsweyr
    [ 5] = {MZI = 744, m = 17, b = 27, e = 30, s = 1}, -- Western Skyrim
    [ 6] = {MZI = 745, m = 17, b = 31, e = 32, s = 5}, -- Blackreach: Greymoor Caverns
    [ 7] = {MZI = 835, m = 26, b = 33, e = 38, s = 1}, -- Blackwood
    [ 8] = {MZI = 884, m = 33, b = 39, e = 44, s = 1}, -- High Isle
    [ 9] = {MZI = 960, m = 41, b = 45, e = 46, s = 1}, -- Telvanni Peninsula
    [10] = {MZI = 959, m = 41, b = 47, e = 50, s = 3}, -- Apocrypha
    [11] = {MZI = 983, m = 45, b = 51, e = 56, s = 1}, -- The Gold Road
    [12] = {MZI =1034, m = 47, b = 57, e = 62, s = 1}, -- Solstice
--    [?] = {MZI = 443, m = ??, b = ??, e = ??, s = 1}, -- Hew's Bane
--    [?] = {MZI = 590, m = ??, b = ??, e = ??, s = 1}, -- The Clockwork City
--    [?] = {MZI = 408, m = ??, b = ??, e = ??, s = 1}, -- Murkmire
--    [?] = {MZI = 784, m = ??, b = ??, e = ??, s = 1}, -- The Reach
--    [?] = {MZI = 785, m = ??, b = ??, e = ??, s = 1}, -- Blackreach: Arkthzand Cavern
--    [?] = {MZI = 854, m = ??, b = ??, e = ??, s = 1}, -- Fargrave
--    [?] = {MZI = 855, m = ??, b = ??, e = ??, s = 1}, -- The Shambles
--    [?] = {MZI = 858, m = ??, b = ??, e = ??, s = 1}, -- The Deadlands
  },
  Bosses = { -- aka DailyBoss
-- Wrothgar
    [ 1] = { QID = 5522, H = "ZANDA", S = {"+zan", "+dolmen", "+ud"} },
    [ 2] = { QID = 5523, H = "NYZ",   S = {"+nyz"} },
    [ 3] = { QID = 5524, H = "EDU",   S = {"+edu"} },
    [ 4] = { QID = 5519, H = "OGRE",  S = {"+ogre","+mad"} },
    [ 5] = { QID = 5518, H = "POA",   S = {"+poa"} },
    [ 6] = { QID = 5521, H = "CORI",  S = {"+cori","+nb"} },
-- Vvardenfell
    [ 7] = { QID = 5865, H = "QUEEN", S = {"+queen"} },
    [ 8] = { QID = 5904, H = "SAL",   S = {"+sal"} },
    [ 9] = { QID = 5866, H = "NIL",   S = {"+nil"} },
    [10] = { QID = 5918, H = "WUY",   S = {"+wuy"} },
    [11] = { QID = 5916, H = "DUB",   S = {"+dub"} },
    [12] = { QID = 5906, H = "SIREN", S = {"+siren"} },
-- Gold Coast
    [13] = { QID = 5606, H = "ARENA", S = {"+arena"} },
    [14] = { QID = 5605, H = "MINO",  S = {"+mino"} },
-- Summerset
    [15] = { QID = 6082, H = "QUEEN", S = {"+queen"} },
    [16] = { QID = 6087, H = "KEEL",  S = {"+keel"} },
    [17] = { QID = 6083, H = "CAAN",  S = {"+caan"} },
    [18] = { QID = 6084, H = "KORG",  S = {"+korg"} },
    [19] = { QID = 6086, H = "GRAV",  S = {"+grav"} },
    [20] = { QID = 6085, H = "GRYPH", S = {"+gryph","+gryf","+grif","+bird"} },
-- Northern Elsweyr
    [21] = { QID = 6380, H = "NARUZ", S = {"+nar","+bw"} },
    [22] = { QID = 6382, H = "THAN",  S = {"+than","+t","+gp"} },
    [23] = { QID = 6381, H = "ZAVI",  S = {"+zavi","+dd"} },
    [24] = { QID = 6377, H = "VHYS",  S = {"+vhys","+sm","+ss"} },
    [25] = { QID = 6378, H = "KEEVA", S = {"+kee","+wk","+k"} },
    [26] = { QID = 6379, H = "ZAL",   S = {"+zal","+z","+x"} },
-- Western Skyrim
    [27] = { QID = 6509, H = "YSM",   S = {"+ysm","+sea","+giant"} },
    [28] = { QID = 6517, H = "WWOLF", S = {"+wwolf","+ww","+moon"} },
    [29] = { QID = 6518, H = "SKREG", S = {"+skreg","+circle","+champ"} },
    [30] = { QID = 6519, H = "SHADE", S = {"+shade","+mother"} },
-- Blackreach: Greymoor Caverns
    [31] = { QID = 6526, H = "VAMP",  S = {"+vamp","+terr"} },
    [32] = { QID = 6527, H = "DISM",  S = {"+dism","+colos","+dc"} },
-- Blackwood
    [33] = { QID = 6651, H = "FROG",  S = {"+frog"} },
    [34] = { QID = 6652, H = "XEEM",  S = {"+xeem"} },
    [35] = { QID = 6650, H = "SUL",   S = {"+sul"} },
    [36] = { QID = 6653, H = "RUIN",  S = {"+ruin"} },
    [37] = { QID = 6645, H = "BULL",  S = {"+bull"} },
    [38] = { QID = 6649, H = "ZATH",  S = {"+zath"} },
-- High Isle
    [39] = { QID = 6816, H = "VIN",   S = {"+vin"} },
    [40] = { QID = 6807, H = "SAB",   S = {"+sab"} },
    [41] = { QID = 6821, H = "SHAD",  S = {"+shad"} },
    [42] = { QID = 6808, H = "WILD",  S = {"+wild"} },
    [43] = { QID = 6803, H = "ELD",   S = {"+eld"} },
    [44] = { QID = 6822, H = "HAD",   S = {"+had"} },
-- Necrom
    [45] = { QID = 7040, H = "WNM",   S = {"+wnm"} },
    [46] = { QID = 7044, H = "CORL",  S = {"+corl","+cc","+ctc"} },
    [47] = { QID = 7039, H = "VRO",   S = {"+vro"} },
    [48] = { QID = 7041, H = "DEK",   S = {"+dek","+vd","+plaza"} },
    [49] = { QID = 7042, H = "CATL",  S = {"+catl","+pc"} },
    [50] = { QID = 7043, H = "XIOM",  S = {"+xiom","+rx"} },
-- Gold Road
    [51] = { QID = 7109, H = "URTH",  S = {"+urth"} },
    [52] = { QID = 7116, H = "STRI",  S = {"+stri"} },
    [53] = { QID = 7117, H = "FANG",  S = {"+fang"} },
    [54] = { QID = 7118, H = "HESS",  S = {"+hess"} },
    [55] = { QID = 7119, H = "RECO",  S = {"+reco"} },
    [56] = { QID = 7120, H = "OAK",   S = {"+oak"} },
-- Solstice
    [57] = { QID = 7266, H = "TIDE",  S = {"+tide"} },
    [58] = { QID = 7264, H = "GAULM", S = {"+gaulm"} },
    [59] = { QID = 7265, H = "VOSK",  S = {"+vosk"} },
    [60] = { QID = 7271, H = "SCALL",   S = {"+scall"} },
    [61] = { QID = 7272, H = "WOXET",   S = {"+woxet"} },
    [62] = { QID = 7270, H = "GHISH", S = {"+ghish"} },
  }, -- Bosses
  CreateModesHeaders = function()
     local B = WPamA.WorldBosses.Bosses
     local L = WPamA.WorldBosses.Locations
     local MS = WPamA.ModeSettings
     -- Replace values for NA Megaserver
     if WPamA.Consts.RealmIndex == 2 then
     -- Wrothgar
       B[1].H = "UD" -- ZANDA
       B[4].H = "MAD" -- OGRE
       B[6].H = "NB" -- CORI
     -- Northern Elsweyr
       B[21].H = "BW" -- NARUZ
       B[23].H = "DD" -- ZAVI
       B[24].H = "SM" -- VHYS
       B[25].H = "WK" -- KEEVA
     end
     -- Copy Bosses.H to mode's headers array
     for i = 0, #L do -- #L = 8 currently
       local v = L[i]
       for j = v.b, v.e do
         MS[v.m].HdT[j-v.b+v.s] = B[j].H
       end
     end
  end, -- CreateModesHeaders end
  -- N = { [QName] = Boss's index }, Q = { [QID] = Boss's index } }
  Iterators = { N = {}, Q = {} },
  CreateIterators = function()
     local WBB, WBI = WPamA.WorldBosses.Bosses, WPamA.WorldBosses.Iterators
     for j = 1, #WBB do
       local qid = WBB[j].QID
       local qn = GetQuestName(qid)
       WBI.Q[qid] = j
       WBI.N[qn] = j
     end
  end,
}
---
WPamA.TrialDungeons = {
  Trials = {
    [ 1] = { M = 6, N = 1, H = "HRC", BTT = 51, QID = 5087,
             COF = {87703, 87708, 139665, 139669}, -- Warrior's Dulled / Honed coffer
           },
    [ 2] = { M = 6, N = 2, H = "AA", BTT = 52, QID = 5102,
             COF = {87702, 87707, 139664, 139668}, -- Mage's Ignorant / Knowledgeable coffer
           },
    [ 3] = { M = 6, N = 3, H = "SO", BTT = 53, QID = 5171,
             COF = {81187, 81188, 87705, 87706, 139666, 139667}, -- Serpent's Languid / Coiled coffer
           },
    [ 4] = { M = 6, N = 4, H = "MOL", BTT = 54, QID = 5352, DLC = 254,
             COF = {94089, 94090, 139670, 139671}, -- Dro-m'Athra's Burnished / Shining coffer
           },
    [ 5] = { M = 15, N = 1, H = "HOF", BTT = 55, QID = 5894, DLC = 593,
             COF = {126130, 126131, 139672, 139673}, -- Fabricant's Burnished / Shining coffer
           },
    [ 6] = { M = 15, N = 2, H = "AS", BTT = 56, QID = 6090, DLC = 1240,
             COF = {134585, 134586, 139674, 139675}, -- Saint's Beatified / Sanctified coffer
           },
    [ 7] = { M = 6, N = 5, H = "CR", BTT = 57, QID = 6192, DLC = 5107,
             COF = {138711, 138712, 141738, 141739}, -- Welkynar's Grounded / Soaring coffer
           },
    [ 8] = { M = 6, N = 6, H = "SS", BTT = 58, QID = 6353, DLC = 5843,
             COF = {151970, 151971}, -- Dragon God's Time-Worn / Pristine Hoard
           },
    [ 9] = { M = 15, N = 3, H = "KA", BTT = 59, QID = 6503, DLC = 7466,
             COF = {165421, 165422}, -- Kyne's Gleaming / Mundane coffer
           },
    [10] = { M = 15, N = 4, H = "RG", BTT = 191, QID = 6654, DLC = 8659,
             COF = {176054, 176055}, -- Rockgrove Mundane / Gleaming coffer
           },
    [11] = { M = 15, N = 5, H = "DSR", BTT = 192, QID = 6783, DLC = 10053,
             COF = {188134, 188139}, -- Taleria's Sundry / Glistening Treasure
           },
    [12] = { M = 15, N = 6, H = "SE", BTT = 193, QID = 7031, DLC = 10475,
             COF = {197827, 197828}, -- Sanity's Edge Treasure / Glistening Treasure
           },
    [13] = { M = 44, N = 1, H = "LC", BTT = 194, QID = 7212, DLC = 11871,
             COF = {207944, 207945}, -- Lucent Citadel Treasure / Glowing Treasure
           },
    [14] = { M = 44, N = 2, H = "OC", BTT = 195, QID = 7306, DLC = 13439,
             COF = {217657, 217658}, -- Curated Ossein Cage Treasure / Curated Ossein Cage Glowing Treasure
           },
  },
  -- |H1:item:188139:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h
  -- N = { [QName] = Trial's index }, Q = { [QID] = Trial's index }, C = { [COF] = Trial's index }
  Iterators = { N = {}, Q = {}, C = {} },
  CreateIterators = function()
     local TDI, TDT = WPamA.TrialDungeons.Iterators, WPamA.TrialDungeons.Trials
     local MS = WPamA.ModeSettings
     for j = 1, #TDT do
       local t = TDT[j]
       local qid = t.QID
       local qn = GetQuestName(qid)
       TDI.Q[qid] = j
       TDI.N[qn] = j
     -- Coffers of trials
       local cof = t.COF
       for c = 1, #cof do
         local ci = cof[c]
         TDI.C[ci] = j
       end
     -- Copy Trials.H to modes headers array
       local th = MS[t.M]
       th.HdT[t.N] = t.H
       th.BTT[t.N] = t.BTT
       th.Col[t.N] = 99
       th.Map[t.N] = j
     end
  end,
}
---
WPamA.SkillLines = { -- Character Skill Lines
  SkillLineDarkBr = 15,
  SkillLineModes = {
    [ 4] = {[1] = 1, [2] = 2, [3] = 3, [4] =17, [5] =18, [6] =19,},
    [ 5] = {[1] = 7, [2] = 8, [3] = 9, [4] =10, [5] =11, [6] =12, [7] =13,},
    [12] = {[1] = 4, [2] = 5, [3] = 6, [4] =14, [5] =15, [6] =16,},
    [24] = {[1] =20, [2] =21, [3] =22, [4] =23, [5] =24, [6] =25,},
  },
  SkillLines = {
    -- Line of Class skills
    [ 1] = {max = 50, typ = SKILL_TYPE_CLASS, si = 1, cl = 0},
    [ 2] = {max = 50, typ = SKILL_TYPE_CLASS, si = 2, cl = 0},
    [ 3] = {max = 50, typ = SKILL_TYPE_CLASS, si = 3, cl = 0},
    -- Line of Guild skills Part 1
    [ 4] = {max = 10, typ = SKILL_TYPE_GUILD, mrk = 'fightersguild',},
    [ 5] = {max = 10, typ = SKILL_TYPE_GUILD, mrk = 'mageguild',},
    [ 6] = {max = 10, typ = SKILL_TYPE_GUILD, mrk = 'undaunted', N1 = 7, mn1 = 2,},
    -- Line of Craft skills
    [ 7] = {max = 50, typ = SKILL_TYPE_TRADESKILL, sub = CRAFTING_TYPE_BLACKSMITHING,  N1 = 1, mn1 = 10, N3 = 3, mn3 = 3,},
    [ 8] = {max = 50, typ = SKILL_TYPE_TRADESKILL, sub = CRAFTING_TYPE_CLOTHIER,       N1 = 1, mn1 = 10, N3 = 3, mn3 = 3,},
    [ 9] = {max = 50, typ = SKILL_TYPE_TRADESKILL, sub = CRAFTING_TYPE_WOODWORKING,    N1 = 1, mn1 = 10, N3 = 3, mn3 = 3,},
    [10] = {max = 50, typ = SKILL_TYPE_TRADESKILL, sub = CRAFTING_TYPE_ALCHEMY,        N1 = 1, mn1 =  8, N2 = 3, mn2 = 3,},
    [11] = {max = 50, typ = SKILL_TYPE_TRADESKILL, sub = CRAFTING_TYPE_ENCHANTING,     N1 = 1, mn1 = 10, N2 = 2, mn2 = 4, N3 = 4, mn3 = 3,},
    [12] = {max = 50, typ = SKILL_TYPE_TRADESKILL, sub = CRAFTING_TYPE_PROVISIONING,   N1 = 1, mn1 =  6, N2 = 2, mn2 = 4, N3 = 7, mn3 = 3,},
    [13] = {max = 50, typ = SKILL_TYPE_TRADESKILL, sub = CRAFTING_TYPE_JEWELRYCRAFTING,N1 = 1, mn1 =  5,},
    -- Line of Guild skills Part 2
    [14] = {max = 12, typ = SKILL_TYPE_GUILD, mrk = 'thievesguild',},
    [15] = {max = 12, typ = SKILL_TYPE_GUILD, mrk = 'darkbrotherhood',},
    [16] = {max = 10, typ = SKILL_TYPE_GUILD, mrk = 'psijic',},
    -- Line of AvA skills
    [17] = {max = 10, typ = SKILL_TYPE_AVA, si = 7, mrk = 'ability_sorcerer_045',},
    [18] = {max = 10, typ = SKILL_TYPE_AVA, si = 4, mrk = 'ability_ava_006',},
    [19] = {max = 10, typ = SKILL_TYPE_AVA, si = 5, mrk = 'ability_ava_003',},
    -- World
    [20] = {max = 10, typ = SKILL_TYPE_WORLD, si = 1, mrk = 'ability_u26_vampire_06',},
    [21] = {max = 10, typ = SKILL_TYPE_WORLD, si = 2, mrk = 'ability_werewolf_001',},
    [22] = {max = 20, typ = SKILL_TYPE_WORLD, si = 3, mrk = 'ability_legerdemain_improvedsneak',},
    [23] = {max =  6, typ = SKILL_TYPE_WORLD, si = 4, mrk = 'ability_otherclass_002',}, -- Soul
    [24] = {max = 10, typ = SKILL_TYPE_WORLD, si = 5, mrk = 'ability_scrying_01', N1 = 2, mn1 = 5,},
    [25] = {max = 10, typ = SKILL_TYPE_WORLD, si = 6, mrk = 'ability_digging_03', N1 = 7, mn1 = 2,},
  },
  CreateModesHeaders = function()
     local skills = WPamA.SkillLines.SkillLines
     local modeSet = WPamA.ModeSettings
     for i, v in pairs(WPamA.SkillLines.SkillLineModes) do
       for j, q in pairs(v) do
         skills[q].tt = modeSet[i].BTT[j]
         skills[q].m  = i
       end
     end
  end,
} -- SkillLines end
---
WPamA.TimedEffects = { -- Character Timed Effects (long-term buffs)
  AvA = {
     -- "Alliance Skill Gain 50% Boost" esoui/art/icons/crownstore_consumable_entremet_cake.dds
     [1] = { AbilityId = {147687}, Perc = 50,  ItemId = {171323} }, -- Colovian War Torte (50%)
     -- "Alliance Skill Gain 100% Boost" esoui/art/icons/ava_skill_boost_food_001.dds
     [2] = { AbilityId = {147733}, Perc = 100, ItemId = {171329} }, -- Molten War Torte (100%)
     -- "Alliance Skill Gain 150% Boost" esoui/art/icons/ava_skill_boost_food_002.dds
     [3] = { AbilityId = {147734}, Perc = 150, ItemId = {171432} }, -- White-Gold War Torte (150%)
     -- "Alliance Skill Gain" esoui/art/icons/store_alliancewarscroll_basic.dds
     [4] = { AbilityId = {147466}, Perc = 50,  ItemId = {171262} }, -- Alliance War Skill Line Scroll (Basic)
     -- "Alliance Skill Gain, Major" esoui/art/icons/store_alliancewarscroll_major.dds
     [5] = { AbilityId = {137733}, Perc = 100, ItemId = {170148} }, -- Alliance War Skill Line Scroll (Major)
     -- "Alliance Skill Gain, Grand" esoui/art/icons/store_alliancewarscroll_grand.dds
     [6] = { AbilityId = {147467}, Perc = 150, ItemId = {171263} }, -- Alliance War Skill Line Scroll (Grand)
     LinkFormatter = "|H0:item:<<1>>:124:10:0:0:0:0:0:0:0:0:0:0:0:0:0:1:0:0:0:0|h|h"
  }, -- AvA
  PvE = {
     -- "Increased Experience" (50%) esoui/art/icons/ability_alchemy_001.dds
     [1] = { AbilityId = {66776, 85501}, Perc = 50,
             ItemId = { 64221, -- Psijic Ambrosia (30 min)
                        64537, -- Crown Experience Scroll (60 min)
                        94439, -- Gold Coast Experience Scroll (120 min)
                        135110, -- Bound Crown Experience Scroll
                      },
           },
     -- "Increased Experience" (100%) esoui/art/icons/ability_alchemy_001.dds
     [2] = { AbilityId = {85502, 174237}, Perc = 100,
             ItemId = { 120076, -- Aetherial Ambrosia (30 min)
                        94440, -- Major Gold Coast Experience Scroll (60 min)
                        187936, -- Pre-Purchase Crown Experience Scroll (60 min)
                      },
           },
     -- "Increased Experience" (150%) esoui/art/icons/ability_alchemy_001.dds
     [3] = { AbilityId = {85503}, Perc = 150,
             ItemId = { 115027, -- Mythic Aetherial Ambrosia (30 min)
                        94441, -- Grand Gold Coast Experience Scroll (60 min)
                        214517, -- Hero's Return Experience Scroll (60 min)
                      },
           },
     -- "Increased Experience" (???%) esoui/art/icons/ability_alchemy_001.dds
     [4] = { AbilityId = {63570, 64210, 88445, 89683, 99462, 99463}, Perc = "??",
             ItemId = {64537}, -- placeholder
           },
     LinkFormatter = "|H0:item:<<1>>:1:1:0:0:0:0:0:0:0:0:0:0:0:0:36:0:0:0:0:0|h|h"
  }, -- PvE
  Stat = {
     -- "Increase All Primary Stats"
     [1] = { AbilityId = {68411},
             ItemId = {64711, 135109}, -- [Bound] Crown Fortifying Meal
             Link = "64711:123:1",
             --ItemType = ITEMTYPE_FOOD
             --|H0:item:135109:123:1:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h
           },
     -- "Witchmother's Potent Brew"
     [2] = { AbilityId = {84731},
             ItemId = {87697}, -- Witchmother's Potent Brew
             Link = "87697:5:1",
             --ItemType = ITEMTYPE_FOOD
             --|H0:item:87697:5:1:0:0:0:0:0:0:0:0:0:0:0:0:0:1:0:0:0:0|h|h
             --esoui/art/icons/event_halloween_2016_iron_cup_bones.dds
           },
     -- "Dubious Camoran Throne"
     [3] = { AbilityId = {89957},
             ItemId = {120763}, -- Dubious Camoran Throne
             Link = "120763:5:1",
             --ItemType = ITEMTYPE_FOOD
             -- |H0:item:120763:5:1:0:0:0:0:0:0:0:0:0:0:0:0:0:1:0:0:0:0|h|h
           },
     ---
     LinkFormatter = "|H0:item:<<1>>:0:0:0:0:0:0:0:0:0:0:0:0:0:1:0:0:0:0|h|h"
  }, -- Stat
  -- /script d(GetAbilityName(66776, "player"))
  -- A = { [AbilityId] = AvA's index }, P = { [AbilityId] = PvE's index } }, S = { [AbilityId] = Stat's index } }
  Iterators = { A = {}, P = {}, S = {} },
  CreateIterators = function()
     local TEI = WPamA.TimedEffects.Iterators
     local A = WPamA.TimedEffects.AvA
     for j = 1, #A do
       local AI = A[j].AbilityId
       for i = 1, #AI do
         local aid = AI[i]
         TEI.A[aid] = j
       end
     end
     ---
     local P = WPamA.TimedEffects.PvE
     for j = 1, #P do
       local AI = P[j].AbilityId
       for i = 1, #AI do
         local aid = AI[i]
         TEI.P[aid] = j
       end
     end
     ---
     local S = WPamA.TimedEffects.Stat
     for j = 1, #S do
       local AI = S[j].AbilityId
       for i = 1, #AI do
         local aid = AI[i]
         TEI.S[aid] = j
       end
     end
     ---
  end,
} -- TimedEffects end
--================================================================
-- Replace values for PTS
--if WPamA.Consts.RealmIndex == 1 then
--end
-- Replace values for NA Megaserver
--if WPamA.Consts.RealmIndex == 2 then
--end
--< For ScreenShots
WPamA.ScreenShotName = {"Mierin Eronaile","Tel Janin","Saine Terasind","Duram Laddel","Ishar Morrad","Ared Mosinel","Eval Ramman","Nemene Damendar","Elan Morin","Barid Bel","Joar Nessosin","Kamarile Moradim","Lillen Moiral"}
--WPamA.GroupDungeons.Dungeons[29].DLC = nil
--WPamA.GroupDungeons.Dungeons[30].DLC = nil
