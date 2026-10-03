-- PB's CyrodiilAlert -- the on-screen display
--
-- PBS_CYRODIIL_ALERT is nil if Main.lua bailed out early (e.g. already loaded).
if not PBS_CYRODIIL_ALERT then
	return
end

local addon = PBS_CYRODIIL_ALERT

-- ---------------------------------------------------------------------------------------
-- One label, not one per line.
--
-- A label's text takes colour markup, exactly as chat does, so three alerts in three colours
-- fit in a single control separated by newlines. That is worth doing: a stack of controls
-- would need creating, anchoring, hiding and re-laying-out every time a line expires, and all
-- of it would exist to reproduce what "\n" already does.
--
-- The window is a plain top-level window with the mouse switched off. It cannot be clicked,
-- dragged or focused, so it can never take a click away from the game underneath it -- which
-- is the only way an add-on's overlay can really hurt on a controller. Position is set from
-- the panel instead of by dragging, for the same reason.
--
-- Nothing here is required for the add-on to work. If the window manager is not there, or
-- creating the window fails, Available() answers false, /pbalert says so, and every alert
-- still goes to chat.
-- ---------------------------------------------------------------------------------------

local hud = addon.hud

local WINDOW_NAME = "PBsCyrodiilAlertHUD"
local LABEL_NAME = "PBsCyrodiilAlertHUDText"
local UPDATE_NAME = "PBsCyrodiilAlertHUDUpdate"

local MAX_LINES = 3
local WINDOW_WIDTH = 1100
local WINDOW_HEIGHT = 220

-- Anchor points, declared one at a time: a client that does not define one of these constants
-- must not take the whole file down with a nil key in a table constructor.
local ANCHORS = {}
local function DeclareAnchor(token, point, alignment)
	if point == nil then
		return
	end
	ANCHORS[token] = { point = point, alignment = alignment }
end

DeclareAnchor("TOP", TOP, TEXT_ALIGN_CENTER)
DeclareAnchor("CENTER", CENTER, TEXT_ALIGN_CENTER)
DeclareAnchor("BOTTOM", BOTTOM, TEXT_ALIGN_CENTER)
DeclareAnchor("TOPLEFT", TOPLEFT, TEXT_ALIGN_LEFT)
DeclareAnchor("TOPRIGHT", TOPRIGHT, TEXT_ALIGN_RIGHT)
DeclareAnchor("BOTTOMLEFT", BOTTOMLEFT, TEXT_ALIGN_LEFT)
DeclareAnchor("BOTTOMRIGHT", BOTTOMRIGHT, TEXT_ALIGN_RIGHT)

-- Where a window sits when something else wants the same piece of screen. Declared one pair at
-- a time, like the anchors: a client missing one of these constants must not take the file down
-- with a nil field, it must simply not offer that choice.
--
-- The client switches these at runtime itself (ZO_KeybindStrip:SetDrawOrder,
-- zo_keybindstrip.lua:180), and the pairs are the ends and the middle of the two enums:
-- DL_OVERLAY/DT_HIGH is what an overlay uses, DL_BACKGROUND/DT_LOW is what the housing editor
-- puts its indicators on (housingeditorhud.lua:1151), and DL_CONTROLS/DT_MEDIUM is an ordinary
-- interface control.
local DRAW_ORDERS = {}
local function DeclareDrawOrder(token, layer, tier)
	if layer == nil or tier == nil then
		return
	end
	DRAW_ORDERS[token] = { layer = layer, tier = tier }
end

DeclareDrawOrder("FRONT", DL_OVERLAY, DT_HIGH)
DeclareDrawOrder("NORMAL", DL_CONTROLS, DT_MEDIUM)
DeclareDrawOrder("BACK", DL_BACKGROUND, DT_LOW)

addon.DRAW_ORDERS = {
	{ token = "FRONT", label = "SI_PBSCA_DRAW_FRONT" },
	{ token = "NORMAL", label = "SI_PBSCA_DRAW_NORMAL" },
	{ token = "BACK", label = "SI_PBSCA_DRAW_BACK" },
}

