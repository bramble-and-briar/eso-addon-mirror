-- Crafting blacksmithing, clothing, woodworking and jewelry writ items at a set station or a consolidated
-- station: one item at a time, then improved step by step to the writ's quality with a sure (100%) chance.
-- Every item is checked against the writ before crafting (result preview) and after (the finished item).
MWC.GearCraft = {}

local EVENT_NS = MWC.name .. "GearCraft"
-- No fixed pauses: the next step starts as soon as the game is done (polled every POLL_MS), and gives up
-- after SETTLE_LIMIT_MS.
local POLL_MS, SETTLE_LIMIT_MS = 50, 4000
local MAX_BOOSTERS = 20
local WRIT_TYPE_BY_STATION = {
  [CRAFTING_TYPE_BLACKSMITHING] = "blacksmithing",
  [CRAFTING_TYPE_CLOTHIER] = "clothier",
  [CRAFTING_TYPE_WOODWORKING] = "woodworking",
  [CRAFTING_TYPE_JEWELRYCRAFTING] = "jewelry",
}

-- Only exists while crafting; nothing here is persisted.
local run = nil

function MWC.GearCraft.StationWritType()
  return WRIT_TYPE_BY_STATION[GetCraftingInteractionType()]
end

function MWC.GearCraft.Stop(fmt, ...)
  if not run then return end
  run = nil
  EVENT_MANAGER:UnregisterForEvent(EVENT_NS, EVENT_CRAFT_COMPLETED)
  EVENT_MANAGER:UnregisterForEvent(EVENT_NS, EVENT_CRAFT_FAILED)
  EVENT_MANAGER:UnregisterForEvent(EVENT_NS, EVENT_END_CRAFTING_STATION_INTERACT)
  EVENT_MANAGER:UnregisterForEvent(EVENT_NS, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
  local message = fmt and string.format(fmt, ...)
  MWC.Activity.End(message)
  MWC.Activity.Notify(message)
end

local function IsConsolidatedStation()
  return ZO_Smithing_IsConsolidatedStationCraftingMode and ZO_Smithing_IsConsolidatedStationCraftingMode() or false
end

local function ConsolidatedIndex(setId)
  for i = 1, GetNumConsolidatedSmithingSets() do
    if GetConsolidatedSmithingItemSetIdByIndex(i) == setId then
      return i
    end
  end
end

local function Log(fmt, ...)
  MWC.Log("Gear: " .. fmt, ...)
end

-- Makes the writ's set craftable here. Returns nil or the reason it can't be.
local function SelectSet(setId)
  if IsConsolidatedStation() then
    local index = ConsolidatedIndex(setId)
    if not index then return "set not available at this station" end
    if not IsConsolidatedSmithingItemSetIdUnlocked(setId) then return "set not unlocked at this station" end
    if GetActiveConsolidatedSmithingItemSetId() ~= setId then
      SetActiveConsolidatedSmithingSetByIndex(index)
    end
    if GetActiveConsolidatedSmithingItemSetId() ~= setId then
      return string.format("the station didn't switch to the set (active %d)", GetActiveConsolidatedSmithingItemSetId())
    end
  end
  if not CanSmithingSetPatternsBeCraftedHere(setId) then return "needs this set's crafting station" end
end

local function Owned(link)
  local backpack, _, craftBag = GetItemLinkStacks(link)
  return backpack + craftBag
end

-- Why the game refuses the craft: the first missing thing we can name.
local function MissingReason(group, fields, pattern, materialIndex, quantity)
  if fields[6] > 0 and MWC.Gear.IsStyleKnown(fields[6], fields[1]) == false then return "style not known for this piece" end
  if MWC.Gear.TraitResearch(fields) == false then return "trait not researched on this item" end
  local materialLink = GetSmithingPatternMaterialItemLink(pattern, materialIndex, LINK_STYLE_BRACKETS)
  if materialLink and materialLink ~= "" and Owned(materialLink) < quantity then
    return "not enough " .. MWC.ItemName(materialLink) .. " in bag or craft bag"
  end
  local traitStone = MWC.KeyItems.TraitStone(fields[5])
  if traitStone and Owned(traitStone) < 1 then return "no " .. MWC.ItemName(traitStone) .. " in bag or craft bag" end
  local styleMaterial = group.mimic and MWC.LinkFromItemId(MWC.Gear.MIMIC_STONE_ID) or MWC.KeyItems.StyleMaterial(fields[6])
  if styleMaterial and Owned(styleMaterial) < 1 then return "no " .. MWC.ItemName(styleMaterial) .. " in bag or craft bag" end
  return "the game refuses to craft it"
end

-- Everything needed to craft one item for the group, or nil and the reason it can't be crafted here.
local function Prepare(group)
  local fields = group.writs[1].fields
  local problem = SelectSet(fields[4])
  if problem then return nil, problem end
  local pattern, materialIndex, setItemId = GetSmithingPatternInfoForItemSet(fields[1], fields[4], fields[2])
  if not pattern or not materialIndex then return nil, "no matching pattern at this station" end
  MWC.Gear.RememberItemKind(setItemId, MWC.Gear.WritKind(fields))
  -- The set's trait requirement is known here only: remember it for planning, and stop at it.
  local _, _, _, _, traitsRequired, traitsKnown = GetSmithingPatternInfo(pattern)
  MWC.Gear.RememberSetTraits(fields[4], traitsRequired)
  if traitsRequired and traitsKnown and traitsKnown < traitsRequired then
    return nil, string.format("set needs %d traits researched on this item (%d)", traitsRequired, traitsKnown)
  end
  local quantity = select(3, GetSmithingPatternMaterialItemInfo(pattern, materialIndex))
  -- Sixth value: use the universal style item (Crown Mimic Stone) instead of the style material.
  local craft = { pattern, materialIndex, quantity, fields[6], fields[5] + 1, group.mimic == true, 1 }
  local iterations = GetMaxIterationsPossibleForSmithingItem(unpack(craft))
  if iterations < 1 then
    return nil, MissingReason(group, fields, pattern, materialIndex, quantity)
  end
  -- The preview must be exactly the writ's item at the crafted (lowest) quality.
  local preview = GetSmithingPatternResultLink(craft[1], craft[2], craft[3], craft[4], craft[5], LINK_STYLE_BRACKETS)
  local expected = MWC.Gear.IndexKey(MWC.Gear.WritKind(fields), fields[4], fields[5], fields[6], 0)
  if preview == "" or MWC.Gear.LinkKey(preview, 0) ~= expected
      or GetItemLinkRequiredChampionPoints(preview) ~= MWC.Gear.REQUIRED_CP then
    Log("Preview %s: key %s, CP %d; expected %s, CP %d", preview, preview ~= "" and MWC.Gear.LinkKey(preview, 0) or "-",
      preview ~= "" and GetItemLinkRequiredChampionPoints(preview) or 0, expected, MWC.Gear.REQUIRED_CP)
    return nil, "the station would craft " .. (preview ~= "" and preview or "nothing") .. ", not the writ's item", true
  end
  return { craft = craft, preview = preview }
end

-- Unique ids of the backpack items that could be this group's item, before crafting it.
local function MatchingIds(group)
  local ids = {}
  local wanted = MWC.Gear.IndexKey(MWC.Gear.WritKind(group.writs[1].fields), group.writs[1].fields[4],
    group.writs[1].fields[5], group.writs[1].fields[6], 0)
  for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
    local link = GetItemLink(BAG_BACKPACK, slot, LINK_STYLE_DEFAULT)
    if link ~= "" and MWC.Gear.IsWritGrade(link) and MWC.Gear.LinkKey(link, 0) == wanted then
      ids[Id64ToString(GetItemUniqueId(BAG_BACKPACK, slot))] = slot
    end
  end
  return ids
end

local function FindById(id)
  for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
    if Id64ToString(GetItemUniqueId(BAG_BACKPACK, slot)) == id then
      return slot
    end
  end
end

-- An item of this group crafted earlier but not improved to the writ's quality (crafting was interrupted between
-- the craft and the last improvement): finishing it saves a new craft. Never taken: items the writ wouldn't take
-- (crafted by another character), locked items, and items that already are the finished item of another writ.
local function FindUnfinished(group, readyKeys)
  local fields = group.writs[1].fields
  local wanted = MWC.Gear.IndexKey(MWC.Gear.WritKind(fields), fields[4], fields[5], fields[6], 0)
  for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
    local link = GetItemLink(BAG_BACKPACK, slot, LINK_STYLE_DEFAULT)
    if link ~= "" and MWC.Gear.IsWritGrade(link) and MWC.Gear.LinkKey(link, 0) == wanted
        and GetItemFunctionalQuality(BAG_BACKPACK, slot) < fields[3]
        and not readyKeys[MWC.Gear.LinkKey(link)]
        and not IsItemPlayerLocked(BAG_BACKPACK, slot)
        and MWC.Gear.IsMine(BAG_BACKPACK, slot) then
      return Id64ToString(GetItemUniqueId(BAG_BACKPACK, slot)), link
    end
  end
