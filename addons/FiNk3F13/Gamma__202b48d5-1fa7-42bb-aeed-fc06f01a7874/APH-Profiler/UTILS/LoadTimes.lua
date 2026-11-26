--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local APHP = APHProfilerCore

local NAMESPACE = "APHProfiler_LoadTimes"
local CLOSE_JOB = "APHProfiler_LoadTimesClose"

local names, starts, ends = {}, {}, {}
local own_index
local result

local function CloseLast()
	EVENT_MANAGER:UnregisterForUpdate(CLOSE_JOB)
	local count = #names
	if count > 0 and not ends[count] then ends[count] = GetGameTimeMilliseconds() end
end

local function OnAddOnLoaded(_, name)
	local now = GetGameTimeMilliseconds()
	local count = #names
	if count > 0 and not ends[count] then ends[count] = now end
	count = count + 1
	names[count], starts[count] = name, now
	if name == APHP.name then own_index = count end
	EVENT_MANAGER:RegisterForUpdate(CLOSE_JOB, 0, CloseLast)
end

local function AddOnDetails()
	local details = {}
	local manager = GetAddOnManager and GetAddOnManager()
	if not manager then return details end
	for index = 1, manager:GetNumAddOns() do
		local name, title, _, _, _, _, _, is_library = manager:GetAddOnInfo(index)
		if name then details[name] = { title = title, library = is_library == true } end
	end
	return details
end

local function Build()
	CloseLast()
	local count = #names
	if count == 0 then return nil end
	local details = AddOnDetails()
	local by_name, rows = {}, {}
	for index = 1, count do
		local name = names[index]
		local row = { name = name, order = index, ms = 0 }
		local info = details[name]
		row.title = info and info.title or name
		row.library = info ~= nil and info.library or false
		row.game = info == nil
		rows[index], by_name[name] = row, row
	end
	for index = 1, count do
		local gap = (ends[index] or starts[index]) - starts[index]
		local owner = names[index]
		if own_index and index < own_index then owner = names[index + 1] end
		local row = by_name[owner]
		if row and gap > 0 then row.ms = row.ms + gap end
	end
	if own_index and own_index > 1 then rows[1].unmeasured = true end
	local total = (ends[count] or starts[count]) - starts[1]
	local game = 0
	for _, row in ipairs(rows) do if row.game then game = game + 1 end end
	result = { rows = rows, total_ms = total, count = count, addons = count - game, game = game, measured_at = GetTimeStamp() }
	names, starts, ends = {}, {}, {}
	return result
end

local PENDING_AGE_SEC = 300
local RELOAD_DELAY_MS = 500

local function TakePendingScan()
	local saved = APHP.saved
	local pending = saved and saved.load_times_scan
	if not saved or pending == nil then return false end
	saved.load_times_scan = nil
	return type(pending) == "number" and GetTimeStamp() - pending <= PENDING_AGE_SEC
end

local function OnPlayerActivated()
	EVENT_MANAGER:UnregisterForEvent(NAMESPACE, EVENT_ADD_ON_LOADED)
	EVENT_MANAGER:UnregisterForEvent(NAMESPACE, EVENT_PLAYER_ACTIVATED)
	Build()
	if TakePendingScan() and APHP.OpenLoadTimesAfterScan then APHP.OpenLoadTimesAfterScan() end
end

function APHP.GetLoadTimes()
	return result
end

function APHP.CanScanLoadTimes()
	return type(ReloadUI) == "function"
end

function APHP.ScansLoadTimes()
	return APHP.saved.scan_load_times == true and APHP.CanScanLoadTimes()
end

function APHP.StartLoadTimesScan()
	if not APHP.CanScanLoadTimes() then return false end
	APHP.saved.load_times_scan = GetTimeStamp()
	APHP.Print(APHP.L("RELOADING_TO_TIME_START_UP"), true)
	zo_callLater(function() ReloadUI("ingame") end, RELOAD_DELAY_MS)
	return true
end

EVENT_MANAGER:RegisterForEvent(NAMESPACE, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
EVENT_MANAGER:RegisterForEvent(NAMESPACE, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
