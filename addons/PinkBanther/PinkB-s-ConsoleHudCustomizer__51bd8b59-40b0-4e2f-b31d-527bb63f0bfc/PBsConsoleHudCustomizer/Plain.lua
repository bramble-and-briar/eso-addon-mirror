-- PBS_CONSOLE_HUD_CUSTOMIZER is nil if Main.lua bailed out early (e.g. already loaded).
if not PBS_CONSOLE_HUD_CUSTOMIZER then
	return
end

local addon = PBS_CONSOLE_HUD_CUSTOMIZER
local Round = addon.Round
local Clamp = addon.Clamp

-- ---------------------------------------------------------------------------------------
-- The plain look
--
-- A second style for the three attribute bars: a flat rectangle for the track and a flat
-- rectangle for what is in it, with the game's arrow-shaped frame and background out of the way.
--
-- It replaces the liquid style of 1.3.x, which never drew anything on a PS5. Two things about
-- that one are not repeated here, because either could have been the reason:
--
--   * it was built out of textures and hung on the client's status bar controls, as children of
--     a StatusBar. This one hangs on the container -- the same parent the client's own frame,
--     background and numbers use, so there is no question about whether a child of it draws.
--   * it was drawn with texture files and blend modes. The track uses a backdrop and the fill uses an untextured
--     colour rectangle, so there is no image file to load.
--
-- The client's own controls are all still there and still doing their work. The frame and the
-- background are hidden (one flag each, put back the moment the style changes), and the bar's own
-- fill is simply covered: the overlay is opaque and sits a tier above it. Nothing is unparented,
-- nothing is resized, and the attribute visualiser's shield, armour and possession overlays carry
-- on drawing on top of the bars as they always did.
-- ---------------------------------------------------------------------------------------

local plain = {
	overlays = {},
	hidden = {},
	numbers = {},
	blanked = {},
}
addon.plain = plain

-- Standard is the game's own. The other two are this add-on's, and both are the same flat
-- rectangle: what separates them is the size. Square keeps the game's own size and scales it;
-- MURA-HIGE Style is drawn at a width and a height of the player's choosing.
--
-- The key is still "rounded" because that is what an install has saved: the style was drawn with
-- round ends until 1.10.0, and it earned nobody's affection.
addon.BAR_STYLES = { "standard", "plain", "rounded", "neo", "liquidflow", "crystal" }

-- Nothing animates, so this only has to keep up with the numbers changing.
local UPDATE_INTERVAL_MS = 100

-- Which bar control belongs to which attribute, which way it fills, and the container it lives
-- in. A bar with barAlignment REVERSE in the XML fills towards its left (magicka, and the left
-- half of the health bar), so its rectangle hangs off the right edge.
--
-- The two halves of the health bar each hold half the value, so the fraction is the same for
-- both: the client divides by two in ZO_PlayerAttributeBar:UpdateStatusBar.
--
-- pointed says which end of a bar comes to a point, and only the ends facing away from the middle
-- of the screen do (playerattributebars.xml): health has an arrow at both ends
-- (ZO_PlayerAttributeFrameLeftArrow and ...RightArrow); magicka has one on its left and a flat
-- ZO_PlayerAttributeFrameRight on its right; stamina is the mirror of that. Until 1.27.5 every
-- single bar was taken for pointed at both ends, which cut the effect back into a triangle at
-- stamina's flat left end and magicka's flat right one (FINDINGS 61).
plain.bars = {
	{
		key = "health",
		power = "health",
		container = "ZO_PlayerAttributeHealth",
		pointedLeft = true,
		pointedRight = true,
		controls = {
			{ name = "ZO_PlayerAttributeHealthBarLeft", reverse = true },
			{ name = "ZO_PlayerAttributeHealthBarRight", reverse = false },
		},
	},
	{
		key = "magicka",
		power = "magicka",
		container = "ZO_PlayerAttributeMagicka",
		pointedLeft = true,
		pointedRight = false,
		controls = { { name = "ZO_PlayerAttributeMagickaBar", reverse = true } },
	},
	{
		key = "stamina",
		power = "stamina",
		container = "ZO_PlayerAttributeStamina",
		pointedLeft = false,
		pointedRight = true,
		controls = { { name = "ZO_PlayerAttributeStaminaBar", reverse = false } },
	},
}

-- What the game draws around the fill, and what this style puts away: the three frame pieces
-- (the arrow ends and the middle) and the whole background container.
local DRESSING = { "FrameLeft", "FrameCenter", "FrameRight", "BgContainer" }

-- The label the game writes the current and maximum on, when the player has it switched on under
-- Settings > Interface. It is drawn at the default tier, and the rectangles are at HIGH, so
-- without this it ends up behind them -- which is what came back from the PS5.
--
-- The low-health warner needs no such help: it is layer OVERLAY, tier HIGH, level 500
-- (ZO_PlayerAttributeWarner), which is above anything here.
local NUMBERS = "ResourceNumbers"
local NUMBERS_LEVEL = 10

-- Used only if the client will not say what colour a power is.
local FALLBACK_COLOURS = {
	health = { 0.65, 0.16, 0.16 },
	magicka = { 0.20, 0.38, 0.78 },
	stamina = { 0.27, 0.56, 0.20 },
}

local TRACK_COLOUR = { 0.06, 0.06, 0.06 }

-- The outline. Dark rather than black so it reads as a line drawn round the bar rather than a
-- gap in it.
addon.BORDER_COLOURS = { "black", "white", "silver", "gold", "red", "blue" }
local BORDER_PALETTE = {
	black = { 0, 0, 0 },
	white = { 1, 1, 1 },
	silver = { 0.75, 0.75, 0.75 },
	gold = { 1, 0.84, 0 },
	red = { 0.9, 0.2, 0.2 },
	blue = { 0.25, 0.55, 1 },
}
local BORDER_ALPHA = 0.82

function addon:PlainBorderColour()
	local key = self:Account().plainBorderColour
	return BORDER_PALETTE[key] and key or "black"
end

function addon:SetPlainBorderColour(key)
	if not BORDER_PALETTE[key] then return false end
	self:Account().plainBorderColour = key
	return true
end

-- ---------------------------------------------------------------------------------------
-- Settings
-- ---------------------------------------------------------------------------------------

function addon:BarStyle()
	local style = self:Account().style
	-- 1.3.x called the second style "liquid".
	if style == "liquid" then
		style = "plain"
		self:Account().style = style
	end
	for _, known in ipairs(self.BAR_STYLES) do
		if style == known then
			return style
		end
	end
	return "standard"
end

function addon:SetBarStyle(style)
	for _, known in ipairs(self.BAR_STYLES) do
		if style == known then
			self:Account().style = style
			return true
		end
	end
	return false
end

addon.MIN_PLAIN_OPACITY = 10
addon.MAX_PLAIN_OPACITY = 100
addon.DEFAULT_PLAIN_OPACITY = 100

function addon:PlainOpacity()
	local value = self:Account().plainOpacity
	if type(value) ~= "number" then
		return self.DEFAULT_PLAIN_OPACITY
	end
	return Clamp(Round(value), self.MIN_PLAIN_OPACITY, self.MAX_PLAIN_OPACITY)
end

function addon:SetPlainOpacity(value)
	self:Account().plainOpacity = Clamp(Round(value), self.MIN_PLAIN_OPACITY, self.MAX_PLAIN_OPACITY)
end

-- Whether this add-on's bars carry an outline of their own. The game's arrow-shaped frame is
-- always put away while one of these styles is on -- a flat rectangle inside an arrow frame is
-- neither one thing nor the other -- so an outline is the only frame on offer, and it is this
-- add-on's to draw.
function addon:PlainBorder()
	return self:Account().plainBorder ~= false
end

function addon:SetPlainBorder(value)
	self:Account().plainBorder = value and true or false
end

-- True while this add-on draws the bars itself, in either of its two shapes.
function addon:PlainWanted()
	if not self:Account().enabled then
		return false
	end
	local style = self:BarStyle()
	return style == "plain" or style == "rounded" or style == "neo" or style == "liquidflow" or style == "crystal"
end

-- MURA-HIGE Style: the one drawn at a size of its own.
function addon:BarsAreMuraHige()
	return self:BarStyle() == "rounded" or self:BarStyle() == "neo"
end

-- ---------------------------------------------------------------------------------------
-- A size in pixels, for the one style that offers it
--
-- Every other style scales: the bar keeps the shape the game drew and is made bigger or smaller
-- whole, because the width of those controls is not this add-on's (the attribute visualiser
-- writes it as buffs come and go, see FINDINGS §3). MURA-HIGE Style draws the bar itself, so
-- there is nothing to fight: it can be given a width and a height and be exactly that.
--
-- Unset means "as the game draws it", which is what keeps an install that never touches these
-- looking the way it did.
-- ---------------------------------------------------------------------------------------

addon.MIN_BAR_WIDTH, addon.MAX_BAR_WIDTH = 20, 800
addon.MIN_BAR_HEIGHT, addon.MAX_BAR_HEIGHT = 3, 80

-- The gamepad attribute bar: 224 of drawable width inside the 237 container, 17 high.
addon.GAME_BAR_WIDTH, addon.GAME_BAR_HEIGHT = 224, 17

function addon:BarSizeSaved(bar)
	local saved = self:Account().bars[bar.key]
	return saved and saved.width, saved and saved.height
end

-- The size to draw at: what was asked for, else the game's own.
function addon:BarSize(bar)
	local width, height = self:BarSizeSaved(bar)
	local measured = self:Account().measured[bar.key] or {}
	if type(width) ~= "number" then
		width = type(measured.barWidth) == "number" and measured.barWidth or self.GAME_BAR_WIDTH
	end
	if type(height) ~= "number" then
		height = type(measured.barHeight) == "number" and measured.barHeight or self.GAME_BAR_HEIGHT
	end
	return Clamp(Round(width), self.MIN_BAR_WIDTH, self.MAX_BAR_WIDTH),
		Clamp(Round(height), self.MIN_BAR_HEIGHT, self.MAX_BAR_HEIGHT)
