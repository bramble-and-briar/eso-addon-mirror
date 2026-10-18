--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local FG = APHFPSGraphCore
local Pad = {}
FG.Pad = Pad

local LAYER = "APHFPSGraph_Focus"
local WAIT_JOB = "APHFPSGraph_PadControl"
local HOLD_JOB = "APHFPSGraph_PadHold"
local HOLD = { delay = 250, slow = 120, fast = 600, ramp = 1500 }

local focus = false
local focus_handle
local dismissed = false
local watching = false
local hint_bar
local order = { "graph" }

local function IsPad() return IsConsoleUI() or IsInGamepadPreferredMode() end

local function PadKey(action)
	return LibAPH.GetKeybindMarkup(action)
end

local WINDOWS = {
	timeline = function()
		if FG.Timeline.IsShown() then return FG.Timeline.Window(), FG.Timeline.Mover(), FG.Timeline.Resizer() end
	end,
	summary = function()
		if FG.Summary.IsShown() then return FG.Summary.Window(), FG.Summary.Mover(), FG.Summary.Resizer() end
	end,
	graph = function()
		if FG.Graph.IsOpen() then return FG.Graph.Window(), not FG.Graph.IsPinned() and FG.Graph.Mover() or nil, FG.Graph.Resizer() end
	end,
}

function Pad.Active()
	for i = #order, 1, -1 do
		local win, mover, resizer = WINDOWS[order[i]]()
		if win then return order[i], win, mover, resizer end
	end
	for _, kind in ipairs({ "timeline", "summary", "graph" }) do
		local win, mover, resizer = WINDOWS[kind]()
		if win then return kind, win, mover, resizer end
	end
	return nil
end

