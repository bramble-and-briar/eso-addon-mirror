BGMeter = BGMeter or {}
local BGMeter = BGMeter

local U = BGMeter.UI._win
local W = U.W
local SEC = U.SEC
local set_text, set_bar, make_clickable = U.set_text, U.set_bar, U.make_clickable
local ICON_STAR, ICON_SORTUP, ICON_SORTDN = U.ICON_STAR, U.ICON_SORTUP, U.ICON_SORTDN

local C = BGMeter.zenimax.constants
local K = BGMeter.Constants
local L = BGMeter.Constants.LAYOUT
local F = BGMeter.Format
local P = BGMeter.Plot.primitives
local S = BGMeter.Plot.style
local Bar = BGMeter.Plot.bar
local Icons = BGMeter.Icons
local Awards = BGMeter.Awards
local Prefs = BGMeter.Prefs
local Faces = BGMeter.Faces

local COLS = {
    { key = "damage",  label = "DMG",  w = 56, priority = 100, words = "Damage dealt", icon = "esoui/art/icons/progression_tabicon_2handed" },
    { key = "healing", label = "HEAL", w = 50, priority = 90,  words = "Healing done", icon = "esoui/art/icons/progression_tabicon_healinglight" },
    { key = "taken",   label = "TKN",  w = 56, priority = 82,  words = "Damage taken", icon = "esoui/art/icons/progression_tabicon_avadefender" },
    { key = "kills",   label = "K",    w = 36, priority = 95,  words = "Kills",        icon = "esoui/art/treeicons/tutorial_idexicon_combat" },
    { key = "deaths",  label = "D",    w = 36, priority = 95,  words = "Deaths",       icon = "esoui/art/treeicons/tutorial_idexicon_death" },
    { key = "assists", label = "A",    w = 36, priority = 80,  words = "Assists",      icon = "esoui/art/icons/progression_tabicon_avaleadership" },
    { key = "caps",    label = "CAP",  w = 40, priority = 85,  flag = true },
    { key = "score",   label = "PTS",  w = 50, priority = 100, words = "Medal score",  icon = "esoui/art/journal/journal_tabicon_leaderboard" },
}
local FLAG_ICONS = {
    caps    = "EsoUI/Art/MapPins/battlegrounds_capturePoint_pin_neutral.dds",
    carried = "esoui/art/icons/mapkey/mapkey_bg_murderball.dds",
}
local HEADER_ICON = 24
local ROWS_TOP = 30
local Grid = BGMeter.UI.Grid
local caps_shown = false
local FACE_ICON = "EsoUI/Art/Help/help_tabIcon_overview_up.dds"

local function hexc(c)
    return string.format("%02x%02x%02x", math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5))
end

local function face_color(lean)
    if lean == "with" then return K.COLOR.face_with end
    if lean == "against" then return K.COLOR.face_vs end
    return K.COLOR.face_mixed
end

local function face_badge(e)
    local c = face_color(Faces.lean(e))
    return string.format("  %s|c%s×%d|r", F.icon(FACE_ICON, 14), hexc(c), Faces.total(e))
end


local INDEX_X, ICON_X, NAME_X = 6, 24, 50
local BAR_X, BAR_RIGHT = 50, 6
local GRID_TOP = 26

local function tint(icon, color)
    icon:SetColor(color[1], color[2], color[3], 1)
end

local function header_art(h, up, over, down)
    h.up, h.over, h.down = up, over or up, down or up
    h.icon:SetTexture(up)
end

local function make_header(b, col)
    local h = BGMeter.zenimax.ui.create_control(nil, b.container, CT_CONTROL)
    h:SetDimensions(col.w, HEADER_ICON)
    h:SetMouseEnabled(true)
    h.col = col
    h.label = P.label(h, S.FONT.small, K.COLOR.text_dim)
    h.label:SetText(col.label)
    h.label:SetAnchor(TOPRIGHT, h, TOPRIGHT, 0, 0)
    h.label:SetDimensions(col.w, 16)
    h.label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    h.icon = P.icon(h)
    h.icon:SetDimensions(HEADER_ICON, HEADER_ICON)
    h.icon:SetAnchor(TOPRIGHT, h, TOPRIGHT, 0, 0)
    h.icon:SetHidden(true)
    h.arrow = P.icon(h)
    h.arrow:SetDimensions(10, 10)
    h.arrow:SetAnchor(RIGHT, h.icon, LEFT, -1, 0)
    h.arrow:SetHidden(true)
    h.tint = K.COLOR.text_dim
    h:SetHandler("OnMouseEnter", function()
        if h.over and not h.icon:IsHidden() then h.icon:SetTexture(h.over); tint(h.icon, K.COLOR.text) end
        local t = W.tips[h]
        if t and t ~= "" and U.card_show then U.card_show(h, BOTTOM, t) end
    end)
    h:SetHandler("OnMouseExit", function()
        if h.up then h.icon:SetTexture(h.up); tint(h.icon, h.tint) end
        if U.card_hide then U.card_hide() end
    end)
    h:SetHandler("OnMouseDown", function()
        if h.down and not h.icon:IsHidden() then h.icon:SetTexture(h.down) end
    end)
    h:SetHandler("OnMouseUp", function(_, _, upInside)
        if h.up then h.icon:SetTexture(h.up) end
        if upInside then W.sort_by(col.key == "caps" and (W.flagcol_key or "caps") or col.key) end
    end)
    return h
