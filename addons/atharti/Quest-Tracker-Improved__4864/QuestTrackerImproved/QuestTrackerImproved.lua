QuestTrackerImproved = {}
local QTI = QuestTrackerImproved
local EM = EVENT_MANAGER

QTI.name = "QuestTrackerImproved"

local ENTRY_TYPE_SUBCATEGORY_CONDITION = 4

local ICON_QUEST = "/esoui/art/floatingmarkers/quest_icon_assisted.dds"
local ICON_ZONE_STORY = "/esoui/art/journal/gamepad/gp_questtypeicon_zonestory.dds"
local ICON_RAID = "esoui/art/icons/mapkey/mapkey_raiddungeon.dds"
local ICON_DUNGEON = "/esoui/art/loadingtips/loadingtip_soloinstance.dds"
local ICON_GROUP_DUNGEON = "esoui/art/icons/mapkey/mapkey_groupinstance.dds"
local ICON_GROUP_DELVE = "/esoui/art/journal/gamepad/gp_questtypeicon_groupdelve.dds"
local ICON_GROUP_AREA = "/esoui/art/journal/gamepad/gp_questtypeicon_grouparea.dds"
local ICON_PUBLIC_DUNGEON = "/esoui/art/zonestories/completiontypeicon_publicdungeon.dds"
local ICON_DELVE = "/esoui/art/journal/gamepad/gp_questtypeicon_delve.dds"
local ICON_ENDLESS_DUNGEON = "/esoui/art/journal/gamepad/gp_questtypeicon_endlessdungeon.dds"
local ICON_COMPANION = "/esoui/art/journal/gamepad/gp_questtypeicon_companion.dds"
local ICON_ADVENTURE_ZONE = "/esoui/art/journal/gamepad/gp_questtypeicon_adventurezone.dds"
local ICON_AVA = "/esoui/art/journal/gamepad/gp_questtypeicon_ava.dds"
local ICON_FAVOR = "/esoui/art/journal/gamepad/gp_questtypeicon_repeatable_favor.dds"
local ICON_BATTLEGROUND = "/esoui/art/battlegrounds/gamepad/gp_battlegrounds_tabicon_battlegrounds.dds"
local ICON_HOUSING = "/esoui/art/icons/mapkey/mapkey_housing.dds"
local ICON_CRAFTING = "/esoui/art/journal/gamepad/gp_questtypeicon_crafting.dds"
local ICON_TRIBUTE = "/esoui/art/tribute/gamepad/gp_tribute_tabicon_tribute.dds"

local REPEATABLE_COLOR = { r = 112/255, g = 180/255, b = 184/255, a = 1 }

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

function QTI.ApplyTextAlignment(control)
	control:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
end

function QTI.ApplyConditionStyle(control)
	if control.entryType == ENTRY_TYPE_SUBCATEGORY_CONDITION then
		control:SetFont(QTI.GetFont(QTI.SV.hintDescFont, QTI.SV.hintDescSize, QTI.SV.hintDescStyle))
		QTI.ApplyControlColor(control, QTI.SV.hintDescColor)
	else
		control:SetFont(QTI.GetFont(QTI.SV.conditionFont, QTI.SV.conditionSize, QTI.SV.conditionStyle))
		QTI.ApplyControlColor(control, QTI.SV.conditionColor)
	end
	QTI.ApplyTextAlignment(control)
end

