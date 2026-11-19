-- The marker wheel: the game's eight, then a "clear" entry, then the extras.
--
-- HOW THE CLIENT BUILDS THE WHEEL (esoui/ingame/targetmarker/targetmarkerwheel_shared.lua, read, not measured):
--
--     function ZO_TargetMarkerWheel_Shared:PopulateMenu()
--         for iconIndex, iconPath in ipairs(ZO_GetPlatformTargetMarkerIconTable()) do
--             self.menu:AddEntry("", iconPath, iconPath, function() AssignTargetMarkerToReticleTarget(iconIndex) end, iconIndex)
--         end
--     end
--
-- The list is asked for every time the wheel opens, the entries are spread round the circle by how many there are, and
-- the entry picked calls the global AssignTargetMarkerToReticleTarget with its POSITION in the list. So two globals are
-- replaced and nothing else is touched:
--
--   * ZO_GetPlatformTargetMarkerIconTable returns the game's list (a pure getter: it creates no closures) with entries
--     added after the eight. Positions 1-8 are the game's own markers, so they mean what they always meant.
--   * AssignTargetMarkerToReticleTarget answers positions beyond eight itself (they are not engine markers: the engine
--     would refuse them) and passes 1-8 and everything else straight to the game's own function.
--
-- WHY THIS IS SAFE TO DO (PB's note "ESO add-on code is insecure": a client closure created while an add-on frame is on the
-- stack is untrusted for good): the client's callbacks are created in PopulateMenu AFTER our getter has returned, so no
-- add-on frame is on the stack when they are born. The wrapper is called FROM the client's trusted closure and only calls
-- a game function that the API says is neither private nor protected (asked first, see InstallWheel); it calls no client
-- UI code, only plain game calls and this add-on's own tables. If the game's call is ever refused or the list has not got
-- eight entries, the wheel is left as the game builds it.
--
-- NOT MEASURED ON A PS5: that the wheel accepts a list of sixteen entries and spreads them evenly; that the entries'
-- textures (this add-on's DDS files) show; that the pick reaches the wrapper. `/pbpme status` counts each step.
local A, S = PBS_PME, PBS_PME_STRINGS

A.wheel = {
	installed = false,
	why = "not installed yet",
	opened = 0, -- times the game asked for the list while this add-on's list was in use
	picked = 0, -- extra entries picked
	passed = 0, -- the game's own eight, passed on
	errors = 0,
	lastError = nil,
	lastSize = nil, -- how many entries the list given out last had
	layout = nil, -- position -> icon number (0 = clear) for the list given out last
	limited = false, -- the list was cut to ten entries (the client's toggleable wheels are on)
	originalList = nil,
	originalAssign = nil,
}

function A:BuildWheelList(base)
	local std = A.STANDARD
	if #base ~= std then
		return nil, "the game's list has " .. #base .. " entries, not " .. std
	end
	local list, layout = {}, {}
	for i = 1, std do
		list[i] = base[i]
	end
	list[std + 1] = A.CLEAR_PATH
	layout[std + 1] = 0
	-- With the accessibility setting "toggleable wheels" on, the client puts a hotkey label on every entry, and it has
	-- ACCESSIBLE_WHEEL_HOTKEY_SLOT_1 .. 10 only (zo_radialmenu.lua asserts the ordinal is at most 10): the wheel then stops at ten.
	local limit = math.huge
	if type(ZO_AreTogglableWheelsEnabled) == "function" then
		local okAsk, on = pcall(ZO_AreTogglableWheelsEnabled)
		if okAsk and on then
			limit = A.WHEEL_HOTKEY_LIMIT
		end
	end
	self.wheel.limited = limit ~= math.huge
	for n = 1, self.sv.wheelSlots do
		local id = self.sv["slot" .. n]
		if #list < limit and A.IsIcon(id) then
			local position = #list + 1
			list[position] = A.IconPath(id)
			layout[position] = id
		end
	end
	return list, layout
end

-- What the client's ZO_GetPlatformTargetMarkerIconTable is replaced by.
function A:WheelList(original, ...)
	local base = original(...)
	local w = self.wheel
	local sv = self.sv
	if not (sv and sv.enabled) or type(base) ~= "table" then
		w.layout = nil
		return base
	end
	local ok, list, layout = pcall(self.BuildWheelList, self, base)
	if ok and list then
		w.layout = layout
		w.lastSize = #list
		w.opened = w.opened + 1
		return list
	end
	w.errors = w.errors + 1
	w.lastError = tostring(ok and layout or list)
	w.layout = nil
	self:Trace("wheel", "the list was left as the game builds it: " .. w.lastError)
	return base
end

function A:WheelPick(id)
	if id == 0 then
		return self:ClearReticle()
	end
	return self:PlaceExtended(id)
end

-- What the client's AssignTargetMarkerToReticleTarget is replaced by.
function A:WheelAssign(marker, ...)
	local w = self.wheel
	local sv = self.sv
	local layout = w.layout
	if type(marker) == "number" and sv and sv.enabled and layout and layout[marker] ~= nil then
		w.picked = w.picked + 1
		local ok, err = pcall(self.WheelPick, self, layout[marker])
		if not ok then
			w.errors = w.errors + 1
			w.lastError = tostring(err)
			self.diag.lastError = w.lastError
		end
		return
	end
	if type(marker) == "number" and marker >= 1 and marker <= A.STANDARD and sv and sv.enabled then
		w.passed = w.passed + 1
		local ok, err = pcall(self.OnStandardAssign, self)
		if not ok then
			w.errors = w.errors + 1
			w.lastError = tostring(err)
		end
	end
	return w.originalAssign(marker, ...)
end

-- Called at start-up (and again at the first PLAYER_ACTIVATED if it did not work the first time).
function A:InstallWheel()
	local w = self.wheel
	if w.installed then
		return true
	end
	if type(ZO_GetPlatformTargetMarkerIconTable) ~= "function" then
		w.why = "the client's marker list function does not exist"
		return false
	end
	if type(AssignTargetMarkerToReticleTarget) ~= "function" then
		w.why = "AssignTargetMarkerToReticleTarget does not exist"
		return false
	end
	-- asked before it is wrapped: a private or protected function must not be called from here
	local state = self:Judge("AssignTargetMarkerToReticleTarget")
	if not state.usable then
		w.why = "AssignTargetMarkerToReticleTarget: " .. tostring(state.why)
		return false
	end
	local okList, base = pcall(ZO_GetPlatformTargetMarkerIconTable)
	if not okList or type(base) ~= "table" or #base ~= A.STANDARD then
		w.why = "the client's marker list does not have " .. A.STANDARD .. " entries"
		return false
	end

	local originalList = ZO_GetPlatformTargetMarkerIconTable
	local originalAssign = AssignTargetMarkerToReticleTarget
	w.originalList, w.originalAssign = originalList, originalAssign
	self.native.AssignTargetMarkerToReticleTarget = originalAssign
	ZO_GetPlatformTargetMarkerIconTable = function(...)
		return A:WheelList(originalList, ...)
	end
	AssignTargetMarkerToReticleTarget = function(marker, ...)
		return A:WheelAssign(marker, ...)
	end
	w.installed = true
	w.why = "installed"
	return true
end

A.MARK("Wheel")
