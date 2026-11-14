Vermilion = Vermilion or {}
local Vermilion = Vermilion
Vermilion.lib = Vermilion.lib or {}
Vermilion.lib.viz = Vermilion.lib.viz or {}

local S = {}
Vermilion.lib.viz.surface = S

local math_max = math.max
local math_floor = math.floor

local function bump(key)
  local D = Vermilion.Diagnostics
  if D and D.bump then D.bump(key) end
end

function S.begin(c)
  c.drawn = 0
  c.dropped = 0
end

function S.box(c, x0, x1, y, h, col, a, lvl)
  local seg = c.seg and c.seg:AcquireObject()
  if not seg then
    c.dropped = (c.dropped or 0) + 1
    bump("viz.surface.dropped")
    return
  end
  seg:ClearAnchors()
  seg:SetAnchor(TOPLEFT, c.canvas, TOPLEFT, x0, y)
  seg:SetWidth(math_max(1, x1 - x0))
  seg:SetHeight(math_max(1, h))
  seg:SetPixelRoundingEnabled(h <= 1 or x1 - x0 <= 1)
  seg:SetDrawLevel(lvl or 2)
  seg:SetColor(col.r, col.g, col.b, a == nil and 1 or a)
  seg:SetHidden(false)
  c.drawn = (c.drawn or 0) + 1
end

function S.frame(c, x0, y0, x1, y1, col, a, lvl)
  if c.panel then
    c.panel(x0, y0, x1, y1)
    return
  end
  local l = lvl or 6
  S.box(c, x0, x1, y0, 1, col, a, l)
  S.box(c, x0, x1, y1 - 1, 1, col, a, l)
  S.box(c, x0, x0 + 1, y0, y1 - y0, col, a, l)
  S.box(c, x1 - 1, x1, y0, y1 - y0, col, a, l)
end

function S.label(c, text, x, y, w, h, align, col, a)
  local lbl = c.lbl and c.lbl:AcquireObject()
  if not lbl then
    c.dropped = (c.dropped or 0) + 1
    bump("viz.surface.dropped")
    return
  end
  lbl:ClearAnchors()
  lbl:SetText(text)
  lbl:SetHorizontalAlignment(align or TEXT_ALIGN_LEFT)
  lbl:SetMaxLineCount(1)
  lbl:SetColor(col.r, col.g, col.b, a == nil and 1 or a)
  lbl:SetDimensions(w, h)
  lbl:SetAnchor(TOPLEFT, c.canvas, TOPLEFT, x, y)
  lbl:SetHidden(false)
  c.drawn = (c.drawn or 0) + 1
end

function S.line(c, x0, y0, x1, y1, col, a, thick, lvl)
  local ln = c.line and c.line:AcquireObject()
  if not ln then
    c.dropped = (c.dropped or 0) + 1
    bump("viz.surface.dropped")
    return false
  end
  ln:ClearAnchors()
  ln:SetAnchor(TOPLEFT, c.canvas, TOPLEFT, x0, y0)
  ln:SetAnchor(TOPRIGHT, c.canvas, TOPLEFT, x1, y1)
  ln:SetThickness(thick or 1)
  if ln.SetDrawLevel then ln:SetDrawLevel(lvl or 4) end
  ln:SetColor(col.r, col.g, col.b, a == nil and 1 or a)
  ln:SetHidden(false)
  c.drawn = (c.drawn or 0) + 1
  return true
end

function S.icon(c, tex, x, y, size, a)
  local ic = c.icon and c.icon:AcquireObject()
  if not ic then
    c.dropped = (c.dropped or 0) + 1
    bump("viz.surface.dropped")
    return
  end
  ic:ClearAnchors()
  ic:SetTexture(tex)
  ic:SetDimensions(size, size)
  ic:SetColor(1, 1, 1, a == nil and 1 or a)
  ic:SetAnchor(TOPLEFT, c.canvas, TOPLEFT, x, y)
  ic:SetHidden(false)
  c.drawn = (c.drawn or 0) + 1
end

function S.disc(c, x, y, size, col, a, lvl)
  if not c.dot_tex then
    S.box(c, x - math_floor(size / 2), x - math_floor(size / 2) + size, y - math_floor(size / 2), size, col, a, lvl or 5)
    return
  end
  local ic = c.icon and c.icon:AcquireObject()
  if not ic then
    c.dropped = (c.dropped or 0) + 1
    bump("viz.surface.dropped")
    return
  end
  ic:ClearAnchors()
  ic:SetTexture(c.dot_tex)
  ic:SetDimensions(size, size)
  ic:SetColor(col.r, col.g, col.b, a == nil and 1 or a)
  if ic.SetDrawLevel then ic:SetDrawLevel(lvl or 5) end
  ic:SetAnchor(CENTER, c.canvas, TOPLEFT, x, y)
  ic:SetHidden(false)
  c.drawn = (c.drawn or 0) + 1
end

function S.tex_ring(c, cx, cy, r, col, a, lvl)
  if not c.ring_tex then return false end
  local ic = c.icon and c.icon:AcquireObject()
  if not ic then
    c.dropped = (c.dropped or 0) + 1
    bump("viz.surface.dropped")
    return false
  end
  ic:ClearAnchors()
  ic:SetTexture(c.ring_tex)
  ic:SetDimensions(r * 2, r * 2)
  ic:SetColor(col.r, col.g, col.b, a == nil and 1 or a)
  if ic.SetDrawLevel then ic:SetDrawLevel(lvl or 4) end
  ic:SetAnchor(CENTER, c.canvas, TOPLEFT, cx, cy)
  ic:SetHidden(false)
  c.drawn = (c.drawn or 0) + 1
  return true
end

function S.x_of(scale, t)
  return scale.x0 + math_floor((t - scale.t0) / scale.span * scale.w + 0.5)
end
