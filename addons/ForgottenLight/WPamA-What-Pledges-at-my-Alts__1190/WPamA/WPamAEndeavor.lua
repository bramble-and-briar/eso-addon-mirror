local WPamA = WPamA
--local nvl = WPamA.SF_Nvl
--=========================================================================
--================= Endeavors Section =====================================
--=========================================================================
local EndeavorDataOnServer = {}
local EndeavorDailyConditions, EndeavorWeeklyConditions, EndeavorSeasonConditions = {}, {}, {}
-- structure [ i ] = { Ind = taIndex, Name = "", Progress = "", Reward = "", Value = 0, isComplete = false }
local EndeavorDataReady = false
local EndeavorChatMessageText = { D = "", W = "", S = "" }
local EndeavorChatFormatter = "<<1>>: <<2>> / <<3>><<4>>"
local RewardTextFormatter = "<<1>><<2>>|t18:18:<<3>>:inheritcolor|t "
local RewardTimeFormatter = WPamA.Textures.GetTexture(6, 20, true) .. " <<1>>"
--
local RemainActivityProgress = { Endvr = {}, Promo = {} }
-- structure [ taskTypeName ] = { Remaining Activity Progress | Max Progress }
--
local PromoActivityChatMessageText = ""
local PromoEventActivity = {
   Campaign = { Key = 0, Name = "", Progress = "", Reward = "", EndTS = 0, isComplete = false },
   Conditions = {},
   Index = {},
--   PromoActivityReady = false ??
  }
--[[ structure [ campaignIndex ] = {
  Campaign = { Key = 0, Name = "", Progress = "", Reward = "", EndTS = 0, isComplete = false },
  Conditions = { Ind = paIndex, Name = "", Progress = "", Reward = "", Value = 0, isComplete = false },
  Index = { [ paIndex ] = cond_ind }
  } --]]
local ChatMessageBuffer = {}

local function PostMessageBufferToChat()
  EVENT_MANAGER:UnregisterForUpdate(WPamA.Name .. "PromoChat")
  local iconEndvr = WPamA.Textures.GetTexture(68, GetChatFontSize(), true)
  local iconPromo = WPamA.Textures.GetTexture(47, GetChatFontSize(), true)
  -- Buffer structure { AT = ActivityType, Name = TaskName, Num = Num, Max = MaxNum,
  --                    Color = chatColor, Channel = chatChannel, EndvrRAP = nil, PromoRAP = nil }
  for _, Task in pairs(ChatMessageBuffer) do
    local txt = ""
    local remainTxt = " (<<1>><<2>>)" -- only one type (Endvr or Promo) exists
    if Task.EndvrRAP and Task.PromoRAP then
      remainTxt = " (<<1>>, <<2>>)" -- both types (Endvr and Promo) exist
    end
    local txtEndvr, txtPromo = "", ""
    if Task.EndvrRAP and (Task.Max < Task.EndvrRAP) then
      txtEndvr = zo_strformat("<<1>><<2>>", iconEndvr, Task.EndvrRAP)
    end
    if Task.PromoRAP and (Task.Max < Task.PromoRAP) then
      txtPromo = zo_strformat("<<1>><<2>>", iconPromo, Task.PromoRAP)
    end
    remainTxt = zo_strformat(remainTxt, txtEndvr, txtPromo)
    remainTxt = remainTxt:gsub(" %(%)", "")
    txt = zo_strformat(EndeavorChatFormatter, Task.Name, Task.Num, Task.Max, remainTxt)
    if Task.Color ~= "" then
      txt = zo_strformat("|c<<1>><<2>>|r", Task.Color, txt)
    end
    WPamA:PostChatMessage(txt, Task.Channel)
    ---
    if WPamA.SV_Main.AutoClaimEndeavorReward and
       (Task.AT == "Endvr") and (Task.Num >= Task.Max) then
      txt = GetString(SI_CLAIMREWARDRESULT1) -- "Successfully claimed reward"
      if Task.Color ~= "" then
        txt = zo_strformat("|c<<1>><<2>>|r", Task.Color, txt)
      end
      txt = zo_strformat("<<1>> <<2>>", iconEndvr, txt)
      WPamA:PostChatMessage(txt, Task.Channel)
    end
  end -- for TaskType
  ChatMessageBuffer = {}
end -- PostMessageBufferToChat end

local function PostProgressToChat(ActivityType, TaskName, Num, MaxNum, chatColor, chatChannel)
  local typedTaskName = TaskName:gsub(" (%d+)", " #")
  local maxProgressPromo = RemainActivityProgress.Promo[typedTaskName] or 0
  local maxProgressEndvr = RemainActivityProgress.Endvr[typedTaskName] or 0
  if ChatMessageBuffer[typedTaskName] then
    local msg = ChatMessageBuffer[typedTaskName]
    if msg.Max == MaxNum then
      --- the same Task with new progress ---
      if msg.Num < Num then msg.Num = Num end
    else
      --- a similar Task with a different progress ---
      if (not msg.PromoRAP) and (ActivityType == "Promo") then
        if maxProgressPromo > 0 then msg.PromoRAP = maxProgressPromo end
      end
      if (not msg.EndvrRAP) and (ActivityType == "Endvr") then
        if maxProgressEndvr > 0 then msg.EndvrRAP = maxProgressEndvr end
      end
    end
  --- a new Task with progress ---
  else
    ChatMessageBuffer[typedTaskName] = { AT = ActivityType, Name = TaskName, Num = Num, Max = MaxNum,
                                         Color = chatColor, Channel = chatChannel }
  end
  EVENT_MANAGER:RegisterForUpdate(WPamA.Name .. "PromoChat", 2000, PostMessageBufferToChat)
end -- PostProgressToChat end

local function GetEndeavorRewardString(index, numComplete)
  if not numComplete then numComplete = 0 end
  local RS = ""
  for ri = 1, GetNumTimedActivityRewards(index) do
    local RID, Q = GetTimedActivityRewardInfo(index, ri)
    local rewardData = REWARDS_MANAGER:GetInfoForReward(RID, Q)
    RS = zo_strformat(RewardTextFormatter, RS, numComplete * Q, rewardData.icon)
  end
  return RS
end -- GetEndeavorRewardString end

--[[
    --- RGB to Hex (for label/text color) ---
    rgb = (r * 0x10000) + (g * 0x100) + b
    string.format("%06x", rgb)
    string.format("%02x%02x%02x", r, g, b)
    --- Floats To Hex (for ColorPicker control) ---
    r, g, b, a = ZO_ColorDef.HexToFloats("RRGGBB") -- A = 1
    HexString = ZO_ColorDef.FloatsToHex(r, g, b, a)
--]]

function WPamA:UpdWindowModeEndeavor()
--  SV structure Endeavor : [1] | [2] | [3] = {NumCompl = 0, NumTotal = 0, EndTS = 0} -- Daily, Weekly, Seasonal
--  if not EndeavorDailyConditions[1] then self:EndeavorDataUpdate() end -- no data -> update data
  if not EndeavorDataReady then return end
