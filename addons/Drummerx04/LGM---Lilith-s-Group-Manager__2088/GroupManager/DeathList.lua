----------------------------------
--Group List Keyboard
----------------------------------
local LGM = LGM or {}
local LCA = LibCombatAlerts


-- Creates a Filtered List object
local DeathList = ZO_SortFilterList:Subclass()
local TimelineList = ZO_SortFilterList:Subclass()

local DEATH_DATA = 1
local TIMELINE_DEATH = 1
local TIMELINE_SUMMARY = 2
local timelineFilter = {}
local wipeSelector = nil
local filterCount = 0


local shortCauseList = {}
local shortDeathList = {}

--Initialize a new FilteredList with a control that has $(parent)Headers and $(parent)List children
function DeathList:New(control)
   return  self:Initialize(control)
end

--Initialize a new FilteredList with a control that has $(parent)Headers and $(parent)List children
function TimelineList:New(control)
   return  self:Initialize(control)
end



function DeathList:Initialize(control)
   --Control must have $(parent)List that inherits ZO_ScrollList
   self:InitializeSortFilterList(control)
   self.label = GetControl(control, "HeadersNameName")

   ZO_ScrollList_AddDataType(self.list, DEATH_DATA, "LGMDeathRow", 30, function(control, data) self:SetupDeathRow(control, data) end)
   ZO_ScrollList_EnableHighlight(self.list, "ZO_ThinListHighlight")

   self:SetEmptyText("No Deaths... For Now!")
   self.emptyRow:ClearAnchors()
   self.emptyRow:SetAnchor(TOPLEFT, GetControl(control, "List"), TOPLEFT, 0,0)
   self.emptyRow:SetWidth(280)

   self.cumulativeDeathList = {}
   self.cumulativeCauseList = {}

   self.masterList = self.cumulativeDeathList
   local sortKeys = {
      ["name"] = { caseInsensitive = true },
      ["totalDeaths"] = { tiebreaker = "name"},
   }
   self.currentSortKey = "totalDeaths"
   self.currentSortOrder = ZO_SORT_ORDER_DOWN
   self.sortFunction = function( listEntry1, listEntry2 )
      return(ZO_TableOrderingFunction(listEntry1.data, listEntry2.data, self.currentSortKey, sortKeys, self.currentSortOrder))
   end

   self:RefreshData()


   return self
end

local function IsWipe()
   if IsUnitGrouped('player') then
      for i = 1, GetGroupSize() do
         local tag = GetGroupUnitTagByIndex(i)
         if tag and IsUnitOnline(tag) and IsGroupMemberInSameInstanceAsPlayer(tag) and not IsUnitDead(tag) then
            return false
         end
      end

      return true
   else
      return false
   end
end

local function CurrentBoss()
   for i=1,10 do
      local temp = GetUnitName(string.format("boss%d", i))
      if temp ~= "" then
         return temp
      end
   end
   return nil
end

function DeathList:RegisterEvents(enable)
   if enable then
      d("LGM Death Tracking Enabled")
      LCA.ToggleUnitIdTracking("LGM", true)
      EVENT_MANAGER:RegisterForEvent(LGM.name, EVENT_UNIT_DEATH_STATE_CHANGED, function(eventCode, unitTag, isDead) zo_callLater(function() self:DeathStateChanged(eventCode, unitTag, isDead) end, 100) end)

      EVENT_MANAGER:RegisterForEvent(LGM.name, EVENT_COMBAT_EVENT, function(...) self:OnCombatDamage(...) end)
      EVENT_MANAGER:AddFilterForEvent(LGM.name, EVENT_COMBAT_EVENT, REGISTER_FILTER_IS_ERROR, false)
      --EVENT_MANAGER:RegisterForEvent(LGM.name, EVENT_PLAYER_COMBAT_STATE, function(...) TimelineList:CombatState(...) end)
      EVENT_MANAGER:RegisterForEvent(LGM.name, EVENT_RAID_TRIAL_STARTED, function()
         if LGM.SV.markTrialStart then
            TimelineList:NewSummaryRow(zo_strformat("<<C:1>>", GetZoneNameById(GetZoneId(GetUnitZoneIndex("player")))), true)
         end
      end)
   else
      d("LGM Death Tracking Disabled")
      LCA.ToggleUnitIdTracking("LGM", false)
      EVENT_MANAGER:UnregisterForEvent(LGM.name, EVENT_UNIT_DEATH_STATE_CHANGED)

      EVENT_MANAGER:UnregisterForEvent(LGM.name, EVENT_COMBAT_EVENT)
      --EVENT_MANAGER:UnregisterForEvent(LGM.name, EVENT_PLAYER_COMBAT_STATE)
      EVENT_MANAGER:UnregisterForEvent(LGM.name, EVENT_RAID_TRIAL_STARTED)
   end