function QTI.GetQuestIconTexture(questType, zoneDisplayType)
	if zoneDisplayType == ZONE_DISPLAY_TYPE_ZONE_STORY then
		return ICON_ZONE_STORY
	elseif zoneDisplayType == ZONE_DISPLAY_TYPE_RAID then
		return ICON_RAID
	elseif zoneDisplayType == ZONE_DISPLAY_TYPE_GROUP_DUNGEON then
		return ICON_GROUP_DUNGEON
	elseif zoneDisplayType == ZONE_DISPLAY_TYPE_GROUP_DELVE then
		return ICON_GROUP_DELVE
	elseif zoneDisplayType == ZONE_DISPLAY_TYPE_GROUP_AREA then
		return ICON_GROUP_AREA
	elseif zoneDisplayType == ZONE_DISPLAY_TYPE_PUBLIC_DUNGEON then
		return ICON_PUBLIC_DUNGEON
	elseif zoneDisplayType == ZONE_DISPLAY_TYPE_DELVE then
		return ICON_DELVE
	elseif zoneDisplayType == ZONE_DISPLAY_TYPE_ENDLESS_DUNGEON then
		return ICON_ENDLESS_DUNGEON
	elseif zoneDisplayType == ZONE_DISPLAY_TYPE_COMPANION then
		return ICON_COMPANION
	elseif zoneDisplayType == ZONE_DISPLAY_TYPE_ADVENTURE_ZONE then
		return ICON_ADVENTURE_ZONE
	elseif zoneDisplayType == ZONE_DISPLAY_TYPE_HOUSING then
		return ICON_HOUSING

	elseif questType == QUEST_TYPE_AVA or questType == QUEST_TYPE_AVA_GRAND or questType == QUEST_TYPE_AVA_GROUP then
		return ICON_AVA
	elseif questType == QUEST_TYPE_UNDAUNTED_PLEDGE then
		return ICON_GROUP_DUNGEON
	elseif questType == QUEST_TYPE_BATTLEGROUND then
		return ICON_BATTLEGROUND
	elseif questType == QUEST_TYPE_DUNGEON then
		return ICON_DUNGEON
	elseif questType == QUEST_TYPE_FAVOR then
		return ICON_FAVOR
	elseif questType == QUEST_TYPE_PROLOGUE then
		return ICON_ZONE_STORY
	elseif questType == QUEST_TYPE_CRAFTING then
		return ICON_CRAFTING
	elseif questType == QUEST_TYPE_TRIBUTE then
		return ICON_TRIBUTE

	else
		return ICON_QUEST
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

	local isFavorIcon = (iconTexture == ICON_FAVOR)

	if not isFavorIcon and repeatableType ~= QUEST_REPEAT_NOT_REPEATABLE then
		icon:SetColor(REPEATABLE_COLOR.r, REPEATABLE_COLOR.g, REPEATABLE_COLOR.b, REPEATABLE_COLOR.a)
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

function QTI.ApplyTreeIndent()
	local tracker = FOCUSED_QUEST_TRACKER
	tracker.treeView:SetIndent(15)
	tracker.treeView:Update()
end

function QTI.WrapPool(pool, fontGetter)
	local originalAcquire = pool.AcquireObject
	pool.AcquireObject = function(poolSelf, ...)
		local control, key = originalAcquire(poolSelf, ...)
		control:SetFont(fontGetter())
		QTI.ApplyTextAlignment(control)
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
		QTI.ApplyTextAlignment(control)
	end
	for _, control in pairs(tracker.conditionPool:GetActiveObjects()) do
		QTI.ApplyConditionStyle(control)
		control:SetWidth(QTI.SV.width)
	end
	for _, control in pairs(tracker.stepDescriptionPool:GetActiveObjects()) do
		control:SetFont(QTI.GetFont(QTI.SV.hintFont, QTI.SV.hintSize, QTI.SV.hintStyle))
		control:SetWidth(QTI.SV.width)
		QTI.ApplyControlColor(control, QTI.SV.hintColor)
		QTI.ApplyTextAlignment(control)
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

function QTI.HookTracker()
	ZO_PostHook(ZO_Tracker, "ApplyPlatformStyle", function(self)
		QTI.RefreshAll()
	end)

	ZO_PostHook(ZO_Tracker, "UpdateTreeView", function(self)
		QTI.ApplyTreeIndent()
	end)

	ZO_PostHook(ZO_Tracker, "InitializeQuestHeader", function(self, questName, questType, questHeader, isComplete, zoneDisplayType)
		QTI.ApplyControlColor(questHeader, QTI.SV.headerColor)
		QTI.ApplyTextAlignment(questHeader)
		QTI.ApplyHeaderIcon(questHeader)
	end)

	ZO_PostHook(ZO_Tracker, "DoHeaderNameHighlight", function(self, label, state)
		if state ~= 1 then
			QTI.ApplyControlColor(label, QTI.SV.headerColor)
		end
		QTI.ApplyTextAlignment(label)
	end)

	ZO_PostHook(ZO_Tracker, "PopulateQuestConditions", function(self)
		QTI.ApplyFontsAndWidth()
		QTI.ApplyTreeIndent()
	end)
