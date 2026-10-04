-- SnipersFriendAimLineActions.lua: Depth-tested aim line capped at the ability's horizontal range.
--
-- The aim point is where the camera ray reaches HORIZONTAL distance = the ground
-- ability's range from the player (GetAbilityRange for the player, so passives and
-- keep / siege-shield buffs are included). Every point on the camera ray projects
-- onto the reticle, so a strip along the ray is invisible (0.5.0 bug: a sliver at
-- screen centre). Instead the strip runs from the CHARACTER to the aim point, like a
-- tracer converging on the dot. With the depth buffer on, world geometry occludes the
-- strip, and the end-cap at the range point vanishes inside walls. Lua cannot read
-- any of that back - it is a purely visual aid.
--
-- Camera origin: Set3DRenderSpaceToCurrentCamera on a hidden probe; forward:
-- GetCameraForward(SPACE_WORLD) (as More Markers / CrutchAlerts do). Render space is
-- metres, Y up. Quad orientation uses CrutchAlerts' production-verified Euler
-- convention (strip lies along the segment, face horizontal) by default; "basis"
-- mode (explicit right/up/forward, camera-facing) is the alternative. Depth-buffered
-- alpha textures clip oddly (Crutch's note), so draw levels are also sorted by
-- distance to the camera.
--
-- Ground marker: where the camera ray meets the player's floor plane (More Markers'
-- cursor-placement math) - correct on flat ground, meaningless on slopes/platforms.
--
-- Distance icons (0.8.0): camera-facing billboards of fixed world size at fixed
-- HORIZONTAL distances from the player. Unlike the strip (a flat quad whose length
-- changes with pitch, so its texture visibly stretches), a billboard never stretches.
-- Path "line": along the character -> aim-point segment (spread out on screen).
-- Path "ray": on the camera ray itself - every icon projects to the crosshair, so
-- they stack concentrically (nearer = bigger) and the depth test removes every icon
-- beyond the first wall: a pure occlusion range finder.

local SnipersFriend = SnipersFriend
local Utils = SnipersFriend.AimLineUtils
local CU = SnipersFriend.CameraUtils

local AimLineActions = {}

local TOPLEVEL_NAME = "SnipersFriendAimLineTL"
local PROBE_NAME = "SnipersFriendCameraProbe"
local LINE_NAME = "SnipersFriendAimLine"
local CAP_NAME = "SnipersFriendAimLineCap"
local TICK_NAME = "SnipersFriendAimTick"
local GROUND_NAME = "SnipersFriendAimGround"
local GROUND_TEXTURE = "SnipersFriend/textures/ring.dds"
local GROUND_MIN_PITCH = math.rad(2)
local SOLID_TEXTURE = "SnipersFriend/textures/solid.dds"
local CAP_TEXTURE = "SnipersFriend/textures/ring_dot.dds"
local MAX_TICKS = 64
local ICON_TEXTURE = "SnipersFriend/textures/icon_ring.dds"
local ICON_MAJOR_TEXTURE = "SnipersFriend/textures/icon_ring_dot.dds"
local ICON_REF_DIST_M = 10 -- constant-screen-size mode: iconSizeM is the size at this distance
local MAX_RAY_M = 120
local START_HEIGHT_M = 1.1 -- start the strip at roughly chest height, not the feet
local START_SKIP_M = 0.8   -- skip the first bit so it doesn't clip the character model

---@return SnipersFriendAimLineSettings
local function Settings() return SnipersFriend.state.savedVars.aimLine end
---@return SnipersFriendState
local function State() return SnipersFriend.state end
local function Debug(fmt, ...) SnipersFriend.SlashUtils.Debug(fmt, ...) end

-- ---------------------------------------------------------------- controls

