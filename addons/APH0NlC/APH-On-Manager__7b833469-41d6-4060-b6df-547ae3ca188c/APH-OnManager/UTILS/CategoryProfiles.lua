--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(APHOnManagerCore, "APH-OnManager.lua must be loaded before this file")
local AoM = APHOnManagerCore
local ApplyProfile, CaptureCurrentProfile, LoadProfileAndReload
local LibAPH = LibAPH

local logger = LibAPH.CreateChatLogger("AoM", "9CD04C")
local NAMES_PER_CHAT_LINE = 6

local function PrintNames(names)
	for first = 1, #names, NAMES_PER_CHAT_LINE do
		local chunk = {}
		for i = first, math.min(first + NAMES_PER_CHAT_LINE - 1, #names) do chunk[#chunk + 1] = names[i] end
		logger:Print(table.concat(chunk, ", "))
	end
end

local CopyList, CopyMap = LibAPH.CopyList, LibAPH.CopyMap

local profile_store = LibAPH.CreateProfileStore({
	getSaved = function() return AoM.saved end,
	field = "category_profiles",
	activeField = "active_category_profile_by_character",
	perCharacter = true,
	capture = function() return CaptureCurrentProfile() end,
	onChanged = function()
		if AoM.RefreshProfileControls then AoM.RefreshProfileControls() end
		if AoM.NoteSavedVariablesChanged then AoM.NoteSavedVariablesChanged() end
	end,
})
AoM.profile_store = profile_store

local profile_combos = {}
local NO_PROFILES_TEXT = AoM.L("NO_PROFILES_YET")

function AoM.RefreshProfileControls()
	if AoM.profile_button and AoM.GetProfileButtonText then
		AoM.profile_button:SetText(AoM.GetProfileButtonText())
	end
	local active = AoM.GetActiveProfileName()
	local text = active or (#AoM.GetProfileNames() > 0 and AoM.L("PICK_A_PROFILE")) or NO_PROFILES_TEXT
	for _, entry in ipairs(profile_combos) do
		entry.combo:ClearItems()
		entry.combo:SetSelectedItemText(text)
	end
end

function AoM.RegisterProfileCombo(combo, container)
	local entry = { combo = combo }
	profile_combos[#profile_combos + 1] = entry
	if container then
		LibAPH.UseContextMenuForCombo(container, AoM.ProfileMenuEntries, { enableFilter = true })
	end
	AoM.RefreshProfileControls()
	return entry
end

function AoM.GetProfileNames()
	return profile_store:GetNames()
end

function AoM.GetActiveProfileName()
	return profile_store:GetActiveName()
end

function AoM.SetActiveProfileName(name)
	profile_store:SetActiveName(name)
end

function AoM.GetProfileCharacterNames(name)
	local by_id = {}
	for i = 1, GetNumCharacters() do
		local character, _, _, _, _, _, id = GetCharacterInfo(i)
		if id then by_id[id] = zo_strformat("<<1>>", LibAPH.UnescapeName(character)) end
	end
	local names, others = {}, 0
	for _, id in ipairs(profile_store:GetCharacterIdsUsing(name)) do
		if by_id[id] then names[#names + 1] = by_id[id] else others = others + 1 end
	end
	table.sort(names)
	return names, others
end

function AoM.ProfileUsedByText(name)
	local names, others = AoM.GetProfileCharacterNames(name)
	if #names == 0 and others == 0 then return AoM.L("PROFILE_USED_BY_NOBODY") end
	local lines = { AoM.L("PROFILE_USED_BY") }
	for _, character in ipairs(names) do lines[#lines + 1] = character end
	if others > 0 then lines[#lines + 1] = string.format(AoM.L("PROFILE_USED_BY_OTHERS"), others) end
	return table.concat(lines, "\n")
end

function AoM.GetProfile(name)
	return profile_store:Get(name)
end

function CaptureCurrentProfile()
	local enabled, disabled = LibAPH.CaptureAddonEnabledState()
	return {
		saved_at = GetTimeStamp(),
		enabled = enabled,
		disabled = disabled,
		categories = CopyList(AoM.saved and AoM.saved.categories),
		assignment = CopyMap(AoM.saved and AoM.saved.addon_category_assignment),
		display_names = CopyMap(AoM.saved and AoM.saved.default_category_display_names),
	}
end

function AoM.SaveProfile(name)
	return profile_store:Save(name)
end

function AoM.DeleteProfile(name)
	return profile_store:Delete(name)
end

function AoM.RenameProfile(oldName, newName)
	return profile_store:Rename(oldName, newName)
end

function ApplyProfile(name)
	local profile = AoM.GetProfile(name)
	if not profile then return nil end

	local am = GetAddOnManager()
	local index_by_name, installed = {}, {}
	for i = 1, am:GetNumAddOns() do
		local addon_name = am:GetAddOnInfo(i)
		index_by_name[addon_name] = i
		installed[addon_name] = true
	end

	local report = { profile = name, enabled = 0, disabled = 0, missing = 0, untouched = {} }
	local in_profile = {}

	for _, addon_name in ipairs(profile.enabled or {}) do
		in_profile[addon_name] = true
		local index = index_by_name[addon_name]
		if index then
			if not select(5, am:GetAddOnInfo(index)) then
				am:SetAddOnEnabled(index, true)
				report.enabled = report.enabled + 1
			end
		else
			report.missing = report.missing + 1
		end
	end

	for _, addon_name in ipairs(profile.disabled or {}) do
		in_profile[addon_name] = true
		local index = index_by_name[addon_name]
		if index then
			if select(5, am:GetAddOnInfo(index)) then
				am:SetAddOnEnabled(index, false)
				report.disabled = report.disabled + 1
			end
		else
			report.missing = report.missing + 1
		end
	end

	for addon_name in pairs(installed) do
		if not in_profile[addon_name] then report.untouched[#report.untouched + 1] = addon_name end
	end
	table.sort(report.untouched)

	AoM.saved.categories = CopyList(profile.categories)
	AoM.saved.addon_category_assignment = CopyMap(profile.assignment)
	AoM.saved.default_category_display_names = CopyMap(profile.display_names)
	profile_store:SetActiveName(name)

	if AoM.RefreshAllCategoryUI then AoM.RefreshAllCategoryUI() end
	if AoM.RefreshProfileControls then AoM.RefreshProfileControls() end
	return report
end

local function PrintApplyReport(report)
	logger:Print(string.format("Loaded profile \"%s\": %d enabled, %d disabled.", report.profile, report.enabled, report.disabled))
	if report.missing > 0 then
		logger:Print(string.format("%d add-on(s) in this profile are not installed any more.", report.missing))
	end
	if #report.untouched > 0 then
		logger:Print(string.format("%d add-on(s) installed after this profile was saved were left as they are:", #report.untouched))
		PrintNames(report.untouched)
	end
end

function AoM.ReportPendingProfileApply()
	if not AoM.saved then return end
	local pending = AoM.saved.profile_apply_report
	if not pending then return end
	AoM.saved.profile_apply_report = nil
	logger:Print(string.format("Loaded profile \"%s\": %d enabled, %d disabled, %d not installed.",
		pending.profile, pending.enabled or 0, pending.disabled or 0, pending.missing or 0))
end

function AoM.ApplyProfileForReload(name)
	local report = ApplyProfile(name)
	if not report then return false end
	PrintApplyReport(report)
	AoM.saved.profile_apply_report = {
		profile = report.profile,
		enabled = report.enabled,
		disabled = report.disabled,
		missing = report.missing,
	}
	return true
end

function LoadProfileAndReload(name)
	if not AoM.ApplyProfileForReload(name) then return false end
	ReloadUI("ingame")
	return true
end

local function HidePopup()
	return AoM.HidePopupForDialog and AoM.HidePopupForDialog() or false
end

local function RestorePopup(was_visible)
	if AoM.RestorePopupAfterDialog then AoM.RestorePopupAfterDialog(was_visible) end
end

function AoM.ConfirmLoadProfile(name, onClosed)
	local profile = AoM.GetProfile(name)
	if not profile then return end
	local was_visible = HidePopup()
	local body = string.format(AoM.L("LOAD_THE_PROFILE_N_NIT_ENABLES"), name)
	LibAPH.ShowDialogChained("AoM_LOAD_PROFILE", AoM.L("LOAD_PROFILE"), body, {
		{ text = SI_DIALOG_CONFIRM, callback = function() LoadProfileAndReload(name) end },
		{ text = SI_DIALOG_CANCEL },
	}, nil, function()
		RestorePopup(was_visible)
		if onClosed then onClosed() end
	end)
end

function AoM.ConfirmSaveProfile(name, onClosed)
	name = name or AoM.GetActiveProfileName()
	if not name then
		AoM.ShowNewProfileDialog()
		return
	end
	local was_visible = HidePopup()
	local body = string.format(AoM.L("OVERWRITE_THE_PROFILE_WITH_THE_ADD"), name)
	LibAPH.ShowDialogChained("AoM_SAVE_PROFILE", AoM.L("SAVE_PROFILE"), body, {
		{ text = SI_DIALOG_CONFIRM, callback = function()
			AoM.SaveProfile(name)
			logger:Print(string.format("Saved profile \"%s\".", name))
		end },
		{ text = SI_DIALOG_CANCEL },
	}, nil, function()
		RestorePopup(was_visible)
		if onClosed then onClosed() end
	end)
end

function AoM.ShowNewProfileDialog()
	AoM.ShowNameEntryDialog("AoM_NEW_PROFILE", AoM.L("NEW_PROFILE"), AoM.L("NAME_THIS_PROFILE_IT_STORES_WHAT"), function(new_name)
		if AoM.GetProfile(new_name) then
			logger:Print(string.format("A profile called \"%s\" already exists.", new_name))
			return
		end
		AoM.SaveProfile(new_name)
		logger:Print(string.format("Created profile \"%s\".", new_name))
	end)
end

function AoM.ShowRenameProfileDialog(name)
	AoM.ShowNameEntryDialog("AoM_RENAME_PROFILE", AoM.L("RENAME_PROFILE"), string.format(AoM.L("ENTER_A_NEW_NAME_FOR"), name), function(new_name)
		local ok, reason = AoM.RenameProfile(name, new_name)
		if not ok and reason == "duplicate" then
			logger:Print(string.format("A profile called \"%s\" already exists.", new_name))
		end
	end)
end

function AoM.ConfirmDeleteProfile(name, onClosed)
	local was_visible = HidePopup()
	LibAPH.ShowDialogChained("AoM_DELETE_PROFILE", AoM.L("DELETE_PROFILE"),
		string.format(AoM.L("DELETE_THE_PROFILE_THE_ADD_ONS"), name), {
		{ text = SI_DIALOG_CONFIRM, callback = function()
			AoM.DeleteProfile(name)
			logger:Print(string.format("Deleted profile \"%s\".", name))
		end },
		{ text = SI_DIALOG_CANCEL },
	}, nil, function()
		RestorePopup(was_visible)
		if onClosed then onClosed() end
	end)
end
