QuestTrackerImproved = {}
local QTI = QuestTrackerImproved
local EM = EVENT_MANAGER

QTI.name = "QuestTrackerImproved"

QTI.ENTRY_TYPE_SUBCATEGORY_CONDITION = 4

QTI.ICON_QUEST = "/esoui/art/floatingmarkers/quest_icon_assisted.dds"
QTI.ICON_ZONE_STORY = "/esoui/art/journal/gamepad/gp_questtypeicon_zonestory.dds"
QTI.ICON_RAID = "esoui/art/icons/mapkey/mapkey_raiddungeon.dds"
QTI.ICON_DUNGEON = "/esoui/art/loadingtips/loadingtip_soloinstance.dds"
QTI.ICON_GROUP_DUNGEON = "esoui/art/icons/mapkey/mapkey_groupinstance.dds"
QTI.ICON_GROUP_DELVE = "/esoui/art/journal/gamepad/gp_questtypeicon_groupdelve.dds"
QTI.ICON_GROUP_AREA = "/esoui/art/journal/gamepad/gp_questtypeicon_grouparea.dds"
QTI.ICON_PUBLIC_DUNGEON = "/esoui/art/zonestories/completiontypeicon_publicdungeon.dds"
QTI.ICON_DELVE = "/esoui/art/journal/gamepad/gp_questtypeicon_delve.dds"
QTI.ICON_ENDLESS_DUNGEON = "/esoui/art/journal/gamepad/gp_questtypeicon_endlessdungeon.dds"
QTI.ICON_COMPANION = "/esoui/art/journal/gamepad/gp_questtypeicon_companion.dds"
QTI.ICON_ADVENTURE_ZONE = "/esoui/art/journal/gamepad/gp_questtypeicon_adventurezone.dds"
QTI.ICON_AVA = "/esoui/art/journal/gamepad/gp_questtypeicon_ava.dds"
QTI.ICON_FAVOR = "/esoui/art/journal/gamepad/gp_questtypeicon_repeatable_favor.dds"
QTI.ICON_BATTLEGROUND = "/esoui/art/battlegrounds/gamepad/gp_battlegrounds_tabicon_battlegrounds.dds"
QTI.ICON_HOUSING = "/esoui/art/icons/mapkey/mapkey_housing.dds"
QTI.ICON_CRAFTING = "/esoui/art/journal/gamepad/gp_questtypeicon_crafting.dds"
QTI.ICON_TRIBUTE = "/esoui/art/tribute/gamepad/gp_tribute_tabicon_tribute.dds"

QTI.REPEATABLE_COLOR = { r = 112/255, g = 180/255, b = 184/255, a = 1 }

local TIMER_ICON = "|t24:24:esoui/art/miscellaneous/timer_32.dds|t"

local defaultSV = {
	headerFont = "$(ANTIQUE_FONT)",
	headerSize = 20,
	headerStyle = "soft-shadow-thin",
	headerColor = { r = 1, g = 0.8392156959, b = 0.3294117749, a = 1 },

	conditionFont = "$(ANTIQUE_FONT)",
	conditionSize = 16,
	conditionStyle = "soft-shadow-thin",
	conditionColor = { r = 1, g = 1, b = 1, a = 1 },

	hintFont = "$(ANTIQUE_FONT)",
	hintSize = 14,
	hintStyle = "soft-shadow-thin",
	hintColor = { r = 0.5450980663, g = 0.5490196347, b = 0.5215686560, a = 1 },

	hintDescFont = "$(ANTIQUE_FONT)",
	hintDescSize = 15,
	hintDescStyle = "soft-shadow-thin",
	hintDescColor = { r = 0, g = 0.7607843280, b = 0.7215686440, a = 1 },

	width = 252,
	iconSize = 32,
}

function QTI.GetFont(font, size, style)
	if style and style ~= "" and style ~= "none" then
		return font .. "|" .. size .. "|" .. style
	end
	return font .. "|" .. size