--
  local TS = GetTimeStamp()
  local Icon = self.Consts.IconsW
  local Colors = self.Colors
  local Endvr = self.SV_Main.Endeavor
  local isHideCompleted = self.SV_Main.EndeavorHideCompleted
  local isDailyComplete  = Endvr[1].NumCompl > 2
  local isWeeklyComplete = Endvr[2].NumCompl == Endvr[2].NumTotal
  local isSeasonComplete = Endvr[3].NumCompl == Endvr[3].NumTotal
  local RowIndex = {0, 0, 0, 99} -- Daily / Weekly / Seasonal / Promo rows
  RowIndex[1] = (#EndeavorDailyConditions > 0) and 1 or 0
  local RowCnt = (#EndeavorDailyConditions > 0) and (1 + #EndeavorDailyConditions) or 0
  RowIndex[2] = RowCnt + 1
  RowCnt = RowCnt + 1 + #EndeavorWeeklyConditions
  RowIndex[3] = RowCnt + 1
  RowCnt = RowCnt + 1 + #EndeavorSeasonConditions
  if #PromoEventActivity.Conditions > 0 then
    RowIndex[4] = RowCnt + 1
    RowCnt = RowCnt + 1 + #PromoEventActivity.Conditions
    if RowCnt > self.Consts.RowCnt then RowCnt = self.Consts.RowCnt end -- overflow protection
  end
  for i = RowCnt + 1, self.Consts.RowCnt do
    self.ctrlRows[i].Row:SetHidden(true)
  end
  self:UI_UpdMainWindowSize(27, RowCnt)
--
  local txtLvl, txtChar, txtB1, txtB2, txtB3 = "", "", "", "", ""
  for i = 1, RowCnt do
    local r = self.ctrlRows[i]
    local clr = Colors.LabelLvl -- current row text color by default
    local isB3clr = false
    ---
    r.BG:SetHidden(true)
    r.Char:SetHorizontalAlignment(TEXT_ALIGN_LEFT) -- TEXT_ALIGN_LEFT | CENTER | RIGHT
    ---
    if i == RowIndex[1] then -- 1
      --- daily Endeavor title line ---
      r.BG:SetHidden(false)
      txtLvl = " "
      r.Char:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
      txtChar = self.i18n.EndeavorTypeNames[1] -- TIMED_ACTIVITY_TYPE_DAILY
      txtB1 = zo_strformat("<<1>> / 3", Endvr[1].NumCompl)
      txtB2 = " "
      txtB3 = zo_strformat(RewardTimeFormatter, self:DifTSToStr(Endvr[1].EndTS - TS, true, 0))
    ---
    elseif i == RowIndex[2] then -- 7
      --- weekly Endeavor title line ---
      r.BG:SetHidden(false)
      txtLvl = " "
      r.Char:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
      txtChar = self.i18n.EndeavorTypeNames[2] -- TIMED_ACTIVITY_TYPE_WEEKLY
      if isHideCompleted and (Endvr[2].NumTotal ~= #EndeavorWeeklyConditions) then
        txtB1 = zo_strformat("0 / <<1>> |c999999(<<2>><<3>>)|r", #EndeavorWeeklyConditions, Endvr[2].NumCompl, Icon.Hidden)
      else
        txtB1 = zo_strformat("<<1>> / <<2>>", Endvr[2].NumCompl, Endvr[2].NumTotal)
      end
      txtB2 = " "
      txtB3 = zo_strformat(RewardTimeFormatter, self:DifTSToStr(Endvr[2].EndTS - TS, true, 0))
    ---
    elseif i == RowIndex[3] then
      --- seasonal Endeavor title line ---
      r.BG:SetHidden(false)
      txtLvl = " "
      r.Char:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
      txtChar = self.i18n.EndeavorTypeNames[3] -- TIMED_ACTIVITY_TYPE_SEASONAL
      if isHideCompleted and (Endvr[3].NumTotal ~= #EndeavorSeasonConditions) then
        txtB1 = zo_strformat("0 / <<1>> |c999999(<<2>><<3>>)|r", #EndeavorSeasonConditions, Endvr[3].NumCompl, Icon.Hidden)
      else
        txtB1 = zo_strformat("<<1>> / <<2>>", Endvr[3].NumCompl, Endvr[3].NumTotal)
      end
      txtB2 = " "
      txtB3 = zo_strformat(RewardTimeFormatter, self:DifTSToStr(Endvr[3].EndTS - TS, true, 0))
    ---
    elseif i == RowIndex[4] then -- 11
      --- Golden Pursuit title line ---
      r.BG:SetHidden(false)
      txtLvl = " "
      r.Char:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
      txtChar = zo_strformat(self.i18n.PromoEventName, PromoEventActivity.Campaign.Name)
      txtB1 = PromoEventActivity.Campaign.Progress
      txtB2 = " "
      txtB3 = zo_strformat(RewardTimeFormatter, self:DifTSToStr(PromoEventActivity.Campaign.EndTS - TS, true, 0))
    ---
    elseif i < RowIndex[2] then -- 7
      --- daily Endeavor ---
      local EDC = EndeavorDailyConditions[ i - RowIndex[1] ] -- i-1
      if EDC.isComplete then txtLvl = Icon.ChkM
      elseif isDailyComplete then txtLvl = " "
      elseif EDC.Value > 150 then txtLvl = Icon.Value
      else txtLvl = " "
      end
      if isDailyComplete or EDC.isComplete then
        clr = Colors.DungStNA
        isB3clr = EDC.isComplete
      elseif EDC.Value > 150 then clr = Colors.FestDone
      end
      txtChar = EDC.Name
      txtB1 = EDC.Progress
      txtB2 = " "
      txtB3 = EDC.Reward
    ---
    elseif i < RowIndex[3] then -- 11
      --- weekly Endeavor ---
      local EWC = EndeavorWeeklyConditions[ i - RowIndex[2] ] -- i-7
      --if EWC.isComplete then txtLvl = Icon.ChkM
      if EWC.isClaim then txtLvl = Icon.ChkM
      else txtLvl = " "
      end
      --if isWeeklyComplete or EWC.isComplete then
      if isWeeklyComplete or EWC.isClaim then
        clr = Colors.DungStNA
        isB3clr = not EWC.isClaim -- EWC.isComplete
      end
      txtChar = EWC.Name
      txtB1 = EWC.Progress
      txtB2 = EWC.ClaimProgress
      txtB3 = EWC.Reward
    ---
    elseif i < RowIndex[4] then
      --- seasonal Endeavor ---
      local ESC = EndeavorSeasonConditions[ i - RowIndex[3] ]
      --if ESC.isComplete then txtLvl = Icon.ChkM
      if ESC.isClaim then txtLvl = Icon.ChkM
      else txtLvl = " "
      end
      --if isSeasonComplete or ESC.isComplete then
      if isSeasonComplete or ESC.isClaim then
        clr = Colors.DungStNA
        isB3clr = not ESC.isClaim -- ESC.isComplete
      end
      txtChar = ESC.Name
      txtB1 = ESC.Progress
      txtB2 = ESC.ClaimProgress
      txtB3 = ESC.Reward
    ---
    elseif i > RowIndex[4] then -- 11
      --- Golden Pursuit ---
      local PEC = PromoEventActivity.Conditions[ i - RowIndex[4] ] -- i-11
      if PEC.isComplete then txtLvl = Icon.ChkM
      elseif PEC.Value > 101 then txtLvl = Icon.Value
      else txtLvl = " "
      end
      if PromoEventActivity.Campaign.isComplete or PEC.isComplete then
        clr = Colors.DungStNA
        isB3clr = PEC.isComplete
      elseif PEC.Value > 101 then clr = Colors.FestDone
      end
      txtChar = PEC.Name
      txtB1 = PEC.Progress
      txtB2 = " "
      txtB3 = PEC.Reward
    ---
    end
    r.Lvl:SetText(txtLvl)
    r.Char:SetColor(self:GetColor(clr))
    self:SetScaledText(r.Char, txtChar)
    r.B[1]:SetColor(self:GetColor(clr))
    self:SetScaledText(r.B[1], txtB1)
    r.B[2]:SetColor(self:GetColor(clr))
    self:SetScaledText(r.B[2], txtB2)
    r.B[3]:SetColor(self:GetColor(isB3clr and Colors.LabelLvl or clr))
    r.B[3]:SetText(txtB3)
--
    r.Row:SetHidden(false)
  end -- for RowCnt
end -- UpdWindowModeEndeavor end

--[[ ===== Backup of original func ======
function WPamA:UpdWindowModeEndeavor()
--  SV structure Endeavor : [1] | [2] = {NumCompl = 0, EndTS = 0} -- Reward = ""} -- Daily, Weekly
  if not EndeavorDailyConditions[1] then self:EndeavorDataUpdate() end -- no data -> update data
  if not EndeavorDataReady then return end
--
  local TS = GetTimeStamp()
  local Icon = self.Consts.IconsW
  local Colors = self.Colors
  local Endvr = self.SV_Main.Endeavor
  local isDailyComplete  = Endvr[1].NumCompl > 2
  local isWeeklyComplete = Endvr[2].NumCompl > 0
  local RowCnt = 2 + #EndeavorDailyConditions + #EndeavorWeeklyConditions
  for i = RowCnt + 1, self.Consts.RowCnt do
    self.ctrlRows[i].Row:SetHidden(true)
  end
  self:UI_UpdMainWindowSize(27, RowCnt)
--
  local txtLvl, txtChar, txtB1, txtB2 = "", "", "", ""
  for i = 1, RowCnt do
    local r = self.ctrlRows[i]
    local clr = Colors.LabelLvl -- current row text color by default
    local isB2clr = false
    ---
    r.BG:SetHidden(true)
    r.Char:SetHorizontalAlignment(TEXT_ALIGN_LEFT) -- TEXT_ALIGN_LEFT | CENTER | RIGHT
    ---
    if i == 1 then
      --- daily Endeavor title line ---
      r.BG:SetHidden(false)
      txtLvl = " "
      r.Char:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
      txtChar = self.i18n.EndeavorTypeNames[1] -- TIMED_ACTIVITY_TYPE_DAILY
      txtB1 = Endvr[1].NumCompl .. " / 3"
      txtB2 = zo_strformat(RewardTimeFormatter, self:DifTSToStr(Endvr[1].EndTS - TS, true, 0))
    ---
    elseif i == 7 then
      --- weekly Endeavor title line ---
      r.BG:SetHidden(false)
      txtLvl = " "
      r.Char:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
      txtChar = self.i18n.EndeavorTypeNames[2] -- TIMED_ACTIVITY_TYPE_WEEKLY
      txtB1 = Endvr[2].NumCompl .. " / 1"
      txtB2 = zo_strformat(RewardTimeFormatter, self:DifTSToStr(Endvr[2].EndTS - TS, true, 0))
    ---
    elseif i < 7 then
      --- daily Endeavor ---
      local EDC = EndeavorDailyConditions[i-1]
      if EDC.isComplete then txtLvl = Icon.ChkM
      elseif EDC.Value > 150 then txtLvl = Icon.Value
      else txtLvl = " "
      end
      if isDailyComplete or EDC.isComplete then
        clr = Colors.DungStNA
        isB2clr = EDC.isComplete
      elseif EDC.Value > 150 then clr = Colors.FestDone
      end
      txtChar = EDC.Name
      txtB1 = EDC.Progress
      txtB2 = EDC.Reward
    ---
    elseif i > 7 then
      --- weekly Endeavor ---
      local EWC = EndeavorWeeklyConditions[i-7]
      if EWC.isComplete then txtLvl = Icon.ChkM
      else txtLvl = " "
      end
      if isWeeklyComplete or EWC.isComplete then
        clr = Colors.DungStNA
        isB2clr = EWC.isComplete
      end
      txtChar = EWC.Name
      txtB1 = EWC.Progress
      txtB2 = EWC.Reward
    ---
    end
    r.Lvl:SetText(txtLvl)
    r.Char:SetColor(self:GetColor(clr))
    self:SetScaledText(r.Char, txtChar)
    r.B[1]:SetColor(self:GetColor(clr))
    self:SetScaledText(r.B[1], txtB1)
    r.B[2]:SetColor(self:GetColor(isB2clr and Colors.LabelLvl or clr))
    r.B[2]:SetText(txtB2)
--
    r.Row:SetHidden(false)
  end -- for RowCnt
end -- UpdWindowModeEndeavor end
================================ --]]
function WPamA:EndeavorDataPrepare()
  if #EndeavorDataOnServer ~= GetNumTimedActivities() then return end
  EndeavorDailyConditions, EndeavorWeeklyConditions, EndeavorSeasonConditions = {}, {}, {}
  local isHideCompleted = self.SV_Main.EndeavorHideCompleted
  local tinsert = table.insert
  local taDailyCompl, taWeeklyCompl, taSeasonCompl = 0, 0, 0
  local taDailyTotal, taWeeklyTotal, taSeasonTotal = 0, 0, 0
  for i = 1, #EndeavorDataOnServer do
    --- Get Endeavor's progress and reward data ---
    local endvData = EndeavorDataOnServer[i]
    local taCompl = endvData.Progress >= endvData.MaxProgress
    local taClaim = endvData.Claim >= endvData.MaxClaim
    local _, taValue = GetTimedActivityRewardInfo(i, 1)
    local isValueReward = (taValue > 15) or (GetNumTimedActivityRewards(i) > 1) or false
    local percProgr = zo_floor(100 * endvData.Progress / endvData.MaxProgress)
    local taSaveCond = (not isHideCompleted) or ( isHideCompleted and (not taClaim) )
    --- Save Endeavor's data to array ---
    local cond = { Ind = i, Name = endvData.Name, isComplete = taCompl, isClaim = taClaim,
                   -- Value = percProgr + taValue * (isValueReward and 20 or 1),
                   Value = percProgr + 20,
                   Progress = zo_strformat("<<1>> / <<2>>", endvData.Progress, endvData.MaxProgress),
                   ClaimProgress = zo_strformat("<<1>> / <<2>>", endvData.Claim, endvData.MaxClaim),
                   Reward = endvData.Reward }
                   -- Reward = GetEndeavorRewardString(i, 1) }
    if endvData.Type == TIMED_ACTIVITY_TYPE_DAILY then -- Daily
      taDailyTotal = taDailyTotal + 1
      if taClaim then taDailyCompl = taDailyCompl + 1 end
      if taSaveCond then tinsert(EndeavorDailyConditions, cond) end
    elseif endvData.Type == TIMED_ACTIVITY_TYPE_WEEKLY then
      taWeeklyTotal = taWeeklyTotal + 1
      if taClaim then taWeeklyCompl = taWeeklyCompl + 1 end
      if taSaveCond then tinsert(EndeavorWeeklyConditions, cond) end
    else -- Season = TIMED_ACTIVITY_TYPE_SEASONAL
      taSeasonTotal = taSeasonTotal + 1
      if taClaim then taSeasonCompl = taSeasonCompl + 1 end
      if taSaveCond then tinsert(EndeavorSeasonConditions, cond) end
    end
  end -- for TA Loop
  --- Patch for U49
  --[[
  if #EndeavorDailyConditions < 1 then
    EndeavorDailyConditions[1] =
      { Ind = 1, Name = "---", isComplete = false, isClaim = false, Value = 1,
        Progress = "--- / ---", ClaimProgress = "--- / ---", Reward = "---" }
  end
  --]]
  if #EndeavorWeeklyConditions < 1 then
    EndeavorWeeklyConditions[1] =
      { Ind = 1, Name = "---", isComplete = false, isClaim = false, Value = 1,
        Progress = "--- / ---", ClaimProgress = "--- / ---", Reward = "---" }
  end
  if #EndeavorSeasonConditions < 1 then
    EndeavorSeasonConditions[1] =
      { Ind = 1, Name = "---", isComplete = false, isClaim = false, Value = 1,
        Progress = "--- / ---", ClaimProgress = "--- / ---", Reward = "---" }
  end
  --- Sort conditions data arrays ---
  table.sort( EndeavorDailyConditions,  function(v1, v2)
                                          --local valV1 = v1.isComplete and 1 or v1.Value
                                          --local valV2 = v2.isComplete and 1 or v2.Value
                                          local valV1 = v1.isClaim and 1 or v1.Value
                                          local valV2 = v2.isClaim and 1 or v2.Value
                                          if valV1 == valV2 then return v1.Name < v2.Name end
                                          return valV2 < valV1
                                        end )
  table.sort( EndeavorWeeklyConditions, function(v1, v2)
                                          local valV1 = v1.isClaim and 1 or v1.Value
                                          local valV2 = v2.isClaim and 1 or v2.Value
                                          if valV1 == valV2 then return v1.Name < v2.Name end
                                          return valV2 < valV1
                                        end )
  table.sort( EndeavorSeasonConditions, function(v1, v2)
                                          local valV1 = v1.isClaim and 1 or v1.Value
                                          local valV2 = v2.isClaim and 1 or v2.Value
                                          if valV1 == valV2 then return v1.Name < v2.Name end
                                          return valV2 < valV1
                                        end )
  --- Save Endeavor's end time ---
  local taSV = self.SV_Main.Endeavor
  -- SV structure Endeavor : [1] | [2] | [3] = {NumCompl = 0, NumTotal = 0, EndTS = 0} -- Daily, Weekly, Seasonal
  taSV[1].NumCompl = taDailyCompl
  taSV[2].NumCompl = taWeeklyCompl
  taSV[3].NumCompl = taSeasonCompl
  taSV[1].NumTotal = taDailyTotal
  taSV[2].NumTotal = taWeeklyTotal
  taSV[3].NumTotal = taSeasonTotal
  local to = self.Today
  if to.DayEnd then
    if taSV[1].EndTS ~= to.DayEnd    then taSV[1].EndTS = to.DayEnd    end
    if taSV[2].EndTS ~= to.WeekEnd   then taSV[2].EndTS = to.WeekEnd   end
    if taSV[3].EndTS ~= to.SeasonEnd then taSV[3].EndTS = to.SeasonEnd end
  end
  if EndeavorWeeklyConditions[1] then EndeavorDataReady = true end
end -- EndeavorDataPrepare end

function WPamA:EndeavorDataUpdate( taIndex )
  if type(taIndex) ~= "number" then taIndex = 0 end
  local taNum = GetNumTimedActivities()
  if (taIndex < 0) or (taNum < taIndex) then taIndex = 0 end
  ---
  EndeavorDataReady = false
  if taIndex == 0 then
    EndeavorDataOnServer = {}
    RemainActivityProgress.Endvr = {}
  end
  local remain = RemainActivityProgress.Endvr
  local startLoop = (taIndex == 0) and 1 or taIndex
  local endLoop   = (taIndex == 0) and taNum or taIndex
  for i = startLoop, endLoop do
    local taType = GetTimedActivityType(i)
    -- TIMED_ACTIVITY_TYPE_DAILY | TIMED_ACTIVITY_TYPE_WEEKLY | TIMED_ACTIVITY_TYPE_SEASONAL
    local taProgress = GetTimedActivityProgress(i)
    local taMaxProgress = GetTimedActivityMaxProgress(i)
    local taName = GetTimedActivityName(i)
    taName = taName:gsub("|t%d%d:%d%d:","|t18:18:")
    local taReward = GetEndeavorRewardString(i, 1)
    local taClaim = GetTimedActivityNumTimesClaimed(i)
    local taMaxClaim = GetTimedActivityTotalNumTimesClaimable(i)
    EndeavorDataOnServer[i] = { Type = taType, Name = taName, Reward = taReward,
                                Progress = taProgress, MaxProgress = taMaxProgress,
                                Claim = taClaim, MaxClaim = taMaxClaim }
    --- Set max progress for endeavor Activity's types ---
    local totalMaxProgress = taMaxProgress * taMaxClaim
    local typedName = taName:gsub(" (%d+)", " #")
    if (taIndex == 0) and (taClaim < taMaxClaim) then
      if remain[typedName] then
        if remain[typedName] < totalMaxProgress then remain[typedName] = totalMaxProgress end
      else
        remain[typedName] = totalMaxProgress
      end
    end
    --- Show Endeavor's progress in chat ---
    if taIndex > 0 then
      if taMaxProgress == 1 then --!!
        taProgress = taClaim + 1
        taMaxProgress = taMaxClaim
      else
        taProgress = taProgress + (taClaim * taMaxProgress)
        taMaxProgress = totalMaxProgress
      end
      local taText = zo_strformat(EndeavorChatFormatter, taName, taProgress, taMaxProgress, "")
      ----local chatType = (taType == TIMED_ACTIVITY_TYPE_DAILY) and "D" or "W"
      local chatType = "D" -- TIMED_ACTIVITY_TYPE_DAILY
      if taType == TIMED_ACTIVITY_TYPE_WEEKLY then chatType = "W"
      elseif taType == TIMED_ACTIVITY_TYPE_SEASONAL then chatType = "S"
      end
      if taText ~= EndeavorChatMessageText[chatType] then
        EndeavorChatMessageText[chatType] = taText
        local EPiC = self.SV_Main.EndeavorProgressInChat
        if EPiC.Enabled then
          local taColor = ""
          if EPiC.isUseCustomColor then
            if EPiC.Color:len() < 6 then EPiC.Color = string.format("%02x%02x%02x", 238, 238, 200) end
            --taText = zo_strformat("|c<<1>><<2>>|r", EPiC.Color, taText)
            taColor = EPiC.Color
          end
          --self:PostChatMessage(taText, EPiC.Channel)
          PostProgressToChat("Endvr", taName, taProgress, taMaxProgress, taColor, EPiC.Channel)
        end
      end
    end
    ---
  end -- for TA Loop
  ---
  self:EndeavorDataPrepare()
end -- EndeavorDataUpdate end

function WPamA.OnEndeavorUpdated(event, ... )
  if IsTimedActivitySystemAvailable() then
    local m = WPamA.SV_Main.ShowMode
    if event == EVENT_TIMED_ACTIVITIES_UPDATED then
      WPamA:UpdToday()
      WPamA:EndeavorDataUpdate()
      -- calendar or hirelings mail update
      local Modes = { [0] = true, [1] = true, [5] = true }
      if Modes[m] then WPamA:UpdWindowInfo() end
    ---
    elseif event == EVENT_TIMED_ACTIVITY_PROGRESS_UPDATED then
      -- (*luaindex* index, *integer* previousProgress, *integer* currentProgress, *bool* complete)
      local endvIndex = ...
      if type(endvIndex) ~= "number" then endvIndex = 0 end
      local isDataChanged = false
      local endvName = GetTimedActivityName(endvIndex)
      if not EndeavorDataOnServer[endvIndex] then
        isDataChanged = true -- no index = full data reload
      elseif endvName ~= EndeavorDataOnServer[endvIndex].Name then
        isDataChanged = true -- name is not equal = full data reload
      end
      if isDataChanged then WPamA:EndeavorDataUpdate() end
      if endvIndex > 0 then WPamA:EndeavorDataUpdate(endvIndex) end
    end
    ---
    if WPamA.SV_Main.AutoClaimEndeavorReward and HasAnyUnclaimedTimedActivityRewards() then
      ClaimAllTimedActivityRewards()
    end
    ---
    if m == 27 then WPamA:UpdWindowInfo() end -- endeavor tab update
  end
end -- OnEndeavorUpdated end
--=========================================================================
--================ Companions Section =====================================
--=========================================================================
local CompItemLinkFormatter = "|H1:item:<<1>>:1:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h"

function WPamA:UpdWindowModeRapports(v, r, mode)
  local wc = self.Companions
  local RapportColors = wc.RapportColors
  local RapportMode = self.SV_Main.CompanionRapportMode
  local isShowMaxRapport = self.SV_Main.CompanionRapportShowMax
  ---- local startLoop = (mode == 29) and 1 or 1 --??
  local endLoop = 6 -- for mode 29 by default
  if mode == 46 then endLoop = #wc.Persons - 6 end -- for mode 46 since ESO U44
--[[
wc =
  MaxRapport = GetMaximumRapport(),
  MinRapport = GetMinimumRapport(),
cc[companionId] = { Rapport = 99999, RapportLvl = 0, StoryQuests = {}, hasQuest = false }
--]]
  for i = 1, endLoop do -- #wc.Persons
    local txt = ""
    local ccIndex = i -- for mode 29 by default
    if mode == 46 then ccIndex = i + 6 end -- for mode 46 since ESO U44
    local cc = v.Companions[ccIndex]
    local locked = wc.Persons[ccIndex].isLocked or false
    local rapport = cc.Rapport
    local rapportLvl = cc.RapportLvl
    local story = cc.StoryQuests
    r.B[i]:SetColor(self:GetColor(self.Colors.LabelLvl))
    if locked then -- companion locked
      txt = self.Consts.IconsW.Lock
      r.B[i]:SetColor(self:GetColor(self.Colors.DungStNA))
    elseif cc.hasQuest then -- companion has a Intro quest
      txt = self.Consts.IconsW.Quest
    elseif rapport == 99999 then -- no data for companion
      txt = self.i18n.DungStNA
      r.B[i]:SetColor(self:GetColor(self.Colors.DungStNA))
    else  -- companion unlocked
      if RapportMode == 1 then -- as a number
        txt = rapport
        if isShowMaxRapport then
          if rapport >= 0 then txt = txt .. " / " .. wc.MaxRapport
          else txt = txt .. " / " .. wc.MinRapport
          end
        end
      else -- as a text
        txt = GetString("SI_COMPANIONRAPPORTLEVEL", rapportLvl)
      end
      txt = zo_strformat(RapportColors[rapportLvl], txt)
      --- companion has a Story quest ---
      if story[1] and (rapportLvl > RAPPORT_LEVEL_SLIGHT_AFFINITY) then
        txt = self.Consts.IconsW.Quest .. txt
      elseif story[2] and (rapportLvl > RAPPORT_LEVEL_MODERATE_AFFINITY) then
        txt = self.Consts.IconsW.Quest .. txt
      elseif story[3] and (rapportLvl > RAPPORT_LEVEL_HIGH_AFFINITY) then
        txt = self.Consts.IconsW.Quest .. txt
      end
    end
    self:SetScaledText(r.B[i], txt)
  end
end -- UpdWindowModeRapports end

function WPamA:UpdWindowModeCompClassSkills()
  local WCP = self.Companions.Persons
  local WCID = self.Companions.ActiveCompanionId
--WCP: { IID = IngameCompanionId, CID = CollectibleId, Name = "CompanionName", QID = QuestId, isLocked = lockedStatus }
  local ACC = self.SV_Main.Companions
--ACC = { Lvl = 99, LvlPrc = 0, Skills = { [ind] = {Lvl = 1, LvlPrc = 0, isLocked = true} }, }
  local RowCnt = #WCP
  for i = RowCnt + 1, self.Consts.RowCnt do
    self.ctrlRows[i].Row:SetHidden(true)
  end
  self:UI_UpdMainWindowSize(32, RowCnt)
--
  for i = 1, RowCnt do
    local r = self.ctrlRows[i]
    r.BG:SetHidden( WCID ~= i )
    r.Lvl:SetColor(self:GetColor(self.Colors.LabelLvl))
    if ACC[i].Lvl < 50 then r.Lvl:SetText(ACC[i].Lvl)
    else r.Lvl:SetText(0)
    end
    r.Char:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    r.Char:SetColor(self:GetColor(self.Colors.LabelLvl))
    self:SetScaledText(r.Char, WCP[i].Name)
--
    for j = 1, 7 do
      local txt = " "
      local skills = ACC[i].Skills[j + 2] -- show skills from 3 to 9 of SkillLines array
      -- skills = {Lvl = 1, LvlPrc = 0, isLocked = true}
      local maxRank = self.Companions.SkillLines[j + 2].Max or 20
      r.B[j]:SetColor(self:GetColor(self.Colors.LabelLvl))
      if skills then
        local locked = WCP[i].isLocked or skills.isLocked or false
        if locked then -- companion or skill-line is locked
          r.B[j]:SetColor(self:GetColor(self.Colors.DungStNA)) -- gray
          txt = self.Consts.IconsW.Lock
        else
          if skills.Lvl >= maxRank then
            r.B[j]:SetColor(self:GetColor(self.Colors.DungStDone)) -- green
          end
          txt = skills.Lvl + skills.LvlPrc
        end
      else -- data not exist
        r.B[j]:SetColor(self:GetColor(self.Colors.DungStNA)) -- gray
        txt = self.i18n.DungStNA
      end
      self:SetScaledText(r.B[j], txt)
    end
--
    r.Row:SetHidden(false)
  end
end -- UpdWindowModeCompClassSkills end

function WPamA:UpdWindowModeCompWeaponSkills()
  local WCP = self.Companions.Persons
  local WCID = self.Companions.ActiveCompanionId
--WCP: { IID = IngameCompanionId, CID = CollectibleId, Name = "CompanionName", QID = QuestId, isLocked = lockedStatus }
  local ACC = self.SV_Main.Companions
--ACC = { Lvl = 99, LvlPrc = 0, Skills = { [ind] = {Lvl = 1, LvlPrc = 0, isLocked = true} }, }
  local RowCnt = #WCP
  for i = RowCnt + 1, self.Consts.RowCnt do
    self.ctrlRows[i].Row:SetHidden(true)
  end
  self:UI_UpdMainWindowSize(36, RowCnt)
--
  for i = 1, RowCnt do
    local r = self.ctrlRows[i]
    r.BG:SetHidden( WCID ~= i )
    r.Lvl:SetColor(self:GetColor(self.Colors.LabelLvl))
    if ACC[i].Lvl < 50 then r.Lvl:SetText(ACC[i].Lvl)
    else r.Lvl:SetText(0)
    end
    r.Char:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    r.Char:SetColor(self:GetColor(self.Colors.LabelLvl))
    self:SetScaledText(r.Char, WCP[i].Name)
--
    for j = 1, 6 do
      local txt = " "
      local skills = ACC[i].Skills[j + 9] -- show skills from 10 to 15 of SkillLines array
      -- skills = {Lvl = 1, LvlPrc = 0, isLocked = true}
      local maxRank = self.Companions.SkillLines[j + 9].Max or 20
      r.B[j]:SetColor(self:GetColor(self.Colors.LabelLvl))
      if skills then
        local locked = WCP[i].isLocked or skills.isLocked or false
        if locked then -- companion or skill-line is locked
          r.B[j]:SetColor(self:GetColor(self.Colors.DungStNA)) -- gray
          txt = self.Consts.IconsW.Lock
        else
          if skills.Lvl >= maxRank then
            r.B[j]:SetColor(self:GetColor(self.Colors.DungStDone)) -- green
          end
          txt = skills.Lvl + skills.LvlPrc
        end
      else -- data not exist
        r.B[j]:SetColor(self:GetColor(self.Colors.DungStNA)) -- gray
        txt = self.i18n.DungStNA
      end
      self:SetScaledText(r.B[j], txt)
    end
--
    r.Row:SetHidden(false)
  end
end -- UpdWindowModeCompWeaponSkills end

function WPamA:UpdWindowModeCompActiveSkills()
  local WCP = self.Companions.Persons
  local WCID = self.Companions.ActiveCompanionId
--WCP: { IID = IngameCompanionId, CID = CollectibleId, Name = "CompanionName", QID = QuestId, isLocked = lockedStatus }
  local ACC = self.SV_Main.Companions
--ACC = { Lvl = 99, LvlPrc = 0, Skills = {}, Equips = {}, SkillBar = {} }
  local deltaSlotInd = self.Companions.MinSkillBarSlot - 1
  local RowCnt = #WCP
  for i = RowCnt + 1, self.Consts.RowCnt do
    self.ctrlRows[i].Row:SetHidden(true)
  end
  self:UI_UpdMainWindowSize(52, RowCnt)
--
  for i = 1, RowCnt do
    local r = self.ctrlRows[i]
    r.BG:SetHidden( WCID ~= i )
    r.Lvl:SetColor(self:GetColor(self.Colors.LabelLvl))
    if ACC[i].Lvl < 50 then r.Lvl:SetText(ACC[i].Lvl)
    else r.Lvl:SetText(0)
    end
    r.Char:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    r.Char:SetColor(self:GetColor(self.Colors.LabelLvl))
    self:SetScaledText(r.Char, WCP[i].Name)
    --
    for j = 1, 6 do
      local txt = ""
      local slotAbilityId = ACC[i].SkillBar[ j + deltaSlotInd ]
      r.B[j]:SetColor(self:GetColor(self.Colors.LabelLvl))
      if slotAbilityId and (slotAbilityId > 0) then
        txt = zo_strformat("|t<<1>>:<<1>>:<<2>>|t", 20, GetAbilityIcon(slotAbilityId))
      else -- data not exist
        r.B[j]:SetColor(self:GetColor(self.Colors.DungStNA)) -- gray
        txt = "---"
      end
      self:SetScaledText(r.B[j], txt)
      self.SetAbilityToolTip(r.B[j], slotAbilityId)
    end
    --
    r.Row:SetHidden(false)
  end
end -- UpdWindowModeCompActiveSkills end

local function GetItemLinkByItemData(ItemDataString)
  if type(ItemDataString) == "string" then
    return zo_strformat(CompItemLinkFormatter, ItemDataString)
  end
  return ""
end -- GetItemLinkByItemData end

function WPamA:UpdWindowModeCompArmorEquips()
  local EquipMode = self.SV_Main.CompanionEquipMode
  local Lng = self.i18n.Lng
  local EquipReplace = self.i18n.CompanionEquipRepl
  local EquipSubs = self.Companions.EquipNameSubs
  local WCP = self.Companions.Persons
  local WCID = self.Companions.ActiveCompanionId
--WCP: { IID = IngameCompanionId, CID = CollectibleId, Name = "CompanionName", QID = QuestId, isLocked = lockedStatus }
  local ACC = self.SV_Main.Companions
--ACC = { Lvl = 99, LvlPrc = 0, Skills = {}, Equips = {[1]..[12] = "item link data"} }
  local RowCnt = #WCP
  for i = RowCnt + 1, self.Consts.RowCnt do
    self.ctrlRows[i].Row:SetHidden(true)
  end
  self:UI_UpdMainWindowSize(39, RowCnt)
--
  for i = 1, RowCnt do
    local r = self.ctrlRows[i]
    r.BG:SetHidden( WCID ~= i )
    r.Lvl:SetColor(self:GetColor(self.Colors.LabelLvl))
    if ACC[i].Lvl < 50 then r.Lvl:SetText(ACC[i].Lvl)
    else r.Lvl:SetText(0)
    end
    r.Char:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    r.Char:SetColor(self:GetColor(self.Colors.LabelLvl))
    self:SetScaledText(r.Char, WCP[i].Name)
--
    for j = 1, 7 do
      local txt = " "
      local equip = ACC[i].Equips[j] -- show equips from 1 to 7 of EquipSlots array
      ---- equips = { [1]..[12] = "item link data" }
      r.B[j]:SetColor(self:GetColor(self.Colors.LabelLvl))
      if equip then
        if equip == "" then -- empty equip slot
          r.B[j]:SetColor(self:GetColor(self.Colors.DungStNA)) -- gray
          txt = "-"
        else
          local itemLink = GetItemLinkByItemData(equip)
          if itemLink ~= "" then
            if EquipMode == 1 then -- show item name
              txt = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetItemLinkName(itemLink) )
              if EquipReplace.CompTitle then
                txt = txt:gsub( EquipReplace.CompTitle, "" )
              end
              if EquipReplace[txt] and EquipReplace[txt][EquipMode] then
                txt = EquipReplace[txt][EquipMode]
              end

            elseif EquipMode == 2 then -- show item type
              local armorType = GetItemLinkArmorType(itemLink)
              txt = GetString( SI_ARMORTYPE1 + 2 * (armorType - 1) ):gsub("%s.+", "")

            elseif EquipMode == 3 then -- show item trait
              local traitType = GetItemLinkTraitInfo(itemLink)
              txt = GetString( SI_ITEMTRAITTYPE0 + traitType )
              if EquipReplace[txt] and EquipReplace[txt][EquipMode] then
                txt = EquipReplace[txt][EquipMode]
              end

            else -- show type + trait
              local armorType = GetItemLinkArmorType(itemLink)
              txt = GetString( SI_ARMORTYPE1 + 2 * (armorType - 1) )
              txt = txt:sub(1, EquipSubs[Lng] or 2)
              local traitType = GetItemLinkTraitInfo(itemLink)
              local traitName = GetString( SI_ITEMTRAITTYPE0 + traitType )
              if EquipReplace[traitName] and EquipReplace[traitName][EquipMode] then
                traitName = EquipReplace[traitName][EquipMode]
              end
              txt = txt .. " - " .. traitName
            end
            local itemQuality = GetItemLinkDisplayQuality(itemLink)
            local qualityColor = GetItemQualityColor(itemQuality)
            txt = qualityColor:Colorize(txt)
            self.SetItemToolTip(r.B[j], itemLink)
          end
        end
      else -- data not exist
        r.B[j]:SetColor(self:GetColor(self.Colors.DungStNA)) -- gray
        txt = self.i18n.DungStNA
      end
      self:SetScaledText(r.B[j], txt)
    end
--
    r.Row:SetHidden(false)
  end
end -- UpdWindowModeCompArmorEquips end

local function GetWeaponTypeByItemLink(itemLink)
  local OneHandedTypes = {
    [WEAPONTYPE_AXE] = true,
    [WEAPONTYPE_DAGGER] = true,
    [WEAPONTYPE_SHIELD] = true,
    [WEAPONTYPE_SWORD] = true,
    [WEAPONTYPE_HAMMER] = true,
  }
  local TwoHandedTypes = {
    [WEAPONTYPE_BOW] = true,
    [WEAPONTYPE_FIRE_STAFF] = true,
    [WEAPONTYPE_FROST_STAFF] = true,
    [WEAPONTYPE_HEALING_STAFF] = true,
    [WEAPONTYPE_LIGHTNING_STAFF] = true,
    [WEAPONTYPE_TWO_HANDED_AXE] = true,
    [WEAPONTYPE_TWO_HANDED_HAMMER] = true,
    [WEAPONTYPE_TWO_HANDED_SWORD] = true,
  }
--WEAPONTYPE_NONE
--WEAPONTYPE_RUNE
  if itemLink and (itemLink ~= "") then
    local WT = GetItemLinkWeaponType(itemLink)
    if OneHandedTypes[WT] then
      return WEAPON_CONFIG_TYPE_ONE_HANDED -- = 10
    elseif TwoHandedTypes[WT] then
      return WEAPON_CONFIG_TYPE_TWO_HANDED -- = 3
    end
  end
  return WEAPON_CONFIG_TYPE_NONE -- = 0
end -- GetWeaponTypeByItemLink end

function WPamA:UpdWindowModeCompWeaponEquips()
  local EquipMode = self.SV_Main.CompanionEquipMode
  local Lng = self.i18n.Lng
  local EquipReplace = self.i18n.CompanionEquipRepl
  local EquipSubs = self.Companions.EquipNameSubs
  local WCP = self.Companions.Persons
  local WCID = self.Companions.ActiveCompanionId
--WCP: { IID = IngameCompanionId, CID = CollectibleId, Name = "CompanionName", QID = QuestId, isLocked = lockedStatus }
  local ACC = self.SV_Main.Companions
--ACC = { Lvl = 99, LvlPrc = 0, Skills = {}, Equips = {[1]..[12] = "item link data"} }
  local RowCnt = #WCP
  for i = RowCnt + 1, self.Consts.RowCnt do
    self.ctrlRows[i].Row:SetHidden(true)
  end
  self:UI_UpdMainWindowSize(40, RowCnt)
--
  for i = 1, RowCnt do
    local r = self.ctrlRows[i]
    r.BG:SetHidden( WCID ~= i )
    r.Lvl:SetColor(self:GetColor(self.Colors.LabelLvl))
    if ACC[i].Lvl < 50 then r.Lvl:SetText(ACC[i].Lvl)
    else r.Lvl:SetText(0)
    end
    r.Char:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    r.Char:SetColor(self:GetColor(self.Colors.LabelLvl))
    self:SetScaledText(r.Char, WCP[i].Name)
--
    local has2HWeapon = false
    local eq = ACC[i].Equips[8] or ""
    if eq ~= "" then -- weapon is in inventory
      local wt = GetWeaponTypeByItemLink( GetItemLinkByItemData(eq) )
      if wt == WEAPON_CONFIG_TYPE_TWO_HANDED then has2HWeapon = true end
    end
--
    for j = 1, 5 do
      local txt = " "
      local equip = ACC[i].Equips[j + 7] -- show equips from 8 to 12 of EquipSlots array
      ---- equips = { [1]..[12] = "item link data" }
      if (j == 2) and has2HWeapon then equip = ACC[i].Equips[8] end
      r.B[j]:SetColor(self:GetColor(self.Colors.LabelLvl))
      if equip then
        if equip == "" then -- empty equip slot
          r.B[j]:SetColor(self:GetColor(self.Colors.DungStNA)) -- gray
          txt = "-"
        else
          local itemLink = GetItemLinkByItemData(equip)
          if itemLink ~= "" then
            if EquipMode == 1 then -- show item name
              txt = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetItemLinkName(itemLink) )
              if EquipReplace.CompTitle then
                txt = txt:gsub( EquipReplace.CompTitle, "" )
              end
              if EquipReplace[txt] and EquipReplace[txt][EquipMode] then
                txt = EquipReplace[txt][EquipMode]
              end

            elseif EquipMode == 2 then -- show item type
              if j < 3 then -- weapon
                local armorType = SI_EQUIPTYPE5 -- One-Handed by default
                if has2HWeapon then armorType = SI_EQUIPTYPE6 end -- Two-Handed
                if EquipReplace[armorType] and EquipReplace[armorType][EquipMode] then
                  txt = EquipReplace[armorType][EquipMode]
                else
                  txt = GetString(armorType)
                end
              elseif j == 3 then -- necklace
                txt = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_EQUIPSLOT1):gsub("%s.+", "") )
              elseif j > 3 then -- ring
                if EquipReplace[SI_EQUIPSLOT11] and EquipReplace[SI_EQUIPSLOT11][EquipMode] then
                  txt = EquipReplace[SI_EQUIPSLOT11][EquipMode]
                else
                  txt = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetString(SI_EQUIPSLOT11):gsub("%s.+", "") )
                end
              end

            elseif EquipMode == 3 then -- show item trait
              local traitType = GetItemLinkTraitInfo(itemLink)
              txt = GetString( SI_ITEMTRAITTYPE0 + traitType )
              if EquipReplace[txt] and EquipReplace[txt][EquipMode] then
                txt = EquipReplace[txt][EquipMode]
              end

            else -- show type + trait
              if j < 3 then -- weapon
                local armorType = SI_EQUIPTYPE5 -- One-Handed by default
                if has2HWeapon then armorType = SI_EQUIPTYPE6 end -- Two-Handed
                if EquipReplace[armorType] and EquipReplace[armorType][EquipMode] then
                  txt = EquipReplace[armorType][EquipMode]
                else
                  txt = GetString(armorType)
                end
              elseif j == 3 then -- necklace
                txt = GetString(SI_EQUIPTYPE2):sub(1, EquipSubs[Lng] or 2)
              elseif j > 3 then -- ring
                txt = GetString(SI_EQUIPTYPE12):sub(1, EquipSubs[Lng] or 2)
              end
              local traitType = GetItemLinkTraitInfo(itemLink)
              local traitName = GetString( SI_ITEMTRAITTYPE0 + traitType )
              if EquipReplace[traitName] and EquipReplace[traitName][EquipMode] then
                traitName = EquipReplace[traitName][EquipMode]
              end
              txt = txt .. " - " .. traitName
            end

            if (j == 2) and has2HWeapon then
              r.B[j]:SetColor(self:GetColor(self.Colors.DungStNA)) -- gray
              self.SetItemToolTip(r.B[j])
            else
              local itemQuality = GetItemLinkDisplayQuality(itemLink)
              local qualityColor = GetItemQualityColor(itemQuality)
              txt = qualityColor:Colorize(txt)
              self.SetItemToolTip(r.B[j], itemLink)
            end
          end
        end
      else -- data not exist
        r.B[j]:SetColor(self:GetColor(self.Colors.DungStNA)) -- gray
        txt = self.i18n.DungStNA
      end
      self:SetScaledText(r.B[j], txt)
    end
