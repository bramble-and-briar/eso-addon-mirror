
--[[

  GLOBAL FUNCTIONS

]]--
VEQ = VEQ or {}

VEQ.MuseumPieces = VEQ.MuseumPieces or {}
VEQ.MuseumPieces.Thieves = {73785, 73786, 73787, 73772, 73773, 73774, 73775, 73776, 73777, 73778, 73779, 73780, 73781, 73782, 73783, 73784}
VEQ.MuseumPieces.Artaeum = {133605, 133606, 133607, 133608, 133609, 133610, 133611, 133612, 133613, 133614, 133615, 133616, 133617, 133618, 133619, 133620, 133621, 133622, 133623, 133624}


-- General Buffer made by Wykkyd : http://wiki.esoui.com/Event_%26_Update_Buffering

-- *********************************************************************************************
-- * General Functions                                                                         *
-- *********************************************************************************************

local BufferTable = {}
local function BufferReached(key, buffer)
if key == nil then return end
  if BufferTable[key] == nil then BufferTable[key] = {} end
  BufferTable[key].buffer = buffer or 3
  BufferTable[key].now = GetFrameTimeSeconds()
  if BufferTable[key].last == nil then BufferTable[key].last = BufferTable[key].now end
  BufferTable[key].diff = BufferTable[key].now - BufferTable[key].last
  BufferTable[key].eval = BufferTable[key].diff >= BufferTable[key].buffer
  if BufferTable[key].eval then BufferTable[key].last = BufferTable[key].now end
  return BufferTable[key].eval
end

-- Convert a colour from "|cABCDEFG" form to [0,1] RGB form.
function VEQ.ConvertHexToRGBA(colourString)
  local r=tonumber(string.sub(colourString, 3, 4), 16) or 255
  local g=tonumber(string.sub(colourString, 5, 6), 16) or 255
  local b=tonumber(string.sub(colourString, 7, 8), 16) or 255
  local a=tonumber(string.sub(colourString, 9, 10), 16) or 255
  return r/255, g/255, b/255, 1
end

-- Convert decimal number to Hex Equivalend (255 = FF)
function VEQ.ConvertDecimalToHex(i)
  if i == nil then return "00" end
  local deci = i*255
  local str = string.format("%x",deci)
  if deci < 16 then str = string.format("0%s", str) end
  return str
end
-- Apply colors to a string
function VEQ.ApplyStringColorRGB(text, r,g,b)
  local hexstring = string.format("%s%s%s", VEQ.ConvertDecimalToHex(r), VEQ.ConvertDecimalToHex(g), VEQ.ConvertDecimalToHex(b))
  local coloredString = string.format("|c%s%s|r", hexstring, text)
 -- d(hexstring)
  return coloredString
end

-- Print to Chat function, grabs as many argument pairs sent text, color, applies the color to the text with ApplyStringColorRGB, applies them to a string with same number of argument pairs (if you send two pairs then template needs <<x>> for both).
function VEQ.PrintToChat(template, ...)
    local arg = {...}

    local textStrings = {}
    for _,x in pairs(arg) do
       table.insert(textStrings, ApplyChatColor(x.text, x.color))
    end
    local msg = zo_strformat(template, unpack(textStrings))
    --if(TI.GetShowTimestamp()) then
    --    chatString = string.format("[%s] %s",GetTimeString(),chatString)
    --end
    CHAT_SYSTEM:AddMessage(msg)
end

-- Standard message
--function VEQ.Msg(header,msg)
--  if VEQ.Chat_AddonMessages == true then
--    if header == nil or msg == nil then
--      VEQ.PrintToChat("

-- *********************************************************************************************
-- * VEQ Specific Functions                                                                  *
-- *********************************************************************************************

function VEQ.CheckMode() -- Check menu /UIs witch are opened

  if VEQ.main then
    local InteractiveMenuIsHidden = ZO_KeybindStripControl:IsHidden()
    local GameMenuIsHidden = ZO_GameMenu_InGame:IsHidden()
    local DialogueIsHidden = ZO_InteractWindow:IsHidden()
    local JournalIsHidden = ZO_QuestJournal:IsHidden()
    local IsControllingSiegeWeapon = IsPlayerControllingSiegeWeapon()
    --local editHUDnotShowing = not HUD_EDITOR_SCENE_KEYBOARD:IsShowing()
    
    -- hides default tracker
    --ZO_FocusedQuestTrackerPanel:SetHidden(true)
    FOCUSED_QUEST_TRACKER:GetFragment():SetHiddenForReason("I'm a liar", true)
    
    -- hides Golden Pursuits tracker
    --ZO_PromotionalEventTracker_TL:SetHidden(true)
    TIMED_ACTIVITY_TRACKER:GetFragment():SetHiddenForReason("I'm a liar", true)
    
    -- hides achievements tracker
    ACHIEVEMENT_TRACKER:GetFragment():SetHiddenForReason("I'm a liar", true)
    
    -- hides default activity tracker 
    --ZO_ActivityTracker:SetHidden(true)
    ACTIVITY_TRACKER:GetFragment():SetHiddenForReason("I'm a liar", true)
    
    -- hides default zonestory tracker
    ZONE_STORY_TRACKER:GetFragment():SetHiddenForReason("I'm a liar", true)
    
    -- hides ready check tracker 
    --ZO_ReadyCheckTrackerTopLevel:SetHidden(true)
    READY_CHECK_TRACKER:GetFragment():SetHiddenForReason("I'm a liar", true)
    
    --hides group lifebars
    if VEQ.SavedVars.hideDefaultGroupFrames then 
        ZO_UnitFramesGroups:SetHidden(true) 
    else 
        ZO_UnitFramesGroups:SetHidden(false)
    end



        -- check craft store
    if CS then
      local CSRune_isHidden = true
      local CSCook_isHidden = true
      --d("CraftStore loaded.")
      CSRune_isHidden = CraftStoreFixed_Rune:IsHidden()
      CSCook_isHidden = CraftStoreFixed_Cook:IsHidden()
      
      if CSRune_isHidden == false or CSCook_isHidden == false then
        -- test cs is still working
        VEQ.main:SetHidden(true) 
      else
        if InteractiveMenuIsHidden == true and GameMenuIsHidden == true and DialogueIsHidden == true then
          VEQ.main:SetHidden(false)
          if IsUnitInCombat('player') and VEQ.SavedVars.HideInCombatOption then VEQ.main:SetHidden(true) else VEQ.main:SetHidden(false) end
        elseif InteractiveMenuIsHidden == false or GameMenuIsHidden == false or DialogueIsHidden == false then
        
          VEQ.main:SetHidden(true)
        end
      end
    else
    
      if HUD_SCENE:IsShowing() then --InteractiveMenuIsHidden == true and GameMenuIsHidden == true and DialogueIsHidden == true and editHUDnotShowing == true then
        VEQ.main:SetHidden(false)
        if IsUnitInCombat('player') and VEQ.SavedVars.HideInCombatOption then VEQ.main:SetHidden(true) else VEQ.main:SetHidden(false) end
      elseif (InteractiveMenuIsHidden == false or GameMenuIsHidden == false or DialogueIsHidden == false) and not IsControllingSiegeWeapon then
        VEQ.main:SetHidden(true)
      end
      
      if GetCurrentBattlegroundState() == BATTLEGROUND_STATE_FINISHED or GetCurrentBattlegroundState() == BATTLEGROUND_STATE_POSTROUND then
          VEQ.main:SetHidden(true) 
        if VEQ.MiniQuestList[19] then 
           VEQ.delayedCheckBattlegroundRewardTimer()
        end
      end 
    end
    
    

    --turns off quest list display in tribute game
     if TRIBUTE_SCENE:IsShowing() then  
        if VEQ.bg then VEQ.bg:SetHidden(true) end
        if VEQ.bgtx then VEQ.bgtx:SetHidden(true) end
        VEQ.isInTributeGame = true
     elseif VEQ.isInTributeGame == true then
       if VEQ.bg then VEQ.bg:SetHidden(false) end
       if VEQ.bgtx then VEQ.bgtx:SetHidden(false) end
       VEQ.isInTributeGame = false
     end 
  end
  
end


function VEQ.CombatState()

  if not IsPlayerActivated() then return end
  
  if not VEQ.SavedVars.Poison then
     if VEQ.MiniQuestList then
         if VEQ.MiniQuestList[14] then VEQ.MiniQuestList[14] = nil end
         -- update table length
        VEQ.updateTableLength(VEQ.MiniQuestList)
     -- update miniquests displayed  
        VEQ.DisplayFocusedMiniQuest()  
     end
     return
  end
  
  local level = GetUnitLevel("player")

  
  if IsUnitInCombat("player") then
    return
  else
    -- check if poison slots are equipped after combat
          local _, stack, _, _, _, _, _, _ = GetItemInfo(BAG_WORN, EQUIP_SLOT_POISON)
        local _, backStack, _, _, _, _, _, _ = GetItemInfo(BAG_WORN, EQUIP_SLOT_BACKUP_POISON)
      
      if stack and stack ~= 0 then
          if backStack and backStack ~= 0 then
             if VEQ.MiniQuestList[14] then VEQ.MiniQuestList[14] = nil end
             -- update table length
                   if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
               -- update miniquests displayed  
                   VEQ.DisplayFocusedMiniQuest()
             return
        elseif level >= 15 then
                       if not VEQ.MiniQuestList[14] then
                VEQ.LoadMiniQuestsInfo(14, 14,VEQ.mylanguage.lang_out_of_poison, VEQ.mylanguage.lang_craft_some_poison, VEQ.mylanguage.lang_alchemy_station, "esoui/art/tradinghouse/gamepad/gp_tradinghouse_materials_potions_poisonsolvent.dds")
                    VEQ.DisplayFocusedMiniQuest() 
             end  
        end
      else
             if not VEQ.MiniQuestList[14] then
                      VEQ.LoadMiniQuestsInfo(14, 14,VEQ.mylanguage.lang_out_of_poison, VEQ.mylanguage.lang_craft_some_poison, VEQ.mylanguage.lang_alchemy_station, "esoui/art/tradinghouse/gamepad/gp_tradinghouse_materials_potions_poisonsolvent.dds")
                VEQ.DisplayFocusedMiniQuest()
                   end           
      end
    
  end
  
end





function VEQ.FindMyZone(dzone, dtype, dInstanceDisplayType, dRepeatType, qname, qZoneIndex)
  
  local parentZone = ""
  if qZoneIndex and type(qZoneIndex) == "number" then  
     parentZone = string.format(" - %s", VEQ.KillTheRubbish(GetZoneNameById(GetParentZoneId(GetZoneId(qZoneIndex)))))
  end
  
  local zone = dzone
  local pzone = string.format(" - %s", zone)
    
    local prepeat = "" 
    if dRepeatType == QUEST_REPEAT_DAILY then
         prepeat = string.format(" %s", GetString(SI_QUESTREPEATABLETYPE2))
    elseif dRepeatType == QUEST_REPEAT_WEEKLY then
         prepeat = string.format(" %s", GetString(SI_QUESTREPEATABLETYPE5))
        elseif dRepeatType == QUEST_REPEAT_MONTHLY then 
         prepeat =string.format(" %s", GetString(SI_QUESTREPEATABLETYPE6))
    elseif dRepeatType == QUEST_REPEAT_REPEATABLE then
         prepeat = string.format(" %s", VEQ.mylanguage.lang_tracker_type_repeatable)
    else
         prepeat = ""
    end
    
    if dtype == QUEST_TYPE_AVA or dtype == QUEST_TYPE_AVA_GRAND or dtype == QUEST_TYPE_AVA_GROUP then
         zone = string.format("%s%s", VEQ.mylanguage.lang_tracker_type_ava, pzone)
    elseif dtype == QUEST_TYPE_GUILD then
         zone = string.format("%s%s%s", VEQ.mylanguage.lang_tracker_type_guild, prepeat, pzone)
         if VEQ.GetQuestLine(qname) then
           zone = string.format("%s%s%s", VEQ.GetQuestLine(qname), prepeat, pzone)
         end
    elseif dtype == QUEST_TYPE_MAIN_STORY then
          zone = string.format("%s%s", VEQ.mylanguage.lang_tracker_type_mainstory, pzone)
    elseif dtype == QUEST_TYPE_CLASS then
          zone = string.format("%s%s%s", VEQ.mylanguage.lang_tracker_type_class, prepeat, pzone)
    elseif dtype == QUEST_TYPE_UNDAUNTED_PLEDGE then
          zone = string.format("%s%s%s", VEQ.mylanguage.lang_tracker_type_undaunted, prepeat, pzone)
    elseif dtype == QUEST_TYPE_COMPANION then
          zone = string.format("%s%s%s", VEQ.mylanguage.lang_tracker_type_companion, prepeat, pzone)
    elseif dtype == QUEST_TYPE_PROLOGUE then
          zone = string.format("%s%s%s", VEQ.mylanguage.lang_tracker_type_prologue, prepeat, pzone)
    elseif dtype == QUEST_TYPE_CRAFTING then
          zone = string.format("%s%s",  VEQ.mylanguage.lang_tracker_type_craft, pzone)
    elseif dtype == QUEST_TYPE_GROUP  then
          zone = string.format("%s%s%s", VEQ.mylanguage.lang_tracker_type_group, prepeat, pzone)
    elseif dtype == QUEST_TYPE_DUNGEON then
         if dInstanceDisplayType == ZONE_DISPLAY_TYPE_SOLO  then 
             zone = string.format("%s %s%s", VEQ.mylanguage.lang_tracker_type_solo, VEQ.mylanguage.lang_tracker_type_arena, pzone)
         elseif dInstanceDisplayType == ZONE_DISPLAY_TYPE_SOLO_DUNGEON  then 
             zone = string.format("%s %s%s", VEQ.mylanguage.lang_tracker_type_solo, VEQ.mylanguage.lang_tracker_type_dungeon, pzone)
         elseif VEQ.GetQuestLine(qname) == VEQ.mylanguage.lang_tracker_type_arena then
             zone = string.format("%s %s%s", VEQ.mylanguage.lang_tracker_type_group, VEQ.mylanguage.lang_tracker_type_arena, pzone)
         else
             zone = string.format("%s %s%s", VEQ.mylanguage.lang_tracker_type_group, VEQ.mylanguage.lang_tracker_type_dungeon, pzone)
         end
    elseif dtype == QUEST_TYPE_RAID then
          zone = string.format("%s %s%s%s", VEQ.mylanguage.lang_tracker_type_group, VEQ.mylanguage.lang_tracker_type_raid, pzone, parentZone)
    elseif dtype == QUEST_TYPE_BATTLEGROUND then
          zone = string.format("%s%s", VEQ.mylanguage.lang_tracker_type_bg, pzone)
    elseif dtype == QUEST_TYPE_HOLIDAY_EVENT then
          zone = string.format("%s%s", VEQ.mylanguage.lang_tracker_type_holiday_event, pzone)
    elseif dtype == QUEST_TYPE_QA_TEST then
          zone = string.format("%s%s", VEQ.mylanguage.lang_tracker_type_qa_test, pzone)
    elseif dtype == QUEST_TYPE_TRIBUTE then
          zone = string.format("%s%s", GetString(SI_LEADERBOARDTYPE5), pzone)
    elseif dtype == QUEST_TYPE_SCRIBING then
          zone = string.format("%s%s", GetString(SI_NOTIFICATIONTYPE20), pzone)
    elseif dtype == QUEST_TYPE_TAMRIEL_TALE then
          zone = string.format("%s%s", GetString(SI_QUESTTYPE20), pzone)
    elseif dtype == QUEST_TYPE_FAVOR then
          zone = string.format("%s%s", GetString(SI_QUESTTYPE19), pzone)
    elseif dtype == QUEST_TYPE_NONE then
      if dInstanceDisplayType == ZONE_DISPLAY_TYPE_RAID  then 
          zone = string.format("%s %s%s%s", VEQ.mylanguage.lang_tracker_type_group, VEQ.mylanguage.lang_tracker_type_raid, pzone, parentZone)
      else 
           if prepeat == "" then
         else zone = string.format("%s%s", prepeat, pzone)
         end
      end
    end
  if dzone == "" and zone == "" then zone = VEQ.mylanguage.lang_Miscellaneous end
  return zone
end

function VEQ.FocusedQuestInfo()
  -- find the current focused quest
  for i=1,MAX_JOURNAL_QUESTS do
    local valQindex = GetTrackedIsAssisted(TRACK_TYPE_QUEST,i,0)
    if valQindex == true then
      local fname, fbackgroundText, factiveStepText, factiveStepType, factiveStepTrackerOverrideText, fcompleted, ftracked, fqlevel, fpushed, fqtype = GetJournalQuestInfo(i)
      local fzone, fobjective, fzoneidx, fpoiIndex = GetJournalQuestLocationInfo(i)
      VEQ.FocusedQIndex = i
      VEQ.FocusedZone = fzone
      VEQ.FocusedQName = fname
      VEQ.FocusedZoneIdx = fzoneidx
      VEQ.FocusedZonePoiIndx = fpoiIndex
      VEQ.FocusedQType = fqtype
      VEQ.FocusedMyZone = VEQ.FindMyZone(fzone,fqtype)
      break;
    end
  end
end


function VEQ.CheckFocusedQuest() 
  -- Check Focused Quest (check if an ESO element modified the current focused quest)
  local RecordedFocusedQuest = GetTrackedIsAssisted(TRACK_TYPE_QUEST,VEQ.currenticon,0)
  if RecordedFocusedQuest == false then
    for j=1, MAX_JOURNAL_QUESTS do
      if IsValidQuestIndex(j) then
        local CurrentFocusedQuest = GetTrackedIsAssisted(TRACK_TYPE_QUEST,j,0)
        if CurrentFocusedQuest == true then
          if j ~= VEQ.currenticon then
            VEQ.currenticon = j
            VEQ.QuestsListUpdate(1) 
          end
        end
      end
    end
  end
  
end

function VEQ.SetFocusedQuest(qindex)
  -- if the game setting to auto track quest is off then we don't do it
  if not GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_AUTOMATIC_QUEST_TRACKING) then return end
  -- Update the focused quest if quest is added or updated
  local check = 0
  if qindex ~= nil then
    for i=1,MAX_JOURNAL_QUESTS do
      local valQindex = GetTrackedIsAssisted(TRACK_TYPE_QUEST,i,0)
      if valQindex == true then
        if i == qindex then
          check = 1
        --***100022 REmove for 100023 START
        else
          SetTrackedIsAssisted(TRACK_TYPE_QUEST,false,i,0)
        --***100022 REmove for 100023 END
        end
        break
      end
    end
    if check == 0 then
      --***100023 - For 10023 START
      FOCUSED_QUEST_TRACKER:ForceAssist(qindex)
      FOCUSED_QUEST_TRACKER:InitialTrackingUpdate()
      VEQ.currenticon = qindex
      VEQ.FocusedQuestInfo()
      --d(string.format("Focused %s", VEQ.FocusedQName))
      -- Check to see if Bandit UI is loaded, if so skip update.
      local noUpdate = false
      if BUI then noUpdate = true end
      if noUpdate == false then
        ZO_WorldMap_UpdateMap()
      end
    end
    -- Refresh Quests
    --if VEQ.QuestsHideZoneOption == true then
    --  VEQ.AutoFilterZone()
    --else
      --emptyLine,totalMiniQuestmarker,areaMiniQuestmarker,titleMiniQuestmarker,objMiniQuestmarker = nil
        
      VEQ.QuestsListUpdate(1)
    --end
  end
end



function VEQ.ForcedFocusedQuest(qindex)
  -- Do a forced update to quest indicated.
  -- a 0 indicates to do a focusedquestinfo and force update what should be focused quest.
  local check = 0
  if qindex ~= nil then
    if qindex == 0 then
      VEQ.FocusedQuestInfo()
      qindex = VEQ.FocusedQIndex
    end
    
    FOCUSED_QUEST_TRACKER:ForceAssist(qindex)
    FOCUSED_QUEST_TRACKER:InitialTrackingUpdate()
    VEQ.currenticon = qindex
    VEQ.FocusedQuestInfo()
    local noUpdate = false
    if BUI then noUpdate = true end
    if noUpdate == false then
      ZO_WorldMap_UpdateMap()
    end
    -- Refresh Quests
    --if VEQ.QuestsHideZoneOption == true then
    --  VEQ.AutoFilterZone()
    --else
    --  VEQ.QuestsListUpdate(1)
    --end
    
  end
end



function VEQ.CheckQuestsToHidden(qindex, qname, qtype, qzoneidx, valcheck)
  local QuestTracked = GetIsTracked(1,qindex,0)
  --[[if VEQ.SavedVars.QuestsUntrackHiddenOption == true then
    --if((VEQ.SavedVars.QuestsZoneGuildOption == false and qtype == 3) or (VEQ.SavedVars.QuestsZoneMainOption == false and qtype == 2) or (VEQ.SavedVars.QuestsZoneCyrodiilOption == false and qzoneidx == VEQ.CyrodiilNumZoneIndex)) then
        -- Untrack Hidden Quests
        if QuestTracked == true then
          valcheck = 1
          SetTracked(1,false,qindex,0)
        end
    else
      if QuestTracked == false then
        valcheck = 1
        SetTracked(1,true,qindex,0)
      end     
    end
  else]]
    -- Track all others
    if QuestTracked == false then
      valcheck = 1
      SetTracked(1,true,qindex,0)
    end
  --end
  return valcheck
end




-- Quest to chat, need to improve output
function VEQ.QuestToChat(i)
  local qname, backgroundText, activeStepText, activeStepType, activeStepTrackerOverrideText, completed, tracked, qlevel, pushed, qtype = GetJournalQuestInfo(i)
  
  d(string.format("Selected Quest: %s", qname))
  d(string.format("Background: %s", backgroundText))
  d(string.format("Active Step: %s", activeStepText))
end

-- *********************************************************************************
-- * FilterZone Functions                                                          *
-- *********************************************************************************

-- Updates the quest/zone filter
function VEQ.UpdateFilterZone(qzone)
  VEQ.FocusedQuestInfo()
  if not VEQ.filterzone then VEQ.filterzone = {} end
  local tmpfilterzone = {}
  local tmp = 0
  if VEQ.filterzone[1] then
    local i=1
    while VEQ.filterzone[i] do
      --if VEQ.filterzone[i] == qzone or VEQ.FocusedMyZone == qzone then
      if VEQ.filterzone[i] == qzone then
        tmp = 1
      else
        table.insert(tmpfilterzone, VEQ.filterzone[i])
      end
      i = i+1
    end
    --if tmp ~= 1 and VEQ.FocusedMyZone ~= qzone then
    if tmp ~= 1 then
      table.insert(tmpfilterzone, qzone)
    end
  else
    --if VEQ.FocusedMyZone ~= qzone then 
      table.insert(tmpfilterzone, qzone)
    --end
  end
  VEQ.filterzone = tmpfilterzone
  VEQ.SavedVars.QuestsFilter = tmpfilterzone
  --if VEQ.FocusedMyZone == qzone then d("VEQ Message: Cannot filter/collapse zone with focused quest.") end
end

-- FilterZone Clean - Removing the fucused zone from list
function VEQ.CleanFilterZone()
  VEQ.FocusedQuestInfo()
  if not VEQ.filterzone then VEQ.filterzone = {} end
  if VEQ.filterzone[1] then
    local tmpfilterzone = {}
    local tmp = 0
    local i=1
    while VEQ.filterzone[i] do
      if VEQ.filterzone[i] == VEQ.FocusedMyZone then
        tmp = 1
      else
        table.insert(tmpfilterzone, VEQ.filterzone[i])
      end
      i = i+1
    end
    VEQ.filterzone = tmpfilterzone
    VEQ.SavedVars.QuestsFilter = tmpfilterzone
  end
end

-- function to remove filterzone, clear it compeltely output
function VEQ.RemoveFilterZone()
  VEQ.filterzone = {}
  --d(VEQ.filterzone[1])
  VEQ.SavedVars.QuestsFilter = VEQ.filterzone
  VEQ.QuestsListUpdate(1)
end

-- Filterzone Auto - Adds all zones excelpt filtered
function VEQ.AutoFilterZone()
  -- Grab Focused Quest Information, will skip zone for focused Qeust
  VEQ.FocusedQuestInfo()
  -- Set vars, clearing filter zone
  VEQ.filterzone = {}
  local tmpfilterzone = {}
  local i = 1
  local myzone = ""
  local x=1
  local done = 0
  local tmp = 0
  -- Run through quests in Journal, need quest type, zone to get myzone
  -- quest loop for x
  for x=1, MAX_JOURNAL_QUESTS do
    if IsValidQuestIndex(x) then
      -- gather quest info need qzone and qtype
      local qname, backgroundText, activeStepText, activeStepType, activeStepTrackerOverrideText, completed, tracked, qlevel, pushed, qtype = GetJournalQuestInfo(x)
      local qzone, qobjective, qzoneidx, poiIndex = GetJournalQuestLocationInfo(x)
      -- find my zone
      myzone = VEQ.FindMyZone(qzone,qtype)
      -- Set Vars for loop
      i = 1
      tmp = 0
      -- loop through filterzone{} first check to see if first record is there
      if VEQ.filterzone[i] then
        -- if first record exists, then loops through filterzone{}
        while VEQ.filterzone[i] do
          -- checks if myzone is in filterzone{} or is focusedzone if so set tmp =1
          if VEQ.filterzone[i] == myzone or myzone == VEQ.FocusedMyZone then
            tmp = 1
          end
          -- While loop increment
          i = i+1
        end
        -- if tmp still 0 then add to table tmpfilterzone{}
        if tmp ~= 1 then
          table.insert(tmpfilterzone, myzone)
        end
      else
        -- if first record does not exist, then check to see if it focused and if not add it
        if VEQ.FocusedMyZone ~= myzone then
          table.insert(tmpfilterzone, myzone)
        end
      end
    -- quest loop for x end/loop
    end
  -- End for x loop
  -- save tmpfilterzone{} to filerzone{} and SavedVars
    VEQ.filterzone = tmpfilterzone
    VEQ.SavedVars.QuestsFilter = tmpfilterzone
  end
  -- save tmpfilterzone{} to filerzone{} and SavedVars MOved up to where it was....was working then....

  -- if filterzone{} is not empty then do a questlistupdate to update the tracker
  if VEQ.filterzone[1] then
    --d("AutoFilterZone doing QuestUpdate")
    VEQ.QuestsListUpdate(1)
  end
-- end function
end

--Switch Display Mode
function VEQ.SwitchDisplayMode()
  VEQ.SavedVars.QuestsZoneOption = not VEQ.SavedVars.QuestsZoneOption
  VEQ.QuestsListUpdate(1)
end

-- Remove Quest Message Box
function VEQ.CheckRemoveQuestBox(qindex, qname)
  if not VEQ.PlayerRemoveQuestBox then
    local WM = WINDOW_MANAGER
    local LMP = LibMediaProvider
    VEQ.MainRemoveQuestBox = WM:CreateTopLevelWindow(nil)
    VEQ.MainRemoveQuestBox:SetAnchor(CENTER,GuiRoot,CENTER,0,-100)
    VEQ.MainRemoveQuestBox:SetDimensions(200,100)
    VEQ.MainRemoveQuestBox:SetMovable(false)
    VEQ.MainRemoveQuestBox:SetDrawLayer(2)
    
    VEQ.PlayerRemoveQuestBox = WM:CreateControl(nil, VEQ.MainRemoveQuestBox, CT_STATUSBAR)
    VEQ.PlayerRemoveQuestBox:SetAnchorFill()
    VEQ.PlayerRemoveQuestBox:SetDrawLayer(2)
    VEQ.PlayerRemoveQuestBox:SetColor(0,0,0,0.4)
    
    VEQ.PlayerRemoveLabelQuestBox = WM:CreateControl(nil, VEQ.PlayerRemoveQuestBox, CT_LABEL)
    VEQ.PlayerRemoveLabelQuestBox:SetAnchor(CENTER, VEQ.MainRemoveQuestBox, CENTER, 0, -25)
    VEQ.PlayerRemoveLabelQuestBox:SetDrawLayer(3)
    VEQ.PlayerRemoveLabelQuestBox:SetFont(("%s|%s|%s"):format(LMP:Fetch('font', VEQ.SavedVars.QuestsAreaFont), 18, VEQ.SavedVars.QuestsAreaStyle))
    VEQ.PlayerRemoveLabelQuestBox:SetColor(VEQ.SavedVars.QuestsAreaColor.r, VEQ.SavedVars.QuestsAreaColor.g, VEQ.SavedVars.QuestsAreaColor.b, VEQ.SavedVars.QuestsAreaColor.a)
    VEQ.PlayerRemoveLabelQuestBox:SetText("Do you really want to remove this quest ?")
    
    VEQ.PlayerRemoveLabelQuestBox2 = WM:CreateControl(nil, VEQ.PlayerRemoveQuestBox, CT_LABEL)
    VEQ.PlayerRemoveLabelQuestBox2:SetAnchor(CENTER, VEQ.MainRemoveQuestBox, CENTER, 0, 10)
    VEQ.PlayerRemoveLabelQuestBox2:SetDrawLayer(3)
    VEQ.PlayerRemoveLabelQuestBox2:SetFont(("%s|%s|%s"):format(LMP:Fetch('font', VEQ.SavedVars.QuestsAreaFont), 18, VEQ.SavedVars.QuestsAreaStyle))
    VEQ.PlayerRemoveLabelQuestBox2:SetColor(VEQ.SavedVars.QuestsAreaColor.r, VEQ.SavedVars.QuestsAreaColor.g, VEQ.SavedVars.QuestsAreaColor.b, VEQ.SavedVars.QuestsAreaColor.a)

    VEQ.RemoveQuestBoxYes = WM:CreateControl(nil, VEQ.PlayerRemoveQuestBox, CT_LABEL)
    VEQ.RemoveQuestBoxYes:SetAnchor(TOPLEFT, VEQ.MainRemoveQuestBox, BOTTOMLEFT, 10, 0)
    VEQ.RemoveQuestBoxYes:SetDrawLayer(3)
    VEQ.RemoveQuestBoxYes:SetFont(("%s|%s|%s"):format(LMP:Fetch('font', VEQ.SavedVars.QuestsAreaFont), VEQ.SavedVars.QuestsAreaSize, VEQ.SavedVars.QuestsAreaStyle))
    VEQ.RemoveQuestBoxYes:SetText("Yes")
    VEQ.RemoveQuestBoxYes:SetColor(VEQ.SavedVars.QuestsAreaColor.r, VEQ.SavedVars.QuestsAreaColor.g, VEQ.SavedVars.QuestsAreaColor.b, VEQ.SavedVars.QuestsAreaColor.a)
    VEQ.RemoveQuestBoxYes:SetMouseEnabled(true)
    VEQ.RemoveQuestBoxYes:SetHandler("OnMouseEnter", function(self) self:SetColor(1,1,1,1)  end)
    VEQ.RemoveQuestBoxYes:SetHandler("OnMouseExit", function(self) self:SetColor(VEQ.SavedVars.QuestsAreaColor.r, VEQ.SavedVars.QuestsAreaColor.g, VEQ.SavedVars.QuestsAreaColor.b, VEQ.SavedVars.QuestsAreaColor.a) end)
    
    VEQ.RemoveQuestBoxNo = WM:CreateControl(nil, VEQ.PlayerRemoveQuestBox, CT_LABEL)
    VEQ.RemoveQuestBoxNo:SetAnchor(TOPRIGHT, VEQ.MainRemoveQuestBox, BOTTOMRIGHT, -10, 0)
    VEQ.RemoveQuestBoxNo:SetDrawLayer(3)
    VEQ.RemoveQuestBoxNo:SetFont(("%s|%s|%s"):format(LMP:Fetch('font', VEQ.SavedVars.QuestsAreaFont), VEQ.SavedVars.QuestsAreaSize, VEQ.SavedVars.QuestsAreaStyle))
    VEQ.RemoveQuestBoxNo:SetText("No")
    VEQ.RemoveQuestBoxNo:SetColor(VEQ.SavedVars.QuestsAreaColor.r, VEQ.SavedVars.QuestsAreaColor.g, VEQ.SavedVars.QuestsAreaColor.b, VEQ.SavedVars.QuestsAreaColor.a)
    VEQ.RemoveQuestBoxNo:SetMouseEnabled(true)
    VEQ.RemoveQuestBoxNo:SetHandler("OnMouseEnter", function(self) self:SetColor(1,1,1,1) end)
    VEQ.RemoveQuestBoxNo:SetHandler("OnMouseExit", function(self) self:SetColor(VEQ.SavedVars.QuestsAreaColor.r, VEQ.SavedVars.QuestsAreaColor.g, VEQ.SavedVars.QuestsAreaColor.b, VEQ.SavedVars.QuestsAreaColor.a) end)
    VEQ.RemoveQuestBoxNo:SetHandler("OnMouseDown", function(self) VEQ.MainRemoveQuestBox:SetHidden(true) end)
  else
    VEQ.MainRemoveQuestBox:SetHidden(false)
  end
  VEQ.PlayerRemoveLabelQuestBox2:SetText(qname)
  VEQ.RemoveQuestBoxYes:SetHandler("OnMouseDown", function()
      AbandonQuest(qindex)
      d(string.format("%s: %s", VEQ.mylanguage.lang_console_abandon, qname)) 
      VEQ.MainRemoveQuestBox:SetHidden(true)
  end)
  
end


function VEQ.ClearBoxes(clearid)
  local clearidx = clearid
  while VEQ.textbox[clearidx] do
    VEQ.textbox[clearidx]:SetText("")
    VEQ.textbox[clearidx]:SetHandler("OnMouseDown", nil)
    VEQ.textbox[clearidx]:SetMouseEnabled(false)
    VEQ.icon[clearidx]:SetHidden(true)
    clearidx = clearidx + 1
  end
end

function VEQ.ClearQTimer(isVisible)
  VEQ.boxqtimer:SetText("")
  VEQ.boxqtimer:SetHandler("OnMouseDown", nil)
  VEQ.boxqtimer:SetMouseEnabled(false)
  VEQ.boxqtimer:SetHidden(isVisible)
end

--*********************************************************************************
--* Keybinds/Toggles                                                              *
--*********************************************************************************

-- For Toggle tracker is hidden
function VEQ.ToggleHidden()
    VEQ.bg:ToggleHidden()
end

--zone/area enabled
function VEQ.ToggleZones()
  if VEQ.QuestsAreaOption == true then 
    VEQ.QuestsAreaOption = false
    local mesg = "VEQ Message - Not displaying Zone/Category names."
    local r = 10/255
    local g = 255/255
    local b = 150/255
    local a = 255/255
    
    mesg = ApplyStringColorRGBA(mesg,r,g,b)
    
    d(mesg)
  else
    VEQ.QuestsAreaOption =  true
    d("VEQ Message - Displaying Zone/Category names.")
  end
  VEQ.QuestsListUpdate(1)
end

--zone/area hybrid/pure zone
function VEQ.ToggleHybrid()
  if VEQ.QuestsHybridOption == true then 
    VEQ.QuestsHybridOption = false
    d("VEQ Message - View is set to Zone View.")
  else
    VEQ.QuestsHybridOption = true
    d("VEQ Message - View is set to Category View.")
  end
  VEQ.QuestsListUpdate(1)
  -- if VEQ.QuestsHideZoneOption == true then VEQ.AutoFilterZone() else 
  -- VEQ.QuestsListUpdate(1) 
  -- end
  end

