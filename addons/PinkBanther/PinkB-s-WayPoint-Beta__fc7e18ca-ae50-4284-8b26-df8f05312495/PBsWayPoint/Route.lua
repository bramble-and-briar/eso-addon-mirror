-- The route: the stops still to walk, then the destination. The only thing asked of the game in this file is whether it
-- still holds a destination (GameHasWaypoint, Nav.lua); Main.lua feeds it what the map says and Guide.lua asks it where to
-- go next.
--
--   route.vias  the stops not reached yet, in the order they are walked
--   route.dest  the game's own destination (the last stop), or nil
--   route.done  how many stops of this route have been reached: numbering goes on from there, so the
--               pin for the third stop says 3 whether or not the first two are behind you
--
-- A stop is { mapId, nx, ny } (where it was marked: a map and a point on it) and, when the game could
-- place that map, { ux, uy, us } (the same point in the universal space and the width of that map there;
-- see Nav.lua).
local A = PBS_WAYPOINT

local floor, abs = math.floor, math.abs

-- ---------------------------------------------------------------------------------------
-- Loading what was saved
-- ---------------------------------------------------------------------------------------

local function Num(value)
	return type(value) == "number" and value == value and value or nil
end

-- A stop from the saved file, with only the fields that belong in it; nil when it is no use.
local function CleanStop(raw)
	if type(raw) ~= "table" then
		return nil
	end
	local mapId, nx, ny = Num(raw.mapId), Num(raw.nx), Num(raw.ny)
	if not mapId or not nx or not ny or nx < 0 or nx > 1 or ny < 0 or ny > 1 then
		return nil
	end
	local stop = { mapId = floor(mapId), nx = nx, ny = ny }
	local ux, uy, us = Num(raw.ux), Num(raw.uy), Num(raw.us)
	if ux and uy and us and us > 0 then
		stop.ux, stop.uy, stop.us = ux, uy, us
	end
	return stop
end