-- Both surfaces are created in front of everything; only the summary can be moved from there.
local function ApplyDrawOrder(window, token)
	local order = DRAW_ORDERS[token] or DRAW_ORDERS.FRONT
	if not (window and order) then
		return false
	end
	-- Marked protected-attributes in the API dump, which has been wrong in both directions
	-- before, and shipped add-ons do call it. Attempted, and its failure survivable: a refused
	-- call leaves the window drawing where it already was, and the add-on says so rather than
	-- letting the setting look as though it did something.
	return (pcall(function()
		window:SetDrawLayer(order.layer)
		window:SetDrawTier(order.tier)
	end))
end

addon.ApplyDrawOrder = ApplyDrawOrder

-- For the overview map, which lives in its own file and positions itself with the same
-- anchors and draw orders as everything else.
function addon.AnchorFor(token)
	local anchor = ANCHORS[token]
	return anchor and anchor.point
end

function addon.IsDrawOrder(token)
	return DRAW_ORDERS[token] ~= nil
end

-- The panel's list, in the order the positions read down the screen.
addon.POSITIONS = {
	{ token = "TOP", label = "SI_PBSCA_POS_TOP" },
	{ token = "CENTER", label = "SI_PBSCA_POS_CENTER" },
	{ token = "BOTTOM", label = "SI_PBSCA_POS_BOTTOM" },
	{ token = "TOPLEFT", label = "SI_PBSCA_POS_TOPLEFT" },
	{ token = "TOPRIGHT", label = "SI_PBSCA_POS_TOPRIGHT" },
	{ token = "BOTTOMLEFT", label = "SI_PBSCA_POS_BOTTOMLEFT" },
	{ token = "BOTTOMRIGHT", label = "SI_PBSCA_POS_BOTTOMRIGHT" },
}

-- Faces and outline tokens: the same shortlist PB's QuestTrackerFontChanger settled on, for
-- the same measured reason. Only faces the console UI already has loaded are offered --
-- ANTIQUE_FONT, HANDWRITTEN_FONT, STONE_TABLET_FONT and CHAT_FONT were measured crashing a
-- PS5, because a face nothing else is drawing with has to be built on use and that build comes
-- out of the memory every add-on shares. Aliases, never resolved paths, so a Japanese client
-- hands back a face that can draw Japanese keep names.
addon.FACES = {
	{ alias = "$(BOLD_FONT)", label = "SI_PBSCA_FACE_BOLD" },
	{ alias = "$(MEDIUM_FONT)", label = "SI_PBSCA_FACE_MEDIUM" },
	{ alias = "$(GAMEPAD_BOLD_FONT)", label = "SI_PBSCA_FACE_GAMEPAD_BOLD" },
	{ alias = "$(GAMEPAD_MEDIUM_FONT)", label = "SI_PBSCA_FACE_GAMEPAD_MEDIUM" },
	{ alias = "$(GAMEPAD_LIGHT_FONT)", label = "SI_PBSCA_FACE_GAMEPAD_LIGHT" },
}

-- Style tokens, not FONT_STYLE_* numbers: SetFont parses "face|size|style" out of the string,
-- and the token names are not the enum names lowercased (FONT_STYLE_OUTLINE_THICK is written
-- "thick-outline"). Only the four the client's own fontdefs use are offered; the rest would be
-- a guess about what the engine's parser accepts, and a font that fails to build is not a good
-- surprise on a console.
addon.STYLES = {
	{ token = "soft-shadow-thick", label = "SI_PBSCA_STYLE_SOFT_THICK" },
	{ token = "soft-shadow-thin", label = "SI_PBSCA_STYLE_SOFT_THIN" },
	{ token = "thick-outline", label = "SI_PBSCA_STYLE_OUTLINE" },
	{ token = "shadow", label = "SI_PBSCA_STYLE_SHADOW" },
	{ token = "none", label = "SI_PBSCA_STYLE_NONE" },
}

