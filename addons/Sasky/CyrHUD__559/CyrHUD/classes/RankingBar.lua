-- This file is part of CyrHUD
--
-- (C) 2015 Scott Yeskie (Sasky)
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

CyrHUD = CyrHUD or {}
CyrHUD.RankingBar = {}
CyrHUD.RankingBar.type = "RankingBar"
CyrHUD.RankingBar.__index = CyrHUD.RankingBar

setmetatable(CyrHUD.RankingBar, {
    __call = function(cls, ...) return cls.new(...) end
})

local bar = CyrHUD.RankingBar

function CyrHUD.RankingBar.new(campaign)

    local self = setmetatable({}, CyrHUD.RankingBar)

    self.campaign = campaign or GetCurrentCampaignId()
	  self.alliance = GetUnitAlliance("player")
    self:update()

    return self
end




function bar:update()

	self.rank = self.rank or 0
	self.points = self.points or 0
	self.rawPoints = self.rawPoints or -1
	self.dName = self.dName or ""
	self.prevRank = self.prevRank or 0
	self.prevName = self.prevName or ""
	self.diffPoints = self.diffPoints or 0
	self.rank2 = self.rank2 or 0
	self.points2 = self.points2 or 0
	self.dName2 = self.dName2  or ""
  self.updated = self.updated or true
	
    if not CyrHUD.CampaignDataPending then
      local entrycount = GetNumCampaignAllianceLeaderboardEntries(self.campaign, self.alliance)

      local rank, points, dName, prevRank, prevPoints, prevName = -1, 0, "", 0, 0, ""
      local gotPlayer = false
      for entry = 1, entrycount do
        local isPlayer, ranking, _, alliancePoints, _, displayName = GetCampaignAllianceLeaderboardEntryInfo(self.campaign, self.alliance, entry)
        
        if isPlayer then
           rank = ranking
           points = alliancePoints
           dName = displayName
           if ranking ~= 1 then
               break
           else
               gotPlayer = true
           end
        else
          prevRank = ranking
          prevPoints = alliancePoints
          prevName = displayName
          
          if ranking == 2 then
            -- rank 2 player
             self.rank2 = ranking
             self.points2 = alliancePoints
             self.dName2 = displayName
             if gotPlayer then
                break
             end
          end
        end	
		end
    

		if rank > 0 and points ~= self.rawPoints then
		   -- player
		   self.rank = rank
		   self.points = points.."p"
		   self.rawPoints = points
		   self.dName = dName
		   
		   -- previous rank player
		   if rank ~= 1 then
			   self.prevRank = prevRank
			   self.prevName = prevName 
			   self.diffPoints = (prevPoints - points)
		   else
       -- following rank player
			   self.prevRank = self.rank2
			   self.prevName = self.dName2 
			   self.diffPoints = (self.points2 - points)
		   end
        self.updated = true
		end
    
    
	end
	
	if self.updated then
	    local state = QueryCampaignLeaderboardData(self.campaign, self.alliance)
      if state == LEADERBOARD_DATA_RESPONSE_PENDING then
         self.updated = false
         CyrHUD.CampaignDataPending = true
      end
  end	

	
end


local ICON_EMPEROR = "img25"
local TEXT_PLAYERNAME = "txt17"
local TEXT_RIVALNAME = "txt18"
local TEXT_PLAYERRANK = "txt19"
local TEXT_RIVALRANK = "txt20"
local TEXT_PLAYERSCORE = "txt21"
local TEXT_RIVALSCORE = "txt22"

local ICON_ASH = "img26"
local ICON_WELL = "img27"
local ICON_CHAL = "img28"
local ICON_BRK = "img29"
local ICON_SIA = "img30"
local ICON_ROE = "img31"

local ICON_MEM = "img32"
local ICON_ELV = "img33"
local ICON_ARE = "img34"
local ICON_NOB = "img35"
local ICON_ARB = "img36"
local ICON_TEM = "img37"


