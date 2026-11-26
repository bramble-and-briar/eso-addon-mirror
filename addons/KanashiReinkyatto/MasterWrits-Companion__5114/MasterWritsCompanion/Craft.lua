MWC.Craft = {}

local EVENT_NS = MWC.name .. "Craft"
-- Inventory counts update some time after the craft event: the check looks again every so often, up to a
-- limit, before calling a craft short.
-- No fixed pauses: the result is checked as soon as the game is done (polled every POLL_MS), for up to
-- SETTLE_LIMIT_MS.
local POLL_MS = 50
local SETTLE_LIMIT_MS = 4000
local WRIT_TYPE_BY_STATION = {
  [CRAFTING_TYPE_PROVISIONING] = "provisioning",
  [CRAFTING_TYPE_ALCHEMY] = "alchemy",
  [CRAFTING_TYPE_ENCHANTING] = "enchanting",
}

-- Only exists while crafting; nothing here is persisted.
local run = nil

local function StationWritType()
  return WRIT_TYPE_BY_STATION[GetCraftingInteractionType()]
end

-- The station's craft, gear stations included (they make holiday furnishings here).
local function StationCraft()
  return StationWritType() or MWC.GearCraft.StationWritType()
end

-- Made from a recipe (CraftProvisionerItem): food, and holiday writs' food or furnishings at any station.
local function FromRecipe(group)
  return group.type == "provisioning" or (group.event ~= nil and group.type ~= "alchemy")
end

