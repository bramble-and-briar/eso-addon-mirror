local TamrielTomes_MapPins = "TamrielTomes_MapPins"

local TTMP = _G.TamrielTomesMapPins or {}
_G.TamrielTomesMapPins = TTMP

TTMP.addonName = TamrielTomes_MapPins
TTMP.savedVarsName = "TamrielTomesMapPins_SV"
TTMP.savedVarsVersion = 1
TTMP.pinType = "TAMRIEL_TOMES_MAP_PINS_CHALLENGE"
TTMP.compassPinType = "TAMRIEL_TOMES_COMPASS_PINS_CHALLENGE"
TTMP.challengeEntriesByActivityId = {}
TTMP.activityIncompleteById = {}
TTMP.texturePath = "TamrielTomes_MapPins/textures/"
TTMP.activeChallengePins = {}
TTMP.activeMatchesByZoneId = {}
TTMP.activeDynamicMatchesByType = {}
TTMP.activeDynamicMatchCount = 0
TTMP.hasActiveLocationMatches = false
TTMP.activeCompassZoneIndex = nil
TTMP.activeCompassZoneId = nil
TTMP.activeCompassMapId = nil
TTMP.activeCompassZoneMatches = nil
TTMP.compassOverlayMaxDistance = 0.55
TTMP.compassOverlayDrawLevel = 140
TTMP.nativePinTextureCallbacks = {}
TTMP.pinDebugCache = {}

local GLOBAL_MAP_TYPES = {
    [MAPTYPE_WORLD] = true,
    [MAPTYPE_COSMIC] = true,
}

TTMP.icons = {
    default = TTMP.texturePath .. "challenge_world_boss.dds",
    worldBoss = TTMP.texturePath .. "challenge_world_boss.dds",
    worldBossComplete = TTMP.texturePath .. "challenge_world_boss_complete.dds",
    worldBossIncomplete = TTMP.texturePath .. "challenge_world_boss_incomplete.dds",
    worldBossGeneric = TTMP.texturePath .. "challenge_world_boss_incomplete_generic.dds",
    worldBossGenericComplete = TTMP.texturePath .. "challenge_world_boss_complete_generic.dds",
    worldBossGenericIncomplete = TTMP.texturePath .. "challenge_world_boss_incomplete_generic.dds",
    worldEvent = TTMP.texturePath .. "challenge_world_event_incomplete.dds",
    worldEventComplete = TTMP.texturePath .. "challenge_world_event_complete.dds",
    worldEventIncomplete = TTMP.texturePath .. "challenge_world_event_incomplete.dds",
    publicDungeon = TTMP.texturePath .. "challenge_public_dungeon_incomplete.dds",
    publicDungeonComplete = TTMP.texturePath .. "challenge_public_dungeon_complete.dds",
    publicDungeonIncomplete = TTMP.texturePath .. "challenge_public_dungeon_incomplete.dds",
    publicDungeonGeneric = TTMP.texturePath .. "challenge_public_dungeon_incomplete_generic.dds",
    publicDungeonGenericComplete = TTMP.texturePath .. "challenge_public_dungeon_complete_generic.dds",
    publicDungeonGenericIncomplete = TTMP.texturePath .. "challenge_public_dungeon_incomplete_generic.dds",
    delveGeneric = TTMP.texturePath .. "challenge_delve_generic.dds",
    delveGenericComplete = TTMP.texturePath .. "challenge_delve_complete_generic.dds",
    delveGenericIncomplete = TTMP.texturePath .. "challenge_delve_generic.dds",
    groupDungeon = TTMP.texturePath .. "challenge_group_dungeon_complete.dds",
    groupDungeonComplete = TTMP.texturePath .. "challenge_group_dungeon_complete.dds",
    groupDungeonIncomplete = TTMP.texturePath .. "challenge_group_dungeon_incomplete.dds",
    groupDungeonGeneric = TTMP.texturePath .. "challenge_group_dungeon_generic.dds",
    groupDungeonGenericComplete = TTMP.texturePath .. "challenge_group_dungeon_complete_generic.dds",
    groupDungeonGenericIncomplete = TTMP.texturePath .. "challenge_group_dungeon_incomplete_generic.dds",
    trial = TTMP.texturePath .. "challenge_trial.dds",
    trialComplete = TTMP.texturePath .. "challenge_trial_complete.dds",
    trialIncomplete = TTMP.texturePath .. "challenge_trial_incomplete.dds",
    trialGeneric = TTMP.texturePath .. "challenge_trial_generic.dds",
    trialGenericComplete = TTMP.texturePath .. "challenge_trial_complete_generic.dds",
    trialGenericIncomplete = TTMP.texturePath .. "challenge_trial_incomplete_generic.dds",
    arenaGeneric = TTMP.texturePath .. "challenge_arena_generic.dds",
    arenaGenericComplete = TTMP.texturePath .. "challenge_arena_complete_generic.dds",
    arenaGenericIncomplete = TTMP.texturePath .. "challenge_arena_incomplete_generic.dds",
    bankGeneric = TTMP.texturePath .. "challenge_bank_generic.dds",
    dynamicEncounterGeneric = TTMP.texturePath .. "challenge_dynamic_encounter_generic.dds",
    freerunner = TTMP.texturePath .. "challenge_freerunner_incomplete_generic.dds",
    freerunnerComplete = TTMP.texturePath .. "challenge_freerunner_complete_generic.dds",
    freerunnerIncomplete = TTMP.texturePath .. "challenge_freerunner_incomplete_generic.dds",
    fightersGuildGeneric = TTMP.texturePath .. "challenge_fighters_guild_generic.dds",
    guildTraderGeneric = TTMP.texturePath .. "challenge_guild_trader_generic.dds",
    magesGuildGeneric = TTMP.texturePath .. "challenge_mages_guild_generic.dds",
    mundusGeneric = TTMP.texturePath .. "challenge_mundus_generic.dds",
    museum = TTMP.texturePath .. "challenge_museum.dds",
    thievesDen = TTMP.texturePath .. "challenge_thieves_den.dds",
    outlawsRefuge = TTMP.texturePath .. "challenge_outlaws_refuge.dds",
    darkBrotherhoodComplete = TTMP.texturePath .. "challenge_dark_brotherhood_complete_generic.dds",
    darkBrotherhoodIncomplete = TTMP.texturePath .. "challenge_dark_brotherhood_incomplete_generic.dds",
    undauntedGeneric = TTMP.texturePath .. "challenge_undaunted_generic.dds",
    worldEventGeneric = TTMP.texturePath .. "challenge_world_event_incomplete_generic.dds",
    worldEventGenericComplete = TTMP.texturePath .. "challenge_world_event_complete_generic.dds",
    worldEventGenericIncomplete = TTMP.texturePath .. "challenge_world_event_incomplete_generic.dds",
}

TTMP.goldBookIcons = {
    [TTMP.icons.worldBoss] = true,
    [TTMP.icons.worldEvent] = true,
    [TTMP.icons.publicDungeon] = true,
    [TTMP.icons.groupDungeon] = true,
    [TTMP.icons.trial] = true,
    [TTMP.icons.thievesDen] = true,
    [TTMP.icons.outlawsRefuge] = true,
}

TTMP.stateIconsByIcon = {
    [TTMP.icons.publicDungeon] = {
        complete = TTMP.icons.publicDungeonComplete,
        incomplete = TTMP.icons.publicDungeonIncomplete,
        undiscovered = TTMP.icons.publicDungeonIncomplete,
    },
    [TTMP.icons.publicDungeonGeneric] = {
        complete = TTMP.icons.publicDungeonGenericComplete,
        incomplete = TTMP.icons.publicDungeonGenericIncomplete,
        undiscovered = TTMP.icons.publicDungeonGenericIncomplete,
    },
    [TTMP.icons.worldBoss] = {
        complete = TTMP.icons.worldBossComplete,
        incomplete = TTMP.icons.worldBossIncomplete,
        undiscovered = TTMP.icons.worldBossIncomplete,
    },
    [TTMP.icons.worldBossGeneric] = {
        complete = TTMP.icons.worldBossGenericComplete,
        incomplete = TTMP.icons.worldBossGenericIncomplete,
        undiscovered = TTMP.icons.worldBossGenericIncomplete,
    },
    [TTMP.icons.worldEvent] = {
        complete = TTMP.icons.worldEventComplete,
        incomplete = TTMP.icons.worldEventIncomplete,
        undiscovered = TTMP.icons.worldEventIncomplete,
    },
    [TTMP.icons.groupDungeon] = {
        complete = TTMP.icons.groupDungeonComplete,
        incomplete = TTMP.icons.groupDungeonIncomplete,
        undiscovered = TTMP.icons.groupDungeonIncomplete,
    },
    [TTMP.icons.trial] = {
        complete = TTMP.icons.trialComplete,
        incomplete = TTMP.icons.trialIncomplete,
        undiscovered = TTMP.icons.trialIncomplete,
    },
}

