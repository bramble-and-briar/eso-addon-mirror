local ADDON_NAME = "GraveSight"
local LAM2 = LibAddonMenu2

local GraveSight = {}

GraveSight.defaults = {
    enabled = true,
    size = 64,
    enemyColoring = true,
    lockRotation = true,
    hideInFirstPerson = false,
    enemySoulFlare = false,

    -- Opacities (0-100)
    idleOpacity    = 55,
    stealthOpacity = 75,
    enemyOpacity   = 100,

    -- Scales & Effects
    stealthScale     = 0.85,        -- 0.50 – 1.00
    pulseStrength    = 0.06,        -- 0.00 – 0.15
    soulFlareIntensity = 65,        -- 0 – 100

    -- Idle Color (pale spectral)
    idleRed   = 0.78,
    idleGreen = 0.72,
    idleBlue  = 0.92,

    -- Stealth Color (necro purple)
    stealthRed   = 0.55,
    stealthGreen = 0.25,
    stealthBlue  = 0.85,

    -- Enemy Color
    enemyRed   = 1.00,
    enemyGreen = 0.18,
    enemyBlue  = 0.18,
}

local reticle
local texture

-- Animation state
local currentRotation = 0
local targetRotation = 0
local currentOpacity = 0.55
local targetOpacity = 0.55
local stealthScale = 1.0
local targetStealthScale = 1.0
local lockPulseScale = 1.0

local soulFlareIntensity = 0
local soulFlareTarget = 0
local nextSoulFlareTime = 0

local ROTATION_SPEED = 0.12
local OPACITY_LERP_SPEED = 0.14
local STEALTH_LERP_SPEED = 0.08
local LOCK_ROTATION = math.rad(60)          -- left toward 10 o'clock (your original)

local HIDDEN_SCENES = {
    inventory = true,
    skills = true,
    stats = true,
    mailInbox = true,
    mailSend = true,
    bank = true,
    store = true,
    guildRoster = true,
}

local function SetVanillaReticleHidden(hidden)
    local alpha = hidden and 0 or 1
    if ZO_ReticleContainerReticle then ZO_ReticleContainerReticle:SetAlpha(alpha) end
    if ZO_ReticleContainerNonInteract then ZO_ReticleContainerNonInteract:SetAlpha(alpha) end
    if ZO_ReticleContainerNonInteractText then ZO_ReticleContainerNonInteractText:SetAlpha(alpha) end
    if ZO_ReticleContainerStealthIcon then ZO_ReticleContainerStealthIcon:SetHidden(hidden) end
    if ZO_ReticleContainerStealthIconStealthText then ZO_ReticleContainerStealthIconStealthText:SetHidden(hidden) end
end

local function IsUiOpen()
    local scene = SCENE_MANAGER:GetCurrentScene()
    if scene and HIDDEN_SCENES[scene.name] then return true end
    return IsGameCameraUIModeActive()
end

local function IsFirstPerson()
    return GetCameraActiveCameraPOV() == CAMERA_POV_FIRST_PERSON
end

local function IsPlayerStealthed()
    local state = GetUnitStealthState("player")
    return state == STEALTH_STATE_HIDDEN
        or state == STEALTH_STATE_STEALTH
        or state == STEALTH_STATE_HIDDEN_ALMOST_DETECTED
        or state == STEALTH_STATE_STEALTH_ALMOST_DETECTED
end

local function GetFlickerMultiplier()
    return 0.95 + (math.random() * 0.10)
end

local function UpdateSize()
    if not reticle then return end
    local finalScale = stealthScale * lockPulseScale
    local finalSize = math.floor(GraveSight.db.size * finalScale)
    reticle:SetDimensions(finalSize, finalSize)
end

local function UpdateSoulFlare(hostile)
    local now = GetFrameTimeMilliseconds()
    local allowFlare = not hostile or GraveSight.db.enemySoulFlare

    if not allowFlare then
        soulFlareIntensity = 0
        soulFlareTarget = 0
        return
    end

    if now >= nextSoulFlareTime and soulFlareIntensity <= 0.01 then
        soulFlareIntensity = 1.0
        soulFlareTarget = 0.0
        nextSoulFlareTime = now + math.random(2200, 5800)   -- slower & more ominous than lightning
    end

    soulFlareIntensity = soulFlareIntensity + ((soulFlareTarget - soulFlareIntensity) * 0.28)
    if soulFlareIntensity < 0.01 then soulFlareIntensity = 0 end
end

local function ApplySoulFlare(r, g, b)
    local strength = (GraveSight.db.soulFlareIntensity / 100)
    local flash = soulFlareIntensity * strength

    -- Necrotic / spectral shift (pushes toward purple-magenta)
    local finalR = r + ((0.75 - r) * flash)
    local finalG = g + ((0.35 - g) * flash)
    local finalB = b + ((0.95 - b) * flash)

    return finalR, finalG, finalB
end

