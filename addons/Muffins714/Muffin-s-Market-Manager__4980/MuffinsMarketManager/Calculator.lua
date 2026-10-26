-- Create a local shortcut for global
local MMM = MuffinsMarketManager

----------------------------------------------------------------------
-- Calculator Core
----------------------------------------------------------------------
-- Listed prices are saved account wide in the lib
local function GetPriceData()
    return LibMuffinsMarketManagerData.SavedVars
end

-- Item key = itemId + traitType + functionalQuality
function MMM.GetItemKey(itemLink)
    if not itemLink or itemLink == "" then return nil end

    local itemId = GetItemLinkItemId(itemLink)
    local traitType = GetItemLinkTraitInfo(itemLink)
    local functionalQuality = GetItemLinkFunctionalQuality(itemLink)

    if not itemId then return nil end

    return string.format("%d_%d_%d", itemId, traitType or 0, functionalQuality or 0)
end

-- Saves the per item price you listed at
function MMM.SaveLastListedPrice(itemLink, perItemPrice)
    local itemKey = MMM.GetItemKey(itemLink)
    if not itemKey then return end
    local priceData = GetPriceData()

    if type(priceData.lastListedPrices) ~= "table" then
        priceData.lastListedPrices = {}
    end

    priceData.lastListedPrices[itemKey] = {
        price = perItemPrice,
        timestamp = GetTimeStamp(),
    }
end

-- Returns the last listed price for an item
function MMM.GetLastListedPrice(itemLink)
    local itemKey = MMM.GetItemKey(itemLink)
    if not itemKey then return nil end
    local priceData = GetPriceData()

    if type(priceData.lastListedPrices) ~= "table" then
        priceData.lastListedPrices = {}
    end

    return priceData.lastListedPrices[itemKey]
end

----------------------------------------------------------------------
-- Calculator UI
----------------------------------------------------------------------
-- Calculator title label
local function GetOrCreateCalculatorTitleLabel(createListingObject, anchorControl)
    if createListingObject.MMMCalTitleLabel then
        return createListingObject.MMMCalTitleLabel
    end

    local profitControl = createListingObject.listingProfitControl
    if not profitControl then
        return nil
    end

    local container = profitControl:GetParent()

    local label = WINDOW_MANAGER:CreateControl(
        "MuffinsMarketManagerCalTitleLabel",
        container,
        CT_LABEL
    )
    label:SetFont("ZoFontGamepad27")
    label:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)
    label:SetColor(ZO_SELECTED_TEXT:UnpackRGBA())

    label:SetDimensions(ZO_GAMEPAD_CONTENT_WIDTH, 30)
    label:SetText(GetString(MMM_CALCULATOR_PER_ITEM))
    label:SetAnchor(TOP, anchorControl, BOTTOM, 0, 40)

    createListingObject.MMMCalTitleLabel = label
    return label
end

----------------------------------------------------------------------
-- Last listed price label
----------------------------------------------------------------------

local function GetOrCreateLastSoldLabel(createListingObject)
    if createListingObject.MMMCalLastSoldLabel then
        return createListingObject.MMMCalLastSoldLabel
    end

    local profitControl = createListingObject.listingProfitControl
    if not profitControl then
        return nil
    end

    local titleLabel = createListingObject.MMMCalTitleLabel
    if not titleLabel then
        return nil
    end

    local container = profitControl:GetParent()

    local label = WINDOW_MANAGER:CreateControl(
        "MuffinsMarketManagerCalLastSoldLabel",
        container,
        CT_LABEL
    )

    label:SetFont("ZoFontGamepad27")
    label:SetModifyTextType(MODIFY_TEXT_TYPE_UPPERCASE)

    label:SetColor(unpack(MMM.DEFAULT_COLORS.sand))
    label:SetDimensions(ZO_GAMEPAD_CONTENT_WIDTH, 30)
    label:SetAnchor(TOP, titleLabel, BOTTOM, 0, 20)

    createListingObject.MMMCalLastSoldLabel = label
    return label
end

----------------------------------------------------------------------
-- Updates the last listed label
----------------------------------------------------------------------
local function UpdateLastSoldLabel(createListingObject, selectedData)
    local settings = MMM.GetSettings()
    if not settings.calculatorEnabled then
        if createListingObject.MMMCalLastSoldLabel then
            createListingObject.MMMCalLastSoldLabel:SetHidden(true)
        end
        if createListingObject.MMMCalTitleLabel then
            createListingObject.MMMCalTitleLabel:SetHidden(true)
        end
        return
    end

    -- SetupListing can run before the controls exist, so retry briefly
    local attempts = 0
    local function tryUpdate()
        attempts = attempts + 1

        local titleLabel = GetOrCreateCalculatorTitleLabel(createListingObject, createListingObject.listingProfitControl)
        local label = GetOrCreateLastSoldLabel(createListingObject)
        if not titleLabel or not label then
            if attempts < 20 then
                zo_callLater(tryUpdate, 16)
            end
            return
        end

        local qty = selectedData and selectedData.stackCount or 1

        label:SetText(string.format("%s %sx%d|r:", GetString(MMM_CALCULATOR_ITEM_LISTED), MMM.HEX_COLOR.BRIGHT_GOLD, qty))
        titleLabel:SetHidden(false)
        label:SetHidden(false)
    end

    zo_callLater(tryUpdate, 0)
