TomesTracker = {}

local TT = TomesTracker
local EM = EVENT_MANAGER
local WM = WINDOW_MANAGER

ZO_CreateStringId("SI_BINDING_NAME_TOMES_TRACKER_TOGGLE", "Toggle Tomes Tracker")

TT.name = "TomesTracker"

TT.areWeeklyCollapsed = false
TT.areSeasonalCollapsed = false

TT.pendingProgressUpdates = {}
TT.isClaimPending = false

local taskControls = {}
local taskBatch = {}

local defaultSV = {
	panelLeft = 100,
	panelTop = 100,
	isHidden = true,
	chatUpdates = true,
	HideCompleted = false,
	panelOpacity = 0.8,
	uiScale = 1.0,
	hideInCombat = false,
	hideRerollsZero = false,
}

local function GetTaskControl(index)
	if not taskControls[index] then
		TT.CreateTaskEntry(index)
	end
	return taskControls[index]
end

function TT.GetTaskData(index)
	local claimed = GetTimedActivityNumTimesClaimed(index)
	local claimable = GetTimedActivityTotalNumTimesClaimable(index)
	local currencyType, rewardQuantity = GetTimedActivityCurrencyRewardInfo(index)

	return {
		index = index,
		name = GetTimedActivityName(index),
		description = GetTimedActivityDescription(index),
		type = GetTimedActivityType(index),
		claimed = claimed,
		claimable = claimable,
		isCompleted = claimed >= claimable,
		progress = GetTimedActivityProgress(index),
		maxProgress = GetTimedActivityMaxProgress(index),
		currencyType = currencyType,
		rewardQuantity = rewardQuantity,
		endTimeS = GetTimedActivityEndTimeS(index),
	}
end

function TT.GetAllTasksData()
	local numActivities = GetNumTimedActivities()
	ZO_ClearNumericallyIndexedTable(taskBatch)
	for index = 1, numActivities do
		taskBatch[index] = TT.GetTaskData(index)
	end
	return taskBatch
end

function TT.RefreshPanel()
	TT_Panel:ClearAnchors()
	TT_Panel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, TT.SV.panelLeft * TT.SV.uiScale, TT.SV.panelTop * TT.SV.uiScale)
	TT_Panel:SetScale(TT.SV.uiScale)
	TT_PanelBG:SetAlpha(TT.SV.panelOpacity)
end

function TT.TogglePanel()
	TT_Panel:ToggleHidden()
	TT.SV.isHidden = TT_Panel:IsHidden()
	return TT.SV.isHidden
end

function TT.IsTaskCompleted(index, taskData)
	taskData = taskData or TT.GetTaskData(index)
	return taskData.isCompleted
end

function TT_Toggle_Panel()
	TT.TogglePanel()
end

function TT.ToggleSection(sectionType, setting)
	if sectionType == "weekly" then
		TT.areWeeklyCollapsed = setting
		TT_PanelWeeklySectionCollapseButton:SetHidden(setting)
		TT_PanelWeeklySectionExpandButton:SetHidden(not setting)
	elseif sectionType == "seasonal" then
		TT.areSeasonalCollapsed = setting
		TT_PanelSeasonalSectionCollapseButton:SetHidden(setting)
		TT_PanelSeasonalSectionExpandButton:SetHidden(not setting)
	end
	TT.RefreshTasksPositions()
end

function TT.OnCombatStateChanged(event, inCombat)
	if inCombat then
		TT_Panel:SetHidden(true)
	else
		TT_Panel:SetHidden(TT.SV.isHidden)
	end
end

function TT.GetTimeRemainingForTaskType(activityType, taskBatch)
	local currentTime = GetTimeStamp()

	if activityType == TIMED_ACTIVITY_TYPE_WEEKLY then
		local resetTimeS = GetTimedActivityTypeResetTimeS(activityType)
		if resetTimeS then
			local timeRemaining = resetTimeS - currentTime
			return math.max(0, timeRemaining)
		end
	elseif activityType == TIMED_ACTIVITY_TYPE_SEASONAL then
		if type(taskBatch) ~= "table" then taskBatch = TT.GetAllTasksData() end
		for index = 1, #taskBatch do
			local taskData = taskBatch[index]
			if taskData.type == activityType and taskData.endTimeS then
				local timeRemaining = taskData.endTimeS - currentTime
				return math.max(0, timeRemaining)
			end
		end
	end
end

