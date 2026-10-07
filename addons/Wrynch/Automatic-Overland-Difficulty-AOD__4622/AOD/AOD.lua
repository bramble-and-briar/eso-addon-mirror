local Addon = {}
local ADDON_NAME = "AOD"
local ADDON_DISPLAY_NAME = "Automatic Overland Difficulty"
local LAM_PANEL_NAME = "AutomaticOverlandDifficulty_LAM"
local ADDON_AUTHOR = "|cFFFF00Wrynch|r"
local ADDON_VERSION = "1.5.0"
local EVENT_NAMESPACE = ADDON_NAME
local SAVED_VARS_NAME = "AODifficulty_SavedVariables"
local SAVED_VARS_VERSION = 1

local NO_CHANGE = -1
local SAME_AS_WORLD_EVENTS = -2

local SITUATION_DELVES = "delves"
local SITUATION_PUBLIC_DUNGEONS = "publicDungeons"
local SITUATION_OLD_GROUP_DUNGEONS = "groupDungeons"
local SITUATION_OPEN_WORLD = "openWorld"
local SITUATION_HISTORY_BOSSES = "historyBosses"

local HISTORY_BOSS_TOOLTIP = "Experimental: applies when ESO identifies the current area as a Solo Instance or Zone Story and AOD detects a Hard/Deadly monster or an official boss unit. ESO does not expose a dedicated story boss flag, so some bosses may not be detected."
local RETICLE_OVER_UNIT_TAG = "reticleover"

local NEARBY_PIN_DRAGONS = "dragons"
local NEARBY_PIN_WORLD_BOSSES = "worldBosses"
local NEARBY_PIN_WORLD_EVENTS = "worldEvents"
local NEARBY_UPDATE_NAMESPACE = EVENT_NAMESPACE .. "_NearbyPins"
local NEARBY_UPDATE_INTERVAL_MS = 2000
local DIFFICULTY_RETRY_UPDATE_NAMESPACE = EVENT_NAMESPACE .. "_DifficultyRetry"
local LEVELING_JOURNEY_MAP_UPDATE_NAMESPACE = EVENT_NAMESPACE .. "_LevelingJourneyMap"
local LEVELING_JOURNEY_MAP_UPDATE_INTERVAL_MS = 200
local LEVELING_JOURNEY_BASE_MAX_LEVEL = 50
local DIFFICULTY_REQUEST_COOLDOWN_MS = 6000
local DEFAULT_NEARBY_PIN_RADIUS_METERS = 120
local MIN_NEARBY_PIN_RADIUS_METERS = 25
local MAX_NEARBY_PIN_RADIUS_METERS = 300
local NEARBY_PIN_RADIUS_STEP_METERS = 5
local POI_DIAGNOSTIC_COMMAND = "/aodpoi"

local POI_PIN_RADIUS_BYPASS_ACTIVITY_IDS =
{
    -- These POIs use ESO's current-area signal because their map pin does not mark the encounter.
    -- See POI_EXCEPTIONS.md for the capture and verification procedure.
    2292, -- Four Skull Lookout
}

local ANNOUNCEMENT_CHAT = "chat"

local LEVELING_JOURNEY_MAX_LEVEL_CHOICES =
{
    "50",
    "CP 160",
    "CP 300",
    "CP 600",
    "CP 900",
    "CP 1400",
    "CP 1800",
    "CP 2400",
    "CP 3600",
}

local LEVELING_JOURNEY_MAX_LEVEL_VALUES =
{
    50,
    160,
    300,
    600,
    900,
    1400,
    1800,
    2400,
    3600,
}

local VALID_LEVELING_JOURNEY_MAX_LEVELS = {}
for index = 1, #LEVELING_JOURNEY_MAX_LEVEL_VALUES do
    VALID_LEVELING_JOURNEY_MAX_LEVELS[LEVELING_JOURNEY_MAX_LEVEL_VALUES[index]] = true
end

local LEVELING_JOURNEY_CHAT_ICONS =
{
    [OVERLAND_DIFFICULTY_TYPE_BASEGAME] = "EsoUI/Art/ChallengeDifficulty/Gamepad/gp_challengeDifficulty_basegame.dds",
    [OVERLAND_DIFFICULTY_TYPE_JOURNEYMAN] = "EsoUI/Art/ChallengeDifficulty/Gamepad/gp_challengeDifficulty_journeyman.dds",
    [OVERLAND_DIFFICULTY_TYPE_ADVENTURER] = "EsoUI/Art/ChallengeDifficulty/Gamepad/gp_challengeDifficulty_adventurer.dds",
    [OVERLAND_DIFFICULTY_TYPE_VETERAN] = "EsoUI/Art/ChallengeDifficulty/Gamepad/gp_challengeDifficulty_veteran.dds",
}

local LEVELING_JOURNEY_CHAT_COLORS =
{
    [OVERLAND_DIFFICULTY_TYPE_BASEGAME] = "66CC66",
    [OVERLAND_DIFFICULTY_TYPE_JOURNEYMAN] = "E6D35C",
    [OVERLAND_DIFFICULTY_TYPE_ADVENTURER] = "E68A3A",
    [OVERLAND_DIFFICULTY_TYPE_VETERAN] = "E85A5A",
}

local LEVELING_JOURNEY_ZONE_LEVELS =
{
    [280] = 3,  -- Bleakrock Isle
    [534] = 3,  -- Stros M'Kai
    [281] = 5,  -- Bal Foyen
    [535] = 5,  -- Betnikh
    [537] = 5,  -- Khenarthi's Roost
    [41] = 10,  -- Stonefalls
    [3] = 10,   -- Glenumbra
    [381] = 10, -- Auridon
    [57] = 20,  -- Deshaan
    [19] = 20,  -- Stormhaven
    [383] = 20, -- Grahtwood
    [117] = 28, -- Shadowfen
    [20] = 28,  -- Rivenspire
    [108] = 28, -- Greenshade
    [101] = 35, -- Eastmarch
    [104] = 35, -- Alik'r Desert
    [58] = 35,  -- Malabal Tor
    [103] = 43, -- The Rift
    [92] = 43,  -- Bangkorai
    [382] = 43, -- Reaper's March
    [347] = 48, -- Coldharbour
    [888] = 50, -- Craglorn
    [816] = 25, -- Hew's Bane
    [726] = 30, -- Murkmire
    [823] = 35, -- Gold Coast
    [684] = 45, -- Wrothgar
    [849] = 15, -- Vvardenfell
    [980] = 32, -- Clockwork City
    [1011] = 45, -- Summerset
    [1086] = 15, -- Northern Elsweyr
    [1133] = 40, -- Southern Elsweyr
    [1160] = 15, -- Western Skyrim
    [1207] = 40, -- The Reach
    [1261] = 15, -- Blackwood
    [1286] = 40, -- The Deadlands
    [1318] = 15, -- High Isle
    [1383] = 40, -- Galen
    [1414] = 25, -- Telvanni Peninsula
    [1413] = 25, -- Apocrypha
    [1443] = 40, -- West Weald
    [1502] = 50, -- Solstice
}

local LEVELING_JOURNEY_ZONE_DISPLAY_TYPES =
{
    [ZONE_DISPLAY_TYPE_NONE] = true,
    [ZONE_DISPLAY_TYPE_DELVE] = true,
    [ZONE_DISPLAY_TYPE_GROUP_DELVE] = true,
    [ZONE_DISPLAY_TYPE_PUBLIC_DUNGEON] = true,
    [ZONE_DISPLAY_TYPE_SOLO] = true,
    [ZONE_DISPLAY_TYPE_ZONE_STORY] = true,
}

local NEARBY_PIN_SETTINGS =
{
    {
        key = NEARBY_PIN_WORLD_BOSSES,
        name = "World Bosses",
        zoneCompletionType = ZONE_COMPLETION_TYPE_GROUP_BOSSES,
    },
    {
        key = NEARBY_PIN_WORLD_EVENTS,
        name = "World Events",
        zoneCompletionType = ZONE_COMPLETION_TYPE_WORLD_EVENTS,
    },
    {
        key = NEARBY_PIN_DRAGONS,
        name = "Dragons",
    },
}

local SETTINGS_DEFAULTS =
{
    enabled = true,
    debugEnabled = false,
    levelingJourney =
    {
        enabled = false,
        maxLevel = LEVELING_JOURNEY_BASE_MAX_LEVEL,
        adaptiveMaxLevel = false,
        chatMessages = true,
        showMapLevel = true,
    },
    historyBossesExperimentalEnabled = false,
    situations =
    {
        [SITUATION_DELVES] = NO_CHANGE,
        [SITUATION_PUBLIC_DUNGEONS] = NO_CHANGE,
        [SITUATION_OPEN_WORLD] = NO_CHANGE,
        [SITUATION_HISTORY_BOSSES] = NO_CHANGE,
    },
    regions =
    {
        ["*"] = NO_CHANGE,
    },
    nearbyPins =
    {
        [NEARBY_PIN_DRAGONS] = SAME_AS_WORLD_EVENTS,
        [NEARBY_PIN_WORLD_BOSSES] = NO_CHANGE,
        [NEARBY_PIN_WORLD_EVENTS] = NO_CHANGE,
    },
    nearbyPinRadiusMeters = DEFAULT_NEARBY_PIN_RADIUS_METERS,
    announcements =
    {
        [ANNOUNCEMENT_CHAT] = false,
    },
    migrations =
    {
        publicDungeonsFromGroupDungeons = false,
    },
}

local SCOPE_DEFAULTS =
{
    accountBoundSettings = true,
}

local SITUATION_BY_ZONE_DISPLAY_TYPE =
{
    [ZONE_DISPLAY_TYPE_DELVE] = SITUATION_DELVES,
    [ZONE_DISPLAY_TYPE_GROUP_DELVE] = SITUATION_DELVES,
    [ZONE_DISPLAY_TYPE_PUBLIC_DUNGEON] = SITUATION_PUBLIC_DUNGEONS,
    [ZONE_DISPLAY_TYPE_NONE] = SITUATION_OPEN_WORLD,
}

local VALID_DIFFICULTIES =
{
    [OVERLAND_DIFFICULTY_TYPE_BASEGAME] = true,
    [OVERLAND_DIFFICULTY_TYPE_JOURNEYMAN] = true,
    [OVERLAND_DIFFICULTY_TYPE_ADVENTURER] = true,
    [OVERLAND_DIFFICULTY_TYPE_VETERAN] = true,
}

local function IsValidDifficulty(value)
    return value == NO_CHANGE or VALID_DIFFICULTIES[value] == true
end

local function NormalizeDifficulty(value)
    if IsValidDifficulty(value) then
        return value
    end
    return NO_CHANGE
end

local function NormalizeNearbyPinDifficulty(nearbyPin, value)
    if nearbyPin == NEARBY_PIN_DRAGONS then
        if VALID_DIFFICULTIES[value] then
            return value
        end
        return SAME_AS_WORLD_EVENTS
    end

    return NormalizeDifficulty(value)
