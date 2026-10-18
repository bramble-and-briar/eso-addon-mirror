--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(APHOnManagerCore, "APH-OnManager.lua must be loaded before this file")
local AoM = APHOnManagerCore
local PrintDisabledUnusedReport
assert(AoM.KnownLibraries, "KnownLibraries.lua must be loaded before this file")
assert(AoM.KnownAddonDependencies, "KnownAddonDependencies.lua must be loaded before this file")
local LibAPH = LibAPH
local KnownLibraries = AoM.KnownLibraries
local KnownAddonDependencies = AoM.KnownAddonDependencies
local KnownConsoleAddonDependencies = AoM.KnownConsoleAddonDependencies or {}
local KnownConsoleLibraries = AoM.KnownConsoleLibraries or {}
local logger = LibAPH.CreateChatLogger("AoM", "9CD04C")

local function GetKnownDependencies(name)
	if AoM.GetDataPlatform(name) == "console" then
		return KnownConsoleAddonDependencies[name] or KnownAddonDependencies[name] or {}
	end
	return KnownAddonDependencies[name] or {}
end
AoM.GetKnownDependencies = GetKnownDependencies

local console_dependency_map

local function GetKnownDependencyMap()
	if not IsConsoleUI() then return KnownAddonDependencies end
	if not console_dependency_map then
		console_dependency_map = {}
		for name, libs in pairs(KnownAddonDependencies) do console_dependency_map[name] = libs end
		for _, name in ipairs(AoM.GetKnownNames(KnownConsoleAddonDependencies)) do
			if AoM.GetDataPlatform(name) == "console" then
				console_dependency_map[name] = KnownConsoleAddonDependencies[name]
			end
		end
	end
	return console_dependency_map
end

