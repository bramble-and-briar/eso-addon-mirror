-- Arclight Taunt 1.2.0 | Optional screen-space taunt indicator
local A = ArclightTaunt
local RING = "ArclightTaunt/Textures/ArclightReticleRing.dds"
local OUTLINE = "ArclightTaunt/Textures/ArclightReticleOutline.dds"
local C, SetHidden = A.C, A.SetHidden
local LinearEase = ZO_LinearEase or function(progress) return progress end

local profileFields = {size = "reticleSize", x = "reticleOffsetX", y = "reticleOffsetY", opacity = "reticleTrackOpacity"}
local profileDefaults = {
    circle = {size = A.defaults.reticleSize, x = 0, y = 0, opacity = A.defaults.reticleTrackOpacity},
    bar = {size = 28, x = 0, y = 45, opacity = A.defaults.reticleTrackOpacity},
}
local function Shape()
    return A.saved.reticleStyle == "bar" and "bar"
        or (A.saved.reticleStyle == "circle" and "circle" or A.saved.reticleLastStyle)
end
local function CopyProfile(profile)
    local copy = {}
    for key in pairs(profileFields) do copy[key] = profile[key] end
    return copy
end
local function Profiles()
    local saved = A.saved
    if type(saved.reticleProfiles) ~= "table" then saved.reticleProfiles = {} end
    for _, style in ipairs({"circle", "bar"}) do
        if type(saved.reticleProfiles[style]) ~= "table" then
            saved.reticleProfiles[style] = CopyProfile(profileDefaults[style])
        end
    end
    return saved.reticleProfiles
end
function A.ReticleProfileDefaults()
    return profileDefaults[Shape()]
end
function A.ReticleThicknessKey()
    return Shape() == "bar" and "reticleBarHeight" or "reticleRingWeight"
end
function A.SetReticleThickness(value)
    A.SaveReticlePosition()
    local key = A.ReticleThicknessKey()
    A.saved[key] = math.floor(A.Clamp(value, 2, 8) * 2 + 0.5) / 2
    A.Tick()
end
function A.SaveReticleProfile()
    local profile = Profiles()[Shape()]
    for key, field in pairs(profileFields) do profile[key] = A.saved[field] end
end
local function LoadProfile(style)
    local profile = Profiles()[style]
    for key, field in pairs(profileFields) do A.saved[field] = profile[key] end
end
function A.InitializeReticleProfiles()
    local source = type(A.saved.reticleProfiles) == "table" and A.saved.reticleProfiles or {}
    local clean = {}
    for _, style in ipairs({"circle", "bar"}) do
        local p = type(source[style]) == "table" and source[style] or {}
        local d = profileDefaults[style]
        clean[style] = {
            size = math.floor(A.FiniteBoundedNumber(p.size, d.size, 16, 40)),
            x = math.floor(A.FiniteBoundedNumber(p.x, d.x, -10000, 10000)),
            y = math.floor(A.FiniteBoundedNumber(p.y, d.y, -10000, 10000)),
            opacity = math.floor(A.FiniteBoundedNumber(p.opacity, d.opacity, 0, 100) + 0.5),
        }
    end
    A.saved.reticleProfiles = clean
    -- Existing flat values remain the active working profile and migration
    -- authority. Only an explicit shape switch loads the other snapshot.
    A.SaveReticleProfile()
end

