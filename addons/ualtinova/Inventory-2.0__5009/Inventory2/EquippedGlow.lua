InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

-- Equipped Sets: a set worn in full (its largest bonus reached, the same test that colours the
-- count in the legend) is tied together by thin pipes in the set's own colour: straight lines
-- with right-angle turns running from box to box in figure order, and a faint wash over its
-- legend line. Under the mouse, white light comes up on the set's pipes and its line.
--
-- The pipes are drawn under the boxes, so a pipe runs from centre to centre and only the part
-- between boxes shows. Each leg of two picks the turn that crosses fewer other boxes.
-- Nothing here is drawn per frame: it is redone after every redraw of the page (which
-- EquippedDrawer.lua already settles), from pooled controls that are hidden and refilled,
-- never left holding an old set.
--
-- Taking this page out of the addon: drop this file and its line in the manifest.

local GREEN = { 0.20, 0.95, 0.35 }
local PIPE = 2               -- thickness of a pipe, in pixels
local PIPE_ALPHA = 0.55
local WHITE_ALPHA = 0.5
local ROW_WASH = { { 0, 0.02 }, { 3, 0.02 }, { 6, 0.025 } }

local function Enabled()
    return not (IG.sv and IG.sv.fullSetGlow == false)
end

local function Paint(tex, alpha)
    tex:SetColor(GREEN[1], GREEN[2], GREEN[3], 1)
    tex:SetAlpha(alpha)
end

-- One straight pipe: a flat texture (untextured, so its alpha goes through SetAlpha) with a
-- white one of the same size on top for the hover.
local function Pipe(parent)
    local pipe = WINDOW_MANAGER:CreateControl(nil, parent, CT_TEXTURE)
    pipe:SetDrawLayer(DL_BACKGROUND)
    pipe:SetDrawLevel(1)
    pipe:SetMouseEnabled(false)
    pipe:SetHidden(true)
    local white = WINDOW_MANAGER:CreateControl(nil, pipe, CT_TEXTURE)
    white:SetAnchorFill(pipe)
    white:SetDrawLayer(DL_BACKGROUND)
    white:SetDrawLevel(2)
    white:SetColor(1, 1, 1, 1)
    white:SetAlpha(WHITE_ALPHA)
    white:SetMouseEnabled(false)
    white:SetHidden(true)
    pipe.white = white
    return pipe
end

local function State(body)
    if not body.igFG then
        body.igFG = { bridges = {}, used = { bridges = 0 }, hover = nil }
    end
    return body.igFG
end

local function Take(body)
    local state = State(body)
    local index = state.used.bridges + 1
    state.used.bridges = index
    local pipe = state.bridges[index]
    if not pipe then
        pipe = Pipe(body)
        state.bridges[index] = pipe
    end
    -- A pooled pipe keeps nothing from its last life: set and white are given again.
    pipe.igSetId = nil
    pipe.white:SetHidden(true)
    pipe:ClearAnchors()
    pipe:SetHidden(false)
    return pipe
end

-- The white light on every bridge and line of one set (nil clears all).
local function Hover(body, setId)
    local state = State(body)
    state.hover = setId
    for index = 1, state.used.bridges do
        local blob = state.bridges[index]
        blob.white:SetHidden(not (setId and blob.igSetId == setId))
    end
    for _, row in ipairs(body.igRows or {}) do
        if row.igFGWhite then
            row.igFGWhite:SetHidden(not (setId and row.igFGSet == setId and not row:IsHidden()))
        end
    end
end

-- Wrapped once per control: the drawer's own handler runs first, then the white light.
local function Wire(body, control, getSetId)
    if control.igFGWired then return end
    control.igFGWired = true
    local enter, exit = control:GetHandler("OnMouseEnter"), control:GetHandler("OnMouseExit")
    control:SetHandler("OnMouseEnter", function(self, ...)
        if enter then enter(self, ...) end
        local id = getSetId(self)
        if id and body.igFullSets and body.igFullSets[id] and Enabled() then Hover(body, id) end
    end)
    control:SetHandler("OnMouseExit", function(self, ...)
        if exit then exit(self, ...) end
        Hover(body, nil)
    end)
end

local function RowWash(row)
    if not row.igFGLayers then
        row.igFGLayers = {}
        for index, layer in ipairs(ROW_WASH) do
            local tex = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
            tex:SetAnchor(TOPLEFT, row, TOPLEFT, layer[1], layer[1])
            tex:SetAnchor(BOTTOMRIGHT, row, BOTTOMRIGHT, -layer[1], -layer[1])
            tex:SetDrawLevel(1)
            tex:SetMouseEnabled(false)
            Paint(tex, layer[2])
            tex:SetHidden(true)
            row.igFGLayers[index] = tex
        end
        local white = WINDOW_MANAGER:CreateControl(nil, row, CT_TEXTURE)
        white:SetAnchorFill(row)
        white:SetDrawLevel(2)
        white:SetColor(1, 1, 1, 1)
        white:SetAlpha(0.14)
        white:SetMouseEnabled(false)
        white:SetHidden(true)
        row.igFGWhite = white
        -- The row's own pieces stand above the wash so the name stays readable.
        row.swatch:SetDrawLevel(5)
        row.name:SetDrawLevel(5)
        row.count:SetDrawLevel(5)
        row.rule:SetDrawLevel(5)
    end
    return row
