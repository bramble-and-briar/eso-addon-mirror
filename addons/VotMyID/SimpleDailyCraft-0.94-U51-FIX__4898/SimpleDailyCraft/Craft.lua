local SDC = SimpleDailyCraft

---------------------
----Tool Function----
---------------------

local function ToLink(Id)
  if not Id then return "" end
  return "|H0:item:"..Id..":30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
end

local function IsInTable(value, tbl)
  for k,v in ipairs(tbl) do
    if v == value then
      return true
    end
  end
  return false
end

local function IsTTCWork()
  --No TTC
  if TamrielTradeCentrePrice == nil then return false end
  --No TTC Update
  if TamrielTradeCentrePrice:GetPriceInfo("|H1:item:30164:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h") == nil then return false end
  return true
end
------------------
----Craft Part----
------------------

--Treat info with Callback "SceneStateChanged"
function SDC.CraftCore(scene, _, newstate)
  if scene.name ~= "smithing" and scene.name ~= "provisioner" and scene.name ~= "enchanting" and scene.name ~= "alchemy" then return end
  if newstate == SCENE_HIDING then --Reset
    EVENT_MANAGER:UnregisterForEvent(SDC.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(SDC.name, EVENT_CRAFT_COMPLETED)
    EVENT_MANAGER:UnregisterForEvent(SDC.name, EVENT_CRAFT_FAILED)
    ZO_EnchantingTopLevelRuneSlotContainer:SetHidden(false)
    ZO_AlchemyTopLevelSlotContainer:SetHidden(false)
    ZO_ProvisionerTopLevelFilletPanelSlotContainer:SetHidden(false)
    ZO_SmithingTopLevelRefinementPanelSlotContainer:SetHidden(false)
    SDC.Announce(true)
    return
  end
  if newstate ~= SCENE_SHOWN then return end
  
  local CurrentCraft = GetCraftingInteractionType() --current station
  SDC.QuestCheck(CurrentCraft) --Find the quest of current station
  SDC.CraftList["Stop"] = false --Reset
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_CRAFT_FAILED, SDC.CraftFail) 
  
  if SDC.CraftList[1] ~= nil then
    SDC.Announce(false)
    if CurrentCraft == 3 then
    --To fix the bug of animation wrong sometime
      ZO_EnchantingTopLevelRuneSlotContainer:SetHidden(true)
      EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, SDC.CraftEnchant)
      SDC.CraftEnchant(true)
      return
    end
    if CurrentCraft == 4 then
    --To fix the bug of animation wrong sometime
      ZO_AlchemyTopLevelSlotContainer:SetHidden(true)
      EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, SDC.CraftAlchemy)
      SDC.CraftAlchemy(true) 
      return
    end
    if CurrentCraft == 5 then 
    --To fix the bug of animation wrong sometime
      ZO_ProvisionerTopLevelFilletPanelSlotContainer:SetHidden(true)
      EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_CRAFT_COMPLETED, function() zo_callLater(function() SDC.CraftCook() end, 100) end)
      SDC.CraftCook(true)
      return
    end
    --To fix the bug of smith craft animation wrong sometime
    ZO_SmithingTopLevelRefinementPanelSlotContainer:SetHidden(true) 
    EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_CRAFT_COMPLETED, function() zo_callLater(function() SDC.CraftSmith() end, 100) end)
    SDC.CraftSmith(true)
  end
end

--Smith
local UsedMaterial = {}
  --The rest number of material used
local function RestMaterial(LinkTable)
  if UsedMaterial[1] == nil then return end
  local Repeat = {LinkTable[1]}
  local count = 1
  --Deduplication
  for a = 1, #LinkTable do
    for b = 1, count do
      if LinkTable[a] ~= Repeat[b] then count = count + 1 end
    end
    Repeat[count] = LinkTable[a]
  end
  --Count and display
  for i = 1, #Repeat do
    local count1, count2, count3 = GetItemLinkStacks(Repeat[i])
    SDC.DD(1, {Repeat[i], count1 + count2 + count3})
  end
  --Check for basic style
  local Style, NumCount = SDC.MostBasicStyle(0)
  SDC.DD(1.1, {ToLink(SDC.SV.StyleList[Style]), NumCount})
  --Reset
  UsedMaterial = {}
end
  --Smith Core
