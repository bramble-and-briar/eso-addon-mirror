--[[
-------------------------------------------------------------------------------
-- NoThankYou, by Ayantir
-------------------------------------------------------------------------------
This software is under : CreativeCommons CC BY-NC-SA 4.0
Attribution-NonCommercial-ShareAlike 4.0 International (CC BY-NC-SA 4.0)

You are free to:

    Share — copy and redistribute the material in any medium or format
    Adapt — remix, transform, and build upon the material
    The licensor cannot revoke these freedoms as long as you follow the license terms.


Under the following terms:

    Attribution — You must give appropriate credit, provide a link to the license, and indicate if changes were made. You may do so in any reasonable manner, but not in any way that suggests the licensor endorses you or your use.
    NonCommercial — You may not use the material for commercial purposes.
    ShareAlike — If you remix, transform, or build upon the material, you must distribute your contributions under the same license as the original.
    No additional restrictions — You may not apply legal terms or technological measures that legally restrict others from doing anything the license permits.


Please read full licence at :
http://creativecommons.org/licenses/by-nc-sa/4.0/legalcode
]]

local ADDON_NAME = "NoThankYou"
local ADDON_VERSION = "12.1.0"
local ADDON_AUTHOR = "|cEFEBBEGarkin|r, Ayantir, Vostorn, |c8794C5SlippyCheeze|r, Uta, ZaiZah,FusRoDah, Dr_Z"
local ADDON_WEBSITE = "http://www.esoui.com/downloads/info865-Nothankyou.html"
local SV
local defaults = {
	ava = 1,
	friends = false,
	boss = false,
	screenshot = false,
	enlightened = false,
	craftingResults = false,
	repair = false,
	alertTextExpiryDelay = 3, --seconds, 3 is default value used in AlertText
	emptyMail = true,
	guildAlerts = 0,
	guildAlertsGuilds = {},
	raid = 0,
	raidToChat = true,
	endless = true,
	notificationSound = false,
	motd = 0,
	motdGuilds = {},
	nonstopHarvest = false,
	noCameraSpin = false,
	noCameraSpinStats = false,
	noCameraSpinInv = false,
	fenceDialog = false,
	ultimateSound = 0,
	disbandDialog = false,
	largeGroupDialog = false,
	marketAnnouncement = false,
	improveDialog = false,
	guildInvites = 0,
	luaError = 1,
	dontReadBooks = false,
	noUniversalStones = false,
	noGuildLeave = 0,
	guildLeave = {},
	autoLootItems = false,
	craftBag = false,
	groupZone = 1,
	dontShowLoreDiscoveries = 0,
	dontShowSkillProgression = 0,
	noReportOnItems = false,
	dontAcceptWritQuest = false,
	disableChatAutoComplete = false,
	chatForTradingHouse = false,
	noBindAlert = false,
	noPortOnLeader = 0,
	emptyInteractions = false,
	guildApps = false,
}

for i = 1, MAX_GUILDS do
	defaults.guildAlertsGuilds[i] = true
	defaults.motdGuilds[i] = true
end

local recentMessages
local isQueued = false
local storedMessages = {}

local function SafePrint(message)
	if message == nil or not IsPlayerActivated or not CHAT_SYSTEM or not CHAT_SYSTEM.AddMessage or not EVENT_MANAGER or EVENT_PLAYER_ACTIVATED == nil or not ZO_ClearNumericallyIndexedTable then
		return
	end
	if IsPlayerActivated() then
		CHAT_SYSTEM:AddMessage(message)
	else
		table.insert(storedMessages, message)
		if not isQueued then
			isQueued = true
			EVENT_MANAGER:RegisterForEvent("NOTY_Print", EVENT_PLAYER_ACTIVATED,
				function(event)
					EVENT_MANAGER:UnregisterForEvent("NOTY_Print", event)
					for i, message in ipairs(storedMessages) do
						CHAT_SYSTEM:AddMessage(message)
					end
					ZO_ClearNumericallyIndexedTable(storedMessages)
					isQueued = false
				end)
		end
	end
end

--AvA messages
local function HookAvAMessages()
    if not ZO_CenterScreenAnnounce_GetEventHandlers then
        return
    end
    local handlers = ZO_CenterScreenAnnounce_GetEventHandlers()
    if type(handlers) ~= "table" then
        return
    end
	local avaEvents = {
		EVENT_ARTIFACT_CONTROL_STATE,
		EVENT_KEEP_GATE_STATE_CHANGED,
		EVENT_CORONATE_EMPEROR_NOTIFICATION,
		EVENT_DEPOSE_EMPEROR_NOTIFICATION,
		EVENT_IMPERIAL_CITY_ACCESS_GAINED_NOTIFICATION,
		EVENT_IMPERIAL_CITY_ACCESS_LOST_NOTIFICATION,
	}
	local function HookAvAEventHandler(event)
		local original = handlers[event]
			if type(original) ~= "function" then
				return
			end
		handlers[event] = function(...)
			if IsPlayerInAvAWorld() then
				return original(...)
			else
				if SV.ava == 1 then
					local messageParams = original(...)
					if messageParams then
						SafePrint(messageParams.mainText)
					end
				elseif SV.ava == 2 then
					return
				else
					return original(...)
				end
			end
		end
	end
	for i = 1, #avaEvents do
		HookAvAEventHandler(avaEvents[i])
	end
end

--Group Zone messages
local function HookGroupZoneMessages()
    if not ZO_CenterScreenAnnounce_GetEventHandlers then
        return
    end
    local handlers = ZO_CenterScreenAnnounce_GetEventHandlers()
    if type(handlers) ~= "table" then
        return
    end
	local groupEvents = {
		EVENT_DISPLAY_ANNOUNCEMENT,
	}
	-- We only want to hide those specific announcement or will remove a lot more.
	local groupValues =
	{
		GetString(NOTY_ENTERING_GROUP_AREA),
		GetString(NOTY_LEAVING_GROUP_AREA),
	}
	local function HookGroupZoneEventHandler(event)
		local original = handlers[event]
			if type(original) ~= "function" then
				 return
			end
		handlers[event] = function(title, description, ...)
			for index, stringValue in pairs(groupValues) do
				if title == stringValue or description == stringValue then
					if SV.groupZone == 1 then
						SafePrint(stringValue)
						return
					elseif SV.groupZone == 2 then
						return
					else
						return original(title, description, ...)
					end
				end
			end
			return original(title, description, ...)
		end
	end
	for i = 1, #groupEvents do
		HookGroupZoneEventHandler(groupEvents[i])
	end
end

local function HookFriendsMessages()
	if not ZO_PreHook or not CHAT_ROUTER or EVENT_FRIEND_PLAYER_STATUS_CHANGED == nil then
		return
	end

	ZO_PreHook(CHAT_ROUTER, "FormatAndAddChatMessage", function(_, eventType)
		if eventType == EVENT_FRIEND_PLAYER_STATUS_CHANGED and SV.friends then
			return true
		end
	end)
end

local function BossAlertTextsHook()
	if not ZO_AlertText_GetHandlers or not ZO_PreHook or EVENT_ABILITY_REQUIREMENTS_FAIL == nil or EVENT_COMBAT_EVENT == nil or ACTION_RESULT_MISSING_EMPTY_SOUL_GEM == nil or ACTION_RESULT_IMMUNE == nil then
		return
	end
	local handlers = ZO_AlertText_GetHandlers()
	if not handlers then
		return
	end
	local abilityErrorIds = {
		[162] = true, -- "Flying creatures are immune to snares."
		[177] = true, -- "This target is too powerful for that effect."
	}
	local function OnAbilityRequirementFailHook(errorStringId)
		if SV.boss then
			return abilityErrorIds[errorStringId]
		end
	end
	ZO_PreHook(handlers, EVENT_ABILITY_REQUIREMENTS_FAIL, OnAbilityRequirementFailHook)

	local actionResults = {
		[ACTION_RESULT_MISSING_EMPTY_SOUL_GEM] = true, -- "You must have a valid empty soul gem."
		[ACTION_RESULT_IMMUNE] = true, -- "Target is immune."
	}
	local function CombatEventHook(result, isError, ...)
		if isError and SV.boss then
			return actionResults[result]
		end
	end
	ZO_PreHook(handlers, EVENT_COMBAT_EVENT, CombatEventHook)
end

local function NoLootWindowOnItems()
	if not EVENT_MANAGER or EVENT_LOOT_UPDATED == nil or not SYSTEMS or not SYSTEMS.GetObject or not LOOT_SHARED or not LOOT_SHARED.LootAllItems or not GetLootTargetInfo or not GetSetting then
		return
	end
    local lootSystem = SYSTEMS:GetObject("loot")
    if not lootSystem or not lootSystem.UpdateLootWindow then
        return
    end
	-- When LOOT_SETTING_AUTO_LOOT is on, the C++ LootAll() is called, all is handled by C++ side, and EVENT_CLOSE_LOOT is sent.
	-- All we can do is to use the LootAll() Lua function
	local function LootAllItems()
		local name, targetType, actionName, isOwned = GetLootTargetInfo()
		if name ~= "" then
			if targetType == INTERACT_TARGET_TYPE_ITEM then
				name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
			elseif targetType == INTERACT_TARGET_TYPE_OBJECT then
				name = zo_strformat(SI_LOOT_OBJECT_NAME, name)
			elseif targetType == INTERACT_TARGET_TYPE_FIXTURE then
				name = zo_strformat(SI_TOOLTIP_FIXTURE_INSTANCE, name)
			end
		end
		if SV.autoLootItems then
			if not (targetType == INTERACT_TARGET_TYPE_ITEM and (isOwned == false and GetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT) == "1") or (isOwned and GetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT_STOLEN) == "1")) then
				lootSystem:UpdateLootWindow(name, actionName, isOwned)
			else
				LOOT_SHARED:LootAllItems()
			end
		else
			lootSystem:UpdateLootWindow(name, actionName, isOwned)
		end
	end
	EVENT_MANAGER:UnregisterForEvent("LOOT_SHARED", EVENT_LOOT_UPDATED)
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_LOOT_UPDATED, LootAllItems)
end

local function ScreenshotAlertHook()
	if not ZO_AlertText_GetHandlers or not ZO_PreHook or EVENT_SCREENSHOT_SAVED == nil then
		return
	end
	local handlers = ZO_AlertText_GetHandlers()
	if not handlers then
		return
	end
	local function EventHook()
	 return SV.screenshot
	end

	ZO_PreHook(handlers, EVENT_SCREENSHOT_SAVED, EventHook)
end

local function EnlightenedAlertHook()
	if not ZO_CenterScreenAnnounce_GetEventHandlers or not ZO_PreHook or EVENT_PLAYER_ACTIVATED == nil then
	   return
	end
	local handlers = ZO_CenterScreenAnnounce_GetEventHandlers()
	if not handlers then
	    return
	end
	 local function EventHook()
	    return SV.enlightened
	end
	ZO_PreHook(handlers, EVENT_PLAYER_ACTIVATED, EventHook)
