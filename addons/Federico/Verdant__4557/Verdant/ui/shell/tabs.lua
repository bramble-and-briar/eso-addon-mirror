Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Tabs = {}
local M = Verdant.Tabs

local api = Verdant.zenimax.api
local zui = Verdant.zenimax.ui
local zc  = Verdant.zenimax.constants
local WM                          = zui.WINDOW_MANAGER
local TOPLEFT           = zc.TOPLEFT
local CT_CONTROL        = zc.CT_CONTROL
local CT_LABEL          = zc.CT_LABEL
local CT_BUTTON         = zc.CT_BUTTON
local TEXT_ALIGN_CENTER = zc.TEXT_ALIGN_CENTER
local math_floor        = math.floor
local Sound             = Verdant.Sound
local Skin              = Verdant.Skin
local VIEWS             = Verdant.Views.list
local release_all_pools = Verdant.ChartPools.release_all

local TAB_FLARE, TAB_H, TAB_CAP, TAB_PAD = 6, 26, 14, 8
local HIT_H, LABEL_TOP, LABEL_H = 24, 6, 18

local controls, STATE, set_view

function M.bind(t)
  controls, STATE = t.controls, t.STATE
  set_view = t.set_view
end

local function style_tabs()
  local tabs = controls.tabs
  if not tabs then return end
  for v = 1, #VIEWS do
    local t = tabs[v]
    local on = (v == STATE.view)
    Skin.label(t.label, on and "ink" or "dim")
    Skin.tab(t.band, on and "on" or "idle")
    t.band:SetDrawLevel(on and 3 or 2)
  end
end

local function fit_tab_widths(tabs, w, n)
  local scale = api.GetUIGlobalScale()
  for v = 1, n do
    local t = tabs[v]
    local text = t.label:GetStringWidth(VIEWS[v].label) / scale
    t.need = (text > 0) and (math_floor(text + 0.999) + TAB_PAD) or 0
    t.fixed = false
  end
  local free, open = w, n
  local again = true
  while again and open > 0 do
    again = false
    local share = free / open
    for v = 1, n do
      local t = tabs[v]
      if not t.fixed and t.need > share then
        t.fixed = true
        free, open = free - t.need, open - 1
        again = true
      end
    end
  end
  local share = (open > 0) and math_floor(free / open) or 0
  for v = 1, n do
    local t = tabs[v]
    t.tw = t.fixed and t.need or share
  end
end

local function layout_tabs()
  local tabs = controls.tabs
  if not tabs then return end
  local strip = tabs.strip
  local n = #VIEWS
  fit_tab_widths(tabs, strip:GetWidth(), n)
  local next_x = 0
  for v = 1, n do
    local t = tabs[v]
    local x, tw = next_x, t.tw
    next_x = x + tw
    t.hit:ClearAnchors()
    t.hit:SetAnchor(TOPLEFT, strip, TOPLEFT, x, 0)
    t.hit:SetDimensions(tw, HIT_H)
    t.label:ClearAnchors()
    t.label:SetAnchor(TOPLEFT, strip, TOPLEFT, x, LABEL_TOP)
    t.label:SetDimensions(tw, LABEL_H)
    t.band:ClearAnchors()
    t.band:SetAnchor(TOPLEFT, strip, TOPLEFT, x - TAB_FLARE, 0)
    t.band:SetDimensions(tw + TAB_FLARE * 2, TAB_H)
  end
end

function M.build()
  local strip = VerdantGraphWindowTabs
  controls.tabs = { strip = strip }
  for v = 1, #VIEWS do
    local hit = WM:CreateControl("VerdantGraphTab" .. v, strip, CT_CONTROL)
    hit:SetMouseEnabled(true)
    hit:SetDrawLevel(5)
    local label = WM:CreateControl("VerdantGraphTab" .. v .. "Label", strip, CT_LABEL)
    label:SetFont("ZoFontGameSmall")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetText(VIEWS[v].label)
    label:SetDrawLevel(4)
    local band = WM:CreateControl("VerdantGraphTab" .. v .. "Band", strip, CT_BUTTON)
    band:SetMouseEnabled(false)
    band:SetEndCapWidth(TAB_CAP)
    local view = v
    zui.handler(hit, "OnMouseUp", function(_, _, upInside)
      if upInside == false or view == STATE.view then return end
      Sound.play("page")
      release_all_pools()
      set_view(view)
    end)
    zui.handler(hit, "OnMouseEnter", function(self)
      label:SetColor(1, 1, 1, 1)
      if view ~= STATE.view then Skin.tab(band, "over") end
    end)
    zui.handler(hit, "OnMouseExit", function()
      style_tabs()
    end)
    controls.tabs[v] = { hit = hit, label = label, band = band }
  end
  layout_tabs()
  style_tabs()
end

M.style  = style_tabs
M.layout = layout_tabs
