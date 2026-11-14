-- Pressing L3 and R3 together on the map screen resets the waypoints: every stop, and the game's own destination.
--
-- On the gamepad map R3 is the game's "Set Destination" (it acts the moment it goes DOWN) and L3 opens its legend. So
-- this cannot take either press over; it can only listen. Both buttons do what they always do (a destination is put
-- down at the cursor, the legend toggles), and when the second of the two goes down within CHORD_MS of the first, the
-- reset follows RESET_DELAY_MS later: by then the game has finished with the two buttons, and the destination that R3
-- put down is cleared with the rest. The legend that L3 toggled is left for the player to close.
--
-- HOW THE BUTTONS ARE HEARD (the pattern PB's ScreenshotModeShortcut measured on a PS5 for L2 + D-pad Left, and that
-- the triangle long press of 0.3.x used here, which the player confirmed reaches this add-on on a PS5):
--   * Bindings.xml has an action layer with two actions that inherit their bindings from UI_SHORTCUT_LEFT_STICK and
--     UI_SHORTCUT_RIGHT_STICK, so they are on whatever the two stick clicks are bound to, and they report Down and Up
--     to this file;
--   * the layer is allowFallthrough="true" and every handler returns false: a press is NOT consumed, the game's own
--     handler gets it exactly as before;
--   * the layer is raised only while the gamepad map scene shows, by a ZO_ActionLayerFragment added to that scene (data
--     added to the scene's list; nothing of the client's is wrapped, replaced or called).
--
-- THE BUTTON GUIDE. One row is appended to the map's button guide at the bottom (data into a table the client reads,
-- found in KEYBIND_STRIP's list of groups): the L3 action as its keybind, so the strip draws the L3 icon beside the
-- text "+ R3: reset waypoints". The row has no function of its own: the press goes to the action's handler in
-- Bindings.xml, never through the strip. The client redraws the strip by itself when the map's cursor enters or leaves
-- the map, which is right after it opens.
--
-- WHAT THE RESET DOES. It asks the game to remove its destination (RemovePlayerWaypoint, asked about first like every
-- call, see Nav.lua) and clears the route. If the game will not, only the stops are cleared and the destination stays,
-- and the player is told. `/pbwp status` counts downs, ups and chords and says whether the guide row was added.
local A, S = PBS_WAYPOINT, PBS_WAYPOINT_STRINGS
local em = EVENT_MANAGER

local LAYER = "PBsWayPointMapLayer" -- named in Bindings.xml
local ACTION_L3 = "PBSWAYPOINT_MAP_L3" -- named in Bindings.xml
local MAP_SCENE = "gamepad_worldMap"
local STALE_MS = 3000 -- a press with no release for this long is forgotten (the release was lost)
local RESET_DELAY_MS = 350 -- from the chord to the reset: the game has dealt with the two buttons by then
local CONFIRM_MS = 600 -- how long the game has to announce that its destination is gone
local REDRAW_DELAYS = { 300, 700 } -- after the reset: the map is asked to redraw again this long after, and again this long after that
local MAP_ROW_KEYBIND = "UI_SHORTCUT_RIGHT_STICK" -- the map's own "Set Destination" row: how its descriptor is recognised
A.CHORD_MS = 600 -- the second button within this long of the first is "together"

A.chord = {
	ready = false, -- the fragment exists and the map scene was found
	added = false, -- the fragment is in the map scene
	why = "not set up yet",
	downs = { L3 = 0, R3 = 0 }, -- a button went down on the map screen
	ups = { L3 = 0, R3 = 0 }, -- ... and came back up
	fired = 0, -- chords that reset the waypoints
	shown = 0, -- the map scene finished showing (the layer was raised without an error)
	down = {}, -- button -> game time it went down, until its release (or until it is forgotten)
	spent = false, -- this chord has been acted on: it waits until both buttons are up
	lastGap = nil, -- ms between the two buttons of the last chord
	error = nil,
	redraws = 0, -- times the map was asked to redraw after a reset
	redrawWhy = "not asked yet",
	row = nil, -- the row in the button guide
	rowWhy = "not added yet",
	rowAdded = 0, -- times a row was put into the map's descriptor (once, unless the client rebuilds it)
}