addon.MIN_FONT_SIZE, addon.MAX_FONT_SIZE = 14, 64
addon.MIN_HUD_SECONDS, addon.MAX_HUD_SECONDS = 2, 30
-- addon.MAX_OFFSET_X / MAX_OFFSET_Y are the screen's own size, set in Main.lua.

-- ---------------------------------------------------------------------------------------
-- Settings, read defensively
--
-- Every one of these can be missing or nonsense in a saved-variables file written by an older
-- version, and none of them may take the display down: an unreadable setting falls back to the
-- shipped one rather than to nil, which is what SetFont would choke on.
-- ---------------------------------------------------------------------------------------

local function Settings()
	return addon.sv and addon.sv.hud or addon.DEFAULTS.hud
end

local function Clamp(value, low, high)
	value = tonumber(value)
	if not value then
		return nil
	end
	if value < low then
		return low
	elseif value > high then
		return high
	end
	return value
end

function hud:Face()
	local wanted = Settings().face
	for _, face in ipairs(addon.FACES) do
		if face.alias == wanted then
			return wanted
		end
	end
	return addon.DEFAULTS.hud.face
end

function hud:Style()
	local wanted = Settings().style
	for _, style in ipairs(addon.STYLES) do
		if style.token == wanted then
			return wanted
		end
	end
	return addon.DEFAULTS.hud.style
end

function hud:Size()
	return Clamp(Settings().size, addon.MIN_FONT_SIZE, addon.MAX_FONT_SIZE) or addon.DEFAULTS.hud.size
end

function hud:Seconds()
	return Clamp(Settings().seconds, addon.MIN_HUD_SECONDS, addon.MAX_HUD_SECONDS) or addon.DEFAULTS.hud.seconds
end

function hud:Position()
	local wanted = Settings().position
	if ANCHORS[wanted] then
		return wanted
	end
	return ANCHORS[addon.DEFAULTS.hud.position] and addon.DEFAULTS.hud.position or "TOP"
end

function hud:OffsetX()
	return Clamp(Settings().offsetX, -addon.MAX_OFFSET_X, addon.MAX_OFFSET_X) or 0
end

function hud:OffsetY()
	return Clamp(Settings().offsetY, -addon.MAX_OFFSET_Y, addon.MAX_OFFSET_Y) or 0
end

-- "face|size|style" -- the string a LabelControl's SetFont parses.
function hud:FontString()
	return string.format("%s|%d|%s", self:Face(), self:Size(), self:Style())
end

-- ---------------------------------------------------------------------------------------
-- The control
-- ---------------------------------------------------------------------------------------

-- One window with one label in it. Both on-screen pieces are exactly this, so it is written
-- once: they differ in where they sit, how big their text is, and what puts text in them.
--
-- Built the first time something wants to be drawn, not at load: an add-on that has never been
-- switched on should not have left a window behind in the UI.
local function CreateSurface(windowName, labelName, width, height, withBackdrop)
	local wm = WINDOW_MANAGER
	if not (wm and wm.CreateTopLevelWindow and wm.CreateControl and CT_LABEL and GuiRoot) then
		return nil
	end

	local ok, window = pcall(function()
		return wm:CreateTopLevelWindow(windowName)
	end)
	if not ok or not window then
		return nil
	end

	window:SetDimensions(width, height)
	-- No mouse, ever. An overlay that can take a click is an overlay that can cost you one.
	window:SetMouseEnabled(false)
	window:SetMovable(false)
	window:SetHidden(true)

	-- A panel behind the text, for the surface that has to be readable over anything. Created
	-- before the label so it is drawn under it.
	local backdrop
	if withBackdrop and CT_BACKDROP then
		local ok, made = pcall(function()
			return wm:CreateControl(windowName .. "Backdrop", window, CT_BACKDROP)
		end)
		if ok and made then
			backdrop = made
			backdrop:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 0)
			backdrop:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, 0, 0)
			backdrop:SetMouseEnabled(false)
		end
	end

	local label = wm:CreateControl(labelName, window, CT_LABEL)
	label:SetAnchor(TOPLEFT, window, TOPLEFT, 0, 0)
	label:SetAnchor(BOTTOMRIGHT, window, BOTTOMRIGHT, 0, 0)
	label:SetMouseEnabled(false)
	label:SetVerticalAlignment(TEXT_ALIGN_TOP)
	-- White, and left white: the colour of every line lives in the text as |cRRGGBB markup,
	-- which is the only way one label can carry three lines in three colours.
	label:SetColor(1, 1, 1, 1)

	ApplyDrawOrder(window, "FRONT")

	return window, label, backdrop
