local ADDON_NAME = "ClassEye"
local LAM2 = LibAddonMenu2

local ClassEye = {}

ClassEye.defaults = {
    enabled = true,
    reticleStyleIndex = 1,          -- 1 = Base
    size = 64,
    enemyColoring = true,
    lockRotation = true,
    enemyLightning = false,

    idleOpacity    = 55,
    stealthOpacity = 75,
    enemyOpacity   = 75,

    stealthScale   = 0.82,
    pulseStrength  = 0.05,
    lightningIntensity = 70,

    idleRed   = 0.75,
    idleGreen = 0.90,
    idleBlue  = 1.00,

    stealthRed   = 0.25,
    stealthGreen = 0.65,
    stealthBlue  = 1.00,

    enemyRed   = 1.00,
    enemyGreen = 0.15,
    enemyBlue  = 0.15,
}

-- Index-based system
local RETICLE_STYLES = {
    { name = "Base",         path = "ClassEye/textures/Base.dds" },
    { name = "Sorcerer",     path = "ClassEye/textures/Sorcerer.dds" },
    { name = "Dragonknight", path = "ClassEye/textures/Dragonknight.dds" },
    { name = "Blade",        path = "ClassEye/textures/Blade.dds" },
    { name = "Templar",      path = "ClassEye/textures/Templar.dds" },
    { name = "Warden",       path = "ClassEye/textures/Warden.dds" },
    { name = "Necromancer",  path = "ClassEye/textures/Necromancer.dds" },
    { name = "Arcanist",     path = "ClassEye/textures/Arcanist.dds" },
}

local RETICLE_STYLE_CHOICES = {}
for i, style in ipairs(RETICLE_STYLES) do
    RETICLE_STYLE_CHOICES[i] = style.name
end

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
    local finalSize = math.floor(ClassEye.db.size * finalScale)
    reticle:SetDimensions(finalSize, finalSize)
end

local function UpdateLightning(hostile)
    local now = GetFrameTimeMilliseconds()
    local allowLightning = not hostile or ClassEye.db.enemyLightning

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
    local strength = (ClassEye.db.lightningIntensity / 100)
    local flash = lightningIntensity * strength

    local finalR = r + ((0.85 - r) * flash)
    local finalG = g + ((0.95 - g) * flash)
    local finalB = b + ((1.00 - b) * flash)
    return finalR, finalG, finalB
end

local function ApplyReticleTexture()
    if not texture then return end

    local index = ClassEye.db.reticleStyleIndex or 1
    if index < 1 or index > #RETICLE_STYLES then
        index = 1
        ClassEye.db.reticleStyleIndex = 1
    end

    local path = RETICLE_STYLES[index].path

    -- Force full texture reload
    texture:SetTexture("")
    texture:SetTexture(path)

    -- Debug message
    d("|c00FF00[ClassEye]|r Applied style #" .. index .. " → " .. path)
end

local function UpdateAppearance()
    if not ClassEye.db.enabled then
        if reticle then reticle:SetHidden(true) end
        SetVanillaReticleHidden(false)
        return
    end

    if IsUiOpen() then
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

    if hostile and ClassEye.db.enemyColoring then
        targetStealthScale = 1.0
        lockPulseScale = 1.0 + (math.sin(GetFrameTimeMilliseconds() / 95) * ClassEye.db.pulseStrength)

        local r, g, b = ApplyLightning(
            ClassEye.db.enemyRed,
            ClassEye.db.enemyGreen,
            ClassEye.db.enemyBlue
        )

        targetOpacity = (ClassEye.db.enemyOpacity / 100) * flicker
        texture:SetColor(r, g, b, currentOpacity)
        targetRotation = ClassEye.db.lockRotation and LOCK_ROTATION or 0

    elseif IsPlayerStealthed() then
        targetStealthScale = ClassEye.db.stealthScale
        lockPulseScale = 1.0

        local r, g, b = ApplyLightning(
            ClassEye.db.stealthRed,
            ClassEye.db.stealthGreen,
            ClassEye.db.stealthBlue
        )

        targetOpacity = (ClassEye.db.stealthOpacity / 100) * flicker
        texture:SetColor(r, g, b, currentOpacity)
        targetRotation = 0

    else
        targetStealthScale = 1.0
        lockPulseScale = 1.0

        local r, g, b = ApplyLightning(
            ClassEye.db.idleRed,
            ClassEye.db.idleGreen,
            ClassEye.db.idleBlue
        )

        targetOpacity = (ClassEye.db.idleOpacity / 100) * flicker
        texture:SetColor(r, g, b, currentOpacity)
        targetRotation = 0
    end

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

