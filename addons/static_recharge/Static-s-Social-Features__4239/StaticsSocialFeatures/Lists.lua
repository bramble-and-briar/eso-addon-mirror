--[[------------------------------------------------------------------------------------------------
Title:          Lists
Author:         Static_Recharge
Description:    Controls the extended friends and ignored list features.
------------------------------------------------------------------------------------------------]]--


--[[------------------------------------------------------------------------------------------------
Libraries and Aliases
------------------------------------------------------------------------------------------------]]--
local EM = EVENT_MANAGER
local LCM = LibCustomMenu
local FL = FRIENDS_LIST
local FLM = FRIENDS_LIST_MANAGER
local ILM = IGNORE_LIST_MANAGER
local SSF = StaticsSocialFeatures


--[[------------------------------------------------------------------------------------------------
Defines
------------------------------------------------------------------------------------------------]]--
local FRIENDS_MAX = 100
local IGNORED_MAX = 100


--[[------------------------------------------------------------------------------------------------
Lists Class Initialization
Status    - Object containing all functions, tables, variables,and constants.
  |-  Parent    - Reference to parent object.
------------------------------------------------------------------------------------------------]]--
local Lists = {}


--[[------------------------------------------------------------------------------------------------
Lists.Initialize()
Inputs:				None  
Outputs:			None
Description:	Initializes all of the variables and tables.
------------------------------------------------------------------------------------------------]]--
function Lists.Initialize()
  Lists.eventSpace = "SSFLists"

  -- Update Icon from settings
	Lists.UpdateFavIcon()

  -- ZO Hooks
	Lists.FriendListHook()
	Lists.FriendEntryHook()
	Lists.FriendListSortHook()
	Lists.FriendKeybindStripHook()
	Lists.FriendListTooltipHook()
	Lists.GroupListTooltipHook()
  Lists.IgnoreMasterListHook()

  -- Register Context Menu
	Lists.FriendListContextMenu()

  -- Event Regristrations
  EM:RegisterForEvent(Lists.eventSpace, EVENT_IGNORE_ADDED, Lists.OnIgnoreAdded)

	Lists.initialized = true
end


--[[------------------------------------------------------------------------------------------------
Lists.IsInitialized()
Inputs:				None
Outputs:			initialized                         - bool for object initialized state
Description:	Returns true if the object has been successfully initialized.
------------------------------------------------------------------------------------------------]]--
function Lists.IsInitialized()
  return Lists.initialized
end


--[[------------------------------------------------------------------------------------------------
Lists.UpdateFavIcon()
Inputs:			  None
Outputs:			None
Description:	Updates the display of the fav icon.
------------------------------------------------------------------------------------------------]]--
function Lists.UpdateFavIcon()
	if SSF.SV.favIconInheritColor then
		SSF.favIcon = zo_strformat("|t<<1>>%:<<2>>%:<<3>>:inheritcolor|t", SSF.SV.favIconSize, SSF.SV.favIconSize, SSF.SV.favIconTexture)
	else
		SSF.favIcon = zo_strformat("|t<<1>>%:<<2>>%:<<3>>|t", SSF.SV.favIconSize, SSF.SV.favIconSize, SSF.SV.favIconTexture)
	end
	FLM:BuildMasterList()
	FL:RefreshFilters()
	SSF.Chat:Debug("Fav icon updated.")
end


--[[------------------------------------------------------------------------------------------------
Lists.FriendListHook()
Inputs:			  None
Outputs:			None
Description:	Hooks into the friends list manager to add Fav tag to all entries as required.
------------------------------------------------------------------------------------------------]]--
function Lists.FriendListHook()
	ZO_PostHook(FLM, 'BuildMasterList', function(self_)
		SSF.Chat:Debug("Friend List prehook started.")
		for i, friendData in ipairs(self_.masterList) do
			if SSF.SV.Favs[friendData.displayName] then
				friendData.favs = false -- ZO sort function sorts false entries before true ones
			else
				friendData.favs = true
			end
		end
	end)
end


--[[------------------------------------------------------------------------------------------------
Lists.FriendEntryHook()
Inputs:			  None
Outputs:			None
Description:	Hooks into the friends list manager to add the icon for Fav friends.
------------------------------------------------------------------------------------------------]]--
function Lists.FriendEntryHook()
	ZO_PostHook(FLM, 'SetupEntry', function(self_, control, data, selected)
		--SSF.Chat:Debug("Friend Listy Entry prehook started.")
		local displayNameLabel = control:GetNamedChild("DisplayName")
		if displayNameLabel then
			if SSF.SV.Favs[data.displayName] then
				displayNameLabel:SetText(zo_strformat("<<1>> <<2>>", SSF.favIcon, ZO_FormatUserFacingDisplayName(data.displayName)))
			end
		end
	end)
