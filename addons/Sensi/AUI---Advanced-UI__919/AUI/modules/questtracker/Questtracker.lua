AUI.Questtracker = {}

local AUI_QUESTTRACKER_SCENE_FRAGMENT = nil
local AUI_QUESTTRACKER_REPEAT_ICON = "EsoUI/Art/Journal/journal_Quest_Repeat.dds"
local AUI_QUESTTRACKER_DAILY_ICON = "EsoUI/Art/Miscellaneous/timer_32.dds"
local AUI_QUESTTRACKER_FOCUSED_ICON = "EsoUI/Art/Quest/questjournal_trackedquest_icon.dds"
local AUI_QUESTTRACKER_ASSISTED_HEADER_TEXT_COLOR = "#ffaf61"
local AUI_QUESTTRACKER_ASSISTED_QUEST_TEXT_COLOR = "#f1ff52"
local AUI_QUESTTRACKER_ASSISTED_CONDITION_TEXT_COLOR = "#d9d9d9"
local AUI_QUESTTRACKER_HEADER_TEXT_COLOR = "#ffffff"
local AUI_QUESTTRACKER_QUEST_TEXT_COLOR = "#f6f39c"
local AUI_QUESTTRACKER_CONDITION_TEXT_COLOR = "#d9d9d9"
local AUI_QUESTTRACKER_REMAIN_TIMER_TEXT_COLOR = "#ffaf61"
local AUI_QUESTTRACKER_QUEST_LOG_INFO_NORMAL_TEXT_COLOR = "#ffffff"
local AUI_QUESTTRACKER_QUEST_LOG_INFO_FULL_TEXT_COLOR = "#ff5f5f"
local AUI_QUESTTRACKER_MIN_HEIGHT = 151
local AUI_QUESTTRACKER_QUEST_COMPLETED_OPACITY = 0.7

local g_isInit = false
local g_itemList = {}
local g_catList = {}
local g_isQuestTimeActive = false
local g_nextZoneCatId = 0

function AUI.Questtracker.g_isInit()
	if g_isInit then
		return true
	end
	
	return false
end

local function AUI_Questtracker_OnMouseDown(_eventCode, _button, _ctrl, _alt, _shift)
	if _button == 1 and not AUI.Settings.Questtracker.lock_window then
		AUI_Questtracker:SetMovable(true)
		AUI_Questtracker:StartMoving()
	end
end

local function AUI_Questtracker_OnMouseUp(_eventCode, _button, _ctrl, _alt, _shift)
	AUI_Questtracker:SetMovable(false)	

	if _button == 1 and not AUI.Settings.Questtracker.lock_window then
		_, AUI.Settings.Questtracker.anchor.point, _, AUI.Settings.Questtracker.anchor.relativePoint, AUI.Settings.Questtracker.anchor.offsetX, AUI.Settings.Questtracker.anchor.offsetY = AUI_Questtracker:GetAnchor()
	end
end

local function AddCategory(_catId, _sortId, _catName, _color, _icon)
	local catData = nil
	local fontSize = AUI.Settings.Questtracker.font_size * 1.1
	
	if not g_catList[_catId] then
		catData =
		{
			[1] = 
			{
				["ControlType"] = "texture",
				["TextureFile"] = _icon,
				["SortType"] = "number",				
				["SortValue"] = _sortId,
				["OffsetX"] = 0,
				["OffsetY"] = -1,
				["TextureWidth"] = fontSize + 8,
				["TextureHeight"] = fontSize + 8,				
			}, 
			[2] = 
			{
				["ControlType"] = "label",
				["Value"] = _catName,
				["HorizontalTextAlign"] = TEXT_ALIGN_LEFT,
				["Color"] = AUI.Color.ConvertHexToRGBA(_color, 1),				
				["Font"] = (AUI.Settings.Questtracker.font_art .. "|" .. fontSize .. "|" .. "thick-outline")
			},	
			[3] = 
			{
				["ControlType"] = "texture",
			},					
		}
		
		table.insert(g_itemList, catData)
		
		return true
	end
	
	return false
end

