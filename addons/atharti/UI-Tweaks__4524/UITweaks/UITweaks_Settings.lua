local UIT = UITweaks

function UIT.RegisterLAMPanel()
	local LAM = LibAddonMenu2

local optionsData = {
	---------------------------------------------------------------
	-- HUD & Display
	---------------------------------------------------------------
	{ type = "header", name = "HUD & Display" },
	{
		type = "checkbox",
		name = "Hide Stealth Text",
		tooltip = "Removes the stealth-state text.",
		getFunc = function() return UIT.SV.HideStealth end,
		setFunc = function(value) UIT.SV.HideStealth = value end,
		default = false,
		requiresReload = true,
	},
	{
		type = "checkbox",
		name = "Hide Compass Directions",
		tooltip = "Hides North, South, West and East from the compass.",
		getFunc = function() return UIT.SV.HideDirections end,
		setFunc = function(value) UIT.SV.HideDirections = value end,
		default = false,
		requiresReload = true,
	},
	{
		type = "checkbox",
		name = "Hide Ability Bar Switch Icon",
		tooltip = "Hides the arrow icon from the action bar.",
		getFunc = function() return UIT.SV.HideSwap end,
		setFunc = function(value) UIT.SV.HideSwap = value end,
		default = false,
		requiresReload = true,
	},
	{
		type = "checkbox",
		name = "Hide Keybind Strip Backdrop",
		tooltip = "Hides the backdrop behind the keybind strip.",
		getFunc = function() return UIT.SV.HideKeyStripBackdrop end,
		setFunc = function(value) UIT.SV.HideKeyStripBackdrop = value end,
		default = false,
		requiresReload = true,
	},
	{
		type = "checkbox",
		name = "Hide Skills Advisor Key",
		tooltip = "Hides the Skills Advisor keybind from the keybind strip inside the Skills window.",
		getFunc = function() return UIT.SV.HideKeyStripAdvisor end,
		setFunc = function(value) UIT.SV.HideKeyStripAdvisor = value end,
		default = false,
		requiresReload = true,
	},
	{
		type = "checkbox",
		name = "Hide Night Market Faction Scores",
		tooltip = "Hides the Faction Scores UI.",
		getFunc = function() return UIT.SV.HideMarket end,
		setFunc = function(value) UIT.SV.HideMarket = value end,
		default = false,
		requiresReload = true,
	},
	{
		type = "checkbox",
		name = "Hide Guild Quit Button",
		tooltip = "Hides the 'Leave Guild' button from the guild home panel.",
		getFunc = function() return UIT.SV.NoQuitGuild end,
		setFunc = function(value) UIT.SV.NoQuitGuild = value end,
		default = false,
		requiresReload = true,
	},
	{
		type = "checkbox",
		name = "Account Achievements",
		tooltip = "Removes the 'Earned By: [character]' text from achievement descriptions.",
		getFunc = function() return UIT.SV.CleanAchievementText end,
		setFunc = function(value) UIT.SV.CleanAchievementText = value end,
		default = false,
		requiresReload = true,
	},

	---------------------------------------------------------------
	-- Camera & Interface
	---------------------------------------------------------------
	{ type = "header", name = "Camera & Interface" },
	{
		type = "checkbox",
		name = "Better Camera Zoom",
		tooltip = "Allows closer zooming to your character and first-person view while mounted.",
		getFunc = function() return UIT.SV.ZoomEnabled end,
		setFunc = function(value) UIT.SV.ZoomEnabled = value end,
		default = false,
		requiresReload = true,
	},
	{
		type = "checkbox",
		name = "Big Map",
		tooltip = "Expands the map size.",
		getFunc = function() return UIT.SV.BigMapEnabled end,
		setFunc = function(value) UIT.SV.BigMapEnabled = value end,
		default = false,
		requiresReload = true,
	},
	{
		type = "checkbox",
		name = "Don't Hide Chat Cursor",
		tooltip = "Prevents the cursor from being hidden when interacting with the chat window (pressing Enter). Disable if you encounter cursor issues.",
		getFunc = function() return UIT.SV.CursorFix end,
		setFunc = function(value) UIT.SV.CursorFix = value end,
		default = false,
		requiresReload = true,
	},
	{
		type = "checkbox",
		name = "Don't Interrupt Interactions",
		tooltip = "Opening various menus won't interrupt interaction with objects (resource nodes, chests, etc.).",
		getFunc = function() return UIT.SV.dontStopInteraction end,
		setFunc = function(value) UIT.SV.dontStopInteraction = value end,
		default = false,
		requiresReload = true,
	},

	---------------------------------------------------------------
	-- Keybinds
	---------------------------------------------------------------
	{ type = "header", name = "Keybinds" },
	{
		type = "checkbox",
		name = "Fullscreen / Borderless Toggle Keybind",
		tooltip = "Adds a keybind to toggle between Borderless Window and Exclusive Fullscreen.",
		getFunc = function() return UIT.SV.FullScreenToggle end,
		setFunc = function(value) UIT.SV.FullScreenToggle = value end,
		default = false,
		requiresReload = true,
	},
	{
		type = "checkbox",
		name = "ReloadUI Keybind",
		tooltip = "Adds a keybind for ReloadUI.",
		getFunc = function() return UIT.SV.ReloadUI end,
		setFunc = function(value) UIT.SV.ReloadUI = value end,
		default = false,
		requiresReload = true,
	},
	{
		type = "checkbox",
		name = "Container Opener Keybind",
		tooltip = "Adds a keybind to automatically open all containers in your inventory.",
		getFunc = function() return UIT.SV.ContainerOpenerEnabled end,
		setFunc = function(value) UIT.SV.ContainerOpenerEnabled = value end,
		default = false,
		requiresReload = true,
	},
	{
		type = "checkbox",
		name = "Shift+Click to Chat Link",
		tooltip = "Allows you to Shift+Click on inventory items to link them in chat.",
		getFunc = function() return UIT.SV.ChatLinkEnabled end,
		setFunc = function(value) UIT.SV.ChatLinkEnabled = value end,
		default = false,
		requiresReload = true,
	},

	---------------------------------------------------------------
	-- Slash Commands
	---------------------------------------------------------------
	{ type = "header", name = "Slash Commands" },
	{
		type = "checkbox",
		name = "Enable /visit Command",
		tooltip = "Adds the /visit @player command to travel to another player's house.",
		getFunc = function() return UIT.SV.visitPlayer end,
		setFunc = function(value) UIT.SV.visitPlayer = value end,
		default = false,
		requiresReload = true,
	},

	---------------------------------------------------------------
	-- Inventory Context Menu
	---------------------------------------------------------------
	{ type = "header", name = "Inventory Context Menu" },
	{
		type = "checkbox",
		name = "Hide 'Get Help'",
		tooltip = "Hides 'Get Help' from the inventory context menu.",
		getFunc = function() return UIT.SV.hideHelp end,
		setFunc = function(value) UIT.SV.hideHelp = value end,
		default = false,
		requiresReload = true,
	},
	{
		type = "checkbox",
		name = "Hide 'Destroy'",
		tooltip = "Hides 'Destroy' from the inventory context menu.",
		getFunc = function() return UIT.SV.hideDestroy end,
		setFunc = function(value) UIT.SV.hideDestroy = value end,
		default = false,
		requiresReload = true,
	},
	{
		type = "checkbox",
		name = "Hide 'Mark as Junk'",
		tooltip = "Hides 'Mark as Junk' from the inventory context menu.",
		getFunc = function() return UIT.SV.hideJunk end,
		setFunc = function(value) UIT.SV.hideJunk = value end,
		default = false,
		requiresReload = true,
	},
	{
		type = "checkbox",
		name = "Hide 'Convert to Imperial Style'",
		tooltip = "Hides 'Convert to Imperial Style' from the inventory context menu.",
		getFunc = function() return UIT.SV.hideImperial end,
		setFunc = function(value) UIT.SV.hideImperial = value end,
		default = false,
		requiresReload = true,
	},
	{
		type = "checkbox",
		name = "Hide 'Convert to Morag Tong Style'",
		tooltip = "Hides 'Convert to Morag Tong Style' from the inventory context menu.",
		getFunc = function() return UIT.SV.hideMorag end,
		setFunc = function(value) UIT.SV.hideMorag = value end,
		default = false,
		requiresReload = true,
	},

	---------------------------------------------------------------
	-- Popups & Notifications
	---------------------------------------------------------------
	{ type = "header", name = "Popups & Notifications" },
	{
		type = "checkbox",
		name = "Suppress Enlightenment Popup",
		tooltip = "Hides the 'You are Enlightened!' popup that appears on login and when gaining/losing Enlightenment.",
		getFunc = function() return UIT.SV.enlightenmentOff end,
		setFunc = function(value) UIT.SV.enlightenmentOff = value end,
		default = false,
		requiresReload = true,
	},
	{
		type = "checkbox",
		name = "Hide Group Area Popup",
		tooltip = "Removes the popup about entering or leaving a Group Area, commonly seen in Craglorn.",
		getFunc = function() return UIT.SV.disableGroupAreaPopup end,
		setFunc = function(value) UIT.SV.disableGroupAreaPopup = value end,
		default = false,
		requiresReload = true,
	},
	{
		type = "checkbox",
		name = "Antiquarian Eye: Remove Text and Decline",
		tooltip = "When joining a digging site, hides the useless text and the Decline option.",
		getFunc = function() return UIT.SV.cleanAntiqTool end,
		setFunc = function(value) UIT.SV.cleanAntiqTool = value end,
		default = false,
		requiresReload = true,
	},

	---------------------------------------------------------------
	-- Miscellaneous
	---------------------------------------------------------------
	{ type = "header", name = "Miscellaneous" },
	{
		type = "checkbox",
		name = "Roll Rawl'kha (New Life)",
		tooltip = "Automatically abandons all New Life quests except the one that sends you to Rawl'kha to unlock 3 chests.",
		getFunc = function() return UIT.SV.RollRawlkhaEnabled end,
		setFunc = function(value) UIT.SV.RollRawlkhaEnabled = value end,
		default = false,
		requiresReload = true,
	},
}

	local panelData = {
		type = "panel",
		name = "UI Tweaks",
		displayName = "|cFFD700UI Tweaks|r",
		author = "|cFFD700@Atharti|r",
		registerForRefresh = true,
		registerForDefaults = true,
	}

	LAM:RegisterAddonPanel("UITweaksPanel", panelData)
	LAM:RegisterOptionControls("UITweaksPanel", optionsData)
end