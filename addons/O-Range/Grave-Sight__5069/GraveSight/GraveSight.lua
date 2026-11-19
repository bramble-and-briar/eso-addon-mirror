local ADDON_NAME = "GraveSight"

local LAM2 = LibAddonMenu2
local GraveSight = {}

GraveSight.defaults = {
    enabled = true,
    size = 64,
    idleOpacity = 50,
    enemyColoring = true,
    lockRotation = true,
    stealthColorStyle = 1,
}

local reticle
local texture

local currentRotation = 0
local targetRotation = 0

local ROTATION_SPEED = 0.12

-- Rotates left toward 10 o'clock.
local LOCK_ROTATION = math.rad(60)

local STEALTH_COLORS = {
    [1] = {0.65, 0.45, 0.85}, -- Arcane Purple
    [2] = {0.40, 0.10, 0.65}, -- Necromancer Purple
    [3] = {0.85, 0.20, 1.00}, -- Glowing Purple
}

local STEALTH_STYLE_NAMES = {
    "Arcane Purple",
    "Necromancer Purple",
    "Glowing Purple",
}

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

    if ZO_ReticleContainerReticle then
        ZO_ReticleContainerReticle:SetAlpha(alpha)
    end

    if ZO_ReticleContainerNonInteract then
        ZO_ReticleContainerNonInteract:SetAlpha(alpha)
    end

    if ZO_ReticleContainerNonInteractText then
        ZO_ReticleContainerNonInteractText:SetAlpha(alpha)
    end

    if ZO_ReticleContainerStealthIcon then
        ZO_ReticleContainerStealthIcon:SetHidden(hidden)
    end

    if ZO_ReticleContainerStealthIconStealthText then
        ZO_ReticleContainerStealthIconStealthText:SetHidden(hidden)
    end
end

local function IsUiOpen()
    local scene = SCENE_MANAGER:GetCurrentScene()

    if scene and HIDDEN_SCENES[scene.name] then
        return true
    end

    return IsGameCameraUIModeActive()
end

local function IsPlayerStealthed()
    local state = GetUnitStealthState("player")

    return
        state == STEALTH_STATE_HIDDEN or
        state == STEALTH_STATE_STEALTH or
        state == STEALTH_STATE_HIDDEN_ALMOST_DETECTED or
        state == STEALTH_STATE_STEALTH_ALMOST_DETECTED
end

local function UpdateAppearance()
    if not GraveSight.db.enabled then
        if reticle then
            reticle:SetHidden(true)
        end

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

    local hostile =
        DoesUnitExist(target)
        and IsUnitAttackable(target)

    local alpha = GraveSight.db.idleOpacity / 100

    if hostile then
        if GraveSight.db.enemyColoring then
            texture:SetColor(1, 0, 0, 1)
        else
            texture:SetColor(1, 1, 1, 1)
        end

        if GraveSight.db.lockRotation then
            targetRotation = LOCK_ROTATION
        else
            targetRotation = 0
        end

    elseif IsPlayerStealthed() then
        local color =
            STEALTH_COLORS[GraveSight.db.stealthColorStyle]
            or STEALTH_COLORS[1]

        texture:SetColor(
            color[1],
            color[2],
            color[3],
            alpha
        )

        targetRotation = 0

    else
        texture:SetColor(
            1,
            1,
            1,
            alpha
        )

        targetRotation = 0
    end

    currentRotation =
        currentRotation +
        ((targetRotation - currentRotation) * ROTATION_SPEED)

    texture:SetTextureRotation(currentRotation)
end

local function RefreshSize()
    if not reticle then
        return
    end

    reticle:SetDimensions(
        GraveSight.db.size,
        GraveSight.db.size
    )
end

local function CreateSettings()
    if not LAM2 then
        return
    end

    local panelData = {
        type = "panel",
        name = "GraveSight",
        displayName = "GraveSight",
        author = "O-Range",
        version = "0.4.2",
        registerForRefresh = true,
        registerForDefaults = true,
    }

    LAM2:RegisterAddonPanel(
        "GraveSightSettings",
        panelData
    )

    local optionsData = {
        {
            type = "checkbox",
            name = "Enable GraveSight",
            getFunc = function()
                return GraveSight.db.enabled
            end,
            setFunc = function(value)
                GraveSight.db.enabled = value
            end,
        },
        {
            type = "slider",
            name = "Reticle Size",
            min = 24,
            max = 128,
            step = 1,
            getFunc = function()
                return GraveSight.db.size
            end,
            setFunc = function(value)
                GraveSight.db.size = value
                RefreshSize()
            end,
        },
        {
            type = "slider",
            name = "Idle Opacity",
            min = 10,
            max = 100,
            step = 1,
            getFunc = function()
                return GraveSight.db.idleOpacity
            end,
            setFunc = function(value)
                GraveSight.db.idleOpacity = value
            end,
        },
        {
            type = "checkbox",
            name = "Enable Enemy Coloring",
            getFunc = function()
                return GraveSight.db.enemyColoring
            end,
            setFunc = function(value)
                GraveSight.db.enemyColoring = value
            end,
        },
        {
            type = "checkbox",
            name = "Enable Lock Rotation",
            getFunc = function()
                return GraveSight.db.lockRotation
            end,
            setFunc = function(value)
                GraveSight.db.lockRotation = value
            end,
        },
        {
            type = "dropdown",
            name = "Stealth Color Style",
            choices = STEALTH_STYLE_NAMES,
            getFunc = function()
                return STEALTH_STYLE_NAMES[GraveSight.db.stealthColorStyle]
            end,
            setFunc = function(value)
                if value == "Arcane Purple" then
                    GraveSight.db.stealthColorStyle = 1
                elseif value == "Necromancer Purple" then
                    GraveSight.db.stealthColorStyle = 2
                else
                    GraveSight.db.stealthColorStyle = 3
                end
            end,
        },
    }

    LAM2:RegisterOptionControls(
        "GraveSightSettings",
        optionsData
    )
end

local function CreateReticle()
    reticle = WINDOW_MANAGER:CreateTopLevelWindow(
        "GraveSightReticle"
    )

    reticle:SetDimensions(
        GraveSight.db.size,
        GraveSight.db.size
    )

    reticle:SetAnchor(
        CENTER,
        GuiRoot,
        CENTER,
        0,
        0
    )

    reticle:SetMouseEnabled(false)

    texture = WINDOW_MANAGER:CreateControl(
        "GraveSightReticleTexture",
        reticle,
        CT_TEXTURE
    )

    texture:SetAnchorFill()

    texture:SetTexture(
        "GraveSight/textures/gravesight.dds"
    )

    texture:SetColor(
        1,
        1,
        1,
        GraveSight.db.idleOpacity / 100
    )

    reticle:SetHidden(false)
end

local function OnAddonLoaded(event, addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    EVENT_MANAGER:UnregisterForEvent(
        ADDON_NAME,
        EVENT_ADD_ON_LOADED
    )

    GraveSight.db = ZO_SavedVars:NewAccountWide(
        "GraveSightVars",
        1,
        nil,
        GraveSight.defaults
    )

    CreateReticle()
    CreateSettings()

    EVENT_MANAGER:RegisterForUpdate(
        ADDON_NAME .. "_Update",
        16,
        UpdateAppearance
    )
end

EVENT_MANAGER:RegisterForEvent(
    ADDON_NAME,
    EVENT_ADD_ON_LOADED,
    OnAddonLoaded
)