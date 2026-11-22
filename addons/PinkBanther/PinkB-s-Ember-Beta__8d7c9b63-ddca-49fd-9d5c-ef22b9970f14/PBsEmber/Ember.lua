-- Ember on the screen: what she does (animation), when she is there (the director), and her speech bubble.
-- The window itself is in PBsEmber.xml; the pictures are put together by Puppet.lua.
--
-- ---------------------------------------------------------------------------------------
-- THE DIRECTOR
-- ---------------------------------------------------------------------------------------
--
-- Watch.lua says what is going on in the game with three calls:
--     A:Raise(kind, data)         something needs saying (kind = "danger" | "hp" | "major" | "minor" | "brutal");
--                                 called again for the same kind it only refreshes the data
--     A:Settle(kind, state)       it ended: state "relief" (it is fine again) or "lost" (it ran out)
--     A:Withdraw(kind) / A:ClearReasons()   gone without comment
-- A raised reason stays for the "seconds she stays" setting, a settled one for about two seconds, then it is
-- dropped. While any reason is alive Ember is on screen; when the last one goes she leaves. One line of the
-- speech bubble per reason (three at most, the most urgent first).
--
-- Her mood follows the most urgent reason: alarm (Resolve running out: hops and points at the bubble),
-- worry (health low: trembles, hands at her chest, ears down), panic (health very low: both arms up, shaking),
-- relief (it ended well: hops, sparkles) and sad (it ran out).
--
-- ---------------------------------------------------------------------------------------
-- WHEN SHE IS ON SCREEN
-- ---------------------------------------------------------------------------------------
--
-- The window belongs to a scene fragment that sits in the HUD scenes (HUD_SCENE and HUD_UI_SCENE), the way PB's
-- KillLog and Online Status Alert put theirs there, so it is on the game screen and nowhere else. The update
-- runs (every 33 ms) only while she is on screen or something is waiting for her; otherwise nothing runs.
--
-- THE PREVIEW: while the add-on's settings panel is open she plays all of her alerts in a loop at the right
-- of the screen (Settings.lua says when the panel is open), at her size and with her text.

local A, S = PBS_EMBER, PBS_EMBER_STRINGS
local G = PBS_EMBER_GEOMETRY
local em = EVENT_MANAGER

local WINDOW_NAME = "PBsEmberWindow"
local TICK_NAME = A.name .. "Tick"
local TICK_MS = 33
local ENTER_S = 0.42
local EXIT_S = 0.32
local BLEND_S = 0.25
local MAX_STEP = 0.25 -- one hitch must not skip a whole move
local LOST_S = 2.2 -- a "ran out" line stays this long
local RELIEF_S = 1.7
local TEXT_EVERY = 0.2 -- s between two refreshes of the bubble text
local MAX_LINES = 3
local PREVIEW_UNIT_MAX = 1.5
local PREVIEW_ANCHOR = { x = 60, y = 330 } -- from the right and the bottom edge of the screen

local TAU = math.pi * 2
local sin, abs, pi, min, max = math.sin, math.abs, math.pi, math.min, math.max

local PRIORITY = { danger = 1, hp = 2, major = 3, minor = 4, brutal = 5 }
local MOOD_OF = { danger = "panic", hp = "worry", major = "alarm", minor = "alarm", brutal = "alarm" }
local LINE_COLOR = {
	danger = { 1.00, 0.45, 0.45 },
	hp = { 1.00, 0.72, 0.74 },
	major = { 1.00, 0.85, 0.45 },
	brutal = { 1.00, 0.66, 0.42 },
	minor = { 1.00, 0.92, 0.66 },
	relief = { 0.62, 0.94, 0.70 },
	lost = { 0.80, 0.80, 0.86 },
}
local LINE_ICON = { danger = "ico_heart", hp = "ico_heart", major = "ico_shield", minor = "ico_shield", brutal = "ico_sword" }
local SOUND_NAME = { danger = "GENERAL_ALERT_ERROR", hp = "ABILITY_NOT_ENOUGH_HEALTH", major = "NEW_TIMED_NOTIFICATION", minor = "NEW_TIMED_NOTIFICATION", brutal = "NEW_TIMED_NOTIFICATION", relief = "ARMORY_RESTORE_SUCCESS" }

-- Bubble text sizes (named gamepad faces the console UI already has loaded; a face nothing else is drawing with
-- has to be built on use, and that has crashed a PS5), by the size setting.
local FONTS = {
	{ upTo = 75, font = "ZoFontGamepad18", line = 28, pad = 14 },
	{ upTo = 125, font = "ZoFontGamepad22", line = 34, pad = 16 },
	{ upTo = 165, font = "ZoFontGamepad27", line = 40, pad = 18 },
	{ upTo = 9999, font = "ZoFontGamepad34", line = 48, pad = 20 },
}
local BUBBLE_MIN_W = 300
local BUBBLE_CORNER = 16
local TAIL_W, TAIL_H = 16, 20
local ICON_GAP = 6

