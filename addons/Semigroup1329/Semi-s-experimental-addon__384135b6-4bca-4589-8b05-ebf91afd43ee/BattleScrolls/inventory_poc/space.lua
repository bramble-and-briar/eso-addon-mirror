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

---Count the postings needed to empty one occupied bag slot.
---@param item InventoryPocItem
---@param budget number
---@return number|nil
local function postingsToEmpty(item, budget)
    local remaining = ZO_ShallowTableCopy(item) ---@type InventoryPocItem
    for posts = 1, budget do
        local quantity = policy.listingQuantity(remaining)
        if quantity == 0 then return end
        remaining.stack = remaining.stack - quantity
        if remaining.stack == 0 then return posts end
    end
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
            elseif action == 'sell' and item.vendorUnit > 0 then counts.sell = counts.sell + 1
            elseif action == 'deconstruct' and CanItemBeDeconstructed(item.bag, item.slot) then counts.deconstruct = counts.deconstruct + 1
            elseif action == 'bank' then counts.bank = counts.bank + 1
            elseif action == 'list' and IsItemSellableOnTradingHouse(item.bag, item.slot) then
                local posts = postingsToEmpty(item, listingSlots)
                postings[#postings + 1] = posts or (listingSlots + 1)
            end
        end
        if index % 5 == 0 then LibEffect.Yield():Await() end
    end
    for _, posts in ipairs(postings) do
        if posts > listingSlots then break end
        listingSlots = listingSlots - posts
        counts.list = counts.list + 1
    end
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
