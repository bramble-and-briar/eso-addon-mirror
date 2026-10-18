-- Quartermaster/src/Holds.lua
-- Hold lifecycle state machine + retention purge.
-- A "hold" is a request that an item or set be moved across characters via a
-- shared container. State transitions are described in brief §8.

AccountHold = AccountHold or {}
AccountHold.Holds = AccountHold.Holds or {}

local Holds = AccountHold.Holds
local addon

local STATE_OPEN              = "open"
local STATE_AWAITING_DEPOSIT  = "awaiting_deposit"
local STATE_IN_TRANSIT_PREFIX = "in_transit:"
local STATE_DELIVERED         = "delivered"
local STATE_CANCELLED         = "cancelled"

Holds.STATE_OPEN              = STATE_OPEN
Holds.STATE_AWAITING_DEPOSIT  = STATE_AWAITING_DEPOSIT
Holds.STATE_IN_TRANSIT_PREFIX = STATE_IN_TRANSIT_PREFIX
Holds.STATE_DELIVERED         = STATE_DELIVERED
Holds.STATE_CANCELLED         = STATE_CANCELLED

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------

function Holds:Initialize(addonRef)
    addon = addonRef
    -- One-shot retention purge on init. Cheap; SV holds map is small.
    self:PurgeExpired()
    -- P0 #3: rerun the purge hourly so long-running sessions don't leak
    -- delivered/cancelled holds past holdRetentionDays.
    if EVENT_MANAGER and EVENT_MANAGER.RegisterForUpdate then
        EVENT_MANAGER:RegisterForUpdate(addon.name .. "_PurgeTimer",
            60 * 60 * 1000,
            function() self:PurgeExpired() end)
    end
end

-- ---------------------------------------------------------------------------
-- ID allocation
-- ---------------------------------------------------------------------------

local function nextHoldId()
    local id = addon.sv.nextHoldId or 1
    addon.sv.nextHoldId = id + 1
    return id
end

-- ---------------------------------------------------------------------------
-- Candidate snapshot
-- ---------------------------------------------------------------------------

-- Build the list of `where can this hold be filled from` rows by querying the
-- index. Stores a snapshot on the hold so the UI can show holders even when
-- the holder character is offline. Every character can act as a deposit
-- source, so all character-owned and container-owned candidates are eligible.
local function refreshCandidates(hold)
    hold.candidates = {}
    if not addon.Index or not addon.Index.RowsForHold then return end
    local rows = addon.Index:RowsForHold(hold)
    for _, row in ipairs(rows) do
        hold.candidates[#hold.candidates + 1] = {
            characterId       = row.characterId,
            bagId             = row.bagId,
            slotIndex         = row.slotIndex,
            count             = row.entry.stackCount or 1,
            isCharacterBound  = row.entry.isCharacterBound and true or false,
            locationKey       = row.locationKey,
            locationLabel     = row.locationLabel,
        }
    end
end

function Holds:RefreshAllCandidates()
    for _, hold in pairs(addon.sv.holds) do
        if hold.status ~= STATE_DELIVERED and hold.status ~= STATE_CANCELLED then
            refreshCandidates(hold)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Live "can this character actually deposit it?" verification
-- ---------------------------------------------------------------------------
-- hold.candidates is a SavedVariables-derived snapshot (refreshCandidates ->
-- Index:RowsForHold, which walks the persisted index). The current character's
-- own snapshot is only refreshed on login and per-slot updates -- opening a
-- bank rescans the CONTAINER, never the player's bags (see Scanner's
-- EVENT_OPEN_BANK handler and BankTab_Gamepad's refreshOpenContainer). So a
-- hold whose item was consumed, sold, or moved while the addon wasn't watching
-- still lists this character as a holder. The bank then offered a Deposit the
-- Mover could not fulfil, and the player got the misleading "may no longer be
-- in the bank" alert for an item they never had.
--
-- Every holder-role surface now confirms against the LIVE bags first.