end

local function CraftingResultAlertsHook()
	if not ZO_AlertText_GetHandlers or not ZO_PreHook or not ZO_AlertNoSuppression or EVENT_CRAFT_FAILED == nil or SI_TRADESKILLRESULT119 == nil or SI_SMITHING_EXTRACTION_FAILED == nil or SI_SMITHING_DECONSTRUCTION_LEVEL_PENALTY == nil or SI_ALCHEMY_NO_YIELD == nil or SI_ENCHANT_NO_YIELD == nil then
		return
	end
	local handlers = ZO_AlertText_GetHandlers()
	if not handlers then
		return
	end
	local blockedMessages = {
		--[SI_SMITHING_BLACKSMITH_EXTRACTION_FAILED] = true,
		[SI_TRADESKILLRESULT119] = true,
		[SI_SMITHING_EXTRACTION_FAILED] = true,
		[SI_SMITHING_DECONSTRUCTION_LEVEL_PENALTY] = true,
		[SI_ALCHEMY_NO_YIELD] = true,
		[SI_ENCHANT_NO_YIELD] = true,
	}
	local function ZO_AlertNoSuppression_Hook(category, soundId, message)
		if SV.craftingResults then
			return blockedMessages[message]
		end
	end
	ZO_PreHook("ZO_AlertNoSuppression", ZO_AlertNoSuppression_Hook)
	local function CraftFailedHook(tradeskillResult)
		return SV.craftingResults
	end
	ZO_PreHook(handlers, EVENT_CRAFT_FAILED, CraftFailedHook)
end

local function RepairAlertsHook()
	if ZO_GamepadStoreManager and ZO_GamepadStoreManager.RepairMessageBox then
		local function RepairMessageBox_Hook(...)
			return SV.repair
		end

		ZO_PreHook(ZO_GamepadStoreManager, "RepairMessageBox", RepairMessageBox_Hook)
	end
end

local function AlertTextThrottling()
	if not ZO_RecentMessages or not ZO_RecentMessages.New or not ZO_PreHook or not ZO_Alert or not ZO_SoundAlert then
		return
	end

	recentMessages = ZO_RecentMessages:New(SV.alertTextExpiryDelay * 1000)

	if not recentMessages or not recentMessages.ShouldDisplayMessage then
		return
	end

	local function ZO_Alert_Hook(category, soundId, message)
		if message and message ~= "" then
			return not recentMessages:ShouldDisplayMessage(message)
		end
		return true
	end
	ZO_PreHook("ZO_Alert", ZO_Alert_Hook)

	local function ZO_SoundAlert_Hook(category, soundId)
		if soundId and soundId ~= "" then
			return not recentMessages:ShouldDisplayMessage(soundId)
		end
		return true
	end
	ZO_PreHook("ZO_SoundAlert", ZO_SoundAlert_Hook)
end

local function DeleteEmptyMailHook()
	local function ShowDialog_Hook(name, data)
		if name ~= "DELETE_MAIL" or not SV.emptyMail then
			return
		end
		data.confirmationCallback()
		return true
	end
	ZO_PreHook("ZO_Dialogs_ShowDialog", ShowDialog_Hook)
end

local function NoUniversalStones()

	if not EVENT_MANAGER or EVENT_CRAFTING_STATION_INTERACT == nil or not GetCurrentSmithingStyleItemCount or not ZO_ADJUSTED_UNIVERSAL_STYLE_ITEM_INDEX or not ZO_SmithingTopLevelCreationPanelStyleListUniversalStyleItem or not ZO_SmithingTopLevelCreationPanelStyleListUniversalStyleItem.SetHidden then
		return
	end

	local function DisableUniversalCheckbox(_, craftSkill)
		if craftSkill == CRAFTING_TYPE_BLACKSMITHING
		or craftSkill == CRAFTING_TYPE_CLOTHIER
		or craftSkill == CRAFTING_TYPE_WOODWORKING then
			if GetCurrentSmithingStyleItemCount(ZO_ADJUSTED_UNIVERSAL_STYLE_ITEM_INDEX) == 0 then
				ZO_SmithingTopLevelCreationPanelStyleListUniversalStyleItem:SetHidden(true)
			else
				ZO_SmithingTopLevelCreationPanelStyleListUniversalStyleItem:SetHidden(false)
			end
		end
	end

	if SV.noUniversalStones then
		EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_CRAFTING_STATION_INTERACT, DisableUniversalCheckbox)
	else
		EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_CRAFTING_STATION_INTERACT)
		ZO_SmithingTopLevelCreationPanelStyleListUniversalStyleItem:SetHidden(false)
	end

end

local function GetGuildIndexFromId(guildId)
	if not GetNumGuilds or not GetGuildId then
		return nil
	end

	for index = 1, GetNumGuilds() do
		if GetGuildId(index) == guildId then
			return index
		end
	end

	return nil
end

local function NoGuildLeave()
    if not GUILD_HOME or not GUILD_HOME.keybindStripDescriptor or not GUILD_HOME.keybindStripDescriptor[1] then
        return
    end

    local leaveGuildKeybind = GUILD_HOME.keybindStripDescriptor[1]

    if SV.noGuildLeave == 1 then
        leaveGuildKeybind.visible = function() return false end

	elseif SV.noGuildLeave == 2 and GUILD_HOME.guildId then
		leaveGuildKeybind.visible = function()
			local guildIndex = GetGuildIndexFromId(GUILD_HOME.guildId)
			return not guildIndex or not SV.guildLeave[guildIndex]
		end
	else
        leaveGuildKeybind.visible = function() return true end
    end
end

local function NoGuildLeavePreHook()
    if ZO_PreHook and GUILD_HOME and GUILD_HOME.RefreshAll then
        ZO_PreHook(GUILD_HOME, "RefreshAll", NoGuildLeave)
    end
end

local function GuildRosterAlertsHook()
        local guildRosterManager = ZO_GuildRosterManager or GUILD_ROSTER

	if not guildRosterManager or not ZO_PreHook or not GetNumGuilds or not GetGuildId then
		return
	end

	local function GetGuildIndex(guildId)
		for index = 1, GetNumGuilds() do
			if GetGuildId(index) == guildId then
				return index
			end
		end
		return 0
	end

	local function OnGuildMemberAdded_Hook(self, guildId, displayName)
		if not self  or not self.RefreshData  or not self.FindDataByDisplayName then
			return
		end
		if SV.guildAlerts == 1 then
			local index = GetGuildIndex(guildId)
			if SV.guildAlertsGuilds[index] then
				self:RefreshData()
				if DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_INVITE) then
					local data = self:FindDataByDisplayName(displayName)
					if data then
						local _, rawCharacterName = GetGuildMemberCharacterInfo(guildId, data.index)
						SafePrint(zo_strformat(SI_GUILD_ROSTER_ADDED, rawCharacterName, self.guildName))
					end
				end
				return true
			end
		elseif SV.guildAlerts == 2 then
			local index = GetGuildIndex(guildId)
			if SV.guildAlertsGuilds[index] then
				self:RefreshData()
				return true
			end
		end
	end
	if guildRosterManager.OnGuildMemberAdded then
		ZO_PreHook( guildRosterManager, "OnGuildMemberAdded", OnGuildMemberAdded_Hook )
	end
	local function OnGuildMemberRemoved_Hook(self, guildId, rawCharacterName)
		if not self or not self.RefreshData then
			return
		end
		if SV.guildAlerts == 1 then
			local index = GetGuildIndex(guildId)
			if SV.guildAlertsGuilds[index] then
				if DoesPlayerHaveGuildPermission(guildId, GUILD_PERMISSION_INVITE) then
					SafePrint(zo_strformat(SI_GUILD_ROSTER_REMOVED, rawCharacterName, self.guildName))
				end
				self:RefreshData()
				return true
			end
		elseif SV.guildAlerts == 2 then
			local index = GetGuildIndex(guildId)
			if SV.guildAlertsGuilds[index] then
				self:RefreshData()
				return true
			end
		end
	end
	if guildRosterManager.OnGuildMemberRemoved then
		ZO_PreHook(guildRosterManager, "OnGuildMemberRemoved", OnGuildMemberRemoved_Hook)
	end
end

--raid notifications
local function HookRaidNotifications()
	if not ZO_PreHook or not ZO_ClearNumericallyIndexedTable or not GetSetting_Bool then
		return
	end
	local function BuildNotificationList_Hook(self)
		if not self or type(self.list) ~= "table" or not self.Decline or not self.CreateMessage then
			return
		end
		ZO_ClearNumericallyIndexedTable(self.list)
		if GetSetting_Bool(SETTING_TYPE_UI, UI_SETTING_SHOW_LEADERBOARD_NOTIFICATIONS) then
			local function BuildMessageAndRemoveNotification(contacts, message, notificationId)
				local membersListShorten = ""
				local nbContacts = #contacts
				if nbContacts > 4 then
					local shortOthers = zo_strformat(GetString(NOTY_RAID_OTHERS), ZO_SELECTED_TEXT:Colorize((nbContacts - 2)))
					membersListShorten = zo_strformat(" (<<1>>, <<2>> <<3>>)", ZO_SELECTED_TEXT:Colorize(contacts[1]), ZO_SELECTED_TEXT:Colorize(contacts[2]), shortOthers)
				else
					local myContacts = ""
					for _, contactName in ipairs(contacts) do
						myContacts = myContacts .. ZO_SELECTED_TEXT:Colorize(contactName) .. ", "
					end
					membersListShorten = zo_strformat(" (<<1>>)", myContacts:sub(1, -3))
				end
				message = string.gsub(message, GetString(NOTY_RAID_COMPLETE), zo_strformat("<<1>><<2>> ",  membersListShorten, GetString(NOTY_RAID_COMPLETE)))
				SafePrint(message)

				RemoveLeaderboardScoreNotification(notificationId)
			end

			if SV.raid == 0 and SV.raidToChat then
				local notificationId = GetNextLeaderboardScoreNotificationId()
				while notificationId do
					local contentType, contentId, _, score, _, numMembers = GetLeaderboardScoreNotificationInfo(notificationId)
					local numKnownMembers = 0
					local hasFriend = false
					local hasGuildMember = false
					local hasPlayer = false
					local contacts = {}

					for memberIndex = 1, numMembers do
						local displayName, _, isFriend, isGuildMember, isPlayer = GetLeaderboardScoreNotificationMemberInfo(notificationId, memberIndex)
						hasFriend = hasFriend or isFriend
						hasGuildMember = hasGuildMember or isGuildMember
						hasPlayer = hasPlayer or isPlayer
		
						if hasPlayer then
							-- We're going to decline anyway, see comment below
							break
						elseif isFriend or isGuildMember then
							table.insert(contacts, displayName)
							numKnownMembers = numKnownMembers + 1
						end
					end

					if hasPlayer then
						-- Player just received a notification about themselves, so filter it out
						self:Decline({ notificationId = notificationId, })
					elseif hasFriend or hasGuildMember then
						local contentName
						if contentType == LEADERBOARD_SCORE_NOTIFICATION_TYPE_RAID then
							contentName = GetRaidName(contentId)
							local message = self:CreateMessage(contentName, score, numKnownMembers, hasFriend, hasGuildMember)
							BuildMessageAndRemoveNotification(contacts, message, notificationId)
						elseif SV.endless then
							-- LEADERBOARD_SCORE_NOTIFICATION_TYPE_ENDLESS_DUNGEON
							-- Since leaderboards only really assume 1 Endless Dungeon for now, we can just use the same name we use for the header there
							contentName = GetString(SI_ENDLESS_DUNGEON_LEADERBOARDS_CATEGORIES_HEADER)
							local message = self:CreateMessage(contentName, score, numKnownMembers, hasFriend, hasGuildMember)
							BuildMessageAndRemoveNotification(contacts, message, notificationId)
						else
							RemoveLeaderboardScoreNotification(notificationId)
						end
					end
					notificationId = GetNextLeaderboardScoreNotificationId(notificationId)
				end
			elseif SV.raid == 1 then
				local notificationId = GetNextLeaderboardScoreNotificationId()
				while notificationId do
					RemoveLeaderboardScoreNotification(notificationId) 
					notificationId = GetNextLeaderboardScoreNotificationId(notificationId)
				end
			end
		end
	end
	if ZO_LeaderboardScoreProvider and ZO_LeaderboardScoreProvider.BuildNotificationList then
	    ZO_PreHook(ZO_LeaderboardScoreProvider, "BuildNotificationList", BuildNotificationList_Hook)
	end
