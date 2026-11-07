InventoryGrouping = InventoryGrouping or {}
local IG = InventoryGrouping

---------------------------------------------------------------------------
-- TO BANK: pieces marked by hand go into the bank the moment it is opened
---------------------------------------------------------------------------

-- A piece is marked from its right click menu ("Move to TO BANK", Overrides.lua), which writes
-- the same per-piece override every set-aside category writes: overrides.items[pieceId] =
-- "TOBANK". This file empties those into the player's own bank whenever it opens. It reads the
-- marks themselves rather than the category, so it works whether or not the TO BANK button is
-- on show (toBankShown only hides the button: Colors.lua, MODULE_ONLY).
--
-- One move out at a time: the next is only sent once the last one has landed, so the pace is
-- the server's rather than a guess. The mark comes off just before its move is sent -- so the
-- lists the game rebuilds when the piece lands already read it as gone -- and goes back on if
-- the piece turns out to be still in the backpack. A move counts as landed only when the bank
-- slot it was sent to shows it, the way LarvalTear's deposit checks its own
-- (DidMoveArrive, LarvalTear/modules/equipment_deposit.lua:378-391). A piece the bank has no
-- room for is passed over and the next one tried: one that tops up a stack may still fit.
-- Only the backpack is emptied: with ESO Plus materials sit in the craft bag, and those are
-- left where they are.
--
-- Sources (other addons installed here, or our own file where it is ours):
--   EVENT_OPEN_BANK (_, bankBag); BAG_BANK is the player's bank   AwesomeGuildStore/util/InteractionHelper.lua:136-138
--   a house chest fires it with its own bag (IsHouseBankBag)      Inventory2/Modules.lua:594-595, 664
--   EVENT_CLOSE_BANK                                              LarvalTear/modules/auto_refill.lua:599-600
--   IsBankOpen, GetBankingBag                                     LarvalTear/modules/equipment_deposit.lua:31, 39
--   BAG_SUBSCRIBER_BANK while IsESOPlusSubscriber()               LarvalTear/modules/equipment_deposit.lua:369-373
--   FindFirstEmptySlotInBag (nil when full)                       LarvalTear/modules/equipment_deposit.lua:341-342,
--                                                                 DolgubonsLazyWritCreator/BankWithdraw.lua:93
--   RequestMoveItem (protected) through CallSecureProtected      DolgubonsLazyWritCreator/BankWithdraw.lua:120-123,
--                                                                 LarvalTear/modules/equipment_deposit.lua:399
--   GetSlotStackSize -> count, max                                AwesomeGuildStore/pc/wrappers/SellTabWrapper.lua:686
--   GetItemInstanceId                                             LootLog/LootLogTrade.lua:227
--   HasItemInSlot                                                 Inventory2/Modules.lua:576
--   GetLatency                                                    DolgubonsLazyWritCreator/BankWithdraw.lua:352
--   IsUnitInCombat, GetFrameTimeMilliseconds                      Inventory2/Repair.lua:116, 357

local TOBANK = "TOBANK"
local EVENT_NAME = "InventoryGroupingToBank"
local STEP_NAME = "InventoryGroupingToBankStep"
local CHECK_NAME = "InventoryGroupingToBankCheck"
local STEP_MS = 150    -- how often a run looks; a move is only sent once the last one has landed
local LAND_MS = 3000   -- a move not seen landing by then (plus the latency) is given up on
local CHECK_MS = 300   -- the wait before a run starts, after the bank opens or a piece is marked
-- The open event can come a moment before IsBankOpen agrees (LarvalTear's auto refill retries
-- for the same reason, auto_refill.lua:560-578): asked this many times before giving up.
local OPEN_TRIES = 5

-- The run under way, or nil: { deposited, skip = { [pieceId] = true }, flight, restored, full }
local run

local function Marks()
    local overrides = IG.sv and IG.sv.overrides
    return overrides and overrides.items
end

local function AnyMarked()
    local marks = Marks()
    if not marks then return false end
    for _, key in pairs(marks) do
        if key == TOBANK then return true end
    end
    return false
end

-- The player's own bank, open right now. A house chest or a guild bank never counts.
local function PlayerBankOpen()
    return IsBankOpen() == true and GetBankingBag() == BAG_BANK
end

-- The bank's bags, in the order the game's own deposit fills them.
local function BankBags()
    if BAG_SUBSCRIBER_BANK and IsESOPlusSubscriber and IsESOPlusSubscriber() then
        return { BAG_BANK, BAG_SUBSCRIBER_BANK }
    end
    return { BAG_BANK }
end

-- The marked piece in this backpack slot, if the bank would take it.
local function MarkedAt(marks, slot)
    if not HasItemInSlot(BAG_BACKPACK, slot) then return nil end
    local pieceId = IG.PieceId(BAG_BACKPACK, slot)
    if pieceId and marks[pieceId] == TOBANK and IG.CanDepositToBank(BAG_BACKPACK, slot) then
        return pieceId
    end
    return nil