function A:LoadRoute()
	local saved = type(self.sv.route) == "table" and self.sv.route or {}
	local route = { vias = {}, done = 0 }
	if type(saved.vias) == "table" then
		for _, raw in ipairs(saved.vias) do
			local stop = CleanStop(raw)
			if stop and #route.vias < A.MAX_STOPS then
				route.vias[#route.vias + 1] = stop
			end
		end
	end
	route.dest = CleanStop(saved.dest)
	route.destOwn = route.dest ~= nil and saved.destOwn == true or nil
	local done = Num(saved.done)
	route.done = done and done >= 0 and floor(done) or 0
	self.sv.route = route
	self.route = route
	self.removal = nil
	self:Compact()
end

-- A route with nothing in it starts counting from 1 again.
function A:Compact()
	local route = self.route
	if #route.vias == 0 and not route.dest then
		route.done = 0
	end
end

function A:RouteChanged()
	self:Compact()
	if self.OnRouteChanged then
		self:OnRouteChanged()
	end
end

-- ---------------------------------------------------------------------------------------
-- What the map tells us
-- ---------------------------------------------------------------------------------------

-- The same place, marked twice (the cursor did not move; or the game announcing a destination it kept from
-- before, on whichever map it happens to have open). On one map, a fiftieth of a percent of the map; on two
-- maps, the same fraction of the smaller one, found through the universal space.
local function SameStop(a, b)
	if a.mapId == b.mapId then
		return abs(a.nx - b.nx) < 2e-4 and abs(a.ny - b.ny) < 2e-4
	end
	if a.ux and b.ux then
		local tolerance = 2e-4 * math.min(a.us, b.us)
		return abs(a.ux - b.ux) < tolerance and abs(a.uy - b.uy) < tolerance
	end
	return false
end
A.SameStop = SameStop

-- A destination was set on the map. Returns "set" (nothing kept), "stop" (the old destination became a stop)
-- or "full" (it would have, but there are as many stops as there is room for).
function A:OnDestinationAdded(stop, now)
	local route = self.route
	local old = route.dest
	-- The game may take the old destination away a moment before it puts the new one down.
	if not old and self.removal and now - self.removal.at <= A.SETTLE_MS then
		old = self.removal.stop
	end
	self.removal = nil

	local result = "set"
	if old and self.sv.addMode and not SameStop(old, stop) then
		if #route.vias >= A.MAX_STOPS then
			result = "full"
		else
			route.vias[#route.vias + 1] = old
			result = "stop"
		end
	end
	route.dest = stop
	route.destOwn = nil -- the game holds this one
	self:RouteChanged()
	-- `changed`: the same place announced again (the game keeping its destination across a login) is nothing to tell the group
	return result, not (old and SameStop(old, stop))
end

-- The game announced that a destination is gone. `near`: the player is standing at it (the game takes the destination
-- away when you get there); `byHand`: a map screen of the game was up, which is the only place a destination is taken
-- off by hand. Nothing is decided yet: a new destination may be about to follow (see OnDestinationAdded), so the
-- verdict waits out A.SETTLE_MS in SettleRemoval.
function A:OnDestinationRemoved(now, near, byHand)
	local route = self.route
	if not route.dest then
		return false
	end
	self.removal = { stop = route.dest, at = now, near = near and true or false, byHand = byHand and true or false }
	route.dest = nil
	self:RouteChanged()
	return true
end

-- Called every tick (and so when the HUD comes back after the map). The removal that nothing followed is settled:
--   * the game still holds a destination: that removal was not this one (the old one going away after the new one was
--     put down, or an announcement that does not say which); the destination stays;
--   * the player was standing at it: the route is over (returns true);
--   * a map screen was up: it was taken off by hand; it goes, the stops stay;
--   * otherwise the game dropped it while the player was out walking, far from it (it forgets it when a zone loads, or
--     for a reason of its own). The add-on holds the place itself, so the guide keeps leading there: a destination
--     does not vanish from the screen just because the game's copy did.
function A:SettleRemoval(now)
	local removal = self.removal
	if not removal or now - removal.at <= A.SETTLE_MS then
		return false
	end
	self.removal = nil
	local route = self.route
	if route.dest then
		return false
	end
	if self:GameHasWaypoint() == true then
		route.dest = removal.stop
		self.destState = "kept (the game still holds a destination)"
		self:Trace("route", "a removal was announced but the game still holds a destination: the destination is kept")
		self:RouteChanged()
		return false
	end
	if removal.near then
		self:Trace("route", "the game took its destination away with you at it: route finished")
		self:Complete()
		return true
	end
	if removal.byHand then
		self:Trace("route", "the destination was taken off the map by hand: dropped, the stops stay")
		self:ShareRoute("the destination was taken off the map")
		return false
	end
	route.dest = removal.stop
	route.destOwn = true -- the game no longer holds it: the add-on draws its pin
	self.destState = "kept (the game dropped its own)"
	self:Trace("route", "the game dropped its destination while you walked, far from it: kept, the guide goes on")
	self:RouteChanged()
	return false
end

-- ---------------------------------------------------------------------------------------
-- Walking the route
-- ---------------------------------------------------------------------------------------

-- The stop to head for: stop, its number, how many there are, and whether it is the destination.
-- nil when there is nothing to walk to.
function A:Current()
	local route = self.route
	local count = #route.vias
	-- a removal that is still being settled is still the destination: no flicker while the game makes up its mind
	local dest = route.dest or (self.removal and self.removal.stop) or nil
	local total = route.done + count + (dest and 1 or 0)
	if count > 0 then
		return route.vias[1], route.done + 1, total, false
	end
	if dest then
		return dest, total, total, true
	end
	return nil
end

function A:HasRoute()
	return #self.route.vias > 0 or self.route.dest ~= nil
end

-- A route taken over from the group (Share.lua): { done, hasDest, points = { { mapId, nx, ny } ... } }. The game's own
-- destination is not touched, so the destination is this add-on's alone (`destOwn`): the map shows a numbered pin on it.
function A:ImportRoute(snapshot)
	local route = self.route
	route.vias = {}
	route.dest = nil
	local last = #snapshot.points
	for index, point in ipairs(snapshot.points) do
		local stop = self:NewStop(point.mapId, point.nx, point.ny)
		if snapshot.hasDest and index == last then
			route.dest = stop
		elseif #route.vias < A.MAX_STOPS then
			route.vias[#route.vias + 1] = stop
		end
	end
	route.done = snapshot.done or 0
	route.destOwn = route.dest ~= nil or nil
	self.removal = nil
	self.destState = route.dest and "taken over from the group" or nil
	self:RouteChanged()
end

-- The current stop was reached or is given up on. Returns "stop" (on to the next), "destination" (the
-- route is finished) or nil (nothing to do).
function A:Reach()
	local route = self.route
	if #route.vias > 0 then
		table.remove(route.vias, 1)
		route.done = route.done + 1
		self:Trace("route", string.format("stop %d reached", route.done))
		self:RouteChanged()
		return "stop"
	end
	if route.dest then
		self:Trace("route", "the destination was reached: the route is finished")
		self:Complete()
		return "destination"
	end
	return nil
end

-- The route is over. The game's own destination pin is not touched.
function A:Complete()
	local route = self.route
	route.vias = {}
	route.dest = nil
	route.destOwn = nil
	route.done = 0
	self.removal = nil
	self:RouteChanged()
end

function A:Clear()
	self:Complete()
end

-- Only the stops go: the destination (the game's own pin) stays, and is the one stop left. Returns how many
-- stops there were.
function A:ClearStops()
	local route = self.route
	local count = #route.vias
	route.vias = {}
	route.done = 0
	self:RouteChanged()
	return count
end

-- Takes out the stop numbered `number` (as the pins and the HUD number them). Returns false for a number
-- that is not a stop still to come; the destination is the game's and is not removed here.
function A:RemoveStop(number)
	local route = self.route
	local index = number and (number - route.done) or nil
	if not index or index < 1 or index > #route.vias or index ~= floor(index) then
		return false
	end
	table.remove(route.vias, index)
	self:RouteChanged()
	return true
end

function A:RemoveLastStop()
	local route = self.route
	if #route.vias == 0 then
		return false
	end
	table.remove(route.vias)
	self:RouteChanged()
	return true
end

-- { stop, number } for each stop still to come, in order, then the destination (number = total).
function A:Stops()
	local route = self.route
	local out = {}
	for index, stop in ipairs(route.vias) do
		out[#out + 1] = { stop = stop, number = route.done + index, destination = false }
	end
	if route.dest then
		local total = route.done + #route.vias + 1
		out[#out + 1] = { stop = route.dest, number = total, destination = true }
	end
	return out
end

A.loaded.Route = true
