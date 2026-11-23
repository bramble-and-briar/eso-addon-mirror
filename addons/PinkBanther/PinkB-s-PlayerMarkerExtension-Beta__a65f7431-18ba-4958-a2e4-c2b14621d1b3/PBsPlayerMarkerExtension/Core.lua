-- PB's PlayerMarkerExtension
-- Author: PinkBanther
--
-- The game's target marker (hold D-pad right, pick one) has EIGHT types, fixed in the engine: the marker's picture is
-- drawn by the engine over the unit's head and an add-on can neither add a type nor change a picture. So the extra
-- markers are this add-on's own: it draws them over the heads of the people in your group (a group member's position
-- is always readable), and tells the group which marker is on whom over LibGroupBroadcast, protocol 466, so that
-- everybody who runs this add-on sees the same markers.
--
-- WHAT IT DOES NOT DO: put an extra marker on an enemy or on somebody outside the group. The add-on can only draw
-- over a unit whose position it can read, and for those only the unit under the reticle is readable, and only while
-- it is under the reticle. For them the game's eight markers stay as they are.
--
-- HOW YOU PICK ONE: the marker wheel is built by the client from the list `ZO_GetPlatformTargetMarkerIconTable()`
-- returns and calls `AssignTargetMarkerToReticleTarget(position)` for the position picked (client source:
-- esoui/ingame/targetmarker/targetmarkerwheel_shared.lua). Wheel.lua gives the wheel a longer list (the game's eight,
-- then a "clear" entry, then the extras) and answers the positions beyond eight itself. Nothing else of the client's is
-- touched, and the game's own eight pass straight through.

PBS_PME = PBS_PME or {}
local A = PBS_PME
local S = PBS_PME_STRINGS

A.baseTitle = "PB’s PlayerMarkerExtension"
A.chatName = "PB’s PlayerMarkerExtension"
A.author = "PinkBanther"
A.version = "0.4.8"

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