local function EnsureControls()
    local state = State()
    if state.aimLine then return true end
    local tl = _G[TOPLEVEL_NAME] or WINDOW_MANAGER:CreateTopLevelWindow(TOPLEVEL_NAME)
    tl:SetDrawLayer(DL_BACKGROUND)
    local probe = _G[PROBE_NAME] or WINDOW_MANAGER:CreateControl(PROBE_NAME, tl, CT_CONTROL)
    if not probe:Has3DRenderSpace() then probe:Create3DRenderSpace() end

    local line = _G[LINE_NAME] or WINDOW_MANAGER:CreateControl(LINE_NAME, tl, CT_TEXTURE)
    if not line:Has3DRenderSpace() then line:Create3DRenderSpace() end
    line:SetTexture(SOLID_TEXTURE)
    line:SetHidden(true)

    state.aimTicks = {}
    for i = 1, MAX_TICKS do
        local name = TICK_NAME .. i
        local tick = _G[name] or WINDOW_MANAGER:CreateControl(name, tl, CT_TEXTURE)
        if not tick:Has3DRenderSpace() then tick:Create3DRenderSpace() end
        tick:SetTexture(ICON_TEXTURE)
        tick:SetHidden(true)
        state.aimTicks[i] = tick
    end

    local cap = _G[CAP_NAME] or WINDOW_MANAGER:CreateControl(CAP_NAME, tl, CT_TEXTURE)
    if not cap:Has3DRenderSpace() then cap:Create3DRenderSpace() end
    cap:SetTexture(CAP_TEXTURE)
    cap:SetHidden(true)

    local ground = _G[GROUND_NAME] or WINDOW_MANAGER:CreateControl(GROUND_NAME, tl, CT_TEXTURE)
    if not ground:Has3DRenderSpace() then ground:Create3DRenderSpace() end
    ground:SetTexture(GROUND_TEXTURE)
    ground:SetHidden(true)
    ground:Set3DRenderSpaceOrientation(ZO_HALF_PI, 0, 0) -- flat on the floor

    state.aimLineTL, state.cameraProbe, state.aimLine, state.aimLineCap, state.aimGround = tl, probe, line, cap, ground
    return true
end

local function ApplyStyle()
    local state = State()
    local s = Settings()
    local line, cap = state.aimLine, state.aimLineCap
    if not line then return end
    line:Set3DRenderSpaceUsesDepthBuffer(s.depthTest)
    cap:Set3DRenderSpaceUsesDepthBuffer(s.depthTest)
    line:SetColor(s.lineColor.r, s.lineColor.g, s.lineColor.b, s.lineColor.a)
    cap:SetColor(s.capColor.r, s.capColor.g, s.capColor.b, s.capColor.a)
    cap:Set3DLocalDimensions(s.capSizeM, s.capSizeM)
    for _, tick in ipairs(state.aimTicks or {}) do
        tick:Set3DRenderSpaceUsesDepthBuffer(s.depthTest)
        tick:SetColor(s.tickColor.r, s.tickColor.g, s.tickColor.b, s.tickColor.a)
    end
    if state.aimGround then
        state.aimGround:Set3DRenderSpaceUsesDepthBuffer(s.depthTest)
        state.aimGround:SetColor(s.groundColor.r, s.groundColor.g, s.groundColor.b, s.groundColor.a)
        state.aimGround:Set3DLocalDimensions(s.groundSizeM, s.groundSizeM)
    end
end

-- ---------------------------------------------------------------- camera

---@return number|nil camX, number camY, number camZ, number fwdX, number fwdY, number fwdZ
local function ReadCamera()
    local probe = State().cameraProbe
    if not probe then return nil end
    Set3DRenderSpaceToCurrentCamera(PROBE_NAME)
    local cx, cy, cz = probe:Get3DRenderSpaceOrigin()
    local fx, fy, fz
    if CU.IsCallable("GetCameraForward") and SPACE_WORLD then
        fx, fy, fz = GetCameraForward(SPACE_WORLD)
    else
        fx, fy, fz = probe:Get3DRenderSpaceForward()
    end
    return cx, cy, cz, fx, fy, fz
end

