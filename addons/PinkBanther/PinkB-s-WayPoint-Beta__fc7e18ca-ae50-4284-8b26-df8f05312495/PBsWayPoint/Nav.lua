-- Where the player is, which way the camera points, and where a stop is from here. Every call into the
-- game that gives a position lives in this file.
--
-- WHAT IS READ, AND WHAT IS NOT
--
-- Nothing here asks "the map the client has open": GetMapPlayerPosition and the Get*PinInfo family answer
-- for whatever map the world map is on, and on a console one frame of that with the map pulled back to
-- Tamriel has filled the add-on memory pool (PB's MiniMap, PB's CyrodiilAlert). Instead:
--
--   * the player comes from GetUnitRawWorldPosition("player"): zone and X/Y/Z in centimetres;
--   * a map is placed in the one flat "universal" space by GetUniversallyNormalizedMapInfo(mapId) (a plain
--     lookup by id; LibGPS does the same), so a point marked on ANY map can be turned into a point on the
--     player's zone map: universal = offset + normalised * size, both ways;
--   * the player's zone map is turned into centimetres by asking GetNormalizedWorldPosition(zone, x, y, z)
--     for the player's spot and a spot 200 m east and 200 m south of it. That is a 2x2 matrix J (map units
--     per centimetre), which also holds if a map were rotated; one calibration per zone, then the player's
--     map position is the affine formula and the matrix inverse turns a map offset into centimetres.
--
-- The add-on reads the open map in exactly two places at the end of this file, both only when the HUD is up and
-- the open map is a zone or a sub-zone: the game's own answer for "where am I on this map" (GetMapPlayerPosition),
-- asked once per zone to ANCHOR the calibration, and the destination the game still holds (GetMapPlayerWaypoint).
--
-- WHY THE SCALE CHECK. The matrix J comes from GetNormalizedWorldPosition, whose space is not guaranteed to be the
-- map's own (ImperialCartographer found the game's normalised spaces differ by a linear map). The map's own
-- position of the player, GetMapPlayerPosition, is the ground truth for where the pins are, so once the player has
-- walked 30 m the add-on compares how far the game's map position moved with how far its formula said, and
-- multiplies J by the ratio (and re-anchors); `/pbwp status` shows the factor it learned.
--
-- WHY THE ANCHOR. GetNormalizedWorldPosition takes WORLD coordinates and GetUnitRawWorldPosition gives RAW ones;
-- other add-on authors (LibGPS, ImperialCartographer) found the two spaces differ by an offset in some zones, and
-- the game's 3D conversion (WorldPositionToGuiRender3DPosition) takes the raw ones. A constant offset in the
-- player's calibrated place shows up as a stop that is "greatly off" from where it was marked. The scale (the
-- matrix J below) is a difference of two answers and is unaffected; the offset is what the anchor measures:
-- the game's own map position of the player, minus the formula's, is added once to the zone's frame.
local A = PBS_WAYPOINT

local DELTA_CM = 20000 -- the calibration step: 200 m
local FRAME_RETRY_MS = 2000 -- a zone that could not be calibrated is tried again after this (the guide has no position until it is)
local RECALIBRATE_RETRY_MS = 2000 -- ... and a recalibration that failed, after this
local RECT_RETRY_MS = 2000 -- a map the game could not place is asked about again after this
local VERIFY_MS = 5000 -- how often the affine formula is checked against the game
local VERIFY_TOLERANCE_CM = 300 -- ... and how far off it may be before the zone is calibrated again
local MIN_SIZE = 1e-6 -- a map with no universal size is useless
local ANCHOR_SETTLE_MS = 3000 -- the zone must have been up this long before the open map is asked about
local ANCHOR_RETRY_MS = 10000 -- ... and a try that could not be made is made again after this
local ANCHOR_OK_CM = 500 -- an anchor this close to the formula is "verified"; farther it was "corrected"
local SCALE_MIN_MOVE_CM = 3000 -- the game's map position is compared after the player has walked this far (30 m)
local SCALE_RETRY_MS = 4000 -- ... at most this often while the scale is being learned
local SCALE_WATCH_MS = 60000 -- ... and this often once two measurements in a row agreed
local SCALE_OK = 0.02 -- a measured ratio within 2 % of 1 agrees
local SCALE_LOW, SCALE_HIGH = 0.2, 5 -- a ratio outside this is not believed
local SCALE_MAX_TURN = math.rad(25) -- the game's map moved this far from the direction the formula said: not a scale error