--enable auto hide zone
function VEQ.ToggleAutoHideZones()
  if VEQ.QuestsHideZoneOption == true then 
    VEQ.QuestsHideZoneOption = false
    VEQ.RemoveFilterZone()
    local mesg = "VEQ Message - Auto Hide Zones turned off, Zone/Category Filter removed."
    --local r = 10/255
    --local g = 255/255
    --local b = 150/255
    --local a = 255/255
    
    --mesg = ApplyStringColorRGBA(mesg,r,g,b,a)
    
    d(mesg)
  else
    VEQ.QuestsHideZoneOption = true
    d("VEQ Message - Auto Hide Zones turned on.")
    VEQ.AutoFilterZone()
  end
end

-- Toggle Set Hide Object/Hints EXCEPT when focused
function VEQ.SetToggleHideObjExceptFocused(newOpt)
  VEQ.HideObjOption = newOpt
  VEQ.QuestsListUpdate(1)
end

-- --Hide Object/Hints EXCEPT when focused
-- function VEQ.ToggleHideObjExceptFocused()
  -- if VEQ.HideObjOption == "Disabled" then
    -- VEQ.HideObjOption = "Focused Quest"
    -- d("VEQ Message - Toggled Objectives/Hints to show only for Focused Quest")
  -- elseif VEQ.HideObjOption == "Focused Quest" then
    -- VEQ.HideObjOption = "Focused Zone"
    -- d("VEQ Message - Toggled Objectives/Hints to show only for Focused Zone/Category")
  -- elseif VEQ.HideObjOption == "Focused Zone" then
    -- VEQ.HideObjOption = "Disabled"
    -- d("VEQ Message - Toggled Objectives/Hints to show for all quests.")
  -- end
  -- VEQ.QuestsListUpdate(1)
-- end



-- --Enable Transparency for Not Focused Quests
-- function VEQ.ToggleQuestsNoFocusOption()
  -- if VEQ.QuestsNoFocusOption == true then 
    -- VEQ.QuestsNoFocusOption = false
    -- d("VEQ Message - Disabled Transparency for Not Focused Quests.")
  -- else
    -- VEQ.QuestsNoFocusOption = true
    -- d("VEQ Message - Enabled Transparency for Not Focused Quests.")
  -- end
  -- VEQ.QuestsListUpdate(1)
-- end

  --Focused Quest Zone Not Transparent
function VEQ.ToggleFocusedQuestAreaNoTrans()
  if VEQ.FocusedQuestAreaNoTrans == true then 
    VEQ.FocusedQuestAreaNoTrans = false
    d("VEQ Message - Disabled Transparency for Focused Zone.")
  else
    VEQ.FocusedQuestAreaNoTrans = true
    d("VEQ Message - Enabled Transparency for Focused Zone.")
  end
  VEQ.QuestsListUpdate(1)
end

--Hide Optional/Hidden Quest Info/Hints ALL
function VEQ.ToggleHideInfoHintsOption()
  if VEQ.HideInfoHintsOption == true then 
    VEQ.HideInfoHintsOption = false
    d("VEQ Message - Disabled Hints and Hidden information.")
  else
    VEQ.HideInfoHintsOption = true
    d("VEQ Message - Enabled Hints and Hidden information.")
  end
  VEQ.QuestsListUpdate(1)
end

--*********************************************************************************
--* Console/Slash Command                                                         *
--*********************************************************************************

function VEQ.CMD_DEBUG1()
  if VEQ.DEBUG ~= 1 then
    d("VEQ Debug1 : On")
    VEQ.DEBUG = 1
  else
    d("VEQ Debug : Off")
    VEQ.DEBUG = 0
  end
end
function VEQ.CMD_DEBUG2()
  if VEQ.DEBUG ~= 2 then
    d("VEQ Debug2 : On")
    VEQ.DEBUG = 2
  else
    d("VEQ Debug : Off")
    VEQ.DEBUG = 0
  end
end
function VEQ.CMD_DEBUG3()
  if VEQ.DEBUG ~= 3 then
    d("VEQ Debug3 : On")
    VEQ.DEBUG = 3
  else
    d("VEQ Debug : Off")
    VEQ.DEBUG = 0
  end
end
function VEQ.CMD_DEBUG4()
  if VEQ.DEBUG ~= 4 then
    d("VEQ Debug4 : On")
    VEQ.DEBUG = 4
  else
    d("VEQ Debug : Off")
    VEQ.DEBUG = 0
  end
end

-- function VEQ.CMD_Position()
  -- VEQ.SetPositionLockOption (false)
  -- VEQ.main:ClearAnchors()
  -- VEQ.main:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 200, 200)
  -- d("VEQ Tracker reset to be visible!  Tracker is unlocked, position and be sure to lock otherwise you will not be able to select quests with mouse!")
-- end

-- function VEQ.CMD_ToggleLock()
  -- if VEQ.SavedVars.PositionLockOption == true then
  -- VEQ.SetPositionLockOption(false)
  -- d("Tracker Position Unlocked")
  -- else
  -- VEQ.SetPositionLockOption(true)
  -- d("Tracker Position Locked")
  -- end
-- end

--*********************************************************************************
--* Get/Set Commands                                                              *
--*********************************************************************************


-- Get/Set Hide in combat
function VEQ.GetHideInCombatOption()
  return VEQ.SavedVars.HideInCombatOption
end

function VEQ.SetHideInCombatOption(newOpt)
  VEQ.SavedVars.HideInCombatOption = newOpt
  VEQ.QuestsListUpdate(1)
end


-- Get/Set Background Transparency
--function VEQ.GetBgAlpha()
--  return VEQ.SavedVars.BgAlpha
--end

--function VEQ.SetBgAlpha(newAlpha)
--  VEQ.SavedVars.BgAlpha = newAlpha
--  VEQ.main:SetAlpha(1)
--  VEQ.SavedVars.Preset = "Custom"
--end


-- Get/Set BGWidth
function VEQ.GetBgWidth()
  return VEQ.SavedVars.BgWidth
end
function VEQ.SetBgWidth(newWidth)
  VEQ.SavedVars.BgWidth = newWidth
  VEQ.bg:SetDimensionConstraints(newWidth,-1,newWidth,-1)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end


-- Intelligent Background
function VEQ.GetIntelligentBackgroundOption()
  return VEQ.SavedVars.IntelligentBackground
end
function VEQ.SetIntelligentBackgroundOption(newOpt)
  VEQ.SavedVars.IntelligentBackground = newOpt

end



-- Position
-- function VEQ.GetPositionLockOption()
  -- return VEQ.SavedVars.PositionLockOption
-- end
-- function VEQ.SetPositionLockOption(newOpt)
  -- VEQ.SavedVars.PositionLockOption = newOpt
  -- if newOpt == true then
    -- VEQ.main:SetMouseEnabled(false)
    -- VEQ.main:SetMovable(false)
  -- else
    -- VEQ.main:SetMouseEnabled(true)
    -- VEQ.main:SetMovable(true)
  -- end
  -- VEQ.QuestsListUpdate(1)
-- end

-- JournalInfos
function VEQ.GetShowNumbQuestOption()
  return VEQ.SavedVars.ShowNumbQuestOption
end

function VEQ.GetShowClockOption()
  return VEQ.SavedVars.ShowClockOption
end

function VEQ.GetShowTbuttonOption()
  return VEQ.SavedVars.ShowTbuttonOption
end

function VEQ.GetShowMQbuttonOption()
  return VEQ.SavedVars.ShowMQbuttonOption
end


function VEQ.SetShowNumbQuestOption(newOpt)
  VEQ.SavedVars.ShowNumbQuestOption = newOpt
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

function VEQ.SetShowClockOption(newOpt)
  VEQ.SavedVars.ShowClockOption = newOpt
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end


function VEQ.SetShowTbuttonOption(newOpt)
  VEQ.SavedVars.ShowTbuttonOption = newOpt
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

function VEQ.SetShowMQbuttonOption(newOpt)
  VEQ.SavedVars.ShowMQbuttonOption = newOpt
  VEQ.SavedVars.Preset = "Custom"
  VEQ.DisplayFocusedMiniQuest()
end



function VEQ.GetShowJournalInfosFont()
  return VEQ.SavedVars.ShowJournalInfosFont
end


function VEQ.SetShowJournalInfosFont(newFont)
  VEQ.SavedVars.ShowJournalInfosFont = newFont
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end



function VEQ.GetShowJournalInfosStyle()
  return VEQ.SavedVars.ShowJournalInfosStyle
end


function VEQ.SetShowJournalInfosStyle(newStyle)
  VEQ.SavedVars.ShowJournalInfosStyle = newStyle
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end



function VEQ.GetShowJournalInfosSize()
  return VEQ.SavedVars.ShowJournalInfosSize
end


function VEQ.SetShowJournalInfosSize(newSize)
  VEQ.SavedVars.ShowJournalInfosSize = newSize
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end



function VEQ.GetShowJournalInfosColor()
  return VEQ.SavedVars.ShowJournalInfosColor.r, VEQ.SavedVars.ShowJournalInfosColor.g, VEQ.SavedVars.ShowJournalInfosColor.b, VEQ.SavedVars.ShowJournalInfosColor.a
end


function VEQ.SetShowJournalInfosColor(r,g,b,a)
  VEQ.SavedVars.ShowJournalInfosColor.r = r
  VEQ.SavedVars.ShowJournalInfosColor.g = g
  VEQ.SavedVars.ShowJournalInfosColor.b = b
  VEQ.SavedVars.ShowJournalInfosColor.a = a
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

--[[
-- Color
function VEQ.GetBgOption()
  return VEQ.SavedVars.BgOption
end
function VEQ.SetBgOption(newOpt)
  VEQ.SavedVars.BgOption = newOpt
  if newOpt == true then
    VEQ.bg:SetColor(VEQ.SavedVars.BgColor.r,VEQ.SavedVars.BgColor.g,VEQ.SavedVars.BgColor.b,VEQ.SavedVars.BgColor.a)
  --elseif VEQ.SavedVars.BgGradientOption == true then
    -- VEQ.bg:SetGradientColors(VEQ.SavedVars.BgColor.r,VEQ.SavedVars.BgColor.g,VEQ.SavedVars.BgColor.b,VEQ.SavedVars.BgColor.a,0,0,0,0)
  else
    VEQ.bg:SetColor(0,0,0,0)
  end
  VEQ.SavedVars.Preset = "Custom"
end

function VEQ.GetBgColor()
  return VEQ.SavedVars.BgColor.r, VEQ.SavedVars.BgColor.g, VEQ.SavedVars.BgColor.b, VEQ.SavedVars.BgColor.a
end
function VEQ.SetBgColor(r,g,b,a)
  VEQ.SavedVars.BgColor.r = r
  VEQ.SavedVars.BgColor.g = g
  VEQ.SavedVars.BgColor.b = b
  VEQ.SavedVars.BgColor.a = a
  VEQ.bg:SetColor(r,g,b,a)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end
]]--

function VEQ.GetDirectionBox()
  return VEQ.SavedVars.DirectionBox
end
function VEQ.SetDirectionBox(newDirection)
  VEQ.SavedVars.DirectionBox = newDirection
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

-- Quests
function VEQ.GetSortQuests()
  return VEQ.SavedVars.SortOrder
end
function VEQ.SetSortQuests(newOrder)
  VEQ.SavedVars.SortOrder = newOrder
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetNbQuests() 
  return VEQ.SavedVars.NbQuests
end
function VEQ.SetNbQuests(newNbQuests)
  VEQ.SavedVars.NbQuests = newNbQuests
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetAutoShareOption()
  return VEQ.SavedVars.AutoShare
end
function VEQ.SetAutoShareOption(newOpt)
  VEQ.SavedVars.AutoShare = newOpt
end

function VEQ.GetAutoAcceptSharedQuestsOption()
  return VEQ.SavedVars.AutoAcceptSharedQuests
end
function VEQ.SetAutoAcceptSharedQuestsOption(newOpt)
  VEQ.SavedVars.AutoAcceptSharedQuests = newOpt
end

function VEQ.GetAutoRefuseSharedQuestsOption()
  return VEQ.SavedVars.AutoRefuseSharedQuests
end
function VEQ.SetAutoRefuseSharedQuestsOption(newOpt)
  VEQ.SavedVars.AutoRefuseSharedQuests = newOpt
end

--AcceptOfferedQuest()
--AcceptSharedQuest()
--DeclineSharedQuest()

function VEQ.GetBufferRefreshTime()
  return VEQ.SavedVars.BufferRefreshTime
end
function VEQ.SetBufferRefreshTime(newTimer)
  VEQ.SavedVars.BufferRefreshTime = newTimer
end

function VEQ.GetQuestIconOption()
  return VEQ.SavedVars.QuestIconOption
end
function VEQ.SetQuestIconOption(newOpt)
  VEQ.SavedVars.QuestIconOption = newOpt
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetQuestIcon()
  return VEQ.SavedVars.QuestIcon
end
function VEQ.SetQuestIcon(newFont)
  VEQ.SavedVars.QuestIcon = newFont
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetQuestIconSize()
  return VEQ.SavedVars.QuestIconSize
end
function VEQ.SetQuestIconSize(newSize)
  VEQ.SavedVars.QuestIconSize = newSize
  local marker = 1
  while VEQ.icon[marker] do
    VEQ.icon[marker]:SetDimensions(newSize, newSize)
    marker = marker + 1
  end
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetQuestIconColor()
  return VEQ.SavedVars.QuestIconColor.r, VEQ.SavedVars.QuestIconColor.g, VEQ.SavedVars.QuestIconColor.b, VEQ.SavedVars.QuestIconColor.a
end


function VEQ.SetQuestIconColor(r,g,b,a)
  VEQ.SavedVars.QuestIconColor.r = r
  VEQ.SavedVars.QuestIconColor.g = g
  VEQ.SavedVars.QuestIconColor.b = b
  VEQ.SavedVars.QuestIconColor.a = a
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end


function VEQ.GetHintColor()
  return VEQ.SavedVars.HintColor.r, VEQ.SavedVars.HintColor.g, VEQ.SavedVars.HintColor.b, VEQ.SavedVars.HintColor.a
end

function VEQ.SetHintColor(r,g,b,a)
  VEQ.SavedVars.HintColor.r = r
  VEQ.SavedVars.HintColor.g = g
  VEQ.SavedVars.HintColor.b = b
  VEQ.SavedVars.HintColor.a = a
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetHintCompleteColor()
  return VEQ.SavedVars.HintCompleteColor.r, VEQ.SavedVars.HintCompleteColor.g, VEQ.SavedVars.HintCompleteColor.b, VEQ.SavedVars.HintCompleteColor.a
end

function VEQ.SetHintCompleteColor(r,g,b,a)
  VEQ.SavedVars.HintCompleteColor.r = r
  VEQ.SavedVars.HintCompleteColor.g = g
  VEQ.SavedVars.HintCompleteColor.b = b
  VEQ.SavedVars.HintCompleteColor.a = a
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

--zone/area enabled
function VEQ.GetQuestsAreaOption()
  return VEQ.SavedVars.QuestsAreaOption
end

--zone/area enabled
function VEQ.SetQuestsAreaOption(newOpt)
  VEQ.SavedVars.QuestsAreaOption = newOpt
  VEQ.QuestsAreaOption = newOpt
  VEQ.SavedVars.QuestsFilter = {}
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetQuestsAreaFont()
  return VEQ.SavedVars.QuestsAreaFont
end
function VEQ.SetQuestsAreaFont(newFont)
  VEQ.SavedVars.QuestsAreaFont = newFont
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetQuestsAreaStyle()
  return VEQ.SavedVars.QuestsAreaStyle
end

function VEQ.SetQuestsAreaStyle(newStyle)
  VEQ.SavedVars.QuestsAreaStyle = newStyle
  VEQ.QuestsListUpdate(1)
end


function VEQ.GetQuestsAreaSize()
  return VEQ.SavedVars.QuestsAreaSize
end
function VEQ.SetQuestsAreaSize(newSize)
  VEQ.SavedVars.QuestsAreaSize = newSize
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetQuestsAreaPadding()
  return VEQ.SavedVars.QuestsAreaPadding
end
function VEQ.SetQuestsAreaPadding(newSize)
  VEQ.SavedVars.QuestsAreaPadding = newSize
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetQuestsAreaColor()
  return VEQ.SavedVars.QuestsAreaColor.r, VEQ.SavedVars.QuestsAreaColor.g, VEQ.SavedVars.QuestsAreaColor.b, VEQ.SavedVars.QuestsAreaColor.a
end
function VEQ.SetQuestsAreaColor(r,g,b,a)
  VEQ.SavedVars.QuestsAreaColor.r = r
  VEQ.SavedVars.QuestsAreaColor.g = g
  VEQ.SavedVars.QuestsAreaColor.b = b
  VEQ.SavedVars.QuestsAreaColor.a = a
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetQuestsShowTimerOption()
  return VEQ.SavedVars.QuestsShowTimerOption
end
function VEQ.SetQuestsShowTimerOption(newOpt)
  VEQ.SavedVars.QuestsShowTimerOption = newOpt
  VEQ.QuestsListUpdate(1)
end


function VEQ.GetHideOptObjective()
  return VEQ.SavedVars.HideOptObjective
end

function VEQ.SetHideOptObjective(newOpt)
  VEQ.SavedVars.HideOptObjective = newOpt
  VEQ.QuestsListUpdate(1)
end



function VEQ.GetHideOptionalInfo()
  return VEQ.SavedVars.HideOptionalInfo
end

function VEQ.SetHideOptionalInfo(newOpt)
  VEQ.SavedVars.HideOptionalInfo = newOpt
  VEQ.QuestsListUpdate(1)
end



function VEQ.GetHideHintsOption()
  return VEQ.SavedVars.HideHintsOption
end

function VEQ.SetHideHintsOption(newOpt)
  VEQ.SavedVars.HideHintsOption = newOpt
  VEQ.QuestsListUpdate(1)
end



function VEQ.GetHideHiddenOptions()
  return VEQ.SavedVars.HideHiddenOptions
end

function VEQ.SetHideHiddenOptions(newOpt)
  VEQ.SavedVars.HideHiddenOptions = newOpt
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetQuestsCategoryClassOption()
  return VEQ.SavedVars.QuestsCategoryClassOption
end
function VEQ.SetQuestsCategoryClassOption(newOpt)
  VEQ.SavedVars.QuestsCategoryClassOption = newOpt
  VEQ.QuestsListUpdate(1)
end
function VEQ.GetQuestsCategoryCraftOption()
  return VEQ.SavedVars.QuestsCategoryCraftOption
end
function VEQ.SetQuestsCategoryCraftOption (newOpt)
  VEQ.SavedVars.QuestsCategoryCraftOption = newOpt
  VEQ.QuestsListUpdate(1)
end
function VEQ.GetQuestsCategoryGroupOption()
  return VEQ.SavedVars.QuestsCategoryGroupOption
end
function VEQ.SetQuestsCategoryGroupOption(newOpt)
  VEQ.SavedVars.QuestsCategoryGroupOption = newOpt
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetQuestsCategoryDungeonOption()
  return VEQ.SavedVars.QuestsCategoryDungeonOption
end
function VEQ.SetQuestsCategoryDungeonOption(newOpt)
  VEQ.SavedVars.QuestsCategoryDungeonOption = newOpt
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetQuestsCategoryRaidOption()
  return VEQ.SavedVars.QuestsCategoryRaidOption
end
function VEQ.SetQuestsCategoryRaidOption(newOpt)
  VEQ.SavedVars.QuestsCategoryRaidOption = newOpt
  VEQ.QuestsListUpdate(1)
end

-- QuestObjIcon - Quest Objective Icon
--Get QuestObjIcon
function VEQ.GetQuestObjIcon()
  return VEQ.SavedVars.QuestObjIcon
end

--SEt QuestObjIcon
function VEQ.SetQuestObjIcon(newOpt)
  VEQ.SavedVars.QuestObjIcon = newOpt
  VEQ.QuestsListUpdate(1)
end
--hideoptional
function VEQ.GetHideCompleteObjHints()
  return VEQ.SavedVars.HideCompleteObjHints
end
function VEQ.SetHideCompleteObjHints(newOpt)
  VEQ.SavedVars.HideCompleteObjHints = newOpt
  VEQ.QuestsListUpdate(1)
end

--Immersive Text hide
function VEQ.GetHideImmersiveText()
  return VEQ.SavedVars.HideImmersiveText
end
function VEQ.SetHideImmersiveText(newOpt)
  VEQ.SavedVars.HideImmersiveText = newOpt
  VEQ.QuestsListUpdate(1)
end



--Focused Quest Zone Not Transparent
function VEQ.GetFocusedQuestAreaNoTrans()
  return VEQ.SavedVars.FocusedQuestAreaNoTrans
end

--Focused Quest Zone Not Transparent
function VEQ.SetFocusedQuestAreaNoTrans(newOpt)
  VEQ.SavedVars.FocusedQuestAreaNoTrans = newOpt
  VEQ.FocusedQuestAreaNoTrans = newOpt
  VEQ.QuestsListUpdate(1)
end

--enable auto hide zone
-- function VEQ.GetQuestsHideZoneOption()
  -- return VEQ.SavedVars.QuestsHideZoneOption
-- end

--enable auto hide zone
-- function VEQ.SetQuestsHideZoneOption(newOpt)
  -- VEQ.SavedVars.QuestsHideZoneOption = newOpt
  -- VEQ.QuestsHideZoneOption = newOpt
  -- if newOpt == true then 
    -- VEQ.AutoFilterZone()
  -- else
    -- VEQ.RemoveFilterZone()
  -- end
  
-- end

function VEQ.GetQuestsZoneOption()
  return VEQ.SavedVars.QuestsZoneOption
end
function VEQ.SetQuestsZoneOption(newOpt)
  VEQ.SavedVars.QuestsZoneOption = newOpt
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetQuestsZoneGuildOption()
  return VEQ.SavedVars.QuestsZoneGuildOption
end
function VEQ.SetQuestsZoneGuildOption(newOpt)
  VEQ.SavedVars.QuestsZoneGuildOption = newOpt
  VEQ.QuestsListUpdate(1)
end

--zone/area hybrid/pure zone
function VEQ.GetQuestsHybridOption()
  return VEQ.SavedVars.QuestsHybridOption
end

--zone/area hybrid/pure zone
function VEQ.SetQuestsHybridOption(newOpt)
  VEQ.SavedVars.QuestsHybridOption = newOpt
  VEQ.QuestsHybridOption = newOpt
  if VEQ.SavedVars.QuestsHideZoneOption == true then VEQ.AutoFilterZone() else VEQ.QuestsListUpdate(1) end
end 

function VEQ.GetQuestsZoneMainOption()
  return VEQ.SavedVars.QuestsZoneMainOption
end
function VEQ.SetQuestsZoneMainOption(newOpt)
  VEQ.SavedVars.QuestsZoneMainOption = newOpt
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetQuestsZoneCyrodiilOption()
  return VEQ.SavedVars.QuestsZoneCyrodiilOption
end
function VEQ.SetQuestsZoneCyrodiilOption(newOpt)
  VEQ.SavedVars.QuestsZoneCyrodiilOption = newOpt
  VEQ.QuestsListUpdate(1)
end
function VEQ.GetQuestsZoneClassOption()
  return VEQ.SavedVars.QuestsZoneClassOption
end
function VEQ.SetQuestsZoneClassOption(newOpt)
  VEQ.SavedVars.QuestsZoneClassOption = newOpt
  VEQ.QuestsListUpdate(1)
end
function VEQ.GetQuestsZoneCraftingOption()
  return VEQ.SavedVars.QuestsZoneCraftingOption
end
function VEQ.SetQuestsZoneCraftingOption(newOpt)
  VEQ.SavedVars.QuestsZoneCraftingOption = newOpt
  VEQ.QuestsListUpdate(1)
end
function VEQ.GetQuestsZoneGroupOption()
  return VEQ.SavedVars.QuestsZoneGroupOption
end
function VEQ.SetQuestsZoneGroupOption(newOpt)
  VEQ.SavedVars.QuestsZoneGroupOption = newOpt
  VEQ.QuestsListUpdate(1)
end
function VEQ.GetQuestsZoneDungeonOption()
  return VEQ.SavedVars.QuestsZoneDungeonOption
end
function VEQ.SetQuestsZoneDungeonOption(newOpt)
  VEQ.SavedVars.QuestsZoneDungeonOption = newOpt
  VEQ.QuestsListUpdate(1)
end
function VEQ.GetQuestsZoneRaidOption()
  return VEQ.SavedVars.QuestsZoneRaidOption
end
function VEQ.SetQuestsZoneRaidOption(newOpt)
  VEQ.SavedVars.QuestsZoneRaidOption = newOpt
  VEQ.QuestsListUpdate(1)
end
function VEQ.GetQuestsZoneAVAOption()
  return VEQ.SavedVars.QuestsZoneAVAOption
end
function VEQ.SetQuestsZoneAVAOption(newOpt)
  VEQ.SavedVars.QuestsZoneAVAOption = newOpt
  VEQ.QuestsListUpdate(1)
end
function VEQ.GetQuestsZoneEventOption()
  return VEQ.SavedVars.QuestsZoneEventOption
end
function VEQ.SetQuestsZoneEventOption(newOpt)
  VEQ.SavedVars.QuestsZoneEventOption = newOpt
  VEQ.QuestsListUpdate(1)
end
function VEQ.GetQuestsZoneBGOption()
  return VEQ.SavedVars.QuestsZoneBGOption
end
function VEQ.SetQuestsZoneBGOption(newOpt)
  VEQ.SavedVars.QuestsZoneBGOption = newOpt
  VEQ.QuestsListUpdate(1)
end

--Hide Optional/Hidden Quest Info/Hints ALL
function VEQ.GetHideInfoHintsOption()
  return VEQ.SavedVars.HideInfoHintsOption
end

--Hide Optional/Hidden Quest Info/Hints ALL
function VEQ.SetHideInfoHintsOption(newOpt)
  VEQ.SavedVars.HideInfoHintsOption = newOpt
  VEQ.HideInfoHintsOption = newOpt
  VEQ.QuestsListUpdate(1)
end

--[[function VEQ.GetQuestsUntrackHiddenOption()
  return VEQ.SavedVars.QuestsUntrackHiddenOption
end
function VEQ.SetQuestsUntrackHiddenOption(newOpt)
  VEQ.SavedVars.QuestsUntrackHiddenOption = newOpt
  VEQ.QuestsListUpdate(1)
end]]

--Enable Transparency for Not Focused Quests
function VEQ.GetQuestsNoFocusOption()
  return VEQ.SavedVars.QuestsNoFocusOption
end

--Enable Transparency for Not Focused Quests
function VEQ.SetQuestsNoFocusOption(newOpt)
  VEQ.SavedVars.QuestsNoFocusOption = newOpt
  VEQ.QuestsNoFocusOption = newOpt
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetQuestsNoFocusTransparency()
  return VEQ.SavedVars.QuestsNoFocusTransparency
end
function VEQ.SetQuestsNoFocusTransparency(newAlpha)
  VEQ.SavedVars.QuestsNoFocusTransparency = newAlpha
  VEQ.QuestsListUpdate(1)
end

-- Title Custom
function VEQ.GetTitleFont()
  return VEQ.SavedVars.TitleFont
end
function VEQ.SetTitleFont(newFont)
  VEQ.SavedVars.TitleFont = newFont
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetTitleStyle()
  return VEQ.SavedVars.TitleStyle
end
function VEQ.SetTitleStyle(newStyle)
  VEQ.SavedVars.TitleStyle = newStyle
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetTitleSize()
  return VEQ.SavedVars.TitleSize
end
function VEQ.SetTitleSize(newSize)
  VEQ.SavedVars.TitleSize = newSize
  VEQ.SavedVars.Preset = "Custom" 
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetTitlePadding()
  return VEQ.SavedVars.TitlePadding
end
function VEQ.SetTitlePadding(newSize)
  VEQ.SavedVars.TitlePadding = newSize
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

-- TimerTitle Custom
function VEQ.GetTimerTitleFont()
  return VEQ.SavedVars.TimerTitleFont
end
function VEQ.SetTimerTitleFont(newFont)
  VEQ.SavedVars.TimerTitleFont = newFont
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetTimerTitleStyle()
  return VEQ.SavedVars.TimerTitleStyle
end
function VEQ.SetTimerTitleStyle(newStyle)
  VEQ.SavedVars.TimerTitleStyle = newStyle
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetTimerTitleSize()
  return VEQ.SavedVars.TimerTitleSize
end
function VEQ.SetTimerTitleSize(newSize)
  VEQ.SavedVars.TimerTitleSize = newSize
  VEQ.SavedVars.Preset = "Custom" 
  VEQ.QuestsListUpdate(1)
end

-- Default TimerTitle color
function VEQ.GetTimerTitleColor()
  return VEQ.SavedVars.TimerTitleColor.r, VEQ.SavedVars.TimerTitleColor.g, VEQ.SavedVars.TimerTitleColor.b, VEQ.SavedVars.TimerTitleColor.a
end
function VEQ.SetTimerTitleColor(r,g,b,a)
  VEQ.SavedVars.TimerTitleColor.r = r
  VEQ.SavedVars.TimerTitleColor.g = g
  VEQ.SavedVars.TimerTitleColor.b = b
  VEQ.SavedVars.TimerTitleColor.a = a
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

-- Default Title color
function VEQ.GetTitleColor()
  return VEQ.SavedVars.TitleColor.r, VEQ.SavedVars.TitleColor.g, VEQ.SavedVars.TitleColor.b, VEQ.SavedVars.TitleColor.a
end
function VEQ.SetTitleColor(r,g,b,a)
  VEQ.SavedVars.TitleColor.r = r
  VEQ.SavedVars.TitleColor.g = g
  VEQ.SavedVars.TitleColor.b = b
  VEQ.SavedVars.TitleColor.a = a
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

-- Custom color level
function VEQ.GetTitleOption()
  return VEQ.SavedVars.TitleOption
end
function VEQ.SetTitleOption(newOpt)
  VEQ.SavedVars.TitleOption = newOpt
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end
--b5-Hide Object/Hints EXCEPT when ?? HideObjHintsSelect --

-- Objectives Custom
function VEQ.GetTextFont()
  return VEQ.SavedVars.TextFont
end
function VEQ.SetTextFont(newFont)
  VEQ.SavedVars.TextFont = newFont
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetTextStyle()
  return VEQ.SavedVars.TextStyle
end
function VEQ.SetTextStyle(newStyle)
  VEQ.SavedVars.TextStyle = newStyle
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetTextSize()
  return VEQ.SavedVars.TextSize
end
function VEQ.SetTextSize(newSize)
  VEQ.SavedVars.TextSize = newSize
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetTextPadding()
  return VEQ.SavedVars.TextPadding
end
function VEQ.SetTextPadding(newSize)
  VEQ.SavedVars.TextPadding = newSize
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetTextColor()
  return VEQ.SavedVars.TextColor.r, VEQ.SavedVars.TextColor.g, VEQ.SavedVars.TextColor.b, VEQ.SavedVars.TextColor.a
end
function VEQ.SetTextColor(r,g,b,a)
  VEQ.SavedVars.TextColor.r = r
  VEQ.SavedVars.TextColor.g = g
  VEQ.SavedVars.TextColor.b = b
  VEQ.SavedVars.TextColor.a = a
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetTextCompleteColor()
  return  VEQ.SavedVars.TextCompleteColor.r, VEQ.SavedVars.TextCompleteColor.g, VEQ.SavedVars.TextCompleteColor.b, VEQ.SavedVars.TextCompleteColor.a
end
function VEQ.SetTextCompleteColor(r,g,b,a)
  VEQ.SavedVars.TextCompleteColor.r = r
  VEQ.SavedVars.TextCompleteColor.g = g
  VEQ.SavedVars.TextCompleteColor.b = b
  VEQ.SavedVars.TextCompleteColor.a = a
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetTextOptionalColor()
  return VEQ.SavedVars.TextOptionalColor.r, VEQ.SavedVars.TextOptionalColor.g, VEQ.SavedVars.TextOptionalColor.b, VEQ.SavedVars.TextOptionalColor.a
end
function VEQ.SetTextOptionalColor(r,g,b,a)
  VEQ.SavedVars.TextOptionalColor.r = r
  VEQ.SavedVars.TextOptionalColor.g = g
  VEQ.SavedVars.TextOptionalColor.b = b
  VEQ.SavedVars.TextOptionalColor.a = a
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

function VEQ.GetTextOptionalCompleteColor()
  return  VEQ.SavedVars.TextOptionalCompleteColor.r, VEQ.SavedVars.TextOptionalCompleteColor.g, VEQ.SavedVars.TextOptionalCompleteColor.b, VEQ.SavedVars.TextOptionalCompleteColor.a
end
function VEQ.SetTextOptionalCompleteColor(r,g,b,a)
  VEQ.SavedVars.TextOptionalCompleteColor.r = r
  VEQ.SavedVars.TextOptionalCompleteColor.g = g
  VEQ.SavedVars.TextOptionalCompleteColor.b = b
  VEQ.SavedVars.TextOptionalCompleteColor.a = a
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end


-- Mouse Controls
function VEQ.GetButton1()
  return VEQ.SavedVars.Button1
