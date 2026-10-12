local TP = TheProfit

-- Experimental button type of the simple margin filter. It shares the
-- evaluation and the row text with Filter.lua and only adds a second filter.
local FILTER_ID = 211
local REQUIRED_AGS_API_VERSION = 4
local MAX_BUTTON_SIZE = 48
local BUTTON_PADDING_Y = 4
local SWATCH_SIZE = 22

-- Category ids and colors are those of the simple filter: gold stands for the
-- yellow state, and the others keep their names.
local GRAY, GREEN, BLUE, PURPLE, GOLD = 0, 1, 2, 3, 4

-- Thresholds. Profit is what is left after the sale fee, for the whole stack.
local PURPLE_MIN_RATIO, PURPLE_MIN_PROFIT = 5, 10000
local BLUE_MIN_RATIO, BLUE_MIN_PROFIT = 3, 5000
local GREEN_MIN_ROI = 0.25
-- A TTC price is reliable when it rests on enough sales that make up a large
-- enough share of the listings. A very liquid item needs a smaller share: its
-- listings pile up faster than they sell.
local MIN_RELIABLE_SALES = 5
local MIN_SALES_SHARE = 0.5
local HIGH_VOLUME_SALES = 200
local HIGH_VOLUME_MIN_SALES_SHARE = 0.2

local CATEGORY_LABELS = {
    [GRAY] = "Other",
    [GREEN] = "ROI 25%+, reliable TTC price",
    [BLUE] = "3x+ below TTC, 5k+ profit",
    [PURPLE] = "5x+ below TTC, 10k+ profit",
    [GOLD] = "Tracked, ready to buy",
}

local function IsReliable(info)
    local sales = tonumber(info.SaleEntryCount)
    local listings = tonumber(info.EntryCount)
    if not sales or not listings or listings <= 0 then return false end
    local minShare = sales >= HIGH_VOLUME_SALES and HIGH_VOLUME_MIN_SALES_SHARE or MIN_SALES_SHARE
    return sales >= MIN_RELIABLE_SALES and sales / listings >= minShare
end

local function IsTrackedBuy(itemLink, unitPrice, stackCount)
    if not TP.EvaluatePurchase or not TP.IsTrackedItem(itemLink) then return false end
    return TP.EvaluatePurchase(itemLink, unitPrice, stackCount) >= TP.PURCHASE_SCORE_BUY
end

-- Same contract as the simple evaluation: category and the discount from the TTC
-- suggested price in percent (nil for the yellow state), or nil category when
-- there is nothing to compare with.
local function Evaluate(itemData)
    local itemLink = itemData and itemData.itemLink
    if not itemLink or itemLink == "" then return nil end

    local stackCount = tonumber(itemData.stackCount) or 1
    local price = tonumber(itemData.purchasePrice)
    if not price or price <= 0 or stackCount < 1 then return nil end
    local unitPrice = price / stackCount

    local info = TP.SimpleMargin.GetPriceInfo(itemLink)
    local suggested = info and tonumber(info.SuggestedPrice)
    if suggested and suggested <= 0 then suggested = nil end
    local percent = suggested and (suggested - unitPrice) / suggested * 100

    -- No percent: the row shows BUY for the yellow state.
    if IsTrackedBuy(itemLink, unitPrice, stackCount) then return GOLD, nil end
    if not suggested then return nil end

    local netUnit = suggested * TP.NET_SALE_RATE
    local ratio = suggested / unitPrice
    local profit = (netUnit - unitPrice) * stackCount
    if ratio >= PURPLE_MIN_RATIO and profit >= PURPLE_MIN_PROFIT then return PURPLE, percent end
    if ratio >= BLUE_MIN_RATIO and profit >= BLUE_MIN_PROFIT then return BLUE, percent end
    if netUnit / unitPrice - 1 >= GREEN_MIN_ROI and IsReliable(info) then return GREEN, percent end
    return GRAY, percent
end

local function GetFilterValues()
    local shared = TP.SimpleMargin
    local values = {}
    for _, category in ipairs(shared.CATEGORY_ORDER) do
        values[#values + 1] = {
            id = category,
            label = CATEGORY_LABELS[category],
            icon = "EsoUI/Art/Inventory/inventory_tabIcon_all_%s.dds",
        }
    end
    return values