local function UpdateAppearance()
    if not GraveSight.db.enabled then
        if reticle then reticle:SetHidden(true) end
        SetVanillaReticleHidden(false)
        return
    end

    if IsUiOpen() or (GraveSight.db.hideInFirstPerson and IsFirstPerson()) then
        reticle:SetHidden(true)
        SetVanillaReticleHidden(false)
        return
    end

    reticle:SetHidden(false)
    SetVanillaReticleHidden(true)

    local target = "reticleover"
    local hostile = DoesUnitExist(target) and IsUnitAttackable(target)
    local flicker = GetFlickerMultiplier()

    UpdateSoulFlare(hostile)

    if hostile and GraveSight.db.enemyColoring then
        -- ===== ENEMY =====
        targetStealthScale = 1.0
        lockPulseScale = 1.0 + (math.sin(GetFrameTimeMilliseconds() / 90) * GraveSight.db.pulseStrength)

        local r, g, b = ApplySoulFlare(
            GraveSight.db.enemyRed,
            GraveSight.db.enemyGreen,
            GraveSight.db.enemyBlue
        )

        targetOpacity = (GraveSight.db.enemyOpacity / 100) * flicker
        texture:SetColor(r, g, b, currentOpacity)

        targetRotation = GraveSight.db.lockRotation and LOCK_ROTATION or 0

    elseif IsPlayerStealthed() then
        -- ===== STEALTH =====
        targetStealthScale = GraveSight.db.stealthScale
        lockPulseScale = 1.0

        local r, g, b = ApplySoulFlare(
            GraveSight.db.stealthRed,
            GraveSight.db.stealthGreen,
            GraveSight.db.stealthBlue
        )

        targetOpacity = (GraveSight.db.stealthOpacity / 100) * flicker
        texture:SetColor(r, g, b, currentOpacity)
        targetRotation = 0

    else
        -- ===== IDLE =====
        targetStealthScale = 1.0
        lockPulseScale = 1.0

        local r, g, b = ApplySoulFlare(
            GraveSight.db.idleRed,
            GraveSight.db.idleGreen,
            GraveSight.db.idleBlue
        )

        targetOpacity = (GraveSight.db.idleOpacity / 100) * flicker
        texture:SetColor(r, g, b, currentOpacity)
        targetRotation = 0
    end

    -- Smooth transitions
    stealthScale    = stealthScale    + ((targetStealthScale - stealthScale)    * STEALTH_LERP_SPEED)
    currentRotation = currentRotation + ((targetRotation     - currentRotation) * ROTATION_SPEED)
    currentOpacity  = currentOpacity  + ((targetOpacity      - currentOpacity)  * OPACITY_LERP_SPEED)

    texture:SetTextureRotation(currentRotation)
    texture:SetAlpha(currentOpacity)
    UpdateSize()
end

local function RefreshSize()
    UpdateSize()
end

local function ResetColorsAndOpacities()
    local d = GraveSight.defaults
    GraveSight.db.idleOpacity    = d.idleOpacity
    GraveSight.db.stealthOpacity = d.stealthOpacity
    GraveSight.db.enemyOpacity   = d.enemyOpacity

    GraveSight.db.idleRed,   GraveSight.db.idleGreen,   GraveSight.db.idleBlue   = d.idleRed,   d.idleGreen,   d.idleBlue
    GraveSight.db.stealthRed,GraveSight.db.stealthGreen,GraveSight.db.stealthBlue = d.stealthRed,d.stealthGreen,d.stealthBlue
    GraveSight.db.enemyRed,  GraveSight.db.enemyGreen,  GraveSight.db.enemyBlue  = d.enemyRed,  d.enemyGreen,  d.enemyBlue

    GraveSight.db.stealthScale       = d.stealthScale
    GraveSight.db.pulseStrength      = d.pulseStrength
    GraveSight.db.soulFlareIntensity = d.soulFlareIntensity
end

