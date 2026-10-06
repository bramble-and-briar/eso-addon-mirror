--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

local am = GetAddOnManager()
local processing = {}

local function BuildAddonIndexByName()
	local map = {}
	for i = 1, am:GetNumAddOns() do
		map[am:GetAddOnInfo(i)] = i
	end
	return map
end

LibAPH.BuildAddonIndexByName = BuildAddonIndexByName

local function EnableRequired(index, setEnabled, onEnabled, seen, index_by_name)
	seen = seen or {}
	if seen[index] then return 0 end
	seen[index] = true

	local num_deps = am:GetAddOnNumDependencies(index)
	if num_deps == 0 then return 0 end

	local enabled_count = 0
	for d = 1, num_deps do
		local dep_name, exists, active = am:GetAddOnDependencyInfo(index, d)
		if exists and not active then
			index_by_name = index_by_name or BuildAddonIndexByName()
			local dep_idx = index_by_name[dep_name]
			if dep_idx then
				enabled_count = enabled_count + EnableRequired(dep_idx, setEnabled, onEnabled, seen, index_by_name)
				if not select(5, am:GetAddOnInfo(dep_idx)) then
					if onEnabled then onEnabled(dep_name, dep_idx) end
					setEnabled(am, dep_idx, true)
					enabled_count = enabled_count + 1
				end
			end
		end
	end
	return enabled_count
end

function LibAPH.EnableRequiredDependencies(index, setEnabled, onEnabled)
	setEnabled = setEnabled or am.SetAddOnEnabled
	if processing[index] then return 0 end
	processing[index] = true
	local count = EnableRequired(index, setEnabled, onEnabled)
	processing[index] = nil
	return count
end

function LibAPH.EnableAddonWithDependencies(index, setEnabled, onEnabled)
	setEnabled = setEnabled or am.SetAddOnEnabled
	local count = LibAPH.EnableRequiredDependencies(index, setEnabled, onEnabled)
	setEnabled(am, index, true)
	return count
end
