local LCA = LibCombatAlerts
local Internal = LibCombatAlertsInternal


--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------

local POLLING_INTERVAL = 50
local GUIDE_THICKNESS = 2
local GUIDE_COLOR_NORMAL = 0xFFFFFF44
local GUIDE_COLOR_HILITE = 0xFFFFFFFF
local CENTER_SENSITIVITY = 12
local CENTER_THRESHOLD = 1000 -- 1s
local GAMEPAD_DEFAULT_TIMEOUT = 3000 -- 3s

local DEFAULT_OPTIONS = {
	color = 0xFFFFFFFF,
	size = 4,
}

local ANCHOR_POINTS = {
	L = {
		T = TOPLEFT,
		M = LEFT,
		B = BOTTOMLEFT,
	},
	C = {
		T = TOP,
		M = CENTER,
		B = BOTTOM,
	},
	R = {
		T = TOPRIGHT,
		M = RIGHT,
		B = BOTTOMRIGHT,
	},
}

local POSITION_NAMES = {
	left = { "X", "L" },
	center = { "X", "C" },
	right = { "X", "R" },
	top = { "Y", "T" },
	mid = { "Y", "M" },
	bottom = { "Y", "B" },
}

local EVENT_START = 1
local EVENT_STOP = 2


--------------------------------------------------------------------------------
-- LCA_MoveableControl
--------------------------------------------------------------------------------

local LCA_MoveableControl = Internal.BaseControlObject:Subclass()
LCA.MoveableControl = LCA_MoveableControl

-- Preserve GuiRoot to guard against redefinition
local GuiRoot = GuiRoot


--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local LinePool = { }
do
	local Pool
	local function GetPool( )
		if (not Pool) then
			Pool = ZO_ControlPool:New("LCA_MoveableControlLine")
		end
		return Pool
	end

	function LinePool.Add( parent, color, size, isX, isGuide )
		local control, key = GetPool():AcquireObject()
		control:ClearAnchors()
		control:SetParent(parent)
		control:SetEdgeColor(0, 0, 0, 0)
		control:SetCenterColor(LCA.UnpackRGBA(color))
		if (isX) then
			control:SetWidth(size)
		else
			control:SetHeight(size)
		end
		if (isGuide) then
			control:SetCenterTexture(LCA.GetTexture("misc-checkered16"), 16, TEX_MODE_WRAP)
			if (isX) then
				control:SetAnchor(TOP, parent, TOP, 0, 0)
				control:SetAnchor(BOTTOM, parent, BOTTOM, 0, 0, ANCHOR_CONSTRAINS_Y)
			else
				control:SetAnchor(LEFT, parent, LEFT, 0, 0)
				control:SetAnchor(RIGHT, parent, RIGHT, 0, 0, ANCHOR_CONSTRAINS_X)
			end
		else
			control:SetCenterTexture("")
		end
		control:SetHidden(false)
		return { control = control, key = key }
	end

	function LinePool.Remove( line )
		line.control:SetParent()
		line.control:SetHidden(true)
		GetPool():ReleaseObject(line.key)
	end
end

local ScreenGuide
local function GetScreenGuide( )
	if (not ScreenGuide) then
		ScreenGuide = WINDOW_MANAGER:CreateTopLevelWindow("LCA_MoveableControl_ScreenGuide")
		ScreenGuide:SetAnchorFill()
		LinePool.Add(ScreenGuide, GUIDE_COLOR_NORMAL, GUIDE_THICKNESS, true, true)
		LinePool.Add(ScreenGuide, GUIDE_COLOR_NORMAL, GUIDE_THICKNESS, false, true)
	end
	return ScreenGuide
end

local function SnapPosition( pos, snap )
	if (type(snap) == "number" and snap > 0) then
		for k, v in pairs(pos) do
			pos[k] = zo_round(v / snap) * snap
		end
	end
	return pos
end

local function PositionToAnchorParameters( pos, obj )
	obj = obj or { }
	local offsets = { }

	for name, data in pairs(POSITION_NAMES) do
		if (type(pos[name]) == "number") then
			obj[data[1]] = data[2]
			offsets[data[1]] = pos[name]
		end
	end

	local anchorPoint = ANCHOR_POINTS[obj.X][obj.Y]
	return anchorPoint, GuiRoot, anchorPoint, offsets.X or 0, offsets.Y or 0
end


--------------------------------------------------------------------------------
-- Public interface
--------------------------------------------------------------------------------

LCA.EVENT_CONTROL_MOVE_START = EVENT_START
LCA.EVENT_CONTROL_MOVE_STOP = EVENT_STOP

