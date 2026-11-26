MWC.Sealed = {}

local EVENT_NS = MWC.name .. "Sealed"
local POLL_MS = 50
-- Using an item starts a short cooldown; a use during it is silently ignored, so wait it out and retry.
local ATTEMPT_TIMEOUT_MS = 1500
local MAX_ATTEMPTS = 3
local COOLDOWN_WAIT_LIMIT_MS = 5000
local SCAN_BAGS = { BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }
-- "Unknown <Craft> Writ" containers, one per craft. 217917, 217918, 217922, 217923 are verified in game;
-- the ids in between follow the same sequence.
local SEALED_IDS = { 217917, 217918, 217919, 217920, 217921, 217922, 217923 }

local IS_SEALED = {}
for _, id in ipairs(SEALED_IDS) do
  IS_SEALED[id] = true
end

local run = nil

function MWC.Sealed.IsSealedSlot(bag, slot)
  return IS_SEALED[GetItemId(bag, slot)] == true
end

-- Per-kind choice of what to open: { enabled = bool, count = n or nil (nil = as many as fit) }.
local function Choice(itemId)
  local choices = MWC.sv.sealedChoices
  choices[itemId] = choices[itemId] or { enabled = true }
  return choices[itemId]
end

-- One row per container kind with how many will be opened: { itemId, link, name, inBag, inBank, planned }.
-- Kinds are planned in display order; each opened writ takes one bag slot.
function MWC.Sealed.Scan()
  local byId, rows = {}, {}
  for _, at in ipairs(MWC.ItemSlots(SCAN_BAGS)) do
    local bag, slot = at[1], at[2]
    local id = GetItemId(bag, slot)
    if IS_SEALED[id] then
      local row = byId[id]
      if not row then
        local link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
        row = { itemId = id, link = link, name = MWC.ItemName(link), inBag = 0, inBank = 0 }
        byId[id] = row
        table.insert(rows, row)
      end
      local count = GetSlotStackSize(bag, slot)
      if bag == BAG_BACKPACK then
        row.inBag = row.inBag + count
      else
        row.inBank = row.inBank + count
      end
    end
  end
  table.sort(rows, function(a, b) return a.name < b.name end)

  -- Opening may fill the bag to the last slot.
  local capacity = GetNumBagFreeSlots(BAG_BACKPACK)
  for _, row in ipairs(rows) do
    local choice = Choice(row.itemId)
    row.enabled = choice.enabled
    local wanted = choice.enabled and math.min(choice.count or row.inBag, row.inBag) or 0
    row.planned = math.min(wanted, capacity)
    -- Wanted but no bag slot left for them: shown, so a "+" that can't be pressed has its reason.
    row.overflow = wanted - row.planned
    capacity = capacity - row.planned
  end
  for _, row in ipairs(rows) do
    row.canIncrease = row.planned < row.inBag and capacity > 0
  end
  return rows
end

-- Enabling always means "as many as fit"; a manual count only comes from the -/+ buttons.
local function SetChoiceEnabled(itemId, enabled)
  local choice = Choice(itemId)
  choice.enabled = enabled
  if enabled then
    choice.count = nil
  end
end

function MWC.Sealed.SetEnabled(itemId, enabled)
  SetChoiceEnabled(itemId, enabled)
  MWC.UI.Refresh("view")
end

function MWC.Sealed.SetAllEnabled(rows, enabled)
  for _, row in ipairs(rows) do
    SetChoiceEnabled(row.itemId, enabled)
  end
  MWC.UI.Refresh("view")
end

function MWC.Sealed.SetCount(row, count)
  local choice = Choice(row.itemId)
  choice.count = zo_clamp(count, 0, row.inBag)
  choice.enabled = choice.count > 0
  MWC.UI.Refresh("view")
end

-- Progress of the current run for one kind: opened, planned. Nil when nothing is being opened.
function MWC.Sealed.RunProgress(itemId)
  if not run then return nil end
  local entry = run.byId[itemId]
  if not entry then return nil end
  return entry.opened, entry.planned
end

