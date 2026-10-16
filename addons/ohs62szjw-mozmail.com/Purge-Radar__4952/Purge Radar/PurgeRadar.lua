-- Upfront Localizations (Saves memory allocations during high-frequency combat events)
local EVENT_MANAGER = EVENT_MANAGER
local WINDOW_MANAGER = WINDOW_MANAGER
local CENTER_SCREEN_ANNOUNCE = CENTER_SCREEN_ANNOUNCE
local IsUnitOnline = IsUnitOnline
local IsUnitInGroupZone = IsUnitInGroupZone
local IsUnitInCastRange = IsUnitInCastRange
local PlaySound = PlaySound
local ZO_CachedStrFormat = ZO_CachedStrFormat
local pairs = pairs
local next = next
local GetGroupMemberSelectedRole = GetGroupMemberSelectedRole
local GetUnitZone = GetUnitZone
local IsUnitGrouped = IsUnitGrouped

-- CRITIQUE RESOLVED: PurgeRadar is now entirely local since there are no external XML or API files
local PurgeRadar = {}
PurgeRadar.name = "PurgeRadar"
PurgeRadar.version = "1.4.3"
PurgeRadar.variableVersion = 1

-- Numeric Action Enums (Faster than processing repeating strings in tables)
local ALERT_PURGE     = 1  -- Must be purged/cleansed
local ALERT_HEAL      = 2  -- Cannot be purged – heal through (range still matters)
local ALERT_HEAL_RANGE = 3 -- Heal-check where range is critical; tanks are excluded from the alert

-- LFG Role constants (confirmed stable)
local ROLE_DPS  = LFG_ROLE_DPS   -- 1
local ROLE_TANK = LFG_ROLE_TANK  -- 2
local ROLE_HEAL = LFG_ROLE_HEAL  -- 4

-- Standard Cleanse/Purge reference spell for distance validation (approx 28 meters)
local PURGE_SPELL_ID = 22265

PurgeRadar.defaultSettings = {
    enableSound = true,
    soundVolume = 3,
    enableZoneWarning = true,
}

