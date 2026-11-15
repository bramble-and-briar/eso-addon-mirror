Wegesruhe = Wegesruhe or {}
local WR = Wegesruhe

WR.name = "Wegesruhe"
WR.version = "2.1.0"
WR.savedVarsVersion = 1
WR.helpHeld = false
WR.initialized = false

local function AllQuestTypesEnabled()
    return {
        none = true,
        mainStory = true,
        guild = true,
        class = true,
        companion = true,
        crafting = true,
        dungeon = true,
        group = true,
        raid = true,
        undauntedPledge = true,
        prologue = true,
        holidayEvent = true,
        tribute = true,
        scribing = true,
        tamrielTale = true,
        favor = true,
        ava = true,
        avaGrand = true,
        avaGroup = true,
        battleground = true,
    }
end

local function AllRepeatTypesEnabled()
    return {
        notRepeatable = true,
        daily = true,
        weekly = true,
        monthly = true,
        repeatable = true,
        eventReset = true,
        perDuration = true,
    }
end

WR.defaults = {
    enabled = true,
    preset = "explorer",
    mapQuestPins = false,
    compassPins = true,
    compass = {
        questOffers = true,
        assistedObjectives = false,
        secondaryObjectives = false,
        poiSeen = false,
        poiComplete = true,
        questAreas = false,
    },
    world = {
        questOffers = true,
        assistedObjectives = false,
        secondaryObjectives = false,
        breadcrumbs = false,
    },
    questTypes = AllQuestTypesEnabled(),
    compassQuestTypes = AllQuestTypesEnabled(),
    repeatTypes = AllRepeatTypesEnabled(),
    compassRepeatTypes = AllRepeatTypesEnabled(),
    pvpOverride = true,
    pvpPreset = "normal",
}

WR.presets = {
    normal = {
        mapQuestPins = true,
        compassPins = true,
        compass = {
            questOffers = true,
            assistedObjectives = true,
            secondaryObjectives = true,
            poiSeen = true,
            poiComplete = true,
            questAreas = true,
        },
        world = {
            questOffers = true,
            assistedObjectives = true,
            secondaryObjectives = true,
            breadcrumbs = true,
        },
        questTypes = AllQuestTypesEnabled(),
    compassQuestTypes = AllQuestTypesEnabled(),
        repeatTypes = AllRepeatTypesEnabled(),
    compassRepeatTypes = AllRepeatTypesEnabled(),
    },
    gentle = {
        mapQuestPins = true,
        compassPins = true,
        compass = {
            questOffers = true,
            assistedObjectives = true,
            secondaryObjectives = true,
            poiSeen = true,
            poiComplete = true,
            questAreas = true,
        },
        world = {
            questOffers = true,
            assistedObjectives = false,
            secondaryObjectives = false,
            breadcrumbs = true,
        },
        questTypes = AllQuestTypesEnabled(),
    compassQuestTypes = AllQuestTypesEnabled(),
        repeatTypes = AllRepeatTypesEnabled(),
    compassRepeatTypes = AllRepeatTypesEnabled(),
    },
    explorer = {
        mapQuestPins = false,
        compassPins = true,
        compass = {
            questOffers = true,
            assistedObjectives = false,
            secondaryObjectives = false,
            poiSeen = false,
            poiComplete = true,
            questAreas = false,
        },
        world = {
            questOffers = true,
            assistedObjectives = false,
            secondaryObjectives = false,
            breadcrumbs = false,
        },
        questTypes = AllQuestTypesEnabled(),
    compassQuestTypes = AllQuestTypesEnabled(),
        repeatTypes = AllRepeatTypesEnabled(),
    compassRepeatTypes = AllRepeatTypesEnabled(),
    },
    hardcore = {
        mapQuestPins = false,
        compassPins = false,
        compass = {
            questOffers = false,
            assistedObjectives = false,
            secondaryObjectives = false,
            poiSeen = false,
            poiComplete = false,
            questAreas = false,
        },
        world = {
            questOffers = false,
            assistedObjectives = false,
            secondaryObjectives = false,
            breadcrumbs = false,
        },
        questTypes = AllQuestTypesEnabled(),
    compassQuestTypes = AllQuestTypesEnabled(),
        repeatTypes = AllRepeatTypesEnabled(),
    compassRepeatTypes = AllRepeatTypesEnabled(),
    },
}

