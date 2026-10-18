--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local APHCR = APHCodeRunnerCore

local function Finish(session, ok, ...)
	APHCR.call_depth = APHCR.call_depth - 1
	if APHCR.call_depth == 0 then
		rawset(_G, "WINDOW_MANAGER", APHCR.REAL_WINDOW_MANAGER)
		if GuiRoot:GetNumChildren() ~= APHCR.known_count then APHCR.RefreshKnown(session) end
	end
	if not ok then
		APHCR.ReportLocated(session, tostring((...)))
		error((...), 0)
	end
	return ...
end

local function Guarded(session, fn)
	if type(fn) ~= "function" then return fn end
	return function(...)
		if not session.alive then return end
		if APHCR.call_depth == 0 then
			if GuiRoot:GetNumChildren() ~= APHCR.known_count then APHCR.RefreshKnown(nil) end
			rawset(_G, "WINDOW_MANAGER", session.window_proxy)
		end
		APHCR.call_depth = APHCR.call_depth + 1
		return Finish(session, pcall(fn, ...))
	end
end

local function PassThrough(real, proxy)
	return setmetatable(proxy, {
		__index = function(_, key)
			local value = real[key]
			if type(value) ~= "function" then return value end
			return function(self, ...)
				if self == proxy then self = real end
				return value(self, ...)
			end
		end,
	})
end

