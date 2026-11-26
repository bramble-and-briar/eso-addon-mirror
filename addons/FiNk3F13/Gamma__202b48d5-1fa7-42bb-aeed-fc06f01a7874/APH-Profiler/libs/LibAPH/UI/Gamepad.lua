--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")

local GetGameTimeMilliseconds = GetGameTimeMilliseconds
local ZO_Gamepad_GetRightStickEasedX = ZO_Gamepad_GetRightStickEasedX
local ZO_Gamepad_GetRightStickEasedY = ZO_Gamepad_GetRightStickEasedY
local SetGamepadRightStickConsumedByUI = SetGamepadRightStickConsumedByUI
local GuiRoot = GuiRoot
local LibAPH = LibAPH

function LibAPH.CreateGamepadMover(target)
	local GAMEPAD_TIMEOUT_MS = 3000
	local poll_key = "LibAPH_GamepadMove_" .. tostring(target)
	local mover = {}
	local gp = nil

	local function stop_move()
		local moved = gp and gp.moved or false
		gp = nil
		EVENT_MANAGER:UnregisterForUpdate(poll_key)
		SetGamepadRightStickConsumedByUI(false)
		if mover.on_move_stop then
			mover.on_move_stop({ left = target:GetLeft(), top = target:GetTop(), moved = moved })
		end
	end

	local function poll()
		local x, y = ZO_Gamepad_GetRightStickEasedX(), ZO_Gamepad_GetRightStickEasedY()
		SetGamepadRightStickConsumedByUI(true)

		local now = GetGameTimeMilliseconds()
		local interval = now - gp.last_tick
		gp.last_tick = now

		local magnitude = zo_sqrt(x * x + y * y)
		if magnitude >= 0.02 then
			local speed = magnitude * interval
			gp.last_move = now
			gp.moved = true
			gp.x = zo_clamp(gp.x + x * speed, 0, 1 + GuiRoot:GetWidth() - target:GetWidth())
			gp.y = zo_clamp(gp.y + -y * speed, 0, 1 + GuiRoot:GetHeight() - target:GetHeight())
			target:ClearAnchors()
			target:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, gp.x, gp.y)
		end

		if now - gp.last_move >= gp.timeout_ms then
			stop_move()
		end
	end

	function mover:ToggleGamepadMove(enable, timeout_ms)
		if enable and not gp then
			local now = GetGameTimeMilliseconds()
			gp = { last_tick = now, last_move = now, x = target:GetLeft(), y = target:GetTop(), timeout_ms = timeout_ms or GAMEPAD_TIMEOUT_MS }
			EVENT_MANAGER:RegisterForUpdate(poll_key, 0, poll)
		elseif not enable and gp then
			stop_move()
		end
	end

	function mover:IsMoving()
		return gp ~= nil
	end

	function mover:RegisterCallback(name, event_code, fn)
		mover.on_move_stop = fn
	end

	return mover
end

function LibAPH.CreateGamepadResizer(target, opts)
	opts = opts or {}
	local GAMEPAD_TIMEOUT_MS = 3000
	local poll_key = "LibAPH_GamepadResize_" .. tostring(target)
	local resizer = {}
	local gp = nil

	local function Limit(value)
		if type(value) == "function" then return value() end
		return value
	end

	local function stop_resize()
		gp = nil
		EVENT_MANAGER:UnregisterForUpdate(poll_key)
		SetGamepadLeftStickConsumedByUI(false)
		if opts.onResizeStop then opts.onResizeStop(target) end
	end

	local function poll()
		local x, y = ZO_Gamepad_GetLeftStickEasedX(), ZO_Gamepad_GetLeftStickEasedY()
		SetGamepadLeftStickConsumedByUI(true)

		local now = GetGameTimeMilliseconds()
		local interval = now - gp.last_tick
		gp.last_tick = now

		local magnitude = zo_sqrt(x * x + y * y)
		if magnitude >= 0.02 then
			local speed = magnitude * interval
			gp.last_move = now
			local min_w, min_h = Limit(opts.minWidth) or 50, Limit(opts.minHeight) or 50
			gp.w = zo_clamp(gp.w + x * speed, min_w, math.max(min_w, GuiRoot:GetWidth() - target:GetLeft()))
			gp.h = zo_clamp(gp.h + -y * speed, min_h, math.max(min_h, GuiRoot:GetHeight() - target:GetTop()))
			target:SetDimensions(gp.w, gp.h)
			if opts.onResizing then opts.onResizing(target) end
		end

		if now - gp.last_move >= GAMEPAD_TIMEOUT_MS then
			stop_resize()
		end
	end

	function resizer:ToggleGamepadResize(enable)
		if enable and not gp then
			local now = GetGameTimeMilliseconds()
			gp = { last_tick = now, last_move = now, w = target:GetWidth(), h = target:GetHeight() }
			EVENT_MANAGER:RegisterForUpdate(poll_key, 0, poll)
		elseif not enable and gp then
			stop_resize()
		end
	end

	function resizer:IsResizing()
		return gp ~= nil
	end

	return resizer
end

local GAMEPAD_KEYBIND_STYLES = { "KEYBIND_STRIP_GAMEPAD_STYLE", "KEYBIND_STRIP_WITH_GENERIC_FOOTER_GAMEPAD_STYLE" }
local ERROR_FRAME_KEYBIND_BUTTONS = { "dismissKeybind", "suppressKeybind", "reloadKeybind", "copyKeybind", "moreInfoKeybind" }

local function RefreshScrollHintsAsGamepad(self)
	local hide = not self.inputEnabled or not self.canScroll
	if self.scrollIndicator then self.scrollIndicator:SetHidden(hide) end
	if self.scrollKeyUp then self.scrollKeyUp:SetHidden(true) end
	if self.scrollKeyDown then self.scrollKeyDown:SetHidden(true) end
end

function LibAPH.ForceControllerKeybindIcons()
	for _, name in ipairs(GAMEPAD_KEYBIND_STYLES) do
		local style = _G[name]
		if type(style) == "table" then style.alwaysPreferGamepadMode = true end
	end
	local error_frame = ZO_ERROR_FRAME
	if error_frame then
		for _, key in ipairs(ERROR_FRAME_KEYBIND_BUTTONS) do
			local button = error_frame[key]
			if button and button.keybind and button.SetKeybind then
				pcall(button.SetKeybind, button, button.keybind, nil, button.gamepadPreferredKeybind, true)
			end
		end
	end
	if type(ZO_ScrollTooltip_Gamepad) == "table" then
		rawset(ZO_ScrollTooltip_Gamepad, "RefreshDisplayedKeybinds", RefreshScrollHintsAsGamepad)
	end
	local tooltips = GAMEPAD_TOOLTIPS and GAMEPAD_TOOLTIPS.tooltips
	if type(tooltips) == "table" then
		for _, info in pairs(tooltips) do
			local tip = info.control and info.control.container and info.control.container.tip
			if tip and tip.initialized ~= false and tip.RefreshDisplayedKeybinds then
				tip.RefreshDisplayedKeybinds = RefreshScrollHintsAsGamepad
				tip:RefreshDisplayedKeybinds()
			end
		end
	end
end

