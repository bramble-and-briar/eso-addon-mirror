-- Questbound_Path.lua : the line on the ground toward the target, drawn in the
-- 3D world (textures with a 3D render space, placed with
-- WorldPositionToGuiRender3DPosition). It follows the streets Questbound learned
-- from walking (Questbound_Roads.lua), with their heights; where none are known
-- yet it's straight at your own height. Near the end it fades out, or, when the
-- objective is close, it ends in rippling rings on the spot.
--
-- Styles (sv.path.style): "solid" (filled chevrons like a navigation app, default
-- since 0.13.0: chev_solid.dds + soft chev_shadow.dds lying flat, each turned along
-- the way with Set3DRenderSpaceOrientation(-pi/2, yaw, 0) like LibCombatAlerts' ground
-- textures), "chevrons" (a V of five dot beads), "comet" (thin line with a bright
-- pulse running along it), "dots", "line".
-- With animations on, the line draws itself out when a new objective starts, the
-- last pieces melt away near the goal, and on arrival green rings ripple out there.

local W = Questbound
local Path = {}
W.Path = Path

local MAX_DOTS = 320
local START_M = 1.2        -- line starts this far in front of you
local FLOW_SPEED = 1.4     -- m/s the line flows toward the target
local DRAW_SPEED = 35      -- m/s the line grows when a new objective starts
local COMET_SPEED = 9      -- m/s of the comet pulse
local MELT_M = 3           -- the last pieces shrink and fade over this many meters before the goal
-- solid chevrons, "glass + spotlight" look (0.13.1): real gold (barely lightened) at
-- GLASS of the opacity setting, with a faint dark edge (chev_edge.dds); faint at your
-- feet, clearest SPOT_NEAR..SPOT_FAR m ahead, then fading out with distance
-- (0.13.2: toned down again: smaller, sparser, fainter, lighter edge)
-- (1.0.1: a tiny bit more visible again: 0.5 -> 0.6, edge 0.3 -> 0.35, feet / far 0.1 / 0.08 -> 0.15 / 0.12)
local GLASS = 0.6
local SOLID_LIGHTEN = 0.1
local EDGE_A = 0.35        -- dark edge strength (times the chevron's opacity)
local SPOT_NEAR, SPOT_FAR = 5, 14
local SPOT_FEET, SPOT_END = 0.15, 0.12
local ARRIVE_TIME = 1.8    -- seconds the arrival rings ripple out
Path.STYLES = { "solid", "chevrons", "comet", "dots", "line" }

local win, fragment
local dots = {}
local shadows = {}    -- dark soft spot under each bead
local SHADOW_A = 0.45 -- shadow strength (times the bead's own fade)
local LIGHTEN = 0.3   -- beads are this much lighter than the chosen color
local rings = {}
local used = 0
local groundY
local currentKey      -- style + width + image the textures were set up for
local lastDrawn = 0   -- pieces drawn last frame (/wf debug)
local lastRouted = false   -- last frame's line followed learned streets
local lastTy, lastReach    -- objective's floor height / height the walked way reaches (m, /wf debug)
local movedM = 0           -- meters moved along the way (keeps the beads on their spot)
local lastPX, lastPZ
local lastEnd              -- the way's end point last frame {x, y, z} m (arrival rings go there)
local arrivedAt            -- time you arrived (arrival rings)
local TrimBehind           -- (below)
local STAIRS_NEAR_M = 40   -- "find the way up": only for objectives this close
local supported = type(WorldPositionToGuiRender3DPosition) == "function"

-- Look of each style: texture, size (m), spacing (m).
local function StyleOf(sv)
    local w = sv.width
    -- solid: one chevron picture per piece (size = its width); until the game was
    -- restarted and the picture is loaded, the dotted chevrons stand in
    if sv.style == "solid" and W.TextureLoaded("chev_solid.dds") then
        return "chev_solid.dds", math.max(0.6, w * 3.5), math.max(2.2, w * 11)   -- 0.7 m wide, every 2.2 m
    end
    -- chevrons: size = width of the "V" (made of dot beads, placed in the world)
    if sv.style == "chevrons" or sv.style == "solid" then return "dot.dds", math.max(0.8, w * 5), math.max(1.3, w * 8) end
    if sv.style == "dots" then return "dot.dds", w * 2.5, math.max(1.2, w * 4) end
    return "dot.dds", w, w * 1.1   -- line and comet: dots close enough to look like a line
end

local function NewTex(file)
    local tex = WINDOW_MANAGER:CreateControl(nil, win, CT_TEXTURE)
    tex:SetTexture(W.TEX .. file)
    tex:Create3DRenderSpace()
    tex:Set3DRenderSpaceOrientation(math.pi / 2, 0, 0)   -- lying flat on the ground
    tex:SetHidden(true)
    return tex
end

-- under solid chevrons: the thin dark edge, or (before a game restart loads it) the old soft shadow
function Path.EdgeFile()
    return W.TextureLoaded("chev_edge.dds") and "chev_edge.dds" or "chev_shadow.dds"
end

-- solid chevrons: how clear a piece is at d meters along the way (spotlight)
local function Spot(d, length)
    if d < SPOT_NEAR then
        return SPOT_FEET + (1 - SPOT_FEET) * zo_clamp((d - START_M) / (SPOT_NEAR - START_M), 0, 1)
    end
    if d <= SPOT_FAR then return 1 end
    return math.max(SPOT_END, 1 - (1 - SPOT_END) * (d - SPOT_FAR) / math.max(1, length - SPOT_FAR))
end

function Path.Apply()
    if not win then return end
    local sv = W.sv.path
    local file, size = StyleOf(sv)
    currentKey = sv.style .. sv.width .. file
    local solid = file == "chev_solid.dds"
    for _, tex in ipairs(dots) do
        tex:SetTexture(W.TEX .. file)
        tex:Set3DLocalDimensions(size, size)
        tex:Set3DRenderSpaceUsesDepthBuffer(sv.depth)
        tex:SetTextureRotation(0)
        -- round beads lie flat as they are; chevrons get turned along the way each frame
        if not solid then tex:Set3DRenderSpaceOrientation(math.pi / 2, 0, 0) end
    end
    for _, sh in ipairs(shadows) do
        sh:SetTexture(W.TEX .. (solid and Path.EdgeFile() or "dot.dds"))
        sh:Set3DRenderSpaceUsesDepthBuffer(sv.depth)
        if not solid then sh:Set3DRenderSpaceOrientation(math.pi / 2, 0, 0) end
    end
    for _, ring in ipairs(rings) do ring:Set3DRenderSpaceUsesDepthBuffer(sv.depth) end
    W.ShowOnHud(fragment, sv.shown)
end

function Path.Init()
    if not supported then return end
    win = WINDOW_MANAGER:CreateTopLevelWindow("Questbound_Path")
    win:SetAnchorFill(GuiRoot)
    win:SetMouseEnabled(false)
    win:SetDrawLayer(DL_BACKGROUND)
    win:SetDrawTier(DT_LOW)
    win:SetDrawLevel(0)
    fragment = W.HudFragment(win)
    W.Path.win = win

    rings[1] = NewTex("ring.dds")
    rings[2] = NewTex("ring.dds")
    rings[3] = NewTex("ring.dds")   -- (the arrival burst uses three)
    W.callbacks:RegisterCallback("SettingsChanged", Path.Apply)
    Path.Apply()
end

local function HideFrom(n)
    for i = n, used do
        dots[i]:SetHidden(true)
        shadows[i]:SetHidden(true)
    end
    used = math.min(used, n - 1)
end

local function HideRings(from)
    for i = from or 1, #rings do rings[i]:SetHidden(true) end
end

local function HideAll()
    lastDrawn = 0
    HideFrom(1)
    HideRings()
end

-- Arrival: three green rings ripple out from the goal, one after another, then stop
-- (the line itself is gone once you're there). Returns false when nothing to show.
local function ArrivalRings(now)
    if not lastEnd or W.sv.anim == "off" or not W.sv.path.marker then return false end
    local a = now - arrivedAt
    if a > ARRIVE_TIME then return false end
    local done = W.COLOR.done
    local rx, ry, rz = WorldPositionToGuiRender3DPosition(lastEnd[1] * 100, lastEnd[2] * 100 + 6, lastEnd[3] * 100)
    for i, ring in ipairs(rings) do
        local p = (a - (i - 1) * 0.3) / 1.2   -- each ring starts 0.3 s after the one before
        if p < 0 or p > 1 then
            ring:SetHidden(true)
        else
            local s = 0.6 + 3.2 * (1 - (1 - p) ^ 2)   -- quick burst, slowing down
            ring:Set3DLocalDimensions(s, s)
            ring:Set3DRenderSpaceOrigin(rx, ry, rz)
            ring:SetColor(done.r, done.g, done.b, 0.95 * (1 - p))
            ring:SetHidden(false)
        end
    end
    return true
end


-- The route is worked out a few times a second from the learned point nearest to
-- you, which on a fast mount is often already behind you. Every frame the part
-- behind is cut off: the line joins the route at its closest point ahead.
local TRIM_SEGS = 12      -- route stretches searched for the closest point
local TRIM_MAX_M = 12     -- further than this from the route: keep it as it is
function TrimBehind(pts, px, py, pz)
    if #pts < 3 then return pts end
    local bestD, bestK, qx, qy, qz
    for k = 2, math.min(#pts - 1, TRIM_SEGS) do
        local a, b = pts[k], pts[k + 1]
        local ex, ez = b[1] - a[1], b[3] - a[3]
        local l2 = ex * ex + ez * ez
        local f = l2 > 0 and zo_clamp(((px - a[1]) * ex + (pz - a[3]) * ez) / l2, 0, 1) or 0
        local x, z = a[1] + ex * f, a[3] + ez * f
        local d = (px - x) ^ 2 + (pz - z) ^ 2
        if not bestD or d < bestD then
            bestD, bestK = d, k
            qx, qy, qz = x, a[2] + (b[2] - a[2]) * f, z
        end
    end
    if not bestD or bestD > TRIM_MAX_M * TRIM_MAX_M then return pts end
    local out = { { px, py, pz }, { qx, qy, qz } }
    for k = bestK + 1, #pts do out[#out + 1] = pts[k] end
    return out
end

function Path.Update(nav, dt, now)
    if not win then return end
    -- a background wayshrine lookup borrows the map for a moment: keep the arrows as
    -- they are instead of blinking them off
    if W.Nav.busy and not nav.valid then return end
    local sv = W.sv.path
    local t = nav.target

    -- ground height follows your feet, but ignores jumps (the markers use it too)
    local wy = nav.wy
    if not groundY or wy < groundY then
        groundY = wy
    else
        groundY = groundY + (wy - groundY) * math.min(1, dt * 3)
    end
    nav.groundY = groundY
    nav.needStairs = false
    Path.lastPts = nil   -- the learned route this frame (world meters), for the minimap

    -- arrived: the line is gone, green rings ripple out on the goal once
    if nav.arrived and t and sv.shown and not win:IsHidden() then
        arrivedAt = arrivedAt or now
        lastDrawn = 0
        HideFrom(1)
        if not ArrivalRings(now) then HideRings() end
        return
    end
    arrivedAt = nil
    if not (sv.shown and nav.valid and t and nav.cal) or win:IsHidden() then
        HideAll()
        return
    end
    -- the way to go, in meters: over the learned streets when known, else straight
    local wtx, wtz = W.Nav.MapToWorld(t.x, t.y)
    local px, py, pz = nav.wx / 100, groundY / 100, nav.wz / 100
    local tx, tz = wtx / 100, wtz / 100
    -- objective up or down a floor (compass): its height, so routes over stairs win
    local floorCm = W.Nav.TargetFloorHeight(wtx, wtz)
    local ty = floorCm and floorCm / 100
    lastTy, lastReach = ty, nil
    local pts = W.Roads.Route(nav, px, py, pz, tx, tz, now, ty)
    -- up or down a floor with no walked way there yet (the stairs were never taken):
    -- a straight line would run into the wall, so no line; the arrow says "find the stairs"
    -- only close by (same building): far away the ground simply rises or falls on the way
    if ty and math.abs(ty - py) > 2 and (nav.dist or 0) <= STAIRS_NEAR_M then
        -- the walked way must end up on the objective's side (a floor up / down), not
        -- necessarily at the estimated height
        local reach = pts and #pts >= 2 and pts[#pts - 1][2]
        local ok = reach and ((ty > py and reach >= py + 2) or (ty < py and reach <= py - 2))
        lastReach = reach
        if not ok then
            nav.needStairs = true
            HideAll()
            return
        end
    end
    lastRouted = pts ~= nil
    if pts then pts = TrimBehind(pts, px, py, pz) end
    Path.lastPts = pts
    if not pts then pts = { { px, py, pz }, { tx, py, tz } } end
    lastEnd = pts[#pts]   -- where the arrival rings go

    -- how far you moved along the way since last frame: the beads stay put on the
    -- ground while you ride over them (no sliding along with you)
    do
        local a, b = pts[1], pts[2]
        local l = math.sqrt((b[1] - a[1]) ^ 2 + (b[3] - a[3]) ^ 2)
        if lastPX and l > 0.01 then
            local dx, dz = px - lastPX, pz - lastPZ
            if dx * dx + dz * dz < 20 * 20 then   -- not a teleport
                movedM = movedM + (dx * (b[1] - a[1]) + dz * (b[3] - a[3])) / l
            end
        end
        lastPX, lastPZ = px, pz
    end

    -- lengths along the way
    local segLen, total = {}, 0
    for k = 1, #pts - 1 do
        local a, b = pts[k], pts[k + 1]
        local l = math.sqrt((b[1] - a[1]) ^ 2 + (b[3] - a[3]) ^ 2)
        segLen[k] = l
        total = total + l
    end
    if total < 0.5 then
        HideAll()
        return
    end

    -- point, height and direction at a distance along the way
    local seg, segStart = 1, 0
    local function At(d)
        while seg < #segLen and d > segStart + segLen[seg] do
            segStart = segStart + segLen[seg]
            seg = seg + 1
        end
        local a, b = pts[seg], pts[seg + 1]
        local l = segLen[seg]
        local f = l > 0 and zo_clamp((d - segStart) / l, 0, 1) or 0
        local ux, uz = 0, 1
        if l > 0 then ux, uz = (b[1] - a[1]) / l, (b[3] - a[3]) / l end
        return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f, ux, uz
    end

    local endM = total - nav.radiusM
    local cut = endM > sv.length
    if cut then endM = sv.length end
    local anim = W.sv.anim
    local since = now - (nav.targetSince or 0)
    local drawn = endM
    if anim ~= "off" then drawn = math.min(endM, START_M + since * DRAW_SPEED) end

    local file, size, spacing = StyleOf(sv)
    if sv.style .. sv.width .. file ~= currentKey then Path.Apply() end
    lastDrawn = 0
    local c = sv.color
    local style = sv.style
    if style == "solid" and file ~= "chev_solid.dds" then style = "chevrons" end   -- picture not loaded yet
    -- (minus the distance you moved: beads keep their spot on the ground as you pass)
    local flow = (sv.flow and anim ~= "off") and now * FLOW_SPEED or 0
    local phase = (flow - movedM) % spacing
    local fadeLen = sv.length * 0.4
    local comet = style == "comet" and ((now * COMET_SPEED) % (endM + 8)) or nil

    -- one glowing bead: at (x, y, z) meters, moved back / sideways along direction (ux, uz)
    local n = 0
    -- a little lighter than the chosen color, so it doesn't sink into sand and grass
    local solid = style == "solid"
    local lighten = solid and SOLID_LIGHTEN or LIGHTEN   -- solid: real gold, not whitish
    local br, bg, bb = c.r + (1 - c.r) * lighten, c.g + (1 - c.g) * lighten, c.b + (1 - c.b) * lighten
    local edgeFile = solid and Path.EdgeFile()
    local thinEdge = edgeFile == "chev_edge.dds"
    local function Bead(x, y, z, ux, uz, back, side, a, beadSize)
        if n >= MAX_DOTS then return end
        n = n + 1
        local tex = dots[n]
        if not tex then
            -- dark soft shadow first (under), then the bead: readable on bright ground
            local sh = NewTex(solid and edgeFile or "dot.dds")
            sh:Set3DRenderSpaceUsesDepthBuffer(sv.depth)
            sh:SetDrawLevel(0)
            shadows[n] = sh
            tex = NewTex(file)
            tex:Set3DRenderSpaceUsesDepthBuffer(sv.depth)
            tex:SetDrawLevel(1)
            dots[n] = tex
        end
        local bx = x - ux * back - uz * side
        local bz = z - uz * back + ux * side
        local sh = shadows[n]
        if solid then
            -- the chevron's tip points along the way: yaw 0 = north (-z), growing toward west
            local yaw = math.atan2(-ux, -uz)
            tex:Set3DRenderSpaceOrientation(-math.pi / 2, yaw, 0)
            sh:Set3DRenderSpaceOrientation(-math.pi / 2, yaw, 0)
        end
        -- under it: thin dark edge (same size) for solid chevrons, else a soft dark spot
        local shS = beadSize * ((solid and thinEdge) and 1 or (solid and 1.6 or 1.9))
        sh:Set3DLocalDimensions(shS, shS)
        sh:Set3DRenderSpaceOrigin(WorldPositionToGuiRender3DPosition(bx * 100, y * 100 + 4, bz * 100))
        sh:SetColor(0, 0, 0, (solid and thinEdge and EDGE_A or SHADOW_A) * a)
        sh:SetHidden(false)
        tex:Set3DLocalDimensions(beadSize, beadSize)
        tex:Set3DRenderSpaceOrigin(WorldPositionToGuiRender3DPosition(bx * 100, y * 100 + 6, bz * 100))
        tex:SetColor(br, bg, bb, math.min(1, a))
        tex:SetHidden(false)
    end

    local d = START_M + phase
    local prevY = py
    while d <= drawn and n < MAX_DOTS do
        local a = zo_clamp((d - START_M) / 1.5, 0, 1)
        if cut then a = a * zo_clamp((endM - d) / fadeLen, 0, 1) end
        local x, y, z, ux, uz = At(d)
        -- height from the ground you've walked around here (stairs, slopes): each bead
        -- continues from the one before, so it stays on one level under bridges
        local h = W.Roads.HeightAt(x, z, 5, prevY)
        if h then
            y = h
        elseif not lastRouted then
            y = prevY   -- nothing known: keep the last known height
        end
        prevY = y
        if solid then
            -- one filled chevron; near the goal (in reach of the line) the last ones melt:
            -- they shrink and fade over the last few meters, into the rings on the spot
            -- glass + spotlight: see-through gold, clearest a few steps ahead (Spot
            -- replaces the fade-in at your feet; the far end still fades out)
            local melt = cut and 1 or zo_clamp((endM - d) / MELT_M, 0, 1)
            local farFade = cut and zo_clamp((endM - d) / fadeLen, 0, 1) or 1
            local alpha = sv.alpha * GLASS * Spot(d, sv.length) * farFade * math.sqrt(melt)
            Bead(x, y, z, ux, uz, 0, 0, alpha, size * (0.35 + 0.65 * melt))
        elseif style == "chevrons" then
            -- a "V" of five beads pointing along the way
            local arm = size * 0.5
            local bead = sv.width * 0.9
            Bead(x, y, z, ux, uz, 0, 0, sv.alpha * a, bead * 1.15)
            Bead(x, y, z, ux, uz, arm * 0.5, arm * 0.5, sv.alpha * a, bead)
            Bead(x, y, z, ux, uz, arm * 0.5, -arm * 0.5, sv.alpha * a, bead)
            Bead(x, y, z, ux, uz, arm, arm, sv.alpha * a * 0.8, bead)
            Bead(x, y, z, ux, uz, arm, -arm, sv.alpha * a * 0.8, bead)
        elseif comet then
            -- thin faint line, bright and bigger where the pulse is
            local near = math.max(0, 1 - math.abs(d - comet) / 2)
            local alpha = math.min(1, sv.alpha * a * (0.35 + 0.65 * near) * 1.6)
            Bead(x, y, z, ux, uz, 0, 0, alpha, size * (1 + 1.5 * near))
            local wr = 0.6 * near
            dots[n]:SetColor(br + (1 - br) * wr, bg + (1 - bg) * wr, bb + (1 - bb) * wr, alpha)
        else
            Bead(x, y, z, ux, uz, 0, 0, sv.alpha * a, size)
        end
        d = d + spacing
    end
    if n > used then used = n end
    lastDrawn = n
    HideFrom(n + 1)

    -- rings rippling outward on the objective when it's within reach of the line
    -- (not where the NPC ring or the hunting area already marks the spot)
    local marked = (W.sv.npcMarker and not t.kill) or (W.sv.killArea and t.kill)
    if sv.marker and not cut and drawn >= endM and not marked then
        local base = math.min(math.max(1.6, nav.radiusM * 2), 30)
        local last = pts[#pts]
        local rx, ry, rz = WorldPositionToGuiRender3DPosition(last[1] * 100, last[2] * 100 + 6, last[3] * 100)
        rings[3]:SetHidden(true)   -- (only for the arrival burst)
        for i = 1, 2 do
            local ring = rings[i]
            local p = anim == "off" and 0.6 or ((now * 0.55 + (i - 1) * 0.5) % 1)
            if anim == "off" and i == 2 then
                ring:SetHidden(true)
            else
                local s = base * (0.35 + 0.9 * p)
                ring:Set3DLocalDimensions(s, s)
                ring:Set3DRenderSpaceOrigin(rx, ry, rz)
                ring:SetColor(c.r, c.g, c.b, math.min(1, sv.alpha * 1.5) * (anim == "off" and 1 or (1 - p)))
                ring:SetHidden(false)
            end
        end
    else
        HideRings()
    end
end


function Path.DebugText()
    if not win then return "line: 3D drawing not available in this game version" end
    local sv = W.sv.path
    local file = StyleOf(sv)
    local floorInfo = ""
    if lastTy then
        floorInfo = string.format(", [0.6.5] objective floor %.1f m, walked way reaches %s", lastTy,
            lastReach and string.format("%.1f m", lastReach) or "nothing")
    end
    return string.format("line: shown %s, window hidden %s, style %s (%s), pieces drawn %d, %s%s",
        tostring(sv.shown), tostring(win:IsHidden()), sv.style, file, lastDrawn,
        lastRouted and "following streets" or "straight", floorInfo)
end

function Path.Supported()
    return supported
end