--
    r.Row:SetHidden(false)
  end
end -- UpdWindowModeCompWeaponEquips end

--[[
GetItemLinkArmorType(*string* _itemLink_)
Returns: *[ArmorType|#ArmorType]* _armorType_

ARMORTYPE_NONE
ARMORTYPE_LIGHT
ARMORTYPE_MEDIUM
ARMORTYPE_HEAVY
txt = GetString( SI_ARMORTYPE?? ):gsub("%s.+", "")
SI_ARMORTYPE0 = "None"
SI_ARMORTYPE1 = "Light"
SI_ARMORTYPE2 = "Medium"
SI_ARMORTYPE3 = "Heavy"

txt = GetString( SI_WEAPONTYPE?? ):gsub("%s.+", "")
SI_WEAPONTYPE0, "do not translate", 0)
SI_WEAPONTYPE1, "Axe", 0)
SI_WEAPONTYPE2, "Mace", 0)
SI_WEAPONTYPE3, "Sword", 0)
SI_WEAPONTYPE4, "Sword", 0)
SI_WEAPONTYPE5, "Axe", 0)
SI_WEAPONTYPE6, "Mace", 0)
SI_WEAPONTYPE7, "do not translate", 0)
SI_WEAPONTYPE8, "Bow", 0)
SI_WEAPONTYPE9, "Healing Staff", 0)
SI_WEAPONTYPE10, "Rune", 0)
SI_WEAPONTYPE11, "Dagger", 0)
SI_WEAPONTYPE12, "Flame Staff", 0)
SI_WEAPONTYPE13, "Frost Staff", 0)
SI_WEAPONTYPE14, "Shield", 0)
SI_WEAPONTYPE15, "Lightning Staff", 0)

