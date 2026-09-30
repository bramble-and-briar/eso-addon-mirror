-- PB's ChatWindowCustomizer
-- Author: PinkBanther
--
-- Moves and resizes the chat window on the HUD, changes the size of the text in it, keeps it on
-- screen instead of fading away, and decides what it is drawn over.
--
-- On console the HUD chat is the gamepad chat system, GAMEPAD_CHAT_SYSTEM, and the game gives
-- the player no say in where it sits or how big it is: GamepadChatContainer:LoadSettings pins
-- it to the bottom right of the screen at a fixed 490 x 280 (ANCHOR_SETTINGS in
-- gamepadchatsystem.lua). The only related option is the text size -- Small / Medium / Large
-- under Settings > Social -- which is three steps and nothing in between.
--
-- What this add-on writes, and why it is safe to write (full evidence in FINDINGS.md):
--
--   position, size   the anchor and dimensions of the chat's top-level control. That control
--                    is the whole chat -- its message area is anchored to its top left and its
--                    input line to its bottom -- so moving and resizing it moves and resizes
--                    everything together, the same way the game's own LoadSettings does.
--   size limits      the game clamps the window to 300-550 x 170-380 through
--                    SetDimensionConstraints, recomputed from four plain fields on the chat
--                    system whenever it lays its tabs out. Those fields are widened as data,
--                    and the constraints set to match.
--   message text     the font on each chat tab's TextBuffer, in the same "face|size|style"
--                    form the game builds in GetChatFontFormatString, with the size as a
--                    number instead of one of the three $(GP_n) steps.
--   the HUD element  Update 51 registers the chat with the new HUD manager, which puts every
--                    element back to its own anchor whenever the screen is resized or the mode
--                    changes -- on console always the game's placement, because the gamepad HUD
--                    editor does not exist yet. That element's anchor is a plain data object, so
--                    the player's placement is written into it and the client's own re-applies
--                    agree with the window instead of undoing it.
--   draw order       the tier and level of the same control. The game draws the chat at
--                    MEDIUM / 30: over the HUD, under keybind strips and tooltips.
--   where it shows   the client draws the chat on the HUD and nowhere else (IsHidden), so the
--                    window is shown again after its RefreshVisibility has hidden it, for
--                    players who want to read chat with a menu open.
--   staying up       the chat minimises itself 20 seconds after the last message. The expiry
--                    behind that is a file-local only StartVisibilityTimer writes, so keeping
--                    it in the future stops the minimise; the message area and the
--                    background's alpha put right what an earlier minimise did.
--
-- All of it is writes to controls and fields, with two exceptions -- StartVisibilityTimer and
-- RefreshVisibility, each of which is one assignment or one SetHidden and nothing else. Nothing in the chat is hooked or wrapped, and
-- no chat code is called: the chat is the one piece of UI where every message the player sends
-- goes through the client's own closures, and an add-on frame anywhere near those is how a
-- private-function error is born. See FINDINGS.md, "Why nothing is hooked".
--
-- Nothing is written while the settings still equal the game's own. The window's place and size
-- are read off the control before the first write, and the text size is measured off a label
-- given the game's own font, so "untouched" is not a guess -- an installed-but-unset add-on is
-- indistinguishable from not having it.

if PBS_CHAT_WINDOW_CUSTOMIZER then
	return
end

local addon = {
	name = "PBsChatWindowCustomizer",
}

-- The display name is a Lua constant and the version comes from the manifest, the same way the
-- other PB's add-ons do it -- reading the name back out of "## Title" mangles the "PB's "
-- prefix in the settings library. Typographic apostrophe (U+2019), not ASCII '.
local DISPLAY_NAME = "PB’s ChatWindowCustomizer"
local AUTHOR = "PinkBanther"
local SLASH = "/pbchatwin"
local SHORT_SLASH = "/pbcw"

local function ReadManifestVersion()
	local manager = GetAddOnManager and GetAddOnManager()
	if not manager then
		return ""
	end
	for index = 1, manager:GetNumAddOns() do
		local name, title = manager:GetAddOnInfo(index)
		if name == addon.name and title then
			local plain = title:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
			return plain:match("([%d]+[%d%.]*)%s*$") or ""
		end
	end
	return ""
end

addon.author = AUTHOR
addon.baseTitle = DISPLAY_NAME
addon.version = ReadManifestVersion()
addon.title = addon.version ~= "" and (DISPLAY_NAME .. " " .. addon.version) or DISPLAY_NAME
addon.slash = SLASH

-- ---------------------------------------------------------------------------------------
-- Output
--
-- A message printed at EVENT_ADD_ON_LOADED is thrown away because chat is not up yet, so
-- anything user-facing is either a command response or fires on EVENT_PLAYER_ACTIVATED.
-- ---------------------------------------------------------------------------------------

local function Say(text)
	if CHAT_ROUTER and CHAT_ROUTER.AddSystemMessage then
		CHAT_ROUTER:AddSystemMessage(text)
	elseif CHAT_SYSTEM and CHAT_SYSTEM.AddMessage then
		CHAT_SYSTEM:AddMessage(text)
	else
		d(text)
	end
end

local function Line(text, ...)
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, text, ...)
		Say(ok and formatted or text)
	else
		Say(text)
	end
end

addon.Line = Line

-- zo_callLater where there is one; straight through in a test harness that has none.
local function Later(fn, delay)
	if zo_callLater then
		zo_callLater(fn, delay)
	else
		fn()
	end
end

-- Whole numbers everywhere a position, a size or a font size is stored or written. Also turns
-- -0 into 0, which a distance measured off a right-hand anchor otherwise comes back as.
local function Round(value)
	return math.floor(value + 0.5)
end

local function Clamp(value, low, high)
	if value < low then
		return low
	end
	if value > high then
		return high
	end
	return value
end

addon.Round = Round

-- ---------------------------------------------------------------------------------------
-- Corners
--
-- The position is two distances from one corner of the screen, and the window is anchored by
-- that same corner of itself. Which corner is the player's choice, because it decides which way
-- the window grows: anchored bottom right -- the game's own choice -- a taller window grows
-- upwards and the input line stays where it was; anchored top left, it grows downwards.
--
-- sx and sy turn a distance into an anchor offset: +1 where the distance runs from the left or
-- top edge, -1 where it runs in from the right or bottom.
-- ---------------------------------------------------------------------------------------

addon.corners = {
	{ key = "topLeft", pointName = "TOPLEFT", sx = 1, sy = 1, command = "tl", stringId = "SI_PBSCWC_CORNER_TOP_LEFT" },
	{ key = "topRight", pointName = "TOPRIGHT", sx = -1, sy = 1, command = "tr", stringId = "SI_PBSCWC_CORNER_TOP_RIGHT" },
	{ key = "bottomLeft", pointName = "BOTTOMLEFT", sx = 1, sy = -1, command = "bl", stringId = "SI_PBSCWC_CORNER_BOTTOM_LEFT" },
	{ key = "bottomRight", pointName = "BOTTOMRIGHT", sx = -1, sy = -1, command = "br", stringId = "SI_PBSCWC_CORNER_BOTTOM_RIGHT" },
}

addon.cornerByKey = {}
addon.cornerByCommand = {}
for _, corner in ipairs(addon.corners) do
	addon.cornerByKey[corner.key] = corner
	addon.cornerByCommand[corner.command] = corner
end

-- The anchor constants are engine globals; looked up when used rather than copied at load.
function addon:CornerPoint(corner)
	return _G[corner.pointName]
end

function addon:CornerForPoint(point)
	for _, corner in ipairs(self.corners) do
		if point ~= nil and self:CornerPoint(corner) == point then
			return corner
		end
	end
	return nil
end

-- ---------------------------------------------------------------------------------------
-- Limits and defaults
-- ---------------------------------------------------------------------------------------

-- The game's own layout, from GamepadChatContainer:LoadSettings: BOTTOMRIGHT of the screen,
-- offset (0, -215), 490 x 280. Only a fallback -- the real one is read off the control before
-- anything is written, so a patch that moves the chat does not leave this add-on's idea of
-- "default" behind.
addon.GAME_LAYOUT_FALLBACK = { corner = "bottomRight", x = 0, y = 215, width = 490, height = 280 }

-- Smaller than the game's own 300 x 170 on purpose: the game's limits were chosen for a window
-- the player drags about with a mouse, and a narrow strip of chat is a reasonable thing to want
-- on a console HUD. Below this the input line has no room for its channel name.
addon.MIN_WIDTH = 200
addon.MIN_HEIGHT = 100

-- The text size range. The game's own steps are $(GP_18) to $(GP_25) or so; this runs well past
-- both ends. Past 48 a single line of chat does not fit across a sensible window.
addon.MIN_FONT_SIZE = 10
addon.MAX_FONT_SIZE = 48

