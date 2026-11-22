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

local A = PBS_EMBER
local G = PBS_EMBER_GEOMETRY

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
local function PartOf(node, expression)
	if node.name == "face" then
		return G.parts["face_" .. (expression or "idle")] or G.parts.face_idle
	end
	return G.parts[node.name]
end
Puppet.PartOf = PartOf

local function World(node, pose, memo)
	local cached = memo[node]
	if cached then
		return cached
	end
	local th = pose.rot and pose.rot[node.name] or 0
	local off = pose.off and pose.off[node.name]
	-- p' = R(th) (p - pivot) + pivot + off
	local rx, ry = Puppet.Rot(th, node.px, node.py)
	local tx = node.px - rx + (off and off[1] or 0)
	local ty = node.py - ry + (off and off[2] or 0)
	local theta = th
	if node.parent then
		local P = World(node.parent, pose, memo)
		local ox, oy = Puppet.Rot(P.theta, tx, ty)
		theta = P.theta + th
		tx, ty = ox + P.tx, oy + P.ty
	end
	local out = { theta = theta, tx = tx, ty = ty }
	memo[node] = out
	return out
end

-- Where each node's picture goes: centre (x, y) in canvas u and its turn, before the whole-figure offset
-- and scale. Returns a table by node name.
function Puppet.Solve(nodes, pose)
	local memo, out = {}, {}
	for _, node in ipairs(nodes) do
		local part = PartOf(node, pose.expression)
		if part then
			local W = World(node, pose, memo)
			local cx, cy = part.x + part.w / 2, part.y + part.h / 2
			local rx, ry = Puppet.Rot(W.theta, cx, cy)
			out[node.name] = { x = rx + W.tx, y = ry + W.ty, theta = W.theta, part = part }
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
local function Place(pair, stage, x, y, w, h, rot, alpha)
	local last = pair.last
	for _, key in ipairs({ "halo", "art" }) do
		local c = pair[key]
		if c then
			if not (last.x and math.abs(last.x - x) < 0.05 and math.abs(last.y - y) < 0.05 and math.abs(last.w - w) < 0.05) then
				c:ClearAnchors()
				c:SetAnchor(TOPLEFT, stage, TOPLEFT, x - w / 2, y - h / 2)
			end
			if not (last.w and math.abs(last.w - w) < 0.05 and math.abs(last.h - h) < 0.05) then
				c:SetDimensions(w, h)
			end
			if not (last.rot and math.abs(last.rot - rot) < 0.0005) then
				c:SetTextureRotation(rot, 0.5, 0.5)
			end
			if last.alpha ~= alpha then
				c:SetAlpha(alpha)
			end
			if last.hidden ~= false then
				c:SetHidden(false)
			end
		end
	end
	last.x, last.y, last.w, last.h, last.rot, last.alpha, last.hidden = x, y, w, h, rot, alpha, false
end

local function Hide(pair)
	if pair.last.hidden ~= true then
		if pair.halo then
			pair.halo:SetHidden(true)
		end
		pair.art:SetHidden(true)
		pair.last = { hidden = true }
	end
end

function Puppet.New(window, prefix)
	local self = setmetatable({}, Puppet)
	self.nodes, self.by = Puppet.MakeNodes()
	self.stage = WINDOW_MANAGER:CreateControl(prefix .. "Stage", window, CT_CONTROL)
	self.stage:SetMouseEnabled(false)
	self.pairs = {}
	self.fx = {}
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
	local solved = Puppet.Solve(self.nodes, pose)
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
	for name, list in pairs(self.fx) do
		for index in ipairs(list) do
			local e = pose.fx and pose.fx[name .. index]
			if e then
				local X, Y = e.x + dx, e.y + dy
				self:SetFx(name, index, fx + ps * (X - fx), fy + ps * (Y - fy), e.scale * ps, e.rot, e.alpha * alpha, unit)
			else
				self:SetFx(name, index, 0, 0, 0, 0, 0, unit)
			end
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

PBS_EMBER_MARK("Puppet")