local ember = {
	reasons = {}, -- kind -> { kind, state = "active" | "relief" | "lost", since, expire, data }
	phase = "hidden", -- hidden | enter | loop | exit
	t = 0, -- seconds in the phase
	clock = 0, -- seconds since she appeared: drives the loops
	mood = "alarm",
	prevMood = nil,
	prevClock = 0,
	blend = 1,
	hud = false, -- the game screen is showing
	preview = false, -- the settings panel is open and she is playing the preview
	script = nil, -- the scripted demo that is running (preview loop or the test), or nil
	testPending = false, -- a test was asked for while the game screen was not up
	ticking = false,
	lastTick = 0,
	lastText = -1,
	bubbleW = 0,
	lines = {},
	-- counted for /pbember status
	raised = 0,
	shown = 0,
	frames = 0,
	feeding = false,
}
A.ember = ember

-- ---------------------------------------------------------------------------------------
-- The moves. Pure functions of time: no game calls, so the offline tests run them on their own.
-- ---------------------------------------------------------------------------------------

local Anim = {}
A.Anim = Anim

local function NewPose()
	return { rot = {}, off = {}, dx = 0, dy = 0, scale = 1, alpha = 1, expression = "idle", fx = {} }
end
Anim.NewPose = NewPose

local function Fx(p, name, x, y, scale, rot, alpha)
	p.fx[name] = { x = x, y = y, scale = scale, rot = rot or 0, alpha = alpha or 1 }
end

-- shared by every mood: the tail sways, the hair follows, an ear flicks now and then
local function Idle(p, t)
	p.rot.tail_a = 0.16 * sin(TAU * t / 1.5)
	p.rot.tail_b = 0.30 * sin(TAU * t / 1.5 - 1.1)
	p.rot.hair_back = -0.04 * sin(TAU * t / 2.2 - 0.5)
	p.rot.hair_front = 0.025 * sin(TAU * t / 2.2 - 0.2)
	local f = (t % 3.3) / 3.3
	if f < 0.07 then
		p.rot.ear_r = -0.35 * sin(pi * f / 0.07)
	end
end

local function Blink(p, t, period)
	if (t % period) < 0.12 then
		p.expression = "blink"
	end
end

-- side: 1 = she stands at the left and the bubble is at her right
local MOODS = {}

function MOODS.alarm(p, t, side)
	Idle(p, t)
	local hop = abs(sin(pi * t / 0.8))
	p.dy = -13 * hop
	p.rot.body = 0.04 * sin(TAU * t / 1.6)
	p.rot.head = 0.06 * sin(TAU * t / 0.8)
	local sd = side == 1 and 1 or -1
	local up, down = side == 1 and "arm_r" or "arm_l", side == 1 and "arm_l" or "arm_r"
	p.rot[up] = sd * (2.0 + 0.2 * sin(TAU * t / 0.45))
	p.rot[down] = -sd * 0.18
	p.expression = "alert"
	Blink(p, t, 2.9)
	Fx(p, "excl1", 95, -12 - 3 * sin(TAU * t / 0.8), 0.7 + 0.07 * sin(TAU * t / 0.4), 0.15 * sin(TAU * t / 0.8))
end

function MOODS.worry(p, t)
	Idle(p, t)
	p.dx = 0.8 * sin(TAU * 11 * t)
	p.rot.body = 0.015 * sin(TAU * 9 * t)
	p.rot.head = -0.07 + 0.03 * sin(TAU * t / 0.85)
	p.rot.ear_l, p.rot.ear_r = 0.45, -0.45
	p.rot.arm_l = 0.5 + 0.06 * sin(TAU * t / 0.7)
	p.rot.arm_r = -0.5 - 0.06 * sin(TAU * t / 0.7 + 1)
	p.rot.tail_a = -0.1 + 0.05 * sin(TAU * t / 1.2)
	p.expression = "worry"
	Blink(p, t, 3.1)
	local ph = (t % 1.4) / 1.4
	Fx(p, "sweat1", 138 - 2 * ph, 62 + 34 * ph, 0.8, 0, sin(pi * ph))
end

