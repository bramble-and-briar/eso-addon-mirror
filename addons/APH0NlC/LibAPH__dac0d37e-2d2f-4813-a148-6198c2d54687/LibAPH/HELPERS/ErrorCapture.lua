--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

local TIME_SYNC_ERROR_CODES = { [0x32BBA739] = true, [0xEA5D75AD] = true }

function LibAPH.HookErrorCapture(addonName, onCaptured)
	EVENT_MANAGER:RegisterForEvent(addonName .. "_LibAPH_ErrorCapture", EVENT_LUA_ERROR, function(_, errorString, errorCode)
		if type(errorString) ~= "string" then return end
		if TIME_SYNC_ERROR_CODES[errorCode] then return end
		local owner = string.match(errorString, "AddOns/([^/]+)/")
		if owner == addonName or (not owner and string.find(errorString, addonName, 1, true)) then
			onCaptured(errorString)
		end
	end)
end

function LibAPH.RecordCapturedBug(bugList, text, maxTracked)
	maxTracked = maxTracked or 20
	for _, bug in ipairs(bugList) do
		if bug.text == text then
			bug.count = bug.count + 1
			bug.lastSeen = GetTimeStamp()
			return false
		end
	end
	table.insert(bugList, 1, { text = text, count = 1, lastSeen = GetTimeStamp() })
	while #bugList > maxTracked do
		table.remove(bugList)
	end
	return true
end

LibAPH.BUG_REPORT_ERRORS_HEADER = "%s - Lua errors captured this session (%d):"

function LibAPH.FormatCapturedBugBlocks(title, bugs)
	local blocks = {}
	for _, bug in ipairs(bugs) do
		blocks[#blocks + 1] = string.format(LibAPH.BUG_REPORT_ERRORS_HEADER, title, bug.count) .. "\n\n" .. bug.text
	end
	return table.concat(blocks, "\n\n")
end

function LibAPH.FormatCapturedBugsSection(bugLines, promptText, noneCapturedText, describeInsteadText)
	if not bugLines or #bugLines == 0 then
		return noneCapturedText .. describeInsteadText
	end
	return promptText .. table.concat(bugLines, "\n\n")
end
