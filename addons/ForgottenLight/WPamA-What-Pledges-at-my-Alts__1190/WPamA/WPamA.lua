--
-- Section 1: Aliases of simple functions
--
local WPamA = WPamA
local nvl = WPamA.SF_NvlN
local msg = WPamA.SF_Msg
local BoolToStr = WPamA.SF_BoolToStr
local OldReloadUI -- the original func link
--
-- Section 2: Support functions
--
function WPamA:SetLFGRewardTime(ActNum)
-- LFG_ACTIVITY_INVALID / LFG_ACTIVITY_DUNGEON
-- LFG_ACTIVITY_BATTLE_GROUND_NON_CHAMPION / LFG_ACTIVITY_TRIBUTE_CASUAL
  if not ActNum then ActNum = LFG_ACTIVITY_INVALID end
  local v = self.CurChar
  local isCooldownUpdated = false
  local TS = GetTimeStamp()
  local LFGCooldownType = self.Consts.LFGCooldownType
--
  local function GetLFGRewardCooldown(activityType)
    local n = GetLFGCooldownTimeRemainingSeconds(LFGCooldownType[activityType])
    local isOnCooldown = (n > 0) or (not IsActivityEligibleForDailyReward(activityType))
    if isOnCooldown then return TS else return nil end
  end
--
  if ActNum == LFG_ACTIVITY_INVALID then -- all activity types
    for act, _ in pairs(LFGCooldownType) do
      v.LFGActivities[act] = GetLFGRewardCooldown(act)
    end
    isCooldownUpdated = true
  elseif LFGCooldownType[ActNum] then -- known activity types
    v.LFGActivities[ActNum] = GetLFGRewardCooldown(ActNum)
    isCooldownUpdated = true
  end
--
  if isCooldownUpdated then
    GetAddOnManager():RequestAddOnSavedVariablesPrioritySave(self.Name)
    if self.SV_Main.ShowMode == 7 then self:UpdWindowInfo() end
  end
--LFG_ACTIVITY_ARENA / LFG_ACTIVITY_AVA / LFG_ACTIVITY_ENDLESS_DUNGEON
--LFG_ACTIVITY_EXPLORATION / LFG_ACTIVITY_HOME_SHOW / LFG_ACTIVITY_TRIAL
end -- SetLFGRewardTime end

function WPamA:QDump(flCond)
  local n = 0
  for i = 1, MAX_JOURNAL_QUESTS do -- GetNumJournalQuests()
    if IsValidQuestIndex(i) then
-- questName,backgroundText,activeStepText,activeStepType, activeStepTrackerOverrideText, completed, tracked, questLevel,pushed,questType,instanceDisplayType=GetJournalQuestInfo(i)
      local questName, _, _, _, activeStep, _, _, _, _, questType = GetJournalQuestInfo(i)
      local questType = GetJournalQuestType(i)
      local isRepeat = GetJournalQuestRepeatType(i)
      self:Debug("DmpQ > QN: " .. questName .. "; JI: " .. i .. "; QT: " .. questType .. "; IR: " .. isRepeat .. "; AS: " .. activeStep, 1)
      if flCond then
        local JQCondNum = GetJournalQuestNumConditions(i, QUEST_MAIN_STEP_INDEX)
        for j = 1, JQCondNum do
          local txt = GetJournalQuestConditionInfo(i, QUEST_MAIN_STEP_INDEX, j)
          self:Debug("DmpQ > Cond[" .. j .. "] = [" .. nvl(txt) .. "]", 1)
        end
      end
      n = n + 1
    end
  end
  msg("Dumped " .. n .. " quests to debug buffer")
end

function WPamA:StartCheckTrialLoot(questId)
  local tr = self.TrialDungeons.Iterators.Q[questId] or false
  if tr then
    self.CurChar.Trials[tr].Act = 0
    self.TS_CheckTrialLoot = GetTimeStamp()
    --self.TR_CheckTrialLoot = tr
    EVENT_MANAGER:RegisterForEvent(self.Name .. "Trials", EVENT_LOOT_RECEIVED, self.OnTrialLootReceived)
    --self:Debug("LootR > Start at TS:" .. self.TS_CheckTrialLoot)
  end
end

function WPamA:StopCheckTrialLoot(TS)
  self.TS_CheckTrialLoot = nil
  --self.TR_CheckTrialLoot = nil
  EVENT_MANAGER:UnregisterForEvent(WPamA.Name .. "Trials", EVENT_LOOT_RECEIVED)
  --self:Debug("LootR > End at TS:" .. TS)
end


function WPamA:StopAIAndRestoreCgf()
  if AutoInvite ~= nil and AutoInviteUI ~= nil then
    AutoInvite.disable()
    local aic = AutoInvite.cfg
    aic.watchStr = self.AICfg.watchStr
    aic.maxSize = self.AICfg.maxSize
    aic.cyrCheck = self.AICfg.cyrCheck
    --aic.restart = false
    --aic.autoKick = false
    --aic.kickDelay = 300
    --aic.showPanel = true
    AutoInviteUI.refresh()
  end
end

function WPamA:GetSkillLineNum(st, si)
  local i, SL = 0, self.SkillLines.SkillLines
  if st == SKILL_TYPE_CLASS then
    for j=1,3 do
      if SL[j].si == si then
        i = j
        break
      end
    end
  elseif st == SKILL_TYPE_AVA then
    for j=17,19 do
      if SL[j].si == si then
        i = j
        break
      end
    end
  elseif st == SKILL_TYPE_TRADESKILL then
    for j=7,13 do
      if SL[j].si == si then
        i = j
        break
      end
    end
  elseif st == SKILL_TYPE_GUILD then
    local _, texture, _, _, _, _, _ = GetSkillAbilityInfo(st, si, 1)
    for _, j in pairs( self.SkillLines.SkillLineModes[12] ) do
      if string.find(texture, SL[j].mrk) then
        i = j
        break
      end
    end
  elseif st == SKILL_TYPE_WORLD then
    local _, texture, _, _, _, _, _ = GetSkillAbilityInfo(st, si, 1)
    for _, j in pairs( self.SkillLines.SkillLineModes[24] ) do
      if string.find(texture, SL[j].mrk) then
        i = j
        break
      end
    end
  end
  return i
end

function WPamA:ClcSkillRank(lastRankXP, nextRankXP, currentXP)
  local NR_XP, CurXP = nextRankXP - lastRankXP, currentXP - lastRankXP
  if NR_XP > 0 and CurXP < NR_XP then
    return math.floor(100 * CurXP / NR_XP) / 100
  end
  return 0
end

function WPamA:UpdSVSkills(i, rank, lastRankXP, nextRankXP, currentXP)
  local r = rank + self:ClcSkillRank(lastRankXP, nextRankXP, currentXP)
  local SK = self.CurChar.Skills
  local SL = self.SkillLines.SkillLines
  if SK[i].rank ~= r then
    --if SK[i].rank > r and r == rank then r = r + 1 end
    SK[i].rank = r 
    if SL[i].m == self.SV_Main.ShowMode then
      self:UpdWindowInfo()
    end
   end
end

function WPamA:GetSkillLineInfo(st, sli)
  local data = SKILLS_DATA_MANAGER:GetSkillLineDataByIndices(st, sli)
  if data then
    local isPlayerClassSkillLine, classId = false, 0
    if st == SKILL_TYPE_CLASS then
      isPlayerClassSkillLine = data:IsPlayerClassSkillLine() or false
      classId = data:GetClassId() or 0
    end
    return data:GetName(), data:GetCurrentRank(), data:IsAvailable(),
           isPlayerClassSkillLine, classId
           -- data:GetId(), data:IsActive()
           -- data:IsAdvised(), data:IsDiscovered(), data:GetUnlockText()
           -- data:GetSkillPointCostMultiplier() -- value = 1 or 2 -- SKILL_TYPE_CLASS
           -- data:IsDisabled() -- or data:IsContentLocked() -- SKILL_TYPE_CLASS
--    data:IsProgressionAccountWide()
--    self.classId = GetSkillLineClassId(skillType, skillLineIndex)
--    self.classAccessCollectibleId = GetClassAccessCollectibleId(self.classId)
--    self.masteryCollectible = GetSkillLineMasteryCollectibleId(self.id)
--    self.isPlayerClassSkillLine = IsPlayerClassSkillLineById(self.id)
--    GetSkillLinePointCostMultiplier(skillType, skillLineIndex)
  end
  return "", 1, false, false, 0 -- , 0, false
end

function WPamA:GetSkillLineProgress(st, si)
  local name, rank = self:GetSkillLineInfo(st, si)
  return name:gsub("%^.+", ""), rank + self:ClcSkillRank(GetSkillLineXPInfo(st, si))
end

function WPamA:GetSkillAbilityInfo(st, si, n)
  local name, _, _, _, _, purchased =  GetSkillAbilityInfo(st, si, n)
  local cur, max = 0, 0
  if purchased then
    cur, max = GetSkillAbilityUpgradeInfo(st, si, n)
    if cur == nil then cur = 1 end
  end
  return name:gsub("%^.+", ""), cur
end

function WPamA:FindSkillLines(SL)
  local res = 0
  for si = 1, GetNumSkillLines(SL.typ) do
    local sli = GetSkillLineId(SL.typ, si)
    local sln = GetSkillLineNameById(sli)
    if not sln:find("%(") then
      local texture = select(2, GetSkillAbilityInfo(SL.typ, si, 1))
      if texture:find(SL.mrk) then
        res = si
        break
      end
    end
  end
  return res
end

function WPamA:UpdShadowySupplier(skillIndex)
  if self.CurChar.ShSupplier == nil then self.CurChar.ShSupplier = {Avl=0, Option=1, Mode=1} end
  local SV = self.CurChar.ShSupplier
  local si = skillIndex or self:FindSkillLines( self.SkillLines.SkillLines[self.SkillLines.SkillLineDarkBr] )
  if si == 0 then
    SV.Avl = 1
  else
----    local abilityName,_,_,_,_,abilityPurchased = GetSkillAbilityInfo(SKILL_TYPE_GUILD,si,4)
    local abilityPurchased = select(6, GetSkillAbilityInfo(SKILL_TYPE_GUILD,si,4) )
    if abilityPurchased then
      SV.Avl = 2
      local timeRemaining = GetTimeToShadowyConnectionsResetInSeconds()
      if timeRemaining > 0 then
        SV.Timer = GetTimeStamp() + timeRemaining
      else
        SV.Timer = nil
      end
    else
      SV.Avl = 1
    end
  end
end -- UpdShadowySupplier end

function WPamA:Init1SkillLines(SV, SL, st, si, i)
  local name, TT = "", self.i18n.ToolTip
  name, SV[i].rank = self:GetSkillLineProgress(st, si)
  if st == SKILL_TYPE_CLASS then
    local classIcon = self.Consts.IconsW.Classes
    local icon = zo_strformat("|t26:26:<<1>>|t", classIcon[SL.cl] or " ")
    if string.find(TT[SL.tt], "\n") then TT[SL.tt] = TT[SL.tt]:gsub("\n.+", "") end
    name = zo_strformat("<<1>>\n<<2>><<3>>", TT[SL.tt], name, icon)
  end
  local a = ""
  if SL.N1 ~= nil then
    a, SV[i].A1 = self:GetSkillAbilityInfo(st, si, SL.N1)
    name = name .. "\n " .. self.Colors.dlm_slash .. a
  end
  if SL.N2 ~= nil then
    a, SV[i].A2 = self:GetSkillAbilityInfo(st, si, SL.N2)
    name = name .. "\n " .. self.Colors.dlm_slash .. a
  end
  if SL.N3 ~= nil then
    a, SV[i].A3 = self:GetSkillAbilityInfo(st, si, SL.N3)
    name = name .. "\n " .. self.Colors.dlm_slash .. a
  end
  if st == SKILL_TYPE_TRADESKILL then
    name = name .. TT[250]
  --elseif st == SKILL_TYPE_AVA then
  --  name = name:gsub("%((.+)%)","") -- remove "( text )" from AvA's skill name
  end
  TT[SL.tt] = name
end

local function GetCraftingSkillLineInd(TradeSkillType)
  local SLD = SKILLS_DATA_MANAGER:GetCraftingSkillLineData(TradeSkillType)
  if SLD then return SLD:GetIndices() end
  return 0, 0, 0
end

local function CheckCurrentClassSkillLines()
  local SL = WPamA.SkillLines.SkillLines
  local st = SKILL_TYPE_CLASS
  local i = 0
  for sli = 1, GetNumSkillLines(st) do
    --local slId = GetSkillLineId(st, sli)
    --local SkillLineName = GetSkillLineNameById(slId)
    local Rank, _, isActive = GetSkillLineDynamicInfo(st, sli)
    if isActive and (Rank > 0) then
      i = i + 1
      local cid = GetSkillLineClassId(st, sli)
      -- [ 1 | 2 | 3 ] = {max = 50, typ = SKILL_TYPE_CLASS, si = 1, cl = 0}
      SL[i].si = sli
      SL[i].cl = cid
    end
  end
end

function WPamA:InitSkillLines()
  CheckCurrentClassSkillLines()
  if self.CurChar.Skills == nil then self.CurChar.Skills = {} end
  local SV = self.CurChar.Skills
  local CertQID = self.CraftCerts.QuestIDs
  local DW = self.CurChar.DailyWrits
  local TS = GetTimeStamp()
  for i = 1, #self.SkillLines.SkillLines do
    if SV[i] == nil then SV[i] = {} end
    local SL = self.SkillLines.SkillLines[i]
    local st, si = SL.typ, 0
    if st == SKILL_TYPE_CLASS or st == SKILL_TYPE_AVA then
      si = SL.si
    elseif st == SKILL_TYPE_GUILD or st == SKILL_TYPE_WORLD then
      si = self:FindSkillLines(SL)
    elseif st == SKILL_TYPE_TRADESKILL then
      st, si = GetCraftingSkillLineInd(SL.sub)
      SL.si = si
      -- Check for this crafting profession Certification --
      local wi = i - 6
      local qn = GetCompletedQuestInfo( CertQID[wi] )
      SV[i].isCert = ( qn ~= "" )
      ---
      local wr = DW[wi]
      if wr.Act == 2 then
        if wr.EndTS > 0 then
          if TS >= wr.EndTS then
            wr.Act = 0
            wr.EndTS = 0
          end
        else
          wr.EndTS = self:GetNextDailyResetTS()
        end
      end
    end
    if si > 0 then
      self:Init1SkillLines(SV, SL, st, si, i)
    else
      SV[i].rank = 0
    end
  end
  local m = self.SV_Main.ShowMode
  local Modes = { [4] = true, [5] = true, [12] = true, [24] = true, [31] = true }
  if Modes[m] then
    self:UI_UpdMainWindowHdr()
    self:UpdWindowInfo()
  end
end

function WPamA:ReloadSkillsAbility()
  local f, SV = false, self.CurChar.Skills
  for i=1, #self.SkillLines.SkillLines do
    local SL = self.SkillLines.SkillLines[i]
    if SL.N1 ~= nil or SL.N2 ~= nil or SL.N3 ~= nil then
      local st, si = SL.typ, 0
      if st == SKILL_TYPE_GUILD or st == SKILL_TYPE_WORLD then
        si = self:FindSkillLines(SL)
      else
        si = SL.si
      end
      if SL.N1 ~= nil then
        local _, n = self:GetSkillAbilityInfo(st, si, SL.N1)
        if n ~= SV[i].A1 then
          SV[i].A1, f = n, true
        end
      end
      if SL.N2 ~= nil then
        local _, n = self:GetSkillAbilityInfo(st, si, SL.N2)
        if n ~= SV[i].A2 then
          SV[i].A2, f = n, true
        end
      end
      if SL.N3 ~= nil then
        local _, n = self:GetSkillAbilityInfo(st, si, SL.N3)
        if n ~= SV[i].A3 then
          SV[i].A3, f = n, true
        end
      end
    end 
  end 
  local m = self.SV_Main.ShowMode
  if f and (m == 4 or m == 5 or m == 12) then
    self:UI_UpdMainWindowHdr()
    self:UpdWindowInfo()
  end 
end

function WPamA:GetCurrentDBoss()
  local b = self.WorldBosses.Bosses
  local v = self.CurChar.DBossLoc[self.RGLA_Mode]
  if v == nil or v < 1 or v > #b then
    return 0
  end
  return v
end