local function ResetColorsAndSettings()
    local d = ClassEye.defaults
    ClassEye.db.reticleStyleIndex  = d.reticleStyleIndex
    ClassEye.db.idleOpacity        = d.idleOpacity
    ClassEye.db.stealthOpacity     = d.stealthOpacity
    ClassEye.db.enemyOpacity       = d.enemyOpacity

    ClassEye.db.idleRed,   ClassEye.db.idleGreen,   ClassEye.db.idleBlue   = d.idleRed,   d.idleGreen,   d.idleBlue
    ClassEye.db.stealthRed,ClassEye.db.stealthGreen,ClassEye.db.stealthBlue = d.stealthRed,d.stealthGreen,d.stealthBlue
    ClassEye.db.enemyRed,  ClassEye.db.enemyGreen,  ClassEye.db.enemyBlue  = d.enemyRed,  d.enemyGreen,  d.enemyBlue

    ClassEye.db.stealthScale       = d.stealthScale
    ClassEye.db.pulseStrength      = d.pulseStrength
    ClassEye.db.lightningIntensity = d.lightningIntensity

    ApplyReticleTexture()
    RefreshSize()
end

local function CreateSettings()
    if not LAM2 then return end

    local panelData = {
        type = "panel",
        name = "ClassEye",
        displayName = "ClassEye",
        author = "O-Range",
        version = "1.0.3",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    LAM2:RegisterAddonPanel("ClassEyeSettings", panelData)

    local optionsData = {
        { type = "header", name = "General" },
        {
            type = "checkbox",
            name = "Enable ClassEye",
            getFunc = function() return ClassEye.db.enabled end,
            setFunc = function(v) ClassEye.db.enabled = v end,
        },
        {
            type = "dropdown",
            name = "Reticle Style",
            tooltip = "Select which class reticle texture to display",
            choices = RETICLE_STYLE_CHOICES,
            getFunc = function()
                local index = ClassEye.db.reticleStyleIndex or 1
                return RETICLE_STYLES[index] and RETICLE_STYLES[index].name or "Base"
            end,
            setFunc = function(selectedName)
                for i, style in ipairs(RETICLE_STYLES) do
                    if style.name == selectedName then
                        ClassEye.db.reticleStyleIndex = i
                        ApplyReticleTexture()
                        break
                    end
                end
            end,
            default = "Base",
        },
        {
            type = "slider",
            name = "Reticle Size",
            min = 24, max = 128, step = 1,
            getFunc = function() return ClassEye.db.size end,
            setFunc = function(v) ClassEye.db.size = v RefreshSize() end,
        },

        { type = "header", name = "Combat" },
        {
            type = "checkbox",
            name = "Enable Enemy Coloring",
            getFunc = function() return ClassEye.db.enemyColoring end,
            setFunc = function(v) ClassEye.db.enemyColoring = v end,
        },
        {
            type = "checkbox",
            name = "Enable Lock Rotation",
            getFunc = function() return ClassEye.db.lockRotation end,
            setFunc = function(v) ClassEye.db.lockRotation = v end,
        },
        {
            type = "checkbox",
            name = "Lightning on Enemies",
            tooltip = "Allow subtle lightning flashes even while targeting enemies",
            getFunc = function() return ClassEye.db.enemyLightning end,
            setFunc = function(v) ClassEye.db.enemyLightning = v end,
        },

        { type = "header", name = "Effects" },
        {
            type = "slider",
            name = "Lightning Intensity",
            min = 0, max = 100, step = 1,
            getFunc = function() return ClassEye.db.lightningIntensity end,
            setFunc = function(v) ClassEye.db.lightningIntensity = v end,
        },
        {
            type = "slider",
            name = "Stealth Scale",
            tooltip = "How much smaller the reticle becomes while stealthed",
            min = 50, max = 100, step = 1,
            getFunc = function() return math.floor(ClassEye.db.stealthScale * 100) end,
            setFunc = function(v) ClassEye.db.stealthScale = v / 100 end,
        },
        {
            type = "slider",
            name = "Enemy Pulse Strength",
            min = 0, max = 15, step = 1,
            getFunc = function() return math.floor(ClassEye.db.pulseStrength * 100) end,
            setFunc = function(v) ClassEye.db.pulseStrength = v / 100 end,
        },

        { type = "header", name = "Opacity" },
        {
            type = "slider",
            name = "Idle Opacity",
            min = 10, max = 100, step = 1,
            getFunc = function() return ClassEye.db.idleOpacity end,
            setFunc = function(v) ClassEye.db.idleOpacity = v end,
        },
        {
            type = "slider",
            name = "Stealth Opacity",
            min = 10, max = 100, step = 1,
            getFunc = function() return ClassEye.db.stealthOpacity end,
            setFunc = function(v) ClassEye.db.stealthOpacity = v end,
        },
        {
            type = "slider",
            name = "Enemy Opacity",
            min = 10, max = 100, step = 1,
            getFunc = function() return ClassEye.db.enemyOpacity end,
            setFunc = function(v) ClassEye.db.enemyOpacity = v end,
        },

        { type = "header", name = "Colors" },
        {
            type = "colorpicker",
            name = "Idle Color",
            getFunc = function() return ClassEye.db.idleRed, ClassEye.db.idleGreen, ClassEye.db.idleBlue end,
            setFunc = function(r, g, b)
                ClassEye.db.idleRed = r
                ClassEye.db.idleGreen = g
                ClassEye.db.idleBlue = b
            end,
            default = { r = 0.75, g = 0.90, b = 1.00 },
        },
        {
            type = "colorpicker",
            name = "Stealth Color",
            getFunc = function() return ClassEye.db.stealthRed, ClassEye.db.stealthGreen, ClassEye.db.stealthBlue end,
            setFunc = function(r, g, b)
                ClassEye.db.stealthRed = r
                ClassEye.db.stealthGreen = g
                ClassEye.db.stealthBlue = b
            end,
            default = { r = 0.25, g = 0.65, b = 1.00 },
        },
        {
            type = "colorpicker",
            name = "Enemy Color",
            getFunc = function() return ClassEye.db.enemyRed, ClassEye.db.enemyGreen, ClassEye.db.enemyBlue end,
            setFunc = function(r, g, b)
                ClassEye.db.enemyRed = r
                ClassEye.db.enemyGreen = g
                ClassEye.db.enemyBlue = b
            end,
            default = { r = 1.00, g = 0.15, b = 0.15 },
        },

        {
            type = "button",
            name = "Reset Colors & Settings",
            tooltip = "Restore reticle style, colors, opacities, scale and effect strengths to default",
            func = function()
                ResetColorsAndSettings()
            end,
            width = "full",
        },
    }

    LAM2:RegisterOptionControls("ClassEyeSettings", optionsData)
end

local function CreateReticle()
    reticle = WINDOW_MANAGER:CreateTopLevelWindow("ClassEyeReticle")
    reticle:SetDimensions(ClassEye.db.size, ClassEye.db.size)
    reticle:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    reticle:SetMouseEnabled(false)

    texture = WINDOW_MANAGER:CreateControl("ClassEyeReticleTexture", reticle, CT_TEXTURE)
    texture:SetAnchorFill()
    ApplyReticleTexture()

    currentOpacity = ClassEye.db.idleOpacity / 100
    texture:SetColor(ClassEye.db.idleRed, ClassEye.db.idleGreen, ClassEye.db.idleBlue, currentOpacity)

    reticle:SetHidden(false)
end

local function OnAddonLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)

    -- Version 8 - Base / Blade rename
    ClassEye.db = ZO_SavedVars:NewAccountWide("ClassEyeVars", 8, nil, ClassEye.defaults)

    math.randomseed(GetTimeStamp())
    CreateReticle()
    CreateSettings()

    EVENT_MANAGER:RegisterForUpdate(ADDON_NAME .. "_Update", 16, UpdateAppearance)
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)