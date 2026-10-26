---@diagnostic disable: undefined-field, inject-field -- Native trading-house objects expose additional runtime fields
if not SemisPlaygroundCheckAccess() then return end

---@class InventoryPocTradingHouseUI
local ui = {}
BattleScrolls.inventoryPocTradingHouseUI = ui
local market = BattleScrolls.inventoryPocMarket
local enabled, registered, suspended = false, false, false
---@class InventoryPocPresentationGate
---@field target table<string, unknown>
---@field key string
---@field original function|nil
---@type InventoryPocPresentationGate[]
local gates = {}

---Cancel native presentation while our service scene owns the visit.
local function suppressPresentation() return true end

---@param target table<string, unknown>|nil
---@param key string
local function gate(target, key)
    if not target or type(target[key]) ~= 'function' then return end
    gates[#gates + 1] = { target = target, key = key, original = rawget(target, key) }
    target[key] = suppressPresentation
end

---@return boolean
function ui.isSuspended()
    return suspended
end

---@param value boolean
function ui.setSuspended(value)
    if suspended == value then return end
    suspended = value
    if value then
        -- Guild-store opening initializes its controls before requesting a scene.
        -- Block that entry point for the automated visit. Restore the exact
        -- original methods before the player's next native opening event.
        gate(TRADING_HOUSE_GAMEPAD, 'OpenTradingHouse')
        gate(TRADING_HOUSE, 'OpenTradingHouse')
        gate(TRADING_HOUSE, 'OnSearchStateChanged')
        gate(TRADING_HOUSE, 'OnAwaitingResponse')
        gate(TRADING_HOUSE, 'OnResponseReceived')
        gate(TRADING_HOUSE, 'UpdateForGuildChange')
        gate(TRADING_HOUSE, 'UpdateStatus')
        gate(TRADING_HOUSE, 'OnOperationTimeout')
        gate(TRADING_HOUSE, 'OnPendingPostItemUpdated')
        gate(TRADING_HOUSE_GAMEPAD, 'LockForInput')
        gate(TRADING_HOUSE_GAMEPAD, 'UnlockForInput')
        gate(TRADING_HOUSE_GAMEPAD, 'OnSelectedGuildChanged')
        gate(GAMEPAD_TRADING_HOUSE_LISTINGS, 'RefreshData')
        gate(GAMEPAD_TRADING_HOUSE_LISTINGS, 'RequestListUpdate')
        gate(GAMEPAD_TRADING_HOUSE_BROWSE, 'RefreshVisible')
        gate(GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS, 'OnSearchStateChanged')
        gate(GAMEPAD_TRADING_HOUSE_BROWSE_RESULTS, 'OnResponseReceived')
    else
        for _, entry in ipairs(gates) do
            if entry.target[entry.key] == suppressPresentation then entry.target[entry.key] = entry.original end
        end
        gates = {}
    end
end

---@param value boolean
function ui.setEnabled(value)
    enabled = value
    if not value then ui.setSuspended(false) end
    if not value or registered then return end
    registered = true
    -- Render the receipt-confirmed count whenever the Sell button is rebuilt.
    -- Native action descriptors and their callbacks retain their original owners.
    SecurePostHook(KEYBIND_STRIP, 'SetUpButton', function(_, button)
        if not enabled or suspended or GetInteractionType() ~= INTERACTION_TRADINGHOUSE then return end
        local sell = GAMEPAD_TRADING_HOUSE_SELL
        if not sell or not sell.keybindStripDescriptor
            or button.keybindButtonDescriptor ~= sell.keybindStripDescriptor[1] or button:IsHidden() then return end
        local counts = market.listings[GetSelectedTradingHouseGuildId()]
        if not counts or not counts.fresh then return end
        local available = counts.used < counts.capacity
        button.nameLabel:SetText(zo_strformat(available and SI_GAMEPAD_TRADING_HOUSE_LISTING_CREATE
            or SI_GAMEPAD_TRADING_HOUSE_LISTING_CREATE_FULL, counts.used, counts.capacity))
        button:SetEnabled(available)
    end)
end
