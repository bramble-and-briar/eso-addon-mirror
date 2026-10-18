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
-- So the answer is accepted only if the camera is looking down and the point is in front of it. The
-- camera's direction in world space is GetCameraForward(SPACE_WORLD). Without that call the test is
-- done on the answers themselves: aim a little lower, and a point in front comes closer while one
-- behind goes further away.
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

local function Dimensions()
	local ok, width, height = pcall(function()
		return GuiRoot:GetDimensions()
	end)
	if ok and width and height and width > 0 and height > 0 then
		return width, height
	end
	return 1920, 1080
end

-- Returns { x, y, z, distance, forward = {x,y,z} or nil } for the floor point under the cursor, or nil
-- and why not. y is the floor's: the player's own height.
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

	-- which way the camera looks, in the world's own axes
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

	if forward then
		-- in front of the camera: the player stands roughly at it, give or take a third-person camera
		if dx * forward.x + dz * forward.z < -BEHIND_TOLERANCE_CM then
			return nil, "the point is behind you"
		end
	else
		-- no camera direction: aim a little lower; a point in front comes nearer, one behind goes away
		local lowerX, lowerZ = look(height / 2 + height * SECOND_LOOK)
		if lowerX then
			local lowerDistance = math.sqrt((lowerX - pose.x) ^ 2 + (lowerZ - pose.z) ^ 2)
			if lowerDistance > distance then
				return nil, "the cursor is pointing above the horizon"
			end
		end
	end

	if distance > MAX_DISTANCE_CM then
		return nil, string.format("the point is %.0f m away; aim closer to the floor", distance / 100)
	end

	return { x = x, y = floorY, z = z, distance = distance, forward = forward }
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
	Print("/pbfe paste aim go   puts the group there")
end)
