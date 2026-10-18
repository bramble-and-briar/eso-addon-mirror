-- PB's FurnitureEditor -- rotation, and finding out which rotation the client uses
--
-- To paste a group turned a quarter round, every furnishing has to be moved round the same
-- vertical axis and given the matching orientation. Positions are easy. Orientation is a
-- pitch, a yaw and a roll, and what that triple MEANS -- which axis each is about, which sign
-- is positive, which is applied first -- is the client's choice and is written down nowhere
-- the API shows. Guessing it wrong tilts every shelf in the copy.
--
-- So it is measured, from houses that already exist. For a placed furnishing the client gives
-- its position, its orientation, its local bounds (the box it fills before it is turned, in
-- metres) and its world bounds (the axis-aligned box around it after it is turned, in
-- centimetres). Turn the local box by a candidate convention, move it to the position, take
-- the axis-aligned box of the result, and compare it with the world bounds: the convention the
-- client really uses is the one that keeps getting the answer right. 48 candidates (six
-- multiplication orders, two signs for each of the three angles), ranked by error.
--
-- Only two facts are needed from the result, and both are checked for agreement across every
-- candidate that fits as well as the best one:
--   sy        +1 or -1: turning the group by +d of yaw is a turn of sy * d round the vertical axis
--   yawOuter  true when yaw is applied last of the three, which makes "turn the group" nothing
--             more than "add d to every yaw", whatever pitch and roll are doing
-- Everything that does not depend on a decision is pure arithmetic and is tested off the console.

local addon = PBS_FURNITURE_EDITOR

local geo = {}
addon.geo = geo

local cos, sin, abs, huge = math.cos, math.sin, math.abs, math.huge
local TWO_PI = math.pi * 2

-- A pitch, yaw or roll this close to nothing is nothing. Furnishings placed by hand carry
-- float dust (1e-7) in angles that are meant to be zero.
geo.FLAT_EPSILON = 0.001

-- ---------------------------------------------------------------------------------------
-- 3x3 matrices, row-major: { m11, m12, m13, m21, m22, m23, m31, m32, m33 }
-- ---------------------------------------------------------------------------------------

local function Rot(axis, a)
	local c, s = cos(a), sin(a)
	if axis == "X" then
		return { 1, 0, 0, 0, c, -s, 0, s, c }
	elseif axis == "Y" then
		return { c, 0, s, 0, 1, 0, -s, 0, c }
	end
	return { c, -s, 0, s, c, 0, 0, 0, 1 }
end

local function Mul(a, b)
	local m = {}
	for r = 0, 2 do
		for c = 0, 2 do
			m[r * 3 + c + 1] = a[r * 3 + 1] * b[c + 1] + a[r * 3 + 2] * b[c + 4] + a[r * 3 + 3] * b[c + 7]
		end
	end
	return m
end

local function Apply(m, x, y, z)
	return m[1] * x + m[2] * y + m[3] * z,
		m[4] * x + m[5] * y + m[6] * z,
		m[7] * x + m[8] * y + m[9] * z
end

geo.Rot = Rot
geo.Mul = Mul
geo.Apply = Apply

function geo.NormalizeAngle(a)
	a = a % TWO_PI
	if a > math.pi then
		a = a - TWO_PI
	end
	return a
end

function geo.IsFlat(pitch, roll)
	return abs(pitch or 0) < geo.FLAT_EPSILON and abs(roll or 0) < geo.FLAT_EPSILON
end

-- ---------------------------------------------------------------------------------------
-- Conventions
--
-- { order = "YXZ", sp = 1, sy = 1, sr = 1 }: pitch is a turn about X, yaw about Y, roll about
-- Z, each multiplied by its sign; "order" is the multiplication order, leftmost applied last.
-- ---------------------------------------------------------------------------------------

function geo.EulerMatrix(pitch, yaw, roll, conv)
	local angle = { X = conv.sp * pitch, Y = conv.sy * yaw, Z = conv.sr * roll }
	local a, b, c = string.sub(conv.order, 1, 1), string.sub(conv.order, 2, 2), string.sub(conv.order, 3, 3)
	return Mul(Mul(Rot(a, angle[a]), Rot(b, angle[b])), Rot(c, angle[c]))
end

local ORDERS = { "XYZ", "XZY", "YXZ", "YZX", "ZXY", "ZYX" }

function geo.AllConventions()
	local list = {}
	for _, order in ipairs(ORDERS) do
		for _, sp in ipairs({ 1, -1 }) do
			for _, sy in ipairs({ 1, -1 }) do
				for _, sr in ipairs({ 1, -1 }) do
					list[#list + 1] = {
						order = order,
						sp = sp,
						sy = sy,
						sr = sr,
						name = order .. (sp > 0 and "+" or "-") .. (sy > 0 and "+" or "-") .. (sr > 0 and "+" or "-"),
					}
				end
			end
		end
	end
	return list
end

function geo.IsYawOuter(conv)
	return string.sub(conv.order, 1, 1) == "Y"
end

-- ---------------------------------------------------------------------------------------
-- Predicting the world box
--
-- sample = { pitch, yaw, roll, x, y, z,                   orientation (radians), position (cm)
--            lmin = {x,y,z}, lmax = {x,y,z},              local bounds, metres
--            wmin = {x,y,z}, wmax = {x,y,z} }             world bounds, centimetres
-- ---------------------------------------------------------------------------------------