local function ScanOptionalLibraries()
	local am = GetAddOnManager()
	local num = am:GetNumAddOns()

	local addon_index_by_name = {}
	local library_addons = {}
	for i = 1, num do
		local name, _, _, _, enabled, _, _, isLibrary = am:GetAddOnInfo(i)
		addon_index_by_name[name] = i
		if isLibrary then
			library_addons[name] = { index = i, version = am:GetAddOnVersion(i), enabled = enabled }
		end
	end

	local referenced = {}
	local addon_dependency_report = {}

	for i = 1, num do
		local name, _, _, _, enabled, state = am:GetAddOnInfo(i)
		if LibAPH.IsAddOnRunningState(enabled, state) then
			local num_deps = am:GetAddOnNumDependencies(i)
			local this_addon_deps = {}
			for d = 1, num_deps do
				local dep_name, exists, active, _, version = am:GetAddOnDependencyInfo(i, d)
				if exists then
					referenced[dep_name] = true
					table.insert(this_addon_deps, { name = dep_name, active = active, version = version })
				end
			end
			if #this_addon_deps > 0 then
				addon_dependency_report[name] = this_addon_deps
			end
		end
	end

	local enable_candidates = {}
	local active_optional_by_lib = {}
	local missing_optional_by_lib = {}

	local function ProcessOptionalDependency(addon_name, lib_name)
		referenced[lib_name] = true
		local lib_idx = addon_index_by_name[lib_name]
		if lib_idx then
			local _, _, _, _, lib_enabled, lib_state = am:GetAddOnInfo(lib_idx)
			if LibAPH.IsAddOnRunningState(lib_enabled, lib_state) then
				active_optional_by_lib[lib_name] = active_optional_by_lib[lib_name]
					or { name = lib_name, version = am:GetAddOnVersion(lib_idx), addons = {} }
				table.insert(active_optional_by_lib[lib_name].addons, addon_name)
			else
				table.insert(enable_candidates, { library = lib_name, forAddon = addon_name })
			end
		else
			missing_optional_by_lib[lib_name] = missing_optional_by_lib[lib_name] or { name = lib_name, addons = {} }
			table.insert(missing_optional_by_lib[lib_name].addons, addon_name)
		end
	end

	for addon_name, decl in pairs(LibAPH.registered_dependencies) do
		for lib_name in pairs(decl.required) do
			referenced[lib_name] = true
		end
		for lib_name in pairs(decl.optional) do
			ProcessOptionalDependency(addon_name, lib_name)
		end
	end

	for addon_name, optional_libs in pairs(GetKnownDependencyMap()) do
		if not LibAPH.registered_dependencies[addon_name] then
			local addon_idx = addon_index_by_name[addon_name]
			if addon_idx then
				local _, _, _, _, addon_enabled, addon_state = am:GetAddOnInfo(addon_idx)
				if LibAPH.IsAddOnRunningState(addon_enabled, addon_state) then
					for _, lib_name in ipairs(optional_libs) do
						ProcessOptionalDependency(addon_name, lib_name)
					end
				end
			end
		end
	end

	local function IsAddonFullyEnabled(idx)
		local _, _, _, _, en, st = am:GetAddOnInfo(idx)
		return LibAPH.IsAddOnRunningState(en, st)
	end

	local potential_required_by, potential_optional_by = {}, {}
	for i = 1, num do
		if not IsAddonFullyEnabled(i) then
			local name = am:GetAddOnInfo(i)
			for d = 1, am:GetAddOnNumDependencies(i) do
				local dep_name, exists = am:GetAddOnDependencyInfo(i, d)
				if exists then
					potential_required_by[dep_name] = potential_required_by[dep_name] or {}
					table.insert(potential_required_by[dep_name], name)
				end
			end
		end
	end
	for addon_name, optional_libs in pairs(GetKnownDependencyMap()) do
		local addon_idx = addon_index_by_name[addon_name]
		if not addon_idx or not IsAddonFullyEnabled(addon_idx) then
			for _, lib_name in ipairs(optional_libs) do
				potential_optional_by[lib_name] = potential_optional_by[lib_name] or {}
				table.insert(potential_optional_by[lib_name], addon_name)
			end
		end
	end

	local unused_libraries = {}
	for lib_name, data in pairs(library_addons) do
		if data.enabled and not referenced[lib_name] then
			table.insert(unused_libraries, {
				name = lib_name, version = data.version, index = data.index,
				potential_required_by = potential_required_by[lib_name],
				potential_optional_by = potential_optional_by[lib_name],
			})
		end
	end

	local broken_addons = {}
	for i = 1, num do
		local name, _, _, _, enabled = am:GetAddOnInfo(i)
		if enabled then
			local missing_deps = {}
			for d = 1, am:GetAddOnNumDependencies(i) do
				local dep_name, exists = am:GetAddOnDependencyInfo(i, d)
				if not exists then
					table.insert(missing_deps, dep_name)
				end
			end
			if #missing_deps > 0 then
				table.insert(broken_addons, { name = name, missing = missing_deps })
			end
		end
	end
	table.sort(broken_addons, function(a, b) return a.name < b.name end)

	local active_optional_libraries = {}
	for _, entry in pairs(active_optional_by_lib) do
		table.insert(active_optional_libraries, entry)
	end
	table.sort(active_optional_libraries, function(a, b) return a.name < b.name end)

	local missing_optional_libraries = {}
	for _, entry in pairs(missing_optional_by_lib) do
		table.insert(missing_optional_libraries, entry)
	end
	table.sort(missing_optional_libraries, function(a, b) return a.name < b.name end)

	return {
		enable_candidates = enable_candidates,
		unused_libraries = unused_libraries,
		active_optional_libraries = active_optional_libraries,
		missing_optional_libraries = missing_optional_libraries,
		broken_addons = broken_addons,
		addon_dependency_report = addon_dependency_report,
		addon_index_by_name = addon_index_by_name,
	}
end