end


--[[------------------------------------------------------------------------------------------------
Lists.FriendListSortHook()
Inputs:			  None
Outputs:			None
Description:	Hooks into the friends list to sort Fav friends to the top.
------------------------------------------------------------------------------------------------]]--
function Lists.FriendListSortHook()
	ZO_PreHook(FL, 'SortScrollList', function(self_)
		SSF.Chat:Debug("Friend List Sort prehook started.")
		if self_.currentSortOrder == ZO_SORT_ORDER_UP then
			for i, friendData in ipairs(FLM.masterList) do
				if SSF.SV.Favs[friendData.displayName] then
					friendData.favs = false -- ZO sort function sorts false entries before true ones
				else
					friendData.favs = true
				end
			end
		else
			for i, friendData in ipairs(FLM.masterList) do
				if SSF.SV.Favs[friendData.displayName] then
					friendData.favs = true -- ZO sort function sorts false entries before true ones
				else
					friendData.favs = false
				end
			end
		end
		local prevSortKey = "status"
		if self_.currentSortKey ~= "favs" then
			prevSortKey = self_.currentSortKey
		end
		FRIENDS_LIST_ENTRY_SORT_KEYS["favs"] = {tiebreaker = prevSortKey}
		if SSF.SV.favFriendsTop then
			self_.currentSortKey = "favs"
		end
	end)
end


--[[------------------------------------------------------------------------------------------------
Lists.FriendKeybindStripHook()
Inputs:			  None
Outputs:			None
Description:	Hooks into the friends keybind strip to add the invite and whisper option for offline 
							favs as well as the add/remove fav friend button.
------------------------------------------------------------------------------------------------]]--
function Lists.FriendKeybindStripHook()
	ZO_PostHook(FL, 'InitializeKeybindDescriptors', function(self_)
		SSF.Chat:Debug("Friend Keybind Strip posthook started.")
		-- Group Invite
		self_.keybindStripDescriptor[2].visible = function()
			if IsGroupModificationAvailable() and self_.mouseOverRow then
				local data = ZO_ScrollList_GetData(self_.mouseOverRow)
				if data and data.hasCharacter and (data.online or (SSF.SV.Favs[data.displayName] and SSF.SV.groupInvite ~= SSF.AllFavNone.List.None) or SSF.SV.groupInvite == SSF.AllFavNone.List.All) then
					return true
				end
			end
			return false
		end
		-- Add/Remove Fav
		self_.keybindStripDescriptor[3] = {
			name = function()
				if self_.mouseOverRow then
					local data = ZO_ScrollList_GetData(self_.mouseOverRow)
					if SSF.SV.Favs[data.displayName] then
						return "Remove Fav"
					end
				end
				return "Add Fav"
			end,
			keybind = "UI_SHORTCUT_QUATERNARY",
			callback = function()
				if self_.mouseOverRow then
					local data = ZO_ScrollList_GetData(self_.mouseOverRow)
					if SSF.SV.Favs[data.displayName] then
						Lists.RemoveFavFriend(data.displayName)
					else
						Lists.AddFavFriend(data.displayName)
					end
				end
			end,
			visible = function()
				if self_.mouseOverRow then
					return true
				end
				return false
			end,
			--icon = SSF.SV.favIconTexture,
		}
	end)
end


--[[------------------------------------------------------------------------------------------------
Lists.FriendListTooltipHook()
Inputs:			  None
Outputs:			None
Description:	Hooks into the friends list to add mutual guilds to the tooltips.
------------------------------------------------------------------------------------------------]]--
function Lists.FriendListTooltipHook()
	ZO_PostHook(ZO_SocialListKeyboard, 'DisplayName_OnMouseEnter', function(self_, control)
		--Lists.Chat:Debug("Friend List Tooltip prehook started.")
		if SSF.SV.sharedGuilds == SSF.AllFavNone.List.None then return end
		local row = control:GetParent()
    local data = ZO_ScrollList_GetData(row)
		local guilds = {}
		for i=1, GetNumGuilds() do
			for j=1, GetGuildInfo(GetGuildId(i)) do
				local name = GetGuildMemberInfo(GetGuildId(i),j)
				if name == data.displayName and name ~= GetDisplayName() then
					table.insert(guilds, GetGuildName(GetGuildId(i)))
					break
				end
			end
		end
		guilds = table.concat(guilds, "\n")
		if data and data.hasCharacter and guilds ~= "" and (SSF.SV.sharedGuilds == SSF.AllFavNone.List.All or (SSF.SV.sharedGuilds == SSF.AllFavNone.List.Fav and  SSF.SV.Favs[data.displayName])) then
			SetTooltipText(InformationTooltip, guilds)
		end
	end)