end

function hud:Create()
	if self.window then
		return true
	end
	if self.failed then
		return false
	end

	local window, label = CreateSurface(WINDOW_NAME, LABEL_NAME, WINDOW_WIDTH, WINDOW_HEIGHT)
	if not window then
		self.failed = true
		return false
	end

	self.window = window
	self.label = label
	self:Apply()
	return true
end

function hud:Available()
	return self.window ~= nil and not self.failed
end

-- Font, position and size, pushed into the control. Called whenever any of them changes, so
-- dragging a slider in the panel moves the real thing while you watch it.
function hud:Apply()
	if not self.window then
		return
	end
	local anchor = ANCHORS[self:Position()] or ANCHORS.TOP
	self.window:ClearAnchors()
	self.window:SetAnchor(anchor.point, GuiRoot, anchor.point, self:OffsetX(), self:OffsetY())
	self.label:SetFont(self:FontString())
	self.label:SetHorizontalAlignment(anchor.alignment)
end

-- ---------------------------------------------------------------------------------------
-- The lines
-- ---------------------------------------------------------------------------------------

hud.lines = {}

local function Now()
	if GetGameTimeMilliseconds then
		return GetGameTimeMilliseconds() / 1000
	end
	return 0
end

function hud:Render()
	if not self.window then
		return
	end
	if #self.lines == 0 then
		self.label:SetText("")
		self.window:SetHidden(true)
		return
	end

	local parts = {}
	for index, line in ipairs(self.lines) do
		parts[index] = "|c" .. addon:Colour(addon.SURFACE_HUD, line.kind) .. line.text .. "|r"
	end
	self.label:SetText(table.concat(parts, "\n"))
	self.window:SetHidden(false)
end

-- One update timer, running only while there is something to expire. A timer that ticks all
-- session for a display that is empty most of it is a cost with nothing on the other side.
function hud:StartTimer()
	if self.ticking then
		return
	end
	self.ticking = true
	EVENT_MANAGER:RegisterForUpdate(UPDATE_NAME, 500, function()
		self:Prune()
	end)
end

function hud:StopTimer()
	if not self.ticking then
		return
	end
	self.ticking = false
	EVENT_MANAGER:UnregisterForUpdate(UPDATE_NAME)
end