end

local function NormalizeNearbyPinRadiusMeters(value)
    local radiusMeters = tonumber(value)
    if not radiusMeters then
        return DEFAULT_NEARBY_PIN_RADIUS_METERS
    end

    if radiusMeters < MIN_NEARBY_PIN_RADIUS_METERS then
        radiusMeters = MIN_NEARBY_PIN_RADIUS_METERS
    elseif radiusMeters > MAX_NEARBY_PIN_RADIUS_METERS then
        radiusMeters = MAX_NEARBY_PIN_RADIUS_METERS
    end

    return math.floor((radiusMeters / NEARBY_PIN_RADIUS_STEP_METERS) + 0.5) * NEARBY_PIN_RADIUS_STEP_METERS
end

local function NormalizeLevelingJourneyMaxLevel(value)
    local maxLevel = tonumber(value)
    if VALID_LEVELING_JOURNEY_MAX_LEVELS[maxLevel] then
        return maxLevel
    end
    return LEVELING_JOURNEY_BASE_MAX_LEVEL
end

local function BuildDifficultyChoices()
    local choices =
    {
        "Do not change",
        GetString("SI_OVERLANDDIFFICULTYTYPE", OVERLAND_DIFFICULTY_TYPE_BASEGAME),
        GetString("SI_OVERLANDDIFFICULTYTYPE", OVERLAND_DIFFICULTY_TYPE_JOURNEYMAN),
        GetString("SI_OVERLANDDIFFICULTYTYPE", OVERLAND_DIFFICULTY_TYPE_ADVENTURER),
        GetString("SI_OVERLANDDIFFICULTYTYPE", OVERLAND_DIFFICULTY_TYPE_VETERAN),
    }

    local values =
    {
        NO_CHANGE,
        OVERLAND_DIFFICULTY_TYPE_BASEGAME,
        OVERLAND_DIFFICULTY_TYPE_JOURNEYMAN,
        OVERLAND_DIFFICULTY_TYPE_ADVENTURER,
        OVERLAND_DIFFICULTY_TYPE_VETERAN,
    }

    return choices, values
end

local function BuildDragonDifficultyChoices()
    local choices =
    {
        "Same as World Events",
        GetString("SI_OVERLANDDIFFICULTYTYPE", OVERLAND_DIFFICULTY_TYPE_BASEGAME),
        GetString("SI_OVERLANDDIFFICULTYTYPE", OVERLAND_DIFFICULTY_TYPE_JOURNEYMAN),
        GetString("SI_OVERLANDDIFFICULTYTYPE", OVERLAND_DIFFICULTY_TYPE_ADVENTURER),
        GetString("SI_OVERLANDDIFFICULTYTYPE", OVERLAND_DIFFICULTY_TYPE_VETERAN),
    }

    local values =
    {
        SAME_AS_WORLD_EVENTS,
        OVERLAND_DIFFICULTY_TYPE_BASEGAME,
        OVERLAND_DIFFICULTY_TYPE_JOURNEYMAN,
        OVERLAND_DIFFICULTY_TYPE_ADVENTURER,
        OVERLAND_DIFFICULTY_TYPE_VETERAN,
    }

    return choices, values
end

local function GetProfileName()
    return GetWorldName()
end

local function GetDifficultyName(difficulty)
    return GetString("SI_OVERLANDDIFFICULTYTYPE", difficulty)
end

function Addon.BuildLevelingJourneyZoneLevels()
    local validatedZoneLevels = {}
    local regionId = GetNextZoneStoryZoneId(nil)

    while regionId do
        local targetLevel = LEVELING_JOURNEY_ZONE_LEVELS[regionId]
        if targetLevel then
            validatedZoneLevels[regionId] = targetLevel
        end
        regionId = GetNextZoneStoryZoneId(regionId)
    end

    Addon.levelingJourneyZoneLevels = validatedZoneLevels
end

function Addon.IsLevelingJourneyEnabled()
    local savedVars = Addon.savedVars
    return savedVars
        and type(savedVars.levelingJourney) == "table"
        and savedVars.levelingJourney.enabled == true
end

function Addon.IsLevelingJourneyChatMessagesEnabled()
    local savedVars = Addon.savedVars
    return savedVars
        and type(savedVars.levelingJourney) == "table"
        and savedVars.levelingJourney.chatMessages ~= false
end

function Addon.IsLevelingJourneyMapLevelEnabled()
    local savedVars = Addon.savedVars
    return savedVars
        and type(savedVars.levelingJourney) == "table"
        and savedVars.levelingJourney.showMapLevel ~= false
end

function Addon.IsLevelingJourneyAdaptiveMaxLevelEnabled()
    local savedVars = Addon.savedVars
    return savedVars
        and type(savedVars.levelingJourney) == "table"
        and savedVars.levelingJourney.adaptiveMaxLevel == true
end

