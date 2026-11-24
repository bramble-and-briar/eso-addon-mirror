-- The Meru-Sawa Style: instead of Ember, three countdown tiles in a row, each with a hand-written label and the
-- seconds the buff has left:   ぶる = Major Brutality   つよ = Major Resolve   よわ = Minor Resolve
--
-- A tile is light blue with whole seconds while its buff has 5 s or more ("the tiles turn yellow" setting),
-- yellow with tenths under that ("1.6"), and grey with OFF when the buff is gone. A buff with no end shows a dash
-- in light blue. A tile whose switch is off is not shown, and the row closes up. Turning yellow plays a sound when
-- the tiles' sound switch is on (the test plays it too, the preview in the settings panel does not).
--
-- The tiles are on the game screen only (a fragment in the HUD scenes, like Ember's window) and, with "only in
-- combat", only in a fight. Their update runs every 100 ms while they are up and changes a control only when
-- what it shows changes; nothing runs while they are not up. The art (lettering, digits, frame) is the add-on's
-- own, in assets/meru.dds, drawn white and tinted here (scripts/build_meru.py).
--
-- The numbers come from the buffs Watch.lua follows (A:BuffLeft). The preview (settings panel open) and the test
-- run a made-up countdown instead, so every state is seen.

local A, S = PBS_COMBAT_ASSISTANT, PBS_COMBAT_ASSISTANT_STRINGS
local M = PBS_COMBAT_ASSISTANT_MERU
local em = EVENT_MANAGER

local WINDOW_NAME = "PBsCombatAssistantTiles"
local TICK_NAME = A.name .. "Tiles"
local TICK_MS = 100
local ORDER = { "brutal", "major", "minor" } -- left to right
local LABEL_PART = { brutal = "lbl_brutal", major = "lbl_major", minor = "lbl_minor" }
local GAP = 10 -- u between two tiles
local LABEL_Y = 2 -- u from the tile's top to the label picture's top
local DIGIT_Y = 36 -- u from the tile's top to the digits' top
local DIGIT_STEP = 25 -- u a digit takes in the row of glyphs
local DOT_STEP = 10 -- u the decimal point takes
local POP_S = 0.45 -- the number swells for this long when a buff starts running out
local POP_GROW = 0.28
local GONE_ALPHA = 0.85
local PREVIEW_UNIT_MAX = 1.5
local PREVIEW_ANCHOR = { x = 60, y = 330 } -- from the right and the bottom edge of the screen, like Ember's
local DEMO_S = 14 -- the test runs this long

-- The made-up countdown of the preview and the test: seconds left = top - ((t + offset) mod period), gone below 0.
local DEMO = {
	brutal = { period = 32, top = 29.9, offset = 0 },
	major = { period = 13, top = 10.9, offset = 0 },
	minor = { period = 13, top = 9.9, offset = 4.5 },
}

-- light blue while it runs, yellow under the limit, grey (OFF) when it is gone
local COLOR = {
	run = { frame = { 0.42, 0.80, 1.00 }, digit = { 0.56, 0.88, 1.00 }, label = { 1, 1, 1 } },
	warn = { frame = { 1.00, 0.84, 0.28 }, digit = { 1.00, 0.87, 0.36 }, label = { 1, 0.97, 0.88 } },
	gone = { frame = { 0.78, 0.82, 0.90 }, digit = { 0.62, 0.66, 0.74 }, label = { 0.72, 0.75, 0.82 } },
}

local sin, floor, min = math.sin, math.floor, math.min

local tiles = {
	hud = false, -- the game screen is showing
	preview = false, -- the settings panel is open, in this style
	demoStart = nil, -- the test: when it started (nil when no test runs)
	testPending = false,
	shown = false,
	ticking = false,
	list = {}, -- kind -> the tile's controls and what it shows
	order = {}, -- the kinds shown, left to right
	-- counted for /pbca status
	frames = 0,
	pops = 0,
}
A.tiles = tiles

local view = {}
local DIGIT_PART = {}
for d = 0, 9 do
	DIGIT_PART[d] = M.parts["dig_" .. d]
end
local DASH_PART = M.parts.dig_dash
local DOT_PART = M.parts.dig_dot
local OFF_PART = M.parts.dig_off
local OFF, DASH = -2, -1

-- ---------------------------------------------------------------------------------------
-- What a tile shows. Pure: the offline tests call it with made-up numbers.
-- ---------------------------------------------------------------------------------------

-- left = seconds left (nil = the buff is not there, math.huge = it has no end), limit = the seconds under which
-- the tile turns yellow. Returns the state ("run" | "warn" | "gone") and what to show: whole seconds while it runs,
-- tenths of a second under the limit (16 = "1.6"), -1 = a dash (no end), -2 = OFF.
function A.TileFace(left, limit)
	if left == nil or left <= 0 then
		return "gone", OFF
	end
	if left == math.huge then
		return "run", DASH
	end
	if left < limit then
		return "warn", min(99, floor(left * 10 + 1e-6))
	end
	return "run", min(99, floor(left + 1e-6))
end

function A.DemoLeft(kind, t)
	local d = DEMO[kind]
	local left = d.top - ((t + d.offset) % d.period)
	if left <= 0 then
		return nil
	end
	return left
end

-- ---------------------------------------------------------------------------------------
-- The controls
-- ---------------------------------------------------------------------------------------

local function Texture(name, parent, part, level)
	local c = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
	c:SetTexture(M.atlas)
	c:SetTextureCoords(part.u0, part.u1, part.v0, part.v1)
	c:SetDrawLayer(DL_CONTROLS)
	c:SetDrawLevel(level)
	c:SetMouseEnabled(false)
	return c
end

local function Build(window)
	view.window = window
	view.box = WINDOW_MANAGER:CreateControl(WINDOW_NAME .. "Box", window, CT_CONTROL)
	view.box:SetMouseEnabled(false)
	view.box:SetHidden(true)
	tiles.box = view.box
	for _, kind in ipairs(ORDER) do
		local base = WINDOW_NAME .. kind
		local root = WINDOW_MANAGER:CreateControl(base, view.box, CT_CONTROL)
		root:SetMouseEnabled(false)
		tiles.list[kind] = {
			kind = kind,
			root = root,
			fill = Texture(base .. "Fill", root, M.parts.tile_fill, 10),
			frame = Texture(base .. "Frame", root, M.parts.tile_frame, 11),
			label = Texture(base .. "Label", root, M.parts[LABEL_PART[kind]], 12),
			glyphs = {
				Texture(base .. "Digit1", root, DIGIT_PART[0], 13),
				Texture(base .. "Digit2", root, DIGIT_PART[0], 13),
				Texture(base .. "Digit3", root, DIGIT_PART[0], 13),
			},
			parts = {}, -- the atlas pieces the glyphs show, left to right (filled again, never made anew)
			count = 0,
			state = nil, -- what it shows now; nil = not drawn yet
			value = nil,
			popAt = nil,
			scale = 1,
		}
	end
end

local function Unit()
	local u = (A.sv and A.sv.tileSize or 100) / 100
	if tiles.preview then
		u = min(u, PREVIEW_UNIT_MAX)
	end
	return u
end

local function StepOf(part)
	if part == DOT_PART then
		return DOT_STEP
	elseif part == OFF_PART then
		return OFF_PART.w * 0.8
	end
	return DIGIT_STEP
end

-- Places the pictures of one tile; k > 1 swells the number about its centre.
local function PlaceTile(tile, unit, k)
	local T = M.tile
	local root = tile.root
	local g = T.glow * unit
	local function at(c, x, y, w, h)
		c:ClearAnchors()
		c:SetAnchor(TOPLEFT, root, TOPLEFT, x, y)
		c:SetDimensions(w, h)
	end
	at(tile.fill, -g, -g, M.parts.tile_fill.w * unit, M.parts.tile_fill.h * unit)
	at(tile.frame, -g, -g, M.parts.tile_frame.w * unit, M.parts.tile_frame.h * unit)
	local lp = M.parts[LABEL_PART[tile.kind]]
	at(tile.label, (T.w - lp.w) / 2 * unit, LABEL_Y * unit, lp.w * unit, lp.h * unit)
	-- the glyphs side by side, each taking its step, the row centred; a picture is wider than its step (outline)
	local cy = (DIGIT_Y + DIGIT_PART[0].h / 2) * unit
	local total = 0
	for i = 1, tile.count do
		total = total + StepOf(tile.parts[i])
	end
	local x = (T.w - total * k) / 2 * unit
	for i, c in ipairs(tile.glyphs) do
		local part = tile.parts[i]
		if i <= tile.count and part then
			local step = StepOf(part) * k * unit
			local w, h = part.w * unit * k, part.h * unit * k
			at(c, x + step / 2 - w / 2, cy - h / 2, w, h)
			c:SetHidden(false)
			x = x + step
		else
			c:SetHidden(true)
		end
	end
	tile.scale = k
end

local function SetPart(c, part)
	c:SetTextureCoords(part.u0, part.u1, part.v0, part.v1)
end

local function Tint(c, rgb)
	c:SetColor(rgb[1], rgb[2], rgb[3], 1)
end

-- The glyphs for what a tile shows: 29 -> "2" "9", in yellow 16 -> "1" "." "6", a dash, or OFF.
local function Spell(tile, state, value)
	local p = tile.parts
	if value == OFF then
		p[1], tile.count = OFF_PART, 1
	elseif value == DASH then
		p[1], tile.count = DASH_PART, 1
	elseif state == "warn" then
		p[1], p[2], p[3], tile.count = DIGIT_PART[floor(value / 10)], DOT_PART, DIGIT_PART[value % 10], 3
	elseif value >= 10 then
		p[1], p[2], tile.count = DIGIT_PART[floor(value / 10)], DIGIT_PART[value % 10], 2
	else
		p[1], tile.count = DIGIT_PART[value], 1
	end
end

-- Draws what changed: the glyphs when the number changes, the colours when the state changes.
local function Show(tile, state, value, unit)
	local changed = value ~= tile.value or state ~= tile.state
	if state ~= tile.state then
		local c = COLOR[state]
		Tint(tile.frame, c.frame)
		Tint(tile.label, c.label)
		for _, g in ipairs(tile.glyphs) do
			Tint(g, c.digit)
		end
		tile.root:SetAlpha(state == "gone" and GONE_ALPHA or 1)
		tile.state = state
	end
	if changed then
		tile.value = value
		Spell(tile, state, value)
		for i = 1, tile.count do
			SetPart(tile.glyphs[i], tile.parts[i])
		end
		PlaceTile(tile, unit, tile.scale)
	end
end

-- The row: the tiles whose switch is on, side by side; the window is anchored by its bottom centre.
local function Layout()
	local window = view.window
	if not window then
		return
	end
	local unit = Unit()
	local T = M.tile
	local n = 0
	for i = #tiles.order, 1, -1 do
		tiles.order[i] = nil
	end
	for _, kind in ipairs(ORDER) do
		local tile = tiles.list[kind]
		if A.sv[kind] then
			n = n + 1
			tiles.order[n] = kind
			tile.root:SetHidden(false)
			tile.root:ClearAnchors()
			tile.root:SetAnchor(TOPLEFT, view.box, TOPLEFT, (n - 1) * (T.w + GAP) * unit, 0)
			tile.root:SetDimensions(T.w * unit, T.h * unit)
			PlaceTile(tile, unit, 1)
		else
			tile.root:SetHidden(true)
		end
	end
	local w = math.max(1, n * T.w + math.max(0, n - 1) * GAP) * unit
	local h = T.h * unit
	window:SetDimensions(w, h)
	window:ClearAnchors()
	if tiles.preview then
		window:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, -PREVIEW_ANCHOR.x, -PREVIEW_ANCHOR.y)
	else
		window:SetAnchor(BOTTOM, GuiRoot, BOTTOM, A.sv.tileX, -A.sv.tileY)
	end
	view.box:ClearAnchors()
	view.box:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 0)
	view.box:SetDimensions(w, h)
