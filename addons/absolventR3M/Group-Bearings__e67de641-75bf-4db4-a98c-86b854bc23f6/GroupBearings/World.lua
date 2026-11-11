-- Group Bearings: arrows at your feet, and light beams over marked symbols,
-- the crown and (optionally) group members without a symbol.
--
-- Arrows and their distance tags are world-space controls (SetSpace(SPACE_WORLD)),
-- the same technique Tales of Tribute and Artaeum Group Tool's crown arrow use.
-- Beams are 3D render-space textures with the depth buffer on, so hills and
-- walls hide the bottom of a beam while the top still shows over them.

local GB = GroupBearings
local Core = GB.Core
local World = {}
GB.World = World

local UNITS_PER_METRE = 200        -- world-space controls: 200 UI units = 1 metre
local HALF_PI = math.pi / 2
local ARROW_RING_CM = 110          -- arrow centre distance from your feet at 100% size
local ARROW_HEIGHT_CM = 12
local TAG_HEIGHT_CM = 45
local NEAR_HIDE_M = 2              -- pointers fade out as you reach the symbol
local NEAR_FULL_M = 6
local BEAM_HEIGHT_M = 80
local BEAM_MIN_WIDTH_M = 0.9
local BEAM_WIDTH_PER_M = 0.008     -- far beams widen so they stay a few pixels wide

local floor, sqrt, max = math.floor, math.sqrt, math.max

local window, fragment
local pointers, beams = {}, {}
local pointersShown, beamsShown = 0, 0
local scaleFactor = 1

---------------------------------------------------------------------------
-- Creation
---------------------------------------------------------------------------
local function NewWorldControl(sizeUnits)
    local c = WINDOW_MANAGER:CreateControl(nil, window, CT_CONTROL)
    c:SetSpace(SPACE_WORLD)
    c:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    c:SetDimensions(sizeUnits, sizeUnits)
    c:SetScale(scaleFactor / UNITS_PER_METRE)
    c:SetTransformNormalizedOriginPoint(0.5, 0.5)
    c:SetMouseEnabled(false)
    c:SetHidden(true)
    return c
end

local function CreatePointer()
    local p = {}
    p.arrow = NewWorldControl(UNITS_PER_METRE)
    p.chevron = WINDOW_MANAGER:CreateControl(nil, p.arrow, CT_TEXTURE)
    p.chevron:SetAnchorFill(p.arrow)
    GB.UseTexture(p.chevron, "chevron")

    p.tag = NewWorldControl(UNITS_PER_METRE)
    p.icon = WINDOW_MANAGER:CreateControl(nil, p.tag, CT_TEXTURE)
    p.icon:SetDimensions(64, 64)
    p.icon:SetAnchor(BOTTOM, p.tag, CENTER, 0, -2)
    p.label = WINDOW_MANAGER:CreateControl(nil, p.tag, CT_LABEL)
    p.label:SetFont("ZoFontGamepadBold54")
    p.label:SetColor(1, 1, 1, 1)
    p.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    p.label:SetAnchor(TOP, p.tag, CENTER, 0, 2)
    p.shown = false
    return p
end

local function CreateBeam()
    local tex = WINDOW_MANAGER:CreateControl(nil, window, CT_TEXTURE)
    tex:Create3DRenderSpace()
    tex:Set3DRenderSpaceUsesDepthBuffer(not GB.sv.beamThroughWalls)
    tex:Set3DRenderSpaceOrigin(0, 0, 0)
    tex:SetDrawLevel(1)
    tex:SetMouseEnabled(false)
    tex:SetHidden(true)
    GB.UseTexture(tex, "beam")
    return { tex = tex, shown = false }
end

---------------------------------------------------------------------------
-- Show / hide helpers
---------------------------------------------------------------------------
local function ShowPointer(p, show)
    if p.shown ~= show then
        p.arrow:SetHidden(not show or not p.arrowWanted)
        p.tag:SetHidden(not show)
        p.shown = show
    end
end

local function ShowBeam(b, show)
    if b.shown ~= show then
        b.tex:SetHidden(not show)
        b.shown = show
    end
end

