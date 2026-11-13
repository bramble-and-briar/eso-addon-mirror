-- SatchelExchangeStoreUtils.lua: Pure helpers for reading gamepad store state.
-- No side effects; each function equates to a current value when invoked.

local SatchelExchangeStoreUtils = {}

---The ZO_GamepadStoreBuy component that owns the buy list and its keybind strip
---@return table|nil buyComponent
function SatchelExchangeStoreUtils.GetBuyComponent()
    local store = STORE_WINDOW_GAMEPAD
    return store and store.components and store.components[ZO_MODE_STORE_BUY] or nil
end

---Target data of the entry currently hovered in the gamepad buy list
---@return table|nil targetData
function SatchelExchangeStoreUtils.GetSelectedBuyEntry()
    local component = SatchelExchangeStoreUtils.GetBuyComponent()
    local list = component and component.list
    return list and list:GetTargetData() or nil
end

---@return boolean isVendorActive
function SatchelExchangeStoreUtils.IsVendorInteractionActive()
    return GetInteractionType() == INTERACTION_VENDOR
end

---Whether the item link is an openable container (satchel, coffer, geode).
---This is the only kind of item the addon is ever allowed to buy -- it keeps
---a mis-hovered style page or motif from being purchased by the automation.
---@param itemLink string
---@return boolean
function SatchelExchangeStoreUtils.IsContainerItemLink(itemLink)
    local itemType, specializedItemType = GetItemLinkItemType(itemLink)
    -- A style page is a container to the game, but using it learns the style.
    if specializedItemType == SPECIALIZED_ITEMTYPE_CONTAINER_STYLE_PAGE then
        return false
    end
    return itemType == ITEMTYPE_CONTAINER
        or itemType == ITEMTYPE_CONTAINER_STACKABLE
        or itemType == ITEMTYPE_CONTAINER_CURRENCY
end

---Re-resolve a store entry index by item link (indexes could shift between transactions)
---@param itemLink string
---@return integer|nil entryIndex
function SatchelExchangeStoreUtils.FindEntryIndexByItemLink(itemLink)
    for entryIndex = 1, GetNumStoreItems() do
        if GetStoreItemLink(entryIndex) == itemLink then
            return entryIndex
        end
    end
    return nil
end

---Snapshot everything relevant about a store entry for buy checks and logging
---@param entryIndex integer
---@return SatchelExchangeEntryDiagnostics
function SatchelExchangeStoreUtils.GetEntryDiagnostics(entryIndex)
    local _, name, stack, price, _, meetsRequirementsToBuy, _, _, _,
        currencyType1, currencyQuantity1, currencyType2, currencyQuantity2,
        entryType, buyStoreFailure, buyErrorStringId = GetStoreEntryInfo(entryIndex)

    return {
        name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name),
        stack = stack,
        price = price,
        currencyType1 = currencyType1,
        currencyQuantity1 = currencyQuantity1,
        currencyType2 = currencyType2,
        currencyQuantity2 = currencyQuantity2,
        entryType = entryType,
        meetsRequirementsToBuy = meetsRequirementsToBuy,
        buyStoreFailure = buyStoreFailure,
        buyErrorStringId = buyErrorStringId,
        maxBuyable = GetStoreEntryMaxBuyable(entryIndex),
        itemLink = GetStoreItemLink(entryIndex),
    }
end

---Human-readable reason the next purchase would fail, or nil if it should succeed
---@param diagnostics SatchelExchangeEntryDiagnostics
---@return string|nil blockReason
function SatchelExchangeStoreUtils.GetBuyBlockReason(diagnostics)
    if not diagnostics.meetsRequirementsToBuy then
        return ZO_StoreManager_GetRequiredToBuyErrorText(diagnostics.buyStoreFailure, diagnostics.buyErrorStringId)
    end

    if diagnostics.maxBuyable < 1 then
        return "store reports max buyable 0"
    end

    local currencyType = diagnostics.currencyType1
    if currencyType and currencyType ~= CURT_NONE and diagnostics.currencyQuantity1 > 0 then
        local held = GetCurrencyAmount(currencyType, GetCurrencyPlayerStoredLocation(currencyType))
        if diagnostics.currencyQuantity1 > held then
            return string.format("not enough currency (type %d: need %d, have %d)", currencyType, diagnostics.currencyQuantity1, held)
        end
    end

    if diagnostics.price > 0 and diagnostics.price > GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) then
        return "not enough gold"
    end

    if not DoesBagHaveSpaceForItemLink(BAG_BACKPACK, diagnostics.itemLink) then
        return "inventory full"
    end

    return nil
end

---Compact one-line description of an entry for logging
---@param diagnostics SatchelExchangeEntryDiagnostics
---@return string
function SatchelExchangeStoreUtils.FormatEntryDiagnostics(diagnostics)
    return string.format(
        "%s | entryType=%d stack=%d maxBuyable=%d gold=%d curr1=%d x%d curr2=%d x%d meetsReqs=%s failure=%d errId=%d",
        diagnostics.name,
        diagnostics.entryType,
        diagnostics.stack,
        diagnostics.maxBuyable,
        diagnostics.price,
        diagnostics.currencyType1 or -1,
        diagnostics.currencyQuantity1 or 0,
        diagnostics.currencyType2 or -1,
        diagnostics.currencyQuantity2 or 0,
        tostring(diagnostics.meetsRequirementsToBuy),
        diagnostics.buyStoreFailure or -1,
        diagnostics.buyErrorStringId or -1
    )
end

SatchelExchange.StoreUtils = SatchelExchangeStoreUtils