end

local function one_line(lbl)
    lbl:SetHeight(14)
    if TEXT_WRAP_MODE_ELLIPSIS and lbl.SetWrapMode then lbl:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS) end
end

local function list_width() return W.cur_w - 2 * L.margin - L.haul_w - L.gap end

local function build_battle(win)
    local b = {}
    b.container = BGMeter.zenimax.ui.create_control(nil, win, CT_CONTROL)
    b.container:SetAnchor(TOPLEFT, win, TOPLEFT, L.margin, L.header_h)
    b.container:SetAnchor(BOTTOMRIGHT, win, BOTTOMRIGHT, -(L.haul_w + L.gap + L.margin), -L.footer_h)

    b.headers = {}
    local nameH = P.label(b.container, S.FONT.small, K.COLOR.text_dim)
    nameH:SetText("PLAYER")
    nameH:SetAnchor(TOPLEFT, b.container, TOPLEFT, NAME_X, 0)
    make_clickable(nameH, function() W.sort_by("name") end)
    b.headers.name = nameH

    b.grid = Grid.new({ columns = COLS, left = NAME_X, right = 10, name_min = 96 })
    b.grid:set_enabled("caps", false)
    for _, col in ipairs(COLS) do
        local h = make_header(b, col)
        h:SetHidden(true)
        if col.icon then header_art(h, col.icon .. "_up.dds", col.icon .. "_over.dds", col.icon .. "_down.dds") end
        if col.words then
            W.tips[h] = col.words .. "  ·  " .. col.label
            if col.key == "taken" then W.tips[h] = W.tips[h] .. "\nHover a value for the damage taken per death." end
        end
        b.headers[col.key] = h
    end

    b.gridFrame = BGMeter.zenimax.ui.create_control(nil, b.container, CT_CONTROL)
    b.gridFrame:SetAnchor(TOPLEFT, b.container, TOPLEFT, 0, GRID_TOP)
    b.gridFrame:SetAnchor(TOPRIGHT, b.container, TOPRIGHT, 0, GRID_TOP)
    b.gridFrame:SetHeight(1)
    local gedge = K.COLOR.text_dim
    b.gridBox = P.hairline_box(b.gridFrame, { gedge[1], gedge[2], gedge[3], K.ALPHA.chart_edge })
    b.gridFrame:SetHidden(true)
    b.teamBoxes, b.runs = {}, {}
    for i = 1, 3 do
        local c = BGMeter.zenimax.ui.create_control(nil, b.container, CT_CONTROL)
        c:SetHeight(1)
        c:SetHidden(true)
        local fill = P.rect(c, { 0, 0, 0, 0 })
        fill:SetAnchorFill(c)
        b.teamBoxes[i] = { container = c, fill = fill, box = P.hairline_box(c, { 0, 0, 0, 0 }) }
        b.runs[i] = { team = 0, y0 = 0, n = 0 }
    end

    b.row_pool = BGMeter.Plot.pool.new(function() return W._make_row(b.container) end,
        function(row) row.container:SetHidden(true) end)

    local edge = K.COLOR.text_dim
    local function strip(key, title, tip, h, title_y)
        local c = BGMeter.zenimax.ui.create_control(nil, b.container, CT_CONTROL)
        c:SetAnchor(BOTTOMLEFT, b.container, BOTTOMLEFT, 0, 0)
        c:SetAnchor(BOTTOMRIGHT, b.container, BOTTOMRIGHT, 0, 0)
        c:SetHeight(h or 0)
        c:SetHidden(true)
        c:SetMouseEnabled(true)
        c:SetHandler("OnMouseEnter", function() W._chart_hover_start() end)
        c:SetHandler("OnMouseExit", function() W._chart_hover_stop() end)
        b[key] = c
        b[key .. "Bg"] = P.rect(c, { 1, 1, 1, K.ALPHA.chart_bg })
        b[key .. "Bg"]:SetAnchorFill(c)
        b[key .. "Box"] = P.hairline_box(c, { edge[1], edge[2], edge[3], K.ALPHA.chart_edge })
        local lbl = P.label(c, S.FONT.small, K.COLOR.text_dim)
        lbl:SetText(title)
        lbl:SetAnchor(TOPLEFT, c, TOPLEFT, 4, title_y or 2)
        b[key .. "Title"] = lbl
        if tip then W.tip_static(lbl, tip) else W.tip_dynamic(lbl) end
        return c
    end
    local function rect_pool(parent)
        return BGMeter.Plot.pool.new(
            function() return P.rect(parent, { 1, 1, 1, 1 }) end,
            function(r) r:SetHidden(true); r:ClearAnchors() end)
    end

    strip("chart", "MATCH TIMELINE",
        "Team score over time.\nGold skull = your kill  ·  red skull = your death  ·  team-color ticks = other kills\nGold band = bloodiest minute  ·  thin marks along the bottom = minutes  ·  dashed line = new round",
        L.chart_h)

    b.chartLegend = P.label(b.chart, S.FONT.small, K.COLOR.text)
    b.chartLegend:SetAnchor(LEFT, b.chartTitle, RIGHT, 10, 0)
    b.chartLegend:SetHeight(14)

    b.chartMax = P.label(b.chart, S.FONT.small, K.COLOR.text_dim)
    b.chartMax:SetAnchor(TOPRIGHT, b.chart, TOPRIGHT, -4, 2)
    b.chartMax:SetDimensions(60, 14)
    b.chartMax:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)

    b.mark_labels = {}

    b.dot_pool = BGMeter.Plot.pool.new(
        function()
            local d = P.rect(b.chart, { 1, 1, 1, 1 })
            d:SetDimensions(3, 3)
            return d
        end,
        function(d) d:SetHidden(true) end)

    local probe = P.line(b.chart, { 1, 1, 1, 1 }, 2)
    if probe then
        probe:SetHidden(true)
        b.lines_ok = true
        b.line_pool = BGMeter.Plot.pool.new(
            function() return P.line(b.chart, { 1, 1, 1, 1 }, 2) end,
            function(ln) ln:SetHidden(true); ln:ClearAnchors() end)
    else
        b.lines_ok = false
    end

    b.bloodiest = P.rect(b.chart, { 0.95, 0.80, 0.35, 0.07 })
    b.bloodiest:SetHidden(true)

    b.skull_pool = BGMeter.Plot.pool.new(
        function()
            local ic = P.icon(b.chart, "EsoUI/Art/TargetMarkers/Target_White_Skull_64.dds")
            ic:SetDimensions(14, 14)
            return ic
        end,
        function(ic) ic:SetHidden(true); ic:ClearAnchors() end)

    b.cursor = P.rect(b.chart, { 1, 1, 1, 0.30 })
    b.cursor:SetDimensions(1, L.chart_h - 4)
    b.cursor:SetHidden(true)

    strip("ribbon", "FLAG CONTROL",
        "Who held each flag over time (lane color = owning team).\nFlag pin = captured  ·  shield = attack defended\nIn Chaosball and Capture the Relic your own runs are gold.\nHover any pin for the details")

    b.ribbon_pool = rect_pool(b.ribbon)

    b.ribbon_letters = {}
    b.lane_pins = {}

    b.pin_pool = BGMeter.Plot.pool.new(
        function() return P.icon(b.ribbon, "") end,
        function(ic) ic:SetHidden(true); ic:ClearAnchors() end)

    strip("occ", "FLAG OCCUPATION",
        "Share of total flag-hold time per team.\nBelow: captures, successful defenses, average hold per team, first capture")

    b.occLegend = P.label(b.occ, S.FONT.small, K.COLOR.text)
    U.clamp_line(b.occLegend)
    b.occLegend:SetAnchor(TOPLEFT, b.occTitle, TOPRIGHT, 10, 0)
    b.occLegend:SetAnchor(TOPRIGHT, b.occ, TOPRIGHT, -4, 2)
    b.occLegend:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    one_line(b.occLegend)

    b.occStats = P.label(b.occ, S.FONT.small, K.COLOR.text_dim)
    U.clamp_line(b.occStats)
    b.occStats:SetAnchor(TOPLEFT, b.occ, TOPLEFT, 4, 32)
    b.occStats:SetAnchor(TOPRIGHT, b.occ, TOPRIGHT, -4, 32)
    one_line(b.occStats)

    b.occ_pool = rect_pool(b.occ)

    strip("bal", "MATCH BALANCE", nil, L.balance_h)
    local BAL_ICON, BAL_Y = 28, 18
    local function glyph(tex, x)
        local ic = P.icon(b.bal, tex)
        ic:SetDimensions(BAL_ICON, BAL_ICON)
        ic:SetAnchor(TOPLEFT, b.bal, TOPLEFT, x, BAL_Y)
        return ic
    end
    local function value(anchorTo, w)
        local l = P.label(b.bal, S.FONT.row, K.COLOR.text)
        U.clamp_line(l)
        l:SetAnchor(LEFT, anchorTo, RIGHT, 5, 0)
        l:SetDimensions(w, BAL_ICON)
        l:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        return l
    end
    b.balIcon = glyph(Icons.BALANCE, 6)
    b.balScore = value(b.balIcon, 30)
    b.balScaleW, b.balScaleN = 72, 12
    b.balScale = BGMeter.zenimax.ui.create_control(nil, b.bal, CT_CONTROL)
    b.balScale:SetDimensions(b.balScaleW, 5)
    b.balScale:SetAnchor(LEFT, b.balScore, RIGHT, 4, 0)
    b.balScaleSegs = {}
    local segW = b.balScaleW / b.balScaleN
    for i = 1, b.balScaleN do
        local c = U.balance_scale_color((i - 0.5) / b.balScaleN)
        local seg = P.rect(b.balScale, { c[1], c[2], c[3], 0.55 })
        seg:SetDimensions(segW, 5)
        seg:SetAnchor(TOPLEFT, b.balScale, TOPLEFT, (i - 1) * segW, 0)
        b.balScaleSegs[i] = seg
    end
    b.balMark = P.rect(b.bal, { 1, 1, 1, 0.95 })
    b.balMark:SetDimensions(3, 11)
    b.balTiltEnd = 6 + BAL_ICON + 5 + 30 + 4 + 72
    b.balCampX = 180
    b.balBaseIcon = glyph(Icons.CAMP, b.balCampX)
    b.balBase = value(b.balBaseIcon, 40)
    b.balStopIcon = glyph(Icons.SHEATHED, 258)
    b.balStop = value(b.balStopIcon, 58)
    b.balLeftW = 350
    local EXP_W = 118
    local function exp_block(right, iconSize)
        local e = { width = EXP_W }
        e.icon = P.icon(b.bal)
        e.icon:SetDimensions(iconSize, iconSize)
        e.icon:SetAnchor(TOPRIGHT, b.bal, TOPRIGHT, -(right + 96 + (22 - iconSize) / 2), 21 - (iconSize - 22) / 2)
        e.barM = P.rect(b.bal, { 1, 1, 1, 0.10 })
        e.barM:SetDimensions(44, 5)
        e.barM:SetAnchor(TOPRIGHT, b.bal, TOPRIGHT, -(right + 50), 22)
        e.fillM = P.rect(b.bal, { 1, 1, 1, 0.8 })
        e.fillM:SetAnchor(TOPLEFT, e.barM, TOPLEFT, 0, 0)
        e.fillM:SetDimensions(0, 5)
        e.valM = P.label(b.bal, S.FONT.small, K.COLOR.text)
        U.clamp_line(e.valM)
        e.valM:SetAnchor(TOPRIGHT, b.bal, TOPRIGHT, -right, 18)
        e.valM:SetDimensions(46, 12)
        e.barO = P.rect(b.bal, { 1, 1, 1, 0.10 })
        e.barO:SetDimensions(44, 5)
        e.barO:SetAnchor(TOPRIGHT, b.bal, TOPRIGHT, -(right + 50), 36)
        e.fillO = P.rect(b.bal, { 1, 1, 1, 0.8 })
        e.fillO:SetAnchor(TOPLEFT, e.barO, TOPLEFT, 0, 0)
        e.fillO:SetDimensions(0, 5)
        e.valO = P.label(b.bal, S.FONT.small, K.COLOR.text)
        U.clamp_line(e.valO)
        e.valO:SetAnchor(TOPRIGHT, b.bal, TOPRIGHT, -right, 32)
        e.valO:SetDimensions(46, 12)
        e.barT = P.rect(b.bal, { 1, 1, 1, 0.10 })
        e.barT:SetDimensions(44, 4)
        e.barT:SetAnchor(TOPRIGHT, b.bal, TOPRIGHT, -(right + 50), 39)
        e.fillT = P.rect(b.bal, { 1, 1, 1, 0.8 })
        e.fillT:SetAnchor(TOPLEFT, e.barT, TOPLEFT, 0, 0)
        e.fillT:SetDimensions(0, 4)
        e.valT = P.label(b.bal, S.FONT.small, K.COLOR.text)
        U.clamp_line(e.valT)
        e.valT:SetAnchor(TOPRIGHT, b.bal, TOPRIGHT, -right, 35)
        e.valT:SetDimensions(46, 11)
        e.barT:SetHidden(true); e.fillT:SetHidden(true); e.valT:SetHidden(true)
        e.right = right
        e.parent = b.bal
        e.all = { e.icon, e.barM, e.fillM, e.valM, e.barO, e.fillO, e.valO }
        e.three = { e.barT, e.fillT, e.valT }
        return e
    end
    b.balAva = exp_block(6, 28)
    b.balVet = exp_block(6 + EXP_W + 8, 22)
    W.tip_dynamic(b.bal)

    strip("race", "DAMAGE LEAD", nil)
    b.race_pool = rect_pool(b.race)
    b.raceLegend = P.label(b.race, S.FONT.small, K.COLOR.text_dim)
    b.raceLegend:SetAnchor(TOPRIGHT, b.race, TOPRIGHT, -4, 2)
    b.raceLegend:SetHeight(14)
    b.raceLegend:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    b.race_line_pool = b.lines_ok and BGMeter.Plot.pool.new(
        function() return P.line(b.race, { 1, 1, 1, 1 }, 2) end,
        function(ln) ln:SetHidden(true); ln:ClearAnchors() end) or nil

    strip("mom", "MOMENTUM",
        "Who was leading, and by how much.\nColor = leading team  ·  brighter = bigger lead", 0, 0)

    b.momStats = P.label(b.mom, S.FONT.small, K.COLOR.text_dim)
    b.momStats:SetAnchor(TOPLEFT, b.mom, TOPLEFT, 4, 30)
    b.momStats:SetAnchor(TOPRIGHT, b.mom, TOPRIGHT, -4, 30)
    one_line(b.momStats)

    b.mom_pool = rect_pool(b.mom)

    strip("kills", "KILL PRESSURE",
        "Kills per minute, one bar per team.\nTwo teams: one team grows up, the other down from the middle line.\nHover a minute for the count.")
    b.killsLegend = P.label(b.kills, S.FONT.small, K.COLOR.text)
    b.killsLegend:SetAnchor(TOPRIGHT, b.kills, TOPRIGHT, -4, 2)
    b.killsLegend:SetHeight(14)
    b.killsLegend:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
    b.kills_pool = rect_pool(b.kills)

    b.hit_pool = BGMeter.Plot.pool.new(
        function()
            local h = BGMeter.zenimax.ui.create_control(nil, b.container, CT_CONTROL)
            W.tip_dynamic(h)
            return h
        end,
        function(h) h:SetHidden(true); h:ClearAnchors(); W.tips[h] = nil end)

    return b
