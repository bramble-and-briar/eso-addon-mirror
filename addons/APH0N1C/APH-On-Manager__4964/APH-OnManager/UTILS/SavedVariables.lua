--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

APHOnManagerCore = APHOnManagerCore or {}
local AoM = APHOnManagerCore
local LibAPH = LibAPH

local SWEEP_THROTTLE_MS = 30000
local SELF_THROTTLE_MS = 5000
local CSA_LIFESPAN_MS = 5000

local LARGE_SHARE_OF_CAPACITY = 0.10
local TOTAL_WARN_SHARE = 0.80
local UNCAPPED_LARGE_FLOOR_MB = 20
local UNCAPPED_TOTAL_WARN_MB = 500

local warned_large = {}
local warned_total = false

local logger = LibAPH.CreateChatLogger("AoM", "9CD04C")

local function PlainTitle(title, name)
	return LibAPH.StripColors(title, name)
end

function AoM.ClearSavedVariableWarnings()
	warned_large = {}
	warned_total = false
end

function AoM.IsPrioritySaveAlertEnabled()
	return AoM.saved == nil or AoM.saved.priority_save_alert ~= false
end

function AoM.SetPrioritySaveAlertEnabled(enabled)
	if AoM.saved then AoM.saved.priority_save_alert = enabled end
end

local function Announce(text)
	if not AoM.IsPrioritySaveAlertEnabled() then return end
	LibAPH.SafeCSA(true, "|c9CD04CAPH-On Manager|r", "|cFFD700" .. text .. "|r", CSA_LIFESPAN_MS)
	logger:Print("|cFFD700" .. text .. "|r")
end

local function LargeThresholdMB()
	if type(AoM.GetSaveSizeUsage) ~= "function" then return nil end
	local total, capacity = AoM.GetSaveSizeUsage()
	if capacity then return capacity * LARGE_SHARE_OF_CAPACITY, capacity, total end
	if type(total) ~= "number" or total < UNCAPPED_LARGE_FLOOR_MB then return nil, nil, total end
	return total * LARGE_SHARE_OF_CAPACITY, nil, total
end

local function CheckOneAddon(name, index, usage, title)
	local _ = index
	if type(usage) ~= "number" or usage <= 0 or warned_large[name] then return end
	local threshold = LargeThresholdMB()
	if not threshold or usage < threshold then return end
	warned_large[name] = true
	Announce(string.format(AoM.L("IS_HOLDING_OF_SETTINGS_SAVING_IT"),
		PlainTitle(title, name), LibAPH.FormatDiskUsageMB(usage)))
end

local function CheckTotal()
	if warned_total then return end
	local _, capacity, total = LargeThresholdMB()
	if type(total) ~= "number" then return end
	if capacity then
		if total < capacity * TOTAL_WARN_SHARE then return end
		warned_total = true
		Announce(string.format(AoM.L("ADD_ON_SETTINGS_ARE_USING_OF"),
			LibAPH.FormatDiskUsageMB(total), LibAPH.FormatDiskUsageMB(capacity)))
		return
	end
	if total < UNCAPPED_TOTAL_WARN_MB then return end
	warned_total = true
	Announce(string.format(AoM.L("ADD_ON_SETTINGS_ARE_USING_ON"),
		LibAPH.FormatDiskUsageMB(total)))
end

function AoM.IsPrioritySaveEnabled()
	return AoM.saved == nil or AoM.saved.priority_save ~= false
end

function AoM.SetPrioritySaveEnabled(enabled)
	if AoM.saved then AoM.saved.priority_save = enabled end
	if enabled then AoM.RequestPrioritySaveSweep(true) end
end

function AoM.RequestPrioritySaveSweep(force)
	if not AoM.IsPrioritySaveEnabled() then return 0 end
	if type(LibAPH.RequestThrottledPrioritySaveSweep) ~= "function" then return 0 end
	local saved = LibAPH.RequestThrottledPrioritySaveSweep(AoM.name, SWEEP_THROTTLE_MS, force, CheckOneAddon)
	if saved > 0 or force then CheckTotal() end
	return saved
end

function AoM.NoteSavedVariablesChanged(force)
	if not AoM.IsPrioritySaveEnabled() then return false end
	if type(LibAPH.RequestThrottledPrioritySave) ~= "function" then return false end
	return LibAPH.RequestThrottledPrioritySave(AoM.name, AoM.name, SELF_THROTTLE_MS, force)
end

EVENT_MANAGER:RegisterForEvent("AoM_PrioritySave", EVENT_PLAYER_DEACTIVATED, function()
	AoM.RequestPrioritySaveSweep()
end)

