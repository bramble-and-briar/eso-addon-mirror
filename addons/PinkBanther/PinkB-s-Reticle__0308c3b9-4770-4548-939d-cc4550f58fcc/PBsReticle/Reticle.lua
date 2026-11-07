-- One drawn reticle: its textures, where they sit, what colour they are, and how they move.
--
-- Console-safe on purpose: plain textures only (no fonts, no templates, nothing that takes input), and
-- nothing is hooked. The game's own reticle is only ever asked to be see-through (Main.lua).
--
-- The same class draws the live reticle (a child of the game's reticle container, so the game decides when
-- it is shown) and the preview on the settings screen (its own window). Both are driven by a "source": the
-- live one reads the game, the preview plays a script.
--
-- Cost: while nothing moves, a frame costs one comparison and, thirty times a second, a few cheap reads
-- of the game's state. Controls are touched only when a value actually changed, and only while something
-- is settling (a target arrived, a hit flashed, the opacity eased).
local A = PBS_RETICLE
local SH = PBS_RETICLE_SHAPES

local PATH = "PBsReticle/assets/"
local POLL_S = 0.03 -- how often the game is asked what is under the reticle
local POSE_RATE = 16 -- per second: the pose covers most of its way in a tenth of a second
local COLOR_RATE = 14
local ALPHA_RATE = 7
local PULSE_DECAY = 4
local EPS = 0.004
local MAX_ERRORS = 3
local GOOD_FRAMES = 30 -- frames without an error before the error count starts over
local RESUME_S = 0.5 -- a gap this long between frames means the reticle was hidden: snap to the state

local floor, abs, exp, max, min = math.floor, math.abs, math.exp, math.max, math.min
local pi = math.pi

local FILES = { dot = "dot", prismDot = "prism_dot", prism = "prism", ring = "ring", orbit = "orbit", armH = "arm_h", armV = "arm_v", bracket = "brk", hit = "hit" }
local WEIGHTED = { prism = true, ring = true, orbit = true, armH = true, armV = true, bracket = true }

local function texturePath(shape, weight, outline)
	local name = FILES[shape]
	if WEIGHTED[shape] then
		name = name .. "_" .. weight
	end
	return PATH .. name .. (outline and "_o" or "") .. ".dds"
end

-- the four brackets: which corner, and how far the texture (an L drawn at the top left) is turned. A
-- positive rotation is counter-clockwise, so a clockwise quarter is negative.
local CORNERS = {
	{ sx = -1, sy = -1, rot = 0 },
	{ sx = 1, sy = -1, rot = -pi / 2 },
	{ sx = 1, sy = 1, rot = -pi },
	{ sx = -1, sy = 1, rot = -pi * 1.5 },
}

-- Half a pixel is as fine as the screen shows.
local function q(v)
	return floor(v * 2 + 0.5) / 2
end

local R = {}
R.__index = R
A.Reticle = R