function TT.IsTaskTypeCompleted(activityType, taskBatch)
	if type(taskBatch) ~= "table" then taskBatch = TT.GetAllTasksData() end
	for index = 1, #taskBatch do
		local taskData = taskBatch[index]
		if taskData.type == activityType and not taskData.isCompleted then
			return false
		end
	end
	return true
end

function TT.GetTaskRewardsAsText(index, taskData)
	taskData = taskData or TT.GetTaskData(index)
	local currencyIcon = GetCurrencyLootKeyboardIcon(taskData.currencyType)
	return string.format("|cFFFFFF+%i|r |t20:20:%s|t ", taskData.rewardQuantity or 0, currencyIcon)
end

function TT.ClaimAllAvailableRewards()
	if TT.isClaimPending then return end

	if HasAnyUnclaimedTimedActivityRewards() then
		TT.isClaimPending = true
		ClaimAllTimedActivityRewards()
		zo_callLater(function()
			if HasAnyUnclaimedTimedActivityRewards() then
				ClaimAllTimedActivityRewards()
			end
			TT.isClaimPending = false
		end, 1000)
	end
end

local COLORS = {
	green = { r = 0.5, g = 0.5, b = 0.5, a = 1 },
	orange = { r = 0.9, g = 0.7, b = 0.08, a = 1 },
	orangeHex = "E5B214",
	red = { r = 0.8, g = 0.2, b = 0.2, a = 1 },
	white = { r = 1, g = 1, b = 1, a = 1 },
}

function TT.UpdateProgressBar()
	local container = TT_PanelProgressContainer
	local fill = container:GetNamedChild("Fill")
	local label = container:GetNamedChild("Text")
	local pageLabel = TT_PanelPageLabel
	local containerWidth = container:GetWidth()

	fill:SetColor(0, 1, 0, 1)

	local tomeId = TAMRIEL_TOMES_MANAGER:GetActiveTomeId()
	if not tomeId or tomeId == 0 then
		fill:SetWidth(0)
		label:SetText("")
		pageLabel:SetText("")
		return
	end

	local tomeData = ZO_TamrielTomeData:New(tomeId)
	local currentTier = tomeData:GetCurrentTier()
	local numTiers = tomeData:GetNumTotalTiers()

	if currentTier >= numTiers then
		fill:SetWidth(containerWidth - 4)
		label:SetText("")
		pageLabel:SetText("|t20:20:TomesTracker/Textures/success.dds|t")
		return
	end

	local nextTier = currentTier + 1
	local remainingPoints = tomeData:GetCostToProgressToTier(nextTier)
	local PAGE_COST = 2000
	local percent = ((PAGE_COST - remainingPoints) / PAGE_COST) * 100

	local fillMaxWidth = containerWidth - 4
	local fillWidth = math.floor((math.min(percent, 100) / 100) * fillMaxWidth)
	fill:SetWidth(fillWidth)

	label:SetText("+" .. tostring(remainingPoints))

	local nextPage = math.min(currentTier + 1, 12)
	pageLabel:SetText(tostring(nextPage) .. " |t20:20:/esoui/art/miscellaneous/gamepad/gp_icon_locked32.dds|t")
end

function TT.UpdateTaskEntry(index, taskData)
	taskData = taskData or TT.GetTaskData(index)
	local entry = GetTaskControl(index)
	if not entry or not entry.name then return end

	local listEntryName = entry.name

	local progress = taskData.progress
	local maxProgress = taskData.maxProgress
	local isFullyClaimed = taskData.isCompleted
	local taskName = taskData.name

	local shouldColorProgressOrange = (progress > 0) and not isFullyClaimed

	local taskProgressText = ""
	if not isFullyClaimed and maxProgress > 1 then
		if shouldColorProgressOrange then
			taskProgressText = string.format(" (|c%s%d|r/%d)", COLORS.orangeHex, progress, maxProgress)
		else
			taskProgressText = string.format(" (%d/%d)", progress, maxProgress)
		end
	end

	local inlineRewardText = ""
	if not isFullyClaimed and taskData.currencyType and taskData.rewardQuantity then
		local currencyIcon = GetCurrencyLootKeyboardIcon(CURT_TOME_POINTS)
		inlineRewardText = string.format(" |cFFFFFF+%i|r |t16:16:%s|t", taskData.rewardQuantity, currencyIcon)
	end

	local listEntryText = string.format("%s%s%s", taskName, taskProgressText, inlineRewardText)
	listEntryName:SetText(listEntryText)