local function Now()
	return GetGameTimeMilliseconds()
end

-- ---------------------------------------------------------------------------------------
-- Getting the layer onto the map scene
-- ---------------------------------------------------------------------------------------

function A:SetupChord()
	local chord = self.chord
	if chord.ready then
		return true
	end
	if self.sv.probe.chordLayer == "bad" then
		chord.why = "it failed on an earlier login (/pbwp retry forgets it)"
		return false
	end
	if not (SCENE_MANAGER and ZO_ActionLayerFragment) then
		chord.why = "the game has no scene manager or action layer fragment"
		return false
	end
	local scene = SCENE_MANAGER:GetScene(MAP_SCENE)
	if not scene then
		chord.why = "the map scene does not exist yet"
		return false
	end
	local ok, err = pcall(function()
		local fragment = ZO_ActionLayerFragment:New(LAYER)
		-- the registrations go beside the client's own; none of theirs is touched
		fragment:RegisterCallback("StateChange", function(_, state)
			if state == SCENE_FRAGMENT_HIDDEN then
				self:CancelChord()
			end
		end)
		scene:RegisterCallback("StateChange", function(_, state)
			self:OnMapState(state)
		end)
		chord.fragment, chord.scene = fragment, scene
	end)
	if not ok then
		chord.why = "setting up failed: " .. tostring(err)
		chord.error = tostring(err)
		return false
	end
	chord.ready = true
	chord.why = "set up"
	return true
end

-- The window in which the layer is being raised: if the game shows its UI error there and the player reloads,
-- the file still says so, and next login the layer is not added (see Sanitize in Core.lua).
function A:OnMapState(state)
	local chord = self.chord
	if state == SCENE_SHOWING then
		if chord.added and self.sv.probe.chordLayer ~= "ok" then
			self.sv.pendingChord = true
		end
		self:EnsureGuideRow()
	elseif state == SCENE_SHOWN then
		chord.shown = chord.shown + 1
		if self.sv.pendingChord then
			self.sv.pendingChord = nil
			self.sv.probe.chordLayer = "ok"
		end
		self:EnsureGuideRow()
	elseif state == SCENE_HIDING or state == SCENE_HIDDEN then
		self:CancelChord()
	end
end

-- Puts the layer on the map scene or takes it off, to match the setting.
function A:ApplyChordSetting()
	local chord = self.chord
	if not self.sv.resetChord then
		if chord.added then
			local ok, err = pcall(function()
				chord.scene:RemoveFragment(chord.fragment)
			end)
			if not ok then
				chord.error = tostring(err)
			end
			chord.added = false
			chord.why = "switched off"
		end
		self:CancelChord()
		return
	end
	if not self:SetupChord() then
		return
	end
	if chord.added then
		return
	end
	local ok, err = pcall(function()
		chord.scene:AddFragment(chord.fragment)
	end)
	if ok then
		chord.added = true
		chord.why = "on the map scene"
	else
		chord.error = tostring(err)
		chord.why = "adding it to the map scene failed: " .. tostring(err)
	end
end

-- ---------------------------------------------------------------------------------------
-- The button guide
-- ---------------------------------------------------------------------------------------

local function IsMapDescriptor(descriptor)
	if type(descriptor) ~= "table" then
		return false
	end
	for _, row in ipairs(descriptor) do
		if type(row) == "table" and row.keybind == MAP_ROW_KEYBIND then
			return true
		end
	end
	return false
end

local function HasRow(descriptor, row)
	for _, candidate in ipairs(descriptor) do
		if candidate == row then
			return true
		end
	end
	return false
end

