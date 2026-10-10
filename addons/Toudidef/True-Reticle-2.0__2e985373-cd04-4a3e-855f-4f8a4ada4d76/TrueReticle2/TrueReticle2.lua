local TrueReticle = {}
local ADDON_NAME = "TrueReticle2"
local savedVariables

-- Conteneurs
local MyCustomReticle_Base = nil     
local MyCustomReticle_Interact = nil 
local MyCustomReticle_Anim = nil     

-- Timelines
local reticleTimeline = nil
local interactTimeline = nil

local customParts = {} 
local isFocused = false

local defaults = {
    reticle_choice = "Default",
    reticle_scale = 100,
    color = {r = 1, g = 1, b = 1, a = 1},
    
    enable_pulse = false,
    pulse_speed = 1200,
    
    enable_interact_anim = true,
}

local reticle_choices = {
    "Default",
    "Cross",
    "Dot",
    "Big Dot",
    "Circle",
    "Acquisition Circle",
    "Circle Dot",
    "Halo",
    "Halo2",
    "Halo3",
}

-- =========================================================================
-- RECETTES HAUTE DENSITÉ OPTIMISÉES
-- =========================================================================
local RETICLE_RECIPES = {
    ["Cross"] = {
        { w=20, h=2, x=0, y=0 },
        { w=2, h=20, x=0, y=0 }
    },
    ["Dot"] = {
        { w=4, h=2, x=0, y=0 },
        { w=2, h=4, x=0, y=0 }
    },
    ["Big Dot"] = {
        { w=8, h=4, x=0, y=0 },
        { w=4, h=8, x=0, y=0 },
        { w=6, h=6, x=0, y=0 }
    },
    ["Acquisition Circle"] = {
        { w=10, h=2, x=0, y=-9 }, { w=10, h=2, x=0, y=9 },
        { w=2, h=10, x=-9, y=0 }, { w=2, h=10, x=9, y=0 },
        { w=4, h=4, x=-7, y=-7 }, { w=4, h=4, x=7, y=-7 },
        { w=4, h=4, x=-7, y=7 },  { w=4, h=4, x=7, y=7 },
    },
    ["Circle"] = {
        -- Pôles Nord (centrés sur l'axe X = 0)
        { w=7,  h=1, x=0,   y=-12 },
        { w=11, h=1, x=0,   y=-11 },
        { w=15, h=1, x=0,   y=-10 },

        -- Épaules Nord (symétrie stricte ±X)
        { w=5,  h=1, x=-6,  y=-9 },  { w=5,  h=1, x=6,  y=-9 },
        { w=4,  h=1, x=-8,  y=-8 },  { w=4,  h=1, x=8,  y=-8 },
        { w=4,  h=1, x=-8,  y=-7 },  { w=4,  h=1, x=8,  y=-7 },
        { w=3,  h=1, x=-9,  y=-6 },  { w=3,  h=1, x=9,  y=-6 },

        -- Flancs Nord
        { w=3,  h=1, x=-10, y=-5 },  { w=3,  h=1, x=10, y=-5 },
        { w=3,  h=1, x=-10, y=-4 },  { w=3,  h=1, x=10, y=-4 },

        -- Équateur (flancs verticaux réguliers à ±11)
        { w=3,  h=1, x=-11, y=-3 },  { w=3,  h=1, x=11, y=-3 },
        { w=3,  h=1, x=-11, y=-2 },  { w=3,  h=1, x=11, y=-2 },
        { w=3,  h=1, x=-11, y=-1 },  { w=3,  h=1, x=11, y=-1 },
        { w=3,  h=1, x=-11, y=0 },   { w=3,  h=1, x=11, y=0 },
        { w=3,  h=1, x=-11, y=1 },   { w=3,  h=1, x=11, y=1 },
        { w=3,  h=1, x=-11, y=2 },   { w=3,  h=1, x=11, y=2 },
        { w=3,  h=1, x=-11, y=3 },   { w=3,  h=1, x=11, y=3 },

        -- Flancs Sud
        { w=3,  h=1, x=-10, y=4 },   { w=3,  h=1, x=10, y=4 },
        { w=3,  h=1, x=-10, y=5 },   { w=3,  h=1, x=10, y=5 },

        -- Épaules Sud (symétrie stricte ±X)
        { w=3,  h=1, x=-9,  y=6 },   { w=3,  h=1, x=9,  y=6 },
        { w=4,  h=1, x=-8,  y=7 },   { w=4,  h=1, x=8,  y=7 },
        { w=4,  h=1, x=-8,  y=8 },   { w=4,  h=1, x=8,  y=8 },
        { w=5,  h=1, x=-6,  y=9 },   { w=5,  h=1, x=6,  y=9 },

        -- Pôles Sud
        { w=15, h=1, x=0,   y=10 },
        { w=11, h=1, x=0,   y=11 },
        { w=7,  h=1, x=0,   y=12 },
    },
    ["Circle Dot"] = {
        -- Point central (Dot)
        { w=4,  h=2, x=0,   y=0 },
        { w=2,  h=4, x=0,   y=0 },

        -- Anneau extérieur (Circle)
        -- Pôles Nord (centrés sur l'axe X = 0)
        { w=7,  h=1, x=0,   y=-12 },
        { w=11, h=1, x=0,   y=-11 },
        { w=15, h=1, x=0,   y=-10 },

        -- Épaules Nord (symétrie stricte ±X)
        { w=5,  h=1, x=-6,  y=-9 },  { w=5,  h=1, x=6,  y=-9 },
        { w=4,  h=1, x=-8,  y=-8 },  { w=4,  h=1, x=8,  y=-8 },
        { w=4,  h=1, x=-8,  y=-7 },  { w=4,  h=1, x=8,  y=-7 },
        { w=3,  h=1, x=-9,  y=-6 },  { w=3,  h=1, x=9,  y=-6 },

        -- Flancs Nord
        { w=3,  h=1, x=-10, y=-5 },  { w=3,  h=1, x=10, y=-5 },
        { w=3,  h=1, x=-10, y=-4 },  { w=3,  h=1, x=10, y=-4 },

        -- Équateur (flancs verticaux réguliers à ±11)
        { w=3,  h=1, x=-11, y=-3 },  { w=3,  h=1, x=11, y=-3 },
        { w=3,  h=1, x=-11, y=-2 },  { w=3,  h=1, x=11, y=-2 },
        { w=3,  h=1, x=-11, y=-1 },  { w=3,  h=1, x=11, y=-1 },
        { w=3,  h=1, x=-11, y=0 },   { w=3,  h=1, x=11, y=0 },
        { w=3,  h=1, x=-11, y=1 },   { w=3,  h=1, x=11, y=1 },
        { w=3,  h=1, x=-11, y=2 },   { w=3,  h=1, x=11, y=2 },
        { w=3,  h=1, x=-11, y=3 },   { w=3,  h=1, x=11, y=3 },

        -- Flancs Sud
        { w=3,  h=1, x=-10, y=4 },   { w=3,  h=1, x=10, y=4 },
        { w=3,  h=1, x=-10, y=5 },   { w=3,  h=1, x=10, y=5 },

        -- Épaules Sud (symétrie stricte ±X)
        { w=3,  h=1, x=-9,  y=6 },   { w=3,  h=1, x=9,  y=6 },
        { w=4,  h=1, x=-8,  y=7 },   { w=4,  h=1, x=8,  y=7 },
        { w=4,  h=1, x=-8,  y=8 },   { w=4,  h=1, x=8,  y=8 },
        { w=5,  h=1, x=-6,  y=9 },   { w=5,  h=1, x=6,  y=9 },

        -- Pôles Sud
        { w=15, h=1, x=0,   y=10 },
        { w=11, h=1, x=0,   y=11 },
        { w=7,  h=1, x=0,   y=12 },
    },
    ["Halo"] = {
        -- Halo classique (Coupures nettes)
        { w=2, h=1, x=5, y=-10 }, { w=2, h=1, x=7, y=-9 }, { w=1, h=1, x=8, y=-8 }, { w=1, h=2, x=9, y=-7 }, { w=1, h=2, x=10, y=-5 },
        { w=2, h=1, x=-5, y=-10 }, { w=2, h=1, x=-7, y=-9 }, { w=1, h=1, x=-8, y=-8 }, { w=1, h=2, x=-9, y=-7 }, { w=1, h=2, x=-10, y=-5 },
        { w=2, h=1, x=5, y=10 }, { w=2, h=1, x=7, y=9 }, { w=1, h=1, x=8, y=8 }, { w=1, h=2, x=9, y=7 }, { w=1, h=2, x=10, y=5 },
        { w=2, h=1, x=-5, y=10 }, { w=2, h=1, x=-7, y=9 }, { w=1, h=1, x=-8, y=8 }, { w=1, h=2, x=-9, y=7 }, { w=1, h=2, x=-10, y=5 },
    },
    ["Halo2"] = {
        -- Nouveau Halo (Plus fluide, arcs de cercles progressifs avec des pointes adoucies)
        -- Arc Haut-Droit
        { w=4, h=2, x=5, y=-11 }, { w=3, h=3, x=8, y=-9 },
        { w=3, h=3, x=9, y=-8 }, { w=2, h=4, x=11, y=-5 },
        -- Arc Haut-Gauche
        { w=4, h=2, x=-5, y=-11 }, { w=3, h=3, x=-8, y=-9 },
        { w=3, h=3, x=-9, y=-8 }, { w=2, h=4, x=-11, y=-5 },
        -- Arc Bas-Droit
        { w=4, h=2, x=5, y=11 }, { w=3, h=3, x=8, y=9 },
        { w=3, h=3, x=9, y=8 }, { w=2, h=4, x=11, y=5 },
        -- Arc Bas-Gauche
        { w=4, h=2, x=-5, y=11 }, { w=3, h=3, x=-8, y=9 },
        { w=3, h=3, x=-9, y=8 }, { w=2, h=4, x=-11, y=5 },
    },
    ["Halo3"] = {
        -- Réticule type Halo (crochets fins, réguliers, courbure fluide de 2 px)
        
        -- Arc Haut-Droit
        { w=4, h=2, x=5,  y=-11 },
        { w=2, h=2, x=8,  y=-10 },
        { w=2, h=2, x=9,  y=-9 },
        { w=2, h=2, x=10, y=-8 },
        { w=2, h=4, x=11, y=-5 },

        -- Arc Haut-Gauche
        { w=4, h=2, x=-5,  y=-11 },
        { w=2, h=2, x=-8,  y=-10 },
        { w=2, h=2, x=-9,  y=-9 },
        { w=2, h=2, x=-10, y=-8 },
        { w=2, h=4, x=-11, y=-5 },

        -- Arc Bas-Droit
        { w=4, h=2, x=5,  y=11 },
        { w=2, h=2, x=8,  y=10 },
        { w=2, h=2, x=9,  y=9 },
        { w=2, h=2, x=10, y=8 },
        { w=2, h=4, x=11, y=5 },

        -- Arc Bas-Gauche
        { w=4, h=2, x=-5,  y=11 },
        { w=2, h=2, x=-8,  y=10 },
        { w=2, h=2, x=-9,  y=9 },
        { w=2, h=2, x=-10, y=8 },
        { w=2, h=4, x=-11, y=5 },
    },
}

-- --- FONCTIONS DE SÉCURITÉ ---

local function SafeSetScaleZero(control)
    if control and control:GetScale() ~= 0 then
        control:SetScale(0)
    end
end

local function SafeSetScaleNormal(control)
    if control then
        if control:GetScale() ~= 1 then control:SetScale(1) end
        if control:GetAlpha() < 1 then control:SetAlpha(1) end
    end
end

-- --- DESSIN ET COULEURS ---

local function ClearReticleParts()
    for i, part in ipairs(customParts) do
        part:SetHidden(true)
    end
end

-- Met à jour la couleur EN TEMPS RÉEL (sans reloadui)
local function UpdateReticleColor()
    local c = savedVariables.color or defaults.color
    for i, part in ipairs(customParts) do
        part:SetColor(c.r, c.g, c.b, c.a)
    end
end

local function DrawReticleShape(shapeName)
    ClearReticleParts()
    
    local recipe = RETICLE_RECIPES[shapeName]
    if not recipe then return end

    for i, data in ipairs(recipe) do
        local part = customParts[i]
        
        if not part then
            -- CT_TEXTURE unie (la méthode la plus légère pour TESO)
            part = WINDOW_MANAGER:CreateControl(ADDON_NAME.."_Part"..i, MyCustomReticle_Anim, CT_TEXTURE)
            part:SetDrawTier(DT_HIGH)
            table.insert(customParts, part)
        end
        
        part:SetDimensions(data.w, data.h)
        part:ClearAnchors()
        part:SetAnchor(CENTER, MyCustomReticle_Anim, CENTER, data.x, data.y)
        part:SetHidden(false)
    end
    
    UpdateReticleColor()
end

-- --- MISE À JOUR VISUELLE ---

local function UpdatePulseAnimationState()
    if savedVariables.enable_pulse and savedVariables.reticle_choice ~= "Default" then
        reticleTimeline:GetAnimation():SetDuration(savedVariables.pulse_speed)
        reticleTimeline:PlayFromStart()
    else
        reticleTimeline:Stop()
        MyCustomReticle_Anim:SetScale(1)
    end
end

local function UpdateReticleScale()
    MyCustomReticle_Base:SetScale(savedVariables.reticle_scale / 100)
end

local function UpdateReticle(reticleName)
    if not MyCustomReticle_Base then return end

    if reticleName == "Default" then
        MyCustomReticle_Base:SetHidden(true)
        SafeSetScaleNormal(ZO_ReticleContainerReticle)
        SafeSetScaleNormal(ZO_ReticleContainerCombatLock)
    else
        MyCustomReticle_Base:SetHidden(false)
        DrawReticleShape(reticleName)
        
        SafeSetScaleZero(ZO_ReticleContainerReticle)
        SafeSetScaleZero(ZO_ReticleContainerCombatLock)
    end

    UpdateReticleScale()
    UpdatePulseAnimationState()
end

-- --- INITIALISATION ---

function TrueReticle:Initialize()
    savedVariables = ZO_SavedVars:NewAccountWide("TrueReticle2_SavedVars", 1, nil, defaults)

    -- BASE
    MyCustomReticle_Base = WINDOW_MANAGER:CreateControl(ADDON_NAME.."_Base", ZO_ReticleContainer, CT_CONTROL)
    MyCustomReticle_Base:SetAnchor(CENTER, ZO_ReticleContainer, CENTER, 0, 0)
    
    -- INTERACTION
    MyCustomReticle_Interact = WINDOW_MANAGER:CreateControl(ADDON_NAME.."_Interact", MyCustomReticle_Base, CT_CONTROL)
    MyCustomReticle_Interact:SetAnchor(CENTER, MyCustomReticle_Base, CENTER, 0, 0)

    -- ANIMATION
    MyCustomReticle_Anim = WINDOW_MANAGER:CreateControl(ADDON_NAME.."_Anim", MyCustomReticle_Interact, CT_CONTROL)
    MyCustomReticle_Anim:SetAnchor(CENTER, MyCustomReticle_Interact, CENTER, 0, 0)

    -- Timeline Pulsation
    reticleTimeline = ANIMATION_MANAGER:CreateTimeline()
    reticleTimeline:SetPlaybackType(ANIMATION_PLAYBACK_PING_PONG, LOOP_INDEFINITELY) 
    local animPulse = reticleTimeline:InsertAnimation(ANIMATION_SCALE, MyCustomReticle_Anim)
    animPulse:SetScaleValues(1.0, 0.85)
    animPulse:SetEasingFunction(ZO_EaseInOutQuadratic)

    -- Timeline Interaction (Resserrement sec)
    interactTimeline = ANIMATION_MANAGER:CreateTimeline()
    local animInteract = interactTimeline:InsertAnimation(ANIMATION_SCALE, MyCustomReticle_Interact)
    animInteract:SetScaleValues(1.0, 0.75)
    animInteract:SetDuration(150)
    animInteract:SetEasingFunction(ZO_EaseOutQuadratic)

    self:InitializeSettingsMenu()

    -- Boucle 50ms
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME.."_Loop", 50, function()
        if savedVariables.reticle_choice ~= "Default" then
            SafeSetScaleZero(ZO_ReticleContainerReticle)
            SafeSetScaleZero(ZO_ReticleContainerCombatLock)
            
            if savedVariables.enable_interact_anim then
                -- Détection des objets et interactions
                local actionInfo = GetGameCameraInteractableActionInfo()
                local isInteractable = (actionInfo and actionInfo ~= "")
                
                -- Détection des entités vivantes (Joueurs, PNJ, Monstres)
                local isTargeting = DoesUnitExist("reticleover")
                
                local shouldFocus = isInteractable or isTargeting
                
                if shouldFocus ~= isFocused then
                    isFocused = shouldFocus
                    if shouldFocus then
                        interactTimeline:PlayForward()
                    else
                        interactTimeline:PlayBackward()
                    end
                end
            end
        end
    end)

    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, function()
        UpdateReticle(savedVariables.reticle_choice)
    end)
