local ADDON_NAME = "StormEye"
local LAM2 = LibAddonMenu2

local StormEye = {}

StormEye.defaults = {
    enabled = true,
    size = 64,
    enemyColoring = true,
    lockRotation = true,
    hideInFirstPerson = false,
    enemyLightning = false,

    -- Opacities (0-100)
    idleOpacity    = 50,
    stealthOpacity = 70,
    enemyOpacity   = 100,

    -- Scales & Effects
    stealthScale   = 0.82,          -- 0.50 – 1.00
    pulseStrength  = 0.05,          -- 0.00 – 0.15
    lightningIntensity = 70,        -- 0 – 100

    -- Idle Color
    idleRed   = 0.75,
    idleGreen = 0.90,
    idleBlue  = 1.00,

    -- Stealth Color
    stealthRed   = 0.25,
    stealthGreen = 0.65,
    stealthBlue  = 1.00,

    -- Enemy Color
    enemyRed   = 1.00,
    enemyGreen = 0.15,
    enemyBlue  = 0.15,
}

local reticle
local texture

-- Animation state
local currentRotation = 0
local targetRotation = 0
local currentOpacity = 0.5
local targetOpacity = 0.5
local stealthScale = 1.0
local targetStealthScale = 1.0
local lockPulseScale = 1.0

local lightningIntensity = 0
local lightningTarget = 0
local nextLightningTime = 0

local ROTATION_SPEED = 0.12
local OPACITY_LERP_SPEED = 0.15
local STEALTH_LERP_SPEED = 0.08
local LOCK_ROTATION = math.rad(45)

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
    return 0.94 + (math.random() * 0.12)
end

local function UpdateSize()
    if not reticle then return end
    local finalScale = stealthScale * lockPulseScale
    local finalSize = math.floor(StormEye.db.size * finalScale)
    reticle:SetDimensions(finalSize, finalSize)
end

local function UpdateLightning(hostile)
    local now = GetFrameTimeMilliseconds()
    local allowLightning = not hostile or StormEye.db.enemyLightning

    if not allowLightning then
        lightningIntensity = 0
        lightningTarget = 0
        return
    end

    if now >= nextLightningTime and lightningIntensity <= 0.01 then
        lightningIntensity = 1.0
        lightningTarget = 0.0
        nextLightningTime = now + math.random(1800, 5000)
    end

    lightningIntensity = lightningIntensity + ((lightningTarget - lightningIntensity) * 0.35)
    if lightningIntensity < 0.01 then lightningIntensity = 0 end
end

local function ApplyLightning(r, g, b)
    local strength = (StormEye.db.lightningIntensity / 100)
    local flash = lightningIntensity * strength

    local finalR = r + ((0.85 - r) * flash)
    local finalG = g + ((0.95 - g) * flash)
    local finalB = b + ((1.00 - b) * flash)
    return finalR, finalG, finalB
end

local function UpdateAppearance()
    if not StormEye.db.enabled then
        if reticle then reticle:SetHidden(true) end
        SetVanillaReticleHidden(false)
        return
    end

    if IsUiOpen() or (StormEye.db.hideInFirstPerson and IsFirstPerson()) then
        reticle:SetHidden(true)
        SetVanillaReticleHidden(false)
        return
    end

    reticle:SetHidden(false)
    SetVanillaReticleHidden(true)

    local target = "reticleover"
    local hostile = DoesUnitExist(target) and IsUnitAttackable(target)
    local flicker = GetFlickerMultiplier()

    UpdateLightning(hostile)

    if hostile and StormEye.db.enemyColoring then
        -- ===== ENEMY =====
        targetStealthScale = 1.0
        lockPulseScale = 1.0 + (math.sin(GetFrameTimeMilliseconds() / 95) * StormEye.db.pulseStrength)

        local r, g, b = ApplyLightning(
            StormEye.db.enemyRed,
            StormEye.db.enemyGreen,
            StormEye.db.enemyBlue
        )

        targetOpacity = (StormEye.db.enemyOpacity / 100) * flicker
        texture:SetColor(r, g, b, currentOpacity)

        targetRotation = StormEye.db.lockRotation and LOCK_ROTATION or 0

    elseif IsPlayerStealthed() then
        -- ===== STEALTH =====
        targetStealthScale = StormEye.db.stealthScale
        lockPulseScale = 1.0

        local r, g, b = ApplyLightning(
            StormEye.db.stealthRed,
            StormEye.db.stealthGreen,
            StormEye.db.stealthBlue
        )

        targetOpacity = (StormEye.db.stealthOpacity / 100) * flicker
        texture:SetColor(r, g, b, currentOpacity)
        targetRotation = 0

    else
        -- ===== IDLE =====
        targetStealthScale = 1.0
        lockPulseScale = 1.0

        local r, g, b = ApplyLightning(
            StormEye.db.idleRed,
            StormEye.db.idleGreen,
            StormEye.db.idleBlue
        )

        targetOpacity = (StormEye.db.idleOpacity / 100) * flicker
        texture:SetColor(r, g, b, currentOpacity)
        targetRotation = 0
    end

    -- Smooth transitions
    stealthScale    = stealthScale    + ((targetStealthScale - stealthScale)    * STEALTH_LERP_SPEED)
    currentRotation = currentRotation + ((targetRotation     - currentRotation) * ROTATION_SPEED)
    currentOpacity  = currentOpacity  + ((targetOpacity      - currentOpacity)  * OPACITY_LERP_SPEED)

    texture:SetTextureRotation(currentRotation)
    texture:SetColor(texture:GetColor()) -- force alpha update if needed
    texture:SetAlpha(currentOpacity)
    UpdateSize()