function LCA_MoveableControl:New( control, options )
	local obj = Internal.BaseControlObject.New(self, "LCA_MoveableControl")

	obj.control = control
	obj.options = LCA.PopulateOptions(options, DEFAULT_OPTIONS)

	-- Fallback defaults
	obj.X = "L"
	obj.Y = "T"

	-- Initialize callbacks
	obj.callbacks = {
		[EVENT_START] = { },
		[EVENT_STOP] = { },
	}

	obj.activeMovement = false

	control:SetHandler("OnMoveStart", function() obj:OnMoveStart() end)
	control:SetHandler("OnMoveStop", function() obj:OnMoveStop() end)

	return obj
end

function LCA_MoveableControl:UpdatePosition( pos )
	self.posCache = pos
	self.control:ClearAnchors()
	self.control:SetAnchor(PositionToAnchorParameters(pos, self))
end

function LCA_MoveableControl:GetPosition( bypassCache )
	if (bypassCache or not self.posCache) then
		local control = self.control
		local pos = { }

		if (self.X == "C") then
			pos.center = control:GetCenter() - GuiRoot:GetCenter()
		elseif (self.X == "R") then
			pos.right = control:GetRight() - GuiRoot:GetRight()
		else
			pos.left = control:GetLeft()
		end

		if (self.Y == "M") then
			pos.mid = select(2, control:GetCenter()) - select(2, GuiRoot:GetCenter())
		elseif (self.Y == "B") then
			pos.bottom = control:GetBottom() - GuiRoot:GetBottom()
		else
			pos.top = control:GetTop()
		end

		self.posCache = pos
	end

	return self.posCache
end

function LCA_MoveableControl:GetLeftTopPosition( )
	return {
		left = self.control:GetLeft(),
		top = self.control:GetTop(),
	}
end

function LCA_MoveableControl:GetAnchorFromPosition( pos )
	return ZO_Anchor:New(PositionToAnchorParameters(pos or self:GetPosition()))
end

function LCA_MoveableControl:ToggleLock( locked )
	self.control:SetMovable(locked ~= true)
end

function LCA_MoveableControl:SetSnap( snap )
	self.snap = snap
end

function LCA_MoveableControl:RegisterCallback( name, eventCode, callback )
	-- Passing nil for callback will unregister
	if (name and eventCode and self.callbacks[eventCode]) then
		self.callbacks[eventCode][name] = callback
	end
end


--------------------------------------------------------------------------------
-- Private functions; do not call these externally
--------------------------------------------------------------------------------

function LCA_MoveableControl:FireCallback( eventCode, ... )
	for _, callback in pairs(self.callbacks[eventCode]) do
		callback(...)
	end
end

function LCA_MoveableControl:ToggleLines( enable )
	if (enable and not self.lines) then
		local opt = self.options
		local lines = {
			LinePool.Add(self.control, opt.color, opt.size, true),
			LinePool.Add(self.control, opt.color, opt.size, false),
			LinePool.Add(self.control, GUIDE_COLOR_NORMAL, GUIDE_THICKNESS, true, true),
			LinePool.Add(self.control, GUIDE_COLOR_NORMAL, GUIDE_THICKNESS, false, true),
		}
		self.anchorX = lines[1].control
		self.anchorY = lines[2].control
		self.guideX = lines[3].control
		self.guideY = lines[4].control
		self.lines = lines
	elseif (not enable and self.lines) then
		for _, line in ipairs(self.lines) do
			LinePool.Remove(line)
		end
		self.lines = nil
	end
end

function LCA_MoveableControl:UpdateAnchorMarkers( )
	self.anchorX:ClearAnchors()
	self.anchorX:SetAnchor(ANCHOR_POINTS[self.X]["T"])
	self.anchorX:SetAnchor(BOTTOM, nil, nil, nil, nil, ANCHOR_CONSTRAINS_Y)

	self.anchorY:ClearAnchors()
	self.anchorY:SetAnchor(ANCHOR_POINTS["L"][self.Y])
	self.anchorY:SetAnchor(RIGHT, nil, nil, nil, nil, ANCHOR_CONSTRAINS_X)
end

function LCA_MoveableControl:ToggleMovement( enable )
	if (enable and not self.activeMovement) then
		self.activeMovement = true
		EVENT_MANAGER:RegisterForUpdate(self.ID, POLLING_INTERVAL, function() self:MovementPoll() end)
		self:ToggleLines(true)
		self:MovementPoll()
		self:UpdateAnchorMarkers()
		GetScreenGuide():SetHidden(false)
		WINDOW_MANAGER:SetMouseCursor(MOUSE_CURSOR_PAN)
	elseif (not enable and self.activeMovement) then
		self.activeMovement = false
		EVENT_MANAGER:UnregisterForUpdate(self.ID)
		self:MovementPoll()
		self:ToggleLines(false)
		GetScreenGuide():SetHidden(true)
		WINDOW_MANAGER:SetMouseCursor(MOUSE_CURSOR_DO_NOT_CARE)
	end
end