end

function TT.UpdateTaskProgress(index, taskData)
	taskData = taskData or TT.GetTaskData(index)
	local entry = GetTaskControl(index)
	if not entry then return end

	local listEntryName = entry.name
	local listEntryProgress = entry.progress

	local progress = taskData.progress
	local maxProgress = taskData.maxProgress
	local claimed = taskData.claimed
	local claimable = taskData.claimable

	local progressText = string.format("%i/%i", claimed, claimable)

	if taskData.isCompleted then
		listEntryName:SetColor(COLORS.green.r, COLORS.green.g, COLORS.green.b, COLORS.green.a)
		listEntryProgress:SetColor(COLORS.green.r, COLORS.green.g, COLORS.green.b, COLORS.green.a)
		progressText = "|t20:20:TomesTracker/Textures/success.dds|t"
	elseif (progress > 0 or claimed > 0) and claimed < claimable then
		listEntryName:SetColor(COLORS.white.r, COLORS.white.g, COLORS.white.b, COLORS.white.a)
		listEntryProgress:SetColor(COLORS.orange.r, COLORS.orange.g, COLORS.orange.b, COLORS.orange.a)
	else
		listEntryName:SetColor(COLORS.white.r, COLORS.white.g, COLORS.white.b, COLORS.white.a)
		listEntryProgress:SetColor(COLORS.white.r, COLORS.white.g, COLORS.white.b, COLORS.white.a)
	end

	listEntryProgress:SetText(progressText)
end

function TT.UpdateCurrency()
	local totalTomePoints = GetCurrencyAmount(CURT_TOME_POINTS, CURRENCY_LOCATION_ACCOUNT)
	local texture = "|t20:20:/esoui/art/currency/u49_tt_tomepoints_mipmap.dds|t"
	local formattedPoints = tonumber(totalTomePoints) and string.format("%d", totalTomePoints):reverse():gsub("(%d%d%d)", "%1,"):gsub(",(%-?)$", "%1"):reverse()
	TT_PanelPointsTotal:SetText(string.format("%s %s", formattedPoints, texture))

	local rerollAmount = GetCurrencyAmount(CURT_TOME_CHALLENGE_REROLLS, CURRENCY_LOCATION_ACCOUNT)
	local rerollCount = rerollAmount
	local rerollTexture = "|t28:28:/esoui/art/currency/u49_tt_reroll_mipmaps.dds|t"
	TT_PanelRerollCount:SetText(string.format("%s %d", rerollTexture, rerollCount))

	if TT.SV.hideRerollsZero and rerollCount == 0 then
		TT_PanelRerollCount:SetAlpha(0.0)
	else
		TT_PanelRerollCount:SetAlpha(1.0)
	end
end

function TT.UpdateTaskEntryAnchors(index, taskData)
	taskData = taskData or TT.GetTaskData(index)
	local entry = GetTaskControl(index)
	if not entry then return end

	local activityType = taskData.type
	local rerollButton = entry.rerollButton
	local nameLabel = entry.name
	local progressLabel = entry.progress

	local claimed = taskData.claimed

	if activityType == TIMED_ACTIVITY_TYPE_WEEKLY then
		rerollButton:SetHidden(false)
		if claimed > 0 then
			rerollButton:SetMouseEnabled(false)
			rerollButton:SetAlpha(0.4)
		else
			rerollButton:SetMouseEnabled(true)
			rerollButton:SetAlpha(1)
		end

		nameLabel:ClearAnchors()
		nameLabel:SetAnchor(TOPLEFT, rerollButton, TOPRIGHT, 5, 0)
	else
		rerollButton:SetHidden(true)
		nameLabel:ClearAnchors()
		nameLabel:SetAnchor(TOPLEFT, entry.control, TOPLEFT, 5, 0)
	end

	progressLabel:ClearAnchors()
	progressLabel:SetAnchor(TOPLEFT, nameLabel, TOPRIGHT, 5, 0)
end