local floor, sqrt, abs = math.floor, math.sqrt, math.abs

A.diag = {
	ticks = 0,
	errors = 0,
	frames = 0, -- zone calibrations made
	drift = 0, -- calibrations thrown away because the formula disagreed with the game
	anchors = 0, -- zones anchored to the game's own map position
	scales = 0, -- comparisons of the game's map movement with the formula's
	payloadOk = 0, -- destinations whose announced place matched the one the game holds
	payloadMismatch = 0, -- ... and those that did not (the game's own was used)
	lastPayload = nil,
	lastError = nil,
}
A.fnState = {}
A.frames = {}
A.rects = {}
A.proven = {}

-- ---------------------------------------------------------------------------------------
-- The game's calls, asked about before they are made
--
-- None of these is documented as private, and that marker has been wrong before; a private call raises
-- the client's UI error, which pcall does not catch. So the API is asked first (IsPrivateFunction /
-- IsProtectedFunction) and, either way, `pending` is written to the saved variables before the first
-- call and cleared when it returns. If the game ever shows the error and the player reloads, the file
-- still says "pending", and next time that call is not made (Sanitize in Core.lua).
-- `/pbwp retry` forgets what was learned.
-- ---------------------------------------------------------------------------------------

function A:Judge(name)
	local state = { usable = false, why = "not checked yet", proven = false }
	self.fnState[name] = state
	local probe = self.sv.probe

	if probe[name] == "bad" then
		state.why = "it failed on an earlier login"
	elseif type(_G[name]) ~= "function" then
		state.why = "the function does not exist"
	else
		local refused
		if probe.ask == "bad" then
			state.asked = "skipped: the question failed on an earlier login"
		elseif type(IsPrivateFunction) == "function" and type(IsProtectedFunction) == "function" then
			self.sv.pending = "ask"
			local okPrivate, isPrivate = pcall(IsPrivateFunction, name)
			local okProtected, isProtected = pcall(IsProtectedFunction, name)
			self.sv.pending = nil
			if okPrivate and okProtected then
				state.asked = (isPrivate and "private" or "not private") .. ", " .. (isProtected and "protected" or "not protected")
				refused = isPrivate or isProtected
			else
				state.asked = "the question failed"
			end
		else
			state.asked = "cannot ask"
		end
		if refused then
			state.why = "the game marks it private or protected"
		else
			state.usable = true
			state.why = "allowed"
		end
	end
	return state
end

-- The arguments go through exactly as given (a client function is not handed extra nils), and up to five
-- results come back on the first call: every call this add-on makes fits.
function A:Call(name, ...)
	local state = self.fnState[name] or self:Judge(name)
	if not state.usable then
		return nil
	end
	local fn = _G[name]
	if state.proven then
		return fn(...)
	end
	self.sv.pending = name
	local ok, r1, r2, r3, r4, r5 = pcall(fn, ...)
	self.sv.pending = nil
	if not ok then
		state.usable = false
		state.why = "the call raised: " .. tostring(r1)
		return nil
	end
	state.proven = true
	self.sv.probe[name] = "ok"
	return r1, r2, r3, r4, r5
end

-- ---------------------------------------------------------------------------------------
-- Heading and position
-- ---------------------------------------------------------------------------------------

-- Radians, north 0 and west pi/2; nil if the game gives nothing usable.
function A:ReadHeading()
	local heading = self:Call("GetPlayerCameraHeading")
	if type(heading) ~= "number" or heading ~= heading then
		return nil
	end
	return heading
end