local function CreateSettings()
    if not LAM2 then return end

    local panelData = {
        type = "panel",
        name = "GraveSight",
        displayName = "GraveSight",
        author = "O-Range",
        version = "0.5.0",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    LAM2:RegisterAddonPanel("GraveSightSettings", panelData)

    local optionsData = {
        {
            type = "checkbox",
            name = "Enable GraveSight",
            getFunc = function() return GraveSight.db.enabled end,
            setFunc = function(v) GraveSight.db.enabled = v end,
        },
        {
            type = "slider",
            name = "Reticle Size",
            min = 24, max = 128, step = 1,
            getFunc = function() return GraveSight.db.size end,
            setFunc = function(v) GraveSight.db.size = v RefreshSize() end,
        },
        {
            type = "checkbox",
            name = "Enable Enemy Coloring",
            getFunc = function() return GraveSight.db.enemyColoring end,
            setFunc = function(v) GraveSight.db.enemyColoring = v end,
        },
        {
            type = "checkbox",
            name = "Enable Lock Rotation",
            getFunc = function() return GraveSight.db.lockRotation end,
            setFunc = function(v) GraveSight.db.lockRotation = v end,
        },
        {
            type = "checkbox",
            name = "Hide in First Person",
            getFunc = function() return GraveSight.db.hideInFirstPerson end,
            setFunc = function(v) GraveSight.db.hideInFirstPerson = v end,
        },
        {
            type = "checkbox",
            name = "Soul Flare on Enemies",
            tooltip = "Allow the necrotic soul flare even while targeting enemies",
            getFunc = function() return GraveSight.db.enemySoulFlare end,
            setFunc = function(v) GraveSight.db.enemySoulFlare = v end,
        },

        -- ===== EFFECTS =====
        { type = "header", name = "Effects" },
        {
            type = "slider",
            name = "Soul Flare Intensity",
            tooltip = "Strength of the occasional necrotic / spectral flare",
            min = 0, max = 100, step = 1,
            getFunc = function() return GraveSight.db.soulFlareIntensity end,
            setFunc = function(v) GraveSight.db.soulFlareIntensity = v end,
        },
        {
            type = "slider",
            name = "Stealth Scale",
            tooltip = "How much smaller the reticle becomes while stealthed",
            min = 50, max = 100, step = 1,
            getFunc = function() return math.floor(GraveSight.db.stealthScale * 100) end,
            setFunc = function(v) GraveSight.db.stealthScale = v / 100 end,
        },
        {
            type = "slider",
            name = "Enemy Pulse Strength",
            min = 0, max = 15, step = 1,
            getFunc = function() return math.floor(GraveSight.db.pulseStrength * 100) end,
            setFunc = function(v) GraveSight.db.pulseStrength = v / 100 end,
        },

        -- ===== OPACITY =====
        { type = "header", name = "Opacity" },
        {
            type = "slider",
            name = "Idle Opacity",
            min = 10, max = 100, step = 1,
            getFunc = function() return GraveSight.db.idleOpacity end,
            setFunc = function(v) GraveSight.db.idleOpacity = v end,
        },
        {
            type = "slider",
            name = "Stealth Opacity",
            min = 10, max = 100, step = 1,
            getFunc = function() return GraveSight.db.stealthOpacity end,
            setFunc = function(v) GraveSight.db.stealthOpacity = v end,
        },
        {
            type = "slider",
            name = "Enemy Opacity",
            min = 10, max = 100, step = 1,
            getFunc = function() return GraveSight.db.enemyOpacity end,
            setFunc = function(v) GraveSight.db.enemyOpacity = v end,
        },

        -- ===== COLORS =====
        { type = "header", name = "Colors" },
        {
            type = "colorpicker",
            name = "Idle Color",
            getFunc = function() return GraveSight.db.idleRed, GraveSight.db.idleGreen, GraveSight.db.idleBlue end,
            setFunc = function(r, g, b)
                GraveSight.db.idleRed = r
                GraveSight.db.idleGreen = g
                GraveSight.db.idleBlue = b
            end,
            default = { r = 0.78, g = 0.72, b = 0.92 },
        },
        {
            type = "colorpicker",
            name = "Stealth Color",
            getFunc = function() return GraveSight.db.stealthRed, GraveSight.db.stealthGreen, GraveSight.db.stealthBlue end,
            setFunc = function(r, g, b)
                GraveSight.db.stealthRed = r
                GraveSight.db.stealthGreen = g
                GraveSight.db.stealthBlue = b
            end,
            default = { r = 0.55, g = 0.25, b = 0.85 },
        },
        {
            type = "colorpicker",
            name = "Enemy Color",
            getFunc = function() return GraveSight.db.enemyRed, GraveSight.db.enemyGreen, GraveSight.db.enemyBlue end,
            setFunc = function(r, g, b)
                GraveSight.db.enemyRed = r
                GraveSight.db.enemyGreen = g
                GraveSight.db.enemyBlue = b
            end,
            default = { r = 1.00, g = 0.18, b = 0.18 },
        },

        -- ===== RESET =====
        {
            type = "button",
            name = "Reset Colors & Opacities",
            tooltip = "Restore all colors, opacities and effect strengths to default",
            func = ResetColorsAndOpacities,
            width = "full",
        },
    }

    LAM2:RegisterOptionControls("GraveSightSettings", optionsData)
end

local function CreateReticle()
    reticle = WINDOW_MANAGER:CreateTopLevelWindow("GraveSightReticle")
    reticle:SetDimensions(GraveSight.db.size, GraveSight.db.size)
    reticle:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    reticle:SetMouseEnabled(false)

    texture = WINDOW_MANAGER:CreateControl("GraveSightReticleTexture", reticle, CT_TEXTURE)
    texture:SetAnchorFill()
    texture:SetTexture("GraveSight/textures/gravesight.dds")

    currentOpacity = GraveSight.db.idleOpacity / 100
    texture:SetColor(GraveSight.db.idleRed, GraveSight.db.idleGreen, GraveSight.db.idleBlue, currentOpacity)

    reticle:SetHidden(false)
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    GraveSight.db = ZO_SavedVars:NewAccountWide("GraveSightVars", 5, nil, GraveSight.defaults)

    math.randomseed(GetTimeStamp())
    CreateReticle()
    CreateSettings()

    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_Update", 16, UpdateAppearance)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)