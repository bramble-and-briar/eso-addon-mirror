-- The HUD guide: an arrow that points at the next stop (turning with the camera), the distance and which
-- stop it is; and, in the world itself, a trail of beads on the ground towards the stop and a beam of light
-- standing on it.
--
-- Console-safe on purpose, like PB's Compass: only fonts the client already has loaded (a font nothing else
-- draws with has to be built on use and has crashed a PS5), plain textures, nothing takes input.
--
-- THE 3D PART follows the client's own housing editor (esoui/ingame/housingeditor/housingeditorhud.lua): a
-- top-level window with Create3DRenderSpace, child textures that each have a render space, a position
-- given by WorldPositionToGuiRender3DPosition, and the camera's orientation read by
-- Set3DRenderSpaceToCurrentCamera on a control of ours. The beads are billboards: each is given the camera's
-- own orientation, so it faces the screen whatever the camera does and no convention of the 3D space has to
-- be guessed. The beam is turned about the vertical axis only (the camera's yaw), so it stays upright.
-- Nothing in the 3D part reads a map.
--
-- WHAT KEEPS THE GUIDE ON THE SCREEN. The update is restarted by itself after errors, the trail pauses and tries
-- again instead of giving up for the session, a position that is missing for a moment keeps the last direction on the
-- arrow, and every change that takes the guide away leaves a line in the trace (`/pbwp why`).
local A, S = PBS_WAYPOINT, PBS_WAYPOINT_STRINGS

local PATH = "PBsWayPoint/assets/"
local TICK_MS = 33 -- the guide is updated about thirty times a second
local ROTATION_EPS = 0.004 -- radians; below this the arrow is not turned again
local DEMO_MS = 20000
local MAX_TICK_ERRORS = 3
local TICK_RESTART_MS = 5000 -- after that many errors in a row the update waits this long and starts again
local MAX_TRAIL_ERRORS = 3
local TRAIL_PAUSE_MS = 10000 -- ... and the trail waits this long
local GRACE_MS = 4000 -- a position that is missing for this long keeps the arrow on the last direction

local BEAD_FIRST_M = 3 -- the first bead is this far from the player
local BEAD_STEP_M = 3.5
local MAX_BEADS = 12
local BEAD_LIFT_CM = 20 -- above the player's feet
local BEAD_SIZE_M = 0.45
local BEAM_HEIGHT_M = 80
local BEAM_MIN_DISTANCE_CM = 800 -- the beam is not drawn when the stop is this close

local DISTANCE_FONT = "ZoFontGamepadBold27"
local STEP_FONT = "ZoFontGamepad22"

local abs, floor, min, max = math.abs, math.floor, math.min, math.max
local Bearing, ScreenAngle = A.Bearing, A.ScreenAngle


local function Texture(name, parent, file, level)
	local c = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
	c:SetTexture(PATH .. file .. ".dds")
	c:SetDrawLayer(DL_CONTROLS)
	c:SetDrawLevel(level)
	c:SetMouseEnabled(false)
	return c
end

local function Label(name, parent, font)
	local label = WINDOW_MANAGER:CreateControl(name, parent, CT_LABEL)
	label:SetDrawLayer(DL_TEXT)
	label:SetMouseEnabled(false)
	label:SetFont(font)
	label:SetColor(1, 1, 1, 1)
	label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	return label
end

function A:CreateUI()
	local root = WINDOW_MANAGER:CreateTopLevelWindow("PBsWayPointRoot")
	root:SetHidden(true)
	root:SetMouseEnabled(false)
	root:SetMovable(false)
	root:SetDimensions(2, 2)
	self.root = root

	self.arrow = Texture("PBsWayPointArrow", root, "arrow", 0)
	self.arrow:SetHidden(true)
	self.distance = Label("PBsWayPointDistance", root, DISTANCE_FONT)
	self.distance:SetHidden(true)
	self.step = Label("PBsWayPointStep", root, STEP_FONT)
	self.step:SetHidden(true)
	self.shown = { arrow = false, distance = false, step = false }
end

function A:IsPreviewing()
	return self.panelOpen and self.sv.preview and self.active and true or false
end

-- Everything that depends on the settings. The next tick moves every piece again.
function A:ApplyLayout()
	local root = self.root
	if not root then
		return
	end
	local sv = self.sv
	local size = sv.arrowSize
	local previewing = self:IsPreviewing()

	root:ClearAnchors()
	root:SetAnchor(TOP, GuiRoot, TOP, sv.x, sv.y)
	root:SetAlpha(sv.opacity / 100)
	-- Above the settings screen while it is being adjusted, in the HUD layer otherwise.
	root:SetDrawTier(previewing and DT_HIGH or DT_MEDIUM)
	root:SetDrawLayer(previewing and DL_OVERLAY or DL_CONTROLS)
	root:SetDrawLevel(previewing and 100 or 0)

	self.arrow:ClearAnchors()
	self.arrow:SetAnchor(TOP, root, TOP, 0, 0)
	self.arrow:SetDimensions(size, size)
	self.distance:ClearAnchors()
	self.distance:SetAnchor(TOP, self.arrow, BOTTOM, 0, 2)
	self.distance:SetDimensions(320, 34)
	self.step:ClearAnchors()
	self.step:SetAnchor(TOP, self.distance, BOTTOM, 0, 0)
	self.step:SetDimensions(480, 30)
	self.lastRotation, self.lastDistanceText, self.lastStepText = nil, nil, nil
end

local function Show(self, key, control, visible)
	if self.shown[key] ~= visible then
		control:SetHidden(not visible)
		self.shown[key] = visible
	end
end

-- ---------------------------------------------------------------------------------------
-- What to show this tick
-- ---------------------------------------------------------------------------------------

-- The preview while the settings panel is open: a stop ahead and to the right, 133 m away, the second of four.
-- (The camera is taken to look along +Z, heading 0; with +Z ahead, +X is on the LEFT.)
local PREVIEW = { dx = -7500, dz = 11000 }

local function Stamp()
	return GetGameTimeMilliseconds()
end

-- { mode, vector, number, total, destination, heading, sample, why }
--   mode "guide"     point at the stop
--        "elsewhere" there is a stop, but not in this zone's map
--        "nopos"     there is a stop, but the position could not be worked out
--        "none"      nothing to show
function A:Observe(now)
	local heading = self:ReadHeading()
	if self:IsPreviewing() then
		local dx, dz = PREVIEW.dx, PREVIEW.dz
		return { mode = "guide", vector = { dx = dx, dz = dz, distance = A.Distance(dx, dz), inside = true },
			number = 2, total = 4, destination = false, heading = 0, preview = true }
	end

	self:SettleRemoval(now)

	local stop, number, total, destination
	local demo = self.demo
	if demo and now >= demo.untilMs then
		self.demo = nil
		demo = nil
	end
	if demo then
		stop, number, total, destination = demo.stop, 1, 1, false
	else
		stop, number, total, destination = self:Current()
	end
	if not stop then
		return { mode = "none" }
	end

	local sample, why = self:ReadSample(now)
	local vector, vwhy
	if sample then
		vector, vwhy = self:VectorTo(stop, sample)
	end
	if not vector then
		-- No position for a moment (a loading screen's last frames, a zone map being calibrated again): the arrow keeps
		-- the direction it had, still turning with the camera, for a few seconds instead of vanishing.
		local last = self.lastGuide
		if last and last.stop == stop and now - last.at <= GRACE_MS then
			return {
				mode = "guide", stale = true, why = why or vwhy or "no position",
				vector = { dx = last.dx, dz = last.dz, distance = last.distance, inside = true }, heading = heading,
				number = number, total = total, destination = destination,
			}
		end
		return { mode = "nopos", why = why or vwhy, sample = sample, number = number, total = total, destination = destination }
	end
	local view = {
		mode = vector.inside and "guide" or "elsewhere",
		vector = vector, sample = sample, heading = heading,
		number = number, total = total, destination = destination, demo = demo ~= nil,
	}
	if view.mode == "guide" then
		local last = self.lastGuide
		if not (last and last.stop == stop) then
			last = { stop = stop }
			self.lastGuide = last
		end
		last.at, last.dx, last.dz, last.distance = now, vector.dx, vector.dz, vector.distance
	end
	-- Arrived? (the test marker is left standing)
	if not demo and vector.inside and vector.distance <= self.sv.arriveRadius * 100 then
		view.arrived = true
	end
	return view
end

function A:Arrived(view)
	local kind = self:Reach()
	if kind == "stop" then
		self:Feedback("stopReached", view.number)
	elseif kind == "destination" then
		self:Feedback("destinationReached")
	end
	return kind
end

-- ---------------------------------------------------------------------------------------
-- The arrow
-- ---------------------------------------------------------------------------------------

function A:UpdateArrow(view)
	local sv = self.sv
	local mode = view.mode
	local showArrow = (mode == "guide") and sv.arrow
	local text, stepText

	if mode == "guide" then
		local vector = view.vector
		if showArrow then
			local bearing = Bearing(vector.dx, vector.dz)
			-- standing on the very spot has no direction: the arrow stays where it was
			if vector.distance < 50 and self.lastBearing then
				bearing = self.lastBearing
			end
			self.lastBearing = bearing
			-- The client's own formula (see Core.lua): the arrow is turned by bearing - heading.
			local angle = ScreenAngle(bearing, view.heading or 0)
			if not self.lastRotation or abs(angle - self.lastRotation) > ROTATION_EPS then
				self.arrow:SetTextureRotation(angle, 0.5, 0.5)
				self.lastRotation = angle
			end
			self.screenAngle = angle
		end
		text = A.FormatDistance(vector.distance)
	elseif mode == "elsewhere" then
		text = S.elsewhere
	elseif mode == "nopos" then
		text = S.noPosition
	end

	if mode ~= "none" then
		if view.destination then
			stepText = S.destinationLine
		elseif view.demo then
			stepText = S.testLine
		else
			stepText = string.format(S.stopLine, view.number or 0, view.total or 0)
		end
	end

	Show(self, "arrow", self.arrow, showArrow and true or false)
	local showDistance = mode ~= "none"
	Show(self, "distance", self.distance, showDistance)
	Show(self, "step", self.step, showDistance)
	if showDistance and text ~= self.lastDistanceText then
		self.distance:SetText(text)
		self.lastDistanceText = text
	end
	if showDistance and stepText ~= self.lastStepText then
		self.step:SetText(stepText)
		self.lastStepText = stepText
	end
end

-- ---------------------------------------------------------------------------------------
-- The world: beads on the ground and a beam on the stop
-- ---------------------------------------------------------------------------------------

function A:CreateWorld()
	local world = WINDOW_MANAGER:CreateTopLevelWindow("PBsWayPointWorld")
	world:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
	world:SetMouseEnabled(false)
	world:Create3DRenderSpace()
	world:SetDrawLayer(DL_BACKGROUND)
	world:SetDrawTier(DT_LOW)
	world:SetHidden(true)

	local probe = WINDOW_MANAGER:CreateControl("PBsWayPointCamera", world, CT_TEXTURE)
	probe:SetMouseEnabled(false)
	probe:Create3DRenderSpace()
	probe:SetHidden(true)

	local beads = {}
	for i = 1, MAX_BEADS do
		local bead = WINDOW_MANAGER:CreateControl("PBsWayPointBead" .. i, world, CT_TEXTURE)
		bead:SetTexture(PATH .. "dot.dds")
		bead:SetMouseEnabled(false)
		bead:Create3DRenderSpace()
		bead:Set3DLocalDimensions(BEAD_SIZE_M, BEAD_SIZE_M)
		bead:Set3DRenderSpaceUsesDepthBuffer(false)
		bead:SetHidden(true)
		beads[i] = { control = bead, hidden = true }
	end

	local beam = WINDOW_MANAGER:CreateControl("PBsWayPointBeam", world, CT_TEXTURE)
	beam:SetTexture(PATH .. "beam.dds")
	beam:SetMouseEnabled(false)
	beam:Create3DRenderSpace()
	beam:Set3DLocalDimensions(1, BEAM_HEIGHT_M)
	beam:Set3DRenderSpaceUsesDepthBuffer(false)
	beam:SetHidden(true)

	self.world = { window = world, probe = probe, beads = beads, beam = beam, beamHidden = true, windowHidden = true }
	return self.world
end

local function SetHiddenOnce(item, hidden)
	if item.hidden ~= hidden then
		item.control:SetHidden(hidden)
		item.hidden = hidden
	end
end

function A:HideWorld()
	local world = self.world
	if not world then
		return
	end
	if not world.windowHidden then
		world.window:SetHidden(true)
		world.windowHidden = true
	end
end

-- The trail is given up for this session (the arrow goes on): `reason` is for /pbwp status and the chat. Only for a game call
-- that is not allowed; errors only pause it (below).
function A:TrailOff(reason)
	self.trailOff = reason
	self:HideWorld()
	self:Trace("trail", "off for this session: " .. tostring(reason))
	self:Print(S.trailStopped, reason)
end

-- Errors in a row: the trail waits a few seconds and tries again by itself (it used to give up until the next login, which
-- looked like a guide that vanished for good).
function A:TrailPause(reason)
	self.trailPausedUntil = Stamp() + TRAIL_PAUSE_MS
	self.trailErrors = 0
	self:HideWorld()
	self:Trace("trail", "paused for " .. floor(TRAIL_PAUSE_MS / 1000) .. " s after errors: " .. tostring(reason))
	self:Print(S.trailPaused, reason)
end

-- The 3D calls are the game's, so they are asked about like the position calls (see Nav.lua).
function A:UpdateWorld(view)
	local sv = self.sv
	if not sv.trail or self.trailOff or view.mode ~= "guide" or view.preview or not view.sample then
		self:HideWorld()
		return
	end
	if self.trailPausedUntil then
		if Stamp() < self.trailPausedUntil then
			self:HideWorld()
			return
		end
		self.trailPausedUntil = nil
		self:Trace("trail", "trying again after the pause")
	end
	local world = self.world or self:CreateWorld()
	local sample, vector = view.sample, view.vector
	local distance = vector.distance
	if distance < 1 then
		self:HideWorld()
		return
	end

	-- The camera's orientation, from a control of ours that the game turns to the camera. Without the call
	-- the probe would hold whatever it was given at the start, and the beads would face the wrong way.
	self:Call("Set3DRenderSpaceToCurrentCamera", world.probe:GetName())
	local camera = self.fnState.Set3DRenderSpaceToCurrentCamera
	if not (camera and camera.usable) then
		self:TrailOff("the camera call is not allowed (" .. tostring(camera and camera.why or "not asked") .. ")")
		return
	end
	local pitch, yaw, roll = world.probe:Get3DRenderSpaceOrientation()
	if type(pitch) ~= "number" or type(yaw) ~= "number" or type(roll) ~= "number" then
		self:HideWorld()
		return
	end

	if world.windowHidden then
		world.window:SetHidden(false)
		world.windowHidden = false
	end

	local ux, uz = vector.dx / distance, vector.dz / distance
	local reach = min(sv.trailLength, distance / 100 - 2)
	local count = 0
	if reach >= BEAD_FIRST_M then
		count = min(MAX_BEADS, floor((reach - BEAD_FIRST_M) / BEAD_STEP_M) + 1)
	end
	local py = sample.y + BEAD_LIFT_CM
	for i = 1, MAX_BEADS do
		local item = world.beads[i]
		if i <= count then
			local metres = BEAD_FIRST_M + (i - 1) * BEAD_STEP_M
			local rx, ry, rz = self:Call("WorldPositionToGuiRender3DPosition",
				floor(sample.x + ux * metres * 100 + 0.5), floor(py + 0.5), floor(sample.z + uz * metres * 100 + 0.5))
			local convert = self.fnState.WorldPositionToGuiRender3DPosition
			if type(rx) ~= "number" and convert and not convert.usable then
				self:TrailOff("the 3D position call is not allowed (" .. tostring(convert.why) .. ")")
				return
			end
			if type(rx) == "number" then
				local control = item.control
				control:Set3DRenderSpaceOrigin(rx, ry, rz)
				control:Set3DRenderSpaceOrientation(pitch, yaw, roll)
				local size = BEAD_SIZE_M + 0.02 * metres
				if item.size ~= size then
					control:Set3DLocalDimensions(size, size)
					item.size = size
				end
				local alpha = max(0.25, 1 - (i - 1) / max(count, 1) * 0.75)
				if item.alpha ~= alpha then
					control:SetColor(1, 1, 1, alpha)
					item.alpha = alpha
				end
				SetHiddenOnce(item, false)
			else
				SetHiddenOnce(item, true)
			end
		else
			SetHiddenOnce(item, true)
		end
	end

	-- The beam stands on the stop: a tall, thin, upright strip that always faces the camera's way.
	local beam = world.beam
	if distance >= BEAM_MIN_DISTANCE_CM then
		local rx, ry, rz = self:Call("WorldPositionToGuiRender3DPosition",
			floor(sample.x + vector.dx + 0.5), floor(sample.y + BEAM_HEIGHT_M * 50 + 0.5), floor(sample.z + vector.dz + 0.5))
		if type(rx) == "number" then
			local width = max(0.6, min(6, distance / 100 * 0.01))
			beam:Set3DRenderSpaceOrigin(rx, ry, rz)
			beam:Set3DRenderSpaceOrientation(0, yaw, 0)
			if world.beamWidth ~= width then
				beam:Set3DLocalDimensions(width, BEAM_HEIGHT_M)
				world.beamWidth = width
			end
			if world.beamHidden then
				beam:SetHidden(false)
				world.beamHidden = false
			end
		elseif not world.beamHidden then
			beam:SetHidden(true)
			world.beamHidden = true
		end
	elseif not world.beamHidden then
		beam:SetHidden(true)
		world.beamHidden = true
	end
	self.diag.worldFrames = (self.diag.worldFrames or 0) + 1
end

-- ---------------------------------------------------------------------------------------
-- The tick
-- ---------------------------------------------------------------------------------------

-- What the guide is doing, as a kind (a change of kind is what the trace records) and, only when asked, a short line.
local function GuideKind(view)
	local mode = view.mode
	if mode == "guide" then
		return view.stale and "stale" or "guide"
	end
	return mode == "elsewhere" and "elsewhere" or (mode == "nopos" and "nopos" or "none")
end

function A.GuideText(kind, why)
	if kind == "guide" then
		return "pointing at the next stop"
	elseif kind == "stale" then
		return "the position is missing (" .. tostring(why) .. "): the arrow keeps its last direction"
	elseif kind == "elsewhere" then
		return "the next stop is not on this zone's map: no arrow"
	elseif kind == "nopos" then
		return "no position (" .. tostring(why) .. "): no arrow"
	end
	return "there is no stop to walk to"
end

function A:TickBody()
	local now = Stamp()
	local view = self:Observe(now)
	self.view = view
	self:UpdateArrow(view)
	-- every change of what the guide shows leaves a line in the trace (the preview and the test marker are not the route)
	local kind = GuideKind(view)
	if not view.preview and not view.demo and kind ~= self.guideKind then
		self:Trace("guide", A.GuideText(kind, view.why))
	end
	self.guideKind, self.guideWhy = kind, view.why
	if view.arrived then
		self:Arrived(view)
	end
	-- The 3D part has its own error count: it is the part that is new to the console, and losing it must
	-- not take the arrow with it.
	local ok, err = pcall(self.UpdateWorld, self, view)
	if ok then
		self.trailErrors = 0
	else
		self.diag.lastTrailError = tostring(err)
		self.trailErrors = (self.trailErrors or 0) + 1
		self:HideWorld()
		if self.trailErrors >= MAX_TRAIL_ERRORS then
			self:TrailPause(tostring(err))
		end
	end
	self.diag.ticks = self.diag.ticks + 1
end

-- An error in the update must not repeat thirty times a second: it is kept for /pbwp status, and the third one in a row
-- stops the update for a few seconds. Then it starts again by itself (it used to stay stopped until the screen changed).
function A:Tick()
	local ok, err = pcall(self.TickBody, self)
	if ok then
		self.tickErrors = 0
		return
	end
	self.diag.lastError = tostring(err)
	self.diag.errors = self.diag.errors + 1
	self.tickErrors = (self.tickErrors or 0) + 1
	if self.tickErrors >= MAX_TICK_ERRORS then
		EVENT_MANAGER:UnregisterForUpdate(self.name .. "Tick")
		self:Trace("guide", "the update stopped after errors, starts again in " .. floor(TICK_RESTART_MS / 1000) .. " s: " .. self.diag.lastError)
		self:Print(S.stopped, self.diag.lastError)
		EVENT_MANAGER:UnregisterForUpdate(self.name .. "TickRestart")
		EVENT_MANAGER:RegisterForUpdate(self.name .. "TickRestart", TICK_RESTART_MS, function()
			EVENT_MANAGER:UnregisterForUpdate(self.name .. "TickRestart")
			self.diag.tickRestarts = (self.diag.tickRestarts or 0) + 1
			self:RefreshVisibility()
		end)
	end
end

function A:RefreshVisibility()
	if not self.root then
		return
	end
	local inHud = (HUD_SCENE and HUD_SCENE:IsShowing()) or (HUD_UI_SCENE and HUD_UI_SCENE:IsShowing())
	local visible = self.active and (self:IsPreviewing() or (self.sv.enabled and inHud)) and true or false
	-- what hides the guide as a whole: a line in the trace when that changes
	local reason
	if visible then
		reason = "shown"
	elseif not self.active then
		reason = "hidden: the game is loading (no player yet)"
	elseif not self.sv.enabled then
		reason = "hidden: switched off in the settings"
	else
		reason = "hidden: the screen is not the HUD (a menu, the map, a conversation ...)"
	end
	if reason ~= self.visibleReason then
		self.visibleReason = reason
		self:Trace("screen", reason)
	end
	self.root:SetHidden(not visible)
	EVENT_MANAGER:UnregisterForUpdate(self.name .. "Tick")
	EVENT_MANAGER:UnregisterForUpdate(self.name .. "TickRestart")
	if visible then
		self.tickErrors = 0
		self:Tick()
		EVENT_MANAGER:RegisterForUpdate(self.name .. "Tick", TICK_MS, function()
			self:Tick()
		end)
	else
		self:HideWorld()
	end
end

function A:OnRouteChanged()
	self.lastRotation = nil
	self.lastBearing = nil
	self:RefreshPins()
end

function A:OnSettingChanged(key)
	if key == nil or key == "pins" then
		self:ApplyPinSetting()
	end
	if key == nil or key == "resetChord" then
		self:ApplyChordSetting()
	end
	self:ApplyLayout()
	self:RefreshVisibility()
end

-- ---------------------------------------------------------------------------------------
-- The test marker: a stop 80 m ahead of where the camera looks now, for 20 seconds, so the arrow and the
-- trail can be seen without any route. It is given in world centimetres, so it also isolates the guide
-- from the map and the calibration.
-- ---------------------------------------------------------------------------------------

function A:StartDemo()
	local now = Stamp()
	local sample, why = self:ReadSample(now)
	if not sample then
		return false, why
	end
	local heading = self:ReadHeading() or 0
	local ox, oz = A.Offset(heading, 8000)
	self.demo = { stop = { world = { x = sample.x + ox, z = sample.z + oz } }, untilMs = now + DEMO_MS }
	self.lastRotation = nil
	self:RefreshVisibility()
	return true
end

-- ---------------------------------------------------------------------------------------
-- Telling the player
-- ---------------------------------------------------------------------------------------

local function Play(name)
	local id = SOUNDS and SOUNDS[name]
	if id and PlaySound then
		PlaySound(id)
	end
end
A.Play = Play

-- "stopReached", "destinationReached": a line in the chat and a sound.
function A:Feedback(kind, number)
	if kind == "stopReached" then
		self:Print(S.stopReached, number or 0)
		if self.sv.sound then
			Play("ABILITY_SLOTTED")
		end
	elseif kind == "destinationReached" then
		self:Print(S.destinationReached)
		if self.sv.sound then
			Play("ARMORY_RESTORE_SUCCESS")
		end
	end
end

A.loaded.Guide = true
