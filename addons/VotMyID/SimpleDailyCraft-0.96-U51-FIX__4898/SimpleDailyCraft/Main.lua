local SDC = SimpleDailyCraft

--Dault setting
SDC.Default = {
  --Account/Character Setting
  CV = false,
  --Writs Bar Setting
  Window_Show = true,
  Window_Point = 128,
  Window_rPoint = 128,
  Window_OffsetX = 0,
  Window_OffsetY = 0,
  --Craft Setting
  NotClose = false,
  DailyCraft = true,
  MasterCraft = true,
  SmithCraft = true,
  CookCraft = true,
  EnchantCraft = true,
  AlchemyCraft = true,
  --Prompt Setting
  DD_SmithMaterialLeft = 200,
  DD_AlchemyCost = true,
  DD_Research = true,
  DD_Bank = false,
  DD_Announce = false,
  --Quest Setting
  QuestAuto = true,
  QuestDelay = 200,
  BQ = true,
  CQ = true,
  WQ = true,
  JQ = true,
  PQ = true,
  EQ = true,
  AQ = true,
  SolsticeAuto = true,
  SolsticeRapid = true,
  --Unbox Setting
  OpenBox = true,
  CustomBoxLinks = {},
  --Bank Setting
  Bank = true,
  OpenBank = false,
  OpenBankAssistant = true,
  CloseBank = true,
  --Restrict for Alchemy Setting
  DailyRestrict = {},
  DailyRawRestrict = {},
  MasterRestrict = {},
  --Style Materials Setting
  StyleList = {},
}

--Tool function
local function ToLink(Id)
  return "|H0:item:"..Id..":30:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"
end

-------------------
----Start point----
-------------------

--when addon loaded
local function OnAddOnLoaded(eventCode, addonName)
  if addonName ~= SDC.name then return end
  EVENT_MANAGER:UnregisterForEvent(SDC.name, EVENT_ADD_ON_LOADED)
  
  --Restore from saved setting
  SDC.SV1 = ZO_SavedVars:NewAccountWide("SDC_SaveVars", 1, nil, SDC.Default, GetWorldName())
  SDC.SV2 = ZO_SavedVars:NewCharacterIdSettings("SDC_SaveVars", 1, nil, SDC.Default, GetWorldName())
  SDC.SwitchSV()

  --Reset keybind if error last
  SDC.CV = ZO_SavedVars:NewCharacterIdSettings("SDC_SaveVars2", 1, nil, {["Key"]={}}, GetWorldName())
  SDC.Key()
  
  --Reset bar window
  SDCTopLevel:ClearAnchors()
  SDCTopLevel:SetAnchor(
    SDC.SV.Window_Point,
    GuiRoot,
    SDC.SV.Window_rPoint,
    SDC.SV.Window_OffsetX,
    SDC.SV.Window_OffsetY
  )

  --Initialization for box name
  SDC.BoxNameDict = SDC.TF.ItemLinksToNameDicts(SDC.BoxLinks, SDC.SV.CustomBoxLinks)
  
  --Register Event
    --Assistant bar info Update
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_PLAYER_ACTIVATED, SDC.QuestUpdate)
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_QUEST_ADDED, SDC.QuestUpdate)
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_QUEST_REMOVED, SDC.QuestUpdate)
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_QUEST_LIST_UPDATED, SDC.QuestUpdate)
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_QUEST_CONDITION_COUNTER_CHANGED, SDC.QuestUpdate)
  
    --Start unboxing after get target containers
  EVENT_MANAGER:RegisterForEvent("SDCOpenDect", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, SDC.OpenBox)
  EVENT_MANAGER:RegisterForEvent("SDCResearch", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, SDC.ResearchHelper)
  
  --Event Used in other position, for avioid repeat 
  --[[
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, Craft Consumable)
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_CRAFT_COMPLETED, Craft Smith)
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_CRAFT_FAILED, Craft fail)
  EVENT_MANAGER:RegisterForEvent("SDCBank", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, SDC.BankProcess)
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_QUEST_OFFERED, SDC.InteractEvent)
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_QUEST_COMPLETE_DIALOG, SDC.InteractEvent)
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_COMBAT_EVENT, SDC.SolsticeRapidAbandon)
  --]]
  
  --Register Callback
  SCENE_MANAGER:RegisterCallback("SceneStateChanged", SDC.CraftCore)    --Start craft work
  SCENE_MANAGER:RegisterCallback("SceneStateChanged", SDC.InteractCore) --Start writ/unbox work
  SCENE_MANAGER:RegisterCallback("SceneStateChanged", SDC.LootAll)      --Loot all in box
  SCENE_MANAGER:RegisterCallback("SceneStateChanged", SDC.BankCore)     --Get target from bank
  
  --Callback Used in other position
  --SCENE_MANAGER:RegisterCallback("SceneStateChanged", SDC.WWCore)

  --LAM
  SDC.BuildMenu()
  
  --Gamepad
  SDC.GamepadMode()
