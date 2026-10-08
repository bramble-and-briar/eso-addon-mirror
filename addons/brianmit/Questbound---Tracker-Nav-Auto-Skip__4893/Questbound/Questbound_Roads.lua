-- Questbound_Roads.lua : a street network that learns from walking.
-- ESO gives addons no map of walls or streets, so Questbound records where you
-- actually walk: a point every few meters (with its height), linked to the one
-- before. Walking the same street again reuses the points already there. That
-- makes a graph of real walkable paths per zone (sv.roads[zoneId]), and the
-- ground line follows the shortest way over it to the objective (A*), like a
-- navigation app. Where nothing is known yet the line stays straight.
--
-- Positions are world meters (x, y = height, z). Saved per zone as flat lists:
-- p = { x1, y1, z1, x2, y2, z2, ... } and e = { [i] = { j, k, ... } } (links).

local W = Questbound
local Roads = {}
W.Roads = Roads

local STEP = 3.5          -- m between recorded points
local SNAP = 2.0          -- m: this close to a known point = the same street
local TURN_MIN = 1.5      -- m: when you turn, a point already after this far...
local TURN_COS = 0.82     -- ...when the way bends more than ~35 degrees (corners, stair turns)
local MAX_SLOPE = 1.1     -- links steeper than this (rise per meter) + 1 m are impossible:
                          -- old data from before floors were kept apart, skipped when routing
local LEVEL_DY = 1.8      -- m: a known point more than this up / down is another floor
local CLIMB = 1.2         -- m: on stairs a point every this much up or down
local LINK_MAX = 14       -- m: longest link (a bigger jump is a teleport / loading)
local CELL = 10           -- m: lookup grid cell
local MAX_NODES = 12000   -- per zone
local START_RANGE = 25    -- m: the route starts at a known point this close to you
local OFFROAD = 1.6       -- walking off the known streets counts this much more
local MAX_EXPAND = 8000   -- A* work limit per route
local ROUTE_EVERY = 0.3   -- s between route updates (the line trims itself every frame in between)
local RECORD_EVERY = 0.25 -- s between recording checks

local zone          -- zone id the loaded data belongs to
local data          -- { p = {...}, e = {...} }
local grid = {}     -- ["cx:cz"] = { i, ... }
local count = 0
local last          -- last point recorded / passed (index)
local lastX, lastZ
local dirX, dirZ     -- direction of the last recorded stretch (for corners)
local nextRecord = 0

-- route cache
local route, routeTime, routeKey = nil, 0, nil

-- ---------------------------------------------------------------------------
-- Points and lookups

local function Pos(i)
    local p = data.p
    return p[3 * i - 2], p[3 * i - 1], p[3 * i]
end

local function Dist2(ax, az, bx, bz)
    local dx, dz = ax - bx, az - bz
    return dx * dx + dz * dz
end

local function CellKey(cx, cz) return cx .. ":" .. cz end

