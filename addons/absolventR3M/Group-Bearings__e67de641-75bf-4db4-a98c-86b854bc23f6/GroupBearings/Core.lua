-- Group Bearings: math and layout rules.
-- Nothing in this file calls the game, so the test harness can drive it directly.

GroupBearings = GroupBearings or {}
local Core = {}
GroupBearings.Core = Core

local pi = math.pi
local TWO_PI = 2 * pi
local atan2, sqrt, floor, abs = math.atan2, math.sqrt, math.floor, math.abs

-- The game's compass is linear in angle and about 108 degrees wide. This is
-- the value CustomCompassPins has matched the native compass with for years.
Core.DEFAULT_FOV_DEGREES = 108

-- Two compass icons this close (as a share of an icon's width) count as overlapping.
Core.OVERLAP_FRACTION = 0.8

function Core.NormalizeAngle(angle)
    while angle > pi do angle = angle - TWO_PI end
    while angle < -pi do angle = angle + TWO_PI end
    return angle
end

-- World axes: X grows east, Z grows south, Y is up, all in centimetres.
-- Camera heading: 0 faces north and grows counter-clockwise (west is pi/2).
-- Returns how far right (+) or left (-) of straight ahead a point is, in radians.
function Core.RelativeAngle(px, pz, tx, tz, heading)
    return Core.NormalizeAngle(heading - atan2(px - tx, pz - tz))
end

-- Pixel offset from the compass centre. Off-compass angles return nil, or the
-- nearest edge when clamp is set (the game clamps its symbol pins the same way).
function Core.CompassX(angle, fovRadians, width, clamp)
    local n = 2 * angle / fovRadians
    if n > 1 or n < -1 then
        if not clamp then return nil end
        n = n > 0 and 1 or -1
    end
    return 0.5 * width * n
end

-- Centimetres in, metres out.
function Core.Distance3D(x1, y1, z1, x2, y2, z2)
    local dx, dy, dz = x1 - x2, y1 - y2, z1 - z2
    return sqrt(dx * dx + dy * dy + dz * dz) / 100
end

function Core.FormatDistance(metres)
    return string.format("%dm", floor(metres + 0.5))
end

-- Width estimate for a distance label such as "48m", in UI units.
function Core.EstimateLabelWidth(text, fontSize)
    return #text * fontSize * 0.58 + 4
end

-- Yaw for a flat world-space control so its texture bottom points from
-- (fromX, fromZ) toward (toX, toZ), used with SetTransformRotation(-pi/2, yaw, 0).
-- Same convention as Artaeum Group Tool's crown arrow.
function Core.GroundYaw(fromX, fromZ, toX, toZ)
    return atan2(toX - fromX, toZ - fromZ)
end

-- Rotation that turns an upright world-space control toward the camera,
-- from the camera's forward vector.
function Core.BillboardRotation(fx, fy, fz)
    local yaw = Core.NormalizeAngle(atan2(fx, fz) - pi)
    local pitch = atan2(fy, sqrt(fx * fx + fz * fz))
    return pitch, yaw
end

-- 0 at or below 'from', 1 at or above 'to', linear between.
function Core.Ramp(value, from, to)
    if value <= from then return 0 end
    if value >= to then return 1 end
    return (value - from) / (to - from)
end

-- Strength of a beam left on a last known spot: 1 while the position is fresh
-- and through most of the linger, then fading to 0 over the last fadePortion.
function Core.LingerFactor(ageMs, freshMs, lingerMs, fadePortion)
    local linger = ageMs - freshMs
    if linger <= 0 then return 1 end
    if linger >= lingerMs then return 0 end
    local fadeStart = lingerMs * (1 - fadePortion)
    if linger <= fadeStart then return 1 end
    return 1 - (linger - fadeStart) / (lingerMs - fadeStart)
end

-- maxM of 0 means no upper limit.
function Core.BeamVisible(dist, minM, maxM)
    if dist < (minM or 0) then return false end
    if maxM and maxM > 0 and dist > maxM then return false end
    return true
end

-- Point at a camera-relative angle (radians, + is right) and distance (cm),
-- for the preview targets.
function Core.OffsetFromHeading(px, pz, heading, angle, distanceCm)
    local h = heading - angle
    return px - math.sin(h) * distanceCm, pz - math.cos(h) * distanceCm
end

---------------------------------------------------------------------------
-- Compass layout
--
-- markers: entries { x, dist, text, order } for symbols on the compass, with x
--          already set (clamped to the edge like the game's own symbol pins).
-- members: entries { x (nil when off the compass), dist, text, isLeader, order }.
-- opts:    iconPx, gapPx, markerLabels, groupLabels,
--          crownSymbol (the crown counts as a symbol), keepCrown (the crown
--          icon draws over every other marker), crownOnTop (the crown wins
--          every overlap, icon and text), markerWidth(text), groupWidth(text)
--
-- Results are written onto the entries:
--   marker.labelShown
--   member.mode = "icon" | "crown" | nil, member.labelShown, member.onTop
--
-- Rules:
--   * Symbol labels come first and the closer symbol wins when two collide.
--     With crownSymbol the crown takes part like a symbol; with crownOnTop it
--     goes before every symbol, whatever the distance.
--   * Every member on the compass keeps their icon (the leader the crown).
--     With keepCrown or crownOnTop the crown is flagged onTop: it is drawn
--     above every compass marker, the game's included.
--   * Members whose icons touch form a pile; each pile gets one label, the
--     closest member's, and only if it does not collide with a symbol label
--     or a closer member's label.
---------------------------------------------------------------------------
local placedX, placedW, placedCount = {}, {}, 0
local scratch, candidates = {}, {}

local function Fits(x, w, gap)
    for i = 1, placedCount do
        if abs(x - placedX[i]) < (w + placedW[i]) * 0.5 + gap then return false end
    end
    return true
end

local function Place(x, w)
    placedCount = placedCount + 1
    placedX[placedCount] = x
    placedW[placedCount] = w
end

local function ByDistance(a, b)
    if a.dist ~= b.dist then return a.dist < b.dist end
    return (a.order or 0) < (b.order or 0)
end

local function ByX(a, b)
    if a.x ~= b.x then return a.x < b.x end
    return (a.order or 0) < (b.order or 0)
end

local function Collect(list, source, count, keep)
    local n = 0
    for i = 1, count do
        local e = source[i]
        if not keep or keep(e) then
            n = n + 1
            list[n] = e
        end
    end
    for i = #list, n + 1, -1 do list[i] = nil end
    return n
end

local function OnCompass(e) return e.x ~= nil end
local function IsCandidate(e) return e.labelCandidate end


Core.ByDistance = ByDistance

function Core.LayoutCompass(markers, markerCount, members, memberCount, opts)
    placedCount = 0
    local gap = opts.gapPx or 6

    -- The crown: the leader's group pin, or the leader's symbol when the leader
    -- is marked and the crown is tracked (marker entry with isCrown).
    local crown = nil
    for i = 1, markerCount do
        local m = markers[i]
        m.labelShown = false
        if m.isCrown then crown = m end
    end
    for i = 1, memberCount do
        local e = members[i]
        e.mode, e.labelShown, e.labelCandidate, e.onTop = nil, false, false, false
        if e.isLeader and e.x ~= nil then crown = e end
    end
    local tracked = opts.crownSymbol or opts.crownOnTop
    local crownHandled = false

    -- 0. Crown always on top: its text goes before any symbol's.
    if crown and opts.crownOnTop then
        local w = crown.isLeader and opts.groupWidth(crown.text) or opts.markerWidth(crown.text)
        Place(crown.x, w)
        crown.labelShown = true
        crownHandled = true
    end

    -- 1. Symbol labels, closest first. A tracked crown takes part like a symbol.
    local n = 0
    for i = 1, markerCount do
        local m = markers[i]
        if not (m == crown and crownHandled) then
            n = n + 1
            scratch[n] = m
        end
    end
    if crown and crown.isLeader and tracked and not crownHandled then
        n = n + 1
        scratch[n] = crown
    end
    for i = #scratch, n + 1, -1 do scratch[i] = nil end
    table.sort(scratch, ByDistance)
    for i = 1, n do
        local m = scratch[i]
        if (m == crown and tracked) or (opts.markerLabels and not m.isLeader) then
            local w = m.isLeader and opts.groupWidth(m.text) or opts.markerWidth(m.text)
            if Fits(m.x, w, gap) then
                Place(m.x, w)
                m.labelShown = true
            end
        end
    end
    if crown and tracked then crownHandled = true end
    for i = 1, n do scratch[i] = nil end

    -- 2. Group pins: everyone keeps their icon; touching icons form a pile.
    local count = Collect(scratch, members, memberCount, OnCompass)
    table.sort(scratch, ByX)
    local overlapPx = opts.iconPx * Core.OVERLAP_FRACTION
    local i = 1
    while i <= count do
        local j = i
        while j < count and scratch[j + 1].x - scratch[j].x < overlapPx do
            j = j + 1
        end
        local closest = scratch[i]
        for k = i, j do
            local e = scratch[k]
            if ByDistance(e, closest) then closest = e end
            if e.isLeader then
                e.mode = "crown"
                e.onTop = (opts.keepCrown or opts.crownOnTop) == true
            else
                e.mode = "icon"
            end
        end
        closest.labelCandidate = true
        i = j + 1
    end
    for k = 1, count do scratch[k] = nil end

    -- 3. One label per cluster, closest first, symbols keep their room.
    if opts.groupLabels then
        local c = Collect(candidates, members, memberCount, IsCandidate)
        table.sort(candidates, ByDistance)
        for k = 1, c do
            local e = candidates[k]
            if not (e == crown and crownHandled) then
                local w = opts.groupWidth(e.text)
                if Fits(e.x, w, gap) then
                    Place(e.x, w)
                    e.labelShown = true
                end
            end
        end
        for k = 1, c do candidates[k] = nil end
    end
end

---------------------------------------------------------------------------
-- Arrows at your feet: which targets get one when arrows would overlap.
--
-- targets: entries { bearing (radians, world yaw toward the target), dist,
--          isCrown, live, wantPointer, order }. Writes target.pointerShown.
--          Targets with wantPointer == false take no part.
-- Closest first (the crown first with crownOnTop). An arrow only shows if it
-- is at least spacingRadians away from every arrow already shown, so the
-- closest target always gets the spot. Stale targets (live == false) never
-- get an arrow. spacingRadians of 0 shows every arrow.
---------------------------------------------------------------------------
local pointerScratch, shownBearings = {}, {}

local function CrownThenDistance(a, b)
    if a.isCrown ~= b.isCrown then return a.isCrown == true end
    return ByDistance(a, b)
end

function Core.AngleBetween(a, b)
    return abs(Core.NormalizeAngle(a - b))
end

function Core.LayoutPointers(targets, count, spacingRadians, crownFirst)
    local n = 0
    for i = 1, count do
        local t = targets[i]
        t.pointerShown = false
        if t.live ~= false and t.wantPointer ~= false then
            n = n + 1
            pointerScratch[n] = t
        end
    end
    for i = #pointerScratch, n + 1, -1 do pointerScratch[i] = nil end
    table.sort(pointerScratch, crownFirst and CrownThenDistance or ByDistance)
    local shown = 0
    for i = 1, n do
        local t = pointerScratch[i]
        local fits = true
        if spacingRadians > 0 then
            for k = 1, shown do
                if Core.AngleBetween(t.bearing, shownBearings[k]) < spacingRadians then
                    fits = false
                    break
                end
            end
        end
        if fits then
            shown = shown + 1
            shownBearings[shown] = t.bearing
            t.pointerShown = true
        end
        pointerScratch[i] = nil
    end
end
