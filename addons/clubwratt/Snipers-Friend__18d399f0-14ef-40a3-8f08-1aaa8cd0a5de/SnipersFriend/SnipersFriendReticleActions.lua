-- SnipersFriendReticleActions.lua: Replace the native crosshair with a dot.
--
-- Strategy: the game's reticle lives in ZO_ReticleContainer (shown/hidden by the
-- engine via IsReticleHidden + RETICLE:UpdateHiddenState). We parent our own
-- texture to that container so visibility rules (menus, cutscenes, dialogs) are
-- inherited for free, and keep the native ZO_ReticleContainerReticle texture
-- hidden while enabled. Stealth hides the native texture; we mirror that state.
-- Hostile tint + hit flash are re-implemented on our texture because the native
-- ones animate the hidden texture.

local SnipersFriend = SnipersFriend
local Utils = SnipersFriend.ReticleUtils

local ReticleActions = {}

local DOT_CONTROL_NAME = "SnipersFriendDot"
local HIT_FLASH_MS = 750

---@return SnipersFriendReticleSettings
local function Settings()
    return SnipersFriend.state.savedVars.reticle
end

---@return SnipersFriendState
local function State()
    return SnipersFriend.state
end

---@return TextureControl|nil
local function GetNativeReticle()
    local container = _G["ZO_ReticleContainer"]
    if not container then return nil end
    return container:GetNamedChild("Reticle")
end

local function EnsureDotControl()
    local state = State()
    if state.dotControl then return true end

    local container = _G["ZO_ReticleContainer"]
    if not container then return false end

    local existing = _G[DOT_CONTROL_NAME]
    local dot = existing or WINDOW_MANAGER:CreateControl(DOT_CONTROL_NAME, container, CT_TEXTURE)
    if not dot then return false end

    dot:SetDrawLayer(DL_OVERLAY)
    dot:SetDrawLevel(1)
    dot:SetHidden(true)
    state.dotControl = dot
    state.nativeReticle = GetNativeReticle()
    return true
end

local function EnsureHitTimeline()
    local state = State()
    if state.hitTimeline or not state.dotControl then return end
    local timeline = ANIMATION_MANAGER:CreateTimeline()
    local anim = timeline:InsertAnimation(ANIMATION_COLOR, state.dotControl, 0)
    ---@cast anim AnimationObjectColor
    anim:SetDuration(HIT_FLASH_MS)
    anim:SetEasingFunction(ZO_EaseOutQuadratic)
    state.hitTimeline = timeline
    state.hitAnimation = anim
end

---@return number, number, number, number
local function CurrentColor()
    local s = Settings()
    if s.hostileTint and State().isHostile then
        return Utils.UnpackColor(s.hostileColor)
    end
    return Utils.UnpackColor(s.color)
end

function ReticleActions.RefreshColor()
    local dot = State().dotControl
    if not dot then return end
    if State().gtOverriding then
        return -- ground-target indicator owns the colour right now
    end
    local timeline = State().hitTimeline
    if timeline and timeline:IsPlaying() then
        return -- the flash animation ends on the right colour (see OnImpactfulHit)
    end
    dot:SetColor(CurrentColor())
end

function ReticleActions.RefreshStyle()
    local dot = State().dotControl
    if not dot then return end
    local s = Settings()
    local style = Utils.GetStyle(s.style)
    local size = Utils.Clamp(s.size or 48, 8, 256)
    dot:SetTexture(style.texture)
    dot:SetDimensions(size, size)
    dot:ClearAnchors()
    dot:SetAnchor(CENTER, dot:GetParent(), CENTER, 0, s.offsetY or 0)
    ReticleActions.RefreshColor()
end

---Mirror native stealth-hide onto the dot; keep native texture hidden while enabled.
function ReticleActions.OnNativeHiddenUpdate()
    local state = State()
    local native = state.nativeReticle
    local dot = state.dotControl
    if not (native and dot) then return end

    if Settings().enabled then
        -- native UpdateHiddenState just ran: hidden == in stealth/disguise
        local stealthHidden = native:IsHidden()
        dot:SetHidden(stealthHidden)
        native:SetHidden(true)
    else
        dot:SetHidden(true)
    end
end

function ReticleActions.OnImpactfulHit()
    local state = State()
    if not (Settings().enabled and Settings().hitFlash) then return end
    EnsureHitTimeline()
    local anim = state.hitAnimation
    local timeline = state.hitTimeline
    if not (anim and timeline) then return end
    local r, g, b, a = CurrentColor()
    if state.gtOverriding and state.dotControl.GetColor then
        r, g, b, a = state.dotControl:GetColor()
    end
    anim:SetColorValues(1, 0, 0, a, r, g, b, a)
    timeline:PlayFromStart()
end

---Called every frame after the native reticle update (cheap: one engine query).
function ReticleActions.OnReticleUpdate()
    local state = State()
    if not Settings().enabled or not state.dotControl then return end
    local GT = SnipersFriend.GroundTargetActions
    if GT then GT.OnUpdate() end
    local AL = SnipersFriend.AimLineActions
    if AL then AL.OnUpdate() end
    if not Settings().hostileTint then
        if state.isHostile then
            state.isHostile = false
            ReticleActions.RefreshColor()
        end
        return
    end
    if not state.canQueryHostile then return end
    local hostile = IsGameCameraUnitHighlightedAttackable() == true
    if hostile ~= state.isHostile then
        state.isHostile = hostile
        ReticleActions.RefreshColor()
    end
end

---@param enabled boolean
function ReticleActions.SetEnabled(enabled)
    Settings().enabled = enabled
    ReticleActions.Apply()
end

function ReticleActions.Apply()
    if not EnsureDotControl() then return end
    local state = State()
    local native = state.nativeReticle
    if Settings().enabled then
        ReticleActions.RefreshStyle()
        -- Re-run the native visibility logic, then our post-hook fixes up both textures.
        if RETICLE and RETICLE.UpdateHiddenState then
            RETICLE:UpdateHiddenState()
        else
            ReticleActions.OnNativeHiddenUpdate()
        end
    else
        state.dotControl:SetHidden(true)
        if native then
            native:SetHidden(false)
            if RETICLE and RETICLE.UpdateHiddenState then
                RETICLE:UpdateHiddenState()
            end
        end
    end
end

local function InstallHooks()
    local state = State()
    if state.hooksInstalled then return end
    local ReticleClass = _G["ZO_Reticle"]
    if not ReticleClass then return end

    ZO_PostHook(ReticleClass, "UpdateHiddenState", function()
        ReticleActions.OnNativeHiddenUpdate()
    end)
    ZO_PostHook(ReticleClass, "OnImpactfulHit", function()
        ReticleActions.OnImpactfulHit()
    end)
    ZO_PostHook(ReticleClass, "OnUpdate", function()
        ReticleActions.OnReticleUpdate()
    end)
    state.hooksInstalled = true
end

---@return boolean
function ReticleActions.Initialize()
    if not EnsureDotControl() then return false end
    State().canQueryHostile = SnipersFriend.CameraUtils.IsCallable("IsGameCameraUnitHighlightedAttackable")
    InstallHooks()
    ReticleActions.Apply()
    return true
end

SnipersFriend.ReticleActions = ReticleActions