local function ApplyOptionalLibraryChoice(to_enable, to_disable)
	local am = GetAddOnManager()
	local acted = { enabled = {}, disabled = {} }

	for _, e in ipairs(to_enable) do
		am:SetAddOnEnabled(e.index, true)
		table.insert(acted.enabled, e.name)
	end
	for _, u in ipairs(to_disable) do
		am:SetAddOnEnabled(u.index, false)
		table.insert(acted.disabled, { name = u.name, version = u.version })
	end

	AoM.saved.pending_optional_report = acted
	ReloadUI("ingame")
end

local SECTION_HEADER_COLOR = { 0.83, 0.92, 0.42, 1 }
local ITEM_COLOR = { 0.85, 0.85, 0.85, 1 }
local MISSING_COLOR = { 0.53, 0.53, 0.53, 1 }
local UNUSED_COLOR = { 1, 0.3, 0.3, 1 }
local ENABLE_CANDIDATE_COLOR = { 1, 0.65, 0.2, 1 }
local BROKEN_COLOR = { 1, 0.3, 0.3, 1 }

local function BuildUnusedTooltip(u)
	local parts = {}
	if u.potential_required_by then
		table.insert(parts, "Required by (disabled):\n" .. table.concat(u.potential_required_by, "\n"))
	end
	if u.potential_optional_by then
		table.insert(parts, AoM.L("OPTIONAL_FOR_DISABLED_N") .. table.concat(u.potential_optional_by, "\n"))
	end
	if #parts == 0 then
		return AoM.L("NOT_WANTED_BY_ANY_INSTALLED_ADD")
	end
	return table.concat(parts, "\n\n") .. AoM.L("N_N_ALL_DISABLED_THAT_S")
end

local function ColorAddonNameList(report, addons)
	local am = GetAddOnManager()
	local colored = {}
	for _, name in ipairs(addons) do
		local idx = report.addon_index_by_name[name]
		local enabled, state
		if idx then
			local _, _, _, _, e, s = am:GetAddOnInfo(idx)
			enabled, state = e, s
		end
		if LibAPH.IsAddOnRunningState(enabled, state) then
			table.insert(colored, "|c00FF00" .. name .. "|r")
		else
			table.insert(colored, "|cFF0000" .. name .. "|r")
		end
	end
	return table.concat(colored, "\n")
end

local function GroupByLibrary(entries, getLibName, getAddonName)
	local grouped = {}
	for _, e in ipairs(entries) do
		local lib_name = getLibName(e)
		grouped[lib_name] = grouped[lib_name] or { name = lib_name, addons = {} }
		table.insert(grouped[lib_name].addons, getAddonName(e))
	end
	local list = {}
	for _, g in pairs(grouped) do table.insert(list, g) end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end

local optional_library_window

local function GetOptionalLibraryWindow()
	if optional_library_window then return optional_library_window end
	optional_library_window = LibAPH.CreateScrollListWindow({
		name = "AoM_OptionalLibraryWindow",
		widthPct = 0.36, heightPct = 0.6,
		minWidth = 580, maxWidth = 950,
		minHeight = 460, maxHeight = 860,
		footerHeight = 44,
		titleText = AoM.L("APH_ON_MANAGER_LIBRARY_MANAGER"),
		countsInFooter = true,
	})

	optional_library_window.check_all_btn = LibAPH.CreateKeybindLabelButton(optional_library_window.footer, {
		action = "AOM_SELECT_ALL_LIBRARIES",
		layer = AoM.LIBRARIES_KEYBIND_LAYER,
		name = AoM.L("SELECT_ALL"),
	})
	optional_library_window.check_all_btn:SetAnchor(TOPLEFT, optional_library_window.footer, TOPLEFT, 0, 0)

	optional_library_window.uncheck_all_btn = LibAPH.CreateKeybindLabelButton(optional_library_window.footer, {
		action = "AOM_DESELECT_ALL_LIBRARIES",
		layer = AoM.LIBRARIES_KEYBIND_LAYER,
		name = AoM.L("DESELECT_ALL"),
	})
	optional_library_window.uncheck_all_btn:SetAnchor(TOPLEFT, optional_library_window.check_all_btn, TOPRIGHT, 20, 0)

	optional_library_window.apply_btn = LibAPH.CreateKeybindLabelButton(optional_library_window.footer, {
		action = "AOM_APPLY_LIBRARY_CHANGES",
		layer = AoM.LIBRARIES_KEYBIND_LAYER,
		name = AoM.L("APPLY_CHANGES"),
	})
	optional_library_window.apply_btn:SetAnchor(TOPLEFT, optional_library_window.uncheck_all_btn, TOPRIGHT, 20, 0)

	optional_library_window:FitButtons()
	return optional_library_window
