-- 1. On déclare l'addon globalement pour éviter les soucis de portée
TrueSynergiesMover = {}
local TSM = TrueSynergiesMover

TSM.name = "TrueSynergiesMover"

-- Valeurs par défaut
local defaults = {
    x = 500,
    y = 500
}

-- 2. Fonction pour déplacer la Synergie
-- ATTENTION : On utilise ZO_SynergyTopLevel (le contrôle) et non ZO_Synergy (l'objet script)
function TSM.UpdatePosition()
    local control = ZO_SynergyTopLevel 
    
    if control then
        control:ClearAnchors()
        -- On ancre par rapport au GUI Root (l'écran global)
        control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, TSM.savedVars.x, TSM.savedVars.y)
    end
end

-- 3. Fonction de création du menu
function TSM.CreateSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelData = {
        type = "panel",
        name = "True Synergies Mover",
        displayName = "|cFF0000True Synergies Mover|r",
        author = "|cff5900To|cb16754ud|c6374a8id|c1581fcef|r",
        version = "1.0.0",
        registerForRefresh = true,
    }

    local optionsTable = {
        {
            type = "header",
            name = "Positions",
        },
        {
            type = "description",
            text = "Use slider to move synergies positions.",
        },
        {
            type = "slider",
            name = "Position X (Horizontal)",
            min = 0,
            max = GuiRoot:GetWidth(),
            step = 10,
            getFunc = function() return TSM.savedVars.x end,
            setFunc = function(value) 
                TSM.savedVars.x = value
                TSM.UpdatePosition() 
            end,
            default = defaults.x,
        },
        {
            type = "slider",
            name = "Position Y (Vertical)",
            min = 0,
            max = GuiRoot:GetHeight(),
            step = 10,
            getFunc = function() return TSM.savedVars.y end,
            setFunc = function(value) 
                TSM.savedVars.y = value
                TSM.UpdatePosition() 
            end,
            default = defaults.y,
        },
        {
            type = "button",
            name = "Toggle synergies display.",
            tooltip = "Display synergies to see where it is.",
            func = function()
                local control = ZO_SynergyTopLevel
                if control:IsHidden() then
                    control:SetHidden(false)
                else
                    control:SetHidden(true)
                end
            end,
            width = "full",
        }
    }

    LAM:RegisterAddonPanel(TSM.name .. "Options", panelData)
    LAM:RegisterOptionControls(TSM.name .. "Options", optionsTable)
end

-- 4. La fonction d'initialisation (L'événement)
local function OnAddOnLoaded(event, addedName)
    if addedName ~= TSM.name then return end

    -- On charge les variables (compte entier)
    TSM.savedVars = ZO_SavedVars:NewAccountWide("TrueSynergiesMover_Data", 1, nil, defaults)

    -- On construit le menu
    TSM.CreateSettingsMenu()

    -- On applique la position initiale
    TSM.UpdatePosition()

    -- On désenregistre l'événement pour ne pas le lancer deux fois
    EVENT_MANAGER:UnregisterForEvent(TSM.name, EVENT_ADD_ON_LOADED)
end

-- 5. L'enregistrement de l'événement DOIT être à la toute fin du fichier
-- pour être sûr que la fonction "OnAddOnLoaded" juste au-dessus est bien lue par le jeu.
EVENT_MANAGER:RegisterForEvent(TSM.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)