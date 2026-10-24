-----------------------------------------------------------
-- CrutchAlerts Extensions
-- @author Kyzeragon
-----------------------------------------------------------
CrutchAlertsExtensions = {
    name = "CrutchAlertsExtensions",
    version = "0.4.0",

    CIRCLE = "Circle",
    RECTANGLE = "Rectangle",
    CONE = "Cone",

    Utils = {},
}
local CAE = CrutchAlertsExtensions

-- Defaults
local defaultGlobalOptions = {
    profiles = {
        [-1] = {
            profileName = "<Empty>",
            circles = {}, -- {[1] = {type = CAE.CIRCLE, rgb = false, color = {1, 1, 1}, radius = 5, yOffset = 0}}
            lines = {}, -- {[1] = {player1 = nil (self), player2 = "@Kyzeragone", color = {1, 1, 1, 1}}}
            hungerRequireModifier = false,
            lowerHunger = false,
            higherFrenzyAndAtro = false,
            evenHigherFrenzy = false,
            iconsForKnownPets = false, -- hardcoded ones
            iconsForPets = false, -- fallback poop
            iconsForCompanions = false,
            damagedEnemies = false,
            shadowImageWireframe = false,
            hideBossBarScavengingMaw = false,
        },
    },
}

local defaultCharOptions = {
    currentProfile = -1,
}


---------------------------------------------------------------------
function CAE.msg(msg)
    if (not msg) then return end
    msg = "|c3bdb5e[CAE]|caaaaaa " .. tostring(msg)
    if (CHAT_ROUTER) then
        CHAT_ROUTER:AddSystemMessage(msg)
    end
end


---------------------------------------------------------------------
-- Zone change
---------------------------------------------------------------------
local function OnPlayerActivatedFirstTime()
    EVENT_MANAGER:UnregisterForEvent(CAE.name .. "ActivatedFirstTime", EVENT_PLAYER_ACTIVATED)

    CAE.InitializeShapes()
    CAE.InitializeLines()
end


---------------------------------------------------------------------
-- Initialize 
---------------------------------------------------------------------
local function FillAllDefaults(tab, defaults)
    for k, v in pairs(defaults) do
        if (tab[k] == nil) then
            if (type(v) == "table") then
                tab[k] = ZO_DeepTableCopy(v)
            else
                tab[k] = v
            end
        end
    end
end

-- Later added things
local function FillMissingDefaults()
    for _, profileData in pairs(CAE.profiles) do
        -- Lines table
        if (profileData.lines == nil) then
            profileData.lines = {}
        end
        -- Line stuff
        for _, lineData in pairs(profileData.lines) do
            if (lineData.useGradient == nil) then
                lineData.useGradient = false
            end
            if (lineData.secondColor == nil) then
                lineData.secondColor = {1, 1, 1, 1}
            end
        end
        -- Shape types, forward offset, ?
        for _, shapeData in pairs(profileData.circles) do
            if (shapeData.type == nil) then
                shapeData.type = CAE.CIRCLE
            end
            if (shapeData.forwardOffset == nil) then
                shapeData.forwardOffset = 0
            end
            if (shapeData.activeBarOnly == nil) then
                shapeData.activeBarOnly = false
            end

            -- convert to tables for multi id
            if (type(shapeData.conditionalAbilityId) ~= "table") then
                shapeData.conditionalAbilityId = {shapeData.conditionalAbilityId}
            end
            if (type(shapeData.conditionalSetId) ~= "table") then
                shapeData.conditionalSetId = {shapeData.conditionalSetId}
            end
            if (type(shapeData.conditionalEffectId) ~= "table") then
                shapeData.conditionalEffectId = {shapeData.conditionalEffectId}
            end

            -- orientation
            if (shapeData.pitch == nil) then
                shapeData.pitch = 0
            end

            -- default will be true, but migrate the old ones to keep the same behavior
            if (shapeData.useCameraHeading == nil) then
                shapeData.useCameraHeading = false
            end

            if (shapeData.type == CAE.CONE and shapeData.coneStyle == nil) then
                shapeData.coneStyle = 3 -- 1 = lines only, 2 = arc only, 3 = lines+arc
            end
        end
    end
end
CAE.FillMissingDefaults = FillMissingDefaults

local function Initialize()
    CrutchAlertsExtensionsSavedProfiles = CrutchAlertsExtensionsSavedProfiles or {}
    FillAllDefaults(CrutchAlertsExtensionsSavedProfiles, defaultGlobalOptions)
    CAE.profiles = CrutchAlertsExtensionsSavedProfiles.profiles
    FillMissingDefaults()

    CAE.csvs = ZO_SavedVars:NewCharacterIdSettings("CrutchAlertsExtensionsSavedVariables", 1, nil, defaultCharOptions)

    CAE.CreateSettingsMenu()
    CAE.CreateUtilsSettingsMenu()
    CAE.InitializeConditionalChecker()
    CAE.InitializeSynergy()
    CAE.InitializeUnitIcons()
    CAE.InitializeUnitDrawing()
    CAE.InitializeDamagedEnemies()
    CAE.InitializeBossTriggers()

    EVENT_MANAGER:RegisterForEvent(CAE.name .. "ActivatedFirstTime", EVENT_PLAYER_ACTIVATED, OnPlayerActivatedFirstTime)

    ZO_CreateStringId("SI_BINDING_NAME_CAE_SYNERGY_MODIFIER", "Werewolf Synergy Modifier")
end


---------------------------------------------------------------------
-- On load
local function OnAddOnLoaded(_, addonName)
    if (addonName == CAE.name) then
        EVENT_MANAGER:UnregisterForEvent(CAE.name, EVENT_ADD_ON_LOADED)
        Initialize()
    end
end
 
EVENT_MANAGER:RegisterForEvent(CAE.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)

