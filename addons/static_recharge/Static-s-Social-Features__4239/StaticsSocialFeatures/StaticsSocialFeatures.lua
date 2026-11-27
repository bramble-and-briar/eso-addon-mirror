--[[------------------------------------------------------------------------------------------------
Title:					Static's Social Features
Author:					Static_Recharge
Version:				2.0.2
Description:		Adds specific social featues.
------------------------------------------------------------------------------------------------]]--


--[[------------------------------------------------------------------------------------------------
Libraries and Aliases
------------------------------------------------------------------------------------------------]]--
local CS = CHAT_SYSTEM
local EM = EVENT_MANAGER
local CR = CHAT_ROUTER
local LS = LibStatic


--[[------------------------------------------------------------------------------------------------
StaticsSocialFeatures Class Initialization
StaticsSocialFeatures    													- Parent object containing all functions, tables, variables, constants and other data managers.
├─ :IsInitialized()                               - Returns true if the object has been successfully initialized.
├─ :LogoutQuitHook()															- Hooks into the logout and quit function to set character status if needed before actually logging out.
├─ :FriendMessageHook()                						- Hooks into the friends message to allow only showing for fav friends.
├─ :GetCharacterIndex()                						- Returns the index of the curent character from the saved vars table.
├─ :OnPlayerActivated(initial) 										- Fires once after load or reload. Performs various on load functions.
├─ :UpdateGuildList() 														- Updates the internal guild list data.
└─ :Test(...)                                     - For internal add-on testing only.
------------------------------------------------------------------------------------------------]]--
StaticsSocialFeatures = {}
local SSF = StaticsSocialFeatures

-- Static definitions
SSF.addonName = "StaticsSocialFeatures"
SSF.addonVersion = "2.0.2"
SSF.varsVersion = 2 -- SHOULD BE 2
SSF.charVarsVersion = 1
SSF.author = "|CFF0000Static_Recharge|r"