local function Reuse(session, name, parent)
	if type(name) ~= "string" or name == "" then return nil end
	local existing = GetControl(name)
	if not existing then return nil end
	local owner = existing:GetOwningWindow() or existing
	if not (APHCR.retired[owner] or session.reclaimed[owner]) then return nil end
	if APHCR.retired[owner] then
		APHCR.retired[owner] = nil
		session.reclaimed[owner] = true
		session.toplevels[#session.toplevels + 1] = owner
	end
	if parent and existing:GetParent() ~= parent then existing:SetParent(parent) end
	existing:ClearAnchors()
	existing:SetHidden(false)
	return existing
end

local function MakeWindowProxy(session)
	local proxy = {}
	function proxy:CreateControl(name, parent, control_type)
		return Reuse(session, name, parent) or APHCR.REAL_WINDOW_MANAGER:CreateControl(name, parent, control_type)
	end
	function proxy:CreateControlFromVirtual(name, parent, template, suffix)
		local full_name = name and (name .. (suffix or "")) or nil
		return Reuse(session, full_name, parent) or APHCR.REAL_WINDOW_MANAGER:CreateControlFromVirtual(name, parent, template, suffix)
	end
	function proxy:CreateTopLevelWindow(name)
		return Reuse(session, name, GuiRoot) or APHCR.REAL_WINDOW_MANAGER:CreateTopLevelWindow(name)
	end
	return PassThrough(APHCR.REAL_WINDOW_MANAGER, proxy)
end

local function MakeEventProxy(session)
	local prefix = "APHCR" .. session.id .. "_"
	local function Scoped(name) return prefix .. tostring(name) end
	local proxy = {}
	function proxy:RegisterForEvent(name, event, fn, do_once)
		local guarded = Guarded(session, fn)
		session.events[Scoped(name) .. "\0" .. tostring(event)] = { Scoped(name), event }
		if event == EVENT_ADD_ON_LOADED then session.loaded[name] = guarded end
		if event == EVENT_PLAYER_ACTIVATED then session.activated[name] = guarded end
		return APHCR.REAL_EVENT_MANAGER:RegisterForEvent(Scoped(name), event, guarded, do_once)
	end
	function proxy:UnregisterForEvent(name, event)
		session.events[Scoped(name) .. "\0" .. tostring(event)] = nil
		if event == EVENT_ADD_ON_LOADED then session.loaded[name] = nil end
		if event == EVENT_PLAYER_ACTIVATED then session.activated[name] = nil end
		return APHCR.REAL_EVENT_MANAGER:UnregisterForEvent(Scoped(name), event)
	end
	function proxy:AddFilterForEvent(name, event, ...)
		return APHCR.REAL_EVENT_MANAGER:AddFilterForEvent(Scoped(name), event, ...)
	end
	function proxy:RegisterForAllEvents(name, fn)
		session.all_events[Scoped(name)] = true
		return APHCR.REAL_EVENT_MANAGER:RegisterForAllEvents(Scoped(name), Guarded(session, fn))
	end
	function proxy:UnregisterForAllEvents(name)
		session.all_events[Scoped(name)] = nil
		session.loaded[name], session.activated[name] = nil, nil
		return APHCR.REAL_EVENT_MANAGER:UnregisterForAllEvents(Scoped(name))
	end
	function proxy:RegisterForUpdate(name, interval, fn, do_once)
		session.updates[Scoped(name)] = true
		return APHCR.REAL_EVENT_MANAGER:RegisterForUpdate(Scoped(name), interval, Guarded(session, fn), do_once)
	end
	function proxy:UnregisterForUpdate(name)
		session.updates[Scoped(name)] = nil
		return APHCR.REAL_EVENT_MANAGER:UnregisterForUpdate(Scoped(name))
	end
	function proxy:RegisterForPostEffectsUpdate(name, interval, fn, do_once)
		session.post_updates[Scoped(name)] = true
		return APHCR.REAL_EVENT_MANAGER:RegisterForPostEffectsUpdate(Scoped(name), interval, Guarded(session, fn), do_once)
	end
	function proxy:UnregisterForPostEffectsUpdate(name)
		session.post_updates[Scoped(name)] = nil
		return APHCR.REAL_EVENT_MANAGER:UnregisterForPostEffectsUpdate(Scoped(name))
	end
	return PassThrough(APHCR.REAL_EVENT_MANAGER, proxy)
end

local function MakeCallbackProxy(session, real)
	local proxy = {}
	local guarded_by_fn = {}
	function proxy:RegisterCallback(name, fn, ...)
		local guarded = Guarded(session, fn)
		guarded_by_fn[fn] = guarded
		session.callbacks[#session.callbacks + 1] = { real, name, guarded }
		return real:RegisterCallback(name, guarded, ...)
	end
	function proxy:UnregisterCallback(name, fn)
		return real:UnregisterCallback(name, guarded_by_fn[fn] or fn)
	end
	return PassThrough(real, proxy)
end

local function MakeSlashProxy(session)
	return setmetatable({}, {
		__index = SLASH_COMMANDS,
		__newindex = function(_, key, value)
			if not session.slash[key] then session.slash[key] = { prev = SLASH_COMMANDS[key] } end
			SLASH_COMMANDS[key] = Guarded(session, value)
		end,
	})
end

local function MakeSavedVarsSandbox(session, env)
	local function Sandbox(name)
		local sandbox = session.saved[name]
		if not sandbox then
			sandbox = {}
			session.saved[name] = sandbox
			rawset(env, name, sandbox)
		end
		return sandbox
	end
	local proxy
	proxy = setmetatable({}, {
		__index = function(_, key)
			local value = ZO_SavedVars[key]
			if type(value) ~= "function" then return value end
			return function(self, first, ...)
				if self == proxy then self = ZO_SavedVars end
				if type(first) == "string" then first = Sandbox(first) end
				return value(self, first, ...)
			end
		end,
	})
	rawset(env, "ZO_SavedVars", proxy)
	return Sandbox
end

local function MakeEnv(session, saved_names)
	local env = {}
	setmetatable(env, {
		__index = function(_, key) return _G[key] end,
		__newindex = function(_, key, value) rawset(env, key, value) end,
	})
	local Sandbox = MakeSavedVarsSandbox(session, env)
	for name in (saved_names or ""):gmatch("[%w_]+") do Sandbox(name) end
	local event_proxy = MakeEventProxy(session)
	rawset(env, "_G", env)
	rawset(env, "getfenv", function(level)
		if level == nil or level == 0 then return env end
		if type(level) == "number" then level = level + 1 end
		return getfenv(level)
	end)
	rawset(env, "setfenv", function(level, table_env)
		if level == 0 then error("setfenv(0) would swap the game's globals; a run keeps its own", 2) end
		if type(level) == "number" then level = level + 1 end
		return setfenv(level, table_env)
	end)
	rawset(env, "EVENT_MANAGER", event_proxy)
	rawset(env, "GetEventManager", function() return event_proxy end)
	rawset(env, "WINDOW_MANAGER", session.window_proxy)
	rawset(env, "GetWindowManager", function() return session.window_proxy end)
	rawset(env, "SLASH_COMMANDS", MakeSlashProxy(session))
	rawset(env, "CALLBACK_MANAGER", MakeCallbackProxy(session, CALLBACK_MANAGER))
	rawset(env, "SCENE_MANAGER", MakeCallbackProxy(session, SCENE_MANAGER))
	rawset(env, "zo_callLater", function(fn, delay_ms)
		local id
		id = zo_callLater(function()
			session.later[id] = nil
			Guarded(session, fn)()
		end, delay_ms)
		session.later[id] = true
		return id
	end)
	for _, hook_name in ipairs(APHCR.HOOK_NAMES) do
		local real_hook = _G[hook_name]
		if real_hook then
			rawset(env, hook_name, function(first, second, third, ...)
				if type(second) == "function" then return real_hook(first, Guarded(session, second)) end
				return real_hook(first, second, Guarded(session, third), ...)
			end)
		end
	end
	return env
end

local function NewSession(addon_name)
	APHCR.session_counter = APHCR.session_counter + 1
	local session = {
		id = APHCR.session_counter, alive = true, addon_name = addon_name,
		events = {}, all_events = {}, updates = {}, post_updates = {}, later = {}, slash = {}, saved = {}, callbacks = {},
		toplevels = {}, reclaimed = {}, stops = {}, loaded = {}, activated = {},
	}
	session.window_proxy = MakeWindowProxy(session)
	return session
end

local function FireTracked(handlers, event_code, arg, errors)
	local snapshot = {}
	for namespace, fn in pairs(handlers) do snapshot[#snapshot + 1] = { namespace, fn } end
	for _, entry in ipairs(snapshot) do
		local ok, err = pcall(entry[2], event_code, arg)
		if not ok then errors[#errors + 1] = entry[1] .. ": " .. tostring(err) end
	end
end

function APHCR.RunFiles(file_list, addon_name, saved_names)
	if not (AreUserAddOnsSupported() or IsInternalBuild()) then
		return false, "User add-ons are not supported in this client/account state."
	end
	local session = NewSession(addon_name ~= "" and addon_name or ("APHCodeRunnerRun" .. APHCR.session_counter + 1))
	local env = MakeEnv(session, saved_names)
	local errors, ran = {}, 0
	APHCR.RefreshKnown(nil)
	APHCR.sessions[#APHCR.sessions + 1] = session

	local runnable = {}
	session.file_list = file_list
	for _, file in ipairs(file_list) do file.error_lines = nil end
	for index, file in ipairs(file_list) do
		if file.enabled ~= false and not file.text:match("^%s*$") then
			local _, newlines = file.text:gsub("\n", "")
			local last = runnable[#runnable]
			local part
			if last and last.title == file.title then
				part = { index = index, first = last.next_line, lines = newlines + 1 }
				last.text = last.text .. "\n" .. file.text
				last.parts[#last.parts + 1] = part
				last.longest = math.max(last.longest, #file.text)
			else
				part = { index = index, first = 1, lines = newlines + 1 }
				last = { title = file.title, text = file.text, parts = { part }, longest = #file.text }
				runnable[#runnable + 1] = last
			end
			last.next_line = part.first + part.lines
		end
	end
	session.groups = runnable

	for _, file in ipairs(runnable) do
		do
			local chunk, compile_err = zo_loadstring(file.text, "@" .. file.title)
			if not chunk then
				local message = file.title .. ": " .. tostring(compile_err)
				if tostring(compile_err):find("<eof>", 1, true) and file.longest >= APHCR.edit_limit - 2500 then
					message = message .. string.format(" - this box holds %d characters and ESO's edit boxes stop at %d (a line break counts as 2). Split the file into two boxes with the same name.", file.longest, APHCR.edit_limit)
				end
				errors[#errors + 1] = message
				APHCR.ReportLocated(session, message)
			else
				setfenv(chunk, env)
				local ok, result = pcall(Guarded(session, chunk))
				ran = ran + 1
				if not ok then
					errors[#errors + 1] = file.title .. ": " .. tostring(result)
				elseif type(result) == "function" then
					session.stops[#session.stops + 1] = result
				end
			end
		end
	end

	FireTracked(session.loaded, EVENT_ADD_ON_LOADED, session.addon_name, errors)
	FireTracked(session.activated, EVENT_PLAYER_ACTIVATED, true, errors)

	for _, message in ipairs(errors) do APHCR.ChatLine(message) end
	if #errors > 0 then
		return false, string.format("Run %d: %d file(s), %d error(s) - see Errors.", session.id, ran, #errors), session.first_location
	end
	return true, string.format("Run %d: %d file(s) loaded as %s.", session.id, ran, session.addon_name)
end

local function RemoveFragmentsFor(owned)
	for _, scene in pairs(SCENE_MANAGER.scenes or {}) do
		local fragments = scene.fragments
		if fragments then
			for index = #fragments, 1, -1 do
				local control = fragments[index].control
				if control and owned[control:GetOwningWindow() or control] then
					scene:RemoveFragment(fragments[index])
				end
			end
		end
	end
end

local function StopSession(session)
	if not session.alive then return false end
	session.alive = false
	for _, fn in ipairs(session.stops) do pcall(fn) end
	for _, entry in pairs(session.events) do APHCR.REAL_EVENT_MANAGER:UnregisterForEvent(entry[1], entry[2]) end
	for namespace in pairs(session.all_events) do APHCR.REAL_EVENT_MANAGER:UnregisterForAllEvents(namespace) end
	for namespace in pairs(session.updates) do APHCR.REAL_EVENT_MANAGER:UnregisterForUpdate(namespace) end
	for namespace in pairs(session.post_updates) do APHCR.REAL_EVENT_MANAGER:UnregisterForPostEffectsUpdate(namespace) end
	for id in pairs(session.later) do zo_removeCallLater(id) end
	for _, entry in ipairs(session.callbacks) do entry[1]:UnregisterCallback(entry[2], entry[3]) end
	for key, entry in pairs(session.slash) do SLASH_COMMANDS[key] = entry.prev end
	local owned = {}
	for _, control in ipairs(session.toplevels) do
		owned[control] = true
		APHCR.retired[control] = true
		control:SetHidden(true)
	end
	RemoveFragmentsFor(owned)
	session.saved = {}
	return true
end

function APHCR.StopLast()
	for index = #APHCR.sessions, 1, -1 do
		local session = table.remove(APHCR.sessions, index)
		if StopSession(session) then return true, string.format("Stopped run %d.", session.id) end
	end
	return false, "Nothing is running."
end

function APHCR.StopAll()
	local count = 0
	for index = #APHCR.sessions, 1, -1 do
		if StopSession(APHCR.sessions[index]) then count = count + 1 end
		APHCR.sessions[index] = nil
	end
	return count
end
