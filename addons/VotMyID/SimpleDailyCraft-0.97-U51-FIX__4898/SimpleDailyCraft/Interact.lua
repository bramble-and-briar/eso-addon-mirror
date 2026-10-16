local SDC = SimpleDailyCraft
---------------------
----Tool function----
---------------------

--To record position
function SDC.ScanP()
  local id, x, _, z = GetUnitWorldPosition("player")
  d(id)
  StartChatInput(x..", "..z)
end

local function InRange(x, z, Table)
  if Table == nil then return false end
  for i = 1, #Table do
    if x > Table[i][1] and x < Table[i][3] and z > Table[i][2] and z < Table[i][4] then 
      return true 
    end
  end
  return false
end

local function IsMasterWrit(Name)
  for i = 1, #SDC.WritId do
    local TargetName = GetItemLinkName(SDC.WritId[i]):gsub("%^.+", "")
    if Name:lower() == TargetName:lower() then
      return true 
    end
  end
  return false
end

--To cancel annouce of quest
function SDC.Announce(Display)
  if SDC.SV.DD_Announce then return end
  if not CENTER_SCREEN_ANNOUNCE.suppressAnnouncements then
    CENTER_SCREEN_ANNOUNCE.suppressAnnouncements = {}
  end
  if Display then
    CENTER_SCREEN_ANNOUNCE.suppressAnnouncements[CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_ADDED] = 0
    CENTER_SCREEN_ANNOUNCE.suppressAnnouncements[CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_PROGRESSION_CHANGED] = 0
    CENTER_SCREEN_ANNOUNCE.suppressAnnouncements[CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_CONDITION_COMPLETED] = 0
    CENTER_SCREEN_ANNOUNCE.suppressAnnouncements[CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_COMPLETED] = 0
  else
    CENTER_SCREEN_ANNOUNCE.suppressAnnouncements[CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_ADDED] = 1
    CENTER_SCREEN_ANNOUNCE.suppressAnnouncements[CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_PROGRESSION_CHANGED] = 1
    CENTER_SCREEN_ANNOUNCE.suppressAnnouncements[CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_CONDITION_COMPLETED] = 1
    CENTER_SCREEN_ANNOUNCE.suppressAnnouncements[CENTER_SCREEN_ANNOUNCE_TYPE_QUEST_COMPLETED] = 1
  end
end
------------------
----Quest Part----
------------------
SDC.AbandonList = {}
local OldInterFun1 = INTERACTION.UpdateChatterOptions
local OldInterFun2 = GAMEPAD_INTERACTION.UpdateChatterOptions

--Treat info with Callback "SceneStateChanged"
function SDC.InteractCore(scene, _, newstate)
  if scene.name ~= "interact" then return end

  --When leave interact window
  if newstate == SCENE_HIDING then  
    SDC.InteractEnd()
    for i = 1, #SDC.AbandonList do  --Abondon quest should not pick up
      AbandonQuest(SDC.AbandonList[i])
    end
    return
  end
  
  --When open interact window
  if newstate ~= SCENE_SHOWN then return end

  -- Accept Master writ quests
  if IsMasterWrit(GetUnitName("interact"):gsub("%^.+", ""):lower()) then 
    SDC.Announce(false)
    AcceptOfferedQuest() 
    return
  end

  --Get position of player, and info of interact target 
  local Map, x, _, z = GetUnitWorldPosition("player")
  local unitLevel = GetUnitLevel("interact")
  local unitCaption = GetUnitCaption("interact")
  local unitGender = GetUnitGender("interact")

  --Should work?
  local Pase = false
  if SDC.SV.QuestAuto then
    --Daily accept/finish region
    if InRange(x, z, SDC.DailyPostion[Map]) then
      if unitLevel == 0 then
        Pase = true
      end
    end
    --Finish master writs region
    if InRange(x, z, SDC.MasterPostion[Map]) then
      if unitLevel == 50 and unitCaption ~= nil and unitGender == 2 then
        if not IsInteractingWithMyAssistant() then
          --Record name
          SDC.MasterNpcName = GetUnitName("interact"):gsub("%^.+", "") 
          Pase = true
        end
      end
    end
  end
  --Solstice region
  if SDC.SV.SolsticeAuto then
    if InRange(x, z, SDC.SolsticePosition[Map]) then
      if unitLevel == 50 and unitCaption ~= nil and unitGender == 2 then
        if not IsInteractingWithMyAssistant() then
          Pase = true
        end
      end
    end
  end
  --Should work?
  if not Pase then return end

  --EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_CHATTER_BEGIN, SDC.InteractDelay)
  INTERACTION.UpdateChatterOptions = function(...)  --To ensure SDC click after eso finishing updating chatter
      local Result = OldInterFun1(...)
      SDC.InteractDelay()
      return Result
    end
  GAMEPAD_INTERACTION.UpdateChatterOptions = function(...)
      local Result = OldInterFun2(...)
      SDC.InteractDelay()
      return Result
    end
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_QUEST_OFFERED, SDC.InteractEvent)
  EVENT_MANAGER:RegisterForEvent(SDC.name, EVENT_QUEST_COMPLETE_DIALOG, SDC.InteractEvent)
  SDC.Announce(false)
  SDC.InteractChatter()
  return
