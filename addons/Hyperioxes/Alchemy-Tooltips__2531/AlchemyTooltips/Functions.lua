ATT_Functions = {}

function ATT_Functions:checkPotion(itemLink)
  if not ATT_savedVars.useTooltips then
    return nil
  end
  if GetItemLinkItemType(itemLink) == ITEMTYPE_MASTER_WRIT then
    local BestCombination = LibAlchemy:getBestCombinationMasterWrit(itemLink)
    if BestCombination ~= nil then
      return { BestCombination, string.format("%.3f", LibAlchemy:getCraftingCost(BestCombination, itemLink)), 0 }
    else
      return nil
    end
  end
  if GetItemLinkItemType(itemLink) ~= ITEMTYPE_POISON and GetItemLinkItemType(itemLink) ~= ITEMTYPE_POTION then
    return nil
  end
  local id = select(24, ZO_LinkHandler_ParseLink(itemLink)) or 0
  local mainID = select(4, ZO_LinkHandler_ParseLink(itemLink))
  --d(mainID .. "     -- Name ID")
  if LibAlchemy:tableContains(LibAlchemy.trashPotions, tonumber(mainID)) then

    return { [3] = 1 }
  end
  id = tonumber(id)
  if id == 0 then
    return nil
  end
  --d(id)

  local effectId1, effectId2, effectId3, prolongedEffectId = LibAlchemy:GetEffectsFromItemLink(itemLink)
  local effect1 = LibAlchemy.effectsByWritID[effectId1]
  local effect2 = LibAlchemy.effectsByWritID[effectId2]
  local effect3 = LibAlchemy.effectsByWritID[effectId3]
  local prolongedEffect = LibAlchemy.effectsByWritID[prolongedEffectId]

  local BestCombination = LibAlchemy:getBestCombination({ effect1, effect2, effect3, prolongedEffect })
  return { BestCombination, string.format("%.2f", LibAlchemy:getCraftingCost(BestCombination, itemLink)), 0 }
end

local function AddDivider(tooltip)
  if not IsInGamepadPreferredMode() then
    ZO_Tooltip_AddDivider(tooltip)
  end
end

local function AddVerticalPadding(tooltip, amount)
  if not IsInGamepadPreferredMode() then
    tooltip:AddVerticalPadding(amount)
  end
end