end

--Setting
function SDC.SwitchSV()
  --Account/Character Switch
  if SDC.SV2.CV then
    SDC.SV = SDC.SV2
  else
    SDC.SV = SDC.SV1
  end

  --The first time dauf setting
  if SDC.SV.DailyRestrict[1] == nil then SDC.SV.DailyRestrict = {30152, 30164, 139019, 150731, 150671} end
  if SDC.SV.DailyRawRestrict[1] == nil then SDC.SV.DailyRawRestrict = {"%/"} end
  if SDC.SV.MasterRestrict[1] == nil then SDC.SV.MasterRestrict = {150731, 150671} end
  for key, value in pairs(SDC.SV.StyleList) do
    if value ~= nil then return end
  end
  SDC.SV.StyleList = {unpack(SDC.BasicSytle)}
  SDC.SV.StyleList[34] = 33254
end

-------------------------
----Craft Info Handle----
-------------------------

--Find which style to use
function SDC.MostBasicStyle(Need)
  Need = Need or 0
  local count = -1
  local style = 0
  
  --Find the one with the most material in the available styles
  for StyleIndex, ItemId in pairs(SDC.SV.StyleList) do
    --Known Sytle
    if ItemId ~= nil and IsSmithingStyleKnown(StyleIndex, 1) then 
      local stack = GetCurrentSmithingStyleItemCount(StyleIndex)
      --the largest number
      if stack > count then 
        style = StyleIndex
        count = stack
      end
    end
  end
  
  --Not Enough
  if count < Need then
    return 0, 0
  end
  
  --Enough
  return style, count
end

--Gears Craft
function SDC.HandleSmith(IsMaster, journalQuestIndex, conditionIndex)
  local CraftType = 0
  local ItemId, ItemTemplateId = 0, 0
  local PatternIndex, PatternCost = 0, 0
  local MaterialId, MaterialIndex = 0, 0
  local SetId, SetIndex = 0, 0
  local TraitType, TraitIndex = 0, 0
  local StyleId = 0
  local Quality = 1
  
  --Already Finished?
  local MissedItemNumber = SDC.TF.MissedWritItemNumber(journalQuestIndex, conditionIndex)
    --Finished
  if MissedItemNumber == 0 then return end
  
  --Is master writ？
  if IsMaster then 
  --Master Writs
    --Master Stations?
    if ZO_Smithing_IsConsolidatedStationCraftingMode() == false then return end
    
    --Info of Target Item
    ItemId, MaterialId, CraftType, Quality, ItemTemplateId, SetId, TraitType, StyleId = GetQuestConditionMasterWritInfo(journalQuestIndex, 1, conditionIndex)
    SetIndex = CONSOLIDATED_SMITHING_SET_DATA_MANAGER.setDataBySetId[SetId].setIndex
    
    --Set Locked
    if not IsConsolidatedSmithingSetIndexUnlocked(SetIndex) then
      SDC.DD(10.5, {GetItemSetName(SetId)})
      return
    end
    
    --Switch Active Set
    SetActiveConsolidatedSmithingSetByIndex(SetIndex)
    
    --Other Info Required for Production
    PatternIndex, MaterialIndex, ItemId = GetSmithingPatternInfoForItemSet(ItemTemplateId, SetId, MaterialId, TraitType)
    TraitIndex = TraitType + 1
  else
  --Daily Writs
    ItemId, MaterialId, CraftType = GetQuestConditionItemInfo(journalQuestIndex, 1, conditionIndex)
    PatternIndex, MaterialIndex = GetSmithingPatternInfoForItemId(ItemId, MaterialId, CraftType)
    StyleId = SDC.MostBasicStyle(MissedItemNumber)
    TraitIndex = 1
  end
  
  --No style can use when not jewerly
  if StyleId == 0 and CraftType ~= SDC.C.CRAFT_TYPE_JEWLERY then 
    SDC.DD(10, {})
    return 
  end
  
  --Raw Materials Needed for this kind of Gear
  PatternCost = select(3, GetSmithingPatternMaterialItemInfo(PatternIndex, MaterialIndex))
  
  --Packaging Production Information
  table.insert(SDC.CraftList, 
    {
      ["Type"] = CraftType,
      ["IsMaster"] = IsMaster,
      ["Master"] = {
        ["Target"]    = ItemId,
        ["Material"]  = MaterialId,
        ["SetIndex"]  = SetIndex,
        ["Trait"]     = TraitType,
        ["Style"]     = StyleId,
        ["Quality"]   = Quality,
      },
      ["Craft"] = {PatternIndex, MaterialIndex, PatternCost, StyleId, TraitIndex, SDC.C.NonUniversalStyle, MissedItemNumber},
    }
  )