end

-- Crafting order: set name A-Z, then item name, the same order as the list sorted by its Set column, so the
-- writs can be watched getting done one after another. The key settles writs with equal names.
local function CraftOrder(a, b)
  local setA, setB = zo_strlower(a.setName or ""), zo_strlower(b.setName or "")
  if setA ~= setB then return setA < setB end
  local nameA, nameB = zo_strlower(a.name or ""), zo_strlower(b.name or "")
  if nameA ~= nameB then return nameA < nameB end
  return a.key < b.key
end

local NextStep

-- Sets the current writ aside with the reason and goes on with the others; the list is shown at the end.
local function SkipCurrent(reason)
  local group = run.current.group
  Log("Skip %s: %s", group.name, reason)
  run.skipped[group.key] = string.format("%s (%s)", group.name, reason)
  run.current = nil
  NextStep()
end

local function FinishItem()
  local current = run.current
  local slot = FindById(current.id)
  local link = slot and GetItemLink(BAG_BACKPACK, slot, LINK_STYLE_BRACKETS)
  if not slot or MWC.Gear.SlotIndexKey(BAG_BACKPACK, slot) ~= current.group.indexKey then
    Log("Finished %s: key %s, expected %s", link or "(not found)",
      slot and tostring(MWC.Gear.SlotIndexKey(BAG_BACKPACK, slot)) or "-", current.group.indexKey)
    SkipCurrent(string.format("the finished item %s doesn't match the writ", link or "(not found)"))
    return
  end
  run.current = nil
  run.made[current.group.key] = (run.made[current.group.key] or 0) + 1
  run.done = run.done + 1
  MWC.Activity.Progress(run.done)
  NextStep()
  -- After the next craft is sent: the row shows the item as made (visible rows only, cheap).
  MWC.UI.CountMade(current.group.key, 1)