end

-- The first marked piece in the backpack that this run has not given up on.
local function NextMarked(r)
    local marks = Marks()
    if not marks then return nil end
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        local pieceId = MarkedAt(marks, slot)
        if pieceId and not r.skip[pieceId] then return slot, pieceId end
    end
    return nil
end

-- Every marked piece still in the backpack, for the line in chat.
local function CountLeft()
    local marks = Marks()
    if not marks then return 0 end
    local left = 0
    for slot = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if MarkedAt(marks, slot) then left = left + 1 end
    end
    return left
end

-- Where this piece goes: onto a stack of the same thing with room for all of it, else into an
-- empty slot, else onto whatever room a stack has left (part of it; the rest stays marked and
-- stays behind). Returns bag, slot, quantity, whole -- or nil when the bank has no room at all.
-- The same thing is the same instance id and the same link, so nothing is ever dropped onto a
-- slot holding something else.
local function Destination(slot)
    local count, max = GetSlotStackSize(BAG_BACKPACK, slot)
    count = count or 1
    local bags = BankBags()
    local partBag, partSlot, partRoom = nil, nil, 0
    if max and max > 1 then
        local instance = GetItemInstanceId(BAG_BACKPACK, slot)
        local link = GetItemLink(BAG_BACKPACK, slot)
        if instance then
            for _, bag in ipairs(bags) do
                for destSlot = 0, GetBagSize(bag) - 1 do
                    if GetItemInstanceId(bag, destSlot) == instance and GetItemLink(bag, destSlot) == link then
                        local have, cap = GetSlotStackSize(bag, destSlot)
                        local room = (cap or 0) - (have or 0)
                        if room >= count then return bag, destSlot, count, true end
                        if room > partRoom then partBag, partSlot, partRoom = bag, destSlot, room end
                    end
                end
            end
        end
    end
    for _, bag in ipairs(bags) do
        local empty = FindFirstEmptySlotInBag(bag)
        if empty then return bag, empty, count, true end
    end
    if partBag then return partBag, partSlot, partRoom, false end
    return nil
end

local function Move(slot, bag, destSlot, quantity)
    if IsProtectedFunction("RequestMoveItem") then
        CallSecureProtected("RequestMoveItem", BAG_BACKPACK, slot, bag, destSlot, quantity)
    else
        RequestMoveItem(BAG_BACKPACK, slot, bag, destSlot, quantity)
    end
end

-- Whether this piece is anywhere in the backpack; the slot it was in is asked first.
local function InBackpack(pieceId, slot)
    if IG.PieceId(BAG_BACKPACK, slot) == pieceId then return true end
    for other = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if HasItemInSlot(BAG_BACKPACK, other) and IG.PieceId(BAG_BACKPACK, other) == pieceId then
            return true
        end
    end
    return false
end