end

--Guild MotD notifications
local function HookMotDNotifications()
	if not ZO_PreHook or not ZO_ClearNumericallyIndexedTable or not GetNumGuilds or not GetGuildId or not GetGuildName or not GetGuildMotD then
		return
	end
	local function BuildNotificationList_Hook(self)
		if not self or type(self.sv) ~= "table" or type(self.list) ~= "table" then
			return
		end
		if self.sv then
			if SV.motd == 1 then
				ZO_ClearNumericallyIndexedTable(self.list)
				for i = 1, GetNumGuilds() do
					local guildId = GetGuildId(i)
					local guildName = GetGuildName(guildId)
					local savedMotD = self.sv[guildName]
					local currentMotD = GetGuildMotD(guildId)
					if savedMotD ~= currentMotD then
						local guildAlliance = GetGuildAlliance(guildId)
						local allianceIcon = zo_iconFormat(GetAllianceBannerIcon(guildAlliance), 24, 24)
						local message = zo_strformat("<<X:1>> |cFFFFFF<<2>>|r\n<<3>>", allianceIcon, guildName, currentMotD)
						SafePrint(message)
					end
					self.sv[guildName] = currentMotD
				end
				return true
			elseif SV.motd == 2 then
				ZO_ClearNumericallyIndexedTable(self.list)
				for i = 1, GetNumGuilds() do
					local guildId = GetGuildId(i)
					local guildName = GetGuildName(guildId)
					self.sv[guildName] = GetGuildMotD(guildId)
				end
				return true
			end
		end
	end
	if ZO_GuildMotDProvider and ZO_GuildMotDProvider.BuildNotificationList then
	    ZO_PreHook(ZO_GuildMotDProvider, "BuildNotificationList", BuildNotificationList_Hook)
	end
end

--CraftBagNotifications notifications
local function HookCraftBagNotifications()
	local function BuildNotificationList_Hook(self)
		if not self or type(self.list) ~= "table" then
			return
		end
		if SV.craftBag then
			ZO_ClearNumericallyIndexedTable(self.list)
			return true
		end
	end
	if ZO_CraftBagAutoTransferProvider and ZO_CraftBagAutoTransferProvider.BuildNotificationList then
	    ZO_PreHook(ZO_CraftBagAutoTransferProvider, "BuildNotificationList", BuildNotificationList_Hook)
	end
end

--Reticle Hook
local function HookReticleTake()
	if not RETICLE or not RETICLE.TryHandlingInteraction or not ZO_PreHook or not GetGameCameraInteractableActionInfo or ADDITIONAL_INTERACT_INFO_EMPTY == nil then
		return
	end
	local function DisableReticleTake_Hook(interactionPossible)
		if interactionPossible then
			if SV.reticleTake or SV.emptyInteractions then
				local action, interactableName, interactionBlocked, _, additionalInteractInfo = GetGameCameraInteractableActionInfo()
				if action and interactableName then
					if (action == GetString(NOTY_INTERACTION_TAKE)) then
						if SV.reticleTake then
							if (interactableName == GetString(NOTY_INSECT_BUTTERFLY)
							or interactableName == GetString(NOTY_INSECT_TORCHBUG)
							or interactableName == GetString(NOTY_INSECT_WASP)
							or interactableName == GetString(NOTY_INSECT_FLESHFLIES)
							or interactableName == GetString(NOTY_INSECT_DRAGONFLY)
							or interactableName == GetString(NOTY_INSECT_NETCHCALF)
							or interactableName == GetString(NOTY_INSECT_FETCHERFLY)
							or interactableName == GetString(NOTY_INSECT_DOVAH))
							then
								return true
							end
						end
					elseif SV.emptyInteractions and interactionBlocked then

						local dontShow = {
							[ADDITIONAL_INTERACT_INFO_EMPTY] = true
						}

						if dontShow[additionalInteractInfo] then
							return true
						end

					end
				end
			end
		end
		return false
	end
	if RETICLE and RETICLE.TryHandlingInteraction then
	    ZO_PreHook(RETICLE, "TryHandlingInteraction", DisableReticleTake_Hook)
	end
end

--Guild invite notifications
local function HookGuildInvitesNotifications()
	local function BuildNotificationList_Hook(self)
		if not self or type(self.list) ~= "table" or not self.CreateMessage then
			return
		end
		ZO_ClearNumericallyIndexedTable(self.list)
		if SV.guildInvites == 0 or (SV.guildInvites == 2 and GetNumGuilds() < MAX_GUILDS) then
			for i = 1, GetNumGuildInvites() do
				local guildId, guildName, guildAlliance, inviterDisplayName, note = GetGuildInviteInfo(i)
				local secsSinceRequest = 0
				local formattedInviterName = ZO_FormatUserFacingDisplayName(inviterDisplayName)
				local message = self:CreateMessage(guildAlliance, guildName, formattedInviterName)
				self.list[i] =  {
					dataType = NOTIFICATIONS_REQUEST_DATA,
					guildId = guildId,
					guildAlliance = guildAlliance,
					guildName = guildName,
					displayName = inviterDisplayName,
					notificationType = NOTIFICATION_TYPE_GUILD,
					secsSinceRequest = ZO_NormalizeSecondsSince(secsSinceRequest),
					note = note,
					message = message,
					shortDisplayText = formattedInviterName,
					controlsOwnSounds = true,
				}
			end
		end
		return true
	end
	if ZO_GuildInviteProvider and ZO_GuildInviteProvider.BuildNotificationList then
	    ZO_PreHook(ZO_GuildInviteProvider, "BuildNotificationList", BuildNotificationList_Hook)
	end
end

local function HookPlayerToPlayerGuildInvite()
	if not PLAYER_TO_PLAYER or not PLAYER_TO_PLAYER.control or not PLAYER_TO_PLAYER.control.RegisterForEvent or not PLAYER_TO_PLAYER.control.UnregisterForEvent or not PLAYER_TO_PLAYER.AddPromptToIncomingQueue or not PLAYER_TO_PLAYER.RemoveFromIncomingQueue or EVENT_GUILD_INVITE_ADDED == nil then
	    return
	end
	local INTERACT_TYPE_GUILD_INVITE = 7
	PLAYER_TO_PLAYER.control:UnregisterForEvent(EVENT_GUILD_INVITE_ADDED)
	PLAYER_TO_PLAYER.control:RegisterForEvent(EVENT_GUILD_INVITE_ADDED, function (eventCode, guildId, guildName, guildAlliance, inviterName, ...)
		if SV.guildInvites == 0 or (SV.guildInvites == 2 and GetNumGuilds() < MAX_GUILDS) then
			local allianceIconSize = 24
			if IsInGamepadPreferredMode() then
				allianceIconSize = 36
			end
			local formattedInviterName = ZO_FormatUserFacingDisplayName(inviterName)
			local guildNameAlliance = zo_iconTextFormat(GetAllianceBannerIcon(guildAlliance), allianceIconSize, allianceIconSize, ZO_SELECTED_TEXT:Colorize(guildName))
			local data = PLAYER_TO_PLAYER:AddPromptToIncomingQueue(INTERACT_TYPE_GUILD_INVITE, nil, formattedInviterName, zo_strformat(SI_PLAYER_TO_PLAYER_INCOMING_GUILD_REQUEST, ZO_SELECTED_TEXT:Colorize(formattedInviterName), guildNameAlliance),
				function()
					AcceptGuildInvite(guildId)
				end,
				function()
					RejectGuildInvite(guildId)
				end,
				function()
					PLAYER_TO_PLAYER:RemoveFromIncomingQueue(INTERACT_TYPE_GUILD_INVITE, formattedInviterName)
				end)
			if data then
			    data.guildId = guildId
			end
		end
	end)
end

--New Guild Applications notifications
local function HookGuildNewApplicationsNotifications()
    local function BuildNotificationList_Hook(self)
	if not self or type(self.list) ~= "table" then
            return
        end
        if SV.guildApps then
            ZO_ClearNumericallyIndexedTable(self.list)
            return true
        end
    end
	if ZO_GuildNewApplicationsProvider and ZO_GuildNewApplicationsProvider.BuildNotificationList then
	    ZO_PreHook(ZO_GuildNewApplicationsProvider, "BuildNotificationList", BuildNotificationList_Hook)
	end
end

-- Aya: Don't interrupt on mailScenes anymore due to RequestOpenMailbox() - sec issue I guess
local function DontInterruptHarvesting()
	 if not END_IN_WORLD_INTERACTIONS_FRAGMENT or not END_IN_WORLD_INTERACTIONS_FRAGMENT.Show or not END_IN_WORLD_INTERACTIONS_FRAGMENT.OnShown or not EndPendingInteraction then
	     return
	end
	local function Show_Hook(self)
		if SV.nonstopHarvest then
			EndPendingInteraction()
			self:OnShown()
			return true
		end
	end
	ZO_PreHook(END_IN_WORLD_INTERACTIONS_FRAGMENT, "Show", Show_Hook)