end


function TimelineList:Initialize(control)
   --Control must have $(parent)List that inherits ZO_ScrollList
   self:InitializeSortFilterList(control)
   self.label = GetControl(control, "HeadersNameName")

   ZO_ScrollList_AddDataType(self.list, TIMELINE_DEATH, "LGMTimelineRow", 30, function(control, data) self:SetupTimelineRow(control, data) end)
   ZO_ScrollList_AddDataType(self.list, TIMELINE_SUMMARY, "LGMTimelineSummaryRow", 30, function(control, data) self:SetupTimelineSummaryRow(control, data) end)
   ZO_ScrollList_EnableHighlight(self.list, "ZO_ThinListHighlight")

   self:SetEmptyText("No Deaths in Timeline")
   self.emptyRow:ClearAnchors()
   self.emptyRow:SetAnchor(TOPLEFT, GetControl(control, "List"), TOPLEFT, 0,0)
   self.emptyRow:SetWidth(280)

   self.masterList = {}

   self.wipeCount = 0

   self:RefreshData()



   return self
end

function LGM.GenerateTestData()
   local data = DeathList:NewEntry("@Drummer1", DeathList.masterList)
   data.deathData = { hehehe = 2, ccccc = 2}
   data.totalDeaths = 4
   data = DeathList:NewEntry("@Drummer2", DeathList.masterList)
   data.deathData = { hehehe = 2, ccccc = 2}
   data.totalDeaths = 4
   data = DeathList:NewEntry("@Drummer3", DeathList.masterList)
   data.deathData = { hehehe = 2, dddd = 2}
   data.totalDeaths = 4

   TimelineList:NewDeathEntry("@Drummer3")
   TimelineList:NewDeathEntry("@Drummer1")
   TimelineList:NewDeathEntry("@Drummer1")
   TimelineList:NewDeathEntry("@Drummer1")
   TimelineList:NewDeathEntry("@Drummer2")
   TimelineList:NewDeathEntry("@Drummer2")
   TimelineList:NewDeathEntry("@Drummer1")
   TimelineList:NewDeathEntry("@Drummer3")
   TimelineList:NewDeathEntry("@Drummer2")
   TimelineList:NewDeathEntry("@Drummer2")
   TimelineList:NewDeathEntry("@Drummer3")
   TimelineList:NewDeathEntry("@Drummer3")
   DeathList:RefreshFilters()
end


