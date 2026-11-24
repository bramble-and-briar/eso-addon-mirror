if not SemisPlaygroundCheckAccess() then return end

---@class InventoryPocReturnsSaved
---@field stock table<string, table<string, number>>
---@field discounted table<string, boolean>
---@field relisted table<string, number> When a variant was last listed at half price
---@field unsold table<string, boolean> Variants that came back from a half-price listing too
---@class InventoryPocReturnMail
---@field items table<string, number>
---@class InventoryPocReturnClaim: InventoryPocReturnMail
---@field before table<string, number>
---@field started number
---@field success boolean
---@class InventoryPocMailInbox
---@field GetActiveMailId fun(self: InventoryPocMailInbox): id64|nil
---@field IsActiveMailFromGuild fun(self: InventoryPocMailInbox): boolean
---@class InventoryPocMailScreen
---@field GetInbox fun(self: InventoryPocMailScreen): InventoryPocMailInbox|nil
---@class InventoryPocReturns
---@field registered boolean
---@field claims table<string, InventoryPocReturnClaim>
---@field syncFiber Fiber<nil>|nil
local returns = { registered = false, claims = {} }
BattleScrolls.inventoryPocReturns = returns
local poc = BattleScrolls.inventoryPoc
local facts = BattleScrolls.inventoryPocFacts
local EVENT_NAME = 'BattleScrollsInventoryPocReturns'
-- A half-price listing sells or expires within the listing period, and its
-- mail is claimed some time after. Older records describe a listing that sold.
local RELISTED_MEMORY_SECONDS = 60 * 86400
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

---@param item InventoryPocItem
---@return boolean
function returns.isUnsold(item)
    return poc.enabled and poc.saved ~= nil and poc.saved.returns.unsold[facts.variantKey(item)] == true
end

---A half-price listing was posted. An expiry mail carries only the item, so
---like the discount this is kept per variant: the next expiry of identical
---stock counts as this listing coming back.
---@param item InventoryPocItem
function returns.relisted(item)
    if not poc.enabled or not poc.saved then return end
    poc.saved.returns.relisted[facts.variantKey(item)] = GetTimeStamp()
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
    for key in pairs(state.unsold) do
        if not owned[key] then state.unsold[key] = nil end
        if not advance() then return false end
    end
    -- A listed item is in no bag, so this record outlives its stock.
    local now = GetTimeStamp()
    for key, listedAt in pairs(state.relisted) do
        if now - listedAt > RELISTED_MEMORY_SECONDS then state.relisted[key] = nil end
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
            for key in pairs(claim.items) do
                if state.relisted[key] then state.unsold[key], state.relisted[key] = true, nil end
                state.discounted[key] = true
            end
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

---Subject of the server's expired-listing mail, which the client shows in its
---text language: game text row (191189508, 0, 1428) of each official .lang
---file, plus the Swedish overlay built from lang-overlay/sv.json (update it
---here if that translation changes). Community languages are not covered.
local EXPIRED_SUBJECTS = {
    ['Item Expired'] = true, -- en
    ['Angebot ausgelaufen'] = true, -- de
    ['Objet arrivé à expiration'] = true, -- fr
    ['Artículo expirado'] = true, -- es
    ['Срок продажи предмета истек'] = true, -- ru
    ['アイテム掲載終了'] = true, -- jp
    ['物品已过期'] = true, -- zh
    ['Försäljning utgången'] = true, -- sv
}

---@param mailId id64
---@return boolean expired
---@return number attachments
local function expiredListing(mailId)
    local _, _, subject, _, _, fromSystem, fromCS, _, count, money, cod = GetMailItemInfo(mailId)
    return fromSystem and not fromCS and EXPIRED_SUBJECTS[subject] == true and count >= 1 and money == 0 and cod == 0, count
end

---@type table<string, boolean> Expired-listing mails already requested this session
local readAhead = {}
---@type string|nil The read this module is waiting for
local awaitedRead