TTMP.poiIconOverrides = {
    ["esoui/art/icons/poi/poi_groupboss_complete.dds"] = TTMP.icons.worldBossComplete,
    ["esoui/art/icons/poi/poi_groupboss_incomplete.dds"] = TTMP.icons.worldBossIncomplete,
    ["esoui/art/icons/poi/poi_dungeon_complete.dds"] = TTMP.icons.publicDungeonComplete,
    ["esoui/art/icons/poi/poi_dungeon_incomplete.dds"] = TTMP.icons.publicDungeonIncomplete,
    ["esoui/art/icons/poi/poi_publicdungeon_complete.dds"] = TTMP.icons.publicDungeonComplete,
    ["esoui/art/icons/poi/poi_publicdungeon_incomplete.dds"] = TTMP.icons.publicDungeonIncomplete,
}

TTMP.poiIconKinds = {
    ["esoui/art/icons/mapkey/mapkey_endlessdungeon.dds"] = "endlessDungeon",
    ["esoui/art/icons/mapkey/mapkey_guildkiosk.dds"] = "guildTrader",
    ["esoui/art/icons/mapkey/mapkey_thievesguild.dds"] = "thievesDen",
    ["esoui/art/icons/mapkey/mapkey_fence.dds"] = "outlawsRefuge",
    ["esoui/art/icons/mapkey/mapkey_fightersguild.dds"] = "fightersGuild",
    ["esoui/art/icons/mapkey/mapkey_magesguild.dds"] = "magesGuild",
    ["esoui/art/icons/mapkey/mapkey_undaunted.dds"] = "undaunted",
    ["esoui/art/icons/mapkey/mapkey_darkbrotherhood.dds"] = "darkBrotherhood",
    ["esoui/art/icons/poi/poi_darkbrotherhood_complete.dds"] = "darkBrotherhood",
    ["esoui/art/icons/poi/poi_darkbrotherhood_incomplete.dds"] = "darkBrotherhood",
    ["esoui/art/icons/poi/poi_delve_complete.dds"] = "delve",
    ["esoui/art/icons/poi/poi_delve_incomplete.dds"] = "delve",
    ["esoui/art/icons/poi/poi_freerunner_complete.dds"] = "freerunner",
    ["esoui/art/icons/poi/poi_freerunner_incomplete.dds"] = "freerunner",
    ["esoui/art/icons/poi/poi_group_portal_complete.dds"] = "worldEvent",
    ["esoui/art/icons/poi/poi_group_portal_incomplete.dds"] = "worldEvent",
    ["esoui/art/icons/poi/poi_groupinstance_complete.dds"] = "groupDungeon",
    ["esoui/art/icons/poi/poi_groupinstance_incomplete.dds"] = "groupDungeon",
    ["esoui/art/icons/poi/poi_groupboss_complete.dds"] = "worldBoss",
    ["esoui/art/icons/poi/poi_groupboss_incomplete.dds"] = "worldBoss",
    ["esoui/art/icons/poi/poi_endlessdungeon_complete.dds"] = "endlessDungeon",
    ["esoui/art/icons/poi/poi_mundus_complete.dds"] = "mundus",
    ["esoui/art/icons/poi/poi_mundus_incomplete.dds"] = "mundus",
    ["esoui/art/icons/poi/poi_portal_complete.dds"] = "worldEvent",
    ["esoui/art/icons/poi/poi_portal_incomplete.dds"] = "worldEvent",
    ["esoui/art/icons/poi/poi_raiddungeon_complete.dds"] = "trial",
    ["esoui/art/icons/poi/poi_raiddungeon_incomplete.dds"] = "trial",
    ["esoui/art/icons/servicemappins/servicepin_bank.dds"] = "bank",
    ["esoui/art/icons/servicemappins/servicepin_fence.dds"] = "outlawsRefuge",
    ["esoui/art/icons/servicemappins/servicepin_fightersguild.dds"] = "fightersGuild",
    ["esoui/art/icons/servicemappins/servicepin_guildkiosk.dds"] = "guildTrader",
    ["esoui/art/icons/servicemappins/servicepin_magesguild.dds"] = "magesGuild",
    ["esoui/art/icons/servicemappins/servicepin_thievesguild.dds"] = "thievesDen",
    ["esoui/art/icons/servicemappins/servicepin_undaunted.dds"] = "undaunted",
}

TTMP.locationIconKinds = {
    ["esoui/art/icons/servicemappins/servicepin_museum.dds"] = "museum",
    ["esoui/art/icons/servicemappins/servicepin_bank.dds"] = "bank",
    ["esoui/art/icons/servicemappins/servicepin_guildkiosk.dds"] = "guildTrader",
    ["esoui/art/icons/mapkey/mapkey_guildkiosk.dds"] = "guildTrader",
    ["esoui/art/icons/mapkey/mapkey_fence.dds"] = "outlawsRefuge",
    ["esoui/art/icons/servicemappins/servicepin_fence.dds"] = "outlawsRefuge",
    ["esoui/art/icons/mapkey/mapkey_thievesguild.dds"] = "thievesDen",
    ["esoui/art/icons/servicemappins/servicepin_thievesguild.dds"] = "thievesDen",
    ["esoui/art/icons/servicemappins/servicepin_fightersguild.dds"] = "fightersGuild",
    ["esoui/art/icons/servicemappins/servicepin_magesguild.dds"] = "magesGuild",
    ["esoui/art/icons/servicemappins/servicepin_undaunted.dds"] = "undaunted",
    ["esoui/art/icons/mapkey/mapkey_fightersguild.dds"] = "fightersGuild",
    ["esoui/art/icons/mapkey/mapkey_magesguild.dds"] = "magesGuild",
    ["esoui/art/icons/mapkey/mapkey_undaunted.dds"] = "undaunted",
}

TTMP.defaults = {
    showPins = true,
    [TTMP.compassPinType] = true,
    debug = false,
    verboseDebug = false,
    pinDebug = false,
}

TTMP.pinLayoutData = {
    level = 75,
    texture = function(pin)
        local pinTag = pin.m_PinTag
        if type(pinTag) == "table" and pinTag.icon then
            return pinTag.icon
        end
        return TTMP.icons.default
    end,
    size = 32,
    minSize = 24,
    mouseLevel = 120,
}

local function Trim(value)
    return (value or ""):match("^%s*(.-)%s*$")
end

local function NormalizeTexturePath(value)
    return string.lower((value or ""):gsub("\\", "/"):gsub("^/", ""))
end

local function GetChallengeLookupKey(zoneId, poiIndex)
    return zoneId .. ":" .. poiIndex
end

local function IsValidNormalizedMapPoint(x, y)
    return x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1
end

local function GetPOIIconState(poiIcon)
    local normalizedIcon = NormalizeTexturePath(poiIcon)
    if string.sub(normalizedIcon, -14) == "incomplete.dds" then
        return "incomplete"
    elseif string.sub(normalizedIcon, -12) == "complete.dds" then
        return "complete"
    end
    return nil
end

local function GetPOIStateFromPinType(pinType)
    if pinType == MAP_PIN_TYPE_POI_SUGGESTED then
        return "undiscovered"
    elseif pinType == MAP_PIN_TYPE_POI_SEEN then
        return "incomplete"
    elseif pinType == MAP_PIN_TYPE_POI_COMPLETE then
        return "complete"
    end

    return nil
end

local function GetPOIStateFromMapInfo(poiPinType, isShownInCurrentMap, isDiscovered)
    local poiState = GetPOIStateFromPinType(poiPinType)
    if poiState then
        return poiState
    end

    if isDiscovered == false or (isDiscovered == nil and isShownInCurrentMap == false) then
        return "undiscovered"
    end

    return nil
end

local pinTypeNames = {}

local function AddPinTypeName(pinType, name)
    if pinType then
        pinTypeNames[pinType] = name
    end
end

AddPinTypeName(MAP_PIN_TYPE_POI_SUGGESTED, "MAP_PIN_TYPE_POI_SUGGESTED")
AddPinTypeName(MAP_PIN_TYPE_POI_SEEN, "MAP_PIN_TYPE_POI_SEEN")
AddPinTypeName(MAP_PIN_TYPE_POI_COMPLETE, "MAP_PIN_TYPE_POI_COMPLETE")
AddPinTypeName(MAP_PIN_TYPE_WORLD_EVENT_POI_ACTIVE, "MAP_PIN_TYPE_WORLD_EVENT_POI_ACTIVE")
AddPinTypeName(MAP_PIN_TYPE_FAST_TRAVEL_WAYSHRINE, "MAP_PIN_TYPE_FAST_TRAVEL_WAYSHRINE")
AddPinTypeName(MAP_PIN_TYPE_FAST_TRAVEL_WAYSHRINE_CURRENT_LOC, "MAP_PIN_TYPE_FAST_TRAVEL_WAYSHRINE_CURRENT_LOC")