end
function VEQ.SetButton1(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.Button1 = NewVal
end

function VEQ.GetButton2()
  return VEQ.SavedVars.Button2
end
function VEQ.SetButton2(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.Button2 = NewVal
end

function VEQ.GetButton3()
  return VEQ.SavedVars.Button3
end
function VEQ.SetButton3(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.Button3 = NewVal
end

function VEQ.GetButton4()
  return VEQ.SavedVars.Button4
end
function VEQ.SetButton4(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.Button4 = NewVal
end

function VEQ.GetButton5()
  return VEQ.SavedVars.Button5
end
function VEQ.SetButton5(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.Button5 = NewVal
end


function VEQ.GetInventorySlotsOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.InventorySlots
end
function VEQ.SetInventorySlotsOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.InventorySlots = NewVal
  VEQ.UpdateInventory()
end

function VEQ.GetInventorySlotsLimit()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.InventorySlotsLimit
end
function VEQ.SetInventorySlotsLimit(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.InventorySlotsLimit = NewVal
  VEQ.UpdateInventory()
end

function VEQ.GetLostTreasureOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.LostTreasure
end
function VEQ.SetLostTreasureOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.LostTreasure = NewVal
  VEQ.checkInventoryOnStartup()
end

function VEQ.GetSkyshardsOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.Skyshards
end
function VEQ.SetSkyshardsOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.Skyshards = NewVal
  VEQ.CheckSkyshardDistance()
end

function VEQ.GetLeadsOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.Leads
end

function VEQ.SetLeadsOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.Leads = NewVal
  VEQ.CheckLeads()
end

function VEQ.GetFakeLeadsOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.GenerateFakeLeads
end

function VEQ.SetFakeLeadsOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.GenerateFakeLeads = NewVal
end


function VEQ.GetWritsOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.Writs
end
function VEQ.SetWritsOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.Writs = NewVal
  VEQ.checkInventoryOnStartup()
end

function VEQ.GetStableOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.Stable
end
function VEQ.SetStableOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.Stable = NewVal
  VEQ.CheckRidingSkillTimer()
end

function VEQ.GetTributeRewardTimerOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.TributeRewardTimer
end
function VEQ.SetTributeRewardTimerOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.TributeRewardTimer = NewVal
  VEQ.CheckTributeRewardTimer()
end

function VEQ.GetDungeonRewardTimerOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.DungeonRewardTimer
end
function VEQ.SetDungeonRewardTimerOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.DungeonRewardTimer = NewVal
  VEQ.CheckDungeonRewardTimer()
end

function VEQ.GetBattlegroundRewardTimerOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.BattlegroundRewardTimer
end
function VEQ.SetBattlegroundRewardTimerOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.BattlegroundRewardTimer = NewVal
  VEQ.CheckBattlegroundRewardTimer()
end

function VEQ.GetFavorsTimerOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.Favors
end
function VEQ.SetFavorsTimerOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.Favors = NewVal
  VEQ.checkResetTime()
end

function VEQ.GetShadowySuppliersOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.ShadowySuppliers
end
function VEQ.SetShadowySuppliersOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.ShadowySuppliers = NewVal
  VEQ.CheckShadowySuppliers()
end

function VEQ.GetDragonguardSupplyChestOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.DragonguardSupplyChest
end
function VEQ.SetDragonguardSupplyChestOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.DragonguardSupplyChest = NewVal
  VEQ.CheckDragonguardSupplyChest()
end

function VEQ.GetBackbankOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.Backbank
end
function VEQ.SetBackbankOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.Backbank = NewVal
  VEQ.CheckBackpackBankUpgrade()
end

function VEQ.GetTamrielTomesOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.TamrielTomes
end
function VEQ.SetTamrielTomesOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.TamrielTomes = NewVal
  VEQ.CheckTamrielTomes()
end

function VEQ.GetGoldenPursuitOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.GoldenPursuits
end
function VEQ.SetGoldenPursuitOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.GoldenPursuits = NewVal
  VEQ.GoldenPursuits()
end

function VEQ.GetDisplayTrackedGoldenPursuitOnlyOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.DisplayTrackedGoldenPursuitOnly
end
function VEQ.SetDisplayTrackedGoldenPursuitOnlyOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.DisplayTrackedGoldenPursuitOnly = NewVal
  VEQ.GoldenPursuits()
end

function VEQ.GetRumorsOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.Rumors
end
function VEQ.SetRumorsOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.Rumors = NewVal
  VEQ.Rumors()
end

function VEQ.GetCommunityEventsOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.CommunityEvents
end
function VEQ.SetCommunityEventsOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.CommunityEvents = NewVal
  VEQ.CommunityEvents()
end

function VEQ.GetTicketsOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.Tickets
end
function VEQ.SetTicketsOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.Tickets = NewVal
  VEQ.CheckCurrencies()
end

function VEQ.GetTicketsLimit()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.TicketsLimit
end
function VEQ.SetTicketsLimit(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.TicketsLimit = NewVal
  VEQ.CheckCurrencies()
end

function VEQ.GetTransmuteOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.Transmute
end
function VEQ.SetTransmuteOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.Transmute = NewVal
  VEQ.CheckCurrencies()
end

function VEQ.GetTransmuteLimit()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.TransmuteLimit
end
function VEQ.SetTransmuteLimit(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.TransmuteLimit = NewVal
  VEQ.CheckCurrencies()
end

function VEQ.GetZoneGuideOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.ZoneGuide
end
function VEQ.SetZoneGuideOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.ZoneGuide = NewVal
  VEQ.zoneStoryTracker()
end

function VEQ.GetPOIcompletionOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.POIcompletion
end
function VEQ.SetPOIcompletionOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.POIcompletion = NewVal
  VEQ.mapCompletion()
end

function VEQ.GetPoisonOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.Poison
end
function VEQ.SetPoisonOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.Poison = NewVal
  VEQ.CombatState()
end

function VEQ.GetGroupFramesOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.GroupFrames
end
function VEQ.SetGroupFramesOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.GroupFrames = NewVal
  VEQ.GroupFrames()
end

function VEQ.GetDefaultGroupFramesOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.hideDefaultGroupFrames
end
function VEQ.SetDefaultGroupFramesOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.hideDefaultGroupFrames = NewVal
end

function VEQ.GetMuseumPiecesOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.MuseumPieces
end
function VEQ.SetMuseumPiecesOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.MuseumPieces = NewVal
  VEQ.checkInventoryOnStartup()
end

function VEQ.GetFishingAchievementsOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.FishingAchievements
end
function VEQ.SetFishingAchievementsOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.FishingAchievements = NewVal
  if VEQ.MiniQuestList[21] then VEQ.MiniQuestList[21] = nil end
  if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
  VEQ.DisplayFocusedMiniQuest()
end

function VEQ.GetRandomAchievementOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.NearlyDoneAchievements
end
function VEQ.SetRandomAchievementOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.NearlyDoneAchievements = NewVal
  if VEQ.MiniQuestList[23] then VEQ.MiniQuestList[23] = nil end
  if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
  VEQ.DisplayFocusedMiniQuest()
end


function VEQ.GetDailiesCounterOption()
  VEQ.SavedVars.Preset = "Custom"
  return VEQ.SavedVars.DailiesCounter
end
function VEQ.SetDailiesCounterOption(NewVal)
  VEQ.SavedVars.Preset = "Custom"
  VEQ.SavedVars.DailiesCounter = NewVal
end

function VEQ.GetShowNumbMiniQuestOption()
  return VEQ.SavedVars.ShowNumbMiniQuestOption
end

function VEQ.SetShowNumbMiniQuestOption(newOpt)
  VEQ.SavedVars.ShowNumbMiniQuestOption = newOpt
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

-- Chat Settings

--Get/Set Chat_AddonMessages
function VEQ.GetChat_AddonMessages()
  return VEQ.SavedVars.Chat_AddonMessages
end

function VEQ.SetChat_AddonMessages(newOpt)
  VEQ.SavedVars.Chat_AddonMessages = newOpt
  VEQ.QuestsListUpdate(1)
end

-- GEt/Set Chat Questinfo
function VEQ.GetChat_QuestInfo()
  return VEQ.SavedVars.Chat_QuestInfo
end

function VEQ.SetChat_QuestInfo(newOpt)
  VEQ.SavedVars.Chat_QuestInfo = newOpt
  VEQ.QuestsListUpdate(1)
end

-- Get/Set Chat_AddonMessage_HeaderColor
function VEQ.GetChat_AddonMessage_HeaderColor()
  return  VEQ.SavedVars.Chat_AddonMessage_HeaderColor.r, VEQ.SavedVars.Chat_AddonMessage_HeaderColor.g, VEQ.SavedVars.Chat_AddonMessage_HeaderColor.b, VEQ.SavedVars.Chat_AddonMessage_HeaderColor.a
end
function VEQ.SetChat_AddonMessage_HeaderColor(r,g,b,a)
  VEQ.SavedVars.Chat_AddonMessage_HeaderColor.r = r
  VEQ.SavedVars.Chat_AddonMessage_HeaderColor.g = g
  VEQ.SavedVars.Chat_AddonMessage_HeaderColor.b = b
  VEQ.SavedVars.Chat_AddonMessage_HeaderColor.a = a
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

-- Get/Set Chat_AddonMessage_MsgColor
function VEQ.GetChat_AddonMessage_MsgColor()
  return  VEQ.SavedVars.Chat_AddonMessage_MsgColor.r, VEQ.SavedVars.Chat_AddonMessage_MsgColor.g, VEQ.SavedVars.Chat_AddonMessage_MsgColor.b, VEQ.SavedVars.Chat_AddonMessage_MsgColor.a
end
function VEQ.SetChat_AddonMessage_MsgColor(r,g,b,a)
  VEQ.SavedVars.Chat_AddonMessage_MsgColor.r = r
  VEQ.SavedVars.Chat_AddonMessage_MsgColor.g = g
  VEQ.SavedVars.Chat_AddonMessage_MsgColor.b = b
  VEQ.SavedVars.Chat_AddonMessage_MsgColor.a = a
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

-- Get/Set Chat_QuestInfo_HeaderColor
function VEQ.GetChat_QuestInfo_HeaderColor()
  return  VEQ.SavedVars.Chat_QuestInfo_HeaderColor.r, VEQ.SavedVars.Chat_QuestInfo_HeaderColor.g, VEQ.SavedVars.Chat_QuestInfo_HeaderColor.b, VEQ.SavedVars.Chat_QuestInfo_HeaderColor.a
end
function VEQ.SetChat_QuestInfo_HeaderColor(r,g,b,a)
  VEQ.SavedVars.Chat_QuestInfo_HeaderColor.r = r
  VEQ.SavedVars.Chat_QuestInfo_HeaderColor.g = g
  VEQ.SavedVars.Chat_QuestInfo_HeaderColor.b = b
  VEQ.SavedVars.Chat_QuestInfo_HeaderColor.a = a
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end

-- Get/Set Chat_QuestInfo_MsgColor
function VEQ.GetChat_QuestInfo_MsgColor()
  return  VEQ.SavedVars.Chat_QuestInfo_MsgColor.r, VEQ.SavedVars.Chat_QuestInfo_MsgColor.g, VEQ.SavedVars.Chat_QuestInfo_MsgColor.b, VEQ.SavedVars.Chat_QuestInfo_MsgColor.a
end
function VEQ.SetChat_QuestInfo_MsgColor(r,g,b,a)
  VEQ.SavedVars.Chat_QuestInfo_MsgColor.r = r
  VEQ.SavedVars.Chat_QuestInfo_MsgColor.g = g
  VEQ.SavedVars.Chat_QuestInfo_MsgColor.b = b
  VEQ.SavedVars.Chat_QuestInfo_MsgColor.a = a
  VEQ.SavedVars.Preset = "Custom"
  VEQ.QuestsListUpdate(1)
end




--*********************************************************************************
--* Mouse Functions                                                               *
--*********************************************************************************

function VEQ.MouseTitleController(button, qzone)
  if button == 1 then
    VEQ.UpdateFilterZone(qzone)
    VEQ.QuestsListUpdate(1)
  end
  if button == 2 then
    local strAutoHide = ""
    local strCatView = ""
    local strNotFocusedTrans = ""
    local strHintsHidden = ""
    --if VEQ.QuestsHideZoneOption then strAutoHide = VEQ.mylanguage.lang_Toggle_AutoHide_off else strAutoHide = VEQ.mylanguage.lang_Toggle_AutoHide_on end
    if VEQ.QuestsHybridOption == true then strCatView = VEQ.mylanguage.lang_Toggle_Category_off else strCatView = VEQ.mylanguage.lang_Toggle_Category_on end
    if VEQ.FocusedQuestAreaNoTrans then strNotFocusedTrans = VEQ.mylanguage.lang_Toggle_NotFocusTrans_off else strNotFocusedTrans = VEQ.mylanguage.lang_Toggle_NotFocusTrans_on end
    if VEQ.HideInfoHintsOption then strHintsHidden = VEQ.mylanguage.lang_Toggle_HintsHidden_on else strHintsHidden = VEQ.mylanguage.lang_Toggle_HintsHidden_off end
    ClearMenu()
    AddCustomMenuItem(VEQ.mylanguage.lang_Collaspe_All_Zones, function() VEQ.AutoFilterZone() end)
    AddCustomMenuItem(VEQ.mylanguage.lang_Expand_All_Zones, function() VEQ.RemoveFilterZone() end)
    AddCustomMenuItem("-", function () return end)
    AddCustomMenuItem(strAutoHide, function() VEQ.ToggleAutoHideZones() end)
    AddCustomMenuItem(strCatView,function() VEQ.ToggleHybrid() end)
    AddCustomMenuItem(strHintsHidden, function() VEQ.ToggleHideInfoHintsOption() end)
    AddCustomMenuItem(strNotFocusedTrans, function() VEQ.ToggleQuestsNoFocusOption() end)
    AddCustomMenuItem(VEQ.mylanguage.lang_Toggle_HideObjOption_Disabled, function () VEQ.SetToggleHideObjExceptFocused("Disabled") end)
    AddCustomMenuItem(VEQ.mylanguage.lang_Toggle_HideObjOption_FocusedQuest, function () VEQ.SetToggleHideObjExceptFocused("Focused Quest") end)
    AddCustomMenuItem(VEQ.mylanguage.lang_Toggle_HideObjOption_FocusedZone, function () VEQ.SetToggleHideObjExceptFocused("Focused Zone") end)
    ShowMenu()
  end
end


function VEQ.MouseController(button, qindex, qname)
  local valaction = "None"
  if button == 1 then
    valaction = VEQ.GetButton1()
  elseif button == 2 then
    valaction = VEQ.GetButton2()
  elseif button == 3 then
    valaction = VEQ.GetButton3()
  elseif button == 4 then
    valaction = VEQ.GetButton4()
  elseif button == 5 then
    valaction = VEQ.GetButton5()
  end
  
  if (valaction == "Change Assisted Quest") then
    VEQ.SetFocusedQuest(qindex)
  elseif valaction == "Share Quest" then
    if IsUnitGrouped('player') and GetIsQuestSharable(qindex) then
      ShareQuest(qindex)
      d(string.format("%s: %s", VEQ.mylanguage.lang_console_share, qname))
    else
      d(string.format("%s: %s", VEQ.mylanguage.lang_console_noshare, qname))
    end
  elseif valaction == "Beam me There" and BMU then
      local _, _, zoneIndex =  GetJournalQuestLocationInfo(qindex)
      BMU.sc_porting(GetZoneId(zoneIndex))
  elseif valaction == "Abandon Quest" then
     AbandonQuest(qindex)
  elseif valaction == "Show Quest on Map" then
    ZO_WorldMap_ShowQuestOnMap(qindex)
  elseif valaction == "Quest Info to Chat" then
    VEQ.QuestToChat(qindex)
  elseif valaction == "Quest Options Menu" then
    ClearMenu()
    --AddCustomMenuItem("Change Assisted Quest", function() VEQ.SetFocusedQuest(qindex) end)
    --AddCustomMenuItem("Quest to Chat",function() VEQ.QuestToChat(qindex) end)
    AddCustomMenuItem("Abandon Quest", function() AbandonQuest(qindex) end)
    AddCustomMenuItem("Share Quest", function() 
                      if IsUnitGrouped('player') and GetIsQuestSharable(qindex) then
                        ShareQuest(qindex)
                        d(string.format("%s: %s", VEQ.mylanguage.lang_console_share, qname))
                      else
                        d(string.format("%s: %s", VEQ.mylanguage.lang_console_noshare, qname))
                      end
                    end)
    AddCustomMenuItem("Show Quest On Map", function() ZO_WorldMap_ShowQuestOnMap(qindex) end)
    AddCustomMenuItem("Beam me there", function() if BMU then local _, _, zoneIndex =  GetJournalQuestLocationInfo(qindex) BMU.sc_porting(GetZoneId(zoneIndex)) end end)
    ShowMenu()
  end 
end

function VEQ.LoadKeybindInfo()
  --zone/area enabled
  VEQ.QuestsAreaOption = VEQ.SavedVars.QuestsAreaOption
  --if VEQ.QuestsAreaOption == true then d("Area On") else d("Area Off") end
  --zone/area hybrid/pure zone
  VEQ.QuestsHybridOption = VEQ.SavedVars.QuestsHybridOption
  --if VEQ.QuestsHybridOption == true then d("Category On") else d("Categpry Off") end
  --enable auto hide zone
  --VEQ.QuestsHideZoneOption = VEQ.SavedVars.QuestsHideZoneOption
  --if VEQ.QuestsHideZoneOption == true then d("enable auto hide zone On") else d("enable auto hide zone Off") end
  --Enable Transparency for Not Focused Quests
  VEQ.QuestsNoFocusOption = VEQ.SavedVars.QuestsNoFocusOption
  --if VEQ.QuestsNoFocusOption == true then d("Transparcncey for not focused On") else d("Transparency for not focused is Off") end
  --Focused Quest Zone Not Transparent
  VEQ.FocusedQuestAreaNoTrans = VEQ.SavedVars.FocusedQuestAreaNoTrans
  --if VEQ.FocusedQuestAreaNoTrans == true then d("Focused Quest Zone Not Transparent On") else d("Focused Quest Zone Not Transparent Off") end
  --Hide Optional/Hidden Quest Info/Hints ALL
  VEQ.HideInfoHintsOption = VEQ.SavedVars.HideInfoHintsOption
  --if VEQ.HideInfoHintsOption == true then d("Hide Optional/Hidden Quest Info/Hints ALL On") else d("Hide Optional/Hidden Quest Info/Hints ALL Off") end
  --HideObjOption
  VEQ.HideObjOption = VEQ.SavedVars.HideObjOption
  --d(string.format("HideObjOption is set to  %s", VEQ.HideObjOption))
end

function VEQ.updatePerZoneDisplay()
     local resetZoneMiniquestTo
     if VEQ.FocusedMiniQuest ~= nil then
       for i=1, GetNumZones() do
          -- we exclude  8 is Tamriel tomes, 22 is Golden pursuits, 24 is community events
         if VEQ.KillTheRubbish(GetZoneNameByIndex(i)) == VEQ.FocusedMiniQuest and VEQ.FocusedMiniQuest ~= 8 and VEQ.FocusedMiniQuest ~= 22 and VEQ.FocusedMiniQuest ~= 24 then
           resetZoneMiniquestTo = VEQ.FocusedMiniQuest
         end
       end
     end
         
     -- create table if it doesn't exist
     VEQ.MiniQuestList = VEQ.MiniQuestList or {}
     
     -- create table if it doesn't exist
     VEQ.PerUniqueIdList = VEQ.PerUniqueIdList or {}
     
     -- create table if it doesn't exist
     VEQ.LeadsList = VEQ.LeadsList or {}
     
    local perZoneList = {}
    -- global to local variables before loop
    local allString = GetString(SI_GUILD_HISTORY_SUBCATEGORY_ALL)

    for k, v in pairs(VEQ.PerUniqueIdList) do
       perZoneList[v.zoneId] = perZoneList[v.zoneId] or {}
       
       if v.zoneId then 
           if v.zoneId == 0 then
             perZoneList[v.zoneId].zoneId = 0
             perZoneList[v.zoneId].zoneName = allString
         elseif type(v.zoneId) == "string" then
           perZoneList[v.zoneId].zoneId = -1
           perZoneList[v.zoneId].zoneName = VEQ.KillTheRubbish(v.zoneId)
         else
             perZoneList[v.zoneId].zoneId = v.zoneId
             perZoneList[v.zoneId].zoneName = VEQ.KillTheRubbish(GetZoneNameById(v.zoneId))
         end

       end

       if perZoneList[v.zoneId].text then
            perZoneList[v.zoneId].text = string.format("%s\n%s", perZoneList[v.zoneId].text, v.text)
       else
           perZoneList[v.zoneId].text = v.text
       end
       
       
       if v.zoneId2 then
           perZoneList[v.zoneId2] = perZoneList[v.zoneId2] or {}
         
         if v.zoneId2 == 0 then
           perZoneList[v.zoneId2].zoneId = 0
           perZoneList[v.zoneId2].zoneName = allString
           elseif type(v.zoneId2) == "string" then
           perZoneList[v.zoneId2].zoneId = -1
           perZoneList[v.zoneId2].zoneName = VEQ.KillTheRubbish(v.zoneId2)
         else 
          perZoneList[v.zoneId2].zoneId = v.zoneId2 
          perZoneList[v.zoneId2].zoneName = VEQ.KillTheRubbish(GetZoneNameById(v.zoneId2))
         end
         
         if perZoneList[v.zoneId2].text then
          perZoneList[v.zoneId2].text = string.format("%s\n%s", perZoneList[v.zoneId2].text, v.text)
         else
           perZoneList[v.zoneId2].text = v.text
         end
       
       end
       
       if v.zoneId3 then
           perZoneList[v.zoneId3] = perZoneList[v.zoneId3] or {}
         
         if v.zoneId3 == 0 then
                perZoneList[v.zoneId3].zoneId = 0
                perZoneList[v.zoneId3].zoneName = allString
         elseif type(v.zoneId3) == "string" then
            perZoneList[v.zoneId3].zoneId = -1
            perZoneList[v.zoneId3].zoneName = VEQ.KillTheRubbish(v.zoneId3)
               else 
                perZoneList[v.zoneId3].zoneId = v.zoneId3 
                  perZoneList[v.zoneId3].zoneName = VEQ.KillTheRubbish(GetZoneNameById(v.zoneId3))
         end
         
         if perZoneList[v.zoneId3].text then
          perZoneList[v.zoneId3].text = string.format("%s\n%s", perZoneList[v.zoneId3].text, v.text)
         else
           perZoneList[v.zoneId3].text = v.text
         end
       
       end
       
       if v.zoneId4 then
           perZoneList[v.zoneId4] = perZoneList[v.zoneId4] or {}
         
         if v.zoneId4 == 0 then
                perZoneList[v.zoneId4].zoneId = 0
                perZoneList[v.zoneId4].zoneName = allString
         elseif type(v.zoneId4) == "string" then
            perZoneList[v.zoneId4].zoneId = -1
            perZoneList[v.zoneId4].zoneName = VEQ.KillTheRubbish(v.zoneId4)
               else 
                perZoneList[v.zoneId4].zoneId = v.zoneId4 
                  perZoneList[v.zoneId4].zoneName = VEQ.KillTheRubbish(GetZoneNameById(v.zoneId4))
         end
         
         if perZoneList[v.zoneId4].text then
          perZoneList[v.zoneId4].text = string.format("%s\n%s", perZoneList[v.zoneId4].text, v.text)
         else
           perZoneList[v.zoneId4].text = v.text
         end
       
       end
        end 
    

    for k, v in pairs(VEQ.LeadsList) do
       perZoneList[v.zoneId] = perZoneList[v.zoneId] or {}
       if v.zoneId then perZoneList[v.zoneId].zoneId = v.zoneId end
       if v.zoneId then perZoneList[v.zoneId].zoneName = VEQ.KillTheRubbish(GetZoneNameById(v.zoneId)) end
       
       if perZoneList[v.zoneId].text then
        perZoneList[v.zoneId].text = string.format("%s\n%s", perZoneList[v.zoneId].text, v.text)
       else
         perZoneList[v.zoneId].text = v.text
       end
    end
    
    -- zonestory
    if VEQ.SavedVars.ZoneGuide and VEQ.CurrentZoneStory and VEQ.CurrentZoneStory ~= nil and VEQ.CurrentZoneStory.zoneId then
       perZoneList[VEQ.CurrentZoneStory.zoneId] = perZoneList[VEQ.CurrentZoneStory.zoneId] or {}
       perZoneList[VEQ.CurrentZoneStory.zoneId].zoneId = VEQ.CurrentZoneStory.zoneId
       perZoneList[VEQ.CurrentZoneStory.zoneId].zoneName = VEQ.KillTheRubbish(GetZoneNameById(VEQ.CurrentZoneStory.zoneId)) 
       
       if perZoneList[VEQ.CurrentZoneStory.zoneId].text then
        perZoneList[VEQ.CurrentZoneStory.zoneId].text = string.format("%s\n%s", perZoneList[VEQ.CurrentZoneStory.zoneId].text, VEQ.CurrentZoneStory.text)
       else
         perZoneList[VEQ.CurrentZoneStory.zoneId].text = VEQ.CurrentZoneStory.text
       end
    end
    
    -- map Completion
    if VEQ.CurrentMapCompletion ~= nil and VEQ.CurrentMapCompletion and VEQ.CurrentMapCompletion.zoneId then
       perZoneList[VEQ.CurrentMapCompletion.zoneId] = perZoneList[VEQ.CurrentMapCompletion.zoneId] or {}
       perZoneList[VEQ.CurrentMapCompletion.zoneId].zoneId = VEQ.CurrentMapCompletion.zoneId
       perZoneList[VEQ.CurrentMapCompletion.zoneId].zoneName = VEQ.KillTheRubbish(GetZoneNameById(VEQ.CurrentMapCompletion.zoneId)) 
       
       if perZoneList[VEQ.CurrentMapCompletion.zoneId].text then
        perZoneList[VEQ.CurrentMapCompletion.zoneId].text = string.format("%s\n%s\n%s", perZoneList[VEQ.CurrentMapCompletion.zoneId].text, VEQ.CurrentMapCompletion.text, VEQ.CurrentMapCompletion.completionMessage)
       else
         perZoneList[VEQ.CurrentMapCompletion.zoneId].text = string.format("%s\n%s", VEQ.CurrentMapCompletion.text, VEQ.CurrentMapCompletion.completionMessage)
       end
    end
    
    --skyshards completion
    if VEQ.skyshardCompletionMessage  and VEQ.skyshardCompletionMessage ~= "" and VEQ.CurrentMapCompletion and VEQ.CurrentMapCompletion.zoneId then
       perZoneList[VEQ.CurrentMapCompletion.zoneId] = perZoneList[VEQ.CurrentMapCompletion.zoneId] or {}
       perZoneList[VEQ.CurrentMapCompletion.zoneId].zoneId = VEQ.CurrentMapCompletion.zoneId
       perZoneList[VEQ.CurrentMapCompletion.zoneId].zoneName = VEQ.KillTheRubbish(GetZoneNameById(VEQ.CurrentMapCompletion.zoneId))
       
       if perZoneList[VEQ.CurrentMapCompletion.zoneId].text then
        perZoneList[VEQ.CurrentMapCompletion.zoneId].text = string.format("%s\n%s", perZoneList[VEQ.CurrentMapCompletion.zoneId].text, VEQ.skyshardCompletionMessage)
       else
         perZoneList[VEQ.CurrentMapCompletion.zoneId].text = VEQ.skyshardCompletionMessage
       end
    end


    -- clean all the zone to-do list miniquests
    for k, v in pairs(VEQ.MiniQuestList) do
        if VEQ.MiniQuestList[k].index == 2 then VEQ.MiniQuestList[k] = nil end
        end
    
    if NonContiguousCount(perZoneList) == 0 then
       return
    end

    for k, v in pairs(perZoneList) do
        local zoneName = v.zoneName or VEQ.KillTheRubbish(GetZoneNameById(v.zoneId)) 
        if v.zoneId == 0 then zoneName = GetString(SI_GUILD_HISTORY_SUBCATEGORY_ALL) end
        VEQ.LoadMiniQuestsInfo(2, zoneName, VEQ.mylanguage.lang_todolist, v.text,  zoneName, "esoui/art/tutorial/gamepad/achievement_categoryicon_exploration.dds", 0, 0, v.zoneId)
    end
    
    
    
    if resetZoneMiniquestTo then
        VEQ.FocusedMiniQuest = resetZoneMiniquestTo
    end
    
      VEQ.DisplayFocusedMiniQuest()
end



function VEQ.checkInventoryOnStartup()-- on init only

         if not IsPlayerActivated() then return end
     
         -- create table if it doesn't exist
     VEQ.MiniQuestList = VEQ.MiniQuestList or {}
     
         -- create table if it doesn't exist
     VEQ.PerUniqueIdList = VEQ.PerUniqueIdList or {}

       local bagpack = SHARED_INVENTORY.bagCache[BAG_BACKPACK]
       for _, slotData in pairs(bagpack) do
          local itemId = GetItemId(slotData.bagId, slotData.slotIndex)
          local uniqueId = GetItemUniqueId(slotData.bagId, slotData.slotIndex)
          local itemName = GetItemName(slotData.bagId, slotData.slotIndex)
          itemName = VEQ.KillTheRubbish(itemName)
          local itemType, specializedItemType = GetItemType(slotData.bagId, slotData.slotIndex)
          local itemLink = GetItemLink(slotData.bagId, slotData.slotIndex)
          local isBound = IsItemBound(slotData.bagId, slotData.slotIndex)
          local stacks, _ = GetSlotStackSize(slotData.bagId, slotData.slotIndex)
          
          if not stacks or stacks < 2 then
              stacks = ""
          else
              stacks = string.format(" x%s", stacks)
          end
                 

         if VEQ.SavedVars.LostTreasure then -- lost treasure
          local thatMap = LibTreasure_GetItemIdData(itemId)
          
          if thatMap ~= nil then
             local pinType = thatMap.pinType
             local texture = thatMap.texture
             local mapID = thatMap.mapId
             local _, _, _,zoneIndex, _ = GetMapInfoById(mapID)
             local zoneId = GetZoneId(zoneIndex)
                       local icon = ""

             local cleanedZonename = zo_strformat(SI_ALERTTEXT_LOCATION_FORMAT, GetZoneNameById(zoneId)) -- VEQ.KillTheRubbish(GetZoneNameById(zoneId))

             itemName = itemName:gsub(string.format(": %s", cleanedZonename), "")
             itemName = itemName:gsub(": Alik'r", "")
             
             itemName = itemName:gsub(string.format("%s ", cleanedZonename), "")
             itemName = itemName:gsub("Alik'r", "")
   

            if pinType == "survey" then
               icon = zo_iconFormatInheritColor("esoui/art/inventory/gamepad/gp_inventory_icon_materials.dds", 24, 24)
               VEQ.PerUniqueIdList[uniqueId] =  VEQ.PerUniqueIdList[uniqueId] or {}
               VEQ.PerUniqueIdList[uniqueId].zoneId = zoneId
               VEQ.PerUniqueIdList[uniqueId].text = string.format("%s%s%s", icon, itemName, stacks)
            elseif pinType == "clue" then 
               icon = zo_iconFormatInheritColor("esoui/art/tradinghouse/gamepad/gp_tradinghouse_trophy_treasure_map.dds", 24, 24)
               VEQ.PerUniqueIdList[uniqueId] =  VEQ.PerUniqueIdList[uniqueId] or {}
               VEQ.PerUniqueIdList[uniqueId].zoneId = zoneId
               VEQ.PerUniqueIdList[uniqueId].text = string.format("%s%s%s", icon, itemName, stacks)
            else 
               icon = zo_iconFormatInheritColor("esoui/art/tradinghouse/gamepad/gp_tradinghouse_trophy_treasure_map.dds", 24, 24)
               VEQ.PerUniqueIdList[uniqueId] =  VEQ.PerUniqueIdList[uniqueId] or {}
               VEQ.PerUniqueIdList[uniqueId].zoneId = zoneId
               VEQ.PerUniqueIdList[uniqueId].text = string.format("%s%s%s", icon, itemName, stacks)
            end

          end
         end
         
         
        if VEQ.SavedVars.Writs and WritWorthy then  
             if itemType == ITEMTYPE_MASTER_WRIT or itemType == SPECIALIZED_ITEMTYPE_MASTER_WRIT  then -- doable master writ
               -- LibMotif.IsKnown(motif_id, item_page_num)
             local basetext = GenerateMasterWritBaseText(itemLink)
             local rewardText = GenerateMasterWritRewardText(itemLink)
             local itemIcon = GetItemLinkIcon(itemLink)
             local craftSkill = VEQ.GetCraftSkillFromIconPath(itemIcon)
             local qualityColor = GetItemQualityColor(GetItemLinkDisplayQuality(itemLink)) 
             local crop = VEQ.mysplit(basetext, ":")
             local crop2 = VEQ.mysplit(crop[2], ";")
             local crop5 = VEQ.mysplit(crop[5], ";")
             local setNameAndLocation = ""
             local setName = ""
             local setLocation = ""
             local zoneIds = {}
             local rewardText2 = VEQ.mysplit(rewardText, ":")
             local rewardText3 = string.match(rewardText2[2], "%d+")
             local rewardIcon = GetCurrencyKeyboardIcon(CURT_WRIT_VOUCHERS)
             local textIcon = string.format("|t12:12:%s|t", rewardIcon)

             
             if crop5 ~= nil and crop5 ~= "" then
                 setName = crop5[1]:sub(2) 
                 setLocation, zoneIds = VEQ.getSetLocation(setName, craftSkill)
             else
                 setLocation, zoneIds = VEQ.getSetLocation("null", craftSkill)
             end
             
             if setLocation ~= "" then setNameAndLocation = string.format("%s - %s\n", setName, setLocation) end
             if rewardText ~= nil and rewardText ~= "" then 
               if setNameAndLocation ~= "" then
                 rewardText = string.format("%s %s\n", zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), rewardText)
               else
                 rewardText = string.format("%s\n", rewardText)
               end
             end
       
             
            if VEQ.IsWritDoable(itemLink) then
               local icon = zo_iconFormatInheritColor("esoui/art/tutorial/poi_crafting_complete.dds", 24, 24)
               local text = qualityColor:Colorize(string.format("%s%s%s: ", icon, VEQ.mylanguage.lang_doable, itemName))
               VEQ.PerUniqueIdList[uniqueId] =  VEQ.PerUniqueIdList[uniqueId] or {}
               VEQ.PerUniqueIdList[uniqueId].text = string.format("%s%s%s", text, rewardText3, textIcon)
               for k,v in pairs(zoneIds) do
                   if VEQ.PerUniqueIdList[uniqueId].zoneId == nil then
                      VEQ.PerUniqueIdList[uniqueId].zoneId = zoneIds[k] 
                   elseif VEQ.PerUniqueIdList[uniqueId].zoneId2 == nil and zoneIds[k] ~= VEQ.PerUniqueIdList[uniqueId].zoneId then
                      VEQ.PerUniqueIdList[uniqueId].zoneId2 = zoneIds[k]
                   elseif VEQ.PerUniqueIdList[uniqueId].zoneId3 == nil and zoneIds[k] ~= VEQ.PerUniqueIdList[uniqueId].zoneId and zoneIds[k] ~= VEQ.PerUniqueIdList[uniqueId].zoneId2 then
                      VEQ.PerUniqueIdList[uniqueId].zoneId3 = zoneIds[k]
                   elseif VEQ.PerUniqueIdList[uniqueId].zoneId4 == nil and zoneIds[k] ~= VEQ.PerUniqueIdList[uniqueId].zoneId and zoneIds[k] ~= VEQ.PerUniqueIdList[uniqueId].zoneId2 and zoneIds[k] ~= VEQ.PerUniqueIdList[uniqueId].zoneId3 then
                      VEQ.PerUniqueIdList[uniqueId].zoneId4 = zoneIds[k]
                 end
                 end
            end
           
           end
         
                end
        
        if VEQ.SavedVars.MuseumPieces then -- museum pieces
             thievesMuseumPiece = false
             for _,v in pairs(VEQ.MuseumPieces.Thieves) do
                if itemId == v then
                   thievesMuseumPiece = true break
                end 
             end
             
             ArtaeumMuseumPiece = false
             for _,v in pairs(VEQ.MuseumPieces.Artaeum) do
                if itemId == v then
                   ArtaeumMuseumPiece = true break
                end 
             end
             
             if (specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_MUSEUM_PIECE or thievesMuseumPiece or ArtaeumMuseumPiece) and isBound and IsItemLinkBook(itemLink) == false and DoesItemLinkStartQuest(itemLink) == false then 
               local itemDesc = GetItemLinkFlavorText(itemLink)
             local zoneId = 1
             
             for i=1, GetNumZones() do
                local testZoneId = GetZoneId(i)
                local parentZoneId = GetParentZoneId(testZoneId)
                local mapId = GetMapIdByZoneId(testZoneId)
                local _, mapType = GetMapInfoById(mapId)
                if string.find(itemDesc, GetZoneNameByIndex(i)) and mapType == MAPTYPE_ZONE then
                  zoneId = GetZoneId(i)
                end
             end
             
             -- f*ck*ng Ornisium / Wrothgar mismatch
             if zoneId == 1 and string.find(itemDesc, GetMapNameById(895)) then
              zoneId = 684
             end
             
             -- Hew's bane / Kari's Hit List
             if zoneId == 1 and thievesMuseumPiece then
                 zoneId = 816
             end
             
             -- Artaeum / Thieves Guild Dead Drops
             if zoneId == 1 and ArtaeumMuseumPiece then
                 zoneId = 1011
             end
             
             local icon = zo_iconFormatInheritColor("esoui/art/icons/servicemappins/servicepin_museum.dds", 24, 24) 
             VEQ.PerUniqueIdList[uniqueId] =  VEQ.PerUniqueIdList[uniqueId] or {}
             VEQ.PerUniqueIdList[uniqueId].zoneId = zoneId
             VEQ.PerUniqueIdList[uniqueId].text = string.format("%s%s %s", icon, VEQ.mylanguage.lang_museum, itemName)
             end
        end

            end -- end of the browse inventory loop
     
  zo_callLater(function()  VEQ.UpdateInventory() end, 1000)
  VEQ.CheckTamrielTomes()
  VEQ.updatePerZoneDisplay()
end


function VEQ.IsWritDoable(itemLink)
  local parser = WritWorthy.CreateParser(itemLink)
  if (not parser or not parser:ParseItemLink(itemLink) or not parser.ToKnowList) then
    return false
  else
    local knowList = parser:ToKnowList()
    if (knowList) then
      for _, know in pairs(knowList) do
        if (not know.is_known) then
          return false
        end
      end
    end
    -- it is known    
    local matList = parser:ToMatList()  
    -- have materials ?
    if matList then

            for _,matRow in pairs(matList) do
            if WritWorthy.Util.MatHaveCt(matRow.link) < matRow.ct then return false end
            end
    end
    return true
  end
end



function VEQ.updateTableLength(T) -- update number of miniquests
   local count = 0
   local next = next
   if next(T) == nil then count = 0 
   else
       for _, __ in pairs(T) do count = count + 1 end
   end
   
   if count == nil then VEQ.totalMiniQuests = 0
   else
   VEQ.totalMiniQuests = count
   end
   
end


function VEQ.SlotUpdated(bagId, slotIndex, isNew)
  if not IsPlayerActivated() then return end 
    -- create table if it doesn't exist
   VEQ.MiniQuestList = VEQ.MiniQuestList or {}
  -- create table if it doesn't exist
  VEQ.PerUniqueIdList = VEQ.PerUniqueIdList or {}
   
   
  local stacks, _ = GetSlotStackSize(bagId, slotIndex)
          
     if not stacks or stacks == 0 then
       return -- item removed
   elseif stacks < 2 then
       stacks = ""
     else
       stacks = string.format(" x%s", stacks)
     end


  if bagId ~= BAG_BACKPACK then
    if bagId == BAG_WORN and (slotIndex == EQUIP_SLOT_POISON or slotIndex == EQUIP_SLOT_BACKUP_POISON) then
      VEQ.CombatState()
    elseif bagId ~= BAG_VIRTUAL then
      return
    end 
  end

   local itemName = GetItemName(bagId, slotIndex)
   itemName = VEQ.KillTheRubbish(itemName)
   local link = GetItemLink(bagId, slotIndex)
   local thatItemID = GetItemLinkItemId(link)
   local itemId = GetItemId(bagId, slotIndex)
   local uniqueId = GetItemUniqueId(bagId, slotIndex)
   local itemType, specializedItemType = GetItemType(bagId, slotIndex)
   local isBound = IsItemBound(bagId, slotIndex)

 
  local updateIdList = false
  if VEQ.SavedVars.LostTreasure then
    -- Lost treasure integration

  
    if link ~= nil then
        
              -- load LostTreasure maps
             local thatMap = LibTreasure_GetItemIdData(thatItemID)
        
        if thatMap ~= nil then

           --local itemId, mapId, pinType, x, y, texture = value 
           local itemId = thatMap.itemId
           local pinType = thatMap.pinType
           local texture = thatMap.texture
           local mapID = thatMap.mapId
           local _, _, _,zoneIndex, _ = GetMapInfoById(mapID)
           local zoneId = GetZoneId(zoneIndex)
           local icon = ""
           
           local cleanedZonename = VEQ.KillTheRubbish(GetZoneNameById(zoneId))
           itemName = itemName:gsub(string.format(": %s", cleanedZonename), "")
           itemName = itemName:gsub(": Alik'r", "")
           itemName = itemName:gsub(string.format("%s ", cleanedZonename), "")
           itemName = itemName:gsub("Alik'r", "")

           if pinType == "survey" then
             icon = zo_iconFormatInheritColor("esoui/art/inventory/gamepad/gp_inventory_icon_materials.dds", 24, 24)
             VEQ.PerUniqueIdList[uniqueId] =  VEQ.PerUniqueIdList[uniqueId] or {}
             VEQ.PerUniqueIdList[uniqueId].zoneId = zoneId
             VEQ.PerUniqueIdList[uniqueId].text = string.format("%s%s%s", icon, itemName, stacks)
             updateIdList = true
           elseif pinType == "clue" then 
             icon = zo_iconFormatInheritColor("esoui/art/tradinghouse/gamepad/gp_tradinghouse_trophy_treasure_map.dds", 24, 24)
             VEQ.PerUniqueIdList[uniqueId] =  VEQ.PerUniqueIdList[uniqueId] or {}
             VEQ.PerUniqueIdList[uniqueId].zoneId = zoneId
             VEQ.PerUniqueIdList[uniqueId].text = string.format("%s%s%s", icon, itemName, stacks)
             updateIdList = true
           else
             icon = zo_iconFormatInheritColor("esoui/art/tradinghouse/gamepad/gp_tradinghouse_trophy_treasure_map.dds", 24, 24) 
             VEQ.PerUniqueIdList[uniqueId] =  VEQ.PerUniqueIdList[uniqueId] or {}
             VEQ.PerUniqueIdList[uniqueId].zoneId = zoneId
             VEQ.PerUniqueIdList[uniqueId].text = string.format("%s%s%s", icon, itemName, stacks)
             updateIdList = true
           end
              end
      end
  end
  
  
  
   if VEQ.SavedVars.Writs and WritWorthy then 
      if itemType == ITEMTYPE_MASTER_WRIT or itemType == SPECIALIZED_ITEMTYPE_MASTER_WRIT then -- doable master writ
       local basetext = GenerateMasterWritBaseText(link)
       local rewardText = GenerateMasterWritRewardText(link)
       local itemIcon = GetItemLinkIcon(link)
       local craftSkill = VEQ.GetCraftSkillFromIconPath(itemIcon)
       local qualityColor = GetItemQualityColor(GetItemLinkDisplayQuality(link))
       local crop = VEQ.mysplit(basetext, ":")
       local crop2 = VEQ.mysplit(crop[2], ";")
       local crop5 = VEQ.mysplit(crop[5], ";") 
       local setNameAndLocation = ""
       local setName = ""
       local setLocation = ""
       local zoneIds = {}
       local rewardText2 = VEQ.mysplit(rewardText, ":")
       local rewardText3 = string.match(rewardText2[2], "%d+")
       local rewardIcon = GetCurrencyKeyboardIcon(CURT_WRIT_VOUCHERS)
       local textIcon = string.format("|t12:12:%s|t", rewardIcon)
       
       if crop5 ~= nil and crop5 ~= "" then
         setName = crop5[1]:sub(2) 
         setLocation, zoneIds = VEQ.getSetLocation(setName, craftSkill)
       else
         setLocation, zoneIds = VEQ.getSetLocation("null", craftSkill)
       end
       if setLocation ~= "" then setNameAndLocation = string.format("%s - %s \n", setName, setLocation) end 
       if rewardText ~= nil and rewardText ~= "" then 
         if setNameAndLocation ~= "" then
           rewardText = string.format("%s%s\n", zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), rewardText)
         else
           rewardText = string.format("%s\n", rewardText)
         end
       end
     
       if VEQ.IsWritDoable(link) then
        local icon = zo_iconFormatInheritColor("esoui/art/tutorial/poi_crafting_complete.dds", 24, 24)
        local text = qualityColor:Colorize(string.format("%s%s%s: ", icon, VEQ.mylanguage.lang_doable, itemName))
        VEQ.PerUniqueIdList[uniqueId] =  VEQ.PerUniqueIdList[uniqueId] or {}
        VEQ.PerUniqueIdList[uniqueId].text = string.format("%s%s%s", text, rewardText3, textIcon)
        for k,v in pairs(zoneIds) do
           if VEQ.PerUniqueIdList[uniqueId].zoneId == nil then VEQ.PerUniqueIdList[uniqueId].zoneId = zoneIds[k] 
           elseif VEQ.PerUniqueIdList[uniqueId].zoneId2 == nil and zoneIds[k] ~= VEQ.PerUniqueIdList[uniqueId].zoneId then VEQ.PerUniqueIdList[uniqueId].zoneId2 = zoneIds[k]
           elseif VEQ.PerUniqueIdList[uniqueId].zoneId3 == nil and zoneIds[k] ~= VEQ.PerUniqueIdList[uniqueId].zoneId and zoneIds[k] ~= VEQ.PerUniqueIdList[uniqueId].zoneId2 then VEQ.PerUniqueIdList[uniqueId].zoneId3 = zoneIds[k]
           elseif VEQ.PerUniqueIdList[uniqueId].zoneId4 == nil and zoneIds[k] ~= VEQ.PerUniqueIdList[uniqueId].zoneId and zoneIds[k] ~= VEQ.PerUniqueIdList[uniqueId].zoneId2 and zoneIds[k] ~= VEQ.PerUniqueIdList[uniqueId].zoneId3 then VEQ.PerUniqueIdList[uniqueId].zoneId4 = zoneIds[k]
           end
           updateIdList = true
         end 
       end
     
      end
    end
    
  
  if VEQ.SavedVars.MuseumPieces then
       thievesMuseumPiece = false
     for _,v in pairs(VEQ.MuseumPieces.Thieves) do
        if itemId == v then
           thievesMuseumPiece = true break
        end 
     end
     ArtaeumMuseumPiece = false
     for _,v in pairs(VEQ.MuseumPieces.Artaeum) do
        if itemId == v then
           ArtaeumMuseumPiece = true break
        end 
     end
     if (specializedItemType == SPECIALIZED_ITEMTYPE_TROPHY_MUSEUM_PIECE or thievesMuseumPiece or ArtaeumMuseumPiece) and isBound and IsItemLinkBook(link) == false and DoesItemLinkStartQuest(link) == false then
       local itemDesc = GetItemLinkFlavorText(link)
       local zoneId = 1
       
       for i=1, GetNumZones() do
        local testZoneId = GetZoneId(i)
        local parentZoneId = GetParentZoneId(testZoneId)
        local mapId = GetMapIdByZoneId(testZoneId)
        local _, mapType = GetMapInfoById(mapId)
        if string.find(itemDesc, GetZoneNameByIndex(i)) and mapType == MAPTYPE_ZONE then
          zoneId = GetZoneId(i)
        end
       end
       
       -- f*ck*ng Ornisium / Wrothgar mismatch
       if zoneId == 1 and string.find(itemDesc, GetMapNameById(895)) then
        zoneId = 684
       end 
       
       -- Hew's bane / Kari's Hit List
       if zoneId == 1 and thievesMuseumPiece then
         zoneId = 816
       end
       
       -- Artaeum / Thieves Guild Dead Drops
       if zoneId == 1 and ArtaeumMuseumPiece then
           zoneId = 1011
       end
       
       local icon = zo_iconFormatInheritColor("esoui/art/icons/servicemappins/servicepin_museum.dds", 24, 24)
       VEQ.PerUniqueIdList[uniqueId] =  VEQ.PerUniqueIdList[uniqueId] or {}
       VEQ.PerUniqueIdList[uniqueId].zoneId = zoneId
       VEQ.PerUniqueIdList[uniqueId].text = string.format("%s%s: %s", icon, VEQ.mylanguage.lang_museum, itemName) 
       updateIdList = true
     
     end
  end
  
  
  -- perfect roe counter when fishing
  if VEQ.SavedVars.FishingAchievements then
      if itemId == 64222 and VEQ.main and not VEQ.main:IsHidden() and isNew then
        VEQ.Fishing(64222)
    end
  end
  
  local isInCraglorn = GetCurrentMapId() == 1126
  -- Fortified Nirncrux counter
  if itemId == 56862 and isInCraglorn and isNew then
     local fortifiedNirncruxCount = GetItemLinkInventoryCount(link, INVENTORY_COUNT_BAG_OPTION_BACKPACK_AND_BANK_AND_CRAFT_BAG)
     local icon = zo_iconFormatInheritColor("/esoui/art/icons/crafting_potent_nirncrux_stone.dds", 24, 24)
     VEQ.PerUniqueIdList["fortifiedNirncrux"] =  VEQ.PerUniqueIdList["fortifiedNirncrux"] or {}
     VEQ.PerUniqueIdList["fortifiedNirncrux"].zoneId = 888
     VEQ.PerUniqueIdList["fortifiedNirncrux"].text = string.format("%s%s x%s", icon, itemName, fortifiedNirncruxCount)
     updateIdList = true
  end 

  -- Potent Nirncrux counter
  if itemId == 56863 and isInCraglorn and isNew then
     local potentNirncruxCount = GetItemLinkInventoryCount(link, INVENTORY_COUNT_BAG_OPTION_BACKPACK_AND_BANK_AND_CRAFT_BAG)
     local icon = zo_iconFormatInheritColor("/esoui/art/icons/crafting_potent_nirncrux_dust.dds", 24, 24)
     VEQ.PerUniqueIdList["potentNirncrux"] =  VEQ.PerUniqueIdList["potentNirncrux"] or {}
     VEQ.PerUniqueIdList["potentNirncrux"].zoneId = 888
     VEQ.PerUniqueIdList["potentNirncrux"].text = string.format("%s%s x%s", icon, itemName, potentNirncruxCount)
     updateIdList = true
  end

    VEQ.UpdateInventory()
    if updateIdList then
     VEQ.updatePerZoneDisplay() 
    end 
end

function VEQ.SlotRemoved(bagId, slotIndex, oldSlotData)
  if bagId ~= BAG_BACKPACK then return end 
  
  if not IsPlayerActivated() then return end
  -- create table if it doesn't exist
  VEQ.PerUniqueIdList = VEQ.PerUniqueIdList or {}
  
  -- Lost treasure integration
  if VEQ.PerUniqueIdList[oldSlotData.uniqueId] then 
      VEQ.PerUniqueIdList[oldSlotData.uniqueId] = nil
      VEQ.updatePerZoneDisplay()
  end
  if bagId == BAG_BACKPACK then
     VEQ.UpdateInventory()
  end
end


function VEQ.GetCraftSkillFromIconPath(itemIconPath)

   local craftSkill = 0
   if itemIconPath == "/esoui/art/icons/master_writ_blacksmithing.dds" then craftSkill = CRAFTING_TYPE_BLACKSMITHING
   elseif itemIconPath == "/esoui/art/icons/master_writ_clothier.dds" then craftSkill = CRAFTING_TYPE_CLOTHIER   
   elseif itemIconPath == "/esoui/art/icons/master_writ_woodworking.dds" then craftSkill = CRAFTING_TYPE_WOODWORKING
   elseif itemIconPath == "/esoui/art/icons/master_writ_jewelry.dds" then craftSkill = CRAFTING_TYPE_JEWELRYCRAFTING
   elseif itemIconPath == "/esoui/art/icons/master_writ_alchemy.dds" then craftSkill = CRAFTING_TYPE_ALCHEMY
   elseif itemIconPath == "/esoui/art/icons/master_writ_enchanting.dds" then craftSkill = CRAFTING_TYPE_ENCHANTING
   elseif itemIconPath == "/esoui/art/icons/master_writ_provisioning.dds" then craftSkill = CRAFTING_TYPE_PROVISIONING
   end

   return craftSkill
end 


function VEQ.getSetLocation(setName, craftSkill)
  for k,v in pairs(LibSets.setInfo) do
      if setName == GetItemSetName(k) then
        local setId = k
        local zoneIds = v.zoneIds
      local zoneNames = ""
      for kk,vv in pairs(zoneIds) do
          
        if zoneNames == "" and zoneIds[kk] and type(zoneIds[kk]) ~= "string" then zoneNames = GetZoneNameById(zoneIds[kk]) 
        elseif zoneNames == "" and type(zoneIds[kk]) == "string" then zoneNames = zoneIds[kk]
        end
      end
      
      if CanThisBeCraftedAtHome then 
          local canBeCraftedAtHome, answerTable = CanThisBeCraftedAtHome.askForSetId(setId, craftSkill)

        if canBeCraftedAtHome then
            for k,v in pairs(answerTable) do
              table.insert(zoneIds, 1, string.format("%s %s", v.houseNickname, v.owner))
          end
        end
      end
      
        return zoneNames, zoneIds
      end
  end
  
  local zoneIds = {}
  table.insert(zoneIds, 0)
  local zoneNames = GetString(SI_GUILD_HISTORY_SUBCATEGORY_ALL) 
  return zoneNames, zoneIds
end

function VEQ.mysplit(inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
    if inputstr == nil or inputstr == "" then return "" end
        local t={}
        for str in string.gmatch(inputstr, string.format("([^%s]+)", sep)) do 
                table.insert(t, str)
        end
    
        return t
end



function VEQ.UpdateInventory()

         if not IsPlayerActivated() then return end
     -- create table if it doesn't exist
     VEQ.MiniQuestList = VEQ.MiniQuestList or {}
     
   if VEQ.SavedVars.InventorySlots then 
      
         -- check inventory space left
         local usedSlots, maxSlots = PLAYER_INVENTORY:GetNumSlots(INVENTORY_BACKPACK)
         local inventorySpaceLeft = maxSlots - usedSlots
     VEQ.freeSlots = VEQ.freeSlots or 0
     
      -- populate inventory value in table 
         if inventorySpaceLeft <= VEQ.SavedVars.InventorySlotsLimit then
        if VEQ.freeSlots ~= inventorySpaceLeft then
        local left = VEQ.mylanguage.lang_slots_inventory
        if IsCountSingularForm(inventorySpaceLeft) then left = VEQ.mylanguage.lang_slot_inventory end
        if inventorySpaceLeft < 1 then  
          VEQ.LoadMiniQuestsInfo(1, 1, VEQ.mylanguage.lang_inventory_full, VEQ.mylanguage.lang_free_space, VEQ.mylanguage.lang_Miscellaneous, "esoui/art/inventory/gamepad/gp_inventory_icon_all.dds")
          VEQ.DisplayFocusedMiniQuest()
        else
          VEQ.LoadMiniQuestsInfo(1, 1, string.format("%s%s", inventorySpaceLeft, left), VEQ.mylanguage.lang_free_space, VEQ.mylanguage.lang_Miscellaneous, "esoui/art/inventory/gamepad/gp_inventory_icon_all.dds") 
          VEQ.DisplayFocusedMiniQuest()
        end 
        end
         else
        if VEQ.MiniQuestList[1] then VEQ.MiniQuestList[1] = nil end
      -- update table length
            if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
        -- update miniquests displayed  
            VEQ.DisplayFocusedMiniQuest()
       end
     
     VEQ.freeSlots = inventorySpaceLeft
     else 
          if VEQ.MiniQuestList[1] then VEQ.MiniQuestList[1] = nil end
        -- update table length
            if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
        -- update miniquests displayed  
            VEQ.DisplayFocusedMiniQuest()
     end

end


function VEQ.CheckLeads()
    if not IsPlayerActivated() then return end
  

  -- create table if it doesn't exist
  VEQ.MiniQuestList = VEQ.MiniQuestList or {}
  -- create table if it doesn't exist
  VEQ.PerUniqueIdList = VEQ.PerUniqueIdList or {}
  
  -- create / reset table
  VEQ.LeadsList = {}

  
  if not VEQ.SavedVars.Leads then
     VEQ.updatePerZoneDisplay()
     return
  end
  
  local numLeads = 0
  local numHighQualityLeads = 0
  local antiquityId = GetNextAntiquityId()
    while antiquityId do
        local haveLead = DoesAntiquityHaveLead(antiquityId)
        local canScry = MeetsAntiquitySkillRequirementsForScrying(antiquityId)
        if haveLead and canScry then
        
          local setId = GetAntiquitySetId(antiquityId)
          local rewardName = GetAntiquitySetName(setId)
          local rewardQuality = GetAntiquitySetQuality(setId)
          local rewardId = GetAntiquityRewardId(antiquityId)
          
          if rewardQuality > 2 then
              numHighQualityLeads = numHighQualityLeads + 1
          end
          
          if not (numHighQualityLeads > 0 and  rewardQuality < 3) then
            if rewardName == "" then
              rewardName = REWARDS_MANAGER:GetRewardContextualTypeString(rewardId)
              rewardQuality = GetAntiquityQuality(antiquityId)
            end
            
            local antiquityDifficulty = GetAntiquityDifficulty(antiquityId)
            if rewardQuality < ANTIQUITY_DIFFICULTY_ADVANCED then
              antiquityDifficulty = rewardQuality
            end
            
            local antiquitycolor = GetAntiquityQualityColor(rewardQuality)
            
            local antiquityName = VEQ.KillTheRubbish(GetAntiquityName(antiquityId))
            local zoneId = GetAntiquityZoneId(antiquityId)
            local zoneName = VEQ.KillTheRubbish(GetZoneNameById(zoneId))
            
            
            local icon = zo_iconFormatInheritColor("esoui/art/icons/mapkey/mapkey_antiquities.dds", 18, 18) 
            VEQ.LeadsList[antiquityId] = VEQ.LeadsList[antiquityId] or {}
            VEQ.LeadsList[antiquityId].zoneId = zoneId
            local text = antiquitycolor:Colorize(string.format("%s %s", icon, antiquityName))
            VEQ.LeadsList[antiquityId].text = text
            numLeads = numLeads + 1
          end
        end
        antiquityId = GetNextAntiquityId(antiquityId)
    end

    
  VEQ.updatePerZoneDisplay()
  if numLeads == 0 and VEQ.SavedVars.GenerateFakeLeads then
     VEQ.GenerateFakeLead()
  end
end

function VEQ.GenerateFakeLead()
  local skillMaxed = MeetsAntiquitySkillRequirementsForScrying(274) 
  VEQ.CharSavedVars.LastExcavationTime = VEQ.CharSavedVars.LastExcavationTime or 0
  local canGenerate = (VEQ.CharSavedVars.LastExcavationTime + (3600*20)) < GetTimeStamp() -- 20h cooldown 
  
  if ZO_IsScryingUnlocked() and (not skillMaxed) and canGenerate then
    local fakeLeads = {}
    local antiquityId = GetNextAntiquityId()
    while antiquityId do
      local requiresLead = DoesAntiquityRequireLead(antiquityId)
      local canScry =  CanScryForAntiquity(antiquityId)
      local DLClocked = IsZoneCollectibleLocked(GetZoneIndex(GetAntiquityZoneId(antiquityId))) 
      local notBottleOfProving = VEQ.KillTheRubbish(GetQuestItemName(7435)) ~= VEQ.KillTheRubbish(GetAntiquityName(antiquityId))
      
      if (not requiresLead) and canScry and (not DLClocked) and notBottleOfProving then
        local setId = GetAntiquitySetId(antiquityId)
        local rewardName = GetAntiquitySetName(setId)
        local rewardQuality = GetAntiquitySetQuality(setId)
        local rewardId = GetAntiquityRewardId(antiquityId)
        
        if rewardName == "" then
          rewardName = REWARDS_MANAGER:GetRewardContextualTypeString(rewardId)
          rewardQuality = GetAntiquityQuality(antiquityId)
        end
        
        local antiquityDifficulty = GetAntiquityDifficulty(antiquityId)
        if rewardQuality < ANTIQUITY_DIFFICULTY_ADVANCED then
          antiquityDifficulty = rewardQuality
        end 
        
        fakeLeads[#fakeLeads+1] =
          {
          antiquityId = antiquityId,
          antiquityName = VEQ.KillTheRubbish(GetAntiquityName(antiquityId)),
          difficulty = antiquityDifficulty,
          zoneName = VEQ.KillTheRubbish(GetZoneNameById(GetAntiquityZoneId(antiquityId))),
          zoneId = GetAntiquityZoneId(antiquityId),
          antiquitycolor = GetAntiquityQualityColor(rewardQuality)
          }
      end
      antiquityId = GetNextAntiquityId(antiquityId)
    end
    
    local randomFakeLead = fakeLeads[math.random(#fakeLeads)]
    
    -- create table if it doesn't exist
      VEQ.LeadsList = VEQ.LeadsList or {}
    
    local icon = zo_iconFormatInheritColor("esoui/art/icons/mapkey/mapkey_antiquities.dds", 18, 18) 
    VEQ.LeadsList[randomFakeLead.antiquityId] =  VEQ.LeadsList[randomFakeLead.antiquityId] or {}
    VEQ.LeadsList[randomFakeLead.antiquityId].zoneId = randomFakeLead.zoneId
    local text = randomFakeLead.antiquitycolor:Colorize(string.format("%s %s", icon, randomFakeLead.antiquityName))
    VEQ.LeadsList[randomFakeLead.antiquityId].text = text
    VEQ.updatePerZoneDisplay()
  end
end



function VEQ.CheckSkyshardDistance(playerPosX, playerPosZ)
  --d("skyshard distance check started"..GetTimeString())
  if not IsPlayerActivated() then return end
  -- create table if it doesn't exist
  VEQ.MiniQuestList = VEQ.MiniQuestList or {}
     
  local ZoneId = ZO_ExplorationUtils_GetZoneStoryZoneIdForCurrentMap() 
  local numSkyshards = GetNumSkyshardsInZone(ZoneId)

  
  if numSkyshards == 0 and GetMapType() == MAPTYPE_SUBZONE then 
       ZoneId = GetParentZoneId(ZoneId)
       numSkyshards = GetNumSkyshardsInZone(ZoneId)
  end

  
  if not VEQ.SavedVars.Skyshards or numSkyshards == nil or numSkyshards == 0 or (VEQ.skyshardCompletionFullForThatZone == ZoneId and ZoneId and ZoneId ~= 0) then 
      if VEQ.MiniQuestList[3] then 
         VEQ.MiniQuestList[3] = nil 
         -- update table length
        if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
        -- update miniquests displayed  
         VEQ.DisplayFocusedMiniQuest()
      end
    return
  end
  
  if not playerPosX or not playerPosZ then return end
  
  
  local acquired = 0
    
  for i = 1, numSkyshards do
    local ShardId = GetZoneSkyshardId(ZoneId, i)
    local nX, nY, isInCurrentMap = GetNormalizedPositionForSkyshardId(ShardId) 
    local X, Y = LibGPS3:LocalToGlobal(nX, nY)
    local Status = GetSkyshardDiscoveryStatus(ShardId)
    
   if X ~= nil and Y ~= nil and X >= 0 and X <= 1 and Y >= 0 and Y <= 1 then 
   
     local distance = math.modf(LibGPS3:GetGlobalDistanceInMeters(playerPosX, playerPosZ, X, Y))
     
     if Status ~= SKYSHARD_DISCOVERY_STATUS_ACQUIRED and isInCurrentMap and distance ~= nil and distance <= 100 and distance >= 0  then
       local questionMark = ""
       local message = VEQ.mylanguage.lang_distant_sky
       
       if distance > 80 then message = VEQ.mylanguage.lang_distant_sky
       elseif distance > 60 then message = VEQ.mylanguage.lang_weak_sky
       elseif distance > 40 then message = VEQ.mylanguage.lang_moderate_sky
       elseif distance > 20 then message = VEQ.mylanguage.lang_strong_sky
       elseif distance < 0  then message = VEQ.mylanguage.lang_huge_sky questionMark = "?" 
       else message = VEQ.mylanguage.lang_huge_sky
       end
       
       VEQ.playerPositionAtLastSkyshardDistanceX = playerPosX
       VEQ.playerPositionAtLastSkyshardDistanceZ = playerPosZ
             
       VEQ.LoadMiniQuestsInfo(3, 3, string.format("%s%s", VEQ.mylanguage.lang_skyshard, questionMark), message, string.format("%s%s", distance, VEQ.mylanguage.lang_maway), "esoui/art/tutorial/gamepad/achievement_categoryicon_skyshards.dds")
       VEQ.DisplayFocusedMiniQuest()
       --d("Skyshard distance updated! "..hint)
       return
     end
   end
   
   -- no return because no skyshard is near so we remove the miniquest
    if VEQ.MiniQuestList[3] then 
       VEQ.MiniQuestList[3] = nil 
       -- update table length
        if VEQ.MiniQuestList then
           VEQ.updateTableLength(VEQ.MiniQuestList)
        end
      -- update miniquests displayed  
        VEQ.DisplayFocusedMiniQuest()
    end 
   
     if Status == SKYSHARD_DISCOVERY_STATUS_ACQUIRED then
         acquired = acquired + 1
     end
  end
  
     if acquired ~= numSkyshards then
       local icon = zo_iconFormatInheritColor("esoui/art/tutorial/gamepad/achievement_categoryicon_skyshards.dds", 24, 24)
       if VEQ.skyshardCompletionMessage ~= string.format("%s%s/%s", icon, acquired, numSkyshards) then 
          VEQ.skyshardCompletionMessage = string.format("%s%s/%s", icon, acquired, numSkyshards)
          VEQ.updatePerZoneDisplay()
       end
     elseif VEQ.skyshardCompletionMessage ~= "" then
         VEQ.skyshardCompletionMessage = ""
         VEQ.updatePerZoneDisplay()
         VEQ.skyshardCompletionFullForThatZone = ZoneId
     else
         VEQ.skyshardCompletionFullForThatZone = ZoneId
     end
end


function VEQ.CheckRidingSkillTimer()

  if not IsPlayerActivated() then return end
 
  -- create table if it doesn't exist
  VEQ.MiniQuestList = VEQ.MiniQuestList or {}
 
  EVENT_MANAGER:UnregisterForUpdate("CheckRidingSkillTimer")
     
  if GetRidingStats() == nil then return end

  local capacityBonus, maxCapacityBonus, staminaBonus, maxStaminaBonus, speedBonus, maxSpeedBonus = GetRidingStats()

  if (capacityBonus + staminaBonus + speedBonus) == (maxCapacityBonus + maxStaminaBonus + maxSpeedBonus) or VEQ.SavedVars.Stable == false then 
      if VEQ.MiniQuestList[5] then VEQ.MiniQuestList[5] = nil end
         if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
       VEQ.DisplayFocusedMiniQuest()
     return
  else
  
     local nextCheck,_ = GetTimeUntilCanBeTrained()
  
     nextCheck = math.floor(nextCheck/2)
     if nextCheck ~= 0 and nextCheck < 1000 then nextCheck = 1000 end
   
   local currentCheckTime,_ = GetTimeUntilCanBeTrained()
  
     if currentCheckTime == 0 then 
       if GetCurrentMoney() >= GetTrainingCost() then
        if not VEQ.MiniQuestList[5] then
           VEQ.LoadMiniQuestsInfo(5, 5, VEQ.mylanguage.lang_stable_rel, VEQ.mylanguage.lang_upgrade_skills, VEQ.mylanguage.lang_stablemaster, "esoui/art/icons/servicemappins/servicepin_stable.dds")
         VEQ.DisplayFocusedMiniQuest()
         return
      end
            return      
     else 
         if VEQ.MiniQuestList[5] then VEQ.MiniQuestList[5] = nil end
       if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
           VEQ.DisplayFocusedMiniQuest()
     end
   else 
       if VEQ.MiniQuestList[5] then VEQ.MiniQuestList[5] = nil end
     if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
       VEQ.DisplayFocusedMiniQuest()
   end
   end
  
   if VEQ.SavedVars.Stable then EVENT_MANAGER:RegisterForUpdate("CheckRidingSkillTimer", nextCheck, function() VEQ.CheckRidingSkillTimer() end) end
end


function VEQ.CheckDungeonRewardTimer()

  if not IsPlayerActivated() then return end
 
  -- create table if it doesn't exist
  VEQ.MiniQuestList = VEQ.MiniQuestList or {}
 
  EVENT_MANAGER:UnregisterForUpdate("CheckDungeonRewardTimer")
     
  if GetLFGCooldownTimeRemainingSeconds(LFG_COOLDOWN_DUNGEON_REWARD_GRANTED) == nil then return end


  if VEQ.SavedVars.DungeonRewardTimer == false or GetUnitLevel("player") < 10 then 
      VEQ.DungeonRewardAvailable = false
      VEQ.CheckRepeatableLimit("dr")
      -- if VEQ.MiniQuestList[18] then VEQ.MiniQuestList[18] = nil end
         -- if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
       -- VEQ.DisplayFocusedMiniQuest()
     return
  else
  
     local remaining = GetLFGCooldownTimeRemainingSeconds(LFG_COOLDOWN_DUNGEON_REWARD_GRANTED)*1000 
     local nextCheck = remaining
  
     nextCheck = math.floor(nextCheck/2)
     if nextCheck ~= 0 and nextCheck < 1000 then nextCheck = 1000 end
  
     if remaining == 0 then 
     if not VEQ.DungeonRewardAvailable then 
        VEQ.DungeonRewardAvailable = true
      
            VEQ.CheckRepeatableLimit("dr")
        return
     end
     return     
   else 
        VEQ.DungeonRewardAvailable = false
          VEQ.CheckRepeatableLimit("dr")
   end
   end
  
   if VEQ.SavedVars.DungeonRewardTimer and GetUnitLevel("player") > 9 then EVENT_MANAGER:RegisterForUpdate("CheckDungeonRewardTimer", nextCheck, function() VEQ.CheckDungeonRewardTimer() end) end
end


function VEQ.CheckBattlegroundRewardTimer()

     if not IsPlayerActivated() then return end
     
     -- create table if it doesn't exist
     VEQ.MiniQuestList = VEQ.MiniQuestList or {}
     
     EVENT_MANAGER:UnregisterForUpdate("CheckBattlegroundRewardTimer")



  if VEQ.SavedVars.BattlegroundRewardTimer == false or GetUnitLevel("player") < 10 then 
      VEQ.BattleGroundRewardAvailable = false
      VEQ.CheckRepeatableLimit("bgr")
     return
  else
  
     local remaining = GetLFGCooldownTimeRemainingSeconds(LFG_COOLDOWN_BATTLEGROUND_REWARD_GRANTED)*1000 
     local nextCheck = remaining
  
     nextCheck = math.floor(nextCheck/2)
     if nextCheck ~= 0 and nextCheck < 1000 then nextCheck = 1000 end
  
     if remaining == 0 then 
     if not VEQ.BattleGroundRewardAvailable then 
        VEQ.BattleGroundRewardAvailable = true
            VEQ.CheckRepeatableLimit("bgr")
        return
     end
     return     
   else 
       VEQ.BattleGroundRewardAvailable = false
         VEQ.CheckRepeatableLimit("bgr")
   end
   end
  
   if VEQ.SavedVars.BattlegroundRewardTimer and GetUnitLevel("player") > 9 then EVENT_MANAGER:RegisterForUpdate("CheckBattlegroundRewardTimer", nextCheck, function() VEQ.CheckBattlegroundRewardTimer() end) end
end


function VEQ.CheckTributeRewardTimer()

     if not IsPlayerActivated() then return end
     
     -- create table if it doesn't exist
     VEQ.MiniQuestList = VEQ.MiniQuestList or {}
     
     EVENT_MANAGER:UnregisterForUpdate("CheckTributeRewardTimer")
     
  if GetLFGCooldownTimeRemainingSeconds(LFG_COOLDOWN_TRIBUTE_REWARD_GRANTED) == nil then return end


  if VEQ.SavedVars.TributeRewardTimer == false or not IsAchievementComplete(3318)then 
      VEQ.TotRewardAvailable = false
      VEQ.CheckRepeatableLimit("tot")
     return
  else
  
     local remaining = GetLFGCooldownTimeRemainingSeconds(LFG_COOLDOWN_TRIBUTE_REWARD_GRANTED)*1000 
     local nextCheck = remaining
  
     nextCheck = math.floor(nextCheck/2)
     if nextCheck ~= 0 and nextCheck < 1000 then nextCheck = 1000 end
  
     if remaining == 0 then 
     if not VEQ.TotRewardAvailable then 
        VEQ.TotRewardAvailable = true
            VEQ.CheckRepeatableLimit("tot")
        return
     end
     return     
   else 
         VEQ.TotRewardAvailable = false
         VEQ.CheckRepeatableLimit("tot")
   end
   end
  
  if VEQ.SavedVars.TributeRewardTimer and IsAchievementComplete(3318) then EVENT_MANAGER:RegisterForUpdate("CheckTributeRewardTimer", nextCheck, function() VEQ.CheckTributeRewardTimer() end) end
end

function VEQ.delayedCheckTributeRewardTimer()
    if VEQ.TotRewardAvailable then
        zo_callLater(function() VEQ.CheckTributeRewardTimer() end, 2000)
    end 
end

function VEQ.delayedCheckBattlegroundRewardTimer()
       if VEQ.BattleGroundRewardAvailable then
           zo_callLater(function() VEQ.CheckBattlegroundRewardTimer() end, 2000)
     end 
end

function VEQ.delayedCheckDungeonRewardTimer()
    if VEQ.DungeonRewardAvailable then
       zo_callLater(function() VEQ.CheckDungeonRewardTimer() end, 2000)
  end
end

function VEQ.CheckBackpackBankUpgrade()
  if not IsPlayerActivated() then return end
    
  -- create table if it doesn't exist
  VEQ.MiniQuestList = VEQ.MiniQuestList or {}

  if GetNextBackpackUpgradePrice() == 0 or GetCurrentMoney() < GetNextBackpackUpgradePrice() or not VEQ.SavedVars.Backbank then
     if VEQ.MiniQuestList[6] then VEQ.MiniQuestList[6] = nil end
     if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
     VEQ.DisplayFocusedMiniQuest()
  elseif not VEQ.MiniQuestList[6] then  
     VEQ.LoadMiniQuestsInfo(6, 6, VEQ.mylanguage.lang_backpack_upgrade, string.format("%s%s%s", VEQ.mylanguage.lang_you_have_the, GetNextBackpackUpgradePrice(), VEQ.mylanguage.lang_up_back) , VEQ.mylanguage.lang_pack_merchant, "esoui/art/icons/servicetooltipicons/gamepad/gp_servicetooltipicon_bagvendor.dds") 
     VEQ.DisplayFocusedMiniQuest()
  end


  if GetNextBankUpgradePrice() == 0 or GetCurrentMoney() < GetNextBankUpgradePrice() or not VEQ.SavedVars.Backbank then
     if VEQ.MiniQuestList[7] then VEQ.MiniQuestList[7] = nil end
     if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
     VEQ.DisplayFocusedMiniQuest()
  elseif not VEQ.MiniQuestList[7] then
     VEQ.LoadMiniQuestsInfo(7, 7, VEQ.mylanguage.lang_bank_space_upgrade, string.format("%s%s%s", VEQ.mylanguage.lang_you_have_the, GetNextBankUpgradePrice(), VEQ.mylanguage.lang_up_bank), VEQ.mylanguage.lang_bank_mon, "esoui/art/icons/servicetooltipicons/gamepad/gp_servicetooltipicon_banker.dds")
     VEQ.DisplayFocusedMiniQuest()
  end
end


function VEQ.ResetTamrielTomes()
        --if not IsPlayerActivated() then return end
      
    -- create table if it doesn't exist
    VEQ.MiniQuestList = VEQ.MiniQuestList or {}
     
    -- erase all 
    if VEQ.MiniQuestList["DailyTamrielTomes"] then VEQ.MiniQuestList["DailyTamrielTomes"] = nil end
    if VEQ.MiniQuestList["WeeklyTamrielTomes"] then VEQ.MiniQuestList["WeeklyTamrielTomes"] = nil end
    if VEQ.MiniQuestList["QuarterlyTamrielTomes"] then VEQ.MiniQuestList["QuarterlyTamrielTomes"] = nil end
    
    -- update table length
        if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
    -- update miniquests displayed  
        VEQ.DisplayFocusedMiniQuest()
    
    VEQ.CheckTamrielTomes()
end

function VEQ.formatThousand(v)
    local s = tostring(v)
    while true do  
        s, k = string.gsub(s, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k == 0) then break end
    end
    return s
end

function VEQ.CheckTamrielTomes()

     --if not IsPlayerActivated() then return end
      
     -- create table if it doesn't exist
     VEQ.MiniQuestList = VEQ.MiniQuestList or {}
     

     if (not VEQ.SavedVars.TamrielTomes) or (not IsTimedActivitySystemAvailable()) then
        VEQ.RemoveTheseMiniQuestsByIndex(8) 
        return
     end
     
     
     local numActivities = GetNumTimedActivities() or 0
     
     if numActivities > 0 then
        local dailyTitle = ""
        local dailyText = {} 
        local weeklyTitle = ""
        local weeklyText = {}
        local quarterlyTitle = ""
        local quarterlyText = {}

        local dailiesDone = 0 
        local weekliesDone = 0  
        local quarterliesDone = 0 
        
        local dailiesMax = 0 
        local weekliesMax = 0  
        local quarterliesMax = 0 
        
        local dailyTimeLimit = 0
        local weeklyTimeLimit = 0
        local quarterlyTimeLimit = 0
        
        local rerollsIcon = GetCurrencyKeyboardIcon(CURT_TOME_CHALLENGE_REROLLS)
        local rerollsAmount = GetPlayerStoredCurrencyAmount(CURT_TOME_CHALLENGE_REROLLS) 
        local RRIcon = string.format(" - %s|t24:24:%s|t", rerollsAmount, rerollsIcon)
        
        local tomePointsIcon = GetCurrencyKeyboardIcon(CURT_TOME_POINTS)
        local tomePointsAmount = GetPlayerStoredCurrencyAmount(CURT_TOME_POINTS) 
        local TPIcon = string.format(" - %s|t18:18:%s|t", tomePointsAmount, tomePointsIcon)
 
        if rerollsAmount == 0 then
            RRIcon = ""
        end
        
        local tomeId = TAMRIEL_TOMES_MANAGER:GetSelectedTomeId()
        local tomeData = ZO_TamrielTomeData:New(tomeId)
        
        local nextTier = 1--tomeData:GetNextTier()
        local cost = tomeData:GetCostToProgressToTier(nextTier)
        
        while cost == 0 and nextTier < tomeData:GetNumTotalTiers() do
            nextTier = nextTier + 1
            cost = tomeData:GetCostToProgressToTier(nextTier)
        end 
        
        if nextTier == tomeData:GetNumTotalTiers() and RRIcon ~= "" then
            RRIcon = string.format("%s|t24:24:%s|t", rerollsAmount, rerollsIcon)
        end
        
        local unlockPointsRemaining = string.format(" %s|t18:18:%s|t", cost, tomePointsIcon)
        local unlockIcon = "|t16:16:/esoui/art/miscellaneous/unlocked_down.dds|t"
        if nextTier > 1 and cost > 0 then
           RRIcon = string.format("%s%s %s%s", unlockIcon, zo_strformat(SI_GAMEPAD_GUILD_HISTORY_PAGE_NUMBER, nextTier), zo_strformat(SI_ORBIS_PRESENCE_LOCATION, unlockPointsRemaining), RRIcon)
        end   
        
        -- GetTomePointGainBonusPercentage()
        
        for index = 1, numActivities do
               
            local ActivityType = string.format("%s %s", GetString(SI_QUESTREPEATABLETYPE5), GetString(SI_GAMEPAD_TAMRIEL_TOMES_CHALLENGES))
            local counter = GetTimedActivityMaxProgress(index) - GetTimedActivityProgress(index)
            local numRewards = GetNumTimedActivityRewards(index)
            local activityName = GetTimedActivityName(index)
            
            if string.find(activityName, GetTimedActivityMaxProgress(index)) then
                 activityName = activityName:gsub(GetTimedActivityMaxProgress(index), counter)
            else
                activityName = activityName:gsub(VEQ.formatThousand(GetTimedActivityMaxProgress(index)), counter)
            end
            
            local trackedIndex, _ = GetTrackedTimedActivityInfo()
            
            if index == trackedIndex then
               activityName = string.format("|cd4af37%s|r", activityName)
            end
            
            local rewardText = {}
            for rewardIndex = 1, numRewards do
               local rewardId, Quantity = GetTimedActivityRewardInfo(index, rewardIndex)
               local rewardData = REWARDS_MANAGER:GetInfoForReward(rewardId, Quantity)
               local icon = rewardData:GetKeyboardIcon()

               if Quantity >= 1000 then
                  Quantity = string.format("%sk", (Quantity/1000))
               end
                
               local textIcon = string.format("|t18:18:%s|t", icon)
               table.insert(rewardText,string.format(" %s%s", Quantity, textIcon))
            end
            
            rewardText = table.concat(rewardText)
            
            local claimsLeft = GetTimedActivityTotalNumTimesClaimable(index) - GetTimedActivityNumTimesClaimed(index)
            if claimsLeft < 2 then
               claimsLeft = ""
            else
                claimsLeft = string.format(" x%s", claimsLeft)
            end
            
            if GetTimedActivityType(index) == TIMED_ACTIVITY_TYPE_DAILY then -- is daily Tamriel tomes
                   dailiesMax = dailiesMax + 1
                   dailyTimeLimit = GetTimedActivityTypeResetTimeS(TIMED_ACTIVITY_TYPE_DAILY)
                   ActivityType = string.format("%s %s", GetString(SI_TIMEDACTIVITYTYPE0), GetString(SI_GAMEPAD_TAMRIEL_TOMES_CHALLENGES))
                   if GetTimedActivityProgress(index) < GetTimedActivityMaxProgress(index) and GetTimedActivityNumTimesClaimed(index) < GetTimedActivityTotalNumTimesClaimable(index) then
                       dailyTitle = string.format("%s %s/%s", ActivityType, dailiesDone, dailiesMax)
                       if NonContiguousCount(dailyText) == 0 and RRIcon ~= "" then 
                           table.insert(dailyText, string.format("%s\n", RRIcon))
                       end
                       table.insert(dailyText, string.format("%s%s%s%s\n", zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), activityName, rewardText, claimsLeft))
                   else
                       dailiesDone = dailiesDone + 1
                       dailyTitle = string.format("%s %s/%s", ActivityType, dailiesDone, dailiesMax)
                       if GetTimedActivityNumTimesClaimed(index) < GetTimedActivityTotalNumTimesClaimable(index) then
                          ClaimTimedActivityReward(index)
                       end
                   end
            elseif GetTimedActivityType(index) == TIMED_ACTIVITY_TYPE_WEEKLY then  -- is weekly Tamriel Tomes
               weekliesMax = weekliesMax + 1
               weeklyTimeLimit = GetTimedActivityTypeResetTimeS(TIMED_ACTIVITY_TYPE_WEEKLY) 
               ActivityType = string.format("%s %s", GetString(SI_TIMEDACTIVITYTYPE1), GetString(SI_GAMEPAD_TAMRIEL_TOMES_CHALLENGES))
               if GetTimedActivityProgress(index) < GetTimedActivityMaxProgress(index) and GetTimedActivityNumTimesClaimed(index) < GetTimedActivityTotalNumTimesClaimable(index) then
                   weeklyTitle = string.format("%s %s/%s", ActivityType, weekliesDone, weekliesMax)
                   if NonContiguousCount(weeklyText) == 0 and RRIcon ~= "" then
                       table.insert(weeklyText, string.format("%s\n", RRIcon))
                   end
                   table.insert(weeklyText, string.format("%s%s%s%s\n", zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), activityName, rewardText, claimsLeft))
               else
                   weekliesDone = weekliesDone + 1
                   weeklyTitle = string.format("%s %s/%s", ActivityType, weekliesDone, weekliesMax)
                   if GetTimedActivityNumTimesClaimed(index) < GetTimedActivityTotalNumTimesClaimable(index) then
                     ClaimTimedActivityReward(index)
                   end
               end
               
            else -- quarterly (season) Tamriel Tomes
               quarterliesMax = quarterliesMax + 1
               quarterlyTimeLimit = GetTimedActivityTypeResetTimeS(TIMED_ACTIVITY_TYPE_SEASONAL)
               ActivityType = string.format("%s %s", GetString(SI_TIMEDACTIVITYTYPE2), GetString(SI_GAMEPAD_TAMRIEL_TOMES_CHALLENGES))
               if GetTimedActivityProgress(index) < GetTimedActivityMaxProgress(index) and GetTimedActivityNumTimesClaimed(index) < GetTimedActivityTotalNumTimesClaimable(index) then
                    quarterlyTitle = string.format("%s %s/%s", ActivityType, quarterliesDone, quarterliesMax)
                    if NonContiguousCount(quarterlyText) == 0 and RRIcon ~= "" then
                       table.insert(quarterlyText, string.format("%s\n", RRIcon))
                    end
                    table.insert(quarterlyText, string.format("%s%s%s%s\n", zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), activityName, rewardText, claimsLeft))
               else
                    quarterliesDone = quarterliesDone + 1
                    quarterlyTitle = string.format("%s %s/%s", ActivityType, quarterliesDone, quarterliesMax)
                    if GetTimedActivityNumTimesClaimed(index) < GetTimedActivityTotalNumTimesClaimable(index) then
                      ClaimTimedActivityReward(index)
                    end
               end
            end
        end -- end of big for loop
        
        dailyText = table.concat(dailyText)
        weeklyText = table.concat(weeklyText)
        quarterlyText = table.concat(quarterlyText)
       
        -- daily Tamriel Tomes
        if dailiesDone < dailiesMax and dailyTitle ~= "" and dailyText ~= "" then
            local timeLeft = ZO_FormatTimeMilliseconds(((dailyTimeLimit-GetTimeStamp())*1000), TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR)
            VEQ.LoadMiniQuestsInfo(8, "DailyTamrielTomes" , string.format("%s%s", dailyTitle, TPIcon), dailyText, string.format("%s %s", GetString(SI_GAMEPAD_TAMRIEL_TOMES_CHALLENGES), timeLeft), "esoui/art/menubar/gamepad/gp_playermenu_icon_tamrieltomes.dds", nil, nil, nil, nil, dailyTimeLimit)
            VEQ.DisplayFocusedMiniQuest()
        else
            if VEQ.MiniQuestList["DailyTamrielTomes"] then VEQ.MiniQuestList["DailyTamrielTomes"] = nil end
            if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
               VEQ.DisplayFocusedMiniQuest()
            end  
        
         -- weekly Tamriel Tomes
        if weekliesDone < weekliesMax and weeklyTitle ~= "" and weeklyText ~= "" then 
           local timeLeft = ZO_FormatTimeMilliseconds(((weeklyTimeLimit-GetTimeStamp())*1000), TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR)
           VEQ.LoadMiniQuestsInfo(8, "WeeklyTamrielTomes" , string.format("%s%s", weeklyTitle, TPIcon), weeklyText, string.format("%s %s", GetString(SI_GAMEPAD_TAMRIEL_TOMES_CHALLENGES), timeLeft), "esoui/art/menubar/gamepad/gp_playermenu_icon_tamrieltomes.dds", nil, nil, nil, nil, weeklyTimeLimit)
           VEQ.DisplayFocusedMiniQuest()
        else
          if VEQ.MiniQuestList["WeeklyTamrielTomes"] then VEQ.MiniQuestList["WeeklyTamrielTomes"] = nil end
          if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
          VEQ.DisplayFocusedMiniQuest()
        end
        
         -- quarterly Tamriel Tomes
        if quarterliesDone < quarterliesMax and quarterlyTitle ~= "" and quarterlyText ~= "" then 
           local timeLeft = ZO_FormatTimeMilliseconds(((quarterlyTimeLimit-GetTimeStamp())*1000), TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR)
           VEQ.LoadMiniQuestsInfo(8, "QuarterlyTamrielTomes" , string.format("%s%s", quarterlyTitle, TPIcon), quarterlyText, string.format("%s %s", GetString(SI_GAMEPAD_TAMRIEL_TOMES_CHALLENGES), timeLeft), "esoui/art/menubar/gamepad/gp_playermenu_icon_tamrieltomes.dds", nil, nil, nil, nil, quarterlyTimeLimit)
           VEQ.DisplayFocusedMiniQuest()
        else
          if VEQ.MiniQuestList["QuarterlyTamrielTomes"] then VEQ.MiniQuestList["QuarterlyTamrielTomes"] = nil end
          if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
          VEQ.DisplayFocusedMiniQuest()
        end 
        
     end

end

function VEQ.RandomZoneDaily()

      local dailyZones = {
                          888,   -- Craglorn
                1086,  -- Northern Elsweyr
                684,   -- Wrothgar
                823,   -- Gold Coast
                849,   -- Vvardenfell
                980,   -- Clockwork City
                1011,  -- Summerset
                726,   -- Murkmire
                1133,  -- Southern Elsweyr
                1160,  -- Western Skyrim
                1207,  -- The Reach
                1261,  -- Blackwood
                1283,  -- Fargrave / The Deadlands
                1318,  -- High Isle
                1383,  -- Galen 
                1414,  -- Telvanni Peninsula
                1443,  -- West Weald
                976,   -- Infinite Archive
                181,   -- Cyrodiil
                         }

      local randomZoneId = dailyZones[math.random(#dailyZones)]
      
      local zoneName = VEQ.KillTheRubbish(GetZoneNameById(randomZoneId)) 
      
      if randomZoneId == 976 then -- infinite archive
         zoneName = GetString(SI_ZONEDISPLAYTYPE12)
      elseif randomZoneId == 1283 then -- fargrave
          zoneName = VEQ.KillTheRubbish(GetMapNameById(2119))
      elseif randomZoneId == 181 then -- Cyrodiil 
          local settlementSubZoneIds = {  -- unusable via the API :-/
                     2118,  -- Vlastarus
                     11185, -- Bruma
                     2133,  -- Cropsford
                     2656,  -- Cheydinhal
                     1161,  -- Chorrol
                     1160,  -- Weynon Priory
                                }
        zoneName = string.format("%s %s", VEQ.KillTheRubbish(GetZoneNameById(randomZoneId)), GetString(SI_HOUSETOURLISTINGTAG26))
      end
      
      if IsZoneCollectibleLocked(GetZoneIndex(randomZoneId)) then 
        VEQ.RandomZoneDaily()
      else
          VEQ.ZoneDaily = string.format("%s %s %s %s", GetString(SI_GAMEPAD_QUEST_JOURNAL_QUEST_OR_DESCRIPTION), zoneName, GetString(SI_QUESTREPEATABLETYPE2), GetString(SI_ITEMFILTERTYPE7))
          VEQ.CheckRepeatableLimit("zoneDaily")
      end 
end







function VEQ.CheckRepeatableLimit(message)

     if not IsPlayerActivated() then return end
      
     -- create table if it doesn't exist
     VEQ.MiniQuestList = VEQ.MiniQuestList or {}
     
     if not VEQ.SavedVars.DailiesCounter then
      if VEQ.MiniQuestList[17] then VEQ.MiniQuestList[17] = nil end
      -- update table length
            if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
        -- update miniquests displayed  
            VEQ.DisplayFocusedMiniQuest()
        return
     end
     
     local ongoingRepeatables = 0
         
         
     for i=1, MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(i) then
      
          local qRepeatType = GetJournalQuestRepeatType(i)
          local complete = GetJournalQuestIsComplete(i)

          if qRepeatType and qRepeatType == QUEST_REPEAT_DAILY then
             if not complete then
                 ongoingRepeatables = ongoingRepeatables + 1 
             end
          end 
        end
       end

     
     VEQ.previousOngoing = VEQ.previousOngoing or ongoingRepeatables
     
     if message == "startup" or message == "removed" or message == "added" then 
        VEQ.previousOngoing = ongoingRepeatables 
        zo_callLater(function() VEQ.QuestsListUpdate(1) end ,1000) -- test 27/04/2023
     elseif message == "complete" and VEQ.previousOngoing > ongoingRepeatables then 
        VEQ.CharSavedVars.DailyCounter = VEQ.CharSavedVars.DailyCounter + 1
        VEQ.CharSavedVars.LastDailyResetTime = GetTimeStamp() + GetTimeUntilNextDailyLoginRewardClaimS()
        VEQ.ZoneDaily = nil
     end 
     
     local repeatIcon = "|t24:24:esoui/art/journal/journal_quest_repeat.dds|t"
         
     local dungeonRewardMessage = ""
         if VEQ.DungeonRewardAvailable then 
          local icon = "|t24:24:esoui/art/icons/poi/poi_groupinstance_complete.dds|t"
          dungeonRewardMessage = string.format("\n%s%s %s", icon, GetString(SI_DUNGEON_FINDER_RANDOM_FILTER_TEXT), GetString(SI_NOTIFICATIONTYPE21))
         end
     
         local bgRewardMessage = ""
         if VEQ.BattleGroundRewardAvailable then
         local icon = "|t24:24:esoui/art/icons/poi/poi_group_battleground_complete.dds|t"
         bgRewardMessage = string.format("\n%s%s %s", icon, GetString(SI_BATTLEGROUND_FINDER_RANDOM_FILTER_TEXT), GetString(SI_NOTIFICATIONTYPE21))
         end
     
     local totRewardMessage = ""
         if VEQ.TotRewardAvailable then
         local icon = "|t24:24:esoui/art/icons/servicemappins/servicepin_talesoftribute.dds|t"
         totRewardMessage = string.format("\n%s%s %s", icon, GetString(SI_TRIBUTE_FINDER_GENERAL_ACTIVITY_DESCRIPTOR), GetString(SI_NOTIFICATIONTYPE21))
         end
     
     local shaMessage = ""
     if VEQ.ShadowySuppliersAvailable then 
         local icon = "|t24:24:esoui/art/icons/mapkey/mapkey_darkbrotherhood.dds|t"
         shaMessage = string.format("\n%s%s", icon,VEQ.mylanguage.lang_remains_silent)
     end
     
     local dcMessage = ""
     if VEQ.SavedVars.DragonguardSupplyChestAvailable then 
         local icon = "|t20:20:VEQ/art/icons/DragonGuard.dds|t"
         dcMessage = string.format("\n%s %s %s", icon, GetAchievementName(2612), GetString(SI_NOTIFICATIONTYPE21))
     end
     
     local soloTrialMessage = "" 
     if VEQ.WeeklySoloTrialAvailable ~= nil then
        local icon = "|t20:20:esoui/art/icons/poi/poi_solotrial_complete.dds|t"
        soloTrialMessage = string.format("\n%s %s %s %s", icon, VEQ.WeeklySoloTrialAvailable, GetString(SI_QUESTREPEATABLETYPE5), GetString(SI_LEVEL_UP_REWARDS_GAMEPAD_REWARD_SECTION_HEADER_SINGULAR))
     end
     
     local groupTrialMessage = "" 
     if VEQ.WeeklyGroupTrialAvailable ~= nil then
        local icon = "|t20:20:esoui/art/icons/poi/poi_raiddungeon_complete.dds|t"
        groupTrialMessage = string.format("\n%s %s %s %s", icon, VEQ.WeeklyGroupTrialAvailable, GetString(SI_QUESTREPEATABLETYPE5), GetString(SI_LEVEL_UP_REWARDS_GAMEPAD_REWARD_SECTION_HEADER_SINGULAR))
     end
     
     local zoneDailyMessage = ""
     if VEQ.ZoneDaily ~= nil then
        local icon = "|t24:24:esoui/art/journal/journal_quest_repeat.dds|t"
        zoneDailyMessage = string.format("\n%s %s", icon, VEQ.ZoneDaily)
     end
     
     VEQ.AvailableFavors = VEQ.AvailableFavors or {}
     local favorRewardMessage = ""
     local favorIcon = "|t24:24:esoui/art/journal/gamepad/gp_questtypeicon_repeatable_favor.dds|t"
     for questName, available in pairs(VEQ.AvailableFavors) do
         if available then
            favorRewardMessage = favorRewardMessage..string.format("\n%s %s", favorIcon, questName)
         end
     end

     VEQ.LoadMiniQuestsInfo(17, 17, string.format("%s %s", VEQ.KillTheRubbish(GetString(SI_QUESTREPEATABLETYPE2)), VEQ.KillTheRubbish(GetString(SI_CRAFT_ADVISOR_WRITS_TITLE))), string.format("%s%s%s\n%s%s%s/100%s%s%s%s%s%s%s%s%s", repeatIcon, VEQ.mylanguage.lang_ongoing, ongoingRepeatables, repeatIcon, VEQ.mylanguage.lang_completed_today, VEQ.CharSavedVars.DailyCounter, favorRewardMessage, dungeonRewardMessage, bgRewardMessage, totRewardMessage, shaMessage, dcMessage, soloTrialMessage, groupTrialMessage, zoneDailyMessage), VEQ.mylanguage.lang_Miscellaneous, "esoui/art/journal/journal_quest_repeat.dds")
     VEQ.DisplayFocusedMiniQuest()
end

function VEQ.checkResetTime() -- Check daily reset time

  if not IsPlayerActivated() then return end
    
    -- create table if it doesn't exist
   VEQ.MiniQuestList = VEQ.MiniQuestList or {}
   
   EVENT_MANAGER:UnregisterForUpdate("CheckResetTime")
   
  if not VEQ.SavedVars.DailiesCounter then
    if VEQ.MiniQuestList[17] then VEQ.MiniQuestList[17] = nil end
    -- update table length
    if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
    -- update miniquests displayed  
    VEQ.DisplayFocusedMiniQuest()
    return
  end
  
  local timeStamp = GetTimeStamp()

  
  VEQ.CharSavedVars.LastDailyResetTime = VEQ.CharSavedVars.LastDailyResetTime or 0
  VEQ.SavedVars.LastDragonguardSupplyChestResetTime = VEQ.SavedVars.LastDragonguardSupplyChestResetTime or 0
  VEQ.CharSavedVars.LastFavorResetTime = VEQ.CharSavedVars.LastFavorResetTime or {}
  
  if timeStamp > VEQ.CharSavedVars.LastDailyResetTime then
    if VEQ.CharSavedVars.DailyCounter ~= 0 then
       VEQ.CharSavedVars.DailyCounter = 0
       VEQ.CheckRepeatableLimit("startup")
    end
  end
  
  if timeStamp > VEQ.SavedVars.LastDragonguardSupplyChestResetTime then
    if VEQ.SavedVars.DragonguardSupplyChest and IsAchievementComplete(2612) then
        VEQ.SavedVars.DragonguardSupplyChestAvailable = true
        VEQ.CheckRepeatableLimit("dgsc")
    else
        VEQ.SavedVars.DragonguardSupplyChestAvailable = false
        VEQ.CheckRepeatableLimit("dgsc")
    end
  end 
  
  -- favors timers
  local favorChange
  for questName, time in pairs(VEQ.CharSavedVars.LastFavorResetTime) do 
      if timeStamp > time then
         if VEQ.SavedVars.Favors then
             VEQ.AvailableFavors = VEQ.AvailableFavors or {}
             VEQ.AvailableFavors[questName] = true
             favorChange = true
         else
             VEQ.AvailableFavors = VEQ.AvailableFavors or {}
             VEQ.AvailableFavors[questName] = false
             favorChange = true
         end
      end
  end
  if favorChange then
     VEQ.CheckRepeatableLimit("favors")
  end
   
  
  
  if not VEQ.MiniQuestList[17] then 
     VEQ.CheckRepeatableLimit("startup")
  end
  
  local secondsLeft = GetTimeUntilNextDailyLoginRewardClaimS()
  local nextCheck = math.floor(secondsLeft/2*1000)
  if nextCheck <= 1000 then 
      VEQ.CharSavedVars.DailyCounter = 0
    VEQ.CheckRepeatableLimit("startup")
      nextCheck = 1000 
  end
  
  if VEQ.previousOngoing and VEQ.previousOngoing == 0 then
     VEQ.RandomZoneDaily()
  end   

  
  EVENT_MANAGER:RegisterForUpdate("CheckResetTime", nextCheck, function() VEQ.checkResetTime() end)
  
end


function VEQ.RaidOfTheWeek() 
    if not IsPlayerActivated() then return end

    
  local _, soloComplete = GetPlayerRaidOfTheWeekProgressInfo(RAID_CATEGORY_CHALLENGE)
  local _, groupComplete = GetPlayerRaidOfTheWeekProgressInfo(RAID_CATEGORY_TRIAL)
  local soloName,_ = GetRaidOfTheWeekLeaderboardInfo(RAID_CATEGORY_CHALLENGE)
  local groupName,_ = GetRaidOfTheWeekLeaderboardInfo(RAID_CATEGORY_TRIAL)
  
  if soloComplete then
       VEQ.WeeklySoloTrialAvailable = nil 
  elseif soloName and soloName ~= "" then
       VEQ.WeeklySoloTrialAvailable = soloName
  end
  
  if groupComplete then
       VEQ.WeeklyGroupTrialAvailable = nil 
  elseif groupName and groupName ~= "" then
       VEQ.WeeklyGroupTrialAvailable = groupName
  end
  
  VEQ.CheckRepeatableLimit("rotw")
end


function VEQ.CheckCurrencies()

     if not IsPlayerActivated() then return end  

     -- create table if it doesn't exist
     VEQ.MiniQuestList = VEQ.MiniQuestList or {}

       local maxTickets = GetMaxPossibleCurrency(CURT_EVENT_TICKETS,CURRENCY_LOCATION_ACCOUNT)
     local maxTransmute = GetMaxPossibleCurrency(CURT_CHAOTIC_CREATIA,CURRENCY_LOCATION_ACCOUNT)
     
     local numTickets =  GetCurrencyAmount(CURT_EVENT_TICKETS,CURRENCY_LOCATION_ACCOUNT)
     local numTransmute =  GetCurrencyAmount(CURT_CHAOTIC_CREATIA,CURRENCY_LOCATION_ACCOUNT)
     
     VEQ.numTransmute = VEQ.numTransmute or 0
     VEQ.maxTransmute = VEQ.maxTransmute or 0
     VEQ.numTickets = VEQ.numTickets or 0
     VEQ.maxTickets = VEQ.maxTickets or 0
     
     local ticketChange = false
     if VEQ.numTickets ~= numTickets or VEQ.maxTickets ~= maxTickets then
         ticketChange = true
     end
     
     local transmuteChange = false
     if VEQ.numTransmute ~= numTransmute or VEQ.maxTransmute ~= maxTransmute then
         transmuteChange = true
     end
     
     
    
    -- Event Tickets
    if numTickets >= maxTickets and VEQ.SavedVars.Tickets then
    
      if ticketChange == true then
          VEQ.LoadMiniQuestsInfo(9, 9, VEQ.mylanguage.lang_event_tickets, VEQ.mylanguage.lang_maxed_out_currency, VEQ.mylanguage.lang_Miscellaneous, "esoui/art/currency/gamepad/gp_eventticket.dds")
          VEQ.DisplayFocusedMiniQuest()
      end 
      
    elseif maxTickets - numTickets <= VEQ.SavedVars.TicketsLimit and VEQ.SavedVars.Tickets then 
    
      if ticketChange == true then    
         VEQ.LoadMiniQuestsInfo(9, 9, string.format("%s %s/%s", VEQ.mylanguage.lang_event_tickets, numTickets, maxTickets), VEQ.mylanguage.lang_nears_max_currency, VEQ.mylanguage.lang_Miscellaneous, "esoui/art/currency/gamepad/gp_eventticket.dds")
         VEQ.DisplayFocusedMiniQuest()
      end
      
    else
       if VEQ.MiniQuestList[9] then VEQ.MiniQuestList[9] = nil end
       if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
       VEQ.DisplayFocusedMiniQuest()

       end 
         VEQ.numTickets = numTickets
         VEQ.maxTickets = maxTickets
  
  
  
    -- Transmute Crystals
    if numTransmute >= maxTransmute and VEQ.SavedVars.Transmute then
      
       if transmuteChange == true then
          VEQ.LoadMiniQuestsInfo(10, 10, VEQ.mylanguage.lang_transmute_crystals, VEQ.mylanguage.lang_maxed_out_currency, VEQ.mylanguage.lang_Miscellaneous, "esoui/art/currency/gamepad/gp_seedcrystal_mipmap.dds")
              VEQ.DisplayFocusedMiniQuest()
       end    
    
    elseif maxTransmute - numTransmute <= VEQ.SavedVars.TransmuteLimit and VEQ.SavedVars.Transmute then 
      
      if transmuteChange == true then
          VEQ.LoadMiniQuestsInfo(10, 10,  string.format("%s %s/%s", VEQ.mylanguage.lang_transmute_crystals, numTransmute, maxTransmute), VEQ.mylanguage.lang_nears_max_currency, VEQ.mylanguage.lang_Miscellaneous, "esoui/art/currency/gamepad/gp_seedcrystal_mipmap.dds")
          VEQ.DisplayFocusedMiniQuest()
      end
  
    else
       if VEQ.MiniQuestList[10] then VEQ.MiniQuestList[10] = nil end
       if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
         VEQ.DisplayFocusedMiniQuest()
       end 
       VEQ.maxTransmute = maxTransmute
       VEQ.numTransmute = numTransmute

end


-- 04/07/2026 performance improvement:
-- This lookup table used to be declared *inside* VEQ.Fishing(), which meant Lua allocated
-- and populated this ~45-entry table from scratch every single time the function ran. The
-- table is a fixed zone-id -> achievement-id mapping that never changes at runtime, so there
-- is no reason to rebuild it on every call. Hoisting it to a file-scoped local means it is
-- built exactly once when the addon loads and simply read (never mutated) afterwards.
local VEQ_FishingZoneToAchievement = { -- that list is taken from Rare Fish Tracker ;-)
  -- Glenumbra
  [3] = 471,
  -- Stormhaven
  [19] = 472,
  -- Rivenspire
  [20] = 473,
  -- Stonefalls
  [41] = 477,
  -- Deshaan
  [57] = 478,
  -- Malabal Tor
  [58] = 486,
  -- Bangkorai
  [92] = 475,
  -- Eastmarch
  [101] = 480,
  -- Rift
  [103] = 481,
  -- Alik'r Desert
  [104] = 474,
  -- Greenshade
  [108] = 485,
  -- Shadowfen
  [117] = 479,
  -- Cyrodiil
  [181] = 489,
  -- Khenarthi's Roost
  [537] = 492,
  -- Bleakrock
  [280] = 493,
  -- Bal Foyen
  [281] = 493,
  -- Coldhabour
  [347] = 490,
  -- Auridon
  [381] = 483,
  -- Reaper's March
  [382] = 487,
  -- Grahtwood
  [383] = 484,
  -- Stros M'Kai
  [534] = 491,
  -- Betnikh
  [535] = 491,
  -- Carglorn
  [888] = 916,
  -- Imperial City
  [584] = 1186,
  -- Wrothgar
  [684] = 1340,
  -- Abahs Landing
  [816] = 1351,
  -- Gold Coast
  [823] = 1431,
  -- Vvardenfell
  [849] = 1882,
  -- Clockwork City
  [980] = 2027,
  [981] = 2027,
  -- Sommersend
  [1011] = 2191,
  [1027] = 2240,
  -- Murkmire
  [726] = 2295,
  [1072] = 2295,
  -- Northern Elsweyr
  [1086] = 2412,
  -- Southern Elsweyr
  [1133] = 2566,
  -- Western Skyrim
  [1160] = 2655,
  -- The Reach
  [1207] = 2861,
  -- Blackwood
  [1261] = 2981,
  -- Deathlands
  [1286] = 3144,
  -- High Isle
  [1318] = 3269,
  -- Galen
  [1383] = 3500,
  -- Aphcrypha
  [1413] = 3636,
  -- Telvani-Halbinsel
  [1414] = 3636,
  -- Westauen
  [1443] = 3948,
  -- Solstice
  [1502] = 4404 -- western 
  -- 4460 -- eastern
}

function VEQ.Fishing(itemId)
    local zoneId = ZO_ExplorationUtils_GetZoneStoryZoneIdForCurrentMap()
    local achievementId = VEQ_FishingZoneToAchievement[zoneId]
  
  if zoneId == 1502 then -- Eastern or Western Solstice? 
    local pointA = {["x"]=.466,["y"]=.270}
    local pointB = {["x"]=.666,["y"]=.793}
    local mapX, mapY = GetMapPlayerPosition("player")
    local dire = (mapX - pointA.x)*(pointB.y-pointA.y)-(mapY-pointA.y)*(pointB.x-pointA.x)
    
    if dire < 0 then 
        achievementId = 4404 -- Eastern Solstice 
    else
        achievementId = 4460 -- Western Solstice
    end
  end
  
  VEQ.FishingCounter = VEQ.FishingCounter or {}
  
  local achievementName, achievementDescription, achievementPoints, achievementIcon, achievementCompleted, achievementDate, achievementTime = GetAchievementInfo(achievementId)
  local numCriteria = GetAchievementNumCriteria(achievementId)
  
  --local numPerfectRoe = GetItemLinkInventoryCount("|H0:item:64222:370:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", INVENTORY_COUNT_BAG_OPTION_BACKPACK_AND_BANK_AND_CRAFT_BAG)
  local itemType, specializedItemType = GetItemLinkItemType(string.format("|H0:item:%s:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", itemId))
  
  local nonFishCatches = {[217654] = true, [197853] = true, [139011] = true, [140443] = true, [43757] = true,
  [118903] = true, [118902] = true, [118338] = true, [118359] = true, [118358] = true, [118339] = true, [118357] = true, [118337] = true, [120753] = true, [120755] = true, [120754] = true, [118901] = true, [118900] = true, [118897] = true, [118896] = true, [118899] = true, [118898] = true, [139082] = true, [139081] = true, [139080] = true, [139077] = true, [139079] = true, [139078] = true, [145402] = true, [64222] = true}
  
  -- we count every item for the future display
  if itemType == ITEMTYPE_FISH or specializedItemType == SPECIALIZED_ITEMTYPE_COLLECTIBLE_RARE_FISH or nonFishCatches[itemId] then
     local icon = GetItemLinkIcon(string.format("|H0:item:%s:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", itemId))
     local name = GetItemLinkName(string.format("|H0:item:%s:1:1:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", itemId))
     local format = "|t24:24:"..icon.."|t".." "..VEQ.KillTheRubbish(name)
     
     VEQ.FishingCounter[zoneId] = VEQ.FishingCounter[zoneId] or {}
     VEQ.FishingCounter[zoneId][format] = VEQ.FishingCounter[zoneId][format] or {}
     if VEQ.FishingCounter[zoneId][format].counter then
        VEQ.FishingCounter[zoneId][format].counter = VEQ.FishingCounter[zoneId][format].counter + 1
     else
        VEQ.FishingCounter[zoneId][format].counter = 1
     end
     VEQ.FishingCounter[zoneId][format].text = format.." x"..VEQ.FishingCounter[zoneId][format].counter
  end
  
   VEQ.FishingCounter[zoneId] = VEQ.FishingCounter[zoneId] or {}
   if NonContiguousCount( VEQ.FishingCounter[zoneId]) == 0  then
       return
   end
   
   local criterionText = {}
   if not achievementCompleted then
     for criterionIndex=1, numCriteria do
       local description, numCompleted, numRequired = GetAchievementCriterion(achievementId, criterionIndex)
       
      if NonContiguousCount(criterionText) == 0 then 
           table.insert(criterionText, string.format("%s\n",  achievementDescription))
       end
       if numCompleted ~= numRequired then 
           table.insert(criterionText, string.format("%s%s\n", zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), description))
       end
     end
     
     -- fish counter after angler achievement 
     VEQ.FishingCounter[zoneId] = VEQ.FishingCounter[zoneId] or {}
     table.insert(criterionText, string.format("\n%s%s:\n", zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10),GetString(SI_ITEM_SET_CATEGORY_SUMMARY_LABEL)))
     for k, v in pairs(VEQ.FishingCounter[zoneId]) do
          table.insert(criterionText, string.format("%s\n",  v.text))
     end
     
   else -- fish counter after angler achievement 
       VEQ.FishingCounter[zoneId] = VEQ.FishingCounter[zoneId] or {}
       table.insert(criterionText, string.format("%s:\n",  GetString(SI_ITEM_SET_CATEGORY_SUMMARY_LABEL)))
       for k, v in pairs(VEQ.FishingCounter[zoneId]) do
          table.insert(criterionText, string.format("%s\n",  v.text))
       end
   end
   
   criterionText = table.concat(criterionText)
   
   -- local perfectRoetext = "" 
   
   -- if numPerfectRoe > 0 then
       -- perfectRoetext = string.format("%s: %s", GetItemLinkName("|H0:item:64222:370:50:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"), numPerfectRoe)
   -- end
   
   
   -- if criterionText == "" then
      -- criterionText = string.format("%s%s\n", criterionText, perfectRoetext)
   -- elseif perfectRoetext ~= "" then
      -- criterionText = string.format("%s%s%s\n", criterionText, zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), perfectRoetext)
   -- end
   
   VEQ.LoadMiniQuestsInfo(21, 21, achievementName, criterionText, string.format("%s - %s", GetString(SI_GUILDACTIVITYATTRIBUTEVALUE9), GetUnitZone("player")), "esoui/art/tutorial/gamepad/achievement_categoryicon_fishing.dds")
   VEQ.DisplayFocusedMiniQuest()

end

function VEQ.zoneStoryTracker(dontTrack)
     if not IsPlayerActivated() then return end

     local pZoneID = ZO_ExplorationUtils_GetZoneStoryZoneIdForCurrentMap() 
         
     if not VEQ.SavedVars.ZoneGuide or IsZoneStoryComplete(pZoneID) or not CanZoneStoryContinueTrackingActivities(pZoneID)then
       if VEQ.CurrentZoneStory ~= nil then
           ClearTrackedZoneStory()
           VEQ.CurrentZoneStory = nil
         VEQ.updatePerZoneDisplay()
       end
             return 
     end

     if not GetTrackedZoneStoryActivityInfo() then 
       if VEQ.CurrentZoneStory ~= nil then
          VEQ.CurrentZoneStory = nil
          VEQ.updatePerZoneDisplay()
       end
       return
     else
       
       local zoneId, zoneCompletionType, activityId = GetTrackedZoneStoryActivityInfo() 
       local ZSActivityName = GetZoneStoryActivityNameByActivityId(zoneId, zoneCompletionType, activityId) or ""
       local ZSActivityDescription = GetZoneStoryShortDescriptionByActivityId(zoneId, zoneCompletionType, activityId) or ""
       local ZSActivityZone = GetZoneNameById(zoneId) or ""
       

      if ZSActivityName ~= "" and ZSActivityDescription ~= "" and ZSActivityZone ~= "" then
         VEQ.CurrentZoneStory = VEQ.CurrentZoneStory or {}
         
         local icon = zo_iconFormatInheritColor("esoui/art/lfg/gamepad/lfg_menuicon_zonestories.dds", 24, 24)
         VEQ.CurrentZoneStory.zoneId = zoneId
         VEQ.CurrentZoneStory.text = string.format("%s%s", icon, ZSActivityDescription)
         
         VEQ.updatePerZoneDisplay()
         
      else
          if VEQ.CurrentZoneStory ~= nil then
           VEQ.CurrentZoneStory = nil
           VEQ.updatePerZoneDisplay()
        end
      end
     end 
     
     -- auto enable zone story tracker for current zone if there is no active quest in zone
     if (not VEQ.isThereAnyActiveQuestInZone()) and (not VEQ.isCurrentZoneTrackedZoneStory()) and not dontTrack then 
       TrackNextActivityForZoneStory(pZoneID, nil, nil, false)
       VEQ.zoneStoryTracker(true)
     end
end

function VEQ.mapCompletion(zoneId, reset)
     if not IsPlayerActivated() then return end 
     
     if not VEQ.SavedVars.POIcompletion then
       VEQ.CurrentMapCompletion = {}
       VEQ.updatePerZoneDisplay()
       return
     end
     
     if not zoneId then
         zoneId = ZO_ExplorationUtils_GetZoneStoryZoneIdForCurrentMap()
     end
     
     local zoneIndex = GetZoneIndex(zoneId)
     local numPOIsInZone = GetNumPOIs(zoneIndex)
     local numDiscoveredPOIsInZone = 0
     
     VEQ.CurrentMapCompletion = VEQ.CurrentMapCompletion or {}
     
     if reset then
        VEQ.CurrentMapCompletion = {}
     else
       if VEQ.CurrentMapCompletion.POIindex then
         local x, y, poiPinType, icon, isShownInCurrentMap, linkedCollectibleIsLocked, isDiscovered, isNearby = GetPOIMapInfo(zoneIndex, VEQ.CurrentMapCompletion.POIindex)
         if isDiscovered then
           VEQ.CurrentMapCompletion = {}
         end
       end
     end
     
     local alliance = GetUnitAlliance("player")
     
     local totalPOIs = 0
     for i = 1, numPOIsInZone do
       local x, y, poiPinType, icon, isShownInCurrentMap, linkedCollectibleIsLocked, isDiscovered, isNearby = GetPOIMapInfo(zoneIndex, i)
       local name = GetPOIInfo(zoneIndex, i)
       
       -- we exclude the 4 Cyrodiil undiscoverable wayshrines
       if alliance == ALLIANCE_ALDMERI_DOMINION then
              if zoneIndex == 38 then
              if (i > 51 and i < 54) or (i > 55 and i < 58) then
                skip = true
            end
          end
       elseif alliance == ALLIANCE_DAGGERFALL_COVENANT then
              if zoneIndex == 38 then
              if i > 53 and i < 58 then
                skip = true
            end
          end
       elseif alliance == ALLIANCE_EBONHEART_PACT then
              if zoneIndex == 38 then
              if i > 51 and i < 56 then
                skip = true
            end
          end
       end

     
       if name and name ~= "" and not skip then
         if isDiscovered  then
           numDiscoveredPOIsInZone = numDiscoveredPOIsInZone + 1
         else
           if not VEQ.CurrentMapCompletion.POIindex then
             VEQ.CurrentMapCompletion.POIindex = i
             VEQ.CurrentMapCompletion.zoneId = zoneId
             icon = zo_iconFormatInheritColor(icon, 24, 24)
             local description = zo_strformat(GetString(SI_ZONECOMPLETIONTYPE_SHORTDESCRIPTION10), name) 
             VEQ.CurrentMapCompletion.text = string.format("%s%s", icon, description)
           end
                   
         end
         totalPOIs = totalPOIs +1
       end
     end
     local icon = zo_iconFormatInheritColor("esoui/art/zonestories/completiontypeicon_pointofinterest.dds", 24, 24)
     VEQ.CurrentMapCompletion.completionMessage = string.format("%s%s %s/%s", icon, GetString(SI_ZONECOMPLETIONTYPE2), numDiscoveredPOIsInZone, totalPOIs)
     VEQ.updatePerZoneDisplay()
end

function VEQ.groupFinder()
    if not IsPlayerActivated() then return end
    VEQ.groupFinderMessage = VEQ.groupFinderMessage or ""
    
    local asker = GROUP_FINDER_GROUP_LISTING_USER_TYPE_CREATED_GROUP_LISTING
    local leader = GetGroupFinderUserTypeGroupListingLeaderDisplayName(asker)

    local listingIndex  
  
    if not leader or leader == "" then -- you are a group member, not the leader or there is no listing

       -- get the listing for group members:
       for listing = 1, GetGroupFinderSearchNumListings() do
            if GetGroupFinderSearchListingJoinabilityResult(listing) == GROUP_FINDER_ACTION_RESULT_FAILED_ALREADY_JOINED_GROUP then
                 listingIndex = listing
            end
       end
       
       if not listingIndex then -- there is really no listing, we abort
          VEQ.groupFinderMessage = ""
          return
       end
  end 
  
  if listingIndex then
      leader = GetGroupFinderSearchListingLeaderDisplayNameByIndex(listingIndex)
  end


    local title = GetGroupFinderUserTypeGroupListingTitle(asker)
  if listingIndex then
     title = GetGroupFinderSearchListingTitleByIndex(listingIndex)
  end
  local description = GetGroupFinderUserTypeGroupListingDescription(asker)
  if listingIndex then
     description = GetGroupFinderSearchListingDescriptionByIndex(listingIndex)
  end
  if description ~= "" then
     description = string.format("\n%s%s", zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), description)
  end 
  
  local optionOneText, optionTwoText = GetGroupFinderUserTypeGroupListingOptionsSelectionText(asker)
  if listingIndex then
     optionOneText, optionTwoText = GetGroupFinderSearchListingOptionsSelectionTextByIndex(listingIndex)
  end
  
  local options = ""
  if optionOneText ~= "" then
     options = string.format("\n%s%s", zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), VEQ.KillTheRubbish(optionOneText))
     if optionTwoText ~= "" then
         options = string.format("%s %s", options, VEQ.KillTheRubbish(optionTwoText))
     end
  elseif optionTwoText ~= "" then
         options = string.format("\n%s%s", zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), VEQ.KillTheRubbish(optionTwoText))
  end
  
  local playStyle = GetGroupFinderUserTypeGroupListingPlaystyle(asker)
  if listingIndex then
     playStyle = GetGroupFinderSearchListingPlaystyleByIndex(listingIndex)
  end
  if playStyle then
       if playStyle == GROUP_FINDER_PLAYSTYLE_EDUCATIONAL then
             playStyle = string.format("\n%s%s", zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), GetString(SI_GROUPFINDERPLAYSTYLE2))
     elseif playStyle == GROUP_FINDER_PLAYSTYLE_SPEED then
             playStyle = string.format("\n%s%s%s", zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), GetString(SI_GROUPFINDERPLAYSTYLE4), GetString(SI_HOUSINGPATHMOVEMENTSPEED2))
     elseif playStyle == GROUP_FINDER_PLAYSTYLE_ACHIEVEMENT then
             playStyle = string.format("\n%s%s", zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), GetString(SI_GAMEPAD_MAIN_MENU_JOURNAL_ACHIEVEMENTS))
     elseif playStyle == GROUP_FINDER_PLAYSTYLE_STORY then --32
             playStyle = string.format("\n%s%s", zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), GetString(SI_GROUPFINDERPLAYSTYLE32))
     elseif playStyle == GROUP_FINDER_PLAYSTYLE_ROLE_PLAY then --16
             playStyle = string.format("\n%s%s", zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), GetString(SI_GROUPFINDERPLAYSTYLE16))
     else
             playStyle = ""
     end
  else
      playStyle = ""
  end

  
  local maxSize = GetGroupFinderUserTypeGroupListingGroupSize(asker)
  if listingIndex then
     maxSize = GetGroupFinderSearchListingGroupSizeByIndex(listingIndex)
  end
  
  if maxSize == GROUP_FINDER_SIZE_LARGE then
         maxSize = 12
  elseif maxSize == GROUP_FINDER_SIZE_SMALL then
         maxSize = 2
  elseif maxSize == GROUP_FINDER_SIZE_STANDARD then
         maxSize = 4
  end
  
  
  local groupSize = GetGroupSize()
  if groupSize == 0 then
     groupSize = 1
  end 
  
  local missing = maxSize - groupSize
  if missing > 0 then 
     missing = string.format("\n%s%s %s", zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), missing, zo_strformat("<<z:1>>", GetString(SI_GAMEPAD_ARMORY_MISSING_ENTRY_NARRATION)))
     VEQ.groupFinderFull = false 
  else
     missing = ""
     VEQ.groupFinderFull = true
  end
    
  VEQ.groupFinderMessage = string.format("%s(%s)%s%s%s%s", title, leader, description, options, playStyle, missing)

    if GetGroupSize() == 0 then 
      VEQ.GroupFrames()
  end 
