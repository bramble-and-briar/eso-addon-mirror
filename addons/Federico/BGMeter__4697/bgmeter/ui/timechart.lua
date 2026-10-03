BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local K = BGMeter.Constants
local P = BGMeter.Plot.primitives
local S = BGMeter.Plot.style
local F = BGMeter.Format

local TC = {}
TC.__index = TC

local MAX_SERIES = 3

local function slot(x, s) return (x - 1) * MAX_SERIES + s end

function TC.new(parent, label)
    local self = setmetatable({}, TC)
    self.root = BGMeter.zenimax.ui.create_control(nil, parent, CT_CONTROL)
    self.bg = P.rect(self.root, { 0, 0, 0, 0.35 })
    self.bg:SetAnchorFill(self.root)
    local probe = P.line(self.root, { 1, 1, 1, 1 }, 2)
    if probe then
        probe:SetHidden(true)
        self.line_pool = BGMeter.Plot.pool.new(
            function() return P.line(self.root, { 1, 1, 1, 1 }, 2) end,
            function(ln) ln:SetHidden(true); ln:ClearAnchors() end)
        self.line_pool.label = label .. ".lines"
    end
    self.dot_pool = BGMeter.Plot.pool.new(
        function() return P.rect(self.root, { 1, 1, 1, 1 }) end,
        function(r) r:SetHidden(true); r:ClearAnchors() end)
    self.dot_pool.label = label .. ".dots"
    self.cursor = P.rect(self.root, { K.COLOR.gold[1], K.COLOR.gold[2], K.COLOR.gold[3], 0.8 })
    self.cursor:SetWidth(1)
    self.cursor:SetHidden(true)
    self.legend = P.label(self.root, S.FONT.small, K.COLOR.text)
    self.legend:SetAnchor(TOPRIGHT, self.root, TOPRIGHT, -3, 1)
    self.legend:SetHeight(12)
    self.legend:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    self.w, self.h = 0, 0
    self.n, self.cols, self.drawn, self.shown, self.max, self.tspan = 0, 0, 0, 0, 0, 0
    self.series, self.col, self.ctl = {}, {}, {}
    self.nseries, self.k = 0, 0
    self.t, self.legendIdx = nil, nil
    return self
end