end

--Delay after chatter begin
function SDC.InteractDelay()
  local Type
  if SCENE_MANAGER:IsShowing("interact") then
    Type = ZO_ChatterOption1.optionType
  else
    if not SCENE_MANAGER:IsShowing("gamepadInteract") then return end
    Type = GAMEPAD_INTERACTION.itemList.dataList[1].optionType
  end
  --Chatter to get, Chatter to finish, Chatter to shop, Chatter to exit
  if Type ~= CHATTER_GENERIC_ACCEPT and Type ~= CHATTER_COMPLETE_QUEST then 
    zo_callLater(SDC.InteractChatter, SDC.SV.QuestDelay) --Make a delay based on player setting
  end
end

local forceExit = false
--To get/finish quest
function SDC.InteractEvent(_, Index)
  if Index then
    zo_callLater(CompleteQuest, 50)
  else
    zo_callLater(function()
      --Special for Solstice daily quest
      if SDC.SV.SolsticeRapid then
        local Map, x, _, z = GetUnitWorldPosition("player")
        if InRange(x, z, SDC.SolsticePosition[Map]) then
          forceExit = true
          EVENT_MANAGER:RegisterForUpdate("SDCSolsticeRapid", 100, SDC.SolsticeRapidAbandon)
        end
      end
      AcceptOfferedQuest()
    end, 50)
  end
end

--Repeat choosing the top chatter, until leave or is shop
function SDC.InteractChatter()
  local Type --The type of option 1
  if forceExit then
    INTERACTION:CloseChatter()
    GAMEPAD_INTERACTION:CloseChatter()
    forceExit = false
    return
  end
  if SCENE_MANAGER:IsShowing("interact") then
    --PC Part
    local control = WINDOW_MANAGER:GetControlByName("ZO_ChatterOption1")
    Type = control.optionType
    if Type == 600 then
      SDC.InteractEnd()
      if WritWorthy and not SDC.RunList[1] then
        INTERACTION:PopulateChatterOption(3, SDC.WritCycle, 
          "|t25:25:esoui/art/icons/master_writ_alchemy.dds|t WritWorthy -> SDC -> "..GetString(SI_BINDING_NAME_AUTORUN), 600)
        INTERACTION:FinalizeChatterOptions(3)
      end
      --Have clear all master quests can commit
      SDC.IsCommit = false 
      --When in ww cycle, quit it
      if SDC.RunList[1] or SDC.LastRound then --In WW-SDC work state
        INTERACTION:CloseChatter()
      end
      return
    end
    if Type == 10000 or Type == 100 then --Done with craft board / Solstice daily npc
      INTERACTION:CloseChatter()  --Close window
    else
      SelectChatterOption(1)  --Click option 1
    end
    --PC Part
  else 
    --Gamepad Part
    if not SCENE_MANAGER:IsShowing("gamepadInteract") then return end
    Type = GAMEPAD_INTERACTION.itemList.dataList[1].optionType
    if Type == 600 then
      SDC.InteractEnd()
      if WritWorthy and not SDC.RunList[1] then
        local entry = GAMEPAD_INTERACTION:GetChatterOptionData(
          SDC.WritCycle, 
          "|t25:25:esoui/art/icons/master_writ_alchemy.dds|t WritWorthy -> SDC -> "..GetString(SI_BINDING_NAME_AUTORUN),
          600, 0, false, false, 0
        )
        GAMEPAD_INTERACTION.itemList:AddEntry("ZO_ChatterOption_Gamepad", entry)
        GAMEPAD_INTERACTION:FinalizeChatterOptions(3)
      end
      SDC.IsCommit = false
      --In WW-SDC work state
      if SDC.RunList[1] or SDC.LastRound then 
        GAMEPAD_INTERACTION:CloseChatter()
      end
      return
    end
    --Done with craft board / Solstice daily npc
    if Type == 10000 or Type == 100 then 
      --Close window
      GAMEPAD_INTERACTION:CloseChatter()  
    else
      --Click option 1
      SelectChatterOption(1)  
    end
    --Gamepad Part
  end