function Pad.HintParts()
	local parts = {}
	local function Add(text, ...)
		local keys = {}
		for _, action in ipairs({ ... }) do keys[#keys + 1] = PadKey(action) end
		parts[#parts + 1] = table.concat(keys, "") .. " " .. text
	end
	if LibAPH.GetContextMenuDepth() > 0 then
		Add(FG.L("PAD_CHOOSE"), "UI_SHORTCUT_PRIMARY")
		Add(FG.L("PAD_BACK"), "UI_SHORTCUT_NEGATIVE")
		return parts
	end
	local kind, _, mover, resizer = Pad.Active()
	Add(FG.Sampler.IsRecording() and FG.L("STOP_RECORDING") or FG.L("START_RECORDING"), "UI_SHORTCUT_SECONDARY")
	Add(FG.L("PAD_MENU"), "UI_SHORTCUT_TERTIARY")
	Add(FG.Summary.IsShown() and FG.L("HIDE_SUMMARY") or FG.L("SUMMARY"), "UI_SHORTCUT_LEFT_SHOULDER")
	Add(FG.Timeline.IsShown() and FG.L("HIDE_TIMELINE") or FG.L("TIMELINE"), "UI_SHORTCUT_RIGHT_SHOULDER")
	if kind == "timeline" or kind == "graph" then
		Add(FG.L("PAD_ZOOM"), "UI_SHORTCUT_LEFT_TRIGGER", "UI_SHORTCUT_RIGHT_TRIGGER")
		Add(kind == "timeline" and FG.L("PAD_MOVE") or FG.L("PAD_PAN"), "UI_SHORTCUT_INPUT_LEFT", "UI_SHORTCUT_INPUT_RIGHT")
	end
	if mover then Add(mover:IsMoving() and FG.L("PAD_MOVING") or FG.L("PAD_MOVE"), "UI_SHORTCUT_RIGHT_STICK") end
	if resizer then Add(resizer:IsResizing() and FG.L("PAD_RESIZING") or FG.L("PAD_RESIZE"), "UI_SHORTCUT_LEFT_STICK") end
	Add(FG.L("PAD_CLOSE"), "UI_SHORTCUT_NEGATIVE")
	return parts
end

function Pad.HintText()
	return table.concat(Pad.HintParts(), "   ")
end

local function BuildHints()
	if hint_bar or not LibAPH.CreatePadHintBar then return end
	hint_bar = LibAPH.CreatePadHintBar("APHFPSGraphPadHints")
end

function Pad.Refresh()
	if not hint_bar then return false end
	local _, owner = Pad.Active()
	if not (focus and IsPad() and owner ~= nil and FG.saved.pad_hints ~= false) then
		FG.hint_below, FG.hint_above = hint_bar:Hide()
		return false
	end
	FG.hint_below, FG.hint_above = hint_bar:Show(owner, Pad.HintParts())
	return true
end

function Pad.GetHintText()
	return hint_bar and hint_bar:GetText() or nil
end

local function SetLayer(on)
	local active = IsActionLayerActiveByName(LAYER)
	if on and not active then
		PushActionLayerByName(LAYER)
	elseif not on and active then
		RemoveActionLayerByName(LAYER)
	end
end

local function StopTools()
	for _, get in ipairs({ FG.Graph.Mover, FG.Summary.Mover, FG.Timeline.Mover }) do
		local mover = get()
		if mover then mover:ToggleGamepadMove(false) end
	end
	for _, get in ipairs({ FG.Graph.Resizer, FG.Summary.Resizer, FG.Timeline.Resizer }) do
		local resizer = get()
		if resizer then resizer:ToggleGamepadResize(false) end
	end
end

local BUTTONS = {
	up = function() return Pad.Move(-1) end,
	down = function() return Pad.Move(1) end,
	a = function() return Pad.Select() end,
	x = function() return Pad.Action("record") end,
	y = function() return Pad.Action("menu") end,
	lb = function() return Pad.Action("summary") end,
	rb = function() return Pad.Action("timeline") end,
	lt = function() return Pad.Action("zoom_out") end,
	rt = function() return Pad.Action("zoom_in") end,
	left = function() return Pad.Action("pan_left") end,
	right = function() return Pad.Action("pan_right") end,
	rs = function() return Pad.Action("move") end,
	ls = function() return Pad.Action("resize") end,
	b = function() return Pad.Action("back") end,
}

local SPEC = {
	canFocus = function(auto) return IsPad() and Pad.Active() ~= nil and not (auto and dismissed) end,
	onFocus = function()
		BuildHints()
		focus = true
		Pad.Refresh()
	end,
	onBlur = function()
		focus = false
		Pad.StopHold()
		LibAPH.CloseContextMenu()
		StopTools()
		Pad.Refresh()
	end,
	buttons = BUTTONS,
	release = { left = function() Pad.StopHold() end, right = function() Pad.StopHold() end },
}

local function OwnLayer()
	local handle, on = {}, false
	handle.Request = function(_, auto)
		if not SPEC.canFocus(auto == true) then return false end
		if on then return true end
		on = true
		SetLayer(true)
		SPEC.onFocus()
		return true
	end
	handle.Release = function()
		if not on then return false end
		on = false
		SetLayer(false)
		SPEC.onBlur("released")
		return true
	end
	handle.IsFocused = function() return on end
	return handle
end

local function Focus()
	focus_handle = focus_handle or (LibAPH.RegisterPadFocus and LibAPH.RegisterPadFocus("APH-FPSGraph", SPEC)) or OwnLayer()
	return focus_handle
end

function Pad.Press(button)
	if not (focus_handle and focus_handle:IsFocused() and SPEC.canFocus(false)) then return false end
	local fn = BUTTONS[button]
	return fn ~= nil and fn() == true
end

function Pad.Release(button)
	local fn = SPEC.release[button]
	if fn then fn() end
	return false
end

function Pad.IsFocused() return focus end

function Pad.Stop(pass_on)
	if not focus then return false end
	return Focus():Release(pass_on == true)
end

function Pad.Start()
	if not IsPad() or not Pad.Active() then return false end
	local focused = Focus():Request(false)
	Pad.Refresh()
	return focused
end

function Pad.ToggleFocus()
	if focus then return Pad.Stop() end
	if not FG.Graph.IsOpen() and not FG.Summary.IsShown() and not FG.Timeline.IsShown() then
		FG.saved.enabled = true
		FG.Apply()
	end
	return Pad.Start()
end

local function GameScreenShown()
	return LibAPH.IsGameScreenShown()
end

function Pad.EnsureConsoleControl()
	if not IsConsoleUI() or focus or dismissed or not Pad.Active() then return false end
	if GameScreenShown() then return Focus():Request(true) end
	LibAPH.ScheduleWait(WAIT_JOB, GameScreenShown, function()
		if not focus and not dismissed and Pad.Active() then Focus():Request(true) end
	end)
	return true
end

local function WatchScenes()
	if watching or not IsConsoleUI() then return end
	watching = true
	SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, _, new_state)
		local name = scene and scene:GetName()
		local game_screen = name == "hud" or name == "hudui"
		if new_state == SCENE_SHOWN and game_screen then
			Pad.EnsureConsoleControl()
		elseif new_state == SCENE_SHOWING and not game_screen and focus then
			Pad.Stop()
		end
	end)
end

