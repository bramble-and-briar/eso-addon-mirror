if not SemisPlaygroundCheckAccess() then return end

---Sorts the pack by what each slot is waiting for.
---
---The helper carries a decision out only at the service that can: a listing
---needs the guild store and a free slot, a sale needs a merchant. A slot's
---fate is therefore its decision plus whatever stands between the item and
---that service. Slots with nothing in their way leave on the next visit;
---the rest are what fills a pack. Listings the guild store cannot take soon
---leave for the bank instead.

---@alias InventoryPocFate 'listWait'|'price'|'info'|'list'|'listNext'|'sell'|'deconstruct'|'bank'|'auto'|'unassigned'|'keep'
---@alias InventoryPocFateClass 'stuck'|'trade'|'leaves'|'unassigned'|'kept'

---@class InventoryPocAnalysisRow
---@field item InventoryPocItem
---@field decision InventoryPocDecision
---@field fate InventoryPocFate
---@field quantity number Pieces the decision applies to
---@field value number|nil Gold the listing or the merchant sale is planned at
---@field rank number|nil Place in the listing queue
---@field quoted boolean The market price is a guild store quote, not the price list
---@field discounted boolean Returned unsold: priced at half
---@field buildDeposit boolean Gear of another build, on its way to the bank
---@field overflow boolean A listing beyond the pack's allowance: it waits in the bank

---@class InventoryPocAnalysisGroup
---@field fate InventoryPocFate
---@field class InventoryPocFateClass
---@field rows InventoryPocAnalysisRow[]

---@class InventoryPocAnalysis
---@field groups InventoryPocAnalysisGroup[] Non-empty, the most blocked first
---@field used number
---@field size number
---@field classes table<InventoryPocFateClass, number> Pack slots per class
---@field listingFree number|nil Nil until every trading guild's listings have been read
---@field listingCapacity number|nil
---@field listingAllowance number Listings the pack keeps: the free slots it knows of and a reserve
---@field waitingValue number Gold in listings that have no slot
---@field merchantValue number

---@class InventoryPocAnalysisModule
---@field ORDER InventoryPocFate[]
---@field CLASS table<InventoryPocFate, InventoryPocFateClass>
---@field CLASSES InventoryPocFateClass[]
local analysis = {
    ORDER = { 'listWait', 'price', 'info', 'list', 'listNext', 'sell', 'deconstruct', 'bank', 'auto', 'unassigned', 'keep' },
    CLASS = { listWait = 'stuck', price = 'stuck', info = 'stuck', list = 'trade', listNext = 'trade', sell = 'leaves',
        deconstruct = 'leaves', bank = 'leaves', auto = 'leaves', unassigned = 'unassigned', keep = 'kept' },
    CLASSES = { 'stuck', 'trade', 'leaves', 'unassigned', 'kept' },
}
BattleScrolls.inventoryPocAnalysis = analysis
local policy = BattleScrolls.inventoryPocPolicy
local facts = BattleScrolls.inventoryPocFacts
local market = BattleScrolls.inventoryPocMarket

---@param decision InventoryPocDecision
---@return InventoryPocFate
local function decidedFate(decision)
    local action = decision.action
    if action == 'list' then return 'list' end
    if action == 'defer' then return decision.reason == 'price' and 'price' or 'info' end
    if action == 'sell' or action == 'deconstruct' or action == 'bank' then return action end
    if action == 'keep' then return decision.reason == 'unassigned' and 'unassigned' or 'keep' end
    return 'auto'
end

---Listing counts are read at the guild store and remembered for the session.
---@return number|nil free
---@return number|nil capacity
local function listingSlots()
    local free, capacity = 0, 0
    for _, guildId in ipairs(facts.guildIds()) do
        local counts = market.listings[guildId]
        if not counts then return nil end
        free, capacity = free + math.max(0, counts.capacity - counts.used), capacity + counts.capacity
    end
    return free, capacity
end

---@param a InventoryPocAnalysisRow
---@param b InventoryPocAnalysisRow
---@return boolean
local function byName(a, b)
    if a.item.name ~= b.item.name then return a.item.name < b.item.name end
    return a.item.slot < b.item.slot
end

