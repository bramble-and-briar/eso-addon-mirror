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
---@field contents InventoryPocLootEntry[]
---@field captured boolean
---@field currencyReceived table<number, number>

---@type InventoryPocContainerUse|nil
local containerUse

---@param pending InventoryPocPending
function ui.beginUse(pending)
    if pending.action == 'open' then
        -- Inventory reconciliation can finish before the final loot updates arrive.
        pending.contents = {}
        containerUse = { name = pending.item.name, expiresAt = pending.started + USE_TIMEOUT_MS, taken = false, closed = false,
            contents = pending.contents, captured = false, currencyReceived = {} }
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

---@param use InventoryPocContainerUse
---@param currency number
---@param amount number
---@param stolen boolean
local function recordCurrency(use, currency, amount, stolen)
    if amount <= 0 then return end
    for _, entry in ipairs(use.contents) do
        if entry.currencyType == currency and entry.stolen == stolen then
            entry.quantity = math.max(entry.quantity, amount)
            return
        end
    end
    use.contents[#use.contents + 1] = { currencyType = currency, quantity = amount, stolen = stolen,
        name = GetCurrencyName(currency, IsCountSingularForm(amount), false), icon = GetCurrencyLootGamepadIcon(currency) }
end

---@param use InventoryPocContainerUse
local function captureContents(use)
    if use.captured then return end
    use.captured = true
    for currency = CURT_ITERATION_BEGIN, CURT_ITERATION_END do
        if IsCurrencyValid(currency) then
            local amount, stolenAmount = GetLootCurrency(currency)
            recordCurrency(use, currency, amount, false)
            recordCurrency(use, currency, stolenAmount, true)
        end
    end
    -- Capture the live loot buffer before LootAll clears it. This small snapshot
    -- stays attached to the opening through late loot events and inventory updates.
    for index = 1, GetNumLootItems() do
        local lootId, name, icon, quantity, quality, _, isQuest, stolen, lootType = GetLootItemInfo(index)
        ---@type InventoryPocLootEntry
        local entry = { name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name), icon = icon, quantity = quantity,
            quality = quality, stolen = stolen, lootType = lootType, link = GetLootItemLink(lootId, LINK_STYLE_DEFAULT) }
        if isQuest then entry.questItemId = GetLootQuestItemId(lootId)
        elseif lootType == LOOT_TYPE_ANTIQUITY_LEAD then entry.antiquityId = GetLootAntiquityLeadId(lootId)
        elseif lootType == LOOT_TYPE_TRIBUTE_CARD_UPGRADE then
            entry.tributePatronId, entry.tributeCardIndex = GetLootTributeCardUpgradeInfo(lootId)
        end
        use.contents[#use.contents + 1] = entry
    end
    poc.revision = poc.revision + 1
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
    captureContents(use)
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
    EVENT_MANAGER:RegisterForEvent('BattleScrollsInventoryPocUseUI', EVENT_CURRENCY_UPDATE,
        function(_, currency, location, amount, oldAmount, reason)
            if reason ~= CURRENCY_CHANGE_REASON_LOOT_CURRENCY_CONTAINER or amount <= oldAmount
                or location ~= GetCurrencyPlayerStoredLocation(currency) then return end
            local use = currentContainer()
            if not use then return end
            use.currencyReceived[currency] = (use.currencyReceived[currency] or 0) + amount - oldAmount
            recordCurrency(use, currency, use.currencyReceived[currency], false)
            poc.revision = poc.revision + 1
        end)
    ZO_PreHook(LORE_READER, 'Show', function(_, title)
        local pending = currentUse('learn')
        if not pending or pending.item.kind ~= 'motif' then return end
        local expected = GetItemLinkBookTitle(pending.item.link)
        return expected ~= '' and zo_strformat(SI_TOOLTIP_ITEM_NAME, title) == zo_strformat(SI_TOOLTIP_ITEM_NAME, expected)
    end)
end