end

--Alchemy
function SDC.HandleAlchemy(IsMaster, journalQuestIndex, conditionIndex)
  local _
  local CraftType = 0
  local SolventId, SolventIndex, ItemId = 0, 0, 0
  
  --Already Finished?
  local MissedItemNumber = SDC.TF.MissedWritItemNumber(journalQuestIndex, conditionIndex)
    --Finished
  if MissedItemNumber == 0 then return end
  
  --Is master writ？
  if IsMaster then
  --Master Writ
    _, SolventIndex, CraftType, _,_,_,_,_, ItemId = GetQuestConditionMasterWritInfo(journalQuestIndex, 1, conditionIndex)
  else
  --Daily Writ
    ItemId, SolventIndex, CraftType = GetQuestConditionItemInfo(journalQuestIndex, 1, conditionIndex)
  end
  
  --Which Solvent?
  SolventId = SDC.Alchemy["Level"][SolventIndex]

  --Packaging Production Information
  table.insert(SDC.CraftList,
    {
      ["Type"] = CraftType,
      ["IsMaster"] = IsMaster,
      ["Craft"] = {SolventId, ItemId, MissedItemNumber},
    }
  )
end

--Enchat
function SDC.HandleEnchant(IsMaster, journalQuestIndex, conditionIndex)
  local CraftType = 0
  local ItemId, MeterialIndex, Quality = 0, 0, 1
  local RunePotency, RuneEssence, RuneAspect = 0, 0, 0
  
  --Already Finished?
  local MissedItemNumber = SDC.TF.MissedWritItemNumber(journalQuestIndex, conditionIndex)
    --Finished
  if MissedItemNumber == 0 then return end
  
  --Is master writ？
  if IsMaster then
  --Master Writ
    ItemId, MeterialIndex, CraftType, Quality = GetQuestConditionMasterWritInfo(journalQuestIndex, 1, conditionIndex)
  else
  --Daily Writ
    ItemId, MeterialIndex, CraftType, Quality = GetQuestConditionItemInfo(journalQuestIndex, 1, conditionIndex)
  end
  
  --To Rune ItemId
  RuneEssence = SDC.Enchant["Id"][ItemId][2]
  RunePotency = SDC.Enchant["Level"][MeterialIndex][SDC.Enchant["Id"][ItemId][1]]
  RuneAspect  = SDC.Enchant["Quilty"][Quality]
  
  --Packaging Production Information
  table.insert(SDC.CraftList,
    {
      ["Type"] = CraftType,
      ["IsMaster"] = IsMaster,
      ["Craft"] = {RunePotency, RuneEssence, RuneAspect, MissedItemNumber},
    }
  )