end

local function cell_hover(row, cell)
    cell:SetMouseEnabled(true)
    cell:SetHandler("OnMouseEnter", function()
        P.set_rect_color(row.highlight, { 1, 1, 1, K.ALPHA.row_hover })
        local t = W.tips[cell]
        if t and U.card_show then U.card_show(cell, BOTTOM, t) end
    end)
    cell:SetHandler("OnMouseExit", function()
        P.set_rect_color(row.highlight, row.baseHL or { 0, 0, 0, 0 })
        if U.card_hide then U.card_hide() end
    end)
    cell:SetHandler("OnMouseUp", function(_, _, upInside)
        if upInside and row.prow then W.select(row.prow) end
    end)
end

function W._make_row(parent)
    local row = { cells = {} }
    row.container = BGMeter.zenimax.ui.create_control(nil, parent, CT_CONTROL)
    row.container:SetHeight(L.row_h)
    row.container:SetMouseEnabled(true)

    row.highlight = P.rect(row.container, { 1, 1, 1, 0 })
    row.highlight:SetAnchorFill(row.container)

    row.teamStrip = P.rect(row.container, { 0, 0, 0, 0 })
    row.teamStrip:SetDimensions(3, L.row_h - 8)
    row.teamStrip:SetAnchor(LEFT, row.container, LEFT, 1, 0)

    row.bar = Bar.create(row.container)
    row.bar.container:SetAnchor(TOPLEFT, row.container, TOPLEFT, BAR_X, 3)
    row.bar.container:SetAnchor(BOTTOMRIGHT, row.container, BOTTOMRIGHT, -BAR_RIGHT, -3)

    row.index = P.label(row.container, S.FONT.small, K.COLOR.text_dim)
    row.index:SetAnchor(LEFT, row.container, LEFT, INDEX_X, 0)
    row.index:SetDimensions(16, L.row_h)

    row.classIcon = P.icon(row.container)
    row.classIcon:SetDimensions(20, 20)
    row.classIcon:SetAnchor(LEFT, row.container, LEFT, ICON_X, 0)

    row.name = P.label(row.container, S.FONT.row, K.COLOR.text)
    row.name:SetAnchor(LEFT, row.container, LEFT, NAME_X, 0)
    row.name:SetHeight(L.row_h)
    row.name:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    if row.name.SetMaxLineCount then row.name:SetMaxLineCount(1) end
    if TEXT_WRAP_MODE_ELLIPSIS and row.name.SetWrapMode then
        row.name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
    end

    for _, col in ipairs(COLS) do
        local lbl = P.label(row.container, S.FONT.row, K.COLOR.text)
        lbl:SetDimensions(col.w, L.row_h)
        lbl:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        lbl:SetHidden(true)
        row.cells[col.key] = lbl
    end
    row.layoutKey = nil
    cell_hover(row, row.cells.taken)
    cell_hover(row, row.cells.caps)

    row.container:SetHandler("OnMouseEnter", function()
        if W._last_row_log ~= row then
            W._last_row_log = row
            BGMeter.Log.debug("row enter: %s", tostring(row.prow and (row.prow.displayName or row.prow.charName) or "?"))
        end
        P.set_rect_color(row.highlight, { 1, 1, 1, K.ALPHA.row_hover })
        if row.face and U.card_show then
            U.card_show(row.container, BOTTOM, Faces.brief(row.face))
        end
    end)
    row.container:SetHandler("OnMouseExit", function()
        P.set_rect_color(row.highlight, row.baseHL or { 0, 0, 0, 0 })
        if row.face and U.card_hide then U.card_hide() end
    end)
    return row