local function AddQuestName(_sortId, _questName, _color, _questIcon, _questTypeIcon, _textureWidth, _textureHeight, _opacity)
	local fontSize = AUI.Settings.Questtracker.font_size / 1.1
	
	local questData =
	{
		[1] = 
		{
			["ControlType"] = "texture",
			["TextureFile"] = _questIcon,
			["SortType"] = "number",
			["SortValue"] = _sortId,
			["OffsetX"] = 20,
			["OffsetY"] = 10,
			["TextureWidth"] = fontSize - 2,		
			["TextureHeight"] = fontSize - 2,					
		}, 
		[2] = 
		{
			["ControlType"] = "label",
			["Value"] = "      " .. _questName,
			["SortValue"] = _questName,
			["SortType"] = "string",
			["OffsetX"] = -2,
			["OffsetY"] = 8,
			["HorizontalTextAlign"] = TEXT_ALIGN_LEFT,
			["Color"] = AUI.Color.ConvertHexToRGBA(_color, 1),
			["Font"] = (AUI.Settings.Questtracker.font_art .. "|" .. fontSize  .. "|" .. "outline")	,				
			["Opacity"] = _opacity,
		},	
		[3] = 
		{
			["ControlType"] = "texture",
			["TextureFile"] = _questTypeIcon,
			["OffsetX"] = 10,
			["TextureWidth"] = _textureWidth,
			["TextureHeight"] = _textureHeight,
			["OffsetY"] = 4,
		},				
	}
	
	table.insert(g_itemList, questData)	
end

local function AddQuestCondition(_sortId, _text, _color)
	local conditionData =
	{
		[1] = 
		{
			["ControlType"] = "label",
			["Value"] = "",
			["SortType"] = "number",				
			["SortValue"] = _sortId,					
		}, 
		[2] = 
		{
			["ControlType"] = "label",
			["Value"] = _text,
			["HorizontalTextAlign"] = TEXT_ALIGN_LEFT,
			["Color"] = AUI.Color.ConvertHexToRGBA(_color, 1),
			["Font"] = (AUI.Settings.Questtracker.font_art .. "|" .. AUI.Settings.Questtracker.font_size / 1.25  .. "|" .. "outline"),
			["OffsetX"] = 30,
			["OffsetY"] = 10,
			["TextWrap"] = true,	
		},	
		[3] = 
		{
			["ControlType"] = "texture",
		},					
	}

	table.insert(g_itemList, conditionData)		
end

local function AddQuestConditions(_questIndex, _sortId)
	local numSteps = GetJournalQuestNumSteps(_questIndex)
	local addedNumConditions = 0
	for stepIndex = 1, numSteps do
		local stepText, visibility, stepType, trackerOverrideText, numConditions = GetJournalQuestStepInfo(_questIndex, stepIndex)
		if trackerOverrideText and not AUI.String.IsEmpty(trackerOverrideText) and visibility ~= QUEST_STEP_VISIBILITY_HIDDEN then
			AddQuestCondition(_sortId, zo_strformat(SI_QUEST_HINT_STEP_FORMAT, trackerOverrideText), AUI_QUESTTRACKER_ASSISTED_CONDITION_TEXT_COLOR)
			addedNumConditions = addedNumConditions + 1	
		else
			if visibility ~= QUEST_STEP_VISIBILITY_HIDDEN then
				for conditionIndex = 1, numConditions do
					local conditionText, current, max, isFailCondition, isComplete, isCreditShared = GetJournalQuestConditionInfo(_questIndex, stepIndex, conditionIndex) 
					if not isFailCondition and not AUI.String.IsEmpty(conditionText) and not isComplete then
						AddQuestCondition(_sortId + conditionIndex, zo_strformat(SI_QUEST_HINT_STEP_FORMAT, conditionText), AUI_QUESTTRACKER_ASSISTED_CONDITION_TEXT_COLOR)
						addedNumConditions = addedNumConditions + 1
					end
				end
			end
		end
	end

	return addedNumConditions
end

