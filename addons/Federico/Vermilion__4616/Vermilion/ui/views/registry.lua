Vermilion = Vermilion or {}
Vermilion.Views = {}
local M = Vermilion.Views

local V = Vermilion

M.list = {
  { label = "SKILL",     bars = true,  bands = true,  render = V.SkillView.render,     abilities = "eos_abilities" },
  { label = "TYPE",      bars = true,  bands = true,  render = V.TypeView.render,      abilities = "dtype_abilities", by_type = true },
  { label = "PRESSURE",  bars = false, bands = true,  render = V.TargetsView.render,   rows = V.TargetsView },
  { label = "CRIT",      bars = true,  bands = true,  render = V.CritView.render,      crit_moment = true },
  { label = "CONTRIB",   bars = false, bands = false, render = V.ContribView.render,   rows = V.ContribView },
  { label = "DEBUFFS",   bars = false, bands = false, render = V.DebuffsView.render,   rows = V.DebuffsView, empty = VERMILION_GRAPH_NO_DEBUFFS },
  { label = "RESOURCES", bars = false, bands = false, render = V.ResourcesView.render, rows = V.ResourcesView },
  { label = "UPTIME",    bars = false, bands = false, render = V.UptimeView.render,    rows = V.UptimeView },
}