function TT.RegisterRerollDialog()
	ZO_CreateStringId("TT_REROLL_DIALOG_HEADER", "Reroll Tome Challenge")

	ESO_Dialogs["TT_REROLL_CONFIRMATION_DIALOG"] = {
		gamepadInfo = {
			dialogType = GAMEPAD_DIALOGS.BASIC,
		},
		title = {
			text = TT_REROLL_DIALOG_HEADER,
		},
		mainText = {
			text = function(dialog)
				return dialog.data.mainText
			end,
		},
		mustChoose = true,
		buttons = {
			[1] = {
				text = SI_DIALOG_ACCEPT,
				callback = function(dialog)
					dialog.data.callback()
				end,
			},
			[2] = {
				text = SI_DIALOG_CANCEL,
			},
		},
	}
end

function TT.RerollTask(index)
	local taskData = TT.GetTaskData(index)
	local taskName = taskData.name
	local taskDesc = taskData.description
	local goldCost = GetGoldCostOfNextTimedActivityReroll()
	local rerollCount = GetCurrencyAmount(CURT_TOME_CHALLENGE_REROLLS, CURRENCY_LOCATION_ACCOUNT)

	local goldIcon = "|t24:24:/esoui/art/currency/currency_gold_64.dds|t"
	local rerollIcon = "|t28:28:/esoui/art/currency/u49_tt_reroll_mipmaps.dds|t"

	local mainText = string.format("Do you want to reroll the following challenge?\n\n|cFFFFFF%s|r\n\n|c888888%s|r", taskName, taskDesc)

	if rerollCount == 0 then
		mainText = mainText .. string.format("\n\nYou are out of %s. Reroll price: |cFFCC33%d|r%s", rerollIcon, goldCost, goldIcon)
	else
		mainText = mainText .. string.format("\n\nThis will consume 1 %s", rerollIcon)
	end

	local dialogParams = {
		callback = function()
			RerollTimedActivity(index)
			TT.RefreshTasks()
		end,
		mainText = mainText
	}

	ZO_Dialogs_ShowDialog("TT_REROLL_CONFIRMATION_DIALOG", dialogParams)
end

function TT.UpdateTasksHeader(activityType, controlHeader, controlProgress, iconPath, taskBatch)
	if type(taskBatch) ~= "table" then taskBatch = TT.GetAllTasksData() end
	local totalCompleted = 0
	local totalClaimable = 0
	local hasAnyProgressOrComplete = false
	local hasAnyClaimed = false

	for index = 1, #taskBatch do
		local taskData = taskBatch[index]
		if taskData.type == activityType then
			local claimed = taskData.claimed
			local claimable = taskData.claimable
			local progress = taskData.progress
			local maxProgress = taskData.maxProgress

			totalCompleted = totalCompleted + claimed
			totalClaimable = totalClaimable + claimable

			if claimed > 0 then
				hasAnyClaimed = true
			end

			if progress > 0 or (progress >= maxProgress and claimed < claimable) then
				hasAnyProgressOrComplete = true
			end
		end
	end

	local progress = string.format("%i/%i", totalCompleted, totalClaimable)

	local timeRemainingS = TT.GetTimeRemainingForTaskType(activityType, taskBatch)
	local timeText = ""
	if timeRemainingS and timeRemainingS > 0 then
		timeText = ZO_FormatTime(timeRemainingS, TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_TWELVE_HOUR_NO_SECONDS, TIME_FORMAT_DIRECTION_DESCENDING)
	end

	local color
	if totalCompleted >= totalClaimable and totalClaimable > 0 then
		color = COLORS.green
	elseif hasAnyProgressOrComplete == true or hasAnyClaimed == true then
		color = COLORS.orange
	else
		color = COLORS.red
	end

	local icon = string.format("|t25:25:%s|t", iconPath)
	local coloredTime = string.format("|c%02x%02x%02x(%s)|r",
		color.r * 255, color.g * 255, color.b * 255, timeText)

	local headerText = string.format("%s %s", icon, coloredTime)
	controlHeader:SetText(headerText)
	controlHeader:SetColor(color.r, color.g, color.b, color.a)

	controlProgress:SetText(progress)
	controlProgress:SetColor(color.r, color.g, color.b, color.a)
end

