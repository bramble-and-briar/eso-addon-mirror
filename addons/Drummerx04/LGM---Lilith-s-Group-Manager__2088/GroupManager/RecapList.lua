local LGM = LGM or {}
local LCA = LibCombatAlerts

local RecapList = {}
local SummaryList = {}

local ActionResults = LGM.ActionResults

function RecapList:GetRowAttackDescription(abilityId)
   return LGM.SV.displayAbilityIds
      and string.format("%d - %s", abilityId,LCA.GetAbilityName(abilityId))
      or  LCA.GetAbilityName(abilityId)
end

function RecapList:ToggleAbilityIdDisplay()
   LGM.SV.displayAbilityIds = not LGM.SV.displayAbilityIds
end

function RecapList:Initialize(base)
   self.base = base
   self.rows = {}
   self.index = 0
   self.popupAnimation = ANIMATION_MANAGER:CreateTimelineFromVirtual("LGM_DeathPopupDisplay")
   self.popupAnimation:GetAnimation(1):SetAnimatedControl(base)
   self.popupAnimation:GetAnimation(2):SetAnimatedControl(base)
   self.popupAnimation:SetHandler("OnStop", function() return self:Detach() end)

   -- Set the popup to draw over the rest of the addon
   base:SetDrawLayer(DL_OVERLAY)
   base:SetDrawTier(DT_HIGH)
   GetControl(base, "BG"):SetDrawLayer(DL_OVERLAY)
   GetControl(base, "BG"):SetDrawTier(DT_MEDIUM)
   base:SetWidth(450)
   base:SetHeight(32)

   -- Set new popup location and save to Saved Vars
   base:SetHandler("OnMoveStop", function()
                      local x, y = self.base:GetLeft(), self.base:GetTop()
                      LGM.SV.livePopupAnchorPoint = {x,y}
                      LGM_LivePopupAnchor:ClearAnchors()
                      LGM_LivePopupAnchor:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
   end)
   self.initialized = false

   return self
end

function RecapList:Detach()
   if self.popupAnimation:IsPlaying() then
      return self.popupAnimation:Stop()
   end

   for _,row in ipairs(self.rows) do
      row:SetHidden(true)
   end
   self.base:SetHidden(true)
end
do
   local prev
   function RecapList:AdjustRowCount(size)
      if self.index < size then

         for i=self.index, size - 1 do
            local row = CreateControlFromVirtual("LGMDeathRecapRow", self.base, "LGMRecapRow", self.index)
            self.index = self.index + 1
            row:ClearAnchors()
            if prev then
               row:SetAnchor(TOPLEFT, prev, BOTTOMLEFT, 0,2)
            else
               row:SetAnchor(TOPLEFT, self.base, TOPLEFT, 0,34)
            end
            table.insert(self.rows, row)
            prev = row
         end
      end
   end
end

local function SortHealElements(a,b)
   return a[2] > b[2]
end

-- Process the healing data stored within a healing row
local healsTable, namesTable -- scratch tables
local function ProcessHealing(data)
   if not data.healsProcessed then
      healsTable = healsTable or {}
      namesTable = namesTable or {}
      for k,v in pairs(data.aId) do
         table.insert(healsTable, {k,v})
      end
      table.sort(healsTable, SortHealElements)
      data.aId = healsTable[1][1]
      for i,v in ipairs(healsTable) do
         table.insert(namesTable, LCA.GetAbilityName(v[1]))
      end
      data.label = table.concat(namesTable, ", ")
      data.healsProcessed = true
      ZO_ClearTable(healsTable)
      ZO_ClearTable(namesTable)
   end
end

function RecapList:Attach(name, q, isLivePopup)
   if not q then return end
   self:AdjustRowCount(q:size())


   if self.popupAnimation:IsPlaying() then
      self.popupAnimation:Stop()
   end
   self.base:ClearAnchors()

   if isLivePopup then
      self.base:SetParent(LGM_LivePopupAnchor)
      self.base:SetAnchor(TOPLEFT, LGM_LivePopupAnchor, TOPLEFT, 0, 0)
   else
      self.base:SetParent(GroupManagerPanel)
      self.base:SetAnchor(TOPRIGHT, GroupManagerPanel, TOPLEFT, -100, 0)
   end


   -- Set Recap Name
   GetControl(self.base, "Name"):SetText(tostring(name))

   local i = 0
   for data in q:iter(isLivePopup and LGM.SV.livePopupLength) do