end

function VEQ.activityTracker()

     if not IsPlayerActivated() then return end
     VEQ.AFStatus = GetActivityFinderStatus() 
     local AFStatus = VEQ.AFStatus


     -- create table if it doesn't exist
     VEQ.MiniQuestList = VEQ.MiniQuestList or {}
     
    if VEQ.MiniQuestList[12] and VEQ.FocusedMiniQuest ~= 12 then return end

    if AFStatus == ACTIVITY_FINDER_STATUS_IN_PROGRESS or AFStatus == ACTIVITY_FINDER_STATUS_NONE or AFStatus == ACTIVITY_FINDER_STATUS_COMPLETE then
        if VEQ.MiniQuestList[12] then
             VEQ.MiniQuestList[12] = nil
             if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
             VEQ.DisplayFocusedMiniQuest()
        end
    end

    local activityId = 0
    local activityType

    if IsCurrentlySearchingForGroup() then
        activityId = GetActivityRequestIds(1)
    elseif IsInLFGGroup() then
        activityId = GetCurrentLFGActivityId()
    end

    if activityId > 0 and AFStatus ~= ACTIVITY_FINDER_STATUS_IN_PROGRESS then
       -- 04/07/2026 performance improvement:
       -- This whole function runs every second, forever, for every player (via the
       -- "ClockUpdate" timer, gated only on VEQ.AFStatus being set, which happens shortly
       -- after login). The LFG search-time formatting below (GetLFGSearchTimes,
       -- ZO_FormatTimeMilliseconds, ZO_GetSimplifiedTimeEstimateText) used to run
       -- unconditionally every tick even though textStartTime/textEstimatedTime are only
       -- ever read inside this activityId > 0 branch - i.e. only while the player is
       -- actually searching for or in an LFG activity. For the very common case of not
       -- using the group finder, this was pure per-second overhead. Computing it here,
       -- only when it will actually be used, removes that cost the rest of the time.
       local searchStartTimeMs, searchEstimatedCompletionTimeMs = GetLFGSearchTimes()
       local timeSinceSearchStartMs = GetFrameTimeMilliseconds() - searchStartTimeMs
       local textStartTime = ZO_FormatTimeMilliseconds(timeSinceSearchStartMs, TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR)

       local textEstimatedTime = ""
       if searchEstimatedCompletionTimeMs > 0 then
          textEstimatedTime = string.format("%s%s", VEQ.mylanguage.lang_in, ZO_GetSimplifiedTimeEstimateText(searchEstimatedCompletionTimeMs))
       end

       activityType = GetActivityType(activityId)
       local aType = GetString("SI_LFGACTIVITY", activityType)
       local icon = "esoui/art/miscellaneous/check_icon_32.dds"
       local LFG = VEQ.mylanguage.lang_lfg
    
    
        if activityType == LFG_ACTIVITY_BATTLE_GROUND_CHAMPION then icon = "esoui/art/icons/poi/poi_group_battleground_complete.dds" aType = VEQ.mylanguage.lang_champion_battleground
        elseif activityType == LFG_ACTIVITY_BATTLE_GROUND_LOW_LEVEL then icon = "esoui/art/icons/poi/poi_group_battleground_complete.dds" aType = VEQ.mylanguage.lang_low_battleground
        elseif activityType == LFG_ACTIVITY_BATTLE_GROUND_NON_CHAMPION then icon = "esoui/art/icons/poi/poi_group_battleground_complete.dds" aType = VEQ.mylanguage.lang_non_battleground
        elseif activityType == LFG_ACTIVITY_DUNGEON then icon = "esoui/art/icons/poi/poi_groupinstance_complete.dds" aType = VEQ.mylanguage.lang_normal_dungeon_finder
        elseif activityType == LFG_ACTIVITY_MASTER_DUNGEON then icon = "esoui/art/icons/poi/poi_groupinstance_complete.dds" aType = VEQ.mylanguage.lang_veteran_dungeon_finder
        elseif activityType == LFG_ACTIVITY_TRIBUTE_CASUAL then icon = "esoui/art/icons/servicemappins/servicepin_talesoftribute.dds" aType = VEQ.mylanguage.lang_tribute_casual LFG = VEQ.mylanguage.lang_lfo
        elseif activityType == LFG_ACTIVITY_TRIBUTE_COMPETITIVE then icon = "esoui/art/icons/servicemappins/servicepin_talesoftribute.dds" aType = VEQ.mylanguage.lang_tribute_competitive LFG = VEQ.mylanguage.lang_lfo
        elseif activityType == LFG_ACTIVITY_ARENA then icon = "esoui/art/treeicons/gamepad/gp_reconstruction_tabicon_arenagroup.dds" 
        elseif activityType == LFG_ACTIVITY_ENDLESS_DUNGEON then icon = "esoui/art/icons/mapkey/mapkey_endlessdungeon.dds" 
        elseif activityType == LFG_ACTIVITY_EXPLORATION then  icon = "esoui/art/treeicons/gamepad/achievement_categoryicon_exploration.dds" 
        end
    
    local status = GetString("SI_ACTIVITYFINDERSTATUS", AFStatus)
    
    if (AFStatus == ACTIVITY_FINDER_STATUS_READY_CHECK or AFStatus == ACTIVITY_FINDER_STATUS_FORMING_GROUP) and HasAcceptedLFGReadyCheck() then
    
      local tanksAccepted, tanksPending, healersAccepted, healersPending, dpsAccepted, dpsPending = GetLFGReadyCheckCounts()
      local acceptedTotal = tanksAccepted + healersAccepted + dpsAccepted
      local pendingTotal = tanksPending + healersPending + dpsPending
      local total = pendingTotal + tanksAccepted + healersAccepted + dpsAccepted 
      local lfgActivityType = GetLFGReadyCheckActivityType()
      local tankIcon = ""
      local healerIcon = ""
      local dps1Icon = ""
      local dps2Icon = ""

      if ZO_IsActivityTypeDungeon(lfgActivityType) and pendingTotal <= 4 then 
      if tanksAccepted == 1 then tankIcon = "|t32:32:EsoUI/Art/LFG/LFG_tank_down_no_glow_64.dds|t " else tankIcon = "|t32:32:EsoUI/Art/LFG/LFG_tank_disabled_64.dds|t " end
      if healersAccepted == 1 then healerIcon = "|t32:32:EsoUI/Art/LFG/LFG_healer_down_no_glow_64.dds|t " else healerIcon = "|t32:32:EsoUI/Art/LFG/LFG_healer_disabled_64.dds|t " end
      if dpsAccepted == 1 then dps1Icon = "|t32:32:EsoUI/Art/LFG/LFG_dps_down_no_glow_64.dds|t " else dps1Icon = "|t32:32:EsoUI/Art/LFG/LFG_dps_disabled_64.dds|t " end
      if dpsAccepted == 2 then dps2Icon = "|t32:32:EsoUI/Art/LFG/LFG_dps_down_no_glow_64.dds|t" else dps2Icon = "|t32:32:EsoUI/Art/LFG/LFG_dps_disabled_64.dds|t" end
                
         VEQ.LoadMiniQuestsInfo(12, 12, string.format("%s%s", LFG, textEstimatedTime), string.format("%s %s\n %s%s%s%s", status, textStartTime, tankIcon, healerIcon, dps1Icon, dps2Icon), aType, icon)
         VEQ.DisplayFocusedMiniQuest()
      
    elseif activityType == LFG_ACTIVITY_TRIBUTE_COMPETITIVE or activityType == LFG_ACTIVITY_TRIBUTE_CASUAL then 
         VEQ.LoadMiniQuestsInfo(12, 12, VEQ.mylanguage.lang_everybody_ready, string.format("1/2%s", VEQ.mylanguage.lang_ready), aType, icon)
         VEQ.DisplayFocusedMiniQuest()
         
      else
           VEQ.LoadMiniQuestsInfo(12, 12, VEQ.mylanguage.lang_everybody_ready, string.format("%s/%s%s", acceptedTotal, total, VEQ.mylanguage.lang_ready), VEQ.mylanguage.lang_grc, icon)
           VEQ.DisplayFocusedMiniQuest()
      end
    else
            if IsUnitInDungeon("player") and activityType == LFG_ACTIVITY_DUNGEON and GetGroupSize() < 4 and not IsUnitInCombat("player") then -- find replacement in group frame
            if VEQ.MiniQuestList[12] then VEQ.MiniQuestList[12] = nil end
            if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
            VEQ.DisplayFocusedMiniQuest() 
      else
            VEQ.LoadMiniQuestsInfo(12, 12, string.format("%s%s", LFG, textEstimatedTime), string.format("%s%s%s", status, VEQ.mylanguage.lang_for, textStartTime), aType, icon)
            VEQ.DisplayFocusedMiniQuest()
      end   
    end 
    
    elseif AFStatus == ACTIVITY_FINDER_STATUS_READY_CHECK and HasAcceptedLFGReadyCheck() then
      local tanksAccepted, tanksPending, healersAccepted, healersPending, dpsAccepted, dpsPending = GetLFGReadyCheckCounts()
      local acceptedTotal = tanksAccepted + healersAccepted + dpsAccepted
      local pendingTotal = tanksPending + healersPending + dpsPending
      local total = pendingTotal + tanksAccepted + healersAccepted + dpsAccepted
      
      VEQ.LoadMiniQuestsInfo(12, 12, VEQ.mylanguage.lang_everybody_ready, string.format("%s/%s%s", acceptedTotal, total, VEQ.mylanguage.lang_ready), VEQ.mylanguage.lang_grc, icon)
      VEQ.DisplayFocusedMiniQuest()
    else 
        if VEQ.MiniQuestList[12] then VEQ.MiniQuestList[12] = nil end
        if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
        VEQ.DisplayFocusedMiniQuest() 
    end