local function AddToGrid(i)
    local x, _, z = Pos(i)
    local key = CellKey(zo_floor(x / CELL), zo_floor(z / CELL))
    local list = grid[key]
    if not list then
        list = {}
        grid[key] = list
    end
    list[#list + 1] = i
end

-- Nearest known point within range meters (index, distance), or nil. With y, only
-- points on the same level (at most dy meters up or down): upstairs isn't the
-- same spot as the room below it.
local function Nearest(x, z, range, y, dy)
    local best, bestD2 = nil, range * range
    local r = math.ceil(range / CELL)
    local cx, cz = zo_floor(x / CELL), zo_floor(z / CELL)
    for gx = cx - r, cx + r do
        for gz = cz - r, cz + r do
            local list = grid[CellKey(gx, gz)]
            if list then
                for _, i in ipairs(list) do
                    local px, py, pz = Pos(i)
                    local d2 = Dist2(x, z, px, pz)
                    if d2 < bestD2 and (not y or math.abs(py - y) <= dy) then best, bestD2 = i, d2 end
                end
            end
        end
    end
    return best, best and math.sqrt(bestD2)
end

local MergeShipped   -- (below)

local function Load(zoneId)
    zone = zoneId
    ZO_ClearTable(grid)
    last, lastX, lastZ = nil, nil, nil
    dirX, dirZ = nil, nil
    route = nil
    local all = W.sv.roads
    data = all[zoneId]
    if not data then
        data = { p = {}, e = {} }
        all[zoneId] = data
    end
    count = #data.p / 3
    for i = 1, count do AddToGrid(i) end
    MergeShipped(zoneId)
end

local function Link(i, j)
    if i == j then return end
    local e = data.e
    local function Add(a, b)
        local list = e[a]
        if not list then
            list = {}
            e[a] = list
        end
        for _, k in ipairs(list) do
            if k == b then return end
        end
        list[#list + 1] = b
    end
    Add(i, j)
    Add(j, i)
end

local function AddPoint(x, y, z)
    local p = data.p
    p[#p + 1] = zo_round(x * 10) / 10
    p[#p + 1] = zo_round(y * 10) / 10
    p[#p + 1] = zo_round(z * 10) / 10
    count = count + 1
    AddToGrid(count)
    return count
end

-- Routes shipped with the addon (Questbound_RouteData.lua) join your own learned
-- streets once per zone and data version: shipped points close to one of yours
-- (same level) become that one, the rest are added, and their links follow.
function MergeShipped(zoneId)
    local ship = W.RouteData
    local z = ship and ship.roads and ship.roads[zoneId]
    if not z or not z.p then return end
    W.sv.roadsMerged = W.sv.roadsMerged or {}
    if W.sv.roadsMerged[zoneId] == ship.version then return end
    local map = {}
    local sp = z.p
    for i = 1, zo_floor(#sp / 3) do
        local x, y, zz = sp[3 * i - 2], sp[3 * i - 1], sp[3 * i]
        local near = Nearest(x, zz, SNAP, y, LEVEL_DY)
        if not near and count < MAX_NODES then near = AddPoint(x, y, zz) end
        map[i] = near
    end
    for i, list in pairs(z.e or {}) do
        local a = map[tonumber(i)]
        if a then
            for _, j in ipairs(list) do
                local b = map[j]
                if b then Link(a, b) end
            end
        end
    end
    W.sv.roadsMerged[zoneId] = ship.version
end

-- ---------------------------------------------------------------------------
-- Recording (called every frame from Nav, works a few times per second)

function Roads.Record(nav, now)
    if not W.sv.path.learn or not nav.zoneId or now < nextRecord then return end
    nextRecord = now + RECORD_EVERY
    if nav.zoneId ~= zone then Load(nav.zoneId) end
    if IsUnitDead("player") or (IsUnitSwimming and IsUnitSwimming("player")) then
        last = nil
        return
    end

    local x, z = nav.wx / 100, nav.wz / 100
    local y = (nav.groundY or nav.wy) / 100
    -- a jump in position = teleport or loading screen: don't link across it
    if lastX and Dist2(x, z, lastX, lastZ) > (LINK_MAX * 2) ^ 2 then last = nil end
    lastX, lastZ = x, z

    local near = Nearest(x, z, SNAP, y, LEVEL_DY)
    if near then
        if last and near ~= last then
            local ax, _, az = Pos(last)
            if Dist2(ax, az, x, z) <= LINK_MAX * LINK_MAX then Link(last, near) end
        end
        if near ~= last then dirX, dirZ = nil, nil end
        last = near
        return
    end
    local ax, ay, az
    if last then
        -- a new point every STEP meters, on stairs / slopes every CLIMB meters up or
        -- down, and where you turn (so the line goes round corners, not across them)
        ax, ay, az = Pos(last)
        local d2 = Dist2(ax, az, x, z)
        local turn = false
        if dirX and d2 >= TURN_MIN * TURN_MIN then
            local d = math.sqrt(d2)
            turn = ((x - ax) * dirX + (z - az) * dirZ) / d < TURN_COS
        end
        if d2 < STEP * STEP and math.abs(y - ay) < CLIMB and not turn then return end
    end
    if count >= MAX_NODES then return end
    local i = AddPoint(x, y, z)
    dirX, dirZ = nil, nil
    if last then
        local d2 = Dist2(ax, az, x, z)
        if d2 <= LINK_MAX * LINK_MAX then Link(last, i) end
        if d2 > 0.01 then
            local d = math.sqrt(d2)
            dirX, dirZ = (x - ax) / d, (z - az) / d
        end
    end
    last = i
end

-- ---------------------------------------------------------------------------
-- Routing

-- small binary heap of { f, i }
local function Push(heap, f, i)
    local n = #heap + 1
    heap[n] = { f, i }
    while n > 1 do
        local parent = zo_floor(n / 2)
        if heap[parent][1] <= heap[n][1] then break end
        heap[parent], heap[n] = heap[n], heap[parent]
        n = parent
    end
end

local function Pop(heap)
    local top = heap[1]
    local n = #heap
    heap[1] = heap[n]
    heap[n] = nil
    n = n - 1
    local k = 1
    while true do
        local l, r = 2 * k, 2 * k + 1
        local s = k
        if l <= n and heap[l][1] < heap[s][1] then s = l end
        if r <= n and heap[r][1] < heap[s][1] then s = r end
        if s == k then break end
        heap[s], heap[k] = heap[k], heap[s]
        k = s
    end
    return top[1], top[2]
end

local function Dist(ax, az, bx, bz) return math.sqrt(Dist2(ax, az, bx, bz)) end

-- Shortest way from (x, z) to (tx, tz) over the known streets, or nil when going
-- straight is as good (or nothing is known). Returns points { x, y, z } in meters,
-- starting at the player (height py) and ending at the target.
-- ty = the target's floor height when it's up or down a floor (else nil): ending
-- on the wrong floor then costs FLOOR_COST per meter, so routes over stairs win.
local FLOOR_COST = 8
local function FindRoute(x, py, z, tx, tz, ty)
    local function FloorCost(y) return ty and math.abs(y - ty) * FLOOR_COST or 0 end
    if not data or count == 0 then return nil end
    -- start on your own floor (not on the one above / below you)
    local s = Nearest(x, z, START_RANGE, py, LEVEL_DY + 0.7)
    if not s then return nil end

    local g, prev = { [s] = 0 }, {}
    local closed = {}
    local heap = {}
    local sx, _, sz = Pos(s)
    local startCost = Dist(x, z, sx, sz) * OFFROAD
    Push(heap, Dist(sx, sz, tx, tz), s)

    local bestTotal = Dist(x, z, tx, tz) * OFFROAD + FloorCost(py)   -- going straight
    local bestNode
    local expanded = 0
    local e = data.e
    while #heap > 0 and expanded < MAX_EXPAND do
        local f, i = Pop(heap)
        if startCost + f >= bestTotal then break end
        if not closed[i] then
            closed[i] = true
            expanded = expanded + 1
            local ix, iy, iz = Pos(i)
            local finish = startCost + g[i] + Dist(ix, iz, tx, tz) * OFFROAD + FloorCost(iy)
            if finish < bestTotal then bestTotal, bestNode = finish, i end
            local links = e[i]
            if links then
                for _, j in ipairs(links) do
                    local jx, jy, jz = Pos(j)
                    local flat = Dist(ix, iz, jx, jz)
                    -- nobody walks straight up a wall: a leftover link from old data
                    if not closed[j] and math.abs(jy - iy) <= flat * MAX_SLOPE + 1 then
                        local ng = g[i] + flat
                        if not g[j] or ng < g[j] then
                            g[j] = ng
                            prev[j] = i
                            Push(heap, ng + Dist(jx, jz, tx, tz), j)
                        end
                    end
                end
            end
        end
    end
    if not bestNode then return nil end

    local chain = {}
    local i = bestNode
    while i do
        chain[#chain + 1] = i
        i = prev[i]
    end
    local pts = { { x, py, z } }
    for k = #chain, 1, -1 do
        local px, pyy, pz = Pos(chain[k])
        pts[#pts + 1] = { px, pyy, pz }
    end
    local ly = pts[#pts][2]
    pts[#pts + 1] = { tx, ty or ly, tz }
    return pts
end

-- Route for the line (cached; worked out again every ROUTE_EVERY seconds or when
-- the target changes). Everything in meters.
function Roads.Route(nav, x, py, z, tx, tz, now, ty)
    if not W.sv.path.roads or not nav.zoneId then return nil end
    if nav.zoneId ~= zone then Load(nav.zoneId) end
    local key = zo_round(tx) .. ":" .. zo_round(tz) .. ":" .. (ty and zo_round(ty) or "-")
    if key == routeKey and now - routeTime < ROUTE_EVERY then
        if route then route[1] = { x, py, z } end   -- start follows you smoothly
        return route
    end
    routeKey, routeTime = key, now
    route = FindRoute(x, py, z, tx, tz, ty)
    return route
end

-- Ground height (m) at (x, z) from the learned points nearby: the closest ones
-- weigh most. near = the height just before (previous bead): points more than
-- MAX_STEP above or below it are another level (bridge over a street) and are
-- left out. nil when nothing was ever walked there.
local MAX_STEP = 2.5
function Roads.HeightAt(x, z, range, near)
    if not data or count == 0 then return nil end
    range = range or 6
    local r = math.ceil(range / CELL)
    local cx, cz = zo_floor(x / CELL), zo_floor(z / CELL)
    local sum, weight = 0, 0
    for gx = cx - r, cx + r do
        for gz = cz - r, cz + r do
            local list = grid[CellKey(gx, gz)]
            if list then
                for _, i in ipairs(list) do
                    local px, py, pz = Pos(i)
                    local d2 = Dist2(x, z, px, pz)
                    if d2 <= range * range and (not near or math.abs(py - near) <= MAX_STEP) then
                        local w = 1 / (d2 + 0.25)
                        sum = sum + py * w
                        weight = weight + w
                    end
                end
            end
        end
    end
    if weight == 0 then return nil end
    return sum / weight
end

-- Ground height (m) at (x, z) from learned points between minY and maxY (either
-- may be nil): the floor above / below you. nil when that floor was never walked.
function Roads.HeightAtLevel(x, z, range, minY, maxY)
    if not data or count == 0 then return nil end
    local r = math.ceil(range / CELL)
    local cx, cz = zo_floor(x / CELL), zo_floor(z / CELL)
    local sum, weight = 0, 0
    for gx = cx - r, cx + r do
        for gz = cz - r, cz + r do
            local list = grid[CellKey(gx, gz)]
            if list then
                for _, i in ipairs(list) do
                    local px, py, pz = Pos(i)
                    local d2 = Dist2(x, z, px, pz)
                    if d2 <= range * range and (not minY or py >= minY) and (not maxY or py <= maxY) then
                        local w = 1 / (d2 + 0.25)
                        sum = sum + py * w
                        weight = weight + w
                    end
                end
            end
        end
    end
    if weight == 0 then return nil end
    return sum / weight
end

-- Highest walked ground (m) around (x, z), at most maxRise above near: the top
-- of the steps in front of a door. nil when nothing was walked there.
function Roads.TopAt(x, z, range, near, maxRise)
    if not data or count == 0 then return nil end
    local r = math.ceil(range / CELL)
    local cx, cz = zo_floor(x / CELL), zo_floor(z / CELL)
    local top
    for gx = cx - r, cx + r do
        for gz = cz - r, cz + r do
            local list = grid[CellKey(gx, gz)]
            if list then
                for _, i in ipairs(list) do
                    local px, py, pz = Pos(i)
                    if Dist2(x, z, px, pz) <= range * range and py >= near - maxRise and py <= near + maxRise
                        and (not top or py > top) then
                        top = py
                    end
                end
            end
        end
    end
    return top
end

function Roads.Forget()
    if zone then
        W.sv.roads[zone] = nil
        -- the shipped routes (checked ones) come back; only what you walked yourself is gone
        if W.sv.roadsMerged then W.sv.roadsMerged[zone] = nil end
        Load(zone)
    end
end

function Roads.DebugText()
    return string.format("streets: %d points in this zone, route %s",
        count, route and (#route .. " points") or "straight")
end
