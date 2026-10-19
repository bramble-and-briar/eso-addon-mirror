if not SemisPlaygroundCheckAccess() then return end

---@class InventoryPocLogDetails
---@field slot number
---@field uniqueId string
---@field stack number
---@field vendorUnit number
---@field marketUnit number|nil
---@field styleMaterialLink string
---@field styleMaterialUnit number|nil
---@field traitMaterialLink string
---@field traitMaterialUnit number|nil

---@class InventoryPocLogEntry
---@field timestamp number
---@field character string
---@field action InventoryPocAction
---@field result 'done'|'uncertain'|'deferred'
---@field itemLink string
---@field itemId number
---@field quantity number
---@field gold number|nil
---@field reason InventoryPocReason|nil
---@field fromBag number
---@field toBag number|nil
---@field guildId number|nil
---@field askingPrice number|nil
---@field fee number|nil
---@field buildName string|nil
---@field setupName string|nil
---@field buildIssue InventoryPocBuildIssue|nil
---@field details InventoryPocLogDetails|nil Absent on older entries
---@field discount number|nil Listing multiplier at the time of posting
---@class InventoryPocPending
---@field item InventoryPocItem
---@field action InventoryPocAction
---@field quantity number
---@field started number
---@field character string
---@field sourceTotal number
---@field toBag number|nil
---@field toSlot number|nil
---@field toCount number|nil
---@field destinationTotal number|nil
---@field receipt boolean|nil
---@field conflicted boolean|nil
---@field gold number|nil
---@field guildId number|nil
---@field askingPrice number|nil
---@field fee number|nil
---@field reason InventoryPocReason|nil
---@field discount number|nil
---@field finished boolean|nil Batch entries remain until the whole batch is reconciled
---@class InventoryPocBatch
---@field action 'sell'|'deconstruct'
---@field entries InventoryPocPending[]
---@field totals table<string, number> Bag/link totals before any requests were sent
---@class InventoryPocPass
---@field reserved table<string, boolean>
---@field backpack InventoryPocItem[]
---@field bank InventoryPocItem[]|nil
---@field worn InventoryPocItem[]|nil
---@class InventoryPocSaved
---@field enabled boolean
---@field log InventoryPocLogEntry[]
---@field reports InventoryPocSnapshot[]
---@field companions table<number, InventoryPocItem[]>
---@field apPotions table<number, boolean>
---@field builds table<string, InventoryPocBuildState>
---@field returns InventoryPocReturnsSaved
---@field unread boolean|nil
---@field pending InventoryPocPending|nil
---@field batch InventoryPocBatch|nil
---@class InventoryPocSavedRoot
---@field accounts table<string, table<string, InventoryPocSaved>>

---@class InventoryPocRuntime
---@field saved InventoryPocSaved|nil
---@field enabled boolean
---@field registered boolean
---@field dirty boolean
---@field craftOpen boolean
---@field blocked table<string, boolean>
---@field notices table<string, boolean>
---@field revision number
---@field lastInteraction number|nil
---@field lastMoving boolean|nil
---@field ownVendorSale boolean|nil
---@field ownDeconstruction boolean|nil
---@field externalSaleUntil number|nil
---@field nextUseAt number|nil
---@field useRetryAt number|nil
local poc = {
    enabled = false, registered = false, dirty = false, craftOpen = false,
    blocked = {}, notices = {}, revision = 0,
}
BattleScrolls.inventoryPoc = poc

local facts = BattleScrolls.inventoryPocFacts
local policy = BattleScrolls.inventoryPocPolicy
local EVENT_NAME = 'BattleScrollsInventoryPoc'
local PROBE_EVENT_NAME = EVENT_NAME .. 'Probe'
local PROBE_BATCH_SIZE = 5
local ACCOUNTS = { ['@Semigroup'] = true, ['@Semigroup1329'] = true }
local MAX_LOG = 200
local INITIALIZE_DELAY_MS, START_DELAY_MS = 2000, 1000
local WORK_INTERVAL_MS, IDLE_INTERVAL_MS = 400, 1000
local startupCancelled = false
---@type number|nil
local updateInterval
---@type fun()
local update
---@type Fiber|nil
local startFiber
---@type Fiber|nil
local workFiber
---@type InventoryPocPass|nil
local workPass
---@type Fiber|nil
local probeFiber
local followupRequested = false
---@type table<string, boolean> Items handled manually during this bank visit, including split/merged stacks
local manualBankItems = {}

---@param interval number
local function setUpdateInterval(interval)
    if not poc.enabled or updateInterval == interval then return end
    updateInterval = interval
    EVENT_MANAGER:UnregisterForUpdate(EVENT_NAME)
    EVENT_MANAGER:RegisterForUpdate(EVENT_NAME, interval, update)
end

-- Schedule the next frame, coalescing receipts and bag events. The slower
-- watcher is only a timeout/state fallback, never a delay between operations.
local function resumeWork()
    if not poc.enabled then return end
    followupRequested = true
    setUpdateInterval(0)
end

