-- The extra markers on the compass bar at the top of the screen, as the game shows its own target markers there.
--
-- HOW THE GAME DOES IT (esoui/ingame/compass/compass.xml, read, not measured): the bar is ONE native control, `Compass`
-- (ZO_CompassContainer, a child of ZO_Compass, which is anchored over ZO_CompassFrame: top of the screen, 24 px high on a
-- console, 35 % of the screen wide between 400 and 800 px). Its pins are drawn by the engine: each is a `CompassPinType` named
-- after a map pin type, and the game's eight target markers are TARGET_MARKER_TYPE_ONE..EIGHT with `clamped="true"` (a pin whose
-- person is out of view sticks to the end of the bar), no maximum distance, alpha 1.0 near and 0.75 from 85 m. A Lua add-on can
-- neither add a pin type nor give an existing one a picture per person (CompassDisplayControl:SetPinInfo is per TYPE), the same
-- limit as the 3D markers have: so the extra markers are drawn by this add-on, on top of the bar.
--
-- WHERE A PICTURE GOES. The engine's own mapping from a bearing to a place on the bar is not in the Lua source. CustomCompassPins
-- (Shinni; used by LoreBooks, SkyShards and others for years to draw their pins level with the game's own) uses
--     angle           = the bearing of the thing relative to where the camera looks, in [-pi, pi], to the right positive
--     normalizedAngle = 2 * angle / FOV            FOV = 0.6 pi (108 degrees)
--     offsetX         = 0.5 * barWidth * normalizedAngle, anchored CENTER to CENTER of the bar
-- and this does the same, with the FOV a setting (`compassFov`) for the player to tune against the game's own pins, and the
-- picture clamped to the ends of the bar the way the game's target markers are.
--
-- WHICH WAY IS "TO THE RIGHT" (0.4.5 got it exactly backwards on a PS5, the player's report): the angle comes from
-- GetPlayerCameraHeading() (h) and the bearing of the member b = atan2(dx, dz) in the raw world axes of GetUnitRawWorldPosition.
-- What is KNOWN is only that h grows when the camera turns to the LEFT, with 0 looking north (the map's player pin is turned by it,
-- and the radial menu code shows that SetTextureRotation turns counter-clockwise; CustomCompassPins' formula needs it too). What
-- is NOT known is how the raw world axes lie: the client's housing editor (atan2(dx, dz) - heading turns an arrow right) says
-- +Z is north and +X west, the map says x east, y south (which would make +X east and +Z south). From those two facts, how the
-- bearing of the direction the camera looks in (call it L(h)) relates to h is one of four things:
--     1  L = h            2  L = -h            3  L = h + pi            4  L = pi - h
-- and the angle to the right of the camera is  sign * (L(h) - b)  with sign +1 for 1 and 3 (a bearing that grows the way h
-- grows) and -1 for 2 and 4. 0.4.5 used 1 (the housing editor's). The player saw everything on the opposite side, which is 3
-- (+X east, +Z south: the same turned half a circle), so 3 is the starting guess. And it is MEASURED, not trusted: whenever a
-- group member is under the reticle (so straight ahead) 10 m or more away, the four are scored on it (cos of what each says the
-- angle to that member is: 1 when it says "ahead"), and the best one is used once it leads clearly; what was learned is kept in
-- the saved variables (`compassConvention`) as the start of the next session. `/pbpme compass 1|2|3|4|auto` sets it by hand.
--
-- THE PICTURES are children of the game's bar (like CustomCompassPins' pins), so they are hidden with it: when the HUD is hidden,
-- while a boss bar stands in for the compass, and so on, with no rule of this add-on's. Nothing of the client's is written: the
-- bar is only read (its width) and used as the anchor.
--
-- WHO: the group members with an extra marker who are online and in the player's world, whatever the distance (the game's own
-- markers have no maximum distance either). Not the player themself (they are the centre of the bar). The player's own switch
-- "Target markers" in the game's compass options (UI_SETTING_COMPASS_TARGET_MARKERS) is obeyed: with it off the game shows none
-- of its own markers on the bar, and this shows none of the extra ones.
--
-- TEST: `/pbpme test` / the settings button also puts four markers on the bar in the directions of the compass letters N, E, S, W
-- (worked out from the convention in use: a compass direction c, clockwise from north, is looked at with h = -c): they must sit
-- under the game's own letters wherever the camera turns. If they sit beside them, change "degrees the compass bar covers"; if
-- they are on the wrong side, `/pbpme compass 1|2|3|4` shows which convention puts them right (and tells which one was in use).
--
-- NOT MEASURED ON A PS5: that the bar accepts children, that the mapping lines up with the game's own pins (the FOV), the size, which
-- convention the learning settles on.
local A, S = PBS_PME, PBS_PME_STRINGS

local MAX_SPRITES = 26
local BASE_SIZE = 28 -- pixels at 100 %
local ALPHA_NEAR, ALPHA_FAR, ALPHA_FAR_M = 1.0, 0.75, 85 -- the game's own target marker pins: full up close, 0.75 from 85 m
local OPTION_MS = 500 -- the game's compass option is asked this often
local PI = math.pi
local DEGREES = PI / 180
local min, max, abs = math.min, math.max, math.abs
local atan2 = math.atan2 or function(y, x)
	return math.atan(y, x)
end

-- the four ways the camera heading h can relate to the bearing L(h) = atan2(dx, dz) of the direction the camera looks in
-- (see the header): L = look * h + turn, and the angle to the right of the camera is sign * (L - b)
local CONVENTIONS = {
	{ look = 1, turn = 0, sign = 1 },
	{ look = -1, turn = 0, sign = -1 },
	{ look = 1, turn = PI, sign = 1 },
	{ look = -1, turn = PI, sign = -1 },
}
local DEFAULT_CONVENTION = 3
local LEARN_MS = 250 -- how often the reticle is looked at
local LEARN_MIN_M, LEARN_MAX_M = 10, 150 -- members nearer than this are seen from the camera's side; farther ones are hard to aim at
local LEARN_AGAIN_MS = 2000 -- one sample per member this often
local LEARN_PRIOR = 1.5 -- the standing convention starts with this many votes
local LEARN_LEAD = 1.5 -- another convention must lead by this many votes to take over
-- the test markers: north, east, south, west as (compass direction clockwise from north, icon)
local TEST_DIRECTIONS = { { 0, 3 }, { PI / 2, 1 }, { PI, 2 }, { 3 * PI / 2, 8 } }

A.compass = {
	sprites = nil,
	used = 0,
	parent = nil,
	parentName = nil,
	off = nil, -- why this part is off for the session
	errors = 0,
	errorsInRow = 0,
	lastError = nil,
	why = "not looked at yet",
	gameOption = nil, -- the player's own "Target markers" switch of the game's compass (nil = could not be asked)
	optionAt = -1e9,
	lastDrawn = 0,
	lastWidth = nil,
	convention = nil, -- 1..4 in use
	votes = nil, -- convention -> score of the samples so far
	samples = 0,
	lastSample = nil, -- { name, metres, degrees } of the last member under the reticle, for status
	sampleAt = {}, -- last sample times for members still within the resampling delay
	learnAt = -1e9,
	forced = false,
}

-- The game's bar: COMPASS.container, else the global of the same control.
function A:CompassParent()
	local c = self.compass
	local compass = _G.COMPASS
	local parent = type(compass) == "table" and compass.container or nil
	if parent ~= nil then
		c.parentName = "COMPASS.container"
		return parent
	end
	parent = _G.ZO_CompassContainer
	if parent ~= nil then
		c.parentName = "ZO_CompassContainer"
		return parent
	end
	return nil
end

function A:CreateCompassSprites(parent)
	local sprites = {}
	for i = 1, MAX_SPRITES do
		local control = WINDOW_MANAGER:CreateControl("PBsPlayerMarkerExtensionCompassMark" .. i, parent, CT_TEXTURE)
		control:SetTexture(A.IconPath(1))
		control:SetMouseEnabled(false)
		control:SetDrawLayer(DL_OVERLAY)
		control:SetHidden(true)
		sprites[i] = { control = control, hidden = true }
	end
	self.compass.sprites = sprites
	return sprites
end

local function HideFrom(c, first)
	local sprites = c.sprites
	if not sprites then
		return
	end
	for i = first, c.used do
		local item = sprites[i]
		if item and not item.hidden then
			item.control:SetHidden(true)
			item.hidden = true
		end
	end
	c.used = min(c.used, first - 1)
end

-- Is the game showing its own target markers on the bar? The player's choice (a call that is not allowed counts as yes).
function A:CompassOption(now)
	local c = self.compass
	if now - c.optionAt < OPTION_MS then
		return c.gameOption
	end
	c.optionAt = now
	local option
	if SETTING_TYPE_UI ~= nil and UI_SETTING_COMPASS_TARGET_MARKERS ~= nil then
		option = self:Call("GetSetting_Bool", SETTING_TYPE_UI, UI_SETTING_COMPASS_TARGET_MARKERS)
	end
	c.gameOption = option
	return option
end

-- The angle from where the camera looks to a bearing, in [-pi, pi], to the right positive, by convention `k` (see the header).
local function RightAngle(k, heading, bearing)
	local convention = CONVENTIONS[k]
	local angle = convention.sign * (convention.look * heading + convention.turn - bearing)
	return (angle + PI) % (2 * PI) - PI
end

-- The convention in use: set by hand (`compassForce`), else the best of the votes, starting from what was learned last time
-- (`compassConvention`) or the standing guess.
function A:CompassConvention()
	local c = self.compass
	if c.convention then
		return c.convention
	end
	local sv = self.sv
	local forced = sv.compassForce
	if type(forced) == "number" and CONVENTIONS[forced] then
		c.convention, c.forced = forced, true
		return forced
	end
	local prior = type(sv.compassConvention) == "number" and CONVENTIONS[sv.compassConvention] and sv.compassConvention or DEFAULT_CONVENTION
	c.votes = { 0, 0, 0, 0 }
	c.votes[prior] = LEARN_PRIOR
	c.convention, c.forced = prior, false
	return prior
end

-- `/pbpme compass [1|2|3|4|auto]`: returns the text to say.
function A:CompassCommand(word)
	local c = self.compass
	local n = tonumber(word)
	if n and CONVENTIONS[n] then
		self.sv.compassForce = n
		c.convention = nil
		self:CompassConvention()
		return string.format(S.compassSet, n)
	elseif word == "auto" then
		self.sv.compassForce = nil
		c.convention, c.samples, c.lastSample = nil, 0, nil
		self:CompassConvention()
		return string.format(S.compassAuto, c.convention)
	end
	return S.compassUsage
end

-- Forgets what was learned (`/pbpme retry`).
function A:CompassForget()
	local c = self.compass
	self.sv.compassConvention, self.sv.compassForce = nil, nil
	c.convention, c.samples, c.lastSample, c.sampleAt = nil, 0, nil, {}
end

-- One sample, while a group member is under the reticle (so straight ahead): each convention is scored by how close to
-- "ahead" it says that member is.
function A:CompassLearn(now)
	local c = self.compass
	if now - c.learnAt < LEARN_MS then
		return
	end
	c.learnAt = now
	for hash, sampledAt in pairs(c.sampleAt) do
		if now - sampledAt >= LEARN_AGAIN_MS then
			c.sampleAt[hash] = nil
		end
	end
	local sv = self.sv
	if not (sv.enabled and self.hudShown and DoesUnitExist and AreUnitsEqual and DoesUnitExist("reticleover")) then
		return
	end
	self:CompassConvention()
	if c.forced then
		return
	end
	local target
	for _, entry in ipairs(self:RefreshRoster(false).list) do
		if not entry.self and entry.online and AreUnitsEqual("reticleover", entry.tag) then
			target = entry
			break
		end
	end
	if not target or c.sampleAt[target.hash] then
		return
	end
	local zone, px, py, pz = self:Call("GetUnitRawWorldPosition", "player")
	local heading = self:Call("GetPlayerCameraHeading")
	if type(zone) ~= "number" or type(px) ~= "number" or type(heading) ~= "number" or heading ~= heading then
		return
	end
	local x, _, z = self:MemberPosition(target, zone, px, py, pz, true)
	if not x then
		return
	end
	local dx, dz = x - px, z - pz
	local metres = math.sqrt(dx * dx + dz * dz) / 100
	if metres < LEARN_MIN_M or metres > LEARN_MAX_M then
		return
	end
	c.sampleAt[target.hash] = now
	local bearing = atan2(dx, dz)
	local votes = c.votes
	local last = c.lastSample or {}
	last.name, last.metres = target.name, metres
	for k = 1, #CONVENTIONS do
		local angle = RightAngle(k, heading, bearing)
		votes[k] = votes[k] + math.cos(angle)
		last[k] = angle / DEGREES
	end
	c.lastSample = last
	c.samples = c.samples + 1
	local best = c.convention
	for k = 1, #CONVENTIONS do
		if votes[k] > votes[best] then
			best = k
		end
	end
	if best ~= c.convention and votes[best] - votes[c.convention] >= LEARN_LEAD then
		local was = c.convention
		c.convention = best
		sv.compassConvention = best
		self:Trace("compass", string.format("compass directions: convention %d (was %d) after %d members aimed at; votes %.1f %.1f %.1f %.1f",
			best, was, c.samples, votes[1], votes[2], votes[3], votes[4]))
	end
end

-- Puts picture `index` on the bar for something at (dx, dz) from the player, `metres` away.
local function Place(self, c, parent, index, icon, theta, metres, halfFov, width, size)
	local item = c.sprites[index]
	local control = item.control
	-- theta: where it is relative to where the camera looks, to the right of the bar positive (see RightAngle)
	local x = theta / halfFov * (width * 0.5)
	local limit = (width - size) * 0.5
	if limit < 0 then
		limit = 0
	end
	if x > limit then
		x = limit
	elseif x < -limit then
		x = -limit
	end
	if item.icon ~= icon then
		control:SetTexture(A.IconPath(icon))
		item.icon = icon
	end
	if item.size ~= size then
		control:SetDimensions(size, size)
		item.size = size
	end
	local alpha = (ALPHA_NEAR - (ALPHA_NEAR - ALPHA_FAR) * min(1, metres / ALPHA_FAR_M)) * (self.sv.opacity / 100)
	if item.alpha ~= alpha then
		control:SetColor(1, 1, 1, alpha)
		item.alpha = alpha
	end
	if not item.x or abs(item.x - x) >= 0.25 or item.parent ~= parent then
		control:ClearAnchors()
		control:SetAnchor(CENTER, parent, CENTER, x, 0)
		item.x, item.parent = x, parent
	end
	if item.hidden then
		control:SetHidden(false)
		item.hidden = false
	end
end

-- Once per frame (the tick calls it under its own guard).
function A:UpdateCompass(now)
	local c = self.compass
	local sv = self.sv
	local wanted = sv.enabled and sv.compassMarks and self.hudShown and (self.test ~= nil or next(self.marks) ~= nil)
	if not wanted then
		c.why = (not sv.enabled and "switched off") or (not sv.compassMarks and "the compass setting is off") or (not self.hudShown and "not on the HUD scene")
			or "nothing is marked"
		HideFrom(c, 1)
		c.lastDrawn = 0
		return
	end
	if self:CompassOption(now) == false then
		c.why = "the game's own compass option 'Target markers' is off"
		HideFrom(c, 1)
		c.lastDrawn = 0
		return
	end
	local parent = c.parent
	if parent == nil then
		parent = self:CompassParent()
		c.parent = parent
		if parent == nil then
			c.why = "the game's compass control was not found"
			return
		end
	end
	if not c.sprites then
		self:CreateCompassSprites(parent)
	end

	-- the player's position and heading: this frame's, as the 3D pass read them, or read here when that pass did not run
	local diag = self.diag
	local playerZone, px, py, pz, heading
	if diag.frameAt == now then
		playerZone, px, py, pz, heading = diag.pzone, diag.px, diag.py, diag.pz, diag.heading
	else
		playerZone, px, py, pz = self:Call("GetUnitRawWorldPosition", "player")
		heading = self:Call("GetPlayerCameraHeading")
	end
	if type(playerZone) ~= "number" or type(px) ~= "number" or type(heading) ~= "number" or heading ~= heading then
		c.why = "the game gives no position or camera heading"
		HideFrom(c, 1)
		c.lastDrawn = 0
		return
	end
	local width = parent:GetWidth()
	if type(width) ~= "number" or width <= 0 then
		c.why = "the compass bar has no width yet"
		HideFrom(c, 1)
		c.lastDrawn = 0
		return
	end
	c.lastWidth = width
	local halfFov = sv.compassFov * DEGREES * 0.5
	local size = BASE_SIZE * sv.compassSize / 100

	local convention = self:CompassConvention()
	local count = 0
	local roster = self.roster
	for hash, m in pairs(self.marks) do
		local entry = roster.byHash[hash]
		if entry and entry.online and not entry.self and count < MAX_SPRITES - #TEST_DIRECTIONS then
			-- where the member is: the 3D pass of this frame knows (`rel`); else it is asked here
			local dx, dz, metres
			local rel = m.rel
			if rel and rel.at == now then
				if rel.ok then
					dx, dz, metres = rel.dx, rel.dz, rel.metres
				end
			else
				local x, _, z = self:MemberPosition(entry, playerZone, px, py, pz, true)
				if x then
					dx, dz = x - px, z - pz
					metres = math.sqrt(dx * dx + dz * dz) / 100
				end
			end
			if dx then
				count = count + 1
				Place(self, c, parent, count, m.icon, RightAngle(convention, heading, atan2(dx, dz)), metres, halfFov, width, size)
			end
		end
	end
	if self.test then
		-- a compass direction d (clockwise from north) is looked at when h = -d, and the bearing there is L(-d)
		local look = CONVENTIONS[convention]
		for _, direction in ipairs(TEST_DIRECTIONS) do
			count = count + 1
			local bearing = look.look * -direction[1] + look.turn
			Place(self, c, parent, count, direction[2], RightAngle(convention, heading, bearing), 0, halfFov, width, size)
		end
	end
	HideFrom(c, count + 1)
	c.used = count
	c.lastDrawn = count
	c.why = count > 0 and "drawing" or "no marked member could be placed (see each marker)"
end

-- Called by the tick: a failure counts, and five in a row switch this part off for the session.
function A:CompassTick(now)
	local c = self.compass
	if c.off then
		return
	end
	local ok, err = pcall(function()
		self:CompassLearn(now)
		self:UpdateCompass(now)
	end)
	if ok then
		c.errorsInRow = 0
		return
	end
	c.errors = c.errors + 1
	c.errorsInRow = c.errorsInRow + 1
	c.lastError = tostring(err)
	if c.errorsInRow >= 5 then
		c.off = "errors: " .. c.lastError
		pcall(HideFrom, c, 1)
		self:Trace("compass", "the compass markers are left alone for this session: " .. c.lastError)
	end
end

-- A line for /pbpme status.
function A:CompassText()
	local c = self.compass
	if c.off then
		return "OFF for this session: " .. tostring(c.off)
	end
	local sv = self.sv
	local option = c.gameOption
	local text = string.format("setting %s | the game's 'Target markers' option %s | bar: %s, %s px wide | pictures on it %d | why: %s | FOV %s degrees | errors %d%s",
		sv and sv.compassMarks and "on" or "off", option == nil and "unknown" or (option and "on" or "OFF"), tostring(c.parentName or "not found yet"),
		c.lastWidth and string.format("%.0f", c.lastWidth) or "?", c.lastDrawn, tostring(c.why), tostring(sv and sv.compassFov),
		c.errors, c.lastError and (" (last: " .. c.lastError .. ")") or "")
	local convention = c.convention or self:CompassConvention()
	text = text .. string.format(" | directions: convention %d%s", convention, c.forced and " (set by hand)" or string.format(" (learned from %d members aimed at%s)", c.samples,
		c.votes and string.format("; votes %.1f %.1f %.1f %.1f", c.votes[1], c.votes[2], c.votes[3], c.votes[4]) or ""))
	local last = c.lastSample
	if last then
		text = text .. string.format(" | last member aimed at: %s, %.0f m, where each convention puts them (degrees to the right, 0 = ahead): %.0f %.0f %.0f %.0f",
			tostring(last.name), last.metres, last[1], last[2], last[3], last[4])
	end
	return text
end

A.MARK("Compass")
