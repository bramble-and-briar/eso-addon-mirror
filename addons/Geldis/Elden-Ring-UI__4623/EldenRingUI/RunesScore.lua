ERUI_RunesScore = {}
local RunesScore = ERUI_RunesScore

RunesScore.MODE_RAW = 1
RunesScore.MODE_ADJUSTED = 2
RunesScore.MODE_NONE = 3

local defaults = {
    mode = RunesScore.MODE_RAW,
}

local fragment
local isVisible = false
local lastText = ""

local function SetText(text)
    if lastText ~= text then
        lastText = text
        ERUI_RunesScoreFrameText:SetText(text)
    end
end

local function FormatScore(score)
    local numericScore = tonumber(score) or 0
    if RunesScore.db.mode == RunesScore.MODE_RAW then
        return tostring(numericScore)
    end
    return tostring(math.max(0, (numericScore - 36000) * 3))
end

local function Show()
    if isVisible then return end
    isVisible = true
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)
end

local function Hide()
    if not isVisible then return end
    isVisible = false
    HUD_SCENE:RemoveFragment(fragment)
    HUD_UI_SCENE:RemoveFragment(fragment)
end

local function StopPolling()
    EVENT_MANAGER:UnregisterForUpdate("ERUI_RunesScore")
end

local function Poll()
    if IsRaidInProgress() then
        SetText(FormatScore(GetCurrentRaidScore()))
    else
        StopPolling()
    end
end

local function StartPolling()
    if RunesScore.db.mode == RunesScore.MODE_NONE then return end
    EVENT_MANAGER:RegisterForUpdate("ERUI_RunesScore", 500, Poll)
    Poll()
end

function RunesScore.ApplyMode()
    StopPolling()
    lastText = ""

    if RunesScore.db.mode == RunesScore.MODE_NONE then
        Hide()
        return
    end

    Show()

    if IsRaidInProgress() then
        StartPolling()
    else
        SetText("0")
    end
end

local function OnTrialEnded(_, _, score)
    if RunesScore.db.mode ~= RunesScore.MODE_NONE then
        SetText(FormatScore(score))
    end
end

local function OnAddOnLoaded(_, addonName)
    if addonName ~= "EldenRingUI" then return end
    EVENT_MANAGER:UnregisterForEvent("ERUI_RunesScore", EVENT_ADD_ON_LOADED)

    RunesScore.db = ZO_SavedVars:NewAccountWide("ERUiVars", 1, "Score", defaults)

    ERUI_RunesScoreFrameText:SetColor(1, 1, 1, 0.75)
    fragment = ZO_HUDFadeSceneFragment:New(ERUI_RunesScoreFrame)

    EVENT_MANAGER:RegisterForEvent("ERUI_RunesScore", EVENT_PLAYER_ACTIVATED, RunesScore.ApplyMode)
    EVENT_MANAGER:RegisterForEvent("ERUI_RunesScore", EVENT_RAID_TRIAL_STARTED, StartPolling)
    EVENT_MANAGER:RegisterForEvent("ERUI_RunesScore", EVENT_RAID_TRIAL_COMPLETE, OnTrialEnded)
    EVENT_MANAGER:RegisterForEvent("ERUI_RunesScore", EVENT_RAID_TRIAL_FAILED, OnTrialEnded)
end

EVENT_MANAGER:RegisterForEvent("ERUI_RunesScore", EVENT_ADD_ON_LOADED, OnAddOnLoaded)