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
	raised = {}, -- window name -> { control, tier, layer, level (what the game had), done }: see RaiseWheel
	raiseWrites = 0, -- times the draw order was written
	raiseWhy = nil, -- what was refused or missing, for /pbpme status
}

-- WHERE THE WHEEL IS DRAWN. The client's wheel is a top-level window of its own (targetmarkerwheel_gamepad.xml /
-- targetmarkerwheel_keyboard.xml) with no draw order set, so it sits where the HUD's other windows do and a window made
-- after it (the buff icons) is drawn over it: with the long list of extra markers the wheel's lower edge was partly
-- hidden behind them (the player's report). The window is raised to the high tier, overlay layer and a level above the
-- keybind strips, and put back when the add-on is switched off. Only the window's draw order is written: no anchor, no
-- parent, no handler (SetDrawTier / SetDrawLayer / SetDrawLevel are marked `protected-attributes` in the API dump; PB's
-- ChatWindowCustomizer writes the draw order of the client's chat window the same way, under pcall; a refusal is kept
-- in `raiseWhy` and /pbpme status prints it). NOT MEASURED ON A PS5 that the write is accepted for this window.
local WHEEL_WINDOWS = { "ZO_TargetMarkerWheel_Gamepad_TopLevel", "ZO_TargetMarkerWheel_Keyboard_TopLevel" }
local WHEEL_LEVEL = 120 -- the client's own high-tier windows: keybind strips 90-120, tooltips 140, alert text 145

local function Reading(control, method)
	local fn = control[method]
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, control)
	return ok and value or nil
end

-- Writes the wheel's draw order (only where it is not already so); `restore`: puts back what the game had.
function A:RaiseWheel(restore)
	local w = self.wheel
	if not restore and not (self.sv and self.sv.enabled) then
		return false -- switched off: the game's own wheel stays exactly as the game has it
	end
	local wantLayer, wantTier = DL_OVERLAY, DT_HIGH
	if wantLayer == nil or wantTier == nil then
		w.raiseWhy = "DL_OVERLAY / DT_HIGH do not exist"
		return false
	end
	local touched = false
	for _, name in ipairs(WHEEL_WINDOWS) do
		local control = _G[name]
		if control ~= nil and type(control.SetDrawTier) == "function" then
			local entry = w.raised[name]
			if entry and entry.control ~= control then
				entry = nil -- the game made the window again
			end
			if not entry then
				entry = {
					control = control, done = false,
					tier = Reading(control, "GetDrawTier"), layer = Reading(control, "GetDrawLayer"), level = Reading(control, "GetDrawLevel"),
				}
				w.raised[name] = entry
			end
			local layer, tier, level
			if restore then
				layer, tier, level = entry.layer, entry.tier, entry.level
			else
				layer, tier, level = wantLayer, wantTier, WHEEL_LEVEL
			end
			if restore and not entry.done then
				layer, tier, level = nil, nil, nil
			end
			if layer ~= nil and (Reading(control, "GetDrawLayer") ~= layer or Reading(control, "GetDrawTier") ~= tier
				or Reading(control, "GetDrawLevel") ~= level) then
				local ok1, err1 = pcall(control.SetDrawLayer, control, layer)
				local ok2, err2 = pcall(control.SetDrawTier, control, tier)
				local ok3, err3 = pcall(control.SetDrawLevel, control, level)
				w.raiseWrites = w.raiseWrites + 1
				touched = true
				if ok1 and ok2 and ok3 then
					entry.done = not restore
					w.raiseWhy = nil
				else
					w.raiseWhy = name .. ": " .. tostring(ok1 and (ok2 and err3 or err2) or err1)
					self:Trace("wheel", "the draw order of the wheel was refused: " .. w.raiseWhy)
				end
			elseif not restore and layer ~= nil then
				entry.done = true
			end
		end
	end
	return touched
end

-- A line for /pbpme status.
function A:WheelRaiseText()
	local w = self.wheel
	local names, count = {}, 0
	for name, entry in pairs(w.raised) do
		count = count + 1
		names[#names + 1] = name:gsub("^ZO_TargetMarkerWheel_", ""):gsub("_TopLevel$", "") .. (entry.done and " raised" or " NOT raised")
	end
	table.sort(names)
	if count == 0 then
		return "the game's wheel window was not found (the draw order is not touched)"
	end
	return table.concat(names, ", ") .. " (written " .. w.raiseWrites .. " times)" .. (w.raiseWhy and ("; refused: " .. w.raiseWhy) or "")
end

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
		-- the wheel is about to be shown: its window goes in front of the HUD (a no-op once it is)
		local okRaise, errRaise = pcall(self.RaiseWheel, self)
		if not okRaise then
			w.raiseWhy = tostring(errRaise)
		end
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
	-- A native selection supersedes any delayed clear from the previous selection.
	self.engineCheck = nil
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