--      if not isLivePopup or q.time - data.time < 5000 then
         i = i + 1
         local row = self.rows[i]

         local AbilityName = GetControl(row, "AbilityName")
         local HitValue = GetControl(row, "HitValue")
         local Delta = GetControl(row, "Delta")
         if data.heal then
            -- Process healing row
            ProcessHealing(data)
            AbilityName:SetColor(0.2,0.8,0.1)
            AbilityName:SetText(data.label)

            HitValue:SetColor(0.2,0.8,0.1)
            Delta:SetHidden(true)
         elseif data.res == ACTION_RESULT_INVALID then
            AbilityName:SetColor(0.9,0.9,0.9)
            AbilityName:SetText("Unknown Cause")
            Delta:SetHidden(true)
         else -- Get name and Icon Normally
            AbilityName:SetColor(0.9,0.9,0.9)
            AbilityName:SetText(self:GetRowAttackDescription(data.aId))
            HitValue:SetColor(0.9,0.9,0.9)
            --Only display Delta time if not a heal row
            Delta:SetHidden(false)
            Delta:SetText(string.format("%.1fs", (data.time - q.time) / 1000))
         end

         GetControl(row, "DamageIcon"):SetTexture(GetAbilityIcon(data.aId))
         HitValue:SetText(data.hit)
         if data.shield then -- Process shield row
            GetControl(row, "HitType"):SetHidden(true)
            GetControl(row, "ShieldIcon"):SetHidden(false)
            GetControl(row, "ShieldIcon"):SetTexture(GetAbilityIcon(data.shield))
         elseif data.res == ACTION_RESULT_INVALID then
            GetControl(row, "HitType"):SetHidden(true)
            GetControl(row, "ShieldIcon"):SetHidden(true)
         else
            -- process normal damage row
            GetControl(row, "HitType"):SetHidden(false)
            GetControl(row, "HitType"):SetText(string.format("- %s",ActionResults[data.res]))
            GetControl(row, "ShieldIcon"):SetHidden(true)
         end
         row:SetHidden(false)
         row:SetAlpha(1.0)


  --    end
   end
   local height = i * 32 + 40
   self.base:SetHeight(height)

   self.base:SetHidden(false)
   if isLivePopup then
      self.popupAnimation:PlayFromStart()
   else
      self.base:SetAlpha(1.0)
   end


end

function RecapList:SetMoveMode(enable)
   local window = self.base
   window:SetMouseEnabled(enable)
   window:SetMovable(enable)
   window:SetAlpha(enable and 1.0 or 0)
   window:SetHidden(not enable)
   window:ClearAnchors()
   if enable then
      window:SetParent(LGM_LivePopupAnchor)
      window:SetAnchor(TOPLEFT, LGM_LivePopupAnchor, TOPLEFT, 0, 0)
   end
end

function SummaryList:Initialize(base)
   self.base = base
   self.rows = {}
   self.index = 0

   base:SetDrawLayer(DL_OVERLAY)
   base:SetDrawTier(DT_HIGH)

   GetControl(base, "BG"):SetDrawLayer(DL_OVERLAY)
   GetControl(base, "BG"):SetDrawTier(DT_MEDIUM)
   base:SetWidth(280)

   self.initialized = false

   return self
end

function SummaryList:Detach()
   for _,row in ipairs(self.rows) do
      row:SetHidden(true)
   end
   self.base:SetHidden(true)
end


function SummaryList:Attach(control, data)

   local prev
   local i = 0
   for id, count in pairs(data.deathData) do
      i = i + 1
      local row = self.rows[i]
      if not row then
         row = CreateControlFromVirtual("LGMDeathSummaryRow", self.base, "LGMSummaryRow", i)
         self.rows[i] = row

         -- Set Anchor of new row
         row:ClearAnchors()
         if prev then
            row:SetAnchor(TOPLEFT, prev, BOTTOMLEFT, 0,2)
         else
            row:SetAnchor(TOPLEFT, self.base, TOPLEFT, 0,4)
         end

      end
      -- Storing abilityIds is not a good idea. Store by name is better.

      GetControl(row, "Count"):SetText(string.format("%d", count))
      --GetControl(row, "Icon"):SetTexture(id)
--      GetControl(row, "Icon"):SetHidden(false)
      GetControl(row, "Name"):SetText(id)

      -- GetControl(row, "Count"):SetText(string.format("%d", count))
      -- GetControl(row, "Icon"):SetHidden(true)
      -- GetControl(row, "Name"):SetText(id)

      row:SetHidden(false)
      prev = row
   end

   local height = i * 32 + 8

   self.base:ClearAnchors()
   self.base:SetHeight(height)
   self.base:SetAnchor(TOPLEFT, control, TOPRIGHT, 0, - (height/3))



   self.base:SetHidden(false)

end





function LGM_RecapList_Initialized(control)
   LGM.recapPopup = RecapList:Initialize(control)
end

function LGM_SummaryList_Initialized(control)
   LGM.summaryPopup = SummaryList:Initialize(control)
end
