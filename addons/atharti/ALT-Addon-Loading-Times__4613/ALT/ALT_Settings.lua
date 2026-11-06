local ALT = AddonLoadingTimes

local LEJ = LibExtendedJournal

function ALT.RegisterSettingsPanel()
	local LAM = LibAddonMenu2

	local panelData = {
		type = "panel",
		name = "ALT",
		displayName = "|cFFD700Addon Loading Times|r",
		author = "|cFFD700@Atharti|r",
		registerForRefresh = true,
	}

	local optionsData = {
		{
			type = "header",
			name = "|t35:35:/esoui/art/treeicons/gamepad/gp_tools.dds|t Test Configuration",
		},

		{
			type = "slider",
			name = "Reload Delay",
			tooltip = "Time in seconds to wait between each reload.",
			min = 0,
			max = 15,
			step = 0.5,
			decimals = 1,
			getFunc = function()
				return ALT.SV.reloadDelay
			end,
			setFunc = function(value)
				ALT.SV.reloadDelay = value
			end,
			width = "half",
		},

		{
			type = "button",
			name = "Start Addons Test",
			func = function()
				if not ALT.AddonsData or next(ALT.AddonsData) == nil then
					ALT.CollectAddonsData()
				end
				ALT.ShowTestConfirmationDialog()
			end,
			width = "half",
			warning = "This will take a while. Move your character into a tavern room to minimize hardware impact on desync. The more addons you got, the longer tests will take.",
		},

		{
			type = "header",
			name = "|t35:35:/esoui/art/lfg/gamepad/gp_lfg_groupfinder_editlisting.dds|t Results Display",
		},

		{
			type = "button",
			name = "Open Results in Journal",
			tooltip = "Opens ExtendedJournal tab with your latest test results.",
			func = function()
				LEJ.Show("ALT_Results")
			end,
			width = "half",
		},

		{
			type = "button",
			name = "Clear Results",
			tooltip = "Clears all stored test results from memory.",
			func = function()
					ALT.ClearTestData()
					ALT.SV.originalState = {}
					ReloadUI()
			end,
			width = "half",
			warning = "This will permanently delete all test data and reload the UI.",
		},
		{
			type = "header",
			name = "|t35:35:/esoui/art/login/login_icon_info.dds|t Information",
		},

		{
			type = "description",
			text = "|cFFAA44Color Codes:|r\n\n" ..
				   "• |c44FF44Green|r: Low impact (~0 ms / <1 MB)\n" ..
				   "• |cFFAA44Orange|r: Medium impact (250-500 ms / 1-25 MB)\n" ..
				   "• |cFF4444Red|r: High impact (>500 ms / >25 MB)",
			width = "full",
		},
	}

	LAM:RegisterAddonPanel("ALT_SettingsPanel", panelData)
	LAM:RegisterOptionControls("ALT_SettingsPanel", optionsData)
end