-- Appends the guide row to the map's button guide once; called whenever the map is showing. The row is data in the
-- descriptor the client already holds; it is not drawn by this add-on.
function A:EnsureGuideRow()
	local chord = self.chord
	if not chord.added then
		return
	end
	local groups = KEYBIND_STRIP and KEYBIND_STRIP.keybindGroups
	if type(groups) ~= "table" then
		chord.rowWhy = "the game's button guide has no list of groups"
		return
	end
	if not chord.row then
		chord.row = {
			name = function()
				return S.mapHint
			end,
			keybind = ACTION_L3,
			-- the row has no function of its own: the press goes to the action in Bindings.xml
			callback = function() end,
			enabled = true,
			visible = function()
				return self.sv ~= nil and self.sv.resetChord == true
			end,
		}
	end
	local ok, err = pcall(function()
		for descriptor in pairs(groups) do
			if IsMapDescriptor(descriptor) then
				if not HasRow(descriptor, chord.row) then
					descriptor[#descriptor + 1] = chord.row
					chord.rowAdded = chord.rowAdded + 1
				end
				chord.rowWhy = "in the map's button guide"
				return
			end
		end
		chord.rowWhy = "the map's button guide was not found among the game's groups"
	end)
	if not ok then
		chord.rowWhy = "adding it failed: " .. tostring(err)
		chord.error = tostring(err)
	end
end

-- ---------------------------------------------------------------------------------------
-- The buttons
-- ---------------------------------------------------------------------------------------

function A:CancelChord()
	self.chord.down = {}
	self.chord.spent = false
	em:UnregisterForUpdate(self.name .. "Chord")
end

-- Called from Bindings.xml with "L3" or "R3". Returns false: a press is never consumed.
function A:OnChordDown(which)
	local chord = self.chord
	if not chord.downs[which] then
		return false
	end
	chord.downs[which] = chord.downs[which] + 1
	if not (self.sv and self.sv.resetChord) then
		return false
	end
	local now = Now()
	-- a press whose release was lost is forgotten
	for key, at in pairs(chord.down) do
		if now - at >= STALE_MS then
			chord.down[key] = nil
		end
	end
	if chord.down[which] then
		return false -- the same button going down again while it is held
	end
	chord.down[which] = now
	local first = chord.down[which == "L3" and "R3" or "L3"]
	if first and not chord.spent then
		chord.lastGap = now - first
		if chord.lastGap <= A.CHORD_MS then
			chord.spent = true -- once per chord: both buttons must come up before the next one counts
			chord.fired = chord.fired + 1
			em:UnregisterForUpdate(self.name .. "Chord")
			em:RegisterForUpdate(self.name .. "Chord", RESET_DELAY_MS, function()
				self:OnChordElapsed()
			end)
		end
	end
	return false
end

function A:OnChordUp(which)
	local chord = self.chord
	if not chord.ups[which] then
		return false
	end
	chord.ups[which] = chord.ups[which] + 1
	chord.down[which] = nil
	if next(chord.down) == nil then
		chord.spent = false
	end
	return false
end

-- The two buttons went down together a moment ago.
function A:OnChordElapsed()
	em:UnregisterForUpdate(self.name .. "Chord")
	local chord = self.chord
	-- the map must still be up: a chord that outlived its screen is not ours
	if not (chord.scene and chord.scene:IsShowing()) then
		return
	end
	self:ResetWaypoints()
end

-- ---------------------------------------------------------------------------------------
-- Redrawing the map after a reset
--
-- The route is cleared at once, but what the map SHOWS is drawn by pin objects that are only rebuilt when something
-- asks: our numbered pins (RefreshPins, Pins.lua) and the game's own destination pin, which the client redraws from
-- the game's destination when its ping pins are rebuilt (WORLD_MAP_MANAGER:RefreshMapPings(), which the client itself
-- calls after it changes a ping without a map change). The announcement that the destination is gone (EVENT_MAP_PING)
-- may be late or not drawn while a panel is over the map, so the map is asked again a moment later, twice.
-- RefreshMapPings reads the open map's pings, so, like the other reads of the open map, it is asked only when that
-- map is a zone or a sub-zone.
-- ---------------------------------------------------------------------------------------

