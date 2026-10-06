-- Input effects indices
local EFFECT_INDEX_PRIMARY = 1
local EFFECT_INDEX_SECONDARY = 2
local EFFECT_INDEX_TERTIARY = 3
local EFFECT_INDEX_PROLONGED = 4

-- Effect lengths
local EFFECT_LENGTH_ONE = 1
local EFFECT_LENGTH_TWO = 2
local EFFECT_LENGTH_THREE = 3

local LIBALCHEMY_WRIT_ITEMTYPE_POTION = 199
local LIBALCHEMY_WRIT_ITEMTYPE_POISON = 239

function LibAlchemy:InitializePrices(source)
  --Initializes prices using LibPrice, you need to call this function in your addon before you can use any price related functions
  if source == LibAlchemy.SOURCE_MM and LibAlchemy.isMMInitialized then return end
  if source == LibAlchemy.SOURCE_ATT and LibAlchemy.isArkadiusInitialized then return end
  if source == LibAlchemy.SOURCE_TTC and LibAlchemy.isTTCInitialized then return end
  if source == LibAlchemy.SOURCE_ATTip and LibAlchemy.isAttInitialized then return end

  --Reagents
  LibAlchemy.reagents[30148][2] = LibPrice.ItemLinkToPriceGold("|H0:item:30148:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30149][2] = LibPrice.ItemLinkToPriceGold("|H0:item:30149:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30151][2] = LibPrice.ItemLinkToPriceGold("|H0:item:30151:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30152][2] = LibPrice.ItemLinkToPriceGold("|H0:item:30152:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30153][2] = LibPrice.ItemLinkToPriceGold("|H0:item:30153:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30154][2] = LibPrice.ItemLinkToPriceGold("|H0:item:30154:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30155][2] = LibPrice.ItemLinkToPriceGold("|H0:item:30155:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30156][2] = LibPrice.ItemLinkToPriceGold("|H0:item:30156:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30157][2] = LibPrice.ItemLinkToPriceGold("|H0:item:30157:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30158][2] = LibPrice.ItemLinkToPriceGold("|H0:item:30158:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30159][2] = LibPrice.ItemLinkToPriceGold("|H0:item:30159:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30160][2] = LibPrice.ItemLinkToPriceGold("|H0:item:30160:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30161][2] = LibPrice.ItemLinkToPriceGold("|H0:item:30161:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30162][2] = LibPrice.ItemLinkToPriceGold("|H0:item:30162:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30163][2] = LibPrice.ItemLinkToPriceGold("|H0:item:30163:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30164][2] = LibPrice.ItemLinkToPriceGold("|H0:item:30164:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30165][2] = LibPrice.ItemLinkToPriceGold("|H0:item:30165:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[30166][2] = LibPrice.ItemLinkToPriceGold("|H0:item:30166:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[77581][2] = LibPrice.ItemLinkToPriceGold("|H0:item:77581:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[77583][2] = LibPrice.ItemLinkToPriceGold("|H0:item:77583:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[77584][2] = LibPrice.ItemLinkToPriceGold("|H0:item:77584:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[77585][2] = LibPrice.ItemLinkToPriceGold("|H0:item:77585:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[77587][2] = LibPrice.ItemLinkToPriceGold("|H0:item:77587:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[77589][2] = LibPrice.ItemLinkToPriceGold("|H0:item:77589:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[77590][2] = LibPrice.ItemLinkToPriceGold("|H0:item:77590:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[77591][2] = LibPrice.ItemLinkToPriceGold("|H0:item:77591:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[139019][2] = LibPrice.ItemLinkToPriceGold("|H0:item:139019:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[139020][2] = LibPrice.ItemLinkToPriceGold("|H0:item:139020:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[150669][2] = LibPrice.ItemLinkToPriceGold("|H0:item:150669:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[150670][2] = LibPrice.ItemLinkToPriceGold("|H0:item:150670:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[150671][2] = LibPrice.ItemLinkToPriceGold("|H0:item:150671:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[150672][2] = LibPrice.ItemLinkToPriceGold("|H0:item:150672:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[150731][2] = LibPrice.ItemLinkToPriceGold("|H0:item:150731:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[150789][2] = LibPrice.ItemLinkToPriceGold("|H0:item:150789:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[224357][2] = LibPrice.ItemLinkToPriceGold("|H0:item:224357:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[224358][2] = LibPrice.ItemLinkToPriceGold("|H0:item:224358:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[224359][2] = LibPrice.ItemLinkToPriceGold("|H0:item:224359:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.reagents[224360][2] = LibPrice.ItemLinkToPriceGold("|H0:item:224360:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")

  --Solvents
  LibAlchemy.solvents[3][1] = LibPrice.ItemLinkToPriceGold("|H0:item:883:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h") or 0--Natural Water
  LibAlchemy.solvents[3][2] = LibPrice.ItemLinkToPriceGold("|H0:item:75357:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h") or 0--Grease
  LibAlchemy.solvents[10][1] = LibPrice.ItemLinkToPriceGold("|H0:item:1187:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents[10][2] = LibPrice.ItemLinkToPriceGold("|H0:item:75358:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents[20][1] = LibPrice.ItemLinkToPriceGold("|H0:item:4570:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents[20][2] = LibPrice.ItemLinkToPriceGold("|H0:item:75359:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents[30][1] = LibPrice.ItemLinkToPriceGold("|H0:item:23265:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents[30][2] = LibPrice.ItemLinkToPriceGold("|H0:item:75360:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents[40][1] = LibPrice.ItemLinkToPriceGold("|H0:item:23266:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents[40][2] = LibPrice.ItemLinkToPriceGold("|H0:item:75361:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents["CP"][75][1] = LibPrice.ItemLinkToPriceGold("|H0:item:23267:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents["CP"][75][2] = LibPrice.ItemLinkToPriceGold("|H0:item:75362:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents["CP"][79][1] = LibPrice.ItemLinkToPriceGold("|H0:item:23268:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents["CP"][79][2] = LibPrice.ItemLinkToPriceGold("|H0:item:75363:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents["CP"][84][1] = LibPrice.ItemLinkToPriceGold("|H0:item:64500:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents["CP"][84][2] = LibPrice.ItemLinkToPriceGold("|H0:item:75364:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h")
  LibAlchemy.solvents["CP"][258][1] = LibPrice.ItemLinkToPriceGold("|H0:item:64501:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h") --Lorkhan Tears
  LibAlchemy.solvents["CP"][258][2] = LibPrice.ItemLinkToPriceGold("|H0:item:75365:30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h") --Alkahest
  if source == LibAlchemy.SOURCE_MM then LibAlchemy.isMMInitialized = true end
  if source == LibAlchemy.SOURCE_ATT then LibAlchemy.isArkadiusInitialized = true end
  if source == LibAlchemy.SOURCE_TTC then LibAlchemy.isTTCInitialized = true end
  if source == LibAlchemy.SOURCE_ATTip then LibAlchemy.isAttInitialized = true end
end

--input table of effect names for example {"RestoreHealth","RestoreMagicka","RestoreStamina"}
--you can also add prolonged effect - an effect that will last longer because it appears in the combination 3 times, instead of 2
--prolonged effect always has to have index = 4
--for example, if you want a combination with only 2 effects and one of them to be prolonged you input {"RestoreHealth","RestoreMagicka",[4] = "RestoreHealth"}
--outputs IDs (1st number in itemLinks, not actual itemLinks) for reagents that will create desired combination for cheapest price
local function getCombinations(tableOfEffects)
  local effect1, effect2, effect3, prolongedEffect, Combinations, length
  local BestCombination
  if tableOfEffects[1] and tableOfEffects[1] ~= 0 then
    effect1 = tableOfEffects[1]
    length = 1
  end
  if tableOfEffects[2] and tableOfEffects[2] ~= 0 then
    effect2 = tableOfEffects[2]
    length = 2
  end
  if tableOfEffects[3] and tableOfEffects[3] ~= 0 then
    effect3 = tableOfEffects[3]
    length = 3
  end
  if tableOfEffects[4] and tableOfEffects[4] ~= 0 then
    prolongedEffect = tableOfEffects[4]
  end

  if length == 3 then
    Combinations = LibAlchemy:ThreeEffects(effect1, effect2, effect3)
    if Combinations[1] == nil then
      Combinations = LibAlchemy:ThreeEffectsAlt(effect1, effect2, effect3)
    end
    Combinations = LibAlchemy:sortOutWrongCombinations3(Combinations, { effect1, effect2, effect3 })
    if prolongedEffect then
      Combinations = LibAlchemy:sortOutAdditional(Combinations, prolongedEffect)
    end
    BestCombination = LibAlchemy:getCheapestCombination(Combinations)
    return BestCombination
  elseif length == 2 then
    Combinations = LibAlchemy:TwoEffects(effect1, effect2)
    Combinations = LibAlchemy:sortOutWrongCombinations3(Combinations, { effect1, effect2 })
    if prolongedEffect then
      Combinations = LibAlchemy:sortOutAdditional(Combinations, prolongedEffect)
    end
    return LibAlchemy:getCheapestCombination(Combinations)
  elseif length == 1 then
    Combinations = LibAlchemy:OneEffect(effect1)
    Combinations = LibAlchemy:sortOutWrongCombinations2(Combinations, effect1)
    if prolongedEffect then
      Combinations = LibAlchemy:OneEffectAlt(effect1)
      Combinations = LibAlchemy:sortOutWrongCombinations3(Combinations, { effect1 })
      Combinations = LibAlchemy:sortOutAdditional(Combinations, prolongedEffect)
    end
    if not Combinations[1] then
      Combinations = LibAlchemy:OneEffect(effect1)
      local Combinations2 = {}
      for key, value in pairs(Combinations) do
        local negativeEffect = LibAlchemy:checkIfAdditional2Effect(value, effect1)
        for key2, value2 in pairs(LibAlchemy.effects[LibAlchemy.opposites[negativeEffect]]) do
          if LibAlchemy:checkIfAdditionalCorrect({ value[1], value[2], value2 }, effect1) and LibAlchemy:checkIfAdditional3({ value[1], value[2], value2 }, { effect1 }) then
            Combinations2[#Combinations2 + 1] = { value[1], value[2], value2 }
          end
        end

      end
      Combinations = Combinations2
    end

    return LibAlchemy:getCheapestCombination(Combinations)
  end
end

local potionEffectCache = {}
-- LibAlchemy.effectCache = potionEffectCache
function LibAlchemy:getBestCombination(tableOfEffects)
  local sorted = {}
  for i = 1, 4 do
    local effect = tableOfEffects[i]
    if effect then
      table.insert(sorted, effect)
    end
  end
  table.sort(sorted)

  local hash = table.concat(sorted, "|")

  if not potionEffectCache[hash] then
    potionEffectCache[hash] = getCombinations(tableOfEffects)
  end

  return potionEffectCache[hash]
end

--input table of reagents' IDs for example {30148,30149,30150} and itemLink
--outputs crafting cost
function LibAlchemy:getCraftingCost(reagentsTable, itemLink)
  local mainID, solvent, CP
  local itemType, specializedItemType = GetItemLinkItemType(itemLink)
  if itemType == ITEMTYPE_MASTER_WRIT then
    mainID = LibAlchemy:ATconvertItemLink(itemLink)
    solvent = 50
    CP = 258
  else
    mainID = select(4, ZO_LinkHandler_ParseLink(itemLink))
    CP = tonumber(select(5, ZO_LinkHandler_ParseLink(itemLink)) - select(6, ZO_LinkHandler_ParseLink(itemLink)))
    solvent = tonumber(select(6, ZO_LinkHandler_ParseLink(itemLink)) - select(7, ZO_LinkHandler_ParseLink(itemLink)))
  end
  local result = 0
  local solventType = 2
  if itemType == ITEMTYPE_POTION then solventType = 1
  elseif itemType == ITEMTYPE_POISON then solventType = 2 end

  for key1, value1 in pairs(reagentsTable) do
    result = result + LibAlchemy.reagents[value1][2]
  end

  if solvent == 50 then
    result = result + LibAlchemy.solvents["CP"][CP][solventType]
  else
    result = result + LibAlchemy.solvents[solvent][solventType]
  end
  if mainID == LIBALCHEMY_WRIT_ITEMTYPE_POISON then
    return result
  elseif mainID == LIBALCHEMY_WRIT_ITEMTYPE_POTION then
    return result * 4
  elseif GetItemLinkItemType(itemLink) == 7 then
    return result / 4
  else
    return result / 16
  end

end

--input itemLink
--outputs cheapest combination of reagents that will craft potion/poison required to fulfill master writ
function LibAlchemy:getBestCombinationMasterWrit(itemLink)
  local solvent, effect1, effect2, effect3 = LibAlchemy:ATconvertItemLink(itemLink)
  if solvent == LIBALCHEMY_WRIT_ITEMTYPE_POTION or solvent == LIBALCHEMY_WRIT_ITEMTYPE_POISON then
    effect1 = LibAlchemy.potionEffectIdToString[effect1]
    effect2 = LibAlchemy.potionEffectIdToString[effect2]
    effect3 = LibAlchemy.potionEffectIdToString[effect3]
    if effect3 == 0 then
      local Combinations = LibAlchemy:TwoEffects(effect1, effect2)
      Combinations = LibAlchemy:sortOutWrongCombinations3(Combinations, { effect1, effect2 })
      return LibAlchemy:getCheapestCombination(Combinations)
    else
      local Combinations = LibAlchemy:ThreeEffects(effect1, effect2, effect3)
      if Combinations[1] == nil then
        Combinations = LibAlchemy:ThreeEffectsAlt(effect1, effect2, effect3)
      end
      return LibAlchemy:getCheapestCombination(Combinations)
    end
  end
  return nil
end

----------------------- Most of functions below this point will have no explanations as they probably won't be of any use on their own and they're there to be used in functions above

function LibAlchemy:getCraftingCostWithoutItemLink(reagentsTable, mainID, solvent, CP)

  local result = 0
  local type = 2
  for key1, value1 in pairs(reagentsTable) do
    result = result + reagents[value1][2]
  end

  if solvent == 50 then
    result = result + solvents["CP"][CP][type]
  else
    result = result + solvents[solvent][type]
  end
  if mainID == LIBALCHEMY_WRIT_ITEMTYPE_POISON then
    return result
  elseif mainID == LIBALCHEMY_WRIT_ITEMTYPE_POTION then
    return result * 4
  elseif table.contains(potionPrimaryIDs, mainID) then
    return result / 4
  else
    return result / 16
  end

end

--tableOfReagents - table of reagents' first ID numbers (example: {30148,30160} which would be Blue Entoloma and Bugloss)
--effectToCheck - string name of effect (example: "RestoreHealth" will check if any of reagents has "RavageHealth")
--In this example none of reagents have "RavageHealth", so function will return true
function LibAlchemy:checkIfCorrect(tableOfReagents, effectToCheck)
  -- Checks if any of reagents in the table has effect opposite to effectToCheck

  for key1, value1 in pairs(tableOfReagents) do

    for key2, value2 in pairs(LibAlchemy.reagents[value1][3]) do

      if value2 == LibAlchemy.opposites[effectToCheck] then
        return false
      end
    end
  end
  return true
end

--tableOfReagentsX - table of 2 reagents's first ID numbers (example: {30148,30160} which would be Blue Entoloma and Bugloss)
--correctEffect - string name of effect (example: "RestoreHealth")
--In this example apart from our desired effect - RestoreHealth - there's also Cowardice, so function will return false
function LibAlchemy:checkIfAdditional2(tableOfReagentsX, correctEffect)
  -- Check if combination of 2 reagents yields any effects other than the correctEffect
  for key1, value1 in pairs(LibAlchemy.reagents[tableOfReagentsX[1]][3]) do
    for key2, value2 in pairs(LibAlchemy.reagents[tableOfReagentsX[2]][3]) do
      if value1 == value2 and value1 ~= correctEffect then
        return false
      end
    end
  end
  return true
end

function LibAlchemy:checkIfAdditionalCorrect(tableOfReagentsX, correctEffect)
  for key1, value1 in pairs(LibAlchemy.reagents[tableOfReagentsX[1]][3]) do
    for key2, value2 in pairs(LibAlchemy.reagents[tableOfReagentsX[2]][3]) do
      if value1 == value2 and LibAlchemy:checkIfNotIn(LibAlchemy.opposites[correctEffect], LibAlchemy.reagents[tableOfReagentsX[3]][3]) and value1 == correctEffect then
        return true
      end
    end
  end
  return false
end

function LibAlchemy:checkIfAdditional2Effect(tableOfReagentsX, correctEffect)
  for key1, value1 in pairs(LibAlchemy.reagents[tableOfReagentsX[1]][3]) do
    for key2, value2 in pairs(LibAlchemy.reagents[tableOfReagentsX[2]][3]) do
      if value1 == value2 and value1 ~= correctEffect then
        return value1
      end
    end
  end
  return nil
end

function LibAlchemy:checkIfNotIn(value, table)
  -- Checks if value is not in the table
  for key1, value1 in pairs(table) do
    if value == value1 then
      return false
    end
  end
  return true
end


--tableOfReagentsX - table of 3 reagents's first ID numbers (example: {30148,30160,77585} which would be Blue Entoloma, Bugloss and Butterfly Wing)
--correctEffects - table of string names of effects (example: {"RestoreHealth","Cowardice"})
--In this example there are no other effects other than our desired effects - Restore Health and Cowardice - so function will return true
function LibAlchemy:checkIfAdditional3(tableOfReagentsX, correctEffects)
  -- Check if combination of 3 reagents yields any effects other than the correctEffects
  local temp = true
  for key1, value1 in pairs(LibAlchemy.reagents[tableOfReagentsX[1]][3]) do
    for key2, value2 in pairs(LibAlchemy.reagents[tableOfReagentsX[2]][3]) do
      for key3, value3 in pairs(LibAlchemy.reagents[tableOfReagentsX[3]][3]) do
        if (value1 == value2 and LibAlchemy:checkIfNotIn(value1, correctEffects) and LibAlchemy:checkIfNotIn(LibAlchemy.opposites[value1], LibAlchemy.reagents[tableOfReagentsX[3]][3])) or (value2 == value3 and LibAlchemy:checkIfNotIn(value2, correctEffects) and LibAlchemy:checkIfNotIn(LibAlchemy.opposites[value2],
          LibAlchemy.reagents[tableOfReagentsX[1]][3])) or (value1 == value3 and LibAlchemy:checkIfNotIn(value1, correctEffects) and LibAlchemy:checkIfNotIn(LibAlchemy.opposites[value1], LibAlchemy.reagents[tableOfReagentsX[2]][3])) then
          temp = false
        end
      end
    end
  end
  return temp
end

function LibAlchemy:tableContains(table, element)
  -- Checks if table contains element
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

--tableOfTables is a table of tables of possible combinations for example {{30148,30160},{30149,30150},{30151,30152,30153}}
function LibAlchemy:getCheapestCombination(tableOfTables)
  -- Checks which of combinations from tableOfTables is cheapest to craft
  local cheapestRecord = 0
  local result = nil
  local amount = 0
  for key2, value2 in pairs(tableOfTables) do
    for key1, value1 in pairs(value2) do
      amount = amount + LibAlchemy.reagents[value1][2]
    end
    if (cheapestRecord > amount or result == nil) and (value2[1] ~= value2[2] and value2[1] ~= value2[3] and value2[2] ~= value2[3]) then
      result = value2
      cheapestRecord = amount
    end
    amount = 0
  end
  return result
end

function LibAlchemy:sortOutWrongCombinations2(allCombinations, effect)
  local result = {}

  for key1, value1 in pairs(allCombinations) do
    if LibAlchemy:checkIfAdditional2(value1, effect) then
      result[#result + 1] = value1
    end
  end
  return result
end

function LibAlchemy:sortOutWrongCombinations3(allCombinations, effects)
  local result = {}

  for key1, value1 in pairs(allCombinations) do
    if #value1 == 3 then
      if LibAlchemy:checkIfAdditional3(value1, effects) then
        result[#result + 1] = value1
      end
    end
    if #value1 == 2 then
      result[#result + 1] = value1
    end
  end
  return result
end

function LibAlchemy:sortOutAdditional(allCombinations, additionalEffect)
  local result = {}
  local temp

  for key1, value1 in pairs(allCombinations) do
    temp = true
    if value1[3] then

      for key2, value2 in pairs(value1) do

        if LibAlchemy:checkIfNotIn(additionalEffect, LibAlchemy.reagents[value2][3]) then

          temp = false
        end

      end
      if temp then
        result[#result + 1] = value1
      end
    end
  end
  return result
end

function LibAlchemy:ATconvertItemLink(itemLink)
  -- input itemLink, returns solvent,effect1,effect2,effect3
  local link = { ZO_LinkHandler_ParseLink(itemLink) }
  return tonumber(link[10]), tonumber(link[11]), tonumber(link[12]), tonumber(link[13])
end

function LibAlchemy:OneEffect(first)
  local connectedIngredients = {}
  for key1, value1 in pairs(LibAlchemy.effects[first]) do
    for key2, value2 in pairs(LibAlchemy.effects[first]) do
      if value1 ~= value2 then
        connectedIngredients[#connectedIngredients + 1] = { value1, value2 }
      end
    end
  end
  return connectedIngredients
end

function LibAlchemy:OneEffectAlt(first)
  local connectedIngredients = {}
  for key1, value1 in pairs(LibAlchemy.effects[first]) do
    for key2, value2 in pairs(LibAlchemy.effects[first]) do
      for key3, value3 in pairs(LibAlchemy.effects[first]) do
        if value1 ~= value2 and value1 ~= value3 and value2 ~= value3 then
          connectedIngredients[#connectedIngredients + 1] = { value1, value2, value3 }
        end
      end
    end
  end
  return connectedIngredients
end

function LibAlchemy:TwoEffects(first, second)
  local connectedIngredients2 = {}
  local firstConnectedIngredients = LibAlchemy:OneEffect(first)
  local secondConnectedIngredients = LibAlchemy:OneEffect(second)
  for key1, value1 in pairs(firstConnectedIngredients) do
    for key2, value2 in pairs(secondConnectedIngredients) do
      if value1[1] == value2[1] and value1[2] == value2[2] then

        connectedIngredients2[#connectedIngredients2 + 1] = { value1[1], value1[2] }

      elseif value1[1] == value2[2] and value1[2] == value2[1] then

        connectedIngredients2[#connectedIngredients2 + 1] = { value1[1], value1[2] }

      elseif LibAlchemy:tableContains(value2, value1[1]) then
        if LibAlchemy:checkIfCorrect({ value1[2], value2[1], value2[2] }, first) and LibAlchemy:checkIfCorrect({ value1[2], value2[1], value2[2] }, second) then
          connectedIngredients2[#connectedIngredients2 + 1] = { value1[2], value2[1], value2[2] }
        end

      elseif LibAlchemy:tableContains(value2, value1[2]) then
        if LibAlchemy:checkIfCorrect({ value1[1], value2[1], value2[2] }, first) and LibAlchemy:checkIfCorrect({ value1[1], value2[1], value2[2] }, second) then
          connectedIngredients2[#connectedIngredients2 + 1] = { value1[1], value2[1], value2[2] }
        end

      end
    end
  end

  return connectedIngredients2
end

function LibAlchemy:ThreeEffectsAlt(first, second, third)
  local connectedIngredients = {}
  local firstConnectedIngredients = LibAlchemy:OneEffect(first)
  local secondConnectedIngredients = LibAlchemy:OneEffect(second)
  local thirdConnectedIngredients = LibAlchemy:OneEffect(third)
  local hash
  local result
  for key1, value1 in pairs(firstConnectedIngredients) do
    for key2, value2 in pairs(secondConnectedIngredients) do
      for key3, value3 in pairs(thirdConnectedIngredients) do
        if value1[1] == value2[1] or value1[1] == value2[2] or value1[2] == value2[1] or value1[2] == value2[2] then
          if value1[1] == value3[1] or value1[1] == value3[2] or value1[2] == value3[1] or value1[2] == value3[2] then
            if value3[1] == value2[1] or value3[1] == value2[2] or value3[2] == value2[1] or value3[2] == value2[2] then
              hash = {}
              result = {}
              for _, v in ipairs({ value1[1], value1[2], value2[1], value2[2], value3[1], value3[2] }) do
                if (not hash[v]) then
                  result[#result + 1] = v
                  hash[v] = true
                end

              end
              connectedIngredients[#connectedIngredients + 1] = result
            end
          end
        end
      end
    end
  end
  return connectedIngredients
end

function LibAlchemy:ThreeEffects(first, second, third)
  local connectedIngredients3 = {}
  local firstConnectedIngredients = LibAlchemy:OneEffect(first)
  local secondConnectedIngredients = LibAlchemy:OneEffect(second)
  local thirdConnectedIngredients = LibAlchemy:OneEffect(third)
  local firstConnectedIngredientsX = LibAlchemy:TwoEffects(first, second)
  local secondConnectedIngredientsX = LibAlchemy:TwoEffects(second, third)
  local thirdConnectedIngredientsX = LibAlchemy:TwoEffects(first, third)
  for key1, value1 in pairs(firstConnectedIngredients) do
    for key2, value2 in pairs(secondConnectedIngredientsX) do
      for key3, value3 in pairs(value2) do

        if (value1[1] == value3 or value1[2] == value3) and table.getn(value2) == 2 then
          if key3 == 1 then

            connectedIngredients3[#connectedIngredients3 + 1] = { value1[1], value1[2], value2[2] }

          end
          if key3 == 2 then

            connectedIngredients3[#connectedIngredients3 + 1] = { value1[1], value1[2], value2[1] }

          end
        end
      end
    end
  end
  for key1, value1 in pairs(secondConnectedIngredients) do
    for key2, value2 in pairs(thirdConnectedIngredientsX) do
      for key3, value3 in pairs(value2) do

        if (value1[1] == value3 or value1[2] == value3) and table.getn(value2) == 2 then
          if key3 == 1 then

            connectedIngredients3[#connectedIngredients3 + 1] = { value1[1], value1[2], value2[2] }

          end
          if key3 == 2 then

            connectedIngredients3[#connectedIngredients3 + 1] = { value1[1], value1[2], value2[1] }

          end
        end
      end
    end
  end

  for key1, value1 in pairs(thirdConnectedIngredients) do
    for key2, value2 in pairs(firstConnectedIngredientsX) do
      for key3, value3 in pairs(value2) do

        if (value1[1] == value3 or value1[2] == value3) and table.getn(value2) == 2 then
          if key3 == 1 then

            connectedIngredients3[#connectedIngredients3 + 1] = { value1[1], value1[2], value2[2] }

          end
          if key3 == 2 then

            connectedIngredients3[#connectedIngredients3 + 1] = { value1[1], value1[2], value2[1] }

          end
        end
      end
    end
  end

  return connectedIngredients3
end

function LibAlchemy:getTextureFromID(id, size)
  if size then
    return string.gsub(LibAlchemy.reagents[id][1], "64", size, 2)
  end
  return LibAlchemy.reagents[id][1]

end

function LibAlchemy:GetEffectsFromItemLink(itemLink)
  local id = select(24, ZO_LinkHandler_ParseLink(itemLink)) or 0

  local b1 = math.floor(id / 65536) % 256
  local b2 = math.floor(id / 256) % 256
  local b3 = id % 256

  local effect1 = b1 > 127 and b1 - 128 or b1
  local effect2 = b2 > 127 and b2 - 128 or b2
  local effect3 = b3 > 127 and b3 - 128 or b3

  local prolongedEffect
  if b1 > 127 then
    prolongedEffect = effect1
  elseif b2 > 127 then
    prolongedEffect = effect2
  elseif b3 > 127 then
    prolongedEffect = effect3
  end

  return effect1, effect2, effect3, prolongedEffect
end

function LibAlchemy:GenerateItemLinkFromID(id)
  return "|H0:item:" .. id .. ":30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
end

function LibAlchemy:getNameFromID(id)
  return GetItemLinkName(LibAlchemy:GenerateItemLinkFromID(id))
end
