Vermilion = Vermilion or {}
Vermilion.Dock = {}
local M = Vermilion.Dock

local zc = Vermilion.zenimax.constants
local math_abs = math.abs

local GAP, SCREEN_MARGIN, SNAP, ALIGN = 8, 16, 14, 40

local function target(d, side)
  local win, host = d.win, d.host
  if side == "right" then return host:GetRight() + GAP, host:GetTop() end
  if side == "left" then return host:GetLeft() - GAP - win:GetWidth(), host:GetTop() end
  if side == "bottom" then return host:GetLeft(), host:GetBottom() + GAP end
  return host:GetLeft(), host:GetTop() - GAP - win:GetHeight()
end

local function fits(d, side)
  local win = d.win
  local x, y = target(d, side)
  local screen_w, screen_h = zc.GuiRoot:GetDimensions()
  return x >= SCREEN_MARGIN and y >= SCREEN_MARGIN
    and x + win:GetWidth() + SCREEN_MARGIN <= screen_w
    and y + win:GetHeight() + SCREEN_MARGIN <= screen_h
end

local function attach(d, side)
  local win, host = d.win, d.host
  win:ClearAnchors()
  if side == "right" then win:SetAnchor(zc.TOPLEFT, host, zc.TOPRIGHT, GAP, 0)
  elseif side == "left" then win:SetAnchor(zc.TOPRIGHT, host, zc.TOPLEFT, -GAP, 0)
  elseif side == "bottom" then win:SetAnchor(zc.TOPLEFT, host, zc.BOTTOMLEFT, 0, GAP)
  else win:SetAnchor(zc.BOTTOMLEFT, host, zc.TOPLEFT, 0, -GAP) end
end

local function free(d, x, y)
  d.win:ClearAnchors()
  d.win:SetAnchor(zc.TOPLEFT, zc.GuiRoot, zc.TOPLEFT, x, y)
end

function M.new(win, host, store, sides)
  return { win = win, host = host, store = store, sides = sides }
end

function M.open(d)
  local s = d.store
  if s.detached and s.x and s.y then
    free(d, s.x, s.y)
    return
  end
  if d.host:IsHidden() then return end
  for i = 1, #d.sides do
    if fits(d, d.sides[i]) then
      attach(d, d.sides[i])
      return
    end
  end
  attach(d, d.sides[#d.sides])
end

function M.released(d)
  local s, win = d.store, d.win
  local x, y = win:GetLeft(), win:GetTop()
  if not d.host:IsHidden() then
    for i = 1, #d.sides do
      local side = d.sides[i]
      local tx, ty = target(d, side)
      local dx, dy = math_abs(x - tx), math_abs(y - ty)
      local along_x = side == "right" or side == "left"
      if (along_x and dx <= SNAP and dy <= ALIGN) or (not along_x and dy <= SNAP and dx <= ALIGN) then
        s.detached, s.x, s.y = nil, nil, nil
        attach(d, side)
        return
      end
    end
  end
  s.detached, s.x, s.y = true, x, y
  free(d, x, y)
end

function M.forget(d)
  local s = d.store
  s.detached, s.x, s.y = nil, nil, nil
  if not d.win:IsHidden() then M.open(d) end
end

function M.is_detached(d)
  return d.store.detached == true
end