function Pad.Opened(kind)
	for i = #order, 1, -1 do
		if order[i] == kind then table.remove(order, i) end
	end
	order[#order + 1] = kind
	dismissed = false
	WatchScenes()
	Pad.EnsureConsoleControl()
	return Pad.Refresh()
end

function Pad.OpenGraph()
	FG.saved.enabled = true
	FG.Apply()
	Pad.Opened("graph")
	if not IsPad() then return true end
	if GameScreenShown() then return Pad.Start() end
	SCENE_MANAGER:ShowBaseScene()
	LibAPH.ScheduleWait(WAIT_JOB, GameScreenShown, function() Pad.Start() end)
	return true
end

function Pad.OpenResults()
	FG.Summary.Show()
	if not IsPad() then return true end
	if GameScreenShown() then return Pad.Start() end
	SCENE_MANAGER:ShowBaseScene()
	LibAPH.ScheduleWait(WAIT_JOB, GameScreenShown, function() Pad.Start() end)
	return true
end

local function ToggleMove()
	local kind, _, mover, resizer = Pad.Active()
	if not mover then return false end
	local moving = not mover:IsMoving()
	if moving and kind == "graph" and FG.Graph.IsPinned() then return false end
	if moving and resizer then resizer:ToggleGamepadResize(false) end
	mover:ToggleGamepadMove(moving)
	if moving and kind == "graph" then FG.Graph.WatchAlign() end
	return true
end

local function ToggleResize()
	local _, _, mover, resizer = Pad.Active()
	if not resizer then return false end
	local resizing = not resizer:IsResizing()
	if resizing and mover then mover:ToggleGamepadMove(false) end
	resizer:ToggleGamepadResize(resizing)
	return true
end

local function Back()
	local kind, _, mover, resizer = Pad.Active()
	if mover and mover:IsMoving() then
		mover:ToggleGamepadMove(false)
	elseif resizer and resizer:IsResizing() then
		resizer:ToggleGamepadResize(false)
	elseif kind == "timeline" then
		FG.Timeline.Hide()
	elseif kind == "summary" then
		FG.Summary.Hide()
	else
		dismissed = true
		FG.saved.enabled = false
		FG.Apply()
		Pad.Stop(true)
	end
	return true
end

local function OnView(name)
	return function()
		local kind = Pad.Active()
		if kind == "timeline" then FG.Timeline[name]() elseif kind == "graph" then FG.Graph[name]() end
		return true
	end
end

function Pad.StopHold()
	EVENT_MANAGER:UnregisterForUpdate(HOLD_JOB)
	return false
end

local function Step(direction)
	return function()
		local kind = Pad.Active()
		if kind == "graph" then FG.Graph[direction < 0 and "PanLeft" or "PanRight"]() end
		if kind ~= "timeline" then return true end
		Pad.StopHold()
		FG.Timeline.MoveCursor(direction)
		local started = GetGameTimeMilliseconds()
		local last = started
		EVENT_MANAGER:RegisterForUpdate(HOLD_JOB, 0, function()
			local now = GetGameTimeMilliseconds()
			local held, step = now - started, now - last
			last = now
			if held < HOLD.delay then return end
			if not (focus and Pad.Active() == "timeline" and LibAPH.GetContextMenuDepth() == 0) then return Pad.StopHold() end
			local speed = HOLD.slow + (HOLD.fast - HOLD.slow) * zo_clamp((held - HOLD.delay) / HOLD.ramp, 0, 1)
			if step > 0 and not FG.Timeline.MoveCursor(direction, speed * step / 1000) then return Pad.StopHold() end
		end)
		return true
	end
end

local ACTIONS = {
	record = function()
		if FG.Sampler.IsRecording() then FG.StopRecording() else FG.StartRecording() end
		return true
	end,
	menu = function()
		local _, owner = Pad.Active()
		FG.Graph.OpenMenu(owner)
		LibAPH.MoveContextMenuFocus(1)
		return true
	end,
	summary = function() return FG.Summary.Toggle() or true end,
	timeline = function() return FG.Timeline.Toggle() or true end,
	zoom_in = OnView("ZoomIn"),
	zoom_out = OnView("ZoomOut"),
	pan_left = Step(-1),
	pan_right = Step(1),
	move = ToggleMove,
	resize = ToggleResize,
	back = Back,
}

function Pad.Move(direction)
	if not focus then return false end
	if LibAPH.GetContextMenuDepth() > 0 then
		LibAPH.MoveContextMenuFocus(direction)
		Pad.Refresh()
	end
	return true
end

function Pad.Select()
	if not focus then return false end
	if LibAPH.GetContextMenuDepth() > 0 then LibAPH.ActivateContextMenuFocus() end
	Pad.Refresh()
	return true
end

function Pad.Action(name)
	if not focus or not IsPad() then return false end
	if LibAPH.GetContextMenuDepth() > 0 then
		if name == "back" then LibAPH.CloseContextMenuLevel() end
		Pad.Refresh()
		return true
	end
	local action = ACTIONS[name]
	if not action then return false end
	action()
	if not Pad.Active() then Pad.Stop(true) end
	Pad.Refresh()
	return true
end