function Addon.GetLevelingJourneyAdaptiveMaxLevel()
    if (GetUnitLevel("player") or 1) < LEVELING_JOURNEY_BASE_MAX_LEVEL then
        return LEVELING_JOURNEY_BASE_MAX_LEVEL
    end

    local championPoints = math.max(GetPlayerChampionPointsEarned() or 0, 0)
    for index = 2, #LEVELING_JOURNEY_MAX_LEVEL_VALUES do
        local maxLevel = LEVELING_JOURNEY_MAX_LEVEL_VALUES[index]
        if championPoints < maxLevel then
            return maxLevel
        end
    end
    return LEVELING_JOURNEY_MAX_LEVEL_VALUES[#LEVELING_JOURNEY_MAX_LEVEL_VALUES]
end

function Addon.GetLevelingJourneyMaxLevel()
    local savedVars = Addon.savedVars
    if not savedVars or type(savedVars.levelingJourney) ~= "table" then
        return LEVELING_JOURNEY_BASE_MAX_LEVEL
    end
    if Addon.IsLevelingJourneyAdaptiveMaxLevelEnabled() then
        return Addon.GetLevelingJourneyAdaptiveMaxLevel()
    end
    return NormalizeLevelingJourneyMaxLevel(savedVars.levelingJourney.maxLevel)
end

function Addon.SetLevelingJourneyEnabled(enabled)
    enabled = enabled == true
    if Addon.savedVars.levelingJourney.enabled ~= enabled then
        Addon.savedVars.levelingJourney.enabled = enabled
    end

    Addon.lastLevelingJourneyRegionId = nil
    Addon.pendingLevelingJourneyAnnouncement = nil
    Addon.historyBossActive = false
    Addon.historyBossRestoreDifficulty = nil

    if enabled then
        Addon.RefreshLevelingJourneyRegionState()
    end

    Addon.RefreshNearbyUpdateRegistration()
    Addon.RefreshHistoryBossEventRegistration()
    Addon.RefreshLevelingJourneyEventRegistration()
    Addon.RefreshWorldMapLevelUpdateRegistration()
    Addon.ApplyCurrentSituation()
end

function Addon.SetLevelingJourneyChatMessagesEnabled(enabled)
    Addon.savedVars.levelingJourney.chatMessages = enabled == true
    if not enabled then
        Addon.pendingLevelingJourneyAnnouncement = nil
    end
end

function Addon.SetLevelingJourneyMapLevelEnabled(enabled)
    Addon.savedVars.levelingJourney.showMapLevel = enabled == true
    Addon.RefreshWorldMapLevelUpdateRegistration()
end

function Addon.SetLevelingJourneyAdaptiveMaxLevelEnabled(enabled)
    enabled = enabled == true
    if Addon.savedVars.levelingJourney.adaptiveMaxLevel == enabled then
        return
    end

    Addon.savedVars.levelingJourney.adaptiveMaxLevel = enabled
    Addon.pendingLevelingJourneyAnnouncement = nil
    Addon.worldMapDisplayedTargetText = nil
    Addon.RefreshLevelingJourneyEventRegistration()
    Addon.ApplyCurrentSituation()
end

function Addon.SetLevelingJourneyMaxLevel(maxLevel)
    maxLevel = NormalizeLevelingJourneyMaxLevel(maxLevel)
    if Addon.savedVars.levelingJourney.maxLevel == maxLevel then
        return
    end

    Addon.savedVars.levelingJourney.maxLevel = maxLevel
    Addon.pendingLevelingJourneyAnnouncement = nil
    Addon.worldMapDisplayedTargetText = nil
    Addon.RefreshLevelingJourneyEventRegistration()
    Addon.ApplyCurrentSituation()
end

function Addon.GetLevelingJourneyTargetProgression(regionId)
    if not regionId or not Addon.levelingJourneyZoneLevels then
        return nil
    end

    local baseTargetLevel = Addon.levelingJourneyZoneLevels[regionId]
    if not baseTargetLevel then
        return nil
    end

    local maxLevel = Addon.GetLevelingJourneyMaxLevel()
    if maxLevel == LEVELING_JOURNEY_BASE_MAX_LEVEL then
        return baseTargetLevel, nil, baseTargetLevel
    end

    local targetChampionPoints = math.floor(((baseTargetLevel * maxLevel) / LEVELING_JOURNEY_BASE_MAX_LEVEL) + 0.5)
    return LEVELING_JOURNEY_BASE_MAX_LEVEL, targetChampionPoints, baseTargetLevel
end

function Addon.GetLevelingJourneyPlayerProgress()
    local maxLevel = Addon.GetLevelingJourneyMaxLevel()
    if maxLevel == LEVELING_JOURNEY_BASE_MAX_LEVEL then
        return GetUnitLevel("player")
    end

    local championPoints = math.max(GetPlayerChampionPointsEarned() or 0, 0)
    return (championPoints * LEVELING_JOURNEY_BASE_MAX_LEVEL) / maxLevel
end

function Addon.GetLevelingJourneyTargetText(targetLevel, targetChampionPoints)
    if targetChampionPoints then
        return string.format("CP %d", targetChampionPoints)
    end
    return string.format("Level %d", targetLevel)
end

function Addon.GetLevelingJourneyDifficulty(targetLevel, playerLevel)
    if not targetLevel or not playerLevel then
        return NO_CHANGE
    end

    local levelGap = targetLevel - playerLevel
    if levelGap <= 0 then
        return OVERLAND_DIFFICULTY_TYPE_BASEGAME
    elseif levelGap <= 4 then
        return OVERLAND_DIFFICULTY_TYPE_JOURNEYMAN
    elseif levelGap <= 9 then
        return OVERLAND_DIFFICULTY_TYPE_ADVENTURER
    end
    return OVERLAND_DIFFICULTY_TYPE_VETERAN
end

function Addon.IsLevelingJourneyContext()
    local zoneDisplayType = Addon.currentZoneDisplayType or ZONE_DISPLAY_TYPE_NONE
    return LEVELING_JOURNEY_ZONE_DISPLAY_TYPES[zoneDisplayType] == true
end

function Addon.GetSituationSettings(situation)
    local savedVars = Addon.savedVars
    if not savedVars or not savedVars.situations then
        return NO_CHANGE
    end
    return NormalizeDifficulty(savedVars.situations[situation])
end

function Addon.IsHistoryBossExperimentalEnabled()
    return Addon.savedVars and Addon.savedVars.historyBossesExperimentalEnabled == true
end

function Addon.SetHistoryBossExperimentalEnabled(enabled)
    enabled = enabled == true
    if Addon.savedVars.historyBossesExperimentalEnabled ~= enabled then
        Addon.savedVars.historyBossesExperimentalEnabled = enabled
    end

    Addon.RefreshHistoryBossEventRegistration()
    Addon.ApplyCurrentSituation()
end

function Addon.SetSituationSettings(situation, difficulty)
    difficulty = NormalizeDifficulty(difficulty)
    if Addon.savedVars.situations[situation] ~= difficulty then
        Addon.savedVars.situations[situation] = difficulty
    end
    Addon.ApplyCurrentSituation()
end

function Addon.SetHistoryBossSettings(difficulty)
    difficulty = NormalizeDifficulty(difficulty)
    if Addon.savedVars.situations[SITUATION_HISTORY_BOSSES] ~= difficulty then
        Addon.savedVars.situations[SITUATION_HISTORY_BOSSES] = difficulty
    end

    Addon.RefreshHistoryBossEventRegistration()
    Addon.ApplyCurrentSituation()
end

function Addon.GetRegionSettings(regionId)
    local savedVars = Addon.savedVars
    if not savedVars or regionId == nil or type(savedVars.regions) ~= "table" then
        return NO_CHANGE
    end
    return NormalizeDifficulty(savedVars.regions[regionId])
end

function Addon.SetRegionSettings(regionId, difficulty)
    if regionId == nil then
        return
    end

    difficulty = NormalizeDifficulty(difficulty)
    if type(Addon.savedVars.regions) ~= "table" then
        Addon.savedVars.regions = {}
    end

    if difficulty == NO_CHANGE then
        if rawget(Addon.savedVars.regions, regionId) ~= nil then
            Addon.savedVars.regions[regionId] = nil
        end
    elseif Addon.savedVars.regions[regionId] ~= difficulty then
        Addon.savedVars.regions[regionId] = difficulty
    end

    Addon.ApplyCurrentSituation()
end

function Addon.ResetRegionSettings()
    if type(Addon.savedVars.regions) ~= "table" then
        Addon.savedVars.regions = {}
    else
        for regionId in pairs(Addon.savedVars.regions) do
            Addon.savedVars.regions[regionId] = nil
        end
    end

    Addon.ApplyCurrentSituation()
end

function Addon.GetNearbyPinSettings(nearbyPin)
    local savedVars = Addon.savedVars
    if not savedVars or type(savedVars.nearbyPins) ~= "table" then
        if nearbyPin == NEARBY_PIN_DRAGONS then
            return SAME_AS_WORLD_EVENTS
        end
        return NO_CHANGE
    end

    local value = savedVars.nearbyPins[nearbyPin]
    if nearbyPin == NEARBY_PIN_DRAGONS and value == nil then
        return SAME_AS_WORLD_EVENTS
    end

    return NormalizeNearbyPinDifficulty(nearbyPin, value)
end

function Addon.SetNearbyPinSettings(nearbyPin, difficulty)
    difficulty = NormalizeNearbyPinDifficulty(nearbyPin, difficulty)
    if type(Addon.savedVars.nearbyPins) ~= "table" then
        Addon.savedVars.nearbyPins = {}
    end

    if difficulty == NO_CHANGE and nearbyPin ~= NEARBY_PIN_DRAGONS then
        if rawget(Addon.savedVars.nearbyPins, nearbyPin) ~= nil then
            Addon.savedVars.nearbyPins[nearbyPin] = nil
        end
    elseif Addon.savedVars.nearbyPins[nearbyPin] ~= difficulty then
        Addon.savedVars.nearbyPins[nearbyPin] = difficulty
    end

    Addon.RefreshNearbyUpdateRegistration()
    Addon.ApplyCurrentSituation()
end

function Addon.GetEffectiveDragonSettings()
    local dragonDifficulty = Addon.GetNearbyPinSettings(NEARBY_PIN_DRAGONS)
    if dragonDifficulty == SAME_AS_WORLD_EVENTS then
        return Addon.GetNearbyPinSettings(NEARBY_PIN_WORLD_EVENTS)
    end
    return dragonDifficulty
end

function Addon.HasNearbyPinSettings()
    if not Addon.savedVars or type(Addon.savedVars.nearbyPins) ~= "table" then
        return false
    end

    for index = 1, #NEARBY_PIN_SETTINGS do
        local nearbyPin = NEARBY_PIN_SETTINGS[index].key
        if nearbyPin == NEARBY_PIN_DRAGONS then
            if Addon.GetEffectiveDragonSettings() ~= NO_CHANGE then
                return true
            end
        elseif Addon.GetNearbyPinSettings(nearbyPin) ~= NO_CHANGE then
            return true
        end
    end

    return false
end

function Addon.GetNearbyPinRadiusMeters()
    local savedVars = Addon.savedVars
    if not savedVars then
        return DEFAULT_NEARBY_PIN_RADIUS_METERS
    end
    return NormalizeNearbyPinRadiusMeters(savedVars.nearbyPinRadiusMeters)
end

function Addon.GetPlayerPositionForNearbyCheck()
    local gps = LibGPS3
    if not gps or not gps.GetCurrentMapMeasurement or not gps.GetLocalDistanceInMeters then
        return nil
    end

    if not DoesCurrentMapMatchMapForPlayerLocation() then
        return nil
    end

    if not gps:GetCurrentMapMeasurement() then
        return nil
    end

    local playerX, playerY, _, isPlayerShownInCurrentMap, isSymbolicLocation = GetMapPlayerPosition("player")
    if not playerX or not playerY or not isPlayerShownInCurrentMap or isSymbolicLocation then
        return nil
    end

    return gps, playerX, playerY
end

function Addon.SetNearbyPinRadiusMeters(radiusMeters)
    if not Addon.savedVars then
        return
    end

    radiusMeters = NormalizeNearbyPinRadiusMeters(radiusMeters)
    if Addon.savedVars.nearbyPinRadiusMeters ~= radiusMeters then
        Addon.savedVars.nearbyPinRadiusMeters = radiusMeters
    end
    Addon.ApplyCurrentSituation()
end

function Addon.GetAnnouncementSettings(announcementType)
    local savedVars = Addon.savedVars
    if not savedVars or type(savedVars.announcements) ~= "table" then
        return false
    end
    return savedVars.announcements[announcementType] == true
end

function Addon.SetAnnouncementSettings(announcementType, enabled)
    if type(Addon.savedVars.announcements) ~= "table" then
        Addon.savedVars.announcements = {}
    end

    Addon.savedVars.announcements[announcementType] = enabled == true
end

function Addon.GetPlayerRegionId()
    local zoneIndex = GetUnitZoneIndex("player")
    if not zoneIndex then
        return nil
    end

    local zoneId = GetZoneId(zoneIndex)
    local regionId = GetZoneStoryZoneIdForZoneId(zoneId)
    if regionId == 0 then
        return nil
    end

    return regionId
end

function Addon.IsDebugEnabled()
    return Addon.savedVars and Addon.savedVars.debugEnabled == true
end

function Addon.SetDebugEnabled(enabled)
    enabled = enabled == true
    if Addon.savedVars.debugEnabled ~= enabled then
        Addon.savedVars.debugEnabled = enabled
    end
    Addon.RefreshPOIDiagnosticCommandRegistration()
end

function Addon.GetZoneStoryActivityIdForPOI(zoneIndex, poiIndex, zoneCompletionType)
    local zoneId = GetZoneId(zoneIndex)
    local zoneStoryZoneId = GetZoneStoryZoneIdForZoneId(zoneId)
    if zoneStoryZoneId == 0 then
        return nil, zoneId, nil
    end

    local numActivities = GetNumZoneActivitiesForZoneCompletionTypeAndIndex(zoneStoryZoneId, zoneCompletionType, nil)
    for activityIndex = 1, numActivities do
        local activityId = GetZoneActivityIdForZoneCompletionType(zoneStoryZoneId, zoneCompletionType, activityIndex)
        local activityZoneIndex, activityPOIIndex = GetPOIIndices(activityId)
        if activityZoneIndex == zoneIndex and activityPOIIndex == poiIndex then
            return activityId, zoneId, zoneStoryZoneId
        end
    end

    return nil, zoneId, zoneStoryZoneId
end

function Addon.BuildPOIDiagnosticData(zoneIndex, poiIndex, gps, playerX, playerY)
    if not zoneIndex or not poiIndex then
        return nil
    end

    local name = GetPOIInfo(zoneIndex, poiIndex)
    local zoneCompletionType = GetPOIZoneCompletionType(zoneIndex, poiIndex)
    local activityId, zoneId, zoneStoryZoneId = Addon.GetZoneStoryActivityIdForPOI(
        zoneIndex,
        poiIndex,
        zoneCompletionType
    )
    local poiX, poiY, _, _, isShownInCurrentMap = GetPOIMapInfo(zoneIndex, poiIndex)
    local distanceMeters
    if gps and poiX and poiY and isShownInCurrentMap then
        distanceMeters = gps:GetLocalDistanceInMeters(playerX, playerY, poiX, poiY)
    end

    return
    {
        zoneIndex = zoneIndex,
        poiIndex = poiIndex,
        zoneId = zoneId,
        zoneStoryZoneId = zoneStoryZoneId,
        activityId = activityId,
        zoneCompletionType = zoneCompletionType,
        name = name,
        poiX = poiX,
        poiY = poiY,
        isShownInCurrentMap = isShownInCurrentMap,
        distanceMeters = distanceMeters,
    }
end

function Addon.GetNearestWorldBossPOIDiagnostic(gps, playerX, playerY)
    if not gps then
        return nil
    end

    local zoneIndex = GetCurrentMapZoneIndex()
    if not zoneIndex then
        return nil
    end

    local nearestData
    local numPOIs = GetNumPOIs(zoneIndex)
    for poiIndex = 1, numPOIs do
        if GetPOIZoneCompletionType(zoneIndex, poiIndex) == ZONE_COMPLETION_TYPE_GROUP_BOSSES then
            local data = Addon.BuildPOIDiagnosticData(zoneIndex, poiIndex, gps, playerX, playerY)
            if data.distanceMeters
                and (not nearestData or data.distanceMeters < nearestData.distanceMeters) then
                nearestData = data
            end
        end
    end

    return nearestData
end

function Addon.OutputPOIDiagnosticData(label, data)
    if not data then
        CHAT_ROUTER:AddSystemMessage(string.format("AOD POI: %s=none", label))
        return
    end

    CHAT_ROUTER:AddSystemMessage(string.format(
        "AOD POI: %s name=%s zoneId=%s storyZoneId=%s zoneIndex=%s poiIndex=%s activityId=%s completionType=%s",
        label,
        tostring(data.name),
        tostring(data.zoneId),
        tostring(data.zoneStoryZoneId),
        tostring(data.zoneIndex),
        tostring(data.poiIndex),
        tostring(data.activityId),
        tostring(data.zoneCompletionType)
    ))
    CHAT_ROUTER:AddSystemMessage(string.format(
        "AOD POI: %s pin=(%s,%s) shown=%s distanceMeters=%s",
        label,
        tostring(data.poiX),
        tostring(data.poiY),
        tostring(data.isShownInCurrentMap),
        data.distanceMeters and string.format("%.2f", data.distanceMeters) or "nil"
    ))
end

function Addon.ReportPOIDiagnostic()
    local gps, playerX, playerY = Addon.GetPlayerPositionForNearbyCheck()
    CHAT_ROUTER:AddSystemMessage(string.format(
        "AOD POI: mapMatchesPlayer=%s player=(%s,%s) gpsMeasurement=%s configuredRadius=%s",
        tostring(DoesCurrentMapMatchMapForPlayerLocation()),
        tostring(playerX),
        tostring(playerY),
        tostring(gps ~= nil),
        tostring(Addon.GetNearbyPinRadiusMeters())
    ))

    local currentZoneIndex, currentPOIIndex = GetCurrentSubZonePOIIndices()
    local currentData = Addon.BuildPOIDiagnosticData(currentZoneIndex, currentPOIIndex, gps, playerX, playerY)
    Addon.OutputPOIDiagnosticData("current", currentData)

    local nearestWorldBossData = Addon.GetNearestWorldBossPOIDiagnostic(gps, playerX, playerY)
    Addon.OutputPOIDiagnosticData("nearestWorldBoss", nearestWorldBossData)
end

function Addon.RefreshPOIDiagnosticCommandRegistration()
    local shouldRegister = Addon.IsDebugEnabled()
    if shouldRegister and not Addon.poiDiagnosticCommandRegistered then
        if not Addon.poiDiagnosticCommandHandler then
            Addon.poiDiagnosticCommandHandler = function()
                Addon.ReportPOIDiagnostic()
            end
        end

        local registeredHandler = SLASH_COMMANDS[POI_DIAGNOSTIC_COMMAND]
        if registeredHandler and registeredHandler ~= Addon.poiDiagnosticCommandHandler then
            if CHAT_ROUTER then
                CHAT_ROUTER:AddSystemMessage(
                    "AOD Debug: /aodpoi is already registered by another addon and was not replaced."
                )
            end
            return
        end

        SLASH_COMMANDS[POI_DIAGNOSTIC_COMMAND] = Addon.poiDiagnosticCommandHandler
        Addon.poiDiagnosticCommandRegistered = true
    elseif not shouldRegister and Addon.poiDiagnosticCommandRegistered then
        if SLASH_COMMANDS[POI_DIAGNOSTIC_COMMAND] == Addon.poiDiagnosticCommandHandler then
            SLASH_COMMANDS[POI_DIAGNOSTIC_COMMAND] = nil
        end
        Addon.poiDiagnosticCommandRegistered = false
    end
end

function Addon.BuildPOIPinRadiusBypassLookup()
    local lookup = {}
    for index = 1, #POI_PIN_RADIUS_BYPASS_ACTIVITY_IDS do
        local zoneIndex, poiIndex = GetPOIIndices(POI_PIN_RADIUS_BYPASS_ACTIVITY_IDS[index])
        if zoneIndex and poiIndex then
            local zoneLookup = lookup[zoneIndex]
            if not zoneLookup then
                zoneLookup = {}
                lookup[zoneIndex] = zoneLookup
            end
            zoneLookup[poiIndex] = true
        end
    end

    Addon.poiPinRadiusBypassLookup = lookup
end

function Addon.ShouldBypassPOIPinRadius(zoneIndex, poiIndex)
    local zoneLookup = Addon.poiPinRadiusBypassLookup
        and Addon.poiPinRadiusBypassLookup[zoneIndex]
    return zoneLookup and zoneLookup[poiIndex] == true
end

function Addon.IsCurrentPOIWithinRadius(zoneIndex, poiIndex)
    if Addon.ShouldBypassPOIPinRadius(zoneIndex, poiIndex) then
        return true
    end

    local gps, playerX, playerY = Addon.GetPlayerPositionForNearbyCheck()
    if not gps then
        return false
    end

    return Addon.IsPOIWithinRadius(zoneIndex, poiIndex, gps, playerX, playerY)
end

function Addon.IsPOIWithinRadius(zoneIndex, poiIndex, gps, playerX, playerY)
    if Addon.ShouldBypassPOIPinRadius(zoneIndex, poiIndex) then
        return false
    end

    local poiX, poiY, _, _, isPOIShownInCurrentMap = GetPOIMapInfo(zoneIndex, poiIndex)
    if not poiX or not poiY or not isPOIShownInCurrentMap then
        return false
    end

    return gps:GetLocalDistanceInMeters(playerX, playerY, poiX, poiY) <= Addon.GetNearbyPinRadiusMeters()
end

function Addon.IsCurrentWorldEventUnitWithinRadius(worldEventInstanceId, unitTag)
    local gps, playerX, playerY = Addon.GetPlayerPositionForNearbyCheck()
    if not gps then
        return false
    end

    local unitX, unitY, _, isUnitShownInCurrentMap, isSymbolicLocation = GetMapPlayerPosition(unitTag)
    if not unitX or not unitY or not isUnitShownInCurrentMap or isSymbolicLocation then
        return false
    end

    local pinType = GetWorldEventInstanceUnitPinType(worldEventInstanceId, unitTag)
    if pinType == MAP_PIN_TYPE_INVALID then
        return false
    end

    return gps:GetLocalDistanceInMeters(playerX, playerY, unitX, unitY) <= Addon.GetNearbyPinRadiusMeters()
end

function Addon.GetNearbyDragonDifficulty()
    local dragonDifficulty = Addon.GetEffectiveDragonSettings()
    if dragonDifficulty == NO_CHANGE and Addon.GetNearbyPinSettings(NEARBY_PIN_DRAGONS) == SAME_AS_WORLD_EVENTS then
        return nil
    end

    local worldEventInstanceId = GetNextWorldEventInstanceId(nil)
    while worldEventInstanceId do
        if GetWorldEventLocationContext(worldEventInstanceId) == WORLD_EVENT_LOCATION_CONTEXT_UNIT then
            local numUnits = GetNumWorldEventInstanceUnits(worldEventInstanceId)
            for unitIndex = 1, numUnits do
                local unitTag = GetWorldEventInstanceUnitTag(worldEventInstanceId, unitIndex)
                if unitTag and Addon.IsCurrentWorldEventUnitWithinRadius(worldEventInstanceId, unitTag) then
                    return dragonDifficulty
                end
            end
        end

        worldEventInstanceId = GetNextWorldEventInstanceId(worldEventInstanceId)
    end

    return nil
end

function Addon.GetNearbyPinDifficulty()
    if not Addon.HasNearbyPinSettings() then
        return NO_CHANGE
    end

    local dragonDifficulty = Addon.GetNearbyDragonDifficulty()
    if dragonDifficulty ~= nil then
        return dragonDifficulty
    end

    local zoneIndex, poiIndex = GetCurrentSubZonePOIIndices()
    if not zoneIndex or not poiIndex then
        return Addon.GetNearbyMapPOIDifficulty()
    end

    local zoneCompletionType = GetPOIZoneCompletionType(zoneIndex, poiIndex)
    for settingsIndex = 1, #NEARBY_PIN_SETTINGS do
        local pinSettings = NEARBY_PIN_SETTINGS[settingsIndex]
        if pinSettings.zoneCompletionType and zoneCompletionType == pinSettings.zoneCompletionType and Addon.IsCurrentPOIWithinRadius(zoneIndex, poiIndex) then
            local difficulty = Addon.GetNearbyPinSettings(pinSettings.key)
            if difficulty ~= NO_CHANGE then
                return difficulty
            end
        end
    end

    return NO_CHANGE
end

function Addon.GetNearbyMapPOIDifficulty()
    local gps, playerX, playerY = Addon.GetPlayerPositionForNearbyCheck()
    if not gps then
        return NO_CHANGE
    end

    local zoneIndex = GetCurrentMapZoneIndex()
    if not zoneIndex then
        return NO_CHANGE
    end

    local numPOIs = GetNumPOIs(zoneIndex)
    for settingsIndex = 1, #NEARBY_PIN_SETTINGS do
        local pinSettings = NEARBY_PIN_SETTINGS[settingsIndex]
        local difficulty = Addon.GetNearbyPinSettings(pinSettings.key)
        if pinSettings.zoneCompletionType and difficulty ~= NO_CHANGE then
            for poiIndex = 1, numPOIs do
                if GetPOIZoneCompletionType(zoneIndex, poiIndex) == pinSettings.zoneCompletionType
                    and Addon.IsPOIWithinRadius(zoneIndex, poiIndex, gps, playerX, playerY) then
                    return difficulty
                end
            end
        end
    end

    return NO_CHANGE
end

function Addon.IsNearbyWorldBoss()
    local zoneIndex, poiIndex = GetCurrentSubZonePOIIndices()
    if zoneIndex and poiIndex
        and GetPOIZoneCompletionType(zoneIndex, poiIndex) == ZONE_COMPLETION_TYPE_GROUP_BOSSES
        and Addon.IsCurrentPOIWithinRadius(zoneIndex, poiIndex) then
        return true
    end

    local gps, playerX, playerY = Addon.GetPlayerPositionForNearbyCheck()
    if not gps then
        return false
    end

    zoneIndex = GetCurrentMapZoneIndex()
    if not zoneIndex then
        return false
    end

    local numPOIs = GetNumPOIs(zoneIndex)
    for currentPOIIndex = 1, numPOIs do
        if GetPOIZoneCompletionType(zoneIndex, currentPOIIndex) == ZONE_COMPLETION_TYPE_GROUP_BOSSES
            and Addon.IsPOIWithinRadius(zoneIndex, currentPOIIndex, gps, playerX, playerY) then
            return true
        end
    end

    return false
end

function Addon.GetLevelingJourneyDesiredDifficulty()
    if not Addon.IsLevelingJourneyContext() then
        return NO_CHANGE
    end

    local regionId = Addon.GetPlayerRegionId()
    local targetLevel, targetChampionPoints, baseTargetLevel = Addon.GetLevelingJourneyTargetProgression(regionId)
    if not targetLevel then
        return NO_CHANGE
    end

    local desiredDifficulty = Addon.GetLevelingJourneyDifficulty(baseTargetLevel, Addon.GetLevelingJourneyPlayerProgress())
    if desiredDifficulty == OVERLAND_DIFFICULTY_TYPE_VETERAN and Addon.IsNearbyWorldBoss() then
        -- OVERLAND_DIFFICULTY_TYPE_ADVENTURER is the visible Master tier.
        desiredDifficulty = OVERLAND_DIFFICULTY_TYPE_ADVENTURER
    end

    return desiredDifficulty, regionId, targetLevel, targetChampionPoints
end

function Addon.MigrateSavedVars()
    local savedVars = Addon.savedVars
    if type(savedVars.levelingJourney) ~= "table" then
        savedVars.levelingJourney = {}
    end
    local levelingJourney = savedVars.levelingJourney
    levelingJourney.enabled = levelingJourney.enabled == true
    levelingJourney.maxLevel = NormalizeLevelingJourneyMaxLevel(levelingJourney.maxLevel)
    levelingJourney.adaptiveMaxLevel = levelingJourney.adaptiveMaxLevel == true
    if rawget(levelingJourney, "chatMessages") == nil then
        levelingJourney.chatMessages = SETTINGS_DEFAULTS.levelingJourney.chatMessages
    else
        levelingJourney.chatMessages = levelingJourney.chatMessages == true
    end
    if rawget(levelingJourney, "showMapLevel") == nil then
        levelingJourney.showMapLevel = SETTINGS_DEFAULTS.levelingJourney.showMapLevel
    else
        levelingJourney.showMapLevel = levelingJourney.showMapLevel == true
    end

    savedVars.debugEnabled = savedVars.debugEnabled == true
    savedVars.historyBossesExperimentalEnabled = savedVars.historyBossesExperimentalEnabled == true
    savedVars.situations = savedVars.situations or {}
    if type(savedVars.regions) ~= "table" then
        savedVars.regions = {}
    end
    if type(savedVars.nearbyPins) ~= "table" then
        savedVars.nearbyPins = {}
    end
    if type(savedVars.announcements) ~= "table" then
        savedVars.announcements = {}
    end
    savedVars.migrations = savedVars.migrations or {}
    savedVars.nearbyPinRadiusMeters = NormalizeNearbyPinRadiusMeters(savedVars.nearbyPinRadiusMeters)

    for regionId, difficulty in pairs(savedVars.regions) do
        if NormalizeDifficulty(difficulty) == NO_CHANGE then
            savedVars.regions[regionId] = nil
        end
    end

    for nearbyPin, difficulty in pairs(savedVars.nearbyPins) do
        if nearbyPin == NEARBY_PIN_DRAGONS then
            savedVars.nearbyPins[nearbyPin] = NormalizeNearbyPinDifficulty(nearbyPin, difficulty)
        elseif NormalizeDifficulty(difficulty) == NO_CHANGE then
            savedVars.nearbyPins[nearbyPin] = nil
        end
    end
    if rawget(savedVars.nearbyPins, NEARBY_PIN_DRAGONS) == nil then
        savedVars.nearbyPins[NEARBY_PIN_DRAGONS] = SETTINGS_DEFAULTS.nearbyPins[NEARBY_PIN_DRAGONS]
    end

    savedVars.announcements[ANNOUNCEMENT_CHAT] = savedVars.announcements[ANNOUNCEMENT_CHAT] == true

    if savedVars.migrations.publicDungeonsFromGroupDungeons then
        return
    end

    local oldDifficulty = NormalizeDifficulty(savedVars.situations[SITUATION_OLD_GROUP_DUNGEONS])
    if oldDifficulty ~= NO_CHANGE and Addon.GetSituationSettings(SITUATION_PUBLIC_DUNGEONS) == NO_CHANGE then
        savedVars.situations[SITUATION_PUBLIC_DUNGEONS] = oldDifficulty
    end

    savedVars.migrations.publicDungeonsFromGroupDungeons = true
end

function Addon.GetCurrentSituation()
    return SITUATION_BY_ZONE_DISPLAY_TYPE[Addon.currentZoneDisplayType or ZONE_DISPLAY_TYPE_NONE]
end

function Addon.IsHistoryBossContext()
    local zoneDisplayType = Addon.currentZoneDisplayType
    return zoneDisplayType == ZONE_DISPLAY_TYPE_SOLO or zoneDisplayType == ZONE_DISPLAY_TYPE_ZONE_STORY
end

function Addon.IsHistoryBossReticleTarget()
    if not DoesUnitExist(RETICLE_OVER_UNIT_TAG) or not IsUnitMonster(RETICLE_OVER_UNIT_TAG) then
        return false
    end

    local reaction = GetUnitReaction(RETICLE_OVER_UNIT_TAG)
    if reaction ~= UNIT_REACTION_NEUTRAL and reaction ~= UNIT_REACTION_HOSTILE then
        return false
    end

    local difficulty = GetUnitDifficulty(RETICLE_OVER_UNIT_TAG)
    return difficulty == MONSTER_DIFFICULTY_HARD or difficulty == MONSTER_DIFFICULTY_DEADLY
end

function Addon.HasActiveBossUnit()
    for bossRank = BOSS_RANK_ITERATION_BEGIN, BOSS_RANK_ITERATION_END do
        if DoesUnitExist("boss" .. bossRank) then
            return true
        end
    end

    return false
end

function Addon.HasHistoryBossSignal()
    return Addon.IsHistoryBossContext()
        and (Addon.HasActiveBossUnit() or Addon.IsHistoryBossReticleTarget())
end

function Addon.ShouldProcessHistoryBossState()
    return (Addon.savedVars
            and Addon.savedVars.enabled
            and not Addon.IsLevelingJourneyEnabled()
            and Addon.IsHistoryBossExperimentalEnabled()
            and Addon.GetSituationSettings(SITUATION_HISTORY_BOSSES) ~= NO_CHANGE)
        or Addon.historyBossActive == true
        or Addon.historyBossRestoreDifficulty ~= nil
end

function Addon.RefreshHistoryBossState()
    local wasActive = Addon.historyBossActive == true
    local shouldDetect = Addon.savedVars
        and Addon.savedVars.enabled
        and not Addon.IsLevelingJourneyEnabled()
        and Addon.IsHistoryBossExperimentalEnabled()
        and Addon.GetSituationSettings(SITUATION_HISTORY_BOSSES) ~= NO_CHANGE

    if not shouldDetect then
        Addon.historyBossActive = false
        if not Addon.savedVars
            or not Addon.savedVars.enabled
            or Addon.IsLevelingJourneyEnabled()
            or (Addon.historyBossRestoreDifficulty ~= nil and not Addon.IsHistoryBossContext()) then
            Addon.historyBossRestoreDifficulty = nil
        end
        return wasActive
    end

    local isActive = false
    if wasActive and IsUnitInCombat("player") then
        -- Keep the override stable while combat is active even if the reticle moves away from the boss.
        isActive = true
    else
        isActive = Addon.HasHistoryBossSignal()
    end

    if isActive and not wasActive and Addon.historyBossRestoreDifficulty == nil then
        local currentDifficulty = GetOverlandDifficulty()
        if VALID_DIFFICULTIES[currentDifficulty] then
            Addon.historyBossRestoreDifficulty = currentDifficulty
        end
    elseif not Addon.IsHistoryBossContext() or not Addon.savedVars or not Addon.savedVars.enabled then
        Addon.historyBossRestoreDifficulty = nil
    end

    Addon.historyBossActive = isActive
    return isActive ~= wasActive
end

function Addon.SetPendingZoneDisplayType(zoneDisplayType)
    Addon.pendingZoneDisplayType = zoneDisplayType
    Addon.hasPendingZoneDisplayType = true
end

function Addon.RefreshLevelingJourneyRegionState()
    local regionId = Addon.GetPlayerRegionId()
    if regionId == Addon.lastLevelingJourneyRegionId then
        return
    end

    Addon.lastLevelingJourneyRegionId = regionId
    Addon.pendingLevelingJourneyAnnouncement = nil

    if Addon.savedVars
        and Addon.savedVars.enabled
        and Addon.IsLevelingJourneyEnabled()
        and Addon.IsLevelingJourneyChatMessagesEnabled()
        and Addon.GetLevelingJourneyTargetProgression(regionId) then
        Addon.pendingLevelingJourneyAnnouncement = regionId
    end
end

function Addon.TryAnnounceLevelingJourneyEntry()
    local pendingRegionId = Addon.pendingLevelingJourneyAnnouncement
    if not pendingRegionId then
        return
    end

    if not Addon.savedVars
        or not Addon.savedVars.enabled
        or not Addon.IsLevelingJourneyEnabled()
        or not Addon.IsLevelingJourneyChatMessagesEnabled() then
        Addon.pendingLevelingJourneyAnnouncement = nil
        return
    end

    local desiredDifficulty, regionId, targetLevel, targetChampionPoints = Addon.GetLevelingJourneyDesiredDifficulty()
    if regionId ~= pendingRegionId
        or desiredDifficulty == NO_CHANGE
        or GetOverlandDifficultyDisabledReason() ~= OVERLAND_DIFFICULTY_DISABLED_REASON_NONE
        or GetOverlandDifficulty() ~= desiredDifficulty then
        return
    end

    local regionName = GetZoneNameById(regionId)
    if not regionName or regionName == "" then
        return
    end

    Addon.pendingLevelingJourneyAnnouncement = nil
    if CHAT_ROUTER then
        local formattedRegionName = ZO_CachedStrFormat(SI_ZONE_NAME, regionName)
        local targetText = Addon.GetLevelingJourneyTargetText(targetLevel, targetChampionPoints)
        local messageText = string.format(
            "Entering %s (%s) - World set to %s.",
            formattedRegionName,
            targetText,
            GetDifficultyName(desiredDifficulty)
        )
        local iconPath = LEVELING_JOURNEY_CHAT_ICONS[desiredDifficulty]
        local color = LEVELING_JOURNEY_CHAT_COLORS[desiredDifficulty]
        local message = string.format("|t24:24:%s|t |c%s%s|r", iconPath, color, messageText)
        CHAT_ROUTER:AddSystemMessage(message)
    end
end

function Addon.AnnounceDifficultyChanged(difficulty)
    if Addon.IsLevelingJourneyEnabled() or not VALID_DIFFICULTIES[difficulty] then
        return
    end

    local difficultyName = GetDifficultyName(difficulty)
    local message = string.format("%s: Difficulty changed to %s.", ADDON_DISPLAY_NAME, difficultyName)

    if Addon.GetAnnouncementSettings(ANNOUNCEMENT_CHAT) and CHAT_ROUTER then
        CHAT_ROUTER:AddSystemMessage(message)
    end
end

function Addon.UnregisterDifficultyRetry()
    if Addon.difficultyRetryRegistered then
        EVENT_MANAGER:UnregisterForUpdate(DIFFICULTY_RETRY_UPDATE_NAMESPACE)
        Addon.difficultyRetryRegistered = false
    end
end

function Addon.ClearDeferredDifficultyRequest()
    Addon.hasDeferredDifficultyRequest = false
    Addon.UnregisterDifficultyRetry()
end

function Addon.ScheduleDeferredDifficultyRequest(delayMs)
    Addon.hasDeferredDifficultyRequest = true
    Addon.UnregisterDifficultyRetry()

    EVENT_MANAGER:RegisterForUpdate(DIFFICULTY_RETRY_UPDATE_NAMESPACE, math.max(delayMs or 0, 1), function()
        Addon.difficultyRetryRegistered = false
        if not Addon.hasDeferredDifficultyRequest then
            return
        end

        Addon.hasDeferredDifficultyRequest = false
        Addon.ApplyCurrentSituation()
    end, true)
    Addon.difficultyRetryRegistered = true
end

function Addon.ApplyCurrentSituation()
    if not Addon.savedVars or not Addon.savedVars.enabled then
        Addon.pendingLevelingJourneyAnnouncement = nil
        Addon.ClearDeferredDifficultyRequest()
        return
    end

    local isRestoringHistoryBossDifficulty = false
    local desiredDifficulty = NO_CHANGE
    if Addon.IsLevelingJourneyEnabled() then
        desiredDifficulty = Addon.GetLevelingJourneyDesiredDifficulty()
        if desiredDifficulty == NO_CHANGE then
            Addon.ClearDeferredDifficultyRequest()
            return
        end
    else
        if Addon.IsHistoryBossExperimentalEnabled() and Addon.historyBossActive then
            desiredDifficulty = Addon.GetSituationSettings(SITUATION_HISTORY_BOSSES)
        else
            desiredDifficulty = Addon.GetNearbyPinDifficulty()
            if desiredDifficulty == NO_CHANGE and Addon.historyBossRestoreDifficulty ~= nil then
                desiredDifficulty = Addon.historyBossRestoreDifficulty
                isRestoringHistoryBossDifficulty = true
            elseif desiredDifficulty ~= NO_CHANGE then
                Addon.historyBossRestoreDifficulty = nil
            end
        end

        if desiredDifficulty == NO_CHANGE then
            local situation = Addon.GetCurrentSituation()
            if not situation then
                Addon.ClearDeferredDifficultyRequest()
                return
            end

            if situation == SITUATION_OPEN_WORLD then
                desiredDifficulty = Addon.GetRegionSettings(Addon.GetPlayerRegionId())
            end

            if desiredDifficulty == NO_CHANGE then
                desiredDifficulty = Addon.GetSituationSettings(situation)
                if desiredDifficulty == NO_CHANGE then
                    Addon.ClearDeferredDifficultyRequest()
                    return
                end
            end
        end
    end

    if GetOverlandDifficultyDisabledReason() ~= OVERLAND_DIFFICULTY_DISABLED_REASON_NONE then
        if Addon.IsLevelingJourneyEnabled() then
            Addon.pendingLevelingJourneyAnnouncement = nil
        end
        Addon.ClearDeferredDifficultyRequest()
        return
    end

    local currentDifficulty = GetOverlandDifficulty()
    if currentDifficulty ~= desiredDifficulty then
        if IsUnitInCombat("player") then
            Addon.hasDeferredDifficultyRequest = true
            Addon.UnregisterDifficultyRetry()
            Addon.lastRequestedDifficulty = nil
            return
        end

        local nowMs = GetFrameTimeMilliseconds()
        if Addon.nextDifficultyRequestTimeMS and nowMs < Addon.nextDifficultyRequestTimeMS then
            Addon.lastRequestedDifficulty = nil
            Addon.ScheduleDeferredDifficultyRequest(Addon.nextDifficultyRequestTimeMS - nowMs)
            return
        end

        Addon.ClearDeferredDifficultyRequest()
        Addon.lastRequestedDifficulty = desiredDifficulty
        Addon.nextDifficultyRequestTimeMS = nowMs + DIFFICULTY_REQUEST_COOLDOWN_MS
        RequestChangePlayerOverlandDifficulty(desiredDifficulty)
    else
        Addon.ClearDeferredDifficultyRequest()
        Addon.lastRequestedDifficulty = nil
        Addon.TryAnnounceLevelingJourneyEntry()
        if isRestoringHistoryBossDifficulty then
            Addon.historyBossRestoreDifficulty = nil
        end
    end
end

function Addon.OnPlayerActivated()
    if Addon.hasPendingZoneDisplayType then
        Addon.currentZoneDisplayType = Addon.pendingZoneDisplayType
        Addon.pendingZoneDisplayType = nil
        Addon.hasPendingZoneDisplayType = false
    end

    Addon.RefreshLevelingJourneyRegionState()
    if Addon.ShouldProcessHistoryBossState() then
        Addon.RefreshHistoryBossState()
    end
    Addon.ApplyCurrentSituation()
end

function Addon.OnPrepareForJump(_, _, _, _, zoneDisplayType)
    Addon.SetPendingZoneDisplayType(zoneDisplayType)
end

function Addon.OnAreaLoadStarted(_, _, _, _, _, _, zoneDisplayType)
    Addon.SetPendingZoneDisplayType(zoneDisplayType)
end

function Addon.OnZoneChanged()
    Addon.RefreshLevelingJourneyRegionState()
    if Addon.ShouldProcessHistoryBossState() then
        Addon.RefreshHistoryBossState()
    end
    Addon.ApplyCurrentSituation()
end

function Addon.OnPlayerCombatState(_, inCombat)
    local historyBossStateChanged = false
    if not inCombat and Addon.ShouldProcessHistoryBossState() then
        historyBossStateChanged = Addon.RefreshHistoryBossState()
    end

    if inCombat or (not Addon.hasDeferredDifficultyRequest and not historyBossStateChanged) then
        return
    end

    Addon.hasDeferredDifficultyRequest = false
    Addon.ApplyCurrentSituation()
end

function Addon.OnLevelingJourneyProgressUpdate(_, unitTag)
    if unitTag == "player" and Addon.IsLevelingJourneyEnabled() then
        Addon.worldMapDisplayedTargetText = nil
        Addon.RefreshLevelingJourneyEventRegistration()
        Addon.ApplyCurrentSituation()
    end
end

function Addon.OnOverlandDifficultyChanged(_, newDifficulty)
    local isAddonRequestedDifficulty = newDifficulty == Addon.lastRequestedDifficulty
    if isAddonRequestedDifficulty then
        Addon.lastRequestedDifficulty = nil
    end

    if VALID_DIFFICULTIES[newDifficulty] then
        Addon.nextDifficultyRequestTimeMS = GetFrameTimeMilliseconds() + DIFFICULTY_REQUEST_COOLDOWN_MS

        if newDifficulty ~= Addon.lastObservedDifficulty then
            Addon.lastObservedDifficulty = newDifficulty
            if GetOverlandDifficultyDisabledReason() == OVERLAND_DIFFICULTY_DISABLED_REASON_NONE
                and GetOverlandDifficulty() == newDifficulty then
                Addon.AnnounceDifficultyChanged(newDifficulty)
                Addon.TryAnnounceLevelingJourneyEntry()
            end
        end
    end

    if not isAddonRequestedDifficulty then
        Addon.ApplyCurrentSituation()
    end
end

function Addon.HideWorldMapLevelLabel()
    if Addon.worldMapLevelLabel then
        Addon.worldMapLevelLabel:SetHidden(true)
    end
    Addon.worldMapDisplayedTargetText = nil
end

function Addon.UpdateWorldMapLevelLabel()
    local label = Addon.worldMapLevelLabel
    if not label then
        return
    end

    local isGamepadMode = IsInGamepadPreferredMode()
    if Addon.worldMapLevelLabelUsesGamepadFont ~= isGamepadMode then
        label:SetFont(isGamepadMode and "ZoFontGamepadBold34" or "ZoFontHeader3")
        Addon.worldMapLevelLabelUsesGamepadFont = isGamepadMode
    end

    local normalizedX, normalizedY
    if isGamepadMode then
        local centerX, centerY = ZO_WorldMapScroll:GetCenter()
        normalizedX, normalizedY = NormalizePointToControl(centerX, centerY, ZO_WorldMapContainer)
    else
        normalizedX, normalizedY = NormalizeMousePositionToControl(ZO_WorldMapContainer)
    end

    if normalizedX <= 0 or normalizedX >= 1 or normalizedY <= 0 or normalizedY >= 1 then
        Addon.HideWorldMapLevelLabel()
        return
    end

    local _, _, _, _, _, _, mapId = GetMapMouseoverInfo(normalizedX, normalizedY)
    if not mapId or mapId == 0 then
        Addon.HideWorldMapLevelLabel()
        return
    end

    local zoneIndex = GetZoneIndexByMapId(mapId)
    if not zoneIndex or zoneIndex == 0 then
        Addon.HideWorldMapLevelLabel()
        return
    end

    local zoneId = GetZoneId(zoneIndex)
    local regionId = GetZoneStoryZoneIdForZoneId(zoneId)
    local targetLevel, targetChampionPoints = Addon.GetLevelingJourneyTargetProgression(regionId)
    if not targetLevel then
        Addon.HideWorldMapLevelLabel()
        return
    end

    local targetText = Addon.GetLevelingJourneyTargetText(targetLevel, targetChampionPoints)
    if Addon.worldMapDisplayedTargetText ~= targetText then
        label:SetText(string.format("World Progression - %s", targetText))
        Addon.worldMapDisplayedTargetText = targetText
    end
    label:SetHidden(false)
end

function Addon.RefreshWorldMapLevelUpdateRegistration()
    local shouldRegister = Addon.worldMapLevelLabel
        and Addon.worldMapIsShowing
        and Addon.savedVars
        and Addon.savedVars.enabled
        and Addon.IsLevelingJourneyEnabled()
        and Addon.IsLevelingJourneyMapLevelEnabled()

    if shouldRegister and not Addon.worldMapLevelUpdateRegistered then
        EVENT_MANAGER:RegisterForUpdate(LEVELING_JOURNEY_MAP_UPDATE_NAMESPACE, LEVELING_JOURNEY_MAP_UPDATE_INTERVAL_MS, function()
            Addon.UpdateWorldMapLevelLabel()
        end)
        Addon.worldMapLevelUpdateRegistered = true
        Addon.UpdateWorldMapLevelLabel()
    elseif not shouldRegister and Addon.worldMapLevelUpdateRegistered then
        EVENT_MANAGER:UnregisterForUpdate(LEVELING_JOURNEY_MAP_UPDATE_NAMESPACE)
        Addon.worldMapLevelUpdateRegistered = false
        Addon.HideWorldMapLevelLabel()
    elseif not shouldRegister then
        Addon.HideWorldMapLevelLabel()
    end
end

function Addon.InitializeWorldMapLevelLabel()
    local label = WINDOW_MANAGER:CreateControl("AODLevelingJourneyMapLevel", ZO_WorldMap, CT_LABEL)
    label:SetAnchor(TOPLEFT, ZO_WorldMapMouseOverDescription, BOTTOMLEFT, 0, 4)
    label:SetAnchor(TOPRIGHT, ZO_WorldMapMouseOverDescription, BOTTOMRIGHT, 0, 4)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetColor(ZO_WorldMapMouseoverName:GetColor())
    label:SetDrawLayer(DL_OVERLAY)
    label:SetHidden(true)
    Addon.worldMapLevelLabel = label

    WORLD_MAP_FRAGMENT:RegisterCallback("StateChange", function(_, newState)
        if newState == SCENE_FRAGMENT_SHOWING or newState == SCENE_FRAGMENT_SHOWN then
            Addon.worldMapIsShowing = true
        elseif newState == SCENE_FRAGMENT_HIDING or newState == SCENE_FRAGMENT_HIDDEN then
            Addon.worldMapIsShowing = false
        end
        Addon.RefreshWorldMapLevelUpdateRegistration()
    end)
end

function Addon.CreateLevelingJourneyEnabledCheckbox()
    return
    {
        type = "checkbox",
        name = "Enable World Progression",
        tooltip = "Gives each zone a level and automatically adjusts the world difficulty as you explore.",
        getFunc = function()
            return Addon.IsLevelingJourneyEnabled()
        end,
        setFunc = function(value)
            Addon.SetLevelingJourneyEnabled(value)
        end,
        default = SETTINGS_DEFAULTS.levelingJourney.enabled,
        width = "full",
    }
end

function Addon.CreateLevelingJourneyChatCheckbox()
    return
    {
        type = "checkbox",
        name = "Show zone entry message in chat",
        tooltip = "Shows the zone level and world difficulty in chat when you enter a new zone.",
        disabled = function()
            return not Addon.IsLevelingJourneyEnabled()
        end,
        getFunc = function()
            return Addon.IsLevelingJourneyChatMessagesEnabled()
        end,
        setFunc = function(value)
            Addon.SetLevelingJourneyChatMessagesEnabled(value)
        end,
        default = SETTINGS_DEFAULTS.levelingJourney.chatMessages,
        width = "full",
    }
end

function Addon.CreateLevelingJourneyAdaptiveMaxLevelCheckbox()
    return
    {
        type = "checkbox",
        name = "Adaptive max level",
        tooltip = "Automatically advances the World Progression cap as you progress. It keeps the cap at Level 50 while your character is below Level 50, switches to CP 160 at Level 50, then advances whenever you reach the current CP tier.",
        disabled = function()
            return not Addon.IsLevelingJourneyEnabled()
        end,
        getFunc = function()
            return Addon.IsLevelingJourneyAdaptiveMaxLevelEnabled()
        end,
        setFunc = function(value)
            Addon.SetLevelingJourneyAdaptiveMaxLevelEnabled(value)
        end,
        default = SETTINGS_DEFAULTS.levelingJourney.adaptiveMaxLevel,
        width = "full",
    }
end

function Addon.CreateLevelingJourneyMaxLevelDropdown()
    return
    {
        type = "dropdown",
        name = "Max level",
        tooltip = "Sets the end of World Progression. Selecting a CP value scales every zone target across that Champion Point range and uses your earned Champion Points instead of character level.",
        disabled = function()
            return not Addon.IsLevelingJourneyEnabled()
                or Addon.IsLevelingJourneyAdaptiveMaxLevelEnabled()
        end,
        choices = LEVELING_JOURNEY_MAX_LEVEL_CHOICES,
        choicesValues = LEVELING_JOURNEY_MAX_LEVEL_VALUES,
        sort = "numericvalue-up",
        getFunc = function()
            return Addon.GetLevelingJourneyMaxLevel()
        end,
        setFunc = function(value)
            Addon.SetLevelingJourneyMaxLevel(value)
        end,
        default = SETTINGS_DEFAULTS.levelingJourney.maxLevel,
        width = "full",
    }
end

function Addon.CreateLevelingJourneyMapCheckbox()
    return
    {
        type = "checkbox",
        name = "Show zone level on the world map",
        tooltip = "Shows each zone's level as you browse the world map.",
        disabled = function()
            return not Addon.IsLevelingJourneyEnabled()
        end,
        getFunc = function()
            return Addon.IsLevelingJourneyMapLevelEnabled()
        end,
        setFunc = function(value)
            Addon.SetLevelingJourneyMapLevelEnabled(value)
        end,
        default = SETTINGS_DEFAULTS.levelingJourney.showMapLevel,
        width = "full",
    }
end

function Addon.CreateSituationDropdown(situation, name, choices, values)
    return
    {
        type = "dropdown",
        name = name,
        disabled = function()
            return Addon.IsLevelingJourneyEnabled()
        end,
        choices = choices,
        choicesValues = values,
        sort = "numericvalue-up",
        getFunc = function()
            return Addon.GetSituationSettings(situation)
        end,
        setFunc = function(value)
            Addon.SetSituationSettings(situation, value)
        end,
        default = SETTINGS_DEFAULTS.situations[situation],
        width = "full",
    }
end

function Addon.CreateHistoryBossDropdown(choices, values)
    return
    {
        type = "dropdown",
        name = "History Bosses*",
        tooltip = HISTORY_BOSS_TOOLTIP,
        disabled = function()
            return Addon.IsLevelingJourneyEnabled() or not Addon.IsHistoryBossExperimentalEnabled()
        end,
        choices = choices,
        choicesValues = values,
        sort = "numericvalue-up",
        getFunc = function()
            return Addon.GetSituationSettings(SITUATION_HISTORY_BOSSES)
        end,
        setFunc = function(value)
            Addon.SetHistoryBossSettings(value)
        end,
        default = SETTINGS_DEFAULTS.situations[SITUATION_HISTORY_BOSSES],
        width = "full",
    }
end

function Addon.CreateHistoryBossExperimentalCheckbox()
    return
    {
        type = "checkbox",
        name = "Enable experimental",
        tooltip = "Enables experimental History Bosses detection. While disabled, no boss detection events are registered and the History Bosses setting has no effect.",
        disabled = function()
            return Addon.IsLevelingJourneyEnabled()
        end,
        getFunc = function()
            return Addon.IsHistoryBossExperimentalEnabled()
        end,
        setFunc = function(value)
            Addon.SetHistoryBossExperimentalEnabled(value)
        end,
        default = SETTINGS_DEFAULTS.historyBossesExperimentalEnabled,
        width = "full",
    }
end

function Addon.CreateDebugCheckbox()
    return
    {
        type = "checkbox",
        name = "Debug",
        getFunc = function()
            return Addon.IsDebugEnabled()
        end,
        setFunc = function(value)
            Addon.SetDebugEnabled(value)
        end,
        default = SETTINGS_DEFAULTS.debugEnabled,
        width = "full",
    }
end

function Addon.CreateNearbyPinDropdown(nearbyPinSettings, choices, values)
    return
    {
        type = "dropdown",
        name = nearbyPinSettings.name,
        disabled = function()
            return Addon.IsLevelingJourneyEnabled()
        end,
        choices = choices,
        choicesValues = values,
        sort = "numericvalue-up",
        getFunc = function()
            return Addon.GetNearbyPinSettings(nearbyPinSettings.key)
        end,
        setFunc = function(value)
            Addon.SetNearbyPinSettings(nearbyPinSettings.key, value)
        end,
        default = SETTINGS_DEFAULTS.nearbyPins[nearbyPinSettings.key],
        width = "full",
    }
end

function Addon.CreateNearbyPinRadiusSlider()
    return
    {
        type = "slider",
        name = "POI Radius",
        tooltip = "How close you must be to a world boss or world event map pin. World Progression uses this radius to cap World Boss difficulty at Master. Smaller numbers mean closer.",
        min = MIN_NEARBY_PIN_RADIUS_METERS,
        max = MAX_NEARBY_PIN_RADIUS_METERS,
        step = NEARBY_PIN_RADIUS_STEP_METERS,
        decimals = 0,
        getFunc = function()
            return Addon.GetNearbyPinRadiusMeters()
        end,
        setFunc = function(value)
            Addon.SetNearbyPinRadiusMeters(value)
        end,
        default = SETTINGS_DEFAULTS.nearbyPinRadiusMeters,
        width = "full",
    }
end

function Addon.CreateAnnouncementCheckbox(announcementType, name, disabled)
    return
    {
        type = "checkbox",
        name = name,
        disabled = function()
            if Addon.IsLevelingJourneyEnabled() then
                return true
            end
            if type(disabled) == "function" then
                return disabled()
            end
            return disabled == true
        end,
        getFunc = function()
            return Addon.GetAnnouncementSettings(announcementType)
        end,
        setFunc = function(value)
            Addon.SetAnnouncementSettings(announcementType, value)
        end,
        default = SETTINGS_DEFAULTS.announcements[announcementType],
        width = "full",
    }
end

function Addon.CreateResetRegionsButton()
    return
    {
        type = "button",
        name = "Reset Zones",
        disabled = function()
            return Addon.IsLevelingJourneyEnabled()
        end,
        func = function()
            Addon.ResetRegionSettings()
        end,
        isDangerous = true,
        warning = "Reset all zone difficulty settings to Do not change?",
        width = "full",
    }
end

function Addon.CreateRegionDropdown(regionId, regionName, choices, values)
    return
    {
        type = "dropdown",
        name = regionName,
        disabled = function()
            return Addon.IsLevelingJourneyEnabled()
        end,
        choices = choices,
        choicesValues = values,
        sort = "numericvalue-up",
        getFunc = function()
            return Addon.GetRegionSettings(regionId)
        end,
        setFunc = function(value)
            Addon.SetRegionSettings(regionId, value)
        end,
        default = NO_CHANGE,
        width = "full",
    }
end

function Addon.BuildRegionDropdownControls(choices, values)
    local regions = {}
    local regionId = GetNextZoneStoryZoneId(nil)

    while regionId do
        local regionName = GetZoneNameById(regionId)
        if regionName ~= nil and regionName ~= "" then
            regions[#regions + 1] =
            {
                id = regionId,
                name = ZO_CachedStrFormat(SI_ZONE_NAME, regionName),
            }
        end

        regionId = GetNextZoneStoryZoneId(regionId)
    end

    table.sort(regions, function(left, right)
        if left.name == right.name then
            return left.id < right.id
        end
        return left.name < right.name
    end)

    local controls =
    {
        Addon.CreateResetRegionsButton(),
    }

    for index = 1, #regions do
        local region = regions[index]
        controls[#controls + 1] = Addon.CreateRegionDropdown(region.id, region.name, choices, values)
    end

    return controls
end

function Addon.LoadActiveSettings()
    local profileName = GetProfileName()
    if Addon.scopeVars.accountBoundSettings ~= false then
        Addon.savedVars = ZO_SavedVars:NewAccountWide(SAVED_VARS_NAME, SAVED_VARS_VERSION, "Settings", SETTINGS_DEFAULTS, profileName)
    else
        Addon.savedVars = ZO_SavedVars:NewCharacterIdSettings(SAVED_VARS_NAME, SAVED_VARS_VERSION, "Settings", SETTINGS_DEFAULTS, profileName)
    end

    Addon.MigrateSavedVars()
    Addon.lastLevelingJourneyRegionId = nil
    Addon.pendingLevelingJourneyAnnouncement = nil
    if Addon.savedVars.enabled and Addon.IsLevelingJourneyEnabled() then
        Addon.RefreshLevelingJourneyRegionState()
    end
    Addon.RefreshNearbyUpdateRegistration()
    Addon.RefreshHistoryBossEventRegistration()
    Addon.RefreshLevelingJourneyEventRegistration()
    Addon.RefreshWorldMapLevelUpdateRegistration()
    Addon.RefreshPOIDiagnosticCommandRegistration()
end

function Addon.LoadScopeSettings()
    local profileName = GetProfileName()
    Addon.scopeVars = ZO_SavedVars:NewCharacterIdSettings(SAVED_VARS_NAME, SAVED_VARS_VERSION, "Scope", nil, profileName)

    if Addon.scopeVars.accountBoundSettings == nil then
        -- This selector used to be account-wide. Copy the old value once when a character first gets its own scope.
        local legacyScopeVars = ZO_SavedVars:NewAccountWide(SAVED_VARS_NAME, SAVED_VARS_VERSION, "Scope", nil, profileName)
        if legacyScopeVars.accountBoundSettings ~= nil then
            Addon.scopeVars.accountBoundSettings = legacyScopeVars.accountBoundSettings ~= false
        end
    end

    Addon.scopeVars = ZO_SavedVars:NewCharacterIdSettings(SAVED_VARS_NAME, SAVED_VARS_VERSION, "Scope", SCOPE_DEFAULTS, profileName)
end

function Addon.RegisterSettings()
    local LAM = LibAddonMenu2

    local choices, values = BuildDifficultyChoices()
    local dragonChoices, dragonValues = BuildDragonDifficultyChoices()

    local panelData =
    {
        type = "panel",
        name = ADDON_DISPLAY_NAME,
        displayName = ADDON_DISPLAY_NAME,
        author = ADDON_AUTHOR,
        version = ADDON_VERSION,
        slashCommand = "/aodifficulty",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    local optionsTable =
    {
        {
            type = "checkbox",
            name = "Enabled",
            getFunc = function()
                return Addon.savedVars.enabled
            end,
            setFunc = function(value)
                if Addon.savedVars.enabled ~= value then
                    Addon.savedVars.enabled = value
                end
                Addon.lastLevelingJourneyRegionId = nil
                Addon.pendingLevelingJourneyAnnouncement = nil
                if value and Addon.IsLevelingJourneyEnabled() then
                    Addon.RefreshLevelingJourneyRegionState()
                end
                Addon.RefreshNearbyUpdateRegistration()
                Addon.RefreshHistoryBossEventRegistration()
                Addon.RefreshLevelingJourneyEventRegistration()
                Addon.RefreshWorldMapLevelUpdateRegistration()
                Addon.ApplyCurrentSituation()
            end,
            default = SETTINGS_DEFAULTS.enabled,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Account Bound Settings",
            getFunc = function()
                return Addon.scopeVars.accountBoundSettings ~= false
            end,
            setFunc = function(value)
                Addon.scopeVars.accountBoundSettings = value
                Addon.LoadActiveSettings()
                Addon.ApplyCurrentSituation()
            end,
            default = SCOPE_DEFAULTS.accountBoundSettings,
            width = "full",
        },
        {
            type = "header",
            name = "World Progression",
            width = "full",
        },
        Addon.CreateLevelingJourneyEnabledCheckbox(),
        Addon.CreateLevelingJourneyAdaptiveMaxLevelCheckbox(),
        Addon.CreateLevelingJourneyMaxLevelDropdown(),
        Addon.CreateNearbyPinRadiusSlider(),
        Addon.CreateLevelingJourneyChatCheckbox(),
        Addon.CreateLevelingJourneyMapCheckbox(),
        {
            type = "header",
            name = "Situations",
            width = "full",
        },
        Addon.CreateSituationDropdown(
            SITUATION_DELVES,
            "Delves",
            choices,
            values
        ),
        Addon.CreateSituationDropdown(
            SITUATION_PUBLIC_DUNGEONS,
            "Public Dungeons",
            choices,
            values
        ),
        Addon.CreateSituationDropdown(
            SITUATION_OPEN_WORLD,
            "Open World",
            choices,
            values
        ),
        Addon.CreateNearbyPinDropdown(NEARBY_PIN_SETTINGS[1], choices, values),
        Addon.CreateNearbyPinDropdown(NEARBY_PIN_SETTINGS[2], choices, values),
        Addon.CreateNearbyPinDropdown(NEARBY_PIN_SETTINGS[3], dragonChoices, dragonValues),
        {
            type = "header",
            name = "Announcements",
            width = "full",
        },
        Addon.CreateAnnouncementCheckbox(
            ANNOUNCEMENT_CHAT,
            "Chat"
        ),
        {
            type = "submenu",
            name = "Zones",
            disabled = function()
                return Addon.IsLevelingJourneyEnabled()
            end,
            controls = Addon.BuildRegionDropdownControls(choices, values),
        },
        {
            type = "header",
            name = "Experimental",
            width = "full",
        },
        Addon.CreateHistoryBossExperimentalCheckbox(),
        Addon.CreateHistoryBossDropdown(choices, values),
        {
            type = "header",
            name = "Diagnostics",
            width = "full",
        },
        Addon.CreateDebugCheckbox(),
    }

    LAM:RegisterAddonPanel(LAM_PANEL_NAME, panelData)
    LAM:RegisterOptionControls(LAM_PANEL_NAME, optionsTable)
end

function Addon.RefreshNearbyUpdateRegistration()
    local shouldRegister = Addon.savedVars
        and Addon.savedVars.enabled
        and (Addon.IsLevelingJourneyEnabled() or Addon.HasNearbyPinSettings())
    if shouldRegister and not Addon.nearbyUpdateRegistered then
        EVENT_MANAGER:RegisterForUpdate(NEARBY_UPDATE_NAMESPACE, NEARBY_UPDATE_INTERVAL_MS, function()
            Addon.ApplyCurrentSituation()
        end)
        Addon.nearbyUpdateRegistered = true
    elseif not shouldRegister and Addon.nearbyUpdateRegistered then
        EVENT_MANAGER:UnregisterForUpdate(NEARBY_UPDATE_NAMESPACE)
        Addon.nearbyUpdateRegistered = false
    end
end

function Addon.RefreshHistoryBossEventRegistration()
    local shouldRegister = Addon.savedVars
        and Addon.savedVars.enabled
        and not Addon.IsLevelingJourneyEnabled()
        and Addon.IsHistoryBossExperimentalEnabled()
        and Addon.GetSituationSettings(SITUATION_HISTORY_BOSSES) ~= NO_CHANGE

    if shouldRegister and not Addon.historyBossEventsRegistered then
        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_RETICLE_TARGET_CHANGED, function()
            if Addon.RefreshHistoryBossState() then
                Addon.ApplyCurrentSituation()
            end
        end)

        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_BOSSES_CHANGED, function()
            if Addon.RefreshHistoryBossState() then
                Addon.ApplyCurrentSituation()
            end
        end)

        Addon.historyBossEventsRegistered = true
    elseif not shouldRegister and Addon.historyBossEventsRegistered then
        EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_RETICLE_TARGET_CHANGED)
        EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_BOSSES_CHANGED)
        Addon.historyBossEventsRegistered = false
    end

    if Addon.ShouldProcessHistoryBossState() then
        Addon.RefreshHistoryBossState()
    end