local function CopyValue(value)
    if type(value) ~= "table" then
        return value
    end
    local copy = {}
    for key, child in pairs(value) do
        copy[key] = CopyValue(child)
    end
    return copy
end

function WR:CopyTable(source)
    return CopyValue(source)
end

function WR:IsPvPContext()
    return IsPlayerInAvAWorld() or IsActiveWorldBattleground()
end

function WR:GetActiveProfile()
    if self.helpHeld or not self.settings.enabled then
        return self.presets.normal
    end
    if self.settings.pvpOverride and self:IsPvPContext() then
        -- "off" suspends all Wegesruhe filtering in PvP while preserving the
        -- user's normal PvE settings. The normal profile is a transparent
        -- pass-through profile, so hooks remain installed without hiding pins.
        if self.settings.pvpPreset == "off" then
            return self.presets.normal
        end
        return self.presets[self.settings.pvpPreset] or self.presets.normal
    end
    return self.settings
end

function WR:GetPresetDisplayName(presetKey)
    local L = self.L
    local names = {
        normal = L.PRESET_NORMAL,
        gentle = L.PRESET_GENTLE,
        explorer = L.PRESET_EXPLORER,
        hardcore = L.PRESET_HARDCORE,
        custom = L.PRESET_CUSTOM,
        off = L.PRESET_OFF,
    }
    return names[presetKey] or tostring(presetKey)
end

function WR:ApplyPreset(presetKey, refresh)
    local preset = self.presets[presetKey]
    if not preset then
        return false
    end
    self.settings.mapQuestPins = preset.mapQuestPins
    self.settings.compassPins = preset.compassPins
    self.settings.compass = self:CopyTable(preset.compass)
    self.settings.world = self:CopyTable(preset.world)
    self.settings.questTypes = self:CopyTable(preset.questTypes)
    self.settings.repeatTypes = self:CopyTable(preset.repeatTypes)
    self.settings.compassQuestTypes = self:CopyTable(preset.compassQuestTypes)
    self.settings.compassRepeatTypes = self:CopyTable(preset.compassRepeatTypes)
    self.settings.preset = presetKey
    if refresh ~= false then
        self:RefreshAll()
    end
    return true
end

function WR:MarkCustom()
    if self.settings.preset ~= "custom" then
        self.settings.preset = "custom"
    end
end

function WR:SetHelpMode(isHeld)
    -- Navigation Help only belongs to an active Wegesruhe. When the addon is
    -- disabled, ignore both key-down and key-up completely so the key cannot
    -- cause pointless marker/map refreshes (or their associated hitching).
    if not self.settings or not self.settings.enabled then
        self.helpHeld = false
        return
    end

    isHeld = isHeld == true
    if self.helpHeld == isHeld then
        return
    end
    self.helpHeld = isHeld
    self:RefreshAll(false)
end

function WR:SetEnabled(enabled, announce)
    enabled = enabled == true
    if self.settings.enabled == enabled then
        -- Even on a no-op command, never leave a stale held-help state behind
        -- while Wegesruhe is disabled.
        if not enabled then
            self.helpHeld = false
        end
        return
    end

    -- A master-state transition must not inherit a currently held help key.
    -- Otherwise releasing that key later can unexpectedly alter the newly
    -- selected state.
    self.helpHeld = false
    self.settings.enabled = enabled

    -- Unlike the frequently used help key, master on/off is rare and deserves
    -- one complete refresh. This also rebuilds map quest pins even if the world
    -- map is currently closed, eliminating the old /reloadui requirement.
    self:RefreshAll(true)

    if announce ~= false then
        d(enabled and self.L.CHAT_ENABLED or self.L.CHAT_DISABLED)
    end
end

function WR:ToggleEnabled()
    self:SetEnabled(not self.settings.enabled, true)
end

function WR:ResetDefaults()
    self.settings.enabled = self.defaults.enabled
    self.settings.pvpOverride = self.defaults.pvpOverride
    self.settings.pvpPreset = self.defaults.pvpPreset
    self:ApplyPreset("explorer", false)
    self.helpHeld = false
    self:RefreshAll(true)
end

