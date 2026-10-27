-- Core/InventoryCompanion_Events.lua
InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local activeListeners = {}

------------------------------------------------------------------
-- Debounce Queue System (Local)
------------------------------------------------------------------
local pendingActions = {}
local callLaterHandle = nil
local DEFAULT_DELAY_MS = 500

local function Enqueue(key, func, delayMs)
    delayMs = delayMs or DEFAULT_DELAY_MS

    if not pendingActions[key] then
        pendingActions[key] = func
    end

    if callLaterHandle then
        zo_removeCallLater(callLaterHandle)
        callLaterHandle = nil
    end

    callLaterHandle = zo_callLater(function()
        callLaterHandle = nil
        
        local executing = pendingActions
        pendingActions = {}

        for _, qFunc in pairs(executing) do
            qFunc()
        end
    end, delayMs)
end

------------------------------------------------------------------
-- Event Conditions & Handlers
------------------------------------------------------------------
local function ShouldListenOpenBank()
    return this.accountWide.autoMergeChests ~= false
end

local function ShouldListenSlotUpdate()
    local showMeters   = this.HasVisibleProgressBars()
    local showTracker  = this.accountWide.showTrackedItemsPanel ~= false
    local showCapacity = this.HasVisibleCapacityResources()

    return showMeters or showTracker or showCapacity or this.HasCapacityNotifications()
end

local function ShouldListenCurrencyUpdates()
    return this.HasCurrencyResourcesToTrack()
        or this.HasVisibleCurrencyProgressBars()
        or this.HasCurrencyNotifications()
end

local function ShouldListenCurrencyCapUpdates()
    return this.HasVisibleCappedCurrencyResources() or this.HasVisibleCappedProgressBars()
end

local function ShouldListenBagCapacity()
    return this.IsProgressBarVisible("capacity:bag") or this.IsCapacityResourceVisible("bag")
end

local function ShouldListenBankCapacity()
    return this.IsProgressBarVisible("capacity:bank") or this.IsCapacityResourceVisible("bank")
end

local function OnBankOpened(eventCode, bankType)
    if this.accountWide.autoMergeChests ~= false then
        this.OnBankOpened(eventCode, bankType)
    end
end

local function OnInventorySlotUpdate(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason, stackCountChange)
    this.HandleTrackedItemInventoryUpdate(bagId, slotIndex, stackCountChange)

    if this.HasCapacityNotifications() then
        local eventKind = bagId == BAG_BACKPACK and "bag"
            or ((bagId == BAG_BANK or bagId == BAG_SUBSCRIBER_BANK) and "bank" or nil)
        this.NotifyLiveCapacityChanges(nil, eventKind, stackCountChange)
    end

    if this.accountWide.showTrackedItemsPanel ~= false then
        Enqueue("RefreshItemTracker", function()
            this.RefreshItemTrackerPanel()
        end, 500)
    end

    if this.HasVisibleCapacityResources() then
        Enqueue("RefreshCurrency", function()
            this.RefreshCurrencyPanel()
        end, 500)
    end

    if this.HasVisibleProgressBars() then
        Enqueue("RefreshProgress", function()
            this.RefreshResourceProgressBars()
        end, 500)
    end
end

local function OnCurrencyUpdate(eventCode, currencyType, currencyLocation, newAmount, oldAmount, reason)
    local shouldRefreshPanel = this.IsCurrencyResourceVisible(currencyType, currencyLocation)
    local shouldRefreshBar = this.IsCurrencyProgressBarVisible(currencyType)
    this.NotifyCurrencyChange(currencyType, currencyLocation, newAmount, reason)
    if not shouldRefreshPanel and not shouldRefreshBar then
        return
    end
    Enqueue("RefreshCurrency", function()
        if shouldRefreshPanel then
            this.RefreshCurrencyPanel()
        end
        if shouldRefreshBar then
            this.RefreshResourceProgressBars()
        end
        this.UpdateEventRegistry()
    end, 500)
end

local function OnCurrencyCapsChanged()
    if this.HasVisibleCurrencyResources() or this.HasVisibleCappedProgressBars() then
        Enqueue("RefreshCurrencyAndProgress", function()
            this.RefreshProgressBarResourceDiscovery()
            if this.HasVisibleCurrencyResources() then
                this.RefreshCurrencyPanel()
            end
            this.UpdateEventRegistry()
        end, 500)
    end
end

local function OnCapacityChanged()
    Enqueue("RefreshProgress", function()
        this.RefreshResourceProgressBars()
    end, 500)
    if this.HasVisibleCapacityResources() then
        Enqueue("RefreshCurrency", function()
            this.RefreshCurrencyPanel()
        end, 500)
    end
end

