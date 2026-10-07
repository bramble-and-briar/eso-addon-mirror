--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

LibAPH = LibAPH or {}
local LibAPH = LibAPH
LibAPH.VERSION = "2026.10.07.17.24"

function LibAPH.L(key, ...)
	local id = _G["SI_LIBAPH_" .. key]
	local text = id and GetString(id) or key
	if select("#", ...) > 0 then return string.format(text, ...) end
	return text
end

function LibAPH.dev_simulate_error()
	zo_callLater(function()
		error("LibAPH: THIS IS NOT A REAL ERROR, THIS IS A TEST ERROR")
	end, 1)
end

EVENT_MANAGER:RegisterForEvent("LibAPH_Init", EVENT_ADD_ON_LOADED, function(eventCode, addonName)
	if addonName ~= "LibAPH" then return end
	EVENT_MANAGER:UnregisterForEvent("LibAPH_Init", EVENT_ADD_ON_LOADED)
	if IsConsoleUI() then LibAPH.ForceControllerKeybindIcons() end
	LibAPH.bug_reporter = LibAPH.CreateAddonBugReporter({
		addonName = "LibAPH",
		title = "LibAPH",
		version = LibAPH.VERSION,
		boxName = "LibAPHBugReportBox",
	})
	if not IsConsoleUI() then
		SLASH_COMMANDS["/libaphbugreport"] = LibAPH.bug_reporter.Show
	end
	if GetDisplayName() == "@APHONlC" then
		SLASH_COMMANDS["/libaphsimulateerror"] = LibAPH.dev_simulate_error
	end
end)
