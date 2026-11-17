local A = OneCraft.Alchemy
local E = {}
A.RecipeEngine = E

function E.Effects(ids, reagents, opposites)
    local counts = {}
    for _, id in ipairs(ids) do
        local traits = reagents[id]
        if not traits or #traits ~= 4 then return nil end
        for _, effect in ipairs(traits) do counts[effect] = (counts[effect] or 0) + 1 end
    end
    local result = {}
    for effect, count in pairs(counts) do
        -- A single opposite trait cancels the entire matching effect.
        if count >= 2 and not counts[opposites[effect]] then result[effect] = true end
    end
    return result
end

function E.Matches(result, selected, exact)
    if not result or #selected == 0 then return false end
    for _, effect in ipairs(selected) do
        if not result[effect] then return false end
    end
    if exact then
        local count = 0
        for _ in pairs(result) do count = count + 1 end
        return count == #selected
    end
    return true
end

function E.Build(available, reagents, opposites, thirdSlot)
    local ids, recipes = {}, {}
    for id in pairs(available) do
        if reagents[id] then ids[#ids + 1] = id end
    end
    table.sort(ids)
    local function add(a, b, c)
        local recipe = {ids[a], ids[b], c and ids[c] or nil}
        local effects = E.Effects(recipe, reagents, opposites)
        local count = 0
        for _ in pairs(effects) do count = count + 1 end
        if count > 0 and count <= 3 then
            recipes[#recipes + 1] = {ids = recipe, effects = effects}
        end
    end
    for a = 1, #ids - 1 do
        for b = a + 1, #ids do
            add(a, b)
            if thirdSlot then
                for c = b + 1, #ids do add(a, b, c) end
            end
        end
    end
    return recipes
end

function E.Filter(recipes, selected)
    local result = {}
    for _, recipe in ipairs(recipes) do
        if E.Matches(recipe.effects, selected, true) then result[#result + 1] = recipe end
    end
    return result
end

-- Total crafts across all accessible unlocked stacks, rather than the batch
-- limit for a single physical stack or the number of potions produced.
function E.CraftCount(ids, inventory, solvent)
    if not solvent or #ids < 2 then return 0 end
    local maximum = solvent.count
    for _, id in ipairs(ids) do
        local item = inventory[id]
        maximum = math.min(maximum, item and item.count or 0)
    end
    return maximum
end

function E.CanAdd(recipes, selected, effect)
    if A.Contains(selected, effect) then return true end
    if #selected >= 3 then return false end
    local wanted = {unpack(selected)}
    wanted[#wanted + 1] = effect
    for _, recipe in ipairs(recipes) do
        if E.Matches(recipe.effects, wanted, false) then return true end
    end
    return false
end

function E.Allowed(recipes, selected)
    local allowed = {}
    for _, effect in ipairs(selected) do allowed[effect] = true end
    if #selected >= 3 then return allowed end
    for _, recipe in ipairs(recipes) do
        if #selected == 0 or E.Matches(recipe.effects, selected, false) then
            for effect in pairs(recipe.effects) do allowed[effect] = true end
        end
    end
    return allowed
end