A.ICON_COUNT = 35 -- assets/icon01.dds .. icon35.dds (25-30 are six rangers, added in 0.3.0; 31-35 five more, added in 0.4.0); the number is what goes over the wire, so it is never renumbered
A.MAX_SLOTS = 35 -- extras on the wheel: every picture can sit on it; with the eight and the clear entry that is 44 entries
-- (on the 500 px circle the entries' frames touch from 28 entries on, the pictures themselves from 33: see scripts/preview.py)
A.STANDARD = 8 -- the game's own markers
A.WHEEL_HOTKEY_LIMIT = 10 -- entries the client has hotkeys for when its toggleable wheels are on

A.defaults = {
	enabled = true,
	wheelSlots = 7, -- how many (the wheel then has 8 + 1 + 7 = 16 entries)
	slot1 = 9, -- shield
	slot2 = 8, -- drop
	slot3 = 10, -- sword
	slot4 = 3, -- arrow
	slot5 = 4, -- exclamation
	slot6 = 12, -- cross
	slot7 = 13, -- check
	slot8 = 1, -- heart
	slot9 = 15, -- crown
	slot10 = 6, -- lightning
	slot11 = 16, -- eye
	slot12 = 2, -- the pictures not used above, in order, so that a wheel of all 24 has each of them once
	slot13 = 5,
	slot14 = 7,
	slot15 = 11,
	slot16 = 14,
	slot17 = 17,
	slot18 = 18,
	slot19 = 19,
	slot20 = 20,
	slot21 = 21,
	slot22 = 22,
	slot23 = 23,
	slot24 = 24,
	slot25 = 25, -- the six rangers (red, blue, yellow, green, pink, black), after everything else
	slot26 = 26,
	slot27 = 27,
	slot28 = 28,
	slot29 = 29,
	slot30 = 30,
	slot31 = 31, -- navy, purple, white, orange, silver
	slot32 = 32,
	slot33 = 33,
	slot34 = 34,
	slot35 = 35,
	shareSend = true, -- the markers you put on are sent to the group (see Share.lua)
	shareReceive = true, -- ... and the group's are shown
	markSelf = true, -- picking an extra marker with nothing under the reticle puts it on yourself
	showSelf = true, -- a marker over your own head (you do not see it in the first person)
	frameMarks = true, -- the extra marker also in the group frames (the names at the top left), where the game shows its own markers (see Frames.lua)
	compassMarks = true, -- the extra marker also on the compass bar at the top of the screen, as the game shows its own (see Compass.lua)
	compassFov = 108, -- degrees the compass bar covers (CustomCompassPins' value, 0.6 pi; change it only if a marker sits off from the game's own)
	compassSize = 100, -- percent
	throughWalls = true,
	size = 100, -- percent
	height = 300, -- centimetres above the feet to the marker's LOWER edge (0.3.0; it was 260 to the centre, which overlapped the nameplate)
	heightPerMetre = 4, -- centimetres more for each metre of distance (the nameplate stands taller in the world the farther it is)
	facingOffset = 0, -- degrees added to the camera heading the pictures are turned to (a picture that shows reversed: 180)
	opacity = 100, -- percent
	sound = true,
	chat = false, -- messages in the chat box: off since 0.2.0 (a typed command always gets its answer; /pbpme status shows what was left unsaid)
}

local RANGES = {
	wheelSlots = { 0, A.MAX_SLOTS },
	size = { 40, 250 },
	height = { 100, 450 },
	heightPerMetre = { 0, 20 },
	facingOffset = { -180, 180 },
	opacity = { 20, 100 },
	compassFov = { 60, 180 },
	compassSize = { 50, 200 },
}
for n = 1, A.MAX_SLOTS do
	RANGES["slot" .. n] = { 1, A.ICON_COUNT }
end
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
	-- ZO_SavedVars writes the defaults INTO the saved file, so a default that is changed later never reaches a player who
	-- has already run the add-on (see the note "ZO_SavedVars defaults persist"). The key is not in the defaults on purpose:
	-- nil = a file from before this existed. Each step runs once:
	--   2: "show a marker on myself" was off by default at first and is on now;
	--   3 (0.2.0): the add-on no longer talks in the chat box unless asked (the player's request);
	--   4 (0.3.0): the height now means the marker's lower edge (was its centre): the old default 260 becomes the new one;
	--   5 (0.3.0): "add the extras to the wheel" was merged into "extended markers" (the one switch). An old "off" there meant
	--      no extras on the wheel while the group's markers were still shown: that is kept as 0 extras on the wheel.
	local version = sv.settingsVersion or 0
	if version < 2 then
		sv.showSelf = true
	end
	if version < 3 then
		sv.chat = false
	end
	if version < 4 and sv.height == 260 then
		sv.height = self.defaults.height
	end
	if version < 5 then
		if sv.wheel == false then
			sv.wheelSlots = 0
		end
		sv.wheel = nil
	end
	sv.settingsVersion = 5
	if type(sv.probe) ~= "table" then
		sv.probe = {}
	end
	-- A call that was started and never finished: the client showed its UI error and the player reloaded. That call is
	-- not made again (see Judge/Call below).
	if type(sv.pending) == "string" then
		sv.probe[sv.pending] = "bad"
		self.lastCrash = sv.pending
		sv.pending = nil
	end
	-- what happened last session, kept across a reload so that a disappearance can be read afterwards (/pbpme why)
	local earlier = {}
	if type(sv.trace) == "table" then
		for _, line in ipairs(sv.trace) do
			if type(line) == "string" and #earlier < A.TRACE_MAX then
				earlier[#earlier + 1] = line:sub(1, 240)
			end
		end
	end
	self.earlierTrace = earlier
	sv.trace = {}
	self.traceLog = {}
end

function A:Set(key, value)
	if self.defaults[key] == nil then
		return
	end
	self.sv[key] = self:Validate(key, value, self.defaults[key])
	if self.OnSettingChanged then
		self:OnSettingChanged(key)
	end
end

function A:Reset()
	for key, value in pairs(self.defaults) do
		self.sv[key] = value
	end
	if self.OnSettingChanged then
		self:OnSettingChanged(nil)
	end
end

-- ---------------------------------------------------------------------------------------
-- Output
-- ---------------------------------------------------------------------------------------

local PREFIX = "|cFF69B4" .. A.chatName .. "|r: "

-- A message printed at EVENT_ADD_ON_LOADED is thrown away because chat is not up yet. The add-on's own messages go to the
-- chat box when the "messages in the chat" setting is on, or while a typed command is being answered (`speaking`): the
-- player asked, so the answer is shown. `status`, `why` and the help are printed with Say, which is never silenced.
function A:Print(text, ...)
	if not (self.speaking or (self.sv and self.sv.chat)) then
		return
	end
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, text, ...)
		A.Say(PREFIX .. (ok and formatted or text))
	else
		A.Say(PREFIX .. text)
	end
end

-- PlaySound(SOUNDS.NAME) looked up guarded is the form that is proven on a PS5 (an unknown name is silence).
function A:Sound(name)
	if not (self.sv and self.sv.sound) then
		return
	end
	local id = SOUNDS and SOUNDS[name]
	if id and PlaySound then
		PlaySound(id)
	end
end

function A.Stamp()
	return GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
end

-- ---------------------------------------------------------------------------------------
-- The trace: what happened to the markers
--
-- Every change that matters (a marker put on or taken off, one that came in or ran out, the wheel being opened, sharing
-- failing) leaves one line. Nothing is printed; `/pbpme why` lists the lines (and the ones the last session left).
-- ---------------------------------------------------------------------------------------

A.TRACE_MAX = 40 -- (24 until 0.4.2, which traces more: the drawing verdicts, zone ids, the 3D window, who is online)

function A.TraceText(item)
	return string.format("%.1fs %s: %s%s", item.at / 1000, item.kind, item.text, item.count > 1 and string.format(" (x%d)", item.count) or "")
end

function A:Trace(kind, text)
	local log = self.traceLog
	if not log then
		return
	end
	local now = A.Stamp()
	local last = log[#log]
	local saved = self.sv and self.sv.trace
	if last and last.kind == kind and last.text == text and now - last.at < 1000 then
		last.count = last.count + 1
		if saved then
			saved[#saved] = A.TraceText(last)
		end
	else
		local item = { at = now, kind = kind, text = text, count = 1 }
		log[#log + 1] = item
		if saved then
			saved[#saved + 1] = A.TraceText(item)
		end
		while #log > A.TRACE_MAX do
			table.remove(log, 1)
			if saved then
				table.remove(saved, 1)
			end
		end
	end
end

function A:TraceLines()
	local lines = {}
	for _, item in ipairs(self.traceLog or {}) do
		lines[#lines + 1] = A.TraceText(item)
	end
	local earlier = {}
	for _, line in ipairs(self.earlierTrace or {}) do
		earlier[#earlier + 1] = line
	end
	return lines, earlier
end

-- ---------------------------------------------------------------------------------------
-- The game's calls, asked about before they are made
--
-- A private call raises the client's UI error, which pcall does not catch. So the API is asked first
-- (IsPrivateFunction / IsProtectedFunction) and, either way, `pending` is written to the saved variables before the first
-- call and cleared when it returns. If the game ever shows the error and the player reloads, the file still says
-- "pending", and next time that call is not made. `/pbpme retry` forgets what was learned.
-- ---------------------------------------------------------------------------------------

A.fnState = {}
A.native = {} -- name -> the game's own function, for the ones this add-on replaces (Wheel.lua)

function A:Judge(name)
	local state = { usable = false, why = "not checked yet", proven = false }
	self.fnState[name] = state
	local probe = self.sv.probe

	if probe[name] == "bad" then
		state.why = "it failed on an earlier login"
	elseif type(self.native[name] or _G[name]) ~= "function" then
		state.why = "the function does not exist"
	else
		local refused
		if probe.ask == "bad" then
			state.asked = "skipped: the question failed on an earlier login"
		elseif type(IsPrivateFunction) == "function" and type(IsProtectedFunction) == "function" then
			self.sv.pending = "ask"
			local okPrivate, isPrivate = pcall(IsPrivateFunction, name)
			local okProtected, isProtected = pcall(IsProtectedFunction, name)
			self.sv.pending = nil
			if okPrivate and okProtected then
				state.asked = (isPrivate and "private" or "not private") .. ", " .. (isProtected and "protected" or "not protected")
				refused = isPrivate or isProtected
			else
				state.asked = "the question failed"
			end
		else
			state.asked = "cannot ask"
		end
		if refused then
			state.why = "the game marks it private or protected"
		else
			state.usable = true
			state.why = "allowed"
		end
	end
	return state
end

-- The arguments go through exactly as given, and up to five results come back: every call this add-on makes fits.
function A:Call(name, ...)
	local state = self.fnState[name] or self:Judge(name)
	if not state.usable then
		return nil
	end
	local fn = self.native[name] or _G[name]
	if state.proven then
		return fn(...)
	end
	self.sv.pending = name
	local ok, r1, r2, r3, r4, r5 = pcall(fn, ...)
	self.sv.pending = nil
	if not ok then
		state.usable = false
		state.why = "the call raised: " .. tostring(r1)
		return nil
	end
	state.proven = true
	self.sv.probe[name] = "ok"
	return r1, r2, r3, r4, r5
end

-- ---------------------------------------------------------------------------------------
-- Small helpers (no game calls in here)
-- ---------------------------------------------------------------------------------------

-- The name a marked person is sent as: a 32-bit number made of their @account name (the same on every client, and a
-- plain sum so that no precision is lost: h * 33 stays far below 2^53). Zero is kept free.
function A.Hash(text)
	local h = 5381
	for i = 1, #text do
		h = (h * 33 + string.byte(text, i)) % 4294967296
	end
	if h == 0 then
		h = 1
	end
	return h
end

local sin, cos, sqrt = math.sin, math.cos, math.sqrt

-- The world offset (dx, dz) of a point `distance` away in the direction of a bearing (the camera heading is a bearing:
-- the game's own convention, see PBsWayPoint's Core.lua).
function A.Offset(bearing, distance)
	return sin(bearing) * distance, cos(bearing) * distance
end

function A.Distance(dx, dz)
	return sqrt(dx * dx + dz * dz)
end

A.MARK("Core")