end

----------------------------------------------------------------------
-- Per item price calculator
----------------------------------------------------------------------
local function GetOrCreatePriceCalculator(createListingObject)
    if createListingObject.MMMCalPriceSelector then
        return createListingObject.MMMCalPriceSelector
    end

    local profitControl = createListingObject.listingProfitControl
    if not profitControl then
        return nil
    end

    local container = profitControl:GetParent()


    -- Uses ESO's gamepad gold spinner so it feels native
    local selectorControl = WINDOW_MANAGER:CreateControlFromVirtual(
        "MuffinsMarketManagerCalPriceSelectorContainer",
        container,
        "ZO_GamepadGoldSpinnerContainerTemplate"
    )

    -- Spinner position and size
    selectorControl:SetAnchor(BOTTOM, container, BOTTOM, 0, -120)
    selectorControl:SetDimensions(380, 40)

    local selector = ZO_CurrencySelector_Gamepad:New(selectorControl:GetNamedChild("Selector"))
    selector:SetCurrencyType(CURT_MONEY)
    selector:SetClampValues(true)
    selector:SetMaxValue(MAX_PLAYER_CURRENCY)

    local function PushTotalToNativeUI()
        local qty = createListingObject.selectedData and createListingObject.selectedData.stackCount or 1
        local perItem = selector:GetValue()
        local total = perItem * qty
        createListingObject:SetListingPrice(total)
    end

    selector:RegisterCallback("OnValueChanged", PushTotalToNativeUI)

    createListingObject.MMMCalPriceSelector = selector
    createListingObject.MMMCalPriceSelectorControl = selectorControl
    createListingObject.MMMCalPushTotal = PushTotalToNativeUI

    return selector
end

local function UpdatePriceCalculator(createListingObject, selectedData)
    local settings = MMM.GetSettings()
    if not settings.calculatorEnabled then
        if createListingObject.MMMCalPriceSelectorControl then
            createListingObject.MMMCalPriceSelectorControl:SetHidden(true)
        end
        return
    end

    -- Retries until the item link is ready so it doesn't fill 0
    local attempts = 0
    local function tryUpdate()
        attempts = attempts + 1

        local selector = GetOrCreatePriceCalculator(createListingObject)
        if not selector then
            if attempts < 20 then
                zo_callLater(tryUpdate, 16)
            end
            return
        end

        local itemLink = createListingObject.itemBag and createListingObject.itemIndex
            and GetItemLink(createListingObject.itemBag, createListingObject.itemIndex)

        if not itemLink and attempts < 20 then
            zo_callLater(tryUpdate, 16)
            return
        end

        createListingObject.MMMCalPriceSelectorControl:SetHidden(false)

        local lastListed = itemLink and MMM.GetLastListedPrice(itemLink)
        local fillPrice = lastListed and lastListed.price or 0
        selector:SetValue(fillPrice)
        createListingObject.MMMCalPushTotal()
    end

    zo_callLater(tryUpdate, 0)
end

----------------------------------------------------------------------
-- Calculator keybind focus
----------------------------------------------------------------------
local function ToggleCalculatorFocus(createListingObject)
    local selector = createListingObject.MMMCalPriceSelector
    if not selector then return end

    if createListingObject.MMMCalFocused then
        selector:Deactivate()
        createListingObject.MMMCalFocused = false
    else
        selector:Activate()
        createListingObject.MMMCalFocused = true
    end
end

local function BuildCalculatorKeybindDescriptor(createListingObject)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = function()
                return createListingObject.MMMCalFocused and GetString(MMM_CALCULATOR_STOP_EDITING) or
                    GetString(MMM_CALCULATOR_SET_PRICE)
            end,
            keybind = "UI_SHORTCUT_QUATERNARY",
            callback = function()
                ToggleCalculatorFocus(createListingObject)
            end,
        },
    }
end

