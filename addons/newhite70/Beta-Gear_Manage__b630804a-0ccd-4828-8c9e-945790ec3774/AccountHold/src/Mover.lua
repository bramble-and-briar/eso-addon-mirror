-- AccountHold/src/Mover.lua
-- Serialized move queue / state machine for reserved-item transfers.
--
-- Design (see docs/TRANSFER_RESEARCH.md for the authoritative sources):
--   * ONE move is ever in flight at a time (self._active). The next move is
--     issued only after the engine confirms the previous one via an event.
--     This mirrors klingo/ESO-PersonalAssistant's banking automation, which
--     creates new stacks strictly one-by-one and waits for each to "arrive"
--     before proceeding.
--   * Player bank / subscriber bank / house storage use generic bag movement
--     through RequestMoveItem, guarded by IsProtectedFunction /
--     CallSecureProtected exactly as PersonalAssistant does.
--   * GUILD banks NEVER use RequestMoveItem. Withdraw uses
--     TransferFromGuildBank(sourceSlot); deposit uses
--     TransferToGuildBank(sourceBag, sourceSlot) — matching the official ZOS
--     UI (esoui/esoui @8c7b5f9…: inventoryslot.lua / guildbank_gamepad.lua).
--     Pacing/confirmation observes EVENT_GUILD_BANK_ITEM_REMOVED (withdraw),
--     EVENT_GUILD_BANK_ITEM_ADDED (deposit into an empty slot),
--     EVENT_GUILD_BANK_UPDATED_QUANTITY (deposit MERGING into an existing
--     stack) and EVENT_GUILD_BANK_TRANSFER_ERROR.
--   * A never-confirmed move times out: the queue STOPS and a concise failure
--     is surfaced. Hold state is advanced ONLY on positive evidence, so a
--     timeout never has to "roll back" a hold — nothing was marked yet.
--
-- Two entry points correspond to the two roles:
--   Mover:DepositForHolds(containerKey, holds)   -- holder pushes into a container
--   Mover:WithdrawForHolds(containerKey, holds)  -- requester pulls into backpack

AccountHold = AccountHold or {}
AccountHold.Mover = AccountHold.Mover or {}

local Mover = AccountHold.Mover
local addon

-- Generous; an ESO server round-trip for a new-stack move can be slow.
local MOVE_CONFIRM_TIMEOUT_MS = 8000

-- ---------------------------------------------------------------------------
-- Init: register the confirmation/pacing event handlers + the timeout sweep.
-- ---------------------------------------------------------------------------
function Mover:Initialize(addonRef)
    addon = addonRef
    if self._initialized then return end
    self._initialized = true

    -- Serialized state machine: a FIFO of pending jobs and the single job we
    -- are currently waiting on the engine to confirm.
    self._queue  = {}
    self._active = nil

    -- Bag-transport confirmation. The real event carries
    -- (eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason,
    --  stackCountChangeAmount, ...) -- see esoui @8c7b5f9…
    -- sharedinventory.lua OnInventorySlotUpdated. We forward the stack-count
    -- delta so a removal/duplicate update can't confirm a destination gain.
    if EVENT_MANAGER and EVENT_INVENTORY_SINGLE_SLOT_UPDATE then
        EVENT_MANAGER:RegisterForEvent(addon.name .. "_MoverConfirm",
            EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
            function(_, bagId, slotIndex, _isNewItem, _soundCategory,
                     _updateReason, stackCountChangeAmount)
                self:_OnDestinationSlotUpdate(bagId, slotIndex, stackCountChangeAmount)
            end)
    end

    -- Guild-bank pacing: withdraw completes on ITEM_REMOVED, deposit on
    -- ITEM_ADDED, and either can fail with TRANSFER_ERROR. Guarded so the
    -- addon still loads under an API surface (or test harness) missing them.
    -- Guild events fire for EVERY member's activity in the open bank and carry
    -- (eventCode, slotIndex, updatedByLocalPlayer, itemSoundCategory,
    --  isLastUpdateForMessage) -- see esoui @8c7b5f9…
    -- sharedinventory.lua OnGuildBankInventorySlotUpdated. We forward those
    -- args so another member's event can never confirm/advance our queue.
    if EVENT_MANAGER and EVENT_GUILD_BANK_ITEM_REMOVED then
        EVENT_MANAGER:RegisterForEvent(addon.name .. "_MoverGBRemoved",
            EVENT_GUILD_BANK_ITEM_REMOVED,
            function(_, slotIndex, updatedByLocalPlayer, _sound, isLastUpdateForMessage)
                self:_OnGuildItemRemoved(slotIndex, updatedByLocalPlayer, isLastUpdateForMessage)
            end)
    end
    if EVENT_MANAGER and EVENT_GUILD_BANK_ITEM_ADDED then
        EVENT_MANAGER:RegisterForEvent(addon.name .. "_MoverGBAdded",
            EVENT_GUILD_BANK_ITEM_ADDED,
            function(_, slotIndex, updatedByLocalPlayer, _sound, isLastUpdateForMessage)
                self:_OnGuildItemAdded(slotIndex, updatedByLocalPlayer, isLastUpdateForMessage)
            end)
    end
    -- A guild deposit that MERGES into an existing guild-bank stack emits
    -- EVENT_GUILD_BANK_UPDATED_QUANTITY (not ITEM_ADDED). Its documented
    -- signature is only (eventCode, slotId) -- it lacks updatedByLocalPlayer /
    -- isLastUpdateForMessage -- so the handler disambiguates using the active
    -- guild-deposit state plus the item link at the reported slot.
    if EVENT_MANAGER and EVENT_GUILD_BANK_UPDATED_QUANTITY then
        EVENT_MANAGER:RegisterForEvent(addon.name .. "_MoverGBQty",
            EVENT_GUILD_BANK_UPDATED_QUANTITY,
            function(_, slotIndex) self:_OnGuildItemQuantityUpdated(slotIndex) end)
    end
    if EVENT_MANAGER and EVENT_GUILD_BANK_TRANSFER_ERROR then
        EVENT_MANAGER:RegisterForEvent(addon.name .. "_MoverGBError",
            EVENT_GUILD_BANK_TRANSFER_ERROR,
            function(_, errorCode) self:_OnGuildTransferError(errorCode) end)
    end

    -- Clear the queue when the container closes so no stale timeout lingers on
    -- an in-flight move whose confirmation can no longer arrive. Only the
    -- pending/in-flight queue is dropped; confirmed hold state is never touched.
    local function stopOnClose() self:StopQueue("container closed") end
    if EVENT_MANAGER and EVENT_CLOSE_BANK then
        EVENT_MANAGER:RegisterForEvent(addon.name .. "_MoverCloseBank",
            EVENT_CLOSE_BANK, stopOnClose)
    end
    if EVENT_MANAGER and EVENT_CLOSE_GUILD_BANK then
        EVENT_MANAGER:RegisterForEvent(addon.name .. "_MoverCloseGBank",
            EVENT_CLOSE_GUILD_BANK, stopOnClose)
    end

    -- Timeout sweep: if the active move is never confirmed we stop the pass
    -- and surface a concise failure rather than hang the queue forever.
    if EVENT_MANAGER and EVENT_MANAGER.RegisterForUpdate then
        EVENT_MANAGER:RegisterForUpdate(addon.name .. "_MoverSweep",
            1000,
            function() self:_SweepActive() end)
    end
