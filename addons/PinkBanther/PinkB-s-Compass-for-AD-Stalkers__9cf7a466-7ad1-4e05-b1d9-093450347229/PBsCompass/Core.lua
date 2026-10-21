-- PB's Compass for AD Stalkers
-- Author: PinkBanther
--
-- A translucent compass ring around the reticle in the middle of the screen. N, E, S and W sit on the
-- ring and turn with the camera; each member of your group is a small marker inside the ring, in the
-- direction they are from you and nearer the middle the closer they are.
--
-- ---------------------------------------------------------------------------------------
-- WHO MAY USE IT
-- ---------------------------------------------------------------------------------------
--
-- Two PSN IDs only: SO1-WYLDE and PinkBanther (Main.lua). The check reads the console ID of the player
-- who is logged in (GetPlatformDisplayName); the ESO @account is not consulted. Anyone else gets one
-- line in chat after login and nothing more: no events, no settings panel, no saved variables.
--
-- ---------------------------------------------------------------------------------------
-- THE GEOMETRY
-- ---------------------------------------------------------------------------------------
--
-- GetPlayerCameraHeading() is a bearing counted from north towards west (0 = north, pi/2 = west):
-- the world map turns the player's arrow by exactly that value, and a texture rotation is
-- counter-clockwise for a positive angle. World coordinates are centimetres, X east and Z south
-- (the world map's normalised y grows southwards and follows Z).
--
--   bearing of an offset (dx east, dz south)  = atan2(-dx, -dz)       north 0, west pi/2
--   angle on the screen, clockwise from up    = rotation - bearing
--   screen offset                             = (r sin a, -r cos a)
--
-- `rotation` is the camera heading (the ring turns with the camera, so what is straight ahead is at
-- the top) or 0 (north stays at the top).

PBS_COMPASS = {
	name = "PBsCompass",
	baseTitle = "PB’s Compass for AD Stalkers",
	chatName = "PB’s Compass",
	author = "PinkBanther",
	version = "1.0.0",
	slash = "/pbcompass",
	shortSlash = "/pbcmp",
	defaults = {
		enabled = true,
		opacity = 60,
		radius = 200,
		x = 0,
		y = 0,
		range = 50,
		markerSize = 22,
		letterSize = "medium",
		rotate = "camera",
		names = false,
		ring = false,
		preview = true,
	},
}
local A = PBS_COMPASS

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

-- ---------------------------------------------------------------------------------------
-- Settings: what each one may be
-- ---------------------------------------------------------------------------------------

local RANGES = {
	opacity = { 10, 100 },
	radius = { 60, 500 },
	x = { -800, 800 },
	y = { -500, 500 },
	range = { 10, 300 },
	markerSize = { 8, 64 },
}
local ENUMS = {
	letterSize = { small = true, medium = true, large = true },
	rotate = { camera = true, north = true },
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
	if ENUMS[key] then
		return ENUMS[key][value] and value or default
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
	-- reloaded. That call is not made again (see Tracker.lua).
	if type(sv.pending) == "string" then
		sv.probe[sv.pending] = "bad"
		self.lastCrash = sv.pending
		sv.pending = nil
	end
end

function A:Set(key, value)
	if self.defaults[key] == nil then
		return
	end
	self.sv[key] = self:Validate(key, value, self.defaults[key])
	self:ApplyLayout()
	self:RefreshVisibility()
end

function A:Reset()
	for key, value in pairs(self.defaults) do
		self.sv[key] = value
	end
	self:ApplyLayout()
	self:RefreshVisibility()
end

-- ---------------------------------------------------------------------------------------
-- Names (for the PSN ID check)
-- ---------------------------------------------------------------------------------------

local lower = zo_strlower or string.lower
local FULLWIDTH_AT = "\239\188\160" -- U+FF20, what a Japanese keyboard types for @
local IDEOGRAPHIC_SPACE = "\227\128\128" -- U+3000

local function Trim(s)
	return (s:gsub(IDEOGRAPHIC_SPACE, " "):match("^%s*(.-)%s*$"))
end

-- "@Foo", "foo", "＠FOO" and a name still carrying its "^Fx" gender suffix all land on one key.
function A.NameKey(raw)
	if type(raw) ~= "string" or raw == "" then
		return ""
	end
	local s = Trim(raw:gsub("%^%a+$", ""))
	if s:sub(1, 3) == FULLWIDTH_AT then
		s = s:sub(4)
	elseif s:sub(1, 1) == "@" then
		s = s:sub(2)
	end
	return lower(Trim(s))
end

-- For showing a name, not for comparing it.
function A.CleanName(raw)
	return (tostring(raw or ""):gsub("%^.*$", ""))
end

-- ---------------------------------------------------------------------------------------
-- Geometry (no game calls in here)
-- ---------------------------------------------------------------------------------------

local PI = math.pi
local sin, cos, sqrt, floor = math.sin, math.cos, math.sqrt, math.floor
local atan2 = math.atan2 or function(y, x)
	return math.atan(y, x)
end

-- Counter-clockwise from north, for an offset of dx metres east and dz metres south.
function A.Bearing(dx, dz)
	return atan2(-dx, -dz)
end

-- Clockwise from straight up on the screen, kept between -pi and pi.
function A.ScreenAngle(bearing, rotation)
	local angle = (rotation - bearing) % (PI * 2)
	if angle > PI then
		angle = angle - PI * 2
	end
	return angle
end

function A.Polar(angle, radius)
	return radius * sin(angle), -radius * cos(angle)
end

-- The ring's four letters. `bearing` is where each one is in the world.
A.CARDINALS = {
	{ key = "N", bearing = 0 },
	{ key = "W", bearing = PI / 2 },
	{ key = "S", bearing = PI },
	{ key = "E", bearing = PI * 1.5 },
}

-- Members are a guide to where somebody is, not a measurement: their place is relative, and the whole
-- marker always stays inside the circle the four letters stand on. `limit` is the farthest a marker's
-- centre may be from the middle: the ring's radius less the letter's half size (the letters are
-- centred on the ring) and the marker's own half size.
function A.MemberLimit(ring, letterPx, markerSize)
	return math.max(ring * 0.3, ring - letterPx * 0.5 - markerSize * 0.5)
end

-- How far from the middle a member is drawn, and whether they are beyond the range. Distance is
-- drawn in proportion up to the range and a member beyond it sits on the limit; one close by is kept
-- off the reticle. No distance (direction only) is drawn half way.
local NEAR = 0.2
function A.MemberRadius(limit, distance, range)
	if not distance then
		return limit * (NEAR + (1 - NEAR) * 0.5), false
	end
	local fraction = distance / range
	local far = fraction > 1
	if far then
		fraction = 1
	end
	return limit * (NEAR + (1 - NEAR) * fraction), far
end

local WORDS = { "N", "NW", "W", "SW", "S", "SE", "E", "NE" }
-- "W" for a heading of pi/2: the eight-point name of where the camera looks.
function A.HeadingWord(heading)
	local degrees = (heading * 180 / PI) % 360
	return WORDS[floor((degrees + 22.5) / 45) % 8 + 1]
end

function A.Distance(dx, dz)
	return sqrt(dx * dx + dz * dz)
end