end

local function CreateFilterClass(AGS)
    local shared = TP.SimpleMargin
    local FilterBase = AGS.class.FilterBase
    local MultiChoiceFilterBase = AGS.class.MultiChoiceFilterBase
    local ButtonFilter = MultiChoiceFilterBase:Subclass()

    function ButtonFilter:New(...)
        return MultiChoiceFilterBase.New(self, ...)
    end

    function ButtonFilter:Initialize()
        MultiChoiceFilterBase.Initialize(self, FILTER_ID, FilterBase.GROUP_LOCAL, "Proficient Margin Filter", GetFilterValues())
    end

    function ButtonFilter:CanFilter()
        return true
    end

    -- A listing without a TTC price cannot show a discount, so it counts as gray.
    function ButtonFilter:FilterLocalResult(itemData)
        local category = shared.Evaluate(itemData) or shared.GRAY
        return self.localSelection[self.valueById[category]] == true
    end

    return ButtonFilter
end

local function CreateFragmentClass(AGS)
    local Base = AGS.class.MultiButtonFilterFragment
    local ButtonFragment = Base:Subclass()

    function ButtonFragment:New(...)
        return Base.New(self, ...)
    end

    -- Stock layout packs seven 32 px buttons per row; here all five share one
    -- row and take the whole width of the filter panel.
    function ButtonFragment:InitializeControls()
        local container = self:GetContainer()
        local values = self.filter:GetRawValues()
        local spacing = container:GetWidth() / #values
        local size = math.min(MAX_BUTTON_SIZE, spacing)

        local buttons = {}
        local buttonsByValue = {}
        for i, value in ipairs(values) do
            local button = self:CreateButton(container, i, value)
            button:SetSize(size)
            button:SetAnchor(CENTER, container, TOPLEFT, spacing * (i - 0.5), size / 2 + BUTTON_PADDING_Y)
            buttons[i] = button
            buttonsByValue[value] = button
        end
        self.buttons = buttons
        self.buttonsByValue = buttonsByValue
    end

    -- The stock buttons share one icon; a swatch in the quality color tells them apart.
    function ButtonFragment:CreateButton(container, index, value)
        local button = Base.CreateButton(self, container, index, value)
        local swatch = button:GetControl():CreateControl(nil, CT_TEXTURE)
        swatch:SetDimensions(SWATCH_SIZE, SWATCH_SIZE)
        swatch:SetAnchor(CENTER, button:GetControl(), CENTER, 0, 0)
        swatch:SetColor(TP.SimpleMargin.GetCategoryColor(value.id))
        swatch:SetMouseEnabled(false)
        return button
    end

    return ButtonFragment
end

local function RegisterFilter(AGS)
    if TP.agsButtonFilter then return end

    if AGS:GetFilter(FILTER_ID) then
        d(string.format("|cFF0000The Profit: AwesomeGuildStore filter id %d is already in use.|r", FILTER_ID))
        return
    end

    local filter = CreateFilterClass(AGS):New()
    AGS:RegisterFilter(filter)
    AGS:RegisterFilterFragment(CreateFragmentClass(AGS):New(FILTER_ID))
    TP.agsButtonFilter = filter
end

TP.agsFilterTypes[#TP.agsFilterTypes + 1] = { value = "proficient", name = "Proficient" }

local setupSimpleFilter = TP.SetupAGSFilter

function TP.SetupAGSFilter()
    setupSimpleFilter()
    if not TP.agsCallbackRegistered or TP.agsButtonCallbackRegistered then return end
    if TP.GetAGSFilterType() ~= "proficient" then return end

    TP.SimpleMargin.Evaluate = Evaluate

    local AGS = AwesomeGuildStore
    if AGS.GetAPIVersion() ~= REQUIRED_AGS_API_VERSION then return end

    TP.agsButtonCallbackRegistered = true
    AGS:RegisterCallback(AGS.callback.AFTER_FILTER_SETUP, function()
        RegisterFilter(AGS)
    end)
end