end

local function DontReadBooks()
	if not LORE_READER or not LORE_READER.control or not LORE_READER.control.RegisterForEvent or not LORE_READER.control.UnregisterForEvent or not LORE_READER.Show or not GetLoreBookOverrideImageFromBookId or not PlaySound or not EndInteraction or EVENT_SHOW_BOOK == nil or INTERACTION_BOOK == nil then
		return
	end
	local function OnShowBook(eventCode, title, body, medium, showTitle, bookId)
		local overrideImage, overrideImageTitlePosition = GetLoreBookOverrideImageFromBookId(bookId)
		LORE_READER:Show(title, body, medium, showTitle, overrideImage, overrideImageTitlePosition)
		PlaySound(LORE_READER.OpenSound)
	end
	local function OnDontShowBook()
		EndInteraction(INTERACTION_BOOK)
	end
	if SV.dontReadBooks then
		LORE_READER.control:UnregisterForEvent(EVENT_SHOW_BOOK)
		LORE_READER.control:RegisterForEvent(EVENT_SHOW_BOOK, OnDontShowBook)
	else
		LORE_READER.control:UnregisterForEvent(EVENT_SHOW_BOOK)
		LORE_READER.control:RegisterForEvent(EVENT_SHOW_BOOK, OnShowBook)
	end
end

local function DontShowLoreDiscoveries()
	if not ZO_CenterScreenAnnounce_GetEventHandlers then
		return
	end
	local handlers = ZO_CenterScreenAnnounce_GetEventHandlers()
	if type(handlers) ~= "table" then
		return
	end
	local loreEvents = {
		EVENT_LORE_BOOK_ALREADY_KNOWN,
		EVENT_LORE_BOOK_LEARNED,
		EVENT_LORE_BOOK_LEARNED_SKILL_EXPERIENCE,
		EVENT_LORE_COLLECTION_COMPLETED,
		EVENT_LORE_COLLECTION_COMPLETED_SKILL_EXPERIENCE,
	}
	local function HookLoreLibraryEventHandler(event)
		local original = handlers[event]
		if type(original) ~= "function" then
			return
		end
		handlers[event] = function(...)
			if SV.dontShowLoreDiscoveries == 1 then
				local messageParams = original(...)
				if messageParams then
					SafePrint(messageParams.mainText)
				end
				return
			elseif SV.dontShowLoreDiscoveries == 2 then
				return
			else
				return original(...)
			end
		end
	end
	for i = 1, #loreEvents do
		HookLoreLibraryEventHandler(loreEvents[i])
	end
end

local function DontShowSkillProgression()
	if not ZO_CenterScreenAnnounce_GetEventHandlers then
		return
	end
	local handlers = ZO_CenterScreenAnnounce_GetEventHandlers()
	if type(handlers) ~= "table" then
		return
	end
	local skillEvents = {
		EVENT_ABILITY_PROGRESSION_RANK_UPDATE,
	}
	local function HookSkillProgressionEventHandler(event)
		local original = handlers[event]
		if type(original) ~= "function" then
			return
		end
		handlers[event] = function(progressionIndex, ...)
			local _, _, _, atMorph = GetAbilityProgressionXPInfo(progressionIndex)
			if not atMorph then
				if SV.dontShowSkillProgression == 1 then
					local messageParams = original(progressionIndex, ...)
					if messageParams then
						SafePrint(messageParams.mainText)
					end
					return
				elseif SV.dontShowSkillProgression == 2 then
					return
				else
					return original(progressionIndex, ...)
				end
			end
			return original(progressionIndex, ...)
		end
	end
	for i = 1, #skillEvents do
		HookSkillProgressionEventHandler(skillEvents[i])
	end
end

local scenes = {}
local function DontRotateGameCamera(doOverrideNoCameraSpin)
	if not SCENE_MANAGER or type(SCENE_MANAGER.scenes) ~= "table" then
		return
	end
	doOverrideNoCameraSpin = doOverrideNoCameraSpin or false
	local emotesFragments = {
		FRAME_PLAYER_FRAGMENT,
		FRAME_EMOTE_FRAGMENT_INVENTORY,
		FRAME_EMOTE_FRAGMENT_SKILLS,
		FRAME_EMOTE_FRAGMENT_JOURNAL,
		FRAME_EMOTE_FRAGMENT_MAP,
		FRAME_EMOTE_FRAGMENT_SOCIAL,
		FRAME_EMOTE_FRAGMENT_AVA,
		FRAME_EMOTE_FRAGMENT_SYSTEM,
		FRAME_EMOTE_FRAGMENT_LOOT,
		FRAME_EMOTE_FRAGMENT_CHAMPION,
	}
	local blacklistedScenes = {
		market = true, 
		gameMenuInGame = true,
		VeterancySceneKeyboard = true,
		TamrielTomesSceneKeyboard = true,
		TamrielTomesPurchaseSceneKeyboard = true,
		endeavorSealStoreSceneKeyboard = true,
		gildbarStoreSceneKeyboard = true,
		crownCrateGamepad = true,
		crownCrateKeyboard = true,
		keyboard_housing_furniture_scene = true,
		gamepad_housing_furniture_scene = true,
		dyeStampConfirmationGamepad = true,
		dyeStampConfirmationKeyboard = true,
		outfitStylesBook = true,
		stats = false,
		inventory = false,
	}

	local function ChangeScenesBehavior(disableFragments)
		for name, scene in pairs(scenes) do
			if scene.toRestore then
				for index, fragment in ipairs(scene.toRestore) do
					scene:AddFragment(fragment)
				end
			end
		end
		scenes = {}
		if disableFragments then
			if SV.noCameraSpin then
				blacklistedScenes["stats"]     = not SV.noCameraSpinStats
				blacklistedScenes["inventory"] = not SV.noCameraSpinInv
			end
			for name, scene in pairs(SCENE_MANAGER.scenes) do
				if not blacklistedScenes[name] then
					local sceneToSave = true
					for _, fragmentToRemove in ipairs(emotesFragments) do
						if scene:HasFragment(fragmentToRemove) then
							scene:RemoveFragment(fragmentToRemove)
							if sceneToSave then
								sceneToSave = false
								scenes[name] = scene
								scenes[name].toRestore = {}
							end
							table.insert(scenes[name].toRestore, fragmentToRemove)
						end
					end
				end
			end
		end
	end
	local doDisableFragments = doOverrideNoCameraSpin or SV.noCameraSpin
	ChangeScenesBehavior(doDisableFragments)
end

local chatScene
local function DisableChatMinimize()
	local fragmentToRemove = MINIMIZE_CHAT_FRAGMENT
	local scene = TRADING_HOUSE_SCENE
	if not fragmentToRemove or not scene or not scene.HasFragment or not scene.RemoveFragment or not scene.AddFragment then
		return
	end
	if SV.chatForTradingHouse then
		local sceneToSave = true
		if scene:HasFragment(fragmentToRemove) then
			scene:RemoveFragment(fragmentToRemove)
			if sceneToSave then
				sceneToSave = false
				chatScene = scene
				chatScene.toRestore = true
			end
		end
	else
		if chatScene and chatScene.toRestore then
			chatScene:AddFragment(fragmentToRemove)
		end
	end
end

local function HookFenceDialog()
	if not ZO_Dialogs_ShowDialog or not ZO_PreHook or not SellInventoryItem then
		return
	end
	local function ShowDialog_Hook(name, data)
		if name == "CANT_BUYBACK_FROM_FENCE" then
			if SV.fenceDialog then
			    if not data or data.bag == nil or data.slot == nil or data.stackCount == nil or not SellInventoryItem then
				return
			    end

			    SellInventoryItem(data.bag, data.slot, data.stackCount)
			    return true
			end
		end
	end
	ZO_PreHook("ZO_Dialogs_ShowDialog", ShowDialog_Hook)
end

local function HookPlaySound()
	if not SOUNDS or not PlaySound or not ZO_PreHook or not IsUnitInCombat then
		return
	end
	local function PlaySound_Hook(soundId)
		if (soundId == SOUNDS.ABILITY_ULTIMATE_READY) then
			if SV.ultimateSound == 1 then
				return (not IsUnitInCombat("player"))
			elseif SV.ultimateSound == 2 then
				return IsUnitInCombat("player")
			elseif SV.ultimateSound == 3 then
				return true
			end
		 elseif (soundId == SOUNDS.NEW_NOTIFICATION) then
		 	if SV.notificationSound == false then
		 		return true
		 	else
		 		return false
	 		end
		end
	end
	ZO_PreHook("PlaySound", PlaySound_Hook)
end

local function HookDisbandDialog()
	if not GroupDisband or not ZO_Dialogs_ShowDialog or not ZO_PreHook then
		return
	end
	local function ShowDialog_Hook(name, data)
		if name == "GROUP_DISBAND_DIALOG" then
			if SV.disbandDialog then
				GroupDisband()
				return true
			end
		end
	end
	ZO_PreHook("ZO_Dialogs_ShowDialog", ShowDialog_Hook)
end

local function HookLargeGroupDialog()
	if not ZO_Dialogs_ShowDialog or not ZO_PreHook or not ZO_Menu_SetLastCommandWasFromMenu or not ZO_Alert or not ZO_FormatUserFacingDisplayName or not ZO_AlertText_GetHandlers or EVENT_GROUP_TYPE_CHANGED == nil then
		return
	end
	local function ShowDialog_Hook(name, data)
		if name == "LARGE_GROUP_INVITE_WARNING" then
			if SV.largeGroupDialog then
				local characterOrDisplayName = data

				if type(characterOrDisplayName) ~= "string" or characterOrDisplayName == "" or not GroupInviteByName then
					return
				end
				GroupInviteByName(characterOrDisplayName)
				ZO_Menu_SetLastCommandWasFromMenu(true)
				ZO_Alert(ALERT, nil, zo_strformat(GetString("SI_GROUPINVITERESPONSE", GROUP_INVITE_RESPONSE_INVITED), ZO_FormatUserFacingDisplayName(characterOrDisplayName)))
				return true
			end
		end
	end
	ZO_PreHook("ZO_Dialogs_ShowDialog", ShowDialog_Hook)
	local handlers = ZO_AlertText_GetHandlers()
	if not handlers or not handlers[EVENT_GROUP_TYPE_CHANGED] then
		return
	end
	local function GroupTypeChanged_Hook()
		return SV.largeGroupDialog
	end
	ZO_PreHook(
		handlers,
		EVENT_GROUP_TYPE_CHANGED,
		GroupTypeChanged_Hook
	)
end

