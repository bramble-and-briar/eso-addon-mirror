-- Provisioning master writs (8 dishes) and holiday event writs (amounts depend on the event).
-- Finds the recipe from the dish (LibCharacterKnowledge), then checks the recipe is known, the Recipe
-- Improvement and Recipe Quality ranks, and the ingredients for every craft needed.

local addon = CanCraftMasterWrit
local Data = addon.Data
local Util = addon.Util
local Result = addon.Result

local Provisioning = {}
addon.checks[Data.KIND_PROVISIONING] = Provisioning

-- Returns the item link of the recipe that teaches the dish, or nil if it can't be found.
local function GetRecipeLink(resultItemId)
    local recipeItemId = LibCharacterKnowledge.GetSourceItemIdFromResultItem(resultItemId)
    if recipeItemId and recipeItemId > 0 then
        return Util.ItemLink(recipeItemId)
    end
    return nil
end

local function CheckRecipeKnown(result, recipeLink, recipeListIndex, recipeIndex, dishLink)
    local known
    if recipeLink then
        known = IsItemLinkRecipeKnown(recipeLink)
    elseif recipeListIndex then
        known = GetRecipeInfo(recipeListIndex, recipeIndex)
    end
    local category = Result.CATEGORY_RECIPE
    if known == nil then
        result:Unknown(category, GetString(SI_CCMW_RECIPE_NOT_FOUND))
    elseif known then
        result:Pass(category, GetString(SI_CCMW_RECIPE_KNOWN))
    else
        result:Fail(category, GetString(SI_CCMW_RECIPE_MISSING), Util.ItemName(recipeLink or dishLink))
    end
end

local function GetRecipeQualityRequirement(requiredQuality)
    return {
        name = Util.AbilityName(Data.RECIPE_QUALITY_PASSIVE, GetString(SI_CCMW_RECIPE_QUALITY)),
        required = requiredQuality,
        current = GetNonCombatBonus(NON_COMBAT_BONUS_PROVISIONING_RARITY_LEVEL),
    }
end

local function CheckSkills(result, recipeLink, recipeListIndex, recipeIndex)
    local skills = {}
    if recipeLink then
        for tradeskillIndex = 1, GetItemLinkRecipeNumTradeskillRequirements(recipeLink) do
            local tradeskill, requiredLevel = GetItemLinkRecipeTradeskillRequirement(recipeLink, tradeskillIndex)
            table.insert(skills, {
                name = Util.LevelPassiveName(tradeskill),
                required = requiredLevel,
                current = Util.LevelPassiveRank(tradeskill),
            })
        end
        local requiredQuality = GetItemLinkRecipeQualityRequirement(recipeLink)
        if requiredQuality > 0 then
            table.insert(skills, GetRecipeQualityRequirement(requiredQuality))
        end
    elseif recipeListIndex then
        local _, _, _, requiredLevel, requiredQuality = GetRecipeInfo(recipeListIndex, recipeIndex)
        table.insert(skills, {
            name = Util.LevelPassiveName(CRAFTING_TYPE_PROVISIONING),
            required = requiredLevel,
            current = Util.LevelPassiveRank(CRAFTING_TYPE_PROVISIONING),
        })
        if requiredQuality > 0 then
            table.insert(skills, GetRecipeQualityRequirement(requiredQuality))
        end
    else
        result:Unknown(Result.CATEGORY_SKILLS, GetString(SI_CCMW_SKILLS_UNKNOWN))
        return
    end
    result:AddSkills(skills)
end

-- Returns how many dishes one craft makes, from the recipe if possible, otherwise from the Chef or Brewer passive.
local function GetYieldPerCraft(recipeListIndex, recipeIndex, isFood)
    if recipeListIndex then
        local quantity = GetRecipeResultQuantity(recipeListIndex, recipeIndex, 1)
        if quantity and quantity > 0 then
            return quantity
        end
    end
    local bonus = isFood and NON_COMBAT_BONUS_PROVISIONING_CREATE_EXTRA_FOOD or NON_COMBAT_BONUS_PROVISIONING_CREATE_EXTRA_DRINK
    return 1 + GetNonCombatBonus(bonus)