end


--[[------------------------------------------------------------------------------------------------
Lists.GroupListTooltipHook()
Inputs:			  None
Outputs:			None
Description:	Hooks into the group list to sort Fav friends to the top.
------------------------------------------------------------------------------------------------]]--
function Lists.GroupListTooltipHook()
	ZO_PostHook('ZO_GroupListRowCharacterName_OnMouseEnter', function(control)
		--SSF.Chat:Debug("Group List Tooltip prehook started.")
		if not SSF.SV.sharedGuildsGroup then return end
    local data = ZO_ScrollList_GetData(control.row)
		if data.displayName == GetDisplayName() then return end
		local guilds = {}
		for i=1, GetNumGuilds() do
			for j=1, GetGuildInfo(GetGuildId(i)) do
				local name = GetGuildMemberInfo(GetGuildId(i),j)
				if name == data.displayName then
					table.insert(guilds, GetGuildName(GetGuildId(i)))
					break
				end
			end
		end
		guilds = table.concat(guilds, "\n")
		if data and data.hasCharacter and guilds ~= "" then
			SetTooltipText(InformationTooltip, guilds) 
		end
	end)
end


--[[------------------------------------------------------------------------------------------------
Lists.FriendListContextMenu()
Inputs:			  None
Outputs:			None
Description:	Adds an entry to the friends list context menu.
------------------------------------------------------------------------------------------------]]--
function Lists.FriendListContextMenu()
	local function AddItem(data)
		SSF.Chat:Debug("Friend List Context Menu started.")
		local name = data.displayName
		if SSF.SV.Favs[name] then 
			AddCustomMenuItem("Remove Fav Friend", function() Lists.RemoveFavFriend(name) end)
			if data.status == SSF.PlayerStatus.List.Offline and SSF.SV.groupInvite ~= SSF.AllFavNone.List.None then
				AddCustomMenuItem("Invite to Group", function() GroupInviteByName(name) end)
			end
		else
			AddCustomMenuItem("Add Fav Friend", function() Lists.AddFavFriend(name) end)
			if data.status == SSF.PlayerStatus.List.Offline and SSF.SV.groupInvite == SSF.AllFavNone.List.All then
				AddCustomMenuItem("Invite to Group", function() GroupInviteByName(name) end)
			end
		end
	end
	LCM:RegisterFriendsListContextMenu(AddItem, LCM.CATEGORY_LATE)
end


--[[------------------------------------------------------------------------------------------------
Lists.AddFavFriend(name)
Inputs:			  name 						- The @name to add to the fav friends list
Outputs:			None
Description:	Adds the name to the Fav list.
------------------------------------------------------------------------------------------------]]--
function Lists.AddFavFriend(name)
	SSF.SV.Favs[name] = true
	SSF.Chat:Debug(zo_strformat("<<1>> added to Fav Friends.", name))
	FLM:BuildMasterList()
	FL:RefreshFilters()
end


--[[------------------------------------------------------------------------------------------------
Lists.RemoveFavFriend(name)
Inputs:			  name 						- The @name to remove from the fav friends list
Outputs:			None
Description:	Removes the name from the Fav list.
------------------------------------------------------------------------------------------------]]--
function Lists.RemoveFavFriend(name)
	SSF.SV.Favs[name] = nil
	SSF.Chat:Debug(zo_strformat("<<1>> removed from Fav Friends.", name))
	FLM:BuildMasterList()
	FL:RefreshFilters()
end