function TT.OnTaskProgressUpdated(event, index, previousProgress, currentProgress, complete)
	TT.ClaimAllAvailableRewards()

	local taskData = TT.GetTaskData(index)
	local name = taskData.name
	local claimed = taskData.claimed
	local claimable = taskData.claimable
	local maxProgress = taskData.maxProgress

	local iconTomePoints = "|t20:20:esoui/art/currency/gamepad/gp_currency_tomepoints.dds|t "

	if currentProgress >= maxProgress then
		local successTexture = "|t20:20:TomesTracker/Textures/success.dds|t"
		local suffix = string.format(" |cFFFFFF(|r|cFFFF00%d|r|cFFFFFF / %d)|r", claimed + 1, claimable)

		if TT.SV.chatUpdates then
			CHAT_SYSTEM:AddMessage(string.format("|cFFFFFF%s%s|r %s%s", iconTomePoints, name, successTexture, suffix))
		end
	elseif currentProgress > previousProgress then
		if TT.SV.chatUpdates then
			CHAT_SYSTEM:AddMessage(string.format("|cFFFFFF%s%s (|r|cFFFF00%d|r|cFFFFFF / %d)|r", iconTomePoints, name, currentProgress, maxProgress))
		end
	end

	TT.RefreshTasks()
end

function TT.RefreshTasksList(taskBatch)
	if type(taskBatch) ~= "table" then taskBatch = TT.GetAllTasksData() end

	for index = 1, #taskBatch do
		local entry = GetTaskControl(index)
		if entry then
			local taskData = taskBatch[index]
			TT.UpdateTaskEntry(index, taskData)
			TT.UpdateTaskProgress(index, taskData)
		end
	end
end

function TT.RefreshTasksPositions(taskBatch)
	if type(taskBatch) ~= "table" then taskBatch = TT.GetAllTasksData() end
	local lastWeeklyEntry = nil
	local lastSeasonalEntry = nil

	local parentWeekly = TT_WeeklyActivities
	local parentSeasonal = TT_SeasonalActivities

	for index = 1, #taskBatch do
		local entry = GetTaskControl(index)
		local listEntry = entry and entry.control

		if listEntry then
			local taskData = taskBatch[index]
			local activityType = taskData.type

			if TT.SV.HideCompleted and taskData.isCompleted then
				listEntry:SetHidden(true)
			elseif activityType == TIMED_ACTIVITY_TYPE_WEEKLY then
				if not TT.areWeeklyCollapsed then
					listEntry:SetParent(parentWeekly)
					listEntry:ClearAnchors()
					if lastWeeklyEntry then
						listEntry:SetAnchor(TOPLEFT, lastWeeklyEntry, BOTTOMLEFT, 0, 5)
					else
						listEntry:SetAnchor(TOPLEFT, parentWeekly, TOPLEFT, 0, 5)
					end
					listEntry:SetHidden(false)
					TT.UpdateTaskEntryAnchors(index, taskData)
					lastWeeklyEntry = listEntry
				else
					listEntry:SetHidden(true)
				end
			elseif activityType == TIMED_ACTIVITY_TYPE_SEASONAL then
				if not TT.areSeasonalCollapsed then
					listEntry:SetParent(parentSeasonal)
					listEntry:ClearAnchors()
					if lastSeasonalEntry then
						listEntry:SetAnchor(TOPLEFT, lastSeasonalEntry, BOTTOMLEFT, 0, 5)
					else
						listEntry:SetAnchor(TOPLEFT, parentSeasonal, TOPLEFT, 0, 5)
					end
					listEntry:SetHidden(false)
					TT.UpdateTaskEntryAnchors(index, taskData)
					lastSeasonalEntry = listEntry
				else
					listEntry:SetHidden(true)
				end
			end
		end
	end
end

function TT.RefreshTasksHeaders(taskBatch)
	if type(taskBatch) ~= "table" then taskBatch = TT.GetAllTasksData() end
	TT.UpdateTasksHeader(TIMED_ACTIVITY_TYPE_WEEKLY, TT_PanelWeeklySectionHeader, TT_PanelWeeklySectionStatus, "/esoui/art/tamrieltomes/gamepad/gp_timedactivitycategory_weekly.dds", taskBatch)
	TT.UpdateTasksHeader(TIMED_ACTIVITY_TYPE_SEASONAL, TT_PanelSeasonalSectionHeader, TT_PanelSeasonalSectionStatus, "/esoui/art/tamrieltomes/gamepad/gp_timedactivitycategory_seasonal.dds", taskBatch)
end

