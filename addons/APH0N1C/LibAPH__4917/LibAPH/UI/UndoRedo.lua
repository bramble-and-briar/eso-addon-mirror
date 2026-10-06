--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH

local DEFAULT_MAX_STEPS = 200
local DEFAULT_COALESCE_MS = 700
local BIG_CHANGE_CHARS = 8

local function NewState(text, cursor)
	return { undo = {}, redo = {}, text = text, cursor = cursor, time = 0, direction = 0 }
end

function LibAPH.EnableUndoRedo(edit, opts)
	if edit.libaph_history then return edit.libaph_history end
	opts = opts or {}
	local max_steps = opts.maxSteps or DEFAULT_MAX_STEPS
	local coalesce_ms = opts.coalesceMs or DEFAULT_COALESCE_MS

	local history = {}
	local state = NewState(edit:GetText(), edit:GetCursorPosition())
	local applying = false

	local function Push(stack, entry)
		stack[#stack + 1] = entry
		if #stack > max_steps then table.remove(stack, 1) end
	end

	local function OnChanged()
		if applying then return end
		local text = edit:GetText()
		if text == state.text then return end
		local delta = #text - #state.text
		local direction = delta > 0 and 1 or -1
		local now = GetFrameTimeMilliseconds()
		local starts_new_step = #state.undo == 0
			or now - state.time > coalesce_ms
			or math.abs(delta) > BIG_CHANGE_CHARS
			or direction ~= state.direction
		if starts_new_step then Push(state.undo, { text = state.text, cursor = state.cursor }) end
		state.redo = {}
		state.text, state.cursor = text, edit:GetCursorPosition()
		state.time, state.direction = now, direction
	end
	ZO_PostHookHandler(edit, "OnTextChanged", OnChanged)

	local function Apply(entry)
		applying = true
		edit:SetText(entry.text)
		edit:SetCursorPosition(math.min(entry.cursor, #entry.text))
		applying = false
		state.text, state.cursor = entry.text, entry.cursor
		state.time, state.direction = 0, 0
	end

	function history:Undo()
		local entry = table.remove(state.undo)
		if not entry then return false end
		Push(state.redo, { text = state.text, cursor = state.cursor })
		Apply(entry)
		return true
	end

	function history:Redo()
		local entry = table.remove(state.redo)
		if not entry then return false end
		Push(state.undo, { text = state.text, cursor = state.cursor })
		Apply(entry)
		return true
	end

	function history:CanUndo() return #state.undo > 0 end
	function history:CanRedo() return #state.redo > 0 end

	function history:RunSilently(change)
		applying = true
		change()
		applying = false
		state.text, state.cursor = edit:GetText(), edit:GetCursorPosition()
		state.time, state.direction = 0, 0
	end

	function history:Reset()
		state = NewState(edit:GetText(), edit:GetCursorPosition())
	end

	function history:GetCounts() return #state.undo, #state.redo end

	function history:TakeState()
		local taken = state
		state = NewState(edit:GetText(), edit:GetCursorPosition())
		return taken
	end

	function history:SetState(new_state)
		if new_state and new_state.text == edit:GetText() then
			state = new_state
		else
			state = NewState(edit:GetText(), edit:GetCursorPosition())
		end
	end

	edit.libaph_history = history
	return history
end