----------------------------------------------------------------------
-- Gamepad trading house hooks
----------------------------------------------------------------------
--[[
local originalPerformDeferredInit = ZO_GamepadTradingHouse_CreateListing.PerformDeferredInitialization

ZO_GamepadTradingHouse_CreateListing.PerformDeferredInitialization = function(self)
    originalPerformDeferredInit(self)

    -- Build controls once the native listing UI exists
    GetOrCreatePriceCalculator(self)
    GetOrCreateCalculatorTitleLabel(self, self.listingProfitControl)
    GetOrCreateLastSoldLabel(self)

    local settings = MMM.GetSettings()
    if not settings.calculatorEnabled then
        if self.MMMCalPriceSelectorControl then
            self.MMMCalPriceSelectorControl:SetHidden(true)
        end
        if self.MMMCalTitleLabel then
            self.MMMCalTitleLabel:SetHidden(true)
        end
        if self.MMMCalLastSoldLabel then
            self.MMMCalLastSoldLabel:SetHidden(true)
        end
    end

    self.MMMCalKeybindDescriptor = BuildCalculatorKeybindDescriptor(self)
end

local originalShowing = ZO_GamepadTradingHouse_CreateListing.Showing
ZO_GamepadTradingHouse_CreateListing.Showing = function(self)
    originalShowing(self)
    local settings = MMM.GetSettings()
    if self.MMMCalKeybindDescriptor and settings.calculatorEnabled then
        KEYBIND_STRIP:AddKeybindButtonGroup(self.MMMCalKeybindDescriptor)
    end
end

local originalHiding = ZO_GamepadTradingHouse_CreateListing.Hiding
ZO_GamepadTradingHouse_CreateListing.Hiding = function(self)
    if self.MMMCalKeybindDescriptor then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.MMMCalKeybindDescriptor)
    end
    if self.MMMCalPriceSelector and self.MMMCalFocused then
        self.MMMCalPriceSelector:Deactivate()
        self.MMMCalFocused = false
    end
    originalHiding(self)
end

local originalSetupListing = ZO_GamepadTradingHouse_CreateListing.SetupListing
ZO_GamepadTradingHouse_CreateListing.SetupListing = function(self, selectedData, bag, index, listingPrice)
    originalSetupListing(self, selectedData, bag, index, listingPrice)
    UpdateLastSoldLabel(self, selectedData)
    UpdatePriceCalculator(self, selectedData)
end

local originalShowListItemConfirmation = ZO_GamepadTradingHouse_CreateListing.ShowListItemConfirmation
ZO_GamepadTradingHouse_CreateListing.ShowListItemConfirmation = function(self)
    local settings = MMM.GetSettings()
    local itemLink = self.selectedData and self.selectedData.slotIndex
        and GetItemLink(BAG_BACKPACK, self.selectedData.slotIndex)
    local perItemPrice = self.MMMCalPriceSelector and self.MMMCalPriceSelector:GetValue()

    if settings.calculatorEnabled and self.selectedData then
        if itemLink and perItemPrice and perItemPrice > 0 then
            MMM.SaveLastListedPrice(itemLink, perItemPrice)
        end
    end

    originalShowListItemConfirmation(self)
end
]]

-- Build controls once the native listing UI exists
SecurePostHook(ZO_GamepadTradingHouse_CreateListing, "PerformDeferredInitialization", function(self)
    GetOrCreatePriceCalculator(self)
    GetOrCreateCalculatorTitleLabel(self, self.listingProfitControl)
    GetOrCreateLastSoldLabel(self)

    local settings = MMM.GetSettings()
    if not settings.calculatorEnabled then
        if self.MMMCalPriceSelectorControl then
            self.MMMCalPriceSelectorControl:SetHidden(true)
        end
        if self.MMMCalTitleLabel then
            self.MMMCalTitleLabel:SetHidden(true)
        end
        if self.MMMCalLastSoldLabel then
            self.MMMCalLastSoldLabel:SetHidden(true)
        end
    end

    self.MMMCalKeybindDescriptor = BuildCalculatorKeybindDescriptor(self)
end)

-- Adds the calculator keybind after the listing screen shows
SecurePostHook(ZO_GamepadTradingHouse_CreateListing, "Showing", function(self)
    local settings = MMM.GetSettings()
    if self.MMMCalKeybindDescriptor and settings.calculatorEnabled then
        KEYBIND_STRIP:AddKeybindButtonGroup(self.MMMCalKeybindDescriptor)
    end
end)

-- Removes the keybind and stops editing before the listing screen hides
ZO_PreHook(ZO_GamepadTradingHouse_CreateListing, "Hiding", function(self)
    if self.MMMCalKeybindDescriptor then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.MMMCalKeybindDescriptor)
    end
    if self.MMMCalPriceSelector and self.MMMCalFocused then
        self.MMMCalPriceSelector:Deactivate()
        self.MMMCalFocused = false
    end
end)

-- Fills the calculator after the game sets up the listing
SecurePostHook(ZO_GamepadTradingHouse_CreateListing, "SetupListing", function(self, selectedData)
    UpdateLastSoldLabel(self, selectedData)
    UpdatePriceCalculator(self, selectedData)
end)

-- Saves the per item price before the confirm dialog opens
ZO_PreHook(ZO_GamepadTradingHouse_CreateListing, "ShowListItemConfirmation", function(self)
    local settings = MMM.GetSettings()
    local itemLink = self.selectedData and self.selectedData.slotIndex
        and GetItemLink(BAG_BACKPACK, self.selectedData.slotIndex)
    local perItemPrice = self.MMMCalPriceSelector and self.MMMCalPriceSelector:GetValue()

    if settings.calculatorEnabled and self.selectedData then
        if itemLink and perItemPrice and perItemPrice > 0 then
            MMM.SaveLastListedPrice(itemLink, perItemPrice)
        end
    end
end)
