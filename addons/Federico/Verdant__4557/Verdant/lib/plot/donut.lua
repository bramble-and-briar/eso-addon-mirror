Verdant = Verdant or {}
local Verdant = Verdant
Verdant.lib = Verdant.lib or {}
Verdant.lib.plot = Verdant.lib.plot or {}

local M = {}
Verdant.lib.plot.Donut = M

local zui = Verdant.zenimax.ui
local WINDOW_MANAGER = zui.WINDOW_MANAGER

local TAU = 2 * math.pi
local RING_TEXTURE = "Verdant/assets/ring.dds"

local Donut = {}
Donut.__index = Donut

function M.new(name, parent, size, opts)
  opts = opts or {}
  local self = setmetatable({}, Donut)
  self.name        = name
  self.size        = size
  self.mode        = opts.mode or "origin"
  self.origin_unit = opts.origin_unit or "rad"
  self.clockwise   = opts.clockwise ~= false
  self.texture     = opts.texture or RING_TEXTURE
  self.gap         = opts.gap or 0
  self.tier        = opts.tier
  self.layer       = opts.layer
  self.root        = WINDOW_MANAGER:CreateControl(name, parent, CT_CONTROL)
  self.root:SetDimensions(size, size)
  if self.tier then self.root:SetDrawTier(self.tier) end
  if self.layer then self.root:SetDrawLayer(self.layer) end
  self.slices      = {}
  self.n           = 0
  return self
end

local function slice(self, i)
  local c = self.slices[i]
  if c then return c end
  c = WINDOW_MANAGER:CreateControl(self.name .. "Slice" .. i, self.root, CT_COOLDOWN)
  c:SetAnchorFill(self.root)
  c:SetTexture(self.texture)
  c:SetRadialCooldownClockwise(self.clockwise)
  if self.tier then c:SetDrawTier(self.tier) end
  if self.layer then c:SetDrawLayer(self.layer) end
  self.slices[i] = c
  return c
end

function Donut:set(values, colors)
  local total = 0
  for i = 1, #values do
    local v = values[i] or 0
    if v > 0 then total = total + v end
  end
  local start = 0
  local n = 0
  local count = #values
  for i = 1, count do
    local v = values[i] or 0
    local share = (total > 0 and v > 0) and (v / total) or 0
    if share > 0 then
      n = n + 1
      local c = slice(self, n)
      local col = colors[i] or colors[#colors]
      c:SetFillColor(col.r, col.g, col.b, col.a or 1)
      if self.mode == "stack" then
        c:SetDrawLevel(count - i + 1)
        c:StartFixedCooldown(start + share, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_REMAINING, false)
      else
        c:SetDrawLevel(i)
        local scale = (self.origin_unit == "deg") and 360 or TAU
        c:SetRadialCooldownOriginAngle(start * scale)
        local visible = share - self.gap
        if visible < 0 then visible = 0 end
        c:StartFixedCooldown(visible, CD_TYPE_RADIAL, CD_TIME_TYPE_TIME_REMAINING, false)
      end
      c:SetHidden(false)
      start = start + share
    end
  end
  for i = n + 1, #self.slices do
    self.slices[i]:SetHidden(true)
  end
  self.n = n
  return n
end

function Donut:control() return self.root end
function Donut:count()   return self.n end
function Donut:set_hidden(h) self.root:SetHidden(h) end