end

-- ---------------------------------------------------------------------------------------
-- The update
-- ---------------------------------------------------------------------------------------

local function Demo()
	return tiles.preview or tiles.demoStart ~= nil
end

-- The tiles' own sound switch ("a sound when a tile turns yellow"), not Ember's.
local function PlayPop()
	if not A.sv.tileSound or tiles.preview then
		return
	end
	A.PlayNamed("NEW_TIMED_NOTIFICATION")
end

function A:TilesRender(now)
	local unit = Unit()
	local demo = Demo()
	local t = demo and (now - (tiles.demoStart or tiles.previewStart or now)) or 0
	for _, kind in ipairs(tiles.order) do
		local tile = tiles.list[kind]
		local left
		if demo then
			left = A.DemoLeft(kind, t)
		else
			left = self:BuffLeft(kind, now)
		end
		local state, value = A.TileFace(left, self.sv.tileWarn or 5)
		if state == "warn" and tile.state ~= "warn" and tile.state ~= nil then
			tile.popAt = now
			tiles.pops = tiles.pops + 1
			PlayPop()
		end
		Show(tile, state, value, unit)
		-- the swell of the number, then the pulse of the frame while it is running out
		if tile.popAt then
			local k = (now - tile.popAt) / POP_S
			if k >= 1 then
				tile.popAt = nil
				PlaceTile(tile, unit, 1)
			else
				PlaceTile(tile, unit, 1 + POP_GROW * sin(math.pi * k))
			end
		end
	end