local function AddQuest(questIndex)	
	local questName = GetJournalQuestName(questIndex)

	if not AUI.String.IsEmpty(questName) then
		local instanceDisplayType = GetJournalQuestInstanceDisplayType(questIndex)
		local questType = GetJournalQuestType(questIndex) 	
		local questRepeatType = GetJournalQuestRepeatType(questIndex)
		local questJournalObject = SYSTEMS:GetObject("questJournal")
		local questIcon = questJournalObject:GetIconTexture(questType, instanceDisplayType)	
		local assisted = GetTrackedIsAssisted(TRACK_TYPE_QUEST, questIndex)
		local questCompleted = GetJournalQuestIsComplete(questIndex)
		
		local currentSortId = 100
		local catName = AUI.L10n.GetString("unknown")
		local textureWidth = 14
		local textureHeight = 14	
		local questTypeIcon = ""
		local opacity = 1

		if questCompleted then		
			opacity = AUI_QUESTTRACKER_QUEST_COMPLETED_OPACITY
		end			
		
		if questRepeatType == QUEST_REPEAT_DAILY then
			questTypeIcon = AUI_QUESTTRACKER_DAILY_ICON
			textureWidth = 17
			textureHeight = 17
		elseif questRepeatType == QUEST_REPEAT_REPEATABLE then
			questTypeIcon = AUI_QUESTTRACKER_REPEAT_ICON
		end	
		
		if questType == QUEST_TYPE_MAIN_STORY then
			currentSortId = 100
			catName = GetString("SI_QUESTTYPE", QUEST_TYPE_MAIN_STORY)
		elseif questType == QUEST_TYPE_GUILD then
			currentSortId = 200
			catName = GetString("SI_QUESTTYPE", QUEST_TYPE_GUILD)	
		elseif questType == QUEST_TYPE_CRAFTING then
			currentSortId = 300
			catName = GetString("SI_QUESTTYPE", QUEST_TYPE_CRAFTING)				
		elseif questType == QUEST_TYPE_HOLIDAY_EVENT then
			currentSortId = 400
			catName = GetString("SI_QUESTTYPE", QUEST_TYPE_HOLIDAY_EVENT)
		elseif questType == QUEST_TYPE_HOLIDAY_EVENT then
			currentSortId = 500
			catName = GetString("SI_QUESTTYPE", QUEST_TYPE_BATTLEGROUND)			
		else
			local zoneName, objectiveName, zoneIndex, poiIndex = GetJournalQuestLocationInfo(questIndex)
			if not AUI.String.IsEmpty(zoneName) then
				catName = zo_strformat(SI_QUEST_JOURNAL_ZONE_FORMAT, zoneName)
				if not g_catList[catName] then
					currentSortId = g_nextZoneCatId + 500
					g_nextZoneCatId = g_nextZoneCatId + 100
				end
			else
				catName = GetString(SI_QUEST_JOURNAL_GENERAL_CATEGORY)
				currentSortId = 60000	
			end	
		end
		
		if AUI.String.IsEmpty(questName) then
			questName = GetString(SI_QUEST_JOURNAL_UNKNOWN_QUEST_NAME)
		end		
		
		if assisted then
			local focusSortId = 0
			AddCategory("focus", focusSortId, catName, AUI_QUESTTRACKER_ASSISTED_HEADER_TEXT_COLOR, AUI_QUESTTRACKER_FOCUSED_ICON)
			focusSortId = focusSortId + 1
			AddQuestName(focusSortId, questName, AUI_QUESTTRACKER_ASSISTED_QUEST_TEXT_COLOR, questIcon, questTypeIcon, textureWidth, textureHeight, opacity)
			focusSortId = focusSortId + 1
			AddQuestConditions(questIndex, focusSortId, AUI_QUESTTRACKER_CONDITION_TEXT_COLOR)	
		end				
		
		if AUI.Settings.Questtracker.expandMode > 0 then		
			if g_catList[catName] then
				catName = g_catList[catName].catName
				currentSortId = g_catList[catName].nextSortId
			else				
				AddCategory(catName, currentSortId, catName, AUI_QUESTTRACKER_HEADER_TEXT_COLOR)
				g_catList[catName] = {catName = catName, nextSortId = currentSortId}
			end		

			currentSortId = currentSortId + 1
			
			AddQuestName(currentSortId, questName, AUI_QUESTTRACKER_QUEST_TEXT_COLOR, questIcon, questTypeIcon, textureWidth, textureHeight, opacity)

			currentSortId = currentSortId + 1

			if AUI.Settings.Questtracker.expandMode > 1 then
				local numConditions = AddQuestConditions(questIndex, currentSortId)
				currentSortId = currentSortId + numConditions + 1
			end
			
			g_catList[catName].nextSortId = currentSortId
		end
	end