function AoM.GetSavedVariablesUsageMB(addonIndex)
	if type(LibAPH.GetSavedVariablesDiskUsageMB) ~= "function" then return nil end
	local usage = LibAPH.GetSavedVariablesDiskUsageMB(addonIndex)
	if type(usage) ~= "number" or usage <= 0 then return nil end
	return usage
end

function AoM.FormatSavedVariablesUsage(usage)
	return LibAPH.FormatDiskUsageMB(usage)
end

function AoM.FormatSavedVariablesUsageShort(usage)
	return LibAPH.FormatDiskUsageMB(usage, true)
end

function AoM.GetUnusedSavedVariablesMB()
	if type(LibAPH.GetUnusedSavedVariablesDiskUsageMB) ~= "function" then return 0 end
	local unused = LibAPH.GetUnusedSavedVariablesDiskUsageMB()
	if type(unused) ~= "number" or unused <= 0 then return 0 end
	return unused
end

local function HidePopup()
	return AoM.HidePopupForDialog and AoM.HidePopupForDialog() or false
end

local function RestorePopup(was_visible)
	if AoM.RestorePopupAfterDialog then AoM.RestorePopupAfterDialog(was_visible) end
end

function AoM.ConfirmDeleteSavedVariables(addonIndex, displayName, onDone)
	local usage = AoM.GetSavedVariablesUsageMB(addonIndex)
	if not usage then return false end
	local was_visible = HidePopup()
	LibAPH.ShowDialogChained("AoM_DELETE_SAVED_VARIABLES", AoM.L("DELETE_SAVED_VARIABLES"),
		string.format(AoM.L("DELETE_THE_SETTINGS_HAS_SAVED_ON"),
			displayName, AoM.FormatSavedVariablesUsage(usage)), {
		{
			text = SI_DIALOG_CONFIRM,
			callback = function()
				LibAPH.DeleteSavedVariablesForAddon(addonIndex)
				logger:Print(string.format("Deleted the saved variables for %s (%s).",
					displayName, AoM.FormatSavedVariablesUsage(usage)))
				RestorePopup(was_visible)
				if onDone then onDone() end
			end,
		},
		{ text = SI_DIALOG_CANCEL, callback = function() RestorePopup(was_visible) end },
	}, nil, function() RestorePopup(was_visible) end)
	return true
end

function AoM.ConfirmClearUnusedSavedVariables(onDone)
	local unused = AoM.GetUnusedSavedVariablesMB()
	if unused <= 0 then return false end
	local was_visible = HidePopup()
	LibAPH.ShowDialogChained("AoM_CLEAR_UNUSED_SAVED_VARIABLES", AoM.L("CLEAR_UNUSED_SETTINGS"),
		string.format(AoM.L("DELETE_THE_SETTINGS_LEFT_BEHIND_BY"),
			AoM.FormatSavedVariablesUsage(unused)), {
		{
			text = SI_DIALOG_CONFIRM,
			callback = function()
				LibAPH.ClearUnusedSavedVariables()
				logger:Print(string.format("Cleared %s of settings left behind by add-ons that are no longer installed.",
					AoM.FormatSavedVariablesUsage(unused)))
				RestorePopup(was_visible)
				if onDone then onDone() end
			end,
		},
		{ text = SI_DIALOG_CANCEL, callback = function() RestorePopup(was_visible) end },
	}, nil, function() RestorePopup(was_visible) end)
	return true
end

function AoM.DevReportPrioritySaveSweep()
	if type(LibAPH.RequestPrioritySaveForRunningAddons) ~= "function" then
		logger:Print("LibAPH has no sweep to run.")
		return 0
	end

	local names = {}
	local saved = LibAPH.RequestPrioritySaveForRunningAddons(function(name, _, usage, title)
		names[#names + 1] = string.format("%s%s", PlainTitle(title, name),
			usage and (" (" .. LibAPH.FormatDiskUsageMB(usage) .. ")") or "")
	end)

	logger:Print(string.format("Priority save asked for %d add-on%s:",
		saved, saved == 1 and "" or "s"))
	for _, line in ipairs(names) do logger:Print("  " .. line) end

	local skipped = 0
	local manager = GetAddOnManager()
	if manager then
		for index = 1, manager:GetNumAddOns() do
			local name, _, _, _, enabled, state = manager:GetAddOnInfo(index)
			if name and not LibAPH.IsAddOnRunningState(enabled, state) then skipped = skipped + 1 end
		end
	end
	logger:Print(string.format("Skipped %d not loaded this session.", skipped))
	return saved
end
