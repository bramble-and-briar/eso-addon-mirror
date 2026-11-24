LibDeconValue = LibDeconValue or { }
local LibDeconValue = LibDeconValue

local function round(value)
  if value then
    local scale = 1
    local abs = math.abs(value)
    if abs < 1 then
      scale = math.pow(10, math.ceil(math.log10(abs)) - 2)
    elseif abs < 40 then
      scale = 0.1
    end
    return zo_roundToNearest(value, scale)
  end
end

local function AddDeconPrice(tooltip, itemLink)
  local expectation = LibDeconValue:FindDeconstructionExpectation(itemLink, LibDeconValue.Analysis.ItemSaleValue)
  if expectation then
    local value = expectation.value
    local color = "|cffffff"
    if value < LibDeconValue.Analysis.ItemVendorValue(itemLink) then
      color = "|cff0000"
    else
      local price = LibPrice and LibPrice.ItemLinkToBidAskSpread and LibPrice.ItemLinkToBidAskSpread(itemLink).gold
      if price then
        local bid = price.bid and price.bid.value
        local sale = price.sale and price.sale.value
        local ask = price.ask and price.ask.value
        if ask and ask < value then
          color = "|c00ee11"
        elseif sale and sale < value then
          color = "|cffff00"
        elseif sale and sale > value then
          color = "|cff8800"
        end
      end
    end
    tooltip:AddLine("|t20:20:esoui/art/tutorial/inventory_trait_intricate_icon.dds|t Deconstruction Value: " .. color 
		.. (round(value) or "?") .. "|r |t18:18:esoui/art/currency/currency_gold_32.dds|t", "ZoFontGameLarge")
    for _, row in ipairs(expectation) do
      local line
      if row.currency then
        line = ZO_Currency_FormatKeyboard(row.currency, zo_round(row.expected), ZO_CURRENCY_FORMAT_AMOUNT_ICON)
      else
        line = row.item .. " × " .. round(row.expected)
      end
      if row.samples and row.samples > 0 then
        line = line .. " |c808080(n=" .. row.samples .. ")|r"
      end
      tooltip:AddLine(line, "ZoFontGameSmall")
    end
    return true
  end
end

EVENT_MANAGER:RegisterForEvent("LibDeconValue" .. "Tooltips", EVENT_ADD_ON_LOADED, function (eventCode, name)
  if name ~= "LibDeconValue" then return end
  EVENT_MANAGER:UnregisterForEvent("LibDeconValue" .. "Tooltips", EVENT_ADD_ON_LOADED)

  local function HookToolTip(tooltip, name, getItemLink)
    local original = tooltip[name]
    tooltip[name] = function(tooltip, ...)
      original(tooltip, ...)
      local itemLink = getItemLink(...)

      if itemLink then
        local spacing = false
        spacing = AddDeconPrice(tooltip, itemLink) or spacing
        --if spacing then tooltip:AddVerticalPadding(8) end
        --spacing = AddSources(tooltip, itemLink) or spacing
      end
    end
  end

  local identity = function (itemLink) return itemLink end

  HookToolTip(PopupTooltip, "SetLink", identity)

  HookToolTip(ZO_SmithingTopLevelCreationPanelResultTooltip, "SetPendingSmithingItem", GetSmithingPatternResultLink)

  HookToolTip(ItemTooltip, "SetBagItem", GetItemLink)
  HookToolTip(ItemTooltip, "SetWornItem", function (equipSlot) return GetItemLink(BAG_WORN, equipSlot) end)
  HookToolTip(ItemTooltip, "SetLootItem", GetLootItemLink)
  HookToolTip(ItemTooltip, "SetLink", identity)
  HookToolTip(ItemTooltip, "SetAttachedMailItem", GetAttachedItemLink)
  HookToolTip(ItemTooltip, "SetBuybackItem", GetBuybackItemLink)
  HookToolTip(ItemTooltip, "SetTradeItem", GetTradeItemLink)
  HookToolTip(ItemTooltip, "SetStoreItem", GetStoreItemLink)
  HookToolTip(ItemTooltip, "SetQuestReward", GetQuestRewardItemLink)
  HookToolTip(ItemTooltip, "SetTradingHouseListing", GetTradingHouseListingItemLink)
  HookToolTip(ItemTooltip, "SetCrownCrateReward", GetCrownCrateRewardItemLink)
  HookToolTip(ItemTooltip, "SetQuestItem", GetQuestItemLink)
  HookToolTip(ItemTooltip, "SetQuestTool", GetQuestToolLink)
  HookToolTip(ItemTooltip, "SetReward", GetItemRewardItemLink)
  HookToolTip(ItemTooltip, "SetDailyLoginRewardEntry", function (day)
    local rewardId, count, isMilestone = GetDailyLoginRewardInfoForCurrentMonth(day)
    local entryType = GetRewardType(rewardId)
    if entryType == REWARD_ENTRY_TYPE_ITEM then
      return GetItemRewardItemLink(rewardId, count)
    end
  end)

  if AwesomeGuildStore then
    AwesomeGuildStore:RegisterCallback(AwesomeGuildStore.callback.AFTER_INITIAL_SETUP, function ()
      HookToolTip(ItemTooltip, "SetTradingHouseItem", GetTradingHouseSearchResultItemLink)
    end)
  else
    HookToolTip(ItemTooltip, "SetTradingHouseItem", GetTradingHouseSearchResultItemLink)
  end
end)
