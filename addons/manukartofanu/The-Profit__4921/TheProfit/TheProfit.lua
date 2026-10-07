TheProfit = TheProfit or {}

local TP = TheProfit
local EM = EVENT_MANAGER

TP.name = "TheProfit"
TP.version = "1.0.0"
TP.processors = {}
TP.currentPurchaseKey = nil
TP.purchaseCandidate = nil
TP.listingCandidate = nil
TP.cancelListingCandidate = nil
TP.libReady = false
TP.historyLoadingStarted = false
TP.historyRangeRetries = {}
TP.overallScrollOffset = 0
TP.ensureSelectedVisible = true
TP.activeView = "portfolio"
TP.ledgerScrollOffset = 0
TP.personalActivityKind = "sale"
TP.personalActivityPeriod = "last7"
TP.personalActivityScrollOffset = 0
TP.guildHistoryGuildId = nil
TP.guildHistoryItemQuery = ""
TP.guildHistorySellerQuery = ""
TP.guildHistoryBuyerQuery = ""
TP.guildHistoryScrollOffset = 0
TP.guildHistoryRefreshAvailableAt = 0
TP.guildHistoryFiltersDirty = true
TP.weeklyAnalyticsPeriod = "current"
TP.weeklyAnalyticsScope = "my"
TP.weeklyAnalyticsGuildId = nil
TP.weeklyAnalyticsScrollOffset = 0
TP.weeklyAnalyticsRefreshAvailableAt = 0
TP.stockItemKey = nil
TP.stockItemScrollOffset = 0
TP.stockListingScrollOffset = 0
TP.ensureStockSelectedVisible = true
TP.itemSalesScrollOffset = 0
TP.selectedItemGuildId = nil
TP.guildSelectionDraft = nil
TP.fullGuildHistoryRequested = false
TP.fullGuildHistoryLoaded = false

local DAY = ZO_ONE_DAY_IN_SECONDS or 86400
local MARKET_MAX_AGE = 7 * DAY
local MARKET_MIN_TRADES = 30
local MARKET_TRIM_FRACTION = 0.15
local MAX_TRACKED_ITEMS = 10
local VISIBLE_PORTFOLIO_ROWS = 10
local LEDGER_VISIBLE_ROWS = 17
local PERSONAL_ACTIVITY_VISIBLE_ROWS = 16
local GUILD_HISTORY_VISIBLE_ROWS = 14
local WEEKLY_ANALYTICS_VISIBLE_ROWS = 7
local STOCK_ITEM_VISIBLE_ROWS = 10
local STOCK_LISTING_VISIBLE_ROWS = 7
local ITEM_SALES_VISIBLE_ROWS = 11
local SUMMARY_CACHE_TTL = 60
local ANALYTICS_REFRESH_COOLDOWN_MS = 60 * 1000
local GUILD_HISTORY_REFRESH_COOLDOWN_MS = 60 * 1000
local SALES_SYNC_OVERLAP_SECONDS = 5 * 60
local analyticsLoadGeneration = 0
local analyticsProcessorsPending = {}
local analyticsProcessorSetupInProgress = false
local analyticsLoadIncludesFullHistory = false
local guildHistorySnapshotTask = nil
local weeklyAnalyticsSnapshotTask = nil
local initialSnapshotBuildGeneration = nil
local salesBulkLoadActive = false
local defaults = {
    windowLeft = 180,
    windowTop = 120,
    backgroundOpacity = 94,
    personalSaleColor = { r = 0.91, g = 0.77, b = 0.42, a = 170 / 255 },
    openWithMail = false,
    openWithStore = false,
    selectedItem = nil,
    trackedItems = {},
    trackedItemOrder = {},
    purchases = {},
    sales = {},
    listings = {},
    listingSequence = 0,
    tradingGuilds = {},
    tradingGuildsConfigured = false,
    salesSyncTimeByGuild = {},
}

local strings = {
    en = {
        title = "The Profit",
        tabPortfolio = "Portfolio",
        tabLedger = "Ledger",
        tabPersonalActivity = "My Deals",
        tabGuildHistory = "All Deals",
        tabWeeklyAnalytics = "Stats",
        tabStock = "Stock",
        tabItem = "Price",
        noItem = "No item selected",
        menuTrack = "Track in The Profit",
        menuSelect = "Select in The Profit",
        menuOpen = "Open The Profit",
        menuShowPrice = "Show Price",
        projectedProfit = "PROJECTED ITEM PROFIT",
        returnRate = "ROI",
        forecastPrice = "FORECAST PRICE",
        recentGuild = "GUILD",
        recentEmpty = "No recent sales for this item",
        configureTradingGuilds = "Trading guilds: %d  ·  Configure",
        tradingGuildsTitle = "Trading guilds",
        tradingGuildsHint = "Only selected guilds are loaded from LibHistoire and used for price calculations.",
        tradingGuildsApply = "Apply",
        tradingGuildsCancel = "Cancel",
        itemAllGuilds = "All Guilds",
        itemGuildsEmpty = "Select at least one trading guild in Configure.",
        ledgerPurchaseWhen = "BOUGHT AT",
        ledgerItem = "ITEM",
        ledgerBought = "BOUGHT",
        ledgerSaleWhen = "SOLD AT",
        ledgerSold = "SOLD",
        ledgerEmpty = "No portfolio purchases have been recorded yet.",
        ledgerBoughtTooltip = "Purchased quantity × unit price. A purchase split across several sales is shown on several rows.",
        ledgerSoldTooltip = "Matched sale quantity × unit price. Unsold quantities have no corresponding sale.",
        activityPurchases = "Purchases",
        activitySales = "Sales",
        activityLast7Days = "Last 7 Days",
        activityCurrentWeek = "Current week",
        activityPreviousWeek = "Previous week",
        activityAllTime = "All time",
        activityEmptyPurchases = "No personal purchases in this period.",
        activityEmptySales = "No personal sales in this period.",
        historyAllGuilds = "All guilds",
        historyItemSearch = "Item name",
        historySellerSearch = "Seller",
        historyBuyerSearch = "Buyer",
        historySeller = "SELLER",
        historyBuyer = "BUYER",
        historyRefresh = "Refresh",
        historyWaitingForLibHistoire = "Guild history is not ready yet. Waiting for LibHistoire…",
        historyLoading = "Loading guild history…",
        historyEmpty = "No guild-trade events match these filters.",
        analyticsCurrentWeek = "Current week",
        analyticsPreviousWeek = "Previous week",
        analyticsMy = "My",
        analyticsAll = "All",
        analyticsGuild = "GUILD",
        analyticsCurrent = "CURRENT",
        analyticsPrevious = "PREVIOUS",
        analyticsAllGuilds = "All Guilds",
        analyticsSeller = "SELLER",
        analyticsSales = "SALES, GOLD",
        analyticsLots = "LOTS",
        analyticsRefresh = "Refresh",
        analyticsLoading = "Loading guild history…",
        analyticsEmpty = "No seller activity is available for this week.",
        stockTracked = "STOCK",
        stockListed = "ACTIVE LISTINGS",
        stockUnlisted = "NOT LISTED",
        stockGuild = "GUILD",
        stockQuantity = "QUANTITY",
        stockUnitPrice = "UNIT PRICE",
        stockTotalPrice = "TOTAL PRICE",
        stockRemaining = "TIME LEFT",
        stockAllItemsEmpty = "There are no purchased items with unsold stock.",
        stockListingsEmpty = "This item has no active listings.",
        stockDaysHours = "%dd %dh",
        stockHoursMinutes = "%dh %dm",
        stockMinutes = "%dm",
        appearanceHeader = "Appearance",
        backgroundOpacity = "Window background opacity",
        backgroundOpacityTooltip = "Controls how strongly the world behind The Profit is darkened. Changes apply immediately.",
        personalSaleColor = "Personal sale highlight",
        personalSaleColorTooltip = "Color and opacity used to mark your own sales in Item. At 0% opacity, the row looks like a regular sale.",
        settingsHeader = "Automatic display",
        openWithMail = "Open with mail",
        openWithMailTooltip = "Automatically show The Profit when opening the mailbox.",
        openWithStore = "Open with guild store",
        openWithStoreTooltip = "Automatically show The Profit when entering a guild store.",
        guild = "GUILD",
        selected = "Now tracking %s",
        help1 = "The Profit commands:",
        help2 = "/theprofit — open or close the ledger",
        help3 = "/theprofit track [item link] — select an item",
        missingLink = "Add an item link after /theprofit track",
        removeItem = "Stop Tracking in The Profit",
        portfolioFull = "The portfolio already contains 10 items. Remove one before adding another.",
        overallPortfolio = "PORTFOLIO PROFIT",
        portfolioProfitShare = "of portfolio profit",
        overallItems = "ITEM",
        overallStockShare = "STOCK %",
        overallItemROI = "ROI",
        overallTooltipStockShare = "This item's remaining FIFO purchase cost as a percentage of the total remaining purchase cost across the portfolio.",
        overallTooltipROI = "Projected profit divided by total purchase cost.",
        overallEmpty = "Add up to ten items to build the portfolio.",
    },
    ru = {
        title = "The Profit",
        tabPortfolio = "Портфель",
        tabLedger = "Учёт",
        tabPersonalActivity = "Мои сделки",
        tabGuildHistory = "Все сделки",
        tabWeeklyAnalytics = "Статистика",
        tabStock = "Остатки",
        tabItem = "Цена",
        noItem = "Предмет не выбран",
        menuTrack = "Отслеживать в The Profit",
        menuSelect = "Выбрать в The Profit",
        menuOpen = "Открыть The Profit",
        menuShowPrice = "Показать цену",
        projectedProfit = "ПРОГНОЗНАЯ ПРИБЫЛЬ ПРЕДМЕТА",
        returnRate = "ROI",
        forecastPrice = "РАСЧЁТНАЯ ЦЕНА",
        recentGuild = "ГИЛЬДИЯ",
        recentEmpty = "Свежих продаж этого предмета нет",
        configureTradingGuilds = "Торговые гильдии: %d  ·  Настроить",
        tradingGuildsTitle = "Торговые гильдии",
        tradingGuildsHint = "Только выбранные гильдии загружаются из LibHistoire и участвуют в расчёте цен.",
        tradingGuildsApply = "Применить",
        tradingGuildsCancel = "Отмена",
        itemAllGuilds = "Все гильдии",
        itemGuildsEmpty = "Выберите хотя бы одну торговую гильдию в настройках.",
        ledgerPurchaseWhen = "ПОКУПКА",
        ledgerItem = "ПРЕДМЕТ",
        ledgerBought = "КУПЛЕНО",
        ledgerSaleWhen = "ПРОДАЖА",
        ledgerSold = "ПРОДАНО",
        ledgerEmpty = "Покупок для портфельного учёта пока нет.",
        ledgerBoughtTooltip = "Количество покупки × цена за единицу. Если покупка закрывалась несколькими продажами, она показана несколькими строками.",
        ledgerSoldTooltip = "Сопоставленное количество продажи × цена за единицу. У непроданного остатка соответствующей продажи нет.",
        activityPurchases = "Покупки",
        activitySales = "Продажи",
        activityLast7Days = "Последние 7 дней",
        activityCurrentWeek = "Текущая неделя",
        activityPreviousWeek = "Прошлая неделя",
        activityAllTime = "Всё время",
        activityEmptyPurchases = "Нет личных покупок за этот период.",
        activityEmptySales = "Нет личных продаж за этот период.",
        historyAllGuilds = "Все гильдии",
        historyItemSearch = "Название предмета",
        historySellerSearch = "Продавец",
        historyBuyerSearch = "Покупатель",
        historySeller = "ПРОДАВЕЦ",
        historyBuyer = "ПОКУПАТЕЛЬ",
        historyRefresh = "Обновить",
        historyWaitingForLibHistoire = "История ещё не готова. Ожидаем LibHistoire…",
        historyLoading = "Загрузка истории гильдий…",
        historyEmpty = "Нет событий гильдейской торговли по выбранным фильтрам.",
        analyticsCurrentWeek = "Текущая неделя",
        analyticsPreviousWeek = "Прошлая неделя",
        analyticsMy = "Мои",
        analyticsAll = "Все",
        analyticsGuild = "ГИЛЬДИЯ",
        analyticsCurrent = "ТЕКУЩАЯ",
        analyticsPrevious = "ПРОШЛАЯ",
        analyticsAllGuilds = "Все гильдии",
        analyticsSeller = "ПРОДАВЕЦ",
        analyticsSales = "ПРОДАЖИ, ЗОЛОТО",
        analyticsLots = "ЛОТЫ",
        analyticsRefresh = "Обновить",
        analyticsLoading = "Загрузка истории гильдий…",
        analyticsEmpty = "За эту неделю нет доступных продаж продавцов.",
        stockTracked = "ОСТАТОК",
        stockListed = "В АКТИВНЫХ ЛОТАХ",
        stockUnlisted = "НЕ ВЫСТАВЛЕНО",
        stockGuild = "ГИЛЬДИЯ",
        stockQuantity = "КОЛИЧЕСТВО",
        stockUnitPrice = "ЦЕНА ЗА ШТ.",
        stockTotalPrice = "ЦЕНА ЛОТА",
        stockRemaining = "ОСТАЛОСЬ",
        stockAllItemsEmpty = "Нет закупленных предметов с непроданным остатком.",
        stockListingsEmpty = "У этого предмета нет активных лотов.",
        stockDaysHours = "%dд %dч",
        stockHoursMinutes = "%dч %dм",
        stockMinutes = "%dм",
        appearanceHeader = "Внешний вид",
        backgroundOpacity = "Непрозрачность фона окна",
        backgroundOpacityTooltip = "Определяет, насколько сильно затемняется мир за окном The Profit. Изменение применяется сразу.",
        personalSaleColor = "Подсветка личных продаж",
        personalSaleColorTooltip = "Цвет и прозрачность подсветки ваших продаж в карточке предмета. При прозрачности 0% строка выглядит как обычная продажа.",
        settingsHeader = "Автоматическое открытие",
        openWithMail = "Открывать с почтой",
        openWithMailTooltip = "Автоматически показывать The Profit при открытии почтового ящика.",
        openWithStore = "Открывать с гильдейским магазином",
        openWithStoreTooltip = "Автоматически показывать The Profit при входе в гильдейский магазин.",
        guild = "ГИЛЬДИЯ",
        selected = "Теперь отслеживается %s",
        help1 = "Команды The Profit:",
        help2 = "/theprofit — открыть или закрыть окно",
        help3 = "/theprofit track [ссылка на предмет] — выбрать предмет",
        missingLink = "Добавьте ссылку на предмет после /theprofit track",
        removeItem = "Прекратить отслеживание в The Profit",
        portfolioFull = "В портфеле уже 10 позиций. Уберите одну перед добавлением новой.",
        overallPortfolio = "ПРИБЫЛЬ ПОРТФЕЛЯ",
        portfolioProfitShare = "от прибыли портфеля",
        overallItems = "НАИМЕНОВАНИЕ",
        overallStockShare = "ЗАПАС %",
        overallItemROI = "ROI",
        overallTooltipStockShare = "Доля FIFO-себестоимости непроданного остатка позиции в общей себестоимости непроданного остатка портфеля.",
        overallTooltipROI = "Прогнозная прибыль, делённая на общую стоимость закупок.",
        overallEmpty = "Добавьте до десяти позиций, чтобы собрать портфель.",
    },
}

local function GetLanguage()
    return string.lower(GetCVar("language.2") or "en") == "ru" and "ru" or "en"
end

function TP.T(key)
    local language = GetLanguage()
    return strings[language][key] or strings.en[key] or key
end

ZO_CreateStringId("SI_BINDING_NAME_THEPROFIT_CATEGORY", "The Profit")
ZO_CreateStringId("SI_BINDING_NAME_THEPROFIT_TOGGLE", "The Profit: Toggle ledger")

local function IsItemLink(itemLink)
    return type(itemLink) == "string" and itemLink:find("|H%d:item:") ~= nil
end

local function SafeId64ToString(value)
    if value == nil then return nil end
    if type(value) == "string" then return value end
    if Id64ToString then
        local succeeded, result = pcall(Id64ToString, value)
        if succeeded and result then return result end
    end
    return tostring(value)
end

function TP.NormalizeItemLink(itemLink)
    if not IsItemLink(itemLink) then return nil end

    local normalized = itemLink:gsub("|H%d:item:", "|H0:item:", 1)
    normalized = normalized:gsub("|h.-|h$", "|h|h")

    -- One field in modern links is volatile between otherwise identical links.
    -- Normalizes the volatile field so identical items share one key.
    local prefix = normalized:match("|H%d:item:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:%d+:")
    local suffix = normalized:match(":%d+:%d+:%d+:%d+|h|h")
    if prefix and suffix then
        normalized = prefix .. "0" .. suffix
    end

    return normalized
end

function TP.GetItemKey(itemLink)
    return TP.NormalizeItemLink(itemLink)
end

local function FormatPlainGold(value)
    return ZO_CommaDelimitNumber(math.floor(tonumber(value) or 0))
end

function TP.FormatAge(timestamp)
    local age = math.max(0, GetTimeStamp() - (tonumber(timestamp) or GetTimeStamp()))
    return ZO_FormatDurationAgo(age)
end

function TP.ShowHeaderTooltip(control, textKey)
    if not control or not textKey then return end
    InitializeTooltip(InformationTooltip, control, BOTTOM, 0, 0)
    SetTooltipText(InformationTooltip, TP.T(textKey))
end

function TP.HideHeaderTooltip()
    ClearTooltip(InformationTooltip)
end

local function GetSelectedKey()
    return TP.SV and TP.SV.selectedItem and TP.SV.selectedItem.key
end

local function MatchesSelectedItem(itemLink)
    local selectedKey = GetSelectedKey()
    return selectedKey ~= nil and TP.GetItemKey(itemLink) == selectedKey
end

local function GetTrackedCount()
    return TP.SV and TP.SV.trackedItemOrder and #TP.SV.trackedItemOrder or 0
end

