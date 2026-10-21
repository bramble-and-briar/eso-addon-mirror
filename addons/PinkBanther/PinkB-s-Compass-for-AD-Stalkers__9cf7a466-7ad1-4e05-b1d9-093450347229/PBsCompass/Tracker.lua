-- Where the camera points and where the group is. Everything the game is asked lives in this file.
local A = PBS_COMPASS

local ROSTER_MS = 2000 -- how often the group is read again (events also mark it stale)
local LOCATE_MS = 100 -- how often positions are read; the ring itself is turned every frame
local CALIBRATE_MIN_CM = 800 -- the player must have moved this far before two samples give a scale
local WORLD_FN = "GetUnitRawWorldPosition"

local floor, sqrt = math.floor, math.sqrt
local Distance = A.Distance

A.diag = {
	ticks = 0,
	located = 0, -- members placed on the last read
	world = 0, -- ... of which by world position
	map = 0, -- ... by map position and a measured scale
	direction = 0, -- ... by direction alone
	skipped = 0, -- group members left out (offline, other zone or instance)
	axisAgree = 0, -- world X/Z moved the way the map's x/y did
	axisDisagree = 0,
}
A.roster = {}
A.located = {}
A.cal = { scale = nil, zone = nil }
A.world = { checked = false, usable = false, why = "not checked yet" }

-- ---------------------------------------------------------------------------------------
-- Heading
-- ---------------------------------------------------------------------------------------

-- Radians, north 0 and west pi/2; nil if the game gives nothing usable.
function A:ReadHeading()
	local heading = GetPlayerCameraHeading()
	if type(heading) ~= "number" or heading ~= heading then
		return nil
	end
	return heading
end

-- ---------------------------------------------------------------------------------------
-- The world position call
--
-- GetUnitRawWorldPosition is documented without a private marker, and that marker has been wrong
-- before; a private call raises the client's UI error, which pcall does not catch. So the API is
-- asked first (IsPrivateFunction / IsProtectedFunction) and, either way, `pending` is written to the
-- saved variables before the first call and cleared when it returns. If the game ever shows the error
-- and the player reloads, the file still says "pending", and next time that call is not made
-- (Sanitize in Core.lua). `/pbcompass retry` forgets what was learned.
-- ---------------------------------------------------------------------------------------

function A:CheckWorld()
	local world = self.world
	if world.checked then
		return world.usable
	end
	world.checked = true
	world.usable = false
	local probe = self.sv.probe

	if probe.world == "bad" then
		world.why = "it failed on an earlier login"
	elseif type(GetUnitRawWorldPosition) ~= "function" then
		world.why = "the function does not exist"
	else
		local refused
		if probe.ask == "bad" then
			world.asked = "skipped: the question failed on an earlier login"
		elseif type(IsPrivateFunction) == "function" and type(IsProtectedFunction) == "function" then
			self.sv.pending = "ask"
			local okPrivate, isPrivate = pcall(IsPrivateFunction, WORLD_FN)
			local okProtected, isProtected = pcall(IsProtectedFunction, WORLD_FN)
			self.sv.pending = nil
			if okPrivate and okProtected then
				world.asked = (isPrivate and "private" or "not private") .. ", " .. (isProtected and "protected" or "not protected")
				refused = isPrivate or isProtected
			else
				world.asked = "the question failed"
			end
		else
			world.asked = "cannot ask"
		end
		if refused then
			world.why = "the game marks it private or protected"
		else
			world.usable = true
			world.why = "allowed"
			self.sv.pending = "world"
		end
	end
	return world.usable
end

-- zone, x, z in centimetres; nil when the unit has no position in this world.
function A:WorldOf(tag)
	if not self:CheckWorld() then
		return nil
	end
	local zone, x, _, z = GetUnitRawWorldPosition(tag)
	if self.sv.pending == "world" then
		self.sv.pending = nil
		self.sv.probe.world = "ok"
	end
	if type(zone) ~= "number" or zone == 0 or type(x) ~= "number" or type(z) ~= "number" or (x == 0 and z == 0) then
		return nil
	end
	return zone, x, z
end

-- Normalised x, y on the map the client has open, which is the one for the player's own location
-- (checked by the caller); nil for a unit the map does not show.
local function MapOf(tag)
	local nx, ny, _, inMap, symbolic = GetMapPlayerPosition(tag)
	if not inMap or symbolic or type(nx) ~= "number" or type(ny) ~= "number" or (nx == 0 and ny == 0) then
		return nil
	end
	return nx, ny
end

-- ---------------------------------------------------------------------------------------
-- The group
-- ---------------------------------------------------------------------------------------

local function Here(tag)
	-- The client's own map shows a member only in the same world, instance and layer.
	if IsGroupMemberInSameWorldAsPlayer and not IsGroupMemberInSameWorldAsPlayer(tag) then
		return false
	end
	if IsGroupMemberInSameInstanceAsPlayer and not IsGroupMemberInSameInstanceAsPlayer(tag) then
		return false
	end
	if IsGroupMemberInSameLayerAsPlayer and not IsGroupMemberInSameLayerAsPlayer(tag) then
		return false
	end
	return true
end

-- What is written under a marker: the console ID (the PSN online ID on a PS5), as the client's own
-- name helpers do (zo_primaryplayername.lua falls back the same way when a unit has none): the
-- @account name, then the character name.
function A.MemberName(tag)
	local platform = GetUnitPlatformDisplayName and GetUnitPlatformDisplayName(tag) or ""
	if platform ~= "" then
		return platform
	end
	local account = GetUnitDisplayName and GetUnitDisplayName(tag) or ""
	if account ~= "" then
		return account
	end
	return A.CleanName(GetUnitName(tag))
end

