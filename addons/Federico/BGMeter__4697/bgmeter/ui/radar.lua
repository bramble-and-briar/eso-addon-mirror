BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local K = BGMeter.Constants
local P = BGMeter.Plot.primitives
local S = BGMeter.Plot.style

local R = {}
R.__index = R

local MAX_SERIES = 2
local MAX_AXES = 8
local FAN = 60
local LABEL_R = 1.18
local MARGIN = 10
local LABEL_W = 56
local LABEL_H = 14
local TWO_PI = 2 * math.pi

function R.new(parent, label)
    local self = setmetatable({}, R)
    self.root = BGMeter.zenimax.ui.create_control(nil, parent, CT_CONTROL)
    local probe = P.line(self.root, { 1, 1, 1, 1 }, 2)
    if probe then
        probe:SetHidden(true)
        self.line_pool = BGMeter.Plot.pool.new(
            function() return P.line(self.root, { 1, 1, 1, 1 }, 2) end,
            function(ln) ln:SetHidden(true); ln:ClearAnchors() end)
        self.line_pool.label = (label or "radar") .. ".lines"
    end
    self.dot_pool = BGMeter.Plot.pool.new(
        function() return P.rect(self.root, { 1, 1, 1, 1 }) end,
        function(r) r:SetHidden(true); r:ClearAnchors() end)
    self.dot_pool.label = (label or "radar") .. ".dots"
    self.labels = {}
    self.axes, self.n = {}, 0
    self.series = {}
    self.pts = {}
    for s = 1, MAX_SERIES do
        self.pts[s] = {}
        for i = 1, MAX_AXES do self.pts[s][i] = { 0, 0 } end
    end
    self.w, self.h, self.cx, self.cy, self.r = 0, 0, 0, 0, 0
    self.lines = 0
    self.em1, self.em2 = nil, nil
    return self
end