function WR:RefreshAll(forceMapRefresh)
    if self.RefreshCompass then
        self:RefreshCompass()
    end

    -- SAFETY: Do not manually re-call SetFloatingMarkerInfo here.
    -- The ESO client can crash to desktop when addons invoke that API at
    -- runtime, especially when multiple addons touch it around the same time.
    -- Wegesruhe only filters 3D marker definitions when ESO (or another addon)
    -- naturally sets them. Map and compass can still refresh immediately.

    if self.RefreshMap then
        self:RefreshMap(forceMapRefresh == true)
    end
end



function WR:HandleSlashCommand(text)
    text = zo_strlower(zo_strtrim(text or ""))
    if text == "" or text == "settings" then
        if self.OpenSettings then
            self:OpenSettings("slash")
        end
        return
    elseif text == "on" then
        self:SetEnabled(true, true)
        return
    elseif text == "off" then
        self:SetEnabled(false, true)
        return
    elseif text == "status" then
        local pvp = self.settings.pvpOverride and self.L.ON or self.L.OFF
        d(zo_strformat(self.L.CHAT_STATUS, self.settings.enabled and self.L.ON or self.L.OFF, self:GetPresetDisplayName(self.settings.preset), pvp))
        return
    end

    local preset = string.match(text, "^preset%s+(%S+)$")
    if preset then
        if self:ApplyPreset(preset) then
            d(zo_strformat("Wegesruhe: <<1>>", self:GetPresetDisplayName(preset)))
        else
            d(self.L.CHAT_UNKNOWN_PRESET)
        end
        return
    end

    d(self.L.CHAT_HELP)
end

local SETTINGS_KEYS = {
    "enabled",
    "preset",
    "mapQuestPins",
    "compassPins",
    "compass",
    "world",
    "questTypes",
    "repeatTypes",
    "compassQuestTypes",
    "compassRepeatTypes",
    "pvpOverride",
    "pvpPreset",
}

local function EnsureDefaults(target, defaults)
    if type(target) ~= "table" or type(defaults) ~= "table" then
        return
    end
    for key, defaultValue in pairs(defaults) do
        local currentValue = target[key]
        if currentValue == nil then
            target[key] = CopyValue(defaultValue)
        elseif type(currentValue) == "table" and type(defaultValue) == "table" then
            EnsureDefaults(currentValue, defaultValue)
        end
    end
end

function WR:GetCharacterStorageKey()
    return tostring(GetCurrentCharacterId())
end

function WR:GetSettingsScope()
    if not self.storage then
        return "account"
    end
    local key = self:GetCharacterStorageKey()
    if self.storage.characterScopes and self.storage.characterScopes[key] == "character" then
        return "character"
    end
    return "account"
end

function WR:ActivateSettingsForCurrentCharacter()
    local key = self:GetCharacterStorageKey()
    if self:GetSettingsScope() == "character" then
        self.storage.characterSettings[key] = self.storage.characterSettings[key] or self:CopyTable(self.storage.account)
        EnsureDefaults(self.storage.characterSettings[key], self.defaults)
        self.settings = self.storage.characterSettings[key]
    else
        EnsureDefaults(self.storage.account, self.defaults)
        self.settings = self.storage.account
    end
end

function WR:SetSettingsScope(scope, refresh)
    if scope ~= "character" then
        scope = "account"
    end

    local key = self:GetCharacterStorageKey()
    local oldScope = self:GetSettingsScope()
    if oldScope == scope then
        return
    end

    self.storage.characterSettings = self.storage.characterSettings or {}
    self.storage.characterScopes = self.storage.characterScopes or {}

    if scope == "character" then
        -- First use starts from the shared account setup so a character-specific
        -- profile never begins as an unexpected factory reset. Existing personal
        -- settings are kept when switching away and back later.
        if not self.storage.characterSettings[key] then
            self.storage.characterSettings[key] = self:CopyTable(self.storage.account)
        end
        EnsureDefaults(self.storage.characterSettings[key], self.defaults)
        self.storage.characterScopes[key] = "character"
        self.settings = self.storage.characterSettings[key]
    else
        self.storage.characterScopes[key] = nil
        EnsureDefaults(self.storage.account, self.defaults)
        self.settings = self.storage.account
    end

    self.helpHeld = false
    if refresh ~= false then
        self:RefreshAll(true)
    end
end

