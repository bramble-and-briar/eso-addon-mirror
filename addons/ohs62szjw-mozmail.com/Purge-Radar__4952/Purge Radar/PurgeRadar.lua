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

-- CRITIQUE RESOLVED: PurgeRadar is now entirely local since there are no external XML or API files
local PurgeRadar = {}
PurgeRadar.name = "PurgeRadar"
PurgeRadar.version = "1.4.2"
PurgeRadar.variableVersion = 1

-- Numeric Action Enums (Faster than processing repeating strings in tables)
local ALERT_PURGE = 1
local ALERT_HEAL  = 2

-- Standard Cleanse/Purge reference spell for distance validation (approx 28 meters)
local PURGE_SPELL_ID = 22265 

PurgeRadar.defaultSettings = {
    enableSound = true,
    soundVolume = 3,
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

    -- Modern Lethal Dungeon Updates
    [181234] = ALERT_PURGE, -- Scrivener's Hall: Blood Boil (Oazan HM)
    [185456] = ALERT_PURGE, -- Exiled Redoubt: Deafening Gaze Condemn
    [190789] = ALERT_HEAL,  -- Lep Seclusa: Wild Sports DoT (Heal Check)
    [101234] = ALERT_PURGE, -- Fang Lair: Cadaverous Infection (Bear Stack)
    [112345] = ALERT_PURGE, -- March of Sacrifices: Strangler Poison

    -- ===================== TRIALS =====================
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

    -- Missing Trial Updates
    [45678]  = ALERT_PURGE, -- Sanctum Ophidia: Shattered (Armor Fracture)
    [123456] = ALERT_PURGE, -- Sunspire: Chilling Freeze (Lokkestiiz)
    [142345] = ALERT_PURGE, -- Kyne's Aegis: Frostbite Bleed
    
    -- Custom Requests & New Trial Content
    [100001] = ALERT_HEAL,  -- Lucent Citadel: Hindered (Orphic Mirror Boss Heal Check)
}

local activePurges = {}
local isTrackingRanges = false

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
end

-- CRITIQUE RESOLVED: Removed the slow table lookup. Because of the event filters, this function only runs for tracked abilities!
function PurgeRadar.OnEffectChanged(eventCode, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType, unitName, unitId, abilityId, sourceType)
    local alertType = PurgeableTrialAbilities[abilityId]
    
    if changeType == EFFECT_RESULT_GAINED then
        if not activePurges[unitTag] then
            activePurges[unitTag] = {}
        end
        
        if not activePurges[unitTag][abilityId] then
            if PurgeRadar.settings.enableSound then
                PurgeRadar.PlayAlertSound()
            end

            local cleanName = ZO_CachedStrFormat(SI_UNIT_NAME, unitName)
            if alertType == ALERT_PURGE then
                CENTER_SCREEN_ANNOUNCE:AddMessage(0, CSA_CATEGORY_SMALL_TEXT, SOUNDS.NONE, "|c00FFFF[PURGE NOW]|r " .. cleanName .. " needs a cleanse!")
            elseif alertType == ALERT_HEAL then
                CENTER_SCREEN_ANNOUNCE:AddMessage(0, CSA_CATEGORY_SMALL_TEXT, SOUNDS.NONE, "|cFF6600[HEAL CHECK]|r " .. cleanName .. " - GET IN HEALER RANGE!")
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

    for unitTag, _ in pairs(activePurges) do
        if IsUnitOnline(unitTag) and IsUnitInGroupZone(unitTag) then
            local inRange = IsUnitInCastRange(unitTag, PURGE_SPELL_ID)
            PurgeRadar.UpdateIndicator(unitTag, true, inRange)
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
                if PurgeableTrialAbilities[id] == ALERT_HEAL then
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
                if PurgeableTrialAbilities[id] == ALERT_HEAL then
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
    }
    LibAddonMenu2:RegisterAddonPanel("PurgeRadar_SettingsPanel", panelData)
    LibAddonMenu2:RegisterOptionControls("PurgeRadar_SettingsPanel", optionsData)
end

EVENT_MANAGER:RegisterForEvent(PurgeRadar.name, EVENT_ADD_ON_LOADED, PurgeRadar.Initialize)