local function GetPinTypeName(pinType)
    return pinTypeNames[pinType] or tostring(pinType)
end

local function GetGenericChallengeIcon(entry, pin, poiIcon, poiState)
    if pin and pin.icon and pin.icon ~= entry.icon then
        local stateIcons = TTMP.stateIconsByIcon[pin.icon]
        local state = poiState or GetPOIIconState(poiIcon)
        if state and stateIcons and stateIcons[state] then
            return stateIcons[state]
        end
        return pin.icon
    end

    local genericIcons = entry.genericIcons
    if genericIcons then
        local state = poiState or GetPOIIconState(poiIcon)
        if state == "undiscovered" and genericIcons.undiscovered then
            return genericIcons.undiscovered
        elseif state == "undiscovered" and genericIcons.incomplete then
            return genericIcons.incomplete
        end
        if state and genericIcons[state] then
            return genericIcons[state]
        end
        if genericIcons.default then
            return genericIcons.default
        end
    end

    return entry.icon or TTMP.icons.default
end

function TTMP:GetChallengeIcon(entry, pin, poiIcon, poiState)
    if entry.genericChallenge then
        return GetGenericChallengeIcon(entry, pin, poiIcon, poiState)
    end

    local stateIcons = self.stateIconsByIcon[pin.icon or entry.icon]
    if poiState and stateIcons and stateIcons[poiState] then
        return stateIcons[poiState]
    end

    local iconOverride = poiIcon and self.poiIconOverrides[NormalizeTexturePath(poiIcon)]
    if iconOverride then
        return iconOverride
    end

    return pin.icon or entry.icon or self.icons.default
end

function TTMP:GetCompassTexturePath(icon)
    icon = icon or self.icons.default
    if string.sub(icon, 1, 1) == "/" then
        return icon
    end

    return "/" .. icon
end

function TTMP:IsPinFilterEnabled()
    if self.savedVars.showPins == false then
        return false
    end

    if self.pinTypeId then
        return self.lmp:IsEnabled(self.pinTypeId) ~= false
    end

    return true
end

function TTMP:IsCompassPinFilterEnabled()
    if not self:IsPinFilterEnabled() then
        return false
    end

    if self.savedVars[self.compassPinType] == false then
        return false
    end

    if self.compassPins then
        return self.compassPins:IsCompassPinEnabled(self.compassPinType) ~= false
    end

    return true
end

function TTMP:SetAllCompassPinTypesEnabled(enabled)
    self.savedVars[self.compassPinType] = enabled

    if self.compassPins then
        self.compassPins:SetCompassPinEnabled(self.compassPinType, enabled)
    end
end