function WPamA:GetDWBJournalIndex(num)
  local b = self.WorldBosses.Bosses
  if (num == nil) or (num < 1) or (num > #b) then return 0 end
  local qid = b[num].QID
  if qid == nil then return 0 end
  local qn = GetQuestName(qid)
---
  for i = 1, MAX_JOURNAL_QUESTS do -- GetNumJournalQuests()
    if IsValidQuestIndex(i) then
      if GetJournalQuestName(i) == qn then
        return i
      end
    end
  end
  return 0
end

function WPamA:ShareQuest(ji)
  ShareQuest(ji)
  if self.SV_Main.QAlert then
    ZO_Alert(UI_ALERT_CATEGORY_ALERT, SOUNDS.QUEST_SHARE_SENT, GetString(SI_QUEST_SHARED))
  end
  if self.SV_Main.QChat then
    msg(GetString(SI_QUEST_SHARED))
  end
end 

function WPamA:CheckDungNum(num)
  if num == nil or num <= 1 then
    return 1
  elseif num > #self.GroupDungeons.Dungeons then
    return 2
  end
  return num
end

function WPamA:GetDungeonName(num)
  if not num then return "no name" end -- protection against the "attempt to index a nil value" error
  if self.SV_Main.ShowLoc and (num > 2) then
    local mapName = GetMapInfoByIndex(self.GroupDungeons.Dungeons[num].Loc)
    mapName = LocalizeString(self.SI_TOOLTIP_ITEM_NAME, mapName)
    return mapName
  end
  if self.SV_Main.ENDung and (num > 2) then
    return self.EN.DungeonsName[num]
  end
  return self.i18n.Dungeons[num].N
end

function WPamA:GetPledgeCycleDungNum(npc, noffset)
  local Ord = self.GroupDungeons.OrdPledges[npc]
  local num = 1 + noffset % #Ord
  return Ord[num] or 1
end

function WPamA:IsTodayDungNumAndNPC(indexDung, indexNPC)
  if self.GroupDungeons.OrdPledges[indexNPC] and (self:CheckDungNum(indexDung) > 2) then
    local num = self:GetPledgeCycleDungNum(indexNPC, self.Today.Diff + 1)
    return num == indexDung
  end
  return false
end

function WPamA:GetTodayDungNumByNPC(npc)
  if not self.GroupDungeons.OrdPledges[npc] then return 1 end -- no NPC = no dungeon
  return self:GetPledgeCycleDungNum(npc, self.Today.Diff + 1)
end

function WPamA:UpdWWBAchiev()
  local _, numCompleted, numRequired = GetAchievementCriterion(self.Consts.WWBAchiev, 1)
  self.CurChar.numWWB = numRequired - numCompleted
end

function WPamA:IsRGLALocation()
  local mzi = GetCurrentMapZoneIndex()
  --msg("MapZoneInd=" .. nvl(mzi))
  if mzi == nil or mzi ~= self.WorldBosses.Locations[self.RGLA_Mode].MZI then
    return false
  end
  return true
end

function WPamA:UpdRGLAMode()
  local mzi = GetCurrentMapZoneIndex()
  if mzi ~= nil then
    local old = self.RGLA_Mode
    for i, v in pairs(self.WorldBosses.Locations) do
      if mzi == v.MZI then
        self.RGLA_Mode = i
        break
      end
    end
---
    if old ~= self.RGLA_Mode then
      local l = self.WorldBosses.Locations[self.RGLA_Mode]
      for i = 1, 6 do
        local j = l.b + i - 1
        if j <= l.e then
          self:RGLACtrlSetText(i, self.WorldBosses.Bosses[j].H)
        else
          self:RGLACtrlSetText(i, "")
        end
      end
    end
  end
end

function WPamA:SetMode(Mode, CanTogle)
  WPamA_SelWind:SetHidden(true)
  local SV = self.SV_Main
  --
  self.ClearItemToolTip()
  if SV.ShowMode == 52 then self.SetAbilityToolTip() end -- clear skill/ability tooltip
  --
  if SV.ShowMode ~= Mode then
    SV.ShowMode = Mode
    self:UpdWindowInfo()
    self.ShowUI()
  elseif CanTogle then
    self.TogleUI()
  end
end

function WPamA:WinFirstVisible(WinInd)
  local WS = self.WindSettings[WinInd]
  local m = self.SV_Main.isModeVisible
  local j = 0
  local mzi = GetCurrentMapZoneIndex()
  if WinInd == 2 and mzi ~= nil then -- World Bosses Window
    for _, v in pairs(self.WorldBosses.Locations) do
      if v.MZI == mzi then
        return v.m
      end
    end
  end
  for i = 1, self.TabBCount do
    if WS.Mds[i] ~= nil then
      if j == 0 then j = i end
      if m[WS.Mds[i]] then
        j = i
        break
      end
    end
  end
  return WS.Mds[j]
end

function WPamA:NextWin()
  local m = self.SV_Main.isWindVisible
  local MS = self.ModeSettings[self.SV_Main.ShowMode]
  local j = MS.WinInd
  local WS = self.WindSettings
  for i = MS.WinInd+1, self.WindCount-1 do
    if WS[i] ~= nil and m[i] then
      j = i
      break
    end
  end
  if j == MS.WinInd then
    for i = 0, MS.WinInd-1 do
      if WS[i] ~= nil and m[i] then
        j = i
        break
      end
    end
  end
  if j == MS.WinInd then
    return self.SV_Main.ShowMode
  end
  return self:WinFirstVisible(j)
end 

function WPamA:NextTab()
  local m = self.SV_Main.isModeVisible
  local MS = self.ModeSettings[self.SV_Main.ShowMode]
  local WI = MS.WinInd
  local TI = MS.TabInd
  local WS = self.WindSettings[WI]
  local j = TI
  for i = TI+1, self.TabBCount do
    if WS.Mds[i] ~= nil and m[WS.Mds[i]] then
      j = i
      break
    end
  end
  if j == TI then
    for i = 1, TI-1 do
      if WS.Mds[i] ~= nil and m[WS.Mds[i]] then
        j = i
        break
      end
    end
  end
  return WS.Mds[j]
end 

function WPamA:NextMode()
  local m = self.SV_Main.isModeVisible
  local MS = self.ModeSettings[self.SV_Main.ShowMode]
  local MO = self.ModeOrder
  local j = MS.MOrder
  for i = MS.MOrder+1, self.ModeCount-1 do
    if MO[i] ~= nil and m[MO[i]] then
      j = i
      break
    end
  end
  if j == MS.MOrder then
    for i = 0, MS.MOrder-1 do
      if MO[i] ~= nil and m[MO[i]] then
        j = i
        break
      end
    end
  end
  return MO[j]
end 

function WPamA:LoadDLCinfo(Arr)
  for _, v in pairs(Arr) do
    if v.DLC == nil or IsCollectibleUnlocked(v.DLC) then
      v.isLocked = false
    else
      v.isLocked = true
    end
  end
end

function WPamA:ListDLCID()
  local function ListCollectible(txt, typ)
    local cnt = GetTotalCollectiblesByCategoryType(typ)
    for i = 1, cnt do
      local collectibleId = GetCollectibleIdFromType(typ, i)
      local name = GetCollectibleInfo(collectibleId)
      self:Debug(txt .. " > ID: " .. collectibleId .. "; Name: " .. name, 1)
    end
  end
  ListCollectible("Chapt",COLLECTIBLE_CATEGORY_TYPE_CHAPTER)
  ListCollectible("DLC",COLLECTIBLE_CATEGORY_TYPE_DLC)
--[[
--== CollectibleCategoryType ==--
COLLECTIBLE_CATEGORY_TYPE_ABILITY_SKIN
COLLECTIBLE_CATEGORY_TYPE_ACCOUNT_SERVICE
COLLECTIBLE_CATEGORY_TYPE_ACCOUNT_UPGRADE
COLLECTIBLE_CATEGORY_TYPE_ASSISTANT
COLLECTIBLE_CATEGORY_TYPE_BODY_MARKING
COLLECTIBLE_CATEGORY_TYPE_CHAPTER
COLLECTIBLE_CATEGORY_TYPE_COMBINATION_FRAGMENT
COLLECTIBLE_CATEGORY_TYPE_COMPANION
COLLECTIBLE_CATEGORY_TYPE_COSTUME
COLLECTIBLE_CATEGORY_TYPE_DLC
COLLECTIBLE_CATEGORY_TYPE_EMOTE
COLLECTIBLE_CATEGORY_TYPE_FACIAL_ACCESSORY
COLLECTIBLE_CATEGORY_TYPE_FACIAL_HAIR_HORNS
COLLECTIBLE_CATEGORY_TYPE_FURNITURE
COLLECTIBLE_CATEGORY_TYPE_HAIR
COLLECTIBLE_CATEGORY_TYPE_HAT
COLLECTIBLE_CATEGORY_TYPE_HEAD_MARKING
COLLECTIBLE_CATEGORY_TYPE_HOUSE
COLLECTIBLE_CATEGORY_TYPE_HOUSE_BANK
COLLECTIBLE_CATEGORY_TYPE_INVALID
COLLECTIBLE_CATEGORY_TYPE_MEMENTO
COLLECTIBLE_CATEGORY_TYPE_MOUNT
COLLECTIBLE_CATEGORY_TYPE_OUTFIT_STYLE
COLLECTIBLE_CATEGORY_TYPE_PERSONALITY
COLLECTIBLE_CATEGORY_TYPE_PIERCING_JEWELRY
COLLECTIBLE_CATEGORY_TYPE_PLAYER_FX_OVERRIDE
COLLECTIBLE_CATEGORY_TYPE_POLYMORPH
COLLECTIBLE_CATEGORY_TYPE_SKIN
COLLECTIBLE_CATEGORY_TYPE_TRIBUTE_PATRON
COLLECTIBLE_CATEGORY_TYPE_VANITY_PET
--]]
end

function WPamA:ListSkillLines(st, nt)
  local ClId = GetUnitClassId("player")
  self:Debug("Class > ID: " .. ClId .. "; Name: " .. GetClassName(0,ClId), 1)
  local n = GetNumSkillLines(st)
  for i = 1, n do
    local nam = self:GetSkillLineInfo(st, i)
    local _, texture = GetSkillAbilityInfo(st, i, nt)
    self:Debug("SkillLine > ID: " .. i .. "; Name: " .. nam .. "; Texture: " .. texture, 1)
  end
end

function WPamA:ListAllChars()
  local cnt = GetNumCharacters()
  self:Debug("Chars > Count: " .. cnt, 1)
  for i = 1, cnt do
    local nam, gndr, lvl, clid, race, alli, sid, lid = GetCharacterInfo(i)
    self:Debug("Chars[" .. i .. "] > Name: " .. nam .. "; Gndr: " .. gndr .. "; Lvl: " .. lvl .. "; ClId: " .. clid .. "; Race: " .. race .. "; Alli: " .. alli .. "; Id: " .. sid .. "; LId: " .. lid, 1)
  end
end
--
-- Section 3: RGLA
--
function WPamA:RGLARegUnReg(isreg)
  if isreg then
    EVENT_MANAGER:RegisterForEvent(WPamA.Name, EVENT_LEADER_UPDATE, WPamA.OnUnitLeaderUpdate)  
    EVENT_MANAGER:RegisterForEvent(WPamA.Name, EVENT_GROUP_MEMBER_JOINED, WPamA.OnGroupMemberJoined)
    EVENT_MANAGER:RegisterForEvent(WPamA.Name, EVENT_CHAT_MESSAGE_CHANNEL, WPamA.OnChatMessage)
    EVENT_MANAGER:RegisterForEvent(WPamA.Name, EVENT_QUEST_CONDITION_COUNTER_CHANGED, WPamA.OnQCondChanged)
  else
    EVENT_MANAGER:UnregisterForEvent(WPamA.Name, EVENT_LEADER_UPDATE)
    EVENT_MANAGER:UnregisterForEvent(WPamA.Name, EVENT_GROUP_MEMBER_JOINED)
    EVENT_MANAGER:UnregisterForEvent(WPamA.Name, EVENT_CHAT_MESSAGE_CHANNEL)
    EVENT_MANAGER:UnregisterForEvent(WPamA.Name, EVENT_QUEST_CONDITION_COUNTER_CHANGED)
  end
end

function WPamA:isWBossCondComplete(JQInd, Num)
  local CondTxt = self.i18n.DailyBoss[Num].C
  if CondTxt == "" then return false end -- no condition in lng-file = no boss killed
--
  local JQCondNum = GetJournalQuestNumConditions(JQInd, QUEST_MAIN_STEP_INDEX)
  if JQCondNum < 1 then
    --self:Debug("Warning: No conditions for step " .. QUEST_MAIN_STEP_INDEX .. " in this quest")
    return true
  else
    for ci = 1, JQCondNum do
      local txt, _, _, isFail, isCompl, _, isVis = GetJournalQuestConditionInfo(JQInd, QUEST_MAIN_STEP_INDEX, ci)
      if txt == CondTxt then
        if (not (isFail or isCompl) and isVis) then
          --self:Debug("Condition ON and boss ON")
          return false
        else
          --self:Debug("Condition ON and boss OFF")
          return true
        end
      end
    end
  end
  return false
end

function WPamA:TryRGLAStart()
  -- Check quest - must present quest for Wrothgar World Bosses
  local DB = self.WorldBosses.Bosses
  local v = self.CurChar
  local b = v.DBossLoc[self.RGLA_Mode]
  local l = self.i18n
  self.RGLA_QuestJI = self:GetDWBJournalIndex(b)
  if self.RGLA_QuestJI == 0 then
    msg(l.RGLA_ErrQuestBeg .. l.RGLA_Loc[self.RGLA_Mode] .. l.RGLA_ErrQuestEnd)
    return false
  end
-- Check quest conditions
  if self.SV_Main.BossKilled and self:isWBossCondComplete(self.RGLA_QuestJI, b) then
    msg(l.RGLA_ErrBoss)
    return false
  end
  -- Check location
  if not WPamA:IsRGLALocation() then
    msg(l.RGLA_ErrLocBeg .. l.RGLA_Loc[self.RGLA_Mode] .. l.RGLA_ErrLocEnd)
    return false
  end
  -- Check group - must be Leader or not in group
  if IsUnitGrouped("player") and not IsUnitGroupLeader("player") then
    msg(l.RGLA_ErrLeader)
    return false
  end
  -- Check group - must present AutoInvite addon
  if AutoInvite == nil or AutoInviteUI == nil then
    msg(l.RGLA_ErrAI)
    return false
  end
  AutoInvite.disable()
  local aic = AutoInvite.cfg
  -- Save current AI values
  self.AICfg.watchStr = aic.watchStr
  self.AICfg.maxSize = aic.maxSize
  self.AICfg.cyrCheck = aic.cyrCheck
  -- Set values for RGLA
  aic.watchStr = self.WorldBosses.Bosses[b].S[1]
  aic.maxSize = self.Consts.RGLAMaxGrMember
  aic.cyrCheck = false
  self:RGLARegUnReg(true)
  AutoInvite.startListening()
  AutoInviteUI.refresh()
  return true
end

function WPamA:RGLAStop()
  self.RGLA_Started = false
  self.RGLA_QuestJI = 0
  self:RGLARegUnReg(false)
  self:UpdRGLAInfo()
  self:StopAIAndRestoreCgf()    
end
--
-- Section 4: Post to chat
--
function WPamA:PostToChatRGLA(var, isEN)
  local DBoss = self.CurChar.DBossLoc[self.RGLA_Mode]
  local dailyBoss = self.WorldBosses.Bosses[DBoss]
  local SV = self.SV_Main
  local rgla, txt, defZ, s = {}, "", "", ""
  if SV.RGLALangChk then
    rgla = self.i18n.RGLA
    defZ = SV.RGLALangEd
  else
    rgla = self.EN.RGLA
    defZ = rgla.CZ
  end
  if var == 1 then
    for i = 1, #dailyBoss.S do
      if s ~= "" then s = s .. ", " end
      s = s .. "\"" .. dailyBoss.S[i] .. "\""
    end
    txt = zo_strformat(rgla.F1, defZ, dailyBoss.H)
  	if SV.AutoShare then
  	  txt = txt .. zo_strformat(rgla.F2, s)
  	else
  	  txt = txt .. zo_strformat(rgla.F3, s)
  	end  	
    txt = txt .. zo_strformat(rgla.F5, self.Name)
  elseif var == 2 then
    if SV.AutoShare then
      txt = zo_strformat(rgla.F6, defZ, dailyBoss.S[1])
  	else
      txt = zo_strformat(rgla.F7, defZ, dailyBoss.S[1])
    end
  elseif var == 3 then
    txt = zo_strformat(rgla.F8, defZ, dailyBoss.H)
  elseif var == 4 then
    txt = zo_strformat(rgla.F8, rgla.CP, dailyBoss.H)
  elseif var == 5 then
    txt = zo_strformat(rgla.F9, dailyBoss.H)
  elseif var == 6 then
    txt = zo_strformat(rgla.F10, defZ, dailyBoss.H)
  elseif var == 7 then
    txt = zo_strformat(rgla.F11)
  else
    txt = zo_strformat(rgla.F12, self.Name, self.Version)
  end
  --msg(txt)
  CHAT_SYSTEM:StartTextEntry(txt) 
end

function WPamA:GetMonsterSetItemLink(DungNum)
  local dd = self.GroupDungeons.Dungeons[DungNum]
  if dd and dd.MSID then
    return zo_strformat(self.Consts.MonsterSetLinkFormatter, dd.MSID)
  end
  return ""
end

function WPamA:GetLootStr(n, Chat)
  local lnk = self:GetMonsterSetItemLink(n)
  if lnk == "" then return lnk end
  return zo_strformat(Chat.Loot, lnk)
end

function WPamA:PostPledgeToChat(isEN, shiftDay)
  self:UpdToday()
  local to = self.Today
  local Chat = {}
  local DungName = {}
  local DoW = {}
  local txt = ""
  if isEN then
    Chat = self.EN.Chat
    DungName = self.EN.DungeonsName
    DoW = self.EN.DayOfWeek
  else
    Chat = self.i18n.Chat
    DungName = self.i18n.Dungeons
    DoW = self.i18n.DayOfWeek
  end
  local function GetDungName(n)
    if isEN then
      return DungName[n]
    end
    return DungName[n].N
  end
-- Date
  local TodayDiff = to.Diff + 1
  if type(shiftDay) == "number" and shiftDay ~= 0 then
    TodayDiff = TodayDiff + shiftDay
    local Today_TS = self.Consts.BaseTimeStamp + TodayDiff * self.Consts.SecInDay
    local Today_W = GetDayOfTheWeekIndex(Today_TS)
    txt = zo_strformat(Chat.Anyday, self:TimestampToStr(Today_TS, 2, false), DoW[Today_W])
  else
    txt = zo_strformat(Chat.Today, self:TimestampToStr(to.TS, 2, false), DoW[to.W])
  end
-- Maj
  local n = self:GetPledgeCycleDungNum(1, TodayDiff)
  txt = txt .. GetDungName(n) .. self:GetLootStr(n, Chat) .. Chat.Dlmtr
-- Glirion
  n = self:GetPledgeCycleDungNum(2, TodayDiff)
  txt = txt .. GetDungName(n) .. self:GetLootStr(n, Chat) .. Chat.Dlmtr
-- Urgarlag
  n = self:GetPledgeCycleDungNum(3, TodayDiff)
  txt = txt .. GetDungName(n) .. self:GetLootStr(n, Chat)
-- Addon name, version
  txt = txt .. zo_strformat(Chat.Addon, self.Name, self.Version)
  CHAT_SYSTEM:StartTextEntry(txt)
end
--
-- Section 4: Main Window
--
function WPamA:UpdPledges(pledgeData, ctrlName, ctrlAct, lvl, calendData)
-- pledgeData = { Num, Act, isDone }
-- calendData = { Num, Name, isLocked, hasBosses, hasQuest, isToday }
----  if not pledgeData then return end
  local SV = self.SV_Main
  local co = self.Consts
  local txt = ""
  local isShowHintForPledge = SV.HintUncompletedPledges and (not calendData.isLocked) and
                              (calendData.hasQuest or calendData.hasBosses)
  local n = self:CheckDungNum(pledgeData.Num)
  local c = self.GroupDungeons.Dungeons[n].Alli
--
  if n < 3 then -- n = 1 or 2 is not a dungeon
    if lvl < co.MinCharLvlForPledge then
      txt = ""
    elseif isShowHintForPledge then
      txt = co.IconsW.RunTo
    end
  else -- n > 2 is a dungeon
    --- Quest Status is Removed / Started / Updated / Completed ---
    if pledgeData.Act == co.QuestStatus.Updated then
      txt = co.IconsW.ChkM
    elseif calendData.isLocked then
      txt = co.IconsW.Lock
    elseif SV.AllowLFGP then
      local modeLFGP = (SV.ModeLFGP == 5) and self.CurChar.CharModeLFGP or SV.ModeLFGP
      modeLFGP = self.CurChar.Veteran and modeLFGP or 1 -- always NNN for non-Veteran char
      -- 1 NNN / 2 VV- / 3 VVN / 4 VVV
      txt = (modeLFGP == 1) and co.IconsW.Norm or co.IconsW.Vet
      if calendData.NPC == 3 then -- Urgarlag
        if modeLFGP == 2 then txt = co.IconsW.Minus end
        if modeLFGP == 3 then txt = co.IconsW.Norm  end
      end
      -- Roulette N or V for outdated Pledge
      if SV.ModeLFGPRoulette and (txt == co.IconsW.Vet) and
         ( not self:IsTodayDungNumAndNPC(n, calendData.NPC) ) then
        txt = co.IconsW.Roult
      end
    end
  end
  ctrlAct:SetText(txt) -- self:SetScaledText(ctrlAct, txt)
--
  txt = self:GetDungeonName(n)
  if n < 3 then -- n = 1 or 2 is not a dungeon
    if lvl < co.MinCharLvlForPledge then
      txt = self.i18n.DungStNA
      c = self.Colors.DungStNA
    elseif pledgeData.isDone then
      txt = self.i18n.DungStDone
      c = self.Colors.DungStDone
    elseif isShowHintForPledge then
      c = self.Colors.DungStNA
      ---- txt = self:GetDungeonName(calendData.Num)
      txt = zo_strformat("<<1>><<2>><<3>>", calendData.hasQuest and co.IconsW.Quest or "",
                         calendData.hasBosses and co.IconsW.Boss or "", calendData.Name)
    elseif SV.DontShowNone then
      txt = ""
    end
  else -- n > 2 is a dungeon
    if calendData.isLocked then
      c = self.Colors.DungStNA
    end
  end
--
  self:SetScaledText(ctrlName, txt)
  ctrlName:SetColor( self:GetColor(c) )
  local lnk = self:GetMonsterSetItemLink(n)
  self.SetItemToolTip(ctrlName, lnk)
end -- UpdPledges end

function WPamA:UpdWindowHdrInfo(isRedraw)
-- While ENLIGHTENED LOST is bugged Do this workaround --
  if WPamA.EnlitState and (GetEnlightenedPool() == 0) then
    WPamA.EnlitState = false
    isRedraw = true
  end
--
  if (not isRedraw) and (self.OldShowMode == self.SV_Main.ShowMode) then
    return
  end
  self.OldShowMode = self.SV_Main.ShowMode
  self:UI_UpdMainWindowHdr()
end

function WPamA:UpdLvl(v, r)
  r.Lvl:SetColor(self:GetColor(self.Colors.LabelLvl))
  if v.Veteran then
    r.Lvl:SetText(self.Consts.IconsW.Chm)
  else
    r.Lvl:SetText(v.Lvl)
  end
end

function WPamA:UpdWindowMode1()
  local function Calculate_W_T_Z()
          local to = self.Today
          local SecInDay = self.Consts.SecInDay
          -- local TimeZone = self.Consts.TimeZone
          local ww = (to.W + 6) % 7
          local tt = to.TS - SecInDay
          local zz = to.Diff - 1
          return ww, tt, zz
        end
  local q = 0
  local w, t, z = Calculate_W_T_Z()
  local co = self.Consts
  local dung = self.GroupDungeons.Dungeons
  local dq = self.CurChar.GroupDungeons
  local qst = co.IconsW.Quest
  local boss = co.IconsW.Boss
  local RCnt = co.CalendRowCnt[ self.SV_Main.LargeCalend ] or 8
  for i = RCnt + 1, co.RowCnt do
    self.ctrlRows[i].Row:SetHidden(true)
  end
  for i = 1, RCnt do
    local r = self.ctrlRows[i]
    r.Row:SetHidden(true)
    if i == 2 then
      r.BG:SetHidden(false)
    else
      r.BG:SetHidden(true)
    end
-- Lvl
    if self.i18n.DayOfWeek then
      r.Lvl:SetText(self.i18n.DayOfWeek[w])
    elseif self.EN.DayOfWeek then
      r.Lvl:SetText(self.EN.DayOfWeek[w])
    else
      r.Lvl:SetText("")
    end
-- Day
    r.Char:SetFont("$(CHAT_FONT)|18|soft-shadow-thin")
    r.Char:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
    r.Char:SetText( self:TimestampToStr(t) )
-- Saturday or Sunday
    if w == 0 or w == 6 then
      r.Lvl:SetColor(self:GetColor(self.Colors.Weekend))
      r.Char:SetColor(self:GetColor(self.Colors.Weekend))
    else
      r.Lvl:SetColor(self:GetColor(self.Colors.Workday))
      r.Char:SetColor(self:GetColor(self.Colors.Workday))
    end
-- Next Day
    t = t + co.SecInDay
    w = (w + 1) % 7
-- Maj NPC
    local txt = ""
    --r.B[1]:SetText("")
    q = self:GetPledgeCycleDungNum(1, i + z)
    r.B[2]:SetColor( self:GetColor(dung[q].Alli) )
    txt = self:GetDungeonName(q) or "???" -- protection from possible lua-error by incorrect i18n file
    if dq[q].hasBosses then txt = boss .. txt end
    if dq[q].hasQuest then txt = qst .. txt end
    self:SetScaledText(r.B[2], txt)
    self.SetItemToolTip( r.B[2], self:GetMonsterSetItemLink(q) )
-- Glirion NPC
    --r.B[3]:SetText("")
    q = self:GetPledgeCycleDungNum(2, i + z)
    r.B[4]:SetColor( self:GetColor(dung[q].Alli) )
    txt = self:GetDungeonName(q) or "???" -- protection from possible lua-error by incorrect i18n file
    if dq[q].hasBosses then txt = boss .. txt end
    if dq[q].hasQuest then txt = qst .. txt end
    self:SetScaledText(r.B[4], txt)
    self.SetItemToolTip( r.B[4], self:GetMonsterSetItemLink(q) )
-- Urgarlag NPC
    --r.B[5]:SetText("")
    q = self:GetPledgeCycleDungNum(3, i + z)
    txt = self:GetDungeonName(q) or "???" -- protection from possible lua-error by incorrect i18n file
    if dq[q].hasBosses then txt = boss .. txt end
    if dq[q].hasQuest then txt = qst .. txt end
    if dung[q].isLocked then
      r.B[6]:SetColor(self:GetColor(self.Colors.DungStNA))
      txt = co.IconsW.Lock .. txt
    else
      r.B[6]:SetColor( self:GetColor(dung[q].Alli) )
    end
    self:SetScaledText(r.B[6], txt)
    self.SetItemToolTip( r.B[6], self:GetMonsterSetItemLink(q) )
--
    r.Row:SetHidden(false)
  end
  self:UI_UpdMainWindowSize(1, RCnt)
end

function WPamA:UpdWWBColor(DBoss, ctrl, isCurrent)
  local clr = self.Colors.WWBStNone
  if isCurrent then
    clr = self.Colors.WWBStCur
  elseif DBoss ~= nil and self:CheckToday(DBoss) then
    clr = self.Colors.WWBStDone
  end
  ctrl:SetColor(self:GetColor(clr))
end

function WPamA:UpdWWBTxtColor(DBoss, ctrl, isCurrent)
  local clr, txt = self.Colors.WWBStNone, ""
  if not self.SV_Main.DontShowNone then
    txt = self.i18n.WWBStNone
  end
  if isCurrent then
    clr, txt = self.Colors.WWBStCur, self.i18n.WWBStCur
  elseif DBoss ~= nil and self:CheckToday(DBoss) then
    clr, txt = self.Colors.WWBStDone, self.i18n.WWBStDone
  end
  ctrl:SetColor(self:GetColor(clr))
  WPamA:SetScaledText(ctrl, txt)
end

function WPamA:UpdRowMode0(v, r, TS)
  local dung = self.GroupDungeons.Dungeons
  local QStat = self.Consts.QuestStatus
  local ccgd = v.GroupDungeons
  local ii = 1
  for i = 1, #self.GroupDungeons.OrdPledges do -- undaunted NPC : 1 Maj / 2 Glirion / 3 Urgarlag
    local pledge = v.Pledges[i] or {}
    --- get today pledge from calendar ---
    local calDungNum = self:GetTodayDungNumByNPC(i)
    local calDungName = self:GetDungeonName(calDungNum)
    local calDungLocked = dung[calDungNum].isLocked
    local dungBosses, dungQuest = false, false
    if ccgd[calDungNum] then
      dungBosses = ccgd[calDungNum].hasBosses or false
      dungQuest  = ccgd[calDungNum].hasQuest  or false
    end
    local dungToday = self:IsTodayDungNumAndNPC(pledge.Num or 1, i)
    --- show pledge info ---
    local pledgeRowData = { Num = pledge.Num or 1, Act = pledge.Act or 0, isDone = false }
    if pledge.Act == QStat.Completed then
      pledgeRowData.Num = 1
      if self:CheckToday(pledge.EndTS) then pledgeRowData.isDone = true end
      -- d(v.Name .. " [" .. i .. "] ETS [" .. WPamA:TimestampToStr(pledge.EndTS, 1, true) .. "]")
    end
    --- Maj      : Pledges[1] B[2] B[1]
    --- Glirion  : Pledges[2] B[4] B[3]
    --- Urgarlag : Pledges[3] B[6] B[5]
    self:UpdPledges(pledgeRowData, r.B[ii + 1], r.B[ii], v.Lvl,
         { Num = calDungNum, Name = calDungName, isLocked = calDungLocked, NPC = i,
           hasBosses = dungBosses, hasQuest = dungQuest, isToday = dungToday })
    ii = ii + 2
  end
-- LFG
  if self.SV_Main.AllowLFGP then
    local SVM = self.SV_Main.ModeLFGP
    local icon = self.Consts.IconsW.LfgpKeys
    local iconInd = 1 -- 3 keys for non-Veteran char
    if v.Veteran then
      if SVM < 5 then iconInd = SVM -- always XX keys
      elseif SVM == 5 then iconInd = v.CharModeLFGP -- char's keys mode
      end
    end
    r.B[7]:SetColor(self:GetColor(self.Colors.LabelLvl))
    self:SetScaledText(r.B[7], icon[iconInd])
  else
    self:SetScaledText(r.B[7], self.Consts.IconsW.Minus)
  end
end -- UpdRowMode0 end

function WPamA:UpdRowModeWB(v, r, l)
-- Bosses
  local bl = self.WorldBosses.Locations[l]
  local bs = v.DBoss
  local n = v.DBossLoc[l]
  for j = bl.b, bl.e do
    self:UpdWWBTxtColor(bs[j], r.B[j-bl.b+bl.s], j == n)
  end
-- Wrothgar WB Achievment
  if l == 0 then
    if v.numWWB == nil then
      r.B[7]:SetText("") -- no data at this moment
    elseif v.numWWB == 0 then
      self:SetScaledText(r.B[7], self.Consts.IconsW.A)
    else
      self:SetScaledText(r.B[7], tostring(v.numWWB)) -- progress
      r.B[7]:SetColor(self:GetColor(self.Colors.WWBAchiev))
    end
  end
end

function WPamA:UpdInvtItemCtrl(ctrl, num, isCurr, maxNum)
  if num == "" then
    ctrl:SetText("")
  elseif num == nil or num == 0 then
    ctrl:SetColor(self:GetColor(self.Colors.MenuDisabled))
    self:SetScaledText(ctrl, "0")
  else
    if maxNum and (num >= maxNum) then
      ctrl:SetColor(self:GetColor(self.Colors.DungStDone))
    else
      ctrl:SetColor(self:GetColor(self.Colors.LabelLvl))
    end
    if isCurr then
      self:SetScaledText(ctrl, self:CurrencyToStr(num))
    else
      self:SetScaledText(ctrl, num)
    end
  end
end

function WPamA:UpdRowModeItmCur(v, r, ttl, m)
-- Items
  local map = self.ModeSettings[m].Map
  local II = self.Inventory.InvtItem
  local k = 0
  for j = 1, self.ColBCount do
    if map[j] then
      k = (v.Invt[map[j]] or 0)
      ttl[j] = ttl[j] + k
      self:UpdInvtItemCtrl(r.B[j], k, II[map[j]].c ~= nil)
    else
      r.B[j]:SetText("")
    end
  end
end

function WPamA:UpdRowMode25(v, r, ttl)
  local curUpgr = v.InvtCnt.CurUpgrade or 0
  local maxUpgr = self.Inventory.InvtMaxUpgrade
  local maxRS, curRS = self.MaxRidingStat, v.RidingSkills[3]
  local curPets, maxPets = self.Inventory.InvtPetUpgrade, #self.Inventory.InvtPetCIDs
  local ittl = v.InvtCnt.Total or 0
  local used = v.InvtCnt.InUse or 0
-- Items
  local free = 0
  if ittl > used then
    free = ittl - used
  end
  ttl[1] = ttl[1] + ittl
  ttl[2] = ttl[2] + used
  ttl[3] = ttl[3] + free
  local maxInvt = 60 + 10 * maxUpgr + maxRS + 5 * maxPets
  self:UpdInvtItemCtrl(r.B[1], ittl, false, maxInvt) -- Inventory total slots
  self:UpdInvtItemCtrl(r.B[2], used, false) -- Inventory used slots
  self:UpdInvtItemCtrl(r.B[3], free, false) -- Inventory free slots
  self:UpdInvtItemCtrl(r.B[4], curUpgr, false, maxUpgr) -- Inventory upgrades
  self:UpdInvtItemCtrl(r.B[5], curRS, false, maxRS) -- Inventory extension by Mount
  self:UpdInvtItemCtrl(r.B[6], curPets, false, maxPets) -- Inventory extension by Vanity Pets
--
  for j = 7, self.ColBCount do
    r.B[j]:SetText("")
  end
end

function WPamA:LH_CurrencyToStr(nL, nH)
  if nL == nH then
    return self:CurrencyToStr(nL)
  end
  return self:CurrencyToStr(nL) .. "-" .. self:CurrencyToStr(nH)
end

function WPamA:UpdRowMode21(v, r, ttl)
-- Items
  local map = self.ModeSettings[21].Map
  local II = self.Inventory.InvtItem
  local k, nl, nh = 0, 0, 0
  for j = 1, self.ColBCount do
    if map[j] == 0 then
      if type(ttl[j]) ~= "table" then ttl[j] = {nL=0,nH=0} end
      ttl[j].nL = ttl[j].nL + nl
      ttl[j].nH = ttl[j].nH + nh
      self:UpdInvtItemCtrl(r.B[j], self:LH_CurrencyToStr(nl,  nh), false)
    elseif map[j] then
      k = (v.Invt[map[j]] or 0)
      ttl[j] = ttl[j] + k
      local XX = II[map[j]]
      nl = nl + k * (XX.nL or 0)
      nh = nh + k * (XX.nH or 0)
      self:UpdInvtItemCtrl(r.B[j], k, false)
    else
      r.B[j]:SetText("")
    end
  end
end

function WPamA:ColorizeModeCraft(t, n, m)
  if not t then return "" end
  if n and m and (n >= m) then
    return zo_strformat("|c<<1>><<2>>|r", self.Colors.Mdl[13], t)
  end
  return t
end

function WPamA:UpdRowModeSkill(v, r, m)
  local skpFormat = "<<1>> / <<2>>"
  local GreyStNA = zo_strformat("|c999999<<1>>|r", self.i18n.DungStNA)
  local w = self.SkillLines.SkillLineModes[m] or {}
  local l = self.SkillLines.SkillLines
  local icn  = self.Consts.IconsW.NoCert
  local mail = self.Consts.IconsW.Mail
  for j = 1, self.ColBCount do
    local k = w[j]
    if (m == 4) and (j == 7) then
      r.B[j]:SetColor(self:GetColor(self.Colors.LabelLvl))
      local availSkP = v.AvlSkP or GreyStNA
      local totalSkP = v.AllocSkP and (v.AvlSkP + v.AllocSkP) or GreyStNA
      r.B[j]:SetText( zo_strformat( skpFormat, availSkP, totalSkP ) )
    elseif k == nil then 
      r.B[j]:SetText("")
    else
      local z = v.Skills[k] or {}
      local txt = self:ColorizeModeCraft(z.rank or "0", z.rank, l[k].max)
      if m == 5 then
        if z.A3 and (z.A3 > 0) then -- has a hireling skill
          if not self:CheckToday(v.LastLoginTS) then txt = mail .. txt end
        end
        if not z.isCert then txt = icn .. txt end -- icon for NOT certified crafting profession
      end
      if z.A1 ~= nil then txt = txt .. self.Colors.dlm_slash .. self:ColorizeModeCraft(z.A1, z.A1, l[k].mn1) end
      if z.A2 ~= nil then txt = txt .. self.Colors.dlm_slash .. self:ColorizeModeCraft(z.A2, z.A2, l[k].mn2) end
      if z.A3 ~= nil then txt = txt .. self.Colors.dlm_slash .. self:ColorizeModeCraft(z.A3, z.A3, l[k].mn3) end
      r.B[j]:SetColor(self:GetColor(self.Colors.LabelLvl))
      self:SetScaledText(r.B[j], txt)
    end
  end
end

function WPamA:UpdRowMode6(v, r, m, TS)
-- Items
  local c = self.Colors
  local l = self.i18n
  local MS = self.ModeSettings[m]
  local f = self.SV_Main.TrialAvlFrmt
  local NextTS = self:GetNextWeeklyResetTS()
  for j = 1, self.ColBCount do
    local clr, txt, i = c.TrialNone, "", MS.Map[j]
    if i then
      local Trial = v.Trials[i]
      if not self:CheckOutOfWeek(Trial.TS) then
        if f == 1 then
          txt = self:DifTSToStr(NextTS - TS, true, 0)
        elseif f == 2 then
          txt = self:TimestampToStr(NextTS, 6, true)
        else
          txt = self:TimestampToStr(NextTS, 7, true)
        end
        clr = c.TrialDone
      end
      if Trial.Act == 1 then
        if txt == "" then
          txt = l.TrialStActv
          clr = c.TrialActv
        else
          txt = txt .. " " .. l.TrialStActv
          clr = c.TrialDnAc
        end
      end
      if txt == "" and not self.SV_Main.DontShowNone then
        txt = l.TrialStNone
      end
      if self.TrialDungeons.Trials[i].isLocked then
        txt = self.Consts.IconsW.Lock .. ""
      end
    end
    r.B[j]:SetColor(self:GetColor(clr))
    self:SetScaledText(r.B[j], txt)
  end
end

function WPamA:UpdMode7TxtClr(r, Num, SV, TS, Lvl, LFG_TS)
  local c = self.Colors
  local l = self.i18n
  local f = SV.LFGRndAvlFrmt
  local clr, txt = c.LFG_Green, ""
--
  if LFG_TS and (LFG_TS > 0) then
    local NextTS = self:GetNextUTC00TS()
    if (LFG_TS >= self.Today.TS) and (LFG_TS < NextTS) then
      if f == 1 then
        txt = self:DifTSToStr(NextTS - TS, true, 0)
      elseif f == 2 then
        txt = self:TimestampToStr(NextTS, 6, true)
      else
        txt = self:TimestampToStr(NextTS, 7, true)
      end
    end
  end
--
  if txt == "" and not SV.LFGRndDontShowSt then
    if Lvl < 10 then
      clr = c.LFG_NA
      txt = l.LFGRewardNA
    else
      clr = c.LFG_Blue
      txt = l.LFGRewardReady
    end
  end
  r.B[Num]:SetColor(self:GetColor(clr))
  self:SetScaledText(r.B[Num], txt)
end

function WPamA:UpdRowMode7(v, r, TS)
  local SV = self.SV_Main
  self:UpdMode7TxtClr(r, 1, SV, TS, v.Lvl, v.LFGActivities[LFG_ACTIVITY_DUNGEON])
  self:UpdMode7TxtClr(r, 2, SV, TS, v.Lvl, v.LFGActivities[LFG_ACTIVITY_BATTLE_GROUND_NON_CHAMPION])
  self:UpdMode7TxtClr(r, 3, SV, TS, v.Lvl, v.LFGActivities[LFG_ACTIVITY_TRIBUTE_CASUAL])
end

function WPamA:UpdRowMode10(v, r)
  local ft = self.Festivals.Titles
  local fa = v.Festivals
  local c = self.Colors
  if fa ~= nil then -- the Festivals data exist for this char
    for i = 1, #fa do
      r.B[i]:SetColor(self:GetColor(self.Colors.LabelLvl))
      self.SetAchvToolTip(r.B[i], nil) -- clear ToolTip
      local compl = fa[ i ].isComplete
      if compl == nil then -- compl not exist
        r.B[i]:SetColor(self:GetColor( c.DungStNA ))
        WPamA:SetScaledText(r.B[i], self.i18n.DungStNA)
      elseif compl then -- compl true
        r.B[i]:SetColor(self:GetColor( c.FestDone ))
        WPamA:SetScaledText(r.B[i], ft[i])
      else -- compl false
        r.B[i]:SetColor(self:GetColor( c.LabelLvl ))
        local tt = fa[ i ].Completed .. " / " .. fa[ i ].All
        WPamA:SetScaledText(r.B[i], tt)
        if v.Name == self.CharName then -- current char
          local fai = self.Festivals.AchievementsIDs[i]
          self.SetAchvToolTip(r.B[i], fai, GetAchievementProgress(fai), GetAchievementTimestamp(fai) )
        end
      end
    end -- for i
  else -- the Festivals data not exist for this char
    for i = 1, #WPamA.Festivals.AchievementsIDs do
      r.B[i]:SetColor(self:GetColor(self.Colors.LabelLvl))
      WPamA:SetScaledText(r.B[i], self.i18n.DungStNA)
      self.SetAchvToolTip(r.B[i], nil) -- clear ToolTip
    end
  end
end -- UpdRowMode10 end

function WPamA:UpdRowModeFreeCHMP(v, r)
  local CD = self.ChampionDisciplines
  local AvlCD = v.AvlChmpDisciplines
  for i = 1, #CD do
    local txt = ""
    if AvlCD and AvlCD[i] then
      txt = zo_iconTextFormat(CD[i].Icon, "100%", "100%", AvlCD[i]) .. " / " .. CD[i].Total
      if AvlCD[i] == CD[i].Total then
        r.B[i]:SetColor(self:GetColor(self.Colors.FestDone))
      else
        r.B[i]:SetColor(self:GetColor(self.Colors.LabelLvl)) -- white color by default
      end
    else
      txt = self.i18n.DungStNA
      r.B[i]:SetColor(self:GetColor(self.Colors.DungStNA))
    end
    self:SetScaledText(r.B[i], txt)
  end
end -- UpdRowModeFreeCHMP end

function WPamA:UpdRowMode13(v, r, TS)
  local MRS, RS = self.MaxRidingStat, v.RidingSkills
  local f = self.SV_Main.LFGRndAvlFrmt
  if RS[4] ~= nil then -- RS data is exist for this char
    local isNoMoreTraining = ( (RS[1] >= MRS) and (RS[2] >= MRS) and (RS[3] >= MRS) )
    for i = 1, 4 do
      r.B[i]:SetColor(self:GetColor(self.Colors.LabelLvl)) -- white color by default
      if i == 4 then -- TS string
        local txt = ""
        if isNoMoreTraining then
          txt = GetString(SI_QUEST_TYPE_COMPLETE)
        elseif TS >= RS[i] then
          r.B[i]:SetColor(self:GetColor(self.Colors.DungStDone)) -- green
          txt = GetString(SI_GAMEPAD_STABLE_TRAINABLE_READY)
        elseif f == 1 then
          txt = self:DifTSToStr(RS[i] - TS, true, 0)
        elseif f == 2 then
          txt = self:TimestampToStr(RS[i], 6, true)
        else
          txt = self:TimestampToStr(RS[i], 7, true)
        end
        self:SetScaledText(r.B[i], txt)
      else -- Skills strings
        if RS[i] >= MRS then
          r.B[i]:SetColor(self:GetColor(self.Colors.DungStDone)) -- green
        end
        self:SetScaledText(r.B[i], RS[i])
      end
    end
  else -- RS data is not exist
    for i = 1, 4 do
      r.B[i]:SetColor(self:GetColor(self.Colors.DungStNA)) -- gray
      self:SetScaledText(r.B[i], self.i18n.DungStNA)
    end
  end
end -- UpdRowMode13 end

function WPamA:UpdRowModeDailyWrit(v, r, TS)
  local f = self.SV_Main.LFGRndAvlFrmt
  local txt = ""
  local icnLock = self.Consts.IconsW.Lock
  local icnQuest = self.Consts.IconsW.Quest
  local slm = self.SkillLines.SkillLineModes[5] or {}
  for i = 1, 7 do
    local hasCert, k = false, slm[i]
    if k and v.Skills[k] then hasCert = v.Skills[k].isCert end
    -------------
    local writ = v.DailyWrits[i]
    r.B[i]:SetColor(self:GetColor(self.Colors.LabelLvl)) -- white color by default
    if not hasCert then -- icon for NOT certified crafting profession
      txt = icnLock
    elseif writ.Act == 2 then -- data is not exist
      r.B[i]:SetColor(self:GetColor(self.Colors.DungStNA)) -- gray
      txt = self.i18n.DungStNA
    elseif writ.Act == 1 then -- quest is active
      txt = self.i18n.TrialStActv
    else -- no quest or quest ready
      if (writ.EndTS == 0) or (TS >= writ.EndTS) then
        if self.SV_Main.LFGRndDontShowSt then txt = " "
        else txt = icnQuest
        end
      else
        if f == 1 then
          txt = self:DifTSToStr(writ.EndTS - TS, true, 0)
        elseif f == 2 then
          txt = self:TimestampToStr(writ.EndTS, 6, true)
        else
          txt = self:TimestampToStr(writ.EndTS, 7, true)
        end
      end
    end
    self:SetScaledText(r.B[i], txt)
  end
end -- UpdRowModeDailyWrit end

function WPamA:InitTTL(ttl, m)
  if m == 25 then
    for i = 1, 3 do ttl[i] = 0 end
  elseif type(self.Inventory.InvtItemModes[m]) == "number" then
    local n = #self.Inventory.InvtItem
    for i = 1, n do ttl[i] = 0 end
  end
end

function WPamA:UpdRowTTL(ttl, m)
  local function BankVal(bc,j)
    if j == 1 then
      return bc.Total
    elseif j == 2 then
      return bc.InUse
    elseif j == 3 and bc.Total > bc.InUse then
      return bc.Total - bc.InUse
    end
    return 0
  end
  if m == 25 or type(self.Inventory.InvtItemModes[m]) == "number" then
    local map = self.ModeSettings[m].Map
    local II = self.Inventory.InvtItem
    local b = self.SV_Main.Bank
    local bc = self.SV_Main.BankCnt
    for j = 1, self.ColBCount do
      local t1 = ""
      local t2 = ""
      local ic = false
      if m == 25 then
        if j <= 3 then
          t1 = nvl( BankVal(bc,j), 0 )
          t2 = nvl( ttl[j], 0 ) + t1
        end
      elseif m == 21 and map[j] == 0 and type(ttl[j]) == "table" then
        local x = ttl[j]
        t1 = GetCurrencyAmount(CURT_TRANSMUTE_CRYSTALS, CURRENCY_LOCATION_ACCOUNT) -- transmute seeds
        x.nL = x.nL + t1
        x.nH = x.nH + t1
        t2 = self:LH_CurrencyToStr( x.nL or 0, x.nH or 0 )
      elseif map[j] and II[ map[j] ] and type(ttl[j]) ~= "table" then
        t1 = nvl( b[map[j]], 0 )
        t2 = nvl( ttl[j], 0 ) + t1
        ic = II[ map[j] ].c ~= nil
      end
      self:UpdInvtItemCtrl(self.ctrlWMsg[1].B[j], t1, ic)
      self:UpdInvtItemCtrl(self.ctrlWMsg[2].B[j], t2, ic)
    end
  end
end

local function FormattedCharName(name, mode)
  if name:len() < 16 then return name end -- it's not a long name
  local SV, newname = WPamA.SV_Main, ""
  if mode == 2 then -- cut the middle
    newname = name:sub(1,7) .. "..." .. name:sub(-7)
  elseif mode == 3 then -- text mask
--    if (SV.CharNamesMaskFrom == "") or (SV.CharNamesMaskTo == "") then
    if SV.CharNamesMaskFrom == "" then return name -- nothing to do with incorrect mask
    else newname = name:gsub(SV.CharNamesMaskFrom, SV.CharNamesMaskTo)
    end
  end
  return newname
end

function WPamA:UpdRowMode28(v, r, TS)
  local c = self.Colors
  local l = self.i18n
  local f = self.SV_Main.LFGRndAvlFrmt
  local clr, txt = c.ShSupl_Timer, ""
  local TM = v.ShSupplier.Timer
  local a  = v.ShSupplier.Avl
--
  if TM and (TM > TS) then
    if f == 1 then
      txt = self:DifTSToStr(TM - TS, true, 0)
    elseif f == 2 then
      txt = self:TimestampToStr(TM, 6, true)
    else
      txt = self:TimestampToStr(TM, 7, true)
    end
  end
--
  if txt == "" then
    if a == 2 then
      if not self.SV_Main.LFGRndDontShowSt then
        clr = c.ShSupl_Ready
        txt = l.ShSuplReady
      end
    elseif a == 1 then
      clr = c.ShSupl_NA
      txt = l.ShSuplNA
    else
      clr = c.ShSupl_Unkn
      txt = l.ShSuplUnkn
    end
  end
  r.B[1]:SetColor(self:GetColor(clr))
  WPamA:SetScaledText(r.B[1], txt)
end

function WPamA:UpdRowModeBook(v, r)
-- Items
  local n = GetNumLoreCategories()
  local c = self.Colors
  local qst = self.Textures.GetTexture("quest", 20)
  for j = 1, self.ColBCount do
    if j <= 3 and j <= n then
      local b = v.Books[j]
      if j == 3 and b.Ttl == 0 then
        self:SetScaledText(r.B[j], qst)
      else
        local clr = c.Book_Some
        local prc = ""
        if b.Cnt == 0 or b.Ttl == 0 then
          clr = c.Book_None
          prc = "0"
        elseif b.Cnt == b.Ttl then
          clr = c.Book_All
          prc = "100"
        else
          prc = tostring(math.floor(1000 * b.Cnt / b.Ttl)/10)
        end
        r.B[j]:SetColor(self:GetColor(clr))
        self:SetScaledText(r.B[j], zo_strformat("<<1>> / <<2>> (<<3>>%)", b.Cnt, b.Ttl, prc))
      end
    else
      self:SetScaledText(r.B[j], "")
    end
  end
end

function WPamA:UpdRowModeFavors(v, r)
  local clrLabel, clrGray, clrGreen = self.Colors.LabelLvl, self.Colors.DungStNA, self.Colors.DungStDone
  local progrFormat = "<<1>> / <<2>>"
  local txt = ""
  for i = 1, #self.Favors.QuestIDs do
    local Favors = v.Favors[i]
    if (not Favors.Unlock) or (not Favors.Total) then
      r.B[i]:SetColor(self:GetColor(clrGray)) -- gray
      txt = self.i18n.DungStNA
    else
      local color = (Favors.Unlock >= Favors.Total) and clrGreen or clrLabel
      color = (Favors.Unlock == 0) and clrGray or color
      r.B[i]:SetColor(self:GetColor(color)) -- white color by default or green
      txt = zo_strformat(progrFormat, Favors.Unlock, Favors.Total)
    end
    self:SetScaledText(r.B[i], txt)
  end
end

function WPamA:UpdRowModeCharInfo(v, r, TS)
  local icon, SecInDay = self.Consts.IconsW, self.Consts.SecInDay
  local iconFormat = "|t24:24:<<1>>|t"
  local skpFormat = "<<1>> / <<2>>"
  local GreyStNA = zo_strformat("|c999999<<1>>|r", self.i18n.DungStNA)
  local clrLabel, clrGray, clrGreen = self.Colors.LabelLvl, self.Colors.DungStNA, self.Colors.DungStDone
  local agoFormat = GetString(SI_TIME_DURATION_AGO):gsub("%.", "")
  agoFormat = agoFormat:gsub("<<(.+)>>", "<<1>>")
  local txt = ""
-- Races info
  if v.Race then
    r.B[1]:SetColor(self:GetColor(clrLabel)) -- white color by default
    txt = zo_strformat( iconFormat, icon.Races[v.Race] or " " )
    self.SetTxtToolTip( r.B[1], zo_strformat( SI_COMPANION_NAME_FORMATTER, GetRaceName(0, v.Race) ) )
  else
    r.B[1]:SetColor(self:GetColor(clrGray)) -- gray
    txt = self.i18n.DungStNA
  end
  self:SetScaledText(r.B[1], txt)
-- Classes info
  if v.Class then
    r.B[2]:SetColor(self:GetColor(clrLabel)) -- white color by default
    txt = zo_strformat( iconFormat, icon.Classes[v.Class] or " " )
    self.SetTxtToolTip( r.B[2], zo_strformat( SI_COMPANION_NAME_FORMATTER, GetClassName(0, v.Class) ) )
  else
    r.B[2]:SetColor(self:GetColor(clrGray)) -- gray
    txt = self.i18n.DungStNA
  end
  self:SetScaledText(r.B[2], txt)
-- SP available / total
  if v.AvlSkP then
    r.B[3]:SetColor(self:GetColor(clrLabel)) -- white color by default
    local totalSkP = v.AllocSkP and (v.AvlSkP + v.AllocSkP) or GreyStNA
    txt = zo_strformat( skpFormat, v.AvlSkP, totalSkP )
  else
    r.B[3]:SetColor(self:GetColor(clrGray)) -- gray
    txt = self.i18n.DungStNA
  end
  self:SetScaledText(r.B[3], txt)
-- Last login
  if v.LastLoginTS and (v.LastLoginTS > 0) then
    if self:CheckToday(v.LastLoginTS) then
      r.B[4]:SetColor(self:GetColor(clrGreen)) -- green
      txt = self.i18n.LoginToday
    elseif self:CheckToday(v.LastLoginTS + SecInDay) then
      r.B[4]:SetColor(self:GetColor(clrLabel)) -- white
      txt = self.i18n.Login1DayAgo
    else
      r.B[4]:SetColor(self:GetColor(clrLabel)) -- white
      txt = self:DifTSToStr(TS - v.LastLoginTS, true, 0)
      txt = zo_strformat( agoFormat, txt )
    end
  else
    r.B[4]:SetColor(self:GetColor(clrGray)) -- gray
    txt = self.i18n.DungStNA
  end
  self:SetScaledText(r.B[4], txt)
-- Played time
  if v.PlayedTime and (v.PlayedTime > 0) then
    r.B[5]:SetColor(self:GetColor(clrLabel)) -- white color by default
    txt = self:DifTSToStr(v.PlayedTime, true, 0)
  else
    r.B[5]:SetColor(self:GetColor(clrGray)) -- gray
    txt = self.i18n.DungStNA
  end
  self:SetScaledText(r.B[5], txt)
end -- UpdRowModeCharInfo end

function WPamA:UpdWindowModeChar()
  self.Mode67PeriodUpd = 59
  local TS = GetTimeStamp()
  local SV = self.SV_Main
  local CL, m = SV.CharsList, SV.ShowMode
  local z, ttl = 0, {}
  self:InitTTL(ttl, m)
  for i = 1, #CL do
    if CL[i] ~= nil then
      local v = CL[i]
      local Name = v.Name
      local f = Name == self.CharName
      if self.ScreenShotMode and self.ScreenShotName[i] ~= nil then
        Name = self.ScreenShotName[i]
      end
      if f or v.isVisible then
        if z + 1 > self.Consts.RowCnt then
          break
        end
        z = z + 1
        local r = self.ctrlRows[z]
        r.Row:SetHidden(false)
-- Current char
        r.BG:SetHidden(not f)
-- Lvl
        self:UpdLvl(v, r)
-- Name
        r.Char:SetFont("$(CHAT_FONT)|18|soft-shadow-thin")
        r.Char:SetHorizontalAlignment(SV.CharNamesAlignment)
        if SV.CharNamesInColors then
          r.Char:SetColor(self:GetColor(v.Alli))
        else
          r.Char:SetColor(self:GetColor(4))
        end
        if SV.CharNamesCorrMode == 0 then -- do nothing
          r.Char:SetText(Name)
        elseif SV.CharNamesCorrMode == 1 then -- by font size
          self:SetScaledText(r.Char, Name)
        elseif SV.CharNamesCorrMode == 2 then -- by cut the middle
          r.Char:SetText( FormattedCharName(Name, SV.CharNamesCorrMode) )
        elseif SV.CharNamesCorrMode == 3 then -- by text mask
          r.Char:SetText( FormattedCharName(Name, SV.CharNamesCorrMode) )
        end
-- Upd Row
        if m == 0 then
          self:UpdRowMode0(v, r, TS)
        elseif m == 2 then
          self:UpdRowModeWB(v, r, 0)
        elseif m == 21 then -- must be before UpdRowModeItmCur
          self:UpdRowMode21(v, r, ttl)
        elseif m == 50 then -- must be before UpdRowModeItmCur
          self:UpdRowModeAvAXPBuffs(v, r, ttl, TS)
        elseif type(self.Inventory.InvtItemModes[m]) == "number" then
          self:UpdRowModeItmCur(v, r, ttl, m)
        elseif m == 4 or m == 5 or m == 12 or m == 24 then
          self:UpdRowModeSkill(v, r, m)
        elseif m == 6 or m == 15 or m == 44 then
          self:UpdRowMode6(v, r, m, TS)
        elseif m == 7 then
          self:UpdRowMode7(v, r, TS)
        elseif m == 8 then
          self:UpdRowModeWB(v, r, 1)
        elseif m == 9 then
          self:UpdRowModeWB(v, r, 2)
        elseif m == 10 then
          self:UpdRowMode10(v, r)
        elseif m == 11 then
          self:UpdRowModeWB(v, r, 3)
        elseif m == 13 then
          self:UpdRowMode13(v, r, TS)
        elseif m == 14 then
          self:UpdRowModeWB(v, r, 4)
        elseif m == 16 then
          self:UpdRowModeAVA(v, r, TS)
        elseif m == 17 then
          self:UpdRowModeWB(v, r, 5)
          self:UpdRowModeWB(v, r, 6)
        elseif m == 18 then
          self:UpdRowModeBGrnd(v, r, TS)
        elseif m == 25 then
          self:UpdRowMode25(v, r, ttl)
        elseif m == 26 then
          self:UpdRowModeWB(v, r, 7)
        elseif m == 28 then
          self:UpdRowMode28(v, r, TS)
        elseif m == 29 then
          self:UpdWindowModeRapports(v, r, m)
        elseif m == 30 then
          self:UpdRowModeFreeCHMP(v, r)
        elseif m == 31 then
          self:UpdRowModeDailyWrit(v, r, TS)
        elseif m == 33 then
          self:UpdRowModeWB(v, r, 8)
        elseif m == 34 then
          self:UpdRowModeBook(v, r)
        elseif m == 41 then
          self:UpdRowModeWB(v, r, 9)
          self:UpdRowModeWB(v, r, 10)
        elseif m == 42 then
          self:UpdRowModeCharInfo(v, r, TS)
        elseif m == 43 then
          self:UpdRowModeEDArchive(v, r, TS)
        elseif m == 45 then
          self:UpdRowModeWB(v, r, 11)
        elseif m == 46 then
          self:UpdWindowModeRapports(v, r, m)
        elseif m == 47 then
          self:UpdRowModeWB(v, r, 12)
        elseif m == 48 then
          self:UpdRowModeWeaponCharge(v, r)
        elseif m == 49 then
          self:UpdRowModeBlueprints(v, r)
        elseif m == 51 then
          self:UpdRowModeFavors(v, r)
        end
      end
    end
  end
  for i = z + 1, self.Consts.RowCnt do
    self.ctrlRows[i].Row:SetHidden(true)
  end
  self:UpdRowTTL(ttl, m)
  self:UI_UpdMainWindowSize(m, z)
end -- UpdWindowModeChar end

function WPamA:UpdWindowInfo(isRedraw)
  self:UpdToday()
  local m = self.SV_Main.ShowMode
  self:UpdWindowHdrInfo(isRedraw)
  if m == 1 then
    self:UpdWindowMode1()
  elseif m == 22 then
    self:UpdWindowModeAvARewards()
  elseif m == 27 then
    self:UpdWindowModeEndeavor()
  elseif m == 32 then
    self:UpdWindowModeCompClassSkills()
  elseif m == 36 then
    self:UpdWindowModeCompWeaponSkills()
  elseif m == 38 then
    self:UpdWindowModeWorldEvents()
  elseif m == 39 then
    self:UpdWindowModeCompArmorEquips()
  elseif m == 40 then
    self:UpdWindowModeCompWeaponEquips()
  elseif m == 52 then
    self:UpdWindowModeCompActiveSkills()
  else
    self:UpdWindowModeChar()
  end
end
--
-- Section 4: Update saved variables & support for initialization
--
function WPamA:UpdRGLAInfo()
  self:UpdRGLAMode()
  local b = self.CurChar.DBoss
  local l = self.WorldBosses.Locations[self.RGLA_Mode]
  local curBoss = self.CurChar.DBossLoc[self.RGLA_Mode]
  local curPresent = false
  for i=1,6 do
    local j = l.b + i - 1
    if j <= l.e then
      if j == curBoss then
        curPresent = true
        self:UpdWWBColor(b[j], self.ctrlRGLA[i], true)
      else
        self:UpdWWBColor(b[j], self.ctrlRGLA[i], false)
      end
    end
  end
  local flStart, flStop = false, self.RGLA_Started
  if flStop then
    WPamA_RGLAStart:SetText(self.i18n.RGLAStarted) 
  else
    WPamA_RGLAStart:SetText(self.i18n.RGLAStart)
    if curPresent then
      flStart = true
    end
  end
  WPamA_RGLAStart:SetEnabled(flStart)
  --WPamA_RGLAPost:SetEnabled(true)
  WPamA_RGLAStop:SetEnabled(flStop)
  WPamA_RGLAShare:SetEnabled(curPresent)
end

function WPamA:RestorePosition(ctrl, hld, ismain)
  if hld.m ~= nil and hld.x ~= nil and hld.y ~= nil then
    ctrl:ClearAnchors()
    local a = self.tWinAlignSettings[hld.m]
    ctrl:SetAnchor(a.a, GuiRoot, a.a, a.x * hld.x, a.y * hld.y)
  end
  if ismain then
    if hld.s == nil or hld.s == true then
      self.ShowUI()
    else
      self.HideUI()
    end
  end
end

function WPamA:SavePosition(ctrl, hld)
  local gr_width = GuiRoot:GetWidth()
  local gr_height = GuiRoot:GetHeight()
  local locx, locy = ctrl:GetCenter()
  hld.x = ctrl:GetLeft()
  hld.y = ctrl:GetTop()
  if locx < gr_width / 2 then
    if locy < gr_height / 2 then
      hld.m = 1
    else
      hld.m = 4
    end
  else
    hld.x = gr_width - hld.x - ctrl:GetWidth()
    if locy < gr_height / 2 then
      hld.m = 2
    else
      hld.m = 3
    end
  end
  if hld.m == 3 or hld.m == 4 then
    hld.y = gr_height - hld.y - ctrl:GetHeight()
  end
  hld.x = math.floor(hld.x)
  hld.y = math.floor(hld.y)
end

function WPamA:UpdPlayerLvl()
  self.CurChar.Veteran = IsUnitChampion("player")
  self.CurChar.Lvl = GetUnitLevel("player")
end

function WPamA:GetPledgeDoneStatus(activeStepText)
  local res = 0
  if activeStepText then
    for _, v in pairs(self.i18n.DoneM) do
      if string.find(activeStepText, v) then
        res = 1
        break
      end
    end
  end
  return res
end

function WPamA:GetPledgeDungNumAndNPC(questName)
-- Detect dungeon
  local di = self.GroupDungeons.Iterators
  local dungNum = di.N[questName] or 2
-- Detect pledge-giver NPC
  local npcNum = di.PG[dungNum] or 3
  return dungNum, npcNum
end

function WPamA:UpdPledgeQuestStatus(questName, questStatus, activeStepText)
  if not self.GroupDungeons.Iterators.N[questName] then return end -- it's not a pledge
  local dung, npc = self:GetPledgeDungNumAndNPC(questName)
  local CCP = self.CurChar.Pledges[npc]
  CCP.Num = dung
  local isTodayPledge = self:IsTodayDungNumAndNPC(dung, npc)
  local EndOfPledge = self:GetNextDailyResetTS() - 3 -- end of in-game day minus 3 sec
  local QStat = self.Consts.QuestStatus
  --- Quest Status is Removed / Started / Updated / Completed ---
  if questStatus == QStat.Removed then -- quest is not added/started or is removed/reseted
    CCP.Act = QStat.Removed
    CCP.Num = 1
    CCP.EndTS = 0
--
  elseif questStatus == QStat.Started then -- quest added / started
    CCP.Act = QStat.Started
    CCP.EndTS = 0
--
  elseif questStatus == QStat.Updated then -- quest updated (by step or condition)
    local isReadyToComplete = self:GetPledgeDoneStatus(activeStepText) == 1
    CCP.Act = isReadyToComplete and QStat.Updated or QStat.Started
    CCP.EndTS = 0
--
  elseif questStatus == QStat.Completed then -- quest completed
    CCP.Num = isTodayPledge and dung or 1
    CCP.Act = isTodayPledge and QStat.Completed or QStat.Removed
    CCP.EndTS = isTodayPledge and EndOfPledge or 0
    -- d("EndTS [" .. WPamA:TimestampToStr(CCP.EndTS, 1, true) .. "]")
    GetAddOnManager():RequestAddOnSavedVariablesPrioritySave(self.Name)
  end
end -- UpdPledgeQuestStatus end

function WPamA:FindDailyBossQuest(questName)
  local r = self.WorldBosses.Iterators.N[questName] or 0
  return r
end

function WPamA:FindTrialsQuest(questName)
  local r = self.TrialDungeons.Iterators.N[questName] or 0
  return r
end

function WPamA:CloseQuest(isDone, questName)
  self:UpdToday()
  local d, n = self:GetPledgeDungNumAndNPC(questName)
  local v = self.CurChar
  if d == 2 then
    local qi = self:FindDailyBossQuest(questName)
    if qi ~= 0 then
      local bl = self:GetBossDailyLoc(qi)
      v.DBossLoc[bl] = nil
      if isDone then
        v.DBoss[qi] = GetTimeStamp()
        GetAddOnManager():RequestAddOnSavedVariablesPrioritySave(self.Name)
        if bl == 0 then self:UpdWWBAchiev() end
      end
      if self.RGLA_Mode == bl then
        if self.RGLA_Started then
          self:RGLAStop()
        else
          self:UpdRGLAInfo()
        end
      end
    end
  end
end

function WPamA:GetBossDailyLoc(qi)
  for i, v in pairs(self.WorldBosses.Locations) do
    if qi >= v.b and qi <= v.e then
      return i
    end
  end
  return 0
end

function WPamA:ChkAddBossDailyQuests(questName)
  local qi = self:FindDailyBossQuest(questName)
  if qi ~= 0 then
    local bl = self:GetBossDailyLoc(qi)
    self.CurChar.DBossLoc[bl] = qi
    self:UpdRGLAInfo()
  end
end

function WPamA:ChkAddTrialsQuests(questName)
  local j = self:FindTrialsQuest(questName)
  if j > 0 then
    self.CurChar.Trials[j].Act = 1
  end
end

function WPamA:UpdWritDailyQuests(questName, questStatus)
  local wi = self.DailyWrits.Iterators.N[questName] -- writ index
  if wi then
    local writ = self.CurChar.DailyWrits[wi]
    if questStatus == self.Consts.WritCompleted then -- quest completed
      writ.Act = 0
      writ.EndTS = self:GetNextDailyResetTS()
      GetAddOnManager():RequestAddOnSavedVariablesPrioritySave(self.Name)
    elseif questStatus == self.Consts.WritRemoved then -- quest removed/reseted
      writ.Act = 0
      writ.EndTS = 0
    else -- quest added or updated
      writ.Act = 1
      writ.EndTS = 0
    end
  end
end -- UpdWritDailyQuests end

function WPamA:FindUpdateQuests()
  local co = self.Consts
  local v = self.CurChar
--
  for i, _ in pairs(self.GroupDungeons.OrdPledges) do
    local Plg = v.Pledges[i]
    local isCompl = (Plg.Act == co.QuestStatus.Completed) and self:CheckToday(Plg.EndTS) or false
    if not isCompl then
      Plg.Num = 1
      Plg.Act = co.QuestStatus.Removed
      Plg.EndTS = 0
    end
  end
--
  for i, _ in pairs(self.TrialDungeons.Trials) do
    --if v.Trials[i] == nil then v.Trials[i] = {} end
    v.Trials[i].Act = 0
  end
  v.DBossLoc = {}
--
  for i = 1, MAX_JOURNAL_QUESTS do -- GetNumJournalQuests()
    if IsValidQuestIndex(i) then
      local questName, _, _, _, activeStep, _, _, _, _, questType = GetJournalQuestInfo(i)
      --local questType = GetJournalQuestType(i)
      --local isRepeat = GetJournalQuestRepeatType(i)
      -----------
      if self.DailyWrits.Iterators.N[questName] then -- daily writs
        self:UpdWritDailyQuests(questName, co.WritUpdated)
      -----------
      elseif self.GroupDungeons.Iterators.N[questName] then -- undaunted dailies
        self:UpdPledgeQuestStatus(questName, co.QuestStatus.Updated, activeStep)
      -----------
      elseif self.TrialDungeons.Iterators.N[questName] then -- Trials
        self:ChkAddTrialsQuests(questName)
      -----------
      elseif self.WorldBosses.Iterators.N[questName] then -- World Bosses daily
        self:ChkAddBossDailyQuests(questName)
      -----------
--[[
      elseif isRepeat == QUEST_REPEAT_DAILY then
        if questType == QUEST_TYPE_GROUP then -- any quest include WB daily
          self:ChkAddBossDailyQuests(questName)
        end
--]]
      -----------
      end
    end
  end
end -- FindUpdateQuests end

function WPamA:DoCurrencyUpdate(Invt, num, newval)
  if Invt[num] ~= newval then
    Invt[num] = newval
    if self.SV_Main.ShowMode == 3 then
      self:UpdWindowModeChar()
    end
  end
end

function WPamA:ListInvtItems(bagIdX, fltrId, view)
  local i = 0
-- Scan for Items
  local function do_scan(bagId)
    local slotId = ZO_GetNextBagSlotIndex(bagId, nil)
    while slotId do
      local itemType, specialType = GetItemType(bagId, slotId)
      if itemType > 0 then
        i = i + 1
        local id = GetItemId(bagId, slotId)
        if fltrId == nil or fltrId == id then
          local icon, stack, sellPrice, meetsUsageRequirement, locked, equipType, itemStyleId, quality = GetItemInfo(bagId, slotId)
          local name = GetItemName(bagId, slotId)
          if view == 1 then
            msg(i .. "> ID=" .. id .. ", IT=" .. itemType .. ", Name=" .. name)
            msg("ST=" .. specialType .. ", IS=" .. itemStyleId .. ", Cnt=" .. stack .. ", Ico=" .. icon)
          else
            msg(i .. "> (" .. stack .. ") " .. name .. "[ID=" .. id .. "]")
          end
        end
      end
      slotId = ZO_GetNextBagSlotIndex(bagId, slotId)
    end
  end
  if type(bagIdX) == "table" then
    for _, v in pairs(bagIdX) do
      do_scan(v)
    end
  else
    do_scan(bagIdX)
  end
end

function WPamA:UpdInvtItemsInternal(Invt, bagIdX)
  local II = self.Inventory.InvtItem
  local BI = self.Inventory.InvtItemByID
  local IT = self.Inventory.ItemTypeForCheckST
-- Scan for Items
  local function do_upd(bagId)
    local slotId = ZO_GetNextBagSlotIndex(bagId, nil)
    while slotId do
      local itemType, specialType = GetItemType(bagId, slotId)
      local id = GetItemId(bagId, slotId)
      local j = BI[id]
      if type(j) == "number" then
        local _, stack = GetItemInfo(bagId, slotId)
        Invt[j] = (Invt[j] or 0) + stack
      else
        if IT[itemType] then
          local icon, stack = GetItemInfo(bagId, slotId)
          for i = 1, #II do
            if itemType == II[i].t and (specialType == II[i].st or icon == II[i].i) then
              Invt[i] = (Invt[i] or 0) + stack
              break
            end
          end
        end
      end
      slotId = ZO_GetNextBagSlotIndex(bagId, slotId)
    end
  end -- do_upd end
  ---
  if type(bagIdX) == "table" then
    for _, v in pairs(bagIdX) do
      do_upd(v)
    end
  else
    do_upd(bagIdX)
  end
-- Scan for Currency
  for i = 1, #II do
    if II[i].c then
      if bagIdX == BAG_BACKPACK then
        Invt[i] = GetCurrencyAmount(II[i].c, CURRENCY_LOCATION_CHARACTER)
      else
        Invt[i] = GetCurrencyAmount(II[i].c, CURRENCY_LOCATION_BANK)
      end
    end
  end
end

function WPamA:UpdInvtItems(need_item)
  if self.CurChar then
    local v = self.CurChar
    if v.InvtCnt == nil then v.InvtCnt = {} end
    v.InvtCnt.Total = GetBagSize(BAG_BACKPACK)
    v.InvtCnt.InUse = GetNumBagUsedSlots(BAG_BACKPACK)
    v.InvtCnt.CurUpgrade = GetCurrentBackpackUpgrade()
    if need_item then
      v.Invt = {}
      self:UpdInvtItemsInternal(v.Invt, BAG_BACKPACK)
    end
  end
end

function WPamA:UpdBankItems(need_item)
  if self.SV_Main then
    local v = self.SV_Main
    if v.BankCnt == nil then v.BankCnt = {} end
    v.BankCnt.Total = GetBagSize(BAG_BANK)
    v.BankCnt.InUse = GetNumBagUsedSlots(BAG_BANK)
    if IsESOPlusSubscriber() then
      v.BankCnt.Total  = v.BankCnt.Total  + GetBagSize(BAG_SUBSCRIBER_BANK)
      v.BankCnt.InUse = v.BankCnt.InUse + GetNumBagUsedSlots(BAG_SUBSCRIBER_BANK)
    end
    if need_item then
      v.Bank = {}
      self:UpdInvtItemsInternal(v.Bank, {BAG_BANK,BAG_SUBSCRIBER_BANK})
    end
  end
end

function WPamA:ChkUpdBoss(Boss)
  for i, _ in pairs(self.WorldBosses.Bosses) do
    if Boss[i] ~= nil and not self:CheckToday(Boss[i]) and i > 0 then
      Boss[i] = nil
    end
  end
end

function WPamA:ClearOutdatedLFGActivities(v)
  for act, _ in pairs(self.Consts.LFGCooldownType) do
    if v.LFGActivities and v.LFGActivities[act] then
      if not self:CheckToday( v.LFGActivities[act] ) then v.LFGActivities[act] = nil end
    end
  end
end

function WPamA:UpdClassSkillLinesSI()
  local ClassId = GetUnitClassId("player")
  local ClassMrk = {[1]="dragonknight", [2]="sorcerer", [3]="nightblade", [4]="warden", [5]="necromancer", [6]="templar", [117]="arcanist",}
  local t = ClassMrk[ClassId]
  local j = 1
  local n = GetNumSkillLines(SKILL_TYPE_CLASS)
  local SL = self.SkillLines.SkillLines
  for i = 1, n do
    local _, texture = GetSkillAbilityInfo(SKILL_TYPE_CLASS, i, 1)
    if string.find(texture, t) then
      SL[j].si = i
      j = j + 1
      if j > 3 then break end
    end
  end
end

function WPamA:UpdAvASkillLinesSI()
  local UV = zo_strupper(GetString(SI_INVENTORY_MODE_VENGEANCE))
  local SL = self.SkillLines.SkillLines
  local AVA = SKILL_TYPE_AVA
  ----local n = GetNumSkillLines(AVA)
  for i = 1, GetNumSkillLines(AVA) do
    local sli = GetSkillLineId(AVA, i)
    local sln = zo_strupper(GetSkillLineNameById(sli))
    local isVSL = sln:find(UV) and true or false
    if not isVSL then
      local _, texture = GetSkillAbilityInfo(AVA, i, 1)
      for k = 17, 19 do
        ----if string.find(texture, SL[k].mrk) then
        if texture:find(SL[k].mrk) then
          SL[k].si = i
          break
        end
      end
    end
  end
end -- UpdAvASkillLinesSI end

function WPamA:UpdAvailableSP()
  self.CurChar.AvlSkP = GetAvailableSkillPoints()
  --self.CurChar.AvlSkP = SKILL_POINT_ALLOCATION_MANAGER:GetAvailableSkillPoints()
  local allocatedSP = 0
  for _, STD in SKILLS_DATA_MANAGER:SkillTypeIterator() do
    if STD then -- Skill Type Data
      for _, SLD in STD:SkillLineIterator({ ZO_SkillLineData_Base.IsAvailable }) do
        if SLD then -- Skill Line Data
          local skpAllocated = SKILL_POINT_ALLOCATION_MANAGER:GetNumPointsAllocatedInSkillLine(SLD)
          if skpAllocated > 0 then allocatedSP = allocatedSP + skpAllocated end
        end
      end -- Skill Line Iterator
    end
  end -- Skill Type Iterator
  self.CurChar.AllocSkP = allocatedSP
end -- UpdAvailableSP end

function WPamA:UpdAvailableCHMP(init)
  local CD = self.ChampionDisciplines
-- Initialization of constant values
  if init then
    local MS = self.ModeSettings[30]
    for cdIndex, cdData in CHAMPION_DATA_MANAGER:ChampionDisciplineDataIterator() do
      CD[cdIndex].Icon = cdData:GetPointPoolIcon()
      CD[cdIndex].Name = cdData:GetFormattedName()
      CD[cdIndex].Total = cdData:GetNumSavedPointsTotal()
      MS.HdT[cdIndex] = CD[cdIndex].Name
    end
    return
  end
-- Update available Champion Disciplines
  local CC = self.CurChar
  if CC.AvlChmpDisciplines == nil then CC.AvlChmpDisciplines = {} end
  local AvlCD = CC.AvlChmpDisciplines
  for cdIndex, cdData in CHAMPION_DATA_MANAGER:ChampionDisciplineDataIterator() do
    AvlCD[cdIndex] = cdData:GetNumAvailablePoints()
    CD[cdIndex].Total = cdData:GetNumSavedPointsTotal()
  end
end -- UpdAvailableCHMP end

function WPamA:UpdFavorsCount()
  local Favors = self.CurChar.Favors
  for i = 1, #self.Favors.QuestIDs do
    local unlocked, total = GetNumUnlockedMailsInMailList(i)
    if total > 0 then
      Favors[i].Unlock = unlocked
      Favors[i].Total  = total
    end
  end
end

function WPamA:UpdLoreBookCount()
  local Books = self.CurChar.Books
  local n = GetNumLoreCategories()
  for i = 1, 3 do
    if i <= n then
      local categoryName, numCollections = GetLoreCategoryInfo(i)
      local cnt, ttl = 0, 0
      for j = 1, numCollections do
        local _, _, numKnownBooks, totalBooks, _, _, _ = GetLoreCollectionInfo(i, j)
        cnt = cnt + nvl(numKnownBooks, 0)
        ttl = ttl + nvl(totalBooks, 0)
      end
      Books[i] = {Cnt=cnt, Ttl=ttl}
--    msg(categoryName .. ": " .. cnt .. "/" .. ttl)
    end
  end
end

function WPamA:UpdCharInfo()
-- Update information about character
  if self.CurChar ~= nil then
    self.CurChar.Alli  = GetUnitAlliance("player")
    self.CurChar.Class = GetUnitClassId("player")
    self.CurChar.Race  = GetUnitRaceId("player")
    self:UpdPlayerLvl()
    self:UpdAvailableSP()
    self:UpdAvailableCHMP()
    self:FindUpdateQuests()
    self:UpdWWBAchiev()
    self:UpdInvtItems(true)
    self:UpdBankItems(true)
    self:UpdFestivalsInfo()
    self:UpdRidingSkillsInfo()
    self:UpdDungeonsQuestInfo()
--[[ -- no need that after High Isle release
    self:UpdAssignedCampaignData()
    self:UpdCampaignLeaderBoardData()
    self:UpdBGrndLeaderBoardData()
--]]
    self:UpdActiveCompanionData()
    self:UpdLoreBookCount()
    self:UpdFavorsCount()
    self:UpdWindowInfo(true)
  end 
end -- UpdCharInfo end

function WPamA:UpdCharLoginData(isPlayerChangedZone)
  if self.SV_Main.RequestedReloadUI then
    -- do nothing --
    self.SV_Main.RequestedReloadUI = nil
--
  elseif isPlayerChangedZone and ( not self:CheckToday(self.CurChar.LastLoginTS) ) then
    self.CurChar.LastLoginTS = GetTimeStamp()
  end
end
--
-- Section 5: Addon initialization
--
function WPamA:Cmp2Chars(a, b, ord)
  local o = ord
  if o == 6 or o == 7 then
    if a.Alli == b.Alli then
      o = o - 2
    else
      return a.Alli > b.Alli
    end
  end
  if o == 4 then
    if math.floor(a.Lvl) == math.floor(b.Lvl) then
      o = 2
    else
      return a.Lvl < b.Lvl
    end
  elseif o == 5 then
    if math.floor(a.Lvl) == math.floor(b.Lvl) then
      o = 2
    else
      return a.Lvl > b.Lvl
    end
  end
  if o == 3 then
    if a.Alli == b.Alli then
      o = 2
    else
      return a.Alli > b.Alli
    end
  end
  if o == 2 then
    return a.Name > b.Name
  end
  return false
end

function WPamA:InitCharsList(SV)
  local CN, CL, f, n, ord = {}, SV.CharsList, false, GetNumCharacters(), SV.CharsOrder
-- Get the name of the character and are looking for it in the list of characters
  self.CharName = GetUnitName("player")
  self.CharNum = 0
  self.CurChar = nil
  local CharNameUp = string.upper(self.CharName)
-- 
  for i = 1, n do
    -- Returns: string name, number Gender gender, number level, number classId, number raceId,
    -- number Alliance alliance, string id, number locationId
    local nam, _, lvl, classId, raceId, alli = GetCharacterInfo(i)
    nam = nam:gsub("%^.+", "")  -- "PlayerName^Mx" -> "PlayerName"
    CN[i] = { Name = nam, Lvl = lvl, Class = classId, Race = raceId, Veteran = lvl == 50, Alli = alli }
    if nam == self.CharName then self.CharNum = i end
  end
  if ord > 1 then
    for i = 1, n-1 do
      for j = i+1, n do
        if self:Cmp2Chars(CN[i], CN[j], ord) then
          CN[i], CN[j] = CN[j], CN[i] 
          if self.CharNum == i then
            self.CharNum = j
          elseif self.CharNum == j then
            self.CharNum = i
          end
        end
      end
    end
  end
  if self.CharNum == 0 then
    for i = 1, n do
      if CharNameUp == string.upper(CN[i].Name) then
        self.CharNum = i
        break
      end
    end
  end
-- Checking whether all data in the list of characters
  if #CL ~= n then
    f = true
  else
    for i = 1, n do
      if CL[i] == nil or CL[i].Name ~= CN[i].Name then
        f = true
        break
      end
    end
  end
-- Repackaging the characters list
  if f then
    local HL, k = CL, 0
    SV.CharsList = {}
    CL = SV.CharsList
    for i = 1, n do
      k = 0
      for j, v in pairs(HL) do
        if v.Name == CN[i].Name then
          k = j
          break
        end
      end
      if k == 0 then
        CL[i] = { Name = CN[i].Name, Lvl = CN[i].Lvl, Class = CN[i].Class, Race = CN[i].Race, Veteran = CN[i].Veteran,
                  Alli = CN[i].Alli, Pledges = {}, Trials = {}, DBoss = {[0]={},}, Invt = {}, Festivals = {}, }
      else
        CL[i] = HL[k]
      end
    end
  end
  self.CurChar = CL[self.CharNum]
  for i = 1, n do
    local v = CL[i]
-- Clear old vars / Remove obsolete variables
    v.Gld = nil
    v.Slv = nil
    v.isVeteranLFGP = nil
    v.is5keysLFGP = nil
    v.WrBoss = nil
-- Init vars
    if v.Lvl == nil then v.Lvl = 1 end
    if v.Veteran == nil then v.Veteran = v.Lvl == 50 end
    if v.PlayedTime == nil then v.PlayedTime = 0 end -- character's seconds played GetSecondsPlayed()
    if v.LastLoginTS == nil then v.LastLoginTS = 0 end
    if v.GroupDungeons == nil then v.GroupDungeons = {} end
--
    if v.Pledges == nil then v.Pledges = {} end
    for j, _ in pairs(self.GroupDungeons.OrdPledges) do
      if v.Pledges[j] == nil then v.Pledges[j] = {} end
      if v.Pledges[j].EndTS == nil then v.Pledges[j].EndTS = 0 end
      if v.Pledges[j].Num == nil then v.Pledges[j].Num = 1 end
      if v.Pledges[j].Act == nil then v.Pledges[j].Act = 0 end
      if v.Pledges[j].QN  then v.Pledges[j].QN  = nil end
      if v.Pledges[j].BTS then v.Pledges[j].BTS = nil end
      if v.Pledges[j].ETS then
        if v.Pledges[j].ETS > 0 then
          v.Pledges[j].EndTS = v.Pledges[j].ETS
          v.Pledges[j].Num = 1
          v.Pledges[j].Act = self.Consts.QuestStatus.Completed
        end
        v.Pledges[j].ETS = nil
      end
    end
--
    self:ClearOutdatedLFGActivities(v)
    if v.DBossLoc == nil then v.DBossLoc = {} end
    if v.DBoss == nil then v.DBoss = {} else self:ChkUpdBoss(v.DBoss) end
--
    if v.Trials == nil then v.Trials = {} end
    for j, _ in pairs(self.TrialDungeons.Trials) do
      if v.Trials[j] == nil then v.Trials[j] = {} end
      if v.Trials[j].Act == nil then v.Trials[j].Act = 0 end
      if v.Trials[j].TS == nil then v.Trials[j].TS = 0 end
    end
--
    if v.Invt == nil then v.Invt = {} end
    if v.InvtCnt == nil then v.InvtCnt = {Total=0, InUse=0} end
    if v.Equips == nil then v.Equips = {} end
    if v.Skills == nil then v.Skills = {} end
    if v.isVisible == nil then v.isVisible = true end
    if v.CharModeLFGP == nil then v.CharModeLFGP = 1 end
--
    if v.ShSupplier == nil then v.ShSupplier = {Avl=0, Option=1, Mode=1} end
    if v.ShSupplier.Option == nil then v.ShSupplier.Option = 1 end
    if v.ShSupplier.Mode == nil then v.ShSupplier.Mode = 1 end
--
    if v.Festivals == nil then v.Festivals = {} end
    for j = 1, #self.Festivals.AchievementsIDs do
      if v.Festivals[j] == nil then v.Festivals[j] = {} end
    end
--
    if v.Favors == nil then v.Favors = {} end
    for j = 1, #self.Favors.QuestIDs do
      if v.Favors[j] == nil then v.Favors[j] = {} end
    end
--
    if v.RidingSkills == nil then v.RidingSkills = {[1] = 0, [2] = 0, [3] = 0, [4] = nil}
      -- 1 = Speed, 2 = Stamina, 3 = Capacity, 4 = TimeWhenNextTrainReady
    end
--
    if v.AvA == nil then
      v.AvA = { Rank = 0, iconRank = "", AssignedCampaign = {}, ImperialCity = {}, BattleGrounds = {} }
      v.AvA.AssignedCampaign = { ID = 0, RT = 0, EndTS = 0, RankLB = 0, Emperor = false }
      v.AvA.BattleGrounds = { RankComp = 0, EndTS = 0 } -- RankDM = 0, RankLG = 0, RankFG = 0
    end
--
    if v.AvA.BattleGrounds.RankComp == nil then v.AvA.BattleGrounds.RankComp = 0 end
    if v.AvA.BattleGrounds.EndTS == nil then v.AvA.BattleGrounds.EndTS = 0 end
--
    if v.Companions == nil then v.Companions = {} end
    for ccid = 1, #self.Companions.Persons do
      if v.Companions[ccid] == nil then
        v.Companions[ccid] = { Rapport = 99999, RapportLvl = 0, hasQuest = false }
      end
      if v.Companions[ccid].StoryQuests == nil then v.Companions[ccid].StoryQuests = {} end
    end
--
    if v.DailyWrits == nil then v.DailyWrits = {} end
    for j = 1, #self.DailyWrits.QuestIDs do
      if v.DailyWrits[j] == nil then v.DailyWrits[j] = { Act = self.Consts.WritRemoved, EndTS = 0 } end -- Act = 2
    end
--
    if v.Books == nil then v.Books = {} end
    for j = 1, 3 do
      if v.Books[j] == nil then v.Books[j] = { Cnt = 0, Ttl = 0 } end
    end
--
    if v.CraftRecipes == nil then v.CraftRecipes = { Recipes = {}, Blueprints = {} } end
    for j = CRAFTING_TYPE_MIN_VALUE, CRAFTING_TYPE_MAX_VALUE do -- from 0 to 8
      if v.CraftRecipes.Recipes[j] == nil then v.CraftRecipes.Recipes[j] = {} end
      if v.CraftRecipes.Blueprints[j] == nil then v.CraftRecipes.Blueprints[j] = {} end
    end
--
    if v.LFGActivities == nil then
      v.LFGActivities = {}
      if v.LFGRndTS then
        v.LFGActivities[LFG_ACTIVITY_DUNGEON] = v.LFGRndTS
        v.LFGRndTS = nil
      end
      if v.LFGBGTS then
        v.LFGActivities[LFG_ACTIVITY_BATTLE_GROUND_NON_CHAMPION] = v.LFGBGTS
        v.LFGBGTS = nil
      end
    end
--
    if v.TimedEffects == nil then v.TimedEffects = { AvA = {}, PvE = {}, Stat = {} } end
    for j, _ in pairs(v.TimedEffects) do
      if v.TimedEffects[j].Index == nil then v.TimedEffects[j].Index = 0 end
      if v.TimedEffects[j].EndTS == nil then v.TimedEffects[j].EndTS = 0 end
      if v.TimedEffects[j].SecUE == nil then v.TimedEffects[j].SecUE = 0 end
    end
--
    if v.EndlessDungeons == nil then v.EndlessDungeons = {} end
--    for j = 1, #self.EndlessDungeons.Dungeons do
--      local edID = self.EndlessDungeons.Dungeons[j].IID
    local id = self.EndlessDungeons.Iterators.I[ DEFAULT_ENDLESS_DUNGEON_ID ]
    if v.EndlessDungeons[id] == nil then
      v.EndlessDungeons[id] = {}
      v.EndlessDungeons[id].EndTS = -1 -- has a Intro quest
      v.EndlessDungeons[id][ ENDLESS_DUNGEON_GROUP_TYPE_SOLO ] = self.EndlessDungeons.DefStat or {}
      v.EndlessDungeons[id][ ENDLESS_DUNGEON_GROUP_TYPE_DUO  ] = self.EndlessDungeons.DefStat or {}
    end
--    end
------------
  end
end -- InitCharsList end

function WPamA:InitSavedVars()
  self.SV_Debug = ZO_SavedVars:NewAccountWide("WPamA_SV_Debug", 1, nil, {})
  local SD = self.SV_Debug
  if SD.Log == nil then SD.Log = {} end
  if SD.IsDebugMode == nil then SD.IsDebugMode = false end
--
  self.SV_Main = ZO_SavedVars:NewAccountWide("WPamA_SV_Main", 1, self.Consts.Realms[self.Consts.RealmIndex], {})
  local SV = self.SV_Main
  if SV.CharsList == nil then SV.CharsList = {} end
  if SV.WinMain == nil then
    SV.WinMain = {}
    self:SavePosition(WPamA_Win, SV.WinMain)
  end
  if SV.WinRGLA == nil then
    SV.WinRGLA = {}
    self:SavePosition(WPamA_RGLA, SV.WinRGLA)
  end
  if SV.AvADailyRewards == nil then
    SV.AvADailyRewards = { [1] = 0, [2] = 0, [3] = 0, [4] = 0 } -- 1 = Cyrodiil, 2 = BG, 3 = IC, 4 = BG(BMT)
  end
  if SV.Endeavor == nil then
    SV.Endeavor = {
      [1] = {NumCompl = 0, NumTotal = 0, EndTS = 0}, -- Reward = "", }, -- Daily
      [2] = {NumCompl = 0, NumTotal = 0, EndTS = 0}, -- Reward = "", }, -- Weekly
      [3] = {NumCompl = 0, NumTotal = 0, EndTS = 0}  -- Reward = "", }, -- Seasonal
     }
  else
    for ind = 1, 3 do
      if type(SV.Endeavor[ind]) ~= "table" then SV.Endeavor[ind] = {NumCompl = 0, NumTotal = 0, EndTS = 0} end
    end
  end
