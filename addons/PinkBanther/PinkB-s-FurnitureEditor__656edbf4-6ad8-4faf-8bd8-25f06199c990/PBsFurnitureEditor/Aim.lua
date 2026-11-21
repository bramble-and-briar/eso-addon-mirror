-- PB's FurnitureEditor -- where the cursor points
--
-- Coordinates differ from house to house, so "the original coordinates" only reproduce a build in the
-- house it came from. What always makes sense is a place in the house you are in: where you stand
-- ("here") or where you are looking. This reads the second.
--
-- The reticle is the middle of the screen, and the camera looks through it. The client has a call that
-- turns a point on the screen into a point in the world by meeting the camera's ray with a plane you
-- describe by three world points (HousingEditorGetScreenPointWorldPlaneIntersection; the editor HUD
-- uses it to drag a furnishing along an axis). Described as the floor you stand on, it gives the spot
-- on that floor the cursor points at.
--
-- A ray meets a plane on only one side of the camera, and the call's answer does not say which. Looking
-- UP, the floor is met BEHIND the camera, and a point there would be a group placed behind the player.
-- So the answer is accepted only if the camera is looking down and the point is in front of it.
--
-- WHICH WAY IS "IN FRONT" is measured, not assumed (1.0.8). The first version took it from
-- GetCameraForward(SPACE_WORLD) and compared that vector with offsets in the house's coordinates, which is
-- right only if the two share their axes. Nothing proves they do. What the series has measured on a PS5
-- (PB's PlayerMarkerExtension 0.4.6, 2026-11-21; PB's WayPoint 0.6.4) is that in RAW world coordinates +X is
-- east and +Z south, and that the bearing of where the camera looks, atan2(dx, dz), is
-- GetPlayerCameraHeading() + pi, where the client's own housing code (furnitureclasses_shared.lua,
-- RefreshPositionalData: atan2(dx, dz) - heading) works as if it were the heading itself: half a circle
-- apart. If the house's coordinates are the one and SPACE_WORLD the other, a point straight ahead has a
-- NEGATIVE dot product with the "forward" vector and is thrown out as "behind you", and a point behind is let
-- through. So the direction across the floor is read from the cursor's own call: the same screen column is
-- looked at twice, the second a little lower, and the vector from the lower floor point to the higher one is
-- the camera's direction across the floor, in the very axes the answers are in. GetCameraForward is kept for
-- what no horizontal axis can spoil, whether the camera looks down (its Y part), and for the /pbfe aim
-- report, which prints how the three directions (the cursor's, the heading's, SPACE_WORLD's) relate, so that
-- one console run settles what this house's axes are.
--
-- Without GetCameraForward the second look alone decides: aim a little lower, and a point in front comes
-- closer while one behind goes further away.
--
-- It is a floor at the height of your feet. Aim at a table top and it is the floor under the line of
-- sight, not the table; "up 90" (centimetres) lifts the group, and the group's root can be moved with
-- the editor afterwards because everything in it is linked.

local addon = PBS_FURNITURE_EDITOR

local Call, Try1 = addon.Call, addon.Try1
local Print, Line = addon.Print, addon.Line

-- Looking down less than this (the vertical part of a unit vector) is "at the horizon".
local MIN_DOWNWARD = 0.02

-- Farther than this from the player, in centimetres, is a wall, a window or the sky, not a spot.
local MAX_DISTANCE_CM = 3000

-- A point this far behind the player (third-person camera, looking steeply down) still counts.
local BEHIND_TOLERANCE_CM = 250

-- How far below the middle of the screen the second look is, as a fraction of its height.
local SECOND_LOOK = 0.1

-- Two floor points closer than this say nothing about a direction (the camera looks almost straight down).
local MIN_BASELINE_CM = 5

local PI = math.pi
local atan2 = math.atan2 or function(y, x)
	return math.atan(y, x)
end

-- An angle in radians brought into (-pi, pi].
local function Wrapped(angle)
	angle = angle % (2 * PI)
	if angle > PI then
		angle = angle - 2 * PI
	end
	return angle
end

local function Dimensions()
	local ok, width, height = pcall(function()
		return GuiRoot:GetDimensions()
	end)
	if ok and width and height and width > 0 and height > 0 then
		return width, height
	end
	return 1920, 1080
end

-- The direction the camera looks across the floor, in the axes of the house's coordinates, from two floor
-- points of one screen column (`high` the cursor's, `low` a little lower on the screen). A ray that goes
-- down meets the floor nearer for the lower point, a ray that goes up meets it (behind) farther, and in
-- both cases the vector from the lower point to the higher one is the camera's direction. Returns
-- { x, z } of unit length, or nil when the two points are too close to say.
local function FloorDirection(highX, highZ, lowX, lowZ)
	if not (highX and lowX) then
		return nil
	end
	local fx, fz = highX - lowX, highZ - lowZ
	local length = math.sqrt(fx * fx + fz * fz)
	if length < MIN_BASELINE_CM then
		return nil
	end
	return { x = fx / length, z = fz / length }
end

-- Returns { x, y, z, distance, facing = {x,z} or nil, forward = {x,y,z} or nil } for the floor point under
-- the cursor, or nil and why not. y is the floor's: the player's own height. `facing` is the camera's
-- direction across the floor in the house's axes as the cursor measured it; `forward` is what
-- GetCameraForward(SPACE_WORLD) said, kept for the report (only its Y part is trusted here).
function addon:AimPoint()
	local pose = self:PlayerPose()
	if not pose then
		return nil, "your position could not be read"
	end

	if type(HousingEditorGetScreenPointWorldPlaneIntersection) ~= "function" then
		return nil, "this build cannot turn the cursor into a point in the house"
	end

	local width, height = Dimensions()
	local floorY = pose.y

	local function look(screenY)
		local result = Call(HousingEditorGetScreenPointWorldPlaneIntersection, width / 2, screenY,
			pose.x, floorY, pose.z,
			pose.x + 100, floorY, pose.z,
			pose.x, floorY, pose.z + 100)
		if not result then
			return nil
		end

		-- the client's own test for "no answer": zeros
		local x, y, z = result[1], result[2], result[3]
		if x == nil or (x == 0 and y == 0 and z == 0) then
			return nil
		end
		return x, z
	end

	-- whether the camera looks down: the vertical part of its direction, which no horizontal axis can spoil
	local forward
	local reading = Call(GetCameraForward, SPACE_WORLD)
	if reading and reading[1] ~= nil and reading[2] ~= nil and reading[3] ~= nil then
		forward = { x = reading[1], y = reading[2], z = reading[3] }
	end

	if forward and forward.y > -MIN_DOWNWARD then
		return nil, "the cursor is not pointing down at the floor"
	end

	local x, z = look(height / 2)
	if not x then
		return nil, "the cursor does not meet the floor"
	end

	local dx, dz = x - pose.x, z - pose.z
	local distance = math.sqrt(dx * dx + dz * dz)

	-- the second look, a little lower: it gives the camera's direction across the floor, and without a
	-- camera direction it is also what tells a point in front from one behind
	local lowerX, lowerZ = look(height / 2 + height * SECOND_LOOK)
	local facing = FloorDirection(x, z, lowerX, lowerZ)

	if forward then
		-- in front of the camera: the player stands roughly at it, give or take a third-person camera.
		-- Measured in the house's own axes; with no direction to measure (the camera looks almost straight
		-- down, or the second look was refused) the point is at most a camera's distance from the player
		-- and is not thrown out.
		if facing and dx * facing.x + dz * facing.z < -BEHIND_TOLERANCE_CM then
			return nil, "the point is behind you"
		end
	elseif lowerX then
		local lowerDistance = math.sqrt((lowerX - pose.x) ^ 2 + (lowerZ - pose.z) ^ 2)
		if lowerDistance > distance then
			return nil, "the cursor is pointing above the horizon"
		end
	end

	if distance > MAX_DISTANCE_CM then
		return nil, string.format("the point is %.0f m away; aim closer to the floor", distance / 100)
	end

	return { x = x, y = floorY, z = z, distance = distance, facing = facing, forward = forward }
end

-- How the camera's directions relate, as lines for /pbfe aim: the cursor's own (the house's axes), the
-- heading's, and SPACE_WORLD's. A bearing is atan2(dx, dz): 0 along +Z, 90 degrees along +X.
function addon:AimAxesReport(aim)
	local lines = {}
	local heading = Try1(GetPlayerCameraHeading)
	local measured = aim.facing and atan2(aim.facing.x, aim.facing.z) or nil

	if measured and type(heading) == "number" then
		local relation = math.deg(Wrapped(measured - heading))
		local reading
		if math.abs(relation) <= 15 then
			reading = "the housing editor's formula (the heading is the bearing) fits these coordinates"
		elseif math.abs(relation) >= 165 then
			reading = "the PS5 measurement of the series (the bearing is the heading + 180) fits these coordinates"
		else
			reading = "neither the housing editor's formula nor the series' PS5 measurement"
		end
		lines[#lines + 1] = string.format("the cursor looks along bearing %.0f deg in the house's axes; camera heading %.0f deg, so bearing = heading %+.0f deg: %s",
			math.deg(measured), math.deg(heading), relation, reading)
	elseif not measured then
		lines[#lines + 1] = "the camera's direction across the floor could not be measured (looking almost straight down?)"
	end

	local forward = aim.forward
	if forward and measured then
		local horizontal = math.sqrt(forward.x * forward.x + forward.z * forward.z)
		if horizontal < 0.2 then
			lines[#lines + 1] = "GetCameraForward points too steeply down to compare its direction"
		else
			local difference = math.deg(Wrapped(atan2(forward.x, forward.z) - measured))
			local verdict
			if math.abs(difference) <= 15 then
				verdict = "in the house's axes"
			elseif math.abs(difference) >= 165 then
				verdict = "the OPPOSITE way to the house's axes (not used for the front/behind test)"
			else
				verdict = "turned from the house's axes (not used for the front/behind test)"
			end
			lines[#lines + 1] = string.format("GetCameraForward(SPACE_WORLD) is %+.0f deg from that: %s", difference, verdict)
		end
	end
	return lines
end

-- ---------------------------------------------------------------------------------------
-- /pbfe aim
-- ---------------------------------------------------------------------------------------

addon:AddCommand("aim", "  /pbfe aim               where the cursor points on the floor (look down at it first)", function(self)
	local pose = self:PlayerPose()
	if not pose then
		Print("not in a house")
		return
	end

	local reading = Call(GetCameraForward, SPACE_WORLD)
	if reading and reading[1] ~= nil then
		Print("camera forward: %.2f %.2f %.2f (down is negative)", reading[1], reading[2], reading[3])
	else
		Print("GetCameraForward gave nothing; the front/behind check uses a second look")
	end

	local aim, why = self:AimPoint()
	if not aim then
		Print("no point: %s", why)
		return
	end

	Print("the cursor meets your floor at x %d z %d, %.1f m from you", aim.x, aim.z, aim.distance / 100)
	for _, text in ipairs(self:AimAxesReport(aim)) do
		Line("  %s", text)
	end
	Print("/pbfe paste aim go   puts the group there")
end)
