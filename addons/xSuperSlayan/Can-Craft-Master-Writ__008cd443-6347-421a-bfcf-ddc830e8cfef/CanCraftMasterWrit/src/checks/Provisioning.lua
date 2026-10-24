-- Provisioning master writs (8 dishes) and holiday event writs, which ask for food, drink or furnishings (amounts
-- depend on the event). Finds the recipe from the item (LibCharacterKnowledge), shows how many finished items are
-- already in stock, and checks the recipe is known, the skill ranks it needs, and the materials for every craft.
-- Furnishings are made with the same recipe functions as food, as in Dolgubon's Lazy Writ Crafter.

local addon = CanCraftMasterWrit
local Data = addon.Data
local Util = addon.Util
local Result = addon.Result

local Provisioning = {}
addon.checks[Data.KIND_PROVISIONING] = Provisioning

-- Returns the item link of the recipe that teaches the item, or nil if it can't be found.
local function GetRecipeLink(resultItemId)
    local recipeItemId = LibCharacterKnowledge.GetSourceItemIdFromResultItem(resultItemId)
    if recipeItemId and recipeItemId > 0 then
        return Util.ItemLink(recipeItemId)
    end
    return nil
end

-- Returns the link of the item the recipe makes, as a crafting station makes it, so the bags count the same item.
local function GetFinalItemLink(resultItemId, recipeLink, recipeListIndex, recipeIndex)
    local link
    if recipeListIndex then
        link = GetRecipeResultItemLink(recipeListIndex, recipeIndex, LINK_STYLE_DEFAULT)
    end
    if (link == nil or link == "") and recipeLink then
        link = GetItemLinkRecipeResultItemLink(recipeLink, LINK_STYLE_DEFAULT)
    end
    if link == nil or link == "" then
        link = Util.ItemLink(resultItemId)
    end
    return link
end

-- Returns how many items the writ asks for, or nil if that isn't known.
local function GetItemsRequired(writ, itemLink, recipeListIndex, recipeIndex)
    local displayQuality = GetItemLinkDisplayQuality(itemLink)
    if recipeListIndex then
        displayQuality = select(5, GetRecipeResultItemInfo(recipeListIndex, recipeIndex)) or displayQuality
    end
    local isFurnishing = GetItemLinkItemType(itemLink) == ITEMTYPE_FURNISHING
    return Data.GetProvisioningItemsRequired(writ.event, writ.resultItemId, displayQuality, isFurnishing)
end

-- Shows how many of the finished items the character already has. It never changes the overall status.
local function CheckFinalItem(result, itemLink, itemsRequired)
    local owned = Util.CountOwned(itemLink)
    if owned >= itemsRequired then
        result:Pass(Result.CATEGORY_ITEM, GetString(SI_CCMW_FINAL_ITEM_OK))
    else
        result:Info(Result.CATEGORY_ITEM, GetString(SI_CCMW_FINAL_ITEM), nil,
            { Result.Detail(Util.ItemName(itemLink), Result.Count(owned, itemsRequired)) })
    end
end

local function CheckRecipeKnown(result, recipeLink, recipeListIndex, recipeIndex, itemLink)
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
        result:Fail(category, GetString(SI_CCMW_RECIPE_MISSING), Util.ItemName(recipeLink or itemLink))
    end
end

local function GetLevelRequirement(tradeskill, requiredLevel)
    return {
        name = Util.LevelPassiveName(tradeskill),
        required = requiredLevel,
        current = Util.LevelPassiveRank(tradeskill),
    }
end

local function GetRecipeQualityRequirement(requiredQuality)
    return {
        name = Util.AbilityName(Data.RECIPE_QUALITY_PASSIVE, GetString(SI_CCMW_RECIPE_QUALITY)),
        required = requiredQuality,
        current = GetNonCombatBonus(NON_COMBAT_BONUS_PROVISIONING_RARITY_LEVEL),
    }
end