-- Initialization of the account's Companions
  if SV.Companions == nil then SV.Companions = {} end
  for ccid = 1, #self.Companions.Persons do
    if SV.Companions[ccid] == nil then
      SV.Companions[ccid] = { Lvl = 99, LvlPrc = 0, Skills = {}, Equips = {}, SkillBar = {} }
    end
    if SV.Companions[ccid].Equips == nil then SV.Companions[ccid].Equips = {} end
    if SV.Companions[ccid].SkillBar == nil then SV.Companions[ccid].SkillBar = {} end
  end
-- Initialization of Window
  if SV.isWindVisible == nil then SV.isWindVisible = {} end
  for i = 0, self.WindCount - 1 do
    if type(SV.isWindVisible[i]) ~= "boolean" then
      SV.isWindVisible[i] = true
    end
  end
  local i = 0
  for _, v in pairs(SV.isWindVisible) do
    if v then i = i + 1 end
  end
  if i == 0 then SV.isWindVisible[i] = true end -- protection from all-window-off situation
-- Initialization of window Modes
  if SV.isModeVisible == nil then SV.isModeVisible = {} end
  for i = 0, self.ModeCount - 1 do
    if type(SV.isModeVisible[i]) ~= "boolean" then
      SV.isModeVisible[i] = self.ModeSettings[i].isVisibleDef
    end
  end
  i = 0
  for _, v in pairs(SV.isModeVisible) do
    if v then i = i + 1 end
  end
  if i == 0 then SV.isModeVisible[i] = true end -- protection from all-modes-off situation