local damageQueues = {}
do
   local ActionResults = LGM.ActionResults

   local unknownQueue = LGM.NewDamageQueue(1)
   unknownQueue:push({hit = "", aId = 0, res = ACTION_RESULT_INVALID})


   function DeathList:OnCombatDamage( _, result, _, _, _, _, _, _, _, _, hitValue, powerType, _, _, sourceUnitId, targetUnitId, abilityId, overflow)
      local unitTag = LCA.IdentifyAllyUnitId(targetUnitId)
      if unitTag and ActionResults[result] then
         local queue = damageQueues[unitTag]
         if not queue then
            queue = LGM.NewDamageQueue(LGM.SV.recapLength)
            damageQueues[unitTag] = queue
         end
         if overflow then
            hitValue = hitValue + overflow
         end
         -- if damage was shielded, prep the shield field
         if result == ACTION_RESULT_DAMAGE_SHIELDED then
            if (hitValue > 0) then
               queue.shieldCount = queue.shieldCount + 1
               queue:push({hit = hitValue, aId = 0, res = result, shield = abilityId,})
            end
         elseif ActionResults[result] == "Heal" then
            -- If received event is a heal
            local selfHeal = 0
            if sourceUnitId == targetUnitId then
               selfHeal = hitValue
            end

            local row = queue:peek()
            if row and row.heal then
               row.hit = row.hit + hitValue
               row.selfHeal = row.selfHeal + selfHeal

               local aIdHealTotal = row.aId[abilityId]
               if aIdHealTotal then
                  row.aId[abilityId] = aIdHealTotal + hitValue
               else
                  row.aId[abilityId] = hitValue
               end
            else
               queue:push({hit = hitValue, aId = {[abilityId] = hitValue}, res = result, heal = true, selfHeal = selfHeal})
            end
         else
            -- if the previous damage was shielded then ammend the shielded fields
            if queue.shieldCount > 0 then
               queue:ammend(abilityId)
            end
            -- if the hit is > 0 then it was either penetrative damage, or a regular hit
            if hitValue > 0 then

               queue:push({hit = hitValue, aId = abilityId, res = result,})
            end
         end
      end
   end


   function TimelineList:EnterRow(row)
      ZO_ScrollList_MouseEnter(self.list, row)

      local data = ZO_ScrollList_GetData(row)
      if data then
         if data.queue then
            LGM.recapPopup:Attach(data.name, data.queue)
         elseif not data.deathList then
            LGM.recapPopup:Attach(data.name, unknownQueue)
         end
      end

      self.mouseOverRow = row

   end



   function DeathList:DumpMapping()
      TimelineList:NewSummaryRow("Begin Dump", true)
      if IsUnitGrouped('player') then
         for i = 1, GetGroupSize() do
            self:DeathStateChanged(nil,GetGroupUnitTagByIndex(i), true, true)
         end
      else
         DeathList:DeathStateChanged(nil, 'player', true, true)
      end
      TimelineList:NewSummaryRow("End Dump", true)
      TimelineList:RefreshFilters()
   end

   function DeathList:ClearLists(all)
      if all then
         self.cumulativeCauseList = {}
         self.cumulativeDeathList = {}
         self.masterList = self.cumulativeDeathList

         self:RefreshData()
      end

   end

   local results = {
      [ACTION_RESULT_DIED] = "DIED",
      [ACTION_RESULT_DIED_XP] = "XP",
      [ACTION_RESULT_KILLING_BLOW] = "ACTION_RESULT_KB"
   }

   function TimelineList:RowToString(data)
      local output = string.format("<LGM:%s,%s>", data.name, os.date("%H:%M:%S", data.time))
      local format = "%s(%.1fs) %s -- %d (%s)"

      if data.queue then
         for e in data.queue:iter() do
            output = string.format(format, output, (data.queue.time - e.time) / 1000, LCA.GetAbilityName(e.aId), e.hit,
                                   (e.shield and LCA.GetAbilityName(e.shield) or tostring(ActionResults[e.res])))
            format = "%s => (%.1fs) %s -- %d (%s)"
         end
      else
         output = "Unknown Cause"
      end



      return output
   end

end

