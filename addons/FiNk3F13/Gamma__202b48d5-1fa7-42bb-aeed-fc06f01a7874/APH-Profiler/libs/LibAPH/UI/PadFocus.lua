--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local lib = LibAPH

local LAYER = "LibAPH_PadFocus"
local RESOLVE = "LibAPH_PadFocusResolve"
local MAX_HANDOFFS = 8
local BUTTONS = { up = true, down = true, left = true, right = true, lb = true, rb = true, lt = true, rt = true, a = true, x = true, y = true, ls = true, rs = true, b = true }

local entries = {}
local history = {}
local held = {}
local owner, waiting
local handoffs = 0

lib.PAD_FOCUS_LAYER = LAYER

local function Report(err)
	zo_callLater(function() error(err, 0) end, 0)
end

local function Call(fn, ...)
	if type(fn) ~= "function" then return true, nil end
	local ok, result = pcall(fn, ...)
	if not ok then Report(result) end
	return ok, result
end

local function SetLayer(on)
	local active = IsActionLayerActiveByName(LAYER)
	if on and not active then
		PushActionLayerByName(LAYER)
	elseif not on and active then
		RemoveActionLayerByName(LAYER)
	end
end

local function Remember(entry)
	for index = #history, 1, -1 do
		if history[index] == entry then table.remove(history, index) end
	end
	history[#history + 1] = entry
end

local function StopWaiting(entry)
	if not (waiting and waiting[entry]) then return end
	waiting[entry] = nil
	for index = #waiting.order, 1, -1 do
		if waiting.order[index] == entry then table.remove(waiting.order, index) end
	end
end

local function Forget(entry)
	for index = #history, 1, -1 do
		if history[index] == entry then table.remove(history, index) end
	end
	StopWaiting(entry)
end

local function Eligible(entry, auto)
	if not entry.registered then return false end
	local ok, result = Call(entry.spec.canFocus, auto == true)
	return ok and result == true
end

local function LetGo(entry)
	for button, by in pairs(held) do
		if by == entry then
			held[button] = nil
			Call(entry.spec.release and entry.spec.release[button])
		end
	end
end

local function Blur(entry, reason)
	if owner ~= entry then return end
	owner = nil
	LetGo(entry)
	if reason == "taken" and lib.GetContextMenuDepth and lib.GetContextMenuDepth() > 0 then lib.CloseContextMenu() end
	Call(entry.spec.onBlur, reason)
end

local function Grant(entry)
	if owner == entry then return true end
	if handoffs >= MAX_HANDOFFS then return false end
	handoffs = handoffs + 1
	local guard = 0
	while owner and owner ~= entry and guard < MAX_HANDOFFS do
		guard = guard + 1
		Blur(owner, "taken")
	end
	if owner then
		handoffs = handoffs - 1
		return owner == entry
	end
	owner = entry
	Remember(entry)
	SetLayer(true)
	Call(entry.spec.onFocus)
	handoffs = handoffs - 1
	if owner == nil then SetLayer(false) end
	return owner == entry
end

local function PassOn(from)
	for index = #history, 1, -1 do
		local entry = history[index]
		if entry ~= from and Eligible(entry, true) then return Grant(entry) end
	end
	return false
end

local function Release(entry, pass_on)
	if owner ~= entry then
		StopWaiting(entry)
		return false
	end
	Blur(entry, "released")
	if owner == nil then SetLayer(false) end
	if pass_on and owner == nil then PassOn(entry) end
	return true
end

local function Resolve()
	EVENT_MANAGER:UnregisterForUpdate(RESOLVE)
	local asked = waiting
	waiting = nil
	if owner or not asked then return end
	for index = #history, 1, -1 do
		local entry = history[index]
		if asked[entry] and Eligible(entry, true) then return Grant(entry) end
	end
	for _, entry in ipairs(asked.order) do
		if Eligible(entry, true) then return Grant(entry) end
	end
end

local function Request(entry, auto)
	if not entry.registered or not Eligible(entry, auto) then return false end
	if owner == entry then return true end
	if not auto then return Grant(entry) end
	if owner then return false end
	waiting = waiting or { order = {} }
	if not waiting[entry] then
		waiting[entry] = true
		waiting.order[#waiting.order + 1] = entry
	end
	EVENT_MANAGER:RegisterForUpdate(RESOLVE, 0, Resolve)
	return true
end

local function OnGameScreen()
	return lib.IsGameScreenShown == nil or lib.IsGameScreenShown()
end

local function Validate(force)
	local entry = owner
	if entry and not Eligible(entry, false) then
		if force or OnGameScreen() then Release(entry, true) end
		return nil
	end
	return owner
end

function lib.PadFocusPress(button)
	if not BUTTONS[button] then return false end
	local entry = Validate()
	if not entry then return false end
	local fn = entry.spec.buttons and entry.spec.buttons[button]
	if type(fn) ~= "function" then return false end
	held[button] = entry
	local ok, result = Call(fn)
	if not ok then return true end
	if result ~= true and held[button] == entry then held[button] = nil end
	return result == true
end

function lib.PadFocusRelease(button)
	local entry = held[button]
	held[button] = nil
	if entry then Call(entry.spec.release and entry.spec.release[button]) end
	return false
end

function lib.GetPadFocusOwner()
	return owner and owner.name or nil
end

function lib.RegisterPadFocus(name, spec)
	assert(type(name) == "string" and name ~= "", "RegisterPadFocus(name, spec): name")
	assert(type(spec) == "table" and type(spec.canFocus) == "function", "RegisterPadFocus(name, spec): spec.canFocus")
	local entry = entries[name]
	if entry then
		entry.spec = spec
		entry.registered = true
		return entry.handle
	end
	entry = { name = name, spec = spec, registered = true }
	local handle = {}
	function handle:Request(auto) return Request(entry, auto) end
	function handle:Release(pass_on) return Release(entry, pass_on) end
	function handle:IsFocused() return owner == entry end
	function handle:Unregister()
		entry.registered = false
		Release(entry, false)
		Forget(entry)
		entries[name] = nil
	end
	entry.handle = handle
	entries[name] = entry
	return handle
end

EVENT_MANAGER:RegisterForEvent(LAYER, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function(_, gamepad)
	Validate(not gamepad)
end)