function SDC.CraftSmith(IsFirst)
  --Remove the info of crafted item in previous round
  if IsFirst ~= true then table.remove(SDC.CraftList, 1) end
  local Table = SDC.CraftList[1]
  if Table == nil then  --The finish state
    RestMaterial(UsedMaterial)
    ZO_SmithingTopLevelRefinementPanelSlotContainer:SetHidden(false)
    if SDC.CraftList["Stop"] or SDC.SV.NotClose then return end --When anything wrong, don't close station
    SCENE_MANAGER:Hide("smithing")
    SCENE_MANAGER:Hide("gamepad_smithing_root")
    return
  end
  NowType = Table["Type"]
  if Table["IsMaster"] then
    -- The improvement progress of master writ
    if HasItemToImproveForWrit(Table["Master"]["Target"], Table["Master"]["Material"], Table["Master"]["Trait"], Table["Master"]["Style"], Table["Master"]["Quality"]) then 
      if SDC.SKillCheck(Table["Type"]) then -- Check the skill of saving material
        SDC.CraftSmith()
        return
      end
      for i = 0, GetBagSize(1) do
        --To find the target item slot
        if DoesItemMatchSmithingMaterialTraitAndStyle(1, i, Table["Master"]["Material"], Table["Master"]["Trait"], Table["Master"]["Style"]) then  
          if GetItemDisplayQuality(1, i) < Table["Master"]["Quality"] then
            --Improve gear
            ImproveSmithingItem(1, i, 8)
            --Repeat until match quest
            if GetItemDisplayQuality(1, i) ~= (Table["Master"]["Quality"] - 1) then table.insert(SDC.CraftList,Table) end 
            return
          end
        end
      end
    else
    --Craft the base gear of master writ
      CraftSmithingItem(unpack(Table["Craft"]))
      table.insert(SDC.CraftList, Table)
      return
    end
  end
  --Craft gears of daily quests
  CraftSmithingItem(unpack(Table["Craft"]))
  table.insert(UsedMaterial, GetSmithingPatternMaterialItemLink(Table["Craft"][1], Table["Craft"][2]))
end

--Enchant
local function FindMaterial(ItemId)
  --Craft bag
  if GetItemId(5, ItemId) ~= 0 then 
    return 5, ItemId
  end
  
  --Bank
  for i = 0, GetBagSize(2) do 
    if GetItemId(2, i) == ItemId then
      return 2, i
    end
  end
  
  --Subscriber bank
  if IsESOPlusSubscriber() then 
    for i = 0, GetBagSize(6) do
      if GetItemId(6, i) == ItemId then
        return 6, i
      end
    end
  end
  
  --Bag
  for i = 0, GetBagSize(1) do 
    if GetItemId(1, i) == ItemId then
      return 1, i
    end
  end
  
  --None
  SDC.CraftList["Stop"] = true
  SDC.DD(3, {ToLink(ItemId)})
  return 0, 0
end
  --Enchant core
function SDC.CraftEnchant(IsFirst, ...)
  --Remove the info of crafted item in previous round
  local NumChange = select(6, ...) or 0
  if NumChange < 0 then return end
  if IsFirst ~= true then table.remove(SDC.CraftList, 1) end
  
  local Table = SDC.CraftList[1]
  if Table == nil then
    ZO_EnchantingTopLevelRuneSlotContainer:SetHidden(false)
    if SDC.CraftList["Stop"] or SDC.SV.NotClose then return end
    SCENE_MANAGER:Hide("enchanting")
    SCENE_MANAGER:Hide("gamepad_enchanting_mode")
    return
  end
  --To avoid use Hakeijo
  if Table["Craft"][2] == 68342 then
    SDC.CraftList["Stop"] = true
    SDC.DD(4, {ToLink(68342)})
    SDC.CraftEnchant()
    return
  end
  
  local pBag, pSlot = FindMaterial(Table["Craft"][1])
  local eBag, eSlot = FindMaterial(Table["Craft"][2])
  local aBag, aSlot = FindMaterial(Table["Craft"][3])
  
  if pBag*eBag*aBag == 0 then
    SDC.CraftEnchant()
    return
  end
  --To fix the bug of sound play wrong sometime
  ENCHANTING.aspectLength, ENCHANTING.essenceLength, ENCHANTING.potencyLength = 1000, 1000, 1000
  CraftEnchantingItem(pBag, pSlot, eBag, eSlot, aBag, aSlot, Table["Craft"][4])
end

--Alchemy
--To count the cost of reagents combo
local function PriceTTC(ComboTest)
  if not IsTTCWork() then return ComboTest end
  
  local Index = {}
  local Total = 0
  for a = 1, #ComboTest do
    Total = 0
    for b = 1, #ComboTest[a] do
      Total = Total + TamrielTradeCentrePrice:GetPriceInfo(ToLink(ComboTest[a][b])).Avg
    end
    --Write the cost in combo
    ComboTest[a]["Cost"] = Total
  end
  --Sort the table by cost
  table.sort(ComboTest, function(a, b)
    return a.Cost < b.Cost
  end)

  return ComboTest
