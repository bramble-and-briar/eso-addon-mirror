--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

local ProfileStore = {}
ProfileStore.__index = ProfileStore

function LibAPH.CreateProfileStore(opts)
	assert(type(opts) == "table" and type(opts.getSaved) == "function", "CreateProfileStore needs a getSaved function")
	return setmetatable({
		getSaved = opts.getSaved,
		field = opts.field or "profiles",
		activeField = opts.activeField or "active_profile",
		capture = opts.capture,
		onChanged = opts.onChanged,
	}, ProfileStore)
end

function ProfileStore:Profiles()
	local saved = self.getSaved()
	if not saved then return nil end
	saved[self.field] = saved[self.field] or {}
	return saved[self.field], saved
end

function ProfileStore:Changed()
	if self.onChanged then self.onChanged() end
end

function ProfileStore:GetNames()
	local names = {}
	local profiles = self:Profiles()
	if not profiles then return names end
	for name in pairs(profiles) do names[#names + 1] = name end
	table.sort(names, function(a, b) return string.lower(a) < string.lower(b) end)
	return names
end

function ProfileStore:GetActiveName()
	local saved = self.getSaved()
	return saved and saved[self.activeField] or nil
end

function ProfileStore:SetActiveName(name)
	local saved = self.getSaved()
	if saved then saved[self.activeField] = name end
end

function ProfileStore:Get(name)
	local profiles = self:Profiles()
	if not profiles then return nil end
	return profiles[name]
end

function ProfileStore:Save(name, snapshot)
	if not name or name == "" then return false, "empty" end
	local profiles, saved = self:Profiles()
	if not profiles then return false, "nosaved" end
	local existed = profiles[name] ~= nil
	profiles[name] = snapshot or (self.capture and self.capture())
	saved[self.activeField] = name
	self:Changed()
	return true, existed and "overwritten" or "created"
end

function ProfileStore:Delete(name)
	local profiles, saved = self:Profiles()
	if not profiles then return false end
	if not profiles[name] then return false end
	profiles[name] = nil
	if saved[self.activeField] == name then saved[self.activeField] = nil end
	self:Changed()
	return true
end

function ProfileStore:Rename(oldName, newName)
	local profiles, saved = self:Profiles()
	if not profiles then return false, "nosaved" end
	if not newName or newName == "" then return false, "empty" end
	if not profiles[oldName] then return false, "notfound" end
	if profiles[newName] then return false, "duplicate" end
	profiles[newName] = profiles[oldName]
	profiles[oldName] = nil
	if saved[self.activeField] == oldName then saved[self.activeField] = newName end
	self:Changed()
	return true
end

function LibAPH.CopyList(source)
	return ZO_ShallowNumericallyIndexedTableCopy(source or {})
end

function LibAPH.CopyMap(source)
	return ZO_ShallowTableCopy(source or {})
end

function LibAPH.CaptureAddonEnabledState()
	local am = GetAddOnManager()
	local enabled, disabled = {}, {}
	for i = 1, am:GetNumAddOns() do
		local name, _, _, _, is_enabled = am:GetAddOnInfo(i)
		if is_enabled then
			enabled[#enabled + 1] = name
		else
			disabled[#disabled + 1] = name
		end
	end
	table.sort(enabled)
	table.sort(disabled)
	return enabled, disabled
end
