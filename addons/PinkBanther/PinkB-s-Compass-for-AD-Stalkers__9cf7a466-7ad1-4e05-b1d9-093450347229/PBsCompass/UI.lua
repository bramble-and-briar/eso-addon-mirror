-- The ring, its four letters and the member markers.
--
-- Console-safe on purpose, like PB's TargetPlayer band: only fonts the client already has loaded
-- (a font nothing else draws with has to be built on use and has crashed a PS5), plain textures, and
-- nothing takes input.
local A = PBS_COMPASS

local PATH = "PBsCompass/assets/"
local TICK_MS = 33 -- the ring is turned about thirty times a second
local ROTATION_EPS = 0.002 -- radians; below this the letters are not moved again
local DEMO_MS = 20000
local MAX_TICK_ERRORS = 3

local LETTERS = {
	small = { font = "ZoFontGamepadBold22", px = 22 },
	medium = { font = "ZoFontGamepadBold27", px = 27 },
	large = { font = "ZoFontGamepadBold34", px = 34 },
}
local NAME_FONT = "ZoFontGamepad18"
-- Nothing is coloured: the letters, ticks and markers are the textures' own white and the fonts' own
-- colour. The only thing that varies is how solid a marker is (a member beyond the range is dimmed).
local FAR_ALPHA = 0.5

local floor, abs = math.floor, math.abs
local Bearing, ScreenAngle, Polar, MemberRadius = A.Bearing, A.ScreenAngle, A.Polar, A.MemberRadius

local function Texture(name, parent, file, level)
	local c = WINDOW_MANAGER:CreateControl(name, parent, CT_TEXTURE)
	c:SetTexture(PATH .. file .. ".dds")
	c:SetDrawLayer(DL_CONTROLS)
	c:SetDrawLevel(level)
	c:SetMouseEnabled(false)
	return c
end

function A:CreateUI()
	local root = WINDOW_MANAGER:CreateTopLevelWindow("PBsCompassRoot")
	root:SetHidden(true)
	root:SetMouseEnabled(false)
	root:SetMovable(false)
	root:SetDimensions(2, 2)
	self.root = root

	self.ring = Texture("PBsCompassRing", root, "ring", 0)
	self.ring:SetColor(1, 1, 1, 0.55)
	self.ring:SetHidden(true)

	self.cards = {}
	for i, cardinal in ipairs(A.CARDINALS) do
		local card = { key = cardinal.key, bearing = cardinal.bearing }
		card.tick = Texture("PBsCompassTick" .. cardinal.key, root, "tri", 1)
		local label = WINDOW_MANAGER:CreateControl("PBsCompassLetter" .. cardinal.key, root, CT_LABEL)
		label:SetDrawLayer(DL_TEXT)
		label:SetMouseEnabled(false)
		label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
		label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
		label:SetText(cardinal.key)
		card.label = label
		self.cards[i] = card
	end
	self.markers = {}
end

function A:IsPreviewing()
	return self.panelOpen and self.sv.preview and self.active and true or false
end

function A:ShowingDemo()
	return self:IsPreviewing() or (self.demoUntil ~= nil and GetGameTimeMilliseconds() < self.demoUntil)
end

-- Everything that depends on the settings. The next tick moves every piece again.
function A:ApplyLayout()
	local root = self.root
	if not root then
		return
	end
	local sv = self.sv
	local letter = LETTERS[sv.letterSize]
	local radius = sv.radius
	local tickSize = floor(letter.px * 0.6 + 0.5)
	self.metrics = {
		radius = radius,
		-- farthest a marker's centre goes: the whole marker stays inside the circle of letters
		limit = A.MemberLimit(radius, letter.px, sv.markerSize),
		tickRadius = radius + letter.px * 0.65 + tickSize * 0.5,
	}

	local previewing = self:IsPreviewing()
	root:ClearAnchors()
	root:SetAnchor(CENTER, GuiRoot, CENTER, sv.x, sv.y)
	root:SetAlpha(sv.opacity / 100)
	-- Above the settings screen while it is being adjusted, in the HUD layer otherwise.
	root:SetDrawTier(previewing and DT_HIGH or DT_MEDIUM)
	root:SetDrawLayer(previewing and DL_OVERLAY or DL_CONTROLS)
	root:SetDrawLevel(previewing and 100 or 0)

	self.ring:ClearAnchors()
	self.ring:SetAnchor(CENTER, root, CENTER, 0, 0)
	self.ring:SetDimensions(radius * 2, radius * 2)
	self.ring:SetHidden(not sv.ring)

	for _, card in ipairs(self.cards) do
		card.label:SetFont(letter.font)
		card.label:SetDimensions(letter.px * 2, letter.px * 2)
		card.label:SetColor(1, 1, 1, 1)
		card.tick:SetDimensions(tickSize, tickSize)
		card.tick:SetColor(1, 1, 1, 1)
	end
	for _, marker in ipairs(self.markers) do
		self:SizeMarker(marker)
		marker.x, marker.y, marker.far = nil, nil, nil
	end
	self.lastRotation = nil
end

function A:SizeMarker(marker)
	local size = self.sv.markerSize
	marker.tex:SetDimensions(size, size)
end

function A:GetMarker(index)
	local marker = self.markers[index]
	if marker then
		return marker
	end
	local tex = Texture("PBsCompassMarker" .. index, self.root, "tri", 2)
	-- Drawn point down, the "V" of the sketch.
	tex:SetTextureRotation(math.pi, 0.5, 0.5)
	tex:SetHidden(true)
	marker = { tex = tex, hidden = true }
	self:SizeMarker(marker)
	self.markers[index] = marker
	return marker