function MOODS.panic(p, t)
	Idle(p, t)
	local hop = abs(sin(pi * t / 0.5))
	p.dy = -8 * hop
	p.dx = 1.6 * sin(TAU * 15 * t)
	p.rot.body = 0.03 * sin(TAU * 13 * t)
	p.rot.head = 0.07 * sin(TAU * 9 * t)
	p.rot.arm_r = 2.3 + 0.3 * sin(TAU * t / 0.28)
	p.rot.arm_l = -(2.3 + 0.3 * sin(TAU * t / 0.28 + 1.3))
	p.rot.ear_l, p.rot.ear_r = 0.75, -0.75
	p.rot.tail_a = 0.5 + 0.1 * sin(TAU * 4 * t)
	p.rot.tail_b = 0.3 + 0.2 * sin(TAU * 4 * t - 1)
	p.expression = "panic"
	Fx(p, "excl1", 95, -16 - 2 * sin(TAU * t / 0.5), 0.85 + 0.12 * sin(TAU * t / 0.25), 0.2 * sin(TAU * 6 * t))
	local a, b = (t % 0.9) / 0.9, ((t + 0.45) % 0.9) / 0.9
	Fx(p, "sweat1", 138 - 2 * a, 60 + 30 * a, 0.85, 0, sin(pi * a))
	Fx(p, "sweat2", 52 + 2 * b, 60 + 30 * b, 0.85, 0, sin(pi * b))
end

function MOODS.relief(p, t)
	Idle(p, t)
	local hop = abs(sin(pi * t / 0.6))
	p.dy = -14 * hop
	p.rot.head = 0.08 * sin(TAU * t / 1.2)
	p.rot.arm_r = 2.1 + 0.25 * sin(TAU * t / 0.6)
	p.rot.arm_l = -(2.1 + 0.25 * sin(TAU * t / 0.6 + pi))
	p.expression = "happy"
	local a, b = 0.5 + 0.5 * sin(TAU * t / 0.7), 0.5 + 0.5 * sin(TAU * t / 0.7 + pi)
	Fx(p, "spark1", 30, 46, 0.45 + 0.35 * a, 0.3 * t, a)
	Fx(p, "spark2", 160, 30, 0.45 + 0.35 * b, -0.3 * t, b)
end

function MOODS.sad(p, t)
	Idle(p, t)
	p.rot.head = -0.1 + 0.02 * sin(TAU * t / 1.4)
	p.rot.ear_l, p.rot.ear_r = 0.5, -0.5
	p.rot.arm_l = 0.12
	p.rot.arm_r = -0.12
	p.rot.tail_a = -0.12
	p.expression = "worry"
	Blink(p, t, 2.6)
	local ph = (t % 1.8) / 1.8
	Fx(p, "sweat1", 138 - 2 * ph, 62 + 34 * ph, 0.75, 0, sin(pi * ph))
end

-- The pose of a mood t seconds into its loop.
function Anim.Pose(mood, t, side)
	local p = NewPose()
	local fn = MOODS[mood] or MOODS.alarm
	fn(p, t, side or 1)
	return p
end

-- Pops in with a little overshoot and a hop, and shrinks away.
local function EaseOutBack(x)
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

-- phase "enter" (progress 0..1), "loop", "exit" (progress 0..1) changes the pose in place.
function Anim.Envelope(p, phase, progress)
	if phase == "enter" then
		local x = min(1, max(0, progress))
		p.scale = max(0.05, EaseOutBack(x))
		p.alpha = min(1, x * 2.5)
		p.dy = p.dy - 18 * sin(pi * x)
	elseif phase == "exit" then
		local x = min(1, max(0, progress))
		p.scale = max(0.05, 1 - 0.35 * x * x)
		p.alpha = 1 - x
		p.dy = p.dy + 8 * x
	end
	return p
end

local function Mix(a, b, k)
	return a + (b - a) * k
end

-- Cross-fades two poses: k = 0 is all a, 1 is all b. The expression is the later one's.
function Anim.Lerp(a, b, k)
	if k >= 1 then
		return b
	end
	local p = NewPose()
	for name in pairs(a.rot) do
		p.rot[name] = Mix(a.rot[name], b.rot[name] or 0, k)
	end
	for name in pairs(b.rot) do
		if p.rot[name] == nil then
			p.rot[name] = Mix(0, b.rot[name], k)
		end
	end
	p.dx, p.dy = Mix(a.dx, b.dx, k), Mix(a.dy, b.dy, k)
	p.scale, p.alpha = Mix(a.scale, b.scale, k), Mix(a.alpha, b.alpha, k)
	p.expression = b.expression
	local names = {}
	for name in pairs(a.fx) do
		names[name] = true
	end
	for name in pairs(b.fx) do
		names[name] = true
	end
	for name in pairs(names) do
		local fa, fb = a.fx[name], b.fx[name]
		if fa and fb then
			p.fx[name] = {
				x = Mix(fa.x, fb.x, k), y = Mix(fa.y, fb.y, k), scale = Mix(fa.scale, fb.scale, k),
				rot = Mix(fa.rot, fb.rot, k), alpha = Mix(fa.alpha, fb.alpha, k),
			}
		elseif fb then
			p.fx[name] = { x = fb.x, y = fb.y, scale = fb.scale, rot = fb.rot, alpha = fb.alpha * k }
		else
			p.fx[name] = { x = fa.x, y = fa.y, scale = fa.scale, rot = fa.rot, alpha = fa.alpha * (1 - k) }
		end
	end
	return p
