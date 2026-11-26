MWC.Bank = {}

local EVENT_NS = MWC.name .. "Bank"
local POLL_MS = 50
local MOVE_TIMEOUT_MS = 3000
-- A completely full backpack blocks quest turn-in, so withdrawals always leave this many slots free.
local FREE_SLOT_RESERVE = MWC.BAG_RESERVE
local BANK_BAGS = { BAG_BANK, BAG_SUBSCRIBER_BANK }
local ALL_BAGS = { BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }

-- The bag of the currently open bank UI: BAG_BANK for the player's bank, a house bank bag for a storage chest.
local openBag = nil
local queue, stats = nil, nil

local function IsPlayerBankOpen()
  return openBag == BAG_BANK
end

local function IsHouseChestOpen()
  return openBag ~= nil and IsHouseBankBag(openBag)
end

local function RequestMove(sourceBag, sourceSlot, destBag, destSlot, count)
  if IsProtectedFunction("RequestMoveItem") then
    CallSecureProtected("RequestMoveItem", sourceBag, sourceSlot, destBag, destSlot, count)
  else
    RequestMoveItem(sourceBag, sourceSlot, destBag, destSlot, count)
  end
end

local function DestBags(toBank)
  if not toBank then return { BAG_BACKPACK } end
  if IsHouseChestOpen() then return { openBag } end
  if IsESOPlusSubscriber() then return BANK_BAGS end
  return { BAG_BANK }
end

local function Stacks(spec, bags)
  local stacks = {}
  for _, bag in ipairs(bags) do
    for slot = 0, GetBagSize(bag) - 1 do
      if spec.matches(bag, slot) then
        table.insert(stacks, { bag = bag, slot = slot, count = GetSlotStackSize(bag, slot) })
      end
    end
  end
  return stacks
end

local function Total(stacks)
  local total = 0
  for _, stack in ipairs(stacks) do
    total = total + stack.count
  end
  return total
end

-- Only fully stack-compatible items (same instance id) are merged; otherwise an empty slot is used.
local function FindDestination(instanceId, destBags)
  for _, bag in ipairs(destBags) do
    for slot = 0, GetBagSize(bag) - 1 do
      if GetItemInstanceId(bag, slot) == instanceId then
        local stack, maxStack = GetSlotStackSize(bag, slot)
        if stack < maxStack then
          return bag, slot, maxStack - stack
        end
      end
    end
  end
  for _, bag in ipairs(destBags) do
    local slot = FindFirstEmptySlotInBag(bag)
    if slot then
      return bag, slot, math.huge
    end
  end
end

local function AddMove(moves, bag, slot, count, isWrit, toBank)
  table.insert(moves, {
    bag = bag, slot = slot, count = count, isWrit = isWrit, toBank = toBank,
    instanceId = GetItemInstanceId(bag, slot), destBags = DestBags(toBank),
  })
end

local function Finish(message)
  EVENT_MANAGER:UnregisterForUpdate(EVENT_NS)
  queue, stats = nil, nil
  MWC.Activity.End(message)
  MWC.Activity.Notify(message)
  MWC.UI.Refresh("view")
end

-- What was moved, in what takes bag space: writs, item stacks (a count of items alone says nothing about slots)
-- and the bag's free slots before and after.
local function Summary()
  local text = string.format("Moved %d writs", stats.writs)
  if stats.items > 0 then
    text = text .. string.format(" and %d items in %d stacks", stats.items, stats.stacks)
  end
  return string.format("%s. Bag free slots: %d → %d.", text, stats.freeBefore, GetNumBagFreeSlots(BAG_BACKPACK))
end

