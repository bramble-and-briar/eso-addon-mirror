--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(APHOnManagerCore, "APH-OnManager.lua must be loaded before this file")
local AoM = APHOnManagerCore
local BuildDependencyTooltip, GetAddonWord
assert(AoM.KnownAddonDependencies, "KnownAddonDependencies.lua must be loaded before this file")
assert(AoM.KnownAddonVersions, "KnownAddonVersions.lua must be loaded before this file")
assert(AoM.KnownLibraries, "KnownLibraries.lua must be loaded before this file")
local LibAPH = LibAPH
local KnownAddonVersions = AoM.KnownAddonVersions
local KnownLibraries = AoM.KnownLibraries
local KnownConsoleAddons = AoM.KnownConsoleAddons
local SuggestedCategories = AoM.SuggestedCategories
local GetUpdateStatus
local PATCH_CATEGORY = "Plug-Ins & Patches"

local addon_info_by_name

local function GetAddonInfoCache(am)
	if addon_info_by_name then return addon_info_by_name end
	addon_info_by_name = {}
	for i = 1, am:GetNumAddOns() do
		local name, _, _, _, _, _, _, isLibrary = am:GetAddOnInfo(i)
		addon_info_by_name[name] = { index = i, isLibrary = isLibrary or string.sub(name, 1, 3) == "Lib" }
	end
	return addon_info_by_name
end

local function GetOptionalLibsFor(addonName)
	local decl = LibAPH.registered_dependencies and LibAPH.registered_dependencies[addonName]
	local libs = {}
	if decl then
		for lib_name in pairs(decl.optional) do table.insert(libs, lib_name) end
	else
		for _, lib_name in ipairs(AoM.GetKnownDependencies(addonName)) do table.insert(libs, lib_name) end
	end
	table.sort(libs)
	return libs
end

local function FormatLibraryStatus(am, lib_name, min_version, show_version)
	local info = GetAddonInfoCache(am)[lib_name]
	if info then
		local _, _, _, _, enabled, state = am:GetAddOnInfo(info.index)
		local ver = am:GetAddOnVersion(info.index)
		local ver_suffix = show_version and LibAPH.FormatVersionBare(ver) or ""
		if LibAPH.IsAddOnRunningState(enabled, state) then
			if min_version and min_version > 0 and ver < min_version then
				return "|cFFA500" .. lib_name .. ver_suffix .. "|r"
			end
			return "|c00FF00" .. lib_name .. ver_suffix .. "|r"
		end
		return "|cFF0000" .. lib_name .. ver_suffix .. "|r"
	end
	return "|c888888" .. lib_name .. AoM.L("NOT_INSTALLED")
end

local function GetRequiredLibsInfo(am, addon_index)
	local list = {}
	for d = 1, am:GetAddOnNumDependencies(addon_index) do
		local dep_name, _, _, minVersion = am:GetAddOnDependencyInfo(addon_index, d)
		table.insert(list, { name = dep_name, minVersion = minVersion })
	end
	return list
end

