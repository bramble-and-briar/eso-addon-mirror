local QTI = QuestTrackerImproved

local FONT_CHOICES = {
	"Antique",
	"Handwritten",
	"Stone Tablet",
	"Gamepad Medium",
	"Gamepad Bold",
	"Gamepad Light",
	"Chat",
	"Bold",
	"Medium",
}

local FONT_CHOICES_VALUES = {
	"$(ANTIQUE_FONT)",
	"$(HANDWRITTEN_FONT)",
	"$(STONE_TABLET_FONT)",
	"$(GAMEPAD_MEDIUM_FONT)",
	"$(GAMEPAD_BOLD_FONT)",
	"$(GAMEPAD_LIGHT_FONT)",
	"$(CHAT_FONT)",
	"$(BOLD_FONT)",
	"$(MEDIUM_FONT)",
}

local STYLE_CHOICES = {
	"Soft Shadow (Thin)",
	"Soft Shadow (Thick)",
	"Thick Outline",
	"None",
}

local STYLE_CHOICES_VALUES = {
	"soft-shadow-thin",
	"soft-shadow-thick",
	"thick-outline",
	"none",
}

function QTI.RegisterSettings()
	local LAM = LibAddonMenu2

	local panelData = {
		type = "panel",
		name = "Quest Tracker Improved",
		displayName = "|cFFD700Quest Tracker Improved|r",
		author = "|cFFD700@Atharti|r",
		registerForRefresh = true,
		registerForDefaults = true,
	}

	local optionsData = {
		{
			type = "header",
			name = "|t35:35:/esoui/art/treeicons/gamepad/gp_tools.dds|t General Settings",
		},
		{
			type = "slider",
			name = "Width",
			tooltip = "Total width of the quest tracker panel and its lines.",
			min = 100,
			max = 600,
			step = 1,
			getFunc = function() return QTI.SV.width end,
			setFunc = function(value) QTI.SV.width = value; QTI.RefreshAll() end,
		},
		{
			type = "slider",
			name = "Icon Size",
			tooltip = "Size of the quest icon shown next to the header.",
			min = 8,
			max = 48,
			step = 1,
			getFunc = function() return QTI.SV.iconSize end,
			setFunc = function(value) QTI.SV.iconSize = value; QTI.RefreshAll() end,
		},	
		{
			type = "checkbox",
			name = "Hide Pinned Golden Pursuits",
			tooltip = "Hides pinned Golden Pursuits task under quest tracker.",
			min = 8,
			max = 48,
			step = 1,
			getFunc = function() return QTI.SV.hidePursuits end,
			setFunc = function(value) QTI.SV.hidePursuits = value end,
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = "Keep Activities Under QuestTracker",
			tooltip = "Anchors the shared tracker container (activity, housing, etc.) under the quest tracker.",
			getFunc = function() return QTI.SV.stickyTrackers end,
			setFunc = function(value)
				QTI.SV.stickyTrackers = value
			end,
			requiresReload = true,
		},
		{
			type = "header",
			name = "|t30:30:/esoui/art/notifications/gamepad/gp_notificationicon_quest.dds|t Quest Header",
		},
		{
			type = "dropdown",
			name = "Font",
			tooltip = "Font used for the quest name.",
			choices = FONT_CHOICES,
			choicesValues = FONT_CHOICES_VALUES,
			getFunc = function() return QTI.SV.headerFont end,
			setFunc = function(value) QTI.SV.headerFont = value; QTI.RefreshAll() end,
			width = "half",
		},
		{
			type = "slider",
			name = "Size",
			tooltip = "Size of the quest name font.",
			min = 8,
			max = 40,
			step = 1,
			getFunc = function() return QTI.SV.headerSize end,
			setFunc = function(value) QTI.SV.headerSize = value; QTI.RefreshAll() end,
			width = "half",
		},
		{
			type = "colorpicker",
			name = "Color",
			tooltip = "Text color of the quest name.",
			getFunc = function()
				local c = QTI.SV.headerColor
				return c.r, c.g, c.b, c.a
			end,
			setFunc = function(r, g, b, a)
				QTI.SV.headerColor = { r = r, g = g, b = b, a = a }
				QTI.RefreshAll()
			end,
			width = "half",
		},
		{
			type = "dropdown",
			name = "Style",
			tooltip = "Text style of the quest name.",
			choices = STYLE_CHOICES,
			choicesValues = STYLE_CHOICES_VALUES,
			getFunc = function() return QTI.SV.headerStyle end,
			setFunc = function(value) QTI.SV.headerStyle = value; QTI.RefreshAll() end,
			width = "half",
		},

		{
			type = "header",
			name = "|t30:30:/esoui/art/notifications/gamepad/gp_notificationicon_quest.dds|t Description",
		},
		{
			type = "dropdown",
			name = "Font",
			tooltip = "Font used for main quest conditions.",
			choices = FONT_CHOICES,
			choicesValues = FONT_CHOICES_VALUES,
			getFunc = function() return QTI.SV.conditionFont end,
			setFunc = function(value) QTI.SV.conditionFont = value; QTI.RefreshAll() end,
			width = "half",
		},
		{
			type = "slider",
			name = "Size",
			tooltip = "Size of the condition font.",
			min = 8,
			max = 40,
			step = 1,
			getFunc = function() return QTI.SV.conditionSize end,
			setFunc = function(value) QTI.SV.conditionSize = value; QTI.RefreshAll() end,
			width = "half",
		},
		{
			type = "colorpicker",
			name = "Color",
			tooltip = "Text color of main quest conditions.",
			getFunc = function()
				local c = QTI.SV.conditionColor
				return c.r, c.g, c.b, c.a
			end,
			setFunc = function(r, g, b, a)
				QTI.SV.conditionColor = { r = r, g = g, b = b, a = a }
				QTI.RefreshAll()
			end,
			width = "half",
		},
		{
			type = "dropdown",
			name = "Style",
			tooltip = "Text style of conditions.",
			choices = STYLE_CHOICES,
			choicesValues = STYLE_CHOICES_VALUES,
			getFunc = function() return QTI.SV.conditionStyle end,
			setFunc = function(value) QTI.SV.conditionStyle = value; QTI.RefreshAll() end,
			width = "half",
		},

		{
			type = "header",
			name = "|t30:30:/esoui/art/notifications/gamepad/gp_notificationicon_quest.dds|t Hints",
		},
		{
			type = "dropdown",
			name = "Font",
			tooltip = "Font used for hint steps.",
			choices = FONT_CHOICES,
			choicesValues = FONT_CHOICES_VALUES,
			getFunc = function() return QTI.SV.hintFont end,
			setFunc = function(value) QTI.SV.hintFont = value; QTI.RefreshAll() end,
			width = "half",
		},
		{
			type = "slider",
			name = "Size",
			tooltip = "Size of the hint font.",
			min = 8,
			max = 40,
			step = 1,
			getFunc = function() return QTI.SV.hintSize end,
			setFunc = function(value) QTI.SV.hintSize = value; QTI.RefreshAll() end,
			width = "half",
		},
		{
			type = "colorpicker",
			name = "Color",
			tooltip = "Text color of hint steps.",
			getFunc = function()
				local c = QTI.SV.hintColor
				return c.r, c.g, c.b, c.a
			end,
			setFunc = function(r, g, b, a)
				QTI.SV.hintColor = { r = r, g = g, b = b, a = a }
				QTI.RefreshAll()
			end,
			width = "half",
		},
		{
			type = "dropdown",
			name = "Style",
			tooltip = "Text style of hint steps.",
			choices = STYLE_CHOICES,
			choicesValues = STYLE_CHOICES_VALUES,
			getFunc = function() return QTI.SV.hintStyle end,
			setFunc = function(value) QTI.SV.hintStyle = value; QTI.RefreshAll() end,
			width = "half",
		},

		{
			type = "header",
			name = "|t30:30:/esoui/art/notifications/gamepad/gp_notificationicon_quest.dds|t Hint Description",
		},
		{
			type = "dropdown",
			name = "Font",
			tooltip = "Font used for hint section headers.",
			choices = FONT_CHOICES,
			choicesValues = FONT_CHOICES_VALUES,
			getFunc = function() return QTI.SV.hintDescFont end,
			setFunc = function(value) QTI.SV.hintDescFont = value; QTI.RefreshAll() end,
			width = "half",
		},
		{
			type = "slider",
			name = "Size",
			tooltip = "Size of the hint description font.",
			min = 8,
			max = 40,
			step = 1,
			getFunc = function() return QTI.SV.hintDescSize end,
			setFunc = function(value) QTI.SV.hintDescSize = value; QTI.RefreshAll() end,
			width = "half",
		},
		{
			type = "colorpicker",
			name = "Color",
			tooltip = "Text color of hint section headers.",
			getFunc = function()
				local c = QTI.SV.hintDescColor
				return c.r, c.g, c.b, c.a
			end,
			setFunc = function(r, g, b, a)
				QTI.SV.hintDescColor = { r = r, g = g, b = b, a = a }
				QTI.RefreshAll()
			end,
			width = "half",
		},
		{
			type = "dropdown",
			name = "Style",
			tooltip = "Text style of hint descriptions.",
			choices = STYLE_CHOICES,
			choicesValues = STYLE_CHOICES_VALUES,
			getFunc = function() return QTI.SV.hintDescStyle end,
			setFunc = function(value) QTI.SV.hintDescStyle = value; QTI.RefreshAll() end,
			width = "half",
		},
	}

	LAM:RegisterAddonPanel("QuestTrackerImprovedPanel", panelData)
	LAM:RegisterOptionControls("QuestTrackerImprovedPanel", optionsData)
end