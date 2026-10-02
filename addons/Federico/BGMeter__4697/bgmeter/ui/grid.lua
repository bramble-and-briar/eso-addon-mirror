BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local Grid = {}
Grid.__index = Grid

local GAP = 8

function Grid.new(spec)
    local self = setmetatable({}, Grid)
    self.columns = spec.columns
    self.left = spec.left or 50
    self.right = spec.right or 10
    self.name_min = spec.name_min or 96
    self.enabled = {}
    self.x, self.w, self.shown = {}, {}, {}
    self.order = {}
    self.key = nil
    self.width = 0
    self.name_right = 0
    return self
end

function Grid:set_enabled(key, on)
    self.enabled[key] = on and true or false
end

function Grid:is_enabled(col)
    local e = self.enabled[col.key]
    if e == nil then return true end
    return e
end

function Grid:fixed_width()
    local total = self.right
    for _, c in ipairs(self.columns) do
        if self:is_enabled(c) then total = total + c.w + GAP end
    end
    return total
end

function Grid:layout(width)
    local cols = {}
    for _, c in ipairs(self.columns) do
        if self:is_enabled(c) then cols[#cols + 1] = c end
    end
    local function name_width()
        local total = 0
        for _, c in ipairs(cols) do total = total + c.w + GAP end
        return width - self.left - self.right - total
    end
    while #cols > 0 and name_width() < self.name_min do
        local drop, at = nil, 0
        for i, c in ipairs(cols) do
            if drop == nil or (c.priority or 50) < (drop.priority or 50) then drop, at = c, i end
        end
        table.remove(cols, at)
    end
    local parts = {}
    for _, c in ipairs(cols) do parts[#parts + 1] = c.key end
    local key = tostring(width) .. "|" .. table.concat(parts, ",")
    if key == self.key then return false end
    self.key, self.width = key, width
    for _, c in ipairs(self.columns) do self.shown[c.key] = false end
    local right = width - self.right
    for i = #cols, 1, -1 do
        local c = cols[i]
        self.w[c.key] = c.w
        self.x[c.key] = right - c.w
        self.shown[c.key] = true
        right = right - c.w - GAP
    end
    self.name_right = width - right
    self.order = cols
    return true
end

function Grid:is_shown(key)
    return self.shown[key] == true
end

function Grid:first_shown()
    return self.order[1]
end

function Grid:apply_header(headers, parent)
    for _, c in ipairs(self.columns) do
        local lbl = headers[c.key]
        if lbl then
            lbl:ClearAnchors()
            if self.shown[c.key] then
                lbl:SetAnchor(TOPLEFT, parent, TOPLEFT, self.x[c.key], 0)
                lbl:SetWidth(self.w[c.key])
                lbl:SetHidden(false)
            else
                lbl:SetHidden(true)
            end
        end
    end
end

function Grid:apply_row(row)
    for _, c in ipairs(self.columns) do
        local cell = row.cells[c.key]
        if cell then
            cell:ClearAnchors()
            if self.shown[c.key] then
                cell:SetAnchor(LEFT, row.container, LEFT, self.x[c.key], 0)
                cell:SetWidth(self.w[c.key])
                cell:SetHidden(false)
            else
                cell:SetHidden(true)
            end
        end
    end
    if row.name then
        row.name:ClearAnchors()
        row.name:SetAnchor(LEFT, row.container, LEFT, self.left, 0)
        row.name:SetAnchor(RIGHT, row.container, RIGHT, -self.name_right, 0)
    end
    row.layoutKey = self.key
end

BGMeter.UI.Grid = Grid
