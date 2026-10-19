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
local returns = { registered = false, claims = {} }
BattleScrolls.inventoryPocReturns = returns
local poc = BattleScrolls.inventoryPoc
local facts = BattleScrolls.inventoryPocFacts
local EVENT_NAME = 'BattleScrollsInventoryPocReturns'

---@param bag number
---@return string
local function location(bag)
    return bag == BAG_BACKPACK and ('character:' .. GetCurrentCharacterId()) or ('bag:' .. tostring(bag))
end

---@param bag number
---@return table<string, number>
local function counts(bag)
    local result = {}
    for slot = 0, GetBagSize(bag) - 1 do
        local link = GetItemLink(bag, slot, LINK_STYLE_DEFAULT)
        if link ~= '' then
            local key = facts.variantKey(facts.variant(link))
            local quantity = GetSlotStackSize(bag, slot)
            result[key] = (result[key] or 0) + quantity
        end
    end
    return result
end

---@param item InventoryPocItem
---@return boolean
function returns.isDiscounted(item)
    return poc.enabled and poc.saved ~= nil and poc.saved.returns.discounted[facts.variantKey(item)] == true
end

---An expiry reprices identical stock across known locations until it is gone.
---Restacking or moving between the backpack and bank preserves that signal.
function returns.sync()
    if not poc.enabled or not poc.saved then return end
    local state = poc.saved.returns
    state.stock[location(BAG_BACKPACK)] = counts(BAG_BACKPACK)
    if IsBankOpen() and (GetBankingBag() == BAG_BANK or GetBankingBag() == BAG_SUBSCRIBER_BANK) then
        state.stock[location(BAG_BANK)] = counts(BAG_BANK)
        if IsESOPlusSubscriber() then state.stock[location(BAG_SUBSCRIBER_BANK)] = counts(BAG_SUBSCRIBER_BANK) end
    end
    for key in pairs(state.discounted) do
        local pending = poc.saved.pending
        local owned = pending and facts.variantKey(pending.item) == key or false
        for _, quantities in pairs(state.stock) do
            if (quantities[key] or 0) > 0 then owned = true; break end
        end
        if not owned then state.discounted[key] = nil end
    end
    local pack = state.stock[location(BAG_BACKPACK)]
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
    end
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
    returns.sync()
    returns.claims[id] = { items = items, before = counts(BAG_BACKPACK), started = GetFrameTimeMilliseconds(), success = false }
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
        if claim then claim.success = true; poc.wake() end
    end)
end

function returns.reset()
    returns.claims = {}
end
