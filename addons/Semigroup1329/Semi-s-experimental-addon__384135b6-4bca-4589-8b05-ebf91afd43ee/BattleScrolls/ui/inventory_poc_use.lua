---@diagnostic disable: undefined-field, inject-field -- Native UI objects expose additional runtime methods
if not SemisPlaygroundCheckAccess() then return end

---@class InventoryPocUseUI
local ui = {}
BattleScrolls.inventoryPocUseUI = ui
local poc = BattleScrolls.inventoryPoc
local registered = false
local USE_TIMEOUT_MS, LOOT_DRAIN_MS = 15000, 1000
local EVENT_NAME = 'BattleScrollsInventoryPocUseUI'
local GATE_WATCH_MS = 250

---A wrapper on a native UI method puts an addon frame under everything that
---method does, and every closure ESO creates there stays untrusted for the
---session (docs/inventory-addon/ui-taint.md). A gate therefore exists only
---while one of our own uses is waiting for that screen; ordinary loot and
---books reach ESO's methods directly.
---@class InventoryPocGate
---@field target table
---@field name string
---@field wrapper function
---@field previous function|nil The instance's own field before the gate; nil when inherited
---@field needed fun(): boolean

---@type table<string, InventoryPocGate>
local gates = {}
local watching = false

---@param key string
local function closeGate(key)
    local gate = gates[key]
    if not gate then return end
    gates[key] = nil
    -- A wrapper another addon added later keeps ours in its chain; ours then only passes calls through.
    if rawget(gate.target, gate.name) == gate.wrapper then gate.target[gate.name] = gate.previous end
end

local function watchGates()
    for key, gate in pairs(gates) do
        if not gate.needed() then closeGate(key) end
    end
    if not next(gates) then
        EVENT_MANAGER:UnregisterForUpdate(EVENT_NAME)
        watching = false
    end
end

---@param key string
---@param target table
---@param name string
---@param take fun(...): boolean|nil True when the call belonged to our use and was handled
---@param needed fun(): boolean
local function openGate(key, target, name, take, needed)
    local current = gates[key]
    if current and current.target == target then return end
    closeGate(key)
    local original = target[name]
    ---@type InventoryPocGate
    local gate = { target = target, name = name, previous = rawget(target, name), needed = needed }
    gate.wrapper = function(...)
        if gates[key] == gate then
            if take(...) then return end
            if not needed() then closeGate(key) end
        end
        return original(...)
    end
    target[name] = gate.wrapper
    gates[key] = gate
    if not watching then
        watching = true
        EVENT_MANAGER:RegisterForUpdate(EVENT_NAME, GATE_WATCH_MS, watchGates)
    end
end

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

---@type fun()
local gateLoot
---@type fun()
local gateBook

---@param pending InventoryPocPending
function ui.beginUse(pending)
    if pending.action == 'open' then
        BattleScrolls.inventoryPocCoffers.beginUse(pending.item.itemId)
        -- Inventory reconciliation can finish before the final loot updates arrive.
        pending.contents = {}
        containerUse = { name = pending.item.name, expiresAt = pending.started + USE_TIMEOUT_MS, taken = false, closed = false,
            contents = pending.contents, captured = false, currencyReceived = {} }
        gateLoot()
    elseif pending.action == 'learn' and pending.item.kind == 'motif' then
        gateBook()
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
    BattleScrolls.inventoryPocCoffers.capture(use.contents)
    LootAll(false)
    EndLooting()
    poc.resume()
    return true
end

gateLoot = function()
    local loot = SYSTEMS:GetObject('loot')
    if loot then
        openGate('loot', loot, 'UpdateLootWindow', takeOwnContainer, function() return currentContainer() ~= nil end)
    end
end

---Suppress the reader for the motif being learned; any other book ends the gate.
---@param title string
---@return boolean|nil
local function takeOwnBook(_, title)
    local pending = currentUse('learn')
    if not pending or pending.item.kind ~= 'motif' then return end
    local expected = GetItemLinkBookTitle(pending.item.link)
    if not expected or expected == '' or zo_strformat(SI_TOOLTIP_ITEM_NAME, title) ~= zo_strformat(SI_TOOLTIP_ITEM_NAME, expected) then
        return
    end
    -- The reader's hide handler normally ends the book interaction.
    EndInteraction(INTERACTION_BOOK)
    return true
end

gateBook = function()
    openGate('book', LORE_READER, 'Show', takeOwnBook, function()
        local pending = currentUse('learn')
        return pending ~= nil and pending.item.kind == 'motif'
    end)
end

function ui.initialize()
    containerUse = nil
    for key in pairs(gates) do closeGate(key) end
    if registered then return end
    registered = true
    -- The loot object differs between input modes; follow a use across a switch.
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
        if currentContainer() then gateLoot() end
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_LOOT_CLOSED, function()
        local use = currentContainer()
        if use and not use.closed then
            use.closed = true
            use.expiresAt = GetFrameTimeMilliseconds() + LOOT_DRAIN_MS + GetLatency()
        end
    end)
    EVENT_MANAGER:RegisterForEvent(EVENT_NAME, EVENT_CURRENCY_UPDATE,
        function(_, currency, location, amount, oldAmount, reason)
            if reason ~= CURRENCY_CHANGE_REASON_LOOT_CURRENCY_CONTAINER or amount <= oldAmount
                or location ~= GetCurrencyPlayerStoredLocation(currency) then return end
            local use = currentContainer()
            if not use then return end
            use.currencyReceived[currency] = (use.currencyReceived[currency] or 0) + amount - oldAmount
            recordCurrency(use, currency, use.currencyReceived[currency], false)
            poc.revision = poc.revision + 1
        end)
end