end

--Unregister Event
function SDC.InteractEnd()
  --EVENT_MANAGER:UnregisterForEvent(SDC.name, EVENT_CHATTER_BEGIN)
  INTERACTION.UpdateChatterOptions = OldInterFun1
  GAMEPAD_INTERACTION.UpdateChatterOptions = OldInterFun2
  EVENT_MANAGER:UnregisterForEvent(SDC.name, EVENT_QUEST_OFFERED)
  EVENT_MANAGER:UnregisterForEvent(SDC.name, EVENT_QUEST_COMPLETE_DIALOG)
  SDC.Announce(true)
end

--Rapid Abandon Solstice Quest by interrupt
function SDC.SolsticeRapidAbandon()
  --Setting Check
  if not SDC.SV.SolsticeRapid then
    EVENT_MANAGER:UnregisterForUpdate("SDCSolsticeRapid")
    return
  end
  --Position Check
  local Map, x, _, z = GetUnitWorldPosition("player")
  if not InRange(x, z, SDC.SolsticePosition[Map]) then
    EVENT_MANAGER:UnregisterForUpdate("SDCSolsticeRapid")
    return
  end
  --Blocking Check
  if IsBlockActive() then
    SDC.TF.AbandonSolsticeQuest()
    EVENT_MANAGER:UnregisterForUpdate("SDCSolsticeRapid")
  end
end

--------------------
----Box opening-----
--------------------

--Treat info from EVENT_LOOT_RECEIVED
function SDC.OpenBox(_, BagId, SlotId, IsNew, _, _, NumChange)
  --Check what update
  if BagId ~= 1 or NumChange < 1 then return end
  --Check Setting
  if not SDC.SV.OpenBox then return end
  --Check target
  if not SDC.BoxNameDict[GetItemName(BagId, SlotId):gsub("%^.+", ""):lower()] then return end
  EVENT_MANAGER:RegisterForUpdate("SDCWait", 50, SDC.OpenWait)
end

--When get/open target box, check this. If DailyQuest and DailyRegion, dalay unbox
function SDC.OpenWait()
  local Map, x, _, z = GetUnitWorldPosition("player")
  if SDC.HaveDaily and InRange(x, z, SDC.DailyPostion[Map]) then return end
  EVENT_MANAGER:UnregisterForUpdate("SDCWait")
  EVENT_MANAGER:RegisterForUpdate("SDCRepeating", 240, SDC.RepeatOpen)
end

local LastCheck = 0
--Open box
function SDC.RepeatOpen()
  EVENT_MANAGER:UnregisterForUpdate("SDCWait")
  if not SDC.SV.OpenBox then
    EVENT_MANAGER:UnregisterForUpdate("SDCRepeating") --Stop repeat
    return 
  end
  for i = 0, GetBagSize(1) do
    local ItemName = GetItemName(1, i):gsub("%^.+", ""):lower() or 0
    if SDC.BoxNameDict[ItemName] then
      --Have item to open
      LastCheck = 0
      EVENT_MANAGER:RegisterForUpdate("SDCRepeating", 240, SDC.RepeatOpen)
      EVENT_MANAGER:UnregisterForUpdate("SDCLastCheck")
      --Inventory check
      if GetNumBagFreeSlots(1) < 5 then 
        EVENT_MANAGER:UnregisterForUpdate("SDCRepeating") --Stop repeat
        SDC.DD(8, {})
        SDC.DD(0)
        return
      end
      --Cool down check
      local remain = GetItemCooldownInfo(1, i) --Total 1000ms cool down for box opening
      if remain == 0 then 
        CallSecureProtected("UseItem", 1, i) --Open
      end
      return
    end
  end
  EVENT_MANAGER:UnregisterForUpdate("SDCRepeating") --Stop repeat
  EVENT_MANAGER:RegisterForUpdate("SDCLastCheck", 500, SDC.RepeatOpen)
  LastCheck = LastCheck + 1
  if LastCheck == 3 then
    EVENT_MANAGER:UnregisterForUpdate("SDCLastCheck")
    LastCheck = 0
    SDC.DD(19)
  end