function A:RedrawMap()
	local chord = self.chord
	chord.redraws = chord.redraws + 1
	self:RefreshPins()
	local manager = WORLD_MAP_MANAGER
	if not manager or type(manager.RefreshMapPings) ~= "function" then
		chord.redrawWhy = "our pins only: the world map has no RefreshMapPings"
		return
	end
	local gate, why = self:MapTypeGate()
	if not gate then
		chord.redrawWhy = "our pins only: " .. tostring(why)
		return
	end
	local ok, err = pcall(manager.RefreshMapPings, manager)
	if not ok then
		chord.redrawWhy = "RefreshMapPings failed: " .. tostring(err)
		chord.error = tostring(err)
		return
	end
	-- the client does this too when it takes its destination away: the map's button guide was told the cursor was on
	-- the pin, and must be told it no longer is
	if type(manager.DoMouseExitForPinType) == "function" and MAP_PIN_TYPE_PLAYER_WAYPOINT then
		pcall(manager.DoMouseExitForPinType, manager, MAP_PIN_TYPE_PLAYER_WAYPOINT)
	end
	chord.redrawWhy = "asked the world map to rebuild its pings"
end

-- Now, and again a moment later and later still.
function A:ScheduleRedraw()
	self:RedrawMap()
	em:UnregisterForUpdate(self.name .. "Redraw")
	local step = 0
	local function arm()
		step = step + 1
		if not REDRAW_DELAYS[step] then
			return
		end
		em:RegisterForUpdate(self.name .. "Redraw", REDRAW_DELAYS[step], function()
			em:UnregisterForUpdate(self.name .. "Redraw")
			self:RedrawMap()
			arm()
		end)
	end
	arm()
end

-- ---------------------------------------------------------------------------------------
-- The reset
-- ---------------------------------------------------------------------------------------

function A:ResetWaypoints()
	local stops = #self.route.vias
	local hadDestination = self.route.dest ~= nil
	local now = Now()

	-- The game's destination first. A call that returns without an error is not proof that it worked, so the game's
	-- announcement that the destination is gone (EVENT_MAP_PING, see HandlePing) is waited for, a moment.
	self:Call("RemovePlayerWaypoint")
	local state = self.fnState.RemovePlayerWaypoint
	local removed = state ~= nil and state.usable and state.proven
	if removed then
		self:Complete()
	else
		self:ClearStops()
	end
	self:Trace("route", string.format("L3 + R3 on the map: %d stops %s", stops, removed and "and the destination cleared" or "cleared; the game would not remove its destination"))
	self:ShareRoute("the waypoints were reset")

	if self.sv.sound and self.Play then
		self.Play("MAP_PING_REMOVE")
	end
	-- what the map shows is redrawn now and a moment later (see above)
	self:ScheduleRedraw()
	if removed then
		self:Print(stops > 0 and S.waypointsReset or S.waypointsResetNoStops, stops)
		self.resetCheck = { at = now, hadDestination = hadDestination }
		em:UnregisterForUpdate(self.name .. "ResetCheck")
		em:RegisterForUpdate(self.name .. "ResetCheck", CONFIRM_MS, function()
			em:UnregisterForUpdate(self.name .. "ResetCheck")
			local check = self.resetCheck
			self.resetCheck = nil
			-- The game's announcement, or failing that the game's own answer to "do you still hold a destination?":
			-- only a destination that is really still there is reported.
			if check and check.hadDestination and not (self.lastRemovedAt and self.lastRemovedAt >= check.at)
				and self:GameHasWaypoint() ~= false then
				self:Print(S.destinationStays)
			end
		end)
	elseif stops > 0 then
		self:Print(S.stopsClearedOnly, stops)
	else
		self:Print(S.nothingToReset)
	end
end

A.loaded.Chord = true