end

function Addon.RefreshLevelingJourneyEventRegistration()
    local shouldRegister = Addon.savedVars
        and Addon.savedVars.enabled
        and Addon.IsLevelingJourneyEnabled()

    if shouldRegister and not Addon.levelingJourneyEventRegistered then
        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_LEVEL_UPDATE, function(...)
            Addon.OnLevelingJourneyProgressUpdate(...)
        end)
        EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE, EVENT_LEVEL_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
        Addon.levelingJourneyEventRegistered = true
    elseif not shouldRegister and Addon.levelingJourneyEventRegistered then
        EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_LEVEL_UPDATE)
        Addon.levelingJourneyEventRegistered = false
    end

    local effectiveMaxLevel = Addon.GetLevelingJourneyMaxLevel()
    local shouldRegisterChampionPoints = shouldRegister
        and effectiveMaxLevel > LEVELING_JOURNEY_BASE_MAX_LEVEL
        and GetPlayerChampionPointsEarned() < effectiveMaxLevel
    if shouldRegisterChampionPoints and not Addon.levelingJourneyChampionPointEventRegistered then
        EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_CHAMPION_POINT_UPDATE, function(...)
            Addon.OnLevelingJourneyProgressUpdate(...)
        end)
        EVENT_MANAGER:AddFilterForEvent(EVENT_NAMESPACE, EVENT_CHAMPION_POINT_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
        Addon.levelingJourneyChampionPointEventRegistered = true
    elseif not shouldRegisterChampionPoints and Addon.levelingJourneyChampionPointEventRegistered then
        EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_CHAMPION_POINT_UPDATE)
        Addon.levelingJourneyChampionPointEventRegistered = false
    end