do
   local wipePending
   local bossName
   local function PostWipeToTimeline()
      TimelineList:NewSummaryRow(bossName or "Group Wipe")
      wipePending = false
   end
   -- Death Handler
   function DeathList:DeathStateChanged(_, unitTag, isDead, override)
      local isGrouped = IsUnitGrouped("player")
      if isDead and ((isGrouped and unitTag:byte(1) == 0x67) or (not isGrouped and (unitTag == "player" or unitTag == "companion"))) then

         local name = LCA.GetNameFromUnitTag(unitTag)
         local q = damageQueues[unitTag]
         damageQueues[unitTag] = nil


         local abilityName = "Unknown Cause"
         -- Update TimelineList
         if q and q:trim() and ((GetGameTimeMilliseconds() - q.time) < 1500 or override and q:peek()) then
            -- trim off extraneous heal elements
            TimelineList:NewDeathEntry(name, q)
            abilityName = LCA.GetAbilityName(q:peek().aId)
            if LGM.SV.livePopupLength > 0 then
               LGM.recapPopup:Attach(name, q, true)
            end
         else
            TimelineList:NewDeathEntry(name, nil)
         end

         --Update Total Deaths List
         ----------------------------------------------------
         if not override then
            local data = self.cumulativeDeathList[name]
            if not data then
               data = self:NewEntry(name, self.cumulativeDeathList, true)
            end
            data.totalDeaths = data.totalDeaths + 1

            if data.deathData[abilityName] then
               data.deathData[abilityName] = data.deathData[abilityName] + 1
            else
               data.deathData[abilityName] = 1
            end

            -- Update Total Cause List
            ----------------------------------------------------
            data = self.cumulativeCauseList[abilityName]
            if not data then
               data = self:NewEntry(abilityName, self.cumulativeCauseList, true)
            end
            if data.deathData[name] then
               data.deathData[name] = data.deathData[name] + 1
            else
               data.deathData[name] = 1
            end
            data.totalDeaths = data.totalDeaths + 1

            -- Update cumulative death list
            ----------------------------------------------------
            data = shortDeathList[name]
            if not data then
               data = self:NewEntry(name, shortDeathList, true)
            end
            data.totalDeaths = data.totalDeaths + 1

            if data.deathData[abilityName] then
               data.deathData[abilityName] = data.deathData[abilityName] + 1
            else
               data.deathData[abilityName] = 1
            end

            -- Update cumulative cause list
            ----------------------------------------------------
            data = shortCauseList[abilityName]
            if not data then
               data = self:NewEntry(abilityName, shortCauseList, true)
            end
            if data.deathData[name] then
               data.deathData[name] = data.deathData[name] + 1
            else
               data.deathData[name] = 1
            end
            data.totalDeaths = data.totalDeaths + 1

            -- Place Wipe Marker
            ----------------------------------------
            if not wipePending and IsWipe() then
               wipePending = true
               bossName = CurrentBoss()
               zo_callLater(PostWipeToTimeline, 1000)
            end

            self:RefreshData()
         end
      end
   end

end


function DeathList:UpdateRow(data)
   local control = data.control
   if not control then return end

   local bg = GetControl(control, "BG")
   GetControl(control,"Number"):SetText(data.totalDeaths)
   if timelineFilter[data.name] then
      bg:SetTexture("EsoUI/Art/Contacts/social_list_bgStrip_highlight.dds")
   else
      bg:SetTexture("EsoUI/Art/Contacts/social_list_bgStrip.dds")
   end

end

do
   local noNewIndexes = { __newindex = function() end }
   -- Create a secondary table to store elements to be associated with Saved
   -- Variable entries, but not actually stored within it
   local function defaults(name)
      return setmetatable({ sortIndex = -1, control = false, name = name, deathData = {}, totalDeaths = 0,}, noNewIndexes)
   end

   function DeathList:NewEntry(name, updateList, skipRefresh)
      local data =  defaults(name)
      updateList[name] = data

      --      table.insert(ZO_ScrollList_GetDataList(self.list), ZO_ScrollList_CreateDataEntry(DEATH_DATA, data))
      if not skipRefresh then
         self:RefreshData()
      end

      return data
   end
end

