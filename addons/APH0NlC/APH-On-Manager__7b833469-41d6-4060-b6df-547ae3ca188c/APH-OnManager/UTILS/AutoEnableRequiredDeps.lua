--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(APHOnManagerCore, "APH-OnManager.lua must be loaded before this file")
local AoM = APHOnManagerCore
local LibAPH = LibAPH

local am = GetAddOnManager()
local orig_SetAddOnEnabled = am.SetAddOnEnabled
local logger = LibAPH.CreateChatLogger("AoM", "9CD04C")

local function AnnounceEnabled(dep_name)
	logger:Print("Auto-enabled required library: " .. dep_name)
end

function AoM.EnableRequiredDependencies(index)
	return LibAPH.EnableRequiredDependencies(index, orig_SetAddOnEnabled, AnnounceEnabled)
end

function AoM.EnableAddonWithDependencies(index)
	return LibAPH.EnableAddonWithDependencies(index, orig_SetAddOnEnabled, AnnounceEnabled)
end

function am:SetAddOnEnabled(index, enabled)
	if enabled then AoM.EnableRequiredDependencies(index) end
	return orig_SetAddOnEnabled(self, index, enabled)
end

if ZO_AddOnManager then
	ZO_PreHook(ZO_AddOnManager, "ChangeEnabledState", function(_, index, checkState)
		if checkState == TRISTATE_CHECK_BUTTON_CHECKED then
			AoM.EnableRequiredDependencies(index)
		end
	end)
end