local function HookImproveDialog()
	if not ZO_Dialogs_ShowDialog or not ZO_PreHook or not ImproveSmithingItem then
		return
	end
	local function ShowDialog_Hook(name, data)
		if name == "CONFIRM_IMPROVE_ITEM" or name == "CONFIRM_IMPROVE_LOCKED_ITEM" or name == "GAMEPAD_CONFIRM_IMPROVE_LOCKED_ITEM" then
			if SV.improveDialog then
			    if not data or data.bagId == nil or data.slotIndex == nil or data.boostersToApply == nil or not ImproveSmithingItem then
				return
			    end
			    ImproveSmithingItem(data.bagId, data.slotIndex, data.boostersToApply)
			    return true
			end
		end
	end
	ZO_PreHook("ZO_Dialogs_ShowDialog", ShowDialog_Hook)
end

local function HookMarketAnnouncement()
    if not SCENE_MANAGER or not SCENE_MANAGER.scenes or not SCENE_MANAGER.ShowBaseScene then
        return
    end
    local marketAnnouncementScene = SCENE_MANAGER.scenes.marketAnnouncement
    if not marketAnnouncementScene or not marketAnnouncementScene.SetState then
        return
    end
    local function SetState_Hook(self, state, ...)
        if state == SCENE_SHOWN then
            if SV.marketAnnouncement then
                SCENE_MANAGER:ShowBaseScene()
            end
            return SV.marketAnnouncement
        end
    end
    ZO_PreHook(marketAnnouncementScene, "SetState", SetState_Hook)
end

local function DoDisableChatAutoComplete()
    if not SlashCommandAutoComplete or not SlashCommandAutoComplete.GetAutoCompletionResults then
        return
    end
    local function GetAutoCompletionResults_Hook()
        return SV.disableChatAutoComplete
    end
    ZO_PreHook(SlashCommandAutoComplete, "GetAutoCompletionResults", GetAutoCompletionResults_Hook)
end

local function OnPlayerActivated_DisableChatAutoComplete()
	EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED)
	DoDisableChatAutoComplete()
end

local function DisableChatAutoComplete()
	EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_ACTIVATED, OnPlayerActivated_DisableChatAutoComplete)
end