--Callback called by "ZO_ScrollList_CreateDataEntry" to setup a row
function DeathList:SetupDeathRow( control, data )
   control.data = data
   data.control = control

   GetControl(control, "Name"):SetText(data.name)


   self:SetupRow(control, data)
   self:UpdateRow(data)
end

--Callback called by "ZO_ScrollList_CreateDataEntry" to setup a row
function TimelineList:SetupTimelineRow( control, data )
   control.data = data
   data.control = control

   GetControl(control, "Name"):SetText(data.name)
   GetControl(control, "Time"):SetText(os.date("%H:%M:%S", data.time))
   self:SetupRow(control, data)
end

function TimelineList:SetupTimelineSummaryRow( control, data )
   control.data = data
   data.control = control
   self:SetupRow(control, data)

   local bg = GetControl(control, "BG")
   if wipeSelector == data then
      bg:SetTexture("EsoUI/Art/Contacts/social_list_bgStrip_highlight.dds")
   else
      bg:SetTexture("EsoUI/Art/Contacts/social_list_bgStrip.dds")
   end
   local wipeCount = GetControl(control, "WipeCount")
   local timeControl = GetControl(control, "Time")
   local nameControl = GetControl(control, "Name")

   if data.isDebug then
      nameControl:SetColor(0.1, 0.8, 0.2)
      wipeCount:SetColor(0.1, 0.8, 0.2)
      timeControl:SetColor(0.1, 0.8, 0.2)
   else
      nameControl:SetColor(0.9, 0.8, 0.2)
      timeControl:SetColor(0.9, 0.8, 0.2)
      wipeCount:SetColor(0.9, 0.5, 0.2)
   end


   wipeCount:SetText(tostring(data.count))
   nameControl:SetText(data.name)
   timeControl:SetText(os.date("%H:%M:%S", data.time))


end


function DeathList:BuildMasterList()
   local scrollData = ZO_ScrollList_GetDataList(self.list)
   ZO_ClearNumericallyIndexedTable(scrollData)

   for name, data in pairs(self.masterList) do
      table.insert(scrollData, ZO_ScrollList_CreateDataEntry(DEATH_DATA, data))
   end
end


function TimelineList:BuildMasterList()
   -- local scrollData = ZO_ScrollList_GetDataList(self.list)
   -- ZO_ClearNumericallyIndexedTable(scrollData)

   --for i, data in ipairs(self.masterList) do
   -- for name, data in pairs(self.masterList) do
   --    table.insert(scrollData, ZO_ScrollList_CreateDataEntry(TIMELINE_DEATH, data))
   -- end
end

-- function DeathList:FilterScrollList() end
function TimelineList:FilterScrollList()
   local scrollData = ZO_ScrollList_GetDataList(self.list)
   ZO_ClearNumericallyIndexedTable(scrollData)

   -- if filtering on player names
   for i, data in ipairs(self.masterList) do
      if filterCount == 0 or data.show or timelineFilter[data.name] or
         (data.queue and timelineFilter[LCA.GetAbilityName(data.queue:peek().aId)]) or
         (not data.queue and timelineFilter["Unknown Cause"])
      then
         table.insert(scrollData, ZO_ScrollList_CreateDataEntry(data.dataEntry.typeId, data))
      end
   end
end

function DeathList:SortScrollList()
   local scrollData = ZO_ScrollList_GetDataList(self.list)
   table.sort(scrollData, self.sortFunction)
end


function DeathList:SummaryToString()
   local output = "<LGM> "
   local format
   local scrollData = ZO_ScrollList_GetDataList(self.list)
   for i, data in ipairs(scrollData) do
      format = (next(scrollData, i)) and "%s%s: %d, " or "%s%s: %d"
      output = string.format(format, output, data.data.name, data.data.totalDeaths)
   end

   return output
end

function DeathList:RowToString(data)
   local output = string.format("<LGM> %s:{", data.name)
   local format

   for name, deaths in pairs(data.deathData) do
      format = (next(data.deathData, name)) and "%s%s: %d, " or "%s%s: %d}"
      output = string.format(format, output, name, deaths)
   end

   return output