function TT.RefreshTasks()
	local taskBatch = TT.GetAllTasksData()

	TT.areWeeklyCollapsed = TT.IsTaskTypeCompleted(TIMED_ACTIVITY_TYPE_WEEKLY, taskBatch)
	TT_PanelWeeklySectionCollapseButton:SetHidden(TT.areWeeklyCollapsed)
	TT_PanelWeeklySectionExpandButton:SetHidden(not TT.areWeeklyCollapsed)

	TT.areSeasonalCollapsed = TT.IsTaskTypeCompleted(TIMED_ACTIVITY_TYPE_SEASONAL, taskBatch)
	TT_PanelSeasonalSectionCollapseButton:SetHidden(TT.areSeasonalCollapsed)
	TT_PanelSeasonalSectionExpandButton:SetHidden(not TT.areSeasonalCollapsed)

	TT.RefreshTasksHeaders(taskBatch)
	TT.RefreshTasksList(taskBatch)
	TT.RefreshTasksPositions(taskBatch)
	TT.UpdateCurrency()
	TT.UpdateProgressBar()
end

function TT.CreateTaskEntry(index)
	if taskControls[index] then
		return taskControls[index]
	end

	local controlName = string.format("TT_Task_Index_%i", index)
	local control = WM:CreateControlFromVirtual(controlName, TT_Panel, "TT_TaskTemplate")

	local entry = {
		control = control,
		name = WM:GetControlByName(controlName .. "_Name"),
		progress = WM:GetControlByName(controlName .. "_Progress"),
		rerollButton = WM:GetControlByName(controlName .. "_RerollButton"),
	}

	entry.name.index = index
	entry.progress.index = index
	entry.rerollButton.index = index

	entry.name:SetHandler("OnMouseEnter", function(self)
		local taskData = TT.GetTaskData(self.index)
		local rewardText = TT.GetTaskRewardsAsText(self.index, taskData)
		local tooltipText = string.format("%s\n\n%s", taskData.description, rewardText)

		if TT_Panel:GetLeft() < 400 then
			InitializeTooltip(InformationTooltip, self, LEFT, 10, 0, RIGHT)
		else
			InitializeTooltip(InformationTooltip, self, RIGHT, -10, 0, LEFT)
		end
		SetTooltipText(InformationTooltip, tooltipText)
	end)

	entry.name:SetHandler("OnMouseExit", function()
		ClearTooltip(InformationTooltip)
	end)

	entry.rerollButton:SetHandler("OnClicked", function(self)
		TT.RerollTask(self.index)
	end)

	entry.progress:SetHandler("OnMouseEnter", function(self)
		ZO_Tooltips_ShowTextTooltip(self, RIGHT, self:GetText())
	end)
	entry.progress:SetHandler("OnMouseExit", function()
		ZO_Tooltips_HideTextTooltip()
	end)

	taskControls[index] = entry

	TT.UpdateTaskEntryAnchors(index)
	return taskControls[index]
end

function TT.CreateUI()
	local numActivities = GetNumTimedActivities()
	for index = 1, numActivities do
		TT.CreateTaskEntry(index)
	end

	TT_PanelBG:SetEdgeTexture("TomesTracker/Textures/centerscreen_floating_edge.dds", 256, 256, 30)
	TT_PanelBG:SetCenterTexture("TomesTracker/Textures/centerscreen_floating_center.dds")
	TT_PanelBG:SetInsets(30, 30, -30, -30)
	TT_PanelBG:SetIntegralWrapping(true)
	TT_PanelBG:SetCenterColor(0, 0, 0, 1)
	TT_PanelBG:SetEdgeColor(0, 0, 0, 1)

	TT_Panel:SetHandler("OnMoveStop", function()
		local scale = TT_Panel:GetScale()
		TT.SV.panelLeft = TT_Panel:GetLeft() / scale
		TT.SV.panelTop = TT_Panel:GetTop() / scale
		TT.RefreshTasksList()
	end)

	TT_PanelWeeklySectionExpandButton:SetHandler("OnClicked", function() TT.ToggleSection("weekly", false) end)
	TT_PanelWeeklySectionCollapseButton:SetHandler("OnClicked", function() TT.ToggleSection("weekly", true) end)
	TT_PanelSeasonalSectionExpandButton:SetHandler("OnClicked", function() TT.ToggleSection("seasonal", false) end)
	TT_PanelSeasonalSectionCollapseButton:SetHandler("OnClicked", function() TT.ToggleSection("seasonal", true) end)
end

function TT.OnCurrencyUpdate(_, currencyType)
	if currencyType == CURT_TOME_POINTS or currencyType == CURT_TOME_CHALLENGE_REROLLS then
		TT.UpdateCurrency()
	end
end

