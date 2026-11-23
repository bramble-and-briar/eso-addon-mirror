-- Gold Digger "What to farm": ranks farmable items using the prices you've actually seen.
-- The game doesn't expose where items come from, so the tips below are a hand-written guide.

local GP = ESOC_GoldDigger
local Farm = {}
GP.Farm = Farm

local Scoring = GP.Scoring

local BY_NAME = {
    { "perfect roe", "Fillet fish. Any fishing hole works." },
    { "tempering alloy", "Rare result from refining raw ore." },
    { "dreugh wax", "Rare result from refining raw cloth or leather." },
    { "rosin", "Rare result from refining raw wood." },
    { "nirncrux", "Rare find on high-level crafting nodes." },
}

local BY_TYPE = {
    ITEMTYPE_REAGENT = "Gather plants and fungi on a zone route.",
    ITEMTYPE_INGREDIENT = "Loot barrels, crates and sacks.",
    ITEMTYPE_STYLE_MATERIAL = "Deconstruct gear of that style.",
    ITEMTYPE_RACIAL_STYLE_MOTIF = "Chests and enemy drops. Varies by motif.",
    ITEMTYPE_RECIPE = "Loot containers and chests.",
}
local typeTips = {}
for name, tip in pairs(BY_TYPE) do
    local value = _G[name]
    if value ~= nil then typeTips[value] = tip end
end

function Farm.TipFor(item)
    local name = string.lower(item.name or "")
    for _, entry in ipairs(BY_NAME) do
        if string.find(name, entry[1], 1, true) then return entry[2] end
    end
    return item.t and typeTips[item.t] or nil
end

-- Best first, weighing price by how reliably it sells.
function Farm.List(limit, tick)
    local today, rows = GP.Today(), {}
    for key, item in pairs(GP.sv.items) do
        if tick then tick() end
        local tip = Farm.TipFor(item)
        local view = tip and Scoring.View(item)
        local rate = view and Scoring.GoingRate(view, today)
        if rate then
            local sell = Scoring.SellThrough(view, today, 0, item.r)
            local recent = Scoring.RecentPrice(view, today)
            local flooded = recent ~= nil and recent <= rate * Scoring.GLUT_RATIO
            rows[#rows + 1] = { key = key, name = item.name, rate = rate, sell = sell, tip = tip, flooded = flooded, score = rate * sell }
        end
    end
    table.sort(rows, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.key < b.key
    end)
    for index = #rows, (limit or #rows) + 1, -1 do rows[index] = nil end
    return rows
end
