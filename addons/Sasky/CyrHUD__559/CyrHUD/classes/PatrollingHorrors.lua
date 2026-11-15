-- This file is part of CyrHUD
--
-- (C) 2014 Scott Yeskie (Sasky)
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

local function n0(val) if val == nil then return 0 end return val end

-- Setup class
CyrHUD.PatrollingHorror = {}
CyrHUD.PatrollingHorror.__index = CyrHUD.PatrollingHorror
CyrHUD.PatrollingHorror.type = "PatrollingHorror"

setmetatable(CyrHUD.PatrollingHorror, {
    __call = function (cls, ...)
        return cls.new(...)
    end,
})


local shortenDistrictName = function(str)
    return str:gsub(",..$", ""):gsub("%^.d$", "")
	--EN
	    --:gsub("Elder Scroll of ", "")
end

----------------------------------------------
-- Creation
----------------------------------------------

CyrHUD.PatrollingHorror.new = function(bossDistrict, alive)
    local self = setmetatable({}, CyrHUD.PatrollingHorror)

    self.startPatrollingHorror = GetTimeStamp()
    self.endPatrollingHorror = nil
    self.name = bossDistrict

    if alive then -- avoid countdown, go straight to timer
	    self.startPatrollingHorror = GetTimeStamp() - 900
	end

    return self
end

----------------------------------------------
-- Label update
----------------------------------------------

--Label fields
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
	
function CyrHUD.PatrollingHorror:configureLabel(label)
	
    label:exposeControls(2,4)

    -- PatrollingHorror icon
    label:positionControl(L_ICON, 28, 28, 3, 3)

    -- PatrollingHorror name
    label:positionControl(L_NAME, 150, 30, 35, 5)

    --Time
    label:positionControl(L_TIME, 35, 30, 245, 5)

end


function CyrHUD.PatrollingHorror:updateLabel(label)

	-- turn off other module's stuff
  label:getControl(L_UA):SetHidden(true)
	label:getControl(L_LUMB):SetHidden(true)
	label:getControl(L_MINE):SetHidden(true)
	label:getControl(L_FARM):SetHidden(true)
  label:getControl(L_SCROLL):SetHidden(true)
	label:getControl(L_ATT_SIEGE):SetHidden(true)
	label:getControl(L_DEF_SIEGE):SetHidden(true)
	label:getControl(CYROCHAT_ICON):SetHidden(true)
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
  label:getControl(L_ATT_SIEGE_ICON):SetHidden(true)
	label:getControl(L_DEF_SIEGE_ICON):SetHidden(true)
	label:getControl(L_CONNECTED):SetHidden(true)
	label:getControl(L_HOLDER):SetHidden(true)
	label:getControl(L_ARROW):SetAlpha(0)
	
	label:getControl(ICON_EMPEROR):SetHidden(true)
	label:getControl(TEXT_PLAYERNAME):SetHidden(true)
	label:getControl(TEXT_RIVALNAME):SetHidden(true)
	label:getControl(TEXT_PLAYERRANK):SetHidden(true)
	label:getControl(TEXT_RIVALRANK):SetHidden(true)
	label:getControl(TEXT_PLAYERSCORE):SetHidden(true)
	label:getControl(TEXT_RIVALSCORE):SetHidden(true)
	label:getControl(ICON_ASH):SetHidden(true)
	label:getControl(ICON_WELL):SetHidden(true)
	label:getControl(ICON_CHAL):SetHidden(true)
	label:getControl(ICON_BRK):SetHidden(true)
	label:getControl(ICON_SIA):SetHidden(true)
	label:getControl(ICON_ROE):SetHidden(true)
	

	local nameControl = label:getControl(L_NAME)
	local iconControl = label:getControl(L_ICON)
	local timeControl = label:getControl(L_TIME)

	nameControl:SetHidden(false)
	iconControl:SetHidden(false)
	timeControl:SetHidden(false)
    
	local time = 900 - self:getRawDuration()
	local formattedTime = CyrHUD.formatTime(math.abs(time), false, true)


    --Time
    timeControl:SetText(formattedTime)
	
	 -- PatrollingHorror name
	nameControl:SetText(self.name) 
	
    -- PatrollingHorror icon
	 iconControl:SetColor(ZO_ColorDef:New(1,1,1,1):UnpackRGBA())
	
	if time > 0 then -- not yet respawned
	
	     -- PatrollingHorror icon
         iconControl:SetTexture("/esoui/art/icons/poi/poi_groupboss_complete.dds")
		 
		-- PatrollingHorror name
		nameControl:SetColor(CyrHUD.info[ALLIANCE_NONE].color:UnpackRGBA())
		
		--Time
		timeControl:SetColor(CyrHUD.info[ALLIANCE_NONE].color:UnpackRGBA())
		 
	else -- presumably respawned
	
	     -- PatrollingHorror icon
	     iconControl:SetTexture("/esoui/art/icons/poi/poi_groupboss_incomplete.dds")
		 
		-- PatrollingHorror name
		nameControl:SetColor(GetBattlegroundTeamColor(2):UnpackRGBA())
		
		--Time
		timeControl:SetColor(GetBattlegroundTeamColor(2):UnpackRGBA())
	end
	
	
	
	
	
	if self.endPatrollingHorror then 
	    iconControl:SetTexture("/esoui/art/icons/poi/poi_groupboss_complete.dds")
	    nameControl:SetColor(CyrHUD.info[2].color:UnpackRGBA())
        timeControl:SetColor(CyrHUD.info[2].color:UnpackRGBA())
		timeControl:SetText("XX") -- GetString(SI_UNIT_FRAME_STATUS_DEAD)
	end 


    --Background color
    label.main:SetCenterColor(self:getBGColor():UnpackRGBA())
end

----------------------------------------------
-- Model update
----------------------------------------------

function CyrHUD.PatrollingHorror:update()
        if self.endPatrollingHorror then
            --Remove after time
            if GetDiffBetweenTimeStamps(GetTimeStamp(), self.endPatrollingHorror) > 15 then
                CyrHUD.PatrollingHorrors[self.name] = nil
            end
        end		
end

function CyrHUD.PatrollingHorror:restart()
    self.endPatrollingHorror = nil
	self.startPatrollingHorror = GetTimeStamp()
end



----------------------------------------------
-- Getters
----------------------------------------------

--[[
    @return red, green, blue, alpha for background color
        all in range [0,1]
--]]
function CyrHUD.PatrollingHorror:getBGColor()
    if self.endPatrollingHorror then
        return CyrHUD.info.endAttackColor
    end

    local delta = GetDiffBetweenTimeStamps(GetTimeStamp(), self.startPatrollingHorror)

    if delta < 60 then
        return CyrHUD.info.newAttackColor:Lerp(CyrHUD.info.defaultBGColor, delta/60)
    end

    return CyrHUD.info.defaultBGColor
end

--[[
    @return elapsed time of battle event
        if an end is specified, will show total lenth
        otherwise will show current length
--]]
-- function CyrHUD.PatrollingHorror:getDuration(time)
    -- return CyrHUD.formatTime(time, false, true)
-- end

function CyrHUD.PatrollingHorror:getRawDuration()
    return GetDiffBetweenTimeStamps(self.endPatrollingHorror or GetTimeStamp(), self.startPatrollingHorror)
end
