--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

LibAPH = LibAPH or {}
local LibAPH = LibAPH

local function GetManager()
	return GetAddOnManager()
end

local function GetSaver()
	local manager = GetManager()
	if manager and type(manager.RequestAddOnSavedVariablesPrioritySave) == "function" then return manager end
	return nil
end

function LibAPH.IsPrioritySaveSupported()
	return GetSaver() ~= nil
end

function LibAPH.RequestPrioritySave(addonName)
	if not addonName or addonName == "" then return false end
	local manager = GetSaver()
	if not manager then return false end
	manager:RequestAddOnSavedVariablesPrioritySave(addonName)
	return true
end

function LibAPH.RequestPrioritySaveForRunningAddons(onSaved)
	local manager = GetSaver()
	if not manager then return 0 end
	local reports_usage = onSaved ~= nil and type(manager.GetUserAddOnSavedVariablesDiskUsageMB) == "function"
	local saved = 0
	for index = 1, manager:GetNumAddOns() do
		local name, title, _, _, enabled, state = manager:GetAddOnInfo(index)
		if name and LibAPH.IsAddOnRunningState(enabled, state) then
			manager:RequestAddOnSavedVariablesPrioritySave(name)
			saved = saved + 1
			if onSaved then
				local usage = reports_usage and manager:GetUserAddOnSavedVariablesDiskUsageMB(index) or nil
				onSaved(name, index, usage, title)
			end
		end
	end
	return saved
end

function LibAPH.GetSavedVariablesDiskCapacityMB()
	local manager = GetManager()
	if not manager or type(manager.GetTotalUserAddOnSavedVariablesDiskCapacityMB) ~= "function" then return nil end
	return manager:GetTotalUserAddOnSavedVariablesDiskCapacityMB()
end

function LibAPH.GetUnusedSavedVariablesDiskUsageMB()
	local manager = GetManager()
	if not manager or type(manager.GetTotalUnusedAddOnSavedVariablesDiskUsageMB) ~= "function" then return nil end
	return manager:GetTotalUnusedAddOnSavedVariablesDiskUsageMB()
end

function LibAPH.ClearUnusedSavedVariables()
	local manager = GetManager()
	if not manager or type(manager.ClearUnusedAddOnSavedVariables) ~= "function" then return false end
	manager:ClearUnusedAddOnSavedVariables()
	return true
end

function LibAPH.DeleteSavedVariablesForAddon(addonIndex)
	if not addonIndex then return false end
	DeleteSavedVariablesForAddonIndex(addonIndex)
	return true
end

function LibAPH.GetSavedVariablesDiskUsageMB(addonIndex)
	local manager = GetManager()
	if not manager or type(manager.GetUserAddOnSavedVariablesDiskUsageMB) ~= "function" then return nil end
	return manager:GetUserAddOnSavedVariablesDiskUsageMB(addonIndex)
end

function LibAPH.GetTotalSavedVariablesDiskUsageMB()
	local manager = GetManager()
	if not manager or type(manager.GetTotalUserAddOnSavedVariablesDiskUsageMB) ~= "function" then return nil end
	return manager:GetTotalUserAddOnSavedVariablesDiskUsageMB()
end

local sweep_throttle = {}

function LibAPH.RequestThrottledPrioritySaveSweep(namespace, throttleMs, force, onSaved)
	local now = GetFrameTimeMilliseconds()
	local last = sweep_throttle[namespace] or 0
	if not force and last > 0 and (now - last) < throttleMs then return 0 end
	sweep_throttle[namespace] = now
	return LibAPH.RequestPrioritySaveForRunningAddons(onSaved)
end

function LibAPH.RequestThrottledPrioritySave(namespace, addonName, throttleMs, force)
	local key = namespace .. "/" .. tostring(addonName)
	local now = GetFrameTimeMilliseconds()
	local last = sweep_throttle[key] or 0
	if not force and last > 0 and (now - last) < throttleMs then return false end
	sweep_throttle[key] = now
	return LibAPH.RequestPrioritySave(addonName)
end