function A:RefreshRoster()
	local roster = self.roster
	for i = #roster, 1, -1 do
		roster[i] = nil
	end
	local skipped = 0
	for i = 1, GetGroupSize() do
		local tag = GetGroupUnitTagByIndex(i)
		if tag and tag ~= "" and DoesUnitExist(tag) and not AreUnitsEqual("player", tag) then
			if IsUnitOnline(tag) and Here(tag) then
				roster[#roster + 1] = {
					tag = tag,
					name = A.MemberName(tag),
				}
			else
				skipped = skipped + 1
			end
		end
	end
	self.diag.skipped = skipped
	self.rosterDirty = false
	self.rosterAt = GetGameTimeMilliseconds()
end

-- ---------------------------------------------------------------------------------------
-- A measured scale for the map
--
-- The world position is exact and is used whenever the game gives it. When it gives it for the player
-- but not for a member, the map position of that member is turned into metres with a scale learned
-- from the player's own movement: world distance moved over the map distance moved. The same samples
-- say whether world X and Z run the way the map's x and y do (they should: east and south).
-- ---------------------------------------------------------------------------------------

function A:Calibrate(zone, wx, wz, nx, ny)
	local cal = self.cal
	if cal.zone ~= zone or not cal.wx then
		cal.scale = nil
		cal.zone, cal.wx, cal.wz, cal.nx, cal.ny = zone, wx, wz, nx, ny
		return
	end
	local dwx, dwz = wx - cal.wx, wz - cal.wz
	local dnx, dny = nx - cal.nx, ny - cal.ny
	local moved, mapMoved = sqrt(dwx * dwx + dwz * dwz), sqrt(dnx * dnx + dny * dny)
	if moved < CALIBRATE_MIN_CM or mapMoved <= 0 then
		return
	end
	local scale = moved / mapMoved
	-- A map change (a city inside the zone) shows as a sample far from the others: start over.
	if cal.scale and scale < cal.scale * 2 and scale > cal.scale / 2 then
		cal.scale = cal.scale * 0.7 + scale * 0.3
	else
		cal.scale = scale
	end
	if dwx * dnx + dwz * dny > 0 then
		self.diag.axisAgree = self.diag.axisAgree + 1
	else
		self.diag.axisDisagree = self.diag.axisDisagree + 1
	end
	cal.wx, cal.wz, cal.nx, cal.ny = wx, wz, nx, ny
end

-- Fills self.located with one entry per member that can be placed: dx, dz in metres (east, south),
-- distance in metres or nil when only the direction is known.
function A:Locate()
	local located, roster, diag = self.located, self.roster, self.diag
	for i = #located, 1, -1 do
		located[i] = nil
	end
	diag.located, diag.world, diag.map, diag.direction = 0, 0, 0, 0
	if #roster == 0 then
		return located
	end

	local pzone, px, pz = self:WorldOf("player")
	local pnx, pny
	if DoesCurrentMapMatchMapForPlayerLocation() then
		pnx, pny = MapOf("player")
	end
	if pzone and pnx then
		self:Calibrate(pzone, px, pz, pnx, pny)
	end
	local scale = self.cal.scale

	for _, member in ipairs(roster) do
		local dx, dz, distance, source
		if pzone then
			local zone, x, z = self:WorldOf(member.tag)
			if zone == pzone then
				dx, dz = (x - px) / 100, (z - pz) / 100
				distance, source = Distance(dx, dz), "world"
			end
		end
		if not dx and pnx then
			local nx, ny = MapOf(member.tag)
			if nx then
				dx, dz = nx - pnx, ny - pny
				if scale then
					dx, dz = dx * scale / 100, dz * scale / 100
					distance, source = Distance(dx, dz), "map"
				else
					-- Map units, not metres: only the direction means anything, so it is kept as a
					-- one-metre step that the "same spot" rule in UI.lua does not mistake for nothing.
					local length = Distance(dx, dz)
					if length > 0 then
						dx, dz = dx / length, dz / length
					end
					source = "direction"
				end
			end
		end
		if source then
			-- Standing on the same spot has no direction: keep the member where they were drawn.
			local entry = { member = member, dx = dx, dz = dz, distance = distance, source = source }
			located[#located + 1] = entry
			diag.located = diag.located + 1
			diag[source] = diag[source] + 1
		end
	end
	return located
end

-- Called every update tick while the compass is visible; keeps the cached group and positions fresh
-- without reading the game more often than it has to.
function A:Refresh(now)
	if self.rosterDirty or not self.rosterAt or now - self.rosterAt >= ROSTER_MS then
		self:RefreshRoster()
		self.locateAt = nil
	end
	if not self.locateAt or now - self.locateAt >= LOCATE_MS then
		self.locateAt = now
		self:Locate()
	end
	return self.located
end

function A:MarkRosterStale()
	self.rosterDirty = true
end

-- Members that are not in the group, for the preview and /pbcompass test: fixed places in the world,
-- so they turn with the camera the way real ones do.
local DEMO = {
	{ bearing = 0.61, fraction = 0.35, name = "PSN ID 1" },
	{ bearing = 2.80, fraction = 0.70, name = "PSN ID 2" },
	{ bearing = 4.30, fraction = 0.95, name = "PSN ID 3" },
	{ bearing = 5.45, fraction = 1.40, name = "PSN ID 4" },
}
function A:DemoMembers()
	local out = self.demo or {}
	self.demo = out
	local range = self.sv.range
	for i, spec in ipairs(DEMO) do
		local distance = spec.fraction * range
		local entry = out[i] or { member = { tag = "demo" .. i } }
		entry.member.name = spec.name
		entry.dx = -distance * math.sin(spec.bearing)
		entry.dz = -distance * math.cos(spec.bearing)
		entry.distance = distance
		entry.source = "demo"
		out[i] = entry
	end
	return out
end
