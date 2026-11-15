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

-- Setup class
CyrHUD.PyreLord = {}
CyrHUD.PyreLord.__index = CyrHUD.PyreLord
CyrHUD.PyreLord.type = "PyreLord"

setmetatable(CyrHUD.PyreLord, {
    __call = function (cls, ...)
        return cls.new(...)
    end,
})

-- Row is removed this many seconds after the last announcement
local EXPIRE_AFTER = 1800

----------------------------------------------
-- Creation
----------------------------------------------

CyrHUD.PyreLord.new = function()
    local self = setmetatable({}, CyrHUD.PyreLord)

    self.startPyreLord = GetTimeStamp() -- time of the last announcement
    self.name = "PyreLord"

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

-- Icon colors (r, g, b, a)
local COLOR_BLACK = { 0, 0, 0, 1 }
local COLOR_WHITE = { 1, 1, 1, 1 }

-- States where the Pyre Lord is gone / asleep: black icon
local function isInactiveState(state)
    return state == CYRHUD_STRING_PL_VANISHES
        or state == CYRHUD_STRING_PL_VANQUISHED
        or state == CYRHUD_STRING_PL_SLUMBER
end

function CyrHUD.PyreLord:configureLabel(label)

    label:exposeControls(2,4)

    -- PyreLord icon
    label:positionControl(L_ICON, 28, 28, 3, 3)

    -- PyreLord state text
    label:positionControl(L_NAME, 200, 30, 35, 5)

    -- Time since last announcement
    label:positionControl(L_TIME, 35, 30, 245, 5)

end


function CyrHUD.PyreLord:updateLabel(label)

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

    -- Time elapsed since the last announcement
    timeControl:SetText(CyrHUD.formatTime(self:getRawDuration(), false, true))

    -- State text = last announcement
    local state = CyrHUD.lastPyreLordState
    nameControl:SetText(state or "")
    
    iconControl:SetTexture("/esoui/art/icons/poi/poi_groupboss_complete.dds")


    local alliance = CyrHUD.lastPyreLordAlliance or ALLIANCE_NONE

    if isInactiveState(state) then
        -- vanishes / vanquished / slumber: black icon (text stays white to remain readable)
        iconControl:SetTexture("/esoui/art/icons/poi/poi_groupboss_incomplete.dds")
        nameControl:SetText("The Pyre Lord")
        local color = CyrHUD.info.endAttackColor
        nameControl:SetColor(color:UnpackRGBA())
    elseif alliance ~= ALLIANCE_NONE then
        -- aligned with an alliance: alliance color
        local color = CyrHUD.info[alliance].color
        iconControl:SetColor(color:UnpackRGBA())
        nameControl:SetText("The Pyre Lord")
        nameControl:SetColor(color:UnpackRGBA())
    elseif state == CYRHUD_STRING_PL_AWAKENS or state == CYRHUD_STRING_PL_ENTREAT then
        -- not colored by an alliance: white icon
        iconControl:SetColor(unpack(COLOR_WHITE))
        nameControl:SetColor(unpack(COLOR_WHITE))
        nameControl:SetText("The Pyre Lord")
    else
        -- not colored by an alliance: white icon
        iconControl:SetColor(unpack(COLOR_WHITE))
        nameControl:SetColor(unpack(COLOR_WHITE))
    end

    timeControl:SetColor(CyrHUD.info[ALLIANCE_NONE].color:UnpackRGBA())

    --Background color
    label.main:SetCenterColor(self:getBGColor():UnpackRGBA())
end

----------------------------------------------
-- Model update
----------------------------------------------

function CyrHUD.PyreLord:update()
    if self:getRawDuration() > (EXPIRE_AFTER * 3) then
        CyrHUD.PyreLords[self.name] = nil
    end
end

-- Called on every new announcement: resets the timer
function CyrHUD.PyreLord:restart()
    self.startPyreLord = GetTimeStamp()
end

----------------------------------------------
-- Getters
----------------------------------------------

--[[
    @return background color: flashes red for the first minute after an announcement
--]]
function CyrHUD.PyreLord:getBGColor()
    local delta = self:getRawDuration()

    if delta < 60 then
        return CyrHUD.info.newAttackColor:Lerp(CyrHUD.info.defaultBGColor, delta/60)
    end

    return CyrHUD.info.defaultBGColor
end

--[[
    @return seconds elapsed since the last announcement
--]]
function CyrHUD.PyreLord:getRawDuration()
    return GetDiffBetweenTimeStamps(GetTimeStamp(), self.startPyreLord)
end