end

--Get loot from box
function SDC.LootAll(scene, _, newstate)
  if not SDC.SV.OpenBox then return end --Check set
  if newstate ~= SCENE_SHOWING then return end --Check state
  local control
  if scene.name == "loot" then 
    control = WINDOW_MANAGER:GetControlByName("ZO_LootTitle")
  end
  if scene.name == "lootGamepad" then
    control = WINDOW_MANAGER:GetControlByName("ZO_Gamepad_LootPickupContentHeaderContainerHeaderTitleContainerTitle")
  end
  if not control then return end

  if SDC.BoxNameDict[control:GetText():lower()] then
    LootAll()
    SCENE_MANAGER:Hide("loot")
    SCENE_MANAGER:Hide("inventory")
    --Gamepad part
    ZO_GamepadTooltipTopLevelRightTooltip:SetParent(ZO_Gamepad_LootPickup)    --Let it hide with loot window
    ZO_GamepadTooltipTopLevelRightTooltipBg:SetParent(ZO_Gamepad_LootPickup)  --Let it hide with loot window
    SCENE_MANAGER:Hide("lootGamepad")
    SCENE_MANAGER:Hide("gamepad_inventory_root")
    --Trigger unbox cycle
    EVENT_MANAGER:RegisterForUpdate("SDCWait", 50, SDC.OpenWait)
  end
  return
end

-----------------------
----Research Helper----
-----------------------

local Point = {}
local DISTANCE = 12500
function SDC.ResearchHelper(_, BagId, SlotId, IsNew, _, _, NumChange)
  if not SDC.SV.DD_Research then return end
  --Check change and state
  if BagId ~= 1 or NumChange ~= -1 or not IsPlayerInteractingWithObject() or GetUnitLevel("interact") == 50 then return end
  --Check item type
  local Type1, Type2 = GetItemType(BagId, SlotId)
  if Type1 ~= 5 and Type2 ~= 101 then return end
  --Record start
  local Map, x, _, z = GetUnitWorldPosition("player")
  Point = {
    {x, z},
    ["Map"] = Map,
    ["Name"] = GetUnitName("interact"),
  }
  EVENT_MANAGER:RegisterForUpdate("SDCResearch", 100, SDC.ResearchUpdate)
end
--Distance
function SDC.ResearchUpdate()
  local Map, x, _, z = GetUnitWorldPosition("player")
  --Check map
  if Map ~= Point["Map"] then
    Point = {}
    EVENT_MANAGER:UnregisterForUpdate("SDCResearch")
  end
  --Check new pick
  if GetUnitName("interact") == Point["Name"] or GetUnitLevel("interact") == 6 then
    local IsNew = true
    for i = 1, #Point do
      if {x, z} == Point[i] then
        IsNew = false
      end
    end
    if IsNew then table.insert(Point, {x, z}) end
  end
  --Count average position
  local Ax, Az = 0, 0
  for i = 1, #Point do
    Ax = Ax + Point[i][1]
    Az = Az + Point[i][2]
  end
  Ax = Ax / #Point
  Az = Az / #Point
  --Distant count
  local distance = math.sqrt(math.pow((x-Ax),2)+math.pow((z-Az),2))
  if distance > DISTANCE then
    SDC.DD(20)
    PlaySound("Enchanting_PotencyRune_Removed")
    Point = {}
    EVENT_MANAGER:UnregisterForUpdate("SDCResearch")
  end
  return
end