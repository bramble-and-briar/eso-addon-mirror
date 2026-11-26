--[[
    Copyright © 2026 @APHONlC. All rights reserved.

    No copying, modification, distribution, or sale without prior written permission.
    AI/ML ingestion and training are strictly prohibited (TDM opt-out).

    See LICENSE.md for full terms and maintenance exceptions.
]]

assert(LibAPH, "LibAPH.lua must be loaded before this file")
local LibAPH = LibAPH
local GuiRoot = GuiRoot

local GAMEPAD_MOVE_TIMEOUT_MS = 5000
local HUD_WAIT_MS = 5000
local WATCH_MS = 50

function LibAPH.GetScreenThirdAlignAt(center_x, screen_w)
	if not center_x or not screen_w or screen_w <= 0 or center_x < screen_w / 3 then return TEXT_ALIGN_LEFT end
	if center_x > screen_w * 2 / 3 then return TEXT_ALIGN_RIGHT end
	return TEXT_ALIGN_CENTER
end

function LibAPH.GetScreenThirdAlign(control)
	local center_x = control and control:GetCenter()
	return LibAPH.GetScreenThirdAlignAt(center_x, GuiRoot:GetWidth())
end

local function IsHudShown()
	local current = SCENE_MANAGER:GetCurrentScene()
	if not current then return false end
	return current:GetName() == SCENE_MANAGER:GetHUDSceneName() and current:GetState() == SCENE_SHOWN
end

local function LeaveMenusToHud()
	if IsHudShown() then return end
	if SCENE_MANAGER:IsInUIMode() and SCENE_MANAGER:SetInUIMode(false) then return end
	SCENE_MANAGER:ShowBaseScene()
end

local function PointCoords(win, point)
	local left, top, right, bottom = win:GetLeft(), win:GetTop(), win:GetRight(), win:GetBottom()
	local x, y = (left + right) / 2, (top + bottom) / 2
	if point == LEFT or point == TOPLEFT or point == BOTTOMLEFT then x = left end
	if point == RIGHT or point == TOPRIGHT or point == BOTTOMRIGHT then x = right end
	if point == TOP or point == TOPLEFT or point == TOPRIGHT then y = top end
	if point == BOTTOM or point == BOTTOMLEFT or point == BOTTOMRIGHT then y = bottom end
	return x, y
end

function LibAPH.CreateWindowPosition(win, opts)
	assert(win and type(opts) == "table", "CreateWindowPosition needs a window and opts")
	assert(type(opts.get) == "function" and type(opts.set) == "function", "CreateWindowPosition needs opts.get and opts.set")
	assert(type(opts.placeDefault) == "function", "CreateWindowPosition needs opts.placeDefault")

	local pos = { window = win, mover = opts.mover }
	local job_name = "LibAPH_WindowPosition_" .. tostring(win)

	function pos:Apply()
		local x, y, point = opts.get()
		win:ClearAnchors()
		if x and y then
			win:SetAnchor(point or TOPLEFT, GuiRoot, TOPLEFT, x, y)
		else
			opts.placeDefault(win)
		end
	end

	function pos:Save()
		local point = opts.point or TOPLEFT
		local x, y = PointCoords(win, point)
		opts.set(x, y, point)
		self:Apply()
	end

	function pos:IsGamepadMoving()
		return self.mover ~= nil and self.mover:IsMoving()
	end

	function pos:StopGamepadMove()
		local waiting = LibAPH.GetScheduledJob(job_name)
		if waiting then waiting:Cancel() end
		if self.mover then self.mover:ToggleGamepadMove(false) end
	end

	function pos:Reset()
		self:StopGamepadMove()
		opts.set(nil, nil, nil)
		self:Apply()
	end

	function pos:StartGamepadMove()
		if not self.mover then return false end
		self:StopGamepadMove()
		LeaveMenusToHud()
		local give_up_at = GetFrameTimeMilliseconds() + HUD_WAIT_MS
		LibAPH.ScheduleWait(job_name, function()
			return IsHudShown() or GetFrameTimeMilliseconds() >= give_up_at
		end, function()
			if not IsHudShown() then return end
			win:SetHidden(false)
			self.mover:ToggleGamepadMove(true, opts.moveTimeoutMs or GAMEPAD_MOVE_TIMEOUT_MS)
			self:WatchMove()
		end)
		return true
	end

	local watch_name = job_name .. "_Watch"
	local mouse_moving = false

	function pos:WatchMove()
		if not opts.onMoving then return false end
		EVENT_MANAGER:RegisterForUpdate(watch_name, opts.watchMs or WATCH_MS, function()
			if not win:IsHidden() then opts.onMoving(win) end
			if not mouse_moving and not self:IsGamepadMoving() then EVENT_MANAGER:UnregisterForUpdate(watch_name) end
		end)
		return true
	end

	function pos:StopWatch()
		EVENT_MANAGER:UnregisterForUpdate(watch_name)
	end

	local function Stopped()
		pos:StopWatch()
		pos:Save()
		if opts.onMoveStop then opts.onMoveStop(win) end
	end

	win:SetHandler("OnMoveStart", function()
		mouse_moving = true
		pos:WatchMove()
	end)
	win:SetHandler("OnMoveStop", function()
		mouse_moving = false
		Stopped()
	end)

	local function ReapplyDefault()
		if pos:IsGamepadMoving() then return end
		local x, y = opts.get()
		if not (x and y) then pos:Apply() end
	end
	for index, anchor_control in ipairs(opts.follow or {}) do
		anchor_control:SetHandler("OnRectChanged", ReapplyDefault, job_name .. "_Follow" .. index)
	end

	if pos.mover then
		pos.mover:RegisterCallback(tostring(win), 2, function(stopped)
			if stopped and stopped.moved then Stopped() else pos:StopWatch() end
			if opts.onMoveEnd then opts.onMoveEnd(win) end
		end)
		SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(scene, _, new_state)
			if not scene or scene:GetName() ~= SCENE_MANAGER:GetHUDSceneName() then return end
			if new_state == SCENE_HIDING and pos:IsGamepadMoving() then
				pos.mover:ToggleGamepadMove(false)
			elseif new_state == SCENE_SHOWN and IsInGamepadPreferredMode() then
				ReapplyDefault()
			end
		end)
	end

	return pos
end