function geo.PredictBounds(sample, conv)
	local m = geo.EulerMatrix(sample.pitch, sample.yaw, sample.roll, conv)
	local minX, minY, minZ = huge, huge, huge
	local maxX, maxY, maxZ = -huge, -huge, -huge

	for i = 0, 1 do
		local lx = (i == 0 and sample.lmin[1] or sample.lmax[1]) * 100
		for j = 0, 1 do
			local ly = (j == 0 and sample.lmin[2] or sample.lmax[2]) * 100
			for k = 0, 1 do
				local lz = (k == 0 and sample.lmin[3] or sample.lmax[3]) * 100
				local x, y, z = Apply(m, lx, ly, lz)
				x, y, z = x + sample.x, y + sample.y, z + sample.z
				if x < minX then minX = x end
				if y < minY then minY = y end
				if z < minZ then minZ = z end
				if x > maxX then maxX = x end
				if y > maxY then maxY = y end
				if z > maxZ then maxZ = z end
			end
		end
	end

	return { minX, minY, minZ }, { maxX, maxY, maxZ }
end

-- Mean absolute difference over the six numbers, centimetres.
function geo.BoundsError(sample, conv)
	local pmin, pmax = geo.PredictBounds(sample, conv)
	local total = 0
	for axis = 1, 3 do
		total = total + abs(pmin[axis] - sample.wmin[axis]) + abs(pmax[axis] - sample.wmax[axis])
	end
	return total / 6
end

-- A sample says something about the yaw sign only if turning it moves the box, which needs a
-- box that is not centred on its own origin in the ground plane, and an angle that is not 0.
function geo.IsInformative(sample)
	local offCentre = math.max(
		abs(sample.lmin[1] + sample.lmax[1]),
		abs(sample.lmin[3] + sample.lmax[3]))
	if offCentre < 0.05 then
		return false
	end
	return abs(geo.NormalizeAngle(sample.yaw)) > 0.05
end

-- The pure-rotation test: with no rotation at all the world box must be the local box moved to
-- the position. If it is not, local bounds are not what this file thinks they are, and no
-- ranking below means anything.
function geo.RestError(sample)
	local rest = { order = "YXZ", sp = 1, sy = 1, sr = 1 }
	local flat = {
		pitch = 0, yaw = 0, roll = 0,
		x = sample.x, y = sample.y, z = sample.z,
		lmin = sample.lmin, lmax = sample.lmax, wmin = sample.wmin, wmax = sample.wmax,
	}
	return geo.BoundsError(flat, rest)
end

-- ---------------------------------------------------------------------------------------
-- Ranking
-- ---------------------------------------------------------------------------------------

-- One furnishing's disagreement counts for at most this much, so that a mesh whose true box is
-- tighter than the corners of its local box cannot drown everything else.
local CLIP_CM = 60

function geo.FitConventions(samples)
	local ranked = {}
	for _, conv in ipairs(geo.AllConventions()) do
		local total = 0
		for _, sample in ipairs(samples) do
			total = total + math.min(geo.BoundsError(sample, conv), CLIP_CM)
		end
		ranked[#ranked + 1] = {
			conv = conv,
			err = #samples > 0 and total / #samples or huge,
		}
	end

	table.sort(ranked, function(a, b)
		if a.err ~= b.err then
			return a.err < b.err
		end
		return a.conv.name < b.conv.name
	end)

	return ranked
end

-- What the ranking settles. A fact is "settled" only when every candidate that fits as well as
-- the best one agrees on it; candidates that differ only in things the samples cannot see (a
-- roll sign on a box that is symmetric about its roll axis) are listed, not guessed between.
--
--   fits       candidates within 5% (and half a centimetre) of the best
--   sy         the yaw sign, or nil when the fitting candidates disagree
--   yawOuter   true / false, or nil when they disagree
--   margin     error of the first candidate that does NOT fit, over the best's; below 1.5 the
--              samples did not tell the candidates apart
function geo.Decide(ranked)
	local best = ranked[1]
	if not best or best.err == huge then
		return nil
	end

	local limit = best.err * 1.05 + 0.5
	local fits = {}
	local firstOut
	for _, entry in ipairs(ranked) do
		if entry.err <= limit then
			fits[#fits + 1] = entry
		elseif not firstOut then
			firstOut = entry
		end
	end

	local sy = fits[1].conv.sy
	local yawOuter = geo.IsYawOuter(fits[1].conv)
	for i = 2, #fits do
		if fits[i].conv.sy ~= sy then
			sy = nil
		end
		if geo.IsYawOuter(fits[i].conv) ~= yawOuter then
			yawOuter = nil
		end
	end

	return {
		best = best,
		fits = fits,
		sy = sy,
		yawOuter = yawOuter,
		margin = firstOut and (firstOut.err / math.max(best.err, 0.01)) or huge,
	}
end

-- ---------------------------------------------------------------------------------------
-- Turning a group
--
-- The group is turned by `delta` of YAW (so that +90 degrees means what the editor's own yaw
-- means), round the vertical line through (cx, cz). A position is moved round that line by
-- sy * delta; an orientation, when yaw is applied last, just gains delta of yaw.
-- ---------------------------------------------------------------------------------------

function geo.RotateOffset(sy, delta, dx, dz)
	local phi = sy * delta
	local c, s = cos(phi), sin(phi)
	return c * dx + s * dz, -s * dx + c * dz
end

-- Can this furnishing be turned by a non-zero delta with what is known? Flat pieces always can
-- (their yaw is the only angle there is). Tilted pieces only when yaw is applied last.
function geo.CanTurn(conv, pitch, roll)
	if not conv or not conv.sy then
		return false
	end
	return geo.IsFlat(pitch, roll) or conv.yawOuter == true
end