local function Finish(message)
  EVENT_MANAGER:UnregisterForUpdate(EVENT_NS)
  EVENT_MANAGER:UnregisterForEvent(EVENT_NS, EVENT_LOOT_UPDATED)
  local opened = run and run.opened or 0
  run = nil
  MWC.Activity.End(message)
  MWC.Activity.Notify(string.format("%s Opened %d.", message, opened))
  MWC.UI.Refresh("view")
end

local function SlotOf(itemId)
  for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
    if GetItemId(BAG_BACKPACK, slot) == itemId then
      return slot
    end
  end
end

local function CanUseItems()
  return not IsUnitInCombat("player") and not IsLooting() and GetInteractionType() == INTERACTION_NONE
end

local function NextEntry()
  for _, entry in ipairs(run.entries) do
    if entry.opened < entry.planned then
      return entry
    end
  end
end

local function Step()
  if not run then return end
  local entry = NextEntry()
  if not entry then
    Finish("Done.")
    return
  end
  if GetNumBagFreeSlots(BAG_BACKPACK) == 0 then
    Finish("Bag is full.")
    return
  end
  if not CanUseItems() then
    Finish("Stopped: can't open containers right now (combat, looting or an open interaction).")
    return
  end
  local slot = SlotOf(entry.itemId)
  if not slot then
    entry.planned = entry.opened
    Step()
    return
  end

  MWC.Activity.Progress(run.opened, "Opening " .. entry.name .. "…")
  local before = GetSlotStackSize(BAG_BACKPACK, slot)
  local attempts, usedAt = 0, nil
  local waitStarted = GetGameTimeMilliseconds()

  local function OnCooldown()
    local itemRemain = GetItemCooldownInfo(BAG_BACKPACK, slot)
    return (itemRemain or 0) > 0 or (GetSlotCooldownInfo(1) or 0) > 0
  end

  EVENT_MANAGER:RegisterForUpdate(EVENT_NS, POLL_MS, function()
    local now = GetGameTimeMilliseconds()
    if GetSlotStackSize(BAG_BACKPACK, slot) < before or GetItemId(BAG_BACKPACK, slot) ~= entry.itemId then
      EVENT_MANAGER:UnregisterForUpdate(EVENT_NS)
      entry.opened = entry.opened + 1
      run.opened = run.opened + 1
      MWC.Activity.Progress(run.opened)
      Step()
      return
    end
    if usedAt and now - usedAt < ATTEMPT_TIMEOUT_MS then return end
    if OnCooldown() then
      if now - waitStarted > COOLDOWN_WAIT_LIMIT_MS then
        Finish("The item cooldown didn't end, stopped.")
      end
      return
    end
    if attempts >= MAX_ATTEMPTS then
      Finish("The game didn't open the container after several tries, stopped.")
      return
    end
    attempts, usedAt = attempts + 1, now
    if IsProtectedFunction("UseItem") then
      CallSecureProtected("UseItem", BAG_BACKPACK, slot)
    else
      UseItem(BAG_BACKPACK, slot)
    end
  end)
end

function MWC.Sealed.Open()
  if run then return end
  if not CanUseItems() then
    MWC.Print("Can't open containers right now: leave combat, close the loot window, bank or station.")
    return
  end
  local entries, byId, target = {}, {}, 0
  for _, row in ipairs(MWC.Sealed.Scan()) do
    if row.planned > 0 then
      local entry = { itemId = row.itemId, name = row.name, planned = row.planned, opened = 0 }
      table.insert(entries, entry)
      byId[row.itemId] = entry
      target = target + row.planned
    end
  end
  if target == 0 then
    MWC.Print("Nothing to open: nothing selected, no sealed writs in the bag or no free slots.")
    return
  end
  if not MWC.Activity.Begin("Opening", target, function() Finish("Opening stopped.") end) then return end
  run = { entries = entries, byId = byId, opened = 0 }
  -- Some containers show a loot window instead of dropping straight into the bag.
  EVENT_MANAGER:RegisterForEvent(EVENT_NS, EVENT_LOOT_UPDATED, function()
    if run then LootAll() end
  end)
  Step()
end