end

local function NameLabel(self, marker, index)
	if marker.label then
		return marker.label
	end
	local label = WINDOW_MANAGER:CreateControl("PBsCompassName" .. index, self.root, CT_LABEL)
	label:SetDrawLayer(DL_TEXT)
	label:SetMouseEnabled(false)
	label:SetFont(NAME_FONT)
	label:SetColor(1, 1, 1, 1)
	label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	label:SetAnchor(TOP, marker.tex, BOTTOM, 0, 2)
	label:SetHidden(true)
	marker.label = label
	return label
end

function A:PlaceCardinals(rotation)
	local metrics = self.metrics
	for _, card in ipairs(self.cards) do
		local angle = ScreenAngle(card.bearing, rotation)
		local x, y = Polar(angle, metrics.radius)
		card.label:ClearAnchors()
		card.label:SetAnchor(CENTER, self.root, CENTER, x, y)
		-- The tick stands outside its letter and points away from the middle. A positive texture
		-- rotation is counter-clockwise, so a clockwise angle is passed negated.
		local tx, ty = Polar(angle, metrics.tickRadius)
		card.tick:ClearAnchors()
		card.tick:SetAnchor(CENTER, self.root, CENTER, tx, ty)
		card.tick:SetTextureRotation(-angle, 0.5, 0.5)
	end
end

function A:PlaceMembers(list, rotation)
	local metrics, sv = self.metrics, self.sv
	local count = #list
	for index = 1, count do
		local entry = list[index]
		local marker = self:GetMarker(index)

		-- Standing on the very spot has no direction: stay where the marker was.
		local bearing
		if entry.dx * entry.dx + entry.dz * entry.dz < 0.25 then
			bearing = marker.bearing or 0
		else
			bearing = Bearing(entry.dx, entry.dz)
		end
		marker.bearing = bearing

		local radius, far = MemberRadius(metrics.limit, entry.distance, sv.range)
		local x, y = Polar(ScreenAngle(bearing, rotation), radius)
		-- Half a pixel is as fine as the screen shows.
		x, y = floor(x * 2 + 0.5) / 2, floor(y * 2 + 0.5) / 2
		if marker.x ~= x or marker.y ~= y then
			marker.tex:ClearAnchors()
			marker.tex:SetAnchor(CENTER, self.root, CENTER, x, y)
			marker.x, marker.y = x, y
		end

		if marker.far ~= far then
			marker.tex:SetColor(1, 1, 1, far and FAR_ALPHA or 1)
			marker.far = far
		end
		if marker.hidden then
			marker.tex:SetHidden(false)
			marker.hidden = false
		end

		if sv.names then
			local label = NameLabel(self, marker, index)
			if marker.name ~= entry.member.name then
				label:SetText(entry.member.name)
				marker.name = entry.member.name
			end
			if marker.labelHidden ~= false then
				label:SetHidden(false)
				marker.labelHidden = false
			end
			label:SetAlpha(far and FAR_ALPHA or 1)
		elseif marker.label and marker.labelHidden ~= true then
			marker.label:SetHidden(true)
			marker.labelHidden = true
		end
	end
	for index = count + 1, #self.markers do
		local marker = self.markers[index]
		if not marker.hidden then
			marker.tex:SetHidden(true)
			marker.hidden = true
			if marker.label then
				marker.label:SetHidden(true)
				marker.labelHidden = true
			end
		end
	end
end

function A:TickBody()
	local now = GetGameTimeMilliseconds()
	local heading = self:ReadHeading()
	self.heading = heading
	local rotation = (self.sv.rotate == "north") and 0 or (heading or 0)
	if not self.lastRotation or abs(rotation - self.lastRotation) > ROTATION_EPS then
		self:PlaceCardinals(rotation)
		self.lastRotation = rotation
	end
	local list
	if self:ShowingDemo() then
		list = self:DemoMembers()
	else
		list = self:Refresh(now)
	end
	self:PlaceMembers(list, rotation)
	self.diag.ticks = self.diag.ticks + 1
end

-- An error in the update must not repeat thirty times a second: it is kept for /pbcompass status,
-- and the third one in a row stops the update.
function A:Tick()
	local ok, err = pcall(self.TickBody, self)
	if ok then
		self.tickErrors = 0
		return
	end
	self.diag.lastError = tostring(err)
	self.tickErrors = (self.tickErrors or 0) + 1
	if self.tickErrors >= MAX_TICK_ERRORS then
		EVENT_MANAGER:UnregisterForUpdate(self.name .. "Tick")
		self:Print("stopped after an error: " .. self.diag.lastError)
	end
end

function A:RefreshVisibility()
	if not self.root then
		return
	end
	local visible = self.active
		and (self:IsPreviewing() or (self.sv.enabled and (HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing())))
		and true
		or false
	self.root:SetHidden(not visible)
	EVENT_MANAGER:UnregisterForUpdate(self.name .. "Tick")
	if visible then
		self.tickErrors = 0
		self:Tick()
		EVENT_MANAGER:RegisterForUpdate(self.name .. "Tick", TICK_MS, function()
			self:Tick()
		end)
	end
end

-- The sample members for a few seconds in the HUD, for someone who is not in a group.
function A:StartDemo()
	self.demoUntil = GetGameTimeMilliseconds() + DEMO_MS
	self:ApplyLayout()
	self:RefreshVisibility()
	EVENT_MANAGER:RegisterForUpdate(self.name .. "DemoEnd", DEMO_MS + 100, function()
		EVENT_MANAGER:UnregisterForUpdate(self.name .. "DemoEnd")
		self.demoUntil = nil
	end)
end