---The player mail selected in the gamepad inbox, read without changing it.
---The inbox builds its list on first use, so both reads may fail before that.
---@return id64|nil
local function selectedMail()
    local screen = rawget(_G, 'MAIL_GAMEPAD') ---@type InventoryPocMailScreen|nil
    local inbox = screen and screen:GetInbox()
    if not inbox then return nil end
    local ok, mailId = pcall(inbox.GetActiveMailId, inbox)
    local known, fromGuild = pcall(inbox.IsActiveMailFromGuild, inbox)
    return ok and known and not fromGuild and mailId or nil
end

---A mail's attachments are unknown until it has been read, so a bulk claim
---could not tell which items an expired listing returned. Read those mails
---ahead, once each. The inbox ignores a readable mail that is not selected
---(mailinbox_gamepad.lua, ShowMailItem), so nothing on screen changes. The
---client allows one read request at a time: after one of ours the player's
---selection is served first, in case it was refused while ours was pending.
---@param ownReadFinished boolean
local function readExpiredMail(ownReadFinished)
    if not poc.enabled or not poc.saved then return end
    if ownReadFinished then
        local selected = selectedMail()
        if selected and not IsReadMailInfoReady(selected)
            and RequestReadMail(selected) == REQUEST_READ_MAIL_RESULT_SUCCESS_SERVER_REQUESTED then return end
    end
    local mailId = GetNextMailId()
    while mailId do
        local id = Id64ToString(mailId)
        if not readAhead[id] and not IsReadMailInfoReady(mailId) and expiredListing(mailId) then
            local result = RequestReadMail(mailId)
            if result == REQUEST_READ_MAIL_RESULT_SUCCESS_SERVER_REQUESTED then
                readAhead[id], awaitedRead = true, id
                return
            end
            -- Another read is pending or the mailbox has closed: a later event retries.
            if result ~= REQUEST_READ_MAIL_RESULT_SUCCESS_CACHED and result ~= REQUEST_READ_MAIL_RESULT_NO_SUCH_MAIL then return end
            readAhead[id] = true
        end
        mailId = GetNextMailId(mailId)
    end
end

---@param mailId id64
---@param baseline (fun(): table<string, number>)|nil Shared backpack counts for a bulk claim
local function prepareClaim(mailId, baseline)
    if not poc.enabled or not poc.saved or not IsReadMailInfoReady(mailId) then return end
    local id = Id64ToString(mailId)
    if returns.claims[id] then return end
    local expired, count = expiredListing(mailId)
    if not expired then return end
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
    local before = baseline and baseline() or assert(counts(BAG_BACKPACK))
    returns.claims[id] = { items = items, before = before, started = GetFrameTimeMilliseconds(), success = false }
    returns.requestSync()
    poc.wake()
    BattleScrolls.gc:RequestGC(2)
end

function returns.initialize()
    if not poc.saved then return end
    poc.saved.returns = poc.saved.returns or { stock = {}, discounted = {}, relisted = {}, unsold = {} }
    poc.saved.returns.relisted = poc.saved.returns.relisted or {}
    poc.saved.returns.unsold = poc.saved.returns.unsold or {}
    if returns.registered then return end
    returns.registered = true
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_MAIL_INBOX_UPDATE, function() readExpiredMail(false) end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_MAIL_READABLE, function(_, mailId)
        local own = awaitedRead ~= nil and Id64ToString(mailId) == awaitedRead
        if own then awaitedRead = nil end
        readExpiredMail(own)
    end)
    -- Observe the existing claim flow. The game passes its own arguments
    -- after the mail (deleteOnClaim), which are not a shared baseline.
    local function claimOne(mailId) prepareClaim(mailId) end
    ZO_PreHook('TakeMailAttachments', claimOne)
    ZO_PreHook('TakeMailAttachedItems', claimOne)
    ZO_PreHook('TakeAllMailAttachmentsInCategory', function(category)
        if not poc.enabled then return end
        -- Every mail in the bulk claim starts from the same backpack: count it once.
        local shared
        local function baseline()
            shared = shared or assert(counts(BAG_BACKPACK))
            return shared
        end
        local mailId = GetNextMailId()
        while mailId do
            local _, _, _, _, _, _, _, _, _, _, _, _, _, mailCategory = GetMailItemInfo(mailId)
            if mailCategory == category then prepareClaim(mailId, baseline) end
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
