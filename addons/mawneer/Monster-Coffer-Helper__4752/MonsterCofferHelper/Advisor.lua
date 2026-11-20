local MCH = MonsterCofferHelper

local Advisor = {}
MCH.Advisor = Advisor

--------------------------------------------------------------------------------
-- The question this addon answers
--------------------------------------------------------------------------------
--
-- A Mystery Coffer is cheap but may hand you a shoulder you already own.
-- A curated coffer costs several times more and always hands you one you lack.
-- Because the goal is to collect every shoulder, each new piece is worth exactly
-- as much as any other, so the two offers can be compared on a single number:
-- keys spent per NEW shoulder.
--
--     mystery:  cost / P(the roll is something new)
--     curated:  cost                                  (P is 1 by definition)
--
-- Buy whichever number is lower. P is the part players cannot work out at a
-- glance, and it is what Model.lua goes and measures.
--
-- A Mystery Coffer rolls uniformly across every shoulder the vendor stocks,
-- collected or not. So with N shoulders on the shelf and M still missing,
-- P = M/N.
--------------------------------------------------------------------------------

local function Harmonic(n)
    local sum = 0.0
    for i = 1, n do sum = sum + 1.0 / i end
    return sum
end

-- Expected keys to finish the vendor's whole shoulder pool.
--
-- With m of N still missing, each Mystery Coffer is a hit with probability m/N,
-- so one new piece costs mysteryCost * N / m on average. Summing that from
-- m = M down to 1 is a harmonic series -- the coupon collector's problem.
--
-- Mystery gets steadily worse as m shrinks while curated stays flat, so the
-- cheapest run is mystery early and curated for the tail. The switch point is
-- where the two per-piece costs meet: mysteryCost * N / m = curatedCost.
local function Project(pool, mysteryCost, curatedCost)
    local N, M = pool.total, pool.missing

    local allMystery = mysteryCost * N * Harmonic(M)
    local allCurated = curatedCost * M

    local switchAt = math.floor(mysteryCost * N / curatedCost)
    local optimal
    if switchAt >= M then
        -- Already past the break-even point; curated all the way.
        switchAt = M
        optimal  = allCurated
    else
        optimal = mysteryCost * N * (Harmonic(M) - Harmonic(switchAt)) + curatedCost * switchAt
    end

    return {
        optimal    = optimal,
        allMystery = allMystery,
        allCurated = allCurated,
        switchAt   = switchAt,
        switchToGo = M - switchAt,
    }
end

--------------------------------------------------------------------------------
-- Public entry point
--------------------------------------------------------------------------------

-- Returns nil when there is nothing to reason about (no stock data at all).
function Advisor.Evaluate(pool, mysteryCost, curatedCost)
    if not pool or pool.total == 0 then return nil end

    local r = {
        pool        = pool,
        total       = pool.total,
        owned       = pool.owned,
        missing     = pool.missing,
        mysteryCost = mysteryCost,
        curatedCost = curatedCost,
    }

    if pool.missing == 0 then
        r.verdict   = MCH.VERDICT_DONE
        r.chanceNew = 0
        return r
    end

    r.chanceNew     = pool.missing / pool.total
    r.mysteryPerNew = mysteryCost / r.chanceNew
    r.curatedPerNew = curatedCost

    if r.mysteryPerNew < curatedCost then
        r.verdict = MCH.VERDICT_MYSTERY
    elseif r.mysteryPerNew > curatedCost then
        r.verdict = MCH.VERDICT_CURATED
    else
        r.verdict = MCH.VERDICT_EITHER
    end

    r.projection = Project(pool, mysteryCost, curatedCost)
    return r
end

-- A curated coffer covers several sets. Adds them up from the pool the advisor
-- already built, so the tooltip and the purchase check reuse the numbers the
-- panel is showing rather than rescanning. Returns nil when none of the
-- coffer's sets is in the pool.
function Advisor.CofferCounts(pool, setIds)
    local wanted = {}
    for _, setId in ipairs(setIds) do wanted[setId] = true end

    local found, missing, total = false, 0, 0
    for _, entry in ipairs(pool.sets) do
        if wanted[entry.setId] then
            found = true
            missing = missing + entry.missing
            total   = total + entry.total
        end
    end
    if not found then return nil end
    return missing, total
end

-- Convenience wrapper used by everything that just wants "what about vendor N".
--
-- Results are cached because the tooltip hook calls this on every mouse-over.
-- Model.Invalidate clears this alongside the pools.
local resultCache = {}

function Advisor.ForVendor(vendorId)
    local cached = resultCache[vendorId]
    if cached then return cached end

    local pool = MCH.Model.GetPool(vendorId)
    local mysteryCost, curatedCost, learned = MCH.Model.GetPrices(vendorId)
    local result = Advisor.Evaluate(pool, mysteryCost, curatedCost)
    if result then
        result.vendorId      = vendorId
        result.pricesLearned = learned
        resultCache[vendorId] = result
    end
    return result
end

function Advisor.Invalidate(vendorId)
    if vendorId then
        resultCache[vendorId] = nil
    else
        resultCache = {}
    end
end
