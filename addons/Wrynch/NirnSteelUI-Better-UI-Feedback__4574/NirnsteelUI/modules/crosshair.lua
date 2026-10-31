local ADDON_NAME = "NirnsteelUI"
local EVENT_NAMESPACE = ADDON_NAME .. "_Crosshair"
local UPDATE_NAMESPACE = EVENT_NAMESPACE .. "_Update"
local FADE_IN_MS, FADE_OUT_MS = 120, 100
local CUSTOM_STYLES = { dot = true, cross = true, openCross = true, ring = true, diamond = true, chevron = true }

Nirnsteel_UI = Nirnsteel_UI or {}
local Crosshair = {}
Nirnsteel_UI.Crosshair = Crosshair

local function Settings()
    return Nirnsteel_UI.Settings:GetCrosshair()
end

local function CreatePart(parent, kind, width, height, x, y, shadow)
    local control = WINDOW_MANAGER:CreateControl(nil, parent, kind)
    control:SetDimensions(width, height)
    control:SetAnchor(CENTER, parent, CENTER, x or 0, y or 0)
    control:SetDrawLayer(DL_OVERLAY)
    control:SetDrawLevel(shadow and 0 or 1)
    control:SetMouseEnabled(false)
    control:SetAlpha(1)
    control:SetHidden(false)
    return control
end