end

local function RunOptionalLibraryWizard()
	local report = ScanOptionalLibraries()

	if #report.enable_candidates == 0 and #report.unused_libraries == 0 then
		if optional_library_window then optional_library_window:Hide() end
		if #report.active_optional_libraries > 0 or #report.missing_optional_libraries > 0 or #report.broken_addons > 0 then
			logger:Print("Nothing to enable or clean up.")
			if #report.active_optional_libraries > 0 then
				logger:Print("Enabled optional libraries currently in use:")
				for _, lib in ipairs(report.active_optional_libraries) do
					logger:Print("  " .. lib.name .. LibAPH.FormatVersionParen(lib.version) .. " - used by " .. table.concat(lib.addons, ", "))
				end
			end
			if #report.missing_optional_libraries > 0 then
				logger:Print("Not installed, but could be used by:")
				for _, lib in ipairs(report.missing_optional_libraries) do
					logger:Print("  " .. lib.name .. " - wanted by " .. table.concat(lib.addons, ", "))
				end
			end
			if #report.broken_addons > 0 then
				logger:Print("Enabled but missing a required library - won't load until installed:")
				for _, a in ipairs(report.broken_addons) do
					logger:Print("  " .. a.name .. " - needs " .. table.concat(a.missing, ", "))
				end
			end
		else
			d(AoM.L("AOM_NO_OPTIONAL_LIBRARIES_TO_OFFER"))
		end
		return
	end

	local enable_list = GroupByLibrary(report.enable_candidates, function(c) return c.library end, function(c) return c.forAddon end)
	local unused_list = {}
	for _, u in ipairs(report.unused_libraries) do table.insert(unused_list, u) end
	table.sort(unused_list, function(a, b) return a.name < b.name end)

	if #unused_list > 0 then
		logger:Print("Enabled but nothing currently references these - Decline below will disable them:")
		for _, u in ipairs(unused_list) do
			local detail
			if u.potential_required_by then
				detail = " (required by disabled " .. table.concat(u.potential_required_by, ", ") .. ")"
			elseif u.potential_optional_by then
				detail = AoM.L("OPTIONAL_FOR_DISABLED") .. table.concat(u.potential_optional_by, ", ") .. ")"
			else
				detail = AoM.L("NOTHING_INSTALLED_WANTS_THIS_ENABLED_OR")
			end
			logger:Print("  " .. u.name .. LibAPH.FormatVersionParen(u.version) .. detail)
		end
	end
	if #report.active_optional_libraries > 0 then
		logger:Print("Enabled optional libraries currently in use (not offered for disable here):")
		for _, lib in ipairs(report.active_optional_libraries) do
			logger:Print("  " .. lib.name .. LibAPH.FormatVersionParen(lib.version) .. " - used by " .. table.concat(lib.addons, ", "))
		end
	end
	if #report.missing_optional_libraries > 0 then
		logger:Print("Not installed, but could be used by:")
		for _, lib in ipairs(report.missing_optional_libraries) do
			logger:Print("  " .. lib.name .. " - wanted by " .. table.concat(lib.addons, ", "))
		end
	end
	if #report.broken_addons > 0 then
		logger:Print("Enabled but missing a required library - won't load until installed:")
		for _, a in ipairs(report.broken_addons) do
			logger:Print("  " .. a.name .. " - needs " .. table.concat(a.missing, ", "))
		end
	end

	local rows = {}
	local function AddHeader(text)
		table.insert(rows, { text = text, color = SECTION_HEADER_COLOR, is_header = true })
	end
	local function AddItem(text, tooltip, color)
		table.insert(rows, { text = "  " .. text, color = color or ITEM_COLOR, tooltip = tooltip })
	end

	if #enable_list > 0 then
		AddHeader(AoM.L("INSTALLED_ADD_ONS_COULD_USE_THESE"))
		for _, g in ipairs(enable_list) do
			table.insert(rows, {
				text = "  " .. g.name,
				color = ENABLE_CANDIDATE_COLOR,
				tooltip = AoM.L("WANTED_BY_N") .. ColorAddonNameList(report, g.addons),
				checkable = true, checked = false, kind = "enable",
				index = report.addon_index_by_name[g.name], name = g.name,
			})
		end
	end
	if #unused_list > 0 then
		AddHeader(AoM.L("ENABLED_BUT_NOTHING_CURRENTLY_REFERENCES_THE"))
		for _, u in ipairs(unused_list) do
			table.insert(rows, {
				text = "  " .. u.name .. LibAPH.FormatVersionParen(u.version),
				color = UNUSED_COLOR,
				tooltip = BuildUnusedTooltip(u),
				checkable = true, checked = false, kind = "disable",
				index = u.index, name = u.name, version = u.version,
			})
		end
	end
	if #report.active_optional_libraries > 0 then
		AddHeader(AoM.L("ENABLED_OPTIONAL_LIBRARIES_IN_USE_HOVER"))
		for _, lib in ipairs(report.active_optional_libraries) do
			AddItem(lib.name .. LibAPH.FormatVersionParen(lib.version), AoM.L("USED_BY_N") .. ColorAddonNameList(report, lib.addons))
		end
	end
	if #report.missing_optional_libraries > 0 then
		AddHeader(AoM.L("NOT_INSTALLED_BUT_COULD_BE_USED"))
		for _, lib in ipairs(report.missing_optional_libraries) do
			AddItem(lib.name, AoM.L("WANTED_BY_N") .. ColorAddonNameList(report, lib.addons), MISSING_COLOR)
		end
	end
	if #report.broken_addons > 0 then
		AddHeader("Enabled but missing a required library - won't load until installed (hover for which):")
		for _, a in ipairs(report.broken_addons) do
			AddItem(a.name, "Missing required library:\n" .. table.concat(a.missing, "\n"), BROKEN_COLOR)
		end
	end

	local win = GetOptionalLibraryWindow()
	win:SetRows(rows)
	win:SetCounts(AoM.GetAddonCountText())
	win:SetSubtitle(AoM.L("CHECK_A_LIBRARY_TO_ENABLE_IT"))
	win.check_all_btn.libaph_click_action = function() win:SetAllChecked(true) end
	win.uncheck_all_btn.libaph_click_action = function() win:SetAllChecked(false) end
	win.apply_btn.libaph_click_action = function()
		local to_enable, to_disable = {}, {}
		for _, row in ipairs(rows) do
			if row.checkable and row.index then
				if row.kind == "enable" and row.checked then
					table.insert(to_enable, { index = row.index, name = row.name })
				elseif row.kind == "disable" and row.checked then
					table.insert(to_disable, { index = row.index, name = row.name, version = row.version })
				end
			end
		end
		win:Hide()
		ApplyOptionalLibraryChoice(to_enable, to_disable)
	end
	win:Show()