end

local function RefreshSize()
    UpdateSize()
end

local function ResetColorsAndOpacities()
    local d = StormEye.defaults
    StormEye.db.idleOpacity    = d.idleOpacity
    StormEye.db.stealthOpacity = d.stealthOpacity
    StormEye.db.enemyOpacity   = d.enemyOpacity

    StormEye.db.idleRed,   StormEye.db.idleGreen,   StormEye.db.idleBlue   = d.idleRed,   d.idleGreen,   d.idleBlue
    StormEye.db.stealthRed,StormEye.db.stealthGreen,StormEye.db.stealthBlue = d.stealthRed,d.stealthGreen,d.stealthBlue
    StormEye.db.enemyRed,  StormEye.db.enemyGreen,  StormEye.db.enemyBlue  = d.enemyRed,  d.enemyGreen,  d.enemyBlue

    StormEye.db.stealthScale      = d.stealthScale
    StormEye.db.pulseStrength     = d.pulseStrength
    StormEye.db.lightningIntensity = d.lightningIntensity
end

local function CreateSettings()
    if not LAM2 then return end

    local panelData = {
        type = "panel",
        name = "StormEye",
        displayName = "StormEye",
        author = "O-Range",
        version = "0.3.0",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    LAM2:RegisterAddonPanel("StormEyeSettings", panelData)

    local optionsData = {
        {
            type = "checkbox",
            name = "Enable StormEye",
            getFunc = function() return StormEye.db.enabled end,
            setFunc = function(v) StormEye.db.enabled = v end,
        },
        {
            type = "slider",
            name = "Reticle Size",
            min = 24, max = 128, step = 1,
            getFunc = function() return StormEye.db.size end,
            setFunc = function(v) StormEye.db.size = v RefreshSize() end,
        },
        {
            type = "checkbox",
            name = "Enable Enemy Coloring",
            getFunc = function() return StormEye.db.enemyColoring end,
            setFunc = function(v) StormEye.db.enemyColoring = v end,
        },
        {
            type = "checkbox",
            name = "Enable Lock Rotation",
            getFunc = function() return StormEye.db.lockRotation end,
            setFunc = function(v) StormEye.db.lockRotation = v end,
        },
        {
            type = "checkbox",
            name = "Hide in First Person",
            getFunc = function() return StormEye.db.hideInFirstPerson end,
            setFunc = function(v) StormEye.db.hideInFirstPerson = v end,
        },
        {
            type = "checkbox",
            name = "Lightning on Enemies",
            tooltip = "Allow subtle lightning flashes even while targeting enemies",
            getFunc = function() return StormEye.db.enemyLightning end,
            setFunc = function(v) StormEye.db.enemyLightning = v end,
        },

        -- ===== EFFECTS =====
        { type = "header", name = "Effects" },
        {
            type = "slider",
            name = "Lightning Intensity",
            min = 0, max = 100, step = 1,
            getFunc = function() return StormEye.db.lightningIntensity end,
            setFunc = function(v) StormEye.db.lightningIntensity = v end,
        },
        {
            type = "slider",
            name = "Stealth Scale",
            tooltip = "How much smaller the reticle becomes while stealthed",
            min = 50, max = 100, step = 1,
            getFunc = function() return math.floor(StormEye.db.stealthScale * 100) end,
            setFunc = function(v) StormEye.db.stealthScale = v / 100 end,
        },
        {
            type = "slider",
            name = "Enemy Pulse Strength",
            min = 0, max = 15, step = 1,
            getFunc = function() return math.floor(StormEye.db.pulseStrength * 100) end,
            setFunc = function(v) StormEye.db.pulseStrength = v / 100 end,
        },

        -- ===== OPACITY =====
        { type = "header", name = "Opacity" },
        {
            type = "slider",
            name = "Idle Opacity",
            min = 10, max = 100, step = 1,
            getFunc = function() return StormEye.db.idleOpacity end,
            setFunc = function(v) StormEye.db.idleOpacity = v end,
        },
        {
            type = "slider",
            name = "Stealth Opacity",
            min = 10, max = 100, step = 1,
            getFunc = function() return StormEye.db.stealthOpacity end,
            setFunc = function(v) StormEye.db.stealthOpacity = v end,
        },
        {
            type = "slider",
            name = "Enemy Opacity",
            min = 10, max = 100, step = 1,
            getFunc = function() return StormEye.db.enemyOpacity end,
            setFunc = function(v) StormEye.db.enemyOpacity = v end,
        },

        -- ===== COLORS =====
        { type = "header", name = "Colors" },
        {
            type = "colorpicker",
            name = "Idle Color",
            getFunc = function() return StormEye.db.idleRed, StormEye.db.idleGreen, StormEye.db.idleBlue end,
            setFunc = function(r, g, b)
                StormEye.db.idleRed = r
                StormEye.db.idleGreen = g
                StormEye.db.idleBlue = b
            end,
            default = { r = 0.75, g = 0.90, b = 1.00 },
        },
        {
            type = "colorpicker",
            name = "Stealth Color",
            getFunc = function() return StormEye.db.stealthRed, StormEye.db.stealthGreen, StormEye.db.stealthBlue end,
            setFunc = function(r, g, b)
                StormEye.db.stealthRed = r
                StormEye.db.stealthGreen = g
                StormEye.db.stealthBlue = b
            end,
            default = { r = 0.25, g = 0.65, b = 1.00 },
        },
        {
            type = "colorpicker",
            name = "Enemy Color",
            getFunc = function() return StormEye.db.enemyRed, StormEye.db.enemyGreen, StormEye.db.enemyBlue end,
            setFunc = function(r, g, b)
                StormEye.db.enemyRed = r
                StormEye.db.enemyGreen = g
                StormEye.db.enemyBlue = b
            end,
            default = { r = 1.00, g = 0.15, b = 0.15 },
        },

        -- ===== RESET =====
        {
            type = "button",
            name = "Reset Colors & Opacities",
            tooltip = "Restore all colors, opacities, scale and effect strengths to default",
            func = function()
                ResetColorsAndOpacities()
            end,
            width = "full",
        },
    }

    LAM2:RegisterOptionControls("StormEyeSettings", optionsData)
end

local function CreateReticle()
    reticle = WINDOW_MANAGER:CreateTopLevelWindow("StormEyeReticle")
    reticle:SetDimensions(StormEye.db.size, StormEye.db.size)
    reticle:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    reticle:SetMouseEnabled(false)

    texture = WINDOW_MANAGER:CreateControl("StormEyeReticleTexture", reticle, CT_TEXTURE)
    texture:SetAnchorFill()
    texture:SetTexture("StormEye/textures/StormEye.dds")

    currentOpacity = StormEye.db.idleOpacity / 100
    texture:SetColor(StormEye.db.idleRed, StormEye.db.idleGreen, StormEye.db.idleBlue, currentOpacity)

    reticle:SetHidden(false)
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    StormEye.db = ZO_SavedVars:NewAccountWide("StormEyeVars", 4, nil, StormEye.defaults)

    math.randomseed(GetTimeStamp())
    CreateReticle()
    CreateSettings()

    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_Update", 16, UpdateAppearance)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)