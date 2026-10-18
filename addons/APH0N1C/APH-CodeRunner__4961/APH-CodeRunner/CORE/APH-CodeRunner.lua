--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

APHCodeRunnerCore = {}
local APHCR = APHCodeRunnerCore
APHCR.name = "APH-CodeRunner"
APHCR.sessions = {}

APHCR.REAL_WINDOW_MANAGER = WINDOW_MANAGER
APHCR.REAL_EVENT_MANAGER = EVENT_MANAGER
local SV_CHUNK_BYTES = 1900
APHCR.ROW_HEIGHT = 22
APHCR.HOOK_NAMES = { "ZO_PreHook", "ZO_PostHook", "SecurePostHook", "ZO_PreHookHandler", "ZO_PostHookHandler" }

APHCR.files = {}
APHCR.selected = 1
local known_toplevels = {}
APHCR.known_count = 0
APHCR.retired = {}
APHCR.session_counter = 0
APHCR.call_depth = 0

function APHCR.ChatLine(message)
	if APHCR.sv and APHCR.sv.chat_logs == false then return false end
	d("|cFF4444[CodeRunner]|r " .. message)
	return true
end

local function SplitText(text)
	local chunks, start, len = {}, 1, #text
	while start <= len do
		local stop = math.min(start + SV_CHUNK_BYTES - 1, len)
		while stop < len and stop > start do
			local next_byte = text:byte(stop + 1)
			if next_byte < 128 or next_byte >= 192 then break end
			stop = stop - 1
		end
		chunks[#chunks + 1] = text:sub(start, stop)
		start = stop + 1
	end
	return chunks
end

function APHCR.PersistFile(index)
	local file = APHCR.files[index]
	if not APHCR.sv or not file then return end
	APHCR.sv.files[index] = { title = file.title, enabled = file.enabled, chunks = SplitText(file.text) }
end

function APHCR.PersistAll()
	if not APHCR.sv then return end
	APHCR.sv.files = {}
	for index in ipairs(APHCR.files) do APHCR.PersistFile(index) end
end

local function LoadFiles()
	APHCR.files = {}
	for index, entry in ipairs(APHCR.sv.files) do
		APHCR.files[index] = {
			title = entry.title or ("file" .. index .. ".lua"),
			enabled = entry.enabled ~= false,
			text = table.concat(entry.chunks or {}),
		}
	end
	if #APHCR.files == 0 then APHCR.files[1] = { title = "main.lua", enabled = true, text = "" } end
end

function APHCR.RefreshKnown(owner)
	local count = GuiRoot:GetNumChildren()
	for index = 1, count do
		local child = GuiRoot:GetChild(index)
		if child and not known_toplevels[child] then
			known_toplevels[child] = true
			if owner then owner.toplevels[#owner.toplevels + 1] = child end
		end
	end
	APHCR.known_count = count
end

APHCR.error_log = {}
local ERROR_LOG_MAX = 200
APHCR.edit_limit = 29903
local error_index = {}

function APHCR.LogError(run_id, message, location)
	local key = run_id .. "\0" .. message
	local entry = error_index[key]
	local is_new = entry == nil
	if entry then
		entry.count = entry.count + 1
		entry.time = GetTimeString()
	else
		entry = { key = key, run = run_id, message = message, count = 1, time = GetTimeString(), location = location }
		error_index[key] = entry
		APHCR.error_log[#APHCR.error_log + 1] = entry
		if #APHCR.error_log > ERROR_LOG_MAX then
			error_index[table.remove(APHCR.error_log, 1).key] = nil
		end
	end
	if APHCR.on_error_logged then APHCR.on_error_logged() end
	return is_new
end

function APHCR.ClearErrors()
	APHCR.error_log = {}
	error_index = {}
	if APHCR.on_error_logged then APHCR.on_error_logged() end
end

local function EscapePattern(text)
	return (text:gsub("%W", "%%%0"))
end

local function FindLocation(session, message)
	if not session.groups then return nil end
	local best_position, best_group, best_line
	for _, group in ipairs(session.groups) do
		local position, _, line = message:find(EscapePattern(group.title) .. ":(%d+):")
		if position and (not best_position or position < best_position) then
			best_position, best_group, best_line = position, group, tonumber(line)
		end
	end
	if not best_group then return nil end
	for _, part in ipairs(best_group.parts) do
		if best_line >= part.first and best_line < part.first + part.lines then
			return { index = part.index, line = best_line - part.first + 1, title = best_group.title }
		end
	end
	return nil
end

function APHCR.ReportLocated(session, message)
	local location = FindLocation(session, message)
	if location then
		session.first_location = session.first_location or location
		local file = session.file_list and session.file_list[location.index]
		if file then
			file.error_lines = file.error_lines or {}
			file.error_lines[location.line] = true
		end
	end
	APHCR.LogError(session.id, message, location)
end
local function HookReloadUI()
	local reloadui_key = GetString(SI_SLASH_RELOADUI)
	local original = SLASH_COMMANDS[reloadui_key]
	SLASH_COMMANDS[reloadui_key] = function(...)
		APHCR.PersistAll()
		APHCR.StopAll()
		if original then original(...) end
	end
end

local function OnAddOnLoaded(_, name)
	if name ~= APHCR.name then return end
	EVENT_MANAGER:UnregisterForEvent(APHCR.name, EVENT_ADD_ON_LOADED)
	LibAPH.RegisterAddonDependencies(APHCR.name, { "LibAPH" }, {})
	APHCR.sv = ZO_SavedVars:NewAccountWide("APHCodeRunner_SV", 1, GetWorldName() or "Default", {
		files = {}, addon_name = "", saved_names = "", font_size = 13, show_in_menus = true, chat_logs = true,
	})
	LoadFiles()
	SLASH_COMMANDS["/coderunner"] = APHCR.Toggle
	HookReloadUI()
end

EVENT_MANAGER:RegisterForEvent(APHCR.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
