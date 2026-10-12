local TP = TheProfit

local DAY = ZO_ONE_DAY_IN_SECONDS or 86400
local HISTORY_DAYS = 7
local HISTORY_MAX_AGE = HISTORY_DAYS * DAY

local TARGET_ROI = 0.05
local SALE_FEE_RATE = 0.08
local NET_SALE_RATE = 1 - SALE_FEE_RATE
local TARGET_PROBABILITY = 0.95
local MARKET_SHARE = 0.25
local MAX_HORIZON_DAYS = 3.5
local RISING_TREND_DAMPING = 0.5
local TREND_SIGNIFICANCE = 2
local TRIM_FRACTION = 0.15
local MIN_LEVEL_VOLATILITY = 0.01
local MAX_LISTING_DISCOUNT = 3
local MIN_BAND_TRADES = 15
local BAND_FENCE = 3
local AVERAGE_MIN_TRADES = 30
local MIN_SALE_DAYS = 4
local MIN_SELLERS = 3

local SCORE_BUY = 100
local SCORE_SIMPLE = 50
local SCORE_SKIP = 0

TP.PURCHASE_SCORE_BUY = SCORE_BUY
TP.NET_SALE_RATE = NET_SALE_RATE

local LOG_SQRT_TWO_PI = 0.5 * math.log(2 * math.pi)

-- Keyed by item; reused while CalculateSummary returns the same cached summary table.
local modelCache = {}

-- Abramowitz-Stegun 26.2.17: log of the standard normal upper tail for x >= 0.
local function LogNormalTail(x)
    local t = 1 / (1 + 0.2316419 * x)
    local poly = t * (0.319381530 + t * (-0.356563782 + t * (1.781477937 + t * (-1.821255978 + t * 1.330274429))))
    return -0.5 * x * x - LOG_SQRT_TWO_PI + math.log(poly)
end

local function LogNormalCdf(x)
    if x < 0 then return LogNormalTail(-x) end
    return math.log(1 - math.exp(LogNormalTail(x)))
end

-- Probability that a log-price level with daily drift and variance never falls by
-- more than margin during horizon days (first passage of Brownian motion).
local function SurvivalProbability(margin, drift, dailyVariance, horizon)
    local spread = math.sqrt(dailyVariance * horizon)
    local upper = math.exp(LogNormalCdf((margin + drift * horizon) / spread))
    local lowerLog = -2 * drift * margin / dailyVariance + LogNormalCdf((-margin + drift * horizon) / spread)
    return upper - math.exp(lowerLog)
end

local function FindRequiredMargin(drift, dailyVariance, horizon)
    if SurvivalProbability(MAX_LISTING_DISCOUNT, drift, dailyVariance, horizon) < TARGET_PROBABILITY then return nil end
    local low, high = 0, MAX_LISTING_DISCOUNT
    for _ = 1, 40 do
        local middle = (low + high) / 2
        if SurvivalProbability(middle, drift, dailyVariance, horizon) >= TARGET_PROBABILITY then
            high = middle
        else
            low = middle
        end
    end
    return high
end

-- Records must be sorted by price. Removes the cheapest and the most expensive 15%
-- of quantity into record.kept; a boundary stack is trimmed only by the units needed.
local function TrimQuantity(records, totalQuantity)
    local remainingLowTrim = totalQuantity * TRIM_FRACTION
    for _, record in ipairs(records) do
        local removed = math.min(record.w, remainingLowTrim)
        record.kept = record.w - removed
        remainingLowTrim = remainingLowTrim - removed
    end
    local remainingHighTrim = totalQuantity * TRIM_FRACTION
    for index = #records, 1, -1 do
        local record = records[index]
        local removed = math.min(record.kept, remainingHighTrim)
        record.kept = record.kept - removed
        remainingHighTrim = remainingHighTrim - removed
    end
end

