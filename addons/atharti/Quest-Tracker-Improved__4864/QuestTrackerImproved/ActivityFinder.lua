local QTI = QuestTrackerImproved
local EM = EVENT_MANAGER

local startTimeMs = 0
local timerActive = false
local readyCheckEndsAt = nil
local cachedStatusText = ""
local cachedHeaderIcon = ""

local ICON_DUNGEON_HEADER = "|t28:28:esoui/art/icons/mapkey/mapkey_groupinstance.dds|t"
local ICON_BATTLEGROUND_HEADER = "|t28:28:esoui/art/battlegrounds/gamepad/gp_battlegrounds_tabicon_battlegrounds.dds|t"
local ICON_TRIBUTE_HEADER = "|t28:28:esoui/art/tribute/gamepad/gp_tribute_tabicon_tribute.dds|t"

local HEADER_ICON_OVERRIDE =
{
	[LFG_ACTIVITY_DUNGEON]					  = ICON_DUNGEON_HEADER,
	[LFG_ACTIVITY_MASTER_DUNGEON]			  = ICON_DUNGEON_HEADER,
	[LFG_ACTIVITY_BATTLE_GROUND_CHAMPION]	  = ICON_BATTLEGROUND_HEADER,
	[LFG_ACTIVITY_BATTLE_GROUND_NON_CHAMPION] = ICON_BATTLEGROUND_HEADER,
	[LFG_ACTIVITY_BATTLE_GROUND_LOW_LEVEL]	  = ICON_BATTLEGROUND_HEADER,
	[LFG_ACTIVITY_TRIBUTE_COMPETITIVE]		  = ICON_TRIBUTE_HEADER,
}

function QTI.IsReadyCheckActive()
	return GetActivityFinderStatus() == ACTIVITY_FINDER_STATUS_READY_CHECK
		and HasLFGReadyCheckNotification()
		and not HasAcceptedLFGReadyCheck()
end

function QTI.HideInProgress(status)
	local hide = (status == ACTIVITY_FINDER_STATUS_IN_PROGRESS or status == ACTIVITY_FINDER_STATUS_COMPLETE)
	ACTIVITY_TRACKER:GetFragment():SetHiddenForReason("QTI_ActivityInProgress", hide, DEFAULT_HUD_DURATION, DEFAULT_HUD_DURATION)
end

function QTI.GetReadyCheckEndTime()
	local entry = PLAYER_TO_PLAYER:GetFromIncomingQueue(ZO_INTERACT_TYPE.LFG_READY_CHECK)
	if not entry or not entry.expiresAtS then return nil end
	return entry.expiresAtS * 1000
end

function QTI.RefreshQueueTimerSubLabel()
	if not timerActive then return end

	local nowMs = GetFrameTimeMilliseconds()
	local timerText
	local colorMarkup = ""

	if readyCheckEndsAt and QTI.IsReadyCheckActive() then
		local remainingMs = readyCheckEndsAt - nowMs
		timerText = ZO_FormatTimeMilliseconds(math.max(0, remainingMs), TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR)

		local secondsLeft = remainingMs / 1000
		if secondsLeft > 20 then
			colorMarkup = "|c00FF00"
		elseif secondsLeft > 10 then
			colorMarkup = "|cFFFF00"
		else
			colorMarkup = "|cFF0000"
		end
	else
		local queueTime = math.max(0, nowMs - startTimeMs)
		timerText = QTI.FormatDuration(queueTime)
	end

	ACTIVITY_TRACKER:SetHeaderText(cachedHeaderIcon .. " " .. cachedStatusText .. " - " .. colorMarkup .. timerText .. "|r")
	ACTIVITY_TRACKER:SetSubLabelText("")
end

function QTI.StartQueueTimer()
	if not timerActive then
		timerActive = true
		EM:RegisterForUpdate(QTI.name, 1000, QTI.RefreshQueueTimerSubLabel)
	end
	QTI.RefreshQueueTimerSubLabel()
end

function QTI.StopQueueTimer()
	if not timerActive then return end
	timerActive = false
	readyCheckEndsAt = nil
	startTimeMs = 0
	EM:UnregisterForUpdate(QTI.name)
end

function QTI.FormatDuration(ms)
	local totalSeconds = math.floor(math.max(0, ms) / 1000)
	local hours	  = math.floor(totalSeconds / 3600)
	local minutes = math.floor((totalSeconds % 3600) / 60)
	local seconds = totalSeconds % 60

	if hours > 0 then
		return string.format("%02d:%02d:%02d", hours, minutes, seconds)
	end
	return string.format("%02d:%02d", minutes, seconds)
end

function QTI.ApplyActivityHeaderIcon()
	local activityId = 0
	if IsCurrentlySearchingForGroup() then
		activityId = GetActivityRequestIds(1)
	elseif IsInLFGGroup() then
		activityId = GetCurrentLFGActivityId()
	end

	if activityId == 0 then return "" end
	return HEADER_ICON_OVERRIDE[GetActivityType(activityId)]
end

ZO_PostHook(ACTIVITY_TRACKER, "Update", function()
	if timerActive then
		QTI.RefreshQueueTimerSubLabel()
	end
end)

EM:RegisterForEvent(QTI.name, EVENT_ACTIVITY_FINDER_STATUS_UPDATE, function(_, status)
	QTI.HideInProgress(status)
	cachedStatusText = GetString("SI_ACTIVITYFINDERSTATUS", status)
	cachedHeaderIcon = QTI.ApplyActivityHeaderIcon()

	if status == ACTIVITY_FINDER_STATUS_READY_CHECK then
		readyCheckEndsAt = QTI.GetReadyCheckEndTime()
		QTI.StartQueueTimer()
	elseif status == ACTIVITY_FINDER_STATUS_QUEUED
		or status == ACTIVITY_FINDER_STATUS_FORMING_GROUP
	then
		readyCheckEndsAt = nil
		if startTimeMs == 0 then
			startTimeMs = GetFrameTimeMilliseconds()
		end
		QTI.StartQueueTimer()
	else
		QTI.StopQueueTimer()
	end
end)

EM:RegisterForEvent(QTI.name .. "_LFG_Timer", EVENT_PLAYER_ACTIVATED, function()
	local status = GetActivityFinderStatus()
	QTI.HideInProgress(status)

	if not IsCurrentlySearchingForGroup() and status ~= ACTIVITY_FINDER_STATUS_READY_CHECK then
		QTI.StopQueueTimer()
		return
	end

	cachedStatusText = GetString("SI_ACTIVITYFINDERSTATUS", status)
	cachedHeaderIcon = QTI.ApplyActivityHeaderIcon()

	if status == ACTIVITY_FINDER_STATUS_READY_CHECK then
		readyCheckEndsAt = QTI.GetReadyCheckEndTime()
		QTI.StartQueueTimer()
	else
		startTimeMs = GetLFGSearchTimes()
		QTI.StartQueueTimer()
	end
end)

ZO_PostHook(ACTIVITY_TRACKER, "ApplyPlatformStyle", function()
	ACTIVITY_TRACKER.headerLabel:SetColor(1, 1, 1, 1)
end)