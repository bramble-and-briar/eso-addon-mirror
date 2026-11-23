
Verdant = Verdant or {}
local Verdant = Verdant
Verdant.lib = Verdant.lib or {}
Verdant.lib.plot = Verdant.lib.plot or {}

local M = {}
Verdant.lib.plot.Pool = M

local zui = Verdant.zenimax.ui
local WINDOW_MANAGER  = zui.WINDOW_MANAGER
local ZO_ObjectPool   = zui.ZO_ObjectPool

local Primitives = Verdant.lib.plot.Primitives

function M.new(name_prefix, parent, ctype, on_factory, on_reset)
  local counter = 0
  return ZO_ObjectPool:New(
    function()
      counter = counter + 1
      local c = WINDOW_MANAGER:CreateControl(name_prefix .. counter, parent, ctype)
      if on_factory then on_factory(c, counter) end
      return c
    end,

    function(c)
      if on_reset then on_reset(c)
      else Primitives.clear(c) end
    end
  )
end