---Nearer things get a higher draw level so overlapping quads sort sensibly.
---@param control any
---@param x number
---@param y number
---@param z number
---@param cx number
---@param cy number
---@param cz number
local function SortByDistance(control, x, y, z, cx, cy, cz)
    local d2 = (x - cx) ^ 2 + (y - cy) ^ 2 + (z - cz) ^ 2
    control:SetDrawLevel(-math.floor(d2))
end

---@return number|nil px, number py, number pz (render space)
local function ReadPlayer()
    local _, wx, wy, wz = GetUnitRawWorldPosition("player")
    if not wx then return nil end
    return WorldPositionToGuiRender3DPosition(wx, wy, wz)
end

-- ---------------------------------------------------------------- range source

---@return number|nil rangeM, string|nil label
local function CurrentRange()
    local s = Settings()
    if s.rangeOverrideM and s.rangeOverrideM > 0 then return s.rangeOverrideM, "custom" end
    local GT = SnipersFriend.GroundTargetActions
    local ability = GT and GT.CurrentAbility and GT.CurrentAbility() or nil
    if ability and ability.maxRangeM then return ability.maxRangeM, ability.name end
    if s.showWithoutGroundAbility then return s.fallbackRangeM, "default" end
    return nil, nil
end

-- ---------------------------------------------------------------- per frame

local function HideTicks(fromIndex)
    local state = State()
    for i = fromIndex or 1, #(state.aimTicks or {}) do
        state.aimTicks[i]:SetHidden(true)
    end
end

local function Hide()
    local state = State()
    if state.aimLine then state.aimLine:SetHidden(true) end
    if state.aimLineCap then state.aimLineCap:SetHidden(true) end
    if state.aimGround then state.aimGround:SetHidden(true) end
    HideTicks(1)
    state.aimLineVisible = false
end

---Turn a quad into a camera-facing billboard (More Markers' pitch/yaw from the camera
---forward in euler mode; explicit basis otherwise).
---@param control any
---@param x number quad position
---@param y number
---@param z number
---@param cx number camera
---@param cy number
---@param cz number
---@param fx number camera forward
---@param fy number
---@param fz number
local function FaceCamera(control, x, y, z, cx, cy, cz, fx, fy, fz)
    if Settings().orientMode == "euler" then
        local pitch = math.atan2(fy, math.sqrt(fx * fx + fz * fz))
        local yaw = math.atan2(fx, fz) - math.pi
        control:Set3DRenderSpaceOrientation(pitch, yaw, 0)
    else
        local rx, ry, rz, ux, uy, uz, nx, ny, nz = Utils.BillboardBasis(cx - x, cy - y, cz - z)
        control:Set3DRenderSpaceRight(rx, ry, rz)
        control:Set3DRenderSpaceUp(ux, uy, uz)
        control:Set3DRenderSpaceForward(nx, ny, nz)
    end
end