-- Only used when nothing better is known: no gamepad chat font setting and no measurement.
addon.FALLBACK_FONT_SIZE = 20

addon.LAYOUT_KEYS = { "corner", "x", "y", "width", "height" }

-- ---------------------------------------------------------------------------------------
-- Draw order
--
-- A top-level window is drawn by tier first, then by level within that tier. The chat is
-- MEDIUM / 30 (ZO_ChatWindowTopLevelTemplate, ZO_MEDIUM_TIER_KEYBOARD_CHAT_WINDOW), which puts
-- it above the HUD -- most of the HUD is LOW -- and under the things the client puts at HIGH:
-- keybind strips, tooltips, announcements, alerts.
--
-- So LOW is "let the HUD draw over the chat", MEDIUM is the game's own, and HIGH is "over
-- almost everything". The level is the order inside the chosen tier, and the client's own
-- numbers for the two tiers worth sharing with are in commonconstants.lua: at MEDIUM, the
-- keybind strip is 10 and a dialog 20; at HIGH, tooltips are 140 and alerts 145.
-- ---------------------------------------------------------------------------------------

addon.tiers = {
	{ key = "low", constName = "DT_LOW", command = "low", stringId = "SI_PBSCWC_TIER_LOW" },
	{ key = "medium", constName = "DT_MEDIUM", command = "medium", stringId = "SI_PBSCWC_TIER_MEDIUM" },
	{ key = "high", constName = "DT_HIGH", command = "high", stringId = "SI_PBSCWC_TIER_HIGH" },
}

addon.tierByKey = {}
addon.tierByCommand = {}
for _, tier in ipairs(addon.tiers) do
	addon.tierByKey[tier.key] = tier
	addon.tierByCommand[tier.command] = tier
end

function addon:TierValue(tier)
	return _G[tier.constName]
end

function addon:TierForValue(value)
	for _, tier in ipairs(self.tiers) do
		if value ~= nil and self:TierValue(tier) == value then
			return tier
		end
	end
	return nil
end

-- The game's own, and only a fallback: the real pair is read off the control before the first
-- write, like the anchor.
addon.GAME_DRAW_FALLBACK = { tier = "medium", level = 30 }

addon.MIN_DRAW_LEVEL = 0
addon.MAX_DRAW_LEVEL = 200
addon.DRAW_KEYS = { "tier", "level" }

-- Every value the player can change is stored only once they change it. An empty table means
-- "the game's own", which is what makes an untouched install cost nothing.
--
-- The measurements are not settings: they are what the client draws, kept so the settings
-- panel knows the game's values before the chat has loaded in a session.
addon.accountDefaults = {
	enabled = true,
	preview = true,
	alwaysVisible = false,
	inMenus = false,
	layout = {},
	draw = {},
	text = {},
	measured = { layout = {}, fontSize = {}, draw = {} },
}

-- ---------------------------------------------------------------------------------------
-- Saved settings
-- ---------------------------------------------------------------------------------------

-- The saved settings, repaired if a partial table came back from an older build. Never returns
-- nil: every caller would otherwise need the same guard.
function addon:Account()
	local account = self.account
	if type(account) ~= "table" then
		account = {}
		self.account = account
	end
	if account.enabled == nil then
		account.enabled = true
	end
	if account.preview == nil then
		account.preview = true
	end
	if type(account.layout) ~= "table" then
		account.layout = {}
	end
	if account.alwaysVisible == nil then
		account.alwaysVisible = false
	end
	if account.inMenus == nil then
		account.inMenus = false
	end
	if type(account.draw) ~= "table" then
		account.draw = {}
	end
	if type(account.text) ~= "table" then
		account.text = {}
	end
	if type(account.measured) ~= "table" then
		account.measured = {}
	end
	if type(account.measured.layout) ~= "table" then
		account.measured.layout = {}
	end
	if type(account.measured.fontSize) ~= "table" then
		account.measured.fontSize = {}
	end
	if type(account.measured.draw) ~= "table" then
		account.measured.draw = {}
	end
	return account
end

-- Whether a stored layout value is one this build can use. A corner has to be one of the four,
-- and a number has to be a number: anything else is treated as "not set".
local function ValidLayoutValue(key, value)
	if key == "corner" then
		return addon.cornerByKey[value] ~= nil
	end
	return type(value) == "number"
end

-- ---------------------------------------------------------------------------------------
-- The screen
-- ---------------------------------------------------------------------------------------

-- GuiRoot's size is the space every anchor offset is measured in. On console that is the
-- gamepad UI's virtual screen, not the TV's pixels.
function addon:RootSize()
	if GuiRoot and type(GuiRoot.GetDimensions) == "function" then
		local ok, width, height = pcall(GuiRoot.GetDimensions, GuiRoot)
		if ok and type(width) == "number" and type(height) == "number" and width > 0 and height > 0 then
			return width, height
		end
	end
	return 1920, 1080
end

-- ---------------------------------------------------------------------------------------
-- Layouts
--
-- A layout is { corner, x, y, width, height }: x and y are the distances from the chosen corner
-- of the screen to the same corner of the window.
-- ---------------------------------------------------------------------------------------

-- The game's own layout: as measured off the control, otherwise the fallback.
function addon:GameLayout()
	local measured = self:Account().measured.layout
	local fallback = self.GAME_LAYOUT_FALLBACK
	local layout = {}
	for _, key in ipairs(self.LAYOUT_KEYS) do
		local value = measured[key]
		if ValidLayoutValue(key, value) then
			layout[key] = value
		else
			layout[key] = fallback[key]
		end
	end
	return layout
end

-- The layout the player has asked for: the saved value where there is one, the game's otherwise.
function addon:Layout()
	local saved = self:Account().layout
	local game = self:GameLayout()
	local layout = {}
	for _, key in ipairs(self.LAYOUT_KEYS) do
		local value = saved[key]
		if ValidLayoutValue(key, value) then
			layout[key] = value
		else
			layout[key] = game[key]
		end
	end
	return layout
end

-- What should be on screen right now: the player's layout, or the game's while switched off.
function addon:EffectiveLayout()
	if self:Account().enabled then
		return self:Layout()
	end
	return self:GameLayout()
end

function addon:SetLayoutValue(key, value)
	self:Account().layout[key] = value
end

-- Pulls a layout onto the screen: whole numbers, no smaller than the minimum, no bigger than
-- the screen, and no part of it off the edge. Applied to what is written rather than to what is
-- saved, so a layout chosen on one screen size is not rewritten by visiting a smaller one.
function addon:Clamped(layout)
	local rootWidth, rootHeight = self:RootSize()
	local width = Clamp(Round(layout.width), self.MIN_WIDTH, math.max(self.MIN_WIDTH, Round(rootWidth)))
	local height = Clamp(Round(layout.height), self.MIN_HEIGHT, math.max(self.MIN_HEIGHT, Round(rootHeight)))
	return {
		corner = self.cornerByKey[layout.corner] and layout.corner or self.GAME_LAYOUT_FALLBACK.corner,
		x = Clamp(Round(layout.x), 0, math.max(0, Round(rootWidth) - width)),
		y = Clamp(Round(layout.y), 0, math.max(0, Round(rootHeight) - height)),
		width = width,
		height = height,
	}
end

-- The window's rectangle on screen: left, top, width, height.
function addon:RectOf(layout)
	local rootWidth, rootHeight = self:RootSize()
	local corner = self.cornerByKey[layout.corner] or self.cornerByKey[self.GAME_LAYOUT_FALLBACK.corner]
	local left = corner.sx > 0 and layout.x or (rootWidth - layout.x - layout.width)
	local top = corner.sy > 0 and layout.y or (rootHeight - layout.y - layout.height)
	return left, top, layout.width, layout.height
end

-- The distances that put a window of this size at this left / top, measured from cornerKey.
function addon:DistancesFor(cornerKey, left, top, width, height)
	local rootWidth, rootHeight = self:RootSize()
	local corner = self.cornerByKey[cornerKey]
	local x = corner.sx > 0 and left or (rootWidth - left - width)
	local y = corner.sy > 0 and top or (rootHeight - top - height)
	return Round(x), Round(y)
end

-- Changes which corner the position is measured from without moving the window: the current
-- rectangle is re-expressed from the new corner. Width and height are saved alongside, because
-- from here on the distances only mean what they say for this size.
function addon:SetCorner(cornerKey)
	if not self.cornerByKey[cornerKey] then
		return false
	end
	local layout = self:Clamped(self:Layout())
	local left, top, width, height = self:RectOf(layout)
	local x, y = self:DistancesFor(cornerKey, left, top, width, height)
	local saved = self:Account().layout
	saved.corner = cornerKey
	saved.x = math.max(0, x)
	saved.y = math.max(0, y)
	saved.width = width
	saved.height = height
	return true
