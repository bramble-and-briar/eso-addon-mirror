InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local currencies = {}
local currenciesByType = {}

function this.InitializeCurrencyHelper()
    currencies = {}
    currenciesByType = {}

    for currencyType = CURT_ITERATION_BEGIN, CURT_ITERATION_END do
        if IsCurrencyValid(currencyType) and ShouldShowCurrencyInCurrencyPanel(currencyType) then
            local info =
            {
                currencyType = currencyType,
                name = GetCurrencyName(currencyType, false, false),
                keyboardTexture = GetCurrencyKeyboardIcon(currencyType),
                gamepadTexture = GetCurrencyGamepadIcon(currencyType),
            }

            table.insert(currencies, info)
            currenciesByType[currencyType] = info
        end
    end
end

local function FindCurrency(currencyType)
    return currenciesByType[currencyType]
end

local function GetCurrentInfo(currency)
    if not currency then
        return nil
    end

    local currencyType = currency.currencyType
    local location = GetCurrencyPlayerStoredLocation(currencyType)
    local cap
    if IsCurrencyCapped(currencyType, location) then
        cap = GetMaxPossibleCurrency(currencyType, location)
    end

    return
    {
        currencyType = currencyType,
        name = currency.name,
        keyboardTexture = currency.keyboardTexture,
        gamepadTexture = currency.gamepadTexture,
        location = location,
        locationName = GetString("SI_CURRENCYLOCATION", location),
        amount = GetCurrencyAmount(currencyType, location),
        cap = cap,
        isAccountWide = location == CURRENCY_LOCATION_ACCOUNT,
        canBeStoredInBank = CanCurrencyBeStoredInLocation(currencyType, CURRENCY_LOCATION_BANK),
    }
end

function this.GetCurrencyList()
    local currencyTypes = {}
    for _, currency in ipairs(currencies) do
        table.insert(currencyTypes, currency.currencyType)
    end
    return currencyTypes
end

function this.GetCappedCurrencyList()
    local currencyTypes = {}
    for currencyType = CURT_ITERATION_BEGIN, CURT_ITERATION_END do
        if IsCurrencyValid(currencyType) then
            local location = GetCurrencyPlayerStoredLocation(currencyType)
            if IsCurrencyCapped(currencyType, location) then
                table.insert(currencyTypes, currencyType)
            end
        end
    end
    return currencyTypes
end

function this.GetCappedCurrencyInfo(currencyType)
    if not IsCurrencyValid(currencyType) then
        return nil
    end

    local location = GetCurrencyPlayerStoredLocation(currencyType)
    if not IsCurrencyCapped(currencyType, location) then
        return nil
    end

    return {
        currencyType = currencyType,
        name = GetCurrencyName(currencyType, false, false),
        keyboardTexture = GetCurrencyKeyboardIcon(currencyType),
        gamepadTexture = GetCurrencyGamepadIcon(currencyType),
        location = location,
        amount = GetCurrencyAmount(currencyType, location),
        cap = GetMaxPossibleCurrency(currencyType, location),
    }
end

function this.GetInfo(currencyType)
    return GetCurrentInfo(FindCurrency(currencyType))
end

function this.GetInfoAtLocation(currencyType, location)
    local currency = FindCurrency(currencyType)
    if not currency then
        return nil
    end

    local cap
    if IsCurrencyCapped(currencyType, location) then
        cap = GetMaxPossibleCurrency(currencyType, location)
    end

    return
    {
        currencyType = currencyType,
        name = currency.name,
        keyboardTexture = currency.keyboardTexture,
        gamepadTexture = currency.gamepadTexture,
        location = location,
        locationName = GetString("SI_CURRENCYLOCATION", location),
        amount = GetCurrencyAmount(currencyType, location),
        cap = cap,
        isAccountWide = location == CURRENCY_LOCATION_ACCOUNT,
        canBeStoredInBank = CanCurrencyBeStoredInLocation(currencyType, CURRENCY_LOCATION_BANK),
    }
end

function this.GetTotalInfo(currencyType)
    local currency = FindCurrency(currencyType)
    if not currency then
        return nil
    end

    local currencyType = currency.currencyType
    local playerLocation = GetCurrencyPlayerStoredLocation(currencyType)
    if playerLocation == CURRENCY_LOCATION_ACCOUNT then
        return nil, GetCurrencyAmount(currencyType, CURRENCY_LOCATION_ACCOUNT)
    end

    local characterAmount = GetCurrencyAmount(currencyType, CURRENCY_LOCATION_CHARACTER)
    local bankAmount = 0
    if CanCurrencyBeStoredInLocation(currencyType, CURRENCY_LOCATION_BANK) then
        bankAmount = GetCurrencyAmount(currencyType, CURRENCY_LOCATION_BANK)
    end

    return characterAmount, characterAmount + bankAmount
end

function this.GetCapInfo(currencyType)
    local currency = FindCurrency(currencyType)
    if not currency then
        return nil
    end

    local currencyType = currency.currencyType
    local location = GetCurrencyPlayerStoredLocation(currencyType)
    if not IsCurrencyCapped(currencyType, location) then
        return nil
    end

    local amount = GetCurrencyAmount(currencyType, location)
    local cap = GetMaxPossibleCurrency(currencyType, location)
    return
    {
        amount = amount,
        cap = cap,
        remaining = cap - amount,
        percent = cap > 0 and amount / cap or 0,
    }
end

function this.IsCurrencyNearCap(currencyType, threshold)
    local capInfo = this.GetCapInfo(currencyType)
    if not capInfo then
        return false
    end

    threshold = threshold or 0.9
    return capInfo.percent >= threshold, capInfo
end