end

local function nowMs()
    return GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
end

-- ---------------------------------------------------------------------------
-- Container-key helpers
-- ---------------------------------------------------------------------------
local function isGuildContainer(containerKey)
    return type(containerKey) == "string" and containerKey:sub(1, 10) == "guildbank:"
end

local function isHouseContainer(containerKey)
    return type(containerKey) == "string" and containerKey:sub(1, 6) == "house:"
end

local function guildIdFromKey(containerKey)
    if isGuildContainer(containerKey) then
        return tonumber(containerKey:sub(11))
    end
    return nil
end

local function rk(bagId, slotIndex)
    return tostring(bagId) .. ":" .. tostring(slotIndex)
end

-- Destination bags for a DEPOSIT into a bag-transport container (bank/house).
local function containerDestBags(containerKey)
    if containerKey == "bank" then
        local t = { BAG_BANK }
        if BAG_SUBSCRIBER_BANK then t[#t + 1] = BAG_SUBSCRIBER_BANK end
        return t
    elseif isHouseContainer(containerKey) then
        local _, _, _, bagIdStr = string.find(containerKey, "house:(%d+):(%d+)")
        local bagId = tonumber(bagIdStr)
        if bagId then return { bagId } end
    end
    return {}
end

-- Source bags that physically back a container (where a withdraw pulls from).
local function containerSourceBags(containerKey)
    if isGuildContainer(containerKey) then return { BAG_GUILDBANK } end
    return containerDestBags(containerKey)
end

-- ---------------------------------------------------------------------------
-- Protected-call wrapper for RequestMoveItem (bag transport only).
-- RequestMoveItem is a protected function: when IsProtectedFunction reports it
-- so, it MUST be invoked via CallSecureProtected. All Mover entry points run
-- from player-initiated input (keybind/dialog callbacks), so the secure chain
-- holds. Mirrors klingo/ESO-PersonalAssistant's _requestMoveItem guard.
-- ---------------------------------------------------------------------------
local function secureMove(srcBag, srcSlot, destBag, destSlot, count)
    local useSecure = false
    if type(IsProtectedFunction) == "function" then
        local ok, protected = pcall(IsProtectedFunction, "RequestMoveItem")
        useSecure = ok and protected and true or false
    end

    local ok, result
    if useSecure then
        if type(CallSecureProtected) ~= "function" then
            return false, "CallSecureProtected missing"
        end
        ok, result = pcall(CallSecureProtected,
            "RequestMoveItem", srcBag, srcSlot, destBag, destSlot, count)
    elseif type(RequestMoveItem) == "function" then
        ok, result = pcall(RequestMoveItem,
            srcBag, srcSlot, destBag, destSlot, count)
    elseif type(CallSecureProtected) == "function" then
        ok, result = pcall(CallSecureProtected,
            "RequestMoveItem", srcBag, srcSlot, destBag, destSlot, count)
    else
        return false, "RequestMoveItem missing"
    end

    if not ok then return false, result end
    if result == false then return false, "RequestMoveItem rejected" end
    return true
end

-- Guild-bank transport primitives. Never route the guild bag through
-- RequestMoveItem — the engine ignores it and the item never moves.
local function guildWithdraw(srcSlot)
    if type(TransferFromGuildBank) ~= "function" then
        return false, "TransferFromGuildBank missing"
    end
    local ok, err = pcall(TransferFromGuildBank, srcSlot)
    if not ok then return false, err end
    return true
end

local function guildDeposit(srcBag, srcSlot)
    if type(TransferToGuildBank) ~= "function" then
        return false, "TransferToGuildBank missing"
    end
    local ok, err = pcall(TransferToGuildBank, srcBag, srcSlot)
    if not ok then return false, err end
    return true
end

-- Guarded guild withdraw-permission check (inert when the globals are absent).
local function canWithdrawFromGuild(guildId)
    if guildId and type(DoesPlayerHaveGuildPermission) == "function"
       and GUILD_PERMISSION_BANK_WITHDRAW then
        local ok, res = pcall(DoesPlayerHaveGuildPermission,
            guildId, GUILD_PERMISSION_BANK_WITHDRAW)
        if ok and res == false then return false end
    end
    return true
end

-- Guarded guild deposit-permission check (inert when the globals are absent).
local function canDepositToGuild(guildId)
    if guildId and type(DoesPlayerHaveGuildPermission) == "function"
       and GUILD_PERMISSION_BANK_DEPOSIT then
        local ok, res = pcall(DoesPlayerHaveGuildPermission,
            guildId, GUILD_PERMISSION_BANK_DEPOSIT)
        if ok and res == false then return false end
    end
    return true
end

-- Ask the gamepad bank tab to rebuild its Withdraw/Deposit list on the NEXT
-- frame. Hold status only flips async, on a later confirmation event, so we
-- defer the refresh so the state change lands first. Fully guarded so it is
-- inert when the bank scene is closed or the tab was never built.
local function refreshBankTabLater()
    if type(zo_callLater) ~= "function" then return end
    zo_callLater(function()
        pcall(function()
            local tab = addon and addon.UI and addon.UI.BankTabGamepad
            if tab and tab.Populate then tab:Populate() end
        end)
    end, 0)
end

-- ---------------------------------------------------------------------------
-- Slot helpers
-- ---------------------------------------------------------------------------
local function findEmptySlot(bagId)
    if not bagId then return nil end
    if FindFirstEmptySlotInBag then
        return FindFirstEmptySlotInBag(bagId)
    end
    local size = GetBagSize(bagId) or 0
    for slot = 0, size - 1 do
        if IsItemBagAndSlotEmpty and IsItemBagAndSlotEmpty(bagId, slot) then
            return slot
        end
    end
    return nil
end

-- Guarded native free-slot check. Uses GetNumBagFreeSlots when present (the
-- real ZOS API), else falls back to a live empty-slot scan so behaviour
-- degrades safely under older API surfaces / the test harness.
local function bagHasFreeSlot(bagId)
    if not bagId then return false end
    if type(GetNumBagFreeSlots) == "function" then
        local ok, n = pcall(GetNumBagFreeSlots, bagId)
        if ok and type(n) == "number" then return n > 0 end
    end
    return findEmptySlot(bagId) ~= nil
end

-- Guarded "does the destination have room for this specific source stack"
-- check, matching the official withdraw/deposit guard
-- DoesBagHaveSpaceFor(destBag, srcBag, srcSlot). Falls back to a plain
-- free-slot check when the API is absent.
local function destHasRoomForSource(destBag, srcBag, srcSlot)
    if type(DoesBagHaveSpaceFor) == "function" then
        local ok, res = pcall(DoesBagHaveSpaceFor, destBag, srcBag, srcSlot)
        if ok and res ~= nil then return res == true end
    end
    return bagHasFreeSlot(destBag)
end

-- First empty slot in bagId not already claimed this planning pass.
local function firstUnreservedEmpty(bagId, reserved)
    if not bagId then return nil end
    local size = GetBagSize and GetBagSize(bagId) or 0
    for slot = 0, size - 1 do
        local key = rk(bagId, slot)
        if not (reserved and reserved[key])
           and (not IsItemBagAndSlotEmpty or IsItemBagAndSlotEmpty(bagId, slot)) then
            return slot
        end
    end
    return nil
end

-- Live (issue-time) destination slot for a bag-transport move. Uses the
-- guarded native space check first, then a live empty-slot scan.
local function findDestEmptySlot(destBags)
    for _, bagId in ipairs(destBags or {}) do
        if bagId and bagHasFreeSlot(bagId) then
            local slot = findEmptySlot(bagId)
            if slot then return bagId, slot end
        end
    end
    return nil, nil
end

-- Re-find a live slot in a single bag whose item link matches `signature`.
local function findSlotBySignature(bagId, signature, reserved)
    if not bagId or not signature or signature == "" then return nil end
    local size = GetBagSize and GetBagSize(bagId) or 0
    for slot = 0, size - 1 do
        local key = rk(bagId, slot)
        if not (reserved and reserved[key])
           and (not IsItemBagAndSlotEmpty or not IsItemBagAndSlotEmpty(bagId, slot)) then
            local link = GetItemLink and GetItemLink(bagId, slot, LINK_STYLE_DEFAULT)
            if link == signature then
                return slot
            end
        end
    end
    return nil
end

-- Does the item physically occupying this slot actually satisfy `hold`?
--
-- Item holds match the exact link signature. SET holds have no itemSignature at
-- all, so they must be matched by set id against the item's live link. The old
-- code passed hold.itemSignature (nil for a set hold) into a
-- "not signature -> accept" short-circuit, which meant a set hold accepted
-- WHATEVER occupied the cached slot -- depositing or withdrawing an unrelated
-- item -- and, when that slot was empty, had no signature left to rescan with
-- and silently moved nothing. A hold we cannot characterise now matches
-- nothing, which is the safe direction.
local function slotSatisfiesHold(bagId, slotIndex, hold)
    if not hold or bagId == nil or slotIndex == nil then return false end
    if IsItemBagAndSlotEmpty and IsItemBagAndSlotEmpty(bagId, slotIndex) then return false end
    local link = GetItemLink and GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
    if not link or link == "" then return false end
    if hold.holdType == "set" then
        if hold.setId == nil or type(GetItemLinkSetInfo) ~= "function" then return false end
        local ok, hasSet, _, _, _, _, setId = pcall(GetItemLinkSetInfo, link)
        if not (ok and hasSet and setId == hold.setId) then return false end
        -- The player may have expanded the reservation and deselected this
        -- piece. Excluding is keyed by itemSignature, and the Scanner builds a
        -- signature from the item link, so compare on the link itself. Without
        -- this the tick boxes would be purely cosmetic and the Mover would
        -- happily deposit a piece the player explicitly excluded.
        local excluded = hold.excludedSignatures
        if type(excluded) == "table" and excluded[link] == true then return false end
        return true
    end
    local signature = hold.itemSignature or hold.itemLink
    return signature ~= nil and signature ~= "" and link == signature
end

-- Test seam. slotSatisfiesHold is the single chokepoint every deposit and
-- withdraw passes through, so the per-piece exclusion is enforced there rather
-- than in each UI surface. Exposed so that rule can be tested directly instead
-- of inferred from a whole move.
Mover._SlotSatisfiesHold = slotSatisfiesHold

-- First unreserved slot in `bagId` holding something that satisfies `hold`.
local function findSlotForHold(bagId, hold, reserved)    if not bagId or not hold then return nil end
    local size = GetBagSize and GetBagSize(bagId) or 0
    for slot = 0, size - 1 do
        local key = rk(bagId, slot)
        if not (reserved and reserved[key])
           and slotSatisfiesHold(bagId, slot, hold) then
            return slot
        end
    end
    return nil
end

-- Resolve the live source bag/slot for a deposit candidate. Trusts the cached
-- value but re-scans the holder's backpack/worn when the cache is stale (slot
-- split / manual reorganisation / the item is simply gone). Reserved slots
-- already claimed this pass are skipped so sibling holds never double-target
-- one physical stack.
local function resolveLiveSource(candidate, hold, reserved)
    if not candidate or not hold then return nil, nil end
    local bagId, slotIndex = candidate.bagId, candidate.slotIndex
    local key = bagId and slotIndex and rk(bagId, slotIndex)
    local cacheFree = bagId and slotIndex and not (reserved and key and reserved[key])
    if cacheFree and slotSatisfiesHold(bagId, slotIndex, hold) then
        return bagId, slotIndex
    end
    for _, scanBag in ipairs({ BAG_BACKPACK, BAG_WORN }) do
        local found = findSlotForHold(scanBag, hold, reserved)
        if found then return scanBag, found end
    end
    return nil, nil