-- Mirrors the sample behind TheProfit's market average (newest trades until a quarter
-- of the last 24 hours volume and at least 30 trades, then the 15% trim) and returns
-- the relative variance of that average. Errors use the sandwich form w^2 * residual^2:
-- a stack sold at the common price adds confidence, an off-price stack adds error.
local function GetAverageVariance(records, lastDayQuantity)
    local recent = {}
    for index, record in ipairs(records) do recent[index] = record end
    table.sort(recent, function(a, b) return a.x > b.x end)

    local targetQuantity = math.max(1, lastDayQuantity / 4)
    local sample, sampleQuantity = {}, 0
    for _, record in ipairs(recent) do
        sample[#sample + 1] = { price = math.exp(record.y), w = record.w }
        sampleQuantity = sampleQuantity + record.w
        if sampleQuantity >= targetQuantity and #sample >= AVERAGE_MIN_TRADES then break end
    end

    table.sort(sample, function(a, b) return a.price < b.price end)
    TrimQuantity(sample, sampleQuantity)
    local keptWeight, weightedPrice, keptTrades = 0, 0, 0
    for _, record in ipairs(sample) do
        if record.kept > 0 then
            keptWeight = keptWeight + record.kept
            weightedPrice = weightedPrice + record.kept * record.price
            keptTrades = keptTrades + 1
        end
    end
    if keptTrades < 2 then return 0 end

    local mean = weightedPrice / keptWeight
    local sandwich = 0
    for _, record in ipairs(sample) do
        local difference = record.price - mean
        sandwich = sandwich + record.kept * record.kept * difference * difference
    end
    return sandwich / (keptWeight * keptWeight * mean * mean) * keptTrades / (keptTrades - 1)
end

local function BuildMarketModel(itemKey)
    local bucket = TP.runtime and TP.runtime.marketSalesByItem[itemKey]
    if not bucket then return { reason = "no market history" } end

    local now = GetTimeStamp()
    local allRecords = {}
    local lastDayQuantity = 0
    for _, sale in pairs(bucket) do
        local quantity = tonumber(sale.quantity) or 0
        local price = tonumber(sale.price) or 0
        local age = now - (tonumber(sale.timestamp) or 0)
        if quantity > 0 and price > 0 and age >= 0 and age <= HISTORY_MAX_AGE then
            allRecords[#allRecords + 1] = {
                x = -age / DAY,
                y = math.log(price / quantity),
                w = quantity,
                day = math.min(HISTORY_DAYS - 1, math.floor(age / DAY)),
                seller = sale.seller,
            }
            if age <= DAY then lastDayQuantity = lastDayQuantity + quantity end
        end
    end
    if #allRecords == 0 then return { reason = "no market history" } end

    -- A trade confirms the price when it is not an extreme outlier by Tukey's fences.
    -- Quartiles are taken over trades, not units, so stacks do not push singles out.
    -- Everything below uses only these trades, so manipulated prices cannot leak into
    -- daily levels, seller counts or volume.
    table.sort(allRecords, function(a, b) return a.y < b.y end)
    local lowerQuartile = allRecords[math.max(1, math.ceil(#allRecords * 0.25))].y
    local upperQuartile = allRecords[math.max(1, math.ceil(#allRecords * 0.75))].y
    local fence = BAND_FENCE * (upperQuartile - lowerQuartile)
    local records = {}
    local totalQuantity = 0
    local days = {}
    local sellers, sellerCount = {}, 0
    for _, record in ipairs(allRecords) do
        if record.y >= lowerQuartile - fence and record.y <= upperQuartile + fence then
            records[#records + 1] = record
            totalQuantity = totalQuantity + record.w

            local stats = days[record.day]
            if not stats then
                stats = { weight = 0, sum = 0, trades = 0, sandwich = 0 }
                days[record.day] = stats
            end
            stats.weight = stats.weight + record.w
            stats.sum = stats.sum + record.w * record.y
            stats.trades = stats.trades + 1

            if record.seller and not sellers[record.seller] then
                sellers[record.seller] = true
                sellerCount = sellerCount + 1
            end
        end
    end
    if #records < MIN_BAND_TRADES then
        return { reason = string.format("trades within price band %d < %d", #records, MIN_BAND_TRADES) }
    end

    -- Days are counted backwards from now, so index 0 is the most recent 24 hours.
    local dayLevels = {}
    for day = HISTORY_DAYS - 1, 0, -1 do
        local stats = days[day]
        if stats then
            stats.level = stats.sum / stats.weight
            dayLevels[#dayLevels + 1] = { day = day, stats = stats }
        end
    end
    if #dayLevels < MIN_SALE_DAYS then
        return { reason = string.format("sales on %d of %d days", #dayLevels, HISTORY_DAYS) }
    end
    if sellerCount < MIN_SELLERS then
        return { reason = string.format("%d sellers < %d", sellerCount, MIN_SELLERS) }
    end

    -- The trend ignores the cheapest and the most expensive 15% of traded quantity.
    TrimQuantity(records, totalQuantity)
    local keptTrades, keptWeight, meanX, meanY = 0, 0, 0, 0
    for _, record in ipairs(records) do
        if record.kept > 0 then
            keptTrades = keptTrades + 1
            keptWeight = keptWeight + record.kept
            meanX = meanX + record.kept * record.x
            meanY = meanY + record.kept * record.y
        end
    end
    if keptTrades <= 2 then return { reason = "too few trades after outlier trim" } end
    meanX = meanX / keptWeight
    meanY = meanY / keptWeight

    local sxx, sxy = 0, 0
    for _, record in ipairs(records) do
        local dx = record.x - meanX
        sxx = sxx + record.kept * dx * dx
        sxy = sxy + record.kept * dx * (record.y - meanY)
    end
    if sxx <= 0 then return { reason = "no time spread for trend" } end

    local slope = sxy / sxx
    local intercept = meanY - slope * meanX
    local sandwich = 0
    for _, record in ipairs(records) do
        local dx = record.x - meanX
        local fitError = record.y - intercept - slope * record.x
        sandwich = sandwich + record.kept * record.kept * dx * dx * fitError * fitError
    end
    local slopeError = math.sqrt(sandwich * keptTrades / (keptTrades - 2)) / sxx

    -- Day-to-day changes of the daily level include sampling noise of each daily
    -- mean; subtracting it leaves the variance of the market level itself.
    for _, record in ipairs(records) do
        local stats = days[record.day]
        local difference = record.y - stats.level
        stats.sandwich = stats.sandwich + record.w * record.w * difference * difference
    end
    local function GetDayNoise(stats)
        if stats.trades < 2 then return 0 end
        return stats.sandwich / (stats.weight * stats.weight) * stats.trades / (stats.trades - 1)
    end

    local changeSum, changeSquares, noiseSum, changeCount = 0, 0, 0, 0
    for index = 2, #dayLevels do
        local previous, current = dayLevels[index - 1], dayLevels[index]
        local gap = previous.day - current.day
        local change = (current.stats.level - previous.stats.level) / math.sqrt(gap)
        changeSum = changeSum + change
        changeSquares = changeSquares + change * change
        noiseSum = noiseSum + (GetDayNoise(previous.stats) + GetDayNoise(current.stats)) / gap
        changeCount = changeCount + 1
    end
    local changeMean = changeSum / changeCount
    local changeVariance = math.max(0, (changeSquares - changeCount * changeMean * changeMean) / (changeCount - 1))
    local levelVariance = math.max(MIN_LEVEL_VOLATILITY * MIN_LEVEL_VOLATILITY, changeVariance - noiseSum / changeCount)

    return {
        available = true,
        dailyVolume = totalQuantity / HISTORY_DAYS,
        slope = slope,
        slopeError = slopeError,
        levelVariance = levelVariance,
        averageVariance = GetAverageVariance(allRecords, lastDayQuantity),
    }
end

local function GetMarketModel(itemKey, summary)
    local cached = modelCache[itemKey]
    if cached and cached.summary == summary then return cached.model end
    local model = BuildMarketModel(itemKey)
    modelCache[itemKey] = { summary = summary, model = model }
    return model
end

local function EvaluateModel(model, summary, unitPrice, quantity)
    if not model.available then return false, model.reason end

    local market = summary.market
    local stock = math.max(0, tonumber(summary.stock) or 0)
    local horizon = (stock + quantity) / (MARKET_SHARE * model.dailyVolume)
    if horizon > MAX_HORIZON_DAYS then
        return false, string.format("sell-through %.1f days > %.1f", horizon, MAX_HORIZON_DAYS)
    end

    local trend = 0
    if model.slope < 0 then
        trend = model.slope
    elseif model.slope > TREND_SIGNIFICANCE * model.slopeError then
        trend = RISING_TREND_DAMPING * model.slope
    end

    -- Uncertainty of today's market average and of the trend are folded into the
    -- level variance over the horizon.
    local trendVariance = (model.slopeError * horizon) ^ 2
    local dailyVariance = model.levelVariance + (model.averageVariance + trendVariance) / horizon

    local margin = FindRequiredMargin(trend, dailyVariance, horizon)
    if not margin then return false, string.format("no safe listing price in %.1f days", horizon) end

    local listingPrice = market.trimmedMean * math.exp(-margin)
    local roi = listingPrice * NET_SALE_RATE / unitPrice - 1
    local description = string.format("ROI %.1f%% listing at %.0f%% of market in %.1f days",
        roi * 100, listingPrice / market.trimmedMean * 100, horizon)
    return roi >= TARGET_ROI, description
end

function TP.IsTrackedItem(itemLink)
    local itemKey = TP.GetItemKey(itemLink)
    return itemKey ~= nil and TP.SV ~= nil and TP.SV.trackedItems ~= nil and TP.SV.trackedItems[itemKey] ~= nil
end

-- Returns 100 (buy), 50 (current market average alone covers fees and ROI) or 0,
-- followed by a short reason for tooltips and debugging.
function TP.EvaluatePurchase(itemLink, unitPrice, quantity)
    unitPrice = tonumber(unitPrice) or 0
    quantity = tonumber(quantity) or 0
    if unitPrice <= 0 or quantity <= 0 then return SCORE_SKIP, "invalid listing" end

    if not TP.IsTrackedItem(itemLink) then return SCORE_SKIP, "not tracked" end
    local itemKey = TP.GetItemKey(itemLink)

    local summary = TP.CalculateSummary(itemKey)
    local market = summary.market
    if not market or not market.available or (market.trimmedMean or 0) <= 0 then
        return SCORE_SKIP, "no market forecast"
    end

    local isGood, reason = EvaluateModel(GetMarketModel(itemKey, summary), summary, unitPrice, quantity)
    if isGood then return SCORE_BUY, reason end

    if market.trimmedMean * NET_SALE_RATE >= unitPrice * (1 + TARGET_ROI) then
        return SCORE_SIMPLE, reason
    end
    return SCORE_SKIP, reason
end
