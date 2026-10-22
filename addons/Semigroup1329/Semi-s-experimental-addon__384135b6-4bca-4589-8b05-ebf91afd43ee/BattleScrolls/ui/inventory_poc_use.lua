---@diagnostic disable: undefined-field, inject-field -- Native UI objects expose additional runtime methods
if not SemisPlaygroundCheckAccess() then return end

---@class InventoryPocUseUI
local ui = {}
BattleScrolls.inventoryPocUseUI = ui
local poc = BattleScrolls.inventoryPoc
local hooked = {}
local registered = false
local USE_TIMEOUT_MS, LOOT_DRAIN_MS = 15000, 1000

---@class InventoryPocContainerUse
---@field name string
---@field expiresAt number
---@field taken boolean
---@field closed boolean

---@type InventoryPocContainerUse|nil
local containerUse

---@param pending InventoryPocPending
function ui.beginUse(pending)
    if pending.action == 'open' then
        -- Inventory reconciliation can finish before the final loot updates arrive.
        containerUse = { name = pending.item.name, expiresAt = pending.started + USE_TIMEOUT_MS, taken = false, closed = false }
    end
end

---@return InventoryPocContainerUse|nil
local function currentContainer()
    if containerUse and (not poc.enabled or GetFrameTimeMilliseconds() > containerUse.expiresAt) then containerUse = nil end
    return containerUse
end

---@param action InventoryPocAction
---@return InventoryPocPending|nil
local function currentUse(action)
    local pending = poc.enabled and poc.saved and poc.saved.pending
    if pending and pending.action == action and GetFrameTimeMilliseconds() - pending.started <= USE_TIMEOUT_MS then
        return pending
    end
end

local function takeOwnContainer()
    local use = currentContainer()
    if not use then return end
    local name, targetType = GetLootTargetInfo()
    if name ~= '' and (targetType ~= INTERACT_TARGET_TYPE_ITEM or zo_strformat(SI_TOOLTIP_ITEM_NAME, name) ~= use.name) then
        containerUse = nil
        return
    end
    local hasCurrency, capped = false, false
    for currency = CURT_ITERATION_BEGIN, CURT_ITERATION_END do
        if IsCurrencyValid(currency) then
            local amount, stolenAmount = GetLootCurrency(currency)
            hasCurrency = hasCurrency or amount > 0 or stolenAmount > 0
            local location = GetCurrencyPlayerStoredLocation(currency)
            capped = capped or (amount > 0 and GetCurrencyAmount(currency, location) + amount > GetMaxPossibleCurrency(currency, location))
        end
    end
    if name == '' or use.closed then
        -- Gamepad UpdateLootWindow calls Show when its control is hidden,
        -- including empty updates queued around LootAll and EndLooting.
        if GetNumLootItems() == 0 and not hasCurrency then return true end
        containerUse = nil
        return
    end
    if use.taken then return true end
    if GetNumBagFreeSlots(BAG_BACKPACK) == 0 or capped then
        containerUse = nil
        return
    end
    use.taken = true
    LootAll(false)
    EndLooting()
    poc.resume()
    return true
end

local function hookLoot()
    local loot = SYSTEMS:GetObject('loot')
    if loot and not hooked[loot] then
        hooked[loot] = true
        ZO_PreHook(loot, 'UpdateLootWindow', takeOwnContainer)
    end
end

function ui.initialize()
    containerUse = nil
    if registered then return end
    registered = true
    hookLoot()
    EVENT_MANAGER:RegisterForEvent('BattleScrollsInventoryPocUseUI', EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, hookLoot)
    EVENT_MANAGER:RegisterForEvent('BattleScrollsInventoryPocUseUI', EVENT_LOOT_CLOSED, function()
        local use = currentContainer()
        if use and not use.closed then
            use.closed = true
            use.expiresAt = GetFrameTimeMilliseconds() + LOOT_DRAIN_MS + GetLatency()
        end
    end)
    ZO_PreHook(LORE_READER, 'Show', function(_, title)
        local pending = currentUse('learn')
        if not pending or pending.item.kind ~= 'motif' then return end
        local expected = GetItemLinkBookTitle(pending.item.link)
        return expected ~= '' and zo_strformat(SI_TOOLTIP_ITEM_NAME, title) == zo_strformat(SI_TOOLTIP_ITEM_NAME, expected)
    end)
end
