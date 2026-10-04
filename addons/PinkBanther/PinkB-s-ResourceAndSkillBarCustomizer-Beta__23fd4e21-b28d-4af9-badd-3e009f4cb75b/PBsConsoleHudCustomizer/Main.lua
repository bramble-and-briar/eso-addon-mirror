-- PB's ResourceAndSkillBarCustomizer (named PB's ConsoleHudCustomizer until 1.27.16; the add-on's
-- own name, its folder and its saved variables keep the old one, so nobody's settings are lost)
-- Author: PinkBanther
--
-- Moves and resizes the player's health, magicka and stamina bars on the HUD.
--
-- The three bars are three sibling controls -- ZO_PlayerAttributeHealth, ...Magicka and
-- ...Stamina -- inside one top-level, ZO_PlayerAttribute, and the game gives the player no say
-- in any of it. The top-level is pinned to the bottom of the screen (BOTTOM of GuiRoot, 105 up,
-- 64 high: ZO_PlayerAttribute_Gamepad_Template) and is as wide as the screen allows
-- (ResizeToFitScreen, clamped to 1014-1600); health sits at its centre, magicka's right edge 237
-- in from its left, stamina's left edge 237 in from its right. Nothing else.
--
-- What this add-on writes, and why it is safe to write (full evidence in FINDINGS.md):
--
--   position   the anchor of each of the three containers: CENTER of the bar on BOTTOM of
--              GuiRoot, so the position is sideways from the middle of the screen and up from
--              the bottom edge. Anchoring to GuiRoot rather than to the group is what lets the
--              three be placed apart from each other; the containers stay children of
--              ZO_PlayerAttribute, so the HUD fragment still fades and hides them as before.
--   size       the scale of each container, 50% to 200%. Scale rather than SetDimensions,
--              because the width of these containers is not ours: ZO_UnitVisualizer_ShrinkExpand
--              writes 237 / 323 / 141 onto them, and animates between those, every time a buff
--              or debuff changes a maximum. Scale is never touched by the client, and it takes
--              the frame, the background, the bar and the numbers with it in proportion.
--
-- The werewolf, mount stamina and siege health bars are anchored to magicka, stamina and health
-- respectively, so they follow on their own; they are given the same scale as the bar they
-- belong to so the pair still lines up.
--
-- Both are writes to controls. Nothing in the attribute bars is hooked or wrapped, and none of
-- their code is called: the rule from PB's MailerExtension, measured on PS5, is that a client
-- closure created while an add-on frame is on the stack is permanently untrusted. These
-- controls run combat code -- power updates, the attribute visualiser, the warners -- on every
-- frame of a fight, which is the last place to leave one.
--
-- Nothing is written while the settings still equal the game's own. Each bar's place is measured
-- off the control before the first write, so "untouched" is not a guess: an installed-but-unset
-- add-on is indistinguishable from not having it.

if PBS_CONSOLE_HUD_CUSTOMIZER then
	return
end

local addon = {
	name = "PBsConsoleHudCustomizer",
}

-- The display name is a Lua constant and the version comes from the manifest, the same way the
-- other PB's add-ons do it -- reading the name back out of "## Title" mangles the "PB's "
-- prefix in the settings library. Typographic apostrophe (U+2019), not ASCII '.
local DISPLAY_NAME = "PB’s ResourceAndSkillBarCustomizer"
local AUTHOR = "PinkBanther"
local SLASH = "/pbhud"
local SHORT_SLASH = "/pbhc"

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

-- A control's own hidden flag and own alpha, not as drawn. The client's IsHidden and GetAlpha take
-- the parents into account (the client itself reads IsControlHidden and GetControlAlpha where it
-- means the control alone). Reading the drawn state is what kept 1.27.4 from ever holding the bars
-- back -- their group was already hidden -- and made the effect styles rewrite their alpha on every
-- update of a fade (FINDINGS 65).
function addon.OwnHidden(control)
	if type(control.IsControlHidden) == "function" then
		local ok, hidden = pcall(control.IsControlHidden, control)
		if ok then
			return hidden and true or false
		end
	end
	local ok, hidden = pcall(control.IsHidden, control)
	return ok and hidden and true or false
end

function addon.OwnAlpha(control)
	if type(control.GetControlAlpha) == "function" then
		local ok, alpha = pcall(control.GetControlAlpha, control)
		if ok and type(alpha) == "number" then
			return alpha
		end
	end
	local ok, alpha = pcall(control.GetAlpha, control)
	return ok and type(alpha) == "number" and alpha or nil
end

-- Whole numbers everywhere a position is stored or written. Also turns -0 into 0, which a
-- distance measured leftwards from the middle of the screen otherwise comes back as.
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
addon.Clamp = Clamp

-- ---------------------------------------------------------------------------------------
-- The elements
--
-- Four controls are placed and scaled, and all four work the same way: an anchor of
-- CENTER -> GuiRoot BOTTOM, and a scale.
--
-- The three attribute bars are container controls with a companion each: the small bar the game
-- anchors to them and shows in their place (werewolf over magicka, mount stamina under stamina,
-- siege health under health). The companion keeps its own anchor -- it is relative to the bar,
-- so it moves with it -- and is given the same scale, or the pair would no longer meet.
--
-- The skill bar is the action bar's top-level, ZO_ActionBar1. Every button, the ultimate, the
-- quickslot and the weapon swap marker are anchored inside it, so its anchor and scale are the
-- whole bar's. normalWidth is what the control is when the game has just laid it out; a
-- measurement is only taken while it reads that (see CaptureGame).
-- ---------------------------------------------------------------------------------------

addon.bars = {
	{
		key = "health",
		controlName = "ZO_PlayerAttributeHealth",
		companionName = "ZO_PlayerAttributeSiegeHealth",
		commands = { "health", "hp", "h" },
		stringId = "SI_PBSCHC_BAR_HEALTH",
		normalWidth = 237,
		colour = { 0.77, 0.20, 0.20 },
	},
	{
		key = "magicka",
		controlName = "ZO_PlayerAttributeMagicka",
		companionName = "ZO_PlayerAttributeWerewolf",
		commands = { "magicka", "mag", "m" },
		stringId = "SI_PBSCHC_BAR_MAGICKA",
		normalWidth = 237,
		colour = { 0.24, 0.44, 0.85 },
	},
	{
		key = "stamina",
		controlName = "ZO_PlayerAttributeStamina",
		companionName = "ZO_PlayerAttributeMountStamina",
		commands = { "stamina", "stam", "s" },
		stringId = "SI_PBSCHC_BAR_STAMINA",
		normalWidth = 237,
		colour = { 0.31, 0.62, 0.24 },
	},
}