end

-- True when the window would be somewhere, or some size, other than where the game puts it.
--
-- Compared as rectangles rather than value by value: the same window can be described from any
-- of the four corners, and switching the corner in the settings panel should not by itself
-- start writing to the chat.
function addon:LayoutDiffers()
	if not self:Account().enabled then
		return false
	end
	local wantLeft, wantTop, wantWidth, wantHeight = self:RectOf(self:Clamped(self:Layout()))
	local gameLeft, gameTop, gameWidth, gameHeight = self:RectOf(self:Clamped(self:GameLayout()))
	return Round(wantLeft) ~= Round(gameLeft) or Round(wantTop) ~= Round(gameTop)
		or wantWidth ~= gameWidth or wantHeight ~= gameHeight
end

-- ---------------------------------------------------------------------------------------
-- The chat
-- ---------------------------------------------------------------------------------------

function addon:Chat()
	local chat = GAMEPAD_CHAT_SYSTEM
	if type(chat) ~= "table" or not chat.control then
		return nil
	end
	return chat
end

-- The chat builds its containers and windows on its own EVENT_PLAYER_ACTIVATED, once saved
-- variables are ready (SharedChatSystem:InitializeSharedEvents), and sets loaded when it has.
-- Before that the control still carries the XML template's size and no anchor worth reading.
function addon:ChatReady()
	local chat = self:Chat()
	if not chat or chat.loaded ~= true or not chat.primaryContainer then
		return false, chat
	end
	return true, chat
end

-- ---------------------------------------------------------------------------------------
-- The customizable HUD element (Update 51)
--
-- U51 registers the chat window with the new HUD manager:
--
--   self.hudElement = HUD_MANAGER:RegisterGamepadElement(self.control, DISPLAY_NAME, CONFIG)
--
-- with CONFIG.defaultAnchor a ZO_Anchor built from the chat's own ANCHOR_SETTINGS. From then on
-- the client puts the window back by itself: ZO_HUDManager:PropagateSettings walks every element
-- and calls ZO_HUDManager_Element:RevertOffsetModifications, which is
-- savedAnchor:Set(self.control) -- a ClearAnchors and a SetAnchor. On console GetSavedAnchor
-- returns the *default* anchor, because the gamepad HUD editor does not exist yet
-- ("TODO Custom HUD: Remove this check once we build the gamepad editor"), so what comes back is
-- always the game's own bottom-right 490 x 280 placement. PropagateSettings runs on
-- EVENT_SCREEN_RESIZED, on a gamepad-mode change, and once when add-ons have loaded.
--
-- So the anchor is not ours to write once. The fix is to make the element's own default *be*
-- ours: ZO_Anchor is a plain data object with setters, and writing our point and offsets into it
-- means every one of the client's own re-applications puts the window where the player asked.
-- That is the same move as the U51 HUD tracker column, which is told where to sit through its
-- element rather than by writing the control.
--
-- element.currentAnchor is left pointing at that same object, because
-- ZO_HUDManager_Element:IsUsingDefaultAnchor is identity ("currentAnchor == defaultAnchor") and
-- ZO_HUDTracker_Manager:OnAnchorStateChanged reads it to decide whether to stack the trackers
-- above the chat window. Keeping it true is what makes the tracker column follow the window.
--
-- Dimensions are not part of an anchor, so the size is still written on the control -- which is
-- why the re-applies below exist as well.
-- ---------------------------------------------------------------------------------------

function addon:HudElement()
	local chat = self:Chat()
	local element = chat and chat.hudElement
	if type(element) ~= "table" or type(element.defaultAnchor) ~= "table" then
		return nil
	end
	if type(element.defaultAnchor.SetOffsets) ~= "function" or type(element.defaultAnchor.Get) ~= "function" then
		return nil
	end
	return element
end

-- Puts our corner and distances into the element's default anchor, so the client's own
-- re-application is ours. Returns false where there is no element -- a pre-U51 client.
function addon:WriteElementAnchor(point, offsetX, offsetY)
	local element = self:HudElement()
	if not element then
		return false
	end
	local anchor = element.defaultAnchor
	local ok = self:Write("hud element", function()
		anchor:SetMyPoint(point)
		anchor:SetRelativePoint(point)
		anchor:SetOffsets(offsetX, offsetY)
		-- nil target is the control's parent, GuiRoot, exactly as the chat's own ANCHOR_SETTINGS
		-- has it.
		anchor:SetTarget(nil)
		element.currentAnchor = anchor
	end)
	self.elementWritten = ok
	return ok
end

function addon:RestoreElementAnchor()
	local element = self:HudElement()
	local original = self.original and self.original.element
	if not element or not original then
		return false
	end
	local anchor = element.defaultAnchor
	self:Write("hud element", function()
		anchor:SetMyPoint(original.point)
		anchor:SetRelativePoint(original.relPoint)
		anchor:SetOffsets(original.offsetX, original.offsetY)
		anchor:SetTarget(original.target)
		if original.usingDefault then
			element.currentAnchor = anchor
		end
	end)
	self.elementWritten = false
	return true
end

-- ---------------------------------------------------------------------------------------
-- Reading the game's layout
--
-- Once per session, and only before this add-on has written anything: after that the control
-- carries our anchor, and reading it back would make our own layout the new "default" -- the
-- mistake PB's NamePlateChanger had to grow a repair path for. A reload rebuilds the chat from
-- scratch, so every session starts with a pristine control.
-- ---------------------------------------------------------------------------------------

local function ReadAnchor(control, index)
	local ok, isValid, point, relativeTo, relativePoint, offsetX, offsetY, constrains = pcall(control.GetAnchor, control, index)
	if not ok or not isValid then
		return nil
	end
	return {
		point = point,
		relativeTo = relativeTo,
		relativePoint = relativePoint,
		offsetX = offsetX or 0,
		offsetY = offsetY or 0,
		constrains = constrains,
	}
end

function addon:CaptureGameLayout(chat)
	if self.original then
		return true
	end
	if self.layoutWritten then
		return false
	end

	local control = chat.control
	local anchor = ReadAnchor(control, 0)
	local okDims, width, height = pcall(control.GetDimensions, control)
	if not anchor or not okDims or type(width) ~= "number" or type(height) ~= "number" or width <= 0 or height <= 0 then
		return false
	end

	local original = {
		anchors = { anchor, ReadAnchor(control, 1) },
		width = width,
		height = height,
		extents = {
			minWidth = chat.minContainerWidth,
			maxWidth = chat.maxContainerWidth,
			minHeight = chat.minContainerHeight,
			maxHeight = chat.maxContainerHeight,
		},
	}
	if type(control.GetDimensionConstraints) == "function" then
		local ok, minWidth, minHeight, maxWidth, maxHeight = pcall(control.GetDimensionConstraints, control)
		if ok then
			original.constraints = { minWidth, minHeight, maxWidth, maxHeight }
		end
	end
	local element = self:HudElement()
	if element then
		local point, target, relPoint, offsetX, offsetY, constraints = element.defaultAnchor:Get()
		original.element = {
			point = point,
			target = target,
			relPoint = relPoint,
			offsetX = offsetX,
			offsetY = offsetY,
			constraints = constraints,
			usingDefault = element.currentAnchor == element.defaultAnchor,
		}
	end

	if type(control.GetDrawTier) == "function" then
		local okTier, tierValue = pcall(control.GetDrawTier, control)
		local okLevel, levelValue = pcall(control.GetDrawLevel, control)
		if okTier and okLevel then
			original.draw = { tier = tierValue, level = levelValue }
			local tier = self:TierForValue(tierValue)
			if tier and type(levelValue) == "number" then
				self:Account().measured.draw = { tier = tier.key, level = Round(levelValue) }
				self.gameDrawSource = "measured"
			else
				self.gameDrawSource = "fallback (tier not one of the three)"
			end
		end
	end
	self.original = original

	-- Translated into this add-on's terms only when it is the shape the game uses today: one
	-- corner of the window on the same corner of the screen. Anything else is left to the
	-- fallback rather than guessed at; the original anchor is still what gets restored.
	local corner = self:CornerForPoint(anchor.point)
	local parent = type(control.GetParent) == "function" and control:GetParent() or nil
	local relativeOk = anchor.relativeTo == nil or anchor.relativeTo == GuiRoot or anchor.relativeTo == parent
	if corner and anchor.point == anchor.relativePoint and relativeOk then
		self:Account().measured.layout = {
			corner = corner.key,
			x = Round(anchor.offsetX * corner.sx),
			y = Round(anchor.offsetY * corner.sy),
			width = Round(width),
			height = Round(height),
		}
		self.gameLayoutSource = "measured"
	else
		self.gameLayoutSource = "fallback (anchor not a screen corner)"
	end
	return true