local function EligibleTarget()
    if not DoesUnitExist("reticleover") or not IsUnitAttackable("reticleover")
        or IsUnitDead("reticleover") then return false end
    if IsUnitPlayer("reticleover") then return A.saved.trackPlayerTargets end
    -- Ambient critters are attackable too. Combine positive observations,
    -- rather than excluding all neutral enemies, low levels or weak monsters.
    -- Native observation: ambient scorpion is level 50, no difficulty, neutral,
    -- with max/effective-max health both exactly 1. Level is not a discriminator.
    -- Unknown classification stays eligible; no name list or low-health cutoff.
    if MONSTER_DIFFICULTY_NONE ~= nil and type(GetUnitDifficulty) == "function"
        and COMBAT_MECHANIC_FLAGS_HEALTH ~= nil and type(GetUnitPower) == "function"
        and type(GetUnitReaction) == "function"
        and GetUnitDifficulty("reticleover") == MONSTER_DIFFICULTY_NONE then
        local reaction = GetUnitReaction("reticleover")
        if reaction ~= nil and (reaction == UNIT_REACTION_NEUTRAL or reaction == UNIT_REACTION_FRIENDLY) then
            local _, maximum, effectiveMaximum = GetUnitPower("reticleover", COMBAT_MECHANIC_FLAGS_HEALTH)
            if maximum ~= 1 or effectiveMaximum ~= 1 then return true end
            -- A directly identified active own taunt overrides the ambient
            -- classification; the filter must not erase real tracking evidence.
            local identified = A.reticleUnitId and A.targets[A.reticleUnitId]
            return identified ~= nil and not identified.dead and not A.IsLost(identified, A.Now())
        end
    end
    return true
end

function A.ReticleNeedsUpdate()
    return A.saved.reticleStyle ~= "off" and not A.demo and not A.reticlePreview
        and not A.reticleMoving and A.inCombat and EligibleTarget()
        -- Allow one initial observation; known excluded enemies need no idle
        -- polling. Target/boss/effect events can wake the existing schedule.
        and (not A.saved.reticleBossOnly or not A.reticleBossTarget or A.BossVisible(A.reticleBossTarget))
end

function A.ReticleVisibilityChanged()
    if A.saved.reticleStyle == "off" or A.demo or A.reticlePreview
        or A.reticleMoving or not A.inCombat then return end
    -- ESO's own visibility handler may run after this event listener. Coalesce
    -- one settled refresh into the existing tick, even if it was asleep.
    -- Never force the native reticle visible or infer a new target identity.
    A.reticleDirty, A.effectTickPending = true, true
    A.RefreshUpdateState()
end

local function Stop(r)
    if r.running then
        r.running = false
        r.circle:ResetCooldown()
        if r.timeline then r.timeline:Stop() end
    end
    r.startTime, r.endTime, r.target, r.paused = nil, nil, nil, nil
    SetHidden(r.circle, true)
    SetHidden(r.fill, true)
end

function A.SaveReticlePosition()
    local r = A.reticleIndicator
    if not r or not r.dragActive then return end
    r.root:StopMovingOrResizing()
    local x, y = r.root:GetCenter()
    local centerX, centerY = GuiRoot:GetCenter()
    A.saved.reticleOffsetX = math.floor(x - centerX + 0.5)
    A.saved.reticleOffsetY = math.floor(y - centerY + 0.5)
    A.SaveReticleProfile()
    r.dragActive = false
    r.offsetX, r.offset = nil, nil
end

function A.SetReticleEnabled(enabled)
    enabled = enabled == true
    if (A.saved.reticleStyle ~= "off") == enabled then return end
    A.SaveReticlePosition()
    A.SaveReticleProfile()
    A.saved.reticleStyle = enabled and A.saved.reticleLastStyle or "off"
    A.reticleDirty = true
    A.Tick()
end
function A.SelectReticleShape(style)
    if style ~= "circle" and style ~= "bar" then return end
    A.SaveReticlePosition()
    local previous = Shape()
    A.SaveReticleProfile()
    if style ~= previous then LoadProfile(style) end
    A.saved.reticleLastStyle = style
    if A.saved.reticleStyle ~= "off" then A.saved.reticleStyle = style end
    A.reticleDirty = true
    A.Tick()
end
function A.SetReticleGeometry(key, value)
    local allowed = key == "reticleSize" or key == "reticleOffsetX" or key == "reticleOffsetY" or key == "reticleTrackOpacity"
    if not allowed then return end
    A.SaveReticlePosition()
    A.saved[key] = value
    A.SaveReticleProfile()
    A.Tick()
