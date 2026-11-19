-- The markers in the world: a flat picture over each marked person's head, always turned square to the screen.
--
-- THE 3D PART follows the client's own housing editor (esoui/ingame/housingeditor/housingeditorhud.lua), the way PB's
-- WayPoint does it: a top-level window with Create3DRenderSpace, child textures that each have a render space, and a
-- position given by WorldPositionToGuiRender3DPosition (it takes the RAW world position that GetUnitRawWorldPosition gives).
--
-- FACING: each picture is turned about the vertical axis to the camera's heading and kept upright:
-- Set3DRenderSpaceOrientation(0, GetPlayerCameraHeading(), 0). That is the client's own way of squaring a 3D control to
-- the screen (the housing editor's pick-up gizmo, housingeditorhud.lua MoveAxisIndicators: yaw = GetPlayerCameraHeading()
-- minus a deliberate 20 degree tilt). The first version copied the camera's orientation from a control given to
-- Set3DRenderSpaceToCurrentCamera; on a PS5 the pictures then turned with the camera like objects in the world (the user's
-- report), so that route is not used. "Marker turn" in the settings adds degrees to the yaw, in case the picture shows
-- reversed on a console (not measured).
--
-- A group member's position can always be read (GetUnitRawWorldPosition("groupN")); nothing outside the group can be
-- followed that way, which is why only group members are marked.
--
-- A marker is shown only on the HUD (not in menus), only for a person in the same zone and instance as the player, and
-- not farther than MAX_DISTANCE_M. Its size grows with the distance (DISTANCE_GROWTH) so that a far one stays readable.
local A, S = PBS_PME, PBS_PME_STRINGS

local TICK_MS = 16 -- about sixty times a second (the game calls it at most once a frame); little work is done while nothing is marked
local MAX_SPRITES = 26 -- a group of 24 and a test marker, with a spare
local BASE_SIZE_M = 0.7 -- the marker's width and height in metres at size 100 %
local DISTANCE_GROWTH = 0.022 -- extra metres of marker per metre of distance
local MAX_DISTANCE_M = 250
local TEST_MS = 10000
local TEST_AHEAD_CM = 500
local TEST_LIFT_CM = 170 -- the test marker floats at about eye height
local MAX_TICK_ERRORS = 3
local TICK_RESTART_MS = 5000 -- after that many errors in a row the update waits this long and starts again

local floor, min, max, sqrt = math.floor, math.min, math.max, math.sqrt
local DEGREES = math.pi / 180

A.diag = A.diag or { ticks = 0, errors = 0, drawn = 0, lastDrawn = 0, lastError = nil }
A.test = nil

function A:CreateWorld()
	local window = WINDOW_MANAGER:CreateTopLevelWindow("PBsPlayerMarkerExtensionWorld")
	window:SetAnchor(CENTER, GuiRoot, CENTER, 0, 0)
	window:SetMouseEnabled(false)
	window:Create3DRenderSpace()
	window:SetDrawLayer(DL_BACKGROUND)
	window:SetDrawTier(DT_LOW)
	window:SetHidden(true)

	local throughWalls = self.sv.throughWalls
	local sprites = {}
	for i = 1, MAX_SPRITES do
		local control = WINDOW_MANAGER:CreateControl("PBsPlayerMarkerExtensionMark" .. i, window, CT_TEXTURE)
		control:SetTexture(A.IconPath(1))
		control:SetMouseEnabled(false)
		control:Create3DRenderSpace()
		control:Set3DLocalDimensions(BASE_SIZE_M, BASE_SIZE_M)
		control:Set3DRenderSpaceUsesDepthBuffer(not throughWalls)
		control:SetHidden(true)
		sprites[i] = { control = control, hidden = true, icon = 1 }
	end
	self.world = { window = window, sprites = sprites, windowHidden = true, depth = throughWalls, used = 0 }
	return self.world
end

function A:HideWorld()
	local w = self.world
	if w and not w.windowHidden then
		w.window:SetHidden(true)
		w.windowHidden = true
	end
end

-- The 3D calls are the game's, so they are asked about like the position calls (see Core.lua). One that is not allowed
-- switches the markers off for the session (`/pbpme retry` tries again); errors only pause them.
function A:WorldOff(reason)
	self.worldOff = reason
	self:HideWorld()
	self:Trace("world", "markers off for this session: " .. tostring(reason))
end

local function Valid(zone, x, z)
	return type(zone) == "number" and zone ~= 0 and type(x) == "number" and type(z) == "number" and not (x == 0 and z == 0)
end

local function SetHiddenOnce(item, hidden)
	if item.hidden ~= hidden then
		item.control:SetHidden(hidden)
		item.hidden = hidden
	end
end

