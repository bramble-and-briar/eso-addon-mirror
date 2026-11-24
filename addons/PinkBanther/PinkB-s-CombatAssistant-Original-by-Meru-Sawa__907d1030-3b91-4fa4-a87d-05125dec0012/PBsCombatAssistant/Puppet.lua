-- The puppet: Ember as a set of textures cut from one atlas, moved by a small rig.
--
-- The rig (Geometry.lua, from the art script) is a list of pieces back to front. Each hangs on a parent
-- and turns about a pivot, so an arm swings from the shoulder, the head tilts on the neck, and the face and
-- hair follow the head. A pose is plain numbers: an angle per piece, an offset for the whole figure, a scale
-- and an opacity, and which expression the face shows. Solve() turns a pose into where each piece goes;
-- Puppet:Apply() puts the textures there. Nothing here knows about alerts: that is Ember.lua.
--
-- Angles are radians, positive = counter-clockwise on screen. That is how SetTextureRotation turns (the
-- client's radial menu and the map's player pin both rely on it); the one setting rotFlip turns it round if a
-- console proves otherwise. A piece is turned about its own centre by the engine, and moved by this file to
-- where the rotation about the rig's pivot would put its centre, so the two always agree.
--
-- Textures are controls with texture coordinates into the atlas, the way PB's other add-ons draw (the
-- anchor-limit and zero-height traps of the client's templates do not come into it).

local A = PBS_COMBAT_ASSISTANT
local G = PBS_COMBAT_ASSISTANT_GEOMETRY

local Puppet = {}
A.Puppet = Puppet
Puppet.__index = Puppet

local cos, sin = math.cos, math.sin

local LEVEL_HALO = 10
local LEVEL_ART = 20
local LEVEL_FX = 30
local LEVEL_FRONT = 25 -- an arm that is raised is drawn in front of the head, not behind it
local RAISED = 1.1 -- radians from hanging down, past which an arm counts as raised

-- ---------------------------------------------------------------------------------------
-- The maths (no game calls: the offline tests run it on its own)
-- ---------------------------------------------------------------------------------------

-- A point turned by theta (counter-clockwise on screen, y pointing down).
function Puppet.Rot(theta, x, y)
	local c, s = cos(theta), sin(theta)
	return c * x + s * y, -s * x + c * y
end

