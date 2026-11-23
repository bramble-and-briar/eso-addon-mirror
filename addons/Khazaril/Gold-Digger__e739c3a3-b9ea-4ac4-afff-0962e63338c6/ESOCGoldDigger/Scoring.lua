-- Gold Digger scoring. Plain calculations with no game calls, so they can be tested off console.

ESOC_GoldDigger = ESOC_GoldDigger or {}
local Scoring = {}
ESOC_GoldDigger.Scoring = Scoring

Scoring.SELL_FEE = 0.08        -- 1% listing fee plus 7% taken from the sale
Scoring.UNDERCUT = 0.02        -- list just under the usual price so it sells
Scoring.MIN_SEEN = 5           -- listings needed before a going rate is trusted
Scoring.MIN_SALES = 3          -- real sales needed to prefer sale prices over listing prices
Scoring.RATE_DAYS = 30
Scoring.SEASON_MIN_DAYS = 42   -- about one event cycle of dated history
Scoring.EVENT_MIN_DAYS = 7     -- normal days needed to compare an event you've marked
Scoring.QUICK_MARGIN = 25
Scoring.SAFE_MARGIN = 35       -- reliable items with no sales data need a bigger discount
Scoring.QUICK_SELL = 50
Scoring.HOLD_MARGIN = 15
Scoring.GLUT_RATIO = 0.8
Scoring.OUTLIER_RATIO = 3
Scoring.HOLD_PROFIT = 1.15     -- sell a held item once it clears 15% after fees
Scoring.TOUR_MARGIN = 20       -- discount needed against live prices in your selling zone
Scoring.MIN_PROFIT = 50        -- not worth a stop for less gold than this
Scoring.AGED_AGE = 7           -- on sale this many days without selling
Scoring.AGED_DISCOUNT = 0.9    -- price below a listing that has failed to sell