-- Initialization of some saved variables
  if SV.Bank == nil then SV.Bank = {} end
  if SV.BankCnt == nil then SV.BankCnt = {Total=0, InUse=0} end
  if SV.BossKilled == nil then SV.BossKilled = true end
  if SV.QChat == nil then SV.QChat = false end
  if SV.QAlert == nil then SV.QAlert = true end
  if SV.ENDung == nil then SV.ENDung = false end
  if SV.ShowLoc == nil then SV.ShowLoc = false end
  if SV.ShowMode == nil then SV.ShowMode = 0 end
  if SV.ShowTime == nil then SV.ShowTime = true end
  if SV.DateFrmt == nil then SV.DateFrmt = self.i18n.DateFrmt end
  if SV.AutoShare == nil then SV.AutoShare = true end
  if SV.CharsOrder == nil then SV.CharsOrder = 1 end
  if type(SV.LargeCalend) ~= "number" then SV.LargeCalend = (SV.LargeCalend and 3) or 1 end
  if SV.TrialAvlFrmt == nil then SV.TrialAvlFrmt = 1 end
  if SV.DontShowNone == nil then SV.DontShowNone = false end
  if SV.TitleToolTip == nil then SV.TitleToolTip = false end
  if SV.AlwaysMaxWinX == nil then SV.AlwaysMaxWinX = false end
  if SV.ShowMonsterSet == nil then SV.ShowMonsterSet = true end
  if SV.CurrencyValueThreshold == nil then SV.CurrencyValueThreshold = 99999 end
  if SV.AutoTakePledges == nil then SV.AutoTakePledges = false end
  if SV.HintUncompletedPledges == nil then SV.HintUncompletedPledges = false end
  if SV.AutoCallEyeInfinite == nil then SV.AutoCallEyeInfinite = false end
  if SV.AutoChargeWeapon == nil then SV.AutoChargeWeapon = false end
  if SV.AutoChargeThreshold == nil then SV.AutoChargeThreshold = 3 end
  if SV.RndDungDelay == nil then SV.RndDungDelay = self.Consts.RndDungDelayDef end
  if SV.ShowMouseMode == nil then SV.ShowMouseMode = false end
  if SV.CharNamesInColors == nil then SV.CharNamesInColors = true end
  if SV.CharNamesAlignment == nil then SV.CharNamesAlignment = TEXT_ALIGN_LEFT end
  if SV.CharNamesCorrMode == nil then SV.CharNamesCorrMode = 0 end
  if SV.CharNamesMaskFrom == nil then SV.CharNamesMaskFrom = "" end
  if SV.CharNamesMaskTo == nil then SV.CharNamesMaskTo = "" end
  if SV.DynEncounterNotifyMode == nil then SV.DynEncounterNotifyMode = 1 end
  if SV.CompanionRapportMode == nil then SV.CompanionRapportMode = 1 end
  if SV.CompanionRapportShowMax == nil then SV.CompanionRapportShowMax = true end
  if SV.CompanionEquipMode == nil then SV.CompanionEquipMode = 1 end
  if SV.EndeavorRewardMode == nil then SV.EndeavorRewardMode = 1 end
  if type(SV.EndeavorProgressInChat) ~= "table" then
    SV.EndeavorProgressInChat = { Enabled = SV.EndeavorProgressInChat or false,
                                  Channel = CHAT_CATEGORY_SYSTEM,
                                  isUseCustomColor = true,
                                  Color = string.format("%02x%02x%02x", 238, 238, 200) }
  end
  if SV.AutoClaimEndeavorReward == nil then SV.AutoClaimEndeavorReward = false end
  if SV.EndeavorHideCompleted == nil then SV.EndeavorHideCompleted = false end
  if SV.CustomModeKeybinds == nil then SV.CustomModeKeybinds = {} end
  if SV.AutoTakeDBSupplies == nil then SV.AutoTakeDBSupplies = 1 end
  if SV.PursuitProgressInChat == nil then
    SV.PursuitProgressInChat = { Enabled = false,
                                 Channel = CHAT_CATEGORY_SYSTEM,
                                 CampRewardEarned = false,
                                 isUseCustomColor = true,
                                 Color = string.format("%02x%02x%02x", 238, 238, 200) }
  end
  if SV.AutoClaimPursuitReward == nil then SV.AutoClaimPursuitReward = false end