--[[------------------------------------------------------------------------------------------------
SSF.Initialize()
Inputs:				None
Outputs:			None
Description:	Initializes all of the variables, modules, slash commands, keybinds and main events.
------------------------------------------------------------------------------------------------]]--
function SSF.Initialize()
	-- Paired Lists
	SSF.PlayerStatus = LS.PairedListNew(
		{"Disabled", "Online", "Away", "Do Not Disturb", "Offline"},
		{5, PLAYER_STATUS_ONLINE, PLAYER_STATUS_AWAY, PLAYER_STATUS_DO_NOT_DISTURB, PLAYER_STATUS_OFFLINE}
	)

	SSF.AllFavNone = LS.PairedListNew(
		{"All", "Fav", "None"},
		{1, 2, 3}
	)

	SSF.NotificationTypes = LS.PairedListNew(
		{"Chat", "Center Screen", "Alert"},
		{1, 2, 3}
	)

  SSF.NotificationSizes = LS.PairedListNew(
		{"Small", "Medium", "Large"},
		{CSA_CATEGORY_SMALL_TEXT, CSA_CATEGORY_MAJOR_TEXT, CSA_CATEGORY_LARGE_TEXT}
	)

	SSF.NotificationSounds = LS.PairedListNew(
		{"None", "Book", "Default", "Map Open", "Error", "New Notification"},
		{SOUNDS.NONE, SOUNDS.BOOK_ACQUIRED, SOUNDS.DEFAULT_CLICK, SOUNDS.MAP_WINDOW_OPEN, SOUNDS.GENERAL_ALERT_ERROR, SOUNDS.NEW_NOTIFICATION}
	)

	SSF.UpdateGuildList()

	SSF.IconTextures = {
		"/esoui/art/compass/target_gold_star.dds",					-- Gold Star
		"/esoui/art/compass/target_blue_square.dds",				-- Blue Square
		"/esoui/art/compass/target_green_circle.dds",				-- Green Circle
		"/esoui/art/compass/target_orange_triangle.dds",		-- Orange Triangle
		"/esoui/art/compass/target_pink_moons.dds",					-- Pink Moons
		"/esoui/art/compass/target_purple_oblivion.dds",		-- Purple Oblivion
		"/esoui/art/compass/target_red_weapons.dds",				-- Red Weapons
		"/esoui/art/compass/target_white_skull.dds",				-- White Skull
		"/esoui/art/armory/buildicons/buildicon_5.dds",			-- CP Star
		"/esoui/art/armory/buildicons/buildicon_32.dds",		-- Dolmen Swirl
		"/esoui/art/armory/buildicons/buildicon_34.dds",		-- Veteran
		"/esoui/art/armory/buildicons/buildicon_46.dds",		-- DB Hand
		"/esoui/art/armory/buildicons/buildicon_49.dds",		-- Buddies
		"/esoui/art/tutorial/journal_tabicon_quest_up.dds",	-- Quest Icon
		"/esoui/art/buttons/featuredot_active.dds",					-- Feature Dot
	}

	SSF.Defaults = {
		-- Friends List
		favFriendsTop = true,
		sharedGuilds = SSF.AllFavNone.List.All,
		sharedGuildsGroup = true,
		favIconSize = 90, -- %
		favIconInheritColor = false,
		favIconTexture = SSF.IconTextures[1],

		-- Status
		charOverride = SSF.PlayerStatus.List.Disabled,
		charOverrideLogin = false,
		charOverrideLogout = false,
		accountOverride = SSF.PlayerStatus.List.Disabled,
		accountOverrideLogin = false,
		accountOverrideLogout = false,
		accountOverrideEnabled = true,
		afkTimerEnabled = true,
		afkTimeout = 600, -- seconds

		-- Notifications
		offlineNotice = true,
		groupInvite = SSF.AllFavNone.List.All,
		whisperNotice = true,
		notificationType = SSF.NotificationTypes["Center Screen"],
		notificationSize = SSF.NotificationSizes.List.Medium,
		notificationSound = SSF.NotificationSounds["Book Acquired"],
		afkNotice = true,
		offlineTimerEnabled = false,
		offlineTimeout = 10, -- minutes
		offlineTimerNotice = true,
		offlineTimerEnd = nil,
		multiMountNotify = true,
		friendMsg = SSF.AllFavNone.List.All,
		friendMsgChat = true,

		-- Repped Guild
		reppedGuildAccountSelection = 0,

		-- Lists and Tables
		Characters = {},
		Favs = {},
		Friends = {},
		Ignored = {},

		-- Misc.
		chatEnabled = true,
		debugEnabled = false,
		settingsChanged = true,
	}

	SSF.CharDefaults = {
		-- Multi Mount
		multiMountEnable = false,
		multiMount = nil,
		soloMount = nil,

		-- Repped Guild
		reppedGuildAccountEnabled = false,
		reppedGuildMarqueeEnabled = false,
		reppedGuildMarqueeInterval = 5, -- minutes
		reppedGuildMarqueeSelections = {},
	}

	-- Session variables
	SSF.chatRouterEventRedirected = false
	SSF.marqueeIndex = 1
	SSF.marqueeRunning = false
	

	-- Saved variables initialization
	SSF.SV = ZO_SavedVars:NewAccountWide("StaticsSocialFeaturesAccountWideVars", SSF.varsVersion, nil, SSF.Defaults, GetWorldName())
	SSF.CH = ZO_SavedVars:NewCharacterIdSettings("StaticsSocialFeaturesCharVars", SSF.charVarsVersion, nil, SSF.CharDefaults, GetWorldName())
	--RequestAddOnSavedVariablesPrioritySave(SSF.addonName)

	-- Update Character list (preserve any settings)
	local NewData = {}

	for i=1, GetNumCharacters() do
		local name, _, _, _, _, _, id, _ = GetCharacterInfo(i)
		local found = false
		name = zo_strformat("<<1>>", name)

		for index, value in ipairs(SSF.SV.Characters) do
			if value.id == id then
				NewData[i] = {name = name, id = id, charOverride = value.charOverride, charOverrideLogin = value.charOverrideLogin, charOverrideLogout = value.charOverrideLogout}
				found = true
				break
			end
		end

		if not found then
			NewData[i] = {name = name, id = id, charOverride = SSF.Defaults.charOverride, charOverrideLogin = SSF.Defaults.charOverrideLogin, charOverrideLogout = SSF.Defaults.charOverrideLogout}
		end
	end

	table.sort(NewData, function(a, b) return a.name < b.name end)
	SSF.SV.Characters = NewData

	-- Library Initializations
	local Options = {
		addonIdentifier = "SSF",
		prefixColor = "FF6600",
		textColor = "FFFFFF",
		chatEnabled = SSF.SV.chatEnabled,
		debugEnabled = SSF.SV.debugEnabled,
	}
	SSF.Chat = LS.ChatNew(Options)

	-- Module Initializations
	SSF.Status.Initialize()
	SSF.Notifications.Initialize()
	SSF.Lists.Initialize()
	SSF.Mounts.Initialize()
	SSF.Settings.Initialize()

	-- Hooks and Events
	SSF.LogoutQuitHook()
	SSF.FriendMessageHook()
	EM:RegisterForEvent(SSF.addonName, EVENT_PLAYER_ACTIVATED, SSF.OnPlayerActivated)

	-- Slash Commands
	--SLASH_COMMANDS["/ssftest"] = function(...) SSF.Test(...) end

	SSF.initialized = true