end

-- ---------------------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------------------

local view = {} -- the controls

local function Unit()
	local size = A.sv and A.sv.size or 100
	local u = size / 100
	if ember.preview then
		u = min(u, PREVIEW_UNIT_MAX)
	end
	return u
end

local function Side()
	if ember.preview then
		return 2
	end
	return A.sv and A.sv.side or 1
end

local function FontFor()
	local size = A.sv and A.sv.size or 100
	for _, row in ipairs(FONTS) do
		if size <= row.upTo then
			return row
		end
	end
	return FONTS[#FONTS]
end

local function Controls()
	if view.window then
		return view.window
	end
	local window = _G[WINDOW_NAME]
	if not window then
		return nil
	end
	view.window = window
	return window
end

-- Anchors the window at its place and sizes it to the figure. The bubble hangs beside it.
function A:ApplyLayout()
	local window = Controls()
	if not (window and view.puppet) then
		return false
	end
	local unit = Unit()
	local w, h = G.canvas.w * unit, G.canvas.h * unit
	window:SetDimensions(w, h)
	window:ClearAnchors()
	if ember.preview then
		window:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, -PREVIEW_ANCHOR.x, -PREVIEW_ANCHOR.y)
	elseif Side() == 1 then
		window:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, A.sv.posX, -A.sv.posY)
	else
		window:SetAnchor(BOTTOMRIGHT, GuiRoot, BOTTOMRIGHT, -A.sv.posX, -A.sv.posY)
	end
	view.stage:ClearAnchors()
	view.stage:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 0)
	view.stage:SetDimensions(w, h)
	ember.lastText = -1 -- the bubble is laid out again at the next tick
	ember.bubbleW = 0
	if ember.phase ~= "hidden" then
		A:EmberRender(0)
	end
	return true
end

-- ---------------------------------------------------------------------------------------
-- The speech bubble: nine pieces cut from one tile, a tail, up to three icons and three lines of text
-- ---------------------------------------------------------------------------------------

local SLICES = {
	{ "tl", 0, 0 }, { "t", 1, 0 }, { "tr", 2, 0 },
	{ "l", 0, 1 }, { "c", 1, 1 }, { "r", 2, 1 },
	{ "bl", 0, 2 }, { "b", 1, 2 }, { "br", 2, 2 },
}

local function BuildBubble(window, stage)
	local tile = G.parts.bubble
	local du, dv = (tile.u1 - tile.u0) / 3, (tile.v1 - tile.v0) / 3
	view.slices = {}
	for _, row in ipairs(SLICES) do
		local name, ci, ri = row[1], row[2], row[3]
		local c = WINDOW_MANAGER:CreateControl(WINDOW_NAME .. "Bubble" .. name, stage, CT_TEXTURE)
		c:SetTexture(G.atlas)
		c:SetTextureCoords(tile.u0 + ci * du, tile.u0 + (ci + 1) * du, tile.v0 + ri * dv, tile.v0 + (ri + 1) * dv)
		c:SetDrawLayer(DL_CONTROLS)
		c:SetDrawLevel(40)
		c:SetMouseEnabled(false)
		c:SetHidden(true)
		view.slices[name] = c
	end
	local tail = G.parts.bubble_tail
	view.tail = WINDOW_MANAGER:CreateControl(WINDOW_NAME .. "BubbleTail", stage, CT_TEXTURE)
	view.tail:SetTexture(G.atlas)
	view.tail:SetTextureCoords(tail.u0, tail.u1, tail.v0, tail.v1)
	view.tail:SetDrawLayer(DL_CONTROLS)
	view.tail:SetDrawLevel(40)
	view.tail:SetMouseEnabled(false)
	view.tail:SetHidden(true)
	view.icons = {}
	view.labels = {}
	for i = 1, MAX_LINES do
		local icon = WINDOW_MANAGER:CreateControl(WINDOW_NAME .. "Icon" .. i, stage, CT_TEXTURE)
		icon:SetTexture(G.atlas)
		icon:SetDrawLayer(DL_CONTROLS)
		icon:SetDrawLevel(45)
		icon:SetMouseEnabled(false)
		icon:SetHidden(true)
		view.icons[i] = icon
		-- the text is in the stage too, on the text layer, so it is always above the bubble's pieces
		local label = WINDOW_MANAGER:CreateControl(WINDOW_NAME .. "Line" .. i, stage, CT_LABEL)
		label:SetDrawLayer(DL_TEXT)
		label:SetMouseEnabled(false)
		label:SetFont(FONTS[2].font)
		label:SetColor(1, 1, 1, 1)
		label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
		label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
		label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
		label:SetMaxLineCount(1)
		label:SetHidden(true)
		view.labels[i] = label
	end