-- Draws sprite `index`; returns true when it is shown, false when its position could not be had, "off" when a 3D call is
-- not allowed.
-- `flat` = no lift (the test marker floats where it is put). Otherwise the marker is lifted so that its LOWER edge is
-- `height` above the feet, to stand above the nameplate the way the game's own markers do:
--   * `height` is the lower edge (it was the centre in 0.2.0, which put the picture over the nameplate);
--   * `heightPerMetre` more for each metre of distance: the nameplate keeps its size on the screen, so it stands taller in the
--     world the farther away it is, and a marker that grows with the distance needs to rise with it;
--   * the position given to the game is the centre, so half the marker's height is added.
-- (The nameplate's real height is not readable by an add-on: these are estimates, and both are sliders.)
function A:DrawSprite(index, icon, x, y, z, metres, pitch, yaw, roll, flat)
	local w = self.world
	local sv = self.sv
	local item = w.sprites[index]
	local scale = sv.size / 100
	local size = max(BASE_SIZE_M * scale, metres * DISTANCE_GROWTH * scale)
	local lift = flat and 0 or (sv.height + metres * sv.heightPerMetre + size * 50)
	local rx, ry, rz = self:Call("WorldPositionToGuiRender3DPosition", floor(x + 0.5), floor(y + lift + 0.5), floor(z + 0.5))
	if type(rx) ~= "number" then
		local convert = self.fnState.WorldPositionToGuiRender3DPosition
		if convert and not convert.usable then
			self:WorldOff("the 3D position call is not allowed (" .. tostring(convert.why) .. ")")
			return "off"
		end
		SetHiddenOnce(item, true)
		return false
	end
	local control = item.control
	control:Set3DRenderSpaceOrigin(rx, ry, rz)
	control:Set3DRenderSpaceOrientation(pitch, yaw, roll)
	if item.icon ~= icon then
		control:SetTexture(A.IconPath(icon))
		item.icon = icon
	end
	if item.size ~= size then
		control:Set3DLocalDimensions(size, size)
		item.size = size
	end
	local alpha = sv.opacity / 100
	if item.alpha ~= alpha then
		control:SetColor(1, 1, 1, alpha)
		item.alpha = alpha
	end
	SetHiddenOnce(item, false)
	return true
end

-- Where a group member is, in RAW world centimetres: x, y, z; or nil, nil, nil and the reason when they are not in the
-- player's zone and instance or the game has no position for them.
function A:MemberPosition(entry, playerZone, px, py, pz)
	if entry.self then
		return px, py, pz
	end
	local zone, x, y, z = self:Call("GetUnitRawWorldPosition", entry.tag)
	if not Valid(zone, x, z) then
		return nil, nil, nil, "the game gives no position"
	end
	if zone ~= playerZone then
		return nil, nil, nil, "another zone"
	end
	-- the same zone is not always the same instance; the game says (a call that is not allowed counts as "yes")
	if self:Call("IsGroupMemberInSameWorldAsPlayer", entry.tag) == false then
		return nil, nil, nil, "another instance"
	end
	return x, y, z
end

-- Once per frame while there is something to show.
function A:UpdateWorld(now)
	local sv = self.sv
	local test = self.test
	if test and now >= test.untilAt then
		self.test = nil
		test = nil
	end
	local diag = self.diag
	local wanted = sv.enabled and self.hudShown and not self.worldOff and (test or next(self.marks) ~= nil)
	if not wanted then
		-- (what /pbpme status shows as the reason nothing is drawn: constants only, this runs every frame)
		diag.why = (not sv.enabled and "switched off") or (not self.hudShown and "not on the HUD scene")
			or (self.worldOff and "drawing is off for this session") or "nothing is marked"
		self:HideWorld()
		return
	end
	local w = self.world or self:CreateWorld()

	local playerZone, px, py, pz = self:Call("GetUnitRawWorldPosition", "player")
	diag.pzone, diag.px, diag.py, diag.pz = playerZone, px, py, pz
	if not Valid(playerZone, px, pz) then
		diag.why = "the game gives no position for the player"
		self:HideWorld()
		return
	end

	-- squared to the screen: upright, turned to the camera's heading (plus the player's own correction, 0 by default)
	local heading = self:Call("GetPlayerCameraHeading")
	if type(heading) ~= "number" or heading ~= heading then
		diag.why = "the game gives no camera heading"
		self:HideWorld()
		return
	end
	diag.heading = heading
	local pitch, yaw, roll = 0, heading + sv.facingOffset * DEGREES, 0

	if w.depth ~= sv.throughWalls then
		w.depth = sv.throughWalls
		for _, item in ipairs(w.sprites) do
			item.control:Set3DRenderSpaceUsesDepthBuffer(not sv.throughWalls)
		end
	end
	if w.windowHidden then
		w.window:SetHidden(false)
		w.windowHidden = false
	end

	local roster = self.roster
	local count = 0
	local verdict = diag.verdict
	if not verdict then
		verdict = {}
		diag.verdict = verdict
	end
	for hash, m in pairs(self.marks) do
		local entry = roster.byHash[hash]
		-- a marker on the player themself: the one the player put on themself is always shown (they asked for it); the
		-- ones others put on them follow the setting
		if not entry then
			verdict[hash] = "that person is not in the roster"
		elseif not entry.online then
			-- a member who logged out stays in the group; the game keeps no position for them worth showing
			verdict[hash] = "that person is offline"
		elseif entry.self and not (sv.showSelf or m.mine) then
			verdict[hash] = "on yourself, put there by another member, and 'show markers others put on me' is off"
		elseif count >= MAX_SPRITES - 1 then
			verdict[hash] = "no sprite left"
		else
			local x, y, z, why = self:MemberPosition(entry, playerZone, px, py, pz)
			if not x then
				verdict[hash] = why
			else
				local dx, dz = x - px, z - pz
				local metres = sqrt(dx * dx + dz * dz) / 100
				verdict[hash] = "too far"
				if metres <= MAX_DISTANCE_M then
					local result = self:DrawSprite(count + 1, m.icon, x, y, z, metres, pitch, yaw, roll)
					if result == "off" then
						return
					elseif result then
						count = count + 1
						verdict[hash] = "drawn"
					else
						verdict[hash] = "the game gives no 3D position"
					end
				end
			end
		end
	end
	diag.why = count > 0 and "drawing" or "no marker could be drawn (see each marker)"

	-- the test marker: a few metres ahead of the camera, at eye height
	if test then
		local heading = self:Call("GetPlayerCameraHeading")
		if type(heading) == "number" and heading == heading then
			local ox, oz = A.Offset(heading, TEST_AHEAD_CM)
			local result = self:DrawSprite(count + 1, test.icon, px + ox, py + TEST_LIFT_CM, pz + oz, TEST_AHEAD_CM / 100, pitch, yaw, roll, true)
			if result == "off" then
				return
			elseif result then
				count = count + 1
			end
		end
	end

	for i = count + 1, w.used do
		SetHiddenOnce(w.sprites[i], true)
	end
	w.used = count
	self.diag.lastDrawn = count
	self.diag.drawn = self.diag.drawn + count