---Billboard icons at fixed HORIZONTAL distances from the player (every tickIntervalM,
---up to the range). Path "line": the strip starts at the player's xz, so horizontal
---distance grows linearly along it - distance d sits at fraction d / range. Path
---"ray": the point on the camera ray whose horizontal distance from the player is d.
---Icons never stretch: they always face the camera and have a fixed world size (or a
---size proportional to distance, which reads as a constant on-screen size).
---@param ox number segment origin (player, chest height)
---@param oy number
---@param oz number
---@param dx number unit direction
---@param dy number
---@param dz number
---@param segLen number full segment length (player -> aim point)
---@param rangeM number horizontal range at the aim point
---@param cx number camera
---@param cy number
---@param cz number
---@param fx number camera forward
---@param fy number
---@param fz number
---@param px number player
---@param pz number
---@return integer shown
local function PlaceIcons(ox, oy, oz, dx, dy, dz, segLen, rangeM, cx, cy, cz, fx, fy, fz, px, pz)
    local state, s = State(), Settings()
    if not s.showTicks or s.tickIntervalM <= 0 then
        HideTicks(1)
        return 0
    end
    local shown = 0
    local d = s.tickIntervalM
    local n = 0
    while d < rangeM - 0.01 and shown < #state.aimTicks do
        n = n + 1
        local tx, ty, tz
        if s.iconPath == "ray" then
            tx, ty, tz = Utils.RangeEndPoint(cx, cy, cz, fx, fy, fz, px, pz, d, MAX_RAY_M)
        else
            local u = d / rangeM
            tx, ty, tz = ox + dx * segLen * u, oy + dy * segLen * u, oz + dz * segLen * u
        end
        local icon = state.aimTicks[shown + 1]
        local major = s.majorTickEvery > 0 and (n % s.majorTickEvery == 0)
        local size = s.iconSizeM
        if s.iconConstantScreenSize then
            local dist = math.sqrt((tx - cx) ^ 2 + (ty - cy) ^ 2 + (tz - cz) ^ 2)
            size = size * dist / ICON_REF_DIST_M
        end
        if major then size = size * 1.4 end
        if icon.sfMajor ~= major then
            icon:SetTexture(major and ICON_MAJOR_TEXTURE or ICON_TEXTURE)
            icon.sfMajor = major
        end
        icon:Set3DRenderSpaceOrigin(tx, ty, tz)
        icon:Set3DLocalDimensions(size, size)
        FaceCamera(icon, tx, ty, tz, cx, cy, cz, fx, fy, fz)
        SortByDistance(icon, tx, ty, tz, cx, cy, cz)
        icon:SetHidden(false)
        shown = shown + 1
        d = d + s.tickIntervalM
    end
    HideTicks(shown + 1)
    return shown
end

function AimLineActions.OnUpdate()
    local state = State()
    local s = Settings()
    if not (s.enabled and state.aimLineReady) then
        if state.aimLineVisible then Hide() end
        return
    end
    if IsReticleHidden() or (IsGameCameraUIModeActive and IsGameCameraUIModeActive()) then
        if state.aimLineVisible then Hide() end
        return
    end
    local rangeM = CurrentRange()
    if not rangeM then
        if state.aimLineVisible then Hide() end
        return
    end

    local cx, cy, cz, fx, fy, fz = ReadCamera()
    local px, py, pz = ReadPlayer()
    if not (cx and px) then
        if state.aimLineVisible then Hide() end
        return
    end

    local ex, ey, ez = Utils.RangeEndPoint(cx, cy, cz, fx, fy, fz, px, pz, rangeM, MAX_RAY_M)

    -- segment: character (chest height) -> aim point
    local ox, oy, oz = px, py + START_HEIGHT_M, pz
    local dx, dy, dz = ex - ox, ey - oy, ez - oz
    local segLen = math.sqrt(dx * dx + dy * dy + dz * dz)
    if segLen <= START_SKIP_M + 0.05 then
        if state.aimLineVisible then Hide() end
        return
    end
    dx, dy, dz = dx / segLen, dy / segLen, dz / segLen
    local sx, sy, sz = ox + dx * START_SKIP_M, oy + dy * START_SKIP_M, oz + dz * START_SKIP_M
    local len = segLen - START_SKIP_M
    local mx, my, mz = (sx + ex) / 2, (sy + ey) / 2, (sz + ez) / 2

    local line, cap, ground = state.aimLine, state.aimLineCap, state.aimGround
    if s.showLine then
        line:Set3DRenderSpaceOrigin(mx, my, mz)
        line:Set3DLocalDimensions(s.lineWidthM, len)
        if s.orientMode == "euler" then
            local pitch, yaw = Utils.LineOrientation(sx, sy, sz, ex, ey, ez)
            line:Set3DRenderSpaceOrientation(pitch, yaw, 0)
        else
            local rx, ry, rz, ux, uy, uz, nx, ny, nz = Utils.StripBasis(dx, dy, dz, cx - mx, cy - my, cz - mz)
            line:Set3DRenderSpaceRight(rx, ry, rz)
            line:Set3DRenderSpaceUp(ux, uy, uz)
            line:Set3DRenderSpaceForward(nx, ny, nz)
        end
        SortByDistance(line, mx, my, mz, cx, cy, cz)
    end
    line:SetHidden(not s.showLine)
    state.aimTickCount = PlaceIcons(ox, oy, oz, dx, dy, dz, segLen, rangeM, cx, cy, cz, fx, fy, fz, px, pz)

    cap:Set3DRenderSpaceOrigin(ex, ey, ez)
    FaceCamera(cap, ex, ey, ez, cx, cy, cz, fx, fy, fz)
    SortByDistance(cap, ex, ey, ez, cx, cy, cz)
    cap:SetHidden(not s.showCap)

    -- ground marker where the view ray meets the player's floor plane (flat ground only)
    if s.showGround then
        local gx, gy, gz = Utils.GroundPoint(cx, cy, cz, fx, fy, fz, py, GROUND_MIN_PITCH)
        if gx then
            local gdx, gdz = gx - px, gz - pz
            local horiz = math.sqrt(gdx * gdx + gdz * gdz)
            local inRange = horiz <= rangeM + 0.01
            local c = inRange and s.groundColor or s.groundFarColor
            ground:SetColor(c.r, c.g, c.b, c.a)
            ground:Set3DRenderSpaceOrigin(gx, gy + 0.05, gz)
            SortByDistance(ground, gx, gy, gz, cx, cy, cz)
            ground:SetHidden(false)
            state.aimGroundDistM = horiz
        else
            ground:SetHidden(true)
            state.aimGroundDistM = nil
        end
    else
        ground:SetHidden(true)
    end

    state.aimLineVisible = true
    state.aimLineRangeM = rangeM
    if s.debugDump then
        state.aimLineDebug = string.format("cam %.1f,%.1f,%.1f fwd %.2f,%.2f,%.2f | player %.1f,%.1f,%.1f | end %.1f,%.1f,%.1f | len %.1f",
            cx, cy, cz, fx, fy, fz, px, py, pz, ex, ey, ez, len)
    end
