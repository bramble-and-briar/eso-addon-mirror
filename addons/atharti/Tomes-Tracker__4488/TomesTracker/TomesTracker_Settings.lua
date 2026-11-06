local TT = TomesTracker

function TT.RegisterLAMPanel()
	local LAM = LibAddonMenu2

	local optionsData = {
		{
			type = "header",
			name = "General Settings",
		},
		{
			type = "checkbox",
			name = "Hide Completed Tasks",
			tooltip = "Hide tome challenges that have been fully completed.",
			getFunc = function() return TT.SV.HideCompleted end,
			setFunc = function(value)
				TT.SV.HideCompleted = value
				TT.RefreshTasksPositions()
			end,
		},
		{
			type = "checkbox",
			name = "Chat Messages",
			tooltip = "Show tasks progress messages in chat.",
			getFunc = function() return TT.SV.chatUpdates end,
			setFunc = function(value)
				TT.SV.chatUpdates = value
			end,
		},
		{
			type = "checkbox",
			name = "Hide Reroll Count When Zero",
			tooltip = "Hide the reroll token count when you have 0 tokens available.",
			getFunc = function() return TT.SV.hideRerollsZero end,
			setFunc = function(value)
				TT.SV.hideRerollsZero = value
				TT.UpdateCurrency()
			end,
		},
		{
			type = "slider",
			name = "Background Opacity",
			tooltip = "Adjust the transparency of the Tomes Tracker panel background.",
			min = 0,
			max = 1,
			step = 0.1,
			decimals = 1,
			getFunc = function()
				return TT.SV.panelOpacity
			end,
			setFunc = function(value)
				TT.SV.panelOpacity = value
				TT.RefreshPanel()
			end,
		},
		{
			type = "slider",
			name = "UI Scale",
			tooltip = "Scale the Tomes Tracker panel size. Default is 1.0.",
			min = 0.9,
			max = 1.5,
			step = 0.05,
			decimals = 2,
			getFunc = function()
				return TT.SV.uiScale
			end,
			setFunc = function(value)
				TT.SV.uiScale = value
				TT.RefreshPanel()
			end,
		},
		{
			type = "checkbox",
			name = "Hide in Combat",
			tooltip = "Automatically hide the Tomes Tracker panel while in combat.",
			getFunc = function() return TT.SV.hideInCombat end,
			setFunc = function(value)
				TT.SV.hideInCombat = value
			end,
			requiresReload = true,
		},

	}

	local panelData = {
		type = "panel",
		name = "Tomes Tracker",
		displayName = "|cFFD700Tomes Tracker|r",
		author = "|cFFD700@Atharti|r",
		registerForRefresh = true,
	}

	LAM:RegisterAddonPanel("TomesTrackerPanel", panelData)
	LAM:RegisterOptionControls("TomesTrackerPanel", optionsData)
end