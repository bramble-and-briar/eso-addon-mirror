--[[------------------------------------------------------------------------------------------------
Title:          Settings
Author:         Static_Recharge
Description:    Creates and controls the settings menu and related saved variables.
------------------------------------------------------------------------------------------------]]--


--[[------------------------------------------------------------------------------------------------
Libraries and Aliases
------------------------------------------------------------------------------------------------]]--
local LAM2 = LibAddonMenu2
local CM = CALLBACK_MANAGER
local FL = FRIENDS_LIST
local WM = WINDOW_MANAGER
local EM = EVENT_MANAGER
local SSF = StaticsSocialFeatures


--[[------------------------------------------------------------------------------------------------
Settings Class Initialization
Settings    													            - Parent object containing all functions, tables, variables, constants and other data managers.
├─ :IsInitialized()                               - Returns true if the object has been successfully initialized.
├─ :CreateSettingsPanel()													- Creates and registers the settings panel with LibAddonMenu.
├─ :Update()                											- Updates the settings panel in LibAddonMenu.
├─ :Changed()               							- Fired when the player first loads in after a settings reset is forced.
└─ :GetParent()                                   - Returns the parent object of this object for reference to parent variables.
------------------------------------------------------------------------------------------------]]--
local Settings = {}


--[[------------------------------------------------------------------------------------------------
Settings.Initialize()
Inputs:				None  
Outputs:			None
Description:	Initializes all of the variables and tables.
------------------------------------------------------------------------------------------------]]--
function Settings.Initialize()
	Settings.eventSpace = "SSFSettings"

  Settings.CreateSettingsPanel()

	-- Event Registrations
	EM:RegisterForEvent(Settings.eventSpace, EVENT_PLAYER_ACTIVATED, Settings.Changed)

	Settings.initialized = true
end


--[[------------------------------------------------------------------------------------------------
Settings.IsInitialized()
Inputs:				None
Outputs:			initialized                         - bool for object initialized state
Description:	Returns true if the object has been successfully initialized.
------------------------------------------------------------------------------------------------]]--
function Settings.IsInitialized()
  return Settings.initialized
end


