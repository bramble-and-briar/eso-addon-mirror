-- Entry point: wires SavedVariables, queue, watcher and screen together once the add-on is loaded.
local function OnPlayerActivated()
    EVENT_MANAGER:UnregisterForEvent(TradeQR.name, EVENT_PLAYER_ACTIVATED)
    TradeQR.saleQueue:PruneSeen(GetTimeStamp())
    TradeQR.saleWatcher:Start()
    TradeQR.saleScreen:StartAutoShow()
end

-- "/tradeqr" opens the screen, "/tradeqr diag" prints the watcher state, "/tradeqr scan" polls now.
local function OnSlashCommand(arguments)
    local command = string.lower(string.match(arguments or "", "^%s*(.-)%s*$"))
    if command == "diag" then
        TradeQR.diagnostics:Print()
    elseif command == "scan" then
        TradeQR.saleWatcher:PollAllGuilds()
        d(GetString(TRADEQR_CHAT_SCAN_STARTED))
    else
        TradeQR.saleScreen:Show()
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= TradeQR.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(TradeQR.name, EVENT_ADD_ON_LOADED)

    local savedVars = ZO_SavedVars:NewAccountWide(TradeQR.savedVariablesName, TradeQR.savedVariablesVersion, nil, TradeQR.defaults)
    -- Left over by 0.1.0 (time-window scanning), no longer used.
    savedVars.lastScanTimestampByGuildId = nil
    local salePayload = TradeQR.SalePayload:New(TradeQR.JsonEncoder:New())

    TradeQR.saleQueue = TradeQR.SaleQueue:New(savedVars)
    TradeQR.saleWatcher = TradeQR.SaleWatcher:New(savedVars, TradeQR.saleQueue)
    TradeQR.saleScreen = TradeQR.SaleScreen:New(TradeQR.saleQueue, salePayload, savedVars)
    TradeQR.diagnostics = TradeQR.Diagnostics:New(TradeQR.saleWatcher, TradeQR.saleQueue, savedVars)

    SLASH_COMMANDS["/tradeqr"] = OnSlashCommand

    EVENT_MANAGER:RegisterForEvent(TradeQR.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

EVENT_MANAGER:RegisterForEvent(TradeQR.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
