if not SemisPlaygroundCheckAccess() then return end

---@class InventoryPocReturnsSaved
---@field stock table<string, table<string, number>>
---@field discounted table<string, boolean>
---@class InventoryPocReturnMail
---@field items table<string, number>
---@class InventoryPocReturnClaim: InventoryPocReturnMail
---@field before table<string, number>
---@field started number
---@field success boolean
---@class InventoryPocReturns
---@field registered boolean
---@field claims table<string, InventoryPocReturnClaim>
---@field syncFiber Fiber<nil>|nil
local returns = { registered = false, claims = {} }
BattleScrolls.inventoryPocReturns = returns
local poc = BattleScrolls.inventoryPoc
local facts = BattleScrolls.inventoryPocFacts
local EVENT_NAME = 'BattleScrollsInventoryPocReturns'
local revision = 0

---@return boolean
local function bankAccessible()
    return IsBankOpen() and (GetBankingBag() == BAG_BANK or GetBankingBag() == BAG_SUBSCRIBER_BANK)
end

---@param bag number
---@return string
local function location(bag)
    if bag == BAG_BACKPACK then return 'character:' .. GetCurrentCharacterId() end
    if bag == BAG_WORN then return 'character:' .. GetCurrentCharacterId() .. ':worn' end
    if bag == BAG_COMPANION_WORN then return 'companion:' .. tostring(GetActiveCompanionDefId()) end
    return 'bag:' .. tostring(bag)
end

---@param bag number
---@param checkpoint (fun(): boolean)|nil Mail claims capture their baseline synchronously
---@return table<string, number>|nil
local function counts(bag, checkpoint)
    local result = {}
    for slot = 0, GetBagSize(bag) - 1 do
        local link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
        if link ~= '' then
            local key = facts.variantKey(facts.variant(link))
            local quantity = GetSlotStackSize(bag, slot)
            result[key] = (result[key] or 0) + quantity
        end
        if checkpoint and (slot + 1) % 5 == 0 and not checkpoint() then return nil end
    end
    return result
end

---@param item InventoryPocItem
---@return boolean
function returns.isDiscounted(item)
    return poc.enabled and poc.saved ~= nil and poc.saved.returns.discounted[facts.variantKey(item)] == true
end

---@return boolean completed
local function syncPass()
    local state = poc.saved.returns
    local version, character, companion = revision, GetCurrentCharacterId(), GetActiveCompanionDefId()
    local bank, subscriber, pending = bankAccessible(), IsESOPlusSubscriber(), poc.saved.pending
    local quoteRevision = facts.quoteRevision
    local function current()
        return poc.enabled and poc.saved and poc.saved.returns == state and version == revision
            and character == GetCurrentCharacterId() and companion == GetActiveCompanionDefId()
            and bank == bankAccessible() and subscriber == IsESOPlusSubscriber() and pending == poc.saved.pending
            and quoteRevision == facts.quoteRevision
    end
    local function checkpoint()
        LibEffect.Yield():Await()
        return current()
    end
    local stock, locations = {}, { [BAG_BACKPACK] = location(BAG_BACKPACK), [BAG_WORN] = location(BAG_WORN) }
    for name, quantities in pairs(state.stock) do stock[name] = quantities end
    if companion > 0 then locations[BAG_COMPANION_WORN] = location(BAG_COMPANION_WORN) end
    if bank then
        locations[BAG_BANK] = location(BAG_BANK)
        if subscriber then locations[BAG_SUBSCRIBER_BANK] = location(BAG_SUBSCRIBER_BANK) end
    end
    for bag, name in pairs(locations) do
        local quantities = counts(bag, checkpoint)
        if not quantities then return false end
        stock[name] = quantities
    end
    local processed = 0
    local function advance()
        processed = processed + 1
        return processed % 50 ~= 0 or checkpoint()
    end
    local owned = {}
    for _, quantities in pairs(stock) do
        for key, quantity in pairs(quantities) do
            if quantity > 0 then owned[key] = true end
            if not advance() then return false end
        end
    end
    if pending then owned[facts.variantKey(pending.item)] = true end
    if not current() then return false end
    -- Publish a complete ownership snapshot after every bag has been checked.
    state.stock = stock
    for key in pairs(state.discounted) do
        if not owned[key] then state.discounted[key] = nil end
        if not advance() then return false end
    end
    for key in pairs(facts.quotes) do
        if not owned[key] then facts.quotes[key] = nil end
        if not advance() then return false end
    end
    local pack = stock[locations[BAG_BACKPACK]]
    for id, claim in pairs(returns.claims) do
        local received = claim.success
        for key, quantity in pairs(claim.items) do
            if (pack[key] or 0) < (claim.before[key] or 0) + quantity then received = false; break end
        end
        if received then
            for key in pairs(claim.items) do state.discounted[key] = true end
            returns.claims[id] = nil
            poc.dirty = true
        elseif GetFrameTimeMilliseconds() - claim.started > 10000 then returns.claims[id] = nil end
        if not advance() then return false end
    end
    return true