------------------------------------------------------------------
-- Event Registry & Management
------------------------------------------------------------------
local eventRegistry = {
    [EVENT_OPEN_BANK]                    = { name = "OpenBank",     condition = ShouldListenOpenBank,     handler = OnBankOpened },
    [EVENT_INVENTORY_SINGLE_SLOT_UPDATE] = {
        name = "SlotUpdate",
        condition = ShouldListenSlotUpdate,
        handler = OnInventorySlotUpdate,
        filters = {
            { name = "Backpack", value = BAG_BACKPACK },
            { name = "Virtual", value = BAG_VIRTUAL },
            { name = "Bank", value = BAG_BANK },
            { name = "SubscriberBank", value = BAG_SUBSCRIBER_BANK },
        },
    },
    [EVENT_CURRENCY_UPDATE]                = { name = "CurrencyUpdate", condition = ShouldListenCurrencyUpdates, handler = OnCurrencyUpdate },
    [EVENT_CURRENCY_CAPS_CHANGED]          = { name = "CurrencyCapsChanged", condition = ShouldListenCurrencyCapUpdates, handler = OnCurrencyCapsChanged },
    [EVENT_INVENTORY_BAG_CAPACITY_CHANGED] = { name = "BagCapacity",  condition = ShouldListenBagCapacity,  handler = OnCapacityChanged },
    [EVENT_INVENTORY_BANK_CAPACITY_CHANGED]= { name = "BankCapacity", condition = ShouldListenBankCapacity, handler = OnCapacityChanged },
}

function this.UpdateEventRegistry()
    local desiredListeners = {}

    local function AddDesiredListener(eventCode, entry, filter)
        local suffix = filter and ("_" .. filter.name) or ""
        local eventId = string.format("%s_Event_%s%s", this.Name, entry.name, suffix)
        desiredListeners[eventId] = {
            eventCode = eventCode,
            handler = entry.handler,
            filter = filter,
        }
    end

    for eventCode, entry in pairs(eventRegistry) do
        if entry.condition() == true then
            if entry.filters then
                for _, filter in ipairs(entry.filters) do
                    AddDesiredListener(eventCode, entry, filter)
                end
            else
                AddDesiredListener(eventCode, entry)
            end
        end
    end

    for eventId, listener in pairs(desiredListeners) do
        if not activeListeners[eventId] then
            EVENT_MANAGER:RegisterForEvent(eventId, listener.eventCode, listener.handler)
            if listener.filter then
                EVENT_MANAGER:AddFilterForEvent(
                    eventId,
                    listener.eventCode,
                    REGISTER_FILTER_BAG_ID,
                    listener.filter.value
                )
            end
            activeListeners[eventId] = listener.eventCode
        end
    end

    for eventId, eventCode in pairs(activeListeners) do
        if not desiredListeners[eventId] then
            EVENT_MANAGER:UnregisterForEvent(eventId, eventCode)
            activeListeners[eventId] = nil
        end
    end
end

EVENT_MANAGER:RegisterForEvent(this.Name .. "_Event_PlayerActivated", EVENT_PLAYER_ACTIVATED, function()
    if this.state and this.state.isLoaded then
        this.BeginCurrencyNotificationSuppression()
    end
end)

function this.InitCutsceneTicker()
    EVENT_MANAGER:RegisterForUpdate(this.Name .. "_HideCheck", 100, function()
        if ZO_CompassFrame then
            local inCutscene = ZO_CompassFrame:IsHidden()
            local isItemEditorOpen = InventoryCompanion_TrackedItemsWindow and (not InventoryCompanion_TrackedItemsWindow:IsHidden())
            local isGroupEditorOpen = InventoryCompanion_GroupsWindow and (not InventoryCompanion_GroupsWindow:IsHidden())
            local isEditorOpen = isItemEditorOpen or isGroupEditorOpen
        
            local isInteractionOpen = this.Utils.IsItemInteractionActive()

            if InventoryCompanion_ItemTrackerFloat then
                local showTracked = (this.accountWide.showTrackedItemsPanel ~= false)
                local shouldShowTracker = (showTracked and not inCutscene) or isEditorOpen or isInteractionOpen
                InventoryCompanion_ItemTrackerFloat:SetHidden(not shouldShowTracker)

                if shouldShowTracker and isInteractionOpen and this.AdjustTrackerPositionForInteraction then
                    this.AdjustTrackerPositionForInteraction()
                elseif not isEditorOpen and not isInteractionOpen and this.RestoreTrackerPosition then
                    this.RestoreTrackerPosition()
                end
            end

            local showCurrencies = this.HasVisibleCurrencyResources()
            local showCapacities = this.HasVisibleCapacityResources()
            local showInfo = showCurrencies or showCapacities
            local shouldShowCurrencyPanel = this.state.isCurrencySettingsOpen or (showInfo and not inCutscene)
            InventoryCompanion_CurrencyFloat:SetHidden(not shouldShowCurrencyPanel)

            this.SetProgressBarsHidden(inCutscene)
        end
    end)
end