function hud:Prune()
	local now = Now()
	local kept = {}
	for _, line in ipairs(self.lines) do
		if line.expires > now then
			kept[#kept + 1] = line
		end
	end
	if #kept == #self.lines then
		return
	end
	self.lines = kept
	self:Render()
	if #self.lines == 0 then
		self:StopTimer()
	end
end

function hud:Push(kindKey, text)
	if not text or text == "" then
		return
	end
	if not self:Create() then
		return
	end

	self.lines[#self.lines + 1] = { kind = kindKey, text = text, expires = Now() + self:Seconds() }
	-- The newest three. A fourth pushes the oldest off rather than shrinking the type or
	-- growing the window over the screen.
	while #self.lines > MAX_LINES do
		table.remove(self.lines, 1)
	end

	self:Render()
	self:StartTimer()
end

function hud:Clear()
	self.lines = {}
	self:StopTimer()
	self:Render()
end

-- Called when anything the display depends on changes: the master switch, the look, a colour.
function hud:Refresh()
	if not (addon.sv and addon.sv.hud and addon.sv.hud.enabled) then
		-- Switched off with lines still up: take them down now rather than at their own pace.
		if self.window then
			self:Clear()
		end
		return
	end
	if not self:Create() then
		return
	end
	self:Apply()
	self:Render()
end

-- ---------------------------------------------------------------------------------------
-- The campaign summary
--
-- The same window-and-label, standing still instead of expiring. It has its own size and its
-- own corner, and takes the typeface and outline from the alert display above: two on-screen
-- texts from one add-on in two different faces looks like a mistake rather than a choice.
--
-- It draws only what a pass actually counted. Out of Cyrodiil, with the watch switched off, or
-- before the first pass, Main.lua clears the tally and this takes itself down -- a summary of
-- a campaign you cannot see is worse than no summary.
-- ---------------------------------------------------------------------------------------

local board = addon.board

local BOARD_WINDOW_NAME = "PBsCyrodiilAlertBoard"
local BOARD_LABEL_NAME = "PBsCyrodiilAlertBoardText"
local BOARD_WIDTH, BOARD_HEIGHT = 620, 220

local function BoardSettings()
	return addon.sv and addon.sv.board or addon.DEFAULTS.board
end

function board:Size()
	return Clamp(BoardSettings().size, addon.MIN_FONT_SIZE, addon.MAX_FONT_SIZE) or addon.DEFAULTS.board.size
end

function board:Position()
	local wanted = BoardSettings().position
	if ANCHORS[wanted] then
		return wanted
	end
	return ANCHORS[addon.DEFAULTS.board.position] and addon.DEFAULTS.board.position or "TOPLEFT"
end

function board:Draw()
	local wanted = BoardSettings().draw
	if DRAW_ORDERS[wanted] then
		return wanted
	end
	return DRAW_ORDERS[addon.DEFAULTS.board.draw] and addon.DEFAULTS.board.draw or "FRONT"
end

function board:OffsetX()
	return Clamp(BoardSettings().offsetX, -addon.MAX_OFFSET_X, addon.MAX_OFFSET_X) or 0
end

function board:OffsetY()
	return Clamp(BoardSettings().offsetY, -addon.MAX_OFFSET_Y, addon.MAX_OFFSET_Y) or 0
end

-- Face and outline are the alert display's; only the size is the summary's own.
function board:FontString()
	return string.format("%s|%d|%s", hud:Face(), self:Size(), hud:Style())
end

function board:Create()
	if self.window then
		return true
	end
	if self.failed then
		return false
	end

	local window, label = CreateSurface(BOARD_WINDOW_NAME, BOARD_LABEL_NAME, BOARD_WIDTH, BOARD_HEIGHT)
	if not window then
		self.failed = true
		return false
	end

	self.window = window
	self.label = label
	self:Apply()
	return true
end

function board:Available()
	return self.window ~= nil and not self.failed
end

function board:Apply()
	if not self.window then
		return
	end
	local anchor = ANCHORS[self:Position()] or ANCHORS.TOPLEFT
	self.window:ClearAnchors()
	self.window:SetAnchor(anchor.point, GuiRoot, anchor.point, self:OffsetX(), self:OffsetY())
	self.label:SetFont(self:FontString())
	self.label:SetHorizontalAlignment(anchor.alignment)
	-- Applied every time rather than only on the change: the choice has to survive the window
	-- being created after the setting was made, which is the usual order on a fresh login.
	self.drawOrderRefused = not ApplyDrawOrder(self.window, self:Draw())
end

function board:Hide()
	if self.window then
		self.label:SetText("")
		self.window:SetHidden(true)
	end
end

-- Called after every pass, and whenever a setting it depends on changes.
function board:Refresh()
	if not (addon.sv and addon.sv.board and addon.sv.board.enabled) then
		self:Hide()
		return
	end

	-- Only ever draws what a pass actually counted. The campaign API keeps answering from
	-- anywhere in the world, so without this the summary would sit there out of Cyrodiil --
	-- correct scores beside an "under attack" column frozen at whatever it last saw, which is
	-- the worst of the three possible states.
	if not addon.tally then
		self:Hide()
		return
	end

	local lines = addon:SituationLines()
	if not lines then
		self:Hide()
		return
	end

	if not self:Create() then
		return
	end
	self:Apply()

	local parts = {}
	for index, line in ipairs(lines) do
		parts[index] = "|c" .. line.colour .. line.text .. "|r"
	end
	self.label:SetText(table.concat(parts, "\n"))
	self.window:SetHidden(false)
end

-- ---------------------------------------------------------------------------------------
-- The output window
--
-- Everything the add-on says, in a window of its own, so that saying it does not cost the
-- player the last few lines of their chat window. Chat holds a conversation; this holds an
-- add-on's running commentary, and the two do not belong in the same place.
--
-- Newest line at the top, and the label's own SetMaxLineCount is what bounds it. That is the
-- one arrangement that cannot overflow: a long line that wraps into two costs the OLDEST line
-- rather than pushing the newest out of the window, and no amount of traffic can make the text
-- spill past the panel behind it.
--
-- Like the other two surfaces it has no mouse, so it cannot be dragged or clicked -- which is
-- why size and position are settings rather than a drag handle. On a controller a window you
-- can accidentally grab is a window that eventually eats a keybind.
-- ---------------------------------------------------------------------------------------

local log = addon.log

local LOG_WINDOW_NAME = "PBsCyrodiilAlertLog"
local LOG_LABEL_NAME = "PBsCyrodiilAlertLogText"

addon.MIN_LOG_WIDTH, addon.MAX_LOG_WIDTH = 240, 1200
addon.MIN_LOG_HEIGHT, addon.MAX_LOG_HEIGHT = 80, 700
addon.MIN_LOG_LINES, addon.MAX_LOG_LINES = 3, 40

local function LogSettings()
	return addon.sv and addon.sv.log or addon.DEFAULTS.log
end

function log:Width()
	return Clamp(LogSettings().width, addon.MIN_LOG_WIDTH, addon.MAX_LOG_WIDTH) or addon.DEFAULTS.log.width
end

function log:Height()
	return Clamp(LogSettings().height, addon.MIN_LOG_HEIGHT, addon.MAX_LOG_HEIGHT) or addon.DEFAULTS.log.height
end

function log:Size()
	return Clamp(LogSettings().size, addon.MIN_FONT_SIZE, addon.MAX_FONT_SIZE) or addon.DEFAULTS.log.size
end

function log:MaxLines()
	return Clamp(LogSettings().lines, addon.MIN_LOG_LINES, addon.MAX_LOG_LINES) or addon.DEFAULTS.log.lines
end

function log:Opacity()
	return Clamp(LogSettings().opacity, 0, 100) or addon.DEFAULTS.log.opacity
end

function log:Draw()
	local wanted = LogSettings().draw
	if DRAW_ORDERS[wanted] then
		return wanted
	end
	return DRAW_ORDERS[addon.DEFAULTS.log.draw] and addon.DEFAULTS.log.draw or "FRONT"
end

function log:Position()
	local wanted = LogSettings().position
	if ANCHORS[wanted] then
		return wanted
	end
	return ANCHORS[addon.DEFAULTS.log.position] and addon.DEFAULTS.log.position or "TOPLEFT"
end

function log:OffsetX()
	return Clamp(LogSettings().offsetX, -addon.MAX_OFFSET_X, addon.MAX_OFFSET_X) or 0
end

function log:OffsetY()
	return Clamp(LogSettings().offsetY, -addon.MAX_OFFSET_Y, addon.MAX_OFFSET_Y) or 0
end

-- Face and outline are the alert display's; only the size is the window's own.
function log:FontString()
	return string.format("%s|%d|%s", hud:Face(), self:Size(), hud:Style())
end

function log:Create()
	if self.window then
		return true
	end
	if self.failed then
		return false
	end

	local window, label, backdrop = CreateSurface(LOG_WINDOW_NAME, LOG_LABEL_NAME,
		self:Width(), self:Height(), true)
	if not window then
		self.failed = true
		return false
	end

	self.window = window
	self.label = label
	self.backdrop = backdrop
	label:SetVerticalAlignment(TEXT_ALIGN_TOP)
	label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
	if label.SetWrapMode and TEXT_WRAP_MODE_ELLIPSIS then
		label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
	end
	self:Apply()
	return true
end

function log:Available()
	return self.window ~= nil and not self.failed
end

function log:Apply()
	if not self.window then
		return
	end
	local anchor = ANCHORS[self:Position()] or ANCHORS.TOPLEFT
	self.window:SetDimensions(self:Width(), self:Height())
	self.window:ClearAnchors()
	self.window:SetAnchor(anchor.point, GuiRoot, anchor.point, self:OffsetX(), self:OffsetY())
	self.label:SetFont(self:FontString())
	-- The hard bound on what can be drawn. Without it a run of wrapped lines would push text
	-- out of the window and over whatever is beside it.
	if self.label.SetMaxLineCount then
		self.label:SetMaxLineCount(self:MaxLines())
	end
	if self.backdrop then
		local alpha = self:Opacity() / 100
		self.backdrop:SetCenterColor(0, 0, 0, alpha)
		self.backdrop:SetEdgeColor(0, 0, 0, alpha)
		self.backdrop:SetHidden(alpha <= 0)
	end
	-- Applied every time, like the summary's: the choice has to survive the window being
	-- created after the setting was made, which is the usual order on a fresh login.
	self.drawOrderRefused = not ApplyDrawOrder(self.window, self:Draw())
end

log.lines = {}

function log:Render()
	if not self.window then
		return
	end
	if #self.lines == 0 then
		self.label:SetText("")
		self.window:SetHidden(true)
		return
	end
	self.label:SetText(table.concat(self.lines, "\n"))
	self.window:SetHidden(false)
end

-- The window belongs to Cyrodiil and the Imperial City. Anywhere else it is not merely empty,
-- it is not there: a panel of add-on output over a city or a trial is somebody else's screen.
-- Output does not stop there, it goes to chat, which is where it would have gone anyway.
--
-- This is not the watch's onlyInAvA setting. That one decides whether the campaign is being
-- read; this decides where a window is allowed to sit, and the answer to that does not change
-- because somebody wants their keeps watched from a crafting station.
function log:ShouldShow()
	return addon:InAvAZone()
end

-- Returns true if the line was taken. False means the caller has to put it in chat instead --
-- which is the whole of the promise that the add-on never swallows its own output.
function log:Push(text)
	if not addon.sv or addon.sv.log.destination == "chat" then
		return false
	end
	if not self:ShouldShow() then
		return false
	end
	if not self:Create() then
		return false
	end

	-- Newest first, and the oldest falls off the end.
	table.insert(self.lines, 1, text)
	local maximum = self:MaxLines()
	while #self.lines > maximum do
		table.remove(self.lines)
	end

	self:Render()
	return true
end

function log:Clear()
	self.lines = {}
	self:Render()
end

function log:Refresh()
	if not (addon.sv and addon.sv.log) then
		return
	end
	if not self:ShouldShow() then
		-- Taken down on the way out, and empty on the way back in: an hour-old alert reappearing
		-- when you ride back into Cyrodiil is not a log, it is a ghost.
		self.lines = {}
		if self.window then
			self.label:SetText("")
			self.window:SetHidden(true)
		end
		return
	end
	if addon.sv.log.destination == "chat" then
		if self.window then
			self.window:SetHidden(true)
		end
		return
	end
	if not self:Create() then
		return
	end
	self:Apply()
	self:Render()
end