end

function AoM.ReportPendingOptionalLibraryChanges()
	local pending = AoM.saved and AoM.saved.pending_optional_report
	if not pending then return end
	AoM.saved.pending_optional_report = nil


	if #pending.disabled > 0 then
		logger:Print("Disabled optional libraries nothing currently references:")
		for _, lib in ipairs(pending.disabled) do
			logger:Print("  " .. lib.name .. LibAPH.FormatVersionParen(lib.version))
		end
	end
	if #pending.enabled > 0 then
		logger:Print("Enabled optional libraries:")
		for _, name in ipairs(pending.enabled) do
			logger:Print("  " .. name)
		end
	end

	local report = ScanOptionalLibraries()

	local addon_names = {}
	for addon_name in pairs(report.addon_dependency_report) do table.insert(addon_names, addon_name) end
	table.sort(addon_names)

	if #addon_names > 0 then
		logger:Print("Enabled add-ons' required library versions:")
		for _, addon_name in ipairs(addon_names) do
			local active_deps = {}
			for _, dep in ipairs(report.addon_dependency_report[addon_name]) do
				if dep.active then table.insert(active_deps, dep) end
			end
			if #active_deps > 0 then
				logger:Print("  " .. addon_name .. ":")
				for _, dep in ipairs(active_deps) do
					local libData = KnownLibraries[dep.name]
					local versionText
					if not dep.version or dep.version <= 0 then
						versionText = AoM.L("VERSION_UNKNOWN")
					elseif libData then
						local color, plus, label = LibAPH.GetLibraryDriftColor(dep.version, libData.requiredVersion)
						versionText = color .. "v" .. dep.version .. plus .. label .. "|r"
					else
						versionText = "|c888888v" .. dep.version .. AoM.L("UNKNOWN")
					end
					logger:Print("    " .. dep.name .. ": " .. versionText)
				end
			end
		end
	end

	if #report.active_optional_libraries > 0 then
		logger:Print("Enabled optional libraries currently in use:")
		for _, lib in ipairs(report.active_optional_libraries) do
			logger:Print("  " .. lib.name .. LibAPH.FormatVersionParen(lib.version) .. " - used by " .. table.concat(lib.addons, ", "))
		end
	end

	if #report.unused_libraries > 0 then
		logger:Print("Still enabled but unreferenced by any add-on:")
		for _, u in ipairs(report.unused_libraries) do
			logger:Print("  " .. u.name .. LibAPH.FormatVersionParen(u.version))
		end
	end

	if #report.missing_optional_libraries > 0 then
		logger:Print("Not installed, but could be used by:")
		for _, lib in ipairs(report.missing_optional_libraries) do
			logger:Print("  " .. lib.name .. " - wanted by " .. table.concat(lib.addons, ", "))
		end
	end

	if #report.broken_addons > 0 then
		logger:Print("Enabled but missing a required library - won't load until installed:")
		for _, a in ipairs(report.broken_addons) do
			logger:Print("  " .. a.name .. " - needs " .. table.concat(a.missing, ", "))
		end
	end