function TC:set_data(data)
    self.data = data
    local n = (data and data.t) and (data.n or #data.t) or 0
    self.n = n
    self.nseries, self.k = 0, 0
    for s = 1, MAX_SERIES do
        local src = data and data.series and data.series[s]
        self.series[s] = src
        if src then self.nseries = s; self.k = self.k + 1 end
    end
    self.max = (data and data.max) or 0
    self.tspan = (n > 0 and data.t[n]) or 0
    self.fmt = data and data.fmt or nil
    self:reset()
end

function TC:set_series(tl)
    if not tl or not tl.t or not tl.teams then self:set_data(nil) return end
    local series, max = {}, 0
    local arrays = { tl.s1, tl.s2, tl.s3 }
    for s = 1, MAX_SERIES do
        local team, arr = tl.teams[s], arrays[s]
        if team and arr then
            series[#series + 1] = { values = arr, color = S.team_color(team) }
            for i = 1, #tl.t do
                local v = arr[i] or 0
                if v > max then max = v end
            end
        end
    end
    self:set_data({ n = #tl.t, t = tl.t, series = series, max = max })
end

function TC:layout(w, h)
    if w == self.w and h == self.h then return end
    self.w, self.h = w, h
    self.root:SetDimensions(w, h)
    self:reset()
end

local function release(self)
    if self.line_pool then self.line_pool:release_all() end
    self.dot_pool:release_all()
    for i = 1, #self.ctl do self.ctl[i] = false end
    self.drawn, self.shown = 0, 0
end

function TC:reset()
    release(self)
    self.t, self.legendIdx = nil, nil
    self.cursor:SetHidden(true)
    self.legend:SetText("")
    local n, plot_w = self.n, self.w - 1
    if n < 2 or plot_w < 2 or self.tspan <= 0 or self.max <= 0 or self.nseries == 0 then self.cols = 0 return end
    local t, col = self.data.t, self.col
    local i = 1
    for x = 0, plot_w do
        local tx = (x / plot_w) * self.tspan
        while i < n and (t[i + 1] or 0) <= tx do i = i + 1 end
        col[x + 1] = i
    end
    self.cols = plot_w + 1
    for i = #self.ctl + 1, plot_w * MAX_SERIES do self.ctl[i] = false end
end

local function y_of(self, s, idx)
    local v = (self.series[s].values[idx]) or 0
    return math.floor((1 - v / self.max) * (self.h - 1) + 0.5)
end

local function color_of(self, sr, idx)
    local lut = sr.lut
    if not lut then return sr.color end
    local v = sr.values[idx] or 0
    local k = 1 + math.floor((v / self.max) * (#lut - 1) + 0.5)
    if k < 1 then k = 1 elseif k > #lut then k = #lut end
    return lut[k]
end

local function draw_segment(self, x, s)
    local sr = self.series[s]
    local x0, y0, x1, y1 = x - 1, y_of(self, s, self.col[x]), x, y_of(self, s, self.col[x + 1])
    local tc = color_of(self, sr, self.col[x + 1])
    if self.line_pool then
        local ln = self.line_pool:acquire()
        ln:ClearAnchors()
        ln:SetAnchor(TOPLEFT, self.root, TOPLEFT, x0, y0)
        ln:SetAnchor(TOPRIGHT, self.root, TOPLEFT, x1, y1)
        ln:SetColor(tc[1], tc[2], tc[3], 0.9)
        ln:SetHidden(false)
        return ln
    end
    local dot = self.dot_pool:acquire()
    dot:ClearAnchors()
    dot:SetAnchor(TOPLEFT, self.root, TOPLEFT, x1, y1)
    dot:SetDimensions(2, 2)
    P.set_rect_color(dot, { tc[1], tc[2], tc[3], 0.9 })
    dot:SetHidden(false)
    return dot
end

local function show_to(self, xT)
    local ctl = self.ctl
    if xT > self.shown then
        local upto = math.min(xT, self.drawn)
        for x = self.shown + 1, upto do
            for s = 1, self.nseries do
                local c = ctl[slot(x, s)]
                if c then c:SetHidden(false) end
            end
        end
        for x = self.drawn + 1, xT do
            for s = 1, self.nseries do
                if self.series[s] then ctl[slot(x, s)] = draw_segment(self, x, s) end
            end
        end
        if xT > self.drawn then self.drawn = xT end
    elseif xT < self.shown then
        for x = xT + 1, self.shown do
            for s = 1, self.nseries do
                local c = ctl[slot(x, s)]
                if c then c:SetHidden(true) end
            end
        end
    end
    self.shown = xT
end

function TC:set_time(t)
    if self.cols == 0 then return end
    local plot_w = self.cols - 1
    t = math.max(0, math.min(self.tspan, t or self.tspan))
    local xT = math.floor(t / self.tspan * plot_w + 0.5)
    show_to(self, xT)
    self.t = t
    self.cursor:ClearAnchors()
    self.cursor:SetAnchor(TOPLEFT, self.root, TOPLEFT, xT, 0)
    self.cursor:SetHeight(self.h)
    self.cursor:SetHidden(false)
    local idx = self.col[xT + 1] or 1
    if idx == self.legendIdx then return end
    self.legendIdx = idx
    local text = ""
    for s = 1, self.nseries do
        local sr = self.series[s]
        if sr then
            local v = sr.values[idx] or 0
            local shown = self.fmt and self.fmt(v) or tostring(math.floor(v + 0.5))
            text = text .. ((text ~= "") and "  " or "") .. string.format("|c%s%s|r", F.hexc(color_of(self, sr, idx)), shown)
        end
    end
    self.legend:SetText(text)
end

function TC:count()
    return self.shown * self.k
end

function TC:acquired()
    return (self.line_pool and self.line_pool:active_count() or 0) + self.dot_pool:active_count()
end

function TC:segments_at(t)
    if self.cols == 0 then return 0 end
    local plot_w = self.cols - 1
    t = math.max(0, math.min(self.tspan, t or self.tspan))
    local xT = math.floor(t / self.tspan * plot_w + 0.5)
    return xT * self.k
end

BGMeter.UI.timechart = TC