end

-- ---------------------------------------------------------------------------
-- Serialized queue / state machine
-- ---------------------------------------------------------------------------

function Mover:_enqueue(job)
    self._queue = self._queue or {}
    -- Start a reporting batch on the first job enqueued while idle. The batch
    -- counts CONFIRMED moves only, so failed/skipped queued jobs are never
    -- reported as moved.
    if not self._batchActive then
        self._batchActive      = true
        self._batchCompleted   = 0
        self._batchFailed      = 0
        self._batchFailReasons = {}
    end
    self._queue[#self._queue + 1] = job
end

-- Drain the queue: issue jobs one at a time. Stops as soon as a job goes
-- in-flight (awaiting a confirmation event). Jobs that cannot be issued
-- (source vanished, destination full, rejected) are skipped — never retried in
-- the same pass. A fatal issue stops the pass entirely.
function Mover:_pump()
    if self._active then return end
    local queue = self._queue or {}
    while #queue > 0 and not self._active do
        local job = table.remove(queue, 1)
        local status, reason = self:_issue(job)
        if status == "skip" then
            self:_noteFailure(job, reason)
        end
        if status == "stop" then
            self._queue = {}
            self:_finalizeBatch(true)
            refreshBankTabLater()
            return
        end
        -- "issued" -> self._active set, loop exits; "skip" -> next job.
    end
    if not self._active then
        self:_finalizeBatch(true)
        refreshBankTabLater()
    end
end

-- Issue a single job. Returns "issued" (now awaiting confirmation), "skip"
-- (could not issue; move on) or "stop" (fatal; abort the pass).
function Mover:_issue(job)
    local srcBag, srcSlot = self:_verifySource(job)
    if not srcBag then
        addon:Debug(GetString(SI_ACCOUNTHOLD_ERR_NO_SOURCE))
        return "skip", "source item no longer present"
    end
    job.srcBag, job.srcSlot = srcBag, srcSlot
    -- Set holds carry no single link; record the actual piece for the log.
    if (job.itemLink == nil or job.itemLink == "") and GetItemLink then
        local okLink, link = pcall(GetItemLink, srcBag, srcSlot, LINK_STYLE_DEFAULT)
        if okLink and link and link ~= "" then job.itemLink = link end
    end

    if job.guild then
        return self:_issueGuild(job)
    end
    return self:_issueBag(job)
end

function Mover:_issueBag(job)
    local destBag, destSlot = findDestEmptySlot(job.destBags)
    if not destBag then
        addon:Debug(GetString(SI_ACCOUNTHOLD_ERR_DEST_FULL))
        return "skip", "destination full"
    end
    local ok, why = secureMove(job.srcBag, job.srcSlot, destBag, destSlot, job.count)
    if not ok then
        addon:Debug(GetString(SI_ACCOUNTHOLD_ERR_MOVE_FAILED):format(job.kind))
        return "skip", tostring(why or "move rejected")
    end
    job.destBag, job.destSlot = destBag, destSlot
    job.expiresAt = nowMs() + MOVE_CONFIRM_TIMEOUT_MS
    self._active = job
    return "issued"
end

function Mover:_issueGuild(job)
    if job.kind == "withdraw" then
        -- Guild items land in the backpack; make sure there is room for this
        -- specific source stack (mirrors the native withdraw guard).
        if not destHasRoomForSource(BAG_BACKPACK, BAG_GUILDBANK, job.srcSlot) then
            addon:Debug(GetString(SI_ACCOUNTHOLD_ERR_DEST_FULL))
            return "skip", "destination full"
        end
        if not canWithdrawFromGuild(job.guildId) then
            addon:Debug(GetString(SI_ACCOUNTHOLD_ERR_MOVE_FAILED):format(job.kind))
            return "skip", "guild transfer refused"
        end
        -- Expected slot the ITEM_REMOVED confirmation must report.
        job.guildSlot = job.srcSlot
        local ok = guildWithdraw(job.srcSlot)
        if not ok then
            addon:Debug(GetString(SI_ACCOUNTHOLD_ERR_MOVE_FAILED):format(job.kind))
            return "skip", "guild transfer refused"
        end
    else -- deposit
        if not canDepositToGuild(job.guildId) then
            addon:Debug(GetString(SI_ACCOUNTHOLD_ERR_MOVE_FAILED):format(job.kind))
            return "skip", "guild transfer refused"
        end
        if not bagHasFreeSlot(BAG_GUILDBANK) then
            addon:Debug(GetString(SI_ACCOUNTHOLD_ERR_DEST_FULL))
            return "skip", "destination full"
        end
        local ok = guildDeposit(job.srcBag, job.srcSlot)
        if not ok then
            addon:Debug(GetString(SI_ACCOUNTHOLD_ERR_MOVE_FAILED):format(job.kind))
            return "skip", "guild transfer refused"
        end
    end
    job.expiresAt = nowMs() + MOVE_CONFIRM_TIMEOUT_MS
    self._active = job
    return "issued"
end

-- Re-resolve a job's source right before issuing (earlier moves may have
-- shifted slots). Falls back to a signature scan over the job's source bags.
function Mover:_verifySource(job)
    -- Prefer the hold-aware check so a set hold (no itemSignature) can't
    -- confirm an unrelated item that happens to sit in the cached slot.
    local hold = job.hold
    if hold then
        if slotSatisfiesHold(job.srcBag, job.srcSlot, hold) then
            return job.srcBag, job.srcSlot
        end
        for _, bagId in ipairs(job.sourceBags or {}) do
            local found = findSlotForHold(bagId, hold, nil)
            if found then return bagId, found end
        end
        return nil, nil
    end
    local b, s = job.srcBag, job.srcSlot
    if b and s and (not IsItemBagAndSlotEmpty or not IsItemBagAndSlotEmpty(b, s)) then
        local link = GetItemLink and GetItemLink(b, s, LINK_STYLE_DEFAULT)
        if not job.signature or job.signature == "" or link == job.signature then
            return b, s
        end
    end
    if job.signature and job.signature ~= "" then
        for _, bagId in ipairs(job.sourceBags or {}) do
            local found = findSlotBySignature(bagId, job.signature, nil)
            if found then return bagId, found end
        end
    end
    return nil, nil
