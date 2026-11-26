--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

function LibAPH.FormatSettingsSnapshot(settings, fields, onLabel, offLabel)
	local lines = {}
	for _, f in ipairs(fields) do
		local v = settings and settings[f.key]
		if type(v) == "boolean" then
			table.insert(lines, f.label .. ": " .. (v and onLabel or offLabel))
		end
	end
	return table.concat(lines, "\n")
end

function LibAPH.ResetToDefaults(settings, defaults, excludeKeys, postFn)
	excludeKeys = excludeKeys or {}
	for k, v in pairs(defaults) do
		if not excludeKeys[k] then
			if type(v) == "table" then
				settings[k] = ZO_ShallowTableCopy(v)
			else
				settings[k] = v
			end
		end
	end
	if postFn then postFn() end
	ReloadUI("ingame")
end
