MidTrialMechs = MidTrialMechs or {}
local MTM = MidTrialMechs

function MidTrialMechs_TogglePanel()
    if MTM.UI and MTM.UI.Toggle then MTM.UI:Toggle() end
end

local hudFragment
local function hookSceneVisibility()
    if hudFragment or not MTM.UI or not MTM.UI.window then return end
    if not HUD_SCENE or not HUD_UI_SCENE then return end
    hudFragment = ZO_HUDFadeSceneFragment:New(MTM.UI.window, nil, 0)
    MTM.UI.hudFragment = hudFragment
end

local function onAddonLoaded(_, addonName)
    if addonName ~= "MidTrialMechs" then return end
    MTM.SV = ZO_SavedVars:NewAccountWide("MidTrialMechs_SavedVars", 1, GetWorldName(), {
        panelPosition = {x = 500, y = 300},
        selectedTrial = "Lucent Citadel",
        selectedBoss = "Count Ryelaz & Zilyesset",
        customText = {},
        bossNotes = {},
    })
    MTM.SV.customText = MTM.SV.customText or {}
    MTM.SV.bossNotes = MTM.SV.bossNotes or {}
    ZO_CreateStringId("SI_BINDING_NAME_MIDTRIALMECHS_PANEL_KEYBIND", "Open/Close Mid Trial Mechs")
    if MTM.UI and MTM.UI.Create then MTM.UI:Create() end
    hookSceneVisibility()
    EVENT_MANAGER:UnregisterForEvent("MidTrialMechs", EVENT_ADD_ON_LOADED)
end
EVENT_MANAGER:RegisterForEvent("MidTrialMechs", EVENT_ADD_ON_LOADED, onAddonLoaded)
