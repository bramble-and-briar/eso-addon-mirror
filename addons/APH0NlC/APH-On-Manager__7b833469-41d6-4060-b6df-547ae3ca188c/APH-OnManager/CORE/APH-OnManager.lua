--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH must be loaded before APH-OnManager")

APHOnManagerCore = APHOnManagerCore or {}
local AoM = APHOnManagerCore
local dev_simulate_error, ApplySuggestedCategoriesOnce
local LibAPH = LibAPH
AoM.name = "APH-OnManager"
AoM.VERSION = "2026.10.15.14.36"

function AoM.L(key, ...)
	local id = _G["SI_AOM_" .. key]
	local text = id and GetString(id) or key
	if select("#", ...) > 0 then return string.format(text, ...) end
	return text
end

local SUGGESTED_CATEGORIES_VERSION = 3

AoM.CreateKnownTable = LibAPH.CreatePackedTable
AoM.CreateConsoleTable = LibAPH.CreatePackedConsoleTable
AoM.CreateConsoleListTable = LibAPH.CreatePackedListTable
AoM.CreateConsoleValueTable = LibAPH.CreatePackedValueTable
AoM.GetKnownNames = LibAPH.GetPackedTableNames

function dev_simulate_error()
	zo_callLater(function()
		error(AoM.name .. ": THIS IS NOT A REAL ERROR, THIS IS A TEST ERROR")
	end, 1)
end

ZO_CreateStringId("SI_BINDING_NAME_AOM_NEW_CATEGORY", "New Category")
ZO_CreateStringId("SI_BINDING_NAME_AOM_RESET_LIST", "Reset List")
ZO_CreateStringId("SI_BINDING_NAME_AOM_RESET_CATEGORIES", "Reset Categories")
ZO_CreateStringId("SI_BINDING_NAME_AOM_SELECT_ALL_LIBRARIES", "Select All Libraries")
ZO_CreateStringId("SI_BINDING_NAME_AOM_DESELECT_ALL_LIBRARIES", "Deselect All Libraries")
ZO_CreateStringId("SI_BINDING_NAME_AOM_APPLY_LIBRARY_CHANGES", "Apply Library Changes")

AoM.KEYBIND_LAYER = "APH-On Manager"
AoM.LIBRARIES_KEYBIND_LAYER = "APH-On Manager Libraries"

EVENT_MANAGER:RegisterForEvent("AoM_Init", EVENT_ADD_ON_LOADED, function(eventCode, addonName)
	if addonName ~= AoM.name then return end
	EVENT_MANAGER:UnregisterForEvent("AoM_Init", EVENT_ADD_ON_LOADED)
	AoM.saved = ZO_SavedVars:NewAccountWide("APHOnManager", 1, GetWorldName() or "Default", {})
	AoM.saved.addon_version_warned = AoM.saved.addon_version_warned or {}
	if AoM.ReplayEarlyErrors then AoM.ReplayEarlyErrors() end
	LibAPH.RegisterKeybindDefaults("AoM", AoM.saved, {
		AOM_NEW_CATEGORY = KEY_F,
		AOM_RESET_LIST = KEY_Q,
		AOM_RESET_CATEGORIES = KEY_Z,
		AOM_SELECT_ALL_LIBRARIES = KEY_F,
		AOM_DESELECT_ALL_LIBRARIES = KEY_R,
		AOM_APPLY_LIBRARY_CHANGES = KEY_E,
	})

	LibAPH.RegisterAddonDependencies(AoM.name, { "LibAPH" }, { "AddonSelector", "PerfectPixel" })

	local function GetKnownAddonData(name)
		return (AoM.GetKnownEntriesByPlatform(name))
	end
	AoM.GetKnownAddonData = GetKnownAddonData
	LibAPH.SetAddonMetadataProvider(GetKnownAddonData)
	AoM.bug_reporter = LibAPH.CreateAddonBugReporter({
		addonName = AoM.name,
		title = "APH-On Manager",
		version = AoM.VERSION,
		boxName = "AoMBugReportBox",
	})
	if GetDisplayName() == "@APHONlC" then
		SLASH_COMMANDS["/aomsimulateerror"] = dev_simulate_error
		SLASH_COMMANDS["/aomsweepreport"] = AoM.DevReportPrioritySaveSweep
	end
	if not IsConsoleUI() then
		SLASH_COMMANDS["/aombugreport"] = AoM.bug_reporter.Show
		SLASH_COMMANDS["/libcheck"] = AoM.RunOptionalLibraryWizard
		SLASH_COMMANDS["/libcategories"] = AoM.OpenCategoryManager
		SLASH_COMMANDS["/libraryversioncheck"] = AoM.ShowLibraryVersionCheck
		SLASH_COMMANDS["/aomsavealerts"] = function()
			local enabled = not AoM.IsPrioritySaveAlertEnabled()
			AoM.SetPrioritySaveAlertEnabled(enabled)
			d(string.format(AoM.L("AOM_SAVED_VARIABLE_ALERTS_ARE_NOW"),
				enabled and "|c00FF00on|r" or AoM.L("OFF")))
		end
	end

	EVENT_MANAGER:RegisterForEvent("AoM_PendingReport", EVENT_PLAYER_ACTIVATED, function()
		EVENT_MANAGER:UnregisterForEvent("AoM_PendingReport", EVENT_PLAYER_ACTIVATED)
		AoM.ReportPendingOptionalLibraryChanges()
		AoM.ReportPendingProfileApply()
	end)

	LibAPH.RunInitStages(AoM.name, {
		function() end,
		function()
			LibAPH.CheckAddonVersions(setmetatable({}, { __index = function(_, name) return GetKnownAddonData(name) end }),
				AoM.saved.addon_version_warned, function(name, installedVer, expected)
				d(string.format(AoM.L("AOM_IS_OUTDATED_INSTALLED_V_EXPECTED"),
					name, installedVer, expected.displayVersion))
			end)
		end,
		ApplySuggestedCategoriesOnce,
	})
end)

function ApplySuggestedCategoriesOnce()
	if AoM.saved.suggested_categories_version ~= SUGGESTED_CATEGORIES_VERSION then
		AoM.saved.suggested_categories_version = SUGGESTED_CATEGORIES_VERSION
		AoM.PruneUninstalledCategoryAssignments()
		AoM.ApplySuggestedCategories(AoM.SuggestedCategories, false)
		if IsConsoleUI() and AoM.ConsoleSuggestedCategories then
			local console_categories = {}
			for _, name in ipairs(AoM.GetKnownNames(AoM.ConsoleSuggestedCategories)) do
				console_categories[name] = AoM.ConsoleSuggestedCategories[name]
			end
			AoM.ApplySuggestedCategories(console_categories, false)
		end
	end
end