end

function Addon.RegisterEvents()
    local eventManager = EVENT_MANAGER

    eventManager:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, function(...)
        Addon.OnPlayerActivated(...)
    end)

    eventManager:RegisterForEvent(EVENT_NAMESPACE, EVENT_ZONE_CHANGED, function(...)
        Addon.OnZoneChanged(...)
    end)

    eventManager:RegisterForEvent(EVENT_NAMESPACE, EVENT_PREPARE_FOR_JUMP, function(...)
        Addon.OnPrepareForJump(...)
    end)

    if EVENT_AREA_LOAD_STARTED ~= nil then
        eventManager:RegisterForEvent(EVENT_NAMESPACE, EVENT_AREA_LOAD_STARTED, function(...)
            Addon.OnAreaLoadStarted(...)
        end)
    end

    eventManager:RegisterForEvent(EVENT_NAMESPACE, EVENT_OVERLAND_DIFFICULTY_CHANGED, function(...)
        Addon.OnOverlandDifficultyChanged(...)
    end)

    eventManager:RegisterForEvent(EVENT_NAMESPACE, EVENT_OVERLAND_DIFFICULTY_DISABLED_BY_SERVER_CHANGED, function()
        Addon.ApplyCurrentSituation()
    end)

    eventManager:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_COMBAT_STATE, function(...)
        Addon.OnPlayerCombatState(...)
    end)
end

function Addon.Initialize()
    Addon.BuildLevelingJourneyZoneLevels()
    Addon.BuildPOIPinRadiusBypassLookup()
    Addon.LoadScopeSettings()
    Addon.LoadActiveSettings()
    Addon.lastObservedDifficulty = GetOverlandDifficulty()
    Addon.RegisterSettings()
    Addon.InitializeWorldMapLevelLabel()
    Addon.RegisterEvents()
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED)
    Addon.Initialize()
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