-- zone, x, y, z in centimetres; nil when the player has no position in this world.
function A:PlayerWorld()
	local zone, x, y, z = self:Call("GetUnitRawWorldPosition", "player")
	if type(zone) ~= "number" or zone == 0 or type(x) ~= "number" or type(z) ~= "number" or (x == 0 and z == 0) then
		return nil
	end
	return zone, x, type(y) == "number" and y or 0, z
end

-- ---------------------------------------------------------------------------------------
-- Maps in the universal space
-- ---------------------------------------------------------------------------------------

-- offsetX, offsetY, sizeX, sizeY of a map in the universal space; nil if the game has none. A lookup that found nothing is
-- remembered for RECT_RETRY_MS only: a map the game could not place a moment ago (right after a zone loaded) is placed a moment
-- later, and one bad answer must not take the position away for the rest of the session.
function A:MapRect(mapId)
	if type(mapId) ~= "number" or mapId == 0 then
		return nil
	end
	local now = GetGameTimeMilliseconds()
	local entry = self.rects[mapId]
	if entry and entry.failedAt and now - entry.failedAt >= RECT_RETRY_MS then
		entry = nil
	end
	if entry == nil then
		local ox, oy, sx, sy = self:Call("GetUniversallyNormalizedMapInfo", mapId)
		if type(ox) == "number" and type(oy) == "number" and type(sx) == "number" and type(sy) == "number"
			and sx > MIN_SIZE and sy > MIN_SIZE then
			entry = { ox, oy, sx, sy }
		else
			entry = { failedAt = now }
		end
		-- a lookup that was refused is not kept at all: it may work later
		if not entry.failedAt or (self.fnState.GetUniversallyNormalizedMapInfo and self.fnState.GetUniversallyNormalizedMapInfo.usable) then
			self.rects[mapId] = entry
		end
	end
	if entry.failedAt then
		return nil
	end
	return entry[1], entry[2], entry[3], entry[4]
end

-- A stop marked at (nx, ny) on the map `mapId`. It remembers where that is in the universal space, so
-- it can be found again on any other map.
function A:NewStop(mapId, nx, ny)
	local stop = { mapId = mapId, nx = nx, ny = ny }
	local ox, oy, sx, sy = self:MapRect(mapId)
	if ox then
		stop.ux, stop.uy, stop.us = ox + nx * sx, oy + ny * sy, sx
	end
	return stop
end

-- Where a stop is on the map `mapId` (normalised), or nil when it is not inside that map.
function A:StopOnMap(stop, mapId)
	if stop.mapId == mapId then
		return stop.nx, stop.ny
	end
	if not stop.ux then
		return nil
	end
	local ox, oy, sx, sy = self:MapRect(mapId)
	if not ox then
		return nil
	end
	local nx, ny = (stop.ux - ox) / sx, (stop.uy - oy) / sy
	if nx <= 0 or nx >= 1 or ny <= 0 or ny >= 1 then
		return nil
	end
	return nx, ny
end

-- ---------------------------------------------------------------------------------------
-- The player's zone as a map: calibration
-- ---------------------------------------------------------------------------------------

local function Normalized(zone, x, y, z)
	return A:Call("GetNormalizedWorldPosition", zone, floor(x + 0.5), floor(y + 0.5), floor(z + 0.5))
end

local function Number(v)
	return type(v) == "number" and v == v
end

-- The change of the map position (dn x, dn y) per centimetre along one ground axis ("x" or "z"), measured with a
-- step of DELTA_CM that stays inside the map: tries one way, then the other. nil when neither does.
local function Step(zone, x, y, z, axis, n0x, n0y)
	for _, sign in ipairs({ 1, -1 }) do
		local sx, sz = x, z
		if axis == "x" then
			sx = x + sign * DELTA_CM
		else
			sz = z + sign * DELTA_CM
		end
		local nx, ny = Normalized(zone, sx, y, sz)
		if Number(nx) and Number(ny) and (nx ~= n0x or ny ~= n0y)
			and nx > 0.0005 and nx < 0.9995 and ny > 0.0005 and ny < 0.9995 then
			return (nx - n0x) / (sign * DELTA_CM), (ny - n0y) / (sign * DELTA_CM)
		end
	end
	return nil
