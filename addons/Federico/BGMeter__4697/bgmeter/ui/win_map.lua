BGMeter = BGMeter or {}
local BGMeter = BGMeter
BGMeter.UI = BGMeter.UI or {}

local U = BGMeter.UI._win
local W = U.W
local TX = U.TX
local set_text, mk_button, team_name, hexc = U.set_text, U.mk_button, U.team_name, U.hexc

local K = BGMeter.Constants
local L = BGMeter.Constants.LAYOUT
local F = BGMeter.Format
local P = BGMeter.Plot.primitives
local S = BGMeter.Plot.style
local Prof = BGMeter.Prof
local Prefs = BGMeter.Prefs
local Sound = BGMeter.Sound
local Scene = BGMeter.zenimax.scene

local M = {}

local PAD = 16
local SCRUB_H = 26
local LEGEND_W = 260
local HEAD_H = 34
local MIN_SIDE = 418
local BINS = 32
local WHEEL_MS = 5000
local SKULL = "EsoUI/Art/TargetMarkers/Target_White_Skull_64.dds"
local PIP_MATE = "EsoUI/Art/MapPins/UI-WorldMapGroupPip.dds"
local PIP_ME = PIP_MATE
local DOCK_SNAP = 48
local FALLBACK_PIN = "EsoUI/Art/MapPins/battlegrounds_murderball_neutral.dds"
local FALLBACK_AREA = "EsoUI/Art/MapPins/battlegrounds_capturePoint_pin_neutral.dds"
local LV = { tile = 1, heat = 2, halo = 3, path = 4, mark = 5, hit = 6 }

local LAYERS = {
    { key = "map_path",   label = "Your path",  tip = "Where you went, up to this second" },
    { key = "map_team",   label = "Team paths", tip = "Your teammates' paths" },
    { key = "map_deaths", label = "Deaths",     tip = "Red: where you died  ·  gold: where you got a kill" },
    { key = "map_pins",   label = "Objectives", tip = "Flags, relics and balls at this second" },
}
local HEAT_MODES = { { key = "presence", label = "PRESENCE", tip = "Where your team spent its time" },
                     { key = "deaths",   label = "DEATHS",   tip = "Where you died and got kills" } }

local VIRIDIS = {
    { 0.27, 0.00, 0.33 }, { 0.28, 0.14, 0.46 }, { 0.24, 0.29, 0.54 }, { 0.19, 0.41, 0.56 },
    { 0.13, 0.57, 0.55 }, { 0.21, 0.72, 0.47 }, { 0.53, 0.83, 0.29 }, { 0.99, 0.91, 0.14 },
}
local EMBER = {
    { 0.20, 0.02, 0.10 }, { 0.45, 0.05, 0.15 }, { 0.72, 0.12, 0.12 }, { 0.90, 0.35, 0.10 },
    { 0.98, 0.62, 0.15 }, { 1.00, 0.85, 0.40 }, { 1.00, 0.97, 0.75 }, { 1.00, 1.00, 1.00 },
}