end

local function HideQuestTimer()
	if AUI.Settings.Questtracker.showTime then
		AUI_Questtracker_LabelTime:SetHidden(false)
	end
	
	AUI_Questtracker_LabelQuestRemainTime:SetHidden(true)
	EVENT_MANAGER:UnregisterForUpdate("AUI_Questtracker_Update_QuestTimer")
	g_isQuestTimeActive = false
end

local function UpdateQuestTime(_timerEnd)
	local remainingTime = _timerEnd - GetFrameTimeSeconds()

	if remainingTime > 0 then
		local timeText, nextUpdateDelta = ZO_FormatTime(remainingTime, TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_SECONDS, TIME_FORMAT_DIRECTION_DESCENDING)		
		AUI_Questtracker_LabelQuestRemainTime:SetText(AUI.L10n.GetString("time_remaining") .. ":    " .. timeText)
		g_isQuestTimeActive = true
	else
		HideQuestTimer()
	end
end

local function ShowQuestTimer(_timerEnd)
	EVENT_MANAGER:RegisterForUpdate("AUI_Questtracker_Update_QuestTimer", 10, function() UpdateQuestTime(_timerEnd) end)		
	AUI_Questtracker_LabelTime:SetHidden(true)		
	AUI_Questtracker_LabelQuestRemainTime:SetHidden(false)
end

local function UpdatePosition()
	AUI_Questtracker:ClearAnchors()
	AUI_Questtracker:SetAnchor(AUI.Settings.Questtracker.anchor.point, GuiRoot, AUI.Settings.Questtracker.anchor.relativePoint, AUI.Settings.Questtracker.anchor.offsetX, AUI.Settings.Questtracker.anchor.offsetY)	

	AUI_Questtracker_ListBox:ClearAnchors()
	AUI_Questtracker_ListBox:SetAnchor(TOPLEFT, AUI_Questtracker, TOPLEFT, 0, 0)	
end

local function OnUpdateTime()
	if not g_isInit or not AUI.Settings.Questtracker.showTime then
		return
	end

	local timePrecision = TIME_FORMAT_PRECISION_TWENTY_FOUR_HOUR
	
	if AUI.Settings.Questtracker.useTimePrecisionTwelfeHour then
		timePrecision = TIME_FORMAT_PRECISION_TWELVE_HOUR
	end
	
	local timeString = AUI.Time.GetFormatedTime(timePrecision)
	
	AUI_Questtracker_LabelTime:SetText(timeString)
end

function AUI.Questtracker.SetToDefaultPosition(defaultSettings)
	if not g_isInit then
		return
	end
	AUI.Settings.Questtracker.anchor = defaultSettings.anchor

	UpdatePosition()
end

function AUI.Questtracker.UpdateQuestTimer(_questIndex)
	local timerStart, timerEnd, isVisible, isPaused = GetJournalQuestTimerInfo(_questIndex) 
	if isVisible then
		local assisted = GetTrackedIsAssisted(TRACK_TYPE_QUEST, _questIndex)
		if assisted then
			ShowQuestTimer(timerEnd)
		end
	end
end

function AUI.Questtracker.Update()
	if not g_isInit then
		return
	end

	g_itemList = {}
	g_catList = {}
	g_nextZoneCatId = 0
	
	local questCount = 0
	
	HideQuestTimer()	

	for i = 1, MAX_JOURNAL_QUESTS do
		if IsValidQuestIndex(i) then  
			local questIndex = i
			AddQuest(questIndex)
			AUI.Questtracker.UpdateQuestTimer(questIndex)

			questCount = questCount + 1
		end
	end	

	AUI_Questtracker_LabelQuestLogInfo:SetText(questCount .. "/" .. MAX_JOURNAL_QUESTS)
	
	if questCount >= MAX_JOURNAL_QUESTS then
		AUI_Questtracker_LabelQuestLogInfo:SetColor(AUI.Color.ConvertHexToRGBA(AUI_QUESTTRACKER_QUEST_LOG_INFO_FULL_TEXT_COLOR):UnpackRGBA())
	else
		AUI_Questtracker_LabelQuestLogInfo:SetColor(AUI.Color.ConvertHexToRGBA(AUI_QUESTTRACKER_QUEST_LOG_INFO_NORMAL_TEXT_COLOR):UnpackRGBA())
	end
	
	if questCount > 0 then
		AUI_Questtracker_ListBox:SetItemList(g_itemList)
	end
	
	AUI_Questtracker_ListBox:Refresh()
	AUI.Questtracker.SetDimensions()
	AUI_Questtracker_ListBox:RefreshVisible()