function TTMP:RebuildActiveChallengeLookup()
    local lookup = {}
    local byZoneId = {}
    local dynamicMatchesByType = {}
    local dynamicMatchCount = 0
    local hasLocationMatches = false
    local matches, incompleteById, nextExpiry = self:GetActiveChallengeEntries()

    local function AddStaticPins(match)
        for _, pin in ipairs(match.entry.pins) do
            if pin.zoneId and (pin.poiIndex or pin.id) then
                local key = GetChallengeLookupKey(pin.zoneId, pin.poiIndex or pin.id)
                if not lookup[key] then
                    local pinMatch = { match = match, entry = match.entry, pin = pin }
                    local zoneMatches = byZoneId[pin.zoneId]
                    lookup[key] = pinMatch
                    if zoneMatches then
                        zoneMatches[#zoneMatches + 1] = pinMatch
                    else
                        byZoneId[pin.zoneId] = { pinMatch }
                    end
                end
            end
        end
    end

    for _, match in ipairs(matches) do
        if match.entry.dynamicPinType then
            local dynamicPinType = match.entry.dynamicPinType
            local dynamicMatches = dynamicMatchesByType[dynamicPinType]
            if dynamicMatches then
                dynamicMatches[#dynamicMatches + 1] = match
            else
                dynamicMatchesByType[dynamicPinType] = { match }
            end
            dynamicMatchCount = dynamicMatchCount + 1
            hasLocationMatches = hasLocationMatches or match.entry.locationPins == true
        elseif not match.entry.genericChallenge then
            AddStaticPins(match)
        end
    end

    for _, match in ipairs(matches) do
        if match.entry.genericChallenge and not match.entry.dynamicPinType then
            AddStaticPins(match)
        end
    end

    self.activeChallengePins = lookup
    self.activeMatchesByZoneId = byZoneId
    self.activeDynamicMatchesByType = dynamicMatchesByType
    self.activeDynamicMatchCount = dynamicMatchCount
    self.hasActiveLocationMatches = hasLocationMatches
    self.activityIncompleteById = incompleteById
    self.nextChallengeExpiry = nextExpiry
    self.hasActiveChallenges = #matches > 0
    self.activeChallengeLookupBuilt = true
    return lookup
end

function TTMP:GetPOIChallengeKind(zoneIndex, poiIndex, poiIcon)
    -- Vault Nexus shares dungeon art but only matches its own challenge entry.
    if poiIndex == 76 and GetZoneId(zoneIndex) == 3 then
        return nil
    end

    local normalizedIcon = NormalizeTexturePath(poiIcon)
    if normalizedIcon == "" then
        normalizedIcon = NormalizeTexturePath(select(4, GetPOIMapInfo(zoneIndex, poiIndex)))
    end

    local iconKind = self.poiIconKinds[normalizedIcon]
    if iconKind and iconKind ~= "trial" and iconKind ~= "groupDungeon" then
        return iconKind
    end

    -- ZOS gives explicit map filters priority over shared dungeon/trial artwork.
    local mapFilterOverride = GetPOIMapFilterOverride(zoneIndex, poiIndex)
    if mapFilterOverride == MAP_FILTER_TRIALS then
        return "trial"
    elseif mapFilterOverride == MAP_FILTER_ARENAS then
        return "arena"
    elseif mapFilterOverride == MAP_FILTER_DUNGEONS then
        return "groupDungeon"
    end
    if iconKind then
        return iconKind
    end

    local zoneCompletionType = GetPOIZoneCompletionType(zoneIndex, poiIndex)
    if zoneCompletionType == ZONE_COMPLETION_TYPE_GROUP_BOSSES then
        return "worldBoss"
    elseif zoneCompletionType == ZONE_COMPLETION_TYPE_WORLD_EVENTS then
        return "worldEvent"
    elseif zoneCompletionType == ZONE_COMPLETION_TYPE_DELVES
        or zoneCompletionType == ZONE_COMPLETION_TYPE_GROUP_DELVES
    then
        return "delve"
    elseif zoneCompletionType == ZONE_COMPLETION_TYPE_PUBLIC_DUNGEONS then
        return "publicDungeon"
    elseif zoneCompletionType == ZONE_COMPLETION_TYPE_MUNDUS_STONES then
        return "mundus"
    end

    local worldEventInstanceId = GetPOIWorldEventInstanceId(zoneIndex, poiIndex)
    if worldEventInstanceId ~= 0 then
        return "worldEvent"
    end

    local poiType = GetPOIType(zoneIndex, poiIndex)
    if poiType == POI_TYPE_PUBLIC_DUNGEON then
        return "publicDungeon"
    end

    if GetPOIInstanceType(zoneIndex, poiIndex) == INSTANCE_TYPE_RAID then
        return "trial"
    end

    if poiType == POI_TYPE_GROUP_DUNGEON then
        return "groupDungeon"
    end

    return nil
end

function TTMP:IsBonusDynamicMatch(match, zoneId)
    local entry = match.entry
    return zoneId
        and entry.bonusIcon
        and entry.bonusZoneIds
        and entry.bonusZoneIds[zoneId]
        and entry.bonusActivityIds
        and entry.bonusActivityIds[match.activityId]
end

function TTMP:GetDynamicPinIcon(match, zoneId)
    if self:IsBonusDynamicMatch(match, zoneId) then
        return match.entry.bonusIcon
    end

    return match.entry.icon
end

function TTMP:CreateDynamicPinMatch(match, zoneIndex, poiIndex)
    local zoneId = GetZoneId(zoneIndex)
    local pin = {
        type = "poi",
        zoneId = zoneId,
        poiIndex = poiIndex,
        label = match.entry.pinLabel or match.entry.label,
        icon = self:GetDynamicPinIcon(match, zoneId),
    }

    return {
        match = match,
        entry = match.entry,
        pin = pin,
    }
end

function TTMP:GetDynamicMatchForPOI(zoneIndex, poiIndex, poiIcon)
    if self.activeDynamicMatchCount == 0 then
        return nil
    end

    local challengeKind = self:GetPOIChallengeKind(zoneIndex, poiIndex, poiIcon)
    if not challengeKind or not self.activeDynamicMatchesByType[challengeKind] then
        return nil
    end
    local match = self:GetDynamicChallengeMatch(challengeKind, GetZoneId(zoneIndex))
    if match then
        return self:CreateDynamicPinMatch(match, zoneIndex, poiIndex)
    end
end

function TTMP:GetDynamicChallengeMatch(challengeKind, zoneId)
    local matches = challengeKind and self.activeDynamicMatchesByType[challengeKind]
    if not matches then
        return nil
    end

    local selectedMatch
    for _, match in ipairs(matches) do
        local zoneRestrictions = match.entry.activityZoneIds
        local allowedZones = zoneRestrictions and zoneRestrictions[match.activityId]
        if not allowedZones or allowedZones[zoneId] then
            if self:IsBonusDynamicMatch(match, zoneId) then
                selectedMatch = match
                break
            end
            selectedMatch = selectedMatch or match
        end
    end

    return selectedMatch
end

function TTMP:GetMatchForLocation(locationIndex, icon)
    if not self.hasActiveLocationMatches or GetMapType() > MAPTYPE_ZONE then
        return nil
    end

    local kind = self.locationIconKinds[NormalizeTexturePath(icon)]
    if not kind or not self.activeDynamicMatchesByType[kind] then
        return nil
    end

    local zoneId = GetZoneId(GetCurrentMapZoneIndex())
    local match = self:GetDynamicChallengeMatch(kind, zoneId)
    if match then
        local locationsByMap = match.entry.locationIndicesByMapId
        if locationsByMap then
            local locations = locationsByMap[GetCurrentMapId()]
            if not locations or not locations[locationIndex] then
                return nil
            end
        end
        return {
            match = match,
            entry = match.entry,
            pin = {
                type = "location",
                id = "location:" .. locationIndex,
                zoneId = zoneId,
                label = GetMapLocationTooltipHeader(locationIndex),
                icon = self:GetDynamicPinIcon(match, zoneId),
            },
        }
    end
end

function TTMP:GetActiveChallengeMatchesForZone(zoneId)
    if not self.activeChallengeLookupBuilt then
        self:RebuildActiveChallengeLookup()
    end

    return self.activeMatchesByZoneId[zoneId] or {}
end

function TTMP:GetGlobalMapCoordinates(zoneId, zoneX, zoneY, sourceMapId)
    if not IsValidNormalizedMapPoint(zoneX, zoneY) then
        return nil, nil
    end

    local mapId = sourceMapId or GetMapIdByZoneId(zoneId)
    if not mapId or mapId == 0 then
        return nil, nil
    end

    local offsetX, offsetZ, width, height = GetUniversallyNormalizedMapInfo(mapId)
    if width <= 0 or height <= 0 then
        return nil, nil
    end

    local currentMapId = GetCurrentMapId()
    if not currentMapId or currentMapId == 0 then
        return nil, nil
    end

    local currentOffsetX, currentOffsetZ, currentWidth, currentHeight = GetUniversallyNormalizedMapInfo(currentMapId)
    if currentWidth <= 0 or currentHeight <= 0 then
        return nil, nil
    end

    local universalX = offsetX + zoneX * width
    local universalZ = offsetZ + zoneY * height
    local globalX = (universalX - currentOffsetX) / currentWidth
    local globalY = (universalZ - currentOffsetZ) / currentHeight
    if IsValidNormalizedMapPoint(globalX, globalY) then
        return globalX, globalY
    end

    return nil, nil
end

function TTMP:GetFastTravelCoordinatesForPOI(zoneIndex, poiIndex)
    if not zoneIndex or not poiIndex then
        return nil, nil, nil
    end

    if not self.fastTravelNodesByPOI then
        local lookup = {}
        for nodeIndex = 1, GetNumFastTravelNodes() do
            local nodeZoneIndex, nodePOIIndex = GetFastTravelNodePOIIndicies(nodeIndex)
            if nodeZoneIndex and nodePOIIndex then
                local key = GetChallengeLookupKey(nodeZoneIndex, nodePOIIndex)
                local nodes = lookup[key]
                if not nodes then
                    nodes = {}
                    lookup[key] = nodes
                end
                nodes[#nodes + 1] = nodeIndex
            end
        end
        self.fastTravelNodesByPOI = lookup
    end

    local nodes = self.fastTravelNodesByPOI[GetChallengeLookupKey(zoneIndex, poiIndex)]
    if not nodes then
        return nil, nil, nil
    end
    for _, nodeIndex in ipairs(nodes) do
        local known, _, normalizedX, normalizedY, icon, _, _, isShownInCurrentMap = GetFastTravelNodeInfo(nodeIndex)
        if known and isShownInCurrentMap and IsValidNormalizedMapPoint(normalizedX, normalizedY) then
            return normalizedX, normalizedY, icon
        end
    end

    return nil, nil, nil
end

function TTMP:GetZoneStoryCoordinatesForPOI(zoneId, zoneIndex, poiIndex)
    if not zoneId or zoneId == 0 or not zoneIndex or not poiIndex then
        return nil, nil, nil
    end

    local zoneCompletionType = GetPOIZoneCompletionType(zoneIndex, poiIndex)
    if not zoneCompletionType or zoneCompletionType == ZONE_COMPLETION_TYPE_NONE then
        return nil, nil, nil
    end

    local numActivities = GetNumZoneActivitiesForZoneCompletionType(zoneId, zoneCompletionType)
    for activityIndex = 1, numActivities do
        local activityId = GetZoneActivityIdForZoneCompletionType(zoneId, zoneCompletionType, activityIndex)
        local activityZoneIndex, activityPOIIndex
        if activityId and activityId ~= 0 then
            activityZoneIndex, activityPOIIndex = GetPOIIndices(activityId)
        end
        if activityZoneIndex == zoneIndex and activityPOIIndex == poiIndex then
            local normalizedX, normalizedY, _, isShownInCurrentMap = GetNormalizedPositionForZoneStoryActivityId(zoneId, zoneCompletionType, activityId)
            if isShownInCurrentMap and IsValidNormalizedMapPoint(normalizedX, normalizedY) then
                return normalizedX, normalizedY, zoneCompletionType
            end
        end
    end

    return nil, nil, nil
end

function TTMP:GetMatchForPOI(zoneIndex, poiIndex, poiIcon)
    if not zoneIndex or not poiIndex then
        return nil
    end

    if not self.activeChallengeLookupBuilt then
        self:RebuildActiveChallengeLookup()
    end

    local zoneId = GetZoneId(zoneIndex)
    return self.activeChallengePins[GetChallengeLookupKey(zoneId, poiIndex)] or self:GetDynamicMatchForPOI(zoneIndex, poiIndex, poiIcon)
end

function TTMP:GetNativePinZoneAndPOI(pin)
    local pinType = pin:GetPinType()

    if pin:IsPOI() or pinType == MAP_PIN_TYPE_POI_SUGGESTED then
        return pin:GetPOIZoneIndex(), pin:GetPOIIndex()
    end

    if pin:IsFastTravelWayShrine() then
        local nodeIndex = pin:GetFastTravelNodeIndex()
        if nodeIndex then
            return GetFastTravelNodePOIIndicies(nodeIndex)
        end
    end

    if pin:IsWorldEventPOIPin() then
        return pin:GetPOIZoneIndex(), pin:GetPOIIndex()
    end

    return nil, nil
end

function TTMP:GetNativePinPOIState(pin, zoneIndex, poiIndex)
    local pinType = pin:GetPinType()
    local pinState = GetPOIStateFromPinType(pinType)
    if pinState then
        return pinState
    end

    if zoneIndex and zoneIndex > 0 and poiIndex and poiIndex > 0 then
        local poiPinType = select(3, GetPOIMapInfo(zoneIndex, poiIndex))
        local poiState = GetPOIStateFromPinType(poiPinType)
        if poiState then
            return poiState
        end
    end

    return nil
end

function TTMP:GetMatchForNativePin(pin, poiIcon)
    if not self:IsPinFilterEnabled() then
        return nil
    end

    if not self.activeChallengeLookupBuilt then
        self:RebuildActiveChallengeLookup()
    end
    if not self.hasActiveChallenges then
        return nil
    end

    if pin:GetPinType() == MAP_PIN_TYPE_LOCATION then
        return self:GetMatchForLocation(pin:GetLocationIndex(), poiIcon)
    end

    local zoneIndex, poiIndex = self:GetNativePinZoneAndPOI(pin)
    local match = self:GetMatchForPOI(zoneIndex, poiIndex, poiIcon)
    if match then
        return match, self:GetNativePinPOIState(pin, zoneIndex, poiIndex)
    end
    return nil
end

function TTMP:ClearPinDebugCache()
    self.pinDebugCache = {}
end

function TTMP:DebugNativePin(pin, originalIcon, match, poiState, challengeIcon)
    if not self.savedVars or not self.savedVars.pinDebug then
        return
    end

    local zoneIndex, poiIndex = self:GetNativePinZoneAndPOI(pin)
    if not zoneIndex or not poiIndex then
        return
    end

    local pinType = pin:GetPinType()
    local zoneId = zoneIndex > 0 and GetZoneId(zoneIndex) or 0
    local poiPinType
    local mapIcon = ""
    if zoneIndex > 0 and poiIndex > 0 then
        local _, _, mapPinType, icon = GetPOIMapInfo(zoneIndex, poiIndex)
        poiPinType, mapIcon = mapPinType, icon
    end

    local matchName = "none"
    if match then
        matchName = match.entry.key or match.entry.label or match.entry.pinLabel or match.pin.label or "match"
    end

    local debugKey = string.format("%s:%s:%s:%s:%s:%s:%s",
        tostring(pinType),
        tostring(zoneId),
        tostring(poiIndex),
        tostring(poiPinType),
        tostring(poiState),
        matchName,
        tostring(challengeIcon))

    if self.pinDebugCache[debugKey] then
        return
    end
    self.pinDebugCache[debugKey] = true

    self:Print(string.format("pin type=%s(%s) zoneId=%s poi=%s mapType=%s(%s) state=%s orig=%s mapIcon=%s match=%s icon=%s",
        GetPinTypeName(pinType),
        tostring(pinType),
        tostring(zoneId),
        tostring(poiIndex),
        GetPinTypeName(poiPinType),
        tostring(poiPinType),
        tostring(poiState),
        tostring(originalIcon),
        tostring(mapIcon),
        matchName,
        tostring(challengeIcon)))
end

function TTMP:RefreshNativePins()
    if not self.initialized then
        return
    end

    ZO_WorldMap_RefreshAllPOIs()
    ZO_WorldMap_RefreshWayshrines()

    local locationPins = ZO_WorldMap_GetPinManager():AddPinsToArray({}, "loc")
    for _, pin in ipairs(locationPins) do
        if pin.ttmpChallengeTextureActive
            or (self.hasActiveLocationMatches and self.locationIconKinds[NormalizeTexturePath(pin:GetLocationIcon())])
        then
            pin:SetData(pin:GetPinTypeAndTag())
        end
    end
end

local function GetNativePinTexture(originalTexture, pin)
    if type(originalTexture) == "function" then
        return originalTexture(pin)
    elseif type(originalTexture) == "string" then
        return originalTexture
    end

    return nil
end

function TTMP:HookNativePinTexture(pinType)
    local pinData = ZO_MapPin.PIN_DATA[pinType]
    if not pinData or self.nativePinTextureCallbacks[pinType] then
        return false
    end

    local originalTexture = pinData.texture
    local originalIsAnimated = pinData.isAnimated
    self.nativePinTextureCallbacks[pinType] = originalTexture

    pinData.texture = function(pin)
        local originalIcon, pulseTexture, glowTexture = GetNativePinTexture(originalTexture, pin)
        local match, poiState = TTMP:GetMatchForNativePin(pin, originalIcon)
        local challengeIcon
        if match then
            challengeIcon = TTMP:GetChallengeIcon(match.entry, match.pin, originalIcon, poiState)
            if challengeIcon then
                pin.ttmpChallengeTextureActive = true
                TTMP.mapPinsActive = true
                TTMP:DebugNativePin(pin, originalIcon, match, poiState, challengeIcon)
                return challengeIcon
            end
        end

        pin.ttmpChallengeTextureActive = false
        TTMP:DebugNativePin(pin, originalIcon, match, poiState, challengeIcon)
        return originalIcon, pulseTexture, glowTexture
    end

    if pinType == MAP_PIN_TYPE_WORLD_EVENT_POI_ACTIVE then
        pinData.isAnimated = function(pin)
            if pin.ttmpChallengeTextureActive then
                return false
            end
            if type(originalIsAnimated) == "function" then
                return originalIsAnimated(pin)
            end
            return originalIsAnimated
        end
    end

    return true
end

function TTMP:RegisterNativeTextureHooks()
    if self.nativeTextureHooksRegistered then
        return
    end

    self.nativeTextureHooksRegistered = true
    self:HookNativePinTexture(MAP_PIN_TYPE_POI_SUGGESTED)
    self:HookNativePinTexture(MAP_PIN_TYPE_POI_SEEN)
    self:HookNativePinTexture(MAP_PIN_TYPE_POI_COMPLETE)
    self:HookNativePinTexture(MAP_PIN_TYPE_WORLD_EVENT_POI_ACTIVE)
    self:HookNativePinTexture(MAP_PIN_TYPE_FAST_TRAVEL_WAYSHRINE)
    self:HookNativePinTexture(MAP_PIN_TYPE_FAST_TRAVEL_WAYSHRINE_CURRENT_LOC)
    self:HookNativePinTexture(MAP_PIN_TYPE_LOCATION)
end

function TTMP:CreatePinForMatch(match, pin, x, y, poiIcon, poiState)
    local entry = match.entry
    local pinTag = {
        id = string.format("%s:%s:%s", entry.key or "challenge", pin.zoneId or 0, pin.poiIndex or pin.id or 0),
        label = pin.label or entry.label,
        icon = self:GetChallengeIcon(entry, pin, poiIcon, poiState),
        activityName = match.activityName,
        activityDescription = not entry.hideDescription and match.activityDescription or nil,
    }

    self.lmp:CreatePin(self.pinType, pinTag, x, y)
end

function TTMP:AddManualPinForMatch(match, pin, zoneIndex, seen)
    if not (pin.poiIndex or pin.id) then
        return 0
    end

    local key = GetChallengeLookupKey(pin.zoneId, pin.poiIndex or pin.id)
    if seen[key] then
        return 0
    end
    seen[key] = true

    local x, y, poiIcon, poiPinType, isShownInCurrentMap, isDiscovered = self:GetChallengePinCoordinates(pin, zoneIndex)
    local poiState = GetPOIStateFromMapInfo(poiPinType, isShownInCurrentMap, isDiscovered)
    if x and y and (pin.type == "coordinates" or poiState == "undiscovered") then
        self:CreatePinForMatch(match, pin, x, y, poiIcon, poiState)
        return 1
    end

    return 0
end

function TTMP:AddGlobalPinForMatch(match, pin, zoneIndex, seen)
    local icon = pin.icon or self:GetDynamicPinIcon(match, pin.zoneId)
    if not self.goldBookIcons[icon] or not pin.zoneId or not (pin.poiIndex or pin.id) then
        return 0
    end

    local key = GetChallengeLookupKey(pin.zoneId, pin.poiIndex or pin.id)
    if seen[key] then
        return 0
    end
    seen[key] = true

    local globalX, globalY, poiIcon, poiState
    if pin.type == "coordinates" then
        globalX, globalY = self:GetGlobalMapCoordinates(pin.zoneId, pin.x, pin.y, pin.mapId)
    else
        local x, y, icon, poiPinType, isShownInCurrentMap, isDiscovered = self:GetPOICoordinates(zoneIndex, pin.poiIndex)
        local fastTravelIcon
        globalX, globalY, fastTravelIcon = self:GetFastTravelCoordinatesForPOI(zoneIndex, pin.poiIndex)
        if not globalX then
            globalX, globalY = self:GetZoneStoryCoordinatesForPOI(pin.zoneId, zoneIndex, pin.poiIndex)
        end
        if not globalX then
            if isShownInCurrentMap then
                -- ESO already expressed this POI in the current overview map.
                globalX, globalY = x, y
            else
                globalX, globalY = self:GetGlobalMapCoordinates(pin.zoneId, x, y)
            end
        end
        poiIcon = fastTravelIcon or icon
        poiState = GetPOIStateFromMapInfo(poiPinType, isShownInCurrentMap, isDiscovered)
    end

    if globalX and globalY then
        self:CreatePinForMatch(match, pin, globalX, globalY, poiIcon, poiState)
        return 1
    end

    return 0
end

function TTMP:AddGlobalPins()
    if not self.activeChallengeLookupBuilt then
        self:RebuildActiveChallengeLookup()
    end

    local seen = {}
    local created = 0
    self.fastTravelNodesByPOI = nil

    for zoneId, pinMatches in pairs(self.activeMatchesByZoneId) do
        local zoneIndex = GetZoneIndex(zoneId)
        if zoneIndex then
            for _, pinMatch in ipairs(pinMatches) do
                created = created + self:AddGlobalPinForMatch(pinMatch.match, pinMatch.pin, zoneIndex, seen)
            end
        end
    end

    local dynamicZones = {}
    for _, matches in pairs(self.activeDynamicMatchesByType) do
        for _, match in ipairs(matches) do
            local entry = match.entry
            local zones
            if self.goldBookIcons[entry.icon] then
                local allowedZones = entry.activityZoneIds and entry.activityZoneIds[match.activityId]
                if entry.overviewPins then
                    for _, pin in ipairs(entry.overviewPins) do
                        if not allowedZones or allowedZones[pin.zoneId] then
                            created = created + self:AddGlobalPinForMatch(match, pin, nil, seen)
                        end
                    end
                else
                    zones = allowedZones
                end
            elseif entry.bonusActivityIds and entry.bonusActivityIds[match.activityId]
                and self.goldBookIcons[entry.bonusIcon]
            then
                zones = entry.bonusZoneIds
            end
            if zones then
                for zoneId in pairs(zones) do
                    dynamicZones[zoneId] = true
                end
            end
        end
    end

    for zoneId in pairs(dynamicZones) do
        local zoneIndex = GetZoneIndex(zoneId)
        if zoneIndex then
            for poiIndex = 1, GetNumPOIs(zoneIndex) do
                if not seen[GetChallengeLookupKey(zoneId, poiIndex)] then
                    local pinMatch = self:GetDynamicMatchForPOI(zoneIndex, poiIndex)
                    if pinMatch then
                        created = created + self:AddGlobalPinForMatch(pinMatch.match, pinMatch.pin, zoneIndex, seen)
                    end
                end
            end
        end
    end

    self:Debug("Created %d global challenge pin(s).", true, created)
end

function TTMP:AddPins()
    if not self:IsPinFilterEnabled() then
        return
    end

    -- The shared map control is also used by minimaps.
    if ZO_WorldMapContainer:IsHidden() then
        self.mapPinsDirty = true
        return
    end
    if not self.activeChallengeLookupBuilt then
        self:RebuildActiveChallengeLookup()
    end
    if not self.hasActiveChallenges then
        return
    end
    self.mapPinsActive = true

    if GLOBAL_MAP_TYPES[GetMapType()] then
        self:AddGlobalPins()
        return
    end

    local zoneIndex = GetCurrentMapZoneIndex()
    local zoneId = zoneIndex and GetZoneId(zoneIndex)
    if not zoneId or zoneId == 0 then
        return
    end

    local seen = {}
    local created = 0

    for _, pinMatch in ipairs(self:GetActiveChallengeMatchesForZone(zoneId)) do
        created = created + self:AddManualPinForMatch(pinMatch.match, pinMatch.pin, zoneIndex, seen)
    end

    if self.activeDynamicMatchCount > 0 then
        for poiIndex = 1, GetNumPOIs(zoneIndex) do
            local key = GetChallengeLookupKey(zoneId, poiIndex)
            if not seen[key] then
                local x, y, poiIcon, poiPinType, isShownInCurrentMap, isDiscovered = self:GetPOICoordinates(zoneIndex, poiIndex)
                local poiState = GetPOIStateFromMapInfo(poiPinType, isShownInCurrentMap, isDiscovered)
                if x and y and poiState == "undiscovered" then
                    local pinMatch = self:GetDynamicMatchForPOI(zoneIndex, poiIndex, poiIcon)
                    if pinMatch then
                        self:CreatePinForMatch(pinMatch.match, pinMatch.pin, x, y, poiIcon, poiState)
                        created = created + 1
                    end
                end
            end
        end
    end

    self:Debug("Created %d custom challenge pin(s) for zoneId %s.", true, created, tostring(zoneId))
end

function TTMP:CreateTooltip(pin)
    local _, pinTag = pin:GetPinTypeAndTag()
    if type(pinTag) ~= "table" then
        return
    end

    InformationTooltip:AddLine(pinTag.label or "Tome Challenge")

    if pinTag.activityName and pinTag.activityName ~= "" then
        InformationTooltip:AddLine(pinTag.activityName)
    end

    if pinTag.activityDescription and pinTag.activityDescription ~= "" then
        InformationTooltip:AddLine(pinTag.activityDescription)
    end
end

function TTMP:SetWaypointFromPin(pin)
    local x, y = pin:GetNormalizedPosition()
    if x and y then
        PingMap(MAP_PIN_TYPE_PLAYER_WAYPOINT, MAP_TYPE_LOCATION_CENTERED, x, y)
    end
end

function TTMP:CreateCompassPinTag(match, pin, poiIcon, poiState)
    local entry = match.entry
    local icon = self:GetChallengeIcon(entry, pin, poiIcon, poiState)
    return {
        label = pin.label or entry.label,
        compassIcon = self:GetCompassTexturePath(icon),
    }
end

function TTMP:GetCompassZoneMatches(zoneIndex, zoneId)
    local mapId = GetCurrentMapId()
    if self.activeCompassZoneIndex == zoneIndex and self.activeCompassZoneId == zoneId
        and self.activeCompassMapId == mapId and self.activeCompassZoneMatches
    then
        return self.activeCompassZoneMatches
    end

    local zoneMatches = {}
    local seen = {}

    local function AddCompassZoneMatch(pinMatch, x, y, poiIcon, poiState)
        local pinTag = self:CreateCompassPinTag(pinMatch.match, pinMatch.pin, poiIcon, poiState)
        zoneMatches[#zoneMatches + 1] = {
            pinTag = pinTag,
            x = x,
            y = y,
        }
    end

    for _, pinMatch in ipairs(self:GetActiveChallengeMatchesForZone(zoneId)) do
        local x, y, poiIcon, poiPinType, isShownInCurrentMap, isDiscovered = self:GetChallengePinCoordinates(pinMatch.pin, zoneIndex)
        if x and y then
            AddCompassZoneMatch(pinMatch, x, y, poiIcon, GetPOIStateFromMapInfo(poiPinType, isShownInCurrentMap, isDiscovered))
        end
        seen[GetChallengeLookupKey(pinMatch.pin.zoneId, pinMatch.pin.poiIndex or pinMatch.pin.id)] = true
    end

    if self.activeDynamicMatchCount > 0 then
        for poiIndex = 1, GetNumPOIs(zoneIndex) do
            local key = GetChallengeLookupKey(zoneId, poiIndex)
            if not seen[key] then
                local x, y, poiIcon, poiPinType, isShownInCurrentMap, isDiscovered = self:GetPOICoordinates(zoneIndex, poiIndex)
                if x and y then
                    local pinMatch = self:GetDynamicMatchForPOI(zoneIndex, poiIndex, poiIcon)
                    if pinMatch then
                        seen[key] = true
                        AddCompassZoneMatch(pinMatch, x, y, poiIcon, GetPOIStateFromMapInfo(poiPinType, isShownInCurrentMap, isDiscovered))
                    end
                end
            end
        end
    end

    if self.hasActiveLocationMatches then
        for locationIndex = 1, GetNumMapLocations() do
            if IsMapLocationVisible(locationIndex) then
                local icon, x, y = GetMapLocationIcon(locationIndex)
                if IsValidNormalizedMapPoint(x, y) then
                    local pinMatch = self:GetMatchForLocation(locationIndex, icon)
                    if pinMatch then
                        AddCompassZoneMatch(pinMatch, x, y, icon)
                    end
                end
            end
        end
    end

    self.activeCompassZoneIndex = zoneIndex
    self.activeCompassZoneId = zoneId
    self.activeCompassMapId = mapId
    self.activeCompassZoneMatches = zoneMatches
    return zoneMatches
end

function TTMP:AddCompassPins()
    if not self.compassPins or not self:IsCompassPinFilterEnabled() then
        return
    end

    if not self.activeChallengeLookupBuilt then
        self:RebuildActiveChallengeLookup()
    end
    if not self.hasActiveChallenges then
        return
    end

    if GetMapType() > MAPTYPE_ZONE then
        return
    end

    local zoneIndex = GetCurrentMapZoneIndex()
    local zoneId = GetZoneId(zoneIndex)
    if not zoneId or zoneId == 0 then
        return
    end

    local zoneMatches = self:GetCompassZoneMatches(zoneIndex, zoneId)
    for _, zoneMatch in ipairs(zoneMatches) do
        local pinTag = zoneMatch.pinTag
        self.compassPins:CreatePin(self.compassPinType, pinTag, zoneMatch.x, zoneMatch.y, pinTag.label)
    end
    self.compassPinsActive = #zoneMatches > 0

    self:Debug("Created %d compass challenge pin(s) for zoneId %s.", true, #zoneMatches, tostring(zoneId))
end

function TTMP:RefreshCompassPins()
    if self.compassPins and self.compassRegistered then
        if self.compassPinsActive or (self.hasActiveChallenges and self:IsCompassPinFilterEnabled()) then
            self.compassPinsActive = false
            self.compassPins:RefreshPins(self.compassPinType)
        end
    end
end

function TTMP:RegisterCompassPins()
    self.compassPins = COMPASS_PINS
    if not self.compassPins then
        self:Debug("CustomCompassPins is not loaded; compass pins are disabled.", true)
        return false
    end

    if self.compassRegistered then
        return true
    end

    local defaultCompassIcon = self:GetCompassTexturePath(self.icons.default)
    local compassLayout = {
        maxDistance = self.compassOverlayMaxDistance,
        texture = defaultCompassIcon,
        mapPinTypeString = self.pinType,
        onToggleCallback = function(_, enabled) TTMP:OnPinFilterChanged(enabled) end,
        additionalLayout = {
            update = function(compassPin)
                local pinTag = compassPin.pinTag
                local compassIcon = pinTag and pinTag.compassIcon or defaultCompassIcon
                local background = compassPin.ttmpBackground
                if not background then
                    background = compassPin:GetNamedChild("Background")
                    compassPin.ttmpBackground = background
                end
                if background and compassPin.ttmpCompassIcon ~= compassIcon then
                    background:SetTexture(compassIcon)
                    compassPin.ttmpCompassIcon = compassIcon
                end
                if not compassPin.ttmpCompassLayoutApplied then
                    compassPin.ttmpOriginalDrawLayer = compassPin:GetDrawLayer()
                    compassPin.ttmpOriginalDrawLevel = compassPin:GetDrawLevel()
                    if background then
                        compassPin.ttmpOriginalBackgroundLevel = background:GetDrawLevel()
                        background:SetDrawLevel(TTMP.compassOverlayDrawLevel)
                    end
                    compassPin:SetDrawLayer(DL_OVERLAY)
                    compassPin:SetDrawLevel(TTMP.compassOverlayDrawLevel)
                    compassPin.ttmpCompassLayoutApplied = true
                end
            end,
            reset = function(compassPin)
                if not compassPin.ttmpCompassLayoutApplied then
                    return
                end
                compassPin:SetDrawLayer(compassPin.ttmpOriginalDrawLayer)
                compassPin:SetDrawLevel(compassPin.ttmpOriginalDrawLevel)
                local background = compassPin.ttmpBackground
                if background then
                    background:SetDrawLevel(compassPin.ttmpOriginalBackgroundLevel)
                end
                compassPin.ttmpCompassIcon = nil
                compassPin.ttmpCompassLayoutApplied = nil
                compassPin.ttmpOriginalDrawLayer = nil
                compassPin.ttmpOriginalDrawLevel = nil
                compassPin.ttmpOriginalBackgroundLevel = nil
            end,
        },
    }

    self.compassPins:AddCustomPin(self.compassPinType, function()
        TTMP:AddCompassPins()
    end, compassLayout, self.savedVars)

    self.compassRegistered = true
    return true
end

function TTMP:ResetActiveChallengeCache()
    self.activeChallengePins = {}
    self.activeMatchesByZoneId = {}
    self.activeDynamicMatchesByType = {}
    self.activeDynamicMatchCount = 0
    self.hasActiveLocationMatches = false
    self.hasActiveChallenges = false
    self.nextChallengeExpiry = nil
    self.activeCompassZoneIndex = nil
    self.activeCompassZoneId = nil
    self.activeCompassMapId = nil
    self.activeCompassZoneMatches = nil
    self.activeChallengeLookupBuilt = false
end

function TTMP:RegisterChallengeData(data)
    for _, entry in ipairs(data) do
        for _, activityId in ipairs(entry.activityIds) do
            local entries = self.challengeEntriesByActivityId[activityId]
            if not entries then
                entries = {}
                self.challengeEntriesByActivityId[activityId] = entries
            end
            entries[#entries + 1] = entry
        end
    end
    self:ResetActiveChallengeCache()
end

function TTMP:Print(message)
    CHAT_SYSTEM:AddMessage(string.format("|cFFD700[Tamriel Tomes Pins]|r %s", message))
end

function TTMP:Debug(message, verbose, ...)
    if not self.savedVars or not self.savedVars.debug then
        return
    end

    if verbose and not self.savedVars.verboseDebug then
        return
    end

    if select("#", ...) > 0 then
        message = string.format(message, ...)
    end
    self:Print(message)
end

function TTMP:IsActivityIncomplete(index)
    local totalNumTimesClaimable = GetTimedActivityTotalNumTimesClaimable(index)
    if totalNumTimesClaimable > 0
        and GetTimedActivityNumTimesClaimed(index) >= totalNumTimesClaimable
    then
        return false
    end

    local endTimeS = GetTimedActivityEndTimeS(index)
    if endTimeS > 0 and endTimeS <= GetTimeStamp() then
        return false
    end
    return GetTimedActivityProgress(index) < GetTimedActivityMaxProgress(index), endTimeS
end

function TTMP:GetActiveChallengeEntries()
    local matches = {}
    local seenEncodedIds = {}
    local matchedActivityIds = {}
    local incompleteById = {}
    local nextExpiry

    if not IsTimedActivitySystemAvailable() then
        return matches, incompleteById
    end

    local numActivities = GetNumTimedActivities()
    for index = 1, numActivities do
        local activityId = GetTimedActivityId(index)
        local entries = self.challengeEntriesByActivityId[activityId]
        if entries then
            local encodedId = Id64ToString(GetTimedActivityEncodedId(index))
            if seenEncodedIds[encodedId] then
                self:Debug("Skipped duplicate activity encoded ID %s.", true, encodedId)
            else
                seenEncodedIds[encodedId] = true
                local incomplete, endTimeS = self:IsActivityIncomplete(index)
                incompleteById[encodedId] = incomplete
                if incomplete and endTimeS > 0 and (not nextExpiry or endTimeS < nextExpiry) then
                    nextExpiry = endTimeS
                end
                if incomplete and not matchedActivityIds[activityId] then
                    matchedActivityIds[activityId] = true
                    local activityName = GetTimedActivityName(index)
                    local activityDescription = GetTimedActivityDescription(index)
                    for _, entry in ipairs(entries) do
                        matches[#matches + 1] = {
                            entry = entry,
                            activityId = activityId,
                            activityName = activityName,
                            activityDescription = activityDescription,
                        }
                    end
                end
            end
        end
    end

    return matches, incompleteById, nextExpiry
end

function TTMP:GetChallengePinCoordinates(pin, zoneIndex)
    if pin.type == "coordinates" then
        -- These coordinates belong to the zone map, not its city/interior submaps.
        if GetCurrentMapId() == GetMapIdByZoneId(pin.zoneId) then
            return pin.x, pin.y
        end
        return nil, nil
    end

    return self:GetPOICoordinates(zoneIndex, pin.poiIndex)
end

function TTMP:GetPOICoordinates(zoneIndex, poiIndex)
    if not zoneIndex or not poiIndex then
        return nil, nil
    end

    local normalizedX, normalizedY, poiPinType, icon, isShownInCurrentMap, _, isDiscovered = GetPOIMapInfo(zoneIndex, poiIndex)
    if not IsValidNormalizedMapPoint(normalizedX, normalizedY) then
        return nil, nil
    end

    return normalizedX, normalizedY, icon, poiPinType, isShownInCurrentMap, isDiscovered
end

function TTMP:RefreshMapPins()
    local enabled = self.hasActiveChallenges and self:IsPinFilterEnabled()
    if not enabled and not self.mapPinsActive and not self.savedVars.pinDebug then
        self.mapPinsDirty = false
        return
    end

    if ZO_WorldMapContainer:IsHidden() then
        self.mapPinsDirty = true
        return
    end

    self.mapPinsDirty = false
    self:ClearPinDebugCache()
    self:RefreshNativePins()
    self.lmp:RefreshPins(self.pinType)
    self.mapPinsActive = enabled
end

function TTMP:RefreshPins(rebuildChallenges)
    if not self.initialized then
        return
    end

    if rebuildChallenges ~= false or not self.activeChallengeLookupBuilt
        or (self.nextChallengeExpiry and self.nextChallengeExpiry <= GetTimeStamp())
    then
        self:RebuildActiveChallengeLookup()
    end
    self.activeCompassZoneIndex = nil
    self.activeCompassZoneId = nil
    self.activeCompassMapId = nil
    self.activeCompassZoneMatches = nil
    self:RefreshMapPins()
    self:RefreshCompassPins()
end

function TTMP:QueueRefreshPins(rebuildChallenges)
    if rebuildChallenges ~= false then
        self.refreshChallengesQueued = true
    end
    if self.refreshQueued then
        return
    end

    self.refreshQueued = true
    local refresh = function()
        local rebuild = TTMP.refreshChallengesQueued == true
        TTMP.refreshQueued = false
        TTMP.refreshChallengesQueued = false
        TTMP:RefreshPins(rebuild)
    end

    zo_callLater(refresh, 100)
end

function TTMP:OnPinFilterChanged(enabled)
    self:SetAllCompassPinTypesEnabled(enabled)
    self:QueueRefreshPins(false)
end

function TTMP:RegisterPins()
    self.lmp = LibMapPins

    local tooltipCreator = {
        creator = function(pin)
            TTMP:CreateTooltip(pin)
        end,
        tooltip = ZO_MAP_TOOLTIP_MODE.INFORMATION,
    }

    local leftClickHandler = {
        {
            name = "Set Waypoint",
            callback = function(pin)
                TTMP:SetWaypointFromPin(pin)
            end,
        },
    }

    self.pinTypeId = self.lmp:AddPinType(self.pinType, function()
        TTMP:AddPins()
    end, nil, self.pinLayoutData, tooltipCreator)

    self.lmp:SetClickHandlers(self.pinTypeId, leftClickHandler, nil)
    local pinData = ZO_WorldMap_GetPinManager().customPins[self.pinTypeId]
    pinData.onToggleCallback = function(_, enabled) TTMP:OnPinFilterChanged(enabled) end
    self.lmp:AddPinFilter(self.pinTypeId, "Tome Challenge Pins", false, self.savedVars, "showPins")

    return true
end

function TTMP:RegisterEvents()
    EVENT_MANAGER:RegisterForEvent(self.addonName, EVENT_REWARD_TRACK_REWARD_CLAIMED, function()
        TTMP:QueueRefreshPins()
    end)

    EVENT_MANAGER:RegisterForEvent(self.addonName, EVENT_REWARD_TRACK_REWARDS_CLAIMED, function()
        TTMP:QueueRefreshPins()
    end)

    EVENT_MANAGER:RegisterForEvent(self.addonName, EVENT_TIMED_ACTIVITIES_UPDATED, function()
        TTMP:QueueRefreshPins()
    end)

    EVENT_MANAGER:RegisterForEvent(self.addonName, EVENT_TIMED_ACTIVITY_PROGRESS_UPDATED, function(_, index)
        if not TTMP.challengeEntriesByActivityId[GetTimedActivityId(index)] then
            return
        end
        local encodedId = Id64ToString(GetTimedActivityEncodedId(index))
        local incomplete = TTMP:IsActivityIncomplete(index)
        if TTMP.activityIncompleteById[encodedId] ~= incomplete then
            TTMP.activityIncompleteById[encodedId] = incomplete
            TTMP:QueueRefreshPins()
        end
    end)

    EVENT_MANAGER:RegisterForEvent(self.addonName, EVENT_TIMED_ACTIVITY_SYSTEM_STATUS_UPDATED, function()
        TTMP:QueueRefreshPins()
    end)

    EVENT_MANAGER:RegisterForEvent(self.addonName, EVENT_HOLIDAYS_CHANGED, function()
        TTMP:QueueRefreshPins()
    end)

    EVENT_MANAGER:RegisterForEvent(self.addonName, EVENT_PLAYER_ACTIVATED, function()
        TTMP:QueueRefreshPins()
    end)

    EVENT_MANAGER:RegisterForEvent(self.addonName, EVENT_POI_UPDATED, function(_, zoneIndex, poiIndex)
        if TTMP:GetMatchForPOI(zoneIndex, poiIndex) then
            TTMP:QueueRefreshPins(false)
        end
    end)

    CALLBACK_MANAGER:RegisterCallback("OnWorldMapChanged", function()
        TTMP:QueueRefreshPins(false)
    end)

    ZO_WorldMapContainer:SetHandler("OnEffectivelyShown", function()
        if TTMP.mapPinsDirty or (TTMP.nextChallengeExpiry and TTMP.nextChallengeExpiry <= GetTimeStamp()) then
            TTMP:QueueRefreshPins(false)
        end
    end, self.addonName)
end

function TTMP:DumpActivities()
    if not IsTimedActivitySystemAvailable() then
        self:Print("The Timed Activity system is not available right now.")
        return
    end

    local numActivities = GetNumTimedActivities()
    if numActivities == 0 then
        self:Print("No active Tome Challenges found.")
        return
    end

    for index = 1, numActivities do
        local activityId = GetTimedActivityId(index)
        local encodedId = GetTimedActivityEncodedId(index)
        local name = GetTimedActivityName(index)
        local description = GetTimedActivityDescription(index)
        local progress = GetTimedActivityProgress(index)
        local maxProgress = GetTimedActivityMaxProgress(index)
        local numTimesClaimed = GetTimedActivityNumTimesClaimed(index)
        local totalNumTimesClaimable = GetTimedActivityTotalNumTimesClaimable(index)
        self:Print(string.format("[%d] id=%s encoded=%s progress=%d/%d claimed=%d/%d name=%s desc=%s", index, tostring(activityId), Id64ToString(encodedId), progress, maxProgress, numTimesClaimed, totalNumTimesClaimable, name, description))
    end
end

function TTMP:FindMapSites(query)
    query = zo_strlower(Trim(query))
    if query == "" then
        self:Print("Usage: /ttpins find <place name>")
        return
    end

    self:Print(string.format("Searching for '%s'. Map=%d, zoneId=%d.", query, GetCurrentMapId(), GetZoneId(GetCurrentMapZoneIndex())))
    local count = 0
    local function Matches(name)
        if string.find(zo_strlower(name), query, 1, true) then
            count = count + 1
            return true
        end
        return false
    end

    for locationIndex = 1, GetNumMapLocations() do
        local name = GetMapLocationTooltipHeader(locationIndex)
        if Matches(name) then
            local icon, x, y = GetMapLocationIcon(locationIndex)
            self:Print(string.format("Location=%d name=%s x=%.5f y=%.5f icon=%s", locationIndex, name, x, y, icon))
        end
    end

    for zoneIndex = 1, GetNumZones() do
        for poiIndex = 1, GetNumPOIs(zoneIndex) do
            local name = GetPOIInfo(zoneIndex, poiIndex)
            if Matches(name) then
                local _, _, pinType, icon = GetPOIMapInfo(zoneIndex, poiIndex)
                self:Print(string.format("POI zoneId=%d poi=%d name=%s type=%s icon=%s", GetZoneId(zoneIndex), poiIndex, name, tostring(pinType), icon))
            end
        end
    end

    for nodeIndex = 1, GetNumFastTravelNodes() do
        local _, name, _, _, icon = GetFastTravelNodeInfo(nodeIndex)
        if Matches(name) then
            local zoneIndex, poiIndex = GetFastTravelNodePOIIndicies(nodeIndex)
            self:Print(string.format("Node=%d zoneId=%d poi=%d name=%s icon=%s", nodeIndex, GetZoneId(zoneIndex), poiIndex, name, icon))
        end
    end
    self:Print(string.format("Search complete: %d matching record(s).", count))
end

function TTMP:PrintStatus()
    local matches = self:GetActiveChallengeEntries()
    self:Print(string.format("%d active challenge match(es). Commands: /ttpins refresh, /ttpins dump, /ttpins find <name>, /ttpins debug, /ttpins verbose, /ttpins pindebug.", #matches))
end

function TTMP:HandleSlash(rawText)
    local command = string.lower(Trim(rawText))

    if command == "refresh" then
        self:RefreshPins()
        self:Print("Pins refreshed.")
    elseif command == "dump" then
        self:DumpActivities()
    elseif command == "find" or string.sub(command, 1, 5) == "find " then
        self:FindMapSites(string.sub(command, 5))
    elseif command == "debug" then
        self.savedVars.debug = not self.savedVars.debug
        self:Print(string.format("Debug is now %s.", self.savedVars.debug and "on" or "off"))
    elseif command == "verbose" then
        self.savedVars.verboseDebug = not self.savedVars.verboseDebug
        self:Print(string.format("Verbose debug is now %s.", self.savedVars.verboseDebug and "on" or "off"))
    elseif command == "pindebug" or command == "pindebug on" then
        self.savedVars.pinDebug = command == "pindebug on" or not self.savedVars.pinDebug
        self:ClearPinDebugCache()
        self:RefreshPins()
        self:Print(string.format("Pin debug is now %s.", self.savedVars.pinDebug and "on" or "off"))
    elseif command == "pindebug off" then
        self.savedVars.pinDebug = false
        self:ClearPinDebugCache()
        self:RefreshPins()
        self:Print("Pin debug is now off.")
    else
        self:PrintStatus()
    end
end

function TTMP:Initialize()
    self.savedVars = ZO_SavedVars:NewAccountWide(self.savedVarsName, self.savedVarsVersion, GetWorldName(), self.defaults)
    self:RegisterNativeTextureHooks()

    self:RegisterPins()
    self:RegisterCompassPins()

    SLASH_COMMANDS["/ttpins"] = function(rawText)
        TTMP:HandleSlash(rawText)
    end

    self:RegisterEvents()
    self.initialized = true

    zo_callLater(function()
        TTMP:RefreshPins()
    end, 1000)
end

function TTMP.OnAddOnLoaded(eventCode, addonName)
    if addonName ~= TTMP.addonName then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(TTMP.addonName, EVENT_ADD_ON_LOADED)
    TTMP:Initialize()
end

EVENT_MANAGER:RegisterForEvent(TTMP.addonName, EVENT_ADD_ON_LOADED, TTMP.OnAddOnLoaded)