function R:set_axes(names)
    local n = math.min(#names, MAX_AXES)
    for i = 1, n do self.axes[i] = names[i] end
    for i = n + 1, #self.axes do self.axes[i] = nil end
    self.n = n
    self.r = fit_radius(self)
end

function R:clear_series()
    for s = 1, MAX_SERIES do self.series[s] = nil end
end

function R:set_emphasis(a, b)
    self.em1, self.em2 = a, b
end

function R:set_series(i, values, color, opts)
    if i < 1 or i > MAX_SERIES then return end
    self.series[i] = { v = values, color = color, fan = opts and opts.fan or false,
                       width = (opts and opts.width) or 2, alpha = (opts and opts.alpha) or 0.9 }
end

fit_radius = function(self)
    local n = self.n
    if n < 3 then return 0 end
    local xmax, ymax = 0, 0
    for i = 1, n do
        local a = -math.pi / 2 + (i - 1) * TWO_PI / n
        local x, y = math.abs(math.cos(a)), math.abs(math.sin(a))
        if x > xmax then xmax = x end
        if y > ymax then ymax = y end
    end
    local r = math.min(self.w, self.h) / 2 - MARGIN
    if xmax > 0 then r = math.min(r, (self.w / 2 - LABEL_W / 2 - 2) / (LABEL_R * xmax)) end
    if ymax > 0 then r = math.min(r, (self.h / 2 - LABEL_H / 2 - 2) / (LABEL_R * ymax)) end
    return math.max(0, r)
end

function R:layout(w, h)
    self.w, self.h = w, h
    self.root:SetDimensions(w, h)
    self.cx, self.cy = w / 2, h / 2
    self.r = fit_radius(self)
end

local fit_radius

local function point(self, i, v)
    local a = -math.pi / 2 + (i - 1) * TWO_PI / self.n
    return self.cx + math.cos(a) * self.r * v, self.cy + math.sin(a) * self.r * v
end

local function seg(self, x0, y0, x1, y1, color, alpha, width)
    if not self.line_pool then return end
    local ln = self.line_pool:acquire()
    ln:ClearAnchors()
    ln:SetAnchor(TOPLEFT, self.root, TOPLEFT, x0, y0)
    ln:SetAnchor(TOPRIGHT, self.root, TOPLEFT, x1, y1)
    if ln.SetThickness then ln:SetThickness(width) end
    ln:SetColor(color[1], color[2], color[3], alpha)
    ln:SetHidden(false)
    self.lines = self.lines + 1
end

local function dot(self, x, y, color, size)
    local d = self.dot_pool:acquire()
    d:ClearAnchors()
    d:SetAnchor(CENTER, self.root, TOPLEFT, x, y)
    d:SetDimensions(size, size)
    P.set_rect_color(d, { color[1], color[2], color[3], 1 })
    d:SetHidden(false)
end

local function ring(self, v, alpha)
    local grid = K.COLOR.text_dim
    local x0, y0 = point(self, 1, v)
    for i = 1, self.n do
        local j = (i % self.n) + 1
        local x1, y1 = point(self, j, v)
        seg(self, x0, y0, x1, y1, grid, alpha, 1)
        x0, y0 = x1, y1
    end
end

local function draw_series(self, s)
    local sr = self.series[s]
    if not sr then return end
    local n, pts = self.n, self.pts[s]
    for i = 1, n do
        local v = sr.v[i] or 0
        if v < 0 then v = 0 elseif v > 1 then v = 1 end
        local x, y = point(self, i, v)
        pts[i][1], pts[i][2] = x, y
    end
    if sr.fan then
        for k = 0, FAN - 1 do
            local t = k / FAN * n
            local i = math.floor(t) + 1
            local j = (i % n) + 1
            local f = t - (i - 1)
            local x = pts[i][1] + (pts[j][1] - pts[i][1]) * f
            local y = pts[i][2] + (pts[j][2] - pts[i][2]) * f
            seg(self, self.cx, self.cy, x, y, sr.color, 0.16, 1)
        end
    end
    for i = 1, n do
        local j = (i % n) + 1
        seg(self, pts[i][1], pts[i][2], pts[j][1], pts[j][2], sr.color, sr.alpha, sr.width)
    end
    if sr.width >= 2 then
        for i = 1, n do dot(self, pts[i][1], pts[i][2], sr.color, 5) end
    end
end

function R:clear()
    if self.line_pool then self.line_pool:release_all() end
    self.dot_pool:release_all()
    for i = 1, #self.labels do self.labels[i]:SetHidden(true) end
    self.lines = 0
end

function R:render()
    self:clear()
    local n = self.n
    if n < 3 or self.r < 8 then return end
    local grid = K.COLOR.text_dim
    for i = 1, n do
        local x, y = point(self, i, 1)
        seg(self, self.cx, self.cy, x, y, grid, 0.35, 1)
    end
    ring(self, 0.5, 0.25)
    ring(self, 1, 0.45)
    for s = 1, MAX_SERIES do draw_series(self, s) end
    for i = 1, n do
        local lbl = self.labels[i]
        if not lbl then
            lbl = P.label(self.root, S.FONT.small, K.COLOR.text_dim)
            lbl:SetDimensions(LABEL_W, LABEL_H)
            lbl:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
            self.labels[i] = lbl
        end
        local x, y = point(self, i, LABEL_R)
        lbl:ClearAnchors()
        lbl:SetAnchor(CENTER, self.root, TOPLEFT, x, y)
        lbl:SetText(self.axes[i])
        local em = (i == self.em1 or i == self.em2) and K.COLOR.gold or K.COLOR.text_dim
        lbl:SetColor(em[1], em[2], em[3], 1)
        lbl:SetHidden(false)
    end
end

function R:points(s) return self.pts[s] end
function R:count() return self.lines end
function R:axis_count() return self.n end

BGMeter.UI.radar = R