---------------------------------------------------------------------------
-- Per frame
---------------------------------------------------------------------------
local function PlacePointer(p, target, slot, px, py, pz, pitch, yaw, showArrow)
    local dx, dz = target.x - px, target.z - pz
    local horizontal = sqrt(dx * dx + dz * dz)
    local alpha = Core.Ramp(target.dist, NEAR_HIDE_M, NEAR_FULL_M)
    if horizontal < 1 or alpha <= 0 then
        ShowPointer(p, false)
        return
    end
    local ux, uz = dx / horizontal, dz / horizontal
    local ring = ARROW_RING_CM * (0.7 + 0.3 * scaleFactor)

    if p.arrowWanted ~= showArrow then
        p.arrowWanted = showArrow
        p.arrow:SetHidden(not (showArrow and p.shown))
    end
    if showArrow then
        local rx, ry, rz = WorldPositionToGuiRender3DPosition(
            floor(px + ux * ring), floor(py + ARROW_HEIGHT_CM + slot * 2), floor(pz + uz * ring))
        p.arrow:SetTransformOffset(rx, ry, rz)
        p.arrow:SetTransformRotation(-HALF_PI, Core.GroundYaw(px, pz, target.x, target.z), 0)
        p.arrow:SetAlpha(alpha)
    end

    local tagRing = ring + 75 * scaleFactor
    local rx, ry, rz = WorldPositionToGuiRender3DPosition(
        floor(px + ux * tagRing), floor(py + TAG_HEIGHT_CM * scaleFactor + slot * 2), floor(pz + uz * tagRing))
    p.tag:SetTransformOffset(rx, ry, rz)
    p.tag:SetTransformRotation(pitch, yaw, 0)
    p.tag:SetAlpha(alpha)

    local symbolKey = target.markerType or "crown"
    if p.symbolKey ~= symbolKey then
        p.symbolKey = symbolKey
        p.icon:SetTexture(GB.GetSymbolIcon(target.markerType))
        local c = GB.GetSymbolColor(target.markerType)
        p.chevron:SetColor(c[1], c[2], c[3], 1)
    end
    -- The crown's arrow draws over any other arrow it touches.
    local level = target.isCrown and 2 or 1
    if p.level ~= level then
        p.level = level
        p.arrow:SetDrawLevel(level)
        p.tag:SetDrawLevel(level)
    end
    if p.text ~= target.text then
        p.label:SetText(target.text)
        p.text = target.text
    end
    ShowPointer(p, true)
end

local function PlaceBeam(b, target, heading, alpha)
    local width = max(BEAM_MIN_WIDTH_M, target.dist * BEAM_WIDTH_PER_M)
    if GB.TEXTURES.beam.useFallback then width = width * 0.45 end -- plain quad: keep it slim
    width = floor(width * 10 + 0.5) / 10
    if b.width ~= width then
        b.tex:Set3DLocalDimensions(width, BEAM_HEIGHT_M)
        b.width = width
    end
    local rx, ry, rz = WorldPositionToGuiRender3DPosition(target.x, target.y, target.z)
    b.tex:Set3DRenderSpaceOrigin(rx, ry + BEAM_HEIGHT_M / 2, rz)
    b.tex:Set3DRenderSpaceOrientation(0, heading, 0)

    local c = target.beamColor
    if b.color ~= c or b.alpha ~= alpha then
        b.color, b.alpha = c, alpha
        local tex = b.tex
        tex:SetColor(c[1], c[2], c[3], alpha)
        -- Fade out toward the top of the beam.
        tex:SetVertexColors(VERTEX_POINTS_BOTTOMLEFT, c[1], c[2], c[3], alpha)
        tex:SetVertexColors(VERTEX_POINTS_BOTTOMRIGHT, c[1], c[2], c[3], alpha)
        tex:SetVertexColors(VERTEX_POINTS_TOPLEFT, c[1], c[2], c[3], 0)
        tex:SetVertexColors(VERTEX_POINTS_TOPRIGHT, c[1], c[2], c[3], 0)
    end
    ShowBeam(b, true)
end

local function CameraFacing(heading)
    if GetCameraForward and SPACE_WORLD then
        local fx, fy, fz = GetCameraForward(SPACE_WORLD)
        if fx and (fx ~= 0 or fz ~= 0) then
            return Core.BillboardRotation(fx, fy, fz)
        end
    end
    return 0, heading
end

