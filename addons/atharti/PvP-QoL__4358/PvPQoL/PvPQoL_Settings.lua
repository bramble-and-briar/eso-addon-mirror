local PQ = PvPQoL

function PQ.RegisterLAMPanel()
	local LAM = LibAddonMenu2
	local SV = PQ.SV

	local panelData = {
		type = "panel",
		name = "PvP QoL",
		displayName = "|cFFD700PvP QoL|r",
		author = "|cFFD700@Atharti|r",
		registerForRefresh = true,
	}

	local optionsData = {

			{
				type = "header",
				name = "|t30:30:esoui/art/addons/gamepad/gp_mod_listing_category_chat.dds|tChat Messages",
			},

			{
				type = "colorpicker",
				name = "Victim Name Color",
				tooltip = "Color used for the killed player name in chat.",
				getFunc = function()
					local r, g, b = ZO_ColorDef:New(SV.victimColor):UnpackRGB()
					return r, g, b
				end,
				setFunc = function(r, g, b)
					SV.victimColor = ZO_ColorDef:New(r, g, b):ToHex()
				end,
			},

			{
				type = "colorpicker",
				name = "Killer Name Color",
				tooltip = "Color used for the killer name in chat.",
				getFunc = function()
					local r, g, b = ZO_ColorDef:New(SV.killerColor):UnpackRGB()
					return r, g, b
				end,
				setFunc = function(r, g, b)
					SV.killerColor = ZO_ColorDef:New(r, g, b):ToHex()
				end,
			},
			{
				type = "colorpicker",
				name = "Arrow Color (→)",
				tooltip = "Color of the arrow shown before the killing blow ability.",
				getFunc = function()
					local r, g, b = ZO_ColorDef:New(SV.arrowColor):UnpackRGB()
					return r, g, b
				end,
				setFunc = function(r, g, b)
					SV.arrowColor = ZO_ColorDef:New(r, g, b):ToHex()
				end,
			},
			{
				type = "colorpicker",
				name = "Ability Name Color",
				tooltip = "Color of the killing blow ability name.",
				getFunc = function()
					local r, g, b = ZO_ColorDef:New(SV.abilityColor):UnpackRGB()
					return r, g, b
				end,
				setFunc = function(r, g, b)
					SV.abilityColor = ZO_ColorDef:New(r, g, b):ToHex()
				end,
			},
			{
				type = "checkbox",
				name = "Hide Killing Blow Ability",
				tooltip = "Removes the arrow and ability name from kill messages.",
				getFunc = function() return SV.hideArrowAndSkill end,
				setFunc = function(value) SV.hideArrowAndSkill = value end,
			},

			{
				type = "checkbox",
				name = "Hide Kill Icons",
				tooltip = "Removes the execute/skull icons from chat messages.",
				getFunc = function() return SV.hideKillIcons end,
				setFunc = function(value) SV.hideKillIcons = value end,
			},

			{
				type = "checkbox",
				name = "Hide Kill Messages",
				tooltip = "Completely prevents kill messages from appearing in chat.",
				getFunc = function() return SV.hideKillMessages end,
				setFunc = function(value)
					SV.hideKillMessages = value
					PQ.ManageEventHandlers()
				end,
			},
			{
				type = "checkbox",
				name = "Hide Death Messages",
				tooltip = "Prevents death messages from appearing in chat.",
				getFunc = function() return SV.hideDeathMessages end,
				setFunc = function(value)
					SV.hideDeathMessages = value
					PQ.ManageEventHandlers()
				end,
			},
			{
				type = "checkbox",
				name = "Use @Account Names",
				tooltip = "Show @AccountName instead of character name in kill/death messages.",
				getFunc = function() return SV.useAccountNames end,
				setFunc = function(value) SV.useAccountNames = value end,
			},
			{
				type = "checkbox",
				name = "Show PvP Rank Icons",
				tooltip = "Display PvP rank icons next to player names.",
				getFunc = function() return SV.showRankIcon end,
				setFunc = function(value)
					SV.showRankIcon = value
				end,
				requiresReload = true,
			},

			{
				type = "header",
				name = "|t35:35:esoui/art/armory/buildicons/buildicon_59.dds|tEffects",
			},

			{
				type = "colorpicker",
				name = "Screen Edge Flash Color",
				tooltip = "Change the color of the screen edge flash on killing blows.",
				getFunc = function()
					local r, g, b = ZO_ColorDef:New(SV.killFlashColor):UnpackRGB()
					return r, g, b
				end,
				setFunc = function(r, g, b)
					SV.killFlashColor = ZO_ColorDef:New(r, g, b):ToHex()
					PQ.SetupAlertBorderColors()
				end,
			},
			{
				type = "checkbox",
				name = "Disable Kill Sound",
				tooltip = "Disables the sound played on killing blows.",
				getFunc = function() return SV.disableKillSound end,
				setFunc = function(value) SV.disableKillSound = value end,
			},

			{
				type = "checkbox",
				name = "Disable Screen Edge Flash",
				tooltip = "Disables the screen edge flash when you get a kill.",
				getFunc = function() return SV.disableKillFlash end,
				setFunc = function(value) SV.disableKillFlash = value end,
			},

			{
			type = "header",
			name = "|t35:35:esoui/art/options/gamepad/gp_options_account.dds|tPlayers",
		},

		{
			type = "checkbox",
			name = "Enable Black Silhouettes",
			tooltip = "Players that are not loaded yet will be displayed as black models allowing you to interact with them instead of being fully invisible. Good to have on crowded momemnts if your graphics card is struggling. Will auto disable outside of PvP zones.",
			getFunc = function() return SV.enableStandIns end,
			setFunc = function(value)
				SV.enableStandIns = value
				PQ.ApplyStandInsSetting()
			end,
		},

		{
			type = "slider",
			name = "Silhouettes At Once",
			tooltip = "Number of players showed as black silhouettes at once.",
			min = 1,
			max = 32,
			step = 1,
			getFunc = function() return SV.standInsPerFrame end,
			setFunc = function(value)
				SV.standInsPerFrame = value
				PQ.ApplyStandInsSetting()
			end,
		},

		{
			type = "header",
			name = "|t30:30:esoui/art/addons/gamepad/gp_mod_listing_category_libraries.dds|t Statistics",
		},

		{
			type = "checkbox",
			name = "Disable Battlegrounds Mode",
			tooltip = "Battlegrounds wont have separate temporary stats.",
			getFunc = function() return SV.useUnifiedStats end,
			setFunc = function(value)
				SV.useUnifiedStats = value
				PQ.FlushBGCountersIfLeft()
				PQ.UpdateUI()
			end,
		},

		{
			type = "checkbox",
			name = "Track Daily Proofs, Merits & Tokens |t30:30:esoui/art/icons/fragment_gladiator_proof.dds|t",
			tooltip = "Track BG/IC/Cyrodiil medals daily gains in stats window.",
			getFunc = function() return SV.trackItems end,
			setFunc = function(value)
				SV.trackItems = value
			end,
			requiresReload = true,
		},

		{
			type = "header",
			name = "|t30:30:esoui/art/notifications/gamepad/gp_notificationicon_trade.dds|tCurrency Messages",
		},

		{
			type = "checkbox",
			name = "Hide Alliance Point Gains |t20:20:" .. GetCurrencyKeyboardIcon(CURT_ALLIANCE_POINTS) .. "|t",
			tooltip = "Prevents Alliance Point gain messages from appearing in chat.",
			getFunc = function() return SV.hideAPGains end,
			setFunc = function(value) SV.hideAPGains = value end,
		},

		{
			type = "checkbox",
			name = "Hide Tel Var Stone Gains |t20:20:" .. GetCurrencyKeyboardIcon(CURT_TELVAR_STONES) .. "|t",
			tooltip = "Prevents Tel Var Stone gain messages from appearing in chat.",
			getFunc = function() return SV.hideTelvarGains end,
			setFunc = function(value) SV.hideTelvarGains = value end,
		},

		{
			type = "slider",
			name = "Hide Telvar prints below:",
			tooltip = "Tel Var gains below this value will be hidden.",
			min = 0,
			max = 10000,
			step = 50,
			getFunc = function()
				return SV.minTelvarMessage
			end,
			setFunc = function(value)
				SV.minTelvarMessage = value
			end,
		},
		{
			type = "slider",
			name = "Hide AP prints below:",
			tooltip = "Alliance Point gains below this value will be hidden.",
			min = 0,
			max = 10000,
			step = 50,
			getFunc = function()
				return SV.minAPMessage
			end,
			setFunc = function(value)
				SV.minAPMessage = value
			end,
		},
		{
			type = "header",
			name = "|t35:35:esoui/art/icons/poi/poi_areaofinterest_complete.dds|tVisibility",
		},

		{
			type = "checkbox",
			name = "Enable addon and UI in all zones",
			tooltip = "Show the kill counter outside PvP areas.",
			getFunc = function() return SV.showEverywhere end,
			setFunc = function(value)
				SV.showEverywhere = value
				PQ.UpdateVisibility()
				PQ.ManageEventHandlers()
			end,
		},

		{
			type = "slider",
			name = "UI Scale",
			tooltip = "Scale the kill/death counter UI. Default is 1.0.",
			min = 1.0,
			max = 2.0,
			step = 0.1,
			decimals = 1,
			getFunc = function()
				return PQ.SV.uiScale
			end,
			setFunc = function(value)
				PQ.SetUIScale(value)
				PQ.UpdateUI()
			end,
		},

		-- =========================
		-- Auto-Accept Queues
		-- =========================
		{
			type = "header",
			name = "|t30:30:esoui/art/miscellaneous/timer_64.dds|tAuto-Accept Queues",
		},

		{
			type = "checkbox",
			name = "Auto Accept Cyrodiil and IC Queues",
			tooltip = "Automatically accepts PvP campaign queues.",
			getFunc = function() return SV.autoQueue end,
			setFunc = function(value)
				SV.autoQueue = value
			end,
			requiresReload = true,
		},

		{
			type = "checkbox",
			name = "Show Chat Message",
			tooltip = "Shows a message in chat when a queue is auto-accepted.",
			getFunc = function() return SV.chatQueue end,
			setFunc = function(value) SV.chatQueue = value end,
		},
		-- =========================
		-- Quest Helpers
		-- =========================
		{
			type = "header",
			name = "|t35:35:/esoui/art/notifications/gamepad/gp_notificationicon_quest.dds|tQuest Helpers",
		},
		{
			type = "checkbox",
			name = "AvA: Eliminate 20 Players",
			tooltip = "Will auto abandon all board quests except one to kill 20 players. Will auto turn-off once acuired once per day.",
			getFunc = function() return SV.helpIC end,
			setFunc = function(value) SV.helpIC = value end,
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = "BG: Win A Match",
			tooltip = "Will auto abandon all battleground quests except one to win a match. Will auto turn-off once acquired once per day.",
			getFunc = function() return SV.helpBG end,
			setFunc = function(value)
				SV.helpBG = value
			end,
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = "AvA: Capture Any 9 Resources",
			tooltip = "Will auto abandon all Cyrodiil Conquest Missions Board quests except the one to capture any 9 resourses. Not as reliable as other two, as cant really be rerolled but can save some time in combination with switching campaigns. Will auto turn-off once acquired once per day.",
			getFunc = function() return SV.helpCYRO end,
			setFunc = function(value)
				SV.helpCYRO = value
			end,
			requiresReload = true,
		},

		-- =========================
		-- Miscellaneous
		-- =========================
		{
			type = "header",
			name = "|t35:35:esoui/art/lfg/gamepad/gp_lfg_menuicon_random.dds|tMiscellaneous",
		},

		{
			type = "checkbox",
			name = "Hide Keep Tooltip Ownership",
			tooltip = "Hides the Alliance and Guild owner information from keep tooltips.",
			getFunc = function() return SV.hideKeepTooltip end,
			setFunc = function(value)
				SV.hideKeepTooltip = value
			end,
			requiresReload = true,
		},
	}

	LAM:RegisterAddonPanel("PvPQoLPanel", panelData)
	LAM:RegisterOptionControls("PvPQoLPanel", optionsData)
end