-- Whether the bank slot the move was sent to shows it: the piece itself in what was an empty
-- slot, or, where it was put onto a stack (which keeps the stack's own id), that stack grown
-- by what was sent.
local function Arrived(flight)
    if flight.destHave > 0 then
        return (GetSlotStackSize(flight.bag, flight.destSlot) or 0) >= flight.destHave + flight.quantity
    end
    return IG.PieceId(flight.bag, flight.destSlot) == flight.pieceId
end

-- Whether the move that is out has landed, and what came of it. In the bank slot it was sent
-- to: deposited. Taken to another backpack slot meanwhile (by hand, or by another addon's own
-- job at the bank): not deposited, and its mark goes back on at once. Otherwise it waits --
-- still in its slot, the move is still on its way; gone from the backpack and not there yet,
-- the bank's side may still be coming -- until the time is up or the run is ending (final).
-- Then a piece still in the backpack gets its mark back and is left for next time, one found
-- in the bank after all is counted, and one gone altogether (used up, piled onto another
-- stack) is neither. A move that lands after that leaves a mark on a piece in the bank, which
-- the bank tidies away the next time it opens (SweepBank).
local function Settle(r, final)
    local flight = r.flight
    if not flight then return end
    if Arrived(flight) then
        r.flight = nil
        if flight.whole then r.deposited = r.deposited + 1 end
        return
    end
    local unmoved = IG.PieceId(BAG_BACKPACK, flight.slot) == flight.pieceId
        and (GetSlotStackSize(BAG_BACKPACK, flight.slot) or 0) >= flight.count
    -- A part of a stack leaves the rest in the slot, so only a whole piece is looked for.
    local inBag = unmoved or (flight.whole and InBackpack(flight.pieceId, flight.slot))
    local timeUp = final
        or GetFrameTimeMilliseconds() - flight.sentMs >= LAND_MS + (GetLatency() or 0)
    if not timeUp and (unmoved or not inBag) then return end
    r.flight = nil
    r.skip[flight.pieceId] = true
    -- A part of a stack never took the mark off.
    if not flight.whole then return end
    if inBag then
        local marks = Marks()
        if marks then
            marks[flight.pieceId] = TOBANK
            r.restored = true
        end
    elseif IG.SlotForTrackedId(flight.pieceId) then
        -- Not in the backpack, so the bank: landed, if not in the slot it was sent to.
        r.deposited = r.deposited + 1
    end
end

-- One line in chat for the whole visit, and only when there was something to say.
local function Finish(reason)
    EVENT_MANAGER:UnregisterForUpdate(STEP_NAME)
    local r = run
    if not r then return end
    if r.flight then Settle(r, true) end
    run = nil
    local left = CountLeft()
    if r.deposited > 0 or left > 0 then
        local text = string.format("Inventory 2.0: TO BANK: %d %s deposited", r.deposited,
            r.deposited == 1 and "item" or "items")
        if left > 0 then text = string.format("%s, %s: %d left", text, reason or "not moved", left) end
        d(text .. ".")
    end
    -- Only where a mark went back on: those rows may have been drawn without it meanwhile.
    -- Every other change reached the lists through the game's own rebuild as the pieces landed.
    if r.restored then IG.RefreshLists() end
end

local function Step()
    local r = run
    if not r then
        EVENT_MANAGER:UnregisterForUpdate(STEP_NAME)
        return
    end
    if not PlayerBankOpen() then return Finish("bank closed") end
    if IsUnitInCombat("player") then return Finish("in combat") end
    if r.flight then
        Settle(r, false)
        if r.flight then return end
    end
    local slot, pieceId = NextMarked(r)
    if not slot then return Finish(r.full and "bank full" or nil) end
    local bag, destSlot, quantity, whole = Destination(slot)
    if not bag then
        -- No room for this one; the next is tried on the next step, since topping up a stack of
        -- its own kind may still work for it. The rest of a part-sent stack ends up here too.
        r.skip[pieceId] = true
        r.full = true
        return
    end
    -- Off before the move is sent, so the game's rebuild when it lands already reads it as gone.
    -- A part of a stack keeps it: the rest is still in the backpack and still marked.
    if whole then Marks()[pieceId] = nil end
    r.flight = { slot = slot, pieceId = pieceId, whole = whole,
        count = GetSlotStackSize(BAG_BACKPACK, slot) or 1, sentMs = GetFrameTimeMilliseconds(),
        bag = bag, destSlot = destSlot, quantity = quantity,
        destHave = HasItemInSlot(bag, destSlot) and (GetSlotStackSize(bag, destSlot) or 0) or 0 }
    if not pcall(Move, slot, bag, destSlot, quantity) then Settle(r, true) end
end

-- Marks on pieces that are in the bank already -- put there by hand, or landed after a run was
-- cut short -- are taken off, so taking such a piece back out does not send it straight back in.
local function SweepBank()
    local marks = Marks()
    if not marks then return end
    for _, bag in ipairs({ BAG_BANK, BAG_SUBSCRIBER_BANK }) do
        for slot = 0, GetBagSize(bag) - 1 do
            if HasItemInSlot(bag, slot) then
                local pieceId = IG.PieceId(bag, slot)
                if pieceId and marks[pieceId] == TOBANK then marks[pieceId] = nil end
            end
        end
    end
end

local function Start()
    if run or not IG.sv then return end
    if IG.IsEnabled and not IG.IsEnabled() then return end
    if not PlayerBankOpen() or not AnyMarked() then return end
    SweepBank()
    run = { deposited = 0, skip = {} }
    EVENT_MANAGER:RegisterForUpdate(STEP_NAME, STEP_MS, Step)
end

-- A run a moment from now, asked up to tries times whether the player's bank is open yet. Off
-- (Modules > Module Settings > To Bank), marked pieces stay marked and stand in TO BANK as
-- always, but nothing empties them in for you; you deposit by hand, the ordinary way.
local function Schedule(tries)
    if IG.sv and IG.sv.toBankAutoDeposit == false then return end
    EVENT_MANAGER:UnregisterForUpdate(CHECK_NAME)
    EVENT_MANAGER:RegisterForUpdate(CHECK_NAME, CHECK_MS, function()
        tries = tries - 1
        if PlayerBankOpen() or tries <= 0 then
            EVENT_MANAGER:UnregisterForUpdate(CHECK_NAME)
            Start()
        end
    end)
end

-- A piece marked while the bank is already open (Overrides.lua): it goes in now rather than on
-- the next visit. A run already under way picks it up by itself.
function IG.ToBankCheck()
    if not run and PlayerBankOpen() then Schedule(1) end
end

EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_OPEN_BANK, function(_, bankBag)
    -- A house chest opens with its own bag; only the player's bank is emptied into.
    if bankBag == BAG_BANK then Schedule(OPEN_TRIES) end
end)
EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_CLOSE_BANK, function()
    EVENT_MANAGER:UnregisterForUpdate(CHECK_NAME)
    if run then Finish("bank closed") end
end)