local function ramp(lut, u)
    u = math.max(0, math.min(1, u))
    local pos = u * (#lut - 1) + 1
    local i = math.floor(pos)
    local f = pos - i
    local a, b = lut[i], lut[math.min(#lut, i + 1)]
    return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, a[3] + (b[3] - a[3]) * f
end

local built = false
local c = nil
local state = { m = nil, geo = nil, t = nil, side = 0, applying = false, race = nil, docked = true, heatKey = nil, tcM = nil, fromChart = false }
local LAY_H = 30 + 24 + 2 * 24 + 6
local NOW_H = 30 + 4 * 16 + 8
local CHART_Y = 48 + LAY_H + 10 + NOW_H + 10
local CARD_H = 96
local CARD_GAP = 8
local HINT_H = 18
local CARDS = {
    { key = "score",    title = "SCORE  ·  TO THIS SECOND", tip = "Team scores so far" },
    { key = "cohesion", title = "TEAM COHESION",            tip = "Team spread  ·  green together, red split" },
    { key = "solo",     title = "YOU AND THE TEAM",         tip = "Your distance to the team  ·  green with them, red alone" },
    { key = "kills",    title = "KILL PRESSURE",            tip = "Kills per minute, per team" },
    { key = "base",     title = "AT THE SPAWN",             tip = "Share of your team at the spawn  ·  wipes and AFKs show as peaks" },
    { key = "control",  title = "OBJECTIVES HELD",          tip = "Share of the objectives your team holds" },
}
local function pct(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end
local CHART_MIN_H = CARD_H
local COHESION_LUT = {}
do
    local steps = 24
    for k = 0, steps do
        local u = k / steps
        local r = (u < 0.5) and (2 * u) or 1
        local g = (u < 0.5) and 1 or (2 * (1 - u))
        COHESION_LUT[k + 1] = { 0.30 + 0.62 * r, 0.30 + 0.55 * g, 0.28 }
    end
end
local CONTROL_LUT = {}
for k = 1, #COHESION_LUT do CONTROL_LUT[k] = COHESION_LUT[#COHESION_LUT + 1 - k] end

local function sv_win()
    local sv = BGMeter.zenimax.savedvars.get()
    if not sv then return {} end
    sv.window = sv.window or {}
    sv.window.map = sv.window.map or { open = false, w = 0, h = 0, free = false, x = 0, y = 0 }
    return sv.window.map
end

local function pin_texture(ty, kind)
    local data = ZO_MapPin and ZO_MapPin.PIN_DATA and ty and ZO_MapPin.PIN_DATA[ty]
    if data and type(data.texture) == "string" then return data.texture end
    if kind == "area" then return FALLBACK_AREA end
    return FALLBACK_PIN
end

local function leveled_pool(make, level)
    return BGMeter.Plot.pool.new(
        function()
            local ctl = make()
            if ctl.SetDrawLevel then ctl:SetDrawLevel(level) end
            return ctl
        end,
        function(ctl) ctl:SetHidden(true); ctl:ClearAnchors() end)
end

local function gold(a) return { K.COLOR.gold[1], K.COLOR.gold[2], K.COLOR.gold[3], a } end

local function card(parent, y, h, heading)
    local box = BGMeter.zenimax.ui.create_control(nil, parent, CT_CONTROL)
    box:SetAnchor(TOPLEFT, c.map, TOPRIGHT, PAD, y)
    box:SetDimensions(LEGEND_W, h)
    local bg = P.rect(box, { 1, 1, 1, K.ALPHA.chart_bg })
    bg:SetAnchorFill(box)
    P.hairline_box(box, { K.COLOR.text_dim[1], K.COLOR.text_dim[2], K.COLOR.text_dim[3], K.ALPHA.chart_edge })
    local hd = P.label(box, S.FONT.small, K.COLOR.gold)
    hd:SetText(heading)
    hd:SetAnchor(TOPLEFT, box, TOPLEFT, 8, 5)
    hd:SetDimensions(LEGEND_W - 16, 14)
    local rule = P.rect(box, gold(0.22))
    rule:SetAnchor(TOPLEFT, box, TOPLEFT, 8, 22)
    rule:SetAnchor(TOPRIGHT, box, TOPRIGHT, -8, 22)
    rule:SetHeight(1)
    return box
end

local function segment(parent, text, w, tip, fn)
    local sg = {}
    sg.hit = BGMeter.zenimax.ui.create_control(nil, parent, CT_CONTROL)
    sg.hit:SetDimensions(w, 18)
    sg.hit:SetMouseEnabled(true)
    sg.bg = P.rect(sg.hit, gold(0.10))
    sg.bg:SetAnchorFill(sg.hit)
    sg.box = P.hairline_box(sg.hit, gold(0.45))
    sg.label = P.label(sg.hit, S.FONT.small, K.COLOR.gold)
    sg.label:SetAnchorFill(sg.hit)
    sg.label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    set_text(sg.label, text)
    sg.hit:SetHandler("OnMouseUp", function(_, _, upInside) if upInside then fn() end end)
    sg.hit:SetHandler("OnMouseEnter", function() if tip and U.card_show then U.card_show(sg.hit, BOTTOM, tip) end end)
    sg.hit:SetHandler("OnMouseExit", function() if U.card_hide then U.card_hide() end end)
    return sg
end

local function segment_set(sg, on)
    P.set_rect_color(sg.bg, gold(on and 0.42 or 0.08))
    S.color(sg.label, on and K.COLOR.bg or K.COLOR.gold)
    for _, e in pairs(sg.box) do P.set_rect_color(e, gold(on and 0.9 or 0.35)) end
end

local function dock()
    local win = c.win
    win:ClearAnchors()
    if W.win then win:SetAnchor(TOPLEFT, W.win, BOTTOMLEFT, 0, 4) else win:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0) end
    state.docked = true
    sv_win().free = false
end

local function float_at(x, y)
    local win = c.win
    win:ClearAnchors()
    win:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    state.docked = false
    local g = sv_win()
    g.free, g.x, g.y = true, x, y
end

function M.on_move_stop()
    if not built then return end
    local x, y = c.win:GetLeft(), c.win:GetTop()
    if W.win and math.abs(x - W.win:GetLeft()) <= DOCK_SNAP and math.abs(y - (W.win:GetBottom() + 4)) <= DOCK_SNAP then
        if not state.docked then Sound.play("nav") end
        dock()
    else
        float_at(x, y)
    end
end

function M.is_docked() return state.docked end

local function drag_poll()
    local cd = state.drag
    if not cd or not built or c.win:IsHidden() then return end
    local chart = cd.chart
    if chart.cols == 0 or chart.w < 2 then return end
    local A = BGMeter.zenimax.api
    if type(A.get_ui_mouse) ~= "function" then return end
    local mx = A.get_ui_mouse()
    local rel = mx - chart.root:GetLeft()
    if rel < 0 then rel = 0 elseif rel > chart.w - 1 then rel = chart.w - 1 end
    local t = (rel / (chart.w - 1)) * chart.tspan
    state.applying = true
    c.slider:SetValue(t)
    state.applying = false
    M.set_time(t, false)
end

local function drag_stop()
    if not state.drag then return end
    state.drag = nil
    BGMeter.zenimax.events.unregister_update("BGMeterCardDrag")
end

local function build()
    if built then return end
    local wm = BGMeter.zenimax.ui.wm
    local g = sv_win()
    local win = wm:CreateTopLevelWindow("BGMeterMapPanel")
    win:SetDimensions((g.w or 0) > 0 and g.w or L.map_w, (g.h or 0) > 0 and g.h or L.map_h)
    win:SetMouseEnabled(true)
    win:SetMovable(true)
    win:SetHandler("OnMoveStop", function() M.on_move_stop() end)
    win:SetClampedToScreen(true)
    win:SetHidden(true)
    win:SetDrawTier(DT_HIGH)
    win:SetResizeHandleSize(L.resize_h)
    win:SetDimensionConstraints(MIN_SIDE + LEGEND_W + 3 * PAD, MIN_SIDE + HEAD_H + 12 + PAD + SCRUB_H + 6, L.max_w, L.max_h)
    win:SetHandler("OnResizeStop", function()
        M.snap_size()
        M.render()
    end)
    win:SetHandler("OnMouseDoubleClick", function()
        local _, y = BGMeter.zenimax.api.get_ui_mouse()
        M.on_double_click(y)
    end)
    win:SetHandler("OnMouseWheel", function(_, delta) M.on_wheel(delta) end)
    Scene.register_top_level(win, function() M.close() end)
    c = { win = win }

    c.bg = P.rect(win, { K.COLOR.bg[1], K.COLOR.bg[2], K.COLOR.bg[3], 0.97 })
    c.bg:SetAnchorFill(win)
    c.art = P.icon(win)
    c.art:SetAnchor(TOPLEFT, win, TOPLEFT, 2, 2)
    c.art:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -2, -2)
    c.art:SetColor(1, 1, 1, K.ALPHA.map_art * 0.8)
    c.art:SetHidden(true)
    P.frame(win):SetAnchorFill(win)
    local strip = P.rect(win, K.COLOR.accent)
    strip:SetAnchor(TOPLEFT, win, TOPLEFT, 6, 6)
    strip:SetAnchor(TOPRIGHT, win, TOPRIGHT, -6, 6)
    strip:SetHeight(3)

    c.head = BGMeter.zenimax.ui.create_control(nil, win, CT_CONTROL)
    c.head:SetAnchor(TOPLEFT, win, TOPLEFT, 6, 9)
    c.head:SetAnchor(TOPRIGHT, win, TOPRIGHT, -6, 9)
    c.head:SetHeight(HEAD_H)
    c.headRule = P.rect(win, { 1, 1, 1, 0.08 })
    c.headRule:SetAnchor(TOPLEFT, c.head, BOTTOMLEFT, PAD - 6, 0)
    c.headRule:SetAnchor(TOPRIGHT, c.head, BOTTOMRIGHT, -(PAD - 6), 0)
    c.headRule:SetHeight(1)

    c.map = BGMeter.zenimax.ui.create_control(nil, win, CT_CONTROL)
    c.map:SetAnchor(TOPLEFT, win, TOPLEFT, PAD, HEAD_H + 12)
    c.map:SetMouseEnabled(true)
    c.map:SetHandler("OnMouseWheel", function(_, delta) M.on_wheel(delta) end)
    c.mapBg = P.rect(c.map, { 0, 0, 0, 0.7 })
    c.mapBg:SetAnchorFill(c.map)
    c.tiles = {}
    c.heat_pool = leveled_pool(function() return P.rect(c.map, { 1, 1, 1, 1 }) end, LV.heat)
    c.dot_pool = leveled_pool(function() return P.rect(c.map, { 1, 1, 1, 1 }) end, LV.mark)
    local probe = P.line(c.map, { 1, 1, 1, 1 }, 2)
    if probe then
        probe:SetHidden(true)
        c.line_pool = leveled_pool(function() return P.line(c.map, { 1, 1, 1, 1 }, 2) end, LV.path)
        c.team_pool = leveled_pool(function() return P.line(c.map, { 1, 1, 1, 1 }, 2) end, LV.path)
    end
    c.icon_pool = leveled_pool(function() return P.icon(c.map, "") end, LV.mark)
    c.heat_pool.label, c.dot_pool.label, c.icon_pool.label = "map.heat", "map.dots", "map.icons"
    if c.line_pool then c.line_pool.label, c.team_pool.label = "map.path", "map.team" end
    c.hit_pool = BGMeter.Plot.pool.new(
        function()
            local h = BGMeter.zenimax.ui.create_control(nil, c.map, CT_CONTROL)
            if h.SetDrawLevel then h:SetDrawLevel(LV.hit) end
            W.tip_dynamic(h)
            return h
        end,
        function(h) h:SetHidden(true); h:ClearAnchors(); W.tips[h] = nil end)
    c.mapBox = P.hairline_box(c.map, { K.COLOR.text_dim[1], K.COLOR.text_dim[2], K.COLOR.text_dim[3], K.ALPHA.chart_edge })
    for _, edge in pairs(c.mapBox) do if edge.SetDrawLevel then edge:SetDrawLevel(LV.hit) end end

    c.empty = P.label(c.map, S.FONT.small, K.COLOR.text_dim)
    c.empty:SetAnchor(CENTER, c.map, CENTER, 0, 0)
    c.empty:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    c.empty:SetText("this match was recorded before 0.4.0\nthere is no position data to draw")
    c.empty:SetHidden(true)
    if c.empty.SetDrawLevel then c.empty:SetDrawLevel(LV.hit) end

    c.emblem = P.icon(c.head, TX.map.n)
    c.emblem:SetDimensions(24, 24)
    c.emblem:SetAnchor(LEFT, c.head, LEFT, PAD - 6, 0)
    c.title = P.label(c.head, S.FONT.title, K.COLOR.text)
    c.title:SetText("MAP")
    c.title:SetAnchor(LEFT, c.emblem, RIGHT, 6, 0)
    c.sub = P.label(c.head, S.FONT.small, K.COLOR.text_dim)
    U.clamp_line(c.sub)
    c.sub:SetAnchor(LEFT, c.title, RIGHT, 10, 1)
    c.sub:SetAnchor(RIGHT, c.head, RIGHT, -40, 1)
    c.sub:SetHeight(16)
    c.close = mk_button(c.head, TX.close, 20, function() M.close() end, "Close")
    c.close:SetAnchor(RIGHT, c.head, RIGHT, -8, 0)

    c.layersCard = card(win, 48, LAY_H, "LAYERS")
    local y = 30
    c.heatRow = BGMeter.zenimax.ui.create_control(nil, c.layersCard, CT_CONTROL)
    c.heatRow:SetAnchor(TOPLEFT, c.layersCard, TOPLEFT, 8, y)
    c.heatRow:SetDimensions(LEGEND_W - 16, 22)
    c.heatRow:SetMouseEnabled(true)
    c.heatMark = P.rect(c.heatRow, K.COLOR.accent)
    c.heatMark:SetAnchor(LEFT, c.heatRow, LEFT, 0, 0)
    c.heatMark:SetDimensions(3, 14)
    c.heatLabel = P.label(c.heatRow, S.FONT.row, K.COLOR.text)
    c.heatLabel:SetAnchor(LEFT, c.heatRow, LEFT, 12, 0)
    c.heatLabel:SetHeight(22)
    set_text(c.heatLabel, "Heat")
    c.heatRow:SetHandler("OnMouseUp", function(_, _, upInside) if upInside then M.toggle_heat() end end)
    c.heatRow:SetHandler("OnMouseEnter", function() if U.card_show then U.card_show(c.heatRow, RIGHT, "Heat on / off") end end)
    c.heatRow:SetHandler("OnMouseExit", function() if U.card_hide then U.card_hide() end end)
    c.heatSeg = {}
    local segW = 66
    for i, mode in ipairs(HEAT_MODES) do
        local sg = segment(c.heatRow, mode.label, segW, mode.tip, function() M.set_heat_mode(mode.key) end)
        sg.hit:SetAnchor(RIGHT, c.heatRow, RIGHT, -(#HEAT_MODES - i) * (segW + 4), 0)
        sg.key = mode.key
        c.heatSeg[i] = sg
    end
    y = y + 24
    c.toggles = {}
    local colW = math.floor((LEGEND_W - 16) / 2)
    for i, lay in ipairs(LAYERS) do
        local t = {}
        t.hit = BGMeter.zenimax.ui.create_control(nil, c.layersCard, CT_CONTROL)
        t.hit:SetAnchor(TOPLEFT, c.layersCard, TOPLEFT, 8 + ((i - 1) % 2) * colW, y + math.floor((i - 1) / 2) * 24)
        t.hit:SetDimensions(colW - 4, 22)
        t.hit:SetMouseEnabled(true)
        t.mark = P.rect(t.hit, K.COLOR.accent)
        t.mark:SetAnchor(LEFT, t.hit, LEFT, 0, 0)
        t.mark:SetDimensions(3, 14)
        t.label = P.label(t.hit, S.FONT.row, K.COLOR.text)
        t.label:SetAnchor(LEFT, t.hit, LEFT, 12, 0)
        t.label:SetHeight(22)
        set_text(t.label, lay.label)
        t.value = P.label(t.hit, S.FONT.small, K.COLOR.text_dim)
        t.value:SetAnchor(RIGHT, t.hit, RIGHT, -4, 0)
        t.value:SetDimensions(26, 22)
        t.value:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        t.hit:SetHandler("OnMouseUp", function(_, _, upInside)
            if not upInside then return end
            Prefs.toggle(lay.key)
            Sound.play("nav")
            M.render()
        end)
        t.hit:SetHandler("OnMouseEnter", function() if U.card_show then U.card_show(t.hit, RIGHT, lay.tip) end end)
        t.hit:SetHandler("OnMouseExit", function() if U.card_hide then U.card_hide() end end)
        t.lay = lay
        c.toggles[i] = t
    end

    c.nowCard = card(win, 48 + LAY_H + 10, NOW_H, "AT THIS SECOND")
    c.nowLines = {}
    for i = 1, 4 do
        local l = P.label(c.nowCard, S.FONT.small, K.COLOR.text)
        l:SetAnchor(TOPLEFT, c.nowCard, TOPLEFT, 8, 28 + (i - 1) * 16)
        l:SetDimensions(LEGEND_W - 16, 16)
        U.clamp_line(l)
        c.nowLines[i] = l
    end

    c.cards = {}
    for i, spec in ipairs(CARDS) do
        local cd = { spec = spec, has = false }
        cd.box = card(win, CHART_Y + (i - 1) * (CARD_H + CARD_GAP), CARD_H, spec.title)
        cd.chart = BGMeter.UI.timechart.new(cd.box, "map." .. spec.key)
        cd.chart.root:SetAnchor(TOPLEFT, cd.box, TOPLEFT, 8, 28)
        cd.box:SetHidden(true)
        cd.box:SetMouseEnabled(true)
        cd.box:SetHandler("OnMouseEnter", function() if U.card_show then U.card_show(cd.box, LEFT, spec.tip) end end)
        cd.box:SetHandler("OnMouseExit", function() if U.card_hide then U.card_hide() end end)
        cd.box:SetHandler("OnMouseDown", function(_, button)
            if MOUSE_BUTTON_INDEX_LEFT and button and button ~= MOUSE_BUTTON_INDEX_LEFT then return end
            if U.card_hide then U.card_hide() end
            state.drag = cd
            drag_poll()
            BGMeter.zenimax.events.register_update("BGMeterCardDrag", 16, drag_poll)
        end)
        cd.box:SetHandler("OnMouseUp", function() drag_stop() end)
        c.cards[i] = cd
    end
    c.chartCard = c.cards[1].box
    c.timechart = c.cards[1].chart
    c.tc_line_pool = c.cards[1].chart.line_pool
    c.tc_cohesion = c.cards[2].chart.line_pool
    c.tc_solo = c.cards[3].chart.line_pool
    c.tc_kills = c.cards[4].chart.line_pool
    c.tc_base = c.cards[5].chart.line_pool
    c.tc_control = c.cards[6].chart.line_pool
    c.moreHint = P.label(win, S.FONT.small, K.COLOR.gold)
    c.moreHint:SetText("more cards below  ·  make the window taller")
    c.moreHint:SetDimensions(LEGEND_W, HINT_H)
    c.moreHint:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    c.moreHint:SetHidden(true)
    state.stack, state.shown, state.hidden = {}, 0, 0

    c.timeLabel = P.label(win, S.FONT.small, K.COLOR.gold)
    c.timeLabel:SetAnchor(BOTTOMLEFT, c.map, BOTTOMLEFT, 0, SCRUB_H)
    c.timeLabel:SetDimensions(56, 16)

    c.slider = BGMeter.zenimax.ui.create_from_virtual(nil, win, "ZO_Slider")
    c.slider:SetAnchor(BOTTOMLEFT, c.map, BOTTOMLEFT, 60, SCRUB_H - 2)
    c.slider:SetHeight(14)
    if c.slider.SetMinMax then c.slider:SetMinMax(0, 1) end
    c.slider:SetHandler("OnValueChanged", function(_, v)
        if state.applying then return end
        M.set_time(v, false)
    end)
    c.slider:SetHandler("OnMouseWheel", function(_, delta) M.on_wheel(delta) end)

    if g.free and (g.x or 0) ~= 0 then float_at(g.x, g.y) else dock() end
    built = true
end

local function side_for(w, h)
    return math.max(MIN_SIDE, math.min(w - LEGEND_W - 3 * PAD, h - HEAD_H - 12 - PAD - SCRUB_H - 6))
end

function M.snap_size()
    local win = c.win
    local side = side_for(win:GetWidth(), win:GetHeight())
    local w, h = side + LEGEND_W + 3 * PAD, side + HEAD_H + 12 + PAD + SCRUB_H + 6
    win:SetDimensions(w, h)
    local gg = sv_win()
    gg.w, gg.h = w, h
    return w, h
end

local function pulse_hint()
    if not built or c.moreHint:IsHidden() or not Prefs.get("animate") or state.pulsing then return end
    local Anim = BGMeter.Anim
    if not Anim or not Anim.value then return end
    state.pulsing = true
    local function down()
        Anim.value(1, 0.35, 900, function(a) if c.moreHint.SetAlpha then c.moreHint:SetAlpha(a) end end, function()
            if c.moreHint:IsHidden() then state.pulsing = false return end
            Anim.value(0.35, 1, 900, function(a) if c.moreHint.SetAlpha then c.moreHint:SetAlpha(a) end end, function()
                if c.moreHint:IsHidden() then state.pulsing = false return end
                down()
            end)
        end)
    end
    down()
end

local function place_cards(side)
    local stack = state.stack
    local n = 0
    for _, cd in ipairs(c.cards) do
        if cd.has then n = n + 1; stack[n] = cd end
    end
    for i = n + 1, #stack do stack[i] = nil end
    local avail = side + SCRUB_H + 6 - CHART_Y
    local shown = math.floor((avail + CARD_GAP) / (CARD_H + CARD_GAP))
    if shown > n then shown = n end
    if shown < n and shown > 0 and shown * (CARD_H + CARD_GAP) - CARD_GAP + HINT_H > avail then shown = shown - 1 end
    if shown < 0 then shown = 0 end
    state.shown, state.hidden = shown, n - shown
    for i, cd in ipairs(c.cards) do
        local at = nil
        for k = 1, shown do if stack[k] == cd then at = k end end
        if at then
            cd.box:ClearAnchors()
            cd.box:SetAnchor(TOPLEFT, c.map, TOPRIGHT, PAD, CHART_Y + (at - 1) * (CARD_H + CARD_GAP))
            cd.box:SetHidden(false)
        else
            cd.box:SetHidden(true)
        end
    end
    if n > shown then
        c.moreHint:ClearAnchors()
        c.moreHint:SetAnchor(TOPLEFT, c.map, TOPRIGHT, PAD, CHART_Y + shown * (CARD_H + CARD_GAP))
        c.moreHint:SetHidden(false)
        pulse_hint()
    else
        c.moreHint:SetHidden(true)
    end
end

local function layout()
    local win = c.win
    local side = side_for(win:GetWidth(), win:GetHeight())
    state.side = side
    c.map:SetDimensions(side, side)
    c.slider:SetWidth(math.max(40, side - 60))
    for _, cd in ipairs(c.cards) do cd.chart:layout(LEGEND_W - 16, CARD_H - 28 - 8) end
    place_cards(side)
    if W.map_art_path then
        c.art:SetTexture(W.map_art_path)
        c.art:SetHidden(false)
    else
        c.art:SetHidden(true)
    end
end

local function apply_tiles(m)
    local map = m.map
    local nx, ny = (map and map.nx) or 0, (map and map.ny) or 0
    local total = nx * ny
    for i = 1, math.max(total, #c.tiles) do
        local tile = c.tiles[i]
        if i <= total then
            if not tile then
                tile = P.icon(c.map, "")
                if tile.SetDrawLevel then tile:SetDrawLevel(LV.tile) end
                c.tiles[i] = tile
            end
            local col = (i - 1) % nx
            local row = math.floor((i - 1) / nx)
            local tw = state.side / nx
            tile:ClearAnchors()
            tile:SetAnchor(TOPLEFT, c.map, TOPLEFT, col * tw, row * tw)
            tile:SetDimensions(tw + 0.5, tw + 0.5)
            tile:SetTexture(map.tex and map.tex[i] or "")
            tile:SetColor(1, 1, 1, 0.92)
            tile:SetHidden(false)
        elseif tile then
            tile:SetHidden(true)
        end
    end
end

local function mx(v) return v / 1000 * state.side end

local function sz(base)
    local k = math.max(0.6, math.min(1.6, state.side / 380))
    return math.floor(base * k + 0.5)
end

local function polyline(pool, xs, ys, n, color, thick, alpha)
    if n < 2 then return end
    if not pool then
        for i = 1, n do
            local d = c.dot_pool:acquire()
            d:ClearAnchors()
            d:SetAnchor(CENTER, c.map, TOPLEFT, xs[i], ys[i])
            d:SetDimensions(thick + 1, thick + 1)
            P.set_rect_color(d, { color[1], color[2], color[3], alpha })
            d:SetHidden(false)
        end
        return
    end
    for i = 2, n do
        local ln = pool:acquire()
        ln:ClearAnchors()
        ln:SetAnchor(TOPLEFT, c.map, TOPLEFT, xs[i - 1], ys[i - 1])
        ln:SetAnchor(TOPRIGHT, c.map, TOPLEFT, xs[i], ys[i])
        ln:SetColor(color[1], color[2], color[3], alpha)
        if ln.SetThickness then ln:SetThickness(thick) end
        ln:SetHidden(false)
    end
end

local function present_span(series, upto)
    local first = nil
    for i = 1, upto do
        local x, y = series.x[i] or 0, series.y[i] or 0
        if x > 0 or y > 0 then
            first = i
            break
        end
    end
    return first
end

local SCR = { xs = {}, ys = {}, px = {}, py = {}, sx = {}, sy = {} }

local MAX_PATH_SEGMENTS = 1500

local function scaled(series, upto, smooth, sub)
    local xs, ys = SCR.xs, SCR.ys
    local first = present_span(series, upto)
    if not first then return xs, ys, 0 end
    local px, py = SCR.px, SCR.py
    local m = 0
    for i = first, upto do
        local x, y = series.x[i] or 0, series.y[i] or 0
        if x > 0 or y > 0 then m = m + 1; px[m], py[m] = x, y end
    end
    local n = 0
    if smooth and m >= 3 then
        local sx, sy, sn = BGMeter.Match.geo_spline(px, py, m, sub or 3, SCR.sx, SCR.sy)
        for i = 1, sn do xs[i], ys[i] = mx(sx[i]), mx(sy[i]) end
        n = sn
    else
        for i = 1, m do xs[i], ys[i] = mx(px[i]), mx(py[i]) end
        n = m
    end
    return xs, ys, n
end

local TEAM = { key = nil, n = 0, members = {} }

local function team_reset()
    TEAM.key, TEAM.n = nil, 0
    for _, mem in ipairs(TEAM.members) do
        for k = #mem.line, 1, -1 do mem.line[k] = nil end
        mem.shown, mem.total = 0, 0
    end
    if c.team_pool then c.team_pool:release_all() end
end

local function team_prepare(geo, m)
    local key = tostring(m) .. "|" .. tostring(m.capturedAt) .. "|" .. tostring(state.side)
    if TEAM.key == key then return end
    team_reset()
    TEAM.key = key
    local j = 0
    for name, s in pairs(geo.pos) do
        if name ~= geo.mine then
            j = j + 1
            local mem = TEAM.members[j]
            if not mem then
                mem = { line = {}, xs = {}, ys = {}, cum = {}, shown = 0, total = 0 }
                TEAM.members[j] = mem
            end
            local xs, ys, n = scaled(s, geo.n, false)
            for i = 1, n do mem.xs[i], mem.ys[i] = xs[i], ys[i] end
            for i = #mem.xs, n + 1, -1 do mem.xs[i], mem.ys[i] = nil, nil end
            local cnt = 0
            for i = 1, geo.n do
                local x, y = s.x[i] or 0, s.y[i] or 0
                if x > 0 or y > 0 then cnt = cnt + 1 end
                mem.cum[i] = cnt
            end
            for i = #mem.cum, geo.n + 1, -1 do mem.cum[i] = nil end
            mem.total = n
        end
    end
    TEAM.n = j
end

local function team_show(idx, tc)
    for j = 1, TEAM.n do
        local mem = TEAM.members[j]
        local pts = (idx > 0 and mem.cum[idx]) or 0
        if pts > mem.total then pts = mem.total end
        local want = math.max(0, pts - 1)
        if want > mem.shown then
            for k = mem.shown + 1, want do
                local ln = mem.line[k]
                if not ln then
                    ln = c.team_pool:acquire()
                    ln:ClearAnchors()
                    ln:SetAnchor(TOPLEFT, c.map, TOPLEFT, mem.xs[k], mem.ys[k])
                    ln:SetAnchor(TOPRIGHT, c.map, TOPLEFT, mem.xs[k + 1], mem.ys[k + 1])
                    ln:SetColor(tc[1], tc[2], tc[3], 0.45)
                    if ln.SetThickness then ln:SetThickness(1) end
                    mem.line[k] = ln
                end
                ln:SetHidden(false)
            end
        elseif want < mem.shown then
            for k = want + 1, mem.shown do mem.line[k]:SetHidden(true) end
        end
        mem.shown = want
    end
end

function M.team_state()
    local shown = 0
    for j = 1, TEAM.n do shown = shown + TEAM.members[j].shown end
    return { n = TEAM.n, shown = shown, acquired = c.team_pool and c.team_pool:active_count() or 0 }
end

local function release_all(keep_heat)
    if not keep_heat then c.heat_pool:release_all() end
    c.dot_pool:release_all()
    c.icon_pool:release_all()
    c.hit_pool:release_all()
end

local function draw_heat(geo, m, mode)
    local heat, lut
    if mode == "deaths" then
        heat, lut = BGMeter.Match.geo_heat_deaths(geo, m, BINS), EMBER
    else
        heat, lut = BGMeter.Match.geo_heat(geo, m, BINS), VIRIDIS
    end
    if not heat then return end
    local cell = state.side / BINS
    for by = 1, BINS do
        for bx = 1, BINS do
            local v = heat.grid[(by - 1) * BINS + bx]
            if v and v > 0 then
                local u = math.min(1, v / heat.cap)
                local r = c.heat_pool:acquire()
                r:ClearAnchors()
                r:SetAnchor(TOPLEFT, c.map, TOPLEFT, (bx - 1) * cell, (by - 1) * cell)
                r:SetDimensions(cell + 0.5, cell + 0.5)
                local cr, cg, cb = ramp(lut, u)
                P.set_rect_color(r, { cr, cg, cb, 0.12 + 0.70 * u ^ 0.6 })
                r:SetHidden(false)
            end
        end
    end
end

local function presized(n)
    local t = {}
    for i = 1, n do t[i] = 0 end
    for i = n, 1, -1 do t[i] = nil end
    return t
end

local PATH = { key = nil, xs = presized(MAX_PATH_SEGMENTS + 2), ys = presized(MAX_PATH_SEGMENTS + 2), cum = presized(1600),
               total = 0, m = 0, sub = 1, line = presized(MAX_PATH_SEGMENTS + 2), shown = 0 }

local function path_reset()
    PATH.key, PATH.total, PATH.m, PATH.sub, PATH.shown = nil, 0, 0, 1, 0
    for k = #PATH.line, 1, -1 do PATH.line[k] = nil end
    if c.line_pool then c.line_pool:release_all() end
end

local function path_sub(count)
    if count < 3 then return 1 end
    local sub = math.floor(MAX_PATH_SEGMENTS / count)
    if sub > 3 then sub = 3 end
    if sub < 1 then sub = 1 end
    return sub
end

local function path_prepare(geo, m)
    local me = geo.me
    local s = me or (geo.mine and geo.pos[geo.mine])
    if not s then
        path_reset()
        return nil
    end
    local n = me and me.n or geo.n
    local key = tostring(m) .. "|" .. tostring(m.capturedAt) .. "|" .. tostring(state.side) .. "|" .. (me and "me" or "pos")
    if PATH.key == key then return s end
    path_reset()
    PATH.key = key
    local smooth = me ~= nil
    local cnt = 0
    for i = 1, n do
        local x, y = s.x[i] or 0, s.y[i] or 0
        if x > 0 or y > 0 then cnt = cnt + 1 end
        PATH.cum[i] = cnt
    end
    for i = n + 1, #PATH.cum do PATH.cum[i] = nil end
    local sub = smooth and path_sub(cnt) or 1
    local xs, ys, total = scaled(s, n, smooth, sub)
    for i = 1, total do PATH.xs[i], PATH.ys[i] = xs[i], ys[i] end
    for i = total + 1, #PATH.xs do PATH.xs[i], PATH.ys[i] = nil, nil end
    PATH.total, PATH.m = total, cnt
    PATH.sub = (smooth and cnt >= 3) and sub or 1
    return s
end

local function path_segment(k)
    local l = PATH.line[k]
    if l then return l end
    local x0, y0, x1, y1 = PATH.xs[k], PATH.ys[k], PATH.xs[k + 1], PATH.ys[k + 1]
    l = c.line_pool:acquire()
    if l.SetDrawLevel then l:SetDrawLevel(LV.path) end
    l:ClearAnchors()
    l:SetAnchor(TOPLEFT, c.map, TOPLEFT, x0, y0)
    l:SetAnchor(TOPRIGHT, c.map, TOPLEFT, x1, y1)
    l:SetColor(K.COLOR.you[1], K.COLOR.you[2], K.COLOR.you[3], 1)
    if l.SetThickness then l:SetThickness(3) end
    PATH.line[k] = l
    return l
end

local PATH_STEP = 40
local SHOW_STEP = 240
local path_show
local path_pending = false

local function path_continue()
    path_pending = false
    if not built or c.win:IsHidden() or not state.geo or PATH.key == nil or PATH.upto == nil then return end
    path_show(PATH.upto)
end

path_show = function(upto)
    PATH.upto = upto
    local mt = PATH.cum[upto] or 0
    local pts
    if mt <= 0 then pts = 0
    elseif mt >= PATH.m then pts = PATH.total
    else pts = (mt - 1) * PATH.sub + 1 end
    local want = math.max(0, pts - 1)
    if want > PATH.shown then
        local made, shown = 0, 0
        local k = PATH.shown + 1
        while k <= want do
            if not PATH.line[k] then
                made = made + 1
                if made > PATH_STEP then break end
            end
            if shown >= SHOW_STEP then break end
            path_segment(k):SetHidden(false)
            shown = shown + 1
            k = k + 1
        end
        PATH.shown = k - 1
        if k <= want and not path_pending then
            path_pending = true
            if type(zo_callLater) == "function" then zo_callLater(path_continue, 0) else path_continue() end
        end
        return
    elseif want < PATH.shown then
        for k = want + 1, PATH.shown do
            PATH.line[k]:SetHidden(true)
        end
    end
    PATH.shown = want
end

function M.path_step() return PATH_STEP end
function M.show_step() return SHOW_STEP end

local function draw_paths(geo, m, idx, t)
    local mine = geo.mine
    if Prefs.get("map_team") then
        local tc = S.team_color(m.localTeam)
        if c.team_pool then
            team_prepare(geo, m)
            team_show(idx, tc)
        else
            for name, s in pairs(geo.pos) do
                if name ~= mine then
                    local xs, ys, n = scaled(s, idx, false)
                    polyline(nil, xs, ys, n, tc, 1, 0.45)
                end
            end
        end
    elseif TEAM.n > 0 then
        team_show(0, nil)
    end
    if not Prefs.get("map_path") then
        if PATH.shown > 0 then path_show(0) end
        return
    end
    local me = geo.me
    local upto = me and BGMeter.Match.geo_index_of(me.t, me.n, t) or idx
    if not c.line_pool then
        local s = me or (mine and geo.pos[mine])
        if s then
            local xs, ys, n = scaled(s, upto, me ~= nil)
            polyline(nil, xs, ys, n, K.COLOR.you, 3, 1)
        end
        return
    end
    if path_prepare(geo, m) then path_show(upto) end
end

function M.path_state() return PATH end

local function draw_deaths(geo, m, t)
    for _, k in ipairs(m.killfeed or {}) do
        if k.x and k.y and k.kind and (k.t or 0) <= t then
            local ic = c.icon_pool:acquire()
            ic:SetTexture(SKULL)
            local col = (k.kind == "kill") and K.COLOR.gold or K.COLOR.accent
            ic:SetColor(col[1], col[2], col[3], 1)
            ic:SetDimensions(sz(18), sz(18))
            ic:ClearAnchors()
            ic:SetAnchor(CENTER, c.map, TOPLEFT, mx(k.x), mx(k.y))
            ic:SetHidden(false)
            local hit = c.hit_pool:acquire()
            hit:ClearAnchors()
            hit:SetAnchorFill(ic)
            hit:SetHidden(false)
            W.tips[hit] = (k.kind == "kill")
                and string.format("you killed %s  @ %s", tostring(k.dn), F.duration(k.t or 0))
                or string.format("%s killed you  @ %s", tostring(k.kn), F.duration(k.t or 0))
        end
    end
end

local function draw_pins(geo, idx)
    for _, pin in ipairs(geo.pins) do
        local x, y = pin.x[idx], pin.y[idx]
        if x and y and (x > 0 or y > 0) then
            local ic = c.icon_pool:acquire()
            ic:SetTexture(pin_texture(pin.ty[idx], pin.kind))
            ic:SetColor(1, 1, 1, 1)
            ic:SetDimensions(sz(30), sz(30))
            ic:ClearAnchors()
            ic:SetAnchor(CENTER, c.map, TOPLEFT, mx(x), mx(y))
            ic:SetHidden(false)
            local hit = c.hit_pool:acquire()
            hit:ClearAnchors()
            hit:SetAnchorFill(ic)
            hit:SetHidden(false)
            W.tips[hit] = tostring(pin.name or "objective")
        end
    end
end

local function draw_spawn(geo, m)
    local sp = BGMeter.Match.spawn_point(m, geo)
    state.spawnShown = false
    if not sp then return end
    local tc = S.team_color(m.localTeam)
    local r = mx(BGMeter.Match.base_radius())
    local cx, cy = mx(sp.x), mx(sp.y)
    local edge = { tc[1], tc[2], tc[3], 0.35 }
    local function side_rect(x, y, w, h)
        local rc = c.dot_pool:acquire()
        rc:ClearAnchors()
        rc:SetAnchor(TOPLEFT, c.map, TOPLEFT, x, y)
        rc:SetDimensions(w, h)
        P.set_rect_color(rc, edge)
        rc:SetHidden(false)
    end
    side_rect(cx - r, cy - r, 2 * r, 1)
    side_rect(cx - r, cy + r, 2 * r, 1)
    side_rect(cx - r, cy - r, 1, 2 * r)
    side_rect(cx + r, cy - r, 1, 2 * r)
    local ic = c.icon_pool:acquire()
    ic:SetTexture(BGMeter.Icons.CAMP)
    ic:SetColor(tc[1], tc[2], tc[3], 0.95)
    ic:SetDimensions(sz(22), sz(22))
    ic:ClearAnchors()
    ic:SetAnchor(CENTER, c.map, TOPLEFT, cx, cy)
    ic:SetHidden(false)
    local hit = c.hit_pool:acquire()
    hit:ClearAnchors()
    hit:SetAnchorFill(ic)
    hit:SetHidden(false)
    W.tips[hit] = (sp.how == "gates")
        and string.format("Your team's spawn\nwhere the team stood before the gates opened (%d samples)", sp.samples)
        or string.format("Your team's spawn\nwhere you landed after respawning (%d respawn%s)", sp.samples, (sp.samples == 1) and "" or "s")
    state.spawnShown = true
end

function M.spawn_state()
    local sp = state.geo and state.m and BGMeter.Match.spawn_point(state.m, state.geo) or nil
    return { shown = state.spawnShown == true, x = sp and sp.x, y = sp and sp.y, how = sp and sp.how }
end

local function draw_positions(geo, m, idx, t)
    local mine = geo.mine
    for name, s in pairs(geo.pos) do
        if name ~= mine then
            local x, y = s.x[idx], s.y[idx]
            if x and y and (x > 0 or y > 0) then
                local d = c.icon_pool:acquire()
                d:SetTexture(PIP_MATE)
                d:ClearAnchors()
                d:SetAnchor(CENTER, c.map, TOPLEFT, mx(x), mx(y))
                d:SetDimensions(sz(16), sz(16))
                local col = S.team_color(geo.team[name] or m.localTeam)
                d:SetColor(col[1], col[2], col[3], 1)
                d:SetHidden(false)
                local hit = c.hit_pool:acquire()
                hit:ClearAnchors()
                hit:SetAnchorFill(d)
                hit:SetHidden(false)
                W.tips[hit] = name
            end
        end
    end
    local mx_, my_
    if geo.me then
        local i = BGMeter.Match.geo_index_of(geo.me.t, geo.me.n, t)
        mx_, my_ = geo.me.x[i], geo.me.y[i]
    elseif mine and geo.pos[mine] then
        mx_, my_ = geo.pos[mine].x[idx], geo.pos[mine].y[idx]
    end
    if mx_ and my_ and (mx_ > 0 or my_ > 0) then
        local ring = c.icon_pool:acquire()
        ring:SetTexture(PIP_ME)
        ring:ClearAnchors()
        ring:SetAnchor(CENTER, c.map, TOPLEFT, mx(mx_), mx(my_))
        ring:SetDimensions(sz(34), sz(34))
        ring:SetColor(K.COLOR.you[1], K.COLOR.you[2], K.COLOR.you[3], 0.35)
        ring:SetHidden(false)
        local d = c.icon_pool:acquire()
        d:SetTexture(PIP_ME)
        d:ClearAnchors()
        d:SetAnchor(CENTER, c.map, TOPLEFT, mx(mx_), mx(my_))
        d:SetDimensions(sz(24), sz(24))
        d:SetColor(K.COLOR.you[1], K.COLOR.you[2], K.COLOR.you[3], 1)
        d:SetHidden(false)
        local hit = c.hit_pool:acquire()
        hit:ClearAnchors()
        hit:SetAnchorFill(d)
        hit:SetHidden(false)
        W.tips[hit] = "you"
    end
end

local function now_lines(m, geo, t)
    local Match = BGMeter.Match
    local lines = {}
    local tl = m.timeline
    if tl and tl.t and #tl.t > 0 then
        local i = Match.geo_index_of(tl.t, #tl.t, t)
        local parts = {}
        local series = { tl.s1, tl.s2, tl.s3 }
        for s = 1, 3 do
            local team = tl.teams and tl.teams[s]
            local v = series[s] and series[s][i]
            if team and v and (v > 0 or (m.teams and #m.teams >= s)) then
                parts[#parts + 1] = string.format("|c%s%d|r", hexc(S.team_color(team)), math.floor(v + 0.5))
            end
        end
        lines[#lines + 1] = "score  " .. table.concat(parts, " · ")
    end
    if state.race == nil or state.raceFor ~= m then
        state.race, state.raceFor = Match.damage_race(m) or false, m
    end
    if state.race and state.race.mine and tl and tl.t then
        local i = Match.geo_index_of(tl.t, #tl.t, t)
        lines[#lines + 1] = string.format("|c%s%s|r dmg by you", hexc(K.COLOR.you), F.abbrev(state.race.mine[i] or 0))
    end
    local kills, deaths = 0, 0
    for _, k in ipairs(m.killfeed or {}) do
        if (k.t or 0) <= t then
            if k.kind == "kill" then kills = kills + 1 elseif k.kind == "death" then deaths = deaths + 1 end
        end
    end
    lines[#lines + 1] = string.format("|c%s%d|r kills  ·  |c%s%d|r deaths", hexc(K.COLOR.gold), kills, hexc(K.COLOR.accent), deaths)
    local near = 0
    if geo.me then
        local i = Match.geo_index_of(geo.me.t, geo.me.n, t)
        local idx = Match.geo_index(geo, t)
        local x0, y0 = geo.me.x[i], geo.me.y[i]
        for name, s in pairs(geo.pos) do
            if name ~= geo.mine and s.x[idx] and x0 then
                local dx, dy = s.x[idx] - x0, s.y[idx] - y0
                if dx * dx + dy * dy <= 60 * 60 then near = near + 1 end
            end
        end
        lines[#lines + 1] = string.format("%d teammate%s within 15 m", near, near == 1 and "" or "s")
    end
    return lines
end

local function refresh_now(m, geo, idx)
    if state.nowM == m and state.nowIdx == idx then return end
    state.nowM, state.nowIdx = m, idx
    local lines = now_lines(m, geo, state.t)
    for i, l in ipairs(c.nowLines) do set_text(l, lines[i] or "") end
end

function M.render()
    if not built or c.win:IsHidden() then return end
    local m = BGMeter.History.get(W.current_index)
    layout()
    local hm = Prefs.get("map_heat_mode")
    local heatKey = tostring(hm) .. "|" .. tostring(state.side) .. "|" .. tostring(m)
    local keep_heat = (heatKey == state.heatKey)
    release_all(keep_heat)
    state.heatKey = heatKey
    c.heatMark:SetHidden(hm == "off")
    S.color(c.heatLabel, hm ~= "off" and K.COLOR.text or K.COLOR.text_dim)
    for _, sg in ipairs(c.heatSeg) do segment_set(sg, hm == sg.key) end
    for _, t in ipairs(c.toggles) do
        local on = Prefs.get(t.lay.key) and true or false
        t.mark:SetHidden(not on)
        S.color(t.label, on and K.COLOR.text or K.COLOR.text_dim)
        set_text(t.value, on and "on" or "off")
    end
    if state.m ~= m then state.t = nil end
    state.m = m
    state.geo = m and BGMeter.Match.geo_cached(m) or nil
    apply_tiles(m or {})
    if state.tcM ~= m then
        state.tcM = m
        local Match = BGMeter.Match
        local tl = m and m.timeline
        local tspan = (tl and tl.t and tl.t[#tl.t]) or 0
        c.cards[1].chart:set_series(tl)
        local coh = state.geo and Match.geo_cohesion(state.geo, m) or nil
        if coh then coh.series = coh.series or { { values = coh.values, color = K.COLOR.accent, lut = COHESION_LUT } } end
        c.cards[2].chart:set_data(coh)
        local solo = state.geo and Match.geo_solo(state.geo, m) or nil
        if solo then solo.series = solo.series or { { values = solo.values, color = K.COLOR.you, lut = COHESION_LUT } } end
        c.cards[3].chart:set_data(solo)
        local ks = (m and tspan > 0) and Match.kill_pressure_series(Match.kill_pressure(m.killfeed, tspan)) or nil
        if ks then for _, sr in ipairs(ks.series) do sr.color = S.team_color(sr.team) end end
        c.cards[4].chart:set_data(ks)
        local base = state.geo and Match.geo_at_base(state.geo, m) or nil
        if base then
            base.series = base.series or { { values = base.values, color = K.COLOR.accent, lut = COHESION_LUT } }
            base.fmt = base.fmt or pct
        end
        c.cards[5].chart:set_data(base)
        local ctl = state.geo and Match.geo_control(state.geo, m) or nil
        if ctl then
            ctl.series = ctl.series or { { values = ctl.values, color = K.COLOR.accent, lut = CONTROL_LUT } }
            ctl.fmt = ctl.fmt or pct
        end
        c.cards[6].chart:set_data(ctl)
        for _, cd in ipairs(c.cards) do cd.has = cd.chart.cols > 0 end
        place_cards(state.side)
    end
    if not state.geo then
        state.heatKey = nil
        state.lastM = nil
        path_reset()
        team_reset()
        c.empty:SetHidden(false)
        set_text(c.sub, m and (m.name or "Battleground") or "")
        for _, l in ipairs(c.nowLines) do set_text(l, "") end
        state.nowM, state.nowIdx = nil, nil
        set_text(c.timeLabel, "")
        c.slider:SetHidden(true)
        Prof.enter("map:timechart")
        for _, cd in ipairs(c.cards) do cd.chart:set_time(nil) end
        Prof.exit("map:timechart")
        return
    end
    c.empty:SetHidden(true)
    c.slider:SetHidden(false)
    local geo = state.geo
    local tspan = geo.t[geo.n] or 1
    if state.t == nil then state.t = tspan end
    if state.t > tspan then state.t = tspan end
    state.applying = true
    if c.slider.SetMinMax then c.slider:SetMinMax(0, tspan) end
    c.slider:SetValue(state.t)
    state.applying = false
    local idx = BGMeter.Match.geo_index(geo, state.t)
    state.lastIdx = idx
    state.lastMeIdx = geo.me and BGMeter.Match.geo_index_of(geo.me.t, geo.me.n, state.t) or idx
    state.lastM = m
    set_text(c.sub, string.format("%s  ·  %s", m.name or "Battleground", m.map and m.map.name or ""))
    if hm ~= "off" and not keep_heat then
        Prof.enter("map:heat")
        draw_heat(geo, m, hm)
        Prof.exit("map:heat")
    end
    Prof.enter("map:paths")
    draw_paths(geo, m, idx, state.t)
    Prof.exit("map:paths")
    Prof.enter("map:marks")
    if Prefs.get("map_deaths") then draw_deaths(geo, m, state.t) end
    if Prefs.get("map_pins") then draw_pins(geo, idx) end
    draw_spawn(geo, m)
    draw_positions(geo, m, idx, state.t)
    Prof.exit("map:marks")
    set_text(c.timeLabel, "t " .. F.duration(state.t))
    refresh_now(m, geo, idx)
    Prof.enter("map:timechart")
    for k = 1, state.shown do state.stack[k].chart:set_time(state.t) end
    Prof.exit("map:timechart")
    if not state.fromChart and W.chart_cursor_at then W.chart_cursor_at(state.t) end
end

local function scrub_impl()
    state.scrubQueued = false
    if not built or c.win:IsHidden() or not state.geo then return end
    local geo, m = state.geo, state.m
    local idx = BGMeter.Match.geo_index(geo, state.t)
    local meIdx = geo.me and BGMeter.Match.geo_index_of(geo.me.t, geo.me.n, state.t) or idx
    if state.lastM == m and state.lastIdx == idx and state.lastMeIdx == meIdx then
        set_text(c.timeLabel, "t " .. F.duration(state.t))
        refresh_now(m, geo, idx)
        Prof.enter("map:timechart")
        for k = 1, state.shown do state.stack[k].chart:set_time(state.t) end
        Prof.exit("map:timechart")
        if not state.fromChart and W.chart_cursor_at then W.chart_cursor_at(state.t) end
        return
    end
    M.render()
end

local function scrub_flush()
    Prof.span("map:scrub", scrub_impl)
end

function M.set_time(t, from_chart, force)
    if not built or c.win:IsHidden() or not state.geo then return end
    local tspan = state.geo.t[state.geo.n] or 1
    t = math.max(0, math.min(tspan, t or tspan))
    if not force and math.abs(t - (state.t or -1)) < 250 then return end
    state.t = t
    state.fromChart = from_chart and true or false
    if from_chart then
        state.applying = true
        c.slider:SetValue(t)
        state.applying = false
    end
    if force then
        M.render()
        return
    end
    if state.scrubQueued then return end
    state.scrubQueued = true
    if type(zo_callLater) == "function" then zo_callLater(scrub_flush, 0) else scrub_flush() end
end

function M.time() return state.t end

function M.on_wheel(delta)
    if not state.geo then return end
    local t = (state.t or 0) + ((delta or 0) > 0 and WHEEL_MS or -WHEEL_MS)
    M.set_time(t, true)
end

function M.on_double_click(y)
    if not built then return end
    local top = c.win:GetTop()
    if y == nil or y < top or y > top + HEAD_H + 12 then return end
    c.win:SetDimensions(L.map_w, L.map_h)
    local gg = sv_win()
    gg.w, gg.h = 0, 0
    dock()
    Sound.play("nav")
    M.render()
end

function M.toggle_heat()
    local cur = Prefs.get("map_heat_mode")
    if cur == "off" then
        Prefs.set("map_heat_mode", Prefs.get("map_heat_last") or "presence")
    else
        Prefs.set("map_heat_last", cur)
        Prefs.set("map_heat_mode", "off")
    end
    Sound.play("nav")
    M.render()
end

function M.set_heat_mode(mode)
    Prefs.set("map_heat_mode", mode)
    Prefs.set("map_heat_last", mode)
    Sound.play("nav")
    M.render()
end

local function raise()
    if c and c.win and c.win.BringWindowToTop then c.win:BringWindowToTop() end
end

function M.open()
    build()
    if not W.win or W.win:IsHidden() then return end
    c.win:SetHidden(false)
    raise()
    sv_win().open = true
    state.t = nil
    M.render()
    Sound.play("menu")
end

function M.close(silent)
    if not built or c.win:IsHidden() then return end
    drag_stop()
    c.win:SetHidden(true)
    sv_win().open = false
    if W.battle and W.battle.cursor then W.battle.cursor:SetHidden(true) end
    if not silent then Sound.play("close") end
end

function M.toggle()
    build()
    if c.win:IsHidden() then M.open() else M.close() end
end

function M.is_open() return built and not c.win:IsHidden() end

function M.on_report_render()
    if not built or c.win:IsHidden() then return end
    raise()
    M.render()
end

function M.on_report_hidden()
    if built and not c.win:IsHidden() then c.win:SetHidden(true) end
end

function M.on_report_shown()
    build()
    if sv_win().open then
        c.win:SetHidden(false)
        state.t = nil
        M.render()
    end
end

function M.controls() return c end

function M.column_state()
    return { side = state.side, chart_y = CHART_Y, chart_min_h = CHART_MIN_H, card_h = CARD_H, card_gap = CARD_GAP,
             min_side = MIN_SIDE, chart_h = c.chartCard:GetHeight(), shown = state.shown, hidden = state.hidden,
             available = #state.stack, hint = not c.moreHint:IsHidden() }
end

function M.ensure_built() build() end

local MINI_TICK_MS = 100
local MINI_LOOP_MS = 22000
local MINI_NAME = "BGMeterMiniPlay"
local MINI_MIN = 120
local MINI_INSET = 5
local mini = nil
local mstate = { m = nil, geo = nil, t = 0, side = 0, on = false }

local function mini_build(parent)
    if mini then return end
    mini = { frame = BGMeter.zenimax.ui.create_control(nil, parent, CT_CONTROL) }
    local fr = mini.frame
    fr:SetMouseEnabled(true)
    fr:SetHidden(true)
    mini.frameBg = P.rect(fr, gold(0.06))
    mini.frameBg:SetAnchorFill(fr)
    mini.box = P.hairline_box(fr, gold(0.45))
    mini.root = BGMeter.zenimax.ui.create_control(nil, fr, CT_CONTROL)
    local r = mini.root
    r:SetAnchor(TOPLEFT, fr, TOPLEFT, MINI_INSET, MINI_INSET)
    r:SetMouseEnabled(false)
    mini.bg = P.rect(r, { 0, 0, 0, 0.6 })
    mini.bg:SetAnchorFill(r)
    mini.tiles = {}
    mini.dot_pool = leveled_pool(function() return P.rect(r, { 1, 1, 1, 1 }) end, LV.mark)
    local probe = P.line(r, { 1, 1, 1, 1 }, 2)
    if probe then
        probe:SetHidden(true)
        mini.line_pool = leveled_pool(function() return P.line(r, { 1, 1, 1, 1 }, 2) end, LV.path)
    end
    mini.icon_pool = leveled_pool(function() return P.icon(r, "") end, LV.mark)
    mini.dot_pool.label, mini.icon_pool.label = "mini.dots", "mini.icons"
    if mini.line_pool then mini.line_pool.label = "mini.path" end
    mini.slots, mini.used, mini.next = {}, 0, 0
    mini.glow = P.rect(r, gold(0))
    mini.glow:SetAnchorFill(r)
    if mini.glow.SetDrawLevel then mini.glow:SetDrawLevel(LV.hit) end
    fr:SetHandler("OnMouseEnter", function()
        P.set_rect_color(mini.glow, gold(0.14))
        P.set_rect_color(mini.frameBg, gold(0.14))
        for _, edge in pairs(mini.box) do P.set_rect_color(edge, gold(0.9)) end
        if U.card_show then U.card_show(fr, LEFT, "Open map") end
    end)
    fr:SetHandler("OnMouseExit", function()
        P.set_rect_color(mini.glow, gold(0))
        P.set_rect_color(mini.frameBg, gold(0.06))
        for _, edge in pairs(mini.box) do P.set_rect_color(edge, gold(0.45)) end
        if U.card_hide then U.card_hide() end
    end)
    fr:SetHandler("OnMouseUp", function(_, _, upInside)
        if upInside then
            if M.is_open() then M.close() else M.open() end
        end
    end)
end

local function mini_tiles(m)
    local map = m.map
    local nx, ny = (map and map.nx) or 0, (map and map.ny) or 0
    local total = nx * ny
    for i = 1, math.max(total, #mini.tiles) do
        local tile = mini.tiles[i]
        if i <= total then
            if not tile then
                tile = P.icon(mini.root, "")
                if tile.SetDrawLevel then tile:SetDrawLevel(LV.tile) end
                mini.tiles[i] = tile
            end
            local col = (i - 1) % nx
            local row = math.floor((i - 1) / nx)
            local tw = mstate.side / nx
            tile:ClearAnchors()
            tile:SetAnchor(TOPLEFT, mini.root, TOPLEFT, col * tw, row * tw)
            tile:SetDimensions(tw + 0.5, tw + 0.5)
            tile:SetTexture(map.tex and map.tex[i] or "")
            tile:SetColor(1, 1, 1, 0.9)
            tile:SetHidden(false)
        elseif tile then
            tile:SetHidden(true)
        end
    end
end

local mscratch = { xs = {}, ys = {}, n = 0, drawn = 0, side = 0, geo = nil }

local function mini_scale(v) return v / 1000 * mstate.side end

local function mini_prepare()
    local geo = mstate.geo
    local me = geo.me or (geo.mine and geo.pos[geo.mine])
    local xs, ys = mscratch.xs, mscratch.ys
    local n = 0
    if me then
        local count = geo.me and me.n or geo.n
        for i = 1, count do
            local x, y = me.x[i] or 0, me.y[i] or 0
            if x > 0 or y > 0 then
                n = n + 1
                xs[n], ys[n] = mini_scale(x), mini_scale(y)
            else
                n = n + 1
                xs[n], ys[n] = false, false
            end
        end
    end
    for i = n + 1, #xs do xs[i], ys[i] = nil, nil end
    if mini.line_pool then mini.line_pool:release_all() end
    mscratch.n, mscratch.drawn, mscratch.side, mscratch.geo = n, 0, mstate.side, geo
end

local function mini_slot()
    local n = mini.next + 1
    mini.next = n
    local d = mini.slots[n]
    if not d then
        d = mini.icon_pool:acquire()
        mini.slots[n] = d
    end
    d:SetHidden(false)
    return d
end

local function mini_draw()
    local geo, m = mstate.geo, mstate.m
    if not geo then
        if mini.line_pool then mini.line_pool:release_all() end
        for i = 1, mini.used do mini.slots[i]:SetHidden(true) end
        mini.used = 0
        return
    end
    if mscratch.geo ~= geo or mscratch.side ~= mstate.side then mini_prepare() end
    local t = mstate.t
    local idx = BGMeter.Match.geo_index(geo, t)
    local me = geo.me or (geo.mine and geo.pos[geo.mine])
    local upto = 0
    if me then upto = geo.me and BGMeter.Match.geo_index_of(me.t, me.n, t) or idx end
    if upto > mscratch.n then upto = mscratch.n end
    local xs, ys = mscratch.xs, mscratch.ys
    if upto < mscratch.drawn then
        if mini.line_pool then mini.line_pool:release_all() end
        mscratch.drawn = 0
    end
    if mini.line_pool then
        for i = math.max(2, mscratch.drawn + 1), upto do
            if xs[i] and xs[i - 1] then
                local ln = mini.line_pool:acquire()
                ln:ClearAnchors()
                ln:SetAnchor(TOPLEFT, mini.root, TOPLEFT, xs[i - 1], ys[i - 1])
                ln:SetAnchor(TOPRIGHT, mini.root, TOPLEFT, xs[i], ys[i])
                ln:SetColor(K.COLOR.you[1], K.COLOR.you[2], K.COLOR.you[3], 0.9)
                if ln.SetThickness then ln:SetThickness(2) end
                ln:SetHidden(false)
            end
        end
    end
    if upto > mscratch.drawn then mscratch.drawn = upto end
    mini.next = 0
    if upto >= 1 and xs[upto] then
        local d = mini_slot()
        if d._mini_tex ~= PIP_ME then d:SetTexture(PIP_ME); d._mini_tex = PIP_ME end
        d:ClearAnchors()
        d:SetAnchor(CENTER, mini.root, TOPLEFT, xs[upto], ys[upto])
        d:SetDimensions(16, 16)
        d:SetColor(K.COLOR.you[1], K.COLOR.you[2], K.COLOR.you[3], 1)
    end
    local tc = S.team_color(m.localTeam)
    for name, s in pairs(geo.pos) do
        if name ~= geo.mine and s.x[idx] and s.y[idx] and (s.x[idx] > 0 or s.y[idx] > 0) then
            local d = mini_slot()
            if d._mini_tex ~= PIP_MATE then d:SetTexture(PIP_MATE); d._mini_tex = PIP_MATE end
            d:ClearAnchors()
            d:SetAnchor(CENTER, mini.root, TOPLEFT, mini_scale(s.x[idx]), mini_scale(s.y[idx]))
            d:SetDimensions(10, 10)
            d:SetColor(tc[1], tc[2], tc[3], 1)
        end
    end
    for _, pin in ipairs(geo.pins) do
        local x, y = pin.x[idx], pin.y[idx]
        if x and y and (x > 0 or y > 0) then
            local ic = mini_slot()
            local tex = pin_texture(pin.ty[idx], pin.kind)
            if ic._mini_tex ~= tex then ic:SetTexture(tex); ic._mini_tex = tex end
            ic:SetColor(1, 1, 1, 1)
            ic:SetDimensions(14, 14)
            ic:ClearAnchors()
            ic:SetAnchor(CENTER, mini.root, TOPLEFT, mini_scale(x), mini_scale(y))
        end
    end
    for i = mini.next + 1, mini.used do mini.slots[i]:SetHidden(true) end
    mini.used = mini.next
end

local function mini_stop()
    if not mstate.on then return end
    mstate.on = false
    BGMeter.zenimax.events.unregister_update(MINI_NAME)
end

local function mini_tick()
    if not mini or mini.frame:IsHidden() or not mstate.geo or not Prefs.get("animate") or (W.win and W.win:IsHidden()) then mini_stop() return end
    local tspan = mstate.geo.t[mstate.geo.n] or 1
    mstate.t = mstate.t + tspan * MINI_TICK_MS / MINI_LOOP_MS
    if mstate.t > tspan + tspan * 0.08 then mstate.t = 0 end
    mini_draw()
end

function M.mini_scratch() return mscratch
end

local function mini_start()
    if mstate.on then return end
    mstate.on = true
    BGMeter.zenimax.events.register_update(MINI_NAME, MINI_TICK_MS, mini_tick)
end

function M.mini_update(m, parent, x, y, avail)
    mini_build(parent)
    local geo = m and BGMeter.Match.geo_cached(m) or nil
    local outer = math.min(avail or 0, L.haul_w - 32)
    local side = outer - 2 * MINI_INSET
    if not geo or not m.map or side < MINI_MIN then
        mini.frame:SetHidden(true)
        mini_stop()
        mstate.geo, mstate.m = nil, nil
        mscratch.geo = nil
        mini_draw()
        return false
    end
    mstate.side = side
    mini.frame:ClearAnchors()
    mini.frame:SetAnchor(TOPLEFT, parent, TOPLEFT, x, y)
    mini.frame:SetDimensions(outer, outer)
    mini.root:SetDimensions(side, side)
    mini.frame:SetHidden(false)
    if mstate.m ~= m then
        mstate.t = 0
        mscratch.geo = nil
    end
    mstate.m, mstate.geo = m, geo
    mini_tiles(m)
    local tspan = geo.t[geo.n] or 1
    if Prefs.get("animate") then
        mini_start()
    else
        mini_stop()
        mstate.t = tspan
    end
    mini_draw()
    return true
end

function M.mini_visible() return mini ~= nil and not mini.frame:IsHidden() end
function M.mini_time() return mstate.t end
function M.mini_running() return mstate.on end
function M.mini_controls() return mini end

BGMeter.UI.map = M