end

-- One quality step with as many boosters as a sure step takes, or the finish when the writ's quality is reached.
local function Improve()
  local current = run.current
  local slot = FindById(current.id)
  if not slot then
    SkipCurrent("lost track of the crafted item")
    return
  end
  local quality = GetItemFunctionalQuality(BAG_BACKPACK, slot)
  local target = current.group.writs[1].fields[3]
  if quality >= target then
    FinishItem()
    return
  end
  if CanItemBeSmithingImproved and not CanItemBeSmithingImproved(BAG_BACKPACK, slot, run.craftType) then
    SkipCurrent(string.format("the game can't improve the item at quality %d", quality))
    return
  end
  local boosters, chance = 0, 0
  while chance < 100 and boosters < MAX_BOOSTERS do
    boosters = boosters + 1
    chance = GetSmithingImprovementChance(BAG_BACKPACK, slot, boosters, run.craftType)
  end
  if chance < 100 then
    SkipCurrent("no sure improvement step possible: improvement skill too low?")
    return
  end
  local name, _, owned = GetSmithingImprovementItemInfo(run.craftType, quality)
  if (owned or 0) < boosters then
    SkipCurrent(string.format("not enough %s: %d needed, %d owned", zo_strformat("<<1>>", name or "?"),
      boosters, owned or 0))
    return
  end
  current.phase = "improve"
  current.qualityBefore, current.waited = quality, 0
  MWC.Activity.Progress(run.done, string.format("Improving %s (%d → %d)…", current.group.name, quality, quality + 1))
  ImproveSmithingItem(BAG_BACKPACK, slot, boosters)
