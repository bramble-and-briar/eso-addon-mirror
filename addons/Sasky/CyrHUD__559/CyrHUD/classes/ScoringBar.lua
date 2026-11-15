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
CyrHUD.ScoringBar = {}
CyrHUD.ScoringBar.type = "ScoringBar"
CyrHUD.ScoringBar.__index = CyrHUD.ScoringBar

setmetatable(CyrHUD.ScoringBar, {
    __call = function(cls, ...) return cls.new(...) end
})

local bar = CyrHUD.ScoringBar

local AD = ALLIANCE_ALDMERI_DOMINION
local DC = ALLIANCE_DAGGERFALL_COVENANT
local EP = ALLIANCE_EBONHEART_PACT

function CyrHUD.ScoringBar.new(campaign)
    local self = setmetatable({}, CyrHUD.ScoringBar)

    self.campaign = campaign or GetCurrentCampaignId()
    self:determineCampaignIndex()
    self:update()

    return self
end

function bar:determineCampaignIndex()
    --d("Calling findCampaignIndex for " .. self.campaign)
    self.campaignIndex = 0

    for i = 1, GetNumSelectionCampaigns() do
        local id = GetSelectionCampaignId(i)

        if self.campaign == id then
            --d("Result: " .. i)
            self.campaignIndex = i
        end
    end

    if self.campaignIndex == 0 then
        --d("No campaign index. Running QueryCampaignSelectionData()")
        QueryCampaignSelectionData()
        zo_callLater(function() self:determineCampaignIndex() end, 2000)
    end
end

local slowUpdate = 0

function bar:update()
    self.ad_points = GetCampaignAlliancePotentialScore(self.campaign, AD)
    self.dc_points = GetCampaignAlliancePotentialScore(self.campaign, DC)
    self.ep_points = GetCampaignAlliancePotentialScore(self.campaign, EP)
	
  	self.ad_lowPopBonus = IsUnderpopBonusEnabled(self.campaign, AD)
    self.dc_lowPopBonus = IsUnderpopBonusEnabled(self.campaign, DC)
    self.ep_lowPopBonus = IsUnderpopBonusEnabled(self.campaign, EP)
	
	-- 05/07/2026 performance improvement:
	-- bar:update() runs on the 5-second KeepCheck timer. self.ad_score,
	-- self.dc_score, and self.ep_score were each populated via a separate
	-- GetCampaignAllianceScore() engine call, but none of the three fields are
	-- ever read anywhere else in this file or the rest of the addon -- they
	-- were computed and stored purely to be discarded. Removing them drops
	-- three unused engine round-trips every update cycle with zero change in
	-- observable behavior.
	self.UnderdogleaderAlliance = GetCampaignUnderdogLeaderAlliance(self.campaign)
	

    if CyrHUD.cfg.showPopBars then
        self.ad_pop = GetSelectionCampaignPopulationData(self.campaignIndex, AD)
        self.dc_pop = GetSelectionCampaignPopulationData(self.campaignIndex, DC)
        self.ep_pop = GetSelectionCampaignPopulationData(self.campaignIndex, EP)

        -- Main update is every 5s
        -- Only refresh population bar data once every 3min
        slowUpdate = slowUpdate + 1

        if slowUpdate >= 36 then
            QueryCampaignSelectionData()
            slowUpdate = 0
        end
    end
end

local TEXT_TIME = "txt4"
local ICON_DC, ICON_EP, ICON_AD = "img1", "img2", "img3"
local TEXT_DC, TEXT_EP, TEXT_AD = "txt1", "txt2", "txt3"
--local TEXT_DCIK, TEXT_EPIK, TEXT_ADIK = "txt5", "txt6", "txt7" -- reuse
local SCROLL_DC, SCROLL_EP, SCROLL_AD = "img9", "img10", "img11"
local TEXT_SCROLL_DC, TEXT_SCROLL_EP, TEXT_SCROLL_AD = "txt8", "txt9", "txt10"
local LowPopBonus_DC, LowPopBonus_EP, LowPopBonus_AD = "img19", "img20", "img21"
local LowScoreBonus_DC, LowScoreBonus_EP, LowScoreBonus_AD = "img22", "img23", "img24"