end
function A.ResetReticlePosition()
    local d = A.ReticleProfileDefaults()
    A.SaveReticlePosition()
    A.saved.reticleOffsetX, A.saved.reticleOffsetY = d.x, d.y
    A.SaveReticleProfile()
    A.Tick()
end

function A.CenterReticleCircle()
    if A.saved.reticleStyle ~= "circle" then return end
    A.SaveReticlePosition()
    local x, y = 0, 0
    local native = RETICLE and (RETICLE.reticleTexture or RETICLE.control)
    if native and type(native.GetCenter) == "function" then
        local nativeX, nativeY = native:GetCenter()
        local centerX, centerY = GuiRoot:GetCenter()
        x = A.FiniteBoundedNumber(nativeX and nativeX - centerX, 0, -10000, 10000)
        y = A.FiniteBoundedNumber(nativeY and nativeY - centerY, 0, -10000, 10000)
    end
    A.saved.reticleOffsetX, A.saved.reticleOffsetY = math.floor(x + 0.5), math.floor(y + 0.5)
    -- A fixed larger preset leaves space for the native combat glyph without
    -- following its animated texture frames or changing size during combat.
    A.saved.reticleSize = 40
    A.SaveReticleProfile()
    A.Tick()
end

local function ClearSetup()
    A.reticlePreview, A.reticlePreviewAt, A.reticleDirty = nil, nil, true
    A.reticleMoving, A.reticleMoveAt, A.reticlePreviewCrosshair = nil, nil, nil
end
function A.ResetReticleSettings()
    A.SaveReticlePosition()
    local style = Shape()
    Profiles()[style] = CopyProfile(profileDefaults[style])
    LoadProfile(style)
    local thickness = style == "bar" and "reticleBarHeight" or "reticleRingWeight"
    A.saved[thickness] = A.defaults[thickness]
    -- Appearance reset keeps activation and the running comparison preview.
    A.reticleMoving, A.reticleMoveAt, A.reticleDirty = nil, nil, true
    A.Tick()
end
function A.ResetAllReticleSettings()
    A.SaveReticlePosition()
    A.saved.reticleProfiles = nil
    Profiles()
    A.saved.reticleStyle, A.saved.reticleLastStyle = "off", "circle"
    LoadProfile("circle")
    A.saved.reticleBarHeight, A.saved.reticleRingWeight = A.defaults.reticleBarHeight, A.defaults.reticleRingWeight
    A.saved.reticleBossOnly = A.defaults.reticleBossOnly
    ClearSetup()
    A.Tick()
end

function A.SetReticlePreviewEnabled(enabled)
    if type(enabled) ~= "boolean" then return end
    enabled = enabled == true
    if enabled and A.saved.reticleStyle == "off" then return end
    if (A.reticlePreview == true) == enabled then return end
    A.reticlePreview, A.reticlePreviewAt = enabled or nil, enabled and A.Now() or nil
    A.reticleDirty = true
    A.Tick()
end

function A.SetReticlePreviewCrosshair(shape)
    if shape ~= "small" and shape ~= "large" then return end
    A.reticlePreviewCrosshair = shape
    A.Tick()
end

function A.IsReticleMoving()
    return A.moving == true or A.reticleMoving == true
end

-- Independent placement uses the same native drag controls as Move displays,
-- without changing the list's preview, pause state or mouse handling.
function A.SetReticleMoveMode(moving, deferTick)
    moving = moving == true
    if moving and (A.moving or A.saved.reticleStyle == "off") then return end
    if (A.reticleMoving == true) == moving then return end
    A.SaveReticlePosition()
    A.reticleMoving, A.reticleMoveAt = moving or nil, moving and A.Now() or nil
    A.reticleDirty = true -- keep the independent countdown preview while moving
    A.SetReticleMoving(A.IsReticleMoving())
    if not deferTick then A.Tick() end
end

