_G.EASArchiveHelper = _G.EASArchiveHelper or {}
local AH = _G.EASArchiveHelper
local priorLC = AH.LC
local defaults = {
    LC = priorLC,
    Defaults = {
        Enabled = true,
        Auditor = false,
        AvatarVisionCount = {IRON = 0, WOLF = 0, ICE = 0},
        CheckQuestItems = true,
        CountTomes = true,
        EchoingDenTimer = 60,
        FabledCheck = true,
        Favourites = {},
        GwCheck = true,
        GwPlay = true,
        Ignore = {},
        MarauderCheck = true,
        MarauderPlay = true,
        MarkAchievements = true,
        MarkAvatar = true,
        MarkFavourites = true,
        MarkIgnore = false,
        Notify = true,
        NotifyChat = true,
        NotifyScreen = true,
        PreventSelection = true,
        ShardCheck = true,
        ShardIgnore = true,
        ShowHelper = true,
        ShowNotice = true,
        ShowSelection = true,
        ShowStacks = true,
        ShowTimer = true,
        TerrainWarnings = true,
        Theatre = true,
        UseDisplayName = false
    },
    ArchiveIndex = 2407,
    ArchiveQuests = {GetQuestName(7091), GetQuestName(7101), GetQuestName(7102)},
    CrossingOptions = {
        "1542L36",
        "1624R53",
        "25143",
        "3R1465L2",
        "35142L6",
        "514236",
        "52L643R1",
        "5R34126"
    },
    FoundQuestItem = false,
    InEchoingDen = false,
    Keys = {},
    Marauders = {
        GetString(_G.ARCHIVEHELPER_MARAUDER_GOTHMAU),
        GetString(_G.ARCHIVEHELPER_MARAUDER_HILKARAX),
        GetString(_G.ARCHIVEHELPER_MARAUDER_ULMOR),
        GetString(_G.ARCHIVEHELPER_MARAUDER_BITTOG),
        GetString(_G.ARCHIVEHELPER_MARAUDER_ZULFIMBUL)
    },
    Name = "ESOAdventurerSuite_ArchiveHelper",
    SearchText = {},
    Shards = {},
    TerrainWarnings = true,
    Tomeshells = {Solo = 4, Duo = 8},
    DATA_ID = 29, -- Suite-internal LibDataShare map id
    DEBUG = false,
    ICONS = {
        ACH = {name = "login/login_icon_yield", colour = {1, 0, 0, 1}},
        FAV = {name = "campaign/overview_indexicon_bonus_down", colour = {0, 1, 0, 1}},
        IRON = {name = "icons/achievement_u40_ed2_iron_atronach", colour = {1, 1, 1, 1}},
        WOLF = {name = "icons/achievement_u40_ed2_werewolf_behemoth", colour = {1, 1, 1, 1}},
        ICE = {name = "icons/achievement_u40_ed2_ice_avatar", colour = {1, 1, 1, 1}},
        AVOID = {name = "castbar/forbiddenaction", colour = {1, 0, 0, 1}},
        UNDEAD = {name = "icons/poly_lich", colour = {1, 1, 1, 1}}
    },
    LF = string.char(10),
    MAPS = {
        TREACHEROUS_CROSSING = {id = 2420, name = GetString(_G.ARCHIVEHELPER_MAP_TREACHEROUS_CROSSING)},
        HAEFELS_BUTCHERY = {id = 2421, name = GetString(_G.ARCHIVEHELPER_MAP_HAEFELS_BUTCHERY)},
        FILERS_WING = {id = 2422, name = GetString(_G.ARCHIVEHELPER_MAP_FILERS_WING)},
        ECHOING_DEN = {id = 2423, name = GetString(_G.ARCHIVEHELPER_MAP_ECHOING_DEN)},
        THEATRE_OF_WAR = {id = 2424, name = GetString(_G.ARCHIVEHELPER_MAP_THEATRE_OF_WAR)},
        DESTOZUNOS_LIBRARY = {id = 2425, name = GetString(_G.ARCHIVEHELPER_MAP_DESTOZUNOS_LIBRARY)},
        FRIGID_WATERS = {2567},
        TOTHER_ONE = {}
    },
    OAKENSOUL = 187658,
    SELECTION_DELAY = 1250,
    SHARE = {
        TOME = 1,
        MARK = 2,
        UNMARK = 3,
        GW = 4,
        ABILITY = 5,
        CROSSING = 6,
        SHARING = 7
    },
    SKILL_TYPE_PET = 999,
    SORCERER = 2,
    SUPPORT_SKILL_LINE = 71,
    WARDEN = 4
}
for k, v in pairs(defaults) do AH[k] = v end