end

function AimLineActions.Refresh()
    ApplyStyle()
    if not Settings().enabled then Hide() end
end

---@return boolean
function AimLineActions.Initialize()
    local state = State()
    local needed = { "Set3DRenderSpaceToCurrentCamera", "GetUnitRawWorldPosition", "WorldPositionToGuiRender3DPosition", "IsReticleHidden" }
    for _, name in ipairs(needed) do
        if not CU.IsCallable(name) then
            Debug("aim line unavailable: %s not callable", name)
            state.aimLineReady = false
            return false
        end
    end
    EnsureControls()
    ApplyStyle()
    state.aimLineReady = true
    return true
end

---@return string[]
function AimLineActions.StatusLines()
    local state, s = State(), Settings()
    local rangeM, label = CurrentRange()
    local lines = {
        string.format("aim guide: %s (%s), range %s%s, depth test %s, orient %s",
            s.enabled and "on" or "off", state.aimLineReady and "ready" or "unavailable",
            rangeM and string.format("%.0f m", rangeM) or "none", label and (" from " .. label) or "",
            s.depthTest and "on" or "off", s.orientMode),
    }
    lines[#lines + 1] = string.format("  icons: %s every %.1f m on the %s (major every %d, %.2f m%s), %d shown",
        s.showTicks and "on" or "off", s.tickIntervalM, s.iconPath == "ray" and "camera ray" or "aim line",
        s.majorTickEvery, s.iconSizeM, s.iconConstantScreenSize and " at 10 m, constant on screen" or "", state.aimTickCount or 0)
    lines[#lines + 1] = string.format("  line strip: %s, width %.2f m", s.showLine and "on" or "off", s.lineWidthM)
    lines[#lines + 1] = string.format("  ground marker: %s%s", s.showGround and "on" or "off",
        state.aimGroundDistM and string.format(" (floor-plane hit at %.1f m horizontal)", state.aimGroundDistM) or "")
    if state.aimLineDebug then lines[#lines + 1] = state.aimLineDebug end
    return lines
end

SnipersFriend.AimLineActions = AimLineActions