function World.Render(targets, count, px, py, pz, heading)
    if not window then return end
    local sv = GB.sv
    -- Symbols use "Symbols at your feet"; the crown has its own switches, so its
    -- beam and arrow work on their own (like Artaeum Group Tool's crown module).
    local symbolPointers, symbolBeams = sv.pointers, sv.pointers and sv.beam
    local crownTracked = GB.IsCrownTracked()
    local crownArrow, crownBeam = crownTracked and sv.crownArrow, crownTracked and sv.crownBeam
    local memberBeams = sv.memberBeams == true

    local usedPointers, usedBeams = 0, 0
    if count > 0 and (symbolPointers or symbolBeams or crownArrow or crownBeam or memberBeams) then
        local pitch, yaw = CameraFacing(heading)
        local beamAlpha = 1 - (sv.beamTransparency or 50) / 100
        for i = 1, count do
            local target = targets[i]
            target.bearing = Core.GroundYaw(px, pz, target.x, target.z)
            local asSymbol = target.marked == true
            local asCrown = target.isCrown == true
            target.wantPointer = (asSymbol and symbolPointers) or (asCrown and crownArrow) or false
            -- One beam per target: a symbol's colour, else the crown's, else the member's.
            local crownBeamHere = asCrown and crownBeam
            target.wantBeam = (asSymbol and symbolBeams) or crownBeamHere
                or (target.memberBeam == true and memberBeams) or false
            if asSymbol then
                target.beamColor = GB.GetSymbolColor(target.markerType)
            elseif crownBeamHere then
                target.beamColor = GB.GetCrownBeamColor()
            else
                target.beamColor = GB.GetMemberBeamColor(target.role)
            end
            -- The ground chevron itself: always for the crown, per setting for symbols.
            target.wantChevron = (asCrown and crownArrow) or (asSymbol and symbolPointers and sv.pointerArrows) or false
        end
        -- Arrows that would overlap: the closest target (or the crown, with
        -- "crown always on top") gets the spot, the others step aside.
        Core.LayoutPointers(targets, count, math.rad(sv.pointerSpacing or 0), sv.crownOnTop == true)
        for i = 1, count do
            local target = targets[i]
            -- A stale position (marked NPC no longer under the crosshair) keeps
            -- only its beam: an arrow pointing at an old spot would mislead.
            if target.pointerShown then
                usedPointers = usedPointers + 1
                local p = pointers[usedPointers]
                if not p then
                    p = CreatePointer()
                    pointers[usedPointers] = p
                end
                PlacePointer(p, target, usedPointers, px, py, pz, pitch, yaw, target.wantChevron)
            end
            local strength = target.beamFactor or 1
            if target.wantBeam and beamAlpha > 0 and strength > 0
                and Core.BeamVisible(target.dist, sv.beamMinDistance, sv.beamMaxDistance) then
                usedBeams = usedBeams + 1
                local b = beams[usedBeams]
                if not b then
                    b = CreateBeam()
                    beams[usedBeams] = b
                end
                PlaceBeam(b, target, heading, beamAlpha * strength)
            end
        end
    end
    for i = usedPointers + 1, pointersShown do ShowPointer(pointers[i], false) end
    for i = usedBeams + 1, beamsShown do ShowBeam(beams[i], false) end
    pointersShown, beamsShown = usedPointers, usedBeams
end

---------------------------------------------------------------------------
-- Public
---------------------------------------------------------------------------
function World.Initialize()
    if not (WINDOW_MANAGER and WINDOW_MANAGER.CreateTopLevelWindow) then
        error("window manager missing")
    end
    local win = WINDOW_MANAGER:CreateTopLevelWindow("GroupBearingsWorld")
    for _, method in ipairs({ "SetSpace", "SetTransformOffset", "SetTransformRotation", "Create3DRenderSpace", "Set3DRenderSpaceOrigin" }) do
        if not win[method] then
            win:SetHidden(true)
            error("this game version has no " .. method .. ", so arrows and beams are off")
        end
    end
    window = win
    window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
    window:SetDimensions(1, 1)
    window:SetMouseEnabled(false)
    window:SetDrawTier(DT_LOW)
    window:SetDrawLayer(DL_BACKGROUND)
    -- Only on the HUD: hidden in menus, the map, dialogue and so on.
    if ZO_HUDFadeSceneFragment and HUD_SCENE then
        fragment = ZO_HUDFadeSceneFragment:New(window)
        HUD_SCENE:AddFragment(fragment)
        if HUD_UI_SCENE then HUD_UI_SCENE:AddFragment(fragment) end
    end
    World.window = window
end

function World.IsReady()
    return window ~= nil
end

function World.ApplySettings()
    if not window then return end
    local newScale = (GB.sv.pointerSize or 100) / 100
    if newScale ~= scaleFactor then
        scaleFactor = newScale
        for _, p in ipairs(pointers) do
            p.arrow:SetScale(scaleFactor / UNITS_PER_METRE)
            p.tag:SetScale(scaleFactor / UNITS_PER_METRE)
        end
    end
    local depth = not GB.sv.beamThroughWalls
    for _, b in ipairs(beams) do
        b.alpha, b.color = nil, nil -- recolour on the next frame (a colour setting may have changed)
        b.tex:Set3DRenderSpaceUsesDepthBuffer(depth)
    end
    for _, p in ipairs(pointers) do p.symbolKey = nil end
end

function World.HideAll()
    for _, p in ipairs(pointers) do
        p.arrow:SetHidden(true)
        p.tag:SetHidden(true)
        p.shown = false
    end
    for _, b in ipairs(beams) do ShowBeam(b, false) end
    pointersShown, beamsShown = 0, 0
end