end

function AUI.Questtracker.SetDimensions()
	local height = 0

	local listBoxInnerHeight = AUI_Questtracker_ListBox:GetScrollContentHeight()
	if listBoxInnerHeight > AUI_QUESTTRACKER_MIN_HEIGHT then
		height = AUI.Settings.Questtracker.height
	else
		height = AUI_QUESTTRACKER_MIN_HEIGHT
	end

	AUI_Questtracker_ListBox:SetDimensions(AUI.Settings.Questtracker.width, height)
	AUI_Questtracker_Border:SetDimensions(AUI.Settings.Questtracker.width, height)
	AUI_Questtracker:SetDimensions(AUI.Settings.Questtracker.width, AUI_QUESTTRACKER_MAX_HEIGHT_MIN_SIZE)
	
	ZO_FocusedQuestTrackerPanel:ClearAnchors()
	ZO_FocusedQuestTrackerPanel:SetAnchor(TOPLEFT, AUI_Questtracker_Border, BOTTOMLEFT, 0, 2)		
end

function AUI.Questtracker.UpdateUI()
	if not g_isInit then
		return
	end
	
	local width1 = 22
	local width2 = (AUI.Settings.Questtracker.width / 100 * 85) - width1
	local width3 = (AUI.Settings.Questtracker.width / 100 * 15)

	local columnList = {
	[1] = 	
		{
			["Name"] = "Icon",
			["Width"] = width1,
			["AllowSort"] = false,
		},
	[2] = 	
		{
			["Name"] = "Name",
			["Text"] = "",
			["Width"] = width2,
			["AllowSort"] = false,
			["Font"] = (AUI.Settings.Questtracker.font_art .. "|" .. 0  .. "|" .. "outline")
		},	
	[3] = 	
		{
			["Name"] = "Level",
			["Text"] = "",
			["Width"] = width3,
			["AllowSort"] = false,
			["Font"] = (AUI.Settings.Questtracker.font_art .. "|" .. 0  .. "|" .. "outline")
		},		
	}		
	
	AUI_Questtracker_ListBox:SetRowHeight(AUI.Settings.Questtracker.font_size + 4)				
	AUI_Questtracker_ListBox:SetColumnList(columnList)	
	
	if AUI.Settings.Questtracker.showBackground then
		AUI_Questtracker_Border:SetHidden(false)
	else
		AUI_Questtracker_Border:SetHidden(true)
	end
	
	local container = GetControl(AUI_Questtracker_ListBox, "Container") 
	local columnHeader = GetControl(container, "ColumnHeader") 	
	
	if AUI.Settings.Questtracker.showTime then
		columnHeader:SetHidden(false)
	else
		columnHeader:SetHidden(true)
		AUI_Questtracker_LabelTime:SetHidden(true)
	end	

	if AUI.Settings.Questtracker.expandMode == 0 then
		AUI_Questtracker_ExpandConditionsButton:SetTextureCoords(0, 1, 0, 1)		
		AUI_Questtracker_ExpandConditionsButton:SetNormalTexture("AUI/images/other/arrow_expand_top.dds")
		AUI_Questtracker_ExpandConditionsButton:SetPressedTexture("AUI/images/other/arrow_expand_top_pressed.dds")
		AUI_Questtracker_ExpandConditionsButton:SetMouseOverTexture("AUI/images/other/arrow_expand_top_hover.dds")			
	elseif AUI.Settings.Questtracker.expandMode == 1 then
		AUI_Questtracker_ExpandConditionsButton:SetTextureCoords(0, 1, 0, 1)
		AUI_Questtracker_ExpandConditionsButton:SetNormalTexture("AUI/images/other/arrow_expand_left.dds")
		AUI_Questtracker_ExpandConditionsButton:SetPressedTexture("AUI/images/other/arrow_expand_left_hover.dds")
		AUI_Questtracker_ExpandConditionsButton:SetMouseOverTexture("AUI/images/other/arrow_expand_left_pressed.dds")					
	else
		AUI_Questtracker_ExpandConditionsButton:SetTextureCoords(0, 1, 1, 0)		
		AUI_Questtracker_ExpandConditionsButton:SetNormalTexture("AUI/images/other/arrow_expand_top.dds")
		AUI_Questtracker_ExpandConditionsButton:SetPressedTexture("AUI/images/other/arrow_expand_top_pressed.dds")
		AUI_Questtracker_ExpandConditionsButton:SetMouseOverTexture("AUI/images/other/arrow_expand_top_hover.dds")			
	end	

	AUI.Questtracker.Update()