end

local function BubbleHidden(hidden)
	if not view.slices then
		return
	end
	for _, c in pairs(view.slices) do
		c:SetHidden(hidden)
	end
	view.tail:SetHidden(hidden)
	if hidden then
		for i = 1, MAX_LINES do
			view.icons[i]:SetHidden(true)
			view.labels[i]:SetHidden(true)
		end
	end
end

local function SetBubbleAlpha(alpha)
	if view.bubbleAlpha == alpha then
		return
	end
	view.bubbleAlpha = alpha
	for _, c in pairs(view.slices) do
		c:SetAlpha(alpha)
	end
	view.tail:SetAlpha(alpha)
	for i = 1, MAX_LINES do
		view.icons[i]:SetAlpha(alpha)
		view.labels[i]:SetAlpha(alpha)
	end
end

local function Put(c, x, y, w, h)
	c:ClearAnchors()
	c:SetAnchor(TOPLEFT, view.stage, TOPLEFT, x, y)
	c:SetDimensions(w, h)
end

-- What a reason says, and how it looks.
local function NameOf(reason)
	local data = reason.data or {}
	if data.name and data.name ~= "" then
		return data.name
	end
	if reason.kind == "minor" then
		return S.minorName
	elseif reason.kind == "brutal" then
		return S.brutalName
	end
	return S.majorName
end

function A.LineText(reason, now)
	local data = reason.data or {}
	if reason.state == "relief" then
		return S.lineRelief
	elseif reason.state == "lost" then
		return string.format(S.lineLost, NameOf(reason))
	elseif reason.kind == "major" or reason.kind == "minor" or reason.kind == "brutal" then
		local left = data.endTime and (data.endTime - now) or 0
		return string.format(S.lineExpiring, NameOf(reason), max(0, left))
	elseif reason.kind == "danger" then
		return string.format(S.lineDanger, data.pct or 0)
	end
	return string.format(S.lineHp, data.pct or 0)
end