local function GetAvailableTradingGuilds()
    local guilds = {}
    for index = 1, GetNumGuilds() do
        local guildId = GetGuildId(index)
        local guildName = GetGuildName(guildId)
        if guildId and guildName ~= "" then
            guilds[#guilds + 1] = { id = guildId, name = guildName }
        end
    end
    return guilds
end

local function IsTradingGuildSelected(guildId)
    return guildId ~= nil
        and TP.SV ~= nil
        and TP.SV.tradingGuilds ~= nil
        and TP.SV.tradingGuilds[tostring(guildId)] == true
end

local function GetSelectedTradingGuilds()
    local selected = {}
    for _, guild in ipairs(GetAvailableTradingGuilds()) do
        if IsTradingGuildSelected(guild.id) then selected[#selected + 1] = guild end
    end
    return selected
end

local function InitializeTradingGuildSelection()
    local available = GetAvailableTradingGuilds()
    local clean = {}
    local configured = TP.SV.tradingGuildsConfigured == true
    local saved = TP.SV.tradingGuilds or {}
    if #available == 0 and not configured then
        TP.SV.tradingGuilds = clean
        return
    end
    for _, guild in ipairs(available) do
        local key = tostring(guild.id)
        if not configured or saved[key] == true then clean[key] = true end
    end
    TP.SV.tradingGuilds = clean
    TP.SV.tradingGuildsConfigured = true
end

local function IsTrackedKey(itemKey)
    return itemKey ~= nil and TP.SV and TP.SV.trackedItems and TP.SV.trackedItems[itemKey] ~= nil
end

local function MatchesTrackedItem(itemLink)
    return IsTrackedKey(TP.GetItemKey(itemLink))
end

local function GetTrackedItemIndex(itemKey)
    for index, key in ipairs(TP.SV.trackedItemOrder or {}) do
        if key == itemKey then return index end
    end
    return nil
end

local function GetAlphabeticalTrackedItemKeys()
    local keys = {}
    for _, itemKey in ipairs(TP.SV.trackedItemOrder or {}) do
        if TP.SV.trackedItems[itemKey] then keys[#keys + 1] = itemKey end
    end
    table.sort(keys, function(leftKey, rightKey)
        local left = TP.SV.trackedItems[leftKey]
        local right = TP.SV.trackedItems[rightKey]
        local leftName = zo_strlower((left and (left.name or left.link)) or "")
        local rightName = zo_strlower((right and (right.name or right.link)) or "")
        if leftName == rightName then return tostring(leftKey) < tostring(rightKey) end
        return leftName < rightName
    end)
    return keys
end

local function GetItemKeyIndex(keys, itemKey)
    for index, key in ipairs(keys or {}) do
        if key == itemKey then return index end
    end
    return nil
end

local TRANSACTION_FIELDS = {
    "id",
    "itemKey",
    "itemLink",
    "quantity",
    "price",
    "seller",
    "buyer",
    "guildId",
    "guildName",
    "timestamp",
    "resolvedAt",
    "kind",
    "status",
    "listingFee",
    "tax",
    "guildTax",
}

local function CopyFlatTransaction(source)
    local copy = {}
    if type(source) ~= "table" then return copy end

    for _, field in ipairs(TRANSACTION_FIELDS) do
        local value = source[field]
        local valueType = type(value)
        if valueType == "string" or valueType == "number" or valueType == "boolean" then
            copy[field] = value
        end
    end
    return copy
end

local function SanitizeSavedTransactions(records)
    local clean = {}
    if type(records) ~= "table" then return clean end

    for key, record in pairs(records) do
        if (type(key) == "string" or type(key) == "number") and type(record) == "table" then
            local flat = CopyFlatTransaction(record)
            if flat.itemKey and flat.timestamp and flat.kind then
                clean[tostring(key)] = flat
            end
        end
    end
    return clean
end

local LISTING_FIELDS = {
    "id",
    "serverId",
    "itemKey",
    "itemLink",
    "itemName",
    "icon",
    "quantity",
    "price",
    "unitPrice",
    "guildId",
    "guildName",
    "timestamp",
    "createdAt",
    "confirmedAt",
    "observedAt",
    "expiresAt",
    "missingAt",
    "resolvedAt",
    "kind",
    "status",
    "listingFee",
    "saleId",
    "source",
}

local function CopyFlatListing(source)
    local copy = {}
    if type(source) ~= "table" then return copy end

    for _, field in ipairs(LISTING_FIELDS) do
        local value = source[field]
        local valueType = type(value)
        if valueType == "string" or valueType == "number" or valueType == "boolean" then
            copy[field] = value
        end
    end
    return copy
end

local function SanitizeSavedListings(records)
    local clean = {}
    if type(records) ~= "table" then return clean end

    for key, record in pairs(records) do
        if (type(key) == "string" or type(key) == "number") and type(record) == "table" then
            local flat = CopyFlatListing(record)
            if flat.itemKey and (flat.createdAt or flat.timestamp) and flat.kind == "listing" then
                flat.id = tostring(flat.id or key)
                flat.createdAt = tonumber(flat.createdAt or flat.timestamp) or GetTimeStamp()
                flat.timestamp = tonumber(flat.timestamp or flat.createdAt) or flat.createdAt
                clean[tostring(key)] = flat
            end
        end
    end
    return clean
end

local function CreateRuntimeData()
    return {
        purchasesByItem = {},
        salesByItem = {},
        marketSalesByItem = {},
        marketSaleKeys = {},
        guildHistorySales = {},
        guildHistorySaleKeys = {},
        guildHistorySnapshot = nil,
        weeklyAnalyticsCache = nil,
        personalActivityCache = {},
        summaryCache = {},
        overallCache = nil,
        marketSalesPrunedGeneration = nil,
    }
end

local function AddIndexedRecord(index, key, record)
    if not index or type(record) ~= "table" or not record.itemKey then return end
    local bucket = index[record.itemKey]
    if not bucket then
        bucket = {}
        index[record.itemKey] = bucket
    end
    bucket[tostring(key)] = record
end

local function InvalidateItemSummary(itemKey)
    if not TP.runtime then return end
    if itemKey then TP.runtime.summaryCache[itemKey] = nil end
    TP.runtime.overallCache = nil
end

local function InvalidateAllSummaries()
    if not TP.runtime then return end
    TP.runtime.summaryCache = {}
    TP.runtime.overallCache = nil
end

local function InvalidatePersonalActivity(kind)
    if not TP.runtime or not TP.runtime.personalActivityCache then return end
    TP.runtime.personalActivityCache[kind] = nil
end

local function RebuildRuntimeIndexes()
    TP.runtime = CreateRuntimeData()
    for key, purchase in pairs(TP.SV.purchases or {}) do
        AddIndexedRecord(TP.runtime.purchasesByItem, key, purchase)
    end
    for key, sale in pairs(TP.SV.sales or {}) do
        AddIndexedRecord(TP.runtime.salesByItem, key, sale)
    end
end

local function SaleFingerprint(sale)
    return table.concat({
        tostring(sale.itemKey or ""),
        tostring(sale.guildId or 0),
        tostring(sale.timestamp or 0),
        tostring(sale.quantity or 0),
        tostring(sale.price or 0),
        tostring(sale.buyer or ""),
    }, "|")
end

local function RemoveLegacyDuplicateSales()
    if TP.SV.salesIdVersion == 1 then return 0 end

    local shortIdSales = {}
    for _, sale in pairs(TP.SV.sales) do
        local numericId = tonumber(sale.id)
        if numericId and numericId <= 4294967295 then
            shortIdSales[SaleFingerprint(sale)] = true
        end
    end

    local removed = 0
    for key, sale in pairs(TP.SV.sales) do
        local numericId = tonumber(sale.id)
        if numericId and numericId > 4294967295 and shortIdSales[SaleFingerprint(sale)] then
            TP.SV.sales[key] = nil
            removed = removed + 1
        end
    end
    TP.SV.salesIdVersion = 1
    return removed
end

local function RequestPrioritySave()
    if ADDON_MANAGER and ADDON_MANAGER.RequestAddOnSavedVariablesPrioritySave then
        ADDON_MANAGER:RequestAddOnSavedVariablesPrioritySave(TP.name)
    end
end

function TP.SetTrackedItem(itemLink)
    if not IsItemLink(itemLink) then return false end

    local key = TP.GetItemKey(itemLink)
    if not key then return false end

    local oldKey = GetSelectedKey()
    local item = TP.SV.trackedItems[key]
    local isNew = item == nil
    if isNew and GetTrackedCount() >= MAX_TRACKED_ITEMS then
        d("|cE7C56AThe Profit:|r " .. TP.T("portfolioFull"))
        return false
    end

    item = item or {}
    item.key = key
    item.link = itemLink
    item.name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(itemLink))
    item.icon = GetItemLinkIcon(itemLink)
    TP.SV.trackedItems[key] = item
    if isNew then
        TP.SV.trackedItemOrder[#TP.SV.trackedItemOrder + 1] = key
        InvalidateAllSummaries()
    end
    TP.SV.selectedItem = item
    TP.ensureSelectedVisible = true
    TP.itemSalesScrollOffset = 0

    if isNew then
        TP.historyRangeRetries = {}
        if TP.libReady then TP.RestartSalesProcessors() end
    end

    if oldKey ~= key then
        TP.purchaseCandidate = nil
        TP.currentPurchaseKey = nil
    end

    TP.RefreshUI()
    RequestPrioritySave()
    d(string.format("|cE7C56AThe Profit:|r " .. TP.T("selected"), itemLink))
    return true
end

function TP.SetActiveItem(itemKey)
    local item = TP.SV and TP.SV.trackedItems and TP.SV.trackedItems[itemKey]
    if not item then return false end
    if GetSelectedKey() ~= itemKey then
        TP.SV.selectedItem = item
        TP.ensureSelectedVisible = true
        TP.itemSalesScrollOffset = 0
        RequestPrioritySave()
    end
    TP.RefreshUI()
    return true
end

function TP.RemoveSelectedItem()
    local key = GetSelectedKey()
    local index = key and GetTrackedItemIndex(key)
    if not index then return end

    table.remove(TP.SV.trackedItemOrder, index)
    TP.SV.trackedItems[key] = nil
    local replacementKey = TP.SV.trackedItemOrder[math.min(index, #TP.SV.trackedItemOrder)]
    TP.SV.selectedItem = replacementKey and TP.SV.trackedItems[replacementKey] or nil
    TP.ensureSelectedVisible = true
    TP.itemSalesScrollOffset = 0
    TP.purchaseCandidate = nil
    TP.currentPurchaseKey = nil
    InvalidateAllSummaries()
    RequestPrioritySave()
    TP.RefreshUI()
end

local function CalculateROI(profit, investment)
    if not investment or investment <= 0 or profit == nil then return nil end
    return profit / investment * 100
end

local function GetSaleFees(grossPrice)
    local listingFee, tradingHouseCut = GetTradingHousePostPriceInfo(math.max(0, math.floor(grossPrice or 0)))
    return listingFee or 0, tradingHouseCut or 0
end

local function FormatPercent(value)
    if value == nil then return "—" end
    return string.format("%+.1f%%", value)
end

local function CalculateMarketAnalytics(itemKey)
    local estimate = {
        available = false,
        sampleTrades = 0,
    }
    itemKey = itemKey or GetSelectedKey()
    if not itemKey then return estimate, nil end

    local now = GetTimeStamp()
    local records = {}
    local dailyVolume = 0
    local recentQuantity, recentValue = 0, 0
    local previousQuantity, previousValue = 0, 0
    local indexedSales = TP.runtime and TP.runtime.marketSalesByItem[itemKey]
    local marketSales = indexedSales or {}
    for _, sale in pairs(marketSales) do
        local quantity = tonumber(sale.quantity) or 0
        local price = tonumber(sale.price) or 0
        local timestamp = tonumber(sale.timestamp) or 0
        local age = now - timestamp
        if quantity > 0 and price > 0 and age >= 0 and age <= MARKET_MAX_AGE then
            records[#records + 1] = {
                quantity = quantity,
                unitPrice = price / quantity,
                timestamp = timestamp,
            }
            if age <= DAY then
                dailyVolume = dailyVolume + quantity
                recentQuantity = recentQuantity + quantity
                recentValue = recentValue + price
            elseif age <= 4 * DAY then
                previousQuantity = previousQuantity + quantity
                previousValue = previousValue + price
            end
        end
    end

    local trend
    if recentQuantity > 0 and previousQuantity > 0 then
        local recentPrice = recentValue / recentQuantity
        local previousPrice = previousValue / previousQuantity
        if previousPrice > 0 then trend = (recentPrice / previousPrice - 1) * 100 end
    end

    if dailyVolume <= 0 then return estimate, trend end

    table.sort(records, function(a, b) return a.timestamp > b.timestamp end)
    local targetQuantity = math.max(1, dailyVolume / 4)
    local sample = {}
    local sampleQuantity = 0
    for _, record in ipairs(records) do
        sample[#sample + 1] = record
        sampleQuantity = sampleQuantity + record.quantity
        if sampleQuantity >= targetQuantity and #sample >= MARKET_MIN_TRADES then break end
    end

    estimate.sampleTrades = #sample
    if #sample < MARKET_MIN_TRADES then return estimate, trend end

    table.sort(sample, function(a, b) return a.unitPrice < b.unitPrice end)
    local trimQuantity = sampleQuantity * MARKET_TRIM_FRACTION
    local remainingLowTrim = trimQuantity
    for _, record in ipairs(sample) do
        local removed = math.min(record.quantity, remainingLowTrim)
        record.includedQuantity = record.quantity - removed
        remainingLowTrim = remainingLowTrim - removed
    end

    local remainingHighTrim = trimQuantity
    for index = #sample, 1, -1 do
        local record = sample[index]
        local includedQuantity = record.includedQuantity or record.quantity
        local removed = math.min(includedQuantity, remainingHighTrim)
        record.includedQuantity = includedQuantity - removed
        remainingHighTrim = remainingHighTrim - removed
    end

    local totalWeight = 0
    local weightedPrice = 0
    for _, record in ipairs(sample) do
        local includedQuantity = record.includedQuantity or 0
        if includedQuantity > 0 then
            totalWeight = totalWeight + includedQuantity
            weightedPrice = weightedPrice + record.unitPrice * includedQuantity
        end
    end
    if totalWeight <= 0 then return estimate, trend end

    local mean = weightedPrice / totalWeight
    local variance = 0
    for _, record in ipairs(sample) do
        local includedQuantity = record.includedQuantity or 0
        if includedQuantity > 0 then
            local difference = record.unitPrice - mean
            variance = variance + includedQuantity * difference * difference
        end
    end
    local deviation = math.sqrt(variance / totalWeight)

    estimate.available = true
    estimate.trimmedMean = mean
    estimate.deviation = deviation
    estimate.forecastUnitPrice = math.max(0, mean - deviation)
    return estimate, trend
end

local function SortNewestTransactionFirst(a, b)
    local aTimestamp = tonumber(a.timestamp) or 0
    local bTimestamp = tonumber(b.timestamp) or 0
    if aTimestamp ~= bTimestamp then return aTimestamp > bTimestamp end
    return tostring(a.sortKey or "") > tostring(b.sortKey or "")
end

local function SortOldestTransactionFirst(a, b)
    local aTimestamp = tonumber(a.timestamp) or 0
    local bTimestamp = tonumber(b.timestamp) or 0
    if aTimestamp ~= bTimestamp then return aTimestamp < bTimestamp end
    return tostring(a.sortKey or "") < tostring(b.sortKey or "")
end

local function MatchRecentSalesToPurchases(itemKey, purchaseLots, saleRecords)
    table.sort(purchaseLots, SortNewestTransactionFirst)
    table.sort(saleRecords, SortNewestTransactionFirst)

    local result = {
        soldQuantity = 0,
        grossSales = 0,
        tax = 0,
        listingFees = 0,
        matchedSales = {},
    }
    local purchaseIndex = 1

    for _, sale in ipairs(saleRecords) do
        local saleTimestamp = tonumber(sale.timestamp) or 0
        while purchaseIndex <= #purchaseLots
            and (tonumber(purchaseLots[purchaseIndex].timestamp) or 0) > saleTimestamp do
            -- A purchase made after this sale cannot be discharged by it. Because
            -- sales are processed newest-first, it cannot match any earlier sale either.
            purchaseIndex = purchaseIndex + 1
        end

        local saleQuantity = math.max(0, tonumber(sale.quantity) or 0)
        local matchedQuantity = 0
        while saleQuantity > 0 and purchaseIndex <= #purchaseLots do
            local purchase = purchaseLots[purchaseIndex]
            local available = math.max(0, tonumber(purchase.remaining) or 0)
            if available <= 0 then
                purchaseIndex = purchaseIndex + 1
            else
                local quantity = math.min(saleQuantity, available)
                matchedQuantity = matchedQuantity + quantity
                saleQuantity = saleQuantity - quantity
                purchase.remaining = available - quantity
                if purchase.remaining <= 0 then purchaseIndex = purchaseIndex + 1 end
            end
        end

        if matchedQuantity > 0 then
            local recordedQuantity = math.max(1, tonumber(sale.quantity) or 0)
            local matchedRatio = matchedQuantity / recordedQuantity
            local salePrice = tonumber(sale.price) or 0
            local listingFee = sale.listingFee
            if listingFee == nil then listingFee = GetSaleFees(salePrice) end

            result.soldQuantity = result.soldQuantity + matchedQuantity
            result.grossSales = result.grossSales + salePrice * matchedRatio
            result.tax = result.tax + (tonumber(sale.tax) or 0) * matchedRatio
            result.listingFees = result.listingFees + (tonumber(listingFee) or 0) * matchedRatio
            result.matchedSales[#result.matchedSales + 1] = {
                itemKey = itemKey,
                quantity = matchedQuantity,
                timestamp = saleTimestamp,
                guildId = sale.guildId,
            }
        end
    end

    return result
end

local function CalculateRemainingFifoCost(purchaseLots, saleRecords)
    table.sort(purchaseLots, SortOldestTransactionFirst)
    table.sort(saleRecords, SortOldestTransactionFirst)
    local purchaseIndex = 1
    for _, sale in ipairs(saleRecords) do
        local remainingSale = math.max(0, tonumber(sale.quantity) or 0)
        while remainingSale > 0 and purchaseIndex <= #purchaseLots do
            local purchase = purchaseLots[purchaseIndex]
            local remainingPurchase = math.max(0, tonumber(purchase.remaining) or 0)
            if remainingPurchase <= 0 then
                purchaseIndex = purchaseIndex + 1
            elseif (tonumber(purchase.timestamp) or 0) > (tonumber(sale.timestamp) or 0) then
                break
            else
                local matched = math.min(remainingSale, remainingPurchase)
                remainingSale = remainingSale - matched
                purchase.remaining = remainingPurchase - matched
                if purchase.remaining <= 0 then purchaseIndex = purchaseIndex + 1 end
            end
        end
    end

    local cost = 0
    for _, purchase in ipairs(purchaseLots) do
        cost = cost
            + math.max(0, tonumber(purchase.remaining) or 0) * math.max(0, tonumber(purchase.unitPrice) or 0)
    end
    return cost
end

function TP.CalculateSummary(itemKey)
    local result = {
        boughtQuantity = 0,
        purchaseTotal = 0,
        soldQuantity = 0,
        grossSales = 0,
        tax = 0,
        listingFees = 0,
        uncertain = 0,
    }

    itemKey = itemKey or GetSelectedKey()
    if not itemKey then
        result.netSales = 0
        result.profit = 0
        result.stock = 0
        result.market = CalculateMarketAnalytics(itemKey)
        return result
    end

    local cached = TP.runtime and TP.runtime.summaryCache[itemKey]
    if cached and GetTimeStamp() - cached.timestamp < SUMMARY_CACHE_TTL then return cached.value end

    local purchaseLots = {}
    local fifoPurchaseLots = {}
    local indexedPurchases = TP.runtime and TP.runtime.purchasesByItem[itemKey] or {}
    for purchaseKey, purchase in pairs(indexedPurchases) do
        if purchase.status ~= "failed" then
            local quantity = math.max(0, tonumber(purchase.quantity) or 0)
            result.boughtQuantity = result.boughtQuantity + quantity
            result.purchaseTotal = result.purchaseTotal + (tonumber(purchase.price) or 0)
            if quantity > 0 then
                local purchaseLot = {
                    timestamp = purchase.timestamp,
                    remaining = quantity,
                    unitPrice = (tonumber(purchase.price) or 0) / quantity,
                    sortKey = purchase.id or purchaseKey,
                }
                purchaseLots[#purchaseLots + 1] = purchaseLot
                fifoPurchaseLots[#fifoPurchaseLots + 1] = {
                    timestamp = purchaseLot.timestamp,
                    remaining = purchaseLot.remaining,
                    unitPrice = purchaseLot.unitPrice,
                    sortKey = purchaseLot.sortKey,
                }
            end
            if purchase.status ~= "confirmed" then
                result.uncertain = result.uncertain + 1
            end
        end
    end

    local saleRecords = {}
    local fifoSaleRecords = {}
    local indexedSales = TP.runtime and TP.runtime.salesByItem[itemKey] or {}
    for saleKey, sale in pairs(indexedSales) do
        local saleRecord = {
            timestamp = sale.timestamp,
            quantity = sale.quantity,
            price = sale.price,
            tax = sale.tax,
            listingFee = sale.listingFee,
            guildId = sale.guildId,
            sortKey = sale.id or saleKey,
        }
        saleRecords[#saleRecords + 1] = saleRecord
        fifoSaleRecords[#fifoSaleRecords + 1] = {
            timestamp = saleRecord.timestamp,
            quantity = saleRecord.quantity,
            sortKey = saleRecord.sortKey,
        }
    end

    local matchedSales = MatchRecentSalesToPurchases(itemKey, purchaseLots, saleRecords)
    result.soldQuantity = matchedSales.soldQuantity
    result.grossSales = matchedSales.grossSales
    result.tax = matchedSales.tax
    result.listingFees = matchedSales.listingFees

    result.netSales = result.grossSales - result.tax - result.listingFees
    result.profit = result.netSales - result.purchaseTotal
    result.stock = result.boughtQuantity - result.soldQuantity
    result.currentROI = CalculateROI(result.profit, result.purchaseTotal)
    result.market = CalculateMarketAnalytics(itemKey)

    result.averagePurchasePrice = result.boughtQuantity > 0 and result.purchaseTotal / result.boughtQuantity or nil
    result.stockCost = CalculateRemainingFifoCost(fifoPurchaseLots, fifoSaleRecords)

    if result.stock <= 0 then
        result.projectedStockGross = 0
        result.projectedStockNet = 0
        result.projectedProfit = result.profit
    elseif result.market.available then
        result.projectedStockGross = math.floor(result.stock * result.market.forecastUnitPrice)
        local projectedListingFee, projectedCut = GetSaleFees(result.projectedStockGross)
        result.projectedStockNet = result.projectedStockGross - projectedListingFee - projectedCut
        result.projectedProfit = result.profit + result.projectedStockNet
    end
    result.projectedROI = CalculateROI(result.projectedProfit, result.purchaseTotal)

    if TP.runtime then
        TP.runtime.summaryCache[itemKey] = { value = result, timestamp = GetTimeStamp() }
    end
    return result
end

function TP.CalculateOverall()
    local cached = TP.runtime and TP.runtime.overallCache
    if cached and GetTimeStamp() - cached.timestamp < SUMMARY_CACHE_TTL then return cached.value end

    local result = {
        items = {},
        purchaseTotal = 0,
        stockCost = 0,
        projectedProfit = 0,
    }

    for _, itemKey in ipairs(TP.SV.trackedItemOrder or {}) do
        local item = TP.SV.trackedItems[itemKey]
        if item then
            local summary = TP.CalculateSummary(itemKey)
            local row = {
                key = itemKey,
                item = item,
                summary = summary,
            }
            result.items[#result.items + 1] = row
            result.purchaseTotal = result.purchaseTotal + (summary.purchaseTotal or 0)
            result.stockCost = result.stockCost + (summary.stockCost or 0)
            result.projectedProfit = result.projectedProfit + (summary.projectedProfit or summary.profit or 0)
        end
    end

    result.projectedROI = CalculateROI(result.projectedProfit, result.purchaseTotal)
    if TP.runtime then TP.runtime.overallCache = { value = result, timestamp = GetTimeStamp() } end
    return result
end


local function SetLabelText(name, value)
    local control = TP.window and TP.window:GetNamedChild(name)
    if control then control:SetText(value) end
end

local function SetProfitControlColor(control, value)
    if not control then return end
    if value == nil then
        control:SetColor(0.65, 0.66, 0.7, 1)
    elseif value > 0 then
        control:SetColor(0.35, 0.9, 0.45, 1)
    elseif value < 0 then
        control:SetColor(0.95, 0.35, 0.32, 1)
    else
        control:SetColor(0.9, 0.78, 0.42, 1)
    end
end

local function SetProfitColor(controlName, value)
    SetProfitControlColor(TP.window and TP.window:GetNamedChild(controlName), value)
end

local function ColorizeProfitText(text, value)
    local color
    if value == nil then
        color = "A6A8B3"
    elseif value > 0 then
        color = "59E673"
    elseif value < 0 then
        color = "F25952"
    else
        color = "E6C76B"
    end
    return "|c" .. color .. tostring(text or "") .. "|r"
end

local function ColorizeCardCaption(text)
    return "|c9B9FA9" .. tostring(text or "") .. "|r"
end

local function SetViewVisibility()
    if not TP.window then return end
    local view = TP.activeView or "portfolio"
    local showingPortfolio = view == "portfolio"
    local portfolio = TP.window:GetNamedChild("Overall")
    if portfolio then portfolio:SetHidden(not showingPortfolio) end

    local ledger = TP.window:GetNamedChild("LedgerView")
    if ledger then ledger:SetHidden(view ~= "ledger") end
    local personalActivity = TP.window:GetNamedChild("PersonalActivityView")
    if personalActivity then personalActivity:SetHidden(view ~= "personalActivity") end
    local guildHistory = TP.window:GetNamedChild("GuildHistoryView")
    if guildHistory then guildHistory:SetHidden(view ~= "guildHistory") end
    local weeklyAnalytics = TP.window:GetNamedChild("WeeklyAnalyticsView")
    if weeklyAnalytics then weeklyAnalytics:SetHidden(view ~= "weeklyAnalytics") end
    local stock = TP.window:GetNamedChild("StockView")
    if stock then stock:SetHidden(view ~= "stock") end
    local itemView = TP.window:GetNamedChild("ItemView")
    local tradingGuildDialog = TP.window:GetNamedChild("TradingGuildDialog")
    local tradingGuildDialogOpen = tradingGuildDialog and not tradingGuildDialog:IsHidden()
    if itemView then itemView:SetHidden(view ~= "item" or tradingGuildDialogOpen) end

    local tabs = {
        PortfolioTab = "portfolio",
        LedgerTab = "ledger",
        PersonalActivityTab = "personalActivity",
        GuildHistoryTab = "guildHistory",
        WeeklyAnalyticsTab = "weeklyAnalytics",
        StockTab = "stock",
        ItemTab = "item",
    }
    for name, tabView in pairs(tabs) do
        local button = TP.window:GetNamedChild("TitleBar" .. name)
        local active = button and button:GetNamedChild("Active")
        if active then active:SetHidden(view ~= tabView) end
    end
end

function TP.SetView(view)
    if view ~= "portfolio" and view ~= "ledger" and view ~= "personalActivity" and view ~= "guildHistory" and view ~= "weeklyAnalytics" and view ~= "stock" and view ~= "item" then return end
    if TP.activeView == view then return end
    TP.activeView = view
    TP.HideHeaderTooltip()
    if view == "guildHistory" and TP.EnsureFullGuildHistoryLoaded then
        TP.EnsureFullGuildHistoryLoaded()
    end
    TP.RefreshUI()
end

function TP.OpenTradingGuilds()
    if not TP.window then return end
    if TP.SV and TP.SV.tradingGuildsConfigured ~= true then InitializeTradingGuildSelection() end
    TP.guildSelectionDraft = {}
    for _, guild in ipairs(GetAvailableTradingGuilds()) do
        TP.guildSelectionDraft[tostring(guild.id)] = IsTradingGuildSelected(guild.id)
    end
    local dialog = TP.window:GetNamedChild("TradingGuildDialog")
    if dialog then dialog:SetHidden(false) end
    SetViewVisibility()
    TP.RefreshTradingGuildDialog()
end

function TP.CloseTradingGuilds()
    TP.guildSelectionDraft = nil
    local dialog = TP.window and TP.window:GetNamedChild("TradingGuildDialog")
    if dialog then dialog:SetHidden(true) end
    SetViewVisibility()
end

function TP.ToggleTradingGuildRow(index)
    local guild = GetAvailableTradingGuilds()[tonumber(index) or 0]
    if not guild or not TP.guildSelectionDraft then return end
    local key = tostring(guild.id)
    TP.guildSelectionDraft[key] = not TP.guildSelectionDraft[key]
    TP.RefreshTradingGuildDialog()
end

function TP.RefreshTradingGuildDialog()
    local dialog = TP.window and TP.window:GetNamedChild("TradingGuildDialog")
    if not dialog or dialog:IsHidden() then return end
    dialog:GetNamedChild("PanelTitle"):SetText(TP.T("tradingGuildsTitle"))
    dialog:GetNamedChild("PanelHint"):SetText(TP.T("tradingGuildsHint"))
    dialog:GetNamedChild("PanelApply"):SetText(TP.T("tradingGuildsApply"))
    dialog:GetNamedChild("PanelCancel"):SetText(TP.T("tradingGuildsCancel"))

    local guilds = GetAvailableTradingGuilds()
    for index = 1, 5 do
        local row = dialog:GetNamedChild("PanelGuild" .. index)
        local guild = guilds[index]
        row:SetHidden(guild == nil)
        if guild then
            local checked = TP.guildSelectionDraft and TP.guildSelectionDraft[tostring(guild.id)] == true
            row:SetText((checked and "|c7DD98A[X]|r  " or "|c777C86[ ]|r  ") .. guild.name)
        end
    end
end

local function ClearUnselectedGuildMarketSales()
    if not TP.runtime then return end
    for itemKey, bucket in pairs(TP.runtime.marketSalesByItem) do
        for key, sale in pairs(bucket) do
            if not IsTradingGuildSelected(tonumber(sale.guildId)) then
                bucket[key] = nil
                TP.runtime.marketSaleKeys[key] = nil
            end
        end
        if not next(bucket) then TP.runtime.marketSalesByItem[itemKey] = nil end
    end
    for key, sale in pairs(TP.runtime.guildHistorySales) do
        if not IsTradingGuildSelected(tonumber(sale.guildId)) then
            TP.runtime.guildHistorySales[key] = nil
            TP.runtime.guildHistorySaleKeys[key] = nil
        end
    end
    if TP.guildHistoryGuildId and not IsTradingGuildSelected(tonumber(TP.guildHistoryGuildId)) then
        TP.guildHistoryGuildId = nil
    end
    InvalidateAllSummaries()
end

function TP.ApplyTradingGuilds()
    if not TP.guildSelectionDraft then return end
    local selected = {}
    for _, guild in ipairs(GetAvailableTradingGuilds()) do
        local key = tostring(guild.id)
        if TP.guildSelectionDraft[key] == true then selected[key] = true end
    end
    TP.SV.tradingGuilds = selected
    TP.SV.tradingGuildsConfigured = true
    TP.guildSelectionDraft = nil
    ClearUnselectedGuildMarketSales()
    TP.CloseTradingGuilds()
    TP.historyRangeRetries = {}
    if TP.libReady then TP.RestartSalesProcessors() end
    RequestPrioritySave()
    TP.RefreshUI()
end

function TP.SelectOverallItem(index)
    local visibleIndex = tonumber(index) or 0
    local absoluteIndex = (TP.overallScrollOffset or 0) + visibleIndex
    local itemKey = GetAlphabeticalTrackedItemKeys()[absoluteIndex]
    local item = itemKey and TP.SV.trackedItems[itemKey]
    if not item then return end
    if GetSelectedKey() ~= itemKey then
        TP.SV.selectedItem = item
        TP.itemSalesScrollOffset = 0
        RequestPrioritySave()
    end
    TP.ensureSelectedVisible = false
    TP.RefreshUI()
end

function TP.OnOverallItemMouseUp(rowControl, index, button, upInside)
    if upInside == false then return end
    if button ~= MOUSE_BUTTON_INDEX_RIGHT then
        TP.SelectOverallItem(index)
        return
    end

    local itemKey = rowControl and rowControl.itemKey
    if not itemKey or not TP.SV.trackedItems[itemKey] then return end
    ClearMenu()
    AddCustomMenuItem(TP.T("menuShowPrice"), function()
        TP.SetActiveItem(itemKey)
        TP.SetView("item")
    end)
    ShowMenu(rowControl)
end

function TP.ScrollOverall(delta)
    local maxOffset = math.max(0, GetTrackedCount() - VISIBLE_PORTFOLIO_ROWS)
    if maxOffset <= 0 then return end

    local numericDelta = tonumber(delta) or 0
    if numericDelta == 0 then return end
    local direction = numericDelta > 0 and -1 or 1
    local newOffset = zo_clamp((TP.overallScrollOffset or 0) + direction, 0, maxOffset)
    if newOffset == TP.overallScrollOffset then return end

    TP.overallScrollOffset = newOffset
    TP.ensureSelectedVisible = false
    TP.RefreshUI()
end

function TP.OnOverallScrollChanged(value)
    if TP.settingOverallScroll then return end
    local maxOffset = math.max(0, GetTrackedCount() - VISIBLE_PORTFOLIO_ROWS)
    local newOffset = zo_clamp(math.floor((tonumber(value) or 0) + 0.5), 0, maxOffset)
    if newOffset == TP.overallScrollOffset then return end

    TP.overallScrollOffset = newOffset
    TP.ensureSelectedVisible = false
    TP.RefreshUI()
end

local function RefreshOverallUI(selected, selectedSummary)
    local overall = TP.CalculateOverall()
    local sortedKeys = GetAlphabeticalTrackedItemKeys()
    local rowsByKey = {}
    for _, row in ipairs(overall.items) do rowsByKey[row.key] = row end
    local displayItems = {}
    for _, itemKey in ipairs(sortedKeys) do
        local row = rowsByKey[itemKey]
        if row then displayItems[#displayItems + 1] = row end
    end
    SetLabelText("OverallHeaderItem", TP.T("overallItems"))
    SetLabelText("OverallHeaderStockShare", TP.T("overallStockShare"))
    SetLabelText("OverallHeaderROI", TP.T("overallItemROI"))

    local market = selectedSummary.market or { available = false }
    SetLabelText("OverallCardsMarketLabel", TP.T("forecastPrice"))
    SetLabelText("OverallCardsMarketValue", market.available and FormatPlainGold(market.forecastUnitPrice) or "—")
    SetLabelText("OverallCardsMarketSub", "")
    SetLabelText("OverallCardsMarketDetail", "")

    local projectedProfitShare = nil
    if selected and selectedSummary.projectedProfit ~= nil and overall.projectedProfit ~= 0 then
        projectedProfitShare = selectedSummary.projectedProfit / overall.projectedProfit * 100
    end
    SetLabelText("OverallCardsProjectedLabel", TP.T("projectedProfit"))
    SetLabelText("OverallCardsProjectedValue", selected and selectedSummary.projectedProfit ~= nil
        and FormatPlainGold(selectedSummary.projectedProfit) or "—")
    SetLabelText("OverallCardsProjectedSub", selected
        and ColorizeProfitText(
            projectedProfitShare and string.format("%.1f%%", projectedProfitShare) or "—",
            projectedProfitShare and selectedSummary.projectedProfit or nil
        ) .. " " .. ColorizeCardCaption(TP.T("portfolioProfitShare")) or "")
    SetLabelText("OverallCardsProjectedDetail", "")

    SetLabelText("OverallCardsPortfolioLabel", TP.T("overallPortfolio"))
    SetLabelText("OverallCardsPortfolioValue", FormatPlainGold(overall.projectedProfit))
    SetLabelText("OverallCardsPortfolioSub",
        ColorizeCardCaption(TP.T("returnRate")) .. "  "
            .. ColorizeProfitText(FormatPercent(overall.projectedROI), overall.projectedROI))
    SetLabelText("OverallCardsPortfolioDetail", "")
    SetProfitColor("OverallCardsProjectedValue", selected and selectedSummary.projectedProfit or nil)
    SetProfitColor("OverallCardsPortfolioValue", overall.projectedProfit)

    local maxOffset = math.max(0, #displayItems - VISIBLE_PORTFOLIO_ROWS)
    local scrollOffset = zo_clamp(TP.overallScrollOffset or 0, 0, maxOffset)
    if TP.ensureSelectedVisible then
        local selectedIndex = GetItemKeyIndex(sortedKeys, GetSelectedKey())
        if selectedIndex then
            if selectedIndex <= scrollOffset then
                scrollOffset = selectedIndex - 1
            elseif selectedIndex > scrollOffset + VISIBLE_PORTFOLIO_ROWS then
                scrollOffset = selectedIndex - VISIBLE_PORTFOLIO_ROWS
            end
            scrollOffset = zo_clamp(scrollOffset, 0, maxOffset)
        end
        TP.ensureSelectedVisible = false
    end
    TP.overallScrollOffset = scrollOffset

    local scrollbar = TP.window:GetNamedChild("OverallScrollbar")
    if scrollbar then
        TP.settingOverallScroll = true
        scrollbar:SetMinMax(0, maxOffset)
        scrollbar:SetHidden(maxOffset <= 0)
        if maxOffset > 0 then
            scrollbar:SetThumbTextureHeight(math.max(24, math.floor(VISIBLE_PORTFOLIO_ROWS / #displayItems * scrollbar:GetHeight())))
        end
        if scrollbar:GetValue() ~= scrollOffset then
            scrollbar:SetValue(scrollOffset)
        end
        TP.settingOverallScroll = false
    end

    local rowContainer = TP.window:GetNamedChild("OverallRows")
    for index = 1, VISIBLE_PORTFOLIO_ROWS do
        local row = displayItems[scrollOffset + index]
        local rowControl = rowContainer and rowContainer:GetNamedChild("Row" .. index)
        if rowControl then
            rowControl.itemKey = row and row.key or nil
            rowControl:SetHidden(row == nil)
        end
        if row then
            local isSelected = row.key == GetSelectedKey()
            rowControl.itemLink = row.item.link
            local itemIcon = rowControl:GetNamedChild("Icon")
            local itemLabel = rowControl:GetNamedChild("Item")
            local stockShareLabel = rowControl:GetNamedChild("StockShare")
            local roiLabel = rowControl:GetNamedChild("ROI")
            local iconTexture = row.item.icon
            if (not iconTexture or iconTexture == "") and row.item.link and IsItemLink(row.item.link) then
                iconTexture = GetItemLinkIcon(row.item.link)
            end
            itemIcon:SetHidden(not iconTexture or iconTexture == "")
            if iconTexture and iconTexture ~= "" then itemIcon:SetTexture(iconTexture) end
            itemLabel:SetText(row.item.name or row.item.link or "")
            if row.item.link and IsItemLink(row.item.link) and GetItemLinkDisplayQuality and GetItemQualityColor then
                local qualityColor = GetItemQualityColor(GetItemLinkDisplayQuality(row.item.link))
                if qualityColor then
                    itemLabel:SetColor(qualityColor:UnpackRGBA())
                else
                    itemLabel:SetColor(0.91, 0.91, 0.93, 1)
                end
            else
                itemLabel:SetColor(0.91, 0.91, 0.93, 1)
            end
            local stockShare = overall.stockCost > 0
                and math.max(0, row.summary.stockCost or 0) / overall.stockCost * 100
                or 0
            stockShareLabel:SetText(string.format("%.1f%%", stockShare))
            roiLabel:SetText(FormatPercent(row.summary.projectedROI))
            SetProfitControlColor(roiLabel, row.summary.projectedROI)
            local marker = rowControl:GetNamedChild("Selected")
            local selectedBackground = rowControl:GetNamedChild("SelectedBackground")
            local background = rowControl:GetNamedChild("Background")
            if marker then marker:SetHidden(not isSelected) end
            if selectedBackground then selectedBackground:SetHidden(not isSelected) end
            if background then
                background:SetCenterColor(0.045, 0.049, 0.059, 0.72)
                background:SetEdgeColor(0, 0, 0, 0)
            end
        end
    end
    local empty = TP.window:GetNamedChild("OverallEmpty")
    if empty then
        empty:SetText(TP.T("overallEmpty"))
        empty:SetHidden(#displayItems > 0)
    end
end

local function GetRecentMarketSales(itemKey, guildIdFilter)
    local result = {}
    local bucket = itemKey and TP.runtime and TP.runtime.marketSalesByItem[itemKey]
    if not bucket then return result end

    local cutoff = GetTimeStamp() - MARKET_MAX_AGE
    local playerDisplayName = zo_strlower(UndecorateDisplayName(GetDisplayName() or ""))
    for key, sale in pairs(bucket) do
        local quantity = tonumber(sale.quantity) or 0
        local totalPrice = tonumber(sale.price) or 0
        local timestamp = tonumber(sale.timestamp) or 0
        local guildId = tonumber(sale.guildId) or tonumber(tostring(key):match("^(%d+):"))
        if quantity > 0
            and totalPrice > 0
            and timestamp >= cutoff
            and (guildIdFilter == nil or guildId == tonumber(guildIdFilter)) then
            local guildName = sale.guildName
            if (not guildName or guildName == "") and guildId then
                guildName = GetGuildName(guildId)
            end
            local sellerDisplayName = zo_strlower(UndecorateDisplayName(sale.seller or ""))
            local isPersonal = TP.SV.sales[tostring(key)] ~= nil
                or (sellerDisplayName ~= "" and sellerDisplayName == playerDisplayName)
            result[#result + 1] = {
                id = tostring(sale.id or key),
                guildName = guildName and guildName ~= "" and guildName or "—",
                quantity = quantity,
                unitPrice = totalPrice / quantity,
                timestamp = timestamp,
                isPersonal = isPersonal,
            }
        end
    end

    table.sort(result, function(a, b)
        if a.timestamp ~= b.timestamp then return a.timestamp > b.timestamp end
        return a.id > b.id
    end)
    return result
end

local function GetLedgerEntries()
    local result = {}
    local purchasesByItem = TP.runtime and TP.runtime.purchasesByItem or {}
    local salesByItem = TP.runtime and TP.runtime.salesByItem or {}

    for itemKey, purchaseBucket in pairs(purchasesByItem) do
        if IsTrackedKey(itemKey) then
            local purchaseLots = {}
            for purchaseKey, purchase in pairs(purchaseBucket) do
                local quantity = math.max(0, tonumber(purchase.quantity) or 0)
                local totalPrice = math.max(0, tonumber(purchase.price) or 0)
                if purchase.status ~= "failed" and quantity > 0 and totalPrice > 0 then
                    local trackedItem = TP.SV.trackedItems and TP.SV.trackedItems[itemKey]
                    local itemLink = purchase.itemLink and IsItemLink(purchase.itemLink) and purchase.itemLink
                        or trackedItem and trackedItem.link
                    local itemName = trackedItem and trackedItem.name
                    if (not itemName or itemName == "") and itemLink then
                        itemName = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(itemLink))
                    end
                    purchaseLots[#purchaseLots + 1] = {
                        id = tostring(purchase.id or purchaseKey),
                        timestamp = tonumber(purchase.timestamp) or 0,
                        quantity = quantity,
                        remaining = quantity,
                        unitPrice = totalPrice / quantity,
                        itemLink = itemLink,
                        itemName = itemName and itemName ~= "" and itemName or "—",
                        sortKey = purchase.id or purchaseKey,
                    }
                end
            end

            local saleRecords = {}
            for saleKey, sale in pairs(salesByItem[itemKey] or {}) do
                local quantity = math.max(0, tonumber(sale.quantity) or 0)
                local totalPrice = math.max(0, tonumber(sale.price) or 0)
                if quantity > 0 and totalPrice > 0 then
                    saleRecords[#saleRecords + 1] = {
                        id = tostring(sale.id or saleKey),
                        timestamp = tonumber(sale.timestamp) or 0,
                        quantity = quantity,
                        remaining = quantity,
                        unitPrice = totalPrice / quantity,
                        sortKey = sale.id or saleKey,
                    }
                end
            end

            table.sort(purchaseLots, SortOldestTransactionFirst)
            table.sort(saleRecords, SortOldestTransactionFirst)
            local purchaseIndex = 1
            for _, sale in ipairs(saleRecords) do
                while sale.remaining > 0 and purchaseIndex <= #purchaseLots do
                    local purchase = purchaseLots[purchaseIndex]
                    if purchase.remaining <= 0 then
                        purchaseIndex = purchaseIndex + 1
                    elseif purchase.timestamp > sale.timestamp then
                        break
                    else
                        local quantity = math.min(sale.remaining, purchase.remaining)
                        result[#result + 1] = {
                            id = purchase.id .. ":" .. sale.id,
                            itemLink = purchase.itemLink,
                            itemName = purchase.itemName,
                            purchaseTimestamp = purchase.timestamp,
                            purchaseQuantity = quantity,
                            purchaseUnitPrice = purchase.unitPrice,
                            saleTimestamp = sale.timestamp,
                            saleQuantity = quantity,
                            saleUnitPrice = sale.unitPrice,
                        }
                        sale.remaining = sale.remaining - quantity
                        purchase.remaining = purchase.remaining - quantity
                        if purchase.remaining <= 0 then purchaseIndex = purchaseIndex + 1 end
                    end
                end
            end

            for _, purchase in ipairs(purchaseLots) do
                if purchase.remaining > 0 then
                    result[#result + 1] = {
                        id = purchase.id .. ":open",
                        itemLink = purchase.itemLink,
                        itemName = purchase.itemName,
                        purchaseTimestamp = purchase.timestamp,
                        purchaseQuantity = purchase.remaining,
                        purchaseUnitPrice = purchase.unitPrice,
                    }
                end
            end
        end
    end

    table.sort(result, function(a, b)
        if a.purchaseTimestamp ~= b.purchaseTimestamp then return a.purchaseTimestamp > b.purchaseTimestamp end
        local aSale = tonumber(a.saleTimestamp) or 0
        local bSale = tonumber(b.saleTimestamp) or 0
        if aSale ~= bSale then return aSale > bSale end
        return tostring(a.id) > tostring(b.id)
    end)
    return result
end

local function FormatQuantityAtPrice(quantity, unitPrice)
    return string.format("%s × %s",
        ZO_CommaDelimitNumber(math.floor((tonumber(quantity) or 0) + 0.5)),
        ZO_CommaDelimitNumber(math.floor((tonumber(unitPrice) or 0) + 0.5)))
end

local function GetTransactionItemDisplay(record)
    local itemLink = record and record.itemLink
    local trackedItem = record and TP.SV.trackedItems and TP.SV.trackedItems[record.itemKey]
    local itemName = trackedItem and trackedItem.name
    if (not itemName or itemName == "") and IsItemLink(itemLink) then
        itemName = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(itemLink))
    end
    return itemLink, itemName and itemName ~= "" and itemName or "—"
end

local function GetTradingWeekRange(period)
    if period == "all" then return nil, nil end

    local now = GetTimeStamp()
    if period == "last7" then return now - 7 * DAY, now + 1 end

    local worldName = zo_strlower(GetWorldName() or "")
    local resetHourUtc = worldName:find("^na") and 19 or 14
    -- Unix epoch began on a Thursday. The first Tuesday after it is day 5.
    local anchor = 5 * DAY + resetHourUtc * 60 * 60
    local week = 7 * DAY
    local currentWeekStart = now - ((now - anchor) % week)
    if period == "previous" then
        return currentWeekStart - week, currentWeekStart
    end
    return currentWeekStart, currentWeekStart + week
end

local function GetPersonalActivityEntries()
    local kind = TP.personalActivityKind == "sale" and "sale" or "purchase"
    local activityCache = TP.runtime and TP.runtime.personalActivityCache
    local cachedKind = activityCache and activityCache[kind]
    if not cachedKind then
        local entries = {}
        local records = kind == "sale" and TP.SV.sales or TP.SV.purchases

        for key, record in pairs(records or {}) do
            local quantity = math.max(0, tonumber(record.quantity) or 0)
            local totalPrice = math.max(0, tonumber(record.price) or 0)
            local itemLink, itemName = GetTransactionItemDisplay(record)
            local guildName = record.guildName
            if (not guildName or guildName == "") and record.guildId then
                local guildId = tonumber(record.guildId)
                if guildId then guildName = GetGuildName(guildId) end
            end
            entries[#entries + 1] = {
                id = tostring(record.id or key),
                itemLink = itemLink,
                itemName = itemName,
                guildName = guildName and guildName ~= "" and guildName or "—",
                quantity = quantity,
                unitPrice = quantity > 0 and totalPrice / quantity or 0,
                timestamp = tonumber(record.timestamp) or 0,
            }
        end

        table.sort(entries, function(a, b)
            if a.timestamp ~= b.timestamp then return a.timestamp > b.timestamp end
            return a.id > b.id
        end)
        cachedKind = { entries = entries }
        if activityCache then
            activityCache[kind] = cachedKind
        end
    end

    local period = TP.personalActivityPeriod
    if period == "all" then return cachedKind.entries end

    local now = GetTimeStamp()
    local periodStart, periodEnd = GetTradingWeekRange(period)
    local viewKey = period == "last7" and period
        or table.concat({ period, tostring(periodStart), tostring(periodEnd) }, ":")
    if cachedKind.viewKey == viewKey
        and (period ~= "last7" or now < (cachedKind.viewExpiresAt or 0)) then
        return cachedKind.viewEntries
    end

    local result = {}
    local viewExpiresAt
    for _, entry in ipairs(cachedKind.entries) do
        if entry.timestamp >= periodStart and entry.timestamp < periodEnd then
            result[#result + 1] = entry
            if period == "last7" then
                local expiresAt = entry.timestamp + 7 * DAY + 1
                if expiresAt > now and (not viewExpiresAt or expiresAt < viewExpiresAt) then
                    viewExpiresAt = expiresAt
                end
            end
        end
    end
    cachedKind.viewKey = viewKey
    cachedKind.viewEntries = result
    cachedKind.viewExpiresAt = viewExpiresAt or (period == "last7" and now + DAY or nil)
    return result
end

local function NormalizeHistoryPlayer(name)
    return zo_strlower(UndecorateDisplayName(name or ""))
end

local function OptionExists(options, value)
    if value == nil then return true end
    for _, option in ipairs(options or {}) do
        if option.value == value then return true end
    end
    return false
end

local function BuildGuildHistorySnapshot(generation, onComplete)
    generation = generation or analyticsLoadGeneration
    if guildHistorySnapshotTask then
        guildHistorySnapshotTask:Cancel()
        guildHistorySnapshotTask = nil
    end

    local runtime = TP.runtime
    if not runtime then
        if onComplete then onComplete(false) end
        return
    end

    local entries = {}
    local guildOptions = {}
    for _, guild in ipairs(GetSelectedTradingGuilds()) do
        local guildId = tostring(guild.id)
        guildOptions[#guildOptions + 1] = { value = guildId, text = guild.name }
    end

    local task = LibAsync:Create(TP.name .. "GuildHistorySnapshot")
    guildHistorySnapshotTask = task
    local completed = false

    task:For(pairs(runtime.guildHistorySales or {})):Do(function(key, record)
        local quantity = math.max(0, tonumber(record.quantity) or 0)
        local totalPrice = math.max(0, tonumber(record.price) or 0)
        local itemLink, itemName = GetTransactionItemDisplay(record)
        local guildId = tostring(record.guildId or 0)
        local seller = record.seller and record.seller ~= "" and record.seller or "—"
        local buyer = record.buyer and record.buyer ~= "" and record.buyer or "—"
        entries[#entries + 1] = {
            id = tostring(record.id or key),
            itemKey = record.itemKey,
            itemLink = itemLink,
            itemName = itemName,
            itemNameNormalized = zo_strlower(itemName or ""),
            guildId = guildId,
            guildName = record.guildName and record.guildName ~= "" and record.guildName or "—",
            seller = seller,
            sellerNormalized = NormalizeHistoryPlayer(record.seller),
            buyer = buyer,
            buyerNormalized = NormalizeHistoryPlayer(record.buyer),
            quantity = quantity,
            unitPrice = quantity > 0 and totalPrice / quantity or 0,
            totalPrice = totalPrice,
            timestamp = tonumber(record.timestamp) or 0,
        }
    end)
    task:Sort(entries, function(a, b)
        if a.timestamp ~= b.timestamp then return a.timestamp > b.timestamp end
        return a.id > b.id
    end)
    task:Then(function()
        if guildHistorySnapshotTask ~= task
            or generation ~= analyticsLoadGeneration
            or TP.runtime ~= runtime then return end
        runtime.guildHistorySnapshot = {
            entries = entries,
            guildOptions = guildOptions,
        }
        TP.guildHistoryFiltersDirty = true
        completed = true
    end)
    task:Finally(function()
        if guildHistorySnapshotTask == task then guildHistorySnapshotTask = nil end
        if onComplete then onComplete(completed) end
    end)
end

local function NormalizeHistoryQuery(value)
    local text = tostring(value or ""):match("^%s*(.-)%s*$") or ""
    return zo_strlower(text)
end

local function HistoryContains(value, query)
    return query == "" or string.find(value or "", query, 1, true) ~= nil
end

local function GetGuildHistoryViewData()
    local snapshot = TP.runtime and TP.runtime.guildHistorySnapshot
    if not snapshot then
        return { entries = {}, guildOptions = {} }, false
    end

    if not OptionExists(snapshot.guildOptions, TP.guildHistoryGuildId) then
        TP.guildHistoryGuildId = nil
        TP.guildHistoryFiltersDirty = true
    end
    local itemQuery = NormalizeHistoryQuery(TP.guildHistoryItemQuery)
    local sellerQuery = NormalizeHistoryQuery(TP.guildHistorySellerQuery)
    local buyerQuery = NormalizeHistoryQuery(TP.guildHistoryBuyerQuery)
    local viewKey = table.concat({
        TP.guildHistoryGuildId or "*",
        itemQuery,
        sellerQuery,
        buyerQuery,
    }, "\31")
    if snapshot.viewKey == viewKey and snapshot.viewData then return snapshot.viewData, true end

    local candidates = {}
    local sellerExact, buyerExact = false, false
    for _, entry in ipairs(snapshot.entries) do
        local guildMatches = TP.guildHistoryGuildId == nil or entry.guildId == TP.guildHistoryGuildId
        if guildMatches and HistoryContains(entry.itemNameNormalized, itemQuery) then
            candidates[#candidates + 1] = entry
            if sellerQuery ~= "" and entry.sellerNormalized == sellerQuery then sellerExact = true end
            if buyerQuery ~= "" and entry.buyerNormalized == buyerQuery then buyerExact = true end
        end
    end

    local result = {}
    for _, entry in ipairs(candidates) do
        local sellerMatches = sellerQuery == ""
            or (sellerExact and entry.sellerNormalized == sellerQuery)
            or (not sellerExact and HistoryContains(entry.sellerNormalized, sellerQuery))
        local buyerMatches = buyerQuery == ""
            or (buyerExact and entry.buyerNormalized == buyerQuery)
            or (not buyerExact and HistoryContains(entry.buyerNormalized, buyerQuery))
        if sellerMatches and buyerMatches then
            result[#result + 1] = entry
        end
    end

    local viewData = {
        entries = result,
        guildOptions = snapshot.guildOptions,
    }
    snapshot.viewKey = viewKey
    snapshot.viewData = viewData
    return viewData, true
end

local function BuildWeeklyAnalyticsSnapshot(generation, onComplete)
    generation = generation or analyticsLoadGeneration
    if weeklyAnalyticsSnapshotTask then
        weeklyAnalyticsSnapshotTask:Cancel()
        weeklyAnalyticsSnapshotTask = nil
    end

    local runtime = TP.runtime
    if not runtime then
        if onComplete then onComplete(false) end
        return
    end

    local guildRows, guildById = {}, {}
    for _, guild in ipairs(GetSelectedTradingGuilds()) do
        local key = tostring(guild.id)
        local row = {
            guildId = guild.id,
            guildName = guild.name,
            currentTurnover = 0,
            previousTurnover = 0,
            currentMyTurnover = 0,
            previousMyTurnover = 0,
        }
        guildById[key] = row
        guildRows[#guildRows + 1] = row
    end

    local currentStart, currentEnd = GetTradingWeekRange("current")
    local previousStart, previousEnd = GetTradingWeekRange("previous")
    local sellersByPeriod = {
        current = {},
        previous = {},
    }
    local sellerRowsByPeriod = {
        current = {},
        previous = {},
    }
    local playerDisplayName = NormalizeHistoryPlayer(GetDisplayName())

    local task = LibAsync:Create(TP.name .. "WeeklyAnalyticsSnapshot")
    weeklyAnalyticsSnapshotTask = task
    local completed = false

    task:For(pairs(runtime.guildHistorySales or {})):Do(function(_, sale)
        local guildId = tostring(sale.guildId or 0)
        local guildRow = guildById[guildId]
        if guildRow then
            local timestamp = tonumber(sale.timestamp) or 0
            local price = math.max(0, tonumber(sale.price) or 0)
            local normalizedSeller = NormalizeHistoryPlayer(sale.seller)
            local isPlayer = normalizedSeller ~= "" and normalizedSeller == playerDisplayName
            local sellerPeriod
            if timestamp >= currentStart and timestamp < currentEnd then
                guildRow.currentTurnover = guildRow.currentTurnover + price
                if isPlayer then guildRow.currentMyTurnover = guildRow.currentMyTurnover + price end
                sellerPeriod = "current"
            elseif timestamp >= previousStart and timestamp < previousEnd then
                guildRow.previousTurnover = guildRow.previousTurnover + price
                if isPlayer then guildRow.previousMyTurnover = guildRow.previousMyTurnover + price end
                sellerPeriod = "previous"
            end

            if sellerPeriod then
                if normalizedSeller ~= "" then
                    local sellerKey = normalizedSeller .. "\31" .. guildId
                    local sellerByKey = sellersByPeriod[sellerPeriod]
                    local sellerRow = sellerByKey[sellerKey]
                    if not sellerRow then
                        sellerRow = {
                            seller = sale.seller,
                            guildId = sale.guildId,
                            guildName = sale.guildName and sale.guildName ~= "" and sale.guildName or guildRow.guildName,
                            sales = 0,
                            lots = 0,
                            isPlayer = isPlayer,
                        }
                        sellerByKey[sellerKey] = sellerRow
                        local sellerRows = sellerRowsByPeriod[sellerPeriod]
                        sellerRows[#sellerRows + 1] = sellerRow
                    end
                    sellerRow.sales = sellerRow.sales + price
                    sellerRow.lots = sellerRow.lots + 1
                end
            end
        end
    end)

    local function SortSellerRows(left, right)
        if left.sales ~= right.sales then return left.sales > right.sales end
        if left.lots ~= right.lots then return left.lots > right.lots end
        local leftSeller, rightSeller = zo_strlower(left.seller), zo_strlower(right.seller)
        if leftSeller ~= rightSeller then return leftSeller < rightSeller end
        return zo_strlower(left.guildName) < zo_strlower(right.guildName)
    end
    task:Sort(sellerRowsByPeriod.current, SortSellerRows)
    task:Sort(sellerRowsByPeriod.previous, SortSellerRows)
    task:Then(function()
        if weeklyAnalyticsSnapshotTask ~= task
            or generation ~= analyticsLoadGeneration
            or TP.runtime ~= runtime then return end
        runtime.weeklyAnalyticsCache = {
            guildRows = guildRows,
            sellerRowsByPeriod = sellerRowsByPeriod,
        }
        completed = true
    end)
    task:Finally(function()
        if weeklyAnalyticsSnapshotTask == task then weeklyAnalyticsSnapshotTask = nil end
        if onComplete then onComplete(completed) end
    end)
end

local function CancelHistorySnapshotTasks()
    if guildHistorySnapshotTask then
        guildHistorySnapshotTask:Cancel()
        guildHistorySnapshotTask = nil
    end
    if weeklyAnalyticsSnapshotTask then
        weeklyAnalyticsSnapshotTask:Cancel()
        weeklyAnalyticsSnapshotTask = nil
    end
end

local function GetWeeklyAnalytics()
    local snapshot = TP.runtime and TP.runtime.weeklyAnalyticsCache
    if not snapshot then return {}, {}, false end
    local period = TP.weeklyAnalyticsPeriod == "previous" and "previous" or "current"
    local guildRows = {}
    local showingMine = TP.weeklyAnalyticsScope ~= "all"
    for _, row in ipairs(snapshot.guildRows or {}) do
        guildRows[#guildRows + 1] = {
            guildId = row.guildId,
            guildName = row.guildName,
            currentTurnover = showingMine and (row.currentMyTurnover or 0) or (row.currentTurnover or 0),
            previousTurnover = showingMine and (row.previousMyTurnover or 0) or (row.previousTurnover or 0),
        }
    end
    local sellerRows = snapshot.sellerRowsByPeriod[period] or {}
    local selectedGuildId = tonumber(TP.weeklyAnalyticsGuildId)
    if selectedGuildId then
        local guildAvailable = false
        for _, row in ipairs(guildRows) do
            if tonumber(row.guildId) == selectedGuildId then
                guildAvailable = true
                break
            end
        end
        if guildAvailable then
            local filtered = {}
            for _, row in ipairs(sellerRows) do
                if tonumber(row.guildId) == selectedGuildId then filtered[#filtered + 1] = row end
            end
            sellerRows = filtered
        else
            TP.weeklyAnalyticsGuildId = nil
        end
    end
    return guildRows, sellerRows, true
end

local function GetStockItemOptions()
    local options = {}
    for itemKey, purchases in pairs(TP.runtime and TP.runtime.purchasesByItem or {}) do
        if IsTrackedKey(itemKey) then
            local summary = TP.CalculateSummary(itemKey)
            local sample
            if math.max(0, tonumber(summary.stock) or 0) > 0 then
                for _, purchase in pairs(purchases) do
                    if purchase.status ~= "failed" and math.max(0, tonumber(purchase.quantity) or 0) > 0 then
                        sample = purchase
                        break
                    end
                end
            end
            if sample then
                local itemLink, itemName = GetTransactionItemDisplay(sample)
                options[#options + 1] = {
                    value = itemKey,
                    text = itemName,
                    itemLink = itemLink,
                    trackedStock = math.max(0, tonumber(summary.stock) or 0),
                }
            end
        end
    end
    table.sort(options, function(left, right)
        local leftText, rightText = zo_strlower(left.text), zo_strlower(right.text)
        if leftText == rightText then return tostring(left.value) < tostring(right.value) end
        return leftText < rightText
    end)
    return options
end

local function FormatListingTimeRemaining(expiresAt)
    local seconds = math.max(0, math.floor((tonumber(expiresAt) or GetTimeStamp()) - GetTimeStamp()))
    local days = math.floor(seconds / DAY)
    local hours = math.floor((seconds % DAY) / 3600)
    if days > 0 then return string.format(TP.T("stockDaysHours"), days, hours) end
    local minutes = math.max(0, math.floor((seconds % 3600) / 60))
    if hours > 0 then return string.format(TP.T("stockHoursMinutes"), hours, minutes) end
    return string.format(TP.T("stockMinutes"), minutes)
end

local function GetStockViewData(itemKey)
    local summary = itemKey and TP.CalculateSummary(itemKey) or { stock = 0 }
    local listings = itemKey and TP.GetListings({ itemKey = itemKey }) or {}
    local trackedStock = math.max(0, tonumber(summary.stock) or 0)
    local activeListings = {}
    local activeQuantity = 0
    for _, listing in ipairs(listings) do
        if listing.status == "active" then
            local quantity = math.max(0, tonumber(listing.quantity) or 0)
            local totalPrice = math.max(0, tonumber(listing.price) or 0)
            local guildName = listing.guildName
            if (not guildName or guildName == "") and listing.guildId then
                local numericGuildId = tonumber(listing.guildId)
                if numericGuildId then guildName = GetGuildName(numericGuildId) end
            end
            guildName = guildName and guildName ~= "" and guildName or "—"
            activeQuantity = activeQuantity + quantity
            activeListings[#activeListings + 1] = {
                id = tostring(listing.id or ""),
                guildName = guildName,
                quantity = quantity,
                unitPrice = quantity > 0 and totalPrice / quantity or 0,
                totalPrice = totalPrice,
                expiresAt = tonumber(listing.expiresAt) or 0,
            }
        end
    end

    table.sort(activeListings, function(left, right)
        if left.expiresAt ~= right.expiresAt then return left.expiresAt < right.expiresAt end
        return left.id > right.id
    end)
    return {
        trackedStock = trackedStock,
        activeQuantity = activeQuantity,
        unlistedQuantity = math.max(0, trackedStock - activeQuantity),
        listings = activeListings,
    }
end

local function ScrollGridByWheel(delta, entryCountKey, visibleRows, offsetKey, visibilityFlagKey)
    local maxOffset = math.max(0, (TP[entryCountKey] or 0) - visibleRows)
    if maxOffset <= 0 then return end
    local numericDelta = tonumber(delta) or 0
    if numericDelta == 0 then return end
    local direction = numericDelta > 0 and -1 or 1
    local newOffset = zo_clamp((TP[offsetKey] or 0) + direction, 0, maxOffset)
    if newOffset == TP[offsetKey] then return end
    TP[offsetKey] = newOffset
    if visibilityFlagKey then TP[visibilityFlagKey] = false end
    TP.RefreshUI()
end

local function SetGridScrollValue(value, settingKey, entryCountKey, visibleRows, offsetKey, visibilityFlagKey)
    if TP[settingKey] then return end
    local maxOffset = math.max(0, (TP[entryCountKey] or 0) - visibleRows)
    local newOffset = zo_clamp(math.floor((tonumber(value) or 0) + 0.5), 0, maxOffset)
    if newOffset == TP[offsetKey] then return end
    TP[offsetKey] = newOffset
    if visibilityFlagKey then TP[visibilityFlagKey] = false end
    TP.RefreshUI()
end

function TP.ScrollLedger(delta)
    ScrollGridByWheel(delta, "ledgerEntryCount", LEDGER_VISIBLE_ROWS, "ledgerScrollOffset")
end

function TP.SetPersonalActivityKind(kind)
    if kind ~= "purchase" and kind ~= "sale" then return end
    if TP.personalActivityKind == kind then return end
    TP.personalActivityKind = kind
    TP.personalActivityScrollOffset = 0
    TP.RefreshUI()
end

function TP.SetPersonalActivityPeriod(value)
    if value ~= "last7" and value ~= "current" and value ~= "previous" and value ~= "all" then return end
    TP.personalActivityPeriod = value
    TP.personalActivityScrollOffset = 0
    TP.RefreshUI()
end

function TP.ScrollPersonalActivity(delta)
    ScrollGridByWheel(delta, "personalActivityEntryCount", PERSONAL_ACTIVITY_VISIBLE_ROWS, "personalActivityScrollOffset")
end

function TP.OnPersonalActivityScrollChanged(value)
    SetGridScrollValue(value, "settingPersonalActivityScroll", "personalActivityEntryCount",
        PERSONAL_ACTIVITY_VISIBLE_ROWS, "personalActivityScrollOffset")
end

function TP.SetGuildHistoryFilter(filterName, value)
    if filterName ~= "guild" or TP.guildHistoryGuildId == value then return end
    TP.guildHistoryGuildId = value
    TP.guildHistoryScrollOffset = 0
    TP.guildHistoryFiltersDirty = true
    TP.RefreshUI()
end

function TP.ApplyGuildHistoryTextFilters()
    if not TP.window then return end
    local function ReadFilter(controlName)
        local control = TP.window:GetNamedChild(controlName)
        local text = control and control:GetText() or ""
        return tostring(text or ""):match("^%s*(.-)%s*$") or ""
    end

    local itemQuery = ReadFilter("GuildHistoryViewTopFiltersItemSearchBox")
    local sellerQuery = ReadFilter("GuildHistoryViewPlayerFiltersSellerSearchBox")
    local buyerQuery = ReadFilter("GuildHistoryViewPlayerFiltersBuyerSearchBox")
    if itemQuery == TP.guildHistoryItemQuery
        and sellerQuery == TP.guildHistorySellerQuery
        and buyerQuery == TP.guildHistoryBuyerQuery then return end

    TP.guildHistoryItemQuery = itemQuery
    TP.guildHistorySellerQuery = sellerQuery
    TP.guildHistoryBuyerQuery = buyerQuery
    TP.guildHistoryScrollOffset = 0
    TP.RefreshUI()
end

function TP.RefreshGuildHistory()
    if not TP.runtime or not TP.runtime.guildHistorySnapshot then return end
    if next(analyticsProcessorsPending) or guildHistorySnapshotTask then return end
    local now = GetGameTimeMilliseconds()
    if now < (TP.guildHistoryRefreshAvailableAt or 0) then return end

    TP.guildHistoryRefreshAvailableAt = now + GUILD_HISTORY_REFRESH_COOLDOWN_MS
    local refreshAvailableAt = TP.guildHistoryRefreshAvailableAt
    BuildGuildHistorySnapshot(analyticsLoadGeneration, function(succeeded)
        if not succeeded then return end
        TP.guildHistoryScrollOffset = 0
        if TP.activeView == "guildHistory" then TP.RefreshUI() end
    end)
    TP.RefreshUI()
    zo_callLater(function()
        if TP.guildHistoryRefreshAvailableAt == refreshAvailableAt
            and TP.activeView == "guildHistory" then
            TP.RefreshUI()
        end
    end, GUILD_HISTORY_REFRESH_COOLDOWN_MS)
end

function TP.ScrollGuildHistory(delta)
    ScrollGridByWheel(delta, "guildHistoryEntryCount", GUILD_HISTORY_VISIBLE_ROWS, "guildHistoryScrollOffset")
end

function TP.OnGuildHistoryScrollChanged(value)
    SetGridScrollValue(value, "settingGuildHistoryScroll", "guildHistoryEntryCount",
        GUILD_HISTORY_VISIBLE_ROWS, "guildHistoryScrollOffset")
end

function TP.SetWeeklyAnalyticsPeriod(period)
    if period ~= "current" and period ~= "previous" then return end
    if TP.weeklyAnalyticsPeriod == period then return end
    TP.weeklyAnalyticsPeriod = period
    TP.weeklyAnalyticsScrollOffset = 0
    TP.RefreshUI()
end

function TP.SetWeeklyAnalyticsScope(scope)
    if scope ~= "my" and scope ~= "all" then return end
    if TP.weeklyAnalyticsScope == scope then return end
    TP.weeklyAnalyticsScope = scope
    TP.weeklyAnalyticsScrollOffset = 0
    TP.RefreshUI()
end

function TP.SelectWeeklyAnalyticsGuild(control, button, upInside)
    if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT or not control then return end
    local guildId = control.analyticsGuildId
    if guildId == false then guildId = nil end
    if tonumber(TP.weeklyAnalyticsGuildId) == tonumber(guildId) then return end
    TP.weeklyAnalyticsGuildId = guildId
    TP.weeklyAnalyticsScrollOffset = 0
    TP.RefreshUI()
end

function TP.RefreshWeeklyAnalytics()
    if not TP.runtime or not TP.runtime.weeklyAnalyticsCache then return end
    if next(analyticsProcessorsPending) or weeklyAnalyticsSnapshotTask then return end
    local now = GetGameTimeMilliseconds()
    if now < (TP.weeklyAnalyticsRefreshAvailableAt or 0) then return end

    TP.weeklyAnalyticsRefreshAvailableAt = now + ANALYTICS_REFRESH_COOLDOWN_MS
    local refreshAvailableAt = TP.weeklyAnalyticsRefreshAvailableAt
    BuildWeeklyAnalyticsSnapshot(analyticsLoadGeneration, function(succeeded)
        if not succeeded then return end
        TP.weeklyAnalyticsScrollOffset = 0
        if TP.activeView == "weeklyAnalytics" then TP.RefreshUI() end
    end)
    TP.RefreshUI()
    zo_callLater(function()
        if TP.weeklyAnalyticsRefreshAvailableAt == refreshAvailableAt
            and TP.activeView == "weeklyAnalytics" then
            TP.RefreshUI()
        end
    end, ANALYTICS_REFRESH_COOLDOWN_MS)
end

function TP.ScrollWeeklyAnalytics(delta)
    ScrollGridByWheel(delta, "weeklyAnalyticsEntryCount", WEEKLY_ANALYTICS_VISIBLE_ROWS,
        "weeklyAnalyticsScrollOffset")
end

function TP.OnWeeklyAnalyticsScrollChanged(value)
    SetGridScrollValue(value, "settingWeeklyAnalyticsScroll", "weeklyAnalyticsEntryCount",
        WEEKLY_ANALYTICS_VISIBLE_ROWS, "weeklyAnalyticsScrollOffset")
end

function TP.SetStockItem(itemKey)
    if not itemKey or TP.stockItemKey == itemKey then return end
    TP.stockItemKey = itemKey
    TP.stockListingScrollOffset = 0
    TP.ensureStockSelectedVisible = false
    TP.RefreshUI()
end

function TP.SelectStockItem(control, button, upInside)
    if not upInside or button ~= MOUSE_BUTTON_INDEX_LEFT or not control or not control.itemKey then return end
    TP.SetStockItem(control.itemKey)
end

function TP.ScrollStockItems(delta)
    ScrollGridByWheel(delta, "stockItemEntryCount", STOCK_ITEM_VISIBLE_ROWS, "stockItemScrollOffset",
        "ensureStockSelectedVisible")
end

function TP.OnStockItemScrollChanged(value)
    SetGridScrollValue(value, "settingStockItemScroll", "stockItemEntryCount", STOCK_ITEM_VISIBLE_ROWS,
        "stockItemScrollOffset", "ensureStockSelectedVisible")
end

function TP.ScrollStockListings(delta)
    ScrollGridByWheel(delta, "stockListingEntryCount", STOCK_LISTING_VISIBLE_ROWS, "stockListingScrollOffset")
end

function TP.OnStockListingScrollChanged(value)
    SetGridScrollValue(value, "settingStockListingScroll", "stockListingEntryCount",
        STOCK_LISTING_VISIBLE_ROWS, "stockListingScrollOffset")
end

function TP.OnLedgerScrollChanged(value)
    SetGridScrollValue(value, "settingLedgerScroll", "ledgerEntryCount", LEDGER_VISIBLE_ROWS,
        "ledgerScrollOffset")
end

function TP.ScrollItemSales(delta)
    ScrollGridByWheel(delta, "itemSalesEntryCount", ITEM_SALES_VISIBLE_ROWS, "itemSalesScrollOffset")
end

function TP.OnItemSalesScrollChanged(value)
    SetGridScrollValue(value, "settingItemSalesScroll", "itemSalesEntryCount", ITEM_SALES_VISIBLE_ROWS,
        "itemSalesScrollOffset")
end

function TP.SelectItemGuild(control)
    if not control then return end
    local guildId = tonumber(control.guildId)
    if TP.selectedItemGuildId == guildId then return end
    TP.selectedItemGuildId = guildId
    TP.itemSalesScrollOffset = 0
    TP.RefreshUI()
end

local function RefreshGridScrollbar(scrollbar, entryCount, visibleRows, scrollOffset, stateKey)
    if not scrollbar then return end
    local maxOffset = math.max(0, entryCount - visibleRows)
    TP[stateKey] = true
    scrollbar:SetMinMax(0, maxOffset)
    scrollbar:SetHidden(maxOffset <= 0)
    if maxOffset > 0 then
        scrollbar:SetThumbTextureHeight(math.max(24, math.floor(visibleRows / entryCount * scrollbar:GetHeight())))
    end
    if scrollbar:GetValue() ~= scrollOffset then scrollbar:SetValue(scrollOffset) end
    TP[stateKey] = false
end

local function RefreshLedgerUI()
    local view = TP.window:GetNamedChild("LedgerView")
    if not view then return end
    local header = view:GetNamedChild("Header")
    header:GetNamedChild("PurchaseWhen"):SetText(TP.T("ledgerPurchaseWhen"))
    header:GetNamedChild("Item"):SetText(TP.T("ledgerItem"))
    header:GetNamedChild("Bought"):SetText(TP.T("ledgerBought"))
    header:GetNamedChild("SaleWhen"):SetText(TP.T("ledgerSaleWhen"))
    header:GetNamedChild("Sold"):SetText(TP.T("ledgerSold"))

    local entries = GetLedgerEntries()
    TP.ledgerEntryCount = #entries
    local maxOffset = math.max(0, #entries - LEDGER_VISIBLE_ROWS)
    local scrollOffset = zo_clamp(TP.ledgerScrollOffset or 0, 0, maxOffset)
    TP.ledgerScrollOffset = scrollOffset
    RefreshGridScrollbar(view:GetNamedChild("Scrollbar"), #entries, LEDGER_VISIBLE_ROWS, scrollOffset, "settingLedgerScroll")

    local rows = view:GetNamedChild("Rows")
    for index = 1, LEDGER_VISIBLE_ROWS do
        local row = rows:GetNamedChild("Row" .. index)
        local entry = entries[scrollOffset + index]
        row:SetHidden(entry == nil)
        row.itemLink = entry and entry.itemLink or nil
        if entry then
            local itemIcon = row:GetNamedChild("Icon")
            local itemLabel = row:GetNamedChild("Item")
            local iconTexture = entry.itemLink and IsItemLink(entry.itemLink)
                and GetItemLinkIcon(entry.itemLink) or nil
            itemIcon:SetHidden(not iconTexture or iconTexture == "")
            if iconTexture and iconTexture ~= "" then itemIcon:SetTexture(iconTexture) end
            row:GetNamedChild("PurchaseWhen"):SetText((TP.FormatAge(entry.purchaseTimestamp):gsub("%.$", "")))
            itemLabel:SetText(entry.itemLink or entry.itemName)
            if entry.itemLink and IsItemLink(entry.itemLink) and GetItemLinkDisplayQuality and GetItemQualityColor then
                local qualityColor = GetItemQualityColor(GetItemLinkDisplayQuality(entry.itemLink))
                if qualityColor then
                    itemLabel:SetColor(qualityColor:UnpackRGBA())
                else
                    itemLabel:SetColor(0.91, 0.91, 0.93, 1)
                end
            else
                itemLabel:SetColor(0.91, 0.91, 0.93, 1)
            end
            row:GetNamedChild("Bought"):SetText(FormatQuantityAtPrice(entry.purchaseQuantity, entry.purchaseUnitPrice))
            row:GetNamedChild("SaleWhen"):SetText(entry.saleTimestamp and (TP.FormatAge(entry.saleTimestamp):gsub("%.$", "")) or "—")
            row:GetNamedChild("Sold"):SetText(entry.saleQuantity and FormatQuantityAtPrice(entry.saleQuantity, entry.saleUnitPrice) or "—")
        end
    end
    local empty = view:GetNamedChild("Empty")
    empty:SetText(TP.T("ledgerEmpty"))
    empty:SetHidden(#entries > 0)
end

local function RefreshPersonalActivityPeriod()
    local container = TP.window:GetNamedChild("PersonalActivityViewToolbarPeriodFilter")
    if not container or not ZO_ComboBox_ObjectFromContainer then return end
    local comboBox = ZO_ComboBox_ObjectFromContainer(container)
    if not comboBox then return end
    local options = {
        { value = "last7", text = TP.T("activityLast7Days") },
        { value = "current", text = TP.T("activityCurrentWeek") },
        { value = "previous", text = TP.T("activityPreviousWeek") },
        { value = "all", text = TP.T("activityAllTime") },
    }
    comboBox:SetSortsItems(false)
    comboBox:ClearItems()
    local selectedText = options[1] and options[1].text or "—"
    for _, option in ipairs(options) do
        local period = option.value
        comboBox:AddItem(comboBox:CreateItemEntry(option.text, function()
            TP.SetPersonalActivityPeriod(period)
        end))
        if period == TP.personalActivityPeriod then selectedText = option.text end
    end
    comboBox:SetSelectedItemText(selectedText)
end

local function RefreshPersonalActivityUI()
    local view = TP.window:GetNamedChild("PersonalActivityView")
    if not view then return end
    local isPurchase = TP.personalActivityKind ~= "sale"

    local purchasesButton = view:GetNamedChild("ToolbarPurchases")
    local salesButton = view:GetNamedChild("ToolbarSales")
    purchasesButton:SetText(TP.T("activityPurchases"))
    salesButton:SetText(TP.T("activitySales"))
    purchasesButton:GetNamedChild("Active"):SetHidden(not isPurchase)
    salesButton:GetNamedChild("Active"):SetHidden(isPurchase)
    purchasesButton:GetNamedChild("SelectedBackground"):SetHidden(not isPurchase)
    salesButton:GetNamedChild("SelectedBackground"):SetHidden(isPurchase)

    RefreshPersonalActivityPeriod()

    local header = view:GetNamedChild("Header")
    header:GetNamedChild("Item"):SetText(TP.T("ledgerItem"))
    header:GetNamedChild("Guild"):SetText(TP.T("guild"))
    header:GetNamedChild("Amount"):SetText(TP.T(isPurchase and "ledgerBought" or "ledgerSold"))
    header:GetNamedChild("When"):SetText(TP.T(isPurchase and "ledgerPurchaseWhen" or "ledgerSaleWhen"))

    local entries = GetPersonalActivityEntries()
    TP.personalActivityEntryCount = #entries
    local maxOffset = math.max(0, #entries - PERSONAL_ACTIVITY_VISIBLE_ROWS)
    local scrollOffset = zo_clamp(TP.personalActivityScrollOffset or 0, 0, maxOffset)
    TP.personalActivityScrollOffset = scrollOffset
    RefreshGridScrollbar(
        view:GetNamedChild("Scrollbar"),
        #entries,
        PERSONAL_ACTIVITY_VISIBLE_ROWS,
        scrollOffset,
        "settingPersonalActivityScroll"
    )

    local rows = view:GetNamedChild("Rows")
    for index = 1, PERSONAL_ACTIVITY_VISIBLE_ROWS do
        local row = rows:GetNamedChild("Row" .. index)
        local entry = entries[scrollOffset + index]
        row:SetHidden(entry == nil)
        row.itemLink = entry and entry.itemLink or nil
        if entry then
            local itemIcon = row:GetNamedChild("Icon")
            local itemLabel = row:GetNamedChild("Item")
            local iconTexture = entry.itemLink and IsItemLink(entry.itemLink)
                and GetItemLinkIcon(entry.itemLink) or nil
            itemIcon:SetHidden(not iconTexture or iconTexture == "")
            if iconTexture and iconTexture ~= "" then itemIcon:SetTexture(iconTexture) end
            itemLabel:SetText(entry.itemLink or entry.itemName)
            if entry.itemLink and IsItemLink(entry.itemLink) and GetItemLinkDisplayQuality and GetItemQualityColor then
                local qualityColor = GetItemQualityColor(GetItemLinkDisplayQuality(entry.itemLink))
                if qualityColor then
                    itemLabel:SetColor(qualityColor:UnpackRGBA())
                else
                    itemLabel:SetColor(0.91, 0.91, 0.93, 1)
                end
            else
                itemLabel:SetColor(0.91, 0.91, 0.93, 1)
            end
            row:GetNamedChild("Guild"):SetText(entry.guildName)
            local amount = row:GetNamedChild("Amount")
            amount:SetText(FormatQuantityAtPrice(entry.quantity, entry.unitPrice))
            if isPurchase then
                amount:SetColor(0.91, 0.77, 0.42, 1)
            else
                amount:SetColor(0.49, 0.85, 0.54, 1)
            end
            row:GetNamedChild("When"):SetText((TP.FormatAge(entry.timestamp):gsub("%.$", "")))
        end
    end
    local empty = view:GetNamedChild("Empty")
    empty:SetText(TP.T(isPurchase and "activityEmptyPurchases" or "activityEmptySales"))
    empty:SetHidden(#entries > 0)
end

local function RefreshGuildHistoryCombo(controlName, options, selectedValue, filterName, enabled)
    local container = TP.window:GetNamedChild(controlName)
    if not container or not ZO_ComboBox_ObjectFromContainer then return end
    local comboBox = ZO_ComboBox_ObjectFromContainer(container)
    if not comboBox then return end
    local isEnabled = enabled ~= false
    if comboBox.SetEnabled then comboBox:SetEnabled(isEnabled) end
    container:SetAlpha(isEnabled and 1 or 0.55)
    comboBox:SetSortsItems(false)
    comboBox:ClearItems()
    local selectedText = options[1] and options[1].text or "—"
    for _, option in ipairs(options) do
        local filterValue = option.value
        comboBox:AddItem(comboBox:CreateItemEntry(option.text, function()
            TP.SetGuildHistoryFilter(filterName, filterValue)
        end))
        if filterValue == selectedValue then selectedText = option.text end
    end
    comboBox:SetSelectedItemText(selectedText)
end

local function PrependGuildHistoryOption(options, option)
    local result = { option }
    for _, existing in ipairs(options or {}) do result[#result + 1] = existing end
    return result
end

local function RefreshGuildHistoryUI()
    local view = TP.window:GetNamedChild("GuildHistoryView")
    if not view then return end

    local viewData, historyReady = GetGuildHistoryViewData()
    local topFilters = view:GetNamedChild("TopFilters")
    local refreshButton = topFilters:GetNamedChild("Refresh")
    refreshButton:SetText(TP.T("historyRefresh"))
    local refreshEnabled = historyReady
        and not next(analyticsProcessorsPending)
        and guildHistorySnapshotTask == nil
        and GetGameTimeMilliseconds() >= (TP.guildHistoryRefreshAvailableAt or 0)
    refreshButton:SetEnabled(refreshEnabled)
    refreshButton:SetAlpha(refreshEnabled and 1 or 0.45)

    if TP.guildHistoryFiltersDirty then
        local guildOptions = PrependGuildHistoryOption(viewData.guildOptions, {
            value = nil,
            text = TP.T("historyAllGuilds"),
        })
        RefreshGuildHistoryCombo("GuildHistoryViewTopFiltersGuild", guildOptions, TP.guildHistoryGuildId, "guild")
        TP.guildHistoryFiltersDirty = false
    end

    local itemSearch = TP.window:GetNamedChild("GuildHistoryViewTopFiltersItemSearchBox")
    local sellerSearch = TP.window:GetNamedChild("GuildHistoryViewPlayerFiltersSellerSearchBox")
    local buyerSearch = TP.window:GetNamedChild("GuildHistoryViewPlayerFiltersBuyerSearchBox")
    if itemSearch and itemSearch.SetDefaultText then itemSearch:SetDefaultText(TP.T("historyItemSearch")) end
    if sellerSearch and sellerSearch.SetDefaultText then sellerSearch:SetDefaultText(TP.T("historySellerSearch")) end
    if buyerSearch and buyerSearch.SetDefaultText then buyerSearch:SetDefaultText(TP.T("historyBuyerSearch")) end

    local header = view:GetNamedChild("Header")
    header:GetNamedChild("Item"):SetText(TP.T("ledgerItem"))
    header:GetNamedChild("Guild"):SetText(TP.T("guild"))
    header:GetNamedChild("Seller"):SetText(TP.T("historySeller"))
    header:GetNamedChild("Buyer"):SetText(TP.T("historyBuyer"))
    header:GetNamedChild("Sold"):SetText(TP.T("ledgerSold"))
    header:GetNamedChild("SaleWhen"):SetText(TP.T("ledgerSaleWhen"))

    local entries = viewData.entries
    TP.guildHistoryEntryCount = #entries
    local maxOffset = math.max(0, #entries - GUILD_HISTORY_VISIBLE_ROWS)
    local scrollOffset = zo_clamp(TP.guildHistoryScrollOffset or 0, 0, maxOffset)
    TP.guildHistoryScrollOffset = scrollOffset
    RefreshGridScrollbar(
        view:GetNamedChild("Scrollbar"),
        #entries,
        GUILD_HISTORY_VISIBLE_ROWS,
        scrollOffset,
        "settingGuildHistoryScroll"
    )

    local rows = view:GetNamedChild("Rows")
    for index = 1, GUILD_HISTORY_VISIBLE_ROWS do
        local row = rows:GetNamedChild("Row" .. index)
        local entry = entries[scrollOffset + index]
        row:SetHidden(entry == nil)
        row.itemLink = entry and entry.itemLink or nil
        if entry then
            local itemIcon = row:GetNamedChild("Icon")
            local itemLabel = row:GetNamedChild("Item")
            local iconTexture = entry.itemLink and IsItemLink(entry.itemLink)
                and GetItemLinkIcon(entry.itemLink) or nil
            itemIcon:SetHidden(not iconTexture or iconTexture == "")
            if iconTexture and iconTexture ~= "" then itemIcon:SetTexture(iconTexture) end
            itemLabel:SetText(entry.itemLink or entry.itemName)
            if entry.itemLink and IsItemLink(entry.itemLink) and GetItemLinkDisplayQuality and GetItemQualityColor then
                local qualityColor = GetItemQualityColor(GetItemLinkDisplayQuality(entry.itemLink))
                if qualityColor then
                    itemLabel:SetColor(qualityColor:UnpackRGBA())
                else
                    itemLabel:SetColor(0.91, 0.91, 0.93, 1)
                end
            else
                itemLabel:SetColor(0.91, 0.91, 0.93, 1)
            end
            row:GetNamedChild("Guild"):SetText(entry.guildName)
            row:GetNamedChild("Seller"):SetText(entry.seller)
            row:GetNamedChild("Buyer"):SetText(entry.buyer)
            row:GetNamedChild("Sold"):SetText(FormatQuantityAtPrice(entry.quantity, entry.unitPrice))
            row:GetNamedChild("SaleWhen"):SetText((TP.FormatAge(entry.timestamp):gsub("%.$", "")))
        end
    end
    local empty = view:GetNamedChild("Empty")
    if not historyReady then
        empty:SetText(TP.T(TP.historyLoadingStarted
            and "historyLoading" or "historyWaitingForLibHistoire"))
    else
        empty:SetText(TP.T("historyEmpty"))
    end
    empty:SetHidden(historyReady and #entries > 0)
end

local function RefreshWeeklyAnalyticsUI()
    local view = TP.window:GetNamedChild("WeeklyAnalyticsView")
    if not view then return end
    local showingMine = TP.weeklyAnalyticsScope ~= "all"
    local myButton = view:GetNamedChild("ScopeToolbarMy")
    local allButton = view:GetNamedChild("ScopeToolbarAll")
    myButton:SetText(TP.T("analyticsMy"))
    allButton:SetText(TP.T("analyticsAll"))
    myButton:GetNamedChild("Active"):SetHidden(not showingMine)
    allButton:GetNamedChild("Active"):SetHidden(showingMine)
    myButton:GetNamedChild("SelectedBackground"):SetHidden(not showingMine)
    allButton:GetNamedChild("SelectedBackground"):SetHidden(showingMine)

    local showingCurrent = TP.weeklyAnalyticsPeriod ~= "previous"
    local currentButton = view:GetNamedChild("ToolbarCurrent")
    local previousButton = view:GetNamedChild("ToolbarPrevious")
    currentButton:SetText(TP.T("analyticsCurrentWeek"))
    previousButton:SetText(TP.T("analyticsPreviousWeek"))
    currentButton:GetNamedChild("Active"):SetHidden(not showingCurrent)
    previousButton:GetNamedChild("Active"):SetHidden(showingCurrent)
    currentButton:GetNamedChild("SelectedBackground"):SetHidden(not showingCurrent)
    previousButton:GetNamedChild("SelectedBackground"):SetHidden(showingCurrent)

    local guildRows, sellerRows, analyticsReady = GetWeeklyAnalytics()
    local refreshButton = view:GetNamedChild("ToolbarRefresh")
    refreshButton:SetText(TP.T("analyticsRefresh"))
    local refreshEnabled = analyticsReady
        and not next(analyticsProcessorsPending)
        and weeklyAnalyticsSnapshotTask == nil
        and GetGameTimeMilliseconds() >= (TP.weeklyAnalyticsRefreshAvailableAt or 0)
    refreshButton:SetEnabled(refreshEnabled)
    refreshButton:SetAlpha(refreshEnabled and 1 or 0.45)
    local guildHeader = view:GetNamedChild("GuildSummaryHeader")
    guildHeader:GetNamedChild("Guild"):SetText(TP.T("analyticsGuild"))
    guildHeader:GetNamedChild("Current"):SetText(TP.T("analyticsCurrent"))
    guildHeader:GetNamedChild("Previous"):SetText(TP.T("analyticsPrevious"))
    local guildContainer = view:GetNamedChild("GuildSummaryRows")
    local allCurrentTurnover, allPreviousTurnover = 0, 0
    for _, entry in ipairs(guildRows) do
        allCurrentTurnover = allCurrentTurnover + (entry.currentTurnover or 0)
        allPreviousTurnover = allPreviousTurnover + (entry.previousTurnover or 0)
    end
    local displayedGuildRows = {
        {
            guildName = TP.T("analyticsAllGuilds"),
            isAll = true,
            currentTurnover = showingMine and allCurrentTurnover or nil,
            previousTurnover = showingMine and allPreviousTurnover or nil,
        },
    }
    for _, entry in ipairs(guildRows) do displayedGuildRows[#displayedGuildRows + 1] = entry end
    for index = 1, 6 do
        local row = guildContainer:GetNamedChild("Row" .. index)
        local entry = displayedGuildRows[index]
        row:SetHidden(entry == nil)
        row.analyticsGuildId = entry and (entry.isAll and false or entry.guildId) or nil
        if entry then
            local isSelected = entry.isAll
                and TP.weeklyAnalyticsGuildId == nil
                or (not entry.isAll and tonumber(entry.guildId) == tonumber(TP.weeklyAnalyticsGuildId))
            row:GetNamedChild("Guild"):SetText(entry.guildName)
            row:GetNamedChild("Current"):SetText(entry.currentTurnover ~= nil
                and ZO_CommaDelimitNumber(math.floor(entry.currentTurnover + 0.5)) or "")
            row:GetNamedChild("Previous"):SetText(entry.previousTurnover ~= nil
                and ZO_CommaDelimitNumber(math.floor(entry.previousTurnover + 0.5)) or "")
            row:GetNamedChild("Selected"):SetHidden(not isSelected)
            row:GetNamedChild("Background"):SetCenterColor(
                isSelected and 0.10 or 0.045,
                isSelected and 0.085 or 0.049,
                isSelected and 0.04 or 0.059,
                isSelected and 0.82 or 0.72)
        end
    end

    local sellerHeader = view:GetNamedChild("SellerHeader")
    sellerHeader:GetNamedChild("Seller"):SetText(TP.T("analyticsSeller"))
    sellerHeader:GetNamedChild("Guild"):SetText(TP.T("analyticsGuild"))
    sellerHeader:GetNamedChild("Sales"):SetText(TP.T("analyticsSales"))
    sellerHeader:GetNamedChild("Lots"):SetText(TP.T("analyticsLots"))

    TP.weeklyAnalyticsEntryCount = #sellerRows
    local maxOffset = math.max(0, #sellerRows - WEEKLY_ANALYTICS_VISIBLE_ROWS)
    local scrollOffset = zo_clamp(TP.weeklyAnalyticsScrollOffset or 0, 0, maxOffset)
    TP.weeklyAnalyticsScrollOffset = scrollOffset
    RefreshGridScrollbar(
        view:GetNamedChild("Scrollbar"),
        #sellerRows,
        WEEKLY_ANALYTICS_VISIBLE_ROWS,
        scrollOffset,
        "settingWeeklyAnalyticsScroll"
    )
    local sellerContainer = view:GetNamedChild("SellerRows")
    local playerDisplayName = NormalizeHistoryPlayer(GetDisplayName())
    for index = 1, WEEKLY_ANALYTICS_VISIBLE_ROWS do
        local row = sellerContainer:GetNamedChild("Row" .. index)
        local entry = sellerRows[scrollOffset + index]
        row:SetHidden(entry == nil)
        if entry then
            local isPlayer = entry.isPlayer == true
                or NormalizeHistoryPlayer(entry.seller) == playerDisplayName
            local background = row:GetNamedChild("Background")
            background:SetCenterColor(
                isPlayer and 0.035 or 0.045,
                isPlayer and 0.095 or 0.049,
                isPlayer and 0.055 or 0.059,
                isPlayer and 0.78 or 0.72)
            row:GetNamedChild("Seller"):SetText(entry.seller)
            row:GetNamedChild("Guild"):SetText(entry.guildName)
            row:GetNamedChild("Sales"):SetText(ZO_CommaDelimitNumber(math.floor(entry.sales + 0.5)))
            row:GetNamedChild("Lots"):SetText(ZO_CommaDelimitNumber(entry.lots))
        end
    end
    local empty = view:GetNamedChild("Empty")
    local emptyTextKey = analyticsReady and "analyticsEmpty"
        or TP.historyLoadingStarted and "analyticsLoading"
        or "historyWaitingForLibHistoire"
    empty:SetText(TP.T(emptyTextKey))
    empty:SetHidden(analyticsReady and #sellerRows > 0)
end

local function RefreshStockUI()
    local view = TP.window:GetNamedChild("StockView")
    if not view then return end
    local options = GetStockItemOptions()
    if TP.stockItemKey == nil or not OptionExists(options, TP.stockItemKey) then
        local selectedKey = GetSelectedKey()
        TP.stockItemKey = OptionExists(options, selectedKey) and selectedKey
            or (options[1] and options[1].value or nil)
        TP.stockListingScrollOffset = 0
        TP.ensureStockSelectedVisible = true
    end

    local selectedIndex
    for index, option in ipairs(options) do
        if option.value == TP.stockItemKey then
            selectedIndex = index
            break
        end
    end

    TP.stockItemEntryCount = #options
    local itemMaxOffset = math.max(0, #options - STOCK_ITEM_VISIBLE_ROWS)
    local itemScrollOffset = zo_clamp(TP.stockItemScrollOffset or 0, 0, itemMaxOffset)
    if TP.ensureStockSelectedVisible and selectedIndex then
        if selectedIndex <= itemScrollOffset then
            itemScrollOffset = selectedIndex - 1
        elseif selectedIndex > itemScrollOffset + STOCK_ITEM_VISIBLE_ROWS then
            itemScrollOffset = selectedIndex - STOCK_ITEM_VISIBLE_ROWS
        end
    end
    TP.stockItemScrollOffset = zo_clamp(itemScrollOffset, 0, itemMaxOffset)
    TP.ensureStockSelectedVisible = false
    RefreshGridScrollbar(
        view:GetNamedChild("ItemScrollbar"),
        #options,
        STOCK_ITEM_VISIBLE_ROWS,
        TP.stockItemScrollOffset,
        "settingStockItemScroll"
    )

    local itemHeader = view:GetNamedChild("ItemHeader")
    itemHeader:GetNamedChild("Item"):SetText(TP.T("ledgerItem"))
    itemHeader:GetNamedChild("Stock"):SetText(TP.T("stockTracked"))
    itemHeader:GetNamedChild("Listed"):SetText(TP.T("stockListed"))
    itemHeader:GetNamedChild("Unlisted"):SetText(TP.T("stockUnlisted"))

    local itemRows = view:GetNamedChild("ItemRows")
    for index = 1, STOCK_ITEM_VISIBLE_ROWS do
        local row = itemRows:GetNamedChild("Row" .. index)
        local option = options[TP.stockItemScrollOffset + index]
        row:SetHidden(option == nil)
        row.itemKey = option and option.value or nil
        row.itemLink = option and option.itemLink or nil
        if option then
            local data = GetStockViewData(option.value)
            local isSelected = option.value == TP.stockItemKey
            row:GetNamedChild("SelectedBackground"):SetHidden(not isSelected)
            row:GetNamedChild("Selected"):SetHidden(not isSelected)
            local itemIcon = row:GetNamedChild("Icon")
            local itemLabel = row:GetNamedChild("Item")
            local iconTexture = option.itemLink and IsItemLink(option.itemLink)
                and GetItemLinkIcon(option.itemLink) or nil
            itemIcon:SetHidden(not iconTexture or iconTexture == "")
            if iconTexture and iconTexture ~= "" then itemIcon:SetTexture(iconTexture) end
            itemLabel:SetText(option.itemLink or option.text)
            if option.itemLink and IsItemLink(option.itemLink) and GetItemLinkDisplayQuality and GetItemQualityColor then
                local qualityColor = GetItemQualityColor(GetItemLinkDisplayQuality(option.itemLink))
                if qualityColor then
                    itemLabel:SetColor(qualityColor:UnpackRGBA())
                else
                    itemLabel:SetColor(0.91, 0.91, 0.93, 1)
                end
            else
                itemLabel:SetColor(0.91, 0.91, 0.93, 1)
            end
            row:GetNamedChild("Stock"):SetText(ZO_CommaDelimitNumber(math.floor(data.trackedStock + 0.5)))
            row:GetNamedChild("Listed"):SetText(ZO_CommaDelimitNumber(math.floor(data.activeQuantity + 0.5)))
            row:GetNamedChild("Unlisted"):SetText(ZO_CommaDelimitNumber(math.floor(data.unlistedQuantity + 0.5)))
        end
    end
    local stockEmpty = view:GetNamedChild("StockEmpty")
    stockEmpty:SetText(TP.T("stockAllItemsEmpty"))
    stockEmpty:SetHidden(#options > 0)

    local data = GetStockViewData(TP.stockItemKey)

    local listingHeader = view:GetNamedChild("ListingHeader")
    listingHeader:GetNamedChild("Guild"):SetText(TP.T("stockGuild"))
    listingHeader:GetNamedChild("Quantity"):SetText(TP.T("stockQuantity"))
    listingHeader:GetNamedChild("Unit"):SetText(TP.T("stockUnitPrice"))
    listingHeader:GetNamedChild("Total"):SetText(TP.T("stockTotalPrice"))
    listingHeader:GetNamedChild("Remaining"):SetText(TP.T("stockRemaining"))

    TP.stockListingEntryCount = #data.listings
    local maxOffset = math.max(0, #data.listings - STOCK_LISTING_VISIBLE_ROWS)
    local scrollOffset = zo_clamp(TP.stockListingScrollOffset or 0, 0, maxOffset)
    TP.stockListingScrollOffset = scrollOffset
    RefreshGridScrollbar(
        view:GetNamedChild("Scrollbar"),
        #data.listings,
        STOCK_LISTING_VISIBLE_ROWS,
        scrollOffset,
        "settingStockListingScroll"
    )
    local listingRows = view:GetNamedChild("ListingRows")
    for index = 1, STOCK_LISTING_VISIBLE_ROWS do
        local row = listingRows:GetNamedChild("Row" .. index)
        local entry = data.listings[scrollOffset + index]
        row:SetHidden(entry == nil)
        if entry then
            local guild = row:GetNamedChild("Guild")
            guild:SetText(entry.guildName)
            guild:SetColor(0.91, 0.91, 0.93, 1)
            row:GetNamedChild("Quantity"):SetText(ZO_CommaDelimitNumber(math.floor(entry.quantity + 0.5)))
            row:GetNamedChild("Unit"):SetText(ZO_CommaDelimitNumber(math.floor(entry.unitPrice + 0.5)))
            row:GetNamedChild("Total"):SetText(ZO_CommaDelimitNumber(math.floor(entry.totalPrice + 0.5)))
            row:GetNamedChild("Remaining"):SetText(FormatListingTimeRemaining(entry.expiresAt))
        end
    end
    local empty = view:GetNamedChild("Empty")
    empty:SetText(TP.T(TP.stockItemKey and "stockListingsEmpty" or "stockAllItemsEmpty"))
    empty:SetHidden(#data.listings > 0)
end

local function RefreshItemSelector(selected, controlName)
    local container = TP.window:GetNamedChild(controlName or "ItemViewSelector")
    if not container or not ZO_ComboBox_ObjectFromContainer then return end
    local comboBox = ZO_ComboBox_ObjectFromContainer(container)
    if not comboBox then return end
    if comboBox.SetFont then comboBox:SetFont("ZoFontGameLarge") end
    local itemIcon = container:GetNamedChild("ItemIcon")
    local selectedTextControl = container:GetNamedChild("SelectedItemText")
    local iconTexture = selected and selected.icon
    if (not iconTexture or iconTexture == "") and selected and IsItemLink(selected.link) then
        iconTexture = GetItemLinkIcon(selected.link)
    end
    if itemIcon then
        itemIcon:SetHidden(not iconTexture or iconTexture == "")
        if iconTexture and iconTexture ~= "" then itemIcon:SetTexture(iconTexture) end
    end
    if selectedTextControl then
        selectedTextControl:SetFont("ZoFontGameLarge")
        selectedTextControl:ClearAnchors()
        selectedTextControl:SetAnchor(LEFT, container, LEFT, 58, 0)
        selectedTextControl:SetAnchor(RIGHT, container, RIGHT, -44, 0)
        selectedTextControl:SetVerticalAlignment(TEXT_ALIGN_CENTER)
        if selected and IsItemLink(selected.link) and GetItemLinkDisplayQuality and GetItemQualityColor then
            local qualityColor = GetItemQualityColor(GetItemLinkDisplayQuality(selected.link))
            if qualityColor then
                selectedTextControl:SetColor(qualityColor:UnpackRGBA())
            else
                selectedTextControl:SetColor(0.91, 0.91, 0.93, 1)
            end
        else
            selectedTextControl:SetColor(0.91, 0.91, 0.93, 1)
        end
    end
    comboBox:SetSortsItems(false)
    comboBox:ClearItems()
    local selectedEntry
    local selectedKey = GetSelectedKey()
    for _, itemKey in ipairs(GetAlphabeticalTrackedItemKeys()) do
        local item = TP.SV.trackedItems[itemKey]
        if item then
            local entryKey = itemKey
            local displayName = item.name or item.link or "—"
            local entryIcon = item.icon
            if (not entryIcon or entryIcon == "") and IsItemLink(item.link) then
                entryIcon = GetItemLinkIcon(item.link)
            end
            local entryText = displayName
            if entryIcon and entryIcon ~= "" then
                if zo_iconTextFormat then
                    entryText = zo_iconTextFormat(entryIcon, 30, 30, displayName)
                else
                    entryText = string.format("|t30:30:%s|t  %s", entryIcon, displayName)
                end
            end
            local entry = comboBox:CreateItemEntry(entryText, function()
                TP.SetActiveItem(entryKey)
            end)
            if selected and entryKey == selectedKey then
                entry.m_normalColor = ZO_ColorDef:New(0.91, 0.77, 0.42, 1)
                entry.m_highlightColor = ZO_ColorDef:New(1, 1, 1, 1)
                selectedEntry = entry
            end
            comboBox:AddItem(entry)
        end
    end
    if selectedEntry and comboBox.SelectItem then
        comboBox:SelectItem(selectedEntry, true)
    end
    comboBox:SetSelectedItemText(selected and (selected.name or selected.link) or TP.T("noItem"))
end

local function RefreshMarketSaleRow(row, entry)
    row:SetHidden(entry == nil)
    if not entry then return end

    local background = row:GetNamedChild("Background")
    local personalMarker = row:GetNamedChild("PersonalMarker")
    if entry.isPersonal then
        local r, g, b, a = TP.GetPersonalSaleColor()
        local targetR, targetG, targetB = r * 0.22, g * 0.22, b * 0.22
        background:SetCenterColor(
            0.045 + (targetR - 0.045) * a,
            0.049 + (targetG - 0.049) * a,
            0.059 + (targetB - 0.059) * a,
            0.72 + (0.88 - 0.72) * a)
        personalMarker:SetCenterColor(r, g, b, a)
        personalMarker:SetHidden(false)
    else
        background:SetCenterColor(0.045, 0.049, 0.059, 0.72)
        personalMarker:SetHidden(true)
    end
    row:GetNamedChild("Guild"):SetText(entry.guildName)
    row:GetNamedChild("Sold"):SetText(FormatQuantityAtPrice(entry.quantity, entry.unitPrice))
    row:GetNamedChild("SaleWhen"):SetText((TP.FormatAge(entry.timestamp):gsub("%.$", "")))
end

local function RefreshItemUI(selected)
    local view = TP.window:GetNamedChild("ItemView")
    if not view then return end
    RefreshItemSelector(selected, "ItemViewSelector")

    local guilds = GetSelectedTradingGuilds()
    view:GetNamedChild("Configure"):SetText(string.format(TP.T("configureTradingGuilds"), #guilds))
    local selectedGuildAvailable = TP.selectedItemGuildId == nil
    for _, guild in ipairs(guilds) do
        if guild.id == TP.selectedItemGuildId then selectedGuildAvailable = true end
    end
    if not selectedGuildAvailable then
        TP.selectedItemGuildId = nil
        TP.itemSalesScrollOffset = 0
    end

    local tabs = view:GetNamedChild("GuildTabs")
    for index = 1, 6 do
        local tab = tabs:GetNamedChild("Tab" .. index)
        local guild = index > 1 and guilds[index - 1] or nil
        local visible = index == 1 or guild ~= nil
        tab:SetHidden(not visible)
        tab.guildId = guild and guild.id or nil
        if visible then
            tab:SetText(guild and guild.name or TP.T("itemAllGuilds"))
            local isSelected = guild and guild.id == TP.selectedItemGuildId
                or index == 1 and TP.selectedItemGuildId == nil
            tab:GetNamedChild("SelectedBackground"):SetHidden(not isSelected)
            tab:GetNamedChild("Active"):SetHidden(not isSelected)
        end
    end

    local header = view:GetNamedChild("Header")
    header:GetNamedChild("Guild"):SetText(TP.T("recentGuild"))
    header:GetNamedChild("Sold"):SetText(TP.T("ledgerSold"))
    header:GetNamedChild("SaleWhen"):SetText(TP.T("ledgerSaleWhen"))

    local entries = GetRecentMarketSales(GetSelectedKey(), TP.selectedItemGuildId)
    TP.itemSalesEntryCount = #entries
    local maxOffset = math.max(0, #entries - ITEM_SALES_VISIBLE_ROWS)
    local scrollOffset = zo_clamp(TP.itemSalesScrollOffset or 0, 0, maxOffset)
    TP.itemSalesScrollOffset = scrollOffset
    RefreshGridScrollbar(view:GetNamedChild("Scrollbar"), #entries, ITEM_SALES_VISIBLE_ROWS, scrollOffset, "settingItemSalesScroll")

    local rows = view:GetNamedChild("Rows")
    for index = 1, ITEM_SALES_VISIBLE_ROWS do
        RefreshMarketSaleRow(rows:GetNamedChild("Row" .. index), entries[scrollOffset + index])
    end
    local empty = view:GetNamedChild("Empty")
    empty:SetText(not selected and TP.T("noItem")
        or #guilds > 0 and TP.T("recentEmpty")
        or TP.T("itemGuildsEmpty"))
    empty:SetHidden(#entries > 0)
end

function TP.ShowGridItemTooltip(control)
    local row = control and control:GetParent()
    local itemLink = row and row.itemLink
    if not itemLink or not IsItemLink(itemLink) or not ItemTooltip then return end
    ClearTooltip(ItemTooltip)
    InitializeTooltip(ItemTooltip, control, BOTTOM, 0, -6, TOP)
    ItemTooltip:SetLink(itemLink)
end

function TP.HideGridItemTooltip()
    if ItemTooltip then ClearTooltip(ItemTooltip) end
end

function TP.OpenGridItemLink(control, button, upInside)
    if not upInside then return end
    local row = control and control:GetParent()
    local itemLink = row and row.itemLink
    if not itemLink or not IsItemLink(itemLink) then return end
    ZO_LinkHandler_OnLinkMouseUp(itemLink, button, control)
end

function TP.RefreshUI()
    if not TP.window or not TP.SV or TP.window:IsHidden() then return end

    local selected = TP.SV.selectedItem
    SetLabelText("TitleBarTitle", TP.T("title"))
    SetLabelText("TitleBarPortfolioTab", TP.T("tabPortfolio"))
    SetLabelText("TitleBarLedgerTab", TP.T("tabLedger"))
    SetLabelText("TitleBarPersonalActivityTab", TP.T("tabPersonalActivity"))
    SetLabelText("TitleBarGuildHistoryTab", TP.T("tabGuildHistory"))
    SetLabelText("TitleBarWeeklyAnalyticsTab", TP.T("tabWeeklyAnalytics"))
    SetLabelText("TitleBarStockTab", TP.T("tabStock"))
    SetLabelText("TitleBarItemTab", TP.T("tabItem"))
    SetViewVisibility()

    if TP.activeView == "ledger" then
        RefreshLedgerUI()
        return
    elseif TP.activeView == "personalActivity" then
        RefreshPersonalActivityUI()
        return
    elseif TP.activeView == "guildHistory" then
        RefreshGuildHistoryUI()
        return
    elseif TP.activeView == "weeklyAnalytics" then
        RefreshWeeklyAnalyticsUI()
        return
    elseif TP.activeView == "stock" then
        RefreshStockUI()
        return
    elseif TP.activeView == "item" then
        RefreshItemUI(selected)
        return
    end

    local summary = TP.CalculateSummary()
    SetLabelText("OverallRemove", TP.T("removeItem"))
    local removeButton = TP.window:GetNamedChild("OverallRemove")
    if removeButton then removeButton:SetEnabled(selected ~= nil) end
    RefreshOverallUI(selected, summary)
end

function TP.QueueRefresh(fromSalesProcessor)
    if fromSalesProcessor and salesBulkLoadActive then return end
    if TP.activeView == "weeklyAnalytics" or TP.activeView == "guildHistory" then return end
    if TP.refreshPending then
        if not fromSalesProcessor then TP.refreshPendingSalesOnly = false end
        return
    end
    TP.refreshPending = true
    TP.refreshPendingSalesOnly = fromSalesProcessor == true
    zo_callLater(function()
        local salesOnly = TP.refreshPendingSalesOnly
        TP.refreshPending = false
        TP.refreshPendingSalesOnly = nil
        if salesOnly and salesBulkLoadActive then return end
        TP.RefreshUI()
    end, 100)
end

function TP.OnWindowInitialized(window)
    TP.window = window
    window:SetHandler("OnMoveStop", function()
        if TP.SV then
            TP.SV.windowLeft = window:GetLeft()
            TP.SV.windowTop = window:GetTop()
        end
    end)
    window:SetHandler("OnShow", function()
        TP.RefreshUI()
    end)
    window:SetHandler("OnHide", function()
        TP.CloseTradingGuilds()
        TP.HideGridItemTooltip()
    end)
end

function TP.ToggleWindow()
    if not TP.window then return end
    TP.window:SetHidden(not TP.window:IsHidden())
end

function TP.CloseWindow()
    if TP.window then TP.window:SetHidden(true) end
end

function TP.GetPersonalSaleColor()
    local color = TP.SV and TP.SV.personalSaleColor or defaults.personalSaleColor
    if type(color) ~= "table" then color = defaults.personalSaleColor end
    local r = zo_clamp(tonumber(color.r or color[1]) or defaults.personalSaleColor.r, 0, 1)
    local g = zo_clamp(tonumber(color.g or color[2]) or defaults.personalSaleColor.g, 0, 1)
    local b = zo_clamp(tonumber(color.b or color[3]) or defaults.personalSaleColor.b, 0, 1)
    local a = zo_clamp(tonumber(color.a or color[4]) or defaults.personalSaleColor.a, 0, 1)
    return r, g, b, a
end

function TP.ApplyAppearanceSettings()
    if not TP.window or not TP.SV then return end
    local surface = TP.window:GetNamedChild("Surface")
    if not surface then return end

    local opacity = tonumber(TP.SV.backgroundOpacity) or defaults.backgroundOpacity
    opacity = zo_clamp(opacity, 40, 100)
    surface:SetCenterColor(0.025, 0.028, 0.035, opacity / 100)
end

function TP.ApplySceneSettings()
    if not TP.window or not TP.SV then return end
    TP.sceneFragment = TP.sceneFragment or ZO_FadeSceneFragment:New(TP.window)

    local enableMail = TP.SV.openWithMail == true
    if enableMail and not TP.mailFragmentsAttached then
        if MAIL_INBOX_SCENE then MAIL_INBOX_SCENE:AddFragment(TP.sceneFragment) end
        if MAIL_SEND_SCENE then MAIL_SEND_SCENE:AddFragment(TP.sceneFragment) end
        TP.mailFragmentsAttached = true
    elseif not enableMail and TP.mailFragmentsAttached then
        if MAIL_INBOX_SCENE then MAIL_INBOX_SCENE:RemoveFragment(TP.sceneFragment) end
        if MAIL_SEND_SCENE then MAIL_SEND_SCENE:RemoveFragment(TP.sceneFragment) end
        TP.mailFragmentsAttached = false
    end

    local enableStore = TP.SV.openWithStore == true
    if enableStore and not TP.storeFragmentAttached then
        if TRADING_HOUSE_SCENE then TRADING_HOUSE_SCENE:AddFragment(TP.sceneFragment) end
        TP.storeFragmentAttached = true
    elseif not enableStore and TP.storeFragmentAttached then
        if TRADING_HOUSE_SCENE then TRADING_HOUSE_SCENE:RemoveFragment(TP.sceneFragment) end
        TP.storeFragmentAttached = false
    end
end

function TP.SetupSettings()
    local LAM = LibAddonMenu2
    if not LAM then return end

    local panelName = "TheProfitOptions"
    LAM:RegisterAddonPanel(panelName, {
        type = "panel",
        name = "The Profit",
        displayName = "|cE7C56AThe Profit|r",
        author = "manukartofanu",
        version = TP.version,
        registerForRefresh = true,
        registerForDefaults = true,
    })

    LAM:RegisterOptionControls(panelName, {
        {
            type = "header",
            name = TP.T("appearanceHeader"),
        },
        {
            type = "slider",
            name = TP.T("backgroundOpacity"),
            tooltip = TP.T("backgroundOpacityTooltip"),
            min = 40,
            max = 100,
            step = 1,
            decimals = 0,
            clampInput = true,
            getFunc = function()
                return tonumber(TP.SV.backgroundOpacity) or defaults.backgroundOpacity
            end,
            setFunc = function(value)
                TP.SV.backgroundOpacity = value
                TP.ApplyAppearanceSettings()
            end,
            default = defaults.backgroundOpacity,
        },
        {
            type = "colorpicker",
            name = TP.T("personalSaleColor"),
            tooltip = TP.T("personalSaleColorTooltip"),
            getFunc = function()
                return TP.GetPersonalSaleColor()
            end,
            setFunc = function(r, g, b, a)
                TP.SV.personalSaleColor = { r = r, g = g, b = b, a = tonumber(a) or 1 }
                TP.RefreshUI()
            end,
            showAlpha = true,
            default = defaults.personalSaleColor,
        },
        {
            type = "header",
            name = TP.T("settingsHeader"),
        },
        {
            type = "checkbox",
            name = TP.T("openWithMail"),
            tooltip = TP.T("openWithMailTooltip"),
            getFunc = function() return TP.SV.openWithMail end,
            setFunc = function(value)
                TP.SV.openWithMail = value
                TP.ApplySceneSettings()
            end,
            default = defaults.openWithMail,
        },
        {
            type = "checkbox",
            name = TP.T("openWithStore"),
            tooltip = TP.T("openWithStoreTooltip"),
            getFunc = function() return TP.SV.openWithStore end,
            setFunc = function(value)
                TP.SV.openWithStore = value
                TP.ApplySceneSettings()
            end,
            default = defaults.openWithStore,
        },
    })
end

local function SnapshotPurchase(slotIndex)
    if not slotIndex then return nil end
    local _, _, _, quantity, seller, _, price, _, uniqueId = GetTradingHouseSearchResultItemInfo(slotIndex)
    local itemLink = GetTradingHouseSearchResultItemLink(slotIndex)
    if not IsItemLink(itemLink) then return nil end

    local guildId, guildName = GetCurrentTradingHouseGuildDetails()
    return {
        id = SafeId64ToString(uniqueId) or string.format("%d:%d:%d", GetTimeStamp(), slotIndex, price or 0),
        itemKey = TP.GetItemKey(itemLink),
        itemLink = itemLink,
        quantity = quantity or 0,
        price = price or 0,
        seller = seller,
        guildId = guildId,
        guildName = guildName,
        timestamp = GetTimeStamp(),
        kind = "purchase",
        status = "uncertain",
    }
end

local function GetPurchaseKey(purchase)
    return tostring(purchase.guildId or 0) .. ":" .. tostring(purchase.id or "unknown") .. ":" .. tostring(purchase.price or 0)
end

function TP.RecordSubmittedPurchase()
    local purchase = TP.purchaseCandidate
    TP.purchaseCandidate = nil
    if not purchase or not IsItemLink(purchase.itemLink) then return end

    local key = GetPurchaseKey(purchase)
    local existing = TP.SV.purchases[key]
    if not existing then
        TP.SV.purchases[key] = purchase
        if TP.runtime then AddIndexedRecord(TP.runtime.purchasesByItem, key, purchase) end
        InvalidatePersonalActivity("purchase")
    elseif existing.status == "failed" then
        existing.status = "uncertain"
        existing.timestamp = purchase.timestamp
        InvalidatePersonalActivity("purchase")
    end
    InvalidateItemSummary((existing or purchase).itemKey)
    TP.currentPurchaseKey = key
    TP.RefreshUI()
    RequestPrioritySave()
end

function TP.UpdateCurrentPurchase(status)
    local key = TP.currentPurchaseKey
    local purchase = key and TP.SV.purchases[key]
    if not purchase then return end
    purchase.status = status
    purchase.resolvedAt = GetTimeStamp()
    InvalidateItemSummary(purchase.itemKey)
    if status == "confirmed" or status == "failed" then
        TP.currentPurchaseKey = nil
    end
    TP.RefreshUI()
    RequestPrioritySave()
end

local function PurchaseFromAGS(itemData)
    if not itemData or not IsItemLink(itemData.itemLink) then return nil end
    return {
        id = SafeId64ToString(itemData.itemUniqueId) or tostring(GetTimeStamp()),
        itemKey = TP.GetItemKey(itemData.itemLink),
        itemLink = itemData.itemLink,
        quantity = itemData.stackCount or 0,
        price = itemData.purchasePrice or 0,
        seller = itemData.sellerName,
        guildId = itemData.guildId,
        guildName = itemData.guildName,
        timestamp = GetTimeStamp(),
        kind = "purchase",
        status = "confirmed",
    }
end

function TP.OnAGSPurchase(itemData, succeeded)
    local purchase = PurchaseFromAGS(itemData)
    if not purchase then return end
    local key = GetPurchaseKey(purchase)
    local existing = TP.SV.purchases[key]
    if existing then
        existing.status = succeeded and "confirmed" or "failed"
        existing.resolvedAt = GetTimeStamp()
    else
        purchase.status = succeeded and "confirmed" or "failed"
        TP.SV.purchases[key] = purchase
        if TP.runtime then AddIndexedRecord(TP.runtime.purchasesByItem, key, purchase) end
        InvalidatePersonalActivity("purchase")
    end
    InvalidateItemSummary((existing or purchase).itemKey)
    if TP.currentPurchaseKey == key then TP.currentPurchaseKey = nil end
    TP.RefreshUI()
    RequestPrioritySave()
end

function TP.SetupPurchaseTracking()
    EM:RegisterForEvent(TP.name .. "PurchaseCandidate", EVENT_TRADING_HOUSE_CONFIRM_ITEM_PURCHASE, function(_, slotIndex)
        TP.purchaseCandidate = SnapshotPurchase(slotIndex)
    end)

    SecurePostHook("ConfirmPendingItemPurchase", function()
        TP.RecordSubmittedPurchase()
    end)

    EM:RegisterForEvent(TP.name .. "PurchaseResponse", EVENT_TRADING_HOUSE_RESPONSE_RECEIVED, function(_, responseType, result)
        if responseType ~= TRADING_HOUSE_RESULT_PURCHASE_PENDING or not TP.currentPurchaseKey then return end
        if result == TRADING_HOUSE_RESULT_SUCCESS then
            TP.UpdateCurrentPurchase("confirmed")
        elseif result ~= TRADING_HOUSE_RESULT_PURCHASE_PENDING then
            TP.UpdateCurrentPurchase("failed")
        end
    end)

    if AwesomeGuildStore and AwesomeGuildStore.RegisterCallback and AwesomeGuildStore.callback then
        local purchaseActivity = AwesomeGuildStore.class and AwesomeGuildStore.class.PurchaseItemActivity
        if purchaseActivity then
            ZO_PreHook(purchaseActivity, "ConfirmPurchase", function(activity)
                local purchase = PurchaseFromAGS(activity.itemData)
                if purchase then
                    purchase.status = "uncertain"
                    TP.purchaseCandidate = purchase
                end
                return false
            end)
        end

        AwesomeGuildStore:RegisterCallback(AwesomeGuildStore.callback.ITEM_PURCHASED, function(itemData)
            TP.OnAGSPurchase(itemData, true)
        end)
        -- A timeout is not a reliable failure in ESO: the purchase can still have
        -- reached the server. Keep the submitted entry uncertain unless the native
        -- response event explicitly rejects it.
    end
end

local LISTING_DEFAULT_DURATION = 30 * DAY
local LISTING_HISTORY_RETENTION = 90 * DAY
local LISTING_RECONCILE_DELAY_MS = 1000
local listingReconcileGeneration = 0

local function NextListingId()
    TP.SV.listingSequence = math.max(0, math.floor(tonumber(TP.SV.listingSequence) or 0)) + 1
    return string.format("%d:%d", GetTimeStamp(), TP.SV.listingSequence)
end

local function SnapshotSubmittedListing(bagId, slotIndex, stackCount, desiredPrice)
    if bagId == nil or slotIndex == nil then return nil end
    local itemLink = GetItemLink(bagId, slotIndex)
    if not IsItemLink(itemLink) then return nil end

    local quantity = math.max(1, math.floor(tonumber(stackCount) or 1))
    local price = math.max(0, math.floor(tonumber(desiredPrice) or 0))
    local guildId, guildName = GetCurrentTradingHouseGuildDetails()
    local now = GetTimeStamp()
    local id = NextListingId()
    local listingFee = GetSaleFees(price)
    return {
        id = id,
        itemKey = TP.GetItemKey(itemLink),
        itemLink = itemLink,
        itemName = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(itemLink)),
        icon = GetItemLinkIcon(itemLink),
        quantity = quantity,
        price = price,
        unitPrice = quantity > 0 and price / quantity or price,
        guildId = guildId,
        guildName = guildName,
        timestamp = now,
        createdAt = now,
        expiresAt = now + LISTING_DEFAULT_DURATION,
        kind = "listing",
        status = "pending",
        listingFee = listingFee,
        source = "post",
    }
end

local function SnapshotServerListing(listingIndex, guildId, guildName)
    if not ZO_TradingHouse_CreateListingItemData then return nil end
    local succeeded, data = pcall(ZO_TradingHouse_CreateListingItemData, listingIndex)
    if not succeeded or type(data) ~= "table" or not IsItemLink(data.itemLink) then return nil end

    local now = GetTimeStamp()
    local quantity = math.max(1, math.floor(tonumber(data.stackCount) or 1))
    local price = math.max(0, math.floor(tonumber(data.purchasePrice) or 0))
    local timeRemaining = math.max(0, tonumber(data.timeRemaining) or LISTING_DEFAULT_DURATION)
    local createdAt = now - math.max(0, LISTING_DEFAULT_DURATION - timeRemaining)
    return {
        serverId = SafeId64ToString(data.uniqueId or data.itemUniqueId),
        itemKey = TP.GetItemKey(data.itemLink),
        itemLink = data.itemLink,
        itemName = data.name or zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(data.itemLink)),
        icon = data.icon or GetItemLinkIcon(data.itemLink),
        quantity = quantity,
        price = price,
        unitPrice = quantity > 0 and price / quantity or price,
        guildId = guildId,
        guildName = guildName,
        timestamp = createdAt,
        createdAt = createdAt,
        observedAt = now,
        expiresAt = now + timeRemaining,
        kind = "listing",
        status = "active",
        listingFee = GetSaleFees(price),
        source = "reconciled",
    }
end

local function FindMatchingListing(snapshot, allowedStatuses, usedIds)
    if not snapshot or not snapshot.itemKey then return nil end
    local best, bestScore
    for key, listing in pairs(TP.SV.listings or {}) do
        local statusAllowed = not allowedStatuses or allowedStatuses[listing.status] == true
        if statusAllowed and not (usedIds and usedIds[tostring(key)])
            and tostring(listing.itemKey or "") == tostring(snapshot.itemKey)
            and tonumber(listing.guildId or 0) == tonumber(snapshot.guildId or 0)
            and tonumber(listing.quantity or 0) == tonumber(snapshot.quantity or 0)
            and tonumber(listing.price or 0) == tonumber(snapshot.price or 0) then
            local sameServerId = snapshot.serverId and listing.serverId
                and tostring(snapshot.serverId) == tostring(listing.serverId)
            local expiryDifference = math.abs((tonumber(listing.expiresAt) or 0) - (tonumber(snapshot.expiresAt) or 0))
            local score = (sameServerId and -1000000000 or 0) + expiryDifference
            if not bestScore or score < bestScore then
                best = listing
                bestScore = score
            end
        end
    end
    return best
end

local function UpdateListingFromSnapshot(listing, snapshot)
    listing.serverId = snapshot.serverId or listing.serverId
    listing.itemLink = snapshot.itemLink or listing.itemLink
    listing.itemName = snapshot.itemName or listing.itemName
    listing.icon = snapshot.icon or listing.icon
    listing.quantity = snapshot.quantity or listing.quantity
    listing.price = snapshot.price or listing.price
    listing.unitPrice = snapshot.unitPrice or listing.unitPrice
    listing.guildId = snapshot.guildId or listing.guildId
    listing.guildName = snapshot.guildName or listing.guildName
    listing.observedAt = snapshot.observedAt or GetTimeStamp()
    listing.expiresAt = snapshot.expiresAt or listing.expiresAt
    listing.listingFee = snapshot.listingFee or listing.listingFee
    listing.status = "active"
    listing.missingAt = nil
end

local function RefreshListingExpirations()
    if not TP.SV or not TP.SV.listings then return false end
    local now = GetTimeStamp()
    local changed = false
    for _, listing in pairs(TP.SV.listings or {}) do
        if (listing.status == "active" or listing.status == "missing")
            and tonumber(listing.expiresAt)
            and tonumber(listing.expiresAt) <= now then
            listing.status = "expired"
            listing.resolvedAt = now
            changed = true
        end
    end
    return changed
end

local function PruneListingHistory()
    if not TP.SV or not TP.SV.listings then return false end
    local cutoff = GetTimeStamp() - LISTING_HISTORY_RETENTION
    local changed = false
    for key, listing in pairs(TP.SV.listings or {}) do
        if listing.status ~= "active" and listing.status ~= "missing"
            and (tonumber(listing.resolvedAt) or tonumber(listing.createdAt) or 0) < cutoff then
            TP.SV.listings[key] = nil
            changed = true
        end
    end
    return changed
end

function TP.ReconcileCurrentGuildListings()
    if not TP.SV or not TP.SV.listings or not GetNumTradingHouseListings then return false end
    local guildId, guildName = GetCurrentTradingHouseGuildDetails()
    if not guildId then return false end

    local seen = {}
    local activeStatuses = { active = true, missing = true }
    local count = math.max(0, tonumber(GetNumTradingHouseListings()) or 0)
    local changed = false
    for listingIndex = 1, count do
        local snapshot = SnapshotServerListing(listingIndex, guildId, guildName)
        if snapshot then
            local listing = FindMatchingListing(snapshot, activeStatuses, seen)
            if not listing then
                local id = NextListingId()
                snapshot.id = id
                TP.SV.listings[id] = snapshot
                listing = snapshot
            else
                UpdateListingFromSnapshot(listing, snapshot)
            end
            seen[tostring(listing.id)] = true
            changed = true
        end
    end

    local now = GetTimeStamp()
    for key, listing in pairs(TP.SV.listings) do
        if tonumber(listing.guildId or 0) == tonumber(guildId)
            and (listing.status == "active" or listing.status == "missing")
            and not seen[tostring(key)] then
            if listing.status ~= "missing" then listing.missingAt = now end
            listing.status = "missing"
            changed = true
        end
    end

    if RefreshListingExpirations() then changed = true end
    if PruneListingHistory() then changed = true end
    if changed then
        RequestPrioritySave()
        TP.QueueRefresh()
    end
    return changed
end

local function ScheduleListingReconciliation()
    listingReconcileGeneration = listingReconcileGeneration + 1
    local generation = listingReconcileGeneration
    local scheduledGuildId = GetCurrentTradingHouseGuildDetails()
    zo_callLater(function()
        if generation ~= listingReconcileGeneration then return end
        local currentGuildId = GetCurrentTradingHouseGuildDetails()
        if not scheduledGuildId or currentGuildId ~= scheduledGuildId then return end
        TP.ReconcileCurrentGuildListings()
    end, LISTING_RECONCILE_DELAY_MS)
end

local function ConfirmSubmittedListing()
    local listing = TP.listingCandidate
    TP.listingCandidate = nil
    if not listing then return false end
    listing.status = "active"
    listing.confirmedAt = GetTimeStamp()
    listing.observedAt = listing.confirmedAt
    local existing = FindMatchingListing(listing, { active = true, missing = true })
    local samePost = existing
        and existing.source == "reconciled"
        and math.abs((tonumber(existing.createdAt) or 0) - (tonumber(listing.createdAt) or 0)) <= 15
    if samePost then
        UpdateListingFromSnapshot(existing, listing)
        existing.confirmedAt = listing.confirmedAt
    else
        TP.SV.listings[tostring(listing.id)] = listing
    end
    RequestPrioritySave()
    TP.QueueRefresh()
    return true
end

local function CaptureCancelledListing(listingIndex)
    local guildId, guildName = GetCurrentTradingHouseGuildDetails()
    local snapshot = SnapshotServerListing(listingIndex, guildId, guildName)
    local listing = FindMatchingListing(snapshot, { active = true, missing = true })
    TP.cancelListingCandidate = listing and tostring(listing.id) or nil
end

local function CaptureCancelledListingByServerId(uniqueId)
    local serverId = SafeId64ToString(uniqueId)
    TP.cancelListingCandidate = nil
    if not serverId then return end
    for key, listing in pairs(TP.SV.listings or {}) do
        if (listing.status == "active" or listing.status == "missing")
            and listing.serverId
            and tostring(listing.serverId) == tostring(serverId) then
            TP.cancelListingCandidate = tostring(key)
            return
        end
    end
end

local function MarkMatchingListingCancelled(guildId, itemLink, price, quantity)
    if not IsItemLink(itemLink) then return false end
    local snapshot = {
        itemKey = TP.GetItemKey(itemLink),
        guildId = guildId,
        price = tonumber(price) or 0,
        quantity = tonumber(quantity) or 0,
    }
    local listing = FindMatchingListing(snapshot, { active = true, missing = true })
    if not listing then return false end
    listing.status = "cancelled"
    listing.resolvedAt = GetTimeStamp()
    RequestPrioritySave()
    TP.QueueRefresh()
    return true
end

local function ConfirmCancelledListing()
    local id = TP.cancelListingCandidate
    TP.cancelListingCandidate = nil
    local listing = id and TP.SV.listings[id]
    if not listing then return false end
    listing.status = "cancelled"
    listing.resolvedAt = GetTimeStamp()
    RequestPrioritySave()
    TP.QueueRefresh()
    return true
end

function TP.MatchSaleToListing(sale)
    if type(sale) ~= "table" or not sale.itemKey then return false end
    local listing = FindMatchingListing(sale, { active = true, missing = true })
    if not listing then
        local best, bestCreatedAt
        for _, candidate in pairs(TP.SV.listings or {}) do
            if (candidate.status == "active" or candidate.status == "missing")
                and candidate.itemKey == sale.itemKey
                and tonumber(candidate.guildId or 0) == tonumber(sale.guildId or 0)
                and tonumber(candidate.price or 0) == tonumber(sale.price or 0) then
                local createdAt = tonumber(candidate.createdAt) or 0
                if not bestCreatedAt or createdAt < bestCreatedAt then
                    best = candidate
                    bestCreatedAt = createdAt
                end
            end
        end
        listing = best
    end
    if not listing then return false end

    listing.status = "sold"
    listing.resolvedAt = tonumber(sale.timestamp) or GetTimeStamp()
    listing.saleId = tostring(sale.id or "")
    RequestPrioritySave()
    return true
end

function TP.GetListings(options)
    options = type(options) == "table" and options or {}
    if RefreshListingExpirations() then RequestPrioritySave() end
    local result = {}
    for _, listing in pairs(TP.SV and TP.SV.listings or {}) do
        local statusMatches = options.status == nil or listing.status == options.status
        local itemMatches = options.itemKey == nil or listing.itemKey == options.itemKey
        local guildMatches = options.guildId == nil or tonumber(listing.guildId) == tonumber(options.guildId)
        if statusMatches and itemMatches and guildMatches then
            result[#result + 1] = CopyFlatListing(listing)
        end
    end
    table.sort(result, function(a, b)
        return (tonumber(a.createdAt) or 0) > (tonumber(b.createdAt) or 0)
    end)
    return result
end

function TP.GetActiveListings(itemKey, guildId)
    return TP.GetListings({ status = "active", itemKey = itemKey, guildId = guildId })
end

function TP.SetupListingTracking()
    SecurePostHook("RequestPostItemOnTradingHouse", function(bagId, slotIndex, stackCount, desiredPrice)
        TP.listingCandidate = SnapshotSubmittedListing(bagId, slotIndex, stackCount, desiredPrice)
    end)

    ZO_PreHook("CancelTradingHouseListing", function(listingIndex)
        CaptureCancelledListing(listingIndex)
        return false
    end)

    ZO_PreHook("CancelTradingHouseListingByItemUniqueId", function(uniqueId)
        CaptureCancelledListingByServerId(uniqueId)
        return false
    end)

    if AwesomeGuildStore and AwesomeGuildStore.RegisterCallback and AwesomeGuildStore.callback
        and AwesomeGuildStore.callback.ITEM_CANCELLED then
        AwesomeGuildStore:RegisterCallback(AwesomeGuildStore.callback.ITEM_CANCELLED, function(guildId, itemLink, price, stackCount)
            MarkMatchingListingCancelled(guildId, itemLink, price, stackCount)
            ScheduleListingReconciliation()
        end)
    end

    EM:RegisterForEvent(TP.name .. "ListingResponse", EVENT_TRADING_HOUSE_RESPONSE_RECEIVED, function(_, responseType, result)
        if responseType == TRADING_HOUSE_RESULT_POST_PENDING then
            if result == TRADING_HOUSE_RESULT_SUCCESS then
                ConfirmSubmittedListing()
            elseif result ~= TRADING_HOUSE_RESULT_POST_PENDING then
                TP.listingCandidate = nil
            end
        elseif responseType == TRADING_HOUSE_RESULT_CANCEL_SALE_PENDING then
            if result == TRADING_HOUSE_RESULT_SUCCESS then
                ConfirmCancelledListing()
                ScheduleListingReconciliation()
            elseif result ~= TRADING_HOUSE_RESULT_CANCEL_SALE_PENDING then
                TP.cancelListingCandidate = nil
            end
        elseif responseType == TRADING_HOUSE_RESULT_LISTINGS_PENDING
            and result == TRADING_HOUSE_RESULT_SUCCESS then
            ScheduleListingReconciliation()
        end
    end)

    EM:RegisterForEvent(TP.name .. "ListingStoreClose", EVENT_CLOSE_TRADING_HOUSE, function()
        listingReconcileGeneration = listingReconcileGeneration + 1
        TP.listingCandidate = nil
        TP.cancelListingCandidate = nil
    end)
end

local function PruneMarketSales(itemKey)
    if not TP.runtime then RebuildRuntimeIndexes() end

    local cutoff = GetTimeStamp() - MARKET_MAX_AGE
    local function PruneItem(keyToPrune)
        local bucket = TP.runtime.marketSalesByItem[keyToPrune] or {}
        for key, sale in pairs(bucket) do
            if not IsTrackedKey(keyToPrune)
                or not IsTradingGuildSelected(tonumber(sale.guildId))
                or (tonumber(sale.timestamp) or 0) < cutoff then
                bucket[key] = nil
                TP.runtime.marketSaleKeys[key] = nil
            end
        end

        if not next(bucket) then TP.runtime.marketSalesByItem[keyToPrune] = nil end
        InvalidateItemSummary(keyToPrune)
    end

    if itemKey then
        PruneItem(itemKey)
        return
    end

    local itemKeys = {}
    for indexedItemKey in pairs(TP.runtime.marketSalesByItem) do
        itemKeys[#itemKeys + 1] = indexedItemKey
    end
    for _, indexedItemKey in ipairs(itemKeys) do PruneItem(indexedItemKey) end
end

local function RecordGuildHistorySale(guildId, guildName, eventId, info, event)
    if not TP.runtime or not IsTradingGuildSelected(guildId) or not IsItemLink(info.itemLink) then return false end
    local timestamp = info.timestampS or event:GetEventTimestampS()
    if not timestamp then return false end
    local eventIdString = SafeId64ToString(eventId) or tostring(timestamp)
    local key = tostring(guildId) .. ":" .. eventIdString
    if TP.runtime.guildHistorySaleKeys[key] then return false end
    TP.runtime.guildHistorySaleKeys[key] = true
    TP.runtime.guildHistorySales[key] = {
        id = eventIdString,
        itemKey = TP.GetItemKey(info.itemLink),
        itemLink = info.itemLink,
        quantity = info.quantity or 0,
        price = info.price or 0,
        guildId = guildId,
        guildName = guildName,
        seller = info.sellerDisplayName,
        buyer = info.buyerDisplayName,
        timestamp = timestamp,
        kind = "guildSale",
    }
    return true
end

local function RecordMarketSale(guildId, guildName, eventId, info, event)
    if not IsTradingGuildSelected(guildId) or not MatchesTrackedItem(info.itemLink) then return false end

    local timestamp = info.timestampS or event:GetEventTimestampS()
    if not timestamp or timestamp < GetTimeStamp() - MARKET_MAX_AGE then return false end

    local eventIdString = SafeId64ToString(eventId) or tostring(timestamp)
    local key = tostring(guildId) .. ":" .. eventIdString
    if TP.runtime and TP.runtime.marketSaleKeys[key] then return false end

    local itemKey = TP.GetItemKey(info.itemLink)
    local sale = {
        id = eventIdString,
        itemKey = itemKey,
        quantity = info.quantity or 0,
        price = info.price or 0,
        guildId = guildId,
        guildName = guildName,
        seller = info.sellerDisplayName,
        timestamp = timestamp,
        kind = "marketSale",
    }
    if TP.runtime then
        TP.runtime.marketSaleKeys[key] = true
        AddIndexedRecord(TP.runtime.marketSalesByItem, key, sale)
        InvalidateItemSummary(itemKey)
    end
    return true
end

function TP.ProcessSaleEvent(guildId, guildName, event)
    local info = event:GetEventInfo()
    if not info or info.eventType ~= GUILD_HISTORY_TRADER_EVENT_ITEM_SOLD then return end

    local eventId = info.eventId or event:GetEventId()
    local player = zo_strlower(UndecorateDisplayName(GetDisplayName()))
    local seller = zo_strlower(UndecorateDisplayName(info.sellerDisplayName or ""))
    local historyChanged = RecordGuildHistorySale(guildId, guildName, eventId, info, event)
    local marketChanged = RecordMarketSale(guildId, guildName, eventId, info, event)
    if seller ~= player then
        if historyChanged or marketChanged then TP.QueueRefresh(true) end
        return
    end

    local eventIdString = SafeId64ToString(eventId) or tostring(info.timestampS or event:GetEventTimestampS())
    local key = tostring(guildId) .. ":" .. eventIdString
    if TP.SV.sales[key] then
        if historyChanged or marketChanged then TP.QueueRefresh(true) end
        return
    end

    local salePrice = info.price or 0
    local listingFee, tradingHouseCut = GetSaleFees(salePrice)
    local sale = {
        id = eventIdString,
        itemKey = TP.GetItemKey(info.itemLink),
        itemLink = info.itemLink,
        quantity = info.quantity or 0,
        price = salePrice,
        -- Guild history's tax is the guild's share, not the seller's full cut.
        listingFee = listingFee,
        tax = tradingHouseCut or 0,
        guildTax = info.tax or 0,
        buyer = info.buyerDisplayName,
        guildId = guildId,
        guildName = guildName,
        timestamp = info.timestampS or event:GetEventTimestampS(),
        kind = "sale",
    }
    TP.SV.sales[key] = sale
    TP.MatchSaleToListing(sale)
    if TP.runtime then AddIndexedRecord(TP.runtime.salesByItem, key, sale) end
    InvalidatePersonalActivity("sale")
    InvalidateItemSummary(sale.itemKey)
    TP.QueueRefresh(true)
end

function TP.StopSalesProcessors()
    for _, processor in pairs(TP.processors) do
        if processor and processor:IsRunning() then processor:Stop() end
    end
    ZO_ClearTable(TP.processors)
end

local salesProcessorStartGeneration = 0
local salesProcessorsStarted = false
local salesReadinessWaiting = false
local salesReadinessRegistrations = {}
local libHistoireRequestsStarted = false
local MaybeStartSalesProcessors

local function GetLibHistoireTraderCache(guildId)
    local internal = LibHistoire and LibHistoire.internal
    local historyCache = internal and internal.historyCache
    if not historyCache then return nil end
    return historyCache:GetCategoryCache(guildId, GUILD_HISTORY_EVENT_CATEGORY_TRADER)
end

local function IsLibHistoireGuildReady(guildId)
    local internal = LibHistoire and LibHistoire.internal
    local historyCache = internal and internal.historyCache
    local guildCache = historyCache and historyCache:GetGuildCache(guildId)
    if not guildCache then return true end

    -- These are the same conditions LibHistoire uses for its green guild bar.
    return guildCache:HasLinked()
        and not guildCache:IsProcessing()
        and not guildCache:HasPendingRequests()
end

local function ClearSalesReadinessRegistrations()
    for _, registration in pairs(salesReadinessRegistrations) do
        registration.cache:UnregisterProcessor(registration.token)
    end
    ZO_ClearTable(salesReadinessRegistrations)
end

local function RegisterSalesReadiness(guildId)
    if salesReadinessRegistrations[guildId] then return true end
    local cache = GetLibHistoireTraderCache(guildId)
    if not cache or not cache.RegisterProcessor or not cache.UnregisterProcessor then return false end

    -- Register interest without creating a processing request. A normal
    -- processor would fall back to the oldest managed event when there is no
    -- event after its start marker and would therefore scan the whole cache.
    local token
    token = {
        GetAddonName = function() return TP.name .. "Readiness" end,
        StopInternal = function(self)
            cache:UnregisterProcessor(self)
            local registration = salesReadinessRegistrations[guildId]
            if registration and registration.token == self then
                salesReadinessRegistrations[guildId] = nil
            end
            return true
        end,
    }
    cache:RegisterProcessor(token)
    salesReadinessRegistrations[guildId] = { cache = cache, token = token }
    return true
end

local function GetSalesProcessorStartTime(guildId, loadFullHistory)
    if loadFullHistory and IsTradingGuildSelected(guildId) then return 0 end

    local previousWeekStart = GetTradingWeekRange("previous")
    local guildKey = tostring(guildId)
    local lastSync = tonumber(TP.SV.salesSyncTimeByGuild[guildKey])
    if lastSync then
        lastSync = math.max(0, lastSync - SALES_SYNC_OVERLAP_SECONDS)
    end

    if IsTradingGuildSelected(guildId) then
        return math.min(lastSync or previousWeekStart, previousWeekStart)
    end
    return lastSync or previousWeekStart
end

local function TryBuildInitialHistorySnapshots(generation)
    if generation ~= analyticsLoadGeneration
        or not TP.runtime
        or analyticsProcessorSetupInProgress then return end
    if next(analyticsProcessorsPending) then return end

    if TP.runtime.marketSalesPrunedGeneration ~= generation then
        PruneMarketSales()
        TP.runtime.marketSalesPrunedGeneration = generation
    end
    if initialSnapshotBuildGeneration == generation then return end
    initialSnapshotBuildGeneration = generation

    local pendingBuilds = 0
    local buildsSucceeded = true
    local function FinishBuild(succeeded)
        if generation ~= analyticsLoadGeneration
            or initialSnapshotBuildGeneration ~= generation then return end
        buildsSucceeded = buildsSucceeded and succeeded
        pendingBuilds = pendingBuilds - 1
        if pendingBuilds > 0 then return end

        initialSnapshotBuildGeneration = nil
        salesBulkLoadActive = false
        if buildsSucceeded then
            if analyticsLoadIncludesFullHistory then TP.fullGuildHistoryLoaded = true end
            RequestPrioritySave()
        end
        TP.RefreshUI()
    end

    if not TP.runtime.guildHistorySnapshot then
        pendingBuilds = pendingBuilds + 1
        BuildGuildHistorySnapshot(generation, FinishBuild)
    end
    if not TP.runtime.weeklyAnalyticsCache then
        pendingBuilds = pendingBuilds + 1
        BuildWeeklyAnalyticsSnapshot(generation, FinishBuild)
    end
    if pendingBuilds == 0 then
        initialSnapshotBuildGeneration = nil
        salesBulkLoadActive = false
        if analyticsLoadIncludesFullHistory then TP.fullGuildHistoryLoaded = true end
        RequestPrioritySave()
        TP.RefreshUI()
    end
end

function TP.SetupGuildSalesProcessor(guildId, guildName, analyticsGeneration, loadFullHistory)
    if not TP.libReady then return end
    salesBulkLoadActive = true

    local existing = TP.processors[guildId]
    if existing and existing:IsRunning() then existing:Stop() end
    TP.processors[guildId] = nil

    local generation = analyticsGeneration or analyticsLoadGeneration
    local guildKey = tostring(guildId)
    if loadFullHistory == nil then loadFullHistory = TP.fullGuildHistoryRequested == true end
    local processor = LibHistoire:CreateGuildHistoryProcessor(guildId, GUILD_HISTORY_EVENT_CATEGORY_TRADER, TP.name)
    if not processor then
        if analyticsProcessorsPending[guildKey] == generation then
            analyticsProcessorsPending[guildKey] = nil
            TryBuildInitialHistorySnapshots(generation)
        end
        return
    end
    local trackAnalyticsLoad = TP.runtime ~= nil
    if trackAnalyticsLoad then analyticsProcessorsPending[guildKey] = generation end

    local callback = function(event)
        TP.ProcessSaleEvent(guildId, guildName, event)
    end
    -- The normal login pass only covers the range needed for market analytics
    -- and any events since the last completed guild sync. Full selected-guild
    -- history is loaded lazily when the History view is opened.
    processor:SetAfterEventTime(GetSalesProcessorStartTime(guildId, loadFullHistory))
    processor:SetEventCallback(callback)
    if trackAnalyticsLoad then
        processor:SetRegisteredForFutureEventsCallback(function()
            if generation ~= analyticsLoadGeneration
                or analyticsProcessorsPending[guildKey] ~= generation then return end
            TP.SV.salesSyncTimeByGuild[guildKey] = GetTimeStamp()
            analyticsProcessorsPending[guildKey] = nil
            TryBuildInitialHistorySnapshots(generation)
        end)
    end
    local started = processor:Start()
    if started then
        TP.processors[guildId] = processor
        TP.historyRangeRetries[guildId] = nil
    elseif trackAnalyticsLoad and analyticsProcessorsPending[guildKey] == generation then
        analyticsProcessorsPending[guildKey] = nil
        TryBuildInitialHistorySnapshots(generation)
    end
end

function TP.SetupSalesProcessors()
    if not TP.libReady then return end

    TP.historyLoadingStarted = true
    analyticsLoadGeneration = analyticsLoadGeneration + 1
    local generation = analyticsLoadGeneration
    CancelHistorySnapshotTasks()
    initialSnapshotBuildGeneration = nil
    salesBulkLoadActive = true
    local loadFullHistory = TP.fullGuildHistoryRequested == true
    analyticsLoadIncludesFullHistory = loadFullHistory
    analyticsProcessorsPending = {}
    analyticsProcessorSetupInProgress = true
    if TP.runtime then
        TP.runtime.guildHistorySnapshot = nil
        TP.runtime.weeklyAnalyticsCache = nil
    end
    TP.RefreshUI()
    for i = 1, GetNumGuilds() do
        local guildId = GetGuildId(i)
        local guildName = GetGuildName(guildId)
        if guildName ~= "" then
            TP.SetupGuildSalesProcessor(guildId, guildName, generation, loadFullHistory)
        end
    end
    analyticsProcessorSetupInProgress = false
    TryBuildInitialHistorySnapshots(generation)
end

function TP.RestartSalesProcessors()
    salesProcessorStartGeneration = salesProcessorStartGeneration + 1
    local generation = salesProcessorStartGeneration
    salesProcessorsStarted = false
    salesReadinessWaiting = true
    TP.historyLoadingStarted = false
    ClearSalesReadinessRegistrations()
    TP.StopSalesProcessors()
    MaybeStartSalesProcessors(generation)
end

MaybeStartSalesProcessors = function(generation)
    if generation ~= salesProcessorStartGeneration
        or not TP.libReady
        or not TP.playerActivated
        or salesProcessorsStarted
        or not salesReadinessWaiting then return end

    local allReady = libHistoireRequestsStarted
    for i = 1, GetNumGuilds() do
        local guildId = GetGuildId(i)
        local guildName = GetGuildName(guildId)
        if guildName ~= "" then
            RegisterSalesReadiness(guildId)
            if not IsLibHistoireGuildReady(guildId) then allReady = false end
        end
    end

    if not allReady then return end
    salesReadinessWaiting = false
    salesProcessorsStarted = true
    ClearSalesReadinessRegistrations()
    TP.SetupSalesProcessors()
end

local function StartSalesProcessorsWhenReady()
    if not TP.libReady or not TP.playerActivated or salesProcessorsStarted then return end
    if not salesReadinessWaiting then
        salesProcessorStartGeneration = salesProcessorStartGeneration + 1
        salesReadinessWaiting = true
    end
    MaybeStartSalesProcessors(salesProcessorStartGeneration)
end

function TP.EnsureFullGuildHistoryLoaded()
    if TP.fullGuildHistoryRequested or TP.fullGuildHistoryLoaded then return end
    TP.fullGuildHistoryRequested = true
    if not TP.libReady or not TP.playerActivated then return end

    if salesProcessorsStarted then
        TP.RestartSalesProcessors()
    else
        StartSalesProcessorsWhenReady()
    end
end

local function MarkGuildRangeLost(guildId, category)
    if category ~= GUILD_HISTORY_EVENT_CATEGORY_TRADER then return end
    TP.historyRangeRetries[guildId] = true
    TP.processors[guildId] = nil
    analyticsProcessorsPending[tostring(guildId)] = analyticsLoadGeneration
    if TP.activeView == "guildHistory" or TP.activeView == "weeklyAnalytics" then TP.RefreshUI() end
end

local function OnLibHistoireCategoryLinked(guildId, category)
    if salesReadinessWaiting then
        -- CATEGORY_LINKED is raised before LibHistoire finishes missed events,
        -- so the readiness predicate still verifies that processing is idle.
        MaybeStartSalesProcessors(salesProcessorStartGeneration)
    end

    if category ~= GUILD_HISTORY_EVENT_CATEGORY_TRADER then return end
    if TP.historyRangeRetries[guildId] and salesProcessorsStarted then
        TP.historyRangeRetries[guildId] = nil
        local guildName = GetGuildName(guildId)
        if guildName ~= "" then TP.SetupGuildSalesProcessor(guildId, guildName) end
    end
end

function TP.SetupLibHistoire()
    EM:RegisterForEvent(TP.name .. "SalesPlayerActivated", EVENT_PLAYER_ACTIVATED, function()
        EM:UnregisterForEvent(TP.name .. "SalesPlayerActivated", EVENT_PLAYER_ACTIVATED)
        TP.playerActivated = true
        StartSalesProcessorsWhenReady()
    end)

    LibHistoire:OnReady(function()
        TP.libReady = true
        InitializeTradingGuildSelection()
        LibHistoire:RegisterCallback(LibHistoire.callback.MANAGED_RANGE_LOST, MarkGuildRangeLost)
        LibHistoire:RegisterCallback(LibHistoire.callback.CATEGORY_LINKED, OnLibHistoireCategoryLinked)

        local internal = LibHistoire.internal
        local historyCache = internal and internal.historyCache
        if historyCache and historyCache.StartRequests and ZO_PostHook then
            -- LibHistoire starts its automatic requests after player activation.
            -- Hook that lifecycle point instead of guessing it with a fixed delay.
            ZO_PostHook(historyCache, "StartRequests", function()
                libHistoireRequestsStarted = true
                if salesReadinessWaiting then
                    MaybeStartSalesProcessors(salesProcessorStartGeneration)
                end
            end)
            if internal.callback.PROCESS_MISSED_EVENTS_FINISHED then
                internal:RegisterCallback(internal.callback.PROCESS_MISSED_EVENTS_FINISHED, function()
                    if salesReadinessWaiting then
                        MaybeStartSalesProcessors(salesProcessorStartGeneration)
                    end
                end)
            end
            if internal.callback.REQUEST_DESTROYED then
                internal:RegisterCallback(internal.callback.REQUEST_DESTROYED, function()
                    if not salesReadinessWaiting then return end
                    local generation = salesProcessorStartGeneration
                    zo_callLater(function()
                        if generation == salesProcessorStartGeneration and salesReadinessWaiting then
                            MaybeStartSalesProcessors(generation)
                        end
                    end, 0)
                end)
            end
            local categoryClass = internal.class and internal.class.GuildHistoryCacheCategory
            if categoryClass and categoryClass.RemoveProcessingRequest then
                ZO_PostHook(categoryClass, "RemoveProcessingRequest", function()
                    if salesReadinessWaiting then
                        MaybeStartSalesProcessors(salesProcessorStartGeneration)
                    end
                end)
            end
        else
            -- Compatibility fallback for a future LibHistoire without internals.
            libHistoireRequestsStarted = true
        end
        StartSalesProcessorsWhenReady()
    end)
end

local function GetInventoryItemLink(inventorySlot)
    local slotType = ZO_InventorySlot_GetType(inventorySlot)
    local bag, index
    if slotType == SLOT_TYPE_TRADING_HOUSE_ITEM_RESULT then
        return GetTradingHouseSearchResultItemLink(ZO_Inventory_GetSlotIndex(inventorySlot))
    elseif slotType == SLOT_TYPE_TRADING_HOUSE_ITEM_LISTING then
        return GetTradingHouseListingItemLink(ZO_Inventory_GetSlotIndex(inventorySlot))
    end

    local rowData = inventorySlot.GetParent and ZO_ScrollList_GetData(inventorySlot:GetParent())
    if rowData and IsItemLink(rowData.itemLink) then return rowData.itemLink end

    bag, index = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if bag and index then return GetItemLink(bag, index) end
    return nil
end

local function AddTrackMenuItem(itemLink)
    if not IsItemLink(itemLink) then return end
    local itemKey = TP.GetItemKey(itemLink)
    local label
    if MatchesSelectedItem(itemLink) then
        label = TP.T("menuOpen")
    elseif IsTrackedKey(itemKey) then
        label = TP.T("menuSelect")
    else
        label = TP.T("menuTrack")
    end
    AddCustomMenuItem(label, function()
        if not MatchesSelectedItem(itemLink) then TP.SetTrackedItem(itemLink) end
        if TP.window then TP.window:SetHidden(false) end
    end)
end

function TP.SetupContextMenus()
    LibCustomMenu:RegisterContextMenu(function(inventorySlot)
        AddTrackMenuItem(GetInventoryItemLink(inventorySlot))
    end)

    SecurePostHook("ZO_LinkHandler_OnLinkMouseUp", function(link, button, control)
        if button == MOUSE_BUTTON_INDEX_RIGHT and IsItemLink(link) then
            AddTrackMenuItem(link)
            ShowMenu(control)
        end
    end)
end

local function HandleSlashCommand(arguments)
    local command, rest = (arguments or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = zo_strlower(command or "")
    if command == "track" then
        local itemLink = (rest or ""):match("(|H%d:item:.-|h.-|h)")
        if itemLink then
            TP.SetTrackedItem(itemLink)
            TP.window:SetHidden(false)
        else
            d("|cE7C56AThe Profit:|r " .. TP.T("missingLink"))
        end
    elseif command == "help" then
        d(TP.T("help1"))
        d(TP.T("help2"))
        d(TP.T("help3"))
    else
        TP.ToggleWindow()
    end
end

local function InitializeWindowPosition()
    TP.window:ClearAnchors()
    TP.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, TP.SV.windowLeft, TP.SV.windowTop)
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= TP.name then return end
    EM:UnregisterForEvent(TP.name, EVENT_ADD_ON_LOADED)

    TP.SV = ZO_SavedVars:NewAccountWide("TheProfitSavedVariables", 1, nil, defaults, GetWorldName())
    TP.SV.trackedItems = TP.SV.trackedItems or {}
    TP.SV.trackedItemOrder = TP.SV.trackedItemOrder or {}

    local migratedItems = {}
    local migratedOrder = {}
    local function AddMigratedItem(item)
        if type(item) ~= "table" or not item.key or migratedItems[item.key] or #migratedOrder >= MAX_TRACKED_ITEMS then return end
        migratedItems[item.key] = item
        migratedOrder[#migratedOrder + 1] = item.key
    end
    for _, itemKey in ipairs(TP.SV.trackedItemOrder) do
        AddMigratedItem(TP.SV.trackedItems[itemKey])
    end
    AddMigratedItem(TP.SV.selectedItem)
    TP.SV.trackedItems = migratedItems
    TP.SV.trackedItemOrder = migratedOrder
    if not TP.SV.selectedItem or not TP.SV.trackedItems[TP.SV.selectedItem.key] then
        TP.SV.selectedItem = migratedOrder[1] and migratedItems[migratedOrder[1]] or nil
    end

    -- Version 3 stops persisting the general market feed. LibHistoire owns that
    -- history; The Profit only caches the selected guilds in memory while logged in.
    TP.SV.marketSales = nil
    TP.SV.lastEventIds = nil
    TP.SV.marketHistoryVersion = 3
    TP.SV.purchases = SanitizeSavedTransactions(TP.SV.purchases)
    TP.SV.sales = SanitizeSavedTransactions(TP.SV.sales)
    TP.SV.listings = SanitizeSavedListings(TP.SV.listings)
    TP.SV.listingSequence = math.max(0, math.floor(tonumber(TP.SV.listingSequence) or 0))
    local salesSyncTimeByGuild = {}
    for guildId, timestamp in pairs(TP.SV.salesSyncTimeByGuild or {}) do
        local numericTimestamp = tonumber(timestamp)
        if numericTimestamp and numericTimestamp > 0 then
            salesSyncTimeByGuild[tostring(guildId)] = math.floor(numericTimestamp)
        end
    end
    TP.SV.salesSyncTimeByGuild = salesSyncTimeByGuild
    RemoveLegacyDuplicateSales()
    InitializeTradingGuildSelection()
    for _, purchase in pairs(TP.SV.purchases) do
        if purchase.status == "pending" then purchase.status = "uncertain" end
    end
    RebuildRuntimeIndexes()
    RefreshListingExpirations()
    PruneListingHistory()

    InitializeWindowPosition()
    TP.ApplyAppearanceSettings()
    TP.SetupSettings()
    TP.ApplySceneSettings()
    TP.SetupPurchaseTracking()
    TP.SetupListingTracking()
    TP.SetupContextMenus()
    TP.SetupLibHistoire()
    TP.RefreshUI()

    SLASH_COMMANDS["/theprofit"] = HandleSlashCommand
end

EM:RegisterForEvent(TP.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