end

-- A marker floats ahead of the camera for a few seconds: the whole drawing path (position, camera, texture) without a
-- group, to see it before anybody else is there.
function A:StartTest(icon)
	local zone, x, _, z = self:Call("GetUnitRawWorldPosition", "player")
	if not Valid(zone, x, z) then
		return false, "no position for the player"
	end
	self.test = { icon = A.IsIcon(icon) and icon or 1, untilAt = A.Stamp() + TEST_MS }
	return true
end

-- Cycles through the icons: each press of the panel's button shows the next one.
function A:StartNextTest()
	self.testCursor = (self.testCursor or 0) % A.ICON_COUNT + 1
	local ok, why = self:StartTest(self.testCursor)
	return ok, ok and self.testCursor or why
end

-- ---------------------------------------------------------------------------------------
-- The tick
-- ---------------------------------------------------------------------------------------

local HOUSE_MS = 250

function A:Tick()
	local now = A.Stamp()
	local diag = self.diag
	diag.ticks = diag.ticks + 1
	if self.pausedUntil then
		if now < self.pausedUntil then
			return
		end
		self.pausedUntil = nil
		self:Trace("tick", "trying again after the pause")
	end

	local scene = SCENE_MANAGER and SCENE_MANAGER.GetCurrentScene and SCENE_MANAGER:GetCurrentScene()
	self.hudShown = scene ~= nil and (scene == HUD_SCENE or scene == HUD_UI_SCENE)
	if scene ~= self.lastScene then
		-- for /pbpme status: which scene the game says it is in (looked up only when it changes)
		self.lastScene = scene
		local named, name = false, nil
		if scene and type(scene.GetName) == "function" then
			named, name = pcall(scene.GetName, scene)
		end
		self.sceneName = named and tostring(name) or (scene and "?" or "none")
	end

	local ok, err = pcall(function()
		if now - (self.lastHouse or 0) >= HOUSE_MS then
			self.lastHouse = now
			self:Housekeeping(now)
			self:ShareTick(now)
		end
		self:UpdateWorld(now)
	end)
	if ok then
		diag.tickErrors = 0
	else
		diag.errors = diag.errors + 1
		diag.tickErrors = (diag.tickErrors or 0) + 1
		diag.lastError = tostring(err)
		if diag.tickErrors >= MAX_TICK_ERRORS then
			diag.tickErrors = 0
			self.pausedUntil = now + TICK_RESTART_MS
			self:HideWorld()
			self:Trace("tick", "paused for " .. (TICK_RESTART_MS / 1000) .. " s after errors: " .. tostring(err))
		end
	end
end

function A:StartTick()
	EVENT_MANAGER:UnregisterForUpdate(self.name .. "Tick")
	EVENT_MANAGER:RegisterForUpdate(self.name .. "Tick", TICK_MS, function()
		A:Tick()
	end)
end

A.MARK("World")
