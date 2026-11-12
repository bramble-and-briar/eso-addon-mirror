-- PB's WayPoint
-- Author: PinkBanther
--
-- The map lets you mark ONE destination. This add-on lets you mark several stops on the way to it, and
-- shows on the HUD which way to walk to the next one.
--
-- ---------------------------------------------------------------------------------------
-- HOW A STOP IS MARKED (no new button, nothing of the game's map screen is touched)
-- ---------------------------------------------------------------------------------------
--
-- You keep using the map's own "Set Destination". The game keeps ONE destination, so each time you set a
-- new one the old one would be gone; with "keep replaced destinations as stops" on, this add-on keeps it
-- as a stop instead. Mark the places in the order you will walk them and the last one, the game's own
-- destination pin, is where you end up:
--
--     R3 on A  ->  destination A
--     R3 on B  ->  stop 1 = A,            destination B
--     R3 on C  ->  stops 1, 2 = A, B,     destination C
--
-- The stops are drawn on the map as numbered pins. On the HUD an arrow points at the next stop (then at
-- the destination), with the distance. Reaching a stop (within the radius set in the panel) moves on to the
-- next one.
--
-- ---------------------------------------------------------------------------------------
-- THE GEOMETRY
-- ---------------------------------------------------------------------------------------
--
-- The game's own convention, as the client uses it itself to show "which way is that furniture" in the housing
-- editor (esoui/ingame/housingeditor/furnitureclasses_shared.lua RefreshPositionalData, and
-- keyboard/housingfurnitureretrieval_keyboard.lua, which turns an up-pointing arrow by the result):
--
--   bearing of an offset (dx, dz) in world centimetres = atan2(dx, dz)     (0 = along +Z, pi/2 = along +X)
--   GetPlayerCameraHeading()                           = the bearing of where the camera looks
--   the angle to give SetTextureRotation to an arrow that points up = bearing - heading
--
-- Nothing here says which compass direction +X or +Z is: the map decides that (Nav.lua turns a map offset into
-- world centimetres with a matrix measured from the game), and compass words are only ever worked out from
-- the MAP's own axes (east = +x, south = +y). PB's first versions assumed "0 = north, west is positive" and
-- drew the arrow turned half a circle from where the client draws it.

PBS_WAYPOINT = {
	name = "PBsWayPoint",
	baseTitle = "PB’s WayPoint",
	chatName = "PB’s WayPoint",
	author = "PinkBanther",
	version = "0.5.1",
	slash = "/pbwp",
	shortSlash = "/pbwaypoint",
	-- a file marks itself here on its last line (see Main.lua: it tells "the files did not run" from "start-up failed")
	loaded = {},
	defaults = {
		enabled = true, -- the HUD guide
		addMode = true, -- a destination that is replaced on the map is kept as a stop
		pins = true, -- numbered pins on the map
		arrow = true, -- the arrow and the distance
		trail = true, -- the beads on the ground and the beam at the stop
		sound = true,
		chat = false, -- messages in the chat box (a typed command always gets its answer)
		preview = true, -- show the guide while the settings panel is open
		resetChord = true, -- L3 and R3 pressed together on the map reset the waypoints (see Chord.lua)
		shareSend = true, -- the stops you mark are sent to the group (see Share.lua)
		shareReceive = true, -- ... and the group's are taken over
		arriveRadius = 20, -- metres
		arrowSize = 80, -- pixels
		opacity = 90, -- percent
		x = 0, -- the arrow, from the top centre of the screen
		y = 130,
		trailLength = 40, -- metres ahead
	},
}
local A = PBS_WAYPOINT

-- The version comes from the manifest, the same way PB's other add-ons read it.
do
	local manager = GetAddOnManager and GetAddOnManager()
	if manager then
		for index = 1, manager:GetNumAddOns() do
			local name, title = manager:GetAddOnInfo(index)
			if name == A.name and title then
				local plain = title:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
				A.version = plain:match("(%d+[%d%.]*)%s*$") or A.version
				break
			end
		end
	end
end
A.title = A.baseTitle .. " " .. A.version

A.MAX_STOPS = 12 -- the pins are numbered 1 to 12
A.SETTLE_MS = 400 -- a removed destination is only "removed" if no new one follows this fast

-- ---------------------------------------------------------------------------------------
-- Settings: what each one may be
-- ---------------------------------------------------------------------------------------

local RANGES = {
	arriveRadius = { 5, 100 },
	arrowSize = { 40, 160 },
	opacity = { 10, 100 },
	x = { -900, 900 },
	y = { 0, 900 },
	trailLength = { 10, 100 },
}
A.RANGES = RANGES

local function number(value, low, high, default)
	local n = tonumber(value)
	if not n or n ~= n then
		return default
	end
	return math.max(low, math.min(high, n))
end

function A:Validate(key, value, default)
	if RANGES[key] then
		return math.floor(number(value, RANGES[key][1], RANGES[key][2], default) + 0.5)
	end
	if type(value) ~= type(default) then
		return default
	end
	return value
end

-- Called once the saved variables are loaded. Whatever is in the file, the add-on runs on values it
-- can use.
function A:Sanitize()
	local sv = self.sv
	for key, default in pairs(self.defaults) do
		sv[key] = self:Validate(key, sv[key], default)
	end
	if type(sv.probe) ~= "table" then
		sv.probe = {}
	end
	-- A call that was started and never finished: the client showed its UI error and the player
	-- reloaded. That call is not made again (see Nav.lua).
	if type(sv.pending) == "string" then
		sv.probe[sv.pending] = "bad"
		self.lastCrash = sv.pending
		sv.pending = nil
	end
	-- The same for the input layer on the map screen, which is only up while the map is (see Chord.lua).
	if sv.pendingChord then
		sv.probe.chordLayer = "bad"
		self.lastCrash = "the L3 + R3 layer on the map screen"
		sv.pendingChord = nil
	end
	-- what earlier versions kept: the triangle long press (0.3.x) is gone
	sv.pendingHold, sv.longPress, sv.holdMs = nil, nil, nil
	sv.probe.holdLayer = nil
	-- What happened to the guide, kept across a reload so that a disappearance can be read afterwards (/pbwp status).
	-- This session's lines are in A.traceLog; the file holds them as text.
	local earlier = {}
	if type(sv.trace) == "table" then
		for _, line in ipairs(sv.trace) do
			if type(line) == "string" and #earlier < A.TRACE_MAX then
				earlier[#earlier + 1] = line:sub(1, 240)
			end
		end
	end
	self.earlierTrace = earlier
	sv.trace = {}
	self.traceLog = {}
end

-- ---------------------------------------------------------------------------------------
-- The trace: why the guide went away
--
-- Every change that can take the guide (or part of it) off the screen leaves one line here: the route losing a stop
-- or the destination, the position or the zone map not being available, the tick or the trail stopping, the screen
-- being something else than the HUD. Nothing is printed; `/pbwp status` lists the lines (and the ones the last
-- session left), so a guide that disappeared can be explained afterwards.
-- ---------------------------------------------------------------------------------------

A.TRACE_MAX = 24

function A:Trace(kind, text)
	local log = self.traceLog
	if not log then
		return
	end
	local now = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
	local last = log[#log]
	local saved = self.sv and self.sv.trace
	if last and last.kind == kind and last.text == text and now - last.at < 1000 then
		last.count = last.count + 1 -- the same thing again at once: counted, not listed again
		if saved then
			saved[#saved] = A.TraceText(last)
		end
	else
		local item = { at = now, kind = kind, text = text, count = 1 }
		log[#log + 1] = item
		if saved then
			saved[#saved + 1] = A.TraceText(item)
		end
		while #log > A.TRACE_MAX do
			table.remove(log, 1)
			if saved then
				table.remove(saved, 1)
			end
		end
	end
end

function A.TraceText(item)
	return string.format("%.1fs %s: %s%s", item.at / 1000, item.kind, item.text, item.count > 1 and string.format(" (x%d)", item.count) or "")
end

-- This session's lines, oldest first, then the previous session's.
function A:TraceLines()
	local lines = {}
	for _, item in ipairs(self.traceLog or {}) do
		lines[#lines + 1] = A.TraceText(item)
	end
	local earlier = {}
	for _, line in ipairs(self.earlierTrace or {}) do
		earlier[#earlier + 1] = line
	end
	return lines, earlier
end

function A:Set(key, value)
	if self.defaults[key] == nil then
		return
	end
	self.sv[key] = self:Validate(key, value, self.defaults[key])
	if self.OnSettingChanged then
		self:OnSettingChanged(key)
	end
end

function A:Reset()
	for key, value in pairs(self.defaults) do
		self.sv[key] = value
	end
	if self.OnSettingChanged then
		self:OnSettingChanged(nil)
	end
end

-- ---------------------------------------------------------------------------------------
-- Geometry (no game calls in here)
-- ---------------------------------------------------------------------------------------

local PI = math.pi
local sin, cos, sqrt, floor = math.sin, math.cos, math.sqrt, math.floor
local atan2 = math.atan2 or function(y, x)
	return math.atan(y, x)
end

-- The game's bearing of an offset of dx, dz world centimetres (the same number GetPlayerCameraHeading() has
-- when the camera looks that way).
function A.Bearing(dx, dz)
	return atan2(dx, dz)
end

-- The world offset (dx, dz) of a point `distance` away in the direction of a bearing.
function A.Offset(bearing, distance)
	return sin(bearing) * distance, cos(bearing) * distance
end

-- The angle to turn an up-pointing arrow so that it points at `bearing` for a camera looking along `heading`,
-- kept between -pi and pi. Positive is the way the client's own SetTextureRotation calls turn it.
function A.ScreenAngle(bearing, heading)
	local angle = (bearing - heading) % (PI * 2)
	if angle > PI then
		angle = angle - PI * 2
	end
	return angle
end

-- Compass bearing, 0 = north and counted towards the west, of a direction given on the MAP's axes (east, south).
function A.CompassBearing(east, south)
	return atan2(-east, -south)
end

function A.Distance(dx, dz)
	return sqrt(dx * dx + dz * dz)
end

-- 85 m, 1.2 km.
function A.FormatDistance(centimetres)
	local metres = centimetres / 100
	if metres < 1000 then
		return string.format("%d m", floor(metres + 0.5))
	end
	return string.format("%.1f km", metres / 1000)
end

local WORDS = { "N", "NW", "W", "SW", "S", "SE", "E", "NE" }
-- "W" for a compass bearing (A.CompassBearing) of pi/2: the eight-point name of a direction.
function A.HeadingWord(compassBearing)
	local degrees = (compassBearing * 180 / PI) % 360
	return WORDS[floor((degrees + 22.5) / 45) % 8 + 1]
end

-- The inverse of [[a, b], [c, d]] as a, b, c, d, or nil when it cannot be inverted.
function A.Invert(a, b, c, d)
	local det = a * d - b * c
	if det ~= det or math.abs(det) < 1e-18 then
		return nil
	end
	return d / det, -b / det, -c / det, a / det
end

A.loaded.Core = true