end




function VEQ.AllianceWarQueue()

   if not IsPlayerActivated() then return end

   -- create table if it doesn't exist
   VEQ.MiniQuestList = VEQ.MiniQuestList or {}
   
   if VEQ.MiniQuestList[13] and VEQ.FocusedMiniQuest ~= 13 then return end
   
  local campaigns = GetNumCampaignQueueEntries()
  
  local campaignIndex = 999
  local qp = 999
  
  for C=1, campaigns do
     local LcampaignID, LisGroup = GetCampaignQueueEntry(C)
     local LqueuePosition = GetCampaignQueuePosition(LcampaignID, LisGroup)
     if LqueuePosition < qp then 
        qp = LqueuePosition 
      campaignIndex = C 
     end 
  end
  
  
  local campaignID, isGroup = GetCampaignQueueEntry(campaignIndex) or -1, false
  local campaignName = GetCampaignName(campaignID) or ""
  local secondsElapsed = GetSecondsInCampaignQueue(campaignID, isGroup) or -1
  local queuePosition = GetCampaignQueuePosition(campaignID, isGroup) or -1
  local secondsToCampaign = (GetSelectionCampaignQueueWaitTime(campaignIndex)*3) + (queuePosition * 60) or -1 
  local queueState = GetCampaignQueueState(campaignID, isGroup) or ""
  local campaignType = GetCampaignRulesetType(GetCampaignRulesetId(campaignID)) or ""
  
  
  if queueState == CAMPAIGN_QUEUE_REQUEST_STATE_FINISHED then 
         if VEQ.MiniQuestList[13] then VEQ.MiniQuestList[13] = nil end
       if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
         VEQ.DisplayFocusedMiniQuest() 
       VEQ.isInAllianceWarWaitingQueue = false
  
  else  
      local alliance = GetUnitAlliance("player")
      local allianceColor = GetAllianceColor(alliance)
      local icon = "esoui/art/icons/poi/poi_keep_complete.dds"
      
      if alliance == ALLIANCE_ALDMERI_DOMINION then
         icon = "esoui/art/stats/alliancebadge_aldmeri.dds"
      elseif alliance == ALLIANCE_DAGGERFALL_COVENANT then
         icon = "esoui/art/stats/alliancebadge_daggerfall.dds" 
      elseif alliance == ALLIANCE_EBONHEART_PACT then
         icon = "esoui/art/stats/alliancebadge_ebonheart.dds"
      end 
      
      local cType = ""
      if campaignType == CAMPAIGN_RULESET_TYPE_CYRODIIL then cType = VEQ.mylanguage.lang_cyrodiil end 
      
      local group = ""
      if isGroup then group = VEQ.mylanguage.lang_group end
      
      local timeElapsed = ZO_FormatTimeMilliseconds((secondsElapsed*1000), TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR)
      local timeToCampaign = ZO_GetSimplifiedTimeEstimateText((secondsToCampaign*1000), TIME_FORMAT_STYLE_SHOW_LARGEST_UNIT, nil, ZO_TIME_ESTIMATE_STYLE.ARITHMETIC) or ""
      
      if secondsToCampaign < 1 then
           timeToCampaign = "" 
      else 
           timeToCampaign = string.format("%s%s", VEQ.mylanguage.lang_ewt, timeToCampaign)
      end
      
      local enter = VEQ.mylanguage.lang_entering_campaign
      local startedAgoMessage = string.format("%s%s%s", VEQ.mylanguage.lang_n_started, timeElapsed, VEQ.mylanguage.lang_ago)
      
      if secondsElapsed > 86400 then
         startedAgoMessage = ""
         timeToCampaign = ""
      end
      
      local qState = ""
      if queueState == CAMPAIGN_QUEUE_REQUEST_STATE_CONFIRMING then qState = VEQ.mylanguage.lang_confirming startedAgoMessage = ""
      elseif queueState == CAMPAIGN_QUEUE_REQUEST_STATE_FINISHED then qState = VEQ.mylanguage.lang_finished
      elseif queueState == CAMPAIGN_QUEUE_REQUEST_STATE_PENDING_ACCEPT then qState = VEQ.mylanguage.lang_pending_accept
      elseif queueState == CAMPAIGN_QUEUE_REQUEST_STATE_PENDING_JOIN then qState = VEQ.mylanguage.lang_pending_join 
      elseif queueState == CAMPAIGN_QUEUE_REQUEST_STATE_PENDING_LEAVE then qState = VEQ.mylanguage.lang_leaving_queue startedAgoMessage = "" enter = VEQ.mylanguage.lang_exiting_campaign
      elseif queueState == CAMPAIGN_QUEUE_REQUEST_STATE_WAITING then qState = VEQ.mylanguage.lang_waiting 
      end
      
      local queuePositionText = ""
      if queuePosition ~= 0 then queuePositionText = string.format("%s%s", VEQ.mylanguage.lang_n_queue_position, queuePosition) end 

      VEQ.LoadMiniQuestsInfo(13, 13, enter, string.format("%s%s%s%s", qState, startedAgoMessage, timeToCampaign, queuePositionText), string.format("%s%s%s", group, cType, campaignName), icon, nil, nil, nil, allianceColor)
      VEQ.DisplayFocusedMiniQuest()
  
      VEQ.isInAllianceWarWaitingQueue = true
  end