local function Step()
  local move = queue[1]
  if not move then
    Finish(Summary())
    return
  end
  if not openBag then
    Finish("Bank closed, moving stopped. " .. Summary())
    return
  end

  local sourceCount = GetSlotStackSize(move.bag, move.slot)
  if sourceCount == 0 or GetItemInstanceId(move.bag, move.slot) ~= move.instanceId then
    table.remove(queue, 1)
    Step()
    return
  end

  local destBag, destSlot, room = FindDestination(move.instanceId, move.destBags)
  if not destBag then
    Finish((move.toBank and "No space left in storage, moving stopped. " or "No space left in the bag, moving stopped. ")
      .. Summary())
    return
  end

  local count = math.min(move.count, sourceCount, room)
  move.count = move.count - count
  if move.count <= 0 then
    table.remove(queue, 1)
  end

  local expected = sourceCount - count
  local started = GetGameTimeMilliseconds()
  RequestMove(move.bag, move.slot, destBag, destSlot, count)
  EVENT_MANAGER:RegisterForUpdate(EVENT_NS, POLL_MS, function()
    if GetSlotStackSize(move.bag, move.slot) <= expected then
      EVENT_MANAGER:UnregisterForUpdate(EVENT_NS)
      if move.isWrit then
        stats.writs = stats.writs + 1
      else
        stats.items = stats.items + count
        -- One stack per source slot, however many moves it took.
        if not move.counted then
          move.counted = true
          stats.stacks = stats.stacks + 1
        end
      end
      MWC.Activity.Progress(stats.total - #queue,
        string.format("Moving… %d writs and %d items so far", stats.writs, stats.items))
      Step()
    elseif GetGameTimeMilliseconds() - started > MOVE_TIMEOUT_MS then
      Finish("The game didn't confirm the move, stopped. Try again.")
    end
  end)
end

