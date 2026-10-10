TrueFlagCaptureMover = {}
local TFCM = TrueFlagCaptureMover

TFCM.name = "TrueFlagCaptureMover"

local defaults = {
    x = 900,
    y = 100
}

-- Initialisation de la boite rouge (Carré simple, sans texte)
function TFCM.CreateMoverFrame()
    local frame = WINDOW_MANAGER:CreateTopLevelWindow("TFCM_MoverFrame")
    
    -- Dimensions ajustées pour coller au plus près de la vraie barre visuelle
    frame:SetDimensions(100, 100)
    
    -- On la met au premier plan
    frame:SetDrawLayer(DL_OVERLAY)
    frame:SetDrawTier(DT_HIGH)
    
    frame:SetHidden(true) 
    
    -- Fond ROUGE uniquement
    local bg = WINDOW_MANAGER:CreateControl("TFCM_MoverFrame_BG", frame, CT_BACKDROP)
    bg:SetAnchorFill()
    bg:SetCenterColor(1, 0, 0, 0.6) -- Rouge semi-transparent
    bg:SetEdgeColor(1, 1, 1, 1) -- Bordure blanche fine
    bg:SetEdgeTexture("", 1, 1, 1, 0)
    
    TFCM.MoverFrame = frame
end

-- Fonction de mise à jour des positions
function TFCM.UpdatePosition()
    local x = TFCM.savedVars.x
    local y = TFCM.savedVars.y

    -- 1. On place le carré rouge
    if TFCM.MoverFrame then
        TFCM.MoverFrame:ClearAnchors()
        -- CHANGEMENT : On ancre par le CENTRE pour éviter le décalage
        TFCM.MoverFrame:SetAnchor(CENTER, GuiRoot, TOPLEFT, x, y -60)
    end

    -- 2. On place la barre de capture du jeu exactement au même endroit
    local gameControl = ZO_ObjectiveCaptureMeter 
    if gameControl then
        gameControl:ClearAnchors()
        -- On ancre aussi le CENTRE de la barre de jeu aux mêmes coordonnées
        gameControl:SetAnchor(CENTER, GuiRoot, TOPLEFT, x, y)
    end
end

function TFCM.CreateSettingsMenu()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelData = {
        type = "panel",
        name = "True Flag Capture Mover",
        displayName = "|c00FF00True Flag Capture Mover|r",
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
            text = "Move position X and Y.",
        },
        {
            type = "slider",
            name = "Position X (Horizontal)",
            min = 0,
            max = GuiRoot:GetWidth(),
            step = 10,
            getFunc = function() return TFCM.savedVars.x end,
            setFunc = function(value) 
                TFCM.savedVars.x = value
                TFCM.UpdatePosition() 
            end,
            default = defaults.x,
        },
        {
            type = "slider",
            name = "Position Y (Vertical)",
            min = 0,
            max = GuiRoot:GetHeight(),
            step = 10,
            getFunc = function() return TFCM.savedVars.y end,
            setFunc = function(value) 
                TFCM.savedVars.y = value
                TFCM.UpdatePosition() 
            end,
            default = defaults.y,
        },
        {
            type = "button",
            name = "Toggle on/off red square to see where the meter is.",
            func = function()
                if TFCM.MoverFrame:IsHidden() then
                    TFCM.MoverFrame:SetHidden(false)
                else
                    TFCM.MoverFrame:SetHidden(true)
                end
            end,
            width = "full",
        }
    }

    LAM:RegisterAddonPanel(TFCM.name .. "Options", panelData)
    LAM:RegisterOptionControls(TFCM.name .. "Options", optionsTable)
end

local function OnAddOnLoaded(event, addedName)
    if addedName ~= TFCM.name then return end
    
    TFCM.savedVars = ZO_SavedVars:NewAccountWide("TrueFlagCaptureMover_Data", 1, nil, defaults)
    
    TFCM.CreateMoverFrame()
    TFCM.CreateSettingsMenu()
    TFCM.UpdatePosition()
    
    EVENT_MANAGER:UnregisterForEvent(TFCM.name, EVENT_ADD_ON_LOADED)
end

EVENT_MANAGER:RegisterForEvent(TFCM.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)