--
  if SV.RGLALangChk == nil then SV.RGLALangChk = self.i18n.Lng == "JP" end
  if SV.RGLALangEd == nil then SV.RGLALangEd = self.i18n.RGLA.CL end
--
  if SV.ModeLFGP == nil then SV.ModeLFGP = 1 end
  if SV.ModeLFGPRoulette == nil then SV.ModeLFGPRoulette = false end
  if SV.LFGPChat == nil then SV.LFGPChat = false end
  if SV.LFGPAlert == nil then SV.LFGPAlert = true end
  if SV.AllowLFGP == nil then SV.AllowLFGP = false end
  if SV.LFGRndAvlFrmt == nil then SV.LFGRndAvlFrmt = 1 end
  if SV.LFGRndDontShowSt == nil then SV.LFGRndDontShowSt = false end
  if SV.LFGPIgnorePledge == nil then SV.LFGPIgnorePledge = false end
end

function WPamA.OnAddInitialize()
  EVENT_MANAGER:UnregisterForEvent(WPamA.Name .. "AddInit", EVENT_PLAYER_ACTIVATED)
  WPamA:UpdToday()
--
  OldReloadUI = ReloadUI
  function ReloadUI( ... )
    WPamA.SV_Main.RequestedReloadUI = true
    OldReloadUI( ... )
  end
-- Update the char data
  WPamA.CurChar.PlayedTime = GetSecondsPlayed()
-- Update the quest data
  WPamA:FindUpdateQuests()
-- Update the Cyrodiil and battleground data
  WPamA:CheckAVADataUpdateNeeded()
  WPamA:ClearOutdatedAVAData()
-- Update the Endeavor data
  WPamA:EndeavorDataUpdate()
-- Update the Promo event activity data
  WPamA:PromoActivityDataUpdate()
-- Update the Companions unlocked data
  WPamA:CheckCompanionsUnlocked()
-- Update the Endless Dungeon LB data
  WPamA:CheckEDADataUpdateNeeded()
-- Update the character's Equipment data
  WPamA:UpdCharEquipmentData()
-- Update known Recipes & Blueprints data
  WPamA:UpdateRecipeData()
-- Update active Timed Effects
  WPamA:UpdateActiveTimedEffects()
-- Update addon window
  WPamA:UpdWindowInfo()
end -- OnAddInitialize end

function WPamA:InitLocalization()
  local l = self.i18n
  local z = self.ModeSettings
  if type(l.ModeSettings) == "table" then
    for i, v in pairs(l.ModeSettings) do
      if type(v.HdT) == "table" then
        for j, s in pairs(v.HdT) do
          z[i].HdT[j] = s
        end
      end
    end
  end
end

function WPamA:Initialize()
  self:UpdClassSkillLinesSI()
  self:UpdAvASkillLinesSI()
  self:UpdToday()
  self:LoadTbColors()
  self:LoadDLCinfo(self.GroupDungeons.Dungeons)
  self:LoadDLCinfo(self.TrialDungeons.Trials)
  self:SetFestivalsTitles()
  self:SetCompanionsPersons()
  self:UpdAvailableCHMP(true)
  self:InitInvtItemTT()
  self:InitLocalization()
  self:InitLoreBookMode()
-- Initialization of saved variables
  self:InitSavedVars()
  local SV = self.SV_Main
  self:InitCharsList(SV)
-- Init current Enlightenment status
  if IsEnlightenedAvailableForAccount() and (GetEnlightenedPool() ~= 0) then
    WPamA.EnlitState = true
  end
-- Init Main and RGLA window
  self:UI_InitMainWindow()
  self:UI_InitRGLAWindow()
  self:UI_SelWindUpdColor()
--
  WPamA_RGLAStart:SetHandler("OnClicked", WPamA.OnRGLAStartClick)
  WPamA_RGLAPost:SetHandler("OnClicked", WPamA.OnRGLASelectMsgClick)
  WPamA_RGLAStop:SetHandler("OnClicked", WPamA.OnRGLAStopClick)
  WPamA_RGLAShare:SetHandler("OnClicked", WPamA.OnRGLAShareClick)
--
  ZO_CheckButton_SetCheckState(WPamA_RGLA_MsgLangChk, SV.RGLALangChk)
  ZO_CheckButton_SetToggleFunction(WPamA_RGLA_MsgLangChk, function(control, checked) SV.RGLALangChk = checked; end)
  WPamA_RGLA_MsgLangEd:SetText(SV.RGLALangEd)
  WPamA_RGLA_MsgLangEd:SetHandler("OnTextChanged", function(control) SV.RGLALangEd = control:GetText(); end)
--
  self:RestorePosition(WPamA_Win, SV.WinMain, true)
  self:RestorePosition(WPamA_RGLA, SV.WinRGLA, false)
  self:UpdCharInfo()
  self:InitSkillLines()
  self:SetLFGRewardTime(LFG_ACTIVITY_INVALID) -- all activity types
  self:UpdShadowySupplier()
-- Register keybinding string
  ZO_CreateStringId("SI_BINDING_NAME_WPAMAWINDOWTOGGLE", self.i18n.KeyBindShowStr)
  ZO_CreateStringId("SI_BINDING_NAME_WPAMAMODECHANGE", self.i18n.KeyBindChgWStr)
  ZO_CreateStringId("SI_BINDING_NAME_WPAMATABCHANGE", self.i18n.KeyBindChgTStr)
  ZO_CreateStringId("SI_BINDING_NAME_WPAMAALTMODECHANGE", self.i18n.KeyBindChgAStr)
  ZO_CreateStringId("SI_BINDING_NAME_WPAMAFAVRADMENU", self.i18n.KeyFavRadMenu)

  ZO_CreateStringId("SI_BINDING_NAME_WPAMACHARTOGGLE", self.i18n.KeyBindCharStr)
  ZO_CreateStringId("SI_BINDING_NAME_WPAMACLNDTOGGLE", self.i18n.KeyBindClndStr)
  ZO_CreateStringId("SI_BINDING_NAME_WPAMACHATPOSTTD", self.i18n.KeyBindPostTd)
  ZO_CreateStringId("SI_BINDING_NAME_WPAMACHATPOSTTDCL", self.i18n.KeyBindPostTdCL)

  ZO_CreateStringId("SI_BINDING_NAME_WPAMAWND0TOGGLE", self.i18n.KeyBindWindow0)
  ZO_CreateStringId("SI_BINDING_NAME_WPAMAWND1TOGGLE", self.i18n.KeyBindWindow1)
  ZO_CreateStringId("SI_BINDING_NAME_WPAMAWND2TOGGLE", self.i18n.KeyBindWindow2)
  ZO_CreateStringId("SI_BINDING_NAME_WPAMAWND3TOGGLE", self.i18n.KeyBindWindow3)
  ZO_CreateStringId("SI_BINDING_NAME_WPAMAWND4TOGGLE", self.i18n.KeyBindWindow4)
  ZO_CreateStringId("SI_BINDING_NAME_WPAMAWND5TOGGLE", self.i18n.KeyBindWindow5)
  ZO_CreateStringId("SI_BINDING_NAME_WPAMAWND6TOGGLE", self.i18n.KeyBindWindow6)
  ZO_CreateStringId("SI_BINDING_NAME_WPAMAWND7TOGGLE", self.i18n.KeyBindWindow7)
  ZO_CreateStringId("SI_BINDING_NAME_WPAMAWND8TOGGLE", self.i18n.KeyBindWindow8)

  ZO_CreateStringId("SI_BINDING_NAME_WPAMARGLA", self.i18n.KeyBindRGLA)
  ZO_CreateStringId("SI_BINDING_NAME_WPAMARGLASRT", self.i18n.KeyBindRGLASrt)
  ZO_CreateStringId("SI_BINDING_NAME_WPAMARGLASTP", self.i18n.KeyBindRGLAStp)
  ZO_CreateStringId("SI_BINDING_NAME_WPAMARGLAPST", self.i18n.KeyBindRGLAPst)
  ZO_CreateStringId("SI_BINDING_NAME_WPAMARGLASHR", self.i18n.KeyBindRGLAShr)

  ZO_CreateStringId("SI_BINDING_NAME_WPAMALFGP", self.i18n.KeyBindLFGP)
  ZO_CreateStringId("SI_BINDING_NAME_WPAMALFGPMODE", self.i18n.KeyBindLFGPMode)

  for i = 1, self.Consts.CustomKeybindsMax do
    ZO_CreateStringId("SI_BINDING_NAME_WPAMACUSTOM" .. i .. "TOGGLE", zo_strformat(self.i18n.OptCustomModeKbd, i))
  end
-- Init radial menu
  WPamA.FavRadMenu = WPamA.RadMenuClass:New(WPamA_FavRad, "ZO_SelectableItemRadialMenuEntryTemplate",
                                            "DefaultRadialMenuAnimation", "SelectableItemRadialMenuEntryAnimation")
-- Preparing an array of Pledge-Giver-NPC's statuses
  for i = 1, #self.i18n.PledgeQGivers do -- for current lang
    self.PledgeGivers[ self.i18n.PledgeQGivers[ i ] ] = true
    if RuESO_init then -- additional for compatible with all RuESO options
      self.PledgeGivers[ self.EN.PledgeQGivers[ i ] ] = true
      -- local enruStr = self.EN.PledgeQGivers[ i ] .. "\n" .. self.i18n.PledgeQGivers[ i ]
      -- local ruenStr = self.i18n.PledgeQGivers[ i ]  .. "\n" .. self.EN.PledgeQGivers[ i ]
      -- self.PledgeGivers[ enruStr ] = true
      -- self.PledgeGivers[ ruenStr ] = true
    end
  end