end

--Cook
local Recipes = {} --All Recipes info
function SDC.HandleCook(IsMaster, journalQuestIndex, conditionIndex)
  --Get recipe info when first run
  if Recipes[33526] == nil then 
    for x = 1, 40 do
      for y = 1, 1000 do
        local TargetId = select(8, GetRecipeInfo(x, y))
        if TargetId == 0 then
          break
        else
          Recipes[TargetId] = {x, y}
        end
      end
    end
  end
  
  local _
  local CraftType = 0
  local ItemId, RecipeListIndex, RecipeIndex = 0, 0, 0
  
  --Already Finished?
  local MissedItemNumber = SDC.TF.MissedWritItemNumber(journalQuestIndex, conditionIndex)
    --Finished
  if MissedItemNumber == 0 then return end
  
  --Is master writ？
  if IsMaster then
  --Master Writs
    ItemId, _, CraftType = GetQuestConditionMasterWritInfo(journalQuestIndex, 1, conditionIndex)
  else
  --Daily Writs
    ItemId, _, CraftType = GetQuestConditionItemInfo(journalQuestIndex, 1, conditionIndex)
  end
  
  --To Recipe Info
  if not Recipes[ItemId] then return end
  RecipeListIndex, RecipeIndex = unpack(Recipes[ItemId])
  
  table.insert(SDC.CraftList,
    {
      ["Type"] = CraftType,
      ["IsMaster"] = IsMaster,
      ["Craft"] = {RecipeListIndex, RecipeIndex, MissedItemNumber},
    }
  )
end

--Which function to handle craft info
local function HandleFunction(CraftType, IsMaster, journalQuestIndex, conditionIndex)
  if not SDC.SV.DailyCraft and not IsMaster then return end     --Ban daily craft
  if not SDC.SV.MasterCraft and IsMaster then return end        --Ban master craft
  
  if CraftType == SDC.C.CRAFT_TYPE_ENCHANT and not SDC.SV.EnchantCraft then return end --Ban Enchant craft
  if CraftType == SDC.C.CRAFT_TYPE_ALCHEMY and not SDC.SV.AlchemyCraft then return end --Ban Alchemy craft
  if CraftType == SDC.C.CRAFT_TYPE_COOK    and not SDC.SV.CookCraft then return end    --Ban Cook craft
  
  if CraftType == SDC.C.CRAFT_TYPE_ENCHANT then SDC.HandleEnchant(IsMaster, journalQuestIndex, conditionIndex) return end
  if CraftType == SDC.C.CRAFT_TYPE_ALCHEMY then SDC.HandleAlchemy(IsMaster, journalQuestIndex, conditionIndex) return end
  if CraftType == SDC.C.CRAFT_TYPE_COOK    then SDC.HandleCook   (IsMaster, journalQuestIndex, conditionIndex) return end
  
  --Ban Smith craft
  if not SDC.SV.SmithCraft then return end      SDC.HandleSmith  (IsMaster, journalQuestIndex, conditionIndex)
end

--To find the craft writ for current station
function SDC.QuestCheck(CurrentType)
  --Reset the List for Crafting
  SDC.CraftList = {}
  
  --Look up all journal quests
  for journalQuestIndex = 1, SDC.C.MAX_NUMBER_QUEST do
    local QuestType = select(10, GetJournalQuestInfo(journalQuestIndex))
    
    --Craft Quests
    if QuestType == SDC.C.QUEST_TYPE_WRIT or QuestType == SDC.C.QUEST_TYPE_HOLIDAY then
      --Master Writs
      if GetQuestConditionMasterWritInfo(journalQuestIndex, 1, 1) then
        local _,_, CraftType = GetQuestConditionMasterWritInfo(journalQuestIndex, 1, 1)
        --Should be Handled in this Station?
        if CraftType == CurrentType then
          HandleFunction(CraftType, true, journalQuestIndex, 1) 
        end
      
      else
      --Daily Writs
        for conditionIndex = 1, SDC.C.MAX_NUMBER_CONDITION_INDEX do
          local ItemId, MaterialId, CraftType = GetQuestConditionItemInfo(journalQuestIndex, 1, conditionIndex)
          --Patch for Some Materials
          if CraftType == 0 then CraftType = GetItemLinkCraftingSkillType(SDC.TF.ToLink(ItemId)) end
          if ItemId ~= 0 and CraftType == CurrentType and (not SDC.TF.IsRawMaterial(ItemId)) then
            HandleFunction(CraftType, false, journalQuestIndex, conditionIndex)
          end
        end
      end
    end
  end