function LCA_MoveableControl:ToggleCenterHighlight( direction, time )
	local key = "time" .. direction
	if (not self[key] and time) then
		self[key] = time
		self["guide" .. direction]:SetCenterColor(LCA.UnpackRGBA(GUIDE_COLOR_HILITE))
	elseif (self[key] and not time) then
		self[key] = nil
		self["guide" .. direction]:SetCenterColor(LCA.UnpackRGBA(GUIDE_COLOR_NORMAL))
	end
end

function LCA_MoveableControl:MovementPoll( )
	local currentTime = GetGameTimeMilliseconds()

	if (self.X ~= "C" and zo_abs(self.control:GetCenter() - GuiRoot:GetCenter()) < CENTER_SENSITIVITY) then
		self:ToggleCenterHighlight("X", currentTime)
		if (currentTime - self.timeX > CENTER_THRESHOLD) then
			self.X = "C"
			self:ToggleCenterHighlight("X")
			self:UpdateAnchorMarkers()
		end
	else
		self:ToggleCenterHighlight("X")
		if (self.X ~= "L" and self.control:GetLeft() <= 0) then
			self.X = "L"
			self:UpdateAnchorMarkers()
		elseif (self.X ~= "R" and self.control:GetRight() >= GuiRoot:GetWidth()) then
			self.X = "R"
			self:UpdateAnchorMarkers()
		end
	end

	if (self.Y ~= "M" and zo_abs(select(2, self.control:GetCenter()) - select(2, GuiRoot:GetCenter())) < CENTER_SENSITIVITY) then
		self:ToggleCenterHighlight("Y", currentTime)
		if (currentTime - self.timeY > CENTER_THRESHOLD) then
			self.Y = "M"
			self:ToggleCenterHighlight("Y")
			self:UpdateAnchorMarkers()
		end
	else
		self:ToggleCenterHighlight("Y")
		if (self.Y ~= "T" and self.control:GetTop() <= 0) then
			self.Y = "T"
			self:UpdateAnchorMarkers()
		elseif (self.Y ~= "B" and self.control:GetBottom() >= GuiRoot:GetHeight()) then
			self.Y = "B"
			self:UpdateAnchorMarkers()
		end
	end
end

function LCA_MoveableControl:OnMoveStart( )
	self:ToggleMovement(true)
	self:FireCallback(EVENT_START)
end

function LCA_MoveableControl:OnMoveStop( )
	self:ToggleMovement(false)
	local pos = SnapPosition(self:GetPosition(true), self.snap)
	self:UpdatePosition(pos)
	self:FireCallback(EVENT_STOP, pos)
end


--------------------------------------------------------------------------------
-- Gamepad
--------------------------------------------------------------------------------

-- Global, since only one control should be moved at at time
local ActiveGamepadMove = false
local UpdateKey = "LCA_MoveableControl_GamepadPoll"

-- Public API
function LCA_MoveableControl:ToggleGamepadMove( enable, timeout )
	if (enable and not ActiveGamepadMove) then
		ActiveGamepadMove = true
		local currentTime = GetGameTimeMilliseconds()
		self.gamepadMove = {
			lastTick = currentTime,
			lastMove = currentTime,
			timeout = timeout or GAMEPAD_DEFAULT_TIMEOUT,
			x = self.control:GetLeft(),
			y = self.control:GetTop(),
		}
		EVENT_MANAGER:RegisterForUpdate(UpdateKey, 0, function() self:GamepadPoll() end)
		self:OnMoveStart()
	elseif (not enable and self.activeMovement) then
		-- While starting movement checks a global state, stopping needs to check a local state
		ActiveGamepadMove = false
		EVENT_MANAGER:UnregisterForUpdate(UpdateKey)
		SetGamepadRightStickConsumedByUI(false)
		self:OnMoveStop()
	end
end

-- Private
function LCA_MoveableControl:GamepadPoll( )
	local gp = self.gamepadMove

	-- Read and then consume the right stick; consumption applies only for the
	-- current frame, which is why it is necessary to check and consume this
	-- input for every frame.
	local x, y = ZO_Gamepad_GetRightStickEasedX(), ZO_Gamepad_GetRightStickEasedY()
	SetGamepadRightStickConsumedByUI(true)

	-- Tick rate varies by fps, so take that into account for speed
	local currentTime = GetGameTimeMilliseconds()
	local interval = currentTime - gp.lastTick
	gp.lastTick = currentTime

	local magnitude = zo_sqrt(x * x + y * y)
	if (magnitude >= 0.02) then
		local speed = magnitude * interval
		gp.lastMove = currentTime
		gp.x = zo_clamp(gp.x + x * speed, 0, 1 + GuiRoot:GetWidth() - self.control:GetWidth())
		gp.y = zo_clamp(gp.y + -y * speed, 0, 1 + GuiRoot:GetHeight() - self.control:GetHeight())
		self.control:ClearAnchors()
		self.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, gp.x, gp.y)
	end

	if (currentTime - gp.lastMove >= gp.timeout) then
		self:ToggleGamepadMove(false)
	end
end