-- Register Slash Command to show/hide addon window
  SLASH_COMMANDS["/wpa"] = function(cmd)
    if cmd == "" then
      self.TogleUI()
    elseif cmd == "td" or cmd == "today" then
      self:PostPledgeToChat(false)
    elseif cmd == "tde" or cmd == "todayen" then
      self:PostPledgeToChat(true)
    elseif cmd == "yd" or cmd == "yesterday" then
      self:PostPledgeToChat(false,-1)
    elseif cmd == "yde" or cmd == "yesterdayen" then
      self:PostPledgeToChat(true,-1)
    elseif cmd == "tm" or cmd == "tomorrow" then
      self:PostPledgeToChat(false,1)
    elseif cmd == "tme" or cmd == "tomorrowen" then
      self:PostPledgeToChat(true,1)
    elseif string.sub(cmd, 1, 3) == "pl " then
      self:PostPledgeToChat(false,tonumber(string.sub(cmd, 4)))
    elseif string.sub(cmd, 1, 4) == "ple " then
      self:PostPledgeToChat(true,tonumber(string.sub(cmd, 5)))
    elseif cmd == "on" or cmd == "show" then
      self.ShowUI()
    elseif cmd == "off" or cmd == "hide" then
      self.HideUI()
    elseif cmd == "r" or cmd == "refresh" then
      self:LoadDLCinfo(self.GroupDungeons.Dungeons)
      self:LoadDLCinfo(self.TrialDungeons.Trials)
      self:FindUpdateQuests()
      self:UpdWindowInfo()
    elseif cmd == "ch" or cmd == "char" then
      SV.ShowMode = 0
      self:UpdWindowInfo()
      self.ShowUI()
    elseif cmd == "cl" or cmd == "calendar" then
      SV.ShowMode = 1
      self:UpdWindowInfo()
      self.ShowUI()
    elseif cmd == "ava" or cmd == "pvp" then
      SV.ShowMode = 16
      self:UpdWindowInfo()
      self.ShowUI()
    elseif cmd == "n" or cmd == "name" then
      self.SetVal_ShowLoc(false)
    elseif cmd == "l" or cmd == "location" then
      self.SetVal_ShowLoc(true)
    elseif cmd == "gfp" then
      self.ToggleLFGP()
    elseif cmd == "gfpm" or cmd == "gfpmode" then
      self.ChangeLFGPMode()
    elseif cmd == "rsi" or cmd == "rescaninv" then
      self:UpdInvtItems(true)
    elseif cmd == "rsb" or cmd == "rescanbank" then
      self:UpdBankItems(true)
    end
  end
  SLASH_COMMANDS["/wpad"] = function(cmd)
    if cmd == "" then
      if self.SV_Debug.IsDebugMode then
        msg("Debug on")
      else
        msg("Debug off")
      end
      local n = #self.SV_Debug.Log
      if n == nil or n == 0 then
        msg("The debug buffer is empty")
      else
        msg("The debug buffer contains entries: " .. n)
      end
    elseif cmd == "on" then
      self.SV_Debug.IsDebugMode = true
      msg("Debug on")
    elseif cmd == "off" then
      self.SV_Debug.IsDebugMode = false
      msg("Debug off")
    elseif cmd == "clr" then
      self.SV_Debug.Log = {}
      msg("The debug buffer is cleared")
    elseif cmd == "ts" or cmd == "timestamp" then
      msg("TimeStamp: " .. GetTimeStamp())
    elseif cmd == "mzi" then
      msg(GetCurrentMapZoneIndex())
    elseif cmd == "loc" then
      msg(GetCurrentMapIndex())
    elseif cmd == "qd" or cmd == "qdump" then
      self:QDump()
    elseif cmd == "qc" or cmd == "qcond" then
      self:QDump(true)
    elseif cmd == "dlc" then
      self:ListDLCID()
    elseif cmd == "csl" then
      self:ListSkillLines(SKILL_TYPE_CLASS, 1)
    elseif cmd == "gsl" then
      self:ListSkillLines(SKILL_TYPE_GUILD, 1)
    elseif cmd == "asl" then
      self:ListSkillLines(SKILL_TYPE_AVA, 1)
    elseif cmd == "wsl" then
      self:ListSkillLines(SKILL_TYPE_WORLD, 1)
    elseif cmd == "chl" or cmd == "charslist" then
      self:ListAllChars()
    elseif cmd == "inv" or cmd == "invlist" then
      self:ListInvtItems(BAG_BACKPACK)
    elseif cmd == "invf" or cmd == "invlistfull" then
      self:ListInvtItems(BAG_BACKPACK, nil, 1)
    elseif string.sub(cmd, 1, 4) == "inv " then
      self:ListInvtItems(BAG_BACKPACK,tonumber(string.sub(cmd, 4)))
    elseif string.sub(cmd, 1, 5) == "invf " then
      self:ListInvtItems(BAG_BACKPACK,tonumber(string.sub(cmd, 5)), 1)
    elseif cmd == "bnk" or cmd == "banklist" then
      self:ListInvtItems({BAG_BANK,BAG_SUBSCRIBER_BANK})
    elseif cmd == "bnkf" or cmd == "banklistfull" then
      self:ListInvtItems({BAG_BANK,BAG_SUBSCRIBER_BANK}, nil, 1)
    elseif string.sub(cmd, 1, 4) == "bnk " then
      self:ListInvtItems({BAG_BANK,BAG_SUBSCRIBER_BANK},tonumber(string.sub(cmd, 4)))
    elseif string.sub(cmd, 1, 5) == "bnkf " then
      self:ListInvtItems({BAG_BANK,BAG_SUBSCRIBER_BANK},tonumber(string.sub(cmd, 5)), 1)
    elseif cmd == "rch" or cmd == "resetchars" then
      self.DoResetCharacters()
    elseif cmd == "scrsh" or cmd == "screenshot" then
      self.ScreenShotMode = not self.ScreenShotMode
      self:UpdWindowInfo()
      self.ShowUI()
    elseif cmd == "red" or cmd == "resetED" then
      self.CurChar.EndlessDungeons = nil
      ReloadUI()
    elseif cmd == "rcpb" or cmd == "bluepr" then
      self:ShowRecipeData()
    elseif cmd == "favors" then
      local favors = self.CurChar.Favors
      msg("Favors Status")
      for j = 1, #self.Favors.QuestIDs do
        local name = GetMailListName(j)
        msg(zo_strformat("<<1>>: <<2>> / <<3>>", name, favors[j].Unlock or "none", favors[j].Total or "none"))
      end
    ---
    end
  end
  SLASH_COMMANDS["/rgla"] = function(cmd)
    if cmd == "" then
      self.TogleRGLA()
    elseif cmd == "on" or cmd == "show" then
      self.ShowRGLA()
    elseif cmd == "off" or cmd == "hide" then
      self.HideRGLA()
    elseif cmd == "s" or cmd == "start" then
      self.OnRGLAStartClick()
    elseif cmd == "t" or cmd == "stop" then
      self.OnRGLAStopClick()
    elseif cmd == "p" or cmd == "post" then
      self.OnRGLAMsgClick(1)
    end
  end
  if self.InitAddModules then self:InitAddModules() end
  EVENT_MANAGER:RegisterForEvent(WPamA.Name .. "AddInit", EVENT_PLAYER_ACTIVATED, WPamA.OnAddInitialize)
end
--
-- Section 7: Event function
-- Function header in this section must use "." instead ":".
-- Also inside the function can not be used "self".
-- Instead, it must explicitly specify the variable
--
-- SubSection 7.1: LFGP functions
--
local function IsGroupRoleSelected()
  local R = GetSelectedLFGRole()
  return (R == LFG_ROLE_DPS) or (R == LFG_ROLE_HEAL) or (R == LFG_ROLE_TANK) or false
end

function WPamA.SetVal_AllowLFGP(value)
  WPamA.SV_Main.AllowLFGP = value
  local m = WPamA.SV_Main.ShowMode
  if m == 0 then WPamA:UpdWindowInfo() end
end

function WPamA.SetVal_ModeLFGPRoulette(value)
  WPamA.SV_Main.ModeLFGPRoulette = value
  local m = WPamA.SV_Main.ShowMode
  if m == 0 then WPamA:UpdWindowInfo() end
end

function WPamA.GetVal_ModeLFGP()
  local f = WPamA.SV_Main.ModeLFGP or 1
  local l = WPamA.i18n.OptLFGPModeList
  return l[f]
end

function WPamA.SetVal_ModeLFGP(value)
  local n, l, v = 1, WPamA.i18n.OptLFGPModeList, WPamA.SV_Main
  for i = 1, #l do
    if l[i] == value then
      n = i
      break
    end
  end
  v.ModeLFGP = n
  if v.ShowMode == 0 then WPamA:UpdWindowInfo() end
end

function WPamA.ChangeLFGPMode()
  local SV = WPamA.SV_Main
  if not SV.AllowLFGP then return end -- LFGP is disabled
  if SV.ShowMode ~= 0 then return end -- no Pledge tab = no change LFGP mode
  --
  local maxModes = #WPamA.i18n.OptLFGPModeList - 1
  local isVeteran = WPamA.CurChar.Veteran or false
  if SV.ModeLFGP == 5 then -- character-wide LFGP mode
    local CurChar = WPamA.CurChar
    CurChar.CharModeLFGP = isVeteran and (CurChar.CharModeLFGP + 1) or 1 -- always NNN for non-Veteran char
    if CurChar.CharModeLFGP > maxModes then CurChar.CharModeLFGP = 1 end
  else -- account-wide LFGP mode
    SV.ModeLFGP = isVeteran and (SV.ModeLFGP + 1) or 1 -- always NNN for non-Veteran char
    if SV.ModeLFGP > maxModes then SV.ModeLFGP = 1 end
  end
  WPamA:UpdWindowInfo()
end

function WPamA.LFGP_Message(txt)
  local SV = WPamA.SV_Main
  local csaParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT)
  if SV.LFGPAlert then
    csaParams:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_DISPLAY_ANNOUNCEMENT)
    csaParams:SetText( txt )
    CENTER_SCREEN_ANNOUNCE:AddMessageWithParams( csaParams )
  end
  if SV.LFGPChat then
    msg(txt)
  end
end

function WPamA.ToggleLFGP()
  local SV = WPamA.SV_Main
  local Lang = WPamA.i18n
  if not SV.AllowLFGP then return end
    -- Character must be solo or a group Leader
  if not IsUnitSoloOrGroupLeader("player") then
    WPamA.LFGP_Message(Lang.LFGP_ErrLeader)
    return 
  end
    -- Character must be in Overland world
--[[
  if IsUnitInDungeon("player") then
    WPamA.LFGP_Message(Lang.LFGP_ErrOverland)
    return 
  end
--]]
    -- Character must have a group role
  if not IsGroupRoleSelected() then
    WPamA.LFGP_Message(Lang.LFGP_ErrGroupRole)
    return 
  end
    -- Stop searching if character already in LFG queue
  local LFGstatus = GetActivityFinderStatus()
  if LFGstatus == ACTIVITY_FINDER_STATUS_QUEUED then
    CancelGroupSearches()
    WPamA.LFGP_Message(Lang.LFGPSrchCanceled)
    return
  elseif (LFGstatus ~= ACTIVITY_FINDER_STATUS_NONE) and
         (LFGstatus ~= ACTIVITY_FINDER_STATUS_COMPLETE) then
    WPamA.LFGP_Message(Lang.LFGPAlrdyStarted)
    return
  end
  local CurChar = WPamA.CurChar
  local SVM = WPamA.SV_Main.ModeLFGP
  local QStat = WPamA.Consts.QuestStatus
  local activityType = LFG_ACTIVITY_DUNGEON
  local CurModeLFGP = SVM
  if SVM == 5 then CurModeLFGP = CurChar.CharModeLFGP end
  ClearActivityFinderSearch()
  for ii = 1, #WPamA.GroupDungeons.OrdPledges do
    local PlNum = CurChar.Pledges[ii].Num
    local PlAct = CurChar.Pledges[ii].Act
    local lfgIndex, isDungIgnored = nil, false -- it must be here
    if PlAct == QStat.Completed then PlNum = 1 end
    if PlNum > 2 then
      local CurDung = WPamA.GroupDungeons.Dungeons[PlNum]
      if CurModeLFGP == 1 then -- 3 keys
        activityType = LFG_ACTIVITY_DUNGEON
        lfgIndex = CurDung.LfgN
      elseif CurModeLFGP == 2 then -- 4 keys
        activityType = LFG_ACTIVITY_MASTER_DUNGEON
        lfgIndex = CurDung.LfgV
        if ii == 3 then isDungIgnored = true end -- ignore Urga's pledge
      elseif CurModeLFGP == 3 then -- 5 keys
        if ii == 3 then -- set the normal mode for Urga's pledge
          activityType = LFG_ACTIVITY_DUNGEON
          lfgIndex = CurDung.LfgN
        else
          activityType = LFG_ACTIVITY_MASTER_DUNGEON
          lfgIndex = CurDung.LfgV
        end
      elseif CurModeLFGP == 4 then -- 6 keys
        activityType = LFG_ACTIVITY_MASTER_DUNGEON
        lfgIndex = CurDung.LfgV
      end
      local isDungReadyToComplete = PlAct == QStat.Updated
      if SV.LFGPIgnorePledge then isDungReadyToComplete = false end
      if (not CurDung.isLocked) and (not isDungReadyToComplete) and (not isDungIgnored) then
        local activityID = GetActivityIdByTypeAndIndex(activityType, lfgIndex)
        AddActivityFinderSpecificSearchEntry(activityID)
          -- Roulette N or V for outdated Pledge
        if SV.ModeLFGPRoulette and (activityType == LFG_ACTIVITY_MASTER_DUNGEON) and
           ( not WPamA:IsTodayDungNumAndNPC(PlNum, ii) ) then
          activityID = GetActivityIdByTypeAndIndex(LFG_ACTIVITY_DUNGEON, CurDung.LfgN)
          AddActivityFinderSpecificSearchEntry(activityID)
        end
      end
    end
  end
  local SearchResult = StartActivityFinderSearch()
  local SearchStatusText = Lang.LFGPSrchStarted -- status OK by default
  if SearchResult ~= ACTIVITY_QUEUE_RESULT_SUCCESS then -- result is not success
    if SearchResult == ACTIVITY_QUEUE_RESULT_GROUP_TOO_LARGE then
      SearchStatusText = GetString(SI_ACTIVITYQUEUERESULT3)
    elseif SearchResult == ACTIVITY_QUEUE_RESULT_DLC_LOCKED then
      SearchStatusText = GetString(SI_ACTIVITYQUEUERESULT6)
    elseif SearchResult == ACTIVITY_QUEUE_RESULT_INVALID_LEVEL then
      SearchStatusText = GetString(SI_ACTIVITYQUEUERESULT4)
    elseif SearchResult == ACTIVITY_QUEUE_RESULT_MEMBERS_OFFLINE then
      SearchStatusText = GetString(SI_ACTIVITYQUEUERESULT14)
    elseif SearchResult == ACTIVITY_QUEUE_RESULT_NEW_SEARCH_INITIATED then
      SearchStatusText = GetString(SI_ACTIVITYQUEUERESULT21)
    elseif SearchResult == ACTIVITY_QUEUE_RESULT_NO_ACTIVITIES_SELECTED then
      SearchStatusText = GetString(SI_ACTIVITYQUEUERESULT8)
    elseif SearchResult == ACTIVITY_QUEUE_RESULT_INCOMPATIBLE_GROUP then
      SearchStatusText = GetString(SI_ACTIVITYQUEUERESULT9)
    elseif SearchResult == ACTIVITY_QUEUE_RESULT_NO_ROLES_SELECTED then
      SearchStatusText = GetString(SI_ACTIVITYQUEUERESULT1)
    elseif SearchResult == ACTIVITY_QUEUE_RESULT_ON_QUEUE_COOLDOWN then
      SearchStatusText = GetString(SI_ACTIVITYQUEUERESULT12)
    else
      SearchStatusText = Lang.LFGPQueueFailed -- status FAIL by default
    end
  end -- if search result is not success
  WPamA.LFGP_Message(SearchStatusText)
end -- ToggleLFGP end
--
-- SubSection 7.2: Main window functions
--
function WPamA.OnLevelUpdate(_eventCode, _unitTag, _level)
--  if _unitTag = "player" then
  local v = WPamA.CurChar
  local bakVet = v.Veteran
  local bakLvl = v.Lvl
  WPamA:UpdPlayerLvl()
  if bakVet ~= v.Veteran or bakLvl ~= v.Lvl then
    WPamA:UpdWindowInfo()
  end
--  end
end

local function ToggleMouseForScene(scene)
  if scene then
    if SCENE_MANAGER:IsShowing(scene) then SCENE_MANAGER:OnToggleHUDUIBinding() end
  end
end

function WPamA.ShowUI()
  local SVM = WPamA.SV_Main
  local m = SVM.ShowMode
  if (m == 6) or (m == 7) then
    WPamA:UpdWindowInfo()
  end
  WPamA_Win:SetHidden(false)
  SVM.WinMain.s = true
  if WPamA.ShowMsg and WPamA_Msg ~= nil then
    WPamA_Msg:SetHidden(false)
  end
  if SVM.ShowMouseMode and (not IsUnitInCombat("player")) then ToggleMouseForScene("hud") end
end 

function WPamA.HideUI()
  local SVM = WPamA.SV_Main
  WPamA_Win:SetHidden(true)
  SVM.WinMain.s = false
  if WPamA_Msg ~= nil then
    WPamA_Msg:SetHidden(true)
  end
  if WPamA_SelWind ~= nil then
    WPamA_SelWind:SetHidden(true)
  end
  if SVM.ShowMouseMode then ToggleMouseForScene("hudui") end
end 

function WPamA.TogleUI()
  if WPamA_Win:IsHidden() then
    WPamA.ShowUI()
  else
    WPamA.HideUI()
  end
end 

function WPamA.OnWindowMoveStop()
  WPamA:SavePosition(WPamA_Win, WPamA.SV_Main.WinMain)
end 

function WPamA.ChangeUIWin(Win)
  if Win == nil then
    WPamA:SetMode(WPamA:NextWin(), false)
  else
    WPamA:SetMode(WPamA:WinFirstVisible(Win), false)
  end
end 

function WPamA.ChangeUITab()
  WPamA:SetMode(WPamA:NextTab(), false)
end 

function WPamA.ChangeUIMode(Mode)
  if Mode == nil then
    WPamA:SetMode(WPamA:NextWin(), false)
  elseif WPamA.ModeSettings[Mode] then
    WPamA:SetMode(Mode, true)
  end
end 

function WPamA.ChangeUIModeAlt()
  WPamA:SetMode(WPamA:NextMode(), false)
end 

function WPamA.GetFirstEnabledMode(winIndex, isIgnoreAllDisabled)
  local MV, WS = WPamA.SV_Main.isModeVisible, WPamA.WindSettings
  if WS[winIndex] and WS[winIndex].Mds then
    local MDS = WS[winIndex].Mds
    -- Find the number of the first enabled mode in window
    for i = 1, #MDS do
      if MV[ MDS[i] ] then return MDS[i] end
    end
    -- when all modes in window are disabled, send the first mode number or nil
    if isIgnoreAllDisabled then return MDS[1] end
  end
  return nil
end -- GetFirstEnabledMode end

function WPamA.GetCustomModeIndex(keybindIndex)
  if not WPamA.SV_Main.CustomModeKeybinds[keybindIndex] then
    WPamA.SV_Main.CustomModeKeybinds[keybindIndex] = 1
  end
  return WPamA.SV_Main.CustomModeKeybinds[keybindIndex] - 2
end -- GetCustomModeIndex end

-- Named functions for call from others addons
function WPamA.ChangeUIModeChar()  WPamA.ChangeUIMode(0) end
function WPamA.ChangeUIModeClnd()  WPamA.ChangeUIMode(1) end
function WPamA.ChangeUIModeWB()    WPamA.ChangeUIMode(2) end
function WPamA.ChangeUIModeInvt()  WPamA.ChangeUIMode(3) end
function WPamA.ChangeUIModeSkls()  WPamA.ChangeUIMode(4) end
function WPamA.ChangeUIModeTrial() WPamA.ChangeUIMode(6) end 
function WPamA.ChangeUIModeRndD()  WPamA.ChangeUIMode(7) end

function WPamA.SwapWindowMode(ctrl, button)
  if button == 1 then
    WPamA:SetMode(WPamA:NextWin(), false)
  elseif button == 2 then
    if WPamA_SelWind:IsHidden() then
       WPamA:UI_SelWindUpdColor()
       WPamA_SelWind:SetHidden(false)
    else
      WPamA_SelWind:SetHidden(true)
    end
  end
end

function WPamA.OnSelWindClick(var)
  WPamA:SetMode(WPamA:WinFirstVisible(var), false)
end

function WPamA.SelWindTxtColor(ctrl, num, isHighlighted)
  local MSc = WPamA.ModeSettings[WPamA.SV_Main.ShowMode]
  local clr = WPamA.Colors
  local cl = clr.MenuEnabled
  if isHighlighted then
    cl = clr.MenuHighlighted
  elseif MSc.WinInd == num then
    cl = clr.MenuActive
  end
  ctrl:SetColor(WPamA:GetColor(cl))
end

function WPamA.OnSelTabClick(var)
  local MSc = WPamA.ModeSettings[WPamA.SV_Main.ShowMode]
  local WSm = WPamA.WindSettings[MSc.WinInd].Mds
  if WSm[var] ~= nil then
    WPamA:SetMode(WSm[var], false)
  end
end

function WPamA.SelTabTxtColor(ctrl, num, isHighlighted)
  local clr = WPamA.Colors
  local SV  = WPamA.SV_Main
  local MS  = WPamA.ModeSettings
  local MSc = MS[SV.ShowMode]
  local WSm = WPamA.WindSettings[MSc.WinInd].Mds

  local cl  = clr.TabDisabled
  if isHighlighted then
    cl = clr.TabHighlighted
  elseif num == MSc.TabInd then
    cl = clr.TabActive
  elseif WSm[num] ~= nil and SV.isModeVisible[WSm[num]] then
    cl = clr.TabEnabled
  end
  ctrl:SetColor(WPamA:GetColor(cl))
end

-- SubSection 7.3: RGLA functions
--
function WPamA.OnWinRGLAMoveStop()
  WPamA:SavePosition(WPamA_RGLA, WPamA.SV_Main.WinRGLA)
end 

function WPamA.ShowRGLA()
  WPamA:UpdRGLAInfo()
  WPamA_RGLA:SetHidden(false)
end 

function WPamA.HideRGLA()
  WPamA_RGLA:SetHidden(true)
  WPamA_RGLA_Msg:SetHidden(true)
end 

function WPamA.TogleRGLA()
  if WPamA_RGLA:IsHidden() then
    WPamA.ShowRGLA()
  else
    WPamA.HideRGLA()
  end
end 

function WPamA.OnRGLAStartClick()
  if not WPamA.RGLA_Started then
    WPamA.RGLA_Started = WPamA:TryRGLAStart()
    WPamA:UpdRGLAInfo()
  end
end 

function WPamA.OnRGLAMsgClick(var)
  if var >= 7 or WPamA.RGLA_Started or (var == 6 and WPamA:GetCurrentDBoss() ~= 0 and WPamA:IsRGLALocation()) then
    WPamA:PostToChatRGLA(var)
    WPamA_RGLA_Msg:SetHidden(true)
  end
end

function WPamA.OnRGLAStopClick()
  if WPamA.RGLA_Started then
    WPamA:RGLAStop()
  end
end 

function WPamA.OnGroupMemberJoined()
  if WPamA.RGLA_Started and WPamA.RGLA_QuestJI ~= nil and WPamA.RGLA_QuestJI > 0 and WPamA.SV_Main.AutoShare then
    WPamA:ShareQuest(WPamA.RGLA_QuestJI)
  end
end

function WPamA.OnRGLAShareClick()
  local ji = WPamA:GetDWBJournalIndex(WPamA:GetCurrentDBoss())
  if ji == 0 then
    local l = WPamA.i18n
    msg(l.RGLA_ErrQuestBeg .. l.RGLA_Loc[WPamA.RGLA_Mode] .. l.RGLA_ErrQuestEnd)
  elseif IsUnitGrouped("player") then
    WPamA:ShareQuest(ji)
  end
end 

function WPamA.RGLAMsgTxtColor(ctrl, num, isHighlighted)
  local clr = WPamA.Colors
  local cl = clr.MenuEnabled
  if num >= 7 then
    if isHighlighted then cl = clr.MenuActive end
  elseif num == 6 then
    if WPamA:GetCurrentDBoss() == 0 or not WPamA:IsRGLALocation() then
      cl = clr.MenuDisabled
    elseif isHighlighted then
      cl = clr.MenuActive 
    end
  else
    if not WPamA.RGLA_Started then
      cl = clr.MenuDisabled
    elseif isHighlighted then
      cl = clr.MenuActive 
    end
  end
  ctrl:SetColor(WPamA:GetColor(cl))
end

function WPamA.OnRGLASelectMsgClick()
  if WPamA_RGLA_Msg:IsHidden() then
    local hld = WPamA.SV_Main.WinRGLA
    if hld ~= nil and hld.m ~= nil then
      WPamA_RGLA_Msg:ClearAnchors()
      if hld.m == 3 or hld.m == 4 then
        WPamA_RGLA_Msg:SetAnchor(BOTTOMLEFT, WPamA_RGLAPost, BOTTOMRIGHT, 0, -4)
      else
        WPamA_RGLA_Msg:SetAnchor(TOPLEFT, WPamA_RGLAPost, TOPRIGHT, 0, 0)
      end
    end
    for j=1,WPamA.Consts.RGLAMsgCnt do
      WPamA.RGLAMsgTxtColor(GetControl(WPamA_RGLA_Msg, "Txt" .. j), j, false)
    end
    WPamA_RGLA_Msg:SetHidden(false)
  else
    WPamA_RGLA_Msg:SetHidden(true)
  end
end

function WPamA.OnUnitLeaderUpdate(eventCode, unitTag)
  if WPamA.RGLA_Started and IsUnitGrouped("player") and not IsUnitGroupLeader("player") then
    msg(WPamA.i18n.RGLALeaderChanged)
    WPamA:RGLAStop()
  end
end
--
-- SubSection 7.4: Chat functions
--
function WPamA.CheckChatMsg(txt, sarr)
  txt = txt:gsub(" ","") -- Del all space
  for i=1, #sarr do
    if txt:match(sarr[i]) then return true end
  end
  return false
end

function WPamA:CheckShareSubstr(txt)
  local ssb = self.i18n.ShareSubstr
  if type(ssb) == "table" then
    for _, v in pairs(ssb) do
      if txt:match(v) then
        return true
      end
    end
  else
    return txt:match(ssb)
  end
  return false
end

function WPamA.OnChatMessage(eventCode, channelType, fromName, messageText, isCustomerService)
-- channelType: 0-say, 2-whisper, 3-party, 31-zone
  local txt = messageText:lower()
  local nam = fromName:gsub("%^.+", "")  -- "PlayerName^Mx" -> "PlayerName"
  if nam ~= WPamA.CharName then
    if channelType == 3 then
      if WPamA:CheckShareSubstr(txt) then
        WPamA.OnGroupMemberJoined()
      end
    elseif nam ~= nil and nam ~= "" then
      local n = WPamA.CurChar.DBossLoc[WPamA.RGLA_Mode]
      local b = WPamA.WorldBosses.Bosses[n]
      -- Case when txt == b.S[1] will be processed inside the AutoInvite
      if txt ~= b.S[1] and WPamA.CheckChatMsg(txt, b.S) then
        if (channelType >= CHAT_CHANNEL_GUILD_1 and channelType <= CHAT_CHANNEL_OFFICER_5) or channelType == CHAT_CHANNEL_WHISPER then
          nam = AutoInvite.accountNameLookup(channelType, fromName)
          if nam == nil or nam == "" then return end
          nam = nam:gsub("%^.+", "")
          if nam == nil or nam == "" then return end
        end
        msg(zo_strformat(WPamA.i18n.SendInvTo, nam))
        AutoInvite:invitePlayer(nam)
      end
    end
  end
end

function WPamA.KeyPostChatTd(isEN)
  WPamA:PostPledgeToChat(isEN)
end 