end

local function apply_dynamic_min_width(m)
    if not W.measure then return end
    local maxw = 0
    for _, prow in ipairs(m.battle) do
        W.measure:SetText(U.player_ident(prow))
        local tw = W.measure:GetTextWidth() or 0
        if tw > maxw then maxw = tw end
    end
    if maxw <= 0 then return end
    local needed = math.ceil(maxw) + 26 + NAME_X + W.battle.grid:fixed_width() + 2 * L.margin + L.haul_w + L.gap
    local dyn = math.max(L.min_w, math.min(needed, L.dyn_min_cap))

    local extra
    local nflags = m.objectives and m.objectives.list and #m.objectives.list or 0
    if nflags == 0 and m.relics and m.relics.list then nflags = #m.relics.list end
    if nflags > 0 then
        local lh, lg = U.lane_metrics(nflags)
        extra = (L.occ_h + 2) + (L.ribbon_top + nflags * (lh + lg) + 3 + 2) + (28 + 2)
    else
        extra = 46 + 2
    end
    if BGMeter.Prefs.get("show_balance") then extra = extra + L.balance_h + 2 end
    local needed_h = L.header_h + ROWS_TOP + #m.battle * L.row_h + L.chart_h + extra + 8 + L.footer_h + 12
    local dyn_h = math.max(L.min_h, math.min(needed_h, L.max_h))

    if dyn ~= W.dyn_min or dyn_h ~= W.dyn_min_h then
        W.dyn_min = dyn
        W.dyn_min_h = dyn_h
        W.win:SetDimensionConstraints(dyn, dyn_h, L.max_w, L.max_h)
    end
    local sv = BGMeter.zenimax.savedvars.get()
    if W.cur_w < dyn then
        W.cur_w = dyn
        W.win:SetWidth(dyn)
        if sv then sv.window = sv.window or {}; sv.window.w = dyn end
    end
    if W.cur_h < dyn_h then
        W.cur_h = dyn_h
        W.win:SetHeight(dyn_h)
        if sv then sv.window = sv.window or {}; sv.window.h = dyn_h end
    end