end

local GHOST_SCAN_MAX_PASSES = 10
local NAMES_PER_CHAT_LINE = 6
local AUTO_RELOAD_DELAY_MS = 1500
local SAFE_RELOAD_NAMESPACE = "AoM_DisableUnusedSafeReload"

local function PrintNames(label, names)
	for first = 1, #names, NAMES_PER_CHAT_LINE do
		local chunk = {}
		for i = first, math.min(first + NAMES_PER_CHAT_LINE - 1, #names) do chunk[#chunk + 1] = names[i] end
		logger:Print(label .. table.concat(chunk, ", "))
	end
end

function PrintDisabledUnusedReport(addon_lines, library_names, closing)
	logger:Print("Disable Unused turned off " .. (#addon_lines + #library_names) .. ":")
	PrintNames("Add-ons missing a required library: ", addon_lines)
	PrintNames(AoM.L("UNUSED_LIBRARIES"), library_names)
	if closing then logger:Print(closing) end
end

local function IsLibraryEntry(name, isLibrary)
	if isLibrary or string.sub(name, 1, 3) == "Lib" then return true end
	return IsConsoleUI() and KnownConsoleLibraries[name] ~= nil
end

local function CollectReferencedLibraries(am, index_by_name)
	local referenced = {}
	for i = 1, am:GetNumAddOns() do
		local name, _, _, _, is_enabled = am:GetAddOnInfo(i)
		if is_enabled then
			for d = 1, am:GetAddOnNumDependencies(i) do
				local dep_name = am:GetAddOnDependencyInfo(i, d)
				if dep_name then referenced[dep_name] = true end
			end
			local declared = LibAPH.registered_dependencies[name]
			if declared then
				for lib_name in pairs(declared.required) do referenced[lib_name] = true end
				for lib_name in pairs(declared.optional) do referenced[lib_name] = true end
			end
			for _, lib_name in ipairs(GetKnownDependencies(name)) do
				if index_by_name[lib_name] then referenced[lib_name] = true end
			end
		end
	end
	return referenced
end

local function FindMissingRequiredDependencies(am, index)
	local missing = {}
	for d = 1, am:GetAddOnNumDependencies(index) do
		local dep_name, exists, active, min_version, version = am:GetAddOnDependencyInfo(index, d)
		local too_old = exists and (tonumber(version) or 0) < (tonumber(min_version) or 0)
		if dep_name and (not exists or not active or too_old) then missing[#missing + 1] = dep_name end
	end
	return missing
end

function AoM.HasMissingDependency(am, index)
	if not index then return false end
	for d = 1, am:GetAddOnNumDependencies(index) do
		local dep_name, exists = am:GetAddOnDependencyInfo(index, d)
		if dep_name and not exists then return true end
	end
	return false
end

function AoM.DisableUnused(opts)
	opts = opts or {}
	local am = GetAddOnManager()
	local index_by_name = {}
	for i = 1, am:GetNumAddOns() do index_by_name[am:GetAddOnInfo(i)] = i end
	local disabled_libraries, disabled_addons = {}, {}
	for _ = 1, GHOST_SCAN_MAX_PASSES do
		local changed = false
		if not opts.librariesOnly then
			for i = 1, am:GetNumAddOns() do
				local name, _, _, _, is_enabled = am:GetAddOnInfo(i)
				if is_enabled then
					local missing = FindMissingRequiredDependencies(am, i)
					if #missing > 0 then
						am:SetAddOnEnabled(i, false)
						disabled_addons[#disabled_addons + 1] = { name = name, missing = missing }
						changed = true
					end
				end
			end
		end
		local referenced = CollectReferencedLibraries(am, index_by_name)
		for i = 1, am:GetNumAddOns() do
			local name, _, _, _, is_enabled, _, _, is_library = am:GetAddOnInfo(i)
			if is_enabled and IsLibraryEntry(name, is_library) and not referenced[name] then
				am:SetAddOnEnabled(i, false)
				disabled_libraries[#disabled_libraries + 1] = name
				changed = true
			end
		end
		if not changed then break end
	end
	local total = #disabled_addons + #disabled_libraries
	if total > 0 then
		local addon_lines = {}
		for _, entry in ipairs(disabled_addons) do
			addon_lines[#addon_lines + 1] = entry.name .. AoM.L("NEEDS") .. table.concat(entry.missing, ", ") .. ")"
		end
		if AoM.saved and not opts.quiet then
			AoM.saved.disabled_unused_report = { addons = addon_lines, libraries = disabled_libraries }
		end
		if not opts.quiet then
			PrintDisabledUnusedReport(addon_lines, disabled_libraries, AoM.L("RELOAD_UI_TO_APPLY"))
		end
	elseif not opts.quiet and not opts.auto then
		logger:Print("Nothing unused to disable.")
	end
	if AoM.RefreshAllCategoryUI and total > 0 then AoM.RefreshAllCategoryUI() end
	return disabled_libraries, disabled_addons
end

local function AddUsedLibraries(am, index, name, into)
	for d = 1, am:GetAddOnNumDependencies(index) do
		local dep_name = am:GetAddOnDependencyInfo(index, d)
		if dep_name then into[dep_name] = true end
	end
	for _, lib_name in ipairs(GetKnownDependencies(name)) do into[lib_name] = true end
	local declared = LibAPH.registered_dependencies[name]
	if declared then
		for lib_name in pairs(declared.required) do into[lib_name] = true end
		for lib_name in pairs(declared.optional) do into[lib_name] = true end
	end
end

function AoM.CascadeDisableUnused(index)
	local am = GetAddOnManager()
	local index_by_name = {}
	for i = 1, am:GetNumAddOns() do index_by_name[am:GetAddOnInfo(i)] = i end
	local candidates = {}
	AddUsedLibraries(am, index, am:GetAddOnInfo(index), candidates)
	local disabled = {}
	for _ = 1, GHOST_SCAN_MAX_PASSES do
		local changed = false
		local referenced = CollectReferencedLibraries(am, index_by_name)
		for lib_name in pairs(candidates) do
			local lib_index = index_by_name[lib_name]
			if lib_index and not referenced[lib_name] then
				local _, _, _, _, is_enabled, _, _, is_library = am:GetAddOnInfo(lib_index)
				if is_enabled and IsLibraryEntry(lib_name, is_library) then
					am:SetAddOnEnabled(lib_index, false)
					disabled[#disabled + 1] = lib_name
					AddUsedLibraries(am, lib_index, lib_name, candidates)
					changed = true
				end
			end
		end
		if not changed then break end
	end
	if #disabled > 0 then
		for _, lib_name in ipairs(disabled) do
			logger:Print("Also disabled " .. lib_name .. ": nothing enabled uses it anymore.")
		end
		if AoM.saved then
			local report = AoM.saved.disabled_unused_report or { addons = {}, libraries = {} }
			for _, lib_name in ipairs(disabled) do report.libraries[#report.libraries + 1] = lib_name end
			AoM.saved.disabled_unused_report = report
		end
	end
	return disabled
end

local function IsAutoDisableZone()
	return IsPlayerInAvAWorld()
		or IsInAvAZone()
		or IsInImperialCity()
		or IsActiveWorldBattleground()
		or IsPlayerInRaid()
		or IsRaidInProgress()
		or IsEndlessDungeonStarted()
		or GetCurrentZoneDungeonDifficulty() ~= DUNGEON_DIFFICULTY_NONE
end

local function ReloadWhenSafe()
	LibAPH.ReloadUIWhenSafe(SAFE_RELOAD_NAMESPACE, {
		logger = logger,
		delayMs = AUTO_RELOAD_DELAY_MS,
		reloadingMessage = AoM.L("RELOADING_THE_UI_TO_APPLY"),
		waitingMessage = AoM.L("RELOADING_THE_UI_TO_APPLY_ONCE"),
	})
end

local function RunAutoDisableUnused()
	if not AoM.IsAutoDisableUnusedEnabled() then return end
	if not IsAutoDisableZone() then return end
	local libraries, addons = AoM.DisableUnused({ auto = true })
	if #libraries + #addons > 0 then ReloadWhenSafe() end
end

EVENT_MANAGER:RegisterForEvent("AoM_DisableUnusedOnZone", EVENT_PLAYER_ACTIVATED, function()
	local report = AoM.saved and AoM.saved.disabled_unused_report
	if report then
		AoM.saved.disabled_unused_report = nil
		PrintDisabledUnusedReport(report.addons or {}, report.libraries or {}, nil)
	end
	RunAutoDisableUnused()
end)

function AoM.IsAutoDisableUnusedEnabled()
	return AoM.saved ~= nil and AoM.saved.auto_disable_unused == true
end

function AoM.SetAutoDisableUnusedEnabled(enabled)
	if AoM.saved then AoM.saved.auto_disable_unused = enabled end
end

AoM.RunOptionalLibraryWizard = RunOptionalLibraryWizard
