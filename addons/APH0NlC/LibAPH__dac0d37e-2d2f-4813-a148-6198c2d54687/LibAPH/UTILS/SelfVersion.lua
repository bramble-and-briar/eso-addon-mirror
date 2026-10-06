--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

function LibAPH.CheckSelfVersion(store, currentVersion, opts)
	opts = opts or {}
	local historyField = opts.historyField or "version_history"
	local versionField = opts.versionField or "last_version"
	local maxHistory = opts.maxHistory or 3

	store[historyField] = store[historyField] or {}
	local history = store[historyField]
	local previousVersion = store[versionField]

	if #history == 0 and previousVersion and previousVersion ~= currentVersion then
		table.insert(history, previousVersion)
	end

	local wasUpdated = false
	local hist_len = #history
	if hist_len == 0 or history[hist_len] ~= currentVersion then
		table.insert(history, currentVersion)
		if #history > maxHistory then
			table.remove(history, 1)
		end
		wasUpdated = (previousVersion ~= nil and previousVersion ~= currentVersion)
	end

	store[versionField] = currentVersion
	return wasUpdated, previousVersion
end

function LibAPH.CheckAddonVersions(knownVersions, warnedTable, onMismatch)
	local am = GetAddOnManager()
	for i = 1, am:GetNumAddOns() do
		local addonName, _, _, _, isEnabled = am:GetAddOnInfo(i)
		local expected = knownVersions[addonName]
		if expected and isEnabled then
			local installedVer = am:GetAddOnVersion(i) or 0
			if expected.requiredVersion and installedVer > 0 and installedVer < expected.requiredVersion and warnedTable[addonName] ~= expected.requiredVersion then
				warnedTable[addonName] = expected.requiredVersion
				onMismatch(addonName, installedVer, expected)
			end
		end
	end
end