function WPamA.MousePostChatTd(ctrl, button)
  if button == 1 then
    WPamA:PostPledgeToChat(true)
  elseif button == 2 then
    WPamA:PostPledgeToChat(false)
  end
end 

function WPamA.MouseLFGP(ctrl, button)
  if button == 1 then
    WPamA.ToggleLFGP()
  elseif button == 2 then
    WPamA.ChangeLFGPMode()
  end
end 
--
-- SubSection 7.5: Quests functions
--
function WPamA.OnQuestAdded(eventCode, journalIndex, questName, objectiveName) -- , questId)
--EVENT_QUEST_ADDED (integer eventCode, integer journalIndex, string questName, string objectiveName)
  --local _, _, _, _, activeStep, _, _, _, _, questType = GetJournalQuestInfo(journalIndex)
  --local questType = GetJournalQuestType(journalIndex)
  --local questId   = GetJournalQuestId(journalIndex)
  --local isRepeat  = GetJournalQuestRepeatType(journalIndex)
  --WPamA:Debug("AddQ > QN: " .. questName .. "; JI: " .. journalIndex .. "; QT: " .. questType .. "; IR: " .. isRepeat .. "; AS: " .. activeStep .. "; EC: " .. eventCode)
  --WPamA:Debug("AddQ > ID: " .. nvl(questId) .. ", TS:" .. GetTimeStamp())
  ------------
  if WPamA.DailyWrits.Iterators.N[questName] then -- daily writs
    WPamA:UpdWritDailyQuests(questName, WPamA.Consts.WritUpdated)
    WPamA:UpdWindowInfo()
  ------------
  elseif WPamA.GroupDungeons.Iterators.N[questName] then -- undaunted daily
    WPamA:UpdPledgeQuestStatus(questName, WPamA.Consts.QuestStatus.Started, "")
    WPamA:UpdWindowInfo()
  ------------
  elseif WPamA.TrialDungeons.Iterators.N[questName] then -- Trials
    WPamA:ChkAddTrialsQuests(questName)
    WPamA:UpdWindowInfo()
  ------------
  elseif WPamA.WorldBosses.Iterators.N[questName] then -- World Bosses daily
    WPamA:ChkAddBossDailyQuests(questName)
    WPamA:UpdWindowInfo()
  ------------
--[[
  elseif isRepeat == QUEST_REPEAT_DAILY then
    if questType == QUEST_TYPE_GROUP then -- any other group quest
     -- ...........
    end
--]]
  ------------
  end
end -- OnQuestAdded end

function WPamA.OnQuestRemoved(eventCode, isCompleted, journalIndex, questName, zoneIndex, poiIndex, questId)
--EVENT_QUEST_REMOVED (integer eventCode, bool isCompleted, luaindex journalIndex, string questName,
--                     luaindex zoneIndex, luaindex poiIndex, integer questID)
  ------------
--[[
  local questType = GetJournalQuestType(journalIndex)
  local isRepeat = GetJournalQuestRepeatType(journalIndex)
  d("QID [" .. nvl(questId) .. "] QName [" .. questName .. "] QType " .. questType ..
    " Rpt " .. isRepeat .. " Done " .. BoolToStr(isCompleted) )
  --WPamA:Debug("RemQ > QN: " .. nvl(questName) .. "; JI: " .. nvl(journalIndex) .. "; QT: " .. nvl(questType) .. "; IR: " .. nvl(isRepeat) .. "; Done: " .. BoolToStr(isCompleted) .. "; EC: " .. nvl(eventCode))
  --WPamA:Debug("RemQ > ID: " .. nvl(questId) .. ", TS:" .. GetTimeStamp())
--]]
  ------------
  if not WPamA.Today.DayEnd then WPamA:UpdToday() end
  ------------
  if WPamA.DailyWrits.Iterators.N[questName] then -- daily writs
    if isCompleted then
      WPamA:UpdWritDailyQuests(questName, WPamA.Consts.WritCompleted)
    else
      WPamA:UpdWritDailyQuests(questName, WPamA.Consts.WritRemoved)
    end
  ------------
  elseif WPamA.CraftCerts.Iterators.N[questName] then -- crafting profession Certification
    WPamA:InitSkillLines()
  ------------
  elseif WPamA.Companions.Iterators.N[questName] then -- companion's Intro quest
    if isCompleted then
      local ccid = WPamA.Companions.Iterators.N[questName]
      WPamA.CurChar.Companions[ccid].hasQuest = false
    end
  ------------
  elseif WPamA.Companions.Iterators.SQ[questName] then -- companion's Story quest
    if isCompleted then
      local ccid = WPamA.Companions.Iterators.SQ[questName]
      WPamA:UpdateCompanionStoryQuests(ccid)
    end
  ------------
  elseif WPamA.GroupDungeons.Iterators.N[questName] then -- undaunted dailies
    if isCompleted then -- quest Completed
      WPamA:UpdPledgeQuestStatus(questName, WPamA.Consts.QuestStatus.Completed, "")
    else -- quest Removed or Reseted
      WPamA:UpdPledgeQuestStatus(questName, WPamA.Consts.QuestStatus.Removed, "")
    end
  ------------
  elseif WPamA.GroupDungeons.Iterators.QN[questName] then -- 4-ppl dungeon Store quest
    if isCompleted then
      local di = WPamA.GroupDungeons.Iterators.QN[questName]
      WPamA.CurChar.GroupDungeons[di].hasQuest = false
    end
  ------------
  elseif WPamA.TrialDungeons.Iterators.N[questName] then -- Trials
    WPamA:StartCheckTrialLoot(questId)
  ------------
  elseif WPamA.EndlessDungeons.Iterators.N[questName] then -- Endless Dungeons dailies
    if isCompleted then
      local di = WPamA.EndlessDungeons.Iterators.N[questName]
      WPamA.CurChar.EndlessDungeons[di].EndTS = GetTimeStamp()
    end
  ------------
  elseif WPamA.EndlessDungeons.Iterators.IQ[questId] then -- Endless Dungeons Intro quest
    if isCompleted then
      local di = WPamA.EndlessDungeons.Iterators.IQ[questId]
      WPamA.CurChar.EndlessDungeons[di].EndTS = 0
    end
  ------------
  elseif WPamA.Favors.Iterators.Q[questId] then -- daily Favors
    if isCompleted then
      WPamA:UpdFavorsCount()
    end
  ------------
  elseif ZO_IsElementInNumericallyIndexedTable(WPamA.AvA.BattleGrounds.DailyQuestIDs, questId) then -- BattleGrounds dailies
    if isCompleted then
      local TS = GetTimeStamp()
      local SV = WPamA.SV_Main
      if not SV.AvADailyRewards[4]  then SV.AvADailyRewards[4] = 0 end
      if SV.AvADailyRewards[4] < TS then SV.AvADailyRewards[4] = WPamA:GetNextDailyResetTS() end
    end
  ------------
--  else
  end
  WPamA:CloseQuest(isCompleted, questName)
  WPamA:FindUpdateQuests()
  WPamA:UpdWindowInfo()
end -- OnQuestRemoved end

function WPamA.OnQuestAdvanced(eventCode, journalIndex, questName, ... )
--EVENT_QUEST_ADVANCED (integer eventCode, luaindex journalIndex, string questName,
--                      bool isPushed, bool isComplete, bool mainStepChanged, bool hideAnnouncement)
  ------------
--[[
  local _, _, _, _, activeStep, _, _, _, _, questType = GetJournalQuestInfo(journalIndex)
  local isRepeat = GetJournalQuestRepeatType(journalIndex)
  local questId  = GetJournalQuestId(journalIndex)
  WPamA:Debug("AdvQ > QN: " .. questName .. "; JI: " .. journalIndex .. "; QT: " .. questType .. "; IR: " .. isRepeat .. "; AS: " .. activeStep .. "; EC: " .. eventCode)
  WPamA:Debug("AdvQ > ID: " .. nvl(questId) .. ", TS:" .. GetTimeStamp())
--]]
  ------------
  if WPamA.GroupDungeons.Iterators.N[questName] then -- undaunted dailies
    local activeStep = select( 5, GetJournalQuestInfo(journalIndex) )
    WPamA:UpdPledgeQuestStatus(questName, WPamA.Consts.QuestStatus.Updated, activeStep)
    WPamA:UpdWindowInfo()
  end
end -- OnQuestAdvanced end

--[[ --??
function WPamA.OnQCondChanged(eventCode, journalIndex, questName, conditionText, conditionType, currConditionVal, newConditionVal, conditionMax, isFailCondition, stepOverrideText, isPushed, isComplete, isConditionComplete, isStepHidden)
  if WPamA.SV_Main.BossKilled and journalIndex == WPamA.RGLA_QuestJI then -- this quest from RGLA
    if isConditionComplete and (not isStepHidden) and (conditionMax == 1) then
      msg(WPamA.i18n.RGLABossKilled)
      WPamA:RGLAStop()
    end
  end
end
--]]

function WPamA.OnQCondChanged(eventCode, journalIndex, questName, conditionText, conditionType, currConditionVal, newConditionVal, conditionMax, isFailCondition, stepOverrideText, isPushed, isComplete, isConditionComplete, isStepHidden)
  local DBoss = WPamA.i18n.DailyBoss
  local DBInd = WPamA.CurChar.DBossLoc[WPamA.RGLA_Mode]
  if WPamA.SV_Main.BossKilled and (journalIndex == WPamA.RGLA_QuestJI) then -- this quest from RGLA
    if isConditionComplete and (conditionText == DBoss[DBInd].C) then
      msg(WPamA.i18n.RGLABossKilled)
      WPamA:RGLAStop()
    end
  end
end
--
-- SubSection 7.6: Addon settings functions
--
function WPamA.DoResetCharacters()
  WPamA.SV_Main.CharsList = {}
  WPamA:InitCharsList(WPamA.SV_Main)
  WPamA:UpdCharInfo()
  WPamA:InitSkillLines()
  WPamA:SetLFGRewardTime(LFG_ACTIVITY_INVALID) -- all activity types
end

function WPamA.GetVal_CharsOrder()
  local v = WPamA.SV_Main.CharsOrder or 1
  local l  = WPamA.i18n.CharsOrderList
  return l[v]
end

function WPamA.SetVal_CharsOrder(value)
  local n = 1
  local l = WPamA.i18n.CharsOrderList
  for i = 1, #l do
    if l[i] == value then
      n = i
      break
    end
  end
  if WPamA.SV_Main.CharsOrder ~= n then
    WPamA.SV_Main.CharsOrder = n
  end
end

function WPamA.SetVal_AlwaysMaxWinX(value)
  if WPamA.SV_Main.AlwaysMaxWinX ~= value then
    WPamA.SV_Main.AlwaysMaxWinX = value
    WPamA:UpdWindowInfo(true)
  end
end

function WPamA.SetVal_LargeCalend(value)
  if WPamA.SV_Main.LargeCalend ~= value then
    WPamA.SV_Main.LargeCalend = value
    if WPamA.SV_Main.ShowMode == 1 then WPamA:UpdWindowInfo(true) end
  end
end

function WPamA.SetVal_HintUncompletedPledges(value)
  if WPamA.SV_Main.HintUncompletedPledges ~= value then
    WPamA.SV_Main.HintUncompletedPledges = value
    if WPamA.SV_Main.ShowMode == 0 then WPamA:UpdWindowInfo(true) end
  end
end

function WPamA.SetVal_ShowLoc(value)
  if WPamA.SV_Main.ShowLoc ~= value then
    WPamA.SV_Main.ShowLoc = value
    local m = WPamA.ModeSettings[WPamA.SV_Main.ShowMode]
    if m.UpdV_ShowLoc ~= nil then
      WPamA:UpdWindowInfo(m.UpdV_ShowLoc)
    end 
  end
end

function WPamA.SetVal_ENDung(value)
  if WPamA.SV_Main.ENDung ~= value then
    WPamA.SV_Main.ENDung = value
    local m = WPamA.ModeSettings[WPamA.SV_Main.ShowMode]
    if m.UpdV_ENDung ~= nil then
      WPamA:UpdWindowInfo(m.UpdV_ENDung)
    end 
  end
end

function WPamA.SetVal_DontShowNone(value)
  if WPamA.SV_Main.DontShowNone ~= value then
    WPamA.SV_Main.DontShowNone = value
    local m = WPamA.ModeSettings[WPamA.SV_Main.ShowMode]
    if m.UpdV_DontShowNone ~= nil then
      WPamA:UpdWindowInfo(m.UpdV_DontShowNone)
    end 
  end
end

function WPamA.SetVal_TitleToolTip(value)
  if WPamA.SV_Main.TitleToolTip ~= value then
    WPamA.SV_Main.TitleToolTip = value
    local m = WPamA.ModeSettings[WPamA.SV_Main.ShowMode]
    if m.UpdV_TitleToolTip ~= nil then
      WPamA:UpdWindowInfo(m.UpdV_TitleToolTip)
    end 
  end
end

function WPamA.SetVal_ShowMonsterSet(value)
  if WPamA.SV_Main.ShowMonsterSet ~= value then
    WPamA.SV_Main.ShowMonsterSet = value
    local m = WPamA.ModeSettings[WPamA.SV_Main.ShowMode]
    if m.UpdV_ShowMonsterSet ~= nil then
      WPamA:UpdWindowInfo(m.UpdV_ShowMonsterSet)
    end 
  end
end

function WPamA.GetVal_DateFrmt()
  local df = WPamA.SV_Main.DateFrmt or WPamA.i18n.DateFrmt or 1
  local l  = WPamA.i18n.DateFrmtList
  return l[df]
end

function WPamA.SetVal_DateFrmt(value)
  local n = WPamA.i18n.DateFrmt
  local l = WPamA.i18n.DateFrmtList
  for i = 1, #l do
    if l[i] == value then
      n = i
      break
    end
  end
  if WPamA.SV_Main.DateFrmt ~= n then
    WPamA.SV_Main.DateFrmt = n
    local m = WPamA.ModeSettings[WPamA.SV_Main.ShowMode]
    if m.UpdV_DateTime ~= nil then
      WPamA:UpdWindowInfo(m.UpdV_DateTime)
    end 
  end
end

function WPamA.SetVal_ShowTime(value)
  if WPamA.SV_Main.ShowTime ~= value then
    WPamA.SV_Main.ShowTime = value
    local m = WPamA.ModeSettings[WPamA.SV_Main.ShowMode]
    if m.UpdV_DateTime ~= nil then
      WPamA:UpdWindowInfo(m.UpdV_DateTime)
    end 
  end
end

function WPamA.SetVal_CharVisible(num, value)
  local c = WPamA.SV_Main.CharsList[num]
  if c.isVisible ~= value then
    c.isVisible = value
    local m = WPamA.ModeSettings[WPamA.SV_Main.ShowMode]
    if m.UpdV_CharVisible ~= nil then
      WPamA:UpdWindowInfo(m.UpdV_CharVisible)
    end 
  end
end

function WPamA.SetVal_ModeVisible(num, value)
  WPamA.SV_Main.isModeVisible[num] = value 
  WPamA:UI_UpdMainWindowTabs()
end

function WPamA.SetVal_WindVisible(num, value)
  WPamA.SV_Main.isWindVisible[num] = value 
  WPamA:UI_SelWindUpdColor()
end

function WPamA.GetVal_TrialAvl()
  local f = WPamA.SV_Main.TrialAvlFrmt or 1
  local l  = WPamA.i18n.OptTimerList
  return l[f]
end

function WPamA.SetVal_TrialAvl(value)
  local n, l, v = 1, WPamA.i18n.OptTimerList, WPamA.SV_Main
  for i = 1, #l do
    if l[i] == value then
      n = i
      break
    end
  end
  if v.TrialAvlFrmt ~= n then
    v.TrialAvlFrmt = n
    local m = WPamA.ModeSettings[v.ShowMode]
    if m.UpdV_TrialAvl then WPamA:UpdWindowInfo(m.UpdV_TrialAvl) end
  end
end

function WPamA.SetVal_LFGRndDontShowSt(value)
  local v = WPamA.SV_Main
  if v.LFGRndDontShowSt ~= value then
    v.LFGRndDontShowSt = value
    local m = WPamA.ModeSettings[v.ShowMode]
    if m.UpdV_LFGRndAvl then WPamA:UpdWindowInfo(m.UpdV_LFGRndAvl) end
  end
end

function WPamA.GetVal_LFGRndAvl()
  local f = WPamA.SV_Main.LFGRndAvlFrmt or 1
  local l  = WPamA.i18n.OptTimerList
  return l[f]
end

function WPamA.SetVal_LFGRndAvl(value)
  local n, l, v = 1, WPamA.i18n.OptTimerList, WPamA.SV_Main
  for i = 1, #l do
    if l[i] == value then
      n = i
      break
    end
  end
  if v.LFGRndAvlFrmt ~= n then
    v.LFGRndAvlFrmt = n
    local m = WPamA.ModeSettings[v.ShowMode]
    if m.UpdV_LFGRndAvl ~= nil then
      WPamA:UpdWindowInfo(m.UpdV_LFGRndAvl)
    end 
  end
end

function WPamA.SetVal_CharNamesInColors(value)
  WPamA.SV_Main.CharNamesInColors = value
  WPamA:UpdWindowInfo(true)
end

function WPamA.SetVal_CharNamesAlignment(value)
  WPamA.SV_Main.CharNamesAlignment = value
  WPamA:UpdWindowInfo(true)
end

function WPamA.SetVal_CharNamesCorrMode(value)
  WPamA.SV_Main.CharNamesCorrMode = value
  WPamA:UpdWindowInfo(true)
end

function WPamA.SetVal_CharNamesMaskFrom(value)
  WPamA.SV_Main.CharNamesMaskFrom = value
  WPamA:UpdWindowInfo(true)
end

function WPamA.SetVal_CharNamesMaskTo(value)
  WPamA.SV_Main.CharNamesMaskTo = value
  WPamA:UpdWindowInfo(true)
end

function WPamA.SetVal_CurrencyValueThreshold(value)
  WPamA.SV_Main.CurrencyValueThreshold = value
  WPamA:UpdWindowInfo(true)
end

function WPamA.SetVal_CompanionRapportMode(value)
  WPamA.SV_Main.CompanionRapportMode = value
  WPamA:UpdWindowInfo(true)
end

function WPamA.SetVal_CompanionRapportShowMax(value)
  WPamA.SV_Main.CompanionRapportShowMax = value
  WPamA:UpdWindowInfo(true)
end

function WPamA.SetVal_CompanionEquipMode(value)
  WPamA.SV_Main.CompanionEquipMode = value
  WPamA:UpdWindowInfo(true)
end

function WPamA.SetVal_EndeavorRewardMode(value)
  WPamA.SV_Main.EndeavorRewardMode = value
  WPamA:EndeavorDataUpdate()
  WPamA:UpdWindowInfo(true)
end

function WPamA.SetVal_EndeavorHideCompleted(value)
  WPamA.SV_Main.EndeavorHideCompleted = value
  WPamA:EndeavorDataUpdate()
  WPamA:UpdWindowInfo(true)
end
--
-- SubSection 7.7: Festivals functions
--
function WPamA:SetFestivalsTitles()
  local fai = WPamA.Festivals.AchievementsIDs
  local ft = WPamA.Festivals.Titles
  for jj = 1, #fai do
    local isTitle, strTitle = GetAchievementRewardTitle( fai[ jj ] )
    if isTitle then ft[ jj ] = strTitle  else ft[ jj ] = "???" end
  end
end

function WPamA:UpdFestivalsInfo()
  local fai = self.Festivals.AchievementsIDs
  local fa = self.CurChar.Festivals
  if fa == nil then fa = {} end
  for i = 1, #fai do
    if fa[i] == nil then fa[i] = {} end
    if IsAchievementComplete(fai[i]) then
      fa[i].isComplete = true
    else
      fa[i].isComplete = false
      local numCriteria = GetAchievementNumCriteria(fai[i])
      fa[i].All = numCriteria -- number of Criterias
      local cc = 0 -- Completed Criterias
      for ii = 1, numCriteria do
        local _, numCompl, numReq = GetAchievementCriterion(fai[i], ii)
        if numCompl == numReq then cc = cc + 1 end
      end -- for ii
      fa[i].Completed = cc -- number of Completed Criterias
    end
  end -- for i
end

function WPamA:UpdRidingSkillsInfo()
  local RS = self.CurChar.RidingSkills
  local rs3, _, rs2, _, rs1 = GetRidingStats()
  RS[3], RS[2], RS[1] = rs3, rs2, rs1
  local msNextTrain = GetTimeUntilCanBeTrained()
  RS[4] = GetTimeStamp() + math.floor(msNextTrain / 1000)
end

function WPamA:UpdDungeonsQuestInfo()
  local gdData = self.GroupDungeons.Dungeons
  local gdChar = self.CurChar.GroupDungeons
  for i = 3, #gdData do
    if type( gdChar[i] ) ~= "table" then gdChar[i] = {} end
    gdChar[i].hasBosses = not IsAchievementComplete( gdData[i].QAch )
    local qn = GetCompletedQuestInfo( gdData[i].QID )
    gdChar[i].hasQuest = ( qn == "" )
  end
end -- UpdDungeonsQuestInfo end
--
-- SubSection 7.8: Other functions
--
function WPamA.OnChmpGained(eventCode)
-- EVENT_CHAMPION_POINT_GAINED (integer eventCode)
  WPamA.ChmPoints = GetPlayerChampionPointsEarned()
  WPamA:UpdWindowInfo(true)
end

function WPamA.OnEnlitGained(eventCode)
-- EVENT_ENLIGHTENED_STATE_GAINED (integer eventCode)
--  if IsEnlightenedAvailableForAccount() then
    WPamA.EnlitState = true
    WPamA:UpdWindowInfo(true)
--  end
end

function WPamA.OnEnlitLost(eventCode)
-- EVENT_ENLIGHTENED_STATE_LOST (integer eventCode)
--  if IsEnlightenedAvailableForAccount() then
    WPamA.EnlitState = false
    WPamA:UpdWindowInfo(true)
--  end
end

function WPamA.OnInvtUpdate(eventCode, bagId, slotId, ... )
-- EVENT_INVENTORY_SINGLE_SLOT_UPDATE (Bag bagId, integer slotIndex, bool isNewItem,
-- ItemUISoundCategory itemSoundCategory, integer inventoryUpdateReason, integer stackCountChange,
-- string:nilable triggeredByCharacterName, string:nilable triggeredByDisplayName, bool isLastUpdateForMessage,
-- BonusDropSource bonusDropSource)
  --local updateReason = select(3, ... )
  --- Bank and Backpack inventory ---
  if (bagId == BAG_BACKPACK) or (bagId == BAG_BANK) or (bagId == BAG_SUBSCRIBER_BANK) then
    local id = GetItemId(bagId, slotId)
    local BI = WPamA.Inventory.InvtItemByID
    local itemType = GetItemType(bagId, slotId)
    local need_item = type( BI[id] ) == "number" or (itemType == ITEMTYPE_NONE) or (itemType == ITEMTYPE_TROPHY) or
                      (itemType == ITEMTYPE_TOOL) or (itemType == ITEMTYPE_SOUL_GEM)
    if bagId == BAG_BACKPACK then
      WPamA:UpdInvtItems(need_item)
    else
      WPamA:UpdBankItems(need_item)
    end
    ---
    local m = WPamA.SV_Main.ShowMode
    if (m == 25) or need_item and type(WPamA.Inventory.InvtItemModes[m]) == "number" then
      WPamA:UpdWindowModeChar()
    end
  end
  --- Worn inventory ---
  if bagId == BAG_WORN then
    local sid = WPamA.Equipment.Iterators.ES[slotId]
    if sid then WPamA:UpdCharEquipmentData(sid) end
    ---
    local m = WPamA.SV_Main.ShowMode
    if m == 48 then WPamA:UpdWindowInfo() end
  end
end -- OnInvtUpdate end

function WPamA.OnBagCapacityChanged(eventCode, ... )
--EVENT_INVENTORY_BAG_CAPACITY_CHANGED
-- (number eventCode, number previousCapacity, number currentCapacity, number previousUpgrade, number currentUpgrade)
  WPamA:UpdInvtItems()
  local m = WPamA.SV_Main.ShowMode
  if m == 25 then WPamA:UpdWindowModeChar() end
end

function WPamA.OnCarriedCurrencyUpdate(eventCode, currency, newValue, oldValue, reason)
--EVENT_CARRIED_CURRENCY_UPDATE (number eventCode, number currency, number newValue, number oldValue, number reason)
  local II = WPamA.Inventory.InvtItem
  for i = 1, #II do
    if II[i].c == currency then
      WPamA:DoCurrencyUpdate(WPamA.CurChar.Invt, i, newValue)
    end
  end
end

function WPamA.OnBankedCurrencyUpdate(eventCode, currency, newValue, oldValue)
--EVENT_BANKED_CURRENCY_UPDATE (number eventCode, number currency, number newValue, number oldValue)
  local II = WPamA.Inventory.InvtItem
  for i = 1, #II do
    if II[i].c == currency then
      WPamA:DoCurrencyUpdate(WPamA.SV_Main.Bank, i, newValue)
    end
  end
end

function WPamA.ShowAddonMenu()
  if WPamA.LAM and WPamA.MainMenuPanel then WPamA.LAM:OpenToPanel(WPamA.MainMenuPanel) end
end