end

function AUI.Questtracker.DoesShow()
	return not AUI_Questtracker:IsHidden()
end

function AUI.Questtracker.Show()
	if not g_isInit then
		return
	end
	
	if not AUI.Questtracker.DoesShow() then	
		AUI_QUESTTRACKER_SCENE_FRAGMENT:Show()
	end
end

function AUI.Questtracker.Hide()
	if AUI.Questtracker.DoesShow() then	
		AUI_QUESTTRACKER_SCENE_FRAGMENT:Hide()
	end
end

function AUI.Questtracker.Load()
	if g_isInit then
		return
	end

	AUI.Questtracker.LoadSettings()
	
	AUI_QUESTTRACKER_SCENE_FRAGMENT = ZO_SimpleSceneFragment:New(AUI_Questtracker)					
	
	HUD_SCENE:AddFragment(AUI_QUESTTRACKER_SCENE_FRAGMENT)
	HUD_UI_SCENE:AddFragment(AUI_QUESTTRACKER_SCENE_FRAGMENT)
	
	AUI_Questtracker:SetHandler("OnMouseDown", AUI_Questtracker_OnMouseDown)
	AUI_Questtracker:SetHandler("OnMouseUp", AUI_Questtracker_OnMouseUp)	
	
	AUI.CreateListBox("AUI_Questtracker_ListBox", AUI_Questtracker, false, false)
	AUI_Questtracker_ListBox:EnableMouseHover()
	AUI_Questtracker_ListBox:SetSortKey(1)
	AUI_Questtracker_ListBox:SetSortOrder(ZO_SORT_ORDER_UP)
	
	zo_callLater(function() 
		FOCUSED_QUEST_TRACKER_FRAGMENT:SetHiddenForReason("AUI_HIDE_PERMANENT", true)
		FOCUSED_QUEST_TRACKER_FRAGMENT:Hide()
	end, 100)
	
	AUI_Questtracker_ExpandConditionsButton:SetHandler("OnClicked", 
	function()
		if AUI.Settings.Questtracker.expandMode == 0 then
			AUI.Settings.Questtracker.expandMode = 1
		elseif AUI.Settings.Questtracker.expandMode == 1 then
			AUI.Settings.Questtracker.expandMode = 2
		else
			AUI.Settings.Questtracker.expandMode = 0
		end
			
		AUI.Questtracker.UpdateUI()
	end)	
	
	g_isInit = true
	
	AUI_Questtracker_LabelTime:SetFont(AUI.Settings.Questtracker.font_art .. "|" ..  18 .. "|" .. "thick-outline")
	AUI_Questtracker_LabelQuestRemainTime:SetFont(AUI.Settings.Questtracker.font_art .. "|" ..  16 .. "|" .. "thick-outline")	
	AUI_Questtracker_LabelQuestRemainTime:SetColor(AUI.Color.ConvertHexToRGBA(AUI_QUESTTRACKER_REMAIN_TIMER_TEXT_COLOR):UnpackRGBA())		
	AUI_Questtracker_LabelQuestLogInfo:SetFont(AUI.Settings.Questtracker.font_art .. "|" ..  14 .. "|" .. "outline")

	UpdatePosition()		
	
	AUI.Questtracker.UpdateUI()
	
	EVENT_MANAGER:RegisterForUpdate("AUI_QuestrTracker_OnUpdate", 10, OnUpdateTime)
end