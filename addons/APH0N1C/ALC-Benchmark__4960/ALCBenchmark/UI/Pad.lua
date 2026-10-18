--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

local AB = ALCBenchmark
local view, WIN, THEME, Pad, UI, ShowSaved = AB.view, AB.WIN, AB.THEME, AB.Pad, AB.UI, AB.ShowSaved

local LAYER = "ALCBenchmark_Focus"
local HINT_LEVEL_STEP = 10
local HINT_GAP = 4
local HINT_PAD = 6
local hint_box, hint_lbl
local resume_focus = false
local watching = false
local focus

local function IsPad() return IsConsoleUI() or IsInGamepadPreferredMode() end
local HOLD = { first = 300, slow = 90, fast = 30, fast_after = 1500, marker = 450 }
local SCROLL_LINES = 3

local function HintText()
	local parts = {}
	local function Add(text, action) parts[#parts + 1] = LibAPH.GetKeybindMarkup(action) .. " " .. text end
	if LibAPH.GetContextMenuDepth() > 0 then
		Add("Choose", "UI_SHORTCUT_PRIMARY")
		Add("Back", "UI_SHORTCUT_NEGATIVE")
		return table.concat(parts, "   ")
	end
	Add("Options", "UI_SHORTCUT_TERTIARY")
	parts[#parts + 1] = LibAPH.GetKeybindMarkup("UI_SHORTCUT_LEFT_SHOULDER") .. LibAPH.GetKeybindMarkup("UI_SHORTCUT_RIGHT_SHOULDER") .. " Page"
	if view.page == "timeline" then
		parts[#parts + 1] = LibAPH.GetKeybindMarkup("UI_SHORTCUT_LEFT_TRIGGER") .. LibAPH.GetKeybindMarkup("UI_SHORTCUT_RIGHT_TRIGGER") .. " Zoom"
		parts[#parts + 1] = LibAPH.GetKeybindMarkup("UI_SHORTCUT_INPUT_LEFT") .. LibAPH.GetKeybindMarkup("UI_SHORTCUT_INPUT_RIGHT") .. " Move"
	end
	if view.page ~= "timeline" and (view.max_first or 1) > 1 then
		parts[#parts + 1] = LibAPH.GetKeybindMarkup("UI_SHORTCUT_INPUT_LEFT") .. LibAPH.GetKeybindMarkup("UI_SHORTCUT_INPUT_RIGHT") .. " Scroll"
	end
	if view.page ~= "timeline" and (view.max_top or 0) > 0 then
		parts[#parts + 1] = LibAPH.GetKeybindMarkup("UI_SHORTCUT_INPUT_UP") .. LibAPH.GetKeybindMarkup("UI_SHORTCUT_INPUT_DOWN") .. " Rows"
	end
	Add(AB.mover:IsMoving() and "Moving" or "Move", "UI_SHORTCUT_RIGHT_STICK")
	Add(AB.resizer:IsResizing() and "Resizing" or "Resize", "UI_SHORTCUT_LEFT_STICK")
	Add((AB.mover:IsMoving() or AB.resizer:IsResizing()) and "Done" or "Close", "UI_SHORTCUT_NEGATIVE")
	return table.concat(parts, "   ")
end

local function BuildHints()
	if hint_box then return end
	hint_box = WINDOW_MANAGER:CreateTopLevelWindow(WIN .. "PadHints")
	hint_box:SetDrawTier(DT_HIGH)
	hint_box:SetHidden(true)
	LibAPH.ApplyPanelBackdrop(hint_box, WIN .. "PadHintsBG", THEME.BG_HUD)
	hint_lbl = WINDOW_MANAGER:CreateControl(WIN .. "PadHintsText", hint_box, CT_LABEL)
	hint_lbl:SetFont("ZoFontGamepad18")
	hint_lbl:SetColor(0.9, 0.9, 0.9, 1)
	hint_lbl:SetAnchor(TOPLEFT, hint_box, TOPLEFT, HINT_PAD, HINT_PAD)
end

function Pad.Refresh()
	Pad.hint_below, Pad.hint_above = 0, 0
	if not hint_box then return false end
	local show = Pad.focus and IsPad() and UI.IsShown() and UI.On("pad_hints")
	hint_box:SetHidden(not show)
	if not show then return false end
	hint_box:SetDrawLayer(AB.win:GetDrawLayer())
	hint_box:SetDrawLevel(AB.win:GetDrawLevel() + HINT_LEVEL_STEP)
	local width = math.max(AB.win:GetWidth(), 300)
	hint_lbl:SetWidth(width - HINT_PAD * 2)
	hint_lbl:SetText(HintText())
	local height = hint_lbl:GetTextHeight() + HINT_PAD * 2
	hint_box:SetDimensions(width, height)
	hint_box:ClearAnchors()
	if AB.win:GetBottom() + HINT_GAP + height > GuiRoot:GetHeight() then
		hint_box:SetAnchor(BOTTOMLEFT, AB.win, TOPLEFT, 0, -HINT_GAP)
		Pad.hint_above = height + HINT_GAP
	else
		hint_box:SetAnchor(TOPLEFT, AB.win, BOTTOMLEFT, 0, HINT_GAP)
		Pad.hint_below = height + HINT_GAP
	end
	return true
end

function Pad.GetHintText()
	if not hint_box or hint_box:IsHidden() then return nil end
	return hint_lbl:GetText()
end

local function SetLayer(on)
	local active = IsActionLayerActiveByName(LAYER)
	if on and not active then
		PushActionLayerByName(LAYER)
	elseif not on and active then
		RemoveActionLayerByName(LAYER)
	end
end

local BUTTONS = {
	up = function() return Pad.Move(-1) end,
	down = function() return Pad.Move(1) end,
	left = function() return Pad.Scroll(-1) end,
	right = function() return Pad.Scroll(1) end,
	lb = function() return Pad.Page(-1) end,
	rb = function() return Pad.Page(1) end,
	lt = function() return Pad.Zoom(-1) end,
	rt = function() return Pad.Zoom(1) end,
	a = function() return Pad.Select() end,
	y = function() return Pad.Action("menu") end,
	rs = function() return Pad.Action("move") end,
	ls = function() return Pad.Action("resize") end,
	b = function() return Pad.Action("back") end,
}

local SPEC = {
	canFocus = function(auto) return IsPad() and UI.IsShown() and not (auto and Pad.dismissed) end,
	onFocus = function()
		BuildHints()
		Pad.focus = true
		Pad.Refresh()
	end,
	onBlur = function()
		Pad.focus = false
		Pad.StopScroll()
		LibAPH.CloseContextMenu()
		if AB.mover then AB.mover:ToggleGamepadMove(false) end
		if AB.resizer then AB.resizer:ToggleGamepadResize(false) end
		Pad.Refresh()
	end,
	buttons = BUTTONS,
	release = { left = function() Pad.StopScroll() end, right = function() Pad.StopScroll() end },
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
	focus = focus or (LibAPH.RegisterPadFocus and LibAPH.RegisterPadFocus(AB.NAME, SPEC)) or OwnLayer()
	return focus
end

function Pad.Press(button)
	if not (focus and focus:IsFocused() and SPEC.canFocus(false)) then return false end
	local fn = BUTTONS[button]
	return fn ~= nil and fn() == true
end

function Pad.Release(button)
	local fn = SPEC.release[button]
	if fn then fn() end
	return false
end

function Pad.Stop(pass_on)
	if not Pad.focus then return false end
	return Focus():Release(pass_on == true)
end

local function WatchScenes()
	if watching then return end
	watching = true
	SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, _, new_state)
		local name = scene and scene:GetName()
		local game_screen = name == "hud" or name == "hudui"
		if new_state == SCENE_SHOWING and not game_screen and Pad.focus then
			resume_focus = Pad.Stop()
		elseif new_state == SCENE_SHOWN and game_screen and (resume_focus or IsConsoleUI()) then
			resume_focus = false
			if UI.IsShown() and not Pad.focus and not Pad.dismissed then Focus():Request(true) end
		end
	end)
end

function Pad.Start()
	if not IsPad() or not UI.IsShown() then return false end
	WatchScenes()
	resume_focus = false
	Pad.dismissed = false
	local focused = Focus():Request(false)
	Pad.Refresh()
	return focused
end

local function Toggle()
	if UI.IsShown() then return UI.Hide() end
	if not AB.test then ShowSaved() end
	UI.Show()
	Pad.Start()
end

function Pad.Ensure()
	if not IsConsoleUI() or Pad.focus or Pad.dismissed or not UI.IsShown() then return false end
	WatchScenes()
	if LibAPH.IsGameScreenShown() then return Focus():Request(true) end
	return false
end

function Pad.ToggleFocus()
	if Pad.focus then
		Pad.dismissed = true
		return Pad.Stop()
	end
	if not UI.IsShown() then return Pad.KeyToggle() end
	return Pad.Start()
end

function Pad.KeyToggle()
	if IsConsoleUI() and IsUnitInCombat("player") and not UI.IsShown() then return false end
	return Toggle()
end

function Pad.Move(direction)
	if not Pad.focus then return false end
	if LibAPH.GetContextMenuDepth() == 0 then
		if view.page == "timeline" then return false end
		return UI.ScrollRows(direction * SCROLL_LINES)
	end
	LibAPH.MoveContextMenuFocus(direction)
	Pad.Refresh()
	return true
end

function Pad.Page(direction)
	if not Pad.focus or LibAPH.GetContextMenuDepth() > 0 then return false end
	UI.StepPage(direction)
	return true
end

function Pad.Zoom(direction)
	if not Pad.focus or LibAPH.GetContextMenuDepth() > 0 then return false end
	return UI.ZoomTimeline(direction)
end

function Pad.StopScroll()
	EVENT_MANAGER:UnregisterForUpdate(LAYER .. "_Hold")
	return false
end

function Pad.Scroll(direction)
	if not Pad.focus or LibAPH.GetContextMenuDepth() > 0 then return false end
	Pad.StopScroll()
	if view.page ~= "timeline" then return UI.ScrollColumns(direction) end
	UI.MoveCursor(direction)
	local started = GetGameTimeMilliseconds()
	local next_at = started + (UI.TimelineMarkerAt(view.tl_cursor) and HOLD.marker or HOLD.first)
	EVENT_MANAGER:RegisterForUpdate(LAYER .. "_Hold", 20, function()
		local now = GetGameTimeMilliseconds()
		if now < next_at then return end
		if not (Pad.focus and view.page == "timeline") or not UI.MoveCursor(direction) then return Pad.StopScroll() end
		next_at = now + (UI.TimelineMarkerAt(view.tl_cursor) and HOLD.marker or (now - started >= HOLD.fast_after and HOLD.fast or HOLD.slow))
	end)
	return true
end

function Pad.Select()
	if not Pad.focus or LibAPH.GetContextMenuDepth() == 0 then return false end
	local depth = LibAPH.GetContextMenuDepth()
	LibAPH.ActivateContextMenuFocus()
	if LibAPH.GetContextMenuDepth() > depth then LibAPH.MoveContextMenuFocus(1) end
	Pad.Refresh()
	return true
end
AB.Toggle = Toggle

local ACTIONS = {
	menu = function() UI.OpenMenu() end,
	move = function()
		local moving = not AB.mover:IsMoving()
		if moving then AB.resizer:ToggleGamepadResize(false) end
		AB.mover:ToggleGamepadMove(moving)
	end,
	resize = function()
		local resizing = not AB.resizer:IsResizing()
		if resizing then AB.mover:ToggleGamepadMove(false) end
		AB.resizer:ToggleGamepadResize(resizing)
	end,
	back = function()
		if AB.mover:IsMoving() then
			AB.mover:ToggleGamepadMove(false)
		elseif AB.resizer:IsResizing() then
			AB.resizer:ToggleGamepadResize(false)
		else
			UI.Hide()
		end
	end,
}

function Pad.Action(name)
	if not Pad.focus or not IsPad() then return false end
	if LibAPH.GetContextMenuDepth() > 0 then
		if name == "back" then LibAPH.CloseContextMenuLevel() end
		Pad.Refresh()
		return true
	end
	local action = ACTIONS[name]
	if not action then return false end
	action()
	Pad.Refresh()
	return true
end