GetItemLinkWeaponType(*string* _itemLink_)
Returns: *[WeaponType|#WeaponType]* _weaponType_

WEAPONTYPE_AXE
WEAPONTYPE_BOW
WEAPONTYPE_DAGGER
WEAPONTYPE_FIRE_STAFF
WEAPONTYPE_FROST_STAFF
WEAPONTYPE_HAMMER
WEAPONTYPE_HEALING_STAFF = 9
WEAPONTYPE_LIGHTNING_STAFF
WEAPONTYPE_NONE
WEAPONTYPE_RUNE
WEAPONTYPE_SHIELD
WEAPONTYPE_SWORD
WEAPONTYPE_TWO_HANDED_AXE
WEAPONTYPE_TWO_HANDED_HAMMER
WEAPONTYPE_TWO_HANDED_SWORD

GetItemLinkTraitInfo(string itemLink)
Returns: number ItemTraitType traitType, string traitDescription
 from SI_ITEMTRAITTYPE0 to SI_ITEMTRAITTYPE60
 ITEM_TRAIT_TYPE_ARMOR_AGGRESSIVE = 47
 SI_ITEMTRAITTYPE38 = "Aggressive"
 SI_ITEMTRAITTYPE47 = "Aggressive"
 d( GetString(SI_ITEMTRAITTYPE0 + 47) )
   local itemIcon = GetItemLinkInfo(itemLink)
   itemIcon = "|t24:24:" .. itemIcon .. "|t"

ItemDisplayQuality
ITEM_DISPLAY_QUALITY_ARCANE
ITEM_DISPLAY_QUALITY_ARTIFACT
ITEM_DISPLAY_QUALITY_LEGENDARY
ITEM_DISPLAY_QUALITY_MAGIC
ITEM_DISPLAY_QUALITY_MYTHIC_OVERRIDE
ITEM_DISPLAY_QUALITY_NORMAL
ITEM_DISPLAY_QUALITY_TRASH
--]]

