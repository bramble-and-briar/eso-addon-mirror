--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

local SAVE_SHARE = 0.9
local SAVE_EVERY_MS = 10000
local SHORT = { logout = "logged out", quit = "game closed", reload = "reloaded", out_of_memory = "out of memory", likely_out_of_memory = "out of memory", unknown = "cut off" }
local copies = {}
local wrapped = {}

local function MarkAll(cause)
	for _, copy in pairs(copies) do copy:MarkCause(cause) end
end

local function ClearAll()
	for _, copy in pairs(copies) do copy:ClearCause() end
end

local function Wrap(name, before)
	local current = _G[name]
	if type(current) ~= "function" or wrapped[name] == current then return end
	ZO_PreHook(name, before)
	wrapped[name] = _G[name]
end

local function Hook()
	EVENT_MANAGER:RegisterForEvent("LibAPH_CrashCopy", EVENT_LOGOUT_DEFERRED, function(_, _, quit) MarkAll(quit and "quit" or "logout") end)
	Wrap("Logout", function() MarkAll("logout") end)
	Wrap("Quit", function() MarkAll("quit") end)
	Wrap("CancelLogout", ClearAll)
	Wrap("ReloadUI", function() MarkAll("reload") end)
end

local function PoolNow()
	local cap = GetTotalUserAddOnMemoryPoolCapacityMB and GetTotalUserAddOnMemoryPoolCapacityMB()
	if type(cap) ~= "number" or cap <= 0 then return nil, nil end
	return GetTotalUserAddOnMemoryPoolUsageMB(), cap
end

function LibAPH.CreateCrashCopy(opts)
	assert(type(opts) == "table" and type(opts.addonName) == "string" and type(opts.store) == "function", "CreateCrashCopy({ addonName, store, key })")
	local key = opts.key or "crash_copy"
	local copy = { cause = nil, next_save = 0 }
	copies[opts.addonName .. "/" .. key] = copy
	Hook()

	local function Active()
		return not opts.active or opts.active()
	end

	function copy:Get()
		local store = opts.store()
		return store and store[key]
	end

	function copy:Keep(data)
		local store = opts.store()
		if not store then return end
		store[key] = data
		self:Update()
	end

	function copy:Update()
		local data = self:Get()
		if type(data) ~= "table" then return end
		local pool, cap = PoolNow()
		data.at, data.pool, data.cap, data.cause = GetTimeStamp(), pool, cap, self.cause
		local now = GetGameTimeMilliseconds()
		if cap and pool and pool >= cap * (opts.saveShare or SAVE_SHARE) and now >= self.next_save then
			self.next_save = now + (opts.saveEveryMs or SAVE_EVERY_MS)
			LibAPH.RequestPrioritySave(opts.addonName)
		end
	end

	function copy:SaveNow()
		self:Update()
		LibAPH.RequestPrioritySave(opts.addonName)
	end

	function copy:MarkCause(cause)
		if self.cause or not Active() then return end
		if cause == "reload" and opts.expectedReload and opts.expectedReload() then return end
		Hook()
		self.cause = cause
		if opts.onCause then opts.onCause(cause) else self:Update() end
	end

	function copy:ClearCause()
		self.cause = nil
	end

	function copy:Reset()
		self.cause, self.next_save = nil, 0
		Hook()
	end

	function copy:Clear()
		local store = opts.store()
		if store then store[key] = nil end
		self.cause = nil
	end

	function copy:Take()
		local store = opts.store()
		local data = store and store[key]
		if store then store[key] = nil end
		if type(data) ~= "table" then return nil end
		return data, LibAPH.GetCrashReason(data)
	end

	return copy
end

function LibAPH.GetCrashReason(data, opts)
	opts = opts or {}
	local cause
	if data.cause == "logout" or data.cause == "quit" or data.cause == "reload" then
		cause = data.cause
	elseif opts.lowMemory or (opts.lowMemory == nil and data.low_memory) then
		cause = "out_of_memory"
	elseif data.pool and data.cap and data.pool >= data.cap * (opts.saveShare or SAVE_SHARE) then
		cause = "likely_out_of_memory"
	else
		cause = "unknown"
	end
	return { cause = cause, short = SHORT[cause], pool = data.pool, cap = data.cap, at = data.at }
end