--[[------------------------------------------------------------------------------------------------
Settings.CreateSettingsPanel()
Inputs:				None  
Outputs:			None
Description:	Creates and registers the settings panel with LibAddonMenu.
------------------------------------------------------------------------------------------------]]--
function Settings.CreateSettingsPanel()
	local panelData = {
		type = "panel",
		name = "Static's Social Features",
		displayName = "|cFF6600Static's Social Features|r",
		author = SSF.author,
		website = "https://www.esoui.com/downloads/info4239-StaticsSocialFeatures.html",
		feedback = "https://www.esoui.com/portal.php?&uid=6533",
		slashCommand = "/ssfmenu",
		registerForRefresh = true,
		registerForDefaults = true,
		version = SSF.addonVersion,
	}

  local optionsData = {}
	local controls = {}
	local i = 1
	local k = 1

	optionsData[i] = {
		type = "header",
		name = "Friends List",
	}

	i = i + 1
	optionsData[i] = {
		type = "description",
    text = "You can add or remove friends from your Fav list by right clicking on their name in the friends list.",
    width = "full",
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Show Fav Friends at Top",
    getFunc = function() return SSF.SV.favFriendsTop end,
    setFunc = function(value)
			SSF.SV.favFriendsTop = value
			if value == false then
				FL.currentSortKey = "status"
			end
			FL:RefreshFilters()
		end,
    tooltip = "Shows your Fav friends at the top of your friends list at all times.",
    width = "full",
		default = SSF.Defaults.favFriendsTop,
	}

	i = i + 1
	optionsData[i] = {
		type = "dropdown",
		name = "Shared Guild Info", -- or string id or function returning a string
		choices = SSF.AllFavNone:GetChoices(),
		choicesValues = SSF.AllFavNone:GetValues(), -- if specified, these values will get passed to setFunc instead (optional)
		getFunc = function() return SSF.SV.sharedGuilds end, -- if multiSelect is true the getFunc must return a table
		setFunc = function(var) SSF.SV.sharedGuilds = var end, -- if multiSelect is true the setFunc's var must be a table
		tooltip = "Displays which guilds you share with the highlighted friend.",
		width = "full", -- or "half" (optional)
		scrollable = false, -- boolean or number, if set the dropdown will feature a scroll bar if there are a large amount of choices and limit the visible lines to the specified number or 10 if true is used (optional)
		default = SSF.Defaults.sharedGuilds, -- default value or function that returns the default value (optional)
		multiSelect = false, -- boolean or function returning a boolean. If set to true you can select multiple entries at the list (optional)
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Shared Guild Info in Group",
    getFunc = function() return SSF.SV.sharedGuildsGroup end,
    setFunc = function(value) SSF.SV.sharedGuildsGroup = value end,
    tooltip = "Displays which guilds you share with the highlighted group member.",
    width = "full",
		default = SSF.Defaults.sharedGuildsGroup,
	}

	i = i + 1
	optionsData[i] = {
		type = "dropdown",
		name = "Offline Group Invite", -- or string id or function returning a string
		choices = SSF.AllFavNone:GetChoices(),
		choicesValues = SSF.AllFavNone:GetValues(), -- if specified, these values will get passed to setFunc instead (optional)
		getFunc = function() return SSF.SV.groupInvite end, -- if multiSelect is true the getFunc must return a table
		setFunc = function(var) SSF.SV.groupInvite = var end, -- if multiSelect is true the setFunc's var must be a table
		tooltip = "Allows you to attempt to send group invite requests to friends showing as offline.",
		width = "full", -- or "half" (optional)
		scrollable = false, -- boolean or number, if set the dropdown will feature a scroll bar if there are a large amount of choices and limit the visible lines to the specified number or 10 if true is used (optional)
		default = SSF.Defaults.groupInvite, -- default value or function that returns the default value (optional)
		multiSelect = false, -- boolean or function returning a boolean. If set to true you can select multiple entries at the list (optional)
	}

	i = i + 1
	optionsData[i] = {
		type = "iconpicker",
		name = "Fav Icon", -- or string id or function returning a string
		choices = SSF.IconTextures,
		getFunc = function() return SSF.SV.favIconTexture end,
		setFunc = function(icon) SSF.SV.favIconTexture = icon SSF.Lists.UpdateFavIcon() end,
		maxColumns = 5, -- number of icons in one row (optional)
		visibleRows = 3, -- number of visible rows (optional)
		iconSize = 32, -- size of the icons (optional)
		width = "full", --or "half" (optional)
		default = SSF.Defaults.favIconTexture, -- default value or function that returns the default value (optional)
	}

	i = i + 1
	optionsData[i] = {
		type = "slider",
		name = "Icon Size (%)",
		getFunc = function() return SSF.SV.favIconSize end,
		setFunc = function(value) SSF.SV.favIconSize = value SSF.Lists.UpdateFavIcon() end,
		min = 50,
		max = 150,
		step = 5,
		clampInput = true,
		decimals = 0,
		autoSelect = false,
		readOnly = false,
		width = "full", -- or "half" (optional)
		default = SSF.Defaults.favIconSize,
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Inherit Text Color",
    getFunc = function() return SSF.SV.favIconInheritColor end,
    setFunc = function(value) SSF.SV.favIconInheritColor = value SSF.Lists.UpdateFavIcon() end,
    tooltip = "Makes the icon match the color of the text in the friends list.",
    width = "full",
		default = SSF.Defaults.favIconInheritColor,
	}

	i = i + 1
	optionsData[i] = {
		type = "header",
		name = "Player Status",
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "AFK Timeout",
    getFunc = function() return SSF.SV.afkTimerEnabled end,
    setFunc = function(value) SSF.SV.afkTimerEnabled = value if value then SSF.Status.StartAFKTimerAgain() end end,
    tooltip = "If enabled, switches you to Away after the timeout. Also automatically switches you back to Online when activity is detected.",
    width = "full",
		default = SSF.Defaults.afkTimerEnabled,
	}

	i = i + 1
	optionsData[i] = {
		type = "slider",
		name = "AFK Timeout (s)",
		getFunc = function() return SSF.SV.afkTimeout end,
		setFunc = function(value) SSF.SV.afkTimeout = value end,
		min = 30,
		max = 1200,
		step = 1,
		clampInput = false,
		decimals = 0,
		autoSelect = true,
		readOnly = false,
		width = "full", -- or "half" (optional)
		disabled = function() return not SSF.SV.afkTimerEnabled end,
		default = SSF.Defaults.afkTimeout,
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Offline Timeout",
    getFunc = function() return SSF.SV.offlineTimerEnabled end,
    setFunc = function(value) SSF.SV.offlineTimerEnabled = value end,
    tooltip = "If enabled, switches you to Online after the timeout. Usefull if you forget to turn yourself Online often. Disabling while the timer is running will cause it to stop. Relog to re-enable.",
    width = "full",
		default = SSF.Defaults.offlineTimerEnabled,
	}

	i = i + 1
	optionsData[i] = {
		type = "slider",
		name = "Offline Timeout (m)",
		getFunc = function() return SSF.SV.offlineTimeout end,
		setFunc = function(value) SSF.SV.offlineTimeout = value end,
		tooltip = "Changes to this will take effect on the next login.",
		min = 5,
		max = 30,
		step = 1,
		clampInput = false,
		decimals = 0,
		autoSelect = true,
		readOnly = false,
		width = "full", -- or "half" (optional)
		disabled = function() return not SSF.SV.offlineTimerEnabled end,
		default = SSF.Defaults.offlineTimeout,
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
		name = "Account Wide Override",
		getFunc = function() return SSF.SV.accountOverrideEnabled end,
		setFunc = function(value) SSF.SV.accountOverrideEnabled = value end,
		width = "Full",
		tooltip = "When enabled, all characters will use the same settings. Disable to set indivually for each character.",
		default = SSF.Defaults.accountOverrideEnabled,
	}

	i = i + 1
	optionsData[i] = {
		type = "dropdown",
		name = "Account Wide Status", -- or string id or function returning a string
		choices = SSF.PlayerStatus:GetChoices(),
		choicesValues = SSF.PlayerStatus:GetValues(), -- if specified, these values will get passed to setFunc instead (optional)
		getFunc = function() return SSF.SV.accountOverride end, -- if multiSelect is true the getFunc must return a table
		setFunc = function(var) SSF.SV.accountOverride = var end, -- if multiSelect is true the setFunc's var must be a table
		width = "full", -- or "half" (optional)
		scrollable = false, -- boolean or number, if set the dropdown will feature a scroll bar if there are a large amount of choices and limit the visible lines to the specified number or 10 if true is used (optional)
		default = SSF.Defaults.accountOverride, -- default value or function that returns the default value (optional)
		multiSelect = false, -- boolean or function returning a boolean. If set to true you can select multiple entries at the list (optional)
		disabled = function() return not SSF.SV.accountOverrideEnabled end,
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
		name = "Login",
		getFunc = function() return SSF.SV.accountOverrideLogin end,
		setFunc = function(value) SSF.SV.accountOverrideLogin = value end,
		width = "half",
		tooltip = "Force the selected status on character login.",
		disabled = function() return SSF.SV.accountOverride == SSF.PlayerStatus.List.Disabled or not SSF.SV.accountOverrideEnabled end,
		default = SSF.Defaults.accountOverrideLogin,
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
		name = "Logout",
		getFunc = function() return SSF.SV.accountOverrideLogout end,
		setFunc = function(value) SSF.SV.accountOverrideLogout = value end,
		width = "half",
		tooltip = "Force the selected status on character logout.",
		disabled = function() return SSF.SV.accountOverride == SSF.PlayerStatus.List.Disabled or not SSF.SV.accountOverrideEnabled end,
		default = SSF.Defaults.accountOverrideLogout,
	}

	controls[k] = {
		type = "description",
    text = "If enabled, forces your player status for the specific characters.",
    width = "full",
	}

	for key, char in ipairs(SSF.SV.Characters) do
		k = k + 1
		local subcontrols = {}
		local j = 1
		subcontrols[j] = {
			type = "dropdown",
			name = "Status", -- or string id or function returning a string
			choices = SSF.PlayerStatus:GetChoices(),
			choicesValues = SSF.PlayerStatus:GetValues(), -- if specified, these values will get passed to setFunc instead (optional)
			getFunc = function() return char.charOverride end, -- if multiSelect is true the getFunc must return a table
			setFunc = function(var) char.charOverride = var end, -- if multiSelect is true the setFunc's var must be a table
			width = "full", -- or "half" (optional)
			scrollable = false, -- boolean or number, if set the dropdown will feature a scroll bar if there are a large amount of choices and limit the visible lines to the specified number or 10 if true is used (optional)
			default = SSF.Defaults.charOverride, -- default value or function that returns the default value (optional)
			multiSelect = false, -- boolean or function returning a boolean. If set to true you can select multiple entries at the list (optional)
		}

		j = j + 1
		subcontrols[j] = {
			type = "checkbox",
			name = "Login",
			getFunc = function() return char.charOverrideLogin end,
			setFunc = function(value) char.charOverrideLogin = value end,
			width = "half",
			tooltip = "Force the selected status on character login.",
			disabled = function() return char.charOverride == SSF.PlayerStatus.List.Disabled end,
			default = SSF.Defaults.charOverrideLogin,
		}

		j = j + 1
		subcontrols[j] = {
			type = "checkbox",
			name = "Logout",
			getFunc = function() return char.charOverrideLogout end,
			setFunc = function(value) char.charOverrideLogout = value end,
			width = "half",
			tooltip = "Force the selected status on character logout.",
			disabled = function() return char.charOverride == SSF.PlayerStatus.List.Disabled end,
			default = SSF.Defaults.charOverrideLogout,
		}

		controls[k] = {
			type = "submenu",
			name = char.name,
			controls = subcontrols,
		}			
	end

	i = i + 1
	optionsData[i] = {
		type = "submenu",
		name = "Character Status",
		controls = controls,
		disabled = function() return SSF.SV.accountOverrideEnabled end,
		tooltip = function() if SSF.SV.accountOverrideEnabled then return "Disable Account Wide Overide to select per character status." end end,
	}

	i = i + 1
	optionsData[i] = {
		type = "header",
		name = "Notifications",
	}

	i = i + 1
	optionsData[i] = {
		type = "dropdown",
		name = "Notification Type", -- or string id or function returning a string
		choices = SSF.NotificationTypes:GetChoices(),
		choicesValues = SSF.NotificationTypes:GetValues(), -- if specified, these values will get passed to setFunc instead (optional)
		getFunc = function() return SSF.SV.notificationType end, -- if multiSelect is true the getFunc must return a table
		setFunc = function(var) SSF.SV.notificationType = var end, -- if multiSelect is true the setFunc's var must be a table
		tooltip = "Choose where to redirect the notifications from this add-on. If directed to chat, chat messages must be enabled in Misc.",
		width = "full", -- or "half" (optional)
		scrollable = false, -- boolean or number, if set the dropdown will feature a scroll bar if there are a large amount of choices and limit the visible lines to the specified number or 10 if true is used (optional)
		default = SSF.Defaults.notificationType, -- default value or function that returns the default value (optional)
		multiSelect = false, -- boolean or function returning a boolean. If set to true you can select multiple entries at the list (optional)
	}

	i = i + 1
	optionsData[i] = {
		type = "dropdown",
		name = "Notification Size", -- or string id or function returning a string
		choices = SSF.NotificationSizes:GetChoices(),
		choicesValues = SSF.NotificationSizes:GetValues(), -- if specified, these values will get passed to setFunc instead (optional)
		getFunc = function() return SSF.SV.notificationSize end, -- if multiSelect is true the getFunc must return a table
		setFunc = function(var) SSF.SV.notificationSize = var end, -- if multiSelect is true the setFunc's var must be a table
		tooltip = "Size of center screen notifications.",
		width = "full", -- or "half" (optional)
		scrollable = false, -- boolean or number, if set the dropdown will feature a scroll bar if there are a large amount of choices and limit the visible lines to the specified number or 10 if true is used (optional)
		default = SSF.Defaults.notificationSize, -- default value or function that returns the default value (optional)
		multiSelect = false, -- boolean or function returning a boolean. If set to true you can select multiple entries at the list (optional)
		disabled = function() return SSF.SV.notificationType ~= SSF.NotificationTypes["Center Screen"] end,
	}

	i = i + 1
	optionsData[i] = {
		type = "dropdown",
		name = "Notification Sound", -- or string id or function returning a string
		choices = SSF.NotificationSounds:GetChoices(),
		choicesValues = SSF.NotificationSounds:GetValues(), -- if specified, these values will get passed to setFunc instead (optional)
		getFunc = function() return SSF.SV.notificationSound end, -- if multiSelect is true the getFunc must return a table
		setFunc = function(var) SSF.SV.notificationSound = var PlaySound(SSF.SV.notificationSound) end, -- if multiSelect is true the setFunc's var must be a table
		width = "full", -- or "half" (optional)
		scrollable = false, -- boolean or number, if set the dropdown will feature a scroll bar if there are a large amount of choices and limit the visible lines to the specified number or 10 if true is used (optional)
		default = SSF.Defaults.notificationSound, -- default value or function that returns the default value (optional)
		multiSelect = false, -- boolean or function returning a boolean. If set to true you can select multiple entries at the list (optional)
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Offline Notice",
    getFunc = function() return SSF.SV.offlineNotice end,
    setFunc = function(value) SSF.SV.offlineNotice = value end,
    tooltip = "Notifies you on login if you're set to Offline.",
    width = "full",
		default = SSF.Defaults.offlineNotice,
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Offline Timer Notice",
    getFunc = function() return SSF.SV.offlineTimerNotice end,
    setFunc = function(value) SSF.SV.offlineTimerNotice = value end,
    tooltip = "Notifies you when you are automatically set to Online via the Offline Timer.",
    width = "full",
		default = SSF.Defaults.offlineTimerNotice,
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Whisper Notice",
    getFunc = function() return SSF.SV.whisperNotice end,
    setFunc = function(value) SSF.SV.whisperNotice = value end,
    tooltip = "Notifies you when you send a whisper and are offline.",
    width = "full",
		default = SSF.Defaults.whisperNotice,
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "AFK Notice",
    getFunc = function() return SSF.SV.afkNotice end,
    setFunc = function(value) SSF.SV.afkNotice = value end,
    tooltip = "Notifies you when you are set to AFK or back to Online from AFK.",
    width = "full",
		default = SSF.Defaults.afkNotice,
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Multi-Rider as Passenger Notice",
    getFunc = function() return SSF.SV.multiMountNotify end,
    setFunc = function(value) SSF.SV.multiMountNotify = value end,
		tooltip = "Shows a notification with the name of the person you mounted.",
    width = "full",
		default = SSF.Defaults.multiMountNotify,
	}

	i = i + 1
	optionsData[i] = {
		type = "dropdown",
		name = "Friend Status Messages", -- or string id or function returning a string
		choices = SSF.AllFavNone:GetChoices(), --{"All", "Fav Only", "None"},
		choicesValues = SSF.AllFavNone:GetValues(), -- if specified, these values will get passed to setFunc instead (optional)
		getFunc = function() return SSF.SV.friendMsg end, -- if multiSelect is true the getFunc must return a table
		setFunc = function(var) SSF.SV.friendMsg = var end, -- if multiSelect is true the setFunc's var must be a table
		tooltip = "Control which friend status messages are displayed.",
		width = "full", -- or "half" (optional)
		scrollable = false, -- boolean or number, if set the dropdown will feature a scroll bar if there are a large amount of choices and limit the visible lines to the specified number or 10 if true is used (optional)
		default = SSF.Defaults.friendMsg, -- default value or function that returns the default value (optional)
		multiSelect = false, -- boolean or function returning a boolean. If set to true you can select multiple entries at the list (optional)
		requiresReload = true, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Friend Status to Chat",
    getFunc = function() return SSF.SV.friendMsgChat end,
    setFunc = function(value) SSF.SV.friendMsgChat = value end,
    tooltip = "If disabled the friend notices will follow the notification settings above.",
    width = "full",
		default = SSF.Defaults.friendMsgChat,
		disabled = function() return SSF.SV.friendMsg == SSF.AllFavNone.List.None end,
	}

  i = i + 1
  optionsData[i] = {
		type = "header",
		name = "Mount Features",
	}

	i = i + 1
  optionsData[i] = {
		type = "description",
    text = "These settings are character specific.",
    width = "full",
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Auto Switch to Multi-Rider",
    getFunc = function() return SSF.CH.multiMountEnable end,
    setFunc = function(value) SSF.CH.multiMountEnable = value end,
    width = "full",
		default = SSF.CharDefaults.multiMountEnable,
	}

	i = i + 1
	optionsData[i] = {
		type = "dropdown",
		name = "Solo Mount", -- or string id or function returning a string
		choices = SSF.Mounts.SoloMount:GetChoices(), --{"All", "Fav Only", "None"},
		choicesValues = SSF.Mounts.SoloMount:GetValues(), -- if specified, these values will get passed to setFunc instead (optional)
		getFunc = function() return SSF.CH.soloMount end, -- if multiSelect is true the getFunc must return a table
		setFunc = function(var) SSF.CH.soloMount = var end, -- if multiSelect is true the setFunc's var must be a table
		tooltip = "Which solo mount to switch to.",
		width = "full", -- or "half" (optional)
		scrollable = true, -- boolean or number, if set the dropdown will feature a scroll bar if there are a large amount of choices and limit the visible lines to the specified number or 10 if true is used (optional)
		default = SSF.CharDefaults.soloMount, -- default value or function that returns the default value (optional)
		multiSelect = false, -- boolean or function returning a boolean. If set to true you can select multiple entries at the list (optional)
		requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
		disabled = function() return not SSF.CH.multiMountEnable end,
		reference = "SSF_SoloMountDropdown_LAM",
	}

	i = i + 1
	optionsData[i] = {
		type = "dropdown",
		name = "Multi Mount", -- or string id or function returning a string
		choices = SSF.Mounts.MultiMount:GetChoices(), --{"All", "Fav Only", "None"},
		choicesValues = SSF.Mounts.MultiMount:GetValues(), -- if specified, these values will get passed to setFunc instead (optional)
		getFunc = function() return SSF.CH.multiMount end, -- if multiSelect is true the getFunc must return a table
		setFunc = function(var) SSF.CH.multiMount = var end, -- if multiSelect is true the setFunc's var must be a table
		tooltip = "Which multi mount to switch to.",
		width = "full", -- or "half" (optional)
		scrollable = true, -- boolean or number, if set the dropdown will feature a scroll bar if there are a large amount of choices and limit the visible lines to the specified number or 10 if true is used (optional)
		default = SSF.CharDefaults.multiMount, -- default value or function that returns the default value (optional)
		multiSelect = false, -- boolean or function returning a boolean. If set to true you can select multiple entries at the list (optional)
		requiresReload = false, -- boolean, if set to true, the warning text will contain a notice that changes are only applied after an UI reload and any change to the value will make the "Apply Settings" button appear on the panel which will reload the UI when pressed (optional)
		disabled = function() return not SSF.CH.multiMountEnable end,
		reference = "SSF_MultiMountDropdown_LAM",
	}

	i = i + 1
  optionsData[i] = {
		type = "header",
		name = "Repped Guild",
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Use Account Wide Repped Guild",
    getFunc = function() return SSF.CH.reppedGuildAccountEnabled end,
    setFunc = function(value) SSF.CH.reppedGuildAccountEnabled = value SSF.ReppedGuildAccountWideUpdate() end,
    width = "full",
		tooltip = "When enabled, this character's repped guild will be set to the selected account wide repped guild.",
		default = SSF.CharDefaults.reppedGuildAccountEnabled,
	}

	i = i + 1
	optionsData[i] = {
		type = "dropdown",
		name = "Account Wide Repped Guild",
		choices = SSF.Guilds:GetChoices(),
		choicesValues = SSF.Guilds:GetValues(),
		getFunc = function() return SSF.SV.reppedGuildAccountSelection end,
		setFunc = function(var) SSF.SV.reppedGuildAccountSelection = var SSF.ReppedGuildAccountWideUpdate() end,
		width = "full",
		scrollable = false,
		default = SSF.Defaults.reppedGuildAccountSelection,
		multiSelect = false,
		requiresReload = false,
		reference = "SSF_ReppedGuildAccountWideDropdown_LAM",
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Marquee Enabled",
    getFunc = function() return SSF.CH.reppedGuildMarqueeEnabled end,
    setFunc = function(value) SSF.CH.reppedGuildMarqueeEnabled = value SSF.MarqueeUpdate() end,
    width = "full",
		tooltip = "The marquee rotates through the selected repped guilds on a timer. This setting overrides the Account Wide Repped Guild setting and is character specific.",
		default = SSF.CharDefaults.reppedGuildMarqueeEnabled,
	}

	i = i + 1
	optionsData[i] = {
		type = "slider",
		name = "Marquee Interval (m)",
		getFunc = function() return SSF.CH.reppedGuildMarqueeInterval end,
		setFunc = function(value) SSF.CH.reppedGuildMarqueeInterval = value SSF.MarqueeUpdate() end,
		tooltip = "How long before the repped guild will be changed to the next selection in minutes.",
		min = 0.5,
		max = 15,
		step = 0.5,
		clampInput = true,
		decimals = 1,
		autoSelect = true,
		readOnly = false,
		width = "full",
		disabled = function() return not SSF.CH.reppedGuildMarqueeEnabled end,
		default = SSF.CharDefaults.reppedGuildMarqueeInterval,
	}

	i = i + 1
	optionsData[i] = {
    type = "dropdown",
    name = "Marquee Guilds",
    choices = SSF.Guilds:GetChoices(),
    --choicesValues = SSF.Guilds:GetValues(),
    getFunc = function() return SSF.Guilds:GetSelectedChoicesByValues(SSF.CH.reppedGuildMarqueeSelections) end,
    setFunc = function(var) SSF.CH.reppedGuildMarqueeSelections = SSF.Guilds:GetSelectedValuesByChoices(var) SSF.MarqueeUpdate() end,
		tooltip = "Must select at least two options for the marquee to work.",
    width = "full", -- or "half" (optional)
    scrollable = false,
    disabled = function() return not SSF.CH.reppedGuildMarqueeEnabled end,
    default = SSF.CharDefaults.reppedGuildMarqueeSelections,
    reference = "SSF_ReppedGuildMarqueeDropdown_LAM",
    multiSelect = true,
	}
	
	i = i + 1
  optionsData[i] = {
		type = "header",
		name = "Misc.",
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Chat Messages",
    getFunc = function() return SSF.SV.chatEnabled end,
    setFunc = function(value) SSF.SV.chatEnabled = value SSF.Chat:SetChatEnabled(value) end,
    tooltip = "Disables ALL chat messages from this add-on.",
    width = "half",
		default = SSF.Defaults.chatEnabled,
	}

	i = i + 1
	optionsData[i] = {
		type = "checkbox",
    name = "Debugging Mode",
    getFunc = function() return SSF.SV.debugEnabled end,
    setFunc = function(value) SSF.SV.debugEnabled = value SSF.Chat:SetDebugEnabled(value) end,
    tooltip = "Turns on extra messages for the purposes of debugging. Not intended for normal use. Must have chat messages enabled.",
    width = "half",
		default = SSF.Defaults.debugEnabled,
		disabled = function() return not SSF.SV.chatEnabled end,
	}

	local function LAMPanelCreated(panel)
		if panel ~= SSF.LAMSettingsPanel then return end
		SSF.Controls = {
			SoloMDD = WM:GetControlByName("SSF_SoloMountDropdown_LAM"),
			MultiMDD = WM:GetControlByName("SSF_MultiMountDropdown_LAM"),
			RepGuildDD = WM:GetControlByName("SSF_ReppedGuildAccountWideDropdown_LAM"),
			MarqueeDD = WM:GetControlByName("SSF_ReppedGuildMarqueeDropdown_LAM"),
		}
		SSF.LAMReady = true
	end

	local function LAMPanelOpened(panel)
		if panel ~= SSF.LAMSettingsPanel then return end
		if not SSF.LAMReady then return end
		Settings.Update()
	end

	SSF.LAMSettingsPanel = LAM2:RegisterAddonPanel(SSF.addonName .. "_LAM", panelData)
	CM:RegisterCallback("LAM-PanelControlsCreated", LAMPanelCreated)
	CM:RegisterCallback("LAM-PanelOpened", LAMPanelOpened)
	LAM2:RegisterOptionControls(SSF.addonName .. "_LAM", optionsData)