end

function QTI.ApplyControlColor(control, color)
	control:SetColor(color.r, color.g, color.b, color.a)
end

function QTI.ApplyConditionStyle(control)
	if control.entryType == QTI.ENTRY_TYPE_SUBCATEGORY_CONDITION then
		control:SetFont(QTI.GetFont(QTI.SV.hintDescFont, QTI.SV.hintDescSize, QTI.SV.hintDescStyle))
		QTI.ApplyControlColor(control, QTI.SV.hintDescColor)
	else
		control:SetFont(QTI.GetFont(QTI.SV.conditionFont, QTI.SV.conditionSize, QTI.SV.conditionStyle))
		QTI.ApplyControlColor(control, QTI.SV.conditionColor)
	end
end

function QTI.GetQuestIconTexture(questType, zoneDisplayType)
	if zoneDisplayType == ZONE_DISPLAY_TYPE_ZONE_STORY then
		return QTI.ICON_ZONE_STORY
	elseif zoneDisplayType == ZONE_DISPLAY_TYPE_RAID then
		return QTI.ICON_RAID
	elseif zoneDisplayType == ZONE_DISPLAY_TYPE_GROUP_DUNGEON then
		return QTI.ICON_GROUP_DUNGEON
	elseif zoneDisplayType == ZONE_DISPLAY_TYPE_GROUP_DELVE then
		return QTI.ICON_GROUP_DELVE
	elseif zoneDisplayType == ZONE_DISPLAY_TYPE_GROUP_AREA then
		return QTI.ICON_GROUP_AREA
	elseif zoneDisplayType == ZONE_DISPLAY_TYPE_PUBLIC_DUNGEON then
		return QTI.ICON_PUBLIC_DUNGEON
	elseif zoneDisplayType == ZONE_DISPLAY_TYPE_DELVE then
		return QTI.ICON_DELVE
	elseif zoneDisplayType == ZONE_DISPLAY_TYPE_ENDLESS_DUNGEON then
		return QTI.ICON_ENDLESS_DUNGEON
	elseif zoneDisplayType == ZONE_DISPLAY_TYPE_COMPANION then
		return QTI.ICON_COMPANION
	elseif zoneDisplayType == ZONE_DISPLAY_TYPE_ADVENTURE_ZONE then
		return QTI.ICON_ADVENTURE_ZONE
	elseif zoneDisplayType == ZONE_DISPLAY_TYPE_HOUSING then
		return QTI.ICON_HOUSING

	elseif questType == QUEST_TYPE_AVA or questType == QUEST_TYPE_AVA_GRAND or questType == QUEST_TYPE_AVA_GROUP then
		return QTI.ICON_AVA
	elseif questType == QUEST_TYPE_UNDAUNTED_PLEDGE then
		return QTI.ICON_GROUP_DUNGEON
	elseif questType == QUEST_TYPE_BATTLEGROUND then
		return QTI.ICON_BATTLEGROUND
	elseif questType == QUEST_TYPE_DUNGEON then
		return QTI.ICON_DUNGEON
	elseif questType == QUEST_TYPE_FAVOR then
		return QTI.ICON_FAVOR
	elseif questType == QUEST_TYPE_PROLOGUE then
		return QTI.ICON_ZONE_STORY
	elseif questType == QUEST_TYPE_CRAFTING then
		return QTI.ICON_CRAFTING
	elseif questType == QUEST_TYPE_TRIBUTE then
        return QTI.ICON_TRIBUTE	

	else
		return QTI.ICON_QUEST
	end
end