-- Crafted in a run for this craft; at a gear station only holiday furnishings are (gear itself is GearCraft's).
local function Craftable(group, writType, eventOnly)
  if group.type ~= writType then return false end
  return not eventOnly or group.event ~= nil
end

function MWC.Craft.Stop(fmt, ...)
  if not run then return end
  run = nil
  EVENT_MANAGER:UnregisterForEvent(EVENT_NS, EVENT_CRAFT_COMPLETED)
  EVENT_MANAGER:UnregisterForEvent(EVENT_NS, EVENT_CRAFT_FAILED)
  EVENT_MANAGER:UnregisterForEvent(EVENT_NS, EVENT_END_CRAFTING_STATION_INTERACT)
  local message = fmt and string.format(fmt, ...)
  MWC.Activity.End(message)
  MWC.Activity.Notify(message)
end

local function CountResult(group)
  if FromRecipe(group) then
    return (MWC.Plan.CountItem(group.recipe.resultItemId))
  elseif group.type == "enchanting" then
    return MWC.Enchanting.CountResults(group)
  end
  return MWC.Alchemy.CountResults(group)
end

local function BackpackRoom(group)
  -- Crafting may fill the bag to the last slot; only withdrawing and opening containers keep slots free.
  local freeSlots = GetNumBagFreeSlots(BAG_BACKPACK)
  local room = freeSlots * (group.recipe.stackSize or MWC.Plan.FOOD_STACK_SIZE)
  if FromRecipe(group) then
    room = room + MWC.Plan.PartialStackRoom(group.recipe.resultItemId)
  end
  return room
end

local function MaxByIngredients(group)
  local max = math.huge
  for i, ingredient in ipairs(group.recipe.ingredients) do
    max = math.min(max, math.floor(group.ingredients[i].have / ingredient.quantity))
  end
  return max
end

-- Crafting can only use materials from the craft bag or the backpack, never the bank.
local function CraftSlot(itemId)
  local craftBagCount = GetSlotStackSize(BAG_VIRTUAL, itemId)
  if craftBagCount > 0 then
    return BAG_VIRTUAL, itemId, craftBagCount
  end
  local bestSlot, bestCount
  for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
    if GetItemId(BAG_BACKPACK, slot) == itemId then
      local count = GetSlotStackSize(BAG_BACKPACK, slot)
      if not bestCount or count > bestCount then
        bestSlot, bestCount = slot, count
      end
    end
  end
  if bestSlot then
    return BAG_BACKPACK, bestSlot, bestCount
  end
end

-- The planned reagents and order first, then every other combination with the right effects, cheapest
-- first: the station's preview must show the writ's name (see Alchemy.ChooseByResult). Returns the slots
-- (solvent first) and how many crafts they allow, or nil and why not.
local function AlchemySlots(group, amount)
  local solventId = MWC.Alchemy.SolventItemId(group.isPoison)
  local solventBag, solventSlot, solventCount = CraftSlot(solventId)
  if not solventBag then return nil, MWC.ItemName(MWC.LinkFromItemId(solventId)) .. " (bag or craft bag)" end
  local planned = {}
  for i = 2, #group.recipe.ingredients do
    table.insert(planned, group.recipe.ingredients[i].itemId)
  end
  local combos = { planned }
  for _, combo in ipairs(MWC.Plan.RankCombos(MWC.Alchemy.UsableCombos(group.effectKey), amount)) do
    table.insert(combos, combo)
  end
  -- Reagents from Keep materials are never used.
  local order, verdict, nameKey = MWC.Alchemy.ChooseByResult(solventId, MWC.Plan.WithoutKept(combos), group.effectKey,
    GenerateMasterWritBaseText(group.link), true, true)
  if verdict ~= "confirmed" then
    return nil, order and "the station shows no result preview"
      or ("no reagents you have make " .. group.name .. " without using Keep materials")
  end
  MWC.Alchemy.LearnName(group.key, nameKey)
  -- What is really crafted with: the plan and the session history follow it from now on.
  MWC.sv.alchemyCrafted = MWC.sv.alchemyCrafted or {}
  MWC.sv.alchemyCrafted[group.key] = order
  local slots, count = { { solventBag, solventSlot } }, math.min(amount, solventCount)
  for _, itemId in ipairs(order) do
    local bag, slot, stack = CraftSlot(itemId)
    table.insert(slots, { bag, slot })
    count = math.min(count, stack)
  end
  return slots, count
end

-- At an alchemy station every alchemy writ's reagents are checked by preview, so the plan becomes certain. Only
-- while the addon's window is open (opening it at the station does it too): daily writs and normal play at the
-- station cost nothing.
function MWC.Craft.LearnAlchemyNames()
  if GetCraftingInteractionType() ~= CRAFTING_TYPE_ALCHEMY or not MWC.UI.IsShown() then return end
  MWC.Timed("alchemy previews", function() MWC.Alchemy.LearnNames(MWC.Plan.Build().groups) end)
  MWC.UI.Refresh({ "alchemy" })
end

EVENT_MANAGER:RegisterForEvent(MWC.name .. "AlchemyNames", EVENT_CRAFTING_STATION_INTERACT, function(_, craftSkill)
  if craftSkill ~= CRAFTING_TYPE_ALCHEMY then return end
  zo_callLater(MWC.Craft.LearnAlchemyNames, 500)
end)

-- Returns how many crafts were requested, or 0 and why not; a third value true means only this writ is
-- ruled out (the station's preview disagrees) and the others can still be crafted.
local function StartCraft(group, amount)
  if FromRecipe(group) then
    CraftProvisionerItem(group.recipe.listIndex, group.recipe.recipeIndex, amount)
    return amount
  end
  if group.type == "alchemy" then
    local ordered, allowed = AlchemySlots(group, amount)
    if not ordered then
      return 0, allowed, true
    end
    local solvent, r1, r2, r3 = ordered[1], ordered[2], ordered[3], ordered[4] or {}
    CraftAlchemyItem(solvent[1], solvent[2], r1[1], r1[2], r2[1], r2[2], r3[1], r3[2], allowed)
    return allowed
  end
  local slots = {}
  for _, ingredient in ipairs(group.recipe.ingredients) do
    local bag, slot, count = CraftSlot(ingredient.itemId)
    if not bag then
      return 0, MWC.ItemName(ingredient.link)
    end
    amount = math.min(amount, count)
    table.insert(slots, { bag, slot })
  end
  local potency, essence, aspect = slots[1], slots[2], slots[3]
  -- The runes decide the glyph; the station's preview confirms it is the writ's (kind, quality, level).
  local ok, preview = pcall(GetEnchantingResultingItemLink, potency[1], potency[2], essence[1], essence[2],
    aspect[1], aspect[2], LINK_STYLE_DEFAULT)
  if ok and preview and preview ~= "" then
    local key = MWC.Enchanting.IndexKey(GetItemLinkItemId(preview), GetItemLinkFunctionalQuality(preview),
      GetItemLinkRequiredChampionPoints(preview))
    if key ~= group.indexKey then
      return 0, "the station would make " .. MWC.ItemName(preview) .. ", not the writ's glyph", true
    end
  end
  CraftEnchantingItem(potency[1], potency[2], essence[1], essence[2], aspect[1], aspect[2], amount)
  return amount
end

-- What an alchemy craft made instead of the writ's potion, kept in SavedVariables (alchemyMismatch) so the
-- reagent data can be checked: the writ, the reagents used with the effects the table gives them, and what
-- appeared in the bags.
function MWC.Craft.RecordAlchemyMismatch(group, before)
  local reagents = {}
  for _, ingredient in ipairs(group.recipe.ingredients) do
    local effects = MWC.Alchemy.ReagentEffects(ingredient.itemId)
    table.insert(reagents, string.format("%d %s {%s}", ingredient.itemId, MWC.ItemName(ingredient.link),
      effects and table.concat(effects, ",") or "solvent"))
  end
  local gained = {}
  for key, entry in pairs(MWC.Alchemy.PotionIndex()) do
    local was = before[key]
    local delta = entry.bag + entry.bank - (was and (was.bag + was.bank) or 0)
    if delta > 0 then
      table.insert(gained, string.format("%s +%d", key, delta))
    end
  end
  MWC.Log("Alchemy mismatch: %s, expected %s, reagents %s, gained %s", group.link, tostring(group.effectKey),
    table.concat(reagents, "; "), #gained > 0 and table.concat(gained, "; ") or "nothing")
  MWC.sv.alchemyMismatch = {
    writ = group.link, name = group.name, writFields = table.concat(group.writs[1].fields, ":"),
    expectedKey = group.effectKey, reagents = reagents, gained = gained,
  }
end

local function Finish()
  local names = {}
  for _, name in pairs(run.skipped) do
    table.insert(names, name)
  end
  -- The run's cap reached while the plan still wants crafts: said as it is, never "everything is crafted".
  local left = {}
  for _, group in ipairs(MWC.Plan.Build().groups) do
    if Craftable(group, run.writType, run.eventOnly) and group.recipe and group.recipe.known and group.crafts > 0
        and not run.skipped[group.key] then
      table.insert(left, string.format("%s (%d more)", group.name, group.crafts))
      MWC.Log("Craft: after the run %s still needs %d crafts, have %s of %s", group.name, group.crafts,
        tostring(group.have), tostring(group.required))
    end
  end
  if #left > 0 then
    MWC.Craft.Stop("Stopped at the run's limit. Still to craft: %s. Craft again.", table.concat(left, "; "))
  elseif #names > 0 then
    MWC.Craft.Stop("Done. Skipped: %s", table.concat(names, "; "))
  else
    MWC.Craft.Stop("Done, everything is crafted.")
  end
end

-- Crafting order: name A-Z, the same order as the list sorted by its name column, so the writs can be watched
-- getting done one after another. The key settles writs with equal names.
local function CraftOrder(a, b)
  local nameA, nameB = zo_strlower(a.name or ""), zo_strlower(b.name or "")
  if nameA ~= nameB then return nameA < nameB end
  return a.key < b.key
end

local function NextStep()
  if not run then return end
  if StationCraft() ~= run.writType then
    MWC.Craft.Stop("Station closed, crafting stopped.")
    return
  end

  local groups = {}
  for _, group in ipairs(MWC.Plan.Build().groups) do
    table.insert(groups, group)
  end
  table.sort(groups, CraftOrder)
  for _, group in ipairs(groups) do
    local recipe = group.recipe
    local allowed = run.total - run.done
    if Craftable(group, run.writType, run.eventOnly) and recipe and recipe.known and group.crafts > 0 and allowed > 0
        and not run.skipped[group.key] then
      -- Alchemy may switch to another reagent combination at the station, so its stacks limit it there.
      local byIngredients = group.type == "alchemy" and math.huge or MaxByIngredients(group)
      if group.kept then
        -- Keep materials is a veto: writs that would spend them are never crafted.
        run.skipped[group.key] = group.name .. " (spends Keep materials)"
      elseif byIngredients == 0 then
        run.skipped[group.key] = group.name .. " (missing materials)"
      else
        local fit = math.floor(BackpackRoom(group) / recipe.yield)
        if fit == 0 then
          MWC.Craft.Stop("Bag full. Free some slots and craft again.")
          return
        end
        local before = CountResult(group)
        local potionsBefore = group.type == "alchemy" and MWC.Alchemy.PotionIndex() or nil
        local crafted, missing, skipOnly = StartCraft(group, math.min(group.crafts, allowed, byIngredients, fit))
        if crafted == 0 and skipOnly then
          -- The station's preview rules this writ out: the other writs still get crafted.
          run.skipped[group.key] = string.format("%s (%s)", group.name, missing)
        elseif crafted == 0 then
          -- A material outside the bag and craft bag (bank items can't be used) sets only this writ aside.
          run.skipped[group.key] = string.format("%s (%s must be in the bag or craft bag)", group.name, missing)
        else
          run.current = { group = group, amount = crafted, before = before, potionsBefore = potionsBefore }
          MWC.Activity.Progress(run.done, string.format("Crafting %s ×%d…", group.name, crafted))
          -- The list catches up once the craft is under way, so it doesn't hold up its start.
          -- Only the crafts the bag changes marked (the station's craft) are worked out again.
          zo_callLater(function() MWC.UI.Refresh(true) end, 100)
          return
        end
      end
    end
  end

  Finish()
end

local function Verify()
  if not run or not run.current then return end
  local current = run.current
  if IsPerformingCraftProcess() then
    zo_callLater(function() if run and run.current == current then Verify() end end, POLL_MS)
    return
  end
  local group = current.group
  local gained = CountResult(group) - current.before
  local expected = current.amount * group.recipe.yield
  current.waited = (current.waited or 0)
  if gained < expected and current.waited < SETTLE_LIMIT_MS then
    current.waited = current.waited + POLL_MS
    zo_callLater(function() if run and run.current == current then Verify() end end, POLL_MS)
    return
  end
  run.current = nil

  run.crafted[group.key] = (run.crafted[group.key] or 0) + current.amount
  run.done = run.done + current.amount
  MWC.Activity.Progress(run.done)

  if gained ~= expected then
    -- Only this writ is set aside (its details are kept for checking); the others are still crafted.
    if current.potionsBefore then
      MWC.Craft.RecordAlchemyMismatch(group, current.potionsBefore)
    end
    run.skipped[group.key] = string.format("%s (expected %d, got %d: details in SavedVariables)", group.name,
      expected, gained)
  end
  NextStep()
end

local function OnCraftCompleted(_, craftSkill)
  if run and run.current and craftSkill == run.craftSkill then
    Verify()
  end
end

local function OnCraftFailed(_, result)
  MWC.Craft.Stop("Crafting failed: %s", GetString("SI_TRADESKILLRESULT", result))
end

local function OnStationClosed()
  MWC.Craft.Stop("Station closed, crafting stopped.")
end

function MWC.Craft.Start()
  if run then
    MWC.Print("Already crafting. Press Stop in the window to stop.")
    return
  end
  -- At a gear station: holiday furnishings first when there are any to make, else gear.
  local writType, eventOnly = StationWritType(), false
  local gearType = MWC.GearCraft.StationWritType()
  if gearType then
    local furnishings = false
    for _, group in ipairs(MWC.Plan.Build().groups) do
      if Craftable(group, gearType, true) and group.recipe and group.recipe.known and group.crafts > 0 then
        furnishings = true
      end
    end
    if not furnishings then
      MWC.GearCraft.Start()
      return
    end
    writType, eventOnly = gearType, true
  end
  if not writType then
    MWC.Print("Open a crafting station first.")
    return
  end

  -- Hard cap for the whole run, what the plan counts at the start: protects against endless crafting if
  -- counting ever goes wrong. Not per writ: alchemy writs wanting the same potion share one pool, so crafting
  -- one of them can move crafts between them (one takes the other's spare potions), never add to the total.
  local total = 0
  for _, group in ipairs(MWC.Plan.Build().groups) do
    if Craftable(group, writType, eventOnly) and group.recipe and group.crafts > 0 then
      total = total + group.crafts
    end
  end
  if total == 0 then
    MWC.Print("Nothing to craft here.")
    return
  end
  if not MWC.Activity.Begin("Crafting", total, function() MWC.Craft.Stop("Crafting stopped.") end, true) then return end
  run = { writType = writType, eventOnly = eventOnly, craftSkill = GetCraftingInteractionType(), crafted = {},
    total = total, skipped = {}, done = 0 }

  EVENT_MANAGER:RegisterForEvent(EVENT_NS, EVENT_CRAFT_COMPLETED, OnCraftCompleted)
  EVENT_MANAGER:RegisterForEvent(EVENT_NS, EVENT_CRAFT_FAILED, OnCraftFailed)
  EVENT_MANAGER:RegisterForEvent(EVENT_NS, EVENT_END_CRAFTING_STATION_INTERACT, OnStationClosed)
  NextStep()
end