end

local function Wanted()
	local sv = A.sv
	if not (sv and sv.enabled and sv.style == 2 and view.window) then
		return false
	end
	if not (sv.major or sv.minor or sv.brutal) then
		return false
	end
	if tiles.preview then
		return true
	end
	if not tiles.hud then
		return false
	end
	if tiles.demoStart then
		return true
	end
	local watch = A.watch
	if watch and watch.dead then
		return false
	end
	return (watch and watch.inCombat) or not sv.combatOnly
end

local function Tick()
	local now = A.Now()
	if tiles.demoStart and now - tiles.demoStart >= DEMO_S then
		tiles.demoStart = nil
		A:TilesUpdateState()
		if not tiles.shown then
			return
		end
	end
	tiles.frames = tiles.frames + 1
	A:TilesRender(now)
end

local function Forget()
	for _, tile in pairs(tiles.list) do
		tile.state, tile.value, tile.popAt, tile.scale, tile.count = nil, nil, nil, 1, 0
	end
end

local function SafeTick()
	local ok, err = pcall(Tick)
	if not ok then
		A.errors = A.errors + 1
		A.lastError = "tiles: " .. tostring(err)
		tiles.demoStart = nil
		pcall(Forget)
	end
end

-- Shows or hides the row and starts or stops its update. Called whenever something it depends on changes
-- (a fight starts or ends, the game screen comes or goes, a setting), never every frame.
function A:TilesUpdateState()
	local want = Wanted()
	if view.box then
		if want then
			Layout()
			Forget()
			view.box:SetHidden(false)
			self:TilesRender(A.Now())
		else
			view.box:SetHidden(true)
			tiles.demoStart = nil -- a test stops when the game screen goes
		end
	end
	tiles.shown = want
	if want and not tiles.ticking then
		tiles.ticking = true
		em:RegisterForUpdate(TICK_NAME, TICK_MS, SafeTick)
	elseif not want and tiles.ticking then
		tiles.ticking = false
		em:UnregisterForUpdate(TICK_NAME)
	end
