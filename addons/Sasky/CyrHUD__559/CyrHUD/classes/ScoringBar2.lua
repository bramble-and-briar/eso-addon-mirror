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
CyrHUD.ScoringBar2 = {}
CyrHUD.ScoringBar2.type = "ScoringBar2"
CyrHUD.ScoringBar2.__index = CyrHUD.ScoringBar2

setmetatable(CyrHUD.ScoringBar2, {
    __call = function(cls, ...) return cls.new(...) end
})

local bar2 = CyrHUD.ScoringBar2

local AD = ALLIANCE_ALDMERI_DOMINION
local DC = ALLIANCE_DAGGERFALL_COVENANT
local EP = ALLIANCE_EBONHEART_PACT

function CyrHUD.ScoringBar2.new(campaign)
    local self = setmetatable({}, CyrHUD.ScoringBar2)

    self.campaign = campaign or GetCurrentCampaignId()
    self:update()

    return self
end

-- runs on the 5-second KeepCheck timer
function bar2:update()
    local myAlliance =  GetUnitAlliance("player")
    local ADscore = GetCampaignAllianceScore(self.campaign, AD)
    local EPscore = GetCampaignAllianceScore(self.campaign, EP)
    local DCscore = GetCampaignAllianceScore(self.campaign, DC)
    
    if myAlliance == AD then
      self.ad_score = ADscore.."p"
      self.ep_score = string.format("%+d", ADscore - EPscore).."p"
      self.dc_score = string.format("%+d", ADscore - DCscore).."p"
    elseif myAlliance == EP then
      self.ad_score = string.format("%+d", EPscore - ADscore).."p"
      self.ep_score = EPscore.."p"
      self.dc_score = string.format("%+d", EPscore - DCscore).."p"
    elseif myAlliance == DC then
      self.ad_score = string.format("%+d", DCscore - ADscore).."p"
      self.ep_score = string.format("%+d", DCscore - EPscore).."p"
      self.dc_score = DCscore.."p"
    end
end

local function GetCampaignTimeRemaining(campaignId)
    local fn = _G.GetCampaignTimeRemaining or _G.GetSecondsUntilCampaignEnd
    if fn and campaignId then
        return fn(campaignId) or 0
    end
    return 0
end

-- Same columns as ScoringBar (Time / DC / EP / AD)
local TEXT_TIME = "txt4"
local TEXT_DC, TEXT_EP, TEXT_AD = "txt1", "txt2", "txt3"

function bar2:configureLabel(label)
    -- show no images, txt1..txt4 only
    label:exposeControls(0, 4)

    -- Rows are reused between types, so hide every other control
    -- (img5+ and txt5+ are not touched by exposeControls)
    for i = 5, 37 do
        label:getControl("img" .. i):SetHidden(true)
    end
    for i = 5, 27 do
        label:getControl("txt" .. i):SetHidden(true)
    end
    label:getControl("img18"):SetAlpha(0) -- animated arrow from Battle rows

    label.main:SetCenterColor(CyrHUD.info.invisColor:UnpackRGBA())

    label:positionControl(TEXT_TIME, 90, 40, 10, 5)
    label:positionControl(TEXT_DC, 50, 40, 100, 5)
    label:positionControl(TEXT_EP, 50, 40, 170, 5)
    label:positionControl(TEXT_AD, 50, 40, 240, 5)

    label:getControl(TEXT_TIME):SetColor(CyrHUD.info[ALLIANCE_NONE].color:UnpackRGBA())
    label:getControl(TEXT_DC):SetColor(CyrHUD.info[DC].color:UnpackRGBA())
    label:getControl(TEXT_EP):SetColor(CyrHUD.info[EP].color:UnpackRGBA())
    label:getControl(TEXT_AD):SetColor(CyrHUD.info[AD].color:UnpackRGBA())
end

function bar2:updateLabel(label)
    local timeControl = label:getControl(TEXT_TIME)
    local textDC, textEP, textAD = label:getControl(TEXT_DC), label:getControl(TEXT_EP), label:getControl(TEXT_AD)

    timeControl:SetText(CyrHUD.formatTime(GetCampaignTimeRemaining(self.campaign), true, false))
    textDC:SetText(self.dc_score)
    textEP:SetText(self.ep_score)
    textAD:SetText(self.ad_score)

    -- same visibility rules as ScoringBar
    local show = IsInJerallPass() or IsInCampaign() or IsInImperialCity()
    timeControl:SetHidden(not show)
    textDC:SetHidden(not show)
    textEP:SetHidden(not show)
    textAD:SetHidden(not show)
end