-- The rig as nodes with their parents resolved, in draw order.
function Puppet.MakeNodes()
	local nodes, by = {}, {}
	for _, row in ipairs(G.rig) do
		local node = { name = row.name, px = row.px, py = row.py, parentName = row.parent }
		nodes[#nodes + 1] = node
		by[node.name] = node
	end
	for _, node in ipairs(nodes) do
		node.parent = node.parentName and by[node.parentName] or nil
	end
	return nodes, by
end

-- The rest-pose rectangle of a node's picture; the face takes its rectangle from any expression.
local FACE_PART = {} -- expression -> "face_<expression>", so a frame does not build the name again
local function PartOf(node, expression)
	if node.name == "face" then
		expression = expression or "idle"
		local key = FACE_PART[expression]
		if not key then
			key = "face_" .. expression
			FACE_PART[expression] = key
		end
		return G.parts[key] or G.parts.face_idle
	end
	return G.parts[node.name]
end
Puppet.PartOf = PartOf

-- A node's turn and shift in the canvas, worked out once per solve (stamp) and kept in its own table.
local function World(node, pose, memo, stamp)
	local m = memo[node]
	if m and m.stamp == stamp then
		return m
	end
	if not m then
		m = {}
		memo[node] = m
	end
	local th = pose.rot and pose.rot[node.name] or 0
	local off = pose.off and pose.off[node.name]
	-- p' = R(th) (p - pivot) + pivot + off
	local rx, ry = Puppet.Rot(th, node.px, node.py)
	local tx = node.px - rx + (off and off[1] or 0)
	local ty = node.py - ry + (off and off[2] or 0)
	local theta = th
	if node.parent then
		local P = World(node.parent, pose, memo, stamp)
		local ox, oy = Puppet.Rot(P.theta, tx, ty)
		theta = P.theta + th
		tx, ty = ox + P.tx, oy + P.ty
	end
	m.theta, m.tx, m.ty, m.stamp = theta, tx, ty, stamp
	return m
end

-- Where each node's picture goes: centre (x, y) in canvas u and its turn, before the whole-figure offset
-- and scale. Returns a table by node name. With `work` (a table kept by the caller) the same tables are
-- filled again on every call, so a frame makes no garbage; without it the answer is fresh.
function Puppet.Solve(nodes, pose, work)
	work = work or {}
	work.memo = work.memo or {}
	work.out = work.out or {}
	work.stamp = (work.stamp or 0) + 1
	local memo, out, stamp = work.memo, work.out, work.stamp
	for _, node in ipairs(nodes) do
		local part = PartOf(node, pose.expression)
		local s = out[node.name]
		if part then
			local W = World(node, pose, memo, stamp)
			local cx, cy = part.x + part.w / 2, part.y + part.h / 2
			local rx, ry = Puppet.Rot(W.theta, cx, cy)
			if not s then
				s = {}
				out[node.name] = s
			end
			s.x, s.y, s.theta, s.part = rx + W.tx, ry + W.ty, W.theta, part
		elseif s then
			out[node.name] = nil
		end
	end
	return out
end

-- ---------------------------------------------------------------------------------------
-- The controls
-- ---------------------------------------------------------------------------------------

local function NewTexture(name, parent, level, u0, v0, u1, v1)
	local c = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
	c:SetTexture(G.atlas)
	c:SetTextureCoords(u0, u1, v0, v1)
	c:SetDrawLayer(DL_CONTROLS)
	c:SetDrawLevel(level)
	c:SetMouseEnabled(false)
	c:SetHidden(true)
	return c
end

-- One picture that may have a sticker halo under it.
local function NewPair(prefix, parent, part, haloLevel, artLevel)
	local pair = { part = part, last = {} }
	if part.hu0 then
		pair.halo = NewTexture(prefix .. "Halo", parent, haloLevel, part.hu0, part.hv0, part.hu1, part.hv1)
	end
	pair.art = NewTexture(prefix, parent, artLevel, part.u0, part.v0, part.u1, part.v1)
	return pair
end

-- Puts a picture at a centre (x, y in px from the stage's top left), size w x h px, turned by rot.
-- What changed since the last frame is worked out once for the pair; the halo and the picture get the same calls.
local function PlaceOne(c, stage, moved, sized, turned, faded, shown, x, y, w, h, rot, alpha)
	if moved then
		c:ClearAnchors()
		c:SetAnchor(TOPLEFT, stage, TOPLEFT, x - w / 2, y - h / 2)
	end
	if sized then
		c:SetDimensions(w, h)
	end
	if turned then
		c:SetTextureRotation(rot, 0.5, 0.5)
	end
	if faded then
		c:SetAlpha(alpha)
	end
	if shown then
		c:SetHidden(false)
	end
end

local abs = math.abs

local function Place(pair, stage, x, y, w, h, rot, alpha)
	local last = pair.last
	local moved = not (last.x and abs(last.x - x) < 0.05 and abs(last.y - y) < 0.05 and abs(last.w - w) < 0.05 and abs(last.h - h) < 0.05)
	local sized = not (last.w and abs(last.w - w) < 0.05 and abs(last.h - h) < 0.05)
	local turned = not (last.rot and abs(last.rot - rot) < 0.0005)
	local faded = last.alpha ~= alpha
	local shown = last.hidden ~= false
	if pair.halo then
		PlaceOne(pair.halo, stage, moved, sized, turned, faded, shown, x, y, w, h, rot, alpha)
	end
	PlaceOne(pair.art, stage, moved, sized, turned, faded, shown, x, y, w, h, rot, alpha)
	last.x, last.y, last.w, last.h, last.rot, last.alpha, last.hidden = x, y, w, h, rot, alpha, false
end

local function Hide(pair)
	local last = pair.last
	if last.hidden ~= true then
		if pair.halo then
			pair.halo:SetHidden(true)
		end
		pair.art:SetHidden(true)
		-- forget the rest, so the next Place sets everything again
		last.x, last.y, last.w, last.h, last.rot, last.alpha, last.hidden = nil, nil, nil, nil, nil, nil, true
	end
end

function Puppet.New(window, prefix)
	local self = setmetatable({}, Puppet)
	self.nodes, self.by = Puppet.MakeNodes()
	self.stage = WINDOW_MANAGER:CreateControl(prefix .. "Stage", window, CT_CONTROL)
	self.stage:SetMouseEnabled(false)
	self.pairs = {}
	self.fx = {}
	self.fxKeys = {} -- { name, index, key = name .. index } for every effect picture, made once
	self.work = {} -- the tables Solve fills again every frame
	self.expression = "idle"
	self.faceCoords = nil
	-- halos first, then the pictures, so every outline lies under the whole figure
	for _, node in ipairs(self.nodes) do
		local part = G.parts[node.name] or (node.name == "face" and G.parts.face_idle)
		if part then
			self.pairs[node.name] = { part = part, last = {} }
		end
	end
	for _, node in ipairs(self.nodes) do
		local pair = self.pairs[node.name]
		if pair and pair.part.hu0 then
			pair.halo = NewTexture(prefix .. node.name .. "Halo", self.stage, LEVEL_HALO, pair.part.hu0, pair.part.hv0, pair.part.hu1, pair.part.hv1)
		end
	end
	for _, node in ipairs(self.nodes) do
		local pair = self.pairs[node.name]
		if pair then
			local p = pair.part
			pair.art = NewTexture(prefix .. node.name, self.stage, LEVEL_ART, p.u0, p.v0, p.u1, p.v1)
		end
	end
	for _, name in ipairs({ "excl", "sweat", "spark" }) do
		-- sweat and spark exist twice (two drops, two twinkles)
		local count = (name == "excl") and 1 or 2
		self.fx[name] = {}
		for i = 1, count do
			self.fx[name][i] = NewPair(prefix .. name .. i, self.stage, G.parts[name], LEVEL_FX, LEVEL_FX + 1)
			self.fxKeys[#self.fxKeys + 1] = { name = name, index = i, key = name .. i }
		end
	end
	return self
end

-- Switches the face to an expression (one texture-coordinate change).
function Puppet:SetExpression(expression)
	if expression == self.expression then
		return
	end
	local part = G.parts["face_" .. expression]
	if not part then
		return
	end
	self.expression = expression
	local pair = self.pairs.face
	if pair and pair.art then
		pair.art:SetTextureCoords(part.u0, part.u1, part.v0, part.v1)
	end
end

-- Puts the whole figure in a pose. unit = px per u (the size setting); pose.scale = the pop in/out scale.
function Puppet:Apply(pose, unit)
	local solved = Puppet.Solve(self.nodes, pose, self.work)
	self:SetExpression(pose.expression or "idle")
	local ps = pose.scale or 1
	local alpha = pose.alpha or 1
	local sign = A.sv and A.sv.rotFlip and -1 or 1
	local fx, fy = G.feet.x, G.feet.y
	local dx, dy = pose.dx or 0, pose.dy or 0
	for _, node in ipairs(self.nodes) do
		local s, pair = solved[node.name], self.pairs[node.name]
		if s and pair then
			local X, Y = s.x, s.y
			local a, w, h = alpha, s.part.w, s.part.h
			if node.name == "shadow" then
				-- the shadow stays on the floor and shrinks as she hops
				local lift = math.min(1, math.max(0, -dy) / 40)
				w = w * (1 - 0.35 * lift)
				h = h * (1 - 0.35 * lift)
				a = alpha * (1 - 0.5 * lift)
				X = X + dx
			else
				X, Y = X + dx, Y + dy
			end
			local px = unit * (fx + ps * (X - fx))
			local py = unit * (fy + ps * (Y - fy))
			Place(pair, self.stage, px, py, w * unit * ps, h * unit * ps, sign * s.theta, a)
			if node.name == "arm_l" or node.name == "arm_r" then
				local raised = math.abs(pose.rot and pose.rot[node.name] or 0) > RAISED
				if pair.raised ~= raised then
					pair.raised = raised
					pair.art:SetDrawLevel(raised and LEVEL_FRONT or LEVEL_ART)
				end
			end
		end
	end
end

-- An effect picture (name = "excl" | "sweat" | "spark", index 1 or 2) at canvas (x, y) u, scaled, turned,
-- or hidden when alpha <= 0.
function Puppet:SetFx(name, index, x, y, scale, rot, alpha, unit)
	local pair = self.fx[name] and self.fx[name][index]
	if not pair then
		return
	end
	if not alpha or alpha <= 0.01 or scale <= 0.01 then
		Hide(pair)
		return
	end
	local sign = A.sv and A.sv.rotFlip and -1 or 1
	local part = pair.part
	Place(pair, self.stage, x * unit, y * unit, part.w * unit * scale, part.h * unit * scale, sign * (rot or 0), alpha)
end

-- The effects of a pose (pose.fx["excl1"], ["sweat1"], ["sweat2"], ["spark1"], ["spark2"]), moved and scaled
-- with the figure; the ones the pose does not mention are hidden.
function Puppet:ApplyFx(pose, unit)
	local ps = pose.scale or 1
	local alpha = pose.alpha or 1
	local dx, dy = pose.dx or 0, pose.dy or 0
	local fx, fy = G.feet.x, G.feet.y
	for _, k in ipairs(self.fxKeys) do
		local e = pose.fx and pose.fx[k.key]
		if e and e.on ~= false then
			local X, Y = e.x + dx, e.y + dy
			self:SetFx(k.name, k.index, fx + ps * (X - fx), fy + ps * (Y - fy), e.scale * ps, e.rot, e.alpha * alpha, unit)
		else
			self:SetFx(k.name, k.index, 0, 0, 0, 0, 0, unit)
		end
	end
end

function Puppet:HideAll()
	for _, pair in pairs(self.pairs) do
		Hide(pair)
	end
	for _, list in pairs(self.fx) do
		for _, pair in ipairs(list) do
			Hide(pair)
		end
	end
end

PBS_COMBAT_ASSISTANT_MARK("Puppet")