end

-- ---------------------------------------------------------------------------
-- Confirmation + failure
-- ---------------------------------------------------------------------------

-- Bag-transport confirmation. ESO may merge the moved stack into a DIFFERENT
-- destination slot than the empty one we targeted, so we accept either the
-- exact requested slot or any slot in the destination bag now holding the
-- expected item link. A confirmation is an item GAIN, so when the engine
-- reports the stack-count delta we require it to be positive — this stops a
-- removal/duplicate update on a same-link slot (e.g. a serialized second
-- same-link job) from prematurely confirming.
function Mover:_OnDestinationSlotUpdate(bagId, slotIndex, stackCountChangeAmount)
    local job = self._active
    if not job or job.guild then return end
    if bagId ~= job.destBag then return end
    if type(stackCountChangeAmount) == "number" and stackCountChangeAmount <= 0 then
        return
    end
    local link = GetItemLink and GetItemLink(bagId, slotIndex, LINK_STYLE_DEFAULT)
    local matchesSlot = (slotIndex == job.destSlot)
    local matchesLink = job.signature and job.signature ~= ""
        and link and link ~= "" and link == job.signature
    if matchesSlot or matchesLink then
        self:_confirmActive()
    end
end

-- Guild withdraw confirmation. The engine fires EVENT_GUILD_BANK_ITEM_REMOVED
-- for EVERY member's activity in the open bank, so we confirm only when the
-- update was made by the local player, is the final update for its message,
-- and the removed slot matches the slot we withdrew from.
function Mover:_OnGuildItemRemoved(slotIndex, updatedByLocalPlayer, isLastUpdateForMessage)
    local job = self._active
    if not (job and job.guild and job.kind == "withdraw") then return end
    if updatedByLocalPlayer ~= true then return end
    if isLastUpdateForMessage == false then return end
    if job.guildSlot ~= nil and slotIndex ~= nil and slotIndex ~= job.guildSlot then
        return
    end
    self:_confirmActive()
