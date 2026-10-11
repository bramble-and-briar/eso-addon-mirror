-- Alchemy master writs: 16 potions or poisons with three required effects.
-- Finds every three-reagent combination that makes exactly those effects, picks the one the character has the
-- most of, then checks Solvent Proficiency, the third reagent slot and the solvent and reagents in stock.
-- Same approach as Dolgubon's Lazy Writ Crafter (alchemy.lua), written independently.

local addon = CanCraftMasterWrit
local Data = addon.Data
local Util = addon.Util
local Result = addon.Result

local Alchemy = {}
addon.checks[Data.KIND_ALCHEMY] = Alchemy

-- Splits an effect number into its pair's positive number and a sign: 1 gives (1, 1), 2 gives (1, -1).
local function SplitEffect(effect)
    if effect % 2 == 1 then
        return effect, 1
    end
    return effect - 1, -1
end

-- Returns the set of effects a reagent combination makes. An effect appears when at least two more of the
-- reagents carry it than carry its opposite.
local function GetCombinationEffects(reagentIds)
    local totals = {}
    for _, reagentId in ipairs(reagentIds) do
        for _, effect in ipairs(Data.REAGENT_EFFECTS[reagentId]) do
            local positive, sign = SplitEffect(effect)
            totals[positive] = (totals[positive] or 0) + sign
        end
    end
    local effects = {}
    for positive, total in pairs(totals) do
        if total >= 2 then
            effects[positive] = true
        elseif total <= -2 then
            effects[positive + 1] = true
        end
    end
    return effects
end

local combinationCache = {}

-- Returns every three-reagent combination that makes exactly the wanted effects. If no combination makes
-- exactly them, returns the ones that make them plus extra effects. Results never change, so they are cached.
function Alchemy.FindCombinations(wantedEffects)
    local sorted = { unpack(wantedEffects) }
    table.sort(sorted)
    local cacheKey = table.concat(sorted, ",")
    if combinationCache[cacheKey] then
        return combinationCache[cacheKey]
    end

    local wanted = {}
    for _, effect in ipairs(sorted) do
        wanted[effect] = true
    end

    -- Only reagents carrying at least one wanted effect can help.
    local candidates = {}
    for reagentId, effects in pairs(Data.REAGENT_EFFECTS) do
        for _, effect in ipairs(effects) do
            if wanted[effect] then
                table.insert(candidates, reagentId)
                break
            end
        end
    end
    table.sort(candidates)

    local exact, withExtras = {}, {}
    for first = 1, #candidates - 2 do
        for second = first + 1, #candidates - 1 do
            for third = second + 1, #candidates do
                local combination = { candidates[first], candidates[second], candidates[third] }
                local effects = GetCombinationEffects(combination)
                local hasAll = true
                for effect in pairs(wanted) do
                    if not effects[effect] then
                        hasAll = false
                        break
                    end
                end
                if hasAll then
                    if NonContiguousCount(effects) == #sorted then
                        table.insert(exact, combination)
                    else
                        table.insert(withExtras, combination)
                    end
                end
            end
        end
    end

    local combinations = #exact > 0 and exact or withExtras
    combinationCache[cacheKey] = combinations
    return combinations
end

-- Returns the combination needing the fewest reagents the character doesn't have.
local function PickCombination(combinations, crafts)
    local best, bestShortfall
    for _, combination in ipairs(combinations) do
        local shortfall = 0
        for _, reagentId in ipairs(combination) do
            shortfall = shortfall + zo_max(0, crafts - Util.CountOwned(Util.ItemLink(reagentId)))
        end
        if not best or shortfall < bestShortfall then
            best, bestShortfall = combination, shortfall
            if shortfall == 0 then
                break
            end
        end
    end
    return best
end

-- Returns how many potions or poisons one craft makes. The game says exactly when the solvent is in stock;
-- otherwise it is worked out from the Chemistry passive.
local function GetYieldPerCraft(solventId, isPoison)
    local bagId, slotIndex = Util.FindItemSlot(solventId)
    if bagId then
        local quantity = GetAlchemyResultQuantity(bagId, slotIndex, 1)
        if quantity and quantity > 0 then
            return quantity
        end
    end
    local extra = GetNonCombatBonus(NON_COMBAT_BONUS_ALCHEMY_CREATE_EXTRA)
    return isPoison and 4 * (1 + extra) or (1 + extra)
end

function Alchemy.Evaluate(writ, result)
    local solventId = writ.isPoison and Data.ALCHEMY_POISON_SOLVENT or Data.ALCHEMY_POTION_SOLVENT
    local solventLink = Util.ItemLink(solventId)
    local crafts = zo_ceil(Data.ALCHEMY_ITEMS_REQUIRED / GetYieldPerCraft(solventId, writ.isPoison))

    local combinations = Alchemy.FindCombinations(writ.effects)
    local combination = PickCombination(combinations, crafts)
    if combination then
        local names = {}
        for _, reagentId in ipairs(combination) do
            table.insert(names, Util.ItemName(Util.ItemLink(reagentId)))
        end
        result:Info(Result.CATEGORY_REAGENTS, GetString(SI_CCMW_REAGENTS), table.concat(names, " + "))
    else
        result:Unknown(Result.CATEGORY_REAGENTS, GetString(SI_CCMW_REAGENTS_NONE))
    end

    result:AddSkills({
        {
            name = Util.LevelPassiveName(CRAFTING_TYPE_ALCHEMY),
            required = GetItemLinkRequiredCraftingSkillRank(solventLink),
            current = GetNonCombatBonus(NON_COMBAT_BONUS_ALCHEMY_LEVEL),
        },
        {
            unlockText = GetString(SI_CCMW_THIRD_SLOT),
            required = 1,
            current = zo_min(1, GetNonCombatBonus(NON_COMBAT_BONUS_ALCHEMY_THIRD_SLOT)),
        },
    })

    local materials = { { link = solventLink, needed = crafts } }
    for _, reagentId in ipairs(combination or {}) do
        table.insert(materials, { link = Util.ItemLink(reagentId), needed = crafts })
    end
    result:AddMaterials(materials)
end
