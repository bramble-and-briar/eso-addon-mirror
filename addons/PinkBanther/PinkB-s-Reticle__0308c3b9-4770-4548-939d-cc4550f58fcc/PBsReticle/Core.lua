-- PB's Reticle
-- Author: PinkBanther
--
-- A reticle with a clean design and a dark outline that reads on any background. It replaces the game's
-- small centre mark with one of eight designs (prism, aegis, dot, cross, ring, bracket, orbit, scope), tints
-- it by what you are looking at, closes it on an enemy and opens it on something friendly or usable, and
-- flashes a marker when your hits land.
--
-- This file holds everything that needs no controls: the settings and what each may be, the colours, the
-- way a target is classed, and the geometry of each design. Reticle.lua draws it.
--
-- ---------------------------------------------------------------------------------------
-- THE GEOMETRY
-- ---------------------------------------------------------------------------------------
--
-- Distances are in "u", one UI pixel at a size of 100 %; the settings' size multiplies them all. The
-- art is drawn four texture pixels to a unit (scripts/build_assets.py, which runs build_prism_assets.py for
-- the Prism), and PBS_RETICLE_SHAPES (generated beside the art, Geometry.lua) says how big each canvas is,
-- so the two cannot disagree.
--
-- `pose` is how far the reticle is closed or open, -1 .. 1: -1 is locked on an enemy (arms and brackets
-- draw in, the orbit turns a quarter of a gap so its arcs sit on the axes), +1 is open (everything moves
-- out a little, like the game's own reticle does over something usable), 0 is at rest.

PBS_RETICLE = {
	name = "PBsReticle",
	baseTitle = "PB’s Reticle",
	chatName = "PB’s Reticle",
	author = "PinkBanther",
	version = "1.1.0",
	slash = "/pbreticle",
	shortSlash = "/pbret",
	defaults = {
		enabled = true,
		preview = true,
		style = "prism",
		color = "white",
		auto = true,
		size = 100,
		weight = "regular",
		gap = 0,
		dot = true,
		outline = 100,
		opacity = 100,
		idle = 100,
		hit = true,
		anim = true,
	},
}
local A = PBS_RETICLE

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

A.STYLES = { "prism", "aegis", "dot", "cross", "ring", "bracket", "orbit", "scope" }
A.COLOR_NAMES = { "white", "cyan", "lime", "yellow", "orange", "pink", "red" }
A.WEIGHTS = { "thin", "regular", "bold" }

local RANGES = {
	size = { 50, 250 },
	gap = { -6, 40 },
	outline = { 0, 100 },
	opacity = { 20, 100 },
	idle = { 10, 100 },
}
local function set(list)
	local out = {}
	for _, key in ipairs(list) do
		out[key] = true
	end
	return out
end
local ENUMS = {
	style = set(A.STYLES),
	color = set(A.COLOR_NAMES),
	weight = set(A.WEIGHTS),
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

-- Called once the saved variables are loaded. Whatever is in the file, the add-on runs on values it can use.
function A:Sanitize()
	local sv = self.sv
	for key, default in pairs(self.defaults) do
		sv[key] = self:Validate(key, sv[key], default)
	end
end

function A:Set(key, value)
	if self.defaults[key] == nil then
		return
	end
	self.sv[key] = self:Validate(key, value, self.defaults[key])
	self:Apply()
end

function A:Reset()
	for key, default in pairs(self.defaults) do
		self.sv[key] = default
	end
	self:Apply()
end

-- ---------------------------------------------------------------------------------------
-- Colours
-- ---------------------------------------------------------------------------------------

A.COLORS = {
	white = { 1, 1, 1 },
	cyan = { 0.37, 0.91, 1 },
	lime = { 0.62, 1, 0.33 },
	yellow = { 1, 0.85, 0.25 },
	orange = { 1, 0.58, 0.2 },
	pink = { 1, 0.41, 0.71 },
	red = { 1, 0.3, 0.28 },
}

-- What the reticle looks like for what is under it. `pose` as above; `color` is used when the colour by
-- target is on, otherwise the chosen colour stays. Hits have colours of their own.
A.LOOKS = {
	none = { pose = 0 },
	interact = { pose = 1 }, -- something to use: a door, a node, a chest
	friendly = { pose = 1, color = { 0.43, 0.89, 0.63 } }, -- a friendly NPC or companion
	ally = { pose = 1, color = { 0.36, 0.78, 1 } }, -- another player on your side
	neutral = { pose = 1, color = { 1, 0.85, 0.25 } }, -- a neutral you cannot attack
	wary = { pose = -1, color = { 1, 0.85, 0.25 } }, -- a neutral you can attack (a critter, a bystander)
	hostile = { pose = -1, color = { 1, 0.3, 0.28 } },
	dead = { pose = 0, color = { 0.76, 0.79, 0.82 } },
}
A.HIT_COLORS = {
	hit = { 1, 1, 1 },
	crit = { 1, 0.82, 0.25 },
	kill = { 1, 0.3, 0.28 },
}
-- seconds; a kill is the longest and the biggest
A.HIT_LOOK = {
	hit = { duration = 0.22, from = 0.85, to = 1.3, pulse = 0.5, rank = 1 },
	crit = { duration = 0.30, from = 0.9, to = 1.45, pulse = 0.8, rank = 2 },
	kill = { duration = 0.55, from = 0.95, to = 1.65, pulse = 1.0, rank = 3 },
}

-- Which kind of target is under the reticle. Every argument is what the game says; the function reads
-- the UNIT_REACTION_* constants when called, so it can be tested with a stand-in.
function A.ClassifyTarget(exists, attackable, interact, reaction, dead)
	if not exists then
		return interact and "interact" or "none"
	end
	if dead then
		return "dead"
	end
	if reaction == UNIT_REACTION_HOSTILE then
		return "hostile"
	end
	if attackable then
		return "wary"
	end
	if reaction == UNIT_REACTION_PLAYER_ALLY then
		return "ally"
	end
	if reaction == UNIT_REACTION_FRIENDLY or reaction == UNIT_REACTION_NPC_ALLY or reaction == UNIT_REACTION_COMPANION then
		return "friendly"
	end
	if reaction == UNIT_REACTION_NEUTRAL then
		return "neutral"
	end
	return interact and "interact" or "none"
end

-- ---------------------------------------------------------------------------------------
-- The designs
-- ---------------------------------------------------------------------------------------

-- `dot`: a centre dot is part of it (the dot design is the dot; the others show it when the setting says so).
-- `arms`: four arms, `inner` u from the middle to where they start.
-- `ring` / `orbit`: a ring or four arcs of `r` u.
-- `brackets`: four corner brackets at `half` u from the middle.
-- `prism`: a custom faceted frame and cardinal ticks.
A.PRESETS = {
	-- Faceted frame, four floating ticks, and a diamond aiming point.
	prism = { dot = true, dotShape = "prismDot", dotScale = 0.9, prism = true },
	-- Four open arcs frame short aiming marks, leaving the centre and the cardinal gaps clear.
	aegis = { dot = true, dotScale = 0.9, orbit = { r = 25, turn = 0.5 }, arms = { inner = 8, length = 0.7, clearCenter = true } },
	dot = { dot = true, dotScale = 1.7 },
	cross = { dot = true, arms = { inner = 7 } },
	ring = { dot = true, ring = { r = 20 } },
	bracket = { dot = true, brackets = { half = 17 } },
	orbit = { dot = true, orbit = { r = 22 } },
	scope = { dot = true, ring = { r = 26 }, arms = { inner = 6 } },
}

-- The core diameter of the companion dot for each weight, in u.
A.DOT_CORE = { thin = 3.2, regular = 4.2, bold = 5.6 }

local pi = math.pi

function A.ArmShift(pose)
	return pose < 0 and pose * 2 or pose * 3
end

function A.BracketShift(pose)
	return pose * 3
end

function A.RingScale(pose, pulse)
	return 1 + 0.05 * pose + 0.04 * pulse
end

-- `orbit.turn` is how much of the eighth of a circle the design turns (the Aegis turns half of it).
function A.OrbitTurn(pose, orbit)
	return pose < 0 and -pose * pi / 4 * (orbit and orbit.turn or 1) or 0
end

function A.DotScale(pose)
	return 1 + 0.12 * math.max(0, -pose)
end

-- Arms never cross the middle or run into an enclosing ring or orbit.
function A.ArmInner(sv, preset, pose)
	local inner = preset.arms.inner + sv.gap + A.ArmShift(pose)
	local enclosure = preset.ring or preset.orbit
	if enclosure then
		-- The enclosure contracts on lock; reserve space at its smallest size.
		local radius = enclosure.r * A.RingScale(-1, 0)
		inner = math.min(inner, radius - PBS_RETICLE_SHAPES.armH.len * (preset.arms.length or 1) - 4)
	end
	local minimum = 1
	if preset.arms.clearCenter and A.ShowDot(sv, preset) then
		minimum = A.DotCore(sv, preset, pose) / 2 + 3.5
	end
	return math.max(minimum, inner)
end

function A.BracketHalf(sv, preset, pose)
	return math.max(10, preset.brackets.half + sv.gap + A.BracketShift(pose))
end

-- The core diameter of the centre dot, in u, for a pose.
function A.DotCore(sv, preset, pose)
	local core = A.DOT_CORE[sv.weight] * (preset.dotScale or 1)
	return core * A.DotScale(pose)
end

-- Whether the centre dot is drawn at all.
function A.ShowDot(sv, preset)
	return preset.dot and (sv.style == "dot" or sv.dot) or false
end
