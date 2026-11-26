--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

function LibAPH.FormatVersionParen(version)
	if not version or version <= 0 then return "" end
	return " (v" .. version .. ")"
end

function LibAPH.FormatVersionBare(version)
	if not version or version <= 0 then return "" end
	return " v" .. version
end

function LibAPH.FormatVersionHistory(history, currentVersion, sep)
	local list = history or { currentVersion }
	local colored = {}
	for i, v in ipairs(list) do
		if i == #list then table.insert(colored, "|c00FF00" .. v .. "|r")
		elseif i == 1 then table.insert(colored, "|cFF0000" .. v .. "|r")
		else table.insert(colored, v) end
	end
	return table.concat(colored, sep or ", ")
end

function LibAPH.StripColors(text, fallback)
	if type(text) ~= "string" then return fallback ~= nil and fallback or text end
	local stripped = (text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""))
	if stripped == "" and fallback ~= nil then return fallback end
	return stripped
end

local DISK_UNITS = { "MB", "GB", "TB", "PB", "EB" }

function LibAPH.PickDiskUnit(usageMB)
	local step = 1
	local scale = 1
	while step < #DISK_UNITS and usageMB / scale >= 1024 do
		scale = scale * 1024
		step = step + 1
	end
	return DISK_UNITS[step], scale
end

function LibAPH.FormatSizeMB(sizeMB, decimals, subMegabyteUnit)
	if type(sizeMB) ~= "number" then return nil end
	decimals = decimals or 1
	if subMegabyteUnit and sizeMB < 1 then
		return string.format("%d %s", math.floor(sizeMB * 1024), subMegabyteUnit)
	end
	local unit, scale = LibAPH.PickDiskUnit(sizeMB)
	return string.format("%." .. decimals .. "f %s", sizeMB / scale, unit)
end

function LibAPH.FormatDiskUsageMB(usageMB, short)
	if type(usageMB) ~= "number" then return nil end
	if usageMB < 0.1 then return short and "<0.1 MB" or LibAPH.L("LESS_THAN_0_1_MB") end
	return LibAPH.FormatSizeMB(usageMB)
end

function LibAPH.FormatMemoryMB(sizeMB)
	return LibAPH.FormatSizeMB(sizeMB, 2, "KB")
end

LibAPH.NO_LIMIT_SIGN = "\226\136\158"

function LibAPH.FormatDiskUsageRangeMB(usedMB, capacityMB)
	if type(usedMB) ~= "number" then return nil end
	if type(capacityMB) ~= "number" then
		local used = LibAPH.FormatDiskUsageMB(usedMB, true)
		return used and (used .. " / " .. LibAPH.NO_LIMIT_SIGN) or nil
	end
	local unit, scale = LibAPH.PickDiskUnit(math.max(usedMB, capacityMB))
	return string.format("%.1f / %.1f %s", usedMB / scale, capacityMB / scale, unit)
end

function LibAPH.FormatInstallDateLine(installedDate, todayStr)
	return "|c00FF00" .. installedDate .. "|r > |cFFFFFF" .. todayStr .. "|r"
end

function LibAPH.GetTodayDateString()
	local raw = GetDate()
	if type(raw) == "number" then raw = tostring(raw) end
	if type(raw) == "string" and string.len(raw) == 8 then
		return string.sub(raw, 1, 4) .. "/" .. string.sub(raw, 5, 6) .. "/" .. string.sub(raw, 7, 8)
	end
	return GetDateStringFromTimestamp(GetTimeStamp())
end

function LibAPH.UnescapeName(name)
	if type(name) ~= "string" or not string.find(name, "\\", 1, true) then return name end
	return (string.gsub(name, "\\(['\226])", "%1"))
end
