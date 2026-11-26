MWC.Report = {}

local C = MWC.COLOR
local Color = MWC.Colorize
local Name = MWC.ItemName

-- The window shows the problem as a red row plus a tooltip line, so it passes withoutProblem.
function MWC.Report.Warnings(group, withoutProblem)
  local text = ""
  if group.problem and not withoutProblem then
    text = text .. Color(C.RED, " [" .. group.problem .. "]")
  end
  local notMaxed = (group.type == "provisioning" and group.recipe and group.recipe.yield < MWC.Plan.MAX_YIELD)
    or (group.type == "alchemy" and MWC.Alchemy.IsChemistryBelowMax())
  if notMaxed then
    text = text .. Color(C.YELLOW, " [skill not maxed]")
  end
  if group.improvementNotMaxed then
    text = text .. Color(C.YELLOW, " [improvement skill not maxed]")
  end
  return text
end

function MWC.Report.AmountList(entries, hex)
  local parts = {}
  for _, entry in ipairs(entries) do
    local color = hex or (entry.have >= entry.need and C.GREY or C.RED)
    table.insert(parts, Color(color, string.format("%s %d/%d", Name(entry.link), entry.have, entry.need)))
  end
  return parts
end

-- "Bag (free now) → used after crafting / size".
-- totals.overflow: items wanted that the bag can't take (it ends full): red, and said so.
function MWC.Report.BagLine(totals)
  local overflow = totals.overflow or 0
  local fits = totals.usedAfter <= totals.bagSize and overflow == 0
  local after = Color(fits and C.GREEN or C.RED, tostring(totals.usedAfter))
  local line = string.format("Bag (%d) → %s / %d", totals.bagSize - totals.used, after, totals.bagSize)
  if overflow > 0 then
    line = line .. Color(C.RED, string.format("  ·  Inventory limit reached: %d don't fit", overflow))
  end
  return line
end

-- /mwc report: per craft one line of totals, then every writ group not ready yet (what is left to craft and
-- why it may not be crafted). Ready groups and the session history aren't listed.
local CRAFT_ORDER = { "blacksmithing", "clothier", "woodworking", "jewelry", "alchemy", "enchanting", "provisioning" }
local CRAFT_LABEL = {
  blacksmithing = "Blacksmithing", clothier = "Clothier", woodworking = "Woodworking", jewelry = "Jewelry",
  alchemy = "Alchemy", enchanting = "Enchanting", provisioning = "Provisioning",
}

function MWC.Report.Summary()
  local plan = MWC.Plan.Build()
  local byCraft = {}
  for _, group in ipairs(plan.groups) do
    if group.selectedCount > 0 then
      byCraft[group.type] = byCraft[group.type] or {}
      table.insert(byCraft[group.type], group)
    end
  end
  local any = false
  for _, craft in ipairs(CRAFT_ORDER) do
    local groups = byCraft[craft]
    if groups then
      any = true
      local totals = MWC.Plan.Totals(groups)
      local left = totals.writs - totals.ready
      local status = left == 0 and Color(C.GREEN, "all ready")
        or Color(C.YELLOW, string.format("%d not ready, %d crafts", left, totals.crafts))
      MWC.Print("%s: %d writs, %d ready, %s", CRAFT_LABEL[craft], totals.writs, totals.ready, status)
      for _, group in ipairs(groups) do
        local ready = group.ready or 0
        if ready < group.selectedCount or group.problem then
          MWC.Print("    %s: ready %d/%d, %d crafts%s", group.name or "?", ready, group.selectedCount, group.crafts or 0,
            MWC.Report.Warnings(group))
        end
      end
    end
  end
  if not any then
    MWC.Print("No queued writs.")
    return
  end
  if #plan.shortages > 0 then
    MWC.Print("Missing: %s", table.concat(MWC.Report.AmountList(plan.shortages, C.RED), ", "))
  end
  MWC.Print("%s", MWC.Report.BagLine(MWC.Plan.Totals(plan.groups)))
end