end


--[[------------------------------------------------------------------------------------------------
SSF.IsInitialized()
Inputs:				None
Outputs:			initialized                         - bool for object initialized state
Description:	Returns true if the object has been successfully initialized.
------------------------------------------------------------------------------------------------]]--
function SSF.IsInitialized()
  return SSF.initialized
end


--[[------------------------------------------------------------------------------------------------
SSF.LogoutQuitHook()
Inputs:			  None
Outputs:			None
Description:	Hooks into the logout and quit function to set character status if needed before actually logging out.
------------------------------------------------------------------------------------------------]]--
function SSF.LogoutQuitHook()
	function SSF.OnLogout()
		SSF.Chat:Debug("Logout/Quit prehook started.")
		if SSF.SV.accountOverrideEnabled and SSF.SV.accountOverrideLogout then
			SelectPlayerStatus(SSF.SV.accountOverride)
			SSF.Chat:Debug(zo_strformat("Player status set to <<1>>", SSF.SV.accountOverride))
		else
			local i = SSF.GetCharacterIndex()
			if SSF.SV.Characters[i].charOverride ~= SSF.PlayerStatus.List.Disabled and SSF.SV.Characters[i].charOverrideLogout then
				SelectPlayerStatus(SSF.SV.Characters[i].charOverride)
				SSF.Chat:Debug(zo_strformat("Player status set to <<1>>", SSF.SV.Characters[i].charOverride))
			end
		end
	end
	ZO_PreHook('Logout', function() SSF.OnLogout() end)
	ZO_PreHook('Quit', function() SSF.OnLogout() end)
end


--[[------------------------------------------------------------------------------------------------
SSF.FriendMessageHook()
Inputs:			  None
Outputs:			None
Description:	Hooks into the friends message to allow only showing for fav friends.
------------------------------------------------------------------------------------------------]]--
function SSF.FriendMessageHook()
	function SSF.OnFriendStatusChanged(eventCode, displayName, characterName, oldStatus, newStatus)
		SSF.Chat:Debug("Friend Message prehook started.")
		if SSF.SV.friendMsg == SSF.AllFavNone.List.None then return end
		if SSF.SV.friendMsg == SSF.AllFavNone.List.Fav and SSF.SV.Favs[displayName] then
			if not SSF.SV.friendMsgChat and SSF.SV.notificationType ~= SSF.NotificationTypes.List.Chat then
				local wasOnline = oldStatus ~= SSF.PlayerStatus.List.Offline
				local isOnline = newStatus ~= SSF.PlayerStatus.List.Offline
				if wasOnline ~= isOnline then
					local text
					if isOnline then
						SSF.Notifications.Notify(zo_strformat(SI_FRIENDS_LIST_FRIEND_CHARACTER_LOGGED_ON, displayName, characterName))
					else
						SSF.Notifications.Notify(zo_strformat(SI_FRIENDS_LIST_FRIEND_CHARACTER_LOGGED_OFF, displayName, characterName))
					end
				end
			else
				CR:FormatAndAddChatMessage(eventCode, displayName, characterName, oldStatus, newStatus)
			end
		end
	end
	if SSF.SV.friendMsg ~= SSF.AllFavNone.List.All and SSF.chatRouterEventRedirected == false then
		EM:UnregisterForEvent("ChatRouter", EVENT_FRIEND_PLAYER_STATUS_CHANGED)
		EM:RegisterForEvent("ChatRouter", EVENT_FRIEND_PLAYER_STATUS_CHANGED, SSF.OnFriendStatusChanged)
		SSF.chatRouterEventRedirected = true
	end
end