local function AddStroke(shape, width, height, x, y)
    local shadow = CreatePart(shape.control, CT_TEXTURE, width + 2, height + 2, x, y, true)
    shadow:SetColor(0, 0, 0, 0.70)
    local control = CreatePart(shape.control, CT_TEXTURE, width, height, x, y, false)
    control:SetColor(1, 1, 1, 1)
    shape.parts[#shape.parts + 1] = { control = control }
end

local function AddPolygon(shape, points, width, height, filled, smooth)
    for _, shadow in ipairs({ true, false }) do
        local control = CreatePart(shape.control, CT_POLYGON,
            width + (shadow and 2 or 0), height + (shadow and 2 or 0), 0, 0, shadow)
        control:SetPointLayout(POLYGON_POINT_LAYOUT_CLOCKWISE)
        control:SetSmoothingEnabled(smooth == true)
        for _, point in ipairs(points) do control:AddPoint(point[1], point[2]) end
        control:SetBorderDirection(POLYGON_BORDER_DIRECTION_IN)
        local thickness = filled and 0 or (shadow and 2.5 or 1.2)
        control:SetBorderThickness(thickness, thickness, 1)
        local color, alpha = shadow and 0 or 1, shadow and 0.70 or 1
        control:SetCenterColor(color, color, color, filled and alpha or 0)
        control:SetBorderColor(color, color, color, alpha)
        if not shadow then
            shape.parts[#shape.parts + 1] = { control = control, polygon = true, filled = filled }
        end
    end
end

local function CreateShape(parent, style)
    local shape = { control = CreatePart(parent, CT_CONTROL, 64, 64), parts = {} }
    if style == "cross" then
        AddStroke(shape, 9, 1.2)
        AddStroke(shape, 1.2, 9)
    elseif style == "openCross" then
        AddStroke(shape, 4, 1.2, -5)
        AddStroke(shape, 4, 1.2, 5)
        AddStroke(shape, 1.2, 4, 0, -5)
        AddStroke(shape, 1.2, 4, 0, 5)
    elseif style == "dot" or style == "ring" then
        local points = {}
        for index = 0, 31 do
            local angle = index * math.pi * 2 / 32
            points[#points + 1] = { 0.5 + math.sin(angle) * 0.5, 0.5 - math.cos(angle) * 0.5 }
        end
        local size = style == "dot" and 3 or 11
        AddPolygon(shape, points, size, size, style == "dot", true)
    elseif style == "diamond" then
        AddPolygon(shape, { {0.5,0}, {1,0.5}, {0.5,1}, {0,0.5} }, 12, 12, false)
    elseif style == "chevron" then
        AddPolygon(shape, { {0,0}, {0.5,0.75}, {1,0}, {1,0.25}, {0.5,1}, {0,0.25} }, 11, 7, true)
    elseif style == "shield" then
        AddPolygon(shape, { {0.5,0}, {1,0.16}, {0.9,0.55}, {0.7,0.85},
            {0.5,1}, {0.3,0.85}, {0.1,0.55}, {0,0.16} }, 15, 19, false)
        AddStroke(shape, 1, 10, 0, -1)
    end
    return shape
end

local function TintShape(shape, r, g, b)
    if not shape then return end
    for _, part in ipairs(shape.parts) do
        if part.polygon then
            if part.filled then part.control:SetCenterColor(r, g, b, 1)
            else part.control:SetBorderColor(r, g, b, 1) end
        else
            part.control:SetColor(r, g, b, 1)
        end
    end
end

function Crosshair:ApplyAppearance()
    local config = Settings()
    self.original.control:SetScale(self.original.baseScale * config.scale / 100)
    self.glyph.control:SetScale(config.scale / 100)
    self.shield.control:SetScale(config.shieldScale / 100)
    self.original.baseAlpha = self.original.nativeAlpha * config.opacity / 100
    self.glyph.baseAlpha = config.opacity / 100
    self.shield.baseAlpha = config.shieldOpacity / 100

    local color = config.color
    local hitTimeline = self.native.hitIndicatorTimeline
    if hitTimeline then
        -- Keep ESO's red hit feedback, returning to the selected color.
        local animation = hitTimeline:GetAnimation(1)
        animation:SetEndColor(color.r, color.g, color.b, 1)
        animation:SetApplyAlpha(false)
    end
    if not hitTimeline or not hitTimeline:IsPlaying() then
        self.original.control:SetColor(color.r, color.g, color.b, 1)
    end
    local shieldColor = config.shieldColor
    TintShape(self.shieldShape, shieldColor.r, shieldColor.g, shieldColor.b)
end

function Crosshair:SelectShape(style)
    if self.currentStyle == style then return end
    if self.currentShape then self.currentShape.control:SetHidden(true) end
    self.currentShape = nil
    if CUSTOM_STYLES[style] then
        self.shapes[style] = self.shapes[style] or CreateShape(self.glyph.control, style)
        self.currentShape = self.shapes[style]
        self.currentShape.control:SetHidden(false)
    end
    self.currentStyle = style
end

local function SampleFade(visual, now)
    local fade = visual.fade
    if not fade then return visual.alpha end
    local progress = math.max(0, math.min(1, (now - fade.startMS) / fade.durationMS))
    local eased = progress * progress * (3 - 2 * progress)
    local alpha = fade.from + (visual.target - fade.from) * eased
    if progress == 1 then visual.fade = nil end
    return alpha
end

function Crosshair:FadeTo(visual, visible, now, instant)
    local alpha = SampleFade(visual, now)
    local target = visible and 1 or 0
    if instant then
        alpha = target
        visual.fade = nil
    elseif target ~= visual.target then
        -- Reverse from the current opacity when the target changes mid-fade.
        visual.fade = { from = alpha, startMS = now,
            durationMS = target == 1 and FADE_IN_MS or FADE_OUT_MS }
    end
    visual.alpha, visual.target = alpha, target
    visual.control:SetAlpha(alpha * visual.baseAlpha)
    visual.control:SetHidden(alpha == 0 and target == 0)
end

function Crosshair:IsInteractionAvailable()
    local native = self.native
    if native.interact:IsHidden() or native.interactionBlocked then return false end
    local _, available, questInteraction, _, _, _, questToolOnCooldown = GetGameCameraInteractableInfo()
    return available == true or (questInteraction == true and not questToolOnCooldown)
end

function Crosshair:UpdateState(instant)
    if not self.native or self.suspended then return end
    local config = Settings()
    local now = GetFrameTimeMilliseconds()
    local eligible = not self.native.control:IsControlHidden()
        and IsGameCameraActive() and not IsGameCameraUIModeActive()
        and not self.nativeTextureHidden
    local blocking = eligible and config.blockIndicator and IsBlockActive()
    local aiming = eligible and not blocking and config.visibility ~= "hidden"
    if aiming and config.visibility == "interaction" then
        aiming = self:IsInteractionAvailable()
    end
    local custom = CUSTOM_STYLES[config.style] == true
    self:SelectShape(custom and config.style or "eso")
    -- Opacity belongs to our fade container, independently of the hidden stock
    -- texture. Only copy its hit-feedback RGB, never its rendered alpha.
    local r, g, b = self.native.reticleTexture:GetColor()
    TintShape(self.currentShape, r, g, b)
    instant = instant or not eligible
    self:FadeTo(self.original, aiming and not custom, now, instant)
    self:FadeTo(self.glyph, aiming and custom, now, instant)
    self:FadeTo(self.shield, blocking, now, instant)
end

function Crosshair:HideImmediately()
    if not self.native then return end
    local now = GetFrameTimeMilliseconds()
    for _, visual in ipairs({ self.original, self.glyph, self.shield }) do
        self:FadeTo(visual, false, now, true)
    end
end

function Crosshair:Initialize()
    if self.native then return true end
    if not RETICLE or not RETICLE.control or not RETICLE.reticleTexture or not RETICLE.interact then
        return false
    end
    self.native = RETICLE
    self.nativeTextureHidden = RETICLE.reticleTexture:IsHidden()
    self.original = { control = RETICLE.reticleTexture, alpha = 1, target = 1,
        baseAlpha = RETICLE.reticleTexture:GetControlAlpha(),
        nativeAlpha = RETICLE.reticleTexture:GetControlAlpha(),
        baseScale = RETICLE.reticleTexture:GetControlScale() }

    self.shapes = {}
    local function CreateVisual()
        local control = WINDOW_MANAGER:CreateControl(nil, RETICLE.control, CT_CONTROL)
        control:SetDimensions(64, 64)
        -- The stock texture is intentionally hidden/faded for custom styles.
        -- Position against its HUD container instead of that invisible texture.
        control:SetAnchor(CENTER, RETICLE.control, CENTER, 0, 0)
        control:SetDrawLayer(DL_OVERLAY)
        control:SetMouseEnabled(false)
        control:SetAlpha(0)
        control:SetHidden(true)
        return { control = control, alpha = 0, target = 0, baseAlpha = 1 }
    end
    self.glyph = CreateVisual()
    self.shield = CreateVisual()
    self.shieldShape = CreateShape(self.shield.control, "shield")

    ZO_PostHook(self.native, "UpdateHiddenState", function()
        -- Capture ESO's decision before applying ours: our own hidden flag must
        -- never be mistaken for stealth/disguise hiding on the next frame.
        self.nativeTextureHidden = self.native.reticleTexture:IsHidden()
        self:UpdateState()
    end)
    return true
end

function Crosshair:RefreshSettings()
    if not self:Initialize() then return end
    self:ApplyAppearance()
    self.native:UpdateHiddenState()
    if not self.suspended and not self.updating then
        -- Do not depend on another addon's replacement/cached reticle handler.
        EVENT_MANAGER:RegisterForUpdate(UPDATE_NAMESPACE, 0, function() self:UpdateState() end)
        self.updating = true
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= ADDON_NAME then return end
    EVENT_MANAGER:UnregisterForEvent(EVENT_NAMESPACE .. "_Loaded", EVENT_ADD_ON_LOADED)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE, EVENT_PLAYER_ACTIVATED, function()
        Crosshair.suspended = false
        Crosshair:RefreshSettings()
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Deactivated", EVENT_PLAYER_DEACTIVATED, function()
        Crosshair.suspended = true
        Crosshair.updating = false
        EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAMESPACE)
        Crosshair:HideImmediately()
    end)
    Crosshair:RefreshSettings()
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAMESPACE .. "_Loaded", EVENT_ADD_ON_LOADED, OnAddOnLoaded)
