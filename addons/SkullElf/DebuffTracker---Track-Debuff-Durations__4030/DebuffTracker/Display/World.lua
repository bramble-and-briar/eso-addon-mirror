-- "Above heads": places tracker entries over allies in the 3D world.
--
-- How: a 3D render space is synced to the game camera every frame; each ally's world position
-- (GetUnitRawWorldPosition, centimetres, Y up) is raised to head height, moved into camera space with
-- three dot products (right / up / forward), and projected with the visible world size at that depth
-- (GetWorldDimensionsOfViewFrustumAtDepth). Same technique as HyperTools' group-member anchors, but
-- one shared pass per frame for every tracker and every ally, and no matrix library.
--
-- Only allies: the game returns no world position for enemies. Each person is projected once per
-- frame; trackers stack their rows upward over that person in profile order.

local DT = DebuffTracker
local World = DT.World
local U = DT.Util

local NS = "DebuffTracker5_World"
local active = {}        -- [display] = true while it has entries to place
local running = false
local space
local cam = {}
local proj = {}          -- [tag] = { frame, ok, x, y, dist }
local frame = 0
World.available = nil    -- nil = not checked yet, false = this client has no 3D render space API

local function EnsureSpace()
    if space then return true end
    if World.available == false then return false end
    if type(Set3DRenderSpaceToCurrentCamera) ~= "function" or type(GetUnitRawWorldPosition) ~= "function"
        or type(GetWorldDimensionsOfViewFrustumAtDepth) ~= "function" then
        World.available = false
        return false
    end
    space = WINDOW_MANAGER:CreateControl("DebuffTracker5_RenderSpace", GuiRoot, CT_CONTROL)
    space:Create3DRenderSpace()
    space:SetHidden(true)
    World.available = true
    return true
end

local function UpdateCamera()
    Set3DRenderSpaceToCurrentCamera(space:GetName())
    cam.x, cam.y, cam.z = GuiRender3DPositionToWorldPosition(space:Get3DRenderSpaceOrigin())
    cam.fx, cam.fy, cam.fz = space:Get3DRenderSpaceForward()
    cam.rx, cam.ry, cam.rz = space:Get3DRenderSpaceRight()
    cam.ux, cam.uy, cam.uz = space:Get3DRenderSpaceUp()
    cam.sw, cam.sh = GuiRoot:GetWidth(), GuiRoot:GetHeight()
    cam.zone, cam.px, cam.py, cam.pz = GetUnitRawWorldPosition("player")
end

-- Screen offset (from the screen centre, UI units) of a point `heightCm` above the unit's feet.
-- Returns ok, x, y, distance from you in metres.
local function Project(tag, heightCm)
    local zone, wx, wy, wz = GetUnitRawWorldPosition(tag)
    if not zone or not wx or zone ~= cam.zone then return false end
    local dist = math.sqrt((wx - cam.px) ^ 2 + (wy - cam.py) ^ 2 + (wz - cam.pz) ^ 2) / 100
    wy = wy + heightCm
    local dx, dy, dz = wx - cam.x, wy - cam.y, wz - cam.z
    local depth = dx * cam.fx + dy * cam.fy + dz * cam.fz
    if depth <= 1 then return false end                      -- behind the camera
    local ww, wh = GetWorldDimensionsOfViewFrustumAtDepth(depth)
    if not ww or ww <= 0 or not wh or wh <= 0 then return false end
    local sx = dx * cam.rx + dy * cam.ry + dz * cam.rz
    local sy = dx * cam.ux + dy * cam.uy + dz * cam.uz
    local x, y = sx * cam.sw / ww, -sy * cam.sh / wh
    if math.abs(x) > cam.sw or math.abs(y) > cam.sh then return false end   -- far off screen
    return true, x, y, dist
end
World.Project = Project

local function IsMe(tag)
    return tag == "player" or (type(AreUnitsEqual) == "function" and AreUnitsEqual(tag, "player"))
end

-- Whether a unit gets icons at all (independent of the camera).
function World.UnitShown(tag, ds, preview)
    if not DoesUnitExist(tag) then return false end
    if preview then return true end
    if IsMe(tag) and not ds.headSelf then return false end
    if tag:sub(1, 5) == "group" and type(IsUnitOnline) == "function" and not IsUnitOnline(tag) then return false end
    if IsUnitDead(tag) then return false end
    return true
end

