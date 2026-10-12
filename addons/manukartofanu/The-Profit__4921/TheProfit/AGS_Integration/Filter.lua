local TP = TheProfit

-- Each filter type has its own id, so a state AGS saved for one type is never read by another.
local FILTER_ID = 210
local REQUIRED_AGS_API_VERSION = 4
local SEARCH_RESULTS_DATA_TYPE = 1
local GUILD_SPECIFIC_ITEM_DATA_TYPE = 3
local TEXT_WIDTH = 50
local TEXT_OFFSET_X = 55
local MAX_CACHED_PRICES = 20000

-- Category ids double as the stored filter values, so they must stay stable.
local GRAY, GREEN, BLUE, PURPLE, GOLD = 0, 1, 2, 3, 4
local CATEGORY_ORDER = { GRAY, GREEN, BLUE, PURPLE, GOLD }
local CATEGORY_LABELS = {
    [GRAY] = "Below 1%",
    [GREEN] = "1% - 15%",
    [BLUE] = "15% - 40%",
    [PURPLE] = "40% - 90%",
    [GOLD] = "90% and more",
}
local CATEGORY_QUALITY = {
    [GREEN] = ITEM_QUALITY_MAGIC,
    [BLUE] = ITEM_QUALITY_ARCANE,
    [PURPLE] = ITEM_QUALITY_ARTIFACT,
    [GOLD] = ITEM_QUALITY_LEGENDARY,
}
local GRAY_COLOR = { 0.65, 0.65, 0.65, 1 }

-- Reading TTC means parsing the link into an item descriptor and walking several
-- nested tables, and AGS asks for every listing of every search, again on each
-- filter change and row refresh. The suggested price only changes when TTC
-- reloads its price table, so it is cached per link until the store is opened
-- again. false marks a link without TTC data.
local priceInfoCache = {}
local priceInfoCount = 0

local function ClearPriceCache()
    priceInfoCache = {}
    priceInfoCount = 0
end

local function GetPriceInfo(itemLink)
    local cached = priceInfoCache[itemLink]
    if cached ~= nil then return cached or nil end

    local info = TamrielTradeCentrePrice and TamrielTradeCentrePrice:GetPriceInfo(itemLink) or false

    if priceInfoCount >= MAX_CACHED_PRICES then ClearPriceCache() end
    priceInfoCache[itemLink] = info
    priceInfoCount = priceInfoCount + 1
    return info or nil
end

local function GetSuggestedPrice(itemLink)
    local info = GetPriceInfo(itemLink)
    local suggested = info and tonumber(info.SuggestedPrice)
    if suggested and suggested > 0 then return suggested end
    return nil
end

-- Shared with the button type of the filter.
TP.SimpleMargin = {}

-- Returns category and discount percent, or nil when there is nothing to compare with.
local function Evaluate(itemData)
    local itemLink = itemData and itemData.itemLink
    if not itemLink or itemLink == "" then return nil end

    local suggested = GetSuggestedPrice(itemLink)
    local stackCount = tonumber(itemData.stackCount) or 1
    local price = tonumber(itemData.purchasePrice)
    if not suggested or not price or stackCount < 1 then return nil end

    local percent = (suggested - price / stackCount) / suggested * 100
    if percent < 1 then return GRAY, percent end
    if percent < 15 then return GREEN, percent end
    if percent < 40 then return BLUE, percent end
    if percent < 90 then return PURPLE, percent end
    return GOLD, percent
end

local function GetCategoryColor(category)
    local quality = CATEGORY_QUALITY[category]
    if not quality then return unpack(GRAY_COLOR) end
    return GetItemQualityColor(quality):UnpackRGBA()
end

TP.SimpleMargin.Evaluate = Evaluate
TP.SimpleMargin.GetPriceInfo = GetPriceInfo
TP.SimpleMargin.GetCategoryColor = GetCategoryColor
TP.SimpleMargin.CATEGORY_ORDER = CATEGORY_ORDER
TP.SimpleMargin.CATEGORY_LABELS = CATEGORY_LABELS
TP.SimpleMargin.GRAY = GRAY

local function CreateTextControl(rowControl)
    local timeControl = rowControl.timeRemaining or rowControl:GetNamedChild("TimeRemaining")
    if not timeControl then return nil end

    -- The time column is anchored at a fixed offset from the row's left edge, so
    -- a fixed offset from it gives every row the same column, whatever the price.
    local text = rowControl:CreateControl(rowControl:GetName() .. "TheProfitSimple", CT_LABEL)
    text:SetDimensions(TEXT_WIDTH, timeControl:GetHeight())
    text:SetFont(timeControl:GetFont())
    text:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    text:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    text:SetMaxLineCount(1)
    text:SetAnchor(LEFT, timeControl, LEFT, TEXT_OFFSET_X, 0)
    rowControl.theProfitSimple = text
    return text
end