end

local function AfterCraft()
  local current = run.current
  -- Usually already known from the bag's new-item event; otherwise looked for among the matching items.
  local id = current.newId
  if not id then
    for candidate in pairs(MatchingIds(current.group)) do
      if not current.before[candidate] then
        id = candidate
      end
    end
  end
  -- The new item can take a moment to show up in the bag.
  if not id and (current.waited or 0) < SETTLE_LIMIT_MS then
    current.waited = (current.waited or 0) + POLL_MS
    zo_callLater(function() if run and run.current == current then AfterCraft() end end, POLL_MS)
    return
  end
  if not id then
    SkipCurrent("the crafted item was not found in the bag")
    return
  end
  current.id = id
  local slot = FindById(id)
  Improve()
end

NextStep = function()
  if not run then return end
  if MWC.GearCraft.StationWritType() ~= run.writType then
    MWC.GearCraft.Stop("Station closed, crafting stopped.")
    return
  end

  local readyKeys = run.readyKeys
  for _, group in ipairs(run.groups) do
    local left = (run.limit[group.key] or 0) - (run.made[group.key] or 0)
    if group.event then
      -- Holiday furnishings are made from a recipe (Craft.lua), not as gear.
    elseif group.type == run.writType and left > 0 and not run.skipped[group.key] and group.kept then
      -- Keep materials is a veto: writs that would spend them are never crafted.
      run.skipped[group.key] = group.name .. " (spends Keep materials)"
    elseif group.type == run.writType and left > 0 and not run.skipped[group.key] then
      local unfinishedId, unfinishedLink = FindUnfinished(group, readyKeys)
      if unfinishedId then
        Log("Resume %s: improving %s crafted earlier", group.name, unfinishedLink)
        run.current = { group = group, phase = "improve", id = unfinishedId }
        Improve()
        return
      end
      if GetNumBagFreeSlots(BAG_BACKPACK) == 0 then
        MWC.GearCraft.Stop("Bag full. Free some slots and craft again.")
        return
      end
      local job, reason = Prepare(group)
      if not job then
        run.skipped[group.key] = string.format("%s (%s)", group.name, reason)
      else
        local fields = group.writs[1].fields
        run.current = { group = group, phase = "craft", before = MatchingIds(group),
          wanted = MWC.Gear.IndexKey(MWC.Gear.WritKind(fields), fields[4], fields[5], fields[6], 0) }
        MWC.Activity.Progress(run.done, string.format("Crafting %s…", group.name))
        CraftSmithingItem(unpack(job.craft))
        return
      end
    end
  end

  local skipped = {}
  for _, text in pairs(run.skipped) do
    table.insert(skipped, text)
  end
  if #skipped > 0 then
    MWC.GearCraft.Stop("Done. Skipped: %s", table.concat(skipped, "; "))
  else
    MWC.GearCraft.Stop("Done, every queued item is crafted.")
  end
end