end

local function ResetWipeRow()
   if wipeSelector then
      local data = wipeSelector
      wipeSelector = nil
      TimelineList:SetupTimelineSummaryRow(data.control, data)
   end
end


function LGM_DeathPanel_ToggleButtonHandler(control, button)
   if button == 1 then
      if DeathList.masterList ~= DeathList.cumulativeDeathList then
         DeathList:LoadDataTable(DeathList.cumulativeDeathList, "Players")
      else
         DeathList:LoadDataTable(DeathList.cumulativeCauseList, "Causes")
      end
      ResetWipeRow()
   elseif button == 2 then
      CHAT_SYSTEM.textEntry:SetText(DeathList:SummaryToString())
      CHAT_SYSTEM:Maximize()
      CHAT_SYSTEM.textEntry:Open()
      CHAT_SYSTEM.textEntry:FadeIn()
   end
end


function DeathList:ExitRow(row)

   LGM.summaryPopup:Detach()
   self.mouseOverRow = nil
   ZO_Options_OnMouseExit(row)

end


function DeathList:EnterRow(row)

   --ZO_ScrollList_MouseEnter(self.list, row)

   local data = ZO_ScrollList_GetData(row)
   if data then
      LGM.summaryPopup:Attach(row, data)
   end

   self.mouseOverRow = row

end


function TimelineList:ExitRow(row)
   ZO_ScrollList_MouseExit(self.list, row)

   self.mouseOverRow = nil
   local data = ZO_ScrollList_GetData(row)
   if data and data.queue then
      LGM.recapPopup:Detach()
   end
   ZO_Options_OnMouseExit(row)

end


function LGM_DeathList_OnInitialized(self)
   LGM.deathList = DeathList:New(self)
end


do
   local noNewIndexes = { __newindex = function() end }
   -- Create a secondary table to store elements to be associated with Saved
   -- Variable entries, but not actually stored within it
   local function NewTLDeathRow(name, q, show)
      --setmetatable(
      return { sortIndex = -1, control = false, name = name, queue = q, show = show, time = os.time() }--, noNewIndexes)
   end

   function TimelineList:NewDeathEntry(name, queue, skipRefresh)
      local data =  NewTLDeathRow(name, queue)
      table.insert(self.masterList, 1 ,data)

      table.insert(ZO_ScrollList_GetDataList(self.list),1 ,ZO_ScrollList_CreateDataEntry(TIMELINE_DEATH, data))

      if not skipRefresh then
         self:RefreshFilters()
      end

      return data
   end
   local debugCount = 0
   function TimelineList:NewSummaryRow(name, isDebug)
      local data =  NewTLDeathRow(name, false, true)
      if isDebug then
         data.isDebug = true
         if name ~= "End Dump" then
            debugCount = debugCount + 1
         end
         data.count = debugCount
      else
         self.wipeCount = self.wipeCount + 1
         data.count = self.wipeCount
      end




      -- store data needed to display summaries
      data.deathList = shortDeathList
      data.causeList = shortCauseList

      -- Reset short term data
      shortCauseList = {}
      shortDeathList = {}

      table.insert(self.masterList, 1 ,data)
      table.insert(ZO_ScrollList_GetDataList(self.list),1 , ZO_ScrollList_CreateDataEntry(TIMELINE_SUMMARY, data))
      --ZO_ScrollList_Commit(self.list)

      self:RefreshFilters()

      return data
   end
end


function TimelineList:ClearList()
   local scrollData = ZO_ScrollList_GetDataList(self.list)
   ZO_ClearNumericallyIndexedTable(scrollData)

   self.masterList = {}
   self:RefreshFilters()
end



function TimelineList:SummaryToString()
   local output = "<LGM> "
   local format
   local scrollData = ZO_ScrollList_GetDataList(self.list)
   for i, data in ipairs(scrollData) do
      format = (next(scrollData, i)) and "%s%s: %d, " or "%s%s: %d"
      output = string.format(format, output, data.data.name, data.data.totalDeaths)
   end

   return output