end

local function CheckIngredients(result, writ, recipeLink, recipeListIndex, recipeIndex, dishLink)
    local isFood = GetItemLinkItemType(dishLink) == ITEMTYPE_FOOD
    local displayQuality = GetItemLinkDisplayQuality(dishLink)
    if recipeListIndex then
        displayQuality = select(5, GetRecipeResultItemInfo(recipeListIndex, recipeIndex)) or displayQuality
    end

    local itemsRequired = Data.GetProvisioningItemsRequired(writ.event, writ.resultItemId, displayQuality, isFood)
    if not itemsRequired then
        result:Unknown(Result.CATEGORY_MATERIALS, GetString(SI_CCMW_MATERIAL_AMOUNT_UNKNOWN), Util.ItemName(dishLink))
        return
    end
    local crafts = zo_ceil(itemsRequired / GetYieldPerCraft(recipeListIndex, recipeIndex, isFood))

    local materials = {}
    if recipeListIndex then
        local numIngredients = select(3, GetRecipeInfo(recipeListIndex, recipeIndex))
        for ingredientIndex = 1, numIngredients do
            local _, _, requiredQuantity = GetRecipeIngredientItemInfo(recipeListIndex, recipeIndex, ingredientIndex)
            table.insert(materials, {
                link = GetRecipeIngredientItemLink(recipeListIndex, recipeIndex, ingredientIndex, LINK_STYLE_DEFAULT),
                perCraft = requiredQuantity,
            })
        end
    elseif recipeLink then
        -- The recipe item lists its ingredients whether or not the recipe is known, as on the recipe's own tooltip.
        for ingredientIndex = 1, GetItemLinkRecipeNumIngredients(recipeLink) do
            local name, owned, requiredQuantity = GetItemLinkRecipeIngredientInfo(recipeLink, ingredientIndex)
            local link = GetItemLinkRecipeIngredientItemLink(recipeLink, ingredientIndex, LINK_STYLE_DEFAULT)
            if link ~= "" then
                table.insert(materials, { link = link, perCraft = requiredQuantity })
            else
                -- Without the ingredient's link, only the game's own count is left: backpack and bank, no craft bag.
                table.insert(materials, {
                    name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name),
                    owned = owned,
                    perCraft = requiredQuantity,
                })
            end
        end
    end

    -- An amount the game didn't give must never read as "in stock".
    local amountsKnown = #materials > 0
    for _, material in ipairs(materials) do
        if not material.perCraft or material.perCraft <= 0 or (material.link == "" and not material.name) then
            amountsKnown = false
        end
        material.needed = (material.perCraft or 0) * crafts
    end

    if amountsKnown then
        result:AddMaterials(materials)
    else
        result:Unknown(Result.CATEGORY_MATERIALS, GetString(SI_CCMW_MATERIAL_AMOUNT_UNKNOWN), Util.ItemName(dishLink))
    end
end

function Provisioning.Evaluate(writ, result)
    local dishLink = Util.ItemLink(writ.resultItemId)
    local recipeLink = GetRecipeLink(writ.resultItemId)
    local _, recipeListIndex, recipeIndex = GetRecipeInfoFromItemId(writ.resultItemId)

    CheckRecipeKnown(result, recipeLink, recipeListIndex, recipeIndex, dishLink)
    CheckSkills(result, recipeLink, recipeListIndex, recipeIndex)

    -- The recipe list gives no ingredient amounts for a recipe the character doesn't know (such a writ read
    -- "Materials in Stock" without the ingredients), so those are read from the recipe item instead.
    if recipeListIndex and not GetRecipeInfo(recipeListIndex, recipeIndex) then
        recipeListIndex, recipeIndex = nil, nil
    end
    CheckIngredients(result, writ, recipeLink, recipeListIndex, recipeIndex, dishLink)
end
