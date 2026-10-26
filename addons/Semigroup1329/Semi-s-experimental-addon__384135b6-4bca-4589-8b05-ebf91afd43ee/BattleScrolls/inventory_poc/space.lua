if not SemisPlaygroundCheckAccess() then return end

---@alias InventoryPocSpaceAction 'sell'|'deconstruct'|'bank'|'list'
---@class InventoryPocSpaceOption
---@field action InventoryPocSpaceAction
---@field slots number
---@class InventoryPocSpaceSummary
---@field best InventoryPocSpaceOption|nil
---@field assistant InventoryPocSpaceOption|nil
---@class InventoryPocSpace
local space = {}
BattleScrolls.inventoryPocSpace = space
local policy = BattleScrolls.inventoryPocPolicy
local ORDER = { 'sell', 'deconstruct', 'bank', 'list' }

---Estimate space using the planned listing values and stack sizes.
---@param items InventoryPocItem[] Mutable copies of the sale candidates
---@param budget number
---@return number
local function listingSpace(items, budget)
    local freed = 0
    for post = 1, budget do
        local best, quantity, highest = nil, 0, 0
        for index, item in ipairs(items) do
            local count = policy.listingQuantity(item)
            local total = math.floor(count * (item.marketUnit or 0))
            if total > highest or (best and total == highest and item.slot < items[best].slot) then
                best, quantity, highest = index, count, total
            end
        end
        if not best then break end
        local item = items[best]
        item.stack = item.stack - quantity
        if item.stack == 0 then freed = freed + 1; table.remove(items, best) end
        if post % 5 == 0 then LibEffect.Yield():Await() end
    end
    return freed
end

---Run within LibEffect.Async; the input is a fresh, reserved backpack scan.
---@param items InventoryPocItem[]
---@param listingSlots number
---@param buildDeposits table<string, boolean>
---@return InventoryPocSpaceSummary
function space.summarize(items, listingSlots, buildDeposits)
    local counts = { sell = 0, deconstruct = 0, bank = 0, list = 0 }
    local postings = {}
    for index, item in ipairs(items) do
        local action = policy.decide(item).action
        if item.bag == BAG_BACKPACK then
            if buildDeposits[item.uniqueId] then counts.bank = counts.bank + 1
            elseif action == 'sell' and item.vendorUnit > 0 and policy.disposalQuantity(item) == item.stack then counts.sell = counts.sell + 1
            elseif action == 'deconstruct' and CanItemBeDeconstructed(item.bag, item.slot) then counts.deconstruct = counts.deconstruct + 1
            elseif action == 'bank' then counts.bank = counts.bank + 1
            elseif action == 'list' and IsItemSellableOnTradingHouse(item.bag, item.slot) then
                postings[#postings + 1] = ZO_ShallowTableCopy(item)
            end
        end
        if index % 5 == 0 then LibEffect.Yield():Await() end
    end
    counts.list = listingSpace(postings, listingSlots)
    local summary = {} ---@type InventoryPocSpaceSummary
    for _, action in ipairs(ORDER) do
        local slots = counts[action]
        if slots > 0 then
            local option = { action = action, slots = slots } ---@type InventoryPocSpaceOption
            if not summary.best or slots > summary.best.slots then summary.best = option end
            if action ~= 'list' and (not summary.assistant or slots > summary.assistant.slots) then summary.assistant = option end
        end
    end
    return summary
end
