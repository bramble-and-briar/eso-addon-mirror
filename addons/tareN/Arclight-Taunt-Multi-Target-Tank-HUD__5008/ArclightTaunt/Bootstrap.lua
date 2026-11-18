-- Arclight Taunt 1.3.1 | Bootstrap module
-- Loaded in manifest order; requires Core.lua and uses its shared namespace.
local A = ArclightTaunt
local T = A.T
local ADDON = A.ADDON
local EM = A.EM
local MEDIA_BAR_ESO = A.MEDIA_BAR_ESO
local MEDIA_BAR_SIGNAL = A.MEDIA_BAR_SIGNAL
local MEDIA_BAR_SIGNATURE = A.MEDIA_BAR_SIGNATURE
local MEDIA_BG_CARBON = A.MEDIA_BG_CARBON
local MEDIA_BG_CARBON_PATH = A.MEDIA_BG_CARBON_PATH
local MEDIA_BG_OBSIDIAN = A.MEDIA_BG_OBSIDIAN
local MEDIA_BG_OBSIDIAN_PATH = A.MEDIA_BG_OBSIDIAN_PATH
local MEDIA_TEXTURE_SIGNAL = A.MEDIA_TEXTURE_SIGNAL
local MEDIA_TEXTURE_SIGNATURE = A.MEDIA_TEXTURE_SIGNATURE
local MEDIA_TRACK_PATH = A.MEDIA_TRACK_PATH
local TAUNT_IDS = A.TAUNT_IDS
local defaults = A.defaults

local function OnLoaded(_, name)
    if name ~= ADDON then return end
    EM:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)
    local firstInstall = A.LoadSettings()
    A.LMP = LibMediaProvider
    if A.LMP then
        -- Only original files created for Arclight Taunt are bundled.
        -- A.LMP exposes them to Arclight and any other addon that supports statusbars.
        -- Do not call SetTexture with an invalid/unresolved resource path.
        A.LMP:Register("statusbar", MEDIA_BAR_SIGNATURE, MEDIA_TEXTURE_SIGNATURE)
        A.LMP:Register("statusbar", MEDIA_BAR_SIGNAL, MEDIA_TEXTURE_SIGNAL)
        A.LMP:Register("background", MEDIA_BG_OBSIDIAN, MEDIA_BG_OBSIDIAN_PATH)
        A.LMP:Register("background", MEDIA_BG_CARBON, MEDIA_BG_CARBON_PATH)
        A.LMP:Register("background", "Arclight (Fassung)", MEDIA_TRACK_PATH)
        A.LMP:Register("statusbar", MEDIA_BAR_ESO,
            "EsoUI/Art/miscellaneous/progressbar_genericfill_tall.dds")
    end
    -- Missing providers may register later or return after an update. Keep
    -- valid saved keys; Media.lua resolves a temporary display fallback.
    for _, key in ipairs({"fontKey", "timerFontKey", "backgroundKey", "barKey"}) do
        if type(A.saved[key]) ~= "string" or A.saved[key] == "" then A.saved[key] = defaults[key] end
    end
    A.inCombat = type(IsUnitInCombat) == "function" and IsUnitInCombat("player") == true or false
    A.ApplyPalette(false)
    A.MakeUI()
    A.ApplyMedia()
    A.MakeSettings()
    if CALLBACK_MANAGER and type(CALLBACK_MANAGER.RegisterCallback) == "function" then
        CALLBACK_MANAGER:RegisterCallback("LibMediaProvider_Registered", function(mediaType, key)
            local selected = (mediaType == "font" and (key == A.saved.fontKey or key == A.saved.timerFontKey))
                or (mediaType == "statusbar" and key == A.saved.barKey)
                or (mediaType == "background" and key == A.saved.backgroundKey)
            if selected then
                if A.RefreshMediaChoices then A.RefreshMediaChoices(mediaType) end
                A.ApplyMedia()
                A.Tick()
            end
        end)
    end
    for id in pairs(TAUNT_IDS) do
        local eventName = ADDON .. "_Effect_" .. tostring(id)
        EM:RegisterForEvent(eventName, EVENT_EFFECT_CHANGED, A.EffectChanged)
        EM:AddFilterForEvent(eventName, EVENT_EFFECT_CHANGED, REGISTER_FILTER_ABILITY_ID, id)
    end
    EM:RegisterForEvent(ADDON .. "_Combat", EVENT_PLAYER_COMBAT_STATE, A.CombatChanged)
    EM:RegisterForEvent(ADDON .. "_Reticle", EVENT_RETICLE_TARGET_CHANGED, A.ReticleChanged)
    A.ConfigureTargetMarkerEvents()
    if EVENT_RETICLE_HIDDEN_UPDATE then
        EM:RegisterForEvent(ADDON .. "_ReticleVisibility", EVENT_RETICLE_HIDDEN_UPDATE, A.ReticleVisibilityChanged)
    end
    for result in pairs(A.DEATH_RESULTS) do
        local deathEvent = ADDON .. "_Death_" .. tostring(result)
        EM:RegisterForEvent(deathEvent, EVENT_COMBAT_EVENT, A.CombatDeath)
        EM:AddFilterForEvent(deathEvent, EVENT_COMBAT_EVENT,
            REGISTER_FILTER_COMBAT_RESULT, result)
    end
    EM:RegisterForEvent(ADDON .. "_ReticleDeath", EVENT_UNIT_DEATH_STATE_CHANGED, A.ReticleDeath)
    if EVENT_BOSSES_CHANGED then
        EM:RegisterForEvent(ADDON .. "_Bosses", EVENT_BOSSES_CHANGED, function()
            A.reticleUnitId = nil -- boss tags may now refer to different units
            A.ResetTargetMarkers()
            A.TargetChanged()
            A.Tick()
        end)
    end
    -- Tick starts periodic updates only when there is work to do.
    if firstInstall and EVENT_PLAYER_ACTIVATED then
        local welcomeEvent = ADDON .. "_Welcome"
        EM:RegisterForEvent(welcomeEvent, EVENT_PLAYER_ACTIVATED, function()
            EM:UnregisterForEvent(welcomeEvent, EVENT_PLAYER_ACTIVATED)
            if A.saved.welcomeNoticeShown then return end
            A.saved.welcomeNoticeShown = true
            A.Chat(T("Welcome! Set up your HUD: ESC > Settings > Add-ons > Arclight Taunt."))
        end)
    end
    A.Tick()
end
EM:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, OnLoaded)