---@param pending InventoryPocPending
local function refreshChangedSlots(pending)
    if not workPass then return end
    local function refresh(items, bag, slot)
        if not items then return end
        local current = facts.item(bag, slot, workPass.reserved)
        for index, item in ipairs(items) do
            if item.bag == bag and item.slot == slot then
                if current then items[index] = current else table.remove(items, index) end
                return
            end
        end
        if current then items[#items + 1] = current end
    end
    refresh(pending.item.bag == BAG_BACKPACK and workPass.backpack or workPass.bank, pending.item.bag, pending.item.slot)
    if pending.toBag then
        refresh(pending.toBag == BAG_BACKPACK and workPass.backpack or workPass.bank, pending.toBag, pending.toSlot)
    end
end

local function cancelStart()
    if startFiber then startFiber:Cancel(); startFiber = nil end
end

local function cancelProbe()
    EVENT_MANAGER:UnregisterForUpdate(PROBE_EVENT_NAME)
    if probeFiber then probeFiber:Cancel(); probeFiber = nil end
end

---@param item InventoryPocItem
---@return InventoryPocLogDetails
local function logDetails(item)
    return { slot = item.slot, uniqueId = item.uniqueId, stack = item.stack,
        vendorUnit = item.vendorUnit, marketUnit = item.marketUnit,
        styleMaterialLink = item.styleMaterialLink, styleMaterialUnit = item.styleMaterialUnit,
        traitMaterialLink = item.traitMaterialLink, traitMaterialUnit = item.traitMaterialUnit }
end

---@param item InventoryPocItem
---@return string
local function itemKey(item)
    return tostring(item.bag) .. ':' .. tostring(item.slot) .. ':' .. item.uniqueId .. ':' .. item.link
end

---@param entry InventoryPocLogEntry
function poc.appendLog(entry)
    if not poc.saved then return end
    local log = poc.saved.log
    log[#log + 1] = entry
    if entry.result ~= 'done' then poc.saved.unread = true end
    while #log > MAX_LOG do table.remove(log, 1) end
    poc.revision = poc.revision + 1
    if BattleScrolls.inventoryPocUI then BattleScrolls.inventoryPocUI.refreshNewness() end
end

---@param pending InventoryPocPending
---@param result 'done'|'uncertain'
local function finish(pending, result)
    if pending.finished then return end
    pending.finished = true
    poc.appendLog({ timestamp = GetTimeStamp(), character = pending.character, action = pending.action,
        result = result, itemLink = pending.item.link, itemId = pending.item.itemId, quantity = pending.quantity, gold = pending.gold,
        fromBag = pending.item.bag, toBag = pending.toBag, guildId = pending.guildId,
        askingPrice = pending.askingPrice, fee = pending.fee, reason = pending.reason,
        details = logDetails(pending.item), discount = pending.discount })
    if result == 'uncertain' then poc.blocked[itemKey(pending.item)] = true end
    if poc.saved.pending == pending then
        poc.saved.pending = nil
        if result == 'done' and (pending.action == 'bank' or pending.action == 'destroy' or pending.action == 'list') then
            refreshChangedSlots(pending)
        else workPass = nil end
    end
    poc.dirty = true
end

---@param item InventoryPocItem
---@param decision InventoryPocDecision
local function defer(item, decision)
    if decision.reason == 'price' and item.priceLoading then return end
    local key = itemKey(item) .. ':' .. decision.reason
    if poc.notices[key] then return end
    poc.notices[key] = true
    poc.appendLog({ timestamp = GetTimeStamp(), character = GetUnitName('player'), action = decision.action,
        result = 'deferred', itemLink = item.link, itemId = item.itemId, quantity = item.stack,
        reason = decision.reason, fromBag = item.bag, details = logDetails(item) })
end

---@return boolean
local function accountBankOpen()
    return IsBankOpen() and (GetBankingBag() == BAG_BANK or GetBankingBag() == BAG_SUBSCRIBER_BANK)
end

---@param bag number
---@param slot number
---@param link string
---@return number
local function countAt(bag, slot, link)
    if GetItemLink(bag, slot, LINK_STYLE_DEFAULT) ~= link then return 0 end
    return (GetSlotStackSize(bag, slot))
end

---@param bag number
---@param link string
---@return number
local function countBag(bag, link)
    local total = 0
    for slot = 0, GetBagSize(bag) - 1 do total = total + countAt(bag, slot, link) end
    return total
end

---@param item InventoryPocItem
---@return string
local function totalKey(item)
    return tostring(item.bag) .. ':' .. item.link
end

---@param batch InventoryPocBatch
local function reconcileBatch(batch)
    local consumed, totals, removed, bags = {}, {}, {}, {}
    for _, pending in ipairs(batch.entries) do bags[pending.item.bag] = true end
    -- Count each bag once, not once per distinct item in a large batch.
    for bag in pairs(bags) do
        for slot = 0, GetBagSize(bag) - 1 do
            local link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
            if link ~= '' then
                local key = tostring(bag) .. ':' .. link
                totals[key] = (totals[key] or 0) + GetSlotStackSize(bag, slot)
            end
            if (slot + 1) % 20 == 0 then LibEffect.Yield():Await() end
        end
    end
    for index, pending in ipairs(batch.entries) do
        local item, key = pending.item, totalKey(pending.item)
        consumed[index] = countAt(item.bag, item.slot, item.link) == item.stack - pending.quantity
        if consumed[index] then removed[key] = (removed[key] or 0) + pending.quantity end
        if index % 5 == 0 then LibEffect.Yield():Await() end
    end
    local waiting = false
    for index, pending in ipairs(batch.entries) do
        if not pending.finished then
            local key = totalKey(pending.item)
            local proven = consumed[index] and pending.receipt and (totals[key] or 0) == batch.totals[key] - (removed[key] or 0)
            if pending.conflicted then finish(pending, 'uncertain')
            elseif proven then finish(pending, 'done')
            elseif GetFrameTimeMilliseconds() - pending.started > (batch.action == 'deconstruct' and 15000 or 5000) then
                finish(pending, 'uncertain')
            else waiting = true end
        end
        if index % 5 == 0 then LibEffect.Yield():Await() end
    end
    if not waiting then
        poc.saved.batch = nil
        workPass = nil
    end
end

---@param action 'sell'|'deconstruct'
---@param items InventoryPocItem[]
---@param reserved table<string, boolean>
---@param building boolean|nil
---@return boolean
local function startBatch(action, items, reserved, building)
    if action == 'sell' and (GetInteractionType() ~= INTERACTION_VENDOR
        or (poc.externalSaleUntil and GetFrameTimeMilliseconds() < poc.externalSaleUntil)) then return false end
    if action == 'deconstruct' and (not poc.craftOpen or IsAwaitingCraftingProcessResponse()) then return false end
    local craft = GetCraftingInteractionType()
    local batch = { action = action, entries = {}, totals = {} } ---@type InventoryPocBatch
    for _, item in ipairs(items) do
        local key = totalKey(item)
        batch.totals[key] = (batch.totals[key] or 0) + item.stack
    end
    for index, item in ipairs(items) do
        if not poc.enabled or IsUnitInCombat('player') or IsUnitDead('player')
            or (action == 'sell' and GetInteractionType() ~= INTERACTION_VENDOR)
            or (action == 'deconstruct' and not poc.craftOpen) then return poc.saved.batch ~= nil end
        if not poc.blocked[itemKey(item)] and not (building and item.kind == 'food') then
            local current = facts.item(item.bag, item.slot, reserved)
            if policy.sameItem(item, current) and not current.reserved then
                local decision = policy.decide(current)
                local eligible = action == 'sell' and current.vendorUnit > 0
                    or action == 'deconstruct' and CanItemBeDeconstructed(item.bag, item.slot, craft ~= CRAFTING_TYPE_INVALID and craft or nil)
                if decision.action == action and eligible then
                    local pending = { item = current, action = action, quantity = current.stack, reason = decision.reason,
                        started = GetFrameTimeMilliseconds(), character = GetUnitName('player'), sourceTotal = batch.totals[totalKey(item)] }
                    batch.entries[#batch.entries + 1] = pending
                    if action == 'sell' then
                        -- Persist before submission. Receipts may arrive between
                        -- chunks; they do not cancel the remaining sales.
                        poc.saved.batch = batch
                        poc.ownVendorSale = true
                        SellInventoryItem(item.bag, item.slot, current.stack)
                        poc.ownVendorSale = false
                    end
                end
            end
        end
        if index % 5 == 0 then LibEffect.Yield():Await() end
    end
    if #batch.entries == 0 then return false end
    if action == 'deconstruct' then
        if not poc.craftOpen or IsAwaitingCraftingProcessResponse() then return false end
        -- Native ExtractAll prepares/adds/sends one message. Do the expensive
        -- classification above with yields, then commit without yielding: this
        -- builder is shared with the native UI and other crafting addons.
        local candidates = batch.entries
        batch.entries = {}
        poc.ownDeconstruction = true
        PrepareDeconstructMessage()
        for _, pending in ipairs(candidates) do
            local item = pending.item
            local same = countAt(item.bag, item.slot, item.link) == item.stack
                and Id64ToString(GetItemUniqueId(item.bag, item.slot)) == item.uniqueId
            if same and not IsItemPlayerLocked(item.bag, item.slot) and not IsItemInArmory(item.bag, item.slot)
                and CanItemBeDeconstructed(item.bag, item.slot, craft ~= CRAFTING_TYPE_INVALID and craft or nil) then
                if not AddItemToDeconstructMessage(item.bag, item.slot, pending.quantity) then break end
                pending.started = GetFrameTimeMilliseconds()
                batch.entries[#batch.entries + 1] = pending
            end
        end
        local sent = false
        if #batch.entries > 0 then
            poc.saved.batch = batch
            sent = SendDeconstructMessage()
        end
        poc.ownDeconstruction = false
        if not sent then
            for _, pending in ipairs(batch.entries) do finish(pending, 'uncertain') end
            poc.saved.batch = nil
            return false
        end
    end
    return true
end

---@param item InventoryPocItem
---@param bags number[]
---@return number|nil, number|nil, number|nil, number|nil
local function destination(item, bags)
    for _, bag in ipairs(bags) do
        for slot = 0, GetBagSize(bag) - 1 do
            if GetItemLink(bag, slot, LINK_STYLE_DEFAULT) == item.link then
                local count, maxStack = GetSlotStackSize(bag, slot)
                if count < maxStack then return bag, slot, count, maxStack - count end
            end
        end
    end
    for _, bag in ipairs(bags) do
        local slot = FindFirstEmptySlotInBag(bag)
        if slot ~= nil then return bag, slot, 0, item.maxStack end
    end
end

---@return number[]
local function bankBags()
    return IsESOPlusSubscriber() and { BAG_BANK, BAG_SUBSCRIBER_BANK } or { BAG_BANK }
end

---@param pending InventoryPocPending
local function reconcile(pending)
    if pending.conflicted then finish(pending, 'uncertain'); return end
    -- A bank closing does not turn its unloaded slots into proof of a transfer.
    if pending.toBag and not accountBankOpen() then
        if GetFrameTimeMilliseconds() - pending.started > 5000 then finish(pending, 'uncertain') end
        return
    end
    local count = countAt(pending.item.bag, pending.item.slot, pending.item.link)
    local consumed = count == pending.item.stack - pending.quantity
    consumed = consumed and countBag(pending.item.bag, pending.item.link) == pending.sourceTotal - pending.quantity
    local proven = false
    if consumed then
        if pending.action == 'bank' then
            proven = countAt(pending.toBag, pending.toSlot, pending.item.link) == pending.toCount + pending.quantity
                and countBag(pending.toBag, pending.item.link) == pending.destinationTotal + pending.quantity
        elseif pending.action == 'list' then
            proven = pending.receipt == true
        elseif pending.action == 'learn' then
            -- Knowledge is stronger evidence than a UseItem call or slot delta.
            if pending.item.kind == 'collectible' or pending.item.kind == 'fragment' then
                local known, progress = facts.collectibleKnowledge(pending.item.link)
                if pending.item.learnProgress then
                    proven = progress == pending.item.learnProgress + pending.quantity
                else
                    proven = known == true
                end
            elseif pending.item.kind == 'motif' then
                proven = IsItemLinkBookKnown(pending.item.link)
            else
                proven = IsItemLinkRecipeKnown(pending.item.link)
            end
        elseif pending.action == 'destroy' or pending.action == 'open' then
            proven = true
        end
    end
    if proven then finish(pending, 'done')
    elseif GetFrameTimeMilliseconds() - pending.started > (pending.action == 'list' and 15000 or 5000) then finish(pending, 'uncertain') end
end

---@param item InventoryPocItem
---@param quote InventoryPocQuote
---@param guildId number
---@param reserved table<string, boolean>
---@return boolean
function poc.post(item, quote, guildId, reserved)
    if not poc.enabled or not poc.saved or poc.saved.pending or poc.saved.batch or poc.blocked[itemKey(item)] then return false end
    if GetInteractionType() ~= INTERACTION_TRADINGHOUSE or GetSelectedTradingHouseGuildId() ~= guildId then return false end
    if not BattleScrolls.inventoryPocMarket.canRequest() then return false end
    local current = facts.item(item.bag, item.slot, reserved)
    if not policy.sameItem(item, current) or current.reserved or not IsItemSellableOnTradingHouse(item.bag, item.slot) then return false end
    current.marketUnit = quote.unitPrice
    local decision = policy.decide(current)
    if decision.action ~= 'list' then return false end
    local quantity = policy.listingQuantity(current)
    if quantity == 0 or quote.quantity ~= quantity or quote.totalPrice ~= math.floor(quote.unitPrice * quantity) then return false end
    local used, capacity = GetTradingHouseListingCounts()
    local fee = GetTradingHousePostPriceInfo(quote.totalPrice)
    if used >= capacity or quote.totalPrice < policy.MIN_LISTING or quote.totalPrice > 2147483647
        or fee > GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) then return false end
    poc.saved.pending = { item = current, action = 'list', quantity = quantity, started = GetFrameTimeMilliseconds(),
        character = GetUnitName('player'), sourceTotal = countBag(item.bag, item.link), guildId = guildId,
        askingPrice = quote.totalPrice, fee = fee, reason = decision.reason, discount = quote.discount }
    RequestPostItemOnTradingHouse(item.bag, item.slot, quantity, quote.totalPrice)
    return true
end

---Recheck matching stacks immediately before a fragment withdrawal. Unrelated
---slots were already scanned for the current pass; inventory changes cancel it.
---@param item InventoryPocItem
---@param items InventoryPocItem[]
---@param reserved table<string, boolean>
---@return number
local function availableCount(item, items, reserved)
    local count = 0
    for _, candidate in ipairs(items) do
        if candidate.link == item.link then
            local current = facts.item(candidate.bag, candidate.slot, reserved)
            if current and current.link == item.link and not current.reserved and not current.stolen and not current.crown then
                count = count + current.stack
            end
        end
    end
    return count
end

---@param item InventoryPocItem
---@param action InventoryPocAction
---@param reserved table<string, boolean>
---@param quantity number|nil
---@param toBackpack boolean|nil
---@return boolean
local function start(item, action, reserved, quantity, toBackpack)
    if not poc.saved or poc.saved.pending or poc.saved.batch or poc.blocked[itemKey(item)] then return false end
    if action == 'bank' and manualBankItems[item.link] then return false end
    local current = facts.item(item.bag, item.slot, reserved)
    if not policy.sameItem(item, current) or current.reserved then return false end
    local decision = policy.decide(current)
    if action ~= 'bank' and decision.action ~= action then return false end
    if action == 'bank' and not current.filledSoulGem then
        local withdraw = decision.action == 'learn' or decision.action == 'list' or decision.action == 'sell' or decision.action == 'destroy'
        if toBackpack and current.kind == 'fragment' and current.known == false then
            if not workPass or not workPass.bank then return false end
            local carried = availableCount(current, workPass.backpack, reserved)
            local banked = availableCount(current, workPass.bank, reserved)
            local needed = policy.withdrawQuantity(current, carried, banked)
            if needed == 0 then return false end
            quantity, withdraw = math.min(quantity or current.stack, needed), true
        end
        if (toBackpack and not withdraw) or (not toBackpack and decision.action ~= 'bank') then return false end
    end
    local pending = { item = current, action = action, quantity = quantity or item.stack, reason = decision.reason,
        started = GetFrameTimeMilliseconds(), character = GetUnitName('player'), sourceTotal = countBag(item.bag, item.link) }
    if action == 'bank' then
        if not accountBankOpen() then return false end
        local bag, slot, count, room = destination(item, toBackpack and { BAG_BACKPACK } or bankBags())
        if not bag then return false end
        pending.toBag, pending.toSlot, pending.toCount = bag, slot, count
        pending.destinationTotal = countBag(bag, item.link)
        pending.quantity = math.min(pending.quantity, room)
    elseif action == 'learn' or action == 'open' then
        if GetInteractionType() ~= INTERACTION_NONE or IsPlayerMoving() or not current.usable then return false end
        if action == 'open' and GetNumBagFreeSlots(BAG_BACKPACK) == 0 then return false end
        -- Lazy Writ Crafter checks the shared slot cooldown as well as leaving
        -- time for server completion. IsItemUsable alone does not cover either.
        local now = GetFrameTimeMilliseconds()
        local remaining = math.max(GetSlotCooldownInfo(1), GetItemCooldownInfo(item.bag, item.slot), (poc.nextUseAt or 0) - now)
        if remaining > 0 then
            local retryAt = now + remaining + 300
            poc.useRetryAt = math.min(poc.useRetryAt or retryAt, retryAt)
            return false
        end
        pending.quantity = action == 'learn' and (current.learnQuantity or 1) or 1
    elseif action == 'destroy' then
        if GetInteractionType() ~= INTERACTION_NONE then return false end
    else
        return false
    end
    poc.saved.pending = pending
    if action == 'bank' then
        CallSecureProtected('RequestMoveItem', item.bag, item.slot, pending.toBag, pending.toSlot, pending.quantity)
    elseif action == 'learn' or action == 'open' then
        poc.nextUseAt = GetFrameTimeMilliseconds() + 1000 + GetLatency()
        CallSecureProtected('UseItem', item.bag, item.slot)
    elseif action == 'destroy' then
        DestroyItem(item.bag, item.slot)
    end
    return true
end

---Build gear may be locked. Only the build module's current exact-ID transfer
---plan can bypass the cleanup reservation check, and only between pack/bank.
---@param item InventoryPocItem
---@param toBackpack boolean
---@return boolean
function poc.moveBuildItem(item, toBackpack)
    if not poc.enabled or not poc.saved or poc.saved.pending or poc.saved.batch or not accountBankOpen()
        or poc.blocked[itemKey(item)] or manualBankItems[item.link] or IsUnitInCombat('player') then return false end
    if not BattleScrolls.inventoryPocBuilds.canMove(item, toBackpack) then return false end
    local current = facts.item(item.bag, item.slot)
    if not policy.sameItem(item, current) or item.stack ~= 1 then return false end
    local bag, slot, count = destination(item, toBackpack and { BAG_BACKPACK } or bankBags())
    if not bag then return false end
    poc.saved.pending = { item = current, action = 'bank', quantity = 1, reason = 'reserved', started = GetFrameTimeMilliseconds(),
        character = GetUnitName('player'), sourceTotal = countBag(item.bag, item.link),
        toBag = bag, toSlot = slot, toCount = count, destinationTotal = countBag(bag, item.link) }
    CallSecureProtected('RequestMoveItem', item.bag, item.slot, bag, slot, 1)
    return true
end

---@param pass InventoryPocPass
---@return boolean
local function bankWork(pass)
    local backpack, reserved = pass.backpack, pass.reserved
    if not pass.bank then
        pass.bank = {}
        for _, bag in ipairs(bankBags()) do
            for _, item in ipairs(facts.bag(bag, reserved)) do pass.bank[#pass.bank + 1] = item end
        end
    end
    local bank = pass.bank
    local packGems, bankGems = 0, 0
    for _, item in ipairs(backpack) do
        if item.filledSoulGem and not item.crown and not item.reserved then packGems = packGems + item.stack end
    end
    for _, item in ipairs(bank) do
        if item.filledSoulGem and not item.crown and not item.reserved then bankGems = bankGems + item.stack end
    end
    local transfer = policy.soulGemTransfer(packGems, bankGems)
    local source = transfer > 0 and backpack or bank
    if transfer ~= 0 then
        for _, item in ipairs(source) do
            if item.filledSoulGem and not item.crown and not item.reserved then
                if start(item, 'bank', reserved, math.min(math.abs(transfer), item.stack), transfer < 0) then return true end
            end
        end
    end
    -- Rules are evaluated for this character, including crafter-only learning.
    -- Carry one use of unknown items; withdraw full stacks for disposal/trading.
    local carried, banked = {}, {}
    for _, item in ipairs(backpack) do
        if not item.reserved and not item.stolen and not item.crown then
            carried[item.link] = (carried[item.link] or 0) + item.stack
        end
    end
    for _, item in ipairs(bank) do
        if not item.reserved and not item.stolen and not item.crown then
            banked[item.link] = (banked[item.link] or 0) + item.stack
        end
    end
    for _, item in ipairs(bank) do
        local quantity = policy.withdrawQuantity(item, carried[item.link] or 0, banked[item.link] or 0)
        if quantity > 0 then
            if start(item, 'bank', reserved, quantity, true) then return true end
        end
    end
    return false
end

local function step()
    if not poc.enabled or not poc.saved then return end
    if poc.saved.batch then reconcileBatch(poc.saved.batch); if poc.saved.batch then return end end
    if poc.saved.pending then reconcile(poc.saved.pending); if poc.saved.pending then return end end
    if next(BattleScrolls.inventoryPocReturns.claims) then BattleScrolls.inventoryPocReturns.sync(); return end
    local builds = BattleScrolls.inventoryPocBuilds
    local building = builds.request and builds.step({})
    -- WW can still be waiting on a skill, CP or food while a merchant is open.
    -- Allow vendor sales after fresh reservations, but leave transfers and uses
    -- until the build finishes so they cannot fight WW for equipment or food.
    if building and (builds.request.kind ~= 'wardrobe' or GetInteractionType() ~= INTERACTION_VENDOR) then return end
    if not poc.dirty or IsUnitInCombat('player') or IsUnitDead('player') or IsLooting() then return end
    if not workPass then
        BattleScrolls.inventoryPocReturns.sync()
        local _, reserved = facts.wardrobe(true)
        local backpack = facts.bag(BAG_BACKPACK, reserved)
        BattleScrolls.inventoryPocCompanions.refresh(backpack)
        workPass = { reserved = reserved, backpack = backpack }
    end
    local backpack, reserved = workPass.backpack, workPass.reserved
    if not building and builds.step(reserved, workPass) then return end
    if GetInteractionType() == INTERACTION_TRADINGHOUSE then
        poc.dirty = BattleScrolls.inventoryPocMarket.step(backpack, reserved)
        if not poc.dirty then workPass = nil end
        return
    end
    if not building and accountBankOpen() and bankWork(workPass) then return end
    if GetInteractionType() == INTERACTION_VENDOR then
        if startBatch('sell', backpack, reserved, building) then return end
    elseif poc.craftOpen and not building then
        local items = {}
        for _, item in ipairs(backpack) do items[#items + 1] = item end
        for _, bag in ipairs(bankBags()) do
            for _, item in ipairs(facts.bag(bag, reserved)) do items[#items + 1] = item end
        end
        if startBatch('deconstruct', items, reserved) then return end
    end
    for _, item in ipairs(backpack) do
        local decision = policy.decide(item)
        if not building and decision.action == 'defer' then defer(item, decision)
        elseif not building and (decision.action == 'bank' or decision.action == 'learn'
            or decision.action == 'open' or decision.action == 'destroy') then
            if start(item, decision.action, reserved) then return end
        end
    end
    poc.dirty = false
    workPass = nil
end

function poc.wake()
    if not poc.enabled then return end
    if workFiber then workFiber:Cancel(); workFiber = nil end
    workPass = nil
    poc.dirty = true
    resumeWork()
end

---A response changes queue progress, not the contents of the inventory scan.
function poc.resume()
    if not poc.enabled then return end
    poc.dirty = true
    resumeWork()
end

---@return boolean
local function needsWork()
    if not poc.enabled or not poc.saved then return false end
    if poc.saved.pending or poc.saved.batch or next(BattleScrolls.inventoryPocReturns.claims) then return true end
    if IsUnitInCombat('player') or IsUnitDead('player') or IsLooting() then return false end
    if BattleScrolls.inventoryPocBuilds.request then return true end
    if not poc.dirty then return false end
    if GetInteractionType() == INTERACTION_TRADINGHOUSE then
        -- Read native readiness without rescanning bags or allocating fibers.
        if BattleScrolls.inventoryPocMarket.isWaiting() then return false end
    end
    return true
end

local workEffect = LibEffect.Async(step):Ensure(function()
    workFiber = nil
    BattleScrolls.gc:RequestGC(2)
    setUpdateInterval(followupRequested and 0 or (needsWork() and WORK_INTERVAL_MS or IDLE_INTERVAL_MS))
end)

update = function()
    if not poc.enabled then return end
    -- No effects, tables or bag reads on idle ticks. Movement and arbitrary
    -- interaction changes have no single event covering all supported windows.
    local interaction, moving = GetInteractionType(), IsPlayerMoving()
    local changed = interaction ~= poc.lastInteraction or moving ~= poc.lastMoving
    poc.lastInteraction, poc.lastMoving = interaction, moving
    local now = GetFrameTimeMilliseconds()
    if poc.externalSaleUntil and now >= poc.externalSaleUntil then poc.externalSaleUntil, changed = nil, true end
    if poc.useRetryAt and now >= poc.useRetryAt then poc.useRetryAt, changed = nil, true end
    if facts.pricesChanged() then changed = true end
    if changed then poc.wake() end
    if workFiber then return end
    if not needsWork() then setUpdateInterval(IDLE_INTERVAL_MS); return end
    followupRequested = false
    workFiber = workEffect:Run()
end

local function newVisit()
    poc.blocked, poc.notices = {}, {}
    manualBankItems = {}
    poc.wake()
end

---@param pending InventoryPocPending
---@param bag number
---@param slot number
---@return boolean
local function expectedUpdate(pending, bag, slot)
    if bag == pending.item.bag and slot == pending.item.slot then
        local link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
        return (link == '' or link == pending.item.link)
            and countAt(bag, slot, pending.item.link) == pending.item.stack - pending.quantity
    end
    return pending.toBag ~= nil and bag == pending.toBag and slot == pending.toSlot
        and countAt(bag, slot, pending.item.link) == pending.toCount + pending.quantity
end

local function abandonBatch()
    if not poc.saved or not poc.saved.batch then return end
    for _, pending in ipairs(poc.saved.batch.entries) do finish(pending, 'uncertain') end
    poc.saved.batch = nil
end

---@param lines string[]
local function printProbe(lines)
    EVENT_MANAGER:UnregisterForUpdate(PROBE_EVENT_NAME)
    local index = 1
    EVENT_MANAGER:RegisterForUpdate(PROBE_EVENT_NAME, 100, function()
        if not poc.enabled then EVENT_MANAGER:UnregisterForUpdate(PROBE_EVENT_NAME); return end
        for _ = 1, PROBE_BATCH_SIZE do
            if not lines[index] then EVENT_MANAGER:UnregisterForUpdate(PROBE_EVENT_NAME); return end
            d(lines[index])
            index = index + 1
        end
        if index > #lines then EVENT_MANAGER:UnregisterForUpdate(PROBE_EVENT_NAME) end
    end)
end

---@param report InventoryPocSnapshot
---@param section string|nil
local function finishProbe(report, section)
    local reports = poc.saved.reports
    reports[#reports + 1] = report
    while #reports > 2 do table.remove(reports, 1) end
    if report.companionId > 0 then poc.saved.companions[report.companionId] = report.companionGear end
    local lines = { zo_strformat(GetString(BATTLESCROLLS_IPOC_CAPTURED), report.character, #report.items, #report.armory, #report.wardrobe) }
    local function add(line) lines[#lines + 1] = line end
    -- Machine-readable field labels below are a diagnostic protocol, not UI copy.
    add(string.format('IPOC world=%s api=%d guild=%s companion=%d:%s', report.world, report.api,
        tostring(report.guildId), report.companionId, report.companionName))
    if section == 'items' or section == 'unassigned' then
        for _, item in ipairs(report.items) do
            local decision = policy.decide(item)
            if section ~= 'unassigned' or decision.reason == 'unassigned' then
                add(string.format('IPOC item=%d slot=%d kind=%s q=%d trait=%d style=%d market=%s action=%s reason=%s %s',
                    item.itemId, item.slot, item.kind, item.quality, item.trait, item.style,
                    tostring(item.marketUnit), decision.action, decision.reason, item.link))
            end
        end
    elseif section == 'companion' then
        for _, item in ipairs(report.companionGear) do
            add(string.format('IPOC slot=%d q=%d trait=%d weapon=%d armor=%d %s', item.slot, item.quality,
                item.trait, item.weaponType, item.armorType, item.link))
        end
    elseif section == 'addons' then
        for _, addon in ipairs(report.addons) do add(string.format('IPOC addon=%s v=%d', addon.name, addon.version)) end
    else
        for _, build in ipairs(report.armory) do
            add(string.format('IPOC armory=%d %s', build.index, build.name))
            if section == 'armory' then
                for _, gear in ipairs(build.gear) do
                    add(string.format('IPOC equip=%d state=%d bag=%d slot=%d id=%s', gear.equipSlot,
                        gear.state, gear.bag, gear.slot, tostring(gear.uniqueId)))
                end
            end
        end
        for _, setup in ipairs(report.wardrobe) do
            add(string.format('IPOC ww=%s/%d/%d %s / %s gear=%d', setup.zone, setup.page, setup.index,
                setup.pageName, setup.name, #setup.gear))
        end
    end
    printProbe(lines)
end

---Explicit diagnostic entry point; snapshots never mutate game inventory.
---Both the backpack scan and chat output yield after five slots/lines.
---@param section string|nil
function poc.probe(section)
    if not poc.enabled or not poc.saved then return end
    cancelProbe()
    probeFiber = LibEffect.Async(function()
        local report, reserved = facts.snapshot({})
        report.items = facts.bag(BAG_BACKPACK, reserved)
        finishProbe(report, section)
    end):Ensure(function() probeFiber = nil; BattleScrolls.gc:RequestGC(2) end):Run()
end

---Read exactly the selected item; no full scan, native dialog or item action.
---@param bag number
---@param slot number
function poc.inspectItem(bag, slot)
    if not poc.enabled or not poc.saved then return end
    cancelProbe()
    -- Capture the selected instance before yielding; the slot may change while
    -- Wardrobe reservations are being read.
    local item = facts.item(bag, slot)
    if not item then return end
    probeFiber = LibEffect.Async(function()
        local _, reserved = facts.wardrobe(true)
        item.reserved = item.reserved or reserved[item.uniqueId] == true
        local itemType, specializedType = GetItemLinkItemType(item.link)
        local _, _, _, _, _, setId = GetItemLinkSetInfo(item.link, false)
        local decision = policy.decide(item)
        local styleMaterial = item.styleMaterialLink ~= '' and GetItemLinkItemId(item.styleMaterialLink) or 0
        local traitMaterial = item.traitMaterialLink ~= '' and GetItemLinkItemId(item.traitMaterialLink) or 0
        local lines = {
            'IPOC ' .. item.link,
            string.format('IPOC item=%d bag=%d slot=%d count=%d type=%d sub=%d',
                item.itemId, bag, slot, item.stack, itemType, specializedType),
            string.format('IPOC kind=%s q=%d trait=%d style=%d set=%d', item.kind, item.quality, item.trait, item.style, setId),
            string.format('IPOC actor=%d equip=%d armor=%d weapon=%d level=%d cp=%d',
                item.actorCategory, item.equipType, item.armorType, item.weaponType, item.level, item.championPoints),
            string.format('IPOC action=%s reason=%s vendor=%s market=%s',
                decision.action, decision.reason, tostring(item.vendorUnit), tostring(item.marketUnit)),
            string.format('IPOC reserved=%s stolen=%s crown=%s known=%s crafterKnown=%s',
                tostring(item.reserved), tostring(item.stolen), tostring(item.crown), tostring(item.known), tostring(item.crafterKnown)),
            string.format('IPOC styleMat=%d price=%s traitMat=%d price=%s resolved=%s', styleMaterial,
                tostring(item.styleMaterialUnit), traitMaterial, tostring(item.traitMaterialUnit), tostring(item.traitMaterialResolved)),
        }
        local flavor = GetItemLinkFlavorText(item.link)
        if flavor ~= '' then lines[#lines + 1] = 'IPOC flavor=' .. flavor end
        printProbe(lines)
    end):Ensure(function() probeFiber = nil; BattleScrolls.gc:RequestGC(2) end):Run()
end

function poc.disable()
    startupCancelled = true
    cancelStart()
    cancelProbe()
    if BattleScrolls.antiquityLeads then BattleScrolls.antiquityLeads.stop() end
    if workFiber then workFiber:Cancel(); workFiber = nil end
    workPass = nil
    if not poc.saved then return end
    BattleScrolls.inventoryPocBuilds.stop()
    poc.saved.enabled = false
    poc.enabled = false
    BattleScrolls.inventoryPocMarket.stop()
    BattleScrolls.inventoryPocCompanions.reset()
    BattleScrolls.inventoryPocReturns.reset()
    if poc.saved.pending then finish(poc.saved.pending, 'uncertain') end
    abandonBatch()
    EVENT_MANAGER:UnregisterForUpdate(EVENT_NAME)
    updateInterval = nil
    BattleScrolls.inventoryPocUI.setEnabled(false)
    d(GetString(BATTLESCROLLS_IPOC_DISABLED))
end

function poc.enable()
    if not ACCOUNTS[GetDisplayName()] or not poc.saved or poc.enabled then return end
    startupCancelled = false
    cancelStart()
    poc.saved.enabled = true
    poc.enabled = true
    if not poc.registered then
        poc.registered = true
        local function otherSale()
            if not poc.enabled or poc.ownVendorSale then return end
            poc.externalSaleUntil = GetFrameTimeMilliseconds() + 5000
            local batch = poc.saved.batch
            if batch and batch.action == 'sell' then
                for _, entry in ipairs(batch.entries) do entry.conflicted = true end
            end
            poc.wake()
        end
        ZO_PreHook('SellInventoryItem', otherSale)
        ZO_PreHook('SellAllJunk', otherSale)
        ZO_PreHook('PrepareDeconstructMessage', function()
            if not poc.enabled or poc.ownDeconstruction then return end
            local batch = poc.saved.batch
            if batch and batch.action == 'deconstruct' then
                for _, entry in ipairs(batch.entries) do entry.conflicted = true end
            end
            poc.wake()
        end)
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function(_event, bag, slot, _isNew, _sound, reason)
            if reason == INVENTORY_UPDATE_REASON_DURABILITY_CHANGE or reason == INVENTORY_UPDATE_REASON_ITEM_CHARGE
                or reason == INVENTORY_UPDATE_REASON_DYE_CHANGE then return end
            if poc.enabled and poc.saved and (reason == INVENTORY_UPDATE_REASON_DEFAULT or reason == nil) then
                local pending, batch = poc.saved.pending, poc.saved.batch
                if pending and expectedUpdate(pending, bag, slot) then resumeWork(); return end
                if batch then
                    for _, entry in ipairs(batch.entries) do
                        if expectedUpdate(entry, bag, slot) then resumeWork(); return end
                    end
                end
            end
            poc.wake()
        end)
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_INVENTORY_FULL_UPDATE, poc.wake)
        -- Native bank actions (including gamepad and partial-stack transfers)
        -- pick up the source before placing it. Observe that event rather than
        -- wrapping protected functions or changing native dialog callbacks.
        -- Our RequestMoveItem calls do not use the cursor.
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_CURSOR_PICKUP, function(_, cursorType, bag, slot)
            if not poc.enabled or cursorType ~= MOUSE_CONTENT_INVENTORY_ITEM or not accountBankOpen() then return end
            if bag ~= BAG_BACKPACK and bag ~= BAG_BANK and bag ~= BAG_SUBSCRIBER_BANK then return end
            local link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
            if link == '' then return end
            manualBankItems[link] = true
            poc.wake()
        end)
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_PLAYER_ACTIVATED, newVisit)
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_OPEN_BANK, newVisit)
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_OPEN_STORE, function()
            if not poc.enabled then return end
            for index = 1, GetNumStoreItems() do
                local _, _, _, _, _, _, _, _, _, currency1, _, currency2 = GetStoreEntryInfo(index)
                local link = GetStoreItemLink(index, LINK_STYLE_DEFAULT)
                if (currency1 == CURT_ALLIANCE_POINTS or currency2 == CURT_ALLIANCE_POINTS) and GetItemLinkItemType(link) == ITEMTYPE_POTION then
                    poc.saved.apPotions[GetItemLinkItemId(link)] = true
                end
            end
            newVisit()
        end)
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_CLOSE_BANK, function()
            manualBankItems = {}
            poc.wake()
        end)
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_CLOSE_STORE, poc.wake)
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_PLAYER_COMBAT_STATE, poc.wake)
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_PLAYER_ALIVE, poc.wake)
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_PLAYER_DEAD, poc.wake)
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_PLAYER_REINCARNATED, poc.wake)
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_LOOT_CLOSED, poc.wake)
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_LOOT_UPDATED, function()
            local pending = poc.enabled and poc.saved and poc.saved.pending
            if not pending or pending.action ~= 'open' or GetFrameTimeMilliseconds() - pending.started > 1500 then return end
            local name, targetType = GetLootTargetInfo()
            if targetType == INTERACT_TARGET_TYPE_ITEM and zo_strformat(SI_TOOLTIP_ITEM_NAME, name) == pending.item.name then
                LootAll(false)
            end
        end)
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_CRAFTING_STATION_INTERACT, function()
            poc.craftOpen = true; newVisit()
        end)
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_END_CRAFTING_STATION_INTERACT, function()
            poc.craftOpen = false; poc.wake()
        end)
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_CRAFT_COMPLETED, function()
            local batch = poc.saved and poc.saved.batch
            if batch and batch.action == 'deconstruct' then
                for _, entry in ipairs(batch.entries) do entry.receipt = true end
                resumeWork()
            else
                poc.wake()
            end
        end)
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_SELL_RECEIPT, function(_, itemLink, quantity, gold)
            local batch = poc.saved and poc.saved.batch
            if batch and batch.action == 'sell' then
                -- The API calls this argument itemName, but sends an item link.
                -- Compare its data, not the visible name or link presentation
                -- (receipt links may have brackets, display text and color).
                local data = itemLink:match('|H%d+:(item:[^|]+)|h')
                for _, entry in ipairs(batch.entries) do
                    if data and not entry.receipt and quantity == entry.quantity
                        and data == entry.item.link:match('|H%d+:(item:[^|]+)|h') then
                        entry.receipt, entry.gold = true, gold
                        break
                    end
                end
            end
            resumeWork()
        end)
        EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_COMPANION_ACTIVATED, poc.wake)
    end
    BattleScrolls.inventoryPocReturns.initialize()
    BattleScrolls.inventoryPocMarket.initialize()
    BattleScrolls.inventoryPocBuilds.initialize()
    BattleScrolls.inventoryPocUI.setEnabled(true)
    newVisit()
    -- Activation may precede the helper's delayed startup. Start the reminder
    -- here as well so that enabling after login does not miss that activation.
    if IsPlayerActivated() and BattleScrolls.antiquityLeads then BattleScrolls.antiquityLeads.report() end
    d(GetString(BATTLESCROLLS_IPOC_ENABLED))
