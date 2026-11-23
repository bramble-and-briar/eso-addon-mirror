Verdant = Verdant or {}
local Verdant = Verdant

Verdant.ChartBuild = {}
local M = Verdant.ChartBuild

local api                = Verdant.zenimax.api
local zui                = Verdant.zenimax.ui
local zc                 = Verdant.zenimax.constants
local zev                = Verdant.zenimax.events
local WINDOW_MANAGER     = zui.WINDOW_MANAGER
local GetString          = api.GetString
local GetUIMousePosition = api.GetUIMousePosition
local string_format      = string.format
local TOPLEFT            = zc.TOPLEFT
local TOPRIGHT           = zc.TOPRIGHT
local BOTTOMLEFT         = zc.BOTTOMLEFT
local BOTTOMRIGHT        = zc.BOTTOMRIGHT
local CT_TEXTURE         = zc.CT_TEXTURE
local CT_LABEL           = zc.CT_LABEL
local TEXT_ALIGN_LEFT    = zc.TEXT_ALIGN_LEFT
local TEXT_ALIGN_CENTER  = zc.TEXT_ALIGN_CENTER
local TEXT_WRAP_MODE_ELLIPSIS = zc.TEXT_WRAP_MODE_ELLIPSIS
local TEXT_ALIGN_RIGHT   = zc.TEXT_ALIGN_RIGHT

local Sound     = Verdant.Sound
local Pool      = Verdant.lib.plot.Pool
local Pools     = Verdant.ChartPools
local Grid      = Verdant.ChartGrid
local HoverCard = Verdant.HoverCard
local Hover     = Verdant.ChartHover
local Drag      = Verdant.ChartDrag
local VIEW      = Verdant.Views.index
local VIEWS     = Verdant.Views.list
local FILL_TEXTURE = Pools.FILL_TEXTURE
local fill_factory, fill_reset = Pools.fill_factory, Pools.fill_reset
local make_fill_pool = Pools.make_fill_pool
local create_grid, hide_grid = Grid.create, Grid.hide
local fmt_val, hexc     = Verdant.Format.value, Verdant.Format.hex
local make_fader, fade_out = Verdant.Fader.new, Verdant.Fader.hide
local build_hover_card  = HoverCard.build
local show_moment_card  = HoverCard.show_moment
local hit_begin         = Verdant.ChartHit.begin
local hover_allowed, stop_hover_poll, hide_hover_ui = Hover.allowed, Hover.stop_poll, Hover.hide_ui
local hover_poll        = Hover.poll

local C_CROSSHAIR = Verdant.lib.themes.tint("crosshair", 0.50)
local C_LINE_SHADE = { r = 0.04, g = 0.07, b = 0.05, a = 0.85 }

local controls, STATE, ULT_L, hit_main, BUFF_FOLD, BUFF_SELF, buff_hit
local C_EHPS, C_OVERHEAL, C_LINE_AVG, C_MEDIAN
local d, toggle_buffs_fold, toggle_buffs_self, render_current_view

function M.bind(t)
  controls, STATE, ULT_L, hit_main = t.controls, t.STATE, t.ULT_L, t.hit_main
  BUFF_FOLD, BUFF_SELF, buff_hit = t.BUFF_FOLD, t.BUFF_SELF, t.buff_hit
  C_EHPS, C_OVERHEAL = t.C_EHPS, t.C_OVERHEAL
  C_LINE_AVG, C_MEDIAN = t.C_LINE_AVG, t.C_MEDIAN
  d, toggle_buffs_fold, toggle_buffs_self, render_current_view = t.d, t.toggle_buffs_fold, t.toggle_buffs_self, t.render
end

local function level_line(name, c, a)
  local line = WINDOW_MANAGER:CreateControl(name, controls.canvas, CT_TEXTURE)
  line:SetTexture(FILL_TEXTURE)
  line:SetTextureCoords(0, 1, 0, 0.05)
  line:SetHeight(1)
  line:SetColor(c.r, c.g, c.b, a)
  line:SetDrawLevel(14)
  line:SetHidden(true)
  local shade = WINDOW_MANAGER:CreateControl(name .. "Shade", line, CT_TEXTURE)
  shade:SetTexture(FILL_TEXTURE)
  shade:SetTextureCoords(0, 1, 0, 0.05)
  shade:SetAnchor(TOPLEFT, line, BOTTOMLEFT, 0, 0)
  shade:SetAnchor(TOPRIGHT, line, BOTTOMRIGHT, 0, 0)
  shade:SetHeight(1)
  shade:SetColor(C_LINE_SHADE.r, C_LINE_SHADE.g, C_LINE_SHADE.b, C_LINE_SHADE.a)
  shade:SetDrawLevel(14)
  return line