end



function VEQ.KillTheRubbish(String)
  return  LocalizeString('<<1>>', String)
end 



function VEQ.isThereAnyActiveQuestInZone()
  local currentZoneIndex = GetUnitZoneIndex("player")
  
  for i=1, MAX_JOURNAL_QUESTS do
    if IsValidQuestIndex(i) then
       local zoneName, objectiveName, zoneIndex, poiIndex = GetJournalQuestLocationInfo(i)
       if currentZoneIndex == zoneIndex then return true end
    end
  end
    
  return false

end



function VEQ.isCurrentZoneTrackedZoneStory() 
    local currentZoneName = GetZoneNameById(ZO_ExplorationUtils_GetZoneStoryZoneIdForCurrentMap())
  local searchForThat = ZO_CachedStrFormat(SI_ZONE_STORY_TRACKER_TITLE, currentZoneName)
  
  if VEQ.CurrentZoneStory ~= nil and VEQ.CurrentZoneStory.zoneId and string.find(searchForThat, GetZoneNameById(VEQ.CurrentZoneStory.zoneId)) then
       return true
    else
       return false
  end

end

function isInvertKeyPressed()
  if VEQ.SavedVars.invertKey == "CTRL" then
         return IsControlKeyDown()
  elseif VEQ.SavedVars.invertKey == "SHIFT" then
         return IsShiftKeyDown()
  elseif VEQ.SavedVars.invertKey == "ALT" then
         return IsAltKeyDown()
  elseif VEQ.SavedVars.invertKey == "CMD" then
         return IsCommandKeyDown()
  else return false
  end

end

function VEQ.ChangeFocusedMiniQuest()

 if VEQ.MiniQuestList == nil or VEQ.totalMiniQuests <= 1  then return end
 
 if isInvertKeyPressed() then
    
  local nextMiniQuest = next(VEQ.MiniQuestList, VEQ.FocusedMiniQuest) or next(VEQ.MiniQuestList) 
  local previousMiniQuest
  while nextMiniQuest ~= VEQ.FocusedMiniQuest do
        previousMiniQuest = nextMiniQuest 
    nextMiniQuest = next(VEQ.MiniQuestList, nextMiniQuest) or next(VEQ.MiniQuestList)
    end
 
    VEQ.FocusedMiniQuest = previousMiniQuest
 else
      VEQ.FocusedMiniQuest = next(VEQ.MiniQuestList, VEQ.FocusedMiniQuest) or next(VEQ.MiniQuestList)
 end
 
  
 VEQ.CharSavedVars.lastSelectedMiniquest = VEQ.FocusedMiniQuest
 
 VEQ.DisplayFocusedMiniQuest()
 
 PlaySound(SOUNDS.DEFAULT_CLICK)

end