local function UpdateTextControl(rowControl, itemData)
    local text = rowControl.theProfitSimple or CreateTextControl(rowControl)
    if not text then return end

    -- Looked up on each call: the Proficient type replaces the evaluation.
    local category, percent = TP.SimpleMargin.Evaluate(itemData)
    if not category then
        text:SetHidden(true)
        return
    end

    text:SetText(percent and string.format("%d%%", zo_round(percent)) or "BUY")
    text:SetColor(GetCategoryColor(category))
    text:SetHidden(false)
end

local function RegisterResultRowRenderer(tradingHouseWrapper)
    if TP.agsRowRendererRegistered then return end

    local tradingHouse = tradingHouseWrapper and tradingHouseWrapper.tradingHouse
    local resultList = tradingHouse and tradingHouse.searchResultsList
    if not resultList then return end

    for _, dataTypeId in ipairs({ SEARCH_RESULTS_DATA_TYPE, GUILD_SPECIFIC_ITEM_DATA_TYPE }) do
        local dataType = ZO_ScrollList_GetDataTypeTable(resultList, dataTypeId)
        if dataType and type(dataType.setupCallback) == "function" then
            SecurePostHook(dataType, "setupCallback", UpdateTextControl)
            TP.agsRowRendererRegistered = true
        end
    end
end

local function GetSteps()
    local steps = {}
    for _, category in ipairs(CATEGORY_ORDER) do
        local quality = CATEGORY_QUALITY[category]
        local color = quality and GetItemQualityColor(quality) or ZO_ColorDef:New(unpack(GRAY_COLOR))
        steps[#steps + 1] = {
            id = category,
            label = CATEGORY_LABELS[category],
            color = color,
            colorizedLabel = color:Colorize(CATEGORY_LABELS[category]),
        }
    end
    return steps
end

local function CreateFilterClass(AGS)
    local FilterBase = AGS.class.FilterBase
    local ValueRangeFilterBase = AGS.class.ValueRangeFilterBase
    local SimpleFilter = ValueRangeFilterBase:Subclass()

    function SimpleFilter:New(...)
        return ValueRangeFilterBase.New(self, ...)
    end

    function SimpleFilter:Initialize()
        ValueRangeFilterBase.Initialize(self, FILTER_ID, FilterBase.GROUP_LOCAL, {
            label = "Simple Margin Filter",
            min = GRAY,
            max = GOLD,
            steps = GetSteps(),
            requiresStepConversion = true,
        })
        local stepById = {}
        for _, step in ipairs(self.config.steps) do stepById[step.id] = step end
        self.stepById = stepById
    end

    function SimpleFilter:CanFilter()
        return true
    end

    -- A listing without a TTC price cannot show a discount, so it counts as gray.
    function SimpleFilter:FilterLocalResult(itemData)
        local category = Evaluate(itemData) or GRAY
        return category >= self.localMin and category <= self.localMax
    end

    function SimpleFilter:GetTooltipText(min, max)
        if self:IsDefault(min, max) then return "" end
        local out = {}
        for id = min, max do
            out[#out + 1] = self.stepById[id].colorizedLabel
        end
        return table.concat(out, ", ")
    end

    return SimpleFilter
end

local function RegisterFilter(AGS)
    if TP.agsFilter then return end

    if AGS:GetFilter(FILTER_ID) then
        d(string.format("|cFF0000The Profit: AwesomeGuildStore filter id %d is already in use.|r", FILTER_ID))
        return
    end

    local filter = CreateFilterClass(AGS):New()
    AGS:RegisterFilter(filter)
    AGS:RegisterFilterFragment(AGS.class.QualityFilterFragment:New(FILTER_ID))
    TP.agsFilter = filter
end

-- Filter types offered by the settings dropdown; other files append their own.
TP.agsFilterTypes = { { value = "simple", name = "Simple" } }

function TP.GetAGSFilterType()
    local selected = TP.SV and TP.SV.agsFilterType
    for _, filterType in ipairs(TP.agsFilterTypes) do
        if filterType.value == selected then return selected end
    end
    return "simple"
end

-- AGS cannot drop a registered filter, so the settings are read once at load and
-- a change needs a UI reload. The row text is shared by all types.
function TP.SetupAGSFilter()
    if not TP.SV or TP.SV.showSimpleFilterInAGS ~= true then return end
    if TP.agsCallbackRegistered then return end

    local AGS = AwesomeGuildStore
    if not AGS or type(AGS.GetAPIVersion) ~= "function" then return end
    if AGS.GetAPIVersion() ~= REQUIRED_AGS_API_VERSION then return end
    if not IsKeyboardUISupported() or not TamrielTradeCentrePrice then return end

    TP.agsCallbackRegistered = true
    if TP.GetAGSFilterType() == "simple" then
        AGS:RegisterCallback(AGS.callback.AFTER_FILTER_SETUP, function()
            RegisterFilter(AGS)
        end)
    end
    AGS:RegisterCallback(AGS.callback.AFTER_INITIAL_SETUP, RegisterResultRowRenderer)
    EVENT_MANAGER:RegisterForEvent(TP.name .. "AGSPrices", EVENT_OPEN_TRADING_HOUSE, ClearPriceCache)
end
