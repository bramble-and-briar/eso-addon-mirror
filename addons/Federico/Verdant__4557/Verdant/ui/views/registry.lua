Verdant = Verdant or {}
local Verdant = Verdant

Verdant.Views = {}
local M = Verdant.Views

local V = Verdant

M.list = {
  { key = "EMS",      label = "EMS",     render = V.EmsView.render, bars = true },
  { key = "SKILL",    label = "SKILL",   render = V.SkillView.render, bars = true },
  { key = "RESOURCES", label = "RESOURCES", render = V.ResourcesView.render,
    empty = "VERDANT_GRAPH_NO_RES" },
  { key = "OVERHEAL", label = "OHEAL",   render = V.OverhealView.render, legend = true, bars = true },
  { key = "SUSTAIN",  label = "SUSTAIN", render = V.RestoreView.render, bars = true, side = V.RestoreView.side,
    empty = "VERDANT_GRAPH_NO_RESTORES" },
  { key = "BUFFS",    label = "BUFFS",   render = V.BuffsView.render,
    empty = "VERDANT_GRAPH_NO_BUFFS" },
  { key = "CONTRIB",  label = "CONTRIB", render = V.ContribView.render },
}

M.index = {}
for i = 1, #M.list do
  M.index[M.list[i].key] = i
end
