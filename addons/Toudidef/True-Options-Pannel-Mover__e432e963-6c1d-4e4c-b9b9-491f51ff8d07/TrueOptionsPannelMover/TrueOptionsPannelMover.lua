TrueOptionsPannelMover = {}
local TOPM = TrueOptionsPannelMover

TOPM.name = "TrueOptionsPannelMover"

local defaults = {
    x = 960, -- Milieu de l'écran environ
    y = 540
}

-- Initialisation de la boite rouge
function TOPM.CreateMoverFrame()
    local frame = WINDOW_MANAGER:CreateTopLevelWindow("TOPM_MoverFrame")
    
    -- Dimensions ajustées pour un panneau d'options classique
    frame:SetDimensions(350, 100)
    
    -- On la met au premier plan
    frame:SetDrawLayer(DL_OVERLAY)
    frame:SetDrawTier(DT_HIGH)
    
    frame:SetHidden(true) 
    
    -- Fond ROUGE uniquement
    local bg = WINDOW_MANAGER:CreateControl("TOPM_MoverFrame_BG", frame, CT_BACKDROP)
    bg:SetAnchorFill()
    bg:SetCenterColor(1, 0, 0, 0.6) -- Rouge semi-transparent
    bg:SetEdgeColor(1, 1, 1, 1) -- Bordure blanche fine
    bg:SetEdgeTexture("", 1, 1, 1, 0)
    
    TOPM.MoverFrame = frame
end

-- Fonction de mise à jour des positions
function TOPM.UpdatePosition()
    local x = TOPM.savedVars.x
    local y = TOPM.savedVars.y

    -- 1. On place le carré rouge exactement où tu le demandes avec le slider
    if TOPM.MoverFrame then
        TOPM.MoverFrame:ClearAnchors()
        TOPM.MoverFrame:SetAnchor(CENTER, GuiRoot, TOPLEFT, x, y)
    end

    -- 2. On place tous les panneaux du jeu en compensant leur décalage invisible
    local panels = {
        ZO_PlayerToPlayerArea,
        ZO_LFGReadyCheck,
        ZO_Resurrect,
        ZO_GroupElection
    }

    for _, panel in ipairs(panels) do
        if panel then
            panel:ClearAnchors()
            -- CORRECTION : On ajoute 280 à l'axe Y (vers le bas) pour aligner les textes sur ton carré rouge
            panel:SetAnchor(CENTER, GuiRoot, TOPLEFT, x, y + 280)
        end
    end

    -- 3. On maintient les sous-titres bien sagement en bas de l'écran
    if ZO_Subtitles then
        ZO_Subtitles:ClearAnchors()
        -- On les ancre au centre, en bas de l'écran (GuiRoot), un peu au dessus de la barre de sorts (-250)
        ZO_Subtitles:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -250)
    end
end

-- 3. On force le placement quand le jeu affiche une de ces fenêtres
function TOPM.ApplyHooks()
    local function EnforcePosition()
        TOPM.UpdatePosition()
    end
    
    local panels = {
        ZO_PlayerToPlayerArea,
        ZO_LFGReadyCheck,
        ZO_Resurrect,
        ZO_GroupElection
    }
    
    for _, panel in ipairs(panels) do
        if panel then
            ZO_PreHookHandler(panel, "OnEffectivelyShown", EnforcePosition)
        end
    end
    
    EVENT_MANAGER:RegisterForEvent(TOPM.name, EVENT_SCREEN_RESIZED, EnforcePosition)
end

function TOPM.CreateSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelData = {
        type = "panel",
        name = "True Options Pannel Mover",
        displayName = "|cFFD700True Options Pannel Mover|r",
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
            text = "Move position X and Y of options pannels.",
        },
        {
            type = "slider",
            name = "Position X (Horizontal)",
            min = 0,
            max = GuiRoot:GetWidth(),
            step = 10,
            getFunc = function() return TOPM.savedVars.x end,
            setFunc = function(value) 
                TOPM.savedVars.x = value
                TOPM.UpdatePosition() 
            end,
            default = defaults.x,
        },
        {
            type = "slider",
            name = "Position Y (Vertical)",
            min = 0,
            max = GuiRoot:GetHeight(),
            step = 10,
            getFunc = function() return TOPM.savedVars.y end,
            setFunc = function(value) 
                TOPM.savedVars.y = value
                TOPM.UpdatePosition() 
            end,
            default = defaults.y,
        },
        {
            type = "button",
            name = "Toggle display of the options pannel.",
            func = function()
                if TOPM.MoverFrame:IsHidden() then
                    TOPM.MoverFrame:SetHidden(false)
                else
                    TOPM.MoverFrame:SetHidden(true)
                end
            end,
            width = "full",
        }
    }

    LAM:RegisterAddonPanel(TOPM.name .. "Options", panelData)
    LAM:RegisterOptionControls(TOPM.name .. "Options", optionsTable)
end

local function OnAddOnLoaded(event, addedName)
    if addedName ~= TOPM.name then return end
    
    TOPM.savedVars = ZO_SavedVars:NewAccountWide("TrueOptionsPannelMover_Data", 1, nil, defaults)
    
    TOPM.CreateMoverFrame()
    TOPM.CreateSettingsMenu()
    TOPM.ApplyHooks()
    TOPM.UpdatePosition()
    
    EVENT_MANAGER:UnregisterForEvent(TOPM.name, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(TOPM.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)