end

-- Guild deposit confirmation. The destination guild slot is engine-assigned
-- (we cannot predict it), so we match on updatedByLocalPlayer + our in-flight
-- deposit rather than a specific slot.
function Mover:_OnGuildItemAdded(_slotIndex, updatedByLocalPlayer, isLastUpdateForMessage)
    local job = self._active
    if not (job and job.guild and job.kind == "deposit") then return end
    if updatedByLocalPlayer ~= true then return end
    if isLastUpdateForMessage == false then return end
    self:_confirmActive()
end

-- Guild deposit confirmation for a MERGE into an existing guild-bank stack.
-- When a deposited item stacks onto an existing guild slot the engine fires
-- EVENT_GUILD_BANK_UPDATED_QUANTITY (not ITEM_ADDED). Its documented signature
-- is only (eventCode, slotId): it carries neither updatedByLocalPlayer nor
-- isLastUpdateForMessage, so we cannot filter by author flags. We disambiguate
-- as safely as the API allows:
--   * only ever confirm when the active job is an in-flight guild DEPOSIT, so
--     unrelated quantity events never confirm a withdraw / bag / idle queue;
--   * when the reported slot is readable, require its item link to match the
--     deposited item so a quantity change on an unrelated stack is ignored.
-- If the slot is unreadable we fall back to the active guild-deposit state,
-- which is the strongest signal the API provides for this event.
function Mover:_OnGuildItemQuantityUpdated(slotIndex)
    local job = self._active
    if not (job and job.guild and job.kind == "deposit") then return end
    if slotIndex ~= nil and job.signature and job.signature ~= "" then
        local link = GetItemLink and GetItemLink(BAG_GUILDBANK, slotIndex, LINK_STYLE_DEFAULT)
        if link and link ~= "" and link ~= job.signature then
            return
        end
    end
    self:_confirmActive()
