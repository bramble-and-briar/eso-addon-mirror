--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

LibAPH.FPS_CAP_MIN, LibAPH.FPS_CAP_MAX = 10, 1000

local HOLDS = {
	{ key = "bg", name = "Limit Background FPS",
		id = function() return GRAPHICS_SETTING_USE_BACKGROUND_FPS_LIMIT end,
		off = function() return "0" end },
	{ key = "idle", name = "Idle Power Reduction",
		id = function() return GRAPHICS_SETTING_ENERGY_SUSTAINABILITY_SCREEN_DIM_AND_RESOLUTION end,
		off = function()
			if type(ENERGY_SUSTAINABILITY_SCREEN_DIM_AND_RESOLUTION_DISABLED) ~= "number" then return nil end
			if not (DoesPlatformSupportScreenDimAndResolutionDrop and DoesPlatformSupportScreenDimAndResolutionDrop()) then return nil end
			return tostring(ENERGY_SUSTAINABILITY_SCREEN_DIM_AND_RESOLUTION_DISABLED)
		end },
}

function LibAPH.GetFpsCap()
	local seconds = tonumber(GetCVar("MinFrameTime.2"))
	if seconds and seconds > 0 then return math.floor(1 / seconds + 0.5) end
	return nil
end

function LibAPH.SetFpsCap(fps)
	if IsConsoleUI() then return false, "console" end
	if fps == nil or (type(fps) == "string" and zo_strlower(zo_strtrim(fps)) == "uncapped") then
		SetCVar("MinFrameTime.2", "-1.00000000")
		return true, nil
	end
	fps = tonumber(fps)
	if not fps or fps < LibAPH.FPS_CAP_MIN or fps > LibAPH.FPS_CAP_MAX then return false, "range" end
	SetCVar("MinFrameTime.2", string.format("%.8f", 1 / fps))
	return true, LibAPH.GetFpsCap()
end

function LibAPH.HoldGameSettings()
	local held = {}
	if IsConsoleUI() then return held end
	for _, hold in ipairs(HOLDS) do
		local id, off = hold.id(), hold.off()
		if type(id) == "number" and off then
			local current = GetSetting(SETTING_TYPE_GRAPHICS, id)
			if current ~= nil and current ~= "" and current ~= off then
				held[hold.key] = { id = id, value = current }
				SetSetting(SETTING_TYPE_GRAPHICS, id, off, SETTINGS_SET_OPTION_DO_NOT_SAVE_TO_PERSISTED_DATA)
			end
		end
	end
	return held
end

function LibAPH.ReholdGameSettings(held)
	for _, hold in ipairs(HOLDS) do
		local entry, off = held and held[hold.key], hold.off()
		if type(entry) == "table" and off then SetSetting(SETTING_TYPE_GRAPHICS, entry.id, off, SETTINGS_SET_OPTION_DO_NOT_SAVE_TO_PERSISTED_DATA) end
	end
end

function LibAPH.ReleaseGameSettings(held)
	for _, hold in ipairs(HOLDS) do
		local entry = held and held[hold.key]
		if type(entry) == "table" then SetSetting(SETTING_TYPE_GRAPHICS, entry.id, entry.value, SETTINGS_SET_OPTION_DO_NOT_SAVE_TO_PERSISTED_DATA) end
	end
end

function LibAPH.GetHeldGameSettingNames(held)
	local names = {}
	for _, hold in ipairs(HOLDS) do
		if held and held[hold.key] then names[#names + 1] = hold.name end
	end
	return names
end