function WPamA:UpdateCompanionStoryQuests(ccid)
  local WCP = self.Companions.Persons
  local CCC = self.CurChar.Companions
  local SQ = WCP[ccid].SQ
  local CSQ = CCC[ccid].StoryQuests
  for sid = 1, #SQ do
    local qn = GetCompletedQuestInfo( SQ[sid] )
    CSQ[sid] = ( qn == "" )
  end
end -- UpdateCompanionStoryQuests end

function WPamA:SetCompanionsPersons()
  local WCP = self.Companions.Persons
  local WMS = self.ModeSettings
  local mode, hdtID = 29, 1 -- by default
--WCP: { IID = IngameCompanionId, DLC = CollectibleId, Name = "CompanionName", QID = QuestId, isLocked = lockedStatus }
  for ccid = 1, #WCP do
    local companionId = WCP[ccid].IID
    local companionName = zo_strformat( SI_COMPANION_NAME_FORMATTER, GetCompanionName(companionId) )
    if companionName ~= "" then
      WCP[ccid].Name = companionName
      if ccid < 7 then
        mode = 29
        hdtID = ccid
      else
        mode = 46
        hdtID = ccid - 6
      end
      if (ccid == 5) or (ccid == 8) then -- Sharp-As-Night or Zerith-var
        WMS[mode].HdT[hdtID] = companionName:gsub("-.+", "")
      else
        WMS[mode].HdT[hdtID] = companionName:gsub("%s.+", "")
      end
    end
  end
  ---
  self.Companions.MinSkillBarSlot, self.Companions.MaxSkillBarSlot = GetAssignableAbilityBarStartAndEndSlots()