end

-----------------------------------------------
----Bar Display & Bank target & Writ status----
-----------------------------------------------

local Icon = {
  [1] = "|t40:40:esoui/art/inventory/inventory_tabicon_craftbag_blacksmithing_up.dds:inheritColor|t",   --BlackSmith
  [2] = "|t40:40:esoui/art/inventory/inventory_tabicon_craftbag_clothing_up.dds:inheritColor|t",        --Cloth
  [3] = "|t40:40:esoui/art/inventory/inventory_tabicon_craftbag_enchanting_up.dds:inheritColor|t",      --Enchat
  [4] = "|t40:40:esoui/art/inventory/inventory_tabicon_craftbag_alchemy_up.dds:inheritColor|t",         --Alchmy
  [5] = "|t40:40:esoui/art/inventory/inventory_tabicon_craftbag_provisioning_up.dds:inheritColor|t",    --Cook
  [6] = "|t40:40:esoui/art/inventory/inventory_tabicon_craftbag_woodworking_up.dds:inheritColor|t",     --Wood
  [7] = "|t40:40:esoui/art/tutorial/tutorial_idexicon_jewelry_up.dds:inheritColor|t",                   --Jewelry
}

function SDC.QuestUpdate()
  --Reset
  SDC.AbandonList = {} --Reset the quest should be abondoned
  SDC.BankTarget = {} --Reset the item list should be taken from bank
  SDC.BankTargetType = {} --Reset the item type should be taken from bank
  SDC.HaveDaily = false
  SDC.UndoneMaster = false
  
  --EachCraftType: HaveCraftQuest? DoneDaily? DoneMaster?
  local List = {}
  local HaveQuest, DoneDaily, DoneMaster = 1, 2, 3
  for i = 1, SDC.C.CRAFT_TYPE_NUMBER do 
    List[i] = {false, true, true} 
  end
  
  --Start analyze
  for journalQuestIndex = 1, SDC.C.MAX_NUMBER_QUEST do
    local QuestType = select(10, GetJournalQuestInfo(journalQuestIndex))
    
    if QuestType == SDC.C.QUEST_TYPE_WRIT or QuestType == SDC.C.QUEST_TYPE_HOLIDAY then
    --Craft quests
      if GetQuestConditionMasterWritInfo(journalQuestIndex, 1, 1) then 
      --Master Writs
        local _,_, CraftType = GetQuestConditionMasterWritInfo(journalQuestIndex, 1, 1)
        --Have Writs
        List[CraftType][HaveQuest] = true

        --Undone Master ?
        if SDC.TF.MissedWritItemNumber(journalQuestIndex, 1) > 0 then 
          List[CraftType][DoneMaster] = false
          SDC.UndoneMaster = true
        end
      
      else
      --Daily Writs
        for conditionIndex = 1, SDC.C.MAX_NUMBER_CONDITION_INDEX do 
          local ItemId, MaterialId, CraftType = GetQuestConditionItemInfo(journalQuestIndex, 1, conditionIndex)
          --Patch for Some Materials
          if CraftType == 0 then CraftType = GetItemLinkCraftingSkillType(SDC.TF.ToLink(ItemId)) end
          
          --Craft Info
          if ItemId ~= 0 and CraftType ~= 0 then
            
            --Check Banned Quests
            if not SDC.SV.BQ and CraftType == 1 then table.insert(SDC.AbandonList, journalQuestIndex) end
            if not SDC.SV.CQ and CraftType == 2 then table.insert(SDC.AbandonList, journalQuestIndex) end
            if not SDC.SV.WQ and CraftType == 6 then table.insert(SDC.AbandonList, journalQuestIndex) end
            if not SDC.SV.JQ and CraftType == 7 then table.insert(SDC.AbandonList, journalQuestIndex) end
            if not SDC.SV.PQ and CraftType == 5 then table.insert(SDC.AbandonList, journalQuestIndex) end
            if not SDC.SV.EQ and CraftType == 3 then table.insert(SDC.AbandonList, journalQuestIndex) end
            if not SDC.SV.AQ and CraftType == 4 then table.insert(SDC.AbandonList, journalQuestIndex) end
            
            --Check Banned Alchemy Materials
            for i = 1, #SDC.SV.DailyRawRestrict do
              if ItemId == SDC.SV.DailyRawRestrict[i] then
                SDC.DD(11, {ToLink(ItemId)})
                table.insert(SDC.AbandonList, journalQuestIndex)
              end
            end
            
            --Have Writs
            List[CraftType][HaveQuest] = true
            SDC.HaveDaily = true
            
            --Undone Daily ?
            local MissedItemNumber = SDC.TF.MissedWritItemNumber(journalQuestIndex, conditionIndex)
            if MissedItemNumber > 0 then 
              List[CraftType][DoneDaily] = false
              
              --For comsuable type bank work
              if (CraftType == SDC.C.CRAFT_TYPE_ENCHANT or CraftType == SDC.C.CRAFT_TYPE_ALCHEMY or CraftType == SDC.C.CRAFT_TYPE_COOK) then 
                table.insert(SDC.BankTarget, {ItemId, MissedItemNumber, journalQuestIndex, conditionIndex}) --Try get from bank later
                SDC.BankTargetType[CraftType] = true
              end
            end
          end
        end
      end
    end
  end
  
  --Bank Operating
  if SDC.Banking then SDC.BankProcess() end
  
  --Bar Display
  local Display = " "
  local Order = { --Resort the display order
    SDC.C.CRAFT_TYPE_BLACKSMITH,
    SDC.C.CRAFT_TYPE_WOOD,
    SDC.C.CRAFT_TYPE_CLOTH,
    SDC.C.CRAFT_TYPE_JEWLERY,
    SDC.C.CRAFT_TYPE_COOK,
    SDC.C.CRAFT_TYPE_ENCHANT,
    SDC.C.CRAFT_TYPE_ALCHEMY,
  } 
  local ShouldH = true
  --Check each craft type
  for i = 1, SDC.C.CRAFT_TYPE_NUMBER do 
    if List[Order[i]][HaveQuest] == false then --No quest
      Display = Display.."|c778899"..Icon[Order[i]].."|r"
    else
      ShouldH = false
      --Finish
      if List[Order[i]][DoneDaily] == true and List[Order[i]][DoneMaster] == true then 
        Display = Display.."|c32CD32"..Icon[Order[i]].."|r" 
      end
      
      --Only master left undone
      if List[Order[i]][DoneDaily] == true and List[Order[i]][DoneMaster] == false then 
        Display = Display.."|c8A2BE2"..Icon[Order[i]].."|r" 
      end
      
      --Only daily left undone
      if List[Order[i]][DoneDaily] == false and List[Order[i]][DoneMaster] == true then 
        Display = Display.."|cF0E68C"..Icon[Order[i]].."|r" 
      end
      
      --Both undone
      if List[Order[i]][DoneDaily] == false and List[Order[i]][DoneMaster] == false then 
        Display = Display.."|cDC143C"..Icon[Order[i]].."|r" 
      end
    end
  end
  
  --Set Info to Display
  SDCTopLevel_Label:SetText(Display)
  
  --Should Hide Bar?
  if not SDC.SV.Window_Show then
    SDCTopLevel:SetHidden(true)
    return
  end
  SDCTopLevel:SetHidden(ShouldH)
end

--When window move, record its new position in SV
function SDC.WindowPosition()
  local _
  _, SDC.SV.Window_Point, _, SDC.SV.Window_rPoint, SDC.SV.Window_OffsetX, SDC.SV.Window_OffsetY = SDCTopLevel:GetAnchor()
end

-------------------
----Start Point----
-------------------
EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)