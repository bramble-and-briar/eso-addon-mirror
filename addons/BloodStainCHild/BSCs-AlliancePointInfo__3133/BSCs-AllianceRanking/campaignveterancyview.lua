BSCAllianceRanking = BSCAllianceRanking or {}
local BSCARI = BSCAllianceRanking

local MAX_VETERANCY_ROWS = 100
local MAX_VETERANCY_PROGRESS_RANK = MAX_VETERANCY_ROWS - 1
local VETERANCY_TRACK_TYPE = REWARD_TRACK_TYPE_AVA_VETERANCY

AllianceVeterancyView_Keyboard = ZO_InitializingObject:Subclass()

local function SafeNumber(value, fallback)
    if type(value) == "number" then
        return value
    end
    return fallback or 0
end

local function FormatNumber(value)
    return zo_strformat(SI_NUMBER_FORMAT, SafeNumber(value, 0))
end

local function GetVeterancyTrackInfo()
    if not IsVeterancySeasonActive or not IsVeterancySeasonActive() then
        return nil
    end

    if not VETERANCY_TRACK_TYPE or not GetActiveReferenceTrackIdsForRewardTrackType then
        return nil
    end

    local trackId = GetActiveReferenceTrackIdsForRewardTrackType(VETERANCY_TRACK_TYPE)
    if not trackId or trackId == 0 then
        return nil
    end

    local rewardTrackId = GetRewardTrackIdFromReferenceTrackId(VETERANCY_TRACK_TYPE, trackId)
    local trackIndex = GetReferenceTrackIndex(VETERANCY_TRACK_TYPE, trackId)
    if not rewardTrackId or rewardTrackId == 0 or not trackIndex then
        return nil
    end

    local numBaseRanks = SafeNumber(GetNumBaseTiersForRewardTrack(rewardTrackId), 0)
    local repeatableRank = nil
    if HasInfinitelyRepeatableTierForRewardTrack and HasInfinitelyRepeatableTierForRewardTrack(rewardTrackId) then
        repeatableRank = GetInfinitelyRepeatableTierForRewardTrack(rewardTrackId)
    end

    local _, currentRank, currentProgress = GetInfoForRewardTrack(VETERANCY_TRACK_TYPE, trackIndex)
    return VETERANCY_TRACK_TYPE, trackIndex, rewardTrackId, SafeNumber(currentRank, 0), SafeNumber(currentProgress, 0), numBaseRanks, repeatableRank
end

local function GetVeterancyRankName(rank)
    if GetVeterancyRankTitle then
        local name = GetVeterancyRankTitle(rank)
        if name and name ~= "" then
            return zo_strformat("<<1>>", name)
        end
    end
    return zo_strformat("Veterancy Rank <<1>>", rank)
end

local function GetVeterancyRankTexture(rank)
    if GetVeterancyRankIcon then
        local icon = GetVeterancyRankIcon(rank)
        if icon and icon ~= "" then
            return icon
        end
    end
    return nil
end

local function HideRows(fromIndex)
    if not AllianceVeterancyView_Keyboard.list then return end
    for index = fromIndex, MAX_VETERANCY_ROWS do
        AllianceVeterancyView_Keyboard.list[index]:SetHidden(true)
    end
end

local function ShowMessage(message)
    local list = AllianceVeterancyView_Keyboard.list
    if not list or not list[1] then return end

    local row = list[1]
    row:SetHidden(false)
    row:ClearAnchors()
    row:SetAnchor(TOPLEFT, nil, TOPLEFT, 0, 0)
    row:GetNamedChild("Rank"):SetText("|cffcc00-|r")
    row:GetNamedChild("Name"):SetText("|cffcc00" .. message .. "|r")
    row:GetNamedChild("PointsNeed"):SetText("|cffcc00-|r")
    row:GetNamedChild("PointsNeedTotal"):SetText("|cffcc00-|r")
    row:GetNamedChild("PointsNeedYou"):SetText("|cffcc00-|r")
    HideRows(2)
end

