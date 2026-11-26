--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH
local lifecycles = {}
local stash = {}

function LibAPH.CallOptional(warnedTable, tag, unavailableNote, fn, label, ...)
	if type(fn) == "function" then
		return fn(...)
	end
	local warn_key = string.match(label, "^(.-)%s*%(") or label
	if not warnedTable[warn_key] then
		warnedTable[warn_key] = true
		d(tag .. " " .. tostring(label) .. " " .. unavailableNote)
	end
	return nil
end

function LibAPH.ToggleModuleDisabled(store, moduleFileFuncs, modKey, notifyFn, silent)
	if not moduleFileFuncs[modKey] then return end
	store.module_disabled = store.module_disabled or {}
	local now_disabled = not store.module_disabled[modKey]
	store.module_disabled[modKey] = now_disabled
	if not silent and notifyFn then notifyFn(now_disabled, modKey) end
	return now_disabled
end

function LibAPH.ApplyModuleDisableOverrides(store, moduleFileFuncs, modulesTable, nilOutFn, getFn)
	store.module_disabled = store.module_disabled or {}
	for mod_key, funcs in pairs(moduleFileFuncs) do
		if store.module_disabled[mod_key] then
			modulesTable[mod_key] = false
			for _, fname in ipairs(funcs) do
				if getFn and lifecycles[mod_key] then
					LibAPH.StashFunc(mod_key, fname, getFn(fname))
				end
				nilOutFn(fname)
			end
		end
	end
end

function LibAPH.RegisterModuleLifecycle(modKey, hooks)
	lifecycles[modKey] = hooks
end

function LibAPH.HasModuleLifecycle(modKey)
	return lifecycles[modKey] ~= nil
end

function LibAPH.StashFunc(modKey, fname, fn)
	stash[modKey] = stash[modKey] or {}
	stash[modKey][fname] = fn
end

function LibAPH.GetStashedFunc(modKey, fname)
	return stash[modKey] and stash[modKey][fname]
end

function LibAPH.SyncModuleLifecycle(modulesTable, modKey, isDisabled)
	local hooks = lifecycles[modKey]
	if not hooks then return false end
	if isDisabled then
		if modulesTable[modKey] and hooks.onUnload then hooks.onUnload() end
		modulesTable[modKey] = false
	else
		if not modulesTable[modKey] and hooks.onLoad then hooks.onLoad() end
		modulesTable[modKey] = true
	end
	return true
end

function LibAPH.BuildModuleLoadButton(opts)
	return {
		type = "checkbox",
		name = function()
			if opts.isMissing and opts.isMissing(opts.modKey) then
				return opts.displayName .. " " .. opts.moduleLabel .. (opts.missingText or "")
			end
			return opts.displayName .. " " .. opts.moduleLabel
		end,
		getFunc = function()
			local disabled_by_user = opts.settings.module_disabled and opts.settings.module_disabled[opts.modKey]
			return not disabled_by_user
		end,
		setFunc = function() opts.toggleFn(opts.modKey) end,
		disabled = opts.isMissing and function() return opts.isMissing(opts.modKey) end or nil
	}
end

function LibAPH.FormatModuleFileLine(filename, state, labels)
	if state == "loaded" then
		return "|cFFFFFF" .. filename .. "|r\n    |c00FF00" .. labels.loaded .. "|r"
	elseif state == "missing" then
		return "|c888888" .. filename .. "\n    " .. labels.missing .. "|r"
	else
		return "|c888888" .. filename .. "\n    " .. labels.unloaded .. "|r"
	end
end

function LibAPH.BuildModuleFileList(moduleOrder, moduleFiles, getState, labels, sep)
	local lines = {}
	for _, mod_key in ipairs(moduleOrder) do
		table.insert(lines, LibAPH.FormatModuleFileLine(moduleFiles[mod_key], getState(mod_key), labels))
	end
	return table.concat(lines, sep or "\n  ")
end