function TT.TweakTomesButton()
	local newSize = 64

	ZO_CATEGORY_LAYOUT_INFO[MENU_CATEGORY_TAMRIEL_TOMES].overrideNormalSize = newSize
	ZO_CATEGORY_LAYOUT_INFO[MENU_CATEGORY_TAMRIEL_TOMES].overrideDownSize = newSize

	local buttonObject = MAIN_MENU_KEYBOARD.categoryBar.m_object:ButtonObjectForDescriptor(MENU_CATEGORY_TAMRIEL_TOMES)
	buttonObject.m_buttonData.overrideNormalSize = newSize
	buttonObject.m_buttonData.overrideDownSize = newSize

	buttonObject.m_image:SetDimensions(newSize, newSize)
	buttonObject.m_highlight:SetDimensions(newSize, newSize)

	buttonObject:SetState(buttonObject:GetState(), true)
	MAIN_MENU_KEYBOARD.categoryBar.m_object:UpdateButtons(true)
end

function TT.EarlyProgressCacheHandler(event, index, previousProgress, currentProgress, complete)
	table.insert(TT.pendingProgressUpdates, {
		event = event,
		index = index,
		previousProgress = previousProgress,
		currentProgress = currentProgress,
		complete = complete
	})
end

function TT.Initialize()
	EM:UnregisterForEvent(TT.name, EVENT_PLAYER_ACTIVATED)

	TT.SV = ZO_SavedVars:NewAccountWide("TomesTracker_SV", 1, nil, defaultSV)

	TT.CreateUI()
	TT.RefreshPanel()

	EM:RegisterForEvent(TT.name, EVENT_TIMED_ACTIVITY_PROGRESS_UPDATED, TT.OnTaskProgressUpdated)

	local fragment = ZO_SimpleSceneFragment:New(TT_Panel, nil, 0)
	HUD_SCENE:AddFragment(fragment)
	HUD_UI_SCENE:AddFragment(fragment)

	fragment:RegisterCallback("StateChange", function(oldState, newState)
		if newState == SCENE_FRAGMENT_SHOWN then
			if TT.SV.isHidden then
				TT_Panel:SetHidden(true)
			end
		end
	end)

	TT_Panel:SetHidden(TT.SV.isHidden)

	EM:RegisterForEvent(TT.name, EVENT_CURRENCY_UPDATE, TT.OnCurrencyUpdate)
	EM:RegisterForEvent(TT.name, EVENT_TIMED_ACTIVITIES_UPDATED, TT.RefreshTasks)
	EM:RegisterForUpdate(TT.name .. "RefreshCountdown", 60000, TT.RefreshTasksHeaders)

	if TT.SV.hideInCombat then
		EM:RegisterForEvent(TT.name, EVENT_PLAYER_COMBAT_STATE, TT.OnCombatStateChanged)
	end

	TAMRIEL_TOMES_MANAGER:RegisterCallback("SelectedTomeChanged", TT.UpdateProgressBar)
	TAMRIEL_TOMES_MANAGER:RegisterCallback("AvailableTomesChanged", TT.UpdateProgressBar)

	TT.RegisterLAMPanel()
	TT.RegisterRerollDialog()
	TT.TweakTomesButton()

	TT.RefreshTasks()

	SLASH_COMMANDS["/tt"] = TT.TogglePanel

	for _, cachedEvent in ipairs(TT.pendingProgressUpdates) do
		TT.OnTaskProgressUpdated(
			cachedEvent.event,
			cachedEvent.index,
			cachedEvent.previousProgress,
			cachedEvent.currentProgress,
			cachedEvent.complete
		)
	end

	EM:UnregisterForEvent(TT.name .. "_EarlyCache", EVENT_TIMED_ACTIVITY_PROGRESS_UPDATED)

	ZO_ClearNumericallyIndexedTable(TT.pendingProgressUpdates)
end

function TT.OnAddOnLoaded(event, addonName)
	if addonName == TT.name then
		EM:UnregisterForEvent(TT.name, EVENT_ADD_ON_LOADED)

		EM:RegisterForEvent(TT.name .. "_EarlyCache", EVENT_TIMED_ACTIVITY_PROGRESS_UPDATED, TT.EarlyProgressCacheHandler)

		EM:RegisterForEvent(TT.name, EVENT_PLAYER_ACTIVATED, TT.Initialize)
	end
end

EM:RegisterForEvent(TT.name, EVENT_ADD_ON_LOADED, TT.OnAddOnLoaded)