local function BuildList()
    local list = AllianceVeterancyView_Keyboard.list
    if not list then return end

    local _, _, rewardTrackId, currentRank, currentProgress, numBaseRanks, repeatableRank = GetVeterancyTrackInfo()
    if not rewardTrackId then
        ShowMessage("No active Veterancy season")
        return
    end

    local rankCount = numBaseRanks
    if repeatableRank and repeatableRank > rankCount then
        rankCount = repeatableRank
    end
    rankCount = zo_min(rankCount, MAX_VETERANCY_ROWS)

    if rankCount <= 0 then
        ShowMessage("No Veterancy ranks available")
        return
    end

    local cumulativePoints = 0
    local totalPlayerNeeds = 0
    local previousRow = nil

    local maxProgressRank = zo_min(MAX_VETERANCY_PROGRESS_RANK, rankCount - 1)
    local playerIsAtCap = currentRank >= rankCount

    for rank = 1, rankCount do
        local row = list[rank]
        local isCapRank = rank >= rankCount
        local pointsForRank = 0
        if rank <= maxProgressRank then
            pointsForRank = SafeNumber(GetTotalProgressAtRewardTrackTier(rewardTrackId, rank), 0)
            cumulativePoints = cumulativePoints + pointsForRank
        end

        local playerNeedsForRank = 0
        if not playerIsAtCap and rank <= maxProgressRank then
            if rank == currentRank then
                playerNeedsForRank = zo_max(pointsForRank - currentProgress, 0)
            elseif rank > currentRank then
                playerNeedsForRank = pointsForRank
            end
        end
        totalPlayerNeeds = totalPlayerNeeds + playerNeedsForRank

        local txtcolor = "|cE9C62A"
        if rank <= currentRank or playerIsAtCap then
            txtcolor = "|c219129"
        end

        local icon = GetVeterancyRankTexture(rank)
        local rankName = txtcolor .. GetVeterancyRankName(rank)
        if icon then
            rankName = "|t23:23:" .. icon .. "|t|r" .. rankName
        end

        row:SetHidden(false)
        row:GetNamedChild("Rank"):SetText(txtcolor .. rank)
        row:GetNamedChild("Name"):SetText(rankName)
        row:GetNamedChild("PointsNeed"):SetText(isCapRank and (txtcolor .. "-") or (txtcolor .. FormatNumber(pointsForRank)))
        row:GetNamedChild("PointsNeedTotal"):SetText(txtcolor .. FormatNumber(cumulativePoints))
        row:GetNamedChild("PointsNeedYou"):SetText(txtcolor .. FormatNumber(totalPlayerNeeds))
        row:ClearAnchors()
        if previousRow then
            row:SetAnchor(TOPLEFT, previousRow, BOTTOMLEFT, 0, 0)
        else
            row:SetAnchor(TOPLEFT, nil, TOPLEFT, 0, 0)
        end
        previousRow = row
    end

    HideRows(rankCount + 1)
end

function AllianceVeterancyView_Keyboard:Refresh()
    BuildList()
end

function AllianceVeterancyView_Keyboard:Initialize(control)
    AllianceVeterancyView_Keyboard.control = control
    AllianceVeterancyView_Keyboard.list = {}

    for rank = 1, MAX_VETERANCY_ROWS do
        AllianceVeterancyView_Keyboard.list[rank] = WINDOW_MANAGER:CreateControlFromVirtual("CampaignVeterancyViewRow" .. rank, CampaignVeterancyViewPanelScrollChildRankings, "AllianceVeterancyViewRow")
    end

    BSCARI.ALLIANCE_VETERANCYVIEW_FRAGMENT = ZO_FadeSceneFragment:New(control)
    BSCARI.ALLIANCE_VETERANCYVIEW_FRAGMENT:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_FRAGMENT_SHOWING then
            self:Refresh()
        end
    end)
end

function AllianceVeterancyView_Keyboard_OnInitialize(control)
    BSCARI.ALLIANCE_VETERANCYVIEW = AllianceVeterancyView_Keyboard:New(control)
end
