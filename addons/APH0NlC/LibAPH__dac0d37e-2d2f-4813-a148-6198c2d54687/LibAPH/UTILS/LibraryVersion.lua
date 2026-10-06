--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

function LibAPH.GetLibraryDriftColor(installedVer, tableVer)
	if not tableVer then return "|cFFFFFF", "", "" end
	if installedVer > tableVer then return "|c00FFFF", "+", LibAPH.L("NEWER_VERSION") end
	if installedVer < tableVer then return "|cFF0000", "", LibAPH.L("OLD_VERSION") end
	return "|c00FF00", "", ""
end

function LibAPH.CheckLibraryVersion(addonName)
	local am = GetAddOnManager()
	local ver, enabled = 0, false
	for i = 1, am:GetNumAddOns() do
		local name, _, _, _, isEnabled, state = am:GetAddOnInfo(i)
		if name == addonName then
			local v = am:GetAddOnVersion(i)
			if LibAPH.IsAddOnRunningState(isEnabled, state) then
				ver = math.max(ver, v); enabled = true
			elseif not enabled then
				ver = math.max(ver, v)
			end
		end
	end
	return ver, enabled
end

function LibAPH.FormatLibraryVersion(ver, enabled, requiredVer, formatters)
	if ver <= 0 then return formatters.missing() end
	if not enabled then return formatters.disabled(ver) end
	if ver == requiredVer then return formatters.exact(ver) end
	if ver < requiredVer then return formatters.old(ver, requiredVer) end
	return formatters.newer(ver, requiredVer)
end

local LIBRARY_NAME_COLOR = "66CCFF"
local LIBRARY_TEXT_COLOR = "FFD700"

local function GoldWrap(text)
	return "|c" .. LIBRARY_TEXT_COLOR .. (string.gsub(text, "|r", "|r|c" .. LIBRARY_TEXT_COLOR)) .. "|r"
end

function LibAPH.BuildLibraryWarning(templates, fullName, shortName, ver, enabled, requiredVer, consequence)
	local name = "|c" .. LIBRARY_NAME_COLOR .. fullName .. "|r"
	return LibAPH.FormatLibraryVersion(ver, enabled, requiredVer, {
		missing = function()
			return GoldWrap(string.format(templates.missing, name, shortName, "|c00FF00v" .. requiredVer .. "+|r", consequence))
		end,
		disabled = function(v)
			return GoldWrap(string.format(templates.disabled, name, consequence))
		end,
		exact = function(v) return nil end,
		old = function(v, r)
			return GoldWrap(string.format(templates.old, name, "|cFF0000v" .. v .. "|r", "|c00FF00v" .. r .. "+|r", consequence))
		end,
		newer = function(v, r) return nil end,
	})
end

function LibAPH.BuildLibraryWarningFromData(templates, libData, ver, enabled, consequence)
	return LibAPH.BuildLibraryWarning(templates, libData.fullName, libData.shortName, ver, enabled, libData.requiredVersion, consequence)
end
