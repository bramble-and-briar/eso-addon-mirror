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
-- Holiday and charity writs. The requested item is writ1 on the sealed writ
-- link. No API exposes how many the writ asks for: the sealed writ text is
-- "Craft a <<1>>" and writ_reward is the voucher payout, so counts are data.

local WritWorthy = _G["WritWorthy"] -- defined in WritWorthy_Define.lua

WritWorthy.Holiday = {}
local Holiday = WritWorthy.Holiday
local Util = WritWorthy.Util

Holiday.FESTIVAL_WITCHES = "witches"
Holiday.FESTIVAL_NEW_LIFE = "new_life"
Holiday.FESTIVAL_DEEP_WINTER = "deep_winter"
Holiday.FESTIVAL_IMPERIAL = "imperial"

-- Writ item id -> festival.
Holiday.WRIT_ITEM_ID = {
  [145531] = Holiday.FESTIVAL_NEW_LIFE,
  [145545] = Holiday.FESTIVAL_NEW_LIFE,
  [145569] = Holiday.FESTIVAL_NEW_LIFE,
  [145570] = Holiday.FESTIVAL_NEW_LIFE,
  [145572] = Holiday.FESTIVAL_NEW_LIFE,
  [145574] = Holiday.FESTIVAL_NEW_LIFE,
  [153482] = Holiday.FESTIVAL_WITCHES,
  [153510] = Holiday.FESTIVAL_WITCHES,
  [153748] = Holiday.FESTIVAL_WITCHES,
  [153749] = Holiday.FESTIVAL_WITCHES,
  [156731] = Holiday.FESTIVAL_DEEP_WINTER,
  [156732] = Holiday.FESTIVAL_DEEP_WINTER,
  [156733] = Holiday.FESTIVAL_DEEP_WINTER,
  [156735] = Holiday.FESTIVAL_DEEP_WINTER,
  [156736] = Holiday.FESTIVAL_DEEP_WINTER,
  [167169] = Holiday.FESTIVAL_IMPERIAL,
  [167170] = Holiday.FESTIVAL_IMPERIAL,
  [167171] = Holiday.FESTIVAL_IMPERIAL,
  [167172] = Holiday.FESTIVAL_IMPERIAL
}

-- Deep Winter normal-quality results that only need 3.
local DEEP_WINTER_NEED_THREE = {
  [117943] = true,
  [120410] = true
}

-- Counts match Lazy Writ Creator MasterWrits.lua provisioningRightClick and
-- deepWinterQuantity. Returns nil for a quality those rules do not cover.
local function GetNeededCount(festival, result_link)
  if festival == Holiday.FESTIVAL_WITCHES then
    return 4
  end
  local quality = GetItemLinkFunctionalQuality(result_link)
  if festival == Holiday.FESTIVAL_NEW_LIFE then
    if quality == ITEM_FUNCTIONAL_QUALITY_MAGIC then
      return 1
    elseif quality == ITEM_FUNCTIONAL_QUALITY_NORMAL then
      return 12
    end
  elseif festival == Holiday.FESTIVAL_DEEP_WINTER then
    if quality == ITEM_FUNCTIONAL_QUALITY_MAGIC then
      return 1
    elseif quality == ITEM_FUNCTIONAL_QUALITY_NORMAL then
      return DEEP_WINTER_NEED_THREE[GetItemLinkItemId(result_link)] and 3 or 12
    end
  elseif festival == Holiday.FESTIVAL_IMPERIAL then
    if quality == ITEM_FUNCTIONAL_QUALITY_NORMAL then
      return 3
    elseif quality == ITEM_FUNCTIONAL_QUALITY_MAGIC then
      return GetItemLinkItemType(result_link) == ITEMTYPE_FURNISHING and 1 or 12
    end
  end
  return nil
end

Holiday.Parser = {
  class = "holiday"
}
local Parser = Holiday.Parser

function Parser:New()
  local parser = {
    class = "holiday",
    crafting_type = CRAFTING_TYPE_PROVISIONING,
    mat_list = {}
  }
  setmetatable(parser, self)
  self.__index = self
  return parser
end