-- One bag walk producing the set of item links and set ids this character is
-- physically carrying, so verifying N holds costs one walk instead of N.
-- Returns nil when the live item API isn't available (test harness, or an
-- unexpected client state); callers treat nil as "unverifiable" and fall back
-- to the snapshot rather than hiding every deposit.
function Holds:BuildLiveCarryIndex()
    if type(GetBagSize) ~= "function" or type(GetItemLink) ~= "function" then
        return nil
    end
    local carry = { signatures = {}, setIds = {}, setSignatures = {} }
    local bags = {}
    if BAG_BACKPACK then bags[#bags + 1] = BAG_BACKPACK end
    if BAG_WORN     then bags[#bags + 1] = BAG_WORN     end
    for _, bagId in ipairs(bags) do
        local size = 0
        local okSize, value = pcall(GetBagSize, bagId)
        if okSize and type(value) == "number" then size = value end
        for slot = 0, size - 1 do
            local empty = false
            if type(IsItemBagAndSlotEmpty) == "function" then
                local okEmpty, isEmpty = pcall(IsItemBagAndSlotEmpty, bagId, slot)
                empty = okEmpty and isEmpty
            end
            if not empty then
                local okLink, link = pcall(GetItemLink, bagId, slot, LINK_STYLE_DEFAULT)
                if okLink and link and link ~= "" then
                    carry.signatures[link] = true
                    if type(GetItemLinkSetInfo) == "function" then
                        local okSet, hasSet, _, _, _, _, setId = pcall(GetItemLinkSetInfo, link)
                        if okSet and hasSet and setId then
                            carry.setIds[setId] = true
                            carry.setSignatures[setId] = carry.setSignatures[setId] or {}
                            carry.setSignatures[setId][link] = true
                        end
                    end
                end
            end
        end
    end
    return carry
end

-- Can the current character physically fill this hold right now? `carry` is an
-- optional index from BuildLiveCarryIndex, shared across a batch of checks.
function Holds:CanCurrentCharacterSupply(hold, carry)
    if not hold then return false end
    if carry == nil then carry = self:BuildLiveCarryIndex() end
    -- Unverifiable (no live item API): don't hide the hold.
    if carry == nil then return true end
    if hold.holdType == "item" then
        return hold.itemSignature ~= nil and carry.signatures[hold.itemSignature] == true
    elseif hold.holdType == "set" then
        if hold.setId == nil or carry.setIds[hold.setId] ~= true then return false end
        -- Only pieces the player kept selected count; carrying nothing but
        -- deselected pieces means there is nothing to deposit.
        local sigs = carry.setSignatures and carry.setSignatures[hold.setId]
        if type(sigs) ~= "table" then return true end
        for link in pairs(sigs) do
            if self:IsMemberIncluded(hold, link) then return true end
        end
        return false
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Create / cancel
-- ---------------------------------------------------------------------------

-- The character a hold's item is destined for. Newer holds carry an explicit
-- targetCharacterId (the player can reserve an item for any of their allowed
-- characters); older holds fall back to whoever created them.
local function holdTarget(hold)
    return hold.targetCharacterId or hold.requestedByCharacterId
end
Holds.Target = holdTarget

-- spec = {
--   holdType        = "item" | "set",
--   itemSignature   = string?,    -- required for "item"
--   setId           = number?,    -- required for "set"
--   itemLink        = string?,    -- display only
--   desiredCount    = number,
--   targetCharacterId = string?,  -- who the item is reserved FOR (default: current char)
--   preferredRoute  = "account_bank" | "guild_bank:<id>" | "house:<id>",
--   equipOnReceive  = boolean,
-- }
function Holds:Create(spec)
    assert(spec and spec.holdType, "holdType required")
    if spec.holdType == "item" then assert(spec.itemSignature, "itemSignature required") end
    if spec.holdType == "set"  then assert(spec.setId, "setId required") end

    local target = spec.targetCharacterId or addon:GetCharacterId()
    local id   = nextHoldId()
    local now  = GetTimeStamp()
    local hold = {
        id              = id,
        holdType        = spec.holdType,
        itemSignature   = spec.itemSignature,
        setId           = spec.setId,
        itemLink        = spec.itemLink,
        desiredCount    = spec.desiredCount or 1,
        requestedByCharacterId = addon:GetCharacterId(),
        targetCharacterId = target,
        targetEquipSlot = spec.targetEquipSlot,
        preferredRoute  = spec.preferredRoute or "account_bank",
        equipOnReceive  = spec.equipOnReceive and true or false,
        status          = STATE_OPEN,
        candidates      = {},
        log             = {},
        createdAt       = now,
        updatedAt       = now,
    }
    refreshCandidates(hold)
    -- If any non-bound candidate exists on a character OTHER than the target
    -- (i.e. a holder the item must be moved away from), advance straight to
    -- awaiting_deposit. An item already sitting on the target character needs
    -- no deposit.
    for _, c in ipairs(hold.candidates) do
        if not c.isCharacterBound and c.characterId and c.characterId ~= target then
            hold.status = STATE_AWAITING_DEPOSIT
            break
        end
    end
    addon.sv.holds[id] = hold

    self:LogToHold(hold, GetString(SI_ACCOUNTHOLD_LOG_HOLD_CREATED):format(
        spec.itemLink or tostring(spec.setId or "?"),
        hold.desiredCount,
        (addon:GetCharacterRecord(target).name or "?")))
    return hold
end

function Holds:Cancel(holdId)
    local hold = addon.sv.holds[holdId]
    if not hold then return end
    hold.status    = STATE_CANCELLED
    hold.updatedAt = GetTimeStamp()
    self:LogToHold(hold, GetString(SI_ACCOUNTHOLD_LOG_HOLD_CANCELLED):format(tostring(holdId)))
end

-- Find the first active (not delivered/cancelled) hold that matches the item
-- on `row` — by itemSignature for item holds, or by setId for set holds.
-- Used by the place-hold flow to detect an existing reservation so the player
-- can be asked whether to override it (bug 3), and by the inventory Cancel (Y)
-- keybind to decide whether a matching hold exists.
--
-- `holdType` (optional) restricts the match to that kind of hold: "item" only
-- matches item-signature holds, "set" only matches set-id holds. Omitting it
-- (nil) keeps the historical behaviour of matching either kind, which the
-- Cancel/visibility paths rely on.
function Holds:FindActiveHoldForRow(row, holdType)
    local e = row and row.entry
    if not e then return nil end
    for _, hold in pairs(addon.sv.holds) do
        if hold.status ~= STATE_DELIVERED and hold.status ~= STATE_CANCELLED then
            local itemMatch = hold.holdType == "item" and hold.itemSignature
                and hold.itemSignature == e.itemSignature
            local setMatch = hold.holdType == "set" and hold.setId and e.setId
                and hold.setId == e.setId
            if holdType == "item" then
                if itemMatch then return hold end
            elseif holdType == "set" then
                if setMatch then return hold end
            elseif itemMatch or setMatch then
                return hold
            end
        end
    end
    return nil
end

-- Human-readable name of the character a hold is reserved FOR. Reads the
-- character record directly (NOT addon:GetCharacterRecord, which fabricates a
-- record under the current character's name for an unknown id).
function Holds:HolderName(hold)
    local id = hold and (hold.targetCharacterId or hold.requestedByCharacterId)
    if id and addon.sv and addon.sv.characters and addon.sv.characters[id] then
        return addon.sv.characters[id].name
    end
    return nil
end

-- Find an active hold that matches a raw item link — matching by exact link
-- signature ("item" holds) or by set id ("set" holds). Used to annotate the
-- native item tooltip with a "Reserved" line at the bank / anywhere the
-- player inspects an item (bug 8). Returns the hold or nil.
function Holds:FindActiveHoldByItemLink(itemLink)
    if not itemLink or itemLink == "" or not (addon.sv and addon.sv.holds) then
        return nil
    end
    -- Fast path: no reservations at all -> skip the set-info API call entirely.
    -- This runs from the global tooltip hook on EVERY item tooltip in the game,
    -- so the common "player has no holds" case must cost nothing.
    if not next(addon.sv.holds) then return nil end
    local setId
    if GetItemLinkSetInfo then
        local ok, hasSet, _, _, _, _, sid = pcall(GetItemLinkSetInfo, itemLink)
        if ok and hasSet then setId = sid end
    end
    for _, hold in pairs(addon.sv.holds) do
        if hold.status ~= STATE_DELIVERED and hold.status ~= STATE_CANCELLED then
            if hold.holdType == "item" and hold.itemSignature == itemLink then
                return hold
            elseif hold.holdType == "set" and setId and hold.setId == setId then
                return hold
            end
        end
    end
    return nil
end

-- Cancel every active hold that matches the item on `row` (item signature or
-- setId). Returns the number cancelled. Used when the player elects to
-- override an existing reservation before placing a new one.
--
-- `holdType` (optional) restricts cancellation to that kind of hold ("item" or
-- "set"). Omitting it cancels either kind, which the inventory Cancel action
-- relies on ("clear the holds for this thing").
function Holds:CancelActiveForRow(row, holdType)
    local e = row and row.entry
    if not e then return 0 end
    local n = 0
    for id, hold in pairs(addon.sv.holds) do
        if hold.status ~= STATE_DELIVERED and hold.status ~= STATE_CANCELLED then
            local itemMatch = hold.holdType == "item" and hold.itemSignature
                and hold.itemSignature == e.itemSignature
            local setMatch = hold.holdType == "set" and hold.setId and e.setId
                and hold.setId == e.setId
            local match
            if holdType == "item" then
                match = itemMatch
            elseif holdType == "set" then
                match = setMatch
            else
                match = itemMatch or setMatch
            end
            if match then
                self:Cancel(id)
                n = n + 1
            end
        end
    end
    return n
end

-- Cancel every open / awaiting / in-transit hold. Used by the Settings
-- panel "Clear all holds" action and by AccountHold:WipeData("holds")
-- before the holds table is cleared.
function Holds:CancelAll()
    local n = 0
    for id, hold in pairs(addon.sv.holds) do
        if hold.status ~= STATE_DELIVERED and hold.status ~= STATE_CANCELLED then
            self:Cancel(id)
            n = n + 1
        end
    end
    if n > 0 and addon.Log then
        addon:Log(GetString(SI_ACCOUNTHOLD_LOG_CANCELLED_N):format(n))
    end
    return n
end

-- Cancel every active hold reserved for (targeted at) the current character.
-- Bound to the gamepad tab's "Clear My Holds" keybind so a player can drop
-- just their own reservations without touching other characters' holds or the
-- scanned inventory snapshot (full wipes live in Settings only).
function Holds:CancelForCurrentCharacter()
    local me = addon:GetCharacterId()
    local n = 0
    for id, hold in pairs(addon.sv.holds) do
        if hold.status ~= STATE_DELIVERED and hold.status ~= STATE_CANCELLED
           and holdTarget(hold) == me then
            self:Cancel(id)
            n = n + 1
        end
    end
    if n > 0 and addon.Log then
        addon:Log(GetString(SI_ACCOUNTHOLD_LOG_CANCELLED_N):format(n))
    end
    return n
end

-- Count active holds reserved for the current character (drives keybind
-- visibility so "Clear My Holds" only shows when there is something to clear).
function Holds:CountForCurrentCharacter()
    local me = addon:GetCharacterId()
    local n = 0
    for _, hold in pairs(addon.sv.holds) do
        if hold.status ~= STATE_DELIVERED and hold.status ~= STATE_CANCELLED
           and holdTarget(hold) == me then
            n = n + 1
        end
    end
    return n
end

local MAX_HOLD_LOG_ENTRIES = 20

function Holds:LogToHold(hold, message)
    hold.log = hold.log or {}
    hold.log[#hold.log + 1] = { ts = GetTimeStamp(), msg = message }
    -- Cap the per-hold log so a long-lived or frequently-updated hold can't
    -- bloat SavedVariables without bound. Keep only the most recent entries.
    local overflow = #hold.log - MAX_HOLD_LOG_ENTRIES
    if overflow > 0 then
        for i = 1, #hold.log do
            hold.log[i] = hold.log[i + overflow]
        end
    end
end

-- ---------------------------------------------------------------------------
-- State transitions called by Mover
-- ---------------------------------------------------------------------------

function Holds:MarkInTransit(holdId, containerKey)
    local hold = addon.sv.holds[holdId]; if not hold then return end
    hold.status    = STATE_IN_TRANSIT_PREFIX .. tostring(containerKey)
    hold.updatedAt = GetTimeStamp()
end

function Holds:MarkDelivered(holdId)
    local hold = addon.sv.holds[holdId]; if not hold then return end
    hold.status      = STATE_DELIVERED
    hold.updatedAt   = GetTimeStamp()
    hold.deliveredAt = hold.updatedAt
end

-- ---------------------------------------------------------------------------
-- Fulfilment accounting
-- ---------------------------------------------------------------------------
-- A hold is only finished when everything it asked for has arrived. One
-- confirmed move used to mark the whole hold delivered, so a request for five
-- items completed after the first stack of three, and a set hold completed
-- after its first piece.

-- Item holds: how many more items the target still needs. nil for set holds,
-- whose need is a set of pieces rather than a count.
function Holds:RemainingCount(hold)
    if type(hold) ~= "table" or hold.holdType ~= "item" then return nil end
    local want = tonumber(hold.desiredCount) or 1
    return math.max(0, want - (tonumber(hold.deliveredCount) or 0))
end

-- Set holds: selected pieces that are neither with the target already nor in
-- `containerKey`. Zero means withdrawing everything in that container finishes
-- the hold.
function Holds:OutstandingSetPiecesOutside(hold, containerKey)
    if type(hold) ~= "table" or hold.holdType ~= "set" then return 0 end
    local target = holdTarget(hold)
    local n = 0
    for _, m in ipairs(self:GetSetMembers(hold)) do
        if m.included and m.locationKey ~= containerKey
           and not (target ~= nil and m.characterId == target) then
            n = n + 1
        end
    end
    return n
end

-- A confirmed deposit of `count` items into `containerKey`.
function Holds:RecordDeposit(holdId, count, containerKey)
    local hold = addon.sv.holds[holdId]; if not hold then return end
    hold.depositedCount = (tonumber(hold.depositedCount) or 0) + (tonumber(count) or 1)
    self:MarkInTransit(holdId, containerKey)
end

-- A confirmed withdrawal of `count` items. `setComplete` says whether, for a set
-- hold, this was the last piece the hold needed. Returns true when the hold is
-- now fully delivered.
function Holds:RecordWithdrawal(holdId, count, setComplete)
    local hold = addon.sv.holds[holdId]; if not hold then return false end
    hold.deliveredCount = (tonumber(hold.deliveredCount) or 0) + (tonumber(count) or 1)
    local fulfilled
    if hold.holdType == "item" then
        fulfilled = self:RemainingCount(hold) == 0
    else
        fulfilled = setComplete and true or false
    end
    if fulfilled then
        self:MarkDelivered(holdId)
    else
        hold.updatedAt = GetTimeStamp()
    end
    return fulfilled
end

-- May the current character still deposit toward this hold? Open/awaiting holds
-- always may; an in-transit hold may too while part of it is still out on a
-- character (a set split across alts, or a quantity spread over stacks).
local function holderMaySupply(self, hold, me, carry)
    if holdTarget(hold) == me then return false end
    local status = hold.status or ""
    local inTransit = string.sub(status, 1, #STATE_IN_TRANSIT_PREFIX) == STATE_IN_TRANSIT_PREFIX
    if not (status == STATE_AWAITING_DEPOSIT or status == STATE_OPEN or inTransit) then
        return false
    end
    if inTransit and hold.holdType == "item"
       and (tonumber(hold.depositedCount) or 0) >= (tonumber(hold.desiredCount) or 1) then
        return false
    end
    for _, c in ipairs(hold.candidates or {}) do
        if c.characterId == me and not c.isCharacterBound then
            return self:CanCurrentCharacterSupply(hold, carry)
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Queries used by Notify / UI
-- ---------------------------------------------------------------------------

function Holds:GetActiveHoldsForCurrentCharacterAsHolder()
    -- Holds whose candidate set lists THIS character as a non-bound holder
    -- and which still need depositing. Every character can deposit; we only
    -- skip holds whose target is this character (no point depositing an item
    -- to yourself). The snapshot claim is confirmed against the live bags so
    -- we never announce a deposit the player cannot actually perform.
    local me  = addon:GetCharacterId()
    local out = {}
    local carry = self:BuildLiveCarryIndex()
    for _, hold in pairs(addon.sv.holds) do
        if holderMaySupply(self, hold, me, carry) then
            out[#out + 1] = hold
        end
    end
    return out
end

function Holds:GetActiveHoldsForCurrentCharacterAsRequester()
    -- Holds targeted at THIS character that are awaiting pickup.
    local me  = addon:GetCharacterId()
    local out = {}
    for _, hold in pairs(addon.sv.holds) do
        if holdTarget(hold) == me and
           string.sub(hold.status or "", 1, #STATE_IN_TRANSIT_PREFIX) == STATE_IN_TRANSIT_PREFIX then
            out[#out + 1] = hold
        end
    end
    return out
end

-- Filter to holds whose currently-open container is the provided one, for the
-- in-bank action panel.
function Holds:GetHoldsAtContainer(containerKey, asRole)
    local me  = addon:GetCharacterId()
    local out = {}
    -- Built once per call and only when it can matter (holder role).
    local carry
    if asRole == "holder" then carry = self:BuildLiveCarryIndex() end
    for _, hold in pairs(addon.sv.holds) do
        local include = false
        if asRole == "holder" then
            -- Deposit if a candidate on this character exists and part of the
            -- hold still needs depositing. We don't pin the route — any
            -- container the holder opens is acceptable (brief §4.2). Every
            -- character can deposit; we only skip holds targeted at this
            -- character. The candidate snapshot is confirmed against the live
            -- bags, so a stale entry can't offer a Deposit the Mover will fail
            -- to fill.
            include = holderMaySupply(self, hold, me, carry)
        elseif asRole == "requester" then
            if holdTarget(hold) == me then
                local status = hold.status or ""
                if status == STATE_IN_TRANSIT_PREFIX .. containerKey then
                    include = true
                elseif status ~= STATE_DELIVERED and status ~= STATE_CANCELLED then
                    -- A reservation created while the item is already in this
                    -- shared container needs no holder-side deposit first. The
                    -- same applies to part of a hold that is in transit
                    -- elsewhere, e.g. set pieces deposited into two containers.
                    for _, c in ipairs(hold.candidates or {}) do
                        if c.locationKey == containerKey then
                            include = true
                            break
                        end
                    end
                end
            end
        end
        if include then out[#out + 1] = hold end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Set-hold membership
-- ---------------------------------------------------------------------------
-- A SET hold is satisfied by ANY piece of the set, so a single reservation can
-- cover many physical items. Displaying it as N reserved rows buries the
-- reservation in noise, so both UI surfaces collapse it to one row and expand
-- on demand.
--
-- Expanding also lets the player narrow the reservation: deselecting a piece
-- means "don't move this one". We store EXCLUSIONS rather than inclusions so
-- the default (a hold with no selection state at all, including every hold
-- created before this existed) means "every piece counts" — the behaviour that
-- was already shipping.
--
-- Keyed by itemSignature because that is the only identity stable across a
-- rescan: bag/slot move, and itemLink is not unique per physical stack.

-- Is this piece part of the reservation? Unknown/absent state means yes.
function Holds:IsMemberIncluded(hold, itemSignature)
    if type(hold) ~= "table" or itemSignature == nil or itemSignature == "" then
        return true
    end
    local excluded = hold.excludedSignatures
    if type(excluded) ~= "table" then return true end
    return excluded[itemSignature] ~= true
end

-- Include/exclude one piece. Returns the new included state.
--
-- Refuses to exclude the LAST included piece: a set hold with nothing selected
-- would sit in the list forever, matching nothing and never completing, which
-- looks exactly like the "reserved but nothing happens" bug this add-on already
-- had once. Cancelling the hold is the way to want none of it.
function Holds:SetMemberIncluded(hold, itemSignature, included)
    if type(hold) ~= "table" or itemSignature == nil or itemSignature == "" then
        return true
    end
    included = included and true or false

    if not included then
        local remaining = 0
        for _, m in ipairs(self:GetSetMembers(hold)) do
            if m.included and m.itemSignature ~= itemSignature then
                remaining = remaining + 1
            end
        end
        if remaining == 0 then
            self:LogToHold(hold, GetString(SI_ACCOUNTHOLD_LOG_HOLD_LAST_PIECE))
            return true
        end
    end

    hold.excludedSignatures = hold.excludedSignatures or {}
    if included then
        hold.excludedSignatures[itemSignature] = nil
    else
        hold.excludedSignatures[itemSignature] = true
    end
    hold.updatedAt = GetTimeStamp()
    return included
end

-- Every account item that satisfies this hold, newest snapshot, each tagged
-- with whether the player has it selected.
--
-- Returns an empty list for item holds: they have exactly one identity and
-- nothing to expand.
function Holds:GetSetMembers(hold)
    local out = {}
    if type(hold) ~= "table" or hold.holdType ~= "set" then return out end
    if not (addon and addon.Index and addon.Index.RowsForHold) then return out end

    local ok, rows = pcall(addon.Index.RowsForHold, addon.Index, hold)
    if not ok or type(rows) ~= "table" then return out end

    -- One physical item may appear once per location; keep them all, because
    -- the player is choosing which COPIES to move, not which item names.
    for _, row in ipairs(rows) do
        local e = row.entry
        if e and e.itemSignature then
            out[#out + 1] = {
                row           = row,
                entry         = e,
                itemSignature = e.itemSignature,
                name          = e.name,
                itemLink      = e.itemLink,
                locationKey   = row.locationKey,
                locationLabel = row.locationLabel,
                characterId   = row.characterId,
                included      = self:IsMemberIncluded(hold, e.itemSignature),
            }
        end
    end
    return out
end

-- How many pieces are currently selected, and how many exist in total.
function Holds:CountSetMembers(hold)
    local included, total = 0, 0
    for _, m in ipairs(self:GetSetMembers(hold)) do
        total = total + 1
        if m.included then included = included + 1 end
    end
    return included, total
end

function Holds:GetPendingHoldsForCharacter(containerKey)
    local me       = addon:GetCharacterId()
    local excluded = {}
    local out      = {}

    for _, hold in ipairs(self:GetHoldsAtContainer(containerKey, "requester")) do
        if hold.id then excluded[hold.id] = true end
    end
    for _, hold in ipairs(self:GetHoldsAtContainer(containerKey, "holder")) do
        if hold.id then excluded[hold.id] = true end
    end

    for _, hold in pairs(addon.sv.holds) do
        if hold.status ~= STATE_DELIVERED
           and hold.status ~= STATE_CANCELLED
           and not excluded[hold.id]
           and (hold.requestedByCharacterId == me or holdTarget(hold) == me) then
            out[#out + 1] = hold
        end
    end
    return out
end

local function safeString(stringId, fallback)
    if type(GetString) == "function" and stringId ~= nil then
        local ok, value = pcall(GetString, stringId)
        if ok and value and value ~= "" then return value end
    end
    return fallback
end

function Holds:DescribePendingStatus(hold)
    local status = hold and hold.status
    if status == STATE_AWAITING_DEPOSIT then
        return safeString(SI_ACCOUNTHOLD_STATUS_AWAITING, "Awaiting deposit")
    elseif status == STATE_OPEN then
        return safeString(SI_ACCOUNTHOLD_STATUS_RESERVED, "Reserved")
    elseif type(status) == "string"
       and string.sub(status, 1, #STATE_IN_TRANSIT_PREFIX) == STATE_IN_TRANSIT_PREFIX then
        return safeString(SI_ACCOUNTHOLD_STATUS_IN_TRANSIT, "In transit")
    end
    return safeString(SI_ACCOUNTHOLD_STATUS_RESERVED, "Reserved")
end

-- ---------------------------------------------------------------------------
-- Retention purge
-- ---------------------------------------------------------------------------

function Holds:PurgeExpired()
    local days  = (addon.sv.settings.holdRetentionDays or 7)
    local maxAge = days * 24 * 60 * 60
    local now   = GetTimeStamp()
    local purged = 0
    for id, hold in pairs(addon.sv.holds) do
        if (hold.status == STATE_DELIVERED or hold.status == STATE_CANCELLED)
           and hold.updatedAt and (now - hold.updatedAt) > maxAge then
            addon.sv.holds[id] = nil
            purged = purged + 1
        end
    end
    if purged > 0 then
        addon:Debug(GetString(SI_ACCOUNTHOLD_LOG_HOLD_PURGED):format(purged))
    end
end
