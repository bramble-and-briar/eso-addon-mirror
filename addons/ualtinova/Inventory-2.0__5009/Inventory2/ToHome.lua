InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

---------------------------------------------------------------------------
-- TO HOME CONTAINER: a piece marked for one particular chest in one of your houses
---------------------------------------------------------------------------

-- A piece is marked from its right click menu (Automation > Move to Home Container, Overrides.lua):
-- the usual per-piece override ("TOHOME") plus the container it is for, written in
-- sv.homeTargets[pieceId] = { houseId, bagId, collectibleId, name, houseName }. The category has
-- no switch of its own: it is there while at least one piece is marked and gone when none is
-- (IG.IsGroupAvailable, Colors.lua, asks IG.HomeMarkCount).
--
-- In the house the marks are listed in chat, and opening the chest a piece is marked for puts it
-- in, one at a time -- the same way TO BANK empties into the bank (ToBank.lua).
--
-- A container is told apart by its house and the house bank bag it stands in, and the collectible
-- (the furnishing itself) that bag holds. Taken away or replaced by another, the pieces marked for
-- it go back to the category they would be in anyway and are told so -- never moved somewhere
-- they were not sent. The containers known are only the ones seen while standing in a house you
-- own (ScanContainers), so a house has to be visited once before its chests can be picked.
--
-- Sources (the game's own UI code, esoui/esoui, and other addons installed here):
--   EVENT_OPEN_BANK (_, bankBag), IsHouseBankBag(bag)       Inventory2/Modules.lua:664, ToBank.lua:312
--   GetCollectibleForBag / GetCollectibleForHouseBankBag    Inventory2/Modules.lua:561 (chest name)
--   GetCurrentZoneHouseId, GetCollectibleIdForHouse         esoui globals.lua / housing UI
--   IsOwnerOfCurrentHouse                                   Inventory2/Modules.lua:578
--   RequestMoveItem (protected) through CallSecureProtected Inventory2/ToBank.lua:147-153

local NAME = "InventoryGroupingToHome"
local STEP_NAME = NAME .. "Step"
local CHECK_NAME = NAME .. "Check"
local SETTLE_MS = 3000   -- after arriving in a house: its chests are read by then
local STEP_MS = 150      -- a run looks this often; a move is only sent once the last has landed
local LAND_MS = 3000     -- a move not seen landing by then (plus the latency) is given up on
local CHECK_MS = 300     -- the wait before a run starts, after the chest opens
local LIST_MAX = 20      -- lines in chat when arriving in a house

local HOUSE_BAGS = {}
for _, name in ipairs({ "BAG_HOUSE_BANK_ONE", "BAG_HOUSE_BANK_TWO", "BAG_HOUSE_BANK_THREE",
    "BAG_HOUSE_BANK_FOUR", "BAG_HOUSE_BANK_FIVE", "BAG_HOUSE_BANK_SIX", "BAG_HOUSE_BANK_SEVEN",
    "BAG_HOUSE_BANK_EIGHT", "BAG_HOUSE_BANK_NINE", "BAG_HOUSE_BANK_TEN" }) do
    if _G[name] then HOUSE_BAGS[#HOUSE_BAGS + 1] = _G[name] end
end

local GetChestCollectible = GetCollectibleForBag or GetCollectibleForHouseBankBag

local run -- the deposit under way, or nil: { bag, houseId, name, deposited, skip, flight, full }

local function Marks()
    local overrides = IG.sv and IG.sv.overrides
    return overrides and overrides.items
end

local function Targets()
    return IG.sv and IG.sv.homeTargets
end

local function Registry()
    return IG.sv and IG.sv.homeContainers
end

local function ChestName(collectibleId)
    local nickname = GetCollectibleNickname(collectibleId)
    local name = nickname ~= "" and nickname or GetCollectibleName(collectibleId)
    return zo_strformat("<<1>>", name)
end

---------------------------------------------------------------------------
-- What is marked
---------------------------------------------------------------------------

-- How many pieces are marked for a container right now. A target whose piece no longer says
-- TOHOME (taken out of the category, reset, or marked somewhere else) is dropped here, so a
-- mark never outlives the thing that made it.
function IG.HomeMarkCount()
    local targets, marks = Targets(), Marks()
    if not (targets and marks) then return 0 end
    local count = 0
    for pieceId in pairs(targets) do
        if marks[pieceId] == "TOHOME" then
            count = count + 1
        else
            targets[pieceId] = nil
        end
    end
    return count
end

-- Whether this backpack slot is a piece with a container written down for it that the container
-- could take (Classify.lua, OverrideForSlot): anything else stands where it would on its own.
function IG.IsHomeMarked(bagId, slotIndex)
    if bagId ~= BAG_BACKPACK or not slotIndex then return false end
    local targets = Targets()
    if not targets then return false end
    local pieceId = IG.PieceId(bagId, slotIndex)
    return pieceId ~= nil and targets[pieceId] ~= nil and IG.CanDepositToBank(bagId, slotIndex)
end

-- The containers a piece can be marked for, nearest first: each house by name, each chest in it
-- by name. A house that was never visited has none, which is the honest answer.
function IG.HomeContainers()
    local list = {}
    for _, container in pairs(Registry() or {}) do list[#list + 1] = container end
    table.sort(list, function(a, b)
        if a.houseName ~= b.houseName then return (a.houseName or "") < (b.houseName or "") end
        return (a.name or "") < (b.name or "")
    end)
    return list
end

-- Written down for one piece; the override that files it is the caller's (Overrides.lua), made
-- right after, so the list that is rebuilt then already finds the target.
function IG.SetHomeTarget(pieceId, container)
    local targets = Targets()
    if not (targets and pieceId and container) then return end
    targets[pieceId] = { houseId = container.houseId, bagId = container.bagId,
        collectibleId = container.collectibleId, name = container.name, houseName = container.houseName }
end

function IG.HomeTargetOf(pieceId)
    local targets = Targets()
    return targets and targets[pieceId] or nil
end

---------------------------------------------------------------------------
-- Knowing the containers, and the ones that are gone
---------------------------------------------------------------------------

local function HouseName(houseId)
    local collectibleId = GetCollectibleIdForHouse and GetCollectibleIdForHouse(houseId) or 0
    if collectibleId == 0 then return "House" end
    return zo_strformat("<<1>>", GetCollectibleName(collectibleId))
end

-- Every chest standing in the house you are in, written into the registry; and a chest that was
-- known here and is not any more taken out of it. Only ever while owning the house the way
-- Modules.lua's SaveChest does, so a read of somewhere else's bags is never taken for a house.
-- Returns whether any chest answered at all: an empty answer from every bag means the house is
-- not loaded yet, not that every chest is gone.
local function ScanContainers()
    local registry = Registry()
    if not (registry and IsOwnerOfCurrentHouse and IsOwnerOfCurrentHouse()) then return false end
    local houseId = GetCurrentZoneHouseId and GetCurrentZoneHouseId() or 0
    if houseId == 0 then return false end
    local houseName = HouseName(houseId)
    local seen, any = {}, false
    for _, bagId in ipairs(HOUSE_BAGS) do
        local collectibleId = GetChestCollectible and GetChestCollectible(bagId) or 0
        if collectibleId ~= 0 then
            any = true
            local key = houseId .. ":" .. bagId
            seen[key] = true
            registry[key] = { houseId = houseId, bagId = bagId, collectibleId = collectibleId,
                name = ChestName(collectibleId), houseName = houseName }
        end
    end
    if any then
        for key, container in pairs(registry) do
            if container.houseId == houseId and not seen[key] then registry[key] = nil end
        end
    end
    return any
end

-- The pieces marked for a container that is no longer where they were told it was: back to the
-- category they would be in anyway. One line in chat, and only when it happened.
local function CancelGone(houseId)
    local targets, marks = Targets(), Marks()
    if not (targets and marks) then return end
    local gone = 0
    for pieceId, target in pairs(targets) do
        if target.houseId == houseId then
            local now = GetChestCollectible and GetChestCollectible(target.bagId) or 0
            if now ~= target.collectibleId then
                targets[pieceId] = nil
                if marks[pieceId] == "TOHOME" then marks[pieceId] = nil end
                gone = gone + 1
            end
        end
    end
    if gone > 0 then
        d(string.format("Inventory 2.0: TO HOME CONTAINER: %d %s went back to %s -- the container they were marked for is gone.",
            gone, gone == 1 and "piece" or "pieces", gone == 1 and "its category" or "their categories"))
        if IG.RefreshLists then IG.RefreshLists() end
    end
end

-- On arriving in a house: what is waiting to go in, chest by chest, in chat.
local function ListWaiting(houseId)
    local targets, marks = Targets(), Marks()
    if not (targets and marks) then return end
    local waiting = {}
    for pieceId, target in pairs(targets) do
        if target.houseId == houseId and marks[pieceId] == "TOHOME" then waiting[pieceId] = target end
    end
    if not next(waiting) then return end
    local lines = {}
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if HasItemInSlot(BAG_BACKPACK, slot) then
            local target = waiting[IG.PieceId(BAG_BACKPACK, slot)]
            if target then
                lines[#lines + 1] = string.format("%s -> %s", GetItemLink(BAG_BACKPACK, slot), target.name)
            end
        end
    end
    if #lines == 0 then return end
    d(string.format("Inventory 2.0: TO HOME CONTAINER: %d %s waiting here. Open the container to put %s in.",
        #lines, #lines == 1 and "piece" or "pieces", #lines == 1 and "it" or "them"))
    for index = 1, zo_min(#lines, LIST_MAX) do d("  " .. lines[index]) end
    if #lines > LIST_MAX then d(string.format("  ... and %d more", #lines - LIST_MAX)) end
end

local function OnArrived()
    if not (IG.sv and IG.IsEnabled and IG.IsEnabled()) then return end
    if not (IsOwnerOfCurrentHouse and IsOwnerOfCurrentHouse()) then return end
    EVENT_MANAGER:UnregisterForUpdate(NAME .. "Arrive")
    EVENT_MANAGER:RegisterForUpdate(NAME .. "Arrive", SETTLE_MS, function()
        EVENT_MANAGER:UnregisterForUpdate(NAME .. "Arrive")
        local houseId = GetCurrentZoneHouseId and GetCurrentZoneHouseId() or 0
        -- Nothing answered: the house is not read yet. Neither the registry nor a mark is
        -- touched on that -- a chest is only ever called gone on an answer that says so.
        if houseId == 0 or not ScanContainers() then return end
        CancelGone(houseId)
        ListWaiting(houseId)
    end)
end

---------------------------------------------------------------------------
-- Putting them in
---------------------------------------------------------------------------

-- The marked piece in this backpack slot, if it is for the chest that is open.
local function MarkedFor(slot, r)
    if not HasItemInSlot(BAG_BACKPACK, slot) then return nil end
    local pieceId = IG.PieceId(BAG_BACKPACK, slot)
    local target = pieceId and Targets()[pieceId]
    if not target or target.houseId ~= r.houseId or target.bagId ~= r.bag then return nil end
    if Marks()[pieceId] ~= "TOHOME" or r.skip[pieceId] then return nil end
    if not IG.CanDepositToBank(BAG_BACKPACK, slot) then return nil end
    return pieceId
end

-- Where the piece goes: onto a stack of the same thing with room for all of it, else the first
-- empty slot. Whole pieces only -- a part of a stack would leave the mark half done.
local function Destination(slot, bag)
    local count, max = GetSlotStackSize(BAG_BACKPACK, slot)
    count = count or 1
    if max and max > 1 then
        local instance = GetItemInstanceId(BAG_BACKPACK, slot)
        local link = GetItemLink(BAG_BACKPACK, slot)
        if instance then
            for destSlot = 0, GetBagSize(bag) - 1 do
                if GetItemInstanceId(bag, destSlot) == instance and GetItemLink(bag, destSlot) == link then
                    local have, cap = GetSlotStackSize(bag, destSlot)
                    if (cap or 0) - (have or 0) >= count then return destSlot, count end
                end
            end
        end
    end
    local empty = FindFirstEmptySlotInBag(bag)
    if empty then return empty, count end
    return nil
end

local function Move(slot, bag, destSlot, quantity)
    if IsProtectedFunction("RequestMoveItem") then
        CallSecureProtected("RequestMoveItem", BAG_BACKPACK, slot, bag, destSlot, quantity)
    else
        RequestMoveItem(BAG_BACKPACK, slot, bag, destSlot, quantity)
    end
end

local function Finish(reason)
    EVENT_MANAGER:UnregisterForUpdate(STEP_NAME)
    local r = run
    run = nil
    if not r then return end
    local left = 0
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if MarkedFor(slot, { bag = r.bag, houseId = r.houseId, skip = {} }) then left = left + 1 end
    end
    if r.deposited > 0 or left > 0 then
        local text = string.format("Inventory 2.0: TO HOME CONTAINER: %d %s put in %s", r.deposited,
            r.deposited == 1 and "item" or "items", r.name)
        if left > 0 then text = string.format("%s, %s: %d left", text, reason or (r.full and "container full") or "not moved", left) end
        d(text .. ".")
    end
    if IG.RefreshLists then IG.RefreshLists() end
end

local function Step()
    local r = run
    if not r then
        EVENT_MANAGER:UnregisterForUpdate(STEP_NAME)
        return
    end
    if not (IsBankOpen() and GetBankingBag() == r.bag) then return Finish("container closed") end
    if IsUnitInCombat("player") then return Finish("in combat") end
    if r.flight then
        local flight = r.flight
        if IG.PieceId(BAG_BACKPACK, flight.slot) ~= flight.pieceId then
            -- Left its slot: in. The mark and the container it named have done their job.
            Marks()[flight.pieceId] = nil
            Targets()[flight.pieceId] = nil
            r.deposited = r.deposited + 1
            r.flight = nil
        elseif GetFrameTimeMilliseconds() - flight.sentMs >= LAND_MS + (GetLatency() or 0) then
            r.skip[flight.pieceId] = true
            r.flight = nil
        else
            return
        end
    end
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local pieceId = MarkedFor(slot, r)
        if pieceId then
            local destSlot, quantity = Destination(slot, r.bag)
            if not destSlot then
                r.skip[pieceId] = true
                r.full = true
                return
            end
            r.flight = { slot = slot, pieceId = pieceId, sentMs = GetFrameTimeMilliseconds() }
            if not pcall(Move, slot, r.bag, destSlot, quantity) then
                r.skip[pieceId] = true
                r.flight = nil
            end
            return
        end
    end
    Finish()
end

local function Start(bag)
    if run or not (IG.sv and Targets()) then return end
    if IG.IsEnabled and not IG.IsEnabled() then return end
    if not (IsBankOpen() and GetBankingBag() == bag) then return end
    if not (IsOwnerOfCurrentHouse and IsOwnerOfCurrentHouse()) then return end
    local houseId = GetCurrentZoneHouseId and GetCurrentZoneHouseId() or 0
    if houseId == 0 then return end
    -- The chest that is open is read first: a mark for a chest that has been swapped for another
    -- in this slot is cancelled here rather than emptied into the wrong one.
    ScanContainers()
    CancelGone(houseId)
    local collectibleId = GetChestCollectible and GetChestCollectible(bag) or 0
    if collectibleId == 0 then return end
    local r = { bag = bag, houseId = houseId, name = ChestName(collectibleId), deposited = 0, skip = {} }
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if MarkedFor(slot, r) then
            run = r
            EVENT_MANAGER:RegisterForUpdate(STEP_NAME, STEP_MS, Step)
            return
        end
    end
end

local function OnOpenBank(_, bankBag)
    if not (bankBag and IsHouseBankBag and IsHouseBankBag(bankBag)) then return end
    EVENT_MANAGER:UnregisterForUpdate(CHECK_NAME)
    EVENT_MANAGER:RegisterForUpdate(CHECK_NAME, CHECK_MS, function()
        EVENT_MANAGER:UnregisterForUpdate(CHECK_NAME)
        Start(bankBag)
    end)
end

EVENT_MANAGER:RegisterForEvent(NAME, EVENT_PLAYER_ACTIVATED, OnArrived)
EVENT_MANAGER:RegisterForEvent(NAME, EVENT_OPEN_BANK, OnOpenBank)
EVENT_MANAGER:RegisterForEvent(NAME, EVENT_CLOSE_BANK, function()
    EVENT_MANAGER:UnregisterForUpdate(CHECK_NAME)
    if run then Finish("container closed") end
end)
