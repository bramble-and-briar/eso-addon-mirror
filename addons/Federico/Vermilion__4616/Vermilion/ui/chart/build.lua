Vermilion = Vermilion or {}
Vermilion.ChartBuild = {}
local M = Vermilion.ChartBuild

local api = Vermilion.zenimax.api
local zui = Vermilion.zenimax.ui
local zc  = Vermilion.zenimax.constants
local zev = Vermilion.zenimax.events
local WINDOW_MANAGER          = zui.WINDOW_MANAGER
local GetGameTimeMilliseconds = api.GetGameTimeMilliseconds
local GetUIMousePosition      = api.GetUIMousePosition
local TOPLEFT                 = zc.TOPLEFT
local BOTTOMLEFT              = zc.BOTTOMLEFT
local CT_TEXTURE              = zc.CT_TEXTURE
local CT_LABEL                = zc.CT_LABEL
local TEXT_ALIGN_LEFT         = zc.TEXT_ALIGN_LEFT
local TEXT_ALIGN_CENTER       = zc.TEXT_ALIGN_CENTER
local RIGHT_BUTTON            = zc.MOUSE_BUTTON_INDEX_RIGHT or 2

local Sound  = Vermilion.Sound
local Pool   = Vermilion.lib.plot.Pool
local Pools  = Vermilion.ChartPools
local Grid   = Vermilion.ChartGrid
local Format = Vermilion.Format
local HC     = Vermilion.HoverCard
local Hover  = Vermilion.ChartHover
local Drag   = Vermilion.ChartDrag
local fill_factory, fill_reset = Pools.fill_factory, Pools.fill_reset
local make_fill_pool, make_line_pool = Pools.fill, Pools.line
local create_grid, hide_grid, draw_grid = Grid.create, Grid.hide, Grid.draw
local TIME_STRIP_H = Grid.TIME_STRIP_H
local fmt_val, fmt_secs, hexc = Format.val, Format.secs, Format.hex
local show_moment_card, show_rows_card = HC.show_moment, HC.show_rows
local make_fader, fade_in, fade_out = Vermilion.Fader.new, Vermilion.Fader.show, Vermilion.Fader.hide
local hover_allowed, stop_hover_poll, hide_hover_ui = Hover.allowed, Hover.stop_poll, Hover.hide_ui
local hover_poll = Hover.poll
local hit_begin = Vermilion.ChartHit.begin
local draw_bands_at = Vermilion.FilmBands.draw_bands_at
local VIEWS = Vermilion.Views.list

local STATE, controls, VIS, CHIP, DTYPE_ICON, top_inset
local C_LINE_EOS, C_CROSSHAIR, C_SUM
local render_current_view
local card_fader, crosshair_fader
local section_panel
local ICON_LEVEL = 2

function M.bind(t)
  STATE, controls, VIS, CHIP = t.STATE, t.controls, t.VIS, t.CHIP
  DTYPE_ICON, top_inset = t.DTYPE_ICON, t.top_inset
  C_LINE_EOS, C_CROSSHAIR, C_SUM = t.C_LINE_EOS, t.C_CROSSHAIR, t.C_SUM
  render_current_view = t.render
  M.KIND = t.KIND
end

function M.attach(fader) card_fader = fader end

local function place_crosshair(cx)
  controls.crosshair:ClearAnchors()
  controls.crosshair:SetAnchor(TOPLEFT,    controls.canvas, TOPLEFT,    cx, 0)
  controls.crosshair:SetAnchor(BOTTOMLEFT, controls.canvas, BOTTOMLEFT, cx, 0)
  fade_in(crosshair_fader)
end