end

function QTI.TimerTweaks()
	local managerHooked = false

	ZO_PostHook(_G, "ZO_QuestTimer_OnUpdate", function(control)
		if managerHooked then return end
		managerHooked = true

		local owner = control.owner

		ZO_PostHook(owner, "UpdateTimer", function(self, timer, now)
			local remaining = timer.ends - now
			if remaining > 0 then
				timer.time:SetText(ZO_FormatTime(remaining, TIME_FORMAT_STYLE_COLONS, TIME_FORMAT_PRECISION_SECONDS, TIME_FORMAT_DIRECTION_DESCENDING))
			end
		end)

		ZO_PostHook(owner, "PerformLayout", function(self)
			for _, timer in pairs(self.timers) do
				local label = timer.label
				local timeLabel = timer.time

				label:SetText(TIMER_ICON)
				label:SetWidth(24)
				label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
				label:ClearAnchors()
				label:SetAnchor(LEFT, timer, LEFT, 0, 0)

				timeLabel:ClearAnchors()
				timeLabel:SetAnchor(LEFT, timer, LEFT, 28, 0)

				timer:SetExcludeFromResizeToFitExtents(true)
				timer:ClearAnchors()
				timer:SetAnchor(TOPLEFT, ZO_FocusedQuestTrackerPanel, TOPLEFT, -3, -22)
			end
		end)

		owner:PerformLayout()
	end)
end

function QTI.DetachQuestTracker()
	local hudTrackerElement = HUD_TRACKER_MANAGER:GetPlatformHUDElement()
	if hudTrackerElement:GetCustomOptionValue("SeparatedTrackers", "Quest") ~= true then
		hudTrackerElement:SetCustomOptionValue("SeparatedTrackers", "Quest", true)
		HUD_TRACKER_MANAGER:RefreshLayout()
	end
end

function QTI.ResizePanel()
	ZO_FocusedQuestTrackerPanel:SetWidth(QTI.SV.width)
end

function QTI.RefreshAll()
	QTI.ApplyFontsAndWidth()
	QTI.ResizePanel()
	QTI.RefreshHeaderIcons()
	QTI.ApplyTreeIndent()
end

function QTI.OnAddOnLoaded(_, addOnName)
	if addOnName ~= QTI.name then return end
	EM:UnregisterForEvent(QTI.name, EVENT_ADD_ON_LOADED)

	QTI.SV = ZO_SavedVars:NewAccountWide("QuestTrackerImproved_SV", 1, nil, defaultSV)

	QTI.RegisterSettings()

	QTI.HideButton()
	QTI.SetupFonts()
	QTI.HookTracker()
	QTI.TimerTweaks()
	QTI.ApplyFontsAndWidth()
	QTI.ResizePanel()
	QTI.RefreshHeaderIcons()
	QTI.ApplyTreeIndent()

	EM:RegisterForEvent(QTI.name .. "_Detach", EVENT_ADD_ONS_LOADED, function()
		EM:UnregisterForEvent(QTI.name .. "_Detach", EVENT_ADD_ONS_LOADED)
		QTI.DetachQuestTracker()
	end)

	EM:RegisterForEvent(QTI.name, EVENT_QUEST_ADVANCED, function(_, questIndex)
		FOCUSED_QUEST_TRACKER:ForceAssist(questIndex)
	end)

	EM:RegisterForEvent(QTI.name, EVENT_QUEST_CONDITION_COUNTER_CHANGED, function(_, questIndex)
		FOCUSED_QUEST_TRACKER:ForceAssist(questIndex)
	end)
end

EM:RegisterForEvent(QTI.name, EVENT_ADD_ON_LOADED, QTI.OnAddOnLoaded)