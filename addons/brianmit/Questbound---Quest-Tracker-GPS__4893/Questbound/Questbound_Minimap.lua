-- Questbound_Minimap.lua : shows the way on AUI (Advanced UI)'s minimap, when that
-- addon is installed and its minimap is on. A dotted gold line runs from you to the
-- objective (over the streets you've walked, like the ground line), with a gold ring
-- on the objective; when the objective is off the minimap, a gold arrow on the
-- minimap's edge points toward it.
--
-- Nothing of AUI is changed: our pictures are children of AUI's map container (so
-- the minimap's frame clips them) and placed the way AUI places its own pins, with
-- its public functions (AUI.Minimap.GetMapContainerSize / DoesRotate /
-- GetRotationData / GetPlayerPosition). Made to work with AUI 3.99.

local W = Questbound
local Minimap = {}
W.Minimap = Minimap

local MAX_DOTS = 70
local DOT_STEP = 9      -- px between dots on the minimap
local DOT_SIZE = 5
local START_PX = 8      -- the line starts this far from your own arrow
local EDGE_PAD = 9      -- the edge arrow stays this far inside the frame

local parent            -- AUI's map container
local scroll            -- AUI's clipping frame around it
local dots = {}
local outlines = {}     -- dark spot under each dot: gold alone vanishes on bright yellow maps
local ring, center, edge
local ringBack, edgeBack  -- dark copies behind the ring and the edge arrow
local shownDots = 0
local OUTLINE_A = 0.75

local function Available()
    return AUI and AUI.Minimap and AUI.Minimap.IsLoaded and AUI.Minimap.IsLoaded()
        and AUI.Minimap.GetMapContainer and AUI.Minimap.GetMapContainer() ~= nil
end

local function Tex(file, size, level)
    local t = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    t:SetTexture(W.TEX .. file)
    t:SetDimensions(size, size)
    t:SetDrawLayer(DL_OVERLAY)
    t:SetDrawLevel(level)
    t:SetHidden(true)
    return t
end

local function Setup()
    if parent then return true end
    if not Available() then return false end
    parent = AUI.Minimap.GetMapContainer()
    scroll = _G["AUI_Minimap_MainWindow_Map_Scroll"] or parent:GetParent()
    ringBack = Tex("ring.dds", 20, 59)
    ringBack:SetColor(0, 0, 0, OUTLINE_A)
    ring = Tex("ring.dds", 16, 60)
    center = Tex("dot.dds", 6, 61)
    edgeBack = Tex("arrow.dds", 18, 61)
    edgeBack:SetColor(0, 0, 0, OUTLINE_A)
    edge = Tex("arrow.dds", 14, 62)
    return true
end

local function HideAll()
    for i = 1, shownDots do
        dots[i]:SetHidden(true)
        outlines[i]:SetHidden(true)
    end
    shownDots = 0
    if ring then
        for _, t in ipairs({ ring, ringBack, center, edge, edgeBack }) do t:SetHidden(true) end
    end
end

-- Map spot (0..1) -> offset from the minimap's middle in px, like AUI's pins.
local function ToMinimap(nx, ny)
    local size = AUI.Minimap.GetMapContainerSize()
    if AUI.Minimap.DoesRotate() then
        local c, s = AUI.Minimap.GetRotationData()
        local px, py = AUI.Minimap.GetPlayerPosition()
        local x, y = nx * size - px, ny * size - py
        return c * x - s * y, s * x + c * y
    end
    local mx, my = scroll:GetCenter()
    return parent:GetLeft() + nx * size - mx, parent:GetTop() + ny * size - my
end

local function Put(tex, x, y)
    tex:ClearAnchors()
    tex:SetAnchor(CENTER, scroll, CENTER, x, y)
    tex:SetHidden(false)
end

function Minimap.Update(nav)
    if not W.sv.minimap or not nav.valid or not nav.target or not nav.cal or not Setup()
        or not AUI.Minimap.DoesShow() then
        HideAll()
        return
    end
    local t = nav.target
    local gold = W.COLOR.theme
    local hw, hh = scroll:GetWidth() / 2, scroll:GetHeight() / 2
    local function Inside(x, y, pad) return math.abs(x) <= hw - pad and math.abs(y) <= hh - pad end

    -- the way: the learned route (world meters) when the ground line has one, else straight
    local pts = {}
    local route = W.Path.lastPts
    local ox, oy = ToMinimap(nav.px, nav.py)
    pts[1] = { ox, oy }
    if route then
        for k = 2, #route - 1 do
            local mx, my = W.Nav.WorldToMap(route[k][1] * 100, route[k][3] * 100)
            if mx then pts[#pts + 1] = { ToMinimap(mx, my) } end
        end
    end
    local tx, ty = ToMinimap(t.x, t.y)
    pts[#pts + 1] = { tx, ty }

    -- dots every DOT_STEP px along it (only where the minimap shows them)
    local n, carry = 0, START_PX
    for k = 1, #pts - 1 do
        local ax, ay, bx, by = pts[k][1], pts[k][2], pts[k + 1][1], pts[k + 1][2]
        local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
        local d = carry
        while d < len and n < MAX_DOTS do
            local f = d / len
            local x, y = ax + (bx - ax) * f, ay + (by - ay) * f
            if Inside(x, y, 3) then
                n = n + 1
                local dot = dots[n]
                if not dot then
                    outlines[n] = Tex("dot.dds", DOT_SIZE + 4, 54)
                    outlines[n]:SetColor(0, 0, 0, OUTLINE_A)
                    dot = Tex("dot.dds", DOT_SIZE, 55)
                    dots[n] = dot
                end
                dot:SetColor(gold.r, gold.g, gold.b, 1)
                Put(outlines[n], x, y)
                Put(dot, x, y)
            end
            d = d + DOT_STEP
        end
        carry = d - len
    end
    for i = n + 1, shownDots do
        dots[i]:SetHidden(true)
        outlines[i]:SetHidden(true)
    end
    shownDots = n

    -- the objective: ring on it, or an arrow on the edge pointing toward it
    if Inside(tx, ty, 6) then
        ring:SetColor(gold.r, gold.g, gold.b, 1)
        center:SetColor(gold.r, gold.g, gold.b, 1)
        Put(ringBack, tx, ty)
        Put(ring, tx, ty)
        Put(center, tx, ty)
        edge:SetHidden(true)
        edgeBack:SetHidden(true)
    else
        ring:SetHidden(true)
        ringBack:SetHidden(true)
        center:SetHidden(true)
        local dx, dy = tx - ox, ty - oy
        local scale = math.min((hw - EDGE_PAD) / math.max(math.abs(dx), 1e-3), (hh - EDGE_PAD) / math.max(math.abs(dy), 1e-3))
        local ex, ey = ox + dx * math.min(scale, 1), oy + dy * math.min(scale, 1)
        ex = zo_clamp(ex, -(hw - EDGE_PAD), hw - EDGE_PAD)
        ey = zo_clamp(ey, -(hh - EDGE_PAD), hh - EDGE_PAD)
        -- arrow.dds points up; turned clockwise by the angle of the way (screen y goes down)
        local rot = -math.atan2(dx, -dy)
        edge:SetTextureRotation(rot)
        edgeBack:SetTextureRotation(rot)
        edge:SetColor(gold.r, gold.g, gold.b, 1)
        Put(edgeBack, ex, ey)
        Put(edge, ex, ey)
    end
end

function Minimap.DebugText()
    if not (AUI and AUI.Minimap) then return "[0.7.1] minimap: AUI not installed" end
    if not parent then return "[0.7.1] minimap: AUI's minimap not found (turned off in AUI?)" end
    return string.format("[0.7.1] minimap: shown %s, dots drawn %d, objective %s", tostring(AUI.Minimap.DoesShow()),
        shownDots, (ring and not ring:IsHidden()) and "on the minimap" or ((edge and not edge:IsHidden()) and "off the minimap (edge arrow)" or "not drawn"))
end

function Minimap.Apply()
    if not W.sv.minimap then HideAll() end
end

function Minimap.Init()
    W.callbacks:RegisterCallback("SettingsChanged", Minimap.Apply)
end