end -- SetCompanionsPersons end

function WPamA:CheckCompanionsUnlocked()
  local WCP = self.Companions.Persons
  local CCC = self.CurChar.Companions
  -- WCP: { IID = IngameCompanionId, DLC = CollectibleId, Name = "CompanionName", QID = IntroQuestId,
  --        SQ = {StoryQuestIds}, isLocked = lockedStatus }
  for ccid = 1, #WCP do
    WCP[ccid].isLocked = not IsCollectibleUnlocked( WCP[ccid].DLC )
    local qn = GetCompletedQuestInfo( WCP[ccid].QID )
    CCC[ccid].hasQuest = ( qn == "" )
  end
end -- CheckCompanionsUnlocked end

local function GetCompanionLevelProgress(level, currentExperience)
  local expPerc = 0
  local expLvl = GetNumExperiencePointsInCompanionLevel(level + 1)
  if expLvl and (expLvl > 0) then expPerc = math.floor(100 * currentExperience / expLvl) / 100 end
  return expPerc
end -- GetCompanionLevelProgress end

local function GetCompanionSkillLineProgress(SkillLineID)
  local sid = WPamA.Companions.Iterators.SL[SkillLineID]
  if not sid then
    return 1, 0, true
  end
  local maxRank = WPamA.Companions.SkillLines[sid].Max or 20
  local SkillLineRank, _, isSkillLineDiscovered = GetCompanionSkillLineDynamicInfo(SkillLineID)
  if SkillLineRank < 1 then SkillLineRank = 1 end
  local xpPrc = 0
  if SkillLineRank < maxRank then
    local LastLineRankXP, NextLineRankXP, CurrentLineRankXP = GetCompanionSkillLineXPInfo(SkillLineID)
    local currLineXP = CurrentLineRankXP - LastLineRankXP
    local nextLineXP = NextLineRankXP - LastLineRankXP
    if nextLineXP > 0 then
      xpPrc = math.floor(100 * currLineXP / nextLineXP) / 100
    end
  end
  return SkillLineRank, xpPrc, (not isSkillLineDiscovered)
end -- GetCompanionSkillLineProgress end

local function GetItemDataFromLink(ItemLinkString)
  if type(ItemLinkString) == "string" then
    local tblDiv = {}
    string.gsub( ItemLinkString, ":(%d+)", function(s) table.insert(tblDiv, s) end )
    ---- string.gsub("|H1:item:175812:429:1:0:0:0:0:0:0:0:0:0:0:0:1:0:0:1:0:0:0|h|h", ":(%d+)", function(s) d(s) end)
    if tblDiv[1] and tblDiv[2] then return tblDiv[1] .. ":" .. tblDiv[2] end
  end
  return ""
end -- GetItemDataFromLink end

local function IsCompanionSkillLineDataCorrect(prevData, newData)
  -- Data : {Lvl = 1, LvlPrc = 0, isLocked = true}
  if newData.Lvl < prevData.Lvl then return false end
  --if newData.LvlPrc < prevData.LvlPrc then return false end
  if newData.isLocked and (not prevData.isLocked) then return false end
  return true
end

function WPamA:UpdActiveCompanionData(companionId)
  if not HasActiveCompanion() then return end
  if companionId == nil then companionId = GetActiveCompanionDefId() end
  local ccid = self.Companions.Iterators.I[companionId]
  if not ccid then return end
  self.Companions.ActiveCompanionId = ccid
  local WCP = self.Companions.Persons
  local ACC = self.SV_Main.Companions
  local CCC = self.CurChar.Companions
  local CSL = self.Companions.SkillLines
  local CES = self.Companions.EquipSlots
--[[
WCP = { IID = IngameCompanionId, DLC = CollectibleId, Name = "CompanionName", QID = IntroQuestId,
        SQ = {StoryQuestIds}, isLocked = lockedStatus }
CCC = { Rapport = 0, RapportLvl = 1, hasQuest = false, }
ACC = { Lvl = 99, LvlPrc = 0, Skills = { [ind] = {Lvl = 1, LvlPrc = 0, isLocked = true} },
        Equips = {[1]..[12] = "item link data"}, SkillBar = {[3]..[8] = AbilityId} }
--]]
  if WCP[ccid].isLocked then WCP[ccid].isLocked = false end
  if CCC[ccid].hasQuest then CCC[ccid].hasQuest = false end
  if not ACC[ccid].LvlPrc then ACC[ccid].LvlPrc = 0 end
  if not ACC[ccid].Skills then ACC[ccid].Skills = {} end
  if not ACC[ccid].Equips then ACC[ccid].Equips = {} end
  if not ACC[ccid].SkillBar then ACC[ccid].SkillBar = {} end