function WR:InitializeSavedVariables()
    local storageDefaults = {
        account = self:CopyTable(self.defaults),
        characterSettings = {},
        characterScopes = {},
    }

    self.storage = ZO_SavedVars:NewAccountWide(
        "WegesruheSavedVariables",
        self.savedVarsVersion,
        nil,
        storageDefaults,
        GetWorldName()
    )

    -- Migration from earlier pre-release builds: older versions stored the actual
    -- settings directly at the account-wide root. Preserve that setup as the
    -- new shared account profile instead of resetting existing users.
    local hasLegacySettings = false
    for _, key in ipairs(SETTINGS_KEYS) do
        if self.storage[key] ~= nil then
            hasLegacySettings = true
            break
        end
    end

    if hasLegacySettings then
        local migrated = self:CopyTable(self.defaults)
        for _, key in ipairs(SETTINGS_KEYS) do
            if self.storage[key] ~= nil then
                migrated[key] = CopyValue(self.storage[key])
                self.storage[key] = nil
            end
        end
        self.storage.account = migrated
    end

    self.storage.characterSettings = self.storage.characterSettings or {}
    self.storage.characterScopes = self.storage.characterScopes or {}
    EnsureDefaults(self.storage.account, self.defaults)
    -- Version 3: legacy quest filters applied to BOTH the map and compass.
    -- On first upgrade, copy each saved profile's legacy map filters into the
    -- new compass filters. Never copy again after the surfaces diverge.
    -- Do not rely on whether the new keys are nil: ZO_SavedVars may already
    -- have filled those fields from the latest defaults during initialization.
    if self.storage.questFilterSplitVersion ~= 1 then
        local function CopyOldFilters(profile)
            if type(profile) ~= "table" then return end
            profile.compassQuestTypes = CopyValue(profile.questTypes or self.defaults.questTypes)
            profile.compassRepeatTypes = CopyValue(profile.repeatTypes or self.defaults.repeatTypes)
        end
        CopyOldFilters(self.storage.account)
        for _, characterSettings in pairs(self.storage.characterSettings or {}) do
            CopyOldFilters(characterSettings)
        end
        self.storage.questFilterSplitVersion = 1
    end


    -- Keep any already-created character settings forward-compatible when new
    -- options are added in later Wegesruhe versions.
    for _, characterSettings in pairs(self.storage.characterSettings) do
        EnsureDefaults(characterSettings, self.defaults)
    end

    self.storage.storageVersion = 3
    -- Language did not exist in 2.0.1. Leave old account/character settings as-is.
    -- An account-wide separate key ensures the chosen language follows characters.
    if not self.supportedLanguages[self.storage.language] then
        self.storage.language = "auto"
    end
    self:ActivateSettingsForCurrentCharacter()
end

-- Addon-only language preference, shared by all characters on the current megaserver.
-- Stored separately from navigation presets/scopes to preserve existing profiles.
function WR:SetLanguagePreference(language)
    if not self.supportedLanguages[language] or not self.storage then
        return false
    end
    if self.storage.language == language then
        return true
    end
    self.storage.language = language
    -- All locale tables are already loaded. Switch only this addon's strings,
    -- update the existing settings controls in-place, and leave ESO's CVar alone.
    self:InitializeLanguage()
    if self.RefreshSettingsLanguage then
        self:RefreshSettingsLanguage()
    end
    return true
end

function WR:Initialize()
    if self.initialized then
        return
    end
    self.initialized = true

    self:InitializeSavedVariables()
    self:InitializeLanguage()
    self:BuildMarkerCatalog()
    self:InitializeQuestFilters()
    self:InitializeCompass()
    self:InitializeFloatingMarkers()
    self:InitializeMap()
    self:InitializeSettings()
    if self.InitializeAddonListGear then
        self:InitializeAddonListGear()
    end

    SLASH_COMMANDS["/wr"] = function(text) self:HandleSlashCommand(text) end
    SLASH_COMMANDS["/wegesruhe"] = function(text) self:HandleSlashCommand(text) end

    EVENT_MANAGER:RegisterForEvent(self.name .. "PlayerActivated", EVENT_PLAYER_ACTIVATED, function()
        zo_callLater(function()
            self:RefreshAll()
        end, 250)
    end)

    self:RefreshAll()
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= WR.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(WR.name .. "Loaded", EVENT_ADD_ON_LOADED)
    WR:Initialize()
end

EVENT_MANAGER:RegisterForEvent(WR.name .. "Loaded", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
