local A, S = PBS_WAYPOINT, PBS_WAYPOINT_STRINGS
local em = EVENT_MANAGER

-- ---------------------------------------------------------------------------------------
-- Output
--
-- A message printed at EVENT_ADD_ON_LOADED is thrown away because chat is not up yet, so anything
-- user-facing is either a command response or fires on EVENT_PLAYER_ACTIVATED.
-- ---------------------------------------------------------------------------------------

function A:Say(text)
	if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
		CHAT_ROUTER:AddSystemMessage(text)
	elseif CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
		CHAT_SYSTEM:AddMessage(text)
	else
		d(text)
	end
end

local PREFIX = "|cFF69B4" .. A.chatName .. "|r: "

-- The add-on's own messages go to the chat box only when the "messages in the chat" setting is on, or while a typed
-- command is being answered (`speaking`): the player asked, so the answer is shown. `/pbwp status`, `check`, `list`
-- and the help are printed with Say, which is never silenced.
function A:Print(text, ...)
	if not (self.speaking or (self.sv and self.sv.chat)) then
		return
	end
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, text, ...)
		self:Say(PREFIX .. (ok and formatted or text))
	else
		self:Say(PREFIX .. text)
	end
end

-- ---------------------------------------------------------------------------------------
-- What the map tells us
--
-- EVENT_MAP_PING is the game announcing that a ping was put down or taken away. The player's own destination
-- is the ping of type MAP_PIN_TYPE_PLAYER_WAYPOINT; the payload is the point on the map that is open.
-- ---------------------------------------------------------------------------------------

local function Valid01(v)
	return type(v) == "number" and v == v and v >= 0 and v <= 1
end