function bar:configureLabel(label)
  label:exposeControls(3,4)
  label.main:SetCenterColor(CyrHUD.info.invisColor:UnpackRGBA())
  label:getControl(ICON_DC):SetTexture(CyrHUD.info[DC].flag)
  label:getControl(ICON_EP):SetTexture(CyrHUD.info[EP].flag)
  label:getControl(ICON_AD):SetTexture(CyrHUD.info[AD].flag)
	label:getControl(ICON_DC):SetDrawLayer(3)
	label:getControl(ICON_EP):SetDrawLayer(3)
	label:getControl(ICON_AD):SetDrawLayer(3)
  label:getControl(SCROLL_DC):SetTexture(CyrHUD.icons["scrollDC"])
  label:getControl(SCROLL_EP):SetTexture(CyrHUD.icons["scrollEP"])
  label:getControl(SCROLL_AD):SetTexture(CyrHUD.icons["scrollAD"])
	label:getControl(SCROLL_DC):SetDrawLayer(2)
	label:getControl(SCROLL_EP):SetDrawLayer(2)
	label:getControl(SCROLL_AD):SetDrawLayer(2)
	
	label:getControl(LowPopBonus_DC):SetTexture(CyrHUD.icons["lowPopBonus"])
	label:getControl(LowPopBonus_DC):SetDrawLayer(3)
	label:positionControl(LowPopBonus_DC, 24, 24,  57, -5)
	label:getControl(LowPopBonus_EP):SetTexture(CyrHUD.icons["lowPopBonus"])
	label:getControl(LowPopBonus_EP):SetDrawLayer(3)
	label:positionControl(LowPopBonus_EP, 24, 24, 127, -5)
	label:getControl(LowPopBonus_AD):SetTexture(CyrHUD.icons["lowPopBonus"])
	label:getControl(LowPopBonus_AD):SetDrawLayer(3)
	label:positionControl(LowPopBonus_AD, 24, 24, 197, -5)
        
 	label:getControl(LowScoreBonus_DC):SetTexture(CyrHUD.icons["lowScoreBonus"])
	label:getControl(LowScoreBonus_DC):SetDrawLayer(3)
	label:positionControl(LowScoreBonus_DC, 24, 24,  98, -5)
	
	label:getControl(LowScoreBonus_EP):SetTexture(CyrHUD.icons["lowScoreBonus"])
	label:getControl(LowScoreBonus_EP):SetDrawLayer(3)
	label:positionControl(LowScoreBonus_EP, 24, 24, 168, -5)
	
	label:getControl(LowScoreBonus_AD):SetTexture(CyrHUD.icons["lowScoreBonus"])
	label:getControl(LowScoreBonus_AD):SetDrawLayer(3)
	label:positionControl(LowScoreBonus_AD, 24, 24, 238, -5) 
	
	label:getControl(LowScoreBonus_DC):SetColor(CyrHUD.info[DC].color:UnpackRGBA())
  label:getControl(LowScoreBonus_EP):SetColor(CyrHUD.info[EP].color:UnpackRGBA())
  label:getControl(LowScoreBonus_AD):SetColor(CyrHUD.info[AD].color:UnpackRGBA())
	
	label:getControl(LowPopBonus_DC):SetColor(CyrHUD.info[DC].color:UnpackRGBA())
  label:getControl(LowPopBonus_EP):SetColor(CyrHUD.info[EP].color:UnpackRGBA())
  label:getControl(LowPopBonus_AD):SetColor(CyrHUD.info[AD].color:UnpackRGBA())
	
	

    label:positionControl(TEXT_SCROLL_DC, 50, 40, 86, -4)
    label:positionControl(TEXT_SCROLL_EP, 50, 40, 156, -4)
    label:positionControl(TEXT_SCROLL_AD, 50, 40, 226, -4)
	  label:getControl(TEXT_SCROLL_DC):SetDrawLayer(3)
	  label:getControl(TEXT_SCROLL_EP):SetDrawLayer(3)
	  label:getControl(TEXT_SCROLL_AD):SetDrawLayer(3)
    label:positionControl(TEXT_TIME, 90, 40, 10, 10)
    label:positionControl(TEXT_DC, 50, 40, 100, 10)
    label:positionControl(TEXT_EP, 50, 40, 170, 10)
    label:positionControl(TEXT_AD, 50, 40, 240, 10)
    label:positionControl(SCROLL_DC, 32, 32, 73, -09)
    label:positionControl(SCROLL_EP, 32, 32, 143, -09)
    label:positionControl(SCROLL_AD, 32, 32, 213, -09)

    label:getControl(TEXT_DC):SetColor(CyrHUD.info[DC].color:UnpackRGBA())
    label:getControl(TEXT_EP):SetColor(CyrHUD.info[EP].color:UnpackRGBA())
    label:getControl(TEXT_AD):SetColor(CyrHUD.info[AD].color:UnpackRGBA())
	
	

    if CyrHUD.cfg.showPopBars then
        label:getControl(ICON_DC):SetColor(CyrHUD.info[DC].color:UnpackRGBA())
        label:getControl(ICON_EP):SetColor(CyrHUD.info[EP].color:UnpackRGBA())
        label:getControl(ICON_AD):SetColor(CyrHUD.info[AD].color:UnpackRGBA())
        label:positionControl(ICON_DC, 28, 28,  72, 7)
        label:positionControl(ICON_EP, 28, 28, 142, 7)
        label:positionControl(ICON_AD, 28, 28, 212, 7)
    else
        label:getControl(ICON_DC):SetColor(CyrHUD.info[ALLIANCE_NONE].color:UnpackRGBA())
        label:getControl(ICON_EP):SetColor(CyrHUD.info[ALLIANCE_NONE].color:UnpackRGBA())
        label:getControl(ICON_AD):SetColor(CyrHUD.info[ALLIANCE_NONE].color:UnpackRGBA())
        label:positionControl(ICON_DC, 30, 30,  75, 10) -- 20, 40, 80, 10
        label:positionControl(ICON_EP, 30, 30, 145, 10) -- 20, 40, 150, 10
        label:positionControl(ICON_AD, 30, 30, 215, 10) -- 20, 40, 220, 10
    end