local function AddTitleLine(tooltip, text)
	local r, g, b = ZO_SELECTED_TEXT:UnpackRGB()
	tooltip:AddLine(text, "ZoFontHeader3", r, g, b, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
end
local function AddSubTitleLine(tooltip, text)
	local r, g, b = ZO_SELECTED_TEXT:UnpackRGB()
	tooltip:AddLine(text, "ZoFontWinH5", r, g, b, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
end
local function AddCenterLine(tooltip, text)
	local r, g, b = ZO_TOOLTIP_DEFAULT_COLOR:UnpackRGB()
	tooltip:AddLine(text, "", r, g, b, CENTER, MODIFY_TEXT_TYPE_NONE, TEXT_ALIGN_CENTER, true)
end

local function FindAddonIndex(am, addonName)
	local info = GetAddonInfoCache(am)[addonName]
	return info and info.index or nil
end

function AoM.GetLibrarySections(am, index, addonName)
	local sections = {}
	local cache = GetAddonInfoCache(am)
	if index then
		local required_addons, required_libs = {}, {}
		for _, r in ipairs(GetRequiredLibsInfo(am, index)) do
			local formatted = FormatLibraryStatus(am, r.name, r.minVersion, true)
			local r_info = cache[r.name]
			if r_info and r_info.isLibrary then
				table.insert(required_libs, formatted)
			else
				table.insert(required_addons, formatted)
			end
		end
		if #required_addons > 0 then
			table.insert(sections, { title = #required_addons > 1 and "Required add-ons:" or "Required add-on:", text = table.concat(required_addons, ", ") })
		end
		if #required_libs > 0 then
			table.insert(sections, { title = #required_libs > 1 and "Required libraries:" or "Required library:", text = table.concat(required_libs, ", ") })
		end
	end

	local optional_real_libs, optional_addons = {}, {}
	for _, lib_name in ipairs(GetOptionalLibsFor(addonName)) do
		local opt_info = cache[lib_name]
		if (opt_info and opt_info.isLibrary) or string.sub(lib_name, 1, 3) == "Lib" then
			table.insert(optional_real_libs, lib_name)
		else
			table.insert(optional_addons, lib_name)
		end
	end

	if #optional_real_libs > 0 then
		local parts = {}
		for _, lib_name in ipairs(optional_real_libs) do
			table.insert(parts, FormatLibraryStatus(am, lib_name, nil, true))
		end
		table.insert(sections, { title = #optional_real_libs > 1 and AoM.L("OPTIONAL_LIBRARIES") or AoM.L("OPTIONAL_LIBRARY"), text = table.concat(parts, ", ") })
	end

	if #optional_addons > 0 then
		local parts = {}
		for _, lib_name in ipairs(optional_addons) do
			table.insert(parts, FormatLibraryStatus(am, lib_name, nil, true))
		end
		table.insert(sections, { title = #optional_addons > 1 and AoM.L("OPTIONAL_ADD_ON_DEPENDENCIES") or AoM.L("OPTIONAL_ADD_ON_DEPENDENCY"), text = table.concat(parts, ", ") })
	end
	return sections
end

local function AddLibrarySections(tooltip, am, data)
	for _, section in ipairs(AoM.GetLibrarySections(am, data.index, data.addOnFileName)) do
		AddSubTitleLine(tooltip, section.title)
		AddCenterLine(tooltip, section.text)
	end
end


local GOLD = "|cFFD21A"
local RED = "|cFF0000"
local GREEN = "|c00FF00"

local function Colored(text, color)
	if not color then return text end
	return color .. text .. "|r"
end

function AoM.GetAddonUpdateStatus(am, index)
	local name, _, _, _, _, _, is_out_of_date = am:GetAddOnInfo(index)
	return GetUpdateStatus(am, index, name, is_out_of_date)
end

function AoM.GetVersionLines(am, index, name, is_out_of_date)
	local status = GetUpdateStatus(am, index, name, is_out_of_date)
	local known = status.known
	local installed = status.installed or 0
	local live_version = known and known.displayVersion
	local live_addon_version = known and known.requiredVersion
	local lines = {}

	local mismatch = live_addon_version ~= nil and installed > 0 and installed ~= live_addon_version

	if not live_version then
		lines[#lines + 1] = Colored("No Version", GOLD)
	elseif mismatch then
		lines[#lines + 1] = Colored(AoM.L("VERSION_MISMATCH"), RED) .. "  " .. Colored(AoM.L("LIVE_VERSION") .. live_version, GREEN)
	else
		lines[#lines + 1] = Colored(AoM.L("VERSION") .. live_version, GREEN)
	end

	if installed <= 0 then
		lines[#lines + 1] = Colored("No AddOnVersion", GOLD)
	elseif mismatch then
		lines[#lines + 1] = Colored(AoM.L("ADDONVERSION") .. installed, RED)
			.. "  " .. Colored(AoM.L("LIVE_ADDONVERSION") .. live_addon_version, GREEN)
	elseif live_addon_version then
		lines[#lines + 1] = Colored(AoM.L("ADDONVERSION") .. installed, GREEN)
	else
		lines[#lines + 1] = AoM.L("ADDONVERSION") .. installed
	end

	local other = status.other_entry
	local differs = other ~= nil and (other.requiredVersion ~= live_addon_version
		or (other.displayVersion ~= nil and other.displayVersion ~= live_version))
	if differs and other.requiredVersion then
		local label = status.known_is_console and "PC (ESOUI)" or "Console (Bethesda.net)"
		local shown = other.displayVersion or tostring(other.requiredVersion)
		local text
		if other.requiredVersion ~= live_addon_version and other.displayVersion then
			text = string.format("%s: v%s (%d)", label, shown, other.requiredVersion)
		else
			text = string.format("%s: v%s", label, shown)
		end
		lines[#lines + 1] = Colored(text, GOLD)
	end

	return lines, status
end

function AoM.GetApiLine(status)
	if status.api_out_of_date or status.api_invalid then
		return Colored(AoM.L("CURRENT_API") .. (status.declared_api or AoM.L("NOT_IN_THE_DATA_TABLES")), RED)
			.. "  " .. Colored(AoM.L("LIVE_API") .. status.live_api, GREEN)
	end
	return Colored(AoM.L("API") .. status.live_api .. AoM.L("UP_TO_DATE"), GREEN)
end

function AoM.PopulateAddonInfoTooltip(tooltip, data)
	local am = GetAddOnManager()

	AddTitleLine(tooltip, data.addOnName)
	if data.index then
		local lines, status = AoM.GetVersionLines(am, data.index, data.addOnFileName, data.isOutOfDate)
		for _, line in ipairs(lines) do
			AddSubTitleLine(tooltip, line)
		end
		if status.api_invalid then
			AddCenterLine(tooltip, Colored(AoM.L("API_VERSION_IS_NOT_VALID"), RED))
		elseif status.api_out_of_date then
			AddCenterLine(tooltip, Colored(AoM.L("API_VERSION_OUT_OF_DATE"), RED))
		end
		AddCenterLine(tooltip, AoM.GetApiLine(status))
	end
	ZO_Tooltip_AddDivider(tooltip)
	if data.addOnAuthorByLine and data.addOnAuthorByLine ~= "" then
		AddSubTitleLine(tooltip, data.addOnAuthorByLine)
	end
	if data.addOnDescription and data.addOnDescription ~= "" then
		AddCenterLine(tooltip, data.addOnDescription)
	end
	if data.index then
		AddCenterLine(tooltip, am:GetAddOnRootDirectoryPath(data.index))
	end
	AddLibrarySections(tooltip, am, data)
end

function AoM.PopulateAddonInfoTooltipByName(tooltip, addonName)
	local am = GetAddOnManager()
	local i = FindAddonIndex(am, addonName)
	if not i then return end
	local name, title, author, description, _, _, isOutOfDate = am:GetAddOnInfo(i)
	AoM.PopulateAddonInfoTooltip(tooltip, {
		addOnFileName = name,
		addOnName = title,
		index = i,
		isOutOfDate = isOutOfDate,
		addOnAuthorByLine = author ~= "" and zo_strformat(SI_ADD_ON_AUTHOR_LINE, author) or "",
		addOnDescription = description,
	})
end

local STATUS_COLOR_ERROR = { 1, 0.15, 0.15 }
local STATUS_COLOR_OUT_OF_DATE = { 1, 0.82, 0.1 }
local STATUS_COLOR_DEPENDENCY_ERROR = { 1, 0.55, 0.1 }
local STATUS_COLOR_OPTIONAL_DEPENDENCY = { 0.4, 0.75, 1 }
local STATUS_COLOR_USED_AS_DEPENDENCY = { 0.7, 0.5, 1 }
local STATUS_COLOR_PATCH_ADDON = { 0.3, 0.9, 0.3 }
local STATUS_COLOR_SAVED_VARIABLES = { 0.72, 0.72, 0.72 }

local STATUS_TEXTURE = {
	[STATUS_COLOR_OUT_OF_DATE] = "/esoui/art/addons/gamepad/gp_addon_out_of_date.dds",
	[STATUS_COLOR_DEPENDENCY_ERROR] = "/esoui/art/addons/gamepad/gp_addon_dependencies.dds",
	[STATUS_COLOR_OPTIONAL_DEPENDENCY] = "/esoui/art/addons/gamepad/gp_mod_listing_category_infoandpluginbars.dds",
	[STATUS_COLOR_USED_AS_DEPENDENCY] = "/esoui/art/addons/gamepad/gp_addon_dependencies_white.dds",
	[STATUS_COLOR_SAVED_VARIABLES] = "/esoui/art/tutorial/tutorial_reconstruct_tabicon_up.dds",
}

local TIME_SYNC_ERROR_CODES = { [0x32BBA739] = true, [0xEA5D75AD] = true }
local error_logger = LibAPH.CreateChatLogger("AoM", "9CD04C")
local ERROR_CSA_LIFESPAN_MS = 10000

local OWNER_CACHE_MAX = 200
local error_roots, error_roots_count = {}, -1
local owner_cache, owner_cache_size = {}, 0

local function ErrorRoots(am)
	local count = am:GetNumAddOns()
	if count == error_roots_count then return error_roots end
	error_roots, error_roots_count = {}, count
	for i = 1, count do
		local root = am:GetAddOnRootDirectoryPath(i)
		if root and root ~= "" then
			local folder = string.match(root, "([^/]+)/?$")
			error_roots[#error_roots + 1] = { root = root, upper = string.upper(root), folder = folder and string.upper(folder), index = i }
		end
	end
	return error_roots
end

local function FindErrorOwner(errorString)
	local upper = string.upper(errorString)
	local roots = ErrorRoots(GetAddOnManager())
	local best, best_at
	for _, entry in ipairs(roots) do
		local at = string.find(upper, entry.upper, 1, true)
		if at and (not best_at or at < best_at or (at == best_at and #entry.upper > #best.upper)) then best, best_at = entry, at end
	end
	if best then return best end
	local folder = string.match(errorString, "[Aa][Dd][Dd][Oo][Nn][Ss]/([^/]+)/")
	if not folder then return nil end
	local wanted = string.upper(folder)
	for _, entry in ipairs(roots) do
		if entry.folder == wanted then return entry end
	end
	return { folder = folder, key = "folder:" .. wanted }
end

local function ErrorOwnerTitle(owner)
	if not owner.index then return owner.folder end
	local name, title = GetAddOnManager():GetAddOnInfo(owner.index)
	local clean = string.gsub(string.gsub(title or "", "|c%x%x%x%x%x%x", ""), "|r", "")
	return clean ~= "" and clean or name or owner.folder
end

local function ErrorOwner(errorString)
	local cached = owner_cache[errorString]
	if cached ~= nil then return cached or nil end
	local owner = FindErrorOwner(errorString)
	if owner_cache_size >= OWNER_CACHE_MAX then owner_cache, owner_cache_size = {}, 0 end
	owner_cache[errorString], owner_cache_size = owner or false, owner_cache_size + 1
	return owner
end

local notified_error_roots = {}
local function NotifyCapturedError(owner)
	local title = ErrorOwnerTitle(owner)
	local hint
	local key = owner.root or owner.key
	if notified_error_roots[key] then
		hint = AoM.L("ANOTHER_ERROR_ON_TOP_OF_THE")
	else
		hint = AoM.L("OPEN_THE_ADD_ONS_LIST_AND")
	end
	notified_error_roots[key] = true
	LibAPH.SafeCSA(true, AoM.L("LUA_ERROR") .. title .. "|r", "|cFFD700" .. hint .. "|r", ERROR_CSA_LIFESPAN_MS)
	error_logger:Print("|cFF0000Lua error:|r |c66CCFF" .. title .. "|r |cFFD700" .. hint .. "|r")
end
local captured_lua_errors = {}

EVENT_MANAGER:RegisterForEvent("AoM_AddonManagerErrorCapture", EVENT_LUA_ERROR, function(_, errorString, errorCode)
	if type(errorString) ~= "string" then return end
	if TIME_SYNC_ERROR_CODES[errorCode] then return end
	local owner = ErrorOwner(errorString)
	if not owner then return end
	local is_new = LibAPH.RecordCapturedBug(captured_lua_errors, errorString, 100)
	for _, bug in ipairs(captured_lua_errors) do
		if bug.text == errorString then
			bug.code = bug.code or errorCode
			bug.root = bug.root or owner.root or false
			break
		end
	end
	if is_new then NotifyCapturedError(owner) end
end)

local native_error_passthrough = false
local early_errors = {}
local EARLY_ERRORS_MAX = 20

function AoM.IsSuppressingLuaErrors()
	return AoM.saved == nil or AoM.saved.suppress_lua_errors ~= false
end

function AoM.SetSuppressingLuaErrors(enabled)
	if AoM.saved then AoM.saved.suppress_lua_errors = enabled end
end

if ZO_ERROR_FRAME then
	ZO_PreHook(ZO_ERROR_FRAME, "OnUIError", function(_, errorString, errorCode)
		if native_error_passthrough or TIME_SYNC_ERROR_CODES[errorCode] then return false end
		if type(errorString) ~= "string" or not ErrorOwner(errorString) then return false end
		if AoM.saved == nil then
			if #early_errors < EARLY_ERRORS_MAX then early_errors[#early_errors + 1] = { text = errorString, code = errorCode } end
			return true
		end
		return AoM.IsSuppressingLuaErrors()
	end)
end

function AoM.ReplayEarlyErrors()
	local held = early_errors
	early_errors = {}
	if #held == 0 or AoM.IsSuppressingLuaErrors() or not ZO_ERROR_FRAME then return 0 end
	native_error_passthrough = true
	local ok = pcall(function()
		for _, bug in ipairs(held) do ZO_ERROR_FRAME:OnUIError(bug.text, bug.code) end
	end)
	native_error_passthrough = false
	return ok and #held or 0
end

local function GetCapturedErrorsForPath(root_path)
	local matches = {}
	if not root_path or root_path == "" then return matches end
	for _, bug in ipairs(captured_lua_errors) do
		if bug.root == root_path then
			table.insert(matches, bug)
		end
	end
	return matches
end

local function GetLatestError(bugs)
	local latest = bugs[1]
	for _, bug in ipairs(bugs) do
		if bug.lastSeen > latest.lastSeen then latest = bug end
	end
	return latest
end

local function ClearCapturedErrorsForPath(root_path)
	if root_path == nil then
		ZO_ClearTable(notified_error_roots)
	else
		notified_error_roots[root_path] = nil
	end
	for i = #captured_lua_errors, 1, -1 do
		if root_path == nil or captured_lua_errors[i].root == root_path then
			table.remove(captured_lua_errors, i)
		end
	end
	if ADD_ON_MANAGER and ADDONS_FRAGMENT and ADDONS_FRAGMENT:IsShowing() then ADD_ON_MANAGER:RefreshData() end
end

local addon_dependents = {}
local addon_patch_targets = {}

local dependency_index_built = false

local function RebuildDependencyIndex()
	dependency_index_built = true
	addon_dependents = {}
	addon_patch_targets = {}
	local am = GetAddOnManager()
	for i = 1, am:GetNumAddOns() do
		local name = am:GetAddOnInfo(i)
		local non_library_deps = {}
		for d = 1, am:GetAddOnNumDependencies(i) do
			local dep_name = am:GetAddOnDependencyInfo(i, d)
			if dep_name then
				addon_dependents[dep_name] = addon_dependents[dep_name] or {}
				table.insert(addon_dependents[dep_name], name)
				if not LibAPH.IsLibraryAddonByName(am, dep_name) then
					table.insert(non_library_deps, dep_name)
				end
			end
		end
		if #non_library_deps > 0 then addon_patch_targets[name] = non_library_deps end
	end
end

local function IsPatchAddon(name, title)
	if SuggestedCategories and SuggestedCategories[name] == PATCH_CATEGORY then return true end
	local text = string.lower(name .. " " .. (title or ""))
	return string.find(text, "patch", 1, true) ~= nil or string.find(text, "fix", 1, true) ~= nil
end

function AoM.GetCapturedErrorCountForAddon(am, index)
	return #GetCapturedErrorsForPath(am:GetAddOnRootDirectoryPath(index))
end

function AoM.ClearCapturedErrorsForAddon(am, index)
	local root_path = am:GetAddOnRootDirectoryPath(index)
	if not root_path or root_path == "" then return end
	ClearCapturedErrorsForPath(root_path)
end

function AoM.ShowNativeErrorsForAddon(am, index)
	local bugs = GetCapturedErrorsForPath(am:GetAddOnRootDirectoryPath(index))
	if #bugs == 0 or not ZO_ERROR_FRAME then return false end
	native_error_passthrough = true
	local ok = pcall(function()
		local suppressed = ZO_ERROR_FRAME.suppressedErrors
		for _, bug in ipairs(bugs) do
			if suppressed then suppressed[bug.code or 0] = nil end
			ZO_ERROR_FRAME:OnUIError(bug.text, bug.code or 0)
		end
	end)
	native_error_passthrough = false
	if not ok then error_logger:Print("Could not open the game's error window.") end
	return ok
end

function AoM.HasAddonError(am, index)
	if not index then return false end
	local addon_state = select(6, am:GetAddOnInfo(index))
	if addon_state == ADDON_STATE_ERROR_STATE_UNABLE_TO_LOAD then return true end
	return #GetCapturedErrorsForPath(am:GetAddOnRootDirectoryPath(index)) > 0
end

function AoM.GetCapturedErrorTotal()
	return #captured_lua_errors
end

function AoM.ClearAllCapturedErrors()
	ClearCapturedErrorsForPath(nil)
end

local error_box
local error_box_name, error_box_path

local function ShowAddonErrors(name, root_path)
	error_box_name, error_box_path = name, root_path
	error_box = error_box or LibAPH.CreateCopyTextBox({
		name = "AoMAddonErrorBox",
		titleText = LibAPH.BUG_REPORT_TITLE,
		pastebin = true,
		sections = true,
		maxInputChars = LibAPH.BUG_REPORT_MAX_CHARS,
		dismissBug = { text = AoM.L("DISMISS_BUG"), onClick = function()
			ClearCapturedErrorsForPath(error_box_path)
			ShowAddonErrors(error_box_name, error_box_path)
		end },
		wipeAllBugs = { text = AoM.L("WIPE_ALL_BUGS"), onClick = function()
			ClearCapturedErrorsForPath(nil)
			error_box:Hide()
		end },
	})
	local bugs = GetCapturedErrorsForPath(root_path)
	local error_section
	if #bugs > 0 then
		error_section = LibAPH.FormatCapturedBugBlocks(name, bugs)
	else
		error_section = AoM.L("NO_LUA_ERRORS_FROM") .. name .. AoM.L("WERE_CAPTURED_THIS_SESSION")
	end
	local addons, libraries = LibAPH.BuildEnabledAddonsReport()
	error_box:ShowReport({
		pastebin = LibAPH.PASTEBIN_MESSAGE,
		errors = error_section,
		platform = AoM.L("PLATFORM") .. tostring(LibAPH.GetPlatformString() or "unknown"),
		language = AoM.L("CURRENT_LANGUAGE") .. tostring(GetCVar("Language.2")),
		live_api = LibAPH.GetLiveApiLine(),
		addons = addons,
		libraries = libraries,
	}, #bugs > 0)
end

local function GetDependencyIssues(am, index)
	local disabled, missing, outdated, disabled_names = {}, {}, {}, {}
	for d = 1, am:GetAddOnNumDependencies(index) do
		local dep_name, dep_exists, dep_active, dep_min_version, dep_version = am:GetAddOnDependencyInfo(index, d)
		local formatted = FormatLibraryStatus(am, dep_name, dep_min_version, true)
		if not dep_exists then
			table.insert(missing, formatted)
		elseif not dep_active then
			table.insert(disabled, formatted)
			table.insert(disabled_names, dep_name)
		elseif dep_version < dep_min_version then
			table.insert(outdated, formatted)
		end
	end
	return disabled, missing, outdated, disabled_names
end

local function DependencySection(header, names, single_action, multiple_action)
	if #names == 0 then return nil end
	return header .. "\n" .. table.concat(names, "\n") .. "\n\n" .. (#names > 1 and multiple_action or single_action)
end

function BuildDependencyTooltip(am, index)
	local disabled, missing, outdated, disabled_names = GetDependencyIssues(am, index)
	local sections = {}
	sections[#sections + 1] = DependencySection("Disabled required dependency:", disabled,
		AoM.L("ENABLE_THE_DISABLED_DEPENDENCY"), AoM.L("ENABLE_THE_DISABLED_DEPENDENCIES"))
	sections[#sections + 1] = DependencySection("Missing required dependency:", missing,
		AoM.L("DOWNLOAD_THE_MISSING_DEPENDENCY"), AoM.L("DOWNLOAD_THE_MISSING_DEPENDENCIES"))
	sections[#sections + 1] = DependencySection("Out of date required dependency:", outdated,
		AoM.L("UPDATE_THE_DEPENDENCY"), AoM.L("UPDATE_THE_DEPENDENCIES"))
	if #sections == 0 then return nil end
	return table.concat(sections, "\n\n"), disabled_names
end

local function GetInactiveOptionalLibs(am, addonName)
	local inactive, names = {}, {}
	for _, lib_name in ipairs(GetOptionalLibsFor(addonName)) do
		if not LibAPH.IsAddonActiveAndRunning(lib_name) then
			table.insert(inactive, FormatLibraryStatus(am, lib_name, nil, true))
			table.insert(names, lib_name)
		end
	end
	return inactive, names
end

local function IsGamepadInput()
	return IsConsoleUI() or IsInGamepadPreferredMode()
end

local KnownConsoleLibraries = AoM.KnownConsoleLibraries or {}

function AoM.IsLibraryName(am, addonName)
	if LibAPH.IsLibraryAddonByName(am, addonName) then return true end
	return KnownConsoleLibraries[addonName] ~= nil
end

function GetAddonWord(am, addonName)
	return AoM.IsLibraryName(am, addonName) and "library" or "add-on"
end

function AoM.GetPlatformAvailability(addonName)
	local on_console = KnownConsoleAddons[addonName] ~= nil
	local pc_entry = KnownLibraries[addonName] or KnownAddonVersions[addonName]
	local on_pc = (pc_entry ~= nil and pc_entry.esouiId ~= nil)
		or (SuggestedCategories and SuggestedCategories[addonName] ~= nil)
	if on_console and not on_pc then return "console" end
	if on_pc and not on_console then return "pc" end
	if on_pc and on_console then return "both" end
	return "unknown"
end

local function GetUpdateHint(am, addonName)
	local availability = AoM.GetPlatformAvailability(addonName)
	local word = GetAddonWord(am, addonName)

	if availability == "unknown" then
		return AoM.L("THIS") .. word .. AoM.L("IS_IN_NEITHER_DATA_TABLE_CHECK")
	end

	if IsConsoleUI() then
		if availability == "pc" then
			return AoM.L("THIS_IS_PC_ONLY") .. word .. AoM.L("CHECK_ESOUI_FOR_NEW_UPDATE")
		end
		return AoM.L("PLEASE_CHECK_FOR_AN_UPDATE")
	end

	if availability == "console" then
		return AoM.L("THIS_IS_CONSOLE_ONLY") .. word .. AoM.L("CHECK_MODS_BETHESDA_NET_FOR_NEW")
	end
	return AoM.L("RUN_MINION_AND_CHECK_FOR_AN")
end

local function GetInvalidApiHint(am, addonName)
	local availability = AoM.GetPlatformAvailability(addonName)
	local word = GetAddonWord(am, addonName)

	if availability == "unknown" then
		return AoM.L("THIS") .. word .. AoM.L("IS_IN_NEITHER_DATA_TABLE_CHECK_2")
	end

	if IsConsoleUI() then
		if availability == "pc" then
			return AoM.L("THIS_IS_PC_ONLY") .. word .. AoM.L("CHECK_ESOUI_FOR_A_VALID_BUILD")
		end
		return AoM.L("PLEASE_CHECK_FOR_A_VALID_BUILD")
	end

	if availability == "console" then
		return AoM.L("THIS_IS_CONSOLE_ONLY") .. word .. AoM.L("CHECK_MODS_BETHESDA_NET_FOR_A")
	end
	return AoM.L("CHECK_ESOUI_FOR_A_VALID_BUILD_2")
end

local function HighestApiVersion(declared)
	local highest = 0
	for token in string.gmatch(declared, "%d+") do
		local value = tonumber(token)
		if value and value > highest then highest = value end
	end
	return highest
end

local function HasUsableDetails(entry)
	if type(entry) ~= "table" then return false end
	return entry.requiredVersion ~= nil or entry.apiVersion ~= nil or entry.displayVersion ~= nil
end

function AoM.GetDataPlatform(name)
	local console_entry = KnownConsoleLibraries[name] or KnownConsoleAddons[name]
	local pc_entry = KnownLibraries[name] or KnownAddonVersions[name]
	if IsConsoleUI() then
		if HasUsableDetails(console_entry) then return "console" end
		return "pc"
	end
	if HasUsableDetails(pc_entry) then return "pc" end
	if HasUsableDetails(console_entry) then return "console" end
	return "pc"
end

function AoM.GetKnownEntriesByPlatform(name)
	local console_entry = KnownConsoleLibraries[name] or KnownConsoleAddons[name]
	local pc_entry = KnownLibraries[name] or KnownAddonVersions[name]
	if AoM.GetDataPlatform(name) == "console" then
		return console_entry, pc_entry, true
	end
	return pc_entry, console_entry, false
end

function GetUpdateStatus(am, index, name, is_out_of_date)
	local known, other_entry, known_is_console = AoM.GetKnownEntriesByPlatform(name)
	local console_known = known_is_console and known or nil
	local console_entry = KnownConsoleLibraries[name] or KnownConsoleAddons[name]
	local console_only = AoM.GetPlatformAvailability(name) == "console"
	local installed = am:GetAddOnVersion(index)
	local live_api = GetAPIVersion()
	local declared_api = known and known.apiVersion
	local highest_api = declared_api and HighestApiVersion(declared_api) or nil
	local api_invalid = highest_api ~= nil and highest_api > live_api + 1
	local api_out_of_date
	if not highest_api then
		api_out_of_date = is_out_of_date
	elseif api_invalid or highest_api > live_api then
		api_out_of_date = false
	else
		api_out_of_date = is_out_of_date or highest_api < live_api
	end
	local installed_version
	if installed > 0 then
		if known and known.requiredVersion == installed then
			installed_version = known.displayVersion
		elseif other_entry and other_entry.requiredVersion == installed then
			installed_version = other_entry.displayVersion
		end
	end

	return {
		known = known,
		installed_version = installed_version,
		console_known = console_known,
		console_entry = console_entry,
		console_only = console_only,
		known_is_console = known_is_console,
		other_entry = other_entry,
		installed = installed,
		newer_on_esoui = known and known.requiredVersion and installed > 0 and installed < known.requiredVersion or false,
		live_api = live_api,
		declared_api = declared_api,
		api_out_of_date = api_out_of_date or false,
		api_invalid = api_invalid or false,
	}
end

local function EsouiPageUrl(known)
	if known and known.esouiId then
		return "https://www.esoui.com/downloads/info" .. known.esouiId
	end
	return nil
end

function AoM.GetBethesdaPageUrl(addonName)
	local entry = KnownConsoleAddons[addonName]
	if not entry or not entry.addonId then return nil end
	local title = string.gsub(entry.title or addonName, "%s+", "_")
	return "https://mods.bethesda.net/en/elderscrollsonline/details/" .. entry.addonId .. "/" .. title
end

local function IsEnabledIndex(am, index)
	local _, _, _, _, enabled = am:GetAddOnInfo(index)
	return enabled
end

local function ListedToggle(am, names, can_disable)
	local info = GetAddonInfoCache(am)
	local listed, off = {}, {}
	for _, name in ipairs(names or {}) do
		local entry = info[name]
		if entry then
			listed[#listed + 1] = entry.index
			if not IsEnabledIndex(am, entry.index) then off[#off + 1] = entry.index end
		end
	end
	if #off > 0 then return { enable = true, indexes = off } end
	if can_disable and #listed > 0 then return { enable = false, indexes = listed } end
	return nil
end

local function ToggleHint(am, toggle)
	if #toggle.indexes == 1 then
		local name = am:GetAddOnInfo(toggle.indexes[1])
		return string.format(AoM.L(toggle.enable and "CLICK_THE_ICON_TO_ENABLE_ONE" or "CLICK_THE_ICON_TO_DISABLE_ONE"), name)
	end
	return string.format(AoM.L(toggle.enable and "CLICK_THE_ICON_TO_ENABLE_MANY" or "CLICK_THE_ICON_TO_DISABLE_MANY"), #toggle.indexes)
end

local function ApplyToggle(am, toggle)
	for _, index in ipairs(toggle.indexes) do
		if toggle.enable then
			AoM.EnableAddonWithDependencies(index)
		elseif IsEnabledIndex(am, index) then
			am:SetAddOnEnabled(index, false)
		end
	end
	if ADD_ON_MANAGER then ADD_ON_MANAGER.isDirty = true end
	if not IsGamepadInput() then ClearTooltip(InformationTooltip) end
	if AoM.RefreshAllCategoryUI then
		AoM.RefreshAllCategoryUI()
	elseif ADD_ON_MANAGER then
		ADD_ON_MANAGER:RefreshData()
	end
end

function AoM.GetStatusIconsForAddon(am, index)
	if not dependency_index_built then RebuildDependencyIndex() end
	local name, title, _, _, _, addon_state, is_out_of_date = am:GetAddOnInfo(index)
	local word = GetAddonWord(am, name)
	local update_hint = GetUpdateHint(am, name)
	local icons = {}
	local function Add(color, tooltipText, onClick, kind, onRightClick)
		table.insert(icons, { color = color, texture = STATUS_TEXTURE[color], tooltip = tooltipText,
			onClick = onClick, kind = kind, onRightClick = onRightClick })
	end
	local function AddToggle(color, tooltipText, names, can_disable)
		local toggle = ListedToggle(am, names, can_disable)
		if not toggle then
			Add(color, tooltipText)
			return
		end
		if not IsGamepadInput() then tooltipText = tooltipText .. "\n\n" .. ToggleHint(am, toggle) end
		Add(color, tooltipText, function() ApplyToggle(am, toggle) end, "toggle")
		icons[#icons].action_name = AoM.L(toggle.enable and "ENABLE" or "DISABLE")
	end

	if addon_state == ADDON_STATE_ERROR_STATE_UNABLE_TO_LOAD then
		Add(STATUS_COLOR_ERROR, AoM.L("THIS") .. word .. AoM.L("FAILED_TO_LOAD_THE_GAME_REPORTS"))
	else
		local root_path = am:GetAddOnRootDirectoryPath(index)
		local session_errors = GetCapturedErrorsForPath(root_path)
		if #session_errors > 0 then
			local latest = GetLatestError(session_errors)
			local text = AoM.L("THIS") .. word .. AoM.L("THREW_A_LUA_ERROR_THIS_SESSION") .. latest.text
			if IsGamepadInput() then
				local first_line = (string.gsub(string.match(latest.text, "^[^\n]*"), "^[Uu][Ss][Ee][Rr]:/[Aa][Dd][Dd][Oo][Nn][Ss]/", ""))
				local gamepad_text = string.format(AoM.L("LUA_ERROR_THIS_SESSION_FIRED"), first_line, latest.count, latest.count == 1 and "time" or "times")
				if #session_errors > 1 then
					gamepad_text = gamepad_text .. string.format(AoM.L("N_OTHER_ERROR_CAPTURED_TOO"), #session_errors - 1, #session_errors == 2 and "" or "s")
				end
				Add(STATUS_COLOR_ERROR, gamepad_text, nil, "error")
			else
				Add(STATUS_COLOR_ERROR, text .. AoM.L("N_NCLICK_THE_ICON_TO_COPY"),
					function() ShowAddonErrors(name, root_path) end, "error", function() AoM.ShowNativeErrorsForAddon(am, index) end)
			end
		end
	end

	local status = GetUpdateStatus(am, index, name, is_out_of_date)
	local known, installed, newer_on_esoui = status.known, status.installed, status.newer_on_esoui
	local live_api, declared_api, api_out_of_date = status.live_api, status.declared_api, status.api_out_of_date
	local api_invalid = status.api_invalid

	if newer_on_esoui or api_out_of_date or api_invalid then
		local on_pc = not IsGamepadInput()
		local console_known = status.console_known
		local console_source = status.console_entry ~= nil and (console_known ~= nil or status.console_only)
		local page_url = EsouiPageUrl(known)
		local page_line = (on_pc and page_url) and ("esoui.com/downloads/info" .. known.esouiId) or nil
		local source = console_known and "Bethesda.net" or "ESOUI"
		local lines = {}
		if newer_on_esoui then
			table.insert(lines, AoM.L("VERSION_MISMATCH"))
			if page_line then table.insert(lines, page_line) end
			table.insert(lines, string.format("%s: v%s (%d)", source, known.displayVersion or tostring(known.requiredVersion), known.requiredVersion))
			table.insert(lines, string.format(AoM.L("INSTALLED"), installed))
		end
		if api_invalid or api_out_of_date then
			if #lines > 0 then table.insert(lines, "") end
			table.insert(lines, api_invalid and AoM.L("API_VERSION_IS_NOT_VALID") or AoM.L("API_VERSION_OUT_OF_DATE"))
			if page_line then table.insert(lines, page_line) end
			table.insert(lines, AoM.L("CURRENT_API") .. (declared_api or AoM.L("NOT_IN_THE_DATA_TABLES")))
			table.insert(lines, AoM.L("LIVE_API") .. tostring(live_api))
		end
		table.insert(lines, "")
		table.insert(lines, (api_invalid and not newer_on_esoui) and GetInvalidApiHint(am, name) or update_hint)
		local on_click
		if on_pc and page_url then
			table.insert(lines, AoM.L("CLICK_THE_ICON_TO_OPEN_THE"))
			on_click = function() RequestOpenUnsafeURL(page_url) end
		end
		if console_source then
			local console_listing = status.console_known or status.console_entry
			if IsConsoleUI() then
				table.insert(lines, string.format(AoM.L("UPDATE_IT_IN_OPTIONS_ADDONS_BROWSE"), console_listing.title or name))
			else
				local bethesda_url = AoM.GetBethesdaPageUrl(name)
				if bethesda_url and not on_click then
					table.insert(lines, AoM.L("CLICK_THE_ICON_TO_OPEN_THE_2"))
					on_click = function() RequestOpenUnsafeURL(bethesda_url) end
				end
			end
		end
		Add(STATUS_COLOR_OUT_OF_DATE, table.concat(lines, "\n"), on_click, console_source and "update" or nil)
	end

	local dependency_text, disabled_names = BuildDependencyTooltip(am, index)
	if dependency_text then
		AddToggle(STATUS_COLOR_DEPENDENCY_ERROR, dependency_text, disabled_names, false)
	end

	local inactive_optional, inactive_names = GetInactiveOptionalLibs(am, name)
	if #inactive_optional > 0 then
		AddToggle(STATUS_COLOR_OPTIONAL_DEPENDENCY, AoM.L("HAS_AN_OPTIONAL_DEPENDENCY_FOR_ADDITIONAL") .. table.concat(inactive_optional, ", "), inactive_names, true)
	end

	local dependents = addon_dependents[name]
	if dependents and #dependents > 0 then
		local formatted_dependents = {}
		for _, dependent_name in ipairs(dependents) do
			table.insert(formatted_dependents, FormatLibraryStatus(am, dependent_name, nil, true))
		end
		AddToggle(STATUS_COLOR_USED_AS_DEPENDENCY, AoM.L("USED_AS_A_DEPENDENCY_BY_N") .. table.concat(formatted_dependents, ", "), dependents, true)
	end

	local patch_targets = addon_patch_targets[name]
	if patch_targets then
		local formatted_targets = {}
		local all_libraries = true
		for _, target_name in ipairs(patch_targets) do
			table.insert(formatted_targets, FormatLibraryStatus(am, target_name, nil, true))
			if not AoM.IsLibraryName(am, target_name) then all_libraries = false end
		end
		local label = IsPatchAddon(name, title) and "Optional Patch" or (word == "library" and "Optional Library" or "Optional Addon")
		local target_word
		if all_libraries then
			target_word = #formatted_targets > 1 and "libraries" or "library"
		else
			target_word = #formatted_targets > 1 and "add-ons" or "add-on"
		end
		AddToggle(STATUS_COLOR_PATCH_ADDON, label .. AoM.L("FOR_THE_FOLLOWING") .. target_word .. ":\n" .. table.concat(formatted_targets, ", "), patch_targets, false)
	end

	local saved_usage = AoM.GetSavedVariablesUsageMB and AoM.GetSavedVariablesUsageMB(index)
	if saved_usage then
		local display_name = LibAPH.StripColors(title or name)
		local lines = { AoM.L("SETTINGS_SAVED_ON_DISK") .. AoM.FormatSavedVariablesUsage(saved_usage) .. "." }
		local on_click
		if not IsGamepadInput() then
			table.insert(lines, AoM.L("CLICK_THE_ICON_TO_DELETE_THIS") .. word .. AoM.L("S_SAVED_VARIABLES"))
			on_click = function() AoM.ConfirmDeleteSavedVariables(index, display_name) end
		end
		Add(STATUS_COLOR_SAVED_VARIABLES, table.concat(lines, "\n"), on_click, "savedvariables")
	end

	return icons
end

function AoM.GetStatusIconsForAddonByName(am, addonName)
	local i = FindAddonIndex(am, addonName)
	if i then return AoM.GetStatusIconsForAddon(am, i) end
	return {}
end
