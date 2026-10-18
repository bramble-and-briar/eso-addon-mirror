--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(APHOnManagerCore, "APH-OnManager.lua must be loaded before this file")
if not ADD_ON_MANAGER then return end
local AoM = APHOnManagerCore
local function IsRecoverableByEnabling(am, addon_index)
	local num_deps = am:GetAddOnNumDependencies(addon_index)
	if num_deps == 0 then return false end

	local has_disabled_only_problem = false
	for d = 1, num_deps do
		local _, exists, active, minVersion, version = am:GetAddOnDependencyInfo(addon_index, d)
		if not exists then
			return false
		end
		if minVersion and minVersion > 0 and version < minVersion then
			return false
		end
		if not active then
			has_disabled_only_problem = true
		end
	end
	return has_disabled_only_problem
end

local orig_GetRowSetupFunction = ZO_AddOnManager.GetRowSetupFunction
function ZO_AddOnManager:GetRowSetupFunction()
	local orig_setup = orig_GetRowSetupFunction(self)
	return function(control, data)
		orig_setup(control, data)
		if data.hasDependencyError and data.index then
			local am = GetAddOnManager()
			if IsRecoverableByEnabling(am, data.index) then
				local enabledControl = control:GetNamedChild("Enabled")
				if enabledControl then
					enabledControl:SetHidden(false)
					ZO_CheckButton_SetEnableState(enabledControl, am:AreAddOnsEnabled())
				end
			end
		end
	end
end

ZO_PostHook(ZO_AddOnManager, "OnEnabledButtonClicked", function(self, control, checkState)
	local row = control and control:GetParent()
	if checkState ~= TRISTATE_CHECK_BUTTON_UNCHECKED or not row or not row.data or not row.data.index then return end
	if #AoM.CascadeDisableUnused(row.data.index) > 0 then
		self.isDirty = true
		self:RefreshData()
	end
end)