end

function bar:updateLabel(label)
  local pre = "+"
	local timeControl = label:getControl(TEXT_TIME)
	local textDC, textEP, textAD = label:getControl(TEXT_DC), label:getControl(TEXT_EP), label:getControl(TEXT_AD)
	local lowPopAD, lowPopDC, lowPopEP = label:getControl(LowPopBonus_AD), label:getControl(LowPopBonus_DC), label:getControl(LowPopBonus_EP)
	local lowScoreAD, lowScoreDC, lowScoreEP = label:getControl(LowScoreBonus_AD), label:getControl(LowScoreBonus_DC), label:getControl(LowScoreBonus_EP)
	local textScrollDC, textScrollEP, textScrollAD = label:getControl(TEXT_SCROLL_DC), label:getControl(TEXT_SCROLL_EP), label:getControl(TEXT_SCROLL_AD)
	local scrollDC, scrollEP, scrollAD = label:getControl(SCROLL_DC), label:getControl(SCROLL_EP), label:getControl(SCROLL_AD)
	local iconDC, iconAD, iconEP = label:getControl(ICON_DC), label:getControl(ICON_AD), label:getControl(ICON_EP)

    timeControl:SetText(CyrHUD.formatTime(GetSecondsUntilCampaignScoreReevaluation(self.campaign), true, false))
    textDC:SetText(pre..self.dc_points.."p")
    textEP:SetText(pre..self.ep_points.."p")
    textAD:SetText(pre..self.ad_points.."p")
	
	
	------ low pop bonus
	if self.ad_lowPopBonus == true then
	     lowPopAD:SetHidden(false)
	else
	     lowPopAD:SetHidden(true)
	end
	
	if self.dc_lowPopBonus == true then
	     lowPopDC:SetHidden(false)
	else
	     lowPopDC:SetHidden(true)
	end
	
	if self.ep_lowPopBonus == true then
	     lowPopEP:SetHidden(false)
	else
	     lowPopEP:SetHidden(true)
	end
	
	
	------ low score bonus
	if self.UnderdogleaderAlliance == 0 then
	     lowScoreAD:SetHidden(true)
		 lowScoreDC:SetHidden(true)
		 lowScoreEP:SetHidden(true)
	elseif self.UnderdogleaderAlliance == AD then
	     lowScoreAD:SetHidden(true)
		 lowScoreDC:SetHidden(false)
		 lowScoreEP:SetHidden(false)
	elseif self.UnderdogleaderAlliance == DC then
	     lowScoreAD:SetHidden(false)
		 lowScoreDC:SetHidden(true)
		 lowScoreEP:SetHidden(false)
	elseif self.UnderdogleaderAlliance == EP then
	     lowScoreAD:SetHidden(false)
		 lowScoreDC:SetHidden(false)
		 lowScoreEP:SetHidden(true)
	end
	

    textScrollDC:SetText(CyrHUD.DCscrolls)
    textScrollEP:SetText(CyrHUD.EPscrolls)
    textScrollAD:SetText(CyrHUD.ADscrolls)

    if CyrHUD.cfg.showPopBars then
        iconDC:SetTexture(ZO_CampaignBrowser_GetPopulationIcon(self.dc_pop))
        iconAD:SetTexture(ZO_CampaignBrowser_GetPopulationIcon(self.ad_pop))
        iconEP:SetTexture(ZO_CampaignBrowser_GetPopulationIcon(self.ep_pop))
    end
	
	

   if IsInCampaign() and not IsInImperialCity() and not IsInJerallPass() then
     timeControl:SetHidden(false)
	   textDC:SetHidden(false)
	   textEP:SetHidden(false)
	   textAD:SetHidden(false)
	   scrollDC:SetHidden(false)
	   scrollEP:SetHidden(false)
	   scrollAD:SetHidden(false)
	   textScrollDC:SetHidden(false)
	   textScrollEP:SetHidden(false)
	   textScrollAD:SetHidden(false)
     
   elseif IsInJerallPass() then
     timeControl:SetHidden(false)
	   textDC:SetHidden(false)
	   textEP:SetHidden(false)
	   textAD:SetHidden(false)
	   scrollDC:SetHidden(true)
	   scrollEP:SetHidden(true)
	   scrollAD:SetHidden(true)
	   textScrollDC:SetHidden(true)
	   textScrollEP:SetHidden(true)
	   textScrollAD:SetHidden(true)
     
   else -- Imperial City
     timeControl:SetHidden(false)
	   textDC:SetHidden(false)
	   textEP:SetHidden(false)
	   textAD:SetHidden(false)
	   scrollDC:SetHidden(true)
	   scrollEP:SetHidden(true)
	   scrollAD:SetHidden(true)
	   textScrollDC:SetHidden(true)
	   textScrollEP:SetHidden(true)
	   textScrollAD:SetHidden(true)
   end
end