-- Distance look: smaller and fainter far away (settings).
function World.DistanceLook(dist, st)
    local maxD = st.headMaxDistance
    local scale, alpha = 1, 1
    if st.headShrink then
        scale = U.Clamp(1 - math.max(0, dist - 10) / math.max(1, maxD - 10) * 0.45, 0.55, 1)
    end
    if st.headFade then
        local start = maxD * 0.7
        if dist > start then alpha = U.Clamp(1 - (dist - start) / math.max(1, maxD - start) * 0.75, 0.25, 1) end
    end
    return scale, alpha
end

-- (an item hidden here is no longer "placed": the display keeps it hidden until it's placed again)
local function HideItems(items, from)
    for i = from or 1, #items do
        items[i].placed = false
        items[i].control:SetHidden(true)
    end
end

local byTag, tagOrder = {}, {}

local function PlaceDisplay(d, stack, st, heightCm)
    local ds = d.ds
    -- group this tracker's entries by unit, keeping their sorted order
    for k in pairs(byTag) do byTag[k] = nil end
    local nTags = 0
    for _, it in ipairs(d.order) do
        local tag = it.state and it.state.unitTag
        if tag then
            local list = byTag[tag]
            if not list then
                list = {}
                byTag[tag] = list
                nTags = nTags + 1
                tagOrder[nTags] = tag
            end
            list[#list + 1] = it
        else
            it.placed = false
            it.control:SetHidden(true)
        end
    end
    for ti = 1, nTags do
        local tag = tagOrder[ti]
        local items = byTag[tag]
        local preview = items[1].state.preview
        local p = proj[tag]
        if not p or p.frame ~= frame then
            p = p or {}
            proj[tag] = p
            p.frame = frame
            p.ok, p.x, p.y, p.dist = Project(tag, heightCm)
        end
        local maxD = st.headMaxDistance
        if not p.ok or (p.dist > maxD and not preview) or not World.UnitShown(tag, ds, preview) then
            HideItems(items)
        else
            local scale, alpha = World.DistanceLook(p.dist, st)
            local n = math.min(#items, ds.maxShown)
            local gap = math.max(2, ds.spacing)
            local width, rowH = 0, 0
            for i = 1, n do
                local it = items[i]
                local size = math.floor(ds.iconSize * scale * (it.lookScale or 1) + 0.5)
                DT.Displays.SizeHeadItem(it, d, size)
                width = width + size + (i > 1 and gap or 0)
                if size > rowH then rowH = size end
            end
            local x = p.x - width / 2
            local bottom = p.y - (stack[tag] or 0)
            for i = 1, n do
                local it = items[i]
                it.headAlpha = alpha
                it.placed = true
                it.control:SetHidden(false)
                it.control:ClearAnchors()
                -- centred vertically on the row so mixed sizes (rule scale) line up
                it.control:SetAnchor(LEFT, d.window, CENTER, x, bottom - rowH / 2)
                x = x + it.size + gap
            end
            HideItems(items, n + 1)
            stack[tag] = (stack[tag] or 0) + rowH + gap + 2
        end
    end
end

local stackScratch = {}

-- One pass per frame: camera, then every active above-heads tracker in profile order.
function World.Pass()
    if not next(active) then World.Stop() return end
    if not EnsureSpace() then return end
    frame = frame + 1
    UpdateCamera()
    local st = DT.Profiles.Settings()
    local heightCm = (st.headHeight or 2.6) * 100
    for k in pairs(stackScratch) do stackScratch[k] = nil end
    for _, t in ipairs(DT.Engine.trackers) do
        local d = DT.Displays.Get(t.id)
        if d and active[d] and d.kind == "heads" and not d.window:IsHidden() then
            if d.worldKeyFor ~= t.name then d.worldKeyFor, d.worldKey = t.name, "above heads: " .. t.name end
            U.SafeCall(d.worldKey, PlaceDisplay, d, stackScratch, st, heightCm)
        end
    end
end

function World.Start()
    if running then return end
    running = true
    EVENT_MANAGER:RegisterForUpdate(NS, 0, World.Pass)
end

function World.Stop()
    if not running then return end
    running = false
    EVENT_MANAGER:UnregisterForUpdate(NS)
end

-- Displays report whether they have entries to place.
function World.SetActive(display, on)
    if on then
        if not active[display] then
            active[display] = true
            if EnsureSpace() then World.Start() end
            World.Pass()
        end
    elseif active[display] then
        active[display] = nil
        if not next(active) then World.Stop() end
    end
end

function World.IsRunning() return running end
function World.ActiveCount() return U.Count(active) end
