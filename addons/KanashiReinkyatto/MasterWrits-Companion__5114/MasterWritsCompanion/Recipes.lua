MWC.Recipes = {}

-- Maps result item id -> recipe. Built from the game API, so new recipes need no data updates. Thousands of
-- calls, so it is kept until a recipe is learned or skill points change (the yield follows the passives).
local cache

local function Invalidate()
  cache = nil
end
for _, event in ipairs({ EVENT_RECIPE_LEARNED, EVENT_MULTIPLE_RECIPES_LEARNED, EVENT_SKILL_POINTS_CHANGED }) do
  if event then
    EVENT_MANAGER:RegisterForEvent(MWC.name .. "Recipes", event, Invalidate)
  end
end

function MWC.Recipes.Build()
  if cache then return cache end
  local byItemId = {}
  for listIndex = 1, GetNumRecipeLists() do
    local _, numRecipes = GetRecipeListInfo(listIndex)
    for recipeIndex = 1, numRecipes do
      local known, _, numIngredients = GetRecipeInfo(listIndex, recipeIndex)
      local resultLink = GetRecipeResultItemLink(listIndex, recipeIndex, LINK_STYLE_DEFAULT)
      local itemId = resultLink ~= "" and GetItemLinkItemId(resultLink) or 0
      if itemId ~= 0 then
        local _, _, yield = GetRecipeResultItemInfo(listIndex, recipeIndex)
        local ingredients = {}
        for i = 1, numIngredients do
          local _, _, quantity = GetRecipeIngredientItemInfo(listIndex, recipeIndex, i)
          table.insert(ingredients, {
            link = GetRecipeIngredientItemLink(listIndex, recipeIndex, i, LINK_STYLE_DEFAULT),
            quantity = quantity,
          })
        end
        byItemId[itemId] = {
          listIndex = listIndex,
          recipeIndex = recipeIndex,
          known = known,
          resultItemId = itemId,
          resultLink = resultLink,
          yield = yield,
          ingredients = ingredients,
        }
      end
    end
  end
  cache = byItemId
  return byItemId
end