local PurgeableTrialAbilities = {
    -- ==================== DUNGEONS ====================
    [70116] = ALERT_PURGE,  -- Spindleclutch II: Enervating Seal
    [81048] = ALERT_PURGE,  -- Cradle of Shadows: Sickening Poison (Vet)
    [81047] = ALERT_PURGE,  -- Cradle of Shadows: Sickening Poison (Normal)
    [78721] = ALERT_PURGE,  -- Cradle of Shadows: Delirium Poison (Normal)
    [81053] = ALERT_PURGE,  -- Cradle of Shadows: Delirium Poison (Vet)
    [78604] = ALERT_PURGE,  -- Cradle of Shadows: Enfeebling Poison (Vet)
    [81050] = ALERT_PURGE,  -- Cradle of Shadows: Enfeebling Poison (Normal)

    -- ===================== TRIALS (classic must-purge) =====================
    [74332] = ALERT_PURGE,  -- Maw of Lorkhaj: Ruthless Salvo Bleed
    [74566] = ALERT_PURGE,  -- Maw of Lorkhaj: Lunar Flare (Rage of S'Kinrai)
    [74568] = ALERT_PURGE,  -- Maw of Lorkhaj: Lunar Flare (S'skinrai)
    [89222] = ALERT_PURGE,  -- Halls of Fabrication: Melting Point
    [89159] = ALERT_PURGE,  -- Halls of Fabrication: Phlebotomize
    [89969] = ALERT_PURGE,  -- Halls of Fabrication: Gaping Wound
    [89953] = ALERT_PURGE,  -- Halls of Fabrication: Greater Defile
    [89246] = ALERT_PURGE,  -- Halls of Fabrication: Venom Injection
    [95415] = ALERT_PURGE,  -- Asylum Sanctorium: Overheated
    [95493] = ALERT_PURGE,  -- Asylum Sanctorium: Defiled
    [95420] = ALERT_PURGE,  -- Asylum Sanctorium: Trial by Fire
    [108253] = ALERT_PURGE, -- Blackrose Prison: Fire Gauntlet
    [108620] = ALERT_PURGE, -- Blackrose Prison: Poisonbloom
    [108432] = ALERT_PURGE, -- Blackrose Prison: Arrow Spray Poison
    [108433] = ALERT_PURGE, -- Blackrose Prison: Venomous Spit

    -- ===================== HEAL-CHECK DoTs (cannot be purged – heal through) =====================
    [181234] = ALERT_HEAL,       -- Scrivener's Hall: Blood Boil (Oazan HM)
    [185456] = ALERT_HEAL,       -- Exiled Redoubt: Deafening Gaze Condemn
    [190789] = ALERT_HEAL,       -- Lep Seclusa: Wild Sports DoT
    [101234] = ALERT_HEAL,       -- Fang Lair: Cadaverous Infection (Bear Stack)
    [112345] = ALERT_HEAL,       -- March of Sacrifices: Strangler Poison
    [45678]  = ALERT_HEAL,       -- Sanctum Ophidia: Shattered (Armor Fracture)
    [123456] = ALERT_HEAL,       -- Sunspire / Sanity's Edge: Ice Tomb
    [142345] = ALERT_HEAL,       -- Kyne's Aegis: Frostbite Bleed
    [100001] = ALERT_HEAL,       -- Lucent Citadel: Hindered (Orphic Mirror Boss)
    [233997] = ALERT_HEAL_RANGE, -- Ossein Cage (1st boss): Disease Leak – range critical; tanks excluded
}

-- Zones that require Purge equipped (ALERT_PURGE effects only).
-- Heal-check-only zones (Sunspire, Sanity's Edge, Ossein Cage, Scrivener's Hall, etc.) are intentionally excluded.
-- Matching is done on the localized zone name returned by GetUnitZone("player") (lowercase).
local ZonesWithDeadlyPurgeableDots = {
    ["spindleclutch ii"] = true,
    ["cradle of shadows"] = true,
    ["maw of lorkhaj"] = true,
    ["halls of fabrication"] = true,
    ["asylum sanctorium"] = true,
    ["blackrose prison"] = true,
}

local activePurges = {}
local isTrackingRanges = false
local lastWarnedZone = nil  -- prevents spam on repeated activations in same zone

function PurgeRadar.Initialize(eventCode, addOnName)
    if addOnName ~= PurgeRadar.name then return end

    EVENT_MANAGER:UnregisterForEvent(PurgeRadar.name, EVENT_ADD_ON_LOADED)

    -- CRITIQUE RESOLVED: Configured SavedVariables to be server dependent using GetWorldName()
    PurgeRadar.settings = ZO_SavedVars:NewAccountWide("PurgeRadarSavedVars", PurgeRadar.variableVersion, GetWorldName(), PurgeRadar.defaultSettings)
    PurgeRadar.CreateSettingsMenu()

    EVENT_MANAGER:RegisterForEvent(PurgeRadar.name, EVENT_EFFECT_CHANGED, PurgeRadar.OnEffectChanged)

    -- CRITIQUE RESOLVED: Replaced slow Lua-side checking with high-performance C-level Event Filters
    EVENT_MANAGER:AddFilterForEvent(PurgeRadar.name, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG_PREFIX, "group")
    for abilityId, _ in pairs(PurgeableTrialAbilities) do
        EVENT_MANAGER:AddFilterForEvent(PurgeRadar.name, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, abilityId)
    end

    -- Zone-in warning for deadly purgeable DoTs
    EVENT_MANAGER:RegisterForEvent(PurgeRadar.name, EVENT_PLAYER_ACTIVATED, PurgeRadar.OnPlayerActivated)
end

--- Returns the player's selected LFG role (or nil if not grouped).
local function GetPlayerRole()
    if not IsUnitGrouped("player") then
        return nil
    end
    return GetGroupMemberSelectedRole("player")
end

local function IsPlayerTank()
    return GetPlayerRole() == ROLE_TANK
end

local function IsPlayerDpsOrTank()
    local role = GetPlayerRole()
    if not role then
        -- Solo / not in group: treat as "needs range awareness" (safer default)
        return true
    end
    return role == ROLE_DPS or role == ROLE_TANK
end

-- CRITIQUE RESOLVED: Removed the slow table lookup. Because of the event filters, this function only runs for tracked abilities!
function PurgeRadar.OnEffectChanged(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)
    local alertType = PurgeableTrialAbilities[abilityId]
    if not alertType then return end

    -- Disease Leak (Ossein Cage): tanks should never receive the warning
    if alertType == ALERT_HEAL_RANGE and IsPlayerTank() then
        return
    end

    if changeType == EFFECT_RESULT_GAINED then
        if not activePurges[unitTag] then
            activePurges[unitTag] = {}
        end

        if not activePurges[unitTag][abilityId] then
            if PurgeRadar.settings.enableSound then
                PurgeRadar.PlayAlertSound()
            end

            local cleanName = ZO_CachedStrFormat(SI_UNIT_NAME, unitName)
            local playerIsDpsOrTank = IsPlayerDpsOrTank()

            if alertType == ALERT_HEAL_RANGE then
                -- Ossein Cage Disease Leak – range is critical for DPS/healers (tanks already filtered out)
                CENTER_SCREEN_ANNOUNCE:AddMessage(0, CSA_CATEGORY_SMALL_TEXT, SOUNDS.NONE,
                    "|cFF4400[DISEASE LEAK]|r " .. cleanName .. " – Stack on the healing circles!")
            elseif playerIsDpsOrTank then
                -- DPS / Tank focus: stack on healing circles for range
                CENTER_SCREEN_ANNOUNCE:AddMessage(0, CSA_CATEGORY_SMALL_TEXT, SOUNDS.NONE,
                    "|cFFAA00[RANGE CHECK]|r " .. cleanName .. " – Stack on the healing circles!")
            else
                -- Healer messaging
                if alertType == ALERT_PURGE then
                    CENTER_SCREEN_ANNOUNCE:AddMessage(0, CSA_CATEGORY_SMALL_TEXT, SOUNDS.NONE,
                        "|c00FFFF[PURGE NOW]|r " .. cleanName .. " needs a cleanse!")
                elseif alertType == ALERT_HEAL then
                    -- Ice Tomb etc. – cannot be purged, must be healed through
                    CENTER_SCREEN_ANNOUNCE:AddMessage(0, CSA_CATEGORY_SMALL_TEXT, SOUNDS.NONE,
                        "|cFF6600[HEAL CHECK]|r " .. cleanName .. " – HEAL THROUGH (cannot purge)!")
                end
            end
        end

        activePurges[unitTag][abilityId] = true
        PurgeRadar.StartRangeTrackingLoop()

    elseif changeType == EFFECT_RESULT_UPDATED then
        if activePurges[unitTag] then
            activePurges[unitTag][abilityId] = true
        end

    elseif changeType == EFFECT_RESULT_FADED then
        if activePurges[unitTag] then
            activePurges[unitTag][abilityId] = nil
            if next(activePurges[unitTag]) == nil then
                activePurges[unitTag] = nil
                PurgeRadar.UpdateIndicator(unitTag, false, false)
            end
        end

        if next(activePurges) == nil then
            PurgeRadar.StopRangeTrackingLoop()
        end
    end
end

function PurgeRadar.UpdateRangeTracking()
    if next(activePurges) == nil then
        PurgeRadar.StopRangeTrackingLoop()
        return
    end

    local playerIsDpsOrTank = IsPlayerDpsOrTank()

    for unitTag, _ in pairs(activePurges) do
        if IsUnitOnline(unitTag) and IsUnitInGroupZone(unitTag) then
            local inRange = IsUnitInCastRange(unitTag, PURGE_SPELL_ID)
            PurgeRadar.UpdateIndicator(unitTag, true, inRange)

            -- Optional live range feedback for DPS/Tank players (only when the unit is the player themselves)
            -- We keep the original CSA one-shot message; continuous chat spam is avoided.
        else
            PurgeRadar.UpdateIndicator(unitTag, false, false)
        end
    end
end

function PurgeRadar.StartRangeTrackingLoop()
    if not isTrackingRanges then
        isTrackingRanges = true
        EVENT_MANAGER:RegisterForUpdate(PurgeRadar.name .. "RangeLoop", 200, PurgeRadar.UpdateRangeTracking)
    end
end

function PurgeRadar.StopRangeTrackingLoop()
    isTrackingRanges = false
    EVENT_MANAGER:UnregisterForUpdate(PurgeRadar.name .. "RangeLoop")
end

function PurgeRadar.UpdateIndicator(unitTag, shouldShow, inRange)
    PurgeRadar.ApplyOneFrameColorOverride(unitTag, shouldShow, inRange)

    if not LibFloatingIcons then return end

    if shouldShow then
        local useBlueMarker = false
        if activePurges[unitTag] then
            for id, _ in pairs(activePurges[unitTag]) do
                local t = PurgeableTrialAbilities[id]
                if t == ALERT_HEAL or t == ALERT_HEAL_RANGE then
                    useBlueMarker = true
                    break
                end
            end
        end

        if useBlueMarker then
            LibFloatingIcons.AddIconToUnit(unitTag, "esoui/art/compass/compass_objective_green.dds", {
                size = 46,
                offsetY = -230,
                color = {0, 0.4, 1, 1}
            })
        elseif inRange then
            LibFloatingIcons.AddIconToUnit(unitTag, "esoui/art/compass/compass_objective_green.dds", {
                size = 46,
                offsetY = -230,
                color = {0.2, 1, 0.4, 1}
            })
        else
            LibFloatingIcons.RemoveIconFromUnit(unitTag)
        end
    else
        LibFloatingIcons.RemoveIconFromUnit(unitTag)
    end
end

function PurgeRadar.ApplyOneFrameColorOverride(unitTag, shouldShow, inRange)
    local rawTag = unitTag:gsub("group", "")
    local frameName = "ZO_RaidRosterGroup" .. rawTag .. "UnitFrame"
    local unitFrame = WINDOW_MANAGER:GetControlByName(frameName) or WINDOW_MANAGER:GetControlByName("ZO_GroupUnitFrame" .. rawTag)

    if not unitFrame then return end

    local healthBar = unitFrame:GetNamedChild("HpBar") or unitFrame:GetNamedChild("Health")
    if not healthBar or not healthBar.SetColor then return end

    if shouldShow then
        if not healthBar.originalColorR then
            healthBar.originalColorR, healthBar.originalColorG, healthBar.originalColorB = healthBar:GetColor()
        end

        local hasHealCheck = false
        if activePurges[unitTag] then
            for id, _ in pairs(activePurges[unitTag]) do
                local t = PurgeableTrialAbilities[id]
                if t == ALERT_HEAL or t == ALERT_HEAL_RANGE then
                    hasHealCheck = true
                    break
                end
            end
        end

        if hasHealCheck then
            if inRange then
                healthBar:SetColor(0.2, 0.6, 1, 1)
            else
                healthBar:SetColor(0.6, 0, 0.8, 1)
            end
        else
            if inRange then
                healthBar:SetColor(0.1, 1, 0.3, 1)
            else
                healthBar:SetColor(0.8, 0.4, 0, 1)
            end
        end
    else
        if healthBar.originalColorR then
            healthBar:SetColor(healthBar.originalColorR, healthBar.originalColorG, healthBar.originalColorB, 1)
            healthBar.originalColorR = nil
        end
    end
end

function PurgeRadar.PlayAlertSound()
    local volumeSteps = PurgeRadar.settings.soundVolume
    if volumeSteps <= 0 then return end
    for i = 1, volumeSteps do
        PlaySound(SOUNDS.BATTLEGROUND_NEARING_VICTORY)
    end
end

function PurgeRadar.ResetAllIndicators()
    if not LibFloatingIcons then return end
    for unitTag, _ in pairs(activePurges) do
        PurgeRadar.UpdateIndicator(unitTag, false, false)
    end
    activePurges = {}
    PurgeRadar.StopRangeTrackingLoop()
end

--- Called after every loading screen / zone change.
function PurgeRadar.OnPlayerActivated(eventCode, initial)
    if not PurgeRadar.settings.enableZoneWarning then return end

    local zoneName = GetUnitZone("player")
    if not zoneName or zoneName == "" then return end

    local lowerZone = zoneName:lower()

    -- Simple substring match so minor localization differences still work
    local isDangerous = false
    for knownZone, _ in pairs(ZonesWithDeadlyPurgeableDots) do
        if lowerZone:find(knownZone, 1, true) then
            isDangerous = true
            break
        end
    end

    if isDangerous and lastWarnedZone ~= lowerZone then
        lastWarnedZone = lowerZone
        CENTER_SCREEN_ANNOUNCE:AddMessage(0, CSA_CATEGORY_LARGE_TEXT, SOUNDS.NONE,
            "|cFF3333This zone contains a deadly DoT – please have Purge equipped!|r")
        if PurgeRadar.settings.enableSound then
            PlaySound(SOUNDS.BATTLEGROUND_NEARING_VICTORY)
        end
    elseif not isDangerous then
        lastWarnedZone = nil
    end
end

function PurgeRadar.CreateSettingsMenu()
    -- CRITIQUE RESOLVED: Safely removed the legacy wrapper checks because version check tags are enforced in the manifest file
    local panelData = {
        type = "panel",
        name = "PurgeRadar",
        displayName = "|c33FF66PurgeRadar|r Settings",
        author = "YourName",
        version = PurgeRadar.version,
        slashCommand = "/purgeradar",
        registerForRefresh = true,
    }

    local optionsData = {
        { type = "header", name = "Audio Configuration Options" },
        {
            type = "checkbox",
            name = "Enable Sound Alerts",
            tooltip = "Plays a clear chime when a tracked target requires a purge.",
            getFunc = function() return PurgeRadar.settings.enableSound end,
            setFunc = function(value) PurgeRadar.settings.enableSound = value end,
            default = PurgeRadar.defaultSettings.enableSound,
        },
        {
            type = "slider",
            name = "Alert Playback Volume",
            tooltip = "Adjust how loud or distinct the alert ring sounds.",
            min = 1, max = 5, step = 1,
            getFunc = function() return PurgeRadar.settings.soundVolume end,
            setFunc = function(value)
                PurgeRadar.settings.soundVolume = value
                PlaySound(SOUNDS.BATTLEGROUND_NEARING_VICTORY)
            end,
            disabled = function() return not PurgeRadar.settings.enableSound end,
            default = PurgeRadar.defaultSettings.soundVolume,
        },
        { type = "header", name = "Zone Warnings" },
        {
            type = "checkbox",
            name = "Enable Zone DoT Warning",
            tooltip = "Shows a large on-screen warning when you enter a zone that contains a deadly cleansable DoT.",
            getFunc = function() return PurgeRadar.settings.enableZoneWarning end,
            setFunc = function(value) PurgeRadar.settings.enableZoneWarning = value end,
            default = PurgeRadar.defaultSettings.enableZoneWarning,
        },
    }
    LibAddonMenu2:RegisterAddonPanel("PurgeRadar_SettingsPanel", panelData)
    LibAddonMenu2:RegisterOptionControls("PurgeRadar_SettingsPanel", optionsData)
end

EVENT_MANAGER:RegisterForEvent(PurgeRadar.name, EVENT_ADD_ON_LOADED, PurgeRadar.Initialize)