local function median(values)
    if #values == 0 then return nil end
    table.sort(values)
    local middle = math.floor((#values + 1) / 2)
    if #values % 2 == 1 then return values[middle] end
    return (values[middle] + values[middle + 1]) / 2
end
Scoring.Median = median

-- History is saved packed. This gives a working copy with ordinary tables.
function Scoring.View(item)
    return ESOC_GoldDigger.History.View(item)
end

-- A joke price shouldn't move the going rate. The listing can still be a bargain.
function Scoring.IsOutlier(price, reference)
    if not reference or reference <= 0 then return false end
    return price > reference * Scoring.OUTLIER_RATIO or price < reference / Scoring.OUTLIER_RATIO
end

-- Adds one price to a day or week summary.
function Scoring.AddPrice(bucket, price)
    bucket.c = bucket.c + 1
    bucket.s = bucket.s + price
    if not bucket.l or price < bucket.l then bucket.l = price end
    if not bucket.h or price > bucket.h then bucket.h = price end
end

-- The usual price, leaving out event days when there are normal days to use.
-- Real sales win when there are enough, otherwise the median day of listings.
function Scoring.GoingRate(item, today)
    item = Scoring.View(item)
    local oldest = today - Scoring.RATE_DAYS
    local function salesRate(includeEvents)
        local units, goldTotal, sales = 0, 0, 0
        for day, bucket in pairs(item.sales or {}) do
            if day >= oldest and (includeEvents or not bucket.e) then
                units, goldTotal, sales = units + bucket.q, goldTotal + bucket.g, sales + bucket.n
            end
        end
        if sales >= Scoring.MIN_SALES and units > 0 then return goldTotal / units, sales end
    end
    local rate, sales = salesRate(false)
    if not rate then rate, sales = salesRate(true) end
    if rate then return rate, "sales", sales end

    local function listingRate(includeEvents)
        local prices, seen = {}, 0
        for day, bucket in pairs(item.days or {}) do
            if day >= oldest and bucket.c > 0 and (includeEvents or not bucket.e) then
                prices[#prices + 1] = bucket.s / bucket.c
                seen = seen + bucket.c
            end
        end
        return prices, seen
    end
    local prices, seen = listingRate(false)
    if seen < Scoring.MIN_SEEN then prices, seen = listingRate(true) end
    if seen < Scoring.MIN_SEEN then return nil, "thin", seen end
    return median(prices), "listings", seen
end

-- What the market is doing this week, event days included.
function Scoring.RecentPrice(item, today)
    item = Scoring.View(item)
    local prices = {}
    for day, bucket in pairs(item.days or {}) do
        if day >= today - 7 and bucket.c > 0 then prices[#prices + 1] = bucket.s / bucket.c end
    end
    return median(prices)
end

-- How far below the going rate, as a percentage. Negative means overpriced.
function Scoring.Margin(price, rate)
    if not rate or rate <= 0 then return nil end
    return (rate - price) / rate * 100
end

function Scoring.ListAt(rate)
    return rate * (1 - Scoring.UNDERCUT)
end

-- Gold left after reselling the stack at this price and paying trader fees.
function Scoring.Profit(unitPrice, quantity, sellPrice)
    if not sellPrice then return nil end
    return (sellPrice * (1 - Scoring.SELL_FEE) - unitPrice) * quantity
end

-- True once a held item can be sold for a worthwhile profit after fees.
function Scoring.ReadyToSell(paid, marketPrice)
    if not marketPrice then return false end
    return Scoring.ListAt(marketPrice) * (1 - Scoring.SELL_FEE) >= paid * Scoring.HOLD_PROFIT
end

-- 0 to 100: recent sales, minus competition, plus a bonus for reliable item types.
function Scoring.SellThrough(item, today, activeListings, isReliableType)
    item = Scoring.View(item)
    local sold = 0
    for day, bucket in pairs(item.sales or {}) do
        if day >= today - 14 then sold = sold + bucket.n end
    end
    local demand = math.min(sold / 7, 1) * 60
    local competition = math.min((activeListings or 0) / 20, 1) * 20
    local score = demand - competition + 20 + (isReliableType and 20 or 0)
    return math.max(0, math.min(100, math.floor(score + 0.5)))
end

-- Compares the last week with normal prices. Returns "blind" until there's enough history.
function Scoring.Seasonal(item, today, eventActive)
    item = Scoring.View(item)
    local earliest, recent, longRun = today, {}, {}
    for day, bucket in pairs(item.days or {}) do
        if bucket.c > 0 then
            if day < earliest then earliest = day end
            local price = bucket.s / bucket.c
            if day >= today - 7 then
                recent[#recent + 1] = price
            elseif not bucket.e then
                longRun[#longRun + 1] = price
            end
        end
    end
    for week, bucket in pairs(item.weeks or {}) do
        if bucket.c > 0 then
            local day = week * 7
            if day < earliest then earliest = day end
            longRun[#longRun + 1] = bucket.s / bucket.c
        end
    end
    local enough = today - earliest >= Scoring.SEASON_MIN_DAYS
        or (eventActive and #longRun >= Scoring.EVENT_MIN_DAYS)
    if not enough or #recent == 0 or #longRun == 0 then return "blind", nil end
    local now, normal = median(recent), median(longRun)
    if now <= normal * Scoring.GLUT_RATIO then return "glut", normal end
    return "normal", normal
end

-- Average, low and high for each of the last few weeks. Index 1 is this week.
function Scoring.WeeklySeries(item, today, count)
    item = Scoring.View(item)
    local thisWeek = math.floor(today / 7)
    local series = {}
    local function add(week, bucket)
        local index = thisWeek - week + 1
        if index < 1 or index > count or bucket.c <= 0 then return end
        local row = series[index] or { c = 0, s = 0 }
        row.c, row.s = row.c + bucket.c, row.s + bucket.s
        if bucket.l and (not row.l or bucket.l < row.l) then row.l = bucket.l end
        if bucket.h and (not row.h or bucket.h > row.h) then row.h = bucket.h end
        if bucket.e then row.e = true end
        series[index] = row
    end
    for week, bucket in pairs(item.weeks or {}) do add(week, bucket) end
    for day, bucket in pairs(item.days or {}) do add(math.floor(day / 7), bucket) end
    return series
end

-- What you could list it for in your selling zone, from the other live listings there.
-- asks is sorted cheapest first, each { id, p, age }. A listing that has sat for days has failed to
-- sell at its price, so the target goes below it. Joke prices are capped by the usual or median price.
function Scoring.SellTarget(asks, listingId, usual, usualSource)
    local lowest, others = nil, 0
    for _, ask in ipairs(asks) do
        if ask.id ~= listingId then
            others = others + 1
            lowest = lowest or ask
        end
    end
    if not lowest or (not usual and others < 2) then return nil end
    local target, slow = lowest.p * (1 - Scoring.UNDERCUT), false
    if lowest.age and lowest.age >= Scoring.AGED_AGE then
        target, slow = lowest.p * Scoring.AGED_DISCOUNT, true
    end
    local cap
    if usual then
        cap = usual * (usualSource == "sales" and 1.1 or 1.25)
    else
        local prices = {}
        for _, ask in ipairs(asks) do prices[#prices + 1] = ask.p end
        cap = median(prices) * 1.2
    end
    if target > cap then target = cap end
    return target, slow
end

-- The per-item numbers, worked out once however many listings the item has.
function Scoring.ItemFacts(item, today, activeListings, isReliableType, eventActive)
    item = Scoring.View(item)
    local rate, source = Scoring.GoingRate(item, today)
    local season, normal = Scoring.Seasonal(item, today, eventActive)
    return { rate = rate, source = source, season = season, normal = normal,
        sell = Scoring.SellThrough(item, today, activeListings, isReliableType) }
end

-- Everything the action list needs for one listing, or nil when there's no usable price.
-- opts may hold asks (live listings in the selling zone), id, age in days and facts.
function Scoring.Evaluate(item, listing, today, activeListings, isReliableType, eventActive, opts)
    opts = opts or {}
    local facts = opts.facts or Scoring.ItemFacts(item, today, activeListings, isReliableType, eventActive)
    local rate, source, sell, season, normal = facts.rate, facts.source, facts.sell, facts.season, facts.normal
    local target, slowMarket
    if opts.asks then target, slowMarket = Scoring.SellTarget(opts.asks, opts.id, rate, source) end
    if not rate and not target then return nil end

    local sellAt = target or Scoring.ListAt(rate)
    local margin = Scoring.Margin(listing.p, sellAt)
    local profit = Scoring.Profit(listing.p, listing.q, sellAt)
    local aged = opts.age ~= nil and opts.age >= Scoring.AGED_AGE
    local flag

    -- Selling into an event glut loses money, so a cheap item then is a hold, not a flip.
    local flooded = season == "glut" or (eventActive and normal ~= nil)
    if flooded and normal and (normal - listing.p) / normal * 100 >= Scoring.HOLD_MARGIN
        and Scoring.Profit(listing.p, listing.q, Scoring.ListAt(normal)) > 0 then
        flag = "hold"
        sellAt = Scoring.ListAt(normal)
        profit = Scoring.Profit(listing.p, listing.q, sellAt)
        margin = Scoring.Margin(listing.p, normal)
    elseif not flooded and profit >= Scoring.MIN_PROFIT then
        -- A cheap listing that has sat for days still hasn't sold, so it needs a bigger discount
        local needed = aged and Scoring.SAFE_MARGIN or (target and Scoring.TOUR_MARGIN or Scoring.QUICK_MARGIN)
        local evidence = sell >= Scoring.QUICK_SELL or (target and (isReliableType or margin >= Scoring.SAFE_MARGIN))
            or (isReliableType and margin >= Scoring.SAFE_MARGIN)
        if margin >= needed and evidence then flag = "flip" end
    end
    return { rate = rate, source = source, margin = margin, profit = profit, sell = sell, sellAt = sellAt,
        season = season, normal = normal, flag = flag, age = opts.age, aged = aged, slowMarket = slowMarket }
end
