-- ESO Adventurer Suite
-- Character-scoped configuration persistence.
--
-- The Suite keeps learned/account data in the existing account-wide SavedVars
-- profile, while each character receives a durable snapshot of UI/configuration
-- values. This prevents one character's HUD layout/settings from being replaced
-- by another character or by ESO's account-wide native HUD editor offsets.

ESOProgressionCoach = ESOProgressionCoach or {}
local EPC = ESOProgressionCoach

EPC.CharacterProfile = EPC.CharacterProfile or {}
local P = EPC.CharacterProfile

P.owner = "CharacterProfile"
P.profileKey = "characterProfiles029784"
P.appliedThisLoad = false

local function deepCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return nil end
    seen[value] = true
    local out = {}
    for k,v in pairs(value) do
        local ck = deepCopy(k, seen)
        if ck ~= nil then out[ck] = deepCopy(v, seen) end
    end
    seen[value] = nil
    return out
end

local ACCOUNT_DATA_KEYS = {
    activityHistory = true,
    dungeonHistory = true,
    activityRunHistory = true,
    inventoryCharacters = true,
    sharedInventory = true,
    dungeonChestLocations = true,
    resourcePinLocations = true,
    antiquityLearnedDigSpots = true,
    bugCatcherLog = true,
    combatPersonalBests = true,
    gameModeReports = true,
    goldSpendingByCharacter = true,
}

local ACCOUNT_DATA_PATTERNS = {
    "Migration", "migration",
    "Learned", "learned",
    "History", "history",
    "Locations", "locations",
    "Log$", "Data$", "Cache$",
}

local PROFILE_TABLE_KEYS = {
    savedLoadoutPages029272 = true,
    savedLoadouts = true,
    savedLoadoutWindow = true,
    mapTeleporterFavorites = true,
    mapTeleporterBlacklistPlayers = true,
    mapTeleporterBlacklistZones = true,
    teamVisibilityCompanionColor = true,
    teamVisibilityPlayerOverrides = true,
    dungeonChestColor = true,
    dungeonChestSackColor = true,
    resourcePinsColor = true,
    overlandDifficultyZoneOverrides = true,
}

function P:GetCharacterKey()
    if type(GetCurrentCharacterId) == "function" then
        local ok, id = pcall(GetCurrentCharacterId)
        id = ok and tostring(id or "") or ""
        if id ~= "" and id ~= "0" then return id end
    end
    if type(GetUnitName) == "function" then
        local ok, name = pcall(GetUnitName, "player")
        name = ok and tostring(name or "") or ""
        if name ~= "" then return "name:" .. name end
    end
    return "unknown"
end

function P:IsProfileKey(key, value)
    key = tostring(key or "")
    if key == "" or key == self.profileKey then return false end
    if ACCOUNT_DATA_KEYS[key] then return false end
    for _,pattern in ipairs(ACCOUNT_DATA_PATTERNS) do
        if string.find(key, pattern) then return false end
    end

    local valueType = type(value)
    if valueType == "boolean" or valueType == "number" or valueType == "string" then
        return true
    end
    if valueType == "table" and PROFILE_TABLE_KEYS[key] then
        return true
    end
    return false
end

function P:GetProfiles()
    if type(EPC.saved) ~= "table" then return nil end
    if type(EPC.saved[self.profileKey]) ~= "table" then
        EPC.saved[self.profileKey] = {}
    end
    return EPC.saved[self.profileKey]
end

function P:GetActiveProfile(create)
    local profiles = self:GetProfiles()
    if not profiles then return nil end
    local key = self:GetCharacterKey()
    if create and type(profiles[key]) ~= "table" then
        profiles[key] = { version = 1 }
    end
    return profiles[key], key
end

function P:Capture(reason)
    if type(EPC.saved) ~= "table" then return false end
    local profile, key = self:GetActiveProfile(true)
    if not profile then return false end

    for savedKey, value in pairs(EPC.saved) do
        if self:IsProfileKey(savedKey, value) then
            profile[savedKey] = deepCopy(value)
        end
    end
    profile.version = 1
    profile.characterKey = key
    profile.savedAt = type(GetTimeStamp) == "function" and (tonumber(GetTimeStamp()) or 0) or 0
    profile.lastReason = tostring(reason or "capture")
    return true
end

function P:CaptureKey(savedKey)
    if type(EPC.saved) ~= "table" then return false end
    local value = EPC.saved[savedKey]
    if not self:IsProfileKey(savedKey, value) then return false end
    local profile = self:GetActiveProfile(true)
    if not profile then return false end
    profile[savedKey] = deepCopy(value)
    profile.savedAt = type(GetTimeStamp) == "function" and (tonumber(GetTimeStamp()) or 0) or 0
    return true
end

function P:Apply()
    if self.appliedThisLoad or type(EPC.saved) ~= "table" then return false end
    local profile = self:GetActiveProfile(false)

    if type(profile) ~= "table" then
        -- First visit on this character: inherit the current account configuration
        -- once, then immediately become independent from other characters.
        self:Capture("seed-character")
        self.appliedThisLoad = true
        return true
    end

    for key, value in pairs(profile) do
        if key ~= "version" and key ~= "characterKey" and key ~= "savedAt" and key ~= "lastReason"
            and self:IsProfileKey(key, value) then
            EPC.saved[key] = deepCopy(value)
        end
    end

    self.appliedThisLoad = true
    return true
end

function P:GetDiagnostics()
    local profiles = self:GetProfiles()
    local count = 0
    if type(profiles) == "table" then
        for _,profile in pairs(profiles) do
            if type(profile) == "table" then count = count + 1 end
        end
    end
    local active = self:GetActiveProfile(false)
    return {
        activeCharacter = self:GetCharacterKey(),
        profileCount = count,
        activeProfile = type(active) == "table",
        applied = self.appliedThisLoad == true,
    }
end

local function onAddonLoaded(_, addonName)
    if addonName ~= EPC.name then return end
    if EPC.Runtime then EPC.Runtime:UnregisterEvent(P.owner, "AddonLoaded") end
    P:Apply()
end

local function persist(reason)
    if EPC.NativeHUDEditor and type(EPC.NativeHUDEditor.SyncAllToSuite) == "function" then
        pcall(EPC.NativeHUDEditor.SyncAllToSuite, EPC.NativeHUDEditor)
    end
    P:Capture(reason)
end

if EPC.Runtime then
    if rawget(_G, "EVENT_ADD_ON_LOADED") then
        EPC.Runtime:RegisterEvent(P.owner, "AddonLoaded", EVENT_ADD_ON_LOADED, onAddonLoaded)
    end
    if rawget(_G, "EVENT_PLAYER_DEACTIVATED") then
        EPC.Runtime:RegisterEvent(P.owner, "PlayerDeactivated", EVENT_PLAYER_DEACTIVATED, function()
            persist("player-deactivated")
        end)
    end
end

function EPC:PersistCharacterProfile029784(reason)
    return P:Capture(reason or "explicit")
end