end

-- nil and a reason, or the frame.
function A:BuildFrame(zone, x, y, z)
	local mapId = self:Call("GetMapIdByZoneId", zone)
	if not Number(mapId) or mapId == 0 then
		return nil, "the zone has no map"
	end
	local ox, oy, sx, sy = self:MapRect(mapId)
	if not ox then
		return nil, "the zone's map is not in the universal space"
	end
	local n0x, n0y = Normalized(zone, x, y, z)
	if not (Number(n0x) and Number(n0y)) then
		return nil, "the game gave no map position for the zone"
	end
	-- One step along each axis of the ground. A step that would leave the map is not used: the game's answer
	-- stops changing at the edge, and a matrix built from that is wrong.
	local a, c = Step(zone, x, y, z, "x", n0x, n0y)
	local b, d = Step(zone, x, y, z, "z", n0x, n0y)
	if not (a and b) then
		return nil, "the game gave no map position for the zone"
	end
	local ia, ib, ic, id = A.Invert(a, b, c, d)
	if not ia then
		return nil, "the zone's map does not change with position"
	end
	self.diag.frames = self.diag.frames + 1
	return {
		zone = zone, mapId = mapId, ox = ox, oy = oy, sx = sx, sy = sy,
		px = x, pz = z, nx = n0x, ny = n0y,
		shiftX = 0, shiftY = 0, -- what the anchor added (see TryAnchor)
		sc = 1, -- the factor the scale check multiplied the matrix by (see TryScale)
		a0 = a, b0 = b, c0 = c, d0 = d, ia0 = ia, ib0 = ib, ic0 = ic, id0 = id, -- the matrix as measured
		a = a, b = b, c = c, d = d, ia = ia, ib = ib, ic = ic, id = id, -- ... and as it is now
		cmPerUnitX = sqrt(ia * ia + ic * ic), -- how many centimetres one map unit is, along x
		cmPerUnitY = sqrt(ib * ib + id * id),
		verifiedAt = nil,
	}
end

-- The frame for the zone the player is in, calibrated on first use; nil and a reason when there is none.
function A:Frame(zone, x, y, z, now)
	local cached = self.frames[zone]
	if cached then
		if cached.failed then
			if now - cached.at < FRAME_RETRY_MS then
				return nil, cached.failed
			end
		else
			return cached
		end
	end
	local frame, why = self:BuildFrame(zone, x, y, z)
	if frame then
		frame.builtAt = now
		self.frames[zone] = frame
		if self.lastFrameFail then
			self.lastFrameFail = nil
			self:Trace("position", "the zone map could be calibrated again")
		end
		return frame
	end
	self.frames[zone] = { failed = why, at = now }
	if self.lastFrameFail ~= why then
		self.lastFrameFail = why
		self:Trace("position", "no zone map to measure the way with (" .. tostring(why) .. ")")
	end
	return nil, why
end

-- The player's place on the zone's map, from the formula.
function A.PlayerOnFrame(frame, x, z)
	return frame.nx + frame.shiftX + frame.a * (x - frame.px) + frame.b * (z - frame.pz),
		frame.ny + frame.shiftY + frame.c * (x - frame.px) + frame.d * (z - frame.pz)
end