function M.pools()
  controls.grid = create_grid("VermilionGrid", controls.canvas)

  controls.pool_eos_segments = make_fill_pool("VermilionEosSeg")
  controls.pool_edps         = make_fill_pool("VermilionEdpsFill")
  controls.pool_shdps        = make_fill_pool("VermilionShdpsFill")
  controls.pool_shield       = make_fill_pool("VermilionShieldHeat")
  controls.pool_shield_icon  = Pool.new("VermilionShieldIcon", controls.canvas, CT_TEXTURE,
    function(c) c:SetDrawLevel(5) end,
    function(c) c:SetHidden(true) end)
  controls.pool_ult          = make_fill_pool("VermilionGraphUlt")
  controls.pool_res          = make_fill_pool("VermilionGraphRes")
  controls.pool_res_lbl      = Pool.new("VermilionGraphResLbl", controls.canvas, CT_LABEL,
    function(c)
      c:SetFont("ZoFontGameSmall")
      c:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
      c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end,
    function(c) c:SetHidden(true) end)
  controls.pool_ult_icon     = Pool.new("VermilionGraphUltIcon", controls.canvas, CT_TEXTURE,
    function(c)
      if c.SetPixelRoundingEnabled then c:SetPixelRoundingEnabled(false) end
      c:SetDrawLevel(8)
    end,
    function(c) c:SetHidden(true) end)
  controls.pool_kill         = Pool.new("VermilionKillIcon", controls.canvas, CT_TEXTURE,
    function(c)
      if c.SetPixelRoundingEnabled then c:SetPixelRoundingEnabled(false) end
      c:SetDrawLevel(9)
    end,
    function(c) c:SetHidden(true) end)
  controls.pool_dead         = Pool.new("VermilionDeadBand", controls.canvas, CT_TEXTURE,
    function(c)
      if c.SetPixelRoundingEnabled then c:SetPixelRoundingEnabled(false) end
      c:SetDrawLevel(1)
    end,
    function(c) c:SetHidden(true) end)
  controls.pool_c_seg = Pool.new("VermilionContribSeg", controls.canvas, CT_TEXTURE,
    function(c)
      fill_factory(c)
      c:SetDrawLevel(2)
    end,
    function(c)
      c:SetHidden(true)
      c:SetDrawLevel(2)
    end)
  controls.pool_c_rim = Pool.new("VermilionContribRim", controls.canvas, CT_TEXTURE,
    function(c)
      fill_factory(c)
      c:SetDrawLevel(3)
    end, fill_reset)
  controls.pool_panel = Pool.new("VermilionPanel", controls.canvas, zc.CT_BACKDROP,
    function(c)
      Vermilion.Skin.section(c)
      c:SetDrawLevel(1)
    end,
    function(c) c:SetHidden(true) end)
  function section_panel(x0, y0, x1, y1)
    local p = controls.pool_panel:AcquireObject()
    p:ClearAnchors()
    p:SetAnchor(TOPLEFT, controls.canvas, TOPLEFT, x0, y0)
    p:SetDimensions(x1 - x0, y1 - y0)
    p:SetHidden(false)
  end
  controls.pool_c_icon = Pool.new("VermilionContribIcon", controls.canvas, CT_TEXTURE,
    function(c)
      c:SetPixelRoundingEnabled(false)
      c:SetDrawLevel(ICON_LEVEL)
    end,
    function(c)
      c:SetHidden(true)
      c:SetColor(1, 1, 1, 1)
      c:SetDrawLevel(ICON_LEVEL)
    end)
  controls.pool_c_lbl = Pool.new("VermilionContribLbl", controls.canvas, CT_LABEL,
    function(c)
      c:SetFont("ZoFontGameSmall")
      c:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
      c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end,
    function(c) c:SetHidden(true) end)
  controls.pool_d_seg = Pool.new("VermilionDebuffSeg", controls.canvas, CT_TEXTURE,
    function(c)
      fill_factory(c)
      c:SetDrawLevel(2)
    end,
    function(c)
      c:SetHidden(true)
      c:SetDrawLevel(2)
    end)
  controls.pool_d_rim = Pool.new("VermilionDebuffRim", controls.canvas, CT_TEXTURE,
    function(c)
      fill_factory(c)
      c:SetDrawLevel(3)
    end, fill_reset)
  controls.pool_d_icon = Pool.new("VermilionDebuffIcon", controls.canvas, CT_TEXTURE,
    function(c) c:SetPixelRoundingEnabled(false) end,
    function(c) c:SetHidden(true) end)
  controls.pool_d_lbl = Pool.new("VermilionDebuffLbl", controls.canvas, CT_LABEL,
    function(c)
      c:SetFont("ZoFontGameSmall")
      c:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
      c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end,
    function(c) c:SetHidden(true) end)
end