end

function Mover:_OnGuildTransferError(errorCode)
    local job = self._active
    if job and job.guild then
        self:_failActive("transfer error " .. tostring(errorCode))
    end
end

-- Advance the confirmed job's hold state, then pump the next job.
function Mover:_confirmActive()
    local job = self._active
    self._active = nil
    if not job then return end
    self:_markConfirmed(job)
    self:_pump()
end

function Mover:_markConfirmed(job)
    self._batchCompleted = (self._batchCompleted or 0) + 1
    local ok, err = pcall(function()
        if job.kind == "withdraw" then
            -- Only the move that completes the hold marks it delivered. A set
            -- hold completes when every planned piece has arrived AND nothing
            -- selected is waiting elsewhere; an item hold when the delivered
            -- count reaches the requested count.
            local plan = job.plan
            local setComplete = false
            if plan then
                plan.confirmed = (plan.confirmed or 0) + 1
                setComplete = plan.setComplete and plan.confirmed >= plan.jobs
            end
            local fulfilled = addon.Holds:RecordWithdrawal(job.holdId, job.count, setComplete)
            addon.Holds:LogToHold(job.hold,
                GetString(SI_ACCOUNTHOLD_LOG_HOLD_DELIVERED):format(
                    job.itemLink or "?", job.count,
                    addon:GetCharacterRecord().name or "?"))
            if fulfilled and addon.Notify and addon.Notify.OnHoldDelivered then
                addon.Notify:OnHoldDelivered(job.hold)
            end
        else
            addon.Holds:RecordDeposit(job.holdId, job.count, job.containerKey)
            addon.Holds:LogToHold(job.hold,
                GetString(SI_ACCOUNTHOLD_LOG_HOLD_DEPOSITED):format(
                    job.itemLink or "?", job.count, tostring(job.containerKey)))
        end
    end)
    if not ok and addon and addon.Debug then
        addon:Debug("Hold state update failed: %s", tostring(err))
    end
    refreshBankTabLater()
end

