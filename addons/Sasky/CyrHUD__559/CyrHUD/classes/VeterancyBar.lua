-- This file is part of CyrHUD
--
-- (C) 2026 Masteroshi430
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
CyrHUD.VeterancyBar = {}
CyrHUD.VeterancyBar.type = "VeterancyBar"
CyrHUD.VeterancyBar.__index = CyrHUD.VeterancyBar

setmetatable(CyrHUD.VeterancyBar, {
    __call = function(cls, ...) return cls.new(...) end
})

local bar = CyrHUD.VeterancyBar

----------------------------------------------
-- Data source
-- Returns: rank, pointsInRank, pointsNeededForNextRank, localizedTitle, iconPath
----------------------------------------------

function bar.getVeterancyData()
    local trackType = REWARD_TRACK_TYPE_AVA_VETERANCY
    local trackId = GetActiveReferenceTrackIdsForRewardTrackType(trackType)
    if not trackId then return nil end

    local trackIndex = GetReferenceTrackIndex(trackType, trackId)
    if not trackIndex then return nil end

    local _, rank, progress = GetInfoForRewardTrack(trackType, trackIndex)
    if not rank then
       return nil
    end

    local total = GetTotalProgressAtRewardTrackTier(
        GetRewardTrackIdFromReferenceTrackId(trackType, trackId),
        rank
    )
    if not total or total <= 0 then total = 100 end
    
    rank = rank + 1 -- getting next rank

    return rank, progress or 0, total, GetVeterancyRankTitle(rank)
end

----------------------------------------------
-- Model
----------------------------------------------

function CyrHUD.VeterancyBar.new()
    local self = setmetatable({}, CyrHUD.VeterancyBar)
    self:update()
    return self
end

function bar:update()
    local rank, current, needed, title = bar.getVeterancyData()

    if rank then
        self.rank = rank
        self.percent = math.min(100, math.floor((current or 0) / needed * 100))

        title = title or ""
        if rank > 100 then
            title = GetString(SI_VETERANCY_REPEATABLE_REWARD_TEXT)
            rank = "∞"
        end
        self.rankText = "#"..rank.." "..title
        self.rankName = self.rankText
    else
        self.rank = self.rank or 0
        self.percent = self.percent or 0
        self.rankText = self.rankText or "--"
        self.rankName = self.rankName or "--"
    end
end

----------------------------------------------
-- Coloured rank name (same idea as CyrHUD.SetColouredName):
-- the first <percent>% of the characters are drawn in the player's
-- alliance color, the remainder in the neutral color.
-- The icon prefix is kept out of the split so its texture markup
-- is never cut in the middle.
----------------------------------------------

function bar:getColouredName()
    -- cached: only rebuild when the text or percent changed
    if self.colouredKey == self.rankName.."|"..self.percent and self.colouredName then
        return self.colouredName
    end

    local text = self.rankText
    local percent = self.percent
    local result

    if percent <= 0 then
        result = text
    elseif percent >= 100 then
        local c = GetAllianceColor(GetUnitAlliance("player"))
        result = "|c"..c:ToHex()..text.."|r"
    else
        local chars = CyrHUD.UTF8ToCharArray(text)
        local limit = math.floor(percent / 100 * #chars)

        if limit == 0 then
            result = text
        else
            local c = GetAllianceColor(GetUnitAlliance("player"))
            local filled, rest = CyrHUD.charArrayToString(chars, limit)
            result = "|c"..c:ToHex()..filled.."|r"

            if #rest > 0 then
                local neutral = CyrHUD.info[ALLIANCE_NONE].color
                local restStr = CyrHUD.charArrayToString(rest, #rest)
                result = result.."|c"..neutral:ToHex()..restStr.."|r"
            end
        end
    end

    self.colouredName = result
    self.colouredKey = self.rankName.."|"..self.percent
    return self.colouredName
end

----------------------------------------------
-- View (reuses the shared label controls)
----------------------------------------------

local TEXT_NAME = "txt17"    -- RankingBar's player name slot (icon + title)
local TEXT_PERCENT = "txt21" -- RankingBar's player score slot
local TEXT_TIME = "txt4"     -- same time column as ScoringBar2

-- every control of the shared label that this bar does NOT use
local HIDE_CONTROLS = {
    "txt18", "txt19", "txt20", "txt22",
    "img25", "img26", "img27", "img28", "img29", "img30", "img31",
    "img32", "img33", "img34", "img35", "img36", "img37",
    "img1", "img2", "img4", "img5", "img6", "img7", "img8",
    "img12", "img13", "img14", "img15", "img16", "img17",
    "txt1", "txt2", "txt3",
    "txt11", "txt12", "txt13", "txt16",
    "txt23", "txt24", "txt25", "txt26", "txt27",
}

function bar:configureLabel(label)
    label:exposeControls(3, 4)

    label:positionControl(TEXT_TIME, 60, 40, 10, 5)
    label:getControl(TEXT_TIME):SetColor(CyrHUD.info[ALLIANCE_NONE].color:UnpackRGBA())
    label:getControl(TEXT_TIME):SetDrawLayer(3)

    label:positionControl(TEXT_NAME, 180, 50, 72, 5)
    label:getControl(TEXT_NAME):SetDrawLayer(3)

    label:positionControl(TEXT_PERCENT, 50, 50, 250, 5)
    label:getControl(TEXT_PERCENT):SetDrawLayer(3)
end

function bar:updateLabel(label)
    for _, name in ipairs(HIDE_CONTROLS) do
        local c = label:getControl(name)
        if c then c:SetHidden(true) end
    end
    local arrow = label:getControl("img18")
    if arrow then arrow:SetAlpha(0) end

    local name = label:getControl(TEXT_NAME)
    local percent = label:getControl(TEXT_PERCENT)
    local time = label:getControl(TEXT_TIME)

    name:SetHidden(false)
    percent:SetHidden(false)
    time:SetHidden(false)

    -- neutral base color for the icon / any uncoloured part
    name:SetColor(CyrHUD.info[ALLIANCE_NONE].color:UnpackRGBA())
    name:SetText(self:getColouredName())
    percent:SetText(self.percent .. "%")

    local remaining = GetCurrentVeterancySeasonTimeRemainingS and GetCurrentVeterancySeasonTimeRemainingS() or 0
    time:SetText(CyrHUD.formatTime(remaining, false, false))

    label.main:SetCenterColor(CyrHUD.info.defaultBGColor:UnpackRGBA())
end