function A:HandlePing(kind, x, y)
	if not self.route then
		return
	end
	local now = GetGameTimeMilliseconds()

	if kind == PING_EVENT_ADDED then
		if not Valid01(x) or not Valid01(y) or (x == 0 and y == 0) then
			return
		end
		local mapId = self:Call("GetCurrentMapId")
		if type(mapId) ~= "number" or mapId == 0 then
			return
		end
		-- The place the event announces, against the place the game itself holds for its destination (what the client
		-- draws the pin from). If they differ, the game's own is the one that is on the map.
		local gx, gy = self:GameWaypointNow()
		if gx then
			if math.abs(gx - x) > 0.0015 or math.abs(gy - y) > 0.0015 then
				self.diag.payloadMismatch = self.diag.payloadMismatch + 1
				self.diag.lastPayload = { x = x, y = y, gx = gx, gy = gy, map = mapId }
				x, y = gx, gy
			else
				self.diag.payloadOk = self.diag.payloadOk + 1
			end
		end
		local result, changed = self:OnDestinationAdded(self:NewStop(mapId, x, y), now)
		if changed then
			self:ShareRoute("destination set")
		end
		if result == "stop" then
			self:Trace("route", string.format("destination set; the old one is now stop %d", self.route.done + #self.route.vias))
			self:Print(S.stopAdded, self.route.done + #self.route.vias)
		elseif result == "full" then
			self:Trace("route", "destination set; no room for another stop")
			self:Print(S.stopsFull, A.MAX_STOPS)
		else
			self:Trace("route", "destination set")
		end

	elseif kind == PING_EVENT_REMOVED then
		self.lastRemovedAt = now -- (the reset waits for this: see Chord.lua)
		local dest = self.route.dest
		if not dest then
			return
		end
		-- A removal that names some other place is the OLD destination going away after the new one was put
		-- down: not ours to act on.
		if Valid01(x) and Valid01(y) and not (x == 0 and y == 0) then
			local mapId = self:Call("GetCurrentMapId")
			if type(mapId) == "number" then
				local dx, dy = self:StopOnMap(dest, mapId)
				if dx and (math.abs(dx - x) > 2e-3 or math.abs(dy - y) > 2e-3) then
					return
				end
			end
		end
		-- The game takes the destination away when you reach it: tell that from taking it away by hand.
		local near = false
		local sample = self:ReadSample(now)
		if sample then
			local vector = self:VectorTo(dest, sample)
			local limit = math.max(self.sv.arriveRadius * 2, 50) * 100
			near = vector ~= nil and vector.inside and vector.distance <= limit
		end
		self:OnDestinationRemoved(now, near, self:MapScreenUp())
	end
end

-- The game keeps one destination and may forget it (it did not keep it through a zone load, for one). The add-on holds the
-- place itself, so a destination the game no longer has is KEPT: the guide goes on leading there. (Earlier versions dropped it
-- here, and the guide vanished after a loading screen.) The state is shown by /pbwp status.
function A:CheckDestination()
	local dest = self.route and self.route.dest
	if not dest then
		self.destState = nil
		return
	end
	local state = self:VerifyDestination(dest)
	self.destState = state or "not asked"
	if state == "present" and dest and self.route.destOwn then
		self.route.destOwn = nil
		self:RouteChanged()
	end
	if state == "gone" then
		if not self.route.destOwn then
			self.route.destOwn = true -- the game does not have it: the add-on draws its pin
			self:RouteChanged()
		end
		self.destState = "gone from the game, kept by the add-on"
		self:Trace("route", "the game no longer holds the destination (checked after the zone loaded): kept, the guide goes on")
		self:Print(S.destinationForgotten)
	end
end

-- ---------------------------------------------------------------------------------------
-- Actions (commands and the panel's buttons both call these)
-- ---------------------------------------------------------------------------------------

function A:ActSkip()
	if not self:HasRoute() then
		self:Print(S.noRoute)
		return
	end
	self:Reach()
	self:Trace("route", "the current stop was skipped")
	self:Print(S.skipped)
end

function A:ActUndo()
	local number = self.route.done + #self.route.vias
	if self:RemoveLastStop() then
		self:ShareRoute("a stop was removed")
		self:Trace("route", string.format("stop %d removed (the last one)", number))
		self:Print(S.removed, number)
	else
		self:Print(S.noStops)
	end
end

function A:ActRemove(number)
	if self:RemoveStop(number) then
		self:ShareRoute("a stop was removed")
		self:Trace("route", string.format("stop %d removed", number))
		self:Print(S.removed, number)
	else
		self:Print(S.noSuchStop, number or 0)
	end
end

function A:ActClear()
	self:Clear()
	self:ShareRoute("the route was cleared")
	self:Trace("route", "the route was cleared (command or panel)")
	self:Print(S.cleared)
end

function A:ListLines()
	local lines = {}
	local items = self:Stops()
	if #items == 0 then
		lines[1] = S.listEmpty
		return lines
	end
	lines[1] = string.format(S.listHeader, #self.route.vias)
	for _, item in ipairs(items) do
		local stop = item.stop
		local where = string.format("(map %d: %.3f, %.3f)", stop.mapId, stop.nx, stop.ny)
		if item.destination then
			lines[#lines + 1] = string.format(S.listDestination, item.number, where)
		else
			lines[#lines + 1] = string.format(S.listLine, item.number, where)
		end
	end
	return lines
end

-- ---------------------------------------------------------------------------------------
-- /pbwp status: what the add-on reads from the game
-- ---------------------------------------------------------------------------------------

local function Metres(centimetres)
	return string.format("%.1f m", centimetres / 100)
end

-- "300.0 m east, 20.0 m north" for a vector: on the map's axes (east is +x, south is +y) when it has them;
-- the game's world axes are not known to point at any compass direction, so a vector without them says so.
local function Toward(vector)
	if vector.east then
		local east, south = vector.east, vector.south
		return string.format("%s %s, %s %s", Metres(math.abs(east)), east >= 0 and "east" or "west", Metres(math.abs(south)), south >= 0 and "south" or "north")
	end
	return string.format("world +X %s, world +Z %s", Metres(vector.dx), Metres(vector.dz))
end

-- "N", "SW": where the camera looks on the map, from the game's heading (the bearing of where it looks, see Core.lua)
-- and a zone frame; nil without a frame.
local function LookingWord(frame, heading)
	if not frame or not heading then
		return nil
	end
	local east, south = A.MapDirection(frame, math.sin(heading), math.cos(heading))
	return A.HeadingWord(A.CompassBearing(east, south))
end

local CALLS = {
	"GetUnitRawWorldPosition", "GetPlayerCameraHeading", "GetMapIdByZoneId", "GetUniversallyNormalizedMapInfo",
	"GetNormalizedWorldPosition", "GetCurrentMapId", "GetMapType", "GetMapPlayerPosition", "GetMapPlayerWaypoint",
	"Set3DRenderSpaceToCurrentCamera", "WorldPositionToGuiRender3DPosition",
	"GetUnitWorldPosition", "GetRawNormalizedWorldPosition", "GuiRender3DPositionToWorldPosition", "RemovePlayerWaypoint",
}

function A:StatusLines()
	local lines = {}
	local function add(text, ...)
		lines[#lines + 1] = select("#", ...) > 0 and string.format(text, ...) or text
	end
	local diag, route = self.diag, self.route

	add("%s", self.title)
	if self.startErrors and #self.startErrors > 0 then
		add("start-up problems: %s", table.concat(self.startErrors, "; "))
	end

	local heading = self:ReadHeading()
	local sample, why = self:ReadSample(GetGameTimeMilliseconds())
	if heading then
		local word = LookingWord(sample and sample.frame, heading)
		add("camera heading: %d° (the game's number: 0 = looking along world +Z, 90 = along +X)%s", math.floor(math.deg(heading) + 0.5) % 360,
			word and (", which is looking " .. word .. " on the map") or "")
	else
		add("camera heading: unavailable")
	end
	local mode = self:NwMode()
	add("the game's normalised position is on: %s; the open map now is %s", mode == "zone" and ("the zone's map (" .. tostring(self.nwModeHow or "learned earlier") .. ")")
		or mode == "current" and ("the open map (" .. tostring(self.nwModeHow or "learned earlier") .. ")") or "not known yet (the open map is assumed)",
		tostring(self:CurrentMap()))
	if sample then
		add("player: zone %d, east %s, south %s, height %s", sample.zone, Metres(sample.x), Metres(sample.z), Metres(sample.y))
		local frame = sample.frame
		if frame then
			local nx, ny = A.PlayerOnFrame(frame, sample.x, sample.z)
			add("map %d (measured with map %s open; the zone's map is %s): you are at %.4f, %.4f; 1 map unit = %.0f m east-west, %.0f m north-south; formula off by %s",
				frame.mapId, tostring(frame.calMap), tostring(frame.zoneMap), nx, ny, frame.cmPerUnitX / 100, frame.cmPerUnitY / 100,
				frame.lastError and string.format("%.1f m", frame.lastError / 100) or "not checked yet")
			if frame.anchored then
				add("anchor: %s against the game's own map position (it was off by %s east, %s south)", frame.anchorWhy,
					Metres(frame.anchorEast), Metres(frame.anchorSouth))
			else
				add("anchor: %s (/pbwp check compares the formula with the game's own map position)", frame.anchorWhy or "not tried yet")
			end
			add("scale check: %s; factor %.3f on the calibration; %d comparisons%s%s", frame.scaleWhy or "not yet (it starts after you have walked 30 m)",
				frame.sc, frame.scaleMeasures or 0, frame.scaleVerified and " (verified)" or "",
				frame.scaleRatio and string.format("; the last ratio %.3f, the game's map moved %d° from the formula's direction", frame.scaleRatio,
					math.floor(math.deg(frame.scaleTurn or 0) + 0.5)) or "")
		else
			add("zone map: not usable (%s)", tostring(sample.why))
		end
	else
		add("player: no position (%s)", tostring(why))
	end
	add("calibrations: %d made, %d thrown away, %d anchored, %d scale comparisons; destinations: %d matched the game's own place, %d did not%s",
		diag.frames, diag.drift, diag.anchors, diag.scales, diag.payloadOk, diag.payloadMismatch,
		diag.lastPayload and string.format(" (last: announced %.4f, %.4f, the game holds %.4f, %.4f on map %d)", diag.lastPayload.x,
			diag.lastPayload.y, diag.lastPayload.gx, diag.lastPayload.gy, diag.lastPayload.map) or "")

	local asked = {}
	for _, name in ipairs(CALLS) do
		local state = self.fnState[name]
		if state then
			asked[#asked + 1] = string.format("%s=%s", name, state.usable and (state.proven and "ok" or "allowed") or ("NO (" .. state.why .. ")"))
		end
	end
	add("game calls: %s", #asked > 0 and table.concat(asked, "; ") or "none made yet")
	if self.lastCrash then
		add("a call failed on an earlier login: %s (/pbwp retry forgets it)", tostring(self.lastCrash))
	end

	add("route: %d stops to come, %d reached, destination %s; replaced destinations are %s", #route.vias, route.done,
		route.dest and (self.destState and ("yes (" .. self.destState .. ")") or "yes") or "none",
		self.sv.addMode and "kept as stops" or "just replaced")
	local stop, number, total, destination = self:Current()
	if stop and sample then
		local vector, vwhy = self:VectorTo(stop, sample)
		if vector then
			add("next: %s %d of %d, %s away (%s), %s", destination and "destination" or "stop", number, total,
				Metres(vector.distance), Toward(vector), vector.inside and "inside this zone's map" or "NOT in this zone's map")
			local bearing = A.Bearing(vector.dx, vector.dz)
			local turn = math.floor(math.deg(A.ScreenAngle(bearing, heading or 0)) + 0.5)
			add("   the game's bearing to it %d°; the arrow is turned %d° (positive = to the left, negative = to the right)",
				math.floor(math.deg(bearing) + 0.5) % 360, turn)
			if vector.east then
				add("   compass bearing %d° (0 = north, 90 = west)", math.floor(math.deg(A.CompassBearing(vector.east, vector.south)) + 0.5) % 360)
			end
		else
			add("next: %s %d of %d, no vector (%s)", destination and "destination" or "stop", number, total, tostring(vwhy))
		end
	elseif not stop then
		add("next: nothing to walk to")
	end

	local pin = self.pin
	add("map pins: %s, %s, %d drawn on the last rebuild, %d rebuilds, %d errors%s", pin.why, pin.enabled and "on" or "off", pin.created,
		pin.refreshes, pin.errors, pin.lastError and ("; last: " .. pin.lastError) or "")

	for _, line in ipairs(self:ShareLines()) do
		add("%s", line)
	end

	local chord = self.chord
	add("L3 + R3 reset: %s; %s; L3 %d down / %d up, R3 %d down / %d up, %d chords (the second button within %d ms of the first), %d times the map finished showing%s",
		self.sv.resetChord and "on" or "off", chord.why, chord.downs.L3, chord.ups.L3, chord.downs.R3, chord.ups.R3, chord.fired, A.CHORD_MS,
		chord.shown, chord.lastGap and string.format("; the last gap between the two was %d ms", chord.lastGap) or "")
	add("   button guide row: %s (put into the map's descriptor %d times)", chord.rowWhy, chord.rowAdded)
	add("   redraw after a reset: %d times; %s", chord.redraws, chord.redrawWhy)

	add("guide: %d updates, %d errors, %d restarts after errors%s", diag.ticks, diag.errors, diag.tickRestarts or 0,
		diag.lastError and ("; last: " .. diag.lastError) or "")
	add("guide now: %s", self.guideKind and A.GuideText(self.guideKind, self.guideWhy) or "not shown yet")
	local world = self.world
	if self.trailOff then
		add("3D trail: OFF: %s", self.trailOff)
	elseif self.trailPausedUntil and GetGameTimeMilliseconds() < self.trailPausedUntil then
		add("3D trail: paused after errors for %d more seconds (it tries again by itself): %s", math.ceil((self.trailPausedUntil - GetGameTimeMilliseconds()) / 1000),
			tostring(diag.lastTrailError))
	elseif world then
		local pitch, yaw, roll = world.probe:Get3DRenderSpaceOrientation()
		add("3D trail: %d frames; the camera's 3D orientation is pitch %s, yaw %s, roll %s (compare yaw with the heading above)",
			diag.worldFrames or 0, tostring(pitch and string.format("%.2f", pitch)), tostring(yaw and string.format("%.2f", yaw)),
			tostring(roll and string.format("%.2f", roll)))
	else
		add("3D trail: not started (it starts with the first stop in view)")
	end

	-- why the guide may have gone: the last things that happened to it (all of them: /pbwp why)
	local current, earlier = self:TraceLines()
	add("what happened to the guide (this session; /pbwp why lists more)%s", #current == 0 and ": nothing yet" or ":")
	for i = math.max(1, #current - 5), #current do
		add("   %s", current[i])
	end
	return lines
end

-- /pbwp why: every line of the trace, this session's and the last one's.
function A:WhyLines()
	local lines = {}
	local current, earlier = self:TraceLines()
	lines[1] = string.format("%s: what happened to the guide, oldest first (the seconds are game time since the game started)", self.title)
	if #current == 0 then
		lines[#lines + 1] = "this session: nothing yet"
	else
		lines[#lines + 1] = "this session:"
		for _, line in ipairs(current) do
			lines[#lines + 1] = "   " .. line
		end
	end
	if #earlier > 0 then
		lines[#lines + 1] = "the last session before the reload:"
		for _, line in ipairs(earlier) do
			lines[#lines + 1] = "   " .. line
		end
	end
	return lines
end

-- ---------------------------------------------------------------------------------------
-- /pbwp check: the add-on's numbers next to the game's own, for when a stop is not where it was marked
--
-- Everything here is asked of the game through A:Call (private / pending protocol), and the two reads of the
-- open map only when the HUD is up and the open map is a zone map (see Nav.lua).
-- ---------------------------------------------------------------------------------------

function A:CheckLines()
	local lines = {}
	local function add(text, ...)
		lines[#lines + 1] = select("#", ...) > 0 and string.format(text, ...) or text
	end
	local function map(x, y)
		return (x and y) and string.format("%.4f, %.4f", x, y) or "none"
	end
	local now = GetGameTimeMilliseconds()
	add("%s: check", self.title)

	local rzone, rx, ry, rz = self:Call("GetUnitRawWorldPosition", "player")
	if type(rzone) ~= "number" or rzone == 0 then
		add("no raw world position: nothing to compare")
		return lines
	end
	add("raw world position: zone %s, east %s, south %s, height %s", tostring(rzone), Metres(rx), Metres(rz), Metres(ry))
	local wzone, wx, wy, wz = self:Call("GetUnitWorldPosition", "player")
	if type(wzone) ~= "number" or wzone == 0 then
		wzone = nil
	end
	if wzone then
		add("world position:     zone %s, east %s, south %s; raw minus world: east %s, south %s", tostring(wzone), Metres(wx), Metres(wz),
			Metres(rx - wx), Metres(rz - wz))
	else
		add("world position: unavailable")
	end

	-- the three ways to get a map position from a world position
	local function ask(name, zone, x, y, z)
		if not zone then
			return nil
		end
		return self:Call(name, zone, math.floor(x + 0.5), math.floor(y + 0.5), math.floor(z + 0.5))
	end
	local c1x, c1y = ask("GetNormalizedWorldPosition", rzone, rx, ry, rz)
	local c2x, c2y = ask("GetNormalizedWorldPosition", wzone, wx, wy, wz)
	local c3x, c3y = ask("GetRawNormalizedWorldPosition", rzone, rx, ry, rz)

	local sample = self:ReadSample(now)
	local frame = sample and sample.frame
	local gx, gy, gmap, gheading, gwhy
	local gate, why = self:MapGate()
	if gate then
		gx, gy, gmap, gheading = self:GameMapPosition(frame or { mapId = 0, ox = 0, oy = 0, sx = 1, sy = 1 })
		if not gx then
			gwhy = gy
		end
	else
		gwhy = why
	end
	if gx then
		-- (on the zone's map; the open map's own numbers are converted when it is another map)
		add("the game's own map position of you: %s on the zone map (open map %s)", map(gx, gy), tostring(gmap))
	else
		add("the game's own map position of you: not asked (%s)", tostring(gwhy))
	end
	local function off(label, cx, cy)
		if not cx then
			add("  %s: no answer", label)
		elseif gx and frame then
			local dnx, dny = cx - gx, cy - gy
			local dx, dz = frame.ia * dnx + frame.ib * dny, frame.ic * dnx + frame.id * dny
			add("  %s: %s, off from the game's by %s east, %s south", label, map(cx, cy), Metres(dx), Metres(dz))
		else
			add("  %s: %s", label, map(cx, cy))
		end
	end
	off("GetNormalizedWorldPosition(raw position)  ", c1x, c1y)
	off("GetNormalizedWorldPosition(world position)", c2x, c2y)
	off("GetRawNormalizedWorldPosition(raw position)", c3x, c3y)
	if frame then
		local fx, fy = A.PlayerOnFrame(frame, sample.x, sample.z)
		off("this add-on's formula now (" .. (frame.anchored and frame.anchorWhy or "not anchored") .. ")", fx, fy)
		add("  1 map unit = %.0f m east-west, %.0f m north-south; the zone map is %d; scale factor learned %.3f (%s)", frame.cmPerUnitX / 100,
			frame.cmPerUnitY / 100, frame.mapId, frame.sc, frame.scaleWhy or "no comparison yet: walk 30 m")
	else
		add("  no zone frame (%s)", tostring(sample and sample.why or "no sample"))
	end

	-- the heading
	local heading = self:ReadHeading()
	local word = LookingWord(frame, heading)
	add("camera heading: GetPlayerCameraHeading %s%s, the map's own heading %s", heading and string.format("%d°", math.floor(math.deg(heading) + 0.5) % 360) or "none",
		word and (" (looking " .. word .. " on the map)") or "",
		gheading and string.format("%d°", math.floor(math.deg(gheading) + 0.5) % 360) or "not asked")

	-- the 3D world: where the camera is, in the world and raw positions
	local world = self.world
	if world then
		self:Call("Set3DRenderSpaceToCurrentCamera", world.probe:GetName())
		local ox, oy, oz = world.probe:Get3DRenderSpaceOrigin()
		local cx, cy, cz = self:Call("GuiRender3DPositionToWorldPosition", ox, oy, oz)
		if type(cx) == "number" then
			add("3D camera at: x %s, z %s; from the raw position %s, from the world position %s (a third-person camera is a few metres away)",
				Metres(cx), Metres(cz), Metres(A.Distance(cx - rx, cz - rz)), wzone and Metres(A.Distance(cx - wx, cz - wz)) or "n/a")
		else
			add("3D camera: no answer")
		end
		local fx, fy, fz = world.probe:Get3DRenderSpaceForward()
		if type(fx) == "number" and type(fz) == "number" then
			add("3D camera looks (x %.2f, up %.2f, z %.2f), which is a bearing of %d° (the same number as the camera heading above if forward is where the camera looks)",
				fx, fy or 0, fz, math.floor(math.deg(A.Bearing(fx, fz)) + 0.5) % 360)
		end
	else
		add("3D: not started (the trail starts with the first stop in view)")
	end

	-- the destination: what the add-on stored against what the game holds
	local dest = self.route and self.route.dest
	if dest then
		local sx, sy = dest.nx, dest.ny
		local open = gate and self:Call("GetCurrentMapId")
		if gate and open == dest.mapId then
			local wxg, wyg = self:ReadWaypoint()
			add("destination: stored %s on map %d; the game holds %s", map(sx, sy), dest.mapId, map(wxg, wyg))
		else
			add("destination: stored %s on map %d; not compared (the open map is %s)", map(sx, sy), dest.mapId, gate and tostring(open) or "not a zone map")
		end
	end
	local stop, number, total, destination = self:Current()
	if stop and sample then
		local vector, vwhy = self:VectorTo(stop, sample)
		if vector then
			add("next: %s %d of %d, %s away (%s)", destination and "destination" or "stop", number, total, Metres(vector.distance), Toward(vector))
		else
			add("next: no vector (%s)", tostring(vwhy))
		end
	end
	return lines
end

-- ---------------------------------------------------------------------------------------
-- /pbwp
-- ---------------------------------------------------------------------------------------

-- Plain bytes, no character classes: what is typed in the chat box may be Japanese (see PB's Translate).
local function Split(input)
	input = tostring(input or "")
	local first, last = 1, #input
	while first <= last and (input:byte(first) == 32 or input:byte(first) == 9) do
		first = first + 1
	end
	while last >= first and (input:byte(last) == 32 or input:byte(last) == 9) do
		last = last - 1
	end
	local text = input:sub(first, last)
	local space = text:find(" ", 1, true)
	local command, arg = text, ""
	if space then
		command = text:sub(1, space - 1)
		arg = text:sub(space + 1)
		local start = 1
		while start <= #arg and (arg:byte(start) == 32 or arg:byte(start) == 9) do
			start = start + 1
		end
		arg = arg:sub(start)
	end
	command = command:gsub("[A-Z]", function(c)
		return string.char(c:byte() + 32)
	end)
	arg = arg:gsub("[A-Z]", function(c)
		return string.char(c:byte() + 32)
	end)
	return command, arg
end
A.Split = Split

local NUMBERS = { radius = "arriveRadius", size = "arrowSize", opacity = "opacity", x = "x", y = "y", length = "trailLength" }
local SWITCHES = { add = "addMode", arrow = "arrow", trail = "trail", pins = "pins", sound = "sound", chat = "chat", preview = "preview", chord = "resetChord",
	send = "shareSend", receive = "shareReceive" }

function A:Command(input)
	self.speaking = true
	local ok, err = pcall(self.CommandBody, self, input)
	self.speaking = false
	if not ok then
		error(err, 0)
	end
end

function A:CommandBody(input)
	if not self.sv or not self.route then
		self:Print(S.notReady, self.startErrors and table.concat(self.startErrors, "; ") or "not loaded yet")
		return
	end
	local command, arg = Split(input)
	local number = tonumber(arg)
	if command == "on" or command == "off" then
		self:Set("enabled", command == "on")
	elseif command == "reset" then
		self:Reset()
	elseif command == "status" then
		for _, line in ipairs(self:StatusLines()) do
			self:Say(line)
		end
	elseif command == "check" then
		for _, line in ipairs(self:CheckLines()) do
			self:Say(line)
		end
	elseif command == "why" then
		for _, line in ipairs(self:WhyLines()) do
			self:Say(line)
		end
	elseif command == "share" then
		local sent, why = self:ShareSendNow(false)
		if sent then
			self:Print(S.shareSent)
		else
			self:Print(S.shareNotSent, tostring(why))
		end
	elseif command == "list" then
		for _, line in ipairs(self:ListLines()) do
			self:Say(line)
		end
	elseif command == "skip" then
		self:ActSkip()
	elseif command == "undo" then
		self:ActUndo()
	elseif command == "remove" and number then
		self:ActRemove(number)
	elseif command == "clear" then
		self:ActClear()
	elseif command == "test" then
		local ok, why = self:StartDemo()
		if ok then
			self:Print(S.testOn)
		else
			self:Print(S.testNoPosition, tostring(why))
		end
	elseif command == "retry" then
		self.sv.probe = {}
		self.lastCrash = nil
		self.fnState = {}
		self.frames = {}
		self.rects = {}
		self.sv.nwMode = nil
		self.trailOff = nil
		self.trailPausedUntil = nil
		self.activatedAt = nil
		self.chord.why = "not set up yet"
		self.chord.rowWhy = "not added yet"
		self:ApplyChordSetting()
		self:Print(S.retried)
	elseif NUMBERS[command] and number then
		self:Set(NUMBERS[command], number)
	elseif SWITCHES[command] and (arg == "on" or arg == "off") then
		self:Set(SWITCHES[command], arg == "on")
		if command == "add" then
			self:Print(arg == "on" and S.addModeOn or S.addModeOff)
		end
	else
		self:Say(S.help)
		return
	end
	if self.panel and self.panel.UpdateControls then
		self.panel:UpdateControls()
	end
end

-- ---------------------------------------------------------------------------------------
-- Start-up
-- ---------------------------------------------------------------------------------------

A.startErrors = {}

-- Each step of the start-up on its own, so one that fails does not take the others with it, and the
-- command and the banner can say which one it was.
local function Step(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		A.startErrors[#A.startErrors + 1] = name .. ": " .. tostring(err)
	end
	return ok
end

local function OnLoaded(_, name)
	if name ~= A.name then
		return
	end
	em:UnregisterForEvent(A.name, EVENT_ADD_ON_LOADED)

	Step("saved variables", function()
		A.sv = ZO_SavedVars:NewAccountWide("PBsWayPoint_Data", 1, nil, A.defaults)
		A:Sanitize()
		A:LoadRoute()
	end)
	if not A.sv then
		return
	end
	Step("interface", function()
		A:CreateUI()
		A:ApplyLayout()
	end)
	Step("settings", function()
		A:InitSettings()
	end)
	Step("map pins", function()
		A:RegisterPins()
	end)
	Step("map events", function()
		em:RegisterForEvent(A.name .. "Ping", EVENT_MAP_PING, function(_, pingEventType, pingType, _, x, y, isLocalPlayerOwner)
			if pingType == MAP_PIN_TYPE_PLAYER_WAYPOINT and isLocalPlayerOwner then
				local ok, err = pcall(A.HandlePing, A, pingEventType, x, y)
				if not ok then
					A.diag.lastError = tostring(err)
					A.diag.errors = A.diag.errors + 1
				end
			end
		end)
	end)
	Step("reset chord", function()
		A:ApplyChordSetting()
	end)
	Step("group sharing", function()
		A:StartShare()
	end)
	Step("scenes", function()
		local function refresh()
			A:RefreshVisibility()
		end
		HUD_SCENE:RegisterCallback("StateChange", refresh)
		HUD_UI_SCENE:RegisterCallback("StateChange", refresh)
	end)

	local bannerShown = false
	em:RegisterForEvent(A.name, EVENT_PLAYER_ACTIVATED, function()
		A.active = true
		A.activatedAt = GetGameTimeMilliseconds()
		Step("map pins", function()
			A:RegisterPins()
			A:RefreshPins()
		end)
		-- the map scene may not have existed when this add-on loaded
		Step("reset chord", function()
			A:ApplyChordSetting()
		end)
		-- a member who logs in into a group asks for its route
		Step("group sharing", function()
			A:ShareLogin()
		end)
		A:ApplyLayout()
		A:RefreshVisibility()
		-- The map is only the player's own once the zone has loaded: ask the game about the destination a moment later.
		em:UnregisterForUpdate(A.name .. "Verify")
		em:RegisterForUpdate(A.name .. "Verify", 3000, function()
			em:UnregisterForUpdate(A.name .. "Verify")
			Step("destination check", function()
				A:CheckDestination()
			end)
		end)
		if not bannerShown then
			bannerShown = true
			A:Print(S.bannerLine, A.title)
			if #A.startErrors > 0 then
				A:Print(S.notReady, table.concat(A.startErrors, "; "))
			end
		end
	end)
	em:RegisterForEvent(A.name, EVENT_PLAYER_DEACTIVATED, function()
		A.active = false
		A:SetPanelOpen(false)
		A:RefreshVisibility()
	end)
	em:RegisterForEvent(A.name, EVENT_SCREEN_RESIZED, function()
		A:ApplyLayout()
	end)
end

-- Registered when the file loads, not at EVENT_ADD_ON_LOADED: the command answers even if start-up failed,
-- and says so.
local function command(input)
	A:Command(input)
end
SLASH_COMMANDS[A.slash] = command
SLASH_COMMANDS[A.shortSlash] = command

em:RegisterForEvent(A.name, EVENT_ADD_ON_LOADED, OnLoaded)
A.loaded.Main = true