function VEQ.GetQuestLine(questName)

   if not IsPlayerActivated() then return end
   
   local guildLine = nil
   
   local DarkBrotherhood = {5595, 5599, 5596, 5567, 5597, 5598, 5600, 5725, 5718, 5719, 5726, 5714, 5724, 5529, 5720, 5713, 5617, 5693, 5593, 5709, 5708, 5666, 5669, 5679, 5694, 5696, 5698, 5700, 5701, 5704, 5706, 5690, 5652, 5705, 5684, 5633, 5621, 5671, 5676, 5688,  5697,  5627, 5703, 5707, 5710, 5711, 5699, 5658}
     
  for _,v in pairs(DarkBrotherhood) do
    if questName == GetQuestName(v) then
       guildLine = VEQ.mylanguage.lang_tracker_type_dark_brotherhood break
    end
    end

   
   local ThievesGuild = {5549, 5545, 5581, 5553, 5572, 5573, 5575, 5577, 5536, 5566, 5570, 5543, 5537, 5535, 5556, 5532, 5534, 5531, 5586, 5587, 5588, 5589, 5645, 5646, 5647, 5640, 5610, 5639, 5642, 5609, 5641, 5584, 5644, 5643, 5638, 5582, 5668, 7168, 7169, 7442, 7453, 7419, 7427, 7426, 7484, 7496, 7497}

    for _,v in pairs(ThievesGuild) do
      if questName == GetQuestName(v) then
         guildLine = VEQ.mylanguage.lang_tracker_type_thieves_guild break
      end
    end

    local MagesGuild = {3916, 4435, 3918, 3953, 3997, 4971, 5814, 5816, 5818, 5819, 5820, 5822, 5823, 5824, 5825, 5826, 5827, 5828, 5829, 5830, 5831} 

    for _,v in pairs(MagesGuild) do
    if questName == GetQuestName(v) then
       guildLine = VEQ.mylanguage.lang_tracker_type_mages_guild break
    end 
    end


    local FightersGuild = {3856, 3858, 3885, 3898, 3973, 4877, 4876, 4874, 4875, 5784, 5785, 5786, 5787, 5788, 5789, 5790, 5791, 5792, 5793, 5794, 5795, 5796, 5797, 5833}

    for _,v in pairs(FightersGuild) do
    if questName == GetQuestName(v) then
       guildLine = VEQ.mylanguage.lang_tracker_type_fighters_guild break
    end 
    end


    local Undaunted = {5734, 5735, 5733, 5738, 5853, 5800, 5808, 5737, 5778, 5779, 5802, 5744, 5739, 5734, 5798 } 

    for _,v in pairs(Undaunted) do
    if questName == GetQuestName(v) then
       guildLine = VEQ.mylanguage.lang_tracker_type_undaunted break 
    end 
    end


   local Psijic = {6172, 6181, 6185, 6194, 6197, 6190, 6198, 6195, 6196, 6199}

    for _,v in pairs(Psijic) do
    if questName == GetQuestName(v) then
       guildLine = VEQ.mylanguage.lang_tracker_type_psijic_order break
    end 
    end


   local Arena = {6269, 5448, 5637, 6610, 6561}

    for _,v in pairs(Arena) do
    if questName == GetQuestName(v) then
       guildLine = VEQ.mylanguage.lang_tracker_type_arena break
    end 
    end

    return guildLine
end




function VEQ.PsijicTimeBreachesHelper(qindex) 

     if not IsPlayerActivated() then return end

   -- create table if it doesn't exist
   VEQ.MiniQuestList = VEQ.MiniQuestList or {}
   
   
   local qname = GetJournalQuestName(qindex)
   local journalText, visibility, comparisonType, trackerOverrideText, numConditions = GetJournalQuestStepInfo(qindex, 1)
   local current, qmax, isFailCondition, isComplete, isCreditShared, isVisible = GetJournalQuestConditionValues(qindex, 1, 1)
     local current2, _, _, _, _, _ = GetJournalQuestConditionValues(qindex, 1, 2)
     local current3, _, _, _, _, _ = GetJournalQuestConditionValues(qindex, 1, 3)
     local current4,  _, _, _, _, _ = GetJournalQuestConditionValues(qindex, 1, 4)  


     local pZoneID = GetZoneId(GetUnitZoneIndex("player")) -- not used? 
   local zoneName = GetUnitZone("player") -- not used?

    if qname == GetQuestName(6172) then -- The Psijics' Calling
     
     
     local psijicSealsCount = VEQ.GetThatQuestToolCount(6552, qindex) -- item id, quest index
     local psijicMapCount = VEQ.GetThatQuestToolCount(6578, qindex) -- 6642
     
     if psijicSealsCount ~= 999 and psijicMapCount ~= 999 and qmax == 9  then -- display only with the right psijic seals set

          if psijicSealsCount == 9 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,1), VEQ.mylanguage.lang_6172_helper_9, GetZoneNameById(1011), "VEQ/art/icons/white_psijic_64.dds") 
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 8 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,2), VEQ.mylanguage.lang_6172_helper_8, GetZoneNameById(1011), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 7 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,3), VEQ.mylanguage.lang_6172_helper_7, GetZoneNameById(1011), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 6 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,4), VEQ.mylanguage.lang_6172_helper_6, GetZoneNameById(1011), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 5 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,5), VEQ.mylanguage.lang_6172_helper_5, GetZoneNameById(1011), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 4 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,6), VEQ.mylanguage.lang_6172_helper_4, GetZoneNameById(1011), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 3 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,7), VEQ.mylanguage.lang_6172_helper_3, GetZoneNameById(1011), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 2 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,8), VEQ.mylanguage.lang_6172_helper_2, GetZoneNameById(1011), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 1 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,9), VEQ.mylanguage.lang_6172_helper_1, GetZoneNameById(1011), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
         else
             if VEQ.MiniQuestList[15] then VEQ.MiniQuestList[15] = nil end
             if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
               VEQ.DisplayFocusedMiniQuest()
           end      
     else
         if VEQ.MiniQuestList[15] then VEQ.MiniQuestList[15] = nil end
       if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
         VEQ.DisplayFocusedMiniQuest()
     end 
     
     
     
  elseif qname == GetQuestName(6181) then -- Breaches On the Bay   seals 6582 map 6583
     
     
     local psijicSealsCount = VEQ.GetThatQuestToolCount(6582, qindex) -- item id, quest index
     local psijicMapCount = VEQ.GetThatQuestToolCount(6583, qindex) -- 6642
     
     if psijicSealsCount ~= 999 and psijicMapCount ~= 999 and qmax == 9 then -- display only with the right psijic seals set

          if psijicSealsCount == 9 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,1), VEQ.mylanguage.lang_6181_helper_9, GetZoneNameById(3), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 8 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,2), VEQ.mylanguage.lang_6181_helper_8, GetZoneNameById(3), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 7 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,3), VEQ.mylanguage.lang_6181_helper_7, GetZoneNameById(3), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 6 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,4), VEQ.mylanguage.lang_6181_helper_6, GetZoneNameById(19), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 5 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,5), VEQ.mylanguage.lang_6181_helper_5, GetZoneNameById(19), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 4 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,6), VEQ.mylanguage.lang_6181_helper_4, GetZoneNameById(19), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 3 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,7), VEQ.mylanguage.lang_6181_helper_3, GetZoneNameById(104), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 2 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,8), VEQ.mylanguage.lang_6181_helper_2, GetZoneNameById(104), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 1 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,9), VEQ.mylanguage.lang_6181_helper_1, GetZoneNameById(104), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
         else
             if VEQ.MiniQuestList[15] then VEQ.MiniQuestList[15] = nil end
             if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
               VEQ.DisplayFocusedMiniQuest() 
           end      
     else
         if VEQ.MiniQuestList[15] then VEQ.MiniQuestList[15] = nil end
       if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
         VEQ.DisplayFocusedMiniQuest()
     end 
     
     
   
     
  elseif qname == GetQuestName(6185) then -- Breaches of Frost and Fire   seals 6585    map 6586
     
     local psijicSealsCount = VEQ.GetThatQuestToolCount(6585, qindex) -- item id, quest index
     local psijicMapCount = VEQ.GetThatQuestToolCount(6586, qindex) 
     
     if psijicSealsCount ~= 999 and psijicMapCount ~= 999 and qmax == 9 then -- display only with the right psijic seals set

          if psijicSealsCount == 9 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,1), VEQ.mylanguage.lang_6185_helper_9, GetZoneNameById(41), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 8 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,2), VEQ.mylanguage.lang_6185_helper_8, GetZoneNameById(41), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 7 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,3), VEQ.mylanguage.lang_6185_helper_7, GetZoneNameById(41), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 6 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,4), VEQ.mylanguage.lang_6185_helper_6, GetZoneNameById(101), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 5 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,5), VEQ.mylanguage.lang_6185_helper_5, GetZoneNameById(101), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 4 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,6), VEQ.mylanguage.lang_6185_helper_4, GetZoneNameById(101), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 3 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,7), VEQ.mylanguage.lang_6185_helper_3, GetZoneNameById(103), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 2 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,8), VEQ.mylanguage.lang_6185_helper_2, GetZoneNameById(103), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 1 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,9), VEQ.mylanguage.lang_6185_helper_1, GetZoneNameById(103), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
         else
             if VEQ.MiniQuestList[15] then VEQ.MiniQuestList[15] = nil end
             if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
               VEQ.DisplayFocusedMiniQuest() 
           end      
     else
         if VEQ.MiniQuestList[15] then VEQ.MiniQuestList[15] = nil end
       if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
         VEQ.DisplayFocusedMiniQuest()
     end 
     
     
     
     
  elseif qname == GetQuestName(6197) then -- The Shattered Staff 
  
          if VEQ.stopDisplaying and current == 0 then -- WORKAROUND TO TEST
         if VEQ.MiniQuestList[15] then VEQ.MiniQuestList[15] = nil end
         if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
           VEQ.DisplayFocusedMiniQuest()
      elseif current == 0 then
           VEQ.LoadMiniQuestsInfo(15, 15, VEQ.mylanguage.lang_6197_helper_pelin, VEQ.mylanguage.lang_6197_helper_adamantine, GetZoneNameById(92), "VEQ/art/icons/white_psijic_64.dds")
       VEQ.DisplayFocusedMiniQuest()
         elseif current2 == 0 then
           VEQ.LoadMiniQuestsInfo(15, 15, VEQ.mylanguage.lang_6197_helper_leki, VEQ.mylanguage.lang_6197_helper_orichalc, GetZoneNameById(104), "VEQ/art/icons/white_psijic_64.dds")
       VEQ.DisplayFocusedMiniQuest() 
     elseif current3 == 0 then
           VEQ.LoadMiniQuestsInfo(15, 15, VEQ.mylanguage.lang_6197_helper_hist, VEQ.mylanguage.lang_6197_helper_crystal, GetZoneNameById(117), "VEQ/art/icons/white_psijic_64.dds")
       VEQ.DisplayFocusedMiniQuest()
       VEQ.stopDisplaying = true -- WORKAROUND TO TEST
         elseif current4 == 0 then
           VEQ.LoadMiniQuestsInfo(15, 15, VEQ.mylanguage.lang_6197_helper_fang, VEQ.mylanguage.lang_6197_helper_walk, GetZoneNameById(57), "VEQ/art/icons/white_psijic_64.dds")
       VEQ.DisplayFocusedMiniQuest() 
       else
         if VEQ.MiniQuestList[15] then VEQ.MiniQuestList[15] = nil end
       if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
         VEQ.DisplayFocusedMiniQuest()
     end  
     
     
  elseif qname == GetQuestName(6194) then -- A Breach Amid the Trees  seals 6599   map 6600     grahtwood 383    greenshade 108   malabal tor 58
     
       local psijicSealsCount = VEQ.GetThatQuestToolCount(6599, qindex) -- item id, quest index
     local psijicMapCount = VEQ.GetThatQuestToolCount(6600, qindex) 
     
     if psijicSealsCount ~= 999 and psijicMapCount ~= 999 and qmax == 9 then -- display only with the right psijic seals set

          if psijicSealsCount == 9 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,1), VEQ.mylanguage.lang_6194_helper_9, GetZoneNameById(383), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 8 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,2), VEQ.mylanguage.lang_6194_helper_8, GetZoneNameById(383), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 7 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,3), VEQ.mylanguage.lang_6194_helper_7, GetZoneNameById(383), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 6 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,4), VEQ.mylanguage.lang_6194_helper_6, GetZoneNameById(108), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 5 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,5), VEQ.mylanguage.lang_6194_helper_5, GetZoneNameById(108), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 4 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,6), VEQ.mylanguage.lang_6194_helper_4, GetZoneNameById(108), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 3 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,7), VEQ.mylanguage.lang_6194_helper_3, GetZoneNameById(58), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 2 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,8), VEQ.mylanguage.lang_6194_helper_2, GetZoneNameById(58), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 1 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,9), VEQ.mylanguage.lang_6194_helper_1, GetZoneNameById(58), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
         else
             if VEQ.MiniQuestList[15] then VEQ.MiniQuestList[15] = nil end
             if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
               VEQ.DisplayFocusedMiniQuest() 
           end      
     else
         if VEQ.MiniQuestList[15] then VEQ.MiniQuestList[15] = nil end
       if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
         VEQ.DisplayFocusedMiniQuest()
     end 
     
     
  elseif qname == GetQuestName(6190) then -- A Time for Mud and Mushrooms  seals 6589    map 6590  Deshaan 57  shadowfen 117
  

     local psijicSealsCount = VEQ.GetThatQuestToolCount(6589, qindex) -- item id, quest index
     local psijicMapCount = VEQ.GetThatQuestToolCount(6590, qindex) 
     
     if psijicSealsCount ~= 999 and psijicMapCount ~= 999 and qmax == 9 then -- display only with the right psijic seals set
          if psijicSealsCount == 9 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,1), VEQ.mylanguage.lang_6190_helper_9, GetZoneNameById(57), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 8 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,2), VEQ.mylanguage.lang_6190_helper_8, GetZoneNameById(57), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 7 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,3), VEQ.mylanguage.lang_6190_helper_7, GetZoneNameById(57), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 6 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,4), VEQ.mylanguage.lang_6190_helper_6, GetZoneNameById(57), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 5 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,5), VEQ.mylanguage.lang_6190_helper_5, GetZoneNameById(57), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 4 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,6), VEQ.mylanguage.lang_6190_helper_4, GetZoneNameById(117), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 3 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,7), VEQ.mylanguage.lang_6190_helper_3, GetZoneNameById(117), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 2 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,8), VEQ.mylanguage.lang_6190_helper_2, GetZoneNameById(117), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 1 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,9), VEQ.mylanguage.lang_6190_helper_1, GetZoneNameById(117), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
         else
             if VEQ.MiniQuestList[15] then VEQ.MiniQuestList[15] = nil end
             if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
               VEQ.DisplayFocusedMiniQuest() 
           end      
     else
         if VEQ.MiniQuestList[15] then VEQ.MiniQuestList[15] = nil end
       if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
         VEQ.DisplayFocusedMiniQuest()
     end 
  
  elseif qname == GetQuestName(6198) then -- The Towers' Remains  
  
          if VEQ.stopDisplaying2 and current == 0 then -- WORKAROUND TO TEST
         if VEQ.MiniQuestList[15] then VEQ.MiniQuestList[15] = nil end
         if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
           VEQ.DisplayFocusedMiniQuest()
      elseif current == 0 then
           VEQ.LoadMiniQuestsInfo(15, 15, VEQ.mylanguage.lang_6198_helper_bro, VEQ.mylanguage.lang_6198_helper_red, GetZoneNameById(41), "VEQ/art/icons/white_psijic_64.dds")
       VEQ.DisplayFocusedMiniQuest()
         elseif current2 == 0 then
           VEQ.LoadMiniQuestsInfo(15, 15, VEQ.mylanguage.lang_6198_helper_weep, VEQ.mylanguage.lang_6198_helper_white, GetZoneNameById(19), "VEQ/art/icons/white_psijic_64.dds") 
       VEQ.DisplayFocusedMiniQuest() 
     elseif current3 == 0 then
           VEQ.LoadMiniQuestsInfo(15, 15, VEQ.mylanguage.lang_6198_helper_green, VEQ.mylanguage.lang_6198_helper_greensap, GetZoneNameById(108), "VEQ/art/icons/white_psijic_64.dds") 
       VEQ.DisplayFocusedMiniQuest()
       VEQ.stopDisplaying2 = true -- WORKAROUND TO TEST
         elseif current4 == 0 then
           VEQ.LoadMiniQuestsInfo(15, 15, VEQ.mylanguage.lang_6198_helper_spell, VEQ.mylanguage.lang_6198_helper_snow , GetZoneNameById(888), "VEQ/art/icons/white_psijic_64.dds") 
       VEQ.DisplayFocusedMiniQuest() 
       else
         if VEQ.MiniQuestList[15] then VEQ.MiniQuestList[15] = nil end
       if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
         VEQ.DisplayFocusedMiniQuest()
     end 
  
  
  elseif qname == GetQuestName(6195) then -- Time in Doomcrag's Shadow  seals 6602    map 6603   rivenspire 20
  
     local psijicSealsCount = VEQ.GetThatQuestToolCount(6602, qindex) -- item id, quest index
     local psijicMapCount = VEQ.GetThatQuestToolCount(6603, qindex) 
     
     if psijicSealsCount ~= 999 and psijicMapCount ~= 999 and qmax == 9 then -- display only with the right psijic seals set  

          if psijicSealsCount == 9 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,1), VEQ.mylanguage.lang_6468_helper_9, GetZoneNameById(20), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 8 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,2), VEQ.mylanguage.lang_6468_helper_8, GetZoneNameById(20), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 7 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,3), VEQ.mylanguage.lang_6468_helper_7, GetZoneNameById(20), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 6 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,4), VEQ.mylanguage.lang_6468_helper_6, GetZoneNameById(20), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 5 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,5), VEQ.mylanguage.lang_6468_helper_5, GetZoneNameById(20), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 4 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,6), VEQ.mylanguage.lang_6468_helper_4, GetZoneNameById(20), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 3 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,7), VEQ.mylanguage.lang_6468_helper_3, GetZoneNameById(20), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 2 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,8), VEQ.mylanguage.lang_6468_helper_2, GetZoneNameById(20), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 1 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,9), VEQ.mylanguage.lang_6468_helper_1, GetZoneNameById(20), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
         else
             if VEQ.MiniQuestList[15] then VEQ.MiniQuestList[15] = nil end
             if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
               VEQ.DisplayFocusedMiniQuest() 
           end      
     else
         if VEQ.MiniQuestList[15] then VEQ.MiniQuestList[15] = nil end
       if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
         VEQ.DisplayFocusedMiniQuest()
     end 
  
  
  elseif qname == GetQuestName(6196) then -- A Breach Beyond the Crags    seals 6605     map 6606   craglorn  888


     local psijicSealsCount = VEQ.GetThatQuestToolCount(6605, qindex) -- item id, quest index
     local psijicMapCount = VEQ.GetThatQuestToolCount(6606, qindex) 
     
     if psijicSealsCount ~= 999 and psijicMapCount ~= 999 and qmax == 6 then -- display only with the right psijic seals set  


      if psijicSealsCount == 6 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,1), VEQ.mylanguage.lang_6196_helper_6, GetZoneNameById(888), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 5 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,2), VEQ.mylanguage.lang_6196_helper_5, GetZoneNameById(888), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 4 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,3), VEQ.mylanguage.lang_6196_helper_4, GetZoneNameById(888), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 3 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,4), VEQ.mylanguage.lang_6196_helper_3, GetZoneNameById(888), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 2 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,5), VEQ.mylanguage.lang_6196_helper_2, GetZoneNameById(888), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
      elseif psijicSealsCount == 1 then
              VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,6), VEQ.mylanguage.lang_6196_helper_1, GetZoneNameById(888), "VEQ/art/icons/white_psijic_64.dds")
            VEQ.DisplayFocusedMiniQuest()
         else
             if VEQ.MiniQuestList[15] then VEQ.MiniQuestList[15] = nil end
             if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
               VEQ.DisplayFocusedMiniQuest() 
           end      
     else
         if VEQ.MiniQuestList[15] then VEQ.MiniQuestList[15] = nil end
       if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
         VEQ.DisplayFocusedMiniQuest()
     end 

  elseif qname == GetQuestName(6199) then -- the tower's fall seals 6639 
       
      if GetUnitZoneIndex("player") == 140  then
          VEQ.stopDisplaying3 = true
      end
    
      if not VEQ.stopDisplaying3 then
             VEQ.LoadMiniQuestsInfo(15, 15, string.format("%s%s", VEQ.mylanguage.lang_psijic_time_breach,1), VEQ.mylanguage.lang_6199_helper, GetZoneNameById(104), "VEQ/art/icons/white_psijic_64.dds")
         VEQ.DisplayFocusedMiniQuest()
      else
       if VEQ.MiniQuestList[15] then VEQ.MiniQuestList[15] = nil end
       if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
       VEQ.DisplayFocusedMiniQuest() 
          end 
    else
         if VEQ.MiniQuestList[15] then VEQ.MiniQuestList[15] = nil end
       if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
         VEQ.DisplayFocusedMiniQuest()
    end 


end


function VEQ.GetThatQuestToolCount(itemID, questIndex)
    local questToolCount = GetQuestToolCount(questIndex)
  
    for toolIndex = 1, questToolCount do
      local ___, stack,___,____, questItemId = GetQuestToolInfo(questIndex, toolIndex)
           if questItemId == itemID then
           return stack
      end
    end
    return 999
end


function VEQ.GroupFrames()
     if not IsPlayerActivated() then return end

   -- create table if it doesn't exist
   VEQ.MiniQuestList = VEQ.MiniQuestList or {}
   
   local duelState, _, opponent, duelTimeRemaining = GetDuelInfo()
   
   if not VEQ.SavedVars.GroupFrames or (not IsUnitGrouped("player") and HasActiveCompanion() == false and duelState ~= DUEL_STATE_DUELING and ( not VEQ.groupFinderMessage or VEQ.groupFinderMessage == "")) then
   if VEQ.MiniQuestList[16] then VEQ.MiniQuestList[16] = nil end
   if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
   VEQ.DisplayFocusedMiniQuest()
   return 
   end
   
   if VEQ.MiniQuestList[16] and VEQ.FocusedMiniQuest ~= 16 then return end
  
  local groupType = ""
    if not VEQ.groupFinderMessage or VEQ.groupFinderMessage == "" or VEQ.groupFinderFull then
      if not VEQ.groupFinderMessage then VEQ.groupFinderMessage = "" end
    groupType = VEQ.mylanguage.lang_tracker_type_group
    else
    groupType = GetString(SI_ACTIVITY_FINDER_CATEGORY_GROUP_FINDER)
  end 
    
  if IsUnitGrouped("player") then -- is in group
  
    local groupDifficultyIcon = ""
    local NMreputation = ""
    
   if IsInAdventureZone() then -- group is in night market
     NMreputation = string.format(" - %s", GetAdventureZonePlayerReputation())
     if not ZO_AdvZoneHUD_TopLevel:IsHidden() then
        ZO_AdvZoneHUD_TopLevel:SetHidden(true)
     end
     if not ZO_AdvZoneHUDTracker:IsHidden() then
        ZO_AdvZoneHUDTracker:SetHidden(true)
     end

     local NMfaction = GetUnitAdventureZoneFaction("player")
     local NMfactionColor = GetBattlegroundTeamColor(0) -- no color
     local icon = ""
     if NMfaction == ADVENTURE_ZONE_FACTION_GLITTERING_GOAD then icon = "esoui/art/stats/u49_faction_glittering_64.dds" 
         elseif NMfaction == ADVENTURE_ZONE_FACTION_THE_RUCKUS then icon = "esoui/art/stats/u49_faction_ruckus_64.dds"    
         elseif NMfaction == ADVENTURE_ZONE_FACTION_THOUSAND_EYES then icon = "esoui/art/stats/u49_faction_thousandeyes_64.dds" 
     end
     groupDifficultyIcon = NMfactionColor:Colorize(zo_iconFormatInheritColor(icon,30,30)) 
    elseif IsActiveWorldBattleground() then -- group is in battleground
       local BGalliance = GetUnitBattlegroundTeam("player")
         local BGallianceColor = GetBattlegroundTeamColor(BGalliance)
       local icon = ""
     if BGalliance == BATTLEGROUND_TEAM_FIRE_DRAKES then icon = "EsoUI/Art/Stats/battleground_alliance_badge_Fire_Drakes.dds"
     elseif BGalliance == BATTLEGROUND_TEAM_PIT_DAEMONS then icon = "EsoUI/Art/Stats/battleground_alliance_badge_Pit_Daemons.dds"
     elseif BGalliance == BATTLEGROUND_TEAM_STORM_LORDS then icon = "EsoUI/Art/Stats/battleground_alliance_badge_Storm_Lords.dds"
     end
     groupDifficultyIcon = BGallianceColor:Colorize(zo_iconFormatInheritColor(icon,30,30))
    elseif IsPlayerInAvAWorld() then -- group is in campaign
       local alliance = GetUnitAlliance("player")
     local allianceColor = GetAllianceColor(alliance)
     groupType = string.format("%s - %s", GetCampaignName(GetCurrentCampaignId()), groupType)
       local icon = ""
     if alliance == ALLIANCE_ALDMERI_DOMINION then icon = "EsoUI/Art/Contacts/social_allianceIcon_aldmeri.dds" 
         elseif alliance == ALLIANCE_EBONHEART_PACT then icon = "EsoUI/Art/Contacts/social_allianceIcon_ebonheart.dds"
         elseif alliance == ALLIANCE_DAGGERFALL_COVENANT then icon = "EsoUI/Art/Contacts/social_allianceIcon_daggerfall.dds"
     end
     groupDifficultyIcon = allianceColor:Colorize(zo_iconFormatInheritColor(icon,30,30))
    elseif IsGroupUsingVeteranDifficulty() then 
         groupDifficultyIcon = zo_iconTextFormatNoSpace("esoui/art/lfg/gamepad/gp_lfg_menuicon_veterandungeon.dds",30,30,"")
    else groupDifficultyIcon = zo_iconTextFormatNoSpace("esoui/art/tutorial/gamepad/gp_lfg_normaldungeon.dds",30,30,"")
  end 
    
  local groupLeaderRole 
  local groupText = {}
  local dpsText = {}
  local healText = {}
  local tankText = {}
    

  local maxGroupSize = GetGroupSize() --GetGroupMaxSize()
  for i=1, maxGroupSize do
    local tag = GetGroupUnitTagByIndex(i) --string.format("group%s", i)
    if  tag then
      local thisText =""
      local role = GetGroupMemberSelectedRole(tag)
    
      if GetUnitName(tag) ~= nil and GetUnitName(tag) ~= "" then -- GROUP PLAYERS
          thisText = string.format("%s\n", VEQ.DrawHealthBarName(tag))
      end
      
      if GetUnitName(string.format("%scompanion", tag)) ~= nil and GetUnitName(string.format("%scompanion", tag)) ~= "" and duelState ~= DUEL_STATE_DUELING then -- GROUP COMPANIONS 
          thisText = string.format("%s%s\n", thisText, VEQ.DrawHealthBarName(string.format("%scompanion", tag), true))
      end
      
      if IsUnitGroupLeader(tag) then -- KEEP GROUP LEADER ON TOP
          groupLeaderRole = role
          if role == LFG_ROLE_DPS then
                 table.insert(dpsText, 1, thisText)
          elseif role == LFG_ROLE_HEAL then
                table.insert(healText, 1, thisText)
          elseif role == LFG_ROLE_TANK then
                 table.insert(tankText, 1, thisText)
          else
              table.insert(groupText, 1, thisText)
          end
      else
          if role == LFG_ROLE_DPS then
               table.insert(dpsText, thisText)
          elseif role == LFG_ROLE_HEAL then
                 table.insert(healText, thisText)
          elseif role == LFG_ROLE_TANK then
                 table.insert(tankText, thisText)
          else
                table.insert(groupText, thisText)
          end
      end
    end    
  end -- end of the for loop
  
  groupText = table.concat(groupText)
  dpsText =   table.concat(dpsText)
  healText =  table.concat(healText)
  tankText =  table.concat(tankText)
  
  if groupLeaderRole == LFG_ROLE_DPS then -- reorder the list by roles
         groupText = string.format("%s%s%s%s", dpsText, healText, tankText, groupText)
  elseif groupLeaderRole == LFG_ROLE_HEAL then
         groupText = string.format("%s%s%s%s", healText, tankText, dpsText, groupText)
  elseif groupLeaderRole == LFG_ROLE_TANK then
         groupText = string.format("%s%s%s%s", tankText, healText, dpsText, groupText)
  else 
         groupText = string.format("%s%s%s%s", groupText, dpsText, healText, tankText)
  end


  if GetNextForwardCampRespawnTime() >  GetFrameTimeMilliseconds() then -- forward camp respawn timer
     local timeToForwardCampRespawn = GetNextForwardCampRespawnTime() - GetFrameTimeMilliseconds()
     local textStartTime = ZO_FormatTimeMilliseconds(timeToForwardCampRespawn, TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR)
     groupText = string.format("%s%s %s\n", groupText, zo_iconTextFormatNoSpace("esoui/art/icons/mapkey/mapkey_forwardcamp.dds",28,28,""), textStartTime)
     
  elseif IsUnitInDungeon("player") and GetGroupSize() < 4 then -- find replacement text   
       if HasActivityFindReplacementNotification() then
              groupText = string.format("%s%s?\n", groupText, GetString(SI_LFG_FIND_REPLACEMENT_ACCEPT))
              AcceptActivityFindReplacementNotification() -- Auto accepts if you are the leader
       elseif GetActivityFinderStatus() == ACTIVITY_FINDER_STATUS_QUEUED then -- FIND REPLACEMENT TIMER
               local searchStartTimeMs, searchEstimatedCompletionTimeMs = GetLFGSearchTimes()
               local timeSinceSearchStartMs = GetFrameTimeMilliseconds() - searchStartTimeMs
               local textStartTime = ZO_FormatTimeMilliseconds(timeSinceSearchStartMs, TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR)
               groupText = string.format("%s%s%s%s\n", groupText, VEQ.mylanguage.lang_LFR, VEQ.mylanguage.lang_for, textStartTime)
       end
  end
     
   if duelState ~= DUEL_STATE_DUELING then
        VEQ.LoadMiniQuestsInfo(16, 16, groupText, VEQ.groupFinderMessage, string.format("%s%s%s%s%s", groupDifficultyIcon, groupType, VEQ.mylanguage.lang_of, GetGroupSize(), NMreputation), "esoui/art/lfg/gamepad/gp_lfg_icon_groupsize.dds") 
   else -- duel while being grouped
      if duelTimeRemaining ~= 0 then
        duelTimeRemaining = string.format(" %s", ZO_FormatTimeMilliseconds(duelTimeRemaining, TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR))
    else
        duelTimeRemaining = ""
    end
    
      VEQ.LoadMiniQuestsInfo(16, 16, groupText, "", string.format("%s - %s %s", GetString(SI_TRIBUTEMATCHTYPE2), GetMapName(), duelTimeRemaining), "esoui/art/notifications/gamepad/gp_notificationicon_duel.dds")
   end
   
   VEQ.DisplayFocusedMiniQuest()

  elseif duelState == DUEL_STATE_DUELING then  -- duel without being grouped
  if duelTimeRemaining ~= 0 then
    duelTimeRemaining = string.format(" %s", ZO_FormatTimeMilliseconds(duelTimeRemaining, TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR))
  else
    duelTimeRemaining = ""
  end
  
  local groupText = ""
  local opponentReticleName = GetUnitDisplayName("reticleover")
  if opponentReticleName == opponent then
      groupText = string.format("%s%s\n", groupText, VEQ.DrawHealthBarName("reticleover"))
    VEQ.prevGrouptext = groupText
    groupText = string.format("%s%s\n", groupText, VEQ.DrawHealthBarName("player"))
  else
      groupText = VEQ.prevGrouptext or string.format("%s\n", opponent)
      groupText = string.format("%s%s\n", groupText, VEQ.DrawHealthBarName("player"))
  end

  VEQ.LoadMiniQuestsInfo(16, 16, groupText, VEQ.groupFinderMessage, string.format("%s - %s %s", GetString(SI_TRIBUTEMATCHTYPE2), GetMapName(), duelTimeRemaining), "esoui/art/notifications/gamepad/gp_notificationicon_duel.dds") 
  VEQ.DisplayFocusedMiniQuest() 
     
  elseif HasActiveCompanion() == true then -- not in group but has companion
     if VEQ.DrawHealthBarName("companion") ~= "" or VEQ.groupFinderMessage ~= "" then
          VEQ.LoadMiniQuestsInfo(16, 16, VEQ.DrawHealthBarName("companion"), VEQ.groupFinderMessage,  groupType, "esoui/art/lfg/gamepad/gp_lfg_icon_groupsize.dds")
          VEQ.DisplayFocusedMiniQuest()
     else
        if VEQ.MiniQuestList[16] then VEQ.MiniQuestList[16] = nil end
        if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
        VEQ.DisplayFocusedMiniQuest()
   end
  elseif VEQ.groupFinderMessage and VEQ.groupFinderMessage ~= "" then -- not in group but is in a group finder
          VEQ.LoadMiniQuestsInfo(16, 16, VEQ.mylanguage.lang_lfg, VEQ.groupFinderMessage,  groupType, "esoui/art/lfg/gamepad/gp_lfg_icon_groupsize.dds") 
          VEQ.DisplayFocusedMiniQuest()  
  else  -- not in group or with companion
     if VEQ.MiniQuestList[16] then VEQ.MiniQuestList[16] = nil end
     if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
     VEQ.DisplayFocusedMiniQuest()
     VEQ.prevGrouptext = nil
  end
  
end

function VEQ.GetTargetMarkerPicture(tag)
   local targetMarkerType = GetUnitTargetMarkerType(tag)
   if targetMarkerType == TARGET_MARKER_TYPE_ONE then return "EsoUI/Art/TargetMarkers/Target_Blue_Square_64.dds"
   elseif targetMarkerType == TARGET_MARKER_TYPE_TWO then return "EsoUI/Art/TargetMarkers/Target_Gold_Star_64.dds"
   elseif targetMarkerType == TARGET_MARKER_TYPE_THREE then return "EsoUI/Art/TargetMarkers/Target_Green_Circle_64.dds"
   elseif targetMarkerType == TARGET_MARKER_TYPE_FOUR then return "EsoUI/Art/TargetMarkers/Target_Orange_Triangle_64.dds"
   elseif targetMarkerType == TARGET_MARKER_TYPE_FIVE then return "EsoUI/Art/TargetMarkers/Target_Pink_Moons_64.dds"
   elseif targetMarkerType == TARGET_MARKER_TYPE_SIX then return "EsoUI/Art/TargetMarkers/Target_Purple_Oblivion_64.dds"
   elseif targetMarkerType == TARGET_MARKER_TYPE_SEVEN then return "EsoUI/Art/TargetMarkers/Target_Red_Weapons_64.dds"
   elseif targetMarkerType == TARGET_MARKER_TYPE_EIGHT then return "EsoUI/Art/TargetMarkers/Target_White_Skull_64.dds"
   else return nil
   end
end