end

-- ---------------------------------------------------------------------------------------
-- Writing the layout
-- ---------------------------------------------------------------------------------------

-- Every write goes through here so a refused one is recorded rather than lost. Writing a
-- control's anchor is marked "protected-attributes" in the API dump; what that means for a
-- client control on console is one of the things FINDINGS.md lists to measure, and status
-- prints whatever came back.
function addon:Write(what, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		self.writeErrors = self.writeErrors or {}
		self.writeErrors[what] = tostring(err)
	end
	return ok
end

-- The game recomputes the window's size limits from these four fields whenever it lays out
-- its tabs (SharedChatContainer:CalculateConstraints). Writing them is what stops a later tab
-- layout from snapping the window back inside 550 x 380.
local function SetExtents(chat, minWidth, maxWidth, minHeight, maxHeight)
	chat.minContainerWidth = minWidth
	chat.maxContainerWidth = maxWidth
	chat.minContainerHeight = minHeight
	chat.maxContainerHeight = maxHeight
end

-- True when the control already has exactly this anchor and size, so a HUD show does not rewrite
-- the same numbers every time the player closes a menu.
function addon:LayoutInPlace(control, layout)
	local corner = self.cornerByKey[layout.corner]
	local point = self:CornerPoint(corner)
	local anchor = ReadAnchor(control, 0)
	if not anchor or ReadAnchor(control, 1) then
		return false
	end
	local okDims, width, height = pcall(control.GetDimensions, control)
	if not (okDims and anchor.point == point and anchor.relativePoint == point
		and Round(anchor.offsetX) == Round(corner.sx * layout.x) and Round(anchor.offsetY) == Round(corner.sy * layout.y)
		and Round(width) == layout.width and Round(height) == layout.height) then
		return false
	end

	-- The element's default anchor counts as part of the layout: while it still says the game's
	-- own placement, the next PropagateSettings undoes everything above.
	local element = self:HudElement()
	if element then
		local elementPoint, _, _, elementX, elementY = element.defaultAnchor:Get()
		if elementPoint ~= point or Round(elementX or 0) ~= Round(corner.sx * layout.x)
			or Round(elementY or 0) ~= Round(corner.sy * layout.y) then
			return false
		end
	end
	return true
end

function addon:RestoreLayout(chat)
	local original = self.original
	local control = chat.control
	if not original then
		return false
	end

	local extents = original.extents
	SetExtents(chat, extents.minWidth, extents.maxWidth, extents.minHeight, extents.maxHeight)
	if original.constraints and type(control.SetDimensionConstraints) == "function" then
		self:Write("constraints", control.SetDimensionConstraints, control, unpack(original.constraints))
	end
	self:Write("anchor", control.ClearAnchors, control)
	for index = 1, 2 do
		local anchor = original.anchors[index]
		if anchor then
			self:Write("anchor", control.SetAnchor, control, anchor.point, anchor.relativeTo, anchor.relativePoint,
				anchor.offsetX, anchor.offsetY, anchor.constrains)
		end
	end
	self:Write("dimensions", control.SetDimensions, control, original.width, original.height)
	self:RestoreElementAnchor()
	self.layoutWritten = false
	self.lastLayout = nil
	return true
end

-- Puts the window where the settings say, or back where the game had it.
function addon:ApplyLayout()
	local ready, chat = self:ChatReady()
	if not ready then
		return false
	end
	local control = chat.control

	if not self:LayoutDiffers() then
		if self.layoutWritten then
			return self:RestoreLayout(chat)
		end
		return true
	end

	if not self:CaptureGameLayout(chat) then
		-- Without the game's own anchor there would be nothing to put back. Better not to move
		-- the window at all than to move it for good.
		self.writeErrors = self.writeErrors or {}
		self.writeErrors.capture = "could not read the chat's own anchor"
		return false
	end

	local layout = self:Clamped(self:Layout())
	if self.layoutWritten and self:LayoutInPlace(control, layout) then
		return true
	end

	local corner = self.cornerByKey[layout.corner]
	local point = self:CornerPoint(corner)
	local rootWidth, rootHeight = self:RootSize()
	local maxWidth = math.max(self.MIN_WIDTH, Round(rootWidth))
	local maxHeight = math.max(self.MIN_HEIGHT, Round(rootHeight))

	SetExtents(chat, self.MIN_WIDTH, maxWidth, self.MIN_HEIGHT, maxHeight)
	if type(control.SetDimensionConstraints) == "function" then
		self:Write("constraints", control.SetDimensionConstraints, control, self.MIN_WIDTH, self.MIN_HEIGHT, maxWidth, maxHeight)
	end

	-- relativeTo nil is the parent, GuiRoot -- exactly the call the game makes in LoadSettings.
	self:Write("anchor", control.ClearAnchors, control)
	self:Write("anchor", control.SetAnchor, control, point, nil, point, corner.sx * layout.x, corner.sy * layout.y)
	self:Write("dimensions", control.SetDimensions, control, layout.width, layout.height)

	-- And the same anchor into the U51 HUD element, so the client's own re-applications agree
	-- with the control instead of putting the window back.
	self:WriteElementAnchor(point, corner.sx * layout.x, corner.sy * layout.y)

	self.layoutWritten = true
	self.lastLayout = layout
	return true
end

-- ---------------------------------------------------------------------------------------
-- Writing the draw order
--
-- Two writes on the same control as the layout, and read back off it first, so switching the
-- option off puts the client's own tier and level back rather than this build's idea of them.
-- ---------------------------------------------------------------------------------------

function addon:GameDraw()
	local measured = self:Account().measured.draw
	local fallback = self.GAME_DRAW_FALLBACK
	local tier = self.tierByKey[measured.tier] and measured.tier or fallback.tier
	local level = type(measured.level) == "number" and Round(measured.level) or fallback.level
	return { tier = tier, level = level }
end

function addon:Draw()
	local saved = self:Account().draw
	local game = self:GameDraw()
	return {
		tier = self.tierByKey[saved.tier] and saved.tier or game.tier,
		level = type(saved.level) == "number" and Clamp(Round(saved.level), self.MIN_DRAW_LEVEL, self.MAX_DRAW_LEVEL) or game.level,
	}
end

function addon:EffectiveDraw()
	if self:Account().enabled then
		return self:Draw()
	end
	return self:GameDraw()
end

function addon:SetDrawValue(key, value)
	self:Account().draw[key] = value
end

function addon:DrawDiffers()
	if not self:Account().enabled then
		return false
	end
	local want, game = self:Draw(), self:GameDraw()
	return want.tier ~= game.tier or want.level ~= game.level
end

-- True when the control already has this tier and level, so a HUD show does not rewrite the
-- same two numbers every time the player closes a menu.
function addon:DrawInPlace(control, draw)
	local tier = self.tierByKey[draw.tier]
	local okTier, tierValue = pcall(control.GetDrawTier, control)
	local okLevel, levelValue = pcall(control.GetDrawLevel, control)
	return okTier and okLevel and tierValue == self:TierValue(tier) and Round(levelValue or -1) == draw.level
end

function addon:ApplyDraw()
	local ready, chat = self:ChatReady()
	if not ready then
		return false
	end
	local control = chat.control

	if not self:DrawDiffers() then
		if self.drawWritten then
			local original = self.original and self.original.draw
			if original then
				self:Write("draw", control.SetDrawTier, control, original.tier)
				self:Write("draw", control.SetDrawLevel, control, original.level)
			end
			self.drawWritten = false
		end
		return true
	end

	if not self:CaptureGameLayout(chat) then
		return false
	end

	local draw = self:Draw()
	local tier = self.tierByKey[draw.tier]
	if self.drawWritten and self:DrawInPlace(control, draw) then
		return true
	end
	self:Write("draw", control.SetDrawTier, control, self:TierValue(tier))
	self:Write("draw", control.SetDrawLevel, control, draw.level)
	self.drawWritten = true
	return true
end

-- ---------------------------------------------------------------------------------------
-- Keeping the window on screen
--
-- The console chat minimises itself 20 seconds after the last message
-- (ZO_GAMEPAD_CHAT_SYSTEM_SECONDS_VISIBLE_UNPINNED): an OnUpdate on the chat control compares
-- GetFrameTimeSeconds() with a file-local expiry, and past it calls
-- GamepadChatContainer:HandleVisibleTimeExpired -> ZO_GamepadChatSystem:Minimize, which hides
-- the message area and fades the background to nothing.
--
-- That expiry is only ever set by ZO_GamepadChatSystem:StartVisibilityTimer, whose whole body is
--
--   g_expirationTime = GetFrameTimeSeconds() + ZO_GAMEPAD_CHAT_SYSTEM_SECONDS_VISIBLE_UNPINNED
--
-- so keeping it in the future is enough to stop the minimise ever happening, and pushing it is
-- the one chat call this add-on makes: it writes a number, creates no closure and touches no
-- screen. Nothing else in the client reads or clears it.
--
-- Two writes put right what a minimise that already happened did -- the message area is shown
-- again and the background's alpha restored. The input line is deliberately left alone: the game
-- hides its box and channel name while minimised, and a permanently visible input line reads as
-- though the player were typing.
--
-- Switching the option off pushes the expiry one last time instead of minimising the window
-- ourselves, so the game's own timer takes it from there and minimises it as it always would.
-- ---------------------------------------------------------------------------------------

local VISIBILITY_PUSH_MS = 10000

-- Long enough for the rest of a scene transition to have run, short enough not to be seen.
local MENU_REASSERT_MS = 50

-- The same idea for a screen resize: after the client's own handlers on that event.
local RESIZE_SETTLE_MS = 50

function addon:AlwaysVisible()
	local account = self:Account()
	if not account.enabled then
		return false
	end
	-- Showing it in menus means keeping it up: a window that appears in a menu and then
	-- minimises itself twenty seconds later is worse than either behaviour on its own.
	return account.alwaysVisible == true or account.inMenus == true
end

-- Whether the window should also be on screen where the game hides it outright.
--
-- ZO_GamepadChatSystem:IsHidden is "only on the HUD": it answers hidden unless HUD_FRAGMENT is
-- showing, and RefreshVisibility is the one thing that turns that answer into
-- control:SetHidden. Never forced while the player has the chat switched off in the game's own
-- settings -- hudEnabled is that setting -- because then the window is not meant to be there at
-- all.
function addon:ShowInMenus()
	local account = self:Account()
	if not (account.enabled and account.inMenus == true) then
		return false
	end
	local chat = self:Chat()
	return chat ~= nil and chat.hudEnabled == true
end

-- The two controls a minimise leaves hidden or transparent.
function addon:VisibilityControls(chat)
	local container = chat.primaryContainer
	local windowContainer = container and container.windowContainer
	local background = type(chat.control.GetNamedChild) == "function" and chat.control:GetNamedChild("Bg") or nil
	return windowContainer, background
end

function addon:PushVisibilityTimer(chat)
	if type(chat.StartVisibilityTimer) ~= "function" then
		return false
	end
	return self:Write("visibility timer", chat.StartVisibilityTimer, chat)
end

function addon:ApplyVisibility()
	local ready, chat = self:ChatReady()
	if not ready then
		return false
	end

	if not self:AlwaysVisible() then
		if self.visibilityWritten then
			-- Hand the window back to the game's own timer rather than minimising it here: the
			-- client then does it in its own time, in its own way. RefreshVisibility is the
			-- other chat call this add-on makes, and for the same reason as the timer: its whole
			-- body is control:SetHidden(self:IsHidden()), so it decides where the window belongs
			-- by the client's own rules -- game setting and HUD included -- without this add-on
			-- having to copy them.
			if type(chat.RefreshVisibility) == "function" then
				self:Write("visibility", chat.RefreshVisibility, chat)
			end
			self:PushVisibilityTimer(chat)
			if EVENT_MANAGER and type(EVENT_MANAGER.UnregisterForUpdate) == "function" then
				EVENT_MANAGER:UnregisterForUpdate(self.name .. "Visible")
			end
			self.visibilityWritten = false
		end
		return true
	end

	local windowContainer, background = self:VisibilityControls(chat)

	if not self.visibilityWritten then
		self.originalVisibility = {
			hidden = windowContainer and windowContainer:IsHidden(),
			alpha = background and type(background.GetAlpha) == "function" and background:GetAlpha() or nil,
		}
		if EVENT_MANAGER and type(EVENT_MANAGER.RegisterForUpdate) == "function" then
			EVENT_MANAGER:RegisterForUpdate(self.name .. "Visible", VISIBILITY_PUSH_MS, function()
				addon:KeepVisible()
			end)
		end
		self.visibilityWritten = true
	end

	self:KeepVisible()
	return true
end

-- Pushes the expiry and puts right anything a minimise got in first with. Runs every ten
-- seconds while the option is on, and writes only what is not already so.
function addon:KeepVisible()
	local ready, chat = self:ChatReady()
	if not ready or not self:AlwaysVisible() then
		return
	end

	self:PushVisibilityTimer(chat)

	-- The client hides the whole control when the HUD goes away; shown again here, after its
	-- RefreshVisibility has had its say. A hidden control gets no OnUpdate, so this is also what
	-- starts the chat's own visibility timer ticking in a menu -- which the push above answers.
	if self:ShowInMenus() and chat.control:IsHidden() then
		self:Write("visibility", chat.control.SetHidden, chat.control, false)
	end

	local windowContainer, background = self:VisibilityControls(chat)
	if windowContainer and windowContainer:IsHidden() then
		self:Write("message area", windowContainer.SetHidden, windowContainer, false)
	end
	if background and type(background.GetAlpha) == "function" then
		local ok, alpha = pcall(background.GetAlpha, background)
		if ok and type(alpha) == "number" and alpha < 1 then
			-- The fade is an animation on this control; stopped first, or it would put the
			-- alpha back to where it was heading.
			local fade = chat.fadeBackground
			if fade and type(fade.IsPlaying) == "function" and fade:IsPlaying() then
				self:Write("background fade", fade.Stop, fade)
			end
			self:Write("background", background.SetAlpha, background, 1)
		end
	end

	-- The client's own idea of the state, so its next Minimize / Maximize agrees with what is on
	-- screen: MINIMIZE_CHAT_FRAGMENT reads it when a menu opens and maximises again on the way
	-- out, and the new-message notification is only for a window that cannot be seen.
	chat.isMinimized = false
end

-- ---------------------------------------------------------------------------------------
-- The text
--
-- The game's chat font is built in SharedChatContainer:GetChatFontFormatString:
--
--   face  = ZoFontGamepadChat:GetFontInfo()      ($(GAMEPAD_MEDIUM_FONT), resolved)
--   size  = "$(GP_" .. GetGamepadChatFontSize() .. ")"
--   style = soft-shadow-thin at 14 and under, soft-shadow-thick above
--
-- $(GP_20) is not 20: the substitution is defined per language in the font strings, and on the
-- Japanese client GP_20 is 15. There is no API to evaluate one, so the game's real size is read
-- off a label of our own given exactly the game's descriptor. That is the same font the chat
-- already has, so the measurement builds nothing new.
-- ---------------------------------------------------------------------------------------

function addon:GameFontSetting()
	if type(GetGamepadChatFontSize) ~= "function" then
		return nil
	end
	local ok, value = pcall(GetGamepadChatFontSize)
	if ok and type(value) == "number" and value > 0 then
		return value
	end
	return nil
end

-- The face the game itself hands the chat buffer, so a size change changes nothing else.
function addon:ChatFace()
	local font = ZoFontGamepadChat
	if font and type(font.GetFontInfo) == "function" then
		local ok, face = pcall(font.GetFontInfo, font)
		if ok and type(face) == "string" and face ~= "" then
			return face
		end
	end
	return "$(GAMEPAD_MEDIUM_FONT)"
end

-- The game's own threshold for the thinner shadow. The game applies it to the $(GP_n) number and
-- this add-on to the real size, which only differs on a client where the two differ -- and only
-- for text small enough that the thick shadow would swallow it anyway.
local function ShadowFor(size)
	if size <= 14 then
		return "soft-shadow-thin"
	end
	return "soft-shadow-thick"
end

-- Exactly the descriptor the game gives a chat tab at this setting.
function addon:GameDescriptor(settingValue)
	return string.format("%s|$(GP_%d)|%s", self:ChatFace(), Round(settingValue), ShadowFor(settingValue))
end

function addon:BuildDescriptor(size)
	size = Clamp(Round(size), self.MIN_FONT_SIZE, self.MAX_FONT_SIZE)
	return string.format("%s|%d|%s", self:ChatFace(), size, ShadowFor(size))
end

-- A hidden label of our own, only ever used to read a font size back.
function addon:ProbeLabel()
	if self.probe then
		return self.probe
	end
	if not WINDOW_MANAGER or not GuiRoot then
		return nil
	end
	local ok, label = pcall(WINDOW_MANAGER.CreateControl, WINDOW_MANAGER, "PBsChatWindowCustomizerProbe", GuiRoot, CT_LABEL)
	if not ok or not label then
		return nil
	end
	label:SetHidden(true)
	self.probe = label
	return label
end

function addon:MeasureGameFontSize(settingValue)
	local label = self:ProbeLabel()
	if not label then
		return nil
	end
	if not pcall(label.SetFont, label, self:GameDescriptor(settingValue)) then
		return nil
	end
	local ok, size = pcall(label.GetFontSize, label)
	if not ok or type(size) ~= "number" or size <= 0 then
		return nil
	end
	size = Round(size)
	self:Account().measured.fontSize[tostring(Round(settingValue))] = size
	return size
end

-- The size the game draws the chat at, at its current Small / Medium / Large setting.
function addon:DefaultFontSize()
	local settingValue = self:GameFontSetting()
	if not settingValue then
		return self.FALLBACK_FONT_SIZE
	end
	local measured = self:Account().measured.fontSize[tostring(Round(settingValue))]
	if type(measured) == "number" and measured > 0 then
		return measured
	end
	return self:MeasureGameFontSize(settingValue) or Round(settingValue)
end

function addon:FontSize()
	local size = self:Account().text.size
	if type(size) == "number" then
		return Clamp(Round(size), self.MIN_FONT_SIZE, self.MAX_FONT_SIZE)
	end
	return self:DefaultFontSize()
end

function addon:SetFontSize(size)
	self:Account().text.size = Clamp(Round(size), self.MIN_FONT_SIZE, self.MAX_FONT_SIZE)
end

-- True when the text would be drawn at a size other than the game's. While false, SetFont is
-- never called: a descriptor that matches nothing the client has built makes it build a font,
-- and on console that build is billed to the 100 MB pool every add-on shares.
function addon:FontDiffers()
	if not self:Account().enabled then
		return false
	end
	local size = self:Account().text.size
	if type(size) ~= "number" then
		return false
	end
	return self:FontSize() ~= self:DefaultFontSize()
end

-- The descriptor that is, or would be, on the chat: ours when the size differs, the game's
-- otherwise. The preview draws its sample lines with this.
function addon:EffectiveDescriptor()
	if self:FontDiffers() then
		return self:BuildDescriptor(self:FontSize())
	end
	local settingValue = self:GameFontSetting()
	if settingValue then
		return self:GameDescriptor(settingValue)
	end
	return self:BuildDescriptor(self:DefaultFontSize())
end

-- Calls fn(buffer, window) for every chat tab's TextBuffer. On console there is one container,
-- and the tabs are hidden, but every tab has its own buffer and they are all given the font: the
-- player switches between them with the chat menu.
function addon:ForEachChatBuffer(fn)
	local chat = self:Chat()
	if not chat or type(chat.containers) ~= "table" then
		return 0
	end
	local count = 0
	for _, container in ipairs(chat.containers) do
		if type(container.windows) == "table" then
			for _, window in ipairs(container.windows) do
				local buffer = window.buffer
				if buffer and type(buffer.SetFont) == "function" then
					fn(buffer, window)
					count = count + 1
				end
			end
		end
	end
	return count
end

function addon:ApplyFont()
	local ready = self:ChatReady()
	if not ready then
		return false
	end

	if self:FontDiffers() then
		local descriptor = self:BuildDescriptor(self:FontSize())
		local count = self:ForEachChatBuffer(function(buffer)
			self:Write("font", buffer.SetFont, buffer, descriptor)
		end)
		self.fontWritten = count > 0
		self.lastDescriptor = descriptor
		self.fontAppliedFor = self:GameFontSetting()
		return true
	end

	-- Putting the game's font back is the game's own descriptor for the size each tab is set to.
	-- window.fontSize is the number the game last gave that tab; the descriptor is rebuilt from
	-- it exactly as GetChatFontFormatString does.
	if self.fontWritten then
		local fallbackSetting = self:GameFontSetting()
		self:ForEachChatBuffer(function(buffer, window)
			local settingValue = type(window.fontSize) == "number" and window.fontSize or fallbackSetting
			if settingValue then
				self:Write("font", buffer.SetFont, buffer, self:GameDescriptor(settingValue))
			end
		end)
		self.fontWritten = false
		self.lastDescriptor = nil
	end
	self.fontAppliedFor = self:GameFontSetting()
	return true
end

-- ---------------------------------------------------------------------------------------
-- Both at once
-- ---------------------------------------------------------------------------------------

function addon:Refresh()
	self:ApplyLayout()
	self:ApplyDraw()
	self:ApplyVisibility()
	self:ApplyFont()
	if self.preview then
		self.preview:Update()
	end
end

function addon:ResetLayout()
	self:Account().layout = {}
end

function addon:ResetFont()
	self:Account().text = {}
end

function addon:ResetDraw()
	self:Account().draw = {}
end

function addon:ResetToDefaults()
	self:ResetLayout()
	self:ResetDraw()
	self:ResetFont()
	self:Account().alwaysVisible = false
	self:Account().inMenus = false
	self:Refresh()
end

-- The HUD is where the chat is drawn, and coming back to it is where anything the game rewrote
-- in the meantime is put right. Two things can:
--
--   * the text size setting. Changing Small / Medium / Large calls GAMEPAD_CHAT_SYSTEM:SetFontSize,
--     which puts the game's font straight back on every tab. The setting has no event, so the
--     number is compared with the one the font was last applied for.
--   * the layout, if anything in a future client calls LoadSettings again. Checked against the
--     control and rewritten only if it no longer matches.
function addon:OnHudShowing()
	if not self:ChatReady() then
		return
	end
	if (self.fontWritten or self:FontDiffers()) and self:GameFontSetting() ~= self.fontAppliedFor then
		self:ApplyFont()
	end
	if self.layoutWritten or self:LayoutDiffers() then
		self:ApplyLayout()
	end
	if self.drawWritten or self:DrawDiffers() then
		self:ApplyDraw()
	end
	-- A menu minimises the chat through MINIMIZE_CHAT_FRAGMENT, and the fragment maximises it
	-- again on the way out only if it was the one that minimised it. This is the moment to make
	-- sure the window really is back.
	if self:AlwaysVisible() or self.visibilityWritten then
		self:ApplyVisibility()
	end
end

-- ---------------------------------------------------------------------------------------
-- After a zone load
--
-- Reported on a PS5 after Update 51: arriving at a wayshrine or in a dungeon leaves the window
-- the wrong size, and opening a menu or the map puts it back -- that is this add-on's own
-- re-apply on the HUD's next show. So something between the loading screen and the first frame on
-- the HUD writes over the window, after this add-on's EVENT_PLAYER_ACTIVATED has run.
--
-- The client does not say when it has finished, so the window is checked a few times over the
-- seconds after a zone load rather than once, and re-written whenever it no longer matches. Each
-- time that happens the drift is recorded: what the control had, and how long after the zone load
-- it was found. "/pbchatwin status" prints the last of those, which is what turns the next PS5
-- round into a measurement instead of another guess.
-- ---------------------------------------------------------------------------------------

-- When to look after a zone load. The first is the frame after the client settles, the last is
-- late enough to catch a slow dungeon load.
addon.SETTLE_DELAYS_MS = { 250, 1000, 3000, 6000, 10000 }
addon.MAX_DRIFT_LOG = 6

function addon:RecordDrift(what)
	local control = self:Chat() and self:Chat().control
	if not control then
		return
	end
	local okDims, width, height = pcall(control.GetDimensions, control)
	local anchor = ReadAnchor(control, 0)
	local elapsed = self.lastActivatedAt and (GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0) - self.lastActivatedAt
	local elementPoint, elementX, elementY
	local element = self:HudElement()
	if element then
		elementPoint, _, _, elementX, elementY = element.defaultAnchor:Get()
	end

	self.driftLog = self.driftLog or {}
	table.insert(self.driftLog, 1, {
		what = what,
		elapsed = elapsed,
		width = okDims and Round(width) or nil,
		height = okDims and Round(height) or nil,
		point = anchor and anchor.point,
		offsetX = anchor and Round(anchor.offsetX),
		offsetY = anchor and Round(anchor.offsetY),
		elementPoint = elementPoint,
		elementX = elementX and Round(elementX),
		elementY = elementY and Round(elementY),
	})
	while #self.driftLog > self.MAX_DRIFT_LOG do
		table.remove(self.driftLog)
	end
end

-- One look: puts the window right if it has drifted, and says so.
function addon:Settle(what)
	local ready, chat = self:ChatReady()
	if not ready then
		return
	end
	if self:LayoutDiffers() and self.layoutWritten and not self:LayoutInPlace(chat.control, self:Clamped(self:Layout())) then
		self:RecordDrift(what)
	end
	self:ApplyLayout()
	self:ApplyDraw()
	if self:AlwaysVisible() or self.visibilityWritten then
		self:ApplyVisibility()
	end
end

-- Every delay in SETTLE_DELAYS_MS after a zone load. Each is a single check, so nothing is
-- polling while the player plays.
function addon:ScheduleSettle()
	for _, delay in ipairs(self.SETTLE_DELAYS_MS) do
		Later(function()
			addon:Settle(string.format("%dms after a zone load", delay))
		end, delay)
	end
end

-- ---------------------------------------------------------------------------------------
-- Status
-- ---------------------------------------------------------------------------------------

local POINT_NAMES = { "TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }

local function PointName(point)
	for _, name in ipairs(POINT_NAMES) do
		if point ~= nil and _G[name] == point then
			return name
		end
	end
	return tostring(point)
end

local function ControlName(control)
	if control == nil then
		return "nil"
	end
	if type(control) == "table" or type(control) == "userdata" then
		if type(control.GetName) == "function" then
			local ok, name = pcall(control.GetName, control)
			if ok and name then
				return name
			end
		end
	end
	return tostring(control)
end

local function DescribeLayout(layout)
	return string.format("corner=%s x=%d y=%d w=%d h=%d", tostring(layout.corner),
		Round(layout.x), Round(layout.y), Round(layout.width), Round(layout.height))
end

function addon:PrintStatus()
	local account = self:Account()
	local ready, chat = self:ChatReady()
	local rootWidth, rootHeight = self:RootSize()

	Line("|cFF69B4%s|r", self.title)
	Line("  chat: found=%s loaded=%s buffers=%d  screen=%dx%d",
		tostring(chat ~= nil), tostring(ready), self:ForEachChatBuffer(function() end), Round(rootWidth), Round(rootHeight))
	Line("  enabled=%s preview=%s alwaysVisible=%s inMenus=%s", tostring(account.enabled), tostring(account.preview),
		tostring(account.alwaysVisible), tostring(account.inMenus))

	Line("  layout:  %s  differs=%s written=%s", DescribeLayout(self:Clamped(self:Layout())),
		tostring(self:LayoutDiffers()), tostring(self.layoutWritten == true))
	Line("  game's:  %s  (%s)", DescribeLayout(self:GameLayout()), self.gameLayoutSource or "from an earlier session or the fallback")

	if chat then
		local control = chat.control
		for index = 0, 1 do
			local anchor = ReadAnchor(control, index)
			if anchor then
				Line("  on screen anchor %d: %s -> %s %s (%d, %d)", index, PointName(anchor.point),
					ControlName(anchor.relativeTo), PointName(anchor.relativePoint), Round(anchor.offsetX), Round(anchor.offsetY))
			end
		end
		local okDims, width, height = pcall(control.GetDimensions, control)
		local okLeft, left = pcall(control.GetLeft, control)
		local okTop, top = pcall(control.GetTop, control)
		Line("  on screen size: %s x %s  left=%s top=%s", okDims and tostring(Round(width)) or "?", okDims and tostring(Round(height)) or "?",
			okLeft and tostring(Round(left)) or "?", okTop and tostring(Round(top)) or "?")
		if type(control.GetDimensionConstraints) == "function" then
			local ok, minWidth, minHeight, maxWidth, maxHeight = pcall(control.GetDimensionConstraints, control)
			if ok then
				Line("  on screen limits: %s-%s x %s-%s", tostring(minWidth), tostring(maxWidth), tostring(minHeight), tostring(maxHeight))
			end
		end
	end

	local draw = self:Draw()
	local gameDraw = self:GameDraw()
	Line("  draw: tier=%s level=%d  differs=%s written=%s", tostring(draw.tier), draw.level,
		tostring(self:DrawDiffers()), tostring(self.drawWritten == true))
	Line("  game's: tier=%s level=%d  (%s)", tostring(gameDraw.tier), gameDraw.level,
		self.gameDrawSource or "from an earlier session or the fallback")

	if chat then
		local control = chat.control
		local okTier, tierValue = pcall(control.GetDrawTier, control)
		local okLevel, levelValue = pcall(control.GetDrawLevel, control)
		local tier = okTier and self:TierForValue(tierValue)
		Line("  on screen draw: tier=%s level=%s", tier and tier.key or tostring(okTier and tierValue),
			okLevel and tostring(Round(levelValue)) or "?")

		local windowContainer, background = self:VisibilityControls(chat)
		local ok, alpha = false, nil
		if background and type(background.GetAlpha) == "function" then
			ok, alpha = pcall(background.GetAlpha, background)
		end
		Line("  on screen visibility: window=%s minimized=%s messages=%s background alpha=%s",
			tostring(not chat.control:IsHidden()), tostring(chat.isMinimized),
			windowContainer and tostring(not windowContainer:IsHidden()) or "?",
			ok and string.format("%.2f", alpha) or "?")
		Line("  chat on HUD (the game's own setting)=%s", tostring(chat.hudEnabled))
	end

	Line("  text: size=%d default=%d setting=%s differs=%s written=%s", self:FontSize(), self:DefaultFontSize(),
		tostring(self:GameFontSetting()), tostring(self:FontDiffers()), tostring(self.fontWritten == true))
	Line("  text descriptor: %s", tostring(self.lastDescriptor or self:EffectiveDescriptor()))

	local element = self:HudElement()
	if element then
		local elementPoint, elementTarget, _, elementX, elementY = element.defaultAnchor:Get()
		Line("  hud element: anchor=%s %s (%s, %s) ours=%s usingDefault=%s", PointName(elementPoint),
			ControlName(elementTarget), tostring(elementX and Round(elementX)), tostring(elementY and Round(elementY)),
			tostring(self.elementWritten == true), tostring(element.currentAnchor == element.defaultAnchor))
	else
		Line("  hud element: none (a client from before Update 51)")
	end

	if self.driftLog and #self.driftLog > 0 then
		Line("  put right after something else wrote to the window:")
		for _, drift in ipairs(self.driftLog) do
			Line("    %s (%sms in): was %sx%s at %s (%s, %s), element %s (%s, %s)", drift.what,
				tostring(drift.elapsed), tostring(drift.width), tostring(drift.height), PointName(drift.point),
				tostring(drift.offsetX), tostring(drift.offsetY), PointName(drift.elementPoint),
				tostring(drift.elementX), tostring(drift.elementY))
		end
	end

	if self.writeErrors then
		for what, err in pairs(self.writeErrors) do
			Line("  |cFF4040refused|r %s: %s", what, err)
		end
	end
	if not chat then
		Line("  the gamepad chat is not on this client, so there is nothing to change.")
	end
end

-- ---------------------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------------------

local function Usage()
	Line("|cFF69B4%s|r", addon.title)
	Line("  %s                  -- this list", SLASH)
	Line("  %s status           -- settings, and what the chat really has", SLASH)
	Line("  %s pos <x> <y>      -- distances from the corner", SLASH)
	Line("  %s corner tl|tr|bl|br -- which corner (keeps the window where it is)", SLASH)
	Line("  %s size <w> <h>     -- width and height", SLASH)
	Line("  %s font <n>         -- message text size (%d-%d)", SLASH, addon.MIN_FONT_SIZE, addon.MAX_FONT_SIZE)
	Line("  %s always on | off  -- keep the window on screen instead of fading after 20s", SLASH)
	Line("  %s menus on | off   -- show it in menus too, not only on the HUD", SLASH)
	Line("  %s tier low|medium|high  -- draw the window under or over the rest of the UI", SLASH)
	Line("  %s level <n>        -- order within that tier (%d-%d)", SLASH, addon.MIN_DRAW_LEVEL, addon.MAX_DRAW_LEVEL)
	Line("  %s on | off         -- switch every change on or off", SLASH)
	Line("  %s preview          -- show or hide the preview frame", SLASH)
	Line("  %s reset [pos|font|draw] -- back to the game's own", SLASH)
	Line("  (%s is the same command)", SHORT_SLASH)
end

local function Numbers(args, first, count)
	local values = {}
	for index = first, first + count - 1 do
		local value = tonumber(args[index])
		if not value then
			return nil
		end
		values[#values + 1] = value
	end
	return values
end

local function OnSlash(argumentString)
	local args = {}
	for word in tostring(argumentString or ""):gmatch("%S+") do
		args[#args + 1] = word
	end
	local command = (args[1] or ""):lower()
	local account = addon:Account()

	if command == "status" then
		addon:PrintStatus()
	elseif command == "pos" or command == "position" then
		local values = Numbers(args, 2, 2)
		if not values then
			Line("usage: %s pos <x> <y>", SLASH)
			return
		end
		local layout = addon:Layout()
		addon:SetLayoutValue("corner", layout.corner)
		addon:SetLayoutValue("x", math.max(0, Round(values[1])))
		addon:SetLayoutValue("y", math.max(0, Round(values[2])))
		account.enabled = true
		addon:Refresh()
		Line("position: %s", DescribeLayout(addon:Clamped(addon:Layout())))
	elseif command == "corner" then
		local corner = addon.cornerByCommand[(args[2] or ""):lower()]
		if not corner then
			Line("usage: %s corner tl|tr|bl|br", SLASH)
			return
		end
		addon:SetCorner(corner.key)
		addon:Refresh()
		Line("corner: %s", DescribeLayout(addon:Clamped(addon:Layout())))
	elseif command == "size" then
		local values = Numbers(args, 2, 2)
		if not values then
			Line("usage: %s size <w> <h>", SLASH)
			return
		end
		addon:SetLayoutValue("width", Round(values[1]))
		addon:SetLayoutValue("height", Round(values[2]))
		account.enabled = true
		addon:Refresh()
		Line("size: %s", DescribeLayout(addon:Clamped(addon:Layout())))
	elseif command == "font" or command == "text" then
		local values = Numbers(args, 2, 1)
		if not values then
			Line("usage: %s font <%d-%d>", SLASH, addon.MIN_FONT_SIZE, addon.MAX_FONT_SIZE)
			return
		end
		addon:SetFontSize(values[1])
		account.enabled = true
		addon:Refresh()
		Line("text size: %d", addon:FontSize())
	elseif command == "always" then
		local what = (args[2] or ""):lower()
		if what ~= "on" and what ~= "off" then
			Line("usage: %s always on | off", SLASH)
			return
		end
		account.alwaysVisible = what == "on"
		if account.alwaysVisible then
			account.enabled = true
		end
		addon:Refresh()
		Line("always visible: %s", what)
	elseif command == "menus" or command == "menu" then
		local what = (args[2] or ""):lower()
		if what ~= "on" and what ~= "off" then
			Line("usage: %s menus on | off", SLASH)
			return
		end
		account.inMenus = what == "on"
		if account.inMenus then
			account.enabled = true
		end
		addon:Refresh()
		Line("shown in menus: %s", what)
	elseif command == "tier" then
		local tier = addon.tierByCommand[(args[2] or ""):lower()]
		if not tier then
			Line("usage: %s tier low | medium | high", SLASH)
			return
		end
		addon:SetDrawValue("tier", tier.key)
		account.enabled = true
		addon:Refresh()
		Line("draw tier: %s (level %d)", tier.key, addon:Draw().level)
	elseif command == "level" then
		local values = Numbers(args, 2, 1)
		if not values then
			Line("usage: %s level <%d-%d>", SLASH, addon.MIN_DRAW_LEVEL, addon.MAX_DRAW_LEVEL)
			return
		end
		addon:SetDrawValue("level", Clamp(Round(values[1]), addon.MIN_DRAW_LEVEL, addon.MAX_DRAW_LEVEL))
		account.enabled = true
		addon:Refresh()
		Line("draw level: %d (tier %s)", addon:Draw().level, addon:Draw().tier)
	elseif command == "on" or command == "off" then
		account.enabled = command == "on"
		addon:Refresh()
		Line("chat window changes %s", command)
	elseif command == "preview" then
		if addon.preview then
			local shown = addon.preview:Toggle()
			Line("preview %s", shown and "on" or "off")
		end
	elseif command == "reset" then
		local what = (args[2] or ""):lower()
		if what == "pos" or what == "position" or what == "size" or what == "layout" then
			addon:ResetLayout()
			addon:Refresh()
			Line("reset -- the chat window is back where the game puts it")
		elseif what == "font" or what == "text" then
			addon:ResetFont()
			addon:Refresh()
			Line("reset -- the chat text is back to the game's own size")
		elseif what == "draw" or what == "tier" or what == "level" then
			addon:ResetDraw()
			addon:Refresh()
			Line("reset -- the window is drawn in the game's own order again")
		else
			addon:ResetToDefaults()
			Line("reset -- the chat window and its text are back to the game's own")
		end
	else
		Usage()
	end
end

-- ---------------------------------------------------------------------------------------
-- Bootstrap
-- ---------------------------------------------------------------------------------------

-- How long after the first zone load to wait before touching the chat.
--
-- The chat itself loads on EVENT_PLAYER_ACTIVATED, on a handler registered before any add-on's,
-- but a second's grace costs nothing and keeps the first font build of the session out of the
-- moment every add-on is initialising at once against the 100 MB console pool -- the lesson from
-- PB's NamePlateChanger. If the chat is still not there, try again a few times, then give up
-- quietly: status says why.
local FIRST_APPLY_DELAY_MS = 1000
local RETRY_DELAY_MS = 1000
local MAX_ATTEMPTS = 10

function addon:TryFirstApply(attempt)
	local ready, chat = self:ChatReady()
	if ready then
		-- Read before anything is written, so the settings panel's defaults are the game's real
		-- numbers even while nothing is being changed.
		self:CaptureGameLayout(chat)
		self:DefaultFontSize()
		self.firstApplyDone = true
		self:Refresh()
		return
	end
	if attempt < MAX_ATTEMPTS then
		Later(function()
			self:TryFirstApply(attempt + 1)
		end, RETRY_DELAY_MS)
	end
end

local function OnPlayerActivated()
	addon.lastActivatedAt = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
	if addon.firstApplyDone then
		-- Later zone loads do not rebuild the chat, but nothing is lost by checking: the checks
		-- write only what no longer matches. The scheduled looks afterwards are for what the
		-- client writes once the loading screen is gone.
		addon:OnHudShowing()
		addon:ScheduleSettle()
		return
	end
	if addon.firstApplyScheduled then
		return
	end
	addon.firstApplyScheduled = true
	Later(function()
		addon:TryFirstApply(1)
	end, FIRST_APPLY_DELAY_MS)
end

-- Registered on the HUD fragment's own callback list: our function sits beside the client's,
-- nothing of theirs is wrapped. SHOWN rather than SHOWING, so the chat's own RefreshVisibility
-- for the same transition has already run.
local function RegisterHud()
	local fragment = HUD_FRAGMENT
	if not fragment or type(fragment.RegisterCallback) ~= "function" then
		return false
	end
	fragment:RegisterCallback("StateChange", function(_, newState)
		if newState == SCENE_FRAGMENT_SHOWN then
			addon:OnHudShowing()
		elseif addon:ShowInMenus() then
			-- The HUD going away is where the client hides the chat, and where
			-- MINIMIZE_CHAT_FRAGMENT minimises it. Both are undone here -- and again a moment
			-- later, because the two fragments belong to the same transition and nothing says
			-- which of them runs first.
			addon:ApplyVisibility()
			Later(function()
				addon:KeepVisible()
			end, MENU_REASSERT_MS)
		end
	end)
	return true
end

-- Menu to menu never touches the HUD fragment, and a scene that hides the chat for its own
-- reasons would otherwise be waiting on the ten-second check. Registered on the scene manager's
-- own callback list, beside the client's.
local function RegisterScenes()
	if not SCENE_MANAGER or type(SCENE_MANAGER.RegisterCallback) ~= "function" then
		return false
	end
	SCENE_MANAGER:RegisterCallback("SceneStateChanged", function(_, _, newState)
		if newState == SCENE_SHOWN and addon:ShowInMenus() then
			addon:KeepVisible()
		end
	end)
	return true
end

local function OnAddOnLoaded(_, loadedName)
	if loadedName ~= addon.name then
		return
	end
	EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

	addon.account = ZO_SavedVars:NewAccountWide("PBsChatWindowCustomizer_Data", 1, nil, addon.accountDefaults)
	addon:Account()

	SLASH_COMMANDS[SLASH] = OnSlash
	SLASH_COMMANDS[SHORT_SLASH] = OnSlash

	addon.hudRegistered = RegisterHud()
	addon.scenesRegistered = RegisterScenes()

	if addon.InitSettings then
		addon:InitSettings()
	end

	EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)

	-- ZO_HUDManager:PropagateSettings runs on this event and on a gamepad-mode change, and puts
	-- every HUD element back to its saved -- on console, its default -- anchor. Ours is deferred
	-- by a moment because both handlers are on the same event with no guaranteed order.
	local function OnScreenResized()
		Later(function()
			addon:Settle("after a screen resize")
		end, RESIZE_SETTLE_MS)
	end
	if EVENT_SCREEN_RESIZED then
		EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_SCREEN_RESIZED, OnScreenResized)
	end
	if EVENT_ALL_GUI_SCREENS_RESIZED then
		EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ALL_GUI_SCREENS_RESIZED, OnScreenResized)
	end
	if EVENT_GAMEPAD_PREFERRED_MODE_CHANGED then
		EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, OnScreenResized)
	end
end

PBS_CHAT_WINDOW_CUSTOMIZER = addon
EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