---@param a InventoryPocAnalysisRow
---@param b InventoryPocAnalysisRow
---@return boolean
local function byValue(a, b)
    if a.value ~= b.value then return (a.value or 0) > (b.value or 0) end
    return a.item.slot < b.item.slot
end

---@param a InventoryPocAnalysisRow
---@param b InventoryPocAnalysisRow
---@return boolean
local function byReason(a, b)
    if a.decision.reason ~= b.decision.reason then return a.decision.reason < b.decision.reason end
    return byName(a, b)
end

---Run within LibEffect.Async; the input is a fresh, reserved backpack scan.
---@param items InventoryPocItem[]
---@param deposits table<string, boolean> Items the selected build sends to the bank
---@param size number Pack capacity
---@return InventoryPocAnalysis
function analysis.build(items, deposits, size)
    local returns = BattleScrolls.inventoryPocReturns
    local free, capacity = listingSlots()
    ---@type table<InventoryPocFate, InventoryPocAnalysisRow[]>
    local byFate = {}
    ---@type InventoryPocAnalysisRow[]
    local queue = {}
    ---@type table<InventoryPocAnalysisRow, number>
    local order = {}
    ---@type InventoryPocAnalysis
    local result = { groups = {}, used = #items, size = size, classes = {}, listingFree = free, listingCapacity = capacity,
        listingAllowance = market.listingAllowance(), waitingValue = 0, merchantValue = 0 }
    for _, class in ipairs(analysis.CLASSES) do result.classes[class] = 0 end
    for index, item in ipairs(items) do
        local decision = policy.decide(item)
        local deposit = deposits[item.uniqueId] == true
        local fate = deposit and 'bank' or decidedFate(decision)
        ---@type InventoryPocAnalysisRow
        local row = { item = item, decision = decision, fate = fate, quantity = item.stack,
            quoted = facts.quoted(item), discounted = returns.isDiscounted(item),
            buildDeposit = deposit, overflow = false }
        if fate == 'list' then
            row.quantity = policy.listingQuantity(item)
            row.value = math.floor(row.quantity * (item.marketUnit or 0))
            -- The guild store lists in this order, so it is the queue.
            order[row] = market.listingValue(item)
            queue[#queue + 1] = row
        else
            if fate == 'sell' then
                row.quantity = policy.disposalQuantity(item)
                row.value = row.quantity * item.vendorUnit
                result.merchantValue = result.merchantValue + row.value
            elseif fate == 'deconstruct' then
                row.quantity = policy.disposalQuantity(item)
            end
            byFate[fate] = byFate[fate] or {}
            table.insert(byFate[fate], row)
        end
        if index % 10 == 0 then LibEffect.Yield():Await() end
    end
    table.sort(queue, function(a, b)
        if order[a] ~= order[b] then return order[a] > order[b] end
        return a.item.slot < b.item.slot
    end)
    for rank, row in ipairs(queue) do
        row.rank = rank
        -- The bank can hold listings ranked above these, so more may follow.
        if rank > result.listingAllowance then row.fate, row.overflow = 'bank', true
        elseif free then row.fate = rank <= free and 'listNext' or 'listWait' end
        if row.fate == 'listWait' or row.overflow then result.waitingValue = result.waitingValue + (row.value or 0) end
        byFate[row.fate] = byFate[row.fate] or {}
        table.insert(byFate[row.fate], row)
    end
    for _, fate in ipairs(analysis.ORDER) do
        local rows = byFate[fate]
        if rows then
            -- The listing queue is already in order.
            if fate == 'sell' then table.sort(rows, byValue)
            elseif fate == 'keep' then table.sort(rows, byReason)
            elseif fate ~= 'list' and fate ~= 'listNext' and fate ~= 'listWait' then table.sort(rows, byName) end
            local class = analysis.CLASS[fate]
            result.classes[class] = result.classes[class] + #rows
            result.groups[#result.groups + 1] = { fate = fate, class = class, rows = rows }
        end
    end
    return result
end

---@return Effect<InventoryPocAnalysis>
function analysis.scan()
    return LibEffect.Async(function()
        local _, reserved = facts.wardrobe(true)
        local items = facts.bag(BAG_BACKPACK, reserved)
        local deposits = BattleScrolls.inventoryPocBuilds.depositIds(reserved, items)
        return analysis.build(items, deposits, GetBagSize(BAG_BACKPACK))
    end)
end
