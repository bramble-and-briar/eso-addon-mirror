local ADDON_NAME = "NagaMapaCompleto"
local DISPLAY_NAME = "Naga Mapa Completo"
local VERSION = "2.8.9"
local AUTHOR = "Naga"
local PIN_TYPE_STRING = "NagaMapaCompleto_ZoneProgressPin"
local SUPPORTED_LANGUAGES = { de = true, en = true, ru = true, fr = true, es = true, pt = true, br = true }

NagaMapaCompleto = NagaMapaCompleto or {}
local TPM = NagaMapaCompleto

TPM.overlayLabels = TPM.overlayLabels or {}
TPM.labelPool = TPM.labelPool or {}
TPM.displayedZoneIds = TPM.displayedZoneIds or {}
TPM.refreshQueued = false
TPM.pinRegistered = false
TPM.symbolicZonePositions = TPM.symbolicZonePositions or {}
TPM.symbolicZonePositionsMapId = TPM.symbolicZonePositionsMapId or 0
TPM.nextLabelId = TPM.nextLabelId or 0
TPM.settingsControls = TPM.settingsControls or {}

local DEFAULTS =
{
    enabled = true,
    showZoneNames = false,
    showTooltip = true,
    showHeader = true,
    language = "auto", -- 2.7.1: follows ESO client language; kept for SV compatibility
    hideCompletedZones = false,
    calculationMode = "objectives",
    showCategoryPercentages = false,
    showQuestRewards = true,
    colorVanillaQuestsByReward = true,
    fontStyle = "classic",
    questFontStyle = "classic",
    blackPercentText = false, -- legacy migration from v1.4.x
    percentColorMode = "black",
    percentColorModeMigrated = false,
    customPercentColor = { r = 0.79, g = 0.64, b = 0.29 },
    mapPercentScale = 100,
    headerPercentScale = 100,
    hundredDisplayMode = "percent",
    hundredDisplayMigrated = false,
    showQuickFilters = true,
    quickFilter = "all",
    debugMode = false,
    questRewardAnchorX = 322,
    questRewardAnchorY = -90,
    questRewardWidth = 312,
    questRewardHeight = 186,
    questRewardLocked = false,
    questRewardAutoSize = true,
    questRewardPositionVersion = 5,
    statisticsWindowX = false,
    statisticsWindowY = false,
    statisticsWindowScale = 100,
    statisticsSortMode = "progress",
    statisticsPage = "progress",
    statisticsProgressSubPage = 1, -- 1=Completion, 2=Alliance progress
    statisticsHistorySubPage = 1, -- 1=PvE/PvP, 2=Character
    statisticsCompletionPage = 1, -- 2.6.0: 1=zone completion, 2=collections, 3=achievements
    statisticsCategorySortMode = "all", -- 2.6.8: all/name/asc/desc for the three completion sub-pages
    skyshardGoalEnabled = false, -- personal zone-aware Skyshard goal HUD
    skyshardGoalPosition = 1, -- 2.6.15: 1=directly above Tamriel Tomes, 2=directly below
    skyshardGoalCustomPosition = false, -- 2.6.21: user-dragged HUD position overrides automatic slot 1/2
    skyshardGoalCustomX = false,
    skyshardGoalCustomY = false,
    skyshardGoalCustomWidth = false, -- 2.6.25: optional user-sized HUD width
    skyshardGoalCustomHeight = false, -- 2.6.25: optional user-sized HUD height
    progressGoalCategoryType = false, -- 2.6.26: currently selected progress-category HUD row
    statisticsFocusZoneId = 0,
    alliancePlannerMapZoom = 1.0,
    alliancePlannerMapCenterX = 0.5,
    alliancePlannerMapCenterY = 0.5,
    alliancePlannerTerritoryColors = true,
    -- 2.7.0: Statistics journal customization. Defaults reproduce the 2.6.84 look.
    statisticsThemeDesign = "cyber", -- futuristic default (dark|cyber|neon|arctic|ember|matrix|tpm|vanilla)
    statisticsThemeBackground = { r = 0.06, g = 0.07, b = 0.09, a = 0.96 },
    statisticsThemeHeading = { r = 0.55, g = 0.85, b = 1.00 },
    statisticsThemeAccent = { r = 0.35, g = 0.78, b = 0.95 },
    statisticsThemeProgress = { r = 0.30, g = 0.90, b = 0.70 },
    statisticsThemeText = { r = 0.90, g = 0.93, b = 0.96 },
    statisticsThemeRGB = false, -- legacy compatibility flag; RGB UI removed
    statisticsCharacterRangeDays = 7, -- 2.7.5: Character history selector: 7/30/90/365 days
    statisticsCharacterRangeOffset = 0, -- 2.7.5: browsing offset inside the selected Character history range
    schemaVersion = 0, -- centralized SavedVariables migration baseline
    serverScopeMigrated = false, -- migrated into the GetWorldName() namespace
    serverScopeMigrationWorld = "",

 -- 2.6.14: 0=all Tamriel, otherwise one supported progress zone
    combatStatsByCharacter = {},
    economyStats = { trackingVersion = "2.0.10", currencies = {} }, -- legacy account-wide ledger from 2.0.10-2.0.14
    economyStatsByCharacter = {},
    economyZoneStatsByCharacter = {}, -- 2.6.32: zone-specific economy ledger; starts with this version
    economyZoneTrackingStartedAt = 0,
    economyDetailFocusZoneId = 0,
    economyDetailView = "overview",
    economyDetailX = false,
    economyDetailY = false,
    showAllianceTerritoryColors = false, -- 2.6.32 community: original alliance territory overlay
    enableLocationColors = true, -- Naga: color WORLD_MAP_LOCATIONS list by zone progress
    enableLocationTooltips = true, -- Naga: show progress breakdown on location hover
    allianceNeutralWhite = true,
    historyByCharacter = {},
    milestoneStateByCharacter = {},
    historyEnabled = true,
    showMilestones = true,
    historyRetentionDays = 730,
    goalPlannerMode = "near",
    goalPlannerCategory = "all",
    historyMetric = "npcKills",
    historyRangeDays = 30,
    mapLabels203Migrated = false,
    percentColorBlack204Migrated = false,
    percentColorBlack205Migrated = false,
    economyPlayerInit210Migrated = false,
}


local FONT_PROFILES =
{
    classic =
    {
        overlay = "$(ANTIQUE_FONT)|28",
        header = "$(ANTIQUE_FONT)|46",
        questTitle = "$(ANTIQUE_FONT)|20",
        questBody = "$(ANTIQUE_FONT)|18",
    },
    handwritten =
    {
        overlay = "$(HANDWRITTEN_FONT)|30",
        header = "$(HANDWRITTEN_FONT)|48",
        questTitle = "$(HANDWRITTEN_FONT)|22",
        questBody = "$(HANDWRITTEN_FONT)|20",
    },
    scroll =
    {
        overlay = "$(HANDWRITTEN_FONT)|32",
        header = "$(HANDWRITTEN_FONT)|50",
        questTitle = "$(HANDWRITTEN_FONT)|24",
        questBody = "$(HANDWRITTEN_FONT)|21",
    },
    stone =
    {
        overlay = "$(STONE_TABLET_FONT)|28",
        header = "$(STONE_TABLET_FONT)|46",
        questTitle = "$(STONE_TABLET_FONT)|22",
        questBody = "$(STONE_TABLET_FONT)|18",
    },
    standard =
    {
        overlay = "$(MEDIUM_FONT)|28",
        header = "$(MEDIUM_FONT)|46",
        questTitle = "$(MEDIUM_FONT)|21",
        questBody = "$(MEDIUM_FONT)|18",
    },
    bold =
    {
        overlay = "$(BOLD_FONT)|28",
        header = "$(BOLD_FONT)|46",
        questTitle = "$(BOLD_FONT)|21",
        questBody = "$(BOLD_FONT)|18",
    },
    chat =
    {
        overlay = "$(CHAT_FONT)|28",
        header = "$(CHAT_FONT)|46",
        questTitle = "$(CHAT_FONT)|21",
        questBody = "$(CHAT_FONT)|18",
    },
    title =
    {
        overlay = "$(BOLD_FONT)|30",
        header = "$(BOLD_FONT)|50",
        questTitle = "$(BOLD_FONT)|24",
        questBody = "$(MEDIUM_FONT)|18",
    },
    outline =
    {
        overlay = "$(BOLD_FONT)|28|thick-outline",
        header = "$(BOLD_FONT)|46|thick-outline",
        questTitle = "$(BOLD_FONT)|21|thick-outline",
        questBody = "$(BOLD_FONT)|18|thick-outline",
    },
    compact =
    {
        overlay = "$(MEDIUM_FONT)|25",
        header = "$(MEDIUM_FONT)|42",
        questTitle = "$(MEDIUM_FONT)|19",
        questBody = "$(MEDIUM_FONT)|16",
    },
}

local FONT_STYLE_ORDER =
{
    "classic",
    "handwritten",
    "scroll",
    "stone",
    "standard",
    "bold",
    "chat",
    "title",
    "outline",
    "compact",
}

local FONT_STYLE_NAME_KEYS =
{
    classic = "FONT_CLASSIC",
    handwritten = "FONT_HANDWRITTEN",
    scroll = "FONT_SCROLL",
    stone = "FONT_STONE",
    standard = "FONT_STANDARD",
    bold = "FONT_BOLD",
    chat = "FONT_CHAT",
    title = "FONT_TITLE",
    outline = "FONT_OUTLINE",
    compact = "FONT_COMPACT",
}


local AURBIS_SYMBOLIC_ZONE_IDS =
{
    [980] = true, -- Clockwork City
}

-- ESO's Aurbis map uses symbolic realm locations that are not derived from the
-- geographical center of the corresponding zone map. Clockwork City is the
-- known outlier that cannot be projected reliably through universal map
-- coordinates, so use its actual normalized symbol position on the current
-- Aurbis layout. Values are normalized to ZO_WorldMapContainer.
local AURBIS_FIXED_ZONE_POSITIONS =
{
    [980] = { x = 0.3672, y = 0.8294 }, -- Clockwork City
}

local COMPLETION_TYPES =
{
    ZONE_COMPLETION_TYPE_PRIORITY_QUESTS,
    ZONE_COMPLETION_TYPE_WAYSHRINES,
    ZONE_COMPLETION_TYPE_DELVES,
    ZONE_COMPLETION_TYPE_GROUP_DELVES,
    ZONE_COMPLETION_TYPE_POINTS_OF_INTEREST,
    ZONE_COMPLETION_TYPE_STRIKING_LOCALES,
    ZONE_COMPLETION_TYPE_SET_STATIONS,
    ZONE_COMPLETION_TYPE_MUNDUS_STONES,
    ZONE_COMPLETION_TYPE_PUBLIC_DUNGEONS,
    ZONE_COMPLETION_TYPE_WORLD_EVENTS,
    ZONE_COMPLETION_TYPE_GROUP_BOSSES,
    ZONE_COMPLETION_TYPE_SKYSHARDS,
    ZONE_COMPLETION_TYPE_MAGES_GUILD_BOOKS,
}

-- Progress sub-pages: zone completion, Collections and Achievements.
-- Keep the API constants as names and resolve them at runtime so a missing or
-- renamed category can never prevent the addon from loading after an ESO update.
-- These collection counters are informational only and NEVER change Tamriel %.
local COLLECTION_STAT_DEFINITIONS =
{
    { typeGlobal = "COLLECTIBLE_CATEGORY_TYPE_MOUNT",                labelKey = "STAT_COLLECTION_MOUNTS" },
    { typeGlobal = "COLLECTIBLE_CATEGORY_TYPE_VANITY_PET",           labelKey = "STAT_COLLECTION_PETS" },
    { typeGlobal = "COLLECTIBLE_CATEGORY_TYPE_COSTUME",              labelKey = "STAT_COLLECTION_COSTUMES" },
    { typeGlobal = "COLLECTIBLE_CATEGORY_TYPE_PERSONALITY",          labelKey = "STAT_COLLECTION_PERSONALITIES" },
    { typeGlobal = "COLLECTIBLE_CATEGORY_TYPE_POLYMORPH",            labelKey = "STAT_COLLECTION_POLYMORPHS" },
    { typeGlobal = "COLLECTIBLE_CATEGORY_TYPE_SKIN",                 labelKey = "STAT_COLLECTION_SKINS" },
    { typeGlobal = "COLLECTIBLE_CATEGORY_TYPE_MEMENTO",              labelKey = "STAT_COLLECTION_MEMENTOS" },
    { typeGlobal = "COLLECTIBLE_CATEGORY_TYPE_EMOTE",                labelKey = "STAT_COLLECTION_EMOTES" },
    { typeGlobal = "COLLECTIBLE_CATEGORY_TYPE_HOUSE",                labelKey = "STAT_COLLECTION_HOUSES" },
    { typeGlobal = "COLLECTIBLE_CATEGORY_TYPE_HAT",                  labelKey = "STAT_COLLECTION_HATS" },
    { typeGlobal = "COLLECTIBLE_CATEGORY_TYPE_BODY_MARKING",         labelKey = "STAT_COLLECTION_BODY_MARKINGS" },
    { typeGlobal = "COLLECTIBLE_CATEGORY_TYPE_HEAD_MARKING",         labelKey = "STAT_COLLECTION_HEAD_MARKINGS" },
    { typeGlobal = "COLLECTIBLE_CATEGORY_TYPE_HAIR",                 labelKey = "STAT_COLLECTION_HAIR" },
    { typeGlobal = "COLLECTIBLE_CATEGORY_TYPE_FACIAL_ACCESSORY",     labelKey = "STAT_COLLECTION_FACIAL_ACCESSORIES" },
    { typeGlobal = "COLLECTIBLE_CATEGORY_TYPE_COMBINATION_FRAGMENT", labelKey = "STAT_COLLECTION_FRAGMENTS" },
}

local COMPLETION_LOCALIZATION_KEYS =
{
    [ZONE_COMPLETION_TYPE_PRIORITY_QUESTS] = "CAT_QUESTS",
    [ZONE_COMPLETION_TYPE_WAYSHRINES] = "CAT_WAYSHRINES",
    [ZONE_COMPLETION_TYPE_DELVES] = "CAT_DELVES",
    [ZONE_COMPLETION_TYPE_GROUP_DELVES] = "CAT_GROUP_DELVES",
    [ZONE_COMPLETION_TYPE_POINTS_OF_INTEREST] = "CAT_POIS",
    [ZONE_COMPLETION_TYPE_STRIKING_LOCALES] = "CAT_STRIKING",
    [ZONE_COMPLETION_TYPE_SET_STATIONS] = "CAT_SET_STATIONS",
    [ZONE_COMPLETION_TYPE_MUNDUS_STONES] = "CAT_MUNDUS",
    [ZONE_COMPLETION_TYPE_PUBLIC_DUNGEONS] = "CAT_PUBLIC_DUNGEONS",
    [ZONE_COMPLETION_TYPE_WORLD_EVENTS] = "CAT_WORLD_EVENTS",
    [ZONE_COMPLETION_TYPE_GROUP_BOSSES] = "CAT_WORLD_BOSSES",
    [ZONE_COMPLETION_TYPE_SKYSHARDS] = "CAT_SKYSHARDS",
    [ZONE_COMPLETION_TYPE_MAGES_GUILD_BOOKS] = "CAT_LOREBOOKS",
}

local SIDE_QUEST_CATEGORY_KEY = "side_quests"
local CROWN_QUEST_CATEGORY_KEY = "crown_quests"
local ZONE_STABLE_MOUNT_CATEGORY_KEY = "zone_stable_mount"

-- Update 49 stablemaster mounts that are intentionally tied to specific zones.
-- This is an informational Zone Focus row only; it never changes ESO's native
-- Zone Guide percentage. Zone IDs are stable game identifiers, so the mapping
-- is independent from the client/TPM language.
local ZONE_STABLEMASTER_MOUNTS =
{
    [1011] = { name = "Highland Spotted Lynx", price = 100000 }, -- Summerset
    [888]  = { name = "Highland Spotted Lynx", price = 100000 }, -- Craglorn
    [381]  = { name = "Ja'zennji Siir Fox", price = 50000 }, -- Auridon
    [1261] = { name = "Ja'zennji Siir Fox", price = 50000 }, -- Blackwood
    [108]  = { name = "Noble Riverhold Senche-Lion", price = 50000 }, -- Greenshade
    [20]   = { name = "Noble Riverhold Senche-Lion", price = 50000 }, -- Rivenspire
    [383]  = { name = "Faunfrolic Great Elk", price = 200000 }, -- Grahtwood
    [58]   = { name = "Faunfrolic Great Elk", price = 200000 }, -- Malabal Tor
    [1318] = { name = "Faunfrolic Great Elk", price = 200000 }, -- High Isle
    [382]  = { name = "Senche-Cougar", price = 50000 }, -- Reaper's March
    [1086] = { name = "Spotted Duneracer Senche-raht", price = 200000 }, -- Northern Elsweyr
    [1133] = { name = "Spotted Duneracer Senche-raht", price = 200000 }, -- Southern Elsweyr
    [726]  = { name = "Shadowghost Guar", price = 50000 }, -- Murkmire
    [117]  = { name = "Shadowghost Guar", price = 50000 }, -- Shadowfen
    [41]   = { name = "Shadowghost Guar", price = 50000 }, -- Stonefalls
    [1502] = { name = "Frostborn Durzog Mangler", price = 100000 }, -- Solstice
    [347]  = { name = "Frostborn Durzog Mangler", price = 100000 }, -- Coldharbour
    [1282] = { name = "Frostborn Durzog Mangler", price = 100000 }, -- Fargrave
    [57]   = { name = "Hearthfire Kagouti", price = 100000 }, -- Deshaan
    [1414] = { name = "Rubyflare Torchnix", price = 100000 }, -- Telvanni Peninsula
    [849]  = { name = "Rubyflare Torchnix", price = 100000 }, -- Vvardenfell
    [103]  = { name = "Yorgrim River Ram", price = 100000 }, -- The Rift
    [101]  = { name = "Yorgrim River Ram", price = 100000 }, -- Eastmarch
    [19]   = { name = "Yorgrim River Ram", price = 100000 }, -- Stormhaven
    [1160] = { name = "Ashbone Sabre Cat", price = 100000 }, -- Western Skyrim
    [92]   = { name = "Ashbone Sabre Cat", price = 100000 }, -- Bangkorai
    [1207] = { name = "Snow Bear", price = 50000 }, -- The Reach
    [684]  = { name = "Snow Bear", price = 50000 }, -- Wrothgar
    [3]    = { name = "Bleakrock Snowdog", price = 50000 }, -- Glenumbra
    [1383] = { name = "Bleakrock Snowdog", price = 50000 }, -- Galen
    [104]  = { name = "Hammerfell Camel", price = 50000 }, -- Alik'r Desert
    [816]  = { name = "Hammerfell Camel", price = 50000 }, -- Hew's Bane
    [823]  = { name = "Sapiarchic Senche-Serval", price = 100000 }, -- Gold Coast
    [1443] = { name = "Sapiarchic Senche-Serval", price = 100000 }, -- West Weald
    [980]  = { name = "Ebon Dwarven Horse", price = 400000 }, -- Clockwork City
}

local STATISTICS_CATEGORY_ICON_TEXTURES =
{
    [ZONE_COMPLETION_TYPE_PRIORITY_QUESTS] = "NagaMapaCompleto/art/cat_quests.dds",
    [ZONE_COMPLETION_TYPE_WAYSHRINES] = "NagaMapaCompleto/art/cat_wayshrine.dds",
    [ZONE_COMPLETION_TYPE_DELVES] = "NagaMapaCompleto/art/cat_delve.dds",
    [ZONE_COMPLETION_TYPE_GROUP_DELVES] = "NagaMapaCompleto/art/cat_groupdelve.dds",
    [ZONE_COMPLETION_TYPE_POINTS_OF_INTEREST] = "NagaMapaCompleto/art/cat_poi.dds",
    [ZONE_COMPLETION_TYPE_STRIKING_LOCALES] = "NagaMapaCompleto/art/cat_striking.dds",
    [ZONE_COMPLETION_TYPE_SET_STATIONS] = "NagaMapaCompleto/art/cat_setstation.dds",
    [ZONE_COMPLETION_TYPE_MUNDUS_STONES] = "NagaMapaCompleto/art/cat_mundus.dds",
    [ZONE_COMPLETION_TYPE_PUBLIC_DUNGEONS] = "NagaMapaCompleto/art/cat_publicdungeon.dds",
    [ZONE_COMPLETION_TYPE_WORLD_EVENTS] = "NagaMapaCompleto/art/cat_event.dds",
    [ZONE_COMPLETION_TYPE_GROUP_BOSSES] = "NagaMapaCompleto/art/cat_boss.dds",
    [ZONE_COMPLETION_TYPE_SKYSHARDS] = "NagaMapaCompleto/art/cat_skyshard.dds",
    [ZONE_COMPLETION_TYPE_MAGES_GUILD_BOOKS] = "NagaMapaCompleto/art/cat_book.dds",
    [SIDE_QUEST_CATEGORY_KEY] = "NagaMapaCompleto/art/cat_sidequests.dds",
    [CROWN_QUEST_CATEGORY_KEY] = "NagaMapaCompleto/art/cat_crown.dds",
    [ZONE_STABLE_MOUNT_CATEGORY_KEY] = "NagaMapaCompleto/art/cat_crown.dds",
}
local ESO_GOLD_HEX = "E6C45C"
local SIDE_QUEST_SCAN_MAX_ID = 12000
local STATISTICS_VISIBLE_ZONE_ROWS = 7
local STATISTICS_PERCENT_GRAY_HEX = "B8B4A8"
local HISTORY_CHECKPOINT_MS = 600000 -- 10 minutes; SavedVariables are still physically written by ESO itself.
local HISTORY_RETENTION_DAYS = 730
local HISTORY_MAX_SESSIONS = 80
local HISTORY_MAX_CHART_POINTS = 60
local HISTORY_SAMPLE_INTERVAL_SECONDS = 300 -- detailed recent chart cadence; large changes can create an earlier point.
local HISTORY_SAMPLE_RETENTION_DAYS = 45 -- older history uses daily close + daily high/low.
local CHARACTER_PLAYTIME_RETENTION_DAYS = 365 -- dedicated Character page date/time + playtime ledger.
local CURRENT_SCHEMA_VERSION = 4 -- schema v4: expanded Statistics theme color channels.
local HISTORY_MAX_SAMPLES = 1400
local SESSION_CONTINUITY_SECONDS = 300

local GOAL_PLANNER_MODES = { "near", "recommended" }
local GOAL_CATEGORY_FILTERS =
{
    { key = "all", completionType = nil, labelKey = "GOAL_CATEGORY_ALL" },
    { key = "quests", completionType = ZONE_COMPLETION_TYPE_PRIORITY_QUESTS, labelKey = "GOAL_CATEGORY_QUESTS" },
    { key = "skyshards", completionType = ZONE_COMPLETION_TYPE_SKYSHARDS, labelKey = "GOAL_CATEGORY_SKYSHARDS" },
    { key = "bosses", completionType = ZONE_COMPLETION_TYPE_GROUP_BOSSES, labelKey = "GOAL_CATEGORY_BOSSES" },
}
local HISTORY_RANGES = { 7, 30, 90, 365, 730 }

local function Round(value)
    return math.floor((value or 0) + 0.5)
end

local function Clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

-- Detach legacy SavedVariables from ZO_SavedVars metatables before migration.
local function TPM_DeepCopyPlain(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, child in pairs(value) do
        if type(key) ~= "function" and type(child) ~= "function" then
            copy[TPM_DeepCopyPlain(key, seen)] = TPM_DeepCopyPlain(child, seen)
        end
    end
    return copy
end

local function RGBToHex(r, g, b)
    local function Byte(value)
        return Clamp(math.floor(((tonumber(value) or 0) * 255) + 0.5), 0, 255)
    end
    return string.format("%02X%02X%02X", Byte(r), Byte(g), Byte(b))
end

local function HexToRGB(hex)
    hex = tostring(hex or "FFFFFF")
    if #hex < 6 then hex = "FFFFFF" end
    local r = (tonumber(string.sub(hex, 1, 2), 16) or 255) / 255
    local g = (tonumber(string.sub(hex, 3, 4), 16) or 255) / 255
    local b = (tonumber(string.sub(hex, 5, 6), 16) or 255) / 255
    return r, g, b
end

local function ScaleFontSpec(fontSpec, scalePercent)
    local scale = Clamp(tonumber(scalePercent) or 100, 70, 160) / 100
    local replaced = false
    return string.gsub(fontSpec or "", "|(%d+)", function(size)
        if replaced then return "|" .. size end
        replaced = true
        local scaled = Clamp(Round((tonumber(size) or 18) * scale), 10, 80)
        return "|" .. tostring(scaled)
    end, 1)
end

local function GetPercentColor(percent)
    if percent >= 100 then
        return "66FF66"
    elseif percent >= 75 then
        return "B8E65B"
    elseif percent >= 50 then
        return "FFE066"
    elseif percent >= 25 then
        return "FFB347"
    end
    return "FF6B6B"
end

function TPM:IsStatisticsDarkDesign()
    local d = self and self.saved and self.saved.statisticsThemeDesign
    return d == "dark" or d == "cyber" or d == "neon" or d == "arctic" or d == "ember" or d == "matrix"
end

-- Futuristic / modern theme presets for the Statistics journal
TPM.THEME_PRESETS = {
    dark = {
        label = "Dark Modern",
        bg = {0.05, 0.06, 0.08, 0.97},
        inner = {0.07, 0.08, 0.10, 0.98},
        edge = {0.28, 0.62, 0.82, 0.95},
        heading = {0.55, 0.85, 1.00},
        accent = {0.35, 0.78, 0.95},
        progress = {0.30, 0.90, 0.70},
        text = {0.90, 0.93, 0.96},
    },
    cyber = {
        label = "Cyber",
        bg = {0.02, 0.04, 0.08, 0.97},
        inner = {0.04, 0.07, 0.12, 0.98},
        edge = {0.00, 0.90, 1.00, 0.95},
        heading = {0.00, 0.95, 1.00},
        accent = {1.00, 0.20, 0.85},
        progress = {0.20, 1.00, 0.90},
        text = {0.85, 0.95, 1.00},
    },
    neon = {
        label = "Neon",
        bg = {0.04, 0.02, 0.08, 0.97},
        inner = {0.08, 0.04, 0.12, 0.98},
        edge = {0.90, 0.20, 1.00, 0.95},
        heading = {1.00, 0.40, 0.95},
        accent = {0.40, 1.00, 0.50},
        progress = {1.00, 0.90, 0.20},
        text = {0.95, 0.90, 1.00},
    },
    arctic = {
        label = "Arctic",
        bg = {0.06, 0.09, 0.12, 0.97},
        inner = {0.10, 0.14, 0.18, 0.98},
        edge = {0.70, 0.90, 1.00, 0.95},
        heading = {0.85, 0.95, 1.00},
        accent = {0.50, 0.80, 1.00},
        progress = {0.40, 0.85, 1.00},
        text = {0.92, 0.96, 1.00},
    },
    ember = {
        label = "Ember",
        bg = {0.08, 0.03, 0.02, 0.97},
        inner = {0.12, 0.05, 0.04, 0.98},
        edge = {1.00, 0.45, 0.15, 0.95},
        heading = {1.00, 0.70, 0.30},
        accent = {1.00, 0.35, 0.20},
        progress = {1.00, 0.55, 0.15},
        text = {1.00, 0.92, 0.85},
    },
    matrix = {
        label = "Matrix",
        bg = {0.01, 0.04, 0.01, 0.97},
        inner = {0.02, 0.07, 0.02, 0.98},
        edge = {0.20, 1.00, 0.30, 0.95},
        heading = {0.40, 1.00, 0.45},
        accent = {0.20, 0.95, 0.35},
        progress = {0.50, 1.00, 0.40},
        text = {0.80, 1.00, 0.85},
    },
    tpm = {
        label = "Classic Gold",
        bg = {0.012, 0.011, 0.009, 1.00},
        inner = {0.035, 0.031, 0.024, 1.00},
        edge = {0.78, 0.62, 0.24, 1.00},
        heading = {0.95, 0.82, 0.36},
        accent = {0.95, 0.82, 0.36},
        progress = {0.95, 0.82, 0.12},
        text = {0.88, 0.84, 0.74},
    },
    vanilla = {
        label = "Transparent",
        bg = {0.002, 0.008, 0.014, 0.80},
        inner = {0.004, 0.016, 0.028, 0.50},
        edge = {0.78, 0.62, 0.24, 0.96},
        heading = {0.95, 0.82, 0.36},
        accent = {0.95, 0.82, 0.36},
        progress = {0.95, 0.82, 0.12},
        text = {0.92, 0.90, 0.84},
    },
}

function TPM:GetThemePreset()
    local design = (self.saved and self.saved.statisticsThemeDesign) or "dark"
    return self.THEME_PRESETS[design] or self.THEME_PRESETS.dark
end

function TPM:ApplyThemePresetColors()
    local preset = self:GetThemePreset()
    if not preset or not self.saved then return end
    self.saved.statisticsThemeHeading = { r = preset.heading[1], g = preset.heading[2], b = preset.heading[3] }
    self.saved.statisticsThemeAccent = { r = preset.accent[1], g = preset.accent[2], b = preset.accent[3] }
    self.saved.statisticsThemeProgress = { r = preset.progress[1], g = preset.progress[2], b = preset.progress[3] }
    self.saved.statisticsThemeText = { r = preset.text[1], g = preset.text[2], b = preset.text[3] }
    self.saved.statisticsThemeBackground = { r = preset.bg[1], g = preset.bg[2], b = preset.bg[3], a = preset.bg[4] }
end

function TPM:GetDisplayPercentColor(percent)
    -- Map / zone percentage color is controlled only by the user setting
    -- "Percentage color". Statistics UI themes must never override it.
    local mode = self and self.saved and self.saved.percentColorMode or "black"
    if mode == "black" then
        return "000000"
    elseif mode == "brown" then
        return "5A3A22"
    elseif mode == "gold" then
        return "C9A24A"
    elseif mode == "custom" then
        local color = self.saved and self.saved.customPercentColor or DEFAULTS.customPercentColor
        return RGBToHex(color.r, color.g, color.b)
    elseif mode == "progress" then
        return GetPercentColor(percent)
    end
    return GetPercentColor(percent)
end

function TPM:GetStatisticsPercentTextColor(percent)
    if self:IsStatisticsDarkDesign() then
        return "FFFFFF"
    end
    percent = Clamp(tonumber(percent) or 0, 0, 100)
    if percent >= 100 then return ESO_GOLD_HEX end
    return STATISTICS_PERCENT_GRAY_HEX
end

function TPM:GetStatisticsProgressColor(percent)
    if self:IsStatisticsDarkDesign() then
        return 1, 1, 1
    end
    -- Deliberately darker than the map-marker palette. The journal uses one
    -- continuous red -> ESO-gold ramp so the bars remain readable on the dark
    -- background without becoming neon.
    local t = Clamp(tonumber(percent) or 0, 0, 100) / 100
    local startR, startG, startB = 0.46, 0.095, 0.065
    local endR, endG, endB = HexToRGB(ESO_GOLD_HEX)
    local r = startR + ((endR - startR) * t)
    local g = startG + ((endG - startG) * t)
    local b = startB + ((endB - startB) * t)
    return r, g, b
end

local function FormatNumber(value)
    value = math.max(0, Round(tonumber(value) or 0))
    return ZO_CommaDelimitNumber(value)
end

function TPM:GetPlayerProgressData()
    local level = GetUnitLevel("player") or 0
    local cp = GetPlayerChampionPointsEarned() or 0
    local canGainCP = CanUnitGainChampionPoints("player") == true
    local maxChampionPoints = (GetMaxSpendableChampionPointsInAttribute() or 0) * GetNumChampionDisciplines()

    local atChampionCap = canGainCP and maxChampionPoints > 0 and cp >= maxChampionPoints
    local current, maximum = 0, 0
    if atChampionCap then
        current, maximum = 1, 1
    elseif canGainCP then
        current = GetPlayerChampionXP() or 0
        maximum = GetNumChampionXPInChampionPoint(math.max(cp, 1)) or 0
    else
        current = GetUnitXP("player") or 0
        maximum = GetUnitXPMax("player") or 0
    end

    local percent = atChampionCap and 100 or 0
    if not atChampionCap and maximum > 0 then
        percent = Clamp(Round((current / maximum) * 100), 0, 100)
    end

    return {
        level = level,
        championPoints = cp,
        maxChampionPoints = maxChampionPoints,
        current = current,
        maximum = maximum,
        percent = percent,
        isChampionProgress = canGainCP,
        atChampionCap = atChampionCap,
    }
end

function TPM:GetCurrentCharacterStatsKey()
    local characterId = GetCurrentCharacterId()
    if characterId and characterId ~= 0 then
        return tostring(characterId)
    end
    local name = GetUnitName("player") or ""
    if name ~= "" then return name end
    return "player"
end

local function TPM_Now()
    return math.max(0, tonumber(GetTimeStamp()) or 0)
end

function TPM:GetPlayerCombatStats(characterKey)
    if not self.saved then
        return { pvpKills = 0, pvpDeaths = 0, npcKills = 0, pveDeaths = 0, bossKills = 0, playSeconds = 0, esoPlayedSeconds = 0 }
    end
    if type(self.saved.combatStatsByCharacter) ~= "table" then
        self.saved.combatStatsByCharacter = {}
    end

    local function NormalizeCounter(value)
        local numberValue = tonumber(value)
        if numberValue == nil or numberValue ~= numberValue or numberValue <= 0 then return 0 end
        return math.floor(numberValue + 0.5)
    end

    local key = characterKey or self:GetCurrentCharacterStatsKey()
    local stats = self.saved.combatStatsByCharacter[key]
    if type(stats) ~= "table" then
        local startedAt = tonumber(GetTimeStamp()) or 0
        local startLevel = tonumber(GetUnitLevel("player")) or 1
        stats = {
            pvpKills = 0,
            pvpDeaths = 0,
            npcKills = 0,
            pveDeaths = 0,
            bossKills = 0,
            playSeconds = 0,
            esoPlayedSeconds = 0,
            esoPlayedBaselineSeconds = nil,
            trackingVersion = VERSION,
            trackingStartedAt = math.max(0, startedAt),
            trackingStartLevel = math.max(1, math.floor(startLevel + 0.5)),
        }
        self.saved.combatStatsByCharacter[key] = stats
    end

    -- Lifetime combat counters are never reset automatically. Invalid/legacy
    -- SavedVariable values are repaired without relying on any later helper.
    stats.pvpKills = NormalizeCounter(stats.pvpKills)
    stats.pvpDeaths = NormalizeCounter(stats.pvpDeaths)
    stats.npcKills = NormalizeCounter(stats.npcKills)
    stats.pveDeaths = NormalizeCounter(stats.pveDeaths)
    stats.bossKills = NormalizeCounter(stats.bossKills)
    stats.playSeconds = NormalizeCounter(stats.playSeconds)
    stats.esoPlayedSeconds = NormalizeCounter(stats.esoPlayedSeconds)
    if stats.esoPlayedBaselineSeconds ~= nil then
        stats.esoPlayedBaselineSeconds = NormalizeCounter(stats.esoPlayedBaselineSeconds)
    end
    stats.trackingVersion = stats.trackingVersion or VERSION

    if tonumber(stats.trackingStartedAt) == nil then
        stats.trackingStartedAt = math.max(0, tonumber(GetTimeStamp()) or 0)
    end
    local startLevel = tonumber(stats.trackingStartLevel)
    if startLevel == nil then
        startLevel = tonumber(GetUnitLevel("player")) or 1
    end
    stats.trackingStartLevel = math.max(1, math.floor((startLevel or 1) + 0.5))
    return stats
end

function TPM:SyncCurrentEsoPlayedTime()
    local key = self:GetCurrentCharacterStatsKey()
    local stats = self:GetPlayerCombatStats(key)
    local value = GetSecondsPlayed()
    if type(value) == "number" and value >= 0 then
        local seconds = math.max(0, Round(value))
        stats.esoPlayedSeconds = math.max(stats.esoPlayedSeconds or 0, seconds)
        -- Preserve the locally tracked 3.0.0 time when migrating: derive a
        -- baseline from ESO's lifetime value instead of resetting the counter.
        if stats.esoPlayedBaselineSeconds == nil then
            stats.esoPlayedBaselineSeconds = math.max(0, seconds - (stats.playSeconds or 0))
        end
    end
    return stats.esoPlayedSeconds or 0
end

function TPM:GetEsoPlayedSeconds()
    return self:SyncCurrentEsoPlayedTime()
end

function TPM:GetKnownAccountEsoPlayedSeconds()
    self:SyncCurrentEsoPlayedTime()
    local total = 0
    for _, stats in pairs((self.saved and self.saved.combatStatsByCharacter) or {}) do
        if type(stats) == "table" then
            total = total + math.max(0, Round(tonumber(stats.esoPlayedSeconds) or 0))
        end
    end
    return total
end

function TPM:GetPlayerCombatStatsView(characterKey)
    local stats = self:GetPlayerCombatStats(characterKey)
    local kd
    if stats.pvpDeaths <= 0 then
        kd = stats.pvpKills > 0 and stats.pvpKills or 0
    else
        kd = stats.pvpKills / stats.pvpDeaths
    end
    return {
        pvpKills = stats.pvpKills,
        pvpDeaths = stats.pvpDeaths,
        npcKills = stats.npcKills,
        pveDeaths = stats.pveDeaths or 0,
        bossKills = stats.bossKills,
        playSeconds = stats.playSeconds or 0,
        esoPlayedSeconds = stats.esoPlayedSeconds or 0,
        esoPlayedBaselineSeconds = stats.esoPlayedBaselineSeconds,
        kd = kd,
        trackingVersion = stats.trackingVersion or VERSION,
    }
end

function TPM:QueueCombatHistoryCheckpoint()
    if not self.saved or self.saved.historyEnabled == false or self.combatHistoryCheckpointQueued then return end
    self.combatHistoryCheckpointQueued = true
    zo_callLater(function()
        TPM.combatHistoryCheckpointQueued = false
        if not TPM.saved or TPM.saved.historyEnabled == false then return end
        local snapshot = TPM:CaptureHistorySnapshot(false)
        TPM:CheckpointHistory("combat", false, snapshot)
        if TPM.activeTrackedActivity and snapshot then
            TPM.activeTrackedActivity.lastSnapshot = snapshot
            TPM.activeTrackedActivity.lastSeenAt = snapshot.timestamp or TPM_Now()
        end
        -- IncrementPlayerCombatStat already refreshes Character page 2 immediately.
        -- Only repaint the PvE/PvP dashboard here after the delayed history snapshot.
        if TPM.statisticsWindow and not TPM.statisticsWindow:IsHidden()
            and TPM.saved.statisticsPage == "history"
            and TPM:GetStatisticsHistorySubPage() == 1 then
            TPM:RefreshHistoryStatisticsPage()
        end
    end, 350)
end

-- 2.7.8: Preserve daily PvE kill/boss totals on the Character page.
-- 2.7.9: Replace ambiguous daily relative bars with a clear Date / Playtime / Kills / Bosses table.
-- 2.7.13: Keep the combat tracker self-contained here. The general character-history
-- date helpers are declared later in this file, so calling them from this earlier
-- section would resolve to nil at runtime in Lua.
local function TPM_CombatLocalUtcOffsetSeconds()
    local nowStamp = tonumber(GetTimeStamp())
    local localSeconds = tonumber(GetSecondsSinceMidnight())
    if nowStamp and localSeconds then
        local utcSeconds = nowStamp % 86400
        local offset = localSeconds - utcSeconds
        if offset > 43200 then offset = offset - 86400 end
        if offset < -43200 then offset = offset + 86400 end
        return offset
    end
    return 0
end

local function TPM_CombatCharacterDayKey(timestamp, utcOffset)
    local adjusted = math.max(0, tonumber(timestamp) or 0) + (tonumber(utcOffset) or 0)
    return math.floor(adjusted / 86400)
end

-- npcKills is the existing TPM PvE-kill counter; bossKills is shown separately.
function TPM:RecordCharacterDailyCombat(field, amount)
    if field ~= "npcKills" and field ~= "bossKills" then return end
    local store = self:GetHistoryStore()
    if not store then return end
    if type(store.characterPlaytime365) ~= "table" then store.characterPlaytime365 = {} end
    local now = TPM_Now()
    local offset = TPM_CombatLocalUtcOffsetSeconds()
    local dayKey = TPM_CombatCharacterDayKey(now, offset)
    local key = tostring(dayKey)
    local entry = store.characterPlaytime365[key]
    if type(entry) ~= "table" then
        entry = { dayKey=dayKey, seconds=0, utcOffset=offset, firstUtcOffset=offset, lastUtcOffset=offset, zones={} }
        store.characterPlaytime365[key] = entry
    end
    local delta = math.max(0, Round(tonumber(amount) or 1))
    if field == "npcKills" then
        entry.npcKills = math.max(0, Round((tonumber(entry.npcKills) or 0) + delta))
    else
        entry.bossKills = math.max(0, Round((tonumber(entry.bossKills) or 0) + delta))
    end
    entry.combatDataReliable = true
end

function TPM:QueueStatisticsLiveRefresh()
    if self.statisticsLiveRefreshQueued or not self.saved
        or not self.statisticsWindow or self.statisticsWindow:IsHidden() then return end
    local page = self.saved.statisticsPage
    if page ~= "economy" and page ~= "history" then return end

    -- Record every event immediately; batch only the relatively expensive UI
    -- work when a kill or loot action emits several events in the same frame.
    self.statisticsLiveRefreshQueued = true
    zo_callLater(function()
        self.statisticsLiveRefreshQueued = false
        if not self.saved or not self.statisticsWindow or self.statisticsWindow:IsHidden() then return end
        local currentPage = self.saved.statisticsPage
        if currentPage == "economy" then
            self:RefreshEconomyStatisticsPage()
        elseif currentPage == "history" then
            if self:GetStatisticsHistorySubPage() == 2 then
                self:RefreshPlayerStatisticsPage()
            else
                self:RefreshHistoryStatisticsPage()
            end
        end
    end, 100)
end

function TPM:IncrementPlayerCombatStat(field, amount)
    local stats = self:GetPlayerCombatStats()
    if stats[field] == nil then return end
    local delta = tonumber(amount) or 1
    stats[field] = math.max(0, Round((tonumber(stats[field]) or 0) + delta))
    if field == "npcKills" or field == "bossKills" then self:RecordCharacterDailyCombat(field, delta) end
    if field == "npcKills" or field == "pveDeaths" or field == "bossKills"
        or field == "pvpKills" or field == "pvpDeaths" then
        self:QueueCombatHistoryCheckpoint()
    end
    if self.saved and self.saved.statisticsPage == "history" then self:QueueStatisticsLiveRefresh() end
end

-- v2.0.15 Economy journal ------------------------------------------------------
-- Current balances come directly from ESO. Received/spent totals are kept per
-- active character from 2.0.15 onward. ESO does not expose a complete historic
-- transaction ledger retroactively, so older account-wide totals are not
-- assigned to a character. Personal-bank balances remain account-wide by ESO design.
function TPM:GetEconomyCurrencyDefinitions()
    if self.economyCurrencyDefinitions then return self.economyCurrencyDefinitions end

    local definitions = {}
    local function Add(key, currencyType, locationMode, fallbackKey)
        if type(currencyType) ~= "number" then return end
        definitions[#definitions + 1] = {
            key = key,
            currencyType = currencyType,
            locationMode = locationMode or "account",
            fallbackKey = fallbackKey,
        }
    end

    Add("gold", _G.CURT_MONEY, "walletBank", "ECON_GOLD")
    Add("crowns", _G.CURT_CROWNS, "account", "ECON_CROWNS")
    Add("crownGems", _G.CURT_CROWN_GEMS, "account", "ECON_CROWN_GEMS")
    Add("tradeBars", _G.CURT_TRADE_BARS, "account", "ECON_TRADE_BARS")
    Add("seals", _G.CURT_SEALS or _G.CURT_ENDEAVOR_SEALS, "account", "ECON_SEALS")
    Add("alliancePoints", _G.CURT_ALLIANCE_POINTS, "walletBank", "ECON_ALLIANCE_POINTS")
    Add("telVar", _G.CURT_TELVAR_STONES, "walletBank", "ECON_TELVAR")
    Add("writVouchers", _G.CURT_WRIT_VOUCHERS, "walletBank", "ECON_WRIT_VOUCHERS")
    Add("transmute", _G.CURT_TRANSMUTE_CRYSTALS or _G.CURT_CHAOTIC_CREATIA, "account", "ECON_TRANSMUTE")
    Add("undauntedKeys", _G.CURT_UNDAUNTED_KEYS, "account", "ECON_UNDAUNTED_KEYS")
    Add("archivalFortunes", _G.CURT_ARCHIVAL_FORTUNES, "account", "ECON_ARCHIVAL_FORTUNES")
    Add("tomePoints", _G.CURT_TOME_POINTS, "account", "ECON_TOME_POINTS")

    self.economyCurrencyDefinitions = definitions
    self.economyCurrencyByType = {}
    for _, definition in ipairs(definitions) do
        self.economyCurrencyByType[definition.currencyType] = definition
    end
    return definitions
end

function TPM:GetEconomyCurrencyName(definition)
    if not definition then return "" end
    -- Keep currency labels in the addon's selected language instead of forcing
    -- the ESO client language. All supported definitions have localized names.
    local localized = definition.fallbackKey and self:L(definition.fallbackKey) or ""
    if localized ~= "" and localized ~= definition.fallbackKey then return localized end
    local name = GetCurrencyName(definition.currencyType, false, false)
    if type(name) == "string" and name ~= "" then return name end
    return tostring(definition.key or "")
end

local function SafeCurrencyAmount(currencyType, location)
    if type(currencyType) ~= "number" or type(location) ~= "number" then return 0 end
    return math.max(0, Round(tonumber(GetCurrencyAmount(currencyType, location)) or 0))
end

function TPM:GetEconomyPrimaryLocation(definition)
    if not definition then return nil end

    -- ESO's own wallet asks the API where a currency is stored instead of
    -- hard-coding every account/character currency. Keep a fallback for older
    -- API versions and compatibility aliases.
    local location = GetCurrencyPlayerStoredLocation(definition.currencyType)
    if type(location) == "number" then return location end

    if definition.locationMode == "walletBank" then
        return _G.CURRENCY_LOCATION_CHARACTER
    end
    return _G.CURRENCY_LOCATION_ACCOUNT or _G.CURRENCY_LOCATION_CHARACTER
end


function TPM:IsEconomyCurrencyBankable(definition)
    if not definition or type(definition.currencyType) ~= "number" then return false end
    local bankLocation = _G.CURRENCY_LOCATION_BANK
    if type(bankLocation) == "number" then
        return CanCurrencyBeStoredInLocation(definition.currencyType, bankLocation) == true
    end
    -- Fallback for API variants where CanCurrencyBeStoredInLocation is not exposed.
    return definition.locationMode == "walletBank"
end

function TPM:GetEconomyCurrentAmounts(definition)
    local amounts = { character = 0, bank = 0, total = 0, current = 0 }
    if not definition then return amounts end

    if self:IsEconomyCurrencyBankable(definition) then
        if type(_G.CURRENCY_LOCATION_CHARACTER) == "number" then
            amounts.character = SafeCurrencyAmount(definition.currencyType, _G.CURRENCY_LOCATION_CHARACTER)
        end
        if type(_G.CURRENCY_LOCATION_BANK) == "number" then
            amounts.bank = SafeCurrencyAmount(definition.currencyType, _G.CURRENCY_LOCATION_BANK)
        end
        amounts.total = amounts.character + amounts.bank
        amounts.current = amounts.total
        return amounts
    end

    local primaryLocation = self:GetEconomyPrimaryLocation(definition)
    if type(primaryLocation) == "number" then
        amounts.current = SafeCurrencyAmount(definition.currencyType, primaryLocation)
        amounts.total = amounts.current
        if primaryLocation == _G.CURRENCY_LOCATION_CHARACTER then
            amounts.character = amounts.current
        elseif primaryLocation == _G.CURRENCY_LOCATION_BANK then
            amounts.bank = amounts.current
        end
    end
    return amounts
end

function TPM:GetEconomyCurrentAmount(definition)
    return self:GetEconomyCurrentAmounts(definition).current
end

function TPM:MigrateLegacyEconomyStats(currentKey, currentCache)
    -- A populated character-ID ledger is authoritative. Older name-keyed
    -- snapshots must not replace it each time the economy page is refreshed.
    local function EconomyCacheScore(cache)
        if type(cache) ~= "table" or type(cache.currencies) ~= "table" then return 0 end
        local score = 0
        for _, e in pairs(cache.currencies) do
            if type(e) == "table" then
                score = score + math.max(0, tonumber(e.received) or 0)
                score = score + math.max(0, tonumber(e.spent) or 0)
                score = score + math.max(0, tonumber(e.bankDeposited) or 0)
                score = score + math.max(0, tonumber(e.bankWithdrawn) or 0)
                score = score + math.max(0, tonumber(e.fenceSales) or 0)
                score = score + math.max(0, tonumber(e.stolenGold) or 0)
                score = score + math.max(0, tonumber(e.bountyPaid) or 0)
            end
        end
        return score
    end

    local selected = type(currentCache) == "table" and currentCache or nil
    if not (selected and selected.legacyMigrationCompleted274)
        and EconomyCacheScore(selected) == 0 then
        local rawName = GetUnitName("player") or ""
        local formattedName = rawName ~= "" and zo_strformat("<<C:1>>", rawName) or ""
        local fallbackKeys = { "player" }
        if rawName ~= "" then fallbackKeys[#fallbackKeys + 1] = rawName end
        if formattedName ~= "" and formattedName ~= rawName then
            fallbackKeys[#fallbackKeys + 1] = formattedName
        end
        local bestScore = 0
        for _, legacyKey in ipairs(fallbackKeys) do
            local candidate = self.saved.economyStatsByCharacter[legacyKey]
            if legacyKey ~= currentKey and type(candidate) == "table" then
                local recordedName = candidate.characterName
                local nameMatches = type(recordedName) == "string" and recordedName ~= ""
                    and (recordedName == rawName or recordedName == formattedName)
                -- "player" alone does not identify a character. Leave any
                -- ambiguous legacy ledger intact instead of assigning it to
                -- whichever character happens to log in next.
                local eligible = legacyKey == "player" and nameMatches
                    or legacyKey ~= "player" and (not recordedName or recordedName == "" or nameMatches)
                local score = eligible and EconomyCacheScore(candidate) or 0
                if score > bestScore then selected, bestScore = candidate, score end
            end
        end
    end

    -- Detach both legacy sources and pre-existing aliases. New transactions
    -- must never mutate another character's table or the preserved snapshot.
    local stats = selected and TPM_DeepCopyPlain(selected) or { trackingVersion = "2.0.15", currencies = {} }
    stats.legacyMigrationCompleted274 = true
    return stats
end

function TPM:GetEconomyStats()
    if not self.saved then return { trackingVersion = "2.0.15", currencies = {} } end
    if type(self.saved.economyStatsByCharacter) ~= "table" then
        self.saved.economyStatsByCharacter = {}
    end
    if type(self.saved.historyByCharacter) ~= "table" then
        self.saved.historyByCharacter = {}
    end
    if type(self.saved.milestoneStateByCharacter) ~= "table" then
        self.saved.milestoneStateByCharacter = {}
    end
    local key = self:GetCurrentCharacterStatsKey()
    local stats = self.saved.economyStatsByCharacter[key]
    if type(stats) == "table" and self.economyPreparedStats == stats
        and self.economyPreparedStatsKey == key then
        return stats
    end
    stats = self:MigrateLegacyEconomyStats(key, stats)
    self.saved.economyStatsByCharacter[key] = stats
    stats.trackingVersion = stats.trackingVersion or "2.0.15"
    if type(stats.currencies) ~= "table" then stats.currencies = {} end

    local characterName = type(GetUnitName) == "function" and (GetUnitName("player") or "") or ""
    if type(zo_strformat) == "function" and characterName ~= "" then
        characterName = zo_strformat("<<C:1>>", characterName)
    end
    stats.characterName = characterName ~= "" and characterName or stats.characterName or self:L("STAT_PLAYER_UNKNOWN")

    for _, definition in ipairs(self:GetEconomyCurrencyDefinitions()) do
        local entry = stats.currencies[definition.key]
        if type(entry) ~= "table" then
            entry = { received = 0, spent = 0, bankDeposited = 0, bankWithdrawn = 0, fenceSales = 0, stolenGold = 0 }
            stats.currencies[definition.key] = entry
        end
        entry.received = math.max(0, Round(tonumber(entry.received) or 0))
        entry.spent = math.max(0, Round(tonumber(entry.spent) or 0))
        entry.bankDeposited = math.max(0, Round(tonumber(entry.bankDeposited) or 0))
        entry.bankWithdrawn = math.max(0, Round(tonumber(entry.bankWithdrawn) or 0))
        if definition.key == "gold" then
            entry.fenceSales = math.max(0, Round(tonumber(entry.fenceSales) or 0))
            entry.stolenGold = math.max(0, Round(tonumber(entry.stolenGold) or 0))
            entry.bountyPaid = math.max(0, Round(tonumber(entry.bountyPaid) or 0))
            entry.crimeTrackingVersion = entry.crimeTrackingVersion or "3.4.24"
            entry.bountyTrackingVersion = entry.bountyTrackingVersion or "2.6.22"
        end
    end
    self.economyPreparedStats = stats
    self.economyPreparedStatsKey = key
    return stats
end


-- v2.6.32 Zone Economy ---------------------------------------------------------
-- Zone ledgers intentionally start with 2.6.32. Existing global Economy totals
-- remain untouched because ESO cannot reconstruct historical transactions by zone.
function TPM:GetEconomyTrackingZoneId()
    if type(GetUnitZoneIndex) ~= "function" or type(GetZoneId) ~= "function" then return 0 end
    local zoneIndex = GetUnitZoneIndex("player")
    if not zoneIndex or zoneIndex <= 0 then return 0 end
    local zoneId = tonumber(GetZoneId(zoneIndex)) or 0
    if zoneId <= 0 then return 0 end
    -- Prefer the stable parent zone for interiors/delves when ESO exposes it.
    if type(GetParentZoneId) == "function" then
        local parentId = tonumber(GetParentZoneId(zoneId)) or 0
        if parentId > 0 then zoneId = parentId end
    end
    return zoneId
end

function TPM:GetEconomyZoneStore()
    if not self.saved then return nil end
    if type(self.saved.economyZoneStatsByCharacter) ~= "table" then
        self.saved.economyZoneStatsByCharacter = {}
    end
    if not tonumber(self.saved.economyZoneTrackingStartedAt) or tonumber(self.saved.economyZoneTrackingStartedAt) <= 0 then
        self.saved.economyZoneTrackingStartedAt = (type(GetTimeStamp) == "function" and GetTimeStamp()) or 0
    end
    local charKey = self:GetCurrentCharacterStatsKey()
    local store = self.saved.economyZoneStatsByCharacter[charKey]
    if type(store) ~= "table" then
        store = { trackingVersion = "2.6.32", zones = {} }
        self.saved.economyZoneStatsByCharacter[charKey] = store
    end
    if type(store.zones) ~= "table" then store.zones = {} end
    return store
end

function TPM:GetEconomyZoneEntry(zoneId, create)
    zoneId = tonumber(zoneId) or 0
    if zoneId <= 0 then return nil end
    local store = self:GetEconomyZoneStore()
    if not store then return nil end
    local key = tostring(zoneId)
    local entry = store.zones[key]
    if type(entry) ~= "table" and create then
        entry = {
            zoneId = zoneId, received = 0, spent = 0, bankDeposited = 0, bankWithdrawn = 0,
            fenceSales = 0, stolenGold = 0, bountyPaid = 0, transactions = 0,
        }
        store.zones[key] = entry
    end
    if type(entry) == "table" then
        for _, field in ipairs({"received","spent","bankDeposited","bankWithdrawn","fenceSales","stolenGold","bountyPaid","transactions"}) do
            entry[field] = math.max(0, Round(tonumber(entry[field]) or 0))
        end
    end
    return entry
end

function TPM:RecordEconomyZoneDelta(delta, reason)
    delta = tonumber(delta) or 0
    if delta == 0 then return end
    local zoneId = self:GetEconomyTrackingZoneId()
    local entry = self:GetEconomyZoneEntry(zoneId, true)
    if not entry then return end
    entry.transactions = (entry.transactions or 0) + 1
    if delta > 0 then entry.received = (entry.received or 0) + delta
    else entry.spent = (entry.spent or 0) + math.abs(delta) end
    if delta > 0 then
        if _G.CURRENCY_CHANGE_REASON_SELL_STOLEN and reason == _G.CURRENCY_CHANGE_REASON_SELL_STOLEN then
            entry.fenceSales = (entry.fenceSales or 0) + delta
        elseif (_G.CURRENCY_CHANGE_REASON_LOOT_STOLEN and reason == _G.CURRENCY_CHANGE_REASON_LOOT_STOLEN)
            or (_G.CURRENCY_CHANGE_REASON_PICKPOCKET and reason == _G.CURRENCY_CHANGE_REASON_PICKPOCKET) then
            entry.stolenGold = (entry.stolenGold or 0) + delta
        end
    end
end

function TPM:RecordEconomyZoneBankTransfer(amount, isDeposit)
    amount = math.max(0, tonumber(amount) or 0)
    if amount <= 0 then return end
    local entry = self:GetEconomyZoneEntry(self:GetEconomyTrackingZoneId(), true)
    if not entry then return end
    if isDeposit then entry.bankDeposited = (entry.bankDeposited or 0) + amount
    else entry.bankWithdrawn = (entry.bankWithdrawn or 0) + amount end
end

function TPM:GetEconomyZoneName(zoneId)
    zoneId = tonumber(zoneId) or 0
    if zoneId <= 0 then return self:L("ECON_DETAIL_ALL_TAMRIEL") end

    -- Since 2.7.1 TPM follows the ESO client language. ESO's own zone-name API
    -- therefore already returns the language we need and no localization library
    -- lookup is required here.
    local name = GetZoneNameById(zoneId) or ""
    if name ~= "" then
        local formatted = ZO_CachedStrFormat(SI_ZONE_NAME, name)
        if formatted and formatted ~= "" then return formatted end
        return zo_strformat("<<C:1>>", name)
    end

    return tostring(zoneId)
end

function TPM:GetEconomyZoneChoices()
    local choices = { { zoneId = 0, name = self:L("ECON_DETAIL_ALL_TAMRIEL") } }
    local seen = {}

    -- Use TPM's already validated progress-zone catalogue so the selector is
    -- useful immediately after installation instead of only after a purchase.
    for zoneId in pairs(self:GetAllProgressZoneIds() or {}) do
        zoneId = tonumber(zoneId) or 0
        if zoneId > 0 and not seen[zoneId] then
            seen[zoneId] = true
            choices[#choices + 1] = { zoneId = zoneId, name = self:GetEconomyZoneName(zoneId) }
        end
    end

    -- Keep recorded zones available even if an unusual zone is not part of the
    -- normal completion catalogue.
    local store = self:GetEconomyZoneStore()
    for _, entry in pairs((store and store.zones) or {}) do
        local zid = tonumber(entry.zoneId) or 0
        if zid > 0 and not seen[zid] then
            seen[zid] = true
            choices[#choices + 1] = { zoneId = zid, name = self:GetEconomyZoneName(zid) }
        end
    end

    table.sort(choices, function(a,b)
        if a.zoneId == 0 then return true end
        if b.zoneId == 0 then return false end
        return string.lower(a.name or "") < string.lower(b.name or "")
    end)
    return choices
end

function TPM:GetEconomyDetailAggregate(zoneId)
    local result = { received=0, spent=0, bankDeposited=0, bankWithdrawn=0, fenceSales=0, stolenGold=0, bountyPaid=0, transactions=0 }
    local store = self:GetEconomyZoneStore()
    if not store then return result end
    for _, e in pairs(store.zones or {}) do
        if (tonumber(zoneId) or 0) == 0 or tonumber(e.zoneId) == tonumber(zoneId) then
            for k in pairs(result) do result[k] = result[k] + math.max(0, tonumber(e[k]) or 0) end
        end
    end
    result.net = result.received - result.spent
    return result
end

function TPM:IsEconomyBankTransferReason(reason)
    if _G.CURRENCY_CHANGE_REASON_BANK_DEPOSIT and reason == _G.CURRENCY_CHANGE_REASON_BANK_DEPOSIT then return true end
    if _G.CURRENCY_CHANGE_REASON_BANK_WITHDRAWAL and reason == _G.CURRENCY_CHANGE_REASON_BANK_WITHDRAWAL then return true end
    if _G.CURRENCY_CHANGE_REASON_GUILD_BANK_DEPOSIT and reason == _G.CURRENCY_CHANGE_REASON_GUILD_BANK_DEPOSIT then return true end
    if _G.CURRENCY_CHANGE_REASON_GUILD_BANK_WITHDRAWAL and reason == _G.CURRENCY_CHANGE_REASON_GUILD_BANK_WITHDRAWAL then return true end
    return false
end

function TPM:RecordEconomyPersonalBankTransfer(definition, currencyLocation, newAmount, oldAmount, reason)
    if not definition or not self:IsEconomyCurrencyBankable(definition) then return false end
    if type(_G.CURRENCY_LOCATION_CHARACTER) ~= "number" or currencyLocation ~= _G.CURRENCY_LOCATION_CHARACTER then
        return false
    end

    local delta = (tonumber(newAmount) or 0) - (tonumber(oldAmount) or 0)
    local isDeposit = _G.CURRENCY_CHANGE_REASON_BANK_DEPOSIT and reason == _G.CURRENCY_CHANGE_REASON_BANK_DEPOSIT
    local isWithdrawal = _G.CURRENCY_CHANGE_REASON_BANK_WITHDRAWAL and reason == _G.CURRENCY_CHANGE_REASON_BANK_WITHDRAWAL
    if not isDeposit and not isWithdrawal then return false end

    local stats = self:GetEconomyStats()
    local entry = stats.currencies and stats.currencies[definition.key]
    if not entry then return true end
    if isDeposit and delta < 0 then
        entry.bankDeposited = math.max(0, Round((tonumber(entry.bankDeposited) or 0) + math.abs(delta)))
        if definition.key == "gold" then self:RecordEconomyZoneBankTransfer(math.abs(delta), true) end
    elseif isWithdrawal and delta > 0 then
        entry.bankWithdrawn = math.max(0, Round((tonumber(entry.bankWithdrawn) or 0) + delta))
        if definition.key == "gold" then self:RecordEconomyZoneBankTransfer(delta, false) end
    end
    return true
end

function TPM:IsEconomyNonTransactionReason(reason, delta)
    -- PLAYER_INIT can report the player's existing balance as an update when
    -- entering the world. Counting that would add the whole wallet to
    -- "Received" on login/reload. ESO's own inventory code ignores it too.
    if _G.CURRENCY_CHANGE_REASON_PLAYER_INIT and reason == _G.CURRENCY_CHANGE_REASON_PLAYER_INIT then return true end
    if self:IsEconomyBankTransferReason(reason) then return true end

    -- These are losses/rollovers rather than deliberate spending. Positive PvP
    -- transfers remain valid income, but a negative transfer is not a purchase.
    if (tonumber(delta) or 0) < 0 then
        if _G.CURRENCY_CHANGE_REASON_DEATH and reason == _G.CURRENCY_CHANGE_REASON_DEATH then return true end
        if _G.CURRENCY_CHANGE_REASON_PVP_KILL_TRANSFER and reason == _G.CURRENCY_CHANGE_REASON_PVP_KILL_TRANSFER then return true end
        if _G.CURRENCY_CHANGE_REASON_TAMRIEL_TOMES_END_OF_SEASON_ROLLOVER_CAP
            and reason == _G.CURRENCY_CHANGE_REASON_TAMRIEL_TOMES_END_OF_SEASON_ROLLOVER_CAP then return true end
    end
    return false
end

function TPM:RecordEconomyCurrencyChange(currencyType, currencyLocation, newAmount, oldAmount, reason)
    self:GetEconomyCurrencyDefinitions()
    local definition = self.economyCurrencyByType and self.economyCurrencyByType[currencyType]
    if not definition then return end

    -- Personal bank transfers are not income/spending, but 3.0.6 records them
    -- separately so the Bank Gold development view can show Deposits and
    -- Withdrawals. Count the character-side event only to avoid double counts.
    if self:RecordEconomyPersonalBankTransfer(definition, currencyLocation, newAmount, oldAmount, reason) then
        self:QueueStatisticsLiveRefresh()
        return
    end

    if self:IsEconomyCurrencyBankable(definition) then
        -- Track only the carried-wallet side. The matching bank event is a
        -- transfer and is deliberately ignored above, so deposits/withdrawals
        -- cannot inflate Received/Spent.
        if type(_G.CURRENCY_LOCATION_CHARACTER) == "number" and currencyLocation ~= _G.CURRENCY_LOCATION_CHARACTER then return end
    else
        local primaryLocation = self:GetEconomyPrimaryLocation(definition)
        if type(primaryLocation) == "number" and currencyLocation ~= primaryLocation then return end
    end

    local delta = (tonumber(newAmount) or 0) - (tonumber(oldAmount) or 0)
    if delta == 0 then return end
    if self:IsEconomyNonTransactionReason(reason, delta) then return end

    local stats = self:GetEconomyStats()
    local entry = stats.currencies[definition.key]
    if not entry then return end

    -- Gold crime subtotals. ESO exposes separate change reasons for selling
    -- stolen goods at a fence and for stealing/pickpocketing gold directly.
    -- These are subcategories of Received, not additional income on top of it.
    if definition.key == "gold" and delta > 0 then
        if _G.CURRENCY_CHANGE_REASON_SELL_STOLEN and reason == _G.CURRENCY_CHANGE_REASON_SELL_STOLEN then
            entry.fenceSales = math.max(0, Round((tonumber(entry.fenceSales) or 0) + delta))
        elseif (_G.CURRENCY_CHANGE_REASON_LOOT_STOLEN and reason == _G.CURRENCY_CHANGE_REASON_LOOT_STOLEN)
            or (_G.CURRENCY_CHANGE_REASON_PICKPOCKET and reason == _G.CURRENCY_CHANGE_REASON_PICKPOCKET) then
            entry.stolenGold = math.max(0, Round((tonumber(entry.stolenGold) or 0) + delta))
        end
    end

    if delta > 0 then
        entry.received = math.max(0, Round((tonumber(entry.received) or 0) + delta))
    else
        entry.spent = math.max(0, Round((tonumber(entry.spent) or 0) + math.abs(delta)))
    end
    -- 2.6.32: only Gold gets the detailed zone ledger. Other currencies keep
    -- their established global/character tracking to avoid implying a location
    -- ESO does not reliably provide for every currency source.
    if definition.key == "gold" then
        self:RecordEconomyZoneDelta(delta, reason)
    end

    self:QueueStatisticsLiveRefresh()
end


-- v2.6.22 Justice / bounty payments -------------------------------------------
-- EVENT_JUSTICE_GOLD_REMOVED is ESO's dedicated notification for gold removed
-- by the Justice system. Keep it as a subcategory of normal Gold "Spent"; the
-- regular currency event already accounts for the wallet loss, so this function
-- must never add the amount to entry.spent a second time.
function TPM:RecordEconomyBountyPayment(goldAmount)
    goldAmount = math.max(0, Round(tonumber(goldAmount) or 0))
    if goldAmount <= 0 then return end

    local stats = self:GetEconomyStats()
    local entry = stats and stats.currencies and stats.currencies.gold
    if not entry then return end

    entry.bountyPaid = math.max(0, Round((tonumber(entry.bountyPaid) or 0) + goldAmount))
    local zoneEntry = self:GetEconomyZoneEntry(self:GetEconomyTrackingZoneId(), true)
    if zoneEntry then zoneEntry.bountyPaid = math.max(0, Round((tonumber(zoneEntry.bountyPaid) or 0) + goldAmount)) end
    entry.bountyTrackingVersion = entry.bountyTrackingVersion or "2.6.22"

    self:QueueStatisticsLiveRefresh()
    self:QueueEconomyHistoryCheckpoint()
end


-- v3.0 History / development journal ------------------------------------------
-- ESO owns the actual SavedVariables disk write. TPM keeps its data current in
-- memory and creates explicit checkpoints on player deactivation, activation
-- transitions and periodically while playing so a normal logout/quit/reload has
-- a complete final state ready for ESO to persist.
local function TPM_GetLocalUtcOffsetSeconds()
    -- ESO exposes the local clock separately from the Unix timestamp. Derive
    -- the current local offset without relying on Lua's host timezone.
    local nowStamp = tonumber(GetTimeStamp())
    local localSeconds = tonumber(GetSecondsSinceMidnight())
    if nowStamp and localSeconds then
        local utcSeconds = nowStamp % 86400
        local offset = localSeconds - utcSeconds
        if offset > 43200 then offset = offset - 86400 end
        if offset < -43200 then offset = offset + 86400 end
        return offset
    end
    return 0
end

local function TPM_DayKey(timestamp)
    -- Generic history keeps its established UTC day-key semantics for backwards
    -- compatibility with existing snapshots and graphs.
    return math.floor(math.max(0, tonumber(timestamp) or 0) / 86400)
end

local function TPM_CharacterDayKeyWithOffset(timestamp, utcOffset)
    local adjusted = math.max(0, tonumber(timestamp) or 0) + (tonumber(utcOffset) or 0)
    return math.floor(adjusted / 86400)
end

local function TPM_CharacterDayStartTimestampWithOffset(dayKey, utcOffset)
    return (tonumber(dayKey) or 0) * 86400 - (tonumber(utcOffset) or 0)
end

local function TPM_CharacterDayKey(timestamp)
    -- Character history follows ESO's local calendar. New observations persist
    -- the UTC offset that was active at the time, so summer/winter-time history
    -- can later be rendered without reinterpreting old entries with today's offset.
    return TPM_CharacterDayKeyWithOffset(timestamp, TPM_GetLocalUtcOffsetSeconds())
end

local function TPM_CharacterDayStartTimestamp(dayKey)
    return TPM_CharacterDayStartTimestampWithOffset(dayKey, TPM_GetLocalUtcOffsetSeconds())
end

local function TPM_FormatDuration(seconds)
    seconds = math.max(0, Round(tonumber(seconds) or 0))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if hours > 0 then
        return string.format("%dh %02dm", hours, minutes)
    end
    return string.format("%dm", minutes)
end

local function TPM_SignedNumber(value)
    value = Round(tonumber(value) or 0)
    if value > 0 then return "+" .. FormatNumber(value) end
    if value < 0 then return "-" .. FormatNumber(math.abs(value)) end
    return "0"
end

local function TPM_SignedDuration(value)
    value = Round(tonumber(value) or 0)
    if value > 0 then return "+" .. TPM_FormatDuration(value) end
    if value < 0 then return "-" .. TPM_FormatDuration(math.abs(value)) end
    return TPM_FormatDuration(0)
end

-- 2.4.50: Legacy dynamicEncounter rows are no longer accepted at all.
-- World events are tracked exclusively through ESO's participation-based
-- world-event API added in 2.4.48. This prevents old zone-wide false positives
-- such as "Dynamische Begegnung: Steinfälle" from returning merely because a
-- kill or another counter changed while a world event existed in the zone.
local function TPM_IsMeaningfulDynamicEncounter(item)
    if type(item) ~= "table" then return false end
    return tostring(item.activityKind or "") ~= "dynamicEncounter"
end

function TPM:GetHistoryStore(characterKey)
    if not self.saved then return nil end
    if type(self.saved.historyByCharacter) ~= "table" then self.saved.historyByCharacter = {} end
    local key = characterKey or self:GetCurrentCharacterStatsKey()
    local store = self.saved.historyByCharacter[key]
    if type(store) ~= "table" then
        store = {
            trackingVersion = VERSION,
            daily = {},
            dailyExtrema = {},
            samples = {},
            sessions = {},
            activeSession = nil,
            characterName = "",
        }
        self.saved.historyByCharacter[key] = store
    end
    if type(store.daily) ~= "table" then store.daily = {} end
    if type(store.dailyExtrema) ~= "table" then store.dailyExtrema = {} end
    if type(store.samples) ~= "table" then store.samples = {} end
    if type(store.sessions) ~= "table" then store.sessions = {} end
    if type(store.characterPlaytime365) ~= "table" then store.characterPlaytime365 = {} end
    if type(store.activities) ~= "table" then store.activities = {} end
    if type(store.combatActivities) ~= "table" then
        store.combatActivities = {}
        -- 2.4.41 migration: previous builds mixed individual kills with quests /
        -- dungeons in one 100-row array. Move existing kill rows into their own
        -- 100-row combat log so ordinary kills can no longer push out quests.
        local keptActivities = {}
        for _, item in ipairs(store.activities) do
            if type(item) == "table" and self:IsCombatLogKind(item.activityKind) then
                store.combatActivities[#store.combatActivities + 1] = item
            else
                keptActivities[#keptActivities + 1] = item
            end
        end
        store.activities = keptActivities
    end
    -- 2.4.50: Purge all legacy dynamic encounter rows. World-event history now
    -- comes exclusively from the participation-based tracker, so the old
    -- dynamicEncounter category must never survive an update or affect counts.
    do
        local cleanedActivities = {}
        for _, item in ipairs(store.activities) do
            if TPM_IsMeaningfulDynamicEncounter(item) then
                cleanedActivities[#cleanedActivities + 1] = item
            end
        end
        store.activities = cleanedActivities
    end
    while #store.activities > 100 do table.remove(store.activities, 1) end
    while #store.combatActivities > 100 do table.remove(store.combatActivities, 1) end
    store.trackingVersion = store.trackingVersion or VERSION

    -- 3.0.0 stored only startedAt/lastSeenAt. Convert that shape to a paused
    -- segment so updating to 3.0.1 can never count offline/other-character time.
    if type(store.activeSession) == "table" then
        local active = store.activeSession
        if active.accumulatedSeconds == nil and active.segmentStartedAt == nil then
            local startedAt = tonumber(active.startedAt) or 0
            local lastSeenAt = tonumber(active.lastSeenAt) or startedAt
            active.accumulatedSeconds = math.max(0, lastSeenAt - startedAt)
            active.segmentStartedAt = nil
            active.deactivatedAt = lastSeenAt
        end
    end

    local currentKey = self:GetCurrentCharacterStatsKey()
    if key == currentKey then
        local characterName = type(GetUnitName) == "function" and (GetUnitName("player") or "") or ""
        if type(zo_strformat) == "function" and characterName ~= "" then
            characterName = zo_strformat("<<C:1>>", characterName)
        end
        if characterName ~= "" then store.characterName = characterName end
    end
    return store
end

function TPM:GetMilestoneState()
    if not self.saved then return nil end
    if type(self.saved.milestoneStateByCharacter) ~= "table" then self.saved.milestoneStateByCharacter = {} end
    local key = self:GetCurrentCharacterStatsKey()
    local state = self.saved.milestoneStateByCharacter[key]
    if type(state) ~= "table" then
        state = { initialized = false, tamriel = {}, zones = {}, records = {} }
        self.saved.milestoneStateByCharacter[key] = state
    end
    if type(state.tamriel) ~= "table" then state.tamriel = {} end
    if type(state.zones) ~= "table" then state.zones = {} end
    if type(state.records) ~= "table" then state.records = {} end
    return state
end

function TPM:GetSnapshotCategory(stats, completionType)
    for _, row in ipairs((stats and stats.categories) or {}) do
        if row.completionType == completionType then return row end
    end
    return nil
end


function TPM:GetCurrentPlayerZoneIdentity()
    local zoneIndex = tonumber(GetUnitZoneIndex("player"))
    if not zoneIndex or zoneIndex <= 0 then return 0, nil, tostring(GetUnitZone("player") or "") end

    local zoneId = tonumber(GetZoneId(zoneIndex)) or 0
    local zoneName = tostring(GetZoneNameByIndex(zoneIndex) or GetUnitZone("player") or "")
    if zoneName ~= "" then zoneName = ZO_CachedStrFormat(SI_ZONE_NAME, zoneName) end
    return zoneId, zoneIndex, zoneName
end

function TPM:GetJumpActivityKind(zoneDisplayType)
    if type(zoneDisplayType) ~= "number" then return "adventure" end
    if _G.ZONE_DISPLAY_TYPE_BATTLEGROUND and zoneDisplayType == _G.ZONE_DISPLAY_TYPE_BATTLEGROUND then return "battleground" end
    if _G.ZONE_DISPLAY_TYPE_RAID and zoneDisplayType == _G.ZONE_DISPLAY_TYPE_RAID then return "trial" end
    if _G.ZONE_DISPLAY_TYPE_DUNGEON and zoneDisplayType == _G.ZONE_DISPLAY_TYPE_DUNGEON then return "dungeon" end
    if _G.ZONE_DISPLAY_TYPE_ENDLESS_DUNGEON and zoneDisplayType == _G.ZONE_DISPLAY_TYPE_ENDLESS_DUNGEON then return "dungeon" end
    return "adventure"
end

function TPM:IsWorldEventActivityKind(kind)
    return kind == "worldEvent" or kind == "dolmen" or kind == "geyser"
        or kind == "harrowstorm" or kind == "volcanicVent" or kind == "dragonHunt"
        or kind == "monsterHunt" or kind == "mirrormoor" or kind == "oblivionPortal"
end

function TPM:IsPersistentTrackedActivityKind(kind)
    return kind == "quest" or kind == "dungeon" or kind == "trial" or kind == "arena"
        or kind == "battleground" or kind == "pvp" or kind == "event"
        or self:IsWorldEventActivityKind(kind)
        or kind == "killAnimal" or kind == "killNpc" or kind == "killBoss" or kind == "killPlayer"
end

function TPM:IsCombatLogKind(kind)
    return kind == "killAnimal" or kind == "killNpc" or kind == "killBoss" or kind == "killPlayer"
end

function TPM:RememberJumpDestination(zoneName, zoneDisplayType, loadingTexture)
    local kind = self:GetJumpActivityKind(zoneDisplayType)
    local formattedName = tostring(zoneName or "")
    if formattedName ~= "" then formattedName = ZO_CachedStrFormat(SI_ZONE_NAME, formattedName) end

    local now = TPM_Now()
    local active = self.activeTrackedActivity

    -- Finalize a dungeon/trial/BG BEFORE the loading screen starts. At this
    -- point ESO still exposes the old instance and all current combat totals,
    -- so the activity cannot get lost or be replaced by the destination zone.
    if type(active) == "table" and self:IsPersistentTrackedActivityKind(active.kind) then
        local activeName = tostring(active.name or "")
        local sameKind = active.kind == kind
        local sameName = formattedName ~= "" and activeName ~= "" and formattedName == activeName
        local stayingInSameActivity = sameKind and (sameName or formattedName == "")
        if not stayingInSameActivity then
            local endSnapshot = self:CaptureHistorySnapshot(false)
            if endSnapshot then
                active.lastSnapshot = endSnapshot
                active.lastSeenAt = endSnapshot.timestamp or now
            end
            self:FinalizeTrackedActivity(endSnapshot or active.lastSnapshot, now)
        end
    end

    self.pendingJumpActivity = {
        kind = kind,
        name = formattedName,
        at = now,
        displayType = zoneDisplayType,
        loadingTexture = tostring(loadingTexture or ""),
    }
end

function TPM:GetCurrentTrackedActivityKind()
    if self:IsCurrentBattlegroundActive() then return "battleground" end

    if IsPlayerInRaid() then return "trial" end

    -- Group dungeons are best identified by the current dungeon difficulty.
    -- IsUnitInDungeon() also returns true in delves/public dungeons, while
    -- NORMAL/VETERAN difficulty identifies a real group dungeon.
    local difficulty = GetCurrentZoneDungeonDifficulty()
    if type(difficulty) == "number" then
        local none = tonumber(_G.DUNGEON_DIFFICULTY_NONE) or 0
        if difficulty > none then return "dungeon" end
    end

    if self:IsInPvPEnvironment() then return "pvp" end

    -- Dynamic/world events are intentionally not inferred from the zone-wide
    -- active-event flag. ESO can report an active event anywhere in the zone,
    -- which caused ordinary play and dungeons to be stored as a dynamic
    -- encounter. Dedicated instance activities are tracked reliably below.
    return "adventure"
end

function TPM:MarkDynamicEncounterActivity(worldEventInstanceId)
    self.activeDynamicEncounterId = worldEventInstanceId or self.activeDynamicEncounterId
    self.lastDynamicEncounterAt = TPM_Now()
end

function TPM:ClearDynamicEncounterActivity(worldEventInstanceId)
    if worldEventInstanceId == nil or self.activeDynamicEncounterId == worldEventInstanceId then
        self.activeDynamicEncounterId = nil
    end
end

-- 2.4.48: World-event logging is participation based. EVENT_WORLD_EVENT_ACTIVATED
-- is zone-wide and therefore not proof the player joined an event. Only the
-- PARTICIPATION_BEGIN/END stream creates a tracker; DEACTIVATED finalizes it.
-- This prevents false rows such as repeated zero-value "Dynamic Encounter"
-- entries while still recording Dolmens, Geysers, Harrowstorms, Volcanic Vents
-- and other current/future ESO world events.
local function TPM_WorldEventNormalizeText(value)
    local text = tostring(value or ""):gsub("%^%a+", "")
    return zo_strlower(text)
end

local function TPM_WorldEventContains(text, ...)
    for i = 1, select("#", ...) do
        local needle = tostring(select(i, ...) or "")
        if needle ~= "" and string.find(text, needle, 1, true) then return true end
    end
    return false
end

function TPM:GetWorldEventMetadata(worldEventInstanceId, stepDefId)
    local metadata = {
        instanceId = tonumber(worldEventInstanceId) or 0,
        stepDefId = tonumber(stepDefId) or 0,
        worldEventId = 0,
        worldEventType = nil,
        locationContext = nil,
        zoneIndex = 0,
        poiIndex = 0,
        poiName = "",
        stepName = "",
        startDescription = "",
        finishedDescription = "",
        playerLocation = "",
        zoneName = "",
        icon = "",
    }

    if metadata.instanceId <= 0 then return metadata end

    metadata.worldEventId = tonumber(GetWorldEventId(metadata.instanceId)) or 0
    if metadata.worldEventId > 0 then
        metadata.worldEventType = GetWorldEventType(metadata.worldEventId)
    end
    metadata.locationContext = GetWorldEventLocationContext(metadata.instanceId)

    local canUsePoi = metadata.locationContext == nil
        or WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST == nil
        or metadata.locationContext == WORLD_EVENT_LOCATION_CONTEXT_POINT_OF_INTEREST
    if canUsePoi then
        local zoneIndex, poiIndex = GetWorldEventPOIInfo(metadata.instanceId)
        metadata.zoneIndex = tonumber(zoneIndex) or 0
        metadata.poiIndex = tonumber(poiIndex) or 0
        -- Update 50 dynamic world-event locations can report 1/1 when the
        -- event is a location rather than a real POI. Treat that sentinel
        -- as invalid instead of accidentally reading Stonefalls as a name.
        if metadata.zoneIndex == 1 and metadata.poiIndex == 1 then
            metadata.zoneIndex, metadata.poiIndex = 0, 0
        end
    end

    if metadata.zoneIndex > 0 and metadata.poiIndex > 0 then
        local poiName, _, startDescription, finishedDescription = GetPOIInfo(metadata.zoneIndex, metadata.poiIndex)
        metadata.poiName = tostring(poiName or "")
        metadata.startDescription = tostring(startDescription or "")
        metadata.finishedDescription = tostring(finishedDescription or "")
        local _, _, _, icon = GetPOIMapInfo(metadata.zoneIndex, metadata.poiIndex)
        metadata.icon = tostring(icon or "")
    end

    if metadata.stepDefId > 0 then
        metadata.stepName = tostring(GetWorldEventStepName(metadata.instanceId, metadata.stepDefId) or "")
    end
    metadata.playerLocation = tostring(GetPlayerLocationName() or "")
    metadata.zoneName = tostring(GetUnitZone("player") or "")

    local function FormatName(value)
        value = tostring(value or "")
        if value == "" then return "" end
        local formatted = ZO_CachedStrFormat("<<C:1>>", value)
        return (formatted and formatted ~= "") and formatted or value:gsub("%^%a+", "")
    end
    metadata.poiName = FormatName(metadata.poiName)
    metadata.stepName = FormatName(metadata.stepName)
    metadata.playerLocation = FormatName(metadata.playerLocation)
    metadata.zoneName = FormatName(metadata.zoneName)
    return metadata
end

function TPM:ClassifyWorldEvent(metadata)
    metadata = metadata or {}
    local text = TPM_WorldEventNormalizeText(table.concat({
        metadata.poiName or "", metadata.stepName or "", metadata.startDescription or "",
        metadata.finishedDescription or "", metadata.playerLocation or "", metadata.zoneName or "",
        metadata.icon or "",
    }, " "))

    -- Dark Anchors/Dolmens have historically used the poi_portal icon. Text
    -- fallbacks cover localized names and future icon changes.
    if TPM_WorldEventContains(text, "poi_portal_", "dolmen", "dark anchor", "daedric anchor", "dunkler anker", "dunkle anker", "дольмен", "тёмный якор", "темный якор") then
        return "dolmen"
    end
    if TPM_WorldEventContains(text, "abyssal geyser", "abyssal geysers", "geyser", "geysir", "гейзер") then
        return "geyser"
    end
    if TPM_WorldEventContains(text, "harrowstorm", "harrow storm", "gramsturm", "gramstürm", "харроу") then
        return "harrowstorm"
    end
    if TPM_WorldEventContains(text, "volcanic vent", "volcanic vents", "vulkanschlot", "vulkanschlote", "вулканическ", "жерло") then
        return "volcanicVent"
    end
    if TPM_WorldEventContains(text, "mirrormoor", "spiegelmoor", "mirror moor", "зеркал") then
        return "mirrormoor"
    end
    if TPM_WorldEventContains(text, "oblivion portal", "portal to oblivion", "portal ins vergessen", "oblivion-portal", "обливион") then
        return "oblivionPortal"
    end
    if TPM_WorldEventContains(text, "dragon", "drache", "drachen", "дракон") then
        return "dragonHunt"
    end

    if _G.WORLD_EVENT_TYPE_MONSTER_HUNT and metadata.worldEventType == _G.WORLD_EVENT_TYPE_MONSTER_HUNT then
        return "monsterHunt"
    end
    return "worldEvent"
end

function TPM:GetWorldEventDisplayName(metadata, kind)
    metadata = metadata or {}
    local poiName = tostring(metadata.poiName or "")
    local location = tostring(metadata.playerLocation or "")
    local stepName = tostring(metadata.stepName or "")
    local zoneName = tostring(metadata.zoneName or "")

    if poiName ~= "" and poiName ~= zoneName then return poiName end
    if location ~= "" and location ~= zoneName then return location end
    if stepName ~= "" then return stepName end
    if zoneName ~= "" then return zoneName end
    return ""
end

function TPM:GetWorldEventCombatCounterSnapshot()
    local stats = self:GetPlayerCombatStats()
    return {
        npcKills = tonumber(stats and stats.npcKills) or 0,
        bossKills = tonumber(stats and stats.bossKills) or 0,
        pveDeaths = tonumber(stats and stats.pveDeaths) or 0,
        pvpKills = tonumber(stats and stats.pvpKills) or 0,
        pvpDeaths = tonumber(stats and stats.pvpDeaths) or 0,
    }
end

function TPM:PruneWorldEventTrackers()
    if type(self.worldEventTrackers) ~= "table" then return end
    local now = TPM_Now()
    for id, tracker in pairs(self.worldEventTrackers) do
        local lastSeen = tonumber(tracker.lastSeenAt or tracker.startedAt) or 0
        if lastSeen > 0 and now - lastSeen > 1800 then
            self.worldEventTrackers[id] = nil
        end
    end
end

-- 2.6.2: Some classic World Events (especially Dark Anchors/Dolmens) can
-- activate/deactivate without a reliable PARTICIPATION_BEGIN callback on every
-- client/event path. Keep a lightweight candidate from activation and promote it
-- only when ESO also gives evidence that the player is at that event (near/inside
-- its POI plus combat, XP or Gold). This avoids the old zone-wide false positives.
function TPM:DiscoverCurrentZoneWorldEventCandidates(force)
    if type(GetPOIWorldEventInstanceId) ~= "function" or type(GetNumPOIs) ~= "function" then return 0 end

    local nowMs = type(GetFrameTimeMilliseconds) == "function" and GetFrameTimeMilliseconds() or (TPM_Now() * 1000)
    if not force and tonumber(self.lastWorldEventPoiScanAtMs) and (nowMs - self.lastWorldEventPoiScanAtMs) < 700 then
        return tonumber(self.lastWorldEventPoiScanCount) or 0
    end
    self.lastWorldEventPoiScanAtMs = nowMs

    local _, playerZoneIndex = self:GetCurrentPlayerZoneIdentity()
    playerZoneIndex = tonumber(playerZoneIndex) or 0
    if playerZoneIndex <= 0 then
        self.lastWorldEventPoiScanCount = 0
        return 0
    end

    local poiCount = GetNumPOIs(playerZoneIndex)
    if type(poiCount) ~= "number" or poiCount <= 0 then
        self.lastWorldEventPoiScanCount = 0
        return 0
    end

    local found = 0
    for poiIndex = 1, poiCount do
        local instanceId = tonumber(GetPOIWorldEventInstanceId(playerZoneIndex, poiIndex)) or 0
        if instanceId > 0 then
            found = found + 1
            self:ObserveWorldEventActivation(instanceId)
        end
    end
    self.lastWorldEventPoiScanCount = found
    return found
end

function TPM:IsWorldEventInPlayerZone(metadata)
    if type(metadata) ~= "table" then return false end
    local _, playerZoneIndex = self:GetCurrentPlayerZoneIdentity()
    playerZoneIndex = tonumber(playerZoneIndex) or 0
    local eventZoneIndex = tonumber(metadata.zoneIndex) or 0
    return playerZoneIndex > 0 and eventZoneIndex > 0 and playerZoneIndex == eventZoneIndex
end

function TPM:IsPlayerNearWorldEvent(metadata)
    if type(metadata) ~= "table" then return false end
    local zoneIndex = tonumber(metadata.zoneIndex) or 0
    local poiIndex = tonumber(metadata.poiIndex) or 0
    if zoneIndex <= 0 or poiIndex <= 0 then return false end

    local currentZoneIndex, currentPoiIndex = GetCurrentSubZonePOIIndices()
    if tonumber(currentZoneIndex) == zoneIndex and tonumber(currentPoiIndex) == poiIndex then
        return true
    end

    -- isNearby is independent of the player's discovery state and is a useful
    -- fallback when ESO does not expose the current sub-zone POI directly.
    local _, _, _, _, _, _, _, isNearby = GetPOIMapInfo(zoneIndex, poiIndex)
    if isNearby == true then return true end

    -- Some POIs (notably active Dark Anchors) do not always report isNearby at
    -- the exact moment combat/XP arrives. Matching ESO's current location name
    -- to the event POI is a safe additional local signal.
    local poiName = TPM_WorldEventNormalizeText(metadata.poiName)
    local playerLocation = TPM_WorldEventNormalizeText(metadata.playerLocation)
    if poiName ~= "" and playerLocation ~= "" and poiName == playerLocation then return true end
    return false
end

function TPM:ObserveWorldEventActivation(worldEventInstanceId, stepDefId)
    local id = tonumber(worldEventInstanceId) or 0
    if id <= 0 then return end
    self.worldEventTrackers = self.worldEventTrackers or {}
    self:PruneWorldEventTrackers()

    local tracker = self.worldEventTrackers[id]
    local metadata = self:GetWorldEventMetadata(id, stepDefId)
    if type(tracker) ~= "table" then
        local now = TPM_Now()
        tracker = {
            instanceId = id,
            startedAt = now,
            startCounters = self:GetWorldEventCombatCounterSnapshot(),
            goldEarned = 0,
            xpEarned = 0,
            observedNpcKills = 0,
            observedBossKills = 0,
            observedPveDeaths = 0,
            everParticipated = false,
            participating = false,
            activationCandidate = true,
            evidenceCount = 0,
            explicitParticipation = false,
        }
        self.worldEventTrackers[id] = tracker
    end
    tracker.metadata = metadata
    tracker.kind = self:ClassifyWorldEvent(metadata)
    tracker.name = self:GetWorldEventDisplayName(metadata, tracker.kind)
    tracker.stepDefId = tonumber(stepDefId) or tracker.stepDefId or 0
    tracker.lastSeenAt = TPM_Now()
end

function TPM:MarkNearbyWorldEventParticipationEvidence(evidenceKind)
    -- If the event was already active when the player entered the area, the
    -- activation callback may have happened before TPM could see it. Ask the
    -- current zone POIs for their live World Event instance ids as a fallback.
    self:DiscoverCurrentZoneWorldEventCandidates(false)
    if type(self.worldEventTrackers) ~= "table" then return false end

    local now = TPM_Now()
    local marked = false
    local sameZoneCandidates = {}

    local function MarkTracker(id, tracker)
        if type(tracker) ~= "table" or tracker.deactivatedAt then return false end
        tracker.everParticipated = true
        tracker.participating = true
        tracker.evidenceCount = (tonumber(tracker.evidenceCount) or 0) + 1
        tracker.lastEvidenceKind = tostring(evidenceKind or "unknown")
        tracker.lastEvidenceAt = now
        tracker.lastSeenAt = now
        self:MarkDynamicEncounterActivity(id)
        return true
    end

    for id, tracker in pairs(self.worldEventTrackers) do
        if type(tracker) == "table" and not tracker.deactivatedAt then
            self:UpdateWorldEventTrackerMetadata(id, tracker.stepDefId)
            if self:IsWorldEventInPlayerZone(tracker.metadata) then
                sameZoneCandidates[#sameZoneCandidates + 1] = { id = id, tracker = tracker }
                if self:IsPlayerNearWorldEvent(tracker.metadata) then
                    if MarkTracker(id, tracker) then marked = true end
                end
            end
        end
    end

    if marked then return true end

    -- Never infer participation merely because this is the only active World
    -- Event in the zone. Generic quest reward XP can otherwise create a false
    -- Dolmen entry while the player is doing an unrelated quest nearby.
    return false
end

function TPM:BeginWorldEventParticipation(worldEventInstanceId, stepDefId)
    local id = tonumber(worldEventInstanceId) or 0
    if id <= 0 then return end
    self.worldEventTrackers = self.worldEventTrackers or {}
    self:PruneWorldEventTrackers()

    local now = TPM_Now()
    local tracker = self.worldEventTrackers[id]
    local metadata = self:GetWorldEventMetadata(id, stepDefId)
    if type(tracker) ~= "table" then
        tracker = {
            instanceId = id,
            startedAt = now,
            startCounters = self:GetWorldEventCombatCounterSnapshot(),
            goldEarned = 0,
            xpEarned = 0,
            observedNpcKills = 0,
            observedBossKills = 0,
            observedPveDeaths = 0,
            everParticipated = true,
        }
        self.worldEventTrackers[id] = tracker
    end
    tracker.metadata = metadata
    tracker.kind = self:ClassifyWorldEvent(metadata)
    tracker.name = self:GetWorldEventDisplayName(metadata, tracker.kind)
    tracker.stepDefId = tonumber(stepDefId) or tracker.stepDefId or 0
    tracker.participating = true
    tracker.everParticipated = true
    tracker.explicitParticipation = true
    tracker.activationCandidate = tracker.activationCandidate == true
    tracker.evidenceCount = math.max(1, tonumber(tracker.evidenceCount) or 0)
    tracker.lastSeenAt = now
    tracker.participationEndedAt = nil
    tracker.endCounters = nil
    self:MarkDynamicEncounterActivity(id)
end

function TPM:UpdateWorldEventTrackerMetadata(worldEventInstanceId, stepDefId)
    local id = tonumber(worldEventInstanceId) or 0
    if id <= 0 then return end
    if type(self.worldEventTrackers) ~= "table" or type(self.worldEventTrackers[id]) ~= "table" then
        self:ObserveWorldEventActivation(id, stepDefId)
    end
    local tracker = type(self.worldEventTrackers) == "table" and self.worldEventTrackers[id] or nil
    if type(tracker) ~= "table" then return end

    local fresh = self:GetWorldEventMetadata(id, stepDefId or tracker.stepDefId)
    local metadata = tracker.metadata or {}
    -- Some values disappear immediately as DEACTIVATED fires. Merge only useful
    -- fresh fields so the POI name/type captured during participation is never
    -- replaced with an empty post-completion snapshot.
    for key, value in pairs(fresh) do
        if type(value) == "string" then
            if value ~= "" then metadata[key] = value end
        elseif value ~= nil and value ~= 0 then
            metadata[key] = value
        elseif metadata[key] == nil then
            metadata[key] = value
        end
    end
    tracker.metadata = metadata

    local classified = self:ClassifyWorldEvent(metadata)
    if tracker.kind == nil or tracker.kind == "worldEvent" or classified ~= "worldEvent" then
        tracker.kind = classified
    end
    local displayName = self:GetWorldEventDisplayName(metadata, tracker.kind)
    if displayName ~= "" then tracker.name = displayName end
    if stepDefId then tracker.stepDefId = stepDefId end
    tracker.lastSeenAt = TPM_Now()
end

function TPM:EndWorldEventParticipation(worldEventInstanceId)
    local id = tonumber(worldEventInstanceId) or 0
    if id <= 0 or type(self.worldEventTrackers) ~= "table" then return end
    local tracker = self.worldEventTrackers[id]
    if type(tracker) ~= "table" then return end
    tracker.participating = false
    tracker.participationEndedAt = TPM_Now()
    tracker.lastSeenAt = tracker.participationEndedAt
    tracker.endCounters = self:GetWorldEventCombatCounterSnapshot()
    self:ClearDynamicEncounterActivity(id)
end

function TPM:RecordWorldEventGoldGain(delta)
    delta = tonumber(delta) or 0
    if delta <= 0 or type(self.worldEventTrackers) ~= "table" then return end
    self:MarkNearbyWorldEventParticipationEvidence("gold")
    local now = TPM_Now()
    for _, tracker in pairs(self.worldEventTrackers) do
        local endedAt = tonumber(tracker.participationEndedAt or tracker.deactivatedAt) or 0
        if tracker.participating or (tracker.everParticipated and endedAt > 0 and now - endedAt <= 10) then
            tracker.goldEarned = math.max(0, (tonumber(tracker.goldEarned) or 0) + delta)
            tracker.lastSeenAt = now
        end
    end
end

function TPM:RecordWorldEventExperienceGain(gained, source)
    gained = tonumber(gained) or 0
    if gained <= 0 or type(self.worldEventTrackers) ~= "table" then return end
    source = tostring(source or "unknown")
    self:MarkNearbyWorldEventParticipationEvidence("xp")

    -- EVENT_EXPERIENCE_GAIN and EVENT_EXPERIENCE_UPDATE can describe the same
    -- XP change. Use both for reliability, but suppress only a matching value
    -- reported by the other source within a few frames. Repeated kills from the
    -- same source are never collapsed.
    local nowMs
    if type(GetFrameTimeMilliseconds) == "function" then
        nowMs = GetFrameTimeMilliseconds()
    else
        nowMs = TPM_Now() * 1000
    end
    local last = self.lastWorldEventExperienceSignal
    if type(last) == "table" and last.source ~= source and tonumber(last.value) == gained
        and math.abs(nowMs - (tonumber(last.atMs) or 0)) <= 450 then
        return
    end
    self.lastWorldEventExperienceSignal = { value = gained, source = source, atMs = nowMs }

    local now = TPM_Now()
    for _, tracker in pairs(self.worldEventTrackers) do
        local endedAt = tonumber(tracker.participationEndedAt or tracker.deactivatedAt) or 0
        if tracker.participating or (tracker.everParticipated and endedAt > 0 and now - endedAt <= 10) then
            tracker.xpEarned = math.max(0, (tonumber(tracker.xpEarned) or 0) + gained)
            tracker.lastSeenAt = now
        end
    end
end

-- 2.6.6: attribute combat events directly to a confirmed active World Event.
-- Counter snapshots remain as a fallback, but explicit event-local counters avoid
-- losing kills when ESO reports PARTICIPATION_BEGIN late during a Dolmen.
function TPM:RecordWorldEventPveKill(kind)
    if type(self.worldEventTrackers) ~= "table" then return end
    local now = TPM_Now()
    for _, tracker in pairs(self.worldEventTrackers) do
        if type(tracker) == "table" and tracker.everParticipated then
            local endedAt = tonumber(tracker.participationEndedAt or tracker.deactivatedAt) or 0
            if tracker.participating or (endedAt > 0 and now - endedAt <= 10) then
                tracker.observedNpcKills = math.max(0, (tonumber(tracker.observedNpcKills) or 0) + 1)
                if kind == "killBoss" then
                    tracker.observedBossKills = math.max(0, (tonumber(tracker.observedBossKills) or 0) + 1)
                end
                tracker.lastSeenAt = now
            end
        end
    end
end

function TPM:RecordWorldEventPveDeath()
    if type(self.worldEventTrackers) ~= "table" then return end
    local now = TPM_Now()
    for _, tracker in pairs(self.worldEventTrackers) do
        if type(tracker) == "table" and tracker.everParticipated then
            local endedAt = tonumber(tracker.participationEndedAt or tracker.deactivatedAt) or 0
            if tracker.participating or (endedAt > 0 and now - endedAt <= 10) then
                tracker.observedPveDeaths = math.max(0, (tonumber(tracker.observedPveDeaths) or 0) + 1)
                tracker.lastSeenAt = now
            end
        end
    end
end

function TPM:FinalizeWorldEventActivity(worldEventInstanceId)
    local id = tonumber(worldEventInstanceId) or 0
    if id <= 0 or type(self.worldEventTrackers) ~= "table" then return end
    local tracker = self.worldEventTrackers[id]
    if type(tracker) ~= "table" then return end
    self.worldEventTrackers[id] = nil
    if not tracker.everParticipated then return end

    local now = tonumber(tracker.deactivatedAt) or TPM_Now()
    local participationEnd = tonumber(tracker.participationEndedAt) or now
    local endCounters = tracker.endCounters or self:GetWorldEventCombatCounterSnapshot()
    local startCounters = tracker.startCounters or {}
    local duration = math.max(0, participationEnd - (tonumber(tracker.startedAt) or participationEnd))
    local metadata = tracker.metadata or self:GetWorldEventMetadata(id, tracker.stepDefId)
    local kind = tracker.kind or self:ClassifyWorldEvent(metadata)
    local name = tracker.name or self:GetWorldEventDisplayName(metadata, kind)

    -- Evidence-only trackers must show actual encounter involvement. This
    -- prevents ordinary quest XP (for example Bilsas Lieferung) from creating
    -- a nearby Dolmen/World Event completion in Quests & Activities.
    if tracker.explicitParticipation ~= true then
        local encounterEvidence =
            math.max(0, tonumber(tracker.observedNpcKills) or 0) +
            math.max(0, tonumber(tracker.observedBossKills) or 0) +
            math.max(0, tonumber(tracker.observedPveDeaths) or 0)
        if encounterEvidence <= 0 and math.max(0, tonumber(tracker.goldEarned) or 0) <= 0 then
            return
        end
    end

    self:AddActivityLogEntry({
        activityKind = kind,
        activityName = name,
        worldEventInstanceId = id,
        worldEventId = metadata and metadata.worldEventId or 0,
        goldEarned = math.max(0, tonumber(tracker.goldEarned) or 0),
        xpEarned = math.max(0, tonumber(tracker.xpEarned) or 0),
        rewardName = "",
        duration = duration,
        startedAt = tonumber(tracker.startedAt) or now,
        endedAt = now,
        timestamp = now,
        npcKillsDelta = (tonumber(tracker.observedNpcKills) or 0) > 0
            and math.max(0, tonumber(tracker.observedNpcKills) or 0)
            or math.max(0, (tonumber(endCounters.npcKills) or 0) - (tonumber(startCounters.npcKills) or 0)),
        bossKillsDelta = (tonumber(tracker.observedBossKills) or 0) > 0
            and math.max(0, tonumber(tracker.observedBossKills) or 0)
            or math.max(0, (tonumber(endCounters.bossKills) or 0) - (tonumber(startCounters.bossKills) or 0)),
        pveDeathsDelta = (tonumber(tracker.observedPveDeaths) or 0) > 0
            and math.max(0, tonumber(tracker.observedPveDeaths) or 0)
            or math.max(0, (tonumber(endCounters.pveDeaths) or 0) - (tonumber(startCounters.pveDeaths) or 0)),
        pvpKillsDelta = math.max(0, (tonumber(endCounters.pvpKills) or 0) - (tonumber(startCounters.pvpKills) or 0)),
        pvpDeathsDelta = math.max(0, (tonumber(endCounters.pvpDeaths) or 0) - (tonumber(startCounters.pvpDeaths) or 0)),
        participatedWorldEvent = true,
    })
end

function TPM:DeactivateWorldEvent(worldEventInstanceId)
    local id = tonumber(worldEventInstanceId) or 0
    if id <= 0 then return end
    local tracker = type(self.worldEventTrackers) == "table" and self.worldEventTrackers[id] or nil
    self:ClearDynamicEncounterActivity(id)
    if type(tracker) ~= "table" then return end

    -- Last chance for classic Dolmens: the player may still be standing inside
    -- the POI when DEACTIVATED arrives even if PARTICIPATION_BEGIN was omitted.
    if not tracker.everParticipated and (tonumber(tracker.evidenceCount) or 0) > 0 and self:IsPlayerNearWorldEvent(tracker.metadata) then
        tracker.everParticipated = true
        tracker.participating = true
    end
    if not tracker.everParticipated then
        self.worldEventTrackers[id] = nil
        return
    end

    local now = TPM_Now()
    -- If participation ended long before the event deactivated, the player
    -- walked away rather than completing it. Do not log that as a completion.
    local participationEndedAt = tonumber(tracker.participationEndedAt) or 0
    if not tracker.participating and participationEndedAt > 0 then
        local lastEvidenceAt = tonumber(tracker.lastEvidenceAt) or participationEndedAt
        -- PARTICIPATION_END can arrive noticeably before the visual World Event
        -- fully deactivates. Keep a wider completion grace, but still discard a
        -- tracker if the player has clearly been away for two minutes.
        if now - participationEndedAt > 120 and now - lastEvidenceAt > 120 then
            self.worldEventTrackers[id] = nil
            return
        end
    end

    if tracker.participating then
        tracker.participating = false
        tracker.participationEndedAt = now
        tracker.endCounters = self:GetWorldEventCombatCounterSnapshot()
    end
    tracker.deactivatedAt = now
    tracker.lastSeenAt = now
    self:UpdateWorldEventTrackerMetadata(id, tracker.stepDefId)

    local finalize = function()
        TPM:FinalizeWorldEventActivity(id)
    end
    zo_callLater(finalize, 1600)
end

function TPM:ResumeParticipatingWorldEvent()
    local instanceId, stepDefId = GetParticipatingWorldEventStep()
    if tonumber(instanceId) and tonumber(instanceId) > 0 then
        self:BeginWorldEventParticipation(instanceId, stepDefId)
    end
end


-- 2.4.41: per-kill combat log. ESO may emit ACTION_RESULT_DIED first and
-- ACTION_RESULT_DIED_XP immediately afterwards for the same target. Older TPM
-- builds finalized DIED too early, so the later XP event could no longer be
-- paired and the row displayed EP +0. Keep a short unit-id based pending queue
-- and only finalize after the XP event had enough time to arrive.
local function TPM_KillLogNowMs()
    return GetFrameTimeMilliseconds()
end

function TPM:NormalizeCombatUnitName(name)
    local raw = tostring(name or "")
    if raw == "" then return "", "" end
    local clean = raw
    local value = ZO_CachedStrFormat("<<C:1>>", raw)
    if type(value) == "string" and value ~= "" then clean = value end
    -- Combat events frequently expose ESO grammar suffixes (^m/^f/^n) while
    -- reticle names may already be formatted. Strip any marker that remains so
    -- both sources can be matched and the marker never leaks into the UI.
    clean = tostring(clean or ""):gsub("%^%a+", "")
    return clean, string.lower(clean)
end

function TPM:CaptureReticlePveTarget()
    if type(GetUnitName) ~= "function" then return end
    local rawName = tostring(GetUnitName("reticleover") or "")
    if rawName == "" then
        -- Keep recent valid target snapshots for a few seconds. ESO often moves
        -- the reticle away from a dead unit before EVENT_COMBAT_EVENT arrives.
        return
    end
    local cleanName, normalizedName = self:NormalizeCombatUnitName(rawName)
    if cleanName == "" then return end
    local snapshot = {
        name = cleanName,
        rawName = rawName,
        normalizedName = normalizedName,
        atMs = TPM_KillLogNowMs(),
        livestock = false,
        critter = false,
        difficulty = nil,
        reaction = nil,
    }
    snapshot.livestock = IsUnitLivestock("reticleover") == true
    local difficulty = GetUnitDifficulty("reticleover")
    if type(difficulty) == "number" then
        snapshot.difficulty = difficulty
        snapshot.critter = difficulty == MONSTER_DIFFICULTY_NONE
    end
    local reaction = GetUnitReaction("reticleover")
    if type(reaction) == "number" then snapshot.reaction = reaction end
    self.lastReticlePveTarget = snapshot
    self.recentReticlePveTargets = self.recentReticlePveTargets or {}
    table.insert(self.recentReticlePveTargets, 1, snapshot)
    local nowMs = snapshot.atMs
    for i = #self.recentReticlePveTargets, 1, -1 do
        local entry = self.recentReticlePveTargets[i]
        if i > 16 or type(entry) ~= "table" or (nowMs - (tonumber(entry.atMs) or 0)) > 6500 then
            table.remove(self.recentReticlePveTargets, i)
        end
    end
end

function TPM:IsKnownBossName(name)
    local _, normalizedName = self:NormalizeCombatUnitName(name)
    if normalizedName == "" then return false end
    for i = 1, 6 do
        local bossName = tostring(GetUnitName("boss" .. tostring(i)) or "")
        local _, normalizedBoss = self:NormalizeCombatUnitName(bossName)
        if normalizedBoss ~= "" and normalizedBoss == normalizedName then return true end
    end
    return false
end

function TPM:RememberPlayerPveCombatTarget(targetName, targetUnitId, targetType)
    local cleanName, normalizedName = self:NormalizeCombatUnitName(targetName)
    local numericTargetId = tonumber(targetUnitId) or 0
    if cleanName == "" and numericTargetId <= 0 then return end
    if _G.COMBAT_UNIT_TYPE_NONE ~= nil and targetType ~= nil and targetType ~= _G.COMBAT_UNIT_TYPE_NONE then return end

    self.recentPlayerPveCombatTargets = self.recentPlayerPveCombatTargets or {}
    local nowMs = TPM_KillLogNowMs()
    local snapshot = cleanName ~= "" and self:GetPveKillSnapshot(cleanName) or nil
    local entry = {
        name = cleanName,
        normalizedName = normalizedName,
        targetUnitId = numericTargetId,
        atMs = nowMs,
        difficulty = snapshot and snapshot.difficulty or nil,
        livestock = snapshot and snapshot.livestock or false,
        critter = snapshot and snapshot.critter or false,
    }
    table.insert(self.recentPlayerPveCombatTargets, 1, entry)
    for i = #self.recentPlayerPveCombatTargets, 1, -1 do
        local item = self.recentPlayerPveCombatTargets[i]
        if i > 64 or type(item) ~= "table" or (nowMs - (tonumber(item.atMs) or 0)) > 15000 then
            table.remove(self.recentPlayerPveCombatTargets, i)
        end
    end
end

function TPM:GetRecentPlayerPveCombatTarget(targetUnitId, targetName)
    local numericTargetId = tonumber(targetUnitId) or 0
    local _, normalizedName = self:NormalizeCombatUnitName(targetName)
    local nowMs = TPM_KillLogNowMs()
    for _, entry in ipairs(self.recentPlayerPveCombatTargets or {}) do
        if type(entry) == "table" then
            local age = nowMs - (tonumber(entry.atMs) or 0)
            if age >= 0 and age <= 15000 then
                local sameUnit = numericTargetId > 0 and tonumber(entry.targetUnitId) == numericTargetId
                local sameName = normalizedName ~= "" and entry.normalizedName == normalizedName
                if sameUnit or sameName then return entry end
            end
        end
    end
    return nil
end

function TPM:GetPveKillSnapshot(targetName)
    local cleanName, normalizedName = self:NormalizeCombatUnitName(targetName)
    if cleanName == "" then return nil end
    local nowMs = TPM_KillLogNowMs()

    local snapshot = self.lastReticlePveTarget
    if type(snapshot) == "table" and snapshot.normalizedName == normalizedName
        and (nowMs - (tonumber(snapshot.atMs) or 0)) <= 6500 then
        return snapshot
    end

    for _, recent in ipairs(self.recentReticlePveTargets or {}) do
        if type(recent) == "table" and recent.normalizedName == normalizedName
            and (nowMs - (tonumber(recent.atMs) or 0)) <= 6500 then
            return recent
        end
    end

    if type(GetUnitName) == "function" then
        local currentName = tostring(GetUnitName("reticleover") or "")
        local _, currentNormalized = self:NormalizeCombatUnitName(currentName)
        if currentNormalized ~= "" and currentNormalized == normalizedName then
            self:CaptureReticlePveTarget()
            snapshot = self.lastReticlePveTarget
            if type(snapshot) == "table" and snapshot.normalizedName == normalizedName then return snapshot end
        end
    end
    return nil
end

function TPM:GetPveKillActivityKind(targetName)
    local cleanName = self:NormalizeCombatUnitName(targetName)
    if self:IsKnownBossName(targetName) or self:IsKnownBossName(cleanName) then return "killBoss" end
    local snapshot = self:GetPveKillSnapshot(targetName)
    if type(snapshot) == "table" then
        if snapshot.livestock or snapshot.critter then return "killAnimal" end
        if _G.MONSTER_DIFFICULTY_DEADLY ~= nil and snapshot.difficulty == _G.MONSTER_DIFFICULTY_DEADLY then
            return "killBoss"
        end
    end
    return "killNpc"
end

function TPM:GetPveKillDifficulty(targetName, kind)
    if kind == "killBoss" then return _G.MONSTER_DIFFICULTY_DEADLY end
    local snapshot = self:GetPveKillSnapshot(targetName)
    if type(snapshot) == "table" and type(snapshot.difficulty) == "number" then return snapshot.difficulty end
    if kind == "killAnimal" then return _G.MONSTER_DIFFICULTY_EASY or _G.MONSTER_DIFFICULTY_NONE end
    return _G.MONSTER_DIFFICULTY_NORMAL
end

function TPM:FinalizePendingPveKillActivity(pending, xpEarned)
    if type(pending) ~= "table" or pending.finalized then return end
    pending.finalized = true
    local now = TPM_Now()
    self:AddActivityLogEntry({
        activityKind = pending.kind or "killNpc",
        activityName = tostring(pending.name or ""),
        xpEarned = math.max(0, tonumber(xpEarned) or 0),
        goldEarned = 0,
        difficulty = pending.difficulty,
        targetUnitId = pending.targetUnitId,
        duration = 0,
        startedAt = now,
        endedAt = now,
        timestamp = now,
        npcKillsDelta = 1,
        pveDeathsDelta = 0,
        pvpKillsDelta = 0,
        pvpDeathsDelta = 0,
    })
end

function TPM:QueuePveKillActivity(targetName, kind, expectsXp, targetUnitId, difficulty, sawXpDeathResult)
    targetName = select(1, self:NormalizeCombatUnitName(targetName))
    if targetName == "" then return nil end
    self.pendingPveKillActivities = self.pendingPveKillActivities or {}
    local nowMs = TPM_KillLogNowMs()
    local numericTargetId = tonumber(targetUnitId) or 0

    -- ESO distinguishes ACTION_RESULT_DIED from ACTION_RESULT_DIED_XP. Only the
    -- latter is a reliable signal that this particular death generated player XP.
    -- Keep both results on the same pending row, but never let a plain DIED row
    -- steal the next EVENT_EXPERIENCE_GAIN from an actual XP-granting kill.
    for i = #self.pendingPveKillActivities, 1, -1 do
        local existing = self.pendingPveKillActivities[i]
        if type(existing) == "table" and not existing.finalized then
            local sameUnit = numericTargetId > 0 and tonumber(existing.targetUnitId) == numericTargetId
            local sameFallback = numericTargetId <= 0 and (tonumber(existing.targetUnitId) or 0) <= 0
                and existing.name == targetName and (nowMs - (tonumber(existing.atMs) or 0)) <= 450
            if sameUnit or sameFallback then
                if kind == "killBoss" then existing.kind = "killBoss" end
                if expectsXp == true then existing.expectsXp = true end
                if sawXpDeathResult == true then
                    existing.sawXpDeathResult = true
                    existing.expectsXp = true
                    existing.xpResultAtMs = nowMs
                end
                existing.difficulty = difficulty or existing.difficulty
                if existing.sawXpDeathResult == true then self:ConsumeRecentExperienceForPendingKill(existing) end
                return existing
            end
        end
    end

    local pending = {
        name = targetName,
        kind = kind or "killNpc",
        expectsXp = expectsXp == true,
        sawXpDeathResult = sawXpDeathResult == true,
        targetUnitId = numericTargetId,
        difficulty = difficulty,
        atMs = nowMs,
        xpResultAtMs = sawXpDeathResult == true and nowMs or nil,
        finalized = false,
    }
    self.pendingPveKillActivities[#self.pendingPveKillActivities + 1] = pending
    while #self.pendingPveKillActivities > 24 do table.remove(self.pendingPveKillActivities, 1) end
    if pending.sawXpDeathResult == true then self:ConsumeRecentExperienceForPendingKill(pending) end

    -- Give DIED_XP + EVENT_EXPERIENCE_GAIN enough time to arrive. The row is
    -- finalized immediately as soon as its XP event is matched.
    local delay = 4000
    if type(zo_callLater) == "function" then
        zo_callLater(function()
            if not pending.finalized then TPM:FinalizePendingPveKillActivity(pending, 0) end
        end, delay)
    else
        self:FinalizePendingPveKillActivity(pending, 0)
    end
    return pending
end

function TPM:MarkPendingPveKillXpResult(targetName, targetUnitId)
    if type(self.pendingPveKillActivities) ~= "table" then return nil end
    targetName = tostring(targetName or "")
    local numericTargetId = tonumber(targetUnitId) or 0
    local nowMs = TPM_KillLogNowMs()

    -- DIED_XP can arrive with an empty targetName in some combat situations.
    -- Pair it by targetUnitId first; only use a very recent name-less fallback
    -- when ESO did not expose a usable id.
    for i = #self.pendingPveKillActivities, 1, -1 do
        local pending = self.pendingPveKillActivities[i]
        if type(pending) == "table" and not pending.finalized then
            local age = nowMs - (tonumber(pending.atMs) or 0)
            local sameUnit = numericTargetId > 0 and tonumber(pending.targetUnitId) == numericTargetId
            local sameName = targetName ~= "" and pending.name == targetName and age >= 0 and age <= 1200
            if sameUnit or sameName then
                pending.sawXpDeathResult = true
                pending.expectsXp = true
                pending.xpResultAtMs = nowMs
                self:ConsumeRecentExperienceForPendingKill(pending)
                return pending
            end
        end
    end

    if numericTargetId <= 0 and targetName == "" then
        for i = #self.pendingPveKillActivities, 1, -1 do
            local pending = self.pendingPveKillActivities[i]
            local age = type(pending) == "table" and (nowMs - (tonumber(pending.atMs) or 0)) or -1
            if type(pending) == "table" and not pending.finalized and age >= 0 and age <= 350 then
                pending.sawXpDeathResult = true
                pending.expectsXp = true
                pending.xpResultAtMs = nowMs
                self:ConsumeRecentExperienceForPendingKill(pending)
                return pending
            end
        end
    end
    return nil
end

function TPM:PromoteOrQueueBossKillActivity(name)
    name = select(1, self:NormalizeCombatUnitName(name))
    if name == "" then return end

    -- EVENT_UNIT_DEATH_STATE_CHANGED has the boss unit tag but no combat-event
    -- targetUnitId. If the matching DIED/DIED_XP row is already pending, promote
    -- that same row instead of creating a second boss entry. DIED_XP can also
    -- finalize the row immediately before the boss death-state callback arrives,
    -- so a very recent finalized boss row must be treated as the same death too.
    local nowMs = TPM_KillLogNowMs()
    for i = #(self.pendingPveKillActivities or {}), 1, -1 do
        local pending = self.pendingPveKillActivities[i]
        if type(pending) == "table" and pending.name == name then
            local age = nowMs - (tonumber(pending.atMs) or 0)
            if age >= 0 and age <= 4500 then
                if pending.finalized then
                    if pending.kind == "killBoss" then
                        return pending
                    end
                else
                    pending.kind = "killBoss"
                    pending.difficulty = _G.MONSTER_DIFFICULTY_DEADLY
                    return pending
                end
            end
        end
    end

    -- Boss identity alone does not prove that ESO granted XP. DIED_XP will
    -- promote the row when XP is actually awarded.
    return self:QueuePveKillActivity(name, "killBoss", false, 0, _G.MONSTER_DIFFICULTY_DEADLY, false)
end

function TPM:PruneRecentExperienceGains(nowMs)
    if type(self.recentExperienceGains) ~= "table" then return end
    nowMs = tonumber(nowMs) or TPM_KillLogNowMs()
    for i = #self.recentExperienceGains, 1, -1 do
        local entry = self.recentExperienceGains[i]
        local age = type(entry) == "table" and (nowMs - (tonumber(entry.atMs) or 0)) or 999999
        if age > 1800 or entry.consumed then table.remove(self.recentExperienceGains, i) end
    end
end

function TPM:StoreRecentExperienceGain(reason, level, previousExperience, currentExperience)
    local gained = self:CalculateExperienceGain(level, previousExperience, currentExperience)
    if gained <= 0 then return nil end
    return self:StoreRecentExperienceValue(gained, reason, "gain")
end

function TPM:StoreRecentExperienceValue(gained, reason, source)
    gained = math.max(0, tonumber(gained) or 0)
    if gained <= 0 then return nil end
    local nowMs = TPM_KillLogNowMs()
    self.recentExperienceGains = self.recentExperienceGains or {}
    self:PruneRecentExperienceGains(nowMs)

    -- EVENT_EXPERIENCE_GAIN and EVENT_EXPERIENCE_UPDATE can describe the same
    -- XP change. Do not keep the exact same gain twice within a few frames.
    for i = #self.recentExperienceGains, 1, -1 do
        local old = self.recentExperienceGains[i]
        if type(old) == "table" and not old.consumed then
            local age = nowMs - (tonumber(old.atMs) or 0)
            if age >= 0 and age <= 160 and tonumber(old.gained) == gained then
                return old
            end
        end
    end

    local entry = { gained = gained, reason = reason, source = source, atMs = nowMs, consumed = false }
    self.recentExperienceGains[#self.recentExperienceGains + 1] = entry
    while #self.recentExperienceGains > 16 do table.remove(self.recentExperienceGains, 1) end
    return entry
end

function TPM:AssignExperienceValueToPendingPveKill(gained, reason, source)
    gained = math.max(0, tonumber(gained) or 0)
    if gained <= 0 then return false end
    local nowMs = TPM_KillLogNowMs()

    if type(self.pendingPveKillActivities) == "table" then
        local bestPending, bestDistance = nil, nil
        for i = #self.pendingPveKillActivities, 1, -1 do
            local pending = self.pendingPveKillActivities[i]
            if type(pending) == "table" and not pending.finalized and pending.sawXpDeathResult == true then
                local markerMs = tonumber(pending.xpResultAtMs) or tonumber(pending.atMs) or 0
                local distance = math.abs(nowMs - markerMs)
                if distance <= 2200 and (bestDistance == nil or distance < bestDistance) then
                    bestPending, bestDistance = pending, distance
                end
            end
        end
        if bestPending then
            self:FinalizePendingPveKillActivity(bestPending, gained)
            return true
        end
    end

    -- XP can update before DIED_XP arrives, so retain it briefly for the death
    -- row to claim. This is especially important on fast/AoE kills.
    self:StoreRecentExperienceValue(gained, reason, source or "update")
    return false
end

function TPM:HandlePlayerExperienceUpdate(currentExp, maxExp, reason)
    currentExp = tonumber(currentExp)
    maxExp = tonumber(maxExp)
    if not currentExp then return false end

    local level = tonumber(GetUnitLevel("player")) or 1
    local previousExp = tonumber(self.killLogLastPlayerExperience)
    local previousLevel = tonumber(self.killLogLastPlayerLevel) or level
    local previousMax = tonumber(self.killLogLastPlayerExperienceMax) or maxExp

    self.killLogLastPlayerExperience = currentExp
    self.killLogLastPlayerExperienceMax = maxExp
    self.killLogLastPlayerLevel = level

    if previousExp == nil then return false end

    local gained = 0
    if level == previousLevel then
        if currentExp >= previousExp then gained = currentExp - previousExp end
    elseif level > previousLevel then
        local levelMax = previousMax
        if not levelMax or levelMax <= 0 then
            levelMax = tonumber(GetNumExperiencePointsInLevel(previousLevel)) or levelMax
        end
        if levelMax and levelMax > previousExp then
            gained = (levelMax - previousExp) + currentExp
        else
            gained = currentExp
        end
    end

    if gained > 0 then
        self:RecordWorldEventExperienceGain(gained, "update")
        return self:AssignExperienceValueToPendingPveKill(gained, reason, "update")
    end
    return false
end

function TPM:ConsumeRecentExperienceForPendingKill(pending)
    if type(pending) ~= "table" or pending.finalized or pending.sawXpDeathResult ~= true then return false end
    if type(self.recentExperienceGains) ~= "table" then return false end
    local nowMs = TPM_KillLogNowMs()
    self:PruneRecentExperienceGains(nowMs)
    local referenceMs = tonumber(pending.xpResultAtMs) or tonumber(pending.atMs) or nowMs
    local bestIndex, bestDistance = nil, nil
    for i = #self.recentExperienceGains, 1, -1 do
        local entry = self.recentExperienceGains[i]
        if type(entry) == "table" and not entry.consumed and (tonumber(entry.gained) or 0) > 0 then
            local distance = math.abs((tonumber(entry.atMs) or 0) - referenceMs)
            -- XP and DIED_XP normally arrive almost together, but either may be
            -- first. 1.5s leaves enough room for UI/event scheduling without
            -- accidentally consuming old quest/discovery XP.
            if distance <= 1500 and (bestDistance == nil or distance < bestDistance) then
                bestIndex, bestDistance = i, distance
            end
        end
    end
    if bestIndex then
        local entry = self.recentExperienceGains[bestIndex]
        entry.consumed = true
        self:FinalizePendingPveKillActivity(pending, tonumber(entry.gained) or 0)
        self:PruneRecentExperienceGains(nowMs)
        return true
    end
    return false
end

function TPM:AssignExperienceToPendingPveKill(reason, level, previousExperience, currentExperience)
    local gained = self:CalculateExperienceGain(level, previousExperience, currentExperience)
    if gained <= 0 then return false end
    local nowMs = TPM_KillLogNowMs()

    -- DIED_XP already tells us that a death awarded XP. Do not reject the XP
    -- event just because ESO reports a different PROGRESS_REASON on some mobs.
    -- First try to attach the event to the oldest waiting DIED_XP kill.
    if type(self.pendingPveKillActivities) == "table" then
        for i = 1, #self.pendingPveKillActivities do
            local pending = self.pendingPveKillActivities[i]
            local markerMs = type(pending) == "table" and (tonumber(pending.xpResultAtMs) or tonumber(pending.atMs) or 0) or 0
            local age = nowMs - markerMs
            if type(pending) == "table" and not pending.finalized and pending.sawXpDeathResult == true
                and age >= -250 and age <= 1800 then
                self:FinalizePendingPveKillActivity(pending, gained)
                return true
            end
        end
    end

    -- Some client/event sequences deliver EVENT_EXPERIENCE_GAIN a few frames
    -- BEFORE ACTION_RESULT_DIED_XP. Keep it briefly so the later death event can
    -- claim the correct value instead of ending up as EP +0.
    self:StoreRecentExperienceGain(reason, level, previousExperience, currentExperience)
    return false
end

-- 3.4.7: real activity tracking. The old "sessions" list represented long
-- login sessions and therefore did not update when a dungeon was completed.
-- Activities are now tracked independently and finalized when the player leaves
-- the dungeon/BG/PvP activity.
function TPM:RecordTrackedActivityGoldGain(currencyType, currencyLocation, newAmount, oldAmount, reason)
    if type(_G.CURT_MONEY) ~= "number" or currencyType ~= _G.CURT_MONEY then return end
    if type(_G.CURRENCY_LOCATION_CHARACTER) == "number" and currencyLocation ~= _G.CURRENCY_LOCATION_CHARACTER then return end
    local delta = (tonumber(newAmount) or 0) - (tonumber(oldAmount) or 0)
    if delta <= 0 then return end
    if self:IsEconomyNonTransactionReason(reason, delta) then return end

    local active = self.activeTrackedActivity
    if type(active) == "table" and self:IsPersistentTrackedActivityKind(active.kind) then
        active.goldEarned = math.max(0, (tonumber(active.goldEarned) or 0) + delta)
    end
    self:RecordWorldEventGoldGain(delta)
end

function TPM:RecordTrackedActivityExperienceGain(reason, level, previousExperience, currentExperience)
    local gained = self:CalculateExperienceGain(level, previousExperience, currentExperience)
    if gained <= 0 then return end

    local active = self.activeTrackedActivity
    if type(active) == "table" and self:IsPersistentTrackedActivityKind(active.kind) then
        active.xpEarned = math.max(0, (tonumber(active.xpEarned) or 0) + gained)
    end
    self:RecordWorldEventExperienceGain(gained, "gain")
end

-- 3.4.32: Quest completion history. ESO removes a completed quest from the
-- journal immediately after turn-in, so cache the visible reward data while the
-- journal index is still valid. EVENT_QUEST_COMPLETE then consumes that cache.
function TPM:CalculateExperienceGain(level, previousExperience, currentExperience)
    local previous = tonumber(previousExperience)
    local current = tonumber(currentExperience)
    if not previous or not current then return 0 end
    if current >= previous then return math.max(0, current - previous) end

    local gained = current
    local previousLevel = math.max(1, (tonumber(level) or 1) - 1)
    local levelMax = tonumber(GetNumExperiencePointsInLevel(previousLevel)) or 0
    if levelMax > previous then
        gained = (levelMax - previous) + current
    end
    return math.max(0, tonumber(gained) or 0)
end

function TPM:CacheQuestCompletionData(journalIndex, fallbackQuestName)
    journalIndex = tonumber(journalIndex)
    if not journalIndex or not IsValidQuestIndex(journalIndex) then return end

    local questName = tostring(GetJournalQuestName(journalIndex) or fallbackQuestName or "")
    if questName == "" then return end

    self.questCompletionCache = self.questCompletionCache or {}
    local cached = {
        questName = questName,
        gold = 0,
        rewards = {},
        cachedAt = TPM_Now(),
    }

    local count = tonumber(GetJournalQuestNumRewards(journalIndex)) or 0
    for rewardIndex = 1, count do
        local rewardType, rewardName, amount, _, meetsUsageRequirement, _, itemType = GetJournalQuestRewardInfo(journalIndex, rewardIndex)
        amount = tonumber(amount) or 0
        local currencyType = GetCurrencyTypeFromRewardType(rewardType)

        if currencyType and _G.CURT_MONEY and currencyType == _G.CURT_MONEY then
            cached.gold = cached.gold + math.max(0, amount)
        elseif not currencyType or currencyType == 0 or (_G.CURT_NONE and currencyType == _G.CURT_NONE) then
            local ownedCollectible = _G.REWARD_TYPE_AUTO_ITEM and _G.REWARD_ITEM_TYPE_COLLECTIBLE
                and rewardType == _G.REWARD_TYPE_AUTO_ITEM and itemType == _G.REWARD_ITEM_TYPE_COLLECTIBLE
                and meetsUsageRequirement == false
            if not ownedCollectible and type(rewardName) == "string" and rewardName ~= "" then
                local formatted = zo_strformat(SI_TOOLTIP_ITEM_NAME, rewardName)
                cached.rewards[#cached.rewards + 1] = formatted
            end
        end
    end

    self.questCompletionCache[questName] = cached
end

function TPM:GetCachedQuestCompletionData(questName)
    self.questCompletionCache = self.questCompletionCache or {}
    local cached = self.questCompletionCache[tostring(questName or "")]
    if type(cached) ~= "table" then return nil end
    -- Never attach an ancient cache entry to a repeatable quest with the same name.
    if TPM_Now() - (tonumber(cached.cachedAt) or 0) > 3600 then
        self.questCompletionCache[tostring(questName or "")] = nil
        return nil
    end
    return cached
end

local function TPM_GetLocalTimestampParts(timestamp)
    timestamp = tonumber(timestamp) or TPM_Now()
    if timestamp <= 0 then return nil end

    -- Derive the player's current local offset from ESO's own local clock.
    local adjusted = timestamp + TPM_GetLocalUtcOffsetSeconds()
    if os and os.date then
        local parts = os.date("!*t", adjusted)
        if type(parts) == "table" then return parts end
    end

    -- Fallback: time portion can still be reconstructed without os.date.
    local seconds = adjusted % 86400
    return {
        hour = math.floor(seconds / 3600) % 24,
        min = math.floor(seconds / 60) % 60,
    }
end

local function TPM_GetCharacterTimestampParts(timestamp, utcOffset)
    timestamp = tonumber(timestamp) or TPM_Now()
    if timestamp <= 0 then return nil end
    local adjusted = timestamp + (tonumber(utcOffset) or TPM_GetLocalUtcOffsetSeconds())
    if os and os.date then
        local parts = os.date("!*t", adjusted)
        if type(parts) == "table" then return parts end
    end

    -- ESO builds do not have to expose Lua's os.date(). Convert Unix days to a
    -- Gregorian calendar date directly so persisted historic UTC offsets remain
    -- useful even on clients where only ESO's timestamp API is available.
    local whole = math.floor(adjusted)
    local days = math.floor(whole / 86400)
    local seconds = whole - days * 86400
    if seconds < 0 then seconds = seconds + 86400; days = days - 1 end
    local z = days + 719468
    local era = math.floor((z >= 0 and z or (z - 146096)) / 146097)
    local doe = z - era * 146097
    local yoe = math.floor((doe - math.floor(doe / 1460) + math.floor(doe / 36524) - math.floor(doe / 146096)) / 365)
    local year = yoe + era * 400
    local doy = doe - (365 * yoe + math.floor(yoe / 4) - math.floor(yoe / 100))
    local mp = math.floor((5 * doy + 2) / 153)
    local day = doy - math.floor((153 * mp + 2) / 5) + 1
    local month = mp + (mp < 10 and 3 or -9)
    if month <= 2 then year = year + 1 end
    return {
        year = year, month = month, day = day,
        hour = math.floor(seconds / 3600) % 24,
        min = math.floor(seconds / 60) % 60,
        sec = seconds % 60,
    }
end

local function TPM_GetLocalizedCharacterDateText(timestamp, lang, utcOffset)
    local p = TPM_GetCharacterTimestampParts(timestamp, utcOffset)
    lang = tostring(lang or "en")
    if p and p.year and p.month and p.day then
        if lang == "en" then return string.format("%02d/%02d/%04d", p.month, p.day, p.year) end
        if lang == "fr" then return string.format("%02d/%02d/%04d", p.day, p.month, p.year) end
        return string.format("%02d.%02d.%04d", p.day, p.month, p.year)
    end
    local value = GetDateStringFromTimestamp(tonumber(timestamp) or TPM_Now())
    if type(value) == "string" then return value end
    return ""
end

local function TPM_GetLocalizedCharacterTimeText(timestamp, lang, utcOffset)
    local p = TPM_GetCharacterTimestampParts(timestamp, utcOffset)
    if not p or p.hour == nil or p.min == nil then return "" end
    local hour, minute = tonumber(p.hour) or 0, tonumber(p.min) or 0
    if tostring(lang or "en") == "en" then
        local suffix = hour >= 12 and "PM" or "AM"
        local displayHour = hour % 12
        if displayHour == 0 then displayHour = 12 end
        return string.format("%d:%02d %s", displayHour, minute, suffix)
    end
    return string.format("%02d:%02d", hour, minute)
end

local function TPM_GetLocalizedLogDateText(timestamp, lang)
    local p = TPM_GetLocalTimestampParts(timestamp)
    lang = tostring(lang or "en")

    if p and p.year and p.month and p.day then
        if lang == "en" then
            return string.format("%02d/%02d/%04d", p.month, p.day, p.year)
        elseif lang == "fr" then
            return string.format("%02d/%02d/%04d", p.day, p.month, p.year)
        elseif lang == "ru" then
            return string.format("%02d.%02d.%04d", p.day, p.month, p.year)
        end
        return string.format("%02d.%02d.%04d", p.day, p.month, p.year)
    end

    -- Only as a last resort use ESO's client-locale string.
    local value = GetDateStringFromTimestamp(tonumber(timestamp) or TPM_Now())
    if type(value) == "string" then return value end
    return ""
end

local function TPM_GetLocalizedLogTimeText(timestamp, lang)
    local p = TPM_GetLocalTimestampParts(timestamp)
    if not p or p.hour == nil or p.min == nil then return "" end

    local hour = tonumber(p.hour) or 0
    local minute = tonumber(p.min) or 0
    if tostring(lang or "en") == "en" then
        local suffix = hour >= 12 and "PM" or "AM"
        local displayHour = hour % 12
        if displayHour == 0 then displayHour = 12 end
        return string.format("%d:%02d %s", displayHour, minute, suffix)
    end

    -- DE / FR / RU use a 24-hour clock.
    return string.format("%02d:%02d", hour, minute)
end

local function TPM_GetCurrentLogTimeText()
    local now = type(GetTimeStamp) == "function" and GetTimeStamp() or 0
    return TPM_GetLocalizedLogTimeText(now, TPM.langCode or "en")
end

local function TPM_GetLogTimeTextFromTimestamp(timestamp)
    return TPM_GetLocalizedLogTimeText(timestamp, TPM.langCode or "en")
end

function TPM:FormatLogTimestamp(entry)
    if type(entry) ~= "table" then return "" end

    local lang = self.langCode or "en"
    local timestamp = tonumber(entry.timestamp) or 0

    -- Always reformat from the stored timestamp. Older entries may contain
    -- German-formatted cached strings, which must not leak into EN/RU/FR.
    if timestamp > 0 then
        local dateText = TPM_GetLocalizedLogDateText(timestamp, lang)
        local timeText = TPM_GetLocalizedLogTimeText(timestamp, lang)
        if dateText ~= "" and timeText ~= "" then return dateText .. " • " .. timeText end
        return dateText ~= "" and dateText or timeText
    end

    -- Legacy fallback only for entries that predate timestamp storage.
    local dateText = tostring(entry.logDateText or "")
    local timeText = tostring(entry.logTimeText or "")
    if dateText ~= "" and timeText ~= "" then return dateText .. " • " .. timeText end
    return dateText ~= "" and dateText or timeText
end


function TPM:AddActivityLogEntry(entry)
    if type(entry) ~= "table" then return end
    if not TPM_IsMeaningfulDynamicEncounter(entry) then return end
    entry.timestamp = tonumber(entry.timestamp) or TPM_Now()
    if tostring(entry.logDateText or "") == "" then entry.logDateText = TPM_GetLocalizedLogDateText(entry.timestamp, self.langCode or "en") end
    if tostring(entry.logTimeText or "") == "" then entry.logTimeText = TPM_GetCurrentLogTimeText() end
    local store = self:GetHistoryStore()
    if not store then return end
    local isCombat = self:IsCombatLogKind(entry.activityKind)
    local listKey = isCombat and "combatActivities" or "activities"
    if type(store[listKey]) ~= "table" then store[listKey] = {} end
    local list = store[listKey]

    -- Guard against ESO firing the same completion twice. New world-event
    -- entries carry the stable instance id, so suppressing duplicates does not
    -- hide a later event with the same location/name.
    if self:IsWorldEventActivityKind(entry.activityKind) and tonumber(entry.worldEventInstanceId) and tonumber(entry.worldEventInstanceId) > 0 then
        local incomingId = tonumber(entry.worldEventInstanceId)
        local incomingTime = tonumber(entry.timestamp) or TPM_Now()
        for i = #list, math.max(1, #list - 8), -1 do
            local previous = list[i]
            if type(previous) == "table" and tonumber(previous.worldEventInstanceId) == incomingId then
                -- ESO may reuse the same World Event instance id when the same
                -- Dolmen/location activates again later. Only suppress callbacks
                -- from the *same completion*, not a later legitimate run.
                local previousTime = tonumber(previous.timestamp) or 0
                if previousTime > 0 and math.abs(incomingTime - previousTime) <= 15 then return end
            end
        end
    end

    list[#list + 1] = entry
    while #list > 100 do table.remove(list, 1) end
    if self.statisticsWindow and not self.statisticsWindow:IsHidden()
        and self.saved and self.saved.statisticsPage == "history"
        and self:GetStatisticsHistorySubPage() == 1 then
        self:RefreshCombatActivityPanel()
        local scroll = isCombat and self.statisticsCombatKillLogScroll or self.statisticsCombatActivityLogScroll
        if scroll and scroll.ResetToTop then scroll:ResetToTop() end
    end
end

function TPM:RecordQuestActivity(questName, level, previousExperience, currentExperience, championPoints, questType, zoneDisplayType)
    questName = tostring(questName or "")
    if questName == "" then return end
    local cached = self:GetCachedQuestCompletionData(questName)
    local rewards = cached and cached.rewards or nil
    local rewardText = ""
    if type(rewards) == "table" and #rewards > 0 then
        if #rewards == 1 then
            rewardText = rewards[1]
        elseif #rewards == 2 then
            rewardText = rewards[1] .. ", " .. rewards[2]
        else
            rewardText = rewards[1] .. ", " .. rewards[2] .. " +" .. tostring(#rewards - 2)
        end
    end

    local now = TPM_Now()
    local entry = {
        activityKind = "quest",
        activityName = questName,
        questType = questType,
        zoneDisplayType = zoneDisplayType,
        goldEarned = math.max(0, tonumber(cached and cached.gold) or 0),
        xpEarned = self:CalculateExperienceGain(level, previousExperience, currentExperience),
        rewardName = rewardText,
        duration = 0,
        startedAt = now,
        endedAt = now,
        timestamp = now,
        npcKillsDelta = 0,
        pveDeathsDelta = 0,
        pvpKillsDelta = 0,
        pvpDeathsDelta = 0,
    }
    self:AddActivityLogEntry(entry)
    if self.questCompletionCache then self.questCompletionCache[questName] = nil end
end

function TPM:StartTrackedActivity(snapshot)
    if not snapshot then return end
    local kind = snapshot.activityKind or "adventure"
    if kind == "adventure" then return end
    local now = tonumber(snapshot.timestamp) or TPM_Now()
    self.activeTrackedActivity = {
        kind = kind,
        name = snapshot.zoneName or "",
        zoneId = tonumber(snapshot.zoneId) or 0,
        startedAt = now,
        lastSeenAt = now,
        startSnapshot = snapshot,
        lastSnapshot = snapshot,
        texture = tostring(snapshot.activityTexture or ""),
        goldEarned = 0,
        xpEarned = 0,
    }
end

function TPM:FinalizeTrackedActivity(endSnapshot, endedAt)
    local active = self.activeTrackedActivity
    if type(active) ~= "table" or not active.startSnapshot then return end
    endSnapshot = endSnapshot or active.lastSnapshot or self:CaptureHistorySnapshot(false)
    if not endSnapshot then return end
    local endTime = tonumber(endedAt) or tonumber(endSnapshot.timestamp) or TPM_Now()
    local duration = math.max(0, endTime - (tonumber(active.startedAt) or endTime))
    local summary = self:BuildSessionSummary(active.startSnapshot, endSnapshot, active.startedAt, endTime, duration)
    if summary and duration >= 20 then
        summary.activityKind = active.kind or summary.activityKind or "adventure"
        summary.activityName = (active.name and active.name ~= "" and active.name) or summary.activityName or ""
        summary.activityTexture = (active.texture and active.texture ~= "" and active.texture) or summary.activityTexture or ""
        summary.goldEarned = math.max(0, tonumber(active.goldEarned) or 0)
        summary.xpEarned = math.max(0, tonumber(active.xpEarned) or 0)
        self:AddActivityLogEntry(summary)
    end
    self.activeTrackedActivity = nil
    self.pendingTrackedActivitySnapshot = nil
    if self.statisticsWindow and not self.statisticsWindow:IsHidden()
        and self.saved and self.saved.statisticsPage == "history"
        and self:GetStatisticsHistorySubPage() == 1 then
        self:RefreshCombatActivityPanel()
    end
end

function TPM:HandleTrackedActivityDeactivated(snapshot)
    local active = self.activeTrackedActivity
    if type(active) ~= "table" then return end
    snapshot = snapshot or self:CaptureHistorySnapshot(false)
    if snapshot then
        active.lastSnapshot = snapshot
        active.lastSeenAt = snapshot.timestamp or TPM_Now()
        self.pendingTrackedActivitySnapshot = snapshot
    end
end

function TPM:HandleTrackedActivityActivated()
    local snapshot = self:CaptureHistorySnapshot(false)
    if not snapshot then return end

    -- EVENT_PREPARE_FOR_JUMP gives us the destination's real display name and
    -- type before the loading screen. Prefer it for dungeon/raid/BG entries,
    -- because GetUnitZone() may expose only the parent overland zone.
    local jump = self.pendingJumpActivity
    if type(jump) == "table" and (TPM_Now() - (tonumber(jump.at) or 0)) <= 90 then
        if jump.kind and jump.kind ~= "adventure" then
            snapshot.activityKind = jump.kind
            if jump.name and jump.name ~= "" then snapshot.zoneName = jump.name end
            if jump.loadingTexture and jump.loadingTexture ~= "" then snapshot.activityTexture = jump.loadingTexture end
        end
    end
    self.pendingJumpActivity = nil

    local kind = snapshot.activityKind or "adventure"
    local name = snapshot.zoneName or ""
    local zoneId = tonumber(snapshot.zoneId) or 0
    local active = self.activeTrackedActivity

    if type(active) == "table" then
        local sameZone = zoneId > 0 and (tonumber(active.zoneId) or 0) > 0 and zoneId == tonumber(active.zoneId)
        local sameName = tostring(active.name or "") == tostring(name or "")
        -- A loading screen inside the same dungeon/activity is not completion.
        if active.kind == kind and (sameZone or sameName) then
            active.lastSnapshot = snapshot
            active.lastSeenAt = snapshot.timestamp or TPM_Now()
            if zoneId > 0 then active.zoneId = zoneId end
            if name ~= "" then active.name = name end
            if snapshot.activityTexture and snapshot.activityTexture ~= "" then active.texture = snapshot.activityTexture end
            self.pendingTrackedActivitySnapshot = nil
            return
        end

        -- We changed activity/zone. Finish the old activity using the snapshot
        -- captured before the loading screen so the correct dungeon counters
        -- and name are retained.
        local previousSnapshot = self.pendingTrackedActivitySnapshot or active.lastSnapshot
        self:FinalizeTrackedActivity(previousSnapshot, previousSnapshot and previousSnapshot.timestamp or TPM_Now())
    end

    self.pendingTrackedActivitySnapshot = nil
    if kind ~= "adventure" then
        self:StartTrackedActivity(snapshot)
    end
end

function TPM:CaptureHistorySnapshot(forceStatistics)
    local now = TPM_Now()
    local stats = self:GetStatisticsData(forceStatistics == true)
    local player = self:GetPlayerProgressData()
    local esoPlayedSeconds = self:SyncCurrentEsoPlayedTime()
    local combat = self:GetPlayerCombatStatsView()
    local currentZoneId, currentZoneIndex, currentZoneName = self:GetCurrentPlayerZoneIdentity()
    local snapshot = {
        timestamp = now,
        dayKey = TPM_DayKey(now),
        tamrielPercent = stats and stats.percent or 0,
        completedObjectives = stats and stats.completedObjectives or 0,
        totalObjectives = stats and stats.totalObjectives or 0,
        completedZones = stats and stats.completedZones or 0,
        totalZones = stats and stats.totalZones or 0,
        level = player.level or 0,
        cp = player.championPoints or 0,
        pvpKills = combat.pvpKills or 0,
        pvpDeaths = combat.pvpDeaths or 0,
        pvpKd = combat.kd or 0,
        npcKills = combat.npcKills or 0,
        pveDeaths = combat.pveDeaths or 0,
        bossKills = combat.bossKills or 0,
        playSeconds = self:GetCurrentPlaySeconds(),
        esoPlayedSeconds = esoPlayedSeconds or 0,
        currencies = {},
        categories = {},
        zoneId = currentZoneId or 0,
        zoneIndex = currentZoneIndex or 0,
        zoneName = currentZoneName or "",
        activityKind = self:GetCurrentTrackedActivityKind(),
    }

    local economyStats = self:GetEconomyStats()
    for _, definition in ipairs(self:GetEconomyCurrencyDefinitions()) do
        local amounts = self:GetEconomyCurrentAmounts(definition)
        local ledger = economyStats and economyStats.currencies and economyStats.currencies[definition.key] or nil
        snapshot.currencies[definition.key] = {
            current = amounts.current or 0,
            character = amounts.character or 0,
            bank = amounts.bank or 0,
            total = amounts.total or amounts.current or 0,
            -- Cumulative per-character ledger counters. Storing these in each
            -- history point lets the Development page calculate income/spending
            -- for any selected time range without keeping every transaction.
            received = ledger and (ledger.received or 0) or 0,
            spent = ledger and (ledger.spent or 0) or 0,
            bankDeposited = ledger and (ledger.bankDeposited or 0) or 0,
            bankWithdrawn = ledger and (ledger.bankWithdrawn or 0) or 0,
        }
    end

    local trackedCategories = {
        quests = ZONE_COMPLETION_TYPE_PRIORITY_QUESTS,
        skyshards = ZONE_COMPLETION_TYPE_SKYSHARDS,
        bosses = ZONE_COMPLETION_TYPE_GROUP_BOSSES,
        wayshrines = ZONE_COMPLETION_TYPE_WAYSHRINES,
    }
    for key, completionType in pairs(trackedCategories) do
        local row = self:GetSnapshotCategory(stats, completionType)
        snapshot.categories[key] = {
            completed = row and row.completed or 0,
            total = row and row.total or 0,
        }
    end
    return snapshot
end

function TPM:PruneHistory(store, now)
    if not store then return end
    now = tonumber(now) or TPM_Now()
    local retention = Clamp(Round(tonumber(self.saved and self.saved.historyRetentionDays) or HISTORY_RETENTION_DAYS), 30, 1460)
    local cutoffDay = TPM_DayKey(now) - retention
    for key, snapshot in pairs(store.daily or {}) do
        local day = tonumber(key) or tonumber(snapshot and snapshot.dayKey) or 0
        if day < cutoffDay then store.daily[key] = nil end
    end
    for key, extrema in pairs(store.dailyExtrema or {}) do
        local day = tonumber(key) or tonumber(extrema and extrema.dayKey) or 0
        if day < cutoffDay then store.dailyExtrema[key] = nil end
    end

    -- Keep recent intraday points for stock-like graphs. Older history remains
    -- compact as daily close plus daily extrema.
    local sampleCutoff = now - (math.min(retention, HISTORY_SAMPLE_RETENTION_DAYS) * 86400)
    local kept = {}
    for _, sample in ipairs(store.samples or {}) do
        if type(sample) == "table" and (tonumber(sample.timestamp) or 0) >= sampleCutoff then
            kept[#kept + 1] = sample
        end
    end
    while #kept > HISTORY_MAX_SAMPLES do table.remove(kept, 1) end
    store.samples = kept

    -- Character page keeps a compact date/time + played-seconds ledger for exactly
    -- the most recent 365 days, independently of the longer generic history.
    local characterCutoffDay = TPM_CharacterDayKey(now) - CHARACTER_PLAYTIME_RETENTION_DAYS + 1
    for key, entry in pairs(store.characterPlaytime365 or {}) do
        local day = tonumber(key) or tonumber(entry and entry.dayKey) or 0
        if day < characterCutoffDay then store.characterPlaytime365[key] = nil end
    end

    local sessions = store.sessions or {}
    while #sessions > HISTORY_MAX_SESSIONS do table.remove(sessions, 1) end
end

function TPM:BuildSessionSummary(startSnapshot, endSnapshot, startedAt, endedAt, activeDuration)
    if not startSnapshot or not endSnapshot then return nil end
    local function CurrencyDelta(key)
        local a = startSnapshot.currencies and startSnapshot.currencies[key]
        local b = endSnapshot.currencies and endSnapshot.currencies[key]
        return ((b and (b.total or b.current)) or 0) - ((a and (a.total or a.current)) or 0)
    end
    local function CategoryDelta(key)
        local a = startSnapshot.categories and startSnapshot.categories[key]
        local b = endSnapshot.categories and endSnapshot.categories[key]
        return ((b and b.completed) or 0) - ((a and a.completed) or 0)
    end
    return {
        startedAt = startedAt or startSnapshot.timestamp or 0,
        endedAt = endedAt or endSnapshot.timestamp or 0,
        duration = activeDuration ~= nil and math.max(0, tonumber(activeDuration) or 0) or math.max(0, (endedAt or 0) - (startedAt or 0)),
        tamrielDelta = (endSnapshot.tamrielPercent or 0) - (startSnapshot.tamrielPercent or 0),
        objectivesDelta = (endSnapshot.completedObjectives or 0) - (startSnapshot.completedObjectives or 0),
        goldDelta = CurrencyDelta("gold"),
        tradeBarsDelta = CurrencyDelta("tradeBars"),
        sealsDelta = CurrencyDelta("seals"),
        crownsDelta = CurrencyDelta("crowns"),
        questsDelta = CategoryDelta("quests"),
        skyshardsDelta = CategoryDelta("skyshards"),
        bossProgressDelta = CategoryDelta("bosses"),
        npcKillsDelta = (endSnapshot.npcKills or 0) - (startSnapshot.npcKills or 0),
        pveDeathsDelta = (endSnapshot.pveDeaths or 0) - (startSnapshot.pveDeaths or 0),
        bossKillsDelta = (endSnapshot.bossKills or 0) - (startSnapshot.bossKills or 0),
        pvpKillsDelta = (endSnapshot.pvpKills or 0) - (startSnapshot.pvpKills or 0),
        pvpDeathsDelta = (endSnapshot.pvpDeaths or 0) - (startSnapshot.pvpDeaths or 0),
        activityKind = endSnapshot.activityKind or startSnapshot.activityKind or "adventure",
        activityName = (endSnapshot.zoneName and endSnapshot.zoneName ~= "" and endSnapshot.zoneName) or startSnapshot.zoneName or "",
    }
end

function TPM:GetHistoryActiveElapsed(active, endAt)
    if type(active) ~= "table" then return 0 end
    local elapsed = math.max(0, tonumber(active.accumulatedSeconds) or 0)
    local segmentStartedAt = tonumber(active.segmentStartedAt)
    if segmentStartedAt and segmentStartedAt > 0 then
        local finish = tonumber(endAt) or TPM_Now()
        if finish >= segmentStartedAt then elapsed = elapsed + (finish - segmentStartedAt) end
    end
    return math.max(0, Round(elapsed))
end

function TPM:PauseHistorySession(store, now, snapshot)
    if not store or type(store.activeSession) ~= "table" then return end
    local active = store.activeSession
    now = tonumber(now) or TPM_Now()
    local segmentStartedAt = tonumber(active.segmentStartedAt)
    if segmentStartedAt and now >= segmentStartedAt then
        active.accumulatedSeconds = math.max(0, (tonumber(active.accumulatedSeconds) or 0) + (now - segmentStartedAt))
    else
        active.accumulatedSeconds = math.max(0, tonumber(active.accumulatedSeconds) or 0)
    end
    active.segmentStartedAt = nil
    active.deactivatedAt = now
    active.lastSeenAt = now
    if snapshot then active.lastSnapshot = snapshot end
end

function TPM:CommitFinishedSessionPlaytime(store, characterKey, activeDuration)
    if not store or type(store.activeSession) ~= "table" then return end
    local duration = math.max(0, Round(tonumber(activeDuration) or self:GetHistoryActiveElapsed(store.activeSession, store.activeSession.lastSeenAt)))
    if duration <= 0 then return end
    local combat = self:GetPlayerCombatStats(characterKey)
    -- Kept as a fallback for clients where GetSecondsPlayed is unavailable.
    -- On normal clients the visible "since TPM" value is derived from ESO's
    -- lifetime /played counter and its stored TPM baseline.
    combat.playSeconds = math.max(0, Round((combat.playSeconds or 0) + duration))
end

function TPM:FinalizeHistorySession(characterKey, store, endedAt)
    if not store or type(store.activeSession) ~= "table" then return end
    local active = store.activeSession
    local endTime = tonumber(endedAt) or tonumber(active.lastSeenAt) or TPM_Now()
    local duration = self:GetHistoryActiveElapsed(active, endTime)
    if active.startSnapshot and active.lastSnapshot then
        local summary = self:BuildSessionSummary(active.startSnapshot, active.lastSnapshot, active.startedAt, endTime, duration)
        if summary and summary.duration >= 60 then
            store.sessions[#store.sessions + 1] = summary
        end
    end
    self:CommitFinishedSessionPlaytime(store, characterKey, duration)
    if duration > 0 then
        if type(store.characterPlaytime365) ~= "table" then store.characterPlaytime365 = {} end
        local utcOffset = TPM_GetLocalUtcOffsetSeconds()
        local dayKey = TPM_CharacterDayKeyWithOffset(endTime, utcOffset)
        local key = tostring(dayKey)
        local entry = store.characterPlaytime365[key]
        if type(entry) ~= "table" then
            entry = { dayKey=dayKey, firstAt=endTime, lastAt=endTime, seconds=0, utcOffset=utcOffset, firstUtcOffset=utcOffset, lastUtcOffset=utcOffset, zones={} }
            store.characterPlaytime365[key] = entry
        end
        entry.longestSessionSeconds = math.max(tonumber(entry.longestSessionSeconds) or 0, duration)
    end
    store.activeSession = nil
    self:PruneHistory(store, endTime)
end

function TPM:FinalizeStaleHistorySession(store, now, characterKey)
    if not store or type(store.activeSession) ~= "table" then return end
    local active = store.activeSession
    now = tonumber(now) or TPM_Now()
    local lastSeen = tonumber(active.deactivatedAt) or tonumber(active.lastSeenAt) or tonumber(active.startedAt) or 0
    if lastSeen <= 0 or (now - lastSeen) <= SESSION_CONTINUITY_SECONDS then return end

    -- If ESO/the client stopped without a clean deactivation, only count up to
    -- our last confirmed checkpoint; never add the offline gap.
    if active.segmentStartedAt then
        local confirmedEnd = tonumber(active.lastSeenAt) or lastSeen
        local segmentStartedAt = tonumber(active.segmentStartedAt) or confirmedEnd
        if confirmedEnd >= segmentStartedAt then
            active.accumulatedSeconds = math.max(0, (tonumber(active.accumulatedSeconds) or 0) + (confirmedEnd - segmentStartedAt))
        end
        active.segmentStartedAt = nil
        active.deactivatedAt = confirmedEnd
        lastSeen = confirmedEnd
    end
    self:FinalizeHistorySession(characterKey or self:GetCurrentCharacterStatsKey(), store, lastSeen)
end

function TPM:FinalizeOtherCharacterHistorySessions(currentKey, now)
    if not self.saved or type(self.saved.historyByCharacter) ~= "table" then return end
    for key, rawStore in pairs(self.saved.historyByCharacter) do
        local store = self:GetHistoryStore(tostring(key)) or rawStore
        if tostring(key) ~= tostring(currentKey) and type(store) == "table" and type(store.activeSession) == "table" then
            -- A different character is now active. Whatever continuity window
            -- remains is irrelevant: the previous character's session is over.
            local active = store.activeSession
            local endTime = tonumber(active.deactivatedAt) or tonumber(active.lastSeenAt) or tonumber(now) or TPM_Now()
            if active.segmentStartedAt then
                local segmentStart = tonumber(active.segmentStartedAt) or endTime
                local confirmedEnd = tonumber(active.lastSeenAt) or endTime
                active.accumulatedSeconds = math.max(0, (tonumber(active.accumulatedSeconds) or 0) + math.max(0, confirmedEnd - segmentStart))
                active.segmentStartedAt = nil
                active.deactivatedAt = confirmedEnd
                endTime = confirmedEnd
            end
            self:FinalizeHistorySession(tostring(key), store, endTime)
        end
    end
end

function TPM:StartOrResumeHistorySession()
    local now = TPM_Now()
    local currentKey = self:GetCurrentCharacterStatsKey()
    self:SyncCurrentEsoPlayedTime()

    -- Finalize any session left by another character, including sessions that
    -- survived a character-select/reload cycle in SavedVariables.
    self:FinalizeOtherCharacterHistorySessions(currentKey, now)

    if not self.saved or self.saved.historyEnabled == false then
        if self.saved then
            local disabledStore = self:GetHistoryStore(currentKey)
            if disabledStore then self:FinalizeStaleHistorySession(disabledStore, now, currentKey) end
        end
        self.historySessionCharacterKey = currentKey
        return
    end
    local store = self:GetHistoryStore(currentKey)
    if not store then return end
    self:FinalizeStaleHistorySession(store, now, currentKey)
    local snapshot = self:CaptureHistorySnapshot(true)
    self:MigrateCharacterPlaytime365LocalDays(store)
    self:MigrateCharacterPlaytime365OffsetsAndZones(store)
    self:ResetCharacterPlaytimeObservation(store, snapshot)
    local active = store.activeSession
    if type(active) ~= "table" then
        active = {
            startedAt = now,
            startSnapshot = snapshot,
            lastSeenAt = now,
            lastSnapshot = snapshot,
            accumulatedSeconds = 0,
            segmentStartedAt = now,
            deactivatedAt = nil,
        }
        store.activeSession = active
    else
        active.accumulatedSeconds = math.max(0, tonumber(active.accumulatedSeconds) or 0)
        if not active.segmentStartedAt then active.segmentStartedAt = now end
        active.deactivatedAt = nil
        active.lastSeenAt = now
        active.lastSnapshot = snapshot
    end
    self.historySessionCharacterKey = currentKey
    self:UpsertDailyHistorySnapshot(snapshot)
    self:InitializeMilestoneBaseline(snapshot)
end

function TPM:UpdateHistoryExtremaForSnapshot(store, snapshot)
    if not store or not snapshot then return end
    if type(store.dailyExtrema) ~= "table" then store.dailyExtrema = {} end
    local dayKey = snapshot.dayKey or TPM_DayKey(snapshot.timestamp)
    local day = store.dailyExtrema[tostring(dayKey)]
    if type(day) ~= "table" then
        day = { dayKey = dayKey, metrics = {} }
        store.dailyExtrema[tostring(dayKey)] = day
    end
    if type(day.metrics) ~= "table" then day.metrics = {} end

    for _, definition in ipairs(self:GetHistoryMetricDefinitions()) do
        local value = tonumber(definition.getter(snapshot))
        if value ~= nil then
            local metric = day.metrics[definition.key]
            if type(metric) ~= "table" then
                metric = { high = value, low = value, highAt = snapshot.timestamp, lowAt = snapshot.timestamp }
                day.metrics[definition.key] = metric
            else
                if metric.high == nil or value > metric.high then
                    metric.high, metric.highAt = value, snapshot.timestamp
                end
                if metric.low == nil or value < metric.low then
                    metric.low, metric.lowAt = value, snapshot.timestamp
                end
            end
        end
    end
end

function TPM:MigrateHistoryExtrema(store)
    if not store or store.extremaVersion == "3.0.3" then return end
    for _, snapshot in pairs(store.daily or {}) do
        if type(snapshot) == "table" then self:UpdateHistoryExtremaForSnapshot(store, snapshot) end
    end
    local active = store.activeSession
    if type(active) == "table" then
        if type(active.startSnapshot) == "table" then self:UpdateHistoryExtremaForSnapshot(store, active.startSnapshot) end
        if type(active.lastSnapshot) == "table" then self:UpdateHistoryExtremaForSnapshot(store, active.lastSnapshot) end
    end
    store.extremaVersion = "3.0.3"
end

function TPM:CreateCompactHistorySample(snapshot)
    if not snapshot then return nil end
    local sample = {
        timestamp = snapshot.timestamp,
        dayKey = snapshot.dayKey,
        tamrielPercent = snapshot.tamrielPercent,
        level = snapshot.level,
        cp = snapshot.cp,
        esoPlayedSeconds = snapshot.esoPlayedSeconds,
        playSeconds = snapshot.playSeconds,
        pvpKd = snapshot.pvpKd,
        pvpKills = snapshot.pvpKills,
        pvpDeaths = snapshot.pvpDeaths,
        npcKills = snapshot.npcKills,
        pveDeaths = snapshot.pveDeaths,
        bossKills = snapshot.bossKills,
        currencies = {},
    }
    for key, currency in pairs(snapshot.currencies or {}) do
        sample.currencies[key] = {
            current = currency.current,
            character = currency.character,
            bank = currency.bank,
            total = currency.total,
            received = currency.received,
            spent = currency.spent,
        }
    end
    return sample
end

function TPM:HistorySnapshotsMeaningfullyDifferent(previous, current)
    if not previous or not current then return true end
    local directKeys = { "tamrielPercent", "level", "cp", "pvpKd", "pvpKills", "pvpDeaths", "npcKills", "pveDeaths", "bossKills" }
    for _, key in ipairs(directKeys) do
        if (tonumber(previous[key]) or 0) ~= (tonumber(current[key]) or 0) then return true end
    end
    for key, currentCurrency in pairs(current.currencies or {}) do
        local previousCurrency = previous.currencies and previous.currencies[key] or nil
        local a = tonumber(previousCurrency and (previousCurrency.total or previousCurrency.current)) or 0
        local b = tonumber(currentCurrency and (currentCurrency.total or currentCurrency.current)) or 0
        local delta = math.abs(b - a)
        local threshold = math.max(1, math.abs(a) * 0.01)
        if delta >= threshold then return true end
        local oldReceived = tonumber(previousCurrency and previousCurrency.received)
        local newReceived = tonumber(currentCurrency and currentCurrency.received)
        local oldSpent = tonumber(previousCurrency and previousCurrency.spent)
        local newSpent = tonumber(currentCurrency and currentCurrency.spent)
        if oldReceived ~= nil and newReceived ~= nil and oldReceived ~= newReceived then return true end
        if oldSpent ~= nil and newSpent ~= nil and oldSpent ~= newSpent then return true end

        if key == "gold" then
            local oldPlayer = tonumber(previousCurrency and previousCurrency.character) or 0
            local newPlayer = tonumber(currentCurrency.character) or 0
            local oldBank = tonumber(previousCurrency and previousCurrency.bank) or 0
            local newBank = tonumber(currentCurrency.bank) or 0
            if math.abs(newPlayer - oldPlayer) >= math.max(1, math.abs(oldPlayer) * 0.01)
                or math.abs(newBank - oldBank) >= math.max(1, math.abs(oldBank) * 0.01) then
                return true
            end
        end
    end
    return false
end

function TPM:RecordHistorySample(store, snapshot, force)
    if not store or not snapshot then return end
    if type(store.samples) ~= "table" then store.samples = {} end
    local compact = self:CreateCompactHistorySample(snapshot)
    if not compact then return end
    local samples = store.samples
    local last = samples[#samples]
    if not last then
        samples[#samples + 1] = compact
        return
    end

    local elapsed = (tonumber(compact.timestamp) or 0) - (tonumber(last.timestamp) or 0)
    local meaningful = self:HistorySnapshotsMeaningfullyDifferent(last, compact)
    if force == true or elapsed >= HISTORY_SAMPLE_INTERVAL_SECONDS or meaningful then
        if elapsed <= 1 and not meaningful then
            samples[#samples] = compact
        else
            samples[#samples + 1] = compact
        end
    else
        -- Tiny changes inside the cadence update the live endpoint without
        -- creating hundreds of points from individual loot ticks.
        samples[#samples] = compact
    end
    while #samples > HISTORY_MAX_SAMPLES do table.remove(samples, 1) end
end

-- 2.7.3: Dedicated 365-day Character playtime ledger. Generic history keeps
-- snapshots for graphs, while this compact ledger preserves the calendar day,
-- first/last observed time and played seconds needed by the Character page.
function TPM:UpdateCharacterPlaytime365(store, snapshot)
    if type(store) ~= "table" or type(snapshot) ~= "table" then return end
    if type(store.characterPlaytime365) ~= "table" then store.characterPlaytime365 = {} end

    local timestamp = tonumber(snapshot.timestamp) or 0
    local played = tonumber(snapshot.esoPlayedSeconds or snapshot.playSeconds)
    if timestamp <= 0 or played == nil then return end
    played = math.max(0, played)
    local currentOffset = TPM_GetLocalUtcOffsetSeconds()
    local currentZoneId = math.max(0, tonumber(snapshot.zoneId) or 0)
    local currentZoneName = tostring(snapshot.zoneName or "")

    local function TouchDay(dayKey, firstAt, lastAt, addSeconds, utcOffset, zoneId, zoneName, timeReliable)
        if not dayKey then return end
        local key = tostring(dayKey)
        local entry = store.characterPlaytime365[key]
        if type(entry) ~= "table" then
            entry = { dayKey = dayKey, firstAt = firstAt, lastAt = lastAt, seconds = 0, zones = {} }
            store.characterPlaytime365[key] = entry
        end
        entry.dayKey = dayKey
        if type(entry.zones) ~= "table" then entry.zones = {} end
        if firstAt and firstAt > 0 then
            if not entry.firstAt or firstAt < entry.firstAt then
                entry.firstAt = firstAt
                entry.firstUtcOffset = tonumber(utcOffset) or currentOffset
            end
        end
        if lastAt and lastAt > 0 then
            if not entry.lastAt or lastAt > entry.lastAt then
                entry.lastAt = lastAt
                entry.lastUtcOffset = tonumber(utcOffset) or currentOffset
            end
        end
        entry.utcOffset = tonumber(utcOffset) or entry.utcOffset or currentOffset
        if timeReliable == false then entry.timeReliable = false
        elseif timeReliable == true and entry.timeReliable ~= false then entry.timeReliable = true end
        local delta = math.max(0, tonumber(addSeconds) or 0)
        entry.seconds = math.max(0, Round((tonumber(entry.seconds) or 0) + delta))
        if delta > 0 and (tonumber(zoneId) or 0) > 0 then
            local zoneKey = tostring(math.floor(tonumber(zoneId)))
            local z = entry.zones[zoneKey]
            if type(z) ~= "table" then z = { zoneId = tonumber(zoneId), zoneName = tostring(zoneName or ""), seconds = 0 }; entry.zones[zoneKey] = z end
            if tostring(zoneName or "") ~= "" then z.zoneName = tostring(zoneName) end
            z.seconds = math.max(0, Round((tonumber(z.seconds) or 0) + delta))
        end
        entry.lastPlayedSeconds = played
    end

    local dayKey = TPM_CharacterDayKeyWithOffset(timestamp, currentOffset)
    TouchDay(dayKey, nil, nil, 0, currentOffset, currentZoneId, currentZoneName, nil)

    local previous = store.characterPlaytimeLastObservation
    local previousAt = type(previous) == "table" and tonumber(previous.timestamp) or nil
    local previousPlayed = type(previous) == "table" and tonumber(previous.played) or nil
    local previousOffset = type(previous) == "table" and tonumber(previous.utcOffset) or currentOffset
    local previousZoneId = type(previous) == "table" and math.max(0, tonumber(previous.zoneId) or 0) or currentZoneId
    local previousZoneName = type(previous) == "table" and tostring(previous.zoneName or "") or currentZoneName
    if previousAt and previousPlayed and timestamp == previousAt and played > previousPlayed then
        -- /played and the Unix clock can tick at different points within a
        -- frame. Preserve the real played delta even when the timestamp has
        -- not advanced; replacing the observation alone would discard it.
        TouchDay(dayKey, timestamp, timestamp, played - previousPlayed,
            currentOffset, previousZoneId, previousZoneName, true)
    elseif previousAt and previousPlayed and timestamp > previousAt and played >= previousPlayed then
        local deltaPlayed = math.max(0, played - previousPlayed)
        local wallSpan = timestamp - previousAt
        if deltaPlayed > 0 and wallSpan > 0 then
            local startDay = TPM_CharacterDayKeyWithOffset(previousAt, previousOffset)
            local endDay = TPM_CharacterDayKeyWithOffset(timestamp, currentOffset)
            if startDay == endDay then
                local continuous = wallSpan <= (deltaPlayed + 300)
                if continuous then
                    TouchDay(endDay, previousAt, timestamp, deltaPlayed, currentOffset, previousZoneId, previousZoneName, true)
                else
                    -- /played advanced, but the wall-clock gap is much larger. This
                    -- usually means TPM was offline between observations. Preserve the
                    -- real played delta without inventing a fake start/end interval.
                    TouchDay(endDay, nil, nil, deltaPlayed, currentOffset, previousZoneId, previousZoneName, false)
                end
            else
                -- Split checkpoints that cross local midnight. The previous and
                -- current observation each preserve their real UTC offset, so a
                -- DST boundary no longer gets reconstructed using today's offset.
                local remaining = deltaPlayed
                for day = startDay, endDay do
                    local segmentOffset = (day == startDay) and previousOffset or currentOffset
                    local segmentStart = math.max(previousAt, TPM_CharacterDayStartTimestampWithOffset(day, segmentOffset))
                    local segmentEnd = math.min(timestamp, TPM_CharacterDayStartTimestampWithOffset(day + 1, currentOffset))
                    local segmentWall = math.max(0, segmentEnd - segmentStart)
                    local share
                    if day == endDay then
                        share = remaining
                    else
                        share = math.max(0, Round(deltaPlayed * (segmentWall / wallSpan)))
                        share = math.min(remaining, share)
                    end
                    TouchDay(day, segmentStart, segmentEnd, share, segmentOffset, previousZoneId, previousZoneName, segmentWall <= (share + 300))
                    remaining = math.max(0, remaining - share)
                end
            end
        end
    end

    store.characterPlaytimeLastObservation = {
        timestamp = timestamp, played = played, utcOffset = currentOffset,
        zoneId = currentZoneId, zoneName = currentZoneName,
    }
end

function TPM:MigrateCharacterPlaytime365LocalDays(store)
    if type(store) ~= "table" then return end
    if type(store.characterPlaytime365) ~= "table" then store.characterPlaytime365 = {} end
    if store.characterPlaytime365LocalDaysMigrated then return end

    local migrated = {}
    for rawKey, entry in pairs(store.characterPlaytime365) do
        if type(entry) == "table" then
            local stamp = tonumber(entry.firstAt) or tonumber(entry.lastAt)
            local offset = tonumber(entry.utcOffset) or TPM_GetLocalUtcOffsetSeconds()
            local day = stamp and TPM_CharacterDayKeyWithOffset(stamp, offset) or tonumber(entry.dayKey) or tonumber(rawKey)
            if day then
                local key = tostring(day)
                local dst = migrated[key]
                if type(dst) ~= "table" then dst = { dayKey = day, seconds = 0, zones = {} }; migrated[key] = dst end
                local firstAt, lastAt = tonumber(entry.firstAt), tonumber(entry.lastAt)
                if firstAt and firstAt > 0 and (not dst.firstAt or firstAt < dst.firstAt) then
                    dst.firstAt, dst.firstUtcOffset = firstAt, tonumber(entry.firstUtcOffset) or offset
                end
                if lastAt and lastAt > 0 and (not dst.lastAt or lastAt > dst.lastAt) then
                    dst.lastAt, dst.lastUtcOffset = lastAt, tonumber(entry.lastUtcOffset) or offset
                end
                dst.utcOffset = tonumber(entry.utcOffset) or dst.utcOffset or offset
                dst.seconds = math.max(0, (tonumber(dst.seconds) or 0) + math.max(0, tonumber(entry.seconds) or 0))
                dst.lastPlayedSeconds = math.max(tonumber(dst.lastPlayedSeconds) or 0, tonumber(entry.lastPlayedSeconds) or 0)
                dst.longestSessionSeconds = math.max(tonumber(dst.longestSessionSeconds) or 0, tonumber(entry.longestSessionSeconds) or 0)
                dst.npcKills = math.max(0, (tonumber(dst.npcKills) or 0) + math.max(0, tonumber(entry.npcKills) or 0))
                dst.bossKills = math.max(0, (tonumber(dst.bossKills) or 0) + math.max(0, tonumber(entry.bossKills) or 0))
                if entry.combatDataReliable == true then dst.combatDataReliable = true end
                for zoneKey, zoneEntry in pairs(entry.zones or {}) do
                    if type(zoneEntry) == "table" then
                        local z = dst.zones[tostring(zoneKey)] or { zoneId = tonumber(zoneEntry.zoneId), zoneName = tostring(zoneEntry.zoneName or ""), seconds = 0 }
                        z.seconds = math.max(0, (tonumber(z.seconds) or 0) + math.max(0, tonumber(zoneEntry.seconds) or 0))
                        if tostring(zoneEntry.zoneName or "") ~= "" then z.zoneName = tostring(zoneEntry.zoneName) end
                        dst.zones[tostring(zoneKey)] = z
                    end
                end
            end
        end
    end
    store.characterPlaytime365 = migrated
    store.characterPlaytime365LocalDaysMigrated = true
    store.characterPlaytimeLastObservation = nil
end

function TPM:MigrateCharacterPlaytime365OffsetsAndZones(store)
    if type(store) ~= "table" or store.characterPlaytime365OffsetMigrated then return end
    local fallbackOffset = TPM_GetLocalUtcOffsetSeconds()
    for _, entry in pairs(store.characterPlaytime365 or {}) do
        if type(entry) == "table" then
            entry.utcOffset = tonumber(entry.utcOffset) or fallbackOffset
            entry.firstUtcOffset = tonumber(entry.firstUtcOffset) or entry.utcOffset
            entry.lastUtcOffset = tonumber(entry.lastUtcOffset) or entry.utcOffset
            if type(entry.zones) ~= "table" then entry.zones = {} end
        end
    end
    store.characterPlaytime365OffsetMigrated = true
    store.characterPlaytimeLastObservation = nil
end

function TPM:ResetCharacterPlaytimeObservation(store, snapshot)
    if type(store) ~= "table" then return end
    local timestamp = type(snapshot) == "table" and tonumber(snapshot.timestamp) or TPM_Now()
    local played = type(snapshot) == "table" and tonumber(snapshot.esoPlayedSeconds or snapshot.playSeconds) or nil
    if not played then
        local stats = self:GetPlayerCombatStats()
        played = stats and tonumber(stats.esoPlayedSeconds or stats.playSeconds) or 0
    end
    timestamp = tonumber(timestamp) or TPM_Now()
    played = math.max(0, tonumber(played) or 0)
    local utcOffset = TPM_GetLocalUtcOffsetSeconds()
    local zoneId = type(snapshot) == "table" and math.max(0, tonumber(snapshot.zoneId) or 0) or 0
    local zoneName = type(snapshot) == "table" and tostring(snapshot.zoneName or "") or ""
    store.characterPlaytimeLastObservation = { timestamp = timestamp, played = played, utcOffset = utcOffset, zoneId = zoneId, zoneName = zoneName }

    if type(store.characterPlaytime365) ~= "table" then store.characterPlaytime365 = {} end
    local day = TPM_CharacterDayKeyWithOffset(timestamp, utcOffset)
    local key = tostring(day)
    local entry = store.characterPlaytime365[key]
    if type(entry) ~= "table" then
        entry = { dayKey = day, seconds = 0, utcOffset = utcOffset, zones = {} }
        store.characterPlaytime365[key] = entry
    else
        entry.dayKey = day
        entry.utcOffset = tonumber(entry.utcOffset) or utcOffset
        if type(entry.zones) ~= "table" then entry.zones = {} end
    end
    entry.lastPlayedSeconds = played
end

function TPM:MigrateCharacterPlaytime365ReliabilityAndSamples(store)
    if type(store) ~= "table" then return end
    if type(store.characterPlaytime365) ~= "table" then store.characterPlaytime365 = {} end
    if store.characterPlaytime365ReliabilityMigrated then return end

    -- Classify old 2.7.3-2.7.5 rows. A large played value with identical
    -- first/last timestamps was reconstructed from cumulative /played data and
    -- must never be presented as an exact clock interval.
    for _, entry in pairs(store.characterPlaytime365) do
        if type(entry) == "table" and entry.timeReliable == nil then
            local firstAt, lastAt = tonumber(entry.firstAt), tonumber(entry.lastAt)
            local seconds = math.max(0, tonumber(entry.seconds) or 0)
            if seconds > 0 and firstAt and lastAt and math.abs(lastAt - firstAt) >= math.max(0, seconds - 300) and math.abs(lastAt - firstAt) <= seconds + 300 then
                entry.timeReliable = true
            elseif seconds > 0 then
                entry.timeReliable = false
                entry.reconstructed = true
            end
        end
    end

    -- Recover additional dates from TPM's older timestamped history samples.
    -- Only consecutive calendar days are used for a full-day delta; otherwise
    -- we keep the date as known but do not invent missing playtime.
    local snapshots, seen = {}, {}
    local function AddSnapshot(snap)
        if type(snap) ~= "table" then return end
        local ts = tonumber(snap.timestamp) or 0
        local played = tonumber(snap.esoPlayedSeconds or snap.playSeconds)
        if ts <= 0 or played == nil then return end
        local key = tostring(math.floor(ts)) .. ":" .. tostring(math.floor(played))
        if seen[key] then return end
        seen[key] = true
        snapshots[#snapshots + 1] = { timestamp=ts, played=math.max(0,played), dayKey=TPM_CharacterDayKey(ts) }
    end
    for _, snap in pairs(store.daily or {}) do AddSnapshot(snap) end
    for _, snap in ipairs(store.samples or {}) do AddSnapshot(snap) end
    table.sort(snapshots, function(a,b) return a.timestamp < b.timestamp end)

    local lastByDay = {}
    for _, snap in ipairs(snapshots) do lastByDay[snap.dayKey] = snap end
    local dayKeys = {}; for dayKey in pairs(lastByDay) do dayKeys[#dayKeys+1] = tonumber(dayKey) end
    table.sort(dayKeys)
    for _, dayKey in ipairs(dayKeys) do
        local snap = lastByDay[dayKey]
        local key = tostring(dayKey)
        local entry = store.characterPlaytime365[key]
        if type(entry) ~= "table" then
            entry = { dayKey=dayKey, seconds=0, utcOffset=TPM_GetLocalUtcOffsetSeconds(), zones={}, reconstructed=true, timeReliable=false }
            store.characterPlaytime365[key] = entry
        end
        local previous = lastByDay[dayKey - 1]
        if previous and snap.played >= previous.played and (tonumber(entry.seconds) or 0) <= 0 then
            entry.seconds = math.max(0, Round(snap.played - previous.played))
            entry.reconstructed = true
            entry.timeReliable = false
        end
    end
    store.characterPlaytime365ReliabilityMigrated = true
end

function TPM:MigrateCharacterDailyCombat365(store)
    if type(store) ~= "table" or store.characterDailyCombat365Migrated then return end
    if type(store.characterPlaytime365) ~= "table" then store.characterPlaytime365 = {} end
    -- Generic daily history stores cumulative combat counters. Where two
    -- consecutive daily closes exist, their delta is a reliable historic day.
    local daily = store.daily or {}
    local keys = {}
    for rawKey, snapshot in pairs(daily) do
        local day = tonumber(rawKey) or tonumber(snapshot and snapshot.dayKey)
        if day then keys[#keys+1] = day end
    end
    table.sort(keys)
    local previous = nil
    for _, day in ipairs(keys) do
        local snap = daily[tostring(day)] or daily[day]
        if type(snap) == "table" and type(previous) == "table" and day == (tonumber(previous.day) or 0) + 1 then
            local npcNow, npcPrev = tonumber(snap.npcKills), tonumber(previous.snap.npcKills)
            local bossNow, bossPrev = tonumber(snap.bossKills), tonumber(previous.snap.bossKills)
            if npcNow and npcPrev and bossNow and bossPrev and npcNow >= npcPrev and bossNow >= bossPrev then
                local key = tostring(day)
                local entry = store.characterPlaytime365[key]
                if type(entry) ~= "table" then entry={dayKey=day,seconds=0,zones={}}; store.characterPlaytime365[key]=entry end
                if entry.combatDataReliable ~= true then
                    entry.npcKills = math.max(0, Round(npcNow - npcPrev))
                    entry.bossKills = math.max(0, Round(bossNow - bossPrev))
                    entry.combatDataReliable = true
                end
            end
        end
        previous = { day=day, snap=snap }
    end
    store.characterDailyCombat365Migrated = true
end

function TPM:MigrateCharacterPlaytime365(store)
    if type(store) ~= "table" then return end
    if type(store.characterPlaytime365) ~= "table" then store.characterPlaytime365 = {} end
    self:MigrateCharacterPlaytime365LocalDays(store)
    self:MigrateCharacterPlaytime365OffsetsAndZones(store)
    self:MigrateCharacterPlaytime365ReliabilityAndSamples(store)
    self:MigrateCharacterDailyCombat365(store)
    if store.characterPlaytime365Migrated then return end

    -- Seed older installations from existing daily /played closes. Exact old
    -- first-login times cannot be reconstructed retroactively, but known dates
    -- and daily play deltas are retained.
    local snapshots = {}
    for _, snap in pairs(store.daily or {}) do
        if type(snap) == "table" then
            local ts = tonumber(snap.timestamp) or 0
            local pl = tonumber(snap.esoPlayedSeconds or snap.playSeconds)
            if ts > 0 and pl ~= nil then
                snapshots[#snapshots + 1] = { timestamp = ts, played = pl, dayKey = TPM_CharacterDayKey(ts) }
            end
        end
    end
    table.sort(snapshots, function(a, b) return a.timestamp < b.timestamp end)
    local previousPlayed
    for _, snap in ipairs(snapshots) do
        local key = tostring(snap.dayKey)
        local entry = store.characterPlaytime365[key]
        if type(entry) ~= "table" then
            entry = { dayKey = snap.dayKey, seconds = 0, utcOffset = TPM_GetLocalUtcOffsetSeconds(), zones = {}, timeReliable = false, reconstructed = true }
            store.characterPlaytime365[key] = entry
        end
        entry.timeReliable = false
        entry.reconstructed = true
        if previousPlayed and snap.played >= previousPlayed then
            entry.seconds = math.max(tonumber(entry.seconds) or 0, Round(snap.played - previousPlayed))
        end
        previousPlayed = snap.played
    end
    store.characterPlaytime365Migrated = true
end

function TPM:UpsertDailyHistorySnapshot(snapshot, forceSample)
    if not self.saved or self.saved.historyEnabled == false or not snapshot then return end
    local store = self:GetHistoryStore()
    if not store then return end
    self:MigrateHistoryExtrema(store)
    self:MigrateCharacterPlaytime365(store)
    self:UpdateCharacterPlaytime365(store, snapshot)
    local dayKey = snapshot.dayKey or TPM_DayKey(snapshot.timestamp)
    self:UpdateHistoryExtremaForSnapshot(store, snapshot)
    store.daily[tostring(dayKey)] = snapshot
    self:RecordHistorySample(store, snapshot, forceSample == true)
    if type(store.activeSession) == "table" then
        store.activeSession.lastSeenAt = snapshot.timestamp
        store.activeSession.lastSnapshot = snapshot
    end
    self:PruneHistory(store, snapshot.timestamp)
end

function TPM:CheckpointHistory(reason, forceStatistics, suppliedSnapshot)
    self:SyncCurrentEsoPlayedTime()
    if not self.saved or self.saved.historyEnabled == false then return end
    local snapshot = suppliedSnapshot or self:CaptureHistorySnapshot(forceStatistics == true)
    local forceSample = reason == "activated" or reason == "deactivated" or reason == "manual" or reason == "progress"
    self:UpsertDailyHistorySnapshot(snapshot, forceSample)
    local store = self:GetHistoryStore()
    if store then
        store.lastCheckpointReason = tostring(reason or "checkpoint")
        store.lastCheckpointAt = snapshot.timestamp
    end
end

function TPM:QueueEconomyHistoryCheckpoint()
    if not self.saved or self.saved.historyEnabled == false or self.economyHistoryCheckpointQueued then return end
    self.economyHistoryCheckpointQueued = true
    zo_callLater(function()
        TPM.economyHistoryCheckpointQueued = false
        if not TPM.saved or TPM.saved.historyEnabled == false then return end
        local snapshot = TPM:CaptureHistorySnapshot(false)
        TPM:CheckpointHistory("currency", false, snapshot)
        if TPM.statisticsWindow and not TPM.statisticsWindow:IsHidden()
            and TPM.saved.statisticsPage == "history"
            and TPM:GetStatisticsHistorySubPage() == 1 then
            TPM:RefreshHistoryStatisticsPage()
        end
    end, 250)
end

function TPM:CheckpointHistoryOnDeactivated()
    self:SyncCurrentEsoPlayedTime()
    if not self.saved or self.saved.historyEnabled == false then return end
    local now = TPM_Now()
    local store = self:GetHistoryStore()
    if not store then return end
    -- Use the cache unless progress invalidation already requires a rebuild.
    -- EVENT_PLAYER_DEACTIVATED also fires on ordinary loading screens, so a
    -- forced full Tamriel scan here would be unnecessarily expensive.
    local snapshot = self:CaptureHistorySnapshot(false)
    self:UpsertDailyHistorySnapshot(snapshot)
    self:HandleTrackedActivityDeactivated(snapshot)
    self:PauseHistorySession(store, now, snapshot)
    store.characterPlaytimeLastObservation = nil
    store.lastCheckpointReason = "deactivated"
    store.lastCheckpointAt = now
end

function TPM:GetCurrentPlaySeconds(characterKey)
    local key = characterKey or self:GetCurrentCharacterStatsKey()
    local stats = self:GetPlayerCombatStats(key)
    local currentKey = self:GetCurrentCharacterStatsKey()

    if tostring(key) == tostring(currentKey) then
        self:SyncCurrentEsoPlayedTime()
    end

    if stats.esoPlayedBaselineSeconds ~= nil and (stats.esoPlayedSeconds or 0) >= stats.esoPlayedBaselineSeconds then
        return math.max(0, Round((stats.esoPlayedSeconds or 0) - stats.esoPlayedBaselineSeconds))
    end

    -- Fallback only: preserve locally accumulated 3.0.x time if the ESO
    -- /played API is unexpectedly unavailable.
    local seconds = stats.playSeconds or 0
    local store = self:GetHistoryStore(key)
    local active = store and store.activeSession
    if active then
        local endAt = active.segmentStartedAt and TPM_Now() or active.lastSeenAt
        seconds = seconds + self:GetHistoryActiveElapsed(active, endAt)
    end
    return math.max(0, Round(seconds))
end

function TPM:InitializeMilestoneBaseline(snapshot)
    if not snapshot then return end
    local state = self:GetMilestoneState()
    if not state or state.initialized then return end
    for _, threshold in ipairs({10, 25, 50, 75, 90, 100}) do
        if (snapshot.tamrielPercent or 0) >= threshold then state.tamriel[tostring(threshold)] = true end
    end
    local stats = self:GetStatisticsData(false)
    for _, zone in ipairs(stats and stats.zones or {}) do
        if zone.percent >= 100 then state.zones[tostring(zone.zoneId)] = true end
    end
    state.initialized = true
end

function TPM:ShowMilestoneMessage(text)
    if not self.saved or self.saved.showMilestones == false or not text or text == "" then return end
    local decorated = "|cE0B050Naga Mapa Completo|r  " .. text
    if type(ZO_Alert) == "function" and _G.UI_ALERT_CATEGORY_ALERT then
        ZO_Alert(UI_ALERT_CATEGORY_ALERT, nil, decorated)
    elseif type(d) == "function" then
        d(decorated)
    end
end

function TPM:RecordMilestone(kind, key, label, timestamp)
    local state = self:GetMilestoneState()
    if not state then return end
    state.records[#state.records + 1] = {
        kind = kind,
        key = tostring(key),
        label = label,
        timestamp = timestamp or TPM_Now(),
    }
    while #state.records > 80 do table.remove(state.records, 1) end
end

function TPM:CheckMilestones(snapshot)
    if not self.saved then return end
    local notify = self.saved.showMilestones ~= false
    snapshot = snapshot or self:CaptureHistorySnapshot(false)
    local state = self:GetMilestoneState()
    if not state then return end
    if not state.initialized then
        self:InitializeMilestoneBaseline(snapshot)
        return
    end
    for _, threshold in ipairs({10, 25, 50, 75, 90, 100}) do
        local key = tostring(threshold)
        if (snapshot.tamrielPercent or 0) >= threshold and not state.tamriel[key] then
            state.tamriel[key] = true
            local text = self:L("MILESTONE_TAMRIEL", threshold)
            self:RecordMilestone("tamriel", key, text, snapshot.timestamp)
            if notify then self:ShowMilestoneMessage(text) end
        end
    end
    local stats = self:GetStatisticsData(false)
    for _, zone in ipairs(stats and stats.zones or {}) do
        local key = tostring(zone.zoneId)
        if zone.percent >= 100 and not state.zones[key] then
            state.zones[key] = true
            local text = self:L("MILESTONE_ZONE", zone.name)
            self:RecordMilestone("zone", key, text, snapshot.timestamp)
            if notify then self:ShowMilestoneMessage(text) end
        end
    end
end

function TPM:GetGoalPlannerModeIndex()
    local current = self.saved and self.saved.goalPlannerMode or "near"
    for i, value in ipairs(GOAL_PLANNER_MODES) do if value == current then return i end end
    return 1
end

function TPM:SetGoalPlannerMode(mode)
    local valid = false
    for _, value in ipairs(GOAL_PLANNER_MODES) do if value == mode then valid = true break end end
    if not valid then mode = "near" end
    self.saved.goalPlannerMode = mode
    if self.saved.statisticsPage == "goals" then self.saved.statisticsPage = "progress" end
end

function TPM:GetGoalPlannerCategoryDefinition(key)
    key = key or (self.saved and self.saved.goalPlannerCategory) or "all"
    for _, definition in ipairs(GOAL_CATEGORY_FILTERS) do
        if definition.key == key then return definition end
    end
    return GOAL_CATEGORY_FILTERS[1]
end

function TPM:SetGoalPlannerCategory(key)
    local definition = self:GetGoalPlannerCategoryDefinition(key)
    self.saved.goalPlannerCategory = definition.key
    if self.saved.statisticsPage == "goals" then self.saved.statisticsPage = "progress" end
end

function TPM:CycleGoalPlannerCategory(direction)
    local current = self:GetGoalPlannerCategoryDefinition()
    local index = 1
    for i, definition in ipairs(GOAL_CATEGORY_FILTERS) do
        if definition.key == current.key then index = i break end
    end
    local step = direction or 1
    index = ((index - 1 + step) % #GOAL_CATEGORY_FILTERS) + 1
    self:SetGoalPlannerCategory(GOAL_CATEGORY_FILTERS[index].key)
end

function TPM:GetGoalCategoryRemaining(zoneId, completionType)
    local breakdown = self:GetCompletionBreakdown(zoneId)
    for _, row in ipairs(breakdown or {}) do
        if row.completionType == completionType then
            return math.max(0, (row.total or 0) - (row.completed or 0)), row.total or 0
        end
    end
    return 0, 0
end

function TPM:GetGoalPlannerData(mode, categoryKey)
    mode = mode or (self.saved and self.saved.goalPlannerMode) or "near"
    categoryKey = categoryKey or (self.saved and self.saved.goalPlannerCategory) or "all"
    local categoryDefinition = self:GetGoalPlannerCategoryDefinition(categoryKey)
    local filterType = categoryDefinition.completionType
    local stats = self:GetStatisticsData(false)
    local rows = {}

    for _, zone in ipairs(stats and stats.zones or {}) do
        if zone.percent < 100 then
            local filterRemaining = 0
            if filterType then filterRemaining = self:GetGoalCategoryRemaining(zone.zoneId, filterType) end
            if not filterType or filterRemaining > 0 then
                local breakdown = self:GetCompletionBreakdown(zone.zoneId)
                local missing = {}
                for _, item in ipairs(breakdown or {}) do
                    local remaining = math.max(0, (item.total or 0) - (item.completed or 0))
                    if remaining > 0 then
                        missing[#missing + 1] = {
                            completionType = item.completionType,
                            remaining = remaining,
                            name = self:GetCompletionTypeName(item.completionType),
                        }
                    end
                end
                table.sort(missing, function(a, b)
                    if filterType then
                        local aSelected = a.completionType == filterType
                        local bSelected = b.completionType == filterType
                        if aSelected ~= bSelected then return aSelected end
                    end
                    if a.remaining == b.remaining then return a.name < b.name end
                    return a.remaining < b.remaining
                end)
                local details = {}
                for i = 1, math.min(3, #missing) do
                    details[#details + 1] = string.format("%s: %d", missing[i].name, missing[i].remaining)
                end
                rows[#rows + 1] = {
                    zoneId = zone.zoneId,
                    mapId = zone.mapId,
                    name = zone.name,
                    percent = zone.percent,
                    remaining = zone.remaining,
                    filterRemaining = filterRemaining,
                    detail = #details > 0 and table.concat(details, "  •  ") or self:L("GOAL_NO_DETAILS"),
                    missing = missing,
                }
            end
        end
    end

    table.sort(rows, function(a, b)
        if mode == "near" then
            -- "Nearly finished" answers one simple question: which zone needs
            -- the fewest remaining completion objectives? Percentage only breaks
            -- ties, so this view is intentionally different from Recommended.
            if a.remaining == b.remaining then
                if a.percent == b.percent then return a.name < b.name end
                return a.percent > b.percent
            end
            return a.remaining < b.remaining
        else
            -- Recommended favors overall completion first. When a category
            -- filter is active (e.g. Main quests), only zones missing that
            -- category are included and fewer missing category objectives break
            -- equal-percentage ties.
            if a.percent == b.percent then
                if filterType and a.filterRemaining ~= b.filterRemaining then
                    return a.filterRemaining < b.filterRemaining
                end
                if a.remaining == b.remaining then return a.name < b.name end
                return a.remaining < b.remaining
            end
            return a.percent > b.percent
        end
    end)
    return rows
end

function TPM:GetHistoryMetricDefinitions()
    if self.historyMetricDefinitions then return self.historyMetricDefinitions end
    -- 3.4.5: the old Development page is now a dedicated PvE/PvP page.
    -- Playtime lives on Progress and Total Gold is no longer exposed here.
    -- Hidden definitions remain only so previously stored history stays compatible.
    local definitions = {
        { key = "playTime", labelKey = "HISTORY_METRIC_PLAYTIME", kind = "duration", hidden = true, getter = function(s) return s.esoPlayedSeconds or s.playSeconds or 0 end },
        {
            key = "gold", labelKey = "HISTORY_METRIC_GOLD_TOTAL", kind = "number", currencyKey = "gold", hidden = true,
            getter = function(snapshot)
                local c = snapshot.currencies and snapshot.currencies.gold
                return c and (c.total or c.current) or 0
            end,
        },
        -- The combat dashboard uses npcKills as its navigation key; the graph
        -- itself still reads all four PvE/PvP counters.
        { key = "npcKills", labelKey = "HISTORY_COMBAT", kind = "number", getter = function(s) return s.npcKills or 0 end },
        { key = "pveDeaths", labelKey = "HISTORY_PVE_DEATHS", kind = "number", hidden = true, getter = function(s) return s.pveDeaths or 0 end },
        { key = "pvpKills", labelKey = "HISTORY_PVP_KILLS", kind = "number", hidden = true, getter = function(s) return s.pvpKills or 0 end },
        { key = "pvpDeaths", labelKey = "HISTORY_PVP_DEATHS", kind = "number", hidden = true, getter = function(s) return s.pvpDeaths or 0 end },
    }
    self.historyMetricDefinitions = definitions
    return definitions
end

function TPM:GetHistoryMetricDefinition(key)
    for _, definition in ipairs(self:GetHistoryMetricDefinitions()) do
        if definition.key == key then return definition end
    end
    return self:GetHistoryMetricDefinitions()[1]
end

function TPM:CycleHistoryMetric(direction)
    -- 3.4.5: PvE/PvP is the only visible combat page metric.
    if self.saved then self.saved.historyMetric = "npcKills" end
    self:RefreshHistoryStatisticsPage()
end

function TPM:SetHistoryRange(days)
    days = tonumber(days) or 30
    local valid = false
    for _, value in ipairs(HISTORY_RANGES) do if value == days then valid = true break end end
    self.saved.historyRangeDays = valid and days or 30
    self:RefreshHistoryStatisticsPage()
end

function TPM:ReduceHistoryPoints(points, maximum)
    maximum = math.max(4, tonumber(maximum) or HISTORY_MAX_CHART_POINTS)
    if #points <= maximum then return points end

    -- Preserve local highs/lows inside chronological buckets so spikes survive
    -- downsampling instead of disappearing from the chart.
    local reduced = { points[1] }
    local interior = #points - 2
    local bucketCount = math.max(1, math.floor((maximum - 2) / 2))
    for bucket = 1, bucketCount do
        local startIndex = 2 + math.floor(((bucket - 1) * interior) / bucketCount)
        local endIndex = 1 + math.floor((bucket * interior) / bucketCount)
        startIndex = Clamp(startIndex, 2, #points - 1)
        endIndex = Clamp(endIndex, startIndex, #points - 1)
        local lowIndex, highIndex = startIndex, startIndex
        for i = startIndex, endIndex do
            if points[i].value < points[lowIndex].value then lowIndex = i end
            if points[i].value > points[highIndex].value then highIndex = i end
        end
        if lowIndex == highIndex then
            reduced[#reduced + 1] = points[lowIndex]
        elseif lowIndex < highIndex then
            reduced[#reduced + 1] = points[lowIndex]
            reduced[#reduced + 1] = points[highIndex]
        else
            reduced[#reduced + 1] = points[highIndex]
            reduced[#reduced + 1] = points[lowIndex]
        end
    end
    reduced[#reduced + 1] = points[#points]
    while #reduced > maximum do table.remove(reduced, #reduced - 1) end
    return reduced
end

function TPM:GetHistorySeries(metricKey, rangeDays)
    local store = self:GetHistoryStore()
    if store then self:MigrateHistoryExtrema(store) end
    local def = self:GetHistoryMetricDefinition(metricKey)
    local points, seen = {}, {}
    local now = TPM_Now()
    local cutoffTimestamp = now - ((math.max(1, tonumber(rangeDays) or 30) - 1) * 86400)
    local cutoffDay = TPM_DayKey(cutoffTimestamp)

    local function AddPoint(timestamp, dayKey, value, snapshot, source)
        timestamp = tonumber(timestamp) or 0
        value = tonumber(value)
        if timestamp <= 0 or value == nil or timestamp < cutoffTimestamp then return end
        local dedupe = tostring(Round(timestamp)) .. ":" .. string.format("%.6f", value)
        if seen[dedupe] then return end
        seen[dedupe] = true
        points[#points + 1] = {
            timestamp = timestamp,
            dayKey = dayKey or TPM_DayKey(timestamp),
            value = value,
            snapshot = snapshot,
            source = source,
        }
    end

    for key, snapshot in pairs(store and store.daily or {}) do
        local day = tonumber(key) or tonumber(snapshot.dayKey) or 0
        if day >= cutoffDay then
            AddPoint(snapshot.timestamp or (day * 86400), day, def.getter(snapshot), snapshot, "daily")
        end
    end
    for _, sample in ipairs(store and store.samples or {}) do
        AddPoint(sample.timestamp, sample.dayKey, def.getter(sample), sample, "sample")
    end
    for key, dayExtrema in pairs(store and store.dailyExtrema or {}) do
        local day = tonumber(key) or tonumber(dayExtrema.dayKey) or 0
        if day >= cutoffDay and type(dayExtrema.metrics) == "table" then
            local metric = dayExtrema.metrics[metricKey]
            if type(metric) == "table" then
                AddPoint(metric.lowAt or (day * 86400), day, metric.low, nil, "low")
                AddPoint(metric.highAt or (day * 86400), day, metric.high, nil, "high")
            end
        end
    end

    table.sort(points, function(a,b)
        if a.timestamp == b.timestamp then return (a.value or 0) < (b.value or 0) end
        return a.timestamp < b.timestamp
    end)
    points = self:ReduceHistoryPoints(points, HISTORY_MAX_CHART_POINTS)
    return points, def
end


function TPM:GetDailyPlaytimeHistorySeries(rangeDays)
    local store = self:GetHistoryStore()
    local definition = self:GetHistoryMetricDefinition("playTime")
    local all, seen = {}, {}

    local function AddSnapshot(snapshot)
        if type(snapshot) ~= "table" then return end
        local timestamp = tonumber(snapshot.timestamp) or 0
        local played = tonumber(snapshot.esoPlayedSeconds or snapshot.playSeconds)
        if timestamp <= 0 or played == nil then return end
        local key = tostring(Round(timestamp)) .. ":" .. tostring(Round(played))
        if seen[key] then return end
        seen[key] = true
        all[#all + 1] = { timestamp = timestamp, dayKey = TPM_DayKey(timestamp), played = math.max(0, played) }
    end

    for _, snapshot in pairs(store and store.daily or {}) do AddSnapshot(snapshot) end
    for _, snapshot in ipairs(store and store.samples or {}) do AddSnapshot(snapshot) end
    local active = store and store.activeSession
    if type(active) == "table" then
        AddSnapshot(active.startSnapshot)
        AddSnapshot(active.lastSnapshot)
    end

    table.sort(all, function(a,b) return a.timestamp < b.timestamp end)
    local lastByDay, orderedDays = {}, {}
    for _, entry in ipairs(all) do
        if not lastByDay[entry.dayKey] then orderedDays[#orderedDays + 1] = entry.dayKey end
        lastByDay[entry.dayKey] = entry
    end
    table.sort(orderedDays)

    local cutoffDay = TPM_DayKey(TPM_Now()) - math.max(1, tonumber(rangeDays) or 30) + 1
    local previousPlayed = nil
    local points = {}
    for _, day in ipairs(orderedDays) do
        local entry = lastByDay[day]
        if previousPlayed ~= nil and day >= cutoffDay then
            local delta = math.max(0, (entry.played or 0) - previousPlayed)
            points[#points + 1] = {
                timestamp = entry.timestamp,
                dayKey = day,
                value = delta,
                source = "daily_playtime",
            }
        end
        previousPlayed = entry.played or previousPlayed
    end
    return self:ReduceHistoryPoints(points, HISTORY_MAX_CHART_POINTS), definition
end

function TPM:GetHistoryRangeExtrema(metricKey, rangeDays, points)
    local store = self:GetHistoryStore()
    if store then self:MigrateHistoryExtrema(store) end
    local now = TPM_Now()
    local cutoffDay = TPM_DayKey(now) - math.max(1, tonumber(rangeDays) or 30) + 1
    local high, low
    for key, dayExtrema in pairs(store and store.dailyExtrema or {}) do
        local day = tonumber(key) or tonumber(dayExtrema.dayKey) or 0
        if day >= cutoffDay and type(dayExtrema.metrics) == "table" then
            local metric = dayExtrema.metrics[metricKey]
            if type(metric) == "table" then
                if metric.high ~= nil then high = high == nil and metric.high or math.max(high, metric.high) end
                if metric.low ~= nil then low = low == nil and metric.low or math.min(low, metric.low) end
            end
        end
    end
    for _, point in ipairs(points or {}) do
        high = high == nil and point.value or math.max(high, point.value)
        low = low == nil and point.value or math.min(low, point.value)
    end
    return high or 0, low or 0
end

function TPM:GetHistoryCurrencyLedgerTotals(metricKey, rangeDays)
    local definition = self:GetHistoryMetricDefinition(metricKey)
    local currencyKey = definition and definition.currencyKey
    if not currencyKey then return nil end

    local bankTransferMetric = metricKey == "goldBank"
    local store = self:GetHistoryStore()
    if not store then return { income = 0, expenses = 0, net = 0, available = false, bankTransfers = bankTransferMetric } end

    local now = TPM_Now()
    local cutoff = now - ((math.max(1, tonumber(rangeDays) or 30) - 1) * 86400)
    local entries, seen = {}, {}

    local function AddSnapshot(snapshot)
        if type(snapshot) ~= "table" then return end
        local timestamp = tonumber(snapshot.timestamp) or 0
        if timestamp <= 0 or timestamp < cutoff then return end
        local currency = snapshot.currencies and snapshot.currencies[currencyKey]
        if type(currency) ~= "table" then return end
        local incoming = tonumber(bankTransferMetric and currency.bankDeposited or currency.received)
        local outgoing = tonumber(bankTransferMetric and currency.bankWithdrawn or currency.spent)
        if incoming == nil or outgoing == nil then return end
        local key = tostring(Round(timestamp)) .. ":" .. tostring(incoming) .. ":" .. tostring(outgoing)
        if seen[key] then return end
        seen[key] = true
        entries[#entries + 1] = { timestamp = timestamp, incoming = math.max(0, incoming), outgoing = math.max(0, outgoing) }
    end

    for _, snapshot in pairs(store.daily or {}) do AddSnapshot(snapshot) end
    for _, sample in ipairs(store.samples or {}) do AddSnapshot(sample) end
    local active = store.activeSession
    if type(active) == "table" then
        AddSnapshot(active.startSnapshot)
        AddSnapshot(active.lastSnapshot)
    end

    table.sort(entries, function(a, b)
        if a.timestamp == b.timestamp then return (a.incoming + a.outgoing) < (b.incoming + b.outgoing) end
        return a.timestamp < b.timestamp
    end)
    if #entries < 2 then
        return { income = 0, expenses = 0, net = 0, available = (#entries > 0), bankTransfers = bankTransferMetric }
    end

    local income, expenses = 0, 0
    local previous = entries[1]
    for i = 2, #entries do
        local current = entries[i]
        local incomingDelta = current.incoming - previous.incoming
        local outgoingDelta = current.outgoing - previous.outgoing
        income = income + (incomingDelta >= 0 and incomingDelta or current.incoming)
        expenses = expenses + (outgoingDelta >= 0 and outgoingDelta or current.outgoing)
        previous = current
    end

    income = math.max(0, Round(income))
    expenses = math.max(0, Round(expenses))
    return { income = income, expenses = expenses, net = income - expenses, available = true, bankTransfers = bankTransferMetric }
end

function TPM:GetHistoryRangeCombatStats(rangeDays)
    local store = self:GetHistoryStore()
    local result = { pvpKills = 0, pvpDeaths = 0, pvpKd = 0, npcKills = 0, pveDeaths = 0, bossKills = 0, playSeconds = 0 }
    if not store then return result end

    local now = TPM_Now()
    local cutoff = now - ((math.max(1, tonumber(rangeDays) or 30) - 1) * 86400)
    local entries, seen = {}, {}

    local function AddSnapshot(snapshot)
        if type(snapshot) ~= "table" then return end
        local timestamp = tonumber(snapshot.timestamp) or 0
        if timestamp <= 0 or timestamp < cutoff then return end
        local key = tostring(Round(timestamp)) .. ":" .. tostring(snapshot.pvpKills or 0) .. ":" .. tostring(snapshot.pvpDeaths or 0) .. ":" .. tostring(snapshot.npcKills or 0) .. ":" .. tostring(snapshot.bossKills or 0)
        if seen[key] then return end
        seen[key] = true
        entries[#entries + 1] = snapshot
    end

    for _, snapshot in pairs(store.daily or {}) do AddSnapshot(snapshot) end
    for _, snapshot in ipairs(store.samples or {}) do AddSnapshot(snapshot) end
    local active = store.activeSession
    if type(active) == "table" then
        AddSnapshot(active.startSnapshot)
        AddSnapshot(active.lastSnapshot)
    end

    table.sort(entries, function(a, b) return (tonumber(a.timestamp) or 0) < (tonumber(b.timestamp) or 0) end)
    if #entries < 1 then return result end

    local function SumCounter(field)
        local total = 0
        local previous = tonumber(entries[1][field]) or 0
        for i = 2, #entries do
            local current = tonumber(entries[i][field]) or 0
            local delta = current - previous
            total = total + (delta >= 0 and delta or current)
            previous = current
        end
        return math.max(0, Round(total))
    end

    result.pvpKills = SumCounter("pvpKills")
    result.pvpDeaths = SumCounter("pvpDeaths")
    result.npcKills = SumCounter("npcKills")
    result.pveDeaths = SumCounter("pveDeaths")
    result.bossKills = SumCounter("bossKills")

    local firstPlayed = tonumber(entries[1].esoPlayedSeconds or entries[1].playSeconds) or 0
    local lastPlayed = tonumber(entries[#entries].esoPlayedSeconds or entries[#entries].playSeconds) or firstPlayed
    result.playSeconds = math.max(0, Round(lastPlayed - firstPlayed))
    if result.pvpDeaths > 0 then
        result.pvpKd = result.pvpKills / result.pvpDeaths
    elseif result.pvpKills > 0 then
        result.pvpKd = math.huge
    else
        result.pvpKd = 0
    end
    return result
end

function TPM:GetLatestSessionSummary()
    local store = self:GetHistoryStore()
    local sessions = store and store.sessions or {}
    return sessions[#sessions]
end

function TPM:BuildDebugReport()
    local api = type(GetAPIVersion) == "function" and GetAPIVersion() or 0
    local lang = self.currentLanguage or "?"
    local key = self:GetCurrentCharacterStatsKey()
    local page = self.saved and self.saved.statisticsPage or "?"
    local mode = self.saved and self.saved.calculationMode or "?"
    return string.format("TPM %s | API %s | lang %s | char %s | page %s | mode %s", VERSION, tostring(api), tostring(lang), tostring(key), tostring(page), tostring(mode))
end

function TPM:IsCurrentBattlegroundActive()
    if type(GetCurrentBattlegroundId) == "function" then
        local battlegroundId = GetCurrentBattlegroundId() or 0
        if battlegroundId > 0 then return true end
    end
    if type(IsActiveWorldBattleground) == "function" and IsActiveWorldBattleground() then
        return true
    end
    return false
end

function TPM:IsInPvPEnvironment()
    if self:IsCurrentBattlegroundActive() then return true end
    if type(IsPlayerInAvAWorld) == "function" and IsPlayerInAvAWorld() then return true end
    if type(IsInCampaign) == "function" and IsInCampaign() then return true end
    return false
end

local function NormalizeDisplayName(name)
    return string.lower(tostring(name or ""))
end

function TPM:IsDuplicatePvPKillFeed(killerDisplayName, victimDisplayName, isKillLocation)
    local now = type(GetFrameTimeMilliseconds) == "function" and GetFrameTimeMilliseconds() or ((type(GetTimeStamp) == "function" and GetTimeStamp() or 0) * 1000)
    self.pvpKillFeedRecurrence = self.pvpKillFeedRecurrence or {}
    local suffix = NormalizeDisplayName(killerDisplayName) .. "|" .. NormalizeDisplayName(victimDisplayName)
    local sourcePrefix = isKillLocation == true and "B|" or "L|"
    local otherPrefix = isKillLocation == true and "L|" or "B|"
    local sourceKey = sourcePrefix .. suffix
    local otherKey = otherPrefix .. suffix
    local otherTime = self.pvpKillFeedRecurrence[otherKey]
    if otherTime and (now - otherTime) >= 0 and (now - otherTime) <= 10000 then
        -- ESO can raise the same PvP death once from the local unit state and
        -- once from the server kill-location feed. Vanilla ChatHandlers uses a
        -- 10-second counterpart recurrence window for exactly this case.
        self.pvpKillFeedRecurrence[otherKey] = nil
        return true
    end
    self.pvpKillFeedRecurrence[sourceKey] = now
    self.pvpKillFeedRecurrenceWrites = (self.pvpKillFeedRecurrenceWrites or 0) + 1
    if self.pvpKillFeedRecurrenceWrites >= 24 then
        self.pvpKillFeedRecurrenceWrites = 0
        for key, timestamp in pairs(self.pvpKillFeedRecurrence) do
            if (now - (timestamp or 0)) > 20000 then self.pvpKillFeedRecurrence[key] = nil end
        end
    end
    return false
end

function TPM:IsDuplicateCombatCounterEvent(key, windowMs)
    local now = type(GetFrameTimeMilliseconds) == "function" and GetFrameTimeMilliseconds() or ((type(GetTimeStamp) == "function" and GetTimeStamp() or 0) * 1000)
    self.combatCounterRecurrence = self.combatCounterRecurrence or {}
    local lastTime = self.combatCounterRecurrence[key]
    if lastTime and (now - lastTime) >= 0 and (now - lastTime) <= (windowMs or 1200) then
        return true
    end
    self.combatCounterRecurrence[key] = now

    -- Keep the recurrence table tiny even during long PvP sessions.
    self.combatCounterRecurrenceWrites = (self.combatCounterRecurrenceWrites or 0) + 1
    if self.combatCounterRecurrenceWrites >= 32 then
        self.combatCounterRecurrenceWrites = 0
        for oldKey, oldTime in pairs(self.combatCounterRecurrence) do
            if (now - (oldTime or 0)) > 12000 then
                self.combatCounterRecurrence[oldKey] = nil
            end
        end
    end
    return false
end

-- 2.7.29: Pair ACTION_RESULT_DIED and ACTION_RESULT_DIED_XP even when ESO
-- does not provide targetUnitId. A queue is used instead of simple name-based
-- throttling so two same-name enemies dying in the same AoE can still count twice.
function TPM:IsDuplicatePveNpcDeathWithoutUnitId(targetName, result)
    local cleanName, normalizedName = self:NormalizeCombatUnitName(targetName)
    normalizedName = normalizedName ~= "" and normalizedName or string.lower(tostring(cleanName or targetName or "unknown"))
    if normalizedName == "" then normalizedName = "unknown" end

    local kind = (_G.ACTION_RESULT_DIED_XP ~= nil and result == _G.ACTION_RESULT_DIED_XP) and "xp" or "died"
    local opposite = kind == "xp" and "died" or "xp"
    local now = type(GetFrameTimeMilliseconds) == "function" and GetFrameTimeMilliseconds()
        or ((type(GetTimeStamp) == "function" and GetTimeStamp() or 0) * 1000)

    self.pveNoUnitDeathPairs = self.pveNoUnitDeathPairs or {}
    local queue = self.pveNoUnitDeathPairs[normalizedName]
    if type(queue) ~= "table" then queue = {}; self.pveNoUnitDeathPairs[normalizedName] = queue end

    -- Remove stale signals first. DIED and DIED_XP for one death are normally
    -- adjacent; 900 ms is deliberately narrow enough not to merge later kills.
    for i = #queue, 1, -1 do
        local age = now - (tonumber(queue[i].atMs) or 0)
        if age < 0 or age > 900 then table.remove(queue, i) end
    end

    for i, entry in ipairs(queue) do
        if entry.kind == opposite then
            table.remove(queue, i)
            if #queue == 0 then self.pveNoUnitDeathPairs[normalizedName] = nil end
            return true
        end
    end

    queue[#queue + 1] = { kind = kind, atMs = now }
    while #queue > 8 do table.remove(queue, 1) end
    return false
end

function TPM:RecordPvPResult(killerDisplayName, victimDisplayName, sourceTag, killerCharacterName, victimCharacterName)
    local me = NormalizeDisplayName(type(GetDisplayName) == "function" and GetDisplayName() or "")
    local killer = NormalizeDisplayName(killerDisplayName)
    local victim = NormalizeDisplayName(victimDisplayName)
    if me == "" or victim == "" then return end

    local key = string.format("%s|%s|%s", tostring(sourceTag or "pvp"), killer, victim)
    local duplicateWindow = sourceTag == "pvp" and 10000 or 1800
    if self:IsDuplicateCombatCounterEvent(key, duplicateWindow) then return end

    if victim == me then
        self:IncrementPlayerCombatStat("pvpDeaths", 1)
    end
    if killer == me and victim ~= me then
        self:IncrementPlayerCombatStat("pvpKills", 1)
        local name = tostring(victimCharacterName or "")
        if name == "" then name = tostring(victimDisplayName or "") end
        if type(zo_strformat) == "function" and name ~= "" then name = zo_strformat("<<C:1>>", name) end
        local now = TPM_Now()
        self:AddActivityLogEntry({
            activityKind = "killPlayer",
            activityName = name,
            xpEarned = 0,
            goldEarned = 0,
            difficulty = "player",
            duration = 0,
            startedAt = now,
            endedAt = now,
            timestamp = now,
            npcKillsDelta = 0,
            pveDeathsDelta = 0,
            pvpKillsDelta = 1,
            pvpDeathsDelta = 0,
        })
    end
end

function TPM:RecordBossDefeat(unitTag)
    if not unitTag or not string.match(unitTag, "^boss%d+$") then return end
    local name = type(GetUnitName) == "function" and (GetUnitName(unitTag) or "") or ""
    local key = string.format("boss|%s|%s", tostring(unitTag), tostring(name))
    if self:IsDuplicateCombatCounterEvent(key, 8000) then return end
    self:IncrementPlayerCombatStat("bossKills", 1)
    self:PromoteOrQueueBossKillActivity(name)
end

function TPM:GetOverviewPercentText(percent)
    percent = Clamp(Round(percent or 0), 0, 100)
    if percent >= 100 then
        local mode = self.saved and self.saved.hundredDisplayMode or "percent"
        if mode == "check" then
            local iconSize = Clamp((self.GetProgressFontSize and self:GetProgressFontSize("overlay")) or 24, 18, 48)
            if type(zo_iconFormatInheritColor) == "function" then
                return zo_iconFormatInheritColor("EsoUI/Art/Buttons/accept_up.dds", iconSize, iconSize)
            elseif type(zo_iconFormat) == "function" then
                return zo_iconFormat("EsoUI/Art/Buttons/accept_up.dds", iconSize, iconSize)
            end
            return ""
        elseif mode == "hidden" then
            -- The explicit 100% quick filter temporarily reveals completed
            -- zones so the filter remains useful even when they are normally hidden.
            if self.saved and self.saved.quickFilter == "complete" then
                return "100%"
            end
            return nil
        end
    end
    return string.format("%d%%", percent)
end

function TPM:MatchesQuickFilter(percent)
    local filter = self.saved and self.saved.quickFilter or "all"
    if filter == "incomplete" then
        return percent < 100
    elseif filter == "under50" then
        return percent < 50
    elseif filter == "complete" then
        return percent >= 100
    end
    return true
end

local function SafeZoneName(zoneId)
    -- TPM follows the ESO client language, so the native zone-name API is the
    -- authoritative and resource-light source for map labels and Statistics.
    local name = GetZoneNameById(zoneId)
    if not name or name == "" then return tostring(zoneId) end
    return ZO_CachedStrFormat(SI_ZONE_NAME, name)
end

function TPM:IsProgressZoneAvailable(zoneId)
    if type(zoneId) ~= "number" or zoneId <= 0 then
        return false
    end

    -- DLC/chapter ownership is represented by the zone collectible lock.
    if type(GetZoneIndex) == "function" and type(IsZoneCollectibleLocked) == "function" then
        local zoneIndex = GetZoneIndex(zoneId)
        if zoneIndex and zoneIndex > 0 and IsZoneCollectibleLocked(zoneIndex) then
            return false
        end
    end

    -- Do not reject a zone merely because IsZoneStoryZoneAvailable() is false:
    -- several small/special maps can still expose valid completion counters via
    -- their own zone id or a fallback story zone. Ownership locking is the safe
    -- filter here.
    return true
end

function TPM:GetGameLanguage()
    local language = zo_strlower(GetCVar("language.2") or "en")
    language = string.sub(tostring(language), 1, 2)
    return SUPPORTED_LANGUAGES[language] and language or "en"
end

function TPM:ResolveLanguage()
    -- localization/en.lua creates the fallback SI_TPM_* ids. The manifest then
    -- loads only the active ESO client language through $(language).
    self.langCode = self:GetGameLanguage()
    self.stringIdCache = self.stringIdCache or {}
    if self.saved then self.saved.language = "auto" end
end

function TPM:L(key, ...)
    self.stringIdCache = self.stringIdCache or {}
    local stringId = self.stringIdCache[key]
    if stringId == nil then
        stringId = _G["SI_TPM_" .. tostring(key)] or false
        self.stringIdCache[key] = stringId
    end
    local value = stringId and GetString(stringId) or tostring(key)
    if select("#", ...) > 0 then return string.format(value, ...) end
    return value
end

function TPM:NormalizeFontStyle(style)
    if style == "map" then
        return "handwritten" -- legacy name used up to v1.5.4
    end
    if FONT_PROFILES[style] then
        return style
    end
    return nil
end

function TPM:GetFontProfile(style)
    style = self:NormalizeFontStyle(style or (self.saved and self.saved.fontStyle) or "classic") or "classic"
    return FONT_PROFILES[style] or FONT_PROFILES.classic
end

function TPM:GetFontStyleName(style)
    style = self:NormalizeFontStyle(style) or "classic"
    local key = FONT_STYLE_NAME_KEYS[style] or FONT_STYLE_NAME_KEYS.classic
    return self:L(key)
end

function TPM:IsValidFontStyle(style)
    return self:NormalizeFontStyle(style) ~= nil
end

function TPM:GetAdjacentFontStyle(style, direction)
    style = self:NormalizeFontStyle(style) or "classic"
    local currentIndex = 1
    for index, key in ipairs(FONT_STYLE_ORDER) do
        if key == style then
            currentIndex = index
            break
        end
    end
    local count = #FONT_STYLE_ORDER
    local newIndex = ((currentIndex - 1 + direction) % count) + 1
    return FONT_STYLE_ORDER[newIndex]
end

function TPM:GetProgressFontSpec(kind)
    local profile = self:GetFontProfile(self.saved and self.saved.fontStyle or "classic")
    local baseSpec = kind == "header" and profile.header or profile.overlay
    local scale = kind == "header"
        and (self.saved and self.saved.headerPercentScale or DEFAULTS.headerPercentScale)
        or (self.saved and self.saved.mapPercentScale or DEFAULTS.mapPercentScale)
    return ScaleFontSpec(baseSpec, scale)
end

function TPM:GetProgressFontSize(kind)
    local spec = self:GetProgressFontSpec(kind)
    return tonumber(string.match(spec or "", "|(%d+)")) or (kind == "header" and 46 or 28)
end

function TPM:ApplyProgressFont(control, kind)
    if not control then return end
    control:SetFont(self:GetProgressFontSpec(kind))
end

function TPM:ApplyProgressFonts()
    if self.headerLabel then
        self:ApplyProgressFont(self.headerLabel, "header")
    end
    for _, label in ipairs(self.overlayLabels) do
        self:ApplyProgressFont(label, "overlay")
    end
    for _, label in ipairs(self.labelPool) do
        self:ApplyProgressFont(label, "overlay")
    end
end

function TPM:ApplyQuestRewardFonts()
    local style = self.saved and self.saved.questFontStyle or "classic"
    local profile = self:GetFontProfile(style)
    if self.questRewardTitle then
        self.questRewardTitle:SetFont(profile.questTitle or FONT_PROFILES.classic.questTitle)
    end
    if self.questRewardLines then
        self.questRewardLines:SetFont(profile.questBody or FONT_PROFILES.classic.questBody)
    end
    self:UpdateQuestRewardLayout()
    if self.saved and self.saved.questRewardAutoSize then
        self:AutoSizeQuestRewardWindow()
    end
end

function TPM:IsWorldMapVisible()
    -- Track keyboard and gamepad map scenes independently. A stale false flag
    -- must never override ESO's actual scene/control visibility.
    if self.worldMapSceneVisible == true or self.gamepadWorldMapSceneVisible == true then
        return true
    end

    if WORLD_MAP_SCENE and WORLD_MAP_SCENE.IsShowing and WORLD_MAP_SCENE:IsShowing() then
        return true
    end
    if GAMEPAD_WORLD_MAP_SCENE and GAMEPAD_WORLD_MAP_SCENE.IsShowing and GAMEPAD_WORLD_MAP_SCENE:IsShowing() then
        return true
    end

    if SCENE_MANAGER and SCENE_MANAGER.IsShowing then
        if SCENE_MANAGER:IsShowing("worldMap") or SCENE_MANAGER:IsShowing("gamepad_worldMap") then
            return true
        end
    end

    if ZO_WorldMap and ZO_WorldMap.IsHidden then
        return not ZO_WorldMap:IsHidden()
    end
    return false
end

-- Unlike IsWorldMapVisible(), this intentionally ignores ZO_WorldMap control
-- visibility. Minimap addons such as Votan's Minimap can reuse/show that control
-- while the real world-map scene is closed. Full-map-only UI (quick filters)
-- must therefore use the scene state instead.
function TPM:IsFullWorldMapSceneVisible()
    if self.worldMapSceneVisible == true or self.gamepadWorldMapSceneVisible == true then
        return true
    end
    if WORLD_MAP_SCENE and WORLD_MAP_SCENE.IsShowing and WORLD_MAP_SCENE:IsShowing() then
        return true
    end
    if GAMEPAD_WORLD_MAP_SCENE and GAMEPAD_WORLD_MAP_SCENE.IsShowing and GAMEPAD_WORLD_MAP_SCENE:IsShowing() then
        return true
    end
    if SCENE_MANAGER and SCENE_MANAGER.IsShowing then
        if SCENE_MANAGER:IsShowing("worldMap") or SCENE_MANAGER:IsShowing("gamepad_worldMap") then
            return true
        end
    end
    return false
end

function TPM:GetCompletionTypeName(completionType)
    local key = COMPLETION_LOCALIZATION_KEYS[completionType]
    if key then
        return self:L(key)
    end
    local fallback = GetString("SI_ZONECOMPLETIONTYPE", completionType)
    if fallback and fallback ~= "" then
        return fallback
    end
    return tostring(completionType)
end

-- Zone Guide completion wrapper shared by API 101050 and 101051+.
-- ZOS changed the underlying global functions in Update 51, while
-- ZONE_STORIES_MANAGER:GetActivityCompletionProgressValues remains the stable
-- UI abstraction and dispatches to the correct API for the active client.
function TPM:GetZoneCompletionActivityProgress(zoneId, completionType)
    zoneId = tonumber(zoneId) or 0
    if zoneId <= 0 or completionType == nil then return 0, 0 end

    local manager = _G.ZONE_STORIES_MANAGER
    local getter = manager and manager.GetActivityCompletionProgressValues
    if type(getter) ~= "function" then return 0, 0 end

    local ok, completed, total = pcall(getter, zoneId, completionType)
    if not ok then return 0, 0 end

    completed = math.max(0, tonumber(completed) or 0)
    total = math.max(0, tonumber(total) or 0)
    if completed > total then completed = total end
    return completed, total
end

function TPM:GetZoneCompletionActivityTotal(zoneId, completionType)
    local _, total = self:GetZoneCompletionActivityProgress(zoneId, completionType)
    return total
end

function TPM:GetZoneCompletionActivityCompleted(zoneId, completionType)
    local completed = self:GetZoneCompletionActivityProgress(zoneId, completionType)
    return completed
end

function TPM:GetCompletionBreakdown(zoneId)
    local breakdown = {}
    local completedTotal = 0
    local availableTotal = 0
    local categoryRatioTotal = 0
    local categoryCount = 0

    if type(zoneId) ~= "number" or zoneId <= 0 then
        return breakdown, 0, 0, 0, 0, 0
    end

    for _, completionType in ipairs(COMPLETION_TYPES) do
        local total = self:GetZoneCompletionActivityTotal(zoneId, completionType)
        if total > 0 then
            local completed = self:GetZoneCompletionActivityCompleted(zoneId, completionType)
            completed = Clamp(completed, 0, total)
            local categoryPercent = Clamp(Round((completed / total) * 100), 0, 100)
            if completed < total and categoryPercent >= 100 then
                categoryPercent = 99
            end

            completedTotal = completedTotal + completed
            availableTotal = availableTotal + total
            categoryRatioTotal = categoryRatioTotal + (completed / total)
            categoryCount = categoryCount + 1

            breakdown[#breakdown + 1] =
            {
                completionType = completionType,
                completed = completed,
                total = total,
                percent = categoryPercent,
            }
        end
    end

    local objectivePercent = 0
    if availableTotal > 0 then
        objectivePercent = Round((completedTotal / availableTotal) * 100)
    end

    local categoryPercent = 0
    if categoryCount > 0 then
        categoryPercent = Round((categoryRatioTotal / categoryCount) * 100)
    end

    local mode = self.saved and self.saved.calculationMode or "objectives"
    local percent = mode == "categories" and categoryPercent or objectivePercent

    -- Never report 100% from rounding while at least one objective is still open.
    -- This also prevents "hide completed" from hiding a 99.x% zone.
    if availableTotal > 0 and completedTotal < availableTotal and percent >= 100 then
        percent = 99
    end

    return breakdown, completedTotal, availableTotal, Clamp(percent, 0, 100), categoryRatioTotal, categoryCount
end

function TPM:GetResolvedCompletion(zoneId)
    local breakdown, completedTotal, availableTotal, percent = self:GetCompletionBreakdown(zoneId)
    local progressZoneId = zoneId

    if availableTotal <= 0 and type(GetZoneStoryZoneIdForZoneId) == "function" then
        local storyZoneId = GetZoneStoryZoneIdForZoneId(zoneId)
        if storyZoneId and storyZoneId > 0 and storyZoneId ~= zoneId then
            local storyBreakdown, storyCompleted, storyAvailable, storyPercent = self:GetCompletionBreakdown(storyZoneId)
            if storyAvailable > 0 then
                breakdown = storyBreakdown
                completedTotal = storyCompleted
                availableTotal = storyAvailable
                percent = storyPercent
                progressZoneId = storyZoneId
            end
        end
    end

    return breakdown, completedTotal, availableTotal, percent, progressZoneId
end


-- 2.6.14: Match the native HUD lifecycle. Tamriel Tomes is visible on the
-- HUD/HUD-UI scenes, but disappears when the world map (M), game menu (ESC) or
-- another full-screen scene takes over. The Skyshard goal now follows exactly
-- that scene rule instead of being an always-on top-level overlay.
function TPM:IsStatisticsAllowedInCurrentScene()
    local currentScene = SCENE_MANAGER:GetCurrentScene()
    if not currentScene then return true end
    return currentScene == _G.HUD_SCENE
        or currentScene == _G.HUD_UI_SCENE
        or currentScene == _G.WORLD_MAP_SCENE
        or currentScene == _G.GAMEPAD_WORLD_MAP_SCENE
end

function TPM:RefreshStandaloneStatisticsSceneVisibility()
    local window = self.statisticsWindow
    if not window or not self.statisticsOpenedStandalone then return end

    -- 2.6.34: ESC should close a standalone journal instead of merely hiding it.
    -- Compare both the scene object and its name for compatibility across UI revisions.
    local currentScene = SCENE_MANAGER:GetCurrentScene()
    local currentSceneName = currentScene and tostring(currentScene:GetName() or "") or ""
    local lowerSceneName = zo_strlower(tostring(currentSceneName or ""))
    if currentScene == _G.GAME_MENU_SCENE or string.find(lowerSceneName, "gamemenu", 1, true) then
        self:HideStatisticsWindow()
        return
    end
    -- When ESC exits camera UI mode directly (HUD-UI -> HUD), close TPM as well.
    if self.statisticsOwnsUIMode then
        local active = IsGameCameraUIModeActive()
        local now = GetFrameTimeMilliseconds() or 0
        local openedAt = tonumber(self.statisticsUIModeOpenedAt) or 0
        if active == false and (openedAt <= 0 or now - openedAt > 200) then
            self:HideStatisticsWindow()
            return
        end
    end

    local allowed = self:IsStatisticsAllowedInCurrentScene()
    if allowed then
        if self.statisticsTemporarilyHiddenForScene then
            self.statisticsTemporarilyHiddenForScene = false
            window:SetHidden(false)
            self:RefreshStatisticsWindow()
            if self.economyDetailTemporarilyHiddenForScene and self.economyDetailWindow then
                self.economyDetailTemporarilyHiddenForScene = false
                self.economyDetailWindow:SetHidden(false)
                self:RefreshEconomyDetailWindow()
            end
        end
    elseif not window:IsHidden() then
        self.statisticsTemporarilyHiddenForScene = true
        self:HideStatisticsHoverTooltips()
        self:HideStatisticsFocusDropdown()
        -- 2.6.34: HideStatisticsHoverTooltips already hides the achievement tooltip.
        -- Do not call the later local TPM_HideAchievementTooltip here; it is nil at this point in Lua load order.
        if self.economyDetailWindow and not self.economyDetailWindow:IsHidden() then
            self.economyDetailTemporarilyHiddenForScene = true
            self.economyDetailWindow:SetHidden(true)
        end
        window:SetHidden(true)
    end
end

function TPM:IsSkyshardGoalHudSceneVisible()
    -- HUD elements are visible only while HUD/HUD-UI is the current scene.
    local currentScene = SCENE_MANAGER:GetCurrentScene()
    return currentScene == HUD_SCENE or currentScene == HUD_UI_SCENE
end

-- Register the global release event only while TPM is actively dragging or
-- resizing something. This keeps the addon idle during unrelated mouse input
-- while still safely ending interactions when the cursor leaves a control.
function TPM:HasActivePointerInteraction()
    return self.skyshardGoalDragging == true
        or self.skyshardGoalResizing == true
        or self.alliancePlannerMapDragging == true
        or self.questRewardResizing == true
        or self.questRewardMoving == true
        or self.statisticsWindowMoving == true
end

function TPM:UpdateGlobalMouseUpRegistration()
    if not EVENT_MANAGER or not EVENT_GLOBAL_MOUSE_UP then return end
    local namespace = ADDON_NAME .. "GlobalMouseUp"
    local shouldRegister = self:HasActivePointerInteraction()

    if shouldRegister and self.globalMouseUpRegistered ~= true then
        EVENT_MANAGER:RegisterForEvent(namespace, EVENT_GLOBAL_MOUSE_UP, function(eventCode, button)
            TPM:HandleGlobalMouseUp(eventCode, button)
        end)
        self.globalMouseUpRegistered = true
    elseif not shouldRegister and self.globalMouseUpRegistered == true then
        EVENT_MANAGER:UnregisterForEvent(namespace, EVENT_GLOBAL_MOUSE_UP)
        self.globalMouseUpRegistered = false
    end
end

function TPM:HandleGlobalMouseUp(_, button)
    if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
    if self.skyshardGoalDragging then self:StopSkyshardGoalMove() end
    if self.skyshardGoalResizing then self:StopSkyshardGoalResize() end
    if self.alliancePlannerMapDragging then self:EndAlliancePlannerMapPan() end
    if self.questRewardResizing then self:StopResizingQuestRewardWindow() end
    if self.questRewardMoving then self:StopMovingQuestRewardWindow() end
    if self.statisticsWindowMoving then self:StopMovingStatisticsWindow() end
    self:UpdateGlobalMouseUpRegistration()
end

-- 2.6.13: Personal Skyshard HUD renderer rebuilt around a true top-level
-- window. Earlier test builds used a normal GuiRoot child and tried to anchor
-- to ESO's quest tracker container. On current clients that container can have
-- scene-dependent geometry/visibility, so an enabled goal could exist but never
-- become effectively visible. The goal now owns its own top-level window and
-- uses an independently resolved HUD anchor.
function TPM:StopSkyshardGoalMove()
    if self.skyshardGoalDragSurface then
        self.skyshardGoalDragSurface:SetHandler("OnUpdate", nil)
    end
    self.skyshardGoalDragging = false
    self:UpdateGlobalMouseUpRegistration()
end

function TPM:StopSkyshardGoalResize()
    if self.skyshardGoalResizeGrip then
        self.skyshardGoalResizeGrip:SetHandler("OnUpdate", nil)
    end
    self.skyshardGoalResizing = false
    self:UpdateGlobalMouseUpRegistration()
end

function TPM:CreateSkyshardGoalWidget()
    if self.skyshardGoalWidget then return end
    local widgetName = ADDON_NAME .. "SkyshardGoalHUD"
    local widget = WINDOW_MANAGER:CreateTopLevelWindow(widgetName)

    local savedWidth = self.saved and tonumber(self.saved.skyshardGoalCustomWidth) or nil
    local savedHeight = self.saved and tonumber(self.saved.skyshardGoalCustomHeight) or nil
    local initialWidth = Clamp(savedWidth or 360, 230, 760)
    local initialHeight = Clamp(savedHeight or 60, 60, 220)
    widget:SetDimensions(initialWidth, initialHeight)
    widget:SetMouseEnabled(false)
    if widget.SetMovable then widget:SetMovable(false) end
    if widget.SetClampedToScreen then widget:SetClampedToScreen(true) end
    if widget.SetAlpha then widget:SetAlpha(1) end
    if widget.SetDrawTier then widget:SetDrawTier(DT_HIGH) end
    if widget.SetDrawLayer then widget:SetDrawLayer(DL_OVERLAY) end
    if widget.SetDrawLevel then widget:SetDrawLevel(200) end

    -- 2.6.25: The HUD itself remains completely transparent in normal play.
    -- The golden editing frame appears only while the gear button is active.
    local editBackdrop = WINDOW_MANAGER:CreateControl(widgetName .. "EditBackdrop", widget, CT_BACKDROP)
    editBackdrop:SetAnchorFill(widget)
    editBackdrop:SetCenterColor(0.06, 0.05, 0.02, 0.16)
    editBackdrop:SetEdgeColor(1.00, 0.82, 0.24, 0.98)
    editBackdrop:SetEdgeTexture(nil, 1, 1, 2)
    editBackdrop:SetMouseEnabled(false)
    editBackdrop:SetHidden(true)

    local title = WINDOW_MANAGER:CreateControl(widgetName .. "Title", widget, CT_LABEL)
    title:SetAnchor(TOPLEFT, widget, TOPLEFT, 0, 0)
    title:SetAnchor(TOPRIGHT, widget, TOPRIGHT, 0, 0)
    title:SetHeight(24)
    title:SetFont("$(BOLD_FONT)|19|soft-shadow-thick")
    title:SetColor(1.00, 0.82, 0.24, 1)
    title:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    title:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    title:SetMouseEnabled(false)

    local progress = WINDOW_MANAGER:CreateControl(widgetName .. "Progress", widget, CT_LABEL)
    -- 2.6.28: Match ESO's native tracker indentation. The white detail line
    -- begins slightly to the right of the yellow title/icon row, just like the
    -- Tamriel Tomes objective text beneath its yellow heading.
    progress:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 36, -1)
    progress:SetAnchor(TOPRIGHT, title, BOTTOMRIGHT, 28, -1)
    progress:SetHeight(23)
    progress:SetFont("$(BOLD_FONT)|17|soft-shadow-thick")
    progress:SetColor(1, 1, 1, 1)
    progress:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    progress:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    progress:SetMouseEnabled(false)

    -- Most of the frame moves the HUD. The lower-right corner is deliberately
    -- left free for the resize grip so moving and resizing can never compete.
    local dragSurface = WINDOW_MANAGER:CreateControl(widgetName .. "DragSurface", widget, CT_CONTROL)
    dragSurface:SetAnchor(TOPLEFT, widget, TOPLEFT, 0, 0)
    dragSurface:SetAnchor(BOTTOMRIGHT, widget, BOTTOMRIGHT, -20, -20)
    dragSurface:SetMouseEnabled(false)
    if dragSurface.SetDrawLayer then dragSurface:SetDrawLayer(DL_OVERLAY) end
    if dragSurface.SetDrawLevel then dragSurface:SetDrawLevel(15000) end

    local resizeGrip = WINDOW_MANAGER:CreateControl(widgetName .. "ResizeGrip", widget, CT_BACKDROP)
    resizeGrip:SetDimensions(18, 18)
    resizeGrip:SetAnchor(BOTTOMRIGHT, widget, BOTTOMRIGHT, -2, -2)
    resizeGrip:SetCenterColor(0.78, 0.59, 0.16, 0.88)
    resizeGrip:SetEdgeColor(1.00, 0.86, 0.30, 1)
    resizeGrip:SetEdgeTexture(nil, 1, 1, 1)
    resizeGrip:SetMouseEnabled(false)
    resizeGrip:SetHidden(true)
    if resizeGrip.SetDrawLayer then resizeGrip:SetDrawLayer(DL_OVERLAY) end
    if resizeGrip.SetDrawLevel then resizeGrip:SetDrawLevel(16000) end

    -- Three tiny dark marks make the corner read as a resize grip without
    -- relying on a Unicode arrow that may be missing in one of ESO's fonts.
    for i = 1, 3 do
        local mark = WINDOW_MANAGER:CreateControl(nil, resizeGrip, CT_BACKDROP)
        local size = 3 + (i - 1) * 3
        mark:SetDimensions(size, 2)
        mark:SetAnchor(BOTTOMRIGHT, resizeGrip, BOTTOMRIGHT, -2, -(2 + (i - 1) * 4))
        mark:SetCenterColor(0.08, 0.07, 0.04, 0.95)
        mark:SetEdgeColor(0, 0, 0, 0)
        mark:SetMouseEnabled(false)
    end

    self.skyshardGoalWidget = widget
    self.skyshardGoalZoneLabel = title
    self.skyshardGoalProgressLabel = progress
    self.skyshardGoalEditBackdrop = editBackdrop
    self.skyshardGoalDragSurface = dragSurface
    self.skyshardGoalResizeGrip = resizeGrip
    self.skyshardGoalTomesAnchor = nil
    self.skyshardGoalLastAnchorScan = 0

    local function StopMove()
        TPM:StopSkyshardGoalMove()
    end

    local function StopResize()
        TPM:StopSkyshardGoalResize()
    end

    widget:SetHandler("OnHide", function()
        StopMove()
        StopResize()
    end)

    dragSurface:SetHandler("OnMouseDown", function(_, button)
        if TPM.skyshardGoalEditMode ~= true or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        StopResize()
        if type(GetUIMousePosition) ~= "function" then return end
        local mouseX, mouseY = GetUIMousePosition()
        local left = type(widget.GetLeft) == "function" and tonumber(widget:GetLeft()) or nil
        local top = type(widget.GetTop) == "function" and tonumber(widget:GetTop()) or nil
        mouseX, mouseY = tonumber(mouseX), tonumber(mouseY)
        if not mouseX or not mouseY or not left or not top then return end

        TPM.skyshardGoalDragging = true
        TPM:UpdateGlobalMouseUpRegistration()
        TPM.skyshardGoalDragStartMouseX = mouseX
        TPM.skyshardGoalDragStartMouseY = mouseY
        TPM.skyshardGoalDragStartX = left
        TPM.skyshardGoalDragStartY = top

        dragSurface:SetHandler("OnUpdate", function()
            if TPM.skyshardGoalDragging ~= true or TPM.skyshardGoalEditMode ~= true then
                dragSurface:SetHandler("OnUpdate", nil)
                return
            end
            if type(GetUIMousePosition) ~= "function" then return end
            local currentX, currentY = GetUIMousePosition()
            currentX, currentY = tonumber(currentX), tonumber(currentY)
            if not currentX or not currentY then return end

            local x = (tonumber(TPM.skyshardGoalDragStartX) or 0) + currentX - (tonumber(TPM.skyshardGoalDragStartMouseX) or currentX)
            local y = (tonumber(TPM.skyshardGoalDragStartY) or 0) + currentY - (tonumber(TPM.skyshardGoalDragStartMouseY) or currentY)
            local rootW = type(GuiRoot.GetWidth) == "function" and (tonumber(GuiRoot:GetWidth()) or 0) or 0
            local rootH = type(GuiRoot.GetHeight) == "function" and (tonumber(GuiRoot:GetHeight()) or 0) or 0
            local widgetW = tonumber(widget:GetWidth()) or 360
            local widgetH = tonumber(widget:GetHeight()) or 60
            if rootW > 0 then x = Clamp(x, 0, math.max(0, rootW - widgetW)) end
            if rootH > 0 then y = Clamp(y, 0, math.max(0, rootH - widgetH)) end
            widget:ClearAnchors()
            widget:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
            TPM.skyshardGoalAnchorMode = "custom_edit_live"
        end)
    end)

    dragSurface:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then StopMove() end
    end)

    resizeGrip:SetHandler("OnMouseDown", function(_, button)
        if TPM.skyshardGoalEditMode ~= true or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        StopMove()
        if type(GetUIMousePosition) ~= "function" then return end
        local mouseX, mouseY = GetUIMousePosition()
        mouseX, mouseY = tonumber(mouseX), tonumber(mouseY)
        if not mouseX or not mouseY then return end
        TPM.skyshardGoalResizing = true
        TPM:UpdateGlobalMouseUpRegistration()
        TPM.skyshardGoalResizeStartMouseX = mouseX
        TPM.skyshardGoalResizeStartMouseY = mouseY
        TPM.skyshardGoalResizeStartWidth = tonumber(widget:GetWidth()) or 360
        TPM.skyshardGoalResizeStartHeight = tonumber(widget:GetHeight()) or 60

        resizeGrip:SetHandler("OnUpdate", function()
            if TPM.skyshardGoalResizing ~= true or TPM.skyshardGoalEditMode ~= true then
                resizeGrip:SetHandler("OnUpdate", nil)
                return
            end
            local currentX, currentY = GetUIMousePosition()
            currentX, currentY = tonumber(currentX), tonumber(currentY)
            if not currentX or not currentY then return end
            local width = (tonumber(TPM.skyshardGoalResizeStartWidth) or 360) + currentX - (tonumber(TPM.skyshardGoalResizeStartMouseX) or currentX)
            local height = (tonumber(TPM.skyshardGoalResizeStartHeight) or 60) + currentY - (tonumber(TPM.skyshardGoalResizeStartMouseY) or currentY)
            local left = tonumber(widget:GetLeft()) or 0
            local top = tonumber(widget:GetTop()) or 0
            local rootW = type(GuiRoot.GetWidth) == "function" and (tonumber(GuiRoot:GetWidth()) or 0) or 0
            local rootH = type(GuiRoot.GetHeight) == "function" and (tonumber(GuiRoot:GetHeight()) or 0) or 0
            local maxWidth = rootW > 0 and math.max(230, rootW - left) or 760
            local maxHeight = rootH > 0 and math.max(60, rootH - top) or 220
            width = Clamp(width, 230, math.min(760, maxWidth))
            height = Clamp(height, 60, math.min(220, maxHeight))
            widget:SetDimensions(math.floor(width + 0.5), math.floor(height + 0.5))
        end)
    end)

    resizeGrip:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then StopResize() end
    end)

    self:UpdateSkyshardGoalAnchor(true)
    widget:SetHidden(true)
end

local function TPM_SkyshardStripControlText(text)
    text = tostring(text or "")
    text = string.gsub(text, "|c%x%x%x%x%x%x", "")
    text = string.gsub(text, "|r", "")
    text = zo_strlower(text)
    return text
end

local function TPM_IsUsableHudAnchorControl(control)
    if not control or not GuiRoot or control == GuiRoot then return false end
    if type(control.GetTop) ~= "function" or type(control.GetRight) ~= "function" then return false end

    local top = tonumber(control:GetTop())
    local right = tonumber(control:GetRight())
    if not top or not right then return false end

    local rootWidth = type(GuiRoot.GetWidth) == "function" and tonumber(GuiRoot:GetWidth()) or 0
    local rootHeight = type(GuiRoot.GetHeight) == "function" and tonumber(GuiRoot:GetHeight()) or 0
    if right <= 0 or top < 0 then return false end
    if rootWidth > 0 and right > rootWidth + 5 then return false end
    if rootHeight > 0 and top > rootHeight + 5 then return false end

    -- 2.6.15: A control can report itself as visible while one of its scene
    -- parents is hidden. Walk the parent chain so an inactive duplicate tracker
    -- can never be selected as the anchor for the Skyshard HUD.
    local current = control
    for _ = 1, 12 do
        if type(current.IsHidden) == "function" and current:IsHidden() then return false end
        if type(current.GetParent) ~= "function" then break end
        local parent = current:GetParent()
        if not parent or parent == current then break end
        if parent == GuiRoot then break end
        current = parent
    end
    return true
end

local function TPM_IsTamrielTomesHudText(text)
    text = TPM_SkyshardStripControlText(text)
    if text == "" then return false end
    return string.find(text, "tamrielfoliant", 1, true) ~= nil
        or string.find(text, "tamriel tome", 1, true) ~= nil
        or string.find(text, "tamriel-tome", 1, true) ~= nil
        or string.find(text, "tomes de tamriel", 1, true) ~= nil
        or string.find(text, "tome de tamriel", 1, true) ~= nil
        or (string.find(text, "том", 1, true) ~= nil and string.find(text, "тамри", 1, true) ~= nil)
end

local function TPM_GetControlText(control)
    local controlType = type(control)
    if (controlType ~= "table" and controlType ~= "userdata") or type(control.GetText) ~= "function" then return "" end
    return tostring(control:GetText() or "")
end

local function TPM_GetNativeHudTrackerContainer(value)
    local valueType = type(value)
    if valueType ~= "table" and valueType ~= "userdata" then return nil end

    -- Native ZO_HUDTracker_Base objects expose owner.container/headerLabel.
    -- Resolve either an owner object or a control whose owner points at one.
    local objects = { value }
    local owner = value.owner
    if owner and owner ~= value then objects[#objects + 1] = owner end

    for _, object in ipairs(objects) do
        local container = object.container
        local header = object.headerLabel
        if header and TPM_IsTamrielTomesHudText(TPM_GetControlText(header)) then
            -- 2.6.17: Return the actual visible title label first. The native
            -- tracker container can span the complete right-hand tracker column
            -- (quests + timed activities + Tamriel Tomes). Anchoring Position 1
            -- to that container placed the Skyshard goal far above the Tomes.
            if TPM_IsUsableHudAnchorControl(header) then return header end
            if TPM_IsUsableHudAnchorControl(container) then return container end
        end
    end

    if TPM_IsTamrielTomesHudText(TPM_GetControlText(value)) then
        -- If the scanned control itself is the visible Tamriel Tomes label,
        -- keep that exact control as the anchor instead of climbing to a large
        -- shared tracker container.
        if TPM_IsUsableHudAnchorControl(value) then return value end
        if owner and TPM_IsUsableHudAnchorControl(owner.container) then return owner.container end
    end
    return nil
end

function TPM:FindTamrielTomesHudAnchor(force)
    if not GuiRoot then return nil end

    if not force and TPM_IsUsableHudAnchorControl(self.skyshardGoalTomesAnchor) then
        return self.skyshardGoalTomesAnchor
    end

    local nowMs = tonumber(GetFrameTimeMilliseconds()) or 0

    -- Prefer ESO's native HUD tracker registry. This is more reliable than
    -- searching arbitrary globals and lets us anchor to the complete native
    -- Tamriel Tomes tracker container when it is registered there.
    if HUD_TRACKER_MANAGER and type(HUD_TRACKER_MANAGER.GetTrackers) == "function" then
        local trackers = HUD_TRACKER_MANAGER:GetTrackers()
        if type(trackers) == "table" then
            for tracker in pairs(trackers) do
                local anchor = TPM_GetNativeHudTrackerContainer(tracker)
                if TPM_IsUsableHudAnchorControl(anchor) then
                    self.skyshardGoalTomesAnchor = anchor
                    return anchor
                end
            end
        end
    end

    -- SECURITY NOTE (2.6.16): never enumerate _G here. ESO exposes private API
    -- functions in the global table (for example GetMarketProductInfo). Merely
    -- iterating over _G from addon code can cross the secure/private boundary and
    -- trigger a UI error before our filtering code even runs. The native tracker
    -- registry above plus the visible control-tree scan below are safe discovery
    -- paths and are sufficient for locating the Tamriel Tomes HUD block.

    -- The full control-tree scan can visit thousands of controls. If it failed,
    -- throttle only this expensive fallback for 60 seconds; the cheap native
    -- tracker-registry lookup above still runs on every normal refresh.
    if not force and nowMs > 0 and (nowMs - (tonumber(self.skyshardGoalLastAnchorScan) or 0)) < 60000 then return nil end
    self.skyshardGoalLastAnchorScan = nowMs

    -- Fallback: scan the visible UI tree and inspect native tracker owners.
    local queue = { { control = GuiRoot, depth = 0 } }
    local index, visited = 1, 0
    while index <= #queue and visited < 12000 do
        local item = queue[index]
        index = index + 1
        local control, depth = item.control, item.depth
        visited = visited + 1

        if control ~= GuiRoot then
            local ownerAnchor = TPM_GetNativeHudTrackerContainer(control)
            if TPM_IsUsableHudAnchorControl(ownerAnchor) then
                self.skyshardGoalTomesAnchor = ownerAnchor
                return ownerAnchor
            end

            if TPM_IsUsableHudAnchorControl(control) then
                local name = ""
                if type(control.GetName) == "function" then
                    name = zo_strlower(tostring(control:GetName() or ""))
                end
                local textLooksLikeTomes = TPM_IsTamrielTomesHudText(TPM_GetControlText(control))
                local nameLooksLikeTomes = string.find(name, "tamrieltome", 1, true) ~= nil
                    or string.find(name, "tamriel_tome", 1, true) ~= nil
                if textLooksLikeTomes or (nameLooksLikeTomes and type(control.GetText) == "function") then
                    self.skyshardGoalTomesAnchor = control
                    return control
                end
            end
        end

        if depth < 14 and control and type(control.GetNumChildren) == "function" and type(control.GetChild) == "function" then
            local count = math.min(tonumber(control:GetNumChildren()) or 0, 900)
            for childIndex = 1, count do
                local child = control:GetChild(childIndex)
                if child then queue[#queue + 1] = { control = child, depth = depth + 1 } end
            end
        end
    end

    self.skyshardGoalTomesAnchor = nil
    return nil
end

local function TPM_GetTamrielTomesBlockAnchor(titleControl)
    if not TPM_IsUsableHudAnchorControl(titleControl) then return titleControl end

    -- If this is already a native HUD tracker container, do not climb into the
    -- shared tracker column. That is what caused Position 1 to land far above
    -- or around the middle of the screen in earlier builds.
    local owner = titleControl.owner
    if owner and owner.container == titleControl then return titleControl end

    local current = titleControl
    -- Pick the FIRST compact parent large enough to contain title + objective,
    -- instead of the highest matching parent in the whole HUD hierarchy.
    for _ = 1, 8 do
        if type(current.GetParent) ~= "function" then break end
        local parent = current:GetParent()
        if not parent or parent == GuiRoot then break end
        if TPM_IsUsableHudAnchorControl(parent) then
            local width = type(parent.GetWidth) == "function" and tonumber(parent:GetWidth()) or 0
            local height = type(parent.GetHeight) == "function" and tonumber(parent:GetHeight()) or 0
            if width >= 150 and width <= 700 and height >= 45 and height <= 220 then
                return parent
            end
        end
        current = parent
    end
    return titleControl
end

local function TPM_GetRenderedLabelBounds(control)
    if not TPM_IsUsableHudAnchorControl(control) then return nil, nil end
    local left = tonumber(control:GetLeft())
    local width = tonumber(control:GetWidth())
    if not left then return nil, nil end

    local textWidth = nil
    if type(control.GetTextWidth) == "function" then
        textWidth = tonumber(control:GetTextWidth())
    end
    if not textWidth or textWidth <= 0 or not width or width <= 0 then
        local right = type(control.GetRight) == "function" and tonumber(control:GetRight()) or nil
        return left, right or (left + math.max(0, width or 0))
    end

    local alignment = nil
    if type(control.GetHorizontalAlignment) == "function" then
        alignment = control:GetHorizontalAlignment()
    end

    local renderedLeft = left
    if alignment == TEXT_ALIGN_RIGHT then
        renderedLeft = left + math.max(0, width - textWidth)
    elseif alignment == TEXT_ALIGN_CENTER then
        renderedLeft = left + math.max(0, (width - textWidth) * 0.5)
    end
    return renderedLeft, renderedLeft + textWidth
end

local function TPM_GetRenderedLabelLeft(control)
    local left = TPM_GetRenderedLabelBounds(control)
    return left
end

local function TPM_GetRenderedLabelRight(control)
    local _, right = TPM_GetRenderedLabelBounds(control)
    return right
end

function TPM:UpdateSkyshardGoalAnchor(forceScan)
    local widget = self.skyshardGoalWidget
    if not widget or not GuiRoot then return end

    local customLayout = self.saved and self.saved.skyshardGoalCustomPosition == true
    local width = customLayout and tonumber(self.saved.skyshardGoalCustomWidth) or 360
    local height = customLayout and tonumber(self.saved.skyshardGoalCustomHeight) or 60
    widget:SetDimensions(Clamp(width or 360, 230, 760), Clamp(height or 60, 60, 220))
    widget:ClearAnchors()

    -- A manually dragged position takes precedence over the automatic Tamriel
    -- Tomes slots. Selecting position 1/2 in settings resets this override.
    if self.saved and self.saved.skyshardGoalCustomPosition == true then
        local customX = tonumber(self.saved.skyshardGoalCustomX)
        local customY = tonumber(self.saved.skyshardGoalCustomY)
        if customX and customY then
            if self.skyshardGoalZoneLabel then self.skyshardGoalZoneLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT) end
            if self.skyshardGoalProgressLabel then self.skyshardGoalProgressLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT) end
            widget:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, customX, customY)
            self.skyshardGoalAnchorMode = "custom_saved"
            return
        end
    end

    local position = self.saved and tonumber(self.saved.skyshardGoalPosition) or 1
    position = position == 2 and 2 or 1

    local tomeTitle = self:FindTamrielTomesHudAnchor(forceScan == true)
    if TPM_IsUsableHudAnchorControl(tomeTitle) then
        -- 2.6.20: The screenshots exposed the exact geometry bug. The native
        -- Tamriel Tomes title label is a wide right/centre-aligned control. Its
        -- calculated rendered LEFT edge can therefore sit ~100 px left of the
        -- actual tracker column. Align our 360 px goal by the rendered RIGHT
        -- edge instead, and right-align both goal labels. This makes the visible
        -- text share the same right edge as Tamriel Tomes regardless of the
        -- hidden label-control width.
        local visualRight = tonumber(TPM_GetRenderedLabelRight(tomeTitle))
        local tomeTop = tonumber(tomeTitle:GetTop())
        if self.skyshardGoalZoneLabel then self.skyshardGoalZoneLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT) end
        if self.skyshardGoalProgressLabel then self.skyshardGoalProgressLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT) end
        if position == 2 then
            local tomeBlock = TPM_GetTamrielTomesBlockAnchor(tomeTitle)
            local blockBottom = tonumber(tomeBlock:GetBottom())
            if visualRight and blockBottom then
                widget:SetAnchor(TOPRIGHT, GuiRoot, TOPLEFT, visualRight, blockBottom + 8)
            else
                widget:SetAnchor(TOPRIGHT, tomeBlock, BOTTOMRIGHT, 0, 8)
            end
        else
            if visualRight and tomeTop then
                widget:SetAnchor(BOTTOMRIGHT, GuiRoot, TOPLEFT, visualRight, tomeTop - 4)
            else
                widget:SetAnchor(BOTTOMRIGHT, tomeTitle, TOPRIGHT, 0, -4)
            end
        end
        self.skyshardGoalAnchorMode = "tamriel_tomes_visual_right_pos" .. tostring(position)
        return
    end

    -- Last-resort slots. Position 1 now sits much closer to the usual Tamriel
    -- Tomes location instead of the old overly-high fallback.
    if self.skyshardGoalZoneLabel then self.skyshardGoalZoneLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT) end
    if self.skyshardGoalProgressLabel then self.skyshardGoalProgressLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT) end
    if position == 2 then
        widget:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, -42, -90)
    else
        widget:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, -42, -155)
    end
    self.skyshardGoalAnchorMode = "screen_fallback_pos" .. tostring(position)
end

function TPM:GetActiveProgressGoalCategoryType()
    if not self.saved then return nil end
    local value = self.saved.progressGoalCategoryType
    if value == nil or value == false or value == "" then
        return self.saved.skyshardGoalEnabled == true and _G.ZONE_COMPLETION_TYPE_SKYSHARDS or nil
    end
    local numeric = tonumber(value)
    if numeric ~= nil then return numeric end
    return value
end

function TPM:IsProgressGoalCategoryActive(completionType)
    if not self.saved or self.saved.skyshardGoalEnabled ~= true or completionType == nil then return false end
    return tostring(self:GetActiveProgressGoalCategoryType()) == tostring(completionType)
end

function TPM:GetProgressGoalCategoryDisplayName(completionType)
    if completionType == SIDE_QUEST_CATEGORY_KEY then return self:L("CAT_SIDE_QUESTS") end
    if completionType == CROWN_QUEST_CATEGORY_KEY then return self:L("CAT_CROWN_QUESTS") end
    if completionType == ZONE_STABLE_MOUNT_CATEGORY_KEY then return self:L("STAT_ZONE_STABLE_MOUNT") end
    return self:GetCompletionTypeName(completionType)
end

function TPM:GetProgressGoalCategoryIconTexture(completionType)
    -- 2.6.29: Use ESO's own Zone Stories completion icons in the HUD instead
    -- of TPM's custom category artwork. This is the same native icon resolver
    -- used by the game's Zone Guide / Zone Stories activity-completion tiles.
    local manager = _G.ZO_ZoneStories_Manager
    if type(completionType) == "number" and type(manager) == "table" and type(manager.GetCompletionTypeIcon) == "function" then
        local texture = manager.GetCompletionTypeIcon(completionType)
        if type(texture) == "string" and texture ~= "" then return texture end
    end

    -- Safe direct native fallbacks in case the manager has not initialized yet.
    local nativeIcons =
    {
        [ZONE_COMPLETION_TYPE_PRIORITY_QUESTS] = "EsoUI/Art/ZoneStories/completionTypeIcon_priorityQuest.dds",
        [ZONE_COMPLETION_TYPE_POINTS_OF_INTEREST] = "EsoUI/Art/ZoneStories/completionTypeIcon_pointOfInterest.dds",
        [ZONE_COMPLETION_TYPE_WAYSHRINES] = "EsoUI/Art/ZoneStories/completionTypeIcon_wayshrine.dds",
        [ZONE_COMPLETION_TYPE_DELVES] = "EsoUI/Art/ZoneStories/completionTypeIcon_delve.dds",
        [ZONE_COMPLETION_TYPE_GROUP_DELVES] = "EsoUI/Art/ZoneStories/completionTypeIcon_groupDelve.dds",
        [ZONE_COMPLETION_TYPE_SKYSHARDS] = "EsoUI/Art/ZoneStories/completionTypeIcon_skyshard.dds",
        [ZONE_COMPLETION_TYPE_WORLD_EVENTS] = "EsoUI/Art/ZoneStories/completionTypeIcon_worldEvents.dds",
        [ZONE_COMPLETION_TYPE_GROUP_BOSSES] = "EsoUI/Art/ZoneStories/completionTypeIcon_groupBoss.dds",
        [ZONE_COMPLETION_TYPE_STRIKING_LOCALES] = "EsoUI/Art/ZoneStories/completionTypeIcon_strikingLocales.dds",
        [ZONE_COMPLETION_TYPE_MAGES_GUILD_BOOKS] = "EsoUI/Art/ZoneStories/completionTypeIcon_lorebooks.dds",
        [ZONE_COMPLETION_TYPE_MUNDUS_STONES] = "EsoUI/Art/ZoneStories/completionTypeIcon_mundusStone.dds",
        [ZONE_COMPLETION_TYPE_PUBLIC_DUNGEONS] = "EsoUI/Art/ZoneStories/completionTypeIcon_publicDungeon.dds",
        [ZONE_COMPLETION_TYPE_SET_STATIONS] = "EsoUI/Art/ZoneStories/completionTypeIcon_setStation.dds",
    }
    return nativeIcons[completionType] or STATISTICS_CATEGORY_ICON_TEXTURES[completionType] or "NagaMapaCompleto/art/cat_quests.dds"
end

function TPM:GetProgressGoalHudTitle(completionType)
    local name = self:GetProgressGoalCategoryDisplayName(completionType)
    local texture = self:GetProgressGoalCategoryIconTexture(completionType)
    -- ESO labels support inline textures. Keeping the icon inside the title
    -- makes it follow both the automatic right alignment near Tamriel Tomes and
    -- the user's custom left-aligned HUD position without separate anchor math.
    return string.format("|t22:22:%s|t  %s", texture, name)
end

function TPM:UpdateSkyshardGoalRefreshTimer()
    if not EVENT_MANAGER then return end
    local namespace = ADDON_NAME .. "SkyshardGoalHudRefresh"
    local shouldRun = self.saved and self.saved.skyshardGoalEnabled == true

    if shouldRun and self.skyshardGoalRefreshTimerRegistered ~= true then
        EVENT_MANAGER:RegisterForUpdate(namespace, 1500, function()
            if TPM.saved and TPM.saved.skyshardGoalEnabled == true then
                TPM:RefreshSkyshardGoalWidget()
            else
                TPM:UpdateSkyshardGoalRefreshTimer()
            end
        end)
        self.skyshardGoalRefreshTimerRegistered = true
    elseif not shouldRun and self.skyshardGoalRefreshTimerRegistered == true then
        EVENT_MANAGER:UnregisterForUpdate(namespace)
        self.skyshardGoalRefreshTimerRegistered = false
    end
end

function TPM:ToggleSkyshardGoalWidget(completionType)
    if not self.saved then return end
    local targetType = completionType or self:GetActiveProgressGoalCategoryType() or _G.ZONE_COMPLETION_TYPE_SKYSHARDS
    local sameActive = self.saved.skyshardGoalEnabled == true and tostring(self:GetActiveProgressGoalCategoryType()) == tostring(targetType)
    if sameActive then
        self.saved.skyshardGoalEnabled = false
    else
        self.saved.progressGoalCategoryType = targetType
        self.saved.skyshardGoalEnabled = true
    end
    if self.saved.skyshardGoalEnabled ~= true and self.skyshardGoalEditMode == true then
        self:SetSkyshardGoalEditMode(false, false)
    end
    self:UpdateSkyshardGoalRefreshTimer()
    self:RefreshSkyshardGoalWidget()
    if self.statisticsWindow and not self.statisticsWindow:IsHidden() then
        self:RefreshStatisticsWindow()
    end
end

local function TPM_TryZoneStoriesSkyshardProgress(zoneId)
    zoneId = tonumber(zoneId) or 0
    if zoneId <= 0 then return nil end

    local completed, total = TPM:GetZoneCompletionActivityProgress(zoneId, ZONE_COMPLETION_TYPE_SKYSHARDS)
    if total > 0 then
        return completed, total
    end
    return nil
end

function TPM:GetCurrentSkyshardGoalData()
    local activeType = self:GetActiveProgressGoalCategoryType() or _G.ZONE_COMPLETION_TYPE_SKYSHARDS

    if activeType == CROWN_QUEST_CATEGORY_KEY then
        local crownStats = self:GetCrownQuestStatistics()
        if crownStats then
            return {
                zoneId = 0,
                name = self:L("TAMRIEL_TOTAL"),
                completed = crownStats.completed or 0,
                total = crownStats.total or 0,
                countText = crownStats.countText,
                informational = crownStats.informational,
                completionType = activeType,
                categoryName = crownStats.name or self:GetProgressGoalCategoryDisplayName(activeType),
            }
        end
    end

    local sourceZoneIds, seenSources = {}, {}
    local function AddSource(zoneId)
        zoneId = tonumber(zoneId) or 0
        if zoneId <= 0 or seenSources[zoneId] then return end
        seenSources[zoneId] = true
        sourceZoneIds[#sourceZoneIds + 1] = zoneId
    end

    AddSource(ZO_ExplorationUtils_GetPlayerCurrentZoneId())
    local worldZoneId = GetUnitWorldPosition("player")
    AddSource(worldZoneId)
    local rawWorldZoneId = GetUnitRawWorldPosition("player")
    AddSource(rawWorldZoneId)

    local currentZoneId = self:GetCurrentPlayerZoneIdentity()
    AddSource(currentZoneId)
    if #sourceZoneIds == 0 then return nil end

    local candidates, seenCandidates = {}, {}
    local function AddCandidate(zoneId)
        zoneId = tonumber(zoneId) or 0
        if zoneId <= 0 or seenCandidates[zoneId] then return end
        seenCandidates[zoneId] = true
        candidates[#candidates + 1] = zoneId
    end

    local function AddExpanded(zoneId)
        zoneId = tonumber(zoneId) or 0
        if zoneId <= 0 then return end
        local current = zoneId
        for _ = 1, 8 do
            if current <= 0 then break end
            AddCandidate(GetZoneStoryZoneIdForZoneId(current))
            AddCandidate(current)
            local parentZoneId = tonumber(GetParentZoneId(current)) or 0
            if parentZoneId <= 0 or parentZoneId == current then break end
            current = parentZoneId
        end
    end

    for _, zoneId in ipairs(sourceZoneIds) do AddExpanded(zoneId) end

    for _, zoneId in ipairs(candidates) do
        local stats = self:GetStatisticsData(false, zoneId)
        if stats and type(stats.categories) == "table" then
            for _, row in ipairs(stats.categories) do
                if tostring(row.completionType) == tostring(activeType) then
                    return {
                        zoneId = zoneId,
                        name = SafeZoneName(zoneId),
                        completed = row.completed or 0,
                        total = row.total or 0,
                        countText = row.countText,
                        informational = row.informational,
                        completionType = activeType,
                        categoryName = row.name or self:GetProgressGoalCategoryDisplayName(activeType),
                    }
                end
            end
        end
    end

    return nil
end

function TPM:RefreshSkyshardGoalWidget()
    if not self.skyshardGoalWidget then self:CreateSkyshardGoalWidget() end
    local widget = self.skyshardGoalWidget
    if not widget then return end

    -- The normal HUD stays hidden behind the journal, but the explicit gear
    -- editor must survive the 1.5-second refresh while the journal is open.
    local editingPosition = self.skyshardGoalEditMode == true
    if not editingPosition and self.statisticsWindow and not self.statisticsWindow:IsHidden() then
        widget:SetHidden(true)
        return
    end
    if editingPosition and not self:IsStatisticsAllowedInCurrentScene() then
        widget:SetHidden(true)
        return
    end
    if (not self.saved or self.saved.skyshardGoalEnabled ~= true) and not editingPosition then
        widget:SetHidden(true)
        return
    end
    if not editingPosition and not self:IsSkyshardGoalHudSceneVisible() then
        widget:SetHidden(true)
        return
    end

    -- Render FIRST, then resolve progress. This makes the HUD independent from
    -- any Zone Stories/API failure. An enabled goal must always be visible.
    if widget.SetAlpha then widget:SetAlpha(1) end
    local activeType = self:GetActiveProgressGoalCategoryType() or _G.ZONE_COMPLETION_TYPE_SKYSHARDS
    self.skyshardGoalZoneLabel:SetText(self:GetProgressGoalHudTitle(activeType))

    local _, _, fallbackZoneName = self:GetCurrentPlayerZoneIdentity()
    fallbackZoneName = tostring(fallbackZoneName or "")
    if fallbackZoneName == "" then fallbackZoneName = "—" end
    self.skyshardGoalProgressLabel:SetText(fallbackZoneName .. "  —/—")
    if not editingPosition then
        self:UpdateSkyshardGoalAnchor(false)
    end
    widget:SetHidden(false)

    local data = self:GetCurrentSkyshardGoalData()
    self.skyshardGoalLastDataError = nil
    if type(data) == "table" then
        local zoneName = tostring(data.name or fallbackZoneName or "—")
        if data.informational and data.countText and data.countText ~= "" then
            self.skyshardGoalProgressLabel:SetText(string.format("%s  %s", zoneName, tostring(data.countText)))
            self.skyshardGoalLastData = data
        elseif (tonumber(data.total) or 0) > 0 then
            self.skyshardGoalProgressLabel:SetText(self:L("SKYSHARD_GOAL_PROGRESS", zoneName, tonumber(data.completed) or 0, tonumber(data.total) or 0))
            self.skyshardGoalLastData = data
        else
            self.skyshardGoalLastData = nil
        end
    else
        self.skyshardGoalLastData = nil
    end

    -- A few UI systems can modify anchors during scene transitions. Re-assert
    -- the top-level window only if the HUD is still the current scene; otherwise
    -- a same-frame ESC/M transition must win over this refresh.
    if not editingPosition and not self:IsSkyshardGoalHudSceneVisible() then
        widget:SetHidden(true)
        return
    end
    if widget.SetAlpha then widget:SetAlpha(1) end
    widget:SetHidden(false)
end

function TPM:SetSkyshardGoalEditMode(enabled, commitChanges)
    enabled = enabled == true
    if enabled and self.saved and not self:GetActiveProgressGoalCategoryType() then
        self.saved.progressGoalCategoryType = _G.ZONE_COMPLETION_TYPE_SKYSHARDS
        self.saved.skyshardGoalEnabled = true
    end
    local wasEditing = self.skyshardGoalEditMode == true
    if not self.skyshardGoalWidget then self:CreateSkyshardGoalWidget() end
    local widget = self.skyshardGoalWidget
    if not widget then return end

    -- Clicking the gear a second time is the explicit SAVE action. Movement
    -- and resizing stay live but unsaved until this point.
    if wasEditing and not enabled and commitChanges ~= false and self.saved then
        local left = type(widget.GetLeft) == "function" and tonumber(widget:GetLeft()) or nil
        local top = type(widget.GetTop) == "function" and tonumber(widget:GetTop()) or nil
        local width = type(widget.GetWidth) == "function" and tonumber(widget:GetWidth()) or nil
        local height = type(widget.GetHeight) == "function" and tonumber(widget:GetHeight()) or nil
        if left and top and width and height then
            self.saved.skyshardGoalCustomPosition = true
            self.saved.skyshardGoalCustomX = math.floor(left + 0.5)
            self.saved.skyshardGoalCustomY = math.floor(top + 0.5)
            self.saved.skyshardGoalCustomWidth = math.floor(Clamp(width, 230, 760) + 0.5)
            self.saved.skyshardGoalCustomHeight = math.floor(Clamp(height, 60, 220) + 0.5)
            self.skyshardGoalAnchorMode = "custom_saved"
        end
    end

    self.skyshardGoalEditMode = enabled
    self.skyshardGoalDragging = false
    self.skyshardGoalResizing = false
    self:UpdateGlobalMouseUpRegistration()
    self:UpdateSkyshardGoalRefreshTimer()
    if self.skyshardGoalDragSurface then self.skyshardGoalDragSurface:SetHandler("OnUpdate", nil) end
    if self.skyshardGoalResizeGrip then self.skyshardGoalResizeGrip:SetHandler("OnUpdate", nil) end

    if enabled and not wasEditing then
        -- Start from the current automatic/saved location, then convert to an
        -- absolute TOPLEFT anchor so ESO's native tracker can no longer move it
        -- underneath the editor while the user is working.
        self:UpdateSkyshardGoalAnchor(true)
        local left = type(widget.GetLeft) == "function" and tonumber(widget:GetLeft()) or 0
        local top = type(widget.GetTop) == "function" and tonumber(widget:GetTop()) or 0
        widget:ClearAnchors()
        widget:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
        if self.skyshardGoalZoneLabel then self.skyshardGoalZoneLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT) end
        if self.skyshardGoalProgressLabel then self.skyshardGoalProgressLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT) end
        self.skyshardGoalAnchorMode = "custom_edit"
    end

    if self.skyshardGoalEditBackdrop then self.skyshardGoalEditBackdrop:SetHidden(not enabled) end
    if self.skyshardGoalResizeGrip then
        self.skyshardGoalResizeGrip:SetHidden(not enabled)
        self.skyshardGoalResizeGrip:SetMouseEnabled(enabled)
    end
    widget:SetMouseEnabled(enabled)
    if widget.SetMovable then widget:SetMovable(false) end
    if self.skyshardGoalDragSurface then self.skyshardGoalDragSurface:SetMouseEnabled(enabled) end
    if widget.SetDrawLevel then widget:SetDrawLevel(enabled and 14000 or 200) end

    if enabled then
        self:RefreshSkyshardGoalWidget()
        widget:SetHidden(false)
        if widget.BringWindowToTop then widget:BringWindowToTop() end
    else
        self:RefreshSkyshardGoalWidget()
    end

    if self.statisticsWindow and not self.statisticsWindow:IsHidden() then
        self:RefreshStatisticsWindow()
    end
end

function TPM:ToggleSkyshardGoalEditMode()
    self:SetSkyshardGoalEditMode(not (self.skyshardGoalEditMode == true))
end

function TPM:ResetSkyshardGoalCustomPosition()
    if not self.saved then return end
    self:SetSkyshardGoalEditMode(false, false)
    self.saved.skyshardGoalCustomPosition = false
    self.saved.skyshardGoalCustomX = false
    self.saved.skyshardGoalCustomY = false
    self.saved.skyshardGoalCustomWidth = false
    self.saved.skyshardGoalCustomHeight = false
    if self.skyshardGoalWidget then self.skyshardGoalWidget:SetDimensions(360, 60) end
    self:UpdateSkyshardGoalAnchor(true)
    self:RefreshSkyshardGoalWidget()
end

function TPM:PrintSkyshardGoalDebug()
    local widget = self.skyshardGoalWidget
    local enabled = self.saved and self.saved.skyshardGoalEnabled == true
    if not widget then
        d(string.format("TPM skydebug: enabled=%s widget=nil", tostring(enabled)))
        return
    end

    local function SafeControlNumber(methodName)
        local fn = widget[methodName]
        if type(fn) ~= "function" then return nil end
        return tonumber(fn(widget))
    end

    local hidden = type(widget.IsHidden) == "function" and widget:IsHidden() or nil
    local alpha = SafeControlNumber("GetAlpha")
    local left, top = SafeControlNumber("GetLeft"), SafeControlNumber("GetTop")
    local right, bottom = SafeControlNumber("GetRight"), SafeControlNumber("GetBottom")
    local rootW = GuiRoot and type(GuiRoot.GetWidth) == "function" and tonumber(GuiRoot:GetWidth()) or 0
    local rootH = GuiRoot and type(GuiRoot.GetHeight) == "function" and tonumber(GuiRoot:GetHeight()) or 0

    local _, _, zoneName = self:GetCurrentPlayerZoneIdentity()
    local data = self.skyshardGoalLastData
    d(string.format("TPM skydebug: enabled=%s hidden=%s alpha=%s anchor=%s pos=%.0f,%.0f-%.0f,%.0f root=%.0fx%.0f zone=%s progress=%s error=%s",
        tostring(enabled), tostring(hidden), tostring(alpha), tostring(self.skyshardGoalAnchorMode or "?"),
        tonumber(left) or -1, tonumber(top) or -1, tonumber(right) or -1, tonumber(bottom) or -1,
        tonumber(rootW) or 0, tonumber(rootH) or 0, tostring(zoneName or "?"),
        data and string.format("%s/%s", tostring(data.completed), tostring(data.total)) or "—/—",
        tostring(self.skyshardGoalLastDataError or "none")))
end

function TPM:SetSkyshardGoalPosition(position)
    if not self.saved then return end
    position = tonumber(position) == 2 and 2 or 1
    self.saved.skyshardGoalPosition = position
    self:SetSkyshardGoalEditMode(false, false)
    self.saved.skyshardGoalCustomPosition = false
    self.saved.skyshardGoalCustomX = false
    self.saved.skyshardGoalCustomY = false
    self.saved.skyshardGoalCustomWidth = false
    self.saved.skyshardGoalCustomHeight = false
    if self.skyshardGoalWidget then self.skyshardGoalWidget:SetDimensions(360, 60) end
    self:UpdateSkyshardGoalAnchor(true)
    self:RefreshSkyshardGoalWidget()
end

function TPM:GetAllProgressZoneIds(forceRebuild)
    if not forceRebuild and self.progressZoneIdsCache then
        return self.progressZoneIdsCache
    end

    local progressZoneIds = {}
    local sourceZoneIds = {}

    local function AddSourceZone(zoneId)
        if not zoneId or zoneId <= 0 or sourceZoneIds[zoneId] then return end
        sourceZoneIds[zoneId] = true

        local _, _, availableTotal, _, progressZoneId = self:GetResolvedCompletion(zoneId)
        if availableTotal > 0 and progressZoneId and progressZoneId > 0 and self:IsProgressZoneAvailable(progressZoneId) then
            progressZoneIds[progressZoneId] = true
        end
    end

    if type(GetNextZoneStoryZoneId) == "function" then
        local lastZoneId = nil
        local safety = 0
        while safety < 500 do
            local zoneId = GetNextZoneStoryZoneId(lastZoneId)
            if not zoneId or zoneId == 0 then break end
            AddSourceZone(zoneId)
            lastZoneId = zoneId
            safety = safety + 1
        end
    end

    if type(GetNumMaps) == "function" and type(GetMapInfoByIndex) == "function" then
        for mapIndex = 1, GetNumMaps() do
            local _, mapType, _, zoneIndex = GetMapInfoByIndex(mapIndex)
            if mapType == MAPTYPE_ZONE and zoneIndex and zoneIndex > 0 then
                AddSourceZone(GetZoneId(zoneIndex))
            end
        end
    end

    self.progressZoneIdsCache = progressZoneIds
    return progressZoneIds
end

function TPM:InvalidateStatisticsData(rebuildZoneList)
    -- Keep the global Tamriel cache separate from the optional zone-focus cache.
    -- History, milestones and the Goals page must always continue to use Tamriel.
    self.statisticsCache = nil
    self.statisticsFocusCache = nil
    self.statisticsFocusCacheZoneId = nil
    self.statisticsData = nil
    self.zoneAchievementSummaryCache = nil
    if rebuildZoneList then
        -- Zone availability can change after activation, so rebuild only the
        -- dynamic progress-zone set. Quest master metadata (quest -> zone,
        -- repeatable/type/name eligibility and Crown starter IDs) is static for
        -- the lifetime of the current UI session and can safely survive loading
        -- screens. Keeping it avoids repeating the 1..SIDE_QUEST_SCAN_MAX_ID scan.
        self.progressZoneIdsCache = nil
    end
end

function TPM:GetTamrielProgress()
    if self.statisticsCache then
        return self.statisticsCache.percent or 0,
            self.statisticsCache.completedObjectives or 0,
            self.statisticsCache.totalObjectives or 0,
            self.statisticsCache.totalZones or 0
    end

    local progressZoneIds = self:GetAllProgressZoneIds()
    local completedTotal = 0
    local availableTotal = 0
    local categoryRatioTotal = 0
    local categoryCount = 0
    local zoneCount = 0

    for zoneId in pairs(progressZoneIds) do
        local breakdown, completed, available = self:GetCompletionBreakdown(zoneId)
        if available > 0 then
            zoneCount = zoneCount + 1
            completedTotal = completedTotal + completed
            availableTotal = availableTotal + available
            for _, row in ipairs(breakdown) do
                if row.total > 0 then
                    categoryRatioTotal = categoryRatioTotal + (row.completed / row.total)
                    categoryCount = categoryCount + 1
                end
            end
        end
    end

    local percent = 0
    local mode = self.saved and self.saved.calculationMode or "objectives"
    if mode == "categories" then
        if categoryCount > 0 then
            percent = Round((categoryRatioTotal / categoryCount) * 100)
        end
    elseif availableTotal > 0 then
        percent = Round((completedTotal / availableTotal) * 100)
    end

    if availableTotal > 0 and completedTotal < availableTotal and percent >= 100 then
        percent = 99
    end

    return Clamp(percent, 0, 100), completedTotal, availableTotal, zoneCount
end

function TPM:BuildCategoryPercentText(breakdown)
    if not breakdown or #breakdown == 0 then return "" end

    local parts = {}
    for _, row in ipairs(breakdown) do
        parts[#parts + 1] = string.format("%s %d%%", self:GetCompletionTypeName(row.completionType), row.percent or 0)
    end

    -- Keep the category block readable in ESO's normal (non-fullscreen) map.
    -- Four entries per row prevents the old 1180px-wide text line from
    -- overflowing the default map viewport.
    local lines = {}
    local entriesPerLine = 4
    for index = 1, #parts, entriesPerLine do
        local row = {}
        for partIndex = index, math.min(index + entriesPerLine - 1, #parts) do
            row[#row + 1] = parts[partIndex]
        end
        lines[#lines + 1] = table.concat(row, "  |  ")
    end

    return table.concat(lines, "\n")
end

function TPM:GetMapRect(mapId)
    if type(mapId) ~= "number" or mapId <= 0 then return nil end

    local offsetX, offsetY, width, height = GetUniversallyNormalizedMapInfo(mapId)
    if not offsetX or not offsetY or not width or not height or width <= 0 or height <= 0 then
        return nil
    end

    return offsetX, offsetY, width, height
end

function TPM:UniversalToCurrentMap(universalX, universalY)
    local currentMapId = GetCurrentMapId()
    if not currentMapId or currentMapId <= 0 then return nil end

    local offsetX, offsetY, width, height = self:GetMapRect(currentMapId)
    if not offsetX then return nil end

    local x = (universalX - offsetX) / width
    local y = (universalY - offsetY) / height

    if x < 0 or x > 1 or y < 0 or y > 1 then return nil end
    return x, y
end

function TPM:IsOverviewMap()
    local mapType = GetMapType()
    return mapType == MAPTYPE_WORLD or mapType == MAPTYPE_COSMIC
end

function TPM:ShouldDisplayOverviewZone(zoneId, x, y, isSymbolicPosition)
    local mapType = GetMapType()
    if mapType ~= MAPTYPE_COSMIC then
        return true
    end

    if not x or not y then
        return false
    end

    -- Clockwork City's Aurbis symbol sits just inside the generic outer-ring
    -- radius. When ESO gives us its own symbolic current-map position, trust it
    -- instead of rejecting it with the geometric fallback below.
    if isSymbolicPosition and AURBIS_SYMBOLIC_ZONE_IDS[zoneId] then
        return true
    end

    -- The cosmic overview contains the Tamriel mainland in the center and the
    -- separate surrounding regions in the outer ring. On this map we only want
    -- labels for the outer ring regions, not the inner mainland zone labels.
    local dx = x - 0.5
    local dy = y - 0.52
    local distance = zo_sqrt((dx * dx) + (dy * dy))
    return distance >= 0.34
end


-- 2.6.32 COMMUNITY ALLIANCE TERRITORY OVERLAY
-- This is intentionally a subtle zone-center glow/border rather than a full
-- recolor of ESO's map art. It keeps TPM completion percentages readable and
-- avoids replacing or modifying ZOS map textures.
local TPM_NEUTRAL_BASEGAME_NAMES =
{
    -- English
    ["coldharbour"] = true,
    ["craglorn"] = true,
    ["cyrodiil"] = true,

    -- German
    ["kalthafen"] = true,
    ["kargstein"] = true,
    ["cyrodiil"] = true,

    -- French
    ["havreglace"] = true,
    ["raidelorn"] = true,
    ["cyrodiil"] = true,

    -- Russian
    ["хладная гавань"] = true,
    ["креглорн"] = true,
    ["сиродил"] = true,
}

function TPM:GetAllianceTerritoryGroup(zoneId)
    zoneId = tonumber(zoneId) or 0
    if zoneId <= 0 then return nil end

    -- 2.6.38: Stable and language-independent original alliance territory map.
    -- Do not use localized zone names here: changing TPM language must never
    -- change alliance percentages, zone counts or objective totals.
    local groups = {
        -- Daggerfall Covenant (7)
        [534] = "DC", -- Stros M'Kai
        [535] = "DC", -- Betnikh
        [3]   = "DC", -- Glenumbra
        [19]  = "DC", -- Stormhaven
        [20]  = "DC", -- Rivenspire
        [104] = "DC", -- Alik'r Desert
        [92]  = "DC", -- Bangkorai

        -- Aldmeri Dominion (6)
        [537] = "AD", -- Khenarthi's Roost
        [381] = "AD", -- Auridon
        [383] = "AD", -- Grahtwood
        [108] = "AD", -- Greenshade
        [58]  = "AD", -- Malabal Tor
        [382] = "AD", -- Reaper's March

        -- Ebonheart Pact (7)
        [280] = "EP", -- Bleakrock Isle
        [281] = "EP", -- Bal Foyen
        [41]  = "EP", -- Stonefalls
        [57]  = "EP", -- Deshaan
        [117] = "EP", -- Shadowfen
        [101] = "EP", -- Eastmarch
        [103] = "EP", -- The Rift

        -- Neutral base-game territories supported by the overlay
        [181] = "NEUTRAL", -- Cyrodiil
        [347] = "NEUTRAL", -- Coldharbour
        [888] = "NEUTRAL", -- Craglorn
    }
    return groups[zoneId]
end


-- 2.6.41: Experimental world-map territory borders.
-- ESO does not expose the drawn zone polygons as recolorable controls, so TPM
-- draws an independent border layer inside ZO_WorldMapContainer. Because the
-- controls are children of the map container they follow the map pan/zoom.

-- 2.6.45: Alliance territory visualization moved into the Alliance Statistics page.
-- The normal ESO World Map is deliberately left untouched.
function TPM:HideAllianceTerritoryBorders() end
function TPM:ReleaseAllianceTerritoryBorders() end
function TPM:RefreshAllianceTerritoryBorders() end


function TPM:GetAllianceTerritoryColor(zoneId)
    local group = self:GetAllianceTerritoryGroup(zoneId)
    if group == "DC" then
        return 0.20, 0.48, 1.00, 0.90
    elseif group == "AD" then
        return 1.00, 0.76, 0.12, 0.90
    elseif group == "EP" then
        return 1.00, 0.20, 0.20, 0.90
    elseif group == "NEUTRAL" and self.saved and self.saved.allianceNeutralWhite then
        return 0.96, 0.96, 0.96, 0.78
    end
    return nil
end

function TPM:EnsureAllianceTerritoryBackdrop(label)
    if not label then return nil end
    if label.allianceTerritoryBackdrop then
        return label.allianceTerritoryBackdrop
    end

    local backdrop = WINDOW_MANAGER:CreateControl(
        label:GetName() .. "AllianceTerritoryBackdrop",
        ZO_WorldMapContainer,
        CT_BACKDROP
    )
    backdrop:SetAnchor(CENTER, label, CENTER, 0, 0)
    backdrop:SetMouseEnabled(false)
    backdrop:SetDrawTier(DT_HIGH)
    backdrop:SetDrawLayer(DL_OVERLAY)
    if backdrop.SetDrawLevel then backdrop:SetDrawLevel(1) end
    backdrop:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16, 3)
    backdrop:SetHidden(true)

    -- Make sure the actual percentage label stays in front of the glow.
    if label.SetDrawLevel then label:SetDrawLevel(10) end

    label.allianceTerritoryBackdrop = backdrop
    return backdrop
end

function TPM:RefreshAllianceTerritoryBackdrop(label, zoneId)
    if not label then return end

    local backdrop = self:EnsureAllianceTerritoryBackdrop(label)
    if not backdrop then return end

    if not self.saved or not self.saved.showAllianceTerritoryColors then
        backdrop:SetHidden(true)
        return
    end

    local r, g, b, a = self:GetAllianceTerritoryColor(zoneId)
    if not r then
        backdrop:SetHidden(true)
        return
    end

    -- Slightly wider than the progress text so it reads as a territory marker,
    -- but remains subtle enough not to hide ESO's world-map art.
    local labelWidth = tonumber(label:GetWidth()) or 84
    local labelHeight = tonumber(label:GetHeight()) or 32
    local width = math.max(154, labelWidth + 34)
    local height = math.max(50, labelHeight + 16)

    backdrop:SetDimensions(width, height)
    backdrop:SetCenterColor(r, g, b, 0.14)
    backdrop:SetEdgeColor(r, g, b, math.min(1, (a or 0.9) + 0.08))
    backdrop:SetHidden(false)
end

function TPM:HideAllianceTerritoryBackdrop(label)
    if label and label.allianceTerritoryBackdrop then
        label.allianceTerritoryBackdrop:SetHidden(true)
    end
end

function TPM:AcquireOverlayLabel()
    local label = table.remove(self.labelPool)
    if label then
        label:SetHidden(false)
        self:ApplyProgressFont(label, "overlay")
        return label
    end

    self.nextLabelId = self.nextLabelId + 1
    label = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "NativeLabel" .. tostring(self.nextLabelId), ZO_WorldMapContainer, CT_LABEL)
    label:SetDimensions(84, 32)
    self:ApplyProgressFont(label, "overlay")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetDrawLayer(DL_OVERLAY)
    label:SetDrawTier(DT_HIGH)
    label:SetMouseEnabled(true)

    label:SetHandler("OnMouseEnter", function(control)
        if not TPM.saved or not TPM.saved.showTooltip or not control.zoneId then return end
        TPM:ShowTooltip(control)
    end)

    label:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)

    label:SetHandler("OnMouseUp", function(control, button, upInside)
        if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        if control.mapId and WORLD_MAP_MANAGER and WORLD_MAP_MANAGER.SetMapById then
            WORLD_MAP_MANAGER:SetMapById(control.mapId)
        end
    end)

    return label
end

function TPM:ReleaseOverlayLabels()
    for _, label in ipairs(self.overlayLabels) do
        self:HideAllianceTerritoryBackdrop(label)
        label:SetHidden(true)
        label:ClearAnchors()
        label.zoneId = nil
        label.progressZoneId = nil
        label.mapId = nil
        label.breakdown = nil
        label.completedTotal = nil
        label.availableTotal = nil
        label.percent = nil
        self.labelPool[#self.labelPool + 1] = label
    end
    ZO_ClearNumericallyIndexedTable(self.overlayLabels)
end

function TPM:ShowTooltip(control)
    if not control.zoneId then return end

    InitializeTooltip(InformationTooltip, control, BOTTOM, 0, -8, TOP)
    InformationTooltip:AddLine(SafeZoneName(control.zoneId), "ZoFontWinH2")
    InformationTooltip:AddLine(self:L("OVERALL_PROGRESS", control.percent or 0), "ZoFontGameBold")

    if control.progressZoneId and control.progressZoneId ~= control.zoneId then
        InformationTooltip:AddLine(self:L("ESO_PROGRESS_ZONE", SafeZoneName(control.progressZoneId)), "ZoFontGameSmall")
    end

    if control.completedTotal and control.availableTotal then
        InformationTooltip:AddLine(self:L("OBJECTIVES_COMPLETE", control.completedTotal, control.availableTotal), "ZoFontGame")
    end

    if control.breakdown then
        InformationTooltip:AddVerticalPadding(7)
        local missingCount = 0
        for _, row in ipairs(control.breakdown) do
            if row.total > 0 and row.completed < row.total then
                if missingCount == 0 then
                    InformationTooltip:AddLine(self:L("TOOLTIP_MISSING_HEADER"), "ZoFontGameBold")
                end
                missingCount = missingCount + 1
                InformationTooltip:AddLine(
                    self:L(
                        "TOOLTIP_MISSING_LINE",
                        self:GetCompletionTypeName(row.completionType),
                        row.completed,
                        row.total
                    ),
                    "ZoFontGame"
                )
            end
        end
        if missingCount == 0 then
            InformationTooltip:AddLine(self:L("TOOLTIP_ALL_COMPLETE"), "ZoFontGameBold")
        end
    end

    if self.saved and self.saved.debugMode then
        InformationTooltip:AddVerticalPadding(8)
        InformationTooltip:AddLine(self:L("DEBUG_HEADER"), "ZoFontGameBold")
        InformationTooltip:AddLine(self:L("DEBUG_CURRENT_MAP", tostring((GetCurrentMapId and GetCurrentMapId()) or 0)), "ZoFontGameSmall")
        InformationTooltip:AddLine(self:L("DEBUG_TARGET_MAP", tostring(control.mapId or 0)), "ZoFontGameSmall")
        InformationTooltip:AddLine(self:L("DEBUG_ZONE_ID", tostring(control.zoneId or 0)), "ZoFontGameSmall")
        InformationTooltip:AddLine(self:L("DEBUG_PROGRESS_ZONE_ID", tostring(control.progressZoneId or 0)), "ZoFontGameSmall")
        InformationTooltip:AddLine(self:L("DEBUG_MAP_TYPE", tostring((GetMapType and GetMapType()) or 0)), "ZoFontGameSmall")
    end

    InformationTooltip:AddVerticalPadding(6)
    InformationTooltip:AddLine(self:L("LEFT_CLICK_OPEN"), "ZoFontGameSmall")
end


function TPM:BuildSymbolicZonePositionCache()
    ZO_ClearTable(self.symbolicZonePositions)
    self.symbolicZonePositionsMapId = GetCurrentMapId() or 0

    if GetMapType() ~= MAPTYPE_COSMIC then return end
    if type(GetNumFastTravelNodes) ~= "function" or type(GetFastTravelNodeInfo) ~= "function" then return end
    if type(GetFastTravelNodePOIIndicies) ~= "function" or type(GetZoneId) ~= "function" then return end

    local numNodes = GetNumFastTravelNodes() or 0
    for nodeIndex = 1, numNodes do
        local _, _, x, y, _, _, _, isShownInCurrentMap = GetFastTravelNodeInfo(nodeIndex)
        if isShownInCurrentMap and type(x) == "number" and type(y) == "number" and x > 0 and x < 1 and y > 0 and y < 1 then
            local zoneIndex = GetFastTravelNodePOIIndicies(nodeIndex)
            if zoneIndex and zoneIndex > 0 then
                local sourceZoneId = GetZoneId(zoneIndex)
                if sourceZoneId and sourceZoneId > 0 then
                    local function Store(candidateZoneId)
                        if candidateZoneId and candidateZoneId > 0 and AURBIS_SYMBOLIC_ZONE_IDS[candidateZoneId]
                           and not self.symbolicZonePositions[candidateZoneId] then
                            self.symbolicZonePositions[candidateZoneId] = { x = x, y = y }
                        end
                    end

                    Store(sourceZoneId)

                    if type(GetZoneStoryZoneIdForZoneId) == "function" then
                        Store(GetZoneStoryZoneIdForZoneId(sourceZoneId))
                    end

                    if type(GetParentZoneId) == "function" then
                        Store(GetParentZoneId(sourceZoneId))
                    end
                end
            end
        end
    end
end

function TPM:GetSymbolicZonePinPosition(zoneId)
    if GetMapType() ~= MAPTYPE_COSMIC or not AURBIS_SYMBOLIC_ZONE_IDS[zoneId] then
        return nil
    end

    local currentMapId = GetCurrentMapId() or 0
    if self.symbolicZonePositionsMapId ~= currentMapId then
        self:BuildSymbolicZonePositionCache()
    end

    local position = self.symbolicZonePositions[zoneId]
    if not position then return nil end
    return position.x, position.y
end

function TPM:GetZonePinPosition(zoneId)
    local mapId = GetMapIdByZoneId(zoneId)
    if not mapId or mapId <= 0 then return nil end

    -- Clockwork City's Aurbis symbol is a deliberate UI location rather than a
    -- geographical projection. Use the known normalized symbol center first so
    -- it cannot disappear because of fast-travel visibility or map projection.
    if GetMapType() == MAPTYPE_COSMIC then
        local fixedPosition = AURBIS_FIXED_ZONE_POSITIONS[zoneId]
        if fixedPosition then
            return fixedPosition.x, fixedPosition.y, mapId, true
        end
    end

    -- Aurbis has symbolic locations whose on-screen position does not match the
    -- universally-normalized center of their actual zone map. Prefer ESO's own
    -- current-map fast-travel position for explicitly known special realms.
    local symbolicX, symbolicY = self:GetSymbolicZonePinPosition(zoneId)
    if symbolicX and symbolicY then
        return symbolicX, symbolicY, mapId, true
    end

    local zoneOffsetX, zoneOffsetY, zoneWidth, zoneHeight = self:GetMapRect(mapId)
    if not zoneOffsetX then return nil end

    local universalX = zoneOffsetX + (zoneWidth * 0.5)
    local universalY = zoneOffsetY + (zoneHeight * 0.5)
    local x, y = self:UniversalToCurrentMap(universalX, universalY)
    if not x or not y then return nil end

    return x, y, mapId, false
end

function TPM:CreateZoneNativePin(pinManager, zoneId)
    local x, y, mapId, isSymbolicPosition = self:GetZonePinPosition(zoneId)
    if not x then return end
    if not self:ShouldDisplayOverviewZone(zoneId, x, y, isSymbolicPosition) then return end

    local breakdown, completedTotal, availableTotal, percent, progressZoneId = self:GetResolvedCompletion(zoneId)
    if availableTotal <= 0 then return end
    if not self:IsProgressZoneAvailable(progressZoneId) then return end
    if not self:MatchesQuickFilter(percent) then return end

    local displayText = self:GetOverviewPercentText(percent)
    if not displayText then return end

    local pinType = _G[PIN_TYPE_STRING]
    if not pinType then return end

    local pin = pinManager:CreatePin(pinType, zoneId, x, y)
    if not pin then return end

    local pinControl = pin:GetControl()
    if not pinControl then return end

    -- The native map pin is only an anchor. ESO owns its position and updates it
    -- in the same zoom/pan cycle as every other map pin. Our label is anchored to
    -- that control, so no per-frame coordinate calculation is needed anymore.
    -- Alpha is reset by ESO's map-pin pool. Do not change MouseEnabled here: the
    -- same pooled control can later be reused by a normal ESO pin.
    pinControl:SetAlpha(0)

    local label = self:AcquireOverlayLabel()
    label:ClearAnchors()
    label:SetAnchor(CENTER, pinControl, CENTER, 0, 0)

    -- World-map percentage labels deliberately use the same rendering path as
    -- v1.6.0. Font, size and color are fully controlled by the user's map
    -- percentage settings for every value, including 100%. The ESO-gold 100%
    -- treatment is reserved for the statistics journal only.
    local color = self:GetDisplayPercentColor(percent)
    local fontSize = self:GetProgressFontSize("overlay")
    if self.saved.showZoneNames then
        label:SetDimensions(math.max(280, fontSize * 11), math.max(34, fontSize + 10))
        label:SetText(string.format("|cD8C58C%s|r  |c%s%s|r", SafeZoneName(zoneId), color, displayText))
    else
        -- Keep the mouse hitbox close to the actual percentage text so map
        -- dragging/clicking is not blocked by large invisible label areas.
        label:SetDimensions(math.max(84, fontSize * 3), math.max(32, fontSize + 10))
        label:SetText(string.format("|c%s%s|r", color, displayText))
    end

    self:RefreshAllianceTerritoryBackdrop(label, zoneId)

    label.zoneId = zoneId
    label.progressZoneId = progressZoneId
    label.mapId = mapId
    label.breakdown = breakdown
    label.completedTotal = completedTotal
    label.availableTotal = availableTotal
    label.percent = percent

    self.overlayLabels[#self.overlayLabels + 1] = label
end

function TPM:BuildNativePins(pinManager)
    if not self.saved or not self.saved.enabled or not self:IsOverviewMap() then return end

    ZO_ClearTable(self.displayedZoneIds)

    local function TryAdd(zoneId)
        if not zoneId or zoneId <= 0 or TPM.displayedZoneIds[zoneId] then return end
        TPM.displayedZoneIds[zoneId] = true
        TPM:CreateZoneNativePin(pinManager, zoneId)
    end

    -- Clockwork City (zoneId 980) is a symbolic Aurbis realm and is not
    -- guaranteed to be returned through the same map enumeration path as normal
    -- MAPTYPE_ZONE regions. Queue it explicitly on the cosmic overview.
    if GetMapType() == MAPTYPE_COSMIC then
        TryAdd(980)
    end

    if type(GetNextZoneStoryZoneId) == "function" then
        local lastZoneId = nil
        local safety = 0
        while safety < 500 do
            local zoneId = GetNextZoneStoryZoneId(lastZoneId)
            if not zoneId or zoneId == 0 then break end
            TryAdd(zoneId)
            lastZoneId = zoneId
            safety = safety + 1
        end
    end

    if type(GetNumMaps) == "function" and type(GetMapInfoByIndex) == "function" then
        for mapIndex = 1, GetNumMaps() do
            local _, mapType, _, zoneIndex = GetMapInfoByIndex(mapIndex)
            if mapType == MAPTYPE_ZONE and zoneIndex and zoneIndex > 0 then
                TryAdd(GetZoneId(zoneIndex))
            end
        end
    end
end

function TPM:RegisterCustomPin()
    if self.pinRegistered then return true end
    if type(ZO_WorldMap_GetPinManager) ~= "function" then return false end

    local pinManager = ZO_WorldMap_GetPinManager()
    if not pinManager or not pinManager.AddCustomPin then return false end

    pinManager:AddCustomPin(
        PIN_TYPE_STRING,
        function(manager) TPM:BuildNativePins(manager) end,
        nil,
        {
            level = 200,
            size = 1,
            minSize = 1,
            texture = "",
        },
        nil
    )

    local pinType = _G[PIN_TYPE_STRING]
    if not pinType then return false end

    pinManager:SetCustomPinEnabled(pinType, true)
    self.pinRegistered = true
    return true
end

function TPM:GetFocusedQuestIndex()
    if QUEST_JOURNAL_MANAGER and QUEST_JOURNAL_MANAGER.GetFocusedQuestIndex then
        local questIndex = QUEST_JOURNAL_MANAGER:GetFocusedQuestIndex()
        if questIndex and questIndex > 0 and IsValidQuestIndex(questIndex) then
            return questIndex
        end
    end

    -- Prefer ESO's assisted tracked quest.
    if type(GetNumTracked) == "function" and type(GetTrackedByIndex) == "function" and type(GetTrackedIsAssisted) == "function" then
        for trackedIndex = 1, GetNumTracked() do
            local trackType, arg1, arg2 = GetTrackedByIndex(trackedIndex)
            if (not TRACK_TYPE_QUEST or trackType == TRACK_TYPE_QUEST) and GetTrackedIsAssisted(trackType, arg1, arg2) then
                if arg1 and arg1 > 0 and IsValidQuestIndex(arg1) then
                    return arg1
                end
            end
        end
    end

    -- Journal quest indices are sparse, so do not iterate only to
    -- GetNumJournalQuests(). Scan the full journal range and use ESO's tracked
    -- flag as a final fallback.
    if type(GetJournalQuestInfo) == "function" then
        local maxQuests = MAX_JOURNAL_QUESTS or 25
        for questIndex = 1, maxQuests do
            if IsValidQuestIndex(questIndex) then
                local _, _, _, _, _, _, tracked = GetJournalQuestInfo(questIndex)
                if tracked then
                    return questIndex
                end
            end
        end
    end

    return nil
end

function TPM:GetQuestRewardLines(questIndex)
    local lines = {}
    local details = {}
    if not questIndex or not IsValidQuestIndex(questIndex) then return lines, details end
    if type(GetJournalQuestNumRewards) ~= "function" or type(GetJournalQuestRewardInfo) ~= "function" then return lines, details end

    local numRewards = GetJournalQuestNumRewards(questIndex) or 0
    for rewardIndex = 1, numRewards do
        local rewardType, name, amount, iconOrCurrencyOptions, meetsUsageRequirement, itemDisplayQuality, itemType = GetJournalQuestRewardInfo(questIndex, rewardIndex)
        amount = amount or 0

        local isOwnedCollectible = REWARD_TYPE_AUTO_ITEM and REWARD_ITEM_TYPE_COLLECTIBLE
            and rewardType == REWARD_TYPE_AUTO_ITEM
            and itemType == REWARD_ITEM_TYPE_COLLECTIBLE
            and meetsUsageRequirement == false

        if not isOwnedCollectible then
            local line = nil
            local currencyType = nil
            local itemId = 0
            if type(GetJournalQuestRewardItemId) == "function" then
                itemId = GetJournalQuestRewardItemId(questIndex, rewardIndex) or 0
            end

            -- ESO uses the fourth GetJournalQuestRewardInfo() return value as
            -- currency formatting data for currency rewards, not as an icon
            -- texture. Detect all currency reward types through ESO's API so
            -- values such as Alliance Points, Tel Var, vouchers and keys cannot
            -- accidentally be passed into zo_iconFormat().
            if type(GetCurrencyTypeFromRewardType) == "function" then
                currencyType = GetCurrencyTypeFromRewardType(rewardType)
                if CURT_NONE and currencyType == CURT_NONE then
                    currencyType = nil
                end
            elseif REWARD_TYPE_MONEY and rewardType == REWARD_TYPE_MONEY then
                currencyType = CURT_MONEY
            end

            if currencyType and currencyType ~= 0 then
                if type(ZO_Currency_FormatPlatform) == "function" then
                    line = ZO_Currency_FormatPlatform(currencyType, amount, ZO_CURRENCY_FORMAT_WHITE_AMOUNT_ICON)
                else
                    line = string.format("%d %s", amount, self:L("QUEST_REWARD_CURRENCY"))
                end
            elseif REWARD_TYPE_PARTIAL_SKILL_POINTS and rewardType == REWARD_TYPE_PARTIAL_SKILL_POINTS then
                if type(ZO_QuestReward_GetSkillPointText) == "function" then
                    line = ZO_QuestReward_GetSkillPointText(amount)
                else
                    line = string.format("%s x%d", self:L("QUEST_REWARD_SKILL_POINTS"), amount)
                end
            else
                local rewardName = name or ""

                if REWARD_TYPE_SKILL_LINE and rewardType == REWARD_TYPE_SKILL_LINE and rewardName ~= "" and type(ZO_QuestReward_GetSkillLineEarnedText) == "function" then
                    rewardName = ZO_QuestReward_GetSkillLineEarnedText(rewardName)
                elseif rewardName ~= "" then
                    rewardName = zo_strformat(SI_TOOLTIP_ITEM_NAME, rewardName)
                else
                    rewardName = self:L("QUEST_REWARD_GENERIC")
                end

                -- Quest reward item names now follow ESO item-quality colors.
                -- Only apply quality colors when ESO exposes a real reward item id.
                if itemId > 0 and itemDisplayQuality and type(GetItemQualityColor) == "function" then
                    local qualityColor = GetItemQualityColor(itemDisplayQuality)
                    if qualityColor and qualityColor.Colorize then
                        rewardName = qualityColor:Colorize(rewardName)
                    end
                end

                local icon = iconOrCurrencyOptions
                local iconText = ""
                -- Only strings are valid texture paths. Some reward types use
                -- this API slot for non-texture data.
                if type(icon) == "string" and icon ~= "" and type(zo_iconFormat) == "function" then
                    iconText = zo_iconFormat(icon, 24, 24) .. " "
                end

                local amountText = amount > 1 and string.format(" x%d", amount) or ""
                line = iconText .. rewardName .. amountText
            end

            if line and line ~= "" then
                lines[#lines + 1] = line
                details[#details + 1] =
                {
                    line = line,
                    rewardIndex = rewardIndex,
                    rewardType = rewardType,
                    amount = amount,
                    itemId = itemId,
                    itemDisplayQuality = itemDisplayQuality,
                    itemType = itemType,
                    currencyType = currencyType,
                }
            end
        end
    end

    return lines, details
end

function TPM:ShowQuestRewardDetailsTooltip(control)
    local details = self.currentQuestRewardDetails or {}
    if #details == 0 then return end

    -- Anchor the details tooltip to the OUTER edge of the whole quest window,
    -- not to the small info icon inside it. This keeps the tooltip above/outside
    -- the high-draw-level reward panel instead of hiding it behind that panel.
    local owner = self.questRewardControl or control
    local rootWidth = (GuiRoot and GuiRoot.GetWidth and GuiRoot:GetWidth()) or 1920
    local ownerLeft = (owner and owner.GetLeft and owner:GetLeft()) or 0
    local ownerRight = (owner and owner.GetRight and owner:GetRight()) or ownerLeft
    local leftSpace = math.max(0, ownerLeft)
    local rightSpace = math.max(0, rootWidth - ownerRight)

    ClearTooltip(InformationTooltip)
    if rightSpace >= leftSpace then
        InitializeTooltip(InformationTooltip, owner, TOPLEFT, 12, 0, TOPRIGHT)
    else
        InitializeTooltip(InformationTooltip, owner, TOPRIGHT, -12, 0, TOPLEFT)
    end

    InformationTooltip:AddLine(self:L("QUEST_REWARD_DETAILS"), "ZoFontWinH3")
    InformationTooltip:AddLine(self:L("QUEST_REWARD_DETAILS_TT"), "ZoFontGameSmall")
    InformationTooltip:AddVerticalPadding(6)

    for _, detail in ipairs(details) do
        InformationTooltip:AddLine(detail.line, "ZoFontGame")
        if self.saved and self.saved.debugMode and detail.itemId and detail.itemId > 0 then
            InformationTooltip:AddLine(self:L("DEBUG_ITEM_ID", detail.itemId, detail.rewardIndex or 0), "ZoFontGameSmall")
        end
    end
end

function TPM:GetQuestRewardAnchorParent()
    return GuiRoot
end

function TPM:GetQuestRewardViewportBounds()
    local parent = GuiRoot
    local parentLeft = (parent and parent.GetLeft and parent:GetLeft()) or 0
    local parentTop = (parent and parent.GetTop and parent:GetTop()) or 0
    local parentWidth = (parent and parent.GetWidth and parent:GetWidth()) or 1920
    local parentHeight = (parent and parent.GetHeight and parent:GetHeight()) or 1080

    local width = (self.questRewardControl and self.questRewardControl:GetWidth()) or DEFAULTS.questRewardWidth
    local height = (self.questRewardControl and self.questRewardControl:GetHeight()) or DEFAULTS.questRewardHeight
    local margin = 8

    local minX = margin
    local minY = margin
    local maxX = math.max(minX, parentWidth - width - margin)
    local maxY = math.max(minY, parentHeight - height - margin)
    return parent, parentLeft, parentTop, minX, minY, maxX, maxY
end

function TPM:GetQuestRewardDefaultScreenPosition()
    local _, rootLeft, rootTop, minX, minY, maxX = self:GetQuestRewardViewportBounds()
    local width = (self.questRewardControl and self.questRewardControl:GetWidth()) or DEFAULTS.questRewardWidth

    -- Start near the upper-right of the actual parchment when possible, but
    -- keep the control in GuiRoot coordinates so the user can later drag it
    -- anywhere on the screen, including outside the map.
    local x = maxX
    local y = minY + 90
    if ZO_WorldMapScroll then
        local mapRight = ZO_WorldMapScroll:GetRight()
        local mapTop = ZO_WorldMapScroll:GetTop()
        if mapRight and mapTop then
            x = (mapRight - rootLeft) - width - 24
            y = (mapTop - rootTop) + 90
        end
    end
    return self:ClampQuestRewardScreenPosition(x, y)
end

function TPM:ClampQuestRewardScreenPosition(x, y)
    local _, _, _, minX, minY, maxX, maxY = self:GetQuestRewardViewportBounds()
    x = Clamp(tonumber(x) or minX, minX, maxX)
    y = Clamp(tonumber(y) or minY, minY, maxY)
    return x, y
end

function TPM:MigrateQuestRewardScreenPosition()
    if not self.saved then return end

    local positionVersion = tonumber(self.saved.questRewardPositionVersion) or 1
    if positionVersion >= 5
        and type(self.saved.questRewardScreenX) == "number"
        and type(self.saved.questRewardScreenY) == "number" then
        return
    end

    local x, y
    local rootLeft = (GuiRoot and GuiRoot:GetLeft()) or 0
    local rootTop = (GuiRoot and GuiRoot:GetTop()) or 0

    -- v1.5.13/1.5.14 stored the position relative to ZO_WorldMap. Convert that
    -- position once into absolute GuiRoot coordinates so the user's last
    -- visible placement is preserved while removing the map-boundary clamp.
    if positionVersion == 4
        and type(self.saved.questRewardScreenX) == "number"
        and type(self.saved.questRewardScreenY) == "number"
        and ZO_WorldMap then
        local mapLeft = ZO_WorldMap:GetLeft()
        local mapTop = ZO_WorldMap:GetTop()
        if mapLeft and mapTop then
            x = (mapLeft - rootLeft) + self.saved.questRewardScreenX
            y = (mapTop - rootTop) + self.saved.questRewardScreenY
        end
    end

    if not x or not y then
        x, y = self:GetQuestRewardDefaultScreenPosition()
    end

    x, y = self:ClampQuestRewardScreenPosition(x, y)
    self.saved.questRewardScreenX = x
    self.saved.questRewardScreenY = y
    self.saved.questRewardPositionVersion = 5
end

function TPM:ApplyQuestRewardPosition()
    local control = self.questRewardControl
    if not control or not self.saved or not GuiRoot then return end

    self:MigrateQuestRewardScreenPosition()
    local x, y = self:ClampQuestRewardScreenPosition(
        self.saved.questRewardScreenX,
        self.saved.questRewardScreenY
    )

    self.saved.questRewardScreenX = x
    self.saved.questRewardScreenY = y
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
end

function TPM:SaveQuestRewardPosition()
    local control = self.questRewardControl
    if not control or not self.saved or not GuiRoot then return end

    local left = control:GetLeft()
    local top = control:GetTop()
    local rootLeft = GuiRoot:GetLeft() or 0
    local rootTop = GuiRoot:GetTop() or 0
    if not left or not top then return end

    local x, y = self:ClampQuestRewardScreenPosition(left - rootLeft, top - rootTop)
    self.saved.questRewardScreenX = Round(x)
    self.saved.questRewardScreenY = Round(y)
    self.saved.questRewardPositionVersion = 5
    self:ApplyQuestRewardPosition()
end

function TPM:UpdateQuestRewardLockState()
    local locked = self.saved and self.saved.questRewardLocked or false
    if self.questRewardResizeHandle then
        self.questRewardResizeHandle:SetHidden(locked)
        self.questRewardResizeHandle:SetMouseEnabled(not locked)
    end
    if self.questRewardDragHandle then
        self.questRewardDragHandle:SetMouseEnabled(not locked)
    end
end

function TPM:StartMovingQuestRewardWindow()
    local control = self.questRewardControl
    if not control or self.questRewardMoving or self.questRewardResizing then return end
    if self.saved and self.saved.questRewardLocked then return end
    if type(GetUIMousePosition) ~= "function" then return end

    local mouseX, mouseY = GetUIMousePosition()
    local _, parentLeft, parentTop = self:GetQuestRewardViewportBounds()
    local left = control:GetLeft()
    local top = control:GetTop()
    if not left or not top then return end

    self.questRewardMoving = true
    self:UpdateGlobalMouseUpRegistration()
    self.questRewardMoveStartMouseX = mouseX
    self.questRewardMoveStartMouseY = mouseY
    self.questRewardMoveStartX = left - parentLeft
    self.questRewardMoveStartY = top - parentTop

    local driver = self.questRewardDragHandle or control
    driver:SetHandler("OnUpdate", function()
        if not TPM.questRewardMoving then return end

        local currentX, currentY = GetUIMousePosition()
        local x = TPM.questRewardMoveStartX + (currentX - TPM.questRewardMoveStartMouseX)
        local y = TPM.questRewardMoveStartY + (currentY - TPM.questRewardMoveStartMouseY)
        x, y = TPM:ClampQuestRewardScreenPosition(x, y)

        local parent = TPM:GetQuestRewardAnchorParent()
        control:ClearAnchors()
        control:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    end)
end

function TPM:StopMovingQuestRewardWindow()
    if not self.questRewardMoving then return end

    self.questRewardMoving = false
    self:UpdateGlobalMouseUpRegistration()
    local driver = self.questRewardDragHandle or self.questRewardControl
    if driver then
        driver:SetHandler("OnUpdate", nil)
    end
    self:SaveQuestRewardPosition()
end

function TPM:UpdateQuestRewardLayout()
    local control = self.questRewardControl
    if not control then return end

    local width = control:GetWidth() or DEFAULTS.questRewardWidth
    local contentWidth = math.max(252, width - 28)

    if self.questRewardTitle then
        local titleWidth = self.questRewardInfoButton and math.max(210, contentWidth - 30) or contentWidth
        self.questRewardTitle:SetWidth(titleWidth)
    end
    if self.questRewardDragHandle then
        local titleHeight = (self.questRewardTitle and self.questRewardTitle:GetHeight()) or 38
        self.questRewardDragHandle:SetHeight(math.max(42, titleHeight + 14))
    end
    if self.questRewardDivider then
        self.questRewardDivider:SetWidth(contentWidth)
    end
    if self.questRewardScrollContainer then
        self.questRewardScrollContainer:ClearAnchors()
        self.questRewardScrollContainer:SetAnchor(TOPLEFT, self.questRewardDivider, BOTTOMLEFT, 0, 8)
        self.questRewardScrollContainer:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -8, -24)
    end
    if self.questRewardLines then
        self.questRewardLines:SetWidth(math.max(220, contentWidth - ZO_SCROLL_BAR_WIDTH - 6))
        local textHeight = self.questRewardLines:GetTextHeight() or 0
        self.questRewardLines:SetHeight(math.max(1, textHeight + 4))
    end
    if self.questRewardScrollContainer and self.questRewardScrollContainer.UpdateScrollBar then
        self.questRewardScrollContainer:UpdateScrollBar()
    end
end

function TPM:ApplyQuestRewardSize()
    local control = self.questRewardControl
    if not control then return end

    local width = Clamp((self.saved and self.saved.questRewardWidth) or DEFAULTS.questRewardWidth, 280, 720)
    local height = Clamp((self.saved and self.saved.questRewardHeight) or DEFAULTS.questRewardHeight, 160, 650)
    control:SetDimensions(width, height)
    self:UpdateQuestRewardLayout()
end

function TPM:SaveQuestRewardSize()
    local control = self.questRewardControl
    if not control or not self.saved then return end

    self.saved.questRewardWidth = Round(Clamp(control:GetWidth() or DEFAULTS.questRewardWidth, 280, 720))
    self.saved.questRewardHeight = Round(Clamp(control:GetHeight() or DEFAULTS.questRewardHeight, 160, 650))
    self:ApplyQuestRewardSize()
    self:ApplyQuestRewardPosition()
end

function TPM:AutoSizeQuestRewardWindow()
    if not self.saved or not self.saved.questRewardAutoSize then return end
    local control = self.questRewardControl
    if not control or not self.questRewardLines or not self.questRewardTitle then return end

    -- Apply the current width before measuring wrapped text. This matters for
    -- long ESO-generated reward names and skill-point lines.
    self:UpdateQuestRewardLayout()

    local titleTextHeight = self.questRewardTitle:GetTextHeight() or 0
    local titleHeight = Clamp(math.max(30, titleTextHeight + 4), 30, 72)
    self.questRewardTitle:SetHeight(titleHeight)

    self:UpdateQuestRewardLayout()
    local rewardTextHeight = self.questRewardLines:GetTextHeight() or 0
    local rootHeight = (GuiRoot and GuiRoot.GetHeight and GuiRoot:GetHeight()) or 1080
    local maxAutoHeight = Clamp(rootHeight - 32, 160, 650)
    local desiredHeight = Clamp(titleHeight + rewardTextHeight + 112, 160, maxAutoHeight)
    control:SetHeight(desiredHeight)
    self.saved.questRewardHeight = Round(desiredHeight)
    self:UpdateQuestRewardLayout()
    self:ApplyQuestRewardPosition()
end

function TPM:StartResizingQuestRewardWindow()
    if self.questRewardResizing or type(GetUIMousePosition) ~= "function" then return end
    if self.saved and self.saved.questRewardLocked then return end

    local control = self.questRewardControl
    local handle = self.questRewardResizeHandle
    if not control or not handle then return end

    local mouseX, mouseY = GetUIMousePosition()
    self.questRewardResizing = true
    self:UpdateGlobalMouseUpRegistration()
    self.questRewardResizeStartMouseX = mouseX
    self.questRewardResizeStartMouseY = mouseY
    self.questRewardResizeStartWidth = control:GetWidth() or DEFAULTS.questRewardWidth
    self.questRewardResizeStartHeight = control:GetHeight() or DEFAULTS.questRewardHeight
    if self.saved then
        self.saved.questRewardAutoSize = false
    end

    handle:SetHandler("OnUpdate", function()
        if not TPM.questRewardResizing then return end
        local currentX, currentY = GetUIMousePosition()
        local newWidth = Clamp(TPM.questRewardResizeStartWidth + (currentX - TPM.questRewardResizeStartMouseX), 280, 720)
        local newHeight = Clamp(TPM.questRewardResizeStartHeight + (currentY - TPM.questRewardResizeStartMouseY), 160, 650)
        control:SetDimensions(newWidth, newHeight)
        TPM:UpdateQuestRewardLayout()
    end)
end

function TPM:StopResizingQuestRewardWindow()
    if not self.questRewardResizing then return end
    self.questRewardResizing = false
    self:UpdateGlobalMouseUpRegistration()
    if self.questRewardResizeHandle then
        self.questRewardResizeHandle:SetHandler("OnUpdate", nil)
    end
    self:SaveQuestRewardSize()
end

function TPM:ResetQuestRewardWindow()
    if not self.saved then return end
    self.saved.questRewardAnchorX = DEFAULTS.questRewardAnchorX
    self.saved.questRewardAnchorY = DEFAULTS.questRewardAnchorY
    self.saved.questRewardWidth = DEFAULTS.questRewardWidth
    self.saved.questRewardHeight = DEFAULTS.questRewardHeight
    self.saved.questRewardAutoSize = true
    self.saved.questRewardPositionVersion = 5

    self:ApplyQuestRewardSize()
    local x, y = self:GetQuestRewardDefaultScreenPosition()
    x, y = self:ClampQuestRewardScreenPosition(x, y)
    self.saved.questRewardScreenX = x
    self.saved.questRewardScreenY = y
    self:ApplyQuestRewardPosition()
    self:UpdateQuestRewardLockState()
    self:QueueRefresh(10)
end

function TPM:CreateQuestRewardControl()
    if self.questRewardControl then return end
    if not GuiRoot or not WINDOW_MANAGER or not WINDOW_MANAGER.CreateTopLevelWindow then return end

    local control = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "QuestRewardControl")
    if control.SetDrawLayer then control:SetDrawLayer(DL_OVERLAY) end
    if control.SetDrawTier then control:SetDrawTier(DT_HIGH) end
    if control.SetDrawLevel then control:SetDrawLevel(100000) end
    control:SetMouseEnabled(true)
    control:SetClampedToScreen(true)
    control:SetMovable(false)
    control:SetHidden(true)
    self.questRewardControl = control
    self:ApplyQuestRewardSize()
    self:ApplyQuestRewardPosition()

    local backdrop = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "QuestRewardBackdrop", control, CT_BACKDROP)
    backdrop:SetAnchorFill(control)
    backdrop:SetDrawLayer(DL_BACKGROUND)
    backdrop:SetDrawTier(DT_LOW)
    backdrop:SetCenterColor(0.06, 0.08, 0.11, 0.92)
    backdrop:SetEdgeColor(0.30, 0.65, 0.85, 0.90)
    backdrop:SetEdgeTexture(nil, 1, 1, 2)
    backdrop:SetMouseEnabled(false)
    self.questRewardBackdrop = backdrop

    local inner = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "QuestRewardInnerBackdrop", control, CT_BACKDROP)
    inner:SetAnchor(TOPLEFT, control, TOPLEFT, 4, 4)
    inner:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -4, -4)
    inner:SetDrawLayer(DL_BACKGROUND)
    inner:SetDrawTier(DT_LOW)
    inner:SetCenterColor(0.09, 0.075, 0.05, 0.48)
    inner:SetEdgeColor(0.08, 0.06, 0.04, 0.0)
    inner:SetMouseEnabled(false)
    self.questRewardInnerBackdrop = inner

    local title = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "QuestRewardTitle", control, CT_LABEL)
    title:SetWidth(284)
    title:SetHeight(38)
    title:SetAnchor(TOPLEFT, control, TOPLEFT, 14, 10)
    title:SetFont(FONT_PROFILES.classic.questTitle)
    title:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    title:SetVerticalAlignment(TEXT_ALIGN_TOP)
    title:SetColor(0.95, 0.82, 0.36, 1)
    title:SetDrawLayer(DL_OVERLAY)
    title:SetDrawTier(DT_HIGH)
    title:SetMouseEnabled(false)
    self.questRewardTitle = title

    -- Dedicated drag area over the quest title. The scroll container consumes
    -- mouse input for scrolling, so dragging the whole parent control is not
    -- reliable. Keeping movement on the title bar makes it deterministic.
    local dragHandle = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "QuestRewardDragHandle", control, CT_CONTROL)
    dragHandle:SetAnchor(TOPLEFT, control, TOPLEFT, 6, 5)
    dragHandle:SetAnchor(TOPRIGHT, control, TOPRIGHT, -6, 5)
    dragHandle:SetHeight(52)
    dragHandle:SetDrawLayer(DL_OVERLAY)
    dragHandle:SetDrawTier(DT_HIGH)
    if dragHandle.SetDrawLevel then dragHandle:SetDrawLevel(5100) end
    dragHandle:SetMouseEnabled(true)
    dragHandle:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            TPM:StartMovingQuestRewardWindow()
        end
    end)
    dragHandle:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            TPM:StopMovingQuestRewardWindow()
        end
    end)
    self.questRewardDragHandle = dragHandle

    local infoButton = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "QuestRewardInfoButton", control, CT_LABEL)
    infoButton:SetDimensions(24, 24)
    infoButton:SetAnchor(TOPRIGHT, control, TOPRIGHT, -10, 10)
    infoButton:SetFont("ZoFontGameBold")
    infoButton:SetText("|cE6C45Ci|r")
    infoButton:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    infoButton:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    infoButton:SetDrawLayer(DL_OVERLAY)
    infoButton:SetDrawTier(DT_HIGH)
    if infoButton.SetDrawLevel then infoButton:SetDrawLevel(5200) end
    infoButton:SetMouseEnabled(true)
    infoButton:SetHidden(true)
    infoButton:SetHandler("OnMouseEnter", function(btn)
        TPM:ShowQuestRewardDetailsTooltip(btn)
    end)
    infoButton:SetHandler("OnMouseExit", function()
        ClearTooltip(InformationTooltip)
    end)
    self.questRewardInfoButton = infoButton

    local divider = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "QuestRewardDivider", control, CT_BACKDROP)
    divider:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 6)
    divider:SetDimensions(284, 1)
    divider:SetDrawLayer(DL_OVERLAY)
    divider:SetDrawTier(DT_HIGH)
    divider:SetCenterColor(0.68, 0.60, 0.36, 0.68)
    divider:SetEdgeColor(0.74, 0.64, 0.39, 0.0)
    divider:SetMouseEnabled(false)
    self.questRewardDivider = divider

    local scrollContainer = WINDOW_MANAGER:CreateControlFromVirtual(
        ADDON_NAME .. "QuestRewardScrollContainer",
        control,
        "ZO_ScrollContainer_Shared"
    )
    scrollContainer:SetDrawLayer(DL_OVERLAY)
    scrollContainer:SetDrawTier(DT_HIGH)
    self.questRewardScrollContainer = scrollContainer
    self.questRewardScroll = scrollContainer:GetNamedChild("Scroll")
    self.questRewardScrollChild = self.questRewardScroll and self.questRewardScroll:GetNamedChild("Child") or nil

    local rewardParent = self.questRewardScrollChild or control
    local rewards = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "QuestRewardLines", rewardParent, CT_LABEL)
    rewards:SetAnchor(TOPLEFT, rewardParent, TOPLEFT, 0, 0)
    rewards:SetWidth(250)
    rewards:SetFont(FONT_PROFILES.classic.questBody)
    rewards:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    rewards:SetVerticalAlignment(TEXT_ALIGN_TOP)
    rewards:SetColor(1, 1, 1, 1)
    rewards:SetDrawLayer(DL_OVERLAY)
    rewards:SetDrawTier(DT_HIGH)
    rewards:SetMouseEnabled(false)
    self.questRewardLines = rewards

    local resizeHandle = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "QuestRewardResizeHandle", control, CT_LABEL)
    resizeHandle:SetDimensions(30, 24)
    resizeHandle:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -5, -3)
    resizeHandle:SetFont("ZoFontGameSmall")
    resizeHandle:SetText("|cC9B76A///|r")
    resizeHandle:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    resizeHandle:SetVerticalAlignment(TEXT_ALIGN_BOTTOM)
    resizeHandle:SetDrawLayer(DL_OVERLAY)
    resizeHandle:SetDrawTier(DT_HIGH)
    resizeHandle:SetMouseEnabled(true)
    resizeHandle:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            TPM:StartResizingQuestRewardWindow()
        end
    end)
    resizeHandle:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            TPM:StopResizingQuestRewardWindow()
        end
    end)
    self.questRewardResizeHandle = resizeHandle

    control:SetHandler("OnHide", function()
        if TPM.questRewardMoving then TPM:StopMovingQuestRewardWindow() end
        if TPM.questRewardResizing then TPM:StopResizingQuestRewardWindow() end
    end)

    self:UpdateQuestRewardLockState()
    self:ApplyQuestRewardFonts()
    self:UpdateQuestRewardLayout()
end

function TPM:HideQuestRewards()
    self.currentQuestRewardDetails = nil
    if self.questRewardInfoButton then
        self.questRewardInfoButton:SetHidden(true)
    end
    if self.questRewardControl then
        self.questRewardControl:SetHidden(true)
    end
end

function TPM:UpdateFocusedRewardPanelPolling()
    if not EVENT_MANAGER then return end
    local namespace = ADDON_NAME .. "FocusedRewardPanel"
    local shouldRun = self.saved and self.saved.showQuestRewards == true
        and self:IsFullWorldMapSceneVisible()

    if shouldRun and self.focusedRewardPanelPolling ~= true then
        EVENT_MANAGER:RegisterForUpdate(namespace, 2000, function()
            if TPM.saved and TPM.saved.showQuestRewards == true and TPM:IsFullWorldMapSceneVisible() then
                TPM:RefreshQuestRewards()
            else
                TPM:UpdateFocusedRewardPanelPolling()
            end
        end)
        self.focusedRewardPanelPolling = true
    elseif not shouldRun and self.focusedRewardPanelPolling == true then
        EVENT_MANAGER:UnregisterForUpdate(namespace)
        self.focusedRewardPanelPolling = false
    end
end

function TPM:RefreshQuestRewards(forceRender)
    -- Full-map-only UI: minimap addons may keep ZO_WorldMap visible on the HUD.
    -- The reward window belongs to the actual world-map scene only.
    if not self:IsFullWorldMapSceneVisible() then
        if self.questRewardControl then self:HideQuestRewards() end
        return
    end

    self:CreateQuestRewardControl()
    if not self.questRewardControl then return end

    -- 3.3.3: this legacy reward window belongs to the world map only.
    -- Queued refreshes can fire just after the map closes, so guard here as
    -- well as in the scene callback to prevent the window reopening on the HUD.

    -- The v2 statistics journal intentionally gets the full map viewport.
    -- Keep the movable quest-reward top-level window from floating above it.
    if self.statisticsWindow and not self.statisticsWindow:IsHidden() then
        self:HideQuestRewards()
        return
    end

    if not self.saved or not self.saved.showQuestRewards then
        self:HideQuestRewards()
        return
    end

    -- Keep the window visible whenever the map is open and the feature is
    -- enabled. Missing focus/reward data should show a useful status message
    -- instead of making the entire window disappear.
    local questIndex = self:GetFocusedQuestIndex()
    local questCacheKey = tostring(questIndex or 0) .. ":" .. tostring(self.langCode or "en")
    if forceRender ~= true and self.questRewardDirty ~= true and self.questRewardLastQuestCacheKey == questCacheKey
        and self.questRewardControl and not self.questRewardControl:IsHidden() then
        self:UpdateQuestRewardLockState()
        return
    end
    local questName = ""
    local rewardText = ""
    local rewardDetails = {}

    if not questIndex then
        questName = self:L("QUEST_REWARDS")
        rewardText = self:L("QUEST_NO_FOCUSED_QUEST")
    else
        questName = GetJournalQuestName(questIndex) or ""
        if questName == "" then
            questName = GetString(SI_QUEST_JOURNAL_UNKNOWN_QUEST_NAME)
        end

        local lines, details = self:GetQuestRewardLines(questIndex)
        rewardDetails = details or {}
        if #lines > 0 then
            rewardText = table.concat(lines, "\n")
        else
            rewardText = self:L("QUEST_NO_REWARD_DATA")
        end
    end

    self.currentQuestRewardDetails = rewardDetails
    self.questRewardLastQuestCacheKey = questCacheKey
    self.questRewardDirty = false
    if self.questRewardInfoButton then
        self.questRewardInfoButton:SetHidden(#rewardDetails == 0)
    end

    self.questRewardTitle:SetText(string.format("|cE6C45C%s|r", zo_strformat(SI_TOOLTIP_ITEM_NAME, questName)))
    self.questRewardLines:SetText(string.format("|cFFFFFF%s|r\n%s", self:L("QUEST_REWARDS"), rewardText))

    local titleTextHeight = self.questRewardTitle:GetTextHeight() or 0
    self.questRewardTitle:SetHeight(Clamp(math.max(30, titleTextHeight + 4), 30, 64))
    self:UpdateQuestRewardLayout()
    self:UpdateQuestRewardLockState()
    self:ApplyQuestRewardPosition()

    -- Show first, then auto-size. This also makes the one-frame auto-size
    -- callback reliable for a control that starts hidden after addon load.
    self.questRewardControl:SetAlpha(1)
    if self.questRewardControl.SetDrawLevel then self.questRewardControl:SetDrawLevel(100000) end
    self.questRewardControl:SetHidden(false)

    if self.questRewardScrollContainer and self.questRewardScrollContainer.ResetToTop then
        self.questRewardScrollContainer:ResetToTop()
    end

    if self.saved.questRewardAutoSize then
        local function RecheckQuestRewardAutoSize()
            if TPM.questRewardControl and not TPM.questRewardControl:IsHidden() then
                TPM:AutoSizeQuestRewardWindow()
            end
        end
        -- ESO text/icon metrics can settle after SetText(). Re-measure twice so
        -- long reward lines (especially skill points) are not clipped.
        zo_callLater(RecheckQuestRewardAutoSize, 1)
        zo_callLater(RecheckQuestRewardAutoSize, 50)
    end
end


-- v2.0.1 Tamriel Completion Journal / full statistics window -----------------
local function GetZoneNameSortKey(name)
    local key = zo_strlower(name or "")
    -- Keep A-Z intuitive for the addon languages. Cyrillic already follows a
    -- stable Unicode order; normalize common German/French accented letters so
    -- localized TPM labels sort where players expect them.
    key = key:gsub("ä", "ae"):gsub("ö", "oe"):gsub("ü", "ue"):gsub("ß", "ss")
    key = key:gsub("à", "a"):gsub("â", "a"):gsub("á", "a"):gsub("ä", "a")
    key = key:gsub("ç", "c")
    key = key:gsub("é", "e"):gsub("è", "e"):gsub("ê", "e"):gsub("ë", "e")
    key = key:gsub("î", "i"):gsub("ï", "i"):gsub("í", "i")
    key = key:gsub("ô", "o"):gsub("ö", "o"):gsub("ó", "o")
    key = key:gsub("ù", "u"):gsub("û", "u"):gsub("ü", "u"):gsub("ú", "u")
    key = key:gsub("ÿ", "y")
    return key
end

function TPM:GetPriorityQuestIdSet(progressZoneIds)
    local ids = {}
    if type(GetZoneActivityIdForZoneCompletionType) ~= "function" then return ids end
    for zoneId in pairs(progressZoneIds or {}) do
        local total = self:GetZoneCompletionActivityTotal(zoneId, ZONE_COMPLETION_TYPE_PRIORITY_QUESTS)
        for activityIndex = 1, total do
            local questId = GetZoneActivityIdForZoneCompletionType(zoneId, ZONE_COMPLETION_TYPE_PRIORITY_QUESTS, activityIndex)
            if questId and questId > 0 then ids[questId] = true end
        end
    end
    return ids
end

function TPM:IsLikelySideQuestName(name)
    if not name or name == "" then return false end
    local upper = zo_strupper(name)
    -- The quest master table contains a few development/dummy records.
    if upper:find("OUTOFDATE", 1, true) then return false end
    if upper:find("QUEST IO BUG", 1, true) then return false end
    if upper:find("DEBUG QUEST", 1, true) then return false end
    if upper:find("TEST QUEST", 1, true) then return false end
    if upper:find("PLACEHOLDER QUEST", 1, true) then return false end
    return true
end

local function TPM_GetProgressZoneScopeKey(progressZoneIds)
    local ids = {}
    for zoneId in pairs(progressZoneIds or {}) do ids[#ids + 1] = tonumber(zoneId) or 0 end
    table.sort(ids)
    if #ids == 0 then return "none" end
    if #ids == 1 then return "zone:" .. tostring(ids[1]) end
    -- The normal all-Tamriel scope is stable for a client build. A compact key
    -- avoids rescanning the entire quest master table whenever zone focus changes.
    return "zones:" .. table.concat(ids, ",")
end

function TPM:BuildSideQuestIndex(progressZoneIds)
    progressZoneIds = progressZoneIds or {}
    self.sideQuestIdsByScope = self.sideQuestIdsByScope or {}
    local scopeKey = TPM_GetProgressZoneScopeKey(progressZoneIds)
    if self.sideQuestIdsByScope[scopeKey] then
        return self.sideQuestIdsByScope[scopeKey]
    end

    local sideQuestIds = {}
    if type(GetQuestName) ~= "function"
        or type(GetQuestZoneId) ~= "function"
        or type(GetQuestType) ~= "function"
        or type(GetQuestRepeatableType) ~= "function"
        or type(HasCompletedQuest) ~= "function" then
        return sideQuestIds
    end

    local priorityQuestIds = self:GetPriorityQuestIdSet(progressZoneIds)
    local notRepeatable = _G.QUEST_REPEAT_NOT_REPEATABLE
    local normalQuestType = _G.QUEST_TYPE_NONE
    if notRepeatable == nil or normalQuestType == nil then return sideQuestIds end

    -- Index quest locations once, then reuse them across focus scopes. Keep
    -- eligibility lazy so opening one zone does not query every quest's name
    -- and type. Completion itself remains live in GetSideQuestStatistics.
    if not self.sideQuestCandidatesByZone then
        local byZone = {}
        for questId = 1, SIDE_QUEST_SCAN_MAX_ID do
            local zoneId = GetQuestZoneId(questId) or 0
            if zoneId > 0 then
                byZone[zoneId] = byZone[zoneId] or {}
                local ids = byZone[zoneId]
                ids[#ids + 1] = questId
            end
        end
        self.sideQuestCandidatesByZone = byZone
        self.sideQuestEligibilityById = {}
    end

    local eligibleById = self.sideQuestEligibilityById
    for zoneId, questIds in pairs(self.sideQuestCandidatesByZone) do
        local progressZoneId = zoneId
        if not progressZoneIds[progressZoneId] and type(GetZoneStoryZoneIdForZoneId) == "function" then
            local storyZoneId = GetZoneStoryZoneIdForZoneId(zoneId)
            if storyZoneId and storyZoneId > 0 then progressZoneId = storyZoneId end
        end
        if progressZoneIds[progressZoneId] then
            for _, questId in ipairs(questIds) do
                if not priorityQuestIds[questId] then
                    local eligible = eligibleById[questId]
                    if eligible == nil then
                        eligible = GetQuestRepeatableType(questId) == notRepeatable
                            and GetQuestType(questId) == normalQuestType
                            and self:IsLikelySideQuestName(GetQuestName(questId) or "")
                        eligibleById[questId] = eligible == true
                    end
                    if eligible then sideQuestIds[#sideQuestIds + 1] = questId end
                end
            end
        end
    end

    table.sort(sideQuestIds)
    self.sideQuestIdsByScope[scopeKey] = sideQuestIds
    return sideQuestIds
end

function TPM:GetSideQuestStatistics(progressZoneIds)
    local sideQuestIds = self:BuildSideQuestIndex(progressZoneIds) or {}
    local total = #sideQuestIds
    if total <= 0 then return nil end
    local completed = 0
    for _, questId in ipairs(sideQuestIds) do
        if HasCompletedQuest(questId) then completed = completed + 1 end
    end
    local percent = Clamp(Round((completed / total) * 100), 0, 100)
    if completed < total and percent >= 100 then percent = 99 end
    return {
        completionType = SIDE_QUEST_CATEGORY_KEY,
        name = self:L("CAT_SIDE_QUESTS"),
        completed = completed,
        total = total,
        remaining = math.max(0, total - completed),
        percent = percent,
    }
end

-- ESO intentionally does not expose the live Crown Store catalog to addons.
-- Track the curated permanent/current quest starters by stable quest ID rather
-- than localized quest name. This works identically on DE/EN/FR/ES/RU and
-- avoids a second 1..SIDE_QUEST_SCAN_MAX_ID name scan.
local CROWN_QUEST_STARTER_IDS =
{
    6299, -- The Demon Weapon
    6395, -- The Dragonguard's Legacy
    6454, -- The Coven Conspiracy
    6549, -- The Ravenwatch Inquiry
    6612, -- A Mortal's Touch
    6701, -- An Apocalyptic Situation
    6097, -- Through a Veil Darkly
    6226, -- Ruthless Competition
    5935, -- The Missing Prophecy
    6751, -- Ascending Doubt
    6843, -- Sojourn of the Druid King
    6967, -- Eye of Fate
    7079, -- Prisoner of Fate
    7290, -- A Guild in Crisis
    6130, -- Room to Spare
    7061, -- The Margins of Ire
    7325, -- A Study in Discipline
    7104, -- The Second Era of Scribing
}

function TPM:BuildCrownQuestIndex()
    if self.crownQuestIndexBuilt then return end
    self.crownQuestIndexBuilt = true
    self.crownQuestIds = {}

    if type(HasCompletedQuest) ~= "function" then return end

    local notRepeatable = _G.QUEST_REPEAT_NOT_REPEATABLE
    for _, questId in ipairs(CROWN_QUEST_STARTER_IDS) do
        local include = true
        if notRepeatable ~= nil and type(GetQuestRepeatableType) == "function" then
            include = GetQuestRepeatableType(questId) == notRepeatable
        end

        -- If the client can resolve quest metadata, ignore IDs that no longer
        -- exist in its data. Completed quests remain valid through HasCompletedQuest.
        if include and type(GetQuestName) == "function" then
            local name = GetQuestName(questId) or ""
            include = name ~= "" or HasCompletedQuest(questId) == true
        end

        if include then
            self.crownQuestIds[#self.crownQuestIds + 1] = questId
        end
    end
end

function TPM:GetCrownQuestStatistics()
    self:BuildCrownQuestIndex()
    local total = #(self.crownQuestIds or {})
    if total <= 0 then return nil end

    local completed = 0
    for _, questId in ipairs(self.crownQuestIds) do
        if HasCompletedQuest(questId) then completed = completed + 1 end
    end

    local remaining = math.max(0, total - completed)
    local percent = Clamp(Round((completed / total) * 100), 0, 100)
    if completed < total and percent >= 100 then percent = 99 end

    return {
        completionType = CROWN_QUEST_CATEGORY_KEY,
        name = self:L("CAT_CROWN_QUESTS"),
        completed = completed,
        total = total,
        remaining = remaining,
        percent = percent,
        countText = self:L("STAT_CROWN_QUEST_COUNT", completed, remaining),
        tooltipText = self:L("STAT_CROWN_QUEST_TT", completed, remaining),
    }
end

function TPM:GetStatisticsFocusZoneId()
    local zoneId = self.saved and tonumber(self.saved.statisticsFocusZoneId) or 0
    zoneId = Round(zoneId or 0)
    if zoneId <= 0 then return 0 end

    local available = self:GetAllProgressZoneIds()
    if not available[zoneId] then
        if self.saved then self.saved.statisticsFocusZoneId = 0 end
        return 0
    end
    return zoneId
end

function TPM:SetStatisticsFocusZone(zoneId)
    if not self.saved then return false end
    zoneId = Round(tonumber(zoneId) or 0)
    if zoneId > 0 and not self:GetAllProgressZoneIds()[zoneId] then return false end
    if tonumber(self.saved.statisticsFocusZoneId) == zoneId then return true end

    self.saved.statisticsFocusZoneId = zoneId
    -- 2.6.20: Keep the current 1/3, 2/3 or 3/3 page while changing zone
    -- focus. Pages 2 and 3 now have their own honest zone-aware presentation,
    -- so forcing the player back to page 1 made the selector feel jumpy.
    self.statisticsScrollOffset = 0
    self.statisticsFocusCache = nil
    self.statisticsFocusCacheZoneId = nil
    self.statisticsData = nil
    if self.statisticsWindow and not self.statisticsWindow:IsHidden() then
        -- Refresh one frame later so the custom selector can finish its click
        -- handler before the progress data and zone rows are rebuilt.
        if type(zo_callLater) == "function" then
            zo_callLater(function()
                if TPM.statisticsWindow and not TPM.statisticsWindow:IsHidden() then
                    TPM:RefreshStatisticsWindow()
                end
            end, 0)
        else
            self:RefreshStatisticsWindow()
        end
    end
    return true
end

function TPM:GetStatisticsFocusZoneChoices()
    local rows = {}
    for zoneId in pairs(self:GetAllProgressZoneIds()) do
        rows[#rows + 1] = { zoneId = zoneId, name = SafeZoneName(zoneId) }
    end
    table.sort(rows, function(a, b)
        local an, bn = GetZoneNameSortKey(a.name), GetZoneNameSortKey(b.name)
        if an == bn then return a.zoneId < b.zoneId end
        return an < bn
    end)
    return rows
end

function TPM:HideStatisticsFocusDropdown()
    if self.statisticsFocusDropdown then self.statisticsFocusDropdown:SetHidden(true) end
end

function TPM:RefreshStatisticsFocusDropdownRows()
    local dropdown = self.statisticsFocusDropdown
    local rows = self.statisticsFocusDropdownRows
    local choices = self.statisticsFocusChoices or {}
    if not dropdown or not rows then return end

    local visibleRows = #rows
    local maxOffset = math.max(0, #choices - visibleRows)
    self.statisticsFocusDropdownOffset = Clamp(Round(tonumber(self.statisticsFocusDropdownOffset) or 0), 0, maxOffset)
    local offset = self.statisticsFocusDropdownOffset
    local selectedZoneId = self:GetStatisticsFocusZoneId()

    for rowIndex, row in ipairs(rows) do
        local choice = choices[offset + rowIndex]
        if choice then
            row.TPMZoneId = choice.zoneId
            row:SetHidden(false)
            row.label:SetText(choice.name or "")
            row.selected = tonumber(choice.zoneId) == tonumber(selectedZoneId)
            if self:IsStatisticsDarkDesign() then
                row.bg:SetCenterColor(0,0,0,row.selected and .44 or .24)
                row.bg:SetEdgeColor(1,1,1,row.selected and .40 or .18)
                row.label:SetColor(1,1,1,1)
                if row.selectedMark then row.selectedMark:SetText(row.selected and "X" or ""); row.selectedMark:SetColor(1,1,1,1) end
            elseif row.selected then
                row.bg:SetCenterColor(0.16, 0.125, 0.040, 0.98)
                row.label:SetColor(1.00, 0.84, 0.26, 1)
                if row.selectedMark then row.selectedMark:SetText("X") end
            else
                row.bg:SetCenterColor(0.025, 0.022, 0.017, 0.98)
                row.label:SetColor(0.91, 0.88, 0.78, 1)
                if row.selectedMark then row.selectedMark:SetText("") end
            end
        else
            row.TPMZoneId = nil
            row.selected = false
            if row.selectedMark then row.selectedMark:SetText("") end
            row:SetHidden(true)
        end
    end

    if self.statisticsFocusScrollBar then
        self.statisticsFocusScrollBarRefreshing = true
        self.statisticsFocusScrollBar:SetMinMax(0, maxOffset)
        self.statisticsFocusScrollBar:SetValueStep(1)
        self.statisticsFocusScrollBar:SetValue(offset)
        self.statisticsFocusScrollBar:SetHidden(maxOffset <= 0)
        self.statisticsFocusScrollBarRefreshing = false
    end
end

function TPM:ScrollStatisticsFocusDropdown(delta)
    if not self.statisticsFocusDropdown or self.statisticsFocusDropdown:IsHidden() then return end
    delta = Round(tonumber(delta) or 0)
    if delta == 0 then return end
    local choices = self.statisticsFocusChoices or {}
    local visibleRows = self.statisticsFocusDropdownRows and #self.statisticsFocusDropdownRows or 9
    local maxOffset = math.max(0, #choices - visibleRows)
    self.statisticsFocusDropdownOffset = Clamp((tonumber(self.statisticsFocusDropdownOffset) or 0) - delta, 0, maxOffset)
    if self.statisticsFocusScrollBar then
        self.statisticsFocusScrollBar:SetValue(self.statisticsFocusDropdownOffset)
    else
        self:RefreshStatisticsFocusDropdownRows()
    end
end

function TPM:ToggleStatisticsFocusDropdown()
    local dropdown = self.statisticsFocusDropdown
    if not dropdown then return end
    if not dropdown:IsHidden() then
        self:HideStatisticsFocusDropdown()
        return
    end

    self.statisticsFocusChoices = { { zoneId = 0, name = self:L("STAT_FOCUS_TAMRIEL") } }
    for _, zone in ipairs(self:GetStatisticsFocusZoneChoices()) do
        self.statisticsFocusChoices[#self.statisticsFocusChoices + 1] = zone
    end

    local selectedZoneId = self:GetStatisticsFocusZoneId()
    local selectedIndex = 1
    for index, choice in ipairs(self.statisticsFocusChoices) do
        if tonumber(choice.zoneId) == tonumber(selectedZoneId) then
            selectedIndex = index
            break
        end
    end
    local visibleRows = self.statisticsFocusDropdownRows and #self.statisticsFocusDropdownRows or 9
    local maxOffset = math.max(0, #self.statisticsFocusChoices - visibleRows)
    self.statisticsFocusDropdownOffset = Clamp(selectedIndex - math.ceil(visibleRows / 2), 0, maxOffset)
    self:RefreshStatisticsFocusDropdownRows()
    dropdown:SetHidden(false)
    self:EnforceStatisticsDarkModeAfterRefresh()
end

function TPM:RefreshStatisticsFocusSelector()
    local selectedLabel = self.statisticsFocusSelectedLabel
    if not selectedLabel then return end

    local selectedZoneId = self:GetStatisticsFocusZoneId()
    if selectedZoneId > 0 then
        selectedLabel:SetText(SafeZoneName(selectedZoneId))
    else
        selectedLabel:SetText(self:L("STAT_FOCUS_TAMRIEL"))
    end

    -- Rebuild names whenever the Statistics window refreshes so client-language
    -- localization changes are reflected immediately without reopening TPM.
    self.statisticsFocusChoices = { { zoneId = 0, name = self:L("STAT_FOCUS_TAMRIEL") } }
    for _, zone in ipairs(self:GetStatisticsFocusZoneChoices()) do
        self.statisticsFocusChoices[#self.statisticsFocusChoices + 1] = zone
    end
    if self.statisticsFocusDropdown and not self.statisticsFocusDropdown:IsHidden() then
        self:RefreshStatisticsFocusDropdownRows()
    end
end

function TPM:GetStatisticsData(forceRefresh, focusZoneId)
    focusZoneId = Round(tonumber(focusZoneId) or 0)
    if focusZoneId > 0 then
        if not forceRefresh and self.statisticsFocusCache and self.statisticsFocusCacheZoneId == focusZoneId then
            return self.statisticsFocusCache
        end
    elseif not forceRefresh and self.statisticsCache then
        return self.statisticsCache
    end

    local stats =
    {
        percent = 0,
        completedObjectives = 0,
        totalObjectives = 0,
        remainingObjectives = 0,
        totalZones = 0,
        completedZones = 0,
        incompleteZones = 0,
        under50Zones = 0,
        untouchedZones = 0,
        zones = {},
        categories = {},
        focusZoneId = focusZoneId,
        isZoneFocus = focusZoneId > 0,
    }

    local categoryTotals = {}
    for _, completionType in ipairs(COMPLETION_TYPES) do
        categoryTotals[completionType] = { completed = 0, total = 0 }
    end

    local categoryRatioTotal = 0
    local categoryCount = 0
    local progressZoneIds = self:GetAllProgressZoneIds()
    if focusZoneId > 0 then
        -- Strict one-zone data source: page 1 categories, summary cards and the
        -- lower zone table are all built from this single Zone Story only.
        progressZoneIds = { [focusZoneId] = true }
        stats.focusName = SafeZoneName(focusZoneId)
    end
    for zoneId in pairs(progressZoneIds) do
        local breakdown, completed, total, percent = self:GetCompletionBreakdown(zoneId)
        if total > 0 then
            stats.totalZones = stats.totalZones + 1
            stats.completedObjectives = stats.completedObjectives + completed
            stats.totalObjectives = stats.totalObjectives + total

            if percent >= 100 then
                stats.completedZones = stats.completedZones + 1
            else
                stats.incompleteZones = stats.incompleteZones + 1
            end
            if percent < 50 then
                stats.under50Zones = stats.under50Zones + 1
            end
            if completed <= 0 then
                stats.untouchedZones = stats.untouchedZones + 1
            end

            local mapId = 0
            if type(GetMapIdByZoneId) == "function" then
                mapId = GetMapIdByZoneId(zoneId) or 0
            end

            stats.zones[#stats.zones + 1] =
            {
                zoneId = zoneId,
                mapId = mapId,
                name = SafeZoneName(zoneId),
                completed = completed,
                total = total,
                remaining = math.max(0, total - completed),
                percent = percent,
            }

            for _, row in ipairs(breakdown) do
                local aggregate = categoryTotals[row.completionType]
                if aggregate then
                    aggregate.completed = aggregate.completed + (row.completed or 0)
                    aggregate.total = aggregate.total + (row.total or 0)
                end
                if row.total and row.total > 0 then
                    categoryRatioTotal = categoryRatioTotal + ((row.completed or 0) / row.total)
                    categoryCount = categoryCount + 1
                end
            end
        end
    end

    stats.remainingObjectives = math.max(0, stats.totalObjectives - stats.completedObjectives)
    local mode = self.saved and self.saved.calculationMode or "objectives"
    if mode == "categories" then
        if categoryCount > 0 then
            stats.percent = Round((categoryRatioTotal / categoryCount) * 100)
        end
    elseif stats.totalObjectives > 0 then
        stats.percent = Round((stats.completedObjectives / stats.totalObjectives) * 100)
    end
    if stats.totalObjectives > 0 and stats.completedObjectives < stats.totalObjectives and stats.percent >= 100 then
        stats.percent = 99
    end
    stats.percent = Clamp(stats.percent, 0, 100)

    for _, completionType in ipairs(COMPLETION_TYPES) do
        local aggregate = categoryTotals[completionType]
        if aggregate and aggregate.total > 0 then
            local percent = Round((aggregate.completed / aggregate.total) * 100)
            if aggregate.completed < aggregate.total and percent >= 100 then percent = 99 end
            stats.categories[#stats.categories + 1] =
            {
                completionType = completionType,
                name = self:GetCompletionTypeName(completionType),
                completed = aggregate.completed,
                total = aggregate.total,
                remaining = math.max(0, aggregate.total - aggregate.completed),
                percent = Clamp(percent, 0, 100),
            }
        end
    end

    -- Side quests are statistics-only. They do not change the native Zone Guide
    -- completion percentage shown on the Tamriel map. Keep them directly under
    -- Main Quests in the journal because both are quest progress categories.
    local sideQuestStats = self:GetSideQuestStatistics(progressZoneIds)
    if sideQuestStats then
        local insertAt = 1
        for index, category in ipairs(stats.categories) do
            if category.completionType == ZONE_COMPLETION_TYPE_PRIORITY_QUESTS then
                insertAt = index + 1
                break
            end
        end
        table.insert(stats.categories, insertAt, sideQuestStats)
    end

    -- Crown Store quest starters are a journal-only statistic. They never alter
    -- ESO's native zone-completion percentage. Keep them next to Main/Side Quests.
    -- Crown Store quest starters are account-wide and cannot be attributed
    -- reliably to one Zone Story, so hide that one journal-only row while a
    -- specific-zone focus is active. Native and zone-attributable rows remain.
    if focusZoneId <= 0 then
        local crownQuestStats = self:GetCrownQuestStatistics()
        if crownQuestStats then
            local insertAt = 1
            for index, category in ipairs(stats.categories) do
                if category.completionType == SIDE_QUEST_CATEGORY_KEY then
                    insertAt = index + 1
                    break
                elseif category.completionType == ZONE_COMPLETION_TYPE_PRIORITY_QUESTS then
                    insertAt = index + 1
                end
            end
            table.insert(stats.categories, insertAt, crownQuestStats)
        end
    else
        -- 2.6.19: Zone Focus also surfaces the Update 49 special mount sold by
        -- that zone's Stablemaster. This row is informational only and does not
        -- count toward Tamriel/Zone Guide completion.
        local mount = ZONE_STABLEMASTER_MOUNTS[focusZoneId]
        if mount then
            stats.categories[#stats.categories + 1] =
            {
                completionType = ZONE_STABLE_MOUNT_CATEGORY_KEY,
                name = self:L("STAT_ZONE_STABLE_MOUNT"),
                completed = 0,
                total = 0,
                remaining = 0,
                percent = 0,
                informational = true,
                countText = self:L("STAT_ZONE_STABLE_MOUNT_AVAILABLE", 4),
                tooltipText = self:L("STAT_ZONE_STABLE_MOUNT_TT", mount.name, ZO_CommaDelimitNumber and ZO_CommaDelimitNumber(mount.price) or tostring(mount.price)),
            }
        end
    end

    -- Zone list remains alphabetical. Completion-category ordering is now
    -- controlled independently by the 2.6.8 sort bar (All / A-Z / 0->100 / 100->0).
    table.sort(stats.zones, function(a, b)
        local an = GetZoneNameSortKey(a.name)
        local bn = GetZoneNameSortKey(b.name)
        if an == bn then return a.zoneId < b.zoneId end
        return an < bn
    end)

    if focusZoneId > 0 then
        self.statisticsFocusCache = stats
        self.statisticsFocusCacheZoneId = focusZoneId
    else
        self.statisticsCache = stats
    end
    return stats
end

function TPM:SetStatisticsBarPercent(fill, width, percent)
    if not fill then return end
    width = math.max(1, tonumber(width) or 1)
    percent = Clamp(tonumber(percent) or 0, 0, 100)
    fill:SetWidth(math.max(1, width * (percent / 100)))
    local r, g, b = self:GetStatisticsProgressColor(percent)
    fill:SetCenterColor(r, g, b, 0.82)
end

function TPM:CreateStatisticsSummaryCard(parent, name, x, width, iconTexture)
    local card = WINDOW_MANAGER:CreateControl(name, parent, CT_BACKDROP)
    card:SetDimensions(width, 74)
    card:SetAnchor(TOPLEFT, parent, TOPLEFT, x, 116)
    card:SetCenterColor(0.08, 0.10, 0.13, 0.96)
    card:SetEdgeColor(0.30, 0.62, 0.82, 0.85)
    card:SetEdgeTexture(nil, 1, 1, 1)
    card:SetMouseEnabled(false)

    local topGlow = WINDOW_MANAGER:CreateControl(nil, card, CT_BACKDROP)
    topGlow:SetDimensions(width - 2, 2)
    topGlow:SetAnchor(TOPLEFT, card, TOPLEFT, 1, 1)
    topGlow:SetCenterColor(0.88, 0.67, 0.18, 0.55)
    topGlow:SetEdgeColor(0, 0, 0, 0)

    local compact = width <= 150
    local iconSize = compact and 30 or 38
    local iconX = compact and 7 or 10
    local textX = compact and 39 or 52
    local textWidth = width - textX - 5

    local icon = WINDOW_MANAGER:CreateControl(nil, card, CT_TEXTURE)
    icon:SetDimensions(iconSize, iconSize)
    icon:SetAnchor(LEFT, card, LEFT, iconX, 0)
    icon:SetTexture(iconTexture or "NagaMapaCompleto/art/stat_objectives.dds")
    icon:SetColor(0.94, 0.76, 0.26, 0.96)

    local title = WINDOW_MANAGER:CreateControl(name .. "Title", card, CT_LABEL)
    title:SetDimensions(textWidth, compact and 34 or 32)
    title:SetAnchor(TOPLEFT, card, TOPLEFT, textX, compact and 4 or 7)
    title:SetFont(compact and "$(MEDIUM_FONT)|12" or "$(MEDIUM_FONT)|14")
    title:SetColor(0.79, 0.74, 0.64, 1)
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local value = WINDOW_MANAGER:CreateControl(name .. "Value", card, CT_LABEL)
    value:SetDimensions(textWidth, 28)
    value:SetAnchor(TOPLEFT, card, TOPLEFT, textX, compact and 39 or 39)
    value:SetFont(compact and "$(BOLD_FONT)|18" or "$(BOLD_FONT)|21")
    value:SetColor(0.98, 0.82, 0.28, 1)
    value:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    value:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    return { control = card, title = title, value = value, icon = icon, topGlow = topGlow }
end

function TPM:CreateProgressPlaytimeCard(parent, name, x, width)
    local card = WINDOW_MANAGER:CreateControl(name, parent, CT_BACKDROP)
    card:SetDimensions(width, 74)
    card:SetAnchor(TOPLEFT, parent, TOPLEFT, x, 116)
    card:SetCenterColor(0.020, 0.019, 0.016, 0.98)
    card:SetEdgeColor(0.48, 0.66, 0.22, 0.92)
    card:SetEdgeTexture(nil, 1, 1, 1)
    card:SetMouseEnabled(false)

    local topGlow = WINDOW_MANAGER:CreateControl(nil, card, CT_BACKDROP)
    topGlow:SetDimensions(width - 2, 2)
    topGlow:SetAnchor(TOPLEFT, card, TOPLEFT, 1, 1)
    topGlow:SetCenterColor(0.64, 0.88, 0.28, 0.58)
    topGlow:SetEdgeColor(0, 0, 0, 0)

    local icon = WINDOW_MANAGER:CreateControl(nil, card, CT_TEXTURE)
    icon:SetDimensions(30, 30)
    icon:SetAnchor(LEFT, card, LEFT, 7, -4)
    icon:SetTexture("NagaMapaCompleto/art/tamriel_wreath.dds")
    icon:SetColor(0.68, 0.92, 0.34, 0.96)

    local title = WINDOW_MANAGER:CreateControl(name .. "Title", card, CT_LABEL)
    title:SetDimensions(width - 44, 20)
    title:SetAnchor(TOPLEFT, card, TOPLEFT, 40, 4)
    title:SetFont("$(BOLD_FONT)|12")
    title:SetColor(0.82, 0.78, 0.68, 1)
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local value = WINDOW_MANAGER:CreateControl(name .. "Value", card, CT_LABEL)
    value:SetDimensions(width - 44, 25)
    value:SetAnchor(TOPLEFT, card, TOPLEFT, 40, 24)
    value:SetFont("$(ANTIQUE_FONT)|19")
    value:SetColor(0.68, 0.94, 0.28, 1)
    value:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    value:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local detail = WINDOW_MANAGER:CreateControl(name .. "Detail", card, CT_LABEL)
    detail:SetDimensions(width - 12, 18)
    detail:SetAnchor(BOTTOM, card, BOTTOM, 0, -5)
    detail:SetFont("$(MEDIUM_FONT)|11")
    detail:SetColor(0.74, 0.70, 0.60, 1)
    detail:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    detail:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    detail:SetHidden(false)

    return { control = card, title = title, value = value, detail = detail, icon = icon, topGlow = topGlow }
end

function TPM:CreateStatisticsCategoryRow(parent, index, controlPrefix)
    local column = index <= 8 and 1 or 2
    local rowIndex = column == 1 and index or (index - 8)
    local x = column == 1 and 30 or 518
    local y = 234 + ((rowIndex - 1) * 20)

    local prefix = controlPrefix or "StatsCategory"
    local row = WINDOW_MANAGER:CreateControl(ADDON_NAME .. prefix .. tostring(index), parent, CT_CONTROL)
    row:SetDimensions(442, 20)
    row:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    row:SetMouseEnabled(false)

    local rowBg = WINDOW_MANAGER:CreateControl(nil, row, CT_BACKDROP)
    rowBg:SetAnchorFill(row)
    rowBg:SetCenterColor(0.035, 0.031, 0.024, rowIndex % 2 == 0 and 0.34 or 0.18)
    rowBg:SetEdgeColor(0.28, 0.23, 0.12, 0.20)
    rowBg:SetEdgeTexture(nil, 1, 1, 1)
    rowBg:SetMouseEnabled(false)

    local icon = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
    icon:SetDimensions(18, 18)
    icon:SetAnchor(LEFT, row, LEFT, 5, 0)
    icon:SetTexture("NagaMapaCompleto/art/cat_quests.dds")
    icon:SetColor(0.86, 0.70, 0.28, 0.82)

    local label = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    label:SetDimensions(166, 20)
    label:SetAnchor(LEFT, row, LEFT, 29, 0)
    label:SetFont("$(MEDIUM_FONT)|16")
    label:SetColor(0.90, 0.94, 0.98, 1)
    label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local count = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    count:SetDimensions(92, 20)
    count:SetAnchor(LEFT, row, LEFT, 188, 0)
    count:SetFont("$(MEDIUM_FONT)|15")
    count:SetColor(0.70, 0.82, 0.92, 1)
    count:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    count:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local bar = WINDOW_MANAGER:CreateControl(nil, row, CT_BACKDROP)
    bar:SetDimensions(98, 8)
    bar:SetAnchor(LEFT, row, LEFT, 292, 0)
    bar:SetCenterColor(0.018, 0.016, 0.013, 0.92)
    bar:SetEdgeColor(0.38, 0.30, 0.13, 0.72)
    bar:SetEdgeTexture(nil, 1, 1, 1)

    local fill = WINDOW_MANAGER:CreateControl(nil, bar, CT_BACKDROP)
    fill:SetDimensions(1, 6)
    fill:SetAnchor(LEFT, bar, LEFT, 1, 0)
    fill:SetCenterColor(0.78, 0.59, 0.16, 0.96)
    fill:SetEdgeColor(0, 0, 0, 0)

    local percent = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    percent:SetDimensions(42, 20)
    percent:SetAnchor(RIGHT, row, RIGHT, -3, 0)
    percent:SetFont("$(BOLD_FONT)|15")
    percent:SetColor(0.90, 0.80, 0.48, 1)
    percent:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    percent:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    -- 2.6.25: The old information button is now a real settings gear. One
    -- click enters the HUD editor; clicking the gear again saves position and
    -- size. No help popup is shown here anymore.
    local gearButton = WINDOW_MANAGER:CreateControl(nil, row, CT_BUTTON)
    gearButton:SetDimensions(18, 18)
    gearButton:SetAnchor(LEFT, row, RIGHT, 4, 0)
    gearButton:SetMouseEnabled(true)
    gearButton:SetHidden(true)
    local gearIcon = WINDOW_MANAGER:CreateControl(nil, gearButton, CT_TEXTURE)
    gearIcon:SetDimensions(16, 16)
    gearIcon:SetAnchor(CENTER, gearButton, CENTER, 0, 0)
    gearIcon:SetTexture("NagaMapaCompleto/art/settings_gear.dds")
    gearIcon:SetColor(0.88, 0.82, 0.64, 0.92)
    gearIcon:SetMouseEnabled(false)
    gearButton.TPMIcon = gearIcon

    return { control = row, label = label, count = count, bar = bar, fill = fill, percent = percent, icon = icon, bg = rowBg, gearButton = gearButton }
end

-- Returns the live account collection count reported by ESO for one
-- CollectibleCategoryType. The category-type API is intentionally used here:
-- GetCollectibleCategoryInfo expects a Collections-book top-level index, not a
-- CollectibleCategoryType. Using ESO's dedicated type counters avoids both that
-- mismatch and an expensive scan across all collectible IDs.
function TPM:GetCollectionStatisticData(definition)
    if type(definition) ~= "table" then return nil end

    local categoryType = _G[definition.typeGlobal]
    local data =
    {
        name = self:L(definition.labelKey),
        owned = 0,
        total = 0,
        percent = 0,
        icon = nil,
        available = false,
    }

    if type(categoryType) ~= "number"
        or type(GetTotalCollectiblesByCategoryType) ~= "function"
        or type(GetTotalUnlockedCollectiblesByCategoryType) ~= "function" then
        return data
    end

    local total = tonumber(GetTotalCollectiblesByCategoryType(categoryType)) or 0
    local owned = tonumber(GetTotalUnlockedCollectiblesByCategoryType(categoryType)) or 0
    if total < 0 then total = 0 end
    owned = Clamp(owned, 0, total)

    -- Use real ESO collectible art for the collection rows. Some category-icon
    -- lookups return ESO's generic question-mark placeholder for categories such
    -- as markings, hair or fragments. Prefer an actual collectible icon first;
    -- only fall back to the Collections-book category icon when needed.
    local function IsUsableCollectionIcon(texture)
        if type(texture) ~= "string" or texture == "" then return false end
        local lower = zo_strlower(texture)
        if lower == zo_strlower(tostring(ZO_NO_TEXTURE_FILE or "")) then return false end
        if string.find(lower, "question", 1, true)
            or string.find(lower, "unknown", 1, true)
            or string.find(lower, "missing", 1, true)
            or string.find(lower, "placeholder", 1, true) then
            return false
        end
        return true
    end

    if total > 0 and type(GetCollectibleIdFromType) == "function" then
        local collectibleId = nil
        -- A few collection types can have an unusable first slot. Look through a
        -- handful of entries and keep the first one with real artwork.
        local probeCount = math.min(total, 12)
        for collectibleIndex = 1, probeCount do
            local candidateId = GetCollectibleIdFromType(categoryType, collectibleIndex)
            if candidateId and candidateId > 0 then
                collectibleId = candidateId
                if type(GetCollectibleIcon) == "function" then
                    local collectibleIcon = GetCollectibleIcon(candidateId)
                    if IsUsableCollectionIcon(collectibleIcon) then
                        data.icon = collectibleIcon
                        break
                    end
                end
            end
        end

        if collectibleId and not data.icon
            and type(GetCategoryInfoFromCollectibleId) == "function"
            and type(GetCollectibleCategoryKeyboardIcons) == "function" then
            local topLevelIndex, categoryIndex = GetCategoryInfoFromCollectibleId(collectibleId)
            if topLevelIndex then
                local normalIcon = GetCollectibleCategoryKeyboardIcons(topLevelIndex, categoryIndex)
                if IsUsableCollectionIcon(normalIcon) then
                    data.icon = normalIcon
                end
            end
        end
    end

    data.total = total
    data.owned = owned
    data.percent = total > 0 and Round((owned / total) * 100) or 0
    data.available = true
    return data
end

-- 2.6.14: Achievement category names returned by ESO follow the GAME client
-- language, while TPM intentionally supports its own live DE/EN/RU/FR/ES language
-- switch. Normalize the known top-level category names from all four supported
-- client languages and route them through TPM localization. Unknown/new ESO
-- categories safely fall back to the API name instead of being hidden.
local function TPM_NormalizeAchievementCategoryName(name)
    local value = zo_strlower(tostring(name or ""))
    value = value:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    value = value:gsub("[’'`´]", "")
    value = value:gsub("[%s%-%–%—_/%.,:&]+", "")
    return value
end

local ACHIEVEMENT_CATEGORY_LOCALIZATION_ALIASES = {}
local function TPM_RegisterAchievementCategoryAliases(key, aliases)
    for _, alias in ipairs(aliases or {}) do
        ACHIEVEMENT_CATEGORY_LOCALIZATION_ALIASES[TPM_NormalizeAchievementCategoryName(alias)] = key
    end
end

TPM_RegisterAchievementCategoryAliases("STAT_ACH_CAT_CHARACTER", {
    "Charakter", "Character", "Personnage", "Персонаж",
})
TPM_RegisterAchievementCategoryAliases("STAT_ACH_CAT_RECENT_SEASONS", {
    "Jüngste Seasons", "Jüngste Saisons", "Recent Seasons", "Saisons récentes", "Последние сезоны",
})
TPM_RegisterAchievementCategoryAliases("STAT_ACH_CAT_QUESTS", {
    "Quests", "Quêtes", "Задания", "Квесты",
})
TPM_RegisterAchievementCategoryAliases("STAT_ACH_CAT_CRAFTING", {
    "Handwerk", "Crafting", "Artisanat", "Ремесло",
})
TPM_RegisterAchievementCategoryAliases("STAT_ACH_CAT_EXPLORATION", {
    "Erkunden", "Exploration", "Исследование",
})
TPM_RegisterAchievementCategoryAliases("STAT_ACH_CAT_PVP", {
    "Spieler gegen Spieler", "Player vs Player", "Player versus Player", "Joueur contre joueur", "Игрок против игрока",
})
TPM_RegisterAchievementCategoryAliases("STAT_ACH_CAT_DUNGEONS", {
    "Verliese", "Dungeons", "Donjons", "Подземелья",
})
TPM_RegisterAchievementCategoryAliases("STAT_ACH_CAT_HOUSING", {
    "Wohnen", "Housing", "Logement", "Жильё", "Жилье",
})
TPM_RegisterAchievementCategoryAliases("STAT_ACH_CAT_FESTIVALS", {
    "Feste und Feiern", "Festivals and Celebrations", "Festivals & Events", "Events", "Fêtes et événements", "Fêtes et célébrations", "Праздники и события", "Праздники",
})
TPM_RegisterAchievementCategoryAliases("STAT_ACH_CAT_ARENAS", {
    "Arenen", "Arenas", "Arènes", "Арены",
})
TPM_RegisterAchievementCategoryAliases("STAT_ACH_CAT_DLC_DUNGEONS", {
    "DLC-Verliese", "DLC Dungeons", "Donjons de DLC", "DLC-подземелья", "Подземелья DLC",
})
TPM_RegisterAchievementCategoryAliases("STAT_ACH_CAT_ENDLESS_ARCHIVE", {
    "Endloses Archiv", "Endless Archive", "Archives infinies", "Бесконечный архив",
})
TPM_RegisterAchievementCategoryAliases("STAT_ACH_CAT_NIGHT_MARKET", {
    "Nachtmarkt", "Night Market", "Marché nocturne", "Ночной рынок",
})
TPM_RegisterAchievementCategoryAliases("STAT_ACH_CAT_TRIALS", {
    "Prüfungen", "Trials", "Épreuves", "Испытания",
})
TPM_RegisterAchievementCategoryAliases("STAT_ACHIEVEMENT_OTHER", {
    "Weitere Errungenschaften", "Other Achievements", "Autres succès", "Другие достижения",
})

function TPM:GetLocalizedAchievementCategoryName(apiName)
    local key = ACHIEVEMENT_CATEGORY_LOCALIZATION_ALIASES[TPM_NormalizeAchievementCategoryName(apiName)]
    if key then return self:L(key) end
    return zo_strformat("<<C:1>>", tostring(apiName or ""))
end

-- 2.6.20: Conservative zone-focused achievement summary. ESO does not expose
-- one universal "all achievements for zoneId" API, so we do not pretend it does.
-- Instead we use ESO's own achievement hierarchy plus the client-localized zone
-- name: achievements in a matching subcategory, or whose own name/description
-- explicitly references the zone, are aggregated into one safe zone row.
local function TPM_NormalizeZoneAchievementText(value)
    local text = zo_strlower(tostring(value or ""))
    text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    text = text:gsub("[’'`´]", "")
    text = text:gsub("[%s%-%–%—_/%.,:&]+", "")
    return text
end

function TPM:GetZoneAchievementSummary(zoneId)
    zoneId = Round(tonumber(zoneId) or 0)
    if zoneId <= 0 then return nil end
    self.zoneAchievementSummaryCache = self.zoneAchievementSummaryCache or {}
    if self.zoneAchievementSummaryCache[zoneId] then
        return self.zoneAchievementSummaryCache[zoneId]
    end
    if type(GetNumAchievementCategories) ~= "function"
        or type(GetAchievementCategoryInfo) ~= "function"
        or type(GetAchievementSubCategoryInfo) ~= "function"
        or type(GetAchievementId) ~= "function"
        or type(GetAchievementInfo) ~= "function" then
        return nil
    end

    local needles = {}
    local function AddNeedle(name)
        local key = TPM_NormalizeZoneAchievementText(name)
        if key ~= "" then needles[key] = true end
    end
    AddNeedle(SafeZoneName(zoneId))
    if type(GetZoneNameById) == "function" then AddNeedle(GetZoneNameById(zoneId)) end

    local function TextMatches(value)
        local haystack = TPM_NormalizeZoneAchievementText(value)
        if haystack == "" then return false end
        for needle in pairs(needles) do
            if #needle >= 4 and string.find(haystack, needle, 1, true) then return true end
        end
        return false
    end

    local seen = {}
    local earnedPoints, totalPoints, matchedCount, completedCount = 0, 0, 0, 0
    local function AddAchievement(achievementId, forceMatch)
        achievementId = tonumber(achievementId) or 0
        if achievementId <= 0 or seen[achievementId] then return end
        local name, description, points, icon, completed = GetAchievementInfo(achievementId)
        if not forceMatch and not TextMatches(name) and not TextMatches(description) then return end
        seen[achievementId] = true
        points = math.max(0, tonumber(points) or 0)
        totalPoints = totalPoints + points
        matchedCount = matchedCount + 1
        if completed == true then
            earnedPoints = earnedPoints + points
            completedCount = completedCount + 1
        end
    end

    local numCategories = tonumber(GetNumAchievementCategories()) or 0
    for topIndex = 1, numCategories do
        local _, numSubCategories, numTopAchievements = GetAchievementCategoryInfo(topIndex)
        numSubCategories = tonumber(numSubCategories) or 0
        numTopAchievements = tonumber(numTopAchievements) or 0
        for achievementIndex = 1, numTopAchievements do
            AddAchievement(GetAchievementId(topIndex, nil, achievementIndex), false)
        end
        for subIndex = 1, numSubCategories do
            local subName, numAchievements = GetAchievementSubCategoryInfo(topIndex, subIndex)
            local forceSubcategory = TextMatches(subName)
            numAchievements = tonumber(numAchievements) or 0
            for achievementIndex = 1, numAchievements do
                AddAchievement(GetAchievementId(topIndex, subIndex, achievementIndex), forceSubcategory)
            end
        end
    end

    local percent = totalPoints > 0 and Clamp(Round((earnedPoints / totalPoints) * 100), 0, 100) or 0
    local result =
    {
        name = self:L("STAT_ZONE_ACHIEVEMENTS"),
        earned = earnedPoints,
        total = totalPoints,
        percent = percent,
        icon = "NagaMapaCompleto/art/stat_complete.dds",
        isTotal = true,
        tooltipText = self:L("STAT_ZONE_ACHIEVEMENTS_TT", completedCount, matchedCount),
    }
    self.zoneAchievementSummaryCache[zoneId] = result
    return result
end

-- 2.6.0: Achievement completion page. ESO exposes earned/total points per
-- top-level achievement category, so TPM can stay update-safe without keeping
-- a hard-coded achievement-id database. These values are informational only and
-- NEVER affect the normal Tamriel completion percentage.
function TPM:GetAchievementStatisticsData()
    local rows = {}
    if type(GetNumAchievementCategories) ~= "function"
        or type(GetAchievementCategoryInfo) ~= "function" then
        return rows
    end

    local categories = {}
    local summedEarned, summedTotal = 0, 0
    local numCategories = tonumber(GetNumAchievementCategories()) or 0

    for categoryIndex = 1, numCategories do
        local name, _, _, earnedPoints, totalPoints = GetAchievementCategoryInfo(categoryIndex)
        earnedPoints = math.max(0, tonumber(earnedPoints) or 0)
        totalPoints = math.max(0, tonumber(totalPoints) or 0)
        if totalPoints > 0 and type(name) == "string" and name ~= "" then
            local icon = nil
            if type(GetAchievementCategoryKeyboardIcons) == "function" then
                icon = select(1, GetAchievementCategoryKeyboardIcons(categoryIndex))
            end
            categories[#categories + 1] =
            {
                name = self:GetLocalizedAchievementCategoryName(name),
                earned = math.min(earnedPoints, totalPoints),
                total = totalPoints,
                percent = Clamp(Round((earnedPoints / totalPoints) * 100), 0, 100),
                icon = icon,
            }
            summedEarned = summedEarned + math.min(earnedPoints, totalPoints)
            summedTotal = summedTotal + totalPoints
        end
    end

    local totalEarned = type(GetEarnedAchievementPoints) == "function" and tonumber(GetEarnedAchievementPoints()) or summedEarned
    local totalPoints = type(GetTotalAchievementPoints) == "function" and tonumber(GetTotalAchievementPoints()) or summedTotal
    totalEarned = math.max(0, totalEarned or 0)
    totalPoints = math.max(0, totalPoints or 0)
    if totalPoints > 0 then totalEarned = math.min(totalEarned, totalPoints) end

    rows[#rows + 1] =
    {
        name = self:L("STAT_ACHIEVEMENT_TOTAL"),
        earned = totalEarned,
        total = totalPoints,
        percent = totalPoints > 0 and Clamp(Round((totalEarned / totalPoints) * 100), 0, 100) or 0,
        icon = "NagaMapaCompleto/art/stat_complete.dds",
        isTotal = true,
    }

    -- The shared category grid has 16 slots. Reserve one for the account-wide
    -- total. If ESO ever exposes more than 15 top-level categories, combine the
    -- overflow instead of letting rows spill outside the panel.
    local maxCategoryRows = 15
    if #categories <= maxCategoryRows then
        for _, data in ipairs(categories) do rows[#rows + 1] = data end
    else
        for index = 1, maxCategoryRows - 1 do
            rows[#rows + 1] = categories[index]
        end
        local otherEarned, otherTotal = 0, 0
        for index = maxCategoryRows, #categories do
            otherEarned = otherEarned + categories[index].earned
            otherTotal = otherTotal + categories[index].total
        end
        rows[#rows + 1] =
        {
            name = self:L("STAT_ACHIEVEMENT_OTHER"),
            earned = otherEarned,
            total = otherTotal,
            percent = otherTotal > 0 and Clamp(Round((otherEarned / otherTotal) * 100), 0, 100) or 0,
            icon = "NagaMapaCompleto/art/stat_objectives.dds",
        }
    end

    return rows
end

function TPM:SetStatisticsCompletionPage(page)
    self:HideStatisticsHoverTooltips()
    self:HideStatisticsFocusDropdown()
    page = Clamp(Round(tonumber(page) or 1), 1, 3)
    if self.saved then self.saved.statisticsCompletionPage = page end
    self.statisticsCompletionPage = page
    if self.statisticsWindow and not self.statisticsWindow:IsHidden() then
        self:RefreshStatisticsWindow()
    end
end

function TPM:GetStatisticsCompletionPage()
    local page = self.saved and tonumber(self.saved.statisticsCompletionPage) or tonumber(self.statisticsCompletionPage) or 1
    return Clamp(Round(page), 1, 3)
end

-- 2.6.8: The three completion sub-pages share one compact sort control.
-- "all" preserves each page's natural/original order. A-Z always sorts the
-- names currently displayed to the player, so TPM-localized category names
-- automatically follow the selected addon language.
function TPM:GetStatisticsCategorySortMode()
    local mode = self.saved and self.saved.statisticsCategorySortMode or "all"
    if mode ~= "all" and mode ~= "name" and mode ~= "asc" and mode ~= "desc" then
        mode = "all"
    end
    return mode
end

function TPM:SetStatisticsCategorySortMode(mode)
    if mode ~= "all" and mode ~= "name" and mode ~= "asc" and mode ~= "desc" then return false end
    if self.saved then self.saved.statisticsCategorySortMode = mode end
    self:HideStatisticsHoverTooltips()
    if self.statisticsWindow and not self.statisticsWindow:IsHidden() then
        self:RefreshStatisticsWindow()
    end
    return true
end

local function TPM_CopyArray(rows)
    local copy = {}
    for index, row in ipairs(rows or {}) do copy[index] = row end
    return copy
end

function TPM:SortStatisticsCategoryData(rows, keepTotalFirst)
    local mode = self:GetStatisticsCategorySortMode()
    local copy = TPM_CopyArray(rows)
    if mode == "all" or #copy <= 1 then return copy end

    local pinnedTotal = nil
    if keepTotalFirst then
        for index, row in ipairs(copy) do
            if row and row.isTotal then
                pinnedTotal = row
                table.remove(copy, index)
                break
            end
        end
    end

    -- Informational rows (for example the zone Stablemaster mount) are not
    -- completion percentages and therefore must not jump to the top in 0->100
    -- sorting. Keep them at the bottom regardless of the selected sort mode.
    local informationalRows = {}
    for index = #copy, 1, -1 do
        local row = copy[index]
        if row and row.informational then
            table.insert(informationalRows, 1, row)
            table.remove(copy, index)
        end
    end

    local function NameKey(row)
        return GetZoneNameSortKey(tostring(row and row.name or ""))
    end
    table.sort(copy, function(a, b)
        if mode == "name" then
            local an, bn = NameKey(a), NameKey(b)
            if an == bn then return tostring(a.name or "") < tostring(b.name or "") end
            return an < bn
        end

        local ap = Clamp(tonumber(a and a.percent) or 0, 0, 100)
        local bp = Clamp(tonumber(b and b.percent) or 0, 0, 100)
        if ap == bp then
            local an, bn = NameKey(a), NameKey(b)
            if an == bn then return tostring(a.name or "") < tostring(b.name or "") end
            return an < bn
        end
        if mode == "desc" then return ap > bp end
        return ap < bp
    end)

    if pinnedTotal then table.insert(copy, 1, pinnedTotal) end
    for _, row in ipairs(informationalRows) do copy[#copy + 1] = row end
    return copy
end

function TPM:RefreshStatisticsCategorySortControls()
    local mode = self:GetStatisticsCategorySortMode()
    local buttons = self.statisticsCategorySortButtons or {}
    local labels =
    {
        all = self:L("FILTER_ALL"),
        name = self:L("STAT_SORT_ALPHABETICAL"),
        asc = "0→100%",
        desc = "100→0%",
    }
    for key, button in pairs(buttons) do
        if button then
            button:SetText(labels[key] or key)
            local selected = key == mode
            button:SetNormalFontColor(selected and 1.00 or 0.76, selected and 0.84 or 0.72, selected and 0.26 or 0.58, 1)
            if button.TPMBackdrop then
                button.TPMBackdrop:SetCenterColor(selected and 0.16 or 0.035, selected and 0.12 or 0.031, selected and 0.025 or 0.024, selected and 0.96 or 0.72)
                button.TPMBackdrop:SetEdgeColor(selected and 0.78 or 0.30, selected and 0.60 or 0.24, selected and 0.12 or 0.12, selected and 0.90 or 0.45)
            end
        end
    end
end

-- 2.6.1: All hover panels that belong to the Tamriel Statistics journal use
-- the same screen position and draw above the journal. This prevents ESO's
-- shared InformationTooltip from being hidden behind the statistics window.
function TPM:AnchorStatisticsHoverTooltip(tip, yOffset)
    if not tip then return end
    tip:ClearAnchors()
    if self.statisticsWindow and not self.statisticsWindow:IsHidden() then
        tip:SetAnchor(TOPLEFT, self.statisticsWindow, TOPRIGHT, 10, tonumber(yOffset) or 58)
    elseif GuiRoot then
        tip:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -18, 80)
    end
    if tip.BringWindowToTop then tip:BringWindowToTop() end
    tip:SetHidden(false)
end

function TPM:HideStatisticsHoverTooltips()
    local tooltips =
    {
        self.statisticsHoverTooltip,
        self.statisticsAchievementTooltip,
        self.statisticsLogHelpTooltip,
    }
    for _, tip in ipairs(tooltips) do
        if tip then
            tip.TPMSourceControl = nil
            tip:SetHidden(true)
        end
    end
    if InformationTooltip then ClearTooltip(InformationTooltip) end
end

-- 2.6.4: Do not rely only on OnMouseExit for statistics hover panels. ESO can
-- skip that callback when small nested controls are clicked or hidden during a
-- refresh. Each hover panel remembers the control that opened it and closes
-- itself as soon as the cursor is no longer above that control.
local function TPM_ArmStatisticsHoverTooltip(tip, sourceControl)
    if not tip then return end
    tip.TPMSourceControl = sourceControl
    tip.TPMHoverLeaveAt = nil
    -- 2.7.27: Help panels opened from tiny controls (especially the
    -- Completion Categories gear) used to disappear on the very next frame
    -- as soon as the cursor left the 18x18 button. Make the tooltip itself
    -- hoverable and add a short grace period so the cursor can travel from
    -- the gear to the help panel without flicker.
    if tip.SetMouseEnabled then tip:SetMouseEnabled(true) end
    if tip.TPMAutoHideInstalled then return end
    tip.TPMAutoHideInstalled = true
    tip:SetHandler("OnUpdate", function(panel)
        if panel:IsHidden() then return end
        if not TPM.statisticsWindow or TPM.statisticsWindow:IsHidden() then
            panel.TPMSourceControl = nil
            panel.TPMHoverLeaveAt = nil
            panel:SetHidden(true)
            return
        end

        local overSource, overPanel = false, false
        local source = panel.TPMSourceControl
        if source then overSource = MouseIsOver(source) == true end
        overPanel = MouseIsOver(panel) == true

        if overSource or overPanel then
            panel.TPMHoverLeaveAt = nil
            return
        end

        local nowMs = type(GetFrameTimeMilliseconds) == "function" and (GetFrameTimeMilliseconds() or 0) or 0
        if panel.TPMHoverLeaveAt == nil then
            panel.TPMHoverLeaveAt = nowMs
            return
        end
        if (nowMs - panel.TPMHoverLeaveAt) >= 650 then
            panel.TPMSourceControl = nil
            panel.TPMHoverLeaveAt = nil
            panel:SetHidden(true)
        end
    end)
end

local function TPM_EnsureStatisticsHoverTooltip()
    if TPM.statisticsHoverTooltip then return TPM.statisticsHoverTooltip end
    if not WINDOW_MANAGER or not GuiRoot then return nil end

    local tip = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "StatisticsHoverTooltip")
    tip:SetDimensions(360, 96)
    tip:SetHidden(true)
    tip:SetMouseEnabled(false)
    tip:SetMovable(false)
    if tip.SetClampedToScreen then tip:SetClampedToScreen(true) end
    if tip.SetDrawTier and DT_HIGH then tip:SetDrawTier(DT_HIGH) end
    if tip.SetDrawLayer and DL_OVERLAY then tip:SetDrawLayer(DL_OVERLAY) end
    if tip.SetDrawLevel then tip:SetDrawLevel(13000) end

    local bg = WINDOW_MANAGER:CreateControl(nil, tip, CT_BACKDROP)
    bg:SetAnchorFill()
    bg:SetCenterColor(0.035, 0.031, 0.026, 0.985)
    bg:SetEdgeColor(0.92, 0.76, 0.14, 0.96)
    bg:SetEdgeTexture(nil, 1, 1, 1)

    local title = WINDOW_MANAGER:CreateControl(nil, tip, CT_LABEL)
    title:SetAnchor(TOPLEFT, tip, TOPLEFT, 14, 12)
    title:SetAnchor(TOPRIGHT, tip, TOPRIGHT, -14, 12)
    title:SetHeight(28)
    title:SetFont("ZoFontWinH3")
    title:SetColor(0.98, 0.96, 0.90, 1)
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local body = WINDOW_MANAGER:CreateControl(nil, tip, CT_LABEL)
    body:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 8)
    body:SetAnchor(TOPRIGHT, title, BOTTOMRIGHT, 0, 8)
    body:SetHeight(42)
    body:SetFont("$(MEDIUM_FONT)|13")
    body:SetColor(0.86, 0.84, 0.78, 1)
    body:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    body:SetVerticalAlignment(TEXT_ALIGN_TOP)

    tip.TPMTitle = title
    tip.TPMBody = body
    TPM.statisticsHoverTooltip = tip
    return tip
end

function TPM:ShowStatisticsHoverTooltip(titleText, bodyText, sourceControl)
    local tip = TPM_EnsureStatisticsHoverTooltip()
    if not tip then return end
    self:HideStatisticsHoverTooltips()

    titleText = tostring(titleText or "")
    bodyText = tostring(bodyText or "")

    -- 2.6.24: Longer help text (especially the Skyshard positioning guide)
    -- gets a wider panel instead of being squeezed into the old 360 px box.
    -- Height is still calculated from the rendered text below, so translated
    -- DE/EN/RU/FR/ES instructions can grow naturally without clipping.
    local lineBreaks = 0
    for _ in string.gmatch(bodyText, "\n") do lineBreaks = lineBreaks + 1 end
    local longHelp = #bodyText >= 170 or lineBreaks >= 3
    local tooltipWidth = longHelp and 440 or 360
    if tip.SetWidth then tip:SetWidth(tooltipWidth) end
    if tip.TPMBody.SetHorizontalAlignment then
        tip.TPMBody:SetHorizontalAlignment(longHelp and TEXT_ALIGN_LEFT or TEXT_ALIGN_CENTER)
    end

    tip.TPMTitle:SetText(titleText)
    tip.TPMBody:SetText(bodyText)
    tip.TPMBody:SetHidden(bodyText == "")

    local titleHeight = 28
    local bodyHeight = 0
    if tip.TPMTitle.GetTextHeight then
        titleHeight = math.max(28, math.ceil(tonumber(tip.TPMTitle:GetTextHeight()) or 28))
    end
    if bodyText ~= "" then
        bodyHeight = 34
        if tip.TPMBody.GetTextHeight then
            bodyHeight = math.max(34, math.ceil(tonumber(tip.TPMBody:GetTextHeight()) or 34))
        end
    end
    tip.TPMTitle:SetHeight(titleHeight)
    tip.TPMBody:SetHeight(math.max(1, bodyHeight))
    tip:SetHeight(12 + titleHeight + (bodyHeight > 0 and (8 + bodyHeight) or 0) + 12)

    TPM_ArmStatisticsHoverTooltip(tip, sourceControl)
    self:AnchorStatisticsHoverTooltip(tip, 58)
end

local function TPM_EnsureAchievementTooltip()
    if TPM.statisticsAchievementTooltip then return TPM.statisticsAchievementTooltip end
    if not WINDOW_MANAGER or not GuiRoot then return nil end

    local tip = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "AchievementTooltip")
    tip:SetDimensions(320, 126)
    tip:SetHidden(true)
    tip:SetMouseEnabled(false)
    tip:SetMovable(false)
    if tip.SetClampedToScreen then tip:SetClampedToScreen(true) end
    if tip.SetDrawTier and DT_HIGH then tip:SetDrawTier(DT_HIGH) end
    if tip.SetDrawLayer and DL_OVERLAY then tip:SetDrawLayer(DL_OVERLAY) end
    -- Statistics itself uses draw level 7200. Keep this panel clearly above it.
    if tip.SetDrawLevel then tip:SetDrawLevel(12000) end

    local bg = WINDOW_MANAGER:CreateControl(nil, tip, CT_BACKDROP)
    bg:SetAnchorFill()
    bg:SetCenterColor(0.035, 0.031, 0.026, 0.985)
    bg:SetEdgeColor(0.92, 0.76, 0.14, 0.96)
    bg:SetEdgeTexture(nil, 1, 1, 1)

    local title = WINDOW_MANAGER:CreateControl(nil, tip, CT_LABEL)
    title:SetAnchor(TOPLEFT, tip, TOPLEFT, 14, 12)
    title:SetAnchor(TOPRIGHT, tip, TOPRIGHT, -14, 12)
    title:SetHeight(28)
    title:SetFont("ZoFontWinH3")
    title:SetColor(0.98, 0.96, 0.90, 1)
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    title:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local points = WINDOW_MANAGER:CreateControl(nil, tip, CT_LABEL)
    points:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 8)
    points:SetAnchor(TOPRIGHT, title, BOTTOMRIGHT, 0, 8)
    points:SetHeight(24)
    points:SetFont("$(MEDIUM_FONT)|16")
    points:SetColor(0.94, 0.92, 0.86, 1)
    points:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    points:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local note = WINDOW_MANAGER:CreateControl(nil, tip, CT_LABEL)
    note:SetAnchor(TOPLEFT, points, BOTTOMLEFT, 0, 8)
    note:SetAnchor(TOPRIGHT, points, BOTTOMRIGHT, 0, 8)
    note:SetHeight(44)
    note:SetFont("$(MEDIUM_FONT)|12")
    note:SetColor(0.78, 0.75, 0.68, 1)
    note:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    note:SetVerticalAlignment(TEXT_ALIGN_TOP)

    tip.TPMTitle = title
    tip.TPMPoints = points
    tip.TPMNote = note
    TPM.statisticsAchievementTooltip = tip
    return tip
end

local function TPM_ShowAchievementTooltip(data, sourceControl)
    if not data or not TPM.statisticsWindow then return end
    local tip = TPM_EnsureAchievementTooltip()
    if not tip then return end
    TPM:HideStatisticsHoverTooltips()

    tip.TPMTitle:SetText(data.name or "")
    tip.TPMPoints:SetText(TPM:L("STAT_ACHIEVEMENT_POINTS_TT", data.earned or 0, data.total or 0))
    tip.TPMNote:SetText(TPM:L("STAT_ACHIEVEMENT_LANGUAGE_NOTE"))

    -- Let long translated category names and notes grow instead of clipping.
    local titleHeight = 28
    local pointsHeight = 24
    local noteHeight = 38
    if tip.TPMTitle.GetTextHeight then
        titleHeight = math.max(28, math.ceil(tonumber(tip.TPMTitle:GetTextHeight()) or 28))
    end
    if tip.TPMPoints.GetTextHeight then
        pointsHeight = math.max(24, math.ceil(tonumber(tip.TPMPoints:GetTextHeight()) or 24))
    end
    if tip.TPMNote.GetTextHeight then
        noteHeight = math.max(34, math.ceil(tonumber(tip.TPMNote:GetTextHeight()) or 38))
    end
    tip.TPMTitle:SetHeight(titleHeight)
    tip.TPMPoints:SetHeight(pointsHeight)
    tip.TPMNote:SetHeight(noteHeight)
    tip:SetHeight(12 + titleHeight + 8 + pointsHeight + 8 + noteHeight + 12)

    -- Always place achievement details beside the journal, aligned near its
    -- upper-right corner rather than attaching them to an individual row.
    TPM_ArmStatisticsHoverTooltip(tip, sourceControl)
    TPM:AnchorStatisticsHoverTooltip(tip, 58)
end

local function TPM_HideAchievementTooltip()
    local tip = TPM.statisticsAchievementTooltip
    if tip then tip:SetHidden(true) end
end

function TPM:RefreshStatisticsCollectionPager()
    local page = self:GetStatisticsCompletionPage()
    self.statisticsCompletionPage = page
    self:RefreshStatisticsCategorySortControls()

    if self.statisticsCategoryPageIndicator then
        self.statisticsCategoryPageIndicator:SetText(string.format("%d / 3", page))
    end
    if self.statisticsCategoryPrev then
        self.statisticsCategoryPrev:SetEnabled(page > 1)
        self.statisticsCategoryPrev:SetAlpha(page > 1 and 1 or 0.32)
    end
    if self.statisticsCategoryNext then
        self.statisticsCategoryNext:SetEnabled(page < 3)
        self.statisticsCategoryNext:SetAlpha(page < 3 and 1 or 0.32)
    end

    -- Hide both optional pages first. Page 1 rows have already been refreshed by
    -- RefreshStatisticsWindow and are only hidden when page 2 or 3 is selected.
    for _, row in ipairs(self.statisticsCollectionRows or {}) do
        row.control:SetHidden(true)
    end
    for _, row in ipairs(self.statisticsAchievementRows or {}) do
        row.control:SetHidden(true)
    end

    if page == 1 then
        if self.statisticsCategoryTitle then
            local focusZoneId = self:GetStatisticsFocusZoneId()
            if focusZoneId > 0 then
                self.statisticsCategoryTitle:SetText(string.format("%s — %s", self:L("STAT_CATEGORIES"), SafeZoneName(focusZoneId)))
            else
                self.statisticsCategoryTitle:SetText(self:L("STAT_CATEGORIES"))
            end
        end
        return
    end

    for _, row in ipairs(self.statisticsCategoryRows or {}) do
        row.control:SetHidden(true)
    end

    if page == 2 then
        local focusZoneId = self:GetStatisticsFocusZoneId()
        if self.statisticsCategoryTitle then
            self.statisticsCategoryTitle:SetText(focusZoneId > 0
                and string.format("%s — %s", self:L("STAT_COLLECTIONS"), SafeZoneName(focusZoneId))
                or self:L("STAT_COLLECTIONS"))
        end
        local collectionData = {}
        if focusZoneId > 0 then
            -- Only show collection data TPM can attribute to this zone without
            -- guessing. At the moment that is the Stablemaster stock introduced
            -- with Update 49. Global account collection totals remain available
            -- immediately by switching focus back to All Tamriel.
            local mount = ZONE_STABLEMASTER_MOUNTS[focusZoneId]
            if mount then
                collectionData[#collectionData + 1] =
                {
                    name = self:L("STAT_ZONE_STABLE_MOUNT"),
                    owned = 0, total = 0, percent = 0, available = true, informational = true,
                    countText = self:L("STAT_ZONE_STABLE_MOUNT_AVAILABLE", 4),
                    tooltipText = self:L("STAT_ZONE_STABLE_MOUNT_TT", mount.name, ZO_CommaDelimitNumber and ZO_CommaDelimitNumber(mount.price) or tostring(mount.price)),
                    icon = "NagaMapaCompleto/art/cat_crown.dds",
                }
            end
        else
            for _, definition in ipairs(COLLECTION_STAT_DEFINITIONS) do
                local data = self:GetCollectionStatisticData(definition)
                if data then collectionData[#collectionData + 1] = data end
            end
            collectionData = self:SortStatisticsCategoryData(collectionData, false)
        end
        for index, row in ipairs(self.statisticsCollectionRows or {}) do
            local data = collectionData[index]
            row.control:SetHidden(data == nil)
            row.control:SetMouseEnabled(data ~= nil and data.tooltipText ~= nil)
            if data then
                row.label:SetText(data.name)
                if data.informational then
                    row.count:SetText(data.countText or "—")
                    row.percent:SetText("—")
                    self:SetStatisticsBarPercent(row.fill, 96, 0)
                elseif data.available then
                    row.count:SetText(string.format("%d / %d", data.owned, data.total))
                    row.percent:SetText(string.format("|c%s%d%%|r", self:GetStatisticsPercentTextColor(data.percent), data.percent))
                    self:SetStatisticsBarPercent(row.fill, 96, data.percent)
                else
                    row.count:SetText("—")
                    row.percent:SetText("—")
                    self:SetStatisticsBarPercent(row.fill, 96, 0)
                end
                if row.icon then
                    row.icon:SetTexture(data.icon or "NagaMapaCompleto/art/cat_quests.dds")
                    local ir, ig, ib = self:GetStatisticsProgressColor(data.percent)
                    row.icon:SetColor(ir, ig, ib, data.available and 0.96 or 0.45)
                end
                if data.tooltipText then
                    row.control:SetHandler("OnMouseEnter", function(control)
                        TPM:ShowStatisticsHoverTooltip(data.name, data.tooltipText, control)
                    end)
                    row.control:SetHandler("OnMouseExit", function() TPM:HideStatisticsHoverTooltips() end)
                else
                    row.control:SetHandler("OnMouseEnter", nil)
                    row.control:SetHandler("OnMouseExit", nil)
                end
            else
                row.control:SetHandler("OnMouseEnter", nil)
                row.control:SetHandler("OnMouseExit", nil)
            end
        end
        self:RefreshStatisticsCategorySortControls()
        return
    end

    local focusZoneId = self:GetStatisticsFocusZoneId()
    if self.statisticsCategoryTitle then
        self.statisticsCategoryTitle:SetText(focusZoneId > 0
            and string.format("%s — %s", self:L("STAT_ACHIEVEMENTS"), SafeZoneName(focusZoneId))
            or self:L("STAT_ACHIEVEMENTS"))
    end
    local achievementRows
    if focusZoneId > 0 then
        local summary = self:GetZoneAchievementSummary(focusZoneId)
        achievementRows = summary and { summary } or {}
    else
        achievementRows = self:SortStatisticsCategoryData(self:GetAchievementStatisticsData(), true)
    end
    for index, row in ipairs(self.statisticsAchievementRows or {}) do
        local data = achievementRows[index]
        row.control:SetHidden(data == nil)
        row.control:SetMouseEnabled(data ~= nil)
        if data then
            row.label:SetText(data.name)
            row.count:SetText(string.format("%d / %d", data.earned or 0, data.total or 0))
            row.percent:SetText(string.format("|c%s%d%%|r", self:GetStatisticsPercentTextColor(data.percent or 0), data.percent or 0))
            self:SetStatisticsBarPercent(row.fill, 96, data.percent or 0)
            if row.icon then
                row.icon:SetTexture(data.icon or "NagaMapaCompleto/art/stat_objectives.dds")
                local ir, ig, ib = self:GetStatisticsProgressColor(data.percent or 0)
                row.icon:SetColor(ir, ig, ib, 0.96)
            end
            row.control:SetHandler("OnMouseEnter", function(control)
                if data.tooltipText then
                    TPM:ShowStatisticsHoverTooltip(data.name, data.tooltipText, control)
                else
                    TPM_ShowAchievementTooltip(data, control)
                end
            end)
            row.control:SetHandler("OnMouseExit", function()
                TPM_HideAchievementTooltip()
                TPM:HideStatisticsHoverTooltips()
            end)
        else
            row.control:SetHandler("OnMouseEnter", nil)
            row.control:SetHandler("OnMouseExit", nil)
        end
    end
end

function TPM:CreateStatisticsZoneRow(parent, index)
    local row = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "StatsZoneRow" .. tostring(index), parent, CT_CONTROL)
    row:SetDimensions(918, 30)
    row:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, (index - 1) * 31)
    row:SetMouseEnabled(true)

    local bg = WINDOW_MANAGER:CreateControl(nil, row, CT_BACKDROP)
    bg:SetAnchorFill(row)
    bg:SetCenterColor(0.035, 0.031, 0.024, index % 2 == 0 and 0.58 or 0.34)
    bg:SetEdgeColor(0.30, 0.25, 0.14, 0.22)
    bg:SetEdgeTexture(nil, 1, 1, 1)
    bg:SetMouseEnabled(false)
    row.bg = bg
    row.baseR, row.baseG, row.baseB = 0.035, 0.031, 0.024
    row.baseAlpha = index % 2 == 0 and 0.58 or 0.34

    local completeIcon = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
    completeIcon:SetDimensions(18, 18)
    completeIcon:SetAnchor(LEFT, row, LEFT, 8, 0)
    completeIcon:SetTexture("EsoUI/Art/Buttons/accept_up.dds")
    completeIcon:SetColor(0.78, 0.86, 0.20, 1)
    completeIcon:SetHidden(true)
    row.completeIcon = completeIcon

    local name = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    name:SetDimensions(390, 30)
    name:SetAnchor(LEFT, row, LEFT, 10, 0)
    name:SetFont("$(MEDIUM_FONT)|18")
    name:SetColor(0.94, 0.92, 0.86, 1)
    name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    row.nameLabel = name

    local percent = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    percent:SetDimensions(62, 30)
    percent:SetAnchor(LEFT, row, LEFT, 398, 0)
    percent:SetFont("$(BOLD_FONT)|18")
    percent:SetColor(0.72, 0.71, 0.67, 1)
    percent:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    percent:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    row.percentLabel = percent

    local progressBg = WINDOW_MANAGER:CreateControl(nil, row, CT_BACKDROP)
    progressBg:SetDimensions(172, 10)
    progressBg:SetAnchor(LEFT, row, LEFT, 476, 0)
    progressBg:SetCenterColor(0.018, 0.016, 0.013, 0.90)
    progressBg:SetEdgeColor(0.34, 0.27, 0.12, 0.70)
    progressBg:SetEdgeTexture(nil, 1, 1, 1)
    row.progressBg = progressBg

    local progressFill = WINDOW_MANAGER:CreateControl(nil, progressBg, CT_BACKDROP)
    progressFill:SetDimensions(1, 8)
    progressFill:SetAnchor(LEFT, progressBg, LEFT, 1, 0)
    progressFill:SetCenterColor(0.78, 0.59, 0.16, 0.96)
    progressFill:SetEdgeColor(0, 0, 0, 0)
    row.progressFill = progressFill

    local done = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    done:SetDimensions(116, 30)
    done:SetAnchor(LEFT, row, LEFT, 664, 0)
    done:SetFont("$(MEDIUM_FONT)|17")
    done:SetColor(0.80, 0.77, 0.69, 1)
    done:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    done:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    row.doneLabel = done

    local open = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
    open:SetDimensions(88, 30)
    open:SetAnchor(RIGHT, row, RIGHT, -14, 0)
    open:SetFont("$(BOLD_FONT)|17")
    open:SetColor(0.95, 0.75, 0.24, 1)
    open:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    open:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    row.openLabel = open

    row:SetHandler("OnMouseEnter", function(control)
        if control.bg then
            if TPM:IsStatisticsDarkDesign() then control.bg:SetCenterColor(0,0,0,0.44)
            else control.bg:SetCenterColor(0.16, 0.125, 0.050, 0.86) end
        end
    end)
    row:SetHandler("OnMouseExit", function(control)
        if control.bg then
            if TPM:IsStatisticsDarkDesign() then control.bg:SetCenterColor(0,0,0,0.18)
            else control.bg:SetCenterColor(control.baseR or 0.035, control.baseG or 0.031, control.baseB or 0.024, control.baseAlpha or 0.34) end
        end
    end)
    row:SetHandler("OnMouseWheel", function(_, delta)
        TPM:ScrollStatistics(delta)
    end)
    row:SetHandler("OnMouseUp", function(control, button, upInside)
        if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        if control.mapId and control.mapId > 0 then
            TPM:OpenWorldMapFromStatistics(control.mapId)
        end
    end)

    return row
end


function TPM:ApplyThemedValueCard(card, options)
    if not card or not card.control then return end
    options = options or {}
    local control = card.control
    local width, height = control:GetDimensions()
    local accent = options.accentColor or { 0.86, 0.66, 0.18 }
    local center = options.centerColor or { 0.016 + accent[1] * 0.045, 0.015 + accent[2] * 0.034, 0.014 + accent[3] * 0.024, 0.980 }
    local edge = options.edgeColor or { math.min(1, accent[1] + 0.10), math.min(1, accent[2] + 0.10), math.min(1, accent[3] + 0.10), 0.88 }
    local iconSize = options.iconSize or math.min(height - 18, 48)
    local iconOffset = options.iconOffset or 10
    local hideIcon = options.hideIcon == true
    local leftTextX = options.leftTextX or (hideIcon and 14 or (iconOffset + iconSize + 12))
    local titleWidth = math.max(10, width - leftTextX - 12)
    local valueWidth = math.max(10, width - leftTextX - 12)

    control:SetCenterColor(center[1], center[2], center[3], center[4] or 1)
    control:SetEdgeColor(edge[1], edge[2], edge[3], edge[4] or 1)
    control:SetEdgeTexture(nil, 1, 1, 1)

    if not control.TPMAccent then
        local bar = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
        bar:SetDimensions(4, math.max(10, height))
        bar:SetAnchor(LEFT, control, LEFT, 0, 0)
        bar:SetEdgeColor(0, 0, 0, 0)
        control.TPMAccent = bar
    end
    control.TPMAccent:ClearAnchors()
    control.TPMAccent:SetDimensions(4, math.max(10, height))
    control.TPMAccent:SetAnchor(LEFT, control, LEFT, 0, 0)
    control.TPMAccent:SetCenterColor(accent[1], accent[2], accent[3], 0.82)

    if not control.TPMIconBack then
        local back = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
        back:SetEdgeTexture(nil, 1, 1, 1)
        control.TPMIconBack = back
    end
    control.TPMIconBack:ClearAnchors()
    control.TPMIconBack:SetDimensions(iconSize, iconSize)
    control.TPMIconBack:SetAnchor(LEFT, control, LEFT, iconOffset, 0)
    control.TPMIconBack:SetCenterColor(math.min(1, accent[1] * 0.28 + 0.05), math.min(1, accent[2] * 0.28 + 0.05), math.min(1, accent[3] * 0.28 + 0.05), 0.99)
    control.TPMIconBack:SetEdgeColor(accent[1], accent[2], accent[3], 0.96)
    control.TPMIconBack:SetHidden(hideIcon)

    if not control.TPMIconFrame then
        local frame = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
        frame:SetEdgeTexture(nil, 1, 1, 1)
        frame:SetMouseEnabled(false)
        control.TPMIconFrame = frame
    end
    control.TPMIconFrame:ClearAnchors()
    control.TPMIconFrame:SetDimensions(iconSize + 4, iconSize + 4)
    control.TPMIconFrame:SetAnchor(CENTER, control.TPMIconBack, CENTER, 0, 0)
    control.TPMIconFrame:SetCenterColor(accent[1] * 0.14, accent[2] * 0.14, accent[3] * 0.14, 0.30)
    control.TPMIconFrame:SetEdgeColor(accent[1], accent[2], accent[3], 0.66)
    control.TPMIconFrame:SetHidden(hideIcon)

    if not control.TPMInnerTint then
        local tint = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
        tint:SetEdgeTexture(nil, 1, 1, 1)
        tint:SetMouseEnabled(false)
        control.TPMInnerTint = tint
    end
    control.TPMInnerTint:ClearAnchors()
    control.TPMInnerTint:SetAnchor(TOPLEFT, control, TOPLEFT, 1, 1)
    control.TPMInnerTint:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -1, -1)
    control.TPMInnerTint:SetCenterColor(accent[1] * 0.09, accent[2] * 0.075, accent[3] * 0.060, 0.14)
    control.TPMInnerTint:SetEdgeColor(0, 0, 0, 0)

    if not control.TPMTopBand then
        local band = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
        band:SetEdgeColor(0, 0, 0, 0)
        band:SetMouseEnabled(false)
        control.TPMTopBand = band
    end
    control.TPMTopBand:ClearAnchors()
    control.TPMTopBand:SetDimensions(math.max(18, width - 2), 1)
    control.TPMTopBand:SetAnchor(TOPLEFT, control, TOPLEFT, 1, 1)
    control.TPMTopBand:SetCenterColor(accent[1], accent[2], accent[3], 0.58)

    if not control.TPMIcon then
        local icon = WINDOW_MANAGER:CreateControl(nil, control.TPMIconBack, CT_TEXTURE)
        icon:SetAnchor(CENTER, control.TPMIconBack, CENTER, 0, 0)
        control.TPMIcon = icon
    end
    control.TPMIcon:SetDimensions(iconSize - 8, iconSize - 8)

    if not control.TPMMonogram then
        local mono = WINDOW_MANAGER:CreateControl(nil, control.TPMIconBack, CT_LABEL)
        mono:SetAnchor(CENTER, control.TPMIconBack, CENTER, 0, 0)
        mono:SetFont("$(BOLD_FONT)|18")
        mono:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        mono:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        control.TPMMonogram = mono
    end
    control.TPMMonogram:SetColor(accent[1], math.min(1, accent[2] + 0.06), math.min(1, accent[3] + 0.10), 1)
    control.TPMMonogram:SetText(options.monogram or "")

    if hideIcon then
        control.TPMIcon:SetHidden(true)
        control.TPMMonogram:SetHidden(true)
    elseif options.iconTexture and options.iconTexture ~= "" then
        control.TPMIcon:SetTexture(options.iconTexture)
        control.TPMIcon:SetColor(1, 1, 1, 1)
        if options.currencyIcon == true then
            control.TPMIcon:SetDimensions(iconSize - 4, iconSize - 4)
        else
            control.TPMIcon:SetDimensions(iconSize - 8, iconSize - 8)
        end
        control.TPMIcon:SetHidden(false)
        control.TPMMonogram:SetHidden(true)
    else
        control.TPMIcon:SetHidden(true)
        control.TPMMonogram:SetHidden(false)
    end

    if card.title then
        card.title:ClearAnchors()
        card.title:SetDimensions(titleWidth, 20)
        card.title:SetAnchor(TOPLEFT, control, TOPLEFT, leftTextX, 8)
        card.title:SetFont(options.titleFont or "$(BOLD_FONT)|15")
        card.title:SetColor(math.min(1, accent[1] * 0.55 + 0.40), math.min(1, accent[2] * 0.50 + 0.38), math.min(1, accent[3] * 0.40 + 0.34), 1)
        card.title:SetHorizontalAlignment(options.titleAlign or TEXT_ALIGN_LEFT)
        card.title:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    if card.value then
        card.value:ClearAnchors()
        card.value:SetDimensions(valueWidth, options.valueHeight or 34)
        card.value:SetAnchor(TOPLEFT, control, TOPLEFT, leftTextX, options.valueY or 31)
        card.value:SetFont(options.valueFont or "$(ANTIQUE_FONT)|29")
        if options.valueColor then
            card.value:SetColor(options.valueColor[1], options.valueColor[2], options.valueColor[3], options.valueColor[4] or 1)
        else
            card.value:SetColor(accent[1], math.min(1, accent[2] + 0.12), math.min(1, accent[3] + 0.18), 1)
        end
        card.value:SetHorizontalAlignment(options.valueAlign or TEXT_ALIGN_LEFT)
        card.value:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end
    if card.detail then
        card.detail:ClearAnchors()
        card.detail:SetDimensions(valueWidth, 16)
        card.detail:SetAnchor(BOTTOMLEFT, control, BOTTOMLEFT, leftTextX, -7)
        card.detail:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        card.detail:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        card.detail:SetColor(0.88, 0.86, 0.80, 1)
        if options.detailFont then
            card.detail:SetFont(options.detailFont)
        end
    end
end

function TPM:GetEconomyCardVisual(definition)
    if not definition then
        return { texture = nil, accent = { 0.86, 0.66, 0.18 }, mono = "?", isEsoCurrencyIcon = false }
    end

    local currencyType = definition.currencyType
    local iconPath = nil

    -- Prefer ESO's own platform/keyboard currency artwork. This keeps TPM in
    -- sync with the live client instead of shipping look-alike currency icons.
    if type(currencyType) == "number" then
        local path = ZO_Currency_GetPlatformCurrencyIcon(currencyType)
        if type(path) == "string" and path ~= "" then iconPath = path end
    end
    if not iconPath and type(currencyType) == "number" then
        local path = GetCurrencyKeyboardIcon(currencyType)
        if type(path) == "string" and path ~= "" then iconPath = path end
    end

    -- Use a curated color palette per currency instead of relying on ESO's
    -- API color, because several currencies return neutral/white tones that do
    -- not visually match the actual currency well enough inside TPM's UI cards.
    local presets = {
        gold             = { texture = "NagaMapaCompleto/art/currency_gold_hd.dds",          accent = { 0.95, 0.78, 0.16 }, mono = "G" },
        crowns           = { texture = "NagaMapaCompleto/art/stat_complete.dds",  accent = { 0.68, 0.76, 0.88 }, mono = "C" },
        crownGems        = { texture = "NagaMapaCompleto/art/cat_skyshard.dds",   accent = { 0.78, 0.36, 0.98 }, mono = "CG" },
        tradeBars        = { texture = "NagaMapaCompleto/art/cat_setstation.dds", accent = { 0.92, 0.76, 0.18 }, mono = "TB" },
        seals            = { texture = "NagaMapaCompleto/art/cat_quests.dds",     accent = { 0.78, 0.66, 0.34 }, mono = "S" },
        alliancePoints   = { texture = "NagaMapaCompleto/art/pvp_kills.dds",      accent = { 0.18, 0.95, 0.18 }, mono = "AP" },
        telVar           = { texture = "NagaMapaCompleto/art/pve_kills.dds",      accent = { 0.18, 0.80, 1.00 }, mono = "TV" },
        writVouchers     = { texture = "NagaMapaCompleto/art/cat_sidequests.dds", accent = { 0.92, 0.77, 0.34 }, mono = "WV" },
        transmute        = { texture = "NagaMapaCompleto/art/cat_mundus.dds",     accent = { 0.32, 0.82, 1.00 }, mono = "TC" },
        undauntedKeys    = { texture = "NagaMapaCompleto/art/cat_delve.dds",      accent = { 0.96, 0.76, 0.24 }, mono = "UK" },
        archivalFortunes = { texture = "NagaMapaCompleto/art/cat_book.dds",       accent = { 0.76, 0.68, 0.28 }, mono = "AF" },
        tomePoints       = { texture = "NagaMapaCompleto/art/cat_book.dds",       accent = { 0.48, 0.92, 0.86 }, mono = "TP" },
    }

    local preset = presets[definition.key] or { texture = nil, accent = { 0.86, 0.66, 0.18 }, mono = "?" }

    -- Gold is intentionally rendered from TPM's sharpened 1024px copy of the
    -- ESO coin artwork. The native currency texture is tiny and becomes visibly
    -- soft in the large Gold summary card. Keep all other currencies live from ESO.
    if definition.key == "gold" then
        iconPath = preset.texture
    end

    return {
        texture = iconPath or preset.texture,
        accent = preset.accent,
        mono = preset.mono,
        isEsoCurrencyIcon = iconPath ~= nil,
    }
end

function TPM:CreatePlayerStatCard(parent, name, x, y, width)
    local card = WINDOW_MANAGER:CreateControl(name, parent, CT_BACKDROP)
    card:SetDimensions(width, 100)
    card:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    card:SetCenterColor(0.030, 0.027, 0.021, 0.985)
    card:SetEdgeColor(0.42, 0.34, 0.17, 0.82)
    card:SetEdgeTexture(nil, 1, 1, 1)
    card:SetMouseEnabled(false)

    local title = WINDOW_MANAGER:CreateControl(name .. "Title", card, CT_LABEL)
    title:SetDimensions(width - 18, 26)
    title:SetAnchor(TOPLEFT, card, TOPLEFT, 9, 9)
    title:SetFont("$(BOLD_FONT)|17")
    title:SetColor(0.78, 0.72, 0.58, 1)
    title:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    title:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local value = WINDOW_MANAGER:CreateControl(name .. "Value", card, CT_LABEL)
    value:SetDimensions(width - 18, 44)
    value:SetAnchor(TOPLEFT, card, TOPLEFT, 9, 36)
    value:SetFont("$(ANTIQUE_FONT)|30")
    value:SetColor(0.95, 0.82, 0.36, 1)
    value:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    value:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    return { control = card, title = title, value = value }
end

function TPM:CreateCharacterMetricCard(parent, name, x, y, width)
    local card = WINDOW_MANAGER:CreateControl(name, parent, CT_BACKDROP)
    card:SetDimensions(width, 94)
    card:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    card:SetCenterColor(0.030, 0.027, 0.021, 0.985)
    card:SetEdgeColor(0.42, 0.34, 0.17, 0.82)
    card:SetEdgeTexture(nil, 1, 1, 1)
    card:SetMouseEnabled(false)

    local title = WINDOW_MANAGER:CreateControl(name .. "Title", card, CT_LABEL)
    title:SetDimensions(width - 18, 26)
    title:SetAnchor(TOPLEFT, card, TOPLEFT, 9, 8)
    title:SetFont("$(BOLD_FONT)|15")
    title:SetColor(0.78, 0.72, 0.58, 1)
    title:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    title:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local value = WINDOW_MANAGER:CreateControl(name .. "Value", card, CT_LABEL)
    value:SetDimensions(width - 18, 48)
    value:SetAnchor(TOPLEFT, card, TOPLEFT, 9, 34)
    value:SetFont("$(ANTIQUE_FONT)|26")
    value:SetColor(0.95, 0.82, 0.36, 1)
    value:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    value:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    return { control = card, title = title, value = value }
end

function TPM:CreatePlayerStatisticsPage(control)
    if self.statisticsPlayerPage then return end

    local page = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "StatisticsPlayerPage", control, CT_BACKDROP)
    page:SetAnchor(TOPLEFT, control, TOPLEFT, 14, 60)
    page:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -14, -55)
    page:SetCenterColor(0.055, 0.046, 0.030, 1.00)
    page:SetEdgeColor(0.34, 0.27, 0.12, 0.94)
    page:SetEdgeTexture(nil, 1, 1, 1)
    page:SetMouseEnabled(true)
    page:SetHidden(true)
    self.statisticsPlayerPage = page

    local subtitle = WINDOW_MANAGER:CreateControl(nil, page, CT_LABEL)
    subtitle:SetDimensions(920, 24); subtitle:SetAnchor(TOPLEFT, page, TOPLEFT, 20, 14)
    subtitle:SetFont("$(MEDIUM_FONT)|18"); subtitle:SetColor(0.70, 0.67, 0.60, 1)
    self.statisticsPlayerPageSubtitle = subtitle

    local profile = WINDOW_MANAGER:CreateControl(nil, page, CT_BACKDROP)
    profile:SetDimensions(932, 88); profile:SetAnchor(TOPLEFT, page, TOPLEFT, 20, 48)
    profile:SetCenterColor(0.045, 0.037, 0.026, 0.96); profile:SetEdgeColor(0.42, 0.34, 0.17, 0.72); profile:SetEdgeTexture(nil, 1, 1, 1)
    profile:SetMouseEnabled(false); self.statisticsPlayerProfileBox = profile

    local profileTitle = WINDOW_MANAGER:CreateControl(nil, profile, CT_LABEL)
    profileTitle:SetDimensions(170, 54); profileTitle:SetAnchor(TOPLEFT, profile, TOPLEFT, 14, 0)
    profileTitle:SetFont("$(BOLD_FONT)|18"); profileTitle:SetColor(0.90, 0.77, 0.34, 1)
    profileTitle:SetVerticalAlignment(TEXT_ALIGN_CENTER); self.statisticsPlayerProfileTitle = profileTitle

    local profileText = WINDOW_MANAGER:CreateControl(nil, profile, CT_LABEL)
    profileText:SetDimensions(292, 54); profileText:SetAnchor(TOPLEFT, profile, TOPLEFT, 182, 0)
    profileText:SetFont("$(MEDIUM_FONT)|17"); profileText:SetColor(0.88, 0.85, 0.77, 1)
    profileText:SetHorizontalAlignment(TEXT_ALIGN_RIGHT); profileText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.statisticsPlayerProfileText = profileText

    local profileDivider = WINDOW_MANAGER:CreateControl(nil, profile, CT_TEXTURE)
    profileDivider:SetDimensions(1, 40); profileDivider:SetAnchor(TOPLEFT, profile, TOPLEFT, 486, 7)
    profileDivider:SetColor(0.42, 0.34, 0.17, 0.72)
    self.statisticsPlayerProfileDivider = profileDivider

    local mountTitle = WINDOW_MANAGER:CreateControl(nil, profile, CT_LABEL)
    mountTitle:SetDimensions(158, 54); mountTitle:SetAnchor(TOPLEFT, profile, TOPLEFT, 500, 0)
    mountTitle:SetFont("$(BOLD_FONT)|18"); mountTitle:SetColor(0.90, 0.77, 0.34, 1)
    mountTitle:SetVerticalAlignment(TEXT_ALIGN_CENTER); self.statisticsPlayerMountTitle = mountTitle

    local mountIconFrame = WINDOW_MANAGER:CreateControl(nil, profile, CT_BACKDROP)
    mountIconFrame:SetDimensions(44, 44); mountIconFrame:SetAnchor(TOPLEFT, profile, TOPLEFT, 662, 5)
    mountIconFrame:SetCenterColor(0.018, 0.016, 0.013, 0.92); mountIconFrame:SetEdgeColor(0.42, 0.34, 0.17, 0.82); mountIconFrame:SetEdgeTexture(nil, 1, 1, 1)
    mountIconFrame:SetMouseEnabled(false); self.statisticsPlayerMountIconFrame = mountIconFrame

    local mountIcon = WINDOW_MANAGER:CreateControl(nil, mountIconFrame, CT_TEXTURE)
    mountIcon:SetDimensions(38, 38); mountIcon:SetAnchor(CENTER, mountIconFrame, CENTER, 0, 0)
    mountIcon:SetTextureCoords(0, 1, 0, 1); mountIcon:SetHidden(true)
    self.statisticsPlayerMountIcon = mountIcon

    local mountText = WINDOW_MANAGER:CreateControl(nil, profile, CT_LABEL)
    mountText:SetDimensions(196, 54); mountText:SetAnchor(TOPLEFT, profile, TOPLEFT, 716, 0)
    mountText:SetFont("$(MEDIUM_FONT)|16"); mountText:SetColor(0.88, 0.85, 0.77, 1)
    mountText:SetHorizontalAlignment(TEXT_ALIGN_RIGHT); mountText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    mountText:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    self.statisticsPlayerMountText = mountText

    -- Level/CP and active companion progression belong to Character, not the
    -- Economy or PvE/PvP dashboards. They live inside the Character profile.
    self:EnsureCombatProgressionControls()

    self.statisticsCharacterCards = {
        hours = self:CreateCharacterMetricCard(page, ADDON_NAME .. "CharacterHours", 20, 146, 218),
        days = self:CreateCharacterMetricCard(page, ADDON_NAME .. "CharacterDays", 252, 146, 218),
        today = self:CreateCharacterMetricCard(page, ADDON_NAME .. "CharacterToday", 484, 146, 218),
        session = self:CreateCharacterMetricCard(page, ADDON_NAME .. "CharacterSession", 716, 146, 236),
        week = self:CreateCharacterMetricCard(page, ADDON_NAME .. "CharacterRange", 20, 246, 218),
        average = self:CreateCharacterMetricCard(page, ADDON_NAME .. "CharacterAverage", 252, 246, 218),
        activeDays = self:CreateCharacterMetricCard(page, ADDON_NAME .. "CharacterActiveDays", 484, 246, 218),
        location = self:CreateCharacterMetricCard(page, ADDON_NAME .. "CharacterLocation", 716, 246, 236),
    }
    for _, card in pairs(self.statisticsCharacterCards) do
        self:ApplyThemedValueCard(card, { accentColor={.90,.68,.18}, hideIcon=true, leftTextX=14 })
    end
    if self.statisticsCharacterCards.location then self.statisticsCharacterCards.location.value:SetFont("$(BOLD_FONT)|18") end

    local dailyTitle = WINDOW_MANAGER:CreateControl(nil, page, CT_LABEL)
    dailyTitle:SetDimensions(220, 30); dailyTitle:SetAnchor(TOPLEFT, page, TOPLEFT, 20, 348)
    dailyTitle:SetFont("ZoFontWinH4"); dailyTitle:SetColor(0.90, 0.77, 0.34, 1); self.statisticsCharacterDailyTitle = dailyTitle

    self.statisticsCharacterRangeButtons = {}
    self.statisticsCharacterRangeBackdrops = {}
    local rangeValues = {7,30,90,365}
    for i, days in ipairs(rangeValues) do
        local bg = WINDOW_MANAGER:CreateControl(nil, page, CT_BACKDROP)
        bg:SetDimensions(48, 24); bg:SetAnchor(TOPLEFT, page, TOPLEFT, 242 + (i-1)*52, 350)
        bg:SetCenterColor(.026,.023,.018,.94); bg:SetEdgeColor(.35,.29,.14,.65); bg:SetEdgeTexture(nil,1,1,1)
        local button = WINDOW_MANAGER:CreateControl(nil, bg, CT_BUTTON)
        button:SetAnchorFill(bg); button:SetFont("$(BOLD_FONT)|14"); button:SetText(tostring(days))
        button:SetHandler("OnClicked", function() TPM:SetCharacterStatisticsRange(days) end)
        button.rangeDays = days; button.TPMBackdrop = bg
        self.statisticsCharacterRangeButtons[#self.statisticsCharacterRangeButtons+1] = button
        self.statisticsCharacterRangeBackdrops[#self.statisticsCharacterRangeBackdrops+1] = bg
    end

    local older = WINDOW_MANAGER:CreateControl(nil, page, CT_BUTTON)
    older:SetDimensions(28,24); older:SetAnchor(TOPLEFT,page,TOPLEFT,458,350); older:SetFont("$(BOLD_FONT)|18"); older:SetText("<")
    older:SetHandler("OnClicked",function() TPM:StepCharacterStatisticsRangePage(1) end); self.statisticsCharacterOlderButton=older
    local newer = WINDOW_MANAGER:CreateControl(nil, page, CT_BUTTON)
    newer:SetDimensions(28,24); newer:SetAnchor(TOPLEFT,page,TOPLEFT,490,350); newer:SetFont("$(BOLD_FONT)|18"); newer:SetText(">")
    newer:SetHandler("OnClicked",function() TPM:StepCharacterStatisticsRangePage(-1) end); self.statisticsCharacterNewerButton=newer

    local dailyHint = WINDOW_MANAGER:CreateControl(nil, page, CT_LABEL)
    dailyHint:SetDimensions(420, 24); dailyHint:SetAnchor(TOPRIGHT, page, TOPRIGHT, -20, 352)
    dailyHint:SetFont("$(MEDIUM_FONT)|14"); dailyHint:SetColor(0.67, 0.64, 0.57, 1); dailyHint:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.statisticsCharacterDailyHint = dailyHint

    local dailyBox = WINDOW_MANAGER:CreateControl(nil, page, CT_BACKDROP)
    dailyBox:SetDimensions(932, 190); dailyBox:SetAnchor(TOPLEFT, page, TOPLEFT, 20, 382)
    dailyBox:SetCenterColor(0.035, 0.030, 0.024, 0.94); dailyBox:SetEdgeColor(0.34, 0.29, 0.18, 0.64); dailyBox:SetEdgeTexture(nil,1,1,1)
    self.statisticsCharacterDailyBox = dailyBox

    -- Character daily history is a compact statistics table. The old relative
    -- bars looked like completion/progress bars and did not communicate a clear
    -- target, so use explicit columns instead: date, playtime, kills and bosses.
    local header = WINDOW_MANAGER:CreateControl(nil, dailyBox, CT_CONTROL)
    header:SetDimensions(900, 22); header:SetAnchor(TOPLEFT, dailyBox, TOPLEFT, 16, 5)
    local function CreateDailyHeader(width, x, align)
        local label = WINDOW_MANAGER:CreateControl(nil, header, CT_LABEL)
        label:SetDimensions(width, 22); label:SetAnchor(TOPLEFT, header, TOPLEFT, x, 0)
        label:SetFont("$(BOLD_FONT)|13"); label:SetColor(.72,.68,.59,1)
        label:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT); label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        return label
    end
    self.statisticsCharacterDailyHeaders = {
        date = CreateDailyHeader(250, 0, TEXT_ALIGN_LEFT),
        playtime = CreateDailyHeader(250, 254, TEXT_ALIGN_LEFT),
        kills = CreateDailyHeader(170, 508, TEXT_ALIGN_CENTER),
        bosses = CreateDailyHeader(170, 682, TEXT_ALIGN_CENTER),
    }

    self.statisticsCharacterDailyRows = {}
    for i=1,7 do
        local row = WINDOW_MANAGER:CreateControl(nil, dailyBox, CT_CONTROL)
        row:SetDimensions(900,22); row:SetAnchor(TOPLEFT,dailyBox,TOPLEFT,16,28+(i-1)*22)
        local date=WINDOW_MANAGER:CreateControl(nil,row,CT_LABEL); date:SetDimensions(250,22); date:SetAnchor(TOPLEFT,row,TOPLEFT,0,0); date:SetFont("$(BOLD_FONT)|15"); date:SetColor(.82,.78,.68,1); date:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        local playtime=WINDOW_MANAGER:CreateControl(nil,row,CT_LABEL); playtime:SetDimensions(250,22); playtime:SetAnchor(TOPLEFT,row,TOPLEFT,254,0); playtime:SetFont("$(MEDIUM_FONT)|15"); playtime:SetColor(.93,.86,.70,1); playtime:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        local kills=WINDOW_MANAGER:CreateControl(nil,row,CT_LABEL); kills:SetDimensions(170,22); kills:SetAnchor(TOPLEFT,row,TOPLEFT,508,0); kills:SetFont("$(MEDIUM_FONT)|15"); kills:SetColor(.93,.86,.70,1); kills:SetHorizontalAlignment(TEXT_ALIGN_CENTER); kills:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        local bosses=WINDOW_MANAGER:CreateControl(nil,row,CT_LABEL); bosses:SetDimensions(170,22); bosses:SetAnchor(TOPLEFT,row,TOPLEFT,682,0); bosses:SetFont("$(MEDIUM_FONT)|15"); bosses:SetColor(.93,.86,.70,1); bosses:SetHorizontalAlignment(TEXT_ALIGN_CENTER); bosses:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        self.statisticsCharacterDailyRows[i]={control=row,date=date,playtime=playtime,kills=kills,bosses=bosses}
    end

    local insightBox=WINDOW_MANAGER:CreateControl(nil,page,CT_BACKDROP)
    insightBox:SetDimensions(932,52); insightBox:SetAnchor(TOPLEFT,page,TOPLEFT,20,574); insightBox:SetCenterColor(.035,.030,.024,.94); insightBox:SetEdgeColor(.34,.29,.18,.64); insightBox:SetEdgeTexture(nil,1,1,1)
    self.statisticsCharacterInsightBox=insightBox; self.statisticsCharacterInsights={}
    local keys={"bestDay","longest","streak","comparison","favoriteZone"}
    local widths={178,178,154,190,204}; local x=8
    for i,key in ipairs(keys) do
        local label=WINDOW_MANAGER:CreateControl(nil,insightBox,CT_LABEL); label:SetDimensions(widths[i],46); label:SetAnchor(TOPLEFT,insightBox,TOPLEFT,x,3); label:SetFont("$(MEDIUM_FONT)|13"); label:SetColor(.86,.81,.70,1); label:SetVerticalAlignment(TEXT_ALIGN_CENTER); label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        self.statisticsCharacterInsights[key]=label; x=x+widths[i]+4
    end
end

function TPM:SetCharacterStatisticsRange(days)
    if not self.saved then return end
    days = tonumber(days) or 7
    if days ~= 7 and days ~= 30 and days ~= 90 and days ~= 365 then days = 7 end
    self.saved.statisticsCharacterRangeDays = days
    self.saved.statisticsCharacterRangeOffset = 0
    self:RefreshPlayerStatisticsPage()
end

function TPM:StepCharacterStatisticsRangePage(direction)
    if not self.saved then return end
    local days = tonumber(self.saved.statisticsCharacterRangeDays) or 7
    local maxOffset = math.max(0, math.floor((days - 1) / 7) * 7)
    local offset = math.max(0, tonumber(self.saved.statisticsCharacterRangeOffset) or 0)
    offset = Clamp(offset + ((tonumber(direction) or 0) * 7), 0, maxOffset)
    self.saved.statisticsCharacterRangeOffset = offset
    self:RefreshPlayerStatisticsPage()
end

function TPM:GetCharacterDailyPlaytimeRows(days, pageOffset, maxRows)
    days = math.max(1, math.min(CHARACTER_PLAYTIME_RETENTION_DAYS, tonumber(days) or 7))
    pageOffset = math.max(0, math.min(days - 1, tonumber(pageOffset) or 0))
    maxRows = math.max(1, math.min(days - pageOffset, tonumber(maxRows) or days))
    local now = TPM_Now(); local todayKey = TPM_CharacterDayKey(now)
    local store = self:GetHistoryStore(); if store then self:MigrateCharacterPlaytime365(store) end
    local ledger = store and store.characterPlaytime365 or {}; local rows={}
    local firstOffset = pageOffset + maxRows - 1
    for offset=firstOffset,pageOffset,-1 do
        local dayKey=todayKey-offset; local entry=ledger[tostring(dayKey)]
        local utcOffset=type(entry)=="table" and tonumber(entry.utcOffset) or TPM_GetLocalUtcOffsetSeconds()
        local timestamp=TPM_CharacterDayStartTimestampWithOffset(dayKey,utcOffset)+43200
        local seconds=type(entry)=="table" and math.max(0,tonumber(entry.seconds) or 0) or 0
        if dayKey==todayKey then seconds=self:GetTodayPlaySeconds() end
        rows[#rows+1]={dayKey=dayKey,timestamp=timestamp,seconds=seconds,today=(dayKey==todayKey),hasData=(type(entry)=="table" or dayKey==todayKey),timeReliable=(type(entry)=="table" and entry.timeReliable==true),reconstructed=(type(entry)=="table" and entry.reconstructed==true),firstAt=type(entry)=="table" and tonumber(entry.firstAt) or nil,lastAt=type(entry)=="table" and tonumber(entry.lastAt) or nil,firstUtcOffset=type(entry)=="table" and tonumber(entry.firstUtcOffset or entry.utcOffset) or utcOffset,lastUtcOffset=type(entry)=="table" and tonumber(entry.lastUtcOffset or entry.utcOffset) or utcOffset,utcOffset=utcOffset,zones=type(entry)=="table" and entry.zones or nil,longestSessionSeconds=type(entry)=="table" and math.max(0,tonumber(entry.longestSessionSeconds) or 0) or 0,npcKills=type(entry)=="table" and math.max(0,tonumber(entry.npcKills) or 0) or 0,bossKills=type(entry)=="table" and math.max(0,tonumber(entry.bossKills) or 0) or 0,combatDataReliable=type(entry)=="table" and entry.combatDataReliable==true}
    end
    return rows
end

function TPM:GetCharacterCurrentStreak(maxDays)
    local days=math.max(1,math.min(CHARACTER_PLAYTIME_RETENTION_DAYS,tonumber(maxDays) or CHARACTER_PLAYTIME_RETENTION_DAYS))
    local rows=self:GetCharacterDailyPlaytimeRows(days,0,days); local streak=0
    for i=#rows,1,-1 do if (rows[i].seconds or 0)>0 then streak=streak+1 else break end end
    return streak
end

function TPM:GetCharacterLongestSessionSince(cutoffTimestamp)
    local store=self:GetHistoryStore(); local best=0
    for _,session in ipairs(store and store.sessions or {}) do
        if type(session)=="table" and (tonumber(session.endedAt) or 0)>=(tonumber(cutoffTimestamp) or 0) then best=math.max(best,tonumber(session.duration) or 0) end
    end
    local active=store and store.activeSession
    if type(active)=="table" then local endAt=active.segmentStartedAt and TPM_Now() or active.lastSeenAt; best=math.max(best,self:GetHistoryActiveElapsed(active,endAt)) end
    return math.max(0,Round(best))
end

function TPM:GetCurrentMountDisplayData()
    local mountId = 0
    local mountType = _G.COLLECTIBLE_CATEGORY_TYPE_MOUNT
    if type(GetActiveCollectibleByType) == "function" and type(mountType) == "number" then
        mountId = tonumber(GetActiveCollectibleByType(mountType)) or 0
    end

    if mountId <= 0 then
        return 0, self:L("STAT_CHARACTER_MOUNT_NONE"), nil
    end

    local mountName, mountIcon = "", nil
    local name, _, icon = GetCollectibleInfo(mountId)
    mountName = tostring(name or "")
    if type(icon) == "string" and icon ~= "" then mountIcon = icon end
    if mountName == "" and type(GetCollectibleName) == "function" then
        mountName = tostring(GetCollectibleName(mountId) or "")
    end
    if mountName ~= "" and type(zo_strformat) == "function" then
        mountName = zo_strformat("<<C:1>>", mountName)
    end
    if mountName == "" then mountName = self:L("STAT_CHARACTER_MOUNT_UNKNOWN") end
    return mountId, mountName, mountIcon
end

function TPM:RefreshPlayerStatisticsPage()
    if not self.statisticsPlayerPage or self.statisticsPlayerPage:IsHidden() then return end
    self:CheckpointHistory("character_view", false)
    self:RefreshCombatProgressionBars()

    local progress=self:GetPlayerProgressData(); local characterName=type(GetUnitName)=="function" and (GetUnitName("player") or "") or ""
    if type(zo_strformat)=="function" and characterName~="" then characterName=zo_strformat("<<C:1>>",characterName) end
    if characterName=="" then characterName=self:L("STAT_PLAYER_UNKNOWN") end
    local nowStamp=TPM_Now(); local updatedDate=TPM_GetLocalizedLogDateText(nowStamp,self.langCode); local updatedTime=TPM_GetLocalizedLogTimeText(nowStamp,self.langCode)
    self.statisticsPlayerPageSubtitle:SetText(self:L("STAT_PLAYER_PAGE_SUBTITLE").."  •  "..self:L("STAT_CHARACTER_UPDATED",updatedDate,updatedTime))
    self.statisticsPlayerProfileTitle:SetText(self:L("STAT_PLAYER_PROFILE")); self.statisticsPlayerProfileText:SetText(self:L("STAT_PLAYER_PROFILE_LINE",characterName,progress.level,progress.championPoints))
    local _, mountName, mountIcon = self:GetCurrentMountDisplayData()
    if self.statisticsPlayerMountTitle then self.statisticsPlayerMountTitle:SetText(self:L("STAT_CHARACTER_CURRENT_MOUNT")) end
    if self.statisticsPlayerMountText then self.statisticsPlayerMountText:SetText(mountName or "—") end
    if self.statisticsPlayerMountIcon then
        if type(mountIcon) == "string" and mountIcon ~= "" then
            self.statisticsPlayerMountIcon:SetTexture(mountIcon)
            self.statisticsPlayerMountIcon:SetHidden(false)
        else
            self.statisticsPlayerMountIcon:SetTexture("")
            self.statisticsPlayerMountIcon:SetHidden(true)
        end
    end

    local total=math.max(0,tonumber(self:SyncCurrentEsoPlayedTime()) or 0); local today=math.max(0,tonumber(self:GetTodayPlaySeconds()) or 0)
    local store=self:GetHistoryStore(); local active=store and store.activeSession; local session=0
    if type(active)=="table" then local endAt=active.segmentStartedAt and TPM_Now() or active.lastSeenAt; session=self:GetHistoryActiveElapsed(active,endAt) end

    local rangeDays=tonumber(self.saved and self.saved.statisticsCharacterRangeDays) or 7
    if rangeDays~=7 and rangeDays~=30 and rangeDays~=90 and rangeDays~=365 then rangeDays=7 end
    local maxOffset=math.max(0,math.floor((rangeDays-1)/7)*7); local pageOffset=Clamp(tonumber(self.saved.statisticsCharacterRangeOffset) or 0,0,maxOffset); self.saved.statisticsCharacterRangeOffset=pageOffset
    local rangeRows=self:GetCharacterDailyPlaytimeRows(rangeDays,0,rangeDays); local visibleRows=self:GetCharacterDailyPlaytimeRows(rangeDays,pageOffset,math.min(7,rangeDays-pageOffset))
    local rangeTotal,activeDays,maxDay,bestRow,dailyLongest=0,0,0,nil,0; local zones={}
    for _,row in ipairs(rangeRows) do
        rangeTotal=rangeTotal+(row.seconds or 0); if (row.seconds or 0)>0 then activeDays=activeDays+1 end
        if (row.seconds or 0)>maxDay then maxDay=row.seconds or 0; bestRow=row end
        dailyLongest=math.max(dailyLongest,tonumber(row.longestSessionSeconds) or 0)
        for _,z in pairs(row.zones or {}) do if type(z)=="table" then local key=tostring(z.zoneId or z.zoneName or ""); local dst=zones[key] or {seconds=0,name=tostring(z.zoneName or "")}; dst.seconds=dst.seconds+math.max(0,tonumber(z.seconds) or 0); if tostring(z.zoneName or "")~="" then dst.name=tostring(z.zoneName) end; zones[key]=dst end end
    end
    local avg=activeDays>0 and rangeTotal/activeDays or 0; local zone=""; if type(GetUnitZone)=="function" then zone=GetUnitZone("player") or "" end
    if zone~="" and type(zo_strformat)=="function" then zone=zo_strformat("<<C:1>>",zone) end
    if zone=="" then zone="—" end
    local favoriteName,favoriteSeconds="—",0; for _,z in pairs(zones) do if z.seconds>favoriteSeconds then favoriteSeconds=z.seconds; favoriteName=z.name~="" and z.name or "—" end end
    local cutoff=TPM_CharacterDayStartTimestampWithOffset(TPM_CharacterDayKey(nowStamp)-rangeDays+1,TPM_GetLocalUtcOffsetSeconds())
    local longest=math.max(dailyLongest,self:GetCharacterLongestSessionSince(cutoff)); local streak=self:GetCharacterCurrentStreak(CHARACTER_PLAYTIME_RETENTION_DAYS)
    local compareRows=self:GetCharacterDailyPlaytimeRows(14,0,14); local currentWeek,previousWeek=0,0
    for i,row in ipairs(compareRows) do if i<=7 then previousWeek=previousWeek+(row.seconds or 0) else currentWeek=currentWeek+(row.seconds or 0) end end
    local comparison=currentWeek-previousWeek

    local cards=self.statisticsCharacterCards or {}; local function SetCard(key,title,value) local c=cards[key]; if c then c.title:SetText(title); c.value:SetText(value) end end
    SetCard("hours",self:L("STAT_CHARACTER_LIFETIME_HOURS"),string.format("%.1f h",total/3600)); SetCard("days",self:L("STAT_CHARACTER_LIFETIME_DAYS"),string.format("%.2f",total/86400)); SetCard("today",self:L("STAT_CHARACTER_TODAY"),TPM_FormatDuration(today)); SetCard("session",self:L("STAT_CHARACTER_SESSION"),TPM_FormatDuration(session))
    SetCard("week",self:L("STAT_CHARACTER_RANGE_TOTAL",rangeDays),TPM_FormatDuration(rangeTotal)); SetCard("average",self:L("STAT_CHARACTER_AVG_DAY"),TPM_FormatDuration(avg)); SetCard("activeDays",self:L("STAT_CHARACTER_ACTIVE_DAYS_RANGE",rangeDays),tostring(activeDays).." / "..tostring(rangeDays)); SetCard("location",self:L("STAT_CHARACTER_LOCATION"),zone)

    self.statisticsCharacterDailyTitle:SetText(self:L("STAT_CHARACTER_DAILY_TITLE"))
    local headers=self.statisticsCharacterDailyHeaders or {}
    if headers.date then headers.date:SetText(self:L("STAT_CHARACTER_COL_DATE")) end
    if headers.playtime then headers.playtime:SetText(self:L("STAT_CHARACTER_COL_PLAYTIME")) end
    if headers.kills then headers.kills:SetText(self:L("STAT_CHARACTER_COL_KILLS")) end
    if headers.bosses then headers.bosses:SetText(self:L("STAT_CHARACTER_COL_BOSSES")) end
    local oldestShown=math.min(rangeDays,pageOffset+#visibleRows); local newestShown=math.min(rangeDays,pageOffset+1)
    self.statisticsCharacterDailyHint:SetText(self:L("STAT_CHARACTER_RANGE_HINT",newestShown,oldestShown,rangeDays))
    local rangeAccentR,rangeAccentG,rangeAccentB=self:GetStatisticsThemeAccentColor()
    for _,button in ipairs(self.statisticsCharacterRangeButtons or {}) do
        local selected=tonumber(button.rangeDays)==rangeDays
        if selected then button:SetNormalFontColor(rangeAccentR,rangeAccentG,rangeAccentB,1) else button:SetNormalFontColor(.75,.70,.60,1) end
    end
    if self.statisticsCharacterOlderButton then self.statisticsCharacterOlderButton:SetHidden(pageOffset>=maxOffset) end
    if self.statisticsCharacterNewerButton then self.statisticsCharacterNewerButton:SetHidden(pageOffset<=0) end

    for i,rowControl in ipairs(self.statisticsCharacterDailyRows or {}) do
        local data=visibleRows[i]
        if data then
            rowControl.control:SetHidden(false)
            local dateText=data.today and self:L("STAT_CHARACTER_TODAY_LABEL") or TPM_GetLocalizedCharacterDateText(data.timestamp,self.langCode,data.utcOffset)
            rowControl.date:SetText(dateText)
            if not data.hasData then
                rowControl.playtime:SetText(self:L("STAT_CHARACTER_NO_HISTORY_SHORT"))
                rowControl.kills:SetText("—")
                rowControl.bosses:SetText("—")
            else
                rowControl.playtime:SetText(TPM_FormatDuration(data.seconds or 0))
                if data.combatDataReliable then
                    rowControl.kills:SetText(tostring(math.max(0, tonumber(data.npcKills) or 0)))
                    rowControl.bosses:SetText(tostring(math.max(0, tonumber(data.bossKills) or 0)))
                else
                    rowControl.kills:SetText("—")
                    rowControl.bosses:SetText("—")
                end
            end
        else
            rowControl.control:SetHidden(true)
        end
    end

    local insights=self.statisticsCharacterInsights or {}; local bestDate=bestRow and TPM_GetLocalizedCharacterDateText(bestRow.timestamp,self.langCode,bestRow.utcOffset) or "—"
    local vr,vg,vb=self:GetStatisticsThemeProgressColor(); local valueHex=string.format("%02X%02X%02X",math.floor(Clamp(vr,0,1)*255+.5),math.floor(Clamp(vg,0,1)*255+.5),math.floor(Clamp(vb,0,1)*255+.5))
    local function InsightValue(value) return "|c"..valueHex..tostring(value or "").."|r" end
    if insights.bestDay then insights.bestDay:SetText(self:L("STAT_CHARACTER_BEST_DAY").."\n"..InsightValue(bestDate.." • "..TPM_FormatDuration(bestRow and bestRow.seconds or 0))) end
    if insights.longest then insights.longest:SetText(self:L("STAT_CHARACTER_LONGEST_SESSION").."\n"..InsightValue(TPM_FormatDuration(longest))) end
    if insights.streak then insights.streak:SetText(self:L("STAT_CHARACTER_STREAK").."\n"..InsightValue(self:L("STAT_CHARACTER_STREAK_VALUE",streak))) end
    if insights.comparison then insights.comparison:SetText(self:L("STAT_CHARACTER_WEEK_COMPARE").."\n"..InsightValue(TPM_SignedDuration(comparison))) end
    if insights.favoriteZone then insights.favoriteZone:SetText(self:L("STAT_CHARACTER_FAVORITE_ZONE").."\n"..InsightValue(favoriteName.." • "..TPM_FormatDuration(favoriteSeconds))) end
    self:EnforceStatisticsDarkModeAfterRefresh()
end

function TPM:CreateEconomyCurrencyCard(parent, name, x, y, width)
    local card = WINDOW_MANAGER:CreateControl(name, parent, CT_BACKDROP)
    card:SetDimensions(width, 60)
    card:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    card:SetCenterColor(0.022, 0.021, 0.019, 0.99)
    card:SetEdgeColor(0.20, 0.18, 0.14, 0.72)
    card:SetEdgeTexture(nil, 1, 1, 1)
    card:SetMouseEnabled(false)

    local accent = WINDOW_MANAGER:CreateControl(nil, card, CT_BACKDROP)
    accent:SetDimensions(3, 58)
    accent:SetAnchor(LEFT, card, LEFT, 0, 0)
    accent:SetCenterColor(0.86, 0.66, 0.18, 0.90)
    accent:SetEdgeColor(0, 0, 0, 0)

    local iconBack = WINDOW_MANAGER:CreateControl(nil, card, CT_BACKDROP)
    iconBack:SetDimensions(50, 50)
    iconBack:SetAnchor(LEFT, card, LEFT, 9, 0)
    iconBack:SetCenterColor(0.035, 0.032, 0.026, 0.98)
    iconBack:SetEdgeColor(0.50, 0.40, 0.18, 0.72)
    iconBack:SetEdgeTexture(nil, 1, 1, 1)

    local icon = WINDOW_MANAGER:CreateControl(nil, iconBack, CT_TEXTURE)
    icon:SetDimensions(44, 44)
    icon:SetAnchor(CENTER, iconBack, CENTER, 0, 0)

    local title = WINDOW_MANAGER:CreateControl(name .. "Title", card, CT_LABEL)
    title:SetDimensions(width - 82, 20)
    title:SetAnchor(TOPLEFT, card, TOPLEFT, 70, 5)
    title:SetFont("$(BOLD_FONT)|16")
    title:SetColor(0.90, 0.77, 0.34, 1)
    title:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    title:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local line = WINDOW_MANAGER:CreateControl(name .. "Line", card, CT_LABEL)
    line:SetDimensions(width - 82, 18)
    line:SetAnchor(TOPLEFT, card, TOPLEFT, 70, 24)
    line:SetFont("$(MEDIUM_FONT)|14")
    line:SetColor(0.80, 0.77, 0.70, 1)
    line:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    line:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local detail = WINDOW_MANAGER:CreateControl(name .. "Detail", card, CT_LABEL)
    detail:SetDimensions(width - 82, 15)
    detail:SetAnchor(TOPLEFT, card, TOPLEFT, 70, 42)
    detail:SetFont("$(MEDIUM_FONT)|12")
    detail:SetColor(0.70, 0.68, 0.62, 1)
    detail:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    detail:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    return {
        control = card,
        accent = accent,
        iconBack = iconBack,
        icon = icon,
        title = title,
        line = line,
        detail = detail,
        isGoldCard = false,
    }
end

function TPM:CreateEconomyGoldCard(parent, name, x, y, width)
    local card = WINDOW_MANAGER:CreateControl(name, parent, CT_BACKDROP)
    card:SetDimensions(width, 132)
    card:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    card:SetCenterColor(0.060, 0.046, 0.018, 0.995)
    card:SetEdgeColor(0.82, 0.62, 0.14, 0.92)
    card:SetEdgeTexture(nil, 1, 1, 1)
    card:SetMouseEnabled(true)

    local topBand = WINDOW_MANAGER:CreateControl(nil, card, CT_BACKDROP)
    topBand:SetDimensions(width - 2, 2)
    topBand:SetAnchor(TOPLEFT, card, TOPLEFT, 1, 1)
    topBand:SetCenterColor(0.95, 0.76, 0.16, 0.82)
    topBand:SetEdgeColor(0, 0, 0, 0)

    local iconBack = WINDOW_MANAGER:CreateControl(nil, card, CT_BACKDROP)
    iconBack:SetDimensions(78, 78)
    iconBack:SetAnchor(LEFT, card, LEFT, 28, 0)
    iconBack:SetCenterColor(0.095, 0.068, 0.018, 0.99)
    iconBack:SetEdgeColor(0.92, 0.72, 0.18, 0.88)
    iconBack:SetEdgeTexture(nil, 1, 1, 1)

    local icon = WINDOW_MANAGER:CreateControl(nil, iconBack, CT_TEXTURE)
    icon:SetDimensions(70, 70)
    icon:SetAnchor(CENTER, iconBack, CENTER, 0, 0)

    local title = WINDOW_MANAGER:CreateControl(name .. "Title", card, CT_LABEL)
    title:SetDimensions(740, 28)
    title:SetAnchor(TOPLEFT, card, TOPLEFT, 142, 8)
    title:SetFont("$(BOLD_FONT)|23")
    title:SetColor(1.00, 0.88, 0.28, 1)
    title:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    title:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local function CreateTopMetric(key, xPos)
        local label = WINDOW_MANAGER:CreateControl(nil, card, CT_LABEL)
        label:SetDimensions(190, 18)
        label:SetAnchor(TOPLEFT, card, TOPLEFT, xPos, 39)
        label:SetFont("$(MEDIUM_FONT)|13")
        label:SetColor(0.78, 0.72, 0.58, 1)
        label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)

        local value = WINDOW_MANAGER:CreateControl(nil, card, CT_LABEL)
        value:SetDimensions(190, 26)
        value:SetAnchor(TOPLEFT, card, TOPLEFT, xPos, 55)
        value:SetFont("$(ANTIQUE_FONT)|24")
        value:SetColor(0.96, 0.84, 0.38, 1)
        value:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        value:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        return { label = label, value = value }
    end

    local cash = CreateTopMetric("cash", 142)
    local bank = CreateTopMetric("bank", 390)
    local total = CreateTopMetric("total", 638)

    for _, xPos in ipairs({ 370, 618 }) do
        local divider = WINDOW_MANAGER:CreateControl(nil, card, CT_BACKDROP)
        divider:SetDimensions(1, 42)
        divider:SetAnchor(TOPLEFT, card, TOPLEFT, xPos, 38)
        divider:SetCenterColor(0.44, 0.32, 0.10, 0.68)
        divider:SetEdgeColor(0, 0, 0, 0)
    end

    local midDivider = WINDOW_MANAGER:CreateControl(nil, card, CT_BACKDROP)
    midDivider:SetDimensions(width - 158, 1)
    midDivider:SetAnchor(TOPLEFT, card, TOPLEFT, 142, 84)
    midDivider:SetCenterColor(0.62, 0.46, 0.12, 0.72)
    midDivider:SetEdgeColor(0, 0, 0, 0)
    midDivider:SetHidden(false)

    local function CreateBottomMetric(xPos, valueColor)
        local label = WINDOW_MANAGER:CreateControl(nil, card, CT_LABEL)
        label:SetDimensions(142, 16)
        label:SetAnchor(TOPLEFT, card, TOPLEFT, xPos, 91)
        label:SetFont("$(MEDIUM_FONT)|12")
        label:SetColor(0.76, 0.71, 0.61, 1)
        label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)

        local value = WINDOW_MANAGER:CreateControl(nil, card, CT_LABEL)
        value:SetDimensions(142, 20)
        value:SetAnchor(TOPLEFT, card, TOPLEFT, xPos, 106)
        value:SetFont("$(BOLD_FONT)|14")
        value:SetColor(valueColor[1], valueColor[2], valueColor[3], 1)
        value:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        value:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        return { label = label, value = value }
    end

    -- Five compact ledger subtotals fit across the promoted Gold card.
    -- Bounty paid is a Justice subset of Spent, not additional spending.
    local received = CreateBottomMetric(142, { 0.48, 0.92, 0.40 })
    local spent = CreateBottomMetric(292, { 0.94, 0.52, 0.32 })
    local fence = CreateBottomMetric(442, { 0.86, 0.70, 0.30 })
    local stolen = CreateBottomMetric(592, { 0.96, 0.60, 0.32 })
    local bounty = CreateBottomMetric(742, { 0.94, 0.72, 0.28 })
    for _, metric in ipairs({ received, spent, fence, stolen, bounty }) do
        metric.label:SetHidden(false)
        metric.value:SetHidden(false)
    end

    return {
        control = card,
        iconBack = iconBack,
        icon = icon,
        title = title,
        cash = cash,
        bank = bank,
        total = total,
        received = received,
        spent = spent,
        fence = fence,
        stolen = stolen,
        bounty = bounty,
        isGoldCard = true,
    }
end


function TPM:CreateEconomyDetailWindow()
    if self.economyDetailWindow then return end
    local parent = self.statisticsWindow or GuiRoot
    local w = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "EconomyDetailWindow")
    w:SetDimensions(760, 520)
    local savedX=tonumber(self.saved and self.saved.economyDetailX)
    local savedY=tonumber(self.saved and self.saved.economyDetailY)
    if savedX and savedY then
        w:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, savedX, savedY)
    else
        w:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    w:SetClampedToScreen(true)
    w:SetMouseEnabled(true)
    w:SetMovable(true)
    w:SetHandler("OnMoveStop", function(control)
        if TPM.saved then
            TPM.saved.economyDetailX=Round(tonumber(control:GetLeft()) or 0)
            TPM.saved.economyDetailY=Round(tonumber(control:GetTop()) or 0)
        end
    end)
    w:SetHidden(true)
    if w.SetDrawTier then w:SetDrawTier(DT_HIGH) end
    if w.SetDrawLayer then w:SetDrawLayer(DL_OVERLAY) end

    local bg = WINDOW_MANAGER:CreateControl(nil, w, CT_BACKDROP)
    bg:SetAnchorFill(w)
    bg:SetCenterColor(0.025,0.022,0.016,0.995)
    bg:SetEdgeColor(0.78,0.61,0.18,0.95)
    bg:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds",128,16,2)
    bg:SetInsets(4,4,-4,-4)

    local title = WINDOW_MANAGER:CreateControl(nil,w,CT_LABEL)
    title:SetAnchor(TOPLEFT,w,TOPLEFT,22,16); title:SetDimensions(600,30)
    title:SetFont("ZoFontWinH2"); title:SetColor(0.95,0.79,0.28,1)
    self.economyDetailTitle = title

    local close = WINDOW_MANAGER:CreateControl(nil,w,CT_BUTTON)
    close:SetDimensions(34,30); close:SetAnchor(TOPRIGHT,w,TOPRIGHT,-14,12)
    close:SetFont("$(BOLD_FONT)|22"); close:SetText("×")
    close:SetHandler("OnClicked", function() w:SetHidden(true) end)

    local focusLabel = WINDOW_MANAGER:CreateControl(nil,w,CT_LABEL)
    focusLabel:SetAnchor(TOPLEFT,w,TOPLEFT,24,62); focusLabel:SetDimensions(60,24)
    focusLabel:SetFont("$(MEDIUM_FONT)|14"); focusLabel:SetColor(.75,.71,.62,1)
    focusLabel:SetText(self:L("ECON_DETAIL_FOCUS"))

    local function MakeSelector(name, x, width, click)
        local c=WINDOW_MANAGER:CreateControl(name,w,CT_BUTTON)
        c:SetDimensions(width,28); c:SetAnchor(TOPLEFT,w,TOPLEFT,x,60)
        c:SetFont("$(MEDIUM_FONT)|15"); c:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        c:SetNormalFontColor(.94,.90,.80,1); c:SetMouseOverFontColor(1,.84,.30,1)
        c:SetHandler("OnClicked",click)
        return c
    end
    self.economyDetailZoneButton=MakeSelector(ADDON_NAME.."EconomyDetailZone",84,260,function(button) TPM:ShowEconomyDetailZoneMenu(button) end)

    local viewLabel=WINDOW_MANAGER:CreateControl(nil,w,CT_LABEL)
    viewLabel:SetAnchor(TOPLEFT,w,TOPLEFT,370,62); viewLabel:SetDimensions(45,24)
    viewLabel:SetFont("$(MEDIUM_FONT)|14"); viewLabel:SetColor(.75,.71,.62,1)
    viewLabel:SetText(self:L("ECON_DETAIL_VIEW"))
    self.economyDetailViewButton=MakeSelector(ADDON_NAME.."EconomyDetailView",415,210,function(button) TPM:ShowEconomyDetailViewMenu(button) end)

    local info=WINDOW_MANAGER:CreateControl(nil,w,CT_BUTTON)
    info:SetDimensions(30,28); info:SetAnchor(TOPLEFT,w,TOPLEFT,640,60)
    info:SetFont("$(BOLD_FONT)|16"); info:SetText("(?)")
    info:SetHandler("OnMouseEnter",function(c)
        InitializeTooltip(InformationTooltip,c,TOPRIGHT,0,0,TOPLEFT)
        SetTooltipText(InformationTooltip,TPM:GetEconomyTrackingTooltip())
    end)
    info:SetHandler("OnMouseExit",function() ClearTooltip(InformationTooltip) end)

    self.economyDetailBody=WINDOW_MANAGER:CreateControl(nil,w,CT_LABEL)
    self.economyDetailBody:SetAnchor(TOPLEFT,w,TOPLEFT,28,112)
    self.economyDetailBody:SetDimensions(704,370)
    self.economyDetailBody:SetFont("$(MEDIUM_FONT)|18")
    self.economyDetailBody:SetColor(.91,.88,.79,1)
    self.economyDetailBody:SetVerticalAlignment(TEXT_ALIGN_TOP)
    self.economyDetailWindow=w
end

function TPM:GetEconomyTrackingTooltip()
    local stamp=tonumber(self.saved and self.saved.economyZoneTrackingStartedAt) or 0
    local dateText=self:L("ECON_DETAIL_UNKNOWN_DATE")
    if stamp>0 then
        local res=FormatShortDate(stamp)
        if res and res~="" then dateText=res end
    elseif stamp>0 and type(os)=="table" and type(os.date)=="function" then
        dateText=os.date("%d.%m.%Y",stamp)
    end
    return self:L("ECON_DETAIL_TRACKING_TT",dateText)
end

function TPM:SetEconomyDetailZone(zoneId)
    if not self.saved then return end
    zoneId=tonumber(zoneId) or 0
    self.saved.economyDetailFocusZoneId=zoneId
    self:HideEconomyFocusDropdown()
    self:RefreshEconomyDetailWindow()
    self:RefreshEconomyStatisticsPage()
end

function TPM:SetEconomyDetailView(view)
    if not self.saved then return end
    local valid={overview=true,records=true,crime=true,bank=true}
    if not valid[view] then view="overview" end
    self.saved.economyDetailView=view
    self:RefreshEconomyDetailWindow()
end

function TPM:BringPopupMenuToFront()
    local candidates = {
        _G.ZO_Menu,
        _G.ZO_MenuItems,
        _G.ZO_ComboBox_Menu,
        _G.ZO_ComboBoxDropdown,
    }
    for _, control in ipairs(candidates) do
        if control then
            if control.SetDrawTier then control:SetDrawTier(DT_HIGH) end
            if control.SetDrawLayer then control:SetDrawLayer(DL_OVERLAY) end
            if control.SetDrawLevel then control:SetDrawLevel(10000) end
        end
    end
end


function TPM:GetEconomyFocusDropdownChoices()
    local result = {}
    result[#result+1] = {zoneId=0, name=self:L("ECON_DETAIL_ALL_TAMRIEL")}
    local currentId=self:GetEconomyTrackingZoneId()
    if currentId and currentId>0 then
        result[#result+1] = {
            zoneId=currentId,
            name=self:L("ECON_DETAIL_CURRENT_ZONE", self:GetEconomyZoneName(currentId))
        }
    end
    for _,choice in ipairs(self:GetEconomyZoneChoices() or {}) do
        if choice.zoneId and choice.zoneId>0 and choice.zoneId~=currentId then
            result[#result+1] = {zoneId=choice.zoneId, name=choice.name}
        end
    end
    return result
end

function TPM:RefreshEconomyFocusDropdown()
    local dropdown=self.economyFocusDropdown
    if not dropdown then return end
    local choices=self:GetEconomyFocusDropdownChoices()
    self.economyFocusDropdownChoices=choices

    local visibleRows=9
    local maxOffset=math.max(1,#choices-visibleRows+1)
    self.economyFocusDropdownOffset=Clamp(tonumber(self.economyFocusDropdownOffset) or 1,1,maxOffset)
    local selectedId=tonumber(self.saved and self.saved.economyDetailFocusZoneId) or 0

    for i,row in ipairs(self.economyFocusDropdownRows or {}) do
        local choice=choices[self.economyFocusDropdownOffset+i-1]
        if choice then
            row.zoneId=choice.zoneId
            if row.rowText then row.rowText:SetText(tostring(choice.name or "")) end
            row:SetHidden(false)
            if row.rowBack then row.rowBack:SetHidden(false) end

            local selected=tonumber(choice.zoneId) == selectedId
            if self:IsStatisticsDarkDesign() then
                if row.rowBack then row.rowBack:SetCenterColor(0,0,0,selected and .44 or .24); row.rowBack:SetEdgeColor(1,1,1,selected and .40 or .18) end
                if row.rowText then row.rowText:SetColor(1,1,1,1) end
            else
                if row.rowBack then
                    if selected then
                        row.rowBack:SetCenterColor(0.080,0.060,0.020,0.98)
                        row.rowBack:SetEdgeColor(0.92,0.72,0.20,0.95)
                    else
                        row.rowBack:SetCenterColor(0.018,0.016,0.012,0.94)
                        row.rowBack:SetEdgeColor(0.18,0.15,0.09,0.75)
                    end
                end
                if row.rowText then row.rowText:SetColor(selected and 1.00 or 0.86, selected and 0.84 or 0.82, selected and 0.30 or 0.72, 1) end
            end
        else
            row.zoneId=nil
            if row.rowText then row.rowText:SetText("") end
            row:SetHidden(true)
            if row.rowBack then row.rowBack:SetHidden(true) end
        end
    end

    -- Thumb size and position reflect the visible fraction/list offset.
    if self.economyFocusScrollThumb and self.economyFocusScrollRail then
        local railH=236
        local fraction=math.min(1, visibleRows / math.max(visibleRows,#choices))
        local thumbH=math.max(32, math.floor(railH*fraction))
        self.economyFocusScrollThumb:SetHeight(thumbH)
        local travel=math.max(0,railH-thumbH)
        local ratio=(maxOffset<=1) and 0 or ((self.economyFocusDropdownOffset-1)/(maxOffset-1))
        self.economyFocusScrollThumb:ClearAnchors()
        self.economyFocusScrollThumb:SetAnchor(TOP, self.economyFocusScrollRail, TOP, 0, 1 + math.floor(travel*ratio))
        self.economyFocusScrollRail:SetHidden(#choices<=visibleRows)
        self.economyFocusScrollThumb:SetHidden(#choices<=visibleRows)
    end
end

function TPM:HideEconomyFocusDropdown()
    if self.economyFocusDropdown then self.economyFocusDropdown:SetHidden(true) end
    if self.statisticsEconomyFocusArrow then self.statisticsEconomyFocusArrow:SetText("⌄") end
end

function TPM:ToggleEconomyFocusDropdown()
    local dropdown=self.economyFocusDropdown
    if not dropdown then return end
    if dropdown:IsHidden() then
        self.economyFocusDropdownOffset=1
        self:RefreshEconomyFocusDropdown()
        dropdown:SetDrawTier(DT_HIGH)
        dropdown:SetDrawLayer(DL_OVERLAY)
        if dropdown.SetDrawLevel then dropdown:SetDrawLevel(20000) end
        if dropdown.BringWindowToTop then dropdown:BringWindowToTop() end
        dropdown:SetHidden(false)
        if self.statisticsEconomyFocusArrow then self.statisticsEconomyFocusArrow:SetText("⌃") end
        self:EnforceStatisticsDarkModeAfterRefresh()
    else
        self:HideEconomyFocusDropdown()
    end
end

function TPM:ScrollEconomyFocusDropdown(delta)
    if not self.economyFocusDropdown or self.economyFocusDropdown:IsHidden() then return end
    local choices=self.economyFocusDropdownChoices or self:GetEconomyFocusDropdownChoices()
    local visibleRows=9
    local maxOffset=math.max(1,#choices-visibleRows+1)
    local step=(tonumber(delta) or 0)>0 and -1 or 1
    self.economyFocusDropdownOffset=Clamp((tonumber(self.economyFocusDropdownOffset) or 1)+step,1,maxOffset)
    self:RefreshEconomyFocusDropdown()
end

function TPM:ShowEconomyDetailZoneMenu(anchor)
    -- 2.6.47: Economy now uses TPM's own top-level dropdown. The standard ESO
    -- menu could render behind the high-level Statistics journal.
    if self.economyFocusDropdown then
        self:ToggleEconomyFocusDropdown()
        return
    end
end

function TPM:ShowEconomyDetailViewMenu(anchor)
    if _G.ClearMenu then ClearMenu() end
    local views={
        {"overview","ECON_DETAIL_OVERVIEW"},
        {"records","ECON_DETAIL_RECORDS"},
        {"crime","ECON_DETAIL_CRIME"},
        {"bank","ECON_DETAIL_BANK"},
    }
    local canMenu=type(ClearMenu)=="function" and type(AddMenuItem)=="function" and type(ShowMenu)=="function"
    if canMenu then
        ClearMenu()
        for _,item in ipairs(views) do
            local view,key=item[1],item[2]
            AddMenuItem(self:L(key), function() TPM:SetEconomyDetailView(view) end)
        end
        ShowMenu(anchor)
        return
    end

    local current=self.saved.economyDetailView or "overview"
    local idx=1
    for i,item in ipairs(views) do if item[1]==current then idx=i break end end
    self:SetEconomyDetailView(views[(idx % #views)+1][1])
    self:BringPopupMenuToFront()
end

function TPM:GetEconomyZoneRanking(field)
    local rows={}
    local store=self:GetEconomyZoneStore()
    for _,e in pairs((store and store.zones) or {}) do
        local value = field=="net"
            and ((tonumber(e.received) or 0)-(tonumber(e.spent) or 0))
            or (tonumber(e[field]) or 0)
        -- Empty zones make rankings noisy. "Most profitable" also only includes
        -- genuinely profitable zones; losses remain visible in the overview.
        if (field=="net" and value>0) or (field~="net" and value>0) then
            rows[#rows+1]={zoneId=e.zoneId,name=self:GetEconomyZoneName(e.zoneId),value=value}
        end
    end
    table.sort(rows,function(a,b)
        if a.value == b.value then return string.lower(a.name or "") < string.lower(b.name or "") end
        return a.value>b.value
    end)
    return rows
end

function TPM:GetEconomyZoneRank(zoneId, field)
    zoneId=tonumber(zoneId) or 0
    if zoneId<=0 then return nil end
    for i,row in ipairs(self:GetEconomyZoneRanking(field)) do
        if tonumber(row.zoneId)==zoneId then return i end
    end
    return nil
end

function TPM:RefreshEconomyDetailWindow()
    local w=self.economyDetailWindow
    if not w or w:IsHidden() then return end
    self:GetEconomyZoneStore()
    local zoneId=tonumber(self.saved.economyDetailFocusZoneId) or 0
    local view=self.saved.economyDetailView or "overview"
    self.economyDetailTitle:SetText(self:L("ECON_DETAIL_TITLE"))
    self.economyDetailZoneButton:SetText(self:GetEconomyZoneName(zoneId).."  ▼")
    local viewKeys={overview="ECON_DETAIL_OVERVIEW",records="ECON_DETAIL_RECORDS",crime="ECON_DETAIL_CRIME",bank="ECON_DETAIL_BANK"}
    self.economyDetailViewButton:SetText(self:L(viewKeys[view] or "ECON_DETAIL_OVERVIEW").."  ▼")
    local a=self:GetEconomyDetailAggregate(zoneId)
    local body={}
    if view=="overview" then
        body[#body+1]=self:L("ECON_DETAIL_INCOME")..": |c70D060+"..FormatNumber(a.received).."|r"
        body[#body+1]=self:L("ECON_DETAIL_EXPENSES")..": |cE07050-"..FormatNumber(a.spent).."|r"
        local sign=a.net>=0 and "+" or "-"
        body[#body+1]=self:L("ECON_DETAIL_NET")..": "..sign..FormatNumber(math.abs(a.net))
        body[#body+1]=""
        body[#body+1]=self:L("ECON_DETAIL_TRANSACTIONS")..": "..FormatNumber(a.transactions)
        body[#body+1]=self:L("ECON_DETAIL_FENCE")..": +"..FormatNumber(a.fenceSales)
        body[#body+1]=self:L("ECON_DETAIL_STOLEN")..": +"..FormatNumber(a.stolenGold)
        body[#body+1]=self:L("ECON_DETAIL_BOUNTY")..": -"..FormatNumber(a.bountyPaid)
    elseif view=="crime" then
        body[#body+1]=self:L("ECON_DETAIL_FENCE")..": +"..FormatNumber(a.fenceSales)
        body[#body+1]=self:L("ECON_DETAIL_STOLEN")..": +"..FormatNumber(a.stolenGold)
        body[#body+1]=self:L("ECON_DETAIL_BOUNTY")..": -"..FormatNumber(a.bountyPaid)
        body[#body+1]=""
        local crimeNet=(a.fenceSales or 0)+(a.stolenGold or 0)-(a.bountyPaid or 0)
        local crimeSign=crimeNet>=0 and "+" or "-"
        body[#body+1]=self:L("ECON_DETAIL_CRIME_NET")..": "..crimeSign..FormatNumber(math.abs(crimeNet))
    elseif view=="bank" then
        body[#body+1]=self:L("ECON_DETAIL_DEPOSITS")..": "..FormatNumber(a.bankDeposited)
        body[#body+1]=self:L("ECON_DETAIL_WITHDRAWALS")..": "..FormatNumber(a.bankWithdrawn)
    else
        local fields={{"net","ECON_DETAIL_PROFIT_RANK"},{"received","ECON_DETAIL_REVENUE_RANK"},{"spent","ECON_DETAIL_SPENDING_RANK"},
                      {"fenceSales","ECON_DETAIL_FENCE_RANK"},{"stolenGold","ECON_DETAIL_THEFT_RANK"},{"bountyPaid","ECON_DETAIL_BOUNTY_RANK"}}
        for _,f in ipairs(fields) do
            body[#body+1]="|cE6C45C"..self:L(f[2]).."|r"
            local rows=self:GetEconomyZoneRanking(f[1])
            if #rows==0 then
                body[#body+1]=self:L("ECON_DETAIL_NO_DATA")
            else
                for i=1,math.min(5,#rows) do
                    local r=rows[i]
                    body[#body+1]=string.format("%d. %s   %s",i,r.name,FormatNumber(r.value))
                end
                if zoneId>0 then
                    local rank=self:GetEconomyZoneRank(zoneId,f[1])
                    if rank and rank>5 then
                        body[#body+1]=self:L("ECON_DETAIL_SELECTED_RANK", self:GetEconomyZoneName(zoneId), rank)
                    end
                end
            end
            body[#body+1]=""
        end
    end
    self.economyDetailBody:SetText(table.concat(body,"\n"))
end

function TPM:ShowEconomyDetailWindow()
    self:CreateEconomyDetailWindow()
    self:GetEconomyZoneStore()
    self.economyDetailWindow:SetHidden(false)
    self:RefreshEconomyDetailWindow()
end

function TPM:CreateEconomyStatisticsPage(control)
    if self.statisticsEconomyPage then return end

    local page = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "StatisticsEconomyPage", control, CT_BACKDROP)
    page:SetAnchor(TOPLEFT, control, TOPLEFT, 14, 60)
    page:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -14, -55)
    page:SetCenterColor(0.036, 0.032, 0.025, 1.00)
    page:SetEdgeColor(0.28, 0.22, 0.10, 0.90)
    page:SetEdgeTexture(nil, 1, 1, 1)
    page:SetMouseEnabled(true)
    page:SetHidden(true)
    self.statisticsEconomyPage = page

    local title = WINDOW_MANAGER:CreateControl(nil, page, CT_LABEL)
    title:SetDimensions(920, 34)
    title:SetAnchor(TOPLEFT, page, TOPLEFT, 20, 14)
    title:SetFont("ZoFontWinH3")
    title:SetColor(0.90, 0.77, 0.34, 1)
    title:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    title:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    title:SetHidden(true)
    self.statisticsEconomyPageTitle = title

    local subtitle = WINDOW_MANAGER:CreateControl(nil, page, CT_LABEL)
    subtitle:SetDimensions(920, 24)
    subtitle:SetAnchor(TOPLEFT, page, TOPLEFT, 20, 14)
    subtitle:SetFont("$(MEDIUM_FONT)|18")
    subtitle:SetColor(0.74, 0.70, 0.62, 1)
    subtitle:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    subtitle:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.statisticsEconomyPageSubtitle = subtitle
    subtitle:SetDimensions(505, 24)

    -- Compact journal-style zone focus selector.
    local focusGroup = WINDOW_MANAGER:CreateControl(ADDON_NAME.."EconomyFocusGroup", page, CT_CONTROL)
    focusGroup:SetDimensions(300, 30)
    focusGroup:SetAnchor(TOPRIGHT, page, TOPRIGHT, -18, 9)
    focusGroup:SetMouseEnabled(false)

    local focusLabel = WINDOW_MANAGER:CreateControl(nil, focusGroup, CT_LABEL)
    focusLabel:SetDimensions(52, 28)
    focusLabel:SetAnchor(LEFT, focusGroup, LEFT, 0, 0)
    focusLabel:SetFont("$(MEDIUM_FONT)|12")
    focusLabel:SetColor(0.76,0.72,0.64,1)
    focusLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    focusLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    focusLabel:SetText(self:L("ECON_DETAIL_FOCUS"))
    self.statisticsEconomyFocusLabel = focusLabel

    local selector = WINDOW_MANAGER:CreateControl(ADDON_NAME.."EconomyFocusSelector", focusGroup, CT_CONTROL)
    selector:SetDimensions(240, 26)
    selector:SetAnchor(RIGHT, focusGroup, RIGHT, 0, 0)
    selector:SetMouseEnabled(true)

    local selectorBg = WINDOW_MANAGER:CreateControl(nil, selector, CT_BACKDROP)
    selectorBg:SetAnchorFill(selector)
    selectorBg:SetCenterColor(0.026,0.023,0.017,0.98)
    selectorBg:SetEdgeColor(0.62,0.49,0.17,0.90)
    selectorBg:SetEdgeTexture(nil,1,1,1)
    selectorBg:SetMouseEnabled(false)

    local selected = WINDOW_MANAGER:CreateControl(nil, selector, CT_LABEL)
    selected:SetDimensions(204,24)
    selected:SetAnchor(LEFT, selector, LEFT, 10, 0)
    selected:SetFont("$(MEDIUM_FONT)|13")
    selected:SetColor(0.92,0.87,0.73,1)
    selected:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    selected:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local arrowBack = WINDOW_MANAGER:CreateControl(nil, selector, CT_BACKDROP)
    arrowBack:SetDimensions(24,22)
    arrowBack:SetAnchor(RIGHT, selector, RIGHT, -3, 0)
    arrowBack:SetCenterColor(0.045,0.036,0.018,0.96)
    arrowBack:SetEdgeColor(0.50,0.38,0.12,0.80)
    arrowBack:SetEdgeTexture(nil,1,1,1)
    arrowBack:SetMouseEnabled(false)

    local arrow = WINDOW_MANAGER:CreateControl(nil, arrowBack, CT_LABEL)
    arrow:SetDimensions(20,20)
    arrow:SetAnchor(CENTER, arrowBack, CENTER, 0, 0)
    arrow:SetFont("$(BOLD_FONT)|14")
    arrow:SetColor(0.96,0.79,0.24,1)
    arrow:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    arrow:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    arrow:SetText("⌄")
    selector:SetHandler("OnMouseEnter", function()
        if TPM:IsStatisticsDarkDesign() then
            selectorBg:SetCenterColor(0,0,0,0.44); selectorBg:SetEdgeColor(1,1,1,0.46)
        else
            selectorBg:SetCenterColor(0.070,0.054,0.022,0.98); selectorBg:SetEdgeColor(0.92,0.72,0.20,1)
        end
    end)
    selector:SetHandler("OnMouseExit", function()
        if TPM:IsStatisticsDarkDesign() then
            selectorBg:SetCenterColor(0,0,0,0.30); selectorBg:SetEdgeColor(1,1,1,0.28)
        else
            selectorBg:SetCenterColor(0.026,0.023,0.017,0.98); selectorBg:SetEdgeColor(0.62,0.49,0.17,0.90)
        end
    end)
    selector:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
            TPM:ToggleEconomyFocusDropdown()
        end
    end)
    selector:SetHandler("OnMouseWheel", function(_, delta)
        if TPM.economyFocusDropdown and not TPM.economyFocusDropdown:IsHidden() then
            TPM:ScrollEconomyFocusDropdown(delta)
        end
    end)

    self.statisticsEconomyFocusSelector = selector
    self.statisticsEconomyFocusButton = selected
    self.statisticsEconomyFocusArrow = arrow

    -- Real top-level popup: this fixes ESO hit-testing where a visible child
    -- control can still sit behind the Statistics journal for mouse input.
    local dropdown = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME.."EconomyFocusDropdown")
    dropdown:SetDimensions(260, 260)
    dropdown:SetAnchor(TOPRIGHT, selector, BOTTOMRIGHT, 0, 3)
    dropdown:SetMouseEnabled(true)
    dropdown:SetClampedToScreen(true)
    dropdown:SetHidden(true)
    dropdown:SetDrawTier(DT_HIGH)
    dropdown:SetDrawLayer(DL_OVERLAY)
    if dropdown.SetDrawLevel then dropdown:SetDrawLevel(20000) end
    dropdown:SetHandler("OnMouseWheel", function(_, delta) TPM:ScrollEconomyFocusDropdown(delta) end)

    local dropBg = WINDOW_MANAGER:CreateControl(nil, dropdown, CT_BACKDROP)
    dropBg:SetAnchorFill(dropdown)
    dropBg:SetCenterColor(0.010,0.009,0.007,0.998)
    dropBg:SetEdgeColor(0.88,0.69,0.19,1)
    dropBg:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds",128,16,2)
    dropBg:SetInsets(2,2,-2,-2)
    dropBg:SetMouseEnabled(false)

    self.economyFocusDropdownRows = {}
    for rowIndex=1,9 do
        local row = WINDOW_MANAGER:CreateControl(ADDON_NAME.."EconomyFocusRow"..tostring(rowIndex), dropdown, CT_BUTTON)
        row:SetDimensions(224,25)
        row:SetAnchor(TOPLEFT, dropdown, TOPLEFT, 7, 6 + ((rowIndex-1)*27))
        row:SetMouseEnabled(true)
        row:SetClickSound(SOUNDS.DEFAULT_CLICK)

        local rowBack = WINDOW_MANAGER:CreateControl(nil, row, CT_BACKDROP)
        rowBack:SetAnchorFill(row)
        rowBack:SetCenterColor(0.018,0.016,0.012,0.94)
        rowBack:SetEdgeColor(0.18,0.15,0.09,0.75)
        rowBack:SetEdgeTexture(nil,1,1,1)
        rowBack:SetMouseEnabled(false)

        local rowText = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
        rowText:SetDimensions(204,25)
        rowText:SetAnchor(LEFT, row, LEFT, 8, 0)
        rowText:SetFont("$(MEDIUM_FONT)|13")
        rowText:SetColor(0.86,0.82,0.72,1)
        rowText:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        rowText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        rowText:SetMouseEnabled(false)

        row.rowBack = rowBack
        row.rowText = rowText

        row:SetHandler("OnMouseEnter", function(btn)
            if TPM:IsStatisticsDarkDesign() then
                if btn.rowBack then btn.rowBack:SetCenterColor(0,0,0,.48); btn.rowBack:SetEdgeColor(1,1,1,.42) end
                if btn.rowText then btn.rowText:SetColor(1,1,1,1) end
            else
                if btn.rowBack then btn.rowBack:SetCenterColor(0.095,0.070,0.022,0.98); btn.rowBack:SetEdgeColor(0.88,0.67,0.18,0.95) end
                if btn.rowText then btn.rowText:SetColor(1,0.88,0.38,1) end
            end
        end)
        row:SetHandler("OnMouseExit", function(btn)
            local selectedId = tonumber(TPM.saved and TPM.saved.economyDetailFocusZoneId) or 0
            local selected = btn.zoneId ~= nil and tonumber(btn.zoneId) == selectedId
            if TPM:IsStatisticsDarkDesign() then
                if btn.rowBack then btn.rowBack:SetCenterColor(0,0,0,selected and .44 or .24); btn.rowBack:SetEdgeColor(1,1,1,selected and .40 or .18) end
                if btn.rowText then btn.rowText:SetColor(1,1,1,1) end
            else
                if btn.rowBack then
                    if selected then
                        btn.rowBack:SetCenterColor(0.080,0.060,0.020,0.98)
                        btn.rowBack:SetEdgeColor(0.92,0.72,0.20,0.95)
                    else
                        btn.rowBack:SetCenterColor(0.018,0.016,0.012,0.94)
                        btn.rowBack:SetEdgeColor(0.18,0.15,0.09,0.75)
                    end
                end
                if btn.rowText then btn.rowText:SetColor(selected and 1.00 or 0.86, selected and 0.84 or 0.82, selected and 0.30 or 0.72, 1) end
            end
        end)
        row:SetHandler("OnMouseUp", function(btn, button, upInside)
            if upInside and button == MOUSE_BUTTON_INDEX_LEFT and btn.zoneId ~= nil then
                TPM:SetEconomyDetailZone(btn.zoneId)
            end
        end)
        row:SetHandler("OnClicked", function(btn)
            if btn.zoneId ~= nil then
                TPM:SetEconomyDetailZone(btn.zoneId)
            end
        end)

        self.economyFocusDropdownRows[rowIndex] = row
    end

    -- Visible scroll rail + thumb.
    local scrollRail = WINDOW_MANAGER:CreateControl(nil, dropdown, CT_BACKDROP)
    scrollRail:SetDimensions(10, 238)
    scrollRail:SetAnchor(TOPRIGHT, dropdown, TOPRIGHT, -8, 8)
    scrollRail:SetCenterColor(0.035,0.030,0.020,0.95)
    scrollRail:SetEdgeColor(0.30,0.24,0.10,0.85)
    scrollRail:SetEdgeTexture(nil,1,1,1)
    scrollRail:SetMouseEnabled(false)

    local scrollThumb = WINDOW_MANAGER:CreateControl(nil, scrollRail, CT_BACKDROP)
    scrollThumb:SetDimensions(8, 48)
    scrollThumb:SetAnchor(TOP, scrollRail, TOP, 0, 1)
    scrollThumb:SetCenterColor(0.72,0.56,0.17,0.95)
    scrollThumb:SetEdgeColor(0.95,0.77,0.25,1)
    scrollThumb:SetEdgeTexture(nil,1,1,1)
    scrollThumb:SetMouseEnabled(false)

    local up = WINDOW_MANAGER:CreateControl(nil, dropdown, CT_LABEL)
    up:SetDimensions(16,16)
    up:SetAnchor(TOPRIGHT, dropdown, TOPRIGHT, -5, -1)
    up:SetFont("$(BOLD_FONT)|12")
    up:SetText("▲")
    up:SetColor(0.82,0.67,0.22,1)
    up:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    up:SetMouseEnabled(true)
    up:SetHandler("OnMouseUp", function(_,button,inside)
        if inside and button==MOUSE_BUTTON_INDEX_LEFT then TPM:ScrollEconomyFocusDropdown(1) end
    end)

    local down = WINDOW_MANAGER:CreateControl(nil, dropdown, CT_LABEL)
    down:SetDimensions(16,16)
    down:SetAnchor(BOTTOMRIGHT, dropdown, BOTTOMRIGHT, -5, 1)
    down:SetFont("$(BOLD_FONT)|12")
    down:SetText("▼")
    down:SetColor(0.82,0.67,0.22,1)
    down:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    down:SetMouseEnabled(true)
    down:SetHandler("OnMouseUp", function(_,button,inside)
        if inside and button==MOUSE_BUTTON_INDEX_LEFT then TPM:ScrollEconomyFocusDropdown(-1) end
    end)

    self.economyFocusDropdown = dropdown
    self.economyFocusDropdownOffset = 1
    self.economyFocusScrollRail = scrollRail
    self.economyFocusScrollThumb = scrollThumb


    self.statisticsEconomyCards = {}
    self.statisticsEconomyCards[1] = self:CreateEconomyGoldCard(page, ADDON_NAME .. "EconomyCardGold", 20, 48, 914)

    -- Layout mirrors the clean journal mock-up: six compact cards on the left,
    -- five on the right, with Gold promoted to a full-width summary card.
    local layout = {
        [2]  = { 0, 1 }, -- Crowns
        [3]  = { 0, 0 }, -- Crown Gems
        [4]  = { 0, 2 }, -- Trade Bars
        [5]  = { 0, 5 }, -- Seals
        [6]  = { 1, 0 }, -- Alliance Points
        [7]  = { 0, 3 }, -- Tel Var
        [8]  = { 1, 1 }, -- Writ Vouchers
        [9]  = { 0, 4 }, -- Transmute Crystals
        [10] = { 1, 2 }, -- Undaunted Keys
        [11] = { 1, 3 }, -- Archival Fortunes
        [12] = { 1, 4 }, -- Tome Points
    }
    local cardWidth = 448
    local startY = 190
    local rowHeight = 64
    for index = 2, 12 do
        local placement = layout[index]
        local column = placement[1]
        local row = placement[2]
        local x = 20 + column * 466
        local y = startY + row * rowHeight
        self.statisticsEconomyCards[index] = self:CreateEconomyCurrencyCard(page, ADDON_NAME .. "EconomyCard" .. tostring(index), x, y, cardWidth)
    end

    local note = WINDOW_MANAGER:CreateControl(nil, page, CT_BACKDROP)
    note:SetDimensions(856, 52)
    note:SetAnchor(TOP, page, TOP, 0, 582)
    note:SetCenterColor(0.026, 0.024, 0.021, 0.97)
    note:SetEdgeColor(0.30, 0.25, 0.15, 0.62)
    note:SetEdgeTexture(nil, 1, 1, 1)
    note:SetMouseEnabled(false)

    local infoBack = WINDOW_MANAGER:CreateControl(nil, note, CT_BACKDROP)
    infoBack:SetDimensions(34, 34)
    infoBack:SetAnchor(LEFT, note, LEFT, 12, 0)
    infoBack:SetCenterColor(0.055, 0.047, 0.032, 1)
    infoBack:SetEdgeColor(0.66, 0.52, 0.22, 0.82)
    infoBack:SetEdgeTexture(nil, 1, 1, 1)

    local info = WINDOW_MANAGER:CreateControl(nil, infoBack, CT_LABEL)
    info:SetDimensions(32, 32)
    info:SetAnchor(CENTER, infoBack, CENTER, 0, 0)
    info:SetFont("$(BOLD_FONT)|20")
    info:SetColor(0.86, 0.72, 0.38, 1)
    info:SetText("i")
    info:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    info:SetVerticalAlignment(TEXT_ALIGN_CENTER)

    local noteTitle = WINDOW_MANAGER:CreateControl(nil, note, CT_LABEL)
    noteTitle:SetDimensions(790, 20)
    noteTitle:SetAnchor(TOPLEFT, note, TOPLEFT, 58, 4)
    noteTitle:SetFont("$(BOLD_FONT)|17")
    noteTitle:SetColor(0.90, 0.77, 0.34, 1)
    noteTitle:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    noteTitle:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.statisticsEconomyTrackingTitle = noteTitle

    local noteText = WINDOW_MANAGER:CreateControl(nil, note, CT_LABEL)
    noteText:SetDimensions(790, 27)
    noteText:SetAnchor(TOPLEFT, note, TOPLEFT, 58, 23)
    noteText:SetFont("$(MEDIUM_FONT)|13")
    noteText:SetColor(0.70, 0.68, 0.62, 1)
    noteText:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    noteText:SetVerticalAlignment(TEXT_ALIGN_TOP)
    self.statisticsEconomyTrackingText = noteText
end

function TPM:RefreshEconomyStatisticsPage()
    if self.economyDetailWindow and not self.economyDetailWindow:IsHidden() then self:RefreshEconomyDetailWindow() end
    if not self.statisticsEconomyPage or self.statisticsEconomyPage:IsHidden() then return end
    local stats = self:GetEconomyStats()
    local definitions = self:GetEconomyCurrencyDefinitions()

    self.statisticsEconomyPageTitle:SetText(self:L("STAT_ECONOMY_PAGE_TITLE"))
    self.statisticsEconomyPageSubtitle:SetText(self:L("STAT_ECONOMY_PAGE_SUBTITLE_CHARACTER", stats.characterName or self:L("STAT_PLAYER_UNKNOWN")))
    self.statisticsEconomyTrackingTitle:SetText(self:L("STAT_ECONOMY_TRACKING"))
    self.statisticsEconomyTrackingText:SetText(self:L("STAT_ECONOMY_TRACKING_NOTE", stats.trackingVersion or "2.0.15"))

    local focusZoneId = tonumber(self.saved and self.saved.economyDetailFocusZoneId) or 0
    local zoneAggregate = self:GetEconomyDetailAggregate(focusZoneId)
    if self.statisticsEconomyFocusButton then
        self.statisticsEconomyFocusButton:SetText(self:GetEconomyZoneName(focusZoneId) .. "  ▼")
    end


    for index, card in ipairs(self.statisticsEconomyCards or {}) do
        local definition = definitions[index]
        card.control:SetHidden(definition == nil)
        if definition then
            local entry = stats.currencies[definition.key] or { received = 0, spent = 0 }
            local amounts = self:GetEconomyCurrentAmounts(definition)
            local visual = self:GetEconomyCardVisual(definition)

            if card.isGoldCard then
                card.title:SetText(self:GetEconomyCurrencyName(definition))
                if visual.texture and visual.texture ~= "" then
                    card.icon:SetTexture(visual.texture)
                    card.icon:SetColor(1, 1, 1, 1)
                end

                card.cash.label:SetText(self:L("STAT_ECONOMY_LABEL_CASH"))
                card.bank.label:SetText(self:L("STAT_ECONOMY_LABEL_BANK"))
                card.total.label:SetText(self:L("STAT_ECONOMY_LABEL_TOTAL"))
                card.cash.value:SetText(FormatNumber(amounts.character))
                card.bank.value:SetText(FormatNumber(amounts.bank))
                card.total.value:SetText(FormatNumber(amounts.total))

                card.received.label:SetText(self:L("STAT_ECONOMY_LABEL_RECEIVED"))
                card.spent.label:SetText(self:L("STAT_ECONOMY_LABEL_SPENT"))
                card.fence.label:SetText(self:L("STAT_ECONOMY_FENCE_SHORT"))
                card.stolen.label:SetText(self:L("STAT_ECONOMY_STOLEN_SHORT"))
                if card.bounty then card.bounty.label:SetText(self:L("STAT_ECONOMY_BOUNTY_PAID_SHORT")) end
                card.received.value:SetText("+" .. FormatNumber((focusZoneId == 0 and entry.received or zoneAggregate.received) or 0))
                card.spent.value:SetText("-" .. FormatNumber((focusZoneId == 0 and entry.spent or zoneAggregate.spent) or 0))
                card.fence.value:SetText("+" .. FormatNumber((focusZoneId == 0 and entry.fenceSales or zoneAggregate.fenceSales) or 0))
                card.stolen.value:SetText("+" .. FormatNumber((focusZoneId == 0 and entry.stolenGold or zoneAggregate.stolenGold) or 0))
                if card.bounty then card.bounty.value:SetText("-" .. FormatNumber((focusZoneId == 0 and entry.bountyPaid or zoneAggregate.bountyPaid) or 0)) end
            else
                local accent = visual.accent or { 0.86, 0.66, 0.18 }
                local accentHex = RGBToHex(accent[1], accent[2], accent[3])
                local bulletHex = "786846"

                card.control:SetCenterColor(
                    0.020 + accent[1] * 0.014,
                    0.020 + accent[2] * 0.012,
                    0.018 + accent[3] * 0.010,
                    0.992
                )
                card.control:SetEdgeColor(accent[1], accent[2], accent[3], 0.48)
                card.accent:SetCenterColor(accent[1], accent[2], accent[3], 0.92)
                card.iconBack:SetCenterColor(
                    0.025 + accent[1] * 0.10,
                    0.024 + accent[2] * 0.09,
                    0.022 + accent[3] * 0.08,
                    0.98
                )
                card.iconBack:SetEdgeColor(accent[1], accent[2], accent[3], 0.70)

                if visual.texture and visual.texture ~= "" then
                    card.icon:SetTexture(visual.texture)
                    card.icon:SetColor(1, 1, 1, 1)
                    card.icon:SetHidden(false)
                else
                    card.icon:SetHidden(true)
                end

                card.title:SetText(self:GetEconomyCurrencyName(definition))
                card.title:SetColor(
                    math.min(1, 0.52 + accent[1] * 0.52),
                    math.min(1, 0.48 + accent[2] * 0.52),
                    math.min(1, 0.44 + accent[3] * 0.50),
                    1
                )

                if self:IsEconomyCurrencyBankable(definition) then
                    local primaryLabel = self:L("STAT_ECONOMY_LABEL_CHARACTER")
                    card.line:SetText(string.format("|c%s%s: %s|r   |c%s•|r   |c%s%s: %s|r   |c%s•|r   |c%s%s: %s|r",
                        accentHex, primaryLabel, FormatNumber(amounts.character),
                        bulletHex,
                        accentHex, self:L("STAT_ECONOMY_LABEL_BANK"), FormatNumber(amounts.bank),
                        bulletHex,
                        accentHex, self:L("STAT_ECONOMY_LABEL_TOTAL"), FormatNumber(amounts.total)))
                else
                    local primaryLocation = self:GetEconomyPrimaryLocation(definition)
                    local primaryLabel = self:L("STAT_ECONOMY_LABEL_CURRENT")
                    if type(_G.CURRENCY_LOCATION_ACCOUNT) == "number" and primaryLocation == _G.CURRENCY_LOCATION_ACCOUNT then
                        primaryLabel = self:L("STAT_ECONOMY_LABEL_ACCOUNT")
                    end
                    card.line:SetText(string.format("|c%s%s: %s|r", accentHex, primaryLabel, FormatNumber(amounts.current)))
                end

                card.detail:SetText(string.format("|c8FD0A5%s: +%s|r   |c%s•|r   |cD9B48A%s: -%s|r",
                    self:L("STAT_ECONOMY_LABEL_RECEIVED"),
                    FormatNumber(entry.received or 0),
                    bulletHex,
                    self:L("STAT_ECONOMY_LABEL_SPENT"),
                    FormatNumber(entry.spent or 0)))
            end
        end
    end
    self:EnforceStatisticsDarkModeAfterRefresh()
end

-- 2.6.34 Community: Alliance statistics page -----------------------------------
function TPM:GetAllianceStatisticsData()
    local result = {
        DC = { completed = 0, total = 0, zonesCompleted = 0, zonesTotal = 0 },
        AD = { completed = 0, total = 0, zonesCompleted = 0, zonesTotal = 0 },
        EP = { completed = 0, total = 0, zonesCompleted = 0, zonesTotal = 0 },
    }
    local stats = self:GetStatisticsData(false, 0)
    for _, zone in ipairs((stats and stats.zones) or {}) do
        local group = self:GetAllianceTerritoryGroup(zone.zoneId)
        local row = group and result[group] or nil
        if row then
            row.completed = row.completed + (tonumber(zone.completed) or 0)
            row.total = row.total + (tonumber(zone.total) or 0)
            row.zonesTotal = row.zonesTotal + 1
            if (tonumber(zone.percent) or 0) >= 100 then row.zonesCompleted = row.zonesCompleted + 1 end
        end
    end
    for _, row in pairs(result) do
        row.percent = row.total > 0 and Clamp(Round((row.completed / row.total) * 100), 0, 100) or 0
        if row.completed < row.total and row.percent >= 100 then row.percent = 99 end
    end
    return result
end

function TPM:GetPlayerAllianceDisplay()
    local allianceId = 0
    if type(_G.GetUnitAlliance) == "function" then
        allianceId = tonumber(GetUnitAlliance("player")) or 0
    end
    local name = ""
    if allianceId > 0 and type(_G.GetAllianceName) == "function" then
        name = tostring(GetAllianceName(allianceId) or "")
    end
    if name == "" then
        name = self:L("STAT_ALLIANCE_UNKNOWN")
    else
        -- ESO localized names can carry grammar metadata (for example "^n").
        -- Those suffixes are useful to the formatter but should never be visible in TPM.
        name = name:gsub("%^%a+", "")
        local formatted = zo_strformat("<<C:1>>", name)
        if type(formatted) == "string" and formatted ~= "" then name = formatted end
    end
    local group = nil
    if allianceId == _G.ALLIANCE_DAGGERFALL_COVENANT then group = "DC"
    elseif allianceId == _G.ALLIANCE_ALDMERI_DOMINION then group = "AD"
    elseif allianceId == _G.ALLIANCE_EBONHEART_PACT then group = "EP" end
    return allianceId, name, group
end


function TPM:GetAllianceCategoryStatisticsData(group)
    -- Some ESO clients/API revisions do not expose every completion-type
    -- constant. Never use a nil completion type as a table key.
    local defs = {
        { key = "CAT_QUESTS", completionType = _G.ZONE_COMPLETION_TYPE_PRIORITY_QUESTS },
        { key = "CAT_SIDE_QUESTS", completionType = _G.ZONE_COMPLETION_TYPE_SIDE_QUESTS },
        { key = "CAT_SKYSHARDS", completionType = _G.ZONE_COMPLETION_TYPE_SKYSHARDS },
        { key = "CAT_WAYSHRINES", completionType = _G.ZONE_COMPLETION_TYPE_WAYSHRINES },
        -- CAT_DELVES (Explorações) intentionally omitted from Alliance details
        { key = "CAT_PUBLIC_DUNGEONS", completionType = _G.ZONE_COMPLETION_TYPE_PUBLIC_DUNGEONS },
        { key = "CAT_WORLD_BOSSES", completionType = _G.ZONE_COMPLETION_TYPE_GROUP_BOSSES },
        { key = "CAT_WORLD_EVENTS", completionType = _G.ZONE_COMPLETION_TYPE_WORLD_EVENTS },
    }

    local totals = {}
    for _, def in ipairs(defs) do
        if def.completionType ~= nil then
            totals[def.completionType] = { completed = 0, total = 0 }
        end
    end

    local progressZoneIds = self:GetAllProgressZoneIds() or {}
    for zoneId in pairs(progressZoneIds) do
        if self:GetAllianceTerritoryGroup(zoneId) == group then
            local breakdown = self:GetCompletionBreakdown(zoneId)
            for _, row in ipairs(breakdown or {}) do
                local completionType = row and row.completionType
                local dst = completionType ~= nil and totals[completionType] or nil
                if dst then
                    dst.completed = dst.completed + (tonumber(row.completed) or 0)
                    dst.total = dst.total + (tonumber(row.total) or 0)
                end
            end
        end
    end

    local rows = {}
    for _, def in ipairs(defs) do
        if def.completionType ~= nil then
            local t = totals[def.completionType] or { completed = 0, total = 0 }
            local percent = t.total > 0 and Clamp(Round((t.completed / t.total) * 100), 0, 100) or 0
            rows[#rows + 1] = {
                label = self:L(def.key),
                completed = t.completed,
                total = t.total,
                percent = percent,
            }
        end
    end
    return rows
end


function TPM:GetAllianceZoneProgressData(group)
    local zoneIdsByGroup = {
        DC = {534,535,3,19,20,104,92},
        AD = {537,381,383,108,58,382},
        EP = {280,281,41,57,117,101,103},
    }
    local result = {}
    for _, zoneId in ipairs(zoneIdsByGroup[group] or {}) do
        local _, completed, total, percent = self:GetResolvedCompletion(zoneId)
        local name = (type(SafeZoneName) == "function" and SafeZoneName(zoneId)) or self:GetEconomyZoneName(zoneId)
        completed = tonumber(completed) or 0
        total = tonumber(total) or 0
        percent = Clamp(tonumber(percent) or 0, 0, 100)
        result[#result+1] = {
            zoneId = zoneId,
            name = (name and name ~= "") and name or tostring(zoneId),
            completed = completed,
            total = total,
            remaining = math.max(0, total - completed),
            percent = percent,
            complete = percent >= 100,
        }
    end

    -- Community planner order: unfinished zones first, closest to 100% first.
    -- Fully completed zones move to the bottom so the next useful target is
    -- always immediately visible.
    table.sort(result, function(a,b)
        if a.complete ~= b.complete then return not a.complete end
        if a.percent ~= b.percent then return a.percent > b.percent end
        if a.remaining ~= b.remaining then return a.remaining < b.remaining end
        return tostring(a.name) < tostring(b.name)
    end)
    return result
end

function TPM:GetAlliancePlannerRecommendations(group)
    local zones = self:GetAllianceZoneProgressData(group)
    local nextTarget, biggestGap = nil, nil
    for _, zone in ipairs(zones) do
        if not zone.complete then
            if not nextTarget then nextTarget = zone end
            if not biggestGap or zone.percent < biggestGap.percent
                or (zone.percent == biggestGap.percent and zone.remaining > biggestGap.remaining) then
                biggestGap = zone
            end
        end
    end
    return nextTarget, biggestGap, zones
end

function TPM:OpenAllianceZoneInProgress(zoneId)
    zoneId = tonumber(zoneId) or 0
    if zoneId <= 0 or not self.saved then return end
    self.saved.statisticsFocusZoneId = zoneId
    self.saved.statisticsProgressSubPage = 1
    -- A zone click from the Alliance planner promises to open the normal zone
    -- completion view. Do not leave Collections/Achievements selected either.
    self.saved.statisticsCompletionPage = 1
    self.statisticsScrollOffset = 0
    self:SetStatisticsPage("progress")
    self:RefreshStatisticsFocusSelector()
    self:RefreshStatisticsWindow()
end


function TPM:GetAlliancePlannerColor(group)
    if group == "DC" then return 0.20, 0.48, 1.00 end
    if group == "AD" then return 1.00, 0.76, 0.12 end
    if group == "EP" then return 1.00, 0.20, 0.20 end
    return 0.92, 0.90, 0.84
end

-- 2.6.74: Resolve the game's own Tamriel overview without changing the
-- player's currently viewed world map. Map-list index 1 is Tamriel in ESO's
-- map list; the fallback keeps this future-proof if that ordering changes.

function TPM:GetAlliancePlannerTamrielMapId()
    if self.alliancePlannerTamrielMapId and self.alliancePlannerTamrielMapId > 0 then
        return self.alliancePlannerTamrielMapId
    end

    -- Do not assume map-list index 1 is Tamriel. The map list can change when
    -- ZOS adds root/world maps. Pick the WORLD map with the largest normalized
    -- footprint instead, without changing the player's active map.
    local bestMapId, bestArea = nil, -1
    local count = tonumber(GetNumMaps()) or 0
    for mapIndex = 1, math.max(0, count) do
        local _, mapType = GetMapInfoByIndex(mapIndex)
        if mapType == MAPTYPE_WORLD then
            local candidateId = tonumber(GetMapIdByIndex(mapIndex))
            if candidateId and candidateId > 0 then
                local _, _, w, h = GetUniversallyNormalizedMapInfo(candidateId)
                local area = math.max(0, tonumber(w) or 0) * math.max(0, tonumber(h) or 0)
                if area > bestArea then
                    bestArea = area
                    bestMapId = candidateId
                end
            end
        end
    end

    self.alliancePlannerTamrielMapId = bestMapId or 0
    return self.alliancePlannerTamrielMapId
end


function TPM:EnsureAlliancePlannerTamrielTiles()
    local frame = self.statisticsAllianceMapFrame
    if not frame then return false end

    local mapId = self:GetAlliancePlannerTamrielMapId()
    if not mapId or mapId <= 0 then return false end

    local numX, numY = GetMapNumTilesForMapId(mapId)
    numX, numY = tonumber(numX) or 0, tonumber(numY) or 0
    if numX <= 0 or numY <= 0 then return false end

    local required = numX * numY
    self.statisticsAllianceMapTiles = self.statisticsAllianceMapTiles or {}

    -- Texture filenames do not change while panning/zooming. Previously they
    -- were reassigned on every frame during dragging.
    local sourceChanged =
        self.statisticsAllianceMapTileMapId ~= mapId
        or self.statisticsAllianceMapTileColumns ~= numX
        or self.statisticsAllianceMapTileRows ~= numY

    for i = 1, required do
        local tile = self.statisticsAllianceMapTiles[i]
        if not tile then
            tile = WINDOW_MANAGER:CreateControl(nil, frame, CT_TEXTURE)
            tile:SetMouseEnabled(false)
            if tile.SetDrawLevel then tile:SetDrawLevel(5) end
            self.statisticsAllianceMapTiles[i] = tile
            sourceChanged = true
        end

        if sourceChanged then
            local texturePath = GetMapTileTextureForMapId(mapId, i)
            if type(texturePath) == "string" and texturePath ~= "" then
                tile:SetTexture(texturePath)
                tile:SetAlpha(1)
                tile.TPMHasValidSource = true
            else
                tile.TPMHasValidSource = false
                tile:SetHidden(true)
            end
        end
    end

    for i = required + 1, #self.statisticsAllianceMapTiles do
        self.statisticsAllianceMapTiles[i]:SetHidden(true)
    end

    self.statisticsAllianceMapTileColumns = numX
    self.statisticsAllianceMapTileRows = numY
    self.statisticsAllianceMapTileMapId = mapId
    return true
end

-- Based on Trobo's verified scaling correction on TPM's ESOUI page.
function TPM:GetAlliancePlannerMapLocalDimensions()
    local frame = self.statisticsAllianceMapFrame
    if not frame then return 1, 1 end

    local frameW, frameH = frame:GetDimensions()
    frameW, frameH = tonumber(frameW) or 1, tonumber(frameH) or 1

    local windowScale = 1
    if self.statisticsWindow and type(self.statisticsWindow.GetScale) == "function" then
        windowScale = tonumber(self.statisticsWindow:GetScale()) or 1
    end
    if windowScale <= 0 then windowScale = 1 end

    return math.max(1, frameW / windowScale), math.max(1, frameH / windowScale)
end

function TPM:RefreshAlliancePlannerTamrielTiles(viewLeft, viewTop, span)
    if not self:EnsureAlliancePlannerTamrielTiles() then return false end

    local frame = self.statisticsAllianceMapFrame
    local tiles = self.statisticsAllianceMapTiles or {}
    local numX = tonumber(self.statisticsAllianceMapTileColumns) or 0
    local numY = tonumber(self.statisticsAllianceMapTileRows) or 0
    local frameW, frameH = self:GetAlliancePlannerMapLocalDimensions()

    local viewRight, viewBottom = viewLeft + span, viewTop + span
    for row = 1, numY do
        for col = 1, numX do
            local index = (row - 1) * numX + col
            local tile = tiles[index]
            if tile then
                local tileL, tileR = (col - 1) / numX, col / numX
                local tileT, tileB = (row - 1) / numY, row / numY
                local l, r = math.max(viewLeft, tileL), math.min(viewRight, tileR)
                local t, b = math.max(viewTop, tileT), math.min(viewBottom, tileB)

                if tile.TPMHasValidSource ~= false and r > l and b > t then
                    local x = ((l - viewLeft) / span) * frameW
                    local y = ((t - viewTop) / span) * frameH
                    local w = ((r - l) / span) * frameW
                    local h = ((b - t) / span) * frameH
                    local u1 = (l - tileL) / (tileR - tileL)
                    local u2 = (r - tileL) / (tileR - tileL)
                    local v1 = (t - tileT) / (tileB - tileT)
                    local v2 = (b - tileT) / (tileB - tileT)

                    tile:ClearAnchors()
                    tile:SetAnchor(TOPLEFT, frame, TOPLEFT, x, y)
                    tile:SetDimensions(math.max(1, w + 0.5), math.max(1, h + 0.5))
                    tile:SetTextureCoords(u1, u2, v1, v2)
                    tile:SetHidden(false)
                else
                    tile:SetHidden(true)
                end
            end
        end
    end
    return true
end


function TPM:GetAlliancePlannerZoneNormalizedPosition(zoneId)
    local tamrielMapId = self:GetAlliancePlannerTamrielMapId()
    if not tamrielMapId or tamrielMapId <= 0 then return nil end

    if self.alliancePlannerZonePositionCacheMapId ~= tamrielMapId then
        self.alliancePlannerZonePositionCache = {}
        self.alliancePlannerZonePositionCacheMapId = tamrielMapId
    end
    local cache = self.alliancePlannerZonePositionCache
    local position = cache and cache[zoneId]
    if position then return position.x, position.y end

    local zoneMapId = tonumber(GetMapIdByZoneId(zoneId))
    if not zoneMapId or zoneMapId <= 0 then return nil end

    local tx, ty, tw, th = GetUniversallyNormalizedMapInfo(tamrielMapId)
    local zx, zy, zw, zh = GetUniversallyNormalizedMapInfo(zoneMapId)

    tx, ty, tw, th = tonumber(tx), tonumber(ty), tonumber(tw), tonumber(th)
    zx, zy, zw, zh = tonumber(zx), tonumber(zy), tonumber(zw), tonumber(zh)
    if not tx or not ty or not tw or not th or not zx or not zy or not zw or not zh
        or tw <= 0 or th <= 0 then
        return nil
    end

    local x = ((zx + zw * 0.5) - tx) / tw
    local y = ((zy + zh * 0.5) - ty) / th
    if x < -0.05 or x > 1.05 or y < -0.05 or y > 1.05 then return nil end
    self.alliancePlannerZonePositionCache = cache or {}
    self.alliancePlannerZonePositionCache[zoneId] = { x = x, y = y }
    return x, y
end

function TPM:GetAlliancePlannerMarkerColor(zoneId)
    if tonumber(zoneId) == 181 then return 0.30, 0.78, 0.26, "CYRODIIL" end
    local group = self:GetAllianceTerritoryGroup(zoneId)
    if group == "DC" then return 0.20, 0.48, 1.00, group end
    if group == "AD" then return 1.00, 0.76, 0.12, group end
    if group == "EP" then return 1.00, 0.20, 0.20, group end
    return 0.94, 0.93, 0.88, "NEUTRAL"
end

function TPM:EnsureAlliancePlannerZoneMarkers()
    local frame = self.statisticsAllianceMapFrame
    if not frame then return end
    self.statisticsAllianceMapMarkers = self.statisticsAllianceMapMarkers or {}

    local ids = {534,535,3,19,20,104,92,537,381,383,108,58,382,280,281,41,57,117,101,103,181,888,347}
    for _, zoneId in ipairs(ids) do
        if not self.statisticsAllianceMapMarkers[zoneId] then
            local label = WINDOW_MANAGER:CreateControl(nil, frame, CT_LABEL)
            label:SetDimensions(88,48)
            label:SetFont("$(BOLD_FONT)|16")
            label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            label:SetMouseEnabled(true)
            label:SetHandler("OnMouseDown", function(control, button)
                if button == MOUSE_BUTTON_INDEX_LEFT then
                    control.TPMAlliancePanStarted = TPM:BeginAlliancePlannerMapPan() == true
                end
            end)
            label:SetHandler("OnMouseUp", function(control, button, inside)
                if button ~= MOUSE_BUTTON_INDEX_LEFT then return end
                local didMove = false
                if control.TPMAlliancePanStarted then
                    didMove = TPM:EndAlliancePlannerMapPan() == true
                end
                control.TPMAlliancePanStarted = false

                -- Click still opens the zone. Drag only moves the Alliance map.
                if inside and not didMove and control.zoneId then
                    TPM:OpenAllianceZoneInProgress(control.zoneId)
                end
            end)
            label:SetHandler("OnMouseWheel", function(_, delta)
                if delta ~= 0 then TPM:ZoomAlliancePlannerMapAtMouse(delta > 0 and 0.25 or -0.25) end
            end)
            label:SetHandler("OnMouseEnter", function(control)
                if not control.zoneId then return end
                InitializeTooltip(InformationTooltip, control, BOTTOM, 0, -4, TOP)
                InformationTooltip:AddLine(SafeZoneName(control.zoneId), "ZoFontGameBold")
                if control.percent then
                    InformationTooltip:AddLine(string.format("%d%%", control.percent), "ZoFontGame")
                end
            end)
            label:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
            if label.SetDrawLevel then label:SetDrawLevel(30) end
            label.zoneId = zoneId
            self.statisticsAllianceMapMarkers[zoneId] = label
        end
    end
end


function TPM:RefreshAlliancePlannerZoneMarkers(viewLeft, viewTop, span, reuseValues)
    self:EnsureAlliancePlannerZoneMarkers()
    local frame = self.statisticsAllianceMapFrame
    if not frame then return end
    local frameW, frameH = self:GetAlliancePlannerMapLocalDimensions()

    for zoneId, label in pairs(self.statisticsAllianceMapMarkers or {}) do
        local x, y = self:GetAlliancePlannerZoneNormalizedPosition(zoneId)

        local available, percent
        if reuseValues and label.percent ~= nil and label.available ~= nil then
            percent = label.percent
            available = label.available
        else
            local _, _, resolvedAvailable, resolvedPercent = self:GetResolvedCompletion(zoneId)
            available = tonumber(resolvedAvailable) or 0
            percent = tonumber(resolvedPercent) or 0
            label.available = available
            label.percent = percent
        end

        if x and y and available > 0 and x >= viewLeft and x <= viewLeft + span
            and y >= viewTop and y <= viewTop + span then
            local screenX = ((x - viewLeft) / span) * frameW
            local screenY = ((y - viewTop) / span) * frameH
            local r,g,b = self:GetAlliancePlannerMarkerColor(zoneId)
            local hex = string.format("%02X%02X%02X",
                math.floor(r*255+0.5), math.floor(g*255+0.5), math.floor(b*255+0.5))

            label:SetText(string.format("|cFFF2C9%d%%|r\n|c%s●|r", percent, hex))
            label:ClearAnchors()
            label:SetAnchor(CENTER, frame, TOPLEFT, screenX, screenY)
            label:SetHidden(false)
        else
            label:SetHidden(true)
        end
    end
end

function TPM:RefreshAlliancePlannerMapView(reuseMarkerValues)
    local surface = self.statisticsAllianceMapTexture
    if not surface then return end

    -- Internal factor 1.0 = 0% additional zoom (fit). 4.5 = +350%.
    local zoom = tonumber(self.saved and self.saved.alliancePlannerMapZoom) or 1.0
    zoom = Clamp(zoom, 1.0, 4.5)
    if self.saved then self.saved.alliancePlannerMapZoom = zoom end

    local span = 1 / zoom
    local halfSpan = span * 0.5
    local centerX = tonumber(self.saved and self.saved.alliancePlannerMapCenterX) or 0.5
    local centerY = tonumber(self.saved and self.saved.alliancePlannerMapCenterY) or 0.5

    if zoom <= 1.001 then
        centerX, centerY = 0.5, 0.5
    else
        centerX = Clamp(centerX, halfSpan, 1 - halfSpan)
        centerY = Clamp(centerY, halfSpan, 1 - halfSpan)
    end

    if self.saved then
        self.saved.alliancePlannerMapCenterX = centerX
        self.saved.alliancePlannerMapCenterY = centerY
    end

    local viewLeft, viewTop = centerX - halfSpan, centerY - halfSpan
    local originalMapVisible = self:RefreshAlliancePlannerTamrielTiles(viewLeft, viewTop, span)
    if self.statisticsAllianceMapFallback then
        self.statisticsAllianceMapFallback:SetHidden(originalMapVisible == true)
    end
    self:RefreshAlliancePlannerZoneMarkers(viewLeft, viewTop, span, reuseMarkerValues == true)

    if self.statisticsAllianceMapZoomLabel then
        self.statisticsAllianceMapZoomLabel:SetText(string.format("%d%%", math.floor((zoom - 1) * 100 + 0.5)))
    end
    if self.statisticsAllianceMapDragHint then
        self.statisticsAllianceMapDragHint:SetHidden(zoom <= 1.001)
    end
end

function TPM:ZoomAlliancePlannerMapAtMouse(step)
    if not self.saved or not self.statisticsAllianceMapTexture then return end

    local surface = self.statisticsAllianceMapFrame or self.statisticsAllianceMapTexture
    local oldZoom = Clamp(tonumber(self.saved.alliancePlannerMapZoom) or 1.0, 1.0, 4.5)
    local newZoom = Clamp(oldZoom + (tonumber(step) or 0), 1.0, 4.5)
    if math.abs(newZoom - oldZoom) < 0.001 then return end

    local oldSpan, newSpan = 1 / oldZoom, 1 / newZoom
    local centerX = tonumber(self.saved.alliancePlannerMapCenterX) or 0.5
    local centerY = tonumber(self.saved.alliancePlannerMapCenterY) or 0.5

    if type(GetUIMousePosition) == "function" then
        local mouseX, mouseY = GetUIMousePosition()
        local left, top = surface:GetScreenRect()
        local width, height = surface:GetDimensions()
        width, height = math.max(1, tonumber(width) or 1), math.max(1, tonumber(height) or 1)
        local relX = Clamp(((tonumber(mouseX) or 0) - (tonumber(left) or 0)) / width, 0, 1)
        local relY = Clamp(((tonumber(mouseY) or 0) - (tonumber(top) or 0)) / height, 0, 1)
        local anchorU = (centerX - oldSpan * 0.5) + relX * oldSpan
        local anchorV = (centerY - oldSpan * 0.5) + relY * oldSpan
        centerX = anchorU - (relX - 0.5) * newSpan
        centerY = anchorV - (relY - 0.5) * newSpan
    end

    local halfSpan = newSpan * 0.5
    self.saved.alliancePlannerMapZoom = newZoom
    self.saved.alliancePlannerMapCenterX = Clamp(centerX, halfSpan, 1 - halfSpan)
    self.saved.alliancePlannerMapCenterY = Clamp(centerY, halfSpan, 1 - halfSpan)
    self:RefreshAlliancePlannerMapView()
end

function TPM:SetAlliancePlannerMapZoom(value)
    if not self.saved then return end
    local zoom = Clamp(tonumber(value) or 1.0, 1.0, 4.5)
    self.saved.alliancePlannerMapZoom = zoom
    if zoom <= 1.001 then
        self.saved.alliancePlannerMapCenterX = 0.5
        self.saved.alliancePlannerMapCenterY = 0.5
    end
    self:RefreshAlliancePlannerMapView()
end

function TPM:StepAlliancePlannerMapZoom(delta)
    self:ZoomAlliancePlannerMapAtMouse(tonumber(delta) or 0)
end


function TPM:BeginAlliancePlannerMapPan()
    self:EndAlliancePlannerMapPan()
    self.alliancePlannerMapDidMove = false
    if not self.saved or not self.statisticsAllianceMapTexture then return false end
    local zoom = tonumber(self.saved.alliancePlannerMapZoom) or 1.0
    if zoom <= 1.001 or type(GetUIMousePosition) ~= "function" then
        self.alliancePlannerMapDragging = false
        self.alliancePlannerMapDidMove = false
        return false
    end

    local mouseX, mouseY = GetUIMousePosition()
    self.alliancePlannerMapDragging = true
    self:UpdateGlobalMouseUpRegistration()
    self.alliancePlannerMapDidMove = false
    self.alliancePlannerMapDragStartX = tonumber(mouseX) or 0
    self.alliancePlannerMapDragStartY = tonumber(mouseY) or 0
    self.alliancePlannerMapDragCenterX = tonumber(self.saved.alliancePlannerMapCenterX) or 0.5
    self.alliancePlannerMapDragCenterY = tonumber(self.saved.alliancePlannerMapCenterY) or 0.5
    -- One update owner for the whole map, installed only during a drag.
    if self.statisticsAllianceMapInputLayer then
        self.statisticsAllianceMapInputLayer:SetHandler("OnUpdate", function()
            TPM:UpdateAlliancePlannerMapPan()
        end)
    end
    return true
end


function TPM:UpdateAlliancePlannerMapPan()
    if not self.alliancePlannerMapDragging or type(GetUIMousePosition) ~= "function" then return end
    local surface = self.statisticsAllianceMapTexture
    if not surface or not self.saved then self:EndAlliancePlannerMapPan(); return end

    local zoom = Clamp(tonumber(self.saved.alliancePlannerMapZoom) or 1.0, 1.0, 4.5)
    if zoom <= 1.001 then
        self:EndAlliancePlannerMapPan()
        return
    end

    -- Mouse release is finalized by EVENT_GLOBAL_MOUSE_UP, which also fires
    -- when the pointer leaves the map control. Keep OnUpdate focused on panning.
    local mouseX, mouseY = GetUIMousePosition()
    local dragSurface = self.statisticsAllianceMapFrame or surface
    local width, height = dragSurface:GetDimensions()
    width, height = math.max(1, tonumber(width) or 1), math.max(1, tonumber(height) or 1)

    local dx = (tonumber(mouseX) or 0) - (tonumber(self.alliancePlannerMapDragStartX) or 0)
    local dy = (tonumber(mouseY) or 0) - (tonumber(self.alliancePlannerMapDragStartY) or 0)

    -- A tiny mouse wobble is still treated as a normal click. This lets zone
    -- markers remain clickable while also allowing left-drag directly on them.
    if not self.alliancePlannerMapDidMove and (math.abs(dx) >= 4 or math.abs(dy) >= 4) then
        self.alliancePlannerMapDidMove = true
        ClearTooltip(InformationTooltip)
    end
    if not self.alliancePlannerMapDidMove then return end

    local span, halfSpan = 1 / zoom, (1 / zoom) * 0.5
    local centerX = (tonumber(self.alliancePlannerMapDragCenterX) or 0.5) - (dx / width) * span
    local centerY = (tonumber(self.alliancePlannerMapDragCenterY) or 0.5) - (dy / height) * span
    centerX = Clamp(centerX, halfSpan, 1 - halfSpan)
    centerY = Clamp(centerY, halfSpan, 1 - halfSpan)
    if math.abs(centerX - (tonumber(self.saved.alliancePlannerMapCenterX) or 0.5)) < 0.000001
        and math.abs(centerY - (tonumber(self.saved.alliancePlannerMapCenterY) or 0.5)) < 0.000001 then
        return
    end
    self.saved.alliancePlannerMapCenterX = centerX
    self.saved.alliancePlannerMapCenterY = centerY
    self:RefreshAlliancePlannerMapView(true)
end


function TPM:EndAlliancePlannerMapPan()
    local didMove = self.alliancePlannerMapDidMove == true
    self.alliancePlannerMapDragging = false
    self:UpdateGlobalMouseUpRegistration()
    if self.statisticsAllianceMapInputLayer then
        self.statisticsAllianceMapInputLayer:SetHandler("OnUpdate", nil)
    end
    -- Keep the result until the next mouse-down. OnUpdate can see the release
    -- before a marker's OnMouseUp; clearing it here would turn a drag into a click.
    return didMove
end

function TPM:ToggleAlliancePlannerTerritoryColors()
    if not self.saved then return end
    self.saved.alliancePlannerTerritoryColors = not (self.saved.alliancePlannerTerritoryColors == true)
    self:RefreshAllianceStatisticsPage()
end

function TPM:CreateAllianceStatisticsPage(control)
    if self.statisticsAlliancePage then return end

    local page=WINDOW_MANAGER:CreateControl(ADDON_NAME.."StatisticsAlliancePage",control,CT_BACKDROP)
    page:SetAnchor(TOPLEFT,control,TOPLEFT,14,60)
    page:SetAnchor(BOTTOMRIGHT,control,BOTTOMRIGHT,-14,-55)
    page:SetCenterColor(0.025,0.023,0.019,1.00)
    page:SetEdgeColor(0.52,0.40,0.12,0.92)
    page:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds",128,16,2)
    page:SetHidden(true)
    self.statisticsAlliancePage=page

    -- Own alliance ------------------------------------------------------------
    local own=WINDOW_MANAGER:CreateControl(nil,page,CT_BACKDROP)
    own:SetDimensions(914,76)
    own:SetAnchor(TOPLEFT,page,TOPLEFT,20,12)
    own:SetCenterColor(0.045,0.040,0.028,0.99)
    own:SetEdgeColor(0.70,0.55,0.18,0.90)
    own:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds",128,16,2)

    local ownTitle=WINDOW_MANAGER:CreateControl(nil,own,CT_LABEL)
    ownTitle:SetDimensions(220,18)
    ownTitle:SetAnchor(TOPLEFT,own,TOPLEFT,16,7)
    ownTitle:SetFont("$(BOLD_FONT)|17")
    ownTitle:SetColor(0.95,0.78,0.26,1)

    local ownName=WINDOW_MANAGER:CreateControl(nil,own,CT_LABEL)
    ownName:SetDimensions(560,24)
    ownName:SetAnchor(TOPLEFT,own,TOPLEFT,16,25)
    ownName:SetFont("$(BOLD_FONT)|24")
    ownName:SetColor(0.96,0.91,0.78,1)

    local ownPercent=WINDOW_MANAGER:CreateControl(nil,own,CT_LABEL)
    ownPercent:SetDimensions(130,34)
    ownPercent:SetAnchor(TOPRIGHT,own,TOPRIGHT,-16,13)
    ownPercent:SetFont("$(ANTIQUE_FONT)|34")
    ownPercent:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    ownPercent:SetColor(0.95,0.82,0.32,1)

    local ownBarBack=WINDOW_MANAGER:CreateControl(nil,own,CT_BACKDROP)
    ownBarBack:SetDimensions(880,8)
    ownBarBack:SetAnchor(BOTTOMLEFT,own,BOTTOMLEFT,16,-9)
    ownBarBack:SetCenterColor(0.08,0.07,0.05,1)
    ownBarBack:SetEdgeColor(0.40,0.33,0.18,0.9)
    ownBarBack:SetEdgeTexture(nil,1,1,1)

    local ownBar=WINDOW_MANAGER:CreateControl(nil,ownBarBack,CT_BACKDROP)
    ownBar:SetDimensions(1,6)
    ownBar:SetAnchor(LEFT,ownBarBack,LEFT,1,0)
    ownBar:SetEdgeColor(0,0,0,0)

    self.statisticsAllianceOwnTitle=ownTitle
    self.statisticsAllianceOwnName=ownName
    self.statisticsAllianceOwnPercent=ownPercent
    self.statisticsAllianceOwnBarBack=ownBarBack
    self.statisticsAllianceOwnBar=ownBar

    -- Alliance selector -------------------------------------------------------
    local defs={
        {key="DC",label="STAT_ALLIANCE_DC",color={0.20,0.48,1.00}},
        {key="AD",label="STAT_ALLIANCE_AD",color={1.00,0.76,0.12}},
        {key="EP",label="STAT_ALLIANCE_EP",color={1.00,0.20,0.20}},
    }
    self.statisticsAllianceCards={}
    for i,def in ipairs(defs) do
        local card=WINDOW_MANAGER:CreateControl(nil,page,CT_BACKDROP)
        card:SetDimensions(220,88)
        card:SetAnchor(TOPLEFT,page,TOPLEFT,20,100+((i-1)*96))
        card:SetCenterColor(0.018,0.018,0.017,0.99)
        card:SetEdgeColor(def.color[1],def.color[2],def.color[3],0.82)
        card:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds",128,16,2)
        card:SetMouseEnabled(true)
        card.allianceGroup=def.key
        card:SetHandler("OnMouseUp",function(c,button,inside)
            if inside and button==MOUSE_BUTTON_INDEX_LEFT then
                TPM.statisticsAllianceSelectedGroup=c.allianceGroup
                TPM:RefreshAllianceStatisticsPage()
            end
        end)

        local accent=WINDOW_MANAGER:CreateControl(nil,card,CT_BACKDROP)
        accent:SetDimensions(216,4)
        accent:SetAnchor(TOP,card,TOP,0,2)
        accent:SetCenterColor(def.color[1],def.color[2],def.color[3],0.96)
        accent:SetEdgeColor(0,0,0,0)

        local title=WINDOW_MANAGER:CreateControl(nil,card,CT_LABEL)
        title:SetDimensions(150,20)
        title:SetAnchor(TOPLEFT,card,TOPLEFT,12,9)
        title:SetFont("$(BOLD_FONT)|17")
        title:SetColor(def.color[1],def.color[2],def.color[3],1)

        local badge=WINDOW_MANAGER:CreateControl(nil,card,CT_LABEL)
        badge:SetDimensions(115,15)
        badge:SetAnchor(TOPLEFT,card,TOPLEFT,12,29)
        badge:SetFont("$(BOLD_FONT)|13")
        badge:SetColor(0.95,0.82,0.32,1)

        local percent=WINDOW_MANAGER:CreateControl(nil,card,CT_LABEL)
        percent:SetDimensions(62,28)
        percent:SetAnchor(TOPRIGHT,card,TOPRIGHT,-10,10)
        percent:SetFont("$(ANTIQUE_FONT)|30")
        percent:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        percent:SetColor(0.95,0.84,0.38,1)

        local barBack=WINDOW_MANAGER:CreateControl(nil,card,CT_BACKDROP)
        barBack:SetDimensions(194,7)
        barBack:SetAnchor(TOPLEFT,card,TOPLEFT,12,47)
        barBack:SetCenterColor(0.07,0.065,0.055,1)
        barBack:SetEdgeColor(0.32,0.29,0.22,0.9)
        barBack:SetEdgeTexture(nil,1,1,1)

        local bar=WINDOW_MANAGER:CreateControl(nil,barBack,CT_BACKDROP)
        bar:SetDimensions(1,5)
        bar:SetAnchor(LEFT,barBack,LEFT,1,0)
        bar:SetCenterColor(def.color[1],def.color[2],def.color[3],0.95)
        bar:SetEdgeColor(0,0,0,0)

        local zones=WINDOW_MANAGER:CreateControl(nil,card,CT_LABEL)
        zones:SetDimensions(94,16)
        zones:SetAnchor(TOPLEFT,card,TOPLEFT,12,61)
        zones:SetFont("$(MEDIUM_FONT)|11")
        zones:SetColor(0.83,0.79,0.69,1)

        local objectives=WINDOW_MANAGER:CreateControl(nil,card,CT_LABEL)
        objectives:SetDimensions(94,16)
        objectives:SetAnchor(TOPRIGHT,card,TOPRIGHT,-12,61)
        objectives:SetFont("$(MEDIUM_FONT)|11")
        objectives:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        objectives:SetColor(0.70,0.68,0.62,1)

        self.statisticsAllianceCards[def.key]={
            control=card,title=title,badge=badge,percent=percent,zones=zones,objectives=objectives,
            barBack=barBack,bar=bar,label=def.label,color=def.color,
        }
    end

    -- Selected alliance quick summary -----------------------------------------
    local quick=WINDOW_MANAGER:CreateControl(nil,page,CT_BACKDROP)
    quick:SetDimensions(220,120)
    quick:SetAnchor(TOPLEFT,page,TOPLEFT,20,386)
    quick:SetCenterColor(0.020,0.019,0.016,0.99)
    quick:SetEdgeColor(0.42,0.34,0.15,0.90)
    quick:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds",128,16,2)

    local quickTitle=WINDOW_MANAGER:CreateControl(nil,quick,CT_LABEL)
    quickTitle:SetDimensions(194,18)
    quickTitle:SetAnchor(TOPLEFT,quick,TOPLEFT,12,7)
    quickTitle:SetFont("$(BOLD_FONT)|16")
    quickTitle:SetColor(0.91,0.75,0.30,1)
    quickTitle:SetText(self:L("STAT_ALLIANCE_OVERVIEW"))
    self.statisticsAllianceQuickTitle=quickTitle

    local quickDone=WINDOW_MANAGER:CreateControl(nil,quick,CT_LABEL)
    quickDone:SetDimensions(194,18)
    quickDone:SetAnchor(TOPLEFT,quick,TOPLEFT,12,30)
    quickDone:SetFont("$(MEDIUM_FONT)|14")
    quickDone:SetColor(0.90,0.88,0.80,1)
    self.statisticsAllianceQuickDone=quickDone

    local quickOpen=WINDOW_MANAGER:CreateControl(nil,quick,CT_LABEL)
    quickOpen:SetDimensions(194,18)
    quickOpen:SetAnchor(TOPLEFT,quick,TOPLEFT,12,52)
    quickOpen:SetFont("$(MEDIUM_FONT)|14")
    quickOpen:SetColor(0.90,0.88,0.80,1)
    self.statisticsAllianceQuickOpen=quickOpen

    local quickNext=WINDOW_MANAGER:CreateControl(nil,quick,CT_LABEL)
    quickNext:SetDimensions(194,28)
    quickNext:SetAnchor(TOPLEFT,quick,TOPLEFT,12,76)
    quickNext:SetFont("$(BOLD_FONT)|15")
    quickNext:SetColor(0.95,0.82,0.32,1)
    quickNext:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    self.statisticsAllianceQuickNext=quickNext

    -- Large map ---------------------------------------------------------------
    local planner=WINDOW_MANAGER:CreateControl(nil,page,CT_BACKDROP)
    planner:SetDimensions(486,412)
    planner:SetAnchor(TOPLEFT,page,TOPLEFT,252,100)
    planner:SetCenterColor(0.012,0.012,0.011,0.99)
    planner:SetEdgeColor(0.25,0.22,0.16,0.90)
    planner:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds",128,16,2)
    self.statisticsAllianceMapPanel=planner

    local mapTitle=WINDOW_MANAGER:CreateControl(nil,planner,CT_LABEL)
    mapTitle:SetDimensions(448,22)
    mapTitle:SetAnchor(TOPLEFT,planner,TOPLEFT,14,7)
    mapTitle:SetFont("$(BOLD_FONT)|17")
    mapTitle:SetColor(0.91,0.75,0.30,1)
    self.statisticsAllianceMapTitle=mapTitle

    -- Source map aspect is 916:663 (~1.3816). 468x339 preserves it.
    local mapFrame=WINDOW_MANAGER:CreateControl(nil,planner,CT_BACKDROP)
    mapFrame:SetDimensions(460,334)
    mapFrame:SetAnchor(TOPLEFT,planner,TOPLEFT,13,31)
    mapFrame:SetCenterColor(0.005,0.005,0.004,0.08)
    mapFrame:SetEdgeColor(0.50,0.40,0.18,0.92)
    mapFrame:SetEdgeTexture(nil,1,1,1)
    mapFrame:SetMouseEnabled(false)
    if mapFrame.SetDrawLevel then mapFrame:SetDrawLevel(2) end
    self.statisticsAllianceMapFrame=mapFrame

    -- Invisible interaction surface. The visible map itself is assembled at
    -- runtime from ESO's original Tamriel map tiles.
    local mapTexture=WINDOW_MANAGER:CreateControl(nil,mapFrame,CT_TEXTURE)
    mapTexture:SetDimensions(454,328)
    mapTexture:SetAnchor(CENTER,mapFrame,CENTER,0,0)
    mapTexture:SetTexture(nil)
    mapTexture:SetAlpha(0)
    mapTexture:SetMouseEnabled(true)
    if mapTexture.SetDrawLevel then mapTexture:SetDrawLevel(20) end
    -- mapTexture remains the geometry reference used for zoom/pan calculations.
    -- Mouse input is handled by a dedicated transparent layer above the map
    -- tiles. This avoids child/background controls swallowing left-clicks.
    mapTexture:SetMouseEnabled(false)
    self.statisticsAllianceMapTexture=mapTexture

    local inputLayer=WINDOW_MANAGER:CreateControl(nil,mapFrame,CT_CONTROL)
    inputLayer:SetAnchorFill(mapFrame)
    inputLayer:SetMouseEnabled(true)
    if inputLayer.SetDrawLevel then inputLayer:SetDrawLevel(20) end
    inputLayer:SetHandler("OnMouseDown",function(_,button)
        if button==MOUSE_BUTTON_INDEX_LEFT then
            TPM:BeginAlliancePlannerMapPan()
        end
    end)
    inputLayer:SetHandler("OnMouseUp",function(_,button)
        if button==MOUSE_BUTTON_INDEX_LEFT then
            TPM:EndAlliancePlannerMapPan()
        end
    end)
    inputLayer:SetHandler("OnMouseWheel",function(_,delta)
        TPM:ZoomAlliancePlannerMapAtMouse((tonumber(delta) or 0)>0 and 0.25 or -0.25)
    end)
    inputLayer:SetHandler("OnHide",function()
        TPM:EndAlliancePlannerMapPan()
    end)
    self.statisticsAllianceMapInputLayer=inputLayer

    -- Fallback is only shown if the ESO client cannot resolve the original
    -- Tamriel tile source. This prevents a completely blank Alliance map.
    local mapFallback=WINDOW_MANAGER:CreateControl(nil,mapFrame,CT_TEXTURE)
    mapFallback:SetAnchorFill(mapFrame)
    mapFallback:SetTexture("NagaMapaCompleto/art/alliance_community_map.dds")
    mapFallback:SetAlpha(0.90)
    mapFallback:SetMouseEnabled(false)
    if mapFallback.SetDrawLevel then mapFallback:SetDrawLevel(4) end
    mapFallback:SetHidden(true)
    self.statisticsAllianceMapFallback=mapFallback

    -- Recommendations below map, inside planner.
    local nextBox=WINDOW_MANAGER:CreateControl(nil,planner,CT_BACKDROP)
    nextBox:SetDimensions(216,32)
    nextBox:SetAnchor(BOTTOMLEFT,planner,BOTTOMLEFT,13,-5)
    nextBox:SetCenterColor(0.035,0.032,0.025,0.96)
    nextBox:SetEdgeColor(0.35,0.29,0.14,0.85)
    nextBox:SetEdgeTexture(nil,1,1,1)

    local nextTitle=WINDOW_MANAGER:CreateControl(nil,nextBox,CT_LABEL)
    nextTitle:SetDimensions(208,12)
    nextTitle:SetAnchor(TOPLEFT,nextBox,TOPLEFT,7,2)
    nextTitle:SetFont("$(BOLD_FONT)|13")
    nextTitle:SetColor(0.87,0.72,0.26,1)
    self.statisticsAllianceNextTitle=nextTitle

    local nextValue=WINDOW_MANAGER:CreateControl(nil,nextBox,CT_LABEL)
    nextValue:SetDimensions(208,13)
    nextValue:SetAnchor(TOPLEFT,nextBox,TOPLEFT,7,14)
    nextValue:SetFont("$(MEDIUM_FONT)|13")
    nextValue:SetColor(0.90,0.86,0.75,1)
    self.statisticsAllianceNextValue=nextValue

    local gapBox=WINDOW_MANAGER:CreateControl(nil,planner,CT_BACKDROP)
    gapBox:SetDimensions(216,32)
    gapBox:SetAnchor(BOTTOMRIGHT,planner,BOTTOMRIGHT,-13,-5)
    gapBox:SetCenterColor(0.035,0.032,0.025,0.96)
    gapBox:SetEdgeColor(0.35,0.29,0.14,0.85)
    gapBox:SetEdgeTexture(nil,1,1,1)

    local gapTitle=WINDOW_MANAGER:CreateControl(nil,gapBox,CT_LABEL)
    gapTitle:SetDimensions(208,12)
    gapTitle:SetAnchor(TOPLEFT,gapBox,TOPLEFT,7,2)
    gapTitle:SetFont("$(BOLD_FONT)|13")
    gapTitle:SetColor(0.87,0.72,0.26,1)
    self.statisticsAllianceGapTitle=gapTitle

    local gapValue=WINDOW_MANAGER:CreateControl(nil,gapBox,CT_LABEL)
    gapValue:SetDimensions(208,13)
    gapValue:SetAnchor(TOPLEFT,gapBox,TOPLEFT,7,14)
    gapValue:SetFont("$(MEDIUM_FONT)|13")
    gapValue:SetColor(0.90,0.86,0.75,1)
    self.statisticsAllianceGapValue=gapValue

    -- Right: legend + zoom ----------------------------------------------------
    local tools=WINDOW_MANAGER:CreateControl(nil,page,CT_BACKDROP)
    tools:SetDimensions(190,200)
    tools:SetAnchor(TOPLEFT,page,TOPLEFT,748,100)
    tools:SetCenterColor(0.020,0.019,0.016,0.99)
    tools:SetEdgeColor(0.42,0.34,0.15,0.90)
    tools:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds",128,16,2)

    local toolsTitle=WINDOW_MANAGER:CreateControl(nil,tools,CT_LABEL)
    toolsTitle:SetDimensions(164,20)
    toolsTitle:SetAnchor(TOPLEFT,tools,TOPLEFT,12,7)
    toolsTitle:SetFont("$(BOLD_FONT)|16")
    toolsTitle:SetColor(0.91,0.75,0.30,1)
    toolsTitle:SetText(self:L("STAT_ALLIANCE_TOOLS_TITLE"))
    self.statisticsAllianceToolsTitle=toolsTitle

        -- Faction legend: alliance badges + colored dots for non-faction
    -- Legend dots use the same alliance colors as the in-game map markers
    self.statisticsAllianceLegendRows = {}
    local legendDefs = {
        { key = "DC",      labelKey = "STAT_ALLIANCE_DC",      color = {0.30, 0.60, 1.00} }, -- Daggerfall blue
        { key = "AD",      labelKey = "STAT_ALLIANCE_AD",      color = {0.95, 0.82, 0.24} }, -- Aldmeri gold
        { key = "EP",      labelKey = "STAT_ALLIANCE_EP",      color = {0.95, 0.28, 0.22} }, -- Ebonheart red
        { key = "NEUTRAL", labelKey = "STAT_ALLIANCE_NEUTRAL", color = {0.92, 0.91, 0.88} }, -- Neutral white
        { key = "CYRO",    labelKey = "STAT_ALLIANCE_CYRODIIL",color = {0.25, 0.80, 0.28} }, -- Cyrodiil green
    }
    for i, def in ipairs(legendDefs) do
        local y = 26 + (i - 1) * 20
        local row = WINDOW_MANAGER:CreateControl(nil, tools, CT_CONTROL)
        row:SetDimensions(166, 18)
        row:SetAnchor(TOPLEFT, tools, TOPLEFT, 12, y)

        local dot = WINDOW_MANAGER:CreateControl(nil, row, CT_BACKDROP)
        dot:SetDimensions(13, 13)
        dot:SetAnchor(LEFT, row, LEFT, 1, 0)
        local c = def.color
        dot:SetCenterColor(c[1], c[2], c[3], 1)
        dot:SetEdgeColor(c[1] * 0.55, c[2] * 0.55, c[3] * 0.55, 1)
        dot:SetEdgeTexture(nil, 1, 1, 1)

        local text = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
        text:SetDimensions(140, 18)
        text:SetAnchor(LEFT, row, LEFT, 20, 0)
        text:SetFont("$(MEDIUM_FONT)|12")
        text:SetColor(c[1], c[2], c[3], 1) -- name in faction color too
        text:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        text:SetText(self:L(def.labelKey))
        self.statisticsAllianceLegendRows[def.key] = text
    end
    self.statisticsAllianceLegend = nil

local zoomTitle=WINDOW_MANAGER:CreateControl(nil,tools,CT_LABEL)
    zoomTitle:SetDimensions(60,18)
    zoomTitle:SetAnchor(TOPLEFT,tools,TOPLEFT,12,130)
    zoomTitle:SetFont("$(BOLD_FONT)|17")
    zoomTitle:SetColor(0.88,0.82,0.68,1)
    zoomTitle:SetText(self:L("STAT_ALLIANCE_ZOOM"))
    self.statisticsAllianceZoomTitle=zoomTitle

    local zoomLabel=WINDOW_MANAGER:CreateControl(nil,tools,CT_LABEL)
    zoomLabel:SetDimensions(70,18)
    zoomLabel:SetAnchor(TOPRIGHT,tools,TOPRIGHT,-12,129)
    zoomLabel:SetFont("$(ANTIQUE_FONT)|24")
    zoomLabel:SetColor(0.95,0.82,0.32,1)
    zoomLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    zoomLabel:SetText("100%")
    self.statisticsAllianceMapZoomLabel=zoomLabel

    local zoomRange=WINDOW_MANAGER:CreateControl(nil,tools,CT_LABEL)
    zoomRange:SetDimensions(166,14)
    zoomRange:SetAnchor(TOPLEFT,tools,TOPLEFT,12,130)
    zoomRange:SetFont("$(MEDIUM_FONT)|12")
    zoomRange:SetColor(0.60,0.57,0.50,1)
    zoomRange:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    zoomRange:SetText("0%  —  350%")

    local zoomMinus=WINDOW_MANAGER:CreateControl(nil,tools,CT_BUTTON)
    zoomMinus:SetDimensions(32,22)
    zoomMinus:SetAnchor(BOTTOMLEFT,tools,BOTTOMLEFT,12,-8)
    zoomMinus:SetFont("$(BOLD_FONT)|17")
    zoomMinus:SetNormalFontColor(0.95,0.85,0.55,1)
    zoomMinus:SetMouseOverFontColor(1,1,0.80,1)
    zoomMinus:SetText("−")
    zoomMinus:SetHandler("OnClicked",function() TPM:ZoomAlliancePlannerMapAtMouse(-0.25) end)

    local resetZoom=WINDOW_MANAGER:CreateControl(nil,tools,CT_BUTTON)
    resetZoom:SetDimensions(64,22)
    resetZoom:SetAnchor(BOTTOM,tools,BOTTOM,0,-8)
    resetZoom:SetFont("$(BOLD_FONT)|13")
    resetZoom:SetNormalFontColor(0.90,0.84,0.70,1)
    resetZoom:SetMouseOverFontColor(1,0.88,0.36,1)
    resetZoom:SetText("0%")
    resetZoom:SetHandler("OnClicked",function() TPM:SetAlliancePlannerMapZoom(1.0) end)

    local zoomPlus=WINDOW_MANAGER:CreateControl(nil,tools,CT_BUTTON)
    zoomPlus:SetDimensions(32,22)
    zoomPlus:SetAnchor(BOTTOMRIGHT,tools,BOTTOMRIGHT,-12,-8)
    zoomPlus:SetFont("$(BOLD_FONT)|17")
    zoomPlus:SetNormalFontColor(0.95,0.85,0.55,1)
    zoomPlus:SetMouseOverFontColor(1,1,0.80,1)
    zoomPlus:SetText("+")
    zoomPlus:SetHandler("OnClicked",function() TPM:ZoomAlliancePlannerMapAtMouse(0.25) end)

    -- Right: zone progress -----------------------------------------------------
    local zonePanel=WINDOW_MANAGER:CreateControl(nil,page,CT_BACKDROP)
    zonePanel:SetDimensions(190,250)
    zonePanel:SetAnchor(TOPLEFT,page,TOPLEFT,748,308)
    zonePanel:SetCenterColor(0.020,0.019,0.016,0.99)
    zonePanel:SetEdgeColor(0.42,0.34,0.15,0.90)
    zonePanel:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds",128,16,2)

    local zoneTitle=WINDOW_MANAGER:CreateControl(nil,zonePanel,CT_LABEL)
    zoneTitle:SetDimensions(164,20)
    zoneTitle:SetAnchor(TOPLEFT,zonePanel,TOPLEFT,12,7)
    zoneTitle:SetFont("$(BOLD_FONT)|17")
    zoneTitle:SetColor(0.91,0.75,0.30,1)
    self.statisticsAllianceZoneTitle=zoneTitle

    local zoneHint=WINDOW_MANAGER:CreateControl(nil,zonePanel,CT_LABEL)
    zoneHint:SetDimensions(164,28)
    zoneHint:SetAnchor(TOPLEFT,zonePanel,TOPLEFT,12,25)
    zoneHint:SetFont("$(MEDIUM_FONT)|13")
    zoneHint:SetColor(0.62,0.59,0.52,1)
    zoneHint:SetVerticalAlignment(TEXT_ALIGN_TOP)
    self.statisticsAllianceZoneHint=zoneHint

    self.statisticsAllianceZoneRows={}
    for i=1,7 do
        local row=WINDOW_MANAGER:CreateControl(nil,zonePanel,CT_BUTTON)
        row:SetDimensions(164,28)
        row:SetAnchor(TOPLEFT,zonePanel,TOPLEFT,12,52+((i-1)*30))
        row:SetMouseEnabled(true)

        local hover=WINDOW_MANAGER:CreateControl(nil,row,CT_BACKDROP)
        hover:SetAnchorFill(row)
        hover:SetCenterColor(0.018,0.016,0.012,0)
        hover:SetEdgeColor(0.22,0.18,0.10,0)
        hover:SetEdgeTexture(nil,1,1,1)
        hover:SetMouseEnabled(false)

        local name=WINDOW_MANAGER:CreateControl(nil,row,CT_LABEL)
        name:SetDimensions(118,15)
        name:SetAnchor(TOPLEFT,row,TOPLEFT,0,1)
        name:SetFont("$(MEDIUM_FONT)|14")
        name:SetColor(0.94,0.92,0.86,1)
        name:SetMouseEnabled(false)

        local pct=WINDOW_MANAGER:CreateControl(nil,row,CT_LABEL)
        pct:SetDimensions(50,15)
        pct:SetAnchor(TOPRIGHT,row,TOPRIGHT,0,1)
        pct:SetFont("$(BOLD_FONT)|14")
        pct:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        pct:SetMouseEnabled(false)

        local barBack=WINDOW_MANAGER:CreateControl(nil,row,CT_BACKDROP)
        barBack:SetDimensions(164,6)
        barBack:SetAnchor(TOPLEFT,row,TOPLEFT,0,17)
        barBack:SetCenterColor(0.060,0.055,0.045,1)
        barBack:SetEdgeColor(0.25,0.22,0.16,0.9)
        barBack:SetEdgeTexture(nil,1,1,1)
        barBack:SetMouseEnabled(false)

        local fill=WINDOW_MANAGER:CreateControl(nil,barBack,CT_BACKDROP)
        fill:SetDimensions(1,4)
        fill:SetAnchor(LEFT,barBack,LEFT,1,0)
        fill:SetEdgeColor(0,0,0,0)

        local count=WINDOW_MANAGER:CreateControl(nil,row,CT_LABEL)
        count:SetDimensions(164,12)
        count:SetAnchor(TOPLEFT,row,TOPLEFT,0,24)
        count:SetFont("$(MEDIUM_FONT)|12")
        count:SetColor(0.78,0.75,0.68,1)
        count:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        count:SetMouseEnabled(false)

        row.hover=hover
        row:SetHandler("OnMouseEnter",function(btn)
            if TPM:IsStatisticsDarkDesign() then btn.hover:SetCenterColor(0,0,0,.36); btn.hover:SetEdgeColor(1,1,1,.30)
            else btn.hover:SetCenterColor(0.075,0.057,0.020,0.70); btn.hover:SetEdgeColor(0.70,0.54,0.16,0.75) end
        end)
        row:SetHandler("OnMouseExit",function(btn)
            if TPM:IsStatisticsDarkDesign() then btn.hover:SetCenterColor(0,0,0,0); btn.hover:SetEdgeColor(1,1,1,0)
            else btn.hover:SetCenterColor(0.018,0.016,0.012,0); btn.hover:SetEdgeColor(0.22,0.18,0.10,0) end
        end)
        row:SetHandler("OnClicked",function(btn)
            if btn.zoneId then TPM:OpenAllianceZoneInProgress(btn.zoneId) end
        end)

        self.statisticsAllianceZoneRows[i]={control=row,name=name,pct=pct,bar=fill,count=count}
    end

    -- Bottom details: fully above tab bar -------------------------------------
    local details=WINDOW_MANAGER:CreateControl(nil,page,CT_BACKDROP)
    details:SetDimensions(700,100)
    details:SetAnchor(TOPLEFT,page,TOPLEFT,20,520)
    details:SetCenterColor(0.020,0.019,0.016,0.99)
    details:SetEdgeColor(0.45,0.36,0.16,0.92)
    details:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds",128,16,2)

    local detailsTitle=WINDOW_MANAGER:CreateControl(nil,details,CT_LABEL)
    detailsTitle:SetDimensions(860,22)
    detailsTitle:SetAnchor(TOPLEFT,details,TOPLEFT,14,6)
    detailsTitle:SetFont("$(BOLD_FONT)|18")
    detailsTitle:SetColor(0.91,0.75,0.30,1)
    self.statisticsAllianceDetailsTitle=detailsTitle

    self.statisticsAllianceDetailRows={}
    for i=1,7 do
        local col=(i-1)%4
        local rowIndex=math.floor((i-1)/4)
        local cell=WINDOW_MANAGER:CreateControl(nil,details,CT_CONTROL)
        cell:SetDimensions(165,34)
        cell:SetAnchor(TOPLEFT,details,TOPLEFT,12+col*172,28+rowIndex*34)

        local label=WINDOW_MANAGER:CreateControl(nil,cell,CT_LABEL)
        label:SetDimensions(100,14)
        label:SetAnchor(TOPLEFT,cell,TOPLEFT,0,0)
        label:SetFont("$(MEDIUM_FONT)|13")
        label:SetColor(0.88,0.85,0.78,1)

        local value=WINDOW_MANAGER:CreateControl(nil,cell,CT_LABEL)
        value:SetDimensions(64,14)
        value:SetAnchor(TOPRIGHT,cell,TOPRIGHT,0,0)
        value:SetFont("$(BOLD_FONT)|14")
        value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        value:SetColor(0.95,0.86,0.45,1)

        local back=WINDOW_MANAGER:CreateControl(nil,cell,CT_BACKDROP)
        back:SetDimensions(165,6)
        back:SetAnchor(TOPLEFT,cell,TOPLEFT,0,16)
        back:SetCenterColor(0.055,0.050,0.040,1)
        back:SetEdgeColor(0.22,0.19,0.13,0.85)
        back:SetEdgeTexture(nil,1,1,1)

        local fill=WINDOW_MANAGER:CreateControl(nil,back,CT_BACKDROP)
        fill:SetDimensions(1,4)
        fill:SetAnchor(LEFT,back,LEFT,1,0)
        fill:SetEdgeColor(0,0,0,0)

        local remain=WINDOW_MANAGER:CreateControl(nil,cell,CT_LABEL)
        remain:SetDimensions(165,12)
        remain:SetAnchor(TOPLEFT,cell,TOPLEFT,0,23)
        remain:SetFont("$(MEDIUM_FONT)|11")
        remain:SetColor(0.70,0.68,0.62,1)
        remain:SetHidden(true) -- remove bottom "restantes" line under each category
        remain:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

        self.statisticsAllianceDetailRows[i]={label=label,value=value,bar=fill,remain=remain}
    end

    self.statisticsAllianceNote=WINDOW_MANAGER:CreateControl(nil,page,CT_LABEL)
    self.statisticsAllianceNote:SetDimensions(900,10)
    self.statisticsAllianceNote:SetAnchor(BOTTOM,page,BOTTOM,0,1)
    self.statisticsAllianceNote:SetFont("$(MEDIUM_FONT)|12")
    self.statisticsAllianceNote:SetColor(0.48,0.46,0.42,1)
    self.statisticsAllianceNote:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
end

function TPM:RefreshAllianceStatisticsPage()
    if not self.statisticsAlliancePage or self.statisticsAlliancePage:IsHidden() then return end

    local _,allianceName,ownGroup=self:GetPlayerAllianceDisplay()
    local data=self:GetAllianceStatisticsData()
    local ownRow=ownGroup and data[ownGroup] or nil

    self.statisticsAllianceOwnTitle:SetText(self:L("STAT_ALLIANCE_YOURS"))
    if self.statisticsAllianceQuickTitle then self.statisticsAllianceQuickTitle:SetText(self:L("STAT_ALLIANCE_OVERVIEW")) end
    if self.statisticsAllianceToolsTitle then self.statisticsAllianceToolsTitle:SetText(self:L("STAT_ALLIANCE_TOOLS_TITLE")) end
    if self.statisticsAllianceZoomTitle then self.statisticsAllianceZoomTitle:SetText(self:L("STAT_ALLIANCE_ZOOM")) end
    if self.statisticsAllianceLegendRows then
        local map = {
            DC = "STAT_ALLIANCE_DC",
            AD = "STAT_ALLIANCE_AD",
            EP = "STAT_ALLIANCE_EP",
            NEUTRAL = "STAT_ALLIANCE_NEUTRAL",
            CYRO = "STAT_ALLIANCE_CYRODIIL",
        }
        for key, label in pairs(self.statisticsAllianceLegendRows) do
            local loc = map[key]
            if loc and label and label.SetText then
                label:SetText(self:L(loc))
            end
        end
    end
    self.statisticsAllianceOwnName:SetText(allianceName)
    self.statisticsAllianceOwnPercent:SetText(string.format("%d%%",ownRow and ownRow.percent or 0))

    local ownColor={0.78,0.62,0.22}
    if ownGroup and self.statisticsAllianceCards and self.statisticsAllianceCards[ownGroup] then
        ownColor=self.statisticsAllianceCards[ownGroup].color or ownColor
    end
    self.statisticsAllianceOwnBar:SetCenterColor(ownColor[1],ownColor[2],ownColor[3],0.95)
    local ownPct=Clamp(tonumber(ownRow and ownRow.percent) or 0,0,100)
    self.statisticsAllianceOwnBar:SetWidth(math.max(1,math.floor(878*ownPct/100)))

    if not self.statisticsAllianceSelectedGroup then
        self.statisticsAllianceSelectedGroup=ownGroup or "DC"
    end

    for group,card in pairs(self.statisticsAllianceCards or {}) do
        local row=data[group] or {percent=0,zonesCompleted=0,zonesTotal=0,completed=0,total=0}
        card.title:SetText(self:L(card.label))
        card.badge:SetText(ownGroup==group and self:L("STAT_ALLIANCE_YOURS_SHORT") or "")
        card.percent:SetText(string.format("%d%%",row.percent or 0))
        card.zones:SetText(string.format("%d/%d %s",row.zonesCompleted or 0,row.zonesTotal or 0,self:L("STAT_ALLIANCE_ZONES_SHORT")))
        card.objectives:SetText(string.format("%d/%d",row.completed or 0,row.total or 0))
        local pct=Clamp(tonumber(row.percent) or 0,0,100)
        card.bar:SetWidth(math.max(1,math.floor(192*pct/100)))

        local selected=self.statisticsAllianceSelectedGroup==group
        if selected then
            card.control:SetCenterColor(math.min(0.12,card.color[1]*0.10),math.min(0.12,card.color[2]*0.10),math.min(0.12,card.color[3]*0.10),1)
            card.control:SetEdgeColor(card.color[1],card.color[2],card.color[3],1)
        else
            card.control:SetCenterColor(0.022,0.021,0.018,0.99)
            card.control:SetEdgeColor(card.color[1],card.color[2],card.color[3],0.68)
        end
    end

    local selectedGroup=self.statisticsAllianceSelectedGroup or ownGroup or "DC"
    if selectedGroup~="DC" and selectedGroup~="AD" and selectedGroup~="EP" then
        selectedGroup=ownGroup or "DC"
        self.statisticsAllianceSelectedGroup=selectedGroup
    end

    local selectedCard=self.statisticsAllianceCards and self.statisticsAllianceCards[selectedGroup]
    local selectedName=selectedCard and self:L(selectedCard.label) or selectedGroup
    local selectedColor=selectedCard and selectedCard.color or {0.78,0.62,0.22}
    local territoryColors = true

    if self.statisticsAllianceMapFrame then
        if territoryColors then
            self.statisticsAllianceMapFrame:SetEdgeColor(selectedColor[1],selectedColor[2],selectedColor[3],1)
        else
            self.statisticsAllianceMapFrame:SetEdgeColor(0.72,0.56,0.18,0.95)
        end
    end
    if self.statisticsAllianceLegend then
        self.statisticsAllianceLegend:SetHidden(false)
    end
    if self.statisticsAllianceMapPanel then
        self.statisticsAllianceMapPanel:SetEdgeColor(selectedColor[1],selectedColor[2],selectedColor[3],0.82)
    end
    if self.statisticsAllianceMapTexture then
        self:RefreshAlliancePlannerMapView()
    end
    if self.statisticsAllianceMapTitle then
        self.statisticsAllianceMapTitle:SetText(self:L("STAT_ALLIANCE_PLANNER_TITLE",selectedName))
    end
    local nextTarget,biggestGap,zoneRows=self:GetAlliancePlannerRecommendations(selectedGroup)

    local selectedStats=data[selectedGroup] or {zonesCompleted=0,zonesTotal=0,completed=0,total=0}
    local zoneOpen=math.max(0,(selectedStats.zonesTotal or 0)-(selectedStats.zonesCompleted or 0))
    local objOpen=math.max(0,(selectedStats.total or 0)-(selectedStats.completed or 0))
    if self.statisticsAllianceQuickDone then
        self.statisticsAllianceQuickDone:SetText(self:L("STAT_ALLIANCE_QUICK_DONE",
            selectedStats.zonesCompleted or 0, selectedStats.zonesTotal or 0))
    end
    if self.statisticsAllianceQuickOpen then
        self.statisticsAllianceQuickOpen:SetText(self:L("STAT_ALLIANCE_QUICK_OPEN",
            zoneOpen, objOpen))
    end
    if self.statisticsAllianceQuickNext then
        if nextTarget then
            self.statisticsAllianceQuickNext:SetText(self:L("STAT_ALLIANCE_QUICK_NEXT",
                nextTarget.name, nextTarget.percent))
        else
            self.statisticsAllianceQuickNext:SetText(self:L("STAT_ALLIANCE_COMPLETE"))
        end
    end
    if self.statisticsAllianceNextTitle then self.statisticsAllianceNextTitle:SetText(self:L("STAT_ALLIANCE_NEXT_TARGET")) end
    if self.statisticsAllianceGapTitle then self.statisticsAllianceGapTitle:SetText(self:L("STAT_ALLIANCE_BIGGEST_GAP")) end
    if self.statisticsAllianceNextValue then
        if nextTarget then
            self.statisticsAllianceNextValue:SetText(string.format("%s  %d%%  •  %d %s",
                nextTarget.name,nextTarget.percent,nextTarget.remaining,self:L("STAT_ALLIANCE_REMAINING_SHORT")))
        else
            self.statisticsAllianceNextValue:SetText(self:L("STAT_ALLIANCE_COMPLETE"))
        end
    end
    if self.statisticsAllianceGapValue then
        if biggestGap then
            self.statisticsAllianceGapValue:SetText(string.format("%s  %d%%  •  %d %s",
                biggestGap.name,biggestGap.percent,biggestGap.remaining,self:L("STAT_ALLIANCE_REMAINING_SHORT")))
        else
            self.statisticsAllianceGapValue:SetText(self:L("STAT_ALLIANCE_COMPLETE"))
        end
    end

    if self.statisticsAllianceZoneTitle then
        self.statisticsAllianceZoneTitle:SetText(self:L("STAT_ALLIANCE_ZONE_PROGRESS"))
    end
    if self.statisticsAllianceZoneHint then
        self.statisticsAllianceZoneHint:SetText(self:L("STAT_ALLIANCE_ZONE_CLICK_HINT"))
    end

    for i,controls in ipairs(self.statisticsAllianceZoneRows or {}) do
        local z=zoneRows[i]
        if z then
            controls.control:SetHidden(false)
            controls.control.zoneId=z.zoneId
            controls.name:SetText(z.name)
            controls.pct:SetText(string.format("%d%%",z.percent))
            if controls.count then controls.count:SetText(""); controls.count:SetHidden(true) end
            controls.bar:SetWidth(math.max(1,math.floor(162*z.percent/100)))
            if z.complete then
                controls.pct:SetColor(0.95,0.82,0.30,1)
                controls.bar:SetCenterColor(0.90,0.72,0.20,0.98)
            elseif z.percent>=75 then
                controls.pct:SetColor(0.72,0.90,0.36,1)
                controls.bar:SetCenterColor(0.58,0.80,0.24,0.95)
            elseif z.percent>=40 then
                controls.pct:SetColor(0.92,0.74,0.30,1)
                if territoryColors then
                    controls.bar:SetCenterColor(selectedColor[1],selectedColor[2],selectedColor[3],0.96)
                else
                    controls.bar:SetCenterColor(0.70,0.52,0.18,0.92)
                end
            else
                controls.pct:SetColor(0.96,0.45,0.30,1)
                controls.bar:SetCenterColor(0.82,0.28,0.16,0.92)
            end
        else
            controls.control.zoneId=nil
            controls.control:SetHidden(true)
        end
    end

    self.statisticsAllianceDetailsTitle:SetText(selectedName.."  •  "..self:L("STAT_ALLIANCE_PROGRESS_DETAILS"))
    local detailRows=self:GetAllianceCategoryStatisticsData(selectedGroup)
    for i,controls in ipairs(self.statisticsAllianceDetailRows or {}) do
        local row=detailRows[i]
        if row then
            local remaining=math.max(0,(row.total or 0)-(row.completed or 0))
            controls.label:SetText(row.label)
            controls.value:SetText(string.format("%d/%d  %d%%",row.completed or 0,row.total or 0,row.percent or 0))
            if controls.remain then controls.remain:SetText(""); controls.remain:SetHidden(true) end
            controls.bar:SetWidth(math.max(1,math.floor(163*(row.percent or 0)/100)))
            if (row.percent or 0)>=100 then
                controls.bar:SetCenterColor(0.90,0.72,0.20,0.98)
            else
                controls.bar:SetCenterColor(selectedColor[1],selectedColor[2],selectedColor[3],0.92)
            end
        else
            controls.label:SetText("")
            controls.value:SetText("")
            controls.remain:SetText("")
            controls.bar:SetWidth(1)
        end
    end

    self:RefreshAlliancePlannerMapView()
    self.statisticsAllianceNote:SetText(self:L("STAT_ALLIANCE_PLANNER_NOTE"))
end

function TPM:IsValidStatisticsPage(page)
    -- Keep the old page names as compatibility aliases for slash commands and
    -- SavedVariables from 2.7.30 and older. They are no longer main tabs.
    return page == "progress" or page == "economy" or page == "history"
        or page == "player" or page == "alliance"
end

function TPM:GetStatisticsProgressSubPage()
    return (self.saved and tonumber(self.saved.statisticsProgressSubPage) == 2) and 2 or 1
end

function TPM:GetStatisticsHistorySubPage()
    return (self.saved and tonumber(self.saved.statisticsHistorySubPage) == 2) and 2 or 1
end

function TPM:SetStatisticsSubPage(pageNumber)
    if not self.saved then return end
    local page = self.saved.statisticsPage or "progress"
    local nextPage = tonumber(pageNumber) == 2 and 2 or 1
    if page == "progress" then
        self.saved.statisticsProgressSubPage = nextPage
    elseif page == "history" then
        self.saved.statisticsHistorySubPage = nextPage
    else
        return
    end
    self:HideEconomyFocusDropdown()
    self:HideStatisticsHoverTooltips()
    self:HideStatisticsFocusDropdown()
    self:UpdateStatisticsPageVisibility(page)
    self:RefreshStatisticsPageTabs()
    self:RefreshStatisticsSubPageNavigation()
    local progressMainPage = page == "progress" and self:GetStatisticsProgressSubPage() == 1
    if self.statisticsThemeGear then self.statisticsThemeGear:SetHidden(not progressMainPage) end
    if self.statisticsThemeGearLabel then self.statisticsThemeGearLabel:SetHidden(not progressMainPage) end
    if not progressMainPage and self.statisticsThemeWindow and not self.statisticsThemeWindow:IsHidden() then self:SetStatisticsThemeWindowVisible(false) end
    self:ApplyStatisticsTheme()
    self:RefreshStatisticsWindow()
end

function TPM:UpdateStatisticsPageVisibility(page)
    if page == "player" then
        page = "history"
        if self.saved then self.saved.statisticsHistorySubPage = 2 end
    elseif page == "alliance" then
        page = "progress"
        if self.saved then self.saved.statisticsProgressSubPage = 2 end
    end
    if page ~= "progress" and page ~= "economy" and page ~= "history" then page = "progress" end

    local progressSubPage = self:GetStatisticsProgressSubPage()
    local historySubPage = self:GetStatisticsHistorySubPage()
    local showProgress = page == "progress" and progressSubPage == 1
    local showAlliance = page == "progress" and progressSubPage == 2
    local showHistory = page == "history" and historySubPage == 1
    local showPlayer = page == "history" and historySubPage == 2

    if self.statisticsProgressPage then self.statisticsProgressPage:SetHidden(not showProgress) end
    if self.statisticsAlliancePage then self.statisticsAlliancePage:SetHidden(not showAlliance) end
    if self.statisticsHistoryPage then self.statisticsHistoryPage:SetHidden(not showHistory) end
    if self.statisticsPlayerPage then self.statisticsPlayerPage:SetHidden(not showPlayer) end
    if self.statisticsEconomyPage then self.statisticsEconomyPage:SetHidden(page ~= "economy") end
    if self.statisticsListArea then self.statisticsListArea:SetMouseEnabled(showProgress) end
    if self.statisticsScrollBar then self.statisticsScrollBar:SetMouseEnabled(showProgress) end
end

function TPM:RefreshStatisticsPageTabs()
    local page = self.saved and self.saved.statisticsPage or "progress"
    if page == "player" then page = "history" end
    if page == "alliance" then page = "progress" end
    if page ~= "progress" and page ~= "economy" and page ~= "history" then page = "progress" end
    local tabs = {
        { self.statisticsProgressTab, "progress", "STAT_TAB_PROGRESS" },
        { self.statisticsEconomyTab, "economy", "STAT_TAB_ECONOMY" },
        { self.statisticsHistoryTab, "history", "STAT_TAB_HISTORY" },
    }
    for _, item in ipairs(tabs) do
        local control, key, labelKey = item[1], item[2], item[3]
        if control then
            local selected = page == key
            local label = self:L(labelKey)
            control:SetText((selected and "|cE6C45C" or "") .. label .. (selected and "|r" or ""))
            if control.TPMAccent then control.TPMAccent:SetHidden(not selected) end
            if control.TPMBackdrop then
                if selected then
                    control.TPMBackdrop:SetCenterColor(0.095, 0.072, 0.024, 0.98)
                    control.TPMBackdrop:SetEdgeColor(0.86, 0.66, 0.18, 0.96)
                else
                    control.TPMBackdrop:SetCenterColor(0.026, 0.023, 0.018, 0.94)
                    control.TPMBackdrop:SetEdgeColor(0.36, 0.29, 0.14, 0.70)
                end
            end
        end
    end
end

function TPM:RefreshStatisticsSubPageNavigation()
    local nav = self.statisticsSubPageNavigation
    if not nav then return end
    local page = self.saved and self.saved.statisticsPage or "progress"
    if page == "player" then page = "history" end
    if page == "alliance" then page = "progress" end
    local show = page == "progress" or page == "history"
    nav:SetHidden(not show)
    if self.statisticsMode then self.statisticsMode:SetHidden(show) end
    if not show then return end

    local subPage = page == "progress" and self:GetStatisticsProgressSubPage() or self:GetStatisticsHistorySubPage()
    if self.statisticsSubPageCounter then self.statisticsSubPageCounter:SetText(tostring(subPage) .. " / 2") end
    if self.statisticsSubPagePrev then
        self.statisticsSubPagePrev:SetHidden(subPage <= 1)
        self.statisticsSubPagePrev:SetMouseEnabled(subPage > 1)
    end
    if self.statisticsSubPageNext then
        self.statisticsSubPageNext:SetHidden(subPage >= 2)
        self.statisticsSubPageNext:SetMouseEnabled(subPage < 2)
    end
end

function TPM:SetStatisticsPage(page)
    self:HideEconomyFocusDropdown()
    self:HideStatisticsHoverTooltips()
    self:HideStatisticsFocusDropdown()

    -- Compatibility: old Character/Alliance main-page requests now open the
    -- matching second page of PvE/PvP or Progress.
    if page == "player" then
        page = "history"
        if self.saved then self.saved.statisticsHistorySubPage = 2 end
    elseif page == "alliance" then
        page = "progress"
        if self.saved then self.saved.statisticsProgressSubPage = 2 end
    end
    if page ~= "progress" and page ~= "economy" and page ~= "history" then page = "progress" end
    if self.saved then self.saved.statisticsPage = page end
    self:UpdateStatisticsPageVisibility(page)
    self:RefreshStatisticsPageTabs()
    self:RefreshStatisticsSubPageNavigation()
    local progressMainPage = page == "progress" and self:GetStatisticsProgressSubPage() == 1
    if self.statisticsThemeGear then self.statisticsThemeGear:SetHidden(not progressMainPage) end
    if self.statisticsThemeGearLabel then self.statisticsThemeGearLabel:SetHidden(not progressMainPage) end
    if not progressMainPage and self.statisticsThemeWindow and not self.statisticsThemeWindow:IsHidden() then self:SetStatisticsThemeWindowVisible(false) end
    self:ApplyStatisticsTheme()
    self:RefreshStatisticsWindow()
end
function TPM:SetProgressStatisticsControlsHidden(hidden)
    if self.statisticsProgressPage then self.statisticsProgressPage:SetHidden(hidden) end
    if self.statisticsListArea then self.statisticsListArea:SetMouseEnabled(not hidden) end
    if self.statisticsScrollBar then self.statisticsScrollBar:SetMouseEnabled(not hidden) end
end

function TPM:CreateGoalCard(parent, name, y)
    local card = WINDOW_MANAGER:CreateControl(name, parent, CT_BACKDROP)
    card:SetDimensions(932, 82)
    card:SetAnchor(TOPLEFT, parent, TOPLEFT, 20, y)
    card:SetCenterColor(0.045, 0.037, 0.026, 0.96)
    card:SetEdgeColor(0.42, 0.34, 0.17, 0.72)
    card:SetEdgeTexture(nil, 1, 1, 1)
    card:SetMouseEnabled(true)

    local nameLabel = WINDOW_MANAGER:CreateControl(nil, card, CT_LABEL)
    nameLabel:SetDimensions(570, 28)
    nameLabel:SetAnchor(TOPLEFT, card, TOPLEFT, 14, 9)
    nameLabel:SetFont("$(BOLD_FONT)|20")
    nameLabel:SetColor(0.90, 0.82, 0.60, 1)
    nameLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    nameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    card.nameLabel = nameLabel

    local percent = WINDOW_MANAGER:CreateControl(nil, card, CT_LABEL)
    percent:SetDimensions(120, 30)
    percent:SetAnchor(TOPRIGHT, card, TOPRIGHT, -14, 8)
    percent:SetFont("$(ANTIQUE_FONT)|26")
    percent:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    percent:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    card.percentLabel = percent

    local detail = WINDOW_MANAGER:CreateControl(nil, card, CT_LABEL)
    detail:SetDimensions(710, 28)
    detail:SetAnchor(TOPLEFT, card, TOPLEFT, 14, 42)
    detail:SetFont("$(MEDIUM_FONT)|16")
    detail:SetColor(0.70, 0.67, 0.60, 1)
    detail:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    detail:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    card.detailLabel = detail

    local open = WINDOW_MANAGER:CreateControl(nil, card, CT_LABEL)
    open:SetDimensions(190, 26)
    open:SetAnchor(BOTTOMRIGHT, card, BOTTOMRIGHT, -14, -10)
    open:SetFont("$(BOLD_FONT)|16")
    open:SetColor(0.90, 0.72, 0.42, 1)
    open:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    open:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    card.openLabel = open

    card:SetHandler("OnMouseEnter", function(c)
        if TPM:IsStatisticsDarkDesign() then c:SetCenterColor(0,0,0,.46) else c:SetCenterColor(0.11, 0.085, 0.040, 0.98) end
        local data = c.goalData
        if data then
            local lines = { TPM:L("GOAL_TOOLTIP_HEADER", data.percent or 0, data.remaining or 0) }
            for _, item in ipairs(data.missing or {}) do
                lines[#lines + 1] = TPM:L("GOAL_TOOLTIP_LINE", item.name or "", item.remaining or 0)
            end
            TPM:ShowStatisticsHoverTooltip(data.name or "", table.concat(lines, "\n"), c)
        end
    end)
    card:SetHandler("OnMouseExit", function(c)
        if TPM:IsStatisticsDarkDesign() then c:SetCenterColor(0,0,0,.34) else c:SetCenterColor(0.045, 0.037, 0.026, 0.96) end
        TPM:HideStatisticsHoverTooltips()
    end)
    card:SetHandler("OnMouseUp", function(c, button, upInside)
        if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT then return end
        if c.mapId and c.mapId > 0 then
            TPM:OpenWorldMapFromStatistics(c.mapId)
        end
    end)
    return card
end

function TPM:CreateGoalsStatisticsPage(control)
    if self.statisticsGoalsPage then return end
    local page = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "StatisticsGoalsPage", control, CT_BACKDROP)
    page:SetAnchor(TOPLEFT, control, TOPLEFT, 14, 60)
    page:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -14, -55)
    page:SetCenterColor(0.075, 0.061, 0.038, 1.00)
    page:SetEdgeColor(0.26, 0.21, 0.12, 0.90)
    page:SetEdgeTexture(nil, 1, 1, 1)
    page:SetMouseEnabled(true)
    page:SetHidden(true)
    self.statisticsGoalsPage = page

    local title = WINDOW_MANAGER:CreateControl(nil, page, CT_LABEL)
    title:SetDimensions(920, 34)
    title:SetAnchor(TOPLEFT, page, TOPLEFT, 20, 14)
    title:SetFont("ZoFontWinH3")
    title:SetColor(0.90, 0.77, 0.34, 1)
    title:SetHidden(true)
    self.statisticsGoalsTitle = title

    local subtitle = WINDOW_MANAGER:CreateControl(nil, page, CT_LABEL)
    subtitle:SetDimensions(920, 24)
    subtitle:SetAnchor(TOPLEFT, page, TOPLEFT, 20, 16)
    subtitle:SetFont("$(MEDIUM_FONT)|17")
    subtitle:SetColor(0.70, 0.67, 0.60, 1)
    self.statisticsGoalsSubtitle = subtitle

    self.statisticsGoalModeButtons = {}
    local labels = { near = "GOAL_MODE_NEAR", recommended = "GOAL_MODE_RECOMMENDED" }
    for i, mode in ipairs(GOAL_PLANNER_MODES) do
        local button = WINDOW_MANAGER:CreateControl(nil, page, CT_BUTTON)
        button:SetDimensions(190, 30)
        button:SetAnchor(TOPLEFT, page, TOPLEFT, 20 + ((i - 1) * 200), 52)
        button:SetFont("$(BOLD_FONT)|16")
        button:SetNormalFontColor(0.78, 0.72, 0.58, 1)
        button:SetMouseOverFontColor(1.00, 0.84, 0.36, 1)
        button:SetPressedFontColor(0.90, 0.72, 0.28, 1)
        button.mode = mode
        button.labelKey = labels[mode]
        button:SetHandler("OnClicked", function(btn) TPM:SetGoalPlannerMode(btn.mode) end)
        self.statisticsGoalModeButtons[#self.statisticsGoalModeButtons + 1] = button
    end

    local categoryButton = WINDOW_MANAGER:CreateControl(nil, page, CT_BUTTON)
    categoryButton:SetDimensions(300, 30)
    categoryButton:SetAnchor(TOPRIGHT, page, TOPRIGHT, -20, 52)
    categoryButton:SetFont("$(BOLD_FONT)|16")
    categoryButton:SetNormalFontColor(0.78, 0.72, 0.58, 1)
    categoryButton:SetMouseOverFontColor(1.00, 0.84, 0.36, 1)
    categoryButton:SetPressedFontColor(0.90, 0.72, 0.28, 1)
    categoryButton:SetHandler("OnClicked", function() TPM:CycleGoalPlannerCategory(1) end)
    self.statisticsGoalCategoryButton = categoryButton

    self.statisticsGoalCards = {}
    for i = 1, 5 do
        self.statisticsGoalCards[i] = self:CreateGoalCard(page, ADDON_NAME .. "GoalCard" .. tostring(i), 94 + ((i - 1) * 90))
    end

    local note = WINDOW_MANAGER:CreateControl(nil, page, CT_LABEL)
    note:SetDimensions(930, 42)
    note:SetAnchor(BOTTOMLEFT, page, BOTTOMLEFT, 20, -18)
    note:SetFont("$(MEDIUM_FONT)|15")
    note:SetColor(0.65, 0.62, 0.55, 1)
    note:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    note:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.statisticsGoalsNote = note
end

function TPM:RefreshGoalsStatisticsPage()
    if not self.statisticsGoalsPage or self.statisticsGoalsPage:IsHidden() then return end
    local mode = self.saved and self.saved.goalPlannerMode or "near"
    local category = self:GetGoalPlannerCategoryDefinition()
    self.statisticsGoalsTitle:SetText(self:L("GOAL_PAGE_TITLE"))
    self.statisticsGoalsSubtitle:SetText(self:L("GOAL_PAGE_SUBTITLE"))
    self.statisticsGoalsNote:SetText(self:L("GOAL_PAGE_NOTE"))
    for _, button in ipairs(self.statisticsGoalModeButtons or {}) do
        local label = self:L(button.labelKey)
        if button.mode == mode then label = "|cE6C45C" .. label .. "|r" end
        button:SetText(label)
    end
    if self.statisticsGoalCategoryButton then
        self.statisticsGoalCategoryButton:SetText(self:L("GOAL_CATEGORY_FILTER", self:L(category.labelKey)))
    end
    local rows = self:GetGoalPlannerData(mode, category.key)
    for i, card in ipairs(self.statisticsGoalCards or {}) do
        local row = rows[i]
        card:SetHidden(row == nil)
        if row then
            card.mapId = row.mapId
            card.zoneId = row.zoneId
            card.goalData = row
            card.nameLabel:SetText(row.name)
            card.percentLabel:SetText(string.format("|c%s%d%%|r", self:GetStatisticsPercentTextColor(row.percent), row.percent))
            card.detailLabel:SetText(row.detail)
            card.openLabel:SetText(self:L("GOAL_OPEN_MAP", row.remaining))
        else
            card.mapId, card.zoneId, card.goalData = nil, nil, nil
        end
    end
end

function TPM:CreateHistorySummaryCard(parent, name, x, width)
    local card = WINDOW_MANAGER:CreateControl(name, parent, CT_BACKDROP)
    card:SetDimensions(width, 74)
    card:SetAnchor(TOPLEFT, parent, TOPLEFT, x, 82)
    card:SetCenterColor(0.028, 0.024, 0.018, 0.985)
    card:SetEdgeColor(0.48, 0.36, 0.12, 0.82)
    card:SetEdgeTexture(nil, 1, 1, 1)
    local title = WINDOW_MANAGER:CreateControl(nil, card, CT_LABEL)
    title:SetDimensions(width - 16, 22)
    title:SetAnchor(TOPLEFT, card, TOPLEFT, 8, 7)
    title:SetFont("$(BOLD_FONT)|15")
    title:SetColor(0.82, 0.78, 0.70, 1)
    title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    local value = WINDOW_MANAGER:CreateControl(nil, card, CT_LABEL)
    value:SetDimensions(width - 16, 34)
    value:SetAnchor(TOPLEFT, card, TOPLEFT, 8, 30)
    value:SetFont("$(ANTIQUE_FONT)|25")
    value:SetColor(0.95, 0.82, 0.36, 1)
    value:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    return { control = card, title = title, value = value }
end

function TPM:CreateHistoryStatisticsPage(control)
    if self.statisticsHistoryPage then return end
    local page = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "StatisticsHistoryPage", control, CT_BACKDROP)
    page:SetAnchor(TOPLEFT, control, TOPLEFT, 14, 60)
    page:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -14, -55)
    page:SetCenterColor(0.040, 0.035, 0.026, 1.00)
    page:SetEdgeColor(0.44, 0.34, 0.10, 0.95)
    page:SetEdgeTexture(nil, 1, 1, 1)
    page:SetMouseEnabled(true)
    page:SetHidden(true)
    self.statisticsHistoryPage = page

    local title = WINDOW_MANAGER:CreateControl(nil, page, CT_LABEL)
    title:SetDimensions(380, 34)
    title:SetAnchor(TOPLEFT, page, TOPLEFT, 20, 14)
    title:SetFont("ZoFontWinH3")
    title:SetColor(0.90, 0.77, 0.34, 1)
    title:SetHidden(true)
    self.statisticsHistoryTitle = title

    local prev = WINDOW_MANAGER:CreateControl(nil, page, CT_BUTTON)
    prev:SetDimensions(42, 28)
    prev:SetAnchor(TOPLEFT, page, TOPLEFT, 145, 15)
    prev:SetFont("$(BOLD_FONT)|22")
    prev:SetText("<")
    prev:SetHandler("OnClicked", function() TPM:CycleHistoryMetric(-1) end)
    prev:SetHidden(true)
    prev:SetMouseEnabled(false)
    self.statisticsHistoryPrevButton = prev

    local metric = WINDOW_MANAGER:CreateControl(nil, page, CT_LABEL)
    metric:SetDimensions(760, 30)
    metric:SetAnchor(TOP, page, TOP, 0, 15)
    metric:SetFont("$(BOLD_FONT)|18")
    metric:SetColor(0.92, 0.82, 0.55, 1)
    metric:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    self.statisticsHistoryMetricLabel = metric

    local next = WINDOW_MANAGER:CreateControl(nil, page, CT_BUTTON)
    next:SetDimensions(42, 28)
    next:SetAnchor(TOPLEFT, page, TOPLEFT, 748, 15)
    next:SetFont("$(BOLD_FONT)|22")
    next:SetText(">")
    next:SetHandler("OnClicked", function() TPM:CycleHistoryMetric(1) end)
    next:SetHidden(true)
    next:SetMouseEnabled(false)
    self.statisticsHistoryNextButton = next

    self.statisticsHistoryRangeButtons = {}
    self.statisticsHistoryRangeBackdrops = {}
    for i, days in ipairs({7, 30, 90, 365, 730}) do
        local bg = WINDOW_MANAGER:CreateControl(nil, page, CT_BACKDROP)
        bg:SetDimensions(66, 28)
        bg:SetAnchor(TOPRIGHT, page, TOPRIGHT, -18 - ((5 - i) * 68), 48)
        bg:SetCenterColor(0.035, 0.031, 0.025, 0.96)
        bg:SetEdgeColor(0.30, 0.25, 0.15, 0.95)
        bg:SetEdgeTexture(nil, 1, 1, 1)
        self.statisticsHistoryRangeBackdrops[i] = bg

        local button = WINDOW_MANAGER:CreateControl(nil, page, CT_BUTTON)
        button:SetDimensions(66, 28)
        button:SetAnchor(CENTER, bg, CENTER, 0, 0)
        button:SetFont("$(BOLD_FONT)|15")
        button.days = days
        button:SetHandler("OnClicked", function(btn) TPM:SetHistoryRange(btn.days) end)
        self.statisticsHistoryRangeButtons[#self.statisticsHistoryRangeButtons + 1] = button
    end

    local pveHeading = WINDOW_MANAGER:CreateControl(nil, page, CT_LABEL)
    pveHeading:SetDimensions(440, 28)
    pveHeading:SetAnchor(TOPLEFT, page, TOPLEFT, 20, 48)
    pveHeading:SetFont("$(BOLD_FONT)|18")
    pveHeading:SetColor(0.55, 0.82, 0.24, 1)
    pveHeading:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    pveHeading:SetText(self:L("HISTORY_PVE_HEADING"))
    pveHeading:SetHidden(true)
    self.statisticsCombatPveHeading = pveHeading

    local bossBadge = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "CombatBossBadge", page, CT_BACKDROP)
    bossBadge:SetDimensions(174, 28)
    bossBadge:SetAnchor(TOPLEFT, page, TOPLEFT, 286, 48)
    bossBadge:SetCenterColor(0.045, 0.036, 0.020, 0.98)
    bossBadge:SetEdgeColor(0.82, 0.62, 0.16, 0.82)
    bossBadge:SetEdgeTexture(nil, 1, 1, 1)
    bossBadge:SetHidden(true)
    bossBadge:SetMouseEnabled(false)

    local bossIcon = WINDOW_MANAGER:CreateControl(nil, bossBadge, CT_TEXTURE)
    bossIcon:SetDimensions(24, 24)
    bossIcon:SetAnchor(LEFT, bossBadge, LEFT, 5, 0)
    bossIcon:SetTexture("EsoUI/Art/LFG/Gamepad/LFG_activityIcon_veteranDungeon.dds")
    -- Preserve the original ESO artwork instead of recoloring the texture itself.
    bossIcon:SetColor(1, 1, 1, 1)

    local bossText = WINDOW_MANAGER:CreateControl(nil, bossBadge, CT_LABEL)
    bossText:SetDimensions(136, 24)
    bossText:SetAnchor(LEFT, bossIcon, RIGHT, 6, 0)
    bossText:SetFont("$(BOLD_FONT)|14")
    bossText:SetColor(0.92, 0.84, 0.62, 1)
    bossText:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    bossText:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.statisticsCombatBossBadge = bossBadge
    self.statisticsCombatBossText = bossText

    -- Leave room in the PvE heading for the compact boss counter.
    pveHeading:SetDimensions(250, 28)

    local pvpHeading = WINDOW_MANAGER:CreateControl(nil, page, CT_LABEL)
    pvpHeading:SetDimensions(440, 28)
    pvpHeading:SetAnchor(TOPRIGHT, page, TOPRIGHT, -20, 48)
    pvpHeading:SetFont("$(BOLD_FONT)|18")
    pvpHeading:SetColor(0.34, 0.67, 0.95, 1)
    pvpHeading:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    pvpHeading:SetText(self:L("HISTORY_PVP_HEADING"))
    pvpHeading:SetHidden(true)
    self.statisticsCombatPvpHeading = pvpHeading

    self.statisticsHistorySummaryCards = {
        current = self:CreateHistorySummaryCard(page, ADDON_NAME .. "HistoryCurrent", 20, 218),
        change = self:CreateHistorySummaryCard(page, ADDON_NAME .. "HistoryChange", 252, 218),
        income = self:CreateHistorySummaryCard(page, ADDON_NAME .. "HistoryIncome", 20, 142),
        expenses = self:CreateHistorySummaryCard(page, ADDON_NAME .. "HistoryExpenses", 174, 142),
        net = self:CreateHistorySummaryCard(page, ADDON_NAME .. "HistoryNet", 328, 142),
        high = self:CreateHistorySummaryCard(page, ADDON_NAME .. "HistoryHigh", 484, 218),
        low = self:CreateHistorySummaryCard(page, ADDON_NAME .. "HistoryLow", 716, 236),
    }

    -- 3.4.18: Prefer original ESO UI artwork for the combat dashboard.
    -- These textures ship with the game and therefore match the native UI.
    local combatAssets = {
        current = "EsoUI/Art/LFG/LFG_dps_down_no_glow_64.dds",
        change = "EsoUI/Art/DeathRecap/deathRecap_killingBlow_icon.dds",
        high = "EsoUI/Art/Battlegrounds/Gamepad/gp_battlegrounds_tabIcon_deathmatch.dds",
        low = "EsoUI/Art/DeathRecap/deathRecap_killingBlow_icon.dds",
    }
    self.statisticsCombatCardExtras = {}
    local combatAccent = {
        current = {0.49,0.78,0.27},
        change  = {0.94,0.31,0.24},
        high    = {0.36,0.62,0.91},
        low     = {0.94,0.31,0.24},
    }
    for key, texturePath in pairs(combatAssets) do
        local card = self.statisticsHistorySummaryCards[key]
        local accentColor = combatAccent[key] or {0.90,0.77,0.34}
        local accent = WINDOW_MANAGER:CreateControl(nil, card.control, CT_BACKDROP)
        accent:SetDimensions(4, 82)
        accent:SetAnchor(LEFT, card.control, LEFT, 0, 0)
        accent:SetCenterColor(accentColor[1], accentColor[2], accentColor[3], 0.92)
        accent:SetEdgeColor(0,0,0,0)
        accent:SetHidden(true)

        local iconBack = WINDOW_MANAGER:CreateControl(nil, card.control, CT_BACKDROP)
        iconBack:SetDimensions(72, 72)
        iconBack:SetAnchor(LEFT, card.control, LEFT, 12, 0)
        iconBack:SetCenterColor(accentColor[1] * 0.10, accentColor[2] * 0.10, accentColor[3] * 0.10, 0.98)
        iconBack:SetEdgeColor(accentColor[1], accentColor[2], accentColor[3], 0.72)
        iconBack:SetEdgeTexture(nil, 1, 1, 1)
        iconBack:SetHidden(true)

        local icon = WINDOW_MANAGER:CreateControl(nil, card.control, CT_TEXTURE)
        icon:SetDimensions(66, 66)
        icon:SetAnchor(CENTER, iconBack, CENTER, 0, 0)
        icon:SetTexture(texturePath)
        icon:SetColor(1, 1, 1, 1)
        icon:SetHidden(true)

        local delta = WINDOW_MANAGER:CreateControl(nil, card.control, CT_LABEL)
        delta:SetDimensions(128, 22)
        delta:SetAnchor(BOTTOMRIGHT, card.control, BOTTOMRIGHT, -9, -8)
        delta:SetFont("$(BOLD_FONT)|14")
        delta:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        delta:SetHidden(true)
        self.statisticsCombatCardExtras[key] = { icon = icon, iconBack = iconBack, accent = accent, delta = delta }
    end

    local chart = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "HistoryChart", page, CT_BACKDROP)
    chart:SetDimensions(932, 292)
    chart:SetAnchor(TOPLEFT, page, TOPLEFT, 20, 198)
    chart:SetCenterColor(0.014, 0.014, 0.013, 0.995)
    chart:SetEdgeColor(0.52, 0.39, 0.10, 0.98)
    chart:SetEdgeTexture(nil, 1, 1, 1)
    self.statisticsHistoryChart = chart

    local chartTitle = WINDOW_MANAGER:CreateControl(nil, chart, CT_LABEL)
    chartTitle:SetDimensions(500, 28)
    chartTitle:SetAnchor(TOP, chart, TOP, 0, 10)
    chartTitle:SetFont("$(BOLD_FONT)|19")
    chartTitle:SetColor(0.90, 0.77, 0.34, 1)
    chartTitle:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    chartTitle:SetHidden(true)
    self.statisticsCombatChartTitle = chartTitle

    self.statisticsHistoryGrid = {}
    for i = 1, 4 do
        local line = WINDOW_MANAGER:CreateControl(nil, chart, CT_BACKDROP)
        line:SetDimensions(872, 1)
        line:SetAnchor(TOPLEFT, chart, TOPLEFT, 30, 66 + ((i - 1) * 61))
        line:SetCenterColor(0.32, 0.29, 0.23, 0.34)
        line:SetEdgeColor(0,0,0,0)
        self.statisticsHistoryGrid[#self.statisticsHistoryGrid + 1] = line
    end

    self.statisticsHistorySegments = {}
    self.statisticsHistoryPoints = {}
    for i = 1, HISTORY_MAX_CHART_POINTS do
        if i < HISTORY_MAX_CHART_POINTS then
            local segment = WINDOW_MANAGER:CreateControl(nil, chart, CT_LINE)
            segment:SetTexture("EsoUI/Art/Champion/champion_star_link.dds")
            segment:SetColor(0.90, 0.77, 0.34, 1)
            if segment.SetThickness then segment:SetThickness(3) end
            segment:SetHidden(true)
            self.statisticsHistorySegments[i] = segment
        end
        local dot = WINDOW_MANAGER:CreateControl(nil, chart, CT_TEXTURE)
        dot:SetTexture("EsoUI/Art/Miscellaneous/progressbar_genericFill_tall.dds")
        dot:SetDimensions(7, 7)
        dot:SetColor(0.95, 0.82, 0.36, 1)
        dot:SetHidden(true)
        self.statisticsHistoryPoints[i] = dot
    end

    local empty = WINDOW_MANAGER:CreateControl(nil, chart, CT_LABEL)
    empty:SetDimensions(880, 60)
    empty:SetAnchor(CENTER, chart, CENTER, 0, 12)
    empty:SetFont("$(MEDIUM_FONT)|18")
    empty:SetColor(0.68, 0.65, 0.58, 1)
    empty:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    empty:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.statisticsHistoryEmpty = empty

    local minLabel = WINDOW_MANAGER:CreateControl(nil, chart, CT_LABEL)
    minLabel:SetDimensions(90, 22)
    minLabel:SetAnchor(BOTTOMLEFT, chart, BOTTOMLEFT, 10, -28)
    minLabel:SetFont("$(MEDIUM_FONT)|13")
    minLabel:SetColor(0.56, 0.54, 0.50, 1)
    self.statisticsHistoryMinAxis = minLabel

    local maxLabel = WINDOW_MANAGER:CreateControl(nil, chart, CT_LABEL)
    maxLabel:SetDimensions(90, 22)
    maxLabel:SetAnchor(TOPLEFT, chart, TOPLEFT, 10, 50)
    maxLabel:SetFont("$(MEDIUM_FONT)|13")
    maxLabel:SetColor(0.56, 0.54, 0.50, 1)
    self.statisticsHistoryMaxAxis = maxLabel

    local startAxis = WINDOW_MANAGER:CreateControl(nil, chart, CT_LABEL)
    startAxis:SetDimensions(180, 18)
    startAxis:SetAnchor(BOTTOMLEFT, chart, BOTTOMLEFT, 82, -8)
    startAxis:SetFont("$(MEDIUM_FONT)|12")
    startAxis:SetColor(0.56, 0.54, 0.50, 1)
    startAxis:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    self.statisticsHistoryStartAxis = startAxis

    local endAxis = WINDOW_MANAGER:CreateControl(nil, chart, CT_LABEL)
    endAxis:SetDimensions(180, 18)
    endAxis:SetAnchor(BOTTOMRIGHT, chart, BOTTOMRIGHT, -16, -8)
    endAxis:SetFont("$(MEDIUM_FONT)|12")
    endAxis:SetColor(0.56, 0.54, 0.50, 1)
    endAxis:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.statisticsHistoryEndAxis = endAxis

    -- 3.1.7: clearer chart axes. Five horizontal value labels and up to five
    -- calendar labels make PvE/PvP, Gold and Playtime readable at a glance.
    self.statisticsHistoryYTicks = self.statisticsHistoryYTicks or {}
    for i = 1, 5 do
        local tick = WINDOW_MANAGER:CreateControl(nil, chart, CT_LABEL)
        tick:SetDimensions(54, 18)
        tick:SetFont("$(MEDIUM_FONT)|12")
        tick:SetColor(0.62, 0.60, 0.55, 1)
        tick:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        self.statisticsHistoryYTicks[i] = tick
    end
    self.statisticsHistoryXTicks = self.statisticsHistoryXTicks or {}
    for i = 1, 5 do
        local tick = WINDOW_MANAGER:CreateControl(nil, chart, CT_LABEL)
        tick:SetDimensions(118, 18)
        tick:SetFont("$(MEDIUM_FONT)|11")
        tick:SetColor(0.62, 0.60, 0.55, 1)
        tick:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        self.statisticsHistoryXTicks[i] = tick
    end

    local session = WINDOW_MANAGER:CreateControl(nil, page, CT_BACKDROP)
    session:SetDimensions(932, 112)
    session:SetAnchor(TOPLEFT, page, TOPLEFT, 20, 500)
    session:SetCenterColor(0.028, 0.026, 0.021, 0.98)
    session:SetEdgeColor(0.44, 0.34, 0.10, 0.95)
    session:SetEdgeTexture(nil, 1, 1, 1)
    self.statisticsHistorySessionBox = session

    local sessionTitle = WINDOW_MANAGER:CreateControl(nil, session, CT_LABEL)
    sessionTitle:SetDimensions(430, 25)
    sessionTitle:SetAnchor(TOPLEFT, session, TOPLEFT, 14, 8)
    sessionTitle:SetFont("$(BOLD_FONT)|18")
    sessionTitle:SetColor(0.90, 0.77, 0.34, 1)
    self.statisticsHistorySessionTitle = sessionTitle

    local activityImage = WINDOW_MANAGER:CreateControl(nil, session, CT_TEXTURE)
    activityImage:SetDimensions(164, 72)
    activityImage:SetAnchor(TOPLEFT, session, TOPLEFT, 14, 34)
    activityImage:SetTexture("NagaMapaCompleto/art/activity_dungeon.dds")
    activityImage:SetHidden(true)
    self.statisticsHistoryActivityImage = activityImage

    local sessionText = WINDOW_MANAGER:CreateControl(nil, session, CT_LABEL)
    sessionText:SetDimensions(690, 68)
    sessionText:SetAnchor(TOPLEFT, session, TOPLEFT, 14, 34)
    sessionText:SetFont("$(MEDIUM_FONT)|15")
    sessionText:SetColor(0.78, 0.74, 0.65, 1)
    sessionText:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    sessionText:SetVerticalAlignment(TEXT_ALIGN_TOP)
    self.statisticsHistorySessionText = sessionText

    local divider = WINDOW_MANAGER:CreateControl(nil, session, CT_BACKDROP)
    divider:SetDimensions(1, 94)
    divider:SetAnchor(TOPLEFT, session, TOPLEFT, 456, 9)
    divider:SetCenterColor(0.44, 0.34, 0.10, 0.75)
    divider:SetEdgeColor(0,0,0,0)
    divider:SetHidden(true)
    self.statisticsCombatActivityDivider = divider

    local examplesTitle = WINDOW_MANAGER:CreateControl(nil, session, CT_LABEL)
    examplesTitle:SetDimensions(438, 24)
    examplesTitle:SetAnchor(TOPLEFT, session, TOPLEFT, 476, 8)
    examplesTitle:SetFont("$(BOLD_FONT)|17")
    examplesTitle:SetColor(0.90, 0.77, 0.34, 1)
    examplesTitle:SetText(self:L("HISTORY_MORE_ACTIVITIES"))
    examplesTitle:SetHidden(true)
    self.statisticsCombatExamplesTitle = examplesTitle

    self.statisticsCombatRecentRows = {}
    for i = 1, 3 do
        local row = WINDOW_MANAGER:CreateControl(nil, session, CT_LABEL)
        row:SetDimensions(438, 22)
        row:SetAnchor(TOPLEFT, session, TOPLEFT, 476, 35 + ((i - 1) * 23))
        row:SetFont("$(MEDIUM_FONT)|14")
        row:SetColor(0.78, 0.74, 0.65, 1)
        row:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        row:SetHidden(true)
        self.statisticsCombatRecentRows[i] = row
    end

    local hint = WINDOW_MANAGER:CreateControl(nil, page, CT_LABEL)
    hint:SetDimensions(900, 18)
    hint:SetAnchor(BOTTOMLEFT, page, BOTTOMLEFT, 14, -4)
    hint:SetFont("$(MEDIUM_FONT)|13")
    hint:SetColor(0.60, 0.58, 0.52, 1)
    hint:SetText("")
    hint:SetHidden(true)
    self.statisticsCombatHint = hint
end

-- 3.1.0 combat-dashboard helpers ------------------------------------------------
function TPM:CreateCombatHistoryLineSet(chart, suffix, r, g, b)
    local set = { segments = {}, points = {}, color = {r,g,b} }
    for i = 1, HISTORY_MAX_CHART_POINTS do
        if i < HISTORY_MAX_CHART_POINTS then
            local segment = WINDOW_MANAGER:CreateControl(nil, chart, CT_LINE)
            segment:SetTexture("EsoUI/Art/Champion/champion_star_link.dds")
            segment:SetColor(r,g,b,1)
            if segment.SetThickness then segment:SetThickness(2) end
            segment:SetHidden(true)
            set.segments[i] = segment
        end
        local dot = WINDOW_MANAGER:CreateControl(nil, chart, CT_TEXTURE)
        dot:SetTexture("EsoUI/Art/Miscellaneous/progressbar_genericFill_tall.dds")
        dot:SetDimensions(7,7)
        dot:SetColor(r,g,b,1)
        dot:SetHidden(true)
        set.points[i] = dot
    end
    return set
end

function TPM:EnsureCombatDashboardControls()
    if self.statisticsCombatLegendLeft then return end
    local chart = self.statisticsHistoryChart
    if not chart then return end
    self.statisticsCombatLineSets = {
        pveKills = { segments=self.statisticsHistorySegments, points=self.statisticsHistoryPoints, color={0.49,0.78,0.27} },
        pveDeaths = self:CreateCombatHistoryLineSet(chart, "PveDeaths", 0.94,0.31,0.24),
        pvpKills = self:CreateCombatHistoryLineSet(chart, "PvpKills", 0.36,0.62,0.91),
        pvpDeaths = self:CreateCombatHistoryLineSet(chart, "PvpDeaths", 0.90,0.24,0.20),
    }
    for _, c in ipairs(self.statisticsHistorySegments or {}) do c:SetColor(0.49,0.78,0.27,1) end
    for _, c in ipairs(self.statisticsHistoryPoints or {}) do c:SetColor(0.49,0.78,0.27,1) end

    local left = WINDOW_MANAGER:CreateControl(nil, chart, CT_LABEL)
    left:SetDimensions(360,22); left:SetAnchor(TOPLEFT, chart, TOPLEFT, 18, 38)
    left:SetFont("$(MEDIUM_FONT)|14"); left:SetColor(0.84,0.80,0.70,1)
    left:SetText(self:L("HISTORY_COMBAT_LEGEND_PVE"))
    left:SetHidden(true)
    self.statisticsCombatLegendLeft = left

    local right = WINDOW_MANAGER:CreateControl(nil, chart, CT_LABEL)
    right:SetDimensions(360,22); right:SetAnchor(TOPRIGHT, chart, TOPRIGHT, -18, 38)
    right:SetFont("$(MEDIUM_FONT)|14"); right:SetColor(0.84,0.80,0.70,1)
    right:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    right:SetText(self:L("HISTORY_COMBAT_LEGEND_PVP"))
    right:SetHidden(true)
    self.statisticsCombatLegendRight = right
end

function TPM:SetCombatDashboardVisible(visible)
    local show = visible == true
    if self.statisticsCombatPveHeading then self.statisticsCombatPveHeading:SetHidden(not show) end
    if self.statisticsCombatBossBadge then self.statisticsCombatBossBadge:SetHidden(not show) end
    if self.statisticsCombatPvpHeading then self.statisticsCombatPvpHeading:SetHidden(not show) end
    -- 3.4.9: the PvE/PvP page is a lifetime dashboard, not a history chart.
    if self.statisticsCombatChartTitle then self.statisticsCombatChartTitle:SetHidden(true) end
    if self.statisticsCombatLegendLeft then self.statisticsCombatLegendLeft:SetHidden(true) end
    if self.statisticsCombatLegendRight then self.statisticsCombatLegendRight:SetHidden(true) end
    if self.statisticsHistoryActivityImage then self.statisticsHistoryActivityImage:SetHidden(true) end
    if self.statisticsCombatActivityDivider then self.statisticsCombatActivityDivider:SetHidden(not show) end
    if self.statisticsCombatExamplesTitle then self.statisticsCombatExamplesTitle:SetHidden(true) end
    if self.statisticsCombatActivityLogScroll then self.statisticsCombatActivityLogScroll:SetHidden(not show) end
    if self.statisticsCombatActivityLogCount then self.statisticsCombatActivityLogCount:SetHidden(not show) end
    if self.statisticsCombatActivityLogClearButton then self.statisticsCombatActivityLogClearButton:SetHidden(not show) end
    if self.statisticsCombatActivityLogInfoButton then self.statisticsCombatActivityLogInfoButton:SetHidden(not show) end
    if self.statisticsCombatKillLogScroll then self.statisticsCombatKillLogScroll:SetHidden(not show) end
    if self.statisticsCombatKillLogCount then self.statisticsCombatKillLogCount:SetHidden(not show) end
    if self.statisticsCombatKillLogClearButton then self.statisticsCombatKillLogClearButton:SetHidden(not show) end
    if self.statisticsCombatKillLogInfoButton then self.statisticsCombatKillLogInfoButton:SetHidden(not show) end
    if self.statisticsCombatActivityRightTitle then self.statisticsCombatActivityRightTitle:SetHidden(not show) end
    if self.statisticsCombatKillLogEmpty then self.statisticsCombatKillLogEmpty:SetHidden(not show) end
    if self.statisticsCombatActivityLogEmpty then self.statisticsCombatActivityLogEmpty:SetHidden(not show) end
    if self.statisticsCombatHint then self.statisticsCombatHint:SetHidden(true) end
    for _, row in ipairs(self.statisticsCombatRecentRows or {}) do row:SetHidden(true) end
    for _, extra in pairs(self.statisticsCombatCardExtras or {}) do
        if extra.icon then extra.icon:SetHidden(not show) end
        if extra.iconBack then extra.iconBack:SetHidden(not show) end
        if extra.accent then extra.accent:SetHidden(not show) end
        if extra.delta then extra.delta:SetHidden(true) end
    end
end

function TPM:GetRecentSessionSummaries(limit)
    local store = self:GetHistoryStore()
    local activities = store and store.activities or nil
    local result = {}
    limit = math.max(1, tonumber(limit) or 4)

    -- Only show activities we can identify reliably. Legacy dynamicEncounter
    -- rows are no longer accepted; world events come exclusively from the
    -- participation-based tracker.
    if type(activities) == "table" then
        for i = #activities, 1, -1 do
            local item = activities[i]
            if type(item) == "table" and self:IsPersistentTrackedActivityKind(item.activityKind)
                and TPM_IsMeaningfulDynamicEncounter(item) then
                result[#result + 1] = item
                if #result >= limit then break end
            end
        end
    end
    return result
end

function TPM:GetActivityDisplayName(session)
    if not session then return self:L("HISTORY_ACTIVITY_ADVENTURE") end
    local zone = session.activityName or ""
    local kind = session.activityKind or "adventure"
    if kind ~= "quest" and not self:IsWorldEventActivityKind(kind) and zone ~= "" and type(ZO_CachedStrFormat) == "function" and _G.SI_ZONE_NAME then
        zone = ZO_CachedStrFormat(SI_ZONE_NAME, zone)
    end
    local prefix
    if kind == "quest" then prefix = self:L("HISTORY_ACTIVITY_QUEST")
    elseif kind == "killAnimal" then prefix = self:L("HISTORY_ACTIVITY_KILL_ANIMAL")
    elseif kind == "killNpc" then prefix = self:L("HISTORY_ACTIVITY_KILL_NPC")
    elseif kind == "killBoss" then prefix = self:L("HISTORY_ACTIVITY_KILL_BOSS")
    elseif kind == "killPlayer" then prefix = self:L("HISTORY_ACTIVITY_KILL_PLAYER")
    elseif kind == "battleground" then prefix = self:L("HISTORY_ACTIVITY_BATTLEGROUND")
    elseif kind == "pvp" then prefix = self:L("HISTORY_ACTIVITY_PVP")
    elseif kind == "dungeon" then prefix = self:L("HISTORY_ACTIVITY_DUNGEON")
    elseif kind == "trial" then prefix = self:L("HISTORY_ACTIVITY_TRIAL")
    elseif kind == "arena" then prefix = self:L("HISTORY_ACTIVITY_ARENA")
    elseif kind == "dolmen" then prefix = self:L("HISTORY_ACTIVITY_DOLMEN")
    elseif kind == "geyser" then prefix = self:L("HISTORY_ACTIVITY_GEYSER")
    elseif kind == "harrowstorm" then prefix = self:L("HISTORY_ACTIVITY_HARROWSTORM")
    elseif kind == "volcanicVent" then prefix = self:L("HISTORY_ACTIVITY_VOLCANIC_VENT")
    elseif kind == "dragonHunt" then prefix = self:L("HISTORY_ACTIVITY_DRAGON_HUNT")
    elseif kind == "monsterHunt" then prefix = self:L("HISTORY_ACTIVITY_MONSTER_HUNT")
    elseif kind == "mirrormoor" then prefix = self:L("HISTORY_ACTIVITY_MIRRORMOOR")
    elseif kind == "oblivionPortal" then prefix = self:L("HISTORY_ACTIVITY_OBLIVION_PORTAL")
    elseif kind == "worldEvent" or kind == "event" then prefix = self:L("HISTORY_ACTIVITY_WORLD_EVENT")
    else prefix = self:L("HISTORY_ACTIVITY_ADVENTURE") end
    if zone ~= "" then return prefix .. ": " .. zone end
    return prefix
end

function TPM:EnsureCombatProgressionControls()
    if self.statisticsCombatPlayerProgressBack or not self.statisticsPlayerProfileBox then return end
    local profile = self.statisticsPlayerProfileBox

    local function CreateProgressColumn(side, x, accent)
        local label = WINDOW_MANAGER:CreateControl(nil, profile, CT_LABEL)
        label:SetDimensions(172, 16)
        label:SetAnchor(TOPLEFT, profile, TOPLEFT, x, 57)
        label:SetFont("$(BOLD_FONT)|12")
        label:SetColor(0.92, 0.90, 0.84, 1)
        label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)

        local detail = WINDOW_MANAGER:CreateControl(nil, profile, CT_LABEL)
        detail:SetDimensions(256, 16)
        detail:SetAnchor(TOPLEFT, profile, TOPLEFT, x + 174, 57)
        detail:SetFont("$(MEDIUM_FONT)|11")
        detail:SetColor(0.76, 0.74, 0.68, 1)
        detail:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        detail:SetVerticalAlignment(TEXT_ALIGN_CENTER)

        local back = WINDOW_MANAGER:CreateControl(nil, profile, CT_BACKDROP)
        back:SetDimensions(430, 6)
        back:SetAnchor(TOPLEFT, profile, TOPLEFT, x, 75)
        back:SetCenterColor(0.025, 0.024, 0.021, 0.98)
        back:SetEdgeColor(0.28, 0.25, 0.18, 0.85)
        back:SetEdgeTexture(nil, 1, 1, 1)

        local fill = WINDOW_MANAGER:CreateControl(nil, back, CT_BACKDROP)
        fill:SetDimensions(1, 4)
        fill:SetAnchor(LEFT, back, LEFT, 1, 0)
        fill:SetCenterColor(accent[1], accent[2], accent[3], 0.94)
        fill:SetEdgeColor(0, 0, 0, 0)
        fill.TPMMaxWidth = 428

        return label, detail, back, fill
    end

    self.statisticsCombatPlayerProgressLabel,
    self.statisticsCombatPlayerProgressDetail,
    self.statisticsCombatPlayerProgressBack,
    self.statisticsCombatPlayerProgressFill = CreateProgressColumn("player", 14, {0.90, 0.74, 0.22})

    self.statisticsCombatCompanionProgressLabel,
    self.statisticsCombatCompanionProgressDetail,
    self.statisticsCombatCompanionProgressBack,
    self.statisticsCombatCompanionProgressFill = CreateProgressColumn("companion", 488, {0.46, 0.80, 0.92})
end

function TPM:SetCombatProgressBar(fill, current, maximum)
    if not fill then return end
    current = math.max(0, tonumber(current) or 0)
    maximum = math.max(0, tonumber(maximum) or 0)
    if maximum <= 0 then
        fill:SetHidden(true)
        return
    end
    fill:SetHidden(false)
    local ratio = math.max(0, math.min(1, current / maximum))
    local maxWidth = math.max(1, tonumber(fill.TPMMaxWidth) or 930)
    fill:SetWidth(math.max(1, math.floor(maxWidth * ratio)))
end

function TPM:RefreshCombatProgressionBars()
    self:EnsureCombatProgressionControls()
    local level = type(GetUnitLevel) == "function" and (tonumber(GetUnitLevel("player")) or 0) or 0
    local maxLevel = type(GetMaxLevel) == "function" and (tonumber(GetMaxLevel()) or 50) or 50
    local currentXP, maxXP, displayLevel
    if level > 0 and level < maxLevel then
        currentXP = type(GetUnitXP) == "function" and (tonumber(GetUnitXP("player")) or 0) or 0
        maxXP = type(GetUnitXPMax) == "function" and (tonumber(GetUnitXPMax("player")) or 0) or 0
        displayLevel = self:L("HISTORY_CHARACTER_LEVEL", level)
    else
        local cp = type(GetUnitChampionPoints) == "function" and (tonumber(GetUnitChampionPoints("player")) or 0)
            or (type(GetPlayerChampionPointsEarned) == "function" and (tonumber(GetPlayerChampionPointsEarned()) or 0) or 0)
        currentXP = type(GetPlayerChampionXP) == "function" and (tonumber(GetPlayerChampionXP()) or 0) or 0
        maxXP = type(GetNumChampionXPInChampionPoint) == "function" and (tonumber(GetNumChampionXPInChampionPoint(cp)) or 0) or 0
        displayLevel = self:L("HISTORY_CHARACTER_CP", cp)
    end
    local remaining = math.max(0, maxXP - currentXP)
    if self.statisticsCombatPlayerProgressLabel then self.statisticsCombatPlayerProgressLabel:SetText(displayLevel) end
    if self.statisticsCombatPlayerProgressDetail then
        self.statisticsCombatPlayerProgressDetail:SetText(self:L("HISTORY_XP_TO_NEXT", FormatNumber(currentXP), FormatNumber(maxXP), FormatNumber(remaining)))
    end
    self:SetCombatProgressBar(self.statisticsCombatPlayerProgressFill, currentXP, maxXP)

    local hasCompanion = type(HasActiveCompanion) == "function" and HasActiveCompanion()
    if hasCompanion and type(GetActiveCompanionDefId) == "function" and type(GetActiveCompanionLevelInfo) == "function" then
        local companionId = tonumber(GetActiveCompanionDefId()) or 0
        local name = type(GetCompanionName) == "function" and tostring(GetCompanionName(companionId) or "") or ""
        if type(zo_strformat) == "function" and name ~= "" then name = zo_strformat("<<C:1>>", name) end
        local companionLevel, companionXP = GetActiveCompanionLevelInfo()
        companionLevel = tonumber(companionLevel) or 0
        companionXP = tonumber(companionXP) or 0
        local companionMax = type(GetNumExperiencePointsInCompanionLevel) == "function"
            and (tonumber(GetNumExperiencePointsInCompanionLevel(companionLevel)) or 0) or 0
        local companionRemaining = math.max(0, companionMax - companionXP)
        if self.statisticsCombatCompanionProgressLabel then
            self.statisticsCombatCompanionProgressLabel:SetText(self:L("HISTORY_COMPANION_LEVEL", name ~= "" and name or self:L("HISTORY_COMPANION_GENERIC"), companionLevel))
        end
        if self.statisticsCombatCompanionProgressDetail then
            self.statisticsCombatCompanionProgressDetail:SetText(self:L("HISTORY_XP_TO_NEXT", FormatNumber(companionXP), FormatNumber(companionMax), FormatNumber(companionRemaining)))
        end
        self:SetCombatProgressBar(self.statisticsCombatCompanionProgressFill, companionXP, companionMax)
    else
        if self.statisticsCombatCompanionProgressLabel then self.statisticsCombatCompanionProgressLabel:SetText(self:L("HISTORY_COMPANION_NONE")) end
        if self.statisticsCombatCompanionProgressDetail then self.statisticsCombatCompanionProgressDetail:SetText("") end
        if self.statisticsCombatCompanionProgressFill then self.statisticsCombatCompanionProgressFill:SetHidden(true) end
    end
end

function TPM:GetCombatDifficultyVisual(item)
    local kind = item and item.activityKind or "killNpc"
    local difficulty = item and item.difficulty or nil
    if kind == "killBoss" then return "E54835", self:L("HISTORY_DIFFICULTY_BOSS") end
    if kind == "killPlayer" then return "58B9F2", self:L("HISTORY_DIFFICULTY_PLAYER") end
    if kind == "killAnimal" then return "75D64B", self:L("HISTORY_DIFFICULTY_EASY") end
    if _G.MONSTER_DIFFICULTY_DEADLY ~= nil and difficulty == _G.MONSTER_DIFFICULTY_DEADLY then return "E54835", self:L("HISTORY_DIFFICULTY_DEADLY") end
    if _G.MONSTER_DIFFICULTY_HARD ~= nil and difficulty == _G.MONSTER_DIFFICULTY_HARD then return "F29A38", self:L("HISTORY_DIFFICULTY_HARD") end
    if _G.MONSTER_DIFFICULTY_EASY ~= nil and difficulty == _G.MONSTER_DIFFICULTY_EASY then return "75D64B", self:L("HISTORY_DIFFICULTY_EASY") end
    if _G.MONSTER_DIFFICULTY_NONE ~= nil and difficulty == _G.MONSTER_DIFFICULTY_NONE then return "75D64B", self:L("HISTORY_DIFFICULTY_TRIVIAL") end
    return "E6C45C", self:L("HISTORY_DIFFICULTY_NORMAL")
end

function TPM:GetCombatLogTitle(item)
    if type(item) ~= "table" then return "" end
    local prefix
    if item.activityKind == "killAnimal" then prefix = self:L("HISTORY_ACTIVITY_KILL_ANIMAL")
    elseif item.activityKind == "killBoss" then prefix = self:L("HISTORY_ACTIVITY_KILL_BOSS")
    elseif item.activityKind == "killPlayer" then prefix = self:L("HISTORY_ACTIVITY_KILL_PLAYER")
    else prefix = self:L("HISTORY_ACTIVITY_KILL_NPC") end
    local colorHex = self:GetCombatDifficultyVisual(item)
    local target = tostring(item.activityName or "")
    if target == "" then target = "—" end
    return "|cF2F0EA" .. prefix .. ":|r |c" .. tostring(colorHex) .. target .. "|r"
end

function TPM:FormatCombatLogDetail(item)
    local colorHex, difficultyText = self:GetCombatDifficultyVisual(item)
    local xp = math.max(0, tonumber(item and item.xpEarned) or 0)
    return string.format("|cF2F0EA%s|r +%s   •   |cF2F0EA%s:|r |c%s%s|r",
        self:L("HISTORY_XP_SHORT"), FormatNumber(xp), self:L("HISTORY_DIFFICULTY"), colorHex, difficultyText)
end

function TPM:ClearCombatActivityList(isCombat)
    local store = self:GetHistoryStore()
    if not store then return end
    if isCombat then
        store.combatActivities = {}
    else
        store.activities = {}
    end
    self:RefreshCombatActivityPanel()
    local scroll = isCombat and self.statisticsCombatKillLogScroll or self.statisticsCombatActivityLogScroll
    if scroll and scroll.ResetToTop then scroll:ResetToTop() end
end

local function TPM_EnsureLogHelpTooltip()
    if TPM.statisticsLogHelpTooltip then return TPM.statisticsLogHelpTooltip end
    if not WINDOW_MANAGER or not GuiRoot then return nil end

    local tip = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "LogHelpTooltip")
    -- Width is stable; height is recalculated from localized text when shown.
    tip:SetDimensions(380, 126)
    tip:SetHidden(true)
    tip:SetMouseEnabled(false)
    tip:SetMovable(false)
    if tip.SetClampedToScreen then tip:SetClampedToScreen(true) end
    if tip.SetDrawTier and DT_HIGH then tip:SetDrawTier(DT_HIGH) end
    if tip.SetDrawLayer and DL_OVERLAY then tip:SetDrawLayer(DL_OVERLAY) end
    if tip.SetDrawLevel then tip:SetDrawLevel(10000) end

    local bg = WINDOW_MANAGER:CreateControl(nil, tip, CT_BACKDROP)
    bg:SetAnchorFill()
    bg:SetCenterColor(0.035, 0.031, 0.026, 0.98)
    bg:SetEdgeColor(0.92, 0.76, 0.14, 0.96)
    bg:SetEdgeTexture(nil, 1, 1, 1)

    local titleLabel = WINDOW_MANAGER:CreateControl(nil, tip, CT_LABEL)
    titleLabel:SetAnchor(TOPLEFT, tip, TOPLEFT, 12, 10)
    titleLabel:SetAnchor(TOPRIGHT, tip, TOPRIGHT, -12, 10)
    titleLabel:SetHeight(24)
    titleLabel:SetFont("$(BOLD_FONT)|16")
    titleLabel:SetColor(0.96, 0.84, 0.30, 1)

    local body = WINDOW_MANAGER:CreateControl(nil, tip, CT_LABEL)
    body:SetAnchor(TOPLEFT, titleLabel, BOTTOMLEFT, 0, 5)
    body:SetAnchor(TOPRIGHT, titleLabel, BOTTOMRIGHT, 0, 5)
    body:SetHeight(100)
    body:SetFont("$(MEDIUM_FONT)|13")
    body:SetColor(0.92, 0.91, 0.87, 1)

    tip.TPMTitle = titleLabel
    tip.TPMBody = body
    TPM.statisticsLogHelpTooltip = tip
    return tip
end

local function TPM_ShowLogHelpTooltip(control, title, text)
    if not control or not text or text == "" then return end
    local tip = TPM_EnsureLogHelpTooltip()
    if not tip then return end
    TPM:HideStatisticsHoverTooltips()

    tip.TPMTitle:SetText(title or "")
    tip.TPMBody:SetText(text)

    -- Re-measure after assigning translated strings. Different UI scales and
    -- languages wrap differently and must not overflow the frame.
    local titleHeight = 24
    local bodyHeight = 78
    if tip.TPMTitle.GetTextHeight then
        titleHeight = math.max(24, math.ceil(tonumber(tip.TPMTitle:GetTextHeight()) or 24))
    end
    if tip.TPMBody.GetTextHeight then
        bodyHeight = math.max(54, math.ceil(tonumber(tip.TPMBody:GetTextHeight()) or 78))
    end
    tip.TPMTitle:SetHeight(titleHeight)
    tip.TPMBody:SetHeight(bodyHeight)
    tip:SetHeight(10 + titleHeight + 5 + bodyHeight + 12)

    -- Keep every statistics-related hover panel in the same place: directly
    -- to the upper-right of the Tamriel Statistics journal.
    TPM_ArmStatisticsHoverTooltip(tip, control)
    TPM:AnchorStatisticsHoverTooltip(tip, 58)
end

local function TPM_HideLogHelpTooltip()
    local tip = TPM.statisticsLogHelpTooltip
    if tip then tip:SetHidden(true) end
end

local function TPM_CreateHeaderIconButton(parent, width, height, iconKind)
    local button = WINDOW_MANAGER:CreateControl(nil, parent, CT_BUTTON)
    button:SetDimensions(width, height)
    button:SetMouseEnabled(true)

    if iconKind == "clear" then
        -- Use ESO's native close-button art instead of a text glyph in a box.
        button:SetNormalTexture("EsoUI/Art/Buttons/closeButton_up.dds")
        button:SetPressedTexture("EsoUI/Art/Buttons/closeButton_down.dds")
        button:SetMouseOverTexture("EsoUI/Art/Buttons/closeButton_mouseOver.dds")
        if button.SetDisabledTexture then
            button:SetDisabledTexture("EsoUI/Art/Buttons/closeButton_disabled.dds")
        end
        if button.SetTextureCoords then
            button:SetTextureCoords(0, 0.625, 0, 0.625)
        end
    else
        -- LibAddonMenu and ESO themselves use this native help icon.
        local icon = WINDOW_MANAGER:CreateControl(nil, button, CT_TEXTURE)
        icon:SetDimensions(math.max(16, width - 3), math.max(16, height - 3))
        icon:SetAnchor(CENTER, button, CENTER, 0, 0)
        icon:SetTexture("EsoUI/Art/Miscellaneous/help_icon.dds")
        icon:SetColor(0.88, 0.82, 0.64, 0.92)
        icon:SetMouseEnabled(false)
        button.TPMIcon = icon
    end

    button:SetHandler("OnMouseEnter", function(selfButton)
        if selfButton.TPMIcon then
            if TPM:IsStatisticsDarkDesign() then selfButton.TPMIcon:SetColor(1,1,1,1)
            else selfButton.TPMIcon:SetColor(1.00, 0.86, 0.30, 1) end
        end
        if selfButton.TPMHelpTitle and selfButton.TPMHelpText then
            TPM_ShowLogHelpTooltip(selfButton, selfButton.TPMHelpTitle, selfButton.TPMHelpText)
        end
    end)
    button:SetHandler("OnMouseExit", function(selfButton)
        if selfButton.TPMIcon then
            if TPM:IsStatisticsDarkDesign() then selfButton.TPMIcon:SetColor(.92,.92,.92,.92)
            else selfButton.TPMIcon:SetColor(0.88, 0.82, 0.64, 0.92) end
        end
        TPM:HideStatisticsHoverTooltips()
    end)
    return button
end

function TPM:EnsureCombatActivityLogControls()
    if self.statisticsCombatActivityLogScroll or not self.statisticsHistorySessionBox then return end
    local session = self.statisticsHistorySessionBox

    if self.statisticsHistoryActivityImage then self.statisticsHistoryActivityImage:SetHidden(true) end
    if self.statisticsHistorySessionText then self.statisticsHistorySessionText:SetHidden(true) end
    if self.statisticsCombatExamplesTitle then self.statisticsCombatExamplesTitle:SetHidden(true) end
    for _, row in ipairs(self.statisticsCombatRecentRows or {}) do row:SetHidden(true) end

    -- Left: individual NPC / animal / boss / player kills.
    if self.statisticsHistorySessionTitle then
        self.statisticsHistorySessionTitle:ClearAnchors()
        self.statisticsHistorySessionTitle:SetDimensions(360, 24)
        self.statisticsHistorySessionTitle:SetAnchor(TOPLEFT, session, TOPLEFT, 14, 8)
    end

    local combatCount = WINDOW_MANAGER:CreateControl(nil, session, CT_LABEL)
    combatCount:SetDimensions(76, 22)
    combatCount:SetAnchor(TOPLEFT, session, TOPLEFT, 364, 9)
    combatCount:SetFont("$(MEDIUM_FONT)|12")
    combatCount:SetColor(0.72, 0.70, 0.65, 1)
    combatCount:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.statisticsCombatKillLogCount = combatCount

    local combatClear = TPM_CreateHeaderIconButton(session, 22, 22, "clear")
    combatClear:SetAnchor(TOPLEFT, session, TOPLEFT, 307, 7)
    combatClear.TPMHelpTitle = self:L("HISTORY_CLEAR_COMBAT_LOG")
    combatClear.TPMHelpText = self:L("HISTORY_CLEAR_TOOLTIP")
    combatClear:SetHandler("OnClicked", function()
        self:HideStatisticsHoverTooltips()
        self:ClearCombatActivityList(true)
    end)
    self.statisticsCombatKillLogClearButton = combatClear

    local combatInfo = TPM_CreateHeaderIconButton(session, 21, 21, "info")
    combatInfo:SetAnchor(TOPLEFT, session, TOPLEFT, 335, 8)
    combatInfo.TPMHelpTitle = self:L("HISTORY_LOG_INFO_TITLE")
    combatInfo.TPMHelpText = self:L("HISTORY_LOG_INFO_TOOLTIP")
    self.statisticsCombatKillLogInfoButton = combatInfo

    local divider = self.statisticsCombatActivityDivider
    if divider then
        divider:ClearAnchors()
        divider:SetDimensions(1, 326)
        divider:SetAnchor(TOP, session, TOP, 0, 38)
        divider:SetCenterColor(0.34, 0.52, 0.72, 0.74)
        divider:SetHidden(false)
    end

    local rightTitle = WINDOW_MANAGER:CreateControl(nil, session, CT_LABEL)
    rightTitle:SetDimensions(350, 24)
    rightTitle:SetAnchor(TOPLEFT, session, TOPLEFT, 480, 8)
    rightTitle:SetFont("$(BOLD_FONT)|18")
    rightTitle:SetColor(0.72, 0.82, 0.94, 1)
    self.statisticsCombatActivityRightTitle = rightTitle

    local activityCount = WINDOW_MANAGER:CreateControl(nil, session, CT_LABEL)
    activityCount:SetDimensions(76, 22)
    activityCount:SetAnchor(TOPRIGHT, session, TOPRIGHT, -14, 9)
    activityCount:SetFont("$(MEDIUM_FONT)|12")
    activityCount:SetColor(0.72, 0.70, 0.65, 1)
    activityCount:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.statisticsCombatActivityLogCount = activityCount

    local activityClear = TPM_CreateHeaderIconButton(session, 22, 22, "clear")
    activityClear:SetAnchor(TOPRIGHT, session, TOPRIGHT, -124, 7)
    activityClear.TPMHelpTitle = self:L("HISTORY_CLEAR_ACTIVITY_LOG")
    activityClear.TPMHelpText = self:L("HISTORY_CLEAR_TOOLTIP")
    activityClear:SetHandler("OnClicked", function()
        self:HideStatisticsHoverTooltips()
        self:ClearCombatActivityList(false)
    end)
    self.statisticsCombatActivityLogClearButton = activityClear

    local activityInfo = TPM_CreateHeaderIconButton(session, 21, 21, "info")
    activityInfo:SetAnchor(TOPRIGHT, session, TOPRIGHT, -96, 8)
    activityInfo.TPMHelpTitle = self:L("HISTORY_LOG_INFO_TITLE")
    activityInfo.TPMHelpText = self:L("HISTORY_LOG_INFO_TOOLTIP")
    self.statisticsCombatActivityLogInfoButton = activityInfo

    local function CreateLogScroll(name, x, width, isCombat)
        local scrollContainer = WINDOW_MANAGER:CreateControlFromVirtual(name, session, "ZO_ScrollContainer_Shared")
        scrollContainer:SetAnchor(TOPLEFT, session, TOPLEFT, x, 36)
        scrollContainer:SetDimensions(width, 330)
        local scroll = scrollContainer:GetNamedChild("Scroll")
        local child = scroll and scroll:GetNamedChild("Child") or nil
        local rows = {}
        local parent = child or session
        local rowWidth = width - 20
        for i = 1, 100 do
            local row = WINDOW_MANAGER:CreateControl(nil, parent, CT_BACKDROP)
            row:SetDimensions(rowWidth, 48)
            row:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, (i - 1) * 50)
            row:SetCenterColor(0.022, 0.021, 0.018, (i % 2 == 0) and 0.84 or 0.66)
            row:SetEdgeColor(0.25, 0.23, 0.18, 0.50)
            row:SetEdgeTexture(nil, 1, 1, 1)
            row:SetHidden(true)

            local accent = WINDOW_MANAGER:CreateControl(nil, row, CT_BACKDROP)
            accent:SetDimensions(3, 46)
            accent:SetAnchor(LEFT, row, LEFT, 0, 0)
            accent:SetEdgeColor(0, 0, 0, 0)
            row.TPMAccent = accent

            local title = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
            title:SetDimensions(rowWidth - 160, 21)
            title:SetAnchor(TOPLEFT, row, TOPLEFT, 10, 3)
            title:SetFont("$(BOLD_FONT)|13")
            title:SetColor(0.95, 0.94, 0.91, 1)
            title:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            title:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            if title.SetWrapMode and _G.TEXT_WRAP_MODE_TRUNCATE then title:SetWrapMode(TEXT_WRAP_MODE_TRUNCATE) end
            row.TPMTitle = title

            local timestamp = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
            timestamp:SetDimensions(142, 19)
            timestamp:SetAnchor(TOPRIGHT, row, TOPRIGHT, -8, 4)
            timestamp:SetFont("$(MEDIUM_FONT)|10")
            timestamp:SetColor(0.68, 0.66, 0.60, 1)
            timestamp:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
            timestamp:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            row.TPMTimestamp = timestamp

            local detail = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
            detail:SetDimensions(rowWidth - 18, 19)
            detail:SetAnchor(TOPLEFT, row, TOPLEFT, 10, 25)
            detail:SetFont("$(MEDIUM_FONT)|12")
            detail:SetColor(0.94, 0.93, 0.90, 1)
            detail:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            detail:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            row.TPMDetail = detail
            rows[i] = row
        end
        return scrollContainer, child, rows, rowWidth
    end

    self.statisticsCombatKillLogScroll,
    self.statisticsCombatKillLogScrollChild,
    self.statisticsCombatKillLogRows,
    self.statisticsCombatKillLogRowWidth = CreateLogScroll(ADDON_NAME .. "CombatKillLogScroll", 10, 450, true)

    self.statisticsCombatActivityLogScroll,
    self.statisticsCombatActivityLogScrollChild,
    self.statisticsCombatActivityLogRows,
    self.statisticsCombatActivityLogRowWidth = CreateLogScroll(ADDON_NAME .. "CombatActivityLogScroll", 472, 450, false)

    local leftEmpty = WINDOW_MANAGER:CreateControl(nil, session, CT_LABEL)
    leftEmpty:SetDimensions(400, 50)
    leftEmpty:SetAnchor(TOPLEFT, session, TOPLEFT, 28, 72)
    leftEmpty:SetFont("$(MEDIUM_FONT)|14")
    leftEmpty:SetColor(0.70, 0.69, 0.65, 1)
    leftEmpty:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    leftEmpty:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    leftEmpty:SetHidden(true)
    self.statisticsCombatKillLogEmpty = leftEmpty

    local rightEmpty = WINDOW_MANAGER:CreateControl(nil, session, CT_LABEL)
    rightEmpty:SetDimensions(400, 50)
    rightEmpty:SetAnchor(TOPLEFT, session, TOPLEFT, 492, 72)
    rightEmpty:SetFont("$(MEDIUM_FONT)|14")
    rightEmpty:SetColor(0.70, 0.69, 0.65, 1)
    rightEmpty:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    rightEmpty:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    rightEmpty:SetHidden(true)
    self.statisticsCombatActivityLogEmpty = rightEmpty
end

function TPM:GetCombatLogSummaries(limit)
    local store = self:GetHistoryStore()
    local activities = store and store.combatActivities or nil
    local result = {}
    limit = math.max(1, math.min(100, tonumber(limit) or 100))
    if type(activities) == "table" then
        for i = #activities, 1, -1 do
            local item = activities[i]
            if type(item) == "table" and self:IsCombatLogKind(item.activityKind) then
                result[#result + 1] = item
                if #result >= limit then break end
            end
        end
    end
    return result
end

function TPM:GetActivityLogSummaries(limit)
    local store = self:GetHistoryStore()
    local activities = store and store.activities or nil
    local result = {}
    limit = math.max(1, math.min(100, tonumber(limit) or 100))
    if type(activities) == "table" then
        for i = #activities, 1, -1 do
            local item = activities[i]
            if type(item) == "table" and self:IsPersistentTrackedActivityKind(item.activityKind)
                and not self:IsCombatLogKind(item.activityKind) and TPM_IsMeaningfulDynamicEncounter(item) then
                result[#result + 1] = item
                if #result >= limit then break end
            end
        end
    end
    return result
end

function TPM:GetActivityLogStyle(kind)
    if kind == "battleground" or kind == "pvp" then return { 0.24, 0.68, 0.96 } end
    if kind == "killAnimal" then return { 0.58, 0.86, 0.24 } end
    if kind == "killNpc" then return { 0.82, 0.72, 0.30 } end
    if kind == "killBoss" then return { 0.96, 0.28, 0.18 } end
    if kind == "killPlayer" then return { 0.28, 0.68, 0.96 } end
    if kind == "quest" then return { 0.90, 0.75, 0.22 } end
    if kind == "dungeon" or kind == "trial" or kind == "arena" then return { 0.55, 0.82, 0.24 } end
    if kind == "dolmen" then return { 0.72, 0.40, 0.94 } end
    if kind == "geyser" then return { 0.26, 0.78, 0.94 } end
    if kind == "harrowstorm" then return { 0.82, 0.30, 0.50 } end
    if kind == "volcanicVent" then return { 0.96, 0.48, 0.18 } end
    if kind == "dragonHunt" or kind == "monsterHunt" then return { 0.94, 0.34, 0.20 } end
    if kind == "mirrormoor" or kind == "oblivionPortal" or kind == "worldEvent" then return { 0.70, 0.54, 0.92 } end
    return { 0.78, 0.66, 0.30 }
end

function TPM:FormatActivityLogDetail(item)
    local parts = {}
    parts[#parts + 1] = string.format("|cE5C454%s|r +%s", self:L("HISTORY_GOLD_SHORT"), FormatNumber(math.max(0, tonumber(item.goldEarned) or 0)))
    parts[#parts + 1] = string.format("|c78BDF2%s|r +%s", self:L("HISTORY_XP_SHORT"), FormatNumber(math.max(0, tonumber(item.xpEarned) or 0)))

    local kind = item.activityKind or "adventure"
    if kind == "quest" then
        local reward = tostring(item.rewardName or "")
        if reward == "" then reward = "—" end
        parts[#parts + 1] = "|cC993EA" .. self:L("HISTORY_REWARD") .. ":|r " .. reward
    elseif kind == "battleground" or kind == "pvp" then
        parts[#parts + 1] = string.format("|c78BDF2%s|r %d", self:L("HISTORY_KILLS_SHORT"), math.max(0, tonumber(item.pvpKillsDelta) or 0))
        parts[#parts + 1] = string.format("|cE66A5A%s|r %d", self:L("HISTORY_DEATHS_SHORT"), math.max(0, tonumber(item.pvpDeathsDelta) or 0))
        if (tonumber(item.duration) or 0) > 0 then parts[#parts + 1] = self:L("HISTORY_DURATION_SHORT") .. " " .. TPM_FormatDuration(item.duration) end
    else
        parts[#parts + 1] = string.format("|c7DCA45%s|r %d", self:L("HISTORY_KILLS_SHORT"), math.max(0, tonumber(item.npcKillsDelta) or 0))
        parts[#parts + 1] = string.format("|cF07B68%s|r %d", self:L("HISTORY_DEATHS_SHORT"), math.max(0, tonumber(item.pveDeathsDelta) or 0))
        if (tonumber(item.duration) or 0) > 0 then parts[#parts + 1] = self:L("HISTORY_DURATION_SHORT") .. " " .. TPM_FormatDuration(item.duration) end
    end
    return table.concat(parts, "   •   ")
end

function TPM:RefreshCombatActivityPanel()
    self:EnsureCombatActivityLogControls()
    local combatActivities = self:GetCombatLogSummaries(100)
    local activities = self:GetActivityLogSummaries(100)

    if self.statisticsHistorySessionTitle then self.statisticsHistorySessionTitle:SetText(self:L("HISTORY_COMBAT_LOG")) end
    if self.statisticsCombatActivityRightTitle then self.statisticsCombatActivityRightTitle:SetText(self:L("HISTORY_ACTIVITY_LIST")) end
    if self.statisticsCombatKillLogCount then self.statisticsCombatKillLogCount:SetText(string.format("%d / 100", #combatActivities)) end
    if self.statisticsCombatActivityLogCount then self.statisticsCombatActivityLogCount:SetText(string.format("%d / 100", #activities)) end

    if self.statisticsHistoryActivityImage then self.statisticsHistoryActivityImage:SetHidden(true) end
    if self.statisticsHistorySessionText then self.statisticsHistorySessionText:SetHidden(true) end
    if self.statisticsCombatExamplesTitle then self.statisticsCombatExamplesTitle:SetHidden(true) end
    for _, row in ipairs(self.statisticsCombatRecentRows or {}) do row:SetHidden(true) end

    local combatRows = self.statisticsCombatKillLogRows or {}
    for i, row in ipairs(combatRows) do
        local item = combatActivities[i]
        row:SetHidden(item == nil)
        if item then
            local hex = self:GetCombatDifficultyVisual(item)
            local r = tonumber(hex:sub(1,2), 16) / 255
            local g = tonumber(hex:sub(3,4), 16) / 255
            local b = tonumber(hex:sub(5,6), 16) / 255
            if row.TPMAccent then row.TPMAccent:SetCenterColor(r, g, b, 0.92) end
            if row.TPMTitle then row.TPMTitle:SetText(self:GetCombatLogTitle(item)) end
            if row.TPMTimestamp then row.TPMTimestamp:SetText(self:FormatLogTimestamp(item)) end
            if row.TPMDetail then row.TPMDetail:SetText(self:FormatCombatLogDetail(item)) end
        end
    end

    local activityRows = self.statisticsCombatActivityLogRows or {}
    for i, row in ipairs(activityRows) do
        local item = activities[i]
        row:SetHidden(item == nil)
        if item then
            local style = self:GetActivityLogStyle(item.activityKind)
            if row.TPMAccent then row.TPMAccent:SetCenterColor(style[1], style[2], style[3], 0.92) end
            if row.TPMTitle then
                row.TPMTitle:SetColor(0.95, 0.94, 0.91, 1)
                row.TPMTitle:SetText(self:GetActivityDisplayName(item))
            end
            if row.TPMTimestamp then row.TPMTimestamp:SetText(self:FormatLogTimestamp(item)) end
            if row.TPMDetail then row.TPMDetail:SetText(self:FormatActivityLogDetail(item)) end
        end
    end

    if self.statisticsCombatKillLogScrollChild then
        self.statisticsCombatKillLogScrollChild:SetDimensions(self.statisticsCombatKillLogRowWidth or 430, math.max(1, #combatActivities) * 50)
    end
    if self.statisticsCombatActivityLogScrollChild then
        self.statisticsCombatActivityLogScrollChild:SetDimensions(self.statisticsCombatActivityLogRowWidth or 430, math.max(1, #activities) * 50)
    end

    if self.statisticsCombatKillLogEmpty then
        self.statisticsCombatKillLogEmpty:SetText(self:L("HISTORY_NO_COMBAT_LOG"))
        self.statisticsCombatKillLogEmpty:SetHidden(#combatActivities > 0)
    end
    if self.statisticsCombatActivityLogEmpty then
        self.statisticsCombatActivityLogEmpty:SetText(self:L("HISTORY_NO_ACTIVITY"))
        self.statisticsCombatActivityLogEmpty:SetHidden(#activities > 0)
    end
end

local function TPM_FormatChartDate(timestamp, rangeDays)
    timestamp = tonumber(timestamp) or 0
    if timestamp <= 0 then return "" end
    -- ESO's formatter is locale-aware and safe in the addon sandbox.
    do
        local value = GetDateStringFromTimestamp(timestamp)
        if type(value) == "string" and value ~= "" then
            local d, m, y = value:match("(%d+)[%.%/%-](%d+)[%.%/%-](%d+)")
            if d and m and y then
                y = tonumber(y) or 0
                if y >= 2000 then y = y % 100 end
                return string.format("%02d.%02d.%02d", tonumber(d) or 0, tonumber(m) or 0, y)
            end
            return value
        end
    end
    return tostring(TPM_DayKey(timestamp))
end

local function TPM_NiceStep(rawStep)
    rawStep = math.max(0.000001, tonumber(rawStep) or 1)
    local exponent = math.floor(math.log(rawStep) / math.log(10))
    local fraction = rawStep / (10 ^ exponent)
    local niceFraction
    if fraction <= 1 then niceFraction = 1
    elseif fraction <= 2 then niceFraction = 2
    elseif fraction <= 2.5 then niceFraction = 2.5
    elseif fraction <= 5 then niceFraction = 5
    else niceFraction = 10 end
    return niceFraction * (10 ^ exponent)
end

function TPM:GetNiceHistoryBounds(dataMin, dataMax, definition, forceZero)
    dataMin, dataMax = tonumber(dataMin) or 0, tonumber(dataMax) or 0
    if forceZero then dataMin = math.min(0, dataMin) end
    if dataMax <= dataMin then
        if definition and definition.kind == "duration" then
            dataMin = 0
            dataMax = math.max(3600, dataMax)
        else
            dataMin = forceZero and 0 or math.floor(dataMin)
            dataMax = math.max(dataMin + 4, dataMax + 1)
        end
    end
    local rawStep = (dataMax - dataMin) / 4
    local step = TPM_NiceStep(rawStep)

    -- Duration axes should use human-friendly quarter/half/full hour steps.
    if definition and definition.kind == "duration" then
        if rawStep <= 300 then step = 300
        elseif rawStep <= 900 then step = 900
        elseif rawStep <= 1800 then step = 1800
        elseif rawStep <= 3600 then step = 3600
        elseif rawStep <= 7200 then step = 7200
        else step = TPM_NiceStep(rawStep) end
    end

    local niceMin = forceZero and 0 or (math.floor(dataMin / step) * step)
    local niceMax = math.ceil(dataMax / step) * step
    if niceMax <= niceMin then niceMax = niceMin + (step * 4) end
    return niceMin, niceMax
end

function TPM:GetHistoryTimeBounds(firstTime, lastTime, rangeDays)
    local now = TPM_Now()
    if rangeDays and rangeDays < 730 then
        return now - math.max(0, rangeDays - 1) * 86400, now
    end
    firstTime = tonumber(firstTime) or now
    lastTime = tonumber(lastTime) or now
    if lastTime <= firstTime then lastTime = firstTime + 86400 end
    return firstTime, lastTime
end

function TPM:RefreshHistoryAxisTicks(minValue, maxValue, firstTime, lastTime, definition, rangeDays, left, top, width, height)
    local chart = self.statisticsHistoryChart
    if not chart then return end
    left, top, width, height = left or 38, top or 76, width or 850, height or 158
    local axisFirst, axisLast = self:GetHistoryTimeBounds(firstTime, lastTime, rangeDays)
    for i = 1, 5 do
        local ratio = (i - 1) / 4
        local yTick = self.statisticsHistoryYTicks and self.statisticsHistoryYTicks[i]
        if yTick then
            local value = maxValue - ((maxValue - minValue) * ratio)
            yTick:ClearAnchors()
            yTick:SetAnchor(RIGHT, chart, TOPLEFT, left - 8, top + height * ratio)
            yTick:SetText(self:FormatHistoryMetricValue(value, definition))
            yTick:SetHidden(false)
        end
        local xTick = self.statisticsHistoryXTicks and self.statisticsHistoryXTicks[i]
        if xTick then
            local ts = axisFirst + ((axisLast - axisFirst) * ratio)
            xTick:ClearAnchors()
            xTick:SetAnchor(TOP, chart, TOPLEFT, left + width * ratio, top + height + 8)
            xTick:SetText(TPM_FormatChartDate(ts, rangeDays))
            xTick:SetHidden(false)
        end
    end
    return axisFirst, axisLast
end

function TPM:RefreshCombatHistoryChart(rangeDays)
    self:EnsureCombatDashboardControls()
    self:SetCombatDashboardVisible(true)
    if self.statisticsCombatChartTitle then
        local rangeText = rangeDays >= 730 and self:L("HISTORY_ALL") or self:L("HISTORY_RANGE_DAYS", rangeDays)
        self.statisticsCombatChartTitle:SetText(self:L("HISTORY_CHART_TITLE", rangeText))
    end
    local chart = self.statisticsHistoryChart
    if not chart or not self.statisticsCombatLineSets then return end

    local seriesDefs = {
        { historyKey = "npcKills",  setKey = "pveKills"  },
        { historyKey = "pveDeaths", setKey = "pveDeaths" },
        { historyKey = "pvpKills",  setKey = "pvpKills"  },
        { historyKey = "pvpDeaths", setKey = "pvpDeaths" },
    }
    local series = {}
    local globalMin, globalMax, firstTime, lastTime
    for _, def in ipairs(seriesDefs) do
        local pts = self:GetHistorySeries(def.historyKey, rangeDays) or {}
        series[def.setKey] = pts
        for _, p in ipairs(pts) do
            local value = tonumber(p.value) or 0
            globalMin = globalMin and math.min(globalMin, value) or value
            globalMax = globalMax and math.max(globalMax, value) or value
            local ts = tonumber(p.timestamp) or 0
            if ts > 0 then
                firstTime = firstTime and math.min(firstTime, ts) or ts
                lastTime = lastTime and math.max(lastTime, ts) or ts
            end
        end
    end

    for _, set in pairs(self.statisticsCombatLineSets or {}) do
        for _, c in ipairs(set.segments or {}) do c:SetHidden(true) end
        for _, c in ipairs(set.points or {}) do c:SetHidden(true) end
    end

    if not globalMin or (tonumber(globalMax) or 0) <= 0 then
        self.statisticsHistoryEmpty:SetHidden(false)
        self.statisticsHistoryEmpty:SetText(self:L("HISTORY_NO_COMBAT_DATA"))
        local minValue, maxValue = 0, 4
        local axisFirst, axisLast = self:GetHistoryTimeBounds(firstTime, lastTime, rangeDays)
        self:RefreshHistoryAxisTicks(minValue, maxValue, axisFirst, axisLast, nil, rangeDays, 38, 76, 850, 158)
        self.statisticsHistoryMinAxis:SetText("")
        self.statisticsHistoryMaxAxis:SetText("")
        self.statisticsHistoryStartAxis:SetText("")
        self.statisticsHistoryEndAxis:SetText("")
        return
    end
    self.statisticsHistoryEmpty:SetHidden(true)

    local minValue, maxValue = self:GetNiceHistoryBounds(globalMin, globalMax, nil, true)
    local valueRange = math.max(1, maxValue - minValue)
    local axisFirst, axisLast = self:GetHistoryTimeBounds(firstTime, lastTime, rangeDays)
    local timeRange = math.max(1, axisLast - axisFirst)
    local left, top, width, height = 38, 76, 850, 158

    for _, def in ipairs(seriesDefs) do
        local set = self.statisticsCombatLineSets[def.setKey]
        local coords = {}
        if set then
            for i, p in ipairs(series[def.setKey] or {}) do
                if i > HISTORY_MAX_CHART_POINTS then break end
                local ts = tonumber(p.timestamp) or axisFirst
                local x = left + Clamp((ts - axisFirst) / timeRange, 0, 1) * width
                local y = top + (1 - Clamp(((tonumber(p.value) or 0) - minValue) / valueRange, 0, 1)) * height
                coords[i] = { x = x, y = y }
                local dot = set.points and set.points[i]
                if dot then
                    dot:ClearAnchors()
                    dot:SetAnchor(CENTER, chart, TOPLEFT, x, y)
                    dot:SetHidden(false)
                end
            end
            for i = 1, #coords - 1 do
                local a, b = coords[i], coords[i + 1]
                local seg = set.segments and set.segments[i]
                if seg then
                    seg:ClearAnchors()
                    seg:SetAnchor(TOPLEFT, chart, TOPLEFT, a.x, a.y)
                    seg:SetAnchor(BOTTOMRIGHT, chart, TOPLEFT, b.x, b.y)
                    seg:SetHidden(false)
                end
            end
        end
    end

    self.statisticsHistoryMinAxis:SetText("")
    self.statisticsHistoryMaxAxis:SetText("")
    self.statisticsHistoryStartAxis:SetText("")
    self.statisticsHistoryEndAxis:SetText("")
    self:RefreshHistoryAxisTicks(minValue, maxValue, axisFirst, axisLast, nil, rangeDays, left, top, width, height)
end

function TPM:GetLastActivityText(session)
    if not session then return self:L("HISTORY_NO_ACTIVITY") end
    return self:GetActivityDisplayName(session)
end

function TPM:FormatHistoryAxisLabel(timestamp)
    timestamp = tonumber(timestamp) or 0
    if timestamp <= 0 then return "" end
    local value = GetDateStringFromTimestamp(timestamp)
    if type(value) == "string" and value ~= "" then return value end
    return tostring(TPM_DayKey(timestamp))
end

function TPM:FormatHistoryMetricValue(value, definition)
    value = tonumber(value) or 0
    if definition and definition.kind == "percent" then return string.format("%.1f%%", value) end
    if definition and definition.kind == "decimal" then return string.format("%.2f", value) end
    if definition and definition.kind == "duration" then return TPM_FormatDuration(value) end
    return FormatNumber(value)
end

function TPM:RefreshHistoryChart(points, definition, rangeDays)
    local chart = self.statisticsHistoryChart
    if not chart then return end
    for _, seg in ipairs(self.statisticsHistorySegments or {}) do seg:SetHidden(true) end
    for _, dot in ipairs(self.statisticsHistoryPoints or {}) do dot:SetHidden(true) end

    if #points < 1 then
        self.statisticsHistoryEmpty:SetHidden(false)
        self.statisticsHistoryEmpty:SetText(self:L("HISTORY_EMPTY"))
        self.statisticsHistoryMinAxis:SetText("")
        self.statisticsHistoryMaxAxis:SetText("")
        if self.statisticsHistoryStartAxis then self.statisticsHistoryStartAxis:SetText("") end
        if self.statisticsHistoryEndAxis then self.statisticsHistoryEndAxis:SetText("") end
        return
    end
    self.statisticsHistoryEmpty:SetHidden(true)

    local dataMin, dataMax = points[1].value, points[1].value
    local firstTime, lastTime = points[1].timestamp or 0, points[#points].timestamp or 0
    for _, point in ipairs(points) do
        dataMin = math.min(dataMin, point.value)
        dataMax = math.max(dataMax, point.value)
    end
    local forceZero = definition and definition.kind == "duration"
    local minValue, maxValue = self:GetNiceHistoryBounds(dataMin, dataMax, definition, forceZero)
    local range = math.max(1, maxValue - minValue)
    local axisFirst, axisLast = self:GetHistoryTimeBounds(firstTime, lastTime, rangeDays)
    local timeRange = math.max(1, axisLast - axisFirst)
    local left, top, width, height = 44, 34, 850, 262
    local coords = {}
    for i, point in ipairs(points) do
        local xRatio = Clamp(((point.timestamp or axisFirst) - axisFirst) / timeRange, 0, 1)
        local x = left + (xRatio * width)
        local normalized = (point.value - minValue) / range
        local y = top + ((1 - normalized) * height)
        coords[i] = { x=x, y=y }
        local dot = self.statisticsHistoryPoints[i]
        if dot then
            dot:ClearAnchors()
            dot:SetAnchor(CENTER, chart, TOPLEFT, x, y)
            dot:SetHidden(false)
        end
    end
    for i = 1, #coords - 1 do
        local a, b = coords[i], coords[i+1]
        local segment = self.statisticsHistorySegments[i]
        if segment then
            segment:ClearAnchors()
            -- CT_LINE connects its two anchors directly. Unlike rotating a thin
            -- CT_TEXTURE, this does not clip diagonal segments inside a horizontal
            -- control rectangle.
            segment:SetAnchor(TOPLEFT, chart, TOPLEFT, a.x, a.y)
            segment:SetAnchor(BOTTOMRIGHT, chart, TOPLEFT, b.x, b.y)
            segment:SetHidden(false)
        end
    end
    self.statisticsHistoryMinAxis:SetText("")
    self.statisticsHistoryMaxAxis:SetText("")
    if self.statisticsHistoryStartAxis then self.statisticsHistoryStartAxis:SetText("") end
    if self.statisticsHistoryEndAxis then self.statisticsHistoryEndAxis:SetText("") end
    self:RefreshHistoryAxisTicks(minValue, maxValue, axisFirst, axisLast, definition, rangeDays, left, top, width, height)
end

function TPM:LayoutHistorySummaryCards(layoutKind)
    local cards = self.statisticsHistorySummaryCards or {}
    local compact = layoutKind == "currency"
    local combat = layoutKind == "counter"
    local function Place(card, x, width, hidden)
        if not card or not card.control then return end
        card.control:SetHidden(hidden == true)
        if hidden then return end
        card.control:ClearAnchors()
        card.control:SetDimensions(width, combat and 98 or 72)
        card.control:SetAnchor(TOPLEFT, self.statisticsHistoryPage, TOPLEFT, x, combat and 124 or 82)
        card.control:SetCenterColor(0.022, 0.021, 0.018, 0.995)
        card.control:SetEdgeColor(0.44, 0.34, 0.10, 0.95)
        if card.title then
            card.title:ClearAnchors()
            card.title:SetDimensions(combat and 126 or (width - 16), 22)
            card.title:SetAnchor(TOPRIGHT, card.control, TOPRIGHT, -8, combat and 11 or 7)
            card.title:SetFont(compact and "$(BOLD_FONT)|14" or "$(BOLD_FONT)|15")
            card.title:SetColor(0.86,0.82,0.73,1)
            card.title:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        end
        if card.value then
            card.value:ClearAnchors()
            card.value:SetDimensions(combat and 126 or (width - 16), combat and 40 or 34)
            card.value:SetAnchor(TOPRIGHT, card.control, TOPRIGHT, -8, combat and 35 or 30)
            card.value:SetFont(combat and "$(ANTIQUE_FONT)|31" or (compact and "$(ANTIQUE_FONT)|23" or "$(ANTIQUE_FONT)|25"))
            card.value:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        end
    end

    if layoutKind == "currency" then
        Place(cards.current, 20, 172, false)
        Place(cards.income, 206, 172, false)
        Place(cards.expenses, 392, 172, false)
        Place(cards.high, 578, 172, false)
        Place(cards.low, 764, 188, false)
        Place(cards.net, 0, 1, true)
        Place(cards.change, 0, 1, true)
    elseif layoutKind == "playtime" then
        Place(cards.current, 20, 450, false)
        Place(cards.change, 482, 470, false)
        Place(cards.high, 0, 1, true)
        Place(cards.low, 0, 1, true)
        Place(cards.income, 0, 1, true)
        Place(cards.expenses, 0, 1, true)
        Place(cards.net, 0, 1, true)
    elseif layoutKind == "counter" then
        Place(cards.current, 20, 218, false)
        Place(cards.change, 252, 218, false)
        Place(cards.high, 484, 218, false)
        Place(cards.low, 716, 236, false)
        Place(cards.income, 0, 1, true)
        Place(cards.expenses, 0, 1, true)
        Place(cards.net, 0, 1, true)
    else
        Place(cards.current, 20, 218, false)
        Place(cards.change, 252, 218, false)
        Place(cards.high, 484, 218, false)
        Place(cards.low, 716, 236, false)
        Place(cards.income, 0, 1, true)
        Place(cards.expenses, 0, 1, true)
        Place(cards.net, 0, 1, true)
    end

    -- Combat cards get subtle category tinting without sacrificing ESO readability.
    if combat then
        local tint = {
            current={0.035,0.060,0.022,0.995, 0.49,0.78,0.27},
            change ={0.060,0.025,0.020,0.995, 0.94,0.31,0.24},
            high   ={0.020,0.038,0.060,0.995, 0.36,0.62,0.91},
            low    ={0.060,0.025,0.020,0.995, 0.94,0.31,0.24},
        }
        for key, c in pairs(tint) do
            local card = cards[key]
            if card and card.control then
                card.control:SetCenterColor(c[1],c[2],c[3],c[4])
                card.control:SetEdgeColor(c[5],c[6],c[7],0.70)
            end
        end
    end

    local chart = self.statisticsHistoryChart
    local box = self.statisticsHistorySessionBox
    if chart then
        chart:ClearAnchors()
        chart:SetDimensions(932, combat and 282 or 350)
        chart:SetAnchor(TOPLEFT, self.statisticsHistoryPage, TOPLEFT, 20, combat and 198 or 170)
        if combat then chart:SetHidden(true) end
    end
    if box then
        box:ClearAnchors()
        if combat then
            box:SetDimensions(932, 378)
            box:SetAnchor(TOPLEFT, self.statisticsHistoryPage, TOPLEFT, 20, 232)
        elseif layoutKind == "currency" or layoutKind == "playtime" then
            box:SetDimensions(932, 220)
            box:SetAnchor(TOPLEFT, self.statisticsHistoryPage, TOPLEFT, 20, 230)
        else
            box:SetDimensions(932, 84)
            box:SetAnchor(TOPLEFT, self.statisticsHistoryPage, TOPLEFT, 20, 530)
        end
    end

    -- Range selector lives in the graph header. This removes the old overlap with
    -- the PvP heading and makes the control read like one cohesive toolbar.
    if chart then
        for i, bg in ipairs(self.statisticsHistoryRangeBackdrops or {}) do
            bg:ClearAnchors()
            bg:SetAnchor(TOPRIGHT, chart, TOPRIGHT, -14 - ((5 - i) * 68), 8)
        end
    end

    if not combat then
        self:SetCombatDashboardVisible(false)
        if self.statisticsHistorySessionText and box then
            self.statisticsHistorySessionText:ClearAnchors()
            self.statisticsHistorySessionText:SetDimensions(900, 44)
            self.statisticsHistorySessionText:SetAnchor(TOPLEFT, box, TOPLEFT, 14, 33)
        end
    end
end


function TPM:SetHistoryChartAreaVisible(visible)
    local show = visible == true
    if self.statisticsHistoryChart then self.statisticsHistoryChart:SetHidden(not show) end
    for _, button in ipairs(self.statisticsHistoryRangeButtons or {}) do button:SetHidden(not show) end
    for _, bg in ipairs(self.statisticsHistoryRangeBackdrops or {}) do bg:SetHidden(not show) end
    for _, tick in ipairs(self.statisticsHistoryYTicks or {}) do tick:SetHidden(not show) end
    for _, tick in ipairs(self.statisticsHistoryXTicks or {}) do tick:SetHidden(not show) end
    if self.statisticsHistoryMinAxis then self.statisticsHistoryMinAxis:SetHidden(not show) end
    if self.statisticsHistoryMaxAxis then self.statisticsHistoryMaxAxis:SetHidden(not show) end
    if self.statisticsHistoryStartAxis then self.statisticsHistoryStartAxis:SetHidden(not show) end
    if self.statisticsHistoryEndAxis then self.statisticsHistoryEndAxis:SetHidden(not show) end
    if self.statisticsHistoryEmpty then self.statisticsHistoryEmpty:SetHidden(not show) end
end

function TPM:GetTodayPlaySeconds()
    local currentPlayed = math.max(0, tonumber(self:SyncCurrentEsoPlayedTime()) or 0)
    local now = TPM_Now()
    local currentOffset = TPM_GetLocalUtcOffsetSeconds()
    local today = TPM_CharacterDayKeyWithOffset(now, currentOffset)
    local store = self:GetHistoryStore()
    if not store then return 0 end
    self:MigrateCharacterPlaytime365(store)
    local entry = store.characterPlaytime365 and store.characterPlaytime365[tostring(today)] or nil
    local total = type(entry) == "table" and math.max(0, tonumber(entry.seconds) or 0) or 0

    -- Add only the still-uncheckpointed /played delta. This keeps the value live
    -- without falling back to the older UTC-day history calculation.
    local previous = store.characterPlaytimeLastObservation
    if type(previous) == "table" then
        local previousAt = tonumber(previous.timestamp) or 0
        local previousPlayed = tonumber(previous.played)
        local previousOffset = tonumber(previous.utcOffset) or currentOffset
        if previousAt > 0 and previousPlayed and now >= previousAt and currentPlayed >= previousPlayed then
            local delta = math.max(0, currentPlayed - previousPlayed)
            if delta > 0 then
                local previousDay = TPM_CharacterDayKeyWithOffset(previousAt, previousOffset)
                if previousDay == today then
                    total = total + delta
                else
                    local wallSpan = now - previousAt
                    local dayStart = TPM_CharacterDayStartTimestampWithOffset(today, currentOffset)
                    local todayWall = math.max(0, now - math.max(previousAt, dayStart))
                    if wallSpan > 0 then total = total + math.max(0, Round(delta * (todayWall / wallSpan))) end
                end
            end
        end
    end
    return math.max(0, Round(total))
end

function TPM:GetPlaytimePeriodTotal(days)
    local points = self:GetDailyPlaytimeHistorySeries(days)
    local total = 0
    if type(points) == "table" and points[1] and points[1].value ~= nil then
        -- Function may return points, definition. Sum daily values only once per day.
        local seen = {}
        for _, p in ipairs(points) do
            local dayKey = p.dayKey or TPM_DayKey(p.timestamp or 0)
            if not seen[dayKey] then
                seen[dayKey] = true
                total = total + math.max(0, tonumber(p.value) or 0)
            end
        end
    end
    return math.max(0, Round(total))
end

function TPM:RefreshHistoryStatisticsPage()
    if not self.statisticsHistoryPage or self.statisticsHistoryPage:IsHidden() then return end

    -- PvE / PvP is now a lifetime dashboard. Keep history only for the recent
    -- activity panel; do not calculate hidden chart/range data in the background.
    self:CheckpointHistory("combat_view", false)
    self.saved.historyMetric = "npcKills"
    self.statisticsHistoryTitle:SetText(self:L("HISTORY_PAGE_TITLE"))
    self.statisticsHistoryMetricLabel:SetText(self:L("HISTORY_COMBAT"))

    -- Character/companion Level and XP bars moved to Character (page 2).
    -- PvE/PvP now refreshes only combat-specific labels and counters.
    if self.statisticsCombatPveHeading then
        self.statisticsCombatPveHeading:ClearAnchors()
        self.statisticsCombatPveHeading:SetAnchor(TOPLEFT, self.statisticsHistoryPage, TOPLEFT, 20, 94)
        self.statisticsCombatPveHeading:SetText(self:L("HISTORY_PVE_HEADING"))
        self.statisticsCombatPveHeading:SetFont(self.langCode == "ru" and "$(BOLD_FONT)|15" or "$(BOLD_FONT)|18")
        self.statisticsCombatPveHeading:SetDimensions(self.langCode == "ru" and 260 or 250, 28)
    end
    if self.statisticsCombatBossBadge then
        self.statisticsCombatBossBadge:ClearAnchors()
        self.statisticsCombatBossBadge:SetAnchor(TOPLEFT, self.statisticsHistoryPage, TOPLEFT, 286, 94)
    end
    if self.statisticsCombatPvpHeading then
        self.statisticsCombatPvpHeading:ClearAnchors()
        self.statisticsCombatPvpHeading:SetAnchor(TOPRIGHT, self.statisticsHistoryPage, TOPRIGHT, -20, 94)
        self.statisticsCombatPvpHeading:SetText(self:L("HISTORY_PVP_HEADING"))
    end
    if self.statisticsCombatLegendLeft then
        self.statisticsCombatLegendLeft:SetText(self:L("HISTORY_COMBAT_LEGEND_PVE"))
    end
    if self.statisticsCombatLegendRight then
        self.statisticsCombatLegendRight:SetText(self:L("HISTORY_COMBAT_LEGEND_PVP"))
    end

    if self.statisticsHistoryPrevButton then self.statisticsHistoryPrevButton:SetHidden(true) end
    if self.statisticsHistoryNextButton then self.statisticsHistoryNextButton:SetHidden(true) end
    self:SetHistoryChartAreaVisible(false)
    self:EnsureCombatDashboardControls()
    self:LayoutHistorySummaryCards("counter")

    local combat = self:GetPlayerCombatStatsView()
    local cards = self.statisticsHistorySummaryCards or {}
    local combatTitleFont = self.langCode == "ru" and "$(BOLD_FONT)|13" or "$(BOLD_FONT)|15"
    for _, card in pairs({ cards.current, cards.change, cards.high, cards.low }) do
        if card and card.title then card.title:SetFont(combatTitleFont) end
    end
    if cards.current then
        cards.current.title:SetText(self:L("HISTORY_PVE_KILLS"))
        cards.current.value:SetText(FormatNumber(combat.npcKills or 0))
        cards.current.value:SetColor(0.55,0.82,0.24,1)
    end
    if cards.change then
        cards.change.title:SetText(self:L("HISTORY_PVE_DEATHS"))
        cards.change.value:SetText(FormatNumber(combat.pveDeaths or 0))
        cards.change.value:SetColor(0.90,0.28,0.24,1)
    end
    if cards.high then
        cards.high.title:SetText(self:L("HISTORY_PVP_KILLS"))
        cards.high.value:SetText(FormatNumber(combat.pvpKills or 0))
        cards.high.value:SetColor(0.36,0.66,0.95,1)
    end
    if cards.low then
        cards.low.title:SetText(self:L("HISTORY_PVP_DEATHS"))
        cards.low.value:SetText(FormatNumber(combat.pvpDeaths or 0))
        cards.low.value:SetColor(0.90,0.28,0.24,1)
    end
    if self.statisticsCombatBossText then
        self.statisticsCombatBossText:SetText(self:L("STAT_BOSS_KILLS") .. ": " .. FormatNumber(combat.bossKills or 0))
    end

    self:SetCombatDashboardVisible(true)

    -- With the chart removed, use the free space for recent activity instead of
    -- leaving the old chart-sized hole in the middle of the page.
    if self.statisticsHistorySessionBox then
        self.statisticsHistorySessionBox:ClearAnchors()
        self.statisticsHistorySessionBox:SetDimensions(932, 378)
        self.statisticsHistorySessionBox:SetAnchor(TOPLEFT, self.statisticsHistoryPage, TOPLEFT, 20, 232)
    end
    self:RefreshCombatActivityPanel()
    self:EnforceStatisticsDarkModeAfterRefresh()
end


-- 2.7.0 ---------------------------------------------------------------------
-- Statistics journal customization
local TPM_THEME_TEXT = {
    de={title="Anpassung",design="Design",designTpm="Klassisch Gold",designVanilla="Transparent",dark="Dark Modern",cyber="Cyber",neon="Neon",arctic="Arctic",ember="Ember",matrix="Matrix",colors="Farben",background="Hintergrund",heading="Überschriften",accent="Akzente & Rahmen",progress="Fortschritt & Werte",text="Normaler Text",effects="Effekte",rgb="Smooth RGB – Fortschritt & Werte",speed="RGB-Geschwindigkeit",brightness="RGB-Helligkeit",reset="Standard wiederherstellen",close="Schließen"},
    en={title="Customization",design="Design",designTpm="Classic Gold",designVanilla="Transparent",dark="Dark Modern",cyber="Cyber",neon="Neon",arctic="Arctic",ember="Ember",matrix="Matrix",colors="Colors",background="Background",heading="Headings",accent="Accents & Borders",progress="Progress & Values",text="Normal Text",effects="Effects",rgb="Smooth RGB – Progress & Values",speed="RGB Speed",brightness="RGB Brightness",reset="Restore Defaults",close="Close"},
    fr={title="Personnalisation",design="Design",designTpm="Or classique",designVanilla="Transparent",dark="Dark Modern",cyber="Cyber",neon="Neon",arctic="Arctic",ember="Ember",matrix="Matrix",colors="Couleurs",background="Arrière-plan",heading="Titres",accent="Accents & bordures",progress="Progression & valeurs",text="Texte normal",effects="Effets",rgb="RGB fluide – progression & valeurs",speed="Vitesse RGB",brightness="Luminosité RGB",reset="Valeurs par défaut",close="Fermer"},
    es={title="Personalización",design="Diseño",designTpm="Oro clásico",designVanilla="Transparente",dark="Dark Modern",cyber="Cyber",neon="Neon",arctic="Arctic",ember="Ember",matrix="Matrix",colors="Colores",background="Fondo",heading="Títulos",accent="Acentos y bordes",progress="Progreso y valores",text="Texto normal",effects="Efectos",rgb="RGB suave – progreso y valores",speed="Velocidad RGB",brightness="Brillo RGB",reset="Restaurar valores",close="Cerrar"},
    ru={title="Настройка",design="Дизайн",designTpm="Классика",designVanilla="Прозрачный",dark="Dark Modern",cyber="Cyber",neon="Neon",arctic="Arctic",ember="Ember",matrix="Matrix",colors="Цвета",background="Фон",heading="Заголовки",accent="Акценты и рамки",progress="Прогресс и значения",text="Обычный текст",effects="Эффекты",rgb="Плавный RGB – прогресс и значения",speed="Скорость RGB",brightness="Яркость RGB",reset="По умолчанию",close="Закрыть"},
    pt={title="Personalização",design="Tema",designTpm="Ouro clássico",designVanilla="Transparente",dark="Dark Modern",cyber="Cyber",neon="Neon",arctic="Ártico",ember="Ember",matrix="Matrix",colors="Cores",background="Fundo",heading="Títulos",accent="Acentos e bordas",progress="Progresso e valores",text="Texto normal",effects="Efeitos",rgb="RGB suave",speed="Velocidade RGB",brightness="Brilho RGB",reset="Restaurar padrão",close="Fechar"},
}

function TPM:GetStatisticsThemeText(key)
    local lang = TPM_THEME_TEXT[self.langCode] or TPM_THEME_TEXT.en
    return lang[key] or TPM_THEME_TEXT.en[key] or key
end

function TPM:GetStatisticsThemeHeadingColor()
    local preset = self:GetThemePreset()
    local c = preset and preset.heading
    if c then return c[1], c[2], c[3], 1 end
    return .95,.82,.36,1
end

function TPM:GetStatisticsThemeAccentColor()
    local preset = self:GetThemePreset()
    local c = preset and preset.accent
    if c then return c[1], c[2], c[3], 1 end
    return .95,.82,.36,1
end

function TPM:GetStatisticsThemeTextColor()
    local preset = self:GetThemePreset()
    local c = preset and preset.text
    if c then return c[1], c[2], c[3], 1 end
    return .88,.84,.74,1
end

function TPM:GetStatisticsThemeProgressColor()
    local preset = self:GetThemePreset()
    local c = preset and preset.progress
    if c then return c[1], c[2], c[3], 1 end
    return .95,.82,.12,1
end

-- 2.7.0: Comprehensive accent recoloring for TPM Standard.
-- Older TPM controls were created over many versions with hard-coded gold/yellow
-- colors.  The customization accent now adopts those decorative colors too,
-- while neutral text/backgrounds and semantic red/green/blue colors remain intact.
local function TPM_IsThemeWarmAccent(r, g, b, a)
    r, g, b, a = tonumber(r), tonumber(g), tonumber(b), tonumber(a) or 1
    if not r or not g or not b or a < 0.12 then return false end
    local mx, mn = math.max(r, g, b), math.min(r, g, b)
    if (mx - mn) < 0.10 then return false end -- neutral grey/white
    -- gold, yellow, amber and warm bronze UI accents
    return r >= 0.48 and g >= 0.30 and b <= 0.52 and r >= (b * 1.18) and g >= (b * 1.08)
end

local function TPM_IsThemeNeutralText(r,g,b,a)
    r,g,b,a=tonumber(r),tonumber(g),tonumber(b),tonumber(a) or 1
    if not r or not g or not b or a<0.12 then return false end
    local mx,mn=math.max(r,g,b),math.min(r,g,b)
    return mx>=0.46 and (mx-mn)<=0.24
end

function TPM:ApplyStatisticsThemeToLegacyAccents(ar, ag, ab, pr, pg, pb, hr, hg, hb, tr, tg, tb)
    hr,hg,hb=hr or ar,hg or ag,hb or ab
    tr,tg,tb=tr or .88,tg or .84,tb or .74
    if not self.statisticsWindow then return end
    -- Headings, accents, text and Progress/Values are deliberately independent channels.
    -- Smooth RGB is ONLY applied to progress bars and numeric values.
    if not self.statisticsThemeLegacyAccentControls then
        self.statisticsThemeLegacyAccentControls = setmetatable({}, { __mode = "k" })
    end
    local tagged = self.statisticsThemeLegacyAccentControls
    -- Run explicit role tagging once per theme pass, not once for every control
    -- visited by the recursive legacy scanner. This avoids repeated O(N*M)
    -- work on the large Character/Alliance pages when switching themes.
    local explicitRolesApplied = false

    local function cleanText(text)
        if type(text) ~= "string" then return "" end
        text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
        return text:gsub("^%s+", ""):gsub("%s+$", "")
    end

    local function isValueText(text)
        text = cleanText(text)
        if text == "" then return false end
        -- Never treat calendar dates as Progress & Values. The old 2.7.11
        -- heuristic accepted strings such as 02.09.2026 as a plain number.
        if text:match("^%d%d?[%.%/%-]%d%d?[%.%/%-]%d%d%d%d$")
            or text:match("^%d%d%d%d[%.%/%-]%d%d?[%.%/%-]%d%d?$") then
            return false
        end
        -- Percentages, counters, plain amounts and compact time/value strings.
        if text:match("^[%+%-]?[%d%.,]+%s*%%$") then return true end
        if text:match("^%d+%s*/%s*%d+$") then return true end
        if text:match("^[%+%-]?[%d%.,]+$") then return true end
        if text:match("^[%+%-]?[%d%.,]+%s*[hHdDmMsS]") then return true end
        if text:match("^%d+:%d+") then return true end
        if text:match("^[%+%-]?[%d%.,]+%s+[A-Za-z][A-Za-z]?$") then return true end
        return false
    end

    local function nameSuggestsProgress(control)
        if not control or not control.GetName then return false end
        local name = control:GetName()
        if type(name) ~= "string" then return false end
        name = name:lower()
        return name:find("progress",1,true) ~= nil
            or name:find("percent",1,true) ~= nil
            or name:find("value",1,true) ~= nil
            or name:find("fill",1,true) ~= nil
            or name:find("count",1,true) ~= nil
    end

    local function isStrongProgressGold(r, g, b, a)
        r, g, b, a = tonumber(r), tonumber(g), tonumber(b), tonumber(a) or 1
        if not r or not g or not b or a < 0.12 then return false end
        -- Bright TPM yellow/gold used by fills and completion values.
        return r >= 0.68 and g >= 0.52 and b <= 0.34 and (r - b) >= 0.38
    end

    local function rememberAndApply(control)
        if not control then return end
        local role = tagged[control]
        if role == nil then
            role = {}
            local text = ""
            if control.GetText then
                local t = control:GetText()
                if type(t) == "string" then text = t end
            end
            local progressHint = nameSuggestsProgress(control) or isValueText(text)

            -- Label / texture color. Numeric warm-gold labels are Progress & Values;
            -- normal labels/icons/decorative textures remain Headings & Accents.
            if control.GetColor and control.SetColor then
                local cr, cg, cb, ca = control:GetColor()
                if progressHint and TPM_IsThemeWarmAccent(cr,cg,cb,ca) then
                    role.colorAlpha=tonumber(ca) or 1; role.colorChannel="progress"
                elseif text~="" and TPM_IsThemeWarmAccent(cr,cg,cb,ca) then
                    role.colorAlpha=tonumber(ca) or 1; role.colorChannel="heading"
                elseif text~="" and TPM_IsThemeNeutralText(cr,cg,cb,ca) then
                    role.colorAlpha=tonumber(ca) or 1; role.colorChannel="text"
                elseif TPM_IsThemeWarmAccent(cr,cg,cb,ca) then
                    role.colorAlpha=tonumber(ca) or 1; role.colorChannel="accent"
                end
            end

            -- Center fills are commonly progress bars / selected value surfaces.
            if control.GetCenterColor and control.SetCenterColor then
                local cr, cg, cb, ca = control:GetCenterColor()
                if TPM_IsThemeWarmAccent(cr, cg, cb, ca) then
                    role.centerAlpha = tonumber(ca) or 1
                    role.centerChannel = (progressHint or isStrongProgressGold(cr,cg,cb,ca)) and "progress" or "accent"
                end
            end

            -- Borders are decorative accents, never progress RGB/value color.
            if control.GetEdgeColor and control.SetEdgeColor then
                local er, eg, eb, ea = control:GetEdgeColor()
                if TPM_IsThemeWarmAccent(er, eg, eb, ea) then
                    role.edgeAlpha = tonumber(ea) or 1
                    role.edgeChannel = "accent"
                end
            end

            -- Inline legacy gold: numeric-only labels are values, prose/headings accents.
            if text ~= "" and text:find("|cE6C45C", 1, true) then
                role.inlineGold = true
                role.inlineChannel = isValueText(text) and "progress" or "heading"
            end

            if role.colorAlpha or role.centerAlpha or role.edgeAlpha or role.inlineGold then
                tagged[control] = role
            else
                -- Dynamic labels are often empty during page creation and only
                -- receive their value later. Do not permanently blacklist them.
                -- Continue this pass so the one-time explicit role tagging below
                -- can still classify known controls before the recursive walk moves on.
            end
        end

        if not explicitRolesApplied then
        -- 2.7.12: Explicit role overrides for controls whose meaning is known.
        -- This prevents the legacy color scanner from confusing yellow card titles,
        -- dates or prose with actual numeric progress/value controls.
        local function forceColor(control, channel)
            if not control or not control.SetColor then return end
            local role = tagged[control] or {}
            if not role.colorAlpha then
                local _,_,_,a = control:GetColor()
                role.colorAlpha = tonumber(a) or 1
            end
            role.colorChannel = channel
            tagged[control] = role
        end
        local function forceEdge(control, channel)
            if not control or not control.SetEdgeColor then return end
            local role = tagged[control] or {}
            if not role.edgeAlpha then
                local _,_,_,a = control:GetEdgeColor()
                role.edgeAlpha = tonumber(a) or 1
            end
            role.edgeChannel = channel
            tagged[control] = role
        end
        local function forceCenter(control, channel)
            if not control or not control.SetCenterColor then return end
            local role = tagged[control] or {}
            if not role.centerAlpha then
                local _,_,_,a = control:GetCenterColor()
                role.centerAlpha = tonumber(a) or 1
            end
            role.centerChannel = channel
            tagged[control] = role
        end

        -- Character page: card captions are headings, card numbers are values,
        -- dates/descriptions are normal text.
        for _,card in pairs(self.statisticsCharacterCards or {}) do
            forceColor(card.title, "heading")
            forceColor(card.value, "progress")
            forceColor(card.detail, "text")
            if card.control then
                forceEdge(card.control, "accent")
                forceCenter(card.control.TPMAccent, "accent")
                forceEdge(card.control.TPMIconBack, "accent")
                forceEdge(card.control.TPMIconFrame, "accent")
                forceCenter(card.control.TPMTopBand, "accent")
            end
        end
        forceColor(self.statisticsPlayerProfileTitle, "heading")
        forceColor(self.statisticsPlayerMountTitle, "heading")
        forceColor(self.statisticsPlayerProfileText, "text")
        forceColor(self.statisticsPlayerMountText, "text")
        forceColor(self.statisticsPlayerPageSubtitle, "text")
        forceColor(self.statisticsCharacterDailyHint, "text")
        for _,h in pairs(self.statisticsCharacterDailyHeaders or {}) do forceColor(h, "heading") end
        for _,row in ipairs(self.statisticsCharacterDailyRows or {}) do
            forceColor(row.date, "text")
            forceColor(row.playtime, "progress")
            forceColor(row.kills, "progress")
            forceColor(row.bosses, "progress")
        end

        -- Alliance tables: labels/count descriptions stay text, percentages and
        -- progress fills are Progress & Values. Alliance semantic marker colors
        -- themselves are intentionally not overridden.
        for _,row in ipairs(self.statisticsAllianceZoneRows or {}) do
            forceColor(row.name, "text"); forceColor(row.count, "text"); forceColor(row.pct, "progress")
            forceCenter(row.bar, "progress")
        end
        for _,row in ipairs(self.statisticsAllianceDetailRows or {}) do
            forceColor(row.label, "text"); forceColor(row.remain, "text"); forceColor(row.value, "progress")
            forceCenter(row.bar, "progress")
        end
        explicitRolesApplied = true
        end

        -- Re-read the role because the one-time explicit pass may have tagged the
        -- current control after its initial heuristic classification.
        role = tagged[control] or role

        local function channelColor(channel)
            if channel=="progress" then return pr,pg,pb end
            if channel=="heading" then return hr,hg,hb end
            if channel=="text" then return tr,tg,tb end
            return ar,ag,ab
        end

        if role.colorAlpha and control.SetColor then
            local r,g,b = channelColor(role.colorChannel)
            control:SetColor(r, g, b, role.colorAlpha)
        end
        if role.centerAlpha and control.SetCenterColor then
            local r,g,b = channelColor(role.centerChannel)
            control:SetCenterColor(r, g, b, role.centerAlpha)
        end
        if role.edgeAlpha and control.SetEdgeColor then
            local r,g,b = channelColor(role.edgeChannel)
            control:SetEdgeColor(r, g, b, role.edgeAlpha)
        end
        if role.inlineGold and control.GetText and control.SetText then
            local txt = control:GetText()
            if type(txt) == "string" then
                local r,g,b = channelColor(role.inlineChannel)
                local hex = string.format("%02X%02X%02X", math.floor(Clamp(r,0,1)*255+.5), math.floor(Clamp(g,0,1)*255+.5), math.floor(Clamp(b,0,1)*255+.5))
                txt = txt:gsub("|cE6C45C", "|c"..hex)
                if role.lastInlineHex then txt = txt:gsub("|c"..role.lastInlineHex, "|c"..hex) end
                role.lastInlineHex = hex
                control:SetText(txt)
            end
        end
    end

    local function walk(control, depth)
        if not control or (depth or 0) > 18 then return end
        rememberAndApply(control)
        if control.GetNumChildren and control.GetChild then
            local count = tonumber(control:GetNumChildren()) or 0
            for i = 1, count do
                local child = control:GetChild(i)
                if child then walk(child, (depth or 0) + 1) end
            end
        end
    end

    walk(self.statisticsWindow, 0)
end


-- 2.7.22: Dark Mode is intentionally monochrome. Cache the original visual
-- state before applying it so switching back to Transparent TPM restores the
-- original ESO/TPM colors instead of leaving grayscale residues behind.
function TPM:CacheStatisticsDarkVisualState()
    if self.statisticsDarkVisualCache then return end
    self.statisticsDarkVisualCache = setmetatable({}, { __mode = "k" })
end

function TPM:ApplyStatisticsDarkMonochrome()
    if not self.statisticsWindow then return end
    self:CacheStatisticsDarkVisualState()
    local cache=self.statisticsDarkVisualCache

    local function luminance(r,g,b)
        r,g,b=tonumber(r) or 0,tonumber(g) or 0,tonumber(b) or 0
        return Clamp(r*.299 + g*.587 + b*.114,0,1)
    end

    local function remember(control)
        if not control then return end
        local existing=cache[control]
        if existing then
            -- Refresh functions can replace a label's text while Clear Mode is
            -- active. If they introduce fresh semantic inline colors, remember
            -- that latest color sequence before converting it to white again.
            if control.GetText and control.SetText then
                local t=control:GetText()
                if type(t)=="string" and t:find("|c",1,true) then
                    local colors,hasNonWhite={},false
                    for hex in t:gmatch("|c(%x%x%x%x%x%x)") do
                        colors[#colors+1]=hex
                        if string.upper(hex)~="FFFFFF" then hasNonWhite=true end
                    end
                    if hasNonWhite and #colors>0 then existing.inlineColors=colors end
                end
            end
            return
        end
        local st={}
        if control.GetColor and control.SetColor then
            local r,g,b,a=control:GetColor()
            st.color={r,g,b,a}
        end
        if control.GetCenterColor and control.SetCenterColor then
            local r,g,b,a=control:GetCenterColor()
            st.center={r,g,b,a}
        end
        if control.GetEdgeColor and control.SetEdgeColor then
            local r,g,b,a=control:GetEdgeColor()
            st.edge={r,g,b,a}
        end
        if control.GetDesaturation and control.SetDesaturation then
            st.desaturation=control:GetDesaturation()
        end
        -- Inline |cRRGGBB markup bypasses SetColor(). Cache only the color-code
        -- sequence, not the complete text, so live values can keep updating while
        -- Clear Mode is active without being rolled back to stale text later.
        if control.GetText and control.SetText then
            local t=control:GetText()
            if type(t)=="string" and t:find("|c",1,true) then
                local colors={}
                for hex in t:gmatch("|c(%x%x%x%x%x%x)") do colors[#colors+1]=hex end
                if #colors>0 then st.inlineColors=colors end
            end
        end
        if next(st) then cache[control]=st end
    end

    local function apply(control,depth)
        if not control or (depth or 0)>22 then return end
        remember(control)
        local st=cache[control]

        -- STRICT DARK MODE: every tint becomes white. This catches labels,
        -- icons, alliance markers, currency icons, bars and decorative textures.
        -- Texture artwork keeps its alpha/detail but loses every hue.
        if control.GetColor and control.SetColor then
            local _,_,_,a=control:GetColor()
            control:SetColor(1,1,1,tonumber(a) or 1)
        end

        -- Backdrops/panel fills are either transparent black surfaces or white
        -- progress/value fills. Never leave yellow/orange/green/blue center colors.
        if control.GetCenterColor and control.SetCenterColor then
            local r,g,b,a=control:GetCenterColor()
            local y=luminance(r,g,b)
            a=tonumber(a) or 1
            if y >= .48 then
                control:SetCenterColor(1,1,1,Clamp(a,.28,1))
            else
                -- Keep the game world visible behind the journal.
                control:SetCenterColor(0,0,0,math.min(a,.52))
            end
        end

        -- All outlines are white only; alpha provides visual hierarchy instead
        -- of introducing gray/gold border colors.
        if control.GetEdgeColor and control.SetEdgeColor then
            local _,_,_,a=control:GetEdgeColor()
            control:SetEdgeColor(1,1,1,math.min(tonumber(a) or 1,.62))
        end

        if control.SetDesaturation then control:SetDesaturation(1) end

        -- ESO inline |cRRGGBB markup bypasses SetColor(), so strip all colored
        -- fragments to white while Dark Mode is active. Original text is cached
        -- and restored when another theme is selected.
        if control.GetText and control.SetText then
            local currentText=control:GetText()
            if type(currentText)=="string" and currentText:find("|c",1,true) then
                local mono=currentText:gsub("|c%x%x%x%x%x%x","|cFFFFFF")
                if mono ~= currentText then control:SetText(mono) end
            end
        end

        if control.GetNumChildren and control.GetChild then
            local n=tonumber(control:GetNumChildren()) or 0
            for i=1,n do
                local c=control:GetChild(i)
                if c then apply(c,(depth or 0)+1) end
            end
        end
    end

    apply(self.statisticsWindow,0)
    if self.statisticsThemeWindow and not self.statisticsThemeWindow:IsHidden() then apply(self.statisticsThemeWindow,0) end
    if self.economyFocusDropdown and not self.economyFocusDropdown:IsHidden() then apply(self.economyFocusDropdown,0) end

    -- Explicit root surfaces: black + transparent. These are applied after the
    -- recursive pass so a page-specific color can never shine through.
    local surfaces={
        self.statisticsOuterBackdrop,self.statisticsInnerBackdrop,
        self.statisticsEconomyPage,self.statisticsHistoryPage,self.statisticsPlayerPage,
        self.statisticsHistoryChart,self.statisticsHistorySessionBox,
        self.statisticsPlayerProfileBox,self.statisticsCharacterInsightBox,
        self.statisticsCharacterDailyBox,self.statisticsThemeWindowShell,
        self.statisticsThemeWindowInner,self.statisticsThemeColorShell,
        self.statisticsThemeColorInnerShell,self.statisticsThemeResetFrame
    }
    for _,surface in ipairs(surfaces) do
        if surface and surface.SetCenterColor then surface:SetCenterColor(0,0,0,.42) end
        if surface and surface.SetEdgeColor then surface:SetEdgeColor(1,1,1,.34) end
    end
    for _,card in ipairs(self.statisticsEconomyCards or {}) do
        if card and card.control then
            card.control:SetCenterColor(0,0,0,.36)
            card.control:SetEdgeColor(1,1,1,.28)
        end
    end
    for _,card in pairs(self.statisticsCharacterCards or {}) do
        if card and card.control then
            card.control:SetCenterColor(0,0,0,.34)
            card.control:SetEdgeColor(1,1,1,.30)
        end
    end

    -- Force the most visible journal widgets into a strict black/white palette
    -- even when their refresh routines later touch selection states or button
    -- emphasis. This keeps Clear Mode visually consistent across Progress,
    -- Economy, PvE/PvP, Character and the Customization window.
    local function monoText(control, r, g, b, a)
        if control and control.SetColor then control:SetColor(r or 1, g or 1, b or 1, a or 1) end
    end
    local function monoCenter(control, alpha)
        if control and control.SetCenterColor then control:SetCenterColor(0, 0, 0, alpha or .36) end
    end
    local function monoEdge(control, alpha)
        if control and control.SetEdgeColor then control:SetEdgeColor(1, 1, 1, alpha or .30) end
    end

    local whiteLabels = {
        self.statisticsTitle,self.statisticsThemeWindowTitle,self.statisticsThemeColorTitle,
        self.statisticsThemeDesignLabel,self.statisticsThemeWindowTitle,self.statisticsThemeColorTitle,
        self.statisticsZoneSortLabel,self.statisticsZoneFocusLabel,self.statisticsEconomyFocusLabel,
        self.statisticsPlayerPageSubtitle,self.statisticsCharacterDailyHint,
        self.statisticsEconomyDetailBody,self.statisticsCombatLegendLeft,self.statisticsCombatLegendRight,
        self.statisticsAllianceStatusLabel,self.statisticsAllianceMarkerLegendLabel
    }
    for _, control in ipairs(whiteLabels) do monoText(control, 1, 1, 1, 1) end

    local mutedLabels = {
        self.statisticsPlayerProfileText,self.statisticsPlayerMountText,
        self.statisticsEconomyProfileText,self.statisticsAllianceSummaryText
    }
    for _, control in ipairs(mutedLabels) do monoText(control, .92, .92, .92, 1) end

    local backdrops = {
        self.statisticsCategoryPageFrame,self.statisticsGoalsFrame,self.statisticsZoneFrame,
        self.statisticsThemeWindowShell,self.statisticsThemeWindowInner,
        self.statisticsThemeColorShell,self.statisticsThemeColorInnerShell,
        self.statisticsCustomizationWindow,self.statisticsCustomizationInner
    }
    for _, control in ipairs(backdrops) do monoCenter(control, .38); monoEdge(control, .30) end

    for _, btn in ipairs(self.statisticsThemeTabs or {}) do
        if btn.TPMBackdrop then monoCenter(btn.TPMBackdrop, .26); monoEdge(btn.TPMBackdrop, .34) end
        if btn.TPMAccent and btn.TPMAccent.SetCenterColor then btn.TPMAccent:SetCenterColor(1, 1, 1, .92) end
        if btn.SetNormalFontColor then btn:SetNormalFontColor(1,1,1,1) end
        if btn.SetMouseOverFontColor then btn:SetMouseOverFontColor(1,1,1,1); btn:SetPressedFontColor(.86,.86,.86,1) end
        if btn.SetDisabledFontColor then btn:SetDisabledFontColor(.55,.55,.55,1) end
    end

    for _, btn in ipairs(self.statisticsCharacterRangeButtons or {}) do
        if btn and btn.TPMBackdrop then monoCenter(btn.TPMBackdrop, .22); monoEdge(btn.TPMBackdrop, .30) end
        if btn and btn.SetNormalFontColor then btn:SetNormalFontColor(1,1,1,1) end
        if btn and btn.SetMouseOverFontColor then btn:SetMouseOverFontColor(1,1,1,1); btn:SetPressedFontColor(.85,.85,.85,1) end
    end

    for _, frame in ipairs(self.statisticsHistoryRangeBackdrops or {}) do monoCenter(frame, .22); monoEdge(frame, .28) end
    for _, frame in ipairs(self.statisticsCharacterRangeBackdrops or {}) do monoCenter(frame, .22); monoEdge(frame, .28) end

    -- Progress page category icons and values should never reintroduce warm hues.
    for _, row in ipairs(self.statisticsCategoryRows or {}) do
        if row.icon then monoText(row.icon, 1, 1, 1, .92) end
        if row.label then monoText(row.label, 1, 1, 1, 1) end
        if row.count then monoText(row.count, .92, .92, .92, 1) end
        if row.percent then monoText(row.percent, 1, 1, 1, 1) end
        if row.bg then monoCenter(row.bg, .24); monoEdge(row.bg, .18) end
        if row.bar then monoCenter(row.bar, .22); monoEdge(row.bar, .18) end
        if row.fill and row.fill.SetCenterColor then row.fill:SetCenterColor(1, 1, 1, .94) end
        if row.fill and row.fill.SetEdgeColor then row.fill:SetEdgeColor(1, 1, 1, .10) end
    end

    for _, row in ipairs(self.statisticsZoneRows or {}) do
        if row.completeIcon then monoText(row.completeIcon, 1, 1, 1, 1) end
        if row.nameLabel then monoText(row.nameLabel, 1, 1, 1, 1) end
        if row.percentLabel then monoText(row.percentLabel, 1, 1, 1, 1) end
        if row.doneLabel then monoText(row.doneLabel, .92, .92, .92, 1) end
        if row.openLabel then monoText(row.openLabel, 1, 1, 1, 1) end
        if row.bg then monoCenter(row.bg, .18); monoEdge(row.bg, .14) end
        if row.progressBg then monoCenter(row.progressBg, .20); monoEdge(row.progressBg, .12) end
        if row.progressFill and row.progressFill.SetCenterColor then row.progressFill:SetCenterColor(1, 1, 1, .94) end
    end

    if self.statisticsThemeGear and self.statisticsThemeGear.TPMIcon then monoText(self.statisticsThemeGear.TPMIcon, 1, 1, 1, 1) end
    for _, btn in ipairs({ self.statisticsSubPagePrev, self.statisticsSubPageNext, self.statisticsCategoryPrev, self.statisticsCategoryNext }) do
        if btn and btn.SetNormalFontColor then
            btn:SetNormalFontColor(1,1,1,1)
            if btn.SetMouseOverFontColor then btn:SetMouseOverFontColor(1,1,1,1) end
            if btn.SetPressedFontColor then btn:SetPressedFontColor(.82,.82,.82,1) end
        end
    end
    for _, btn in pairs(self.statisticsCategorySortButtons or {}) do
        if btn and btn.SetNormalFontColor then
            btn:SetNormalFontColor(1,1,1,1)
            if btn.SetMouseOverFontColor then btn:SetMouseOverFontColor(1,1,1,1) end
            if btn.SetPressedFontColor then btn:SetPressedFontColor(.82,.82,.82,1) end
        end
        if btn and btn.TPMBackdrop then monoCenter(btn.TPMBackdrop,.22); monoEdge(btn.TPMBackdrop,.26) end
    end
    if self.statisticsTopDivider then self.statisticsTopDivider:SetCenterColor(1, 1, 1, .34) end
    if self.statisticsFooterDivider then self.statisticsFooterDivider:SetCenterColor(1, 1, 1, .30) end
    if self.statisticsThemeWindowHeaderLine then self.statisticsThemeWindowHeaderLine:SetCenterColor(1, 1, 1, .30) end
    if self.statisticsThemeColorHeaderLine then self.statisticsThemeColorHeaderLine:SetCenterColor(1, 1, 1, .30) end
end

function TPM:RestoreStatisticsDarkVisualState()
    local cache=self.statisticsDarkVisualCache
    if not cache then return end
    for control,st in pairs(cache) do
        if control then
            if st.color and control.SetColor then control:SetColor(unpack(st.color)) end
            if st.center and control.SetCenterColor then control:SetCenterColor(unpack(st.center)) end
            if st.edge and control.SetEdgeColor then control:SetEdgeColor(unpack(st.edge)) end
            if st.desaturation~=nil and control.SetDesaturation then control:SetDesaturation(st.desaturation) end
            -- Restore the original inline colors in-place while preserving the
            -- CURRENT text/value content. This fixes white text fragments being
            -- left behind after switching from Clear Mode to another theme.
            if st.inlineColors and control.GetText and control.SetText then
                local txt=control:GetText()
                if type(txt)=="string" then
                    local index=0
                    local restored=txt:gsub("|cFFFFFF",function()
                        index=index+1
                        local hex=st.inlineColors[index]
                        return hex and ("|c"..hex) or "|cFFFFFF"
                    end)
                    if restored~=txt then control:SetText(restored) end
                end
            end
        end
    end
    self.statisticsDarkVisualCache=nil
end

-- 2.7.25: Page refresh functions in TPM still contain their original semantic
-- colors (gold, alliance colors, combat colors, currency colors). Dark Mode is
-- therefore re-enforced AFTER data refreshes, otherwise those refreshes paint
-- the old colors back over the monochrome skin.
function TPM:EnforceStatisticsDarkModeAfterRefresh()
    if not self.saved then return end
    local design = self.saved.statisticsThemeDesign
    -- Only legacy pure-dark monochrome wipes colors. Futuristic themes keep accents so names stay visible.
    if design ~= "dark" then return end
    if not self.statisticsWindow or self.statisticsWindow:IsHidden() then return end
    self:ApplyStatisticsDarkMonochrome()
end

-- 2.7.23: Fixed TPM Standard skin restored as a third stable theme.
-- It intentionally uses the original warm journal palette and does not expose
-- the removed RGB/custom-color editor.
function TPM:ApplyStatisticsTpmStandardFixed()
    local r,g,b=.95,.82,.36
    if self.statisticsOuterBackdrop then self.statisticsOuterBackdrop:SetCenterColor(.012,.011,.008,1); self.statisticsOuterBackdrop:SetEdgeColor(r,g,b,1) end
    if self.statisticsInnerBackdrop then self.statisticsInnerBackdrop:SetCenterColor(.035,.031,.024,1); self.statisticsInnerBackdrop:SetEdgeColor(r*.45,g*.45,b*.45,.78) end
    if self.statisticsEconomyPage then self.statisticsEconomyPage:SetCenterColor(.036,.032,.025,1); self.statisticsEconomyPage:SetEdgeColor(.34,.28,.16,.55) end
    for _,card in ipairs(self.statisticsEconomyCards or {}) do
        if card and card.control then
            if card.isGoldCard then card.control:SetCenterColor(.060,.046,.018,.995); card.control:SetEdgeColor(.82,.62,.14,.92)
            else card.control:SetCenterColor(.022,.021,.019,.99); card.control:SetEdgeColor(.20,.18,.14,.72) end
        end
    end
    if self.statisticsHistoryPage then self.statisticsHistoryPage:SetCenterColor(.040,.035,.026,1); self.statisticsHistoryPage:SetEdgeColor(.34,.28,.16,.55) end
    if self.statisticsHistoryChart then self.statisticsHistoryChart:SetCenterColor(.014,.014,.013,.995); self.statisticsHistoryChart:SetEdgeColor(.30,.27,.22,.62) end
    if self.statisticsHistorySessionBox then self.statisticsHistorySessionBox:SetCenterColor(.028,.026,.021,.98); self.statisticsHistorySessionBox:SetEdgeColor(.30,.27,.22,.62) end
    for _,x in ipairs(self.statisticsHistoryRangeBackdrops or {}) do x:SetCenterColor(.035,.031,.025,.96); x:SetEdgeColor(.30,.27,.22,.60) end
    if self.statisticsCombatBossBadge then self.statisticsCombatBossBadge:SetCenterColor(.045,.036,.020,.98); self.statisticsCombatBossBadge:SetEdgeColor(.45,.36,.18,.72) end
    if self.statisticsPlayerPage then self.statisticsPlayerPage:SetCenterColor(.055,.046,.030,1); self.statisticsPlayerPage:SetEdgeColor(.34,.27,.12,.94) end
    if self.statisticsPlayerProfileBox then self.statisticsPlayerProfileBox:SetCenterColor(.045,.037,.026,.96); self.statisticsPlayerProfileBox:SetEdgeColor(.42,.34,.17,.72) end
    if self.statisticsPlayerMountIconFrame then self.statisticsPlayerMountIconFrame:SetCenterColor(.025,.022,.018,.94); self.statisticsPlayerMountIconFrame:SetEdgeColor(.34,.29,.18,.68) end
    if self.statisticsPlayerProfileDivider then self.statisticsPlayerProfileDivider:SetColor(.34,.29,.18,.64) end
    if self.statisticsCharacterInsightBox then self.statisticsCharacterInsightBox:SetCenterColor(.035,.030,.024,.94); self.statisticsCharacterInsightBox:SetEdgeColor(.34,.29,.18,.64) end
    for _,x in ipairs(self.statisticsCharacterRangeBackdrops or {}) do x:SetCenterColor(.026,.023,.018,.94); x:SetEdgeColor(.35,.29,.14,.65) end
    if self.statisticsCharacterDailyBox then self.statisticsCharacterDailyBox:SetCenterColor(.035,.030,.024,.94); self.statisticsCharacterDailyBox:SetEdgeColor(.34,.29,.18,.64) end
    for _,card in pairs(self.statisticsCharacterCards or {}) do if card and card.control then card.control:SetCenterColor(.030,.027,.021,.985); card.control:SetEdgeColor(.42,.34,.17,.82) end end
    for _,btn in ipairs(self.statisticsThemeTabs or {}) do if btn.TPMBackdrop then btn.TPMBackdrop:SetCenterColor(.026,.023,.018,.94); btn.TPMBackdrop:SetEdgeColor(r*.42,g*.42,b*.42,.70) end end
    if self.statisticsThemeWindowShell then self.statisticsThemeWindowShell:SetCenterColor(.012,.011,.009,1); self.statisticsThemeWindowShell:SetEdgeColor(r,g,b,1) end
    if self.statisticsThemeWindowInner then self.statisticsThemeWindowInner:SetCenterColor(.035,.031,.024,1); self.statisticsThemeWindowInner:SetEdgeColor(r*.48,g*.48,b*.48,.92) end
end

function TPM:ApplyStatisticsTheme()
    if not self.saved then return end
    local design=self.saved.statisticsThemeDesign or "dark"
    if design ~= "dark" and self.statisticsDarkVisualCache then self:RestoreStatisticsDarkVisualState() end
    if not TPM.THEME_PRESETS[design] then design="dark" end
    self.saved.statisticsThemeDesign=design
    self.saved.statisticsThemeRGB=false
    -- Sync saved RGB slots from the selected futuristic preset
    if design ~= "tpm" and design ~= "vanilla" then
        self:ApplyThemePresetColors()
    end
    local preset = self.THEME_PRESETS[design] or self.THEME_PRESETS.dark
    local bg=self.saved.statisticsThemeBackground
    if type(bg) ~= "table" then
        bg = TPM_DeepCopyPlain(DEFAULTS.statisticsThemeBackground)
        self.saved.statisticsThemeBackground = bg
    end
    local br,bgG,bb,ba=Clamp(tonumber(bg.r) or .035,0,1),Clamp(tonumber(bg.g) or .031,0,1),Clamp(tonumber(bg.b) or .024,0,1),Clamp(tonumber(bg.a) or 1,0.20,1)
    if design == "vanilla" then
        br,bgG,bb,ba = 0.002,0.012,0.022,0.76
    elseif preset and preset.bg then
        br,bgG,bb,ba = preset.bg[1], preset.bg[2], preset.bg[3], preset.bg[4]
    end
    local r,g,b,a=self:GetStatisticsThemeAccentColor()
    local hr,hg,hb,ha=self:GetStatisticsThemeHeadingColor()
    local tr,tg,tb,ta=self:GetStatisticsThemeTextColor()
    local pr,pg,pb,pa=self:GetStatisticsThemeProgressColor()
    if self.statisticsOuterBackdrop then
        if design == "vanilla" then
            self.statisticsOuterBackdrop:SetCenterColor(.002,.008,.014,.80)
            self.statisticsOuterBackdrop:SetEdgeColor(r,g,b,.96)
        elseif preset and preset.bg then
            self.statisticsOuterBackdrop:SetCenterColor(preset.bg[1], preset.bg[2], preset.bg[3], preset.bg[4])
            self.statisticsOuterBackdrop:SetEdgeColor(preset.edge[1], preset.edge[2], preset.edge[3], preset.edge[4])
        else
            self.statisticsOuterBackdrop:SetCenterColor(0,0,0,.66)
            self.statisticsOuterBackdrop:SetEdgeColor(.62,.62,.62,.78)
        end
    end
    if self.statisticsInnerBackdrop then
        if design == "vanilla" then
            self.statisticsInnerBackdrop:SetCenterColor(.004,.016,.028,.68)
            self.statisticsInnerBackdrop:SetEdgeColor(r*.45,g*.45,b*.45,.64)
        elseif preset and preset.inner then
            self.statisticsInnerBackdrop:SetCenterColor(preset.inner[1], preset.inner[2], preset.inner[3], preset.inner[4])
            self.statisticsInnerBackdrop:SetEdgeColor(preset.edge[1]*0.7, preset.edge[2]*0.7, preset.edge[3]*0.7, 0.55)
        else
            self.statisticsInnerBackdrop:SetCenterColor(0,0,0,.42)
            self.statisticsInnerBackdrop:SetEdgeColor(.35,.35,.35,.58)
        end
    end
    if self.statisticsTitle and preset and preset.heading then
        self.statisticsTitle:SetColor(preset.heading[1], preset.heading[2], preset.heading[3], 1)
    end
    if self.statisticsVanillaThemeBands then
        for _,band in ipairs(self.statisticsVanillaThemeBands) do band:SetHidden(design ~= "vanilla") end
        if design == "vanilla" then
            -- Three very soft translucent bands approximate ESO's blue-black menu vignette
            -- without replacing any TPM panels or changing input behavior.
            local b1,b2,b3=self.statisticsVanillaThemeBands[1],self.statisticsVanillaThemeBands[2],self.statisticsVanillaThemeBands[3]
            if b1 then b1:SetCenterColor(.012,.035,.058,.13) end
            if b2 then b2:SetCenterColor(.004,.018,.034,.09) end
            if b3 then b3:SetCenterColor(.001,.009,.019,.15) end
        end
    end
    -- Page-level Transparent TPM transparency. Progress already uses the shared journal
    -- backdrop, while Economy and PvE/PvP have their own opaque page backdrops.
    -- Theme those page surfaces explicitly so all Statistics tabs have the same
    -- translucent blue-black Transparent TPM appearance.
    if self.statisticsEconomyPage then
        if design == "vanilla" then
            self.statisticsEconomyPage:SetCenterColor(.004,.016,.028,.30)
            self.statisticsEconomyPage:SetEdgeColor(r,g,b,.62)
        else
            self.statisticsEconomyPage:SetCenterColor(0,0,0,.26)
            self.statisticsEconomyPage:SetEdgeColor(.38,.38,.38,.46)
        end
    end
    for _,card in ipairs(self.statisticsEconomyCards or {}) do
        if card and card.control and card.control.SetCenterColor then
            if design == "vanilla" then
                if card.isGoldCard then
                    card.control:SetCenterColor(.018,.022,.024,.52)
                    card.control:SetEdgeColor(r,g,b,.72)
                else
                    card.control:SetCenterColor(.006,.018,.030,.46)
                    card.control:SetEdgeColor(.40,.34,.24,.54)
                end
            else
                if card.isGoldCard then
                    card.control:SetCenterColor(0,0,0,.38)
                    card.control:SetEdgeColor(.46,.46,.46,.52)
                else
                    card.control:SetCenterColor(0,0,0,.32)
                    card.control:SetEdgeColor(.36,.36,.36,.46)
                end
            end
        end
    end
    if self.statisticsHistoryPage then
        if design == "vanilla" then
            self.statisticsHistoryPage:SetCenterColor(.004,.016,.028,.30)
            self.statisticsHistoryPage:SetEdgeColor(r,g,b,.62)
        else
            self.statisticsHistoryPage:SetCenterColor(0,0,0,.26)
            self.statisticsHistoryPage:SetEdgeColor(.38,.38,.38,.46)
        end
    end
    if self.statisticsHistoryChart then
        if design == "vanilla" then
            self.statisticsHistoryChart:SetCenterColor(.003,.012,.022,.48)
            self.statisticsHistoryChart:SetEdgeColor(.42,.35,.23,.48)
        else
            self.statisticsHistoryChart:SetCenterColor(0,0,0,.34)
            self.statisticsHistoryChart:SetEdgeColor(.15,.15,.15,.60)
        end
    end
    if self.statisticsHistorySessionBox then
        if design == "vanilla" then
            self.statisticsHistorySessionBox:SetCenterColor(.006,.017,.028,.46)
            self.statisticsHistorySessionBox:SetEdgeColor(.42,.35,.23,.50)
        else
            self.statisticsHistorySessionBox:SetCenterColor(0,0,0,.34)
            self.statisticsHistorySessionBox:SetEdgeColor(.16,.16,.16,.60)
        end
    end
    for _,rangeBg in ipairs(self.statisticsHistoryRangeBackdrops or {}) do
        if rangeBg and rangeBg.SetCenterColor then
            if design == "vanilla" then
                rangeBg:SetCenterColor(.006,.018,.030,.42)
                rangeBg:SetEdgeColor(.42,.35,.23,.48)
            else
                rangeBg:SetCenterColor(0,0,0,.30)
                rangeBg:SetEdgeColor(.16,.17,.18,.60)
            end
        end
    end
    if self.statisticsCombatBossBadge then
        if design == "vanilla" then
            self.statisticsCombatBossBadge:SetCenterColor(.010,.020,.030,.48)
            self.statisticsCombatBossBadge:SetEdgeColor(r,g,b,.62)
        else
            self.statisticsCombatBossBadge:SetCenterColor(0,0,0,.32)
            self.statisticsCombatBossBadge:SetEdgeColor(.22,.22,.20,.68)
        end
    end

    if self.statisticsPlayerPage then
        if design == "vanilla" then
            self.statisticsPlayerPage:SetCenterColor(.004,.016,.028,.30)
            self.statisticsPlayerPage:SetEdgeColor(r,g,b,.62)
        else
            self.statisticsPlayerPage:SetCenterColor(0,0,0,.26)
            self.statisticsPlayerPage:SetEdgeColor(.38,.38,.38,.46)
        end
    end
    if self.statisticsPlayerProfileBox then
        if design == "vanilla" then
            self.statisticsPlayerProfileBox:SetCenterColor(.006,.018,.030,.48)
            self.statisticsPlayerProfileBox:SetEdgeColor(r,g,b,.58)
        else
            self.statisticsPlayerProfileBox:SetCenterColor(0,0,0,.34)
            self.statisticsPlayerProfileBox:SetEdgeColor(.16,.17,.18,.66)
        end
    end
    if self.statisticsPlayerMountIconFrame then
        if design == "vanilla" then
            self.statisticsPlayerMountIconFrame:SetCenterColor(.004,.015,.027,.52)
            self.statisticsPlayerMountIconFrame:SetEdgeColor(.42,.35,.23,.56)
        else
            self.statisticsPlayerMountIconFrame:SetCenterColor(0,0,0,.34)
            self.statisticsPlayerMountIconFrame:SetEdgeColor(.18,.18,.17,.64)
        end
    end
    if self.statisticsPlayerProfileDivider then
        if design == "vanilla" then self.statisticsPlayerProfileDivider:SetColor(.42,.35,.23,.52)
        else self.statisticsPlayerProfileDivider:SetColor(.18,.18,.18,.58) end
    end
    if self.statisticsCharacterInsightBox then
        if design == "vanilla" then
            self.statisticsCharacterInsightBox:SetCenterColor(.004,.015,.027,.44)
            self.statisticsCharacterInsightBox:SetEdgeColor(.42,.35,.23,.50)
        else
            self.statisticsCharacterInsightBox:SetCenterColor(0,0,0,.30)
            self.statisticsCharacterInsightBox:SetEdgeColor(.15,.16,.17,.62)
        end
    end
    for _,rangeBg in ipairs(self.statisticsCharacterRangeBackdrops or {}) do
        if design == "vanilla" then rangeBg:SetCenterColor(.006,.018,.030,.42); rangeBg:SetEdgeColor(.42,.35,.23,.48)
        else rangeBg:SetCenterColor(0,0,0,.28); rangeBg:SetEdgeColor(.16,.17,.18,.60) end
    end
    if self.statisticsCharacterDailyBox then
        if design == "vanilla" then
            self.statisticsCharacterDailyBox:SetCenterColor(.004,.015,.027,.44)
            self.statisticsCharacterDailyBox:SetEdgeColor(.42,.35,.23,.50)
        else
            self.statisticsCharacterDailyBox:SetCenterColor(0,0,0,.30)
            self.statisticsCharacterDailyBox:SetEdgeColor(.15,.16,.17,.62)
        end
    end
    for _,card in pairs(self.statisticsCharacterCards or {}) do
        if card and card.control then
            if design == "vanilla" then
                card.control:SetCenterColor(.006,.018,.030,.48)
                card.control:SetEdgeColor(r,g,b,.58)
            else
                card.control:SetCenterColor(0,0,0,.32)
                card.control:SetEdgeColor(.16,.17,.18,.66)
            end
        end
    end

    if self.statisticsTitle then self.statisticsTitle:SetColor(hr,hg,hb,ha) end
    -- Theme journal section headings independently from decorative accents. Data,
    -- status and Alliance marker colors stay untouched so they keep meaning.
    local headingNames={
        "statisticsCategoryTitle","statisticsGoalsTitle","statisticsZoneTitle",
        "statisticsEconomyPageTitle","statisticsEconomyTrackingTitle",
        "statisticsHistoryTitle","statisticsHistorySessionTitle","statisticsCombatChartTitle",
        "statisticsCombatActivityRightTitle","statisticsCombatExamplesTitle",
        "statisticsAllianceDetailsTitle","statisticsAllianceGapTitle","statisticsAllianceMapTitle",
        "statisticsAllianceNextTitle","statisticsAllianceOwnTitle","statisticsAllianceQuickTitle",
        "statisticsAllianceToolsTitle","statisticsAllianceZoneTitle","statisticsAllianceZoomTitle",
        "statisticsPlayerProfileTitle","statisticsPlayerMountTitle","statisticsCharacterDailyTitle"
    }
    for _,name in ipairs(headingNames) do local h=self[name]; if h and h.SetColor then h:SetColor(hr,hg,hb,1) end end
    if self.statisticsThemeGear and self.statisticsThemeGear.TPMIcon then self.statisticsThemeGear.TPMIcon:SetColor(r,g,b,1) end
    if self.statisticsTopDivider then self.statisticsTopDivider:SetCenterColor(r,g,b,design=="dark" and .45 or .68) end
    if self.statisticsFooterDivider then self.statisticsFooterDivider:SetCenterColor(r,g,b,design=="dark" and .42 or .62) end
    for _,o in ipairs(self.statisticsCornerOrnaments or {}) do o:SetColor(r,g,b,design=="dark" and .58 or .88) end
    local selectedRange=tonumber(self.saved.statisticsCharacterRangeDays) or 7
    for _,btn in ipairs(self.statisticsCharacterRangeButtons or {}) do
        if tonumber(btn.rangeDays)==selectedRange then btn:SetNormalFontColor(pr,pg,pb,1) end
    end
    for _,btn in ipairs(self.statisticsThemeTabs or {}) do
        if btn.TPMBackdrop then
            if design == "vanilla" then btn.TPMBackdrop:SetCenterColor(.004,.016,.027,.90) else btn.TPMBackdrop:SetCenterColor(.006,.007,.008,.98) end
            if design == "vanilla" then
                btn.TPMBackdrop:SetEdgeColor(r,g,b,.76)
            else
                btn.TPMBackdrop:SetEdgeColor(.16,.17,.18,.70)
            end
        end
        if btn.TPMAccent then btn.TPMAccent:SetCenterColor(r,g,b,.88) end
        if btn.SetNormalFontColor then
            btn:SetNormalFontColor(tr,tg,tb,1)
        end
        if btn.SetMouseOverFontColor then btn:SetMouseOverFontColor(r,g,b,1); btn:SetPressedFontColor(r*.95,g*.95,b*.95,1) end
    end
    if self.statisticsThemeHeadingSwatch then self.statisticsThemeHeadingSwatch:SetCenterColor(hr,hg,hb,1); self.statisticsThemeHeadingSwatch:SetEdgeColor(hr*.75,hg*.75,hb*.75,1) end
    if self.statisticsThemeAccentSwatch then self.statisticsThemeAccentSwatch:SetCenterColor(r,g,b,1); self.statisticsThemeAccentSwatch:SetEdgeColor(r*.75,g*.75,b*.75,1) end
    if self.statisticsThemeTextSwatch then self.statisticsThemeTextSwatch:SetCenterColor(tr,tg,tb,1); self.statisticsThemeTextSwatch:SetEdgeColor(tr*.75,tg*.75,tb*.75,1) end
    if self.statisticsThemeProgressSwatch then self.statisticsThemeProgressSwatch:SetCenterColor(pr,pg,pb,1); self.statisticsThemeProgressSwatch:SetEdgeColor(pr*.75,pg*.75,pb*.75,1) end
    if self.statisticsThemeBackgroundSwatch then self.statisticsThemeBackgroundSwatch:SetCenterColor(br,bgG,bb,ba); self.statisticsThemeBackgroundSwatch:SetEdgeColor(r*.75,g*.75,b*.75,1) end
    if self.statisticsThemeWindowShell then
        if design=="vanilla" then
            self.statisticsThemeWindowShell:SetCenterColor(.002,.009,.016,.82)
            self.statisticsThemeWindowShell:SetEdgeColor(r,g,b,.96)
        else
            self.statisticsThemeWindowShell:SetCenterColor(0,0,0,.68)
            self.statisticsThemeWindowShell:SetEdgeColor(.60,.60,.60,.72)
        end
    end
    if self.statisticsThemeWindowInner then
        if design=="vanilla" then
            self.statisticsThemeWindowInner:SetCenterColor(.005,.018,.031,.70)
            self.statisticsThemeWindowInner:SetEdgeColor(r*.48,g*.48,b*.48,.72)
        else
            self.statisticsThemeWindowInner:SetCenterColor(0,0,0,.42)
            self.statisticsThemeWindowInner:SetEdgeColor(.36,.36,.36,.56)
        end
    end
    if self.statisticsThemeWindowTitle then self.statisticsThemeWindowTitle:SetColor(hr,hg,hb,1) end
    if self.statisticsThemeWindowHeaderLine then self.statisticsThemeWindowHeaderLine:SetCenterColor(r,g,b,.72) end
    if self.statisticsThemeResetFrame then self.statisticsThemeResetFrame:SetEdgeColor(r*.48,g*.48,b*.48,.9) end
    for _,o in ipairs(self.statisticsThemeWindowOrnaments or {}) do o:SetColor(r,g,b,.88) end
    if self.statisticsThemeColorShell then
        if design=="vanilla" then
            self.statisticsThemeColorShell:SetCenterColor(.002,.009,.016,.82)
            self.statisticsThemeColorShell:SetEdgeColor(r,g,b,.96)
        else
            self.statisticsThemeColorShell:SetCenterColor(.012,.011,.009,1)
            self.statisticsThemeColorShell:SetEdgeColor(r,g,b,1)
        end
    end
    if self.statisticsThemeColorInnerShell then
        if design=="vanilla" then
            self.statisticsThemeColorInnerShell:SetCenterColor(.005,.018,.031,.70)
            self.statisticsThemeColorInnerShell:SetEdgeColor(r*.48,g*.48,b*.48,.66)
        else
            self.statisticsThemeColorInnerShell:SetCenterColor(.035,.031,.024,1)
            self.statisticsThemeColorInnerShell:SetEdgeColor(r*.48,g*.48,b*.48,.78)
        end
    end
    if self.statisticsThemeColorTitle then self.statisticsThemeColorTitle:SetColor(hr,hg,hb,1) end
    if self.statisticsThemeColorHeaderLine then self.statisticsThemeColorHeaderLine:SetCenterColor(r,g,b,.78) end
    if self.statisticsThemeColorCloseFrame then self.statisticsThemeColorCloseFrame:SetEdgeColor(r*.48,g*.48,b*.48,.9) end
    for _,o in ipairs(self.statisticsThemeColorOrnaments or {}) do o:SetColor(r,g,b,.88) end

    -- Recolor legacy hard-coded gold/yellow accents across the complete Statistics
    -- window so the chosen Accent/RGB color is applied consistently.
    self:ApplyStatisticsThemeToLegacyAccents(r,g,b,pr,pg,pb,hr,hg,hb,tr,tg,tb)
    if design == "tpm" then self:ApplyStatisticsTpmStandardFixed() end
    if design == "dark" then self:ApplyStatisticsDarkMonochrome() end
end

function TPM:ApplyStatisticsThemeProgressFast()
    if not self.saved or not self.statisticsWindow then return end
    local pr,pg,pb=self:GetStatisticsThemeProgressColor()
    local tagged=self.statisticsThemeLegacyAccentControls or {}
    local function apply(control,role)
        if not control or type(role)~="table" then return end
        if role.colorAlpha and role.colorChannel=="progress" and control.SetColor then control:SetColor(pr,pg,pb,role.colorAlpha) end
        if role.centerAlpha and role.centerChannel=="progress" and control.SetCenterColor then control:SetCenterColor(pr,pg,pb,role.centerAlpha) end
        if role.inlineGold and role.inlineChannel=="progress" and control.GetText and control.SetText then
            local txt=control:GetText()
            if type(txt)=="string" then
                local hex=string.format("%02X%02X%02X",math.floor(Clamp(pr,0,1)*255+.5),math.floor(Clamp(pg,0,1)*255+.5),math.floor(Clamp(pb,0,1)*255+.5))
                if role.lastInlineHex then txt=txt:gsub("|c"..role.lastInlineHex,"|c"..hex) else txt=txt:gsub("|cE6C45C","|c"..hex) end
                role.lastInlineHex=hex; control:SetText(txt)
            end
        end
    end
    for control,role in pairs(tagged) do apply(control,role) end
    if self.statisticsThemeProgressSwatch then self.statisticsThemeProgressSwatch:SetCenterColor(pr,pg,pb,1); self.statisticsThemeProgressSwatch:SetEdgeColor(pr*.75,pg*.75,pb*.75,1) end
    local selectedRange=tonumber(self.saved.statisticsCharacterRangeDays) or 7
    for _,btn in ipairs(self.statisticsCharacterRangeButtons or {}) do if tonumber(btn.rangeDays)==selectedRange then btn:SetNormalFontColor(pr,pg,pb,1) end end
end

function TPM:StartStatisticsThemeRGBUpdate()
    EVENT_MANAGER:UnregisterForUpdate(ADDON_NAME.."ThemeRGB")
    if self.saved then self.saved.statisticsThemeRGB=false end
end

function TPM:GetStatisticsThemeColorPickerText(key)
    local texts = {
        de={title="Farbauswahl",red="Rot",green="Grün",blue="Blau",close="Schließen"},
        en={title="Color Selection",red="Red",green="Green",blue="Blue",close="Close"},
        fr={title="Sélection de couleur",red="Rouge",green="Vert",blue="Bleu",close="Fermer"},
        es={title="Selección de color",red="Rojo",green="Verde",blue="Azul",close="Cerrar"},
        ru={title="Выбор цвета",red="Красный",green="Зелёный",blue="Синий",close="Закрыть"},
    }
    local lang=texts[self.langCode] or texts.en
    return lang[key] or texts.en[key] or key
end

local function TPM_ThemeColorKey(which)
    if which=="background" then return "statisticsThemeBackground",DEFAULTS.statisticsThemeBackground end
    if which=="heading" then return "statisticsThemeHeading",DEFAULTS.statisticsThemeHeading end
    if which=="progress" then return "statisticsThemeProgress",DEFAULTS.statisticsThemeProgress end
    if which=="text" then return "statisticsThemeText",DEFAULTS.statisticsThemeText end
    return "statisticsThemeAccent",DEFAULTS.statisticsThemeAccent
end

function TPM:RefreshStatisticsThemeColorPicker()
    local w=self.statisticsThemeColorWindow
    if not w or not self.statisticsThemeColorWhich then return end
    local which=self.statisticsThemeColorWhich
    local key,d=TPM_ThemeColorKey(which)
    local c=(self.saved and self.saved[key]) or d
    if self.statisticsThemeColorTitle then self.statisticsThemeColorTitle:SetText(self:GetStatisticsThemeColorPickerText("title")) end
    if self.statisticsThemeColorRedLabel then self.statisticsThemeColorRedLabel:SetText(self:GetStatisticsThemeColorPickerText("red")..": "..tostring(math.floor((tonumber(c.r) or 0)*255+.5))) end
    if self.statisticsThemeColorGreenLabel then self.statisticsThemeColorGreenLabel:SetText(self:GetStatisticsThemeColorPickerText("green")..": "..tostring(math.floor((tonumber(c.g) or 0)*255+.5))) end
    if self.statisticsThemeColorBlueLabel then self.statisticsThemeColorBlueLabel:SetText(self:GetStatisticsThemeColorPickerText("blue")..": "..tostring(math.floor((tonumber(c.b) or 0)*255+.5))) end
    if self.statisticsThemeColorCloseButton then self.statisticsThemeColorCloseButton:SetText(self:GetStatisticsThemeColorPickerText("close")) end
    if self.statisticsThemeColorPreview then self.statisticsThemeColorPreview:SetCenterColor(tonumber(c.r) or 0,tonumber(c.g) or 0,tonumber(c.b) or 0,1) end
end

function TPM:CreateStatisticsThemeColorPicker()
    if self.statisticsThemeColorWindow or not WINDOW_MANAGER or not GuiRoot then return end
    local w=WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME.."StatisticsThemeColorWindow")
    w:SetDimensions(430,355)
    w:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
    w:SetDrawLayer(DL_OVERLAY)
    w:SetDrawTier(DT_HIGH)
    if w.SetDrawLevel then w:SetDrawLevel(20000) end
    w:SetMouseEnabled(true)
    w:SetMovable(true)
    w:SetClampedToScreen(true)
    w:SetHidden(true)
    self.statisticsThemeColorWindow=w

    -- Match the main Statistics journal visually without changing picker behavior.
    self.statisticsThemeColorOrnaments = {}

    local shell=WINDOW_MANAGER:CreateControl(nil,w,CT_BACKDROP)
    shell:SetAnchorFill(w)
    shell:SetCenterColor(.012,.011,.009,1)
    shell:SetEdgeColor(.82,.67,.28,1)
    shell:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds",128,16,2)
    shell:SetInsets(8,8,-8,-8)
    shell:SetMouseEnabled(true)
    self.statisticsThemeColorShell=shell

    local innerShell=WINDOW_MANAGER:CreateControl(nil,w,CT_BACKDROP)
    innerShell:SetAnchor(TOPLEFT,w,TOPLEFT,5,5)
    innerShell:SetAnchor(BOTTOMRIGHT,w,BOTTOMRIGHT,-5,-5)
    innerShell:SetCenterColor(.035,.031,.024,1)
    innerShell:SetEdgeColor(.38,.29,.12,.78)
    innerShell:SetEdgeTexture(nil,1,1,1)
    innerShell:SetMouseEnabled(false)
    self.statisticsThemeColorInnerShell=innerShell

    local cornerDefs={
        {TOPLEFT,TOPLEFT,7,7,"NagaMapaCompleto/art/journal_corner_tl.dds"},
        {TOPRIGHT,TOPRIGHT,-7,7,"NagaMapaCompleto/art/journal_corner_tr.dds"},
        {BOTTOMLEFT,BOTTOMLEFT,7,-7,"NagaMapaCompleto/art/journal_corner_bl.dds"},
        {BOTTOMRIGHT,BOTTOMRIGHT,-7,-7,"NagaMapaCompleto/art/journal_corner_br.dds"},
    }
    for _,d in ipairs(cornerDefs) do
        local o=WINDOW_MANAGER:CreateControl(nil,w,CT_TEXTURE)
        o:SetDimensions(24,24); o:SetAnchor(d[1],w,d[2],d[3],d[4]); o:SetTexture(d[5])
        o:SetColor(.96,.78,.30,.88); o:SetMouseEnabled(false)
        if o.SetDrawLevel then o:SetDrawLevel(40) end
        self.statisticsThemeColorOrnaments[#self.statisticsThemeColorOrnaments+1]=o
    end

    local header=WINDOW_MANAGER:CreateControl(nil,w,CT_BACKDROP)
    header:SetAnchor(TOPLEFT,w,TOPLEFT,8,8)
    header:SetAnchor(TOPRIGHT,w,TOPRIGHT,-8,8)
    header:SetHeight(48)
    header:SetCenterColor(.022,.020,.015,1)
    header:SetEdgeColor(.28,.23,.12,1)
    header:SetMouseEnabled(true)
    self.statisticsThemeColorHeader=header

    local headerLine=WINDOW_MANAGER:CreateControl(nil,w,CT_BACKDROP)
    headerLine:SetDimensions(388,2); headerLine:SetAnchor(TOP,w,TOP,0,58)
    headerLine:SetCenterColor(.95,.82,.36,.78); headerLine:SetEdgeColor(0,0,0,0)
    self.statisticsThemeColorHeaderLine=headerLine
    header:SetHandler("OnMouseDown",function(_,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and w.StartMoving then w:StartMoving() end
    end)
    header:SetHandler("OnMouseUp",function(_,button)
        if button==MOUSE_BUTTON_INDEX_LEFT and w.StopMovingOrResizing then w:StopMovingOrResizing() end
    end)

    local title=WINDOW_MANAGER:CreateControl(nil,w,CT_LABEL)
    title:SetDimensions(330,42)
    title:SetAnchor(TOPLEFT,w,TOPLEFT,20,12)
    title:SetFont("ZoFontWinH2")
    title:SetColor(.96,.82,.36,1)
    title:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.statisticsThemeColorTitle=title

    local x=WINDOW_MANAGER:CreateControl(nil,w,CT_BUTTON)
    x:SetDimensions(42,42)
    x:SetAnchor(TOPRIGHT,w,TOPRIGHT,-14,12)
    x:SetFont("ZoFontWinH3")
    x:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    x:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    x:SetText("X")
    x:SetNormalFontColor(.82,.76,.62,1)
    x:SetMouseOverFontColor(1,.86,.38,1)
    x:SetHandler("OnClicked",function() w:SetHidden(true) end)

    local preview=WINDOW_MANAGER:CreateControl(nil,w,CT_BACKDROP)
    preview:SetDimensions(388,56)
    preview:SetAnchor(TOP,w,TOP,0,78)
    preview:SetCenterColor(1,1,1,1)
    preview:SetEdgeColor(.72,.59,.25,1)
    preview:SetEdgeTexture(nil,1,1,1)
    self.statisticsThemeColorPreview=preview

    local function makeSlider(y,channel)
        local lab=WINDOW_MANAGER:CreateControl(nil,w,CT_LABEL)
        lab:SetDimensions(380,24)
        lab:SetAnchor(TOPLEFT,w,TOPLEFT,24,y)
        lab:SetFont("$(MEDIUM_FONT)|17")
        lab:SetColor(.88,.84,.74,1)
        local sl=WINDOW_MANAGER:CreateControl(nil,w,CT_SLIDER)
        sl:SetDimensions(380,20)
        sl:SetAnchor(TOPLEFT,w,TOPLEFT,24,y+28)
        sl:SetOrientation(ORIENTATION_HORIZONTAL)
        sl:SetMouseEnabled(true)
        local elev="/esoui/art/miscellaneous/scrollbox_elevator.dds"
        sl:SetThumbTexture(elev,elev,elev,22,22,0,0,1,1)
        if sl.SetBackgroundMiddleTexture then sl:SetBackgroundMiddleTexture("/esoui/art/chatwindow/chat_scrollbar_track.dds",0,0,1,1) end
        sl:SetMinMax(0,255)
        sl:SetValueStep(1)
        sl:SetHandler("OnValueChanged",function(_,v)
            if TPM.statisticsThemeColorPickerUpdating then return end
            local which=TPM.statisticsThemeColorWhich
            if not which or not TPM.saved then return end
            local key,d=TPM_ThemeColorKey(which)
            local c=TPM.saved[key] or d
            local n={r=tonumber(c.r) or 0,g=tonumber(c.g) or 0,b=tonumber(c.b) or 0,a=tonumber(c.a) or tonumber(d.a) or 1}
            n[channel]=Clamp((tonumber(v) or 0)/255,0,1)
            TPM.saved[key]=n
            TPM:ApplyStatisticsTheme()
            TPM:RefreshStatisticsThemeColorPicker()
        end)
        return lab,sl
    end
    self.statisticsThemeColorRedLabel,self.statisticsThemeColorRedSlider=makeSlider(145,"r")
    self.statisticsThemeColorGreenLabel,self.statisticsThemeColorGreenSlider=makeSlider(205,"g")
    self.statisticsThemeColorBlueLabel,self.statisticsThemeColorBlueSlider=makeSlider(265,"b")

    local closeFrame=WINDOW_MANAGER:CreateControl(nil,w,CT_BACKDROP)
    closeFrame:SetDimensions(180,32); closeFrame:SetAnchor(BOTTOM,w,BOTTOM,0,-10)
    closeFrame:SetCenterColor(.055,.047,.030,1); closeFrame:SetEdgeColor(.46,.36,.16,.9); closeFrame:SetEdgeTexture(nil,1,1,1)
    self.statisticsThemeColorCloseFrame=closeFrame

    local close=WINDOW_MANAGER:CreateControl(nil,w,CT_BUTTON)
    close:SetDimensions(180,32)
    close:SetAnchor(BOTTOM,w,BOTTOM,0,-10)
    close:SetFont("$(BOLD_FONT)|16")
    close:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    close:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    close:SetNormalFontColor(.90,.84,.67,1)
    close:SetMouseOverFontColor(1,.88,.38,1)
    close:SetHandler("OnClicked",function() w:SetHidden(true) end)
    self.statisticsThemeColorCloseButton=close
end

function TPM:OpenStatisticsThemeColorPicker(which)
    if not self.saved then return end
    self:CreateStatisticsThemeColorPicker()
    if not self.statisticsThemeColorWindow then return end
    self.statisticsThemeColorWhich=which
    local key,d=TPM_ThemeColorKey(which)
    local c=self.saved[key] or d
    self.statisticsThemeColorPickerUpdating=true
    if self.statisticsThemeColorRedSlider then self.statisticsThemeColorRedSlider:SetValue(math.floor((tonumber(c.r) or 0)*255+.5)) end
    if self.statisticsThemeColorGreenSlider then self.statisticsThemeColorGreenSlider:SetValue(math.floor((tonumber(c.g) or 0)*255+.5)) end
    if self.statisticsThemeColorBlueSlider then self.statisticsThemeColorBlueSlider:SetValue(math.floor((tonumber(c.b) or 0)*255+.5)) end
    self.statisticsThemeColorPickerUpdating=false
    self:RefreshStatisticsThemeColorPicker()
    self.statisticsThemeColorWindow:ClearAnchors()
    self.statisticsThemeColorWindow:SetAnchor(CENTER,GuiRoot,CENTER,0,0)
    if self.statisticsThemeColorWindow.BringWindowToTop then self.statisticsThemeColorWindow:BringWindowToTop() end
    self.statisticsThemeColorWindow:SetHidden(false)
end

function TPM:ResetStatisticsTheme()
    if not self.saved then return end
    self.saved.statisticsThemeDesign="tpm"
    self.saved.statisticsThemeRGB=false
    self:StartStatisticsThemeRGBUpdate()
    self:RefreshStatisticsThemeWindow()
    self:ApplyStatisticsTheme()
end

function TPM:RefreshStatisticsThemeWindow()
    if not self.statisticsThemeWindow or not self.saved then return end
    local design = self.saved.statisticsThemeDesign or "cyber"
    if not TPM.THEME_PRESETS[design] then
        design = "cyber"
        self.saved.statisticsThemeDesign = design
    end
    self.saved.statisticsThemeRGB = false
    if self.statisticsThemeWindowTitle then
        self.statisticsThemeWindowTitle:SetText(self:GetStatisticsThemeText("title"))
    end
    if self.statisticsThemeDesignLabel then
        self.statisticsThemeDesignLabel:SetText(self:GetStatisticsThemeText("design"))
    end

    -- Highlight the active theme among all futuristic + classic buttons
    for key, entry in pairs(self.statisticsThemeDesignButtons or {}) do
        local selected = (key == design)
        local preset = self.THEME_PRESETS[key]
        local label = (preset and preset.label) or key
        -- Prefer localized short name when available
        local locKey = ({ tpm = "designTpm", vanilla = "designVanilla", dark = "dark", cyber = "cyber", neon = "neon", arctic = "arctic", ember = "ember", matrix = "matrix" })[key]
        if locKey then
            local loc = self:GetStatisticsThemeText(locKey)
            if loc and loc ~= locKey then label = loc end
        end
        if entry.button then
            entry.button:SetText(label)
            if selected then
                entry.button:SetNormalFontColor(1, 1, 1, 1)
            else
                entry.button:SetNormalFontColor(0.78, 0.82, 0.88, 1)
            end
        end
        if entry.frame then
            if selected and preset and preset.edge then
                entry.frame:SetCenterColor(preset.bg[1], preset.bg[2], preset.bg[3], 0.95)
                entry.frame:SetEdgeColor(preset.edge[1], preset.edge[2], preset.edge[3], 0.98)
            else
                entry.frame:SetCenterColor(0.02, 0.025, 0.03, 0.90)
                entry.frame:SetEdgeColor(0.35, 0.40, 0.48, 0.55)
            end
        end
    end
    self:ApplyStatisticsTheme()
end

function TPM:SetStatisticsThemeDesign(design)
    if not self.saved then return end
    if not self.THEME_PRESETS[design] then design = "dark" end
    self.saved.statisticsThemeDesign = design
    self:ApplyThemePresetColors()
    self:ApplyStatisticsTheme()
    if self.statisticsWindow and not self.statisticsWindow:IsHidden() then
        self:RefreshStatisticsWindow()
    end
    if self.RefreshStatisticsThemeWindow then self:RefreshStatisticsThemeWindow() end
end

function TPM:CycleStatisticsTheme()
    local order = { "dark", "cyber", "neon", "arctic", "ember", "matrix", "tpm", "vanilla" }
    local current = self.saved and self.saved.statisticsThemeDesign or "dark"
    local idx = 1
    for i, key in ipairs(order) do
        if key == current then idx = i break end
    end
    local nextKey = order[(idx % #order) + 1]
    self:SetStatisticsThemeDesign(nextKey)
    local preset = self.THEME_PRESETS[nextKey]
    d("|c5EC8F0Naga Mapa Completo|r tema: " .. (preset and preset.label or nextKey))
end

-- 2.7.20: Custom color/RGB editor removed. The panel now intentionally offers
-- three stable fixed skins: TPM Standard, Transparent TPM and Dark Mode.
function TPM:CreateStatisticsThemeWindow()
    if self.statisticsThemeWindow or not self.statisticsWindow then return end
    local parent = self.statisticsWindow
    local w = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "StatisticsThemeWindow")
    -- Taller panel to fit all futuristic themes
    w:SetDimensions(360, 420)
    w:SetAnchor(TOPLEFT, parent, TOPRIGHT, 8, 0)
    w:SetDrawLayer(DL_OVERLAY)
    w:SetDrawTier(DT_HIGH)
    if w.SetDrawLevel then w:SetDrawLevel(12000) end
    w:SetMouseEnabled(true)
    w:SetMovable(false)
    w:SetClampedToScreen(false)
    w:SetHidden(true)
    self.statisticsThemeWindow = w

    local shell = WINDOW_MANAGER:CreateControl(nil, w, CT_BACKDROP)
    shell:SetAnchorFill(w)
    shell:SetCenterColor(0.006, 0.010, 0.014, 0.96)
    shell:SetEdgeColor(0.30, 0.65, 0.85, 0.95)
    shell:SetEdgeTexture(nil, 1, 1, 2)
    shell:SetInsets(2, 2, -2, -2)
    shell:SetMouseEnabled(true)
    self.statisticsThemeWindowShell = shell

    self.statisticsThemeWindowOrnaments = {}
    local defs = {
        { TOPLEFT, TOPLEFT, 7, 7, "NagaMapaCompleto/art/journal_corner_tl.dds" },
        { TOPRIGHT, TOPRIGHT, -7, 7, "NagaMapaCompleto/art/journal_corner_tr.dds" },
        { BOTTOMLEFT, BOTTOMLEFT, 7, -7, "NagaMapaCompleto/art/journal_corner_bl.dds" },
        { BOTTOMRIGHT, BOTTOMRIGHT, -7, -7, "NagaMapaCompleto/art/journal_corner_br.dds" },
    }
    for _, d in ipairs(defs) do
        local o = WINDOW_MANAGER:CreateControl(nil, w, CT_TEXTURE)
        o:SetDimensions(24, 24)
        o:SetAnchor(d[1], w, d[2], d[3], d[4])
        o:SetTexture(d[5])
        o:SetColor(0.40, 0.78, 0.95, 0.85)
        self.statisticsThemeWindowOrnaments[#self.statisticsThemeWindowOrnaments + 1] = o
    end

    local inner = WINDOW_MANAGER:CreateControl(nil, w, CT_BACKDROP)
    inner:SetAnchor(TOPLEFT, w, TOPLEFT, 12, 56)
    inner:SetAnchor(BOTTOMRIGHT, w, BOTTOMRIGHT, -12, -12)
    inner:SetCenterColor(0.04, 0.06, 0.09, 0.94)
    inner:SetEdgeColor(0.25, 0.45, 0.60, 0.70)
    inner:SetEdgeTexture(nil, 1, 1, 1)
    inner:SetMouseEnabled(true)
    self.statisticsThemeWindowInner = inner

    local title = WINDOW_MANAGER:CreateControl(nil, w, CT_LABEL)
    title:SetDimensions(270, 38)
    title:SetAnchor(TOPLEFT, w, TOPLEFT, 20, 13)
    title:SetFont("ZoFontWinH2")
    title:SetColor(0.70, 0.90, 1.00, 1)
    title:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    title:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.statisticsThemeWindowTitle = title

    local x = WINDOW_MANAGER:CreateControl(nil, w, CT_LABEL)
    x:SetDimensions(34, 34)
    x:SetAnchor(TOPRIGHT, w, TOPRIGHT, -12, 12)
    x:SetFont("ZoFontWinH3")
    x:SetText("X")
    x:SetColor(0.82, 0.82, 0.80, 1)
    x:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    x:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    x:SetMouseEnabled(true)
    x:SetHandler("OnMouseEnter", function(btn) btn:SetColor(1, 1, 1, 1) end)
    x:SetHandler("OnMouseExit", function(btn) btn:SetColor(0.82, 0.82, 0.80, 1) end)
    x:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
            TPM:SetStatisticsThemeWindowVisible(false)
        end
    end)

    local divider = WINDOW_MANAGER:CreateControl(nil, w, CT_BACKDROP)
    divider:SetDimensions(320, 2)
    divider:SetAnchor(TOP, w, TOP, 0, 56)
    divider:SetCenterColor(0.30, 0.65, 0.85, 0.65)
    divider:SetEdgeColor(0, 0, 0, 0)
    self.statisticsThemeWindowHeaderLine = divider

    local designLabel = WINDOW_MANAGER:CreateControl(nil, inner, CT_LABEL)
    designLabel:SetDimensions(308, 24)
    designLabel:SetAnchor(TOPLEFT, inner, TOPLEFT, 16, 10)
    designLabel:SetFont("$(BOLD_FONT)|16")
    designLabel:SetColor(0.90, 0.94, 0.98, 1)
    self.statisticsThemeDesignLabel = designLabel

    -- All themes in a 2-column grid
    local themeOrder = { "cyber", "neon", "arctic", "ember", "matrix", "dark", "tpm", "vanilla" }
    self.statisticsThemeDesignButtons = {}
    local btnW, btnH = 150, 36
    local startX, startY = 12, 40
    local gapX, gapY = 8, 8
    for i, value in ipairs(themeOrder) do
        local col = ((i - 1) % 2)
        local row = math.floor((i - 1) / 2)
        local xp = startX + col * (btnW + gapX)
        local yp = startY + row * (btnH + gapY)
        local frame = WINDOW_MANAGER:CreateControl(nil, inner, CT_BACKDROP)
        frame:SetDimensions(btnW, btnH)
        frame:SetAnchor(TOPLEFT, inner, TOPLEFT, xp, yp)
        frame:SetCenterColor(0.02, 0.025, 0.03, 0.90)
        frame:SetEdgeColor(0.35, 0.40, 0.48, 0.55)
        frame:SetEdgeTexture(nil, 1, 1, 1)
        local b = WINDOW_MANAGER:CreateControl(nil, frame, CT_BUTTON)
        b:SetAnchorFill(frame)
        b:SetFont("$(BOLD_FONT)|14")
        b:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        b:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        b:SetNormalFontColor(0.80, 0.84, 0.90, 1)
        b:SetMouseOverFontColor(1, 1, 1, 1)
        b:SetHandler("OnClicked", function()
            TPM:SetStatisticsThemeDesign(value)
            TPM:RefreshStatisticsThemeWindow()
        end)
        self.statisticsThemeDesignButtons[value] = { button = b, frame = frame }
        -- Keep legacy references for any old code paths
        if value == "tpm" then
            self.statisticsThemeDesignTpmButton = b
            self.statisticsThemeDesignTpmFrame = frame
        elseif value == "vanilla" then
            self.statisticsThemeDesignVanillaButton = b
            self.statisticsThemeDesignVanillaFrame = frame
        elseif value == "dark" then
            self.statisticsThemeDesignDarkButton = b
            self.statisticsThemeDesignDarkFrame = frame
        end
    end
    self:RefreshStatisticsThemeWindow()
end

function TPM:SetStatisticsThemeWindowVisible(show)
    if not self.statisticsThemeWindow then return end
    if show then
        -- Match the journal scale and dock TOP-to-TOP on the right.
        if self.statisticsWindow and self.statisticsThemeWindow.SetScale then
            self.statisticsThemeWindow:SetScale(self.statisticsWindow:GetScale() or 1)
        end
        self.statisticsThemeWindow:ClearAnchors()
        self.statisticsThemeWindow:SetAnchor(TOPLEFT,self.statisticsWindow,TOPRIGHT,8,0)

        -- If journal + side panel do not fit, temporarily move the journal left.
        -- We keep the original top-left so closing the panel restores it exactly.
        if not self.statisticsThemeDockRestore and self.statisticsWindow and GuiRoot then
            local left,top=self.statisticsWindow:GetLeft(),self.statisticsWindow:GetTop()
            local right=self.statisticsWindow:GetRight()
            local rootW=select(1,GuiRoot:GetDimensions()) or 0
            local scale=self.statisticsWindow:GetScale() or 1
            local panelW=360*scale
            local desiredRight=(right or 0)+8+panelW
            if rootW>0 and desiredRight>rootW-8 and left and top then
                local shift=desiredRight-(rootW-8)
                local newLeft=math.max(8,left-shift)
                self.statisticsThemeDockRestore={left=left,top=top}
                self.statisticsWindow:ClearAnchors()
                self.statisticsWindow:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,newLeft,top)
            end
        end

        if self.statisticsThemeWindow.BringWindowToTop then self.statisticsThemeWindow:BringWindowToTop() end
        self.statisticsThemeWindow:SetHidden(false)
        self:RefreshStatisticsThemeWindow()
    else
        self.statisticsThemeWindow:SetHidden(true)
        if self.statisticsThemeColorWindow then self.statisticsThemeColorWindow:SetHidden(true) end
        if self.statisticsThemeDockRestore and self.statisticsWindow and GuiRoot then
            local p=self.statisticsThemeDockRestore
            self.statisticsThemeDockRestore=nil
            self.statisticsWindow:ClearAnchors()
            self.statisticsWindow:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT,p.left,p.top)
        end
    end
end

function TPM:ToggleStatisticsThemeWindow()
    if not self.statisticsWindow then return end
    self:CreateStatisticsThemeWindow()
    self:SetStatisticsThemeWindowVisible(self.statisticsThemeWindow:IsHidden())
end

function TPM:CreateStatisticsWindow()
    if self.statisticsWindow then return end
    if not WINDOW_MANAGER or not GuiRoot then return end

    local control = WINDOW_MANAGER:CreateTopLevelWindow(ADDON_NAME .. "StatisticsWindow")
    control:SetDimensions(1000, 750)
    control:SetScale(Clamp(tonumber(self.saved and self.saved.statisticsWindowScale) or 100, 80, 120) / 100)
    control:SetDrawLayer(DL_OVERLAY)
    control:SetDrawTier(DT_HIGH)
    if control.SetDrawLevel then control:SetDrawLevel(7200) end
    control:SetMouseEnabled(true)
    control:SetMovable(true)
    control:SetClampedToScreen(true)
    control:SetHidden(true)

    if self.saved and type(self.saved.statisticsWindowX) == "number" and type(self.saved.statisticsWindowY) == "number" then
        control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, self.saved.statisticsWindowX, self.saved.statisticsWindowY)
    else
        -- 2.6.31_Beta: Statistics is a real standalone journal now. Anchor to
        -- GuiRoot instead of the world-map viewport so it can exist while the
        -- map scene is completely closed.
        control:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    end
    self.statisticsWindow = control

    local backdrop = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
    backdrop:SetAnchorFill(control)
    -- Solid backdrop: do not use the semi-transparent tooltip center texture.
    backdrop:SetCenterColor(0.05, 0.06, 0.08, 0.97)
    backdrop:SetEdgeColor(0.28, 0.62, 0.82, 0.95)
    backdrop:SetEdgeTexture(nil, 1, 1, 2)
    backdrop:SetInsets(2, 2, -2, -2)
    backdrop:SetMouseEnabled(false)
    self.statisticsOuterBackdrop = backdrop

    local inner = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
    inner:SetAnchor(TOPLEFT, control, TOPLEFT, 5, 5)
    inner:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, -5, -5)
    inner:SetCenterColor(0.07, 0.08, 0.10, 0.98)
    inner:SetEdgeColor(0.20, 0.45, 0.60, 0.55)
    inner:SetEdgeTexture(nil, 1, 1, 1)
    inner:SetMouseEnabled(false)
    self.statisticsInnerBackdrop = inner

    -- Decorative Transparent TPM skin layers. They stay hidden in TPM Standard and
    -- sit behind every existing Statistics control, so the addon layout is untouched.
    self.statisticsVanillaThemeBands = {}
    local vanillaBandDefs = {
        { top = 8, height = 245 },
        { top = 220, height = 320 },
        { top = 500, height = 242 },
    }
    for _,def in ipairs(vanillaBandDefs) do
        local band = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
        band:SetAnchor(TOPLEFT, control, TOPLEFT, 8, def.top)
        band:SetAnchor(TOPRIGHT, control, TOPRIGHT, -8, def.top)
        band:SetHeight(def.height)
        band:SetDrawLayer(DL_BACKGROUND)
        band:SetDrawTier(DT_LOW)
        if band.SetDrawLevel then band:SetDrawLevel(2) end
        band:SetCenterColor(.008,.025,.045,.20)
        band:SetEdgeColor(0,0,0,0)
        band:SetMouseEnabled(false)
        band:SetHidden(true)
        self.statisticsVanillaThemeBands[#self.statisticsVanillaThemeBands + 1] = band
    end

    self.statisticsCornerOrnaments = {}
    local cornerDefs = {
        { point = TOPLEFT, rel = TOPLEFT, x = 7, y = 7, texture = "NagaMapaCompleto/art/journal_corner_tl.dds" },
        { point = TOPRIGHT, rel = TOPRIGHT, x = -7, y = 7, texture = "NagaMapaCompleto/art/journal_corner_tr.dds" },
        { point = BOTTOMLEFT, rel = BOTTOMLEFT, x = 7, y = -7, texture = "NagaMapaCompleto/art/journal_corner_bl.dds" },
        { point = BOTTOMRIGHT, rel = BOTTOMRIGHT, x = -7, y = -7, texture = "NagaMapaCompleto/art/journal_corner_br.dds" },
    }
    for _, def in ipairs(cornerDefs) do
        local ornament = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
        ornament:SetDimensions(30, 30)
        ornament:SetAnchor(def.point, control, def.rel, def.x, def.y)
        ornament:SetTexture(def.texture)
        ornament:SetColor(0.40, 0.78, 0.95, 0.75)
        if ornament.SetDrawLevel then ornament:SetDrawLevel(30) end
        ornament:SetMouseEnabled(false)
        self.statisticsCornerOrnaments[#self.statisticsCornerOrnaments + 1] = ornament
    end

    local title = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
    title:SetDimensions(620, 42)
    title:SetAnchor(TOPLEFT, control, TOPLEFT, 22, 12)
    title:SetFont("ZoFontWinH1")
    title:SetColor(0.70, 0.90, 1.00, 1)
    title:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    title:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.statisticsTitle = title

    local versionLabel = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
    versionLabel:SetDimensions(126, 26)
    -- Keep build information with the title, before the language selector.
    versionLabel:SetAnchor(TOPLEFT, control, TOPLEFT, 212, 13)
    versionLabel:SetFont("$(MEDIUM_FONT)|15")
    versionLabel:SetColor(0.96, 0.96, 0.94, 1)
    versionLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    versionLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    versionLabel:SetText("")
    versionLabel:SetHidden(true)
    self.statisticsVersionLabel = versionLabel

    local dragHandle = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "StatisticsDragHandle", control, CT_CONTROL)
    dragHandle:SetDimensions(720, 56)
    dragHandle:SetAnchor(TOPLEFT, control, TOPLEFT, 8, 4)
    dragHandle:SetMouseEnabled(true)
    dragHandle:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            TPM.statisticsWindowMoving = true
            TPM:UpdateGlobalMouseUpRegistration()
            control:StartMoving()
        end
    end)
    dragHandle:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            TPM:StopMovingStatisticsWindow()
        end
    end)
    self.statisticsDragHandle = dragHandle

    local mode = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
    mode:SetDimensions(280, 30)
    mode:SetAnchor(TOPRIGHT, control, TOPRIGHT, -58, 18)
    mode:SetFont("$(MEDIUM_FONT)|18")
    mode:SetColor(0.74, 0.71, 0.63, 1)
    mode:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    mode:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.statisticsMode = mode

    -- Progress and PvE/PvP each use two journal pages. The compact
    -- < 1 / 2 > navigator occupies the old mode-text position only on those
    -- sections; Economy stays a single page and keeps its mode text.
    local subNav = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "StatisticsSubPageNavigation", control, CT_CONTROL)
    subNav:SetDimensions(170, 30)
    subNav:SetAnchor(TOPRIGHT, control, TOPRIGHT, -58, 18)
    subNav:SetMouseEnabled(false)
    subNav:SetHidden(true)
    self.statisticsSubPageNavigation = subNav

    local subPrev = WINDOW_MANAGER:CreateControl(nil, subNav, CT_BUTTON)
    subPrev:SetDimensions(42, 28)
    subPrev:SetAnchor(LEFT, subNav, LEFT, 0, 0)
    subPrev:SetFont("$(BOLD_FONT)|22")
    subPrev:SetText("<")
    subPrev:SetNormalFontColor(0.90, 0.77, 0.34, 1)
    subPrev:SetMouseOverFontColor(1.00, 0.90, 0.50, 1)
    subPrev:SetHandler("OnClicked", function() TPM:SetStatisticsSubPage(1) end)
    self.statisticsSubPagePrev = subPrev

    local subCounter = WINDOW_MANAGER:CreateControl(nil, subNav, CT_LABEL)
    subCounter:SetDimensions(84, 28)
    subCounter:SetAnchor(CENTER, subNav, CENTER, 0, 0)
    subCounter:SetFont("$(BOLD_FONT)|17")
    subCounter:SetColor(0.86, 0.82, 0.72, 1)
    subCounter:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    subCounter:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.statisticsSubPageCounter = subCounter

    local subNext = WINDOW_MANAGER:CreateControl(nil, subNav, CT_BUTTON)
    subNext:SetDimensions(42, 28)
    subNext:SetAnchor(RIGHT, subNav, RIGHT, 0, 0)
    subNext:SetFont("$(BOLD_FONT)|22")
    subNext:SetText(">")
    subNext:SetNormalFontColor(0.90, 0.77, 0.34, 1)
    subNext:SetMouseOverFontColor(1.00, 0.90, 0.50, 1)
    subNext:SetHandler("OnClicked", function() TPM:SetStatisticsSubPage(2) end)
    self.statisticsSubPageNext = subNext

    local close = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
    close:SetDimensions(34, 34)
    close:SetAnchor(TOPRIGHT, control, TOPRIGHT, -12, 12)
    close:SetFont("ZoFontWinH3")
    close:SetText("X")
    close:SetColor(0.78, 0.72, 0.58, 1)
    close:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    close:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    close:SetMouseEnabled(true)
    close:SetHandler("OnMouseEnter", function(btn) if TPM:IsStatisticsDarkDesign() then btn:SetColor(1,1,1,1) else btn:SetColor(1, 0.84, 0.38, 1) end end)
    close:SetHandler("OnMouseExit", function(btn) if TPM:IsStatisticsDarkDesign() then btn:SetColor(.92,.92,.92,1) else btn:SetColor(0.78, 0.72, 0.58, 1) end end)
    close:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then TPM:HideStatisticsWindow() end
    end)

    -- Theme gear in the Statistics header. The addon follows ESO's client
    -- language automatically, so no separate language indicator is needed.
    -- Using the bundled DDS avoids unsupported Unicode glyphs rendering as [].
    local gear = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "StatisticsThemeGear", control, CT_BUTTON)
    gear:SetDimensions(26, 26)
    gear:SetAnchor(TOP, control, TOP, -28, 18)
    gear:SetMouseEnabled(true)
    local gearIcon = WINDOW_MANAGER:CreateControl(nil, gear, CT_TEXTURE)
    gearIcon:SetDimensions(20, 20)
    gearIcon:SetAnchor(CENTER, gear, CENTER, 0, 0)
    gearIcon:SetTexture("NagaMapaCompleto/art/settings_gear.dds")
    gearIcon:SetColor(0.96, 0.78, 0.30, 1)
    gearIcon:SetMouseEnabled(false)
    gear.TPMIcon = gearIcon
    gear:SetHandler("OnMouseEnter", function(g)
        if g.TPMIcon then
            if TPM:IsStatisticsDarkDesign() then g.TPMIcon:SetColor(1,1,1,1) else g.TPMIcon:SetColor(1, 0.90, 0.45, 1) end
        end
        if TPM.statisticsThemeGearLabel then
            if TPM:IsStatisticsDarkDesign() then TPM.statisticsThemeGearLabel:SetColor(1,1,1,1)
            else TPM.statisticsThemeGearLabel:SetColor(1, 0.90, 0.50, 1) end
        end
    end)
    gear:SetHandler("OnMouseExit", function()
        TPM:ApplyStatisticsTheme()
        if TPM.statisticsThemeGearLabel then
            local hr, hg, hb = TPM:GetStatisticsThemeHeadingColor()
            TPM.statisticsThemeGearLabel:SetColor(hr, hg, hb, 1)
        end
    end)
    gear:SetHandler("OnClicked", function() TPM:ToggleStatisticsThemeWindow() end)
    self.statisticsThemeGear = gear

    -- Label "Themes" next to the gear (header customization entry)
    local gearLabel = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "StatisticsThemeGearLabel", control, CT_LABEL)
    gearLabel:SetDimensions(90, 26)
    gearLabel:SetAnchor(LEFT, gear, RIGHT, 4, 0)
    gearLabel:SetFont("$(BOLD_FONT)|16")
    gearLabel:SetColor(0.95, 0.82, 0.36, 1)
    gearLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    gearLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    gearLabel:SetText("Themes")
    gearLabel:SetMouseEnabled(true)
    gearLabel:SetHandler("OnMouseEnter", function(lbl)
        if TPM:IsStatisticsDarkDesign() then lbl:SetColor(1,1,1,1) else lbl:SetColor(1, 0.90, 0.50, 1) end
        if TPM.statisticsThemeGear and TPM.statisticsThemeGear.TPMIcon then
            if TPM:IsStatisticsDarkDesign() then TPM.statisticsThemeGear.TPMIcon:SetColor(1,1,1,1)
            else TPM.statisticsThemeGear.TPMIcon:SetColor(1, 0.90, 0.45, 1) end
        end
    end)
    gearLabel:SetHandler("OnMouseExit", function(lbl)
        local hr, hg, hb = TPM:GetStatisticsThemeHeadingColor()
        lbl:SetColor(hr, hg, hb, 1)
        TPM:ApplyStatisticsTheme()
    end)
    gearLabel:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
            TPM:ToggleStatisticsThemeWindow()
        end
    end)
    self.statisticsThemeGearLabel = gearLabel

    local topDivider = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
    topDivider:SetDimensions(956, 1)
    topDivider:SetAnchor(TOPLEFT, control, TOPLEFT, 22, 56)
    topDivider:SetCenterColor(0.68, 0.56, 0.27, 0.68)
    topDivider:SetEdgeColor(0, 0, 0, 0)
    self.statisticsTopDivider = topDivider

    -- Dedicated container for the complete Progress page.  All progress-only
    -- controls are children of this control, so hiding the page hides every
    -- row/header/bar atomically and later row refreshes cannot bleed through
    -- to the Player or Economy pages.
    local progressPage = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "StatisticsProgressPage", control, CT_CONTROL)
    progressPage:SetAnchorFill(control)
    progressPage:SetMouseEnabled(false)
    progressPage:SetHidden(false)
    self.statisticsProgressPage = progressPage

    -- Tamriel completion medallion: label above the ESO Ouroboros and the
    -- overall percentage centered cleanly inside the ring.
    local tamriel = WINDOW_MANAGER:CreateControl(nil, progressPage, CT_LABEL)
    tamriel:SetDimensions(170, 24)
    tamriel:SetAnchor(TOPLEFT, control, TOPLEFT, 7, 55)
    tamriel:SetFont("$(BOLD_FONT)|19")
    tamriel:SetColor(0.88, 0.80, 0.60, 1)
    tamriel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    tamriel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.statisticsTamrielLabel = tamriel

    local medallion = WINDOW_MANAGER:CreateControl(nil, progressPage, CT_TEXTURE)
    medallion:SetDimensions(132, 132)
    medallion:SetAnchor(TOPLEFT, control, TOPLEFT, 26, 68)
    medallion:SetTexture("NagaMapaCompleto/art/tamriel_ouroboros.dds")
    -- Keep the original artwork colors instead of tinting the user-supplied ESO ring.
    medallion:SetColor(1.00, 1.00, 1.00, 0.98)
    medallion:SetMouseEnabled(false)
    self.statisticsTamrielMedallion = medallion

    local overall = WINDOW_MANAGER:CreateControl(nil, progressPage, CT_LABEL)
    overall:SetDimensions(106, 44)
    overall:SetAnchor(CENTER, medallion, CENTER, 0, 3)
    overall:SetFont("$(ANTIQUE_FONT)|32")
    overall:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    overall:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.statisticsOverall = overall

    local tamrielDivider = WINDOW_MANAGER:CreateControl(nil, progressPage, CT_BACKDROP)
    tamrielDivider:SetDimensions(1, 116)
    tamrielDivider:SetAnchor(TOPLEFT, control, TOPLEFT, 184, 72)
    tamrielDivider:SetCenterColor(0.46, 0.36, 0.16, 0.42)
    tamrielDivider:SetEdgeColor(0, 0, 0, 0)
    self.statisticsTamrielDivider = tamrielDivider

    local overallBar = WINDOW_MANAGER:CreateControl(nil, progressPage, CT_BACKDROP)
    overallBar:SetDimensions(760, 20)
    overallBar:SetAnchor(TOPLEFT, control, TOPLEFT, 208, 72)
    overallBar:SetCenterColor(0.014, 0.013, 0.011, 0.96)
    overallBar:SetEdgeColor(0.58, 0.45, 0.17, 0.92)
    overallBar:SetEdgeTexture(nil, 1, 1, 1)
    self.statisticsOverallBar = overallBar

    local overallFill = WINDOW_MANAGER:CreateControl(nil, overallBar, CT_BACKDROP)
    overallFill:SetDimensions(1, 18)
    overallFill:SetAnchor(LEFT, overallBar, LEFT, 1, 0)
    overallFill:SetCenterColor(0.82, 0.62, 0.18, 0.98)
    overallFill:SetEdgeColor(0, 0, 0, 0)
    self.statisticsOverallFill = overallFill

    local overallFillShine = WINDOW_MANAGER:CreateControl(nil, overallFill, CT_BACKDROP)
    overallFillShine:SetAnchor(TOPLEFT, overallFill, TOPLEFT, 0, 0)
    overallFillShine:SetAnchor(TOPRIGHT, overallFill, TOPRIGHT, 0, 0)
    overallFillShine:SetHeight(3)
    overallFillShine:SetCenterColor(1.00, 0.90, 0.48, 0.34)
    overallFillShine:SetEdgeColor(0, 0, 0, 0)

    local overallBarPercent = WINDOW_MANAGER:CreateControl(nil, progressPage, CT_LABEL)
    overallBarPercent:SetDimensions(62, 26)
    overallBarPercent:SetAnchor(RIGHT, overallBar, RIGHT, -8, 0)
    overallBarPercent:SetFont("$(BOLD_FONT)|19")
    overallBarPercent:SetColor(0.98, 0.82, 0.28, 1)
    overallBarPercent:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    overallBarPercent:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.statisticsOverallBarPercent = overallBarPercent

    local subtitle = WINDOW_MANAGER:CreateControl(nil, progressPage, CT_LABEL)
    subtitle:SetDimensions(760, 18)
    subtitle:SetAnchor(TOPLEFT, control, TOPLEFT, 208, 94)
    subtitle:SetFont("$(MEDIUM_FONT)|15")
    subtitle:SetColor(0.64, 0.61, 0.54, 1)
    subtitle:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    subtitle:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    subtitle:SetWidth(390)
    self.statisticsSubtitle = subtitle

    -- 2.6.14: Native-style zone focus selector. "Tamriel" preserves the old
    -- all-zone view; any supported Zone Story narrows the summary, categories
    -- and zone table to that one zone without affecting global history/goals.
    local focusLabel = WINDOW_MANAGER:CreateControl(nil, progressPage, CT_LABEL)
    focusLabel:SetDimensions(72, 24)
    focusLabel:SetAnchor(TOPLEFT, control, TOPLEFT, 598, 92)
    focusLabel:SetFont("$(MEDIUM_FONT)|14")
    focusLabel:SetColor(0.74, 0.70, 0.62, 1)
    focusLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    focusLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.statisticsFocusLabel = focusLabel

    -- 2.6.15: Own TPM selector instead of ZO_ComboBox. The virtual combo could
    -- render correctly but not receive/open its dropdown in the world-map
    -- overlay. This control is fully mouse-driven and its popup lives directly
    -- on the statistics top-level window, so it cannot be clipped by the page.
    local focusSelector = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "StatisticsFocusSelector", progressPage, CT_CONTROL)
    focusSelector:SetDimensions(286, 26)
    focusSelector:SetAnchor(TOPLEFT, control, TOPLEFT, 678, 91)
    focusSelector:SetMouseEnabled(true)
    local focusSelectorBg = WINDOW_MANAGER:CreateControl(nil, focusSelector, CT_BACKDROP)
    focusSelectorBg:SetAnchorFill(focusSelector)
    focusSelectorBg:SetCenterColor(0.022, 0.020, 0.016, 0.98)
    focusSelectorBg:SetEdgeColor(0.72, 0.58, 0.17, 0.95)
    focusSelectorBg:SetEdgeTexture(nil, 1, 1, 1)
    focusSelectorBg:SetMouseEnabled(false)
    local focusSelected = WINDOW_MANAGER:CreateControl(nil, focusSelector, CT_LABEL)
    focusSelected:SetDimensions(250, 24)
    focusSelected:SetAnchor(LEFT, focusSelector, LEFT, 8, 0)
    focusSelected:SetFont("$(MEDIUM_FONT)|16")
    focusSelected:SetColor(0.94, 0.91, 0.82, 1)
    focusSelected:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    focusSelected:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    local focusArrow = WINDOW_MANAGER:CreateControl(nil, focusSelector, CT_LABEL)
    focusArrow:SetDimensions(22, 24)
    focusArrow:SetAnchor(RIGHT, focusSelector, RIGHT, -4, 0)
    focusArrow:SetFont("$(BOLD_FONT)|15")
    focusArrow:SetColor(0.95, 0.78, 0.20, 1)
    focusArrow:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    focusArrow:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    focusArrow:SetText("▼")
    focusSelector:SetHandler("OnMouseEnter", function()
        if TPM:IsStatisticsDarkDesign() then
            focusSelectorBg:SetCenterColor(0,0,0,.44); focusSelectorBg:SetEdgeColor(1,1,1,.46)
        else
            focusSelectorBg:SetCenterColor(0.085, 0.066, 0.025, 0.98); focusSelectorBg:SetEdgeColor(0.95, 0.76, 0.20, 1)
        end
    end)
    focusSelector:SetHandler("OnMouseExit", function()
        if TPM:IsStatisticsDarkDesign() then
            focusSelectorBg:SetCenterColor(0,0,0,.30); focusSelectorBg:SetEdgeColor(1,1,1,.28)
        else
            focusSelectorBg:SetCenterColor(0.022, 0.020, 0.016, 0.98); focusSelectorBg:SetEdgeColor(0.72, 0.58, 0.17, 0.95)
        end
    end)
    focusSelector:SetHandler("OnMouseUp", function(_, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then TPM:ToggleStatisticsFocusDropdown() end
    end)
    focusSelector:SetHandler("OnMouseWheel", function(_, delta)
        if TPM.statisticsFocusDropdown and not TPM.statisticsFocusDropdown:IsHidden() then
            TPM:ScrollStatisticsFocusDropdown(delta)
        end
    end)
    self.statisticsFocusSelector = focusSelector
    self.statisticsFocusSelectedLabel = focusSelected
    self.statisticsFocusArrow = focusArrow

    local focusDropdown = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "StatisticsFocusDropdown", control, CT_CONTROL)
    focusDropdown:SetDimensions(286, 242)
    focusDropdown:SetAnchor(TOPLEFT, control, TOPLEFT, 678, 120)
    focusDropdown:SetMouseEnabled(true)
    focusDropdown:SetHidden(true)
    if focusDropdown.SetDrawTier then focusDropdown:SetDrawTier(DT_HIGH) end
    if focusDropdown.SetDrawLayer then focusDropdown:SetDrawLayer(DL_OVERLAY) end
    if focusDropdown.SetDrawLevel then focusDropdown:SetDrawLevel(7600) end
    focusDropdown:SetHandler("OnMouseWheel", function(_, delta) TPM:ScrollStatisticsFocusDropdown(delta) end)
    local focusDropdownBg = WINDOW_MANAGER:CreateControl(nil, focusDropdown, CT_BACKDROP)
    focusDropdownBg:SetAnchorFill(focusDropdown)
    focusDropdownBg:SetCenterColor(0.010, 0.009, 0.007, 0.995)
    focusDropdownBg:SetEdgeColor(0.88, 0.70, 0.18, 1)
    focusDropdownBg:SetEdgeTexture("EsoUI/Art/Tooltips/UI-Border.dds", 128, 16, 2)
    focusDropdownBg:SetInsets(2, 2, -2, -2)
    focusDropdownBg:SetMouseEnabled(false)

    self.statisticsFocusDropdownRows = {}
    for rowIndex = 1, 9 do
        local row = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "StatisticsFocusRow" .. tostring(rowIndex), focusDropdown, CT_BUTTON)
        row:SetDimensions(258, 25)
        row:SetAnchor(TOPLEFT, focusDropdown, TOPLEFT, 4, 4 + ((rowIndex - 1) * 26))
        row:SetMouseEnabled(true)
        if row.SetDrawLayer then row:SetDrawLayer(DL_OVERLAY) end
        if row.SetDrawLevel then row:SetDrawLevel(7610 + rowIndex) end
        local rowBg = WINDOW_MANAGER:CreateControl(nil, row, CT_BACKDROP)
        rowBg:SetAnchorFill(row)
        rowBg:SetCenterColor(0.025, 0.022, 0.017, 0.98)
        rowBg:SetEdgeColor(0.23, 0.19, 0.10, 0.85)
        rowBg:SetEdgeTexture(nil, 1, 1, 1)
        rowBg:SetMouseEnabled(false)
        local rowLabel = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
        rowLabel:SetDimensions(220, 23)
        rowLabel:SetAnchor(LEFT, row, LEFT, 8, 0)
        rowLabel:SetFont("$(MEDIUM_FONT)|15")
        rowLabel:SetColor(0.91, 0.88, 0.78, 1)
        rowLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
        rowLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        local selectedMark = WINDOW_MANAGER:CreateControl(nil, row, CT_LABEL)
        selectedMark:SetDimensions(24, 23)
        selectedMark:SetAnchor(RIGHT, row, RIGHT, -6, 0)
        selectedMark:SetFont("$(BOLD_FONT)|16")
        selectedMark:SetColor(1.00, 0.84, 0.26, 1)
        selectedMark:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        selectedMark:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        selectedMark:SetText("")
        row.bg, row.label, row.selectedMark = rowBg, rowLabel, selectedMark
        row:SetHandler("OnMouseEnter", function(r)
            if TPM:IsStatisticsDarkDesign() then
                r.bg:SetCenterColor(0,0,0,.48); r.bg:SetEdgeColor(1,1,1,.42); r.label:SetColor(1,1,1,1)
            else
                r.bg:SetCenterColor(0.13, 0.10, 0.035, 0.99); r.label:SetColor(1.00, 0.84, 0.26, 1)
            end
        end)
        row:SetHandler("OnMouseExit", function(r)
            if TPM:IsStatisticsDarkDesign() then
                r.bg:SetCenterColor(0,0,0,r.selected and .44 or .24); r.bg:SetEdgeColor(1,1,1,r.selected and .40 or .18); r.label:SetColor(1,1,1,1)
            elseif r.selected then
                r.bg:SetCenterColor(0.16, 0.125, 0.040, 0.98); r.label:SetColor(1.00, 0.84, 0.26, 1)
            else
                r.bg:SetCenterColor(0.025, 0.022, 0.017, 0.98); r.label:SetColor(0.91, 0.88, 0.78, 1)
            end
        end)
        row:SetHandler("OnMouseWheel", function(_, delta) TPM:ScrollStatisticsFocusDropdown(delta) end)
        -- 2.6.19: use the native button click event. OnMouseUp/upInside on a
        -- custom CT_CONTROL was unreliable while the popup overlapped the main
        -- progress controls, which made every zone look unselectable.
        row:SetHandler("OnClicked", function(r, button)
            if button and button ~= MOUSE_BUTTON_INDEX_LEFT then return end
            if r.TPMZoneId == nil then return end
            local zoneId = tonumber(r.TPMZoneId) or 0

            -- Apply and paint the choice before closing the popup. In 2.6.19
            -- the popup was hidden first, so the old OnMouseExit state could
            -- briefly erase the highlight and make selection feel unreliable.
            if TPM:SetStatisticsFocusZone(zoneId) then
                if TPM.statisticsFocusSelectedLabel then
                    TPM.statisticsFocusSelectedLabel:SetText(zoneId > 0 and SafeZoneName(zoneId) or TPM:L("STAT_FOCUS_TAMRIEL"))
                end
                TPM:RefreshStatisticsFocusDropdownRows()
            end
            TPM:HideStatisticsFocusDropdown()
        end)
        self.statisticsFocusDropdownRows[rowIndex] = row
    end

    -- 2.6.18: one real vertical scroll rail instead of tiny up/down buttons.
    -- It can be dragged just like the main zone-list scrollbar and mouse-wheel
    -- scrolling remains available anywhere inside the popup.
    local focusScrollBar = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "StatisticsFocusScrollBar", focusDropdown, CT_SLIDER)
    focusScrollBar:SetDimensions(14, 226)
    focusScrollBar:SetAnchor(TOPRIGHT, focusDropdown, TOPRIGHT, -5, 8)
    focusScrollBar:SetOrientation(ORIENTATION_VERTICAL)
    focusScrollBar:SetMouseEnabled(true)
    local focusElevator = "/esoui/art/miscellaneous/scrollbox_elevator.dds"
    focusScrollBar:SetThumbTexture(focusElevator, focusElevator, focusElevator, 18, 44, 0, 0, 1, 1)
    if focusScrollBar.SetBackgroundMiddleTexture then
        focusScrollBar:SetBackgroundMiddleTexture("/esoui/art/chatwindow/chat_scrollbar_track.dds", 0, 0, 1, 1)
    end
    focusScrollBar:SetValueStep(1)
    focusScrollBar:SetMinMax(0, 0)
    focusScrollBar:SetValue(0)
    focusScrollBar:SetHandler("OnValueChanged", function(_, value)
        if TPM.statisticsFocusScrollBarRefreshing then return end
        TPM.statisticsFocusDropdownOffset = Round(tonumber(value) or 0)
        TPM:RefreshStatisticsFocusDropdownRows()
    end)
    self.statisticsFocusDropdown = focusDropdown
    self.statisticsFocusScrollBar = focusScrollBar
    self.statisticsFocusScrollUp = nil
    self.statisticsFocusScrollDown = nil

    self.statisticsCards =
    {
        self:CreateStatisticsSummaryCard(progressPage, ADDON_NAME .. "StatsCardZones", 208, 146, "NagaMapaCompleto/art/stat_complete.dds"),
        self:CreateStatisticsSummaryCard(progressPage, ADDON_NAME .. "StatsCardObjectives", 361, 146, "NagaMapaCompleto/art/stat_objectives.dds"),
        self:CreateStatisticsSummaryCard(progressPage, ADDON_NAME .. "StatsCardRemaining", 514, 146, "NagaMapaCompleto/art/stat_remaining.dds"),
        self:CreateStatisticsSummaryCard(progressPage, ADDON_NAME .. "StatsCardUntouched", 667, 146, "NagaMapaCompleto/art/stat_untouched.dds"),
    }
    self.statisticsPlaytimeCard = self:CreateProgressPlaytimeCard(progressPage, ADDON_NAME .. "StatsCardPlaytime", 820, 146)

    -- Character Level/CP and Companion progression live on PvE/PvP page 2.
    -- ESO play time remains a compact summary on Progress and a detailed ledger on Character.

    local categoryTitle = WINDOW_MANAGER:CreateControl(nil, progressPage, CT_LABEL)
    categoryTitle:SetDimensions(450, 28)
    categoryTitle:SetAnchor(TOPLEFT, control, TOPLEFT, 22, 202)
    categoryTitle:SetFont("ZoFontWinH4")
    categoryTitle:SetColor(0.90, 0.77, 0.34, 1)
    categoryTitle:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    categoryTitle:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.statisticsCategoryTitle = categoryTitle

    local categoryGearButton = WINDOW_MANAGER:CreateControl(nil, progressPage, CT_BUTTON)
    categoryGearButton:SetDimensions(18, 18)
    categoryGearButton:SetAnchor(TOPLEFT, control, TOPLEFT, 472, 207)
    categoryGearButton:SetMouseEnabled(true)
    local categoryGearIcon = WINDOW_MANAGER:CreateControl(nil, categoryGearButton, CT_TEXTURE)
    categoryGearIcon:SetDimensions(16, 16)
    categoryGearIcon:SetAnchor(CENTER, categoryGearButton, CENTER, 0, 0)
    categoryGearIcon:SetTexture("NagaMapaCompleto/art/settings_gear.dds")
    categoryGearIcon:SetColor(0.55, 0.52, 0.46, 0.80)
    categoryGearIcon:SetMouseEnabled(false)
    categoryGearButton.TPMIcon = categoryGearIcon
    self.statisticsCategoryGearButton = categoryGearButton
    self.statisticsCategoryGearIcon = categoryGearIcon

    -- 2.6.5: Use one clean divider without a center glyph. The font-based
    -- diamond could look optically off-center at different UI scales even
    -- when its control was mathematically centered.
    local categoryDivider = WINDOW_MANAGER:CreateControl(nil, progressPage, CT_BACKDROP)
    categoryDivider:SetDimensions(956, 1)
    categoryDivider:SetAnchor(TOPLEFT, control, TOPLEFT, 22, 227)
    categoryDivider:SetCenterColor(0.42, 0.34, 0.17, 0.52)
    categoryDivider:SetEdgeColor(0, 0, 0, 0)
    self.statisticsCategoryDivider = categoryDivider

    local categoryPanelLeft = WINDOW_MANAGER:CreateControl(nil, progressPage, CT_BACKDROP)
    categoryPanelLeft:SetDimensions(456, 164)
    categoryPanelLeft:SetAnchor(TOPLEFT, control, TOPLEFT, 22, 232)
    categoryPanelLeft:SetCenterColor(0.022, 0.020, 0.016, 0.64)
    categoryPanelLeft:SetEdgeColor(0.34, 0.27, 0.12, 0.58)
    categoryPanelLeft:SetEdgeTexture(nil, 1, 1, 1)
    categoryPanelLeft:SetMouseEnabled(false)
    self.statisticsCategoryPanelLeft = categoryPanelLeft

    local categoryPanelRight = WINDOW_MANAGER:CreateControl(nil, progressPage, CT_BACKDROP)
    categoryPanelRight:SetDimensions(456, 164)
    categoryPanelRight:SetAnchor(TOPLEFT, control, TOPLEFT, 510, 232)
    categoryPanelRight:SetCenterColor(0.022, 0.020, 0.016, 0.64)
    categoryPanelRight:SetEdgeColor(0.34, 0.27, 0.12, 0.58)
    categoryPanelRight:SetEdgeTexture(nil, 1, 1, 1)
    categoryPanelRight:SetMouseEnabled(false)
    self.statisticsCategoryPanelRight = categoryPanelRight

    self.statisticsCategoryRows = {}
    for index = 1, (#COMPLETION_TYPES + 2) do
        self.statisticsCategoryRows[index] = self:CreateStatisticsCategoryRow(progressPage, index)
    end

    -- 2.5.0 TEST: collection rows occupy the exact same grid and are only
    -- shown on page 2. Page 1 controls above are intentionally unchanged.
    self.statisticsCollectionRows = {}
    for index = 1, #COLLECTION_STAT_DEFINITIONS do
        local row = self:CreateStatisticsCategoryRow(progressPage, index, "StatsCollection")
        row.label:SetFont("$(MEDIUM_FONT)|14")
        row.control:SetHidden(true)
        self.statisticsCollectionRows[index] = row
    end

    -- 2.6.0: Page 3 uses the same 8 + 8 grid for ESO achievement categories.
    self.statisticsAchievementRows = {}
    for index = 1, 16 do
        local row = self:CreateStatisticsCategoryRow(progressPage, index, "StatsAchievement")
        row.label:SetFont("$(MEDIUM_FONT)|14")
        row.count:SetFont("$(MEDIUM_FONT)|13")
        row.control:SetHidden(true)
        self.statisticsAchievementRows[index] = row
    end

    -- 2.6.8: Compact sort bar shared by Completion / Collections / Achievements.
    local categorySortBox = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "StatsCategorySortBox", progressPage, CT_BACKDROP)
    categorySortBox:SetDimensions(326, 26)
    categorySortBox:SetAnchor(TOPLEFT, control, TOPLEFT, 505, 201)
    categorySortBox:SetCenterColor(0.024, 0.021, 0.016, 0.82)
    categorySortBox:SetEdgeColor(0.34, 0.27, 0.12, 0.62)
    categorySortBox:SetEdgeTexture(nil, 1, 1, 1)
    categorySortBox:SetMouseEnabled(false)
    self.statisticsCategorySortBox = categorySortBox
    self.statisticsCategorySortButtons = {}

    local function CreateCategorySortButton(key, x, width)
        local back = WINDOW_MANAGER:CreateControl(nil, categorySortBox, CT_BACKDROP)
        back:SetDimensions(width, 22)
        back:SetAnchor(LEFT, categorySortBox, LEFT, x, 0)
        back:SetCenterColor(0.035, 0.031, 0.024, 0.72)
        back:SetEdgeColor(0.30, 0.24, 0.12, 0.45)
        back:SetEdgeTexture(nil, 1, 1, 1)
        back:SetMouseEnabled(false)

        local button = WINDOW_MANAGER:CreateControl(nil, categorySortBox, CT_BUTTON)
        button:SetDimensions(width, 22)
        button:SetAnchorFill(back)
        button:SetFont("$(BOLD_FONT)|13")
        button:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        button:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        button:SetMouseOverFontColor(1.00, 0.90, 0.40, 1)
        button:SetPressedFontColor(1.00, 0.72, 0.18, 1)
        button:SetHandler("OnClicked", function() TPM:SetStatisticsCategorySortMode(key) end)
        button.TPMBackdrop = back
        self.statisticsCategorySortButtons[key] = button
    end

    CreateCategorySortButton("all", 2, 64)
    CreateCategorySortButton("name", 68, 66)
    CreateCategorySortButton("asc", 136, 92)
    CreateCategorySortButton("desc", 230, 94)
    self:RefreshStatisticsCategorySortControls()

    local categoryPrev = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "StatsCategoryPrev", progressPage, CT_BUTTON)
    categoryPrev:SetDimensions(28, 24)
    categoryPrev:SetAnchor(TOPRIGHT, control, TOPRIGHT, -116, 202)
    categoryPrev:SetFont("$(BOLD_FONT)|20")
    categoryPrev:SetText("‹")
    categoryPrev:SetNormalFontColor(0.86, 0.72, 0.28, 1)
    categoryPrev:SetMouseOverFontColor(1.00, 0.88, 0.42, 1)
    categoryPrev:SetPressedFontColor(1.00, 0.70, 0.14, 1)
    categoryPrev:SetHandler("OnClicked", function() TPM:SetStatisticsCompletionPage(TPM:GetStatisticsCompletionPage() - 1) end)
    categoryPrev:SetHandler("OnMouseEnter", function(control)
        local targetPage = math.max(1, TPM:GetStatisticsCompletionPage() - 1)
        local key = targetPage == 1 and "STAT_PAGE_COMPLETION" or "STAT_PAGE_COLLECTIONS"
        TPM:ShowStatisticsHoverTooltip(TPM:L(key), "", control)
    end)
    categoryPrev:SetHandler("OnMouseExit", function() TPM:HideStatisticsHoverTooltips() end)
    self.statisticsCategoryPrev = categoryPrev

    local categoryPageIndicator = WINDOW_MANAGER:CreateControl(nil, progressPage, CT_LABEL)
    categoryPageIndicator:SetDimensions(54, 24)
    categoryPageIndicator:SetAnchor(TOPRIGHT, control, TOPRIGHT, -58, 202)
    categoryPageIndicator:SetFont("$(BOLD_FONT)|14")
    categoryPageIndicator:SetColor(0.78, 0.72, 0.58, 1)
    categoryPageIndicator:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    categoryPageIndicator:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    categoryPageIndicator:SetText("1 / 3")
    self.statisticsCategoryPageIndicator = categoryPageIndicator

    local categoryNext = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "StatsCategoryNext", progressPage, CT_BUTTON)
    categoryNext:SetDimensions(28, 24)
    categoryNext:SetAnchor(TOPRIGHT, control, TOPRIGHT, -22, 202)
    categoryNext:SetFont("$(BOLD_FONT)|20")
    categoryNext:SetText("›")
    categoryNext:SetNormalFontColor(0.86, 0.72, 0.28, 1)
    categoryNext:SetMouseOverFontColor(1.00, 0.88, 0.42, 1)
    categoryNext:SetPressedFontColor(1.00, 0.70, 0.14, 1)
    categoryNext:SetHandler("OnClicked", function() TPM:SetStatisticsCompletionPage(TPM:GetStatisticsCompletionPage() + 1) end)
    categoryNext:SetHandler("OnMouseEnter", function(control)
        local targetPage = math.min(3, TPM:GetStatisticsCompletionPage() + 1)
        local key = targetPage == 2 and "STAT_PAGE_COLLECTIONS" or "STAT_PAGE_ACHIEVEMENTS"
        TPM:ShowStatisticsHoverTooltip(TPM:L(key), "", control)
    end)
    categoryNext:SetHandler("OnMouseExit", function() TPM:HideStatisticsHoverTooltips() end)
    self.statisticsCategoryNext = categoryNext

    local zoneSectionTop = 402
    local zoneTitle = WINDOW_MANAGER:CreateControl(nil, progressPage, CT_LABEL)
    zoneTitle:SetDimensions(410, 30)
    zoneTitle:SetAnchor(TOPLEFT, control, TOPLEFT, 22, zoneSectionTop)
    zoneTitle:SetFont("ZoFontWinH4")
    zoneTitle:SetColor(0.90, 0.77, 0.34, 1)
    zoneTitle:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    zoneTitle:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    self.statisticsZoneTitle = zoneTitle

    local function CreateSortButton(name, rightOffset, sortMode)
        local button = WINDOW_MANAGER:CreateControl(name, progressPage, CT_BUTTON)
        button:SetDimensions(132, 30)
        button:SetAnchor(TOPRIGHT, progressPage, TOPRIGHT, rightOffset, zoneSectionTop)
        button:SetFont("$(BOLD_FONT)|19")
        button:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        button:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        button:SetNormalFontColor(0.86, 0.78, 0.58, 1)
        button:SetMouseOverFontColor(1.00, 0.84, 0.36, 1)
        button:SetPressedFontColor(0.90, 0.72, 0.28, 1)
        button:SetMouseEnabled(true)
        button:SetHandler("OnClicked", function()
            TPM.saved.statisticsSortMode = sortMode
            TPM.statisticsScrollOffset = 0
            TPM:InvalidateStatisticsData(false)
            TPM:RefreshStatisticsWindow()
        end)
        return button
    end

    local sortProgress = CreateSortButton(ADDON_NAME .. "StatsSortProgress", -164, "progress")
    self.statisticsSortProgress = sortProgress

    local sortName = CreateSortButton(ADDON_NAME .. "StatsSortName", -22, "name")
    self.statisticsSortName = sortName

    local zonePanel = WINDOW_MANAGER:CreateControl(nil, progressPage, CT_BACKDROP)
    zonePanel:SetDimensions(944, 250)
    zonePanel:SetAnchor(TOPLEFT, control, TOPLEFT, 22, zoneSectionTop + 32)
    zonePanel:SetCenterColor(0.014, 0.014, 0.012, 0.92)
    zonePanel:SetEdgeColor(0.54, 0.41, 0.15, 0.82)
    zonePanel:SetEdgeTexture(nil, 1, 1, 1)
    zonePanel:SetMouseEnabled(false)
    self.statisticsZonePanel = zonePanel

    local header = WINDOW_MANAGER:CreateControl(nil, progressPage, CT_BACKDROP)
    header:SetDimensions(936, 28)
    header:SetAnchor(TOPLEFT, control, TOPLEFT, 22, zoneSectionTop + 34)
    header:SetCenterColor(0.090, 0.066, 0.025, 0.96)
    header:SetEdgeColor(0.62, 0.48, 0.18, 0.74)
    header:SetEdgeTexture(nil, 1, 1, 1)
    self.statisticsHeaderBackdrop = header

    local function HeaderLabel(width, x, align)
        local label = WINDOW_MANAGER:CreateControl(nil, header, CT_LABEL)
        label:SetDimensions(width, 28)
        label:SetAnchor(LEFT, header, LEFT, x, 0)
        label:SetFont("$(BOLD_FONT)|19")
        label:SetColor(0.78, 0.72, 0.58, 1)
        label:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
        label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        return label
    end
    self.statisticsHeaderZone = HeaderLabel(380, 10, TEXT_ALIGN_LEFT)
    self.statisticsHeaderProgress = HeaderLabel(238, 398, TEXT_ALIGN_RIGHT)
    self.statisticsHeaderDone = HeaderLabel(115, 655, TEXT_ALIGN_RIGHT)
    self.statisticsHeaderOpen = HeaderLabel(90, 815, TEXT_ALIGN_RIGHT)

    -- Use a dedicated slider + seven reusable rows instead of ZO_ScrollContainer.
    -- This makes the thumb directly draggable and avoids the generic map scroll
    -- container swallowing mouse input.
    local listArea = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "StatisticsListArea", progressPage, CT_CONTROL)
    listArea:SetDimensions(918, STATISTICS_VISIBLE_ZONE_ROWS * 31)
    listArea:SetAnchor(TOPLEFT, header, BOTTOMLEFT, 0, 4)
    listArea:SetMouseEnabled(true)
    listArea:SetHandler("OnMouseWheel", function(_, delta) TPM:ScrollStatistics(delta) end)
    self.statisticsListArea = listArea

    self.statisticsZoneRows = {}
    for slot = 1, STATISTICS_VISIBLE_ZONE_ROWS do
        self.statisticsZoneRows[slot] = self:CreateStatisticsZoneRow(listArea, slot)
    end

    local scrollBar = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "StatisticsScrollBar", progressPage, CT_SLIDER)
    scrollBar:SetDimensions(14, STATISTICS_VISIBLE_ZONE_ROWS * 31)
    scrollBar:SetAnchor(TOPLEFT, listArea, TOPRIGHT, 5, 0)
    scrollBar:SetOrientation(ORIENTATION_VERTICAL)
    scrollBar:SetMouseEnabled(true)
    local elevator = "/esoui/art/miscellaneous/scrollbox_elevator.dds"
    scrollBar:SetThumbTexture(elevator, elevator, elevator, 18, 48, 0, 0, 1, 1)
    if scrollBar.SetBackgroundMiddleTexture then
        scrollBar:SetBackgroundMiddleTexture("/esoui/art/chatwindow/chat_scrollbar_track.dds", 0, 0, 1, 1)
    end
    scrollBar:SetValueStep(1)
    scrollBar:SetMinMax(0, 0)
    scrollBar:SetValue(0)
    scrollBar:SetHandler("OnValueChanged", function(_, value)
        if TPM.saved and TPM.saved.statisticsPage ~= "progress" then return end
        TPM.statisticsScrollOffset = Clamp(Round(value or 0), 0, TPM:GetStatisticsMaxScrollOffset())
        TPM:RefreshStatisticsZoneRows()
    end)
    self.statisticsScrollBar = scrollBar
    self.statisticsScrollOffset = self.statisticsScrollOffset or 0

    local hint = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
    hint:SetDimensions(930, 18)
    hint:SetAnchor(BOTTOMLEFT, control, BOTTOMLEFT, 22, -48)
    hint:SetFont("$(MEDIUM_FONT)|15")
    hint:SetColor(0.64, 0.61, 0.55, 1)
    hint:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    hint:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    hint:SetHidden(true)
    self.statisticsHint = hint

    -- Every journal section is a real, independent page container in 3.0.
    -- Only one page is visible at a time, preventing refreshes from bleeding
    -- controls into another section.
    -- 2.7.2: Character returns as a dedicated journal page focused on
    -- play time and character activity. PvE/PvP remains a separate combat page.
    self:CreatePlayerStatisticsPage(control)
    self:CreateEconomyStatisticsPage(control)
    self:CreateHistoryStatisticsPage(control)
    self:CreateAllianceStatisticsPage(control)

    local footerDivider = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
    footerDivider:SetDimensions(956, 1)
    footerDivider:SetAnchor(BOTTOMLEFT, control, BOTTOMLEFT, 22, -41)
    footerDivider:SetCenterColor(0.46, 0.35, 0.14, 0.62)
    footerDivider:SetEdgeColor(0, 0, 0, 0)
    self.statisticsFooterDivider = footerDivider

    self.statisticsThemeTabs = {}
    local function CreatePageTab(name, x, pageName, width)
        width = tonumber(width) or 292
        local tabBg = WINDOW_MANAGER:CreateControl(name .. "Bg", control, CT_BACKDROP)
        tabBg:SetDimensions(width, 34)
        tabBg:SetAnchor(BOTTOMLEFT, control, BOTTOMLEFT, x, -4)
        tabBg:SetCenterColor(0.026, 0.023, 0.018, 0.94)
        tabBg:SetEdgeColor(0.36, 0.29, 0.14, 0.70)
        tabBg:SetEdgeTexture(nil, 1, 1, 1)
        tabBg:SetMouseEnabled(false)

        local button = WINDOW_MANAGER:CreateControl(name, control, CT_BUTTON)
        button:SetDimensions(width, 34)
        button:SetAnchorFill(tabBg)
        button:SetFont("$(BOLD_FONT)|18")
        button:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        button:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        button:SetNormalFontColor(0.78, 0.72, 0.58, 1)
        button:SetMouseOverFontColor(1.00, 0.84, 0.36, 1)
        button:SetPressedFontColor(0.95, 0.75, 0.24, 1)
        button:SetMouseEnabled(true)
        button:SetHandler("OnClicked", function() TPM:SetStatisticsPage(pageName) end)
        local accent = WINDOW_MANAGER:CreateControl(nil, tabBg, CT_BACKDROP)
        accent:SetDimensions(math.max(20, width - 10), 2)
        accent:SetAnchor(TOP, tabBg, TOP, 0, 1)
        accent:SetCenterColor(0.90, 0.68, 0.18, 0.88)
        accent:SetEdgeColor(0, 0, 0, 0)
        accent:SetHidden(true)
        button.TPMBackdrop = tabBg
        button.TPMAccent = accent
        button.TPMPageName = pageName
        self.statisticsThemeTabs[#self.statisticsThemeTabs + 1] = button
        return button
    end

    self.statisticsProgressTab = CreatePageTab(ADDON_NAME .. "StatsTabProgress", 22, "progress", 302)
    self.statisticsEconomyTab = CreatePageTab(ADDON_NAME .. "StatsTabEconomy", 338, "economy", 302)
    self.statisticsHistoryTab = CreatePageTab(ADDON_NAME .. "StatsTabHistory", 654, "history", 302)
    self:RefreshStatisticsPageTabs()
    self:RefreshStatisticsSubPageNavigation()
    self:ApplyStatisticsTheme()
end

function TPM:GetStatisticsViewportBounds()
    local parent = GuiRoot
    local parentLeft = (parent and parent.GetLeft and parent:GetLeft()) or 0
    local parentTop = (parent and parent.GetTop and parent:GetTop()) or 0
    local parentWidth = (parent and parent.GetWidth and parent:GetWidth()) or 1920
    local parentHeight = (parent and parent.GetHeight and parent:GetHeight()) or 1080
    local scale = (self.statisticsWindow and self.statisticsWindow.GetScale and self.statisticsWindow:GetScale()) or 1
    local width = ((self.statisticsWindow and self.statisticsWindow:GetWidth()) or 1000) * scale
    local height = ((self.statisticsWindow and self.statisticsWindow:GetHeight()) or 750) * scale
    local margin = 8
    local maxX = math.max(margin, parentWidth - width - margin)
    local maxY = math.max(margin, parentHeight - height - margin)
    return parentLeft, parentTop, margin, margin, maxX, maxY
end

function TPM:ClampStatisticsScreenPosition(x, y)
    local _, _, minX, minY, maxX, maxY = self:GetStatisticsViewportBounds()
    return Clamp(tonumber(x) or minX, minX, maxX), Clamp(tonumber(y) or minY, minY, maxY)
end

function TPM:ClampStatisticsWindowToScreen()
    local control = self.statisticsWindow
    if not control or not GuiRoot then return end
    local left, top = control:GetLeft(), control:GetTop()
    if not left or not top then return end
    local rootLeft, rootTop = GuiRoot:GetLeft() or 0, GuiRoot:GetTop() or 0
    local x, y = self:ClampStatisticsScreenPosition(left - rootLeft, top - rootTop)
    control:ClearAnchors()
    control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    if self.saved then
        self.saved.statisticsWindowX = Round(x)
        self.saved.statisticsWindowY = Round(y)
    end
end

function TPM:ResetStatisticsWindowPosition()
    if self.saved then
        self.saved.statisticsWindowX = false
        self.saved.statisticsWindowY = false
    end
    local control = self.statisticsWindow
    if not control then return end
    control:ClearAnchors()
    control:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    self:ClampStatisticsWindowToScreen()
end

function TPM:SaveStatisticsWindowPosition()
    self:ClampStatisticsWindowToScreen()
end

function TPM:StopMovingStatisticsWindow()
    if not self.statisticsWindowMoving then return end
    self.statisticsWindowMoving = false
    self:UpdateGlobalMouseUpRegistration()
    if self.statisticsWindow then
        self.statisticsWindow:StopMovingOrResizing()
    end
    self:SaveStatisticsWindowPosition()
end

function TPM:GetStatisticsMaxScrollOffset()
    local total = self.statisticsData and #(self.statisticsData.zones or {}) or 0
    return math.max(0, total - STATISTICS_VISIBLE_ZONE_ROWS)
end

function TPM:RefreshStatisticsZoneRows()
    if not self.saved or self.saved.statisticsPage ~= "progress" or self:GetStatisticsProgressSubPage() ~= 1 then return end
    local stats = self.statisticsData
    if not stats then return end
    local maxOffset = self:GetStatisticsMaxScrollOffset()
    local offset = Clamp(Round(self.statisticsScrollOffset or 0), 0, maxOffset)
    self.statisticsScrollOffset = offset

    for slot = 1, STATISTICS_VISIBLE_ZONE_ROWS do
        local row = self.statisticsZoneRows and self.statisticsZoneRows[slot]
        local data = stats.zones[offset + slot]
        if row then
            row:SetHidden(data == nil)
            if data then
                row.zoneId = data.zoneId
                row.mapId = data.mapId
                row.nameLabel:SetText(data.name)
                local isComplete = data.percent >= 100
                if row.completeIcon then row.completeIcon:SetHidden(not isComplete) end
                row.nameLabel:ClearAnchors()
                row.nameLabel:SetAnchor(LEFT, row, LEFT, isComplete and 32 or 10, 0)

                if isComplete then
                    row.baseR, row.baseG, row.baseB, row.baseAlpha = 0.10, 0.095, 0.018, 0.72
                    row.bg:SetCenterColor(row.baseR, row.baseG, row.baseB, row.baseAlpha)
                    row.bg:SetEdgeColor(0.68, 0.62, 0.06, 0.78)
                    row.nameLabel:SetColor(0.88, 0.93, 0.20, 1)
                else
                    row.baseR, row.baseG, row.baseB = 0.035, 0.031, 0.024
                    row.baseAlpha = slot % 2 == 0 and 0.58 or 0.34
                    row.bg:SetCenterColor(row.baseR, row.baseG, row.baseB, row.baseAlpha)
                    row.bg:SetEdgeColor(0.30, 0.25, 0.14, 0.22)
                    row.nameLabel:SetColor(0.94, 0.92, 0.86, 1)
                end

                local percentColor = self:GetStatisticsPercentTextColor(data.percent)
                row.percentLabel:SetText(string.format("|c%s%d%%|r", percentColor, data.percent))
                row.doneLabel:SetText(string.format("%d / %d", data.completed, data.total))
                row.openLabel:SetText(tostring(data.remaining))
                if data.remaining <= 0 then
                    row.openLabel:SetColor(0.62, 0.86, 0.24, 1)
                elseif data.remaining <= 10 then
                    row.openLabel:SetColor(0.98, 0.82, 0.28, 1)
                else
                    row.openLabel:SetColor(0.95, 0.70, 0.20, 1)
                end
                self:SetStatisticsBarPercent(row.progressFill, 170, data.percent)
            else
                row.zoneId = nil
                row.mapId = nil
            end
        end
    end
    self:EnforceStatisticsDarkModeAfterRefresh()
end

function TPM:ScrollStatistics(delta)
    if not self.saved or self.saved.statisticsPage ~= "progress" or self:GetStatisticsProgressSubPage() ~= 1 then return end
    local maxOffset = self:GetStatisticsMaxScrollOffset()
    local current = Clamp(Round(self.statisticsScrollOffset or 0), 0, maxOffset)
    -- ESO sends positive delta when scrolling up.
    local nextValue = Clamp(current - (tonumber(delta) or 0), 0, maxOffset)
    self.statisticsScrollOffset = nextValue
    if self.statisticsScrollBar then
        self.statisticsScrollBar:SetValue(nextValue)
    end
    self:RefreshStatisticsZoneRows()
end

function TPM:RefreshStatisticsPlayerProgress()
    if not self.statisticsWindow or self.statisticsWindow:IsHidden() then return end
    -- Character progression is page 2 of PvE/PvP.
    if self.saved and self.saved.statisticsPage == "history" and self:GetStatisticsHistorySubPage() == 2 then
        self:RefreshPlayerStatisticsPage()
    end
end

function TPM:RefreshStatisticsWindow()
    if self.statisticsHint then self.statisticsHint:SetHidden(true) end
    -- Keep the large journal lazy. ShowStatisticsWindow/ToggleStatisticsWindow
    -- create it on demand; routine map refreshes should not allocate it.
    local control = self.statisticsWindow
    if not control or control:IsHidden() then return end

    local page = self.saved and self.saved.statisticsPage or "progress"
    -- Normalize legacy direct Character/Alliance page requests before painting
    -- anything. This avoids a one-frame flash of the wrong subpage.
    if page == "player" then
        page = "history"
        if self.saved then
            self.saved.statisticsPage = page
            self.saved.statisticsHistorySubPage = 2
        end
    elseif page == "alliance" then
        page = "progress"
        if self.saved then
            self.saved.statisticsPage = page
            self.saved.statisticsProgressSubPage = 2
        end
    elseif not self:IsValidStatisticsPage(page) then
        page = "progress"
        if self.saved then self.saved.statisticsPage = page end
    end
    self:UpdateStatisticsPageVisibility(page)
    self:RefreshStatisticsPageTabs()

    self:RefreshStatisticsSubPageNavigation()
    local progressMainPage = page == "progress" and self:GetStatisticsProgressSubPage() == 1
    if self.statisticsThemeGear then self.statisticsThemeGear:SetHidden(not progressMainPage) end
    if self.statisticsThemeGearLabel then self.statisticsThemeGearLabel:SetHidden(not progressMainPage) end

    if page == "economy" then
        self.statisticsTitle:SetText(self:L("STAT_ECONOMY_PAGE_TITLE"))
        self.statisticsMode:SetText(self:L("STAT_ECONOMY_PAGE_MODE"))
        self:RefreshEconomyStatisticsPage()
        self:EnforceStatisticsDarkModeAfterRefresh()
        return
    elseif page == "history" then
        if self:GetStatisticsHistorySubPage() == 2 then
            self.statisticsTitle:SetText(self:L("STAT_PLAYER_PAGE_TITLE"))
            self:RefreshPlayerStatisticsPage()
        else
            self.statisticsTitle:SetText(self:L("HISTORY_PAGE_TITLE"))
            self:RefreshHistoryStatisticsPage()
        end
        self:EnforceStatisticsDarkModeAfterRefresh()
        return
    elseif page == "progress" and self:GetStatisticsProgressSubPage() == 2 then
        self.statisticsTitle:SetText(self:L("STAT_ALLIANCE_PAGE_TITLE"))
        self:RefreshAllianceStatisticsPage()
        self:EnforceStatisticsDarkModeAfterRefresh()
        return
    end

    self:SetProgressStatisticsControlsHidden(false)
    local focusZoneId = self:GetStatisticsFocusZoneId()
    local stats = self:GetStatisticsData(false, focusZoneId)
    self.statisticsData = stats

    self.statisticsTitle:SetText(string.format("%s  v%s", self:L("STATISTICS_TITLE"), (VERSION:gsub("_", "-"))))
    self.statisticsMode:SetText(self:L("STAT_MODE", self.saved.calculationMode == "categories" and self:L("MODE_CATEGORIES") or self:L("MODE_OBJECTIVES")))
    if self.statisticsFocusLabel then self.statisticsFocusLabel:SetText(self:L("STAT_FOCUS_LABEL")) end
    self:RefreshStatisticsFocusSelector()
    if focusZoneId > 0 then
        local focusName = stats.focusName or SafeZoneName(focusZoneId)
        self.statisticsTamrielLabel:SetText(focusName)
        self.statisticsSubtitle:SetText(self:L("STATISTICS_SUBTITLE_ZONE", focusName))
    else
        self.statisticsTamrielLabel:SetText(self:L("TAMRIEL_TOTAL"))
        self.statisticsSubtitle:SetText(self:L("STATISTICS_SUBTITLE"))
    end

    local color = self:GetStatisticsPercentTextColor(stats.percent)
    self.statisticsOverall:SetText(string.format("|c%s%d%%|r", color, stats.percent))
    self:SetStatisticsBarPercent(self.statisticsOverallFill, 758, stats.percent)
    if self.statisticsOverallBarPercent then
        self.statisticsOverallBarPercent:SetText(string.format("%d%%", stats.percent))
    end

    local cards = self.statisticsCards or {}
    if cards[1] then
        cards[1].title:SetText(self:L("STAT_COMPLETE_ZONES"))
        cards[1].value:SetText(self:L("STAT_OF_ZONES", stats.completedZones, stats.totalZones))
    end
    if cards[2] then
        cards[2].title:SetText(self:L("STAT_OBJECTIVES"))
        cards[2].value:SetText(self:L("STAT_OF_OBJECTIVES", stats.completedObjectives, stats.totalObjectives))
    end
    if cards[3] then
        cards[3].title:SetText(self:L("STAT_REMAINING"))
        cards[3].value:SetText(tostring(stats.remainingObjectives))
    end
    if cards[4] then
        cards[4].title:SetText(self:L("STAT_UNTOUCHED"))
        cards[4].value:SetText(tostring(stats.untouchedZones))
    end
    if self.statisticsPlaytimeCard then
        -- Keep this live without bringing the old Development playtime page back.
        self:CheckpointHistory("progress_view", false)
        local totalPlayed = self:SyncCurrentEsoPlayedTime()
        local todayPlayed = self:GetTodayPlaySeconds()
        self.statisticsPlaytimeCard.title:SetText(self:L("STAT_CHARACTER_PLAY_TIME"))
        self.statisticsPlaytimeCard.value:SetText(TPM_FormatDuration(totalPlayed or 0))
        self.statisticsPlaytimeCard.detail:SetText(self:L("STAT_CHARACTER_PLAY_TIME_TODAY", TPM_FormatDuration(todayPlayed or 0)))
    end

    self:RefreshStatisticsPlayerProgress()

    self.statisticsCategoryTitle:SetText(self:L("STAT_CATEGORIES"))
    self:RefreshStatisticsCategorySortControls()
    local displayedCategories = self:SortStatisticsCategoryData(stats.categories, false)
    for index, categoryControl in ipairs(self.statisticsCategoryRows or {}) do
        local data = displayedCategories[index]
        categoryControl.control:SetHidden(data == nil)
        if data then
            categoryControl.label:SetText(data.name)
            categoryControl.count:SetText(data.countText or string.format("%d/%d", data.completed, data.total))
            if data.informational then
                categoryControl.percent:SetText("—")
                self:SetStatisticsBarPercent(categoryControl.fill, 96, 0)
                categoryControl.fill:SetHidden(true)
            else
                categoryControl.percent:SetText(string.format("|c%s%d%%|r", self:GetStatisticsPercentTextColor(data.percent), data.percent))
                categoryControl.fill:SetHidden(false)
                self:SetStatisticsBarPercent(categoryControl.fill, 96, data.percent)
            end
            if categoryControl.icon then
                local iconTexture = STATISTICS_CATEGORY_ICON_TEXTURES[data.completionType] or "NagaMapaCompleto/art/cat_quests.dds"
                categoryControl.icon:SetTexture(iconTexture)
                local ir, ig, ib = self:GetStatisticsProgressColor(data.percent)
                categoryControl.icon:SetColor(ir, ig, ib, 0.96)
            end
            local hudRowActive = self:IsProgressGoalCategoryActive(data.completionType)
            if categoryControl.gearButton then
                categoryControl.gearButton:SetHidden(true)
                categoryControl.gearButton:SetHandler("OnMouseEnter", nil)
                categoryControl.gearButton:SetHandler("OnMouseExit", nil)
                categoryControl.gearButton:SetHandler("OnClicked", nil)
                categoryControl.gearButton:SetHandler("OnMouseUp", nil)
            end
            categoryControl.label:SetColor(hudRowActive and 1.00 or 0.92, hudRowActive and 1.00 or 0.89, hudRowActive and 1.00 or 0.81, 1)
            categoryControl.bg:SetEdgeColor(hudRowActive and 0.82 or 0.28, hudRowActive and 0.74 or 0.23, hudRowActive and 0.48 or 0.12, hudRowActive and 0.70 or 0.20)

            local tooltipName = data.name
            local tooltipText = data.tooltipText or ""
            categoryControl.control:SetMouseEnabled(true)
            categoryControl.control:SetHandler("OnMouseEnter", function()
                TPM:ShowStatisticsHoverTooltip(tooltipName, tooltipText, categoryControl.control)
            end)
            categoryControl.control:SetHandler("OnMouseExit", function() TPM:HideStatisticsHoverTooltips() end)
            categoryControl.control:SetHandler("OnMouseUp", function(_, button, upInside)
                if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
                    TPM:HideStatisticsHoverTooltips()
                    TPM:ToggleSkyshardGoalWidget(data.completionType)
                end
            end)
        end
    end

    -- Apply page 1/2/3 visibility only after the unchanged completion rows have
    -- refreshed, so switching pages cannot alter their data or Tamriel %.
    self:RefreshStatisticsCollectionPager()

    if self.statisticsCategoryGearButton then
        local activeType = self:GetActiveProgressGoalCategoryType()
        local showGear = (tonumber(self.saved.statisticsCompletionPage) or 1) == 1 and activeType ~= nil
        local editing = self.skyshardGoalEditMode == true
        self.statisticsCategoryGearButton:SetHidden(not showGear)
        self.statisticsCategoryGearButton:SetMouseEnabled(showGear)
        if self.statisticsCategoryGearIcon then
            self.statisticsCategoryGearIcon:SetColor(showGear and (editing and 1.00 or 0.88) or 0.55, showGear and (editing and 0.82 or 0.82) or 0.52, showGear and (editing and 0.24 or 0.64) or 0.46, showGear and (editing and 1.00 or 0.92) or 0.80)
        end
        self.statisticsCategoryGearButton:SetHandler("OnMouseEnter", showGear and function(button)
            if button.TPMIcon then if TPM:IsStatisticsDarkDesign() then button.TPMIcon:SetColor(1,1,1,1) else button.TPMIcon:SetColor(1.00, 0.86, 0.30, 1) end end
            local completionType = TPM:GetActiveProgressGoalCategoryType()
            local title = TPM:L("STAT_GOAL_HUD_GEAR_TITLE", TPM:GetProgressGoalCategoryDisplayName(completionType))
            local body = TPM:L("STAT_GOAL_HUD_GEAR_TT")
            TPM:ShowStatisticsHoverTooltip(title, body, button)
        end or nil)
        self.statisticsCategoryGearButton:SetHandler("OnMouseExit", showGear and function(button)
            local activeEditor = TPM.skyshardGoalEditMode == true
            if button.TPMIcon then
                if TPM:IsStatisticsDarkDesign() then button.TPMIcon:SetColor(1,1,1,activeEditor and 1 or .92)
                else button.TPMIcon:SetColor(activeEditor and 1.00 or 0.88, activeEditor and 0.82 or 0.82, activeEditor and 0.24 or 0.64, activeEditor and 1.00 or 0.92) end
            end
            TPM:HideStatisticsHoverTooltips()
        end or nil)
        self.statisticsCategoryGearButton:SetHandler("OnClicked", showGear and function()
            TPM:HideStatisticsHoverTooltips()
            TPM:ToggleSkyshardGoalEditMode()
        end or nil)
        self.statisticsCategoryGearButton:SetHandler("OnMouseUp", showGear and function(_, button, upInside)
            if upInside and button == MOUSE_BUTTON_INDEX_RIGHT then
                TPM:ResetSkyshardGoalCustomPosition()
            end
        end or nil)
    end

    self.statisticsZoneTitle:SetText(self:L("STAT_ZONE_PROGRESS", stats.totalZones))
    self.statisticsHeaderZone:SetText(self:L("STAT_ZONE"))
    self.statisticsHeaderProgress:SetText(self:L("STAT_PROGRESS"))
    self.statisticsHeaderDone:SetText(self:L("STAT_DONE"))
    self.statisticsHeaderOpen:SetText(self:L("STAT_OPEN"))

    if self.statisticsSortProgress then self.statisticsSortProgress:SetHidden(true) end
    if self.statisticsSortName then
        self.statisticsSortName:SetHidden(false)
        self.statisticsSortName:SetMouseEnabled(false)
        self.statisticsSortName:SetText(self:L("STAT_SORT_ALPHABETICAL"))
    end

    local maxOffset = self:GetStatisticsMaxScrollOffset()
    self.statisticsScrollOffset = Clamp(Round(self.statisticsScrollOffset or 0), 0, maxOffset)
    if self.statisticsScrollBar then
        self.statisticsScrollBar:SetMinMax(0, maxOffset)
        self.statisticsScrollBar:SetValueStep(1)
        self.statisticsScrollBar:SetValue(self.statisticsScrollOffset)
        self.statisticsScrollBar:SetHidden(maxOffset <= 0)
    end
    self:RefreshStatisticsZoneRows()
    self:EnforceStatisticsDarkModeAfterRefresh()
end
function TPM:OpenWorldMapFromStatistics(mapId)
    mapId = tonumber(mapId) or 0
    if mapId <= 0 then return false end

    -- Clicking a zone is the one place where the standalone journal should
    -- deliberately transition into ESO's map. Close the journal first, show
    -- the correct keyboard/gamepad map scene, then select the requested map
    -- after ESO has initialized the scene.
    self.statisticsOpenedStandalone = false
    self:HideStatisticsWindow()

    local function SelectMap()
        if TPM and WORLD_MAP_MANAGER and WORLD_MAP_MANAGER.SetMapById then
            WORLD_MAP_MANAGER:SetMapById(mapId)
            TPM:QueueRefresh(30)
        end
    end

    if self:IsFullWorldMapSceneVisible() then
        SelectMap()
        return true
    end

    if SCENE_MANAGER and SCENE_MANAGER.Show then
        local sceneName = "worldMap"
        if type(IsInGamepadPreferredMode) == "function" and IsInGamepadPreferredMode() then
            sceneName = "gamepad_worldMap"
        end
        SCENE_MANAGER:Show(sceneName)
        if type(zo_callLater) == "function" then
            zo_callLater(SelectMap, 120)
        else
            SelectMap()
        end
        return true
    end
    return false
end

-- 2.6.34: Standalone Statistics owns UI mouse mode only while opened by TPM.
function TPM:SetStandaloneStatisticsUIMode(enabled)
    enabled = enabled == true

    if enabled then
        local alreadyInUiMode = IsGameCameraUIModeActive() == true

        -- Only establish ownership once. A later safety re-assert must never
        -- overwrite statisticsOwnsUIMode=false merely because TPM itself
        -- already enabled UI mode a few milliseconds earlier.
        if not self.statisticsUIModeActiveForStandalone then
            self.statisticsUIModeWasAlreadyActive = alreadyInUiMode
            SetGameCameraUIMode(true)
            self.statisticsOwnsUIMode = not alreadyInUiMode
            self.statisticsUIModeActiveForStandalone = true
        else
            SetGameCameraUIMode(true)
        end

        self.statisticsUIModeOpenedAt = GetFrameTimeMilliseconds() or 0

        -- A remapped gameplay key can be processed again by ESO after the
        -- binding callback. Re-assert UI mode without changing TPM ownership.
        zo_callLater(function()
            if TPM.statisticsOpenedStandalone and TPM.statisticsWindow and not TPM.statisticsWindow:IsHidden() then
                SetGameCameraUIMode(true)
            end
        end, 0)
        zo_callLater(function()
            if TPM.statisticsOpenedStandalone and TPM.statisticsWindow and not TPM.statisticsWindow:IsHidden() then
                SetGameCameraUIMode(true)
                TPM.statisticsUIModeOpenedAt = GetFrameTimeMilliseconds() or TPM.statisticsUIModeOpenedAt
            end
        end, 80)
    else
        if self.statisticsOwnsUIMode then SetGameCameraUIMode(false) end
        self.statisticsOwnsUIMode = false
        self.statisticsUIModeWasAlreadyActive = false
        self.statisticsUIModeActiveForStandalone = false
        self.statisticsUIModeOpenedAt = 0
    end
end


-- 2.6.83: Slightly slower ESO-style fade for both opening and closing.
-- Only alpha is animated, so saved position, scale, anchors and dimensions stay untouched.
local TPM_STATISTICS_FADE_MS = 250

function TPM:PlayStatisticsOpenAnimation()
    local window = self.statisticsWindow
    if not window then return end

    self.statisticsCloseAnimationToken = (tonumber(self.statisticsCloseAnimationToken) or 0) + 1
    self.statisticsCloseAnimationPending = false
    if self.statisticsCloseTimeline then self.statisticsCloseTimeline:Stop() end

    if not self.statisticsOpenTimeline then
        local timeline = ANIMATION_MANAGER:CreateTimeline()
        local alpha = timeline:InsertAnimation(ANIMATION_ALPHA, window, 0)
        alpha:SetAlphaValues(0, 1)
        alpha:SetDuration(TPM_STATISTICS_FADE_MS)
        self.statisticsOpenTimeline = timeline
    end

    local timeline = self.statisticsOpenTimeline
    timeline:Stop()
    window:SetAlpha(0)
    timeline:PlayFromStart()
end


function TPM:FinalizeStatisticsWindowHide(closeToken)
    if closeToken ~= nil and closeToken ~= self.statisticsCloseAnimationToken then return end
    self.statisticsCloseAnimationPending = false
    if self.alliancePlannerMapDragging then self:EndAlliancePlannerMapPan() end

    if self.statisticsWindow then
        self.statisticsWindow:SetAlpha(1)
        self.statisticsWindow:SetHidden(true)
    end
    if self.economyDetailWindow then
        self.economyDetailWindow:SetHidden(true)
    end
    self.economyDetailTemporarilyHiddenForScene = false
    self:SetStandaloneStatisticsUIMode(false)
    self.statisticsOpenedStandalone = false
    self.statisticsTemporarilyHiddenForScene = false
    self:RefreshQuickFilterBar()
    if type(zo_callLater) == "function" then
        zo_callLater(function() TPM:RefreshSkyshardGoalWidget() end, 30)
    end
    if self:IsWorldMapVisible() then
        self:RefreshQuestRewards()
        self:QueueRefresh(20)
    end
end

function TPM:PlayStatisticsCloseAnimation()
    local window = self.statisticsWindow
    if not window or window:IsHidden() then
        self:FinalizeStatisticsWindowHide()
        return
    end
    if self.statisticsCloseAnimationPending then return end

    if self.statisticsOpenTimeline then self.statisticsOpenTimeline:Stop() end

    self.statisticsCloseAnimationToken = (tonumber(self.statisticsCloseAnimationToken) or 0) + 1
    local closeToken = self.statisticsCloseAnimationToken
    self.statisticsCloseAnimationPending = true

    if not self.statisticsCloseTimeline then
        local timeline = ANIMATION_MANAGER:CreateTimeline()
        local alpha = timeline:InsertAnimation(ANIMATION_ALPHA, window, 0)
        alpha:SetAlphaValues(1, 0)
        alpha:SetDuration(TPM_STATISTICS_FADE_MS)
        self.statisticsCloseTimeline = timeline
    end

    window:SetAlpha(1)
    local timeline = self.statisticsCloseTimeline
    timeline:Stop()
    timeline:PlayFromStart()

    zo_callLater(function()
        TPM:FinalizeStatisticsWindowHide(closeToken)
    end, TPM_STATISTICS_FADE_MS + 20)
end


function TPM:ShowStatisticsWindow(openStandalone)
    self:CreateStatisticsWindow()
    if not self.statisticsWindow then return false end
    if openStandalone == nil then
        openStandalone = not self:IsFullWorldMapSceneVisible()
    end
    self.statisticsOpenedStandalone = openStandalone == true
    self.statisticsTemporarilyHiddenForScene = false
    self.statisticsWindow:SetHidden(false)
    self:PlayStatisticsOpenAnimation()
    if self.statisticsOpenedStandalone then
        self:SetStandaloneStatisticsUIMode(true)
    end
    self:ClampStatisticsWindowToScreen()
    self:HideQuestRewards()
    if self.skyshardGoalWidget then self:RefreshSkyshardGoalWidget() end
    -- Always take a fresh snapshot when the journal is opened. While it stays
    -- open, completion events invalidate the cache as needed.
    self:InvalidateStatisticsData(false)
    self:RefreshStatisticsWindow()
    self:RefreshQuickFilterBar()
    self:QueueRefresh(20)
    if self.statisticsOpenedStandalone then
        self:RefreshStandaloneStatisticsSceneVisibility()
    end
    return true
end

function TPM:HideStatisticsWindow()
    if self.statisticsThemeWindow and not self.statisticsThemeWindow:IsHidden() then self:SetStatisticsThemeWindowVisible(false) end
    self:HideEconomyFocusDropdown()
    self:HideStatisticsHoverTooltips()
    self:HideStatisticsFocusDropdown()
    TPM_HideAchievementTooltip()
    -- Keep the Skyshard HUD editor alive when the world map closes. The gear
    -- button is the explicit editor toggle: moving/resizing stays active until
    -- the user clicks the gear again to save.
    if self.statisticsWindowMoving then
        self:StopMovingStatisticsWindow()
    end
    self:PlayStatisticsCloseAnimation()
end
function TPM:ToggleStatisticsWindow(openStandalone)
    self:CreateStatisticsWindow()
    if not self.statisticsWindow then return end
    -- A standalone journal may be temporarily hidden while an ESO fullscreen
    -- menu is active. Treat it as logically open so pressing the key again
    -- actually closes it instead of reopening a hidden copy.
    if self.statisticsOpenedStandalone and self.statisticsTemporarilyHiddenForScene then
        self:HideStatisticsWindow()
    elseif self.statisticsWindow:IsHidden() then
        self:ShowStatisticsWindow(openStandalone)
    else
        self:HideStatisticsWindow()
    end
end

function TPM:ToggleStatisticsFromKeybind()
    -- Keybind/slash openings are always standalone. Handle the open path
    -- explicitly so every remapped binding acquires mouse/UI mode reliably.
    self:CreateStatisticsWindow()
    if not self.statisticsWindow then return end

    if self.statisticsOpenedStandalone and self.statisticsTemporarilyHiddenForScene then
        self:HideStatisticsWindow()
        return
    end

    if self.statisticsWindow:IsHidden() then
        -- ShowStatisticsWindow(true) owns the single activation path.
        -- Its delayed safety re-asserts keep remapped keys reliable without
        -- changing UI-mode ownership a second time.
        self:ShowStatisticsWindow(true)
    else
        self:HideStatisticsWindow()
    end
end

function TPM.KeybindToggleStatistics()
    TPM:ToggleStatisticsFromKeybind()
end

function TPM:GetQuestBestRewardDisplayQuality(questIndex)
    if not questIndex or not IsValidQuestIndex(questIndex) then return nil end
    if type(GetJournalQuestNumRewards) ~= "function" or type(GetJournalQuestRewardInfo) ~= "function" then return nil end
    local bestQuality = nil
    local numRewards = GetJournalQuestNumRewards(questIndex) or 0
    for rewardIndex = 1, numRewards do
        local rewardType, _, _, _, _, itemDisplayQuality = GetJournalQuestRewardInfo(questIndex, rewardIndex)
        local currencyType = nil
        if type(GetCurrencyTypeFromRewardType) == "function" then
            currencyType = GetCurrencyTypeFromRewardType(rewardType)
            if CURT_NONE and currencyType == CURT_NONE then currencyType = nil end
        end
        local itemId = 0
        if type(GetJournalQuestRewardItemId) == "function" then
            itemId = tonumber(GetJournalQuestRewardItemId(questIndex, rewardIndex)) or 0
        end
        -- Only actual item rewards determine the quest color. Gold, XP,
        -- currencies, skill points and other non-item rewards therefore remain
        -- white exactly as the feature promises.
        if (not currencyType or currencyType == 0) and itemId > 0 then
            local quality = tonumber(itemDisplayQuality)
            if quality and quality >= 0 then
                if bestQuality == nil or quality > bestQuality then bestQuality = quality end
            end
        end
    end
    return bestQuality
end

function TPM:GetQuestRewardColorDef(questIndex)
    if not self.saved or self.saved.colorVanillaQuestsByReward == false then return nil end
    local quality = self:GetQuestBestRewardDisplayQuality(questIndex)
    if quality ~= nil then
        local color = GetItemQualityColor(quality)
        if color then return color end
    end
    -- Currency-only/no-item quests stay white as requested instead of inheriting
    -- ESO's level/con difficulty color.
    if ZO_ColorDef then
        self.questRewardWhiteColor = self.questRewardWhiteColor or ZO_ColorDef:New(1, 1, 1, 1)
        return self.questRewardWhiteColor
    end
    return nil
end

function TPM:ApplyWorldMapQuestRewardColor(control, data)
    if not control or not data then return end
    local nameControl = GetControl(control, "Name")
    if not nameControl then return end
    local color = self:GetQuestRewardColorDef(data.questIndex)
    if color and type(ZO_SelectableLabel_SetNormalColor) == "function" then
        ZO_SelectableLabel_SetNormalColor(nameControl, color)
    end
end
function TPM:ApplyFocusedQuestRewardColor(questHeader)
    if not questHeader or not questHeader.m_Data then return end
    local questIndex = nil
    if questHeader.m_Data.GetJournalIndex then
        questIndex = questHeader.m_Data:GetJournalIndex()
    else
        questIndex = questHeader.m_Data.arg1
    end
    if not questIndex then return end
    if self.saved and self.saved.colorVanillaQuestsByReward ~= false then
        local color = self:GetQuestRewardColorDef(questIndex)
        if color and color.UnpackRGBA then questHeader:SetColor(color:UnpackRGBA()) end
    else
        questHeader:SetColor(GetConColor(questHeader.m_Data.level))
    end
end
function TPM:RefreshVanillaQuestRewardColors()
    if WORLD_MAP_QUESTS and WORLD_MAP_QUESTS.RefreshHeaders then
        WORLD_MAP_QUESTS:RefreshHeaders()
    end
    if FOCUSED_QUEST_TRACKER and FOCUSED_QUEST_TRACKER.headerPool then
        for _, header in pairs(FOCUSED_QUEST_TRACKER.headerPool:GetActiveObjects() or {}) do
            self:ApplyFocusedQuestRewardColor(header)
        end
    end
end
function TPM:RegisterVanillaQuestRewardColorHooks()
    if self.questRewardColorHooksRegistered or type(ZO_PostHook) ~= "function" then return end

    if not self.questRewardWorldMapHooked and WORLD_MAP_QUESTS and WORLD_MAP_QUESTS.SetupQuestHeader then
        ZO_PostHook(WORLD_MAP_QUESTS, "SetupQuestHeader", function(_, control, data)
            TPM:ApplyWorldMapQuestRewardColor(control, data)
        end)
        self.questRewardWorldMapHooked = true
    end

    if not self.questRewardFocusedHooked and ZO_Tracker and ZO_Tracker.InitializeQuestHeader then
        ZO_PostHook(ZO_Tracker, "InitializeQuestHeader", function(_, _, _, questHeader)
            TPM:ApplyFocusedQuestRewardColor(questHeader)
        end)
        if ZO_Tracker.RefreshHeaderConColors then
            ZO_PostHook(ZO_Tracker, "RefreshHeaderConColors", function(tracker)
                if tracker and tracker.headerPool then
                    for _, header in pairs(tracker.headerPool:GetActiveObjects() or {}) do
                        TPM:ApplyFocusedQuestRewardColor(header)
                    end
                end
            end)
        end
        self.questRewardFocusedHooked = true
    end

    self.questRewardColorHooksRegistered = self.questRewardWorldMapHooked and self.questRewardFocusedHooked
    if self.questRewardWorldMapHooked or self.questRewardFocusedHooked then
        self:RefreshVanillaQuestRewardColors()
    end
    if not self.questRewardColorHooksRegistered and type(zo_callLater) == "function" then
        zo_callLater(function() TPM:RegisterVanillaQuestRewardColorHooks() end, 1000)
    end
end

function TPM:SetQuickFilter(value)
    if value ~= "all" and value ~= "incomplete" and value ~= "under50" and value ~= "complete" then
        return false
    end
    self.saved.quickFilter = value
    self:RefreshQuickFilterBar()
    self:QueueRefresh(10)
    return true
end

function TPM:CreateQuickFilterBar()
    if self.quickFilterBar then return end
    if not ZO_WorldMap or not ZO_WorldMapScroll then return end

    local bar = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "QuickFilterBar", ZO_WorldMap, CT_CONTROL)
    bar:SetDimensions(506, 38)
    bar:SetAnchor(TOPLEFT, ZO_WorldMapScroll, TOPLEFT, 10, -36)
    bar:SetDrawLayer(DL_OVERLAY)
    bar:SetDrawTier(DT_HIGH)
    if bar.SetDrawLevel then bar:SetDrawLevel(4500) end
    bar:SetMouseEnabled(false)
    bar:SetHidden(true)
    self.quickFilterBar = bar

    local bg = WINDOW_MANAGER:CreateControl(nil, bar, CT_BACKDROP)
    bg:SetAnchorFill(bar)
    bg:SetCenterColor(0.06, 0.08, 0.11, 0.88)
    bg:SetEdgeColor(0.30, 0.65, 0.85, 0.85)
    bg:SetEdgeTexture(nil, 1, 1, 1)
    bg:SetMouseEnabled(false)

    local definitions =
    {
        { key = "all", labelKey = "FILTER_ALL" },
        { key = "incomplete", labelKey = "FILTER_INCOMPLETE" },
        { key = "under50", labelKey = "FILTER_UNDER_50" },
        { key = "complete", labelKey = "FILTER_COMPLETE" },
    }

    bar.buttons = {}
    for index, data in ipairs(definitions) do
        local button = WINDOW_MANAGER:CreateControlFromVirtual(nil, bar, "ZO_DefaultButton")
        button:SetDimensions(92, 28)
        button:SetAnchor(LEFT, bar, LEFT, 5 + ((index - 1) * 96), 0)
        button.filterKey = data.key
        button.filterLabelKey = data.labelKey
        button:SetHandler("OnClicked", function(btn)
            TPM:SetQuickFilter(btn.filterKey)
        end)
        bar.buttons[#bar.buttons + 1] = button
    end

    local statsButton = WINDOW_MANAGER:CreateControlFromVirtual(nil, bar, "ZO_DefaultButton")
    statsButton:SetDimensions(112, 28)
    statsButton:SetAnchor(LEFT, bar, LEFT, 389, 0)
    statsButton:SetHandler("OnClicked", function()
        TPM:ToggleStatisticsWindow()
    end)
    bar.statisticsButton = statsButton
end

function TPM:RefreshQuickFilterBar()
    self:CreateQuickFilterBar()
    local bar = self.quickFilterBar
    if not bar then return end

    local visible = self.saved
        and self.saved.enabled
        and self.saved.showQuickFilters
        and self:IsFullWorldMapSceneVisible()
    bar:SetHidden(not visible)
    if not visible then return end

    local current = self.saved.quickFilter or "all"
    for _, button in ipairs(bar.buttons or {}) do
        local text = self:L(button.filterLabelKey)
        if button.filterKey == current then
            text = "|c5EC8F0" .. text .. "|r"
        end
        button:SetText(text)
    end

    if bar.statisticsButton then
        local text = self:L("STATISTICS_BUTTON")
        if self.statisticsWindow and not self.statisticsWindow:IsHidden() then
            text = "|c5EC8F0" .. text .. "|r"
        end
        bar.statisticsButton:SetText(text)
    end
end

function TPM:CreateHeaderProgressLabel()
    if self.headerLabel then return end
    if not ZO_WorldMap or not ZO_WorldMapScroll then return end

    -- Keep header UI fixed to the map viewport. ZO_WorldMapContainer itself is
    -- the zoomable/pannable map content.
    local label = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "HeaderProgress", ZO_WorldMap, CT_LABEL)
    local headerFontSize = self:GetProgressFontSize("header")
    label:SetDimensions(math.max(220, headerFontSize * 5), math.max(54, headerFontSize + 12))
    self:ApplyProgressFont(label, "header")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetDrawLayer(DL_OVERLAY)
    label:SetDrawTier(DT_HIGH)
    label:SetMouseEnabled(false)
    label:SetAnchor(TOP, ZO_WorldMapScroll, TOP, 0, 34)
    label:SetHidden(true)
    self.headerLabel = label

    local categoryLabel = WINDOW_MANAGER:CreateControl(ADDON_NAME .. "HeaderCategories", ZO_WorldMap, CT_LABEL)
    categoryLabel:SetDimensions(650, 88)
    categoryLabel:SetFont("ZoFontGameSmall")
    categoryLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    categoryLabel:SetVerticalAlignment(TEXT_ALIGN_TOP)
    categoryLabel:SetDrawLayer(DL_OVERLAY)
    categoryLabel:SetDrawTier(DT_HIGH)
    categoryLabel:SetMouseEnabled(false)
    categoryLabel:SetAnchor(TOP, label, BOTTOM, 0, 2)
    categoryLabel:SetHidden(true)
    self.headerCategoryLabel = categoryLabel
end

function TPM:ApplyHeaderProgressAnchor()
    if not self.headerLabel or not ZO_WorldMapScroll then return end

    local gamepadMap = self.gamepadWorldMapSceneVisible == true
    if not gamepadMap and GAMEPAD_WORLD_MAP_SCENE and GAMEPAD_WORLD_MAP_SCENE.IsShowing then
        gamepadMap = GAMEPAD_WORLD_MAP_SCENE:IsShowing()
    end

    self.headerLabel:ClearAnchors()
    if gamepadMap then
        self.headerLabel:SetAnchor(TOPRIGHT, ZO_WorldMapScroll, TOPRIGHT, -120, 76)
        self.headerLabel:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    else
        self.headerLabel:SetAnchor(TOP, ZO_WorldMapScroll, TOP, 0, 34)
        self.headerLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    end

    if self.headerCategoryLabel then
        self.headerCategoryLabel:ClearAnchors()
        self.headerCategoryLabel:SetAnchor(TOP, self.headerLabel, BOTTOM, 0, 2)
    end
end

function TPM:HideHeaderProgress()
    if self.headerLabel then
        self.headerLabel:SetHidden(true)
        self.headerLabel.zoneId = nil
        self.headerLabel.progressZoneId = nil
        self.headerLabel.percent = nil
    end
    if self.headerCategoryLabel then
        self.headerCategoryLabel:SetHidden(true)
        self.headerCategoryLabel:SetText("")
    end
end

function TPM:RefreshHeaderProgress()
    self:CreateHeaderProgressLabel()
    if not self.headerLabel then return end

    local headerFontSize = self:GetProgressFontSize("header")
    self.headerLabel:SetDimensions(math.max(220, headerFontSize * 5), math.max(54, headerFontSize + 12))
    self:ApplyProgressFont(self.headerLabel, "header")
    self:ApplyHeaderProgressAnchor()

    if not self.saved or not self.saved.enabled or not self.saved.showHeader or not self:IsWorldMapVisible() then
        self:HideHeaderProgress()
        return
    end

    local mapType = GetMapType()

    if mapType == MAPTYPE_WORLD or mapType == MAPTYPE_COSMIC then
        local percent, completedTotal, availableTotal, zoneCount = self:GetTamrielProgress()
        if availableTotal <= 0 and zoneCount <= 0 then
            self:HideHeaderProgress()
            return
        end

        local color = self:GetDisplayPercentColor(percent)
        self.headerLabel:SetText(string.format("|c%s%d%%|r", color, percent))
        self.headerLabel.zoneId = nil
        self.headerLabel.progressZoneId = nil
        self.headerLabel.completedTotal = completedTotal
        self.headerLabel.availableTotal = availableTotal
        self.headerLabel.percent = percent
        self.headerLabel:SetHidden(false)
        if self.headerCategoryLabel then
            self.headerCategoryLabel:SetHidden(true)
            self.headerCategoryLabel:SetText("")
        end
        return
    end

    if mapType ~= MAPTYPE_ZONE then
        self:HideHeaderProgress()
        return
    end

    local zoneIndex = GetCurrentMapZoneIndex()
    if not zoneIndex or zoneIndex <= 0 then
        self:HideHeaderProgress()
        return
    end

    local zoneId = GetZoneId(zoneIndex)
    if not zoneId or zoneId <= 0 then
        self:HideHeaderProgress()
        return
    end

    local breakdown, completedTotal, availableTotal, percent, progressZoneId = self:GetResolvedCompletion(zoneId)
    if availableTotal <= 0 then
        self:HideHeaderProgress()
        return
    end

    local color = self:GetDisplayPercentColor(percent)
    self.headerLabel:SetText(string.format("|c%s%d%%|r", color, percent))
    self.headerLabel.zoneId = zoneId
    self.headerLabel.progressZoneId = progressZoneId
    self.headerLabel.completedTotal = completedTotal
    self.headerLabel.availableTotal = availableTotal
    self.headerLabel.percent = percent
    self.headerLabel:SetHidden(false)

    if self.headerCategoryLabel then
        if self.saved and self.saved.showCategoryPercentages and breakdown and #breakdown > 0 then
            -- Modern layout: "Nome 12/20  60%" per category, readable on the map
            local parts = {}
            for _, row in ipairs(breakdown) do
                local name = self:GetCompletionTypeName(row.completionType) or "?"
                local done = tonumber(row.completed) or 0
                local total = tonumber(row.total) or 0
                local pct = tonumber(row.percent) or 0
                local col = pct >= 100 and "5CFF8A" or (pct >= 50 and "FFB84D" or "FF6B6B")
                parts[#parts + 1] = string.format("|c%s%s|r %d/%d", col, name, done, total)
            end
            local line = table.concat(parts, "   ·   ")
            self.headerCategoryLabel:SetText(line)
            self.headerCategoryLabel:SetColor(0.92, 0.95, 1.00, 1)
            self.headerCategoryLabel:SetHidden(false)
        else
            self.headerCategoryLabel:SetHidden(true)
            self.headerCategoryLabel:SetText("")
        end
    end
end

function TPM:Refresh()
    self.refreshQueued = false

    -- Most TPM rendering belongs exclusively to the world map. The Statistics
    -- journal is the exception since 2.6.31: when opened standalone it must keep
    -- receiving live completion updates even while the map is closed.
    if not self:IsWorldMapVisible() then
        self:ReleaseOverlayLabels()
        self:HideAllianceTerritoryBorders()
        self:HideHeaderProgress()
        if self.questRewardControl then self:HideQuestRewards() end
        if self.statisticsWindow and not self.statisticsWindow:IsHidden() then
            self:RefreshStatisticsWindow()
        end
        return
    end

    self:ReleaseOverlayLabels()
    self:RefreshHeaderProgress()
    self:RefreshQuestRewards()
    self:RefreshQuickFilterBar()
    self:RefreshAllianceTerritoryBorders()

    if not self.pinRegistered then
        self:RegisterCustomPin()
    end

    -- Rebuild map percentages before the heavier statistics pass. This keeps the
    -- Tamriel markers visible even while the journal is open/refreshed.
    if self.pinRegistered and type(ZO_WorldMap_GetPinManager) == "function" then
        local pinManager = ZO_WorldMap_GetPinManager()
        local pinType = _G[PIN_TYPE_STRING]
        if pinManager and pinType then
            pinManager:SetCustomPinEnabled(pinType, self.saved and self.saved.enabled or false)
            pinManager:RefreshCustomPins(pinType)
        end
    end

    self:RefreshStatisticsWindow()
end

function TPM:QueueRefresh(delayMs)
    if self.refreshQueued then return end
    self.refreshQueued = true
    zo_callLater(function()
        TPM:Refresh()
    end, delayMs or 80)
end

function TPM:PrintHelp()
    d(string.format("|cE6C45C%s|r v%s - %s", DISPLAY_NAME, VERSION, AUTHOR))
    d(self:L("HELP_TOGGLE"))
    d(self:L("HELP_NAMES"))
    d(self:L("HELP_REFRESH"))
    d(self:L("HELP_LANG"))
    d(self:L("HELP_MODE"))
    d(self:L("HELP_COMPLETED"))
    d(self:L("HELP_FONT"))
    d(self:L("HELP_QUEST_FONT"))
    d(self:L("HELP_REWARDS"))
    d(self:L("HELP_STATS"))
    d(self:L("HELP_PAGE"))
    d(self:L("HELP_DEBUG_REPORT"))
    d("/nmc theme - trocar tema (cyber/neon/arctic/ember/matrix/dark/tpm/vanilla)")
end

function TPM:RefreshBindingStrings()
    local stringId = _G.SI_BINDING_NAME_TPM_TOGGLE_STATISTICS
    if stringId and type(SafeAddString) == "function" then
        SafeAddString(stringId, self:L("KEYBIND_TOGGLE_STATS"), 2)
    end
end

function TPM:SetLanguage(value, silent)
    -- Compatibility shim: TPM follows the ESO client language automatically.
    if value ~= nil and value ~= "auto" then return false end
    if self.saved then self.saved.language = "auto" end
    self:ResolveLanguage()
    self:RefreshBindingStrings()
    self:RefreshCustomSettingsControls()
    self:RefreshStatisticsWindow()
    if not silent then d(self:L("LANGUAGE_SET", self:L("LANGUAGE_NAME") or self.langCode)) end
    return true
end

function TPM:HandleSlashCommand(text)
    text = zo_strlower(zo_strtrim(text or ""))

    if text == "version" then
        if type(d) == "function" then d(DISPLAY_NAME .. " " .. VERSION) end
    elseif text == "toggle" then
        self.saved.enabled = not self.saved.enabled
        d(string.format("%s: %s", DISPLAY_NAME, self.saved.enabled and self:L("ON") or self:L("OFF")))
        self:QueueRefresh(10)
    elseif text == "names" then
        self.saved.showZoneNames = not self.saved.showZoneNames
        d(string.format("%s %s: %s", DISPLAY_NAME, self:L("ZONE_NAMES"), self.saved.showZoneNames and self:L("ON") or self:L("OFF")))
        self:QueueRefresh(10)
    elseif text == "completed" then
        local hide = (self.saved.hundredDisplayMode or "percent") ~= "hidden"
        self:SetHundredDisplayMode(hide and "hidden" or "percent")
        d(string.format("%s: %s", self:L("HIDE_COMPLETED"), hide and self:L("ON") or self:L("OFF")))
    elseif text == "rewards" then
        self.saved.showQuestRewards = not self.saved.showQuestRewards
        self:UpdateFocusedRewardPanelPolling()
        if not self.saved.showQuestRewards then self:HideQuestRewards() end
        d(string.format("%s: %s", self:L("QUEST_REWARDS"), self.saved.showQuestRewards and self:L("ON") or self:L("OFF")))
        self:QueueRefresh(10)
    elseif text == "skydebug" then
        self:RefreshSkyshardGoalWidget()
        self:PrintSkyshardGoalDebug()
    elseif text == "rewarddebug" then
        local questIndex = self:GetFocusedQuestIndex()
        local lines = questIndex and self:GetQuestRewardLines(questIndex) or {}
        d(string.format("TPM rewarddebug: quest=%s rewards=%d window=%s",
            tostring(questIndex or "nil"), #(lines or {}), tostring(self.questRewardControl ~= nil)))
        self:RefreshQuestRewards()
    elseif text == "refresh" then
        self:QueueRefresh(10)
    elseif text == "stats" or text == "statistics" then
        self:ToggleStatisticsFromKeybind()
    elseif text == "debugreport" then
        d(self:BuildDebugReport())
    elseif text == "checkpoint" then
        self:CheckpointHistory("manual", true)
        d(self:L("HISTORY_CHECKPOINT_SAVED"))
    elseif text == "theme" or text == "tema" then
        self:CycleStatisticsTheme()
    else
        local themeName = string.match(text, "^theme%s+(%S+)$") or string.match(text, "^tema%s+(%S+)$")
        if themeName and self.THEME_PRESETS and self.THEME_PRESETS[themeName] then
            self:SetStatisticsThemeDesign(themeName)
            d("|c5EC8F0Naga Mapa Completo|r tema: " .. self.THEME_PRESETS[themeName].label)
            return
        end
        local page = string.match(text, "^page%s+(%S+)$")
        if page and self:IsValidStatisticsPage(page) then
            self.saved.statisticsPage = page
            if self:ShowStatisticsWindow() then self:SetStatisticsPage(page) end
            return
        end
        local mode = string.match(text, "^mode%s+(%S+)$")
        if mode == "objectives" or mode == "categories" then
            self:SetCalculationMode(mode)
            d(self:L("CALCULATION_MODE_SET", mode == "categories" and self:L("MODE_CATEGORIES") or self:L("MODE_OBJECTIVES")))
            return
        end
        local fontStyle = string.match(text, "^font%s+(%S+)$")
        if fontStyle and self:SetFontStyle(fontStyle) then
            d(self:L("FONT_STYLE_SET", self:GetFontStyleName(fontStyle)))
            return
        end
        local questFontStyle = string.match(text, "^questfont%s+(%S+)$")
        if questFontStyle and self:SetQuestFontStyle(questFontStyle) then
            d(self:L("QUEST_FONT_STYLE_SET", self:GetFontStyleName(questFontStyle)))
            return
        end
        local lang = string.match(text, "^lang%s*(%S*)$")
        if lang ~= nil and (lang == "" or lang == "auto") then
            self:SetLanguage("auto")
            return
        end
        self:PrintHelp()
    end
end


function TPM:RefreshLAMSettingsLocalization()
    local panel = self.settingsPanel
    local controls = panel and panel.controlsToRefresh
    if type(controls) ~= "table" then return end

    local util = LibAddonMenu2 and LibAddonMenu2.util
    local function Resolve(value)
        if util and util.GetStringFromValue then
            return util.GetStringFromValue(value)
        end
        if type(value) == "function" then return value() end
        if type(value) == "number" and type(GetString) == "function" then
            return GetString(value)
        end
        return value
    end

    for _, control in ipairs(controls) do
        local data = control and control.data
        if data then
            local name = data.name ~= nil and Resolve(data.name) or nil
            if name ~= nil then
                if control.label and control.label.SetText then control.label:SetText(name) end
                if control.header and control.header.SetText then control.header:SetText(name) end
                if control.button and control.button.SetText then control.button:SetText(name) end
            end
            if control.desc and data.text ~= nil and control.desc.SetText then
                control.desc:SetText(Resolve(data.text) or "")
            end
            if control.title and data.title ~= nil and control.title.SetText then
                control.title:SetText(Resolve(data.title) or "")
            end
            if data.tooltip ~= nil then
                local tooltipText = Resolve(data.tooltip) or ""
                data.tooltipText = tooltipText
                if control.button and type(control.button.data) == "table" then
                    control.button.data.tooltipText = tooltipText
                end
            end
            if control.checkbox then
                control.checkedText = self:L("ON")
                control.uncheckedText = self:L("OFF")
                if control.UpdateValue then control:UpdateValue() end
            end
            if control.UpdateWarning then control:UpdateWarning() end
        end
    end
end

function TPM:RefreshCustomSettingsControls()
    if self.settingsControls.language then
        self:UpdateLanguageCustomControl(self.settingsControls.language)
    end
    if self.settingsControls.calculation then
        self:UpdateCalculationCustomControl(self.settingsControls.calculation)
    end
    if self.settingsControls.fontStyle then
        self:UpdateFontStyleCustomControl(self.settingsControls.fontStyle)
    end
    if self.settingsControls.questFontStyle then
        self:UpdateQuestFontStyleCustomControl(self.settingsControls.questFontStyle)
    end
    if self.settingsControls.percentColor then
        self:UpdatePercentColorCustomControl(self.settingsControls.percentColor)
    end
    if self.settingsControls.percentSize then
        self:UpdatePercentSizeCustomControl(self.settingsControls.percentSize)
    end
    if self.settingsControls.hundredDisplay then
        self:UpdateHundredDisplayCustomControl(self.settingsControls.hundredDisplay)
    end
    self:RefreshLAMSettingsLocalization()
end

function TPM:SetupLanguageCustomControl(control)
    if not control then return end
    control:SetHeight(58)
    self.settingsControls.language = control
    if not control.TPMLanguageTitle then
        local title = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        title:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
        title:SetFont("ZoFontWinH4")
        title:SetColor(1,1,1,1)
        control.TPMLanguageTitle = title
        local tip = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        tip:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 2)
        tip:SetFont("ZoFontGameSmall")
        tip:SetColor(.75,.75,.75,1)
        control.TPMLanguageTooltip = tip
        local current = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        current:SetDimensions(220,26)
        current:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, 4)
        current:SetFont("$(BOLD_FONT)|15")
        current:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        current:SetColor(.90,.77,.36,1)
        control.TPMLanguageCurrent = current
    end
    self:UpdateLanguageCustomControl(control)
end

function TPM:UpdateLanguageCustomControl(control)
    if not control then return end
    if control.TPMLanguageTitle then control.TPMLanguageTitle:SetText(self:L("SETTINGS_LANGUAGE")) end
    if control.TPMLanguageTooltip then control.TPMLanguageTooltip:SetText(self:L("SETTINGS_LANGUAGE_TT")) end
    if control.TPMLanguageCurrent then
        local name = self:L("LANGUAGE_NAME") or string.upper(self.langCode or "en")
        control.TPMLanguageCurrent:SetText(name .. " (ESO)")
    end
end

function TPM:SetCalculationMode(value)
    if value ~= "objectives" and value ~= "categories" then return false end
    self.saved.calculationMode = value
    self:InvalidateStatisticsData(false)
    if self.settingsControls.calculation then
        self:UpdateCalculationCustomControl(self.settingsControls.calculation)
    end
    self:QueueRefresh(10)
    return true
end

function TPM:SetupCalculationCustomControl(control)
    if not control then return end
    control:SetHeight(72)

    if not control.TPMCalculationTitle then
        local title = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        title:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
        title:SetFont("ZoFontWinH4")
        title:SetColor(1, 1, 1, 1)
        control.TPMCalculationTitle = title

        local tip = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        tip:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 2)
        tip:SetFont("ZoFontGameSmall")
        tip:SetColor(0.75, 0.75, 0.75, 1)
        control.TPMCalculationTooltip = tip

        local function CreateModeButton(key, x)
            local button = WINDOW_MANAGER:CreateControlFromVirtual(nil, control, "ZO_DefaultButton")
            button:SetDimensions(220, 28)
            button:SetAnchor(TOPLEFT, control, TOPLEFT, x, 40)
            button.modeKey = key
            button:SetHandler("OnClicked", function(btn)
                TPM:SetCalculationMode(btn.modeKey)
            end)
            return button
        end

        control.TPMObjectivesButton = CreateModeButton("objectives", 0)
        control.TPMCategoriesButton = CreateModeButton("categories", 230)
    end

    self:UpdateCalculationCustomControl(control)
end

function TPM:UpdateCalculationCustomControl(control)
    if not control then return end
    if control.TPMCalculationTitle then control.TPMCalculationTitle:SetText(self:L("SETTINGS_CALCULATION")) end
    if control.TPMCalculationTooltip then control.TPMCalculationTooltip:SetText(self:L("SETTINGS_CALCULATION_TT")) end

    local current = self.saved and self.saved.calculationMode or "objectives"
    local labels =
    {
        objectives = self:L("MODE_OBJECTIVES"),
        categories = self:L("MODE_CATEGORIES"),
    }
    local buttons = { control.TPMObjectivesButton, control.TPMCategoriesButton }
    for _, button in ipairs(buttons) do
        if button then
            local text = labels[button.modeKey] or button.modeKey
            local selected = button.modeKey == current
            button:SetText(selected and ("|cE6C45C" .. text .. "|r") or text)
        end
    end
end

function TPM:SetFontStyle(value)
    value = self:NormalizeFontStyle(value)
    if not value then
        return false
    end

    self.saved.fontStyle = value
    self:ApplyProgressFonts()
    if self.settingsControls.fontStyle then
        self:UpdateFontStyleCustomControl(self.settingsControls.fontStyle)
    end
    self:QueueRefresh(10)
    return true
end

function TPM:SetQuestFontStyle(value)
    value = self:NormalizeFontStyle(value)
    if not value then
        return false
    end

    self.saved.questFontStyle = value
    self:ApplyQuestRewardFonts()
    if self.settingsControls.questFontStyle then
        self:UpdateQuestFontStyleCustomControl(self.settingsControls.questFontStyle)
    end
    self:QueueRefresh(10)
    return true
end

function TPM:SetupFontSelectorCustomControl(control, isQuestFont)
    if not control then return end
    control:SetHeight(96)

    if not control.TPMFontSelectorTitle then
        local title = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        title:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
        title:SetFont("ZoFontWinH4")
        title:SetColor(1, 1, 1, 1)
        control.TPMFontSelectorTitle = title

        local tip = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        tip:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 2)
        tip:SetFont("ZoFontGameSmall")
        tip:SetColor(0.75, 0.75, 0.75, 1)
        control.TPMFontSelectorTooltip = tip

        local prev = WINDOW_MANAGER:CreateControlFromVirtual(nil, control, "ZO_DefaultButton")
        prev:SetDimensions(46, 32)
        prev:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 50)
        prev:SetText("<")
        control.TPMFontPrevButton = prev

        local nextButton = WINDOW_MANAGER:CreateControlFromVirtual(nil, control, "ZO_DefaultButton")
        nextButton:SetDimensions(46, 32)
        nextButton:SetAnchor(TOPLEFT, control, TOPLEFT, 414, 50)
        nextButton:SetText(">")
        control.TPMFontNextButton = nextButton

        local preview = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        preview:SetDimensions(350, 38)
        preview:SetAnchor(TOPLEFT, control, TOPLEFT, 55, 47)
        preview:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        preview:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        preview:SetColor(0.90, 0.77, 0.36, 1)
        control.TPMFontPreview = preview

        prev:SetHandler("OnClicked", function()
            local current = isQuestFont and (TPM.saved.questFontStyle or "classic") or (TPM.saved.fontStyle or "classic")
            local value = TPM:GetAdjacentFontStyle(current, -1)
            if isQuestFont then TPM:SetQuestFontStyle(value) else TPM:SetFontStyle(value) end
        end)
        nextButton:SetHandler("OnClicked", function()
            local current = isQuestFont and (TPM.saved.questFontStyle or "classic") or (TPM.saved.fontStyle or "classic")
            local value = TPM:GetAdjacentFontStyle(current, 1)
            if isQuestFont then TPM:SetQuestFontStyle(value) else TPM:SetFontStyle(value) end
        end)
    end

    control.TPMFontSelectorIsQuest = isQuestFont
    if isQuestFont then
        self:UpdateQuestFontStyleCustomControl(control)
    else
        self:UpdateFontStyleCustomControl(control)
    end
end

function TPM:SetupFontStyleCustomControl(control)
    self:SetupFontSelectorCustomControl(control, false)
end

function TPM:UpdateFontStyleCustomControl(control)
    if not control then return end
    local style = self.saved and self.saved.fontStyle or "classic"
    local profile = self:GetFontProfile(style)
    if control.TPMFontSelectorTitle then control.TPMFontSelectorTitle:SetText(self:L("SETTINGS_FONT")) end
    if control.TPMFontSelectorTooltip then control.TPMFontSelectorTooltip:SetText(self:L("SETTINGS_FONT_TT")) end
    if control.TPMFontPreview then
        control.TPMFontPreview:SetFont(profile.overlay)
        control.TPMFontPreview:SetText(string.format("75%%  -  %s", self:GetFontStyleName(style)))
    end
end

function TPM:SetupQuestFontStyleCustomControl(control)
    self:SetupFontSelectorCustomControl(control, true)
end

function TPM:UpdateQuestFontStyleCustomControl(control)
    if not control then return end
    local style = self.saved and self.saved.questFontStyle or "classic"
    local profile = self:GetFontProfile(style)
    if control.TPMFontSelectorTitle then control.TPMFontSelectorTitle:SetText(self:L("SETTINGS_QUEST_FONT")) end
    if control.TPMFontSelectorTooltip then control.TPMFontSelectorTooltip:SetText(self:L("SETTINGS_QUEST_FONT_TT")) end
    if control.TPMFontPreview then
        control.TPMFontPreview:SetFont(profile.questTitle)
        control.TPMFontPreview:SetText(string.format("%s  -  %s", self:L("QUEST_REWARDS"), self:GetFontStyleName(style)))
    end
end

function TPM:SetPercentColorMode(value)
    if value ~= "progress" and value ~= "black" and value ~= "brown" and value ~= "gold" and value ~= "custom" then
        return false
    end
    self.saved.percentColorMode = value
    self.saved.blackPercentText = value == "black" -- keep old SavedVariables meaningful
    if self.settingsControls.percentColor then
        self:UpdatePercentColorCustomControl(self.settingsControls.percentColor)
    end
    self:ReleaseOverlayLabels()
    self:InvalidateStatisticsData(false)
    self:QueueRefresh(10)
    return true
end

function TPM:OpenCustomPercentColorPicker()
    local savedColor = self.saved.customPercentColor or DEFAULTS.customPercentColor
    local r = Clamp(tonumber(savedColor.r) or DEFAULTS.customPercentColor.r, 0, 1)
    local g = Clamp(tonumber(savedColor.g) or DEFAULTS.customPercentColor.g, 0, 1)
    local b = Clamp(tonumber(savedColor.b) or DEFAULTS.customPercentColor.b, 0, 1)

    local picker = nil
    if type(IsInGamepadPreferredMode) == "function" and IsInGamepadPreferredMode() and COLOR_PICKER_GAMEPAD then
        picker = COLOR_PICKER_GAMEPAD
    else
        picker = COLOR_PICKER
    end

    if not picker or not picker.Show then
        self:SetPercentColorMode("custom")
        return false
    end

    picker:Show(function(newR, newG, newB)
        TPM.saved.customPercentColor =
        {
            r = Clamp(newR or r, 0, 1),
            g = Clamp(newG or g, 0, 1),
            b = Clamp(newB or b, 0, 1),
        }
        TPM:SetPercentColorMode("custom")
        if self.settingsControls.percentColor then
            TPM:UpdatePercentColorCustomControl(TPM.settingsControls.percentColor)
        end
    end, r, g, b)
    return true
end

function TPM:SetupPercentColorCustomControl(control)
    if not control then return end
    control:SetHeight(72)

    if not control.TPMColorTitle then
        local title = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        title:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
        title:SetFont("ZoFontWinH4")
        title:SetColor(1, 1, 1, 1)
        control.TPMColorTitle = title

        local tip = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        tip:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 2)
        tip:SetFont("ZoFontGameSmall")
        tip:SetColor(0.75, 0.75, 0.75, 1)
        control.TPMColorTooltip = tip

        local function CreateColorButton(key, x)
            local button = WINDOW_MANAGER:CreateControlFromVirtual(nil, control, "ZO_DefaultButton")
            button:SetDimensions(92, 28)
            button:SetAnchor(TOPLEFT, control, TOPLEFT, x, 40)
            button.colorKey = key
            button:SetHandler("OnClicked", function(btn)
                if btn.colorKey == "custom" then
                    TPM:OpenCustomPercentColorPicker()
                else
                    TPM:SetPercentColorMode(btn.colorKey)
                end
                TPM:UpdatePercentColorCustomControl(control)
            end)
            return button
        end

        control.TPMProgressColorButton = CreateColorButton("progress", 0)
        control.TPMBlackColorButton = CreateColorButton("black", 98)
        control.TPMBrownColorButton = CreateColorButton("brown", 196)
        control.TPMGoldColorButton = CreateColorButton("gold", 294)
        control.TPMCustomColorButton = CreateColorButton("custom", 392)
    end

    self:UpdatePercentColorCustomControl(control)
end

function TPM:UpdatePercentColorCustomControl(control)
    if not control then return end
    if control.TPMColorTitle then control.TPMColorTitle:SetText(self:L("SETTINGS_PERCENT_COLOR")) end
    if control.TPMColorTooltip then control.TPMColorTooltip:SetText(self:L("SETTINGS_PERCENT_COLOR_TT")) end

    local current = self.saved and self.saved.percentColorMode or "black"
    local labels = {
        progress = self:L("COLOR_PROGRESS"),
        black = self:L("COLOR_BLACK"),
        brown = self:L("COLOR_BROWN"),
        gold = self:L("COLOR_GOLD"),
        custom = self:L("COLOR_CUSTOM"),
    }
    local buttons = {
        control.TPMProgressColorButton,
        control.TPMBlackColorButton,
        control.TPMBrownColorButton,
        control.TPMGoldColorButton,
        control.TPMCustomColorButton,
    }
    for _, button in ipairs(buttons) do
        if button then
            local text = labels[button.colorKey] or button.colorKey
            local selected = button.colorKey == current
            if button.colorKey == "custom" then
                local color = self.saved and self.saved.customPercentColor or DEFAULTS.customPercentColor
                local colorHex = RGBToHex(color.r, color.g, color.b)
                text = "|c" .. colorHex .. text .. "|r"
                if selected then
                    text = "|cE6C45C[|r" .. text .. "|cE6C45C]|r"
                end
            elseif selected then
                text = "|c5EC8F0" .. text .. "|r"
            end
            button:SetText(text)
        end
    end
end

function TPM:SetPercentScale(kind, value)
    value = Clamp(Round(tonumber(value) or 100), 70, 160)
    if kind == "header" then
        self.saved.headerPercentScale = value
    else
        self.saved.mapPercentScale = value
    end
    self:ApplyProgressFonts()
    if self.settingsControls.percentSize then
        self:UpdatePercentSizeCustomControl(self.settingsControls.percentSize)
    end
    self:QueueRefresh(10)
end

function TPM:SetupPercentSizeCustomControl(control)
    if not control then return end
    control:SetHeight(102)

    if not control.TPMPercentSizeTitle then
        local title = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        title:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
        title:SetFont("ZoFontWinH4")
        title:SetColor(1, 1, 1, 1)
        control.TPMPercentSizeTitle = title

        local tip = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        tip:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 2)
        tip:SetFont("ZoFontGameSmall")
        tip:SetColor(0.75, 0.75, 0.75, 1)
        control.TPMPercentSizeTooltip = tip

        local function CreateRow(prefix, y, kind)
            local label = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
            label:SetDimensions(285, 28)
            label:SetAnchor(TOPLEFT, control, TOPLEFT, 0, y)
            label:SetFont("ZoFontGame")
            label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
            control[prefix .. "Label"] = label

            local minus = WINDOW_MANAGER:CreateControlFromVirtual(nil, control, "ZO_DefaultButton")
            minus:SetDimensions(42, 28)
            minus:SetAnchor(TOPLEFT, control, TOPLEFT, 300, y)
            minus:SetText("-")
            minus:SetHandler("OnClicked", function()
                local current = kind == "header" and TPM.saved.headerPercentScale or TPM.saved.mapPercentScale
                TPM:SetPercentScale(kind, (current or 100) - 5)
            end)

            local plus = WINDOW_MANAGER:CreateControlFromVirtual(nil, control, "ZO_DefaultButton")
            plus:SetDimensions(42, 28)
            plus:SetAnchor(TOPLEFT, control, TOPLEFT, 350, y)
            plus:SetText("+")
            plus:SetHandler("OnClicked", function()
                local current = kind == "header" and TPM.saved.headerPercentScale or TPM.saved.mapPercentScale
                TPM:SetPercentScale(kind, (current or 100) + 5)
            end)
        end

        CreateRow("TPMMapPercentSize", 42, "map")
        CreateRow("TPMHeaderPercentSize", 72, "header")
    end

    self:UpdatePercentSizeCustomControl(control)
end

function TPM:UpdatePercentSizeCustomControl(control)
    if not control then return end
    if control.TPMPercentSizeTitle then control.TPMPercentSizeTitle:SetText(self:L("SETTINGS_PERCENT_SIZE")) end
    if control.TPMPercentSizeTooltip then control.TPMPercentSizeTooltip:SetText(self:L("SETTINGS_PERCENT_SIZE_TT")) end
    if control.TPMMapPercentSizeLabel then
        control.TPMMapPercentSizeLabel:SetText(string.format("%s: %d%%", self:L("SETTINGS_MAP_PERCENT_SIZE"), self.saved.mapPercentScale or 100))
    end
    if control.TPMHeaderPercentSizeLabel then
        control.TPMHeaderPercentSizeLabel:SetText(string.format("%s: %d%%", self:L("SETTINGS_HEADER_PERCENT_SIZE"), self.saved.headerPercentScale or 100))
    end
end

function TPM:SetHundredDisplayMode(value)
    if value ~= "percent" and value ~= "check" and value ~= "hidden" then return false end
    self.saved.hundredDisplayMode = value
    self.saved.hideCompletedZones = value == "hidden" -- legacy SavedVariable compatibility
    if self.settingsControls.hundredDisplay then
        self:UpdateHundredDisplayCustomControl(self.settingsControls.hundredDisplay)
    end
    self:QueueRefresh(10)
    return true
end

function TPM:SetupHundredDisplayCustomControl(control)
    if not control then return end
    control:SetHeight(72)

    if not control.TPMHundredTitle then
        local title = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        title:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
        title:SetFont("ZoFontWinH4")
        title:SetColor(1, 1, 1, 1)
        control.TPMHundredTitle = title

        local tip = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
        tip:SetAnchor(TOPLEFT, title, BOTTOMLEFT, 0, 2)
        tip:SetFont("ZoFontGameSmall")
        tip:SetColor(0.75, 0.75, 0.75, 1)
        control.TPMHundredTooltip = tip

        local function CreateModeButton(key, x)
            local button = WINDOW_MANAGER:CreateControlFromVirtual(nil, control, "ZO_DefaultButton")
            button:SetDimensions(145, 28)
            button:SetAnchor(TOPLEFT, control, TOPLEFT, x, 40)
            button.modeKey = key
            button:SetHandler("OnClicked", function(btn)
                TPM:SetHundredDisplayMode(btn.modeKey)
            end)
            return button
        end

        control.TPMHundredPercentButton = CreateModeButton("percent", 0)
        control.TPMHundredCheckButton = CreateModeButton("check", 154)
        control.TPMHundredHiddenButton = CreateModeButton("hidden", 308)
    end

    self:UpdateHundredDisplayCustomControl(control)
end

function TPM:UpdateHundredDisplayCustomControl(control)
    if not control then return end
    if control.TPMHundredTitle then control.TPMHundredTitle:SetText(self:L("SETTINGS_HUNDRED_DISPLAY")) end
    if control.TPMHundredTooltip then control.TPMHundredTooltip:SetText(self:L("SETTINGS_HUNDRED_DISPLAY_TT")) end

    local current = self.saved and self.saved.hundredDisplayMode or "percent"
    local labels =
    {
        percent = self:L("HUNDRED_PERCENT"),
        check = self:L("HUNDRED_CHECK"),
        hidden = self:L("HUNDRED_HIDDEN"),
    }
    local buttons = { control.TPMHundredPercentButton, control.TPMHundredCheckButton, control.TPMHundredHiddenButton }
    for _, button in ipairs(buttons) do
        if button then
            local text = labels[button.modeKey] or button.modeKey
            local selected = button.modeKey == current
            button:SetText(selected and ("|cE6C45C" .. text .. "|r") or text)
        end
    end
end


function TPM:ResetCurrentCharacterCombatStats()
    -- 3.4.9: lifetime combat counters are intentionally permanent per character.
    -- Keep this method as a compatibility no-op for older settings/control references.
    return false
end

function TPM:ResetCurrentCharacterEconomyStats()
    if not self.saved then return end
    local key = self:GetCurrentCharacterStatsKey()
    if type(self.saved.economyStatsByCharacter) ~= "table" then self.saved.economyStatsByCharacter = {} end
    self.saved.economyStatsByCharacter[key] = { trackingVersion = VERSION, currencies = {}, legacyMigrationCompleted274 = true }
    if type(self.saved.economyZoneStatsByCharacter) ~= "table" then self.saved.economyZoneStatsByCharacter = {} end
    self.saved.economyZoneStatsByCharacter[key] = {}
    self.economyCurrencyPrevious = nil
    self:RefreshEconomyStatisticsPage()
end

function TPM:ResetCurrentCharacterHistory()
    if not self.saved then return end
    local key = self:GetCurrentCharacterStatsKey()
    self.saved.historyByCharacter[key] = nil
    self.saved.milestoneStateByCharacter[key] = nil
    self:StartOrResumeHistorySession()
    self:RefreshHistoryStatisticsPage()
end

function TPM:RegisterSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelDisplayName = string.format("%s v%s", DISPLAY_NAME, VERSION)

    local panelData =
    {
        type = "panel",
        name = panelDisplayName,
        displayName = "|cE6C45C" .. panelDisplayName .. "|r",
        author = AUTHOR,
        version = VERSION,
        registerForRefresh = true,
        registerForDefaults = false,
    }

    self.settingsPanel = LAM:RegisterAddonPanel(ADDON_NAME .. "Options", panelData)

    local optionData =
    {
        { type = "header", name = function() return TPM:L("SETTINGS_SECTION_LANGUAGE") end, width = "full" },
        {
            type = "custom",
            refreshFunc = function(control) TPM.settingsControls.language=control; TPM:SetupLanguageCustomControl(control) end,
            width = "full",
        },
        { type = "description", text = function() return TPM:L("SETTINGS_RELOAD_NOTE") end, width = "full" },

        { type = "header", name = function() return TPM:L("SETTINGS_SECTION_MAP") end, width = "full" },
        {
            type = "checkbox",
            name = function() return TPM:L("SETTINGS_ENABLED") end,
            tooltip = function() return TPM:L("SETTINGS_ENABLED_TT") end,
            getFunc = function() return TPM.saved.enabled end,
            setFunc = function(value) TPM.saved.enabled = value; TPM:QueueRefresh(10) end,
            default = DEFAULTS.enabled,
            width = "full",
        },
        {
            type = "checkbox",
            name = function() return TPM:L("SETTINGS_QUICK_FILTERS") end,
            tooltip = function() return TPM:L("SETTINGS_QUICK_FILTERS_TT") end,
            getFunc = function() return TPM.saved.showQuickFilters end,
            setFunc = function(value) TPM.saved.showQuickFilters = value; TPM:RefreshQuickFilterBar() end,
            default = DEFAULTS.showQuickFilters,
            width = "full",
        },

        {
            type = "dropdown",
            name = function() return "Tema da interface (Estatísticas)" end,
            tooltip = function() return "Temas modernos e futuristas para a janela de estatísticas. Use também /tpm theme" end,
            choices = { "Dark Modern", "Cyber", "Neon", "Arctic", "Ember", "Matrix", "Classic Gold", "Transparent" },
            choicesValues = { "dark", "cyber", "neon", "arctic", "ember", "matrix", "tpm", "vanilla" },
            getFunc = function() return TPM.saved.statisticsThemeDesign or "dark" end,
            setFunc = function(value) TPM:SetStatisticsThemeDesign(value) end,
            default = "dark",
            width = "full",
        },
        {
            type = "checkbox",
            name = function() return TPM:L("SETTINGS_NAMES") end,
            tooltip = function() return TPM:L("SETTINGS_NAMES_TT") end,
            getFunc = function() return TPM.saved.showZoneNames end,
            setFunc = function(value) TPM.saved.showZoneNames = value; TPM:QueueRefresh(10) end,
            default = DEFAULTS.showZoneNames,
            width = "full",
        },
        {
            type = "checkbox",
            name = function() return TPM:L("SETTINGS_LOCATION_COLORS") end,
            tooltip = function() return TPM:L("SETTINGS_LOCATION_COLORS_TT") end,
            getFunc = function() return TPM.saved.enableLocationColors ~= false end,
            setFunc = function(value)
                TPM.saved.enableLocationColors = value and true or false
                TPM:RefreshLocationsColors()
            end,
            default = DEFAULTS.enableLocationColors,
            width = "full",
        },
        {
            type = "checkbox",
            name = function() return TPM:L("SETTINGS_LOCATION_TOOLTIPS") end,
            tooltip = function() return TPM:L("SETTINGS_LOCATION_TOOLTIPS_TT") end,
            getFunc = function() return TPM.saved.enableLocationTooltips ~= false end,
            setFunc = function(value)
                TPM.saved.enableLocationTooltips = value and true or false
            end,
            default = DEFAULTS.enableLocationTooltips,
            width = "full",
        },

        {
            type = "checkbox",
            name = function() return TPM:L("SETTINGS_ALLIANCE_TERRITORY") end,
            tooltip = function() return TPM:L("SETTINGS_ALLIANCE_TERRITORY_TT") end,
            getFunc = function() return TPM.saved.showAllianceTerritoryColors end,
            setFunc = function(value)
                TPM.saved.showAllianceTerritoryColors = value and true or false
                TPM:QueueRefresh(10)
            end,
            default = DEFAULTS.showAllianceTerritoryColors,
            width = "full",
        },
        {
            type = "checkbox",
            name = function() return TPM:L("SETTINGS_ALLIANCE_NEUTRAL_WHITE") end,
            tooltip = function() return TPM:L("SETTINGS_ALLIANCE_NEUTRAL_WHITE_TT") end,
            getFunc = function() return TPM.saved.allianceNeutralWhite end,
            setFunc = function(value)
                TPM.saved.allianceNeutralWhite = value and true or false
                TPM:QueueRefresh(10)
            end,
            default = DEFAULTS.allianceNeutralWhite,
            disabled = function() return not TPM.saved.showAllianceTerritoryColors end,
            width = "full",
        },
        {
            type = "checkbox",
            name = function() return TPM:L("SETTINGS_TOOLTIP") end,
            tooltip = function() return TPM:L("SETTINGS_TOOLTIP_TT") end,
            getFunc = function() return TPM.saved.showTooltip end,
            setFunc = function(value) TPM.saved.showTooltip = value end,
            default = DEFAULTS.showTooltip,
            width = "full",
        },
        {
            type = "checkbox",
            name = function() return TPM:L("SETTINGS_HEADER") end,
            tooltip = function() return TPM:L("SETTINGS_HEADER_TT") end,
            getFunc = function() return TPM.saved.showHeader end,
            setFunc = function(value) TPM.saved.showHeader = value; TPM:QueueRefresh(10) end,
            default = DEFAULTS.showHeader,
            width = "full",
        },

        { type = "header", name = function() return TPM:L("SETTINGS_SECTION_DISPLAY") end, width = "full" },
        {
            type = "custom",
            refreshFunc = function(control) TPM.settingsControls.fontStyle=control; TPM:SetupFontStyleCustomControl(control) end,
            width = "full",
        },
        {
            type = "custom",
            refreshFunc = function(control) TPM.settingsControls.percentSize=control; TPM:SetupPercentSizeCustomControl(control) end,
            width = "full",
        },
        {
            type = "custom",
            refreshFunc = function(control) TPM.settingsControls.percentColor=control; TPM:SetupPercentColorCustomControl(control) end,
            width = "full",
        },
        {
            type = "custom",
            refreshFunc = function(control) TPM.settingsControls.hundredDisplay=control; TPM:SetupHundredDisplayCustomControl(control) end,
            width = "full",
        },
        {
            type = "slider",
            name = function() return TPM:L("SETTINGS_STATISTICS_SCALE") end,
            tooltip = function() return TPM:L("SETTINGS_STATISTICS_SCALE_TT") end,
            min = 80, max = 120, step = 5,
            getFunc = function() return TPM.saved.statisticsWindowScale or 100 end,
            setFunc = function(value)
                TPM.saved.statisticsWindowScale = Clamp(Round(value), 80, 120)
                if TPM.statisticsWindow then
                    TPM.statisticsWindow:SetScale(TPM.saved.statisticsWindowScale / 100)
                    TPM:RefreshAlliancePlannerMapView(true)
                    TPM:ClampStatisticsWindowToScreen()
                end
            end,
            default = DEFAULTS.statisticsWindowScale,
            width = "full",
        },
        {
            type = "button",
            name = function() return TPM:L("SETTINGS_STATISTICS_RESET") end,
            tooltip = function() return TPM:L("SETTINGS_STATISTICS_RESET_TT") end,
            func = function() TPM:ResetStatisticsWindowPosition() end,
            width = "half",
        },
        {
            type = "description",
            text = function() return TPM:L("SETTINGS_STATISTICS_KEYBIND_INFO") end,
            width = "full",
        },

        { type = "header", name = function() return TPM:L("SETTINGS_SECTION_PROGRESS") end, width = "full" },
        {
            type = "custom",
            refreshFunc = function(control) TPM.settingsControls.calculation=control; TPM:SetupCalculationCustomControl(control) end,
            width = "full",
        },
        {
            type = "dropdown",
            name = function() return TPM:L("SETTINGS_SKYSHARD_POSITION") end,
            tooltip = function() return TPM:L("SETTINGS_SKYSHARD_POSITION_TT") end,
            choices = { "1", "2" },
            choicesValues = { 1, 2 },
            getFunc = function() return tonumber(TPM.saved.skyshardGoalPosition) == 2 and 2 or 1 end,
            setFunc = function(value) TPM:SetSkyshardGoalPosition(value) end,
            default = DEFAULTS.skyshardGoalPosition,
            width = "full",
        },

        { type = "header", name = function() return TPM:L("SETTINGS_SECTION_QUEST") end, width = "full" },
        {
            type = "custom",
            refreshFunc = function(control) TPM.settingsControls.questFontStyle=control; TPM:SetupQuestFontStyleCustomControl(control) end,
            width = "full",
        },
        {
            type = "checkbox",
            name = function() return TPM:L("SETTINGS_QUEST_REWARDS") end,
            tooltip = function() return TPM:L("SETTINGS_QUEST_REWARDS_TT") end,
            getFunc = function() return TPM.saved.showQuestRewards end,
            setFunc = function(value)
                TPM.saved.showQuestRewards = value
                TPM:UpdateFocusedRewardPanelPolling()
                if value then TPM:QueueRefresh(10) else TPM:HideQuestRewards() end
            end,
            default = DEFAULTS.showQuestRewards,
            width = "full",
        },
        {
            type = "checkbox",
            name = function() return TPM:L("SETTINGS_QUEST_REWARD_COLORS") end,
            tooltip = function() return TPM:L("SETTINGS_QUEST_REWARD_COLORS_TT") end,
            getFunc = function() return TPM.saved.colorVanillaQuestsByReward ~= false end,
            setFunc = function(value)
                TPM.saved.colorVanillaQuestsByReward = value
                TPM:RefreshVanillaQuestRewardColors()
            end,
            default = DEFAULTS.colorVanillaQuestsByReward,
            width = "full",
        },
        {
            type = "checkbox",
            name = function() return TPM:L("SETTINGS_QUEST_AUTO_SIZE") end,
            tooltip = function() return TPM:L("SETTINGS_QUEST_AUTO_SIZE_TT") end,
            getFunc = function() return TPM.saved.questRewardAutoSize end,
            setFunc = function(value) TPM.saved.questRewardAutoSize = value; TPM:QueueRefresh(10) end,
            default = DEFAULTS.questRewardAutoSize,
            width = "full",
        },
        {
            type = "checkbox",
            name = function() return TPM:L("SETTINGS_QUEST_LOCK") end,
            tooltip = function() return TPM:L("SETTINGS_QUEST_LOCK_TT") end,
            getFunc = function() return TPM.saved.questRewardLocked end,
            setFunc = function(value) TPM.saved.questRewardLocked = value; TPM:UpdateQuestRewardLockState() end,
            default = DEFAULTS.questRewardLocked,
            width = "full",
        },
        {
            type = "button",
            name = function() return TPM:L("SETTINGS_QUEST_RESET") end,
            tooltip = function() return TPM:L("SETTINGS_QUEST_RESET_TT") end,
            func = function() TPM:ResetQuestRewardWindow() end,
            width = "half",
        },

        { type = "header", name = function() return TPM:L("SETTINGS_SECTION_JOURNAL") end, width = "full" },
        {
            type = "checkbox",
            name = function() return TPM:L("SETTINGS_HISTORY_ENABLED") end,
            tooltip = function() return TPM:L("SETTINGS_HISTORY_ENABLED_TT") end,
            getFunc = function() return TPM.saved.historyEnabled ~= false end,
            setFunc = function(value)
                if value then
                    TPM.saved.historyEnabled = true
                    TPM:StartOrResumeHistorySession()
                else
                    -- Pause before disabling so time spent with history disabled
                    -- can never be added to a later session when it is re-enabled.
                    TPM:CheckpointHistoryOnDeactivated()
                    TPM.saved.historyEnabled = false
                end
            end,
            default = DEFAULTS.historyEnabled,
            width = "full",
        },
        {
            type = "checkbox",
            name = function() return TPM:L("SETTINGS_MILESTONES") end,
            tooltip = function() return TPM:L("SETTINGS_MILESTONES_TT") end,
            getFunc = function() return TPM.saved.showMilestones ~= false end,
            setFunc = function(value) TPM.saved.showMilestones = value end,
            default = DEFAULTS.showMilestones,
            width = "full",
        },
        {
            type = "button",
            name = function() return TPM:L("SETTINGS_RESET_ECONOMY") end,
            tooltip = function() return TPM:L("SETTINGS_RESET_ECONOMY_TT") end,
            func = function() TPM:ResetCurrentCharacterEconomyStats() end,
            width = "half",
        },
        {
            type = "button",
            name = function() return TPM:L("SETTINGS_RESET_HISTORY") end,
            tooltip = function() return TPM:L("SETTINGS_RESET_HISTORY_TT") end,
            func = function() TPM:ResetCurrentCharacterHistory() end,
            width = "half",
        },

        { type = "header", name = function() return TPM:L("SETTINGS_SECTION_ADVANCED") end, width = "full" },
        {
            type = "checkbox",
            name = function() return TPM:L("SETTINGS_DEBUG") end,
            tooltip = function() return TPM:L("SETTINGS_DEBUG_TT") end,
            getFunc = function() return TPM.saved.debugMode end,
            setFunc = function(value) TPM.saved.debugMode = value end,
            default = DEFAULTS.debugMode,
            width = "full",
        },

        { type = "description", text = function() return TPM:L("SETTINGS_CHANGELOG") end, width = "full" },
    }

    LAM:RegisterOptionControls(ADDON_NAME .. "Options", optionData)

    if not self.lamControlsCreatedCallbackRegistered then
        self.lamControlsCreatedCallbackRegistered = true
        CALLBACK_MANAGER:RegisterCallback("LAM-PanelControlsCreated", function(panel)
            if panel ~= TPM.settingsPanel then return end

            -- Build the direct ESO button controls on first panel creation.
            if self.settingsControls.language then
                TPM:SetupLanguageCustomControl(TPM.settingsControls.language)
            end
            if self.settingsControls.calculation then
                TPM:SetupCalculationCustomControl(TPM.settingsControls.calculation)
            end
            if self.settingsControls.fontStyle then
                TPM:SetupFontStyleCustomControl(TPM.settingsControls.fontStyle)
            end
            if self.settingsControls.questFontStyle then
                TPM:SetupQuestFontStyleCustomControl(TPM.settingsControls.questFontStyle)
            end
            if self.settingsControls.percentColor then
                TPM:SetupPercentColorCustomControl(TPM.settingsControls.percentColor)
            end
            if self.settingsControls.percentSize then
                TPM:SetupPercentSizeCustomControl(TPM.settingsControls.percentSize)
            end
            if self.settingsControls.hundredDisplay then
                TPM:SetupHundredDisplayCustomControl(TPM.settingsControls.hundredDisplay)
            end
            TPM:RefreshLAMSettingsLocalization()
        end)
    end
end


function TPM:QueueProgressHistoryCheckpoint()
    if self.progressHistoryCheckpointQueued then return end
    self.progressHistoryCheckpointQueued = true
    zo_callLater(function()
        TPM.progressHistoryCheckpointQueued = false
        local snapshot = TPM:CaptureHistorySnapshot(false)
        TPM:CheckMilestones(snapshot)
        TPM:CheckpointHistory("progress", false, snapshot)
        if TPM.statisticsWindow and not TPM.statisticsWindow:IsHidden()
            and TPM.saved and TPM.saved.statisticsPage == "history"
            and TPM:GetStatisticsHistorySubPage() == 1 then
            TPM:RefreshHistoryStatisticsPage()
        end
    end, 250)
end

function TPM:RunSavedVariableMigrations()
    if not self.saved then return end
    local schema = math.max(0, tonumber(self.saved.schemaVersion) or 0)
    if schema < 1 then
        if type(self.saved.economyZoneStatsByCharacter) ~= "table" then self.saved.economyZoneStatsByCharacter = {} end
        schema = 1
    end
    if schema < 2 then
        local days = tonumber(self.saved.statisticsCharacterRangeDays) or 7
        if days~=7 and days~=30 and days~=90 and days~=365 then days=7 end
        self.saved.statisticsCharacterRangeDays=days; self.saved.statisticsCharacterRangeOffset=math.max(0,tonumber(self.saved.statisticsCharacterRangeOffset) or 0)
        schema = 2
    end
    if schema < 3 then
        -- Existing 2.7.3/2.7.4 ledgers cannot reveal historic DST offsets or
        -- per-zone time retroactively. Marking happens lazily per character and
        -- all new observations store both values accurately from this version.
        for _,store in pairs(self.saved.historyByCharacter or {}) do if type(store)=="table" then store.characterPlaytime365OffsetMigrated=false end end
        schema = 3
    end
    if schema < 4 then
        -- 2.7.11 splits the old combined accent channel into headings, accents,
        -- normal text and progress/value colors. Preserve the user's previous
        -- accent choice for headings when upgrading instead of silently losing it.
        local old=self.saved.statisticsThemeAccent
        if type(old)=="table" then self.saved.statisticsThemeHeading={r=old.r,g=old.g,b=old.b} end
        if type(self.saved.statisticsThemeText)~="table" then self.saved.statisticsThemeText={r=.88,g=.84,b=.74} end
        schema=4
    end
    -- Never downgrade a SavedVariables file written by a newer TPM build.
    self.saved.schemaVersion = math.max(tonumber(self.saved.schemaVersion) or 0, CURRENT_SCHEMA_VERSION, schema)
end


---------------------------------------------------------------------------
-- Naga: Locations list colors + mouseover progress (from NagaMapCompletion)
---------------------------------------------------------------------------
TPM.locationNameLookup = TPM.locationNameLookup or {}
TPM.locationsHooked = false

local NMC_DEFAULT_LOCATION_RGBA = {0.898, 0.855, 0.714, 1}
local NMC_PIN_COLORS = {
    complete = {0.20, 0.95, 0.30, 1},
    middle   = {1.00, 0.60, 0.10, 1},
    low      = {1.00, 0.25, 0.25, 1},
    unknown  = {0.75, 0.70, 0.55, 1},
}

local function NMC_NormalizeName(name)
    if not name then return "" end
    name = string.lower(name)
    name = name:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    name = name:gsub("%s+", " ")
    local base = name:match("^([^%(]+)") or name
    base = base:gsub("%s+$", ""):gsub("^%s+", "")
    base = base:gsub("^the ", ""):gsub(" de ", " "):gsub(" do ", " "):gsub(" da ", " ")
    base = base:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    return base
end

local function NMC_GetColorKey(percent)
    if percent == nil then return "unknown" end
    if percent >= 100 then return "complete" end
    if percent >= 50 then return "middle" end
    return "low"
end

local function NMC_ProgressColorCode(c, t)
    if not t or t <= 0 then return "|cBBBBBB" end
    if c >= t then return "|c22FF44" end
    if c > 0 then return "|cFF9900" end
    return "|cFF3333"
end

local function NMC_ApplyLabelColor(label, percent, forceDefault)
    if not label then return end
    local r, g, b, a
    if forceDefault or percent == false or percent == nil then
        r, g, b, a = NMC_DEFAULT_LOCATION_RGBA[1], NMC_DEFAULT_LOCATION_RGBA[2], NMC_DEFAULT_LOCATION_RGBA[3], NMC_DEFAULT_LOCATION_RGBA[4]
        label.nmcPercent = nil
        label.nmcR, label.nmcG, label.nmcB, label.nmcA = nil, nil, nil, nil
        label.nmcColorsEnabled = false
    else
        local c = NMC_PIN_COLORS[NMC_GetColorKey(percent)]
        r, g, b, a = c[1], c[2], c[3], c[4]
        label.nmcPercent = percent
        label.nmcR, label.nmcG, label.nmcB, label.nmcA = r, g, b, a
        label.nmcColorsEnabled = true
    end
    if label.SetColor then label:SetColor(r, g, b, a) end
    if label.SetNormalFontColor then label:SetNormalFontColor(r, g, b, a) end
    if label.SetMouseOverFontColor then
        label:SetMouseOverFontColor(math.min(1, r + 0.12), math.min(1, g + 0.12), math.min(1, b + 0.12), a)
    end
    if label.SetPressedFontColor then label:SetPressedFontColor(r, g, b, a) end
    if label.SetDisabledFontColor then label:SetDisabledFontColor(r * 0.55, g * 0.55, b * 0.55, a) end
    if label.SetSelectedFontColor then label:SetSelectedFontColor(r, g, b, a) end
end

function TPM:BuildLocationNameLookup()
    self.locationNameLookup = {}
    if type(GetNextZoneStoryZoneId) ~= "function" then return 0 end
    local zoneId = GetNextZoneStoryZoneId()
    local count, safety = 0, 0
    while zoneId ~= nil and zoneId ~= 0 and safety < 500 do
        safety = safety + 1
        local rawName = (type(GetZoneNameById) == "function" and GetZoneNameById(zoneId)) or ("Zone " .. tostring(zoneId))
        local name = zo_strformat(SI_ZONE_NAME, rawName)
        local breakdown, completed, total, percent = self:GetResolvedCompletion(zoneId)
        local details = {}
        if breakdown then
            for _, row in ipairs(breakdown) do
                local catKey = COMPLETION_LOCALIZATION_KEYS and COMPLETION_LOCALIZATION_KEYS[row.completionType]
                local catName = catKey and self:L(catKey) or tostring(row.completionType)
                details[#details + 1] = {
                    name = catName,
                    completed = row.completed or 0,
                    total = row.total or 0,
                }
            end
        end
        local entry = {
            id = zoneId,
            name = name,
            percent = percent,
            details = details,
            completed = completed or 0,
            total = total or 0,
        }
        if percent ~= nil then
            local function indexKey(k)
                if k and k ~= "" and not self.locationNameLookup[k] then
                    self.locationNameLookup[k] = entry
                end
            end
            indexKey(NMC_NormalizeName(name))
            local eng = name:match("%(([^%)]+)%)")
            if eng then indexKey(NMC_NormalizeName(eng)) end
        end
        count = count + 1
        local nextId = GetNextZoneStoryZoneId(zoneId)
        if nextId == zoneId then break end
        zoneId = nextId
    end
    return count
end

function TPM:LookupLocationEntry(locationName)
    if not locationName or locationName == "" then return nil end
    local key = NMC_NormalizeName(locationName)
    if self.locationNameLookup[key] then return self.locationNameLookup[key] end
    local eng = locationName:match("%(([^%)]+)%)")
    if eng then
        local ek = NMC_NormalizeName(eng)
        if self.locationNameLookup[ek] then return self.locationNameLookup[ek] end
    end
    local lower = string.lower(locationName)
    for k, entry in pairs(self.locationNameLookup) do
        if #k >= 4 then
            if lower:find(k, 1, true) or k:find(key, 1, true) or key:find(k, 1, true) then
                return entry
            end
        end
    end
    return nil
end

function TPM:AddLocationProgressToTooltip(tooltip, entry)
    if not tooltip then return end
    local percent = entry and entry.percent
    local detailsList = entry and entry.details
    local status
    local completeWord = self:L("FILTER_COMPLETE") or "100%"
    local noData = self:L("GOAL_NO_DETAILS") or "No data"
    local collected = self:L("STAT_OBJECTIVES") or "Collected"
    if percent == nil then
        status = "|cBBBBBB" .. tostring(noData) .. "|r"
    elseif percent >= 100 then
        status = string.format("|c22FF44● %d%% %s|r", math.floor(percent + 0.5), completeWord)
    elseif percent >= 50 then
        status = string.format("|cFF9900● %d%%|r", math.floor(percent + 0.5))
    else
        status = string.format("|cFF3333● %d%%|r", math.floor(percent + 0.5))
    end
    tooltip:AddLine("Zone Story: " .. status, "ZoFontGame")
    if detailsList and #detailsList > 0 then
        tooltip:AddLine(" ", "ZoFontGame")
        tooltip:AddLine("|cFFFFFF" .. tostring(collected) .. "|r", "ZoFontGame")
        for _, d in ipairs(detailsList) do
            local col = NMC_ProgressColorCode(d.completed, d.total)
            tooltip:AddLine(string.format("%s%s: %d/%d|r", col, d.name, d.completed, d.total), "ZoFontGame")
        end
    end
end

function TPM:ColorLocationControl(control, data)
    if not control or not data then return end
    local locationLabel = control:GetNamedChild("Location")
    if not locationLabel then return end

    local entry = self:LookupLocationEntry(data.locationName)
    local percent = entry and entry.percent or nil
    if percent == nil and locationLabel.GetText then
        entry = self:LookupLocationEntry(locationLabel:GetText())
        percent = entry and entry.percent
    end

    locationLabel.nmcLocationName = data.locationName
    locationLabel.nmcEntry = entry
    if locationLabel.SetFont then
        locationLabel:SetFont("ZoFontWinH4")
    end

    local colorsOn = not (self.saved and self.saved.enableLocationColors == false)
    if colorsOn and percent ~= nil then
        NMC_ApplyLabelColor(locationLabel, percent, false)
    else
        NMC_ApplyLabelColor(locationLabel, nil, true)
    end

    if not locationLabel.nmcHoverHooked then
        locationLabel.nmcHoverHooked = true
        local oldEnter = locationLabel:GetHandler("OnMouseEnter")
        local oldExit = locationLabel:GetHandler("OnMouseExit")
        locationLabel:SetHandler("OnMouseEnter", function(lbl, ...)
            if oldEnter then oldEnter(lbl, ...) end
            if TPM.saved and TPM.saved.enableLocationColors ~= false and lbl.nmcColorsEnabled and lbl.nmcR then
                NMC_ApplyLabelColor(lbl, lbl.nmcPercent, false)
            elseif TPM.saved and TPM.saved.enableLocationColors == false then
                NMC_ApplyLabelColor(lbl, nil, true)
            end
            if TPM.saved and TPM.saved.enableLocationTooltips == false then return end
            local name = lbl.nmcLocationName or (lbl.GetText and lbl:GetText()) or "Zone"
            InitializeTooltip(InformationTooltip, lbl, RIGHT, -16, 0)
            InformationTooltip:AddLine(name, "ZoFontWinH3")
            TPM:AddLocationProgressToTooltip(InformationTooltip, lbl.nmcEntry or TPM:LookupLocationEntry(name))
        end)
        locationLabel:SetHandler("OnMouseExit", function(lbl, ...)
            ClearTooltip(InformationTooltip)
            if oldExit then oldExit(lbl, ...) end
            if TPM.saved and TPM.saved.enableLocationColors ~= false and lbl.nmcColorsEnabled and lbl.nmcR then
                NMC_ApplyLabelColor(lbl, lbl.nmcPercent, false)
            else
                NMC_ApplyLabelColor(lbl, nil, true)
            end
        end)
    end
end

function TPM:HookLocationsList()
    if self.locationsHooked then return end
    local function tryHook()
        if TPM.locationsHooked then return true end
        if not WORLD_MAP_LOCATIONS or not WORLD_MAP_LOCATIONS.SetupLocation then return false end
        local original = WORLD_MAP_LOCATIONS.SetupLocation
        WORLD_MAP_LOCATIONS.SetupLocation = function(self, control, data)
            original(self, control, data)
            TPM:ColorLocationControl(control, data)
            zo_callLater(function()
                if control and data then TPM:ColorLocationControl(control, data) end
            end, 10)
        end
        TPM.locationsHooked = true
        return true
    end
    if not tryHook() and WORLD_MAP_SCENE then
        WORLD_MAP_SCENE:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_SHOWN then
                zo_callLater(function()
                    if tryHook() then TPM:RefreshLocationsColors() end
                end, 100)
            end
        end)
    end
end

function TPM:RefreshLocationsColors()
    if not WORLD_MAP_LOCATIONS or not WORLD_MAP_LOCATIONS.list then return end
    if type(ZO_ScrollList_RefreshVisible) == "function" then
        pcall(ZO_ScrollList_RefreshVisible, WORLD_MAP_LOCATIONS.list)
    end
end

function TPM:InitializeLocationColors()
    self:BuildLocationNameLookup()
    self:HookLocationsList()
    if WORLD_MAP_SCENE then
        WORLD_MAP_SCENE:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_SHOWN then
                zo_callLater(function()
                    TPM:BuildLocationNameLookup()
                    TPM:RefreshLocationsColors()
                end, 50)
            end
        end)
    end
end


function TPM:Initialize()
    -- Define NumPad 5 as TPM's default binding without forcing it as a custom
    -- bind. ESO will use this as the default and players can freely replace it
    -- under Controls > Keybindings > Tamriel Progress Map (Naga Mapa Completo).
    local noModifier = KEY_INVALID or 0
    CreateDefaultActionBind("TPM_TOGGLE_STATISTICS", KEY_NUMPAD5, noModifier, noModifier, noModifier, noModifier)

    -- v2.6.81: When the standalone Statistics journal owns UI mode, the
    -- normal ESO Toggle UI Mode action (Left Alt by default) closes TPM again
    -- instead of leaving the journal open while only changing cursor mode.
    -- Hooking the ESO action also respects players who remap that native bind.
    if not self.statisticsToggleUIModeHookInstalled and type(ZO_PreHook) == "function"
        and _G.SCENE_MANAGER and type(_G.SCENE_MANAGER.OnToggleUIModeBinding) == "function" then
        ZO_PreHook(_G.SCENE_MANAGER, "OnToggleUIModeBinding", function()
            if TPM.statisticsOpenedStandalone then
                local logicallyOpen = TPM.statisticsTemporarilyHiddenForScene == true
                    or (TPM.statisticsWindow and not TPM.statisticsWindow:IsHidden())
                if logicallyOpen then
                    TPM:HideStatisticsWindow()
                    return true
                end
            end
            return false
        end)
        self.statisticsToggleUIModeHookInstalled = true
    end

    -- Server-dependent progression/economy/history data is isolated by world.
    -- Read the pre-2.7.1 non-server AccountWide table directly, before creating
    -- the new GetWorldName() namespace. This avoids creating another legacy
    -- ZO_SavedVars wrapper and lets us mark the migration source exactly once.
    local worldName = GetWorldName()
    local legacySaved
    local rawSavedRoot = _G["NagaMapaCompleto_SavedVariables"]
    if type(rawSavedRoot) == "table" then
        local defaultNamespace = rawSavedRoot["Default"]
        local accountTable = type(defaultNamespace) == "table" and defaultNamespace[GetDisplayName()] or nil
        if type(accountTable) == "table" then
            legacySaved = accountTable["$AccountWide"]
        end
    end

    self.saved = ZO_SavedVars:NewAccountWide("NagaMapaCompleto_SavedVariables", 1, worldName, DEFAULTS)
    local migratedLegacyThisLoad = false
    if not self.saved.serverScopeMigrated then
        local isPts = string.find(string.lower(worldName), "pts", 1, true) ~= nil
        local canMigrateLegacy = not isPts
            and type(legacySaved) == "table"
            and legacySaved.serverScopeMigrationCompleted ~= true

        if canMigrateLegacy then
            local legacyCopy = TPM_DeepCopyPlain(legacySaved)
            for key, value in pairs(legacyCopy) do
                if key ~= "serverScopeMigrated"
                    and key ~= "serverScopeMigrationWorld"
                    and key ~= "serverScopeMigrationCompleted" then
                    self.saved[key] = value
                end
            end
            -- Mark the old non-server namespace so it can never be copied a
            -- second time to another live megaserver.
            legacySaved.serverScopeMigrationCompleted = true
            legacySaved.serverScopeMigrationWorld = worldName
            migratedLegacyThisLoad = true
        end

        self.saved.serverScopeMigrated = true
        self.saved.serverScopeMigrationWorld = worldName
    end

    -- ESOUI's SavedVariables migration guidance recommends persisting both the
    -- copied destination and the migration marker immediately. Reload only once,
    -- and only for users who actually had legacy non-server data to migrate.
    if migratedLegacyThisLoad then
        ReloadUI()
        return
    end

    self.saved.language = "auto"
    self:RunSavedVariableMigrations()
    if self.saved.statisticsThemeDesign ~= "tpm" and self.saved.statisticsThemeDesign ~= "vanilla" and self.saved.statisticsThemeDesign ~= "dark" then
        self.saved.statisticsThemeDesign = DEFAULTS.statisticsThemeDesign
    end
    if type(self.saved.statisticsThemeProgress) ~= "table" then
        self.saved.statisticsThemeProgress = { r = DEFAULTS.statisticsThemeProgress.r, g = DEFAULTS.statisticsThemeProgress.g, b = DEFAULTS.statisticsThemeProgress.b }
    end
    self:StartStatisticsThemeRGBUpdate()
    if not self.saved.percentColorModeMigrated then
        if self.saved.blackPercentText then
            self.saved.percentColorMode = "black"
        end
        self.saved.percentColorModeMigrated = true
    end
    if self.saved.percentColorMode ~= "progress" and self.saved.percentColorMode ~= "black"
        and self.saved.percentColorMode ~= "brown" and self.saved.percentColorMode ~= "gold"
        and self.saved.percentColorMode ~= "custom" then
        self.saved.percentColorMode = DEFAULTS.percentColorMode
    end

    -- v2.0.4: Black is now the standard map-percentage color. Existing users
    -- who were still on the old default "progress" palette are migrated once.
    -- Explicit Brown/Gold/Custom choices are preserved.
    if not self.saved.percentColorBlack204Migrated then
        if self.saved.percentColorMode == "progress" then
            self.saved.percentColorMode = "black"
            self.saved.blackPercentText = true
        end
        self.saved.percentColorBlack204Migrated = true
    end

    -- v2.0.5: force the map percentage color to true black once on upgrade.
    -- Some 2.0.x installs already had Gold/Custom saved from testing, so merely
    -- changing the default in 2.0.4 could not affect those existing SavedVars.
    -- After this one-time reset the user can freely choose another color again.
    if not self.saved.percentColorBlack205Migrated then
        self.saved.percentColorMode = "black"
        self.saved.blackPercentText = true
        self.saved.percentColorBlack205Migrated = true
    end

    if type(self.saved.customPercentColor) ~= "table" then
        self.saved.customPercentColor = { r = DEFAULTS.customPercentColor.r, g = DEFAULTS.customPercentColor.g, b = DEFAULTS.customPercentColor.b }
    else
        self.saved.customPercentColor.r = Clamp(tonumber(self.saved.customPercentColor.r) or DEFAULTS.customPercentColor.r, 0, 1)
        self.saved.customPercentColor.g = Clamp(tonumber(self.saved.customPercentColor.g) or DEFAULTS.customPercentColor.g, 0, 1)
        self.saved.customPercentColor.b = Clamp(tonumber(self.saved.customPercentColor.b) or DEFAULTS.customPercentColor.b, 0, 1)
    end

    self.saved.mapPercentScale = Clamp(Round(tonumber(self.saved.mapPercentScale) or DEFAULTS.mapPercentScale), 70, 160)
    self.saved.headerPercentScale = Clamp(Round(tonumber(self.saved.headerPercentScale) or DEFAULTS.headerPercentScale), 70, 160)
    self.saved.statisticsWindowScale = Clamp(Round(tonumber(self.saved.statisticsWindowScale) or DEFAULTS.statisticsWindowScale), 80, 120)
    local characterRange=tonumber(self.saved.statisticsCharacterRangeDays) or 7
    if characterRange~=7 and characterRange~=30 and characterRange~=90 and characterRange~=365 then characterRange=7 end
    self.saved.statisticsCharacterRangeDays=characterRange
    self.saved.statisticsCharacterRangeOffset=Clamp(tonumber(self.saved.statisticsCharacterRangeOffset) or 0,0,math.max(0,math.floor((characterRange-1)/7)*7))

    if not self.saved.hundredDisplayMigrated then
        self.saved.hundredDisplayMode = self.saved.hideCompletedZones and "hidden" or "percent"
        self.saved.hundredDisplayMigrated = true
    end
    if self.saved.hundredDisplayMode ~= "percent" and self.saved.hundredDisplayMode ~= "check" and self.saved.hundredDisplayMode ~= "hidden" then
        self.saved.hundredDisplayMode = DEFAULTS.hundredDisplayMode
    end
    self.saved.hideCompletedZones = self.saved.hundredDisplayMode == "hidden"

    if self.saved.quickFilter ~= "all" and self.saved.quickFilter ~= "incomplete"
        and self.saved.quickFilter ~= "under50" and self.saved.quickFilter ~= "complete" then
        self.saved.quickFilter = DEFAULTS.quickFilter
    end

    if self.saved.statisticsSortMode ~= "progress" and self.saved.statisticsSortMode ~= "name" then
        self.saved.statisticsSortMode = DEFAULTS.statisticsSortMode
    end
    -- 2.7.31 journal restructure: Character and Alliance became page 2 of
    -- PvE/PvP and Progress. Preserve exactly what older users had open.
    if self.saved.statisticsPage == "player" then
        self.saved.statisticsPage = "history"
        self.saved.statisticsHistorySubPage = 2
    elseif self.saved.statisticsPage == "alliance" then
        self.saved.statisticsPage = "progress"
        self.saved.statisticsProgressSubPage = 2
    end
    if self.saved.statisticsPage ~= "progress" and self.saved.statisticsPage ~= "economy" and self.saved.statisticsPage ~= "history" then
        self.saved.statisticsPage = DEFAULTS.statisticsPage
    end
    self.saved.statisticsProgressSubPage = tonumber(self.saved.statisticsProgressSubPage) == 2 and 2 or 1
    self.saved.statisticsHistorySubPage = tonumber(self.saved.statisticsHistorySubPage) == 2 and 2 or 1
    if tonumber(self.saved.statisticsCompletionPage) ~= 1 and tonumber(self.saved.statisticsCompletionPage) ~= 2 and tonumber(self.saved.statisticsCompletionPage) ~= 3 then
        self.saved.statisticsCompletionPage = DEFAULTS.statisticsCompletionPage
    else
        self.saved.statisticsCompletionPage = tonumber(self.saved.statisticsCompletionPage)
    end
    if self.saved.statisticsCategorySortMode ~= "all" and self.saved.statisticsCategorySortMode ~= "name"
        and self.saved.statisticsCategorySortMode ~= "asc" and self.saved.statisticsCategorySortMode ~= "desc" then
        self.saved.statisticsCategorySortMode = DEFAULTS.statisticsCategorySortMode
    end
    self.saved.statisticsFocusZoneId = math.max(0, Round(tonumber(self.saved.statisticsFocusZoneId) or 0))
    self.saved.skyshardGoalPosition = tonumber(self.saved.skyshardGoalPosition) == 2 and 2 or 1
    self.saved.skyshardGoalCustomPosition = self.saved.skyshardGoalCustomPosition == true
    if type(self.saved.skyshardGoalCustomX) ~= "number" or type(self.saved.skyshardGoalCustomY) ~= "number" then
        self.saved.skyshardGoalCustomPosition = false
        self.saved.skyshardGoalCustomX = false
        self.saved.skyshardGoalCustomY = false
    end
    if type(self.saved.skyshardGoalCustomWidth) ~= "number" or type(self.saved.skyshardGoalCustomHeight) ~= "number" then
        self.saved.skyshardGoalCustomWidth = false
        self.saved.skyshardGoalCustomHeight = false
    else
        self.saved.skyshardGoalCustomWidth = math.floor(Clamp(self.saved.skyshardGoalCustomWidth, 230, 760) + 0.5)
        self.saved.skyshardGoalCustomHeight = math.floor(Clamp(self.saved.skyshardGoalCustomHeight, 60, 220) + 0.5)
    end
    if not self.saved.skyshardGoalCustomPosition then
        self.saved.skyshardGoalCustomWidth = false
        self.saved.skyshardGoalCustomHeight = false
    end
    if self.saved.progressGoalCategoryType ~= SIDE_QUEST_CATEGORY_KEY
        and self.saved.progressGoalCategoryType ~= CROWN_QUEST_CATEGORY_KEY
        and self.saved.progressGoalCategoryType ~= ZONE_STABLE_MOUNT_CATEGORY_KEY then
        local numericGoalType = tonumber(self.saved.progressGoalCategoryType)
        self.saved.progressGoalCategoryType = numericGoalType or false
    end
    if self.saved.skyshardGoalEnabled == true and not self.saved.progressGoalCategoryType then
        self.saved.progressGoalCategoryType = _G.ZONE_COMPLETION_TYPE_SKYSHARDS
    end
    -- 3.0.6 simplifies Goals to two meaningful modes. Preserve old category
    -- tabs as the new compact category filter during migration.
    if self.saved.goalPlannerMode == "quests" or self.saved.goalPlannerMode == "skyshards" or self.saved.goalPlannerMode == "bosses" then
        self.saved.goalPlannerCategory = self.saved.goalPlannerMode
        self.saved.goalPlannerMode = "recommended"
    elseif self.saved.goalPlannerMode == "lowest" then
        self.saved.goalPlannerMode = "recommended"
    end
    local validGoalMode = false
    for _, value in ipairs(GOAL_PLANNER_MODES) do if self.saved.goalPlannerMode == value then validGoalMode = true break end end
    if not validGoalMode then self.saved.goalPlannerMode = DEFAULTS.goalPlannerMode end
    local goalCategory = self:GetGoalPlannerCategoryDefinition(self.saved.goalPlannerCategory)
    self.saved.goalPlannerCategory = goalCategory.key
    local validRange = false
    for _, value in ipairs(HISTORY_RANGES) do if tonumber(self.saved.historyRangeDays) == value then validRange = true break end end
    if not validRange then self.saved.historyRangeDays = DEFAULTS.historyRangeDays end
    local validHistoryMetric = false
    for _, definition in ipairs(self:GetHistoryMetricDefinitions()) do
        if definition.key == self.saved.historyMetric then validHistoryMetric = true break end
    end
    if not validHistoryMetric then self.saved.historyMetric = DEFAULTS.historyMetric end
    self.saved.historyRetentionDays = Clamp(Round(tonumber(self.saved.historyRetentionDays) or HISTORY_RETENTION_DAYS), 30, 1460)
    if type(self.saved.combatStatsByCharacter) ~= "table" then
        self.saved.combatStatsByCharacter = {}
    end
    if type(self.saved.economyStats) ~= "table" then
        self.saved.economyStats = { trackingVersion = "2.0.10", currencies = {} }
    end
    if type(self.saved.economyStatsByCharacter) ~= "table" then
        self.saved.economyStatsByCharacter = {}
    end
    if type(self.saved.historyByCharacter) ~= "table" then self.saved.historyByCharacter = {} end
    if type(self.saved.milestoneStateByCharacter) ~= "table" then self.saved.milestoneStateByCharacter = {} end

    -- v2.0.10: 2.0.9 did not ignore CURRENCY_CHANGE_REASON_PLAYER_INIT.
    -- Depending on login timing ESO can emit the already-existing wallet balance
    -- as an initialization update, which could falsely inflate "Received". 2.0.9
    -- was a development build, so reset those new economy counters once and start
    -- the reliable ledger from 2.0.10. Current balances are never affected.
    if not self.saved.economyPlayerInit210Migrated then
        self.saved.economyStats = { trackingVersion = "2.0.10", currencies = {} }
        self.saved.economyPlayerInit210Migrated = true
    end

    -- v2.0.3: 2.0.2 could leave the 100%-only quick filter active while users
    -- were testing the new statistics window, which makes every incomplete
    -- world-map label disappear by design. Reset it once on upgrade so the
    -- overview immediately returns to the familiar v1.6 "Alle" view. After
    -- this migration, quick-filter choices behave and persist normally again.
    if not self.saved.mapLabels203Migrated then
        self.saved.quickFilter = "all"
        self.saved.mapLabels203Migrated = true
    end

    -- v1.5.5 expands the old 3-style selector to 10 styles. Preserve the old
    -- "map" choice by migrating it to the new Handwritten style.
    self.saved.fontStyle = self:NormalizeFontStyle(self.saved.fontStyle) or DEFAULTS.fontStyle
    self.saved.questFontStyle = self:NormalizeFontStyle(self.saved.questFontStyle) or DEFAULTS.questFontStyle

    -- 2.6.46 migration: show the preserved historical Economy totals first.
    -- Users can still select any zone afterwards for the zone ledger.
    if self.saved and not self.saved.economyFocusCacheRestore2646 then
        self.saved.economyDetailFocusZoneId = 0
        self.saved.economyFocusCacheRestore2646 = true
    end

    self:ResolveLanguage()
    self:RefreshBindingStrings()
    self:CreateHeaderProgressLabel()
    self:CreateQuestRewardControl()
    self:CreateStatisticsWindow()
    self:CreateSkyshardGoalWidget()
    self:RegisterSettings()
    -- Modern UI: prefer dark theme for Naga Mapa Completo (one-time soft default)
    if self.saved and self.saved.statisticsThemeDesign == "tpm" and not self.saved.nagaModernUiMigrated then
        self.saved.statisticsThemeDesign = "cyber"
        self.saved.statisticsThemeHeading = { r = 0.55, g = 0.85, b = 1.00 }
        self.saved.statisticsThemeAccent = { r = 0.35, g = 0.78, b = 0.95 }
        self.saved.statisticsThemeProgress = { r = 0.30, g = 0.90, b = 0.70 }
        self.saved.statisticsThemeText = { r = 0.90, g = 0.93, b = 0.96 }
        self.saved.nagaModernUiMigrated = true
    end
    self:InitializeLocationColors()
    self:RegisterVanillaQuestRewardColorHooks()

    if not self:RegisterCustomPin() then
        zo_callLater(function()
            if TPM and TPM:RegisterCustomPin() then
                TPM:QueueRefresh(10)
            end
        end, 500)
    end

    CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", function()
        TPM:ReleaseOverlayLabels()
        ZO_ClearTable(TPM.symbolicZonePositions)
        TPM.symbolicZonePositionsMapId = 0
        TPM:InvalidateStatisticsData(false)
        TPM:QueueRefresh(80)
    end)

    if WORLD_MAP_SCENE then
        WORLD_MAP_SCENE:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_SHOWING then
                TPM.worldMapSceneVisible = true
                TPM:UpdateFocusedRewardPanelPolling()
                if TPM.skyshardGoalWidget then TPM.skyshardGoalWidget:SetHidden(true) end
                TPM:RefreshAllianceTerritoryBorders()
                TPM:QueueRefresh(40)
            elseif newState == SCENE_SHOWN then
                TPM.worldMapSceneVisible = true
                TPM:UpdateFocusedRewardPanelPolling()
                TPM:RefreshAllianceTerritoryBorders()
                -- Do not let a refresh queued during SCENE_SHOWING suppress the
                -- final refresh after ESO has finished showing the map.
                TPM.refreshQueued = false
                TPM:QueueRefresh(20)
            elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
                TPM.worldMapSceneVisible = false
                TPM:UpdateFocusedRewardPanelPolling()
                TPM.refreshQueued = false
                TPM:ReleaseOverlayLabels()
                TPM:HideAllianceTerritoryBorders()
                TPM:HideHeaderProgress()
                TPM:HideQuestRewards()
                -- A journal opened from the world-map button belongs to that
                -- scene and closes with it. A standalone journal opened by
                -- keybind or /tpm stats remains visible when the map closes.
                if not TPM.statisticsOpenedStandalone then
                    TPM:HideStatisticsWindow()
                end
                zo_callLater(function() TPM:RefreshSkyshardGoalWidget() end, 50)
                -- Minimap addons can reuse ZO_WorldMap after the real scene closes.
                TPM:RefreshQuickFilterBar()
            end
        end)

        if WORLD_MAP_SCENE.IsShowing and WORLD_MAP_SCENE:IsShowing() then
            self.worldMapSceneVisible = true
        else
            self.worldMapSceneVisible = false
        end
    end

    if GAMEPAD_WORLD_MAP_SCENE then
        GAMEPAD_WORLD_MAP_SCENE:RegisterCallback("StateChange", function(_, newState)
            if newState == SCENE_SHOWING then
                TPM.gamepadWorldMapSceneVisible = true
                TPM:UpdateFocusedRewardPanelPolling()
                if TPM.skyshardGoalWidget then TPM.skyshardGoalWidget:SetHidden(true) end
                TPM:RefreshAllianceTerritoryBorders()
                TPM:QueueRefresh(40)
            elseif newState == SCENE_SHOWN then
                TPM.gamepadWorldMapSceneVisible = true
                TPM:UpdateFocusedRewardPanelPolling()
                TPM:RefreshAllianceTerritoryBorders()
                TPM.refreshQueued = false
                TPM:QueueRefresh(20)
            elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
                TPM.gamepadWorldMapSceneVisible = false
                TPM:UpdateFocusedRewardPanelPolling()
                TPM.refreshQueued = false
                TPM:ReleaseOverlayLabels()
                TPM:HideAllianceTerritoryBorders()
                TPM:HideHeaderProgress()
                TPM:HideQuestRewards()
                -- A journal opened from the world-map button belongs to that
                -- scene and closes with it. A standalone journal opened by
                -- keybind or /tpm stats remains visible when the map closes.
                if not TPM.statisticsOpenedStandalone then
                    TPM:HideStatisticsWindow()
                end
                zo_callLater(function() TPM:RefreshSkyshardGoalWidget() end, 50)
                -- Minimap addons can reuse ZO_WorldMap after the real scene closes.
                TPM:RefreshQuickFilterBar()
            end
        end)

        if GAMEPAD_WORLD_MAP_SCENE.IsShowing and GAMEPAD_WORLD_MAP_SCENE:IsShowing() then
            self.gamepadWorldMapSceneVisible = true
        else
            self.gamepadWorldMapSceneVisible = false
        end
    end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "ActivityPrepareForJump", EVENT_PREPARE_FOR_JUMP,
        function(_, zoneName, zoneDescription, loadingTexture, zoneDisplayType)
            TPM:RememberJumpDestination(zoneName, zoneDisplayType, loadingTexture)
        end)

    -- Keep the Skyshard goal synchronized with the same HUD scene lifecycle
    -- used by native trackers. This makes M/ESC hiding immediate, not dependent
    -- on the 1.5s safety refresh timer.
    local function RegisterSkyshardHudScene(scene)
        if scene and type(scene.RegisterCallback) == "function" then
            scene:RegisterCallback("StateChange", function()
                zo_callLater(function() TPM:RefreshSkyshardGoalWidget() end, 0)
            end)
        end
    end
    RegisterSkyshardHudScene(_G.HUD_SCENE)
    RegisterSkyshardHudScene(_G.HUD_UI_SCENE)

    -- React to *every* scene transition, not only the world map. This is the
    -- reliable part for ESC: as soon as the current scene stops being HUD or
    -- HUD-UI, the Skyshard block is hidden. Returning to the HUD restores it.
    if _G.SCENE_MANAGER and type(_G.SCENE_MANAGER.RegisterCallback) == "function" then
        _G.SCENE_MANAGER:RegisterCallback("SceneStateChanged", function()
            if TPM.skyshardGoalWidget and not TPM:IsSkyshardGoalHudSceneVisible() then
                TPM.skyshardGoalWidget:SetHidden(true)
            end
            zo_callLater(function()
                TPM:RefreshStandaloneStatisticsSceneVisibility()
                TPM:RefreshSkyshardGoalWidget()
            end, 0)
        end)
    end

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "PlayerActivated", EVENT_PLAYER_ACTIVATED, function()
        -- Ownership and available zone-story data can change between sessions.
        -- Economy tracking is character-scoped from 2.0.15 onward, so this also
        -- ensures the active character ledger is selected immediately after login.
        TPM:InvalidateStatisticsData(true)
        TPM.alliancePlannerZonePositionCache = {}
        TPM.alliancePlannerZonePositionCacheMapId = nil
        TPM:GetEconomyStats()
        TPM:SyncCurrentEsoPlayedTime()
        TPM:StartOrResumeHistorySession()
        TPM:HandleTrackedActivityActivated()
        TPM:ResumeParticipatingWorldEvent()
        TPM:DiscoverCurrentZoneWorldEventCandidates(true)
        zo_callLater(function() TPM:HandleTrackedActivityActivated() end, 350)
        zo_callLater(function() TPM:ResumeParticipatingWorldEvent(); TPM:DiscoverCurrentZoneWorldEventCandidates(true) end, 500)
        zo_callLater(function() TPM.questRewardDirty=true; TPM:RefreshQuestRewards(true) end, 250)
        zo_callLater(function() TPM:RefreshSkyshardGoalWidget() end, 450)
        if TPM.statisticsWindow and not TPM.statisticsWindow:IsHidden()
            and TPM.saved and TPM.saved.statisticsPage == "economy" then
            TPM:RefreshEconomyStatisticsPage()
        end
        TPM:QueueRefresh(100)
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "HistoryPlayerDeactivated", EVENT_PLAYER_DEACTIVATED, function()
        TPM:CheckpointHistoryOnDeactivated()
    end)

    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "HistoryCheckpoint", HISTORY_CHECKPOINT_MS, function()
        if TPM.saved and TPM.saved.historyEnabled ~= false then
            TPM:CheckpointHistory("periodic", false)
        end
        if TPM.statisticsWindow and not TPM.statisticsWindow:IsHidden()
            and TPM.saved and TPM.saved.statisticsPage == "history"
            and TPM:GetStatisticsHistorySubPage() == 2 then
            TPM:RefreshPlayerStatisticsPage()
        end
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "SkyshardTomeTracking", EVENT_TIMED_ACTIVITY_TRACKING_UPDATED, function()
        -- ESO rebuilds/reanchors the native Tome HUD when the tracked Tome
        -- changes. Throw away our cached control and resolve the new native
        -- tracker twice: once immediately, once after its layout settles.
        TPM.skyshardGoalTomesAnchor = nil
        TPM.skyshardGoalLastAnchorScan = 0
        zo_callLater(function()
            TPM:UpdateSkyshardGoalAnchor(true); TPM:RefreshSkyshardGoalWidget()
        end, 50)
        zo_callLater(function()
            TPM:UpdateSkyshardGoalAnchor(true); TPM:RefreshSkyshardGoalWidget()
        end, 450)
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "SkyshardGoalZoneChanged", EVENT_ZONE_CHANGED, function()
        -- Checkpoint immediately after a zone transition. The previous /played
        -- interval is attributed to the previous observed zone, then the new
        -- observation becomes the start of the next zone segment.
        if TPM.saved and TPM.saved.historyEnabled ~= false then TPM:CheckpointHistory("zone_changed", false) end
        zo_callLater(function() TPM:RefreshSkyshardGoalWidget() end, 100)
    end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "SkyshardGoalGained", EVENT_SKYSHARD_GAINED, function()
        TPM:InvalidateStatisticsData(false)
        zo_callLater(function() TPM:RefreshSkyshardGoalWidget() end, 100)
    end)
    -- Optional polling/global mouse events are registered lazily only while needed.
    TPM:UpdateSkyshardGoalRefreshTimer()

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "QuestFocus", EVENT_QUEST_SHOW_JOURNAL_ENTRY, function()
        TPM:QueueRefresh(30)
        zo_callLater(function() TPM.questRewardDirty=true; TPM:RefreshQuestRewards(true) end, 30)
    end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "QuestList", EVENT_QUEST_LIST_UPDATED, function()
        TPM.questRewardDirty = true
        TPM:InvalidateStatisticsData(false)
        TPM:QueueRefresh(50)
        zo_callLater(function() TPM:RefreshVanillaQuestRewardColors() end, 20)
        zo_callLater(function() if TPM and TPM:IsFullWorldMapSceneVisible() then TPM:RefreshQuestRewards(true) end end, 50)
    end)
    if FOCUSED_QUEST_TRACKER and FOCUSED_QUEST_TRACKER.RegisterCallback then
        FOCUSED_QUEST_TRACKER:RegisterCallback("QuestTrackerAssistStateChanged", function()
            TPM:QueueRefresh(30)
            zo_callLater(function() TPM.questRewardDirty=true; TPM:RefreshQuestRewards(true) end, 30)
        end)
    end

    -- Rare tracker rebuilds are covered by a 2-second safety poll only while
    -- the full world map is actually open and the feature is enabled.
    TPM:UpdateFocusedRewardPanelPolling()

    -- Lightweight live updates for the Statistics journal. The manifest targets
    -- the current live APIs, so register the documented events directly.
    local function RegisterCompletionRefreshEvent(suffix, eventCode)
        local namespace = ADDON_NAME .. "Progress" .. suffix
        EVENT_MANAGER:RegisterForEvent(namespace, eventCode, function()
            TPM:InvalidateStatisticsData(false)
            if TPM:IsWorldMapVisible() or (TPM.statisticsWindow and not TPM.statisticsWindow:IsHidden()) then
                TPM:QueueRefresh(60)
            end
            TPM:QueueProgressHistoryCheckpoint()
        end)
    end

    -- Collection unlocks are rare events. Refresh page 2 immediately when
    -- ESO changes the account Collections data; no polling is required.
    local function RegisterCollectionRefreshEvent(suffix, eventCode)
        EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "Collections" .. suffix, eventCode, function()
            if TPM.statisticsWindow and not TPM.statisticsWindow:IsHidden()
                and TPM.saved and TPM.saved.statisticsPage == "progress" and TPM:GetStatisticsProgressSubPage() == 1
                and tonumber(TPM.saved.statisticsCompletionPage) == 2 then
                TPM:RefreshStatisticsWindow()
            end
        end)
    end
    RegisterCollectionRefreshEvent("Collection", EVENT_COLLECTION_UPDATED)
    RegisterCollectionRefreshEvent("Collectible", EVENT_COLLECTIBLE_UPDATED)
    RegisterCollectionRefreshEvent("Collectibles", EVENT_COLLECTIBLES_UPDATED)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "ActivityQuestRewardCacheDialog", EVENT_QUEST_COMPLETE_DIALOG,
        function(_, journalIndex)
            TPM:CacheQuestCompletionData(journalIndex)
        end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "ActivityQuestRewardCacheAdvanced", EVENT_QUEST_ADVANCED,
        function(_, journalIndex, questName, isPushed, isComplete)
            if isComplete then TPM:CacheQuestCompletionData(journalIndex, questName) end
        end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "ActivityQuestComplete", EVENT_QUEST_COMPLETE,
        function(_, questName, level, previousExperience, currentExperience, championPoints, questType, zoneDisplayType)
            TPM:RecordQuestActivity(questName, level, previousExperience, currentExperience, championPoints, questType, zoneDisplayType)
        end)

    RegisterCompletionRefreshEvent("QuestComplete", EVENT_QUEST_COMPLETE)
    RegisterCompletionRefreshEvent("ObjectiveComplete", EVENT_OBJECTIVE_COMPLETED)
    RegisterCompletionRefreshEvent("PoiUpdated", EVENT_POI_UPDATED)
    RegisterCompletionRefreshEvent("LoreBook", EVENT_LORE_BOOK_LEARNED)
    RegisterCompletionRefreshEvent("Achievement", EVENT_ACHIEVEMENT_UPDATED)
    RegisterCompletionRefreshEvent("ZoneStory", EVENT_ZONE_STORY_ACTIVITY_COMPLETED)
    RegisterCompletionRefreshEvent("Skyshard", EVENT_SKYSHARD_GAINED)

    local function RegisterPlayerProgressEvent(suffix, eventCode, filterPlayer)
        local namespace = ADDON_NAME .. "PlayerProgress" .. suffix
        EVENT_MANAGER:RegisterForEvent(namespace, eventCode, function()
            if TPM.saved and TPM.saved.historyEnabled ~= false then
                TPM:CheckpointHistory("player_progress", false)
            end
            if TPM.statisticsWindow and not TPM.statisticsWindow:IsHidden() then
                if TPM.saved and TPM.saved.statisticsPage == "history" then
                    if TPM:GetStatisticsHistorySubPage() == 2 then
                        -- XP changes only need the lightweight bars; a Level/CP change
                        -- also updates the Character profile line immediately.
                        if suffix == "Level" or suffix == "CP" or suffix == "CPGain" then
                            TPM:RefreshPlayerStatisticsPage()
                        else
                            TPM:RefreshCombatProgressionBars()
                        end
                    else
                        TPM:RefreshHistoryStatisticsPage()
                    end
                else
                    TPM:RefreshStatisticsPlayerProgress()
                end
            end
        end)
        if filterPlayer then
            EVENT_MANAGER:AddFilterForEvent(namespace, eventCode, REGISTER_FILTER_UNIT_TAG, "player")
        end
    end

    RegisterPlayerProgressEvent("XP", EVENT_EXPERIENCE_UPDATE, true)
    RegisterPlayerProgressEvent("Level", EVENT_LEVEL_UPDATE, true)
    RegisterPlayerProgressEvent("CP", EVENT_UNSPENT_CHAMPION_POINTS_CHANGED, false)
    RegisterPlayerProgressEvent("CPGain", EVENT_CHAMPION_POINT_GAINED, false)

    -- Finalize queued dungeons/trials as soon as ESO reports the activity complete.
    -- Manual dungeon entries still use the existing leave-instance fallback.
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "ActivityFinderCompleted", EVENT_ACTIVITY_FINDER_ACTIVITY_COMPLETE,
        function()
            if TPM.activeTrackedActivity and TPM:IsPersistentTrackedActivityKind(TPM.activeTrackedActivity.kind) then
                local snapshot = TPM:CaptureHistorySnapshot(false)
                TPM:FinalizeTrackedActivity(snapshot, TPM_Now())
            end
        end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "ActivityBattlegroundCompleted", EVENT_BATTLEGROUND_STATE_CHANGED,
        function(_, previousState, currentState)
            if currentState == BATTLEGROUND_STATE_FINISHED
                and TPM.activeTrackedActivity and TPM.activeTrackedActivity.kind == "battleground" then
                local snapshot = TPM:CaptureHistorySnapshot(false)
                TPM:FinalizeTrackedActivity(snapshot, TPM_Now())
            end
        end)

    -- v2.0.7 personal combat statistics. ESO does not expose complete lifetime
    -- kill/death totals to addons, so these counters are accumulated locally
    -- from this version onward and stored per character.
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "CombatStatsBG", EVENT_BATTLEGROUND_KILL,
        function(_, killedCharacterName, killedDisplayName, killedAlliance, killingCharacterName, killingDisplayName)
            TPM:RecordPvPResult(killingDisplayName, killedDisplayName, "bg", killingCharacterName, killedCharacterName)
        end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "CombatStatsPvPFeed", EVENT_PVP_KILL_FEED_DEATH,
        function(_, killLocation, killerDisplayName, killerCharacterName, killerAlliance, killerRank,
            victimDisplayName, victimCharacterName, victimAlliance, victimRank, isKillLocation)
            -- Battlegrounds have their own server-backed kill event and should
            -- not be counted a second time through the generic PvP feed.
            if TPM:IsCurrentBattlegroundActive() then return end
            if TPM:IsDuplicatePvPKillFeed(killerDisplayName, victimDisplayName, isKillLocation) then return end
            TPM:RecordPvPResult(killerDisplayName, victimDisplayName, "pvp", killerCharacterName, victimCharacterName)
        end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "KillLogReticle", EVENT_RETICLE_TARGET_CHANGED, function()
        TPM:CaptureReticlePveTarget()
    end)
    TPM:CaptureReticlePveTarget()

        -- 3.4.7 PvE kill tracking:
        -- Count NPC deaths caused by the player, their pet/companion OR a group
        -- member. This makes group dungeons reflect the enemies the party actually
        -- defeats instead of only the rare final killing blows credited to you.
        local function OnPveNpcDeath(_, result, isError, abilityName, abilityId, abilityActionSlotType,
            sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log,
            sourceUnitId, targetUnitId)
            if TPM:IsInPvPEnvironment() then return end

            local isXpDeathResult = result == ACTION_RESULT_DIED_XP
            local numericTargetId = tonumber(targetUnitId) or 0
            local recentTarget = TPM:GetRecentPlayerPveCombatTarget(numericTargetId, targetName)

            if isXpDeathResult then
                -- ESO commonly blanks targetName on DIED_XP when somebody else
                -- lands the final hit. targetUnitId is often still available,
                -- so promote an already pending row before resolving the name.
                TPM:MarkPendingPveKillXpResult(targetName, numericTargetId)
            end

            local cleanTargetName = select(1, TPM:NormalizeCombatUnitName(targetName))
            if cleanTargetName == "" and type(recentTarget) == "table" then
                cleanTargetName = tostring(recentTarget.name or "")
            end

            -- If ESO still withholds the name, do not silently drop a confirmed
            -- XP death. Show an explicit Unknown Enemy row instead so the combat
            -- log reflects every death participation the API actually reports.
            if cleanTargetName == "" and isXpDeathResult then
                cleanTargetName = TPM:L("HISTORY_UNKNOWN_ENEMY")
            end
            if cleanTargetName == "" then return end

            local personalSource = sourceType == COMBAT_UNIT_TYPE_PLAYER
                or sourceType == COMBAT_UNIT_TYPE_PLAYER_PET
                or sourceType == COMBAT_UNIT_TYPE_PLAYER_COMPANION
            local groupSource = sourceType == COMBAT_UNIT_TYPE_GROUP
            local participated = personalSource or groupSource or isXpDeathResult or recentTarget ~= nil
            if not participated then return end

            -- Death/XP at a currently active World Event is strong participation
            -- evidence. The helper can now discover an already-active Dolmen by
            -- its live POI instance id even if activation happened earlier.
            TPM:MarkNearbyWorldEventParticipationEvidence(isXpDeathResult and "death_xp" or "combat")

            -- Log every death participation ESO exposes, not just kills where
            -- the player dealt the final blow. This covers public-event mobs
            -- killed by another player after we damaged them, and grouped kills.
            local kind = TPM:GetPveKillActivityKind(cleanTargetName)
            if type(recentTarget) == "table" then
                if recentTarget.livestock or recentTarget.critter then kind = "killAnimal" end
                if recentTarget.difficulty == MONSTER_DIFFICULTY_DEADLY then kind = "killBoss" end
            end
            local difficulty = (type(recentTarget) == "table" and recentTarget.difficulty) or TPM:GetPveKillDifficulty(cleanTargetName, kind)
            TPM:QueuePveKillActivity(cleanTargetName, kind, isXpDeathResult, numericTargetId, difficulty, isXpDeathResult)

            if numericTargetId > 0 then
                local deathKey = "pve_npc_death|" .. tostring(numericTargetId)
                if TPM:IsDuplicateCombatCounterEvent(deathKey, 1800) then return end
            elseif TPM:IsDuplicatePveNpcDeathWithoutUnitId(cleanTargetName, result) then
                return
            end
            TPM:IncrementPlayerCombatStat("npcKills", 1)
            TPM:RecordWorldEventPveKill(kind)
        end

        -- Cache NPCs affected by the player/pet/companion. ESO can blank
        -- targetName on the later DIED_XP event if another player lands the
        -- killing blow; targetUnitId lets us recover the name from this cache.
        local function OnPlayerPveCombatTarget(_, result, isError, abilityName, abilityId, abilityActionSlotType,
            sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log,
            sourceUnitId, targetUnitId)
            if TPM:IsInPvPEnvironment() then return end
            if not targetName or targetName == "" then return end
            TPM:RememberPlayerPveCombatTarget(targetName, targetUnitId, targetType)
        end

        local function RegisterPlayerTargetSource(suffix, combatUnitType)
            local namespace = ADDON_NAME .. "CombatTargetCache" .. suffix
            EVENT_MANAGER:RegisterForEvent(namespace, EVENT_COMBAT_EVENT, OnPlayerPveCombatTarget)
            EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, combatUnitType)
            EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_NONE)
            EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_COMBAT_EVENT, REGISTER_FILTER_IS_ERROR, false)
        end
        RegisterPlayerTargetSource("Player", COMBAT_UNIT_TYPE_PLAYER)
        RegisterPlayerTargetSource("Pet", COMBAT_UNIT_TYPE_PLAYER_PET)
        RegisterPlayerTargetSource("Companion", COMBAT_UNIT_TYPE_PLAYER_COMPANION)

        local function RegisterPveDeathResult(suffix, resultCode)
            local namespace = ADDON_NAME .. "CombatStatsPvE" .. suffix
            EVENT_MANAGER:RegisterForEvent(namespace, EVENT_COMBAT_EVENT, OnPveNpcDeath)
            EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_COMBAT_EVENT, REGISTER_FILTER_COMBAT_RESULT, resultCode)
            EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_COMBAT_EVENT, REGISTER_FILTER_TARGET_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_NONE)
            EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_COMBAT_EVENT, REGISTER_FILTER_IS_ERROR, false)
        end

        -- DIED / DIED_XP represent the actual NPC death and are much more useful
        -- in group content than ACTION_RESULT_KILLING_BLOW.
        RegisterPveDeathResult("Died", ACTION_RESULT_DIED)
        RegisterPveDeathResult("DiedXP", ACTION_RESULT_DIED_XP)


    -- 2.6.2 World Events. PARTICIPATION_BEGIN remains the strongest signal,
    -- but activation is now kept as a candidate so classic Dark Anchors can be
    -- promoted by local combat/XP/Gold evidence when that callback is missing.
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "WorldEventActivated", EVENT_WORLD_EVENT_ACTIVATED,
        function(_, worldEventInstanceId)
            TPM:ObserveWorldEventActivation(worldEventInstanceId)
        end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "WorldEventParticipationBegin", EVENT_WORLD_EVENT_PARTICIPATION_BEGIN,
        function(_, worldEventInstanceId, stepDefId)
            TPM:BeginWorldEventParticipation(worldEventInstanceId, stepDefId)
        end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "WorldEventParticipationEnd", EVENT_WORLD_EVENT_PARTICIPATION_END,
        function(_, worldEventInstanceId)
            TPM:EndWorldEventParticipation(worldEventInstanceId)
        end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "WorldEventStepChanged", EVENT_WORLD_EVENT_STEP_CHANGED,
        function(_, worldEventInstanceId, newStepDefId)
            TPM:UpdateWorldEventTrackerMetadata(worldEventInstanceId, newStepDefId)
        end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "WorldEventLocationChanged", EVENT_WORLD_EVENT_ACTIVE_LOCATION_CHANGED,
        function(_, worldEventInstanceId)
            TPM:ObserveWorldEventActivation(worldEventInstanceId)
            TPM:UpdateWorldEventTrackerMetadata(worldEventInstanceId)
        end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "WorldEventDeactivated", EVENT_WORLD_EVENT_DEACTIVATED,
        function(_, worldEventInstanceId)
            TPM:DeactivateWorldEvent(worldEventInstanceId)
        end)

    local playerDeathNamespace = ADDON_NAME .. "CombatStatsPlayerDeath"
    EVENT_MANAGER:RegisterForEvent(playerDeathNamespace, EVENT_UNIT_DEATH_STATE_CHANGED, function(_, unitTag, isDead)
        if isDead and not TPM:IsInPvPEnvironment() and not TPM:IsDuplicateCombatCounterEvent("pve_player_death", 2500) then
            TPM:MarkNearbyWorldEventParticipationEvidence("player_death")
            TPM:IncrementPlayerCombatStat("pveDeaths", 1)
            TPM:RecordWorldEventPveDeath()
        end
    end)
    EVENT_MANAGER:AddFilterForEvent(playerDeathNamespace, EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")

    local function OnBossDeath(_, unitTag, isDead)
        if isDead then TPM:RecordBossDefeat(unitTag) end
    end
    for bossIndex = 1, 6 do
        local unitTag = "boss" .. tostring(bossIndex)
        local namespace = ADDON_NAME .. "CombatStatsBoss" .. tostring(bossIndex)
        EVENT_MANAGER:RegisterForEvent(namespace, EVENT_UNIT_DEATH_STATE_CHANGED, OnBossDeath)
        EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_UNIT_DEATH_STATE_CHANGED, REGISTER_FILTER_UNIT_TAG, unitTag)
    end

    -- v2.0.15 per-character economy tracker. EVENT_CURRENCY_UPDATE provides the
    -- old/new balance and reason. Player initialization and bank transfers are ignored so
    -- moving gold/AP/Tel Var/vouchers between wallet and bank does not inflate
    -- received/spent totals.
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "EconomyCurrency", EVENT_CURRENCY_UPDATE,
        function(_, currencyType, currencyLocation, newAmount, oldAmount, reason, reasonSupplementaryInfo)
            TPM:RecordTrackedActivityGoldGain(currencyType, currencyLocation, newAmount, oldAmount, reason)
            TPM:RecordEconomyCurrencyChange(currencyType, currencyLocation, newAmount, oldAmount, reason)
            TPM:GetEconomyCurrencyDefinitions()
            if TPM.economyCurrencyByType and TPM.economyCurrencyByType[currencyType]
                and reason ~= CURRENCY_CHANGE_REASON_PLAYER_INIT then
                TPM:QueueEconomyHistoryCheckpoint()
            end
        end)

    -- v2.6.22: track how much gold this character has actually lost to the
    -- Justice system (bounty payoff). This event does not represent passive
    -- bounty decay, and the amount is stored only as a Gold spending sub-total.
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "EconomyBountyPaid", EVENT_JUSTICE_GOLD_REMOVED,
        function(_, goldAmount)
            TPM:RecordEconomyBountyPayment(goldAmount)
        end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "ActivityExperienceGain", EVENT_EXPERIENCE_GAIN,
        function(_, reason, level, previousExperience, currentExperience)
            -- Keep this event for activity totals. Individual kill XP is
            -- matched from EVENT_EXPERIENCE_UPDATE below, which reflects
            -- every actual player XP-state change more reliably.
            TPM:RecordTrackedActivityExperienceGain(reason, level, previousExperience, currentExperience)
        end)

    -- Seed the baseline before the first kill so the first XP update can be
    -- measured as a real delta instead of being lost.
    TPM.killLogLastPlayerExperience = tonumber(GetUnitXP("player")) or 0
    TPM.killLogLastPlayerExperienceMax = tonumber(GetUnitXPMax("player")) or 0
    TPM.killLogLastPlayerLevel = tonumber(GetUnitLevel("player")) or 1

    local combatProgressXpNamespace = ADDON_NAME .. "CombatProgressXP"
    EVENT_MANAGER:RegisterForEvent(combatProgressXpNamespace, EVENT_EXPERIENCE_UPDATE,
        function(_, unitTag, currentExp, maxExp, reason)
            TPM:HandlePlayerExperienceUpdate(currentExp, maxExp, reason)
        end)
    EVENT_MANAGER:AddFilterForEvent(combatProgressXpNamespace, EVENT_EXPERIENCE_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")

    local combatProgressCpNamespace = ADDON_NAME .. "CombatProgressCP"
    EVENT_MANAGER:RegisterForEvent(combatProgressCpNamespace, EVENT_CHAMPION_POINT_UPDATE, function()
        if TPM.saved and TPM.saved.statisticsPage == "history" and TPM:GetStatisticsHistorySubPage() == 2 then
            TPM:RefreshCombatProgressionBars()
        end
    end)
    EVENT_MANAGER:AddFilterForEvent(combatProgressCpNamespace, EVENT_CHAMPION_POINT_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "CombatProgressCompanionXP", EVENT_COMPANION_EXPERIENCE_GAIN, function()
        if TPM.saved and TPM.saved.statisticsPage == "history" and TPM:GetStatisticsHistorySubPage() == 2 then TPM:RefreshCombatProgressionBars() end
    end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "CombatProgressCompanionOn", EVENT_COMPANION_ACTIVATED, function()
        if TPM.saved and TPM.saved.statisticsPage == "history" and TPM:GetStatisticsHistorySubPage() == 2 then TPM:RefreshCombatProgressionBars() end
    end)
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "CombatProgressCompanionOff", EVENT_COMPANION_DEACTIVATED, function()
        if TPM.saved and TPM.saved.statisticsPage == "history" and TPM:GetStatisticsHistorySubPage() == 2 then TPM:RefreshCombatProgressionBars() end
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME .. "ScreenResized", EVENT_SCREEN_RESIZED, function()
        if TPM.statisticsWindow then TPM:ClampStatisticsWindowToScreen() end
        if TPM.questRewardControl then TPM:ApplyQuestRewardPosition() end
        if TPM.skyshardGoalWidget then TPM:UpdateSkyshardGoalAnchor(true); TPM:RefreshSkyshardGoalWidget() end
    end)

    SLASH_COMMANDS["/nmc"] = function(text) TPM:HandleSlashCommand(text) end
    SLASH_COMMANDS["/tpm"] = function(text) TPM:HandleSlashCommand(text) end
    SLASH_COMMANDS["/nagamapacompleto"] = function(text) TPM:HandleSlashCommand(text) end
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    TPM:Initialize()
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)