end

function addon:SetBarSize(bar, which, value)
	local saved = self:Account().bars[bar.key]
	if which == "width" then
		saved.width = Clamp(Round(value), self.MIN_BAR_WIDTH, self.MAX_BAR_WIDTH)
	else
		saved.height = Clamp(Round(value), self.MIN_BAR_HEIGHT, self.MAX_BAR_HEIGHT)
	end
end

-- True while a bar is drawn at a size rather than scaled. That is the whole of what MURA-HIGE
-- Style is, so it is true for every bar the moment the style is chosen -- not only once a slider
-- has been moved.
--
-- It was the saved values that decided this until 1.10.2, which meant choosing the style changed
-- nothing on screen until a slider was touched, and the sizes looked as though they only applied
-- on the second attempt. Unset values are the game's own size; drawing that at a size of our own
-- looks the same and behaves consistently.
function addon:BarSizeIsOwn(bar)
	return self:BarsAreMuraHige()
end

-- ---------------------------------------------------------------------------------------
-- The controls
-- ---------------------------------------------------------------------------------------

local function Control(name)
	local control = _G[name]
	if type(control) ~= "table" and type(control) ~= "userdata" then
		return nil
	end
	if type(control.GetDimensions) ~= "function" then
		return nil
	end
	return control
end

plain.Control = Control

function plain:PowerColour(bar)
	local powerType = _G["COMBAT_MECHANIC_FLAGS_" .. bar.power:upper()]
	if powerType and type(GetInterfaceColor) == "function" and INTERFACE_COLOR_TYPE_POWER_START then
		local ok, r, g, b = pcall(GetInterfaceColor, INTERFACE_COLOR_TYPE_POWER_START, powerType)
		if ok and type(r) == "number" and type(g) == "number" and type(b) == "number" then
			return r, g, b
		end
	end
	local fallback = FALLBACK_COLOURS[bar.key] or { 1, 1, 1 }
	return fallback[1], fallback[2], fallback[3]
end

function plain:Overlay(bar, entry)
	local existing = self.overlays[entry.name]
	if existing then
		return existing
	end
	local barControl = Control(entry.name)
	local container = Control(bar.container)
	if not barControl or not container or not addon.timers then
		return nil
	end
	-- Built the same way as the skill bar's controls, with the same fallback if the XML did not
	-- load.
	local control = addon.timers:Build("PBsConsoleHudCustomizerPlain", container, "PBsConsoleHudCustomizerPlainBar", entry.name)
	if not control then
		return nil
	end
	local overlay = {
		control = control,
		bar = barControl,
		reverse = entry.reverse,
		track = control.Track or control:GetNamedChild("Track"),
		fill = control.Fill or control:GetNamedChild("Fill"),
		key = bar.key,
		border = {},
	}
	for _, side in ipairs({ "Top", "Bottom", "Left", "Right" }) do
		overlay.border[side] = control["Border" .. side] or control:GetNamedChild("Border" .. side)
	end
	self.overlays[entry.name] = overlay
	self:AnchorOverlay(overlay, bar)
	self:ColourOverlay(bar, overlay)
	return overlay
end

-- Over the client's own fill, exactly: the whole of the bar control's rectangle.
-- Over the client's own bar, exactly -- or, where a size has been asked for, standing on the
-- edge the bar fills from at that size instead.
function plain:AnchorOverlay(overlay, bar)
	local control, barControl = overlay.control, overlay.bar
	local sized = bar and addon:BarSizeIsOwn(bar)
	control:ClearAnchors()
	if sized then
		-- Held by the edge the fill grows from and level with the bar the game has, which is
		-- where the position sliders put it.
		local point = overlay.reverse and RIGHT or LEFT
		control:SetAnchor(point, barControl, point, 0, 0)
		local width, height = addon:BarSize(bar)
		-- The health bar is two halves that meet in the middle, so each is half of what was
		-- asked for and the pair is the whole.
		if #bar.controls > 1 then
			if addon:BarStyle() == "neo" then
				-- Health's native halves meet here. NEO draws one continuous bar,
				-- centered at that same point, rather than two separate fills.
				control:ClearAnchors()
				control:SetAnchor(CENTER, Control(bar.controls[1].name), RIGHT, 0, 0)
			else
				width = width / 2
			end
		end
		control:SetDimensions(width, height)
		overlay.sizedWidth = width
	else
		overlay.sizedWidth = nil
		control:SetAnchor(TOPLEFT, barControl, TOPLEFT, 0, 0)
		control:SetAnchor(BOTTOMRIGHT, barControl, BOTTOMRIGHT, 0, 0)
	end
end

function plain:ColourOverlay(bar, overlay)
	local alpha = addon:PlainOpacity() / 100
	local r, g, b = self:PowerColour(bar)

	if overlay.track and type(overlay.track.SetCenterColor) == "function" then
		overlay.track:SetCenterColor(TRACK_COLOUR[1], TRACK_COLOUR[2], TRACK_COLOUR[3], alpha)
		if type(overlay.track.SetEdgeColor) == "function" then
			overlay.track:SetEdgeColor(0, 0, 0, 0)
		end
		overlay.track:SetHidden(false)
	end
	if overlay.fill and type(overlay.fill.SetColor) == "function" then
		local fill = overlay.fill
		-- Reset all vertices first so switching back to Square restores a solid fill.
		fill:SetColor(r, g, b, alpha)
		if addon:BarsAreMuraHige() and type(fill.SetVertexColors) == "function"
			and VERTEX_POINTS_TOPLEFT and VERTEX_POINTS_TOPRIGHT
			and VERTEX_POINTS_BOTTOMLEFT and VERTEX_POINTS_BOTTOMRIGHT then
			-- Keep each resource's hue: a small white blend at the top, a darker
			-- version at the bottom. Alpha is constant over the whole fill.
			local topR, topG, topB = r + (1 - r) * 0.2, g + (1 - g) * 0.2, b + (1 - b) * 0.2
			fill:SetVertexColors(VERTEX_POINTS_TOPLEFT, topR, topG, topB, alpha)
			fill:SetVertexColors(VERTEX_POINTS_TOPRIGHT, topR, topG, topB, alpha)
			fill:SetVertexColors(VERTEX_POINTS_BOTTOMLEFT, r * 0.55, g * 0.55, b * 0.55, alpha)
			fill:SetVertexColors(VERTEX_POINTS_BOTTOMRIGHT, r * 0.55, g * 0.55, b * 0.55, alpha)
		end
	end

	local border = addon:PlainBorder()
	local colour = BORDER_PALETTE[addon:PlainBorderColour()]
	for _, piece in pairs(overlay.border or {}) do
		if type(piece.SetCenterColor) == "function" then
			piece:SetCenterColor(colour[1], colour[2], colour[3], BORDER_ALPHA * alpha)
			if type(piece.SetEdgeColor) == "function" then
				piece:SetEdgeColor(0, 0, 0, 0)
			end
		end
		piece:SetHidden(not border)
	end
end

function plain:Restyle()
	for _, bar in ipairs(self.bars) do
		for _, entry in ipairs(bar.controls) do
			local overlay = self.overlays[entry.name]
			if overlay then
				self:AnchorOverlay(overlay, bar)
				self:ColourOverlay(bar, overlay)
			end
		end
	end
end

function plain:HideAll()
	for _, overlay in pairs(self.overlays) do
		overlay.control:SetHidden(true)
	end
end

-- ---------------------------------------------------------------------------------------
-- The game's own frame and background
--
-- Hidden while this style is on, and put back the moment it is not. Only the flag is touched,
-- and only when it is not already what it should be, so there is nothing to undo beyond it.
-- ---------------------------------------------------------------------------------------

function plain:Dress(bar, hide)
	for _, suffix in ipairs(DRESSING) do
		local name = bar.container .. suffix
		local control = Control(name)
		if control and type(control.SetHidden) == "function" then
			local wanted = hide and true or false
			if self.hidden[name] ~= wanted then
				addon:Write("plain dressing", control.SetHidden, control, wanted)
				self.hidden[name] = wanted
			end
		end
	end
end

function plain:DressAll(hide)
	for _, bar in ipairs(self.bars) do
		self:Dress(bar, hide)
	end
end

-- The numbers, lifted over the rectangle while this style is on and put back where the client
-- had them when it is not. Re-asserted on every update rather than remembered as done: the
-- client re-applies its own templates to these controls, and a template carries a draw tier.
addon.RESOURCE_TEXT_ALIGNMENTS = { "left", "right", "center" }

function addon:ResourceTextAlignment()
	local key = self:Account().resourceTextAlignment
	if key == "right" or key == "center" then return key end
	return "left"
end

function addon:SetResourceTextAlignment(key)
	for _, known in ipairs(self.RESOURCE_TEXT_ALIGNMENTS) do
		if key == known then
			self:Account().resourceTextAlignment = key
			return true
		end
	end
	return false
end

