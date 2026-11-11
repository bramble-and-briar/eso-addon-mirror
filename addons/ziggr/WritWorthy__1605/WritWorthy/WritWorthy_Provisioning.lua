--[[
-------------------------------------------------------------------------------
-- WritWorthy
-------------------------------------------------------------------------------
-- Original author: ziggr (project started 2017-02-12)
--
-- Current maintainer: Sharlikran (contributions since 2022-11-12)
-- Contributor: jogietze (formerly otac0n) — GitHub PR contributions
--
-- ----------------------------------------------------------------------------
-- Unless otherwise stated, portions of this software are © ziggr and may
-- be subject to “All Rights Reserved” status due to the absence of a public
-- open-source license declaration.
--
-- ----------------------------------------------------------------------------
-- Contributions by Sharlikran are licensed under the BSD 3-Clause License:
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are met:
--
-- 1. Redistributions of source code must retain the above copyright notice,
--    this list of conditions and the following disclaimer.
--
-- 2. Redistributions in binary form must reproduce the above copyright notice,
--    this list of conditions and the following disclaimer in the documentation
--    and/or other materials provided with the distribution.
--
-- 3. Neither the name of the author "Sharlikran" nor the names of previous
--    contributors may be used to endorse or promote products derived from this
--    software without specific prior written permission.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
-- AND ANY EXPRESS OR IMPLIED WARRANTIES ARE DISCLAIMED. IN NO EVENT SHALL THE
-- COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING IN
-- ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
-- OF SUCH DAMAGE.
--
-- Maintainer Notice:
-- Redistribution of this software outside of ESOUI.com (including Bethesda.net
-- or other platforms) is discouraged unless authorized by the current
-- maintainer. Please do not redistribute or fork without attribution,
-- permission, and license compliance.
-------------------------------------------------------------------------------
]]
-- Parse a food or dring request.

local WritWorthy = _G["WritWorthy"] -- defined in WritWorthy_Define.lua

WritWorthy.Provisioning = {
  savedVarVersion = 2
}

local Provisioning = WritWorthy.Provisioning
local Util = WritWorthy.Util
local Fail = WritWorthy.Util.Fail
local Log = WritWorthy.Log

-- Recipe --------------------------------------------------------------------

Provisioning.Recipe = {}
local Recipe = Provisioning.Recipe
function Recipe:New(args)
  local o = {
    class = "provisioning",
    fooddrink_item_id = args.fooddrink_item_id, -- int(33526)
    recipe_item_id = args.recipe_item_id, -- int(45888)
    recipe_link = args.recipe_link, -- "|H1:item:45888:1:36:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
    is_known = args.is_known, -- true
    mat_list = {}, -- list of MatRow ingredients
    fooddrink_link = nil,
    fooddrink_name = nil
  }

  setmetatable(o, self)
  self.__index = self
  return o
end

function Recipe:FromFoodDrinkItemID(fooddrink_item_id)
  local MatRow = WritWorthy.MatRow

  local o = Recipe:New({ fooddrink_item_id = fooddrink_item_id })
  local LCK = LibCharacterKnowledge
  local recipe_item_id = LCK.GetSourceItemIdFromResultItem(fooddrink_item_id)
  if recipe_item_id == 0 then
    return nil
  end
  o.recipe_item_id = recipe_item_id
  o.recipe_link = string.format("|H1:item:%d:1:36:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", o.recipe_item_id)
  o.fooddrink_link = GetItemLinkRecipeResultItemLink(o.recipe_link, LINK_STYLE_DEFAULT)
  o.fooddrink_name = WritWorthy.FoodDrink(GetItemLinkItemId(o.fooddrink_link))
  o.is_known = IsItemLinkRecipeKnown(o.recipe_link)

  local r = { GetItemLinkItemType(o.fooddrink_link) }
  o.fooddrink_item_type = r[1]
  o.fooddrink_specialized_item_type = r[2]

  local log_t = {}
  log_t.fooddrink_item_id = fooddrink_item_id
  log_t.recipe_item_id = o.recipe_item_id
  log_t.recipe_link = o.recipe_link
  log_t.fooddrink_link = o.fooddrink_link
  log_t.fooddrink_name = o.fooddrink_name
  log_t.is_known = o.is_known
  log_t.fooddrink_item_type = o.fooddrink_item_type
  log_t.fooddrink_specialized_item_type = o.fooddrink_specialized_item_type
  Log:Add(log_t)

  local mat_ct = GetItemLinkRecipeNumIngredients(o.recipe_link)
  local cook_ct = 2 -- Usually need to craft 2x batches for master writs
  for ingr_index = 1, mat_ct do
    local _, _, ingr_ct = GetItemLinkRecipeIngredientInfo(o.recipe_link, ingr_index)
    local ingr_link = GetItemLinkRecipeIngredientItemLink(o.recipe_link, ingr_index, LINK_STYLE_DEFAULT)
    if 0 < ingr_ct and ingr_link and ingr_link ~= "" then
      local mr = MatRow:FromLink(ingr_link, ingr_ct * cook_ct)
      table.insert(o.mat_list, mr)
    end
  end
  return o
end

-- Provisioning --------------------------------------------------------------

-- Find a recipe by fooddrink_item_id
--
-- First time this runs, we decompress a list of all 554 recipe names.
-- Takes 1+ second!
--
-- Second-and-later times this runs, it's O(1) instantaneous.
--
-- returns a Recipe{} instance.
--
function Provisioning.FindRecipe(fooddrink_item_id)
  local recipe = Recipe:FromFoodDrinkItemID(fooddrink_item_id)
  if not recipe then
    return Fail("WritWorthy: recipe not found:" .. tostring(fooddrink_item_id))
  end
  return recipe
end

Provisioning.Parser = {
  class = "provisioning"
}
local Parser = Provisioning.Parser

function Parser:New()
  local o = {
    recipe = nil, -- Recipe{}
    crafting_type = CRAFTING_TYPE_PROVISIONING
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function Parser:ParseItemLink(item_link)
  Log:StartNewEvent("ParseItemLink: %s %s", self.class, item_link)
  local fields = Util.ToWritFields(item_link)
  self.recipe = Provisioning.FindRecipe(fields.writ1)
  if not self.recipe then
    return nil
  end
  return self
end

function Parser:ToMatList()
  return self.recipe.mat_list
end

function Parser:ToKnowList()
  Log:StartNewEvent("ToKnowList: %s", self.class)
  local Know = WritWorthy.Know
  local k = Know:New(
    {
      name = "recipe",
      is_known = self.recipe.is_known,
      lack_msg = WritWorthy.Str("know_err_recipe"),
      how = WritWorthy.Know.KNOW.RECIPE
    }
  )
  local r = { k }
  if self.recipe.fooddrink_item_type == ITEMTYPE_FOOD then
    local chef = WritWorthy.RequiredSkill.PR_FOOD_4X:ToKnow()
    chef.is_warn = true
    table.insert(r, chef)
  elseif self.recipe.fooddrink_item_type == ITEMTYPE_DRINK then
    local brewer = WritWorthy.RequiredSkill.PR_DRINK_4X:ToKnow()
    brewer.is_warn = true
    table.insert(r, brewer)
  end
  return r
end

function Parser:ToDolRequest(unique_id)
  local mat_list = self:ToMatList()
  local o = {}
  o[1] = self.recipe.recipe_item_id -- recipeId
  o[2] = 2 -- timesToMake
  o[3] = true -- autocraft
  o[4] = unique_id -- reference
  return {
    ["function"] = "CraftProvisioningItemByRecipeId",
    ["args"] = o
  }
end