end

function M.pools()
  controls.avg_line    = level_line("VerdantGraphAvgLine", C_LINE_AVG, 0.75)
  controls.median_line = level_line("VerdantGraphMedianLine", C_MEDIAN, 0.6)
  controls.grid_ems = create_grid("VerdantGridEms", controls.canvas)
  controls.grid_skill = create_grid("VerdantGridSkill", controls.canvas)


  controls.pool_ehps           = make_fill_pool("VerdantGraphFillEhps")
  controls.pool_mps            = make_fill_pool("VerdantGraphFillMps")
  controls.pool_dmg_fill       = make_fill_pool("VerdantGraphDmgFill", 1)
  controls.pool_dead           = make_fill_pool("VerdantDeadBand", 1)
  local dmg_label = WINDOW_MANAGER:CreateControl("VerdantGraphDmgLabel", controls.canvas, CT_LABEL)
  dmg_label:SetFont("ZoFontGameSmall")
  dmg_label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
  dmg_label:SetDimensions(160, 12)
  dmg_label:SetDrawLevel(7)
  controls.dmg_label = dmg_label
  controls.pool_marker_icon = Pool.new("VerdantMarkerIcon", controls.canvas, CT_TEXTURE,
    function(c)
      c:SetPixelRoundingEnabled(false)
      c:SetDrawLevel(10)
    end,
    function(c) c:SetHidden(true) end)
  controls.pool_skill          = make_fill_pool("VerdantSkillFill")
  controls.pool_legend_sw      = make_fill_pool("VerdantSkillLegendSwatch", 7)
  controls.pool_legend_lbl     = Pool.new("VerdantSkillLegendLabel", controls.canvas, CT_LABEL,
    function(c)
      c:SetFont("ZoFontGameSmall")
      c:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
      c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
      c:SetDrawLevel(7)
    end,
    function(c) c:SetHidden(true) end)

  controls.pool_sustain_bar = make_fill_pool("VerdantSustainBar", 3)
  controls.pool_sustain_icon = Pool.new("VerdantSustainIcon", controls.canvas, CT_TEXTURE,
    function(c)
      c:SetPixelRoundingEnabled(false)
      c:SetDrawLevel(7)
    end,
    function(c) c:SetHidden(true) end)
  controls.pool_section = Pool.new("VerdantSection", controls.canvas, zc.CT_BACKDROP,
    function(c)
      Verdant.Skin.section(c)
      c:SetDrawLevel(1)
    end,
    function(c) c:SetHidden(true) end)
  controls.pool_sustain_lbl = Pool.new("VerdantSustainLabel", controls.canvas, CT_LABEL,
    function(c)
      c:SetFont("ZoFontGameSmall")
      c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
      c:SetMaxLineCount(1)
      c:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
      c:SetDrawLevel(7)
    end,
    function(c) c:SetHidden(true) end)

  controls.pool_ult = Pool.new("VerdantGraphUlt", controls.canvas, CT_TEXTURE,
    function(c)
      fill_factory(c)
      c:SetDrawLevel(6)
    end, fill_reset)
  controls.pool_ult_icon = Pool.new("VerdantGraphUltIcon", controls.canvas, CT_TEXTURE,
    function(c)
      c:SetPixelRoundingEnabled(false)
      c:SetDrawLevel(8)
    end,
    function(c) c:SetHidden(true) end)

  controls.pool_buff_seg = Pool.new("VerdantBuffSeg", controls.canvas, CT_TEXTURE,
    function(c)
      fill_factory(c)
      c:SetDrawLevel(2)
    end,
    function(c)
      c:SetHidden(true)
      c:SetDrawLevel(2)
    end)
  controls.pool_buff_rim = make_fill_pool("VerdantBuffRim", 3)
  controls.pool_buff_icon = Pool.new("VerdantBuffIcon", controls.canvas, CT_TEXTURE,
    function(c) c:SetPixelRoundingEnabled(false) end,
    function(c) c:SetHidden(true) end)
  controls.pool_buff_lbl = Pool.new("VerdantBuffLbl", controls.canvas, CT_LABEL,
    function(c)
      c:SetFont("ZoFontGameSmall")
      c:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
      c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end,
    function(c) c:SetHidden(true) end)
  controls.pool_res_seg = Pool.new("VerdantResSeg", controls.canvas, CT_TEXTURE,
    function(c)
      fill_factory(c)
      c:SetDrawLevel(2)
    end,
    function(c)
      c:SetHidden(true)
      c:SetDrawLevel(2)
    end)
  controls.pool_res_icon = Pool.new("VerdantResIcon", controls.canvas, CT_TEXTURE,
    function(c) c:SetPixelRoundingEnabled(false) end,
    function(c) c:SetHidden(true) end)
  controls.pool_res_lbl = Pool.new("VerdantResLbl", controls.canvas, CT_LABEL,
    function(c)
      c:SetFont("ZoFontGameSmall")
      c:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
      c:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    end,
    function(c) c:SetHidden(true) end)
  Verdant.ContribView.attach({
    canvas = controls.canvas, grid = controls.grid_ems, no_data = controls.no_data,
    seg = controls.pool_buff_seg, rim = controls.pool_buff_rim, icon = controls.pool_buff_icon, lbl = controls.pool_buff_lbl,
    layout = ULT_L, fmt_val = fmt_val, hexc = hexc, hide_grid = hide_grid,
    show_card = show_moment_card,
    hide_card = function() fade_out(controls.card_fader) end,
    hit_reset = function() hit_begin(hit_main, 0) end,
    rerender = function() render_current_view() end,
  })