function A.SetReticleMoving(moving)
    local r = A.reticleIndicator
    if not r then return end
    moving = moving == true and A.saved.reticleStyle ~= "off"
    if r.editing == moving then return end
    if not moving then A.SaveReticlePosition() end
    r.editing = moving
    r.root:SetMovable(moving)
    r.root:SetMouseEnabled(moving)
    r.dragSurface:SetMouseEnabled(moving)
    SetHidden(r.dragSurface, not moving)
    SetHidden(r.moveTint, not moving)
    SetHidden(r.moveLabel, not moving)
end

local function Create()
    local root = A.WM:CreateTopLevelWindow("ArclightTauntReticle")
    -- Match the list/banner tier so explicit setup previews stay above menus.
    -- Live visibility still follows the existing HUD/native-reticle gates.
    root:SetDrawTier(DT_HIGH)
    root:SetMouseEnabled(false)
    root:SetClampedToScreen(true)
    local r = {root = root}
    r.ringWeight = 5
    r.ringOutline = A.Solid(root, {0.015, 0.02, 0.025, 0.95})
    r.ringOutline:SetTexture(OUTLINE)
    r.ringTrack = A.Solid(root, {0.53, 0.58, 0.61, 1})
    r.ringTrack:SetTexture(RING)
    -- A frame must have a transparent interior. A larger solid rectangle
    -- underneath the track defeats its opacity control even at zero alpha.
    r.barOutline = A.WM:CreateControl(nil, root, CT_CONTROL)
    r.barEdges = {}
    for i = 1, 4 do
        local edge = A.Solid(r.barOutline, {0.015, 0.02, 0.025, 0.95})
        edge:SetDrawLayer(DL_BACKGROUND)
        edge:SetDrawLevel(1)
        if edge.SetPixelRoundingEnabled then edge:SetPixelRoundingEnabled(false) end
        r.barEdges[i] = edge
    end
    r.barTrack = A.Solid(root, {1, 1, 1, 1})
    -- Half-unit thickness must reach the track/outline as well as the fill.
    if r.barTrack.SetPixelRoundingEnabled then r.barTrack:SetPixelRoundingEnabled(false) end
    r.circle = A.WM:CreateControl(nil, root, CT_COOLDOWN)
    r.circle:SetTexture(RING)
    r.circle:SetRadialCooldownClockwise(true)
    r.circle:SetRadialCooldownOriginAngle(0)
    r.fill = A.Solid(root, {1, 1, 1, 1})
    -- Native anchors carry the endpoint with the shrinking fill. Clip the
    -- light to the remaining width, including the final subpixel fraction.
    r.fill:SetAutoRectClipChildren(true)
    if r.fill.SetPixelRoundingEnabled then r.fill:SetPixelRoundingEnabled(false) end
    r.lightEdge = A.Solid(r.fill, {0.96, 0.98, 1, 1})
    r.lightEdge:SetAnchor(TOPRIGHT, r.fill, TOPRIGHT, 0, 0)
    r.lightEdge:SetDimensions(2, 3)
    r.lightEdge:SetGradientColors(ORIENTATION_HORIZONTAL, 0.96, 0.98, 1, 0,
        0.96, 0.98, 1, 0.95)
    if r.lightEdge.SetPixelRoundingEnabled then r.lightEdge:SetPixelRoundingEnabled(false) end
    r.ringOutline:SetDrawLayer(DL_BACKGROUND)
    r.barOutline:SetDrawLayer(DL_BACKGROUND)
    r.ringOutline:SetDrawLevel(1)
    r.barOutline:SetDrawLevel(1)
    r.ringTrack:SetDrawLayer(DL_CONTROLS)
    r.barTrack:SetDrawLayer(DL_CONTROLS)
    r.circle:SetDrawLayer(DL_OVERLAY)
    r.fill:SetDrawLayer(DL_OVERLAY)
    r.lightEdge:SetDrawLayer(DL_OVERLAY)
    r.lightEdge:SetDrawLevel(1)
    -- A generous edit-only hit area makes a thin marker easy to grab. Native
    -- moving handles motion; the normal tick never reanchors an active drag.
    r.moveTint = A.Solid(root, {0.02, 0.03, 0.04, 0.8})
    r.moveTint:SetDrawLayer(DL_BACKGROUND)
    r.moveTint:SetDrawLevel(0)
    r.moveLabel = A.WM:CreateControl(nil, root, CT_LABEL)
    r.moveLabel:SetFont("ZoFontGameSmall")
    r.moveLabel:SetText(A.T("Crosshair"))
    r.moveLabel:SetAnchor(TOP, root, BOTTOM, 0, 5)
    r.dragSurface = A.WM:CreateControl(nil, root, CT_CONTROL)
    r.dragSurface:SetHandler("OnMouseDown", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and A.IsReticleMoving() then
            r.dragActive = true
            root:StartMoving()
        end
    end)
    r.dragSurface:SetHandler("OnMouseUp", function(_, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and r.dragActive then A.SaveReticlePosition(); A.Tick() end
    end)
    SetHidden(r.moveTint, true)
    SetHidden(r.moveLabel, true)
    SetHidden(r.dragSurface, true)
    r.dragSurface:SetMouseEnabled(false)
    SetHidden(root, true)
    A.reticleIndicator = r
    return r
end

local function Layout(r)
    local saved = A.saved
    if r.dragActive then return false end
    if r.style == saved.reticleStyle and r.size == saved.reticleSize and r.offset == saved.reticleOffsetY
        and r.offsetX == saved.reticleOffsetX
        and (saved.reticleStyle ~= "bar" or r.barHeight == saved.reticleBarHeight) then return false end
    Stop(r)
    local circle, size = saved.reticleStyle == "circle", saved.reticleSize
    local width, height = circle and size or size * 2, circle and size or saved.reticleBarHeight
    r.root:ClearAnchors()
    r.root:SetAnchor(CENTER, GuiRoot, CENTER, saved.reticleOffsetX, saved.reticleOffsetY)
    r.root:SetDimensions(width, height)
    r.ringOutline:SetAnchorFill(r.root)
    r.ringTrack:SetAnchorFill(r.root)
    r.barOutline:ClearAnchors()
    r.barOutline:SetAnchor(TOPLEFT, r.root, TOPLEFT, -1, -1)
    r.barOutline:SetDimensions(width + 2, height + 2)
    for i, edge in ipairs(r.barEdges) do
        local side = i == 2 and BOTTOMLEFT or (i == 4 and TOPRIGHT or TOPLEFT)
        edge:ClearAnchors()
        edge:SetAnchor(side, r.barOutline, side, 0, i >= 3 and 1 or 0)
        edge:SetDimensions(i <= 2 and width + 2 or 1, i <= 2 and 1 or height)
    end
    r.barTrack:SetAnchorFill(r.root)
    SetHidden(r.ringOutline, not circle)
    SetHidden(r.ringTrack, not circle)
    SetHidden(r.barOutline, circle)
    SetHidden(r.barTrack, circle)
    r.circle:SetAnchorFill(r.root)
    r.fill:ClearAnchors()
    r.fill:SetAnchor(TOPLEFT, r.root, TOPLEFT, 0, 0)
    r.fill:SetHeight(height)
    r.lightEdge:SetHeight(height)
    r.dragSurface:ClearAnchors()
    r.dragSurface:SetAnchor(CENTER, r.root, CENTER, 0, 9)
    r.dragSurface:SetDimensions(math.max(96, width + 16), math.max(44, height + 32))
    -- The edit-only label can have a backdrop; the actual marker remains an
    -- honest opacity preview even while its larger drag hit area is enabled.
    r.moveTint:SetAnchorFill(r.moveLabel)
    r.style, r.size, r.offset = saved.reticleStyle, size, saved.reticleOffsetY
    r.offsetX, r.barHeight = saved.reticleOffsetX, saved.reticleBarHeight
    r.width, r.height = width, height
    return true
end

local function Visible()
    if A.IsReticleMoving() or A.reticlePreview then return true end
    if A.demo then return false end -- list preview has its own independent switch
    if not A.inCombat then return false end
    if not EligibleTarget() or IsReticleHidden() then return false end
    if A.saved.reticleBossOnly and (not A.reticleBossTarget or not A.BossVisible(A.reticleBossTarget)) then return false end
    if RETICLE then
        if RETICLE.control and RETICLE.control:IsHidden() then return false end
    end
    -- A nearby loot/interaction prompt can coexist with an attackable aimed
    -- enemy. It says nothing about that unit's taunt and must not hide/reset
    -- this countdown. Eligibility, native hides and scene gates remain above/below.
    if SCENE_MANAGER and not (SCENE_MANAGER:IsShowing("hud") or SCENE_MANAGER:IsShowing("hudui")) then return false end
    return true
end

local function UpdatePreviewCrosshair(r, show)
    local guide = r.previewCrosshair
    if not show then
        if guide then SetHidden(guide.root, true) end
        return
    end
    if not guide then
        local root = A.WM:CreateTopLevelWindow("ArclightTauntPreviewCrosshair")
        root:SetDrawTier(DT_HIGH)
        root:SetMouseEnabled(false)
        local texture = A.Solid(root, {1, 1, 1, 1})
        texture:SetTexture("EsoUI/Art/Reticle/reticleAnim.dds")
        texture:SetAnchorFill(root)
        texture:SetDrawLayer(DL_OVERLAY)
        texture:SetMouseEnabled(false)
        guide = {root = root, texture = texture}
        r.previewCrosshair = guide
    end
    -- Separate top-level window: follows the native glyph's geometry, but
    -- never inherits its menu visibility or our indicator's drag/size.
    local native = RETICLE and RETICLE.reticleTexture
    if not guide.anchored or guide.reference ~= native then
        guide.root:ClearAnchors()
        if native then guide.root:SetAnchorFill(native)
        else
            guide.root:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
            guide.root:SetDimensions(64, 64)
        end
        guide.reference, guide.anchored = native, true
    end
    local shape = A.reticlePreviewCrosshair or "large"
    if guide.shape ~= shape then
        -- Native visual check: frame 0 is large; frame 15 is small.
        local first = shape == "small" and 15 / 16 or 0
        guide.texture:SetTextureCoords(first, first + 1 / 16, 0, 1)
        guide.shape = shape
    end
    SetHidden(guide.root, false)
end

function A.UpdateReticleIndicator(now)
    local r = A.reticleIndicator
    if A.saved.reticleStyle == "off" or not Visible() then
        if r then
            A.SetReticleMoving(false); Stop(r); SetHidden(r.root, true)
            UpdatePreviewCrosshair(r, false)
        end
        if A.saved.reticleStyle == "off" then
            A.reticleTaunt, A.reticleObservation, A.reticleBossTarget = nil, nil, nil
            A.reticlePreview, A.reticlePreviewAt = nil, nil
            A.reticleMoving, A.reticleMoveAt = nil, nil
        end
        return
    end
    r = r or Create()
    UpdatePreviewCrosshair(r, A.reticlePreview == true or A.IsReticleMoving())
    Layout(r)
    if r.style == "circle" and r.ringWeight ~= A.saved.reticleRingWeight then
        local weight = A.saved.reticleRingWeight
        local suffix = weight == 5 and "" or string.format("%02d", weight * 2)
        r.ringTrack:SetTexture("ArclightTaunt/Textures/ArclightReticleRing" .. suffix .. ".dds")
        r.ringOutline:SetTexture("ArclightTaunt/Textures/ArclightReticleOutline" .. suffix .. ".dds")
        r.circle:SetTexture("ArclightTaunt/Textures/ArclightReticleRing" .. suffix .. ".dds")
        r.ringWeight = weight
    end
    if r.trackOpacity ~= A.saved.reticleTrackOpacity then
        local alpha = A.saved.reticleTrackOpacity / 100
        r.barTrack:SetGradientColors(ORIENTATION_VERTICAL, 0.28, 0.30, 0.32, alpha,
            0.14, 0.16, 0.18, alpha)
        r.ringTrack:SetColor(0.53, 0.58, 0.61, alpha)
        r.trackOpacity = A.saved.reticleTrackOpacity
    end
    A.SetReticleMoving(A.IsReticleMoving())
    local target = A.reticleTaunt
    local moving = A.IsReticleMoving()
    local preview = A.reticlePreview == true
    if preview or moving then
        -- One reusable sample, never inserted into real/demo lists. Explicit
        -- preview runs on its own clock, even while list preview is paused.
        local duration = math.max(15, A.saved.warningAt + 2)
        local startTime, endTime
        if preview then
            local anchor = A.reticlePreviewAt
            local period = duration + 0.6 -- briefly show the empty indicator
            local cycle = math.floor(math.max(0, now - anchor) / period)
            startTime = anchor + cycle * period
            endTime = startTime + duration
        else
            -- Placement alone keeps its stable handle without an idle timer.
            now = A.reticleMoveAt or A.DemoNow(now)
            endTime = now + A.saved.warningAt + 1
            startTime = endTime - duration
        end
        r.previewTarget = r.previewTarget or {}
        target = r.previewTarget
        target.startTime, target.endTime = startTime, endTime
    end
    SetHidden(r.root, false)
    if not target or target.dead or target.expiredAt or target.endTime <= now then Stop(r); return end
    local remaining = target.endTime - now
    local duration = math.max(0.001, target.endTime - target.startTime)
    local color = remaining <= A.saved.dangerAt and C.danger or (remaining <= A.saved.warningAt and C.warning or C.safe)
    if r.color ~= color then
        r.circle:SetFillColor(color[1], color[2], color[3], 1)
        -- Quiet depth across the existing fill, rather than a glow/wash over
        -- the aim point. The top retains the exact shared urgency color.
        r.fill:SetGradientColors(ORIENTATION_VERTICAL, color[1], color[2], color[3], 1,
            color[1] * 0.78, color[2] * 0.78, color[3] * 0.78, 1)
        r.color = color
    end
    local paused = moving and not preview
    if r.running and r.target == target and r.startTime == target.startTime and r.endTime == target.endTime
        and r.paused == paused then return end
    Stop(r)
    r.target, r.startTime, r.endTime, r.paused = target, target.startTime, target.endTime, paused
    r.running = true
    local fraction = A.Clamp(remaining / duration, 0, 1)
    if r.style == "circle" then
        SetHidden(r.circle, false)
        if paused then
            -- TIME_UNTIL reveals the complement of completion. Freeze the
            -- same remaining arc as the live native effect countdown.
            r.circle:StartFixedCooldown(1 - fraction, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_UNTIL, false)
        else
            r.circle:StartCooldown(math.max(1, math.ceil(remaining * 1000)), math.max(1, math.ceil(duration * 1000)),
                CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_UNTIL, false)
        end
    else
        r.fill:SetWidth(r.width * fraction)
        SetHidden(r.fill, false)
        if not paused then
            if not r.timeline then
                r.timeline = ANIMATION_MANAGER:CreateTimeline()
                r.animation = r.timeline:InsertAnimation(ANIMATION_SIZE, r.fill, 0)
                r.animation:SetEasingFunction(LinearEase)
                r.timeline:SetHandler("OnStop", function(_, completed)
                    local target = r.target
                    if completed and r.running and r.style == "bar" and not r.paused and target
                        and target.startTime == r.startTime and target.endTime == r.endTime
                        and A.Now() >= r.endTime then
                        r.running = false
                        SetHidden(r.fill, true)
                    end
                end)
            end
            r.animation:SetDuration(math.max(1, math.ceil(remaining * 1000)))
            r.animation:SetStartAndEndWidth(r.width * fraction, 0)
            r.animation:SetStartAndEndHeight(r.height, r.height)
            r.timeline:PlayFromStart()
        end
    end
end