-- Anchor the label across the drawn bar, not the client's original 224px bar.
-- Save its alignment and anchors before the first write, and restore on style exit.
function plain:AlignNumbers(bar, enabled)
	local label = Control(bar.container .. NUMBERS)
	if not label then return end
	self.numberLayouts = self.numberLayouts or {}
	local saved = self.numberLayouts[label]
	if not enabled then
		if saved then
			addon:Write("number layout", label.ClearAnchors, label)
			for _, anchor in ipairs(saved.anchors) do
				addon:Write("number layout", label.SetAnchor, label, unpack(anchor))
			end
			addon:Write("number layout", label.SetHorizontalAlignment, label, saved.alignment)
			self.numberLayouts[label] = nil
		end
		return
	end
	local first = self.overlays[bar.controls[1].name]
	local last = self.overlays[bar.controls[#bar.controls].name]
	if addon:BarStyle() == "neo" then last = first end
	if not first or not last then return end
	if not saved then
		if type(label.GetHorizontalAlignment) ~= "function" then return end
		local ok, alignment = pcall(label.GetHorizontalAlignment, label)
		if not ok then return end
		saved = { alignment = alignment, anchors = {} }
		for index = 0, 1 do
			local read, valid, point, target, relative, x, y, constrains = pcall(label.GetAnchor, label, index)
			if not read then return end
			if valid then
				saved.anchors[#saved.anchors + 1] = { point, target, relative, x, y, constrains }
			end
		end
		self.numberLayouts[label] = saved
	end
	local key = addon:ResourceTextAlignment()
	local alignment = key == "right" and TEXT_ALIGN_RIGHT or key == "center" and TEXT_ALIGN_CENTER or TEXT_ALIGN_LEFT
	addon:Write("number layout", label.ClearAnchors, label)
	addon:Write("number layout", label.SetAnchor, label, LEFT, first.control, LEFT, 4, 0)
	addon:Write("number layout", label.SetAnchor, label, RIGHT, last.control, RIGHT, -4, 0)
	addon:Write("number layout", label.SetHorizontalAlignment, label, alignment)
end

function plain:RaiseNumbers(bar, raise)
	if not raise then self:AlignNumbers(bar, false) end
	local control = Control(bar.container .. NUMBERS)
	if not control or type(control.SetDrawTier) ~= "function" or type(control.SetDrawLevel) ~= "function" then
		return false
	end

	if raise then
		if not self.numbers[bar.key] then
			local okTier, tier = pcall(control.GetDrawTier, control)
			local okLevel, level = pcall(control.GetDrawLevel, control)
			self.numbers[bar.key] = {
				tier = okTier and tier or nil,
				level = okLevel and level or nil,
			}
		end
		addon:Write("numbers", control.SetDrawTier, control, DT_HIGH)
		addon:Write("numbers", control.SetDrawLevel, control, NUMBERS_LEVEL)
		return true
	end

	local saved = self.numbers[bar.key]
	if not saved then
		return false
	end
	if saved.tier ~= nil then
		addon:Write("numbers", control.SetDrawTier, control, saved.tier)
	end
	if saved.level ~= nil then
		addon:Write("numbers", control.SetDrawLevel, control, saved.level)
	end
	self.numbers[bar.key] = nil
	return true
end

function plain:RaiseAllNumbers(raise)
	for _, bar in ipairs(self.bars) do
		self:RaiseNumbers(bar, raise)
	end
end

-- ---------------------------------------------------------------------------------------
-- The client's own fill, out of the way
--
-- Only needed for a bar drawn at a size of its own: a rectangle narrower or shorter than the
-- game's leaves the game's fill showing round it. The bar control cannot simply be hidden --
-- the damage shield overlays are its children (powershield.lua anchors them to it *and* parents
-- them to it) and would go with it -- so its colours are taken to nothing instead, and its gloss,
-- which has no children, is hidden.
--
-- Putting it back is the client's own line: ZO_StatusBar_SetGradientColor with
-- ZO_POWER_BAR_GRADIENT_COLORS for that power, which is exactly what ZO_PlayerAttributeBar's
-- RefreshColor does.
-- ---------------------------------------------------------------------------------------

local function Gloss(control)
	if control.gloss then
		return control.gloss
	end
	if type(control.GetNamedChild) == "function" then
		local ok, gloss = pcall(control.GetNamedChild, control, "Gloss")
		if ok then
			return gloss
		end
	end
	return nil
end

function plain:BlankClientBar(bar, overlay, blank)
	local control = overlay.bar
	if type(control.SetGradientColors) ~= "function" then
		return false
	end
	local name = overlay.key .. ":" .. tostring(control.GetName and control:GetName() or "?")
	if (self.blanked[name] == true) == (blank and true or false) then
		return true
	end

	local gloss = Gloss(control)
	if blank then
		addon:Write("bar colour", control.SetGradientColors, control, 0, 0, 0, 0, 0, 0, 0, 0)
		if gloss and type(gloss.SetHidden) == "function" then
			addon:Write("bar colour", gloss.SetHidden, gloss, true)
		end
		self.blanked[name] = true
		return true
	end

	local powerType = _G["COMBAT_MECHANIC_FLAGS_" .. bar.power:upper()]
	local gradient = powerType and ZO_POWER_BAR_GRADIENT_COLORS and ZO_POWER_BAR_GRADIENT_COLORS[powerType]
	if gradient and gradient[1] and gradient[2] then
		local ok, r, g, b, a = pcall(gradient[1].UnpackRGBA, gradient[1])
		local ok2, r2, g2, b2, a2 = pcall(gradient[2].UnpackRGBA, gradient[2])
		if ok and ok2 then
			addon:Write("bar colour", control.SetGradientColors, control, r, g, b, a, r2, g2, b2, a2)
		end
	end
	if gloss and type(gloss.SetHidden) == "function" then
		addon:Write("bar colour", gloss.SetHidden, gloss, false)
	end
	self.blanked[name] = nil
	return true
end

function plain:BlankAll(blank)
	for _, bar in ipairs(self.bars) do
		for _, entry in ipairs(bar.controls) do
			local overlay = self.overlays[entry.name]
			if overlay then
				self:BlankClientBar(bar, overlay, blank)
			end
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- How full the bar is
-- ---------------------------------------------------------------------------------------

-- How full the game's own fill is drawn right now. The client does not jump a status bar to a new
-- value: ZO_StatusBar_SmoothTransition plays an animation that moves it there with SetValue, so the
-- fill lags the real amount for a moment after every change -- and after a stay in a menu, by all
-- that was regained there. An effect drawn over the fill has to follow the fill, not the amount, or
-- it stands out past the fill until the fill catches up, which is the flash Liquid and Crystal
-- showed coming back from a menu and Standard did not (1.27.10, FINDINGS 66).
function plain:DrawnFraction(bar)
	local control = Control(bar.controls[1].name)
	if control and type(control.GetValue) == "function" and type(control.GetMinMax) == "function" then
		local okValue, value = pcall(control.GetValue, control)
		local okRange, low, high = pcall(control.GetMinMax, control)
		if okValue and okRange and type(value) == "number" and type(low) == "number" and type(high) == "number"
			and high > low then
			return Clamp((value - low) / (high - low), 0, 1)
		end
	end
	return self:Fraction(bar)
end

function plain:Fraction(bar)
	local powerType = _G["COMBAT_MECHANIC_FLAGS_" .. bar.power:upper()]
	if not powerType or type(GetUnitPower) ~= "function" then
		return nil
	end
	local ok, current, _, effectiveMax = pcall(GetUnitPower, "player", powerType)
	if not ok or type(current) ~= "number" or type(effectiveMax) ~= "number" or effectiveMax <= 0 then
		return nil
	end
	return Clamp(current / effectiveMax, 0, 1)
end

-- ---------------------------------------------------------------------------------------
-- The drawing
-- ---------------------------------------------------------------------------------------

function plain:UpdateOverlay(overlay, fraction)
	local control = overlay.control
	local barWidth = overlay.sizedWidth
	if not barWidth then
		local okWidth, width = pcall(overlay.bar.GetWidth, overlay.bar)
		if not okWidth or type(width) ~= "number" or width <= 0 then
			control:SetHidden(true)
			return
		end
		barWidth = width
	end
	control:SetHidden(false)

	local fill = overlay.fill
	if not fill then
		return
	end
	local fillWidth = barWidth * fraction
	if fillWidth < 1 then
		fill:SetHidden(true)
		return
	end
	fill:ClearAnchors()
	if overlay.reverse and addon:BarStyle() ~= "neo" then
		fill:SetAnchor(TOPRIGHT, control, TOPRIGHT, 0, 0)
		fill:SetAnchor(BOTTOMRIGHT, control, BOTTOMRIGHT, 0, 0)
	else
		fill:SetAnchor(TOPLEFT, control, TOPLEFT, 0, 0)
		fill:SetAnchor(BOTTOMLEFT, control, BOTTOMLEFT, 0, 0)
	end
	fill:SetWidth(fillWidth)
	fill:SetHidden(false)
end

-- ---------------------------------------------------------------------------------------
-- Liquid and Crystal
--
-- Two styles that keep the game's own bars -- frame, background, gloss, and the amount they show,
-- including the reversed bars and health's two halves -- and draw over the fill, out of nothing
-- but untextured rectangles: no art ships with this add-on.
--
--   Liquid    a see-through liquid, the way Diablo's orbs read: depth sinking into shadow, soft
--             currents drifting through it, a glow at the moving end that swells when the amount
--             changes, what was just lost draining away, rising bubbles, and a reflection with a
--             glint along the glass
--   Crystal   a cut crystal: faceted planes that catch the light in turn, a bright girdle line, and
--             sparkles that twinkle and move on
--
-- Everything is drawn through one painter, which cuts each rectangle into rows so that each row
-- can reach exactly as far as the shape allows (1.27.0). The shape is the frame's: its pointed
-- outer ends are a point at the middle of the band sloping back 45 degrees to the top and bottom,
-- and the fill's moving end has the same point, facing the way the fill moves. A row a distance d
-- from the middle of the band stops d short of a pointed end, and d short of the moving end -- so
-- the effects fill the triangles at the ends without crossing them.
--
-- Both are as solid as the game's own bars unless the opacity slider says otherwise: the body and
-- every effect over it are scaled by it (1.27.1).
--
-- Nothing here makes garbage while it runs (1.27.1, FINDINGS 57): the painter keeps its alpha as
-- numbers rather than closures, each group reuses one bounds table, and the pool of pieces has a
-- ceiling, because the client never frees a control once it is made.
--
-- Parented to the attribute container (not the StatusBar) for console visibility.
-- ---------------------------------------------------------------------------------------
addon.EFFECT_STYLES = { liquidflow = true, crystal = true }

function addon:EffectStyle()
	local style = self:BarStyle()
	return self.EFFECT_STYLES[style] and style or nil
end

local EFFECT_UPDATE_MS = 50

-- Where the effect may draw, inside one native status bar.
--
-- The status bar a console draws is ZO_PlayerAttributeStatusBar_Gamepad_Template: 64 high
-- (playerattributebartemplates.xml), with the coloured band in the middle of that texture and
-- transparent art above and below it. The bar the player sees is the 23-high container's 17, as
-- it is on keyboard. Everything used to be worked out from the 64 (FINDINGS 52).
local EFFECT_BAND_OF_CONTAINER = 17 / 23
local EFFECT_BAND_MARGIN = 0.12
local EFFECT_LEADING_EDGE = 2
-- The band is cut into this many rows wherever a slope has to be followed.
local EFFECT_ROWS = 8
-- Kept clear of the very point, so nothing touches the frame's line.
local EFFECT_TIP_INSET = 1

-- How far the effect stops short of each end of the status bar, on top of everything else.
--
-- The client's own layout leaves no room for a spill: the status bar's flat end sits exactly on the
-- inner edge of the 6-wide flat frame piece, and its pointed end 9 pixels inside a 16-wide arrow.
-- But the fill's own art may carry transparent margin at an end, so what the player sees ends
-- before the control does -- and an effect drawn to the control's edge then stands past the fill
-- (FINDINGS 63). How much, only a PS5 can say, so it is a setting measured there rather than a
-- number guessed here: "/pbhud plain margin <left> <right>".
addon.MAX_END_MARGIN = 8

function addon:EndMargins()
	local account = self:Account()
	local margins = account.endMargin
	if type(margins) ~= "table" then
		margins = { left = 0, right = 0 }
		account.endMargin = margins
	end
	return Clamp(margins.left or 0, 0, self.MAX_END_MARGIN), Clamp(margins.right or 0, 0, self.MAX_END_MARGIN)
end

function addon:SetEndMargins(left, right)
	local account = self:Account()
	if type(account.endMargin) ~= "table" then
		account.endMargin = {}
	end
	account.endMargin.left = Clamp(Round(left or 0), 0, self.MAX_END_MARGIN)
	account.endMargin.right = Clamp(Round(right or 0), 0, self.MAX_END_MARGIN)
	return true
end

local LIQUID_CURRENTS = 5
local LIQUID_BUBBLES = 4
-- How quickly a slosh settles, and how much a change in the amount stirs it.
local LIQUID_SLOSH_SETTLE_MS = 450
local LIQUID_SLOSH_GAIN = 6
-- The pale trace of what was lost: how long it waits, and how fast it drains (fraction per ms).
local LIQUID_DRAIN_HOLD_MS = 150
local LIQUID_DRAIN_RATE = 0.0009
-- A gap between updates longer than this is the bars having been hidden, not a change to show.
local LIQUID_GAP_MS = 500
-- How far a current fades out before the moving end.
local LIQUID_SOFT_EDGE = 5

local CRYSTAL_FACET = 18
local CRYSTAL_SPARKLES = 5
-- The pieces one bar section has, all built when the group is: the client never frees a control, so
-- memory is flat from the moment a style is chosen rather than creeping up as a rarer arrangement
-- needs one more. Measured over 100,000 updates (about 80 minutes) the most either style used was
-- 86; anything past the pool is dropped for that frame and counted (FINDINGS 57).
local EFFECT_MAX_PIECES = 110

-- into: a table to fill rather than a new one. The loop passes its group's own.
function plain:LiquidBounds(bar, entry, native, fraction, into)
	local width, height = native:GetDimensions()
	local container = Control(bar.container)
	local containerHeight = height
	if container then
		local _, measured = container:GetDimensions()
		if type(measured) == "number" and measured > 0 then
			containerHeight = measured
		end
	end
	local band = math.min(height, containerHeight * EFFECT_BAND_OF_CONTAINER)
	local bandTop = (height - band) / 2
	local margin = math.max(1, band * EFFECT_BAND_MARGIN)

	-- Which ends of this control are the pointed outer ends of the bar.
	local halves = #bar.controls > 1
	local isRightHalf = halves and bar.controls[2].name == entry.name

	fraction = Clamp(fraction or 0, 0, 1)
	local filled = width * fraction
	-- A full bar has no moving end to keep clear of.
	local edgeClear = fraction < 0.99 and EFFECT_LEADING_EDGE or 0

	local t = into or {}
	t.width = width
	t.top = bandTop + margin
	t.bottom = bandTop + band - margin
	t.middle = bandTop + band / 2
	t.reach = band / 2
	t.bandTop = bandTop
	t.bandBottom = bandTop + band
	t.rowHeight = band / EFFECT_ROWS
	-- A half of health meets the other in the middle, where nothing is pointed; otherwise the bar's
	-- own ends, which are pointed only where they face away from the middle of the screen.
	t.pointedLeft = (bar.pointedLeft ~= false) and not isRightHalf
	t.pointedRight = (bar.pointedRight ~= false) and (isRightHalf or not halves)
	t.marginLeft, t.marginRight = addon:EndMargins()
	t.reverse = entry.reverse and true or false
	t.fraction = fraction
	t.filled = filled
	-- Where the middle row of the fill ends.
	t.edge = entry.reverse and width - filled + edgeClear or filled - edgeClear
	t.edgeOpen = fraction > 0 and fraction < 0.99
	-- Health's right half carries on where the left half stops, so what moves along the bar is
	-- placed in one coordinate that runs the whole length of it.
	t.offset = isRightHalf and width or 0
	t.length = halves and width * 2 or width
	return t
end

-- How far a row from y0 to y1 may reach. "tube" is held by the pointed ends; "fill" by the moving
-- end as well.
local function Limits(bounds, y0, y1, fill)
	local d = math.max(math.abs(y0 - bounds.middle), math.abs(y1 - bounds.middle))
	local left = (bounds.pointedLeft and d + EFFECT_TIP_INSET or 0) + bounds.marginLeft
	local right = (bounds.pointedRight and bounds.width - d - EFFECT_TIP_INSET or bounds.width) - bounds.marginRight
	if fill then
		if bounds.reverse then
			left = math.max(left, bounds.edge + d)
		else
			right = math.min(right, bounds.edge - d)
		end
	end
	return left, right, d
end

local VERTEX_TL, VERTEX_TR = VERTEX_POINTS_TOPLEFT, VERTEX_POINTS_TOPRIGHT
local VERTEX_BL, VERTEX_BR = VERTEX_POINTS_BOTTOMLEFT, VERTEX_POINTS_BOTTOMRIGHT

local function Lighten(r, g, b, k)
	return r + (1 - r) * k, g + (1 - g) * k, b + (1 - b) * k
end

-- ---- Switches for finding a flicker --------------------------------------------------------
-- The return trace (ReturnTrace.lua) showed nothing that goes or comes back, or changes alpha, once
-- the bars are showing -- and Liquid still flickered coming back from a menu where Standard did not
-- (FINDINGS 67). So whatever it is lies in what is drawn, which no trace sees. These take one part
-- of the style away at a time, for this session only, so the PS5 can say which part it is:
-- "/pbhud plain test <part> off".
plain.TEST_PARTS = {
	"hold", "colour", "alpha", "numbers", "effect",
	"shade", "current", "bubble", "glow", "drain", "glass", "facet", "pavilion", "girdle", "sparkle",
}
plain.testOff = {}

function plain:TestOn(part)
	return not self.testOff[part]
end

-- Whether the bars' own fade has finished: true until their fragment starts to show, false from
-- then until it reports SHOWN. The effect over the fill is drawn through the fade but kept out of
-- sight until it ends: Liquid's wide pieces flickered while the group above them faded in, and on a
-- PS5 this was the way back that both stopped it and looked natural (1.27.15, FINDINGS 69).
plain.fadeDone = true

function plain:OnFade(state)
	if state == SCENE_FRAGMENT_SHOWING then
		self.fadeDone = false
	elseif state == SCENE_FRAGMENT_SHOWN or state == SCENE_FRAGMENT_HIDDEN then
		self.fadeDone = true
	end
end

-- "/pbhud plain test", "... test <part> on|off", "... test reset". Changing one starts the style
-- over, so what it had written is put back before it runs without that part.
function plain:TestCommand(part, value)
	local Line = addon.Line
	part = part and part:lower() or nil
	if part == "reset" then
		for key in pairs(self.testOff) do
			self.testOff[key] = nil
		end
	elseif part then
		local known = false
		for _, name in ipairs(self.TEST_PARTS) do
			if name == part then
				known = true
			end
		end
		if not known then
			Line("unknown part %s -- one of: %s", part, table.concat(self.TEST_PARTS, " "))
			return false
		end
		self.testOff[part] = (tostring(value):lower() == "off") or nil
	end
	if part then
		self:Stop()
		self:Refresh()
	end
	local off = {}
	for _, name in ipairs(self.TEST_PARTS) do
		if self.testOff[name] then
			off[#off + 1] = name
		end
	end
	Line("|cFF69B4%s|r test parts off: %s  (%s plain test <part> on|off, %s plain test reset)", addon.title,
		#off > 0 and table.concat(off, ", ") or "none", addon.slash, addon.slash)
	return true
end

-- ---- The painter ----------------------------------------------------------------------------
-- A pool of EFFECT_MAX_PIECES textures per bar section, built with the group, handed out in order
-- each frame and the rest hidden.
--
-- What a rectangle is painted with is set on the painter before the call, as numbers, so drawing
-- makes no garbage:
--
--   Alpha(x0, y0, x1, y1, tl, tr, bl, br)   alpha bilinear over that reference rectangle; a
--                                            constant is the same number four times
--   Fade(x0, x1, a, b)                       and multiplied by a value running from a at x0 to b
--                                            at x1 (NoFade() to stop)
--   Between(near, far)                       for the "between" limit: from the moving end to a
--                                            level beyond it

local Painter = {}
Painter.__index = Painter

function Painter:Begin(bounds)
	self.bounds = bounds
	self.used = 0
	self.fading = false
end

function Painter:Alpha(x0, y0, x1, y1, tl, tr, bl, br)
	self.ax0, self.ay0, self.ax1, self.ay1 = x0, y0, x1, y1
	self.atl, self.atr, self.abl, self.abr = tl, tr, bl, br
end

function Painter:Constant(alpha)
	self:Alpha(0, 0, 1, 1, alpha, alpha, alpha, alpha)
end

function Painter:Fade(x0, x1, a, b)
	self.fading = true
	self.fx0, self.fx1, self.fa, self.fb = x0, x1, a, b
end

function Painter:NoFade()
	self.fading = false
end

function Painter:Between(near, far)
	self.near, self.far = near, far
end

function Painter:At(x, y)
	local w, h = self.ax1 - self.ax0, self.ay1 - self.ay0
	local s = w > 0 and Clamp((x - self.ax0) / w, 0, 1) or 0
	local t = h > 0 and Clamp((y - self.ay0) / h, 0, 1) or 0
	local alpha = (self.atl * (1 - s) + self.atr * s) * (1 - t) + (self.abl * (1 - s) + self.abr * s) * t
	if self.fading then
		local span = self.fx1 - self.fx0
		local k = span ~= 0 and Clamp((x - self.fx0) / span, 0, 1) or 0
		alpha = alpha * (self.fa + (self.fb - self.fa) * k)
	end
	return alpha
end

-- How far a row may reach under a limit: "tube" (the pointed ends), "fill" (and the moving end),
-- "between" (and from the moving end to self.far).
function Painter:Limits(limit, y0, y1)
	local bounds = self.bounds
	if limit ~= "between" then
		return Limits(bounds, y0, y1, limit == "fill")
	end
	local left, right, d = Limits(bounds, y0, y1, false)
	if bounds.reverse then
		return math.max(left, bounds.width - self.far + d), math.min(right, bounds.width - self.near + d)
	end
	return math.max(left, self.near - d), math.min(right, self.far - d)
end

function Painter:Put(x0, y0, x1, y1, r, g, b, level, role, tag)
	if x1 - x0 < 0.5 or y1 - y0 < 0.25 then
		return
	end
	if tag and plain.testOff[tag] then
		return
	end
	local tl, tr, bl, br = self:At(x0, y0), self:At(x1, y0), self:At(x0, y1), self:At(x1, y1)
	if tl <= 0.002 and tr <= 0.002 and bl <= 0.002 and br <= 0.002 then
		return
	end
	if self.used >= EFFECT_MAX_PIECES then
		self.dropped = (self.dropped or 0) + 1
		return
	end
	self.used = self.used + 1
	local texture = self.pool[self.used]
	if texture.pbsLevel ~= level then
		texture:SetDrawLevel(level)
		texture.pbsLevel = level
	end
	texture.pbsLiquidRole = role
	texture.pbsTag = tag
	-- Placed by both corners, not by one corner and a size. The screen snaps each anchored edge to
	-- a pixel; with a size, the right and bottom edges were the snapped left edge plus a separately
	-- snapped width, which can land a pixel beyond where they should -- only ever to the right,
	-- which is where the PS5 showed the effect spilling past the ends (1.27.6, FINDINGS 62).
	texture:ClearAnchors()
	texture:SetAnchor(TOPLEFT, self.root, TOPLEFT, x0, y0)
	texture:SetAnchor(BOTTOMRIGHT, self.root, TOPLEFT, x1, y1)
	-- The colour goes on the vertices, so a texture used for something else last frame keeps none
	-- of it. Without per-corner colours, the average.
	if VERTEX_TL and type(texture.SetVertexColors) == "function" then
		texture:SetColor(1, 1, 1, 1)
		texture:SetVertexColors(VERTEX_TL, r, g, b, tl)
		texture:SetVertexColors(VERTEX_TR, r, g, b, tr)
		texture:SetVertexColors(VERTEX_BL, r, g, b, bl)
		texture:SetVertexColors(VERTEX_BR, r, g, b, br)
	else
		texture:SetColor(r, g, b, (tl + tr + bl + br) / 4)
	end
	texture:SetHidden(false)
end

-- Paint (x0, y0)-(x1, y1) with the alpha set above, cut to the shape. tag names what the piece is,
-- for /pbhud plain and the tests.
function Painter:Quad(x0, y0, x1, y1, r, g, b, level, limit, tag)
	local bounds = self.bounds
	y0, y1 = math.max(y0, bounds.bandTop), math.min(y1, bounds.bandBottom)
	if y1 - y0 < 0.25 or x1 - x0 < 0.25 then
		return
	end
	local role = limit == "between" and "custom" or limit
	-- Clear of every slope: one piece.
	local left, right = self:Limits(limit, y0, y1)
	if x0 >= left and x1 <= right then
		self:Put(x0, y0, x1, y1, r, g, b, level, role, tag)
		return
	end
	-- Otherwise a piece per row of the band.
	local h = bounds.rowHeight
	local y = y0
	while y < y1 - 0.001 do
		local rowEnd = math.min(y1, bounds.bandTop + (math.floor((y - bounds.bandTop) / h + 0.0001) + 1) * h)
		local rowLeft, rowRight = self:Limits(limit, y, rowEnd)
		self:Put(math.max(x0, rowLeft), y, math.min(x1, rowRight), rowEnd, r, g, b, level, role, tag)
		y = rowEnd
	end
end

function Painter:End()
	for index = self.used + 1, self.shown or 0 do
		self.pool[index]:SetHidden(true)
	end
	self.shown = self.used
	self.root:SetHidden(self.used == 0)
end

-- ---- One group per bar section --------------------------------------------------------------

function plain:EffectGroup(bar, entry, native)
	self.effectGroups = self.effectGroups or {}
	self.liquidRibbons = self.effectGroups
	local group = self.effectGroups[entry.name]
	if group then
		if group.native ~= native then
			group.control:SetParent(Control(bar.container))
			group.control:ClearAnchors()
			group.control:SetAnchor(TOPLEFT, native, TOPLEFT, 0, 0)
			group.control:SetAnchor(BOTTOMRIGHT, native, BOTTOMRIGHT, 0, 0)
			group.native = native
			group.painter.root = group.control
		end
		return group
	end
	if not WINDOW_MANAGER or not CT_TEXTURE then
		return nil
	end
	local prefix = "PBsLiquid" .. entry.name
	local root = WINDOW_MANAGER:CreateControl(prefix, Control(bar.container), CT_CONTROL)
	root:SetAnchor(TOPLEFT, native, TOPLEFT, 0, 0)
	root:SetAnchor(BOTTOMRIGHT, native, BOTTOMRIGHT, 0, 0)
	root:SetDrawTier(DT_HIGH)
	root:SetDrawLevel(1)
	local painter = setmetatable({ root = root, prefix = prefix, pool = {}, used = 0, shown = 0 }, Painter)
	for index = 1, EFFECT_MAX_PIECES do
		local texture = WINDOW_MANAGER:CreateControl(prefix .. "Piece" .. index, root, CT_TEXTURE)
		texture:SetHidden(true)
		-- Every field the painter keeps on a piece, given now: a field first set mid-fight is a
		-- little memory taken mid-fight, and a piece first used an hour in is exactly that.
		texture.pbsLevel, texture.pbsTag, texture.pbsLiquidRole = -1, false, false
		painter.pool[index] = texture
	end
	group = { control = root, native = native, painter = painter, textures = painter.pool, bounds = {} }
	self.effectGroups[entry.name] = group
	return group
end

-- How solid the effect styles are drawn: the opacity slider, 100% unless it is moved.
local function Opacity()
	return addon:PlainOpacity() / 100
end

-- ---- Liquid ---------------------------------------------------------------------------------

function plain:LiquidRibbons(bar, entry, native, fraction, now)
	local group = self:EffectGroup(bar, entry, native)
	if not group then
		return
	end
	local painter = group.painter
	local bounds = self:LiquidBounds(bar, entry, native, fraction, group.bounds)
	local top, bottom, width = bounds.top, bounds.bottom, bounds.width
	local depth = bottom - top
	fraction = bounds.fraction

	-- Back after the bars were hidden: whatever the amount did meanwhile happened out of sight, and
	-- showing it now as a slosh and a drain is a flash on the way back (1.27.3).
	if group.lastNow and now - group.lastNow > LIQUID_GAP_MS then
		group.lastFraction, group.drainLevel, group.drainSince, group.slosh = fraction, fraction, nil, 0
	end
	-- The slosh and the drain both need to know how the amount moved since last time.
	local dt = group.lastNow and Clamp(now - group.lastNow, 0, 200) or 0
	group.lastNow = now
	local moved = group.lastFraction and math.abs(fraction - group.lastFraction) or 0
	group.lastFraction = fraction
	group.slosh = math.min(1, (group.slosh or 0) * math.exp(-dt / LIQUID_SLOSH_SETTLE_MS) + moved * LIQUID_SLOSH_GAIN)
	if not group.drainLevel or fraction >= group.drainLevel then
		group.drainLevel, group.drainSince = fraction, nil
	else
		group.drainSince = group.drainSince or now
		if now - group.drainSince > LIQUID_DRAIN_HOLD_MS then
			group.drainLevel = math.max(fraction, group.drainLevel - dt * LIQUID_DRAIN_RATE)
		end
	end
	local draining = group.drainLevel - fraction

	painter:Begin(bounds)
	local r, g, b = self:PowerColour(bar)
	local seconds = now / 1000
	local lr, lg, lb = Lighten(r, g, b, 0.55)
	local A = Opacity()

	if fraction > 0 and depth >= 3 then
		-- Depth: the lower part of the liquid sinks into shadow.
		local shadeTop = top + depth * 0.35
		painter:Alpha(0, shadeTop, width, bottom, 0, 0, 0.5 * A, 0.5 * A)
		painter:Quad(0, shadeTop, width, bottom, 0, 0, 0, 1, "fill", "shade")

		-- Currents, placed along the whole bar and cut to the shape. They fade out before the
		-- moving end, where a hard edge would read as a line; they run right into the points. Each
		-- quarter of a mass is brightest at its inner corner, which is bilinear over the quarter.
		if bounds.edgeOpen then
			if bounds.reverse then
				painter:Fade(bounds.edge, bounds.edge + LIQUID_SOFT_EDGE, 0, 1)
			else
				painter:Fade(bounds.edge - LIQUID_SOFT_EDGE, bounds.edge, 1, 0)
			end
		end
		for index = 1, LIQUID_CURRENTS do
			local light = index % 3 ~= 0
			local direction = index % 2 == 0 and -1 or 1
			local speed = direction * (7 + index * 4)
			local hw = 14 + (index * 7) % 13
			local hh = depth * (0.42 + (index % 3) * 0.1)
			local travel = bounds.length + hw * 2
			local cx = ((index * 53.7 + speed * seconds) % travel) - hw - bounds.offset
			local cy = top + depth * (0.5 + 0.3 * math.sin(seconds * (0.5 + 0.11 * index) + index * 1.7))
			local k = (light and 0.42 or 0.4) * (0.8 + 0.2 * math.sin(seconds * 1.3 + index)) * A
			local cr, cg, cb = lr, lg, lb
			if not light then
				cr, cg, cb = r * 0.25, g * 0.25, b * 0.25
			end
			if cx + hw > 0 and cx - hw < width then
				local y0, y1 = cy - hh, cy + hh
				painter:Alpha(cx - hw, y0, cx, cy, 0, 0, 0, k)
				painter:Quad(cx - hw, y0, cx, cy, cr, cg, cb, 2, "fill", "current")
				painter:Alpha(cx, y0, cx + hw, cy, 0, 0, k, 0)
				painter:Quad(cx, y0, cx + hw, cy, cr, cg, cb, 2, "fill", "current")
				painter:Alpha(cx - hw, cy, cx, y1, 0, k, 0, 0)
				painter:Quad(cx - hw, cy, cx, y1, cr, cg, cb, 2, "fill", "current")
				painter:Alpha(cx, cy, cx + hw, y1, k, 0, 0, 0)
				painter:Quad(cx, cy, cx + hw, y1, cr, cg, cb, 2, "fill", "current")
			end
		end
		painter:NoFade()

		-- Bubbles: beads with a point of light that rise and fade at the top.
		for index = 1, LIQUID_BUBBLES do
			local period = 1.8 + index * 0.35
			local progress = (seconds / period + index * 0.37) % 1
			local size = 1.8 + 0.6 * progress
			local y = bottom - size - (depth - size) * progress
			local left, right = Limits(bounds, y, y + size, true)
			if right - left >= size + 1 then
				local x = left + (right - left) * ((index * 0.29 + 0.11) % 1) + math.sin(seconds * 1.3 + index) * 2
				x = Clamp(x, left, right - size)
				local alpha = math.sin(math.pi * progress) * A
				painter:Constant(0.55 * alpha)
				painter:Quad(x, y, x + size, y + size, lr, lg, lb, 3, "fill", "bubble")
				painter:Constant(0.9 * alpha)
				painter:Quad(x, y, x + math.min(1, size), y + math.min(1, size), 1, 1, 1, 4, "fill", "bubble")
			end
		end

		-- A glow at the moving end, which swells when the amount changes. No line: a bright edge
		-- right beside the point of a regenerating bar flickered as it came and went (1.27.0). It
		-- fades out as the moving end reaches the full end, so it is gone before it gets there.
		if bounds.edgeOpen then
			local toFull = width - bounds.filled
			local fullPointed = bounds.reverse and bounds.pointedLeft or (not bounds.reverse and bounds.pointedRight)
			-- Gone within a band's width of the full end, whole a band's width before that.
			local nearFull = fullPointed and Clamp((toFull - bounds.reach * 2) / (bounds.reach * 2), 0, 1) or 1
			local glowAlpha = (0.3 + group.slosh * 0.35) * A * nearFull
			local glowWidth = 8 + group.slosh * 6
			if glowAlpha > 0.005 then
				if bounds.reverse then
					painter:Alpha(bounds.edge, top, bounds.edge + glowWidth, bottom, glowAlpha, 0, glowAlpha, 0)
					painter:Quad(bounds.edge, top, bounds.edge + glowWidth, bottom, lr, lg, lb, 4, "fill", "glow")
				else
					painter:Alpha(bounds.edge - glowWidth, top, bounds.edge, bottom, 0, glowAlpha, 0, glowAlpha)
					painter:Quad(bounds.edge - glowWidth, top, bounds.edge, bottom, lr, lg, lb, 4, "fill", "glow")
				end
			end
		end
	end

	-- What was just lost, draining away beyond the moving end. Both its ends have the shape --
	-- where the liquid now stops and where it stopped before -- and it fades to nothing at the far
	-- end.
	if draining > 0.002 then
		local alpha = 0.5 * Clamp(draining * 10, 0, 1) * A
		local near, far = bounds.filled, width * group.drainLevel
		painter:Between(near, far)
		if bounds.reverse then
			painter:Alpha(width - far, top, width - near, bottom, 0, alpha, 0, alpha)
			painter:Quad(width - far, top, width - near + bounds.reach, bottom, lr, lg, lb, 2, "between", "drain")
		else
			painter:Alpha(near, top, far, bottom, alpha, 0, alpha, 0)
			painter:Quad(near - bounds.reach, top, far, bottom, lr, lg, lb, 2, "between", "drain")
		end
	end

	-- Glass: a reflection along the top of the whole tube, and a glint that crosses it -- while
	-- there is anything in it to see through.
	if fraction > 0 or draining > 0.002 then
		local glassTop = bounds.bandTop + math.max(1, depth * 0.08)
		painter:Constant(0.16 * A)
		painter:Quad(0, glassTop, width, glassTop + 1.2, 1, 1, 1, 6, "tube", "glass")
		local sweep = bounds.length + 240
		local glint = ((seconds * 70) % sweep) - 120 - bounds.offset
		painter:Alpha(glint - 16, 0, glint, 1, 0, 0.5 * A, 0, 0.5 * A)
		painter:Quad(glint - 16, glassTop, glint, glassTop + 2, 1, 1, 1, 6, "tube", "glass")
		painter:Alpha(glint, 0, glint + 16, 1, 0.5 * A, 0, 0.5 * A, 0)
		painter:Quad(glint, glassTop, glint + 16, glassTop + 2, 1, 1, 1, 6, "tube", "glass")
	end

	painter:End()
end

-- ---- Crystal --------------------------------------------------------------------------------

-- The same numbers every time for the same cycle, so sparkles move on without flickering.
local function Hash(n)
	local x = math.sin(n * 12.9898) * 43758.5453
	return x - math.floor(x)
end

function plain:CrystalFacets(bar, entry, native, fraction, now)
	local group = self:EffectGroup(bar, entry, native)
	if not group then
		return
	end
	local painter = group.painter
	local bounds = self:LiquidBounds(bar, entry, native, fraction, group.bounds)
	local top, bottom, width = bounds.top, bounds.bottom, bounds.width
	local depth = bottom - top
	local seconds = now / 1000

	painter:Begin(bounds)
	if bounds.fraction <= 0 or depth < 3 then
		painter:End()
		return
	end
	local r, g, b = self:PowerColour(bar)
	local lr, lg, lb = Lighten(r, g, b, 0.7)
	local dr, dg, db = r * 0.2, g * 0.2, b * 0.2
	local girdle = top + depth * 0.42
	local A = Opacity()

	-- Facets: planes along the whole bar, the upper ones catching light and the lower ones in the
	-- stone's own darker colour, each lit from a corner that alternates, and each brightening in
	-- turn as though the crystal were turning in the light.
	local first = math.floor(bounds.offset / CRYSTAL_FACET)
	local last = math.ceil((bounds.offset + width) / CRYSTAL_FACET)
	for k = first, last do
		local x0 = k * CRYSTAL_FACET - bounds.offset
		local x1 = x0 + CRYSTAL_FACET
		if x1 > 0 and x0 < width then
			local shine = 0.55 + 0.45 * math.sin(seconds * 0.9 - k * 0.8)
			local bright = (0.16 + 0.32 * shine) * A
			if k % 2 == 0 then
				painter:Alpha(x0, top, x1, girdle, bright, bright * 0.25, bright * 0.45, 0.02 * A)
				painter:Quad(x0, top, x1, girdle, lr, lg, lb, 2, "fill", "facet")
				painter:Alpha(x0, girdle, x1, bottom, 0.08 * A, 0.42 * A, 0.3 * A, 0.6 * A)
				painter:Quad(x0, girdle, x1, bottom, dr, dg, db, 2, "fill", "pavilion")
			else
				painter:Alpha(x0, top, x1, girdle, bright * 0.25, bright, 0.02 * A, bright * 0.45)
				painter:Quad(x0, top, x1, girdle, lr, lg, lb, 2, "fill", "facet")
				painter:Alpha(x0, girdle, x1, bottom, 0.42 * A, 0.08 * A, 0.6 * A, 0.3 * A)
				painter:Quad(x0, girdle, x1, bottom, dr, dg, db, 2, "fill", "pavilion")
			end
		end
	end

	-- The girdle: a thin bright line where the upper and lower facets meet.
	painter:Constant(0.28 * A)
	painter:Quad(0, girdle - 0.5, width, girdle + 0.5, 1, 1, 1, 3, "fill", "girdle")

	-- Sparkles: small four-pointed stars that twinkle and then move on.
	for index = 1, CRYSTAL_SPARKLES do
		local period = 1.3 + index * 0.23
		local phase = seconds / period + index * 0.41
		local cycle = math.floor(phase)
		local t = phase - cycle
		local alpha = math.max(0, math.sin(math.pi * t)) ^ 3 * A
		local y = top + 2 + (depth - 4) * Hash(index * 7 + cycle)
		local left, right = Limits(bounds, y - 1.5, y + 1.5, true)
		if right - left > 5 and alpha > 0.02 then
			local x = left + 1.5 + (right - left - 3) * Hash(index * 13 + cycle * 3)
			painter:Constant(0.95 * alpha)
			painter:Quad(x - 1.5, y - 0.5, x + 1.5, y + 0.5, 1, 1, 1, 6, "fill", "sparkle")
			painter:Quad(x - 0.5, y - 1.5, x + 0.5, y + 1.5, 1, 1, 1, 6, "fill", "sparkle")
		end
	end

	-- A crisp reflection along the top of the stone.
	local glassTop = bounds.bandTop + math.max(1, depth * 0.08)
	painter:Constant(0.22 * A)
	painter:Quad(0, glassTop, width, glassTop + 1, 1, 1, 1, 6, "tube", "glass")

	painter:End()
end

-- ---- Running them ---------------------------------------------------------------------------

-- How solid the whole bar is in these styles. The slider used to reach only the fill's colour and
-- the effects over it, and the game's own background, frame and gloss stayed solid -- so lowering it
-- let a dark, solid background show through the fill, and nothing behind the bar ever showed
-- (1.27.2, FINDINGS 58). Now the background, the three frame pieces and the status bars themselves
-- (and with them their gloss) take the slider's alpha. Written again whenever it differs: the
-- client sets the background back to 1 in its armour and possession modules.
function plain:EffectAlpha(bar, alpha)
	self.effectAlphas = self.effectAlphas or {}
	local controls = bar.effectAlphaControls
	if not controls then
		controls = {}
		for _, suffix in ipairs(DRESSING) do
			controls[#controls + 1] = bar.container .. suffix
		end
		for _, entry in ipairs(bar.controls) do
			controls[#controls + 1] = entry.name
		end
		bar.effectAlphaControls = controls
	end
	for _, name in ipairs(controls) do
		local control = Control(name)
		if control and type(control.SetAlpha) == "function" and type(control.GetAlpha) == "function" then
			-- Its own alpha: the drawn one moves with every fade of the group above it.
			local current = addon.OwnAlpha(control) or 1
			if self.effectAlphas[control] == nil then
				self.effectAlphas[control] = current
			end
			if math.abs(current - alpha) > 0.001 then
				addon:Write("effect alpha", control.SetAlpha, control, alpha)
			end
		end
	end
end

function plain:RestoreLiquid()
	for _, group in pairs(self.effectGroups or {}) do
		group.control:SetHidden(true)
	end
	for control, colours in pairs(self.effectColours or {}) do
		addon:Write("effect colour", control.SetGradientColors, control, unpack(colours))
	end
	self.effectColours = nil
	for control, original in pairs(self.effectAlphas or {}) do
		addon:Write("effect alpha", control.SetAlpha, control, original)
		self.effectAlphas[control] = nil
	end
end

function plain:UpdateLiquid(style)
	style = style or "liquidflow"
	if not self.effectColours then
		self:HideAll()
		self:DressAll(false)
		self:RaiseAllNumbers(false)
		self:BlankAll(false)
		self.effectColours = {}
	end
	local now = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
	local wave = (math.sin(now / 1300) + 1) / 2
	local opacity = Opacity()
	for _, bar in ipairs(self.bars) do
		local fraction = self:DrawnFraction(bar)
		if self:TestOn("numbers") then
			self:RaiseNumbers(bar, true)
		end
		if bar.powerType == nil then
			bar.powerType = _G["COMBAT_MECHANIC_FLAGS_" .. bar.power:upper()] or false
		end
		local powerType = bar.powerType
		if self:TestOn("alpha") then
			self:EffectAlpha(bar, opacity)
		end
		local gradient = powerType and ZO_POWER_BAR_GRADIENT_COLORS and ZO_POWER_BAR_GRADIENT_COLORS[powerType]
		if gradient and gradient[1] and gradient[2] then
			local r, g, b, a = gradient[1]:UnpackRGBA()
			local r2, g2, b2, a2 = gradient[2]:UnpackRGBA()
			for _, entry in ipairs(bar.controls) do
				local control = Control(entry.name)
				if control and type(control.SetGradientColors) == "function" then
					self.effectColours[control] = self.effectColours[control] or { r, g, b, a, r2, g2, b2, a2 }
					local drawEffect, writeColour = self:TestOn("effect"), self:TestOn("colour")
					local holdEffect = not self.fadeDone
					if drawEffect and holdEffect then
						-- Drawn, so it is ready, and kept out of sight until the fade ends.
						if style == "crystal" then
							self:CrystalFacets(bar, entry, control, fraction, now)
						else
							self:LiquidRibbons(bar, entry, control, fraction, now)
						end
						drawEffect = false
					end
					if not drawEffect then
						local group = self.effectGroups and self.effectGroups[entry.name]
						if group then
							group.control:SetHidden(true)
						end
					end
					if style == "crystal" then
						if drawEffect then
							self:CrystalFacets(bar, entry, control, fraction, now)
						end
						-- Clear and cool: the power's colour lifted towards white.
						local k1, k2 = 0.22 + wave * 0.06, 0.45
						if writeColour then addon:Write("effect colour", control.SetGradientColors, control,
							r + (1 - r) * k1, g + (1 - g) * k1, b + (1 - b) * k1, a,
							r2 + (1 - r2) * k2, g2 + (1 - g2) * k2, b2 + (1 - b2) * k2, a2) end
					else
						if drawEffect then
							self:LiquidRibbons(bar, entry, control, fraction, now)
						end
						local dark, light = 0.60 + wave * 0.18, 0.12 + (1 - wave) * 0.18
						if writeColour then addon:Write("effect colour", control.SetGradientColors, control,
							r * dark, g * dark, b * dark, a,
							r2 + (1 - r2) * light, g2 + (1 - g2) * light, b2 + (1 - b2) * light, a2) end
					end
				end
			end
		end
	end
end

-- The frame clock, for holding the bars back (below).
local function FrameNow()
	return GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
end

function plain:Update()
	self:UpdateStyle()
	-- Counted only while the loop runs: an update made for a setting changed in the menu does not
	-- bring the bars back early.
	if self.holding and self.running then
		self.resumeUpdates = (self.resumeUpdates or 0) + 1
		self:CheckReveal(FrameNow())
	end
end

function plain:UpdateStyle()
	local effect = addon:EffectStyle()
	if effect then
		self:UpdateLiquid(effect)
		return
	end
	if self.effectColours then self:RestoreLiquid() end
	for _, bar in ipairs(self.bars) do
		local fraction = self:Fraction(bar)
		self:Dress(bar, true)
		self:RaiseNumbers(bar, true)
		local sized = addon:BarSizeIsOwn(bar)
		for _, entry in ipairs(bar.controls) do
			local overlay = self:Overlay(bar, entry)
			if overlay then
				self:AnchorOverlay(overlay, bar)
				self:ColourOverlay(bar, overlay)
				self:BlankClientBar(bar, overlay, sized)
				if addon:BarStyle() == "neo" and bar.key == "health" and not entry.reverse then
					-- The left overlay now covers the full health bar. Keep the other
					-- native half blanked, without drawing a duplicate track or border.
					overlay.control:SetHidden(true)
				elseif fraction then
					self:UpdateOverlay(overlay, fraction)
				else
					overlay.control:SetHidden(true)
				end
			end
		end
		self:AlignNumbers(bar, addon:BarsAreMuraHige())
	end
end

-- ---------------------------------------------------------------------------------------
-- What the plain style is really doing
-- ---------------------------------------------------------------------------------------

function plain:PrintStatus()
	local Line = addon.Line
	Line("|cFF69B4%s|r -- the bars this add-on draws", addon.title)
	Line("  style=%s opacity=%d%% outline=%s running=%s hud=%s", addon:BarStyle(), addon:PlainOpacity(),
		tostring(addon:PlainBorder()), tostring(self.running == true), tostring(self.hudShown ~= false))
	local log = self.returnLog
	if log then
		Line("  last return from a menu: bars shown %d ms into the fade, after %d draw(s)%s  (%d return(s))",
			Round(log.shownAfter or 0), log.updates or 0, log.byFailsafe and ", by the failsafe" or "", log.count or 0)
	end
	Line("  held back now=%s  follows the bars' own fragment=%s", tostring(self.holding == true), tostring(addon.plainFollowsBars == true))
	local marginLeft, marginRight = addon:EndMargins()
	Line("  end margins: left %d right %d  (%s plain margin <left> <right>)", marginLeft, marginRight, addon.slash)
	-- Where the game's own pieces really are, so a spill past an end can be measured rather than
	-- guessed at: everything is given as an offset from the container's own edges.
	for _, bar in ipairs(self.bars) do
		local container = Control(bar.container)
		if container then
			local left, _, width = addon:ScreenRect(container)
			if left then
				local right = left + width
				Line("|cFF69B4  %s|r container %d wide", bar.key, Round(width))
				local function Place(what, control)
					if not control then
						return
					end
					local pieceLeft, _, pieceWidth = addon:ScreenRect(control)
					if pieceLeft then
						Line("      %s: %.1f in from the left, %.1f in from the right, %d wide", what,
							pieceLeft - left, right - (pieceLeft + pieceWidth), Round(pieceWidth))
					end
				end
				for _, entry in ipairs(bar.controls) do
					Place("fill", Control(entry.name))
				end
				Place("FrameLeft", Control(bar.container .. "FrameLeft"))
				Place("FrameRight", Control(bar.container .. "FrameRight"))
			end
		end
	end
	if addon:BarStyle() == "standard" then
		Line("  the style is Standard, so nothing is drawn. Set it in the settings panel, or")
		Line("  |cFFFFFF%s style plain|r", addon.slash)
	end

	for _, bar in ipairs(self.bars) do
		local fraction = self:Fraction(bar)
		Line("|cFF69B4  %s|r  full=%s", bar.key, fraction and string.format("%d%%", Round(fraction * 100)) or "unknown")
		for _, entry in ipairs(bar.controls) do
			local barControl = Control(entry.name)
			if not barControl then
				Line("    %s: not on this client", entry.name)
			else
				local okWidth, width = pcall(barControl.GetWidth, barControl)
				local okAlpha, alpha = pcall(barControl.GetAlpha, barControl)
				local overlay = self.overlays[entry.name]
				Line("    %s: bar %s wide, alpha=%s", entry.name, okWidth and tostring(Round(width)) or "?",
					okAlpha and string.format("%.2f", alpha) or "?")
				-- Liquid's geometry, so a PS5 can confirm the band it draws in: the status bar's
				-- own height (64 on a console), the container's, and where the effect goes.
				if addon:EffectStyle() then
					local okSize, nativeWidth, nativeHeight = pcall(barControl.GetDimensions, barControl)
					local okBounds, bounds = pcall(self.LiquidBounds, self, bar, entry, barControl, fraction or 0)
					local group = self.effectGroups and self.effectGroups[entry.name]
					if okSize and okBounds then
						Line("      %s: control %dx%d, band y %.1f-%.1f, moving end %.1f, pieces %d, shown=%s",
							addon:EffectStyle(), Round(nativeWidth), Round(nativeHeight), bounds.top, bounds.bottom, bounds.edge,
							group and group.painter.used or 0, tostring(group ~= nil and not group.control:IsHidden()))
						local background = Control(bar.container .. "BgContainer")
						local frame = Control(bar.container .. "FrameCenter")
						Line("      own alpha: bar %.2f, background %s, frame %s (slider %d%%)", addon.OwnAlpha(barControl) or -1,
							background and string.format("%.2f", addon.OwnAlpha(background) or -1) or "?",
							frame and string.format("%.2f", addon.OwnAlpha(frame) or -1) or "?", addon:PlainOpacity())
					end
				end
				if overlay then
					local okFill, fillWidth = pcall(overlay.fill.GetWidth, overlay.fill)
					Line("      rectangle: hidden=%s, fill %s wide, fills %s", tostring(overlay.control:IsHidden()),
						okFill and tostring(Round(fillWidth)) or "?", overlay.reverse and "leftwards" or "rightwards")
					local numbers = Control(bar.container .. NUMBERS)
					if numbers and type(numbers.GetDrawTier) == "function" then
						local okTier, tier = pcall(numbers.GetDrawTier, numbers)
						local okLevel, level = pcall(numbers.GetDrawLevel, numbers)
						Line("      numbers: tier=%s level=%s (lifted over the rectangle=%s)",
							okTier and tostring(tier) or "?", okLevel and tostring(level) or "?",
							tostring(self.numbers[bar.key] ~= nil))
					end
				else
					Line("      rectangle: |cFF4040not built|r")
				end
			end
		end
	end

	if addon.writeErrors and addon.writeErrors.PBsConsoleHudCustomizerPlainBar then
		Line("  |cFF4040the template was refused|r: %s", tostring(addon.writeErrors.PBsConsoleHudCustomizerPlainBar))
	end
	Line("  the bars themselves fade out when they are full and you are out of combat, and this")
	Line("  is drawn on them -- so check it with a bar part-empty, or in a fight.")
end

-- ---------------------------------------------------------------------------------------
-- The loop
-- ---------------------------------------------------------------------------------------

function plain:Start()
	if self.running or not addon:PlainWanted() or self.hudShown == false then
		return false
	end
	-- Coming back from a pause the look is still on the bars; the caches of what was last written
	-- are dropped so that anything the client put back while they were hidden is written again.
	if self.paused then
		self.paused = false
		self.hidden = {}
		self.blanked = {}
	end
	if self.holding then
		self.resumeUpdates = 0
		self.holdSince = FrameNow()
		if type(EVENT_MANAGER.RegisterForUpdate) == "function" then
			EVENT_MANAGER:RegisterForUpdate(addon.name .. "PlainReveal", 100, function()
				plain:CheckReveal(FrameNow())
			end)
			self.revealFailsafe = true
		end
	end
	if not EVENT_MANAGER or type(EVENT_MANAGER.RegisterForUpdate) ~= "function" then
		return false
	end
	EVENT_MANAGER:RegisterForUpdate(addon.name .. "Plain", addon:EffectStyle() and EFFECT_UPDATE_MS or UPDATE_INTERVAL_MS, function()
		plain:Update()
	end)
	self.running = true
	self:Update()
	return true
end

-- ---------------------------------------------------------------------------------------
-- Holding the bars back until the style is on them
--
-- 1.27.3 stopped putting the game's look back while a menu was open, and it still flickered on the
-- way back (FINDINGS 60). So the three bars are kept hidden from the moment they are hidden until
-- the style has been drawn on them twice after they start to show again -- about 50 ms into the
-- 250 ms fade-in -- and only then shown. The hidden flag on the three containers is the one thing
-- here the client never writes: the fragment fades the group above them, and the contextual
-- fading animates their alpha. Only a container this add-on hid is shown again, and a failsafe
-- shows them after 600 ms whatever happens.
-- ---------------------------------------------------------------------------------------
local REVEAL_AFTER_UPDATES = 2
local REVEAL_FAILSAFE_MS = 600

function plain:HoldBars()
	self.heldBars = self.heldBars or {}
	for _, bar in ipairs(self.bars) do
		local container = Control(bar.container)
		-- Its own flag: the group above it is already hidden when this runs, so the drawn state
		-- always said "hidden" and nothing was ever held back (FINDINGS 65).
		if container and type(container.SetHidden) == "function" and type(container.IsHidden) == "function"
			and not addon.OwnHidden(container) then
			addon:Write("hold bars", container.SetHidden, container, true)
			self.heldBars[bar.container] = container
		end
	end
	self.holding = next(self.heldBars) ~= nil
	self.resumeUpdates = 0
	self.holdSince = nil
end

function plain:RevealBars()
	if self.holding and addon.returnTrace then
		addon.returnTrace:Event("revealed")
	end
	-- What the last return from a menu looked like, for /pbhud plain: the one measurement to ask for
	-- if the bars still flicker.
	if self.holding and self.holdSince then
		local log = self.returnLog or {}
		self.returnLog = log
		log.shownAfter = FrameNow() - self.holdSince
		log.updates = self.resumeUpdates or 0
		log.byFailsafe = (self.resumeUpdates or 0) < REVEAL_AFTER_UPDATES
		log.count = (log.count or 0) + 1
	end
	for name, container in pairs(self.heldBars or {}) do
		addon:Write("hold bars", container.SetHidden, container, false)
		self.heldBars[name] = nil
	end
	self.holding = false
	if EVENT_MANAGER and self.revealFailsafe then
		EVENT_MANAGER:UnregisterForUpdate(addon.name .. "PlainReveal")
		self.revealFailsafe = false
	end
end

-- Called after every update while the bars are held, and by the failsafe.
function plain:CheckReveal(now)
	if not self.holding then
		return false
	end
	local drawn = (self.resumeUpdates or 0) >= REVEAL_AFTER_UPDATES
	if drawn or (self.holdSince and now - self.holdSince >= REVEAL_FAILSAFE_MS) then
		self:RevealBars()
		return true
	end
	return false
end

-- The bars are hidden: stop drawing, and leave the look on them. Putting the game's own look back
-- here is what made the bars flash as they came back -- they faded in as the game draws them, and
-- then changed (1.27.3, FINDINGS 59). Only a change of style, or the add-on being switched off,
-- takes the look away (Stop).
function plain:Pause()
	if not self.running then
		return false
	end
	EVENT_MANAGER:UnregisterForUpdate(addon.name .. "Plain")
	self.running = false
	self.paused = true
	-- Hidden anyway; kept hidden until the style is back on them.
	if self:TestOn("hold") then
		self:HoldBars()
	end
	return true
end

function plain:Stop()
	if not self.running and not self.paused then
		return false
	end
	if self.running then
		EVENT_MANAGER:UnregisterForUpdate(addon.name .. "Plain")
	end
	self.running = false
	self.paused = false
	self:RevealBars()
	self:RestoreLiquid()
	self:HideAll()
	self:DressAll(false)
	self:RaiseAllNumbers(false)
	self:BlankAll(false)
	return true
end

function plain:Refresh()
	-- A change between the drawn styles and the effect styles, or from one effect to the other,
	-- starts over: the loop runs at another rate, and the other style's pieces must go.
	local effect = addon:EffectStyle() or false
	if (self.running or self.paused) and self.wasEffect ~= effect then self:Stop() end
	self.wasEffect = effect
	if addon:PlainWanted() and self.hudShown ~= false then
		self:Restyle()
		if self.running then
			self:Update()
		else
			self:Start()
		end
	elseif addon:PlainWanted() and self.paused then
		-- A setting changed in the menu while the bars are hidden: brought up to date now, so they
		-- come back already showing it.
		self:Restyle()
		self:Update()
	else
		self:Stop()
	end
end

function plain:OnHudStateChange(shown)
	self.hudShown = shown and true or false
	if shown then
		self:Refresh()
	else
		self:Pause()
	end
end