end

function M.layers()
  local WM = WINDOW_MANAGER

  local oh_legend = WM:CreateControl("VerdantGraphOhLegend", controls.canvas, CT_LABEL)
  oh_legend:SetFont("ZoFontGameSmall")
  oh_legend:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
  oh_legend:SetVerticalAlignment(TEXT_ALIGN_CENTER)
  oh_legend:SetAnchor(TOPRIGHT, controls.canvas, TOPRIGHT, -2, 2)
  oh_legend:SetDimensions(220, 12)
  oh_legend:SetDrawLevel(7)
  oh_legend:SetText(string_format("|c%s%s|r · |c%s%s|r",
    hexc(C_EHPS), GetString(VERDANT_OHEAL_EFF),
    hexc(C_OVERHEAL), GetString(VERDANT_OHEAL_OVER)))
  oh_legend:SetHidden(true)
  controls.oh_legend = oh_legend

  build_hover_card()
  controls.card_fader = make_fader(controls.card.root)
  HoverCard.attach(controls.card_fader)
  Verdant.ReportCard.attach(controls.card_fader)
  controls.win_fader = make_fader(controls.window)
  controls.win_fader.visible = true

  local crosshair = WINDOW_MANAGER:CreateControl("VerdantGraphCrosshair", controls.window, CT_TEXTURE)
  crosshair:SetTexture(FILL_TEXTURE)
  crosshair:SetTextureCoords(0, 1, 0, 0.05)
  crosshair:SetWidth(1)
  crosshair:SetColor(C_CROSSHAIR.r, C_CROSSHAIR.g, C_CROSSHAIR.b, C_CROSSHAIR.a)
  crosshair:SetDrawLevel(15)
  crosshair:SetAnchor(TOPLEFT,    controls.canvas, TOPLEFT,    0, 0)
  crosshair:SetAnchor(BOTTOMLEFT, controls.canvas, BOTTOMLEFT, 0, 0)
  crosshair:SetAlpha(0)
  crosshair:SetHidden(true)
  controls.crosshair = crosshair
  controls.crosshair_c = C_CROSSHAIR
  controls.crosshair_fader = make_fader(crosshair)
  Hover.attach(controls.card_fader, controls.crosshair_fader)

  local function make_hit(name, canvas)
    local h = WINDOW_MANAGER:CreateControl(name, canvas, zc.CT_CONTROL)
    h:SetAnchorFill(canvas)
    h:SetMouseEnabled(false)
    h:SetHidden(true)
    zui.handler(h, "OnMouseEnter", function()
      if hover_allowed() and not Drag.active() then zev.register_update("VerdantHoverPoll", 50, hover_poll) end
    end)
    zui.handler(h, "OnMouseExit", function()
      stop_hover_poll(); hide_hover_ui()
      if STATE.hover_key ~= nil then STATE.hover_key = nil; render_current_view() end
    end)
    return h
  end
  controls.hit_main = make_hit("VerdantGraphHitMain", controls.canvas)
  Verdant.ResourcesView.attach({
    canvas = controls.canvas, grid = controls.grid_ems, no_data = controls.no_data,
    seg = controls.pool_res_seg, lbl = controls.pool_res_lbl, icon = controls.pool_res_icon,
    panel = function(x0, y0, x1, y1)
      local p = controls.pool_section:AcquireObject()
      p:ClearAnchors()
      p:SetCenterColor(1, 1, 1, 1)
      p:SetAnchor(TOPLEFT, controls.canvas, TOPLEFT, x0, y0)
      p:SetDimensions(x1 - x0, y1 - y0)
      p:SetHidden(false)
    end,
    top = function() return ULT_L.CHIP or 0 end,
    time_strip = Grid.TIME_STRIP_H, fmt_secs = Verdant.Format.secs, fmt_val = fmt_val, hide_grid = hide_grid,
    now = api.GetGameTimeMilliseconds,
    show_card = HoverCard.show_rows,
    hide_card = function() hide_hover_ui() end,
    crosshair = function(x)
      local cr = controls.crosshair
      cr:ClearAnchors()
      cr:SetAnchor(TOPLEFT, controls.canvas, TOPLEFT, x, 0)
      cr:SetAnchor(BOTTOMLEFT, controls.canvas, BOTTOMLEFT, x, 0)
      Verdant.Fader.show(controls.crosshair_fader)
    end,
    hit_reset = function() hit_begin(hit_main, 0) end,
    rerender = function() render_current_view() end,
  })
  Verdant.FilmOverview.attach(controls.viewport, controls.canvas, function() render_current_view() end)

  zui.handler(controls.hit_main, "OnMouseWheel", function(_, delta)
    local dir = (delta and delta < 0) and 1 or -1
    if STATE.view == VIEW.BUFFS then
      local next_off = BUFF_FOLD.scroll + dir
      if next_off < 0 then next_off = 0 end
      if next_off > BUFF_FOLD.max_scroll then next_off = BUFF_FOLD.max_scroll end
      if next_off ~= BUFF_FOLD.scroll then
        BUFF_FOLD.scroll = next_off
        hide_hover_ui(); STATE.hover_key = nil
        render_current_view()
      end
      return
    end
    if STATE.view == VIEW.RESOURCES then
      if Verdant.ResourcesView.scroll(dir) then
        hide_hover_ui()
        render_current_view()
      end
      return
    end
    if STATE.view == VIEW.CONTRIB then
      if Verdant.ContribView.scroll(dir) then
        hide_hover_ui()
        render_current_view()
      end
      return
    end
    local W = Verdant.FilmWindow
    local n = Verdant.TemporalBuffer.count()
    local changed
    if api.IsShiftKeyDown() then
      changed = W.pan(dir, n)
    else
      changed = W.zoom(dir, (GetUIMousePosition() - controls.canvas:GetLeft()) / controls.canvas:GetWidth(), n)
    end
    if changed then
      hide_hover_ui()
      render_current_view()
      Drag.rebase()
    end
  end)

  controls.side_hit = WINDOW_MANAGER:CreateControl("VerdantGraphSideHit", controls.canvas, zc.CT_CONTROL)
  controls.side_hit:SetMouseEnabled(true)
  controls.side_hit:SetHidden(true)
  zui.handler(controls.side_hit, "OnMouseWheel", function(_, delta)
    local _, my = GetUIMousePosition()
    if Verdant.RestoreView.scroll((delta and delta < 0) and 1 or -1, my - controls.canvas:GetTop()) then
      render_current_view()
    end
  end)

  zui.handler(controls.hit_main, "OnMouseDown", function(_, button) Drag.begin(button) end)

  zui.handler(controls.hit_main, "OnMouseUp", function(_, button, upInside)
    if Drag.finish() then return end
    if upInside == false then return end
    if button == zc.MOUSE_BUTTON_INDEX_RIGHT and VIEWS[STATE.view].bars then
      if Verdant.FilmWindow.reset() then
        hide_hover_ui()
        render_current_view()
      end
      return
    end
    if STATE.view == VIEW.RESOURCES then
      local px, py = GetUIMousePosition()
      if Verdant.ResourcesView.click(px, py) then
        Sound.play("click")
        hide_hover_ui()
        render_current_view()
      end
      return
    end
    if STATE.view ~= VIEW.BUFFS then return end
    local mx, my = GetUIMousePosition()
    local rel_x = mx - controls.canvas:GetLeft()
    local rel_y = my - controls.canvas:GetTop()
    if BUFF_FOLD.on and rel_y >= BUFF_FOLD.y0 and rel_y <= BUFF_FOLD.y1 and rel_x >= 0 then
      toggle_buffs_fold()
      return
    end
    if BUFF_SELF.on and rel_y >= BUFF_SELF.y0 and rel_y <= BUFF_SELF.y1 and rel_x >= 0 then
      toggle_buffs_self()
      return
    end
    if rel_x < 0 or rel_x > 20 then return end
    for i = 1, buff_hit.n do
      if rel_y >= buff_hit.y0[i] and rel_y <= buff_hit.y1[i] then
        local rec = buff_hit.rec[i]
        local thr = Verdant.BuffWatch.toggle(rec.name, rec.id)
        Sound.play("arm")
        if thr then
          d("[V] " .. string_format(GetString(VERDANT_WATCH_ARMED), rec.name or "?", thr))
        else
          d("[V] " .. string_format(GetString(VERDANT_WATCH_OFF), rec.name or "?"))
        end
        render_current_view()
        break
      end
    end
  end)
end