end


--[[------------------------------------------------------------------------------------------------
Settings.Update()
Inputs:				None
Outputs:			None
Description:	Updates the settings panel in LibAddonMenu.
------------------------------------------------------------------------------------------------]]--
function Settings.Update()
	if not SSF.LAMReady then return end

	local C = SSF.Controls
	local M = SSF.Mounts
	local G = SSF.Guilds

	M.UpdateMountData()
	C.SoloMDD:UpdateChoices(M.SoloMount:GetChoices(), M.SoloMount:GetValues())
	C.SoloMDD:UpdateValue()
	C.MultiMDD:UpdateChoices(M.MultiMount:GetChoices(), M.MultiMount:GetValues())
	C.MultiMDD:UpdateValue()

	SSF.UpdateGuildList()
	C.RepGuildDD:UpdateChoices(G:GetChoices(), G:GetValues())
	C.RepGuildDD:UpdateValue()
	C.MarqueeDD:UpdateChoices(G:GetChoices(), G:GetValues())
	C.MarqueeDD:UpdateValue()
end


--[[------------------------------------------------------------------------------------------------
Settings.Changed()
Inputs:				None
Outputs:			None
Description:	Fired when the player first loads in after a settings reset is forced.
------------------------------------------------------------------------------------------------]]--
function Settings.Changed()
	if SSF.SV.settingsChanged then 
		SSF.Chat:Msg(zo_strformat("Static's Social Features updated to <<1>>. Settings have been reset.", SSF.addonVersion))
		SSF.SV.settingsChanged = false
	end
	EM:UnregisterForEvent(Settings.eventSpace, EVENT_PLAYER_ACTIVATED)
end


--[[------------------------------------------------------------------------------------------------
Global template assignment
------------------------------------------------------------------------------------------------]]--
StaticsSocialFeatures.Settings = Settings