end


function TimelineList:RowContextMenu(data)
   ClearMenu()

   AddMenuItem("Print To Chat", function()
                  CHAT_SYSTEM.textEntry:SetText(self:RowToString(data))
                  CHAT_SYSTEM:Maximize()
                  CHAT_SYSTEM.textEntry:Open()
                  CHAT_SYSTEM.textEntry:FadeIn()
   end)
   --AddMenuItem("Dump Data Table", function() d('--------',data) end)

   if(ZO_Menu_GetNumMenuItems() > 0) then
      ShowMenu()
   end

end

function DeathList:RowContextMenu(data)
   ClearMenu()
   --AddMenuItem(GetString(SI_CHAT_PLAYER_CONTEXT_WHISPER), function() StartChatInput(nil, CHAT_CHANNEL_WHISPER, data.name) end)
   AddMenuItem("Print To Chat", function()
                  CHAT_SYSTEM.textEntry:SetText(self:RowToString(data))
                  CHAT_SYSTEM:Maximize()
                  CHAT_SYSTEM.textEntry:Open()
                  CHAT_SYSTEM.textEntry:FadeIn()
   end)
   --   AddMenuItem("Dump Data Table", function() d('--------',data) end)
   -- AddMenuItem("grab", function() testv = data.control end)
   if(ZO_Menu_GetNumMenuItems() > 0) then
      ShowMenu()
   end

end

function DeathList:LoadDataTable(list, label)
   self.masterList = list
   self.label:SetText(label)
   self:RefreshData()
end

function DeathList:MouseClickHandler(control, button)
   local data = control.data
   if button == 1 then

      if timelineFilter[data.name] then
         timelineFilter[data.name] = nil
         filterCount = filterCount - 1
      else
         timelineFilter[data.name] = true
         filterCount = filterCount + 1
      end
      self:RefreshFilters()
      --d(timelineFilter)
      TimelineList:RefreshFilters()
   elseif button == 2 then

      self:RowContextMenu(data)
   end
end


function TimelineList:MouseClickHandler(control, button)
   local data = control.data
   if button == 1 then -- Load or reset causes in the DeathList
      if data.deathList then
         if DeathList.masterList ~= data.deathList then
            ResetWipeRow()
            wipeSelector = data
            DeathList:LoadDataTable(data.deathList, "TL Players")
         else
            wipeSelector = nil
            DeathList:LoadDataTable(DeathList.cumulativeDeathList, "Players")
         end
         self:SetupTimelineSummaryRow(control, data)
      end
   elseif button == 2 then -- Load or reset causes in the DeathList
      if data.causeList then
         if data.causeList ~= DeathList.masterList then
            ResetWipeRow()
            wipeSelector = data
            DeathList:LoadDataTable(data.causeList, "TL Causes")
         else
            wipeSelector = nil
            DeathList:LoadDataTable(DeathList.cumulativeCauseList, "Causes")
         end
         self:SetupTimelineSummaryRow(control, data)
      else
         self:RowContextMenu(data)
      end
   end
end


function LGM_DeathPanel_ResetButton(control, button, shift)
   local data = control.data
   if button == 1 then
      if shift then
         TimelineList:NewSummaryRow(CurrentBoss() or "Separator", true)
      else
         DeathList:ClearLists(true)
         TimelineList:ClearList()
         TimelineList.wipeCount = 0
      end
   elseif button == 2 then
      if shift then
         LGM.recapPopup:ToggleAbilityIdDisplay()
      else
         timelineFilter = {}
         filterCount = 0
         TimelineList:RefreshFilters()
         DeathList:RefreshFilters()
      end
   end
end


function LGM_TimelineList_OnInitialized(self)
   LGM.timelineList = TimelineList:New(self)
end