--
  local curRapport = GetActiveCompanionRapport()
  CCC[ccid].Rapport = curRapport
  local lvlRapport = GetActiveCompanionRapportLevel()
  CCC[ccid].RapportLvl = lvlRapport
  self:UpdateCompanionStoryQuests(ccid)
--
  local level, curExp = GetActiveCompanionLevelInfo()
  if (level > 0) and (curExp >= 0) then
    ACC[ccid].Lvl = level
    ACC[ccid].LvlPrc = GetCompanionLevelProgress(level, curExp)
  end
-- update Equip Slots --
  local equip = ACC[ccid].Equips
  for i = 1, #CES do
    local slotId = CES[i]
    local slotHasItem = GetWornItemInfo(BAG_COMPANION_WORN, slotId)
    if slotHasItem then
      --- slot has item ---
      local itemLink = GetItemLink(BAG_COMPANION_WORN, slotId, LINK_STYLE_DEFAULT)
      local itemData = GetItemDataFromLink(itemLink)
      if itemData ~= "" then
        equip[i] = itemData
      end
    else
      --- slot has no item ---
      equip[i] = ""
    end
  end
-- update Skill Lines --
  local sid, slp, sln = 0, {}, ACC[ccid].Skills
  for i = 1, #CSL do
    if i < 4 then sid = CSL[i].CID[ccid]
    else sid = CSL[i].ID
    end
    CSL[i].Name = GetCompanionSkillLineNameById(sid) or "???"
    if not sln[i] then sln[i] = {Lvl = 1, LvlPrc = 0, isLocked = true} end
    -- skill line progress by server API --
    slp.Lvl, slp.LvlPrc, slp.isLocked = GetCompanionSkillLineProgress(sid)
    if IsCompanionSkillLineDataCorrect(sln[i], slp) then
      -- save actual skill line progress --
      sln[i].Lvl = slp.Lvl
      sln[i].LvlPrc = slp.LvlPrc
      sln[i].isLocked = slp.isLocked
    end
  end
  --[[
-- update SkillBar Slots --
  if (self.Companions.MinSkillBarSlot == 0) or (self.Companions.MaxSkillBarSlot == 0) then
    self.Companions.MinSkillBarSlot, self.Companions.MaxSkillBarSlot = GetAssignableAbilityBarStartAndEndSlots()
  end
  local hotbar = ACC[ccid].SkillBar
  for slotIndex = self.Companions.MinSkillBarSlot, self.Companions.MaxSkillBarSlot do
    local abilityId = GetSlotBoundId(slotIndex, HOTBAR_CATEGORY_COMPANION)
    hotbar[slotIndex] = abilityId
    --local abilityName = GetAbilityName(abilityId)
    --d(zo_strformat("Slot:<<1>> AbilId:<<2>> [<<3>>]", slotIndex, abilityId, abilityName))
    --d(zo_strformat("Hotbar [<<1>>] = <<2>>", slotIndex, hotbar[slotIndex]))
  end
  --]]
---
end -- UpdActiveCompanionData end

function WPamA.OnCompanionActivated(event, companionId)
  WPamA:UpdActiveCompanionData(companionId)
  local m = WPamA.SV_Main.ShowMode
  local Modes = { [29] = true, [32] = true, [36] = true, [39] = true, [40] = true, [46] = true, [52] = true }
  if Modes[m] then WPamA:UpdWindowInfo() end
end -- OnCompanionActivated end

function WPamA.OnCompanionDeactivated(event)
  WPamA.Companions.ActiveCompanionId = 0
  local m = WPamA.SV_Main.ShowMode
  local Modes = { [32] = true, [36] = true, [39] = true, [40] = true, [52] = true }
  if Modes[m] then WPamA:UpdWindowInfo() end
end -- OnCompanionDeactivated end

function WPamA.OnCompanionRapportUpdate(event, companionId, previousRapport, currentRapport, adjustmentAmountType)
--EVENT_COMPANION_RAPPORT_UPDATE (integer companionId, integer previousRapport, integer currentRapport, CompanionRapportAdjustmentAmount adjustmentAmountType)
  local ccid = WPamA.Companions.Iterators.I[companionId]
  if not ccid then return end
  local CCC = WPamA.CurChar.Companions
  CCC[ccid].Rapport = currentRapport
  local oldLvl = CCC[ccid].RapportLvl
  local levelRapport = GetActiveCompanionRapportLevel()
  CCC[ccid].RapportLvl = levelRapport
  if oldLvl ~= levelRapport then WPamA:UpdateCompanionStoryQuests(ccid) end
--
  local m = WPamA.SV_Main.ShowMode
  if (m == 29) or (m == 46) then WPamA:UpdWindowInfo() end
end -- OnCompanionRapportUpdate end

function WPamA.OnCompanionExpGain(event, companionId, level, previousExperience, currentExperience)
--EVENT_COMPANION_EXPERIENCE_GAIN (*integer* _companionId_, *integer* _level_, *integer* _previousExperience_, *integer* _currentExperience_)
  local ccid = WPamA.Companions.Iterators.I[companionId]
  if not ccid then return end
  local ACC = WPamA.SV_Main.Companions -- ACC = { Lvl = 99, LvlPrc = 0, Skills = { [ind] = {Lvl = 1, LvlPrc = 0, isLocked = true} }, }
  local oldLvl = ACC[ccid].Lvl
  if (level > 0) and (currentExperience > 0) then
    ACC[ccid].Lvl = level
    ACC[ccid].LvlPrc = GetCompanionLevelProgress(level, currentExperience)
  end
--
  local m = WPamA.SV_Main.ShowMode
  local Modes = { [29] = true, [32] = true, [36] = true, [39] = true, [40] = true, [46] = true }
  if (m == 32) or ( Modes[m] and (oldLvl ~= ACC[ccid].Lvl) ) then WPamA:UpdWindowInfo() end
end -- OnCompanionExpGain end

function WPamA.OnCompanionSkillBarUpdate(event, actionSlotIndex, hotbarCategory)
--EVENT_HOTBAR_SLOT_STATE_UPDATED (luaindex actionSlotIndex, HotBarCategory hotbarCategory)
  if hotbarCategory ~= HOTBAR_CATEGORY_COMPANION then return end
  if not HasActiveCompanion() then return end
  --local sceneName = SCENE_MANAGER.currentScene:GetName()
  --if sceneName ~= "companionSkillsKeyboard" then return end
  local ccid = WPamA.Companions.ActiveCompanionId
  if ccid == 0 then
    local companionId = GetActiveCompanionDefId()
    ccid = WPamA.Companions.Iterators.I[companionId]
    if not ccid then return end
  end
--
  local ACC = WPamA.SV_Main.Companions
  --if not ACC[ccid].SkillBar then ACC[ccid].SkillBar = {} end
  local abilityId = GetSlotBoundId(actionSlotIndex, hotbarCategory)
  ACC[ccid].SkillBar[actionSlotIndex] = abilityId
     --[[
     d("-= HOTBAR SLOT STATE UPDATED =-")
     local aid = ACC[ccid].SkillBar[actionSlotIndex]
     local abilityName = GetAbilityName(aid)
     d(zo_strformat("Slot:<<1>> AbId:<<2>> [<<3>>]", actionSlotIndex, aid, abilityName))
     --]]
--
  local m = WPamA.SV_Main.ShowMode
  if m == 52 then WPamA:UpdWindowInfo() end
end -- OnCompanionSkillBarUpdate end

function WPamA.OnCompanionSkillLineUpdate(event, skillLineId, ...)
--EVENT_COMPANION_SKILL_LINE_ADDED (*integer* _skillLineId_)
--EVENT_COMPANION_SKILL_RANK_UPDATE (*integer* _skillLineId_, *luaindex* _rank_)
--EVENT_COMPANION_SKILL_XP_UPDATE (*integer* _skillLineId_, *integer* _reason_, *luaindex* _rank_, *integer* _previousXP_, *integer* _currentXP_)
  local sid = WPamA.Companions.Iterators.SL[skillLineId]
  if not sid then return end
  local companionId = GetActiveCompanionDefId()
  local ccid = WPamA.Companions.Iterators.I[companionId]
  if not ccid then return end
--
  local ACC = WPamA.SV_Main.Companions -- ACC = { Lvl = 99, LvlPrc = 0, Skills = {}, Equips = {} }
  local sln = ACC[ccid].Skills[sid] -- Skills = { [ind] = {Lvl = 1, LvlPrc = 0, isLocked = true} }
  if not sln then sln = {Lvl = 1, LvlPrc = 0, isLocked = true} end
--
  local slp = {} -- skill line progress by server API
  slp.Lvl, slp.LvlPrc, slp.isLocked = GetCompanionSkillLineProgress(skillLineId)
  if IsCompanionSkillLineDataCorrect(sln, slp) then
    -- save actual skill line progress --
    sln.Lvl = slp.Lvl
    sln.LvlPrc = slp.LvlPrc
    sln.isLocked = slp.isLocked
  end
  if (sid < 4) and (ACC[ccid].Lvl < sln.Lvl) then -- just for rare cases of delayed event
    ACC[ccid].Lvl = sln.Lvl
    ACC[ccid].LvlPrc = sln.LvlPrc
  end
--
  local m = WPamA.SV_Main.ShowMode
  if (m == 32) or (m == 36) then WPamA:UpdWindowInfo() end
end -- OnCompanionSkillLineUpdate end

function WPamA.OnCompanionEquipSlotUpdate(event, bagId, slotId, ... )
--EVENT_INVENTORY_SINGLE_SLOT_UPDATE (*Bag* _bagId_, *integer* _slotIndex_, *bool* _isNewItem_, ...)
  if bagId ~= BAG_COMPANION_WORN then return end
  local sid = WPamA.Companions.Iterators.ES[slotId]
  if not sid then return end
  local companionId = GetActiveCompanionDefId()
  local ccid = WPamA.Companions.Iterators.I[companionId]
  if not ccid then return end
--
  local ACC = WPamA.SV_Main.Companions -- ACC = { Lvl = 99, LvlPrc = 0, Skills = {}, Equips = {} }
  if not ACC[ccid].Equips then ACC[ccid].Equips = {} end
  if not ACC[ccid].Equips[sid] then ACC[ccid].Equips[sid] = "" end
