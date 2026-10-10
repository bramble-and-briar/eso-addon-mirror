local TrueReticle = {}
local ADDON_NAME = "TrueReticle"
local CURRENT_VERSION = "1.2" -- À changer si besoin lors de futures versions
local savedVariables
local MyCustomReticle = nil

local defaults = {
    reticle_choice = "Default",
    lastSeenVersion = "0.0.0", -- Permet de détecter la première ouverture
}

local reticle_choices = {
    "Default",
    "Cross",
    "green_cross",
    "Dot",
    "BigDot",
    "Circle",
    "Halo",
}

-- 1. Enregistrement de la boîte de dialogue native (compatible Gamepad et Clavier/Souris)
ESO_Dialogs["TRUERETICLE_V2_ANNOUNCEMENT"] = {
    gamepadInfo = {
        dialogType = GAMEPAD_DIALOGS.BASIC,
    },
    title = {
        text = "TrueReticle " .. CURRENT_VERSION,
    },
    mainText = {
        text = "|cff5900True Reticle 2.0 is out now.\nYou can Download it on the same category as this one (UI Graphics) and uninstall this one.|r",
    },
    buttons = {
        {
            text = SI_DIALOG_CANCEL, -- Affiche "Fermer" (B sur Xbox / Rond sur PlayStation)
            keybind = "DIALOG_NEGATIVE",
            callback = function(dialog)
                -- Rien de particulier à la fermeture
            end,
        },
    },
}

-- --- FONCTIONS DE SECURITE MODIFIEES ---

-- Cette fonction réduit la taille à 0 (invisible par taille)
local function SafeSetScaleZero(control)
    if control then
        if control:GetScale() ~= 0 then
            control:SetScale(0)
        end
    end
end

-- Cette fonction remet la taille normale à 1
local function SafeSetScaleNormal(control)
    if control then
        if control:GetScale() ~= 1 then
            control:SetScale(1)
        end
        if control:GetAlpha() < 1 then
            control:SetAlpha(1)
        end
    end
end

-- Fonction pour changer le réticule
local function UpdateReticle(reticleName)
    if not MyCustomReticle then return end

    if reticleName == "Default" then
        MyCustomReticle:SetHidden(true)
        SafeSetScaleNormal(ZO_ReticleContainerReticle)
        SafeSetScaleNormal(ZO_ReticleContainerCombatLock)
    else
        MyCustomReticle:SetHidden(false)
        
        local texturePath = string.format("/TrueReticle/reticles/%s.dds", string.lower(reticleName))
        MyCustomReticle:SetTexture(texturePath)
        
        SafeSetScaleZero(ZO_ReticleContainerReticle)
        SafeSetScaleZero(ZO_ReticleContainerCombatLock)
    end
end

function TrueReticle:Initialize()
    savedVariables = ZO_SavedVars:NewAccountWide("TrueReticleSavedVars", 1, nil, defaults)

    -- Création de la texture
    MyCustomReticle = WINDOW_MANAGER:CreateControl("TrueReticle_Texture", ZO_ReticleContainer, CT_TEXTURE)
    MyCustomReticle:SetAnchor(CENTER, ZO_ReticleContainer, CENTER, 0, 0)
    MyCustomReticle:SetDimensions(32, 32)
    MyCustomReticle:SetDrawTier(DT_HIGH)

    self:InitializeSettingsMenu()

    -- Boucle de contrôle (toutes les 50ms)
    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME.."_Loop", 50, function()
        if savedVariables.reticle_choice ~= "Default" then
            SafeSetScaleZero(ZO_ReticleContainerReticle)
            SafeSetScaleZero(ZO_ReticleContainerCombatLock)
        end
    end)

    -- Événement déclenché une fois que le joueur arrive en jeu
    EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, function()
        UpdateReticle(savedVariables.reticle_choice)

        -- Vérification pour afficher la boîte de dialogue une SEULE fois après la màj
        if savedVariables.lastSeenVersion ~= CURRENT_VERSION then
            savedVariables.lastSeenVersion = CURRENT_VERSION

            -- Délai de 500ms pour laisser le temps à l'UI manette de se charger
            zo_callLater(function()
                if IsInGamepadPreferredMode() then
                    ZO_Dialogs_ShowGamepadDialog("TRUERETICLE_V2_ANNOUNCEMENT")
                else
                    ZO_Dialogs_ShowDialog("TRUERETICLE_V2_ANNOUNCEMENT")
                end
            end, 500)
        end
    end)
end

function TrueReticle:InitializeSettingsMenu()
    local panelData = {
        type = "panel",
        name = "TrueReticle",
        displayName = "TrueReticle Settings",
        author = "|cff5900To|cb16754ud|c6374a8id|c1581fcef|r",
        version = CURRENT_VERSION,
        slashCommand = "/truereticle",
        registerForRefresh = true,
    }

    local optionsPanel = LibAddonMenu2:RegisterAddonPanel("TrueReticlePanel", panelData)

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
    }

    LibAddonMenu2:RegisterOptionControls("TrueReticlePanel", optionsData)
end

function TrueReticle.OnAddOnLoaded(event, addonName)
    if addonName == ADDON_NAME then
        TrueReticle:Initialize()
        EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
    end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, TrueReticle.OnAddOnLoaded)