--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(APHOnManagerCore, "APH-OnManager.lua must be loaded before this file")
local AoM = APHOnManagerCore
local LibAPH = LibAPH

local selected_profile

local function EnsureSelectedProfile()
	local names = AoM.GetProfileNames()
	if selected_profile and AoM.GetProfile(selected_profile) then return selected_profile end
	selected_profile = AoM.GetActiveProfileName() or names[1]
	return selected_profile
end

function AoM.CreateProfileSettingsButton(parent, name, onClicked)
	if not LibAPH.IsScrollableMenuAvailable() then return nil end
	return LibAPH.CreateCogwheelButton(parent, name, onClicked or function(button)
		AoM.ShowProfileTriggerMenu(button)
	end, AoM.L("PROFILE_TRIGGERS"))
end

local friend_filter = "all"

local FRIEND_FILTERS = {
	{ id = "all", label = AoM.L("ALL_FRIENDS") },
	{ id = "online", label = AoM.L("FRIENDS_ONLINE_NOW") },
	{ id = "offline", label = AoM.L("FRIENDS_OFFLINE") },
	{ id = "ignored", label = AoM.L("IGNORE_LIST") },
}

local function FilteredNames()
	if friend_filter == "ignored" then
		local names = {}
		for _, display_name in ipairs(LibAPH.GetIgnoredList()) do
			names[#names + 1] = { name = display_name, online = false }
		end
		return names
	end
	local names = {}
	for _, friend in ipairs(LibAPH.GetFriendList()) do
		if friend_filter == "all"
			or (friend_filter == "online" and friend.online)
			or (friend_filter == "offline" and not friend.online) then
			names[#names + 1] = friend
		end
	end
	return names
end

local function FriendEntries(profile_name)
	local entries = {}
	local shown = FilteredNames()

	for _, filter in ipairs(FRIEND_FILTERS) do
		entries[#entries + 1] = {
			text = AoM.L("SHOW") .. filter.label,
			checkbox = true,
			checked = friend_filter == filter.id,
			onToggle = function() friend_filter = filter.id end,
		}
	end

	entries[#entries + 1] = {
		text = AoM.L("WATCH_EVERYONE_SHOWN"),
		onClick = function()
			for _, person in ipairs(shown) do AoM.SetProfileTriggerFriend(profile_name, person.name, true) end
			if LibAPH.RefreshContextMenu then LibAPH.RefreshContextMenu() end
		end,
		closeOnClick = false,
	}
	entries[#entries + 1] = {
		text = AoM.L("WATCH_NOBODY"),
		onClick = function()
			local profile = AoM.GetProfile(profile_name)
			if profile then profile.trigger_friends = {} end
			if LibAPH.RefreshContextMenu then LibAPH.RefreshContextMenu() end
		end,
		closeOnClick = false,
	}

	if #shown == 0 then
		entries[#entries + 1] = { text = AoM.L("NOBODY_IN_THIS_LIST") }
		return entries
	end

	entries[#entries + 1] = { text = AoM.L("NAMES_TO_WATCH"), header = true }
	for _, person in ipairs(shown) do
		entries[#entries + 1] = {
			text = person.name,
			icon = person.statusIcon,
			checkbox = true,
			checked = AoM.GetProfileTriggerFriend(profile_name, person.name),
			keepOpen = true,
			onToggle = function(checked) AoM.SetProfileTriggerFriend(profile_name, person.name, checked) end,
		}
	end
	return entries
end

local function TriggerEntries(profile_name, group_id, control)
	local entries = {}
	for _, trigger in ipairs(LibAPH.GetActivityTriggersInGroup(group_id)) do
		local active_now = AoM.IsProfileTriggerActive(trigger.id, profile_name)
		entries[#entries + 1] = {
			text = trigger.label,
			color = active_now and LibAPH.THEME.GREEN or nil,
			checkbox = true,
			checked = AoM.GetProfileTriggerState(profile_name, trigger.id),
			keepOpen = true,
			onToggle = function(checked) AoM.SetProfileTriggerState(profile_name, trigger.id, checked) end,
		}
		if trigger.needsNames and AoM.GetProfileTriggerState(profile_name, trigger.id) then
			entries[#entries + 1] = {
				text = string.format(AoM.L("NAMES_TO_WATCH_ON"),
					AoM.GetProfileTriggerFriendCount(profile_name)),
				submenu = function() return FriendEntries(profile_name) end,
			}
		end
	end
	local _ = control
	return entries
end

local function ProfileListEntries(control)
	local entries = {}
	for _, name in ipairs(AoM.GetProfileNames()) do
		entries[#entries + 1] = {
			text = name,
			onClick = function()
				selected_profile = name
				zo_callLater(function() AoM.ShowProfileTriggerMenu(control) end, 50)
			end,
		}
	end
	if #entries == 0 then
		entries[#entries + 1] = { text = AoM.L("NO_PROFILES_YET") }
	end
	return entries
end

function AoM.GetProfileButtonText()
	local active = AoM.GetActiveProfileName()
	if active then return AoM.L("PROFILE") .. active end
	if #AoM.GetProfileNames() > 0 then return AoM.L("PICK_A_PROFILE") end
	return AoM.L("NO_PROFILES_YET")
end

local function ProfileActionEntries(name)
	return {
		{ text = "Load", onClick = function() AoM.ConfirmLoadProfile(name) end },
		{ text = "Save", onClick = function() AoM.ConfirmSaveProfile(name) end },
		{ text = "Rename", onClick = function() AoM.ShowRenameProfileDialog(name) end },
		{ text = "Delete", onClick = function() AoM.ConfirmDeleteProfile(name) end },
	}
end

function AoM.ProfileMenuEntries()
	local entries = {}
	local active = AoM.GetActiveProfileName()
	local names = AoM.GetProfileNames()

	entries[#entries + 1] = { text = "Profiles", header = true }
	entries[#entries + 1] = { text = AoM.L("NEW_PROFILE_2"), onClick = function() AoM.ShowNewProfileDialog() end }
	entries[#entries + 1] = { divider = true }
	for _, name in ipairs(names) do
		entries[#entries + 1] = {
			text = name,
			color = name == active and LibAPH.THEME.GREEN or nil,
			tooltip = function() return AoM.ProfileUsedByText(name) end,
			submenu = function() return ProfileActionEntries(name) end,
		}
	end
	if #names == 0 then
		entries[#entries + 1] = { text = AoM.L("NO_PROFILES_YET") }
	end
	return entries
end

function AoM.ShowProfileMenu(control, onHide)
	LibAPH.ShowScrollableMenu(control, AoM.ProfileMenuEntries(), { onHide = onHide, enableFilter = true })
end

local function TriggerMenuEntries(control)
	local profile_name = EnsureSelectedProfile()
	local entries = {}

	entries[#entries + 1] = {
		text = AoM.L("ENABLE_SWITCHING"),
		checkbox = true,
		checked = AoM.IsProfileAutoSwitchEnabled(),
		keepOpen = true,
		onToggle = function(checked) AoM.SetProfileAutoSwitchEnabled(checked) end,
	}

	if not profile_name then
		entries[#entries + 1] = { text = AoM.L("MAKE_A_PROFILE_FIRST_THEN_PICK") }
		return entries
	end

	entries[#entries + 1] = {
		text = AoM.L("PROFILE") .. profile_name,
		submenu = function() return ProfileListEntries(control) end,
	}
	entries[#entries + 1] = { text = AoM.L("LOAD_IT_WHEN_ALL_OF_THESE"), header = true }

	for _, group in ipairs(LibAPH.GetActivityTriggerGroups()) do
		local group_id = group.id
		local on_count = 0
		for _, trigger in ipairs(LibAPH.GetActivityTriggersInGroup(group_id)) do
			if AoM.GetProfileTriggerState(profile_name, trigger.id) then on_count = on_count + 1 end
		end
		entries[#entries + 1] = {
			text = group.label .. (on_count > 0 and string.format("  |c66FF66(%d on)|r", on_count) or ""),
			submenu = function() return TriggerEntries(profile_name, group_id, control) end,
		}
	end
	return entries
end

function AoM.ShowProfileTriggerMenu(control)
	local function Build() return TriggerMenuEntries(control) end
	LibAPH.ShowScrollableMenu(control, Build(), { rebuild = Build })
end