local function HookAcceptOfferedQuest(fromLAM)
	if not INTERACTION or type(INTERACTION.eventCallbacks) ~= "table" or not INTERACTION.control or not INTERACTION.control.RegisterForEvent or not INTERACTION.control.UnregisterForEvent or not INTERACTION.control.AddFilterForEvent then
		return
	end
	local original = INTERACTION.eventCallbacks[EVENT_QUEST_OFFERED]
	if type(original) ~= "function" then
		return
	end
	local masterWritReceived
	local function OnQuestOffered(...)
		if masterWritReceived then
			masterWritReceived = false
		else
			original(...)
		end
	end
	local function OnLootReceived(_,_, itemLink)
		if GetItemLinkItemType(itemLink) == ITEMTYPE_MASTER_WRIT then
			masterWritReceived = true
		end
	end
	if SV.dontAcceptWritQuest then
		INTERACTION.control:RegisterForEvent(EVENT_LOOT_RECEIVED, OnLootReceived)
		INTERACTION.control:AddFilterForEvent(EVENT_LOOT_RECEIVED, REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
		INTERACTION.control:AddFilterForEvent(EVENT_LOOT_RECEIVED, REGISTER_FILTER_UNIT_TAG, "player")
		INTERACTION.control:UnregisterForEvent(EVENT_QUEST_OFFERED)
		INTERACTION.control:RegisterForEvent(EVENT_QUEST_OFFERED, OnQuestOffered)
	elseif fromLAM then
		INTERACTION.control:UnregisterForEvent(EVENT_QUEST_OFFERED)
		INTERACTION.control:UnregisterForEvent(EVENT_LOOT_RECEIVED)
		INTERACTION.control:RegisterForEvent(EVENT_QUEST_OFFERED, original)
	end
end

local function HookReportItemFromInventory()
    if not ZO_InventorySlotActions or not ZO_InventorySlotActions.AddSlotAction then
        return
    end
    local function AddSlotActionHook(self, actionStringId)
        if SV.noReportOnItems  and actionStringId == SI_ITEM_ACTION_REPORT_ITEM then
            return true
        end
    end
    ZO_PreHook(ZO_InventorySlotActions, "AddSlotAction",  AddSlotActionHook)
end

local NOTY_currentBagId
local NOTY_currentSlotId
local function HookBindAlerts()
	if not EVENT_MANAGER or EVENT_INVENTORY_SLOT_LOCKED == nil or not ZO_Dialogs_ShowDialog or not ZO_PreHook then
		return
	end
	local function TryEquipItem()
		if SV.noBindAlert and NOTY_currentBagId ~= nil and NOTY_currentSlotId ~= nil and IsEquipable and EquipItem then
			local equipable = IsEquipable(NOTY_currentBagId, NOTY_currentSlotId)
			if equipable then
				EquipItem(NOTY_currentBagId, NOTY_currentSlotId)
				return true
			end
		end
	end
	local function OnInventorySlotLocked(eventCode, bagId, slotId)
		if SV.noBindAlert then
			NOTY_currentBagId = bagId
			NOTY_currentSlotId = slotId
		end
	end
	EVENT_MANAGER:RegisterForEvent("INVENTORY_SLOT_LOCKED", EVENT_INVENTORY_SLOT_LOCKED, OnInventorySlotLocked)
	local function ShowDialog_Hook(name, data)
		if name == "CONFIRM_EQUIP_ITEM" then
			if SV.noBindAlert then
			    local callback = data and data.onAcceptCallback

			    if type(callback) == "function" then
				local status = pcall(callback)

				if status then
				    return true
				end
			    end

			    if TryEquipItem() then
				return true
			    end
			end
		end
	end
	ZO_PreHook("ZO_Dialogs_ShowDialog", ShowDialog_Hook)
end

local function NoPortToLeader()	
	if not PLAYER_TO_PLAYER or not PLAYER_TO_PLAYER.AddPromptToIncomingQueue or type(PLAYER_TO_PLAYER.incomingQueue) ~= "table" or not SecurePostHook or not ZO_Dialogs_ReleaseAllDialogsOfName then
	    return
	end
	local INTERACT_TYPE_TRAVEL_TO_LEADER = 19
	local cannotJump = {
		[181] = true, -- Cyrodiil
		[584] = true, -- Imperial City
		[643] = true, -- Imperial Sewers
	}
	local function removeFromIncomingQueue(incomingType)
	    local incomingQueue = PLAYER_TO_PLAYER.incomingQueue
	    for i = #incomingQueue, 1, -1 do
		local incomingEntry = incomingQueue[i]
		if incomingEntry and incomingEntry.incomingType == incomingType then
		    table.remove(incomingQueue, i)
		end
	    end
	    ZO_Dialogs_ReleaseAllDialogsOfName("PTP_TIMED_RESPONSE_PROMPT")
	end
	SecurePostHook(PLAYER_TO_PLAYER, 'AddPromptToIncomingQueue', function(self, incomingType) 
		if incomingType == INTERACT_TYPE_TRAVEL_TO_LEADER then
			if SV.noPortOnLeader == 1 then
				local groupLeaderUnitTag = GetGroupLeaderUnitTag()
				local groupLeaderZoneIndex = GetUnitZoneIndex(groupLeaderUnitTag)
				local groupLeaderZoneId = GetZoneId(groupLeaderZoneIndex)
				if cannotJump[groupLeaderZoneId] then
					removeFromIncomingQueue(incomingType)
				end
			elseif SV.noPortOnLeader == 2 then
				removeFromIncomingQueue(incomingType)
			end
		end
	end)
end

local function HandleLuaErrorEvent()
	if not EVENT_LUA_ERROR then
	    return
	end
	if SV.luaError == 1 then
	    if not LibNotifications or not LibNotifications.CreateProvider or not ZO_ERROR_FRAME or not ZO_ERROR_FRAME.OnUIError then
		return
	    end
	end
	if SV.luaError >= 1 then
		local provider
		if SV.luaError == 1 then
			provider = LibNotifications:CreateProvider()

			if not provider or type(provider.notifications) ~= "table" or not provider.UpdateNotifications then
				return
			end
		end

		--unregister original handler
		EVENT_MANAGER:UnregisterForEvent("ErrorFrame", EVENT_LUA_ERROR)
		local seenBugs = {}

		--create a new event handler
		local function OnLuaError(_, errString)

			-- Display a notification
			if SV.luaError == 1 then
				local function RemoveNotification(data)
				    if not data or type(data.notificationId) ~= "number" then
					return
				    end
				    if data.notificationId < 1 or data.notificationId > #provider.notifications then
					return
				    end
				    table.remove(provider.notifications, data.notificationId)
				    provider:UpdateNotifications()
				end
				if not seenBugs[errString] then
					local msg = {
						dataType				= NOTIFICATIONS_REQUEST_DATA,
						secsSinceRequest			= ZO_NormalizeSecondsSince(0),
						message					= GetString(NOTYOU_LUAERR_MESSAGE),
						note					= errString,
						heading					= GetString(NOTYOU_LUAERR_HEADING),
						texture					= "/esoui/art/miscellaneous/eso_icon_warning.dds",
						shortDisplayText			= GetString(NOTYOU_LUAERR_SHORT),
						controlsOwnSounds			= true,
						keyboardAcceptCallback	= function(data)
							ZO_ERROR_FRAME:OnUIError(errString)
							RemoveNotification(data)
						end,
						keybaordDeclineCallback	= RemoveNotification,
						gamepadAcceptCallback	= function(data)
							ZO_ERROR_FRAME:OnUIError(errString)
							RemoveNotification(data)
						end,
						gamepadDeclineCallback	= RemoveNotification,
						data					= {errString = errString},
					}
					table.insert(provider.notifications, msg)
					provider:UpdateNotifications()
					seenBugs[errString] = true
				end
			elseif SV.luaError == 2 then
				if not seenBugs[errString] then
					d(errString)
					seenBugs[errString] = true
				end
			end
		end
		EVENT_MANAGER:RegisterForEvent("LUA_ERROR", EVENT_LUA_ERROR, OnLuaError)
	end
end

local function BuildSettingsMenu()

	local panelData = {
		type = "panel",
		name = "No, thank you!",
		author = ADDON_AUTHOR,
		version = ADDON_VERSION,
		slashCommand = "/noty",
		registerForRefresh = true,
		registerForDefaults = true,
		website = ADDON_WEBSITE,
	}

	local guildInvites = { GetString(NOTY_GUILD_INV_OPTION_0), GetString(NOTY_GUILD_INV_OPTION_1), GetString(NOTY_GUILD_INV_OPTION_2) }
	local guildInvitesLookup = { [GetString(NOTY_GUILD_INV_OPTION_0)] = 0, [GetString(NOTY_GUILD_INV_OPTION_1)] = 1, [GetString(NOTY_GUILD_INV_OPTION_2)] = 2 }

	local avaMode = { GetString(NOTY_AVA_MODE_OPTION_0), GetString(NOTY_AVA_MODE_OPTION_1), GetString(NOTY_AVA_MODE_OPTION_2) }
	local avaModeLookup = { [GetString(NOTY_AVA_MODE_OPTION_0)] = 0, [GetString(NOTY_AVA_MODE_OPTION_1)] = 1, [GetString(NOTY_AVA_MODE_OPTION_2)] = 2 }

	local loreLibraryMode = { GetString(NOTY_AVA_MODE_OPTION_0), GetString(NOTY_AVA_MODE_OPTION_1), GetString(NOTY_AVA_MODE_OPTION_2) }
	local loreLibraryModeLookup = { [GetString(NOTY_AVA_MODE_OPTION_0)] = 0, [GetString(NOTY_AVA_MODE_OPTION_1)] = 1, [GetString(NOTY_AVA_MODE_OPTION_2)] = 2 }

	local skillsProgressionMode = { GetString(NOTY_AVA_MODE_OPTION_0), GetString(NOTY_AVA_MODE_OPTION_1), GetString(NOTY_AVA_MODE_OPTION_2) }
	local skillsProgressionModeLookup = { [GetString(NOTY_AVA_MODE_OPTION_0)] = 0, [GetString(NOTY_AVA_MODE_OPTION_1)] = 1, [GetString(NOTY_AVA_MODE_OPTION_2)] = 2 }

	local groupZoneMode = { GetString(NOTY_AVA_MODE_OPTION_0), GetString(NOTY_AVA_MODE_OPTION_1), GetString(NOTY_AVA_MODE_OPTION_2) }

	local soundMode = { GetString(NOTY_SOUND_MODE_OPTION_0), GetString(NOTY_SOUND_MODE_OPTION_1), GetString(NOTY_SOUND_MODE_OPTION_2), GetString(NOTY_SOUND_MODE_OPTION_3) }
	local soundModeLookup = { [GetString(NOTY_SOUND_MODE_OPTION_0)] = 0, [GetString(NOTY_SOUND_MODE_OPTION_1)] = 1, [GetString(NOTY_SOUND_MODE_OPTION_2)] = 2, [GetString(NOTY_SOUND_MODE_OPTION_3)] = 3 }

	local guildAlertsMode = { GetString(NOTY_GALERTS_OPTION_0), GetString(NOTY_GALERTS_OPTION_1), GetString(NOTY_GALERTS_OPTION_2) }
	local guildAlertsModeLookup = { [GetString(NOTY_GALERTS_OPTION_0)] = 0, [GetString(NOTY_GALERTS_OPTION_1)] = 1, [GetString(NOTY_GALERTS_OPTION_2)] = 2 }

	local raidMode = { GetString(NOTY_RAID_OPTION_0), GetString(NOTY_RAID_OPTION_1)}
	local raidModeLookup = { [GetString(NOTY_RAID_OPTION_0)] = 0, [GetString(NOTY_RAID_OPTION_1)] = 1 }

	local motdMode = { GetString(NOTY_MOTD_OPTION_0), GetString(NOTY_MOTD_OPTION_1), GetString(NOTY_MOTD_OPTION_2) }
	local motdModeLookup = { [GetString(NOTY_MOTD_OPTION_0)] = 0, [GetString(NOTY_MOTD_OPTION_1)] = 1, [GetString(NOTY_MOTD_OPTION_2)] = 2 }

	local guildLeaveMode = { GetString(NOTY_GUILDLEAVE_OPTION_0), GetString(NOTY_GUILDLEAVE_OPTION_1), GetString(NOTY_GUILDLEAVE_OPTION_2) }
	local guildLeaveModeLookup = { [GetString(NOTY_GUILDLEAVE_OPTION_0)] = 0, [GetString(NOTY_GUILDLEAVE_OPTION_1)] = 1, [GetString(NOTY_GUILDLEAVE_OPTION_2)] = 2 }

	local luaError = { GetString(NOTY_LUAERR_OPTION_0), GetString(NOTY_LUAERR_OPTION_1), GetString(NOTY_LUAERR_OPTION_2) }
	local luaErrorLookup = { [GetString(NOTY_LUAERR_OPTION_0)] = 0, [GetString(NOTY_LUAERR_OPTION_1)] = 1, [GetString(NOTY_LUAERR_OPTION_2)] = 2 }

	local noPortOnLeader = { GetString(NOTY_NOPORTONLEADER_0), GetString(NOTY_NOPORTONLEADER_1), GetString(NOTY_NOPORTONLEADER_2) }
	local noPortOnLeaderLookup = { [GetString(NOTY_NOPORTONLEADER_0)] = 0, [GetString(NOTY_NOPORTONLEADER_1)] = 1, [GetString(NOTY_NOPORTONLEADER_2)] = 2 }

	local optionsData = {
		---[[ AvA Messages ]]---
		{
			type = "header",
			name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(NOTYOU_AVA_HEADER)),
		},
		{
			type = "dropdown",
			name = GetString(NOTYOU_AVA),
			tooltip = GetString(NOTYOU_AVA_TOOLTIP),
			choices = avaMode,
			getFunc = function() return avaMode[SV.ava + 1] end,
			setFunc = function(value) SV.ava = avaModeLookup[value] end,
			default = avaMode[defaults.ava + 1],
		},
		---[[ Group Zone Messages ]]---
		{
			type = "header",
			name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(NOTYOU_GROUPZONE_HEADER)),
		},
		{
			type = "dropdown",
			name = GetString(NOTYOU_GROUPZONE),
			tooltip = GetString(NOTYOU_GROUPZONE_TOOLTIP),
			choices = groupZoneMode,
			getFunc = function() return groupZoneMode[SV.groupZone + 1] end,
			setFunc = function(value) SV.groupZone = avaModeLookup[value] end,
			default = groupZoneMode[defaults.groupZone + 1],
		},
		---[[ Friends Status Messages ]]---
		{
			type = "header",
			name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(NOTYOU_FRIENDS_HEADER)),
		},
		{
			type = "checkbox",
			name = GetString(NOTYOU_FRIENDS_ACTIVITY),
			tooltip = GetString(NOTYOU_FRIENDS_ACTIVITY_TOOLTIP),
			getFunc = function() return SV.friends end,
			setFunc = function(value) SV.friends = value end,
			default = defaults.friends,
		},
		{
			type = "header",
			name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(NOTYOU_TEXT_ALERTS_HEADER)),
		},
		---[[ Ability alerts ]]---
		{
			type = "checkbox",
			name = GetString(NOTYOU_MOB_IMMUNE),
			tooltip = GetString(NOTYOU_MOB_IMMUNE_TOOLTIP),
			getFunc = function() return SV.boss end,
			setFunc = function(value) SV.boss = value end,
			default = defaults.boss,
		},
		---[[ Screenshot Saved alert ]]---
		{
			type = "checkbox",
			name = GetString(NOTYOU_SCREENSHOT),
			tooltip = GetString(NOTYOU_SCREENSHOT_TOOLTIP),
			getFunc = function() return SV.screenshot end,
			setFunc = function(value) SV.screenshot = value end,
			default = defaults.screenshot,
		},
		---[[ Enlightened alert ]]---
		{
			type = "checkbox",
			name = GetString(NOTYOU_ENLIGHTENED),
			tooltip = GetString(NOTYOU_ENLIGHTENED_TOOLTIP),
			getFunc = function() return SV.enlightened end,
			setFunc = function(value) SV.enlightened = value end,
			default = defaults.enlightened,
			disabled = function() return not IsEnlightenedAvailableForCharacter() end,
		},
		---[[ Crafting Result alerts ]]---
		{
			type = "checkbox",
			name = GetString(NOTYOU_CRAFTRESULT),
			tooltip = GetString(NOTYOU_CRAFTRESULT_TOOLTIP),
			getFunc = function() return SV.craftingResults end,
			setFunc = function(value) SV.craftingResults = value end,
			default = defaults.craftingResults,
		},
		---[[ Repair alerts ]]---
		{
			type = "checkbox",
			name = GetString(NOTYOU_REPAIR),
			tooltip = GetString(NOTYOU_REPAIR_TOOLTIP),
			getFunc = function() return SV.repair end,
			setFunc = function(value) SV.repair = value end,
			default = defaults.repair,
			disabled = function() return ZO_GamepadStoreManager == nil end,
		},
		---[[ AlertText throttling ]]---
		{
			type = "slider",
			name = GetString(NOTYOU_ALERT_THROTTLING),
			tooltip = GetString(NOTYOU_ALERT_THROTTLING_TOOLTIP),
			min = 3,
			max = 30,
			getFunc = function() return SV.alertTextExpiryDelay end,
			setFunc = function(value)
				SV.alertTextExpiryDelay = value
				recentMessages.expiryDelayMilliseconds = value * 1000
			end,
			default = defaults.alertTextExpiryDelay,
		},
		{
			type = "header",
			name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(NOTYOU_SOUND_HEADER)),
		},
		{
			type = "dropdown",
			name = GetString(NOTYOU_ULTISOUND),
			tooltip = GetString(NOTYOU_ULTISOUND_TOOLTIP),
			choices = soundMode,
			getFunc = function() return soundMode[SV.ultimateSound + 1] end,
			setFunc = function(value) SV.ultimateSound = soundModeLookup[value] end,
			default = soundMode[defaults.ultimateSound + 1],
		},
		---[[ Hide market announcement ]]---
		{
			type = "header",
			name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(SI_GAMEPAD_MAIN_MENU_CROWN_STORE_CATEGORY)),
		},
		{
			type = "checkbox",
			name = GetString(NOTYOU_MARKET_ADS),
			tooltip = GetString(NOTYOU_MARKET_ADS_TOOLTIP),
			getFunc = function() return SV.marketAnnouncement end,
			setFunc = function(value) SV.marketAnnouncement = value end,
			default = defaults.marketAnnouncement,
			disabled = function() return SCENE_MANAGER.scenes.marketAnnouncement == nil end,
		},
		---[[ Confirmation dialog when deleting empty mails ]]---
		{
			type = "header",
			name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(NOTYOU_MAIL_HEADER)),
		},
		{
			type = "checkbox",
			name = GetString(NOTYOU_MAIL),
			tooltip = GetString(NOTYOU_MAIL_TOOLTIP),
			getFunc = function() return SV.emptyMail end,
			setFunc = function(value) SV.emptyMail = value end,
			default = defaults.emptyMail,
		},
		---[[ Confirmation dialog when selling rare items to fence ]]---
		{
			type = "header",
			name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(NOTYOU_FENCE_HEADER)),
		},
		{
			type = "checkbox",
			name = GetString(NOTYOU_FENCE),
			tooltip = GetString(NOTYOU_FENCE_TOOLTIP),
			getFunc = function() return SV.fenceDialog end,
			setFunc = function(value) SV.fenceDialog = value end,
			default = defaults.fenceDialog,
		},
		---[[ Confirmation dialog when disband group and setting large group ]]---
		{
			type = "header",
			name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(NOTYOU_GROUPS_HEADER)),
		},
		{
			type = "checkbox",
			name = GetString(NOTYOU_GROUPS_DISBAND),
			tooltip = GetString(NOTYOU_GROUPS_DISBAND_TOOLTIP),
			getFunc = function() return SV.disbandDialog end,
			setFunc = function(value) SV.disbandDialog = value end,
			default = defaults.disbandDialog,
		},
		{
			type = "checkbox",
			name = GetString(NOTYOU_GROUPS_LARGE),
			tooltip = GetString(NOTYOU_GROUPS_LARGE_TOOLTIP),
			getFunc = function() return SV.largeGroupDialog end,
			setFunc = function(value) SV.largeGroupDialog = value end,
			default = defaults.largeGroupDialog,
		},
		{
			type = "dropdown",
			name = GetString(NOTYOU_NOPORTONLEADER),
			tooltip = GetString(NOTYOU_NOPORTONLEADER_TOOLTIP),
			choices = noPortOnLeader,
			getFunc = function() return noPortOnLeader[SV.noPortOnLeader + 1] end,
			setFunc = function(value) SV.noPortOnLeader = noPortOnLeaderLookup[value] end,
			default = noPortOnLeader[defaults.noPortOnLeader + 1],
		},
		---[[ Confirmation dialog when crafting ]]---
		{
			type = "header",
			name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(NOTYOU_CRAFT_HEADER)),
		},
		{
			type = "checkbox",
			name = GetString(NOTYOU_CRAFT),
			tooltip = GetString(NOTYOU_CRAFT_TOOLTIP),
			getFunc = function() return SV.improveDialog end,
			setFunc = function(value) SV.improveDialog = value end,
			default = defaults.improveDialog,
		},
		---[[ Chameleon checkbox ]]---
		{
			type = "header",
			name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(NOTYOU_CHAMELEON_HEADER)),
		},
		{
			type = "checkbox",
			name = GetString(NOTYOU_CHAMELEON),
			tooltip = GetString(NOTYOU_CHAMELEON_TOOLTIP),
			getFunc = function() return SV.noUniversalStones end,
			setFunc = function(value)
				SV.noUniversalStones = value
				NoUniversalStones()
			end,
			default = defaults.noUniversalStones,
		},
		---[[ Reticle options ]]---
		{
			type = "header",
			name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(NOTYOU_RETICLE_HEADER)),
		},
		{
			type = "checkbox",
			name = GetString(NOTYOU_RETICLE_TAKE),
			tooltip = GetString(NOTYOU_RETICLE_TAKE_TOOLTIP),
			getFunc = function() return SV.reticleTake end,
			setFunc = function(value) SV.reticleTake = value end,
			default = defaults.reticleTake,
		},
		{
			type = "checkbox",
			name = GetString(NOTYOU_EMPTY_INTERACT),
			tooltip = GetString(NOTYOU_EMPTY_INTERACT_TOOLTIP),
			getFunc = function() return SV.emptyInteractions end,
			setFunc = function(value) SV.emptyInteractions = value end,
			default = defaults.emptyInteractions,
		},
		---[[ Auto Loot Items ]]---
		{
			type = "header",
			name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(NOTYOU_AUTOLOOTITEMS_HEADER)),
		},
		{
			type = "checkbox",
			name = GetString(NOTYOU_AUTOLOOTITEMS),
			tooltip = GetString(NOTYOU_AUTOLOOTITEMS_TOOLTIP),
			getFunc = function() return SV.autoLootItems end,
			setFunc = function(value)
				SV.autoLootItems = value
				NoLootWindowOnItems()
			end,
			default = defaults.autoLootItems,
		},
		---[[ Guild Invites ]]---
		{
			type = "header",
			name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(NOTYOU_GUILDS_HEADER)),
		},
		{
			type = "dropdown",
			name = GetString(NOTYOU_GUILDS),
			tooltip = GetString(NOTYOU_GUILDS_TOOLTIP),
			choices = guildInvites,
			getFunc = function() return guildInvites[SV.guildInvites + 1] end,
			setFunc = function(value) SV.guildInvites = guildInvitesLookup[value] end,
			default = guildInvites[defaults.guildInvites + 1],
		},
		{
			type = "checkbox",
			name = GetString(NOTYOU_GUILDSAPP),
			tooltip = GetString(NOTYOU_GUILDSAPP_TOOLTIP),
			getFunc = function() return SV.guildApps end,
			setFunc = function(value)
				SV.guildApps = value
			end,
			default = defaults.guildApps,
		},
		{
			type = "header",
			name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(NOTYOU_CAMERA_HEADER)),
		},
		{
			type = "checkbox",
			name = GetString(NOTYOU_CAMERA_INTERRUPT),
			tooltip = GetString(NOTYOU_CAMERA_INTERRUPT_TOOLTIP),
			getFunc = function() return SV.nonstopHarvest end,
			setFunc = function(value) SV.nonstopHarvest = value end,
			default = defaults.nonstopHarvest,
		},
		{
			type = "checkbox",
			name = GetString(NOTYOU_CAMERA_ROTATE),
			tooltip = GetString(NOTYOU_CAMERA_ROTATE_TOOLTIP),
			getFunc = function() return SV.noCameraSpin end,
			setFunc = function(value)
				SV.noCameraSpin = value
				DontRotateGameCamera()
			end,
			default = defaults.noCameraSpin,
		},
		{
			type = "checkbox",
			name = GetString(NOTYOU_CAMERA_ROTATE_STATS),
			tooltip = GetString(NOTYOU_CAMERA_ROTATE_STATS_TOOLTIP),
			getFunc = function() return SV.noCameraSpinStats end,
			setFunc = function(value)
				SV.noCameraSpinStats = value
				DontRotateGameCamera()
			end,
			default = defaults.noCameraSpinStats,
			disabled = function() return SV.noCameraSpin == false end,
		},
		{
			type = "checkbox",
			name = GetString(NOTYOU_CAMERA_ROTATE_INV),
			tooltip = GetString(NOTYOU_CAMERA_ROTATE_INV_TOOLTIP),
			getFunc = function() return SV.noCameraSpinInv end,
			setFunc = function(value)
				SV.noCameraSpinInv = value
				DontRotateGameCamera()
			end,
			default = defaults.noCameraSpinInv,
			disabled = function() return SV.noCameraSpin == false end,
		},
		---[[ Lore Library ]]---
		{
			type = "header",
			name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(SI_WINDOW_TITLE_LORE_LIBRARY)),
		},
		{
			type = "checkbox",
			name = GetString(NOTYOU_NOLOREREADER),
			tooltip = GetString(NOTYOU_NOLOREREADER_TOOLTIP),
			getFunc = function() return SV.dontReadBooks end,
			setFunc = function(value)
				SV.dontReadBooks = value
				DontReadBooks()
			end,
			default = defaults.dontReadBooks,
		},
		{
			type = "dropdown",
			name = GetString(NOTYOU_NOLOREDISCOVERIES),
			tooltip = GetString(NOTYOU_NOLOREDISCOVERIES_TOOLTIP),
			choices = loreLibraryMode,
			getFunc = function() return loreLibraryMode[SV.dontShowLoreDiscoveries + 1] end,
			setFunc = function(value) SV.dontShowLoreDiscoveries = loreLibraryModeLookup[value] end,
			default = loreLibraryMode[defaults.dontShowLoreDiscoveries + 1],
		},
		-- Crafting Bag
		{
			type = "header",
			name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(SI_NOTIFICATIONTYPE15)),
		},
		{
			type = "checkbox",
			name = GetString(NOTYOU_NOCRAFTBAG_NOTIF),
			tooltip = GetString(NOTYOU_NOCRAFTBAG_NOTIF_TOOLTIP),
			getFunc = function() return SV.craftBag end,
			setFunc = function(value)
				SV.craftBag = value
				HookCraftBagNotifications()
			end,
			default = defaults.craftBag,
		},
		---[[ Skills ]]---
		{
			type = "header",
			name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(SI_WINDOW_TITLE_SKILLS)),
		},
		{
			type = "dropdown",
			name = GetString(NOTYOU_NOSKILLSPROGRESS),
			tooltip = GetString(NOTYOU_NOSKILLSPROGRESS_TOOLTIP),
			choices = skillsProgressionMode,
			getFunc = function() return skillsProgressionMode[SV.dontShowSkillProgression + 1] end,
			setFunc = function(value) SV.dontShowSkillProgression = skillsProgressionModeLookup[value] end,
			default = skillsProgressionMode[defaults.dontShowSkillProgression + 1],
		},
		---[[ Inventory ]]---
		{
			type = "header",
			name = ZO_HIGHLIGHT_TEXT:Colorize(zo_strformat(GetString(SI_MAIN_MENU_INVENTORY))),
		},
		{
			type = "checkbox",
			name = GetString(NOTYOU_NOREPORTONITEMS),
			tooltip = GetString(NOTYOU_NOREPORTONITEMS_TOOLTIP),
			getFunc = function() return SV.noReportOnItems end,
			setFunc = function(value) SV.noReportOnItems = value end,
			default = defaults.noReportOnItems,
		},
		{
			type = "checkbox",
			name = GetString(NOTYOU_NOBINDALERT),
			tooltip = GetString(NOTYOU_NOBINDALERT_TOOLTIP),
			getFunc = function() return SV.noBindAlert end,
			setFunc = function(value) SV.noBindAlert = value end,
			default = defaults.noBindAlert,
		},
		---[[ Quests ]]---
		{
			type = "header",
			name = ZO_HIGHLIGHT_TEXT:Colorize(zo_strformat(GetString(SI_JOURNAL_MENU_QUESTS))),
		},
		{
			type = "checkbox",
			name = GetString(NOTYOU_NOWRITQUESTS),
			tooltip = GetString(NOTYOU_NOWRITQUESTS_TOOLTIP),
			getFunc = function() return SV.dontAcceptWritQuest end,
			setFunc = function(value)
				SV.dontAcceptWritQuest = value
				HookAcceptOfferedQuest(true)
			end,
			default = defaults.dontAcceptWritQuest,
		},
		---[[ Chat ]]---
		{
			type = "header",
			name = ZO_HIGHLIGHT_TEXT:Colorize(zo_strformat(GetString(SI_CHAT_TAB_GENERAL))),
		},
		{
			type = "checkbox",
			name = GetString(NOTYOU_NOCHATAUTOCOMPLETE),
			tooltip = GetString(NOTYOU_NOCHATAUTOCOMPLETE_TOOLTIP),
			getFunc = function() return SV.disableChatAutoComplete end,
			setFunc = function(value)
				SV.disableChatAutoComplete = value
				DoDisableChatAutoComplete()
			end,
			default = defaults.disableChatAutoComplete,
		},
		{
			type = "checkbox",
			name = GetString(NOTYOU_NOCHATDISABLE),
			tooltip = GetString(NOTYOU_NOCHATDISABLE_TOOLTIP),
			getFunc = function() return SV.chatForTradingHouse end,
			setFunc = function(value)
				SV.chatForTradingHouse = value
				DisableChatMinimize()
			end,
			default = defaults.chatForTradingHouse,
		},

	}
	--Guild Alerts
	local submenuGuildAlerts = {
		type = "submenu",
		name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(NOTYOU_GROSTER_HEADER)),
		tooltip = GetString(NOTYOU_GROSTER_HEADER_TOOLTIP),
		controls = {
			{
				type = "dropdown",
				name = GetString(NOTYOU_GROSTER),
				tooltip = GetString(NOTYOU_GROSTER_TOOLTIP),
				choices = guildAlertsMode,
				getFunc = function() return guildAlertsMode[SV.guildAlerts + 1] end,
				setFunc = function(value) SV.guildAlerts = guildAlertsModeLookup[value] end,
				default = guildAlertsMode[defaults.guildAlerts + 1],
			},
			{
				type = "texture",
				image = "EsoUI/Art/Quest/questJournal_divider.dds",
				imageWidth = 510,
				imageHeight = 4,
			},
		},
	}
	--RaidScore Notifications
	local submenuRaidScore = {
		type = "submenu",
		name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(NOTYOU_RAIDSCORE_HEADER)),
		tooltip = GetString(NOTYOU_RAIDSCORE_HEADER_TOOLTIP),
		controls = {
			{
				type = "dropdown",
				name = GetString(NOTYOU_RAIDSCORE_ONLYFOR),
				tooltip = GetString(NOTYOU_RAIDSCORE_ONLYFOR_TOOLTIP),
				choices = raidMode,
				getFunc = function() return raidMode[SV.raid + 1] end,
				setFunc = function(value) SV.raid = raidModeLookup[value] end,
				default = raidMode[defaults.raid + 1],
			},
			{
				type = "checkbox",
				name = GetString(NOTYOU_RAIDSCORE_ENDLESS),
				getFunc = function() return SV.endless end,
				setFunc = function(value) SV.endless = value end,
				default = defaults.endless,
				disabled = function() return SV.raid == 1 end
			},
			{
				type = "checkbox",
				name = GetString(NOTYOU_RAIDSCORE_REDIRECT),
				getFunc = function() return SV.raidToChat end,
				setFunc = function(value) SV.raidToChat = value end,
				default = defaults.raidToChat,
				disabled = function() return SV.raid == 1 end
			},
			{
				type = "checkbox",
				name = GetString(NOTYOU_RAIDSCORE_SOUND),
				tooltip = GetString(NOTYOU_RAIDSCORE_SOUND_TOOLTIP),
				getFunc = function() return SV.notificationSound end,
				setFunc = function(value) SV.notificationSound = value end,
				default = defaults.notificationSound,
			},
		},
	}
	--Guild MotD Notifications
	local submenuGuildMotD = {
		type = "submenu",
		name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(NOTYOU_MOTD_HEADER)),
		tooltip = GetString(NOTYOU_MOTD_HEADER_TOOLTIP),
		controls = {
			{
				type = "dropdown",
				name = GetString(NOTYOU_MOTD_BLOCK),
				tooltip = GetString(NOTYOU_MOTD_BLOCK_TOOLTIP),
				choices = motdMode,
				getFunc = function() return motdMode[SV.motd + 1] end,
				setFunc = function(value) SV.motd = motdModeLookup[value] end,
				default = motdMode[defaults.motd + 1],
			},
			{
				type = "texture",
				image = "EsoUI/Art/Quest/questJournal_divider.dds",
				imageWidth = 510,
				imageHeight = 4,
			},
		},
	}
	-- NoGuildLeave Notifications
	local submenuGuildLeave = {
		type = "submenu",
		name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(NOTYOU_GUILDLEAVE_HEADER)),
		tooltip = GetString(NOTYOU_GUILDLEAVE_HEADER_TOOLTIP),
		controls = {
			{
				type = "dropdown",
				name = GetString(NOTYOU_GUILDLEAVE_BLOCK),
				tooltip = GetString(NOTYOU_GUILDLEAVE_BLOCK_TOOLTIP),
				choices = guildLeaveMode,
				getFunc = function() return guildLeaveMode[SV.noGuildLeave + 1] end,
				setFunc = function(value)
					SV.noGuildLeave = guildLeaveModeLookup[value]
					NoGuildLeave()
				end,
				default = guildLeaveMode[defaults.noGuildLeave + 1],
			},
			{
				type = "texture",
				image = "EsoUI/Art/Quest/questJournal_divider.dds",
				imageWidth = 510,
				imageHeight = 4,
			},
		},
	}
	for i = 1, MAX_GUILDS do
		local gname = GetGuildName(GetGuildId(i))
		--Guild Alerts
		local guildData = {
			type = "checkbox",
			name = (#gname > 0 and gname or "Guild " .. i),
			getFunc = function() return SV.guildAlertsGuilds[i] end,
			setFunc = function(value)
				SV.guildAlertsGuilds[i] = value
				NoGuildLeave()
			end,
			default = defaults.guildAlertsGuilds[i],
			disabled = function() return SV.guildAlerts == 0 end,
		}
		table.insert(submenuGuildAlerts.controls, guildData)

		--Guild MotD Notifications
		local motdData = {
			type = "checkbox",
			name = (#gname > 0 and gname or "Guild " .. i),
			getFunc = function() return SV.motdGuilds[i] end,
			setFunc = function(value)
					SV.motdGuilds[i] = value
					NOTIFICATIONS:RefreshNotificationList()
				end,
			default = defaults.motdGuilds[i],
			disabled = function() return SV.motd == 0 end,
		}
		table.insert(submenuGuildMotD.controls, motdData)

		--Guild Leave
		local guildLeave = {
			type = "checkbox",
			name = (#gname > 0 and gname or "Guild " .. i),
			getFunc = function() return SV.guildLeave[i] end,
			setFunc = function(value) SV.guildLeave[i] = value end,
			default = defaults.guildLeave[i],
			disabled = function() return SV.noGuildLeave ~= 2 end,
		}
		table.insert(submenuGuildLeave.controls, guildLeave)
	end

	--add submenus to the optionsData
	table.insert(optionsData, submenuGuildAlerts)
	table.insert(optionsData, submenuRaidScore)
	table.insert(optionsData, submenuGuildMotD)
	table.insert(optionsData, submenuGuildLeave)
	table.insert(optionsData, {
			type = "header",
			name = ZO_HIGHLIGHT_TEXT:Colorize(GetString(NOTYOU_LUA_HEADER)),
		})
	table.insert(optionsData, {
			type = "dropdown",
			name = GetString(NOTYOU_LUA_ERROR),
			tooltip = GetString(NOTYOU_LUA_ERROR_TOOLTIP),
			choices = luaError,
			getFunc = function() return luaError[SV.luaError + 1] end,
			setFunc = function(value)
				SV.luaError = luaErrorLookup[value]
				HandleLuaErrorEvent()
			end,
			default = luaError[defaults.luaError + 1],
		}
	)
	table.insert(optionsData, {
		type = "divider",
		width = "full", -- or "half" (optional)
		height = 70, -- (optional)
		alpha = 0.25, -- (optional)
	}
	)
	local panel = LibAddonMenu2:RegisterAddonPanel("NOTY_Panel", panelData)
	LibAddonMenu2:RegisterOptionControls("NOTY_Panel", optionsData)
	--add logo
	panel.logo = WINDOW_MANAGER:CreateControl(nil, panel, CT_TEXTURE)
	panel.logo:SetAnchor(TOP, panel, TOP, -5, 15)
	panel.logo:SetDimensions(420, 60)
	panel.logo:SetTexture("NoThankYou/Art/noty.dds")
	panel.logo:SetTextureCoords(0, 1, 0, 0.1429)
	panel.label:SetHeight(65)
	panel.label:SetHidden(true)
	panel.container:ClearAnchors()
	panel.container:SetAnchor(TOPLEFT, panel.info, BOTTOMLEFT, 0, 10)
	panel.container:SetAnchor(BOTTOMRIGHT, panel, BOTTOMRIGHT, -3, -3)
end

function NTY_ToggleRotateGameCamera()
	if SV.noCameraSpin then
		SV.noCameraSpin = false
	else
		SV.noCameraSpin = true
	end
	DontRotateGameCamera()
end

local function OnAddonLoaded(event, name)
	if name == ADDON_NAME then
		EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, event)
		SV = ZO_SavedVars:NewAccountWide("NO_THANK_YOU_VARS", 2, nil, defaults)
		--set hooks
		HookAvAMessages()
		HookGroupZoneMessages()
		HookFriendsMessages()
		BossAlertTextsHook()
		ScreenshotAlertHook()
		EnlightenedAlertHook()
		GuildRosterAlertsHook()
		CraftingResultAlertsHook()
		RepairAlertsHook()
		AlertTextThrottling()
		DeleteEmptyMailHook()
		HookRaidNotifications()
		HookMotDNotifications()
		HookCraftBagNotifications()
		HookReticleTake()
		HookGuildInvitesNotifications()
		HandleLuaErrorEvent()
		DontInterruptHarvesting()
		DontRotateGameCamera()
		HookFenceDialog()
		HookPlaySound()
		HookDisbandDialog()
		HookLargeGroupDialog()
		HookImproveDialog()
		HookMarketAnnouncement()
		HookPlayerToPlayerGuildInvite()
		DontReadBooks()
		DontShowLoreDiscoveries()
		DontShowSkillProgression()
		NoUniversalStones()
		NoGuildLeave()
		NoGuildLeavePreHook()
		NoLootWindowOnItems()
		HookReportItemFromInventory()
		DisableChatAutoComplete()
		DisableChatMinimize()
		HookBindAlerts()
		NoPortToLeader()
		HookGuildNewApplicationsNotifications()
		BuildSettingsMenu()
		--rebuild notifications list
		if NOTIFICATIONS and NOTIFICATIONS.RefreshNotificationList then
		    NOTIFICATIONS:RefreshNotificationList()
		end
	end
end

EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED, OnAddonLoaded)

-- Key Binding
ZO_CreateStringId("SI_BINDING_NAME_NOCAMROTATE_TOGGLE", "Toggle Camera Rotate")