local function AddLine(tooltip, text)
  if not IsInGamepadPreferredMode() then
    tooltip:AddLine(text, "", 1, 1, 1, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
  end
end

function ATT_Functions:AddPotionInfo(tooltip, type)
  if type then
    if type[3] == 0 then
      AddDivider(tooltip)
      AddLine(tooltip, GetString(AT_CheapestCombination))

      if ATT_savedVars.useOld then
        AddVerticalPadding(tooltip, 8)
        AddLine(tooltip, ATT_Functions:PrintCombination(type[1]))
        AddVerticalPadding(tooltip, 16)
        AddLine(tooltip, ATT_Functions:PrintCombinationText(type[1]))

      else
        for key, value in pairs(type[1]) do
          AddLine(tooltip, "                     " .. LibAlchemy:getTextureFromID(value, 42) .. "            " .. ATT_Functions:getNameFromID(value))
          AddVerticalPadding(tooltip, 8)
        end

      end

      if ATT_savedVars.showCraftCost then
        AddDivider(tooltip)
        AddLine(tooltip, GetString(AT_CraftingCost) .. type[2] .. ' |t16:16:EsoUI/Art/currency/currency_gold.dds|t')
      end


    end
    if type[3] == 1 then
      AddDivider(tooltip)
      AddVerticalPadding(tooltip, 8)
      AddLine(tooltip, GetString(AT_CantCraft))


    end
    if type[3] == 2 then
      AddDivider(tooltip)
      AddVerticalPadding(tooltip, 8)
      AddLine(tooltip, GetString(AT_SendHelp))


    end
  end

end

function ATT_Functions:getPotionQualityBasedOnCraftingCost(craftingCost)
  if tostring(craftingCost) == "-nan(ind)" then
    return 1
  end
  for k = 1, 5 do
    if craftingCost < ATT_savedVars.craftingCostQualityBrackets[k] then
      return k
    end
  end
  return 6

end

local legacyEffectIdToSettingsId = {
  [13] = 11, -- Increase Weapon Power -> Increase Power
  [14] = 12, -- Maim -> Cowardice
  [17] = 15, -- Weapon Critical -> Critical
  [18] = 36, -- old Enervation id -> current Enervation setting
}

local function getDisplayedEffectName(effectId)
  local settingsEffectId = legacyEffectIdToSettingsId[effectId] or effectId
  return ATT_savedVars.effectsByWritIDShort[settingsEffectId]
end

function ATT_Functions:processItemLink(link)
  local effect1, effect2, effect3, effect4 = LibAlchemy:GetEffectsFromItemLink(link)
  local CP = tonumber(select(5, ZO_LinkHandler_ParseLink(link)) - select(6, ZO_LinkHandler_ParseLink(link)))
  local iconTexture = ATT_Variables.replaceIcons[GetItemLinkItemType(link) .. "-" .. CP .. "-" .. effect1 .. "-" .. effect2 .. "-" .. effect3] or 0
  if effect1 ~= 0 then
    local BestCombination = LibAlchemy:getBestCombination({ LibAlchemy.effectsByWritID[effect1], LibAlchemy.effectsByWritID[effect2], LibAlchemy.effectsByWritID[effect3], LibAlchemy.effectsByWritID[effect4] }) or 0
    local craftingCost = LibAlchemy:getCraftingCost(BestCombination, link) or 0
    local newText = "(" .. getDisplayedEffectName(effect1)
    if effect2 ~= 0 then
      newText = newText .. "/" .. getDisplayedEffectName(effect2)
      if effect3 ~= 0 then
        newText = newText .. "/" .. getDisplayedEffectName(effect3)
      end
    end
    newText = newText .. ")"
    return newText, ATT_Functions:getPotionQualityBasedOnCraftingCost(craftingCost), iconTexture
  end
  return GetItemLinkName(link), 0, 0
end

function ATT_Functions:GetCustomIconFromItemLink(link)
  local effect1, effect2, effect3, effect4 = LibAlchemy:GetEffectsFromItemLink(link)
  local CP = tonumber(select(5, ZO_LinkHandler_ParseLink(link)) - select(6, ZO_LinkHandler_ParseLink(link)))
  local iconTexture = ATT_Variables.replaceIcons[GetItemLinkItemType(link) .. "-" .. CP .. "-" .. effect1 .. "-" .. effect2 .. "-" .. effect3]
  return iconTexture
end

function ATT_Functions:GetCustomQualityFromItemLink(link)
  local effect1, effect2, effect3, effect4 = LibAlchemy:GetEffectsFromItemLink(link)
  if effect1 ~= 0 then
    local BestCombination = LibAlchemy:getBestCombination({ LibAlchemy.effectsByWritID[effect1], LibAlchemy.effectsByWritID[effect2], LibAlchemy.effectsByWritID[effect3], LibAlchemy.effectsByWritID[effect4] }) or 0
    local craftingCost = LibAlchemy:getCraftingCost(BestCombination, link) or 0
    return ATT_Functions:getPotionQualityBasedOnCraftingCost(craftingCost)
  end
  return nil
end

function ATT_Functions:countPricingAddons()
  local counter = 0
  if ATT_savedVars.TTCuse and LibPrice.ItemLinkToPriceGold("|H0:item:30148:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", "ttc") ~= nil then
    counter = counter + 1
  end
  if ATT_savedVars.MMuse and LibPrice.ItemLinkToPriceGold("|H0:item:30148:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", "mm") ~= nil then
    counter = counter + 1
  end
  if ATT_savedVars.ATTuse and LibPrice.ItemLinkToPriceGold("|H0:item:30148:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", "att") ~= nil then
    counter = counter + 1
  end
  return counter
end

function ATT_Functions:GeneratePrice(itemLink)
  result = 0
  if ATT_savedVars.TTCuse == true and LibPrice.ItemLinkToPriceGold(itemLink, "ttc") ~= nil then
    result = result + LibPrice.ItemLinkToPriceGold(itemLink, "ttc") * ATT_savedVars.TTCMultiplier
  end
  if ATT_savedVars.MMuse == true and LibPrice.ItemLinkToPriceGold(itemLink, "mm") ~= nil then
    result = result + LibPrice.ItemLinkToPriceGold(itemLink, "mm") * ATT_savedVars.MMMultiplier
  end
  if ATT_savedVars.ATTuse == true and LibPrice.ItemLinkToPriceGold(itemLink, "att") ~= nil then
    result = result + LibPrice.ItemLinkToPriceGold(itemLink, "att") * ATT_savedVars.ATTMultiplier
  end
  return result / ATT_Functions:countPricingAddons()

end

function ATT_Functions:PrintCombination(table)

  result = reagents[table[1]][1]
  for key1, value1 in pairs(table) do
    if key1 ~= 1 and value1 ~= 0 then
      result = result .. "                  +                     " .. reagents[value1][1]
    end
  end
  result = string.gsub(result, "                  +                     ", "")
  return result
end

function ATT_Functions:PrintCombinationText(table)

  result = zo_strformat("<<t:1>>", GetItemLinkName(("|H0:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"):format(table[1])))
  for key1, value1 in pairs(table) do
    if key1 ~= 1 and value1 ~= 0 then
      result = result .. " + " .. zo_strformat("<<t:1>>", GetItemLinkName(("|H0:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"):format(value1)))
    end
  end
  result = string.gsub(result, " + ", "")
  return result
end

function ATT_Functions:getNameFromID(id)
  return zo_strformat("<<t:1>>", GetItemLinkName(("|H0:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"):format(id)))
end

function ATT_Functions:getCheapestCombination(table)
  local cheapestRecord = 0
  local result = nil
  local amount = 0
  for key2, value2 in pairs(table) do
    for key1, value1 in pairs(value2) do
      amount = amount + reagents[value1][2]
    end
    if (cheapestRecord > amount or result == nil) and (value2[1] ~= value2[2] and value2[1] ~= value2[3] and value2[2] ~= value2[3]) then
      result = value2
      cheapestRecord = amount
    end
    amount = 0
  end
  return result
end

function ATT_Functions:InitializePrices()
  --Reagents

  LibAlchemy.reagents[30148][2] = ATT_Functions:GeneratePrice("|H0:item:30148:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30160][2] = ATT_Functions:GeneratePrice("|H0:item:30160:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[77585][2] = ATT_Functions:GeneratePrice("|H0:item:77585:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30149][2] = ATT_Functions:GeneratePrice("|H0:item:30149:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30151][2] = ATT_Functions:GeneratePrice("|H0:item:30151:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30152][2] = ATT_Functions:GeneratePrice("|H0:item:30152:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30153][2] = ATT_Functions:GeneratePrice("|H0:item:30153:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30154][2] = ATT_Functions:GeneratePrice("|H0:item:30154:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30155][2] = ATT_Functions:GeneratePrice("|H0:item:30155:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30156][2] = ATT_Functions:GeneratePrice("|H0:item:30156:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30157][2] = ATT_Functions:GeneratePrice("|H0:item:30157:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30158][2] = ATT_Functions:GeneratePrice("|H0:item:30158:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30159][2] = ATT_Functions:GeneratePrice("|H0:item:30159:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30161][2] = ATT_Functions:GeneratePrice("|H0:item:30161:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30162][2] = ATT_Functions:GeneratePrice("|H0:item:30162:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30163][2] = ATT_Functions:GeneratePrice("|H0:item:30163:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30164][2] = ATT_Functions:GeneratePrice("|H0:item:30164:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30165][2] = ATT_Functions:GeneratePrice("|H0:item:30165:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30166][2] = ATT_Functions:GeneratePrice("|H0:item:30166:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[77581][2] = ATT_Functions:GeneratePrice("|H0:item:77581:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[77583][2] = ATT_Functions:GeneratePrice("|H0:item:77583:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[77584][2] = ATT_Functions:GeneratePrice("|H0:item:77584:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[77587][2] = ATT_Functions:GeneratePrice("|H0:item:77587:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[77589][2] = ATT_Functions:GeneratePrice("|H0:item:77589:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[77590][2] = ATT_Functions:GeneratePrice("|H0:item:77590:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[77591][2] = ATT_Functions:GeneratePrice("|H0:item:77591:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[150789][2] = ATT_Functions:GeneratePrice("|H0:item:150789:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[150731][2] = ATT_Functions:GeneratePrice("|H0:item:150731:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[150671][2] = ATT_Functions:GeneratePrice("|H0:item:150671:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[139019][2] = ATT_Functions:GeneratePrice("|H0:item:139019:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[139020][2] = ATT_Functions:GeneratePrice("|H0:item:139020:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[150672][2] = ATT_Functions:GeneratePrice("|H0:item:150672:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[150670][2] = ATT_Functions:GeneratePrice("|H0:item:150670:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[150669][2] = ATT_Functions:GeneratePrice("|H0:item:150669:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[224357][2] = ATT_Functions:GeneratePrice("|H0:item:224357:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[224358][2] = ATT_Functions:GeneratePrice("|H0:item:224358:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[224359][2] = ATT_Functions:GeneratePrice("|H0:item:224359:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[224360][2] = ATT_Functions:GeneratePrice("|H0:item:224360:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")

  --solvents
  LibAlchemy.solvents[3][1] = ATT_Functions:GeneratePrice("|H0:item:883:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h") or 0
  LibAlchemy.solvents[3][2] = ATT_Functions:GeneratePrice("|H0:item:75357:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h") or 0
  LibAlchemy.solvents[10][1] = ATT_Functions:GeneratePrice("|H0:item:1187:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents[10][2] = ATT_Functions:GeneratePrice("|H0:item:75358:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents[20][1] = ATT_Functions:GeneratePrice("|H0:item:4570:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents[20][2] = ATT_Functions:GeneratePrice("|H0:item:75359:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents[30][1] = ATT_Functions:GeneratePrice("|H0:item:23265:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents[30][2] = ATT_Functions:GeneratePrice("|H0:item:75360:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents[40][1] = ATT_Functions:GeneratePrice("|H0:item:23266:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents[40][2] = ATT_Functions:GeneratePrice("|H0:item:75361:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents["CP"][75][1] = ATT_Functions:GeneratePrice("|H0:item:23267:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents["CP"][75][2] = ATT_Functions:GeneratePrice("|H0:item:75362:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents["CP"][79][1] = ATT_Functions:GeneratePrice("|H0:item:23268:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents["CP"][79][2] = ATT_Functions:GeneratePrice("|H0:item:75363:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents["CP"][84][1] = ATT_Functions:GeneratePrice("|H0:item:64500:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents["CP"][84][2] = ATT_Functions:GeneratePrice("|H0:item:75364:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents["CP"][258][1] = ATT_Functions:GeneratePrice("|H0:item:64501:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents["CP"][258][2] = ATT_Functions:GeneratePrice("|H0:item:75365:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")


end