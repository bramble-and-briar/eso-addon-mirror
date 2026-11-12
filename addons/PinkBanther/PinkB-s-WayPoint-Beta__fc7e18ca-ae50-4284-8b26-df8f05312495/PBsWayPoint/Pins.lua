-- The stops as numbered pins on the world map (and so on PB's MiniMap, which draws the same map).
--
-- A custom pin type is registered with the world map's pin manager the way LibMapPins does it: the manager
-- keeps our function beside its own and calls it whenever it rebuilds the pins of the map on show; this
-- file never wraps or replaces anything of the client's. The function needs no call into the game that
-- depends on the map: it asks which map is open by id (GetCurrentMapId) and turns each stop's
-- universal position into that map's own (A:StopOnMap in Nav.lua), so the pins also show on a map the
-- stop was not marked on (a zone map, then the Tamriel map), and a stop that is not inside the open map
-- gets no pin.
--
-- The destination is the game's own pin and is not drawn again, unless the game does not hold it (the route took it over
-- from the group, or the game dropped its own): then it gets a numbered pin like the stops (`route.destOwn`).
local A = PBS_WAYPOINT

local PIN_TYPE = "PBSWAYPOINT_PIN_STOP"
local PATH = "PBsWayPoint/assets/"

A.pin = {
	registered = false,
	enabled = false,
	typeId = nil,
	why = "not registered yet",
	refreshes = 0,
	created = 0, -- pins made on the last rebuild
	errors = 0,
	lastError = nil,
}

local function PinTexture(pin)
	local _, number = pin:GetPinTypeAndTag()
	number = math.max(1, math.min(A.MAX_STOPS, tonumber(number) or 1))
	return string.format("%spin%02d.dds", PATH, number)
end
A.PinTexture = PinTexture

-- Called by the pin manager: `manager` is the pin manager itself.
local function AddPins(manager)
	local pin = A.pin
	pin.created = 0
	if not A.sv or not A.sv.pins or not A.route then
		return
	end
	local mapId = A:Call("GetCurrentMapId")
	if type(mapId) ~= "number" then
		return
	end
	for _, item in ipairs(A:Stops()) do
		if not item.destination or A.route.destOwn then
			local nx, ny = A:StopOnMap(item.stop, mapId)
			if nx then
				manager:CreatePin(pin.typeId, item.number, nx, ny)
				pin.created = pin.created + 1
			end
		end
	end
end
A.AddPins = AddPins

-- Above the game's own destination pin (160) would hide it; just below it.
local LAYOUT = {
	level = 150,
	size = 40,
	minSize = 32,
	texture = PinTexture,
}

local function Manager()
	if type(ZO_WorldMap_GetPinManager) ~= "function" then
		return nil
	end
	return ZO_WorldMap_GetPinManager()
end

-- True once the pin type is known to the pin manager. The manager may not exist yet when this add-on
-- loads, so Main.lua asks again at EVENT_PLAYER_ACTIVATED.
function A:RegisterPins()
	local pin = self.pin
	if pin.registered then
		return true
	end
	local manager = Manager()
	if not manager or type(manager.AddCustomPin) ~= "function" then
		pin.why = "the world map has no pin manager yet"
		return false
	end
	local ok, err = pcall(manager.AddCustomPin, manager, PIN_TYPE, AddPins, nil, LAYOUT, nil)
	if not ok then
		pin.why = "registering failed: " .. tostring(err)
		pin.lastError = tostring(err)
		pin.errors = pin.errors + 1
		return false
	end
	-- the manager writes the new type's number into _G[PIN_TYPE]
	pin.typeId = _G[PIN_TYPE]
	if type(pin.typeId) ~= "number" then
		pin.why = "the pin manager gave no type number"
		return false
	end
	pin.registered = true
	pin.why = "registered"
	self:ApplyPinSetting()
	return true
end

-- Switches the pin type on or off to match the setting, and rebuilds the pins.
function A:ApplyPinSetting()
	local pin = self.pin
	if not pin.registered then
		return
	end
	local manager = Manager()
	if not manager then
		return
	end
	local want = self.sv.pins and true or false
	local ok, err = pcall(manager.SetCustomPinEnabled, manager, pin.typeId, want)
	if ok then
		pin.enabled = want
	else
		pin.errors = pin.errors + 1
		pin.lastError = tostring(err)
	end
	self:RefreshPins()
end

-- Rebuilds the stop pins after the route changed.
function A:RefreshPins()
	local pin = self.pin
	if not pin.registered then
		return
	end
	local manager = Manager()
	if not manager then
		return
	end
	local ok, err = pcall(manager.RefreshCustomPins, manager, pin.typeId)
	pin.refreshes = pin.refreshes + 1
	if not ok then
		pin.errors = pin.errors + 1
		pin.lastError = tostring(err)
	end
end

A.loaded.Pins = true