end

---@param entry InventoryPocLogEntry
---@return string
function poc.formatLog(entry)
    if entry.buildName then
        local id = entry.result == 'uncertain' and BATTLESCROLLS_IPOC_BUILD_INTERRUPTED
            or (entry.setupName and BATTLESCROLLS_IPOC_BUILD_READY or BATTLESCROLLS_IPOC_ARMORY_RESTORED)
        return zo_strformat(GetString(id), entry.buildName, entry.setupName or '')
    end
    if entry.result == 'uncertain' then
        return zo_strformat(GetString(BATTLESCROLLS_IPOC_UNCERTAIN), entry.quantity, entry.itemLink)
    end
    if entry.result == 'deferred' then
        local ids = { price = BATTLESCROLLS_IPOC_WAIT_PRICE, knowledge = BATTLESCROLLS_IPOC_WAIT_KNOWLEDGE,
            companion = BATTLESCROLLS_IPOC_WAIT_COMPANION }
        return zo_strformat(GetString(ids[entry.reason]), entry.itemLink)
    end
    if entry.action == 'bank' then
        local bag = entry.toBag == BAG_SUBSCRIBER_BANK and BAG_BANK or entry.toBag
        return zo_strformat(GetString(BATTLESCROLLS_IPOC_MOVED), entry.quantity, entry.itemLink, GetString('SI_BAG', bag))
    end
    if entry.action == 'learn' then return zo_strformat(GetString(BATTLESCROLLS_IPOC_LEARNED), entry.itemLink) end
    if entry.action == 'open' then return zo_strformat(GetString(BATTLESCROLLS_IPOC_OPENED), entry.itemLink, entry.itemId) end
    if entry.action == 'list' then
        return zo_strformat(GetString(BATTLESCROLLS_IPOC_LISTED), entry.quantity, entry.itemLink,
            entry.askingPrice, GetGuildName(entry.guildId), entry.fee)
    end
    local ids = { sell = BATTLESCROLLS_IPOC_SOLD, deconstruct = BATTLESCROLLS_IPOC_DECONSTRUCTED, destroy = BATTLESCROLLS_IPOC_DESTROYED }
    return zo_strformat(GetString(ids[entry.action]), entry.quantity, entry.itemLink, entry.gold or 0)