end
--To find the slot id of materials, or missing or banlist
local function FindReagents(ItemId)
  --Is in banlist?
  local AR = {}
  if SDC.CraftList[1]["IsMaster"] == false then
    AR = SDC.SV.DailyRestrict
  else
    AR = SDC.SV.MasterRestrict
  end
  for i = 1, #AR do
    if ItemId == AR[i] then return 0, 0 end
  end
  --Find the slot with largest number item
  local Table = {}
  --Craft Bag
  if GetItemId(5, ItemId) ~= 0 then table.insert(Table, {5, ItemId}) end
   --bank
  for i = 0, GetBagSize(2) do
    if GetItemId(2, i) == ItemId then table.insert(Table, {2, i}) end
  end
  --Subscriber bank
  if IsESOPlusSubscriber() then 
    for i = 0, GetBagSize(6) do
      if GetItemId(6, i) == ItemId then table.insert(Table, {6, i}) end
    end
  end
  --bag
  for i = 0, GetBagSize(1) do 
    if GetItemId(1, i) == ItemId then table.insert(Table, {1, i}) end
  end
  --Missing
  if not Table[1] then return 0, 0 end
  local BagId, SlotId, Max = 0, 0, 0
  for i = 1, #Table do
    local count = select(2, GetItemInfo(Table[i][1], Table[i][2]))
    if count > Max then
      BagId = Table[i][1]
      SlotId = Table[i][2]
      Max = count
    end
  end
  return BagId, SlotId
end
  --Alchemy Core
function SDC.CraftAlchemy(IsFirst, ...)
  --Only Trggle once for slot update
  local NumChange = select(6, ...) or 0
  if NumChange < 0 then return end
  --First in cycle?
  if IsFirst ~= true then table.remove(SDC.CraftList, 1) end
  
  --Finish, and check error
  local Table = SDC.CraftList[1]
  if Table == nil then
    ZO_AlchemyTopLevelSlotContainer:SetHidden(false)
    if SDC.CraftList["Stop"] or SDC.SV.NotClose then return end
    SCENE_MANAGER:Hide("alchemy")
    SCENE_MANAGER:Hide("gamepad_alchemy_mode")
    return
  end
  
  --Get combo info from data table
  local TotalCombo = {}
  if Table["IsMaster"] then
    if SDC.SKillCheck(4.1) or SDC.SKillCheck(4.2) or SDC.SKillCheck(4.3) then --Skill check
      SDC.CraftAlchemy()
      return
    end
    TotalCombo = SDC.Master2Craft[Table["Craft"][2]]  -- Get all possible combos of 3 Reagents by encode
  else
    -- U51: resolve the recipe against the current game API.
    -- The solvent comes from the writ itself, so a potion can never be
    -- substituted with a poison that happens to share an old reagent table entry.
    TotalCombo = SDC.GetCurrentDailyAlchemyCombos(Table["Craft"][1], Table["Craft"][2])
    if #TotalCombo == 0 then
      -- Never guess an Alchemy recipe. Stop rather than craft a wrong potion/poison.
      SDC.CraftList["Stop"] = true
      SDC.DD(3, {ToLink(Table["Craft"][2])})
      SDC.CraftAlchemy()
      return
    end
  end
  
  --Resort combo with cost by TTC
  TotalCombo = PriceTTC(TotalCombo) 

  --The final info used for crafting
  local FinalCombo = {} 
  for i = 1, 9 do FinalCombo[i] = 0 end --New
  
  --Solvents check
  FinalCombo[1], FinalCombo[2] = FindReagents(Table["Craft"][1])
  if FinalCombo[1] == 0 then  --No solvent
    SDC.CraftList["Stop"] = true
    SDC.DD(3, {ToLink(Table["Craft"][1])})
    SDC.CraftAlchemy()
    return
  end
  
  --Solvents price
  local SCost = 0
  if IsTTCWork() then 
    SCost = TamrielTradeCentrePrice:GetPriceInfo(GetItemLink(FinalCombo[1], FinalCombo[2])).Avg
  end
  
  --Craft num check for master writ
  if Table["Craft"][1] < 70000 and Table["IsMaster"] then
    FinalCombo[9] = 4
  else
    FinalCombo[9] = 1
  end
  
  --Find material info
  local Cost = 0
  for a = 1, #TotalCombo do
    local fBag, fSlot = FindReagents(TotalCombo[a][1])
    local sBag, sSlot = FindReagents(TotalCombo[a][2])
    local tBag, tSlot = FindReagents(TotalCombo[a][3])
    if TotalCombo[a][3] == nil then
      if (fBag*sBag) ~= 0 then
        FinalCombo[3], FinalCombo[4], FinalCombo[5], FinalCombo[6], FinalCombo[7], FinalCombo[8] = fBag, fSlot, sBag, sSlot, nil, nil
        Cost = TotalCombo[a]["Cost"]
        break
      end
    else
      if (fBag*sBag*tBag) ~= 0 then
        FinalCombo[3], FinalCombo[4], FinalCombo[5], FinalCombo[6], FinalCombo[7], FinalCombo[8] = fBag, fSlot, sBag, sSlot, tBag, tSlot
        Cost = TotalCombo[a]["Cost"]
        break
      end
    end
  end
  
  --No combo can use? Reason and suggested cheapest combo
  if FinalCombo[3] == 0 or FinalCombo[5] == 0 or FinalCombo[7] == 0 then
    SDC.CraftList["Stop"] = true
    local Report = {["Cost"] = TotalCombo[1]["Cost"]}
    for i = 1, 3 do
      if TotalCombo[1][i] ~= nil then
        local Cause = ""
        if FindReagents(TotalCombo[1][i]) == 0 then Cause = GetString(SI_CRAFTING_MISSING_ITEMS) end --Missing
        if IsInTable(TotalCombo[1][i], SDC.SV.DailyRestrict) then Cause = GetString(SI_GUILD_RECRUITMENT_CATEGORY_BLACKLIST) end --Banlist, overwrite
        if IsInTable(TotalCombo[1][i], SDC.SV.MasterRestrict) then Cause = GetString(SI_GUILD_RECRUITMENT_CATEGORY_BLACKLIST) end --Banlist, overwrite
        table.insert(Report, {ToLink(TotalCombo[1][i]), Cause})
      end
    end
    SDC.DD(5, Report)
    --Next item to craft
    SDC.CraftAlchemy()
    return
  end
  --Craft and display cost
  --/script CraftAlchemyItem(5,64501,5,77587,5,77590,nil,nil,10) --肉蝇+夜茄
  CraftAlchemyItem(unpack(FinalCombo))
  if Cost ~= 0 and Cost ~= nil then
    SDC.DD(6, {Cost + SCost})
  end