-- The reasons in the order they are shown: most urgent first, at most MAX_LINES.
function A:EmberLines()
	local list = {}
	for _, reason in pairs(ember.reasons) do
		list[#list + 1] = reason
	end
	table.sort(list, function(a, b)
		local pa, pb = PRIORITY[a.kind] or 9, PRIORITY[b.kind] or 9
		if pa ~= pb then
			return pa < pb
		end
		return a.since < b.since
	end)
	while #list > MAX_LINES do
		table.remove(list)
	end
	return list
end

-- Lays the bubble out for the lines it has now. Returns false when there is nothing to show.
local function LayoutBubble(now)
	local lines = A:EmberLines()
	ember.lines = lines
	if #lines == 0 or not A.sv.bubble then
		return false
	end
	local row = FontFor()
	local pad = row.pad
	local iconSize = row.line - 6
	local textW = 0
	for i = 1, MAX_LINES do
		local label = view.labels[i]
		local reason = lines[i]
		if reason then
			label:SetFont(row.font)
			label:SetDimensions(900, row.line)
			label:SetText(A.LineText(reason, now))
			local ok, width = pcall(label.GetTextWidth, label)
			if ok and type(width) == "number" then
				textW = max(textW, width)
			else
				textW = max(textW, 340)
			end
		end
	end
	local needed = textW + 2 * pad + iconSize + ICON_GAP + 4
	ember.bubbleW = max(ember.bubbleW, needed, BUBBLE_MIN_W)
	local bw = ember.bubbleW
	local bh = #lines * row.line + 2 * pad
	local unit = Unit()
	local headY = 86 * unit
	local side = Side()
	local x0
	if side == 1 then
		x0 = G.canvas.w * unit + TAIL_W - 2
	else
		x0 = -(TAIL_W - 2) - bw
	end
	local y0 = headY - bh / 2
	local c = BUBBLE_CORNER
	local sl = view.slices
	Put(sl.tl, x0, y0, c, c)
	Put(sl.t, x0 + c, y0, bw - 2 * c, c)
	Put(sl.tr, x0 + bw - c, y0, c, c)
	Put(sl.l, x0, y0 + c, c, bh - 2 * c)
	Put(sl.c, x0 + c, y0 + c, bw - 2 * c, bh - 2 * c)
	Put(sl.r, x0 + bw - c, y0 + c, c, bh - 2 * c)
	Put(sl.bl, x0, y0 + bh - c, c, c)
	Put(sl.b, x0 + c, y0 + bh - c, bw - 2 * c, c)
	Put(sl.br, x0 + bw - c, y0 + bh - c, c, c)
	local tail = G.parts.bubble_tail
	if side == 1 then
		view.tail:SetTextureCoords(tail.u0, tail.u1, tail.v0, tail.v1)
		Put(view.tail, x0 - TAIL_W + 2, headY - TAIL_H / 2, TAIL_W, TAIL_H)
	else
		view.tail:SetTextureCoords(tail.u1, tail.u0, tail.v0, tail.v1)
		Put(view.tail, x0 + bw - 2, headY - TAIL_H / 2, TAIL_W, TAIL_H)
	end
	for i = 1, MAX_LINES do
		local reason = lines[i]
		local label, icon = view.labels[i], view.icons[i]
		if reason then
			local ty = y0 + pad + (i - 1) * row.line
			local shown = reason.state == "active" and reason.kind or reason.state
			local color = LINE_COLOR[shown] or LINE_COLOR.hp
			local iconName = reason.state == "active" and LINE_ICON[reason.kind] or nil
			local lx = x0 + pad
			if iconName then
				local part = G.parts[iconName]
				icon:SetTextureCoords(part.u0, part.u1, part.v0, part.v1)
				Put(icon, lx, ty + (row.line - iconSize) / 2, iconSize * part.w / part.h, iconSize)
				icon:SetHidden(false)
				lx = lx + iconSize + ICON_GAP
			else
				icon:SetHidden(true)
				lx = lx + 2
			end
			label:ClearAnchors()
			label:SetAnchor(TOPLEFT, view.stage, TOPLEFT, lx, ty)
			label:SetDimensions(x0 + bw - pad - lx, row.line)
			label:SetColor(color[1], color[2], color[3], 1)
			label:SetHidden(false)
		else
			icon:SetHidden(true)
			label:SetHidden(true)
		end
	end
	return true
end

-- Refreshes only the text of the lines (the numbers change; the layout does not).
local function RefreshText(now)
	for i, reason in ipairs(ember.lines) do
		local label = view.labels[i]
		if label and not label:IsHidden() then
			label:SetText(A.LineText(reason, now))
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- The director
-- ---------------------------------------------------------------------------------------

local function PlaySoundFor(name)
	if not A.sv.sound then
		return
	end
	-- the form that is proven on a console: look the id up, and play it only when it is there
	local id = SOUNDS and SOUNDS[SOUND_NAME[name]]
	if id and PlaySound then
		pcall(PlaySound, id)
	end
end

-- Whether Watch.lua may speak: not while the preview is on (it has its own reasons) and not when switched off.
local function Accepts()
	return A.sv and A.sv.enabled and (ember.feeding or not ember.preview)
end

function A:ReasonState(kind)
	local r = ember.reasons[kind]
	return r and r.state or nil
end

function A:Raise(kind, data)
	if not PRIORITY[kind] or not Accepts() then
		return nil
	end
	local now = A.Now()
	local r = ember.reasons[kind]
	if r and r.state == "active" then
		r.data = data or r.data
		return r
	end
	r = { kind = kind, state = "active", since = now, expire = now + A.sv.hold, data = data or {} }
	ember.reasons[kind] = r
	ember.raised = ember.raised + 1
	ember.lastText = -1 -- the bubble is laid out again for the new line
	PlaySoundFor(kind)
	self:EmberUpdateState()
	return r
end

-- It ended: "relief" (fine again) or "lost" (ran out). Only for a reason that is still alive.
function A:Settle(kind, state)
	local r = ember.reasons[kind]
	if not r or r.state ~= "active" then
		return
	end
	r.state = state
	r.expire = A.Now() + (state == "lost" and LOST_S or RELIEF_S)
	if state == "relief" then
		PlaySoundFor("relief")
	end
	ember.lastText = -1
end

function A:Withdraw(kind)
	if ember.reasons[kind] then
		ember.reasons[kind] = nil
		ember.lastText = -1
	end
end

function A:ClearReasons()
	ember.reasons = {}
	ember.lastText = -1
end

local function MoodNow()
	local best, bestRank
	for kind, r in pairs(ember.reasons) do
		if r.state == "active" and PRIORITY[kind] and (not bestRank or PRIORITY[kind] < bestRank) then
			best, bestRank = MOOD_OF[kind], PRIORITY[kind]
		end
	end
	if best then
		return best
	end
	local relief, lost = false, false
	for _, r in pairs(ember.reasons) do
		relief = relief or r.state == "relief"
		lost = lost or r.state == "lost"
	end
	if relief then
		return "relief"
	elseif lost then
		return "sad"
	end
	return nil
end

local function Hide()
	if view.puppet then
		view.puppet:HideAll()
	end
	if view.slices then
		BubbleHidden(true)
	end
	ember.bubbleW = 0
	ember.lastText = -1
end

function A:EmberRender(dt)
	local now = A.Now()
	local unit = Unit()
	local side = Side()
	local mood = ember.mood
	local clock = ember.clock
	local pose = Anim.Pose(mood, clock, side)
	if ember.blend < 1 and ember.prevMood then
		local before = Anim.Pose(ember.prevMood, ember.prevClock, side)
		pose = Anim.Lerp(before, pose, ember.blend)
	end
	local phase, progress = ember.phase, 1
	if phase == "enter" then
		progress = ember.t / ENTER_S
	elseif phase == "exit" then
		progress = ember.t / EXIT_S
	end
	Anim.Envelope(pose, phase, progress)
	view.puppet:Apply(pose, unit)
	view.puppet:ApplyFx(pose, unit)

	-- the bubble: laid out when the reasons change, its text refreshed a few times a second
	local bubbleAlpha = 0
	if phase == "loop" then
		bubbleAlpha = 1
	elseif phase == "enter" then
		bubbleAlpha = min(1, max(0, (ember.t - 0.12) / 0.25))
	elseif phase == "exit" then
		bubbleAlpha = max(0, 1 - progress * 2)
	end
	if bubbleAlpha > 0 and A.sv.bubble then
		if ember.lastText < 0 then
			if LayoutBubble(now) then
				BubbleHidden(false)
			else
				BubbleHidden(true)
			end
			ember.lastText = now
		elseif now - ember.lastText >= TEXT_EVERY then
			RefreshText(now)
			ember.lastText = now
		end
		SetBubbleAlpha(bubbleAlpha)
	elseif view.slices then
		BubbleHidden(true)
	end
end

local function Advance(dt, now)
	-- reasons that have been on screen long enough go
	for kind, r in pairs(ember.reasons) do
		if r.expire <= now then
			ember.reasons[kind] = nil
			ember.lastText = -1
		end
	end
	local alive = next(ember.reasons) ~= nil
	local mood = MoodNow()
	if mood and mood ~= ember.mood then
		if ember.phase ~= "hidden" then
			ember.prevMood, ember.prevClock, ember.blend = ember.mood, ember.clock, 0
		end
		ember.mood = mood
	end
	local phase = ember.phase
	if alive then
		if phase == "hidden" then
			ember.phase, ember.t, ember.clock, ember.blend = "enter", 0, 0, 1
			ember.shown = ember.shown + 1
			ember.lastText = -1
		elseif phase == "exit" then
			ember.phase, ember.t = "enter", ENTER_S * 0.4
		end
	elseif phase == "enter" or phase == "loop" then
		ember.phase, ember.t = "exit", 0
	end
	ember.t = ember.t + dt
	ember.clock = ember.clock + dt
	if ember.blend < 1 then
		ember.blend = min(1, ember.blend + dt / BLEND_S)
		ember.prevClock = ember.prevClock + dt
	end
	if ember.phase == "enter" and ember.t >= ENTER_S then
		ember.phase, ember.t = "loop", 0
	elseif ember.phase == "exit" and ember.t >= EXIT_S then
		ember.phase, ember.t = "hidden", 0
		Hide()
	end
end

-- ---------------------------------------------------------------------------------------
-- The scripted demo: the preview loop, and the test
-- ---------------------------------------------------------------------------------------

-- Times are seconds from the start. Each step runs once. "at" below is in the order they happen.
local SCRIPT = {
	period = 17.5,
	steps = {
		{ 0.0, function(now)
			A:Raise("major", { name = S.majorName, endTime = now + 3.4 })
			A:Raise("minor", { name = S.minorName, endTime = now + 4.5 })
			A:Raise("brutal", { name = S.brutalName, endTime = now + 4.0 })
		end },
		{ 3.5, function() A:Settle("major", "lost") end },
		{ 4.1, function() A:Settle("brutal", "lost") end },
		{ 4.6, function() A:Settle("minor", "lost") end },
		{ 7.4, function() A:Raise("hp", { pct = 66 }) end },
		{ 9.0, function() A:Raise("hp", { pct = 61 }) end },
		{ 10.2, function() A:Withdraw("hp") A:Raise("danger", { pct = 31 }) end },
		{ 12.8, function() A:Settle("danger", "relief") end },
	},
}

local function ScriptStart(loop)
	ember.script = { start = A.Now(), index = 1, loop = loop, last = 0 }
end

local function ScriptStep(now)
	local sc = ember.script
	if not sc then
		return
	end
	local t = now - sc.start
	ember.feeding = true
	while SCRIPT.steps[sc.index] and SCRIPT.steps[sc.index][1] <= t do
		-- a step is run with the time it was due, so a slow frame does not shorten a countdown
		local ok, err = pcall(SCRIPT.steps[sc.index][2], sc.start + SCRIPT.steps[sc.index][1])
		if not ok then
			A.errors = A.errors + 1
			A.lastError = "demo: " .. tostring(err)
		end
		sc.index = sc.index + 1
	end
	ember.feeding = false
	if sc.index > #SCRIPT.steps and t >= SCRIPT.period then
		if sc.loop then
			sc.start, sc.index = now, 1
		else
			ember.script = nil
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- The tick
-- ---------------------------------------------------------------------------------------

local function Tick()
	local now = A.Now()
	local dt = now - ember.lastTick
	ember.lastTick = now
	if dt < 0 then
		dt = 0
	elseif dt > MAX_STEP then
		dt = MAX_STEP
	end
	if ember.hud or ember.preview then
		ScriptStep(now)
		Advance(dt, now)
		if ember.phase ~= "hidden" then
			ember.frames = ember.frames + 1
			A:EmberRender(dt)
		end
	end
	A:EmberUpdateState()
end

local function Reset()
	ember.reasons = {}
	ember.phase, ember.t = "hidden", 0
	ember.script = nil
	Hide()
end

-- A tick that raises would raise again 33 ms later, and so on. Whatever went wrong, she is sent away (the next
-- alert starts clean) and the error is counted for /pbember status.
local function SafeTick()
	local ok, err = pcall(Tick)
	if not ok then
		A.errors = A.errors + 1
		A.lastError = "ember: " .. tostring(err)
		pcall(Reset)
		pcall(A.EmberUpdateState, A)
	end
end

-- The update runs only while she is on screen or something waits for her, on the game screen (or the preview).
function A:EmberUpdateState()
	local up = ember.hud or ember.preview
	local want = up and (ember.phase ~= "hidden" or next(ember.reasons) ~= nil or ember.script ~= nil)
	if want and not ember.ticking then
		ember.ticking = true
		ember.lastTick = A.Now()
		em:RegisterForUpdate(TICK_NAME, TICK_MS, SafeTick)
	elseif not want and ember.ticking then
		ember.ticking = false
		em:UnregisterForUpdate(TICK_NAME)
	end
end

-- ---------------------------------------------------------------------------------------
-- The preview, the test, the switch
-- ---------------------------------------------------------------------------------------

function A:SetPreview(on)
	on = on and A.sv.preview and A.sv.enabled and true or false
	if ember.preview == on then
		return
	end
	local window = Controls()
	ember.preview = on
	if not window then
		return
	end
	Reset()
	ember.script = nil
	if on then
		window:SetHidden(false)
		ScriptStart(true)
	else
		window:SetHidden(not ember.hud)
	end
	self:ApplyLayout()
	self:EmberUpdateState()
end

-- Plays every alert once on the game screen.
function A:StartTest()
	if ember.preview then
		return false
	end
	if not ember.hud then
		ember.testPending = true
		return false
	end
	ember.testPending = false
	ScriptStart(false)
	self:EmberUpdateState()
	return true
end

-- Called when the switch changes: off sends her away at once.
function A:ApplyEnabled()
	if not A.sv.enabled then
		Reset()
		self:EmberUpdateState()
	end
end

-- ---------------------------------------------------------------------------------------
-- Start-up
-- ---------------------------------------------------------------------------------------

function A:InitEmber()
	local window = Controls()
	if not window then
		error("the window is missing: PBsEmber.xml did not load")
	end
	if not (ZO_SimpleSceneFragment and HUD_SCENE and HUD_UI_SCENE) then
		error("the game screen's scenes are not there")
	end
	view.puppet = A.Puppet.New(window, WINDOW_NAME)
	view.stage = view.puppet.stage
	BuildBubble(window, view.stage)
	self:ApplyLayout()
	local fragment = ZO_SimpleSceneFragment:New(window)
	ember.fragment = fragment
	fragment:RegisterCallback("StateChange", function(_, newState)
		if newState == SCENE_FRAGMENT_SHOWN then
			ember.hud = true
			if ember.testPending then
				A:StartTest()
			end
		elseif newState == SCENE_FRAGMENT_HIDING or newState == SCENE_FRAGMENT_HIDDEN then
			ember.hud = false
		end
		A:EmberUpdateState()
	end)
	HUD_SCENE:AddFragment(fragment)
	HUD_UI_SCENE:AddFragment(fragment)
end

PBS_EMBER_MARK("Ember")
