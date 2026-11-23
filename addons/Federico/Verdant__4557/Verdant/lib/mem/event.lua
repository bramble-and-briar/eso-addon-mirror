Verdant = Verdant or {}
local Verdant = Verdant
Verdant.lib = Verdant.lib or {}
Verdant.lib.mem = Verdant.lib.mem or {}

local Event = {}
Verdant.lib.mem.Event = Event

function Event.factory()
  return {
    t              = 0,
    kind           = 0,
    result         = 0,
    amount         = 0,
    target_unit_id = 0,
    target_type    = 0,
    ability_id     = 0,

  }
end