-- name: unique prefix for the control names. parent/anchorTo: where the root sits (the live one hangs on
-- the game's container, the preview on its own window). layer/level: where it draws within its tier.
function A.NewReticle(name, parent, anchorTo, offsetY, layer, level)
	local self = setmetatable({ name = name }, R)
	local root = WINDOW_MANAGER:CreateControl(name .. "Root", parent, CT_CONTROL)
	root:SetMouseEnabled(false)
	root:SetDimensions(2, 2)
	root:SetAnchor(CENTER, anchorTo or parent, CENTER, 0, offsetY or 0)
	self.root = root
	self.layer, self.level = layer or DL_CONTROLS, level or 0

	self.pose, self.poseT = 0, 0
	self.pulse = 0
	self.rgb, self.rgbT = { 1, 1, 1 }, { 1, 1, 1 }
	self.alpha, self.alphaT = 1, 1
	self.nextPoll = 0
	self.errors, self.goodFrames = 0, 0
	self.frames, self.polls, self.steps = 0, 0, 0
	self.kind = "none"
	self.shown = {}
	self.busy = true

	local function element(key, haloLevel)
		local halo = WINDOW_MANAGER:CreateControl(name .. key .. "O", root, CT_TEXTURE)
		local core = WINDOW_MANAGER:CreateControl(name .. key, root, CT_TEXTURE)
		for _, c in ipairs({ halo, core }) do
			c:SetMouseEnabled(false)
			c:SetDrawLayer(self.layer)
			c:SetHidden(true)
		end
		halo:SetDrawLevel(self.level + haloLevel)
		core:SetDrawLevel(self.level + haloLevel + 1)
		return { halo = halo, core = core, hidden = true, rot = 0 }
	end
	self.dotEl = element("Dot", 0)
	self.prismEl = element("Prism", 0)
	self.ringEl = element("Ring", 0)
	self.orbitEl = element("Orbit", 0)
	self.armR, self.armL = element("ArmR", 0), element("ArmL", 0)
	self.armD, self.armU = element("ArmD", 0), element("ArmU", 0)
	self.brk = { element("BrkA", 0), element("BrkB", 0), element("BrkC", 0), element("BrkD", 0) }
	self.hitEl = element("Hit", 2)
	self.hitEl.core:SetTexture(texturePath("hit", nil, false))
	self.hitEl.halo:SetTexture(texturePath("hit", nil, true))
	self.hitEl.shape = "hit"

	root:SetHandler("OnUpdate", function(_, t)
		self:OnUpdate(t)
	end)
	return self
end

-- ---------------------------------------------------------------------------------------
-- Layout: everything that depends on the settings
-- ---------------------------------------------------------------------------------------

local function setHidden(el, hidden)
	if el.hidden ~= hidden then
		el.hidden = hidden
		el.core:SetHidden(hidden)
		if hidden then
			el.halo:SetHidden(true)
		end
		el.haloOn = nil
	end
end

function R:Layout()
	local sv = A.sv
	self.sv = sv
	local preset = A.PRESETS[sv.style] or A.PRESETS.prism
	self.preset = preset
	local weight = sv.weight
	self.s = sv.size / 100
	self.outlineAlpha = sv.outline / 100
	local shown = {}
	self.shown = shown

	local function use(el, shape, on)
		if on then
			if el.shape ~= shape or el.weight ~= weight then
				el.core:SetTexture(texturePath(shape, weight, false))
				el.halo:SetTexture(texturePath(shape, weight, true))
				el.shape, el.weight = shape, weight
			end
			shown[#shown + 1] = el
		end
		setHidden(el, not on)
	end
	use(self.dotEl, preset.dotShape or "dot", A.ShowDot(sv, preset))
	use(self.prismEl, "prism", preset.prism ~= nil)
	use(self.ringEl, "ring", preset.ring ~= nil)
	use(self.orbitEl, "orbit", preset.orbit ~= nil)
	local arms = preset.arms ~= nil
	use(self.armR, "armH", arms)
	use(self.armL, "armH", arms)
	use(self.armD, "armV", arms)
	use(self.armU, "armV", arms)
	for _, el in ipairs(self.brk) do
		use(el, "bracket", preset.brackets ~= nil)
	end

	-- The outline: a black copy under each core, as strong as the setting says; none at all at zero.
	local outline = self.outlineAlpha
	for _, el in ipairs(shown) do
		self:SetOutline(el, outline)
	end
	self:SetOutline(self.hitEl, outline)

	self.placeDirty, self.paintDirty = true, true
	self.busy = true
end

function R:SetOutline(el, alpha)
	local on = alpha > 0 and not el.hidden
	if el.haloOn ~= on or el.haloAlpha ~= alpha then
		el.halo:SetHidden(not on)
		if on then
			el.halo:SetColor(0, 0, 0, alpha)
		end
		el.haloOn, el.haloAlpha = on, alpha
	end
end

-- ---------------------------------------------------------------------------------------
-- Placing
-- ---------------------------------------------------------------------------------------

function R:Put(el, x, y, w, h, rot)
	x, y, w, h = q(x), q(y), q(w), q(h)
	local root = self.root
	if el.x ~= x or el.y ~= y then
		el.halo:ClearAnchors()
		el.halo:SetAnchor(CENTER, root, CENTER, x, y)
		el.core:ClearAnchors()
		el.core:SetAnchor(CENTER, root, CENTER, x, y)
		el.x, el.y = x, y
	end
	if el.w ~= w or el.h ~= h then
		el.halo:SetDimensions(w, h)
		el.core:SetDimensions(w, h)
		el.w, el.h = w, h
	end
	if abs(rot - el.rot) > 0.0005 then
		el.halo:SetTextureRotation(rot, 0.5, 0.5)
		el.core:SetTextureRotation(rot, 0.5, 0.5)
		el.rot = rot
	end
end

function R:Place()
	local sv, preset, s, pose = self.sv, self.preset, self.s, self.pose
	if not self.dotEl.hidden then
		local k = A.DotCore(sv, preset, pose) / SH.dot.core * s
		self:Put(self.dotEl, 0, 0, SH.dot.w * k, SH.dot.h * k, 0)
	end
	if preset.prism then
		local k = A.RingScale(pose, self.pulse) * s
		self:Put(self.prismEl, 0, 0, SH.prism.w * k, SH.prism.h * k, 0)
	end
	if preset.arms then
		local length = preset.arms.length or 1
		local c = (A.ArmInner(sv, preset, pose) + SH.armH.len * length / 2) * s
		self:Put(self.armR, c, 0, SH.armH.w * length * s, SH.armH.h * s, 0)
		self:Put(self.armL, -c, 0, SH.armH.w * length * s, SH.armH.h * s, 0)
		self:Put(self.armD, 0, c, SH.armV.w * s, SH.armV.h * length * s, 0)
		self:Put(self.armU, 0, -c, SH.armV.w * s, SH.armV.h * length * s, 0)
	end
	if preset.ring then
		local k = preset.ring.r / SH.ring.r * A.RingScale(pose, self.pulse) * s
		self:Put(self.ringEl, 0, 0, SH.ring.w * k, SH.ring.h * k, 0)
	end
	if preset.orbit then
		local k = preset.orbit.r / SH.orbit.r * A.RingScale(pose, self.pulse) * s
		self:Put(self.orbitEl, 0, 0, SH.orbit.w * k, SH.orbit.h * k, A.OrbitTurn(pose, preset.orbit))
	end
	if preset.brackets then
		local half = A.BracketHalf(sv, preset, pose)
		-- the L's corner sits (w/2 - cx) from the middle of its own canvas
		local e = SH.bracket.w / 2 - SH.bracket.cx
		for i, corner in ipairs(CORNERS) do
			self:Put(self.brk[i], corner.sx * (half - e) * s, corner.sy * (half - e) * s,
				SH.bracket.w * s, SH.bracket.h * s, corner.rot)
		end
	end
end

function R:Paint()
	local r, g, b = self.rgb[1], self.rgb[2], self.rgb[3]
	local shown = self.shown
	for i = 1, #shown do
		shown[i].core:SetColor(r, g, b, 1)
	end
end

-- ---------------------------------------------------------------------------------------
-- The hit marker: four ticks that pop out and fade; a kill is bigger and red
-- ---------------------------------------------------------------------------------------

function R:Hit(kind, now)
	local look = A.HIT_LOOK[kind]
	if not look or not self.sv then
		return
	end
	local current = self.hit
	-- a lesser hit does not cut short a crit or a kill that is still on its way
	if self.hitActive and look.rank < current.look.rank and now - current.t0 < current.look.duration * 0.6 then
		return
	end
	current = current or {}
	current.kind, current.look, current.t0 = kind, look, now
	self.hit = current
	local c = A.HIT_COLORS[kind]
	self.hitEl.core:SetColor(c[1], c[2], c[3], 1)
	self.hitActive = true
	if self.sv.anim then
		self.pulse = max(self.pulse, look.pulse)
		self.placeDirty = true
	end
	self.busy = true
end

local function easeOut(p)
	return 1 - (1 - p) * (1 - p)
end

function R:StepHit(now)
	local el, h, sv = self.hitEl, self.hit, self.sv
	-- the event may carry a frame time a hair ahead of this frame's
	local p = max(0, (now - h.t0) / h.look.duration)
	if p >= 1 then
		self.hitActive = false
		setHidden(el, true)
		el.fade = nil
		return
	end
	local scale = sv.anim and (h.look.from + (h.look.to - h.look.from) * easeOut(p)) or (h.look.from + h.look.to) / 2
	local fade = p < 0.35 and 1 or 1 - ((p - 0.35) / 0.65) ^ 2
	setHidden(el, false)
	self:SetOutline(el, self.outlineAlpha)
	self:Put(el, 0, 0, SH.hit.w * scale * self.s, SH.hit.h * scale * self.s, 0)
	fade = floor(fade * 50 + 0.5) / 50
	if el.fade ~= fade then
		el.core:SetAlpha(fade)
		el.halo:SetAlpha(fade)
		el.fade = fade
	end
end

-- ---------------------------------------------------------------------------------------
-- Following the game, and settling
-- ---------------------------------------------------------------------------------------

-- What is under the reticle, from the source: the game for the live reticle, a script for the preview.
function R:Poll(t)
	local sv = self.sv
	self.polls = self.polls + 1
	local kind, engaged
	if self.source then
		kind, engaged = self.source(self, t)
	else
		kind, engaged = A.ReadWorld()
	end
	self.kind = kind
	local look = A.LOOKS[kind] or A.LOOKS.none

	local poseT = sv.anim and look.pose or 0
	if poseT ~= self.poseT then
		self.poseT = poseT
		self.busy = true
	end

	local c = (sv.auto and look.color) or A.COLORS[sv.color]
	local rgbT = self.rgbT
	if rgbT[1] ~= c[1] or rgbT[2] ~= c[2] or rgbT[3] ~= c[3] then
		rgbT[1], rgbT[2], rgbT[3] = c[1], c[2], c[3]
		self.busy = true
	end

	-- gone while the game shows its own stealth eye in the middle
	local alphaT = 0
	if not (self.mirror and self.mirror()) then
		alphaT = sv.opacity / 100 * (engaged and 1 or sv.idle / 100)
	end
	if alphaT ~= self.alphaT then
		self.alphaT = alphaT
		self.busy = true
	end
end

function R:Snap()
	self.pose, self.pulse = self.poseT, 0
	self.rgb[1], self.rgb[2], self.rgb[3] = self.rgbT[1], self.rgbT[2], self.rgbT[3]
	self.alpha = self.alphaT
	self.placeDirty, self.paintDirty = true, true
	self.busy = true
end

local function approach(value, target, k)
	if value == target then
		return value
	end
	value = value + (target - value) * k
	if abs(target - value) < EPS then
		return target
	end
	return value
end

function R:Step(dt, t)
	self.steps = self.steps + 1
	local anim = self.sv.anim
	local settled = true

	if self.pose ~= self.poseT then
		self.pose = approach(self.pose, self.poseT, anim and 1 - exp(-dt * POSE_RATE) or 1)
		self.placeDirty = true
		settled = settled and self.pose == self.poseT
	end
	if self.pulse > 0 then
		self.pulse = max(0, self.pulse - dt * PULSE_DECAY)
		self.placeDirty = true
		settled = settled and self.pulse == 0
	end

	local kc = 1 - exp(-dt * COLOR_RATE)
	local rgb, rgbT = self.rgb, self.rgbT
	for i = 1, 3 do
		if rgb[i] ~= rgbT[i] then
			rgb[i] = approach(rgb[i], rgbT[i], kc)
			self.paintDirty = true
			settled = settled and rgb[i] == rgbT[i]
		end
	end

	if self.alpha ~= self.alphaT then
		self.alpha = approach(self.alpha, self.alphaT, 1 - exp(-dt * ALPHA_RATE))
		settled = settled and self.alpha == self.alphaT
	end
	-- one percent is as fine as the eye sees; a snap lands here too, so it is applied whenever it differs
	local applied = floor(self.alpha * 100 + 0.5) / 100
	if applied ~= self.alphaApplied then
		self.root:SetAlpha(applied)
		self.alphaApplied = applied
	end

	if self.placeDirty then
		self.placeDirty = false
		self:Place()
	end
	if self.paintDirty then
		self.paintDirty = false
		self:Paint()
	end
	if self.hitActive then
		self:StepHit(t)
		settled = settled and not self.hitActive
	end
	self.busy = not settled
end

function R:Frame(t)
	self.frames = self.frames + 1
	local dt = self.t and (t - self.t) or RESUME_S + 1
	self.t = t
	local resumed = dt > RESUME_S
	if dt > 0.1 then
		dt = 0.1
	elseif dt < 0 then
		dt = 0
	end
	if resumed or t >= self.nextPoll then
		self.nextPoll = t + POLL_S
		self:Poll(t)
	end
	if resumed then
		self:Snap()
	end
	if self.busy or self.placeDirty or self.paintDirty then
		self:Step(dt, t)
	end
end

-- An error in a frame must not repeat sixty times a second: it is kept for /pbreticle status, and the
-- third one stops this reticle (and Main.lua gives the game's own back). The game is only asked every other
-- frame, so a failing question succeeds on the frames between: the count starts over only after a
-- stretch of frames that all went well.
function R:OnUpdate(t)
	local ok, err = pcall(self.Frame, self, t)
	if ok then
		self.goodFrames = self.goodFrames + 1
		if self.goodFrames >= GOOD_FRAMES then
			self.errors = 0
		end
		return
	end
	self.goodFrames = 0
	self.lastError = tostring(err)
	self.errors = self.errors + 1
	if self.errors >= MAX_ERRORS then
		self.root:SetHandler("OnUpdate", nil)
		self.failed = true
		if self.onFail then
			self.onFail(self)
		end
	end
end

function R:SetSource(source)
	self.source = source
	self.nextPoll = 0
	self.busy = true
end