end

function A:TilesPreview(on)
	on = on and true or false
	if tiles.preview == on or not view.window then
		return
	end
	tiles.preview = on
	tiles.previewStart = A.Now()
	view.window:SetHidden(not (on or tiles.hud))
	self:TilesUpdateState()
end

-- The test: the made-up countdown for a few seconds on the game screen.
function A:TilesTest()
	if tiles.preview then
		return false
	end
	if not tiles.hud then
		tiles.testPending = true
		return false
	end
	tiles.testPending = false
	tiles.demoStart = A.Now()
	self:TilesUpdateState()
	return true
end

function A:InitTiles()
	local window = _G[WINDOW_NAME]
	if not window then
		error("the tile window is missing: PBsCombatAssistant.xml did not load")
	end
	Build(window)
	local fragment = ZO_SimpleSceneFragment:New(window)
	tiles.fragment = fragment
	fragment:RegisterCallback("StateChange", function(_, newState)
		if newState == SCENE_FRAGMENT_SHOWN then
			tiles.hud = true
			if tiles.testPending then
				A:TilesTest()
			end
		elseif newState == SCENE_FRAGMENT_HIDING or newState == SCENE_FRAGMENT_HIDDEN then
			tiles.hud = false
		end
		A:TilesUpdateState()
	end)
	HUD_SCENE:AddFragment(fragment)
	HUD_UI_SCENE:AddFragment(fragment)
	self:TilesUpdateState()
end

PBS_COMBAT_ASSISTANT_MARK("Tiles")
