--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

LibAPH.registered_dependencies = LibAPH.registered_dependencies or {}

function LibAPH.RegisterAddonDependencies(addonName, requiredLibs, optionalLibs)
	local required, optional = {}, {}
	for _, name in ipairs(requiredLibs or {}) do required[name] = true end
	for _, name in ipairs(optionalLibs or {}) do optional[name] = true end
	LibAPH.registered_dependencies[addonName] = { required = required, optional = optional }
end