function QTI.ApplyHeaderIcon(questHeader)
	local questIndex = questHeader.m_Data:GetJournalIndex()
	local repeatableType = GetJournalQuestRepeatType(questIndex)

	local icon = questHeader.icon
	local iconTexture = QTI.GetQuestIconTexture(questHeader.questType, questHeader.displayType)
	icon:SetTexture(iconTexture)
	icon:SetDimensions(QTI.SV.iconSize, QTI.SV.iconSize)

	icon:ClearAnchors()

	local styleOffset = (QTI.SV.headerStyle == "thick-outline") and -4 or 0
	local alignOffset = -((QTI.SV.iconSize - QTI.SV.headerSize) / 2)
	icon:SetAnchor(TOPRIGHT, questHeader, TOPLEFT, -5, alignOffset + styleOffset + 2)

	local isFavorIcon = (iconTexture == QTI.ICON_FAVOR)

	if not isFavorIcon and repeatableType ~= QUEST_REPEAT_NOT_REPEATABLE then
		icon:SetColor(QTI.REPEATABLE_COLOR.r, QTI.REPEATABLE_COLOR.g, QTI.REPEATABLE_COLOR.b, QTI.REPEATABLE_COLOR.a)
	else
		icon:SetColor(1, 1, 1, 1)
	end

	icon:SetHidden(false)
	questHeader.isUsingIcon = true
end

function QTI.HideButton()
	FOCUSED_QUEST_TRACKER.assistedTexture:SetHidden(true)

	ZO_PreHook(ZO_Tracker, "UpdateAssistedVisibility", function(self)
		self.assistedTexture:SetHidden(true)
		return true
	end)
end

function QTI.WrapPool(pool, fontGetter)
	local originalAcquire = pool.AcquireObject
	pool.AcquireObject = function(poolSelf, ...)
		local control, key = originalAcquire(poolSelf, ...)
		control:SetFont(fontGetter())
		return control, key
	end
end

function QTI.WrapConditionPool(pool)
	local originalAcquire = pool.AcquireObject
	pool.AcquireObject = function(poolSelf, ...)
		local control, key = originalAcquire(poolSelf, ...)
		if not control.QTI_setTextWrapped then
			control.QTI_setTextWrapped = true
			local originalSetText = control.SetText
			control.SetText = function(controlSelf, text)
				originalSetText(controlSelf, text)
				QTI.ApplyConditionStyle(controlSelf)
			end
		end
		QTI.ApplyConditionStyle(control)
		return control, key
	end
end

function QTI.ApplyFontsAndWidth()
	local tracker = FOCUSED_QUEST_TRACKER

	for _, control in pairs(tracker.headerPool:GetActiveObjects()) do
		control:SetFont(QTI.GetFont(QTI.SV.headerFont, QTI.SV.headerSize, QTI.SV.headerStyle))
		control:SetWidth(QTI.SV.width)
		QTI.ApplyControlColor(control, QTI.SV.headerColor)
	end
	for _, control in pairs(tracker.conditionPool:GetActiveObjects()) do
		QTI.ApplyConditionStyle(control)
		control:SetWidth(QTI.SV.width)
	end
	for _, control in pairs(tracker.stepDescriptionPool:GetActiveObjects()) do
		control:SetFont(QTI.GetFont(QTI.SV.hintFont, QTI.SV.hintSize, QTI.SV.hintStyle))
		control:SetWidth(QTI.SV.width)
		QTI.ApplyControlColor(control, QTI.SV.hintColor)
	end
end

function QTI.SetupFonts()
	local tracker = FOCUSED_QUEST_TRACKER

	QTI.WrapPool(tracker.headerPool, function() return QTI.GetFont(QTI.SV.headerFont, QTI.SV.headerSize, QTI.SV.headerStyle) end)
	QTI.WrapConditionPool(tracker.conditionPool)
	QTI.WrapPool(tracker.stepDescriptionPool, function() return QTI.GetFont(QTI.SV.hintFont, QTI.SV.hintSize, QTI.SV.hintStyle) end)

	QTI.ApplyFontsAndWidth()
end

function QTI.RefreshHeaderIcons()
	for _, header in pairs(FOCUSED_QUEST_TRACKER.headerPool:GetActiveObjects()) do
		QTI.ApplyHeaderIcon(header)
	end
end