local L_ICON, L_UA = "img1", "img2"
local CYROCHAT_ICON = 'img4'
local L_NAME, L_ATT_SIEGE, L_DEF_SIEGE, L_TIME = "txt1", "txt2", "txt3", "txt4"
local L_LUMB, L_MINE, L_FARM = "img5", "img6", "img7"
local L_SCROLL = "img8"
local L_ICON_DEATHS_AD, L_ICON_DEATHS_EP, L_ICON_DEATHS_DC = "img12", "img13", "img14"
local L_DEATHS_AD, L_DEATHS_EP, L_DEATHS_DC = "txt11", "txt12", "txt13"
local L_KILLS_AD, L_KILLS_EP, L_KILLS_DC = "txt23", "txt24", "txt25"
local LEGEND_KILLS, LEGEND_DEATHS = "txt26", "txt27"
local L_ATT_SIEGE_ICON, L_DEF_SIEGE_ICON = "img15", "img16"
local L_CONNECTED = "img17"
local L_ARROW = "img18"
local L_HOLDER = "txt16"


--local TEXT_KILLS, TEXT_DEATHS = "txt14","txt15"

function bar:configureLabel(label)
    label:exposeControls(3,4)
    --label.main:SetCenterColor(CyrHUD.info.invisColor:UnpackRGBA())
	
  label:getControl(ICON_EMPEROR):SetTexture(CyrHUD.icons["emperor"])
	label:getControl(ICON_EMPEROR):SetDrawLayer(3)
	label:getControl(ICON_EMPEROR):SetColor(CyrHUD.info[self.alliance].color:UnpackRGBA())
	label:positionControl(ICON_EMPEROR, 32, 32, 0, 0)
	
	

	label:positionControl(TEXT_RIVALNAME, 130, 50, 35, -3)
	label:getControl(TEXT_RIVALNAME):SetDrawLayer(3)

	
	label:positionControl(TEXT_RIVALRANK, 30, 50, 170, -3)
	label:getControl(TEXT_RIVALRANK):SetDrawLayer(3)
	

	label:positionControl(TEXT_RIVALSCORE, 130, 50, 205, -3)
	label:getControl(TEXT_RIVALSCORE):SetDrawLayer(3)


  label:positionControl(TEXT_PLAYERNAME, 130, 50, 35, 16)
	label:getControl(TEXT_PLAYERNAME):SetDrawLayer(3)
	
	label:positionControl(TEXT_PLAYERRANK, 30, 50, 170, 16)
	label:getControl(TEXT_PLAYERRANK):SetDrawLayer(3)

	label:positionControl(TEXT_PLAYERSCORE, 130, 50, 205, 16)
	label:getControl(TEXT_PLAYERSCORE):SetDrawLayer(3)
	
	label:getControl(ICON_ASH):SetTexture(CyrHUD.icons[KEEPTYPE_KEEP])
	label:getControl(ICON_WELL):SetTexture(CyrHUD.icons[KEEPTYPE_KEEP])
	label:getControl(ICON_CHAL):SetTexture(CyrHUD.icons[KEEPTYPE_KEEP])
	label:getControl(ICON_BRK):SetTexture(CyrHUD.icons[KEEPTYPE_KEEP])
	label:getControl(ICON_SIA):SetTexture(CyrHUD.icons[KEEPTYPE_KEEP])
	label:getControl(ICON_ROE):SetTexture(CyrHUD.icons[KEEPTYPE_KEEP])
	
	
	label:getControl(ICON_MEM):SetTexture(CyrHUD.icons[KEEPTYPE_IMPERIAL_CITY_DISTRICT])
	label:getControl(ICON_ELV):SetTexture(CyrHUD.icons[KEEPTYPE_IMPERIAL_CITY_DISTRICT])
	label:getControl(ICON_ARE):SetTexture(CyrHUD.icons[KEEPTYPE_IMPERIAL_CITY_DISTRICT])
	label:getControl(ICON_NOB):SetTexture(CyrHUD.icons[KEEPTYPE_IMPERIAL_CITY_DISTRICT])
	label:getControl(ICON_ARB):SetTexture(CyrHUD.icons[KEEPTYPE_IMPERIAL_CITY_DISTRICT])
	label:getControl(ICON_TEM):SetTexture(CyrHUD.icons[KEEPTYPE_IMPERIAL_CITY_DISTRICT])
  
    -- Objective icon
    label:positionControl(L_ICON, 40, 40, -2, -2)
    label:getControl(L_ICON):SetDrawLayer(2)
    label:getControl(L_ICON):SetTexture("/esoui/art/mappins/ava_largekeep_neutral.dds")
	
	--Keep resources around keep
	label:getControl(L_LUMB):SetDrawLayer(4)
	label:getControl(L_MINE):SetDrawLayer(4)
	label:getControl(L_FARM):SetDrawLayer(4)
	label:positionControl(L_LUMB, 20, 20, -5, -5) 
	label:positionControl(L_MINE, 20, 20, -5, 20) 
	label:positionControl(L_FARM, 20, 20, 22, 20) 
  label:getControl(L_LUMB):SetTexture(CyrHUD.icons[10 + RESOURCETYPE_WOOD])
  label:getControl(L_MINE):SetTexture(CyrHUD.icons[10 + RESOURCETYPE_ORE])
  label:getControl(L_FARM):SetTexture(CyrHUD.icons[10 + RESOURCETYPE_FOOD])
	
  label:getControl(ICON_ASH):SetDrawLayer(4)
	label:getControl(ICON_WELL):SetDrawLayer(4)
	label:getControl(ICON_CHAL):SetDrawLayer(4)
	label:getControl(ICON_BRK):SetDrawLayer(4)
	label:getControl(ICON_SIA):SetDrawLayer(4)
	label:getControl(ICON_ROE):SetDrawLayer(4)
	
	
	label:getControl(ICON_MEM):SetDrawLayer(4)
	label:getControl(ICON_ELV):SetDrawLayer(4)
	label:getControl(ICON_ARE):SetDrawLayer(4)
	label:getControl(ICON_NOB):SetDrawLayer(4)
	label:getControl(ICON_ARB):SetDrawLayer(4)
	label:getControl(ICON_TEM):SetDrawLayer(4)
	
	label:positionControl(ICON_WELL, 15, 15, 0, -2)
	label:positionControl(ICON_CHAL, 15, 15, 18, -2)
	
  label:positionControl(ICON_ASH, 15, 15, -5, 10)
	label:positionControl(ICON_BRK, 15, 15, 23, 10)
	
	label:positionControl(ICON_ROE, 15, 15, 0, 20)
	label:positionControl(ICON_SIA, 15, 15, 18, 20)
	
	
	
	label:positionControl(ICON_MEM, 20, 20, 9, -2)
	
	label:positionControl(ICON_ELV, 20, 20, -2, 4)
	label:positionControl(ICON_ARE, 20, 20, 20, 4)
	
	label:positionControl(ICON_ARB, 20, 20, 20, 15)
	label:positionControl(ICON_NOB, 20, 20, -2, 15)
	
	label:positionControl(ICON_TEM, 20, 20, 9, 20)	
	
	
	--label:positionControl(TEXT_KILLS, 90, 40, 10, -30)
	--label:positionControl(TEXT_DEATHS, 90, 40, 10, -10)