--[[------------------------------------------------------------------------------------------------
Lists.OnIgnoreAdded(eventCode, displayName)
Inputs:				eventCode 			- ZOS event code
              displayName     - display name of the ignore added
Outputs:			None
Description:	Determines if the added ignore needs to be placed on the virtual list. Reserves the
              last ignore spot for transferring data and preserving ignore add functionality.
------------------------------------------------------------------------------------------------]]--
function Lists.OnIgnoreAdded(eventCode, displayName)
  -- if not at max ignore then we don't have to add to virtual list
  if GetNumIgnored() ~= IGNORED_MAX then return end

  table.insert(SSF.SV.Ignored, {displayName})
  RemoveIgnore(displayName)

  SSF.Chat:Msg(zo_strformat("Ignore list is full! <<1>> added to virtual ignore list.", displayName))
end


--[[------------------------------------------------------------------------------------------------
Lists.IgnoreMasterListHook()
Inputs:				None
Outputs:			None
Description:	Hooks into the ignore master list to add our virtual items.
------------------------------------------------------------------------------------------------]]--
function Lists.IgnoreMasterListHook()
  ZO_PostHook(ILM, "BuildMasterList", function(self_)
    for index, Ignore in ipairs(SSF.SV.Ignored) do
      table.insert(self_.masterList, {Ignore.displayName, Ignore.note, SOCIAL_NAME_SEARCH, IGNORED_MAX - 1 + index})
    end
  end)
end

--[[
RequestFriend(*string* _charOrDisplayName_, *string* _message_)

* RemoveFriend(*string* _displayName_)

* SetFriendNote(*luaindex* _friendIndex_, *string* _note_)

GetNumFriends()

IsFriend(*string* _charOrDisplayName_)
** _Returns:_ *bool* _isFriend_

GetFriendCharacterInfo(*luaindex* _friendIndex_)
** _Returns:_ *bool* _hasCharacter_, *string* _characterName_, *string* _zoneName_, *integer* _classType_, *[Alliance|#Alliance]* _alliance_, *integer* _level_, *integer* _championRank_, *integer* _zoneId_, *id64* _consoleId_

GetFriendInfo(*luaindex* _friendIndex_)
** _Returns:_ *string* _displayName_, *string* _note_, *[PlayerStatus|#PlayerStatus]* _playerStatus_, *integer* _secsSinceLogoff_

GetNumIncomingFriendRequests()
** _Returns:_ *integer* _numRequests_

* GetIncomingFriendRequestInfo(*luaindex* _index_)
** _Returns:_ *string* _displayName_, *integer* _secsSinceRequest_, *string* _message_

AcceptFriendRequest(*string* _displayName_)

* RejectFriendRequest(*string* _displayName_)

* CancelFriendRequest(*luaindex* _index_)

EVENT_INCOMING_FRIEND_INVITE_ADDED (*string* _displayName_)
* EVENT_INCOMING_FRIEND_INVITE_NOTE_UPDATED (*string* _displayName_, *string* _message_)
* EVENT_INCOMING_FRIEND_INVITE_REMOVED (*string* _displayName_)

EVENT_FRIEND_ADDED (number eventCode, string displayName)

EVENT_OUTGOING_FRIEND_INVITE_ADDED (*string* _displayName_)
* EVENT_OUTGOING_FRIEND_INVITE_REMOVED (*string* _displayName_)

GetNumOutgoingFriendRequests()
** _Returns:_ *integer* _numRequests_

* GetOutgoingFriendRequestInfo(*luaindex* _index_)
** _Returns:_ *string* _displayName_, *integer* _secsSinceRequest_, *string* _note_


EVENT_IGNORE_ADDED (*string* _displayName_)
* EVENT_IGNORE_NOTE_UPDATED (*string* _displayName_, *string* _note_)
* EVENT_IGNORE_ONLINE_CHARACTER_CHANGED (*string* _displayName_)
* EVENT_IGNORE_REMOVED (*string* _displayName_)

GetNumIgnored()
** _Returns:_ *integer* _numIgnored_

* GetIgnoredInfo(*luaindex* _index_)
** _Returns:_ *string* _displayName_, *string* _note_

* IsIgnored(*string* _charOrDisplayName_)
** _Returns:_ *bool* _isIgnored_

AddIgnore(*string* _charOrDisplayName_)

* RemoveIgnore(*string* _displayName_)

* SetIgnoreNote(*luaindex* _ignoreIndex_, *string* _note_)

EVENT_SOCIAL_DATA_LOADED
* EVENT_SOCIAL_ERROR (*[SocialActionResult|#SocialActionResult]* _error_)
]]--


--[[------------------------------------------------------------------------------------------------
Global template assignment
------------------------------------------------------------------------------------------------]]--
StaticsSocialFeatures.Lists = Lists