end

-- --- MENU DES PARAMÈTRES ---

function TrueReticle:InitializeSettingsMenu()
    local panelData = {
        type = "panel",
        name = "TrueReticle2",
        displayName = "True Reticle 2.0",
        author = "|cff5900To|cb16754ud|c6374a8id|c1581fcef|r",
        version = "2.0.0",
        slashCommand = "/truereticle",
        registerForRefresh = true,
    }

    local optionsPanel = LibAddonMenu2:RegisterAddonPanel(ADDON_NAME.."Panel", panelData)

    local optionsData = {
        {
            type = "dropdown",
            name = "Reticle Style",
            choices = reticle_choices,
            getFunc = function() return savedVariables.reticle_choice end,
            setFunc = function(choice)
                savedVariables.reticle_choice = choice
                UpdateReticle(choice)
            end,
            width = "full",
        },
        {
            type = "colorpicker",
            name = "Reticle Color",
            tooltip = "Changes the color. Applies instantly.",
            getFunc = function() 
                local c = savedVariables.color or defaults.color
                return c.r, c.g, c.b, c.a 
            end,
            setFunc = function(r, g, b, a)
                savedVariables.color = savedVariables.color or {}
                savedVariables.color.r = r
                savedVariables.color.g = g
                savedVariables.color.b = b
                savedVariables.color.a = a
                UpdateReticleColor() -- Instantané grâce à CT_TEXTURE !
            end,
            width = "full",
        },
        {
            type = "slider",
            name = "Global Scale (%)",
            tooltip = "Adjusts the base size of the reticle.",
            min = 50,
            max = 200,
            step = 5,
            getFunc = function() return savedVariables.reticle_scale end,
            setFunc = function(value)
                savedVariables.reticle_scale = value
                UpdateReticleScale()
            end,
            width = "full",
        },
        {
            type = "header",
            name = "Animations",
        },
        {
            type = "checkbox",
            name = "Interaction Focus (Targeting)",
            tooltip = "The reticle tightens when you aim at an NPC, Enemy, or Object.",
            getFunc = function() return savedVariables.enable_interact_anim end,
            setFunc = function(value)
                savedVariables.enable_interact_anim = value
                if not value then MyCustomReticle_Interact:SetScale(1) end
            end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Pulse Effect (Breathing)",
            tooltip = "Continuous breathing animation of the reticle.",
            getFunc = function() return savedVariables.enable_pulse end,
            setFunc = function(value)
                savedVariables.enable_pulse = value
                UpdatePulseAnimationState()
            end,
            width = "full",
        },
        {
            type = "slider",
            name = "Pulse Speed (ms)",
            tooltip = "The lower the number, the faster the pulse.",
            min = 200,
            max = 2500,
            step = 50,
            getFunc = function() return savedVariables.pulse_speed end,
            setFunc = function(value)
                savedVariables.pulse_speed = value
                UpdatePulseAnimationState()
            end,
            width = "full",
            disabled = function() return not savedVariables.enable_pulse end,
        },
    }

    LibAddonMenu2:RegisterOptionControls(ADDON_NAME.."Panel", optionsData)
end

function TrueReticle.OnAddOnLoaded(event, addonName)
    if addonName == ADDON_NAME then
        TrueReticle:Initialize()
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, TrueReticle.OnAddOnLoaded)