end

function bar:updateLabel(label)

	-- if not CyrHUD.cfg.hideKillsDeaths then
	    -- label:getControl(TEXT_KILLS):SetText("K: "..CyrHUD.yourKills)
	    -- label:getControl(TEXT_DEATHS):SetText("D: "..CyrHUD.yourDeaths)
		-- label:getControl(TEXT_KILLS):SetHidden(false)
		-- label:getControl(TEXT_DEATHS):SetHidden(false)
	-- else
	    -- label:getControl(TEXT_KILLS):SetHidden(true)
		-- label:getControl(TEXT_DEATHS):SetHidden(true)
    -- end


  label:getControl(L_ICON_DEATHS_AD):SetHidden(true)
	label:getControl(L_ICON_DEATHS_EP):SetHidden(true)
	label:getControl(L_ICON_DEATHS_DC):SetHidden(true)
  label:getControl(L_DEATHS_AD):SetHidden(true)
	label:getControl(L_DEATHS_EP):SetHidden(true)
	label:getControl(L_DEATHS_DC):SetHidden(true)
  label:getControl(L_KILLS_AD):SetHidden(true)
	label:getControl(L_KILLS_EP):SetHidden(true)
	label:getControl(L_KILLS_DC):SetHidden(true)
	label:getControl(LEGEND_KILLS):SetHidden(true)
	label:getControl(LEGEND_DEATHS):SetHidden(true)

  label:getControl(L_UA):SetHidden(true)
	label:getControl(L_LUMB):SetHidden(true)
	label:getControl(L_MINE):SetHidden(true)
	label:getControl(L_FARM):SetHidden(true)
  label:getControl(L_SCROLL):SetHidden(true)
	label:getControl(L_ATT_SIEGE):SetHidden(true)
	label:getControl(L_DEF_SIEGE):SetHidden(true)
	label:getControl(CYROCHAT_ICON):SetHidden(true)
  label:getControl(L_ATT_SIEGE_ICON):SetHidden(true)
	label:getControl(L_DEF_SIEGE_ICON):SetHidden(true)
	label:getControl(L_CONNECTED):SetHidden(true)
	label:getControl(L_HOLDER):SetHidden(true)
	label:getControl(L_ARROW):SetAlpha(0)
	
  label:getControl(L_NAME):SetHidden(true)
	label:getControl(L_ICON):SetHidden(true)
	label:getControl(L_TIME):SetHidden(true)


	local playerName, rivalName = label:getControl(TEXT_PLAYERNAME), label:getControl(TEXT_RIVALNAME)
	local playerRank, rivalRank = label:getControl(TEXT_PLAYERRANK), label:getControl(TEXT_RIVALRANK)
	local playerScore, rivalScore = label:getControl(TEXT_PLAYERSCORE), label:getControl(TEXT_RIVALSCORE)
	local iconEmperor = label:getControl(ICON_EMPEROR)
	local iconMem, iconElv, iconAre = label:getControl(ICON_MEM), label:getControl(ICON_ELV), label:getControl(ICON_ARE)
	local iconNob, iconArb, iconTem = label:getControl(ICON_NOB), label:getControl(ICON_ARB), label:getControl(ICON_TEM)
	local iconAsh, iconWell, iconChal = label:getControl(ICON_ASH), label:getControl(ICON_WELL), label:getControl(ICON_CHAL)
	local iconBrk, iconSia, iconRoe = label:getControl(ICON_BRK), label:getControl(ICON_SIA), label:getControl(ICON_ROE)

	playerName:SetHidden(false)
	rivalName:SetHidden(false)
	playerRank:SetHidden(false)
	rivalRank:SetHidden(false)
	playerScore:SetHidden(false)
	rivalScore:SetHidden(false)
	
	
	

	if IsInImperialCity() then
	
	  CyrHUD.imperialKeeps = CyrHUD.imperialKeeps or {}
	  iconEmperor:SetHidden(true)
	
		local MemAlliance = CyrHUD.imperialKeeps[142] or 0
		local ElvAlliance = CyrHUD.imperialKeeps[148] or 0	
		local AreAlliance = CyrHUD.imperialKeeps[146] or 0
		local NobAlliance = CyrHUD.imperialKeeps[141] or 0
		local ArbAlliance = CyrHUD.imperialKeeps[143] or 0
		local TemAlliance = CyrHUD.imperialKeeps[147] or 0
		
		local NemColor = CyrHUD.info[MemAlliance].color 
		local ElvColor = CyrHUD.info[ElvAlliance].color
		local AreColor = CyrHUD.info[AreAlliance].color 
		local NobColor = CyrHUD.info[NobAlliance].color 
		local ArbColor = CyrHUD.info[ArbAlliance].color 
		local TemColor = CyrHUD.info[TemAlliance].color 

		
		iconMem:SetColor(NemColor:UnpackRGBA())
		iconElv:SetColor(ElvColor:UnpackRGBA())
		iconAre:SetColor(AreColor:UnpackRGBA())
		iconNob:SetColor(NobColor:UnpackRGBA())
		iconArb:SetColor(ArbColor:UnpackRGBA())
		iconTem:SetColor(TemColor:UnpackRGBA())

	
		iconMem:SetHidden(false)
		iconElv:SetHidden(false)
		iconAre:SetHidden(false)
		iconNob:SetHidden(false)
		iconArb:SetHidden(false)
		iconTem:SetHidden(false)	
	
	
	
		iconAsh:SetHidden(true)
		iconWell:SetHidden(true)
		iconChal:SetHidden(true)
		iconBrk:SetHidden(true)
		iconSia:SetHidden(true)
		iconRoe:SetHidden(true)
		
    -- local telVarIcon = GetCurrencyKeyboardIcon(CURT_TELVAR_STONES)
		-- local fragmentsIcon = GetCurrencyKeyboardIcon(CURT_IMPERIAL_FRAGMENTS)
		
		-- local telVarColor = ZO_ColorDef:New(GetCurrencyKeyboardColor(CURT_TELVAR_STONES))
		-- local fragmentsColor = ZO_ColorDef:New(GetCurrencyKeyboardColor(CURT_IMPERIAL_FRAGMENTS))

		-- local numTelVar = GetCurrencyAmount(CURT_TELVAR_STONES, CURRENCY_LOCATION_CHARACTER)..zo_iconTextFormatNoSpace(telVarIcon,12,12,"")
		      -- numTelVar = telVarColor:Colorize(numTelVar)
		-- local numFragments = GetCurrencyAmount(CURT_IMPERIAL_FRAGMENTS, CURRENCY_LOCATION_ACCOUNT)..zo_iconTextFormatNoSpace(fragmentsIcon,12,12,"")
		      -- numFragments = fragmentsColor:Colorize(numFragments)
		
		-- local telVar = GetCurrencyName(CURT_TELVAR_STONES, false, true)
		      -- telVar = telVarColor:Colorize(telVar)
		-- local fragments = GetCurrencyName(CURT_IMPERIAL_FRAGMENTS, false, true)
		      -- fragments = fragmentsColor:Colorize(fragments)
		-- local multiplier = GetTelvarStoneMultiplier(GetTelvarStoneMultiplierThresholdIndex())

		-- if tostring(numTelVar) ~= rivalScore:GetText() or tostring(numFragments) ~= playerScore:GetText() then
		    -- self.startBattle = GetTimeStamp()
		-- end

		
		-- rivalName:SetText(telVar)
		-- rivalRank:SetText("x"..multiplier)
		-- rivalScore:SetText(numTelVar)	

		-- playerName:SetText(fragments)
		-- playerRank:SetText("")  
		-- playerScore:SetText(numFragments)
		
		-- rivalName:SetAlpha(1)
	  -- rivalRank:SetAlpha(1)
	  -- rivalScore:SetAlpha(1)	
    
		if playerScore:GetText() ~= tostring(self.points) then
       self.startBattle = GetTimeStamp()
    end
	
		rivalName:SetText(self.prevName)
		rivalRank:SetText("#"..self.prevRank)
		rivalScore:SetText(string.format("%+d", self.diffPoints).."p")

		playerName:SetText(self.dName)
		playerRank:SetText("#"..self.rank)  
		playerScore:SetText(self.points)

    rivalName:SetAlpha(0.5)
	  rivalRank:SetAlpha(0.5)
	  rivalScore:SetAlpha(0.5)		
		
	elseif IsInJerallPass() then
  
    CyrHUD.imperialKeeps = CyrHUD.imperialKeeps or {}
    
     local iconKeep = label:getControl(L_ICON)
	   local iconLumb = label:getControl(L_LUMB)
	   local iconMine = label:getControl(L_MINE)
	   local iconFarm = label:getControl(L_FARM)
    
    
    local KeepAlliance = CyrHUD.imperialKeeps[1] or 0
		local FarmAlliance = CyrHUD.imperialKeeps[25] or 0
		local LumbAlliance = CyrHUD.imperialKeeps[26] or 0
		local MineAlliance = CyrHUD.imperialKeeps[27] or 0
		
		local KeepColor = CyrHUD.info[KeepAlliance].color 
		local FarmColor = CyrHUD.info[FarmAlliance].color
		local LumbColor = CyrHUD.info[LumbAlliance].color 
		local MineColor = CyrHUD.info[MineAlliance].color 
		
		iconKeep:SetColor(KeepColor:UnpackRGBA())
		iconFarm:SetColor(FarmColor:UnpackRGBA())
		iconLumb:SetColor(LumbColor:UnpackRGBA())
		iconMine:SetColor(MineColor:UnpackRGBA())
    
		iconKeep:SetHidden(false)
		iconFarm:SetHidden(false)
		iconLumb:SetHidden(false)
		iconMine:SetHidden(false)
  
  
	  iconEmperor:SetHidden(true)
	
		iconAsh:SetHidden(true)
		iconWell:SetHidden(true)
		iconChal:SetHidden(true)
		iconBrk:SetHidden(true)
		iconSia:SetHidden(true)
		iconRoe:SetHidden(true)
    
		iconMem:SetHidden(true)
		iconElv:SetHidden(true)
		iconAre:SetHidden(true)
		iconNob:SetHidden(true)
		iconArb:SetHidden(true)
		iconTem:SetHidden(true)
		
		if playerScore:GetText() ~= tostring(self.points) then
       self.startBattle = GetTimeStamp()
    end
	
		rivalName:SetText(self.prevName)
		rivalRank:SetText("#"..self.prevRank)
		rivalScore:SetText(string.format("%+d", self.diffPoints).."p")

		playerName:SetText(self.dName)
		playerRank:SetText("#"..self.rank)  
		playerScore:SetText(self.points)

      rivalName:SetAlpha(0.5)
	    rivalRank:SetAlpha(0.5)
	    rivalScore:SetAlpha(0.5)		
  
  
		
	else
  
	   iconEmperor:SetHidden(false)
	
		local emperorAlliance = GetCampaignEmperorInfo(self.campaign)
		iconEmperor:SetColor(CyrHUD.info[emperorAlliance].color:UnpackRGBA())
    
    CyrHUD.imperialKeeps = CyrHUD.imperialKeeps or {}
		
		local AshAlliance = CyrHUD.imperialKeeps[6] or 0
		local AleswellAlliance = CyrHUD.imperialKeeps[7] or 0	
		local ChalmanAlliance = CyrHUD.imperialKeeps[9] or 0
		local BlueRoadAlliance = CyrHUD.imperialKeeps[13] or 0
		local AlessiaAlliance = CyrHUD.imperialKeeps[15] or 0
		local RoebeckAlliance = CyrHUD.imperialKeeps[17] or 0
		
		local AshColor = CyrHUD.info[AshAlliance].color 
		local AleswellColor = CyrHUD.info[AleswellAlliance].color 	
		local ChalmanColor = CyrHUD.info[ChalmanAlliance].color 
		local BlueRoadColor = CyrHUD.info[BlueRoadAlliance].color 
		local AlessiaColor = CyrHUD.info[AlessiaAlliance].color 
		local RoebeckColor = CyrHUD.info[RoebeckAlliance].color 

		
		iconAsh:SetColor(AshColor:UnpackRGBA())
		iconWell:SetColor(AleswellColor:UnpackRGBA())
		iconChal:SetColor(ChalmanColor:UnpackRGBA())
		iconBrk:SetColor(BlueRoadColor:UnpackRGBA())
		iconSia:SetColor(AlessiaColor:UnpackRGBA())
		iconRoe:SetColor(RoebeckColor:UnpackRGBA())
		
		if playerScore:GetText() ~= tostring(self.points) then
       self.startBattle = GetTimeStamp()
    end
	
		rivalName:SetText(self.prevName)
		rivalRank:SetText("#"..self.prevRank)
		rivalScore:SetText(string.format("%+d", self.diffPoints).."p")

		playerName:SetText(self.dName)
		playerRank:SetText("#"..self.rank)  
		playerScore:SetText(self.points)
	
	
		iconAsh:SetHidden(false)
		iconWell:SetHidden(false)
		iconChal:SetHidden(false)
		iconBrk:SetHidden(false)
		iconSia:SetHidden(false)
		iconRoe:SetHidden(false)	
		
		
		iconMem:SetHidden(true)
		iconElv:SetHidden(true)
		iconAre:SetHidden(true)
		iconNob:SetHidden(true)
		iconArb:SetHidden(true)
		iconTem:SetHidden(true)

      rivalName:SetAlpha(0.5)
	    rivalRank:SetAlpha(0.5)
	    rivalScore:SetAlpha(0.5)		
	end
	    --Background color
    label.main:SetCenterColor(self:getBGColor():UnpackRGBA())
end

function bar:getBGColor()

    local delta = GetDiffBetweenTimeStamps(GetTimeStamp(), self.startBattle)

    if delta < 15 then
        return CyrHUD.info.endAttackColor:Lerp(CyrHUD.info.defaultBGColor, delta/30)
    end

    return CyrHUD.info.defaultBGColor
end