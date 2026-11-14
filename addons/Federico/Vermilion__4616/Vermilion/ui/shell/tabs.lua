Vermilion = Vermilion or {}
Vermilion.ViewTabs = {}
local M = Vermilion.ViewTabs

local zui = Vermilion.zenimax.ui
local zc  = Vermilion.zenimax.constants
local WINDOW_MANAGER    = zui.WINDOW_MANAGER
local TOPLEFT           = zc.TOPLEFT
local CT_LABEL          = zc.CT_LABEL
local TEXT_ALIGN_CENTER = zc.TEXT_ALIGN_CENTER
local math_floor        = math.floor
local Sound             = Vermilion.Sound

local STATE, controls, VIEW_LABELS
local release_all_pools, set_view

function M.bind(t)
  STATE, controls, VIEW_LABELS = t.STATE, t.controls, t.VIEW_LABELS
  release_all_pools, set_view = t.release_all_pools, t.set_view
end

local TAB_FLARE, TAB_H, TAB_CAP, TAB_PAD = 6, 26, 14, 8

local function style_tabs()
  local tabs = controls.tabs
  if not tabs then return end
  for v = 1, #VIEW_LABELS do
    local t = tabs[v]
    local on = (v == STATE.view)
    t.label:SetColor(on and 0.98 or 0.66, on and 0.90 or 0.58, on and 0.88 or 0.56, 1)
    t.band:SetNormalTexture(on and Vermilion.Skin.TAB_ON or Vermilion.Skin.TAB_IDLE)
    t.band:SetDrawLevel(on and 3 or 2)
  end
end

local function fit_tab_widths(tabs, w, n)
  local scale = Vermilion.zenimax.api.GetUIGlobalScale()
  for v = 1, n do
    local t = tabs[v]
    local text = t.label:GetStringWidth(VIEW_LABELS[v]) / scale
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
  local n = #VIEW_LABELS
  fit_tab_widths(tabs, strip:GetWidth(), n)
  local next_x = 0
  for v = 1, n do
    local t = tabs[v]
    local x, tw = next_x, t.tw
    next_x = x + tw
    t.hit:ClearAnchors()
    t.hit:SetAnchor(TOPLEFT, strip, TOPLEFT, x, 0)
    t.hit:SetDimensions(tw, 24)
    t.label:ClearAnchors()
    t.label:SetAnchor(TOPLEFT, strip, TOPLEFT, x, 6)
    t.label:SetDimensions(tw, 18)
    t.band:ClearAnchors()
    t.band:SetAnchor(TOPLEFT, strip, TOPLEFT, x - TAB_FLARE, 0)
    t.band:SetDimensions(tw + TAB_FLARE * 2, TAB_H)
  end
end

function M.build(strip)
  controls.tabs = { strip = strip }
  for v = 1, #VIEW_LABELS do
    local hit_c = WINDOW_MANAGER:CreateControl("VermilionGraphTab" .. v, strip, zc.CT_CONTROL)
    hit_c:SetMouseEnabled(true)
    hit_c:SetDrawLevel(5)
    local label = WINDOW_MANAGER:CreateControl("VermilionGraphTab" .. v .. "Label", strip, CT_LABEL)
    label:SetFont("ZoFontGameSmall")
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    label:SetText(VIEW_LABELS[v])
    label:SetDrawLevel(4)
    local band = WINDOW_MANAGER:CreateControl("VermilionGraphTab" .. v .. "Band", strip, zc.CT_BUTTON)
    band:SetMouseEnabled(false)
    band:SetEndCapWidth(TAB_CAP)
    band:SetNormalTexture(Vermilion.Skin.TAB_IDLE)
    band:SetDrawLevel(2)
    local view = v
    hit_c:SetHandler("OnMouseUp", function(_, _, upInside)
      if upInside == false or view == STATE.view then return end
      Sound.play("page")
      release_all_pools()
      set_view(view)
    end)
    hit_c:SetHandler("OnMouseEnter", function()
      label:SetColor(1, 1, 1, 1)
      if view ~= STATE.view then band:SetNormalTexture(Vermilion.Skin.TAB_OVER) end
    end)
    hit_c:SetHandler("OnMouseExit", function()
      style_tabs()
    end)
    controls.tabs[v] = { hit = hit_c, label = label, band = band }
  end
  layout_tabs()
  style_tabs()
end

M.style, M.layout = style_tabs, layout_tabs