end

--Cook
function SDC.CraftCook(IsFirst)
  if IsFirst ~= true then table.remove(SDC.CraftList, 1) end
  local Table = SDC.CraftList[1]
  if Table == nil then
    ZO_ProvisionerTopLevelFilletPanelSlotContainer:SetHidden(false)
    if SDC.CraftList["Stop"] or SDC.SV.NotClose then return end
    SCENE_MANAGER:Hide("provisioner")
    SCENE_MANAGER:Hide("gamepad_provisioner_root")
    return
  end
  --Check Recipe
  local IsKnown = GetRecipeInfo(unpack(Table["Craft"])) 
  if IsKnown == false then
    SDC.CraftFail(_, 100)
    SDC.CraftCook()
    return
  end
  --Check skill for master writ, and count craft num
  if Table["IsMaster"] then
    if SDC.SKillCheck(5.1) then
      SDC.CraftCook()
      return
    end
    if SDC.SKillCheck(5.2) then
      SDC.CraftCook()
      return
    end
    Table["Craft"][3] = Table["Craft"][3] / 4
    CraftProvisionerItem(unpack(Table["Craft"]))
  else
    CraftProvisionerItem(unpack(Table["Craft"]))
  end
end

--Treat info with EVENT_CRAFT_FAILED
function SDC.CraftFail(Alert, Warning)
  SDC.CraftList["Stop"] = true
  if not SDC.CraftList[1] then return end --Not trigger by SDC
  if SDC.CraftList[1]["IsMaster"] == true then
    for i = 2, #SDC.CraftList do
      if SDC.CraftList[i]["Craft"] == SDC.CraftList[1]["Craft"] then
        table.remove(SDC.CraftList, i)
      end
    end
  end
  SDC.DD(7, {Warning})
end

--Materila saving skill id
local SkillTable = {
  --Skill and Max Level
  [1] = {48166  , 3}, --Black
  [2] = {48196  , 3}, --Cloth
  [6] = {48175  , 3}, --Wood
  [7] = {103646 , 3}, --Jewlery
  
  [4.1] = {45577, 3}, --Alchemy
  [4.2] = {45555, 0}, --Alchemy
  [4.3] = {45542, 8}, --Alchemy
  
  [5.1] = {44616, 3}, --Cook
  [5.2] = {44620, 3}, --Cook
}

--For master writ check, saving materials
function SDC.SKillCheck(Job)
  local AbilityId = SkillTable[Job][1]
  local Require = SkillTable[Job][2]
  local Type, Line, Index = GetSpecificSkillAbilityKeysByAbilityId(AbilityId)
  if select(8, GetSkillAbilityInfo(Type, Line, Index)) ~= Require or not IsSkillAbilityPurchased(Type, Line, Index) then
    SDC.CraftList["Stop"] = true
    local Name = select(1, GetSkillAbilityInfo(Type, Line, Index))
    SDC.DD(2, {"|H1:ability:"..AbilityId.."|h|h"})
    return true
  end
  return false
end