end

---@param delayMs number
---@return Fiber<nil>
local function startSync(delayMs)
    returns.syncFiber = LibEffect.Async(function()
        if delayMs > 0 then LibEffect.Sleep(delayMs):Await() end
        while poc.enabled and poc.saved do
            if syncPass() then return end
        end
    end):Ensure(function() returns.syncFiber = nil end):Run()
    return returns.syncFiber
end

---An expiry reprices identical stock across known locations until it is gone.
---Restacking or moving between the backpack and bank preserves that signal.
---Run inside LibEffect.Async. Concurrent callers share the current scan.
function returns.sync()
    if not poc.enabled or not poc.saved then return end
    local fiber = returns.syncFiber or startSync(0)
    fiber:Await()
end

---Coalesce bag events, including manual changes after the service handoff.
function returns.requestSync()
    if not poc.enabled or not poc.saved then return end
    revision = revision + 1
    if not returns.syncFiber then startSync(100) end
end

---@param mailId id64
local function prepareClaim(mailId)
    if not poc.enabled or not poc.saved or not IsReadMailInfoReady(mailId) then return end
    local id = Id64ToString(mailId)
    if returns.claims[id] then return end
    local _, _, subject, _, _, fromSystem, fromCS, _, count, money, cod = GetMailItemInfo(mailId)
    -- Protocol text observed on this player's English Xbox client. These are
    -- server mail signatures, not UI copy. A returned flag alone is insufficient.
    if not fromSystem or fromCS or subject ~= 'Item Expired' or count < 1 or money ~= 0 or cod ~= 0 then return end
    local body = ReadMail(mailId)
    if not body:find('An item you listed has expired.', 1, true) or not body:find('Attached is the item.', 1, true) then return end
    local items = {}
    for index = 1, count do
        local link = GetAttachedItemLink(mailId, index, LINK_STYLE_DEFAULT)
        local _, quantity = GetAttachedItemInfo(mailId, index)
        if link == '' or not quantity or quantity <= 0 then return end
        local key = facts.variantKey(facts.variant(link))
        items[key] = (items[key] or 0) + quantity
    end
    local before = assert(counts(BAG_BACKPACK))
    returns.claims[id] = { items = items, before = before, started = GetFrameTimeMilliseconds(), success = false }
    returns.requestSync()
    poc.wake()
    BattleScrolls.gc:RequestGC(2)
end

function returns.initialize()
    if not poc.saved then return end
    poc.saved.returns = poc.saved.returns or { stock = {}, discounted = {} }
    if returns.registered then return end
    returns.registered = true
    -- Observe the existing claim flow. Do not read other mails in the background:
    -- the native gamepad mail UI displays whichever mail becomes readable.
    ZO_PreHook('TakeMailAttachments', prepareClaim)
    ZO_PreHook('TakeMailAttachedItems', prepareClaim)
    ZO_PreHook('TakeAllMailAttachmentsInCategory', function(category)
        if not poc.enabled then return end
        local mailId = GetNextMailId()
        while mailId do
            local _, _, _, _, _, _, _, _, _, _, _, _, _, mailCategory = GetMailItemInfo(mailId)
            if mailCategory == category then prepareClaim(mailId) end
            mailId = GetNextMailId(mailId)
        end
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_MAIL_TAKE_ATTACHED_ITEM_SUCCESS, function(_, mailId)
        local claim = poc.enabled and returns.claims[Id64ToString(mailId)]
        if claim then claim.success = true; returns.requestSync(); poc.wake() end
    end)
end

function returns.reset()
    revision = revision + 1
    if returns.syncFiber then returns.syncFiber:Cancel(); returns.syncFiber = nil end
    returns.claims = {}
end