function QTI.HookFonts()
	ZO_PostHook(ZO_Tracker, "ApplyPlatformStyle", function(self)
		QTI.ResizePanel()
	end)

	ZO_PostHook(ZO_Tracker, "InitializeQuestHeader", function(self, questName, questType, questHeader)
		QTI.ApplyControlColor(questHeader, QTI.SV.headerColor)
	end)

	ZO_PostHook(ZO_Tracker, "DoHeaderNameHighlight", function(self, label, state)
		if state ~= 1 then
			QTI.ApplyControlColor(label, QTI.SV.headerColor)
		end
	end)

	ZO_PostHook(ZO_Tracker, "PopulateQuestConditions", function(self)
		QTI.ApplyFontsAndWidth()
	end)
end

function QTI.HookIcons()
	ZO_PostHook(ZO_Tracker, "InitializeQuestHeader", function(self, questName, questType, questHeader, isComplete, zoneDisplayType)
		QTI.ApplyHeaderIcon(questHeader)
	end)

	ZO_PostHook(ZO_Tracker, "ApplyPlatformStyle", function(self)
		QTI.RefreshHeaderIcons()
	end)
end

function QTI.TimerTweaks()
	ZO_PostHook(_G, "ZO_QuestTimer_OnUpdate", function(control)
		local label = control.label
		local timeLabel = control.time

		if label:GetText() ~= TIMER_ICON then
			label:SetText(TIMER_ICON)
		end

		local xOffset = 40
		local yOffset = -20

		label:SetWidth(24)

		label:ClearAnchors()
		label:SetAnchor(TOPLEFT, ZO_FocusedQuestTrackerPanel, TOPLEFT, xOffset, yOffset)

		timeLabel:ClearAnchors()
		timeLabel:SetAnchor(TOPLEFT, ZO_FocusedQuestTrackerPanel, TOPLEFT, xOffset + 28, yOffset)

		if not control.QTI_timerStyled then
			control.QTI_timerStyled = true

			local trackerContainer = ZO_FocusedQuestTrackerPanel:GetNamedChild("Container")

			label:SetParent(trackerContainer)
			timeLabel:SetParent(trackerContainer)

			control:SetHeight(0)

			ZO_PreHook(control, "SetHidden", function(self, hidden)
				label:SetHidden(hidden)
				timeLabel:SetHidden(hidden)
			end)

			label:SetHidden(control:IsHidden())
			timeLabel:SetHidden(control:IsHidden())
		end
	end)
end

function QTI.ResizePanel()
	ZO_FocusedQuestTrackerPanel:SetWidth(QTI.SV.width)
end

function QTI.RefreshAll()
	QTI.ApplyFontsAndWidth()
	QTI.ResizePanel()
	QTI.RefreshHeaderIcons()
end

function QTI.OnAddOnLoaded(_, addOnName)
	if addOnName ~= QTI.name then return end
	EM:UnregisterForEvent(QTI.name, EVENT_ADD_ON_LOADED)

	QTI.SV = ZO_SavedVars:NewAccountWide("QuestTrackerImproved_SV", 1, nil, defaultSV)

	QTI.RegisterSettings()

	QTI.HideButton()
	QTI.SetupFonts()
	QTI.HookFonts()
	QTI.HookIcons()
	QTI.TimerTweaks()
	QTI.ResizePanel()
	QTI.RefreshHeaderIcons()

	EM:RegisterForEvent(QTI.name, EVENT_QUEST_ADVANCED, function(_, questIndex)
		FOCUSED_QUEST_TRACKER:ForceAssist(questIndex)
	end)
	
	EM:RegisterForEvent(QTI.name, EVENT_QUEST_CONDITION_COUNTER_CHANGED, function(_, questIndex)
		FOCUSED_QUEST_TRACKER:ForceAssist(questIndex)
	end)	 
end

EM:RegisterForEvent(QTI.name, EVENT_ADD_ON_LOADED, QTI.OnAddOnLoaded)