end

local function Apply(body)
    if not body.igBoxes then return end
    local state = State(body)
    for _, pipe in ipairs(state.bridges) do
        pipe:SetHidden(true)
        pipe.white:SetHidden(true)
    end
    state.used.bridges, state.hover = 0, nil
    for _, row in ipairs(body.igRows or {}) do
        RowWash(row)
        row.igFGSet = nil
        row.igFGWhite:SetHidden(true)
        for _, tex in ipairs(row.igFGLayers) do tex:SetHidden(true) end
    end

    for _, box in ipairs(body.igBoxes) do Wire(body, box, function(self) return self.igSetId end) end
    for _, row in ipairs(body.igRows or {}) do Wire(body, row, function(self) return self.igSetId end) end

    local full = body.igFullSets
    if not (Enabled() and full and next(full)) then return end

    -- The legend lines of full sets.
    for _, row in ipairs(body.igRows or {}) do
        if not row:IsHidden() and row.igSetId and full[row.igSetId] then
            row.igFGSet = row.igSetId
            for _, tex in ipairs(row.igFGLayers) do tex:SetHidden(false) end
        end
    end

    -- Boxes of each full set in figure order (the drawer's own list: armour, jewellery, then
    -- the bars), with the centres and sizes the drawer gave them (its own anchor offsets, the
    -- same units the pipes are placed in).
    -- The back bar does not count toward a set bonus: its weapons never take part. The front
    -- bar's do, so a weapon of the set is piped to the rest of it.
    local skip = {}
    local back = body.igWeapons and body.igWeapons[2]
    if back then skip[back.main] = true; skip[back.off] = true end
    local bySet, shown = {}, {}
    for _, box in ipairs(body.igBoxes) do
        if not box:IsHidden() then
            local ok, _, _, _, _, x, y = pcall(box.GetAnchor, box, 0)
            if ok and x and y then
                local w, h = box:GetDimensions()
                local item = { box = box, x = x, y = y, w = w, h = h }
                shown[#shown + 1] = item
                local id = box.igSetId
                if id and full[id] and box.igLink and not skip[box] then
                    local list = bySet[id]
                    if not list then list = {}; bySet[id] = list end
                    list[#list + 1] = item
                end
            end
        end
    end

    -- How many boxes other than a and b a straight segment runs over.
    local function Crossings(x1, y1, x2, y2, a, b)
        local lx, hx = zo_min(x1, x2), zo_max(x1, x2)
        local ly, hy = zo_min(y1, y2), zo_max(y1, y2)
        local count = 0
        for _, item in ipairs(shown) do
            if item ~= a and item ~= b
                and lx <= item.x + item.w / 2 and hx >= item.x - item.w / 2
                and ly <= item.y + item.h / 2 and hy >= item.y - item.h / 2 then
                count = count + 1
            end
        end
        return count
    end

    for id, list in pairs(bySet) do
        local box = list[1].box
        local r, g, b = GREEN[1], GREEN[2], GREEN[3]
        if box.fill and box.fill.GetColor then r, g, b = box.fill:GetColor() end
        local function Segment(x1, y1, x2, y2)
            if math.abs(x1 - x2) < 0.5 and math.abs(y1 - y2) < 0.5 then return end
            local pipe = Take(body)
            pipe:SetColor(r, g, b, 1)
            pipe:SetAlpha(PIPE_ALPHA)
            pipe:SetDimensions(zo_max(PIPE, math.abs(x2 - x1)), zo_max(PIPE, math.abs(y2 - y1)))
            pipe:SetAnchor(CENTER, body, TOP, (x1 + x2) / 2, (y1 + y2) / 2)
            pipe.igSetId = id
        end
        for index = 2, #list do
            local p, q = list[index - 1], list[index]
            if math.abs(p.x - q.x) < 0.5 or math.abs(p.y - q.y) < 0.5 then
                Segment(p.x, p.y, q.x, q.y)
            else
                -- Across then down, or down then across: whichever runs over fewer boxes.
                local across = Crossings(p.x, p.y, q.x, p.y, p, q) + Crossings(q.x, p.y, q.x, q.y, p, q)
                local down = Crossings(p.x, p.y, p.x, q.y, p, q) + Crossings(p.x, q.y, q.x, q.y, p, q)
                if across <= down then
                    Segment(p.x, p.y, q.x, p.y); Segment(q.x, p.y, q.x, q.y)
                else
                    Segment(p.x, p.y, p.x, q.y); Segment(p.x, q.y, q.x, q.y)
                end
            end
        end
    end
end

local wrapped = IG.RefreshEquippedDrawer
if wrapped then
    IG.RefreshEquippedDrawer = function(body)
        wrapped(body)
        local ok, err = pcall(Apply, body)
        if not ok and IG.sv and IG.sv.debug then d("[I2] full set glow: " .. tostring(err)) end
    end
end