function WPamA.OnSkillLineAdd(eventCode, skillType, skillIndex)
--EVENT_SKILL_LINE_ADDED (integer eventCode, integer skillType, luaindex skillIndex)
  local m = WPamA.SV_Main.ShowMode
  if skillType == SKILL_TYPE_CLASS then
    CheckCurrentClassSkillLines()
    WPamA:InitSkillLines()
    if m == 4 then
      WPamA:UI_UpdMainWindowHdr()
      WPamA:UpdWindowInfo()
    end
  end
  ---
  if skillType == SKILL_TYPE_GUILD or skillType == SKILL_TYPE_WORLD then
    local _, texture = GetSkillAbilityInfo(skillType, skillIndex, 1)
    --local name, rank = WPamA:GetSkillLineInfo(skillType, skillIndex) --??
    local SL, SK, mx = WPamA.SkillLines.SkillLines, WPamA.CurChar.Skills, 12
    if skillType == SKILL_TYPE_WORLD then mx = 24 end
    for _, i in pairs( WPamA.SkillLines.SkillLineModes[mx] ) do
      if string.find(texture, SL[i].mrk) then
        WPamA:Init1SkillLines(SK, SL[i], skillType, skillIndex, i)
        local f = i == WPamA.SkillLines.SkillLineDarkBr
        if f then WPamA:UpdShadowySupplier(skillIndex) end
        if m == mx or f then
          WPamA:UI_UpdMainWindowHdr()
          WPamA:UpdWindowInfo()
        end
        break
      end
    end
  end
end

function WPamA.OnSkillXPUpdate(eventCode, skillType, skillIndex, reason, rank, previousXP, currentXP)
--EVENT_SKILL_XP_UPDATE (integer eventCode, number skillType, number skillIndex, number reason, number rank, number previousXP, number currentXP)
  local _, rank1, isAvailable = WPamA:GetSkillLineInfo(skillType, skillIndex)
  if not isAvailable then return end
  local i = WPamA:GetSkillLineNum(skillType, skillIndex)
  if i ~= 0 then
    local lastRankXP, nextRankXP, currentXP1 = GetSkillLineXPInfo(skillType, skillIndex)
    --WPamA:Debug("Rank (E/F) = " .. rank .. " / " .. rank1 .. ", currentXP (E/F) = " .. currentXP .. " / " .. currentXP1,1)
    WPamA:UpdSVSkills(i, rank1, lastRankXP, nextRankXP, currentXP1)
  end
end

function WPamA.OnSkillPointsChanged(eventCode, pointsBefore, pointsNow)
-- EVENT_SKILL_POINTS_CHANGED(integer eventCode, integer pointsBefore, integer pointsNow,
-- integer partialPointsBefore, integer partialPointsNow, SkillPointReason skillPointChangeReason)
  if pointsBefore ~= pointsNow then
    WPamA:ReloadSkillsAbility()
    WPamA:UpdAvailableSP()
    if WPamA.CurChar.AvlSkP ~= pointsNow then WPamA.CurChar.AvlSkP = pointsNow end
  end
  local m = WPamA.ModeSettings[WPamA.SV_Main.ShowMode]
  if m.UpdV_AvlSPChg ~= nil then
    WPamA:UpdWindowInfo(m.UpdV_AvlSPChg)
  end 
end

function WPamA.OnUnspentChmpChanged(event)
-- EVENT_UNSPENT_CHAMPION_POINTS_CHANGED (number eventCode)
  WPamA:UpdAvailableCHMP()
  local m = WPamA.SV_Main.ShowMode
  if m == 30 then WPamA:UpdWindowInfo() end
end

function WPamA.OnTrialLootReceived(eventCode, receivedBy, itemName, quantity, itemSound, lootType, receivedBySelf, isPickpocketLoot, questItemIconPath, itemId)
  local TS = GetTimeStamp()
  local tr = WPamA.TrialDungeons.Iterators.C[itemId] or false
  --WPamA:Debug("LootR > ID:" .. nvl(itemId) .. ", N:" .. itemName .. ", TS:" .. TS .. ", TR:" .. nvl(tr) .. ", RB:" .. nvl(receivedBy) .. ", RBS:" .. BoolToStr(receivedBySelf))
  if tr and receivedBySelf then
    local v = WPamA.CurChar.Trials
    v[tr] = v[tr] or {}
    v[tr].TS = TS
    WPamA:StopCheckTrialLoot(TS)
    GetAddOnManager():RequestAddOnSavedVariablesPrioritySave(WPamA.Name)
    local m = WPamA.SV_Main.ShowMode
    local Modes = { [6] = true, [15] = true, [44] = true }
    if Modes[m] then WPamA:UpdWindowInfo() end
  elseif (WPamA.TS_CheckTrialLoot == nil) or ((TS - WPamA.TS_CheckTrialLoot) > 3) then
    WPamA:StopCheckTrialLoot(TS)
  end
end

function WPamA.OnWindowUpdate()
  local v = WPamA.SV_Main
  local FreqRedrawMode = WPamA.ModeSettings[v.ShowMode].UpdV_FreqRedrawMode
  if type(FreqRedrawMode) == "number"  then
    if (FreqRedrawMode == 0) and (v.LFGRndAvlFrmt == 1) or (FreqRedrawMode == 1) and (v.TrialAvlFrmt == 1) then
      local TS = GetTimeStamp()
      if TS > WPamA.LastWinUpdTS + WPamA.Mode67PeriodUpd then
        WPamA.LastWinUpdTS = TS
        WPamA:UpdWindowInfo()
      end
    end
  end
end

function WPamA.OnLFGDungeonNew()
--EVENT_GROUPING_TOOLS_JUMP_DUNGEON_NOTIFICATION_NEW (number eventCode)
  WPamA:SetLFGRewardTime(LFG_ACTIVITY_INVALID) -- all activity types
end

local function DelayedSetLFGDungeonRewardTime()
  WPamA:SetLFGRewardTime(LFG_ACTIVITY_DUNGEON)
  WPamA.Consts.LFGMaxRewardCheck = WPamA.Consts.LFGMaxRewardCheck - 1
  local lfgAct = WPamA.CurChar.LFGActivities[LFG_ACTIVITY_DUNGEON]
  if ( lfgAct and (lfgAct > 0) ) or ( WPamA.Consts.LFGMaxRewardCheck < 1 ) then
    EVENT_MANAGER:UnregisterForUpdate(WPamA.Name .. "DNG")
    WPamA.Consts.LFGMaxRewardCheck = nil
  end
end

function WPamA.OnLFGActivityComplete()
--EVENT_ACTIVITY_FINDER_ACTIVITY_COMPLETE (number eventCode)
  local actType = GetActivityType( GetCurrentLFGActivityId() )
  --WPamA:Debug("LFG Activity Complete: " .. nvl(actType))
  if (actType == LFG_ACTIVITY_DUNGEON) or (actType == LFG_ACTIVITY_MASTER_DUNGEON) then
    WPamA.Consts.LFGMaxRewardCheck = 5
    EVENT_MANAGER:RegisterForUpdate(WPamA.Name .. "DNG", 1000 * WPamA.SV_Main.RndDungDelay, DelayedSetLFGDungeonRewardTime)
--
  elseif (actType == LFG_ACTIVITY_TRIBUTE_CASUAL) or (actType == LFG_ACTIVITY_TRIBUTE_COMPETITIVE) then
    WPamA:SetLFGRewardTime(LFG_ACTIVITY_TRIBUTE_CASUAL)
--
  elseif actType == LFG_ACTIVITY_ENDLESS_DUNGEON then
    --d("-== LFG endless dung completed ==-")
  end
--LFG_ACTIVITY_BATTLE_GROUND_CHAMPION
--LFG_ACTIVITY_BATTLE_GROUND_LOW_LEVEL
--LFG_ACTIVITY_BATTLE_GROUND_NON_CHAMPION
--LFG_ACTIVITY_HOME_SHOW
--LFG_ACTIVITY_TRIAL
end

function WPamA.OnAchievAwarded(eventCode, achName, achPoints, achID, achLink)
-- EVENT_ACHIEVEMENT_AWARDED (number eventCode, string name, number points, number id, string link)
  local m = WPamA.SV_Main.ShowMode
-- Festival's Achiev
  local fti = WPamA.Festivals.FestIDs
  if fti[achID] then
    WPamA:UpdFestivalsInfo()
    if m == 10 then WPamA:UpdWindowInfo() end
  end
-- Craft Cert's Achiev
----  if WPamA.Consts.CraftCertAchievs[achID] then WPamA:InitSkillLines() end
-- Dungeon's Achiev
  local dq, di = WPamA.CurChar.GroupDungeons, WPamA.GroupDungeons.Iterators.A
  if di[achID] then
    dq[ di[achID] ].hasBosses = false
    if (m == 0) or (m == 1) then WPamA:UpdWindowInfo() end
  end
end

function WPamA.OnAchievUpdated(eventCode, achID)
-- EVENT_ACHIEVEMENT_UPDATED (number eventCode, number id)
  local m = WPamA.SV_Main.ShowMode
-- Festival's Achiev
  local fti = WPamA.Festivals.FestIDs
  if fti[achID] then
    WPamA:UpdFestivalsInfo()
    if m == 10 then WPamA:UpdWindowInfo() end
  end
----  if WPamA.Consts.CraftCertAchievs[achID] then WPamA:InitSkillLines() end
end

function WPamA.OnQuestOfferedGFP(eventCode)
-- EVENT_QUEST_OFFERED (number eventCode)
  if GetNumJournalQuests() < MAX_JOURNAL_QUESTS then
    AcceptOfferedQuest()
    INTERACTION:CloseChatter()
  else
    INTERACTION:CloseChatter()
    local messageParams
    messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT)
    messageParams:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_DISPLAY_ANNOUNCEMENT)
    messageParams:SetText( GetString(SI_ERROR_QUEST_LOG_FULL) )
    CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
  end
end

function WPamA.OnQuestCompleteDlgGFP(eventCode, journalIndex)
-- EVENT_QUEST_COMPLETE_DIALOG (number eventCode, number journalIndex)
  CompleteQuest()
end

function WPamA.OnConvUpdatedGFP(eventCode, bodyText, optionCount)
--EVENT_CONVERSATION_UPDATED (number eventCode, string conversationBodyText, number conversationOptionCount)
  if optionCount == 0 then
    INTERACTION:CloseChatter()
    return
  end
  SelectChatterOption(1)
end

function WPamA.OnChatterEndGFP(eventCode)
-- EVENT_CHATTER_END (number eventCode)
  local EM = GetEventManager()
  local WN = WPamA.Name .. "GFP"
  EM:UnregisterForEvent(WN, EVENT_CONVERSATION_UPDATED)
  EM:UnregisterForEvent(WN, EVENT_QUEST_OFFERED)
  EM:UnregisterForEvent(WN, EVENT_QUEST_COMPLETE_DIALOG)
  EM:UnregisterForEvent(WN, EVENT_CHATTER_END)
end

function WPamA.OnChatterEndSHAD(eventCode)
-- EVENT_CHATTER_END (number eventCode)
  EVENT_MANAGER:UnregisterForEvent(WPamA.Name .. "SHAD", EVENT_CHATTER_END)
-- Update the Time to Shadowy Connections reset
  WPamA:UpdShadowySupplier()
--
  local m = WPamA.SV_Main.ShowMode
  if m == 28 then WPamA:UpdWindowInfo() end
end

function WPamA.OnChatterBegin(eventCode, optionCount)
-- EVENT_CHATTER_BEGIN (number eventCode, number optionCount)
  local _, actName = GetGameCameraInteractableActionInfo()
  if type(actName) ~= "string" then return end -- protection from incorrect value
  if RuESO_init then actName = actName:gsub("\n.+", "") end -- double-name correction for RuESO addon
--d("actName = [" .. actName .. "]")
  local EM = GetEventManager()
  ------------
  if WPamA.PledgeGivers[ actName ] then -- one of Undaunted NPC
    if WPamA.SV_Main.AutoTakePledges then -- check the AutoTakePledges option
      if optionCount == 0 then
        INTERACTION:CloseChatter()
        return
      elseif optionCount == 2 then
        local WN = WPamA.Name .. "GFP"
        EM:RegisterForEvent(WN, EVENT_CONVERSATION_UPDATED, WPamA.OnConvUpdatedGFP)
        EM:RegisterForEvent(WN, EVENT_QUEST_OFFERED, WPamA.OnQuestOfferedGFP)
        EM:RegisterForEvent(WN, EVENT_QUEST_COMPLETE_DIALOG, WPamA.OnQuestCompleteDlgGFP)
        EM:RegisterForEvent(WN, EVENT_CHATTER_END, WPamA.OnChatterEndGFP)
        SelectChatterOption(1)
      end
    end
  ------------
  elseif WPamA.i18n.ShadowySupplier[ actName ] then -- Shadowy-Supplier NPC
    EM:RegisterForEvent(WPamA.Name .. "SHAD", EVENT_CHATTER_END, WPamA.OnChatterEndSHAD)
    if optionCount > 2 then
      local chosenOption = WPamA.ShadowySupplierOption()
      if chosenOption == 1 then return end -- chosen "do nothing" option
      local _, optionType = GetChatterOption(chosenOption)
      if optionType == CHATTER_TALK_CHOICE_SHADOWY_CONNECTIONS_UNAVAILABLE then
        INTERACTION:CloseChatter()
        --- Message to player ---
        local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_SMALL_TEXT)
        messageParams:SetCSAType(CENTER_SCREEN_ANNOUNCE_TYPE_DISPLAY_ANNOUNCEMENT)
        messageParams:SetText(WPamA.i18n.ComeBackLater or " ")
        CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
        return
      else
        SelectChatterOption(chosenOption)
      end
    else
      INTERACTION:CloseChatter()
      return
    end
  ------------
  end
end -- OnChatterBegin end

function WPamA.OnRidingSkillImpr(eventCode, ridingSkillType, previous, current, source)
-- EVENT_RIDING_SKILL_IMPROVEMENT(number eventCode, RidingTrainType ridingSkillType,
-- number previous, number current, RidingTrainSource source)
  WPamA:UpdRidingSkillsInfo()
  local m = WPamA.SV_Main.ShowMode
  if (m == 13) or (m == 25) then WPamA:UpdWindowInfo() end
end
--
-- Section 8: Register addon and events
--
function WPamA.OnBGStateChanged(eventCode, previousState, currentState)
--[[ Update 44 BG States :
BATTLEGROUND_STATE_NONE		= 0
BATTLEGROUND_STATE_PREROUND	= 1
BATTLEGROUND_STATE_STARTING	= 2
BATTLEGROUND_STATE_RUNNING	= 3
BATTLEGROUND_STATE_POSTROUND	= 4
BATTLEGROUND_STATE_FINISHED	= 5 --]]
--[[
  local f = IsActivityEligibleForDailyReward(LFG_ACTIVITY_BATTLE_GROUND_NON_CHAMPION)
  local v = WPamA.CurChar
  WPamA:Debug("BGStateChanged: PS=" .. nvl(previousState) .. ", CS=" .. currentState .. ", DR=" .. BoolToStr(f) .. ", TS=" .. nvl(v.LFGBGTS))
--]]
  if currentState == BATTLEGROUND_STATE_POSTROUND then -- currentState is 4
    --WPamA:Debug("BGStateChanged: Register for EVENT_PLAYER_ACTIVATED")
    EVENT_MANAGER:RegisterForEvent(WPamA.Name .. "BG", EVENT_PLAYER_ACTIVATED, WPamA.OnBGChangeZone)
  end
end

function WPamA.OnBGChangeZone()
  EVENT_MANAGER:UnregisterForEvent(WPamA.Name .. "BG", EVENT_PLAYER_ACTIVATED)
  WPamA:SetLFGRewardTime(LFG_ACTIVITY_BATTLE_GROUND_NON_CHAMPION)
--  QueryBattlegroundLeaderboardData()
end

function WPamA.OnBookLearned()
  WPamA:UpdLoreBookCount()
  if WPamA.SV_Main.ShowMode == 34 then
    WPamA:UI_UpdMainWindowHdr()
    WPamA:UpdWindowInfo()
  end
end

function WPamA.OnAddOnLoaded(event, addonName)
  if addonName == WPamA.Name then
    local EM = GetEventManager()
    local WN = WPamA.Name -- for common events
    EM:UnregisterForEvent(WN, EVENT_ADD_ON_LOADED)
    WPamA:Initialize()
    WPamA:CreateOptionsPanel()
    EM:RegisterForEvent(WN, EVENT_LEVEL_UPDATE, WPamA.OnLevelUpdate)
    EM:AddFilterForEvent(WN, EVENT_LEVEL_UPDATE, REGISTER_FILTER_UNIT_TAG, "player")
    EM:RegisterForEvent(WN, EVENT_QUEST_ADDED, WPamA.OnQuestAdded)
    EM:RegisterForEvent(WN, EVENT_QUEST_REMOVED, WPamA.OnQuestRemoved)
    EM:RegisterForEvent(WN, EVENT_QUEST_ADVANCED, WPamA.OnQuestAdvanced)
    EM:RegisterForEvent(WN, EVENT_LOGOUT_DEFERRED, WPamA.OnRGLAStopClick)
    EM:RegisterForEvent(WN, EVENT_LOGOUT_DISALLOWED, WPamA.OnRGLAStopClick)
    EM:RegisterForEvent(WN, EVENT_CHAMPION_POINT_GAINED, WPamA.OnChmpGained)
    EM:RegisterForEvent(WN, EVENT_ENLIGHTENED_STATE_GAINED, WPamA.OnEnlitGained)
    EM:RegisterForEvent(WN, EVENT_ENLIGHTENED_STATE_LOST, WPamA.OnEnlitLost)
    EM:RegisterForEvent(WN, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, WPamA.OnInvtUpdate)
    EM:RegisterForEvent(WN, EVENT_INVENTORY_BAG_CAPACITY_CHANGED, WPamA.OnBagCapacityChanged)
    EM:RegisterForEvent(WN, EVENT_CHATTER_BEGIN, WPamA.OnChatterBegin)
    EM:RegisterForEvent(WN, EVENT_SKILL_LINE_ADDED, WPamA.OnSkillLineAdd)
    EM:RegisterForEvent(WN, EVENT_SKILL_XP_UPDATE, WPamA.OnSkillXPUpdate)
    EM:RegisterForEvent(WN, EVENT_SKILL_POINTS_CHANGED, WPamA.OnSkillPointsChanged)
    EM:RegisterForEvent(WN, EVENT_GROUPING_TOOLS_JUMP_DUNGEON_NOTIFICATION_NEW, WPamA.OnLFGDungeonNew)
    EM:RegisterForEvent(WN, EVENT_ACTIVITY_FINDER_ACTIVITY_COMPLETE, WPamA.OnLFGActivityComplete)
    EM:RegisterForEvent(WN, EVENT_CARRIED_CURRENCY_UPDATE, WPamA.OnCarriedCurrencyUpdate)
    EM:RegisterForEvent(WN, EVENT_BANKED_CURRENCY_UPDATE, WPamA.OnBankedCurrencyUpdate)
    EM:RegisterForEvent(WN, EVENT_ACHIEVEMENT_UPDATED, WPamA.OnAchievUpdated)
    EM:RegisterForEvent(WN, EVENT_ACHIEVEMENT_AWARDED, WPamA.OnAchievAwarded)
    EM:RegisterForEvent(WN, EVENT_RIDING_SKILL_IMPROVEMENT, WPamA.OnRidingSkillImpr)
    EM:RegisterForEvent(WN, EVENT_CAMPAIGN_LEADERBOARD_DATA_RECEIVED, WPamA.OnCampLBDataReceived)
    EM:RegisterForEvent(WN, EVENT_ASSIGNED_CAMPAIGN_CHANGED, WPamA.OnAssignedCampChanged)
    EM:RegisterForEvent(WN, EVENT_CAMPAIGN_SCORE_DATA_CHANGED, WPamA.OnCampScoreDataChanged)
    EM:RegisterForEvent(WN, EVENT_CAMPAIGN_EMPEROR_CHANGED, WPamA.OnCampEmperorChanged)
    EM:RegisterForEvent(WN, EVENT_RANK_POINT_UPDATE, WPamA.OnRankPointUpdate)
    EM:AddFilterForEvent(WN, EVENT_RANK_POINT_UPDATE, REGISTER_FILTER_UNIT_TAG_PREFIX, "player")
    EM:RegisterForEvent(WN, EVENT_BATTLEGROUND_STATE_CHANGED, WPamA.OnBGStateChanged)
    EM:RegisterForEvent(WN, EVENT_BATTLEGROUND_LEADERBOARD_DATA_RECEIVED, WPamA.OnBGrndLBDataReceived)
----    EM:RegisterForEvent(WN, EVENT_BATTLEGROUND_SCOREBOARD_UPDATED, WPamA.OnBGrndScoreDataChanged)
    EM:RegisterForEvent(WN, EVENT_LOOT_UPDATED, WPamA.OnLootUpdated)
    EM:RegisterForEvent(WN, EVENT_TIMED_ACTIVITY_PROGRESS_UPDATED, WPamA.OnEndeavorUpdated)
    EM:RegisterForEvent(WN, EVENT_TIMED_ACTIVITIES_UPDATED, WPamA.OnEndeavorUpdated)
    EM:RegisterForEvent(WN, EVENT_UNSPENT_CHAMPION_POINTS_CHANGED, WPamA.OnUnspentChmpChanged)
    EM:RegisterForEvent(WN, EVENT_LORE_BOOK_LEARNED, WPamA.OnBookLearned)
--
    EM:RegisterForEvent(WN, EVENT_PROMOTIONAL_EVENTS_CAMPAIGNS_UPDATED, WPamA.OnPromoActivityUpdated)
    EM:RegisterForEvent(WN, EVENT_PROMOTIONAL_EVENTS_ACTIVITY_PROGRESS_UPDATED, WPamA.OnPromoActivityUpdated)
--
    EM:RegisterForEvent(WN, EVENT_MULTIPLE_RECIPES_LEARNED, WPamA.OnRecipeLearned)
    EM:RegisterForEvent(WN, EVENT_RECIPE_LEARNED, WPamA.OnRecipeLearned)
--
    EM:RegisterForEvent(WN, EVENT_EFFECT_CHANGED, WPamA.OnEffectChanged)
    EM:AddFilterForEvent(WN, EVENT_EFFECT_CHANGED, REGISTER_FILTER_UNIT_TAG, "player")
--
    WN = WPamA.Name .. "COMP" -- for companion events
    EM:RegisterForEvent(WN, EVENT_COMPANION_ACTIVATED, WPamA.OnCompanionActivated)
    EM:RegisterForEvent(WN, EVENT_COMPANION_DEACTIVATED, WPamA.OnCompanionDeactivated)
    EM:RegisterForEvent(WN, EVENT_COMPANION_RAPPORT_UPDATE, WPamA.OnCompanionRapportUpdate)
    EM:RegisterForEvent(WN, EVENT_COMPANION_EXPERIENCE_GAIN, WPamA.OnCompanionExpGain)
    EM:RegisterForEvent(WN, EVENT_COMPANION_SKILL_LINE_ADDED, WPamA.OnCompanionSkillLineUpdate)
    EM:RegisterForEvent(WN, EVENT_COMPANION_SKILL_RANK_UPDATE, WPamA.OnCompanionSkillLineUpdate)
    EM:RegisterForEvent(WN, EVENT_COMPANION_SKILL_XP_UPDATE, WPamA.OnCompanionSkillLineUpdate)
    EM:RegisterForEvent(WN, EVENT_HOTBAR_SLOT_STATE_UPDATED, WPamA.OnCompanionSkillBarUpdate)
    EM:RegisterForEvent(WN, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, WPamA.OnCompanionEquipSlotUpdate)
    EM:AddFilterForEvent(WN, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_COMPANION_WORN)
--
    WN = WPamA.Name .. "WE" -- for world events
    EM:RegisterForEvent(WN, EVENT_WORLD_EVENT_UNIT_CREATED, WPamA.OnWorldEventsCalled)
    EM:RegisterForEvent(WN, EVENT_WORLD_EVENT_UNIT_DESTROYED, WPamA.OnWorldEventsCalled)
    EM:RegisterForEvent(WN, EVENT_WORLD_EVENT_ACTIVATED, WPamA.OnWorldEventsCalled)
    EM:RegisterForEvent(WN, EVENT_WORLD_EVENT_DEACTIVATED, WPamA.OnWorldEventsCalled)
    EM:RegisterForEvent(WN, EVENT_ADVENTURE_ZONE_WORLD_EVENT_STARTS_SOON, WPamA.OnWorldEventsCalled)
    EM:RegisterForEvent(WN, EVENT_PLAYER_ACTIVATED, WPamA.OnPlayerActiveWE)
    EM:RegisterForEvent(WN, EVENT_PLAYER_DEACTIVATED, WPamA.OnPlayerActiveWE)
--
    WN = WPamA.Name .. "ED" -- for endless dungeons
    EM:RegisterForEvent(WN, EVENT_ENDLESS_DUNGEON_INITIALIZED, WPamA.OnEndlessDungeonEvents)
    EM:RegisterForEvent(WN, EVENT_ENDLESS_DUNGEON_STARTED, WPamA.OnEndlessDungeonEvents)
    EM:RegisterForEvent(WN, EVENT_ENDLESS_DUNGEON_COMPLETED, WPamA.OnEndlessDungeonEvents)
--    EM:RegisterForEvent(WN, EVENT_ENDLESS_DUNGEON_CONFIRM_COMPANION_SUMMONING, WPamA.OnEndlessDungeonEvents)
    EM:RegisterForEvent(WN, EVENT_ENDLESS_DUNGEON_COUNTER_VALUE_CHANGED, WPamA.OnEndlessDungeonEvents)
    EM:RegisterForEvent(WN, EVENT_ENDLESS_DUNGEON_LEADERBOARD_PLAYER_DATA_CHANGED, WPamA.OnEndlessDungeonEvents)
--    EM:RegisterForEvent(WN, EVENT_ENDLESS_DUNGEON_LEADERBOARD_DATA_RECEIVED, WPamA.OnEndlessDungeonEvents)
  end
end
 
EVENT_MANAGER:RegisterForEvent(WPamA.Name, EVENT_ADD_ON_LOADED, WPamA.OnAddOnLoaded)