end

---@param count number|nil
function poc.log(count)
    if not poc.saved then return end
    local log = poc.saved.log
    for index = math.max(1, #log - (count or 10) + 1), #log do
        d(poc.formatLog(log[index]))
    end
end

local function scheduleStart()
    cancelStart()
    -- UI construction and inventory scans also stay out of PLAYER_ACTIVATED.
    startFiber = LibEffect.Async(function()
        BattleScrolls.startup.playerActivated:Await()
        LibEffect.Sleep(START_DELAY_MS):Await()
        startFiber = nil -- enable() must not cancel the fiber currently calling it.
        if not startupCancelled and poc.saved and poc.saved.enabled and not poc.enabled then poc.enable() end
    end):Ensure(function() startFiber = nil end):Run()
end

local function initialize()
    local root = rawget(_G, 'BattleScrollsInventoryPocSavedVariables') ---@type InventoryPocSavedRoot|nil
    if not root then
        root = { accounts = {} }
        BattleScrollsInventoryPocSavedVariables = root
    end
    local account = GetDisplayName()
    root.accounts[account] = root.accounts[account] or {}
    local worlds = root.accounts[account]
    local world = GetWorldName()
    worlds[world] = worlds[world] or { enabled = false, log = {}, reports = {}, companions = {}, apPotions = {}, builds = {},
        returns = { stock = {}, discounted = {} } }
    poc.saved = worlds[world]
    poc.saved.builds = poc.saved.builds or {}
    poc.saved.returns = poc.saved.returns or { stock = {}, discounted = {} }
    if startupCancelled then poc.saved.enabled = false end
    -- An interrupted request cannot be declared successful or blindly retried
    -- using bags that have not loaded yet. Preserve it as an uncertain record.
    if poc.saved.pending then finish(poc.saved.pending, 'uncertain') end
    abandonBatch()
    if poc.saved.enabled then scheduleStart() end
end

if ACCOUNTS[GetDisplayName()] then
    LibEffect.Async(function()
        BattleScrolls.startup.addonLoaded:Await()
        LibEffect.Sleep(INITIALIZE_DELAY_MS):Await()
        initialize()
    end):Run()
end
