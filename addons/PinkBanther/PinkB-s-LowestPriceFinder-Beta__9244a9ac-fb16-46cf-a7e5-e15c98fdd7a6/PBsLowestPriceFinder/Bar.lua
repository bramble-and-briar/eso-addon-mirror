PBsLowestPriceFinder = PBsLowestPriceFinder or {}
local ADDON = PBsLowestPriceFinder

---------------------------------------------------------------------------------------------------
-- The progress bar
--
-- What a search says about itself goes here, not into the chat: a line of text over a bar that fills as
-- the (store, item) searches finish. It is up while a search runs, shows the outcome for a few seconds
-- afterwards (red text when something failed), and also carries the one-line notices a search used to
-- print (nothing to search, trader closed, stopped by an error...). It is shown whether or not the
-- result panel is switched on. It takes no input, like the panel.
--
-- Only fonts the console UI is known to have loaded are used, as in the panel.
---------------------------------------------------------------------------------------------------

local bar = { shown = false, hideAt = nil }
ADDON.bar = bar

local NAME = "PBsLowestPriceFinderBar"
local FONT = "ZoFontGamepad22"
local PADDING = 14
local GAP = 8
local TRACK_HEIGHT = 10
local MIN_WIDTH = 520
local MAX_WIDTH = 1100
local TOP_OFFSET = 50
local UPDATE_MS = 250
local HOLD_DONE_SEC = 8
local HOLD_NOTE_SEC = 6

local COLORS = {
	normal = { 1, 1, 1 },
	bad = { 1, 0.55, 0.55 },
	fill = { 1, 0.41, 0.71 },
}

local function Now()
	return GetFrameTimeMilliseconds()
end

function bar:Create()
	if self.control then
		return self.control
	end
	if not WINDOW_MANAGER or not GuiRoot then
		return nil
	end
	local top = WINDOW_MANAGER:CreateTopLevelWindow(NAME)
	top:SetHidden(true)
	top:SetMouseEnabled(false)
	top:SetMovable(false)
	top:SetDrawLayer(DL_OVERLAY)
	top:SetDrawTier(DT_MEDIUM)
	self.control = top

	local back = WINDOW_MANAGER:CreateControl(NAME .. "Back", top, CT_TEXTURE)
	back:SetColor(0, 0, 0, 0.7)
	back:SetAnchorFill(top)

	-- measures text without the size limits the visible label has
	local probe = WINDOW_MANAGER:CreateControl(NAME .. "Probe", GuiRoot, CT_LABEL)
	probe:SetHidden(true)
	self.probe = probe

	local label = WINDOW_MANAGER:CreateControl(NAME .. "Text", top, CT_LABEL)
	label:SetFont(FONT)
	label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	label:SetMaxLineCount(2)
	self.label = label

	local track = WINDOW_MANAGER:CreateControl(NAME .. "Track", top, CT_TEXTURE)
	track:SetColor(0.3, 0.3, 0.3, 0.9)
	self.track = track

	local fill = WINDOW_MANAGER:CreateControl(NAME .. "Fill", top, CT_TEXTURE)
	fill:SetColor(COLORS.fill[1], COLORS.fill[2], COLORS.fill[3], 1)
	self.fill = fill

	top:SetHandler("OnUpdate", function()
		local now = Now()
		if now < (self.nextUpdate or 0) then
			return
		end
		self.nextUpdate = now + UPDATE_MS
		self:Tick(now)
	end)
	return top
end

-- Draws the text and, when `fraction` is a number, the bar under it (nil: text only).
function bar:Render(text, fraction, bad)
	local top = self:Create()
	if not top then
		return
	end
	local label, track, fill, probe = self.label, self.track, self.fill, self.probe
	probe:SetFont(FONT)
	local height = type(probe.GetFontHeight) == "function" and probe:GetFontHeight() or 0
	if type(height) ~= "number" or height <= 0 then
		height = math.ceil(22 * 1.3)
	end
	probe:SetText(text)
	local width = type(probe.GetTextWidth) == "function" and probe:GetTextWidth() or nil
	if type(width) ~= "number" or width <= 0 then
		width = MIN_WIDTH
	end
	label:SetFont(FONT)
	label:SetText(text)
	local total = math.min(MAX_WIDTH, math.max(MIN_WIDTH, math.ceil(width) + PADDING * 2))
	local inner = total - PADDING * 2
	local lines = width > inner and 2 or 1

	local color = bad and COLORS.bad or COLORS.normal
	label:SetColor(color[1], color[2], color[3], 1)
	label:SetDimensions(inner, height * lines)
	label:ClearAnchors()
	label:SetAnchor(TOPLEFT, top, TOPLEFT, PADDING, PADDING)

	local y = PADDING + height * lines
	if type(fraction) == "number" then
		fraction = math.max(0, math.min(1, fraction))
		local barY = y + GAP
		track:SetDimensions(inner, TRACK_HEIGHT)
		track:ClearAnchors()
		track:SetAnchor(TOPLEFT, top, TOPLEFT, PADDING, barY)
		track:SetHidden(false)
		local filled = math.floor(inner * fraction)
		if filled > 0 then
			fill:SetDimensions(filled, TRACK_HEIGHT)
			fill:ClearAnchors()
			fill:SetAnchor(TOPLEFT, top, TOPLEFT, PADDING, barY)
			fill:SetHidden(false)
		else
			fill:SetHidden(true)
		end
		y = barY + TRACK_HEIGHT
	else
		track:SetHidden(true)
		fill:SetHidden(true)
	end
	top:SetDimensions(total, y + PADDING)
	top:ClearAnchors()
	top:SetAnchor(TOP, GuiRoot, TOP, 0, TOP_OFFSET)
	top:SetHidden(false)
	self.shown = true
	self.text = text
	self.fraction = type(fraction) == "number" and fraction or nil
	self.bad = bad and true or false
end

-- A search is running: stays up until the search ends.
function bar:Progress(text, fraction)
	self.hideAt = nil
	self:Render(text, fraction, false)
end

-- A search has ended: the bar full, held for a few seconds. `bad` colours the text.
function bar:Finish(text, bad)
	self:Render(text, 1, bad)
	self.hideAt = Now() + HOLD_DONE_SEC * 1000
end

-- A line with no bar under it, held for `seconds` (a notice, or the reason a search could not start).
function bar:Note(text, seconds, bad)
	self:Render(text, nil, bad)
	self.hideAt = Now() + (seconds or HOLD_NOTE_SEC) * 1000
end

function bar:Hide()
	self.shown = false
	self.hideAt = nil
	if self.control then
		self.control:SetHidden(true)
	end
end

-- While a search runs the bar stays; afterwards it goes when its time is up.
function bar:Tick(now)
	if not self.shown then
		return
	end
	local scan = ADDON.scan
	if scan and scan.run then
		return
	end
	if self.hideAt and now >= self.hideAt then
		self:Hide()
	end
end
