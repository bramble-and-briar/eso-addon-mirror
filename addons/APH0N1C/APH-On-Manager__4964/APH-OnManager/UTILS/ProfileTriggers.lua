--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(APHOnManagerCore, "APH-OnManager.lua must be loaded before this file")
local AoM = APHOnManagerCore
local LibAPH = LibAPH

local logger = LibAPH.CreateChatLogger("AoM", "9CD04C")
local AUTO_SWITCH_NAMESPACE = "AoM_ProfileAutoSwitch"
local AUTO_SWITCH_COOLDOWN_SEC = 60
local ASK_DIALOG = "AoM_AUTO_SWITCH_PROFILE"
local CSA_LIFESPAN_MS = 10000

local declined_profile
local pending_ask

function AoM.GetProfileTriggers()
	return LibAPH.GetActivityTriggers()
end

function AoM.IsProfileAutoSwitchEnabled()
	return AoM.saved ~= nil and AoM.saved.auto_switch_profiles == true
end

function AoM.SetProfileAutoSwitchEnabled(enabled)
	if AoM.saved then AoM.saved.auto_switch_profiles = enabled end
	declined_profile = nil
end

function AoM.GetProfileTriggerState(profileName, trigger_id)
	local profile = AoM.GetProfile(profileName)
	return profile ~= nil and profile.triggers ~= nil and profile.triggers[trigger_id] == true
end

function AoM.SetProfileTriggerState(profileName, trigger_id, enabled)
	local profile = AoM.GetProfile(profileName)
	if not profile then return false end
	profile.triggers = profile.triggers or {}
	profile.triggers[trigger_id] = enabled or nil
	declined_profile = nil
	return true
end

function AoM.GetProfileTriggerFriend(profileName, displayName)
	local profile = AoM.GetProfile(profileName)
	return profile ~= nil and profile.trigger_friends ~= nil and profile.trigger_friends[displayName] == true
end

function AoM.SetProfileTriggerFriend(profileName, displayName, enabled)
	local profile = AoM.GetProfile(profileName)
	if not profile then return false end
	profile.trigger_friends = profile.trigger_friends or {}
	profile.trigger_friends[displayName] = enabled or nil
	declined_profile = nil
	return true
end

function AoM.GetProfileTriggerFriendCount(profileName)
	local profile = AoM.GetProfile(profileName)
	local count = 0
	for _ in pairs(profile and profile.trigger_friends or {}) do count = count + 1 end
	return count
end

function AoM.GetFriendDisplayNames()
	local names = {}
	for _, friend in ipairs(LibAPH.GetFriendList()) do names[#names + 1] = friend.name end
	return names
end

local function TriggerContext(profile)
	return { names = profile and profile.trigger_friends }
end

function AoM.IsProfileTriggerActive(trigger_id, profileName)
	return LibAPH.IsActivityTriggerActive(trigger_id, TriggerContext(AoM.GetProfile(profileName)))
end

function AoM.GetMatchingProfileName()
	local best_name, best_count
	for _, name in ipairs(AoM.GetProfileNames()) do
		local profile = AoM.GetProfile(name)
		local count = LibAPH.CountActiveActivityTriggers(profile.triggers, TriggerContext(profile))
		if count and (not best_count or count > best_count) then
			best_name, best_count = name, count
		end
	end
	return best_name
end

function AoM.ProfileNeedsChanges(name)
	local profile = AoM.GetProfile(name)
	if not profile then return false end
	local am = GetAddOnManager()
	local wanted = {}
	for _, addon_name in ipairs(profile.enabled or {}) do wanted[addon_name] = true end
	for _, addon_name in ipairs(profile.disabled or {}) do
		if wanted[addon_name] == nil then wanted[addon_name] = false end
	end
	for i = 1, am:GetNumAddOns() do
		local addon_name, _, _, _, is_enabled = am:GetAddOnInfo(i)
		local want = wanted[addon_name]
		if want ~= nil and (want == true) ~= (is_enabled == true) then return true end
	end
	return false
end

local function ManualHint(name)
	if IsConsoleUI() then
		return string.format(AoM.L("PROFILE_WAS_NOT_LOADED_OPEN_OPTIONS"), name)
	end
	return string.format(AoM.L("PROFILE_WAS_NOT_LOADED_OPEN_THE"), name)
end

local function SwitchNow(name)
	AoM.saved.last_auto_switch_time = GetTimeStamp()
	LibAPH.ReloadUIWhenSafe(AUTO_SWITCH_NAMESPACE, {
		logger = logger,
		reloadingMessage = string.format(AoM.L("LOADING_PROFILE"), name),
		waitingMessage = string.format(AoM.L("PROFILE_WILL_LOAD_ONCE_YOU_ARE"), name),
		stillWanted = function()
			if AoM.GetMatchingProfileName() ~= name then return false end
			return AoM.ApplyProfileForReload(name)
		end,
	})
end

local function AskToSwitch(name)
	if pending_ask then return end
	pending_ask = name
	local answered = false
	local body = string.format(AoM.L("YOUR_ADD_ONS_MATCH_THE_PROFILE"), name)
	LibAPH.ShowDialogChained(ASK_DIALOG, AoM.L("SWITCH_PROFILE"), body, {
		{ text = SI_DIALOG_CONFIRM, callback = function()
			answered = true
			pending_ask = nil
			SwitchNow(name)
		end },
		{ text = SI_DIALOG_CANCEL, callback = function()
			answered = true
			pending_ask = nil
			declined_profile = name
			AoM.saved.last_auto_switch_time = GetTimeStamp()
		end },
	}, nil, function()
		if answered then return end
		pending_ask = nil
		declined_profile = name
		AoM.saved.last_auto_switch_time = GetTimeStamp()
		local hint = ManualHint(name)
		LibAPH.SafeCSA(true, "|c9CD04CAPH-On Manager|r", "|cFFD700" .. hint .. "|r", CSA_LIFESPAN_MS)
		logger:Print("|cFFD700" .. hint .. "|r")
	end)
end

function AoM.RunProfileAutoSwitch()
	if not AoM.IsProfileAutoSwitchEnabled() then return end
	if not AoM.saved or pending_ask then return end
	local name = AoM.GetMatchingProfileName()
	if not name then
		declined_profile = nil
		return
	end
	if name == declined_profile then return end

	local last = AoM.saved.last_auto_switch_time or 0
	if GetTimeStamp() - last < AUTO_SWITCH_COOLDOWN_SEC then return end

	if not AoM.ProfileNeedsChanges(name) then
		if AoM.GetActiveProfileName() ~= name then
			AoM.SetActiveProfileName(name)
			if AoM.RefreshProfileControls then AoM.RefreshProfileControls() end
		end
		return
	end
	AskToSwitch(name)
end

LibAPH.RegisterActivityTriggerWatcher(AUTO_SWITCH_NAMESPACE, function() AoM.RunProfileAutoSwitch() end, 1500)