-- The skill bar. No companion, and no colour of its own in the preview -- it is drawn in the
-- add-on's pink, because unlike the three attribute bars it is not a resource.
addon.actionBar = {
	key = "skillbar",
	controlName = "ZO_ActionBar1",
	commands = { "skillbar", "skills", "bar", "action" },
	stringId = "SI_PBSCHC_BAR_SKILLBAR",
	colour = { 1, 0.41, 0.71 },
	isActionBar = true,
	normalWidth = 606,
}

addon.elements = {}
for _, bar in ipairs(addon.bars) do
	addon.elements[#addon.elements + 1] = bar
end
addon.elements[#addon.elements + 1] = addon.actionBar

addon.barByKey = {}
addon.barByCommand = {}
for _, bar in ipairs(addon.elements) do
	addon.barByKey[bar.key] = bar
	for _, command in ipairs(bar.commands) do
		addon.barByCommand[command] = bar
	end
end

-- ---------------------------------------------------------------------------------------
-- The game's own numbers
--
-- All from playerattributebars.lua / .xml at API 101050, and only ever used as a fallback: the
-- real values are measured off the controls in CaptureGame.
-- ---------------------------------------------------------------------------------------

addon.GAME = {
	-- ZO_PlayerAttributeContainer
	barWidth = 237,
	barHeight = 23,
	-- ZO_PlayerAttribute: 64 high, BOTTOM of GuiRoot at -105 (the gamepad template).
	groupHeight = 64,
	groupBottom = 105,
	-- ResizeToFitScreen: clamp(screenWidth - 502 * 2, (323 + 15) * 3, 1600)
	edgeOffset = 502,
	minGroupWidth = 1014,
	maxGroupWidth = 1600,
	-- The inset of magicka's right edge from the group's left, and stamina's left from its right.
	inset = 237,
	-- ZO_ActionBar1: 70 high from the XML, 606 wide and BOTTOM of GuiRoot at -25 from
	-- GAMEPAD_CONSTANTS in actionbar.lua.
	actionBarWidth = 606,
	actionBarHeight = 70,
	actionBarBottom = 25,
}

addon.MIN_SCALE = 50
addon.MAX_SCALE = 200
addon.DEFAULT_SCALE = 100

addon.POSITION_KEYS = { "x", "y" }

-- Every value the player can change is stored only once they change it. An empty table means
-- "the game's own", which is what makes an untouched install cost nothing.
--
-- The measurements are not settings: they are where the client draws the bars, kept so the
-- settings panel knows the game's values before the HUD has been up in a session.
addon.accountDefaults = {
	enabled = true,
	preview = true,
	-- Whether the skill bar is this add-on's to touch at all. Off, everything it does to the
	-- bar -- the place, the size, the gaps, the other weapon set's row, the text on the icons and
	-- the shade -- is put back and stays off, so another add-on that lays the bar out has it to
	-- itself. The three attribute bars are unaffected.
	skillBar = true,
	bars = {},
	spacing = {},
	measured = {},
	-- The text on the skill bar's icons, and the back bar. Defaults rather than "unset": these
	-- draw something the game does not draw at all, so there is no game value to fall back to.
	text = {
		-- Bumped when a default in here is thought better of; see Account().
		version = 2,
		timerMode = "addon",
		timerSize = 27,
		countSize = 22,
		showCounts = true,
		-- From one target rather than two. Two was the first choice, so that a single-target
		-- ability did not carry a "1" for its whole duration -- but "nothing is showing" is a
		-- worse first impression than a 1, and most of what a player checks is single-target.
		countFromOne = true,
		decimals = true,
	},
	-- The look of the three attribute bars: the game's own, or flat rectangles. Standard is the
	-- default, and while it is chosen nothing is built at all.
	style = "standard",
	plainOpacity = 100,
	plainBorder = true,
	plainBorderColour = "black",
	resourceTextAlignment = "left",
	-- The shade over a skill icon while its effect runs.
	shade = {
		enabled = true,
		darkness = 60,
		direction = "down",
		leadingEdge = true,
	},
	backBar = {
		enabled = true,
		showEmpty = true,
		offsetX = 0,
		gap = 4,
		scale = 100,
	},
}

-- ---------------------------------------------------------------------------------------
-- Saved settings
-- ---------------------------------------------------------------------------------------

-- 1.1.0 called the countdown modes auto / always / never, for a setting that meant something
-- slightly different. Carried over rather than reset, so nobody's choice is thrown away.
local RENAMED_TIMER_MODES = { auto = "addon", always = "both", never = "game" }
local DEFAULTED_GROUPS = { "text", "backBar", "shade" }

-- The saved settings, repaired if a partial table came back from an older build. Never returns
-- nil: every caller would otherwise need the same guard.
--
-- Repaired once, not on every call. It is called many times on every update of every loop, and
-- until 1.27.1 it built two tables each time -- most of the garbage the skill bar and the watch
-- made (FINDINGS 57). The repair runs again whenever the saved table, or any table in it the repair
-- fills, is not the one it last repaired: a reset that swaps in an empty table is caught.
local repaired = {}
function addon:Account()
	local account = self.account
	if type(account) ~= "table" then
		account = {}
		self.account = account
	end
	if repaired.account == account and repaired.bars == account.bars and repaired.measured == account.measured
		and repaired.spacing == account.spacing and repaired.text == account.text
		and repaired.backBar == account.backBar and repaired.shade == account.shade then
		return account
	end
	if account.enabled == nil then
		account.enabled = true
	end
	if account.preview == nil then
		account.preview = true
	end
	if account.skillBar == nil then
		account.skillBar = true
	end
	if type(account.bars) ~= "table" then
		account.bars = {}
	end
	if type(account.measured) ~= "table" then
		account.measured = {}
	end
	if type(account.spacing) ~= "table" then
		account.spacing = {}
	end
	-- 1.3.x had a liquid style here, which never drew anything on a console and has been taken
	-- out. Anyone who had chosen it gets the plain one, at an opacity in the range this uses.
	if account.style == "liquid" then
		account.style = "plain"
	end
	-- 1.9.x offered to leave the game's arrow frame in place. It is always put away now, and an
	-- outline of this add-on's own is the frame on offer instead.
	if account.plainKeepFrame ~= nil then
		account.plainKeepFrame = nil
	end
	if account.liquidStrength ~= nil then
		if type(account.plainOpacity) ~= "number" then
			account.plainOpacity = math.min(100, math.max(10, Round(account.liquidStrength)))
		end
		account.liquidStrength = nil
	end
	if type(account.text) == "table" and RENAMED_TIMER_MODES[account.text.timerMode] then
		account.text.timerMode = RENAMED_TIMER_MODES[account.text.timerMode]
	end

	-- ZO_SavedVars copies the defaults into the saved table, so a default that is later thought
	-- better of stays on every install that ever ran the old build. countFromOne started false in
	-- 1.1.0 and became true in 1.1.1 -- and an install from before that kept the false, which
	-- reads as "the target count does not work" for every single-target ability there is.
	--
	-- Moved on once, with a marker so that anyone who does want it from two targets can say so
	-- and be left alone from then on.
	if type(account.text) == "table" and account.text.version == nil then
		if account.text.countFromOne == false then
			account.text.countFromOne = true
		end
		account.text.version = 2
	end
	for _, group in ipairs(DEFAULTED_GROUPS) do
		if type(account[group]) ~= "table" then
			account[group] = {}
		end
		for key, value in pairs(self.accountDefaults[group]) do
			if account[group][key] == nil then
				account[group][key] = value
			end
		end
	end
	for _, bar in ipairs(self.elements) do
		if type(account.bars[bar.key]) ~= "table" then
			account.bars[bar.key] = {}
		end
		if type(account.measured[bar.key]) ~= "table" then
			account.measured[bar.key] = {}
		end
	end
	repaired.account, repaired.bars, repaired.measured, repaired.spacing = account, account.bars, account.measured, account.spacing
	repaired.text, repaired.backBar, repaired.shade = account.text, account.backBar, account.shade
	return account
end

function addon:Saved(bar)
	return self:Account().bars[bar.key]
end

function addon:Measured(bar)
	return self:Account().measured[bar.key]
end

-- Whether this add-on touches the skill bar. Everything it draws on or writes to the bar asks
-- this first, and everything it has already written is put back the moment the answer changes.
function addon:SkillBarAllowed()
	local account = self:Account()
	return account.enabled == true and account.skillBar ~= false
end

function addon:SetSkillBarAllowed(allowed)
	self:Account().skillBar = allowed and true or false
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
-- Positions
--
-- A position is { x, y }: x is how far the middle of the bar is from the middle of the screen,
-- negative to the left, and y is how far it is up from the bottom edge. That is the shape of
-- the anchor the add-on writes -- CENTER of the bar on BOTTOM of GuiRoot -- so the numbers in
-- the settings panel and the numbers on the control are the same numbers.
--
-- The middle rather than a corner, because a bar's width is not ours: the attribute visualiser
-- writes 141, 237 or 323 onto it as buffs come and go. Held by its middle, a bar stays where it
-- was put and grows evenly both ways.
-- ---------------------------------------------------------------------------------------

-- Where the game puts a bar, worked out from its own layout rules rather than measured. Used
-- until a measurement is in, and after that only if the measurement was refused.
function addon:FallbackPosition(bar)
	local game = self.GAME
	local rootWidth, rootHeight = self:RootSize()
	if bar.isActionBar then
		return { x = 0, y = Round(game.actionBarBottom + game.actionBarHeight / 2) }
	end
	local groupWidth = Clamp(rootWidth - game.edgeOffset * 2, game.minGroupWidth, game.maxGroupWidth)
	local y = game.groupBottom + game.groupHeight / 2
	if bar.key == "health" then
		return { x = 0, y = Round(y) }
	end
	-- Magicka's right edge is inset from the group's left, so its middle is half a bar further
	-- in again; stamina is the mirror of that.
	local fromCentre = groupWidth / 2 - game.inset + game.barWidth / 2
	if bar.key == "magicka" then
		return { x = Round(-fromCentre), y = Round(y) }
	end
	return { x = Round(fromCentre), y = Round(y) }
end

-- Where the game puts a bar: as measured off the control, otherwise worked out.
function addon:GamePosition(bar)
	local measured = self:Measured(bar)
	local fallback = self:FallbackPosition(bar)
	return {
		x = type(measured.x) == "number" and measured.x or fallback.x,
		y = type(measured.y) == "number" and measured.y or fallback.y,
	}
end

-- Where the player has asked for a bar: the saved value where there is one, the game's otherwise.
function addon:Position(bar)
	local saved = self:Saved(bar)
	local game = self:GamePosition(bar)
	return {
		x = type(saved.x) == "number" and saved.x or game.x,
		y = type(saved.y) == "number" and saved.y or game.y,
	}
end

function addon:SetPositionValue(bar, key, value)
	self:Saved(bar)[key] = Round(value)
end

-- The scale the player has asked for, as a percentage.
function addon:ScalePercent(bar)
	local saved = self:Saved(bar).scale
	if type(saved) == "number" then
		return Clamp(Round(saved), self.MIN_SCALE, self.MAX_SCALE)
	end
	return self.DEFAULT_SCALE
end

function addon:SetScalePercent(bar, value)
	self:Saved(bar).scale = Clamp(Round(value), self.MIN_SCALE, self.MAX_SCALE)
end

-- Pulls a position onto the screen: whole numbers, and never so far out that the middle of the
-- bar leaves the screen. Applied to what is written rather than to what is saved, so a position
-- chosen on one screen size is not rewritten by visiting a smaller one.
function addon:ClampedPosition(position)
	local rootWidth, rootHeight = self:RootSize()
	local halfWidth = Round(rootWidth / 2)
	return {
		x = Clamp(Round(position.x), -halfWidth, halfWidth),
		y = Clamp(Round(position.y), 0, Round(rootHeight)),
	}
end

-- What should be on screen right now for one bar: the player's, or the game's while switched off.
function addon:EffectivePosition(bar)
	if self:Account().enabled then
		return self:ClampedPosition(self:Position(bar))
	end
	return self:ClampedPosition(self:GamePosition(bar))
end

function addon:EffectiveScalePercent(bar)
	if self:Account().enabled then
		return self:ScalePercent(bar)
	end
	return self.DEFAULT_SCALE
end

-- The rectangle a bar would occupy: left, top, width, height. The size is the container's own
-- (237 x 23 in its normal state) multiplied by the scale. Only the preview needs it.
function addon:RectOf(bar)
	local rootWidth, rootHeight = self:RootSize()
	local position = self:EffectivePosition(bar)
	local scale = self:EffectiveScalePercent(bar) / 100
	local width = (bar.normalWidth or self.GAME.barWidth) * scale
	local height = (bar.isActionBar and self.GAME.actionBarHeight or self.GAME.barHeight) * scale
	local centreX = rootWidth / 2 + position.x
	local centreY = rootHeight - position.y
	return centreX - width / 2, centreY - height / 2, width, height
end

-- True when a bar would be somewhere, or some size, other than where the game draws it.
function addon:BarDiffers(bar)
	if not self:Account().enabled then
		return false
	end
	if bar.isActionBar and not self:SkillBarAllowed() then
		return false
	end
	if self:ScalePercent(bar) ~= self.DEFAULT_SCALE then
		return true
	end
	local want = self:ClampedPosition(self:Position(bar))
	local game = self:ClampedPosition(self:GamePosition(bar))
	return want.x ~= game.x or want.y ~= game.y
end

function addon:AnythingDiffers()
	for _, bar in ipairs(self.elements) do
		if self:BarDiffers(bar) then
			return true
		end
	end
	return self.SpacingDiffers ~= nil and self:SpacingDiffers()
end

-- ---------------------------------------------------------------------------------------
-- The controls
--
-- Looked up by name when they are needed, never cached across a reload. A plain _G lookup by
-- key, not an iteration: walking _G with next is what raises a private-function error on
-- console (PB's LuaMemoryMonitor).
-- ---------------------------------------------------------------------------------------

function addon:Control(bar)
	local control = _G[bar.controlName]
	if type(control) ~= "table" and type(control) ~= "userdata" then
		return nil
	end
	if type(control.SetAnchor) ~= "function" then
		return nil
	end
	return control
end

function addon:Companion(bar)
	local control = _G[bar.companionName]
	if type(control) ~= "table" and type(control) ~= "userdata" then
		return nil
	end
	if type(control.SetScale) ~= "function" then
		return nil
	end
	return control
end

-- The bars are built from XML when the UI loads, and ZO_PlayerAttribute_OnInitialized makes
-- PLAYER_ATTRIBUTE_BARS out of them. Both are checked: the controls are what is written to, and
-- the object's existence is what says the game has finished putting them together. The skill
-- bar's control is checked the same way, in the same loop.
function addon:BarsReady()
	if type(PLAYER_ATTRIBUTE_BARS) ~= "table" then
		return false
	end
	for _, bar in ipairs(self.elements) do
		-- A skill bar this add-on has been told to leave alone is not a reason to wait: the
		-- attribute bars are still its to place.
		if not (bar.isActionBar and not self:SkillBarAllowed()) and not self:Control(bar) then
			return false
		end
	end
	return true
end

-- ---------------------------------------------------------------------------------------
-- Reading the game's layout
--
-- Once per session per bar, and only before this add-on has written anything to it: after that
-- the control carries our anchor, and reading it back would make our own position the new
-- "default" -- the mistake PB's NamePlateChanger had to grow a repair path for. A reload
-- rebuilds the bars from XML, so every session starts with pristine controls.
--
-- A reading is only taken while the bar is its normal 237 wide. The attribute visualiser
-- stretches a bar to 323 or shrinks it to 141 whenever a buff or debuff moves a maximum, and
-- the middle of a stretched bar is not where the middle of a normal one is -- the game holds
-- magicka by its right edge and stamina by its left. A bar that is not its normal width is left
-- for the next HUD show to measure.
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

local function ReadScale(control)
	if type(control.GetScale) ~= "function" then
		return nil
	end
	local ok, scale = pcall(control.GetScale, control)
	if ok and type(scale) == "number" and scale > 0 then
		return scale
	end
	return nil
end

-- The rectangle the control really occupies, in GuiRoot's units.
function addon:ScreenRect(control)
	local okLeft, left = pcall(control.GetLeft, control)
	local okTop, top = pcall(control.GetTop, control)
	local okDims, width, height = pcall(control.GetDimensions, control)
	if not (okLeft and okTop and okDims) then
		return nil
	end
	if type(left) ~= "number" or type(top) ~= "number" or type(width) ~= "number" or type(height) ~= "number" then
		return nil
	end
	if width <= 0 or height <= 0 then
		return nil
	end
	return left, top, width, height
end

-- The anchors and the scale a bar had before this add-on touched it. Taken once, before the
-- first write, and the one thing that has to succeed: without it there would be nothing to put
-- back, so a bar whose anchor cannot be read is left where the game has it.
function addon:CaptureAnchors(bar)
	local control = self:Control(bar)
	if not control then
		return false
	end
	if self.original[bar.key] then
		return true
	end
	if self.written[bar.key] then
		return false
	end
	local anchor = ReadAnchor(control, 0)
	if not anchor then
		return false
	end
	local companion = self:Companion(bar)
	self.original[bar.key] = {
		anchors = { anchor, ReadAnchor(control, 1) },
		scale = ReadScale(control) or 1,
		companionScale = companion and ReadScale(companion) or 1,
	}
	return true
end

-- Where the game itself draws the bar, measured off the control. Best effort, and deliberately
-- separate from CaptureAnchors: it can fail for reasons that have nothing to do with whether the
-- add-on can do its job -- a control the client has not laid out yet reads back no rectangle at
-- all, and a bar stretched by a buff reads back the wrong one. Until it succeeds the worked-out
-- fallback stands in, and it is tried again on the next HUD show.
--
-- 1.3.1 and earlier folded this into the capture and returned its failure as the capture's, so a
-- bar whose rectangle was not readable at that moment was never moved at all -- the position
-- setting appearing to do nothing, on some logins and not others.
function addon:MeasureGame(bar)
	local control = self:Control(bar)
	if not control then
		return false
	end
	if self.written[bar.key] then
		return false
	end
	local measured = self:Measured(bar)
	if type(measured.x) == "number" and type(measured.y) == "number" then
		return true
	end
	local left, top, width, height = self:ScreenRect(control)
	if not left then
		self.measureNote = "waiting for the bars to have a size on screen"
		return false
	end
	if Round(width) ~= (bar.normalWidth or self.GAME.barWidth) then
		self.measureNote = "waiting for the bars to be their normal width"
		return false
	end
	local rootWidth, rootHeight = self:RootSize()
	measured.x = Round(left + width / 2 - rootWidth / 2)
	measured.y = Round(rootHeight - (top + height / 2))
	self.measureNote = nil
	return true
end

-- Both, for the callers that want the bar looked at as a whole. The measurement's answer is not
-- the one returned: only the capture decides whether this add-on may write.
function addon:CaptureGame(bar)
	local captured = self:CaptureAnchors(bar)
	self:MeasureGame(bar)
	return captured
end

function addon:CaptureAll()
	local captured = true
	for _, bar in ipairs(self.elements) do
		if not self:CaptureGame(bar) then
			captured = false
		end
	end
	return captured
end

-- ---------------------------------------------------------------------------------------
-- Writing
-- ---------------------------------------------------------------------------------------

-- Every write goes through here so a refused one is recorded rather than lost. Writing a
-- control's anchor is marked "protected-attributes" in the API dump; what that means for a
-- client control on console is one of the things FINDINGS.md lists to measure, and status
-- prints whatever came back.
function addon:Write(what, fn, ...)
	if self.returnTrace and self.returnTrace.started then
		self.returnTrace:Wrote(what)
	end
	local ok, err = pcall(fn, ...)
	if not ok then
		self.writeErrors = self.writeErrors or {}
		self.writeErrors[what] = tostring(err)
	end
	return ok
end

-- True when the control already has exactly this anchor and scale, so a HUD show does not
-- rewrite the same numbers every time the player closes a menu.
function addon:InPlace(control, position, scale)
	local anchor = ReadAnchor(control, 0)
	if not anchor or ReadAnchor(control, 1) then
		return false
	end
	local current = ReadScale(control)
	return anchor.point == CENTER and anchor.relativePoint == BOTTOM and anchor.relativeTo == GuiRoot
		and Round(anchor.offsetX) == position.x and Round(anchor.offsetY) == -position.y
		and current ~= nil and math.abs(current - scale) < 0.001
end

function addon:RestoreBar(bar)
	local original = self.original[bar.key]
	local control = self:Control(bar)
	if not original or not control then
		return false
	end

	self:Write("anchor", control.ClearAnchors, control)
	for index = 1, 2 do
		local anchor = original.anchors[index]
		if anchor then
			self:Write("anchor", control.SetAnchor, control, anchor.point, anchor.relativeTo, anchor.relativePoint,
				anchor.offsetX, anchor.offsetY, anchor.constrains)
		end
	end
	self:Write("scale", control.SetScale, control, original.scale)
	local companion = self:Companion(bar)
	if companion then
		self:Write("scale", companion.SetScale, companion, original.companionScale)
	end
	self.written[bar.key] = false
	return true
end

-- Puts one bar where the settings say, or back where the game had it.
function addon:ApplyBar(bar)
	local control = self:Control(bar)
	if not control then
		return false
	end

	if not self:BarDiffers(bar) then
		if self.written[bar.key] then
			return self:RestoreBar(bar)
		end
		-- Still worth a look: the measurement may not have been takeable yet.
		self:CaptureAnchors(bar)
		self:MeasureGame(bar)
		return true
	end

	if not self:CaptureAnchors(bar) then
		-- Without the bar's own anchor there would be nothing to put back. Better not to move
		-- it at all than to move it for good.
		self.writeErrors = self.writeErrors or {}
		self.writeErrors.capture = "could not read " .. bar.key .. "'s own anchor"
		return false
	end
	-- A measurement that is not ready yet only means the game's own position is still the
	-- worked-out one. It never stops the bar being put where the player asked.
	self:MeasureGame(bar)

	local position = self:ClampedPosition(self:Position(bar))
	local scale = self:ScalePercent(bar) / 100
	if self.written[bar.key] and self:InPlace(control, position, scale) then
		return true
	end

	self.writeCount = (self.writeCount or 0) + 1
	self:Write("anchor", control.ClearAnchors, control)
	self:Write("anchor", control.SetAnchor, control, CENTER, GuiRoot, BOTTOM, position.x, -position.y)
	self:Write("scale", control.SetScale, control, scale)

	-- The companion keeps its own anchor -- it is relative to this bar, so it has already
	-- moved -- but it has to be scaled to match or the two no longer meet.
	local companion = self:Companion(bar)
	if companion then
		self:Write("scale", companion.SetScale, companion, scale)
	end

	self.written[bar.key] = true
	return true
end

function addon:Apply()
	if not self:BarsReady() then
		return false
	end
	for _, bar in ipairs(self.elements) do
		self:ApplyBar(bar)
	end
	if self.skillbar then
		self.skillbar:Apply()
	end
	return true
end

-- ---------------------------------------------------------------------------------------
-- Keeping it put
--
-- Everything this add-on writes is checked once a second while the HUD is up, and written again
-- if it is no longer there. PB's MiniMap has had the same watch since its first release, for the
-- same reason: on a console there is no way to see what moved something, and a layout that puts
-- itself back is worth more than knowing.
--
-- It is nearly free -- an anchor and a scale read per control, and nothing written while they
-- match -- and it counts what it had to put back, so status can say whether anything really is
-- fighting this add-on or whether a write simply never landed.
-- ---------------------------------------------------------------------------------------

local WATCH_INTERVAL_MS = 1000

function addon:AnythingWritten()
	for _, bar in ipairs(self.elements) do
		if self.written[bar.key] then
			return true
		end
	end
	return self.skillbar ~= nil and self.skillbar.written == true
end

function addon:Verify()
	if not self:BarsReady() then
		return
	end
	if not self:AnythingDiffers() and not self:AnythingWritten() then
		return
	end
	local before = self.writeCount or 0
	self:Apply()
	if (self.writeCount or 0) > before then
		self.repairs = (self.repairs or 0) + 1
		self.lastRepair = GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0
	end
end

function addon:Watch(start)
	if not EVENT_MANAGER or type(EVENT_MANAGER.RegisterForUpdate) ~= "function" then
		return false
	end
	if start then
		if self.watching then
			return true
		end
		EVENT_MANAGER:RegisterForUpdate(self.name .. "Watch", WATCH_INTERVAL_MS, function()
			addon:Verify()
		end)
		self.watching = true
	else
		if not self.watching then
			return true
		end
		EVENT_MANAGER:UnregisterForUpdate(self.name .. "Watch")
		self.watching = false
	end
	return true
end

function addon:Refresh()
	self:Apply()
	if self.timers then
		self.timers:Refresh()
	end
	if self.plain then
		self.plain:Refresh()
	end
	if self.preview then
		self.preview:Update()
	end
end

function addon:ResetBar(bar)
	self:Account().bars[bar.key] = {}
	if bar.isActionBar then
		self:ResetSpacing()
	end
end

function addon:ResetAll()
	for _, bar in ipairs(self.elements) do
		self:ResetBar(bar)
	end
	self:ResetSpacing()
	self:Refresh()
end

-- The HUD is where the bars are drawn, and coming back to it is where anything that has drifted
-- is put right: a screen resize moves the group and so the game's own positions, and the first
-- measurement may still be waiting for the bars to be at their normal width. Only what no
-- longer matches is written.
function addon:OnHudShowing()
	if self.returnTrace then
		self.returnTrace:Event("HUD SHOWN")
	end
	if not self:BarsReady() then
		return
	end
	self:Apply()
	self:Watch(true)
	if self.timers and not self.timersFollowBar then
		self.timers:OnHudStateChange(true)
	end
	if self.plain and not self.plainFollowsBars then
		self.plain:OnHudStateChange(true)
	end
end

function addon:OnHudHidden()
	self:Watch(false)
	if self.timers and not self.timersFollowBar then
		self.timers:OnHudStateChange(false)
	end
	if self.plain and not self.plainFollowsBars then
		self.plain:OnHudStateChange(false)
	end
end

-- The bars' own fragment, for the styles drawn on them. It is a fade: SHOWING is the first frame of
-- a 250 ms fade-in, and SHOWN is its end. Waiting for the HUD's SHOWN meant the bars faded in as
-- the game draws them and changed style afterwards, which read as a flash every time a menu closed
-- (1.27.3, FINDINGS 59). The same fragment is shown with the siege bar, where the HUD's is not.
-- The skill bar's own fragment, for what is drawn on it, for the same reason as the attribute
-- bars' (below): it is a 250 ms fade, and resuming only when the HUD had finished showing let the
-- skill bar fade in without this add-on's countdowns, row and shades, and with the game's own
-- countdown back, before changing (1.27.8, FINDINGS 64).
function addon:OnActionBarFragment(state)
	if not self.timers then
		return
	end
	if state == SCENE_FRAGMENT_SHOWING or state == SCENE_FRAGMENT_SHOWN then
		if self:BarsReady() then
			self.timers:OnHudStateChange(true)
		end
	elseif state == SCENE_FRAGMENT_HIDDEN then
		self.timers:OnHudStateChange(false)
	end
end

function addon:OnBarsFragment(state)
	if not self.plain then
		return
	end
	-- Recorded from the first frame of the fade, whatever the style, so a flicker can be measured
	-- (FINDINGS 64): before the add-on does anything with the bars.
	if self.returnTrace then
		if state == SCENE_FRAGMENT_SHOWING then
			self.returnTrace:Begin("bars' fragment SHOWING")
		elseif state == SCENE_FRAGMENT_SHOWN then
			self.returnTrace:Event("bars' fragment SHOWN")
		elseif state == SCENE_FRAGMENT_HIDDEN then
			self.returnTrace:Finish()
		end
	end
	-- Whether the fade has ended, before anything is drawn for this state (FINDINGS 69).
	self.plain:OnFade(state)
	if state == SCENE_FRAGMENT_SHOWING or state == SCENE_FRAGMENT_SHOWN then
		if self:BarsReady() then
			self.plain:OnHudStateChange(true)
		end
	elseif state == SCENE_FRAGMENT_HIDDEN then
		self.plain:OnHudStateChange(false)
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

function addon:PrintStatus()
	local account = self:Account()
	local rootWidth, rootHeight = self:RootSize()

	Line("|cFF69B4%s|r", self.title)
	Line("  bars ready=%s  screen=%dx%d  enabled=%s preview=%s  skill bar=%s", tostring(self:BarsReady()),
		Round(rootWidth), Round(rootHeight), tostring(account.enabled), tostring(account.preview),
		self:SkillBarAllowed() and "controlled" or "|cFFFF80left alone|r")
	if self.measureNote then
		Line("  %s", self.measureNote)
	end
	Line("  watch=%s  put back %d time(s)%s", tostring(self.watching == true), self.repairs or 0,
		self.lastRepair and string.format(" (last %ds ago)",
			Round(((GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0) - self.lastRepair) / 1000)) or "")

	for _, bar in ipairs(self.elements) do
		local position = self:ClampedPosition(self:Position(bar))
		local game = self:GamePosition(bar)
		local measured = self:Measured(bar)
		local source = type(measured.x) == "number" and "measured" or "worked out"
		Line("|cFF69B4  %s|r  x=%d y=%d scale=%d%%  game's: x=%d y=%d (%s)  differs=%s written=%s",
			bar.key, position.x, position.y, self:ScalePercent(bar), game.x, game.y, source,
			tostring(self:BarDiffers(bar)), tostring(self.written[bar.key] == true))

		local control = self:Control(bar)
		if control then
			local anchor = ReadAnchor(control, 0)
			if anchor then
				Line("    anchor: %s -> %s %s (%d, %d)", PointName(anchor.point), ControlName(anchor.relativeTo),
					PointName(anchor.relativePoint), Round(anchor.offsetX), Round(anchor.offsetY))
			end
			local left, top, width, height = self:ScreenRect(control)
			if left then
				Line("    on screen: %dx%d at left=%d top=%d  middle=(%d, %d up)  scale=%s",
					Round(width), Round(height), Round(left), Round(top),
					Round(left + width / 2 - rootWidth / 2), Round(rootHeight - (top + height / 2)),
					tostring(ReadScale(control)))
			end
		else
			Line("    the control is not there")
		end
	end

	if self.timers then
	local text = self:Text()
	local back = self:BackBar()
	if self.skillbar then
		local available, why = self:WeaponSwapState()
		Line("|cFF69B4  skill bar gaps|r  skill=%d ultimate=%d item=%d  (the game's: %d / %d / %d)  written=%s",
			self:Gap("skill"), self:Gap("ultimate"), self:Gap("item"),
			self:GameGap("skill"), self:GameGap("ultimate"), self:GameGap("item"),
			tostring(self.skillbar.written == true))
		Line("    weapon swap: %s%s", tostring(available), why and (" (" .. why .. ")") or "")
	end

	if self.plain then
		Line("|cFF69B4  bar style|r  %s  opacity=%d%% outline=%s  running=%s", self:BarStyle(),
			self:PlainOpacity(), tostring(self:PlainBorder()), tostring(self.plain.running == true))
	end
	Line("|cFF69B4  icon shade|r  on=%s darkness=%d%% direction=%s leading edge=%s",
		tostring(self:ShadeEnabled()), self:ShadeDarkness(), self:ShadeDirection(),
		tostring(self:Shade().leadingEdge ~= false))

	local built, backBuilt = 0, 0
	for _ in pairs(self.timers.labels) do
		built = built + 1
	end
	for _ in pairs(self.timers.back) do
		backBuilt = backBuilt + 1
	end
	Line("|cFF69B4  skill bar text|r  countdown=%s  the game draws its own: %s (dimmed=%s)",
		self:TimerMode(), tostring(self:GameShowsBarTimers()), tostring(self:DimsGameTimer()))
	Line("    sizes: countdown %d / %d%s   count %s %d / %d%s",
		self:TextSize("timer", false), self:TextSize("timer", true),
		self:TextSizeIsOwn("timer") and "" or " (following)",
		tostring(text.showCounts ~= false), self:TextSize("count", false), self:TextSize("count", true),
		self:TextSizeIsOwn("count") and "" or " (following)")
	Line("    controls built: labels=%d/6 row=%d/6   effects tracked=%d   (%s slots for the rest)",
		built, backBuilt, self.timers:TrackedCount(), SLASH .. " slots")
	Line("|cFF69B4  back bar|r  on=%s empty=%s scale=%d%% gap=%d  running=%s",
		tostring(back.enabled ~= false), tostring(back.showEmpty ~= false), self:BackBarScale(),
		Round(back.gap or 4), tostring(self.timers ~= nil and self.timers.running == true))
	local backHotbar, activeHotbar = self.timers:BackHotbar()
	Line("    hotbar: active=%s other=%s", tostring(activeHotbar), tostring(backHotbar))
	end

	if self.writeErrors then
		for what, err in pairs(self.writeErrors) do
			Line("  |cFF4040refused|r %s: %s", what, err)
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------------------

local function Usage()
	Line("|cFF69B4%s|r", addon.title)
	Line("  %s                        -- this list", SLASH)
	Line("  %s status                 -- settings, and where the bars really are", SLASH)
	Line("  %s pos <bar> <x> <y>      -- x from the middle of the screen, y up from the bottom", SLASH)
	Line("  %s scale <bar> <n>        -- size in per cent (%d-%d)", SLASH, addon.MIN_SCALE, addon.MAX_SCALE)
	Line("  %s text [back] timer|count <n> -- size of the text on the skill bar (%d-%d)", SLASH, addon.MIN_TEXT_SIZE or 12, addon.MAX_TEXT_SIZE or 48)
	Line("  %s timers addon|both|game -- whose countdown goes on the front bar", SLASH)
	Line("  %s gap skill|ult|item <n> -- the space along the skill bar (%d-%d)", SLASH, addon.MIN_GAP or 0, addon.MAX_GAP or 150)
	Line("  %s style standard|plain|mura -- the look of the three resource bars", SLASH)
	Line("  %s size <bar> <w> <h>    -- bar size in pixels (MURA-HIGE Style)", SLASH)
	Line("  %s shade [on|off|up|down|<n>] -- the shade over a skill while its effect runs", SLASH)
	Line("  %s slots                  -- what is on each slot, and why", SLASH)
	Line("  %s effects                -- the last effect events the game sent", SLASH)
	Line("  %s trace [on|off|clear]  -- record what the game sends as an ability is cast", SLASH)
	Line("  %s plain [margin <l> <r>] -- what the plain look is doing, and the end margins", SLASH)
	Line("  %s plain trace            -- what the bars did coming back from the last menu", SLASH)
	Line("  %s plain test <part> off  -- take one part of a style away, to find a flicker", SLASH)
	Line("  %s backbar [on|off|empty|<scale>] -- the other weapon set's row", SLASH)
	Line("  %s skillbar on|off        -- whether the skill bar is this add-on's to touch", SLASH)
	Line("  %s on | off               -- switch every change on or off", SLASH)
	Line("  %s preview                -- show or hide the preview frames", SLASH)
	Line("  %s reset [bar]            -- back to the game's own", SLASH)
	Line("  <bar> is health, magicka or stamina (hp, mag, stam)", SLASH)
	Line("  (%s is the same command)", SHORT_SLASH)
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
	elseif command == "effects" then
		if addon.timers then
			addon.timers:PrintLog()
		end
	elseif command == "trace" then
		if addon.trace then
			addon.trace:Command(args[2])
		end
	elseif command == "plain" then
		if (args[2] or ""):lower() == "test" then
			if addon.plain then
				addon.plain:TestCommand(args[3], args[4])
			end
			return
		end
		if (args[2] or ""):lower() == "trace" then
			if addon.returnTrace then
				addon.returnTrace:Print()
			end
			return
		end
		if (args[2] or ""):lower() == "margin" then
			local left, right = tonumber(args[3]), tonumber(args[4])
			if not left then
				Line("usage: %s plain margin <left> <right>   (0-%d pixels, how far the effect stops short of each end)",
					SLASH, addon.MAX_END_MARGIN)
				return
			end
			addon:SetEndMargins(left, right or left)
			addon:Refresh()
			local now, also = addon:EndMargins()
			Line("end margins: left %d right %d", now, also)
			return
		end
		if addon.plain then
			addon.plain:PrintStatus()
		end
	elseif command == "slots" or command == "skills" then
		if addon.timers then
			addon.timers:PrintSlots()
		end
	elseif command == "pos" or command == "position" then
		local bar = addon.barByCommand[(args[2] or ""):lower()]
		local x, y = tonumber(args[3]), tonumber(args[4])
		if not bar or not x or not y then
			Line("usage: %s pos <health|magicka|stamina> <x> <y>", SLASH)
			return
		end
		addon:SetPositionValue(bar, "x", x)
		addon:SetPositionValue(bar, "y", y)
		account.enabled = true
		addon:Refresh()
		local position = addon:ClampedPosition(addon:Position(bar))
		Line("%s: x=%d y=%d", bar.key, position.x, position.y)
	elseif command == "size" and addon.barByCommand[(args[2] or ""):lower()] and not addon.barByCommand[(args[2] or ""):lower()].isActionBar and tonumber(args[4]) then
		local bar = addon.barByCommand[(args[2] or ""):lower()]
		addon:SetBarSize(bar, "width", tonumber(args[3]))
		addon:SetBarSize(bar, "height", tonumber(args[4]))
		account.enabled = true
		addon:Refresh()
		local width, height = addon:BarSize(bar)
		Line("%s: %dx%d (drawn at that size in MURA-HIGE Style)", bar.key, width, height)
	elseif command == "scale" or command == "size" then
		local bar = addon.barByCommand[(args[2] or ""):lower()]
		local value = tonumber(args[3])
		if not bar or not value then
			Line("usage: %s scale <health|magicka|stamina> <%d-%d>", SLASH, addon.MIN_SCALE, addon.MAX_SCALE)
			return
		end
		addon:SetScalePercent(bar, value)
		account.enabled = true
		addon:Refresh()
		Line("%s: scale=%d%%", bar.key, addon:ScalePercent(bar))
	elseif command == "text" then
		-- "back" anywhere in front of the rest picks the other weapon set's row.
		local index = 2
		local isBack = false
		local word = (args[index] or ""):lower()
		if word == "back" or word == "front" then
			isBack = word == "back"
			index = index + 1
			word = (args[index] or ""):lower()
		end
		local which
		if word == "count" or word == "targets" then
			which = "count"
		elseif word == "timer" or word == "time" then
			which = "timer"
		end
		local value = tonumber(args[index + 1])
		if which and word == "" then
			which = nil
		end
		if not which or not value then
			Line("usage: %s text [back] timer|count <%d-%d>", SLASH, addon.MIN_TEXT_SIZE, addon.MAX_TEXT_SIZE)
			return
		end
		addon:SetTextSize(which, value, isBack)
		account.enabled = true
		addon:Refresh()
		Line("%s text size: this bar %d, other set %d", which, addon:TextSize(which, false),
			addon:TextSize(which, true))
	elseif command == "gap" or command == "gaps" then
		local which = (args[2] or ""):lower()
		local names = { skill = "skill", skills = "skill", ability = "skill",
			ult = "ultimate", ultimate = "ultimate",
			item = "item", quickslot = "item", quick = "item" }
		which = names[which]
		local value = tonumber(args[3])
		if not which or not value then
			Line("usage: %s gap skill|ult|item <%d-%d>", SLASH, addon.MIN_GAP, addon.MAX_GAP)
			return
		end
		addon:SetGap(which, value)
		account.enabled = true
		addon:Refresh()
		Line("gaps: skill=%d ultimate=%d item=%d", addon:Gap("skill"), addon:Gap("ultimate"), addon:Gap("item"))
	elseif command == "style" then
		local style = (args[2] or ""):lower()
		if style == "liquid" then
			style = "liquidflow"
		end
		if style == "round" or style == "mura" or style == "murahige" or style == "mura-hige" then
			style = "rounded"
		end
		if not addon:SetBarStyle(style) then
			Line("usage: %s style standard|plain|rounded|neo|liquid|crystal", SLASH)
			return
		end
		account.enabled = true
		addon:Refresh()
		Line("bar style: %s", addon:BarStyle())
	elseif command == "shade" then
		local what = (args[2] or ""):lower()
		local shade = addon:Shade()
		local darkness = tonumber(what)
		if what == "on" or what == "off" then
			shade.enabled = what == "on"
			account.enabled = true
		elseif what == "up" or what == "down" then
			shade.direction = what
		elseif what == "edge" then
			shade.leadingEdge = not (shade.leadingEdge ~= false)
		elseif darkness then
			addon:SetShadeDarkness(darkness)
			account.enabled = true
		elseif what ~= "" then
			Line("usage: %s shade [on|off|up|down|edge|<0-100>]", SLASH)
			return
		else
			shade.enabled = not (shade.enabled ~= false)
			account.enabled = true
		end
		addon:Refresh()
		Line("icon shade: on=%s darkness=%d%% direction=%s", tostring(addon:ShadeEnabled()),
			addon:ShadeDarkness(), addon:ShadeDirection())
	elseif command == "timers" then
		local mode = (args[2] or ""):lower()
		local renamed = { auto = "addon", always = "both", never = "game" }
		mode = renamed[mode] or mode
		if mode ~= "addon" and mode ~= "both" and mode ~= "game" then
			Line("usage: %s timers addon|both|game", SLASH)
			return
		end
		addon:Text().timerMode = mode
		addon:Refresh()
		Line("countdown on the game's own bar: %s", mode)
	elseif command == "backbar" or command == "back" then
		local what = (args[2] or ""):lower()
		local back = addon:BackBar()
		local scale = tonumber(what)
		if what == "on" or what == "off" then
			back.enabled = what == "on"
			account.enabled = true
		elseif what == "empty" then
			back.showEmpty = not (back.showEmpty ~= false)
		elseif scale then
			addon:SetBackBarScale(scale)
			account.enabled = true
		elseif what ~= "" then
			Line("usage: %s backbar [on|off|empty|<%d-%d>]", SLASH, addon.MIN_SCALE, addon.MAX_SCALE)
			return
		else
			back.enabled = not (back.enabled ~= false)
			account.enabled = true
		end
		addon:Refresh()
		Line("back bar: on=%s empty=%s scale=%d%%", tostring(back.enabled ~= false),
			tostring(back.showEmpty ~= false), addon:BackBarScale())
	elseif command == "skillbar" then
		local what = (args[2] or ""):lower()
		if what ~= "on" and what ~= "off" then
			Line("usage: %s skillbar on|off", SLASH)
			return
		end
		addon:SetSkillBarAllowed(what == "on")
		addon:Refresh()
		Line("the skill bar is %s", addon:SkillBarAllowed() and "this add-on's to touch"
			or "left alone -- position, size, gaps, the other set's row, the text and the shade are all off")
	elseif command == "on" or command == "off" then
		account.enabled = command == "on"
		addon:Refresh()
		Line("bar changes %s", command)
	elseif command == "preview" then
		if addon.preview then
			local shown = addon.preview:Toggle()
			Line("preview %s", shown and "on" or "off")
		end
	elseif command == "reset" then
		local bar = addon.barByCommand[(args[2] or ""):lower()]
		if bar then
			addon:ResetBar(bar)
			addon:Refresh()
			Line("reset -- the %s bar is back where the game puts it", bar.key)
		else
			addon:ResetAll()
			Line("reset -- all three bars are back where the game puts them")
		end
	else
		Usage()
	end
end

-- ---------------------------------------------------------------------------------------
-- Bootstrap
-- ---------------------------------------------------------------------------------------

-- How long after the first zone load to wait before touching the bars.
--
-- The bars exist from the moment the UI loads, but the attribute visualiser sets their widths
-- on its own EVENT_PLAYER_ACTIVATED, and the first measurement wants them at rest. A second's
-- grace also keeps this out of the moment every add-on is initialising at once against the
-- 100 MB console pool -- the lesson from PB's NamePlateChanger. If the bars are still not
-- there, try again a few times, then give up quietly: status says why.
local FIRST_APPLY_DELAY_MS = 1000
local RETRY_DELAY_MS = 1000
local MAX_ATTEMPTS = 10

local function Later(fn, delay)
	if zo_callLater then
		zo_callLater(fn, delay)
	else
		fn()
	end
end

function addon:TryFirstApply(attempt)
	if self:BarsReady() then
		-- Read before anything is written, so the settings panel's defaults are the game's real
		-- numbers even while nothing is being changed.
		self:CaptureAll()
		self.firstApplyDone = true
		self:Refresh()
		return
	end
	if attempt < MAX_ATTEMPTS then
		Later(function()
			self:TryFirstApply(attempt + 1)
		end, RETRY_DELAY_MS)
		return
	end
	-- Out of attempts. Letting the flag go means the next zone load starts again rather than the
	-- add-on sitting there having given up for the session.
	self.firstApplyScheduled = false
end

local function OnPlayerActivated()
	if addon.firstApplyDone then
		-- A later zone load does not rebuild the bars, but nothing is lost by checking: the
		-- checks write only what no longer matches.
		addon:OnHudShowing()
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
-- nothing of theirs is wrapped. SHOWN rather than SHOWING, so the bars' own fragment has
-- already done whatever it does for the same transition.
local function RegisterHud()
	local fragment = HUD_FRAGMENT
	if not fragment or type(fragment.RegisterCallback) ~= "function" then
		return false
	end
	fragment:RegisterCallback("StateChange", function(_, newState)
		if newState == SCENE_FRAGMENT_SHOWN then
			addon:OnHudShowing()
		elseif newState == SCENE_FRAGMENT_HIDDEN then
			addon:OnHudHidden()
		end
	end)
	local bars = PLAYER_ATTRIBUTE_BARS_FRAGMENT
	if bars and type(bars.RegisterCallback) == "function" then
		bars:RegisterCallback("StateChange", function(_, newState)
			addon:OnBarsFragment(newState)
		end)
		addon.plainFollowsBars = true
	end
	local actionBar = ACTION_BAR_FRAGMENT
	if actionBar and type(actionBar.RegisterCallback) == "function" then
		actionBar:RegisterCallback("StateChange", function(_, newState)
			addon:OnActionBarFragment(newState)
		end)
		addon.timersFollowBar = true
	end
	return true
end

local function OnAddOnLoaded(_, loadedName)
	if loadedName ~= addon.name then
		return
	end
	EVENT_MANAGER:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

	addon.account = ZO_SavedVars:NewAccountWide("PBsConsoleHudCustomizer_Data", 1, nil, addon.accountDefaults)
	addon:Account()

	SLASH_COMMANDS[SLASH] = OnSlash
	SLASH_COMMANDS[SHORT_SLASH] = OnSlash

	addon.hudRegistered = RegisterHud()

	if addon.timers then
		addon.timers:Register()
	end

	if addon.InitSettings then
		addon:InitSettings()
	end

	EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
end

-- What has been written, and what was there before, per bar. Neither survives a reload, which
-- is what makes every session start from the game's own controls.
addon.written = {}
addon.original = {}

PBS_CONSOLE_HUD_CUSTOMIZER = addon
EVENT_MANAGER:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