function Parser:ParseItemLink(item_link)
  local fields = Util.ToWritFields(item_link)
  local festival = Holiday.WRIT_ITEM_ID[fields.item_id]
  local crafting_station_type, recipe_list_index, recipe_index = GetRecipeInfoFromItemId(fields.writ1 or 0)
  if not (festival and recipe_list_index and recipe_index) then
    return nil
  end
  local result_per_craft = GetRecipeResultQuantity(recipe_list_index, recipe_index, 1)
  if result_per_craft < 1 then
    return nil
  end

  local result_link = GetRecipeResultItemLink(recipe_list_index, recipe_index, LINK_STYLE_DEFAULT)
  local needed_count = GetNeededCount(festival, result_link)
  if not needed_count then
    return nil
  end
  local is_known, _, ingredient_count = GetRecipeInfo(recipe_list_index, recipe_index)

  self.writ_item_id = fields.item_id
  self.festival = festival
  self.crafting_type = crafting_station_type
  self.recipe_list_index = recipe_list_index
  self.recipe_index = recipe_index
  self.result_per_craft = result_per_craft
  self.ingredient_count = ingredient_count
  self.is_known = is_known
  self.requested_item_id = fields.writ1
  self.requested_item_name = zo_strformat(SI_TOOLTIP_ITEM_NAME, GetItemLinkName(result_link))
  self.requested_item_type = GetItemLinkItemType(result_link)
  self.needed_count = needed_count
  self.backpack_count = GetItemLinkStacks(result_link)
  self:SetOwnedCount(self.backpack_count)
  return self
end

-- owned_count is how many backpack result items count toward this writ.
-- Several writs for the same item share one backpack stack.
function Parser:SetOwnedCount(owned_count)
  self.owned_count = owned_count
  self.still_needed_count = zo_max(self.needed_count - owned_count, 0)
  self.times_to_craft = zo_ceil(self.still_needed_count / self.result_per_craft)
  self.mat_list = {}
  self.mat_list_fail_reason = nil

  if self.times_to_craft < 1 then
    self.mat_list_fail_reason = string.format(
      WritWorthy.Str("holiday_have_enough"),
      self.owned_count,
      self.needed_count,
      self.requested_item_name
    )
    return
  end

  for ingredient_index = 1, self.ingredient_count do
    local _, _, required_count = GetRecipeIngredientItemInfo(self.recipe_list_index, self.recipe_index, ingredient_index)
    local ingredient_link = GetRecipeIngredientItemLink(self.recipe_list_index, self.recipe_index, ingredient_index, LINK_STYLE_DEFAULT)
    if 0 < required_count and ingredient_link ~= "" then
      table.insert(self.mat_list, WritWorthy.MatRow:FromLink(ingredient_link, required_count * self.times_to_craft))
    end
  end
end

function Parser:ToMatList()
  return self.mat_list
end

function Parser:ToKnowList()
  local Know = WritWorthy.Know
  local know_list = {
    Know:New(
      {
        name = "recipe",
        is_known = self.is_known,
        lack_msg = WritWorthy.Str("know_err_recipe"),
        how = WritWorthy.Know.KNOW.RECIPE
      }
    )
  }
  if self.requested_item_type == ITEMTYPE_FOOD then
    local chef = WritWorthy.RequiredSkill.PR_FOOD_4X:ToKnow()
    chef.is_warn = true
    table.insert(know_list, chef)
  elseif self.requested_item_type == ITEMTYPE_DRINK then
    local brewer = WritWorthy.RequiredSkill.PR_DRINK_4X:ToKnow()
    brewer.is_warn = true
    table.insert(know_list, brewer)
  end
  return know_list
end

function Parser:ToDolRequest(unique_id)
  if self.times_to_craft < 1 then
    return nil
  end
  return {
    ["function"] = "CraftProvisioningItemByResultItemId",
    ["args"] = {
      self.requested_item_id,
      self.times_to_craft,
      true,
      unique_id
    }
  }
end

function Holiday.DumpInventory()
  local found_count = 0
  for _, bag_id in ipairs({ BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }) do
    for slot_index = 0, GetBagSize(bag_id) do
      local item_link = GetItemLink(bag_id, slot_index, LINK_STYLE_DEFAULT)
      local writ_item_id = GetItemLinkItemId(item_link)
      local parser = Holiday.WRIT_ITEM_ID[writ_item_id] and WritWorthy.CreateParser(item_link)
      parser = parser and parser:ParseItemLink(item_link)
      if parser and parser.class == WritWorthy.Alchemy.Parser.class then
        found_count = found_count + 1
        d(
          string.format(
            "WritWorthy holiday: writ %d -> %s %s + %s + %s crafts=%d",
            writ_item_id,
            parser.is_poison and "poison" or "potion",
            parser.effects[1].name,
            parser.effects[2].name,
            parser.effects[3].name,
            parser:GetRequiredCraftCt()
          )
        )
      elseif parser then
        found_count = found_count + 1
        d(
          string.format(
            "WritWorthy holiday: writ %d -> %d %s station=%d recipe=%d/%d needed=%d owned=%d crafts=%d",
            parser.writ_item_id,
            parser.requested_item_id,
            parser.requested_item_name,
            parser.crafting_type,
            parser.recipe_list_index,
            parser.recipe_index,
            parser.needed_count,
            parser.owned_count,
            parser.times_to_craft
          )
        )
      end
    end
  end
  d(string.format("WritWorthy holiday: %d writs", found_count))
end