--[[------------------------------------------------------------------------------------------------
SSF.GetCharacterIndex()
Inputs:			  None
Outputs:			index 					- The index of the character
Description:	Returns the index of the curent character from the saved vars table.
------------------------------------------------------------------------------------------------]]--
function SSF.GetCharacterIndex()
	local index
	local id = GetCurrentCharacterId()
	for i, v in ipairs(SSF.SV.Characters) do
		if v.id == id then
			index = i
			break
		end
	end
	return index
end


--[[------------------------------------------------------------------------------------------------
SSF.OnPlayerActiviated()
Inputs:			  initial 														- (bool) true if first load after login
Outputs:			None
Description:	Fires once after load or reload. Performs various on load functions.
------------------------------------------------------------------------------------------------]]--
function SSF.OnPlayerActivated(eventCode, initial)
	-- Repped Guild Update
	SSF.ReppedGuildAccountWideUpdate()
	SSF.MarqueeUpdate()

	EM:UnregisterForEvent(SSF.addonName, EVENT_PLAYER_ACTIVATED)
end


--[[------------------------------------------------------------------------------------------------
SSF.ReppedGuildAccountWideUpdate()
Inputs:			  None
Outputs:			None
Description:	Updates the repped guild based on account wide setting.
------------------------------------------------------------------------------------------------]]--
function SSF.ReppedGuildAccountWideUpdate()
	local enabled, marquee = SSF.CH.reppedGuildAccountEnabled, SSF.CH.reppedGuildMarqueeEnabled
	local selection = SSF.SV.reppedGuildAccountSelection
	if enabled and not marquee then
		SetRepresentedGuildId(selection)
	end
end


--[[------------------------------------------------------------------------------------------------
SSF.UpdateGuildList()
Inputs:			  None
Outputs:			None
Description:	Updates the internal guild paired list.
------------------------------------------------------------------------------------------------]]--
function SSF.UpdateGuildList()
	local guildIds = {0}
	local guildNames = {"None"}
	for i=1, GetNumGuilds() do
		local id = GetGuildId(i)
		table.insert(guildNames, GetGuildName(id))
		table.insert(guildIds, id)
	end

	if not SSF.Guilds then
		SSF.Guilds = LS.PairedListNew(guildNames, guildIds)
	else
		SSF.Guilds:UpdateData(guildNames, guildIds)
	end
end


--[[------------------------------------------------------------------------------------------------
SSF.MarqueeUpdate()
Inputs:			  None
Outputs:			None
Description:	Updates the repped guild marquee system. Turns off if not needed.
------------------------------------------------------------------------------------------------]]--
function SSF.MarqueeUpdate()
	local function SetNextMarqueeGuild()
		local min, max = 1, #SSF.CH.reppedGuildMarqueeSelections
		SSF.marqueeIndex = SSF.marqueeIndex + 1
		if SSF.marqueeIndex > max then SSF.marqueeIndex = min end
		SetRepresentedGuildId(SSF.CH.reppedGuildMarqueeSelections[SSF.marqueeIndex])
	end

	if SSF.CH.reppedGuildMarqueeEnabled and #SSF.CH.reppedGuildMarqueeSelections >= 2 then
		if SSF.marqueeRunning then
			EM:UnregisterForUpdate(SSF.addonName)
		end
		SSF.marqueeIndex = 1
		EM:RegisterForUpdate(SSF.addonName, SSF.CH.reppedGuildMarqueeInterval * 60 * 1000, SetNextMarqueeGuild)
		SSF.marqueeRunning = true
	else
		EM:UnregisterForUpdate(SSF.addonName)
		SSF.marqueeRunning = false
	end
end


--[[------------------------------------------------------------------------------------------------
SSF.Test(...)
Inputs:				...							- Various test inputs.
Outputs:			None
Description:	For internal add-on testing only.
------------------------------------------------------------------------------------------------]]--
function SSF.Test(...)
	--SSF.Notifications.Notify(...)
	--SSF.Chat(...)
end


--[[------------------------------------------------------------------------------------------------
Main add-on event registration. Creates the global object, StaticsSocialFeatures, of the StaticsSocialFeatures class.
------------------------------------------------------------------------------------------------]]--
EM:RegisterForEvent("StaticsSocialFeatures", EVENT_ADD_ON_LOADED, function(eventCode, addonName)
	if addonName ~= "StaticsSocialFeatures" then return end
	EM:UnregisterForEvent("StaticsSocialFeatures", EVENT_ADD_ON_LOADED)
	SSF.Initialize()
end)