function M.layers()
  local crosshair = WINDOW_MANAGER:CreateControl("VermilionGraphCrosshair", controls.canvas, CT_TEXTURE)
  crosshair:SetWidth(1)
  crosshair:SetColor(C_CROSSHAIR.r, C_CROSSHAIR.g, C_CROSSHAIR.b, C_CROSSHAIR.a)
  crosshair:SetDrawLevel(15)
  crosshair:SetAnchor(TOPLEFT,    controls.canvas, TOPLEFT,    0, 0)
  crosshair:SetAnchor(BOTTOMLEFT, controls.canvas, BOTTOMLEFT, 0, 0)
  crosshair:SetAlpha(0)
  crosshair:SetHidden(true)
  controls.crosshair = crosshair

  local avg_line = WINDOW_MANAGER:CreateControl("VermilionGraphAvgLine", controls.canvas, CT_TEXTURE)
  avg_line:SetHeight(1)
  avg_line:SetColor(C_LINE_EOS.r, C_LINE_EOS.g, C_LINE_EOS.b, 0.75)
  avg_line:SetDrawLevel(14)
  avg_line:SetHidden(true)
  controls.avg_line = avg_line
  local median_line = WINDOW_MANAGER:CreateControl("VermilionGraphMedianLine", controls.canvas, CT_TEXTURE)
  median_line:SetHeight(1)
  median_line:SetColor(C_SUM.MEDIAN.r, C_SUM.MEDIAN.g, C_SUM.MEDIAN.b, 0.6)
  median_line:SetDrawLevel(14)
  median_line:SetHidden(true)
  controls.median_line = median_line

  Vermilion.FilmOverview.attach(controls.viewport, controls.canvas, function()
    hide_hover_ui()
    render_current_view()
  end)
  crosshair_fader = make_fader(crosshair)
  Hover.attach(card_fader, crosshair_fader)

  local hit_layer = WINDOW_MANAGER:CreateControl("VermilionGraphHit", controls.canvas, zc.CT_CONTROL)
  hit_layer:SetAnchorFill(controls.canvas)
  hit_layer:SetMouseEnabled(false)
  hit_layer:SetHidden(true)
  hit_layer:SetHandler("OnMouseEnter", function()
    if hover_allowed() and not Drag.active() then zev.register_update("VermilionHoverPoll", 50, hover_poll) end
  end)
  hit_layer:SetHandler("OnMouseExit", function()
    stop_hover_poll(); hide_hover_ui()
    local lit = false
    for i = 1, #VIEWS do
      local rows = VIEWS[i].rows
      if rows then
        if rows.hovered() ~= nil then lit = true end
        rows.clear_hover()
      end
    end
    if STATE.hover_key ~= nil or lit then STATE.hover_key = nil; render_current_view() end
  end)
  controls.hit = hit_layer
  hit_layer:SetHandler("OnMouseWheel", function(_, delta)
    local dir = (delta and delta < 0) and 1 or -1
    local rows = VIEWS[STATE.view].rows
    local changed
    if rows then
      changed = rows.scroll(dir)
    else
      local W = Vermilion.FilmWindow
      local n = Vermilion.TemporalBuffer.count()
      if api.IsShiftKeyDown and api.IsShiftKeyDown() then
        changed = W.pan(dir, n)
      else
        local mx = api.GetUIMousePosition()
        local cw = controls.canvas:GetWidth()
        changed = W.zoom(dir, (cw > 0) and ((mx - controls.canvas:GetLeft()) / cw) or 0.5, n)
      end
    end
    if changed then
      hide_hover_ui()
      render_current_view()
      Drag.rebase()
    end
  end)
  hit_layer:SetHandler("OnMouseDown", function(_, button) Drag.begin(button) end)
  hit_layer:SetHandler("OnMouseUp", function(_, button, upInside)
    if Drag.finish() then return end
    if upInside == false then return end
    local view = VIEWS[STATE.view]
    if button == RIGHT_BUTTON and view.bars then
      if Vermilion.FilmWindow.reset() then
        hide_hover_ui()
        render_current_view()
      end
      return
    end
    local rows = view.rows
    if not (rows and rows.click) then return end
    local mx, my = GetUIMousePosition()
    if rows.click(mx, my) then
      Sound.play(rows.click_sound and rows.click_sound() or "page")
      hide_hover_ui()
      render_current_view()
    end
  end)
  controls.pool_t_seg = Pool.new("VermilionTargetSeg", controls.canvas, CT_TEXTURE,
    function(c)
      fill_factory(c)
      c:SetDrawLevel(2)
    end,
    function(c)
      c:SetHidden(true)
      c:SetDrawLevel(2)
    end)
  controls.pool_t_sub = Pool.new("VermilionTargetSub", controls.canvas, CT_TEXTURE,
    function(c)
      fill_factory(c)
      c:SetDrawLevel(4)
    end,
    function(c)
      c:SetHidden(true)
      c:SetDrawLevel(4)
    end)
  controls.pool_t_rim = Pool.new("VermilionTargetRim", controls.canvas, CT_TEXTURE,
    function(c)
      fill_factory(c)
      c:SetDrawLevel(3)
    end, fill_reset)
  controls.pool_t_lbl = Pool.new("VermilionTargetLbl", controls.canvas, CT_LABEL,
    function(c)
      c:SetFont("ZoFontGameSmall")
      c:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
      c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
      c:SetDrawLevel(5)
    end,
    function(c) c:SetHidden(true) end)
  Vermilion.TargetsView.attach({
    canvas = controls.canvas, grid = controls.grid, no_data = controls.no_data,
    seg = controls.pool_t_seg, sub = controls.pool_t_sub, rim = controls.pool_t_rim, lbl = controls.pool_t_lbl,
    layout = CHIP, time_strip = TIME_STRIP_H, fmt_secs = fmt_secs, fmt_val = fmt_val, kinds = M.KIND,
    ult_band = draw_bands_at, ult_inset = top_inset,
    kills = function()
      if Vermilion.Settings and Vermilion.Settings.kill_markers and not Vermilion.Settings.kill_markers() then return nil end
      return Vermilion.Kills
    end,
    kill_pool = function() return controls.pool_kill end,
    kill_icon = VIS.kill_icon,
    hide_grid = hide_grid, draw_grid = draw_grid,
    now = GetGameTimeMilliseconds,
    show_card = show_rows_card,
    hide_card = function() hide_hover_ui() end,
    crosshair = place_crosshair,
    hit_reset = function() hit_begin(0) end,
    rerender = function() render_current_view() end,
  })
  controls.pool_viz_line = make_line_pool("VermilionVizLine")
  controls.pool_viz_cd = Pool.new("VermilionVizCd", controls.canvas, zc.CT_COOLDOWN or CT_COOLDOWN,
    function(cd) cd:SetDrawLevel(5) end,
    function(cd) cd:SetHidden(true); cd:ClearAnchors() end)
  Vermilion.ResourcesView.attach({
    panel = section_panel, panels = controls.pool_panel,
    canvas = controls.canvas, grid = controls.grid, no_data = controls.no_data,
    seg = controls.pool_t_seg, sub = controls.pool_t_sub, rim = controls.pool_t_rim, lbl = controls.pool_t_lbl,
    line = controls.pool_viz_line,
    layout = CHIP, time_strip = TIME_STRIP_H, fmt_secs = fmt_secs, fmt_val = fmt_val,
    mag = VIS.mag, sta = VIS.sta, low = VIS.low, kinds = M.KIND, kill_icon = VIS.kill_icon,
    icon = controls.pool_c_icon,
    hide_grid = hide_grid,
    now = GetGameTimeMilliseconds,
    show_card = show_rows_card,
    hide_card = function() hide_hover_ui() end,
    crosshair = place_crosshair,
    hit_reset = function() hit_begin(0) end,
    rerender = function() render_current_view() end,
  })
  Vermilion.UptimeView.attach({
    panel = section_panel, panels = controls.pool_panel,
    canvas = controls.canvas, grid = controls.grid, no_data = controls.no_data,
    seg = controls.pool_t_seg, lbl = controls.pool_t_lbl, icon = controls.pool_c_icon, line = controls.pool_viz_line,
    cd = controls.pool_viz_cd, ring_tex = "Vermilion/assets/ring.dds", dot_tex = "Vermilion/assets/dot.dds",
    layout = CHIP, time_strip = TIME_STRIP_H, fmt_secs = fmt_secs, fmt_val = fmt_val, kinds = M.KIND,
    hide_grid = hide_grid,
    now = GetGameTimeMilliseconds,
    show_card = show_rows_card,
    hide_card = function() hide_hover_ui() end,
    hit_reset = function() hit_begin(0) end,
    rerender = function() render_current_view() end,
  })
  Vermilion.DebuffsView.attach({
    canvas = controls.canvas, grid = controls.grid, no_data = controls.no_data,
    seg = controls.pool_d_seg, rim = controls.pool_d_rim, icon = controls.pool_d_icon, lbl = controls.pool_d_lbl,
    layout = CHIP, time_strip = TIME_STRIP_H, fmt_secs = fmt_secs, hide_grid = hide_grid, draw_grid = draw_grid,
    now = GetGameTimeMilliseconds,
    show_card = show_rows_card,
    hide_card = function() hide_hover_ui() end,
    crosshair = place_crosshair,
    hit_reset = function() hit_begin(0) end,
    rerender = function() render_current_view() end,
  })
  Vermilion.ContribView.attach({
    canvas = controls.canvas, grid = controls.grid, no_data = controls.no_data,
    seg = controls.pool_c_seg, rim = controls.pool_c_rim, icon = controls.pool_c_icon, lbl = controls.pool_c_lbl,
    layout = CHIP, fmt_val = fmt_val, hexc = hexc, hide_grid = hide_grid,
    type_icon = function(ch)
      return DTYPE_ICON[ch] or DTYPE_ICON[zc.DAMAGE_TYPE_GENERIC]
    end,
    show_card = show_moment_card,
    hide_card = function() fade_out(card_fader) end,
    hit_reset = function() hit_begin(0) end,
    rerender = function() render_current_view() end,
  })
end