--
  local slotHasItem = GetWornItemInfo(bagId, slotId)
  if slotHasItem then
    --- item of equipment worn ---
    local itemLink = GetItemLink(bagId, slotId, LINK_STYLE_DEFAULT)
    local itemData = GetItemDataFromLink(itemLink)
    if itemData ~= "" then
      ACC[ccid].Equips[sid] = itemData
    end
  else
    --- item of equipment removed ---
    ACC[ccid].Equips[sid] = ""
  end
--
  local m = WPamA.SV_Main.ShowMode
  if (m == 39) or (m == 40) then WPamA:UpdWindowInfo() end
end -- OnCompanionEquipSlotUpdate end
--=========================================================================
--=============== Promo Event Activity Section ============================
--=========================================================================
local ActivePromoCampaignIndex = 1

local function GetPromoActivityRewardString(RID, RQ) -- rewardID, rewardQuantity
  if not RQ then RQ = 0 end
  local RS = ""
  if RQ > 0 then
    local rewardData = REWARDS_MANAGER:GetInfoForReward(RID, 1)
    RS = zo_strformat(RewardTextFormatter, RS, RQ, rewardData.icon)
  end
  return RS
end -- GetPromoEventRewardString end

function WPamA:PromoActivityDataUpdate( paKey, paIndex )
  if IsPromotionalEventSystemLocked() then return end
  --local paCampaignsNum = GetNumActivePromotionalEventCampaigns() --??
  --if paCampaignsNum < 1 then return end
  local isNeedCampaignProgressUpdate = false
--- Init Condition's arrays ---
  if not paKey then
    PromoEventActivity.Conditions = {}
    PromoEventActivity.Index = {}
    paKey = GetActivePromotionalEventCampaignKey(ActivePromoCampaignIndex or 1)
    paIndex = 0
    isNeedCampaignProgressUpdate = true
  end
  if paIndex == 0 then RemainActivityProgress.Promo = {} end
  local remain = RemainActivityProgress.Promo
--- Update promo-event Activity's status ---
  local paNum = GetNumPromotionalEventCampaignActivities(paKey)
  if paNum < 1 then return end
  local tinsert = table.insert
  local startLoop = (paIndex == 0) and 1 or paIndex
  local endLoop   = (paIndex == 0) and paNum or paIndex
  for i = startLoop, endLoop do
    local paProgress = GetPromotionalEventCampaignActivityProgress(paKey, i) -- , rewardFlags
    local paID, paName, _, paMaxProgress, paRewardID, paValue = GetPromotionalEventCampaignActivityInfo(paKey, i)
    paName = paName:gsub("|t%d%d:%d%d:","|t18:18:")
    --[[
    d("Act [" .. i .. "] [" .. paName .. "]")
    d("Progress : " .. paProgress .. " / " .. paMaxProgress)
    d("Reward ID [" .. paRewardID .. "] Q [" .. paValue .. "]")
    --]]
    --- Set max progress for promo-event Activity's types ---
    local typedName = paName:gsub(" (%d+)", " #")
    if (paIndex == 0) and (paProgress < paMaxProgress) then
      if remain[typedName] then
        if remain[typedName] < paMaxProgress then remain[typedName] = paMaxProgress end
      else
        remain[typedName] = paMaxProgress
      end
    end
    --- Show promo-event Activity's progress in chat ---
    if paIndex > 0 then
      local paText = zo_strformat(EndeavorChatFormatter, paName, paProgress, paMaxProgress, "")
      if paText == PromoActivityChatMessageText then
        return
      else
        PromoActivityChatMessageText = paText
        local PPiC = self.SV_Main.PursuitProgressInChat
        if PPiC.Enabled then
          local paColor = ""
          if PPiC.isUseCustomColor then
            if PPiC.Color:len() < 6 then PPiC.Color = string.format("%02x%02x%02x", 238, 238, 200) end
            --paText = zo_strformat("|c<<1>><<3>><<2>>|r", PPiC.Color, paText,
            --         self.Textures.GetTexture(47, GetChatFontSize(), true) )
            paColor = PPiC.Color
          end
          local isNotPostToChat = (PPiC.CampRewardEarned or false) and
                                  (PromoEventActivity.Campaign.isComplete or false)
          if not isNotPostToChat then
            --self:PostChatMessage(paText, PPiC.Channel)
            PostProgressToChat("Promo", paName, paProgress, paMaxProgress, paColor, PPiC.Channel)
          end
        end -- Progress in chat enabled
      end
    end
--- Save promo-event Activity's data to array ---
    local paCompl = paProgress >= paMaxProgress
    local isValueReward = paValue > 0
    local percProgr = zo_floor(100 * paProgress / paMaxProgress)
    ---  { Ind = peaIndex, Name = "", Progress = "", Reward = "", Value = 0, isComplete = false }
    local cond = { Ind = i, Name = paName, isComplete = paCompl,
                   Value = 2 + percProgr + paValue * (isValueReward and 100 or 1),
                   Progress = zo_strformat("<<1>> / <<2>>", paProgress, paMaxProgress),
                   Reward = (paValue > 0) and GetPromoActivityRewardString(paRewardID, paValue) or "" }
    if paIndex > 0 then
      local ind = PromoEventActivity.Index[paIndex]
      if ind then PromoEventActivity.Conditions[ind] = cond end
      if paCompl then isNeedCampaignProgressUpdate = true end
    else
      tinsert(PromoEventActivity.Conditions, cond)
    end
  end -- for PA Loop
--- Sort and Reindex data array ---
  table.sort( PromoEventActivity.Conditions,
              function(v1, v2)
                local valV1 = v1.isComplete and 1 or v1.Value
                local valV2 = v2.isComplete and 1 or v2.Value
                if valV1 == valV2 then return v1.Name < v2.Name end
                return valV2 < valV1
              end )
  PromoEventActivity.Index = {}
  for ind = 1, #PromoEventActivity.Conditions do
    local condInd = PromoEventActivity.Conditions[ind].Ind
    PromoEventActivity.Index[condInd] = ind
  end
--- Update Campaign's and Milestone's data ---
  if isNeedCampaignProgressUpdate then
    --- campaignId, numActivities, numMilestones, capstoneCompletionThreshold, capstoneRewardId, capstoneRewardQuantity
    local capID, _, _, capCompletionThreshold, capRewardID, capRewardQuantity = GetPromotionalEventCampaignInfo(paKey)
    local paCompletedNum = GetPromotionalEventCampaignProgress(paKey) -- , capstoneRewardFlags
    PromoEventActivity.Campaign = { Key = paKey, Name = GetPromotionalEventCampaignDisplayName(capID),
                                    Reward = GetPromoActivityRewardString(capRewardID, capRewardQuantity),
                                    Progress = zo_strformat("<<1>> / <<2>>", paCompletedNum, capCompletionThreshold),
                                    EndTS = 0, isComplete = paCompletedNum >= capCompletionThreshold }
    local secondsRemaining = GetSecondsRemainingInPromotionalEventCampaign(paKey)
    if secondsRemaining > 0 then
      PromoEventActivity.Campaign.EndTS = secondsRemaining + GetTimeStamp()
    end
    ---
  end
--SI_ACTIVITY_FINDER_CATEGORY_PROMOTIONAL_EVENTS, "Golden Pursuits"
--SI_LEVEL_UP_REWARDS_NEXT_MILESTONE_REWARD_HEADER, "Next Milestone - Level <<X:1>>"
--SI_GROUPING_TOOLS_PANEL_CURRENT_CAMPAIGN, "Current Campaign:"
--SI_GUILDMETADATAATTRIBUTE4, "Activities"
end -- PromoActivityDataUpdate end

function WPamA.OnPromoActivityUpdated(event, ... )
  if event == EVENT_PROMOTIONAL_EVENTS_CAMPAIGNS_UPDATED then
    local PromoCampaigns, RetPlayerCampaigns = {}, {}
    local numActiveCampaigns = GetNumActivePromotionalEventCampaigns()
    if numActiveCampaigns > 1 then
      for camp = 1, numActiveCampaigns do
        local campaignKey = GetActivePromotionalEventCampaignKey(camp)
        local capstoneCompletionThreshold = select(4, GetPromotionalEventCampaignInfo(campaignKey))
        local numActivitiesCompleted = GetPromotionalEventCampaignProgress(campaignKey) -- , isCapstoneRewardClaimed
        if IsReturningPlayerPromotionalEventsCampaign(campaignKey) then
          if numActivitiesCompleted < capstoneCompletionThreshold then
            table.insert(RetPlayerCampaigns, camp)
          end
        else
          table.insert(PromoCampaigns, camp)
        end
      end -- for Active Campaigns
    end
    ActivePromoCampaignIndex = PromoCampaigns[1] or RetPlayerCampaigns[1] or 1
    WPamA:PromoActivityDataUpdate()
---
  elseif event == EVENT_PROMOTIONAL_EVENTS_ACTIVITY_PROGRESS_UPDATED then
    -- *id64* campaignKey, *luaindex* activityIndex, *integer* previousProgress,
    -- *integer* newProgress, *PromotionalEventRewardFlags* rewardFlags
    local campaignKey, activityIndex = ...
    local promoKey = GetActivePromotionalEventCampaignKey(ActivePromoCampaignIndex)
    if campaignKey ~= promoKey then return end
    WPamA:PromoActivityDataUpdate(campaignKey, activityIndex)
    --[[
    local campaignKey, activityIndex, prevProgress, newProgress, rewardFlags = ...
    local isRewardClaimed = (rewardFlags == PROMOTIONAL_EVENTS_REWARD_FLAG_CLAIMED) or false
    d("-=== Promo Progress Upd ===-")
    d("Act [" .. activityIndex .. "] Claimed = " .. (isRewardClaimed and "T" or "F"))
    d("Prev [" .. prevProgress .. "] New [" .. newProgress .. "]")
    --]]
    --local maxProgress = select( 4, GetPromotionalEventCampaignActivityInfo(campaignKey, activityIndex) )
    if WPamA.SV_Main.AutoClaimPursuitReward and -- (newProgress >= maxProgress) and
       IsAnyPromotionalEventCampaignRewardClaimable(campaignKey) then
      TryClaimAllAvailablePromotionalEventCampaignRewards(campaignKey)
    end
  end
  local m = WPamA.SV_Main.ShowMode
  if m == 27 then WPamA:UpdWindowInfo() end -- Promo event activity update
end -- OnPromoActivityUpdated end
