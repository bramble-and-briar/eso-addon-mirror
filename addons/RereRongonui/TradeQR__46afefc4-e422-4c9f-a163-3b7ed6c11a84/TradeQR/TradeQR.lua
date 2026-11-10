-- Entry point: wires SavedVariables, queue, watcher and screen together once the add-on is loaded.
local function OnPlayerActivated()
    EVENT_MANAGER:UnregisterForEvent(TradeQR.name, EVENT_PLAYER_ACTIVATED)
    TradeQR.saleQueue:PruneSeen(GetTimeStamp())
    TradeQR.saleWatcher:Start()
    TradeQR.saleScreen:StartAutoShow()
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= TradeQR.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(TradeQR.name, EVENT_ADD_ON_LOADED)

    local savedVars = ZO_SavedVars:NewAccountWide(TradeQR.savedVariablesName, TradeQR.savedVariablesVersion, nil, TradeQR.defaults)
    local salePayload = TradeQR.SalePayload:New(TradeQR.JsonEncoder:New())

    TradeQR.saleQueue = TradeQR.SaleQueue:New(savedVars)
    TradeQR.saleWatcher = TradeQR.SaleWatcher:New(savedVars, TradeQR.saleQueue)
    TradeQR.saleScreen = TradeQR.SaleScreen:New(TradeQR.saleQueue, salePayload, savedVars)

    -- Manual opening, also handy on PC while testing.
    SLASH_COMMANDS["/tradeqr"] = function() TradeQR.saleScreen:Show() end

    EVENT_MANAGER:RegisterForEvent(TradeQR.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent(TradeQR.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