-- Count a move that could not be completed so the batch can report it. With
-- debug logging off (the default) these used to vanish: the player pressed
-- Withdraw, nothing happened, and nothing said why.
function Mover:_noteFailure(job, reason)
    self._batchFailed = (self._batchFailed or 0) + 1
    self._batchFailReasons = self._batchFailReasons or {}
    local r = tostring(reason or "unknown")
    if #self._batchFailReasons < 5 then
        self._batchFailReasons[#self._batchFailReasons + 1] = r
    end
    if job and job.containerKey then
        self._retry = {
            role         = (job.kind == "deposit") and "deposit" or "withdraw",
            containerKey = job.containerKey,
        }
    end
end

-- Stop the pass on timeout/error. Hold state is never advanced without
-- evidence, so there is nothing to roll back — we simply drop the queue and
-- surface a concise, stack-trace-free failure.
function Mover:_failActive(reason)
    local job = self._active
    self._active = nil
    self._queue = {}
    if job then
        addon:Debug(GetString(SI_ACCOUNTHOLD_ERR_MOVE_FAILED):format(
            tostring(job.kind) .. " (" .. tostring(reason) .. ")"))
        self:_noteFailure(job, reason)
    end
    -- Report whatever confirmed before the stop; failed/in-flight jobs were
    -- never counted, so they are not reported as moved.
    self:_finalizeBatch(true)
    refreshBankTabLater()
end

function Mover:_SweepActive()
    local job = self._active
    if not job then return end
    if job.expiresAt and nowMs() >= job.expiresAt then
        self:_failActive("timeout")
    end
end

-- Report the actual number of confirmed moves once the queue fully drains.
-- Only confirmed deliveries/deposits are counted, so failed or skipped queued
-- jobs are never reported as moved.
function Mover:_finalizeBatch(announce)
    if not self._batchActive then return end
    local completed = self._batchCompleted or 0
    local failed    = self._batchFailed or 0
    local reasons   = self._batchFailReasons or {}
    self._batchActive      = false
    self._batchCompleted   = 0
    self._batchFailed      = 0
    self._batchFailReasons = {}
    self._lastBatchMoved   = completed
    self._lastBatchFailed  = failed
    if announce and completed > 0 and addon and addon.Notify and addon.Notify.Alert then
        pcall(function()
            addon.Notify:Alert(GetString(SI_ACCOUNTHOLD_BANK_MOVE_OK):format(completed))
        end)
    end
    if announce and failed > 0 and addon then
        if addon.Diagnostic then
            pcall(function()
                addon:Diagnostic("warn", "[mover] %d move(s) failed: %s",
                    failed, table.concat(reasons, "; "))
            end)
        end
        if addon.Notify and addon.Notify.Alert then
            pcall(function()
                addon.Notify:Alert(GetString(SI_ACCOUNTHOLD_BANK_MOVE_FAILED):format(failed))
            end)
        end
    end
end

-- Drop the pending/in-flight queue without touching confirmed hold state.
-- Used when the bank/guild bank closes so no stale timeout lingers. We do NOT
-- announce a summary here: each confirmed move already updated its hold and
-- fired its own notification.
function Mover:StopQueue(_reason)
    self._active = nil
    self._queue  = {}
    self:_finalizeBatch(false)
end

-- ---------------------------------------------------------------------------
-- Job builders
-- ---------------------------------------------------------------------------
function Mover:_makeDepositJob(hold, srcBag, srcSlot, count, containerKey, guild, destBags)
    return {
        kind         = "deposit",
        guild        = guild,
        guildId      = guildIdFromKey(containerKey),
        holdId       = hold.id,
        hold         = hold,
        srcBag       = srcBag,
        srcSlot      = srcSlot,
        count        = count,
        signature    = hold.itemSignature or hold.itemLink,
        itemLink     = hold.itemLink,
        containerKey = containerKey,
        destBags     = destBags,
        sourceBags   = { BAG_BACKPACK, BAG_WORN },
    }
end

function Mover:_makeWithdrawJob(hold, srcBag, srcSlot, count, containerKey, guild, srcBags)
    return {
        kind         = "withdraw",
        guild        = guild,
        guildId      = guildIdFromKey(containerKey),
        holdId       = hold.id,
        hold         = hold,
        srcBag       = srcBag,
        srcSlot      = srcSlot,
        count        = count,
        signature    = hold.itemSignature or hold.itemLink,
        itemLink     = hold.itemLink,
        containerKey = containerKey,
        destBags     = { BAG_BACKPACK },
        sourceBags   = srcBags,
    }
end

-- ---------------------------------------------------------------------------
-- Public: deposit
-- Plan (synchronous): resolve every source stack this character can put toward
-- each hold -- enough stacks to cover an item hold's outstanding count, or
-- every selected piece of a set hold -- reserving source + destination slots
-- per pass. Then pump to issue the first move. Returns (enqueued, blockedBySpace).
-- ---------------------------------------------------------------------------

-- Items an item hold still needs moved out of characters' bags. Anything
-- already deposited or delivered counts toward the request.
local function depositNeed(hold)
    local want = tonumber(hold.desiredCount) or 1
    local done = math.max(tonumber(hold.depositedCount) or 0, tonumber(hold.deliveredCount) or 0)
    return math.max(0, want - done)
end

function Mover:DepositForHolds(containerKey, holds)
    local me = addon:GetCharacterId()
    local reserved = {}
    local enqueued, blocked = 0, 0
    local guild = isGuildContainer(containerKey)

    for _, hold in ipairs(holds or {}) do
        local isSet = hold.holdType == "set"
        local need = isSet and math.huge or depositNeed(hold)
        for _, c in ipairs(hold.candidates or {}) do
            if need <= 0 then break end
            if c.characterId == me and not c.isCharacterBound then
                local srcBag, srcSlot = resolveLiveSource(c, hold, reserved)
                if srcBag and srcSlot then
                    -- Guild transfers move the WHOLE source stack
                    -- (TransferToGuildBank takes no count), so record the true
                    -- full-stack count for truthful logs/state. Bag transport
                    -- honours the reserved partial count.
                    local srcStack = (GetSlotStackSize and GetSlotStackSize(srcBag, srcSlot))
                        or c.count or 1
                    local count
                    if guild or isSet then
                        count = srcStack
                    else
                        count = math.min(need, srcStack)
                    end
                    if count > 0 then
                        local destBags, ok = nil, false
                        if guild then
                            if bagHasFreeSlot(BAG_GUILDBANK) then
                                destBags = { BAG_GUILDBANK }
                                ok = true
                            end
                        else
                            destBags = containerDestBags(containerKey)
                            local destBag, destSlot
                            for _, b in ipairs(destBags) do
                                local slot = firstUnreservedEmpty(b, reserved)
                                if slot then destBag, destSlot = b, slot; break end
                            end
                            if destBag then
                                reserved[rk(destBag, destSlot)] = true
                                ok = true
                            end
                        end
                        if ok then
                            reserved[rk(srcBag, srcSlot)] = true
                            self:_enqueue(self:_makeDepositJob(
                                hold, srcBag, srcSlot, count, containerKey, guild, destBags))
                            enqueued = enqueued + 1
                            need = need - count
                        else
                            blocked = blocked + 1
                            break -- no room for this hold's remaining stacks
                        end
                    end
                end
            end
        end
    end

    self:_pump()
    self:_ReportSpaceBlocked("deposit", containerKey, blocked)
    return enqueued, blocked
end

-- ---------------------------------------------------------------------------
-- Public: withdraw
-- Plans every stack an item hold still needs and every selected piece of a set
-- hold that is in this container. Each job carries the hold's plan so the move
-- that completes the hold -- and only that one -- marks it delivered.
-- ---------------------------------------------------------------------------
function Mover:WithdrawForHolds(containerKey, holds)
    local reserved = {}
    local enqueued, blocked = 0, 0
    local guild   = isGuildContainer(containerKey)
    local srcBags = containerSourceBags(containerKey)

    for _, hold in ipairs(holds or {}) do
        local isSet = hold.holdType == "set"
        local need = isSet and math.huge or (addon.Holds:RemainingCount(hold) or 0)
        local jobs, holdBlocked = {}, false
        while need > 0 do
            local srcBag, srcSlot, sourceCount = self:_findWithdrawSource(hold, containerKey, srcBags, reserved)
            if not srcBag then break end
            local destSlot = firstUnreservedEmpty(BAG_BACKPACK, reserved)
            if not destSlot then
                blocked = blocked + 1
                holdBlocked = true
                break
            end
            local count
            if guild or isSet then
                -- Guild withdraws move the whole stack (TransferFromGuildBank
                -- takes no count), so record the true full-stack count.
                count = sourceCount or 1
            else
                count = math.min(need, sourceCount or 1)
            end
            if count <= 0 then break end
            reserved[rk(srcBag, srcSlot)]        = true
            reserved[rk(BAG_BACKPACK, destSlot)] = true
            jobs[#jobs + 1] = self:_makeWithdrawJob(
                hold, srcBag, srcSlot, count, containerKey, guild, srcBags)
            need = need - count
        end

        if #jobs > 0 then
            local plan = { jobs = #jobs, confirmed = 0 }
            if isSet then
                -- Withdrawing everything here finishes the hold only when no
                -- selected piece is still out on a character or in another
                -- container, and nothing was left behind for lack of space.
                plan.setComplete = not holdBlocked
                    and addon.Holds:OutstandingSetPiecesOutside(hold, containerKey) == 0
            end
            for _, job in ipairs(jobs) do
                job.plan = plan
                self:_enqueue(job)
                enqueued = enqueued + 1
            end
        end
    end

    self:_pump()
    self:_ReportSpaceBlocked("withdraw", containerKey, blocked)
    return enqueued, blocked
end
-- Resolve one live source (bag, slot, stackCount) for a withdraw hold in the
-- open container. Trusts a cached index row first, then re-scans by signature.
function Mover:_findWithdrawSource(hold, containerKey, srcBags, reserved)
    local rows = addon.Index:RowsForHold(hold)
    for _, row in ipairs(rows) do
        if row.locationKey == containerKey then
            local b, s = row.bagId, row.slotIndex
            -- Verify against the hold, not just a non-nil signature: a set hold
            -- has no signature, and the old "no signature -> accept" path would
            -- withdraw whatever now occupies the cached slot.
            if b and s and not reserved[rk(b, s)] and slotSatisfiesHold(b, s, hold) then
                local stack = (row.entry and row.entry.stackCount)
                    or (GetSlotStackSize and GetSlotStackSize(b, s)) or 1
                return b, s, stack
            end
        end
    end
    for _, bagId in ipairs(srcBags or {}) do
        local found = findSlotForHold(bagId, hold, reserved)
        if found then
            local stack = (GetSlotStackSize and GetSlotStackSize(bagId, found)) or 1
            return bagId, found, stack
        end
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Space-blocked reporting + retry (features F1 / F2)
-- ---------------------------------------------------------------------------
function Mover:_ReportSpaceBlocked(role, containerKey, count)
    if not count or count <= 0 then return end
    self._retry = { role = role, containerKey = containerKey }
    if not addon.Notify then return end
    local msg
    if role == "deposit" then
        msg = GetString(SI_ACCOUNTHOLD_ALERT_BANK_FULL):format(count)
    else
        msg = GetString(SI_ACCOUNTHOLD_ALERT_INV_FULL):format(count)
    end
    addon.Notify:Alert(msg)
end

function Mover:HasPendingRetry()
    return self._retry ~= nil
end

function Mover:RetryPending()
    local r = self._retry
    if not r then
        if addon.Notify then
            addon.Notify:Alert(GetString(SI_ACCOUNTHOLD_ALERT_RETRY_NONE))
        end
        return 0
    end
    self._retry = nil
    local asRole = (r.role == "deposit") and "holder" or "requester"
    local holds  = addon.Holds:GetHoldsAtContainer(r.containerKey, asRole)
    local queued
    if r.role == "deposit" then
        queued = self:DepositForHolds(r.containerKey, holds)
    else
        queued = self:WithdrawForHolds(r.containerKey, holds)
    end
    -- The value returned is queued (not yet confirmed) work; the actual moved
    -- count is announced by the batch completion. Report truthfully.
    if addon.Notify then
        addon.Notify:Alert(GetString(SI_ACCOUNTHOLD_ALERT_RETRY_DONE):format(queued or 0))
    end
    return queued
end

-- ---------------------------------------------------------------------------
-- Convenience: container-key for the container the player just opened
-- ---------------------------------------------------------------------------
function Mover:ContainerKeyForOpenedBag(bagId)
    if bagId == BAG_BANK or (BAG_SUBSCRIBER_BANK and bagId == BAG_SUBSCRIBER_BANK) then
        return "bank"
    elseif bagId == BAG_GUILDBANK then
        local guildId = addon.Scanner and addon.Scanner._currentGuildBankId or 0
        if guildId ~= 0 then return "guildbank:" .. tostring(guildId) end
    else
        local houseId = GetCurrentZoneHouseId and GetCurrentZoneHouseId() or 0
        if houseId ~= 0 then return string.format("house:%d:%d", houseId, bagId) end
    end
    return nil
end