end

local function caps_relevant(m)
    if m.objectives and m.objectives.list and #m.objectives.list > 0 then return true end
    for _, r in ipairs(m.battle) do
        if (r.caps or 0) > 0 or (r.carried or 0) > 0 then return true end
    end
    return false
end

local function flag_col_spec(m)
    local gt = C.GAME_TYPE_LABEL and C.GAME_TYPE_LABEL[m.gameType] or nil
    if gt == "murderball" then
        return "carried", "HOLD",
            "BALL POSSESSION\nTime this player spent holding a chaosball\n(the ball scores for their team while held). Click to sort."
    end
    return "caps", "CAP",
        "CAPTURES\nObjectives this player captured for their team\n(flags, capture points, relics). Click to sort."
end

local function caps_count(m, v)
    local gt = C.GAME_TYPE_LABEL and C.GAME_TYPE_LABEL[m.gameType] or nil
    if gt == "capture_the_flag" then return math.floor(v / 100 + 0.5) end
    return v
end

function SEC.battle(m, animate)
    local b = W.battle
    b.row_pool:release_all()
    local want_caps = caps_relevant(m)
    caps_shown = want_caps
    b.grid:set_enabled("caps", want_caps)
    b.grid:set_enabled("taken", Prefs.get("show_taken") ~= false)
    local fkey, flabel, ftip = flag_col_spec(m)
    W.flagcol_key = fkey
    if b.headers.caps then
        W.tips[b.headers.caps] = ftip
        header_art(b.headers.caps, FLAG_ICONS[fkey] or FLAG_ICONS.caps)
    end
    apply_dynamic_min_width(m)
    if b.grid:layout(list_width()) then b.grid:apply_header(b.headers, b.container) end

    local key = Prefs.get("sort_key") or "damage"
    if (key == "caps" or key == "carried") and not caps_shown then key = "damage" end
    if key ~= "name" and key ~= "caps" and key ~= "carried" and not b.grid:is_shown(key) then key = "damage" end
    if key == "caps" or key == "carried" then key = fkey end
    if key == "name" then
        local desc = Prefs.get("sort_desc")
        table.sort(m.battle, function(a, z)
            local an = (a.displayName or a.charName or ""):lower()
            local zn = (z.displayName or z.charName or ""):lower()
            if desc then return an > zn end
            return an < zn
        end)
    else
        BGMeter.Match.sort(m, key, Prefs.get("sort_desc"))
    end
    local grouped = Prefs.get("group_by_team") and true or false
    if grouped then BGMeter.Match.group_by_team(m) end

    local icons = Prefs.get("icon_headers") ~= false
    local arrow = Prefs.get("sort_desc") and ICON_SORTDN or ICON_SORTUP
    for ckey, h in pairs(b.headers) do
        local col = h.col
        local base = (ckey == "name") and (grouped and "PLAYER  ·  by team" or "PLAYER") or (col and col.label or ckey)
        if ckey == "caps" then base = flabel end
        local active = (ckey == "caps" and key == fkey) or ckey == key
        if col and icons and h.up then
            h.label:SetHidden(true)
            h.icon:SetHidden(false)
            h.tint = active and K.COLOR.text or K.COLOR.text_dim
            h.icon:SetTexture(h.up)
            tint(h.icon, h.tint)
            h.arrow:SetTexture(arrow)
            h.arrow:SetHidden(not active)
        else
            local lbl = h
            if col then
                h.icon:SetHidden(true)
                h.arrow:SetHidden(true)
                h.label:SetHidden(false)
                lbl = h.label
            end
            if active then
                S.color(lbl, K.COLOR.text)
                set_text(lbl, base .. " " .. F.icon(arrow, 16))
            else
                S.color(lbl, K.COLOR.text_dim); set_text(lbl, base)
            end
        end
    end

    local awards = Prefs.get("show_awards") and Awards.compute(m) or { leaders = {}, mvp = nil }
    local show_faces = Prefs.get("show_faces") ~= false
    local barKey = (key == "name" or key == "deaths") and "damage" or key
    local maxVal = BGMeter.Match.column_max(m, barKey)
    local barBase = (barKey == "healing") and K.COLOR.heal or K.COLOR.accent
    local listW = list_width()
    local y = ROWS_TOP
    local nruns, run = 0, nil

    for i, prow in ipairs(m.battle) do
        local row = b.row_pool:acquire()
        row.prow = prow
        if grouped then
            local t = prow.team or 0
            if not run or run.team ~= t then
                if nruns < 3 then
                    nruns = nruns + 1
                    run = b.runs[nruns]
                    run.team, run.y0, run.n = t, y, 0
                else
                    run = nil
                end
            end
            if run then run.n = run.n + 1 end
        end
        if row.layoutKey ~= b.grid.key then b.grid:apply_row(row) end
        row.container:SetHidden(false)
        row.container:ClearAnchors()
        row.container:SetAnchor(TOPLEFT, b.container, TOPLEFT, 0, y)
        row.container:SetAnchor(TOPRIGHT, b.container, TOPRIGHT, 0, y)

        set_text(row.index, tostring(i))
        local cicon = Icons.class(prow.classId)
        if cicon then row.classIcon:SetTexture(cicon); row.classIcon:SetHidden(false) else row.classIcon:SetHidden(true) end

        local nm = U.player_ident(prow)
        if awards.mvp == prow then nm = F.icon(ICON_STAR, 20) .. " " .. nm end
        local face = (show_faces and not prow.isLocal) and Faces.get(prow) or nil
        if face and Faces.is_familiar(face) then
            row.face = face
            nm = nm .. face_badge(face)
        else
            row.face = nil
        end
        set_text(row.name, nm)
        S.color(row.name, prow.isLocal and K.COLOR.you or S.team_color(prow.team))

        if prow.team then
            local tc = S.team_color(prow.team)
            P.set_rect_color(row.teamStrip, { tc[1], tc[2], tc[3], K.ALPHA.team_strip })
        else
            P.set_rect_color(row.teamStrip, { 0, 0, 0, 0 })
        end

        for _, col in ipairs(COLS) do
            local ck = (col.key == "caps") and fkey or col.key
            local cell, v = row.cells[col.key], (prow[ck] or 0) + 0
            local txt
            if col.key == "damage" or col.key == "healing" or col.key == "score" or col.key == "taken" then
                txt = F.abbrev(v)
                if col.key == "taken" then
                    local deaths = prow.deaths or 0
                    if v <= 0 then W.tips[cell] = nil
                    elseif deaths > 0 then W.tips[cell] = string.format("%s damage taken\n%s per death", F.abbrev(v), F.abbrev(v / deaths))
                    else W.tips[cell] = string.format("%s damage taken\nnever died", F.abbrev(v)) end
                end
            elseif ck == "carried" then
                txt = (v > 0) and F.duration(v * 1000) or "0"
                local def = prow.defPts or 0
                if v <= 0 and def <= 0 then W.tips[cell] = nil
                else W.tips[cell] = string.format("held the ball %s\n%d defense points", F.duration(v * 1000), def) end
            elseif ck == "caps" then
                local n = caps_count(m, v)
                txt = tostring(n)
                local def = prow.defPts or 0
                if n <= 0 and def <= 0 then W.tips[cell] = nil
                else W.tips[cell] = string.format("%d capture%s\n%d defense points", n, (n == 1) and "" or "s", def) end
            else
                txt = tostring(v)
            end
            set_text(cell, txt)
            if awards.leaders[ck] == prow and v > 0 then S.color(cell, K.COLOR.gold)
            elseif v == 0 then S.color(cell, K.COLOR.text_dim)
            else S.color(cell, K.COLOR.text) end
        end

        local pct = (maxVal > 0) and ((prow[barKey] or 0) / maxVal) or 0
        local bc = prow.isLocal and K.COLOR.you or barBase
        set_bar(row.bar, pct, { bc[1], bc[2], bc[3], K.ALPHA.bar_fill }, listW - BAR_X - BAR_RIGHT, animate)

        local hl = { 0, 0, 0, 0 }
        if awards.mvp == prow then hl = { K.COLOR.gold[1], K.COLOR.gold[2], K.COLOR.gold[3], K.ALPHA.row_mvp } end
        if prow.isLocal then hl = { K.COLOR.you[1], K.COLOR.you[2], K.COLOR.you[3], K.ALPHA.row_you } end
        if W.selected_row == prow then hl = { 1, 1, 1, K.ALPHA.row_selected } end
        row.baseHL = hl
        P.set_rect_color(row.highlight, hl)
        row.container:SetHandler("OnMouseUp", function(_, button, upInside)
            if not upInside then return end
            if MOUSE_BUTTON_INDEX_RIGHT and button == MOUSE_BUTTON_INDEX_RIGHT then
                local name = prow.displayName or prow.charName
                if name and not prow.isLocal
                    and type(ClearMenu) == "function" and type(AddMenuItem) == "function"
                    and type(ShowMenu) == "function" then
                    name = (name:gsub("%^.*$", ""))
                    ClearMenu()
                    if CHAT_SYSTEM and CHAT_SYSTEM.StartTextEntry and CHAT_CHANNEL_WHISPER then
                        AddMenuItem("Whisper " .. name, function()
                            CHAT_SYSTEM:StartTextEntry("", CHAT_CHANNEL_WHISPER, name)
                        end)
                    end
                    if type(GroupInviteByName) == "function" then
                        AddMenuItem("Invite to Group", function() GroupInviteByName(name) end)
                    end
                    ShowMenu(row.container)
                end
                return
            end
            W.select(prow)
        end)

        y = y + L.row_h
    end
    b.gridFrame:SetHeight(#m.battle * L.row_h + 8)
    b.gridFrame:SetHidden(#m.battle == 0)
    for i = 1, 3 do
        local tb = b.teamBoxes[i]
        local r = b.runs[i]
        if grouped and i <= nruns and r.n > 0 then
            local tc = S.team_color(r.team)
            tb.container:ClearAnchors()
            tb.container:SetAnchor(TOPLEFT, b.container, TOPLEFT, 2, r.y0 + 1)
            tb.container:SetAnchor(TOPRIGHT, b.container, TOPRIGHT, -2, r.y0 + 1)
            tb.container:SetHeight(r.n * L.row_h - 2)
            P.set_rect_color(tb.fill, { tc[1], tc[2], tc[3], K.ALPHA.team_box })
            local edge = { tc[1], tc[2], tc[3], K.ALPHA.team_box_edge }
            P.set_rect_color(tb.box.top, edge)
            P.set_rect_color(tb.box.bottom, edge)
            P.set_rect_color(tb.box.left, edge)
            P.set_rect_color(tb.box.right, edge)
            tb.container:SetHidden(false)
        else
            tb.container:SetHidden(true)
        end
    end
end

U.build_battle = build_battle
U.flag_col_spec = flag_col_spec
U.caps_count = caps_count