function VEQ.UTF8ToCharArray(str)
     local charArray = {}
     local iStart = 0
     local strLen = str:len()

     local function bit(b)
           return 2 ^ (b - 1)
     end

     local function hasbit(w, b)
           return w % (b + b) >= b
     end

     local function checkMultiByte(i)
           if (iStart ~= 0) then
               charArray[#charArray + 1] = str:sub(iStart, i - 1)
               iStart = 0
           end
     end

     for i = 1, strLen do
         local b = str:byte(i)
         local multiStart = hasbit(b, bit(7)) and hasbit(b, bit(8))
         local multiTrail = not hasbit(b, bit(7)) and hasbit(b, bit(8))
         if (multiStart) then
            checkMultiByte(i)
            iStart = i
         elseif (not multiTrail) then
            checkMultiByte(i)
            charArray[#charArray + 1] = str:sub(i, i)
         end
     end

      -- process if last character is multi-byte 
     checkMultiByte(strLen + 1)
     return charArray
end

function VEQ.charArrayToString(array, limit)
  -- 04/07/2026 performance improvement:
  -- This function is called twice per group member, every second, from
  -- VEQ.DrawHealthBarName (used to build the health-percentage color split in each
  -- group/companion name shown in the group frames). It used to build the result with
  -- str = string.format("%s%s", str, v) inside the loop - since Lua strings are immutable,
  -- each iteration allocates a brand new string and copies everything built so far into it,
  -- making the whole function O(n^2) in the name's character count and generating a lot of
  -- throwaway garbage for the collector, repeated every second for every grouped unit.
  -- Collecting the characters into a table and joining once with table.concat does the same
  -- job in O(n) with a single allocation for the final string.
  local parts = {}
  local newArray = {}
  local i = 1
  for k,v in pairs(array) do
    if i <= limit then
      parts[#parts + 1] = v
    else
      table.insert(newArray, v)
    end
    i = i + 1
  end
  return table.concat(parts), newArray
end

function VEQ.DrawHealthBarName(unitTag, groupedCompanion)

   local unitName = GetUnitName(unitTag)
   if unitTag ~= "companion" and not groupedCompanion then unitName = GetUnitDisplayName(unitTag) end
   if unitName == "" then unitName = GetRawUnitName(unitTag) or "Companion" end
   if groupedCompanion then unitName = GetString(SI_COLLECTIBLECATEGORYTYPE27) end
   
   local currentHealth, maxHealth, effectiveMaxHealth = GetUnitPower(unitTag, POWERTYPE_HEALTH)
   if IsUnitDead(unitTag) then currentHealth = 0 end
   local healthPercent = math.floor(currentHealth/maxHealth*100)
   local formattedHealth = currentHealth
   if formattedHealth > 999 then
      formattedHealth = string.format("%sK", math.floor((formattedHealth/1000)*10)/10)
   end
   
   local healthPercentText = ""
   if (healthPercent ~= 100 and healthPercent ~= 0) or (maxHealth < 30000 and IsPlayerInAvAWorld()) then -- Grouped players with less than 30k health are exposed in AvA
     if healthPercent > 51 then 
          healthPercentText = string.format(" %s", formattedHealth) 
     else healthPercentText = string.format(" |cFF0000%s|r", formattedHealth)
     end 
    
   end
   
   local nameArray = VEQ.UTF8ToCharArray(unitName)

   local colorLimitLetter = math.floor(currentHealth/maxHealth*#nameArray)
   local namePartOne, newArray = VEQ.charArrayToString(nameArray, colorLimitLetter)
   local namePartTwo, _ = VEQ.charArrayToString(newArray, #newArray)
   
   local choice = zo_iconTextFormatNoSpace("esoui/art/icons/heraldrycrests_misc_blank_01.dds",28,28,"")  
   local iconText = ""
   local deadIconText = ""
   local inRange = false
   if IsUnitGroupLeader(unitTag) then choice = zo_iconTextFormatNoSpace("esoui/art/lfg/lfg_leader_icon.dds",28,28,"") end 
   if IsUnitInGroupSupportRange(unitTag) then inRange = true end 
   if IsUnitDead(unitTag) then deadIconText = zo_iconTextFormatNoSpace("esoui/art/tutorial/gamepad/gp_notificationicon_resurrect.dds",20,20,"") end
   if IsUnitReincarnating(unitTag) then deadIconText = zo_iconTextFormatNoSpace("VEQ/art/icons/ghost.dds",20,20,"") end 
   if IsUnitBeingResurrected(unitTag) and IsUnitDead(unitTag) then deadIconText = zo_iconTextFormatNoSpace("esoui/art/inventory/inventory_tabicon_soulgem_down.dds",20,20,"") end
   
   
   if unitTag == "companion" or groupedCompanion then
        iconText = zo_iconTextFormatNoSpace("esoui/art/compass/activecompanion.dds",28,28,"")

      if not IsUnitInCombat(unitTag) and not groupedCompanion then 
         currentHealth = maxHealth 
      end
      
      if IsUnitGrouped("player") then
         choice = string.format("%s%s", zo_iconTextFormatNoSpace("esoui/art/icons/heraldrycrests_misc_blank_01.dds",28,28,""), zo_iconTextFormatNoSpace("esoui/art/icons/heraldrycrests_misc_blank_01.dds",28,28,""))   -- yeah companions don't care about politics!
      else
         choice = ""
      end
      
      if currentHealth == maxHealth and not groupedCompanion then return "" end
   else
      local electionType, timeRemainingSeconds, descriptor, targetUnitTag, initiatorUnitTag = GetGroupElectionInfo() -- election choice displayed
      if timeRemainingSeconds > 0 then
        local vote = GetGroupElectionVoteByUnitTag(unitTag)
        if vote == GROUP_VOTE_CHOICE_FOR then choice = zo_iconTextFormatNoSpace("VEQ/art/icons/yes.dds",28,28,"")
        elseif vote == GROUP_VOTE_CHOICE_AGAINST then choice = zo_iconTextFormatNoSpace("VEQ/art/icons/no.dds",28,28,"")
        elseif vote == GROUP_VOTE_CHOICE_ABSTAIN then choice = zo_iconTextFormatNoSpace("VEQ/art/icons/neutral.dds",28,28,"")
        else   choice = zo_iconTextFormatNoSpace("esoui/art/icons/heraldrycrests_misc_blank_01.dds",28,28,"")
        end
      else
         
        if OSI and not OSI.isFakeOSIStub then -- support for OdySupportIcons
           -- 04/07/2026 performance improvement:
           -- This branch runs per grouped unit, every second, whenever the OdySupportIcons
           -- addon is installed. It used to do "local OPTIONS = OPTIONS or ZO_SavedVars:
           -- NewAccountWide(...)" - because OPTIONS was declared local right here, it never
           -- persisted between calls, so the "or" fallback almost never had anything cached
           -- to fall back to and ZO_SavedVars:NewAccountWide() (which allocates fresh tables
           -- and merges in defaults) ran again on essentially every single call: once per
           -- group member, every second, for as long as the player stayed grouped. Caching
           -- the loaded SavedVars table on the VEQ namespace instead means it is only built
           -- once per session and simply reused afterwards.
           VEQ.OSIOptions = VEQ.OSIOptions or ZO_SavedVars:NewAccountWide( "OSIStore", 1, nil, DEFAULT )
           local OPTIONS = VEQ.OSIOptions
           local wmConfig = {
                 ["dead"]     = OPTIONS.wmdead,
                 ["mechanic"] = false,
                 ["raid"]     = OPTIONS.raidallow,
                 ["leader"]   = OPTIONS.wmroles,
                 ["tank"]     = OPTIONS.wmroles,
                 ["healer"]   = OPTIONS.wmroles,
                 ["dps"]      = OPTIONS.wmroles,
                 ["bg"]       = OPTIONS.wmroles,
                 ["custom"]   = OPTIONS.wmuse,
                 ["unique"]   = OPTIONS.wmunique,
                 ["anim"]     = false,
                }

           local tex, col, _, hodor = OSI.GetIconDataForPlayer(GetUnitDisplayName(unitTag),wmConfig,unitTag)
           if tex then
            
              if col then 
                 local hexaColor = string.format("%s%s%s", VEQ.ConvertDecimalToHex(col[1]), VEQ.ConvertDecimalToHex(col[2]), VEQ.ConvertDecimalToHex(col[3]))
                  choice = zo_iconTextFormatNoSpace(tex,28,28,"",hexaColor)
              else
                  choice = zo_iconTextFormatNoSpace(tex,28,28,"")
              end
           end
        end
        --support for target markers
        if VEQ.GetTargetMarkerPicture(unitTag) then choice = zo_iconTextFormatNoSpace(VEQ.GetTargetMarkerPicture(unitTag),28,28,"") end
    
      end
      
        local role = GetGroupMemberSelectedRole(unitTag)
      if role == LFG_ROLE_HEAL then
             iconText = zo_iconTextFormatNoSpace("esoui/art/lfg/gamepad/lfg_roleicon_healer.dds",28,28,"")
      elseif role == LFG_ROLE_TANK then
             iconText = zo_iconTextFormatNoSpace("esoui/art/lfg/gamepad/lfg_roleicon_tank.dds",28,28,"")
      elseif role == LFG_ROLE_DPS then
             iconText = zo_iconTextFormatNoSpace("esoui/art/lfg/gamepad/lfg_roleicon_dps.dds",28,28,"")
      end
      
      if iconText == "" then -- dueling without being grouped gets no role icon so we give a class icon instead (it accidentally works for battlegrounds :) )
         local DclassID = GetUnitClassId(unitTag)
       local icon = "esoui/art/treeicons/gamepad/gp_ouroboros_indexicon.dds" -- if no class then porting ? 
       if DclassID ~= 0 and not IsGroupMemberInRemoteRegion(unitTag) then 
           icon = ZO_GetGamepadClassIcon(DclassID)
       end
          iconText = zo_iconTextFormatNoSpace(icon,28,28,"")
      end
      
      if not IsUnitOnline(unitTag) then iconText = zo_iconTextFormatNoSpace("VEQ/art/icons/offline.dds",28,28,"") colorLimitLetter = 0 end
      if IsGroupMemberInRemoteRegion(unitTag) then deadIconText = zo_iconTextFormatNoSpace("esoui/art/icons/mapkey/mapkey_portal.dds",20,20,"") end
   end
   local healthColor = "9DFE00"
   if not inRange then healthColor = "e7ffbf" end 
   if IsInAdventureZone() then -- group is in night market   
       local NMfaction = GetUnitAdventureZoneFaction(unitTag) 
       if NMfaction == 0 then 
          NMfaction = GetUnitAdventureZoneFaction("player") 
       end
       local NMfactionColor = GetBattlegroundTeamColor(0) -- no color
       if NMfaction == ADVENTURE_ZONE_FACTION_GLITTERING_GOAD then NMfactionColor = ZO_ColorDef:New(ZO_ColorDef.RGBAToFloats(224, 177, 61, 255)) -- 224 177 61 #e0b13d 
           elseif NMfaction == ADVENTURE_ZONE_FACTION_THE_RUCKUS then NMfactionColor = ZO_ColorDef:New(ZO_ColorDef.RGBAToFloats(213, 76, 47, 255))-- 213 76 47 #d5492f
           elseif NMfaction == ADVENTURE_ZONE_FACTION_THOUSAND_EYES then NMfactionColor = ZO_ColorDef:New(ZO_ColorDef.RGBAToFloats(86, 222, 219, 255)) -- 86 222 219 #56dedb
       end 
       if not inRange then NMfactionColor = NMfactionColor:Lerp(ZO_ColorDef:New(1, 1, 1, 1), 0.5) end
       healthColor = NMfactionColor:ToHex()
   elseif IsActiveWorldBattleground() then -- group is in battleground, get the battleground alliance color
       local BGalliance = GetUnitBattlegroundTeam("player") 
     local BGallianceColor = GetBattlegroundTeamColor(BGalliance)
     if not inRange then BGallianceColor = BGallianceColor:Lerp(ZO_ColorDef:New(1, 1, 1, 1), 0.5) end
       healthColor = BGallianceColor:ToHex()
   elseif IsPlayerInAvAWorld() then -- group is in campaign, get the alliance color
       local alliance = GetUnitAlliance("player")
     local allianceColor = GetAllianceColor(alliance)
     if not inRange then allianceColor = allianceColor:Lerp(ZO_ColorDef:New(1, 1, 1, 1), 0.5) end
       healthColor = allianceColor:ToHex()
   end
  return string.format("%s%s|c%s%s|r|c666666%s|r%s%s", choice, iconText, healthColor, namePartOne, namePartTwo, deadIconText, healthPercentText)
end

function VEQ.RemoveTheseMiniQuestsByIndex(index)
    for k, v in pairs(VEQ.MiniQuestList) do
        if v.index == index then
           VEQ.MiniQuestList[k] = nil 
        end
    end
    VEQ.DisplayFocusedMiniQuest()
end

function VEQ.Rumors()

  -- create table if it doesn't exist
  VEQ.MiniQuestList = VEQ.MiniQuestList or {}
  
   if not VEQ.SavedVars.Rumors then
     VEQ.RemoveTheseMiniQuestsByIndex(4) 
     return
  end
  
   local pendingRumors = GetNumPendingRumors()
   local maxPendingRumors = GetMaxPendingRumors()
   
   if pendingRumors == 0 then
       -- stop displaying & return
       VEQ.RemoveTheseMiniQuestsByIndex(4)
       return
   end
   
   local function get_last_book(tbl)
        if NonContiguousCount(tbl) == 0 then return 0 end 
        local max_val = 0 
        local book_id = 0
        for i, v in pairs(tbl) do
            if v.order > max_val then
                max_val = v.order
                book_id = v.bookId
            end
        end
        return book_id
   end
   
   
   for i = 1, GetNumRumors() do
      local rumorId = GetRumorIdAtIndex(i)
      if IsRumorPending(rumorId) then
          -- display rumor
          local rumorName = GetRumorDisplayName(rumorId)
          local rumorType = GetString(SI_GAMEPAD_QUEST_JOURNAL_RUMORS_CURRENT_MAX_LABEL).." "..pendingRumors.."/"..maxPendingRumors.." - "..GetString("SI_RUMORTYPE", GetRumorType(rumorId))
          local backgroundText = GetRumorBackgroundText(rumorId)
          local text = {}
          table.insert(text, string.format("%s\n", backgroundText))
          
          local function ReplaceColorTag(text)
              return string.gsub(text, "(|c)%x%x%x%x%x%x", "%1" .. "9DFE00") 
          end
          
          local numHints = GetNumHintsForPendingRumor(rumorId)
          for j = 1, numHints do
              local discovered = HasDiscoveredRumorHint(rumorId, j)
              local hintName = GetRumorHintDisplayName(rumorId, j)
              local hintDescription = GetRumorHintDescription(rumorId, j)
              local hintIcon = GetRumorHintIcon(rumorId, j)
              local rumorHintBookId = GetRumorHintBook(rumorId, j)
              local body = ReadLoreBook(GetLoreBookIndicesFromBookId(rumorHintBookId))
              local libraryIcon = ""
              
              if body and body ~= "" and rumorHintBookId ~= 0 then
                 libraryIcon = zo_iconFormatInheritColor("/esoui/art/menubar/gamepad/gp_playermenu_icon_lorelibrary.dds",24,24)
              end

              if discovered then
                 table.insert(text, string.format("\n%s%s%s\n%s\n", zo_iconFormatInheritColor(hintIcon,24,24), hintName, libraryIcon, hintDescription))
              end
          end
          
          text = table.concat(text)
          VEQ.LoadMiniQuestsInfo(4, rumorName, rumorName, text, rumorType, "esoui/art/journal/gamepad/gp_journal_rumors_tabicon_up.dds", 0, 0)
      else
           -- remove from display
          if VEQ.MiniQuestList[GetRumorDisplayName(rumorId)] then VEQ.MiniQuestList[GetRumorDisplayName(rumorId)] = nil end
      end
   end

   VEQ.DisplayFocusedMiniQuest()
end

function VEQ.GoldenPursuits()

  -- create table if it doesn't exist
  VEQ.MiniQuestList = VEQ.MiniQuestList or {}

  if not VEQ.SavedVars.GoldenPursuits then
     VEQ.RemoveTheseMiniQuestsByIndex(22) 
     return
  end

  local numGoldenPursuitCampaigns = GetNumActivePromotionalEventCampaigns() or 0

  if (not IsPromotionalEventSystemLocked()) and numGoldenPursuitCampaigns ~= 0 then 
       local trackedCampaignKey, trackedActivityIndex = GetTrackedPromotionalEventActivityInfo()
  
   for i=1, numGoldenPursuitCampaigns do
      local campaignKey = GetActivePromotionalEventCampaignKey(i)
      local campaignId, numActivities, numMilestones, capstoneCompletionThreshold, capstoneRewardId, capstoneRewardQuantity = GetPromotionalEventCampaignInfo(campaignKey)
      local campaignName = GetPromotionalEventCampaignDisplayName(campaignId)
      local campaignDescription = GetPromotionalEventCampaignDescription(campaignId)
      local secondsRemaining = GetSecondsRemainingInPromotionalEventCampaign(campaignKey)
      local timeLimit = GetTimeStamp() + secondsRemaining
      local timeLeft = ZO_FormatTimeMilliseconds((secondsRemaining*1000), TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR)
      local numActivitiesCompleted, isCapstoneRewardClaimed = GetPromotionalEventCampaignProgress(campaignKey)
      local numActivities = GetNumPromotionalEventCampaignActivities(campaignKey)
      local activitiesText = {}


      
      local activitiesWithRewardRemaining = 0 
      for j=1, numActivities do
        local skip
        local activityId, displayName, description, completionThreshold, rewardId, rewardQuantity = GetPromotionalEventCampaignActivityInfo(campaignKey, j)
        local progress, isRewardClaimed = GetPromotionalEventCampaignActivityProgress(campaignKey, j)
        
        if string.find(displayName, completionThreshold) then
             displayName = displayName:gsub(completionThreshold, completionThreshold - progress)
        else
             displayName = displayName:gsub(VEQ.formatThousand(completionThreshold), completionThreshold - progress)
        end
              
        local bullet = zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10)
        if NonContiguousCount(activitiesText) == 0  then
            bullet = ""
        end
        
        if trackedCampaignKey == campaignKey then
            if trackedActivityIndex == j then
                displayName = string.format("|cd4af37%s|r", displayName)
            elseif VEQ.SavedVars.DisplayTrackedGoldenPursuitOnly then
                skip = true
            end
        end

        if progress ~= completionThreshold and not skip then
           if rewardQuantity > 0  then 
               activitiesWithRewardRemaining = activitiesWithRewardRemaining + 1
               table.insert(activitiesText, string.format("%s%s%s\n", bullet, displayName, zo_iconTextFormatNoSpace("esoui/art/achievements/achievements_reward_earned.dds",20,20,"")))
           elseif numActivitiesCompleted < capstoneCompletionThreshold then
               table.insert(activitiesText, string.format("%s%s\n", bullet, displayName))
           end
        end
   end
      
      activitiesText = table.concat(activitiesText)

      
      if activitiesWithRewardRemaining ~= 0 or numActivitiesCompleted < capstoneCompletionThreshold then
        VEQ.LoadMiniQuestsInfo(22, campaignId, string.format("%s %s/%s", campaignName, numActivitiesCompleted, capstoneCompletionThreshold), activitiesText, string.format("%s %s", GetString(SI_ACTIVITY_FINDER_CATEGORY_PROMOTIONAL_EVENTS), timeLeft), "/esoui/art/lfg/gamepad/lfg_menuicon_promotionalevents.dds", nil, nil, nil, nil, timeLimit)
        VEQ.DisplayFocusedMiniQuest()
      else
          if VEQ.MiniQuestList and VEQ.MiniQuestList[campaignId] and VEQ.MiniQuestList[campaignId].index == 22 then
             VEQ.MiniQuestList[campaignId] = nil
             if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
             VEQ.DisplayFocusedMiniQuest()
          end 
              end
      end
  else
       if VEQ.FocusedMiniQuest and VEQ.MiniQuestList  and VEQ.MiniQuestList[VEQ.FocusedMiniQuest] and VEQ.MiniQuestList[VEQ.FocusedMiniQuest].index and VEQ.MiniQuestList[VEQ.FocusedMiniQuest].index == 22 then
       VEQ.MiniQuestList[VEQ.FocusedMiniQuest] = nil
       end
     if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
     VEQ.DisplayFocusedMiniQuest()
  end
end

function VEQ.CommunityEvents()
  -- create table if it doesn't exist
  VEQ.MiniQuestList = VEQ.MiniQuestList or {}
  if not VEQ.SavedVars.CommunityEvents then
     VEQ.RemoveTheseMiniQuestsByIndex(24)
     return
  end
    
  local numCommunityEvents = GetNumActiveSpectacleEvents() or 0   
  
  if numCommunityEvents ~= 0 then
    for i=1, numCommunityEvents do
      local eventId = GetActiveSpectacleEventId(i)
      local eventname = GetActiveSpectacleEventDisplayName(eventId)
      local phaseNum, totalPhases = GetActiveSpectacleEventPhaseInfo(eventId)
      local phaseName = GetActiveSpectacleEventPhaseDisplayName(eventId)
      local phaseDescription = GetActiveSpectacleEventPhaseDescription(eventId)
      local phasePercentage = math.floor(GetActiveSpectacleEventPhaseProgressPercentage(eventId) * 10000)/ 100
      local isPhaseComplete = IsCurrentActiveSpectacleEventPhaseComplete(eventId)
      local fullPhasePercentage = 100 / totalPhases
      local fullEventpercentage =  math.floor(((((phaseNum - 1) * fullPhasePercentage) + (phasePercentage/totalPhases))*100))/100
      
      local numAch = GetActiveSpectacleEventNumFeaturedAchievements(eventId)
      local allAchText = {}
      for j=1, numAch do
         local achId = GetActiveSpectacleEventFeaturedAchievementsId(eventId, j)
         local name, description, points, icon, completed = GetAchievementInfo(achId)
         local achText = description
         if not completed then
            local numCriterion = GetAchievementNumCriteria(achId)
            local totalNumCompleted = 0
            local totalNumRequired = 0
            local criterionText = {}
            for k=1, numCriterion do
              local critDescription, numCompleted, numRequired = GetAchievementCriterion(achId, k)
              totalNumCompleted = totalNumCompleted + numCompleted
              totalNumRequired = totalNumRequired + numRequired
              if numCriterion ~= 1 and numCompleted ~= numRequired then
                 table.insert(criterionText, string.format("%s%s\n", zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), critDescription))
              end
            end
            
            criterionText = table.concat(criterionText)
            
            if criterionText == "" then 
                 achText = achText:gsub(totalNumRequired, string.format("%s/%s", totalNumCompleted, totalNumRequired))
            else
                 achText = criterionText 
            end
         else
              achText = ""
         end
         
           table.insert(allAchText, string.format("%s%s\n", zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10),achText))
      end
      
      
      phaseDescription = table.concat(allAchText)
      
      if not isPhaseComplete then
         VEQ.LoadMiniQuestsInfo(24, string.format("CE%s", eventId), string.format("%s %s/%s - %s%%", eventname, phaseNum, totalPhases, fullEventpercentage), phaseDescription, string.format("%s - %s%%", phaseName, phasePercentage), "/esoui/art/lfg/gamepad/lfg_menuicon_writhingwall.dds", nil, nil, nil, nil, nil)
         VEQ.DisplayFocusedMiniQuest()
      else
           local secondsRemaining = GetSecondsRemainingUntilNextActiveSpectacleEventPhase(eventId) 
         local timeLimit = GetTimeStamp() + secondsRemaining
               local timeLeft = ZO_FormatTimeMilliseconds((secondsRemaining*1000), TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR)
         local nextPhase = SPECTACLE_EVENTS_MANAGER:GetActiveSpectacleEventNextPhaseBeginsString(eventId) or phaseName or eventname
         local timeLeftString = ZO_FormatTimeLargestTwo(secondsRemaining, TIME_FORMAT_STYLE_DESCRIPTIVE_MINIMAL_HIDE_ZEROES)
         if nextPhase and timeLeft and secondsRemaining ~= 0 then
             nextPhase = nextPhase:gsub(timeLeftString, timeLeft)
         end
         VEQ.LoadMiniQuestsInfo(24, string.format("CE%s", eventId), string.format("%s %s/%s", eventname, phaseNum, totalPhases), phaseDescription, nextPhase, "/esoui/art/lfg/gamepad/lfg_menuicon_writhingwall.dds", nil, nil, nil, nil, timeLimit)
         VEQ.DisplayFocusedMiniQuest()
      end
    end

  else
      if VEQ.FocusedMiniQuest and VEQ.MiniQuestList and VEQ.MiniQuestList[VEQ.FocusedMiniQuest] and VEQ.MiniQuestList[VEQ.FocusedMiniQuest].index and VEQ.MiniQuestList[VEQ.FocusedMiniQuest].index == 24 then
       VEQ.MiniQuestList[VEQ.FocusedMiniQuest] = nil
      end
      if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
      VEQ.DisplayFocusedMiniQuest()
  end

end



function VEQ.UpdateTimeLimitForFocusedMiniQuest() 
    if VEQ.FocusedMiniQuest and VEQ.MiniQuestList then
     local now = GetTimeStamp()
     if VEQ.MiniQuestList[VEQ.FocusedMiniQuest] and VEQ.MiniQuestList[VEQ.FocusedMiniQuest].timeLimit and VEQ.MiniQuestList[VEQ.FocusedMiniQuest].timeLimit > now then
        local secondsRemaining = VEQ.MiniQuestList[VEQ.FocusedMiniQuest].timeLimit - now
        local timeLeft = ZO_FormatTimeMilliseconds((secondsRemaining*1000), TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR)
      
      if VEQ.MiniQuestList[VEQ.FocusedMiniQuest].index == 22 then -- golden pursuits
         local title = string.format("%s %s", GetString(SI_ACTIVITY_FINDER_CATEGORY_PROMOTIONAL_EVENTS), timeLeft)
         VEQ.MiniQuestList[VEQ.FocusedMiniQuest].zone = zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, title)
      elseif VEQ.MiniQuestList[VEQ.FocusedMiniQuest].index == 8 then -- Tamriel Tomes 
         local title = string.format("%s %s", GetString(SI_GAMEPAD_TAMRIEL_TOMES_CHALLENGES), timeLeft)
         VEQ.MiniQuestList[VEQ.FocusedMiniQuest].zone = zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, title)
      elseif VEQ.MiniQuestList[VEQ.FocusedMiniQuest].index == 24 then -- Community events 
         local idString = VEQ.FocusedMiniQuest:gsub("CE", "")
         local id = tonumber(idString)
         local eventname = GetActiveSpectacleEventDisplayName(id)
         local phaseName = GetActiveSpectacleEventPhaseDisplayName(id)
         local nextPhase = SPECTACLE_EVENTS_MANAGER:GetActiveSpectacleEventNextPhaseBeginsString(id) or phaseName or eventname
         local secondsRemaining = GetSecondsRemainingUntilNextActiveSpectacleEventPhase(id) or 0
         local timeLeft = ZO_FormatTimeMilliseconds((secondsRemaining*1000), TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR)
         local timeLeftString = ZO_FormatTimeLargestTwo(secondsRemaining, TIME_FORMAT_STYLE_DESCRIPTIVE_MINIMAL_HIDE_ZEROES)
         if secondsRemaining ~= 0 then 
             nextPhase = nextPhase:gsub(timeLeftString, timeLeft)
         end
         VEQ.MiniQuestList[VEQ.FocusedMiniQuest].zone = zo_strformat(SI_WINDOW_TITLE_WORLD_MAP, nextPhase)
      end
      VEQ.DisplayFocusedMiniQuest()
     end
  end
end

function VEQ.CheckShadowySuppliers() 
    if not IsPlayerActivated() then return end
    EVENT_MANAGER:UnregisterForUpdate("CheckShadowySuppliers")
    if not VEQ.SavedVars.ShadowySuppliers or not (GetNonCombatBonus(NON_COMBAT_BONUS_SHADOWY_CONNECTIONS) == 1) then return end
  
  if GetTimeToShadowyConnectionsResetInSeconds() == 0 then
       VEQ.ShadowySuppliersAvailable = true
         VEQ.CheckRepeatableLimit("sha")
  else
       VEQ.ShadowySuppliersAvailable = false
         VEQ.CheckRepeatableLimit("sha")
      local nextCheck = math.floor(GetTimeToShadowyConnectionsResetInSeconds()/2)
        if nextCheck ~= 0 and nextCheck < 1000 then nextCheck = 1000 end
        EVENT_MANAGER:RegisterForUpdate("CheckShadowySuppliers", nextCheck, function() VEQ.CheckShadowySuppliers() end)
  end
end


function VEQ.CheckDragonguardSupplyChest()
   if not IsPlayerActivated() then return end
   if not VEQ.SavedVars.DragonguardSupplyChest or not IsAchievementComplete(2612) then return end

   if GetCurrentMapId() == 1682 then
      VEQ.SavedVars.DragonguardSupplyChestAvailable = false
      VEQ.CheckRepeatableLimit("dgsc")
      VEQ.SavedVars.LastDragonguardSupplyChestResetTime = GetTimeStamp() + GetTimeUntilNextDailyLoginRewardClaimS()
   end    
end


function VEQ.GetNearlyDoneAchievement(id)
    
  if not VEQ.SavedVars.NearlyDoneAchievements then
    if VEQ.MiniQuestList and VEQ.MiniQuestList[23] then 
         VEQ.MiniQuestList[23] = nil 
         -- update table length
        if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
    -- update miniquests displayed  
         VEQ.DisplayFocusedMiniQuest()
      end
    return
  end
  
  if id and id == 0 then
      id = nil 
      VEQ.CurrentAchievementId = nil
  end
  
  local pinned = ""
  local trackedAchievementId, trackedCriterion =  GetTrackedAchievement()
  if trackedAchievementId and trackedAchievementId ~= 0 then
      id = trackedAchievementId 
      VEQ.CurrentAchievementId = trackedAchievementId
      pinned = zo_iconFormat("/esoui/art/tutorial/gamepad/gp_trackingpin.dds",20,20)
  end  
  
  local nearlyDoneAchievements = {}
  
  if id and id == VEQ.CurrentAchievementId then
    local achievementId = id
    local name, description, points, icon, completed = GetAchievementInfo(achievementId)
    if not completed then
      local numCriterion = GetAchievementNumCriteria(achievementId)
      local totalNumCompleted = 0
      local totalNumRequired = 0
      local criterionText = {}
      for l = 1, numCriterion do
        local critDescription, numCompleted, numRequired = GetAchievementCriterion(achievementId, l)
        totalNumCompleted = totalNumCompleted + numCompleted
        totalNumRequired = totalNumRequired + numRequired
        if numCriterion ~= 1 and numCompleted ~= numRequired then
           table.insert(criterionText, string.format("%s%s\n", zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), critDescription))
        end
      end
      
      criterionText = table.concat(criterionText)

      local achievement = {}
      achievement.name = name
      achievement.description = string.format("%s\n%s", description, criterionText)
      achievement.completion = string.format("%s/%s", totalNumCompleted, totalNumRequired)
      achievement.id = achievementId
      table.insert(nearlyDoneAchievements, achievement)
    end
  
  elseif id then
       return
  else

    for i = 1, GetNumAchievementCategories() do
      local categoryName, numSubCategories, _, categoryEarnedPoints, categoryTotalPoints = GetAchievementCategoryInfo(i) 
      if categoryEarnedPoints ~= categoryTotalPoints then
        for j = 1, numSubCategories do
          local subCategoryName, numAchievements, subCategoryEarnedPoints, subCategoryTotalPoints = GetAchievementSubCategoryInfo(i, j) 
          if subCategoryEarnedPoints ~= subCategoryTotalPoints then
            for k = 1, numAchievements do 
              local achievementId = GetAchievementId(i, j, k)
              local name, description, points, icon, completed = GetAchievementInfo(achievementId)
              if not completed then
                local numCriterion = GetAchievementNumCriteria(achievementId)
                local totalNumCompleted = 0
                local totalNumRequired = 0
                local criterionText = {}
                for l = 1, numCriterion do
                  local critDescription, numCompleted, numRequired = GetAchievementCriterion(achievementId, l)
                  totalNumCompleted = totalNumCompleted + numCompleted
                  totalNumRequired = totalNumRequired + numRequired
                  if numCriterion ~= 1 and numCompleted ~= numRequired then
                      table.insert(criterionText, string.format("%s%s\n", zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), critDescription))
                  end
                end
                
                criterionText = table.concat(criterionText)
                
                local achievement = {}
                achievement.name = name
                achievement.description = string.format("%s\n%s", description, criterionText)
                achievement.completion = string.format("%s/%s", totalNumCompleted, totalNumRequired)
                achievement.id = achievementId
                table.insert(nearlyDoneAchievements, achievement)
              end
            end
          end
        end
        -- handle general subCategory
        local subCategoryName, numAchievements, subCategoryEarnedPoints, subCategoryTotalPoints = GetAchievementSubCategoryInfo(i, nil) 
          if subCategoryEarnedPoints ~= subCategoryTotalPoints then
            for k = 1, numAchievements do 
              local achievementId = GetAchievementId(i, nil, k)
              local name, description, points, icon, completed = GetAchievementInfo(achievementId)
              if name ~= "" and not completed then
                local numCriterion = GetAchievementNumCriteria(achievementId)
                local totalNumCompleted = 0
                local totalNumRequired = 0
                local criterionText = {}
                for l = 1, numCriterion do
                  local critDescription, numCompleted, numRequired = GetAchievementCriterion(achievementId, l)
                  totalNumCompleted = totalNumCompleted + numCompleted
                  totalNumRequired = totalNumRequired + numRequired
                  if numCriterion ~= 1 and numCompleted ~= numRequired then
                      table.insert(criterionText, string.format("%s%s\n", zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_bullet.dds",10,10), critDescription))
                  end
                end
                
                criterionText = table.concat(criterionText)
                
                local achievement = {}
                achievement.name = name
                achievement.description = string.format("%s\n%s", description, criterionText)
                achievement.completion = string.format("%s/%s", totalNumCompleted, totalNumRequired)
                achievement.id = achievementId
                table.insert(nearlyDoneAchievements, achievement)
              end
            end
          end
      end
    end
  end
  
  if VEQ.MiniQuestList[23] then 
         VEQ.MiniQuestList[23] = nil 
         -- update table length
        if VEQ.MiniQuestList then VEQ.updateTableLength(VEQ.MiniQuestList) end
    -- update miniquests displayed  
         VEQ.DisplayFocusedMiniQuest()
  end
  
  if #nearlyDoneAchievements > 0 then
    local randomIndex = math.random(1, #nearlyDoneAchievements)
    
    VEQ.CurrentAchievementId = nearlyDoneAchievements[randomIndex].id
    
    local persistanceLevel = GetAchievementPersistenceLevel(VEQ.CurrentAchievementId)
    local persistanceIcon = ""
      if persistanceLevel == ACHIEVEMENT_PERSISTENCE_CHARACTER then
        persistanceIcon = ZO_SECOND_SELECTED_TEXT:Colorize(zo_iconFormatInheritColor("/esoui/art/miscellaneous/gamepad/gp_charnameicon.dds", 24, 24))
      end
    
    VEQ.LoadMiniQuestsInfo(23, 23, string.format("%s %s", nearlyDoneAchievements[randomIndex].name, nearlyDoneAchievements[randomIndex].completion), nearlyDoneAchievements[randomIndex].description, string.format("%s%s", persistanceIcon, pinned..GetString(SI_GROUPFINDERPLAYSTYLE8)), "esoui/art/menubar/gamepad/gp_playermenu_icon_achievements.dds")
    VEQ.DisplayFocusedMiniQuest()
  end
end


function VEQ.UpdatebackgroundOpacity()
   -- Prevent the 1s ClockUpdate tick from spawning a second overlapping
   -- 50ms fade chain while a previous one is still running.
   if VEQ.isFadingBG or SCENE_MANAGER:GetCurrentSceneName() ==  "hud_editor_keyboard" then return end

   local currentOpacity = VEQ.bgtx:GetAlpha()
   if IsPlayerMoving() or IsUnitActivelyEngaged("player") or VEQ.bg:IsHidden() or not VEQ.SavedVars.IntelligentBackground then
      if currentOpacity ~= 0 then
          VEQ.isFadingBG = true
          VEQ.bgtx:SetAlpha(currentOpacity-0.1)
          zo_callLater(function() VEQ.isFadingBG = false VEQ.UpdatebackgroundOpacity() end, 50)
      end
   else
       if currentOpacity ~= 1 then
          VEQ.isFadingBG = true
          VEQ.bgtx:SetAlpha(currentOpacity+0.1)
          zo_callLater(function() VEQ.isFadingBG = false VEQ.UpdatebackgroundOpacity() end, 50)
       end
   end
end


-- Tests Only
function VEQ.CheckEvent(eventCode)
  d(eventCode)
end


function VEQ.CSTest()
    if CS then
        d("CraftStore loaded.")
    if VEQ.main:IsHidden() then
      d("Window No Open Open")
    else
      d("Window No Open Closed")
    end
    else
        d("CraftStore not loaded.")
    end 
end



  