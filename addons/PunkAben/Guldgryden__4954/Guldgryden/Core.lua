Guldgryden = Guldgryden or {}
local G = Guldgryden
G.Core = G.Core or {}
local C = G.Core
function C.Available(r, stock)
    local n = math.huge
    for _, ing in ipairs(r.ingredients) do
        n = math.min(n, math.floor((stock[ing.id] or 0) / ing.qty))
    end
    if n == math.huge then return 0 end
    return math.max(0, n)
end
-- Compare complete feasible plans. This is a bounded heuristic, NOT a global optimum.
local function PlanTier(recipes, owned, reserve)
    local best = {rows = {}, gold = 0, crafts = 0, portions = 0}
    for mode = 1, 3 do
        local stock, ordered = {}, {}
        for id, count in pairs(owned) do stock[id] = math.max(0, count - reserve) end
        for _, r in ipairs(recipes) do ordered[#ordered + 1] = r end
        table.sort(ordered, function(a, b)
            local an, bn = C.Available(a, stock), C.Available(b, stock)
            local av, bv = a.value * a.output, b.value * b.output
            if mode == 2 then av, bv = av * an, bv * bn end
            if mode == 3 then av, bv = av / math.max(1, an), bv / math.max(1, bn) end
            if av ~= bv then return av > bv end
            return a.key < b.key
        end)
        local plan = {rows = {}, gold = 0, crafts = 0, portions = 0}
        for _, r in ipairs(ordered) do
            local n = C.Available(r, stock)
            if n > 0 then
                plan.rows[#plan.rows + 1] = {recipe = r, count = n}
                plan.gold = plan.gold + n * r.output * r.value
                plan.crafts = plan.crafts + n
                plan.portions = plan.portions + n * r.output
                for _, ing in ipairs(r.ingredients) do stock[ing.id] = stock[ing.id] - n * ing.qty end
            end
        end
        if plan.gold > best.gold or (plan.gold == best.gold and plan.crafts < best.crafts) then best = plan end
    end
    return best
end
-- Finish each price tier before allocating its leftover ingredients to the next.
function C.Plan(recipes, owned, reserve)
    local groups, prices, remaining = {}, {}, {}
    for id, count in pairs(owned) do remaining[id] = count end
    for _, r in ipairs(recipes) do
        if r.value >= 1 then
            if not groups[r.value] then groups[r.value] = {}; prices[#prices + 1] = r.value end
            groups[r.value][#groups[r.value] + 1] = r
        end
    end
    table.sort(prices, function(a, b) return a > b end)
    local plan = {rows = {}, gold = 0, crafts = 0, portions = 0}
    for _, price in ipairs(prices) do
        local tier = PlanTier(groups[price], remaining, reserve)
        for _, row in ipairs(tier.rows) do
            plan.rows[#plan.rows + 1] = row
            for _, ing in ipairs(row.recipe.ingredients) do
                remaining[ing.id] = remaining[ing.id] - row.count * ing.qty
            end
        end
        plan.gold = plan.gold + tier.gold
        plan.crafts = plan.crafts + tier.crafts
        plan.portions = plan.portions + tier.portions
    end
    return plan
end
-- Deliberately require a free slot for a new result whose maximum stack size is unknown.
function C.HasRoom(output, matchingStackSpace, freeSlots)
    return matchingStackSpace >= output or freeSlots > 0
end
function C.Sellable(pending, current, baseline)
    return math.max(0, math.min(pending, current - baseline))
end
