PBsLowestPriceFinder = PBsLowestPriceFinder or {}
local ADDON = PBsLowestPriceFinder

---------------------------------------------------------------------------------------------------
-- The result panel
--
-- A box with the cheapest store of each watched item and where its trader is. It is up while a search
-- runs and for a while after (and stays up when the guild trader is closed, so it can be read while
-- walking there). It takes no input, so on a console it cannot take a button from the game; the
-- guild store's own screen is not touched.
--
-- Only fonts the console UI is known to have loaded are used (the ones PB's HPS Checker's HUD uses):
-- a face nothing else draws with has to be built on use, and that has crashed a PS5 before.
---------------------------------------------------------------------------------------------------

local panel = { shown = false, hideAt = nil }
ADDON.panel = panel

local NAME = "PBsLowestPriceFinderPanel"
local MAX_LINES = 14
local PADDING = 14
local LINE_PADDING = 4
local MIN_WIDTH = 520
local MAX_WIDTH = 1100
local UPDATE_MS = 500

local SIZES = {
	{ title = "ZoFontGamepadBold22", row = "ZoFontGamepad20" },
	{ title = "ZoFontGamepadBold25", row = "ZoFontGamepad20" },
	{ title = "ZoFontGamepadBold27", row = "ZoFontGamepad22" },
	{ title = "ZoFontGamepadBold34", row = "ZoFontGamepad22" },
	{ title = "ZoFontGamepadBold34", row = "ZoFontGamepad25" },
}
panel.NUM_SIZES = #SIZES

local COLORS = {
	title = { 1, 0.41, 0.71 },
	head = { 1, 1, 1 },
	sub = { 0.75, 0.85, 1 },
	dim = { 0.7, 0.7, 0.7 },
}

local function Now()
	return GetFrameTimeMilliseconds()
end

-- How tall the client draws one line of a font; the number in the name when it does not say. (The
-- Japanese client draws the named gamepad fonts smaller than their number, so layout is from this.)
function panel:FontHeight(font)
	local probe = self.probe
	probe:SetFont(font)
	local height = type(probe.GetFontHeight) == "function" and probe:GetFontHeight() or 0
	if type(height) ~= "number" or height <= 0 then
		height = math.ceil((tonumber(font:match("(%d+)$")) or 22) * 1.3)
	end
	return height
end

function panel:TextWidth(font, text)
	local probe = self.probe
	probe:SetFont(font)
	probe:SetText(text)
	local width = type(probe.GetTextWidth) == "function" and probe:GetTextWidth() or nil
	if type(width) ~= "number" or width <= 0 then
		return nil
	end
	return width
end

function panel:Size()
	local size = math.floor(tonumber(ADDON.sv and ADDON.sv.panelSize) or ADDON.DEFAULTS.panelSize)
	return math.max(1, math.min(#SIZES, size))
end

function panel:Create()
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

	local fill = WINDOW_MANAGER:CreateControl(NAME .. "Fill", top, CT_TEXTURE)
	fill:SetColor(0, 0, 0, 0.7)
	fill:SetAnchorFill(top)

	local probe = WINDOW_MANAGER:CreateControl(NAME .. "Probe", GuiRoot, CT_LABEL)
	probe:SetHidden(true)
	self.probe = probe

	self.labels = {}
	for index = 1, MAX_LINES do
		local label = WINDOW_MANAGER:CreateControl(NAME .. "Line" .. index, top, CT_LABEL)
		label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
		label:SetMaxLineCount(1)
		label:SetHidden(true)
		self.labels[index] = label
	end

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

-- Draws the lines. The box is as wide as its longest line needs, between the limits.
function panel:Render()
	local top = self:Create()
	if not top then
		return
	end
	local fonts = SIZES[self:Size()]
	local lines = ADDON:PanelLines(GetTimeStamp())
	if #lines > MAX_LINES then
		for index = #lines, MAX_LINES + 1, -1 do
			lines[index] = nil
		end
	end

	local widest = 0
	for _, line in ipairs(lines) do
		local font = line.kind == "title" and fonts.title or fonts.row
		local width = self:TextWidth(font, line.text)
		if width and width > widest then
			widest = width
		end
	end
	local width = math.min(MAX_WIDTH, math.max(MIN_WIDTH, math.ceil(widest) + PADDING * 2))
	local innerWidth = width - PADDING * 2

	local y = PADDING
	for index, label in ipairs(self.labels) do
		local line = lines[index]
		if line then
			local font = line.kind == "title" and fonts.title or fonts.row
			local height = self:FontHeight(font) + LINE_PADDING
			local color = COLORS[line.kind] or COLORS.head
			label:SetFont(font)
			label:SetColor(color[1], color[2], color[3], 1)
			label:SetText(line.text)
			label:SetDimensions(innerWidth, height)
			label:ClearAnchors()
			label:SetAnchor(TOPLEFT, top, TOPLEFT, PADDING, y)
			label:SetHidden(false)
			y = y + height
		else
			label:SetHidden(true)
		end
	end
	top:SetDimensions(width, y + PADDING)
	top:ClearAnchors()
	top:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, ADDON.sv.panelLeft, ADDON.sv.panelTop)
end

-- Up now (when the panel is on), and for `panelHoldSec` after the search that is running ends.
function panel:Show()
	if not ADDON.sv or not ADDON.sv.panel then
		return
	end
	local top = self:Create()
	if not top then
		return
	end
	self.shown = true
	self.hideAt = Now() + (ADDON.sv.panelHoldSec or 30) * 1000
	self:Render()
	top:SetHidden(false)
end

-- Redraws when it is up; does nothing otherwise.
function panel:Refresh()
	if self.shown then
		self:Render()
	end
end

function panel:Hide()
	self.shown = false
	self.hideAt = nil
	if self.control then
		self.control:SetHidden(true)
	end
end

-- While a search runs the box stays; afterwards it goes when its time is up.
function panel:Tick(now)
	if not self.shown then
		return
	end
	local scan = ADDON.scan
	if scan and scan.run then
		self.hideAt = now + (ADDON.sv.panelHoldSec or 30) * 1000
		return
	end
	if self.hideAt and now >= self.hideAt then
		self:Hide()
	end
end
