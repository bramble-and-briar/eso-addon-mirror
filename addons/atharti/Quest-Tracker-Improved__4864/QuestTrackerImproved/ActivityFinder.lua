local QTI = QuestTrackerImproved
local EM = EVENT_MANAGER

local startTimeMs = 0
local timerActive = false
local readyCheckEndsAt = nil
local cachedStatusText = ""

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
	local _, _, timeRemainingSeconds = GetLFGReadyCheckNotificationInfo()
	local readyCheckCountdown = math.max(0, timeRemainingSeconds * 1000)
	return GetFrameTimeMilliseconds() + readyCheckCountdown
end

function QTI.RefreshQueueTimerSubLabel()
	if not timerActive then return end

	local nowMs = GetFrameTimeMilliseconds()
	local timerText

	if readyCheckEndsAt and QTI.IsReadyCheckActive() then
		local readyCheckCountdown = math.max(0, readyCheckEndsAt - nowMs)
		timerText = ZO_FormatTimeMilliseconds(readyCheckCountdown, TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR)
	else
		local queueTime = math.max(0, nowMs - startTimeMs)
		timerText = ZO_FormatTimeMilliseconds(queueTime, TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR)
	end

	ACTIVITY_TRACKER:SetSubLabelText(cachedStatusText .. " - " .. timerText)
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

EM:RegisterForEvent(QTI.name, EVENT_ACTIVITY_FINDER_STATUS_UPDATE, function(_, status)
	QTI.HideInProgress(status)
	cachedStatusText = GetString("SI_ACTIVITYFINDERSTATUS", status)

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

EM:RegisterForEvent(QTI.name, EVENT_PLAYER_ACTIVATED, function()
	local status = GetActivityFinderStatus()
	QTI.HideInProgress(status)

	if not IsCurrentlySearchingForGroup() and status ~= ACTIVITY_FINDER_STATUS_READY_CHECK then
		QTI.StopQueueTimer()
		return
	end

	cachedStatusText = GetString("SI_ACTIVITYFINDERSTATUS", status)

	if status == ACTIVITY_FINDER_STATUS_READY_CHECK then
		readyCheckEndsAt = QTI.GetReadyCheckEndTime()
		QTI.StartQueueTimer()
	else
		startTimeMs = GetLFGSearchTimes()
		QTI.StartQueueTimer()
	end
end)

ZO_PostHook(ACTIVITY_TRACKER, "Update", function()
	if timerActive then
		QTI.RefreshQueueTimerSubLabel()
	end
end)

function QTI.AnchorSharedTrackersUnderQuest()
	local questPanel = FOCUSED_QUEST_TRACKER:GetTrackerControl()

	ZO_HUDTrackers:ClearAnchors()
	ZO_HUDTrackers:SetAnchor(TOPRIGHT, questPanel, BOTTOMRIGHT, 0, 10)

	ZO_PostHook(HUD_TRACKER_MANAGER, "RefreshLayout", function()
		ZO_HUDTrackers:ClearAnchors()
		ZO_HUDTrackers:SetAnchor(TOPRIGHT, questPanel, BOTTOMRIGHT, 0, 10)
	end)
end

