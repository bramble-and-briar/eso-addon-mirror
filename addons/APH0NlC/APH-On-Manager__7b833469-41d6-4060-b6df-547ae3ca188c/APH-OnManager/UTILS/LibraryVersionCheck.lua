--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(APHOnManagerCore, "APH-OnManager.lua must be loaded before this file")
local AoM = APHOnManagerCore
assert(AoM.KnownLibraries, "KnownLibraries.lua must be loaded before this file")
local LibAPH = LibAPH
local KnownLibraries = AoM.KnownLibraries

local library_version_window

local function GetLibraryVersionWindow()
	if library_version_window then return library_version_window end
	library_version_window = LibAPH.CreateScrollListWindow({
		name = "AoM_LibraryVersionWindow",
		widthPct = 0.3, heightPct = 0.5,
		minWidth = 420, maxWidth = 760,
		minHeight = 360, maxHeight = 720,
		footerHeight = 20,
		titleText = AoM.L("APH_ON_MANAGER_LIBRARY_VERSION_CHECK"),
	})
	return library_version_window
end

function AoM.ShowLibraryVersionCheck()
	local names = AoM.GetKnownNames(KnownLibraries)

	local rows = {}
	for _, key in ipairs(names) do
		local libData = KnownLibraries[key]
		local ver = LibAPH.CheckLibraryVersion(key)
		if ver > 0 then
			local color, plus, label = LibAPH.GetLibraryDriftColor(ver, libData.requiredVersion)
			table.insert(rows, { text = string.format("%s: %sv%d%s%s|r", libData.fullName, color, ver, plus, label) })
		end
	end

	if #rows == 0 then
		d(AoM.L("AOM_NONE_OF_THE_LIBRARIES_IN"))
		return
	end

	table.insert(rows, 1, { text = AoM.L("INSTALLED_LIBRARY_VERSIONS_COMPARED_TO_THIS"), is_header = true })

	local win = GetLibraryVersionWindow()
	win:SetRows(rows)
	win:Show()
end