-- Is the formula still what the game says? A zone whose map is not a straight copy of the world would show
-- here (a drifting arrow is worse than no arrow).
function A:VerifyFrame(frame, x, y, z, now)
	if frame.verifiedAt and now - frame.verifiedAt < VERIFY_MS then
		return true
	end
	frame.verifiedAt = now
	local nx, ny = Normalized(frame.zone, x, y, z)
	if not (Number(nx) and Number(ny)) then
		return true
	end
	-- Against the formula as it was MEASURED from this very function (the anchor and the scale check change the
	-- one in use, not this): is the game's answer still a straight line of the player's place?
	local px = frame.nx + frame.a0 * (x - frame.px) + frame.b0 * (z - frame.pz)
	local py = frame.ny + frame.c0 * (x - frame.px) + frame.d0 * (z - frame.pz)
	local ex, ey = nx - px, ny - py
	-- the error in centimetres
	local dx, dz = frame.ia0 * ex + frame.ib0 * ey, frame.ic0 * ex + frame.id0 * ey
	frame.lastError = sqrt(dx * dx + dz * dz)
	if frame.lastError > VERIFY_TOLERANCE_CM then
		self.diag.drift = self.diag.drift + 1
		return false
	end
	return true
end

-- The formula no longer agrees with what the game says: calibrate again where the player stands now. The new frame takes
-- over what the old one had learned (the offset from the game's own map position and the scale), so the guide does not
-- jump; if it cannot be built, the OLD frame goes on being used and the calibration is tried again soon: a guide that
-- is a little off is better than none. Returns the new frame, or nil and a reason.
function A:Recalibrate(old, zone, x, y, z, now)
	local fresh, why = self:BuildFrame(zone, x, y, z)
	if not fresh then
		old.verifiedAt = now - VERIFY_MS + RECALIBRATE_RETRY_MS
		self:Trace("position", "the zone map drifted and could not be calibrated again (" .. tostring(why) .. "): going on with the old calibration")
		return nil, why
	end
	fresh.builtAt = now
	if old.sc ~= 1 then
		self:ApplyFrameScale(fresh, old.sc)
	end
	-- continuity: at the spot where the player stands the new formula gives what the old one gave
	local ox, oy = A.PlayerOnFrame(old, x, z)
	fresh.shiftX, fresh.shiftY = ox - fresh.nx, oy - fresh.ny
	fresh.anchored, fresh.anchorWhy, fresh.anchorCm = old.anchored, old.anchorWhy, old.anchorCm
	fresh.anchorEast, fresh.anchorSouth, fresh.anchorAt = old.anchorEast, old.anchorSouth, old.anchorAt
	fresh.ref, fresh.scaleAt, fresh.scaleWhy = old.ref, old.scaleAt, old.scaleWhy
	fresh.scaleVerified, fresh.scaleOkCount, fresh.scaleMeasures = old.scaleVerified, old.scaleOkCount, old.scaleMeasures
	fresh.scaleRatio, fresh.scaleTurn = old.scaleRatio, old.scaleTurn
	self.frames[zone] = fresh
	self:Trace("position", "the zone map drifted from the calibration: calibrated again, what was learned is kept")
	return fresh
end

-- ---------------------------------------------------------------------------------------
-- From here to a stop
-- ---------------------------------------------------------------------------------------

-- A table { dx, dz, distance, inside, east, south } with dx, dz the offset in the game's world axes (centimetres)
-- and east, south the same offset on the map's axes (nil for a test marker), or nil and a reason.
-- `inside` is false for a stop that is not within the player's zone map: then the offset is only a
-- direction on the universal map and the distance is not meant to be walked.
function A:VectorTo(stop, sample)
	if stop.world then
		-- a point given in world centimetres of this very zone (the test marker)
		local dx, dz = stop.world.x - sample.x, stop.world.z - sample.z
		return { dx = dx, dz = dz, distance = A.Distance(dx, dz), inside = true }
	end
	local frame = sample.frame
	if not frame then
		return nil, sample.why or "no map frame"
	end
	local qx, qy
	if stop.mapId == frame.mapId then
		qx, qy = stop.nx, stop.ny
	elseif stop.ux then
		qx, qy = (stop.ux - frame.ox) / frame.sx, (stop.uy - frame.oy) / frame.sy
	else
		return nil, "the stop's map is not known"
	end
	local pnx, pny = A.PlayerOnFrame(frame, sample.x, sample.z)
	local dnx, dny = qx - pnx, qy - pny
	local dx, dz = frame.ia * dnx + frame.ib * dny, frame.ic * dnx + frame.id * dny
	local inside = qx > 0 and qx < 1 and qy > 0 and qy < 1
	-- ... and the same offset on the MAP's own axes, which are the only ones whose compass directions are known:
	-- east is +x and south is +y.
	return { dx = dx, dz = dz, distance = A.Distance(dx, dz), inside = inside,
		east = dnx * frame.cmPerUnitX, south = dny * frame.cmPerUnitY }
end

-- Which way a world direction (dx, dz) points on the map, as the map's east and south (cm per cm).
function A.MapDirection(frame, dx, dz)
	return (frame.a * dx + frame.b * dz) * frame.cmPerUnitX, (frame.c * dx + frame.d * dz) * frame.cmPerUnitY
end

-- Everything a tick needs about where the player is: { zone, x, y, z, frame, why }, or nil and a reason.
function A:ReadSample(now)
	local zone, x, y, z = self:PlayerWorld()
	if not zone then
		return nil, "no world position"
	end
	local sample = { zone = zone, x = x, y = y, z = z, now = now }
	local frame, why = self:Frame(zone, x, y, z, now)
	if frame and not self:VerifyFrame(frame, x, y, z, now) then
		local fresh = self:Recalibrate(frame, zone, x, y, z, now)
		if fresh then
			frame = fresh
		end
	end
	sample.frame, sample.why = frame, why
	if frame and not frame.anchored and now >= (frame.anchorAt or 0) then
		self:TryAnchor(frame, sample, now)
	elseif frame and frame.anchored and now >= (frame.scaleAt or 0) then
		self:TryScale(frame, sample, now)
	end
	return sample
end

-- ---------------------------------------------------------------------------------------
-- The two reads of the map the client has open (see the top of this file)
--
-- Both answer for the OPEN map, so they are asked only when
--   * the HUD is the scene (no map screen of the player's own is up),
--   * and the open map is a zone or a sub-zone (never Tamriel or the cosmic map: on a console, one frame of
--     these with Tamriel open has filled the add-on memory pool, PB's MiniMap and PB's CyrodiilAlert).
-- ---------------------------------------------------------------------------------------

-- Is the open map a zone or a sub-zone? true, or false and the reason. (The one read of the map's type.)
function A:MapTypeGate()
	local mapType = self:Call("GetMapType")
	if mapType == nil then
		return false, "the open map's type could not be read"
	end
	if mapType ~= MAPTYPE_ZONE and mapType ~= MAPTYPE_SUBZONE then
		return false, "the open map is not a zone map"
	end
	return true
end

-- Is one of the world map's own screens up? The player can take the destination off the map by hand only there.
function A:MapScreenUp()
	if not (SCENE_MANAGER and SCENE_MANAGER.GetScene) then
		return false
	end
	for _, name in ipairs({ "gamepad_worldMap", "worldMap" }) do
		local ok, scene = pcall(SCENE_MANAGER.GetScene, SCENE_MANAGER, name)
		if ok and scene and scene.IsShowing and scene:IsShowing() then
			return true
		end
	end
	return false
end

-- The HUD is up AND the open map is a zone or a sub-zone: true, or false and the reason.
function A:MapGate()
	if not (HUD_SCENE and HUD_SCENE.IsShowing and HUD_SCENE:IsShowing()) then
		return false, "the HUD is not up"
	end
	return self:MapTypeGate()
end

-- Does the game hold a destination on the open map? true, false, or nil when it cannot be asked (the open map is not a
-- zone or sub-zone, or the call is not allowed). Only the map's type is checked, like GameWaypointNow.
function A:GameHasWaypoint()
	if not self:MapTypeGate() then
		return nil
	end
	local x, y = self:ReadWaypoint()
	if not x then
		return nil
	end
	return not (x == 0 and y == 0)
end

-- The game's own place for its destination on the open map, while the player is putting it down (the map screen is
-- up then, so only the map's type is checked): x, y, or nil. The destination EVENT carries a place too; this is the
-- one the client itself draws the pin from.
function A:GameWaypointNow()
	if not self:MapTypeGate() then
		return nil
	end
	local x, y = self:ReadWaypoint()
	if not x or (x == 0 and y == 0) then
		return nil
	end
	return x, y
end

-- The destination the game holds, on the open map: x, y (0, 0 = none), or nil. The caller has passed MapGate.
function A:ReadWaypoint()
	local x, y = self:Call("GetMapPlayerWaypoint")
	if type(x) ~= "number" or type(y) ~= "number" then
		return nil
	end
	return x, y
end

-- Where the game puts the player on the open map: x, y, mapId, heading; nil and a reason when it does not (the
-- open map is another zone, or a place with no position). The caller has passed MapGate.
function A:ReadMapPosition()
	local x, y, heading, inMap, symbolic = self:Call("GetMapPlayerPosition", "player")
	if inMap ~= true then
		return nil, "the player is not on the open map"
	end
	if symbolic == true then
		return nil, "the open map shows the player as a symbol"
	end
	if not Number(x) or not Number(y) or (x == 0 and y == 0) then
		return nil, "the game gave no position"
	end
	local mapId = self:Call("GetCurrentMapId")
	if not Number(mapId) or mapId == 0 then
		return nil, "the open map's id could not be read"
	end
	return x, y, mapId, Number(heading) and heading or nil
end

-- The game's own answer, on the ZONE's map (through the universal space when the open map is another one);
-- nil and a reason.
function A:GameMapPosition(frame)
	local ok, why = self:MapGate()
	if not ok then
		return nil, why
	end
	local x, y, mapId, heading = self:ReadMapPosition()
	if not x then
		return nil, y -- (a refusal comes back as nil and the reason)
	end
	if mapId == frame.mapId then
		return x, y, mapId, heading
	end
	local ox, oy, sx, sy = self:MapRect(mapId)
	if not ox then
		return nil, "the open map is not in the universal space"
	end
	return (ox + x * sx - frame.ox) / frame.sx, (oy + y * sy - frame.oy) / frame.sy, mapId, heading
end

-- Measures the offset between the formula and the game once per zone, and adds it to the frame. Tries again
-- every ANCHOR_RETRY_MS while the conditions are not met; `frame.anchorWhy` says how it stands.
function A:TryAnchor(frame, sample, now)
	if self.activatedAt and now - self.activatedAt < ANCHOR_SETTLE_MS then
		return
	end
	frame.anchorAt = now + ANCHOR_RETRY_MS
	local qx, qy = self:GameMapPosition(frame)
	if not qx then
		frame.anchorWhy = "not yet: " .. tostring(qy)
		return
	end
	local px, py = A.PlayerOnFrame(frame, sample.x, sample.z)
	local dnx, dny = qx - px, qy - py
	local dx, dz = frame.ia * dnx + frame.ib * dny, frame.ic * dnx + frame.id * dny
	frame.shiftX, frame.shiftY = frame.shiftX + dnx, frame.shiftY + dny
	frame.ref = { x = sample.x, z = sample.z, mx = qx, my = qy } -- where the game's map position and the world position were last paired
	frame.scaleAt = now + SCALE_RETRY_MS
	frame.anchored = true
	frame.anchorCm = sqrt(dx * dx + dz * dz)
	frame.anchorEast, frame.anchorSouth = dx, dz
	frame.anchorWhy = frame.anchorCm <= ANCHOR_OK_CM and "verified" or "corrected"
	self.diag.anchors = self.diag.anchors + 1
end

-- Multiplies the frame's matrix by `factor` (the offset is put right again by the caller).
function A:ApplyFrameScale(frame, factor)
	frame.a, frame.b, frame.c, frame.d = frame.a * factor, frame.b * factor, frame.c * factor, frame.d * factor
	frame.ia, frame.ib, frame.ic, frame.id = frame.ia / factor, frame.ib / factor, frame.ic / factor, frame.id / factor
	frame.sc = frame.sc * factor
	frame.cmPerUnitX = sqrt(frame.ia * frame.ia + frame.ic * frame.ic)
	frame.cmPerUnitY = sqrt(frame.ib * frame.ib + frame.id * frame.id)
end

-- Compares how far the game's own map position of the player moved since the last pairing with how far the formula
-- said it would, and learns the ratio. Needs the player to have walked SCALE_MIN_MOVE_CM (so a player who stands
-- still costs no call), and asks the game at most every SCALE_RETRY_MS (SCALE_WATCH_MS once two answers in a row
-- agreed). The result is a factor on the matrix; the offset is put right again at the new spot.
function A:TryScale(frame, sample, now)
	local ref = frame.ref
	if not ref then
		return
	end
	local dwx, dwz = sample.x - ref.x, sample.z - ref.z
	if sqrt(dwx * dwx + dwz * dwz) < SCALE_MIN_MOVE_CM then
		return
	end
	frame.scaleAt = now + SCALE_RETRY_MS
	local gx, gy = self:GameMapPosition(frame)
	if not gx then
		frame.scaleWhy = "not yet: " .. tostring(gy)
		return
	end
	-- the formula's idea of the move, and the game's, on the zone's map
	local px, py = frame.a * dwx + frame.b * dwz, frame.c * dwx + frame.d * dwz
	local dmx, dmy = gx - ref.mx, gy - ref.my
	local predicted, actual = sqrt(px * px + py * py), sqrt(dmx * dmx + dmy * dmy)
	if predicted <= 0 or actual <= 0 then
		frame.scaleWhy = "no movement to compare"
		return
	end
	local turn = math.atan2(px * dmy - py * dmx, px * dmx + py * dmy) -- how far the game's move is turned from the formula's
	frame.scaleTurn = turn
	frame.scaleMeasures = (frame.scaleMeasures or 0) + 1
	self.diag.scales = self.diag.scales + 1
	local ratio = actual / predicted
	frame.scaleRatio = ratio
	if math.abs(turn) > SCALE_MAX_TURN then
		-- not a question of scale: the map moves in another direction than the formula says (rotated or mirrored)
		frame.scaleWhy = string.format("the game's map moved %d° away from the formula's direction", math.floor(math.deg(math.abs(turn)) + 0.5))
		frame.scaleOkCount = 0
	elseif ratio < SCALE_LOW or ratio > SCALE_HIGH then
		frame.scaleWhy = string.format("a ratio of %.2f is not believed", ratio)
		frame.scaleOkCount = 0
	elseif math.abs(ratio - 1) > SCALE_OK then
		self:ApplyFrameScale(frame, ratio)
		frame.scaleWhy = string.format("learned a factor of %.3f", frame.sc)
		frame.scaleOkCount = 0
		frame.scaleVerified = false
	else
		frame.scaleOkCount = (frame.scaleOkCount or 0) + 1
		frame.scaleWhy = "agrees with the game's map"
		if frame.scaleOkCount >= 2 then
			frame.scaleVerified = true
		end
	end
	if frame.scaleVerified then
		frame.scaleAt = now + SCALE_WATCH_MS
	end
	-- pair the two again here, so the next comparison starts from a spot where the formula is exact
	local fx, fy = A.PlayerOnFrame(frame, sample.x, sample.z)
	frame.shiftX, frame.shiftY = frame.shiftX + (gx - fx), frame.shiftY + (gy - fy)
	frame.ref = { x = sample.x, z = sample.z, mx = gx, my = gy }
end

-- The game still holds the destination?  "present", "gone", or nil when it could not be asked: only when the
-- open map is the one the destination was marked on.
function A:VerifyDestination(dest)
	if not dest or not dest.mapId then
		return nil
	end
	if not self:MapGate() then
		return nil
	end
	if self:Call("GetCurrentMapId") ~= dest.mapId then
		return nil
	end
	local x, y = self:ReadWaypoint()
	if not x then
		return nil
	end
	if x == 0 and y == 0 then
		return "gone"
	end
	return "present"
end

A.loaded.Nav = true