local function AfterCraftEvent(current)
  if not run or run.current ~= current then return end
  -- The station may still be busy right after the event: look again shortly.
  if IsPerformingCraftProcess() then
    zo_callLater(function() AfterCraftEvent(current) end, POLL_MS)
    return
  end
  if current.phase == "craft" then
    AfterCraft()
    return
  end
  -- Improvement: go on once the item shows the new quality; never improve again on a stale reading.
  local slot = FindById(current.id)
  if slot and GetItemFunctionalQuality(BAG_BACKPACK, slot) == current.qualityBefore then
    if current.waited < SETTLE_LIMIT_MS then
      current.waited = current.waited + POLL_MS
      zo_callLater(function() AfterCraftEvent(current) end, POLL_MS)
    else
      SkipCurrent("the improvement didn't show on the item")
    end
    return
  end
  Improve()
end

local function OnCraftCompleted(_, craftSkill)
  if run and run.current and craftSkill == run.craftType then
    AfterCraftEvent(run.current)
  end
end

-- The crafted item, as soon as it lands in the bag (saves searching the bag for it).
local function OnSlotUpdate(_, bag, slot, isNewItem)
  local current = run and run.current
  if not (current and current.phase == "craft" and isNewItem) or current.newId or bag ~= BAG_BACKPACK then return end
  local link = GetItemLink(BAG_BACKPACK, slot, LINK_STYLE_DEFAULT)
  if MWC.Gear.IsWritGrade(link) and MWC.Gear.LinkKey(link, 0) == current.wanted then
    current.newId = Id64ToString(GetItemUniqueId(BAG_BACKPACK, slot))
  end
end

local function OnCraftFailed(_, result)
  Log("Craft failed: result %s, current %s, phase %s", tostring(result),
    run and run.current and run.current.group.name or "-", run and run.current and run.current.phase or "-")
  MWC.GearCraft.Stop("Crafting failed: %s", GetString("SI_TRADESKILLRESULT", result))
end

local function OnStationClosed()
  MWC.GearCraft.Stop("Station closed, crafting stopped.")
end

function MWC.GearCraft.Start()
  if run then
    MWC.Print("Already crafting. Press Stop in the window to stop.")
    return
  end
  local writType = MWC.GearCraft.StationWritType()
  if not writType then return end

  -- Hard cap per writ group for this run: never more items than the queued writs still need. The plan is
  -- built once here: what is made is counted in run.made, so it isn't rebuilt before every item.
  local limit, total, groups, readyKeys = {}, 0, {}, {}
  for _, group in ipairs(MWC.Plan.Build().groups) do
    table.insert(groups, group)
    if group.indexKey then readyKeys[group.indexKey] = true end
    if group.type == writType and not group.problem and not group.event then
      local left = math.max(0, group.selectedCount - (group.have or 0))
      limit[group.key] = left
      total = total + left
    end
  end
  if total == 0 then
    MWC.Print("Nothing to craft here.")
    return
  end
  Log("Start at %s: %d items, consolidated %s, active set %s, %d tempers for a sure gold step", writType, total,
    tostring(IsConsolidatedStation()),
    IsConsolidatedStation() and tostring(GetActiveConsolidatedSmithingItemSetId()) or "-",
    MWC.Gear.BoostersForStep(writType, 4))
  if not MWC.Activity.Begin("Crafting", total,
      function() MWC.GearCraft.Stop("Crafting stopped.") end, true) then return end
  run = {
    writType = writType, craftType = GetCraftingInteractionType(), limit = limit, made = {}, skipped = {},
    done = 0, groups = groups, readyKeys = readyKeys,
  }
  table.sort(groups, CraftOrder)
  EVENT_MANAGER:RegisterForEvent(EVENT_NS, EVENT_CRAFT_COMPLETED, OnCraftCompleted)
  EVENT_MANAGER:RegisterForEvent(EVENT_NS, EVENT_CRAFT_FAILED, OnCraftFailed)
  EVENT_MANAGER:RegisterForEvent(EVENT_NS, EVENT_END_CRAFTING_STATION_INTERACT, OnStationClosed)
  EVENT_MANAGER:RegisterForEvent(EVENT_NS, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnSlotUpdate)
  EVENT_MANAGER:AddFilterForEvent(EVENT_NS, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
  NextStep()
end
