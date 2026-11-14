Vermilion = Vermilion or {}
Vermilion.lib = Vermilion.lib or {}
Vermilion.lib.plot = Vermilion.lib.plot or {}

local M = {}
Vermilion.lib.plot.Pool = M

local zui = Vermilion.zenimax.ui
local WINDOW_MANAGER  = zui.WINDOW_MANAGER

local Primitives = Vermilion.lib.plot.Primitives

local Pool = {}
Pool.__index = Pool

function Pool:AcquireObject()
  local i = self.used + 1
  local object = self[i]
  if not object then
    object = self.create(i)
    self[i] = object
  end
  self.used = i
  return object
end

function Pool:ReleaseAllObjects()
  local reset = self.reset
  for i = 1, self.used do reset(self[i]) end
  self.used = 0
end

function M.of(create, on_reset)
  return setmetatable({ used = 0, create = create, reset = on_reset or Primitives.clear }, Pool)
end

function M.new(name_prefix, parent, ctype, on_factory, on_reset)
  return M.of(function(i)
    local c = WINDOW_MANAGER:CreateControl(name_prefix .. i, parent, ctype)
    if on_factory then on_factory(c, i) end
    return c
  end, on_reset)
end

function M.new_virtual(name_prefix, parent, virtual_template, on_factory, on_reset)
  local CreateControlFromVirtual = zui.CreateControlFromVirtual
  return M.of(function(i)
    local c = CreateControlFromVirtual(name_prefix .. i, parent, virtual_template)
    if on_factory then on_factory(c, i) end
    return c
  end, on_reset)
end