-- emptyMessage: printed when there is nothing to move (nil for a quiet automatic run).
local function Start(moves, emptyMessage)
  if #moves == 0 then
    if emptyMessage then MWC.Print("%s", emptyMessage) end
    return
  end
  if not MWC.Activity.Begin("Moving", #moves, function() Finish("Moving stopped. " .. Summary()) end) then return end
  queue, stats = moves, { writs = 0, items = 0, stacks = 0, total = #moves,
    freeBefore = GetNumBagFreeSlots(BAG_BACKPACK) }
  Step()
end

local function CanMove(needHouseChest)
  if queue then
    MWC.Print("Already moving items.")
    return false
  end
  if needHouseChest and not IsHouseChestOpen() then
    MWC.Print("Open a house storage chest first.")
    return false
  end
  if not needHouseChest and not IsPlayerBankOpen() then
    MWC.Print("Open your bank first (not a house chest).")
    return false
  end
  return true
end

local function ExcludedWrits(bags)
  local writs = {}
  for _, writ in ipairs(MWC.Writs.Scan(bags)) do
    if MWC.Session.IsExcluded(writ.uid) then
      table.insert(writs, writ)
    end
  end
  return writs
end

function MWC.Bank.WithdrawExcluded()
  if not CanMove(false) then return end
  local free = GetNumBagFreeSlots(BAG_BACKPACK) - FREE_SLOT_RESERVE
  local moves = {}
  for _, writ in ipairs(ExcludedWrits(BANK_BAGS)) do
    if #moves >= free then break end
    AddMove(moves, writ.bag, writ.slot, 1, true, false)
  end
  Start(moves, string.format("Nothing to withdraw: no marked writs in the bank or no bag space (%d slots kept free).", FREE_SLOT_RESERVE))
end

-- Sealed writs stack to 200, so taking every stack costs only a few slots.
function MWC.Bank.WithdrawSealed()
  if not CanMove(false) then return end
  local free = GetNumBagFreeSlots(BAG_BACKPACK) - FREE_SLOT_RESERVE
  local moves = {}
  for _, bag in ipairs(BANK_BAGS) do
    for slot = 0, GetBagSize(bag) - 1 do
      if #moves < free and MWC.Sealed.IsSealedSlot(bag, slot) then
        AddMove(moves, bag, slot, GetSlotStackSize(bag, slot), false, false)
      end
    end
  end
  Start(moves, string.format("Nothing to withdraw: no sealed writs in the bank or no bag space (%d slots kept free).", FREE_SLOT_RESERVE))
end

-- Every opened master writ in the backpack, of any craft.
function MWC.Bank.DepositWrits()
  if not CanMove(false) then return end
  local moves = {}
  for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
    if GetItemType(BAG_BACKPACK, slot) == ITEMTYPE_MASTER_WRIT then
      AddMove(moves, BAG_BACKPACK, slot, 1, true, true)
    end
  end
  Start(moves, "No master writs in the bag.")
end

function MWC.Bank.StoreExcludedInChest()
  if not CanMove(true) then return end
  local moves = {}
  for _, writ in ipairs(ExcludedWrits({ BAG_BACKPACK })) do
    AddMove(moves, writ.bag, writ.slot, 1, true, true)
  end
  Start(moves, "No marked writs in the bag.")
end

-- How to recognise a group's crafted items, how many one writ takes, and the item id when stacks merge by id.
local function ResultSpec(group)
  -- Food and holiday writs' food or furnishings: the item by id, as many as the writ wants.
  if group.type == "provisioning" or (group.event and group.type ~= "alchemy") then
    local writ = group.writs[1]
    local itemId = writ and writ.foodItemId
    if not itemId then return nil end
    return {
      key = "food:" .. itemId,
      matches = function(bag, slot) return GetItemId(bag, slot) == itemId and MWC.IsMine(bag, slot) end,
      perWrit = writ.eventCount or MWC.Plan.ITEMS_PER_PROVISIONING_WRIT,
      itemId = itemId,
    }
  elseif group.type == "alchemy" then
    local key = MWC.Alchemy.IndexKey(group.isPoison, group.effectKey, group.nameKey)
    return {
      key = key,
      matches = function(bag, slot) return MWC.Alchemy.SlotIndexKey(bag, slot) == key end,
      perWrit = MWC.Alchemy.ITEMS_PER_WRIT,
    }
  elseif group.type == "enchanting" and group.indexKey then
    local key = group.indexKey
    return {
      key = key,
      matches = function(bag, slot) return MWC.Enchanting.SlotIndexKey(bag, slot) == key end,
      perWrit = MWC.Enchanting.ITEMS_PER_WRIT,
      stackSize = MWC.Enchanting.STACK_SIZE,
    }
  elseif group.indexKey then
    local key = group.indexKey
    return {
      key = key,
      matches = function(bag, slot) return MWC.Gear.SlotIndexKey(bag, slot) == key end,
      perWrit = MWC.Gear.ITEMS_PER_WRIT,
      stackSize = MWC.Gear.STACK_SIZE,
    }
  end
end

-- Writ groups that hand in the same crafted item (alchemy writs listing the same effects in another order)
-- share its stacks, so bank moves are worked out per item: { spec, keys = group keys, active, type, typeOrder }.
-- Groups whose item can't be recognised stay on their own, without a spec.
local function Families(groups)
  local byKey, families = {}, {}
  for _, group in ipairs(groups) do
    local spec = ResultSpec(group)
    local key = spec and spec.key or ("writ:" .. group.key)
    local family = byKey[key]
    if not family then
      family = { spec = spec, keys = {}, active = 0, type = group.type, typeOrder = group.typeOrder }
      byKey[key] = family
      table.insert(families, family)
    end
    family.keys[group.key] = true
    family.active = family.active + (group.activeCount or 0)
  end
  return families
end

-- Queued writs of these group keys: how many are in the bag, and the ones in the bank.
local function QueuedWrits(writs, keys)
  local inBag, inBank = 0, {}
  for _, writ in ipairs(writs) do
    if keys[writ.key] and not MWC.Session.IsExcluded(writ.uid) then
      if writ.bag == BAG_BACKPACK then
        inBag = inBag + 1
      else
        table.insert(inBank, writ)
      end
    end
  end
  return inBag, inBank
end

local function KeySet(groups)
  local keys = {}
  for _, group in ipairs(groups) do
    keys[group.key] = true
  end
  return keys
end

-- Moves crafted items out of the bag, except the given number kept back (from the smallest stacks first,
-- so the kept items stay together).
local function DepositItems(moves, spec, keep)
  local stacks = Stacks(spec, { BAG_BACKPACK })
  table.sort(stacks, function(a, b) return a.count < b.count end)
  local extra = Total(stacks) - keep
  for _, stack in ipairs(stacks) do
    if extra <= 0 then break end
    local take = math.min(stack.count, extra)
    AddMove(moves, stack.bag, stack.slot, take, false, true)
    extra = extra - take
  end
end

-- Moves every writ of these groups from the backpack to the bank, plus their crafted items, except the items
-- their active quests still need for handing in.
function MWC.Bank.Deposit(groups)
  if not CanMove(false) then return end
  local moves, keys = {}, KeySet(groups)
  local bagWrits = MWC.Writs.Scan({ BAG_BACKPACK })
  for _, writ in ipairs(bagWrits) do
    if keys[writ.key] then
      AddMove(moves, writ.bag, writ.slot, 1, true, true)
    end
  end
  -- Items stay for active quests and for queued writs of the same item that stay in the bag.
  local deposited = {}
  for _, family in ipairs(Families(groups)) do
    if family.spec then deposited[family.spec.key] = true end
  end
  for _, family in ipairs(Families(MWC.Plan.Build().groups)) do
    if family.spec and deposited[family.spec.key] then
      local staying = {}
      for key in pairs(family.keys) do
        if not keys[key] then staying[key] = true end
      end
      local stayingInBag = QueuedWrits(bagWrits, staying)
      DepositItems(moves, family.spec, (family.active + stayingInBag) * family.spec.perWrit)
    end
  end
  Start(moves, "No writs or crafted items of these recipes in the bag.")
end

-- Takes as many selected writs as fit, reserving backpack room for all items needed to turn them in
-- (whether already crafted or not) and bringing along the crafted items that are in the bank.
local function PlanWithdrawFamily(moves, family, writs, free)
  local inBag, inBank = QueuedWrits(writs, family.keys)
  -- Active quests are handed in from the bag as well: their items count as needed there.
  inBag = inBag + family.active
  local spec = family.spec
  local takeWrits, takeItems = 0, 0
  if spec then
    local bankStacks = Stacks(spec, BANK_BAGS)
    local haveBag, haveBank = Total(Stacks(spec, { BAG_BACKPACK })), Total(bankStacks)
    local reservedSlots = 0
    for count = #inBank, 0, -1 do
      local missingInBag = math.max(0, (inBag + count) * spec.perWrit - haveBag)
      local slots = count + MWC.Plan.SlotsFor(spec.itemId, missingInBag, spec.stackSize)
      if slots <= free then
        takeWrits, takeItems, reservedSlots = count, math.min(missingInBag, haveBank), slots
        break
      end
    end
    local remaining = takeItems
    for _, stack in ipairs(bankStacks) do
      if remaining <= 0 then break end
      local take = math.min(stack.count, remaining)
      AddMove(moves, stack.bag, stack.slot, take, false, false)
      remaining = remaining - take
    end
    free = free - reservedSlots
  else
    takeWrits = math.max(0, math.min(#inBank, free))
    free = free - takeWrits
  end

  for i = 1, takeWrits do
    AddMove(moves, inBank[i].bag, inBank[i].slot, 1, true, false)
  end
  return free
end

function MWC.Bank.Withdraw(groups)
  if not CanMove(false) then return end
  local writs = MWC.Writs.Scan(ALL_BAGS)
  local free = GetNumBagFreeSlots(BAG_BACKPACK) - FREE_SLOT_RESERVE
  local moves = {}
  for _, family in ipairs(Families(groups)) do
    free = PlanWithdrawFamily(moves, family, writs, free)
  end
  Start(moves, string.format("Nothing to withdraw: no selected writs in the bank or no bag space (%d slots kept free).", FREE_SLOT_RESERVE))
end

-- For turning in: only writs whose crafted items exist (in the bag or bank), with those items, as many as fit.
-- Taken round-robin by craft, so every turn-in batch can start one quest for each craft.
-- quiet: an automatic run (Autodelivery on opening the bank) says nothing when there is nothing to take.
function MWC.Bank.WithdrawReady(quiet)
  if quiet and (queue or not IsPlayerBankOpen() or MWC.Activity.Current()) then return end
  if not CanMove(false) then return end
  local writs = MWC.Writs.Scan(ALL_BAGS)
  local free = GetNumBagFreeSlots(BAG_BACKPACK) - FREE_SLOT_RESERVE
  local plans = {}
  local candidates = {}
  -- Autodelivery (quiet) takes only master writs: it starts their quests next, holiday writs it can't.
  for _, group in ipairs(MWC.Plan.Build().groups) do
    if group.selectedCount > 0 and not group.problem and not (quiet and group.event) then
      table.insert(candidates, group)
    end
  end
  for _, family in ipairs(Families(candidates)) do
    local spec = family.spec
    if spec then
      local inBag, inBank = QueuedWrits(writs, family.keys)
      inBag = inBag + family.active
      local bankStacks = Stacks(spec, BANK_BAGS)
      local haveBag, haveBank = Total(Stacks(spec, { BAG_BACKPACK })), Total(bankStacks)
      local ready = math.min(inBag + #inBank, math.floor((haveBag + haveBank) / spec.perWrit))
      local maxTake = math.max(0, math.min(#inBank, ready - inBag))
      -- Items that bag writs and active quests lack come back even when no writ is taken.
      local bagMissing = inBag * spec.perWrit - haveBag
      if maxTake > 0 or (bagMissing > 0 and haveBank > 0) then
        table.insert(plans, {
          type = family.type, typeOrder = family.typeOrder, spec = spec, inBag = inBag, inBank = inBank,
          bankStacks = bankStacks, haveBag = haveBag, haveBank = haveBank, maxTake = maxTake, take = 0, slots = 0,
          missing = 0,
        })
      end
    end
  end

  local function Cost(plan, count)
    local missing = math.max(0, (plan.inBag + count) * plan.spec.perWrit - plan.haveBag)
    return count + MWC.Plan.SlotsFor(plan.spec.itemId, missing, plan.spec.stackSize), missing
  end
  table.sort(plans, function(a, b) return a.typeOrder < b.typeOrder end)
  -- First what the writs already in the bag (and active quests) lack, then new writs round-robin.
  for _, plan in ipairs(plans) do
    local slots, missing = Cost(plan, 0)
    if slots <= free then
      free = free - slots
      plan.slots, plan.missing = slots, missing
    end
  end
  -- Each round takes one writ per craft. Within a craft the cheapest writ comes first: one whose items are
  -- already in the bag costs only its own slot, one whose items are in the bank costs their slots too, so a
  -- tight bag holds as many ready writs as possible.
  local types = {}
  for _, plan in ipairs(plans) do
    if not types[plan.type] then
      types[plan.type] = true
      table.insert(types, plan.type)
    end
  end
  local progress = true
  while progress do
    progress = false
    for _, craft in ipairs(types) do
      local best, bestSlots, bestMissing, bestExtra
      for _, plan in ipairs(plans) do
        if plan.type == craft and plan.take < plan.maxTake then
          local slots, missing = Cost(plan, plan.take + 1)
          local extra = slots - plan.slots
          if extra <= free and (not best or extra < bestExtra) then
            best, bestSlots, bestMissing, bestExtra = plan, slots, missing, extra
          end
        end
      end
      if best then
        free = free - bestExtra
        best.take, best.slots, best.missing = best.take + 1, bestSlots, bestMissing
        progress = true
      end
    end
  end

  local moves = {}
  for _, plan in ipairs(plans) do
    local remaining = math.min(plan.missing, plan.haveBank)
    for _, stack in ipairs(plan.bankStacks) do
      if remaining <= 0 then break end
      local take = math.min(stack.count, remaining)
      AddMove(moves, stack.bag, stack.slot, take, false, false)
      remaining = remaining - take
    end
    for i = 1, plan.take do
      AddMove(moves, plan.inBank[i].bag, plan.inBank[i].slot, 1, true, false)
    end
  end
  Start(moves, not quiet and string.format("Nothing to withdraw: no ready writs in the bank or no bag space (%d slots kept free).", FREE_SLOT_RESERVE) or nil)
end

-- Crafted items in the bag beyond what the queued writs in the bag need (say, spare potions after turning in).
function MWC.Bank.DepositLeftovers()
  if not CanMove(false) then return end
  local writs = MWC.Writs.Scan({ BAG_BACKPACK })
  local moves = {}
  for _, family in ipairs(Families(MWC.Plan.Build().groups)) do
    if family.spec then
      local inBag = QueuedWrits(writs, family.keys)
      DepositItems(moves, family.spec, (family.active + inBag) * family.spec.perWrit)
    end
  end
  Start(moves, "No leftover crafted items in the bag.")
end

MWC.Bank.IsPlayerBankOpen = IsPlayerBankOpen
MWC.Bank.IsHouseChestOpen = IsHouseChestOpen

function MWC.Bank.Init()
  EVENT_MANAGER:RegisterForEvent(EVENT_NS, EVENT_OPEN_BANK, function(_, bankBag)
    openBag = bankBag
    MWC.UI.OnBankStateChanged()
  end)
  EVENT_MANAGER:RegisterForEvent(EVENT_NS, EVENT_CLOSE_BANK, function()
    openBag = nil
    MWC.UI.OnBankStateChanged()
    -- A bank problem (bank or bag full...) shown in red is over once the bank is left; a moment later, so an
    -- operation stopped by the closing has ended first.
    zo_callLater(function() MWC.Activity.DismissIf("Moving") end, 200)
  end)
end
