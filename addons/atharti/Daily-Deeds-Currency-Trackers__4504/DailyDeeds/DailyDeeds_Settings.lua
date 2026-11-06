local DD = DailyDeeds
local LAM = LibAddonMenu2

function DD.RegisterLAMPanel()
	local optionsData = {
		-- XP
		{
			type = "header",
			name = "|t16:16:/esoui/art/icons/icon_experience.dds|t Experience Points",
		},
		{
			type = "checkbox",
			name = "Enable Tracker",
			getFunc = function() return not DD.SV.XP.isHidden end,
			setFunc = function(value)
				DD.SV.XP.isHidden = not value
				DD.RefreshVisibility()
			end,
			width = "full",
		},
		{
			type = "checkbox",
			name = "Disable Enlightenment at 3600 CP",
			tooltip = "When enabled, enlightened XP bonus is disabled at max champion points (3600)",
			getFunc = function() return DD.SV.XP.disableEnlightenmentAtMaxCP end,
			setFunc = function(value) DD.SV.XP.disableEnlightenmentAtMaxCP = value end,
		},
		{
			type = "button",
			name = "Reset",
			func = function() DD.ResetTracker("XP") end,
			width = "half",
		},

		-- Gold
		{
			type = "header",
			name = "|t16:16:/esoui/art/currency/currency_gold.dds|t Gold",
		},
		{
			type = "checkbox",
			name = "Enable Tracker",
			getFunc = function() return not DD.SV.Gold.isHidden end,
			setFunc = function(value)
				DD.SV.Gold.isHidden = not value
				DD.RefreshVisibility()
			end,
			width = "full",
		},
		{
			type = "checkbox",
			name = "Track Negative Changes",
			tooltip = "When disabled, only gold gains will be tracked (spending will be ignored)",
			getFunc = function() return DD.SV.Gold.trackNegatives end,
			setFunc = function(value) DD.SV.Gold.trackNegatives = value end,
		},
		{
			type = "button",
			name = "Reset",
			func = function() DD.ResetTracker("Gold") end,
			width = "half",
		},

		-- AP
		{
			type = "header",
			name = string.format("|t16:16:%s|t Alliance Points", GetCurrencyKeyboardIcon(CURT_ALLIANCE_POINTS)),
		},
		{
			type = "checkbox",
			name = "Enable Tracker",
			getFunc = function() return not DD.SV.AP.isHidden end,
			setFunc = function(value)
				DD.SV.AP.isHidden = not value
				DD.RefreshVisibility()
			end,
			width = "full",
		},
		{
			type = "checkbox",
			name = "Track Negative Changes",
			tooltip = "When disabled, only AP gains will be tracked (spending will be ignored)",
			getFunc = function() return DD.SV.AP.trackNegatives end,
			setFunc = function(value) DD.SV.AP.trackNegatives = value end,
		},
		{
			type = "checkbox",
			name = "Show In All Zones",
			tooltip = "When enabled, tracker will be visible in all zones (ignores zone restrictions)",
			getFunc = function() return DD.SV.AP.showInAllZones end,
			setFunc = function(value)
				DD.SV.AP.showInAllZones = value
				DD.RefreshVisibility()
			end,
		},
		{
			type = "button",
			name = "Reset",
			func = function() DD.ResetTracker("AP") end,
			width = "half",
		},

		-- Telvar
		{
			type = "header",
			name = string.format("|t16:16:%s|t Telvar Stones", GetCurrencyKeyboardIcon(CURT_TELVAR_STONES)),
		},
		{
			type = "checkbox",
			name = "Enable Tracker",
			getFunc = function() return not DD.SV.Telvar.isHidden end,
			setFunc = function(value)
				DD.SV.Telvar.isHidden = not value
				DD.RefreshVisibility()
			end,
			width = "full",
		},
		{
			type = "checkbox",
			name = "Track Negative Changes",
			tooltip = "When disabled, only Telvar gains will be tracked (losses will be ignored)",
			getFunc = function() return DD.SV.Telvar.trackNegatives end,
			setFunc = function(value) DD.SV.Telvar.trackNegatives = value end,
		},
		{
			type = "checkbox",
			name = "Show In All Zones",
			tooltip = "When enabled, tracker will be visible in all zones (ignores zone restrictions)",
			getFunc = function() return DD.SV.Telvar.showInAllZones end,
			setFunc = function(value)
				DD.SV.Telvar.showInAllZones = value
				DD.RefreshVisibility()
			end,
		},
		{
			type = "button",
			name = "Reset",
			func = function() DD.ResetTracker("Telvar") end,
			width = "half",
		},

		-- TradeBars
		{
			type = "header",
			name = string.format("|t16:16:%s|t Trade Bars", GetCurrencyKeyboardIcon(CURT_TRADE_BARS)),
		},
		{
			type = "checkbox",
			name = "Enable Tracker",
			getFunc = function() return not DD.SV.TradeBars.isHidden end,
			setFunc = function(value)
				DD.SV.TradeBars.isHidden = not value
				DD.RefreshVisibility()
			end,
			width = "full",
		},
		{
			type = "button",
			name = "Reset",
			func = function() DD.ResetTracker("TradeBars") end,
			width = "half",
		},

		-- Fortunes
		{
			type = "header",
			name = string.format("|t16:16:%s|t Archival Fortunes", GetCurrencyKeyboardIcon(CURT_ARCHIVAL_FORTUNES)),
		},
		{
			type = "checkbox",
			name = "Enable Tracker",
			getFunc = function() return not DD.SV.Fortunes.isHidden end,
			setFunc = function(value)
				DD.SV.Fortunes.isHidden = not value
				DD.RefreshVisibility()
			end,
			width = "full",
		},
		{
			type = "checkbox",
			name = "Track Negative Changes",
			tooltip = "When disabled, only Fortunes gains will be tracked (spending will be ignored)",
			getFunc = function() return DD.SV.Fortunes.trackNegatives end,
			setFunc = function(value) DD.SV.Fortunes.trackNegatives = value end,
		},
		{
			type = "checkbox",
			name = "Show In All Zones",
			tooltip = "When enabled, tracker will be visible in all zones (ignores zone restrictions)",
			getFunc = function() return DD.SV.Fortunes.showInAllZones end,
			setFunc = function(value)
				DD.SV.Fortunes.showInAllZones = value
				DD.RefreshVisibility()
			end,
		},
		{
			type = "button",
			name = "Reset",
			func = function() DD.ResetTracker("Fortunes") end,
			width = "half",
		},
	}

	local panelData = {
		type = "panel",
		name = "Daily Deeds",
		displayName = "|cFFD700Daily Deeds|r",
		author = "|cFFD700@Atharti|r",
		registerForRefresh = true,
	}

	LAM:RegisterAddonPanel("DailyDeedsPanel", panelData)
	LAM:RegisterOptionControls("DailyDeedsPanel", optionsData)
end