-- Every rank the recipe lists is read, because furnishings can need other crafts' ranks, such as Woodworking.
local function CheckSkills(result, recipeLink, recipeListIndex, recipeIndex)
    local skills = {}
    local requiredQuality
    if recipeLink then
        for tradeskillIndex = 1, GetItemLinkRecipeNumTradeskillRequirements(recipeLink) do
            local tradeskill, requiredLevel = GetItemLinkRecipeTradeskillRequirement(recipeLink, tradeskillIndex)
            table.insert(skills, GetLevelRequirement(tradeskill, requiredLevel))
        end
        requiredQuality = GetItemLinkRecipeQualityRequirement(recipeLink)
    elseif recipeListIndex then
        for tradeskillIndex = 1, GetNumRecipeTradeskillRequirements(recipeListIndex, recipeIndex) do
            local tradeskill, requiredLevel = GetRecipeTradeskillRequirement(recipeListIndex, recipeIndex,
                tradeskillIndex)
            table.insert(skills, GetLevelRequirement(tradeskill, requiredLevel))
        end
        requiredQuality = select(5, GetRecipeInfo(recipeListIndex, recipeIndex))
    else
        result:Unknown(Result.CATEGORY_SKILLS, GetString(SI_CCMW_SKILLS_UNKNOWN))
        return
    end
    if requiredQuality and requiredQuality > 0 then
        table.insert(skills, GetRecipeQualityRequirement(requiredQuality))
    end
    result:AddSkills(skills)
end

-- Returns how many items one craft makes: from the recipe list if possible, otherwise from the Chef passive for food
-- or the Brewer passive for drink. Furnishings are made one at a time.
local function GetYieldPerCraft(recipeListIndex, recipeIndex, itemType)
    if recipeListIndex then
        local quantity = GetRecipeResultQuantity(recipeListIndex, recipeIndex, 1)
        if quantity and quantity > 0 then
            return quantity
        end
    end
    if itemType == ITEMTYPE_FOOD then
        return 1 + GetNonCombatBonus(NON_COMBAT_BONUS_PROVISIONING_CREATE_EXTRA_FOOD)
    elseif itemType == ITEMTYPE_DRINK then
        return 1 + GetNonCombatBonus(NON_COMBAT_BONUS_PROVISIONING_CREATE_EXTRA_DRINK)
    end
    return 1
end

local function CheckIngredients(result, crafts, recipeLink, recipeListIndex, recipeIndex, itemLink)
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
        result:Unknown(Result.CATEGORY_MATERIALS, GetString(SI_CCMW_MATERIAL_AMOUNT_UNKNOWN), Util.ItemName(itemLink))
    end
end

function Provisioning.Evaluate(writ, result)
    local recipeLink = GetRecipeLink(writ.resultItemId)
    local _, recipeListIndex, recipeIndex = GetRecipeInfoFromItemId(writ.resultItemId)
    local itemLink = GetFinalItemLink(writ.resultItemId, recipeLink, recipeListIndex, recipeIndex)

    -- The recipe list gives no ingredient amounts for a recipe the character doesn't know (such a writ read
    -- "Materials in Stock" without the ingredients), so those are read from the recipe item instead.
    local knownListIndex, knownRecipeIndex
    if recipeListIndex and GetRecipeInfo(recipeListIndex, recipeIndex) then
        knownListIndex, knownRecipeIndex = recipeListIndex, recipeIndex
    end
    local itemsRequired = GetItemsRequired(writ, itemLink, knownListIndex, knownRecipeIndex)

    -- Items already made don't lower the other checks: like every other writ, it reads Craftable only if the
    -- character can make all of it (1.2.0 skipped them, and showed Craftable without the recipe or materials). Only an
    -- item a recipe makes is counted: a writ number that matches no recipe may not be an item at all.
    if itemsRequired and (recipeLink or recipeListIndex) then
        CheckFinalItem(result, itemLink, itemsRequired)
    end

    CheckRecipeKnown(result, recipeLink, recipeListIndex, recipeIndex, itemLink)
    CheckSkills(result, recipeLink, recipeListIndex, recipeIndex)
    if not itemsRequired then
        result:Unknown(Result.CATEGORY_MATERIALS, GetString(SI_CCMW_MATERIAL_AMOUNT_UNKNOWN), Util.ItemName(itemLink))
        return
    end
    local yield = GetYieldPerCraft(knownListIndex, knownRecipeIndex, GetItemLinkItemType(itemLink))
    local crafts = zo_ceil(itemsRequired / yield)
    CheckIngredients(result, crafts, recipeLink, knownListIndex, knownRecipeIndex, itemLink)
end
